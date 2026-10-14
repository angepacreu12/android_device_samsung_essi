# docs/

The investigation notes behind the device tree and the SELinux policy, kept as they were written, in date order
(`MMDD` in the file name, 2026). Start with `REPRODUCE.md`, `APPROACH.md`, `KNOWN_GAPS.md`, `RESULTS.md` and
`UNVERIFIED_WORK.md`.

**About citations.** The notes often cite raw evidence:
- logcat, dmesg and dumpsys captures (`docs/logs/...`, `docs/*.txt`);
- task notes (`TASK_*.md`);
- the stock firmware (`reference/stock/...`) and our built image (`reference/ours/...`).

None of these are published. The captures contain device identifiers (IMEI, serial number, network addresses,
cell IDs), and the firmware files are Samsung's. `reference/stock` and `reference/ours` can be rebuilt locally
(see the top-level `README.md`). The line numbers cited for them refer to the A566BXXS6AYGE firmware. The
captures are not available.

Identifiers that remained in the notes are masked (`XX:XX:XX:XX:XX:XX`, `<ims-pdn-ipv6>`, `<local>`).

| file | topic |
|---|---|
| [`APPROACH.md`](APPROACH.md) | Vendor SELinux policy for essi: approach |
| [`BOOT_0927_3.md`](BOOT_0927_3.md) | 27/09 boot #3 (build 20260927 12:41): features, USB, Bluetooth audio, Wi-Fi/BT addresses |
| [`BOOT_0927.md`](BOOT_0927.md) | 27/09 boot: navigation bar / display, USB data, Wi-Fi module load, modem |
| [`BOOTLOG_1001.md`](BOOTLOG_1001.md) | Boot log catcher: off by default, size-capped (01/10) |
| [`BT_AUDIO_1001.md`](BT_AUDIO_1001.md) | 01/10: Bluetooth audio (connects, no sound), PR B |
| [`CALL_0928.md`](CALL_0928.md) | Voice call stuck in DIALING, Settings crash on the SIM page (28/09) |
| [`CAMERA_1001.md`](CAMERA_1001.md) | Camera 01/10: `sec-camera-provider` exits with status 237 (PR C of `docs/TASK_1001_multi(1).md`) |
| [`cil2te_report.md`](cil2te_report.md) | cil2te report |
| [`CODEC2_1001.md`](CODEC2_1001.md) | Codec2 01/10: `samsung.hardware.media.c2@V1-service` crashes on its first codec |
| [`CSC_0927.md`](CSC_0927.md) | CSC/OMC config for the modem (27/09, late night) |
| [`FINGERPRINT_1001.md`](FINGERPRINT_1001.md) | Fingerprint (under-display): where the sensor geometry comes from (01/10, PR D) |
| [`IMAGE_GAPS.md`](IMAGE_GAPS.md) | Stock vendor services missing from our vendor image |
| [`IMS_0928.md`](IMS_0928.md) | IMS (VoLTE, then VoWiFi) with an open-source stack: feasibility, 28/09 |
| [`IMS_1001.md`](IMS_1001.md) | IMS follow-up (01/10): VoLTE switch, Wi-Fi calling, RCS, user-agent, audio underruns |
| [`IMS_PDN_0928.md`](IMS_PDN_0928.md) | IMS PDN on the PR #24 build (28/09 evening) |
| [`IMS_STEP1_0928.md`](IMS_STEP1_0928.md) | IMS step 1: PhhIms in the build (28/09) |
| [`KNOWN_GAPS.md`](KNOWN_GAPS.md) | Known gaps of the generated vendor policy |
| [`MODEM_0927.md`](MODEM_0927.md) | 27/09 (night): modem registration, then polish |
| [`NETWORK_MODE_1001.md`](NETWORK_MODE_1001.md) | Modem network mode (01/10) |
| [`OBSERVATION_0929.md`](OBSERVATION_0929.md) | Observation of 29/09 (cleaned) |
| [`REPRODUCE.md`](REPRODUCE.md) | Reproducing the work: exact files needed |
| [`RESULTS.md`](RESULTS.md) | Acceptance check results |
| [`SCREEN_0927.md`](SCREEN_0927.md) | Screen edges: the stock product overlay (27/09, night) |
| [`SEHRADIO_0928.md`](SEHRADIO_0928.md) | sehradiomanager (framework-ready client): on hold, 28/09 |
| [`UNVERIFIED_WORK.md`](UNVERIFIED_WORK.md) | Unverified and unfinished work |
| [`VAULTKEEPER.md`](VAULTKEEPER.md) | VaultKeeper / cass removal (relock investigation) |
| [`VERIFY_0928.md`](VERIFY_0928.md) | Verification of PR #20 (screen overlay) and PR #21 (Settings patch + call analysis), 28/09 |
| [`WIFI_BT_0927.md`](WIFI_BT_0927.md) | 27/09 (late): Wi-Fi HAL library, Bluetooth LE Audio abort |
