# Task 305 -- a shot hits what the shooter sees

Task: 305
Round: 3
Base: 4130114e (main)
Code commit: 71475766275fc7aa36da3232c324e7e780b6f403

Harness, full suite, clean tree -- **two lines, two commits, because this round's job was to make
each round-2 case FAIL against a broken producer and then pass**:

    [harness] FAIL: 32/34 checks @ 9a996b38466c8fb6f28abefc9fad908e05503f9c (clean tree) scope=all
    [harness] PASS: 34/34 checks @ 71475766275fc7aa36da3232c324e7e780b6f403 (clean tree) scope=all

`agents.needs_two_player` returns **False**. The net diff against `main` touches
`src/server/Weapon/{Rewind,Cast,Flight,init}.luau`, `src/server/RangeBoot.server.luau`,
`src/server/Boar/Body.luau`, `src/shared/Shotgun/init.luau`, `src/shared/Flags/init.luau`,
`tests/server/weapon_rewind.spec.luau` and `tools/studio_mcp.py` -- no `TWO_PLAYER_PATHS` file.
Verify: `git diff --name-only origin/main..HEAD`.

**Round 3 is authorised by the Director** (2026-10-28 11:50 UTC), transcribed verbatim in
`ESCALATE.md` under "Task 305 round 3: Director authorisation". It does three things and nothing
else.

## 1. The two round-2 findings, each now proven to bite (L-093)

`9a996b38` broke BOTH producers on purpose, in one commit, and one full run named both -- and
nothing else:

    failed [server] weapon_rewind.spec:68  Expected value to be near 6.000000 but got 7.000000
    failed [server] weapon_rewind.spec:113 Expected value to be near 0.180000 but got 0.230000
    [tests:server] FAIL: 2485 passed, 2 failed, 0 skipped, 2 errors, 77 spec files

- **:68 is finding 1.** `Rewind.impact`'s selection was broken from nearest-wins to last-wins. The
  case's injected answers now RISE (6 then 7, `distance = 5 + seen`, `seen` incremented above), so
  under a cap of 2 the nearest is the FIRST asked and last-wins gives 7. Round 2's version answered
  9, 8, 7 -- falling -- so the last call was also the nearest and the two rules gave one number.
- **:113 is finding 2.** `Weapon.rewindFor`'s "a failed ping contributes ZERO" was broken to guess
  0.05. The case is one line, `Weapon.rewindFor(nil, nil, CONFIG)`, which is the branch
  `onFireRequest` itself takes (`Weapon.rewindFor(player, nil, CONFIG)`) and which no case entered
  before this round.

`71475766` is `git revert` of that break: `git diff 71475766 a502ccd1 -- src` is **empty**, so
`src/` is bit-for-bit the pre-break state, and the run above is green over it.

## 2. CASE (b) MEASURED FOR REAL -- and it answers the flag question

`reviews/task-305/MEASURED.md` section 4. Ownership fix on (it is in `HEAD`), `AIM_REWIND` **off**
at its shipped default, rifle, 10 real `FireRequest`s per pace aimed at the CLIENT'S OWN rendered
`ZoneChest` plus `Ballistics.leadStuds` alone. Instruments are section 2's own files unchanged
(`305/ft-stand.luau`, `305/ft-pick-run-rifle.luau`, `305/lag-srv.luau`, `305/trial.luau.tpl`) driven
by `<runs-dir>/305b.py`. **DEV ONLY.**

**THE `no-ammo` VOID IS CLOSED**: `notice=` is empty on all 30 lines, because the template already
asks for the reload after every shot and waits 3.2 s.

| run | pace | hits |
|---|---|---|
| (b) ownership on, rewind **off** | run | **0/10** |
| (b) | trot | **1/10** |
| (b) | walk | **0/10** -- and NOT evidence about aim, see below |
| **(d) control, same rig, same session, rewind on** | run | **7/10** (chest x5, rear x2) |

Ownership confirmed live in all four runs off `ft-stand.luau`:
`Boar1 anchored=false auto=false owner=SERVER dist=117.8-123.9`.

**The verdict row is RUN: 0/10 against the control's 7/10, taken minutes later on the same build
with one override changed.** With the rewind off, impacts land BEHIND where the client DREW the
animal -- mean **-1.4 studs** over the six non-outlier run shots -- so the shooter is still asked for
lead he cannot see. With it on, `impact-aim` collapses to **+-0.5 studs on 5 of 7** (both columns are now published in
`MEASURED.md` section 4, after round 3's review found only one of them had been). **And 7/10 is
itself below this task's own >= 8/10 target** -- said on the line, because it is the number the flag
decision rests on.

**So (b) is NOT >= 8/10 at any pace, and I say so plainly: `AIM_REWIND` must NOT stay dark.** The
flag is the Director's call; this is the number he asked for.

## Claims

1. Each round-2 case fails against its own broken producer and passes restored -- the two harness
   lines and the two named spec lines above. Verify: check out `9a996b38` and read the run, then
   `git diff 71475766 a502ccd1 -- src` (empty).
2. `src/` at the code commit is bit-for-bit the state round 2 reviewed plus nothing: the only `src/`
   commits this round are the break and its revert.
3. Case (b) is a real measurement, not void: 30 lines, `notice=` empty on every one.
4. The (d) control is the SAME instrument, the same rig and the same session as (b), one override
   apart -- which is the before/after pair the protocol asks for.
5. The walk row is reported as 0/10 **and explicitly not read as the fix failing**: all ten shots
   produced no impact at all, and the same rows appear in the (d) control at 7-12 studs/s, so it is
   a rig artefact that strikes slow targets in both cases equally.
6. L-141 is honoured: walk and trot do not discriminate (demanded lead 0.21-0.63 studs against a
   ~2-stud error). RUN is the verdict row and is the only one read as one.
7. Nothing else changed. No design edit, no new seam; the round-2 notes stay queued as 305a.
8. `python tools/studio_mcp.py selftest` and `python tools/agents.py selftest` pass at this commit.

ANSWERED: L-136 nothing is called a flake or known -- the only FAIL line in this round is my own
deliberate break, named with its commit beside the green line for the restored commit;
`weapon_shot.spec.luau:1490` did not fire in either run.
ANSWERED: L-127 every item below is MET or NOT PROVEN with its reason on the line.
ANSWERED: L-093 both fixed cases were shown RED against a broken producer BEFORE being called
fixed, in one run that named each and left 2485 others passing.
ANSWERED: Verdict-298 the moving-target hits ARE this round's proof: case (b)'s three paces and the
(d) control, real `FireRequest`s at the client's own rendered chest, in `MEASURED.md` section 4.

## What I could NOT verify (rule 8)

- **NOTHING OF THIS HAS BEEN SEEN IN KAREN'S PLACE.** Every row is `DEV ONLY`. Rule 5 is not met;
  the Playtester in her place is what closes it, and the Director runs that after a PASS.
- **No frame was taken.** `NOT OBTAINABLE` from this session: the probe drives the client VM through
  StudioMCP and the shooter's-eye frame would need `capture` during Play against a target crossing a
  lane; I did not get one and I am not calling the rig a reason.
- **`impact-srv` reads `n/a` on all 30 lines**: `lag-srv.luau`'s ring attribute did not reach the
  client inside the shot window, so the server's own instant of each impact is NOT measured here.
  `impact-drawn` -- this client's own read of what it DREW -- is the column the claim rests on.
- **STILL NOT RUN AT ALL**: the lever, the semi-auto, buckshot, and any HUNT animal (boar or deer in
  a drive). Every row is the range's own target. The shotgun slug's 4/6 from round 2 stands and is
  still below the target.
- **Two outliers are left in the table** (-21.24 studs at run, -13.28 at trot), both taken as the
  target reversed at the lane end; the mean is quoted without them and that is said on the line.
