# Task 345d -- `releaseLine` STOPS SPAWNING; `orderGroup` ORDERS (T4 of animal-placement)

Task: 345d
Round: 1
Base: 85c4aef1 (origin/main, #363)
Code commit: 3e1c259ad60c25ae4e9b6d06c9e9d9ad121ea8c4

`[harness] PASS: 34/34 checks @ 3e1c259ad60c25ae4e9b6d06c9e9d9ad121ea8c4 (clean tree) scope=all`
`test2` **N/A** -- no `TWO_PLAYER_PATHS` path is touched (design section 17 says so for all six tasks).

## PLAN (core quality protocol step 0, committed at `783382d2` before any `src/` edit)

**(a) REAL LIFE.** A sounder the line reaches leaves its bed in SINGLE FILE behind the leading sow.
`docs/design/animal-placement.md` 4.6 puts the number on it: a formed file within 5 s of the break,
median nose-to-nose <= `2 x LINE.spacingStuds` = **17 studs** (`spacingStuds` 8.5).

**(b) MEASURED NOW (at the base).** On the flag-ON path a woken group got **no file at all**:
`releaseLine` printed `THE ROSTER'S ... the line finds it` and returned, nothing was ever put in
`state.lines`, and `spookNearBeaters` turned the group into a flight. Instrument: task 345b's ON
drives (`<runs-dir>/345b-ON4-{C1,A2}-console.txt`), whose SLOT lines carry no `in N of M file(s)`.

**(c) TARGET.** Median nose-to-nose <= 17 studs within 5 s, over >= 10 breaks, C1 and A2. Scheduled
slots spawning on the ON path: 0. A2 ring searches per drive: < 100 (was ~2,940).

**(d) LEVER.** `src/server/ForestTest/init.luau`, the `table.insert(state.lines, {` with
`trail = seeded` -- reachable only from `releaseLine`'s spawn half. Now also from
`ForestTest.orderGroup`. The searches counter the cap bounds: `state.placementSearches += 1` in
`ForestTest.bedSpot`.

**(e) HOW IT IS MEASURED AFTER.** `ForestTest.measureFile` -- one instrument, both sides: a WOKEN
file (what T4 builds) and a RELEASED one (the control, spawned along its approach) -- published on
`ServerStorage.DHForestPlacement`, Studio only, because a live `require` over StudioMCP answers a
FRESH module (measured: `placementStats()` read `drive=nil` while the attribute read `drive=1`).

## What changed

`releaseLine` keeps its ROUTE half (lifted into `routeFilesFor`, shared) and loses its SPAWN half for
every scheduled slot while the flag is on; the T2 bridge is archived. `ForestTest.orderGroup` hands a
woken group its own route from where it is standing, seeded from the leader's feet backwards along
the first leg. The Director's retry cap: three searches per row, then PARKED, then one reopen. Three
things were measured wrong on the way and fixed, each with its reading (claims 5-7).

## Claims

1. **Nothing is spawned for a scheduled slot while the switch is on.** `ForestTest.releaseLine`'s
   roster branch now fires for every slot with a roster row, whatever its state.
   *Verify:* `forest_placement.spec` -> *"releases nothing for a scheduled slot the switch owns"*;
   and live, eight ON drives in Karen's Forest Test: every `SLOT n` line is a roster line
   (`grep -oE "SLOT [0-9]+ act [0-9]+ [A-Z-]+ -- [0-9]+ of" 345d-ON*-console.txt` finds none for
   slots 1-15). **L-093 RUN at the code commit:** restore the bridge (`and inRoster.skipped == nil`)
   -> `forest_placement.spec:1221` fails. Slots **16+** (the repeat window) still spawn: design 17's
   T5, `ESCALATE.md` entry 5.
2. **A woken group is handed its route in a file, from where it stands.** `ForestTest.orderGroup`:
   `routeFilesFor` for the pins, `Line.order`/`Line.split` for the march (rank ties broken by who is
   already in front), `Placement.seedTrail` for the trail, `formSounder` for the ears, one
   `state.lines` row per file. No `spawn` call anywhere in it.
   *Verify:* the spec's *"orders a woken group once, counts a group the fright already took, and
   spawns nothing"*; live, `ordered=` on the probe attribute: **12 groups over eight drives**,
   `noroute=0` in every one.
3. **A file formed from a bed is as tight as one spawned along its approach, and inside the target.**
   MEASURED, `ForestTest.measureFile`, same instrument both sides, at +5 s after the order:
   **woken 3 files, medians 7.7 and 8.5 studs, worst 10.3** (`345d-ON2-C1-track.txt`,
   `345d-ON7-C1-track.txt`) against the target of **17**; **released (control) 14 files, medians
   8.4-8.6, worst 14.5**. **NOT PROVEN over the design's >= 10 breaks: 3.** The reason is measured
   and is the horn (`ESCALATE.md` entry 4): 357 studs reaches five beds from a line 300 studs away,
   6-9 animals pushed per blast, four blasts a drive, and a flight can never be a file.
4. **The retry cap: a refused bed is not re-searched every step, and the row is not lost.**
   `Placement.CONFIG.searchesPerWake` 3 + `Placement.dueNow`'s cap arm + `Placement.reopenNow` (one
   reopen per row per drive, on the line's band or the slot clock). Arithmetic: 15 x (3 + 3) = **90**
   worst case, under the Director's 100.
   *Verify:* live at **A2, the cell that produced the 2,940: 24 searches, caps=3, reopens=3**
   (`345d-ON5-A2-track.txt`); C1 7-10 per drive. Spec: *"parks a row that has spent its searches, and
   the drive wakes it once more"* drives **two wake cycles in one drive** and asserts the row ends up
   with a body (L-142). **L-093 RUN:** delete the cap arm -> `forest_placement.spec:1276` fails.
5. **MEASURED AND FIXED #1: the pathfinder answers `NoPath` from a bed.** A bed is in COVER by
   construction and a point inside a trunk's `AgentRadius` is off the navmesh. Same animal, same
   tick (`<runs-dir>/345d-path.luau`): from the body's Y, 100 studs south = `NoPath`; from the GROUND
   under its feet = `Success, 31 waypoints`. `orderGroup` now starts the route at the first point the
   pathfinder accepts -- the ground under the leader, then 30/60/90 studs along the way out. The file
   is STEERED to `route[1]` by `Runtime:leadTo`, never pathed to it.
   *Verify:* `noroute` went **2 -> 0** and stayed 0 in all seven later drives.
6. **MEASURED AND FIXED #2: the wake read the bed while the flush read the animal.**
   `345d-diag-mid.txt`: `flights=3 ordered=1` -- three of four woken groups were already FLYING when
   `orderGroup` reached them. The wake is now judged on the group's LIVE position (the member nearest
   the line, off the one runtime walk `stepPlacement` already does) and leads the notice by half a
   bed spread. `345d-ON2-C1-console.txt` has the case in one line: *"a beater spooked Boar65 at 145
   studs, **137 ahead of the front**"*.
   *Verify:* the spec's wake case asserts both the lead and `atNorth`; live, `ordered` went 1 -> 3
   per drive.
7. **MEASURED AND FIXED #3: the horn leaves no latch, so a fleeing group read as "bedded".**
   `345d-ON3-C1`: `ordered=0 wokeBand=0 flights=0` with **7 of 13 rows going straight to `gone`** --
   their animals had been horn-flushed and the roster never saw it. The reconcile now asks the Brain
   (`Runtime:flying`), and the order is offered **four times, four seconds apart**, so a group whose
   flight has ended still gets its route.
   *Verify:* the spec's try-count case (60 heartbeats inside the window cost no route; 60 s cost the
   three that are left and then nothing); live, `flights=` is now counted instead of hidden.
8. **Nothing is created in view, and the flag-OFF drive is unchanged.** `inView = 0` on every one of
   the eight ON drives. OFF (`345d-OFF-C1-console.txt`): every scheduled slot released its animals
   (`SLOT 1..4, 6, 7, 8 -- n of n animal(s)`), **no roster line at all** (`grep -c ROSTER` = 0) and no
   `DHForestPlacement` attribute, which is today's drive.
9. **One bite per Heartbeat is still one bite.** A step that orders does not also materialise;
   `orderGroup` is at most 4 `ComputeAsync` calls once per group per try, bounded by claim 7's
   counter. Boar step avg over the ON drives 4.53 ms (`345d-ON*-track.txt`), inside the 7.0 ms of
   design 12.1; heartbeat p95 27.09 ms at C1, inside 32.
10. **Rule 5 / the frame: NOT OBTAINABLE, with the measured reason** -- `ESCALATE.md` entry 1. Four
    attempts; a woken file is 700-900 studs from the hunter and `ModelStreamingMode = Atomic` keeps
    it off his client (`Boars=10 within145=0 nearest=841`), which neither `RequestStreamAroundAsync`
    (`nearest=190`) nor `Player.ReplicationFocus` (`within145=3 nearest=117`) beat inside the window.
    The two frames taken WERE opened: `345d-ON7-C1-F1.png` and `345d-ON9-C1-F1.png` show the right
    patch of wood -- birch and oak trunks, autumn leaf litter, the HUD reading `DRIVE 1 / 0 ANIMALS /
    HUNTER` -- and **no animal**, which is the streaming fact and not the drive's.

## What I could not verify

* The file-formation target over **>= 10 breaks** (3 measured). Claim 3, `ESCALATE.md` 4.
* **Anything by eye**: no frame of a woken file exists (claim 10).
* That the three fixes of claims 5-7 are the LAST of their kind: each was found by running the drive,
  and only eight drives were run.
