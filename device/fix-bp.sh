#!/bin/bash
# SPDX-FileCopyrightText: 2026 dxjsk
# SPDX-License-Identifier: Apache-2.0
BP="$(dirname "$0")/../../../vendor/samsung/essi/Android.bp"
sed -i -E '/"(libaudio_aidl_conversion_common_ndk|libsensorndkbridge|libcodec2_aidl|libstagefright_aidl_bufferpool2|libbluetooth_audio_session_aidl|libcamera2ndk_vendor)",/d' "$BP"
# older AIDL versions Samsung blobs link against (installed via device.mk instead)
sed -i -E '/"android\.hardware\.(security\.keymint-V3|thermal-V1)-ndk",/d' "$BP"
# older AIDL versions Samsung blobs link against (installed via device.mk instead)
sed -i -E '/"android\.hardware\.(security\.keymint-V3|thermal-V1|biometrics\.common-V3)-ndk",/d' "$BP"
# libuuid: AOSP only has the static lib; Samsung's .so is installed via PRODUCT_COPY_FILES
sed -i -E '/"libuuid",?$/d' "$BP"
# system-only AOSP names; Samsung copies installed via PRODUCT_COPY_FILES
sed -i -E '/"(libalsautils|libalsautilsv2|libsoft_attestation_cert)",?$/d' "$BP"
# AOSP libs with restricted visibility; installed via PRODUCT_PACKAGES instead
sed -i -E '/"libvibratorutils",?$/d' "$BP"
# AOSP clang runtime module name (file is still libclang_rt.ubsan_standalone-aarch64-android.so)
sed -i 's/"libclang_rt\.ubsan_standalone-aarch64-android"/"libclang_rt.ubsan_standalone"/' "$BP"
# Rust dylibs: AOSP builds them; blobs dropped, deps stripped, installed via PRODUCT_PACKAGES
sed -i -E '/"lib[a-z0-9_]+\.dylib",?$/d' "$BP"
# AOSP protobuf vendor variants already produce the -21.12 filenames
sed -i 's/"libprotobuf-cpp-full-21.12"/"libprotobuf-cpp-full"/; s/"libprotobuf-cpp-lite-21.12"/"libprotobuf-cpp-lite"/' "$BP"
# 26/09 stock WiFi/BT/sensors HALs: the prebuilts share their module name with the AOSP HAL sources, and soong
# rejects the pair when both link different versions of one aidl_interface ("depends on multiple versions of the
# same aidl_interface": prebuilt wifi-V2 vs AOSP wifi-V3). Strip these deps; the .so files are installed by
# device.mk PRODUCT_PACKAGES (*.vendor), exactly like keymint-V3 above.
sed -i -E '/^[[:space:]]*"android\.hardware\.(wifi-V2|wifi\.common-V1|wifi\.supplicant-V3|wifi\.hostapd-V2|bluetooth-V1|bluetooth\.audio-V4|sensors-V2)-ndk",?$/d' "$BP"
# ELF check trips on the deps we stripped above; Samsung blobs are trusted as-is (idempotent: drop, then re-add)
sed -i '/^    check_elf_files: false,$/d' "$BP"
sed -i 's/^    prefer: true,$/    prefer: true,\n    check_elf_files: false,/' "$BP"
# 01/10 camera: the stock blobs call Samsung-only libsensorndkbridge symbols (ALooper_forCamera, 231x in
# docs/logs/diag_1001_1203/10_camera_isp.txt) that AOSP's libsensorndkbridge lacks. Load libshim_sensorndkbridge
# (device/shims/libsensorndkbridge) into them, like LineageOS gta4xl-common/sm8250-common extract-files.py do
# with blob_fixup().add_needed(). Same patchelf as extract-utils; idempotent (skip when already NEEDED).
ROOT="$(dirname "$0")/../../.."
PATCHELF="$ROOT/prebuilts/extract-tools/linux-x86/bin/patchelf-0_18"
for so in unihal_android.so libsensorlistener.so; do
    f="$ROOT/vendor/samsung/essi/proprietary/vendor/lib64/$so"
    [ -f "$f" ] || { echo "fix-bp: $f missing" >&2; continue; }
    readelf -d "$f" | grep -q 'Shared library: \[libshim_sensorndkbridge\.so\]' || "$PATCHELF" --add-needed libshim_sensorndkbridge.so "$f"
done
