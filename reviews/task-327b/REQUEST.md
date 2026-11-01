# Task 327b: THE STANDS AND THE TOWERS

Task: 327b
Round: 1
Base: e7131a94 (main, with 327a merged as #310)
Code commit: 287026dd86975e179527b1284a32c2fbf6bb2cf5

```
[harness] PASS: 34/34 checks @ 287026dd86975e179527b1284a32c2fbf6bb2cf5 (clean tree) scope=all
[harness2] PASS: 36/36 checks @ 287026dd86975e179527b1284a32c2fbf6bb2cf5 (clean tree)
```

`test2` is required and was run: `src/server/Match/init.luau` is inside `TWO_PLAYER_PATHS`.

Built to `docs/design/grid-map.md` section 17's **327b**. `GRID_PREVIEW` stays OFF in git.

## Claims

1. **`ForestTest.Layout` gains four OPTIONAL fields and no shipped row grows one** (design 3.2) --
   `sides`, `beaterNorthStuds`, `fieldNorthStuds`, `cellOf`, plus the `Sides` type, in
   `src/shared/ForestTest/init.luau`. Verify: `grid.spec` case 2 ("the four shipped places") asserts
   all four are nil on `road`/`edge`/`ride`/`track` AND re-derives `standX`, `standPosition`,
   `standSpan`, `beaterNorthStuds`, `exitZOf`, `boundsOf`, `fieldFor`, `corridorOf` from the record's
   own pre-327b arithmetic, with the road's five field numbers pinned as literals.
2. **`Grid.layoutFor` is the one place a cell becomes a layout**, memoised, `standCount` 15,
   `standSpacing` the MAIN line's, `halfSpanStuds` = `cellWidth / 2` (`src/shared/Grid/init.luau`).
   Verify: `grid.spec` case 4.
3. **`ForestTest.standX` / `standPosition` delegate to `Grid` when a layout has `sides`; `standSpan`
   is then the MAIN line's.** Verify: case 4 asserts the two agree to 1e-9 on indices 1..7 of all
   eight cells (the old `(15+1)/2` middle would put stand 1 at `centre.X - 1050`), that flank stands
   are off the main road and on a flank road, and case 8 that the span is `centre.X +- 450`.
4. **A flank post never answers a line question** (design 6.4): `Markers.Set.linePosts` in
   `src/server/ForestTest/Markers.luau`, read through ONE `linePostsOf` in `src/server/Match/init.luau`
   at **five** call sites. Verify: `grid.spec` case 7 shows the DEFECT first -- handed all fifteen
   posts, `Match.lineReferenceFor` answers the flank post 340 studs up the cell and `crossedLine`
   says the beater is through -- then the fix. **DEVIATION:** the design names four sites;
   `Match.throughSpotFor` is `gatherSpotFor`'s arithmetic with its own number and had the same
   `posts[ceil(#posts/2)]` defect, so it is the fifth, named in its own comment.
5. **`hunterStandX` is clamped into the main line's span** (`src/server/ForestTest/init.luau`).
   Verify: case 8 asserts both flank ends clamp to the span's ends and no main stand moves.
6. **The release clamp stops biting on a cell** -- case 10 walks every `SCHEDULE.drive` row at the
   cell's own `beaterNorthStuds` (1430) and asserts no row is pinned to `minNorthStuds` and every row
   keeps `leadStuds` of lead, AND that today's road at `Bots.CONFIG.WALK_SPEED` still pins rows.
7. **`Grid.standPosition` / `sideOf` range-check the index** (327a note (d), because 327b wires a
   client index into this seam). Verify: case 4's four `pcall`s (16, 0, 7.5, 99) all answer false.
8. **THE TOWER MEASUREMENT IS THE MEASUREMENT** (design 6.1, task 218's rule and instrument): all
   120 stands measured in a **Play** session in Karen's place (`DrivePlaces=3`) with
   `driven-hunt-runs/327b-towers.luau` -- `218-sight2.luau` fed `Grid.standPosition`'s own values.
   `Grid.CELLS[*].towers` carries the result with each tower's gain/spread/relief in the row;
   `HighSeats.STANDS` takes the eight rows from `Grid.towerStands`, not a second copy. Verify:
   `high_seats.spec` "takes a measured tower set in every grid cell too".
   **ROW 2 IS ALL RELIEF-RELAXED and declared** (`towersRelaxed`, design 6.2 rule 4, as task 218
   declared `edge`): no stand in A2/B2/C2/D2 rolls under `JUMP_RELIEF_STUDS` inside its own circle.
   **DEVIATION:** a relaxed cell takes the LOWEST-RELIEF candidate, not the highest-gain one (D2
   stand 3 is +160 at relief 9.88 against stand 12's +155 at 2.79).
9. **The preview cell IS the live place while the flag is on** (`src/server/ForestTestBoot.server.luau`,
   `layoutByName` in `src/server/ForestTest/init.luau`). **This was MEASURED, not reasoned about:**
   the boot built C1's posts and towers and a probe a minute later read the ROAD's nine posts at
   (2430, -2120) with stands 10-15 missing -- the drive's own level-triggered `markers` closure
   rebuilds both folders once a second for the LIVE layout. A second builder of those folders is a
   preview nobody can walk, so the composition root forces the cell and the one owner builds it.
10. **Live in her place at the code commit** (`driven-hunt-294` on rojo :34874; the panel read
    `localhost:34874`, and the boot printed a 327b-only line). Zero console errors.
    `[ForestTestBoot] grid preview cell C1: 15 of 15 post(s) (7 line), 3 tower(s) at {8,13,15},
    line=true, complete=true` / `[seats] C1: 3 built, 0 refused, worst foot gap -0.30 studs` /
    `[ForestTest] layout=C1 (override): 15 stands 150 apart, centre (-3899, -5107), exit -5357`.
    **Rule E / L-086, worst case over every item:** each of the 12 ground stands' post bottoms is
    -0.50..+0.65 studs against the terrain under its worst footprint sample; the 3 tower stands read
    +12.00..+12.33 because their post sits ON THE DECK by design; every leg and ladder of all three
    towers is **0.25..0.30 studs INTO the ground** (two instruments agreeing: `Seats`' own
    `worst foot gap -0.30` and `327b-seatlow.luau`). Nothing is within 8 studs of any of the 120
    stands in any cell (`partsNear=0`).

## What I could not verify

- **Karen has not walked it.** Rule 5 frames are mine, not hers.
- **No "ring of 15 stands" aerial.** A post is a 6x1x6 pad at the ground, and at 250-420 studs the
  roads themselves wash out (streaming + Atmosphere) -- 327a recorded the same gap. The ring is
  proven by number (15 of 15 posts, each measured) and by three ground frames, not by an aerial.
- **The road paint is still slow**: 5.82-6.37 s against the design's `< 4.0 s` (327a note (e)).
  Unchanged by this task and still queued.
- **With `GRID_PREVIEW` on, the drive's animals follow the cell** (`promote` swaps the field): the
  stand-5 frame has a sounder on cell C1's road. Correct behaviour, not asked for by this task.

ANSWERED: L-136 -- no spec failed as a flake; the two FAILs in the first gate run were MY OWN cases
(`grid.spec:361`, `:528`), fixed in `287026dd` and named in its message. No `weapon_shot.spec:1490`,
no `deer_hitbox`, no `weapon_client`, no `camera_client` failure fired. Both final runs are clean.
ANSWERED: L-127 -- every claim above is MET or carries its own NOT PROVEN line; see the report.
ANSWERED: L-162 -- the first live proof ran at `44292a4d`; the code commit moved to `287026dd`
(tests only), so **the whole live proof was re-run at `287026dd`** and the numbers are that run's.
ANSWERED: L-014 -- `driven-hunt-karen` was never checked out; only `driven-hunt-294` moved, and it
is back at `e7131a94`.
ANSWERED: L-139 -- the switch back was verified **two ways**: the Rojo panel reads `localhost:34873`,
AND with `GRID_PREVIEW` still ON a boot there printed no `grid preview cell` line, `layout=road
(rotation)`, and `ForestMarkers` held the ROAD's nine posts at (2430, -2120).
