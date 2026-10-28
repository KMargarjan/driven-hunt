# Task 305b -- the aim fix works in DEV and not in Karen's place

Task: 305b
Round: 1
Base: 2b77716e
Code commit: TBD

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

## Claims

(filled in at the end of the round)
