# Task 179 — varied drives: more than one place to stand

Task: 179
Round: 1
Base: 253d21f (main, #162 merged)
Code commit: 598e1192e61073da6d69cb6128f258b83031517c

```
[harness] PASS: 33/33 checks @ 598e1192e61073da6d69cb6128f258b83031517c (clean tree) scope=all
[harness] PASS: 33/33 checks @ 598e1192e61073da6d69cb6128f258b83031517c (clean tree) scope=all
```

```
[harness2] PLACEHOLDER -- NEEDS TEST2 179 598e119 (ESCALATE.md). `src/server/Match/init.luau` is in
TWO_PLAYER_PATHS; `run-test2.sh` refuses while two Studios are open (DEV + Karen's Forest Test),
and StudioMCP cannot start a two-player test itself.
```

## What changed

**KAREN, 2026-10-13 ~13:55, verbatim:** *"we will improve terrain that not all a time same place
hunters standing and not the same terrain for beaters / we will make view for hunter from different
places and diffretent tree lines road ect like in real life"*.

A drive **layout** is now data in the one world-geometry seam. Three ship — the **road** (today,
unchanged), the south **forest edge** and a straight **ride** — one is dealt per drive from a
shuffled bag, and `DHForestLayout` forces one for a test. Design `docs/design/drive-layouts.md`
(Architect PASS), note `docs/research/2026-10-14-drive-layouts.md`, brief `reviews/task-179/BRIEF.md`.

Files: `src/shared/ForestTest/init.luau`, `src/shared/ForestTest/Live.model.json` (new),
`src/server/ForestTest/init.luau`, `src/server/ForestTest/Markers.luau`,
`src/server/ForestTestBoot.server.luau`, `src/server/Match/init.luau`, `src/server/Boar/init.luau`,
`src/client/Hud/init.luau`, `src/client/Hud/MapUi.luau`, `GAME_DESIGN.md`, and the five specs
`forest_stand`, `forest_markers`, `forest_line`, `bots_lane`, `lobby`, `map_ui`.

## Claims

1. **Three layouts ship, and every number in them was MEASURED in the Forest Test before it was
   written** — not chosen, not tidied. `ForestTest.LAYOUTS` in `src/shared/ForestTest/init.luau`;
   the measurements are `docs/research/2026-10-14-drive-layouts.md` section 5.
   *Verify:* the note's tables against the three records. The stand lines are x 2430..3630 (road),
   3105..3855 (edge), 3090..3610 (ride), which is what `standX` produces from each record.

2. **The dispatch's fourth layout — a clearing with a high seat — is NOT shipped, and the reason is
   a measurement rather than an opinion.** Of 1,054 points sampled inside the wood every 50 studs,
   **nine** have nothing colliding within 45 studs and no two are adjacent.
   *Verify:* note section 5, *"THERE IS NO CLEARING IN IT"*; design 1.2.3 and 11 D4.

3. **The ROAD layout is today's drive, number for number, and that is asserted rather than claimed.**
   `forest_stand.spec`'s *"leaves the ROAD layout exactly as it was before task 179"* checks the
   centre, amplitude, count, spacing, half-span, `SHAPE`, `exitZOf(road) == -2377` (the old `EXIT_Z`
   constant) and `fieldFor(road)` field by field against the table `ForestTestBoot` used to build
   (bounds 2230..3830 by -2477..-1197, exit -2377, ground 138).
   *Verify:* that case; `git show 598e119 -- src/server/ForestTestBoot.server.luau` for the `field`
   it replaced. So the rollback — `LAYOUT_ORDER = { "road" }` — is a real rollback.

4. **Every pure geometry function takes a layout as a trailing optional parameter defaulting to
   `ROAD_LAYOUT`, which is this module's own `spook`/`beater`/`rest` idiom.** The bare constants
   `CENTRE`, `ROAD`, `STAND_COUNT`, `STAND_SPACING`, `HALF_SPAN`, `EXIT_Z` and
   `BEATER.laneSpacingStuds` are **removed**, not kept, because keeping one beside a live layout is
   two answers to "where is the line".
   *Verify:* `grep -rn "\.CENTRE\b\|\.EXIT_Z\b\|\.STAND_COUNT\b\|\.STAND_SPACING\b\|\.HALF_SPAN\b\|laneSpacingStuds" src/ tests/`
   — the only hits are `laneSpacing`'s own honouring of a spec-supplied `beater` table.

5. **`EXIT_Z` could not stay a constant, and that is a real defect avoided rather than a tidy-up.**
   -2377 is **223 studs NORTH of the ride's line at -2600**, so a boar on the ride would have been
   despawned by `Brain:_outcome` before it reached the hunters. `exitZOf(layout)` and
   `fieldFor(layout)`, with `Runtime:setField` (new, `src/server/Boar/init.luau`) swapping the
   runtime's field when a layout is promoted — after `runtime:clear()`, because a boar keeps the
   field it was born with.
   *Verify:* `ForestTest.exitZOf`, `promote` in `src/server/ForestTest/init.luau`, `Runtime:setField`'s
   header; `forest_stand.spec`'s *"starts the beaters behind the animals and north of every stand"*.

6. **`Match` placed every drive's hunters on the marker set measured during the PREVIOUS drive, and
   this task fixes it.** `dispatch` set `markersStale` on the `Assigning` edge and the set was
   re-read on the NEXT step, after `applyEffects` had already emitted `placePlayers`. Invisible while
   a world's geometry never changed between drives; a 900-stud error with layouts.
   `measureMarkers()` is split out of `readMarkers()` and called on the edge — **only the
   measurement moves**: the `markers` EVENT still goes out on the next step, so no dispatch happens
   inside a dispatch.
   *Verify:* `measureMarkers` and the `Assigning` block in `src/server/Match/init.luau`; design 6.1.
   In DEV `measureMarkers` is `Markers.read(world.collection)` — five idempotent `GetTagged` calls —
   so the value is identical there and only the moment changes. **This is the one change outside the
   forest, and it is why this task needs `test2`.**

7. **One writer, and the client never chooses.** `ServerScriptService.ForestTest` deals, publishes
   and swaps the field; `ForestTestBoot` says WHEN (inside `world.markers`, on the `Assigning` edge,
   before anybody is placed) and decides nothing; the client reads the one string off
   `ReplicatedStorage.ForestTest.Live` (a Rojo-owned `Configuration` child of the module, `Flags`'
   own shape) and `MapUi.geometryFor` answers **nil** for a name it does not know — never the road's.
   *Verify:* `ForestTest.layoutForDrive` / `promote` / `publishLayout`; the `markers` closure in
   `ForestTestBoot`; the `drawMap` closure in `src/client/Hud/init.luau`; `map_ui.spec`'s *"gives a
   layout nobody has heard of NO MAP, never the road's"*.

8. **The bag never deals the same layout twice running, including across a refill**, which a plain
   bag of three does not give you. `ForestTest.nextLayout` is pure — `(previous, bag, roll)` — and
   `forest_stand.spec` drives 12 consecutive deals with a fixed roll plus the explicit boundary case,
   the one-name case (the same name again, not a loop) and a roll stub answering 0, -5 and 99.
   *Verify:* that function and `describe("the bag that deals the layouts")`.

9. **A pick the live layout does not have is NO PICK, not a stand in a wood.** The ride has 5 stands
   and the road has 9. `ForestTest.pickOf` refuses an index past `standCount` and `standIndexOf`,
   `standArea`, `boundary` and `hunterStandX` all go through it. It is belt over the brace — the
   drive boundary already drops every pick and `Body.place` puts him on a post the new layout has.
   *Verify:* `pickOf` and its three callers; `forest_stand.spec`'s *"refuses a pick the live layout
   does not have"*.

10. **The lobby spec's "clear of the drive" case was a z comparison and BOTH halves became false** —
    `EXIT_Z` is gone and the edge's exit (-3250) is *south* of the lodge (-2950). It is a distance
    between two rectangles now, asserted for every layout, with each owner stating its own
    (`ForestTest.corridorOf` / `boundsOf`, and `Lobby.anchorFor` + `Lobby.CONFIG.FIELD.SPAN_STUDS`);
    the two meet only in the spec. Measured gaps: corridor 463 / 145 / 130 studs, boar bounds
    363 / 85 / 70.
    *Verify:* `tests/server/lobby.spec.luau`, *"is clear of EVERY drive layout's ground"*.

## Evidence that is not a spec

* **The one-player gate, twice, on a clean tree at the code commit** — both lines above, 33/33,
  1368 server and 325 client assertions each.
* **SMOKE PASS twice in the Forest Test** (`<runs-dir>/smoke.sh 90`), and it is the live proof the
  whole chain runs:
  * dealt from the bag: `[ForestTest] layout=ride (bag): 5 stands 130 apart, centre (3350, -2600),
    exit -2850` and `[ForestTestBoot] markers: layout=ride 5/5 stands (0 refused), max ground delta
    0.00, reads=26`;
  * forced: `[ForestTest] layout=edge (override): 6 stands 150 apart, centre (3480, -3000), exit
    -3250` and `markers: layout=edge 6/6 stands (0 refused), max ground delta 0.00`.
  * Both runs: `gun in hand @15s=1 @90s=1 | stacks=0 errorLines=0 | waves=6`.
  * `DHForestLayout` was cleared afterwards and Karen's five Forest Test attributes are exactly as
    the dispatch left them (`DHFlag_COINS`, `DHFlag_DRIVE_BOTS`, `DHFlag_SHOP`, `DHShopTestGrant`,
    `DHForestStartRole`).
* **Three screenshots, inspected** (rule 5), one per layout, from a hunter's stand at eye height
  looking north down the push, in `.screenshots/`: `179-road-stand5.png` (dense birch and spruce,
  a trunk at the stand, short sight lines in shade), `179-ride-stand3.png` (open oak stand,
  dappled light, sight lines well past 100 studs under canopy), `179-edge-stand3.png` (open grass
  under full sky with a wall of trees ~100 studs out). They are three different places, which is
  the thing Karen asked for and the only thing a number cannot answer.

## What I could not verify

* **The two-player line.** `src/server/Match/init.luau` is in `TWO_PLAYER_PATHS` and StudioMCP cannot
  start that test; `run-test2.sh` additionally refuses while two Studios are open, and the second is
  Karen's Forest Test with her playtest settings on it. `ESCALATE.md` carries **NEEDS TEST2 179
  598e119** with the clicks. The placeholder above is what that line replaces.
* **Karen's eye.** Nobody has played a drive on the edge or the ride. Whether a different layout
  every drive is right (or too much), whether the edge reads as a hunt, and whether 5 and 6 stands
  feel like a line are hers — design 11, K1-K5.
* **The edge layout's push corridor as a SAMPLE COUNT.** The ride's is measured (22 of 25 samples in
  trees); the edge's 83 % is a depth ratio off the measured tree line, not a trunk sample along the
  lanes. The design named this as the one thing to measure and I did not get to it. It changes no
  shipped number — the layout's geometry is fixed either way — and a poor result is a finding about
  that layout's feel for Karen, not a defect.
* **Whether a bot beater's lane can reach the lobby's field on the `edge` layout.** Design 11 D2
  computes that lane -300 off the westernmost edge stand starts at x 2805, inside the lobby's
  220-stud field. The Director's recorded default is *ship it and log it*, because the cheap fix
  (clamping into the stand span) would change the **road** layout's behaviour too, which brief
  decision 2 freezes. Not measured live.
