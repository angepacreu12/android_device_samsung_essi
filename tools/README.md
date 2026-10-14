# tools/

| script | purpose |
|---|---|
| `cil2te.py` | regenerate `device/sepolicy/vendor/` from `reference/stock/vendor/etc/selinux` (policy as `.te`, contexts copied minus the baseline); writes `docs/cil2te_report.md` |
| `cil2te_exclusions.txt` | stock statements the converter must skip, with reasons |
| `check_compile.py` | check 1: replay Soong's vendor policy build (m4, checkpolicy, versioning, filter) and run init's `secilc` line against `reference/system`; the build's `sepolicy_neverallows` (checkpolicy + `sepolicy-analyze`) and `sepolicy.recovery` checks; contexts validation; since 27/09 also the device system_ext policy `device/sepolicy_system_ext/{public,private}` (its new public types are emulated into `system_ext_sepolicy.cil` + mapping, `tools/out/compile/system_ext_extra.cil`) |
| `check_labels.py` | check 2: label of every stock vendor file through libselinux vs `reference/stock/vendor_ls_Z.txt` |
| `check_services.py` | check 3: exec label + `init` domain transition for every stock vendor `service`; a service counts as shipped when a script in `reference/ours/vendor/etc/init/` defines it, whatever the file name (`essi.<name>.rc`) |
| `check_services_exclusions.txt` | check 3: services whose `.rc` is left out on purpose (relock vector), reported n/a with the reason |
| `check_manifest.py` | check 4: every HAL instance declared in stock's VINTF manifests is declared in ours (servicemanager refuses undeclared instances: the `mapper/stableC-impl-sgr` composer abort) |
| `run_checks.sh` | all of the above; writes `docs/RESULTS.md` |

Checks 1-3 also take `device/sepolicy_extra/` (hand-written rules and contexts, the second `BOARD_VENDOR_SEPOLICY_DIRS` entry) into account: its `.te` files are compiled with the generated ones and its contexts files are validated and used for the label lookups.
| `fetch_deps.sh` | clones LineageOS 22.2 `system/sepolicy` and `device/lineage/sepolicy` into `tools/deps/` and builds `checkfc`/`checkseapp`/`sepolicy-analyze` |
| `selabel_util.py` | shared: libselinux lookups, `ls -laRZ` parsing |
| `populate_reference.sh` | fills `reference/stock/` (or `reference/ours/` with `OUT_SUBDIR=ours`) from mounted firmware partitions |
| `extract_prebuilts.sh` | fills `device/prebuilts/` (kernel, dtb, dtbo, the modules named in `modules.list`, 6 vendor_boot ramdisk files) from the stock images |

Inputs: `reference/stock` (Samsung; not in git, see `populate_reference.sh`), `reference/baseline` (frozen no-device-policy build, what the converter
and checks 1-2 treat as "already provided"), `reference/ours` (not in git; latest image, refreshed after each build; used
only by checks 3-4 for "is it in our image"), `reference/system` (our system policy).

Host requirements (Ubuntu 24.04): `secilc checkpolicy m4 python3 libselinux1`, plus `gcc libsepol-dev
libselinux1-dev libpcre2-dev` for `checkfc`/`checkseapp`. Everything is open source.
