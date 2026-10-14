# VaultKeeper / cass removal (relock investigation)

Date: 2026-09-25
Status: **APPLIED** (plan approved by the user; build launched from the pipeline)

## Why

Investigation of the relock-after-sideload bug:

- Vector 1 (fixed 23/09): `ro.frp.pst` set -> AOSP PersistentDataBlockService reformats
  `frp` on checksum mismatch (`formatPartitionLocked(false)`) and clears the OEM-unlock
  byte -> Samsung bootloader relocks. Preflight rule `[safety] ro.frp.pst not set` guards it.
- Vector 2 (this change): the Samsung VaultKeeper stack was shipped in
  `proprietary-files.txt`. `libvkservice.so` reads/writes its vault in the `steady`
  partition (`vk_write_to_steady`), and VaultKeeper is documented to relock the
  bootloader after a /data wipe until a stock OS confirms the unlock. It did not start
  only because the tree has no vendor sepolicy yet; it would run under a permissive boot
  or once `slsi_sepolicy` (which carries `vaultkeeperd.te`) is added.
  Reference trees LineageOS `s5e9925-common` (S22) and erd8825 `s5e8825-common` (A53/A33)
  ship none of it, only `tzts_daemon`. `cass` hard-depends on it
  ("Fatal error : VaultKeeper is not running").

## What changed

Removed from `device/samsung/essi/proprietary-files.txt` (backup `.bak2`), from
`vendor/samsung/essi/essi-vendor.mk` (backup `.bak1`: 3 PRODUCT_COPY_FILES + 7
PRODUCT_PACKAGES) and from `vendor/samsung/essi/Android.bp` (backup `.bak1`: 7 module
blocks). The blob files were MOVED, not deleted, to
`<backup>/removed_vaultkeeper/` (same relative paths):

- vendor/bin/vaultkeeperd
- vendor/bin/vendor.samsung.hardware.security.vaultkeeper-service
- vendor/bin/cass
- vendor/etc/init/vaultkeeper_common.rc
- vendor/etc/init/vendor.samsung.hardware.security.vaultkeeper-service.rc
- vendor/etc/init/cass.rc
- vendor/etc/vintf/manifest/vendor.samsung.hardware.security.vaultkeeper-manifest.xml
- vendor/lib64/libvk_cass_interface.so   (used only by cass)
- vendor/lib64/libvkservice.so           (used only by vaultkeeperd)
- vendor/lib64/vendor.samsung.hardware.security.vaultkeeper-V1-ndk.so (used only by the service)

Kept: `vendor/lib64/libvkmanager_vendor.so` (`libsec-ril` and
`vendor.samsung.hardware.security.rtts-service` link against it).

VINTF: `framework_compatibility_matrix.xml` lists `vendor.samsung.hardware.security.vaultkeeper`
as `optional="true"`, so dropping the manifest fragment passes check_vintf.

Preflight: a `[safety] no VaultKeeper / cass blobs` rule for
`<local>/preflight.py` (FAIL if any of these come back through
proprietary-files.txt, essi-vendor.mk, or the extracted blob dir) was planned but
**NOT added**: the Claude Code auto-mode classifier refused the edit twice. To add by hand:
match `vaultkeeper|libvkservice|libvk_cass_interface|(^|/)cass(\.rc)?$` against the
blob-list tokens, the essi-vendor.mk tokens, and the file names under
vendor/samsung/essi/proprietary, and `res("FAIL", ...)` on any hit.

## To revert

Restore the three `.bak` files and move the files back from the backup folder.

## Still open

- Before the next flash: dump `frp` and `steady` from recovery, keep copies, and check the
  FRP digest (first 32 bytes vs sha256 of byte 33..end) and the last byte (01 = OEM unlock on).
- Decide `ro.frp.pst` from that measurement (community trees keep it set to the stock partition).
- Sepolicy (`slsi_sepolicy` + own `sepolicy/vendor`) comes after this change is validated.
- `~/refs/vbx/` holds a truncated extraction (0-byte vendor_boot.img); discard it.
