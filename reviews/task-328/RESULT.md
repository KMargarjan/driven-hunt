PASS

Rule 5, stated so this PASS is not read as rule 5 having been met: nothing in this change was seen in
Karen's place, and nothing in it is visible — the commit touches nine files and every one is
Markdown (`.agent-evidence/changed-files.txt`). There is no core item (animal behaviour or shooting)
in task 328a, so no item number sits in the parenthesis. Karen's acceptance test for the series —
*"not broken trees hanging or to inside"* — is NOT proven by anything here and belongs to 328b/328f;
the request says so itself ("Nothing in this task was run in Studio"). Harness: docs-only, exempt;
`paperwork-after-code-commit.txt` reads OK (only `reviews/task-328/REQUEST.md` followed `a881b4fa`).

Delete-the-producer, applied by reading: the request offers no spec, probe, counted run or frame as
proof, so there is no case that could survive a deletion. Its claims rest on document text plus repo
facts, and I re-derived every repo fact from the source rather than from the documents — delete
`TreeGround`, `Places`, `Grid` or `grid.spec` and claims 3, 4, 5 and 9 all fail. Verified
independently: `sinkFor(h) = min(0.6, 0.1h)`, `TOLERANCE_STUDS` 0.2, `CLIFF_STUDS` 4.0 with the
"0.23 … median and 2.10 at the ninetieth percentile" comment, `junctionY`, `stepAllowance =
max(CLIFF_STUDS, 0.10h)`, `clawFor`'s `or 0` over 5 `SilverBirch_*` entries, no `TEMPLATE_DIMS`
anywhere in `src/` or `tools/`, `groundsUnder` at `samples(…, 4)` = 25 points; F-1 (`Places.build`:
*"THE OTHER WORLD'S FOLDER IS DESTROYED WHATEVER THE FLAG SAYS"*, then `priorGrid:Destroy()`);
F-2 (`Grid.roads` = `origin + 21 + k·(cell + 42)` with origin −6700/−6600, so all eight centres ≡ 1
mod 4 and a 4k+2 snap is a 1-stud move); F-3 (`Places.SURFACES.track.ruts`' merge measurement,
quoted correctly); F-4 (`laneHalfWidth` 21 = `roadClearStuds`/2, asserted); F-5 (`fernBands` over
`cellGround`, inset `CELL_EDGE_STUDS` 3 off a 21-st clear half, `fernBandStuds` 30 → d 24 to 54,
through the ditch 22–30 and verge 30–34); the sixth (`servePlaceIds` = [136410205938347,
130094961655666], against `forest_ground.py`'s *"serves only the DEV place"*). Arithmetic re-run and
correct: the §3.1 crown term (trunk `24 + 0.5·hw`, crown edge `24 − 0.5·hw`, clears ±10 only to
hw 28, 4.5 st at hw 39); rides 36 st → 18 st out → 5–21 st over the centreline at hw 23–39; §7.2's
49/51 and §13.2's 56.8/58.8 at scale 1.2; 32×32×24 = 24,576 against `MapGen.Config.VOXEL`;
footprint 4490 × 2986 → 36 × 24 = 864; 1430 × 18 = 25,740 = 1.7 % ≈ 25 trees at 32 st.

## Notes (non-blocking)
- `docs/design/grid-terrain.md` §14 F-1 / §10.1 / §13.3 / §0 — all four cite "`grid.spec` case 21"; that
  case does not exist. The numbered markers in `tests/server/grid.spec.luau` are 1–16, 17/18, 19, 20
  and 22, and the assertion they mean is in **case 22** ("the preview tags nothing"):
  `expect(quiet:FindFirstChild(Planter.GRID_FOLDER)).to.equal(nil)` and, after an OFF rebuild,
  `expect(world:FindFirstChild(Planter.GRID_FOLDER)).to.equal(nil)`. The defect itself is real and
  verified in `Places.build`. Fix: renumber to 22 — §13.3 tells 328i to *extend* that case, so a
  Builder will go looking for a case that is not there.
- `grid-terrain.md` §14 F-4 / §7.1 — cite "`grid.spec` case 15" for the identity. The assertion
  `expect(Plan.laneHalfWidth(plan) * 2).to.equal(Grid.CONFIG.roadClearStuds)` is in **case 12** ("the
  recipes and the zones"). Case 15 ("nothing in a road") is the one that asserts `gap > half`, which
  is what §7.1's *"Case 15 still passes: it asserts ≥ 21"* correctly describes — so one number is
  carrying two different cases. Fix: 12 for the identity, 15 for the ≥ 21.
- `docs/research/2026-11-02-terrain-v2.md` §3, §8 target 5 and `docs/research/INDEX.md`'s row — *"`Places.SPECIES`
  names 61 models in 7 groups"* and *"all 61 models"* are wrong: `SPECIES` names **35**
  (conifer 7, young 4, birch 8, oak 3, fieldOak 4, aspen 4, fern 5), and 61 is the `Workspace.OurForest`
  count from that table's own comment (*"61 models, 4,819 instances"*). The design's §9.2 already
  corrects it and finds the real hole is worse (33 of 35 planted templates seat at `clawFor` 0 — the
  `CLAW_FRACTION` ∩ `SPECIES.birch` intersection is only `SilverBirch_Var11_LOD_0` and
  `_Var13_LOD_0`, which I confirmed). Fix: the note's target 5 and the INDEX row should say 35, so
  328b is not sent to measure 26 templates the planter never clones.
- `2026-11-02-terrain-v2.md` §5's open-space table, carried into `grid-terrain.md` §12.1 target 9 —
  11.6 % and ≈ 17 % count **34 st each side** of every bounding road centreline (170,000 sq st
  exactly) against a denominator of the cell alone (1070 × 1430 = 1,530,100 sq st), but the cell
  boundary is 21 st from a centreline (`Grid.CONFIG.roadClearStuds` / 2), so ~13 st of each strip is
  outside the denominator. Counted strictly inside the cell, roads give ~4.3 % and the 36-st design
  falls **below** BASC's 10 % floor — which only strengthens the 54-st ruling, so no decision moves.
  Fix: name the convention beside target 9, or 328f will compute a different percentage and read it
  as red.
- `grid-terrain.md` §15 item 4 — *"cuts the worst corridor-to-ramp distance to ~75 st"*. With ramps at
  x ≈ 214, 535, 835 and `SWARM_DESIGN` §3.4's corridors at 160, 310, 460, 610, 760, 910, the worst is
  the corridor at **310**, 96 st from the ramp at 214, and the third ramp does not change it. 75 is the
  worst among the corridors the third ramp fixes. The three-ramp ruling stands either way — `Bots.Lane`'s
  ±20 jitter reaches neither 75 nor 96 — but 328h will measure against the wrong figure.
- `grid-terrain.md` §15 item 2 and §18 item 4 — attribute *"0.752 studs off its nominal shelf"* to
  `Lobby.Field`'s measurement. The sentence is `src/server/Places/Ground.luau`'s header, which credits
  **task 191**; it cites `Lobby.Field`'s header separately, for what a flat slab costs on a slope. The
  number is real and in the repo in half a dozen places; only the owner is misnamed.
- `grid-terrain.md`, whole document — it never names the feature-flag obligation for the feel-critical
  paths it creates: the prebuild/fallback arbiter, the 54-st ride, the frontage rule that turns A1's
  and C2's roadside thickets to birch. The only hit for "flag" in the file is `tools/flags.py clear` in
  §6.2's refusal list. The brief §5 did not ask for it, and §10.3 does give the arbiter's branches by
  parameter (`ForestTest.prebuildVerdict(live, planted)`), which is the testability half. Queue it so
  328b/328f do not land an unflagged feel-critical path.
- `reviews/task-328/REQUEST.md` claim 10 — *"the Builder committed them unmodified"* cannot be checked
  from the repo: every commit's `%an` is `KMargarjan`, so `git log --format=%an` distinguishes nothing.
  What is consistent: `bb3a8e0c` adds `docs/design/grid-terrain.md` and `ARCH_RESULT.md` in one commit,
  nothing else, and `ARCH_RESULT.md`'s trailer names `d1ca8e19`, which is the commit that added the
  BRIEF. Request prose, so a note only.

---
REVIEWER verdict on commit `934bc73d74ffd72ccb3b08ac913a0bc293d18f5b` (round 1) · 2026-11-02 09:07 UTC · session cost $4.50, 70 turns · written by tools/agents.py
