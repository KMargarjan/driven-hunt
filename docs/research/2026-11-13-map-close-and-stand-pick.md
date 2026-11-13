# A close button on the map, and a stand pick you can read (task 361)

Karen, 2026-11-13 ~11:50 UTC: *"also stat at the game I want to be able turn off the map x or
something visible"*, and the same minute *"also postions has to be nicer and selcet more nicer"*.

Her frame is `<runs-dir>/360-karen-map.png`: the map opens by itself at the start of a drive, the
only way out of it is the M key, and the stands are 6 px orange squares with 10 px numbers beside a
right-hand column of `1 MAIN FREE` rows.

## What the system must do

1. **A visible way out.** Whenever the full map is up -- the auto-open at the start of a drive and
   every M press -- a close control in the panel's top-right corner, big enough for a thumb, that
   closes the map. M keeps toggling it.
2. **Stands you can find.** A stand on the map is a marker with a number you can read at the panel's
   real size, and a tower says it is a tower.
3. **One stand, two widgets, one state.** Hovering or picking a stand shows on the map marker AND on
   its list row, and the two can never disagree.
4. **Rows that read like cards**, not `1 MAIN FREE`, and 44 real px tall whatever the panel's scale.
5. **The pick rules do not change** (who may pick, free/taken, the default stand).

## Sources

1. **Apple Human Interface Guidelines -- Layout / "hit targets"**
   (https://developer.apple.com/design/human-interface-guidelines/layout) -- Apple, maintained,
   documentation licence. *"Provide ample touch targets for interactive elements. Try to maintain a
   minimum tappable area of 44x44 pt for all controls."* **Good:** one number, measured, and it is
   the number this repo's own `docs/design/mobile-controls.md` already took for the touch rail and
   for `STAND_LIST_ROW_PX` 44. **Bad:** says nothing about where a close control belongs, and points
   are not pixels -- on a phone at this game's panel scale a point is about a pixel, which is why 44
   is taken as a floor and not as a conversion.
2. **Material Design 3 -- Icon buttons / dialog close affordance**
   (https://m3.material.io/components/icon-buttons/guidelines) -- Google, maintained, CC-BY 4.0.
   The close icon sits at the **trailing edge of the top bar**, the icon is 24 dp inside a **48 dp
   touch target**, and the target may be larger than the drawn icon. **Good:** it separates the
   DRAWN size from the TAPPED size, which is exactly the split this panel needs (the panel shrinks
   with `UIScale`; a thumb does not). **Bad:** its 48 dp state layer assumes a ripple this engine
   has no equivalent of, so the pressed state has to be drawn by hand.
3. **Roblox `GuiButton` / `UIScale` reference**
   (https://create.roblox.com/docs/reference/engine/classes/GuiButton,
   https://create.roblox.com/docs/reference/engine/classes/UIScale) -- Roblox, maintained, docs
   licence. `Activated` is the one event that covers a mouse click, a touch tap and a gamepad A, and
   `MouseEnter`/`MouseLeave` are the only hover signal a `GuiObject` gives. **Good:** no new input
   owner -- `Hud.Rail`, `Hud.Touch` and this map's own stand pads already pick `Activated` for that
   reason. **Bad:** `MouseEnter` does not fire on a touch screen at all, which is why hover is an
   affordance here and never a requirement: a tap selects without ever hovering.
4. **A real game's map/spawn picker: PUBG's map stand/vehicle markers and DayZ's map, as the
   inspiration reference the Director named** -- not source code, a look: a numbered marker on the
   ground layer, a hairline ring around the one you have chosen, and the list beside the map
   highlighting the same row. **Borrowed:** the *ring* for "this one is yours" (not a second colour,
   not a second mark) and the *paired highlight* between list and map.

## The pattern adopted, and why

**Material's trailing-edge close button at Apple's 44 px floor, drawn in this panel's own brass**,
and **one reconciled accent writer** for the marker and the row.

- The button is built by `MapUi` (rule 3: it is the one writer of everything inside `FullMap`) and
  sized in REAL pixels through an inverse `UIScale`, which is the trick `STAND_LIST_WIDTH_PX`
  already uses for the same reason (task 327f): the panel shrinks to fit a phone, a thumb does not.
- The glyph is **two rotated `Frame`s**, not a `✕` character: this file already draws its roads and
  the lodge's roof that way, and a font that does not carry the glyph would ship a blank button.
- **`standHover` and `standMine` are single module variables**, and ONE function writes the marker
  and the row from them. The map marker and the list row are never written by their own handlers --
  a handler only states the hover and calls the reconciler. (Learning Agent L-029: two
  edge-triggered writers for one state is how the gun-backpack race was born.)

**Not invented:** nothing here is a new mechanism. The button is `Hud.Rail`'s button shape, the
inverse scale is the stand list's, the ring is the free seat's `UIStroke`, and the row card is
`ReportPanel`'s row (badge, name, pill).

## The numbers

| | value | why |
|---|---|---|
| close button tap size | **44 real px** square | HIG floor; Material's 48 dp rounded down to the number this repo already uses |
| close glyph | 16 px arms, 2 px thick, +-45 deg | reads as an X at 44 px without a font |
| close button place | panel top-right, 8 px in | Material trailing edge of the top bar; clear of the centred title |
| stand marker | **16 px** (ground), **20 px** (tower) canvas px, was 6 / 9 | stands are 31 canvas px apart on the world view, so 20 < 31 keeps two markers apart |
| stand number | 11 px, INSIDE the marker | 10 px under a 6 px square was the unreadable thing in Karen's frame |
| hover ring | marker + 8 px, 2 px `BRASS` | the free seat's own ring weight |
| selected ring | marker + 10 px, 3 px `BRASS_HI` | one step brighter and thicker than hover, so the two are never confused |
| list row | 44 real px, width **150** canvas px | 44 is the HIG floor; 132 could not hold a badge, a name and a pill |
