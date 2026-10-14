# Reproducing the work: exact files needed

This page lists every input needed for two jobs:
- rebuilding the vendor policy (`device/sepolicy/vendor/`) and rerunning the checks;
- building the vendor tree and the images.

Everything Samsung's comes from **one firmware**. Other versions differ: the kernel modules must match the
kernel, and the policy is converted rule by rule.

## 1. The firmware

| | |
|---|---|
| Model | SM-A566B (Galaxy A56 5G), product `a56xnaxx` |
| Build | `A566BXXS6AYGE`, Android 15, `a56xnaxx-user 15 AP3A.240905.015.A2 A566BXXS6AYGE release-keys` |
| File needed | the **AP** tarball: `AP_A566BXXS6AYGE_A566BXXS6AYGE_MQB99172836_REV00_user_low_ship_MULTI_CERT_meta_OS15.tar.md5` |
| Not needed | BL, CP, CSC, HOME_CSC (keep them to restore the phone to stock) |

Any firmware download tool for Samsung (e.g. samloader-style tools, or a Samsung firmware site) gives the full
`.zip` with the five tarballs. Only AP is used here.

**Never flash a One UI 8 (Android 16) BL.** It no longer contains the OEM unlock code (`docs/UNVERIFIED_WORK.md` §1).

## 2. Files inside the AP tarball and what uses them

```bash
tar xf AP_A566BXXS6AYGE_*.tar.md5 boot.img.lz4 vendor_boot.img.lz4 dtbo.img.lz4 super.img.lz4
```

```bash
for f in *.lz4; do lz4 -d "$f" "${f%.lz4}"; done
```

```bash
simg2img super.img super_raw.img
```

```bash
lpunpack super_raw.img super/
```

Depending on the `lpunpack` version, the partition images may carry an `_a` suffix.

| file | from | used by | for |
|---|---|---|---|
| `boot.img` | AP tarball | `tools/extract_prebuilts.sh` | `device/prebuilts/kernel` |
| `vendor_boot.img` | AP tarball | `tools/extract_prebuilts.sh` | `device/prebuilts/dtb.img`, the 235 `vendor_boot` modules, 6 ramdisk files (`device/prebuilts/vendor_ramdisk/`) |
| `dtbo.img` | AP tarball | `tools/extract_prebuilts.sh` | `device/prebuilts/dtbo.img` |
| `vendor_dlkm.img` | `super.img` | `tools/extract_prebuilts.sh` | the 56 `vendor_dlkm` modules |
| `system_dlkm.img` | `super.img` | `tools/extract_prebuilts.sh` | the 94 `system_dlkm` modules |
| `vendor.img` | `super.img` | `tools/populate_reference.sh`, `device/extract-files.py` | `reference/stock/vendor/…`, `vendor_ls_Z.txt`; 1,089 vendor blobs |
| `odm.img` | `super.img` | `tools/populate_reference.sh`, `device/extract-files.py` | `reference/stock/odm/…`, `odm_ls_Z.txt`; 1 odm blob |
| `system_ext.img` | `super.img` | `device/extract-files.py` | 3 system_ext blobs (audio parameter parser) |
| `system.img` | `super.img` | `tools/populate_reference.sh` | `reference/stock/system/plat_{file,property}_contexts` |

`init_boot`, `vbmeta*`, `product`, `odm_dlkm`, `userdata` and `misc` are not needed. Our build makes its own
`init_boot` and `vbmeta`.

### Which files each job needs

- **Rebuild the vendor policy** (`tools/cil2te.py`): `vendor.img` and `system.img`.
  - From `vendor.img`: `etc/selinux/vendor_sepolicy.cil`, `plat_pub_versioned.cil`, the `vendor_*_contexts`,
    `vndservice_contexts` and `vendor_mac_permissions.xml`.
  - From `system.img`: `plat_file_contexts` and `plat_property_contexts`.
  - Already in git: `reference/baseline/` and `reference/system/`.
- **Rerun checks 1-4** (`tools/run_checks.sh`): the above, plus the following.
  - From `vendor.img`: `etc/init/` and `etc/vintf/`.
  - From `odm.img`: `etc/selinux/`.
  - The `ls -laRZ` listings of the mounted `vendor` and `odm` images.
  - `reference/ours/`: the same files from **your own** build.
- **Build the images:**
  - all of `device/prebuilts/` (from `boot`, `vendor_boot`, `dtbo`, `vendor_dlkm`, `system_dlkm`);
  - `vendor/samsung/essi` (from `vendor`, `odm`, `system_ext`, through `device/proprietary-files.txt`).

## 3. Commands

```bash
UNPACK_BOOTIMG=<aosp>/system/tools/mkbootimg/unpack_bootimg.py tools/extract_prebuilts.sh <dir with the 5 images>
```

Mount the stock images read-only. The SELinux labels are only visible on a mount:

```bash
for p in vendor odm system; do sudo mkdir -p /mnt/stock/$p && sudo mount -o ro,loop super/$p.img /mnt/stock/$p; done
```

```bash
tools/populate_reference.sh /mnt/stock/vendor /mnt/stock/odm /mnt/stock/system
```

```bash
python3 tools/cil2te.py
```

```bash
tools/fetch_deps.sh
```

```bash
tools/run_checks.sh
```

The vendor blobs go into `vendor/samsung/essi`, run from `device/samsung/essi` in the source tree:

```bash
./extract-files.py /mnt/stock
```

```bash
./fix-bp.sh
```

`extract-files.py` takes a directory with one subdirectory per partition. `/mnt/stock` needs `vendor`, `odm` and
`system_ext` mounted.

## 4. Checksums (A566BXXS6AYGE)

Use these to confirm that your firmware and the extraction match what this tree was built and tested with.

Images, after `lz4 -d`, `simg2img` and `lpunpack`:

```
9b3aed93f63b1bba7175979283862437098035f00b1f2252c29dff51879ab64e  boot.img
8d96fcbf26480f88cd07ecafa3366be56e00f0df7cc3b3b7b9a5992210ee8e99  vendor_boot.img
c1264900ed50981cbf7e9d5bf4f34d8d7b0edc4b34a49299e073967c789ef8e2  dtbo.img
d09a9739512d2a3a374ab66f29c9f8418bff997c923a0e957fc3ffdbdb691650  vendor_dlkm.img
76b30f7c8910cac8312c3671c3d9359b6722d03d00d732ea3998ee86c94567c2  system_dlkm.img
```

Extracted files:

```
1853b10fe152f8865c9204a12d904283259c1f2ec9ac8d237e2a34edc8cbaa56  device/prebuilts/kernel
9eda0f387352e46a0dfc7117d96f7374ad4a6b17d3b958d900e86c390827854a  device/prebuilts/dtb.img
9df34f0347b225aa53d37e3680f5a4bbaf238b21b3dce54cd3fcff6863a1ba91  reference/stock/vendor/etc/selinux/vendor_sepolicy.cil
19126008bab14097b43dce496bf92067aa70917480f93f419b3dd374b47aae19  reference/stock/vendor/etc/selinux/plat_pub_versioned.cil
71a215c8b88a3c9a3fa364bf8a5c407c6005c07dedee2df9b137219501915dc3  reference/stock/vendor/etc/selinux/vendor_file_contexts
05aad79136e1563da32cce4b5d00d9cf8e062468adac706c01659d6c4adb5ac4  reference/stock/odm/etc/selinux/precompiled_sepolicy
30a0b3a5317968e0fc82291dfdd75506d6355c478cbab830a1d34a7bd3d09214  reference/stock/system/plat_file_contexts
7422ac7d2a74e06dc96e27674722119d0cab7b25f9f3261fec8603f4a1f98fb3  reference/stock/system/plat_property_contexts
```

With these inputs, `tools/cil2te.py` regenerates `device/sepolicy/vendor/` and `docs/cil2te_report.md`
**byte-identical** to the committed ones. `git status` stays clean.

## 5. Host tools and source trees

| what | for |
|---|---|
| `lz4`, `simg2img`, `lpunpack` (AOSP `system/extras/partition_tools`) | unpacking the AP tarball and `super.img` |
| AOSP `system/tools/mkbootimg/unpack_bootimg.py`, `cpio`, `fsck.erofs` (erofs-utils) | `extract_prebuilts.sh` |
| `python3`, `secilc`, `checkpolicy`, `m4`, `libselinux` (+ `gcc libsepol-dev libselinux1-dev libpcre2-dev`) | `cil2te.py` and the checks (`tools/README.md`) |
| /e/OS v4.3-a15 source (LineageOS 22.2, Android 15, `TARGET_RELEASE=bp1a`) with LineageOS `extract-utils` | `extract-files.py` and the build |
| `patches/`, `projects.txt` | applied to and cloned into the source tree before building (`patches/README.md`) |
