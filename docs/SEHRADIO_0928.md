# sehradiomanager (framework-ready client): on hold, 28/09

Task: `docs/TASK_0928_sehradio.md`, step 0 only. Evidence: `docs/CALL_CAPTURE_0928.txt` (28/09 10:51, build with
PR #19).

## Why nothing in the capture points at the framework-ready client

`docs/CALL_0928.md` §1d proposed Lineage's `sehradiomanager` in case the RIL was waiting on the framework. That
would show as a call held on LTE with no network activity, together with `FW_READY` / `phone.connected` /
`Indication == NULL` lines. The capture shows the opposite: **the modem does act on the dial, and the network
refuses the result.**

- **The dial is accepted and the modem leaves LTE (CS fallback).** `DIAL` goes out and returns (`:27`, `:33`). Two
  seconds later the phone is off Free LTE and on Orange's PLMN:
  - `< OPERATOR {, , 20801}` (`:38`), after `< OPERATOR {Free, Free, 20815}` (`:35`)
  - `gsm.operator.numeric` changes from `20815` to `20801` during the call (`:11-13`)
  - `gsm.network.type` changes from `LTE` to `Unknown` (`:5`, `:8`)
- **The target network denies registration.**
  `< VOICE_REGISTRATION_STATE RegStateResult{regState: REG_DENIED_EM, rat: UMTS, reasonForDenial: PLMN_NOT_ALLOWED`
  (`:40`, again after hang-up at `:47`). Data registration there is `NOT_REG_MT_NOT_SEARCHING_OP` (`:39`, `:45`).
  `REG_DENIED_EM` is "same as REG_DENIED but indicates that emergency calls are enabled" (LineageOS
  `android_hardware_interfaces` `lineage-22.2` `89252f8f`
  `radio/aidl/android/hardware/radio/network/RegState.aidl:63-65`). So on 20801 the phone may place only
  emergency calls.
- **The call stays DIALING because there is no network to set it up on.** Telecom shows DIALING → DIALING until the
  user hangs up (`:41`). `HANGUP` is accepted (`:42-43`).
- **MT call: the phone flips through LTE registrations and never rings.** There is no `CALL_RING` or
  `CALL_STATE_CHANGED`, only `VOICE_REGISTRATION_STATE REG_HOME, rat: LTE` and `OPERATOR` updates (`:50-55`).
- **MT SMS: `NEW_SMS count = 0`** (`:57`).
- **The framework-ready indicators do not move.**
  - `ril.phone.connected.slot1` is `false` idle and stays `false` during the MO call. It is not in the idle-vs-call
    diff (`:4-19`), and the snapshot shows it at `:23`.
  - The trimmed capture quotes no `FW_READY`, `csFallback`, `callDetails` or `Indication == NULL` line.
  - A RIL blocked on the framework would not have sent the modem to another PLMN.
- **The other step-0 inputs cannot decide anything either:**
  - The network-radio NDK hash is unreadable from `adb shell` ("Permission denied", `:84`), so the library-clash
    precondition is still open.
  - All six `ISehRadio*` HALs are registered for both slots, plus `ISehRadioChannel/imsd,imsd2,epdgd,epdgd2`
    (`:68-81`). That matches the manifest; `docs/CALL_0928.md` §1c has the table.
  - The EUX `cscfeature.xml` is encrypted (`:85`), so its voice-domain switches cannot be read.

**Verdict: stop after step 0.** The evidence points at the **network**. Circuit-switched fallback from Free LTE
(20815) lands on Orange 3G (20801), which rejects this SIM with `PLMN_NOT_ALLOWED`. The framework-ready client is not
the cause. `docs/TASK_0928_sehradio.md` stays on hold, and nothing is added to the build.

Next, per `docs/TASK_0928_ims.md`: voice and incoming SMS on Free here need IMS (VoLTE). The study is
`docs/IMS_0928.md`, which also covers the no-IMS interim of staying on Free's own 3G.

If `sehradiomanager` is revisited later, for signal bars or 5G as Lineage's commit claims, run this first on a rooted
or eng build to settle the library-clash precondition:

```
grep -a -o -E '[0-9a-f]{40}' /vendor/lib64/vendor.samsung.hardware.radio.network-V1-ndk.so
```
