PASS (item 6, 7 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: nothing in this change has been
seen in Karen's place. What was measured there is the DEFECT, on merged main (`Live.Layout=C1`,
`DrivenHunt.Map.Toggle` absent, `FullMap.Visible=false`). The AFTER is DEV only, and DEV is the
`dev-match` world -- so the picture her Forest Test will now draw, the C1 CELL map (bounds ~1310 x
1890 studs, portrait, fifteen stands on three sides, against `road`'s 1720 x 1130 landscape), has
been seen by nobody; `332-F1.png` is the DEV road map, a different geometry. Item 6's trigger half
was seen only as "a click on MAP closed the panel": nobody has clicked over the OPEN map with a
loaded gun to see that no shell leaves, which is the half that touches shooting.

Verified in the repo, not taken on the request's word: `ForestTestBoot` passes `Grid.PREVIEW_CELL`
to `layoutForDrive` when `gridPreviewOn`; `promote` -> `publishLayout` writes that name to
`Live`'s `LAYOUT_ATTRIBUTE`; `Hud.init`'s `drawMap` reads exactly that attribute into
`geometryFor`; `layoutNamed` is `(ForestTest.LAYOUTS)[name]` and nothing else, so "C1" resolved nil
and `geometryFor` returned nil before `built`/`BindAction` could run. `layoutOf` is the server's
deleted nine lines verbatim, `layoutByName` delegates, `Grid` was already required in
`src/shared/ForestTest` and requires only `Shotgun` back (no cycle), and `roadZ`/`standX`/
`standPosition` all already delegate a `sides` layout to `Grid`, so the client can draw a cell with
no server-only read. Claim 4's arithmetic holds: `beaterNorthStuds` is nil on all four shipped rows,
so `road` stays 1720 x 1130 number for number, and reverting `beaterNorthStuds(layout)` to the
no-argument call makes `map_ui.spec`'s muster line fail (maxZ `centre.Z+805` against the required
`centre.Z+1430`; amplitude 45 + margin 60 = 105, not 730). Harness line names the `Code commit:`,
is "(clean tree)", and `paperwork-after-code-commit.txt` says OK.

## Notes (non-blocking)
- `tests/client/map_ui.spec.luau`, "draws every one of the eight cells" / `expect(#model.stands).to.equal(Grid.standCount(id))` — this line CANNOT FAIL: `geometryFromForestTest` loops `for index = 1, layout.standCount` and inserts unconditionally, and `Grid.layoutFor` sets `standCount = Grid.standCount(id)`, so both sides are one value through two names. It is a note and not a blocking finding only because the case as a whole dies without the producer -- `expect(geometry).to.be.ok()` is the Builder's own `:1232`, and the muster line bites independently. The surviving line is that one. Fix: compare against the design's own fifteen (`Grid.CONFIG.mainStandCount + 2 * Grid.CONFIG.flankStandCount`) or assert all three sides are represented.
- `tests/client/map_ui.spec.luau`, "binds M and opens on a cell" / `expect(#actions).to.equal(1)` — survives the producer's deletion, and the request's own fail-first proves it: with `layoutOf` put back the failure is `:1264`, not `:1258`. `MapUi.setGeometry(nil)` takes the `next_ == nil` branch, leaves `built` true and never unbinds, so the binding an earlier build made is still there to be counted. Claim 9's "M bound ... on `PREVIEW_CELL`" therefore overstates: what the case proves is that the PANEL opens with a cell geometry. Fix: read `MapUi.stats().rebuilds` across the `setGeometry`, or bind from a known-unbound state.
- `tests/client/map_ui.spec.luau`, "hands the mouse over ..." — `expect(Weapon.Input.isHeld()).to.equal(true)` and `expect(#Weapon.Input.holdTags()).to.equal(heldBefore)` both pass on SOMEBODY ELSE's tag: `isHeld` is `next(holds) ~= nil` and a count matches if one tag arrives as another leaves. The comment above it claims the count is "what proves it". Name the tag instead: `table.find(Weapon.Input.holdTags(), "map")` while open, and absent after. `Camera.Cursor` exposes no `freeTags()`, so `isFree()` is all that half can say today.
- `tests/client/camera_client.spec.luau`, the cursor case — the 15 s `waitUntil` lands in the window `tests/client/InputReady.luau` documents as hazardous: *"The suite RUNS WHILE THE REPLAY PLAYS, so every second added here lands somewhere"*, which already cost `camera_client.spec:1488` two reproducible failures for one added second. The wait is conditional and bounded and the assertion keeps its bite (a cursor held for ever still reads `Default`), so this is a note -- but the `TestKit.note` records only a boolean, not how long it waited or who held it. Print the waited seconds so the next red run can tell "settled at once" from "settled after 9 s".
- `docs/design/map-ui.md` section 8.4 — FOR THE ARCHITECT. The change takes the path 8.4 reserves (*"If a later task makes the map clickable, it asks ... with the tag `"map"`"*), so this is an amendment and not a contradiction, but three places now read false: *"the map **does not call** `Cursor.requestFree`, `Cursor.release`, `Input.requestHold` or `Input.releaseHold`"*, the §8 table's rows *"the mouse cursor, when the map opens | **untouched**"* and *"aiming and the trigger, when the map opens | **untouched**"*, and the consequence paragraph *"with the map open a click still fires the gun"*. Not the Builder's file.
- MERGE NOTE FOR KAREN / the Director — with the map open the gun now will not fire AT ALL: `applyModal` takes `WeaponInput.requestHold("map")`, and a held trigger makes `onFire` return Pass without acting. That reverses 8.4's stated decision (*"correct for a half-transparent overlay the player chose to put up"*) and nobody has tried to shoot a crossing boar with the panel up. It is the `map-pick` / `ReportPanel` precedent and the panel draws a full-screen scrim over the view anyway, so it is a feel call, not a defect -- but it is hers to judge, and it is not in `ESCALATE.md`'s queued list.
- `src/server/ForestTest/init.luau` — the block comment *"EVERYTHING THAT HAS TO HAPPEN WHEN THE GROUND MOVES, in one place and in this order (design 6.5 steps 1 and 2)"* belongs to `promote` and now sits two comments above it, over `layoutByName`'s one-line body. Pre-existing, made more visible by the delegation; move it onto `promote`.

---
REVIEWER verdict on commit `979653a1331a55d2496f75778b8e2baf28a6416e` (round 1) · 2026-11-06 13:42 UTC · session cost $3.39, 46 turns · written by tools/agents.py
