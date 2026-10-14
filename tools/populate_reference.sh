#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
#
# Fill reference/stock/ from your own copy of the stock A566B firmware (A566BXXS6AYGE). reference/stock is
# Samsung's content and is never committed (see .gitignore); tools/cil2te.py and the checks read it.
#
# Usage: tools/populate_reference.sh <vendor root> <odm root> <system root>
#   Each root is a partition mounted read-only, e.g.
#     sudo mount -o ro,loop vendor.img /mnt/stock/vendor        (images taken out of super.img with lpunpack)
#   Mount, don't extract: the `ls -laRZ` listings (vendor_ls_Z.txt, odm_ls_Z.txt) need the SELinux labels
#   that only a mount exposes. Alternatively, write those two files from a stock phone with
#     adb shell ls -laRZ /vendor > reference/stock/vendor_ls_Z.txt   (same for /odm)
#   and run this script with SKIP_LS_Z=1.
#
# reference/ours/ (the same files for the image *you* built) is produced the same way from your build's
# out/target/product/essi/{vendor,odm}: OUT_SUBDIR=ours tools/populate_reference.sh <vendor> <odm> <system>.
set -euo pipefail

VENDOR=${1:?usage: $0 <vendor root> <odm root> <system root>}
ODM=${2:?}
SYSTEM=${3:?}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
REF=$ROOT/reference/${OUT_SUBDIR:-stock}

copy_dir() {  # copy_dir <src dir> <dst dir>
    [ -d "$1" ] || { echo "missing $1" >&2; exit 1; }
    mkdir -p "$2"
    cp -a --no-preserve=ownership "$1"/. "$2"/
}

echo "== vendor: etc/selinux, etc/init, etc/vintf"
copy_dir "$VENDOR/etc/selinux" "$REF/vendor/etc/selinux"
copy_dir "$VENDOR/etc/init" "$REF/vendor/etc/init"
copy_dir "$VENDOR/etc/vintf" "$REF/vendor/etc/vintf"

echo "== odm: etc/selinux"
copy_dir "$ODM/etc/selinux" "$REF/odm/etc/selinux"

if [ "${OUT_SUBDIR:-stock}" = stock ]; then
    echo "== system: plat_file_contexts, plat_property_contexts"
    # system-as-root images keep the system tree under system/
    SYS_SE=$SYSTEM/system/etc/selinux
    [ -d "$SYS_SE" ] || SYS_SE=$SYSTEM/etc/selinux
    mkdir -p "$REF/system"
    for f in plat_file_contexts plat_property_contexts; do
        install -m 0644 "$SYS_SE/$f" "$REF/system/$f"
    done
fi

# ls -laRZ of a mounted partition, with the mount point rewritten to the on-device path (/vendor, /odm)
ls_z() {  # ls_z <mount point> <device path> <out file>
    local mnt=${1%/}
    (cd "$mnt" && LC_ALL=C ls -laRZ .) | sed -E "s#^\.(/[^:]*)?:\$#$2\1:#" > "$3"
    if ! grep -q ' u:object_r:' "$3"; then
        echo "no SELinux labels in $3: mount the image instead of extracting it, or use adb (see the header)" >&2
        exit 1
    fi
}

if [ "${SKIP_LS_Z:-0}" != 1 ]; then
    echo "== ls -laRZ listings"
    ls_z "$VENDOR" /vendor "$REF/vendor_ls_Z.txt"
    ls_z "$ODM" /odm "$REF/odm_ls_Z.txt"
fi

echo "done: $REF"
echo "next: tools/cil2te.py (regenerates device/sepolicy/vendor), then tools/run_checks.sh"
