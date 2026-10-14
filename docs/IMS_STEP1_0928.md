# IMS step 1: PhhIms in the build (28/09)

Plan: `docs/IMS_0928.md` §6, step 1.

The tester's decisions (28/09):
- The source is `xuanyayi/ims-for-wisdom`, branch `lineage-22.2`, pinned to a commit.
- QualifiedNetworksService comes later, with Wi-Fi calling.
- The project is added through the pipeline's `projects.txt` + `build.sh`, with no manifest change.

## 1. What the pipeline must add (outside this repo)

| field | value |
|---|---|
| repository | `https://github.com/xuanyayi/ims-for-wisdom` |
| path in the tree | `packages/apps/PhhIms` |
| commit (pin) | `4562d77e726e772ca0cf55a78862998a073f3909`, head of `lineage-22.2`, 2026-06-21, "ims: keep calls alive during downlink audio recovery" |
| submodule | `app/jni/rnnoise` → `https://github.com/amikhasenko/rnnoise`, gitlink `f94e734aa504e34100516c7d486cf69fc4174f00` (`.gitmodules`; `git ls-tree`) |

- **`build.sh` must initialise the submodule** after checkout:
  `git -C packages/apps/PhhIms submodule update --init --recursive`.
  - The native library `librnnoise_jni` compiles files from it (`app/jni/Android.bp:5-11`), and the app links it
    (`Android.bp:25`).
  - The fork's README warns that `repo sync` does not fetch submodules (README:239-246 at `353a65b`).
- **Don't take the fork's newer branches without review.** `lineage-23.2` and `derpfest-17` ship the carrier database
  generated from Samsung's IMS configuration, which our rule excludes (`docs/IMS_0928.md` §1). The pinned commit
  predates it.
- The repo also contains `keys/platform.pk8` (AOSP test keys) and a prebuilt `signapk/…so`. Both belong to its
  standalone Gradle build. Soong ignores them: the app is signed with the build's own platform key
  (`certificate: "platform"`, `Android.bp:15`).

## 2. What this PR changes

- **`device/device.mk`**, a new "IMS" block. It is active only when `packages/apps/PhhIms/Android.bp` exists:
  - `PRODUCT_PACKAGES += PhhIms`. Its static overlay `PhhImsOverlay` comes with it through `required`
    (`Android.bp:28`). That overlay sets `config_ims_mmtel_package` to `me.phh.ims` in `com.android.phone`
    (`overlay/res/values/config.xml:3`, `overlay/AndroidManifest.xml:5-8`), so we need no Telephony overlay of our
    own.
  - `android.hardware.telephony.ims.xml` from `frameworks/native/data/etc` (Lineage 22.2 `bc39ca6d`, `:19`
    `<feature name="android.hardware.telephony.ims" />`) goes into `/vendor/etc/permissions`, like the other
    features (`device.mk` feature block).
  - `device/configs/permissions/privapp-permissions-me.phh.ims.xml` goes into `/system/etc/permissions`.
- **Why the guard.** Android creates the IMS phone only when the feature is declared
  (`frameworks/opt/telephony` `PhoneFactory.java:255-263`, `:334-337`). Our rule is never to declare what nothing
  provides. So the feature and the ImsService ship together or not at all:
  - if the pipeline has not checked out PhhIms, the build is exactly today's;
  - PhhIms is a Soong module, so without the guard a missing checkout would fail the build.
- **Privapp allowlist.** The app's manifest requests one privileged permission, `READ_PRIVILEGED_PHONE_STATE`
  (`app/src/main/AndroidManifest.xml:11`). It runs as `android.uid.system` (`:6`) and is platform-signed. The
  allowlist follows the fork's integration notes (README:345-364), minus `MODIFY_PHONE_STATE`, which this branch
  does not request.
- **Unchanged on purpose:**
  - **VoLTE availability.** `carrier_volte_available_bool` stays `false` (`docs/response_0928.md` carrier-config
    dump), so calls still go the CS way. This step only proves that the ImsService binds and registers (plan
    steps 1-3). Turning VoLTE on is step 4.
  - **The Settings patch stays.** With the IMS feature declared, `isAdvancedCallingSettingEnabled` no longer throws,
    and the patch's guard is simply bypassed (`patches/…/VolteQueryImsState.java`, check on
    `FEATURE_TELEPHONY_IMS`). If a build ever lacks PhhIms, the guard above removes the feature and the patch keeps
    Settings from crashing. Remove it once IMS is confirmed working.
  - **SELinux.** The app runs in `system_app`: Lineage 22.2 `system/sepolicy` `private/seapp_contexts:180`,
    `user=system seinfo=platform`. That domain already has networking (`private/system_app.te:10`
    `net_domain(system_app)`) and may use `ipsec`, an `app_api_service` (`public/service.te:174`). No vendor policy
    change is needed. Watch for `system_app` denials on the next boot.

## 3. Answers from `docs/response_0928.md` and the pulled audio files

- **3G-only interim: works for outgoing calls.** Data drops to H+ because LTE is off in that mode (`docs/IMS_0928.md`,
  "No-IMS interim"). Still to confirm in that mode: an incoming call rings, and an incoming SMS arrives.
- **APN file.** It is at `/product/etc/apns-conf.xml` (1 367 060 bytes). The `grep` over `adb shell` found nothing
  because the quotes were eaten: the device received `mnc=15` without quotes. To check, pull it and grep on the PC:
  ```
  adb pull /product/etc/apns-conf.xml .
  grep -n -B8 -A8 'mnc="15"' apns-conf.xml | grep -B6 -A6 'mcc="208"' | grep -E 'carrier=|apn=|type='
  ```
  **Result (the tester, 28/09): our build has Free's IMS APN**, the same as stock
  (`reference/stock/extra/csc/system/system/etc/apns-conf.xml:3636-3642`), in both lists the file carries:
  - `:1108` `mcc="208" mnc="15" carrier="IMS" apn="ims" protocol="IPV4V6" roaming_protocol="IPV4V6" type="ims"`
  - `:4389`, the same entry with `network_type_bitmask="1|…|20"` (all RATs)
  - `:4390` is a second `ims` entry restricted to `mvno_match_data="F003"` (the Iliad Italy SIMs, GID-matched), which
    does not apply to the tester's SIM.

  So step 2 should reach `SETUP_DATA_CALL` for APN `ims`.
- **Carrier config** (`docs/response_0928.md`):
  - VoLTE and Wi-Fi calling are off.
  - SMS over IMS is allowed on LTE and NR (`imssms.sms_over_ims_supported_rats_int_array = [3, 5]`).
  - IPsec for SIP is on (`ims.sip_over_ipsec_enabled_bool = true`).
  - The ePDG is found through the PLMN name (`iwlan.epdg_address_priority_int_array = [1, 0]`, static address
    empty). That matches `docs/IMS_0928.md` §4.
- **Which audio policy is live.** It is **not** `audio_policy_configuration.xml`.
  - The live `dumpsys media.audio_policy` (response file) lists ports such as `voice_tx`, `incall_music_uplink`,
    `USB Device In` and `BLE Headset In`.
  - `reference/ours/vendor/etc/audio_policy_configuration.xml` declares none of them (its device ports are at
    `:32-68`).
  - So the loaded chain is `audio_policy_configuration_sec_on_gsi.xml`, which includes
    `primary_audio_policy_configuration_sec_on_gsi.xml` (`:25`).
  - The tester pasted that primary module on 28/09. It is the one that declares exactly those ports: mix ports
    `incall_music_uplink` and `voice_tx`, and device ports `USB Device In`, `BLE Headset In`, `Telephony Tx` /
    `Telephony Rx` and `Echo-Reference In`. That confirms it is the live one.
- **Audio route for an app-side call: present.**
  - The live policy routes the voice-communication usage to `Earpiece` and has `Built-In Mic`
    (`docs/response_0928.md`, dumpsys section).
  - The mixer paths have a dedicated communication use case, separate from the modem call:
    `communication-handset` (`reference/ours/vendor/etc/mixer_paths.xml:2717`) and `communication-handset-mic`
    (`:4672`), next to `incall-handset` (`:3069`) for the modem call.
  - That is the path `MODE_IN_COMMUNICATION` should select, and PhhIms uses that mode (`docs/IMS_0928.md` §3).
  - No `voip` port exists (the dumpsys grep for `voip` is empty), so the app plays through the normal outputs.
    That is fine for 16 kHz AMR-WB.
  - **The live primary module has the routes an app-side call needs** (from the tester's paste of
    `primary_audio_policy_configuration_sec_on_gsi.xml`):
    - `<route type="mix" sink="Earpiece" sources="primary output, fast output, deep_buffer, Telephony Rx"/>`: the
      normal app outputs reach the earpiece, not only the modem's `Telephony Rx`. The earpiece port runs 48 kHz mono;
      AudioFlinger resamples a 16 kHz `AudioTrack`.
    - `<route type="mix" sink="primary input" sources="Built-In Mic, Built-In Back Mic, …"/>`: a
      `VOICE_COMMUNICATION` `AudioRecord` captures from the handset mics through `primary input` (8/16/32/48 kHz).
    - The modem-call path is separate: `Telephony Tx` from the mics, `voice_tx` and `incall_music_uplink`, and
      `voice_rx` from `Telephony Rx`. PhhIms does not need it.
    - There is no `VOIP_RX` / `VOIP_TX` mix port, so VoIP uses the generic `primary output` and `primary input`.
  - **What the configs cannot show** is whether Samsung's HAL picks `communication-handset` /
    `communication-handset-mic` in `MODE_IN_COMMUNICATION`, or treats it like a modem call. Only a test shows that:
    a two-way call in any VoIP app on the current build (Linphone, Signal), with the phone at the ear. Do it before
    IMS step 5.
  - To keep the file citable, please push the real file with the others:
    `adb pull /vendor/etc/primary_audio_policy_configuration_sec_on_gsi.xml reference/ours/vendor/etc/`.

## 4. Next boot: what proves step 1, and steps 2-3

Filter for PhhIms logs (README:541-547):
```
adb logcat -v threadtime 'PHH SipHandler:D' 'PHH MmTelFeature:D' 'ImsPhone:D' 'ImsPhoneCallTracker:D' 'ImsResolver:D' '*:S'
```

1. **Installed and declared.**
   - `adb shell pm list features | grep telephony.ims` shows `feature:android.hardware.telephony.ims`.
   - `adb shell pm path me.phh.ims` returns `/system/priv-app/PhhIms/…`.
2. **Bound as the MmTel provider.**
   - `adb shell dumpsys ims` or `dumpsys telephony.registry` lists `me.phh.ims` for MMTEL on slot 0.
   - The SIM settings page still opens.
3. **IMS bearer and P-CSCF.** `RILJ > SETUP_DATA_CALL` for APN `ims`, then `PHH SipHandler: Got pcscfs [...]`.
4. **Registered.**
   - `PHH SipHandler: REGISTER 200 OK acknowledged`, then
     `PHH MmTelFeature: IMS SIP registered, reporting registration tech …`.
   - `*#*#4636#*#*` shows IMS registered.
   - A `403` after the AKA challenge means Free filters devices (`docs/IMS_0928.md` §4).
5. **No regressions.**
   - 3G-only calls still work.
   - There are no `avc: denied … scontext=u:r:system_app` lines for `me.phh.ims`.

Once step 4 of this list shows registration, the next PR turns VoLTE on for Free (plan step 4).
