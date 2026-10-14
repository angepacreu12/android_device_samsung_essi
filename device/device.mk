#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

# Enable updating of APEXes
$(call inherit-product, $(SRC_TARGET_DIR)/product/updatable_apex.mk)

# A/B
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/android_t_baseline.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_ramdisk.mk)

PRODUCT_PACKAGES +=

PRODUCT_PACKAGES += \
    update_engine \
    update_engine_sideload \
    update_verifier

PRODUCT_PACKAGES += \
    checkpoint_gc \
    otapreopt_script

# API levels
PRODUCT_SHIPPING_API_LEVEL := 35

# fastbootd
PRODUCT_PACKAGES += \
    android.hardware.fastboot@1.1-impl-mock \
    fastbootd

# Health
PRODUCT_PACKAGES +=

# Kernel
PRODUCT_ENABLE_UFFD_GC := true

# Hardware/software feature XMLs (27/09, boot #3). SystemServer starts UsbService only if FEATURE_USB_HOST or
# FEATURE_USB_ACCESSORY is declared (frameworks/base services/java/com/android/server/SystemServer.java:2424-2430);
# without them "dumpsys usb" says "Can't find service: usb" (docs/BOOT_0927_3_evidence.txt:20) and the Phone app
# cannot be the default dialer (FEATURE_TELEPHONY). The list mirrors reference/stock/extra/vendor/permissions/
# (stock /vendor/etc/permissions) where frameworks/native/data/etc has the same file; see docs/BOOT_0927_3.md.
# Already installed elsewhere and therefore not repeated here: handheld_core_hardware.xml
# (build/target/product/full_base_telephony.mk:27), android.hardware.{bluetooth,bluetooth_le,wifi,wifi.aware,
# wifi.direct,wifi.passpoint}.xml (stock blobs, proprietary-files.txt) and android.software.sip.voip.xml
# (vendor/lineage/config/common.mk:79, product partition).
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.audio.low_latency.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.audio.low_latency.xml \
    frameworks/native/data/etc/android.hardware.audio.pro.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.audio.pro.xml \
    frameworks/native/data/etc/android.hardware.biometrics.face.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.biometrics.face.xml \
    frameworks/native/data/etc/android.hardware.camera.autofocus.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.autofocus.xml \
    frameworks/native/data/etc/android.hardware.camera.flash-autofocus.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.flash-autofocus.xml \
    frameworks/native/data/etc/android.hardware.camera.front.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.front.xml \
    frameworks/native/data/etc/android.hardware.camera.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.xml \
    frameworks/native/data/etc/android.hardware.fingerprint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.fingerprint.xml \
    frameworks/native/data/etc/android.hardware.keystore.app_attest_key.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.keystore.app_attest_key.xml \
    frameworks/native/data/etc/android.hardware.location.gps.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.location.gps.xml \
    frameworks/native/data/etc/android.hardware.nfc.ese.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.ese.xml \
    frameworks/native/data/etc/android.hardware.nfc.hce.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.hce.xml \
    frameworks/native/data/etc/android.hardware.nfc.hcef.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.hcef.xml \
    frameworks/native/data/etc/android.hardware.nfc.uicc.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.uicc.xml \
    frameworks/native/data/etc/android.hardware.nfc.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.xml \
    frameworks/native/data/etc/android.hardware.opengles.aep.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.opengles.aep.xml \
    frameworks/native/data/etc/android.hardware.se.omapi.ese.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.se.omapi.ese.xml \
    frameworks/native/data/etc/android.hardware.sensor.accelerometer.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.accelerometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.compass.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.compass.xml \
    frameworks/native/data/etc/android.hardware.sensor.gyroscope.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.gyroscope.xml \
    frameworks/native/data/etc/android.hardware.sensor.light.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.light.xml \
    frameworks/native/data/etc/android.hardware.sensor.proximity.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.proximity.xml \
    frameworks/native/data/etc/android.hardware.sensor.stepcounter.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.stepcounter.xml \
    frameworks/native/data/etc/android.hardware.sensor.stepdetector.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.stepdetector.xml \
    frameworks/native/data/etc/android.hardware.telephony.gsm.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.gsm.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.vulkan.compute-0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.compute.xml \
    frameworks/native/data/etc/android.hardware.vulkan.level-1.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.level.xml \
    frameworks/native/data/etc/android.hardware.vulkan.version-1_3.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.version.xml \
    frameworks/native/data/etc/android.software.device_id_attestation.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.device_id_attestation.xml \
    frameworks/native/data/etc/android.software.freeform_window_management.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.freeform_window_management.xml \
    frameworks/native/data/etc/android.software.ipsec_tunnels.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.ipsec_tunnels.xml \
    frameworks/native/data/etc/android.software.midi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.midi.xml \
    frameworks/native/data/etc/android.software.opengles.deqp.level-2024-03-01.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.opengles.deqp.level.xml \
    frameworks/native/data/etc/android.software.verified_boot.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.verified_boot.xml \
    frameworks/native/data/etc/android.software.vulkan.deqp.level-2024-03-01.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.vulkan.deqp.level.xml \
    frameworks/native/data/etc/com.nxp.mifare.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/com.nxp.mifare.xml

# android.hardware.hardware_keystore version="300" (stock vendor/permissions/android.hardware.hardware_keystore.xml)
# has no file in frameworks/native/data/etc; KeyMint ships versioned copies as prebuilt_etc modules
# (hardware/interfaces/security/keymint/aidl/default/Android.bp:134-139, vendor: true, sub_dir permissions).
PRODUCT_PACKAGES += \
    android.hardware.hardware_keystore_V3.xml

# Overlays (device/overlay: framework-res values, built as an RRO by the line below)
DEVICE_PACKAGE_OVERLAYS += $(LOCAL_PATH)/overlay
PRODUCT_ENFORCE_RRO_TARGETS := *

# IMS: PhhIms, open-source ImsService (docs/IMS_0928.md, docs/IMS_STEP1_0928.md). Step 1 of the plan: the app,
# its privapp allowlist and android.hardware.telephony.ims. Android creates the IMS phone only when that feature is
# declared (frameworks/opt/telephony PhoneFactory.java:255-263, :334-337), so feature and ImsService ship together or
# not at all: the whole block depends on packages/apps/PhhIms being in the tree (added by the build pipeline's
# projects.txt, not by the manifest). PhhImsOverlay (config_ims_mmtel_package=me.phh.ims) comes with PhhIms through
# its `required` (Android.bp:28). VoLTE availability (docs/IMS_1001.md §1): CarrierConfigOverlayEssi sets
# carrier_volte_available_bool for Free 208/15; the device half, config_device_volte_available, is in the overlay.
# Wi-Fi calling (docs/IMS_1001.md §2) also needs QualifiedNetworksService checked out at
# packages/services/QualifiedNetworksService (not in projects.txt: AOSP has no Android 15 tag for it). With it, the image
# gets Iwlan (Lineage manifest default.xml:808), QNS, overlay-wfc and the carrier config variant with the WFC keys
# (two overlays of the same vendor.xml replace each other, so exactly one of the two is installed).
ifneq ($(wildcard packages/apps/PhhIms/Android.bp),)
PRODUCT_PACKAGES += \
    PhhIms

ifneq ($(wildcard packages/services/QualifiedNetworksService/Android.bp),)
PRODUCT_PACKAGES += \
    Iwlan \
    QualifiedNetworksService \
    CarrierConfigOverlayEssiWfc

DEVICE_PACKAGE_OVERLAYS += $(LOCAL_PATH)/overlay-wfc
else
PRODUCT_PACKAGES += \
    CarrierConfigOverlayEssi
endif

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.telephony.ims.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.ims.xml \
    $(LOCAL_PATH)/configs/permissions/privapp-permissions-me.phh.ims.xml:$(TARGET_COPY_OUT_SYSTEM)/etc/permissions/privapp-permissions-me.phh.ims.xml
endif

# Partitions
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# Product characteristics
PRODUCT_CHARACTERISTICS := phone

# Rootdir (the stock vendor/bin init scripts come from proprietary-files.txt, "Init scripts")
PRODUCT_PACKAGES += \
    fstab.ramplus

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.s5e8855:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.s5e8855 \
    $(LOCAL_PATH)/rootdir/etc/fstab.s5e8855:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.s5e8855

# Stock wifi.rc without its wlandutservice block (a /system/bin factory-test binary /e/OS does not have);
# creates /data/vendor/wifi, fixes /mnt/vendor/efs/wifi/.mac.info and starts macloader in post-fs-data
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init/wifi.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/wifi.rc

# vndbinder service manager. Lineage 22.2 base_vendor.mk only installs it for
# PRODUCT_SHIPPING_API_LEVEL <= 29 (PRODUCT_PACKAGES_SHIPPING_API_LEVEL_29); ours is 35, and
# Samsung's HALs register 59 vndservices (device/sepolicy/vendor/vndservice_contexts + stock).
PRODUCT_PACKAGES += \
    vndservicemanager

# AIDL client libraries of the stock WiFi / Bluetooth / sensors HALs (blob deps stripped by fix-bp.sh)
PRODUCT_PACKAGES += \
    android.hardware.wifi-V2-ndk.vendor \
    android.hardware.wifi.common-V1-ndk.vendor \
    android.hardware.wifi.supplicant-V3-ndk.vendor \
    android.hardware.wifi.hostapd-V2-ndk.vendor \
    android.hardware.bluetooth-V1-ndk.vendor \
    android.hardware.bluetooth.audio-V4-ndk.vendor \
    android.hardware.sensors-V2-ndk.vendor
# Bluetooth audio (01/10, docs/BT_AUDIO_1001.md). Lineage's Bluetooth stack only talks to the AOSP
# android.hardware.bluetooth.audio IBluetoothAudioProviderFactory/default; Samsung's audio HAL serves
# its own vendor.samsung one (stock vendor_service_contexts:51) and never registered the AOSP one, even
# when it was declared (119 ctl.interface_start failures, docs/BOOT_0927_3_evidence.txt:61-63). The
# AOSP provider hands PCM to the audio HAL's Bluetooth stream through a per-process session map
# (hardware/interfaces bluetooth/audio/utils/aidl_session/BluetoothAudioSession.cpp:742-759), so the
# provider and an AOSP Bluetooth module (IModule/a2dp) run together in one vendor process:
# device/audio_bt. The AOSP provider library now has a process that registers it, so its
# vintf_fragments (bluetooth_audio.xml) declare a provided service (PR #16 rule). The stock blob of the
# same name is dropped from proprietary-files.txt so that only the AOSP module installs that path.
PRODUCT_PACKAGES += \
    android.hardware.audio.service-aidl.essi-bt \
    android.hardware.bluetooth.audio-impl

# Stock primary audio policy (reference/ours/vendor/etc/, pulled from the phone; 14243 bytes like stock
# vendor_ls_Z.txt:459 and ours :450) without its three BT A2DP device ports and routes. Samsung's primary module
# declared A2DP, so audioserver routed the headset to it, ahead of IModule/a2dp, and it stayed silent
# (docs/14_audio.txt, docs/BT_AUDIO_1001.md section 7). Replaces the blob line in proprietary-files.txt.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/audio/primary_audio_policy_configuration_sec_on_gsi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/primary_audio_policy_configuration_sec_on_gsi.xml

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH)

# Fingerprint: LineageOS's open-source Samsung AIDL HAL, copied into device/fingerprint (README there: LineageOS
# android_hardware_samsung bb6e7b20 aidl/fingerprint), in place of Samsung's loader service, which ignores
# onPointerDown so enrollment never starts a capture (docs/FINGERPRINT_1001.md §8-10). It drives the same stock
# /vendor/lib64/libsfp_sensor.so through ss_fingerprint_* (device/fingerprint/LegacyHAL.cpp:20-23). Same package as
# LineageOS sm7125-common b315034e common.mk:171-173. Copied rather than pulling all of hardware/samsung, whose namespace
# installs every module in it (§10.6). Samsung's HAL binary, rc and VINTF fragment are dropped from proprietary-files.txt (same service name
# vendor.fingerprint-default and same IFingerprint/default instance). Its props are in vendor.prop (Fingerprint).
PRODUCT_PACKAGES += \
    android.hardware.biometrics.fingerprint-service.samsung

# Inherit the proprietary files
$(call inherit-product, vendor/samsung/essi/essi-vendor.mk)

# AOSP libs that Samsung blobs load at runtime (deps stripped by fix-bp.sh)
PRODUCT_PACKAGES += \
    libaudio_aidl_conversion_common_ndk.vendor \
    libsensorndkbridge \
    libcodec2_aidl.vendor \
    libstagefright_aidl_bufferpool2.vendor \
    libbluetooth_audio_session_aidl \
    libcamera2ndk_vendor

# Samsung-only libsensorndkbridge symbols (ALooper_forCamera, ...) that the stock camera blobs call;
# fix-bp.sh adds it as NEEDED to them. Source: LineageOS gta4xl-common shims/libsensorndkbridge (docs/CAMERA_1001.md)
PRODUCT_PACKAGES += \
    libshim_sensorndkbridge

# Older AIDL versions Samsung blobs load at runtime (deps stripped by fix-bp.sh)
PRODUCT_PACKAGES += \
    android.hardware.security.keymint-V3-ndk.vendor \
    android.hardware.thermal-V1-ndk.vendor \
    android.hardware.biometrics.common-V3-ndk.vendor

# Older AIDL versions Samsung blobs load at runtime (deps stripped by fix-bp.sh)
PRODUCT_PACKAGES += \
    android.hardware.security.keymint-V3-ndk.vendor \
    android.hardware.thermal-V1-ndk.vendor \
    android.hardware.biometrics.common-V3-ndk.vendor

# Samsung libuuid.so (shared) — name clashes with AOSP's static libuuid
PRODUCT_COPY_FILES += \
    vendor/samsung/essi/proprietary/vendor/lib64/libuuid.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libuuid.so


# AOSP vendor dumpsys (replaces Samsung's vendor/bin/dumpsys blob)
PRODUCT_PACKAGES += \
    dumpsys_vendor

# AOSP aconfig read lib (replaces Samsung's vendor blob copy)
PRODUCT_PACKAGES += \
    libaconfig_storage_read_api_cc.vendor

# AOSP libs replacing Samsung blob copies (name clashes at Kati)
PRODUCT_PACKAGES += \
    libaudioaidlcommon.vendor \
    libbinderdebug.vendor \
    libcodec2_hal_common.vendor \
    libcodec2_hidl@1.1.vendor \
    libcodec2_hidl@1.2.vendor \
    libcodec2_simple_component.vendor \
    libcodec2_soft_common.vendor \
    libcppbor.vendor \
    libcppbor_external.vendor \
    libcppcose_rkp.vendor \
    libflatbuffers-cpp.vendor \
    libgrallocusage.vendor \
    libimage_io.vendor \
    libkeymaster4_1support.vendor \
    libmediautils_vendor.vendor \
    libmeminfo.vendor \
    libsfplugin_ccodec_utils.vendor \
    libstagefright_bufferpool@2.0.1.vendor \
    libtinyalsav2.vendor \
    libvibratorutils.vendor \
    libz_stable.vendor \
    server_configurable_flags.vendor \
    libcodec2_hidl_plugin \
    dumpsys_vendor


# AOSP Rust dylibs (replace Samsung blob copies)
PRODUCT_PACKAGES += \
libandroid_logger.vendor \
libandroid_log_sys.vendor \
libanyhow.vendor \
libatomic_rust.vendor \
libbitflags.vendor \
libbytemuck.vendor \
libcfg_if.vendor \
libenv_logger.vendor \
libgetrandom.vendor \
liblibc.vendor \
liblogger.vendor \
liblog_rust.vendor \
libmemoffset.vendor \
libnix.vendor \
libonce_cell.vendor \
librustutils.vendor \
libserde.vendor \
libstd.vendor \
libsystem_properties_bindgen_sys.vendor \
libthiserror.vendor \
libuuid.vendor
    # end

# AOSP protobuf (vendor variants carry the -21.12 suffix Samsung blobs expect)
PRODUCT_PACKAGES += \
    libprotobuf-cpp-full.vendor \
    libprotobuf-cpp-lite.vendor

# STMicro eSE HAL from source (hardware/st/secure_element2)
PRODUCT_PACKAGES += \
    android.hardware.secure_element-service.thales

# ---- Stock vendor_boot content (Samsung injects it at build time) ----
ESSI_VR := $(LOCAL_PATH)/rootdir/vendor_ramdisk_extra
# Samsung files from the stock vendor_boot/recovery ramdisks: not in git, tools/extract_prebuilts.sh fills it
ESSI_VR_BIN := $(LOCAL_PATH)/prebuilts/vendor_ramdisk

# GPU firmware: sgpu.ko requests it during first stage
PRODUCT_COPY_FILES += \
    $(ESSI_VR_BIN)/mgfx2.0_mid.bin:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/lib/firmware/sgpu/mgfx2.0_mid.bin \
    $(ESSI_VR_BIN)/mgfx2.0_mid.bin:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/lib/firmware/sgpu/mgfx2.0_mid.bin

# Defex policy + Samsung audit filter (stock kernel)
PRODUCT_COPY_FILES += \
    $(ESSI_VR_BIN)/dpolicy:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/dpolicy \
    $(ESSI_VR_BIN)/dpolicy:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/dpolicy \
    $(ESSI_VR_BIN)/audit_filter_table:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/audit_filter_table

# Touch firmware for recovery
PRODUCT_COPY_FILES += \
    $(ESSI_VR_BIN)/gt9916k_a56x.bin:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/vendor/firmware/tsp_goodix/gt9916k_a56x.bin

# Recovery: watchdog feeding, USB/adb, /efs dirs
PRODUCT_COPY_FILES += \
    $(ESSI_VR)/init.recovery.s5e8855.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.s5e8855.rc

# Recovery: Samsung boot control HAL (slots live in 'slotinfo'), needed for A/B sideload
PRODUCT_COPY_FILES += \
    $(ESSI_VR_BIN)/android.hardware.boot-service.exynos_recovery:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/hw/android.hardware.boot-service.exynos_recovery \
    $(ESSI_VR)/android.hardware.boot-service.exynos_recovery.rc:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/init/android.hardware.boot-service.exynos_recovery.rc \
    $(ESSI_VR_BIN)/android.hardware.boot-service.exynos.xml:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/vintf/manifest/android.hardware.boot-service.exynos.xml


# First-stage fsck for /metadata (fstab 'check' flag)
PRODUCT_PACKAGES += \
    linker.vendor_ramdisk \
    e2fsck.vendor_ramdisk \
    fsck.f2fs.vendor_ramdisk


# Optional: put your own adb public key (~/.android/adbkey.pub) in device/adb_keys (gitignored)
ifneq ($(wildcard $(LOCAL_PATH)/adb_keys),)
PRODUCT_ADB_KEYS := $(LOCAL_PATH)/adb_keys

# Recovery adbd reads /adb_keys: ship our key there explicitly (never rely on stale out/ files)
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/adb_keys:$(TARGET_COPY_OUT_RECOVERY)/root/adb_keys

# A15: recovery /adb_keys is a symlink to /product/etc/security/adb_keys -> ship the target inside the recovery ramdisk
PRODUCT_COPY_FILES += $(LOCAL_PATH)/adb_keys:$(TARGET_COPY_OUT_RECOVERY)/root/product/etc/security/adb_keys
endif

# Boot log catcher (debug, off by default, size-capped): dmesg/logcat/props to /metadata/essi_log every 2 s during boot
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/bootlog/essi_bootlog.sh:$(TARGET_COPY_OUT_VENDOR)/bin/essi_bootlog.sh \
    $(LOCAL_PATH)/bootlog/essi_bootlog.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/essi_bootlog.rc

# Stock *system* init.rilcommon.rc:68-81,89-90 copies the ro.boot.*.param.offset bootconfig values into
# ro.vendor.boot.* for the vendor RIL; Lineage's system has no such script, so rild logs "Not support read boot
# param (ro.vendor.boot.carrierid.param.offset)" (27/09). Same six mappings, from a vendor script.
PRODUCT_COPY_FILES += $(LOCAL_PATH)/rootdir/etc/init/essi.rilcommon.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/essi.rilcommon.rc

# KeyMint HAL start script (was missing: vold hung waiting for IKeyMintDevice, 26/09)
PRODUCT_COPY_FILES += $(LOCAL_PATH)/rootdir/etc/init/essi.keymint-service.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/essi.keymint-service.rc
