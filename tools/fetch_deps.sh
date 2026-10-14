#!/bin/sh
# SPDX-FileCopyrightText: 2026 dxjsk
# SPDX-License-Identifier: Apache-2.0
# Fetch the open-source policy sources the checks need to replay the Android 15 vendor policy build:
#   system/sepolicy      (LineageOS 22.2 = Android 15, same public types as our system image)
#   device/lineage/sepolicy (the vendor baseline every Lineage build includes)
# Both land in tools/deps/ (git-ignored).  Host tools: secilc, checkpolicy, m4, python3, libselinux1.
set -e
cd "$(dirname "$0")"
mkdir -p deps
BR=${LINEAGE_BRANCH:-lineage-22.2}
[ -d deps/system_sepolicy ]  || git clone --depth 1 -b "$BR" https://github.com/LineageOS/android_system_sepolicy.git deps/system_sepolicy
[ -d deps/lineage_sepolicy ] || git clone --depth 1 -b "$BR" https://github.com/LineageOS/android_device_lineage_sepolicy.git deps/lineage_sepolicy
for t in secilc checkpolicy m4 python3; do
    command -v $t >/dev/null || echo "missing host tool: $t (Ubuntu: apt install secilc checkpolicy m4 python3)"
done
# checkfc / checkseapp from system/sepolicy/tools (optional, used for the contexts validation step)
if command -v gcc >/dev/null && [ ! -x deps/checkfc ]; then
    gcc -O2 -o deps/checkfc deps/system_sepolicy/tools/checkfc.c -Wl,-Bstatic -lsepol -Wl,-Bdynamic -lselinux 2>/dev/null \
        || echo "checkfc not built (need libsepol-dev, libselinux1-dev)"
    gcc -O2 -DPCRE2_CODE_UNIT_WIDTH=8 -o deps/checkseapp deps/system_sepolicy/tools/check_seapp.c \
        -Wl,-Bstatic -lsepol -Wl,-Bdynamic -lselinux -lpcre2-8 2>/dev/null \
        || echo "checkseapp not built (need libsepol-dev, libselinux1-dev, libpcre2-dev)"
fi
if command -v gcc >/dev/null && [ ! -x deps/sepolicy-analyze ]; then
    gcc -O2 -o deps/sepolicy-analyze deps/system_sepolicy/tools/sepolicy-analyze/*.c \
        -Ideps/system_sepolicy/tools/sepolicy-analyze -Wl,-Bstatic -lsepol -Wl,-Bdynamic 2>/dev/null \
        || echo "sepolicy-analyze not built (need libsepol-dev)"
fi
echo "deps ready in $(pwd)/deps"
