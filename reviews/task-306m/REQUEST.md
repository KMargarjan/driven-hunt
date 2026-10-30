# Task 306m: smooth the backstop into a hill (look only)

Task: 306m
Round: 2
Base: cb8a820c (main, = merged #292)
Code commit: d33c318e8c616fb93bc49953532a833c28d81607

```
[harness] PASS: 34/34 checks @ d33c318e8c616fb93bc49953532a833c28d81607 (clean tree) scope=all
```

`test2` is **N/A**: nothing here touches `TWO_PLAYER_PATHS` — the change is `src/shared/Range/`,
`src/server/Range/Build.luau`, `tests/server/range.spec.luau` and one research note. Look only, no
input path: **CORE-NA**.

**What changed.** 306l's heap was one `FillBlock` per 12-stud column, so the crest was a row of
square merlons with vertical sides and each side bank a square block (Karen's two frames). Every
number 306l measured is untouched; only the primitive and the shape move: the hill is
`Terrain:FillBall` now, one ball per (column, level), inscribed in a cross-section that tapers
linearly from its base half-depth to `capRadius` at the crown.

## Claims

1. **No box is left in the heap.** `Build.writeTerrain` fills the hill, both banks and the scrub
   with `FillBall` only. `range.spec`'s terrain double now records `FillBall` apart from
   `FillBlock`, and the case asserts every remaining `FillBlock` is a terrace rectangle (air, or
   the bank whose top is the shelf). *Verify:* `Build.bermFills`, `Range.bermBalls`,
   `Range.bankBalls`; the case "fills a rolling earth hill out of balls".
2. **The skyline has no step.** Sampled off the ball union's own surface (not off the dials) at one
   column's width: max adjacent difference **1.25 studs**, and **1.00** inside the shoulders,
   against `crestStepMaxStuds` 2.5 and `crestStepInnerMaxStuds` 1.5. *Verify:* `surfaceAt` in that
   case; harness note `range 306m hill: ... skyline step 1.25 (inner 1.00)`.
3. **No vertical face and no flat top anywhere on the berm, under bounds that REJECT both**
   (round 1, finding 1 — the old pair rejected neither). At every one of the 58 columns the
   cross-section rises every stud from the toe to the apex and falls every stud to the back; the
   apex is **strictly above both its neighbours**, which a plateau of any width fails; and the
   steepest **one-stud** rise is **5.13 studs**, held to `BERM.riseMaxStuds` 6.5 — a bound the
   pedestal (8.7) and a 306l box's face (its whole crest, up to 21) both fail, and which a 4-stud
   chord could not see because it averages the jump with the slope under it. The 4-stud slope
   (77.2 deg, `faceMaxDegrees` 79) is kept beside it as the reported angle. *Verify:* item (3).
4. **The `< ~50 deg` target is refuted by the envelope, not by taste**, and the arithmetic is in
   the code and in research note section 10: the envelope 306l fixed is `slopeRun + depth` = **16
   studs deep and 21 tall**, so the shallowest steepest face a RIDGE can have here -- a crest with
   ground falling away both sides -- is `atan(21/8)` = **69.1 deg** (round 1, note: a one-sided ramp
   over the whole 16 would read 52.7, with its crest standing ON the terrace edge and nothing behind
   it, which is not a backstop); spheres cannot even reach that (a cone's crest balls stop
   overlapping and comb the skyline, and a radius floor makes a pedestal with a vertical face —
   simulated at 8.7 studs of rise in one stud); and **50 deg needs 17.6 studs of run, putting the
   toe at 174 — 4.6 studs inside the 179 lane.** *Verify:* `BERM.faceMaxDegrees` comment, note
   section 10, and `expect(degrees > 50)` which fails the day the envelope changes.
5. **Every number 306l asserted still holds.** `bermToeClearance` 5.0, crest face 192, toe 184,
   back 200 against the terrace edge 202 and the road 204 (T6), the crest heights, and the
   deck-eye lower bound. *Verify:* the unchanged case "keeps the backstop's toe behind the farthest
   lane" (its loop now reads balls), the T6 case, and harness note
   `range 306l toe: ... toe 184 -- 5.0 studs clear of the 179 lane`.
6. **The side banks are rounded mounds that run into the heap**, not square blocks: two ball chains
   each, the radius tapering to `capRadius`, the top cap's own top equal to `BANK.size.Y`, so the
   mound is as tall as the block was and has no face. *Verify:* `Range.bankBalls`; item (8).
7. **Grass on crest, back and banks; earth only on the impact face.** A ball is one material, so
   the split is one `ReplaceMaterial` (BERM -> HILL) over the apex-to-back band — the **fourth and
   last** repaint. Its band starts **two voxels above the shelf**, because `SURFACE.BERM` and
   `SURFACE.LANE` are the same material (`Ground`) and a band at the shelf would turn the terrace's
   own downrange strip to grass. **Both faces of the band are now pinned to the apex** within the
   one voxel `ExpandToGrid` may add, and its depth is bounded above as well as below (round 1,
   finding 2: a size-only check stayed green with the band moved to the toe, which would grass the
   impact face). *Verify:* `writeTerrain`'s `repaintBox`; item (7).
8. **Nothing floats (rule E) under a rule written for balls**: per column the lowest ball is buried
   and every ball above overlaps the one below (centre distance < the two radii); each scrub clump
   is embedded exactly **2.0 studs** in its own crest, by construction (`2r - proud` is constant).
   *Verify:* the chain block in the terrace case; the embedding assertions.
9. **Looked at in HER place**, at `2e67a292` — and the hill in those frames IS this one: the whole
   `src/` diff `2e67a292..d33c318e` is comments plus the single line `riseMaxStuds = 6.5`, a dial
   no producer reads (`git diff 2e67a292..d33c318e -- src/` shows it). Forest Test on the 294 worktree served to
   :34874, same three camera points as 306l (`306l-lookmarker.luau`, `306l-cam-deck2.luau`,
   `306l-cam-yard.luau`), same crop box on both frames:
   - `306m-cmp-crest2.png` (before over after, 2x): before = flat-topped merlons with vertical
     sides; after = a continuous rolling green crest of uneven rises and a rounded left shoulder.
   - `306m-AFTER2-deck2-same.png`: a long earth bank with a rolling crown, rounded ends, no step.
   - `306m-AFTER2-yard-same.png`: from the lodge yard, a low earth ridge behind the stands.
   **No vertical face and no square step is left in any of the three.** The face is plainly steep,
   which is claim 4's measured 77.2 deg.
10. **The first AFTER frame refuted my own scrub.** At 7 even clumps of one radius the crest
    photographed as a row of regular cones — the battlement's rhythm with rounded tops. 13 clumps
    now take place, radius and height from one wave. The earth's own roll cannot carry the skyline:
    `crestDropStuds` is 3 and cannot grow, because `height - crestDrop` = 18 is already within half
    a stud of the deck eye at 17.5. *Verify:* `bermScrubPoints`; its commit message.

11. **Round 1's non-blocking notes that were false statements of mine are fixed in the same pass**,
    not queued: the crest is sampled BETWEEN two caps now (the one place a comb appears) against
    the dip the dials themselves predict — 0.76 studs measured, exactly
    `capRadius - sqrt(capRadius^2 - (crestStepStuds/2)^2)`; the scrub's uprange reach is asserted
    again as 306l did; and three comments describing states the code cannot reach are corrected.
    The rest are queued in `TASKS.md`.

## Could not be verified

- **The hill is steep and will still read as steep.** 77.2 deg is a bank, not a mountainside. The
  envelope forbids anything shallower (claim 4) and only Karen can say whether the battlement being
  gone is enough. **NOT PROVEN: that Karen reads this as "an earth formed mountain".**
- **T6 — `n shots stopped / n` — was NOT re-measured.** This change replaces the solid the backstop
  is made of and no shot was fired into the new one; `range.spec` is pure geometry. The arithmetic
  says the union is continuous (adjacent balls are 4 studs apart with radii >= `capRadius` 3 both
  laterally and vertically, so every pair overlaps by >= 2 studs) and the crest heights are
  unchanged — but that is a reading, not a sweep. **NOT PROVEN.** Queued in `TASKS.md`.
- A live probe of the shipped `Range` module in the Forest Test's **Edit** session could not be
  run: `execute_luau` answers "Module code did not return exactly one value" for any `require` of
  it there (a bare `return "ping "..game.PlaceId` in the same session answers). The sync is
  evidenced instead by the Rojo panel (`evidence/port-34874-20261030-043143.png`, "8 seconds ago",
  localhost:34874) and by the frames themselves, which cannot be drawn by the old code.

ANSWERED: L-136 — no spec failed at either code commit; the named flake
`weapon_shot.spec.luau:1490` did not appear in either run of the final commit, so no control run
was needed and no finding is called "known".
ANSWERED: L-127 — every item above is MET or carries its own NOT PROVEN line; the handover block
in the report states one verdict per dispatch item in my own words.
