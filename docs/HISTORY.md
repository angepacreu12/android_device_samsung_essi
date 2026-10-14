# Development history: what "PR #NN", "PR A-D" and "TASK_*.md" refer to

This work was developed in a private repository from 26/09 to 05/10/2026, through about 40 pull requests. The
notes in `docs/` cite those pull requests by number and cite the task briefs that started each round of work.
Neither came over to this public repository:
- the history contained device identifiers;
- the task briefs were working instructions, not documentation.

This page is the key for those citations.

## Pull requests

`PR #NN` in the notes refers to the table below. The code of every merged PR is in this repository's first commit.
The unmerged branches are described in `UNVERIFIED_WORK.md`.

| PR | change |
|---|---|
| #1 | Vendor SELinux policy for essi generated from Samsung's stock CIL |
| #2 | sepolicy: recover Samsung system-side labels from reference/stock/system |
| #3 | sepolicy: stop converting Samsung's neverallows; emulate the build's neverallow and recovery checks |
| #4 | essi: ship the KeyMint HAL init script (vold metadata-encryption hang) |
| #6 | docs: stock vendor services missing from our image, with the proposed device-tree changes |
| #8 | essi: ship the stock WiFi, Bluetooth, sensors and dumpstate HAL files, vndservicemanager; dedupe contexts; drop ddp fstab flag |
| #10 | tools: check 4 (VINTF coverage); freeze the no-device-policy baseline under reference/baseline |
| #12 | sepolicy_extra: rules for the enforced denials of the 27/09 boot; checks cover the hand-written dir |
| #14 | essi: framework overlay (nav bar, doze off), boot-log captures for USB/Wi-Fi/modem, 27/09 analysis |
| #15 | essi: stock display values in the overlay + stock power_profile; Wi-Fi and modem facts from reference/stock/extra; check 3 exclusions |
| #16 | essi: stock feature XMLs (USB, dialer), drop the unprovided Bluetooth audio HAL declaration, boot #3 analysis |
| #17 | essi: ship the stock libwifi-hal.so, turn LE Audio off, check 3 matches renamed init scripts |
| #18 | essi: system_ext policy for the RIL properties, /mnt/vendor for secril_config_svc, modem and polish analysis |
| #19 | modem/CSC: /efs mount point, ro.vendor.boot param offsets, CSC/OMC analysis |
| #20 | overlay: screen edges from the stock product RRO (cutout, corner radii, status bar) |
| #21 | call: Settings IMS crash patch; voice-call and camera-loop analysis |
| #22 | verify: independent check of PR #20 (screen) and PR #21 (Settings patch, call analysis) |
| #23 | docs: sehradiomanager on hold (capture evidence); IMS feasibility study |
| #24 | IMS step 1: PhhIms + android.hardware.telephony.ims (guarded on the checkout) |
| #25 | docs: IMS PDN on the PR #24 build: no RIL refusal, radio SHUTDOWN kills it |
| #26 | Check of direct commits to master + mask the IMEI left in the 01/10 logs |
| #27 | Fingerprint: UDFPS location from the stock driver (01/10, PR D) |
| #28 | Modem network mode: back to stock 9, clean the 29/09 observation |
| #29 | Camera: shim Samsung's ALooper_forCamera so the camera provider stops crashing (PR C) |
| #30 | IMS: VoLTE switch and Wi-Fi calling for Free, PhhIms underrun fixes |
| #31 | PR B: Bluetooth audio, AOSP A2DP module and provider in one vendor process |
| #32 | docs/IMS_1001: the 01/10 IMS evidence was with data on 5G SA |
| #33 | Fingerprint: use LineageOS's Samsung HAL so enrollment starts captures |
| #34 | codec2: stop Samsung's hardware codec service from crashing |
| #35 | projects.txt: drop QualifiedNetworksService (no Android 15 source) |
| #36 | Patch hardware/samsung: drop its duplicate secril_config_svc |
| #37 | Patch hardware/samsung: drop radio.network AIDL and sehradiomanager |
| #38 | Fingerprint: copy LineageOS's Samsung HAL into device/fingerprint |
| #39 | Lock screen: draw the fingerprint icon at the right size |
| #40 | radio: default network mode NR/LTE and keep NR in the mask sent to the modem |
| #41 | docs: read PhhIms test lines from the radio log buffer |
| #42 | Bluetooth audio: drop A2DP from Samsung's primary audio policy |
| #43 | Boot logger: off by default, hard size cap on /metadata |

PRs #5, #7, #9, #11 and #13 were closed or folded into later PRs; no title is recorded. In the notes, "#9", "#11"
and "#16" are cited only for the lessons they left:
- no service may be declared without a process that provides it;
- no stock blob may share its install path with an AOSP module (the "same-name trap");
- a SELinux fix should be the smallest one, such as a single `file_contexts` line.

## Task briefs

`TASK*.md` files were the briefs for each work session. The note that answers each brief is in `docs/`:

| brief | topic | answered in |
|---|---|---|
| `TASK.md` | our own vendor SELinux policy (the starting point: boot hung on `tzdaemon`) | `APPROACH.md`, `KNOWN_GAPS.md` |
| `TASK_0927_stock_refs.md` | finish the overlay, Wi-Fi and modem fixes | `BOOT_0927.md` |
| `TASK_0927_features.md` | hardware features, USB, Bluetooth audio, Wi-Fi/BT addresses | `BOOT_0927_3.md` |
| `TASK_0927_wifi_bt.md` | Wi-Fi HAL library, Bluetooth LE Audio crash | `WIFI_BT_0927.md` |
| `TASK_0927_modem.md` | modem registration | `MODEM_0927.md` |
| `TASK_0927_screen.md` | screen edges from the stock product overlay | `SCREEN_0927.md` |
| `TASK_0927_csc.md` | Samsung CSC/OMC config for the modem | `CSC_0927.md` |
| `TASK_0928_call.md` | voice call stuck, Settings crash on the SIM page | `CALL_0928.md` |
| `TASK_0928_sehradio.md` | Samsung's framework-ready radio client | `SEHRADIO_0928.md` |
| `TASK_0928_ims.md` | IMS (VoLTE, VoWiFi) with an open-source stack | `IMS_0928.md`, `IMS_STEP1_0928.md`, `IMS_PDN_0928.md` |
| `TASK_0928_verify.md` | independent check of PR #20 and PR #21 | `VERIFY_0928.md` |
| `TASK_1001_multi(1).md` | four subsystems, one PR each: **PR A** IMS follow-up, **PR B** Bluetooth audio, **PR C** camera, **PR D** fingerprint | `IMS_1001.md`, `BT_AUDIO_1001.md`, `CAMERA_1001.md`, `FINGERPRINT_1001.md` |

`DIRECT_COMMITS_1001.md` (cited in `NETWORK_MODE_1001.md`) was a privacy review of the captures. It is not published.

## Captures

`docs/logs/…` and `docs/*.txt` were logcat, dmesg and dumpsys captures from the phone. They are not published
because they contain device identifiers. The notes quote the lines that matter.
