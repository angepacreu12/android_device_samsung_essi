# Boot log catcher: off by default, size-capped (01/10)

## What happened
Recovery sideload failed with `kInstallDeviceOpenError` because `/metadata/ota/state` could not be written:
"No space left on device" (user's recovery log, 01/10 17:14). `/metadata/essi_log` (cur + a full prev copy,
every 2 s at boot then every 20 s for 20 min, `device/bootlog/essi_bootlog.sh` before this change) took the space.

## /metadata size
The fstab mounts it from `/dev/block/by-name/metadata` as f2fs or ext4, `first_stage_mount`
(`device/rootdir/etc/fstab.s5e8855:26-27`), but an fstab carries no partition size, and no capture in the
repo shows one. The script now writes `df -k /metadata` at the top of `cur/info.txt` on every run; from adb:

    adb shell df -k /metadata

The caps below are therefore relative (percent free) or small absolute values, so they hold whatever the size.

## Behaviour now (`device/bootlog/essi_bootlog.rc`, `essi_bootlog.sh`)
- Off by default. `on init` still starts the script, which, when not enabled, deletes `essi_log/cur` and
  `essi_log/prev` and exits. So the first boot of this build frees the space the old logs take.
- Enable from the very start of boot (what a boot loop needs): `adb root; adb shell touch /metadata/essi_log/enable`
  (or from a recovery shell). Disable: `adb shell rm /metadata/essi_log/enable`.
- Enable from /data mount on: `adb root; adb shell setprop persist.vendor.essi.bootlog 1` (persistent props load
  after /data is mounted, so early boot is missed). Disable: `setprop persist.vendor.essi.bootlog 0`
  (a running logger stops at its next sample).
- Hard cap whenever it runs, checked before every sample: stop when `essi_log` + 1 MB of headroom for the next
  sample would exceed 4 MB, or when /metadata has less than 50 % free. The stop is written to `cur/info.txt`
  (`cap hit at <uptime>: <reason>; stopped`) and to the kernel log (`essi_bootlog: cap hit: ...`, `dmesg | grep essi_bootlog`).
- Only tails are kept: logcat last 512 KB, dmesg last 256 KB, usb.txt trimmed to 128 KB when it passes 256 KB.
- `prev` keeps only the last 64 KB of info, once, usb, dmesg and logcat of the previous boot.

## Free the space now (before flashing this build)
From recovery or a booted phone with adb root:

    adb shell rm -rf /metadata/essi_log/cur /metadata/essi_log/prev
    adb shell df -k /metadata
