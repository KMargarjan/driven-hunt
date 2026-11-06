# Task 332 -- "and M doesnt work at all"

Task: 332
Round: 1
Base: main 40d6a063
Code commit: e990509f3da3a5ce4d0ac1c061e50fa7260bfc83

`[harness] PASS: 34/34 checks @ e990509f3da3a5ce4d0ac1c061e50fa7260bfc83 (clean tree) scope=all`

`test2`: N/A -- no `TWO_PLAYER_PATHS` path is touched (client Hud, shared/server ForestTest, two
client specs). No failing spec and no flake fired in that run.

## What changed

The client could not resolve the layout name the server publishes in Karen's world, so the map never
built -- and the build is what binds M. `ForestTest.layoutOf` is the one resolver now. Separately,
the open map now holds the mouse, because the camera's `LockCenter` made its own MAP button
unpressable.

## Claims

1. **The cause, measured on her path.** In Karen's Forest Test on merged `main`, Play started from
   Edit, `DHFlag_GRID_PREVIEW` on: `Live.Layout = C1`, and a client probe read
   `name=C1 layoutNamed=false geometryFor=false` beside `name=road layoutNamed=true geometryFor=true
   stands=9`. Verify: `src/server/ForestTestBoot.server.luau` passes `Grid.PREVIEW_CELL` as the
   layout override when the flag is on; `ForestTest.layoutNamed` indexes `LAYOUTS` only;
   `MapUi.geometryFor` returns nil for a nil layout.
2. **All four of the dispatch's cases failed, with real input.** Lobby and drive, a real M press
   (`298key.ps1` -- ONE `InputBegan`, not `263key.ps1`'s two, L-159) and a real MAP-button click:
   `DrivenHunt.Map.Toggle` absent from `ContextActionService:GetAllBoundActionInfo()` (the Report and
   Weapon actions were present), `FullMap.Visible=false AbsoluteSize=1100x700`,
   `MiniMap.Visible=false`, `MapLegend` with 0 children. The keys reached the client
   (`keys=LMB M LMB M LMB n=2`). Verify: the numbers are in `TASKS.md` row 332 and `ESCALATE.md`.
3. **The fix is one resolver, not a second copy.** `ForestTest.layoutOf` answers the four rows and
   the grid's eight cells; `src/server/ForestTest/init.luau`'s `layoutByName` delegates to it (its
   nine lines are gone); `MapUi.geometryFor` calls it. Verify: grep `layoutOf` and `layoutNamed`.
4. **The map's north bound asks the LAYOUT.** `geometryFromForestTest` calls
   `data.beaterNorthStuds(layout)`; a cell musters at 1,430 studs and the no-argument call answered
   the road layout's 580. The four shipped rows state no `beaterNorthStuds`, so they are unchanged
   number for number (`forest_stand.spec` still passes, and the map notes still read
   `bounds 1720 x 1130` for `road`).
5. **The second defect, measured in DEV.** With the map open: `MouseBehavior=LockCenter`,
   `mouse=484,334` in a 969x784 view, the MAP button's centre at 933,264 -- two real clicks on it
   changed nothing. Verify: `docs/design/map-ui.md` section 8.4 reserves the tag `"map"` for exactly
   this case.
6. **The open panel is a modal, off the panel's own answer.** `applyModal(full.Visible)` is called
   from `applyVisibility`, which already runs on all six exits, and takes `Cursor.requestFree("map")`
   plus `WeaponInput.requestHold("map")` -- the trigger because `Weapon.Input` binds `MouseButton1`.
   `MapUi.isModalHeld()` reads what was written.
7. **Proven live in DEV with real input, at the code commit.** A real M press: `FullMap.Visible`
   false -> true, `MouseBehavior` LockCenter -> Default, minimap off. A real click on the MAP button:
   `LMB(gp)` (the GUI took it), `FullMap.Visible` -> false, `MouseBehavior` -> LockCenter, minimap
   back. Frame `<runs-dir>/332-F1.png`: the map panel over the drive -- the "MAP / map:v1" title, N
   at the top, the white road polyline with the player's gold marker and facing wedge on it, the
   "200 m" scale bar, and the legend's six rows (ROAD, STAND, GO HERE, YOU, HUNTER, BEATER). No
   stands, which is DEV's own geometry (`map_ui.spec` asserts `#stands == 0` there). DEV ONLY.
8. **FAIL FIRST, run not argued.** With `layoutOf` put back to `layoutNamed` and the `applyModal`
   call deleted, the same suite reads `failed [client] map_ui.spec:1232 Expected value "nil" to be
   non-nil`, `:1264 Expected "true", got "false"`, `:1280 Expected "true", got "false"` -- the cell
   geometry, the panel opening, and the modal hold. Tree restored; the PASS above is at the clean
   tree.
9. **New cases.** `map_ui.spec` "a grid cell is a layout the map can draw (task 332)": all eight
   cells draw, every stand inside the bounds, the north bound reaches the cell's own muster; M bound
   and the panel opens and closes on `PREVIEW_CELL`; the mouse and the trigger are taken and handed
   back (reference counted, asserted against `Weapon.Input.holdTags()`).
10. **One premise fixed, not weakened.** `camera_client.spec`'s "locked by default" case now waits
    up to 15 s for the cursor to be handed back, because the harness's own `map-toggle` scenario can
    have it legitimately held. A cursor held for ever still fails it. It read
    `cursor handed back before this case=true` in the green run.

## What I could not verify

- **The AFTER in Karen's own Forest Test.** Her place syncs from `driven-hunt-karen`, the Director's
  copy, and I may not check code out there (L-014). The BEFORE above is from her place; the AFTER is
  DEV. `ESCALATE.md` 2026-11-06 ~13:30 carries the exact steps for the Director after the merge.
- **Opening the map with the MAP button on a PC.** The camera holds the mouse, so no `Hud.Rail`
  button is clickable while nothing has freed the cursor. The open map frees it, so the button
  CLOSES the map; opening it from a locked mouse is the cursor owner's question (rule 3), queued in
  `TASKS.md` and in `ESCALATE.md`, not fixed here.
