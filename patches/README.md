# Source patches (outside the device tree)

Fixes that cannot be made from the device tree, because the code at fault is in a platform project. Each
directory mirrors the project path in the /e/OS (LineageOS 22.2) source tree. Apply from the top of the source
tree:

```
git -C packages/apps/Settings apply "$ESSI/patches/packages/apps/Settings/"*.patch
```

`$ESSI` is this repository. The build (`pipeline/build.sh`) applies each `patches/<project path>/*.patch` the same
way, with `git apply`. The files are `git format-patch` output, which `git apply` accepts; the mail header is
ignored. `git apply --reverse --check` detects a patch that is already applied.

The patches are written against LineageOS `lineage-22.2`. Each patch's `index` line names the blob hash of the file
it expects. If `git -C <project> hash-object <file>` on the /e/OS tree prints the same hash, the file is identical
and the patch applies. If it differs, run `git -C <project> apply --check <patch>` before building
(`docs/VERIFY_0928.md`).

| patch | why | analysis |
|---|---|---|
| `packages/apps/Settings/0001-...FEATURE_TELEPHONY_IMS.patch` | Settings crashes on the SIM page without `android.hardware.telephony.ims` | `docs/CALL_0928.md` section 2; kept, see `docs/IMS_1001.md` §1 |
| `frameworks/av/0001-codec2-keep-ComponentStore-layout-of-prebuilt-vendor.patch` | Samsung's `samsung.hardware.media.c2@V1-service` crashes in `ComponentStore::reportComponentBirth` on its first codec: upstream `07b6b1570b` grew `ComponentStore`, the blob allocates the old size | `docs/CODEC2_1001.md` |
| `frameworks/opt/telephony/0001-Phone-keep-NR-in-the-allowed-network-types-sent-to-t.patch` | the RIL reports a radio capability without NR (130047), so Android cuts every preferred type to LTE/WCDMA (21380) before sending it to the modem | `docs/NETWORK_MODE_1001.md` §8 |
| `packages/apps/PhhIms/0001-...concealment-repeats.patch`, `0002-...rebuffer-downlink-PCM-after-underruns.patch` | downlink audio underruns during IMS calls; upstream fixes `8d91919` and `8903a97` from `xuanyayi/ims-for-wisdom` `lineage-23.2` | `docs/IMS_1001.md` §5 |

Remove a patch when its reason is gone.
- **Settings:** once the IMS block in `device/device.mk` loses its `wildcard` guard, so that no build can ship
  without `android.hardware.telephony.ims`. While the guard exists, a build whose pipeline did not check out
  PhhIms has no IMS feature, and the crash comes back without the patch.
- **frameworks/av:** when the vendor c2 service blob comes from a build that already has `mMultiAccessUnitReflector`
  (Samsung firmware on a base newer than September 2024), or when we ship Samsung's whole codec2 library set instead.
- **PhhIms:** when the pin in `projects.txt` moves to a commit that already contains them (`git apply --reverse
  --check` passes). `packages/apps/PhhIms` is cloned from `projects.txt`, so the build must apply these patches
  after that clone. They are `git format-patch` output of the two upstream commits cherry-picked onto the pinned
  `4562d77` (both apply in order; the result is byte-identical to the upstream file at `8903a97`).
- **frameworks/opt/telephony:** when the RIL reports NR in `GET_RADIO_CAPABILITY` (`mRadioAccessFamily` holds 524288).

**Licenses.** Each patch carries the license of the project it changes: the AOSP/LineageOS projects
(`frameworks/*`, `packages/apps/Settings`) are Apache-2.0, and PhhIms (`xuanyayi/ims-for-wisdom`, from
`krazey/ims` and `phhusson/ims`) is GPL-2.0. The PhhIms upstream commits keep their original author in the
`From:` header.
