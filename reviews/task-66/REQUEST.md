# Task 66 — M2.8c: the road's furniture

Task: 66
Round: 1
Base: `4aa2962` (`main`, with Task 63 merged)
Code commit: `41f473513ea1f3d655fad616251144c3dad9c1b5` — **both** harness lines below name it, and
both runs were made at it. It is a PAPERWORK commit: the last commit that changed `src/`, `tests/`
or `tools/` is `2fcafba`, and `git diff --name-only 2fcafba..41f4735` is `TASKS.md` and this file.

Harness, clean tree, one player:

    [harness] PASS: 30/30 checks @ 41f473513ea1f3d655fad616251144c3dad9c1b5 (clean tree)

Harness, clean tree, two players — **run by the DIRECTOR, not by me** (`src/` changed):

    [harness2] PASS: 32/32 checks @ 41f473513ea1f3d655fad616251144c3dad9c1b5 (clean tree)

Both lines name the same commit. My own one-player run had named `2fcafba`, the last commit that
touched code, and the review gate refused it: the rule is that the pasted line names the
`Code commit:` itself, so the Director re-ran it at `41f4735`.

382 server specs (378 before: **four new**), 84 shooter and 78 driver client specs. **The map is
CLEARED from the place**: `cellsAfter: 0`, `paletteRestored: true`, and a `census` afterwards shows
Workspace holding Camera and Terrain only.

## Scope

Design §18's **M2.8c** row, which is the list: stakes beside each post, a high seat as scenery near
four of them, a barrier at each end of the road, two log piles on the verge, a fence and a gate on a
field boundary, reeds at the bog — "all proxies", plus "one new close view". Director decisions in
`reviews/task-54/BRIEF.md`. It also closes **row 58a(a)**.

## Claims

1. **The stands are VISIBLE now — row 58a(a).** Every tagged marker is `Transparency = 1` by design
   §4.3, so `map-road` could not answer its own question: there was nothing on the road to see. Two
   stakes flank each stand with a 2.4-stud orange cube on top, 9 studs up. `map-stand-close`: the
   near cap reads clearly at ~70 studs and the next stand's at ~230. Verify: `Layout.furniture`'s
   stakes, `Config.FURNITURE.stake`, the shot.

2. **Nothing this task adds stands between a shooter and the drive.** The stakes sit 4 studs BEHIND
   the centreline (the drive is at +z) and the high seats 40 studs behind it, past the verge. Verify:
   the spec *"puts a stake either side of every stand, behind the line and never in front of it"*.

3. **NOTHING IN THE LAYER COLLIDES, and that is one rule, not six decisions.**
   `MapGen.verifyContract` fails the build for any collidable part within `halfWidth + verge` of the
   road over its whole length (Task 58 round 1 finding 1). Half this layer stands inside that
   envelope on purpose — stakes, barriers, one log pile — so `Props.furniture` sets
   `CanCollide = false` on everything it makes. The spec builds the layer for real into a throwaway
   root and asserts every part is non-collidable **and** that more than 30 of them are inside the
   envelope, so the assertion is about something. It also means the furniture cannot change a single
   pathfinding answer.

4. **Pure list, dumb builder.** `Layout.furniture(config)` returns every piece as data and
   `Props.furniture` builds what it is handed — the division `Props.hedge` already has — so what the
   road carries is assertable without building a map. Each piece names the anchor its ground height
   is sampled at, so a high seat's four legs and its deck stand on one plane instead of each
   following the heightfield.

5. **The wood is kept out of the high seats.** They stand inside the dense band, so without a
   clearing a 15-stud tower is built inside a spruce. `Layout.treeDensity` returns 0 within
   `clearRadius = 14`; the spec asserts the clearing exists **and** that it is a clearing rather than
   a hole in the wood (density > 0 at 30 studs further out). Cost: 4 trees (2,746 → 2,742).

6. **The fence and its gate are in the field, and the farm track passes through the gap.** Every
   fence piece is beyond `corridor.maxX` and inside `Layout.inField`, and the gate gap straddles
   `WORLD.tracks[1].at = 880`. The gate panel stands open on its hinge post. Verify: the spec *"puts
   the fence, its gate and the reeds where they belong"*.

7. **N — the build, measured.** 274 steps; **137 furniture parts** (stake 16, cap 16, high-seat legs
   16 + 12 deck/rail/roof, barrier 6, log 12, fence 10 posts + 18 rails + 1 gate, reed 32) against
   the new `Map.BUDGET.furniture = 250`; 6,387 → **6,393 parts** total; 2,742 trees. Same seed twice
   → **same digest** `e064d598…` (before the last two shots-only commits), `contract OK`.

8. **N2 — reachability still passes, unchanged.** `mapgen verify --seed 1`: **25/25
   `PathStatus.Success`** across five froms × five targets, which is what claim 3's rule guarantees
   rather than hopes for.

9. **Looked at, then changed — twice (rule 5).** The first build's stake cap (1.2 × 1.5 on an 8-stud
   stake) was one orange speck at 70 studs and nothing at 160; it is a 2.4-stud cube on a 9-stud
   stake. The first log pile (3.2 studs tall, 30 studs off the centreline) was a pale sliver in the
   shade; it is three rows of thicker logs at 20 studs. The reeds were 1.4 studs thick and invisible
   against the mud; they are 3-stud clumps, 32 of them. Each change has its own commit and its
   reason in the code.

10. **The generator says which version built a map.** `Map.GENERATOR` → `"m2.8c-road-furniture"`, and
    `MapGen.VERSION` still reads it (the spec asserts the one home). `prop.highseat` joins
    `Assets.KEY`: when a model exists it replaces the WHOLE seven-box proxy rather than one box of
    it.

## What I could not verify

- **Karen has not seen any of it.** Whether a hunting line reads at 160 studs, and whether an orange
  cap is the right marker at all, is hers.
- **The furniture is scenery a player can walk through**, all of it, including the barrier across
  the road and the log piles. That is the contract's rule applied to the whole layer; whether some
  of it should collide when real meshes arrive is a Director/Architect call, queued as 66a(a).
- **The fence reads as a thin line at 100 studs** in an open field, and is essentially invisible from
  the road. I looked at it from 20 studs to describe it honestly; nobody will see it while playing.
- **Both harness runs at `41f4735` were made by the Director, not by me.** My own one-player run
  was at `2fcafba`, the last code commit, which the gate refused. This change is generator code that
  runs in Edit and puts nothing in a play session, so the two-player run in particular is the gate's
  requirement rather than evidence I produced.
- **The screenshots are seed 1**; the specs are pure and run at `SEED = 7`.
