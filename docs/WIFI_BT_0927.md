# 27/09 (late): Wi-Fi HAL library, Bluetooth LE Audio abort

Task: `docs/TASK_0927_wifi_bt.md`. The runtime facts (logcat lines, file size on the phone) are the task's
(`TASK_0927_wifi_bt.md:21-30, 38-40`). Image facts come from `reference/ours` at commit e9076cf
("reference/ours: build 0927_1406"). Line numbers refer to files of this repository unless a source path is
named. Named sources were read from these trees:
- `packages/modules/Bluetooth` and `hardware/interfaces`: the `lineage-22.2` branches of the LineageOS GitHub mirrors.
- `frameworks/opt/net/wifi`: Lineage 22.2 takes it unmodified from AOSP (`LineageOS/android` `default.xml:621`,
  `refs/tags/android-15.0.0_r32`). It was read from the GrapheneOS `15-qpr2` mirror because googlesource is not
  reachable from this environment.

Ranked by impact. Nothing in `device/sepolicy/vendor/` or `reference/baseline/` was touched. The screen is left
as it is (task section 3).

| # | problem | change |
|---|---|---|
| 1 | Wi-Fi never starts: the vendor function table cannot be initialised | stock `vendor/lib64/libwifi-hal.so` added to `device/proprietary-files.txt` |
| 2 | `droid.bluetooth` aborts in a loop in the LE Audio broadcaster | the eight LE Audio profiles set to `false` in `device/product.prop` |
| 3 | check 3 failed on master since the 0927_1406 refresh | `tools/check_services.py` recognises stock scripts installed as `essi.<name>.rc` |

## 1. Wi-Fi: ship the stock `libwifi-hal.so`

### Why the HAL cannot start

- The stock `android.hardware.wifi-service` is what runs. Our copy has the stock size, 504152 bytes
  (`reference/ours/vendor_ls_Z.txt:318` = `reference/stock/vendor_ls_Z.txt:321`). It gets the vendor function table
  by calling `init_wifi_vendor_hal_func_table` through `dlsym(RTLD_DEFAULT, ...)`, so from the libraries it is
  linked with. When that call fails it logs "Can not initialize the vendor function pointer table"
  (`hardware/interfaces/wifi/aidl/default/wifi_legacy_hal_factory.cpp:97-112`).
- The library it is linked with, `libwifi-hal.so`, is the AOSP build in our image: 54000 bytes in `/vendor/lib64`
  (`reference/ours/vendor_ls_Z.txt:2634`). Stock's is 304096 bytes (`reference/stock/vendor_ls_Z.txt:2634`).
  `device/proprietary-files.txt` had no line for it, so the dependency resolved to the AOSP module.
- The AOSP module `libwifi-hal` (`frameworks/opt/net/wifi/libwifi_hal/Android.bp:213-243`) takes its vendor
  implementation from `BOARD_WLAN_DEVICE`. `slsi` is a known value (`:53-67`) and selects `libwifi-hal-slsi`
  (`:184-185`). Without a value it takes `libwifi-hal-fallback` (`:190-191`), whose
  `init_wifi_vendor_hal_func_table` returns `WIFI_ERROR_NOT_SUPPORTED`
  (`libwifi_hal/wifi_hal_fallback.cpp:19-21`). Our `device/BoardConfig.mk` sets no Wi-Fi flag at all. That fallback
  gives exactly the logged error and the 4 × `CMD_STA_START_FAILURE`.
- `/vendor/etc/wifi/vendor_hals` is optional. Its absence only produces the "failed to open" line
  (`wifi_legacy_hal_factory.cpp:31, 139`).

### Change

`vendor/lib64/libwifi-hal.so` is appended to the "Stock HALs left out" block of `device/proprietary-files.txt`,
right after the stock `android.hardware.wifi-service`, with a comment. Four facts decide whether the prebuilt wins:

- **Precedent in this build.** The stock `android.hardware.wifi-service` has the same module name as AOSP's
  (`hardware/interfaces/wifi/aidl/default/Android.bp:122`), and the stock file is what our image installs (size
  above). A same-named prebuilt from this blob list therefore replaces the AOSP module here. The generated
  prebuilts carry `prefer: true`; `device/fix-bp.sh:27` edits exactly that line.
- **Nothing extra installs from the AOSP module.** `libwifi-hal` has no `init_rc` and no `vintf_fragments`
  (`libwifi_hal/Android.bp:213-243`), so there is no script or VINTF declaration to keep out.
- **The prebuilt gets installed.** It is installed as a shared-library dependency of the stock wifi-service, the
  same way the AOSP copy was. This is not a PRODUCT_PACKAGES question. Compare `android.hardware.bluetooth.audio-impl.so`
  from PR #16: nothing links it, and it is absent from the 0927_1406 image altogether (no match in
  `reference/ours/vendor_ls_Z.txt`). So that blob line did not install. Nothing in the evidence shows that anything
  loads it, and its VINTF declaration is gone as intended (`reference/ours/vendor/etc/vintf/manifest.xml` has no
  `bluetooth.audio` entry).
- **Architecture matches.** Stock has it only in `/vendor/lib64`, which matches the AOSP module's
  `compile_multilib: "first"` (`libwifi_hal/Android.bp:216`).

### NEEDED libraries

The stock `.so` is not in this repository, so its ELF `NEEDED` list cannot be read here. These are the known
dependencies:

| library | why it is expected | available as a vendor module in our build |
|---|---|---|
| `libbase`, `libcutils`, `liblog`, `libnl`, `libutils` | the `shared_libs` of the AOSP `libwifi-hal` the stock one is built from (`libwifi_hal/Android.bp:226-232`) | yes (AOSP; `libnl.so` is in both images, stock `vendor_ls_Z.txt`, ours `vendor_ls_Z.txt`) |
| `libc++`, `libc`, `libm`, `libdl` | implicit for every C++ vendor library | yes |
| none extra from the SLSI part | Samsung's open-source `libwifi-hal-slsi` is a static library with no `shared_libs` (`LineageOS/android_hardware_samsung_slsi_scsc_wifibt_wifi_hal` `lineage-22.2` `Android.bp:3-31`) | n/a |

No `fix-bp.sh` or `device.mk` line is needed for these. If the stock file also links an AIDL
`android.hardware.wifi*-ndk`, `device/fix-bp.sh:24` already strips that dependency for every module and
`device/device.mk` installs the V2 `.vendor` variants. If extract-utils generates a dependency that does not exist,
Soong names it at build time ("depends on undefined module"); the fix is then one `sed` line in `fix-bp.sh`, like
`:9` for `libuuid`. To confirm before building, run `readelf -d vendor/samsung/essi/proprietary/vendor/lib64/libwifi-hal.so`
after extraction, or read its `cc_prebuilt_library_shared` stanza in `vendor/samsung/essi/Android.bp`.

### Board flags

- `BOARD_WLAN_DEVICE` feeds only the AOSP `libwifi-hal` (`libwifi_hal/Android.bp:53-67, 154-195`). With the stock
  library shipped it no longer matters. Setting it to `slsi` would instead require `libwifi-hal-slsi` from
  `hardware/samsung_slsi`, which is not in the Lineage manifest. That is the from-source alternative; the task asked
  for the blob.
- `WIFI_HAL_INTERFACE_COMBINATIONS` and the `WIFI_HIDL_FEATURE_*` flags are compile-time `cppflags` of the AOSP
  `android.hardware.wifi-service` (`hardware/interfaces/wifi/aidl/default/Android.bp:20-37`). We ship the stock
  binary, whose values are built in, so they are not relevant.
- Stock's Wi-Fi properties are already in our tree: `wifi.aware.interface` (stock vendor `build.prop:147` =
  `device/vendor.prop:45`), `ro.wifi.channels` and `ro.security.wlan.*` (stock system `build.prop:57, 181-182` =
  `device/system.prop:24, 114-115`).

## 2. Bluetooth: turn LE Audio off

### Why it aborts

- The broadcaster calls `log::fatal("HAL requirements not met. Init aborted.")` when the audio-HAL check fails
  (`system/bta/le_audio/broadcaster/broadcaster.cc:1493-1494`). That is the abort message in the task. Only a
  controller without ISO broadcast would return earlier (`:1487-1491`).
- The broadcaster is started by `LeAudioService.start()` when `LE_AUDIO_BROADCAST` is a supported profile
  (`android/app/src/com/android/bluetooth/le_audio/LeAudioService.java:580-593`). That is decided by
  `bluetooth.profile.bap.broadcast.source.enabled` (`:520-521`), and `device/product.prop:13` set it to `true`.
- With broadcast off, the unicast client would abort next. `LeAudioClient::Initialize` asserts the same HAL
  ("LE Audio Client requires Bluetooth Audio HAL V2.1 at least. Either disable LE Audio Profile, or update your HAL",
  `system/bta/le_audio/client.cc:6551-6553`). `LeAudioService` starts its native unicast `init()` whenever the
  service runs (`LeAudioService.java:613, 631`), and `bluetooth.profile.bap.unicast.client.enabled` enables it
  (`:516-517`, `device/product.prop:14`).
- Classic audio does not abort without the HAL. The AIDL client first asks whether the factory is declared
  (`system/audio_hal_interface/aidl/client_interface_aidl.cc:71-72`). With neither AIDL nor HIDL present,
  `HalVersionManager` only logs "No supported HAL version" (`system/audio_hal_interface/hal_version_manager.cc:179-180`).
  A2DP and hearing-aid init then return false instead of crashing (`a2dp_encoding.cc:56-62`,
  `hearing_aid_software_encoding.cc:36-41`, `bta/hearing_aid/hearing_aid.cc:2142-2153`).

### Which properties

AOSP's own "LE Audio off" switch turns off one group of profiles together:
- `setLeAudioProfileStatus` covers CSIP set coordinator, HAP client, LE Audio, LE call control, MCP server and
  volume control (`android/app/src/com/android/bluetooth/btservice/Config.java:254-261`).
- `setLeAudioBroadcastProfileStatus` covers the broadcast assistant and the broadcaster (`:263-266`).

Each of these reads its own property with a default of `false`. The source lines are in
`packages/modules/Bluetooth` `android/app/src/com/android/bluetooth/`:

| property | profile | read at | before (`device/product.prop`) | now |
|---|---|---|---|---|
| `bluetooth.profile.bap.broadcast.source.enabled` | LE Audio broadcast (the abort) | `le_audio/LeAudioService.java:520-521` | `true` (:13) | `false` |
| `bluetooth.profile.bap.unicast.client.enabled` | LE Audio unicast (the next abort) | `le_audio/LeAudioService.java:516-517` | `true` (:14) | `false` |
| `bluetooth.profile.bap.broadcast.assist.enabled` | broadcast assistant (BASS) | `bass_client/BassClientService.java:348-349` | `true` (:12) | `false` |
| `bluetooth.profile.csip.set_coordinator.enabled` | CSIP | `csip/CsipSetCoordinatorService.java:110-111` | `true` (:17) | `false` |
| `bluetooth.profile.hap.client.enabled` | HAP (LE hearing aids) | `hap/HapClientService.java:90-91` | `true` (:19) | `false` |
| `bluetooth.profile.vcp.controller.enabled` | VCP | `vc/VolumeControlService.java:156-157` | `true` (:30) | `false` |
| `bluetooth.profile.mcp.server.enabled` | MCP | `mcp/McpService.java:67-68` | `true` (:24) | `false` |
| `bluetooth.profile.ccp.server.enabled` | LE call control (TBS) | `tbs/TbsService.java:59-60` | `true` (:16) | `false` |

The `(:N)` values are the line numbers in `device/product.prop` before this change.

Values and origin:
- **Stock sets all eight to `true`.** These lines came with the initial device tree (`device/product.prop`, commit
  1f72347). The stock `product/etc/build.prop` they came from is not in `reference/stock/`.
- **Stock's system `build.prop` has no LE Audio line** (`reference/stock/extra/system/build.prop:79-90`: A2DP, ASHA,
  AVRCP, GATT, HFP, HID, MAP, OPP, PAN, PBAP).
- **Stock needs no AOSP provider for them.** Stock pairs these profiles with Samsung's own provider
  `vendor.samsung.hardware.bluetooth.audio` `ISehBluetoothAudioProviderFactory` (`seh_bluetooth_audio.xml:7-9`).
- **Nothing else sets these properties.** No other prop file of the tree does, and neither does any inherited
  product makefile (`vendor/lineage/config/*.mk`, `build/make/target/product/{full_base_telephony,telephony*,handheld_*}.mk`).
- **The dynamic switcher stays inactive.** `Config.init()` consults it only when broadcast or unicast is enabled
  (`Config.java:200-227`).

Unchanged and still on: A2DP source, AVRCP target, HFP AG, HID host/device, PAN, PBAP, MAP, SAP, GATT, ASHA and BAS.
Their audio path has no HAL (see above), so audio over classic Bluetooth is not expected to play. Pairing, BLE,
HID and file or data profiles are expected to work.

## 3. check 3 after the 0927_1406 refresh

On master, `tools/run_checks.sh` failed check 3 on 7 services: `vendor.keymint-default`, `hostapd`,
`vendor.bluetooth-default`, `vendor.dumpstate-default`, `vendor.sensors-hal-multihal`, `vendor.wifi_hal_legacy` and
`wpa_supplicant`. The real image installs their stock scripts as `essi.<name>.rc`
(`device/proprietary-files.txt:1161-1166`, `device/device.mk:303` for KeyMint, `reference/ours/vendor/etc/init/essi.*.rc`), and the check compared file
names only.

`tools/check_services.py` now also parses the scripts in `reference/ours/vendor/etc/init/`. A stock service counts
as shipped when a script of our image defines a service of the same name. The table shows e.g.
`android.hardware.wifi-service.rc (ours: essi.android.hardware.wifi-service.rc)`.

A test on a copy of the reference, with `essi.android.hardware.wifi-service.rc` removed from the directory and the
listing, still fails check 3 on `vendor.wifi_hal_legacy`. `cass`, `vaultkeeper` and `vaultkeeper_aidl` are no longer
in our image at all (`reference/ours/vendor_ls_Z.txt`), so the exclusion file is currently unused.

Result: checks 1-4 PASS (`docs/RESULTS.md`).

## Checks on the next boot

- `ls -l /vendor/lib64/libwifi-hal.so` shows 304096 bytes.
- `dumpsys wifi` shows no `CMD_STA_START_FAILURE`, and logcat has no "Can not initialize the vendor function pointer table".
- No `droid.bluetooth` SIGABRT, and `dumpsys bluetooth_manager` reaches state `ON`.
- The Bluetooth log line `Config: init: profile= LE_AUDIO, enabled=false` appears (`Config.java:244-251`).
