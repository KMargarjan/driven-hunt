# Task 361: the map's stand pick made nice, and a visible close button

Task: 361
Round: 2
Base: 3533e137 (origin/main)
Code commit: 11faec0714f4a0658ab06760e01aa510572d0c0c

```
[harness] PASS: 34/34 checks @ 11faec0714f4a0658ab06760e01aa510572d0c0c (clean tree) scope=all
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
7. **The pick rules did not change.** `git diff 3533e137..11faec07 -- src/client/Hud/MapUi.luau`
   touches no line of `tapStand`, `pickable`, `standStateFor`, `setPickWindow` or `applyPick`'s
   permission arithmetic. Live: a real click on list row 8 (a tower the player has not bought) was
   REFUSED and the footer said `you need tree-stand access`, exactly as before.
8. **It is inside task 347's instance budget.** `map_ui 347 drawn: ... 1488 instances` against the
   1,500 the budget case allows. The first version read 1,557 (one ring per stand); the two shared
   rings and the badge-as-label are what brought it back, and they are the same picture.
9. **REAL clicks, in Karen's own Forest Test, C1, her flags, at this code commit** -- every frame
   named, opened and described in `## The frames`: a click on stand 5's MARKER picked stand 5; a
   click on list ROW 2 picked stand 2; a click on the X closed the map; a real mouse move onto
   stand 8 ringed it in BOTH widgets while picked stand 5 kept the brighter ring (the hover frame
   L-027 asks for, taken from both directions -- cursor on the row, and cursor on the marker).
10. **The painted tiles (task 359) on her real map, first look:** 9 of 9 `Painted*` `ImageLabel`s
    are drawn with a non-empty `Image`, and in the frames the forest pictures sit under the roads
    and the stand chips with no blank cell. This is the first time task 359's tiles have been seen
    on her map.
11. **ROUND 2: the X never sits on a list row** -- round 1's first note, and it is a real defect of
    this change. Case 34b, at 1366x768 and at 400x800. Note: `map_ui 361 the X and the stand list:
    1366 beside | 400 over, list top 60 px vs button bottom 52`. Delete `layoutFor`'s push and the
    400x800 arm reddens.
12. **ROUND 2: three assertions round 1 called teethless now have them.** Case 35 compares
    `STAND_PICK_PAD_PX > STAND_HOVER_PAD_PX` and pins the pick ring to
    `FULL_STAND_PX + STAND_PICK_PAD_PX` (two rings on two different stands would have gone red the
    day a tower landed on stand 7); case 36 asserts the marker's size against the config rather
    than against itself; and the MINIMAP's own 6 / 9 px square is asserted again, with no `Index`
    label -- so claim 6 rests on a case and not on reading a branch.

## The frames

Every frame below was opened and is described from what is in it. The Forest Test ones are Karen's
own place, section C1, her flags (`DHFlag_STAND_PICK`, `MAP_PAINTED`, `PLACEMENT_IN_PLACE` all
true), one player, the map AUTO-OPENED at the start of drive 1 -- the state she photographed. Her
attribute set was read before and after and the diff is EMPTY; her place was never Saved and ends
on `:34873` from `driven-hunt-karen`, Edit.

**BEFORE (origin/main, `3533e137`, served from `driven-hunt-karen`)**

- `<runs-dir>/361-FT-BEFORE.png` -- the map as it opens. A dark panel over the forest, `MAP /
  section C1`, the painted ground, the road grid, and **nothing anywhere on the panel that says how
  to close it**. The stands are tiny orange squares on the roads with a grey number BESIDE each
  one; at this size the numbers along the bottom road are a smudge. The right-hand column is twelve
  plain rows, `1 MAIN FREE` ... `11 WEST FREE`, all caps, no badge, no separation. Footer, bottom
  right: `click a stand`.
- `<runs-dir>/361-FT-BEFORE-row3.png` -- the same frame after a REAL click on list row 3. Row 3 now
  reads `3 MAIN YOURS` and **looks exactly like every other row**: same ground, same weight, the
  only change is the word. On the map the only mark is the small orange GO-HERE diamond among the
  squares. Footer: `stand 3 is yours`.
- Measured in that session: markers drawn **4.7 x 4.7 px** (tower 7.1), number **10 px beside**
  them, rows **126 x 42**, `Close` **absent**.

**AFTER (this code commit, `11faec07`, served from `driven-hunt-rev`)**

- `<runs-dir>/361-R2-AFTER-open.png` and `<runs-dir>/361-FT-AFTER-mark5.png` -- the same auto-opened
  map after a REAL click on stand 5's marker. **A round dark X button sits in the panel's top-right
  corner**, brass-rimmed, clear of the title. The stands are rounded orange chips with the number
  INSIDE them (1-15), readable at this size. **Stand 5 wears a bright ring**, and in the list **row
  5 is a filled card** -- an orange badge `5`, `Main`, `Yours`. The other rows are cards too: a
  brass number badge, `Main` / `West tower` in sentence case, and a quiet `Free` under it. Footer:
  `stand 5 is yours`.
- `<runs-dir>/361-AFTER-zoom-stands.png` -- stands 9, 10 and 11 at 5x. 9 and 11 are rounded orange
  chips with a dark number; **10 is a tower: a bigger chip with a brass peak on top**, the same
  45-degree shape the lodge's roof is drawn with.
- `<runs-dir>/361-R2-AFTER-hover8.png` -- the cursor parked on **stand 8's MARKER on the map**: that
  marker wears a brass ring AND row 8 (`West tower / Free`) is lightened in the list, while picked
  stand 5 keeps its brighter ring and its filled card. One hover, both widgets.
- `<runs-dir>/361-FT-AFTER-row8.png` -- the other direction: the cursor on **row 8 in the list**,
  and stand 8 on the MAP wears the ring. Footer reads `you need tree-stand access`: the row-8 click
  was REFUSED because it is a tower the player has not bought -- the pick rules, unchanged.
- `<runs-dir>/361-R2-ROWX-row2.png` -- a REAL click on list **row 2**: row 2 becomes the filled card
  with the orange `2` badge and `Yours`, and on the map **stand 2's chip is ringed**. Footer:
  `stand 2 is yours`.
- `<runs-dir>/361-R2-ROWX-close.png` -- immediately after a REAL click on the **X**: the panel is
  gone, the player is back in the forest with deer in the mid-distance and the HUD intact, and the
  objective still counts `pick your stand on map - 8` -- so the X closed a map the pick window had
  opened and **it did not re-open itself**.
- Measured in that session: markers **12.3-13.8 px drawn** (tower 15.4-17.3, with `Peak`), number
  **11 px INSIDE**, rows **144 x 42** drawn, `Close` **44.0 x 44.0**, list right edge 888 of 969.

**THE PAINTED TILES (task 359), first look on her map.** In every AFTER frame the eight drive cells
and the surrounding wood are painted photographs of the forest, not flat tints: dark conifer blocks,
olive-and-rust leafy stands, pale clearings. The white road grid runs over them and **every stand
chip sits on a road** where the stand is. There is no blank cell and no seam; the probe reads
`painted tiles=9, blank image=none` in every session. One cost, stated rather than hidden: the
lodge marker at the canvas's top-right corner is partly covered by the new X. It is a pinned marker
for a lodge 5,270 studs outside the grid, and the top-right corner is where a close control belongs.

**DEV Play, the same code commit** (the dispatch asks for the X click in DEV):

- `<runs-dir>/361-R2-DEV-open.png` -- DEV's own map (`map:v1`, one road, no stands, so no list)
  opened by a REAL `M` keystroke. The X is in the top-right corner and the cursor is free over the
  panel.
- `<runs-dir>/361-R2-DEV-closed.png` -- after a REAL `rawclick.ps1` on that X: the map is gone and
  the shotgun view is back. The probe read `FullMap visible=true` before and `false` after.
- `<runs-dir>/361-R2-DEV-reopened.png` -- `M` pressed again, map open: the X is a second door, not a
  replacement. The CLOSE direction of `M` was read at the previous commit
  (`361-dev-open-BEFORE.png` -> X -> `361-dev-AFTER-xclick.png` -> M open -> M closed) and is
  asserted at this one by case 34.
- **A measured note on the instrument, not on the game:** `<runs-dir>/263key.ps1` sends a THROWAWAY
  press and then the real one (its own comment says why). That is right for an idempotent key and
  wrong for a TOGGLE -- it opened the map and closed it again in one call, which is why `M` first
  looked dead. `<runs-dir>/361key.ps1` presses once. The first key after it takes the foreground is
  still swallowed, so a probe between two presses costs one press; the readings above are the ones
  that landed.

## What I could not verify

- **The `Activated` connection on the button is not asserted by a spec.** `GuiButton.Activated`
  cannot be fired from Lua, so case 34 drives the one function behind it, and the REAL clicks --
  `361-R2-ROWX-close.png` in Karen's Forest Test and `361-R2-DEV-closed.png` in DEV, both at this
  code commit -- are what prove the wire. Delete that one `Connect` line and case 34 still passes;
  those two frames do not.
- **A touch tap.** `TouchEnabled` is false on this PC, so "44 px is enough for a thumb" is an
  Apple HIG / Material number and a measured pixel size, not a tap taken on a phone.
- **1366x768 and 400x800 are the spec's viewports, handed in by parameter** (a spec cannot resize
  a Studio window). The live Forest Test numbers are at its own 969x792 and the DEV ones at its
  own, and both are labelled so. Nobody has opened this map on a real phone.
- **The marker is not a tap target and is not claimed as one.** What a finger hits is the `Hit`
  pad, which this task did not change (26 canvas px, 22.4 real px, measured in the Forest Test),
  and the 44 real px list row -- which is why task 323c built the list at all. The marker got
  bigger so it can be READ, and 16 < 31 canvas px keeps two of them apart.
- **Two specs failed on the first run of this commit and were re-run**: `weapon_shot.spec:1890`
  (expected 4, got 3) and `semiauto_client.spec:93`. Both are named in the dispatch's own KNOWN
  FLAKE list; neither is touched by this change (no weapon file is). The second run of the same
  scope at the same commit is the PASS line at the top. Count: 2 flakes, 1 re-run.
