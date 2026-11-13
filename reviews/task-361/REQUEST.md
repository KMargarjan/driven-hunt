# Task 361: the map's stand pick made nice, and a visible close button

Task: 361
Round: 1
Base: 3533e137 (origin/main)
Code commit: 7acc2f30fc2be750ab7891d045af3692e06a5885

```
[harness] PASS: 34/34 checks @ 7acc2f30fc2be750ab7891d045af3692e06a5885 (clean tree) scope=all
```

`test2` N/A: no `TWO_PLAYER_PATHS` file is touched (`src/client/Hud/MapUi.luau`,
`tests/client/map_ui.spec.luau`, two docs). A second client would render a second copy of one
player's own map and answer nothing.

Karen, 2026-11-13: *"I want to be able turn off the map x or something visible"* and *"postions has
to be nicer and selcet more nicer"*. Her frame `<runs-dir>/360-karen-map.png` is the map that opens
by itself at the start of a drive, with M as the only way out.

## What changed

`src/client/Hud/MapUi.luau` only (rule 3: it is the one writer of everything inside `FullMap`).

1. **A close button**, built with the picture at the panel's trailing top edge: 44 REAL px at every
   viewport through its own inverse `UIScale` (the trick `StandList` already uses), the X drawn as
   two rotated `Frame`s, and `MapUi.pressClose` as the one implementation its `Activated` calls
   (`Hud.Rail.press`'s shape, because `Activated` cannot be fired from Lua).
2. **The full map's markers**: `FULL_STAND_PX` 16 / `FULL_STAND_TOWER_PX` 20 with the number INSIDE
   at 11 px, a rounded chip, and a brass peak on a tower. The MINIMAP keeps its 6 px square.
3. **Hover and picked**: `standHover` and `standMine` are two module variables and
   `applyStandAccent` is the only thing that writes the map ring and the list row from them. The
   marker pad and the row handler only STATE the hover (L-029). One `HoverRing` and one `PickRing`
   for the whole map, moved onto the marker's own `Position`.
4. **The list rows are cards**: a brass number badge, the stand's name in sentence case
   (`West tower`), and one quiet state word, all from the one pure `MapUi.standRowParts`.
   `STAND_LIST_WIDTH_PX` 132 -> 150.

The pick rules are untouched: `tapStand`, `pickable`, `standStateFor`, `setPickWindow` and the
server's default stand are the same code.

Note: `docs/research/2026-11-13-map-close-and-stand-pick.md` (INDEX updated).

## Claims, and how to verify each

1. **The X exists on the panel, is 44 real px at a desktop AND a phone, and closes the map.**
   `map_ui.spec` case 34. Harness note: `map_ui 361 close button: 44.0 px at 1366x768, 44.0 px at
   400x800 (floor 44)`. It also asserts the button is the panel's own child, anchored top-right,
   above the list rows and every stand pad in `ZIndex`, and that the X is two `Arm%d` frames at
   +-45 degrees.
2. **The wiring is what closes it, and deleting it reddens the case (L-093).** Case 34 drives
   `MapUi.pressClose` -- the one function the `Activated` handler calls -- and asserts
   `stats.closes` rose by exactly one and `isOpen()` went false; a press on a CLOSED map returns
   false and does not count, so the counter is the click and never the state. `closes` is
   incremented nowhere else (`grep -n "closes" src/client/Hud/MapUi.luau`). The `Activated`
   connection itself is proven by the REAL clicks below, which a spec cannot make.
3. **M still toggles it.** Case 34 asserts exactly one bound action after the change and toggles
   both ways; `case: binds M, and only once there is a map to open` and the `keyToggles` case are
   unchanged and still green. Proven live in DEV Play with a real keystroke (below).
4. **Hover and picked come from ONE source and the two widgets agree.** Case 35. It reads the two
   DRAWN widgets, never the variable, and asks WHICH STAND by POSITION (`ring.Position ==
   stand.Position`), which is the strictest form of the claim. It covers: one hover at a time;
   moving the hover moves both and leaves nothing behind; `clearHoverStand` only clears the stand
   it is leaving; picked beats hovered on its own stand (the hover ring stands down, so one stand
   never wears two rings); the picked ring is the brighter, thicker, larger one.
5. **Each marker carries its number inside it and a tower says so.** Case 36: every `Index` label
   is the stand's number, at `STAND_NUMBER_PX`, anchored and positioned at the marker's centre, no
   wider than the marker, in `STAND_NUMBER_COLOR`; a `Peak` exists on exactly the stands
   `Grid.towerStands` names and on no other. Note: `map_ui 361 markers: 15 stands at 16 px with the
   number inside, 3 towers with a peak`.
6. **The minimap is untouched.** `STAND_PX` / `STAND_TOWER_PX` are still 6 / 9 and
   `drawGeometry`'s `standLabels` branch is what picks between the two pairs; the minimap draws no
   number, no ring and no pad (`if not standLabels then continue end`, unchanged).
7. **The pick rules did not change.** `git diff 3533e137..7acc2f30 -- src/client/Hud/MapUi.luau`
   touches no line of `tapStand`, `pickable`, `standStateFor`, `setPickWindow` or `applyPick`'s
   permission arithmetic. Live: a real click on list row 8 (a tower the player has not bought) was
   REFUSED and the footer said `you need tree-stand access`, exactly as before.
8. **It is inside task 347's instance budget.** `map_ui 347 drawn: ... 1488 instances` against the
   1,500 the budget case allows. The first version read 1,557 (one ring per stand); the two shared
   rings and the badge-as-label are what brought it back, and they are the same picture.
9. **REAL clicks, in Karen's own Forest Test, C1, her flags** (`<runs-dir>/361-FT-*.png`, all
   opened and described in `## The frames`): a click on stand 5's marker picked stand 5; a click on
   list row 2 picked stand 2; a click on the X closed the map. A mouse parked on row 8 ringed stand
   8 ON THE MAP while picked stand 5 kept the brighter ring -- the hover frame L-027 asks for.
10. **The painted tiles (task 359) on her real map, first look:** 9 of 9 tiles draw, none with a
    blank `Image`, and the stand icons and roads sit on them. Measured and in the frames.

## What I could not verify

- **The `Activated` connection on the button is not asserted by a spec.** `GuiButton.Activated`
  cannot be fired from Lua, so case 34 drives the one function behind it and the REAL click in DEV
  Play and in the Forest Test is what proves the wire. Both are in the report with frames.
- **A touch tap.** `TouchEnabled` is false on this PC, so "44 px is enough for a thumb" is an
  Apple HIG / Material number and a measured pixel size, not a tap taken on a phone.
- **1366x768 and 400x800 are the spec's viewports, handed in by parameter** (a spec cannot resize
  a Studio window). The live Forest Test numbers are at its own 969x792 and are labelled so.
