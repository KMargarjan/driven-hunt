# Task 68 — a key per species, and furniture that does not stop a slug

Task: 68
Round: 1
Base: `main` (`47b99a3`)
Code commit: `06880514ac345efe375663f8235635aa9a827c35`

```
[harness] PASS: 30/30 checks @ 06880514ac345efe375663f8235635aa9a827c35 (clean tree)
```

*(the `[harness2]` line for this same commit is the Director's run; this request is updated with it
before the review.)*

**What changed.** Two map defects the Director dispatched before M2.8d, and nothing else.
`src/serverstorage/MapGen/Assets.luau`, `Config.luau`, `Props.luau` and
`tests/server/map_contract.spec.luau`. 383 server specs (382 before: one new), 84 client.

**What was scoped out, by the Director, and is queued as `TASKS.md` row 68a:** audit-005 must-fix 2's
third fix piece (`placed` taking its anchor explicitly), its sixth `brush` key, and Task 66's two
geometry notes (high seat 4 beside tie tree 12; a fence rail sampling the ground at its span middle).
The last two would move parts, and claim 8 is that nothing moved.

## Claims

1. **Each species asks for its own asset key.** `Assets.KEY` gains `treeBirch`, `treeOak` and
   `treeAlder` (`docs/design/map-generator.md` §12.1's names), and every `Config.SPECIES` row carries
   an `assetKey`. Verify: read `Assets.KEY` and `Config.SPECIES`; `Config` requires `Assets` (data
   only, `Assets` requires nothing, so no cycle) and there is still exactly one id table in the repo.

2. **No call site in `Props` spells an asset key for a tree any more.** `Props.trees` fetches one
   template **per species row** before its loop and hands `templates[species]` to each tree;
   `Props.tieTrees` asks `Props.speciesRow(config, nil).assetKey`. Verify: grep `Props.luau` for
   `Assets.KEY` — the only remaining hits are `hedge` and `highSeat`.

3. **Every placed tree records what it was built from.** `Props.placeTree` sets
   `Props.SPECIES_ATTRIBUTE` (`"Species"`) to the row's `name` on both branches, proxy and template.
   `Config.TREE_PROXY` is now a row like the others: `name = "tieTree"` (deliberately not `"spruce"`,
   so a tie tree cannot satisfy a claim about the wood) and its own key.

4. **The wood is asserted as instances, not as a sampler.** `map_contract.spec`,
   `it("plants the species it sampled, and asks for a key per species")`, builds all four quadrants
   through `Props.trees` into a throwaway `Folder` (as the furniture test does) and asserts, for
   every tree: the `Species` attribute is one of Karen's four; it equals `Scatter.speciesAt` at that
   tree's own point, asked with `Height.atFlattened` plus the pads and `Layout.bogDepth` exactly as
   `Props.trees` asks it; the trunk and crown sizes are **that species'** `Config.SPECIES` geometry;
   and the step reported **four distinct asset keys**. Note from the run:
   `built wood: 2734 trees, spruce 1097, birch 744, oak 554, alder 339, from 4 asset keys`, which
   matches the sampler's own note tree for tree.

5. **A tree is matched to its point by name, not by its position.** `Tree%04d` is the placement
   order, so the spec re-asks `Scatter.trees` for the same points in the same order and checks the
   trunk stands within 0.05 studs of the point. Why: the spec's first run failed with
   `Tree0840 at (676, 975) is a oak, but the sampler chose birch there` — the tree was right and the
   spec was wrong, because `Position` is float32 and the round trip flips a tree on a clump boundary.

6. **One writer of both collision properties in the furniture layer.** `Props.sceneryOnly` sets
   `CanCollide = false` and `CanQuery = false` on a piece and its descendants, and it is the only
   writer of either in `Props.furniture`. The rule is stated in `Config.FURNITURE`'s header beside
   the CanCollide argument: a slug passes through anything a player walks through. It is explicitly
   **not** a map-wide rule — a tree crown stays `CanQuery = true` (`Props.placeTree`, Task 63).

7. **The furniture spec asserts it.** `it("builds every piece of furniture, and not one of them
   collides or stops a slug")` builds the layer for real and asserts `CanQuery == false` on every
   part, beside the existing `CanCollide` assertion. This is Task 66's first review note: the log
   pile 20 studs downrange and 20 studs right of shooter post 7 was absorbing slugs.

8. **No geometry moved.** `python tools/mapgen.py verify --seed 1 --backup census`:
   `[mapgen] OK: same seed twice, same digest @ 9bbf25f seed=1 digest=e064d598…deae5 (clean tree)`,
   6,393 parts, 25/25 `PathStatus.Success`, `contract OK`. The digest is **byte-identical to Task
   66's** — `Digest.of` hashes name, className, Position, Size and tags, so an attribute cannot move
   it, and nothing else in this task touches a position.

9. **Three mutations, each applied, the harness run, then restored.** Dropping `candidate.CanQuery`
   from `sceneryOnly` → the furniture spec fails (`Expected value "false", got "true"`). Keying every
   tree `Assets.KEY.treeSpruce` in `Props.trees` → the four-keys assertion fails (`Expected value
   "true", got "nil"`). Writing `"spruce"` as every tree's species → `Tree0001 at (-972, 807) is a
   spruce, but the sampler chose oak there`. Each run: `FAIL: 28/30 checks` on the dirty tree; the
   tree is clean and unchanged now (`git status`).

10. **Screenshot (rule 5).** `.screenshots/20260926T192515Z-task68-wood-autumn.png`, the `map-autumn`
    camera, taken from the rebuilt map and inspected: pale birch trunks among dark ones, and green,
    yellow and orange-brown crowns overhead — a mixed wood, not a monoculture. Ground level is still
    near-black under a closed canopy, which is the open row 63a(a) and not this task.

## Not verified

- **`test2`** — the Director's run; this request is updated with the `[harness2]` line for the same
  commit before the review.
- **The template branch of `Props.trees` is still dormant.** `Assets.ROWS` is empty, so every tree is
  a proxy and the per-species `Props.template` call is only ever exercised on its `nil` return. What
  claim 4 proves today is that four *keys* are asked for; that four *meshes* arrive is provable only
  when the first tree id lands (M2.3 / M2.7d).
- **Nobody has shot at a log pile in a live session.** Claim 7 is asserted on the built part's
  `CanQuery`, not on a slug's path; `Weapon.Cast` is unchanged and untouched by this task.
