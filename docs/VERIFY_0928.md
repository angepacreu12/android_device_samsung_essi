# Verification of PR #20 (screen overlay) and PR #21 (Settings patch + call analysis), 28/09

Task: `docs/TASK_0928_verify.md`. Each claim was re-checked against a source fetched for this review. Nothing was
taken from the PR text or the earlier session's copies.

## Revisions opened

Lineage sources were fetched by commit hash, from the `lineage-22.2` heads on 28/09 (`git ls-remote`):

| repo (github.com/LineageOS/…) | revision |
|---|---|
| `android_packages_apps_Settings` | `a04dfa1c5ead9d78263ca21eaa79923bf65137ed` |
| `android_frameworks_base` | `5c05c66e872c907a925f633b69f11661c59e7ad0` |
| `android_packages_services_Telephony` | `4fe0d7081464f0d3eddf97f65ef11f63cf090dbe` |
| `android_frameworks_opt_telephony` | `6feb405d62073d98593e60cfc3f340874ba4594b` |
| `android_hardware_samsung` | `bb6e7b202f7deeeb5dd5a2f9a8c84d259e2cfe8b` |
| `android_system_core` | `bcb8623207cf6e7a51876a891d8b7ad3d04fd8c2` |
| `android_frameworks_native` | `bc39ca6d64ccd8b15f8cc43d9674d74b2ad9d802` |
| `android_vendor_lineage` | `87f03bdeafbf22dc35130c61ae2ff97f2041b90f` |

Our files are cited at master `f8a8115`. PRO = `reference/stock/extra/screen/stock_rro_product.txt`. FR =
`zcat reference/stock/extra/system/framework-res.resources.txt.gz`.

## The Settings patch against /e/OS `v4.3-a15`

**Unverifiable from this environment.**
- `gitlab.e.foundation` is refused by the session's network policy (proxy: `connect_rejected`,
  `gitlab.e.foundation:443`).
- No public mirror answered: `github.com/{e-foundation,eFoundation,e-os,murena}/android_packages_apps_Settings`
  and `gitlab.com/e/os/android_packages_apps_Settings`.

So the /e/OS manifest's Settings project and revision could not be read, and the patch could not be regenerated
against the /e/OS file.

**What is verified:**
- **Applies to Lineage.** `git apply --check` passes against LineageOS Settings `a04dfa1c`
  `src/com/android/settings/network/ims/VolteQueryImsState.java`, with no offset or fuzz.
- **Idempotent.** After applying, `git apply --reverse --check` passes, so `build.sh` can detect a patch that is
  already applied.
- **Format.** The file is `git format-patch` output. `git apply` accepts it and ignores the mail header (tested
  above).
- **Compiles.** `import android.content.pm.PackageManager;` is already at line 22 of the target file.
  `PackageManager.FEATURE_TELEPHONY_IMS` is used by the same class at :147.
- **Known base.** The patch's `index 5acf2db..2798a5e` line is the git blob hash of the Lineage file
  (`git hash-object` → `5acf2db2129d63bf82061e17b7360bef0bfa1890`).

**One command settles it on the build machine,** from the top of the /e/OS tree:

```
repo manifest -r | grep -E 'path="packages/apps/Settings"'
git -C packages/apps/Settings hash-object src/com/android/settings/network/ims/VolteQueryImsState.java
git -C packages/apps/Settings apply --check -v "$ESSI"/patches/packages/apps/Settings/*.patch
```

- **Hash is `5acf2db2129d63bf82061e17b7360bef0bfa1890`.** The file is byte-identical to Lineage's and the patch
  applies.
- **Hash differs but `--check` passes.** It applies too.
- **`--check` fails.** Send the file and the patch is regenerated against it, with the same logic.

## PR #20: screen overlay

| claim | source opened | result | correction |
|---|---|---|---|
| `config_mainBuiltInDisplayCutout` = the stock path, character for character | PRO :857-858; overlay `values/config.xml:21` (diffed by script) | confirmed, identical | none |
| `config_fillMainBuiltInDisplayCutout` = true | PRO :776-777; overlay `config.xml:23` | confirmed | none |
| `rounded_corner_radius` = 128px | PRO :807-808; overlay `values/dimens.xml:13` | confirmed | none |
| `rounded_corner_radius_top` = 42dp | PRO :813-814; `dimens.xml:15` | confirmed | none |
| `rounded_corner_radius_bottom` = 42dp | PRO :810-811; `dimens.xml:17` | confirmed | none |
| `status_bar_height_portrait` = 92px | PRO :822-823; `dimens.xml:20` | confirmed | none |
| `status_bar_height_landscape` = 24dp, stock framework-res literal | FR :360364-360365 (`0x01050568`, `24.000000dp`); `dimens.xml:24` | confirmed | none |
| AOSP aliases landscape to portrait | fw/base `core/res/res/values/dimens.xml:56` `@dimen/status_bar_height_portrait` (5c05c66e) | confirmed | none |
| The product RRO does not set `status_bar_height_landscape` | `grep` over PRO: no match | confirmed | none |
| Density 450, stock and ours | `reference/stock/extra/vendor/build.prop:194` `ro.sf.lcd_density=450`; `device/BoardConfig.mk:38` `TARGET_SCREEN_DENSITY := 450` | confirmed | none |
| Skipped as Samsung-only: `status_bar_camera_side_padding` 30px, `status_bar_camera_top_margin` 26px, `status_bar_indicator_corner_padding` 67px | PRO :816-817, :819-820, :825-826; 0 matches in fw/base `core/res/res/values/{dimens,config,symbols}.xml` and SystemUI `res/values/dimens.xml` (5c05c66e) | confirmed, none exists in Lineage 22.2 | none |
| Framework-res old values: 36dp top/bottom, fill false, rect approximation = path | FR :358890-358891, :358878-358879, :390807-390808, :85765-85766 | confirmed | none |
| AOSP defaults: cutout "" (config.xml:4116), rect approximation = `@string/config_mainBuiltInDisplayCutout` (:4124), fill false (:4129), radii 0dp (dimens.xml:116, :119, :122), portrait 24dp (:52), default 24dp (:44), content padding 0dp (:143) | fw/base 5c05c66e, the same lines | confirmed | none |
| Stock `rounded_corner_content_padding` 0dp | `reference/stock/extra/screen/stock_fw_0397.txt:2-3` | confirmed | none |
| Status bar height = max(cutout safe inset, default + waterfall); portrait dimen "Do not read … directly" | fw/base `SystemBarUtils.java:46-53`, :76-80; `dimens.xml:49-52` | confirmed | none |
| Radii: top/bottom win over the generic radius; fallbacks | fw/base `RoundedCorners.java:170-178`, :197-198, :225-226 | confirmed | none |
| SystemUI masks: radii only enable; size from an 8dp drawable | fw/base `RoundedCornerResDelegate.kt:105-109`, :111-120; `SystemUI/res/drawable/rounded.xml:14-22`; `SystemUI/res/values/config.xml:880-882` | confirmed | none |
| Cutout fill read by ScreenDecorations; main-display values used when no unique-id array | fw/base `ScreenDecorations.java:1253-1256`; `DisplayCutout.java:1047-1056`, :1062-1072, :1101-1115 | confirmed | none |
| SystemUI content padding points to the framework value | fw/base `SystemUI/res/values/dimens.xml:659-660` | confirmed | none |
| Lineage common overlays set no cutout, corner or status bar value | vendor_lineage 87f03bde `overlay/common/frameworks/base/core/res/res/values/config.xml`, `…/SystemUI/res/values/{config,dimens}.xml`: 0 matches; `…/core/res/res/values/dimens.xml` does not exist (404) | confirmed | none |
| The stock vendor RRO sets no cutout, corner or status bar value | `zcat reference/stock/extra/vendor/overlay_framework-res__…_rro_vendor.resources.txt.gz` grep: 0 | confirmed | none |

**Verdict PR #20: OK.** Every value, name and citation was confirmed, and no correction was needed.

## PR #21: Settings patch and call analysis

| claim | source opened | result | correction |
|---|---|---|---|
| The patch applies with `git apply` | Settings a04dfa1c `VolteQueryImsState.java`; `git apply --check` | confirmed for Lineage; **unverifiable for /e/OS** (see above) | none; `patches/README.md` now says `git apply` and gives the hash check |
| `PackageManager` is imported | Settings a04dfa1c `VolteQueryImsState.java:22` | confirmed | none |
| Guard pattern exists: `isVoImsOptInEnabled()` checks `FEATURE_TELEPHONY_IMS` | same file :146-151 | confirmed | none |
| `isEnabledByUser()` has no feature check | same file :134-139 | confirmed | none |
| `query()` calls `isAdvancedCallingSettingEnabled()` | Settings `…/ims/ImsQueryEnhanced4gLteModeUserSetting.java:43-47` | confirmed | none |
| The phone process throws without the IMS feature | Telephony 4fe0d708 `PhoneInterfaceManager.java:4970-4975` (calls the check), :14761-14781 (throws `UnsupportedOperationException`) | confirmed | none |
| The check applies only when `ro.vendor.api_level` >= V (35) | same file :14767-14770 (`mVendorApiLevel < VANILLA_ICE_CREAM` → skip), :2509-2510 (reads `ro.vendor.api_level`) | confirmed | none |
| Ours is 202404, same as stock | `device/vendor.prop:111`; `reference/stock/extra/vendor/build.prop:40` | confirmed | none |
| `init()` always creates the callback | Settings `Enhanced4gBasePreferenceController.java:72-75`, called from `MobileNetworkSettings.java:322` | confirmed | none |
| Availability and the `KEY_HIDE_ENHANCED_4G_LTE_BOOL` gate | same controller :98-120, :110-112 | confirmed | none |
| A hidden preference stays in the screen | fw/base `SettingsLib/…/AbstractPreferenceController.java:67-68` (`setVisible(…, false)`) | confirmed | none |
| Preference stored and callback registered regardless | controller :125, :133 | confirmed | none |
| The callback leads to `updateState`, then `isChecked`, then the IMS call | controller :220-222, :146, :178-180; Settings `core/TogglePreferenceController.java:68-70` | confirmed | none |
| `config_device_volte_available` / `config_carrier_volte_available` false in AOSP, true in stock | fw/base `config.xml:3804`, :3809; FR :390508-390509, :389859-389860 | confirmed | none |
| `RIL.java:1029-1033` registers the voice response and indication | opt_telephony 6feb405d, same lines | confirmed | none |
| "Voice services are bound only when `FEATURE_TELEPHONY_CALLING` is present (`RIL.java:296`)" | opt_telephony 6feb405d `RIL.java:295-296` is `FEATURES_TO_SERVICES`; its only reader is `validateFeatureFlags()` (:1307-1324), which only logs a mismatch (:1316-1322) | **wrong** | corrected in `docs/CALL_0928.md` §1b. The conclusion (voice is bound) stands on the live `DIAL` log |
| `IRadioVoice/slot1,slot2` v3 declared, identical to stock | `reference/ours/vendor/etc/vintf/manifest/vendor.samsung.hardware.radio_manifest_2_202404.xml:57-62`; `cmp` with stock: identical | confirmed | none |
| The ISehRadio table (1c) line ranges 6-10, 11-17, 18-22, 23-27, 28-32, 33-37 | `…/vendor.samsung.hardware.sehradio_manifest_2_202404.xml`; `cmp` with stock: identical | confirmed | none |
| `sehradiomanager` reads `/vendor/etc/sehradiomanager.conf`, defaulting to `FW_READY=1` | hardware_samsung bb6e7b20 `ril/sehradiomanager/sehradiomanager.cpp:88-92` | confirmed | none |
| It registers on `ISehRadioNetwork/slotN` and sends `setVendorSpecificConfiguration(0x4242, …)` | same file :94-105 | confirmed | none |
| It starts on `sys.boot_completed=1`, `class main`, user radio, `disabled` | same repo `ril/sehradiomanager/sehradiomanager.rc:1-8` | confirmed | none |
| `callDetailsChanged` / `csFallback` indications exist and are stubbed | same repo `ril/sehradiomanager/aidl/SehRadioNetworkIndication.cpp:35-44` | confirmed | none |
| Commit d6f5799 and its message | hardware_samsung `d6f5799cefc4d20a79e6105f85feb57b7c02975e` (2024-03-11, Tim Zimmermann): "samsung: Introduce sehradiomanager … signal bar, LTE+ and 5G working with RIL stacks from stock Android S and up … Based on TrebleDroid … f0eecb08" | confirmed | none |
| TrebleDroid f0eecb08 message | `github.com/TrebleDroid/platform_frameworks_opt_telephony` `f0eecb08…`: "Initialize Samsung HIDL ISehRadio. Fixes 5G on S20 Ultra" | confirmed | none |
| `interfaces/radio/network/aidl` is version 1, hash `0fac7647…` | hardware_samsung bb6e7b20 `interfaces/radio/network/aidl/Android.bp:16-18`; `aidl_api/vendor.samsung.hardware.radio.network/1/.hash` = `0fac7647ce0de55319d9c5fa53bdf92cfdc1a5c2` | confirmed | none |
| Our tree ships the stock network-radio library | `device/proprietary-files.txt:204` | confirmed | none |
| Network modes: 9 = LTE_GSM_WCDMA, 26 = NR_LTE_GSM_WCDMA | fw/base `RILConstants.java:181`, :232 | confirmed | none |
| `ro.vendor.sec.radio.def_network=9`, stock and ours | `reference/stock/extra/vendor/build.prop:86`; `device/vendor.prop:130` | confirmed | none |
| `ril.phone.connected.slot1/2=false`, `ril.lte.voice.status=1` | `docs/BOOT_0927_3_evidence.txt:110-111`, :105 | confirmed | none |
| init "updatable components" branch sets `sys.init.updatable_crashing` | system_core bcb86232 `init/service.cpp:364-366`, :391-395 | confirmed | none |
| servicemanager starts a declared, unregistered AIDL instance via `ctl.interface_start` | frameworks_native bc39ca6d `cmds/servicemanager/ServiceManager.cpp:872-884` | confirmed | none |
| init starts it even when `disabled` | system_core bcb86232 `init/init.cpp:556-557` (`interface_` → `FindInterface`), :408-410 (`DoControlStart` → `service->Start()`, no disabled check) | confirmed (newly cited) | none |
| The camera provider is declared and named in its rc | `reference/ours/vendor/etc/vintf/manifest/vendor.samsung.hardware.camera.provider-service.xml:6-10`; `…/init/vendor.samsung.hardware.camera.provider-service_64.rc:1-2` | confirmed | none |
| `proca` starts on `vendor.tzdaemon=Ready`, unchanged from stock | `reference/ours/vendor/etc/init/pa_daemon_teegris.rc:8-12`; identical to stock | confirmed | none |
| `/optics/configs` readable by every domain | Lineage 22.2 `system/sepolicy` `private/domain.te:177-178` (`tools/deps/system_sepolicy`) | confirmed | none |

**Verdict PR #21: OK after corrections.**
- One claim was wrong: the `RIL.java:296` "gate". It is corrected in `docs/CALL_0928.md` §1b, and the conclusion
  does not change.
- `patches/README.md` now describes `git apply`, the flow `build.sh` uses.
- The patch is correct for Lineage 22.2. Whether it applies to /e/OS `v4.3-a15` is **unverified** here, and the
  three commands above settle it before the build.
