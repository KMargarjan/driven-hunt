# Task 309a -- name the last stud: the per-shot instrument, then the fix

Task: 309a
Round: 2
Base: 190b145d (main)
Code commit: 7f0a45a84ae3a37a15b8af7cda53b4b298c069b8

```
[harness] PASS: 34/34 checks @ 7f0a45a84ae3a37a15b8af7cda53b4b298c069b8 (clean tree) scope=all
```

Two players: **N/A**. No changed path is in `TWO_PLAYER_PATHS` (`tools/agents.py`): the change is
`src/server/HitLog/`, `src/server/Weapon/`, `src/shared/Shotgun/`, `src/shared/Flags/` (one comment),
two server specs, `tools/aim_bench.py` and one research note.

**WHERE EVERY NUMBER BELOW WAS TAKEN** (round 1, finding 2): placeId **130094961655666** -- the
Forest Test place Karen plays -- synced from the test build **driven-hunt-294** on port 34874 at the
commit named. Her own driven-hunt-karen copy (port 34873) was never checked out, edited or connected
to; the panel is returned to 34873. The place is hers, the build is the test checkout.

## Round 1's three findings

1. **The bound's sign was backwards.** Corrected in the `FLIGHT_REWIND_BASE_SECONDS` row, in the
   research-note row and in claim 5: the bench reads the drawn trunk one frame AFTER the trigger, so
   the measurement UNDER-reports the gap by ~0.4 studs at a run, a perfect rewind would print about
   **-0.4** rather than 0, and **0.250 is the UNDER-rewound end** with the zero above it near
   0.254..0.271. The shipped value stands; under-rewinding is the conservative side.
2. **"Karen's place" named a place and implied a build.** Both are now stated where the constant is
   read (`src/shared/Shotgun/init.luau`), in `Flight.advance`'s comment and in the research note.
3. **A ring line could be credited to a shot that did not write it.** `ServerStorage.DHLastHits`
   persists across cells, so "the tail changed" credited the first shot of every later cell with the
   previous cell's last line whenever it missed. `ring_credit` now credits a line only when its own
   index is unseen, and `ring_indices` seeds that set from the ring BEFORE the cell's first shot.

## Claims

1. **The contradiction is a REPORTING defect.** At 190b145d `DHLastHits` was empty for all 120
   shots (`<runs-dir>/309/after-B.txt`, the "last server hit trace" block reads `nil`). With the
   instruments it read `local=(-1.63,-0.08,5.62)` and `local=(-2.55,0.54,6.21)` on a boar 5.5 long
   and 2.0 wide -- a body length past its own rump, `uv` pinned at u=1.000.
   *Verify:* `<runs-dir>/309a/diag1.txt`, `ring-z` +5.88 (run chest) and +6.16 (control).
2. **The cause is `Flight.advance` rebuilding the impact row without `frame`.** `Rewind.impact` sets
   it, `Hits.group` carries it (task 308), `HitLog.frameOf` falls back to `part.CFrame` without it.
   *Verify:* the field list in `Flight.advance`; and on diag1 control shot 12,
   `|impact - pres|` = 5.85 against a ring z of 5.62, `|impact - past|` = 1.21.
3. **The fix is proven by the same instrument.** `ring-z` is now -0.05 (stand), +0.85 (run chest),
   -0.97 (run nose), -0.32 (control) -- every struck point inside the body, against +5.88/+6.16
   before. *Verify:* `<runs-dir>/309a/after-C.txt` against diag1.txt.
4. **The zone word was right all along.** Each cell's mean `ring-z` falls in the zone its own
   histogram names, against `Boar.CONFIG.ZONES`: chest -1.29..+0.23, body loin +0.67..+1.11, rear
   hips from +1.11. Control: `ring-z` -0.32 with chest 21 of 27. *Verify:* after-C.txt.
5. **The last stud is the rewind amount, measured end to end.** `pastgap` read +1.00 / +1.19 / +0.90
   on three run cells at 0.205 and **+0.17 / +0.09 / +0.05** at 0.250, with +0.04 standing. Its own
   bias and direction are stated in finding 1 above and in the config row. *Verify:*
   `<runs-dir>/309a/after-A.txt` (0.205) against after-C.txt (0.250), same place, same rig, N=30.
6. **Three measure-change-re-measure cycles, one instrument.** diag1 (N=12, instruments only) ->
   after-A (N=30, tense carried) -> cycle3 (N=20, 0.250 in the test build) -> after-C (N=30,
   shipped, corrected instrument). RUN chest 42% -> 50% -> 100% -> 100%; `pastgap` +1.47 -> +1.00 ->
   +0.10 -> +0.17.
7. **Nothing was widened into air, and finding 3's artefact is visibly gone.** The KNOWN-BAD cell --
   a click one drawn body length ahead of the nose -- read 2/30 at 190b145d and **0/30** now, with
   **ring 0/30 and ring-z `--`**: at round 1 the same cell printed ring 1/30, which was the stale
   line finding 3 named. *Verify:* after-B.txt against after-C.txt.
8. **Both instruments have a known-bad case in the suite.** `hit_card.spec`: a card the range
   REFUSES leaves `traced` 0 and the ring empty; and -- new this round -- a second pass with
   `targetCFrame` set 6 studs back, whose offset differs from the present-tense one by 6 studs, so
   the TENSE itself is now covered. `weapon_rewind.spec`: `advance` driven with a cast that names a
   frame and one that does not. `aim_bench.py selftest`: `parse_trace` on four non-ring inputs, and
   `ring_credit` refusing a line already seen.
9. **Two of five targets are NOT met and are not claimed.** RUN nose 25/30 = 83% (target 85%,
   CI 66-93) and CONTROL 27/30 = 90% (target 95%). MET: STAND chest 29/30 = 97%, RUN chest
   **30/30 = 100%**, known-bad 0/30.
10. **The bench ran at 83569069, one commit before the code commit.** 7f0a45a8 adds only
    `reviews/task-309a/RESULT.md`, so no `src/`, `tests/` or `tools/` line differs between the
    measured build and the reviewed one.

## What I could not verify

- **CI on the pushed branch.** `gh` is not authenticated in this session; the branch is pushed.
- **Whether 0.250 or something up to ~0.271 is right.** The bracket and its direction are in the
  config row. It needs Karen's eye, not another number.
- **Rule 5 / the hit card on screen.** No frame of the card was taken: carrying `frame` moves the
  card's dots and the report silhouette's mark off the clamped u=1.000 tail into the body, and that
  is a change in what Karen sees which nobody has looked at. **NOT PROVEN, not claimed.**
- **`AIM_REWIND.default` is still `false`** -- unchanged by this task, open since 305. Her Forest
  Test place has the override ON (`DHFlag_AIM_REWIND=true`, printed at the head of every bench run),
  so the fix is live for her playtest; for anyone else it is dark.

ANSWERED: L-136 the one FAIL in round 1 was MINE (`hit_card.spec`, my own new case asserting
`points[1]` instead of the report's own position); fixed, not called a flake, and the re-runs are 34/34.
ANSWERED: L-127 every dispatch item is MET / NOT MET per item in claim 9 and in the handover block.
ANSWERED: L-123 control and known-bad are printed as numbers in every table in `<runs-dir>/309a/`.
ANSWERED: Verdict-298 the proof is the bench's moving-target table in her PLACE (after-C.txt), from
the test build, and claim 10 and the WHERE block say exactly which build.
ANSWERED: ROUTE/b309-result.json her place's live flags are printed at the head of every bench run;
`DHFlag_AIM_REWIND=true` there, so the fix is visible to her Friday playtest.
ANSWERED: L-141 both instruments read differently by state -- ring 30/30 on a scoring cell against
**0/30** on clear air, `pastgap` +0.04 standing against +1.19 at a run on the old build.
ANSWERED: L-143 every row and every cell prints `pastgap`, `ring-z` and `ring N/N`, control included.
ANSWERED: L-121/L-028 the verdict is geometric -- the struck point's local offset against the drawn
mesh's own extents, not the zone word -- and the known-bad click produces no ring line at all.
ANSWERED: L-124 the ring is populated -- 29/30, 30/30, 25/30, 27/30 -- so no proof was worked around.
