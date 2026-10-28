# ESCALATE -- Task 305, 2026-10-28 (written ~10:20 UTC, amended ~11:00 UTC; deadline 12:25 UTC)

**CORRECTION TO THIS FILE'S OWN HEADER.** It first read "12:20 UTC", which was an estimate of
elapsed time and not a reading -- `date -u` said 10:22 immediately after it was written. V283: never
state a time from memory. The two amendments below are stamped from `date -u`.

## 1. TWO BUILDERS WERE ON THIS BRANCH AND THEIR TWO MEASUREMENTS ARE BOTH RIGHT. THE DIRECTOR MUST COMBINE THEM.

Session `5296d523` (this one) and session `9d5b3ff8` were both dispatched task 305 on
`task-305-aim-what-you-see`. We measured the same defect from two distances and got **opposite
signs**, which is itself the finding:

| who | place | shooter -> animal | reading |
|---|---|---|---|
| this session, `<runs-dir>/305lag.py` | DEV, boar at **115 studs** | far | client draws the animal **+0.180 s IN THE PAST** (residual 0.011 studs); own client-owned part **-0.170 s in the future** |
| session `9d5b3ff8` | Karen's Forest Test range + DEV | **near / on the mat** | client draws the animal **AHEAD** of the server by 4.00 studs at 24.8 studs/s (0.159 s); `GetNetworkOwner()` reads `SERVER` at 134 studs and **the PLAYER once he is on the mat** |

**The cause of the unlearnable lead is that `Boar.Body.create` leaves the trunk unanchored with
`GetNetworkOwnershipAuto()` true, so the engine hands the animal to the nearest player.** Near the
animal the CLIENT simulates it and the server's copy trails; far from it the server owns it and the
CLIENT's copy trails. **The sign of the required lead therefore flips with distance**, which is
exactly Karen's *"aiming is off"*.

**Neither fix alone is right, and they do not conflict:**
- `9d5b3ff8`'s commit `97d67896` -- **re-pinning the trunk in `Boar.Body.attachVisual`**, not in
  `Body.create`. **This file first named `create` and that was wrong**: `Body.create` already calls
  `trunk:SetNetworkOwner(nil)` and has for some time; `attachVisual` then welds the drawn mesh into
  the assembly, the assembly is rebuilt, and ownership reverts to AUTO
  (`GetNetworkOwnershipAuto()` read true on every live animal in both places). That is why the
  engine hands a near animal to the nearest player. It does **not** remove the lag; it makes it
  one-signed.
- this session's commit `605e1f6d` -- the server resolves the shot against the animal **where the
  shooter drew it**, 0.180 s back, measured -- removes that remaining one-signed lag, for every
  weapon, on the range and in the hunt. **With auto-ownership still on it is WRONG for a shooter
  standing next to the animal**, because it would rewind a server copy that is already behind.

**Director decision needed: land `SetNetworkOwner(nil)` FIRST, then re-measure `305lag.py` at 115
studs AND on the mat.** If both then read ~+0.18 s with one sign, `605e1f6d` is the second half and
`FLIGHT_REWIND_BASE_SECONDS` is re-fitted to whatever that re-measurement says. If pinning ownership
alone brings the required lead to the ballistic lead, this commit's flag `AIM_REWIND` is turned OFF
and the row retired. **It is behind a flag precisely so this is one line either way.**

## 1b. AMENDMENT, 2026-10-28 ~11:00 UTC: BOTH HALVES ARE NOW MEASURED TOGETHER AND IT WORKS.

`reviews/task-305/MEASURED.md` (session `9d5b3ff8`) holds the four cases, rifle at the range's run
pace, 10 real `FireRequest`s each aimed at the CLIENT'S OWN rendered chest plus the ballistic lead
alone: **(a) both halves dark 0/10, (c) rewind alone 0/6, (d) both halves on 10 hits in 11 shots
that flew** (chest x6, body x4; 6 for 6 at pace >= 15 studs/s; impacts 0.02-0.15 studs from the aim
point). Case (b) is void -- 9 of 10 refused `no-ammo`. Case (c) is ALSO the live proof of round 1's
finding 1, caught geometrically: the shot crossed 0.05 studs from the chest and carried on to the
berm. **Still NOT PROVEN: walk and trot, the lever, the semi-auto, buckshot, and any hunt animal.**

## 2. NEEDS DIRECTOR: THE CLICK PROOF DID NOT RUN IN *THIS* SESSION. (Session `9d5b3ff8`'s did; see 1b.)

`<runs-dir>/305run.py` + `305-shoot.luau` (a real `FireRequest` aimed at the CLIENT'S OWN rendered
chest plus `Ballistics.leadStuds` and nothing else) got as far as firing and `Weapon.stats().shots`
stayed **0** -- the DEV arena refused every request, almost certainly because the drive is not open
in the lobby phase (`driveOpenProvider`). Not diagnosed; the session ran out of clock.
**So: `>= 8/10` per pace per gun is NOT PROVEN, the fail-first is NOT PROVEN, and no frame was
taken.** Per V280 this is written at the stop, not worked around.

## 3. Review rounds, as of ~11:00 UTC: round 1 returned FINDINGS (four, all fixed in `bbba8b40`);
round 2 is being run. **The dispatch caps this task at 2 rounds** -- findings on round 2 means this
file gets another entry and the Builder stops.
