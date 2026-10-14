#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 dxjsk
# SPDX-License-Identifier: Apache-2.0
"""check_services.py - acceptance check 3: every `service` of the stock vendor init scripts must be
startable under the new policy.

For each `service NAME /path/to/exe` in reference/stock/vendor/etc/init/**:
  * the executable's label (through our file_contexts, as in check 2) must be a type that exists in
    the compiled policy, and
  * the policy must contain a domain transition `type_transition init <exec_type>:process <domain>`
    (or the service has an explicit `seclabel u:r:<domain>:s0` whose domain exists).
This is exactly what init checks before starting a service ("does not have a SELinux domain defined")
and the failure that hung the boot on tzdaemon.  Uses the CIL produced by check_compile.py.
"""
import argparse
import collections
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from selabel_util import FileContexts, parse_ls_z, ROOT  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
TEEGRIS = {"tz_service", "tzts_service", "proca", "teed", "tee_service", "icccserv", "pa_daemon"}
KEYS = {"keymint", "gatekeeper", "keymaster", "skpm", "secureclock", "sharedsecret"}
MODEM = {"cbd", "rild", "ril-daemon", "vendor.rild", "secril", "shannon", "cpboot", "modem"}
EARLY = {"early-init", "init", "late-init", "early-fs", "fs", "post-fs", "late-fs", "post-fs-data"}


def parse_services(rcdir):
    """Return {name: dict(exe, file, seclabel, class, started_in)} from all *.rc files."""
    services = collections.OrderedDict()
    start_trigger = {}
    for rc in sorted(glob.glob(os.path.join(rcdir, "*.rc"))):
        cur = None
        trigger = None
        for line in open(rc, errors="replace"):
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            m = re.match(r"^service\s+(\S+)\s+(\S+)", s)
            if m:
                cur = m.group(1)
                services[cur] = {"exe": m.group(2), "file": os.path.basename(rc), "seclabel": None, "class": "default", "trigger": None}
                trigger = None
                continue
            m = re.match(r"^on\s+(.*)$", s)
            if m:
                trigger = m.group(1)
                cur = None
                continue
            if s.startswith("import"):
                cur = None
                continue
            if cur:
                if s.startswith("seclabel "):
                    services[cur]["seclabel"] = s.split()[1]
                elif s.startswith("class "):
                    services[cur]["class"] = " ".join(s.split()[1:])
            elif trigger:
                m = re.match(r"^(start|exec_start)\s+(\S+)", s)
                if m:
                    start_trigger.setdefault(m.group(2), trigger)
    for n, d in services.items():
        d["trigger"] = start_trigger.get(n)
    return services


def prio(name, exe, d):
    s = (name + " " + exe).lower()
    if any(k in s for k in TEEGRIS) or "tz" in name.lower() or "tee" in s:
        return 0, "TEEGRIS"
    if any(k in s for k in KEYS):
        return 1, "KeyMint/Gatekeeper"
    trig = (d.get("trigger") or "").split("&&")[0].strip()
    if d["class"].split()[0] in ("core", "early_hal") or trig in EARLY:
        return 2, "early-init..post-fs-data"
    if any(k in s for k in MODEM):
        return 3, "modem"
    return 4, "other"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ref", default=os.path.join(ROOT, "reference"))
    ap.add_argument("--vendor-dir", default=os.path.join(ROOT, "device/sepolicy/vendor"))
    ap.add_argument("--extra-dir", default=os.path.join(ROOT, "device/sepolicy_extra"))
    ap.add_argument("--compiled", default=os.path.join(HERE, "out/compile"),
                    help="output dir of check_compile.py (vendor_sepolicy.cil, plat_pub_versioned.cil)")
    ap.add_argument("--deps", default=os.path.join(HERE, "deps"))
    ap.add_argument("--md")
    args = ap.parse_args()
    ref = args.ref
    sel = os.path.join(ref, "system")
    plat_cils = [os.path.join(sel, "system/selinux/plat_sepolicy.cil"),
                 os.path.join(sel, "system_ext/selinux/system_ext_sepolicy.cil"),
                 os.path.join(sel, "product/selinux/product_sepolicy.cil")]
    vendor_cil = os.path.join(args.compiled, "vendor_sepolicy.cil")
    ppv = os.path.join(args.compiled, "plat_pub_versioned.cil")
    if not os.path.exists(vendor_cil):
        raise SystemExit("run tools/check_compile.py first (%s missing)" % vendor_cil)
    text = "".join(open(p).read() for p in plat_cils + [vendor_cil, ppv])
    vers = open(os.path.join(ref, "baseline/vendor/etc/selinux/plat_sepolicy_vers.txt")).read().strip()
    unver = lambda n: n[:-len(vers) - 1] if n.endswith("_" + vers) else n
    types = set(re.findall(r"^\(type (\S+)\)", text, re.M))
    aliases = {a: unver(b) for a, b in re.findall(r"^\(typealiasactual (\S+) (\S+)\)", text, re.M)}
    transitions = {}
    for src, tgt, res in re.findall(r"^\(typetransition (\S+) (\S+) process (\S+)\)", text, re.M):
        if unver(src) == "init":
            transitions[unver(tgt)] = unver(res)

    fc_sort = os.path.join(args.deps, "system_sepolicy/tests/fc_sort.py")
    fc = FileContexts([os.path.join(sel, "system/selinux/plat_file_contexts"),
                       os.path.join(sel, "system_ext/selinux/system_ext_file_contexts"),
                       os.path.join(sel, "product/selinux/product_file_contexts"),
                       os.path.join(ref, "baseline/vendor/etc/selinux/vendor_file_contexts"),
                       os.path.join(args.vendor_dir, "file_contexts"),
                       os.path.join(args.extra_dir, "file_contexts")], fc_sort=fc_sort)
    stock_fc = FileContexts([os.path.join(sel, "system/selinux/plat_file_contexts"),
                             os.path.join(ref, "stock/vendor/etc/selinux/vendor_file_contexts")])
    stock_files = {path for path, mode, t, name in parse_ls_z(os.path.join(ref, "stock/vendor_ls_Z.txt"))}
    shipped = set(os.listdir(os.path.join(ref, "ours/vendor/etc/init")))
    # binaries present in the vendor image our tree builds (reference/ours/vendor_ls_Z.txt)
    our_files = {path for path, mode, t, name in parse_ls_z(os.path.join(ref, "ours/vendor_ls_Z.txt"))}
    our_rcs = {os.path.basename(p) for p in our_files if p.startswith("/vendor/etc/init/")}
    if our_rcs:
        shipped = our_rcs   # the image listing is authoritative when available
    # Services our image's init scripts define, whatever the script is called: device/proprietary-files.txt
    # installs some stock scripts under another name (essi.<name>.rc, so that they do not clash with the AOSP
    # module of the same name), and the service is shipped all the same.
    our_services = parse_services(os.path.join(ref, "ours/vendor/etc/init"))

    excl = {}
    excl_path = os.path.join(HERE, "check_services_exclusions.txt")
    if os.path.exists(excl_path):
        for l in open(excl_path):
            l = l.split("#")[0].rstrip()
            if l.strip():
                name, _, why = l.partition("\t")
                excl[name.strip()] = why.strip()

    services = parse_services(os.path.join(ref, "stock/vendor/etc/init"))
    rows = []
    fails = 0
    for name, d in services.items():
        exe = d["exe"]
        real = re.sub(r"^/system/vendor/", "/vendor/", exe)   # /system/vendor is a symlink to /vendor
        label = fc.type_of(real, "-")
        stock_label = stock_fc.type_of(real, "-")
        if label in aliases:
            label = aliases[label]
        problems = []
        if label is None:
            problems.append("no file_contexts match")
        elif label not in types:
            problems.append("label `%s` not in policy" % label)
        if d["seclabel"]:
            dom = d["seclabel"].split(":")[2]
            domain = dom
            if dom not in types:
                problems.append("seclabel domain `%s` not in policy" % dom)
        else:
            domain = transitions.get(label)
            if label and label in types and domain is None:
                problems.append("no `type_transition init %s:process` (init would refuse to start it)" % label)
        if label and stock_label and label != stock_label:
            problems.append("stock labels it `%s`" % stock_label)
        if label in ("vendor_file", "system_file", "vendor_configs_file") and not d["seclabel"]:
            problems.append("generic label")
        note = None
        if problems and not real.startswith("/vendor/"):
            note = "system binary, not part of the vendor policy (does not exist on /e/OS)"
        elif problems and label == stock_label and not d["seclabel"] and domain is None:
            note = "same as stock: not startable there either (legacy entry)"
        if problems and real.startswith("/vendor/") and real not in stock_files:
            note = "no such binary in the stock vendor image either (legacy .rc entry)"
        ours = our_services.get(name)
        rc_shipped = d["file"] in shipped or ours is not None
        if real in our_files and not rc_shipped:
            problems.append("binary is in our vendor image but its init script `%s` is not: the service can never start"
                            % d["file"])
            note = None
            if name in excl:
                note = "kept out on purpose (tools/check_services_exclusions.txt): " + excl[name]
        ok = not problems or note is not None
        fails += 0 if ok else 1
        rc = d["file"] if not ours or ours["file"] == d["file"] else "%s (ours: %s)" % (d["file"], ours["file"])
        rows.append((prio(name, exe, d), name, exe, label, domain, rc, rc_shipped, problems, note))
    rows.sort(key=lambda r: (r[0][0], not r[6], r[1]))

    rep = ["# check 3: every stock vendor init service has a labeled executable and a domain", "",
           "%d services in `reference/stock/vendor/etc/init/*.rc`; %d have a problem (entries marked n/a are "
           "system binaries, services stock cannot start either, or services listed with a reason in "
           "`tools/check_services_exclusions.txt`). 'shipped in our image' is taken from "
           "`reference/ours/vendor_ls_Z.txt` and from the services defined by the scripts in "
           "`reference/ours/vendor/etc/init/` (a stock script installed under another name, e.g. `essi.<name>.rc`, "
           "counts as shipped), so it reflects that snapshot of the image." % (len(rows), fails), "",
           "| class | service | executable | exec label | domain | rc file | shipped in our image | result |",
           "|---|---|---|---|---|---|---|---|"]
    for (pn, pc), name, exe, label, domain, rc, shipped_flag, problems, note in rows:
        if not problems:
            res = "OK"
        elif note:
            res = "n/a: %s (%s)" % (note, "; ".join(problems))
        else:
            res = "**FAIL**: " + "; ".join(problems)
        rep.append("| %s | %s | `%s` | `%s` | `%s` | %s | %s | %s |" % (
            pc, name, exe, label, domain, rc, "yes" if shipped_flag else "no (removed)", res))
    rep += ["", "Overall: **%s**" % ("PASS" if fails == 0 else "FAIL (%d services)" % fails)]
    text = "\n".join(rep) + "\n"
    print(text)
    if args.md:
        open(args.md, "w").write(text)
    return 0 if fails == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
