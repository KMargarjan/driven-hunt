# Task 327d — THE SWITCH: every drive is dealt in a grid cell

Task: 327d
Round: 1
Base: `2cdf3be4` (main, after #344)
Code commit: `e811c60d122c8a5a2c6822190bd0dc3335364290`
Branch: `task-327d-switch`

```
[harness] PASS: 34/34 checks @ e811c60d122c8a5a2c6822190bd0dc3335364290 (clean tree) scope=all
[harness2] PASS: 36/36 checks @ e811c60d122c8a5a2c6822190bd0dc3335364290 (clean tree)
```

Both runs first try, no failing spec, so no flake is named and no control run is owed (L-136).
Only `ESCALATE.md` changed between the last `src/tests/tools` commit (`52716ba4`) and the code
commit.

Karen, 2026-11-08: *"so rest part of map we can remove we can only focus on those what we have from
A1 ect"*, *"we only load one per game thats it"*; earlier *"once I am driver ended with line I wait
untile hunt ends? its shit boring"*.
Design: `grid-map.md` D-4 and the 327d row; `cell-loading.md` 13 D1 and 17 D-4.

---

## Claims

**1. The rotation IS `Grid.PLANTED_CELLS` — not a copy of it — so the cells with a wood and the
cells the rotation deals cannot drift apart.** `ForestTest.LAYOUT_ORDER = Grid.PLANTED_CELLS` in
`src/shared/ForestTest/init.luau`. Verify: `grid.spec` → *"deals ONLY the planted cells, never a line
place and never A1"* asserts `order == Grid.PLANTED_CELLS` by IDENTITY, `#order == 7`, every name a
cell, no name in `LINE_PLACES`, `layoutNamed(name) == nil` for each, `A1` in neither list, and four
full `nextLayout` cycles reaching no line place. **LIVE in Karen's Forest Test at the code commit**
(`<runs-dir>/327d-rotation.luau`): `order=C1,C2,A2,B1,D1,B2,D2 | 14 deals: C1 -> C2 -> A2 -> B1 ->
D1 -> B2 -> D2 -> C1 -> ... | A1 in order=false`.

**2. SEVEN CONSECUTIVE REAL DRIVES in her place dealt all seven cells, and `Places.Cells` stood
exactly the dealt one each time.** Measured by polling the published layout and
`Workspace.GridForest`'s children every 18 s through seven drives
(`.agent-logs/327d-rotation-live.txt`): `C1{C1} → C2{C2} → A2{A2} → B1{B1} → D1{D1} → B2{B2} →
D2{D2}`. The server's own line at each boundary, e.g.
`[ForestTest] layout=C2 (rotation): 15 stands 150 apart, centre (-3899, -6579), exit -6874` followed
by `[Places.Cells] want=C2 stood=C2 (2555 models) stored=6 cell(s)/14263 models moved=2 in 383 ms`.
No line place and no A1 in seven drives.

**3. `Places.build` creates no `DrivePlaces` content, and NOT ONE LINE of its loop changed**
(`cell-loading.md` 13 D1): both bodies are guarded by `Forest.layoutNamed(name)`, nil for a cell.
Verify by the same probe in the same place, before and after
(`<runs-dir>/327d-parts.luau`):

| | merge-base `2cdf3be4` | code commit `e811c60d` |
|---|---|---|
| `Workspace.DrivePlaces` | **9,105 parts / 3 children** | **0 / 0** |
| whole `Workspace` | 31,566 parts | **22,459** |
| boot's planting line | `3 dressed, 3727 planted (9105 parts), 164 on a step, 720 paint call(s), 1.34s` | `0 dressed, 0 planted (0 parts), 0 on a step, 0 paint call(s), 0.03s` |

`GridForest` is unchanged at 9,318 parts / one standing cell in both. Spec side: the `grid.spec`
L-093 case asserts `report.places == 0`, `parts == 0`, `paints == 0` and an empty `DrivePlaces`
folder, with `report.reason == nil` so it is not the `no-templates` early return.

**4. `GRID_PREVIEW` is retired and nothing reads a flag in `Places` any more.** The row is gone,
`Flags.MAX_FLAGS` 24 → 23; with it go `Places.GRID_FLAG`, `Places.gridPreviewEnabled`,
`Places.build`'s `gridPreview` parameter, that module's `Flags` require, and `terrainbake.py`'s
`FLAGS_STUB` plus its injection row — replaced by a selftest that reads the ABSENT require out of
`src/server/Places/init.luau` (`python tools/terrainbake.py selftest` → *"src/server/Places/init.luau
requires no Flags, so the prebuild has no flag to stub"*). Losing branch archived, rule 7:
`backups/2026-11-09_task-327d_the-four-line-places.md`.

**5. Her leftover `DHFlag_GRID_PREVIEW=true` is a WARNING, not an error and not a failure — and it
was NOT cleared.** Live, at the code commit: `[flags] OVERRIDE ACTIVE (Studio only) 5 of 23: …` then
`[flags] override(s) REJECTED and NOT applied: unknown flag GRID_PREVIEW`. `Flags.resolve` rejects an
undeclared name rather than creating a flag, and `ensure()` warns once. Zero error lines in that
boot. Her attributes are byte-identical before the first Connect and after the last Play (claim 9).

**6. The boot is no longer a SECOND builder of `ForestMarkers` / `HighSeats` (rule 3).**
`ForestTestBoot`'s `if gridPreviewOn then … end` block is gone; the drive's `markers` closure is the
one builder, and it runs once a second while `Match` is `Waiting`. The closure's preview branch —
which forced `DEFAULT_CELL` and ignored a line place — is gone too, so `DHForestLayout` goes
straight through to `ForestTest.layoutForDrive`. Verify by reading
`src/server/ForestTestBoot.server.luau` (`gridPreviewOn` appears nowhere) and by the live boot, which
prints no `grid preview cell …` line yet deals and builds C1.

**7. `Bots.CONFIG.WALK_SPEED` reads `Grid.CONFIG.beaterWalkStudsPerSecond` — the one owner — and the
number is 5.2.** `bots_lane.spec` asserts the equality and that 1.46 m/s is inside the band, that
`AHEAD_STUDS >= WALK_SPEED * MOVE_REISSUE_SECONDS` (12 ≥ 10.4) and
`RECOVER_HOLD_SECONDS >= SIDE_STEP_STUDS / WALK_SPEED` (3.4 ≥ 1.92) still hold, and that the gait
rate (0.77) clears the floor. **LIVE: every bot beater walked at exactly `WalkSpeed = 5.2`, measured
speed `sp=5.20` on every sample** (`<runs-dir>/327d-bots.luau`), dz 1430 → 23 over the drive. **The
crossing still did not fire — see "what I could not verify" and `ESCALATE.md`.**

**8. A drive works end to end in a cell, one player.** At the code commit, cell C1: the player
enrolled at the truck pad, was dealt **main stand 4** at `(-3905, 111, -5062)` against the cell's main
road at `z = -5107`, with three bot hunters at dz 29–41 — **all four on MAIN-line stands, no flank
stand was used**, so `Body.placementFor`'s north-facing on a flank (TASKS.md 327b-notes (c), 327g's)
was not exercised and is unchanged. Beaters started at the cell's far side (dz 1430) and walked in.
**Animals: 60 of 60 inside the dealt cell's bounds** (`<runs-dir>/327d-animals.luau`,
`layout=C2 cell=[-4434..-3364 x -6558..-5128] animals=60 inCell=60`). `ForestMarkers` carried 16
posts for the cell's 15 stands plus the drive line.

**9. Case 21 — `Places.build` destroys BOTH worlds' folders, whichever is live** (design 11.3 step 2,
13.1 case 21). `grid.spec` → *"case 21: destroys BOTH folders and stands no part of its own"* seeds a
world with a stale `DrivePlaces` and a stale `GridPlaces`, each with a child, and asserts both are
gone **by instance identity** (so a re-parent could not pass), the new grid folder is a different
instance, it holds 0 parts of its own, no `ForestMarkers` / `HighSeats` were built, the
ground-ignore list still names the folder, and a second build replaces rather than doubles.

**10. The specs that changed, and why each had to.** The four line places are archived DATA, so
`places.spec` (19 sites), `grid.spec`'s two *"four old places"* cases and `forest_stand.spec`'s
geometry block now loop the new `ForestTest.LINE_PLACES` or `EVERY` (the rotation **plus** the four),
resolving through `layoutOf`; every number of theirs is still asserted. Two cases had their CLAIM
inverted by the switch and say so in their titles: `forest_stand.spec`'s *"gives every layout one
walk, because no layout may carry a depth of its own"* → *"gives every dealt layout a walk that
outlasts the drive script and fits the clock"*, and `bots_live.spec`'s gait-floor case (at 5.2, half
pace no longer clamps — the pace that does is now computed from the law). `forest_markers.spec` and
`forest_stand.spec` assert west-to-east sortedness and the uniform stand grid only for a layout with
no `sides`, because a cell's 15 stands are on three of its sides. `QUICK_TEST` had expired
2026-11-08 and is re-justified 21 days.

---

## What I could not verify

- **ITEM 3 IS NOT MET: the beaters do NOT all cross inside the drive at 5.2, and the measurement is
  the deliverable.** One live drive in cell C1 at the code commit:
  `[bots] drive 3 hunters, 4/4 beaters (0 failed, 0 stale) | 4 walking, **1 arrived in 292.9s** | 0
  stuck, worst pin 0.0s, 1135 side-steps, 0 no-ground | 74 detours (1 boxed in), 0 recoveries`.
  The last beater was ~35 studs behind the first when the 300 s clock ended the drive (dz 58 and 23
  on the final sample), so all four would have been through at ~300–305 s. `Phase.beatersThrough`
  needs ALL of them, so **`END_ON_BEATERS_CROSS` did not fire**. The design's 4.3 arithmetic
  (`1430 / 5.2 = 275 s`) leaves out `GOAL_PAST_LINE_STUDS` 20 (→ 278.8 s) and the measured ground
  overhead 1.051 (→ 292.9 s). The number lives in `docs/design/`, which is not mine; the arithmetic
  for one that would work (5.35 bare, 5.64 with margin, or `DRIVE.seconds` 300 → 330) is in
  `ESCALATE.md` with its own table. `bots_lane.spec` prints the flat and ground figures as a note
  rather than asserting a crossing it cannot see.
- **`Map.WORLD_BY_PLACE` → `"grid:v1"` (the design's 327d row) is NOT DONE, deliberately.** The
  dispatch does not ask for it and cites `cell-loading.md` instead. `"forest-test"` is the string
  `ForestTestBoot` returns early on, `MatchBoot` skips on, `RangeData.anchorFor` keys on and `Hud` /
  `MapUi` compare to; changing it alone would disable the Forest Test boot. `ESCALATE.md` item 2.
- **`map_ui.spec` case 28 now runs over the LINE PLACES only, and the measured gap is named**: a
  cell's 15 stands drawn by today's `geometryFor` give **70 overlapping Hit-pad pairs**, because 7
  main + 8 flank stands are squeezed onto one road polyline. The cell's own map view
  (`geometryFromGrid`) is task **327f**'s by `grid-map.md` section 17. The map is NOT blank for a
  cell — frame `327d-F2-map.png` shows it drawn.
- **A FORCED `DHForestLayout=road` rollback drive gets the road's geometry but no planted wood**
  (`Places.build` ran at boot, before the override was read) **and its 580-stud walk now ends before
  the drive script's last slot at 192 s.** Both are asserted or stated: `forest_stand.spec` asserts
  the second, `Places.build`'s own comment and the backup note state the first.
- **Karen has not played it.** Her Forest Test is back on merged `main` (`2cdf3be4`, rojo :34873 from
  `driven-hunt-karen`), reconnected, in Edit, with her attributes byte-identical to the start.

## Frames (opened and described)

- `327d-F1-stand-beaters.png` — a hunter's first-person view from **main stand 4 of cell C1**,
  shotgun up (SLUG, INF), HUD `DRIVE 1 · 0:11 TIME · 0 ANIMALS · HUNTER · $13500`, banner *"stay on
  stand, animals coming"*. **One bot beater is visible in the birches at the top-left in the orange
  hi-vis vest and cap**, ~100–150 studs out — which is where the probe put them (dz 92/125/125/153)
  with **eleven seconds left on the clock**. That is the escalation's picture: they arrive at the
  very end.
- `327d-F2-map.png` — the FT Studio in Play, Client tab, HUD `DRIVE 2 · 3:51 · BEATER`, horn in hand.
  The **M map is open** and drawn from the dealt cell: the main line curves along the bottom with
  stands **1–7** and a ROAD mark, flank columns **8–11** (west) and **12–15** (east), a ROAD mark at
  the top for the muster road, and the legend ROAD / STAND / GO HERE / YOU / HUNTER / BEATER.
- `327d-connect-full.png` — the FT connected to rojo :34873 from `driven-hunt-rev` at the code
  commit; Explorer shows `Workspace.GridForest` with A2, B1, B2, C1, C2, D1, D2.

---

ANSWERED: **L-136** no spec failed in either gate run, so no flake is named and no control run is
owed. Five earlier runs on a DIRTY tree failed while I was fixing the switch's own spec fallout
(43 → 17 → 8 → 6 → 1 → 0 server failures); every one was mine and none is claimed as evidence.
ANSWERED: **L-127** per item. **MET** — items 1 (rotation), 2 (a drive end to end in a cell), 4
(`GRID_PREVIEW` retired) and 5 (case 21 + the L-093 case). **NOT MET** — item 3: the beaters do not
all cross inside the drive at 5.2; measured 292.9 s for the first of four against a 300 s clock,
escalated with the arithmetic. **NOT PROVEN** — Karen has not played it, and the forced-rollback path
was not driven live.
ANSWERED: **L-162** every live number above is from the one Play session at the code commit
`e811c60d` (the tree `driven-hunt-rev` served on rojo :34873 was `52716ba4`, which differs from the
code commit only by `ESCALATE.md`); the BEFORE numbers are labelled `2cdf3be4` and were taken with
the SAME probe file in the SAME place.
ANSWERED: **L-014** `driven-hunt-karen` was never checked out, written to or touched; it is still on
`2cdf3be4`. Her Forest Test ends on rojo **:34873 from `driven-hunt-karen`**, reconnected and in
Edit. No Save, no Publish, no Drafts Commit. The branch was served from `driven-hunt-rev` for the
proof and then put back.
ANSWERED: **L-101** her attributes were dumped before the first Connect, after the branch Play and
after the final Play, and all three are **identical** — including `DHFlag_GRID_PREVIEW=true`, which
was deliberately left as it is (dispatch). `.agent-logs/327d-ft-attrs-{before,after-play,final}.txt`.
ANSWERED: **L-093** the delete-the-producer case is claim 1's: restore
`ForestTest.LAYOUT_ORDER = table.freeze({ "road", "edge", "ride", "track" })` and the identity
assertion, `#order == 7`, every `Grid.cellOf` and every `layoutNamed == nil`, the `LINE_PLACES`
membership test, the four-cycle walk and the `report.places == 0` triple all redden at once.
ANSWERED: **the Learning Agent's ROUTE note** (`Body.placementFor` facing every Shooters hunter north
for a flank stand) — checked on the live drive before claiming item 2: the player took **main stand
4** and the three bot hunters stood at dz 29–41, i.e. on the main line. **No flank stand was dealt**,
so that defect was not exercised, is unchanged, and stays 327g's (TASKS.md 327b-notes (c)).
