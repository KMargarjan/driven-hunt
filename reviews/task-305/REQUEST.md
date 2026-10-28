# Task 305 -- a shot hits what the shooter sees

Task: 305
Round: 2
Base: 4130114e (main)
Code commit: 29476a7712d76b8200bd2c5caf936707f2e72ef8

Harness, full suite, clean tree:

    [harness] PASS: 34/34 checks @ 29476a7712d76b8200bd2c5caf936707f2e72ef8 (clean tree) scope=all

`agents.needs_two_player` returns **False**: none of the paths this diff touches is in
`TWO_PLAYER_PATHS` (which holds only `src/server/Match/`, `src/server/MatchBoot.server.luau`,
`src/client/Match/`, `src/client/MatchBoot.client.luau`, `src/shared/Drive/`, `tests/client/Role.luau`
and eleven named specs). The NET diff against `main` touches `src/server/Weapon/{Rewind,Cast,Flight,init}.luau`,
`src/server/RangeBoot.server.luau`, `src/server/Boar/Body.luau` (the other session's),
`src/shared/Shotgun/init.luau`, `src/shared/Flags/init.luau`,
`tests/server/weapon_rewind.spec.luau` and `tools/studio_mcp.py`.

**ROUND 2 BRIEFLY TOUCHED A TWO-PLAYER PATH AND ROUND 2b UN-TOUCHED IT.** `bbba8b40` chained the
history provider through all three composition roots, which put
`src/server/MatchBoot.server.luau` in the diff for three lines of plumbing. `6b0d2271` replaces that
with `Weapon.addHistoryProvider`: `setHistoryProvider` keeps its exact meaning, the drive's two
boots are untouched, and only `RangeBoot` gains a call. Verify:
`git diff --name-only origin/main..HEAD` lists no `TWO_PLAYER_PATHS` file.

**TWO BUILDER SESSIONS ARE ON THIS BRANCH AND THE FIX HAS TWO HALVES.** This request covers this
session's (`5296d523`) -- everything but `src/server/Boar/Body.luau`. That file is session
`9d5b3ff8`'s commit `97d67896`: it **re-pins the trunk to the server in `Body.attachVisual`**, after
the weld loop that rebuilds the assembly and reverts ownership to AUTO. `Body.create` already calls
`trunk:SetNetworkOwner(nil)`; the weld undoes it, which is why the engine was handing a near animal
to the nearest player and the lead's SIGN flipped with distance. Its live evidence and mine are in
`reviews/task-305/MEASURED.md` (that session's file, quoted by reference here and not re-typed).
`ESCALATE.md` says why both halves are needed and in what order; **the Director must read it before
merging either.**

## What round 2 changed, finding by finding

1. **`Weapon.castWithRewind` -- an animal with no history was in NEITHER pass and the bullet went
   through it.** The root is now inserted into `staticIgnore` only inside the accepted branch, and an
   empty candidate list returns `castFn(origin, direction, ignore)` untouched. `cframeAt` answers
   nil for four ordinary states and one of them was **every shot on the range**: `RangeBoot` builds
   its own `Boar.newRuntime` and the single provider seam held only the drive's. **Session
   `9d5b3ff8` measured that consequence: case (c), rewind on and ownership unpinned, 0/6, and the
   geometry probe caught the shot crossing 0.05 studs from the chest and carrying on to the berm --
   the bullet went THROUGH the drawn animal.** The seam is now `Weapon.addHistoryProvider`:
   `setHistoryProvider` keeps its exact old meaning and the drive's two boots are untouched,
   `RangeBoot` adds its own runtime beside the primary, and `historyAt` walks primary-then-extras
   with first-non-nil winning (`nil` from one runtime means "not mine", the seam's own documented
   meaning). Verify: `grep -n "addHistoryProvider\|historyAt" src/server/Weapon/init.luau
   src/server/RangeBoot.server.luau`.
2. **`AIM_REWIND` ships `default = false`.** The Director's sentence authorised lit for the range,
   but this half alone is wrong wherever the CLIENT owns the animal, and session `9d5b3ff8` measured
   exactly that on the mat (+0.174 s in the FUTURE). So the row is dark until the ownership commit
   lands and `305lag.py` reads one-signed at both distances -- the order `ESCALATE.md` asks the
   Director for -- and `docs/design/feature-flags.md` section 11 step 1 is obeyed rather than
   excepted. The `MAX_FLAGS` paragraph is rewritten to say so.
3. **The cast is `Weapon.castWithRewind`, public, and the spec DRIVES it.** `weapon_rewind.spec`
   gains a `describe` that wires `setRewindWorld` + `setCast` + `setHistoryProvider` and asserts: the
   animal IS hit when the segment is aimed where the shooter drew it; the same aim with `rewind = 0`
   finds nothing; the same aim at the server's PRESENT copy with the rewind on finds nothing; and an
   animal whose provider answers nil is still asked of the static pass **with the caller's own
   ignore list** (finding 1, red first). Verify: revert `Weapon.castWithRewind`'s body to
   `castFn(origin, direction, ignore)` and the first case fails.
4. **The tie case asserts IDENTITY, not the distance**, so `<` cannot silently become `<=`
   (`expect(Rewind.nearer(tieStatic, tieRewound)).to.equal(tieStatic)`). **The nearest-candidate case
   did NOT refuse last-wins, and round 2 finding 1 is right**: the injected answers FELL (9, 8, 7),
   so under a cap of 2 the last call asked was also the nearest and the two rules gave one number.
   They now RISE (5, 6), so nearest-wins gives 5 and last-wins gives 6 -- added after the round-2
   verdict and NOT reviewed.

Notes also taken: candidates are sorted nearest-the-muzzle **before** the cap, so `MAX_TARGETS` cuts
the far animal and never leaves a near one neither rewound nor excluded; `MaxParts` 200 -> 800 with
the reason; the misplaced comment moved onto the call it describes; the research note's stale
"rewind amount" row corrected and an amendment added recording the ownership half.

Notes NOT taken, with the reason: `docs/design/ballistics.md` is the **Architect's** file and the
Builder may not write designs (CLAUDE.md roles table), so the new module is not documented there --
it needs an Architect run or a Director dispatch. `Rewind.luau`'s header no longer claims the static
pass excludes every candidate past the cap, because the sort makes the cut the far animals.

## PLAN (core quality protocol step 0)

**(a) REAL LIFE.** At 35 m a .416 reaches a boar in ~0.05 s, so a boar running at 24 studs/s wants
~1.2 studs of lead -- the board's own LEAD BALLISTIC for the rifle: walk 0.22, trot 0.54, run 1.18.
Aiming at the nose of a trotting boar at that range HITS in life.
Source: `docs/research/2026-10-24-real-shooting.md`, `Ballistics.leadStuds`.

**(b) MEASURED NOW.** `<runs-dir>/305lag.py` (the task-265 recorder `265-lagrec.luau`, unchanged),
DEV, 2026-10-28, boar at 115 studs:

| part | owner | mean speed | best-fit shift | residual |
|---|---|---|---|---|
| `Boars.Boar1` | server | 2.55 studs/s | **+0.180 s, client LAGS** | 0.011 studs |
| own `HumanoidRootPart`, pushed by its own client | client | 8.69 studs/s | **-0.170 s, client AHEAD** | 0.078 studs |

The control is MOVING and client-owned, which is what task 265 round 3 lacked (L-112): a clock skew
biases both recordings the same way and so cannot produce opposite signs of near-equal size.

**(c) TARGET.** Extra lead beyond `Ballistics.leadStuds` = **0 studs**, +-0.63 (one Heartbeat x
38 studs/s, the grid's own quantisation; well inside a boar's 0.45 m chest zone).

**(d) LEVER.**

    $ grep -n "local impact = cast" src/server/Weapon/Flight.luau
    319:  local impact = cast(pellet.position, segment, shot.ignore, shot.rewindSeconds)

    $ grep -n "FLIGHT_REWIND_BASE_SECONDS" src/shared/Shotgun/init.luau src/server/Weapon/init.luau
    src/shared/Shotgun/init.luau:667:    FLIGHT_REWIND_BASE_SECONDS = 0.18,
    src/server/Weapon/init.luau:    cfg.FLIGHT_REWIND_BASE_SECONDS + seconds * cfg.FLIGHT_CATCHUP_PING_FACTOR,

**(e) HOW IT WILL BE MEASURED AFTER.** The same `305lag.py` for the lag; `<runs-dir>/305run.py` +
`305-shoot.luau` for the hit rate -- a real `FireRequest` aimed at the CLIENT'S OWN rendered chest
plus `Ballistics.leadStuds` and nothing else.

## Claims

1. **The cause is named in numbers, with a MOVING control.** The (b) table, and
   `docs/research/2026-10-28-lag-compensation.md`. Verify by re-running both `305lag.py` lines.
2. **`Weapon.Rewind` is pure and owns the arithmetic.** No `Workspace`, no clock, no cast of its own.
3. **The world touching is in `Weapon.Cast`, and `Pierce.cast` is still this folder's only ray.**
   `grep -rn "Pierce.cast|Workspace:Raycast" src/server/Weapon/` -- `Cast.world` and `Cast.only`,
   and `GetPartBoundsInRadius` is a bounds query, not a ray.
4. **`Flight` carries the rewind and reads it never.**
   `grep -n "rewindSeconds" src/server/Weapon/Flight.luau` -- the field and the call, nothing else.
5. **The flag is read ONCE at the owner's boundary and passed inward.** `REWIND_ON =
   Flags.isOn("AIM_REWIND")`; with it off `Weapon.rewindFor` returns 0, the shot carries 0, and
   `castWithRewind` is `castFn(origin, direction, ignore)` and nothing else runs.
6. **Both states are reachable by parameter**, and both are driven: `setRewindPolicy` in the
   `rewindFor` cases, and `rewind = 0` versus `0.18` in the `castWithRewind` cases.
7. **The amount is the measurement and is not `CLAIM.VIEW_LAG_BASE_SECONDS`**, capped at
   `CLAIM.VIEW_LAG_MAX_SECONDS`, zero for a negative, a NaN or a missing ping. **Round 2 finding 2: the
   `nil`-ping branch, which is the one `onFireRequest` itself takes, was NOT covered when this
   sentence first claimed it was.** One line now covers it
   (`Weapon.rewindFor(nil, nil, CONFIG)`), added after the round-2 verdict and NOT reviewed.
8. **The range gets the rewind.** `RangeBoot` ADDS its own runtime's `cframeAt` beside the drive's;
   without it the range had none, which was finding 1's live consequence (0/6, measured). A spec
   case proves the fall-through with no world: one provider wired, no rewind, no hit; add the
   second and the same aim hits.
9. **The new spec is in a scope**, and both selftests pass (`tools/studio_mcp.py selftest`,
   `tools/agents.py selftest`), run by this session at `6b0d2271` and by session `9d5b3ff8` at
   10:54 UTC over both halves combined, where `agents.needs_two_player` also returns empty.
10. **Lint, format and build are clean at the code commit**, and CI is green on it
    (run 40674420086, success).

## THE LIVE PROOF (session `9d5b3ff8`, `reviews/task-305/MEASURED.md`, DEV range mat 1)

Rifle at the range's RUN pace, 10 real `FireRequest`s per case aimed at **that client's own rendered
`ZoneChest`** plus `Ballistics.leadStuds` alone (`LEAD_T` 0.0476 s = the board's 1.18 studs at
24 studs/s), hits counted off `HitMarker.OnClientEvent` with the zone it names, `StateChanged` read
so a refused trigger is never counted as a miss:

| case | build | hits |
|---|---|---|
| (a) both halves dark -- **the fail-first** | pre-`605e1f6d` | **0/10** (8 flew, all missed) |
| (b) ownership pinned live, no rewind | pre-`605e1f6d` | **VOID**: 9 of 10 refused `no-ammo` |
| (c) rewind on, ownership unpinned | `605e1f6d` | **0/6** -- round 1 finding 1, caught geometrically |
| (d) **both halves on** | `97d67896` + `AIM_REWIND` override on | **10 hits in 11 shots that flew** |

(d)'s zones: chest x6, body x4. The one miss was at a measured 12.5 studs/s; at pace >= 15 studs/s
it is **6 for 6**. Impacts land **0.02-0.15 studs from the aim point**, and the view lag on that
build reads **+0.141 s** against +0.176 s before. Second gun family, **shotgun SLUG at run: 4/6**,
both full-pace shots in the chest, two shots produced no impact at all.

The other two paces, same rig (`MEASURED.md` section 3): **WALK 6/6** (chest x5, rear x1) at a drawn
4.4-11.1 studs/s, **TROT 4/4 of the shots that flew** at 5.6-9.3 studs/s. Totals with both halves
on: **20 hits in 21 shots that flew across the three paces**, against **0 of 8 that flew with both
halves dark at run**.

**AND THE CAVEAT THAT SESSION WROTE BESIDE ITS OWN NUMBERS, kept rather than dropped**: the walk and
trot rows were read at LOW drawn speeds, because the probe fires as soon as the target exceeds
4 studs/s and so catches it accelerating out of a respawn. At those speeds the whole demanded lead
is under half a stud and **the hit rate stops discriminating** -- a build with no fix would pass
them too. **RUN is the row that carries the claim**: lead 1.1-1.4 studs against a 4-stud error.

**So the target (>= 8/10 chest-or-body per pace per gun) is MET for the rifle at run, met but NOT
DISCRIMINATING at walk and trot, and NOT MET for the shotgun slug at 4/6.** The numbers are reported
as they read.

## What I could NOT verify (rule 8)

- **`[harness2]` WAS NOT RUN, and is N/A**: the net diff against `main` contains no
  `TWO_PLAYER_PATHS` file (round 2b removed the only one), so `agents.needs_two_player` is empty for
  this half and for both halves combined. The one-player line above is the gate, for the PR to
  `main` as well.
- **The harness line names `29476a77`, which is the commit holding this file's previous revision.**
  That is the allowed shape (git workflow step 4: a later paperwork commit only tightens the bound)
  and the only thing committed after it is this file.
- **THIS SESSION's own click case never fired a shot**, and the rows above are the other session's.
  In the DEV ARENA the request is refused before anything is cast: my client probe's `StateChanged`
  listener caught `REFUSED off-stand` verbatim (`Rules.OFF_STAND`), because no drive had assigned
  the man a stand. The pace driver works (`<runs-dir>/305-pace.luau` reads back `boarvel=24.00`
  against an asked 24 and crosses the lane) and the aim arithmetic works; the range mat, where the
  gates are relaxed, is the door, and session `9d5b3ff8` had the rig there.
- **STILL NOT PROVEN, named rather than implied**: the lever and the semi-auto;
  buckshot; any HUNT animal (a boar or a deer in a drive) -- every row above is a range target.
  **The shotgun slug is 4/6, which is BELOW the target**, and nothing explains the two shots that
  produced no impact at all. **No frame of any of it has been looked at by this session.**
- **NOTHING HAS BEEN SEEN IN KAREN'S OWN PLACE with both halves on.** Her Forest Test reading is of
  her SHIPPED build, which has neither half: the client draws the running range target **+4.18
  studs AHEAD** (0.174 s in the FUTURE, the ring-based instrument) and **0/10** hits with ballistic
  lead only. Every row in the proof table above is DEV. The Playtester playing her place is what
  closes this, and until then rule 5 is NOT met for this change.
- **`Weapon.stats()` read through an MCP probe is worthless and is quoted nowhere.** `require` in
  that thread hands back a FRESH module whose counters are 0.
