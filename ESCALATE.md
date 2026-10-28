# ESCALATE -- Task 305, 2026-10-28 12:20 UTC (deadline 12:25)

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
- `9d5b3ff8`'s one line -- `part:SetNetworkOwner(nil)` in `Boar.Body.create` -- makes the server the
  only simulator at every distance. It does **not** remove the lag; it makes it one-signed.
- this session's commit `605e1f6d` -- the server resolves the shot against the animal **where the
  shooter drew it**, 0.180 s back, measured -- removes that remaining one-signed lag, for every
  weapon, on the range and in the hunt. **With auto-ownership still on it is WRONG for a shooter
  standing next to the animal**, because it would rewind a server copy that is already behind.

**Director decision needed: land `SetNetworkOwner(nil)` FIRST, then re-measure `305lag.py` at 115
studs AND on the mat.** If both then read ~+0.18 s with one sign, `605e1f6d` is the second half and
`FLIGHT_REWIND_BASE_SECONDS` is re-fitted to whatever that re-measurement says. If pinning ownership
alone brings the required lead to the ballistic lead, this commit's flag `AIM_REWIND` is turned OFF
and the row retired. **It is behind a flag precisely so this is one line either way.**

## 2. NEEDS DIRECTOR: THE CLICK PROOF DID NOT RUN. The code is NOT proven on screen.

`<runs-dir>/305run.py` + `305-shoot.luau` (a real `FireRequest` aimed at the CLIENT'S OWN rendered
chest plus `Ballistics.leadStuds` and nothing else) got as far as firing and `Weapon.stats().shots`
stayed **0** -- the DEV arena refused every request, almost certainly because the drive is not open
in the lobby phase (`driveOpenProvider`). Not diagnosed; the session ran out of clock.
**So: `>= 8/10` per pace per gun is NOT PROVEN, the fail-first is NOT PROVEN, and no frame was
taken.** Per V280 this is written at the stop, not worked around.

## 3. No review round was run. `reviews/task-305/` has no REQUEST.md and no verdict.
