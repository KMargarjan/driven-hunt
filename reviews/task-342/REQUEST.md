# Task 342 -- at most 24 animals alive, so the animals never lag the server

Task: 342
Round: 1
Base: e77e755a (main, #354)
Code commit: 56973867

`[harness] PASS: 34/34 checks @ 56973867e19e616c29f1318c0f156b9588a4e192 (clean tree) scope=all`

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
| 3 | margin measured FROM THE ROAD, every mood (`e7720997`) | 32 | 4.03 ms | **0 of 28** |
| 4 | the margin has to HOLD 1.5 s, not fire on one frame (`56973867`, the code commit) | **33** | **4.16 ms** | **0** |

Cycle 2 failed and the reading says why: every one of those sixteen was still `ordered()` -- walking
at 4.5 studs/s to a route end beyond this cell's own `exitZ` -- and cycle 2's rule excluded ordered
animals. `342-diag-where.txt` and `342-diag2-where.txt` are the two readings. Cycle 4 is the
harness's own finding, in claim 11.

## STEP 3 -- live proof in her place, at the code commit `56973867`

Route: `driven-hunt-rev` checked out to the code commit and served on :34873, the Forest Test
reconnected to it (panel shot `342-connect9.png`: "DrivenHunt localhost:34873 ... Disconnect").
Her attributes before and after differ by **one line**, `DHForestLayout=A2`, which my own runs wrote
(`327h-setcell.luau`) and which I removed; every `DHFlag_*`, `DHFlag_STAND_PICK=true` included, is
untouched (`342-attrs-BEFORE.txt` / `342-attrs-AFTER.txt`). Her place ends on :34873 from
`driven-hunt-karen` at `e77e755a`, in Edit.

**DRIVE 1, the per-drive instrument on both sides** (the drive report's own
`drive 1: N step(s) avg X ms worst Y`, or the same three attributes read at the end of a
single-drive run; peak live is the ten-second sample series):

| cell | peak live | step avg | step worst | server hb p95 | client frame p95 | parts |
|---|---|---|---|---|---|---|
| **C1 normal** before (`342-before-C1`, 400 s) | 47 | 6.45 ms | 88.46 ms | 36.35 ms | 33.92 ms | 1025 |
| C1 after (`342-cc-C1b`, 320 s = drive 1) | **33** | **4.16 ms** | **74.04 ms** | 32.05 ms | 30.38 ms | 591 |
| **D1 quiet** before (`342-before-D1`, 400 s) | 33 | 5.44 ms | 88.45 ms | 36.47 ms | 33.84 ms | 850 |
| D1 after (`342-cc-D1`, 400 s) | **26** | **4.11 ms** | **82.90 ms** | 33.09 ms | 32.21 ms | 850 |
| **A2 busy** before (`342-before-A2`, 400 s) | 59 | 7.57 ms | 92.45 ms | 38.14 ms | 34.43 ms | 1055 |
| A2 after (`342-cc-A2`, 330 s = drive 1) | **35** | **4.61 ms** | **80.57 ms** | 33.03 ms | 30.92 ms | 625 |

Each row is ONE run and one window, named; no row blends two (V284). The `before` part counts and
hb/frame figures are that run's whole 400 s, which spans the second drive's stocked wood -- so they
flatter `before` rather than this task.

**Crossings W/C/E**, drive 1: C1 before 4/138/7 over 400 s, after 6/98/3 over 320 s; D1 3/117/0 to
2/120/1 (both 400 s); A2 8/123/11 over 400 s to 15/101/7 over 330 s. Animals still cross in all
three thirds and the centre still dominates, as the cell rows say.

**FRAME 342-F1**, stand 4 in C1 at ~250 s, same fixed camera both sides (`342-f1.sh`):
- `342-F1-before.png` (main): first-person over the shotgun barrel, tall grass, the birch wood
  opening north, HUD `DRIVE 1 / 1:13 TIME / 0 ANIMALS / HUNTER / $13500`, compass and minimap, one
  pale animal at the tree line mid-left and a second dark shape on the grass centre-right, toast
  *"an animal got away x20"*. 44 live at that moment.
- `342-F1-after.png` (code commit): the same camera and the same wood, HUD `DRIVE 1 / 1:17 TIME /
  0 ANIMALS / HUNTER / $13500`, one pale animal at the tree line mid-left, an orange stand marker on
  a trunk behind it, toast *"an animal got away x34"*. The where-probe at that instant:
  `Boar79 dz=-12 v=24.0` -- an animal crossing the road at a run, 12 studs past it.
- **What that pair shows:** the drive still has animals coming at 250 s, and they are being counted
  as got-aways FASTER (x34 against x20 at the same moment) -- which is the whole change: an animal
  that has crossed is counted and gone instead of walking 300 studs into the far wood.

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
10. **The gate is green at the code commit.** The `[harness] PASS: 34/34 ... @ 56973867 (clean
    tree) scope=all` line at the top of this file.
11. **The south margin must HOLD for `pastRoadSeconds` 1.5 s, not fire on one frame's reading.**
    `deer.spec`'s "cannot re-arm the burst inside a bound it is already flying" moves the ROAD 400
    studs for two ticks rather than the animal; the first version of this rule read the distance once
    and deleted the deer mid-bound. Verify: that spec passes at the code commit, and
    `boar_behaviour.spec`'s pastRoad case asserts that half the dwell still stands.

## What I could NOT verify, and what is NOT met

- **peak live <= 24 is NOT MET**: 33 / 26 / 35 inside drive 1 (C1 / D1 / A2), from 47 / 33 / 59.
  **step avg <= 4.0 ms is NOT MET**: 4.16 / 4.11 / 4.61 ms, from 6.45 / 5.44 / 7.57. Both, with the
  measured ms-per-live-animal fit and the `REST.groups` arithmetic, are in `ESCALATE.md`
  (2026-11-10 ~04:30, for the Architect) as the dispatch's option 3 asks.
- **"released counts order quiet < normal < busy" is NOT MET, and was not met before either.** Over
  400 s: before, quiet D1 147 < busy A2 184 < normal C1 192; at `e7720997`, 155 < 174 < 176. Busy and
  normal are within 1 % on BOTH sides, so the inversion is a pre-existing fact of the dial and not a
  regression. At the code commit only the two 400 s runs exist (D1 155 < C1 182), so busy against
  normal over a full 400 s is NOT measured at `56973867` -- said rather than left to be found.
- `settled` and `pastRoad` **never fired in a hunter drive**: every out-of-play animal in all three
  cells was still under orders, so all three runs read `DespawnByReason=escaped=...`. The two rules
  are proven by their cases and by the DEV-arena case; they are not proven by a live despawn line.
- The 17 KB rolling console loses the `drive 1:` line on a 400 s run, so C1's and A2's after figures
  are read from the runtime's own three attributes at the end of a SINGLE-drive run (320 s / 330 s)
  rather than from that line. Same counters, same arithmetic, one drive either way -- which is what
  the per-drive reset in claim 8 makes true.
