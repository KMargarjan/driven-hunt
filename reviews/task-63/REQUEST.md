# Task 63 — M2.8b: the wood

Task: 63
Round: 2
Base: `4a0a7d5` (`main`, with Task 61 merged)
Code commit: `4755ad898e4aad35f90f75b0245e98ddbb505c50` — **both** harness lines below name it. It is a
PAPERWORK commit: the last commit that changed `src/`, `tests/` or `tools/` is `a2ebfca`, and
`git diff --name-only a2ebfca..4755ad8` is `TASKS.md` and this file.

Harness, clean tree, one player:

    [harness] PASS: 30/30 checks @ 4755ad898e4aad35f90f75b0245e98ddbb505c50 (clean tree)

Harness, clean tree, two players — **run by the DIRECTOR, not by me**:

    [harness2] PASS: 32/32 checks @ 4755ad898e4aad35f90f75b0245e98ddbb505c50 (clean tree)

378 server specs (377 before: **one new**), 84 shooter and 78 driver client specs. **The map is
CLEARED from the place**: `cellsBefore: 3381368`, `cellsAfter: 0`, `paletteRestored: true`, and a
`census` afterwards shows Workspace holding Camera and Terrain only.

## Round 1's finding, and what round 2 changed

The finding was PROJECT_CONTEXT's named killer — **one predicate answered two unrelated questions**.
`Scatter.weighted` stored the key that decided *whether a candidate becomes a tree* on the point, and
`Scatter.speciesAt` used that same number to decide *which species it is*. Every candidate accepted
where the density is 0.42 (the drive) or 0.14 (the backdrop) has a key below
`SPECIES_CLUMP_STRENGTH = 0.65`, so the clump's leader was returned unconditionally: **every clump
outside the dense band was a pure monoculture**, over about half the wood.

Nothing else in the task changed. **No tree moved**: the same build, same seed, reports the same
2,746 trees in the same quadrant counts.

## Claims

1. **The species has its own number, and cannot be handed one.** `Scatter.speciesAt(x, z, seed,
   config, groundY)` **no longer takes a key**; it draws its own from `Scatter.pointKey(x, z, seed,
   STREAM.species)`, a hash of WHERE the tree is rather than of when it was drawn. The signature is
   the fix: no caller can pass a number that answered another question. Verify: `Scatter.speciesAt`,
   `Scatter.pointKey`, `Scatter.STREAM`, and `Props.trees`'s call site.

2. **The acceptance key does not leave `Scatter.weighted`.** A point is `{x, z}`. The number was
   compared against the weight and is finished; storing it is how the species came to be decided by
   the density, so the only way to make that unrepeatable is for it not to be there. Verify:
   `Scatter.weighted` (no `key` on the point); nothing in `src/` or `tests/` reads `point.key` of a
   tree any more. `Scatter.jitteredGrid` still carries one, because brush sorts candidates BY it —
   the same question, the same number.

3. **The hash is flat, measured before it was used for a second question.** `hash01` is the
   arithmetic `clumpHash` already used, so **the clump leaders did not move**. Over 200,000 points
   of this map's own inputs it lands 10.03 / 9.97 / 9.99 / 9.96 / 10.00 / 10.05 / 9.98 / 10.00 /
   10.01 / 10.01 per cent in the ten deciles, and `pickByShare` over it returns 39.95 / 25.08 /
   19.96 / 15.02 against Karen's 40 / 25 / 20 / 15. Verify: `hash01`'s comment, which quotes the
   measurement.

4. **THE SPEC MEASURES THE MIX INSIDE A CLUMP, because the aggregate mix does not catch this bug.**
   The leader is itself drawn by share, so the marginal shares are unbiased with the bug and without
   it — which is why round 1's share assertion passed over a broken wood, and it would have passed
   over this fix too. The new `it` measures the share of trees that are **not their clump's leader**,
   per density tier, against the derived `(1 - strength) * (1 - Σ share²) = 0.35 × 0.715 = 0.2503`.
   Measured at `SEED = 7`: **thin tier 0.262 over 1,438 trees, dense tier 0.244 over 1,289, and the
   two tiers 0.018 apart**. Verify: `map_contract.spec`, *"draws the species independently of the
   density, so the mix is the same in a thin wood"*; `Scatter.clumpLeaderAt`, exposed because a spec
   cannot measure a clump's mix without knowing its leader.

5. **The species mix per tier, against the configured weights, with the tolerance stated.** The same
   spec asserts every species' share **in each tier**, not only in the wood as a whole: thin
   spruce 0.401 / birch 0.266 / oak 0.202 / alder 0.131, dense 0.406 / 0.281 / 0.205 / 0.109, against
   0.40 / 0.25 / 0.20 / 0.15. The band is `× 0.4 … × 1.8` and the comment says why it is that wide:
   the wood is about **59 clumps** of 260 studs, so the effective sample is clumps, not 2,746 trees
   (the design's ±25 % over one seed would be ~1.3 σ, i.e. flaky — queued as 63a rather than
   silently loosened).

6. **MUTATION-CHECKED, and the mutation is the bug itself.** Scaling the species number by the
   density again (`Layout.treeDensity(x, z, config) * Scatter.pointKey(...)` — which is exactly the
   distribution of the old accepted key) makes the thin tier read **0.000**, and the new spec fails
   at `map_contract.spec:1131`, its tier-agreement line. **The old share assertion passed in the same
   run** (377 passed, 1 failed), which is the Reviewer's point demonstrated rather than restated.
   Restored and re-run green.

7. **The wet rule still overrides the clump**, now asserted at four points around the bog instead of
   two — `speciesAt` no longer takes a key to steer it with. Verify: the last lines of *"plants
   Karen's four species, in her proportions, with alder in the wet"*.

8. **N2 — reachability, rebuilt.** `mapgen verify --seed 1` is **25/25 `PathStatus.Success`** across
   five froms × five targets (321–450 waypoints), same seed twice → **same digest**
   `940540037013158d…` @ `a2ebfca` (clean tree), `contract OK`, 9,030 instances, 3,381,368 terrain
   cells. Verify: the `[mapgen] OK` and `[mapgen] reachability OK` lines.

9. **N3 — the build is unchanged where it must be.** **2,746 trees** at seed 1, quadrant for
   quadrant (433 / 444 / 905 / 964), 500 brush, 12 tie trees — identical to round 1. Only the species
   assignment moved: spruce 1082→1090, birch 542→567, oak 530→522, alder 592→567 of the same 2,746.
   That the aggregate barely moves is the point of claim 4.

10. **Screenshots, inspected (rule 5).** `map-wide` (the whole map from 1,100 studs): wood with
    fields at the edges, the road a line through it, and the four crown colours intermixed across the
    frame rather than in solid blocks. `map-post` (a shooter's view into the drive): white birch
    trunks and dark trunks interleaved, crowns green/orange/yellow overhead, sight ~60–80 studs.
    `map-autumn` (close in the wood): all four crown colours within one small area. `map-drive`
    (down the corridor from 40 studs up): unchanged framing, mixed crowns, road clear.

## What I could not verify

- **A screenshot cannot show a mix statistic.** The pictures show the wood is not blocked into
  monocultures where I looked; the per-tier measurement in claim 4 is the evidence for the fix, and
  it is a measurement of the seed-7 wood, not of the seed-1 build the pictures are of.
- **One seed each.** The spec measures `SEED = 7`; the build and the shots are seed 1. The design's
  five- and twenty-seed properties are measured by the walkability spec, not by this one.
- **`[harness2]` was run by the Director, not by me**; this change is server-side generator code
  with no client path, and the two-player run is the gate's requirement rather than evidence I
  produced.
- **Karen has not seen the wood.** Whether the mix reads as a European wood at all is hers.
- The round-1 notes that are not this finding are queued in `TASKS.md` as 63a, not fixed here.
