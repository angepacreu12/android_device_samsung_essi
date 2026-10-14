# Samsung fingerprint AIDL HAL (from LineageOS)

The files in this directory, except this README, are an unmodified copy of `aidl/fingerprint/` from
LineageOS `android_hardware_samsung`, branch `lineage-22.2`, commit `bb6e7b202f7deeeb5dd5a2f9a8c84d259e2cfe8b`
(https://github.com/LineageOS/android_hardware_samsung/tree/bb6e7b202f7deeeb5dd5a2f9a8c84d259e2cfe8b/aidl/fingerprint).
They are Copyright (C) 2024 The LineageOS Project and licensed under Apache-2.0, as their headers say.

Only this directory is copied. Pulling in the whole `hardware/samsung` project put its Soong namespace in the build,
and every module in it got installed (duplicate `secril_config_svc`, `vendor.samsung.hardware.radio.network-V1-ndk`,
`memtrack.xml`; docs/FINGERPRINT_1001.md §10.4-10.6).

Modules (`Android.bp`), in the `device/` namespace (`device/Android.bp`):
- `android.hardware.biometrics.fingerprint-service.samsung` (cc_binary, vendor), with `init_rc` and `vintf_fragments`
  from this directory.
- `android.hardware.biometrics.fingerprint.SamsungProps` (sysprop_library over `fingerprint.sysprop`).

Every include is either a file in this directory, the generated `fingerprint.sysprop.h`, or a header of an AOSP
library in `shared_libs` (`libbase`, `libbinder_ndk`, `libhardware` for `hardware/fingerprint.h` and
`hardware/hw_auth_token.h`, `android.hardware.biometrics.fingerprint-V4-ndk`, `android.hardware.biometrics.common-V4-ndk`,
`android.hardware.biometrics.common.util` for `util/Util.h`). No other file from `hardware/samsung` is needed.

At runtime it loads the stock `/vendor/lib64/libsfp_sensor.so` (`LegacyHAL.cpp:20-23`; `device/proprietary-files.txt`)
and reads `ro.vendor.fingerprint.*` from `device/vendor.prop`.
