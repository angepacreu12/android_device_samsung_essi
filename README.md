# essi: LineageOS / e/OS for the Samsung Galaxy A56 5G (SM-A566B)

This repository has four parts:

- a device tree;
- tooling that builds the **vendor SELinux policy** from the stock firmware;
- a few platform patches;
- the notes from bringing up /e/OS (LineageOS 22.2, Android 15) on the Galaxy A56 5G.

| | |
|---|---|
| Device | Samsung Galaxy A56 5G, SM-A566B, codename `essi` |
| SoC | Exynos 1580 (`s5e8855`) |
| Stock firmware used | A566BXXS6AYGE (Android 15, kernel 6.6.50) |
| Base | /e/OS v4.3-a15 = LineageOS 22.2 (`lineage-22.2`, Android 15) |

> **Status: work in progress, for developers.** It boots and the main hardware works (see below). Read
> [`docs/UNVERIFIED_WORK.md`](docs/UNVERIFIED_WORK.md) before you flash anything.

## Layout

| path | what |
|---|---|
| `device/` | the device tree; goes to `device/samsung/essi` in the source tree |
| `device/sepolicy_extra/`, `device/sepolicy_system_ext/` | hand-written vendor and system_ext SELinux policy |
| `device/sepolicy/vendor/` | **generated**: Samsung's stock vendor policy converted to `.te`/contexts by `tools/cil2te.py` (committed; do not edit by hand) |
| `device/prebuilts/` | **not in git**: kernel, dtb, dtbo, modules, ramdisk firmware and files (`tools/extract_prebuilts.sh`). Only the module lists (`modules.load`, `modules.blocklist`, `modules.list`) are tracked |
| `device/fingerprint/`, `device/audio_bt/`, `device/shims/`, `device/bootlog/` | HALs and helpers built from source |
| `tools/` | the policy converter and the four acceptance checks; see [`tools/README.md`](tools/README.md) |
| `reference/baseline/`, `reference/system/` | AOSP/LineageOS policy the converter and the checks compare against |
| `reference/stock/`, `reference/ours/` | **not in git**: the stock firmware's files and your build's files (`tools/populate_reference.sh`) |
| `patches/` | patches to platform projects; see [`patches/README.md`](patches/README.md) |
| `projects.txt` | extra projects the build clones (PhhIms) |
| `docs/` | investigation notes; see [`docs/README.md`](docs/README.md) |

## No Samsung files in git

The repository contains no Samsung binaries. Kernel, modules, ramdisk files and vendor blobs are extracted from
**your own copy** of the stock A566BXXS6AYGE firmware. The one Samsung-derived part that is committed is the
generated vendor policy in `device/sepolicy/vendor/` (see step 3). See [`NOTICE`](NOTICE).

### 1. Prebuilts (kernel, dtb, dtbo, modules, vendor_boot ramdisk files)

1. Unpack the stock firmware:
   - take `boot.img`, `vendor_boot.img` and `dtbo.img` out of the AP tarball and `lz4 -d` them;
   - take `vendor_dlkm.img` and `system_dlkm.img` out of `super.img` (`simg2img`, then `lpunpack`).
2. Then run:

```bash
UNPACK_BOOTIMG=<aosp>/system/tools/mkbootimg/unpack_bootimg.py tools/extract_prebuilts.sh <firmware dir>
```

The script copies exactly the modules named in `device/prebuilts/modules/*/modules.list`. With A566BXXS6AYGE
the output is byte-identical to what the tree was built and tested with.

### 2. Vendor blobs

Use LineageOS extract-utils with `device/proprietary-files.txt` (into `vendor/samsung/essi`):

```bash
device/extract-files.py <dump of the stock partitions>
```

`device/fix-bp.sh` then adjusts the generated `vendor/samsung/essi/Android.bp`.

### 3. Vendor SELinux policy

The vendor policy is in two parts, both committed:
- `device/sepolicy/vendor/`: generated from Samsung's A566BXXS6AYGE vendor policy. It is ready to build; you only
  need to regenerate it for another firmware version or after changing `tools/cil2te.py` or its exclusions.
- `device/sepolicy_extra/` and `device/sepolicy_system_ext/`: written by hand, for what the conversion cannot
  carry over (the runtime denials, the system_ext types).

To regenerate the generated part:
1. Mount the stock `vendor`, `odm` and `system` images read-only (the label listings need a mount).
2. Fill `reference/stock/` and regenerate the policy:

```bash
tools/populate_reference.sh /mnt/stock/vendor /mnt/stock/odm /mnt/stock/system
```

```bash
python3 tools/cil2te.py
```

`cil2te.py` writes `device/sepolicy/vendor/` and `docs/cil2te_report.md`:
- It converts Samsung's `vendor_sepolicy.cil` and contexts.
- It drops what LineageOS already provides, and what names Samsung-only platform types.
- It applies `tools/cil2te_exclusions.txt`.

Hand-written rules go in `device/sepolicy_extra/`, never in the generated directory. To check the policy:

```bash
tools/fetch_deps.sh
```

```bash
tools/run_checks.sh
```

The checks are: compile and neverallows, labels of every stock vendor file, init domain transitions for every
stock service, and VINTF coverage. Results go to `docs/RESULTS.md`. Checks 3-4 also need `reference/ours/` from
your build:

```bash
OUT_SUBDIR=ours tools/populate_reference.sh <out>/vendor <out>/odm <out>/system
```

### 4. Build

1. Put `device/` at `device/samsung/essi` in an /e/OS a15 (LineageOS 22.2) tree.
2. Apply `patches/` as `patches/README.md` describes, and clone the projects in `projects.txt`.
3. Run `lunch e_essi-bp1a-userdebug` (or `lineage_essi`), then `m`.

Optional: to trust your adb key in the built images, put it in `device/adb_keys` (gitignored).

## What works (A15 base, as tested on 01-02/10/2026)

- **Boot.** Boots with the generated vendor policy in enforcing mode.
- **Modem.** Registers, with data on 4G and 5G.
- **Calls and SMS.** VoLTE calls and SMS go through PhhIms. Wi-Fi works.
- **Camera.** The cameras work through Samsung's provider (with a shim).
- **Fingerprint.** The under-display reader uses LineageOS's Samsung HAL. The full enrol cycle is unconfirmed.
- **Display.** Overlay values come from stock: display, brightness, cutout, UDFPS position.

The open items and the work that was written but not merged are in
[`docs/UNVERIFIED_WORK.md`](docs/UNVERIFIED_WORK.md):
- Android 16 base;
- macro camera and torch levels;
- proximity sensor in calls;
- Bluetooth audio;
- the SMS duplicates.

## License

Apache-2.0 ([`LICENSE`](LICENSE)), except the PhhIms patches (GPL-2.0), the generated Samsung-derived vendor
policy (`device/sepolicy/vendor/`) and the third-party files listed in
[`NOTICE`](NOTICE). This project is not affiliated with or endorsed by Samsung.
