# Task 265 -- round 3: the replication-lag hypothesis, measured

Task: 265
Round: 3
Base: 670416e6 (main, which includes 264)
Code commit: 16146f74d5570814b4fec11030aa50fce25368c8

`[harness] PASS: 34/34 checks @ 16146f74d5570814b4fec11030aa50fce25368c8 (clean tree) scope=all`
`[harness2]` N/A: **nothing under `src/`, `tests/` or `tools/` changed in this round at all.** The
branch's one code commit is round 2's three-comment fix (`75539a94`), already reviewed; this round
is a measurement and writes only paperwork.

## PLAN (core quality protocol step 0)

- **(a) REAL LIFE.** A shooter leads a running animal by the bullet's flight time and nothing else.
  For this rifle at 131 studs that is **0.052 s** (`Ballistics.timeToRange` on `Rifle.CONFIG`).
- **(b) MEASURED NOW.** The client draws a moving animal **~0.17 s AHEAD** of the server's
  authoritative position: five animals, 1049 matched samples, 0 of them with the client behind, and
  a single time shift of -0.170 s collapses a 4.011-stud gap to **0.098 studs** over 284 samples.
  Probe: `<runs-dir>/265-lagrec.luau` + `265lag.py`.
- **(c) TARGET.** None is set this round: the dispatch says measure and, if the answer is yes, write
  it up rather than fix it. The residual target it names for item 2 (0.5 studs) is not reached
  because item 2 was not obtained.
- **(d) LEVER.** None is moved. Were one wanted it would be `Flight`/`Weapon.onFireRequest`'s
  treatment of target position, not `Ballistics`; the Architect owns that decision and this round
  hands over a measurement, not a prescription.
- **(e) HOW IT IS MEASURED AFTER.** The same probe, `265lag.py`.

**(b) CONTRADICTS THE DISPATCH'S SIGN, so step 0 applies: it is said plainly and this round does not
build on it.** The hypothesis was that the client sees the PAST. It sees the FUTURE, by the same
0.15-0.25 s the hypothesis predicted.

## Claims

1. **CORE -- the view error is real, systematic, and ~0.17 s.** Five animals, 1049 matched samples:
   mean gaps 0.785 / 1.485 / 2.157 / 4.011 / 4.232 studs at speeds 4.5 / 8.4 / 12.0 / 24.1 / 24.1,
   giving 0.167-0.181 s by gap/speed. *Verify:* the table in `<runs-dir>/ledgers/265.md` round 3
   item 1.
2. **And it is a TIME shift, not a constant offset, which is the stronger reading.** A single shift
   of **-0.170 s** reduces Boar42's 4.011-stud gap to **0.098 studs** over 284 samples (-0.175 s and
   0.130 studs for Boar39). A constant positional error cannot be collapsed by a time shift.
   *Verify:* the `best-fit shift` lines; the scan runs over BOTH signs.
3. **The sign is the finding, and it is the opposite of the hypothesis.** The gap is measured ALONG
   the server's own direction of travel and is positive in **1049 of 1049 samples**: the client's
   copy is AHEAD. *Verify:* the `along the direction of travel` line, which prints how many samples
   were behind -- 0 every time.
4. **The two sides cannot borrow each other's answer.** The same recorder runs on the server and on
   the client; each stamps its own reading with `workspace:GetServerTimeNow()`, the one shared
   clock; the comparison happens in Python, outside the game. No attribute carries a position from
   one side to the other. *Verify:* `265-lagrec.luau` -- it reads one part and one clock, nothing
   else.
5. **The metric can read ZERO, which is the control round 2 lacked.** A uniquely named part that
   never moves (`Seg37`) reads **mean 0.000, min 0.000, max 0.000** over 232 samples. *Verify:* the
   control line in the ledger.
6. **Two instrument faults were found and excluded rather than averaged in.** (i) The first static
   control picked `OuterLeaves`, of which this forest has hundreds, and the two VMs resolved
   different trees -- a 5313-stud "gap" that was a name collision; the control now requires a unique
   name. (ii) An animal the probe ANCHORED read a *constant* 5.775-stud gap (min = max), which no
   time shift improves -- an anchored replica that never received the command-bar CFrame write.
   **That control is declared void and is not used.** The moving rows are unaffected: a constant
   offset cannot be collapsed to 0.098 studs by a time shift, and theirs was.
7. **CORE -- item 2 is NOT MET, and the reason is measured.** In this Play session **no click
   produced a `ShotLanded` at all**: `aimshot`'s listener read `shots=0` after a click the guard
   confirmed landed, and `265-shotspy`'s `UserInputService.InputBegan` recorded **0 clicks** across
   six real focused clicks. The `--selftest` could not diagnose it -- by then the drive had moved on
   and it answered `NO VISIBLE TARGET`. **No paired row is offered, and the off-animal row the round-2
   review required is not taken either.**
8. **The verdict does NOT claim the anomaly is explained, and says why.** A client that draws the
   animal AHEAD puts the aim point ahead of the server's body, so the impact should fall toward the
   animal's FRONT; round 1's fell ~3 studs toward its REAR. Either a second effect is present or
   round 1's row is the mispairing this instrument demonstrated (the 19.167-stud spurious
   disagreement). *Verify:* the ledger's round 3 item 3. **Nothing is written to `ESCALATE.md`**,
   because the cure the dispatch names -- rewinding the target to the shooter's view time -- is the
   cure for a client that is BEHIND, and the Architect should be handed the measurement rather than
   a prescription drawn from the wrong sign.
9. **259b is measured as arithmetic and NOT fixed** (dispatch item 4).
   `askLineUnsafe(player, origin, aim, stopAt)` tests from **`origin`** -- on the sight line at the
   shipped `BORE_ON_SIGHT_LINE = true` -- while `safetySignal:Fire(player, aim, muzzle, stopAt)`
   publishes from **`muzzle`**, 0.73 studs across it. `Match.Penalty.judge` measures the driver's
   miss off the PUBLISHED line against `SAFETY_MISS_STUDS = 12` (`src/server/Match/init.luau:121`).
   **So both ways round are possible:** a driver whose distance to the tested line is within 0.73
   studs of the 12-stud boundary can be passed by the lock and then judged unsafe by the penalty, or
   the reverse. The band is widest (0.73 studs) at the muzzle and closes to zero at the aim point.
   *Verify:* the three cited lines. **This is read off the code and its one constant, not off a live
   two-player run** -- `src/server/Match/` is a `TWO_PLAYER_PATH` and no such run was made.
10. **The Forest Test's attributes are identical before and after.** Read with
    `<runs-dir>/attrs-id.luau` before anything and again after the restore:
    `DHFlag_BOAR_BEHAVIOUR=true DHFlag_BOAR_MODEL=true DHFlag_COINS=true DHFlag_DEER_ROAD_LEAP=true
    DHFlag_DRIVE_BOTS=true DHFlag_HORN=true DHFlag_LICENCE_POPUP=true DHFlag_LOBBY=true
    DHFlag_SHOP=true DHForestStartRole=hunter DHShopTestGrant=true`. `DHTestOwns` was set for the
    proof only and is cleared; the probe's anchors are released (`265-free.luau`: `freed 0`, after
    an earlier `freed 1`).

## What could not be verified

- **Item 2 entirely** (claim 7): the paired shot, the residual, and the off-animal row.
- **Why the clicks stopped firing in this session.** Six focused clicks, zero `ShotLanded`, zero
  `InputBegan` records, in a session where the same two instruments worked in round 2. Not
  diagnosed.
- **Round 1's anomaly is still unexplained** (claim 8). This round narrows it -- a 0.17 s view error
  of the right magnitude exists -- and refutes the sign that would have explained it.
- **No frame this round.** Nothing here is a look claim; every number is from two recordings and one
  shared clock. `NOT OBTAINABLE` does not apply -- no frame was called for.
- **Item 4's consequence is arithmetic from the code, not a live reading** (claim 9).
