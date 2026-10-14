#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
#
# Fill device/prebuilts/ from your own copy of the stock A566B firmware. Nothing produced here is committed
# (see .gitignore): the kernel, the kernel modules and the vendor_boot/recovery ramdisk binaries are Samsung's.
#
# Usage: tools/extract_prebuilts.sh <firmware dir>
#   <firmware dir> holds the unpacked stock images (from the AP tarball, lz4 -d'd; vendor_dlkm and system_dlkm
#   taken out of super.img with lpunpack):
#     boot.img  vendor_boot.img  dtbo.img  vendor_dlkm.img  system_dlkm.img
#
# Needs: python3, lz4, cpio, fsck.erofs (erofs-utils), and AOSP's unpack_bootimg.py
#   (system/tools/mkbootimg; set UNPACK_BOOTIMG=/path/to/unpack_bootimg.py if it is not on PATH).
set -euo pipefail

FW=${1:?usage: $0 <firmware dir>}
FW=$(cd "$FW" && pwd)
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=$ROOT/device/prebuilts
UNPACK=${UNPACK_BOOTIMG:-$(command -v unpack_bootimg || command -v unpack_bootimg.py || true)}
[ -n "$UNPACK" ] || { echo "unpack_bootimg not found: set UNPACK_BOOTIMG" >&2; exit 1; }

for f in boot.img vendor_boot.img dtbo.img vendor_dlkm.img system_dlkm.img; do
    [ -f "$FW/$f" ] || { echo "missing $FW/$f" >&2; exit 1; }
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Unpack a boot image with whichever form unpack_bootimg was found in
unpack() { case "$UNPACK" in *.py) python3 "$UNPACK" "$@" ;; *) "$UNPACK" "$@" ;; esac; }

# Decompress (lz4 or gzip, or plain) a ramdisk and extract its cpio into a directory
extract_ramdisk() {
    local in=$1 dir=$2 raw=$TMP/ramdisk.cpio
    mkdir -p "$dir"
    if lz4 -t "$in" 2>/dev/null; then lz4 -dcq "$in" > "$raw"
    elif gzip -t "$in" 2>/dev/null; then gzip -dc "$in" > "$raw"
    else cp "$in" "$raw"; fi
    (cd "$dir" && cpio -idmu --quiet --no-absolute-filenames < "$raw")
}

echo "== kernel (boot.img)"
unpack --boot_img "$FW/boot.img" --out "$TMP/boot" > /dev/null
install -m 0644 "$TMP/boot/kernel" "$OUT/kernel"

echo "== dtb (vendor_boot.img), dtbo"
unpack --boot_img "$FW/vendor_boot.img" --out "$TMP/vendor_boot" > /dev/null
install -m 0644 "$TMP/vendor_boot/dtb" "$OUT/dtb.img"
install -m 0644 "$FW/dtbo.img" "$OUT/dtbo.img"

echo "== vendor_boot ramdisk fragments"
n=0
for rd in "$TMP"/vendor_boot/vendor_ramdisk*; do
    extract_ramdisk "$rd" "$TMP/vr/$n"
    n=$((n + 1))
done

# Find one file by name in the unpacked ramdisks and copy it to device/prebuilts/vendor_ramdisk/
mkdir -p "$OUT/vendor_ramdisk"
take() {
    local hit
    hit=$(find "$TMP/vr" -name "$1" -type f | head -1)
    [ -n "$hit" ] || { echo "not found in vendor_boot ramdisks: $1" >&2; exit 1; }
    install -m 0644 "$hit" "$OUT/vendor_ramdisk/$1"
    echo "   $1  <- ${hit#$TMP/vr/}"
}
take mgfx2.0_mid.bin
take dpolicy
take gt9916k_a56x.bin
take android.hardware.boot-service.exynos_recovery
take android.hardware.boot-service.exynos.xml
take audit_filter_table

# Copy exactly the modules named in device/prebuilts/modules/<dir>/modules.list (tracked in git):
# BoardConfig.mk takes every .ko in the directory, so stray modules would change the images.
missing=0
take_modules() {
    local dir=$1 src=$2 sub=$3 m hit
    rm -f "$OUT/modules/$dir"/*.ko
    while read -r m; do
        [ -n "$m" ] || continue
        hit=$(find "$src" -path "*$sub/$m" -type f | head -1)
        if [ -n "$hit" ]; then install -m 0644 "$hit" "$OUT/modules/$dir/$m"
        else echo "   missing $dir/$m (modules.list)"; missing=1; fi
    done < "$OUT/modules/$dir/modules.list"
}

echo "== modules: vendor_boot"
# lib/modules/*.ko is the 4K-page kernel's set; the 16K fragment keeps its own copies in a subdirectory
take_modules vendor_boot "$TMP/vr" /lib/modules

for part in vendor_dlkm system_dlkm; do
    echo "== modules: $part"
    mkdir -p "$TMP/$part"
    fsck.erofs --extract="$TMP/$part" "$FW/$part.img" > /dev/null
    take_modules "$part" "$TMP/$part" ""
done

# The modules.load / modules.blocklist lists are tracked in git too: check every module they name exists
for dir in vendor_boot vendor_dlkm system_dlkm; do
    for list in "$OUT/modules/$dir"/modules.load "$OUT/modules/$dir"/modules.blocklist; do
        [ -f "$list" ] || continue
        while read -r m; do
            m=${m#blocklist }
            [ -n "$m" ] && [ "${m#\#}" = "$m" ] || continue
            [ -f "$OUT/modules/$dir/$(basename "$m")" ] || { echo "   missing $dir/$(basename "$m") ($(basename "$list"))"; missing=1; }
        done < "$list"
    done
done
[ $missing = 0 ] || { echo "some listed modules were not found in this firmware" >&2; exit 1; }

echo "done: $(find "$OUT/modules" -name '*.ko' | wc -l) modules, kernel, dtb, dtbo, 6 ramdisk files in $OUT"
