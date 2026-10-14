# 01/10: Bluetooth audio (connects, no sound), PR B

Task: `docs/TASK_1001_multi(1).md`, "PR B". Upstream sources are the `lineage-22.2` branches of the LineageOS GitHub
mirrors, at these heads:

| short name | repository | head |
|---|---|---|
| `hi` | `android_hardware_interfaces` | `89252f8` |
| `bt` | `android_packages_modules_Bluetooth` | `70aa5d5` |
| `av` | `android_frameworks_av` | `0bbac29` |
| `media` | `android_system_media` | `980ffac` |
| `sepol` | `android_system_sepolicy` | `24428bf` |

The paths in our repo are plain (`device/...`, `reference/...`, `docs/...`).

## Decision

**Neither route (a) nor a property change.** Route (a), "A2DP software encoding with offload off", is already in
place: offload is off today, and that alone gives no sound. The software path needs one more piece, and Samsung's
audio HAL can't supply it. **This PR adds that piece:**
- a small vendor service, `device/audio_bt/`;
- it runs the AOSP Bluetooth audio provider and an AOSP Bluetooth audio module **in the same process**.

PR #26 and the false network-mode assumption don't touch this item.

## 1. Facts

### What our stack asks for, and what Samsung serves

- **Lineage's stack talks to one exact instance.** That is `android.hardware.bluetooth.audio.IBluetoothAudioProviderFactory/default`
  (`bt` `system/audio_hal_interface/hal_version_manager.cc:33-34`, probed with `AServiceManager_checkService` at
  `:140`). Without it, it logs `No supported HAL version` (`:180`), and A2DP connects with no audio path
  (`docs/WIFI_BT_0927.md:108-112`).
- **Samsung serves a different interface.** It is `vendor.samsung.hardware.bluetooth.audio` v2
  `ISehBluetoothAudioProviderFactory/default` (`reference/stock/vendor/etc/vintf/manifest/seh_bluetooth_audio.xml:7-9`).
  It is labelled `hal_audio_service` (`reference/stock/vendor/etc/selinux/vendor_service_contexts:51`), so the
  **audio HAL process** registers it.
- **Correction to the task text.** It cites `docs/CALL_CAPTURE_0928.txt` for this, but that file doesn't contain the
  name. The sources are `docs/BOOT_0927_3.md:135-140` and `docs/MODEM_0927.md:162-165`.
- **The audio HAL is AIDL and lives in an APEX.**
  - The APEX is `vendor/apex/com.android.hardware.audio.exynos.apex` (`reference/stock/vendor_ls_Z.txt:25`,
    `device/proprietary-files.txt:355`).
  - audioserver talks to its `bluetooth` module (`DeviceHalAidl: [bluetooth] setParameters`, served by pid 783
    `AHAL_Module`, `docs/logs/diag_1001_1203/07_audio_bluetooth.txt`).
  - `secaudiohalaidl` is a separate Samsung extension. It declares only `vendor.samsung.hardware.audio
    ISecAudioHal/default` (`reference/stock/vendor/etc/vintf/manifest/secaudiohalaidl_manifest.xml`).
- **The 01/10 capture has no Bluetooth session.** It shows `supportedBluetoothDevices: []`
  (`07_audio_bluetooth.txt`), `mBluetoothName=null` and `mA2dp: null`
  (`docs/logs/diag_1001_1203/06_dumpsys_audio.txt:312, 573`). It also has no Bluetooth denial. So it can't show
  the failure itself. The checks in section 6 can.

### How the AOSP software path is built

1. **The provider and the module talk through process memory, not binder.**
   - The provider reports a session with `BluetoothAudioSessionReport::OnSessionStarted`
     (`hi` `bluetooth/audio/aidl/default/A2dpSoftwareAudioProvider.cpp:102`).
   - The audio module reads it with `BluetoothAudioSessionControl`
     (`hi` `audio/aidl/default/bluetooth/DevicePortProxy.cpp:99, 148, 264`).
   - Both go through `BluetoothAudioSessionInstance::GetSessionInstance`, a **static, per-process map**
     (`hi` `bluetooth/audio/utils/aidl_session/BluetoothAudioSession.cpp:742-759`, `BluetoothAudioSession.h:233-243`).
2. **So AOSP always runs the provider inside the audio HAL process.**
   - The HIDL audio service `dlopen`s `android.hardware.bluetooth.audio-impl` and calls
     `createIBluetoothAudioProviderFactory` (`hi` `audio/common/all-versions/default/service/service.cpp:136-140, 162-167`).
   - The AIDL example HAL links it (`hi` `audio/aidl/default/Android.bp:137-140`).
   - The platform labels the instance `hal_audio_service` (`sepol` `private/service_contexts:40`).
3. **Software vs offload is decided by two properties, and offload is already off.**
   - The stack enables offload only if `ro.bluetooth.a2dp_offload.supported=true` **and**
     `persist.bluetooth.a2dp_offload.disabled=false`. That is the native side (`bt` `system/btif/src/bluetooth.cc:210-221`,
     read by `btif_av.cc:1138`) and the Java side (`android/app/src/com/android/bluetooth/btservice/AdapterProperties.java:71-74, 183-185`).
   - Neither property is set anywhere in our tree or in stock's build.props: no match in `device/*.prop`,
     `reference/stock/extra/{vendor,system}/build.prop` or the 01/10 logs.
   - So the stack already picks the **software** path. `persist.bluetooth.samsung.a2dp_offload.cap`
     (`device/product.prop:40`) is read by nothing in `bt` (no match).

## 2. Routes ruled out (from sources)

| route | why not |
|---|---|
| Props only (`persist.bluetooth.a2dp_offload.disabled=true`, `ro.bluetooth.a2dp_offload.supported`) | Offload is already off (above). The rest of what the props do is pick the policy XML (`media` `audio/include/system/audio_config.h:88-114`). With an AIDL HAL, audioserver doesn't read that XML: it builds the policy from the HAL's ports (`av` `services/audiopolicy/service/AudioPolicyService.cpp:200-201`, `services/audioflinger/AudioFlinger.cpp:2651-2672`). A prop alone isn't a fallback (task, principle D). |
| `audio.bluetooth.default` (`bt` `system/audio_bluetooth_hw`) | It is a legacy libhardware module. audioserver prefers the AIDL HAL whenever one exists and then never loads a HIDL/legacy one (`av` `media/libaudiohal/FactoryHal.cpp:53-58, 151-170`). Neither stock nor our image has it. |
| Samsung's audio HAL loads the AOSP provider | On the 27/09 boot #3 the AOSP provider was installed **and** declared. Nothing ever registered it: 119 `ctl.interface_start` failures and 44 `Waited one second` (`docs/BOOT_0927_3_evidence.txt:61-63`). So Samsung's HAL doesn't call `createIBluetoothAudioProviderFactory`. |
| A standalone provider service (the option in `docs/MODEM_0927.md:174-177`) | **It can't work.** Its session map would be in its own process, and Samsung's `bluetooth` module would never see the session (fact 1). That earlier note is corrected here. |
| A bridge from the AOSP factory to `ISehBluetoothAudioProviderFactory` | We have no Samsung `.aidl` definition. The methods in the guide's pseudocode are invented (task, "Claims in that guide"). Not designable without sources. |
| Copy `bluetooth_audio_policy_configuration_7_0.xml` (guide's rule) | **Not needed.** It is already in our image as the stock blob, same size (`reference/ours/vendor_ls_Z.txt:377` = stock `:387`, 2,832 bytes; `device/proprietary-files.txt:45`). The live `audio_policy_configuration_sec_on_gsi.xml:31` already includes it. Samsung's HAL reads that file, not audioserver (row 1). |

## 3. The change: AOSP module and provider in one process

With every piece AOSP code, the provider and the module are in one process, so they share one session map.

| piece | what | source |
|---|---|---|
| provider HAL | `android.hardware.bluetooth.audio-impl`, the AOSP build. Its `bluetooth_audio.xml` declares `IBluetoothAudioProviderFactory/default` v5. | `hi` `bluetooth/audio/aidl/default/Android.bp:10-13`, `bluetooth_audio.xml`, `service.cpp:28-38` |
| audio HAL module | AOSP `ModuleBluetooth` (`Module::Type::BLUETOOTH`) with its built-in configuration: A2DP Out/Headphones/Speaker plus Hearing Aid Out, PCM 16-bit stereo 44.1-96 kHz. No XML needed. | `hi` `audio/aidl/default/Module.cpp:113-125`, `Configuration.cpp:626-689` |
| one process | `device/audio_bt/service.cpp` calls `createIBluetoothAudioProviderFactory()` first, then registers the module as `android.hardware.audio.core.IModule/a2dp`. It passes the configuration explicitly, because `createInstance(type)` alone gives an empty one (`hi` `include/core-impl/Module.h:51-53`). | modelled on `hi` `audio/aidl/default/main.cpp` |
| build | `device/audio_bt/Android.bp` copies the deps of AOSP's example binary (`hi` `audio/aidl/default/Android.bp:124-145`). `libaudioserviceexampleimpl` has no visibility limit. `libbluetooth_audio_session_aidl` is already ours (`device/device.mk:177`), and the provider and the module load the same copy. | |
| VINTF | `IModule/a2dp` v3. `latest_android_hardware_audio_core` is V3 (`hi` `audio/aidl/Android.bp:205`). The framework matrix allows `a2dp` (`compatibility_matrices/compatibility_matrix.202404.xml:8`) and version 3 (`compatibility_matrix.202504.xml:4`). Our framework matrix accepts 202504 versions: boot #3 built and booted with the provider at v5, which only 202504 allows (`:127`; 202404 allows 3-4, `:135`). | |
| init | `vendor.audio-hal-essi-bt`, `class hal`, user `audioserver`, with `interface aidl` lines for both instances. Scheduling and capabilities as AOSP (`hi` `audio/aidl/default/android.hardware.audio.service-aidl.example.rc:2-12`) and stock `secaudiohalaidl.rc`. | |
| SELinux | One label: `hal_audio_default_exec`, the existing domain of AOSP's AIDL example (`reference/ours/vendor/etc/selinux/vendor_file_contexts:275`) and of stock `secaudiohalaidl` (`:1538`). No new allow rule. `hal_audio_server` may add `hal_audio_service` (`sepol` `private/hal_audio.te:6`), and `bluetooth` is a `hal_audio` client (`sepol` `private/bluetooth.te:71, 85`). | |
| policy include | nothing to add (section 2, last row) | |

**Why the instance is `a2dp`.** Samsung's HAL already registers `IModule/bluetooth`. audioserver sorts modules
`primary, a2dp, usb, r_submix, bluetooth, …` (`av` `media/libaudiohal/impl/DevicesFactoryHalAidl.cpp:154-165`) and
keeps that order (`services/audioflinger/AudioFlinger.cpp:2663-2672`,
`services/audiopolicy/common/managerdefinitions/src/AudioPolicyConfig.cpp:153-157`). The policy takes the **first**
module that declares a device (`HwModule.cpp:306-330, 366-375`). So A2DP devices resolve to our module, ahead of
Samsung's `bluetooth`, which has no session to stream into.

**Correction (01/10 evening, section 7).** This missed that Samsung's **primary** module declares A2DP too, and
`primary` sorts first. The 15:11 capture shows A2DP going to primary. Section 7 removes A2DP from the primary policy.

**Unchanged:**
- LE Audio stays off (PR #17). Our module has no LE port anyway.
- HFP calls keep the SCO path: the HFP software datapath needs `bluetooth.hfp.software_datapath.enabled`, default
  false (`bt` `system/bta/ag/bta_ag_sco.cc:1689-1690`).
- No prop change.

### PR #11 / #16 lessons

- **#16, no service declared without a provider.** `IBluetoothAudioProviderFactory/default` is declared again only
  because a process now registers it. That process has an `interface aidl` line, so init can start it on demand.
- **#16, same-name trap.** The stock blob `vendor/lib64/android.hardware.bluetooth.audio-impl.so` is removed from
  `proprietary-files.txt`, so only the AOSP module installs that path.
  - The blob was kept "for whatever stock links it against". No evidence shows anything loads it: no NEEDED is known,
    and nothing registered the provider on boot #3.
  - The vendor makefiles have to be regenerated from the new `proprietary-files.txt`, or the old prebuilt and the AOSP
    module will clash at build time.
- **#11.** No allow rule, no `dontaudit`, nothing neverallowed: a single `file_contexts` line on an existing domain.

## 4. What is not proven yet

- **Whether Samsung's APEX already registers `IModule/a2dp`.** Its VINTF fragment is inside the APEX, which isn't in
  `reference/`. If it does, this build must not be flashed as is. Run capture A first.
- **FMQ memory access between `bluetooth` and `hal_audio_default`.** The plat policy covers AOSP's own setup, where
  the provider runs in `hal_audio_default`. Any denial will show in capture C.
- **The build.** It can't run here, so `device/audio_bt` is uncompiled.

## 5. Capture before building (A)

```
adb shell service list | grep -iE 'audio|bluetooth'
adb shell dumpsys media.audio_flinger | grep -iE 'loadHwModule|hw module|module'
adb shell 'ls -l /apex/com.android.hardware.audio*/etc/vintf/ /vendor/etc/vintf/manifest/ 2>/dev/null; cat /apex/com.android.hardware.audio*/etc/vintf/*.xml 2>/dev/null'
```

Go ahead if there's no `IModule/a2dp` and no `android.hardware.bluetooth.audio.IBluetoothAudioProviderFactory`.

**Result (Ange, 01/10 11:29, `service list`):** the audio instances are `IConfig/default` and `IModule/{bluetooth,default,r_submix}`,
plus `ISecAudioHal/default`, `ISehBluetooth/default` and `ISehBluetoothAudioProviderFactory/default`. There is no
`IModule/a2dp` and no AOSP `IBluetoothAudioProviderFactory`, so the build can go ahead. The first point of section 4
is settled.

## 6. Checks on the next boot (B, C)

**B. Service registered.** Pair a headset, connect it and play music, then run:

```
adb shell service list | grep -E 'IModule/a2dp|IBluetoothAudioProviderFactory'
adb shell ps -A | grep essi-bt
adb logcat -d | grep -E 'AHAL_EssiBt|BtAudioAIDLService|No supported HAL version|HalVersionManager'
adb shell dumpsys bluetooth_manager | grep -iE 'a2dp|codec|offload' | head -40
adb shell dumpsys media.audio_policy | grep -iE 'a2dp|HW Modules|module' | head -40
adb shell dumpsys audio | grep -iE 'mA2dp|bt_a2dp|mBluetoothName'
```

Pass:
- both instances are listed and the process is running;
- `A2dpOffloadEnabled: false`;
- the A2DP device belongs to module `a2dp`;
- sound plays on the headset.

**C. Denials and crashes.**

```
adb logcat -d | grep 'avc: denied' | grep -E 'hal_audio_default|bluetooth'
adb logcat -b crash -d | tail -50
```

If audio stays silent, run `adb bugreport`, or at least B and C in full, and send them back.

## 7. 01/10 15:11 test: connected, silent, routed to Samsung's primary module

Ange's captures are `docs/13_audio.txt` to `docs/17_audio.txt`; `16_audio.txt` is empty. The headset was
connected and playing, with no sound.

### What works

- **The Bluetooth stack side.**
  - The stack found our provider: `bluetooth` asked servicemanager for `IBluetoothAudioProviderFactory/default` at
    15:11:12, 4 times (`17_audio.txt:1-4`).
  - A2DP is active with offload off: `mActiveDevice: XX:XX:XX:XX:4A:4D`, `mA2dpOffloadEnabled: false`
    (`15_audio.txt`).
  - audioserver has the headset as an available device: `Port ID: 70; "BT A2DP Out"; @:XX:XX:XX:XX:XX:XX`
    (`14_audio.txt:3`).

### What is wrong

- **The connected device belongs to the first module, `primary`, not to `a2dp`.**
  - Port 70 with the headset address is listed under that module's `Declared devices (23)` and its mix ports
    (`14_audio.txt:5-9, 50-51`).
  - The active output (`curActiveCount: 1`, `:14`) is one of primary's mix ports.
  - Module `2. Handle: 18; "a2dp"` comes after it (`:58`). Its supported devices carry no address, so none of
    them is the connected device.
- **The reason is in the primary policy itself.** Samsung's primary policy declares A2DP: device ports `BT A2DP Out`,
  `BT A2DP Headphones` and `BT A2DP Speaker` (`reference/ours/vendor/etc/primary_audio_policy_configuration_sec_on_gsi.xml:140-151`),
  with routes from `primary output`, `fast output`, `deep_buffer`, `compressed_offload` and `mmap_no_irq_out`
  (`:198-203`).
- **Why that gives silence.** `primary` sorts before `a2dp` (section 3), and the policy takes the first module that
  declares the device. So the music goes to Samsung's HAL.
  - That HAL feeds A2DP through Samsung's own provider, `ISehBluetoothAudioProviderFactory`.
  - Lineage's stack never opens a session there. That last step is inferred, since we have no log of the HAL's
    A2DP stream.
- **The video test points the same way.** The video plays on the speaker but not on the headset (codec2 thread,
  18:46). So only the A2DP route fails.

### Change

`device/configs/audio/primary_audio_policy_configuration_sec_on_gsi.xml` is the stock file with only two edits: the
three A2DP device ports and their three routes are removed, and replaced by an XML comment.
- **Where it comes from.** It is copied from `reference/ours/vendor/etc/`, pulled from the phone, 14,243 bytes like
  stock `vendor_ls_Z.txt:459` and ours `:450`.
- **How it ships.** It is shipped by `PRODUCT_COPY_FILES` (`device/device.mk`), and the blob line is dropped from
  `proprietary-files.txt:50`. **Regenerate the vendor makefiles.**
- **Why this file.** This is the file Samsung's HAL builds its primary module from: its ports are exactly the live
  ones (`docs/IMS_STEP1_0928.md:87-97`).
- **What stays the same.** SCO, BLE and every other port are unchanged. Calls over a headset (SCO, primary) are not
  affected.

### Checks on the next boot

Connect the headset and play music, then run:

```
adb shell dumpsys media.audio_policy | grep -nE 'Handle:|BT A2DP|curActiveCount: 1|Declared devices' | head -40
adb logcat -d | grep -E 'AHAL_EssiBt|BtAudioAIDLService|BTAudio|a2dp_encoding|DevicePortProxy|StreamBluetooth|BluetoothAudio' | head -60
adb logcat -d | grep 'avc: denied' | grep -E 'hal_audio_default|bluetooth'
adb logcat -b crash -d | grep -E '>>> |pid: '
```

Pass:
- the port with the headset address is listed under `Handle: 18; "a2dp"`;
- `a2dp output` has `curActiveCount: 1`;
- the headset plays.

Also check two things are unchanged: speaker playback, and a call on the earpiece.

