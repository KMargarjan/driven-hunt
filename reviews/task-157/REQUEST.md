# Task 157 — review request: the real drive runs in the forest

Task: 157
Round: 1
Base: `612dbf2` (`main`, #139 merged)
Code commit: `bdf56898bb0fe1c44716d80d7346602587fb6178`

```
[harness] PASS: 33/33 checks @ bdf56898bb0fe1c44716d80d7346602587fb6178 (clean tree) scope=all
[harness] PASS: 33/33 checks @ bdf56898bb0fe1c44716d80d7346602587fb6178 (clean tree) scope=all
[harness2] <PENDING — the Director runs it: one Studio, one human click>
```

Two clean one-player runs at the code commit (`<runs-dir>/gate-157-4.log`, `gate-157-5.log`). **This
change touches `src/server/Match/` and `MatchBoot`-adjacent wiring, so it IS in `TWO_PLAYER_PATHS`
and the merge needs `[harness2]` for this same sha** — the Director runs it (dispatch, 2026-10-11).

## What changed

The place "Driven Hunt Forest Test" now runs the **real `Match`** on the **forest's** geometry, built
to `docs/design/forest-drive.md` (Architect PASS, `reviews/task-157/ARCH_RESULT.md`). Pattern: *the
world provides; the owner decides* — three injected fields, the repo's third instance of an owner
with an injected world. Note: `docs/research/2026-10-11-forest-drive.md`.

## Claims, and how to verify each

1. **DEV did not change, and it is provable by identity.** `Match.mergeConfig(Match.CONFIG, nil)`
   returns `Match.CONFIG` **itself**, so `Match.config() == Match.CONFIG` in the DEV place.
   *Verify:* `Match.mergeConfig` in `src/server/Match/init.luau`; the identity cases in
   `tests/server/match_config.spec.luau` and the live case in `match_live.spec.luau` ("are the table
   the LIVE drive is running on"). The whole suite is still 33/33 at 923+ server assertions.
2. **No world can give a rule number a second value.** `Match.WORLD_OVERRIDABLE` is a frozen
   allow-list of nine scalars; a key off it or a table value is an `assert`.
   *Verify:* the list and `mergeConfig` in `Match`; `match_config.spec` asserts the refusals **by
   pattern** (`^SAFETY_`, `^TIE_`, `^QUICK_TEST`, plus `POINTS`, `SOUNDER`, the roster five,
   `OUTFITS_ENABLED`, `SEED`), so a later addition fails the spec rather than passing review.
3. **The forest's animals stay the forest's.** `Match` gets `ForestTest.readOnlyBoars(runtime)` — two
   signals, three counts, **no `spawn`, `spawnSounder` or `clear`** — and `BOARS_PER_DRIVE = 0`, which
   makes `Phase.maybeRelease` return on its first predicate with no new branch.
   *Verify:* `ForestTest.readOnlyBoars`; the view case in `forest_stand.spec`; the forest-config cases
   in `match_phase.spec` (no `spawnSounder` over a whole simulated drive, `boarsReleased == 0`,
   `holdbacks == 0`); `applyClearBoars`'s existing `if world.boars.clear`, which is now false there.
4. **The marker set can say NO, and in DEV it does.** `ForestTest.Markers.build` refuses a stand whose
   two readings of the ground disagree by more than `GROUND_TOLERANCE_STUDS`; all nine refused is
   `complete = false`, the drive stays in `Waiting` and the Hud already prints `waitingFor`.
   *Verify:* `src/server/ForestTest/Markers.luau`; `tests/server/forest_markers.spec.luau` — in the
   DEV place (no terrain under those coordinates) it answers `complete = false`, names
   `forest:stands (0 of 9)` and **creates no Instance**; with injected readers it builds nine posts
   within 1 stud of `standPosition(i)`, one line with `normal == Vector3.zAxis`, and is `complete`
   with **no** boar spawns and **no** trees (both deliberate, design §4.1.4).
5. **Nothing in that place is tagged `DrivenHunt.*`.** The set is handed over through
   `world.markers`, so `Markers.read` is never called there and one `GetTagged` can never answer for
   two worlds (the inverse of the Task 79 hazard). *Verify:* `Markers.build` creates plain Parts and
   calls no `CollectionService`; `readMarkers` in `Match` takes the function branch.
6. **One decider of a role, and the old pair did not merely make two — it did not work.** `Match`
   reads `state.assignment`, not `Player.Team`, so the old `ForestTestBoot.applyRole` →
   `Body.setTeam` left a dressed beater who was still a shooter to the drive (armed, push-credited,
   unprotected by the safety rule). `/beater` and `DHForestStartRole` are now a one-shot request
   honoured by `Match.requestTeam` → `Phase`'s new `team` event.
   *Verify:* `Match.requestTeam`; the `team` branch in `Phase.step` (the join branch's three effects
   for one userId, inside a drive only, no feed line); `ForestTest.requestRole`/`takeRequest`/
   `roleFor`; the four `match_phase.spec` cases including "is not sticky: the next drive swaps her
   back"; `forest_stand.spec`'s request and `roleFor` cases. Removed code is archived at
   `backups/2026-10-11_task157_forest_roles_and_placement.txt` (rule 7).
7. **`Body` is still the one writer of where a character stands.** `applyPlace` takes
   `world.placement` when one is injected and `Body.placementFor` otherwise — same argument order,
   same "nil means they spawned and that is not a failure" — and `Body.place` remains the only caller
   of `LoadCharacter`/`PivotTo`. *Verify:* `applyPlace` in `Match`; the `placement` closure in
   `ForestTestBoot`; `ForestTest.standIndexFor` (centre-out: a solo hunter gets stand 5, which is the
   x `hunterStandX()` aims every wave at) and `postIndexFor` (a refused stand must not shift which
   post she gets — asserted on an eight-post list).
8. **TWO REAL DEFECTS WERE MEASURED IN THE PLACE AND FIXED, and neither could be seen from DEV.**
   (a) `CharacterAdded` fires there with `character.Parent == nil` — a probe running `Body.place`'s own
   sequence printed `added parent=false root=true primary=true` — so `if character.Parent then
   PivotTo` was false and **no player was ever placed**: as a hunter or as a beater she stood where
   `LoadCharacter` left her, the place's SpawnLocation on the road, while the drive's CFrame was 240
   studs north. `Body.place` now waits, bounded (2 s, counted in `Body.parentWaits()`), for the parent
   that is about to be there. (b) `Body.settle` pivots once more on the next frame if the character
   has drifted more than a stud, counted in `Body.settled()`.
   *Verify:* the two comments in `Body.place`; the three `Body.settle` cases in `match_teams.spec`;
   and the console lines below. **`settled=0` in every run since (a) was fixed** — so (b) has never
   yet bitten, and that is said rather than claimed otherwise.
9. **It is measured in the place Karen plays, by console line** (`<runs-dir>/157-console-C.txt`,
   `157-console-final.txt`): `[ForestTest] … is a hunter at (3030, 144, -2097), 0 studs from the road
   (settled=0)` — stand 5, on the road; `[ForestTest] … is now a beater (team=Drivers)` then `… is a
   beater at (3030, 159, -1857), 240 studs from the road`; `[report] drive 1 opened (300s windows)`
   (the record's window is `Match.PhaseChanged` in both worlds now); `[ForestTestBoot] markers: 9/9
   stands (0 refused), max ground delta 0.00` — and, in two later runs, `8/9 stands (1 refused), max
   ground delta 6.99`, which is the refusal working on a canopy ray and is claim 10.
   **SMOKE PASS** in that place at this sha: `gun in hand @15s=1 @100s=1 | stacks=0 errorLines=0 |
   boars=23`.
10. **What I could not verify, and one thing to decide.** The two-player half of the safety rule — a
    real beater on the push line making a hunter's shot a judged violation — needs `test2` and is the
    one behaviour here that one player cannot produce (design §13.3). And the ground over one stand is
    not stable: `Data.groundAt` excludes `OurForest`/`Foliage`/`Boars` but not the two Studio-built
    `Session` folders of 831 more trees, so one stand is refused in some runs (delta 6.99 studs). The
    drive runs on eight stands and says so; the fix is either excluding those folders or raising
    `GROUND_TOLERANCE_STUDS`, and it is the Director's call rather than this task's.

## Not verified / out of scope

- No client file changed (design §6.4), so no client spec changed.
- No feature flag: the place id is the switch (design §14, Task 79's measurement).
- The start-of-drive stand timer as a phase and the end-of-drive results scene are Karen's next two
  tasks; design §16 says where each attaches and neither is built.
- `DHForestStartRole` is currently set to `beater` in that place (the Director's switch), so the
  evidence above is the beater path; the hunter path is `157-console-C.txt` line 8.
