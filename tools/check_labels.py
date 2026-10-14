#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 dxjsk
# SPDX-License-Identifier: Apache-2.0
"""check_labels.py - acceptance check 2: every file of the stock vendor image must get Samsung's label.

For every entry of reference/stock/vendor_ls_Z.txt the label our file_contexts would assign (looked up
through libselinux, over plat + system_ext + product + baseline vendor + our vendor file_contexts, in
the order the platform concatenates them) must equal the stock label.  Every mismatch is reported.
The same lookup with the *current* (baseline-only) vendor_file_contexts is shown for comparison.
"""
import argparse
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from selabel_util import FileContexts, parse_ls_z, ROOT  # noqa: E402

PRIORITY = [
    ("TEEGRIS", ("tzdaemon", "tzts", "tee", "proca", "tz_", "iccc", "pa_daemon", "mobicore", "secure_storage")),
    ("KeyMint/Gatekeeper", ("keymint", "gatekeeper", "keymaster", "skpm", "fkeymaster")),
    ("modem", ("cbd", "rild", "ril", "modem", "slsi", "shannon")),
]


def prio(path, label):
    s = (path + " " + label).lower()
    for name, keys in PRIORITY:
        if any(k in s for k in keys):
            return name
    return "other"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ref", default=os.path.join(ROOT, "reference"))
    ap.add_argument("--vendor-dir", default=os.path.join(ROOT, "device/sepolicy/vendor"))
    ap.add_argument("--extra-dir", default=os.path.join(ROOT, "device/sepolicy_extra"))
    ap.add_argument("--deps", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "deps"))
    ap.add_argument("--md")
    ap.add_argument("--max", type=int, default=80, help="max mismatches listed per group")
    args = ap.parse_args()
    ref = args.ref
    sel = os.path.join(ref, "system")
    plat = [os.path.join(sel, "system/selinux/plat_file_contexts"),
            os.path.join(sel, "system_ext/selinux/system_ext_file_contexts"),
            os.path.join(sel, "product/selinux/product_file_contexts")]
    baseline = os.path.join(ref, "baseline/vendor/etc/selinux/vendor_file_contexts")
    ours = os.path.join(args.vendor_dir, "file_contexts")
    extra = os.path.join(args.extra_dir, "file_contexts")   # hand-written dir; FileContexts skips it if absent
    fc_sort = os.path.join(args.deps, "system_sepolicy/tests/fc_sort.py")
    new = FileContexts(plat + [baseline, ours, extra], fc_sort=fc_sort)
    old = FileContexts(plat + [baseline], fc_sort=fc_sort)

    entries = list(parse_ls_z(os.path.join(ref, "stock/vendor_ls_Z.txt")))
    total = len(entries)
    mism = collections.defaultdict(list)
    old_mism = 0
    by_prio = collections.Counter()
    by_prio_bad = collections.Counter()
    for path, mode, want, name in entries:
        got = new.type_of(path, mode)
        p = prio(path, want)
        by_prio[p] += 1
        if got != want:
            mism[(want, got)].append(path)
            by_prio_bad[p] += 1
        if old.type_of(path, mode) != want:
            old_mism += 1
    bad = sum(len(v) for v in mism.values())
    rep = ["# check 2: labels of every stock vendor file", "",
           "Lookup: libselinux `selabel_lookup` over plat + system_ext + product file_contexts, the baseline "
           "vendor_file_contexts of the no-device-policy build (`reference/baseline`, %d entries), `device/sepolicy/vendor/file_contexts` and `device/sepolicy_extra/file_contexts`."
           % sum(1 for l in open(baseline) if l.strip() and not l.startswith("#")), "",
           "| | entries | mismatches |", "|---|---|---|",
           "| current tree (baseline only) | %d | %d |" % (total, old_mism),
           "| with the new vendor policy | %d | **%d** |" % (total, bad), "",
           "By priority class (new policy): " + ", ".join("%s %d/%d" % (k, by_prio_bad[k], by_prio[k]) for k, _ in PRIORITY + [("other", ())]),
           ""]
    if mism:
        rep += ["## Mismatches (stock label -> label we would give)", ""]
        for (want, got), paths in sorted(mism.items(), key=lambda kv: -len(kv[1])):
            rep.append("- `%s` -> `%s` (%d): %s%s" % (want, got, len(paths), ", ".join("`%s`" % p for p in paths[:8]),
                                                       " ..." if len(paths) > 8 else ""))
        rep.append("")
    rep += ["Overall: **%s**" % ("PASS" if bad == 0 else "FAIL (%d mismatches)" % bad)]
    text = "\n".join(rep) + "\n"
    print(text)
    if args.md:
        open(args.md, "w").write(text)
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
