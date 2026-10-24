# Task 251c: every group starts ahead of the beaters, and the stag has time to sneak

Task: 251c
Round: 1
Base: main @ 1316e023 (task 251 parts 1 and 2 merged)
Code commit: e5a5bd955499b6dfab56e46f1cf6c828bfb0982c

`[harness] PASS: 34/34 checks @ e5a5bd955499b6dfab56e46f1cf6c828bfb0982c (clean tree) scope=all`

`test2` is N/A: no `TWO_PLAYER_PATHS` file is touched (`src/server/ForestTest/`,
`src/shared/ForestTest/`, `tests/server/forest_line.spec.luau`).

## What changed

The Director answered part 2's escalation (*"ACT III ... IS RELEASED BEHIND THE ADVANCING BEATER
LINE"*) with two rules: a slot's start depth is relative to the line, and the stag is released early
enough to walk his route. Both are built. The Forest Test proof is in `ESCALATE.md` (2026-10-24,
task 251c) and `<runs-dir>/251c-console1.txt`, `251c-console2.txt`, `251c-stag-track.txt`.

## Claims

1. **A slot is released at `min(its table depth, the line's depth - leadStuds)`, floored.**
   `ForestTest.releaseDepth` in `src/shared/ForestTest/init.luau` is the whole rule and is pure;
   `SCHEDULE.leadStuds` (60) and `SCHEDULE.minNorthStuds` (25) are the two data rows.
   Verify: the function, and the case *"clamps a slot's depth to stay ahead of the line, and never
   deeper than the row"* in `tests/server/forest_line.spec.luau`.

2. **The line's depth is MEASURED at the moment of release, at that row's own x, off the beaters'
   bodies** (Learning Agent L-024). `ForestTest.lineNorthAt` in `src/server/ForestTest/init.luau`
   reads `realBeaters()` through `Data.lineFrontAt` and subtracts `roadZ` at that x; `releaseLine`
   calls it and nothing precomputes or estimates it.
   Verify: `lineNorthAt`, and its one call site in `releaseLine`.

3. **Every route word hands in its own floor** so the clamp cannot break the rows it was meant to
   save: a sneak may not start shallower than its treeline band, a refusal may not start inside its
   own `turnAtDz`, and the one that HOLDS may not be put where lying up after `holdStuds` would leave
   it across the road. `ForestTest.routeFloor`.
   Verify: `routeFloor`, and the `Data.routeFloor` assertions in the same spec case as claim 1.

4. **The stag moved from slot 13 to slot 8 and the refusal that was at slot 8 took slot 13 -- a
   SWAP**, so every release time in the fifteen-slot grid is untouched (the Director's *"keep the
   other slots' release times"*) and, both rows being `keepAt = 13`, no column of the dial's table
   moves at any density. The arithmetic for slot 8 is in his row's comment.
   Verify: the two rows in `SCHEDULE.drive`, and the counts case
   (*"answers Karen's counts at the dial she OK'd"*) still asserting 13 groups / 10 crossings /
   2 refusals / 1 hold / 2 deer groups.

5. **He reaches the verge in act III, before the line arrives, with a margin.** Released at 101 s
   with the line at dz 267 (flat) he starts at dz 207 and his route is `north + sneakStuds` = 327
   studs, 73 s at `PACE.WALK_SPEED`, so he is at the verge at 174 s against a line that reaches the
   road at 187 s flat / ~202 s on the measured ground factor.
   Verify: the case *"releases every slot ahead of the line at its own time, and the stag early
   enough to WALK"*, which computes it from `Bots.CONFIG.WALK_SPEED`, `Data.beaterNorthStuds()` and
   `Boar.CONFIG.PACE.WALK_SPEED` rather than from any number written twice.

6. **Every slot of the script is released ahead of the line at its own release time**, and the two
   exceptions are named rather than asserted away: slots 12-14 are ahead but inside the 60-stud
   margin (they take their own route floors), and slot 15 -- which holds and never comes -- is due
   after the men are through. Same case as claim 5.
   Verify: the `through` and `tight` lists at the end of it.

7. **A line at or past the road is not a line** (`lineNorth <= 0` -> the table's own depth). MEASURED:
   the first live run released the repeat window's groups at the 25-stud floor ON THE VERGE
   (*"SLOT 17 ... from dz 25 of 170, line at dz -9"*); after the fix the same slot read *"from dz 170
   of 170, line at dz -9"*.
   Verify: the guard in `releaseDepth`, its three cases in the spec, and the two console lines in
   `<runs-dir>/251c-console1.txt` and `251c-console2.txt`.

8. **The repeat window never repeats the stag.** Its exclusion of him used to be positional (he was
   slot 13 and the window is `repeatFrom` 6 .. `repeatTo` 12); slot 8 is inside it, so the rule is
   stated in `slotAt` instead. Slot 18 of a long drive mapped to his row.
   Verify: `slotAt`'s repeat branch, and the case *"never repeats the stag, however long the drive
   runs"*.

9. **The Forest Test proof, read-only.** Two full drives on Karen's path; the place's attributes were
   read before (`<runs-dir>/attrs-id.luau`) and after and are identical, nothing was written, and the
   Forest Test window was closed before the harness ran (the harness log says DEV). Fourteen of the
   fifteen slots were released ahead of the line, against none of act III before this task.
   Verify: `ESCALATE.md`'s table, `251c-console2.txt`.

## What I could NOT verify, and it is escalated

**The stag still does not walk, and the frame of him at the verge does not exist.** Tracked by
instance every 0.5 s he was in `MOVE.SPRINT_SPEED` within 1.5 s of release and over the road 7 s
later, with no 2-6 s stop, no yaw reversal and no leg along his sneak band. The cause is measured and
is a radius in another system: `ForestTest.noticeAheadStuds` is 100 studs and `leadStuds` is 60, so a
clamped group is spawned 40 studs INSIDE the line's notice band and `SPOOK.ALERT_SECONDS` = 2 ends the
stand whatever the line does. The arithmetic for every lead that could fix it, and five options, are
in `ESCALATE.md` (2026-10-24, task 251c). **No screenshot of him at the verge is claimed, because
there is nothing to photograph.**

Also from the run, and also in `ESCALATE.md`: his release TIME is not fixed either --
`MAX_GROUPS_ALIVE` is 1, so the hind party held him over to slot 10 (127 s) in drive 2.

The client gate failed once on `tests/client/camera_client.spec.luau` and passed on the next run with
no change; that case is the known flake of this branch lineage (TASKS.md 251c(f), 4 of 6 runs). This
branch changes no client file (`git diff --name-only main..HEAD` is three files, none under
`src/client/` or `tests/client/`).
