#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 dxjsk
# SPDX-License-Identifier: Apache-2.0
"""check_manifest.py - check 4: every HAL instance the stock vendor declares in VINTF must be declared by us.

servicemanager refuses to hand out an instance that is not in the VINTF manifest ("Could not find
mapper/stableC-impl-sgr in the VINTF manifest"), which is how the display HAL died on the first boot
past post-fs-data.  Compares reference/stock/vendor/etc/vintf/manifest.xml + manifest/*.xml with
device/manifest.xml + the fragments of our image (reference/ours/vendor/etc/vintf/manifest/*.xml) +
the stock fragments listed in DEVICE_MANIFEST_FILE (device/BoardConfig.mk).
"""
import argparse
import glob
import os
import re
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

# instances deliberately not shipped (see docs/IMAGE_GAPS.md, docs/VAULTKEEPER.md)
ALLOWLIST = {("vendor.samsung.hardware.security.vaultkeeper", "ISehVaultKeeper/default")}


def hals(path):
    out = {}
    root = ET.parse(path).getroot()
    for hal in root.findall("hal"):
        name = hal.findtext("name")
        fmt = hal.get("format", "hidl")
        vers = ",".join(v.text for v in hal.findall("version"))
        insts = [f.text for f in hal.findall("fqname")]
        for itf in hal.findall("interface"):
            for inst in itf.findall("instance"):
                insts.append("%s/%s" % (itf.findtext("name"), inst.text))
        for x in insts or ["(no instance)"]:
            out[(name, x)] = (fmt, vers, os.path.relpath(path, ROOT))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ref", default=os.path.join(ROOT, "reference"))
    ap.add_argument("--device", default=os.path.join(ROOT, "device"))
    ap.add_argument("--md")
    args = ap.parse_args()
    stock = {}
    stock.update(hals(os.path.join(args.ref, "stock/vendor/etc/vintf/manifest.xml")))
    for f in sorted(glob.glob(os.path.join(args.ref, "stock/vendor/etc/vintf/manifest/*.xml"))):
        stock.update(hals(f))
    ours = {}
    ours.update(hals(os.path.join(args.device, "manifest.xml")))
    for f in sorted(glob.glob(os.path.join(args.ref, "ours/vendor/etc/vintf/manifest/*.xml"))):
        ours.update(hals(f))
    bc = open(os.path.join(args.device, "BoardConfig.mk")).read()
    for m in re.findall(r"vintf/manifest/(\S+\.xml)", bc):
        p = os.path.join(args.ref, "stock/vendor/etc/vintf/manifest", m)
        if os.path.exists(p):
            ours.update(hals(p))
    missing = sorted(k for k in stock if k not in ours and k not in ALLOWLIST)
    skipped = sorted(k for k in stock if k not in ours and k in ALLOWLIST)
    rep = ["# check 4: VINTF manifest coverage", "",
           "Stock declares %d HAL instances (7 in its main `vendor/etc/vintf/manifest.xml`, the rest in fragments); "
           "ours declares %d (`device/manifest.xml`, fragments in the image, stock fragments merged via "
           "`DEVICE_MANIFEST_FILE`)." % (len(stock), len(ours)), ""]
    if missing:
        rep += ["## Declared by stock, missing in ours", ""]
        for name, inst in missing:
            fmt, vers, src = stock[(name, inst)]
            rep.append("- `%s` `%s` (format %s%s) from `%s`" % (name, inst, fmt, ", version " + vers if vers else "", src))
        rep.append("")
    if skipped:
        rep += ["Deliberately not shipped: " + ", ".join("`%s` `%s`" % k for k in skipped), ""]
    rep.append("Overall: **%s**" % ("PASS" if not missing else "FAIL (%d instances)" % len(missing)))
    text = "\n".join(rep) + "\n"
    print(text)
    if args.md:
        open(args.md, "w").write(text)
    return 0 if not missing else 1


if __name__ == "__main__":
    sys.exit(main())
