# 27/09 (night): modem registration, then polish

Task: `docs/TASK_0927_modem.md` ("task" below; the live facts of 20:29 are its lines 16-34 and 51-62).
Line numbers refer to files of this repository unless a source path is named. Named sources were read from
the `lineage-22.2` branches of the LineageOS GitHub mirrors (`frameworks/opt/telephony`, `frameworks/base`,
`packages/modules/Connectivity`, `packages/modules/Bluetooth`, `hardware/interfaces`, `system/sepolicy`).
"Stock CIL" = `reference/stock/vendor/etc/selinux/vendor_sepolicy.cil`, "stock ppv" =
`reference/stock/vendor/etc/selinux/plat_pub_versioned.cil`. Nothing in `device/sepolicy/vendor/` or
`reference/baseline/` was touched; nothing from the relock families was added.

| # | item | change |
|---|---|---|
| 1a | `rild` / `vendor_secril_config_svc` denied on `persist.ril.*`, `ro.multisim.simslotcount` (Samsung system-side public types) | first device **system_ext** policy: `device/sepolicy_system_ext/{public/property.te,private/property_contexts}`, `BoardConfig.mk`, vendor rules in `sepolicy_extra/runtime.te`; check 1 emulates it |
| 1b | `vendor_secril_config_svc` cannot search `/mnt/vendor` (its config is `/mnt/vendor/efs/factory.prop`) | converter loss of a stock `{ domain -coredomain }` rule; written in `sepolicy_extra/runtime.te` |
| 1c | `mRadio*Indication == NULL`, "Service not connected" | not a HAL binding problem: same instances as stock; the error is the IWLAN network service, which stock gets from `com.sec.epdg`. No change |
| 2 | polish | facts and what is missing; no tree change (details below) |

## 1a. The RIL properties: which side labels them, and the system_ext policy

### What stock does

- Stock's *vendor* `property_contexts` has none of these names (`reference/stock/vendor/etc/selinux/vendor_property_contexts`),
  and its *system* `plat_property_contexts` maps only the AOSP prefixes: `ril.`, `ro.ril.`, `gsm.`, `persist.radio`
  -> `radio_prop` (`reference/stock/system/plat_property_contexts:40-43`), `persist.radio.multisim.config` ->
  `radio_control_prop` (`:697`), the `telephony_*` entries (`:1482-1497`). Identical to ours
  (`reference/system/system/selinux/plat_property_contexts:39-42, 754, 1553-1568`). `persist.ril.` is not covered
  by the `ril.` prefix, and `ro.multisim.` appears nowhere, so on both sides these names would be `default_prop`
  **unless** another system-side file maps them.
- That file is Samsung's system_ext (or product) property_contexts, which is **not in `reference/stock/`**
  (only `system/plat_file_contexts` and `system/plat_property_contexts` are). What we do have is the result: the
  stock vendor policy sets and reads two *system-side public* types, `rild_prop` and `multisim_prop`:
  - `rild` -> `rild_prop_202404` set + read (stock CIL 19609-19610). Its other system-side reads are
    `powerctl_prop`, `exported_radio_prop`, `sec_timed_prop`, `sec_ims_prop`, `product_ship_prop`
    (8924-8997) and it sets `exported_radio_prop` (8960).
  - `vendor_secril_config_svc` -> `multisim_prop_202404` set + read (18375-18376). These are exactly the two of
    its 15 stock rules the converter dropped (`docs/KNOWN_GAPS.md` section 1; ours has 13,
    `reference/ours/vendor/etc/selinux/vendor_sepolicy.cil`).
  - Both types are declared in the stock ppv as public types (`rild_prop` :5465-5467, `multisim_prop`
    :5471-5473) and listed in `property_type` (:54), `system_property_type` (:60) and
    `system_public_property_type` (:69). The `_202404` suffix means they come from the platform's public policy.
- `rild` and `vendor_secril_config_svc` are `hal_telephony_server` on stock (CIL 1348) and in ours
  (`device/sepolicy/vendor/vendor_secril_config_svc.te:3`), so the AOSP `radio_prop` rules already apply to them.
  The denials are only about the names outside the AOSP prefixes.

### Why a vendor `property_contexts` cannot do it

- `default_prop` is `system_internal_prop` and `system_prop` is `core_property_type`: a vendor domain may not
  read or set them (`system/sepolicy/private/property.te:169-180, 287-305`).
- A vendor `property_contexts` may only name `vendor.`, `persist.vendor.`, `ro.vendor.`, `ro.boot.`,
  `ro.hardware.`, `odm.`, ... (`build/soong/selinux_contexts.go:365-381`, `check_prop_prefix --strict` :400-407).
  `persist.ril.` and `ro.multisim.` are refused.

### The device system_ext policy (this PR)

Same mechanism Lineage uses for its own system_ext types (`device/lineage/sepolicy/common/sepolicy.mk:12-16`,
`public/property.te:2,5` with `system_vendor_config_prop`; image copy `reference/system/system_ext/selinux/system_ext_property_contexts`).

| file | content | stock fact it mirrors |
|---|---|---|
| `device/sepolicy_system_ext/public/property.te` | `system_public_prop(rild_prop)`, `system_public_prop(multisim_prop)` (`public/te_macros:973`: `type X, property_type, system_property_type, system_public_property_type`) | stock ppv :5465, :5471, memberships :54, :60, :69 |
| `device/sepolicy_system_ext/private/property_contexts` | `persist.ril.  u:object_r:rild_prop:s0`; `ro.multisim.simslotcount  u:object_r:multisim_prop:s0` | the three denied `persist.ril.*` names and the denied `ro.multisim.simslotcount` (task:29-31). **The entry forms are ours**: stock's own lines are in the missing system_ext file |
| `device/BoardConfig.mk` | `SYSTEM_EXT_PUBLIC_SEPOLICY_DIRS += .../sepolicy_system_ext/public`, `SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += .../sepolicy_system_ext/private` | built into `system_ext_sepolicy.cil`, its mapping, and `/system_ext/etc/selinux/system_ext_property_contexts` (`system/sepolicy/contexts/Android.bp:241-246`) |
| `device/sepolicy_extra/runtime.te` | `set_prop(rild, rild_prop)`; `set_prop(vendor_secril_config_svc, multisim_prop)` | stock CIL 19609-19610; 18375-18376 |

Neverallows: vendor rules on `system_public_property_type` are the allowed case of
`private/property.te:169-180`. Check 1 confirms it and was extended for this:
`tools/check_compile.py` now takes the system_ext dirs into the public policy and emulates the statements the
build adds to `system_ext_sepolicy.cil` and to the system_ext mapping for new public types (9 statements,
`tools/out/compile/system_ext_extra.cil`: the three attribute memberships, two `roletype`s, and the
`typeattributeset X_202404 (X)` + `expandtypeattribute` pairs, the same shape as the image's
`reference/system/system_ext/selinux/mapping/202404.cil:1-3`). Negative test: with `system_internal_prop(rild_prop)`
instead, the neverallow check fails on the `rild` set/read rules, as the build would.

What the converter will do later: `cil2te.py` takes the public types from the built image's
`plat_pub_versioned.cil` (`tools/cil2te.py:132`). After the next build, `rild_prop` and `multisim_prop` are in
it, so the stock rules 19609-19610 and 18375-18376 come back into `device/sepolicy/vendor/` by themselves; the two
`set_prop` lines in `sepolicy_extra` then duplicate them harmlessly and can be removed.

### Still open, and the file that would settle it

- 90 `rild` and 12 `vendor_secril_config_svc` reads of `default_prop`, 36 + 5 reads of `system_prop`
  (task:28-32): the property **names** are not in the evidence (a read denial carries none; logcat's
  "Access denied finding property" line does). Stock gives `rild` five more system-side types (above); which
  names they carry is in stock's `/system_ext/etc/selinux/system_ext_property_contexts` (and
  `/product/etc/selinux/product_property_contexts`), together with `/system_ext/etc/selinux/system_ext_sepolicy.cil`
  for the type declarations. Those three files are what `reference/stock/` needs to finish this table without
  guessing. `system_prop` names (`persist.sys.*`, `sys.*`) can only be moved by an exact entry, as for
  `persist.sys.sf.hs_mode` (`docs/KNOWN_GAPS.md` section 4).
- `hal_audio_default` -> `radio_prop` read (task:34): unchanged, row 7 of KNOWN_GAPS section 4.

## 1b. `vendor_secril_config_svc` cannot search `/mnt/vendor`

- What it needs: `/mnt/vendor/efs/factory.prop`, "for Dual / Single SIM settings"
  (`reference/stock/vendor/etc/init/init.baseband.rc:11-13`); `sim_config` runs `secril_config_svc SimConfig` at
  `on fs` right after the chown (`init.vendor.rilcommon.rc:22-31`), `network_config` runs `NetworkConfig` at
  `post-fs-data` and init then copies `ro.vendor.radio.default_network` into `ro.telephony.default_network`
  (`:33-35`). Three denials = the runs of these one-shots. Searching `/mnt/vendor` is the step before
  `efs_file`, which it may already read (`device/sepolicy/vendor/vendor_secril_config_svc.te:15-16` = stock CIL 18371-18372).
- Stock has no per-domain rule for it. It grants every vendor domain: CIL 11140
  `(allow base_typeattr_223_202404 mnt_vendor_file_202404 (dir (ioctl read getattr lock open watch watch_reads search)))`
  with `base_typeattr_223 = (and (domain) (not (coredomain)))` (stock ppv :7445), i.e.
  `allow { domain -coredomain } mnt_vendor_file:dir r_dir_perms`.
- **Converter loss.** Our built policy has 28 of stock's 42 `allow` rules with an attribute-set source; the 11
  missing ones (stock CIL 7250-7252, 7259, 10453-10454, 11133, 11140-11141, 11144-11145) all use sets defined
  in the stock ppv rather than in the vendor CIL (`base_typeattr_223`, `245`, `280`). `cil2te.py` resolves sets
  from the statements it parses (`tools/cil2te.py:440-455`: a set it cannot resolve drops the rules that use it).
  Besides `/mnt/vendor`, the same set carries `sysfs_ss_writable` dir/file access for every vendor domain
  (11144-11145: the `epicd`/`hal_hyper_default` denials of 27/09 boot #1 were exactly that) and
  `vendor_bssl_post_prop` (11141). The `245` and `280` rules are app-side (`appdomain` sets on Samsung
  services) and two of them name `knox_analytics_*` services, so they are not taken over here.
- Fix (`device/sepolicy_extra/runtime.te`): the stock rule itself, `allow { domain -coredomain } mnt_vendor_file:dir r_dir_perms;`.
  AOSP forbids this class only to `coredomain` (`private/domain.te:1503-1510`). Check 1 passes.
- Converter follow-up (not in this PR): resolve `base_typeattr_N` from the stock ppv too, so the 11 rules are
  generated and this hand-written one becomes redundant.

## 1c. `mRadio*Indication == NULL`, "Service not connected": right instances, different cause

- **Instances and versions.** Our image declares the stock radio fragments unchanged
  (`device/proprietary-files.txt:644-645, 655`; `reference/ours/vendor/etc/vintf/manifest/vendor.samsung.hardware.radio_manifest_2_202404.xml`):
  AIDL `android.hardware.radio.{config,data,messaging,modem,network,sim,voice}` version 3, instances
  `IRadioConfig/default`, `IRadio*/slot1` and `/slot2`, plus Samsung's `ISehRadio*` (`sehradio_manifest`).
  Lineage 22.2's RIL binds exactly those: `HIDL_SERVICE_NAME = {"slot1", "slot2", "slot3"}`
  (`frameworks/opt/telephony/.../RIL.java:293`), `ServiceManager.waitForDeclaredService(IRadioX.DESCRIPTOR + "/" + slotN)`
  per service (`:853-945`), `IRadioConfig/default` (`RadioConfig.java:284-285`); interface version 3 maps to
  `RADIO_HAL_VERSION_2_2` (`RIL.java:6355`). The framework does not use `ISehRadio*`. The requests that
  succeeded in the evidence (`RADIO_POWER`, `SET_ALLOWED_NETWORK_TYPES_BITMAP`, the registration polls with
  modem answers) prove the AIDL connection works.
- **`radioStateChangedInd: mRadioModemIndication == NULL`** (6) and the two `mRadioConfigIndication` /
  `mRadioNetworkIndication == NULL` lines are Samsung RILC messages (vendor code, no source here): an
  unsolicited indication arrived before the framework had registered its callbacks on that instance. The
  framework registers them when it first obtains the proxy (`RIL.java:859-862` for data, same pattern per
  service). Small counts at boot are consistent with ordering, not with a wrong instance; if they kept
  repeating after the RIL connected, that would be new evidence.
- **"Service not connected."** (21) is not the radio HAL. It is thrown by `NetworkRegistrationManager` when the
  *NetworkService app* it should bind to is not connected (`NetworkRegistrationManager.java:133-139`). SST keeps
  one manager per transport (`ServiceStateTracker.java:749`) and polls the WLAN (IWLAN) one too
  (`:3487-3491`, `EVENT_POLL_STATE_PS_IWLAN_REGISTRATION`); the failed poll is logged at `:2026-2028, 2046-2048`. The
  package comes from `config_wlan_network_service_package` (`NetworkRegistrationManager.java:292-300`,
  `bindService` refuses an empty name, `:246-249`): Lineage's default is **empty**
  (`frameworks/base/core/res/res/values/config_telephony.xml:142`), stock's is **`com.sec.epdg`**
  (`reference/stock/extra/system/framework-res.resources.txt.gz` :86770-86771; also its data service, :86764-86765).
  WWAN is `com.android.phone` on both (`config_telephony.xml:131-133`; stock :86785-86786). We do not ship
  Samsung's ePDG app, so the IWLAN poll fails every cycle. It is logged as an error but does not stop cellular
  registration; the same holds for `FeatureConnector: [ImsSmsDispatcher] connect: not supported` (no IMS).
- **Conclusion.** (c) is separate from (a) and (b) and is not what keeps the modem "not searching". The
  registration answers (`NOT_REG_MT_NOT_SEARCHING_OP`, `REG_DENIED_EM ... PLMN_NOT_ALLOWED` on 208-01) come from
  the modem. What the evidence does show broken on the modem side is 1b: both `secril_config_svc` runs could
  not open `/mnt/vendor/efs/factory.prop`, so whatever they configure from it (dual/single SIM settings,
  `init.baseband.rc:11`) was not applied on this boot. Re-check after this PR; if the modem still does not
  search, the next facts needed are the `secril_config_svc` and `RILD`/`SEC-RIL` logcat lines around
  "factory.prop", "NetworkConfig", "SimConfig", plus `getprop | grep -E 'ril\.|radio\.|multisim'`. The
  `PLMN_NOT_ALLOWED` on mcc 208 / mnc 01 is a foreign PLMN for a 208-15 SIM and is expected to be denied.

## 2. Polish

### Bluetooth audio: our stack cannot use Samsung's provider

- Lineage's stack asks for one exact instance: `android.hardware.bluetooth.audio.IBluetoothAudioProviderFactory/default`
  (`packages/modules/Bluetooth/system/audio_hal_interface/hal_version_manager.cc:33-34`;
  `aidl/client_interface_aidl.cc:71-72` checks `AServiceManager_isDeclared` on it, then `waitForService`,
  `:86, :111`). The name is a compile-time constant; there is no property to point it elsewhere.
- Samsung registers a different AIDL interface: `vendor.samsung.hardware.bluetooth.audio` v2
  `ISehBluetoothAudioProviderFactory/default` (`reference/stock/vendor/etc/vintf/manifest/seh_bluetooth_audio.xml:7-9`,
  library `vendor.samsung.hardware.bluetooth.audio-V2-ndk.so`, `proprietary-files.txt:1058`). A binder of that
  descriptor cannot be used as the AOSP one, so **no, the stack cannot use Samsung's provider** without new code.
- Providing the AOSP one is not just registering it. The AOSP provider reports its sessions through
  `BluetoothAudioSessionReport` (`hardware/interfaces/bluetooth/audio/aidl/default/A2dpSoftwareAudioProvider.cpp:22, 102`,
  `BluetoothAudioProvider.cpp:21, 49-164`) and the *audio HAL* must read them with the same library
  (`libbluetooth_audio_session_aidl`, `audio/aidl/default/bluetooth/StreamBluetooth.cpp` uses
  `BluetoothAudioSessionControl`). Our audio HAL is Samsung's `secaudiohalaidl` (`proprietary-files.txt:373`),
  which ships with `libsehbluetooth_audio_session_aidl.so` (`:1009`), the Samsung-side twin. Whether it also
  links the AOSP `libbluetooth_audio_session_aidl.so` (stock ships it too, `reference/stock/vendor_ls_Z.txt:2303`,
  and so does the AOSP `android.hardware.bluetooth.audio-impl.so`, :2165) is not visible from the listings: it
  needs `readelf -d` on the blob `/vendor/bin/hw/secaudiohalaidl` and on `/vendor/lib64/libsecaudiohalproxy_vendor.so`.
  - If it does: a small vendor service that calls `createIBluetoothAudioProviderFactory()` from the AOSP
    `android.hardware.bluetooth.audio-impl` (its `vintf_fragments` then declare the instance legitimately,
    because something registers it) would give A2DP software encoding.
  - If it does not: PCM from the framework never reaches the stack's session, and Bluetooth audio needs either
    Samsung's stack or an audio HAL built for the AOSP session library. Not a device-tree change.
- The AVRCP 1.6 / MAP 1.4 switch made by hand is consistent with this: the connection itself is fine; only the
  audio transport is missing.

### Screen edges: the values stock's framework has, and the file that holds the rest

- Our radius is stock's: 36dp x 450/160 = 101.25 px (`device/overlay/.../values/dimens.xml`; density
  `ro.sf.lcd_density=450`, `reference/stock/extra/vendor/build.prop:194`). The observed 101 px is that.
- Stock's **framework-res** declares no padding for it: `rounded_corner_content_padding` 0dp
  (`framework-res.resources.txt.gz` :358869-358870), `status_bar_height_portrait` 24dp (:360367-360368),
  `quick_qs_offset_height` 48dp (:358799-358800), all waterfall edge sizes 0px (:360991-361002), and no cutout
  (`config_mainBuiltInDisplayCutout` "" :85759-85760, `config_mainBuiltInDisplayCutoutForUDC` "" :85762-85763).
  So the values that keep Samsung's UI out of the corners are in **SystemUI** (OneUI), whose resource dump is
  still not in `reference/stock/extra/` (only `framework-res.*` under `system/`). Without it there is no stock
  value to cite for `rounded_corner_content_padding` or the status-bar paddings, and the camera hole has no stock
  geometry anywhere in the files we have. **No overlay change**; needed: the aapt2 dump of stock
  `SystemUI.apk` (`system/SystemUI*.resources.txt.gz`, as `docs/BOOT_0927_3.md` section 4 asks).

### Launcher: `can't create bitmap without a color space`

- The message is `Bitmap.createBitmap(DisplayMetrics, int, int, Config, boolean, ColorSpace)` refusing a null
  `ColorSpace` for any config but `ALPHA_8` (`frameworks/base/graphics/java/android/graphics/Bitmap.java:1225-1236`).
  Inside Bitmap itself the color space of a copy comes from `source.getColorSpace()` (`:989`), which the API
  allows to be null (`:1074`, `:1984`): a hardware bitmap whose buffer dataspace has no `ColorSpace` mapping.
- Our overlay's `config_availableColorModes` (`device/overlay/.../values/config.xml:20-25`) and
  `config_setColorTransformAccelerated` (`:27`) are read only by `ColorDisplayService`
  (`frameworks/base/services/core/.../ColorDisplayService.java:1081, 1117`), the Settings colour-mode
  machinery; nothing there produces a `Bitmap` color space. Both values are stock's (`docs/BOOT_0927_3.md`).
  The wide-colour properties are stock's too (`ro.surface_flinger.has_wide_color_display=true`,
  `use_color_management=true`, `ro.vendor.gpu.dataspace=1`: `device/vendor.prop:18, 25, 113` =
  stock `vendor/build.prop:140, 139, 130`).
- What is needed to go further: the full `AndroidRuntime` stack trace of the two crashes (the frame that calls
  `createBitmap` tells whether the null comes from a screenshot, a wallpaper or an icon buffer). No change.

### USB tethering: the NPE and the path that reaches it

- `Tethering.java:2227` (Lineage 22.2 `packages/modules/Connectivity/Tethering/.../Tethering.java`) is
  `enableTetheringInternal(request.getTetheringType(), ...)` in `EVENT_REQUEST_CHANGE_DOWNSTREAM` (`:2224-2228`).
  The event is posted by `IpServer.Callback.requestEnableTethering(request, enabled)` (`:2811-2814`) with the
  `IpServer`'s own `mTetheringRequest` (`IpServer.java:1182, 1466, 1471`), on a prefix conflict or a
  restart after `CMD_TETHER_UNREQUESTED` / `CMD_INTERFACE_DOWN`.
- `mTetheringRequest` is whatever `Tethering.tether()` passed to `IpServer.enable()` (`IpServer.java:427-429,
  1043-1045`): `mActiveTetheringRequests.get(type, null)`, and the request is **deleted from the map on first
  use** (`Tethering.java:1035-1039`). `startTethering()` puts it there (`:675-687`). The USB IpServer is
  (re)enabled from the `ACTION_USB_STATE` broadcast: `handleUsbAction` -> `changeUsbIpServing` when
  `configured && rndis` toggles (`:1256-1300`) -> `enableUsbIpServing` -> `enableIpServing` -> `tether()`
  (`:1576-1602, 1472-1477`).
- So a null request, hence the NPE, needs the USB interface to be tethered a **second time** after the request
  was consumed: an `ACTION_USB_STATE` sequence configured -> disconnected -> configured while USB tethering
  stays on. `getRequestedState()` even documents the map being empty by then (`:1091-1099`). Our USB path
  switches functions through `sys.usb.config` (`docs/BOOT_0927.md` section 1); the stock init script rebuilds
  the gadget for `rndis` and `rndis,adb` (`reference/stock/vendor/etc/init/init.s5e8855.usb.rc:379-410`),
  which the host sees as a disconnect and a new enumeration. Whether that produced two "configured rndis"
  broadcasts on this boot is not in the evidence: the `usb.txt` timeline of the boot catcher (state
  transitions) and the `Tethering` log lines "USB bcast connected:... configured:... rndis:..." (`:1262-1263`)
  around the crash would show it.
- Lineage devices with a gadget HAL take the same Java path; the difference is only whether the function switch
  re-enumerates. Nothing in the device tree changes this; a fix belongs in `Tethering.tether()` (keep the
  request for USB until `stopTethering`, `:706`). No change here.

## Checks

`tools/run_checks.sh`: checks 1-4 PASS (`docs/RESULTS.md`), check 1 now including the system_ext policy and
its property contexts (1456 entries). Boot catcher: `once.txt` also lists `/mnt/vendor/efs/factory.prop`.

## Checks on the next boot

- No `vendor_secril_config_svc` denial on `mnt_vendor_file`, `multisim_prop`; no `rild` set denial on `persist.ril.*`.
- `getprop ro.multisim.simslotcount` returns a value (set by `sim_config`); `persist.ril.cp_feature_type` exists.
- `dumpsys telephony.registry`: registration state other than `NOT_REG_MT_NOT_SEARCHING_OP` on slot 1, or
  the `secril_config_svc` / `SEC-RIL` log lines named in 1c.
