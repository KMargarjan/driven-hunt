# Task 321 -- one pass, one animal

Task: 321
Round: 2
Base: d7ae1929 (main)
Code commit: 5bdf5a37c128c8d270ad8fa6d79f3705350af3a0

`[harness] PASS: 34/34 checks @ 5bdf5a37c128c8d270ad8fa6d79f3705350af3a0 (clean tree) scope=all`

`[harness2] PASS: 36/36 checks @ 5bdf5a37c128c8d270ad8fa6d79f3705350af3a0 (clean tree)`

**Director, 2026-11-01 ~00:05 UTC:** both lines run with DEV the only Studio (Karen's Forest Test closed in Edit). The code commit is the branch head; after the Builder's code commit 0fcb2929 only `ESCALATE.md`, `TASKS.md` and this request changed. `deer_hitbox.spec` passed in this run. The Builder's three one-player FAILs below were all taken with the Forest Test open beside DEV, and are kept as its record.

The Builder's runs, with the Forest Test open:

- **one-player:** FAIL 32/34 **three times**, on `deer_hitbox.spec` and nothing else. Every one of the
  three is the **calf**, and every one is a flank ray that **answered `nil`** -- it hit nothing:
  `:659` *"calf: legs box 1 is unreachable by a flank ray"* (run 2), `:682` the same (run 1, as
  quoted), `:659` *"calf: the skull at (0.01, 1.50, -1.02) answered nil, wanted head"* (run 3, at
  `7923cc7a`). This branch touches no deer, boar or hitbox file, and `deer_hitbox.spec` names `Range`
  **zero times**; it loads its models at runtime through `ServerStorage.Assets.Loader`, and a ray that
  hits nothing is the signature of a model that has not finished loading.
  It PASSED in the three earlier runs of this session, all of which ran while DEV was the only
  Studio, and has failed in all three runs since Karen's second editor appeared. That is a
  CORRELATION plus a plausible mechanism, **not a control run** -- the control at the merge-base is
  the Director's to run, and no claim here rests on calling it a flake.
  (Run 3's line names `7923cc7a`, the paperwork commit: at-or-after the last code change with only
  paperwork after it, so if the Director uses that line, `Code commit:` above reads `7923cc7a`.)
- **two-player:** required (`src/client/Range/` and `tests/client/range_mask.spec.luau` are in
  `TWO_PLAYER_PATHS`). `test2` at this commit reached the click and timed out:
  `FAIL A 2-player local test appeared within 180 s (0 new studio(s) beside the editor)` then
  `[harness2] NEEDS KAREN: nobody pressed Start.` The no-human route is `<runs-dir>/run-test2.sh`,
  which **refuses at its own first line** while more than one Studio is open
  (`REFUSED: n studios open before the run`). Not worked around (V280).

## What changed -- the three blocking findings of `reviews/task-321/RESULT.md`, and nothing else

1. **A carcass is a body, and the shot's door now says so (finding 1).** `Range.ignoredFor` looped
   `trial.targetId` only, and task 321 moves a dead animal onto `trial.carcassId` for
   `CARCASS_SECONDS` -- so for three seconds a neighbour's corpse, which `Mask` hides from him,
   stopped his bullet and `Range.onHitReported` scored it as his hit. One local `door` closure in
   `Range.ignoredFor` now carries ONE rule for both bodies, and is called for `trial.targetId` and
   for `trial.carcassId`. `positionOfId` -- the old `targetPositionOf` generalised by id, which still
   wraps it for `Range.gapStuds` -- reads either body off the same history ring, so a carcass's door
   is judged where it is drawn.
   **HIS OWN CARCASS: shootable while it is inside his own window, ignored once it leaves** -- the
   live target's own rule, and not a new one. That is what the picture does: `Range.mineIdsFor` puts
   his carcass in `Mask`'s "mine", and `Mask.wantedFor` draws a mine trunk exactly while
   `RangeData.inWindow` holds. The door and the picture ask the one question, which is what
   `src/shared/Range/init.luau`'s `sightSpanFor` header requires.
   **Verify:** `range.spec` "hides a carcass exactly as it hides a live target, his own one included"
   -- a station-2 carcass moved to the centre of station 3's own span, asserted present in
   `Range.ignoredFor(man)` and in the rewound `Range.ignoredFor(man, 0.2)`, and asserted to be a
   different Instance from station 2's new target; then his own carcass at that same centre asserted
   ABSENT, and two studs outside his west edge asserted present.
2. **The server half of the mask fix now dies when its producer is deleted (finding 2).**
   `range_mask.spec` hands the ids to `Mask.setMine` by hand, so `Range.mineIdsFor` and `copy.mineIds`
   in `Range.recordOf` could both be deleted with the suite green. No `src/` change: the fix is a case
   that reads the ids **off the payload**, through a fake `RangeBoard`.
   **Verify:** `range.spec` "names his animal's id on the wire, and after a kill both ids" --
   `sent[#sent].record.mineIds` contains the live animal's id and NOT station 1's, the trunk's `Name`
   is asserted to BE that id (which is what the client resolves on its own sweep), and after a kill
   the payload carries BOTH the carcass id and the fresh target's.
3. **A man at a station is published to with no request at all (finding 3).** The round-1 cases
   asserted `#sent >= 1` AFTER an `onRequest`, which publishes by itself, so both halves of (e) could
   be deleted and they stayed green. No `src/` change: the fix is a case with ONE man in the players
   list, NO request, and one scan tick.
   **Verify:** `range.spec` "tells a man standing at a station which animal is his before he asks
   anything" -- `#sent == 0` and `Range.recordOf(him) == nil` first, then after `2 / STEP_HZ` the
   payload went to HIM, `record.spot == 4`, and `record.window.minX` is station 4's and not station
   1's default.
4. **The request's false description of finding 3's proof is corrected.** Round 1 said: `range.spec`
   "tells every man at the range" cases; `#sent >= 1` before any request. No case of that name exists
   and both assertions came after a request. What each spec proves is stated per item above, in the
   words of the case's own title.

## FAIL FIRST -- every case run red, and at which commit

Three real harness runs, each naming the case it covers:

| case | mutation | run | red at |
|---|---|---|---|
| 1 | `src/server/Range/init.luau` at the round-1 code commit (`adbec7a0`), new specs in place | `FAIL 32/34 (DIRTY TREE (1 paths))`, 1 failed / 1 error | `range.spec:4145` -- `expect(has(Range.ignoredFor(man), carcass2)).to.equal(true)` got **false**: the neighbour's carcass was in nobody's ignore list |
| 2 | fix in place, `copy.mineIds = Range.mineIdsFor(player)` deleted from `Range.recordOf` | `FAIL 32/34 (DIRTY TREE (2 paths))`, 2 failed / 2 errors | `range.spec:4383` via `idsOf` at `:4373` -- `mineIds` was **nil** |
| 3 | fix in place, `state.watchers[key] = player` deleted from `occupancy` | the same run as case 2 | `range.spec:4428` -- `#sent >= 1` got **false** |
| 3 | fix in place, `publish`'s record-making arm deleted (the OTHER half) | `FAIL 32/34 (DIRTY TREE (2 paths))`, 1 failed / 1 error | `range.spec:4428`, and that case alone |

Cases 2 and 3 are GREEN at the round-1 code commit by design: their producers shipped in round 1 and
the defect was the spec, so their bite is shown by deleting the producer, which is what findings 2 and
3 asked for.

## What I could not verify

- **Both gate lines.** Above, with the refusal text. Nothing in this round is called tested.
- **The `Mask.setMine((record :: any).mine, (record :: any).mineIds)` call itself**, finding 2's third
  named site, is a line in `src/client/RangeBoot.client.luau` -- a boot script's remote handler, which
  no spec in this repository can call. What is now covered is the producer (`Range.mineIdsFor` ->
  `copy.mineIds` -> the wire, case 2) and the consumer (`Mask.isMine`'s id arm, `range_mask.spec`).
  The one-line wiring between them is uncovered, as every boot wiring here is.
- **No live Forest Test proof this round.** Finding 1 does change what a real shot does in her place,
  so the dispatch asked for one shot past a carcass. Her Studio is open and in use; the proof route
  needs a Play restart there, and `<runs-dir>/ft-open.sh` -- the cold-restart script (V294) -- would
  restart HER session. Not attempted. The spec is the proof this round; the live shot is the
  Director's, or a later round's.
- The round-1 non-blocking notes are untouched and queued as **321a** in `TASKS.md`, per the dispatch.

ANSWERED: L-136 the named flake `weapon_shot.spec.luau:1490` did not fire in any of the five runs of
this session. The FAIL that did fire is `deer_hitbox.spec:659/:682`, reported above as a FAIL with a
correlation and explicitly NOT as a flake -- no control run was made, so no claim leans on it.
ANSWERED: L-127 each item above is stated as proven-by-case or as NOT verified; the gate lines are NOT
MET, said first and in the header.
ANSWERED: L-162 every run is named with the commit and the mutation it was taken at; the only runs at
the code commit itself are the two one-player runs, both quoted with their result.
ANSWERED: L-028 all three findings were producer-survives-deletion cases, so every new case was RUN
RED and its failing line and value are pasted above, not claimed.
ANSWERED: L-054 the two-player run's one-Studio precondition was CHECKED FIRST, not after burning the
slot: `run-test2.sh` refuses at 2 Studios, and the bare `test2` attempt is quoted. The player-count
spinner was never reached, so nothing is claimed about it.
ANSWERED: Vnight-1027 the dispatch naming `deer_hitbox` intermittent is not treated as the control
run; it is reported as a live FAIL at this commit.
