# Fingerprint (under-display): where the sensor geometry comes from (01/10, PR D)

Task: `docs/TASK_1001_multi(1).md` PR D. Symptom (Ange): the enroll zone never appears.

**Outcome: one overlay change (section 7).** The HAL reports an **optical UDFPS** with an **empty location** (section 6),
so SystemUI draws its overlay but its sensor area is 0,0-0,0 and no touch reaches the HAL. The location now comes from
the stock driver's own value (`/sys/class/fingerprint/fingerprint/position`, from the device tree) converted to pixels with
a cited open-source formula: **x 540, y 2039, radius 113**, set through `config_sfps_sensor_props`.
The 540 / 1950 / 90 values from `observation_for_pending_task_at29_09_2026.md:220-228` stay out: no source.

Citation keys:
- `FR :N` = line N of `zcat reference/stock/extra/system/framework-res.resources.txt.gz` (stock framework-res, A566BXXS6AYGE).
- `RRO :N` = line N of `zcat reference/stock/extra/vendor/overlay_framework-res__a56xnaxx__auto_generated_rro_vendor.resources.txt.gz`.
- `LOS fb` = `LineageOS/android_frameworks_base` @ `lineage-22.2` = `5c05c66e872c907a925f633b69f11661c59e7ad0`.
- `LOS hi` = `LineageOS/android_hardware_interfaces` @ `lineage-22.2` = `89252f8fa9f56b373581beee2ca0ffe19bfdcd93`,
  path `biometrics/fingerprint/aidl/android/hardware/biometrics/fingerprint/`.
- `LOS hs` = `LineageOS/android_hardware_samsung` @ `lineage-22.2` = `bb6e7b202f7deeeb5dd5a2f9a8c84d259e2cfe8b`.
- `diag/0N` = `docs/logs/diag_1001_1203/0N_*.txt`.

## 1. Facts

### 1.1 Which HAL we run
- One fingerprint HAL: Samsung's binary `/vendor/bin/hw/vendor.samsung.hardware.biometrics.fingerprint-service`
  (`reference/stock/vendor_ls_Z.txt:333`, ours `reference/ours/vendor_ls_Z.txt:330`, `device/proprietary-files.txt:376`),
  service `vendor.fingerprint-default`, `class late_start`, `user system`, `group system input`
  (`reference/ours/vendor/etc/init/vendor.samsung.hardware.biometrics.fingerprint-service.rc:1-5`).
- It declares the **standard AIDL** `android.hardware.biometrics.fingerprint` **v3** `IFingerprint/default`
  (`reference/ours/vendor/etc/vintf/manifest/vendor.samsung.hardware.biometrics.fingerprint-service.xml:6-10`, same in stock).
  So the framework talks to it as an AIDL provider, not HIDL.
- Also shipped from stock: `vendor/apex/com.samsung.android.biometrics.fingerprint.signed.apex`
  (`reference/stock/vendor_ls_Z.txt:31`, `device/proprietary-files.txt:360`) and the Samsung extension interface lib
  `vendor.samsung.hardware.biometrics.fingerprint-V1-ndk.so` (`reference/stock/vendor_ls_Z.txt:2666`, `device/proprietary-files.txt:1056`).
- Side note, no action: `/vendor/lib64/android.hardware.biometrics.fingerprint-V3-ndk.so` is 151576 bytes on stock
  (`reference/stock/vendor_ls_Z.txt:2162`) and 135424 bytes on ours (`reference/ours/vendor_ls_Z.txt:2158`); it is not in
  `device/proprietary-files.txt`, so ours is the AOSP build. V3 is a frozen stable AIDL interface and the HAL runs
  (1.2), so this is not a lead by itself.

### 1.2 The HAL is alive, the framework sees a fingerprint sensor
- `diag/08:1-4`: `Dumping for sensorId: 0, provider: FingerprintProvider`, `"service":"FingerprintProvider\/default"`,
  0 prints, `HAL deaths since last reboot: 0`.
- `diag/09:99`: `BiometricService: Sensor ID(0), oemStrength: 15, … modality 2 … hasEnrollments: false`
  (modality 2 = fingerprint, strength 15 = BIOMETRIC_STRONG).
- `diag/08` and `diag/09` **do not show the sensor type or location** the HAL reports. That is the missing fact.
- What `diag/09` does **not** contain (the guide's claims, checked): no `SensorLocation(…)` / `udfpsLocation` line, no
  `calib_data.bin` line, no `/sys/class/lcd/panel/fingerprint` reading, no `Adding AIDL configs` line (that one is logged
  once at boot, `LOS fb` `services/core/java/com/android/server/biometrics/sensors/fingerprint/aidl/FingerprintProvider.java:242`,
  and the 09 capture starts after boot activity, `diag/09:2` 09:09:33).
- The `goodix_i2c 13-005d: [sec_input] …` lines in `diag/09` (e.g. `:941`) are the **touchscreen** driver (`sec_input`;
  stock ships its firmware dir `/vendor/firmware/tsp_goodix`, `reference/stock/vendor_ls_Z.txt:1300`), not the fingerprint sensor.

### 1.3 Stock carries no sensor geometry
- Stock framework-res: `array/config_udfps_sensor_props` **size=0** (`FR :368112-368114`), `array/config_sfps_sensor_props`
  **size=0** (`FR :367968-367970`). No `config_udfps_location*` resource exists in it (grep of the whole dump).
  `config_udfps_touch_detection_options` and `config_selected_udfps_touch_detection = 0` are the AOSP defaults
  (`FR :368116-368119`, `FR :388921-388922`).
- Samsung's vendor framework-res RRO has 19 resources, none about fingerprint (`RRO :4-62`).
- Stock product RRO (`reference/stock/extra/screen/stock_rro_product.txt`), stock `vendor/build.prop`, `system/build.prop`,
  `stock_features.txt` and `vendor/display_id_4633128672291735943.xml`: no fingerprint/UDFPS key (grep). The only hits
  are build fingerprints and `android.hardware.fingerprint` (`reference/stock/extra/stock_features.txt:13`).
- The stock SystemUI resource dump is not in the repo (`docs/BOOT_0927_3.md:226-229`). Samsung's own UI does not use
  AOSP's UDFPS overlay anyway, so even that dump may carry nothing.
- Conclusion: on stock, the geometry reaches Samsung's UI at runtime (HAL / Samsung extension / kernel node), not from a
  resource file. **No stock-cited number exists in this repo.**

### 1.4 Kernel node that may hold the position
- Stock `init.fingerprint.rc` (copied verbatim to ours): `chown system radio /sys/class/fingerprint/fingerprint/position`
  (`reference/ours/vendor/etc/init/init.fingerprint.rc:21`, stock `reference/stock/vendor/etc/init/init.fingerprint.rc`),
  plus `name`, `vendor`, `type_check` (`:16-18`). The format of `position` is not documented anywhere we have: it is a
  capture item, not a value we can use yet.

### 1.5 SELinux
- `diag/03` (470 `avc: denied` lines, 10-01 09:10:16 to 12:02:43): sources are `hal_graphics_composer_default` (236),
  `rild` (196), `untrusted_app` (37), `isolated_app` (1). **No denial for `hal_fingerprint_default`**, nor any `tcontext`
  mentioning fingerprint/biometric. Caveat: the capture starts after boot, so a denial at HAL start would not be in it;
  the boot capture below covers that.

## 2. How AOSP 15 (Lineage 22.2) gets UDFPS geometry

1. `FingerprintService` connects to each declared `IFingerprint/<name>` and passes **`fp.getSensorProps()`** to
   `FingerprintProvider` with `resetLockoutRequiresHardwareAuthToken = true` (`LOS fb`
   `services/core/java/com/android/server/biometrics/sensors/fingerprint/FingerprintService.java:1043-1051`).
2. With that flag, `FingerprintProvider.initSensors` takes the **AIDL** branch (`… /aidl/FingerprintProvider.java:233-249`).
   The only overlay it reads is `config_sfps_sensor_props` (`:945-966`, comment `:945-946`: "workaround … reads values via
   an overlay instead of querying the HAL").
3. `Sensor.getFingerprintSensorPropertiesInternal` builds the framework props from the HAL's `SensorProps`:
   `prop.sensorType`, `prop.halControlsIllumination`, `prop.halHandlesDisplayTouches`, and **`prop.sensorLocations`
   unless `config_sfps_sensor_props` is non-empty** (`… /aidl/Sensor.java:210-237`, the choice at `:229`).
   The overlay replaces the location only. **The sensor type always comes from the HAL.**
4. HAL side, the fields are: `FingerprintSensorType sensorType = UNKNOWN` by default, `SensorLocation[] sensorLocations`,
   `halHandlesDisplayTouches`, `halControlsIllumination` (`LOS hi` `SensorProps.aidl:37,43,65,76`); types are
   `UNKNOWN, REAR, UNDER_DISPLAY_ULTRASONIC, UNDER_DISPLAY_OPTICAL, POWER_BUTTON, HOME_BUTTON`
   (`FingerprintSensorType.aidl:23-30`); a location is `sensorLocationX/Y`, `sensorRadius`, `display`
   (`SensorLocation.aidl:36,43,50,64`).
5. `config_udfps_sensor_props` (integer-array **x, y, radius**, 3 items, `LOS fb` `core/res/res/values/config.xml:5689-5696`)
   is read **only on the HIDL path**: `AuthService.getHidlFingerprintSensorProps` (`services/core/java/com/android/server/biometrics/AuthService.java:989-1030`)
   and `HidlFingerprintSensorConfig` (`core/java/android/hardware/fingerprint/HidlFingerprintSensorConfig.java:86-109`).
   **On our AIDL HAL it is ignored.** Also, it is not the 5-item sensorId/type/x/y/r array the guide wrote.
6. SystemUI creates the UDFPS overlay only for sensors whose type is `TYPE_UDFPS_OPTICAL` or `TYPE_UDFPS_ULTRASONIC`
   (`packages/SystemUI/src/com/android/systemui/biometrics/AuthController.java:282-314`;
   `core/java/android/hardware/fingerprint/FingerprintSensorPropertiesInternal.java:118-121`). Otherwise there is no
   `UdfpsController` and no enroll zone.

So the enroll zone that never appears has two possible causes, and the capture tells which:
- **(a) the HAL reports a non-UDFPS type** (`UNKNOWN`/`REAR`, e.g. because Samsung's binary expects something from its
  own stack before it fills `SensorProps`). No overlay can fix that on the AIDL path (2.3).
- **(b) the HAL reports UDFPS but location 0/0/0** (or a size the scale factor gets wrong). Then the fix is the location,
  from the HAL itself or, as a last resort, `config_sfps_sensor_props` (2.2-2.3), **with numbers from a capture**.

Not applicable here: Lineage's open-source Samsung wrapper `android.hardware.biometrics.fingerprint-service.samsung` reads
`ro.vendor.fingerprint.type` and `ro.vendor.fingerprint.sensor_location` (`<x>|<y>|<radius>|display`, `LOS hs`
`aidl/fingerprint/fingerprint.sysprop:8,37`, `Fingerprint.cpp:50-62,116-131`), but it `dlopen`s `libbauthserver.so` /
`libsfp_sensor.so` (`LegacyHAL.cpp:20,23`), which are not in the stock vendor listing. Those props do nothing for
Samsung's AIDL binary.

## 3. Decision
- First version: no change to `device/`, because no number was available yet and `config_udfps_sensor_props` would be ignored.
  **Updated after the captures: case (b), overlay change in section 7.**
- After the capture: if (b), add the location with the captured numbers (HAL-reported if the HAL has them, otherwise
  derived from `/sys/class/fingerprint/fingerprint/position` only if its format can be cited). If (a), the next step is
  the HAL's own log lines at start and the Samsung extension, not an overlay.

## 4. Capture for Ange (exact commands)

Reboot the phone first, then run within a few minutes (the logcat buffers rotate):

```sh
mkdir -p fp_1001 && cd fp_1001

# 1. Boot: which path the framework took, HAL start lines, denials
adb logcat -d -b all > logcat_boot_all.txt
grep -nE "FingerprintProvider|FingerprintService|Adding (AIDL|HIDL) configs|Added: |fingerprint-service|vendor.fingerprint-default|biometrics.fingerprint" logcat_boot_all.txt > 1_boot_fp.txt
grep -n "avc:" logcat_boot_all.txt | grep -iE "fingerprint|biometric|esfp|goodix_fp" > 2_denials_fp.txt

# 2. What SystemUI received from the HAL (type, location, bounds, scale)
adb shell dumpsys activity service com.android.systemui/.SystemUIService > sysui_dump.txt
grep -nE "fingerprintSensorLocation|udfpsBounds|mScaleFactor|mCachedDisplayInfo|mSensorProps|allFingerprintAuthenticatorsRegistered|Type: " sysui_dump.txt > 3_sysui_fp.txt

# 3. Kernel node and display size (may say Permission denied for shell: keep the error, it is an answer too)
adb shell 'ls -lZ /sys/class/fingerprint/fingerprint/; for f in name vendor type_check position; do echo "== $f"; cat /sys/class/fingerprint/fingerprint/$f; done' > 4_sysfs_fp.txt 2>&1
adb shell 'wm size; wm density; getprop | grep -iE "finger|biometric"' > 5_display_props.txt 2>&1

# 4. Enroll attempt: Settings > Security > Fingerprint, go to the screen where the zone should appear, wait 10 s, then
adb logcat -d > logcat_enroll.txt
grep -nE "Fingerprint|Udfps|UDFPS|BiometricScheduler|FingerprintEnroll|AuthController" logcat_enroll.txt > 6_enroll_fp.txt
```

Send back files `1_` to `6_` (they contain no IMEI; `logcat_*_all.txt` may, keep them local or mask them as in PR #26).
What each answers: `3_` says `Type:` (`FingerprintSensorPropertiesInternal.toString`, `LOS fb`
`core/java/android/hardware/fingerprint/FingerprintSensorPropertiesInternal.java:188-189`) and the location SystemUI uses
(`AuthController.java:1381-1390`, `UdfpsController.java:260-264`); an empty `fingerprintSensorLocation` / no
`mSensorProps` line means case (a). `1_` and `2_` cover the boot gap of `diag/09` and `diag/03`. `4_` gives the
position node and its format.

## 5. Checks on the next boot (after a fix lands)
- `adb shell dumpsys activity service com.android.systemui/.SystemUIService | grep -nE "fingerprintSensorLocation|udfpsBounds|Type: "`:
  a UDFPS type and a non-zero location.
- Settings > Security > Fingerprint shows the enroll circle over the sensor; `adb shell dumpsys fingerprint` then shows
  `"count":1` after one enrolled finger (compare `diag/08:3`).
- `adb logcat -d | grep "avc:" | grep -iE "fingerprint|biometric"`: empty.

## 6. Capture results (01/10, boot at 13:09:40, `docs/logs/fp_1001/`)

Files received: `1_boot_fp.txt`, `2_denials_fp.txt`, `3_sysui_fp.txt`, `6_enroll_fp.txt`. Files `4_` (sysfs node) and
`5_` (display/props) are missing; the display size is in `3_` anyway. Line numbers below are the `grep -n` prefixes kept
in each file (line in the full logcat).

### 6.1 What the framework received
- AIDL path confirmed: `FingerprintProvider/default: Adding AIDL configs` (`1_boot_fp.txt`, logcat :9441), then
  `Added: …fingerprint.aidl.Sensor@9956e7f` (:9447). The HAL starts as pid 953 (`init`, :4624) and is found in VINTF (:5540).
- **Type 3** = `TYPE_UDFPS_OPTICAL`: `mSensorProps=(ID: 0, Strength: 2, Type: 3)` (`3_sysui_fp.txt`, :1256);
  constant `FingerprintSensorProperties.java:52` (`LOS fb` `core/java/android/hardware/fingerprint/`). So **case (b)**
  of section 2, not (a).
- **Location empty**: `fingerprintSensorLocation=Point(0, 0)`, `udfpsBounds=Rect(0, 0 - 0, 0)`, `mScaleFactor=1.0`,
  display `real 1080 x 2340` (`3_sysui_fp.txt`, :1660-1664). SystemUI asks for the location of display `""`
  (`FingerprintSensorPropertiesInternal.java:157-176`) and falls back to `SensorLocationInternal.DEFAULT` = `("", 0, 0, 0)`
  (`core/java/android/hardware/biometrics/SensorLocationInternal.java:35`). So either the HAL sends 0/0/0, or it sends a
  location tagged with another display id. The fix below covers both.

### 6.2 What happens during enrollment
- Settings reaches `FingerprintEnrollEnrolling` (`6_enroll_fp.txt`, :20841), the framework starts
  `FingerprintEnrollClient` (:20971, :20988), and SystemUI adds its overlay: `UdfpsController: showUdfpsOverlay | adding
  window reason=2` (:21019). The touch overlay covers the whole screen, `0,0-1080,2340` (:21037).
- Every touch is logged `NormalizedTouchData [UNCHANGED]` with `sessionId: -1` (from :21755 on): 161 touches, x 523-643,
  y 1896-2108. None falls inside the 0-size sensor rectangle, so SystemUI never sends `onPointerDown` to the HAL and the
  optical sensor is never lit. That matches "the zone never appears".
- Those 161 touches are where Ange put his finger, **not a sensor geometry**. They are only a sanity check for the
  numbers of 6.3: the sensor centre should fall inside that cluster.
- `FingerprintManager: Invalid acquired message: 6, 10001` (:21109): acquired code 6 (vendor) with Samsung vendor code
  10001, logged by `LOS fb` `core/java/android/hardware/fingerprint/FingerprintManager.java:1554` when no string matches. Harmless by itself.

### 6.3 Mechanism for the fix (AIDL)
- On the AIDL path, a non-empty `config_sfps_sensor_props` **replaces the HAL's locations for any sensor type**, and the
  type stays the HAL's (`… /aidl/Sensor.java:229`, read at `… /aidl/FingerprintProvider.java:948-966`). Its items are
  arrays of `displayId` (string), `x`, `y`, `radius` (`parseSensorLocation`, `:969-983`;
  `core/res/res/values/config.xml:5722-5734`). With `displayId` = `""`, SystemUI's `getLocation()` finds it.
- The name says "sfps", but the code path is not type-specific. It is the only overlay that reaches an AIDL sensor.
  `config_udfps_sensor_props` stays useless here (section 2.5).
- What it needs: x, y, radius in pixels of the 1080 x 2340 panel (`3_` :1660, scale 1.0).

### 6.4 Where a stock number can come from
- The sensor is a **Goodix GW9558** driven by `fingerprint.ko` (`device/prebuilts/modules/vendor_boot/modules.load:207-208`;
  strings of `device/prebuilts/modules/vendor_boot/fingerprint.ko`: `gw9558_probe`, `goodix,position`,
  `fps_%s: position: %s`). The driver reads the **device-tree property `goodix,position`** and exposes it as
  `/sys/class/fingerprint/fingerprint/position` (1.4). That is Samsung's own value for this panel, so it is the stock source.
- The device tree is not in the repo, so it has to be read on the phone (6.5). Its format (Samsung writes several
  comma-separated numbers) is not documented in anything we have. Converting it to pixels also needs the panel's
  physical dpi. Both are in 6.5. If the format cannot be cited, the next source is Samsung's open-source kernel
  release for SM-A566B (the dts that sets `goodix,position`).

### 6.5 Second capture (no root)

```sh
cd fp_1001
adb shell 'ls -lZ /sys/class/fingerprint/fingerprint/; for f in name vendor type_check position; do echo "== $f"; cat /sys/class/fingerprint/fingerprint/$f; echo; done' > 4_sysfs_fp.txt 2>&1
adb shell 'for f in $(find /proc/device-tree/ -name "goodix,position" 2>/dev/null); do echo "== $f"; cat "$f"; echo; done' > 7_dt_position.txt 2>&1
adb shell 'wm size; wm density; dumpsys display | grep -m4 -iE "dpi"' > 5_display_props.txt 2>&1
```

Expected next step: with `7_` (or `4_`) and the dpi, add `config_sfps_sensor_props` to
`device/overlay/frameworks/base/core/res/res/values/config.xml`, cite the value, check that the centre falls in the
6.2 touch cluster, then the checks of section 5.

### 6.6 SELinux at boot
- `2_denials_fp.txt`: 7 lines, all `scontext=u:r:essi_bootlog:s0` (`ps` from our boot logger, `device/sepolicy_extra/essi_bootlog.te`)
  reading `/proc/953` of `hal_fingerprint_default`, `permissive=1`. **No denial of the fingerprint HAL itself.**
  These come from our own diagnostic logger, not a fingerprint problem.

## 7. Second capture (01/10, 13:20) and the change

### 7.1 Values read on the phone
- `docs/logs/fp_1001/4_sysfs_fp.txt`: `name` = `GW9588`, `vendor` = `GOODIX`, `type_check` = `9`, and
  **`position` = `12.34,0.00,9.10,9.10,14.80,14.80,12.00,12.00,5.00`**. The files are `r--r--r--`,
  `u:object_r:sysfs_ss_writable:s0`, so they are readable without root.
- `docs/logs/fp_1001/7_dt_position.txt`: the device-tree node is `/proc/device-tree/samsung_mobile_device/gw9558/goodix,position`;
  reading it is `Permission denied`. The sysfs node is the same value: the driver prints it as `position: %s` from that
  property (strings of `fingerprint.ko`, 6.4).
- `docs/logs/fp_1001/5_display_props.txt`: `Physical size: 1080x2340`, `density 450`, **`xDpi=386.3662, yDpi=388.47058`**,
  display `uniqueId="local:4633128672291735943"`.

### 7.2 Format and conversion (cited)
The only open-source reader of this node we found is phh's GSI framework (`phhusson/platform_frameworks_base`,
branch `android-12.0.0_r28-phh`, `4f160de9fbee09a49da246447f014a665b09554d`,
`services/core/java/com/android/server/biometrics/AuthService.java:917-936`):

- field 0 = distance from the bottom edge in mm (`bottomMM`), field 5 = sensor area size in mm (`areaSizeMM`);
- mm to px: `mm × 0.0393700787 × ydpi`, truncated to int;
- `mW = areaSizePx / 2` (radius), `mX = width / 2`, `mY = height − bottomPx − mH`;
- it then sets `udfpsProps = {mX, mY, mW}`, i.e. the AOSP x, y, radius.

With our values: bottom = 12.34 mm → **188 px**, area = 14.80 mm → **226 px**, radius = **113**, x = 1080/2 = **540**,
y = 2340 − 188 − 113 = **2039**. Field 1 (`0.00`) is not used by that formula; it reads as a zero horizontal offset,
which matches x = width/2.

Check against the enrollment touches of 6.2 (161 presses, x 523-643, y 1896-2108): the centre (540, 2039) is inside the
cluster. This is a sanity check only; the numbers come from the driver value.

### 7.3 Change
`device/overlay/frameworks/base/core/res/res/values/config.xml`: `config_sfps_sensor_props` with one location
`{@null → displayId "", 540, 2039, 113}` (sub-array `config_essi_udfps_location_display0`).
- `displayId` "": `SensorLocationInternal` turns null into "" (`LOS fb` `core/java/android/hardware/biometrics/SensorLocationInternal.java:64-67`),
  and SystemUI looks up the "" location (`FingerprintSensorPropertiesInternal.java:157-158`).
- Our overlay is an auto-generated RRO (`device/device.mk:95-96`). The sub-array is a new resource defined in the overlay
  itself and referenced from the overlaid array. If the build or the boot does not resolve it, the check below shows
  `udfpsBounds=Rect(0, 0 - 0, 0)` again; tell me and I will move it.

### 7.4 Not done here, possible next step
phh's code also writes `fod_rect,…` and `fod_enable,1,1,0` to Samsung's touchscreen (`/sys/devices/virtual/sec/tsp/cmd`,
same file `:664-665`, `:851-862`, `:931`) for the old HIDL Samsung HAL. Our HAL is Samsung's AIDL one, and nothing shows yet
that it needs this. If, after this build, the circle appears but touches do not progress enrollment, that is the next lead.

### 7.5 Checks on the next boot
```sh
adb shell dumpsys activity service com.android.systemui/.SystemUIService | grep -nE "fingerprintSensorLocation|udfpsBounds|mSensorProps"
# expected: mSensorProps=(ID: 0, Strength: 2, Type: 3), fingerprintSensorLocation=Point(540, 2039), udfpsBounds=Rect(427, 1926 - 653, 2152)
adb logcat -c   # then Settings > Security > Fingerprint, enroll, touch the circle
adb logcat -d | grep -nE "UdfpsController|FingerprintEnroll|Invalid acquired|onAcquired|Enroll" > fp_enroll2.txt
adb shell dumpsys fingerprint | head -4      # "count":1 after one enrolled finger
adb logcat -d | grep "avc:" | grep -iE "fingerprint|biometric"
```

## 8. Third capture (01/10, build of 14:07 UTC with PR #27): position OK, enrollment stalls in the HAL

Files: `docs/check_1001_1450.txt`, `docs/8_enroll2_fp.txt`, `docs/10_tsp_cmd_list.txt`, `docs/11_sysui_udfps.txt`
(the `9_crash.txt` file is empty; the 14:49 SIGSEGVs are `samsung.hardware.media.c2`, handled in another thread).
Line numbers are the `grep -n` prefixes kept in `8_enroll2_fp.txt` (line in Ange's full logcat).

### 8.1 What now works
- `check_1001_1450.txt` (fingerprint section): `fingerprintSensorLocation=Point(540, 2039)`,
  `udfpsBounds=Rect(427, 1926 - 653, 2152)`, exactly the values of 7.5. The circle shows and the lock screen uses it.
- The framework-to-HAL chain is complete. Enrollment starts: `FingerprintEnrollClient` (15:07:14.909), HAL logs
  `enrollWithContext` / `Enroll` (15:07:14.917). Then on every press the HAL receives `onPointerDownWithContext`,
  `onPointerDown`, `onUiReady`, and on release `onPointerUpWithContext` / `onPointerUp` (first press :16452-16458,
  release :16740-16741). That is 12+ presses, each logged by the HAL.

### 8.2 What does not happen
- At enroll start the HAL powers the sensor and talks to the Trustlet (`fps_gw9558_ioctl: GF_IOC_ENABLE_POWER`,
  `GF_IOC_RESET`, `GF_IOC_ENABLE_SPI_CLK`, `SW> securefp: Trustlet Fingerprint::Returning 0`, 15:07:14.926-14.999),
  reports `onAcquired(7, 10001)` (vendor code), then **turns the SPI clock off** (`GF_IOC_DISABLE_SPI_CLK`, 15:07:15.000),
  0.5 s **before** the first press (15:07:15.537).
- During the presses there is **no** sensor activity at all: no `fps_gw9558_ioctl`, no `securefp` Trustlet call, no
  `onAcquired`, no progress or error. The HAL logs the pointer callbacks and does nothing with them.
- Touch side: the touch IC reports the presses with `fod:7` (e.g. :16437 `[P] … fod:7`), but never logs
  `FOD PRESS`, a message the touch driver has (`device/prebuilts/modules/vendor_dlkm/goodix_ts_berlin.ko` strings:
  `[sec_input] [%s:%d] FOD %sPRESS`, `fod_enable`, `set_fod_rect`, `fod_lp_mode`, `fod is not supported`).
- Illumination: `UdfpsDisplayMode: disable | onDisabled is null` after every release (14×, from :16746). No
  `UdfpsDisplayModeProvider` is installed, so the framework does not switch the panel to a bright mode for the optical
  sensor. That only matters once the HAL captures.
- `FingerprintCallback: sendUdfpsPointerDown, callback null` (pid 1701 = `com.android.settings`, :16558): Settings'
  own callback is not set; the framework path to the HAL above is independent of it.

### 8.3 Reading
On stock, something other than AOSP's `onPointerDown` starts the capture. The facts point at Samsung's side channels:
- The touch IC has a FOD mode (`fod_enable`, `set_fod_rect`, `fod_lp_mode` in `10_tsp_cmd_list.txt`) that nobody enables
  on our image. Stock gives `/sys/class/sec/tsp/cmd` to `system` (`reference/stock/vendor/etc/init/vendor.samsung.hardware.sysinput-default.rc:28`)
  and ships `sec-sysinput-aidl` (`:269`) for it. The stock fingerprint HAL itself has no right on input devices or on
  the tsp node (every `allow hal_fingerprint_default` rule in `reference/stock/vendor/etc/selinux/vendor_sepolicy.cil`),
  so on stock it is the framework / SystemUI that drives the touch IC.
- phh's GSI did exactly this for Samsung UDFPS: `fod_enable,1,1,0` and `fod_rect,…` on `/sys/devices/virtual/sec/tsp/cmd`
  (`phhusson/platform_frameworks_base` 4f160de9 `AuthService.java:664-665,851-862,931`), plus `sehRequest(…)` on Samsung's
  fingerprint extension.
- Lineage's Samsung fingerprint wrapper, on `onPointerDown`, sends `SEM_REQUEST_TOUCH_EVENT` (22) with 2, and 1 on
  `onPointerUp`, when `ro.vendor.fingerprint.request_touch_event` is set (`LOS hs` `aidl/fingerprint/Session.cpp:198-216`,
  `VendorConstants.h:50`). That is the legacy Samsung HAL's request API. Our HAL is Samsung's AIDL binary, and it
  exposes Samsung's extension `vendor.samsung.hardware.biometrics.fingerprint` V1 (`device/proprietary-files.txt:1056`);
  what that extension contains is not known yet.

Two candidate fixes, neither cited enough to ship yet:
1. enable the touch IC's FOD mode (`fod_enable`, `set_fod_rect`) when enrollment/auth starts, with parameters this
   driver accepts (phh's `fod_enable,1,1,0` was for older kernels);
2. send Samsung's touch event request to the HAL through its V1 extension on pointer down/up.
Both need a small platform patch (rule B: `patches/<project>/*.patch` + doc) and sepolicy for the writer. The next
capture decides which one.

### 8.4 Fourth capture (no root)
```sh
adb pull /vendor/lib64/vendor.samsung.hardware.biometrics.fingerprint-V1-ndk.so
adb pull /vendor/bin/hw/vendor.samsung.hardware.biometrics.fingerprint-service
strings -n 4 vendor.samsung.hardware.biometrics.fingerprint-V1-ndk.so | grep -iE "vendor\.samsung|ISeh|seh|request|touch|descriptor|transact" > 12_seh_ndk_strings.txt
strings -n 4 vendor.samsung.hardware.biometrics.fingerprint-service | grep -iE "seh|request|touch|pointer|uiready|fod|mask|hbm|illum|lcd|panel|extension|sysinput|tsp|%s|%d" > 13_hal_strings.txt
adb shell 'service list | grep -iE "finger|biometric|sysinput"; ls -lZ /sys/class/sec/tsp/ | grep -iE "cmd|fod"; cat /sys/class/sec/tsp/fod_info /sys/class/sec/tsp/fod_pos 2>&1; ls -lZ /sys/class/lcd/panel/ | grep -iE "finger|mask|hbm|fod"' > 14_services_nodes.txt 2>&1
```
Only the text files go in `docs/logs/fp_1001/`; the two binaries stay local (no blobs in the repo).

## 9. Fourth capture (01/10, 15:14): Samsung's HAL is a loader, the logic is in the APEX

Files: `docs/12_seh_ndk_strings.txt`, `docs/13_hal_strings.txt`, `docs/14_services_nodes.txt`.

- Samsung's extension interface is **`vendor.samsung.hardware.biometrics.fingerprint.ISehFingerprint`** with one method,
  **`sehRequest(int, int, int, in byte[], out SehResult)`** (mangled `BpSehFingerprint10sehRequestEiiiRKNSt3__16vectorIhNS…EEPNS4_9SehResultE`,
  `12_seh_ndk_strings.txt`). It is attached to the standard `IFingerprint/default` binder as a **binder extension**:
  `Check failed: STATUS_OK == AIBinder_setExtension(halBinder.get(), sehFingerprint->asBinder().get())` (`13_hal_strings.txt`).
  So a client gets it with `IFingerprint.asBinder().getExtension()`. It is not a separate service: `service list` shows only
  `IFingerprint/default` (`14_services_nodes.txt:2`).
- `/vendor/bin/hw/vendor.samsung.hardware.biometrics.fingerprint-service` itself is a **loader**: its strings are
  `/apex/com.samsung.android.biometrics.fingerprint/lib64/libsfp_sensor.so`, `/vendor/lib64/libsfp_sensor.so`, `load apex ca`,
  `apex version is empty`, `MakeSehFingerprint() dlsym fail`, and the symbol
  `vendor::samsung::hardware::biometrics::fingerprint::FingerprintInjector::MakeSehFingerprint(IFingerprint*)`
  (`strings` of the binary pulled by Ange, 102920 bytes, same size as `reference/stock/vendor_ls_Z.txt:333`). The
  sensor/TA logic, and whatever starts a capture, is in **`libsfp_sensor.so`** (APEX path first, then `/vendor/lib64`; see 9.2: on our image it is the `/vendor/lib64` one)
  (`vendor/apex/com.samsung.android.biometrics.fingerprint.signed.apex`, `device/proprietary-files.txt:360`).
- `libsfp_sensor.so` is also the name Lineage's open-source Samsung fingerprint HAL loads (`LOS hs`
  `aidl/fingerprint/LegacyHAL.cpp:20-23`, via `ss_fingerprint_open`, `ss_fingerprint_request`, …). That HAL sends
  `SEM_REQUEST_TOUCH_EVENT` on pointer down/up (8.3). Whether this APEX's `libsfp_sensor.so` still exports those
  `ss_fingerprint_*` functions decides whether Lineage's HAL is an option.
- Display: `/sys/class/lcd/panel/local_hbm` exists (`-rw-rw-r-- system system`, `sysfs_ski_display_writable`), next to
  `fingerprint` (`14_services_nodes.txt`). That is the panel's local high-brightness mode, the illumination an optical
  UDFPS needs (8.2, `UdfpsDisplayMode` has no provider).
- Touch: `/sys/class/sec/tsp/cmd` is `--w--w---- system radio` (`14_services_nodes.txt`), `fod_info` reads
  `17,13,28,17,37…`, `fod_pos` exists. Writers would be `system` processes, as on stock.

The two `.so`/binary files that were pushed to `docs/` are removed in this PR (ground rule: no `.so` in the repo).

### 9.1 Fifth capture (no root)
```sh
adb shell 'ls -lZ /apex/com.samsung.android.biometrics.fingerprint/ /apex/com.samsung.android.biometrics.fingerprint/lib64/' > 15_fp_apex_ls.txt 2>&1
adb pull /apex/com.samsung.android.biometrics.fingerprint/lib64/libsfp_sensor.so
strings -n 4 libsfp_sensor.so | grep -E "^ss_|MakeSeh|Injector|TOUCH|[Tt]ouch|fod|local_hbm|hbm|mask|sehRequest|[Rr]equest|onPointer|UiReady|/sys/|/dev/" > 16_sfp_strings.txt
```
Push `15_` and `16_` to `docs/logs/fp_1001/`; keep `libsfp_sensor.so` local.

### 9.2 Correction (fifth capture, 01/10 15:20)
- The APEX holds no library: `/apex/com.samsung.android.biometrics.fingerprint/` contains only `apex_manifest.pb` and
  `lost+found`, and `lib64/` does not exist (`docs/15_fp_apex_ls.txt`). So the loader uses its second path,
  **`/vendor/lib64/libsfp_sensor.so`**: stock 546592 bytes (`reference/stock/vendor_ls_Z.txt:2559`), shipped by us
  with the same size (`reference/ours/vendor_ls_Z.txt:2562`, `device/proprietary-files.txt:1011`), next to
  `libsfp_teegw.so` (`:1012`) and `libgf_in_system_lib.so` (`:956`).
- Corrected capture:
```sh
adb pull /vendor/lib64/libsfp_sensor.so
strings -n 4 libsfp_sensor.so | grep -E "^ss_|MakeSeh|Injector|TOUCH|[Tt]ouch|fod|local_hbm|hbm|mask|sehRequest|[Rr]equest|onPointer|UiReady|/sys/|/dev/" > 16_sfp_strings.txt
```

## 10. Fix: LineageOS's Samsung fingerprint HAL (01/10, after `docs/16_sfp_strings.txt`)

### 10.1 What the strings show
- `libsfp_sensor.so` still has the legacy API names: `ss_fingerprint_open`, `_close`, `_pre_enroll`, `_enroll`,
  `_post_enroll`, `_get_auth_id`, `_cancel`, `_remove`, `_set_active_group`, `_authenticate`, `_request` and
  `ss_set_notify_callback` (`docs/16_sfp_strings.txt:28-39`). These are exactly the functions Lineage's HAL resolves
  (`LOS hs` bb6e7b20 `aidl/fingerprint/LegacyHAL.cpp:20-56`). Inferred, not checked with `nm -D`: names in `strings`
  output of a shared library are normally its dynamic symbols; if one is missing, the HAL logs it at start (10.3).
- The same library also holds Samsung's whole AIDL HAL (`aidl::android::…::Session::onPointerDown`, `onUiReady`,
  `FingerprintInjector::MakeSehFingerprint`, `16_sfp_strings.txt:1-14`), so the stock service binary is only a loader
  (9). Samsung's `Session::onPointerDown` is the one that does nothing on our build (8).

### 10.2 Change (this PR)
| File | Change | Source |
|---|---|---|
| `projects.txt` | `hardware/samsung` from LineageOS at `bb6e7b20` (lineage-22.2) | Lineage HAL source (replaced by the copy in `device/fingerprint`, §10.6) |
| `device/device.mk` | `hardware/samsung` in `PRODUCT_SOONG_NAMESPACES`; `PRODUCT_PACKAGES += android.hardware.biometrics.fingerprint-service.samsung` | sm7125-common b315034e `common.mk:171-173`, `:437-441` |
| `device/vendor.prop` | `ro.vendor.fingerprint.type=udfps_optical`, `request_touch_event=true`, `sensor_location=540\|2039\|113` | sm7125 `vendor.prop:160-161`; location = §7 |
| `device/proprietary-files.txt` | drop Samsung's `fingerprint-service` binary, its `.rc` and its VINTF xml | same service name `vendor.fingerprint-default` and same `IFingerprint/default` as Lineage's (`aidl/fingerprint/*.rc`, `*.xml`): keeping both would register the instance twice (PR #11/#16 lesson) |
| `device/sepolicy_extra/file_contexts` | new binary labelled `hal_fingerprint_default_exec` | stock binary's label (`device/sepolicy/vendor/file_contexts:218`), sm7125 `sepolicy/vendor/file_contexts:61` |

Kept: `libsfp_sensor.so`, `libsfp_teegw.so`, `libgf_in_system_lib.so`, the Samsung `fingerprint-V1-ndk` lib and the APEX
(`proprietary-files.txt`), and the framework overlay (§7, same values; with the HAL now reporting the location both agree).

No SELinux property rule: `ro.vendor.*` is `vendor_default_prop` (`reference/system/system/selinux/plat_property_contexts:293`)
and every vendor domain may read it (`plat_sepolicy.cil:14126`, attribute `base_typeattr_375` = domain minus app and
core domains, `:34932`). The HAL runs in the same domain as the stock one, so its access to the sensor and the TEE is unchanged.

`ss_fingerprint_enumerate` is not in the strings (`16_sfp_strings.txt` has only `FPBAuthService::request_enumerate`).
Lineage's HAL handles that: without it, `enumerateEnrollments` lists `/data/vendor/biometrics/fp/User_<id>/`
(`Session.cpp:120-140`, `Session.h:17`), labelled `biometrics_vendor_data_file` (`device/sepolicy/vendor/file_contexts:868`),
which `hal_fingerprint_default` may read and write (`device/sepolicy/vendor/file.te:812-813`).

Not added: Lineage's SurfaceFlinger UDFPS extension (`soong_config_set … udfps_zorder` in sm7125). Its z-order bit
`0x20000000` is a Qualcomm display-HAL contract; nothing says the Exynos HWC reads it. Illumination (`local_hbm`, 9) is the
next step only if captures start but fail for image quality.

### 10.3 Checks after build and flash
After `extract`/regeneration of the vendor makefiles (the three dropped lines), build, flash, then:
```sh
adb logcat -d | grep -iE "fingerprint|LegacyHAL|onPointer|request\(" > 17_fp_lineage_hal.txt
adb shell dumpsys activity service com.android.systemui/.SystemUIService | grep -iE "udfps|SensorLocation|sensorType" >> 17_fp_lineage_hal.txt
adb shell 'service list | grep -i fingerprint; ps -A | grep -i fingerprint' >> 17_fp_lineage_hal.txt
# enroll: Settings > Security > Fingerprint, touch the circle 3-4 times, then
adb logcat -d | grep -iE "onPointerDown|onPointerUp|onAcquired|onEnrollmentProgress|request\(" > 18_fp_enroll.txt
adb logcat -d | grep "avc: denied" | grep -i fingerprint >> 18_fp_enroll.txt
adb shell dumpsys fingerprint >> 18_fp_enroll.txt
```
Expected: `Sensor type: UNDER_DISPLAY_OPTICAL location: … sensorLocationX: 540, sensorLocationY: 2039, sensorRadius: 113`
(`Fingerprint.cpp`), no `Can't open HAL module`, one `IFingerprint/default`, `onPointerDown` on each touch, enrollment
progress on screen. If the HAL fails to open (`Can't open HAL module`), `ss_fingerprint_open` failed or a library
dependency of `libsfp_sensor.so` is missing: `adb shell ls /vendor/lib64 | grep -i biometrics` goes in the capture.

### 10.4 Build fix: duplicate `secril_config_svc` (01/10; superseded by §10.6)
The first build with PR #33 stopped with `module "secril_config_svc" found in multiple namespaces (hardware/samsung and
vendor/samsung/essi)`. `hardware/samsung` is one Soong namespace (root `Android.bp`), and its
`ril/secril_config_svc/Android.bp:18` builds a `secril_config_svc` binary. We ship Samsung's stock one
(`device/proprietary-files.txt:414`), so the vendor tree has a prebuilt module of the same name. Ange's scan found no
other duplicate. `patches/hardware/samsung/0001-…` deletes that one `Android.bp` (it defines nothing else, and no other file
in `hardware/samsung` references the module); the fingerprint HAL is untouched. Apply it after cloning `projects.txt`:
`git -C hardware/samsung apply "$ESSI/patches/hardware/samsung/"*.patch`.

### 10.5 Second clash: `vendor.samsung.hardware.radio.network-V1-ndk` (01/10; superseded by §10.6)
The next build stopped in Kati: `vendor.samsung.hardware.radio.network-V1-ndk` is defined by our stock blob
(`device/proprietary-files.txt:204`) and by `hardware/samsung`'s `aidl_interface vendor.samsung.hardware.radio.network`
(`interfaces/radio/network/aidl/Android.bp`, version 1), which generates `…-V1-ndk`. Ange's scan compared plain
`name:` values, so it missed generated names.

Full scan (script over every `Android.bp` of `hardware/samsung` at `bb6e7b20`, expanding `aidl_interface` to
`-V<n>-{ndk,cpp,java,rust}` and `hidl_interface` to its generated libraries, against the basenames of every
`proprietary-files.txt` entry): only two names are in both, `secril_config_svc` (0001, §10.4) and
`vendor.samsung.hardware.radio.network-V1-ndk`. No `vendor.samsung.hardware.radio@x.y` HIDL library is a blob of ours
(`proprietary-files.txt` has only the AIDL `-V1-ndk` radio libs, lines 200-205 and 1064).

Dependents of removed modules, computed transitively: only `sehradiomanager` (`ril/sehradiomanager/Android.bp`, it
links `vendor.samsung.hardware.radio.network-V1-ndk`). Nothing depends on `sehradiomanager` or `secril_config_svc`.
`hidl/radio/1.3` and `interfaces/radio/{1.2,2.0,2.1,2.2}` stay: they use only the HIDL interfaces, which are kept.

`patches/hardware/samsung/0002-…` deletes those two `Android.bp` files. Checks, on a clean clone at `bb6e7b20`:
- `git apply --check` then `git apply` of 0001 and 0002, in order: both OK.
- The same scan on the patched tree: no shared name, no remaining reference to a removed module.
- `grep -rn --include=Android.bp -E '"(secril_config_svc|sehradiomanager|vendor\.samsung\.hardware\.radio\.network[^"]*)"'`: no match.

The fingerprint HAL chain is untouched. Everything it needs in `hardware/samsung` is in two files, both kept:

| Module | Defined in | Kept |
|---|---|---|
| `android.hardware.biometrics.fingerprint-service.samsung` (cc_binary) | `aidl/fingerprint/Android.bp` | yes |
| `android.hardware.biometrics.fingerprint.SamsungProps` (sysprop_library, gives `libandroid.hardware.biometrics.fingerprint.SamsungProps`) | `aidl/fingerprint/Android.bp` | yes |
| `soong_namespace` (imports `hardware/google/pixel`, `hardware/google/interfaces`) | `Android.bp` (root) | yes |
| `libbase`, `libbinder_ndk`, `libhardware` | AOSP `system/libbase`, `frameworks/native`, `hardware/libhardware` | outside `hardware/samsung` |
| `android.hardware.biometrics.fingerprint-V4-ndk`, `android.hardware.biometrics.common-V4-ndk`, `android.hardware.biometrics.common.util` | AOSP `hardware/interfaces/biometrics` | outside `hardware/samsung` |

No other `hardware/samsung` `Android.bp` mentions fingerprint (`grep -rl fingerprint --include=Android.bp` lists only
`aidl/fingerprint/Android.bp`). We do not use `fingerprint/Android.bp` (the SurfaceFlinger extension, §10.2).

### 10.6 HAL copied into the device tree; `hardware/samsung` removed (01/10)
The build after 10.5 stopped on `overriding commands for target …/vendor/etc/vintf/manifest/memtrack.xml`. Putting
`hardware/samsung` in `PRODUCT_SOONG_NAMESPACES` exports all its modules to Make, so every HAL in it got installed.
Ange asked to stop patching it one module at a time and to do what PR #29 did for the camera shim. So:

- `device/fingerprint/` is an unmodified copy of `aidl/fingerprint/` at `bb6e7b20` (`diff -r` empty), with a README
  citing the source. Its includes are local, the generated sysprop header, or AOSP libraries already in `shared_libs`
  (README lists them), so no other `hardware/samsung` file is copied. It lives in the `device/` Soong namespace, which
  `device.mk` already exports.
- `hardware/samsung` is gone from `projects.txt` and `PRODUCT_SOONG_NAMESPACES`; `patches/hardware/samsung/` (0001,
  0002) is deleted. **Delete the `hardware/samsung` checkout in the build tree** (`rm -rf hardware/samsung`): it is not
  in the base manifest, and leaving it would keep Soong parsing it (and a second module with the same names, in a
  namespace nobody exports).
- Kept from PR #33: `vendor.prop` props, the three `proprietary-files.txt` removals, the `file_contexts` label (same
  install path `/vendor/bin/hw/android.hardware.biometrics.fingerprint-service.samsung`).

Collision check against our blobs and tree:
| Copied item | Value | Clash? |
|---|---|---|
| module names | `android.hardware.biometrics.fingerprint-service.samsung`, `android.hardware.biometrics.fingerprint.SamsungProps` | not in `proprietary-files.txt` (no `fingerprint` line but the APEX :360, `fingerprint_common.rc` :482, `init.fingerprint.rc` :488, `…fingerprint-V1-ndk.so` :1053) |
| `init_rc` service | `vendor.fingerprint-default` | Samsung's `.rc` with that name is removed; stock `fingerprint_common.rc` and `init.fingerprint.rc` define no service (only `on boot` chown/chmod) |
| `vintf_fragments` | `IFingerprint/default` version 4 | Samsung's fragment removed; not in `device/manifest.xml` |
| install paths | `vendor/bin/hw/…fingerprint-service.samsung`, `vendor/etc/init/…samsung.rc`, `vendor/etc/vintf/manifest/…samsung.xml` | no blob at those paths |


## 11. Lock-screen icon drawn as a clipped white shape (01/10, screenshot 17:10)

Seen: on the lock screen the dark circle sits at the sensor (x 540, y 2039, radius 113), but a white block with a
curved lower edge covers its top, inside the sensor bounds `Rect(427, 1926 - 653, 2152)` (§7.5).

Cause: SystemUI pads the lock-screen icon (`DeviceEntryIconView`, `iconView` with `CENTER_CROP`) by
`(sensor width - iconSize) / 2`, with `iconSize = udfps_icon_size / pixel_pitch`
(fw/base 5c05c66e `packages/SystemUI/.../biometrics/domain/interactor/UdfpsOverlayInteractor.kt:55-57,124-131`).
`udfps_icon_size` is 6000 µm and `pixel_pitch` defaults to -1 (`packages/SystemUI/res/values/dimens.xml:2074,2080`),
so `iconSize` = -6000 and the padding is (226 + 6000) / 2 = 3113 px in a 226 px view. The image area is negative and
the crop draws a piece of an oversized icon. Inferred from the code and the screenshot; not confirmed by a dump.

Change: `device/overlay/frameworks/base/packages/SystemUI/res/values/dimens.xml` sets `pixel_pitch` to 65.385 µm
(25400 / yDpi 388.47058, `docs/logs/fp_1001/5_display_props.txt:4`). Icon 91 px, padding 67 px.

Check after build and flash: lock the phone; the circle should show a normal fingerprint glyph. If not:
`adb shell cmd overlay list | grep -i systemui` (the device RRO for com.android.systemui should be `[x]`).
