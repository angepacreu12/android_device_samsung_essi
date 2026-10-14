# Observation of 29/09 (cleaned)

Origin: `observation_for_pending_task_at29_09_2026.md`, added at the repo root by `c6ef4db` with no sources. Per
`docs/TASK_1001_multi(1).md` (section "Modem network mode"), only cited facts are kept here; the original stays in
git history (`git show c6ef4db`). Upstream sources as in `docs/NETWORK_MODE_1001.md` (L-fb `5c05c66e`,
L-ot `6feb405d`).

## Kept: facts with a source

**Radio**
- Mode 33 is `NETWORK_MODE_NR_LTE_TDSCDMA_CDMA_EVDO_GSM_WCDMA` (L-fb `RILConstants.java:253`).
  - The original named it `NETWORK_MODE_NR_LTE_CDMA_EVDO_GSM_WCDMA`. That constant is 27, not 33.
- The framework enables NR only when the carrier config's `carrier_nr_availabilities_int_array` is non-empty
  (L-ot `GsmCdmaPhone.java:5299-5303`). The AOSP default already holds NSA and SA (L-fb
  `CarrierConfigManager.java:11162-11163`), so the overlay the original proposed only repeats the default.
- `ro.telephony.default_network` is set by **init** at `post-fs-data` from `ro.vendor.radio.default_network`, right
  after `secril_config_svc NetworkConfig` runs (`reference/ours/vendor/etc/init/init.vendor.rilcommon.rc:33-35`).

**IMS**
- PhhIms is the ImsService. `projects.txt` pins `packages/apps/PhhIms` to
  `https://github.com/xuanyayi/ims-for-wisdom` at `4562d77e`.
  - `device/device.mk:98-112` adds it, `android.hardware.telephony.ims.xml` and its privapp allowlist, guarded by
    `ifneq ($(wildcard packages/apps/PhhIms/Android.bp),)`.
  - VoLTE availability stays off in that step (`device/device.mk:103`). See `docs/IMS_0928.md`.

**Bluetooth audio**
- Nothing provides `android.hardware.bluetooth.audio.IBluetoothAudioProviderFactory/default`: init logged "Could not
  find" 119 times (`docs/BOOT_0927_3_evidence.txt:61`).
- Stock declares Samsung's `ISehBluetoothAudioProviderFactory/default` instead
  (`reference/stock/vendor/etc/vintf/manifest/seh_bluetooth_audio.xml:9`,
  `reference/stock/vendor/etc/selinux/vendor_service_contexts:51`).

**Camera, TEE**
- These files are in the stock vendor listing (`reference/stock/vendor_ls_Z.txt`):
  - `vendor.samsung.hardware.camera.provider-service_64` (:335), its `.rc` (:666) and its VINTF manifest (:1099);
  - `camera.s5e8855.so` (:2740) and `camera.unihal.default.so` (:2741);
  - `vendor.samsung.hardware.camera.provider-V1-ndk.so` (:2671) and `libsamsungcamerahal.so` (:2522);
  - `tzdaemon` (:264) and the TA `00000000-0000-0000-0000-46494e474502` (:2931).
- Whether each one is *needed* is not shown here. That belongs to the camera and fingerprint PRs.

## Dropped: no source, or wrong

| claim (original §) | why dropped |
|---|---|
| Set `ro.vendor.sec.radio.def_network`, `ro.vendor.radio.default_network`, `ro.telephony.default_network` to 33 (1.1) | the prop does not set the live mode, and mode 33 adds TD-SCDMA/CDMA/EvDo (`docs/NETWORK_MODE_1001.md` §1-2) |
| "`secril_config_svc` defaults to 9, stripping 5G" (1.1) | on stock 9 the live mode was 26, which includes NR (`docs/BOOT_0927_3_evidence.txt:76`, L-fb `RILConstants.java:232`) |
| `secril_config_svc` writes `ro.telephony.default_network` (1.1) | init does it (`init.vendor.rilcommon.rc:35`) |
| `ro.telephony.default_network=33,33` "provisions both slots" (1.1) | no source |
| `persist.vendor.radio.nr_mode=3`, `persist.radio.nr_mode=3` (1.1) | no source in `reference/` |
| IMS APN `ims` with `IPV4V6` (1.2) | no source given; IMS PDN evidence is in `docs/IMS_PDN_0928.md` |
| `config_device_volte_available`, `carrier_volte_available_bool`, `editable_enhanced_4g_lte_bool` (1.2) | the IMS PR decides these from its own evidence |
| `/dev/fimg2d`, `/sys/class/camera/flash/rear_flash`, `init.svc.sec-camera-provider` (2.1) | not checked against the stock listing or rc files |
| Software A2DP fallback props, `bluetooth_audio_policy_configuration_7_0.xml` (2.2) | no source; the task flags the copy path as wrong |
| Bridge daemon calling Samsung AIDL methods (2.2) | the methods are invented (task, "Claims in that guide…") |
| `calib_data.bin` fallback log, `/sys/class/lcd/panel/fingerprint` = 4294967295, `udfpsLocation=SensorLocation(0,0,0)` (3.1) | none appears in `docs/logs/diag_1001_1203/0[89]_*` (task, same section) |
| `config_udfps_sensor_props` = 0/2/540/1950/90 (3.1) | invented coordinates; not an AOSP 15 resource format (task) |
| `dmesg \| grep avc` (4.1), idle drain targets (4.2) | `dmesg` needs root here; the targets have no source |
