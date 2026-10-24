# Task 253: the stag sneaks away from the beaters instead of bolting

Task: 253
Round: 1
Base: main @ 1316e023 (task 251 parts 1 and 2 merged)
Code commit: f03af027b7e14fd18b8365778d8f29a24595f669

`[harness] PASS: 34/34 checks @ f03af027b7e14fd18b8365778d8f29a24595f669 (clean tree) scope=all`

`test2` is N/A: no `TWO_PLAYER_PATHS` file is touched (`src/shared/ForestTest/`,
`src/server/ForestTest/`, `src/server/Boar/`, `tests/server/`).

**This task is task 251c renumbered** at the Director's instruction (the 233b -> 235 precedent), so
the clamp that releases every group ahead of the beater line is part of it: claims 1-4 are that work
(reviewed by nobody yet), claims 5-9 are the three rules the Director added on 2026-10-24.

## Claims

1. **A slot is released at `min(its table depth, the line's depth - leadStuds)`, floored.**
   `ForestTest.releaseDepth` (pure) is the rule; `SCHEDULE.leadStuds` and `minNorthStuds` are the two
   data rows. Verify: the function, and the case *"clamps a slot's depth to stay ahead of the line,
   and never deeper than the row"* in `tests/server/forest_line.spec.luau`.

2. **The line's depth is MEASURED at release, at that row's own x, off the beaters' bodies**
   (L-024): `ForestTest.lineNorthAt` -> `Data.lineFrontAt(realBeaters(), x)` - `roadZ(x)`, called by
   `releaseLine`. Nothing precomputes or estimates it. Verify: the function and its one call site.

3. **Every route word hands in its own floor** (`ForestTest.routeFloor`): a sneak may not start
   shallower than its treeline band, a refusal inside its own `turnAtDz`, or the one that HOLDS where
   lying up after `holdStuds` would leave it across the road. Verify: the function and its cases.

4. **A line at or past the road is not a line** (`lineNorth <= 0` -> the table's own depth), and
   **the repeat window never repeats the stag** (his slot moved inside it, so the exclusion is a rule
   in `slotAt` now). Both were found by a live drive. Verify: the guard, the `slotAt` branch, their
   two cases, and in `<runs-dir>/253-PROOF.md` the line `SLOT 17 ... from dz 170 of 170, line at dz
   -827`.

5. **For a DEER kind, noticing the line is not a flush.** `ForestTest.encounterStage` gains an
   `isDeer` argument and a fourth answer, `"sneak"`: everything that flushes a boar -- the sweep
   band, the flush circle, the alert clock -- answers "sneak" for a deer while the nearest beater's
   BODY is further than `SPOOK.DEER_FLUSH_STUDS` (40). A sneak is the drive doing nothing: the animal
   keeps walking the route it was given. Inside 40 studs it bolts as before, and so does a boar at
   any distance.
   Verify: `encounterStage`, the case *"lets a DEER slip away at a walk where a boar would bolt, and
   bolts it when a man is close"* in `tests/server/forest_stand.spec.luau`, and `spookNearBeaters`'s
   `sneak` branch -- which does nothing, does NOT latch (so the next tick can still bolt it), and
   counts.

6. **`SCHEDULE.leadStuds` 60 -> 130, because 60 was inside two of the line's own reaches.**
   `noticeAheadStuds` is 100 and `BEATER_STUDS` is 71. Verify: the row, and the case *"orders the
   three reaches so a deer is pressed closer than a boar and noticed furthest out"*, which asserts
   `DEER_FLUSH_STUDS < BEATER_STUDS < NOTICE_STUDS` and `noticeAheadStuds < leadStuds` rather than
   any of the numbers.

7. **The stag is released though another deer group is alive, because he moves alone.**
   `Boar.deerGroupsAllowed(liveKinds, config, party)` raises the cap by
   `RELEASE.LONE_PARTY_EXTRA_GROUPS` when the named party's own composition weighs
   `LONE_PARTY_SIZE`; `Runtime:deerAllowed(party)` passes it through and `releaseLine` names
   `row.party`. It is "a party of one" and not "the stag", so the rule reads off the table.
   Verify: the function, the rows, and the assertions added to *"answers the live cap through one
   door"* in `tests/server/deer.spec.luau` (the hinds are still refused; a second stag is refused).

8. **`Boar.isDeerKind` is the one answer to "is this kind a deer"**, asked of the live config.
   Verify: the function and its case in `deer.spec`.

9. **THE PROOF, in Karen's place, read-only.** `<runs-dir>/253-PROOF.md` with the two tracks
   (`253-stag-track-A.txt`, `253-stag-track-B.txt`) and the consoles. Attributes read before and
   after, identical; nothing written; the Forest Test window closed before the harness, which logged
   DEV. **Run A: 39 seconds of walking and a 90-stud treeline sneak at `PACE.WALK_SPEED`** (dz holds
   81-85 while x runs 2880 -> 2970), against the same animal in `MOVE.SPRINT_SPEED` 1.5 s after
   release on the pre-task commit. **Run B: the edge check at the verge -- he stops dead at dz 57 and
   swings his head -176 <-> -132 degrees for 4.1 seconds**, inside the stag's own 2-6 s band, then
   crosses. Every slot's release depth against the line's own depth at that moment is the table in
   section 1 of the proof.

10. **The new cases fail on the pre-253 source** (L-028), and that was RUN rather than reasoned:
    with `src/` stashed and the specs in place, `[harness] FAIL: 32/34 ... (DIRTY TREE ...)` with
    `2197 passed, 6 failed, 6 errors` at `deer.spec:1102`, `deer.spec:1128` (*"attempt to call a nil
    value"* -- `Boar.isDeerKind`), `forest_line.spec:808`, `forest_line.spec:861`,
    `forest_stand.spec:2039` and `forest_stand.spec:2075` (*"attempt to call a nil value"* --
    `Data.deerFlushStuds`).

## What I could NOT verify

* **No single drive shows the walk, the sneak AND the edge check together**, and neither bolt in
  between is unexplained: run A's is a beater inside 40 studs at the end of the twenty-second sneak,
  run B's is the hand horn (*"horn blown at (3034,142,-2101): 14 boar(s) pushed within 357 studs"*,
  with the line 122 studs behind him at that moment). Both are the Director's rule firing as written.
* **The frame of him at the verge at eye height was not obtained.** `ftplay.py capture` passes a
  camera and a look-at, and **in Play StudioMCP renders the PLAYER's own camera and ignores them** --
  the three frames taken (`253-stag-1.png`, `253-verge-1..3.png`) are all the hunter's own first-
  person view from the stand at eye height, and the stag is not identifiable in any of them. The fix
  is one client probe that points the player's camera at him before the capture; it needs another
  Play run and the session is already over its box. The behaviour is evidenced by the 0.5 s track
  instead, which is what a frame could only corroborate.
* The one-per-animal console ration is proved by run B's single line; run A is what measured the
  1,676.
