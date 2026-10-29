# Task 306 step B10: THE LOOK -- a clean, proper range like a real one

Task: 306j
Round: 1
Base: d4612c53 (task-306b9-proof)
Code commit: fb9a5f815f2ca63221319b5e021baf4cbc2443af

Karen, 2026-10-28: *"make nice shooting range clean proper like in real life and behind animal could
be a mountain not high but like in real life ... nice and clean / outsource and make it real"*.

```
[harness] PASS: 34/34 checks @ fb9a5f815f2ca63221319b5e021baf4cbc2443af (clean tree) scope=all
```

`[harness2]` N/A: no changed path is in `TWO_PLAYER_PATHS`
(`python -c "...agents.needs_two_player([...])"` -> `[]`). The change is the range's geometry, its
data, its own server handler and one client key rule.

Research first (rule 1): `docs/research/2026-10-28-the-range-in-the-lobby.md` **section 8** -- seven
photo-reference pages with what each shows, the deviations, and targets 8.3 L1-L6.

## Claims

1. **No gameplay number moved.** `range.spec` "leaves every measured point and distance exactly
   where B2-B9 put it" asserts the LITERALS (distances, window, apron, spacing, berm, banks, mat,
   post, bench, stand, prompt rise) and the points themselves, so a moved arithmetic fails it.
   MEASURED in her place before and after, same probe (`<runs-dir>/306b10-read.luau`):
   `Mat1/3/5`, `Bench3`, `Post3`, `Stand3/5 deck+ladder` are byte-identical in the two runs.
2. **The lane is mown and does not hide the target.** `Range.turfSlabs` + `Build`: decorative slabs
   of a **BasePart's** `Grass` (flat texture, no blades -- blades are the TERRAIN renderer's, which
   was B8's measured objection), `CanCollide`/`CanQuery`/`CanTouch` all false. Verify:
   `range.spec` "lays the mown lane as one part that no ray and no body can meet", and the corridor
   case asserts that same triple on the way past its one exemption.
3. **The berm and the banks are grassed earth.** `SURFACE.BERM = Grass`, and the two repaints move
   AHEAD of those fills in `Build.writeTerrain` (filled first, the repaint ate the bottom 4 studs).
   Verify: measured in her place -- `berm@(2660,-3222)` and `bankE` read `Ground` before and
   `Grass` after (same probe), and frame `306b10-after-D.png`.
4. **A roofed firing point per station**, four posts + roof + planked bench + a number board on both
   fascia faces. Verify: `range.spec` "keeps the roofed firing point out of every line of fire"
   (every post against `Range.sightHalfWidthAt`, the roof against the deck's own sight ray and
   against the stand's deck edge) and "prints each station's own number on its board" (stations 1,
   4 and 6, three different strings).
5. **The hut, the board and the turf stand on the MEASURED ground, not the shelf.** Found by the
   first frame from the bench: her shelf is 148 and the ground the mats sit on is 150, so the roof
   hung 2 studs over the eye and the turf was 1.9 studs under the terrain. The turf takes ONE
   reading at its own centre, because its corners sit on the berm and the banks (that bug floated it
   11.7 studs). Verify: `306b10-after-B.png` against `306b10-before-B.png`.
6. **The way up works under real keys** (the one input change; B9 measured twice that real `W` never
   climbs). `Climb` on E at the ladder foot, `Climb down` on F on the deck, `Triggered` wired on the
   SERVER. Verify: `range.spec` "climbs a man onto the deck and back down again, by station" enters
   BOTH arms and the refusals, and "hangs a Climb on E at the ladder foot and a Climb down on F on
   the deck" asserts the two keys differ and that both points are in reach of a man on the deck
   (which is WHY they differ: `Exclusivity` is `OnePerButton`).
   LIVE, real keys in her place: E at the foot moved him (2624,153.0,-3004) -> (2624,165.6,-3016),
   `spot=2 position=treestand`; F on the deck moved him back to (2624,153.1,-3009), on the ground.
7. **The panel's own E stands down for the climb prompt.** `range_panel.spec` enters both arms
   (`setClimbShown(true)` swallows, `false` opens) and `isClimbPrompt` is asserted for an up, a down
   and a menu prompt.
8. **The lot's side line is NOT built, and it is refuted with a reading.** `Build`'s comment carries
   it: along the east line the build's own ground reader says 159.1 and a terrain raycast 150.0 at
   (2775,-3061), so a post laid there stands 7.5 studs in the air. `range.spec` asserts the build
   writes NO `FencePost*` and NO `FenceRail*`. **Item 5 of the dispatch is NOT MET** and queued.
9. **Census, her place, 162-part build:** worst SINK +0.30 (`Leg1`, the seat's own `FOOT_EMBED`),
   0 parts with no ground. The run that reported worst FLOAT +7.53 was claim 8's post line, which is
   why it is not built. Re-measure with `<runs-dir>/306b10-census.luau`.
10. **Budget.** `MAX_PARTS` 160 -> 220; built 143 in DEV and 143-ish in hers, asserted by the spec
    against the arithmetic of what is built, not a literal.

## What I could not verify

* **The boar's silhouette from the bench was NOT measured.** `306b10-census.luau` answered
  `VISIBILITY: no animal on the lane` on both attempts -- the range releases a target only while
  occupancy says a man is at that station, and the staged man did not hold one long enough. The
  bench frame (`306b10-after-B.png`) shows the lane clear from the bench with nothing between the
  eye and the berm, and `306b10-c9-on-ground.png` has a boar on the lane; the NUMBER is not taken.
* The AFTER frames A/A2/B/C/D were shot at `1a254a09`..`33b27736`, before claim 8 removed the side
  posts. Nothing else in them changed.
* No asset was uploaded (note 8.2), so there is no `uploads.json` row and no per-asset loaded check.
