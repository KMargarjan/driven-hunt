# Task 342 -- at most 24 animals alive, so the animals never lag the server

Task: 342
Round: 1
Base: e77e755a (main, #354)
Code commit: e7720997

Harness, clean tree, full suite:
`[harness] PASS: 34/34 checks @ 657f2c06bc22b24e22c12d44d8a2d365076643d2 (clean tree) scope=all`
and, for the code commit `e7720997` which is 657f2c06 plus the two margin numbers and their cases:
see **claim 10** -- the re-run is the line pasted at the bottom of this file.

`test2`: **N/A.** Nothing changed under `TWO_PLAYER_PATHS` (`src/server/Match/`,
`src/server/MatchBoot.server.luau`, `src/client/Match/`, `src/client/MatchBoot.client.luau`,
`src/shared/Drive/`, `tests/client/Role.luau` and their specs). The four files changed are
`src/server/Boar/Brain.luau`, `src/server/Boar/init.luau`, `src/server/ForestTest/init.luau`,
`src/shared/ForestTest/init.luau` -- the animal runtime and the Forest Test, as the dispatch asked.

## PLAN (core quality protocol, step 0) -- committed at `29fbdefc`, before any `src/` edit

**(a) REAL LIFE.** A *Treiben* is beaten ONCE: the animals in a section either cross the shooting
line or break back through the beaters, and nothing comes back in, so the count inside a beaten
section only FALLS once the push starts. `docs/design/grid-map.md` 9.2 puts it at **<= 24 live**,
`MAX_BOARS` 60 as the hard ceiling, and **<= 4.0 ms/frame average, <= 8.0 ms peak** for the step.

**(b) MEASURED NOW / (e) MEASURED AFTER** -- the same probe both sides:
`<runs-dir>/342-drive.sh <tag> <cell> 400`, which arms `342-arm.luau` and reads `342-step.luau`.

**(c) TARGET.** peak live <= 24, step avg <= 4.0 ms. **(d) LEVER.** `Brain:_outcome` (the one
despawn decision; `Boar` owns `_despawn`, L-104 -- no second path) and `releaseLine`'s release door.

## STEP 2 -- three cycles, same instrument each time (C1)

| cycle | change | peak live, drive 1 | step avg, drive 1 | out-of-play backlog south of the road at 185 s |
|---|---|---|---|---|
| 1 (before) | main e77e755a | 47 | 6.45 ms | 16 of 44 live, 264-332 studs past the road |
| 2 | despawn at `exitZ` + repeat-window budget (`657f2c06`) | 45 | 6.69 ms | 16 of 44 -- **nothing despawned**, `DespawnByReason=escaped=113` |
| 3 | margin measured FROM THE ROAD, every mood (`e7720997`) | **32** | **4.03 ms** | **0 of 28** |

Cycle 2 failed and the reading says why: every one of those sixteen was still `ordered()` -- walking
at 4.5 studs/s to a route end beyond this cell's own `exitZ` -- and cycle 2's rule excluded ordered
animals. `342-diag-where.txt` and `342-diag2-where.txt` are the two readings.

## Claims

1. **An animal past the cell's outer road by a margin leaves, in any mood but DOWN and CRIPPLED.**
   `Brain:_outcome`, `OUT_OF_PLAY.pastRoadStuds` 150. Verify: `boar_behaviour.spec`, "takes an
   animal that stopped past the outer road with nobody driving it" -- 155 studs south goes, 145 stays,
   and with `ENABLED` false neither does.
2. **A got-away is still reported as `escaped`**, so the toast, `Score.escape` and the report are
   unchanged; only WHERE it is counted as gone moves. Verify: same spec, "still reports a GOT AWAY as
   escaped" (an ordered one and a fleeing one), and `Match.onDespawned`, which is untouched and still
   early-returns on any reason but `escaped`.
3. **A shot animal is NOT despawned by this.** DOWN and CRIPPLED return before both rules. Verify:
   same spec, "does NOT take an animal a hunter shot".
4. **The DEV arena is unchanged by construction**: both rules need `field.road`, and only
   `ForestTest.fieldFor` ever puts one on a field. Verify: same spec, "is inert in a field with no
   road", plus `boar_brain.spec`'s existing "does not despawn an idle boar that drifts over the exit
   line" (Task 17 finding 6), which still passes.
5. **A group the drive let go of, left 80+ studs north for 60 s, leaves as `settled`; one the drive
   never ordered -- Karen's stocked wood -- never does.** Verify: same spec, "takes a group the drive
   let go of", which also drives the stocked case and the still-led case and expects no despawn.
6. **The repeat window releases only while live + the whole group <= 24**, read off
   `Runtime:liveCount()` at that slot and never latched (L-029). `ForestTest.repeatRoomFor` is the
   pure rule; `releaseLine` is its one call. Verify: `forest_line.spec`, "never lets live past 24
   over a long repeat window, and would without the gate" (the same walk with no ceiling passes 24),
   and "is asked per release against the live count of that moment". LIVE: the console of
   `342-after-C1-console.txt` -- *"repeat slot 16 held -- 28 live + 9 would pass the budget of 24"*.
7. **A SCRIPTED slot is not capped**, so the density dial keeps today's shape. Verify: same spec,
   `repeatRoomFor(15, 15, 60, 9, CAP) == true` and slot 0 (a staged release) the same; live, D1 and
   A2 held 0 repeat slots and released 155 / 174 against 147 / 184 before.
8. **`stepMsAvg`, `stepMsMax`, the peak live and the despawn reasons are PER DRIVE**, handed back by
   `Runtime:clear` -- this owner's one drive boundary, as its own comment already said. Verify:
   `forest_line.spec`, "publishes live, the drive's peak and the despawn reasons, and hands them back
   on clear"; `despawned` stays cumulative in the same case.
9. **They are published where a live probe can read them** (V293b): `Live`, `LiveMax`,
   `DespawnByReason` on the runtime's folder, and each of the two out-of-play reasons prints a line.
   Verify: the same case; live, `342-after-A2-step.txt` -- `live=49 liveMax=60
   despawns=escaped=124 outOfBounds=1`.
10. **The gate is green at the code commit.** `python tools/studio_mcp.py test`, clean tree,
    scope=all, at `e7720997`; the line is pasted at the bottom of this file.

## What I could NOT verify, and what is NOT met

- **peak live <= 24 is NOT MET**: 32 / 27 / 32 inside drive 1 (C1 / D1 / A2), from 47 / 33 / 59.
  **step avg <= 4.0 ms is NOT MET**: 4.03 / 4.13 ms, from 6.45 / 5.44. Both, with the measured
  ms-per-live-animal fit and the `REST.groups` arithmetic, are in `ESCALATE.md`
  (2026-11-10 ~04:30, for the Architect) as the dispatch's option 3 asks.
- **"released counts order quiet < normal < busy" is NOT MET and was not met before either**:
  155 < 174 < 176 after, 147 < 184 < 192 before -- busy A2 and normal C1 are within 1 % both sides,
  so this is a pre-existing fact of the dial and not a regression. Said rather than left to be found.
- `settled` and `pastRoad` **never fired in a hunter drive**: every out-of-play animal in all three
  cells was still under orders, so all three runs read `DespawnByReason=escaped=...`. The two rules
  are proven by their cases and by the DEV-arena case; they are not proven by a live despawn line.
- A2's per-drive console line was lost to the 17 KB rolling buffer on the AFTER run; A2's after
  number in the report is the whole 400 s window (5.74 ms), not drive 1 alone.
