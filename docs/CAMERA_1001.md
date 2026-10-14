# Camera 01/10: `sec-camera-provider` exits with status 237 (PR C of `docs/TASK_1001_multi(1).md`)

## Facts (quoted)
- `docs/logs/diag_1001_1203/10_camera_isp.txt` (1221 lines): 61× `init : Service 'sec-camera-provider' (pid …) exited with
  status 237` (first at line 687), roughly every 5 s, and 53× `process with updatable components 'sec-camera-provider'
  exited 4 times in 4 minutes`.
- Every start logs the same three lines before the exit (231× each), e.g. lines 2-4:
  ```
  E vndksupport: Could not load /vendor/lib64/hw/camera.unihal.default.so from default namespace: dlopen failed:
    cannot locate symbol "ALooper_forCamera" referenced by "/vendor/lib64/unihal_android.so"....
  E HAL     : load: module=/vendor/lib64/hw/camera.unihal.default.so
  I Samsung_CameraProvider_impl: UniHAL is not loaded
  ```
  `ALooper_forCamera` is the only symbol the log names (231 lines, all identical). Bionic stops at the first unresolved
  symbol, so the log cannot show whether others follow (see "Chain" below).
- `docs/logs/diag_1001_1203/03_selinux_denials.txt`: 0 lines mention `camera` or `unihal`. Not a policy problem.
- The blobs are present. `unihal_android.so`, `camera.unihal.default.so` and the provider binary are in the stock listing
  (`reference/stock/vendor_ls_Z.txt`), in our image (`reference/ours/vendor_ls_Z.txt`) and in
  `device/proprietary-files.txt` (lines 68, 103, 378). It is not a missing blob.
- Service: `reference/ours/vendor/etc/init/vendor.samsung.hardware.camera.provider-service_64.rc:1-2`
  (`/vendor/bin/hw/vendor.samsung.hardware.camera.provider-service_64`, AIDL `ICameraProvider/internal/0`).

## Where `ALooper_forCamera` comes from
- **Not in LineageOS 22.2 `libandroid`:** `LineageOS/android_frameworks_base` lineage-22.2,
  `native/android/libandroid.map.txt:139-147` exports only `ALooper_acquire/addFd/forThread/pollAll/pollOnce/prepare/
  release/removeFd/wake`, and `native/android/looper.cpp` defines nothing else.
- **Not in `libmediandk`:** `LineageOS/android_frameworks_av` lineage-22.2, `media/ndk/libmediandk.map.txt` has no
  `ALooper` symbol. Same for `camera/ndk/libcamera2ndk.map.txt` (and `libcamera2ndk_vendor`, `camera/ndk/Android.bp:121`).
- **It is a Samsung addition to `libsensorndkbridge`.** LineageOS already shims it for Samsung devices:
  `LineageOS/android_device_samsung_gta4xl-common` lineage-22.2 (rev `dd036a278e1c`),
  `shims/libsensorndkbridge/ASensorManager.cpp:26-53` defines `ALooper_forCamera()`, `ALooper_release_forCamera()` and
  `ALooper_pollOnce_camera()` on top of AOSP's `libsensorndkbridge` `ALooper` class
  (`shims/libsensorndkbridge/Android.bp`: `libshim_sensorndkbridge`, `vendor: true`, links `libsensorndkbridge`).
  It is loaded with `blob_fixup().add_needed('libshim_sensorndkbridge.so')` on `vendor/lib64/libsensorlistener.so`
  (`extract-files.py:39-43` there). `LineageOS/android_device_samsung_sm8250-common` lineage-22.2
  `extract-files.py:43-44` does the same for `libsensorlistener.so` and two camera libraries.
- Consistent with our image: stock ships Samsung's own `/vendor/lib64/libsensorndkbridge.so` (85064 bytes,
  `reference/stock/vendor_ls_Z.txt:2556`); we ship the AOSP build (85096 bytes, `reference/ours/vendor_ls_Z.txt:2559`,
  `device/device.mk` "AOSP libs that Samsung blobs load at runtime", dep stripped by `device/fix-bp.sh:3`).

## Decision and changes
Shim, the LineageOS way, instead of shipping Samsung's `libsensorndkbridge.so` (it shares its module name with the AOSP
library, the same trap as PR #9/#16).
1. `device/shims/libsensorndkbridge/` — copy of the gta4xl-common shim (Android.bp + ASensorManager.cpp, LineageOS
   copyright and Apache-2.0 header kept). It sits in our `device/` soong namespace (`device/Android.bp`).
2. `device/device.mk` — `PRODUCT_PACKAGES += libshim_sensorndkbridge`. Needed because `fix-bp.sh` patches the blobs after
   `vendor/samsung/essi/Android.bp` is generated, so soong does not see the new NEEDED entry.
3. `device/fix-bp.sh` — `patchelf --add-needed libshim_sensorndkbridge.so` on `unihal_android.so` (the library the log
   names) and `libsensorlistener.so` (the library both LineageOS trees above patch; it is our stock blob,
   `device/proprietary-files.txt:99`). Uses extract-utils' own patchelf
   (`prebuilts/extract-tools/linux-x86/bin/patchelf-0_18`, default version in `LineageOS/android_tools_extract-utils`
   lineage-22.2 `extract_utils/tools.py:11-27`) and is idempotent: it skips a file that already has the NEEDED entry,
   like `add_needed_impl` (`extract_utils/fixups_blob.py:117-129`).

No `proprietary-files.txt` line is added: nothing the log names is missing from the image.

Not done: SELinux. The provider is a vendor process (`.rc` above), so `/vendor/lib64/libshim_sensorndkbridge.so` with the
default `vendor_file` label is readable by it. If the shim is ever loaded into a system process through the sphal namespace,
it would need `same_process_hal_file` like `libsensorndkbridge.so` (`device/sepolicy/vendor/file_contexts:435`). No log
shows that today.

## Chain: are other symbols missing?
The shim defines all three Samsung looper symbols known from LineageOS, so the next two in that family cannot be the next
failure. Anything else would show only on the next boot. To check the whole camera chain at once, without one boot per
symbol, run this **on the build machine after the build** (it lists every undefined symbol of the camera blobs that no
library of the built image defines):

```sh
cd out/target/product/essi
find symbols -name '*.so' -exec nm -D --defined-only {} + 2>/dev/null | awk 'NF==3{print $3}' | sed 's/@.*//' | sort -u > /tmp/defined.txt
for f in vendor/lib64/unihal_*.so vendor/lib64/hw/camera.unihal.default.so vendor/lib64/hw/camera.s5e8855.so vendor/lib64/libsensorlistener.so; do
  nm -D --undefined-only "$f" | awk '$1=="U"{print $2}' | sed 's/@.*//' | sort -u | comm -23 - /tmp/defined.txt | sed "s|^|$f: |"
done
```
Empty output = nothing else missing for these files. The blobs are stripped, but `nm -D` reads the dynamic table, which
they keep. `symbols/` also holds the APEX libraries (bionic), which `system/lib64` does not.

## Checks on the next boot
```sh
adb logcat -d | grep -E 'sec-camera-provider|vndksupport|UniHAL|Samsung_CameraProvider|cannot locate symbol' | tail -40
adb shell service list | grep -i camera.provider
adb shell dumpsys media.camera | head -40
adb logcat -d | grep -i 'avc:.*denied' | grep -iE 'camera|unihal|sensorndk'
```
Pass: no `exited with status 237`, no `cannot locate symbol`, `ICameraProvider/internal/0` listed, and
`dumpsys media.camera` shows at least one device. If a new `cannot locate symbol` appears, that symbol is the next link of
the chain: send that line (or the output of the `nm` loop above).
