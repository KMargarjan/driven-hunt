# Task 298, step B2: the range lane

Task: 298
Round: 1
Base: 0018eedce00799a3ec480813d9521097116d1a2b (`task-298-shooting-range`, phase A's design commit)
Code commit: c74d6f9233a714055bf2d0f319fa124efaaaf420

Branch `task-298b2-range-lane`, stacked on `task-298-shooting-range`. The design's step B2 only
(`docs/design/shooting-range.md` section 15, item 6): `src/shared/Range/` + `src/server/Range/`
(`Build` and the owner) + `tests/server/range.spec.luau`, built in DEV only, no menu and no gun.
B1, B3, B4, B5 and B6 are not in this branch.

**Harness, clean tree, at the code commit:**
`[harness] PASS: 34/34 checks @ c74d6f9233a714055bf2d0f319fa124efaaaf420 (clean tree) scope=all`

`test2` is N/A: no file in `TWO_PLAYER_PATHS` changed — the one composition root touched is the NEW
`src/server/RangeBoot.server.luau` (claim 8).

## Claims

1. **The lane runs and FLIPS.** `Range.step` advances the leg when the target is inside
   `WAYPOINT_STUDS` of the current end and re-issues `leadTo` for the other one. *Verify:*
   `range.spec` "crosses the lane and FLIPS direction at the end, both ways" — it asserts
   `stats().flips >= 2` AND orders in both directions. Note: `6 crossings and 6 flips in 40 s at a
   trot (east 179, west 162 orders)`.
2. **The crossing seconds are within ±10 % of `window / Boar.paceSpeed`** (design TARGET 3), measured
   off the target's own position samples at `STEP_HZ` 10. *Verify:* the "measures the crossing
   seconds" case; note: `walk 8.87 s (predicted 8.89, 0.3 %) · trot 3.62 s (3.64, 0.5 %) · run
   1.63 s (1.67, 2.0 %)`. The tolerance is `Range.CONFIG.CROSSING_TOLERANCE` = 0.10.
3. **STAND (Karen, 2026-10-27) is the Brain's own arrive-and-stop**, through the same `leadTo` seam
   with the lane's MIDDLE as the point — no second CFrame writer, no invented speed. N = 2 studs,
   M = 3 s. *Verify:* the STAND case: 180/180 samples (3 s at 60 Hz) within 2 studs,
   `directions.middle > 0`, `directions.east == nil`, `crossings == 0`.
4. **A killed target is held `CARCASS_SECONDS` (3), cleared, and a fresh one released
   `RELEASE_SECONDS` (2) later.** *Verify:* the carcass case asserts `clears == 0` under the hold,
   then `lastClear == "range carcass"` and `spawns` 1 → 2 only after the release delay.
5. **The drive is untouched: one writer each.** The range never writes an animal's position (no
   `.CFrame =` in `src/server/Range/` outside `Build`'s own parts), has its own runtime, its own
   folder (`RangeTargets`) and its own field, and `Weapon.ShotFired` is NOT wired to it. *Verify:*
   the "writes no Workspace.Boars, no drive runtime and no Workspace.Range" case — a REAL second
   runtime's folder stays empty, `Workspace.Range` is never created (the range builds into the
   folder it is handed), and `grep -n "CFrame" src/server/Range/`.
6. **THE SCREENS STOOD ON THE LANE ENDS AND NOTHING EVER CROSSED — found live, not by the fake.**
   Built in DEV with `RANGE` on, the target stopped against `ScreenEast`'s west face at x = +32.2
   for 30 s. `Range.screenPosition` now puts them beyond the end by half their width + 6 studs.
   *Verify:* commit `c74d6f92`; the "builds nothing inside the lane the target walks" case asserts
   no built part is inside the corridor (lane widened by `Boar.bodyAvoidRadius`) AND that both
   screens are still built outside it, so it cannot pass by building no screen.
7. **`Boar.paceSpeed` moved beside `Boar.gaitBands`; `ForestTest.paceSpeed` is a one-line
   delegation** and its spec is untouched (design section 6). `"stand"` returns 0. *Verify:*
   `git diff 0018eedc..HEAD -- src/server/ForestTest/init.luau` is that one function;
   `forest_stand.spec` unchanged and green.
8. **DEVIATION FROM DESIGN SECTION 3, stated not slipped in:** the DEV root is a new
   `src/server/RangeBoot.server.luau`, not a block in `MatchBoot`. Two measured reasons in its
   header: `MatchBoot` has NO `RunService.Heartbeat` (the design's "the Heartbeat the root already
   runs" does not exist in this world), and it is in `TWO_PLAYER_PATHS`, which costs a human click
   per round for a range one player evidences completely. `ArenaBoot` is the precedent. B6 wires
   Karen's place from `ForestTestBoot`, which has a Heartbeat already.
9. **`Flags.MAX_FLAGS` 18 → 19.** `RANGE` is the nineteenth and the cap refused it (`flags.spec`'s
   rot tripwire did its job). Stated in `src/shared/Flags/init.luau` beside the four bumps before
   it, with the Director's alternative named (spend TASKS.md 82b instead). Born OFF, expires
   2026-11-17.
10. **Karen's deer question is MEASURED, not assumed.** The range's own runtime spawns a `hind` with
    the red deer's own zones (6, including `neck`; the boar's 5 do not), through `Runtime:spawn`'s
    `kind` parameter and no new code path, and `leadTo` accepts it. *Verify:* the last case; note:
    `a hind spawns in the range runtime with 6 zones (boar 5), and leadTo accepts it`.

## FAIL FIRST

`[harness] FAIL: 32/34 checks @ 0018eedce00799a3ec480813d9521097116d1a2b (DIRTY TREE (4 paths) -
NOT valid evidence) scope=all`, server `2417 passed, 15 failed, 15 errors` — the tree was the base
commit's `src/` plus this spec and two EMPTY modules in place of `src/shared/Range` and
`src/server/Range` (a `return {}` each, so the requires resolve instead of yielding for ever).
**All 15 of the spec's 15 cases failed**; every other spec passed. The corridor case (claim 6) was
added after that run, so its bite is argued by its own construction instead: it asserts both screens
are built and outside the corridor, and it failed against the geometry shipped in `c7c659a4`.

## What I could not verify

- **Nothing in Karen's place.** `Range.anchorFor("forest-test")` is nil by design until B6 measures
  the anchor, so every live measurement here is **DEV ONLY** and is labelled so.
- **TARGET 4 (the target within 2 studs of the lane in z) is NOT met live:** measured in DEV the
  real body wanders to **z 120.0 .. 129.0**, i.e. ±4.0 studs, because a real animal steers and
  avoids where the spec's rail does not. The spec asserts ±2 against the rail only. Not fixed here
  (it is the Brain's steering, not the range's route); reported for B6/the Director.
- `test2` was not run (claim 8's paths).
