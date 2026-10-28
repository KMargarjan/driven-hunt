# Task 305b -- the aim fix works in DEV and not in Karen's place

Task: 305b
Round: 2
Base: 2b77716e
Code commit: PENDING

## PLAN

**(a) REAL LIFE.** A bullet goes where the barrel pointed. The only lead a shooter owes a boar at
24 studs/s and 125 studs is the bullet's own flight time -- 1.18 studs for the .416
(`Ballistics.leadStuds`, the board prints it). Nothing else about the animal's past is his problem.

**(b) MEASURED NOW, in HER place, Play, build 2b77716e, target owner SERVER:**
- view lag, `<runs-dir>/305/lag-srv.luau` + `305/lag3r-cli.luau`: the client draws the running boar
  **5.28 studs BEHIND** the server, **0.205 s**, along the heading (lateral -0.00, vertical +0.05).
- the Playtester, same build, real clicks, aim on the client's drawn chest: RUN rifle 1/10, board
  `MISS GAP 1.3 m behind` (4.3 studs = 0.18 s x 24); slug 0/2, 2.0 m behind; TROT 5/5 but every dot
  BODY/REAR; WALK 3/5 all BODY. The residual error is a CONSTANT TIME, ~0.18 s, at every pace.
- candidates, `<runs-dir>/305b/cand.luau` (the live `Cast.candidates` over the flight's own step):
  the target root IS found, 2 of 11 steps, 17 parts in the sphere, **not** saturated (cap 800).
- the ring, `<runs-dir>/305b/hist.luau` (`ServerStorage.DHBoarHistory`, live): `animals=1
  samples=5430 misses=0`, step interval 0.025-0.034 s -> 96 samples span ~2.9 s. Healthy.

So: the candidate is found and the history exists, yet the impact still trails by one whole view
lag. **The rewind is contributing ~0 in her place.** Which of `castWithRewind`'s four plain-path
exits is taken is NOT readable from outside -- `Weapon.stats()` is module state and an
`execute_luau` probe gets a fresh module (the Director's own note). So the first commit of this task
publishes it.

**(c) TARGET.** The impact lands within **1.0 stud** of the chest the client drew, at RUN
(24 studs/s), when the shooter aims at that chest plus `Ballistics.leadStuds` alone. 1.0 stud
because the boar's chest zone is ~2 studs across, so anything under that is a hit on the part aimed
at; 0.205 s of uncompensated lag is 4.9 studs, which is a clean miss.

**(d) LEVER.** `src/server/Weapon/init.luau`, `Weapon.castWithRewind` -- the only writer of the
rewound pass -- and `Weapon.rewindFor`, the only writer of the seconds it rewinds by:
```
601:function Weapon.castWithRewind(
607:	if type(rewind) ~= "number" or rewind <= 0 or (historyProvider == nil and #extraHistory == 0) then
617:	local roots = findCandidates(origin, direction, pad, ignore, Hits.targetOf, CONFIG.CLAIM.MAX_TARGETS)
2505:		rewindSeconds = Weapon.rewindFor(player, nil, CONFIG),
```

**(e) HOW IT WILL BE MEASURED AFTER.** The same three probes: `305/lag-srv.luau` +
`305/lag3r-cli.luau` for the lag, `305b/cand.luau` for the candidate, and the new
`ServerStorage.DH305Rewind` attribute for the exit taken -- plus the Playtester's own rig (client
tracker on the drawn chest, `Ballistics.leadStuds` only, real clicks) for the hits.

## STEP 1 -- her case, reproduced

Reproduced above, in her place, on her build, at her range: RUN rifle 1/10 and the board's own
`MISS GAP 1.3 m behind`. Not DEV.

## Harness

```
[harness] PASS: 34/34 checks @ 14bbd363fa9e66b36ebfeb7d400d06592c52ed35 (clean tree) scope=all
```
needs_two_player: **no**. The change touches `src/server/Weapon/Flight.luau`,
`src/server/Weapon/init.luau` and `tests/server/weapon_rewind.spec.luau`; none is in
`TWO_PLAYER_PATHS`, and a second client renders a second copy of the same bullet.

## STEP 2 -- the three cycles

The table is `reviews/task-305b/MEASURED.md` section 3: the same instrument
(`testedAt - firedAt`, published by the live code) read at three builds, moving -0.118 -> -0.119 ->
-0.126 against an ideal of -0.133.

## STEP 3 -- live proof, in HER place

`MEASURED.md` section 2 and 3. Every number is from the Forest Test in Play, her flags untouched.

## Claims

1. **The dispatch's premise is refuted: the rewind DOES run in her place.** `DH305Rewind` (written
   by the live `castWithRewind`, Studio only) reads `why=rewound rewind=0.181 cands=1 back=3.32
   hit=true`, and its `eff=` -- the look-back the ring actually delivered -- reads 0.182 and 0.190
   against a client-drawn lag of 0.185-0.205 measured the same session. Verify: `MEASURED.md` 1,
   and `Weapon.castWithRewind`'s `trail(...)` calls.
2. **The 1/10 is the zero-lead aim rule, not the rewind.** Same build 2b77716e, same rig, same
   lane, back to back: drawn chest + `Ballistics.leadStuds` = **9/10**; drawn chest + zero lead =
   **0/10**. Verify: `MEASURED.md` 2, runs `305b/p-run-rifle.luau` and `305b/z-run-rifle-nolead.luau`.
3. **FAIL FIRST does not fail, and that is the finding.** The rig that is supposed to show the
   defect on `2b77716e` scores 9/10 there. Claim 2 is what replaces it: the known-bad input is the
   zero-lead rule, which scores 0/10 on the same build in the same minute.
4. **One real defect, fixed: the rewind was anchored on the wall clock.** `Flight.advance` now
   measures it from the trigger (`ShotRecord.firedAtServer`) plus `Ballistics.timeToRange` of the
   pellet's own travelled distance -- the same function the range board prints the lead from, so
   the lead shown and the lead demanded are one number. Verify: `src/server/Weapon/Flight.luau`,
   the `rewind` block inside `Flight.advance`.
5. **The new branch is entered by a case, not only by the shipped value.** `weapon_rewind.spec`,
   `describe("Flight.advance's rewind anchor")`: 0.05 s of slip is added (0.18 -> 0.23) and a 900 s
   gap clamps at `CLAIM.VIEW_LAG_MAX_SECONDS` -- those two go red if the block is deleted. The
   third, `now = nil`, is the NON-REGRESSION half and passes with the block deleted, by design.
6. **The fix is not claimed to raise the hit rate.** 7/10 after against 9/10 before, n=10 each --
   the same number within one standard error. It is kept for the arithmetic, and `MEASURED.md` 3
   says so in those words.
7. **The diagnostic costs a live server nothing (round 1 finding 1, fixed).** `STUDIO` is read once
   at load and EVERY call site -- all four exits -- is wrapped in `if STUDIO then`, so on a live
   server no `string.format` is built, no `AssemblyLinearVelocity`/`CFrame` is read for the probe
   and no counter is bumped. Verify: grep `STUDIO` in `Weapon.castWithRewind`; the first exit (the
   one the shipped game always takes, because `AIM_REWIND` ships OFF) now does nothing but cast.
8. **The board's `MISS GAP` misleads and is NOT fixed here.** 1.3 m = 0.18 s x 24 studs/s is the
   view lag: the board measures against the server's present position. Queued for the Director.
9. **Harness**: the PASS line above, full scope, at the code commit; only paperwork after it.
10. **Known, not fixed here** (round 1 notes, queued): `castWithRewind` still reads its own
    `GetServerTimeNow()` for `at`, so the slip inside the Heartbeat handler survives -- passing
    `now` through the cast seam would close it; `DH305At` is written on the Boar's trunk by
    `Weapon` and is kept there deliberately, because it is the instrument the next run reads from
    a CLIENT and a client cannot read ServerStorage.
11. **NOT PROVEN, named**: the real-click path (every number here is a client-VM `FireRequest`);
    the lever, the semi-auto and buckshot; any animal but the range's boar; shotgun SLUG at run
    (3/5, below the 4/5 asked); WALK and TROT on the fixed build. `MEASURED.md` 4.
