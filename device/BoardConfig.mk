#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/samsung/essi

# A/B
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    init_boot \
    dtbo \
    odm \
    product \
    system \
    system_dlkm \
    system_ext \
    vbmeta \
    vendor \
    vendor_boot \
    vendor_dlkm
BOARD_USES_RECOVERY_AS_BOOT := false

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 := 
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a76

# Bootloader
TARGET_BOOTLOADER_BOARD_NAME := s5e8855
TARGET_NO_BOOTLOADER := true

# Display
TARGET_SCREEN_DENSITY := 450
TARGET_USES_VULKAN := true

# Kernel
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_BASE := 0x10000000
BOARD_KERNEL_CMDLINE := panic_on_warn=0 bootconfig loop.max_part=7
BOARD_KERNEL_PAGESIZE := 2048
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_KERNEL_SEPARATED_DTBO := true
TARGET_KERNEL_CONFIG := essi_defconfig
TARGET_KERNEL_SOURCE := kernel/samsung/essi

# Kernel - prebuilt
TARGET_FORCE_PREBUILT_KERNEL := true
ifeq ($(TARGET_FORCE_PREBUILT_KERNEL),true)
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilts/kernel
TARGET_PREBUILT_DTB := $(DEVICE_PATH)/prebuilts/dtb.img
BOARD_MKBOOTIMG_ARGS += --dtb $(TARGET_PREBUILT_DTB)
BOARD_INCLUDE_DTB_IN_BOOTIMG := 
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilts/dtbo.img
BOARD_KERNEL_SEPARATED_DTBO := 
endif

# Partitions
BOARD_FLASH_BLOCK_SIZE := 131072 # (BOARD_KERNEL_PAGESIZE * 64)
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_DTBOIMG_PARTITION_SIZE := 8388608
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 16777216
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 117440512
BOARD_SUPER_PARTITION_SIZE := 14680064000
BOARD_SUPER_PARTITION_GROUPS := group_basic
BOARD_GROUP_BASIC_PARTITION_LIST := odm product system system_dlkm system_ext vendor vendor_dlkm
BOARD_GROUP_BASIC_SIZE := 14675869696

# Platform
TARGET_BOARD_PLATFORM := erd8855

# Properties
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop
TARGET_PRODUCT_PROP += $(DEVICE_PATH)/product.prop
TARGET_SYSTEM_EXT_PROP += $(DEVICE_PATH)/system_ext.prop
TARGET_SYSTEM_DLKM_PROP += $(DEVICE_PATH)/system_dlkm.prop
TARGET_ODM_PROP += $(DEVICE_PATH)/odm.prop
TARGET_ODM_DLKM_PROP += $(DEVICE_PATH)/odm_dlkm.prop
TARGET_VENDOR_DLKM_PROP += $(DEVICE_PATH)/vendor_dlkm.prop

# Recovery
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.s5e8855
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# Security patch level

# Verified Boot
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
# BOARD_AVB_VENDOR_BOOT_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
# BOARD_AVB_VENDOR_BOOT_ALGORITHM := SHA256_RSA4096
# BOARD_AVB_VENDOR_BOOT_ROLLBACK_INDEX := 1
# BOARD_AVB_VENDOR_BOOT_ROLLBACK_INDEX_LOCATION := 1

# VINTF
DEVICE_MANIFEST_FILE += $(DEVICE_PATH)/manifest.xml

# Inherit the proprietary files
include vendor/samsung/essi/BoardConfigVendor.mk

# Samsung VINTF fragments (module names clash with AOSP's, so merged here)
DEVICE_MANIFEST_FILE += \
    vendor/samsung/essi/proprietary/vendor/etc/vintf/manifest/android.hardware.security.keymint-service.xml \
    vendor/samsung/essi/proprietary/vendor/etc/vintf/manifest/android.hardware.security.secureclock-service.xml \
    vendor/samsung/essi/proprietary/vendor/etc/vintf/manifest/android.hardware.security.sharedsecret-service.xml \
    vendor/samsung/essi/proprietary/vendor/etc/vintf/manifest/dumpstate-default.xml \
    vendor/samsung/essi/proprietary/vendor/etc/vintf/manifest/android.hardware.wifi-service.xml \
    vendor/samsung/essi/proprietary/vendor/etc/vintf/manifest/android.hardware.wifi.supplicant.xml \
    vendor/samsung/essi/proprietary/vendor/etc/vintf/manifest/android.hardware.wifi.hostapd.xml \
    vendor/samsung/essi/proprietary/vendor/etc/vintf/manifest/bluetooth-service-default.xml \
    vendor/samsung/essi/proprietary/vendor/etc/vintf/manifest/android.hardware.sensors-multihal.xml

# Kernel modules (built from Samsung opensource AYGE)
MODULES_DIR := $(DEVICE_PATH)/prebuilts/modules

BOARD_VENDOR_RAMDISK_KERNEL_MODULES := $(wildcard $(MODULES_DIR)/vendor_boot/*.ko)
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD := $(addprefix $(MODULES_DIR)/vendor_boot/,$(shell cat $(MODULES_DIR)/vendor_boot/modules.load))

BOARD_VENDOR_KERNEL_MODULES := $(wildcard $(MODULES_DIR)/vendor_dlkm/*.ko)
BOARD_VENDOR_KERNEL_MODULES_LOAD := $(addprefix $(MODULES_DIR)/vendor_dlkm/,$(shell cat $(MODULES_DIR)/vendor_dlkm/modules.load))
BOARD_USES_VENDOR_DLKMIMAGE := true
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm

BOARD_SYSTEM_KERNEL_MODULES := $(wildcard $(MODULES_DIR)/system_dlkm/*.ko)
BOARD_SYSTEM_KERNEL_MODULES_LOAD := $(addprefix $(MODULES_DIR)/system_dlkm/,$(shell cat $(MODULES_DIR)/system_dlkm/modules.load))
BOARD_USES_SYSTEM_DLKMIMAGE := true
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# Vendor AIDs used by Samsung init scripts
TARGET_FS_CONFIG_GEN += $(DEVICE_PATH)/config.fs

# Logical partitions (stock layout, all erofs)
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_EROFS_COMPRESSOR := lz4hc

TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_ODM := odm

# Chained vbmeta for the system half (matches stock layout)
# BOARD_AVB_VBMETA_SYSTEM := system system_ext product
# BOARD_AVB_VBMETA_SYSTEM_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
# BOARD_AVB_VBMETA_SYSTEM_ALGORITHM := SHA256_RSA4096
# BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX := 1
# BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION := 2

# Samsung vendor-namespace HALs (not in the AOSP framework matrix)
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE += $(DEVICE_PATH)/framework_compatibility_matrix.xml

# Device-specific HALs not in the AOSP framework compatibility matrix
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE += $(DEVICE_PATH)/framework_compatibility_matrix.xml

# init_boot holds the generic ramdisk on A15-launch devices; recovery moves to vendor_boot
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true
# BOARD_AVB_INIT_BOOT_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
# BOARD_AVB_INIT_BOOT_ALGORITHM := SHA256_RSA4096
# BOARD_AVB_INIT_BOOT_ROLLBACK_INDEX := 1
# BOARD_AVB_INIT_BOOT_ROLLBACK_INDEX_LOCATION := 3

# Match stock boot image headers
BOARD_INIT_BOOT_HEADER_VERSION := 4
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset 0x00000000 --tags_offset 0x00000000 --board SRPXH01A006
BOARD_MKBOOTIMG_INIT_ARGS += --header_version $(BOARD_INIT_BOOT_HEADER_VERSION)

# GKI generic ramdisk layout (first_stage_ramdisk skeleton) + LZ4 like stock
BOARD_USES_GENERIC_KERNEL_IMAGE := true
BOARD_RAMDISK_USE_LZ4 := true

# Mount points used by the stock fstab (prism, optics) and by the stock vendor init: init.s5e8855.rc:379-380
# (shipped unchanged) mounts the sec_efs partition on /efs at `on fs`. Without the directory that mount fails and
# /efs does not exist (27/09, build 19:12), so init.vendor.onebinary.rc:10-13 cannot copy factory.prop to
# /efs/imei right before sim_config runs. A directory, not a symlink to /mnt/vendor/efs: see docs/CSC_0927.md
# section 2c. Label: efs_file (system/sepolicy private/file_contexts:858; stock plat_file_contexts:658).
BOARD_ROOT_EXTRA_FOLDERS := prism optics efs
# Stock vendor_boot bootconfig
BOARD_BOOTCONFIG += androidboot.serialconsole=0

# Stock system_dlkm blocklist (GKI zram replaced by Samsung vendor_zram, ptp_kvm unused)
BOARD_SYSTEM_KERNEL_MODULES_BLOCKLIST_FILE := $(MODULES_DIR)/system_dlkm/modules.blocklist

# Match stock AYGE patch level (never announce a newer one to the bootloader/TEE)
BOOT_SECURITY_PATCH := 2025-08-01
VENDOR_SECURITY_PATCH := 2025-08-01

# Root mount points for the fstab (25/09: missing /metadata -> first-stage init fatal)
BOARD_USES_METADATA_PARTITION := true
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_CACHEIMAGE_PARTITION_SIZE := 41943040


# SELinux: vendor policy generated from Samsung stock policy (essi-device PR #1/#2)
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# Hand-written vendor policy (not overwritten by the essi-device sync of sepolicy/)
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy_extra

# Device system_ext policy (27/09): public property types Samsung's system side gives the RIL daemons
# (rild_prop, multisim_prop) and their property_contexts; vendor rules on them live in sepolicy_extra.
# Same mechanism as Lineage's own (device/lineage/sepolicy/common/sepolicy.mk:12-16). docs/MODEM_0927.md.
SYSTEM_EXT_PUBLIC_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy_system_ext/public
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy_system_ext/private
