# Task 179 — varied drives: more than one place to stand

Task: 179
Round: 2
Base: 253d21f (main, #162 merged)
Code commit: 08ddde735df89dd897c758496af4bdba546de76a

```
[harness] PASS: 33/33 checks @ 9e880f57c157bb9d72f5e33f0fcc46c76d0fef6d (clean tree) scope=all
[harness] PASS: 33/33 checks @ 9e880f57c157bb9d72f5e33f0fcc46c76d0fef6d (clean tree) scope=all
```

```
[harness] PASS: 33/33 checks @ 08ddde735df89dd897c758496af4bdba546de76a (clean tree) scope=all
[harness2] PASS: 35/35 checks @ 08ddde735df89dd897c758496af4bdba546de76a (clean tree)
```

DIRECTOR NOTE: both lines are the Director's at the head `08ddde7` (only paperwork after `9e880f5`).

## What changed

**KAREN, 2026-10-13 ~13:55, verbatim:** *"we will improve terrain that not all a time same place
hunters standing and not the same terrain for beaters / we will make view for hunter from different
places and diffretent tree lines road ect like in real life"*.

A drive **layout** is data in the one world-geometry seam. Three ship — the **road** (today,
unchanged), the south **forest edge** and a straight **ride** — one is dealt per drive from a
shuffled bag, and `DHForestLayout` forces one for a test. Design `docs/design/drive-layouts.md`
(Architect PASS), note `docs/research/2026-10-14-drive-layouts.md`, brief `reviews/task-179/BRIEF.md`.

Files: `src/shared/ForestTest/init.luau`, `src/shared/ForestTest/Live.model.json` (new),
`src/server/ForestTest/init.luau`, `src/server/ForestTest/Markers.luau`,
`src/server/ForestTestBoot.server.luau`, `src/server/Match/init.luau`, `src/server/Boar/init.luau`,
`src/server/Bots/init.luau`, `src/client/Hud/init.luau`, `src/client/Hud/MapUi.luau`,
`src/client/Hud/Objective.luau`, `src/shared/Lobby/init.luau`, `GAME_DESIGN.md`, and the specs
`forest_stand`, `forest_markers`, `forest_line`, `bots_lane`, `lobby`, `map_ui`.

**Round 1's four findings are all fixed, each at its owner and each with a case that fails on the
round-1 code.** They are claims 1-4 below; claims 5-11 are the task's own and are written fresh.

## Claims

1. **(finding 1) The stand's soft wall is measured against the LIVE layout, so a hunter stays on his
   own stand.** Round 1 was game-breaking exactly as the Reviewer described: `withinStand` and
   `boundaryPoint` read the default layout, `ForestTest.boundary` runs them every Heartbeat, and a
   hunter on his own ride stand was measured against the road's stand of the same index — 815 studs,
   far outside the 12-stud circle — so his `CFrame` was rewritten onto the road's circle every tick.
   Both now take an optional layout defaulting to the live one, and **`boundaryPoint` resolves it
   once and hands it to `withinStand`**, so the two reads cannot be about different circles.
   *Verify:* both functions in `src/server/ForestTest/init.luau`; `forest_stand.spec`'s *"keeps a
   hunter on HIS OWN stand on a non-road layout, never on the road's"* (every layout, the circle's
   inside, its edge and its outside) and *"measures the stand circle against the LIVE layout when
   nobody passes one"*, which is the half `ForestTest.boundary` actually runs — it asserts that
   standing on the ROAD's stand of the same index is now OUTSIDE.
   *Live, 60 s per layout, in the Forest Test:* section "Evidence that is not a spec".

2. **(finding 2) The boar runtime gets the live layout's field on the FIRST drive of a session.**
   `promote` guarded the swap on a runtime that does not exist yet — the first deal happens inside
   `Match.start`'s first marker read, which the boot runs *before* `ForestTest.start` — and the
   first deal can never be the road, so it was every session, not an edge case. `ForestTest.applyField`
   is now the one writer of a runtime's field and `ForestTest.start` calls it with the already-chosen
   layout.
   *Verify:* `ForestTest.applyField`, `ForestTest.start` and `promote`; `forest_stand.spec`'s *"gives
   the boar runtime the LIVE layout's field, on the first drive of the session"* — a fake runtime
   records every `setField`, and the case also asserts the layout's own spawn line is inside the
   field it is spawned into, which is what round 1 broke (a ride line spawns at −2420 and the road's
   exit is −2377, already past it).

3. **(finding 3) The map redraws when the world hands it a different layout.** `MapUi.setGeometry`
   latched `built` for the life of the client, so the attribute signal replaced only the table
   `withinBounds` reads and the drawn road and stands stayed on the first layout from drive 2 on.
   It tears down (by ownership: the children of the two frames and the legend holder, all of which
   `MapUi` is the one writer of) and rebuilds when `sameGeometry` says the geometry is really
   different — **and is still idempotent for the same one**, because `Hud` calls it on every
   attribute write and a map that rebuilt per write would flicker.
   *Verify:* `sameGeometry`, `teardown` and `MapUi.setGeometry`; `map_ui.spec`'s *"REDRAWS the
   picture when the world hands it a different layout"*, which asserts on **the drawn nodes** —
   the `Stand*` frames under the minimap's `Geometry` layer, their count and their position — not on
   `MapUi.geometry()`, which is what let the round-1 claim pass while the picture was wrong. It
   re-finds the layer every time, because a rebuild destroys it.

4. **(finding 4) The live name is published on every deal, not only when the layout changes.**
   `publishLayout` ran only from `promote`, so a session whose first deal equalled the starting name
   (`DHForestLayout = road`, or a bag that deals the default first) wrote no attribute at all and the
   hunter had **no map for the whole session**. It is now written on every deal, **unconditionally
   and not behind a latch** — my first fix latched it, and the spec caught that: a latch answers *has
   this process ever said it* when the question is *does the attribute say what is true*. Writing the
   same string again fires no `AttributeChanged`, so it costs the clients nothing. The console line
   is still once per choice.
   *Verify:* the `else` branch of `ForestTest.layoutForDrive`; `forest_stand.spec`'s *"publishes the
   name on the FIRST deal, even when it is the one it started on"*, which clears the attribute twice
   and requires it back both times.

5. **Three layouts ship, and every number in them was MEASURED in the Forest Test before it was
   written.** `ForestTest.LAYOUTS`; the measurements are `docs/research/2026-10-14-drive-layouts.md`
   section 5. The stand lines are x 2430..3630 (road), 3105..3855 (edge), 3090..3610 (ride), which is
   what `standX` produces from each record.

6. **The dispatch's fourth layout — a clearing with a high seat — is NOT shipped, and the reason is a
   measurement.** Of 1,054 points sampled inside the wood every 50 studs, **nine** have nothing
   colliding within 45 studs and no two are adjacent. *Verify:* note section 5; design 1.2.3, 11 D4.

7. **The ROAD layout is today's drive, number for number, asserted rather than claimed.**
   `forest_stand.spec`'s *"leaves the ROAD layout exactly as it was before task 179"* checks the
   centre, amplitude, count, spacing, half-span, `SHAPE`, `exitZOf(road) == -2377` (the old `EXIT_Z`
   constant) and `fieldFor(road)` field by field against the table `ForestTestBoot` used to build. So
   the rollback — `LAYOUT_ORDER = { "road" }` — is a real rollback.

8. **Every pure geometry function takes a layout as a trailing optional parameter defaulting to
   `ROAD_LAYOUT`** (this module's own `spook`/`beater`/`rest` idiom), and the bare constants
   `CENTRE`, `ROAD`, `STAND_COUNT`, `STAND_SPACING`, `HALF_SPAN`, `EXIT_Z` and
   `BEATER.laneSpacingStuds` are **removed**, not kept.
   *Verify:* `grep -rn "standPosition(" src/ tests/` — every production call now names a layout; the
   remaining bare ones are in specs, where the road is what they mean. Round 1's note about the four
   **stale citations** this removal left behind (`Hud.Objective`, `MapUi.CONFIG`, `Lobby`, `Bots`) is
   fixed too.

9. **`Match` placed every drive's hunters on the marker set measured during the PREVIOUS drive, and
   this task fixes it.** `measureMarkers()` is split out of `readMarkers()` and called on the
   `Assigning` edge — **only the measurement moves**: the `markers` EVENT still goes out on the next
   step, so no dispatch happens inside a dispatch. In DEV it is five idempotent `GetTagged` calls, so
   the value is identical there and only the moment changes. **This is the one change outside the
   forest, and it is why this task needs `test2`.** *Verify:* design 6.1.

10. **The bag never deals the same layout twice running, including across a refill.**
    `ForestTest.nextLayout` is pure; `forest_stand.spec` drives 12 consecutive deals with a fixed
    roll, the explicit boundary case, the one-name case and a roll stub answering 0, −5 and 99.

11. **The lobby spec's "clear of the drive" case is a distance between two rectangles now**, asserted
    for every layout, with each owner stating its own; the two meet only in the spec. Both halves of
    the old z comparison became false (`EXIT_Z` is gone and the edge's exit is *south* of the lodge).
    Measured gaps: corridor 463 / 145 / 130 studs, boar bounds 363 / 85 / 70.

## Evidence that is not a spec

* **The one-player gate, twice, on a clean tree at the code commit** — both lines above, 33/33,
  1371 server and 326 client assertions each.
* **LIVE, in the Forest Test, 60 s on the stand with the layout forced** (`<runs-dir>/stand179.sh`,
  sampling the server every 5 s; the player is stepped into the truck spot first, as `smoke.sh`
  does, because the lobby is on in that place):
  * **`ride`** — `layout=ride ring=3 distToMyStand=0.0 nearest=Stand3 at=0.0 me=(3350,-2600)`, all
    12 samples identical. (3350, −2600) **is** the ride's own stand 3. On round-1 code he would have
    been dragged to the road's stand 3 circle at (2730, ≈−2070).
  * **`edge`** — `layout=edge ring=3 distToMyStand=0.0 nearest=Stand3 at=0.0 me=(3405,-3000)`, all
    samples identical. (3405, −3000) is the edge's own stand 3.
  * `stacks=0 errorLines=0` in both, and the console carries
    `[ForestTest] layout=<name> (override)` + `[ForestTestBoot] markers: layout=<name> n/n stands
    (0 refused), max ground delta 0.00`.
* **Finding 2, live:** on the `edge` layout the wood held **9 → 26 live boars at z −3248..−2759** —
  animals crossing the line at −3000 and running on to that layout's own exit at −3250. On round-1
  code those positions are outside the ROAD's field (`minZ` −2477, exit −2377) and `Brain:_outcome`
  would have despawned them outright. This is the alive-boar count the Reviewer correctly said the
  round-1 smoke evidence did not carry.
* **SMOKE PASS twice** (round 1, `<runs-dir>/smoke.sh 90`): `gun in hand @15s=1 @90s=1 | stacks=0
  errorLines=0 | waves=6`, once on a dealt layout and once on a forced one.
* **Three screenshots, inspected** (rule 5), one per layout from a hunter's stand at eye height
  looking north: `.screenshots/179-road-stand5.png` (dense birch and spruce, a trunk at the stand,
  short sight lines in shade), `179-ride-stand3.png` (open oak, dappled light, sight lines well past
  100 studs under canopy), `179-edge-stand3.png` (open grass under full sky, a wall of trees ~100
  studs out). Three different places, which is the thing a number cannot answer.
* `DHForestLayout` was cleared after every forced run and Karen's five Forest Test attributes are
  exactly as the dispatch left them (`DHFlag_COINS`, `DHFlag_DRIVE_BOTS`, `DHFlag_SHOP`,
  `DHShopTestGrant`, `DHForestStartRole`).

## What I could not verify

* **The two-player line.** `src/server/Match/init.luau` is in `TWO_PLAYER_PATHS`; StudioMCP cannot
  start that test and `run-test2.sh` refuses while two Studios are open. `ESCALATE.md` carries
  **NEEDS TEST2 179 9e880f5** with the clicks.
* **Karen's eye.** Nobody has *played* a drive on the edge or the ride — the 60-second runs above
  stand still and are about geometry, not feel. Design 11, K1-K5.
* **The edge layout's push corridor as a SAMPLE COUNT.** The ride's is measured (22 of 25 samples in
  trees); the edge's 83 % is a depth ratio off the measured tree line, not a trunk sample along the
  lanes. It changes no shipped number.
* **Whether a bot beater's lane reaches the lobby's field on the `edge` layout** (design 11 D2): lane
  −300 off the westernmost edge stand starts at x 2805, inside the lobby's 220-stud field. The
  Director's recorded default is *ship it and log it*, because the cheap fix would change the road
  layout too, which brief decision 2 freezes. Not measured live.
* **Round 1's third note is queued, not fixed (179a):** the forced-layout spec cases promote the real
  world (`publishLayout`, `runtime:clear()`) and leave `chosen.drive` advanced. They restore the
  default layout, and the harness passes twice, but a seam that drives the chooser without promoting
  would be better. It is a test-hygiene change to the thing under test, which is not a round-2 fix.
