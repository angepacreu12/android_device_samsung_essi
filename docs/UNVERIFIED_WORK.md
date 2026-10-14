# Unverified and unfinished work

This repository holds the work that was merged and tested on the phone as of 02/10/2026. Seven more pieces of work
were written but never merged, or never tested on the phone. They are **not in this repository**. This file says
what each one does, how far it got and what is missing, so it can be redone or picked up later.

Status words:
- **written, not built:** code written, never compiled.
- **built, not tested:** it compiles, but no phone has run it.
- **partly tested:** some checks were run on the phone, not all.

## 1. Android 16 (LineageOS 23.2 / e/OS a16) base

**Status: built (sepolicy checks only), not booted.**

- **Goal.** Move only the system side to Android 16 (`lineage-23.2`, `android-16.0.0_r4`) and keep Samsung's
  Android 15 vendor, kernel 6.6.50, dtb and dtbo from A566BXXS6AYGE. Android 16 still accepts an Android 15
  vendor through the 202404 sepolicy mapping and `compatibility_matrix.202404.xml`.
- **Never flash a One UI 8 bootloader** (by OTA or Odin). It no longer has the OEM unlock code, so the
  One UI 8 firmware route is ruled out.
- **Done on the branch.**
  - The generated vendor policy failed two new Android 16 build-time checks:
    - `sepolicy_neverallows`: 6 Samsung grants to platform domains.
    - `sepolicy.recovery`: 22 binder rules that name service or file types.
  - Those statements were added to `tools/cil2te_exclusions.txt`. The still-allowed part of the platform grants
    was given back in a hand-written `sepolicy_extra/a16_platform.te`.
  - `tools/fetch_deps.sh` was pinned to the lineage-23.2 `system/sepolicy` and Lineage sepolicy commits.
  - `tools/check_compile.py` gained `--vers`, the `bp4a` release flags, the nlmsg macro files and `checkpolicy -N`.
  - The three platform patches (`frameworks/av`, `frameworks/opt/telephony`, `packages/apps/Settings`) were
    rebased onto lineage-23.2 with `git am -3`. The PhhIms patches did not change.
- **Missing.**
  1. Build `e_essi` from the a16 tree and fix the build errors.
  2. Turn the boot logger on before the first flash.
  3. Flash boot, init_boot, vendor_boot, dtbo, vbmeta and the payload. Keep the last Android 15 payload for
     rollback.
  4. Refresh `reference/system` and `reference/ours`, then run `tools/run_checks.sh`.
  5. Retest everything bottom up: boot and denials, modem and data (5G NSA/SA), SMS, VoLTE, Wi-Fi, Bluetooth
     audio, camera, fingerprint, sensors, brightness.

## 2. Camera: LineageOS Samsung camera provider (macro lens, torch levels)

**Status: written, not tested on the phone.**

- **Problem.** The camera works on master. But Samsung's provider exposes no macro camera and reports one torch
  level, where stock has about five.
- **Change.**
  - Replace Samsung's provider with LineageOS's Samsung AIDL camera provider (android_hardware_samsung
    lineage-23.2 `aidl/camera`, copied into `device/camera`). It loads the same `camera.unihal` module, reports
    5 torch levels and can expose the hidden IDs (`extra_ids` 54/52).
  - Drop Samsung's provider binary, rc and VINTF fragment. Move its boot actions to an `essi.camera.rc`.
- **Missing.** A test on the phone:
  - cameras 0-3 (photo and video);
  - `torchStrengthMaxLevel` = 5;
  - a new macro ID in `dumpsys media.camera`;
  - the secure camera 4 still hidden, and face unlock unchanged.
- **Risk.** The LineageOS rc has fewer groups than Samsung's. If the provider logs `EACCES`, check those first.

## 3. Sensors: LineageOS Samsung multihal (screen off during calls)

**Status: written, not tested on the phone.**

- **Problem.** On master the screen stays on during calls. Samsung's multihal declares the ear sensor only as
  `com.samsung.sensor.hover_proximity`, so Android finds no standard proximity sensor.
- **Change.**
  - Copy LineageOS android_hardware_samsung `aidl/sensors` into `device/sensors`. That is AOSP's AIDL multihal,
    which reports Samsung's proximity types as `android.sensor.proximity` and loads the same stock sub-HALs.
  - Drop the stock multihal binary, rc and VINTF fragment, and label the new binary `hal_sensors_default_exec`.
- **Missing.**
  - Regenerate the vendor makefiles.
  - Check that `dumpsys sensorservice` lists `android.sensor.proximity` (ideally wake-up), that the screen goes
    off in a call, and that auto-rotate and auto-brightness still work.
- **Possible build issue.** Sensors AIDL v3 is unfrozen on 22.2. If the VINTF check refuses the fragment, declare
  version 2.

## 4. SystemUI torch strength slider

**Status: written, not built.**

- **Change.** A `frameworks/base` patch: a long press on the flashlight Quick Settings tile opens a slider
  from 1 to `FLASH_INFO_STRENGTH_MAXIMUM_LEVEL`. It only appears when the back flash reports more than one
  level, so it depends on §2.
- **Missing.** Build and test. Android 16 has its own `flashlight_strength` support, so on the a16 base (§1)
  this patch may not be needed.

## 5. Minimum brightness floor

**Status: written, not tested.**

- **Problem.** Without the float brightness limits, the framework uses the integer minimum 10 (0.0354), so the
  lowest slider position is brighter than on stock.
- **Change.** Set the stock product RRO's minimum (float 0.0) in the framework overlay.
- **Missing.** A check on the phone that the lowest position matches stock and that the screen doesn't turn off.

## 6. PhhIms: incoming RTP sockets left unconnected

**Status: written, not tested here.**

- **Problem.** The other party's voice was lost while moving during a call (02/10).
- **Change.** Upstream fix `870a39a` (krazey, lineage-23.2): a connected UDP socket drops downlink RTP that comes
  from another address or port after a handover.
- **Outcome.** The report was in fact fixed on the network-mode side (all modes, with 4G/5G preferred, so the
  call can fall back). The patch stays a standalone upstream fix that hasn't been tested on this device.
- **Missing.** A call while moving, with the radio log showing the downlink RTP source.

## 7. SMS sent twice; network mode default

**Status: SMS patch written, not tested. The network mode default is still undecided.**

- **Sent twice.**
  - **Problem.** PhhIms waits 15 s for the network's RP-ACK. If the ack arrives later, the SMS is reported as
    failed, Android resends it over CS, and the recipient gets it twice.
  - **Change.** A PhhIms patch raises the wait to 60 s. RP-ERROR and terminal SIP failures still complete the
    SMS at once.
- **Received twice.** A hypothesis from the code only, not fixed: the RP-ACK sent back is never checked. It
  needs a log first.
- **Network mode.**
  - master ships mode 24 (NR/LTE only).
  - The branch went back and forth between 24 and 33 (all modes, 4G/5G preferred by the modem).
  - Mode 33 lets calls and SMS fall back to 3G where there is no LTE. Mode 24 avoids 3G.
  - Pick the default after an SMS and call test in weak coverage.
- **Note.** 5G SA was seen on the carrier after an airplane-mode cycle (02/10). But the "5G" picked in
  Phone info is a simulated, display-only RAT, so it proves nothing about the radio.

## Known missing bits on master

These are documented in the docs cited below. Each is either untested, partly working or a known gap.

- **Generated vendor policy** (`KNOWN_GAPS.md`):
  - 4,203 Samsung rules that name Samsung *system-side* types are dropped, because those types don't exist on
    LineageOS. Expect their denials in `dmesg`. They are believed non-fatal, but each one was not checked.
  - Some stock contexts could not be taken over (§2).
  - Some compile-time differences remain (§3).
- **Runtime denials.** Only the denials seen on the boots recorded in `KNOWN_GAPS.md` §4 have hand-written
  rules (`device/sepolicy_extra/`). Any domain not exercised on those boots may hit new denials.
- **Bluetooth audio** (`BT_AUDIO_1001.md` §7). On the 01/10 test the headset connected but was silent, because
  audio was routed to Samsung's primary module. The A2DP change that came after it was not confirmed on the phone.
- **Fingerprint (UDFPS)** (`FINGERPRINT_1001.md` §10-11). The LineageOS Samsung HAL and the sensor location
  overlay are in. A full enrol-and-unlock cycle on the final build is not recorded.
- **Codec2** (`CODEC2_1001.md`). The `frameworks/av` patch fixes Samsung's c2 service crash on paper. Check
  video playback and recording after each source sync.
- **IMS / VoLTE / Wi-Fi calling** (`IMS_1001.md`).
  - VoLTE registration and calls work on the tested carrier.
  - A VoLTE call while data is on NR is untested (`NETWORK_MODE_1001.md` §4).
  - Wi-Fi calling (QNS) is only built when the QNS checkout is there. There is no Android 15 QNS tag.
  - RCS is not available.
- **APN.** The build still ships the carrier APN as IPv4-only (`IP`). IPv6 works only after the protocol is
  changed by hand (`NETWORK_MODE_1001.md` §8).
- **Screen** (`SCREEN_0927.md` §4). The status bar and corner paddings have no stock value to copy. Corner
  clipping may remain.
- **Excluded on purpose.** Samsung's VaultKeeper/CASS relock stack (`VAULTKEEPER.md`, `IMAGE_GAPS.md`).
- **Checks.** `tools/run_checks.sh` last passed checks 1-4 on the Android 15 base (`RESULTS.md`). In this
  repository they need a locally filled `reference/stock` and `reference/ours` (see the top-level `README.md`).
