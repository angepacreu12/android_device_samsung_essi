# Modem network mode (01/10)

Task: `docs/TASK_1001_multi(1).md`, section "Modem network mode (Ange's decision, 01/10)". Follows PR #26
(`docs/DIRECT_COMMITS_1001.md` §1). Upstream sources: LineageOS `android_frameworks_base` `5c05c66e` (L-fb) and
`android_frameworks_opt_telephony` `6feb405d` (L-ot), the revisions PR #26 used.

## 1. The premise of "mode 33" was wrong

The task's reasoning: master has 20 (`device/vendor.prop:130-131`), mode 20 has no NR, and `nrState=NONE` (285×) in
`docs/logs/diag_1001_1203/04_telephony_registry.txt` shows it. So set 33 to allow 5G.

- **`vendor.prop` does not set the live mode.**
  - On 27/09 master had stock 9 (`80c00b1`, which made it 20, is dated 29/09), yet the live value was
    `persist.radio.def_network=[26,26]` (`docs/BOOT_0927_3_evidence.txt:76`).
  - On 01/10 the modem reported an allowed bitmap of `21380` three times
    (`docs/logs/diag_1001_1203/05_ril_ims_logcat.txt:2161`, `:2301`, `:2439`). The value is a framework bitmask
    (L-ot `NetworkResponse.java:57-61` converts it with `RILUtils.convertHalNetworkTypeBitMask`). Decoded with L-fb
    `TelephonyManager.java:15156-15244` (bit = network type − 1), it is UMTS, HSDPA, HSUPA, HSPA, LTE and HSPAP. That
    is neither mode 20 nor mode 9: it has no GSM and no TD-SCDMA.
- **What the framework sends to the modem is the per-SIM value, not a prop.**
  - `updateAllowedNetworkTypes()` sends `modemRaf & getEffectiveAllowedNetworkTypes()` (L-ot `Phone.java:2608-2622`).
  - The effective value is the AND of the per-reason values (`Phone.java:2354-2372`). They are loaded from the
    subscription database (`Phone.java:2444-2470`).
  - The prop-derived default (`RILConstants.PREFERRED_NETWORK_MODE` from `ro.telephony.default_network`, L-fb
    `RILConstants.java:256-259`) is used only for a reason with no stored value (`Phone.java:2418-2429`).
  - The 01/10 registry shows a stored "user" value (reason 0): `mAllowedNetworkTypeValue=130047`
    (`04_telephony_registry.txt:34-35`). Ange set the mode by hand on 28/09 (`docs/DIRECT_COMMITS_1001.md` §1).
- **The framework-side values in the 01/10 capture don't show NR, but the modem reports data on NR.** The
  modem reports `getRilDataRadioTechnology=20(NR_SA)` (30×, first at `04_telephony_registry.txt:10`). Corrected in §6:
  the modem's report is what counts. Framework-side values:
  - neither allowed bitmap above has the NR bit (`NETWORK_TYPE_BITMASK_NR`, bit 19 = 524288; 130047 and 21380 are both
    below it);
  - the serving physical channel is LTE band 8 (`04_telephony_registry.txt:36`, `mNetworkType=LTE`);
  - the PS registration's cell is a `CellIdentityLte` and `isEnDcAvailable = false` (`:10`).
  - These are framework or physical-channel reports. They don't override the modem's data registration (§6).

## 2. Which prop is read, and decision

| prop | who reads it | decision |
|---|---|---|
| `ro.vendor.sec.radio.def_network` | Samsung RIL side; the binary can't be searched from here. Stock ships **9** (`reference/stock/extra/vendor/build.prop:86`, `:157`) | **back to stock 9** |
| `ro.vendor.radio.def_network` (`95d8620`) | nothing in `reference/` (rc files, stock `build.prop`, property contexts; `docs/DIRECT_COMMITS_1001.md` §1) | **removed** |
| `ro.telephony.default_network` | init sets it at `post-fs-data` from `ro.vendor.radio.default_network` (`reference/ours/vendor/etc/init/init.vendor.rilcommon.rc:34-35`, same as stock). The framework reads it through `TelephonyProperties.default_network()` (L-fb `RILConstants.java:256-259`) | **not set.** Shipping it in a build prop would pre-empt init's copy, and it only applies when the SIM has no stored value |

Why 9 and not 33 or 26:
- 9 is the only value with a stock source (`NETWORK_MODE_LTE_GSM_WCDMA`, L-fb `RILConstants.java:181`).
- 9 is the value under which the live mode was 26 on 27/09 (`docs/BOOT_0927_3_evidence.txt:76`).
  - 26 is `NETWORK_MODE_NR_LTE_GSM_WCDMA` (`RILConstants.java:232`), i.e. 9 plus NR. *Inferred, not proven:* the
    RIL adds NR to this prop when 5G RF is on (`ril.enabled_5g_rf=1`, `docs/BOOT_0927_3_evidence.txt:96`).
- 33 is `NETWORK_MODE_NR_LTE_TDSCDMA_CDMA_EVDO_GSM_WCDMA` (`RILConstants.java:253`). It adds TD-SCDMA, CDMA and EvDo,
  which France doesn't use. Nothing shows it changes what the modem gets.
- 20 is `NETWORK_MODE_LTE_TDSCDMA_GSM_WCDMA` (`RILConstants.java:214`). It has no source.
- None of these values changes the live mode on this phone while a "user" value is stored for the SIM (§1).

Ange chooses the final value (decision card in the project thread). This PR ships 9 until then.

## 3. How 5G is actually allowed

5G is in use (§6). These are the conditions the framework applies:
- **The "user" value must include NR.** Set in Settings, per SIM (preferred network type with 5G). It is the value
  `getEffectiveAllowedNetworkTypes()` uses (§1). **Met after Ange's change at 13:24** (`logcatjsp.log:53`).
- **The carrier must allow NR.** The framework strips NR when the carrier config's `carrier_nr_availabilities_int_array`
  is empty (L-ot `GsmCdmaPhone.java:5299-5303`, applied at `Phone.java:2361-2363`). The AOSP default is NSA + SA
  (L-fb `CarrierConfigManager.java:11162-11163`). **Met:** Free's config has `[1, 2]` (`docs/logs/fp_1001/logcatims.log:1`).
  No overlay needed.
- **The framework intersects with the RIL's radio capability.** The framework sends `modemRaf & effective`
  (`Phone.java:2608-2622`), where `modemRaf` is the RIL's radio capability (`Phone.java:4401-4404`). This RIL
  reports 130047, without NR, yet the modem uses NR, so it doesn't appear to enforce this bitmap (§6).
- `persist.vendor.radio.nr_mode` / `persist.radio.nr_mode`: no source anywhere in `reference/`. Not added.

## 4. Pass criteria (from the task) and what is already known

- **VoLTE re-registers with data on the "NR" state:** `REGISTER 200 OK` at `05_ril_ims_logcat.txt:2669` (11:06) and
  `:3761` (11:57), while data was labelled NR from 10:37:33 (`04_telephony_registry.txt:287`). §1 says this state may
  not be real NR.
- **The only call (09:22-09:23) ran with data on LTE** (`05_ril_ims_logcat.txt:336`, `:754`, `:889`).
- **Still untested: a call while the modem is really on NR.** "Really" means an NR physical channel or a
  `CellIdentityNr`, not only the `NR_SA` label.
- If VoLTE breaks with NR allowed (Free has no VoNR), fall back to an entry without 5G in Settings. Don't use NR-only:
  it removes LTE.

## 5. Checks on the next boot

Reboot first, so the radio log has the boot-time load of the stored value.

```sh
# 1. Live radio props: what the RIL and init derived from vendor.prop
adb shell getprop | grep -E 'def_network|default_network|nr_mode|5g_rf'

# 2. Allowed network types: stored value, effective value, what was sent to the modem
adb logcat -b radio -d | grep -E 'load allowed network types|getEffectiveAllowedNetworkTypes|modemRafBitMask|ALLOWED_NETWORK_TYPES_BITMAP'
adb shell dumpsys telephony.registry | grep -E 'mAllowedNetworkType|mTelephonyDisplayInfo|mPhysicalChannelConfigs'

# 3. Does Free's carrier config allow NR?
adb shell dumpsys carrier_config | grep -i carrier_nr_availabilities

# 4. Then in Settings pick a preferred network type with 5G, wait for the 5G icon, rerun 2, and place a call.
adb logcat -b radio -d | grep -E 'ALLOWED_NETWORK_TYPES_BITMAP|modemRafBitMask'
adb shell dumpsys telephony.registry | grep -E 'mPhysicalChannelConfigs|CellIdentityNr|getRilDataRadioTechnology' | head -5
adb logcat -d | grep 'PHH SipHandler' | grep -E 'INVITE sip|SIP/2.0 [0-9]{3}|REGISTER 200 OK|Call-ID'
```

Mask the output as for the 01/10 logs (`docs/DIRECT_COMMITS_1001.md` §3, including the `imei:` URN) before committing.

## 6. Capture of 01/10 13:20-13:24 (`docs/logs/fp_1001/logcatjsp.log`)

- **The live default comes from a file in `/efs`, not from `vendor.prop`.**
  - `ro.vendor.radio.default_network=26`, `ro.vendor.radio.default_network_by=telephony.prop_26`,
    `ro.telephony.default_network=26` (`logcatjsp.log:13-15`).
  - `telephony.prop` is one of the files at the efs root (`docs/TASK_0927_csc.md:56`, `docs/CSC_phone_0927.txt:24`).
  - Neither `ro.vendor.sec.radio.def_network` nor `ro.vendor.radio.def_network` is in that `getprop | grep def_network`
    output (`:4-15`). The build that ran doesn't carry either line, or `getprop` doesn't list it.
    `adb shell grep def_network /vendor/build.prop` settles which.
- **The stored values:** `user=130047` and `enable_2g=545668` (`:16`). Decoded (bit = network type − 1):
  - 130047: every 2G/3G/4G type, TD-SCDMA, CDMA and EvDo, **no NR**;
  - 545668: UMTS, HSxPA, LTE and NR, **no GSM/GPRS/EDGE**. The "Allow 2G" switch is off.
- **After Ange picked a 5G mode,** the effective value gains NR: `…LTE|HSPA+|LTE_CA|NR` (`:53`). The stored user
  value is then 654335, i.e. 130047 + NR (`:58-59`).
- **The modem still gets no NR.** `modemRafBitMask = 130047` (no NR), so `filteredRafBitMask = 21380`: UMTS, HSxPA,
  LTE (`:54`). The modem confirms it with `GET_ALLOWED_NETWORK_TYPES_BITMAP {21380}` (`:51-52`).
- **The `NR` label is unreliable here too.** `mTelephonyDisplayInfo` says `network=NR` while the serving physical
  channel is UMTS (`:57`, `:60`).

**Correction (01/10, after Ange: "we already got 5G").** An earlier version of this section concluded that the
modem never gets NR. The evidence doesn't support that, so it is withdrawn.
- **What says 5G is used.** The modem's own data registration: `accessNetworkTechnology=NR` and
  `getRilDataRadioTechnology=20(NR_SA)` (`04_telephony_registry.txt:10`, 30×, from 10:37:33 on 01/10, `:287`), a data call set up on 5G
  (`SETUP_DATA_CALL … accessNetworkType=NGRAN`, `05_ril_ims_logcat.txt:3195`), the 5G icon
  (`mTelephonyDisplayInfo network=NR`, `logcatjsp.log:57`), and Ange's own use of the phone.
- **What is only the framework's view.** `GET_RADIO_CAPABILITY 130047` (`radio_capability.txt:4`) and the filtered
  bitmap `21380` (`logcatjsp.log:54`) are what the framework computes and sends. They don't prove what the modem uses.
  The live modem default is `persist.radio.def_network=26`, which includes NR (`logcatjsp.log:8`). *Inferred:* this
  Samsung RIL keeps its own mode and doesn't restrict NR on the framework's bitmap.
- **What is inconsistent, without a source to settle it.** The physical channel configs report LTE or UMTS while
  data is on NR (`04_telephony_registry.txt:36`, `logcatjsp.log:60`), and the cell identity is LTE. Most likely the
  RIL doesn't report NR physical channels. That is cosmetic for data.

So nothing is blocked on 5G and no RIL work follows. The `sehradiomanager` lead (`docs/TASK_0928_sehradio.md`) also
fails its precondition: the stock `radio.network-V1-ndk` interface hash is `8fb94cb4cf759f224987eb2d1908582a1f6f1600`
(Ange, 01/10), not Lineage's `0fac7647ce0de55319d9c5fa53bdf92cfdc1a5c2` (`android_hardware_samsung` `bb6e7b2`
`interfaces/radio/network/aidl/aidl_api/vendor.samsung.hardware.radio.network/1/.hash`). The client is not shipped.

**Still true from this capture:**
- The live default comes from `/efs` `telephony.prop` (26), not `vendor.prop`.
- The running image has stock 9 in `/vendor/build.prop` (`radio_capability.txt:9`).
- Free's carrier config allows NSA and SA.
- Still untested: a VoLTE call while data is on NR (§4).

## 7. Default mode 33 (Ange, 01/10 17:12)

Ange wants the mode picked on the phone to be the default: Phone info shows "NR/LTE/TDSCDMA/CDMA/EvDo/GSM/WCDMA",
i.e. `NETWORK_MODE_NR_LTE_TDSCDMA_CDMA_EVDO_GSM_WCDMA = 33` (L-fb `RILConstants.java:253`).

- **Change:** `ro.telephony.default_network=33,33` in `device/vendor.prop` (one value per slot).
- **Why this prop.** It is the framework's default (`RILConstants.PREFERRED_NETWORK_MODE`, L-fb
  `RILConstants.java:256-259`). `vendor.prop` can set it: `vendor_init` may set `telephony_config_prop`
  (`reference/system/system/selinux/plat_sepolicy.cil:8427`), its label (`plat_property_contexts:1565`). Lineage
  Samsung trees set it the same way (`android_device_samsung_sm7325-common` `7204b7d` `vendor.prop:202`, there
  `26,26`).
- **Effect on init's copy.** Build props load before `post-fs-data`, so init's
  `setprop ro.telephony.default_network ${ro.vendor.radio.default_network}`
  (`init.vendor.rilcommon.rc:35`) no longer changes it (read-only once set). Today that copy gives 26 from
  `/efs/telephony.prop` (§6).
- **When it applies.** Only for a SIM with no stored "user" value (`Phone.java:2418-2429`): after a data wipe or
  with a new SIM. A value picked in Settings or Phone info still wins.
- **Unchanged:** `ro.vendor.sec.radio.def_network` stays at stock 9 (§2). Nothing shows that the RIL reads it for
  the live mode.
- **DSDS** ("Activer DSDS" in the same screenshots) is already on by default: `persist.radio.multisim.config=dsds`
  (`docs/BOOT_0927_3_evidence.txt:78`). Nothing to add.

Check after a data wipe: `adb shell getprop ro.telephony.default_network` gives `33,33`. Phone info shows the
mode 33 entry only with §8's patch and "Allow 2G" on (§8).

## 8. Captures `docs/4g.txt` and `docs/5g.txt` (01/10 17:33-17:34)

Both files come from **the same boot** (same `system_server` pid 1424, same timestamps): `5g.txt` is `4g.txt` plus
about 20 s (`docs/5g.txt:41-52`). Neither holds a mode change, so they don't compare a 4G state with a 5G state.

**IPv6 works on 4G now.** With the APN set to IPv4/IPv6 and after a reboot:
- the initial-attach APN is `Free Mobile … IPV4V6, IPV4V6` (`docs/4g.txt:16`);
- the internet data call is set up on `accessNetworkType=EUTRAN` (LTE) with that APN (`docs/4g.txt:24`) and gets
  `protocolType=2` (IPv4v6) with an IPv4 and a global IPv6 address, plus IPv6 DNS (`docs/4g.txt:25`);
- on 01/10 13:20 the same APN was `IP` and the call had only IPv4 (`docs/logs/diag_1001_1203/05_ril_ims_logcat.txt:1863`).

So the earlier 4G failure was the IPv4-only connection still up from before the APN change; a reboot (or airplane
mode) re-attaches with IPv4v6. **Open:** the build still ships "Free Mobile" as `IP`, so a data wipe or a new SIM
brings the failure back. Stock ships it `IPV4V6`
(`reference/stock/extra/csc/system/system/etc/apns-conf.xml:3616-3624`). The fix needs the file the /e/OS image
takes its APN list from, which is not in the LineageOS 22.2 sources.

**Why Phone info shows LTE/WCDMA.** Android sends the modem the user's allowed types masked by the modem's radio
capability (`Phone.java:2609-2630` in L-ot `6feb405d`). The RIL reports 130047, which has no NR
(`docs/4g.txt:2`), so the mask sent is 21380 (LTE/WCDMA) at boot (`docs/4g.txt:12,20,38`), and the modem returns 21380
to Phone info (`docs/5g.txt:49-50`). Picking an NR mode by hand gives the same 21380
(`docs/logs/fp_1001/logcatjsp.log:53-54`), yet the modem was on NR then (`:57`): the mask alone does not decide
whether the phone reaches 5G. Mode 33 also has GSM, which Android removes while "Allow 2G" is off.

**Change:** `patches/frameworks/opt/telephony/0001-Phone-keep-NR-in-the-allowed-network-types-sent-to-t.patch`
adds NR to the radio capability before masking. NR is still sent only when the user, carrier and admin values allow
it (`Phone.java:2355-2363`; Free's carrier config allows NR, `logcatjsp.log:53`). With it and PR #40's default,
the modem receives mode 33 (or mode 33 without GSM while "Allow 2G" is off). Whether the modem then camps on 5G sooner
than today is not known: it reached NR with 21380 too.

Checks after the build (no mode picked by hand, "Allow 2G" on in the SIM settings):
```
adb logcat -d -b main,radio | grep -E 'filteredRafBitMask|GET_ALLOWED_NETWORK_TYPES_BITMAP \{'
```
`filteredRafBitMask` should hold the NR bit 524288 (TelephonyManager bit = network type − 1, NR = 20); with mode 33
and 2G allowed it is 654335 (130047 + NR). Phone info should then show NR/LTE/TDSCDMA/CDMA/EvDo/GSM/WCDMA.

## 9. Default changed to 4G/5G only (Ange, 01/10 17:41)

Ange: the modem reaches 5G when the preferred type is NR, so the default should be 4G/5G only.
`ro.telephony.default_network=24,24`: `NETWORK_MODE_NR_LTE = 24` (L-fb `RILConstants.java:226`), which replaces
mode 33 from §7 (same prop, same rules: only for a SIM with no saved choice). "Allow 2G" no longer matters, since
mode 24 has no 2G. Without §8's patch the mask would be LTE only (24 masked by 130047 drops NR), so the patch stays.
Trade-off: no 3G/2G fallback, so where there is no LTE or NR there is no service, and calls rely on VoLTE (which
works, `docs/IMS_1001.md`).

Check after the build: `filteredRafBitMask` should be LTE + LTE_CA + NR, and Phone info should show NR/LTE.
