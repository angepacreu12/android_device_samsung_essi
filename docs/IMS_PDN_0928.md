# IMS PDN on the PR #24 build (28/09 evening)

Evidence: `docs/ims_pdn_0928_grep.txt`. That is Ange's grep of the 18:25 capture, cited here as **G:N**; the number
after `:` in each line of that file is the line in the full log. Lineage sources are pinned as in
`docs/VERIFY_0928.md`.

## Verdict

**The Samsung RIL does not refuse the IMS PDN.**
- **The first attempt fails**, 2 ms after the radio came back from a power-off, with a Samsung-private cause. The
  internet APN fails the same way at the same moment.
- **The automatic retry 5 s later succeeds** over the standard `IRadioData`, and the IMS PDN is up on `rmnet1`.
- **About 14 s later the radio is shut down** (`reason = SHUTDOWN`), and both PDNs go with it.
- **So nothing in the device tree needs to change for this grep.** The next captures must show why the radio
  shuts down, and what PhhIms did with the PDN during those 14 s.

## 1. What the grep shows, in order

| time | line | event |
|---|---|---|
| 18:25:10.600 | G:1-5 | `DEACTIVATE_DATA_CALL cid = 1 reason = SHUTDOWN`, internet PDN down |
| 18:25:10.7-10.8 | G:6-9 | `mVoiceRegState=3(POWER_OFF)`: the radio is off |
| 18:25:13.115-126 | G:11-13 | `onSetupDataNetwork` / `> SETUP_DATA_CALL … [ApnSetting] IMS, 973, 20815, ims, … IPV4V6` |
| 18:25:13.128 | G:14 | `< SETUP_DATA_CALL DataCallResponse: { cause=UNKNOWN(0xfffffff9) retry=5000 cid=0 …` (2 ms later) |
| 18:25:13.279-342 | G:16-19 | at that moment voice is still `OUT_OF_SERVICE`: the modem is re-attaching |
| 18:25:13.661-663 | G:21-22 | the **internet** APN `free` fails with the **same** `UNKNOWN(0xfffffff9)` |
| 18:25:14.118 | G:24-25 | voice and data `IN_SERVICE`, operator Free: the attach is done |
| 18:25:18.178 | G:29-30 | retry: `> SETUP_DATA_CALL … IMS … ims`. The RIL logs `DefineContext: … mApn=ims` |
| 18:25:18.393 | G:34 | `< SETUP_DATA_CALL DataCallResponse: { cause=NONE(0x0) retry=-1 cid=2 linkStatus=2 protocolType=1 ifname=rmnet1 addresses=[<ims-pdn-ipv6>/64] dnses=[/fcff:a1::1, /fcff:a1:1::1] …` |
| 18:25:18.412 | G:38 | `state: CONNECTED … [ApnSetting] IMS, 973, 20815, ims` |
| 18:25:18.761 | G:45-47 | the internet PDN comes back too (`cid=1 rmnet0`) |
| 18:25:32.941-948 | G:51-54 | `DEACTIVATE_DATA_CALL cid = 2 reason = SHUTDOWN`, then `cid = 1 reason = SHUTDOWN`: the radio goes off again |
| 18:25:33.39-33.5 | G:65-68 | `POWER_OFF` again |

- **Failure cause.** `0xfffffff9` is `-7`, a cause Android does not know. AOSP's `DataFailCause` lists the negative
  vendor codes only down to `-5` (`RADIO_POWER_OFF`). That is LineageOS `android_frameworks_base` `5c05c66e`
  `telephony/java/android/telephony/DataFailCause.java:1091-1101`.
- **Where `UNKNOWN(0x10000)` comes from.** `getFailCause()` returns `UNKNOWN` (`0x10000`, `:1110`) for any code not
  in its map (`:1745-1751`). That is the "UNKNOWN(0x10000)" seen in the framework logs.
- **What `-7` means.** Its meaning is inside Samsung's RIL. Its timing and its hitting both APNs point to "not
  attached yet". It is not an IMS refusal.
- **The same goes for `cause: -21`** on the IMS PDN's teardown (G:57).

## 2. Does Samsung's RIL want the IMS PDN through ISehRadioData or ISehRadioChannel/imsd?

- **Not for setting it up.** The PDN that came up used the same standard request as the internet PDN:
  - `> SETUP_DATA_CALL` through `IRadioData`, the RIL's `DefineContext … mApn=ims`, then `cid=2` (G:29-34);
  - compare `mApn=free` and `cid=1` (G:40-45).
- **The Samsung-only NULL lines don't block anything:**
  - `RIL_GetFd: sehRadioBridgeService[0]->mSehRadioBridgeIndication == NULL` shows around **both** successful
    setups (G:31-32, 35-36, 42-43).
  - `RIL_ReadPacketBytes: mSehRadioDataIndication == NULL` shows only at teardowns (G:2, 55, 58). That looks like
    packet statistics.
  - Both are Samsung's optional indications, as in `docs/CALL_0928.md` §1c.
- **`ISehRadioChannel/imsd`** is the pipe for Samsung's own IMS daemon (`docs/IMS_0928.md` §2). PhhIms never uses it,
  and the PDN did not need it.

## 3. What PhhIms does on the Samsung Exynos devices it supports

- **It needs only a usable IMS bearer.** The fork's README lists "The RIL must expose a usable IMS APN/network and
  P-CSCF information, or DNS fallback must work" (`xuanyayi/ims-for-wisdom` README:124 at `353a65b`).
- **It asks for that bearer the standard way:** a `NetworkRequest` with `NET_CAPABILITY_IMS`
  (`ImsNetworkRequestBuilder.kt:27` at `4562d77`). That is what produced G:11-13.
- **No branch calls any `ISehRadio*` interface** (`docs/IMS_0928.md` §2).
- **Finding the P-CSCF.** PhhIms reads it from the bearer's `LinkProperties` (`SipHandler.kt:703-704`, logged as
  `Got pcscfs …` at :2092). If there is none, it tries ISIM candidates (:1384-1392), then DNS NAPTR on
  `ims.mnc015.mcc208.pub.3gppnetwork.org` (`ImsDnsDiscovery.kt:37-38`).
- **PhhIms never powers the radio off.** Its only airplane-mode code reads the setting (`SipHandler.kt:2224-2232`).
  So the two `SHUTDOWN`s did not come from PhhIms.

## 4. IMS needs LTE or NR, never 3G-only

- Free's carrier config allows IMS on `ims.supported_rats_int_array = [6, 3, 5]` (`docs/response_0928.md:75`).
- In the radio HAL's `AccessNetwork` enum those are `NGRAN`, `EUTRAN` and `IWLAN`: ordinals 0-6 are UNKNOWN, GERAN,
  UTRAN, EUTRAN, CDMA2000, IWLAN, NGRAN (LineageOS `android_hardware_interfaces` `89252f8f`
  `radio/aidl/android/hardware/radio/AccessNetwork.aidl:27-53`).
- So in "WCDMA only" mode the IMS PDN cannot come up. **Test IMS in LTE mode.** 3G-only stays the fallback for calls
  only.

## 5. SMS

Ange reports that SMS sends only in LTE mode, and replies never arrive in either mode. The grep has no SMS line, so
nothing can be concluded yet:
- In LTE mode without IMS, outgoing SMS goes over SGs, which worked on 28/09 (`docs/TASK_0928_call.md`).
- In 3G-only mode on Free's own UMTS it should go over CS. The failure code is needed.
- Once IMS registers, `imssms.sms_over_ims_supported_bool = true` (`docs/response_0928.md`) sends and receives SMS
  over IMS (`docs/IMS_0928.md` §6, step 7). That may make the SGs question moot.

## 6. Minimal fix and next captures

**Minimal fix: none in this repo for the PDN.** It works on the retry, over the standard path.

Four facts are missing. Capture one run in **LTE mode**, from boot to about 60 s after data is up, without toggling
airplane mode or the network mode during it:

```
adb logcat -b all -c; (reboot, unlock, wait ~90 s)
adb logcat -b all -v threadtime -d > ims2.txt
# 1. the full IMS DataCallResponse, not cut: is pcscf=[...] empty or not?
grep -n 'SETUP_DATA_CALL DataCallResponse' ims2.txt
# 2. what PhhIms did with the PDN
grep -n -E 'PHH (SipHandler|MmTelFeature)' ims2.txt | head -300
# 3. who turns the radio off (reason = SHUTDOWN)
grep -n -E 'RADIO_POWER|setRadioPower|RadioPowerStateStats|AIRPLANE|airplane|onRadioStateChanged|RADIO_STATE|SHUTDOWN' ims2.txt | head -120
# 4. SMS, once in LTE mode and once in "WCDMA only"
grep -n -E 'SEND_SMS|NEW_SMS|SMS_ACKNOWLEDGE|RP-ERROR|errorCode|GsmSMSDispatcher|ImsSmsDispatcher' ims2.txt
```

Reading the results:
- **P-CSCF.** If `pcscf=[]`, look for `P-CSCF NAPTR` lines. A failed DNS lookup would be the next blocker, and the
  last resort is `persist.ims.pcscf_fallback` (README:513).
- **Registration.** `REGISTER 200 OK acknowledged` means IMS registered, and the next PR turns VoLTE on (plan step 4).
  A `403` / `401` loop is the Free-side question (`docs/IMS_0928.md` §4).
- **SHUTDOWN.** If `RADIO_POWER` is requested by a framework component, the cause is on our side. If the RIL reports
  a radio-state change with no request, it is a modem reset. `persist.radio.silent-reset` was already `1`
  (`docs/BOOT_0927_3_evidence.txt`).
