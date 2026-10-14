# Stock vendor services missing from our vendor image

Status 26/09: items 1 and 3-9 below are applied by the `next-fixes` branch (proprietary-files.txt tail block,
device.mk, BoardConfig.mk, device/rootdir/etc/init/wifi.rc); the five new VINTF fragments must be present in
`vendor/samsung/essi/proprietary/vendor/etc/vintf/manifest/` like the four already referenced there.

Source of truth: every `service` in `reference/stock/vendor/etc/init/*.rc` (102), compared with the
files of the vendor image our tree builds (`reference/ours/vendor_ls_Z.txt`) and with
`device/proprietary-files.txt`. `tools/check_services.py` (check 3) computes the table on every run;
this document turns it into an ordered to-do list. Everything else in the stock init scripts
(display, touch, modem, audio, camera, NFC, biometrics, TEEGRIS, KeyMint/Gatekeeper) has both its
binary and its `.rc` in our image, or is a legacy entry without a binary on stock either
(`vcd`, `charon`, `wfc-pkt-router`, `dhcpcd`, `wpal`, `snap_utility_32`).

| # | service (stock `.rc`) | binary in ours | `.rc` in ours | needed for | verdict |
|---|---|---|---|---|---|
| 1 | `vndservicemanager` (`vndservicemanager.rc`, class core) | no | no | boot: every Samsung HAL that uses `/dev/vndbinder` (59 entries in `vndservice_contexts`); `onrestart class_restart main/hal/early_hal` | must ship |
| 2 | `vendor.keymint-default` (`android.hardware.security.keymint-service.rc`) | yes | no in this snapshot | boot: `vold` metadata encryption | fixed by PR #4 |
| 3 | `vendor.wifi_hal_legacy` (`android.hardware.wifi-service.rc`) | no | no | WiFi (`IWifi/default`) | ship stock |
| 4 | `wpa_supplicant` (`android.hardware.wifi.supplicant-service.rc`) | no | no | WiFi client | ship stock |
| 5 | `hostapd` (`hostapd.android.rc`) | no | no | hotspot | ship stock |
| 6 | `macloader`, `mfgloader` (`wifi.rc`) | yes | no | WiFi MAC/firmware load, `/data/vendor/wifi` dirs | ship a trimmed `wifi.rc` |
| 7 | `vendor.bluetooth-default` (`bluetooth-service-default.rc`) | no | no | Bluetooth (`IBluetoothHci/default`) | ship stock |
| 8 | `vendor.sensors-hal-multihal` (`android.hardware.sensors-service-multihal.rc`) | no | no | sensors (rotation, proximity, ...) | AOSP module |
| 9 | `vendor.dumpstate-default` (`dumpstate-default.rc`) | yes | no | bug reports only | ship `.rc` + manifest |
| - | `cass`, `vaultkeeper`, `vaultkeeper_aidl`, `vaultkeeper_hal` | no | no | Samsung relock stack | keep out (`docs/VAULTKEEPER.md`) |
| - | `vendor_flash_recovery` (`install-recovery.sh`) | no | no | Samsung's recovery overwrite | keep out |
| - | `wlandutservice` (`/system/bin`, `wifi.rc`) | n/a | - | Samsung factory WiFi test | keep out |

Display (`hwc3`, `graphics.allocator-sgr`, `memtrack`, `lights`), touch (`sysinput`, kernel driver),
modem (`cbd`, `rild`, `secril_config_svc`, `dmd`) need nothing from this list.

## Why these were missing

The binaries and `.rc` files whose names equal an AOSP module (`vndservicemanager`, `wpa_supplicant`,
`hostapd`, `android.hardware.wifi-service`, `android.hardware.bluetooth-service.default`,
`android.hardware.sensors-service.multihal`, `android.hardware.security.keymint-service`) were left
out of `proprietary-files.txt`, apparently to avoid module-name clashes. Two facts make that
unnecessary: `vendor/samsung/essi` is a Soong namespace (`PRODUCT_SOONG_NAMESPACES`), so a prebuilt
there may share its name with an AOSP module and wins for the product; and the KeyMint binary, which
has exactly such a clash, is already shipped that way and works. VINTF fragments are the exception the
tree already handles by merging them through `DEVICE_MANIFEST_FILE` in `BoardConfig.mk`.

`vndservicemanager` is in LineageOS 22.2 `build/make/target/product/base_vendor.mk` only under
`PRODUCT_PACKAGES_SHIPPING_API_LEVEL_29` (lines 102-105), i.e. for devices shipping with API 29 or lower.
`device/device.mk:25` sets `PRODUCT_SHIPPING_API_LEVEL := 35`, so it is never installed unless the
device adds it explicitly.

## Proposed changes, in order

### 1. Boot: vndservicemanager

`device/device.mk`:
```
# vndbinder service manager for Samsung's vendor-to-vendor binder HALs (vndservice_contexts)
PRODUCT_PACKAGES += \
    vndservicemanager
```
(AOSP module; installs `/vendor/bin/vndservicemanager` and its `vndservicemanager.rc`.)

### 2. Boot: KeyMint (done, PR #4)

`vendor/etc/init/android.hardware.security.keymint-service.rc` in `proprietary-files.txt`.

### 3. WiFi: HAL, supplicant, hostapd, loaders

`device/proprietary-files.txt` (all present in stock, all Samsung builds against the SLSI driver;
the AOSP alternatives need `lib_driver_cmd_slsi` sources this tree does not have):
```
vendor/bin/hw/android.hardware.wifi-service
vendor/bin/hw/wpa_supplicant
vendor/bin/hw/hostapd
vendor/etc/init/android.hardware.wifi-service.rc
vendor/etc/init/android.hardware.wifi.supplicant-service.rc
vendor/etc/init/hostapd.android.rc
vendor/etc/permissions/android.hardware.wifi.xml
vendor/etc/permissions/android.hardware.wifi.direct.xml
vendor/etc/permissions/android.hardware.wifi.aware.xml
vendor/etc/permissions/android.hardware.wifi.passpoint.xml
```
Their AIDL client libraries are not in our image; use the AOSP vendor variants as the tree already
does for KeyMint/thermal (`fix-bp.sh` strips the blob dependencies), `device/device.mk`:
```
PRODUCT_PACKAGES += \
    android.hardware.wifi-V2-ndk.vendor \
    android.hardware.wifi.common-V1-ndk.vendor \
    android.hardware.wifi.supplicant-V3-ndk.vendor \
    android.hardware.wifi.hostapd-V2-ndk.vendor
```
VINTF, `device/BoardConfig.mk` `DEVICE_MANIFEST_FILE +=`:
```
    vendor/samsung/essi/proprietary/vendor/etc/vintf/manifest/android.hardware.wifi-service.xml \
    vendor/samsung/essi/proprietary/vendor/etc/vintf/manifest/android.hardware.wifi.supplicant.xml \
    vendor/samsung/essi/proprietary/vendor/etc/vintf/manifest/android.hardware.wifi.hostapd.xml
```
(`IWifi` v2, `ISupplicant` v3, `IHostapd` v2, `/default` instances; they must also be pulled by
`extract-files` into `proprietary/vendor/etc/vintf/manifest/`, so list them in `proprietary-files.txt`
as well, exactly like the KeyMint fragments.)

`wifi.rc`: ship it, minus the `wlandutservice` block (`/system/bin` binary that does not exist on
/e/OS). Put the edited copy in `device/rootdir/etc/init/wifi.rc` and install it with
`PRODUCT_COPY_FILES += $(LOCAL_PATH)/rootdir/etc/init/wifi.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/wifi.rc`
rather than listing the stock file, so the removal is explicit. It creates `/data/vendor/wifi/*`,
fixes ownership of `/mnt/vendor/efs/wifi/.mac.info` and starts `macloader` in `post-fs-data`.

Firmware (`/vendor/firmware/wifi/mx140/*`), `/vendor/etc/wifi/*`, `libwifi-hal.so`, `wlbtd` and
`wifi_slsi.rc` are already in the image. Policy: `hal_wifi_default`, `hal_wifi_supplicant_default`,
`hal_wifi_hostapd_default`, `macloader`, `mfgloader` all have their stock rules and labels (check 3).

### 4. Bluetooth

`proprietary-files.txt`:
```
vendor/bin/hw/android.hardware.bluetooth-service.default
vendor/etc/init/bluetooth-service-default.rc
vendor/etc/permissions/android.hardware.bluetooth.xml
vendor/etc/permissions/android.hardware.bluetooth_le.xml
vendor/etc/vintf/manifest/bluetooth-service-default.xml
```
`device.mk`:
```
PRODUCT_PACKAGES += \
    android.hardware.bluetooth-V1-ndk.vendor \
    android.hardware.bluetooth.audio-V4-ndk.vendor \
    android.hardware.bluetooth.audio-impl
```
`BoardConfig.mk` `DEVICE_MANIFEST_FILE += .../bluetooth-service-default.xml` (`IBluetoothHci/default`).
The Samsung extension HAL `vendor.samsung.hardware.bluetooth-service` is already shipped; it does not
replace the core HCI HAL. `/vendor/etc/bluetooth/*` is present.

### 5. Sensors

The two Samsung sub-HALs (`sensors.sensorhub.so`, `sensors.inputvirtual.so`), `hals.conf` and the
HIDL 2.0/2.1 helper libraries are in our image; only the multihal host and its files are not. Shipped as the
stock blob `vendor/bin/hw/android.hardware.sensors-service.multihal` with its `.rc`,
`android.hardware.sensors-multihal.xml` (via `DEVICE_MANIFEST_FILE`) and `android.hardware.sensors-V2-ndk.vendor`.
LineageOS 22.2 `hardware/interfaces/sensors/aidl/default/multihal/Android.bp` only defines the static
library `android.hardware.sensors@aidl-multihal`; the name of an AOSP host binary could not be verified
from here, so the AOSP-module route is not used.

### 6. dumpstate

`proprietary-files.txt`: `vendor/etc/init/dumpstate-default.rc`, `vendor/etc/vintf/manifest/dumpstate-default.xml`
(the fragment is already merged in `BoardConfig.mk`; the binary is present).

## After the next build

Refresh `reference/ours/vendor_ls_Z.txt` and `reference/ours/vendor/etc/init/` from the new image and
re-run `tools/run_checks.sh`: check 3 must show no "binary is in our vendor image but its init
script is not" row, and `vndservicemanager`, `wpa_supplicant`, `hostapd`, the WiFi and Bluetooth
HALs and the sensors multihal must appear with their stock labels and domains.
