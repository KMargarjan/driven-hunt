# Task 305 -- a shot hits what the shooter sees

Task: 305
Round: 1
Base: 4130114e (main)
Code commit: 605e1f6d722de6a5c0796a836807c25d80f829b0

Harness, full suite, clean tree:

    [harness] PASS: 34/34 checks @ 605e1f6d722de6a5c0796a836807c25d80f829b0 (clean tree) scope=all

`agents.needs_two_player` returns **False** for this change: no path it touches is in
`TWO_PLAYER_PATHS` (`src/server/Weapon/`, `src/shared/Shotgun/`, `src/shared/Flags/`,
`tests/server/`, `tools/studio_mcp.py`). Weapon, viewmodel, camera, boar, hud, sound and tools need
the one-player line only, for the PR to `main` as well.

**TWO BUILDER SESSIONS WERE DISPATCHED THIS TASK ON THIS BRANCH.** This request covers only the half
committed here (session `5296d523`, `src/server/Weapon/` and the two shared config files). Session
`9d5b3ff8` is landing `part:SetNetworkOwner(nil)` in `src/server/Boar/Body.luau` separately, rebased
on `1eb4c9c4`. `ESCALATE.md` on this branch states why both halves are needed and in which order;
**the Director must read it before merging either.**

## PLAN (core quality protocol step 0)

**(a) REAL LIFE.** At 35 m a .416 reaches a boar in ~0.05 s, so a running boar at 24 studs/s wants
~1.2 studs of lead -- the board's own LEAD BALLISTIC for the rifle: walk 0.22, trot 0.54, run 1.18.
Aiming at the nose of a trotting boar at that range HITS in life. Source:
`docs/research/2026-10-24-real-shooting.md` and `Ballistics.leadStuds`.

**(b) MEASURED NOW.** `<runs-dir>/305lag.py` (the task-265 round-3 recorder `265-lagrec.luau`,
unchanged) in DEV, 2026-10-28, boar at 115 studs:

| part | owner | mean speed | best-fit shift | residual |
|---|---|---|---|---|
| `Boars.Boar1` | server | 2.55 studs/s | **+0.180 s, client LAGS** | 0.011 studs |
| own `HumanoidRootPart`, pushed by its own client | client | 8.69 studs/s | **-0.170 s, client AHEAD** | 0.078 studs |

So the shooter is asked for 0.180 s x the animal's speed on top of the real lead: **4.3 studs at a
run**, which is what Karen aims into.

**(c) TARGET.** Extra lead beyond `Ballistics.leadStuds` = **0 studs**, +-0.63 (one Heartbeat x
38 studs/s, the sampling grid's own quantisation). Not smaller, because the grid cannot resolve it;
not larger, because 0.63 studs is well inside a boar's 0.45 m chest zone.

**(d) LEVER.** `Weapon.Flight.advance`'s one cast call, now handed the shot's own rewind:

    $ grep -n "local impact = cast" src/server/Weapon/Flight.luau
    319:  local impact = cast(pellet.position, segment, shot.ignore, shot.rewindSeconds)

and the amount's writer:

    $ grep -n "FLIGHT_REWIND_BASE_SECONDS" src/shared/Shotgun/init.luau src/server/Weapon/init.luau
    src/shared/Shotgun/init.luau:667:    FLIGHT_REWIND_BASE_SECONDS = 0.18,
    src/server/Weapon/init.luau:    cfg.FLIGHT_REWIND_BASE_SECONDS + seconds * cfg.FLIGHT_CATCHUP_PING_FACTOR,

**(e) HOW IT WILL BE MEASURED AFTER.** The same `305lag.py` for the lag, and the click case
`<runs-dir>/305run.py` + `305-shoot.luau` for the hit rate -- a real `FireRequest` aimed at the
CLIENT'S OWN rendered chest plus `Ballistics.leadStuds` and nothing else.

## Claims

1. **The cause is named in numbers, with a MOVING control.** Research note
   `docs/research/2026-10-28-lag-compensation.md`, section "Measured cause". Verify: run
   `python 305lag.py Boar1 5` and `python 305lag.py HumanoidRootPart 5 walk` from `<runs-dir>` in a
   DEV Play session. The two signs are what defeats the clock-skew confound that sank task 265
   round 3 (Learning Agent L-112): a skew biases both recordings the same way, so it cannot produce
   opposite signs of near-equal size.
2. **`Weapon.Rewind` is pure and owns the arithmetic.** `src/server/Weapon/Rewind.luau`: no
   `Workspace`, no clock, no cast of its own. `Rewind.impact` moves the ray by MINUS the animal's
   displacement and moves the impact back; `Rewind.nearer` gives cover the tie. Verify by reading
   the file and `tests/server/weapon_rewind.spec.luau`.
3. **The world touching is in `Weapon.Cast`, and `Pierce.cast` is still this folder's only ray.**
   `Cast.candidates` uses `GetPartBoundsInRadius` (a bounds query, not a ray); `Cast.only` uses
   `Pierce.cast` with an Include filter, which task 280 round 1 proved is not optional for a
   `ZonesOnly` animal. Verify: `grep -rn "Pierce.cast|Workspace:Raycast" src/server/Weapon/`.
4. **`Flight` carries the rewind and reads it never.** `ShotRecord.rewindSeconds` is carried like
   `claim` and `bore`; the only use is the cast's fourth argument. Verify:
   `grep -n "rewindSeconds" src/server/Weapon/Flight.luau` -- the field and the call, nothing else.
5. **The flag is read ONCE, at the owner's boundary, and passed inward.** `REWIND_ON =
   Flags.isOn("AIM_REWIND")` in `src/server/Weapon/init.luau`; `Weapon.rewindFor` returns 0 when the
   flag or `rewindPolicy` says off, the shot then carries 0, and `resolvedCast` is
   `castFn(origin, direction, ignore)` and nothing else runs. Verify: `grep -rn "AIM_REWIND" src/`
   finds the row and that one boundary.
6. **Both states are reachable by parameter.** `Weapon.setRewindPolicy(true/false/nil)`, exercised
   in `weapon_rewind.spec.luau` at both values while the row sits lit.
7. **The amount is the measurement and is NOT `CLAIM.VIEW_LAG_BASE_SECONDS`.**
   `FLIGHT_REWIND_BASE_SECONDS = 0.18`; its comment says why 0.30 would be wrong here (a window a
   sweep searches versus an amount -- 0.30 would over-rewind by 0.12 s, 2.9 studs at a run, in the
   other direction). `Weapon.rewindFor` caps at `CLAIM.VIEW_LAG_MAX_SECONDS`, contributes zero for a
   negative, a NaN or a missing ping, and is tested at five ping values.
8. **The flag ships LIT, by the Director's own sentence, and that is on the record.** The dispatch of
   2026-10-28: *"If the fix needs a flag, it is born ON for the range (the range is a training
   place) -- say so"*. `Flags.MAX_FLAGS` 19 -> 20 with the reason written above the line, the shape
   every previous cap move used.
9. **The new spec is in a scope.** `tools/studio_mcp.py` `SCOPE_SPECS` gains
   `tests/server/weapon_rewind.spec.luau` under the weapon scope; `python tools/studio_mcp.py
   selftest` and `python tools/agents.py selftest` both pass (run, 2026-10-28).
10. **Lint, format and build are clean at the code commit.** `selene src`,
    `selene --config tests/selene.toml tests`, `stylua --check src tests`, `rojo build`.

## What I could NOT verify (rule 8)

- **THE CLICK PROOF DID NOT RUN, so >= 8/10 per pace per gun is NOT PROVEN and no frame was taken.**
  The DEV arena refuses the request before anything is cast: the client probe's `StateChanged`
  listener caught `REFUSED off-stand` verbatim (`Rules.OFF_STAND`), because no drive had assigned
  the man a stand. The pace driver itself works -- `<runs-dir>/305-pace.luau` reads back
  `boarvel=24.00` against an asked 24 and crosses the lane -- and the aim arithmetic works, but no
  shot flew. Session `9d5b3ff8` holds the live rig on the range mat, where the gates are relaxed,
  and is running the four-case matrix (pin off/on x rewind off/on); its rows are not in this round.
- **Nothing here was measured in Karen's place by this session.** Session `9d5b3ff8` reports, on her
  own path in her Forest Test, her build: shipped auto-ownership = the client draws the running
  range target **+4.18 studs ahead** (0.174 s in the FUTURE) and **0/10** hits with ballistic lead
  only; with `SetNetworkOwner(nil)` applied live = **-4.74 studs** (0.213 s in the PAST), still 0/10
  because her build has no rewind. Attributed to that session, not re-measured here.
- **A first reading of `Weapon.stats()` through an MCP probe was worthless and is quoted nowhere.**
  `require` in that thread hands back a FRESH module whose counters are 0, so an early run read
  `shots=0` for shots that may have flown. Every number above is an instance fact or a recording,
  never module state.
