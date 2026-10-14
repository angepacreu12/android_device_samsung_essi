#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 dxjsk
# SPDX-License-Identifier: Apache-2.0
"""check_compile.py - acceptance check 1: build the vendor policy the way Soong does and compile it
the way init does.

Replays system/sepolicy's pipeline for `vendor_sepolicy.cil` and `plat_pub_versioned.cil`:

    m4 -s <ordered policy files>            -> vendor_sepolicy.conf / pub_policy.conf / reqd_policy_mask.conf
    checkpolicy -C -M -c 30                 -> *.cil.raw
    filter_out reqd_policy_mask.cil
    version_policy -n 202404                -> (re-implemented in Python: public types become X_202404
                                               attributes, base_typeattr_N become base_typeattr_N_202404)
    filter_out plat_pub_versioned.cil       -> vendor_sepolicy.cil

then runs init's command line against the *phone's* system policy in reference/system:

    secilc -m -M true -G -N -c 30 plat_sepolicy.cil mapping/202404.cil system_ext... product... \
           vendor_sepolicy.cil plat_pub_versioned.cil

and, additionally, the same without -N (the build's neverallow check) and checkfc/checkseapp over the
contexts files.  Writes tools/out/ and a markdown report.
"""
import argparse
import glob
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
POLICY_VERS = "30"

ORDER = ["flagging_macros", "security_classes", "initial_sids", "access_vectors", "global_macros",
         "neverallow_macros", "mls_macros", "mls_decl", "mls", "policy_capabilities", "te_macros",
         "ioctl_defines", "ioctl_macros", "attributes|*.te", "roles_decl", "roles", "users",
         "initial_sid_contexts", "fs_use", "genfs_contexts", "port_contexts"]

M4_DEFS = ["mls_num_sens=1", "mls_num_cats=1024", "target_arch=arm64", "target_with_asan=false",
           "target_with_dexpreopt=true", "target_with_native_coverage=false",
           "target_full_treble=true", "target_compatible_property=true",
           "target_treble_sysprop_neverallow=true", "target_enforce_sysprop_owner=true",
           "target_exclude_build_test=false", "target_requires_insecure_execmem_for_swiftshader=false",
           "target_enforce_debugfs_restriction=true", "target_recovery=false",
           "target_board_api_level=202404", "target_flag_RELEASE_RANGING_STACK=false"]


def run(cmd, **kw):
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, **kw)
    return r.returncode, r.stdout


def collect(dirs):
    """Order policy files like Soong's policyConfOrder (attributes of every dir, then *.te of every dir)."""
    out = []
    for pat in ORDER:
        if pat == "attributes|*.te":
            for d in dirs:
                out += sorted(glob.glob(os.path.join(d, "attributes")))
            for d in dirs:
                out += sorted(glob.glob(os.path.join(d, "*.te")))
        else:
            for d in dirs:
                out += sorted(glob.glob(os.path.join(d, pat)))
    return out


# policy.go: for the recovery policy these four are forced to "false"
RECOVERY_DEFS = {"target_recovery": "true", "target_full_treble": "false", "target_compatible_property": "false",
                 "target_treble_sysprop_neverallow": "false", "target_enforce_sysprop_owner": "false"}


def m4(files, out, variant, overrides=None):
    defs = dict(d.split("=", 1) for d in M4_DEFS)
    defs["target_build_variant"] = variant
    defs.update(overrides or {})
    cmd = ["m4", "--fatal-warnings"] + sum((["-D", "%s=%s" % kv] for kv in defs.items()), []) + ["-s"] + files
    rc, txt = run(cmd)
    if rc:
        raise SystemExit("m4 failed:\n" + txt[-3000:])
    with open(out, "w") as f:
        f.write(txt)


def checkpolicy(conf, out):
    rc, txt = run(["checkpolicy", "-C", "-M", "-c", POLICY_VERS, "-o", out, conf])
    if rc:
        raise SystemExit("checkpolicy failed on %s:\n%s" % (conf, txt[-4000:]))
    return txt


def cil_lines(path):
    return [l for l in open(path).read().splitlines() if l and not l.startswith(";;")]


def filter_out(lines, *filters):
    drop = set()
    for f in filters:
        drop.update(cil_lines(f) if isinstance(f, str) else f)
    return [l for l in lines if l not in drop]


class Versioner:
    """Python re-implementation of system/sepolicy/tools/version_policy (cil_android_attributize)."""

    def __init__(self, pub_lines, vers):
        self.vers = vers
        self.pub_types = set()
        for l in pub_lines:
            m = re.match(r"^\(type (\S+)\)$", l)
            if m:
                self.pub_types.add(m.group(1))
        self.tok = re.compile(r'"[^"]*"|[A-Za-z0-9_.\-]+|[()\s]+')

    def rename(self, name):
        if name in self.pub_types or name.startswith("base_typeattr_"):
            return name + "_" + self.vers
        return name

    def line(self, l):
        if l.startswith("(genfscon ") or l.startswith("(type "):
            return [l]          # contexts keep real types; public type declarations stay as they are
        m = re.match(r"^\(roletype object_r (\S+)\)$", l)
        if m:
            # version_policy replaces the roletype of a public type by the one of its versioned attribute
            return ["(roletype object_r %s)" % self.rename(m.group(1))]
        out = []
        toks = list(self.tok.finditer(l))
        # in a rule the class position "(class (perms))" is never a type, even if a type shares its name
        kind = l[1:].split(" ", 1)[0]
        cls_pos = -1
        if kind in ("allow", "dontaudit", "neverallow", "auditallow"):
            m2 = re.match(r"^\(\w+ \S+ \S+ \((\S+) \(", l)
            if m2:
                cls_pos = l.index(" (" + m2.group(1) + " (") + 2
        elif kind in ("allowx", "dontauditx", "neverallowx", "auditallowx"):
            m2 = re.match(r"^\(\w+ \S+ \S+ \(ioctl (\S+) \(", l)
            if m2:
                cls_pos = l.index("(ioctl " + m2.group(1)) + 7
        elif kind == "typetransition":
            m2 = re.match(r"^\(typetransition \S+ \S+ (\S+) ", l)
            if m2:
                cls_pos = l.index(" " + m2.group(1) + " ", len("(typetransition ")) + 1
        # the result type of a typetransition stays a real type (an attribute cannot be a result)
        keep_last = l.startswith("(typetransition ")
        last_name = max((i for i, t in enumerate(toks) if t.group(0)[0].isalnum() or t.group(0)[0] == "_"), default=-1)
        for i, m in enumerate(toks):
            t = m.group(0)
            if t.startswith('"') or not t[0].isalnum() and t[0] not in "_":
                out.append(t)
            elif (keep_last and i == last_name) or m.start() == cls_pos:
                out.append(t)
            else:
                out.append(self.rename(t))
        return [re.sub(r"\s+\)", ")", "".join(out))]

    def version(self, lines):
        out = []
        for l in lines:
            m = re.match(r"^\(type (\S+)\)$", l)
            if m and m.group(1) in self.pub_types:
                out.append(l)
                out.append("(typeattribute %s_%s)" % (m.group(1), self.vers))
                continue
            m = re.match(r"^\(typeattribute (base_typeattr_\d+)\)$", l)
            if m:
                out.append("(typeattribute %s_%s)" % (m.group(1), self.vers))
                continue
            out += self.line(l)
        return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--deps", default=os.path.join(HERE, "deps"))
    ap.add_argument("--vendor-dir", default=os.path.join(ROOT, "device/sepolicy/vendor"))
    ap.add_argument("--extra-dir", default=os.path.join(ROOT, "device/sepolicy_extra"),
                    help="hand-written policy dir (second BOARD_VENDOR_SEPOLICY_DIRS entry); skipped if absent")
    ap.add_argument("--sysext-dir", default=os.path.join(ROOT, "device/sepolicy_system_ext"),
                    help="device system_ext policy: <dir>/public (SYSTEM_EXT_PUBLIC_SEPOLICY_DIRS) and <dir>/private "
                         "(SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS); skipped if absent")
    ap.add_argument("--ref", default=os.path.join(ROOT, "reference"))
    ap.add_argument("--out", default=os.path.join(HERE, "out/compile"))
    ap.add_argument("--variant", default=None, help="user/userdebug/eng; default: detected from reference/system (su domain present => userdebug)")
    ap.add_argument("--md", help="write a markdown report here")
    args = ap.parse_args()

    S = os.path.join(args.deps, "system_sepolicy")
    L = os.path.join(args.deps, "lineage_sepolicy/common")
    if not os.path.isdir(S) or not os.path.isdir(L):
        raise SystemExit("policy sources missing: run tools/fetch_deps.sh first")
    os.makedirs(args.out, exist_ok=True)
    O = lambda *p: os.path.join(args.out, *p)
    ref = args.ref
    sysd = os.path.join(ref, "system")
    vers = open(os.path.join(sysd, "system/selinux/plat_sepolicy_and_mapping.sha256")).read() and \
        open(os.path.join(ref, "baseline/vendor/etc/selinux/plat_sepolicy_vers.txt")).read().strip()
    if args.variant is None:
        args.variant = "userdebug" if "(type su)" in open(os.path.join(sysd, "system/selinux/plat_sepolicy.cil")).read() else "user"
    report = ["# check 1: compile like init does", "", "Build variant used for the baseline policy: `%s` (detected from the system image)." % args.variant, ""]
    ok_all = True

    # Directories, in the order Soong uses them.  SYSTEM_EXT public policy comes from Lineage
    # (device/lineage/sepolicy/common/sepolicy.mk); BOARD_VENDOR_SEPOLICY_DIRS = lineage dynamic +
    # lineage vendor (TARGET_USES_PREBUILT_VENDOR_SEPOLICY is false: our vendor image is erofs) + ours.
    flag = [os.path.join(S, "flagging/flagging_macros")]
    xpub, xpriv = os.path.join(args.sysext_dir, "public"), os.path.join(args.sysext_dir, "private")
    sysext_dirs = [d for d in (xpub, xpriv) if os.path.isdir(d)]
    pub_dirs = [os.path.join(S, "public"), os.path.join(L, "public")] + ([xpub] if os.path.isdir(xpub) else []) + [os.path.join(S, "reqd_mask")]
    vendor_dirs = [os.path.join(S, "vendor"), os.path.join(L, "dynamic"), os.path.join(L, "vendor"), args.vendor_dir]
    ours_dirs = [args.vendor_dir] + ([args.extra_dir] if os.path.isdir(args.extra_dir) else [])
    vendor_dirs += ours_dirs[1:]

    # 1. confs and raw CIL
    m4(flag + collect([os.path.join(S, "reqd_mask")]), O("reqd_policy_mask.conf"), args.variant)
    checkpolicy(O("reqd_policy_mask.conf"), O("reqd_policy_mask.cil"))
    m4(flag + collect(pub_dirs), O("pub_policy.conf"), args.variant)
    checkpolicy(O("pub_policy.conf"), O("pub_policy.cil.raw"))
    m4(flag + collect(pub_dirs + vendor_dirs), O("vendor_sepolicy.conf"), args.variant)
    cp_out = checkpolicy(O("vendor_sepolicy.conf"), O("vendor_sepolicy.cil.raw0"))
    report += ["- checkpolicy over `%s` (%d policy source files incl. %d of ours): **OK**" % (
        "vendor_sepolicy.conf", len(collect(pub_dirs + vendor_dirs)), sum(len(glob.glob(os.path.join(d, "*.te"))) for d in ours_dirs))]
    pub = filter_out(cil_lines(O("pub_policy.cil.raw")), O("reqd_policy_mask.cil"))
    raw = filter_out(cil_lines(O("vendor_sepolicy.cil.raw0")), O("reqd_policy_mask.cil"))
    open(O("pub_policy.cil"), "w").write("\n".join(pub) + "\n")

    # 2. versioning
    v = Versioner(pub, vers)
    ppv = v.version(pub)
    open(O("plat_pub_versioned.cil"), "w").write("\n".join(ppv) + "\n")
    vendor = filter_out(v.version(raw), ppv)
    open(O("vendor_sepolicy.cil"), "w").write("\n".join(vendor) + "\n")

    # 2b. fidelity of the emulation: our plat_pub_versioned.cil vs. the one the real build produced
    real_ppv = set(cil_lines(os.path.join(ref, "baseline/vendor/etc/selinux/plat_pub_versioned.cil")))
    mine = set(ppv)
    report += ["- emulated `plat_pub_versioned.cil` vs the real build's (`reference/baseline`): %d lines, "
               "%d only in ours, %d only in the real one" % (len(mine), len(mine - real_ppv), len(real_ppv - mine))]
    open(O("ppv_diff.txt"), "w").write("ONLY EMULATED:\n" + "\n".join(sorted(mine - real_ppv)) +
                                       "\n\nONLY REAL:\n" + "\n".join(sorted(real_ppv - mine)) + "\n")
    ntypes = len([l for l in vendor if l.startswith("(type ")])
    report += ["- generated `vendor_sepolicy.cil`: %d lines, %d types (baseline build: %d lines, %d types; "
               "Samsung stock: %d lines, %d types)" % (
                   len(vendor), ntypes,
                   len(cil_lines(os.path.join(ref, "baseline/vendor/etc/selinux/vendor_sepolicy.cil"))),
                   len([l for l in cil_lines(os.path.join(ref, "baseline/vendor/etc/selinux/vendor_sepolicy.cil")) if l.startswith("(type ")]),
                   len(cil_lines(os.path.join(ref, "stock/vendor/etc/selinux/vendor_sepolicy.cil"))),
                   len([l for l in cil_lines(os.path.join(ref, "stock/vendor/etc/selinux/vendor_sepolicy.cil")) if l.startswith("(type ")]))]

    # 3. secilc like init
    plat = [os.path.join(sysd, "system/selinux/plat_sepolicy.cil"),
            os.path.join(sysd, "system/selinux/mapping/%s.cil" % vers)]
    compat = os.path.join(sysd, "system/selinux/mapping/%s.compat.cil" % vers)
    if os.path.exists(compat):
        plat.append(compat)
    for part in ("system_ext", "product"):
        c = os.path.join(sysd, part, "selinux/%s_sepolicy.cil" % part)
        if os.path.exists(c):
            plat += [c, os.path.join(sysd, part, "selinux/mapping/%s.cil" % vers)]
    genfs_vers = 202404
    gv = os.path.join(args.vendor_dir, "genfs_labels_version.txt")
    if os.path.exists(gv):
        genfs_vers = int(open(gv).read().strip())
    for g in sorted(glob.glob(os.path.join(sysd, "system/selinux/plat_sepolicy_genfs_*.cil"))):
        if int(re.search(r"genfs_(\d+)", g).group(1)) <= genfs_vers:
            plat.append(g)
    # 2c. device system_ext policy: what the build would add to system_ext_sepolicy.cil and to the system_ext
    #     mapping file for the types our public dir declares (the image's copies predate them).  Emulated from
    #     the full conf (system + lineage + ours), keeping only the statements that name a new type.
    sysext_extra = []
    if sysext_dirs:
        m4(flag + collect([os.path.join(S, "public"), os.path.join(S, "private"), os.path.join(L, "public"),
                           os.path.join(L, "private")] + sysext_dirs), O("system_ext_full.conf"), args.variant)
        checkpolicy(O("system_ext_full.conf"), O("system_ext_full.cil"))
        full = cil_lines(O("system_ext_full.cil"))
        known = set()
        for c in glob.glob(os.path.join(sysd, "*/selinux/*_sepolicy.cil")):
            known |= set(re.findall(r"^\(type (\S+)\)", open(c).read(), re.M))
        new_types = {m.group(1) for m in (re.match(r"^\(type (\S+)\)$", l) for l in full) if m} - known
        tok = re.compile(r"[A-Za-z0-9_.\-]+")
        for l in full:
            if l.startswith("(type "):
                continue
            m = re.match(r"^\(typeattributeset (\S+) \((.*)\)\)$", l)
            if m:
                mine = [x for x in m.group(2).split() if x in new_types]
                if mine and not m.group(1).startswith("base_typeattr_"):
                    sysext_extra.append("(typeattributeset %s (%s))" % (m.group(1), " ".join(mine)))
            elif any(t in new_types for t in tok.findall(l)):
                sysext_extra.append(l)
        for t in sorted(new_types):
            sysext_extra += ["(typeattributeset %s_%s (%s))" % (t, vers, t), "(expandtypeattribute (%s_%s) true)" % (t, vers)]
        open(O("system_ext_extra.cil"), "w").write("\n".join(sysext_extra) + "\n")
        report += ["- device system_ext policy (`%s`): %d new public type(s) %s; %d CIL statements emulated for "
                   "`system_ext_sepolicy.cil` + its mapping (`tools/out/compile/system_ext_extra.cil`)" % (
                       os.path.relpath(args.sysext_dir, ROOT), len(new_types), sorted(new_types), len(sysext_extra))]

    base_cmd = ["secilc", "-m", "-M", "true", "-G", "-c", POLICY_VERS, "-f", "/dev/null"]
    files = plat + [O("vendor_sepolicy.cil"), O("plat_pub_versioned.cil")] + ([O("system_ext_extra.cil")] if sysext_extra else [])
    rc, txt = run(base_cmd + ["-N", "-o", O("precompiled_sepolicy")] + files)
    report += ["", "## secilc as init runs it (`-m -M true -G -N -c 30`)", "", "```",
               "secilc -m -M true -G -N -c 30 " + " ".join(os.path.relpath(f, ROOT) for f in files), "```", "",
               "**%s**" % ("PASS" if rc == 0 else "FAIL (rc=%d)" % rc)]
    if rc:
        ok_all = False
        report += ["", "```", txt[-3000:], "```"]
    else:
        report += ["", "`precompiled_sepolicy`: %d bytes" % os.path.getsize(O("precompiled_sepolicy"))]

    # 4. neverallow check (what the build does at the secilc stage without -N)
    rc2, txt2 = run(base_cmd + ["-o", "/dev/null"] + files)
    ok_all &= rc2 == 0
    viol = [l for l in txt2.splitlines() if l.startswith("neverallow") or "violated" in l or "Neverallow" in l]
    report += ["", "## neverallow check (same command without `-N`, as the build runs it)", "",
               "**%s**" % ("PASS" if rc2 == 0 else "FAIL (rc=%d): %d neverallow lines reported" % (rc2, len(viol)))]
    if rc2:
        open(O("neverallow_failures.txt"), "w").write(txt2)
        report += ["", "First failures (full list in `tools/out/compile/neverallow_failures.txt`):", "", "```"]
        report += [l[:300] for l in txt2.splitlines() if l.strip()][:40]
        report += ["```"]

    # 5. contexts validation with checkfc / checkseapp (what the build does for every *_contexts file)
    if rc == 0:
        checkfc = os.path.join(args.deps, "checkfc")
        checkseapp = os.path.join(args.deps, "checkseapp")
        report += ["", "## contexts files validated against the compiled policy", ""]
        pol = O("precompiled_sepolicy")
        sel = os.path.join(sysd, "system/selinux")
        combos = [
            ("file_contexts", ["-e"] if False else [], [os.path.join(sel, "plat_file_contexts"),
                                                      os.path.join(ref, "baseline/vendor/etc/selinux/vendor_file_contexts"),
                                                      os.path.join(args.vendor_dir, "file_contexts")] + [os.path.join(d, "file_contexts") for d in ours_dirs[1:]]),
            ("property_contexts", ["-p"], [os.path.join(sel, "plat_property_contexts"),
                                           os.path.join(ref, "baseline/vendor/etc/selinux/vendor_property_contexts"),
                                           os.path.join(args.vendor_dir, "property_contexts")] + [os.path.join(d, "property_contexts") for d in ours_dirs[1:]]
                                          + ([os.path.join(xpriv, "property_contexts")] if os.path.isdir(xpriv) else [])),
            ("service_contexts", ["-s"], [os.path.join(sel, "plat_service_contexts"),
                                          os.path.join(ref, "baseline/vendor/etc/selinux/vendor_service_contexts"),
                                          os.path.join(args.vendor_dir, "service_contexts")] + [os.path.join(d, "service_contexts") for d in ours_dirs[1:]]),
            ("hwservice_contexts", ["-l"], [os.path.join(sel, "plat_hwservice_contexts"),
                                            os.path.join(ref, "baseline/vendor/etc/selinux/vendor_hwservice_contexts"),
                                            os.path.join(args.vendor_dir, "hwservice_contexts")] + [os.path.join(d, "hwservice_contexts") for d in ours_dirs[1:]]),
            ("vndservice_contexts", ["-v"], [os.path.join(ref, "baseline/vendor/etc/selinux/vndservice_contexts"),
                                             os.path.join(args.vendor_dir, "vndservice_contexts")] + [os.path.join(d, "vndservice_contexts") for d in ours_dirs[1:]]),
        ]
        for name, flags, srcs in combos:
            srcs = [s for s in srcs if os.path.exists(s)]
            merged = O("merged_" + name)
            with open(merged, "w") as f:
                for s in srcs:
                    for l in open(s, errors="replace"):
                        l = l.split("#")[0].rstrip()
                        if l.strip():
                            f.write(l + "\n")
            if name != "file_contexts" or not os.path.exists(checkfc):
                # Ubuntu's libselinux lacks the Android property/service label backends checkfc
                # needs for -p/-s/-l/-v; validate the same two things in Python: every context
                # names a type of the compiled policy, and no key is given two different contexts.
                types_ok = set(re.findall(r"^\(type (\S+)\)", "".join(open(f).read() for f in plat + [O("vendor_sepolicy.cil"), O("plat_pub_versioned.cil")]), re.M))
                types_ok |= {unver_t for unver_t in re.findall(r"^\(typealias (\S+)\)", open(O("vendor_sepolicy.cil")).read(), re.M)}
                seen, errs = {}, []
                for l in open(merged):
                    parts = l.split()
                    if len(parts) < 2:
                        continue
                    key = parts[0]
                    cons = [x for x in parts[1:] if x.startswith("u:")]   # property_contexts: key ctx [exact type]
                    if not cons:
                        continue
                    con = cons[0]
                    t = con.split(":")[2] if con.count(":") >= 3 else con
                    if t not in types_ok:
                        errs.append("unknown type `%s` for `%s`" % (t, key))
                    if key in seen and seen[key] != con:
                        errs.append("`%s` has two contexts: %s and %s" % (key, seen[key], con))
                    seen.setdefault(key, con)
                rcf, txtf = (1, "\n".join(errs)) if errs else (0, "")
            else:
                rcf, txtf = run([checkfc] + flags + [pol, merged])
            ok_all &= rcf == 0
            report.append("- `%s` (%s, %d entries%s): **%s**%s" % (
                name, " + ".join(os.path.relpath(s, ROOT) for s in srcs), sum(1 for _ in open(merged)),
                ", checkfc" if name == "file_contexts" else ", types + duplicate keys checked in python",
                "PASS" if rcf == 0 else "FAIL", "" if rcf == 0 else "\n\n```\n" + txtf[-1500:] + "\n```"))
        seapp = os.path.join(args.vendor_dir, "seapp_contexts")
        if os.path.exists(checkseapp) and os.path.exists(seapp):
            rcs, txts = run([checkseapp, "-p", pol, "-o", "/dev/null",
                             os.path.join(sel, "plat_seapp_contexts"), seapp])
            ok_all &= rcs == 0
            report.append("- `seapp_contexts` (plat + ours): **%s**%s" % (
                "PASS" if rcs == 0 else "FAIL", "" if rcs == 0 else "\n\n```\n" + txts[-1500:] + "\n```"))
    else:
        ok_all = False

    # 6. the build's monolithic checks: sepolicy_neverallows (checkpolicy + sepolicy-analyze over
    #    public+private+vendor in one conf) and sepolicy.recovery (same, recovery flags, secilc).
    report += ["", "## build-time checks over the full monolithic policy", ""]
    mono = [os.path.join(S, "public"), os.path.join(S, "private"), os.path.join(L, "public"), os.path.join(L, "private")] + sysext_dirs + vendor_dirs
    sa = os.path.join(args.deps, "sepolicy-analyze")
    m4(flag + collect(mono), O("sepolicy_neverallows.conf"), args.variant)
    # (the build passes -N to checkpolicy here; Ubuntu's checkpolicy lacks it, so it checks neverallows
    #  itself, then sepolicy-analyze re-checks them the way the build does, with -w)
    rc5, txt5 = run(["checkpolicy", "-M", "-c", POLICY_VERS, "-o", O("sepolicy_neverallows.policy"), O("sepolicy_neverallows.conf")])
    how = "checkpolicy -M -c 30"
    if rc5 == 0 and os.path.exists(sa):
        # sepolicy-analyze gets a conf built with Exclude_build_test (target_exclude_build_test=true):
        # build_test_only() neverallows name expanded attributes and are only checked by checkpolicy.
        m4(flag + collect(mono), O("sepolicy_neverallows.analyze.conf"), args.variant, {"target_exclude_build_test": "true"})
        rc5, txt5 = run([sa, O("sepolicy_neverallows.policy"), "neverallow", "-w", "-f", O("sepolicy_neverallows.analyze.conf")])
        how += ", then sepolicy-analyze neverallow -w on the exclude_build_test conf"
    ok_all &= rc5 == 0
    fails = [l for l in txt5.splitlines() if "violated" in l or "neverallow" in l.lower()]
    report.append("- `sepolicy_neverallows` (%s, variant `%s`): **%s**" % (how, args.variant, "PASS" if rc5 == 0 else "FAIL, %d lines" % len(fails)))
    if rc5:
        report += ["", "```"] + [l[:300] for l in fails[:30]] + ["```", ""]
    m4(flag + collect(mono), O("recovery_sepolicy.conf"), args.variant, RECOVERY_DEFS)
    rc6, txt6 = run(["checkpolicy", "-C", "-M", "-c", POLICY_VERS, "-o", O("recovery_sepolicy.cil"), O("recovery_sepolicy.conf")])
    if rc6 == 0:
        rc6, txt6 = run(["secilc", "-m", "-M", "true", "-G", "-c", POLICY_VERS, "-o", "/dev/null", "-f", "/dev/null", O("recovery_sepolicy.cil")])
    ok_all &= rc6 == 0
    report.append("- `sepolicy.recovery` (recovery flags, checkpolicy -C then secilc with neverallows): **%s**" % ("PASS" if rc6 == 0 else "FAIL"))
    if rc6:
        report += ["", "```"] + [l[:300] for l in txt6.splitlines() if l.strip()][:30] + ["```", ""]

    report += ["", "Overall: **%s**" % ("PASS" if ok_all else "FAIL")]
    text = "\n".join(report) + "\n"
    print(text)
    if args.md:
        open(args.md, "w").write(text)
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
