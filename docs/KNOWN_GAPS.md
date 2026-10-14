# Known gaps of the generated vendor policy

Companion to `docs/APPROACH.md` (why) and `docs/RESULTS.md` (check output). Numbers are from the
26/09 run of `tools/run_checks.sh` (second run, with `reference/stock/system/`); `docs/cil2te_report.md` has the full lists.

## 1. Rules that name Samsung *system-side* types (4,203 allow/dontaudit/allowx rules dropped)

Samsung's vendor policy was written against Samsung's system policy, which has 584 public types
and 25 attributes that /e/OS does not (Samsung framework services, daemons and their `_prop`/
`_data_file` types). Rules naming them cannot compile on our system and are dropped. Effects:

- Rules for Samsung framework services/daemons (`*_service`, `apexserver`, `auditd`, ...): dead
  on /e/OS, no loss.
- **Property reads by vendor daemons**: Samsung labels some properties in its *system*
  `property_contexts` with Samsung types (`debug_level_prop` for `ro.boot.debug_level`,
  `product_ship_prop` for `ro.product_ship`, `tzdaemon_prop`, `boot_force_upload_prop`, ...). On
  /e/OS these properties get whatever Lineage's `plat_property_contexts` gives them (mostly
  `bootloader_prop` / `default_prop`), and the daemons' read rules were dropped with the type. Expect
  denials such as `tzdaemon ... bootloader_prop:file read`; they are non-fatal (the read returns
  empty) but should be added to `device/sepolicy/vendor/` by hand once seen in `dmesg`. Affected
  boot-critical domains and the dropped types (from `docs/cil2te_report.md`):
  `tzdaemon`/`tztsd`/`tz_proxy_service` (tzdaemon_prop, debug_level_prop, product_ship_prop),
  `hal_keymint_default` (ctl_bugreportm_prop), `hal_gatekeeper_default` (tzdaemon_prop,
  tztsdaemon_prop), `cbd`/`rild` (rild_prop, debug_level_prop, domain_read_prop,
  boot_force_upload_prop, exported_radio_prop, sec_ims_prop, sec_timed_prop, omr_file,
  dumplog_data_file).
- **Device nodes and properties labeled on Samsung's system side**: `reference/stock/system/`
  now holds Samsung's `plat_file_contexts` and `plat_property_contexts`. `cil2te.py` scans that
  directory and recovers every label whose type vendor rules use (the file is generic on purpose:
  drop more Samsung system contexts files there and re-run). Result with the two files available:
  - `plat_file_contexts` differs from Lineage's by only 33 lines; the Samsung-specific ones are
    `/omr`, `/sec_efs`, `/optics`, `/prism`, `/dpolicy_system`. `/omr(/.*)? omr_file` is imported
    (43 rules restored for `rild`, `hal_audio_default`, `bootanim`, ...); the others use types we
    already have. Note that nothing in our tree mounts `/omr` (the stock `fstab.s5e8855` has no
    `omr` line either), so those rules only matter once it is.
  - `plat_property_contexts` is plain AOSP: not one of the 76 Samsung property types the vendor
    rules use (`tzdaemon_prop` 60 rules, `mobicore_prop` 21, `product_ship_prop` 19,
    `debug_level_prop` 16, ...) appears in it, and neither do `pa_daemon_device`,
    `secure_storage_device`, `system_integrity_device` in the file_contexts.
  - Conclusion: Samsung keeps its own labels in the **system_ext** policy (One UI lives in
    `system_ext`). The files still needed from the stock firmware are
    `system_ext/etc/selinux/system_ext_file_contexts`, `system_ext_property_contexts` and, if
    present, `product/etc/selinux/product_file_contexts` / `product_property_contexts`. Once they
    are in `reference/stock/system/`, the converter will label the three `/dev` nodes and every
    property in a vendor-settable namespace (`ro.boot.`, `ro.vendor.`, `vendor.`, ...) with
    Samsung's type and restore the corresponding rules; properties in system namespaces
    (`ro.product_ship`, `ro.csc.*`, ...) will be listed as not recoverable, because vendor
    `property_contexts` may not label them (`check_prop_prefix`).
- **Samsung system domains that live in /vendor**: `pa_daemon` (`pa_daemon_teegris.rc` only
  configures it; the binary is started from the system side) and `secure_storage` are `coredomain`
  types of Samsung's system policy; their rules (16 + 78) are dropped. `VC-daemon`
  (`/vendor/bin/vcd`, `seclabel u:r:vcd:s0`, `disabled`, never started by a vendor `.rc`) has no
  `vcd` type anywhere in the vendor image: it is the one failing row of check 3.

## 2. Contexts that could not be taken over

- `genfscon iso9660 /` and `genfscon udf /`: Samsung labels them `vfat`, Lineage's system_ext
  labels them `iso9660`/`udf`. The platform wins (a conflicting `genfscon` does not compile).
- 154 types and 183 `file_contexts` entries are already provided by the AOSP/Lineage vendor
  baseline and are not re-declared; none of them differ in label from stock (check 2: 0 mismatches).
- Samsung's `vendor_service_contexts` lists four keys twice (`IKeyMintDevice/strongbox`,
  `ISharedSecret/strongbox`, `IDrmFactory/widevine`, `mapper/stableC-impl-sgr`; stock lines 2/30, 3/31, ...),
  which libselinux reports at boot as "Multiple same specifications". The converter now keeps the first
  occurrence only, and also leaves out keys the system side defines with the same context
  (`plat_hwservice_contexts`: `IComponentStore`, `INfc`).
- `vendor_keystore2_key_contexts`: Samsung's file is empty apart from comments; nothing to add.
- `sk/authorize.xml` (Knox) is not a sepolicy build product and is not handled here.

## 3. Compile-time only differences

- **Samsung's 202 `neverallow`s are not converted** (`tools/cil2te.py --neverallows keep` emits
  them). They are assertions about *Samsung's* platform and the first real build failed on 17 of
  them: `hal_attribute_service()` copies whose `-hal_keymint_client` exclusion names an attribute
  our platform expands (`sepolicy-analyze` then sees `keystore`, `system_server`, `rkpdapp`, ...
  finding `hal_sharedsecret_service` as violations), `hal_attribute()` fork rules on the expanded
  `hal_spqckeymaster`/`hal_epic` attributes, `app_domain()` ptrace rules expanded for a user build
  (no `-llkd`), and property rules that the recovery policy breaks because it is built with
  `target_compatible_property=false` (`vendor_init` may then set any non-system property). None of
  them has a runtime effect. The platform's own neverallows (AOSP + Lineage) are still enforced
  against our vendor rules at build time, and check 1 now runs the same three checks the build
  runs: the init `secilc` line, `sepolicy_neverallows` (checkpolicy, then `sepolicy-analyze` on an
  `exclude_build_test` conf) and `sepolicy.recovery`.
- One Samsung *allow* rule (`allow dumpstate proc_type:dir ioctl`) is excluded via
  `tools/cil2te_exclusions.txt` because it violates the platform's `neverallowxperm * *:dir ioctl { 0 }`.
- `version_policy` was re-implemented in Python; its output for `plat_pub_versioned.cil` is
  byte-for-byte identical to the one in `reference/ours` (check 1), so the vendor CIL we test is the
  one the build will produce as long as `system/sepolicy` stays at LineageOS 22.2.
- Not replicated here: the build's `treble_sepolicy_tests` / `sepolicy_tests` (coredomain
  violators, unused types) and `property_info_checker`. The 4,299 lines in
  `platform_and_baseline_domains.te` (Samsung rules whose *source* is a platform domain such as
  `init`, `system_server`, `installd`) are the most likely place for such a test to object; if the
  real build does, drop the offending file rather than editing it.

## 4. Runtime

First boot with the generated policy (26/09): `on post-fs` passes, `tzdaemon` starts, then `vold`
hangs generating the metadata encryption key (KeyMint, `wrappedkey_v0`).

- **Cause found in the device tree, not in the policy**: `/vendor/bin/hw/android.hardware.security.keymint-service`
  is in our image but its init script `android.hardware.security.keymint-service.rc` is not
  (it was never listed in `proprietary-files.txt`; every stock `.rc` that shares its name with an
  AOSP module was left out). The `vendor.keymint-default` service (`class early_hal`) is therefore
  never started, `IKeyMintDevice/default` never appears, and `vold` waits for it forever. The same
  script also creates `/mnt/vendor/efs/DAK` in `on post-fs`. Fixed by shipping the script;
  check 3 now flags any stock service whose binary is in our image without its `.rc`
  (`dumpstate-default.rc`, and `wifi.rc` with `macloader`/`mfgloader`, are the other hits; they are
  not boot-critical but WiFi firmware loading depends on the latter two).
- Policy side of that path, verified from the conversion: `hal_keymint_default` keeps 65 of its 67
  stock rules (the two dropped name `ctl_bugreportm_prop`), including `tz_user_device`,
  `mobicore_user_device`, `keymaster_efs_file`, `prov_efs_file`, `vendor_ssp_device`,
  `vendor_camellia_device`; `hal_gatekeeper_default` 37/39, `tzdaemon` 50/57, `tztsd` 14/17,
  `vold` 222/246. Every `/dev/tz*`, `/dev/tee*`, `/dev/tziw*`, `/dev/socket/tz` entry of the stock
  `file_contexts` is in ours with the same type. The dropped rules on this path are all property
  reads of Samsung system-side types (`tzdaemon_prop`, `debug_level_prop`, `product_ship_prop`,
  `mobicore_prop`, `tztsdaemon_prop`) and `vold`/`tzdaemon` links to Samsung system daemons
  (`secure_storage`, `sdp_cryptod`, `keyrefuge`); expect their denials in `dmesg`, non-fatal.
- Next: `dmesg | grep avc` from the boot log catcher; add missing rules for the priority domains
  to a hand-written file in a second `BOARD_VENDOR_SEPOLICY_DIRS` entry (`cil2te.py` wipes
  `device/sepolicy/vendor/`).
- `precompiled_sepolicy` of the built image only loads if its `.sha256` side files match the
  system image; otherwise init compiles at boot exactly as check 1 does.

### 27/09 boot: the enforced denials, what stock has for each, and what was added

Source: logcat + dmesg of the 27/09 boot of our build (essi_bootlog). The boot itself looped only on
the missing gralloc mapper (VINTF, fixed separately). 13 distinct denials remained. **None of them is a
rule the converter dropped**: for every source/target pair below the stock `vendor_sepolicy.cil`
(`reference/stock/vendor/etc/selinux/`, "CIL" below) has no allow rule either. Where stock works
anyway, it is because Samsung's *system* side labels the object differently (property contexts we do
not have, or a relabel of `/sys/kernel/ems`). Rules added by this PR live in
`device/sepolicy_extra/runtime.te` and `device/sepolicy_extra/service_contexts` (the second
`BOARD_VENDOR_SEPOLICY_DIRS` entry, `device/BoardConfig.mk:208`); checks 1-3 now compile and validate
that directory too. Ranked by boot impact (crash loop > HAL used by the framework > optional daemons).

| # | denials | source -> target (object) | stock CIL for this pair | AOSP neverallow | this PR |
|---|---|---|---|---|---|
| 1 | 15 | `epicd` -> `sysfs_ss_writable:file write` (`req_level`) | none. Node labelled by genfscon `/devices/platform/ems/emstune/req_level` (CIL 900). epicd may write it only as `ems_file` (CIL 5271; that label comes from `vendor_file_contexts:1520` for `/sys/kernel/ems/emstune/req_level`, effective only after a restorecon) or `sysfs` (CIL 5275) | no | `allow epicd sysfs_ss_writable:file { read write getattr open }` (CIL 5271's set) |
| 2 | 15 | `epicd` -> `vendor_epic_prop:file read` (`vendor.epic.log`) | none: only `system_server` read (6691) and `vendor_init` set/read (6854-6855) | no (vendor type) | `get_prop(epicd, vendor_epic_prop)` |
| 3 | 14 | `hal_hyper_default` -> `sysfs_ss_writable:file write` (`req_level`, `low_latency`) | none; ems nodes granted as `ems_file` (19307) and `sysfs_vendor_ems` (19315); genfscon CIL 900, 859 | no | `allow hal_hyper_default sysfs_ss_writable:file rw_file_perms` (19307's set) |
| 4 | 14 | `hal_hyper_default` -> `default_prop:file read` | the only system-side property type stock lets it read is `product_ship_prop` (12659); the property name is not in the log excerpt | **yes**: `default_prop` is `system_internal_prop` (`public/property.te:276`); `private/property.te:169-174` | no rule; alternative below |
| 5 | 14+14 | `emservice` -> `default_prop:property_service set` + `file read` (`ro.em.version`) | `em_version_prop` set/read (11445-11446), a Samsung system-side public type; `ro.em.` is in no contexts file we have | **yes**: `private/property.te:176-179` (set), `169-174` (read). A vendor `property_contexts` may not relabel `ro.em.`: `check_prop_prefix` allowlist `build/soong/selinux_contexts.go:365-381`, strict without `BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE` (`:405-407`) | no rule; alternative below |
| 6 | 29 | `hal_graphics_composer_default` -> `system_prop:file read` (`persist.sys.sf.hs_mode`) | none (its property rules: 5686-5691, 8015-8047); the name falls under `persist.sys.` -> `system_prop` in ours (`plat_property_contexts:103`) and stock (`:102`) | **yes**: `system_prop` is `core_property_type` (`private/property.te:147`), `neverallow { domain -coredomain -appdomain -vendor_init } core_property_type:file` (`private/property.te:287-305`). Check 1 rejected the rule | no rule; alternative below |
| 7 | 15 | `hal_audio_default` -> `radio_prop:file read` (`ril.official_cscver`) | none (readers: rild 8961, sec-ril 16027, at_distributor 10511, diagexe 19029, scs 15894); `ril.` -> `radio_prop` in ours (`plat_property_contexts:39`) and stock (`:40`) | **yes**: `private/property.te:420-427`, only `hal_telephony_server` | no rule; alternative below |
| 8 | 7 | `hal_health_default` -> `boot_status_prop:file read` (`sys.boot_completed`) | none; `cbd` has it (18983) | no: `system_restricted_prop` (`public/property.te:60`), only *set* is restricted (`private/system_server.te:1607`) | `get_prop(hal_health_default, boot_status_prop)` |
| 9 | 6 | `hal_thermal_default` -> `boot_status_prop:file read` | none; stock thermal reads `exported_system_prop` (13632) | no | `get_prop(hal_thermal_default, boot_status_prop)` |
| 10 | 58 | `audioserver` -> `default_android_service:service_manager find` (`android.media.audio.IHalAdapterVendorExtension/default`) | not a rule: a missing `service_contexts` entry. Stock `vendor_service_contexts` does not have it (its audio entries are lines 51 and 95); ours `reference/system/system/selinux/plat_service_contexts` and Lineage 22.2 `private/service_contexts` do not either. Stock's system `plat_service_contexts` is not in the reference | no | `device/sepolicy_extra/service_contexts`: label it `hal_audio_service` (the type stock uses for its audio AIDL services, lines 51 and 95) |
| 11 | 69 | `hal_gnss_default` -> `sec_radio_device:chr_file read` (`/dev/umts_boot0`, `vendor_file_contexts:1260`) | none (its device rules: 4477, 5644, 5648); the older `gpsd` domain has it rw (11761) | no | `allow hal_gnss_default sec_radio_device:chr_file r_file_perms` (read-only; not needed for boot, drop it if GNSS must not touch the modem boot node) |
| 12 | 4 | `gperfd` -> `traced_producer_socket:sock_file write` | none (its rules: 5323-5341); stock has the producer rules for `hal_camera_default` (12024) and `mediacodec` (14822) | no | `perfetto_producer(gperfd)` (`public/te_macros:873`); only tracing depends on it |

**Why `epicd` cannot read `vendor.epic.log` although `vendor_epic_prop` exists.** The type is declared
(`device/sepolicy/vendor/property.te:21`) and the mapping is the stock one (`vendor.epic.` ->
`vendor_epic_prop`, `device/sepolicy/vendor/property_contexts:38` = stock `vendor_property_contexts:94`),
so it is neither a name mismatch nor a different mapping. It is a missing `get_prop`, and it is missing
in stock too: the only stock rules on `vendor_epic_prop` are `system_server` read (CIL 6691),
`vendor_init` set/read (6854-6855) and a neverallow on set (6566). Stock epicd gets the same denial.
Row 2 adds the read anyway (a vendor property, no neverallow).

**What the `epicd` abort is and is not.** "terminating" is the C++ runtime's message for an unhandled
exception. The two denials before each abort are rows 1 and 2; both exist on stock, unless Samsung's
system `init.rc` (not in the reference) relabels `/sys/kernel/ems` so that row 1 becomes the `ems_file`
write stock allows (`vendor_file_contexts:1501-1520` label those nodes `ems_file`, which only takes
effect after a `restorecon`; no stock vendor `.rc` does one, `init.s5e8855.rc:59-68` only `chown`s them).
After this PR the write is allowed, so if epicd still terminates, the cause is the log line before
"terminating", not these two denials. The stock-faithful alternative to row 1 and row 3 is a
`restorecon /sys/kernel/ems/emstune/req_level` (and `low_latency`) in an init script of ours, which
gives the nodes their `ems_file` label and makes the stock rules 5271/19307 apply unchanged; that is a
device-tree change, not a policy one, so it is not in this PR.

**`audioserver` and `IHalAdapterVendorExtension`.** The stock line asked for does not exist in the
files we have: it is not in `reference/stock/vendor/etc/selinux/vendor_service_contexts`, and stock's
system `plat_service_contexts` is not in `reference/stock/system/`. `audioserver` looks the service up
because `ro.audio.ihaladaptervendorextension_enabled` exists in our platform
(`reference/system/system/selinux/plat_property_contexts:511`), and the stock audio HAL
(`/vendor/bin/hw/secaudiohalaidl`, `hal_audio_default_exec`) registers it. Row 10 labels it
`hal_audio_service`; `audioserver` may find that type (`hal_client_domain(audioserver, hal_audio)`).
To confirm against stock, add stock's `/system/etc/selinux/plat_service_contexts` (and
`system_ext_service_contexts`) to `reference/stock/system/`.

**Alternative for rows 4-7 (neverallowed).** These four are properties that Samsung labels on the
system side with *public* types (`em_version_prop_202404`, `product_ship_prop_202404`, ... in the
stock CIL) so that vendor domains may read or set them; our platform labels them `default_prop`,
`system_prop`, `radio_prop`, which vendor domains may not touch. The vendor policy cannot fix this:
vendor `property_contexts` entries must start with `vendor.`, `ro.vendor.`, `persist.vendor.`,
`ro.boot.`, `ro.hardware.`, `odm.`... (`selinux_contexts.go:365-381`). The way that mirrors stock is a
device-tree **system_ext** policy (`SYSTEM_EXT_PUBLIC_SEPOLICY_DIRS` / `SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS`
in `BoardConfig.mk`): declare `system_public_prop(...)` types there and a `system_ext_property_contexts`
with `ro.em.version`, `persist.sys.sf.hs_mode`, `ril.official_cscver` (an exact entry outranks the
`ril.` prefix) and the hyper property once its name is known (the `Access denied finding property`
line in logcat). Vendor rules on such public types are allowed (`private/property.te:169-179`
exclude `system_public_property_type`), and the converter's dropped rules for those Samsung types
(section 1) would come back with the types. No `dontaudit` was added for rows 4-7.

### 27/09 boot #3: enforced denials (evidence `docs/BOOT_0927_3_evidence.txt:117-141`)

Full table with the stock rule for each pair in `docs/BOOT_0927_3.md` section 6. Summary:

| denials | pair | stock | action |
|---|---|---|---|
| 438 | `hal_graphics_composer_default` -> `system_prop` read | none | row 6 above (neverallow); system_ext alternative |
| 25 | `hal_hyper_default` -> `permissioncontroller_app` setsched | no rule for the pair; setsched granted on every other app domain (CIL 12666-12680) | none: `permissioncontroller_app` is a private platform type, vendor policy cannot name it (check 1: "unknown type") |
| 15 | `hal_bluetooth_default` -> set `vendor.bluetooth_fw_ver` (`vendor_default_prop`) | no property_contexts entry on stock either (`vendor_property_contexts:306, 313`) | `device/sepolicy_extra/property_contexts`: `vendor_bluetooth_prop` (set allowed, CIL 11932) |
| 25 | `rild` (13+11+1), `gpsd` (6+1), `cbd` (2), `snap_utility` (2+1+1) -> `system_prop`/`default_prop` read or set (`persist.ril.cp_feature_type`, `persist.cache_status_64`, `persist.cache_integrity_64`) | Samsung system-side types (`rild_prop_202404` CIL 19609, `cache_status_prop_202404` 16379) | none: neverallowed (`private/property.te:169-179, 287-305`), prefixes not allowed in vendor property_contexts; system_ext alternative above |
| 4 | `mediacodec` -> `logdr_socket` write, `misctrl_prop`/`custom_version_prop` read | none | none |
| 14 | `system_app`/`permissioncontroller_app` -> `shell_data_file` search, `platform_app` -> `proc_version` read, `system_app` -> `tracingproxy_service` find | system-side domains | none: platform policy, not vendor |

### 27/09 night: RIL properties, first device system_ext policy (`docs/MODEM_0927.md`)

The system_ext alternative described above now exists in the tree: `device/sepolicy_system_ext/public/property.te`
declares `rild_prop` and `multisim_prop` (stock's names, `reference/stock/vendor/etc/selinux/plat_pub_versioned.cil:5465, 5471`),
`device/sepolicy_system_ext/private/property_contexts` maps `persist.ril.` and `ro.multisim.simslotcount` to them,
and `device/sepolicy_extra/runtime.te` carries the stock vendor rules (`set_prop(rild, rild_prop)` = CIL 19609-19610,
`set_prop(vendor_secril_config_svc, multisim_prop)` = CIL 18375-18376). Check 1 emulates the system_ext build.
Still open on the RIL side: 90 `rild` and 12 `vendor_secril_config_svc` reads of `default_prop`, 36 + 5 reads of
`system_prop`, whose property names are not in the evidence, and `hal_audio_default` -> `radio_prop` (row 7).
Converter gap found on the way: 11 stock allow rules whose source is an attribute set defined only in the stock
`plat_pub_versioned.cil` (`base_typeattr_223` = `{ domain -coredomain }`, 245, 280) are dropped
(`docs/MODEM_0927.md` section 1b); the one the RIL needs is written by hand in `sepolicy_extra`.

**27/09 late night (CSC, `docs/CSC_0927.md`):** the rild `default_prop` / `system_prop` reads above are Samsung
CSC/OMC names (`persist.sys.omc_etcpath`, `mdc.*`, `ro.csc.country_code`, `*matched_code*`, `mdc.sys.sec_feature*`).
Their setters are all Samsung system-side (`/system/bin/scs`, Samsung init's `omc_update`, the CSC/OMC apps), and
no stock value is in the reference, so they stay unlabeled and unset: a label alone would return the same empty
value to rild. Needed from a phone running stock: `getprop | grep -E 'omc|csc|matched_code|sec_feature|mdc\.'`
and `/system_ext/etc/selinux/system_ext_property_contexts`. Added: the `/efs` mount point for stock's `sec_efs`
mount, and the six `ro.boot.*.param.offset` -> `ro.vendor.boot.*` mappings of stock's system `init.rilcommon.rc`.
