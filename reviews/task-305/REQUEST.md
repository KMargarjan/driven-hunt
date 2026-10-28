# Task 305 -- a shot hits what the shooter sees

Task: 305
Round: 2
Base: 4130114e (main)
Code commit: bbba8b40

Harness, full suite, clean tree:

    PENDING -- see "What I could NOT verify". The DEV Studio is held by the other Builder session
    for its live matrix; this line is run and pasted the moment it is handed back.

`agents.needs_two_player` returns **False**: none of the paths this diff touches is in
`TWO_PLAYER_PATHS` (which holds only `src/server/Match/`, `src/server/MatchBoot.server.luau`,
`src/client/Match/`, `src/client/MatchBoot.client.luau`, `src/shared/Drive/`, `tests/client/Role.luau`
and eleven named specs). The diff touches `src/server/Weapon/`, `src/server/MatchBoot.server.luau`,
`src/server/ForestTestBoot.server.luau`, `src/server/RangeBoot.server.luau`, `src/shared/Shotgun/`,
`src/shared/Flags/`, `tests/server/` and `tools/studio_mcp.py`.

**NOTE -- `src/server/MatchBoot.server.luau` IS in `TWO_PLAYER_PATHS` and round 2 touches it** (three
lines: the history provider is chained instead of replaced). So this round DOES need the
`[harness2]` line as well, and round 1 did not. Both are pending with the Studio.

**TWO BUILDER SESSIONS ARE ON THIS BRANCH.** This request covers only this session's half
(`5296d523`). Session `9d5b3ff8` lands `part:SetNetworkOwner(nil)` in `src/server/Boar/Body.luau`
separately. `ESCALATE.md` says why both halves are needed and in what order; **the Director must
read it before merging either.**

## What round 2 changed, finding by finding

1. **`Weapon.castWithRewind` -- an animal with no history was in NEITHER pass and the bullet went
   through it.** The root is now inserted into `staticIgnore` only inside the accepted branch, and an
   empty candidate list returns `castFn(origin, direction, ignore)` untouched. `cframeAt` answers
   nil for four ordinary states and one of them was **every shot on the range**: `RangeBoot` builds
   its own `Boar.newRuntime` and the single provider seam held only the drive's. So
   `Weapon.setHistoryProvider` now RETURNS the provider it replaced (the shape `setClaimPolicy`
   has) and all three composition roots CHAIN -- `MatchBoot`, `ForestTestBoot`, `RangeBoot` -- which
   is what a lobby with two runtimes needs. Verify:
   `grep -n "previousHistory" src/server/*.luau` (three sites, same shape).
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
   (`expect(Rewind.nearer(tieStatic, tieRewound)).to.equal(tieStatic)`). The nearest-candidate case
   now says why 9/8/7 under a cap of 2 also refuses last-wins.

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
   `CLAIM.VIEW_LAG_MAX_SECONDS`, zero for a negative, a NaN or a missing ping. The `nil`-ping branch
   (the one `onFireRequest` itself takes) is now covered too.
8. **The range gets the rewind.** `RangeBoot` chains its own runtime's `cframeAt` onto whatever the
   drive's boot installed; without it the range had none, which was finding 1's live consequence.
9. **The new spec is in a scope**, and both selftests pass (`tools/studio_mcp.py selftest`,
   `tools/agents.py selftest`, run at this commit).
10. **Lint, format and build are clean at the code commit**, and CI is green on it
    (run 40674420086, success).

## What I could NOT verify (rule 8)

- **THE GATE LINES ARE PENDING.** The DEV Studio is held by session `9d5b3ff8` for its live matrix,
  and `python tools/studio_mcp.py test` needs Edit mode and refuses to start while a flag override
  is set. Round 2 also touches `src/server/MatchBoot.server.luau`, which IS a two-player path, so it
  needs `[harness2]` as well -- a human click. Neither line is faked and neither is in this file.
- **THE CLICK PROOF STILL DID NOT RUN IN THIS SESSION, so >= 8/10 per pace per gun is NOT PROVEN and
  no frame was taken.** In the DEV arena the request is refused before anything is cast: the client
  probe's `StateChanged` listener caught `REFUSED off-stand` verbatim (`Rules.OFF_STAND`) because no
  drive had assigned the man a stand. The pace driver works (`<runs-dir>/305-pace.luau` reads back
  `boarvel=24.00` against an asked 24 and crosses the lane) and the aim arithmetic works; no shot
  flew. Session `9d5b3ff8` holds the rig on the range mat where the gates are relaxed.
- **Nothing of this change has been seen on screen, in any place.** Round 1's note said so and it is
  still true. The only live numbers quoted here are the two `305lag.py` recordings and session
  `9d5b3ff8`'s mat readings of **her shipped build, which has no rewind**: auto-ownership = the
  client draws the running target +4.18 studs ahead (0.174 s in the FUTURE), 0/10 hits with
  ballistic lead only; with `SetNetworkOwner(nil)` live = -4.74 studs (0.213 s in the PAST), still
  0/10. Attributed to that session, not re-measured here. **Every core item is NOT PROVEN until a
  shot is seen to land on a running animal aimed at the drawn chest plus `Ballistics.leadStuds`.**
- **`Weapon.stats()` read through an MCP probe is worthless and is quoted nowhere.** `require` in
  that thread hands back a FRESH module whose counters are 0.
