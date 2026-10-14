# Screen edges: the stock product overlay (27/09, night)

Task: `docs/TASK_0927_screen.md`. Changed files: `device/overlay/frameworks/base/core/res/res/values/dimens.xml` and
`.../values/config.xml`.

Sources, as cited below:
- **PRO :N** = `reference/stock/extra/screen/stock_rro_product.txt` (aapt2 dump of Samsung's product overlay
  `framework-res__a56xnaxx__auto_generated_rro_product.apk`).
- **FR :N** = `zcat reference/stock/extra/system/framework-res.resources.txt.gz`.
- **fb/** = LineageOS `android_frameworks_base`, branch `lineage-22.2`.

The latest master commit says it adds product/system_ext overlay and SystemUI dumps under
`reference/stock/extra/`. It only re-compressed existing files (`git show --stat d8d6566`), so none of those
dumps is in the repo. This work uses the product RRO dump only.

## 1. What changed

| resource | old | new | citation |
|---|---|---|---|
| `string/config_mainBuiltInDisplayCutout` | not set (AOSP `""`, fb/`core/res/res/values/config.xml:4116`) | the stock path, byte for byte | PRO :857-858 |
| `bool/config_fillMainBuiltInDisplayCutout` | not set (AOSP `false`, config.xml:4129) | `true` | PRO :776-777 |
| `dimen/rounded_corner_radius` | not set (AOSP `0dp`, dimens.xml:116) | `128px` | PRO :807-808 |
| `dimen/rounded_corner_radius_top` | `36dp` | `42dp` | PRO :813-814 |
| `dimen/rounded_corner_radius_bottom` | `36dp` | `42dp` | PRO :810-811 |
| `dimen/status_bar_height_portrait` | not set (AOSP `24dp`, dimens.xml:52) | `92px` | PRO :822-823 |
| `dimen/status_bar_height_landscape` | not set (AOSP `@dimen/status_bar_height_portrait`, dimens.xml:56) | `24dp` | FR :360364-360365 |

- **Why `status_bar_height_landscape` is set.** The product overlay does not set it, so stock keeps
  framework-res's literal 24dp. In AOSP it points at the portrait value, so without this line our landscape
  status bar would become 92px.
- **Density.** It is 450 on stock (`reference/stock/extra/vendor/build.prop:194`) and on ours
  (`device/BoardConfig.mk:38`), so the px values mean the same physical size.
- **Consistency check.** 92px at 450 dpi is 32.7dp. The cutout circle runs from 8.18dp to 8.18 + 24.53 = 32.7dp.
  Samsung's portrait status bar height is exactly the bottom of the camera hole.

## 2. What the product overlay sets that was not applied

Samsung-only names, which Lineage 22.2 framework-res does not define (absent from fb/`core/res/res/values/symbols.xml`
and `dimens.xml`), so they are skipped:
- `status_bar_camera_side_padding` 30px (PRO :816-817)
- `status_bar_camera_top_margin` 26px (PRO :819-820)
- `status_bar_indicator_corner_padding` 67px (PRO :825-826)

Out of this task's scope. Colors, brightness, power profile and nav bar stay untouched, and so do settings that
are not about the screen edges:
- Brightness: the 13 arrays (PRO :3-771), `config_dynamic_automatic_brightness_available` (:773-774, also not in
  AOSP), the four `config_screenBrightness*Float` dimens (:795-806) and the nine integers (:828-855).
- Nav bar: `config_showNavigationBar` true (:779-780). It is already true in our overlay, from the vendor RRO.
- Other: `config_letterboxHorizontalPositionMultiplier` / `Vertical` 0.5 (:789-794),
  `config_supportAudioSourceUnprocessed` false (:782-783), `config_systemCaptionsServiceCallsEnabled` true
  (:785-786).

Checked and unchanged:
- **`rounded_corner_content_padding`.** Stock framework has 0dp (`reference/stock/extra/screen/stock_fw_0397.txt:2-3`).
  AOSP has the same (dimens.xml:143). The product overlay does not set it.
- **`status_bar_height_default`.** Stock has 24dp (FR :360361-360362). AOSP has the same (dimens.xml:44).
- **The stock vendor overlay** sets no cutout, corner or status bar value. `grep -i 'cutout|corner|status_bar'` on
  its dump returns nothing.

## 3. Cutout: the rect approximation

- The product overlay does not set `config_mainBuiltInDisplayCutoutRectApproximation`.
- Its default is `@string/config_mainBuiltInDisplayCutout` in AOSP (fb/`core/res/res/values/config.xml:4124`) and
  on stock (FR :85765-85766). It follows the path automatically, so Lineage 22.2 needs no separate value.
- The main-display values are read whenever `config_displayUniqueIdArray` is not set
  (fb/`core/java/android/view/DisplayCutout.java:1047-1056`, :1062-1072 for the approximation, :1101-1115 for the
  fill flag). Neither overlay sets that array.

## 4. What reads these values on 22.2

- **Status bar height.** `SystemBarUtils.getStatusBarHeight` is
  `max(cutout safe inset top, status_bar_height_default + waterfall top)`
  (fb/`core/java/com/android/internal/policy/SystemBarUtils.java:46-53`, and :76-80 for other rotations).
  - Adding the cutout is what makes the status bar taller: 24dp becomes about 32.7dp, clear of the camera hole.
    Apps' top insets follow.
  - `status_bar_height_portrait` is not read there. AOSP marks it "Do not read this dimen directly"
    (dimens.xml:49-52). It is set because the RRO sets it and apps that read `android:dimen/status_bar_height`
    directly get it.
- **Cutout fill.** `ScreenDecorations.shouldDrawCutout` reads the fill flag through
  `DisplayCutout.getFillBuiltInDisplayCutout` (fb/`packages/SystemUI/src/com/android/systemui/ScreenDecorations.java:1253-1256`).
  SystemUI then paints the hole area black, as stock does.
- **Corner radii, for apps.** `RoundedCorners` takes top and bottom when they are above 0, otherwise the generic
  radius (fb/`core/java/android/view/RoundedCorners.java:170-178`, fallbacks :197-198, :225-226). So 42dp applies
  to window insets, and 128px only matters where top or bottom is 0.
- **Corner radii, for SystemUI's masks.** The radii only switch the masks on:
  `hasTop` / `hasBottom` = radius > 0 (fb/`packages/SystemUI/src/com/android/systemui/decor/RoundedCornerResDelegate.kt:105-109`).
  - The mask's size is the SystemUI drawable, not the radius: `config_roundedCornerTopDrawableArray`, or
    `R.drawable.rounded_corner_top` as backup (:111-120; `packages/SystemUI/res/values/config.xml:880-882`).
  - On 22.2 that drawable is an 8dp vector (`packages/SystemUI/res/drawable/rounded.xml:14-22`). Our 36dp radii
    already enabled it, and 42dp does not change its size.
- **SystemUI overrides.** We have no SystemUI overlay (`device/overlay/` only has `frameworks/base/core/res`).
  Lineage's common overlays (`vendor/lineage/overlay/common/frameworks/base/core/res/res/values/config.xml`,
  `.../packages/SystemUI/res/values/{config,dimens}.xml` on lineage-22.2) set no cutout, corner or status bar
  value. SystemUI's `rounded_corner_content_padding` points to the framework one
  (`packages/SystemUI/res/values/dimens.xml:659-660`), which is 0 on stock too.

**Open point, not changed here.** On stock, the paddings that keep status bar icons away from the corners and
the camera are the three Samsung-only dimens in section 2, read by Samsung's SystemUI. Lineage's SystemUI does not
read them. Its own knobs (`status_bar_padding_start/end`, `rounded_corner_content_padding`) have no stock value
to copy, so a value there would be invented. If corner clipping remains after this PR, the next input needed is
Samsung's SystemUI resource dump, which the commit message announced but which is not in the repo.

## 5. Next boot

- `adb shell dumpsys display | grep -i cutout` shows a non-empty cutout, a top bound around the centre of the top
  edge.
- `adb shell cmd overlay lookup android android:dimen/rounded_corner_radius_top` returns 42dp. Likewise
  `android:string/config_mainBuiltInDisplayCutout` returns the path above.
- `adb shell dumpsys window | grep -i -E 'statusBar|InsetsSource.*statusBars'` shows a status bar frame of about
  92px (32.7dp) in portrait.
- The status bar clears the camera hole, and the hole area is painted black.
- Content at the top and bottom corners is no longer clipped. If it still is, see the open point in section 4.
