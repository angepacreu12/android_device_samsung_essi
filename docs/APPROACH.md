# Vendor SELinux policy for essi: approach

Status: written before the implementation, updated with the results of the first experiments.
Note (27/09): the no-device-policy build the converter compares against now lives in `reference/baseline/`
(frozen copy of the original `reference/ours`); `reference/ours/` is refreshed after each build and only tells
the checks what the current image contains.

Companion documents: `docs/RESULTS.md` (check results), `docs/KNOWN_GAPS.md`, `docs/cil2te_report.md`
(what the converter dropped and why), `TASK.md` (the brief).

## 1. The problem in one paragraph

Our `vendor.img` is built from Samsung blobs by the LineageOS 22.2 / Android 15 build, but the
tree has no `BOARD_VENDOR_SEPOLICY_DIRS`. The resulting vendor policy is the AOSP + Lineage
baseline only (181 vendor types, 1,486 CIL lines, 206 `file_contexts` lines) while Samsung's stock
vendor policy has 1,270 types, 20,227 CIL lines and 1,610 `file_contexts` lines. Every Samsung
daemon is therefore labeled `vendor_file` and cannot be started by init. The first casualty is
`tzdaemon` (`tz_service`, TEEGRIS) and `teegris.rc` waits for it forever in `on post-fs`.

## 2. What the phone does with the vendor policy

On a Treble device init does not load `precompiled_sepolicy` unless its `.sha256` side files match
the system's. Otherwise it runs, in this order:

```
secilc -m -M true -G -N -c 30 -f /sys/fs/selinux/null -o <out>
    /system/etc/selinux/plat_sepolicy.cil
    /system/etc/selinux/mapping/<vers>.cil          (vers = /vendor/etc/selinux/plat_sepolicy_vers.txt = 202404)
    /system_ext/etc/selinux/system_ext_sepolicy.cil + mapping/<vers>.cil
    /product/etc/selinux/product_sepolicy.cil       + mapping/<vers>.cil
    /vendor/etc/selinux/vendor_sepolicy.cil
    /vendor/etc/selinux/plat_pub_versioned.cil
    [/odm/etc/selinux/odm_sepolicy.cil]
```

So a vendor policy is "correct" for our system if that command compiles, and the labels it needs
are produced by `vendor_file_contexts` (files), `vendor_property_contexts`, `vendor_service_contexts`,
`vendor_hwservice_contexts`, `vndservice_contexts`, `vendor_seapp_contexts`,
`vendor_keystore2_key_contexts` and `vendor_mac_permissions.xml`.

## 3. What is in the stock policy

`reference/stock/vendor/etc/selinux/vendor_sepolicy.cil` (20,227 lines) uses only these
statements, all of which have a 1:1 equivalent in the kernel policy language (`.te`):

| CIL statement | count | `.te` equivalent |
|---|---|---|
| `allow` / `dontaudit` | 14,695 / 292 | `allow` / `dontaudit` |
| `type` + `roletype object_r` | 1,270 | `type X;` (object_r is implicit) |
| `typeattribute` / `typeattributeset` | 313 / 510 | `attribute A;` / `typeattribute X A;` |
| `genfscon` | 1,178 | `genfs_contexts` file |
| `typetransition` | 293 | `type_transition` |
| `neverallow` / `neverallowx` | 200 / 2 | `neverallow` / `neverallowxperm` |
| `allowx` | 187 | `allowxperm` |
| `typealias` + `typealiasactual` | 5 | `typealias` |
| `expandtypeattribute` | 6 | `expandattribute` |

Public platform types appear versioned (`init_202404`, `vendor_file_202404`); set expressions
from `.te` (`{ domain -init }`) appear as auto-generated attributes `base_typeattr_N_202404`
defined by a `typeattributeset ... (and (...) (not (...)))` line. Both are mechanically reversible.

Samsung's vendor policy is compiled against **Samsung's** system policy. Samsung's public
platform policy declares 618 types that /e/OS does not have (219 `*_service`, 104 `*_exec`,
130 domains, 98 `*_prop`, 28 file types, 3 devices, 2 hwservices). 584 of them are referenced by
the stock vendor CIL. Only four of those are used by the stock vendor *contexts* files
(`hal_tee_service`, `hal_tee_hwservice`, `hal_teeregistry_hwservice`, and `mif_device` which is an
alias of the vendor type `ssipc_device`).

## 4. Experiments (26/09, host `secilc` 3.5, our `reference/system` policy)

| # | Inputs | Result |
|---|---|---|
| A | our plat/system_ext/product + mapping, **stock** `plat_pub_versioned.cil`, **stock** `vendor_sepolicy.cil` | all types resolve; fails only on 2 `genfscon` conflicts: stock labels `iso9660 /` and `udf /` as `vfat`, Lineage's system_ext labels them `iso9660` / `udf` |
| B | same, but **our** `plat_pub_versioned.cil` | fails at the first rule that names a Samsung-only public type (`pa_daemon_device_202404`, ...): 584 such types are undeclared |
| C | our system + our current (baseline) vendor CIL | compiles (sanity check of the command line) |

Reading of A: the stock policy is *almost* loadable on our system, but only because Samsung's
`plat_pub_versioned.cil` declares the 618 Samsung-only public types as empty attributes and also
carries Samsung's public *rules* (356 allow, 427 neverallow) which we would then grant to our
platform domains. Reading of B: whatever we ship must either declare or drop the rules that name
those 584 types.

## 5. The two approaches

### Approach 2: ship Samsung's compiled files (prebuilt CIL + contexts)

What it needs from the Android 15 build:

- `vendor_sepolicy.cil` is a Soong `se_versioned_policy` module in `system/sepolicy/Android.bp`
  built from `vendor_sepolicy.conf` (m4 over `.te`), `checkpolicy -C`, `version_policy` and a
  `filter_out` of `plat_pub_versioned.cil`. There is **no board variable for a prebuilt vendor CIL**:
  the only inputs are directories of `.te`/contexts files (`BOARD_VENDOR_SEPOLICY_DIRS`,
  `BOARD_ODM_SEPOLICY_DIRS`). A prebuilt would need a patch to `system/sepolicy` (a fork of the
  platform repo, not device-tree work) or a post-build file swap in `out/` (breaks `checkfc`,
  `sepolicy_neverallows`, `precompiled_sepolicy` and the sha256 side files; not reproducible).
- `plat_pub_versioned.cil` is regenerated from *our* public policy at build time, so the Samsung
  copy that made experiment A pass cannot be shipped: we would be back to experiment B and would
  still need a compat CIL for the 584 types, which again has no build hook (odm policy is `.te` too).
- The contexts files are the easy half: every `*_contexts` file is a plain text concatenation of
  the source files in the sepolicy dirs (m4 `-s`, comments stripped, `fc_sort`, `checkfc`
  validation). Samsung's compiled files are m4-safe (verified) and use only the allowed vendor
  property namespaces (`vendor.`, `persist.vendor.`, `ro.vendor.`, `odm.`; verified against
  `check_prop_prefix`). They can be dropped into our sepolicy dir *as-is*.

Verdict: the contexts half of approach 2 is clean and is what we do. The policy half is not
possible without patching the platform build.

### Approach 1: `.te` sources derived from Samsung's CIL

- Fits the build as designed: `BOARD_VENDOR_SEPOLICY_DIRS += device/samsung/essi/sepolicy/vendor`,
  and the platform runs its normal checks (`checkpolicy`, neverallows, `checkfc`, `checkseapp`,
  property namespace checks, `precompiled_sepolicy` + hashes).
- The conversion is mechanical and scriptable (`tools/cil2te.py`): strip the `_202404` suffix,
  turn `base_typeattr_N` back into `{ ... }` set expressions, `type`/`typeattribute` into
  declarations, `genfscon` into `genfs_contexts`. Output is regenerated, never hand-edited, so it
  can be re-run on a new stock firmware.
- The 584 Samsung-only platform types are handled explicitly: the six that matter for contexts are
  declared in `samsung_platform_compat.te` with the attributes Samsung gave them; rules that name
  any other one are dropped and counted (they concern Samsung framework services/daemons that do
  not exist on /e/OS, so the rules are dead on our system either way). The list is reported so it
  can be revisited from runtime denials.
- Types and rules already provided by the baseline (`system/sepolicy/vendor` + Lineage's
  `device/lineage/sepolicy/common/{dynamic,vendor}`: 181 types, of which 154 are also in
  the stock policy) are not re-declared; conflicting `type_transition`s and `genfscon`s are
  dropped and reported.
- Verification is possible here without an Android tree: LineageOS 22.2 `system/sepolicy`
  and `device/lineage/sepolicy` were cloned and declare exactly the same 1,397 public types as the
  phone's system image (`reference/ours/.../plat_pub_versioned.cil`). `tools/check_compile.py`
  replays the build's pipeline (m4 -> `checkpolicy -C` -> versioning -> `filter_out`) and then the
  init command line above against `reference/system`. Round-trip fidelity is measured by diffing
  the emulated `plat_pub_versioned.cil` against the one our real build produced.

Cost: Samsung's neverallows were validated against Samsung's platform, not ours; the first real
build failed on 17 of them, so they are not converted at all (they are compile-time assertions,
not runtime policy; the platform's own neverallows still apply to our rules).
Samsung's *system-side* labels that vendor daemons touch (`/dev` nodes, `ro.boot.*` properties)
are not in the vendor image; `cil2te.py` recovers them from whatever Samsung system contexts files
are placed in `reference/stock/system/` (see `docs/KNOWN_GAPS.md` for which files still matter).

## 6. Recommendation

**Approach 1 for the policy, approach 2 for the contexts**, both generated by scripts in `tools/`:

1. `tools/cil2te.py` converts `reference/stock/vendor/etc/selinux/vendor_sepolicy.cil` into
   `device/sepolicy/vendor/*.te` (one file per domain/type group) + `genfs_contexts`, and copies
   the stock contexts files into the same directory (minus entries the baseline already provides).
2. `device/BoardConfig.mk` gets `BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor`.
3. `tools/check_compile.py`, `tools/check_labels.py`, `tools/check_services.py` implement the
   three acceptance checks of `TASK.md`; `tools/run_checks.sh` runs them all and writes
   `docs/RESULTS.md`.

Priority order from `TASK.md` (TEEGRIS, KeyMint/Gatekeeper, early-init..post-fs-data services,
modem, the rest) is used for reporting: the checks list results by that class first, and the
domain list in `docs/RESULTS.md` is ordered the same way. The conversion itself is total (all
domains at once) because the cost of converting one domain versus all is the same for a script,
and partial policies fail neverallow/`checkfc` checks in confusing ways.

## 7. Tooling used (all open source)

- `secilc`, `checkpolicy`, `setools` (Ubuntu 24.04 packages, SELinux userspace 3.5); Android's
  copy is the same code base with small build-tool patches.
- `checkfc` and `checkseapp` built from LineageOS 22.2 `system/sepolicy/tools` against libsepol.
- `version_policy` is Android-only (`cil/android.h`); its behaviour is re-implemented in Python
  and validated against the real build output in `reference/ours`.
- `libselinux` (`selabel_open`/`selabel_lookup`, via Python ctypes) for `matchpathcon`-style
  label lookups in check 2, so precedence rules are the library's, not ours. Ubuntu's libselinux
  is built without the Android property/service backends, so `checkfc -p/-s/-l/-v` cannot run
  here; check 1 validates those contexts files in Python (every type exists, no key has two
  contexts), and uses `checkfc` for `file_contexts` and `checkseapp` for `seapp_contexts`.

Outcome of the recommendation (26/09, `tools/run_checks.sh`): check 1 passes (init command line,
the build's `sepolicy_neverallows` and `sepolicy.recovery` checks, all contexts files), check 2 passes (0 label mismatches on 2,104 stock vendor
entries, down from 704), check 3 passes for 101 of 102 stock services; the one failure and the
dropped-rule classes are documented in `docs/KNOWN_GAPS.md`.
