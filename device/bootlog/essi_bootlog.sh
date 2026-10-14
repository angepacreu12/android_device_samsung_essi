#!/vendor/bin/sh
# SPDX-FileCopyrightText: 2026 dxjsk
# SPDX-License-Identifier: Apache-2.0
# essi_bootlog - boot log catcher (debug builds). Copies kernel log, Android log, props and processes to
# /metadata/essi_log every 2 s from `on init` until boot completes (max 10 min), then every 20 s for 20 min. /metadata survives a forced
# reset and is readable from recovery.
# Off by default (01/10): uncapped logs (cur + a full prev copy) filled /metadata and recovery could not write
# /metadata/ota/state. Enabled by /metadata/essi_log/enable or persist.vendor.essi.bootlog=1 (essi_bootlog.rc).
# When disabled it only deletes old logs. When enabled it keeps only tails of the logs and stops as soon as
# essi_log passes MAX_KB or /metadata has less than MIN_FREE_PCT % free, and says so in info.txt and the kernel log.
D=/metadata/essi_log
MAX_KB=4096           # whole essi_log directory, cur + prev
MIN_FREE_PCT=50       # of /metadata
SNAP_KB=1024          # headroom for one snapshot (logcat 512K + dmesg 256K + props/ps + .tmp copies)
klog() { echo "essi_bootlog: $*" > /dev/kmsg 2>/dev/null; }
enabled() { [ -f $D/enable ] || [ "$(getprop persist.vendor.essi.bootlog)" = 1 ]; }
if ! enabled; then rm -rf $D/cur $D/prev; exit 0; fi
# Started twice in one boot (enable file at `on init`, then the prop trigger): keep the running/finished one.
B=$(cat /proc/sys/kernel/random/boot_id)
[ "$(cat $D/cur/boot_id 2>/dev/null)" = "$B" ] && exit 0
# The previous boot is kept truncated: tails only.
rm -rf $D/prev
if [ -d $D/cur ]; then
  mkdir -p $D/prev
  for f in info.txt once.txt usb.txt dmesg.txt logcat.txt; do
    [ -f $D/cur/$f ] && tail -c 65536 $D/cur/$f > $D/prev/$f 2>/dev/null
  done
  rm -rf $D/cur
fi
mkdir -p $D/cur
echo "$B" > $D/cur/boot_id
echo "start $(cat /proc/uptime)" > $D/cur/info.txt
df -k /metadata >> $D/cur/info.txt 2>&1
capped() {  # true (and logged) once the cap is reached; checked before every write burst
  used=$(du -sk $D 2>/dev/null | cut -f1)
  set -- $(df -k /metadata 2>/dev/null | tail -n 1)
  total=$2; avail=$4
  why=
  case "$used" in ''|*[!0-9]*) ;; *) [ $((used + SNAP_KB)) -gt $MAX_KB ] && why="essi_log ${used} KB + ${SNAP_KB} KB > ${MAX_KB} KB";; esac
  case "$total$avail" in ''|*[!0-9]*) ;; *)
    [ "$total" -gt 0 ] && [ $((avail * 100 / total)) -lt $MIN_FREE_PCT ] && why="${why:+$why, }/metadata free ${avail}/${total} KB < ${MIN_FREE_PCT}%";; esac
  [ -z "$why" ] && return 1
  rm -f $D/cur/*.tmp
  echo "cap hit at $(cut -d' ' -f1 /proc/uptime): $why; stopped" >> $D/cur/info.txt
  klog "cap hit: $why; stopped"
  sync
  return 0
}
usbsnap() {  # one line per sample: uptime, every usb property, UDC binding and gadget functions
  { echo "== $(cut -d' ' -f1 /proc/uptime)"; getprop | grep -iE 'usb|adb'
    echo "UDC=$(cat /config/usb_gadget/g1/UDC 2>&1)"; ls /config/usb_gadget/g1/configs/b.1 2>&1 | tr '\n' ' '; echo
    ls /sys/class/udc 2>&1
    echo "android_usb state=$(cat /sys/class/android_usb/android0/state 2>&1) udc state=$(cat /sys/class/udc/*/state 2>&1 | tr '\n' ' ')"
  } >> $D/cur/usb.txt
  [ "$(stat -c %s $D/cur/usb.txt 2>/dev/null || echo 0)" -gt 262144 ] && { tail -c 131072 $D/cur/usb.txt > $D/cur/usb.tmp; mv $D/cur/usb.tmp $D/cur/usb.txt; }
}
once() {  # one shot after boot_completed. Only what a vendor process can read: /system/bin tools (settings, dumpsys,
          # cmd, wm, service) are "inaccessible or not found" from here (docs/BOOT_0927_3_evidence.txt:19); query
          # those over adb once USB works.
  { echo "== $(cut -d' ' -f1 /proc/uptime)"
    echo "== usb: android_usb=$(ls /sys/class/android_usb 2>&1 | tr '\n' ' ')"
    echo "== features shipped"; ls /vendor/etc/permissions /odm/etc/permissions 2>&1
    echo "== vintf fragments"; ls /vendor/etc/vintf/manifest 2>&1
    echo "== insmod cfgs"; cat /vendor/etc/wifi/init.insmod.wifi.cfg /vendor/etc/init.insmod.bluetooth.cfg 2>&1
    echo "== lsmod"; lsmod 2>&1
    echo "== wifi/bt"; ls /sys/class/net 2>&1; ls -la /mnt/vendor/efs/wifi /mnt/vendor/efs/bluetooth /sys/wifi 2>&1; getprop | grep -iE 'wifi|wlan|bluetooth|bt\.|macloader|wlbtd|supplicant'
    echo "== radio"; ls -la /mnt/vendor/efs/factory.prop 2>&1; getprop | grep -iE 'radio|telephony|ril\.|multisim|cbd'
    echo "== efs/csc"; ls -ld /efs 2>&1; ls -l /dev/block/by-name/ 2>&1 | grep -i efs; grep -E ' /efs | /optics ' /proc/mounts
    ls -la /efs /efs/imei 2>&1; ls -laZ /optics/configs/carriers/single/EUX/conf 2>&1; getprop | grep -E 'ro\.(vendor\.)?boot\.[a-z]+\.param\.offset|ro\.boot\.carrierid|csc|omc|matched_code|sec_feature'
  } > $D/cur/once.tmp 2>&1 && mv $D/cur/once.tmp $D/cur/once.txt
}
snap() {
  dmesg 2>&1 | tail -c 262144 > $D/cur/dmesg.tmp && mv $D/cur/dmesg.tmp $D/cur/dmesg.txt
  if [ -x /system/bin/logcat ]; then
    /system/bin/logcat -b all -d 2>&1 | tail -c 524288 > $D/cur/logcat.tmp && mv $D/cur/logcat.tmp $D/cur/logcat.txt
  fi
  getprop > $D/cur/props.tmp 2>&1 && mv $D/cur/props.tmp $D/cur/props.txt
  ps -A -o PID,PPID,STAT,LABEL,NAME > $D/cur/ps.tmp 2>&1 && mv $D/cur/ps.tmp $D/cur/ps.txt
  usbsnap
  sync
}
# phase 1: every 2 s until boot completes (max 10 min)
n=0
while [ $n -lt 300 ]; do
  enabled || { echo "disabled at $(cat /proc/uptime)" >> $D/cur/info.txt; exit 0; }
  capped && exit 0
  snap; echo "loop $n $(cat /proc/uptime)" >> $D/cur/info.txt
  [ "$(getprop sys.boot_completed)" = 1 ] && { echo "boot_completed" >> $D/cur/info.txt; break; }
  sleep 2; n=$((n + 1))
done
# phase 2 (27/09): keep sampling every 20 s for 20 min after boot, so what happens when a setting is
# toggled (USB debugging, Wi-Fi...) is captured too. The last sample wins; usb.txt keeps the whole timeline.
sleep 10; capped && exit 0; once
m=0
while [ $m -lt 60 ]; do
  sleep 20
  enabled || { echo "disabled at $(cat /proc/uptime)" >> $D/cur/info.txt; exit 0; }
  capped && exit 0
  snap; echo "post $m $(cat /proc/uptime)" >> $D/cur/info.txt; m=$((m + 1))
done
echo "done" >> $D/cur/info.txt
