# reference/baseline

The vendor SELinux files our tree built **before any device policy existed** (commit 1f72347,
`reference/ours` as of 26/09 morning): the AOSP `system/sepolicy/vendor` + LineageOS baseline that
every build of this tree contains regardless of `device/sepolicy/vendor`.

`tools/cil2te.py` and the checks read this directory to know what the baseline already declares
(181 types, 206 `file_contexts` entries, ...). It must stay frozen. `reference/ours` is the *latest*
image and is refreshed after every build; it is only used for "is this file / init script / VINTF
fragment in our image" questions (checks 3 and 4).
