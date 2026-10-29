# Task 306 step B10: THE LOOK -- a clean, proper range like a real one

Task: 306j
Round: 2
Base: d4612c53 (task-306b9-proof)
Code commit: 2082ce5ea77f7b575094e3a9e93858ccb23b586a

Karen, 2026-10-28: *"make nice shooting range clean proper like in real life and behind animal could
be a mountain not high but like in real life ... nice and clean / outsource and make it real"*.

```
[harness] PASS: 34/34 checks @ 2082ce5ea77f7b575094e3a9e93858ccb23b586a (clean tree) scope=all
```

`[harness2]` N/A: no changed path is in `TWO_PLAYER_PATHS` (`agents.needs_two_player` over the eight
changed files returns `[]`). The change is the range's geometry, its data, its own server handler and
one client key rule. The last commit that touched `src/`/`tests/` is `ff554760`; `2082ce5e` adds only
`reviews/task-306j/RESULT.md`.

Research first (rule 1): `docs/research/2026-10-28-the-range-in-the-lobby.md` **section 8** -- seven
photo-reference pages with what each shows, the deviations, and targets 8.3 L1-L6.

## Round 1's two findings

1. **The number board floated** (1.5 studs under the roof's underside). `HUT.boardRise` is GONE;
   `Range.boardRiseFor` derives the centre as `roofRise - boardSize.Y / 2`, so the board's TOP face
   IS the roof, and there is no key left to drift from. Verify: the new built-world case asserts
   `boardTop == roofBottom` within 1e-4 at all six stations, and frame
   `<runs-dir>/306b10-final-A2.png` (boards 4 and 5 flush under the fascia) against
   `306b10-after-A2.png` (the same two hanging in air).
2. **The sight case read no built part.** New case *"builds the hut where the sight bound says it may
   stand, and hangs the board on the roof"* builds the range and reads every `Roof<spot>` and
   `HutPost<spot>_<corner>` OUT OF THE FOLDER: X/Z against the pure point, each post's off-axis
   clearance against `Range.sightHalfWidthAt` at its OWN measured Z, each post top and the board top
   against the BUILT roof's underside. Deleting the hut block in `Build.build` fails it.

## Claims

1. **No gameplay number moved.** `range.spec` "leaves every measured point and distance exactly
   where B2-B9 put it" asserts the LITERALS and the points. MEASURED in her place before and after
   with the same probe (`<runs-dir>/306b10-read.luau`): `Mat1/3/5`, `Bench3`, `Post3`,
   `Stand3/5 deck+ladder` identical in the two runs.
2. **The lane is mown and hides nothing.** `Range.turfSlabs` + `Build`: slabs of a **BasePart's**
   `Grass` (flat texture; blades are the TERRAIN renderer's, which was B8's measured objection),
   `CanCollide`/`CanQuery`/`CanTouch` false. Verify: the turf case (both edges now pinned to 1e-6)
   and the corridor case, which asserts that same triple on the way past its one exemption.
3. **The berm and the banks are grassed earth.** `SURFACE.BERM = Grass`; the two repaints move
   AHEAD of those fills in `Build.writeTerrain` (filled first, the repaint ate the bottom 4 studs).
   Verify: in her place `berm@(2660,-3222)` and `bankE` read `Ground` before and `Grass` after, and
   frames `306b10-before-D.png` / `306b10-after-D.png`.
4. **A roofed firing point per station**: four posts, a roof, a planked bench (same size, same
   point), a number board on both fascia faces. Verify: finding 2's built-world case, plus "prints
   each station's own number on its board" (stations 1, 4, 6 -- three different strings).
5. **The hut, the board and the turf stand on the MEASURED ground.** Her shelf is 148 and the ground
   the mats sit on is 150, so `anchor.Y + rise` hung the roof 2 studs over the eye and buried the
   turf 1.9 studs. The turf takes ONE reading at its own centre (its corners sit on the berm and the
   banks -- that floated it 11.7 studs). Verify: `306b10-before-B.png` vs `306b10-final-B.png`.
6. **The way up works under real keys** -- the one input change; B9 measured twice that real `W`
   never climbs. `Climb` (E) at the ladder foot, `Climb down` (F) on the DOWNRANGE rail, `Triggered`
   wired on the SERVER. Verify: "climbs a man onto the deck and back down again, by station" enters
   both arms, both refusals and the false-mover arm, and asserts the Z that `footClearStuds` moves;
   "hangs a Climb on E ... and a Climb down on F" asserts the two keys differ and that both points
   are in reach of a man on the deck -- which is WHY they differ (`Exclusivity` is `OnePerButton`).
   LIVE, real keys in her place: E at the foot moved him (2624,153.0,-3004) -> (2624,165.6,-3016),
   `spot=2 position=treestand`; F on the deck moved him to (2624,153.1,-3009), on the ground.
   Frames `306b10-c3-climb-prompt.png`, `306b10-c4-on-deck.png`, `306b10-c7-lookdown.png`,
   `306b10-c9-on-ground.png`.
7. **The panel's own E stands down for the climb prompt, and stands back up.** `range_panel.spec`
   enters both arms of `climbShown` AND the `unwatchClimbPrompts` arm (a prompt destroyed while
   shown fires no `PromptHidden`, which would swallow E for the session).
8. **The lot's side line is NOT built, and it is refuted with a reading.** Along the east line the
   build's own ground reader says 159.1 and a terrain raycast 150.0 at (2775,-3061), so a post laid
   there stands 7.5 studs in the air; refusing by footprint SPREAD did not catch it, because the two
   readers disagree about the SURFACE, not its slope. `range.spec` asserts the build writes no
   `FencePost*` and no `FenceRail*`. **Dispatch item 5 is NOT MET**, and the research note's EDGES
   paragraph and `LAYOUT.FENCE` both carry the refusal.
9. **Census, her place:** 0 parts with no ground, worst SINK +0.30 (`Leg1`, the seat's own
   `FOOT_EMBED_STUDS`). The +7.53 FLOAT that the census reported was claim 8's post line, which is
   why it is not built. Re-measure: `<runs-dir>/306b10-census.luau`.
10. **Budget.** `MAX_PARTS` 160 -> 220; 143 built in DEV, and the comment's arithmetic now counts
    what is built. The spec asserts the count against that arithmetic, not a literal.

## What I could not verify

* **The boar's silhouette from the bench was NOT measured.** `306b10-census.luau` answered
  `VISIBILITY: no animal on the lane` on both attempts -- the range releases a target only while
  occupancy says a man is at that station, and the staged man did not hold one long enough for the
  probe. `306b10-final-B.png` shows the lane clear from the bench with nothing between the eye and
  the berm, and `306b10-c9-on-ground.png` has a boar on the lane; the NUMBER is not taken. 8.3 L4 is
  therefore NOT PROVEN.
* Frames A/C/D are from `33b27736` and earlier, before the side posts came out and before the board
  moved; A2 and B were re-shot at this commit. The census number (162 parts) was taken with those
  posts present -- the build at this commit is 143.
* No asset was uploaded (note 8.2), so there is no `uploads.json` row and no per-asset loaded check.
