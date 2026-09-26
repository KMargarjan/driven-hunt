# Task 72 — an asset-prep tool (headless Blender), first used on Karen's own shotgun

Task: 72
Round: 1
Base: `main` (`c995574`)
Code commit: `5b732923c5b9a4a41df4c17b19ac8bc4575e4b77`

```
[harness] PASS: 30/30 checks @ 5b732923c5b9a4a41df4c17b19ac8bc4575e4b77 (clean tree)
```

**`test2`: N/A.** Nothing under `src/`, `tests/client/` or `tools/studio_mcp.py` changed — this is
`tools/` plus docs plus one CI step (git workflow step 4's exemption for tools outside the harness).

**What changed.** New `tools/asset_prep.py` and `tools/asset_prep_blender.py`, new
`docs/research/2026-09-26-asset-prep.md` (+ `INDEX.md`), one CI smoke step, `TASKS.md` rows 72/72a.
**No `src/`, no `tests/`, nothing uploaded, no network call, no credit spent.**

**The run on Karen's gun:** `<assets-dir>/prepped/shotgun_sxs-20260926T211709Z/` — `recipe.json`,
`report.json`, three corrected textures, four renders, `model.fbx`, `model.glb`, and the untouched
copy of her input under `source/`.

## Claims

1. **Research before implementation (rule 1).** Five sources with licence and maintenance status.
   Roblox's limits are quoted, not remembered: *"Individual meshes can not exceed 20,000 triangles"*,
   *"up to 4096x4096 pixel texture resolutions"*, metalness and roughness *"Single Channel Grayscale
   (8-bit)"*. **The Blender manual's command-line page renders to a fetcher as a navigation tree,
   twice**, so `--background` / `--python` / `--` was **measured** here instead — along with Blender
   5.2.1 LTS, numpy 2.3.4 bundled, and only `BLENDER_EEVEE` available in this build. The note says
   which claims are quoted and which are measured.

2. **The licence split is deliberate and is the reason there are two files.**
   `tools/asset_prep.py` never imports `bpy` — it spawns a process — and carries the repository's
   terms. `tools/asset_prep_blender.py` runs inside Blender and carries an SPDX
   **GPL-2.0-or-later** header, which is what the Blender Foundation asks of a published script
   written for Blender. That the repo itself has no LICENSE file is queued as 72a(a), not decided
   here. Verify: grep both files for `import bpy`.

3. **It never modifies the input, and it proves it rather than promising it.** The input folder is
   copied into the output's `source/` and Blender only ever reads the copy; the driver hashes every
   input file before and after and **fails the run** if anything changed or appeared. This exists
   because Blender's FBX importer extracts embedded textures into a `.fbm` folder *next to the file
   it reads* — on this model it happened not to, which is not a guarantee. Verify: `prep()` in
   `asset_prep.py`, and mutation 1 below.

4. **The triangle count is measured, and checked by an independent second count.** The Blender side
   measures the evaluated mesh; the driver then parses the exported **GLB's own index accessors**
   (`glb_triangles`, stdlib only, different process, different code) and the selftest asserts the two
   agree. Karen's gun: **19,325 → 5,999** against a 6,000 target.

5. **Regions are decided by position AND colour, because neither alone can work.** The barrels and
   the action are both neutral grey in one atlas, so colour alone merges them; the forend sits under
   the barrels and shares their span, so position alone merges it with them. The rule is: woody
   colour wins anywhere, otherwise forward of `actionStartT` is barrel and behind it is action.
   `actionStartT = 0.62` is the 486 Parallelo's own published barrel fraction (28 in of 45 in), the
   same number `src/server/Weapon/Shape.luau` is built from. Karen's gun split 2,481 / 1,971 / 1,547.

6. **Which end is the muzzle is measured, not assumed** — the shallower end of the model's own
   slices — and the report says which end it picked, so a reversed model is visible rather than
   silently colour-swapped.

7. **The correction keeps the detail by construction, and the tool measures what it achieved.** Each
   region's masked pixels move in HSV so the region's median lands on a target while every pixel
   keeps its relation to it; grain and engraving are variation around the median. Targets are sRGB
   triples sampled from Karen's own reference photographs and converted to scene-linear.
   **Asked → got:** barrel RGB(34,35,37) → **(37,37,37)**; action RGB(172,172,172) →
   **(172,172,172)**; wood RGB(112,80,69) → **(116,83,72)**.

8. **Three bugs found by looking, not by reading (rule 5), each fixed with its reason in the code.**
   (a) The first four renders were **pure black** — the lighting function was written and never
   called, and my "file is bigger than 2 KB" check passed them. (b) The colour targets were sRGB
   numbers applied to Blender's **linear** float pixels, so the gun came back chrome and orange.
   (c) `metallic = 1.0` made every surface a mirror of the preview room, so a dark albedo rendered
   white and a bright one rendered black. Each is now a named constant with the measurement beside
   it.

9. **The selftest is offline and does not need Karen's model: 39 checks, two fixtures.** One fixture
   is neutral (only the position rule can split it) and one is woody (only the colour rule can), so
   neither result depends on where the unwrapper happened to put an island. It also proves the four
   refusals — inside the repo, a non-empty output, no FBX, a non-GLB handed to the GLB reader.

10. **Four mutations, each applied, the selftest run, then restored** (`git status` is clean):
    writing a file into the input → `THE INPUT FOLDER CHANGED during the run (MUTATION.txt)`;
    echoing the triangle target instead of measuring → the GLB cross-check fails (`GLB says 300,
    report says 307`); skipping the lights → all four renders fail `is lit, not a black screen`
    (`spread 0.0039, subjectFraction 0.0`); collapsing every face into one region → five checks fail.

## Not verified

- **Nothing has been imported into Studio and nothing uploaded.** Karen's explicit OK is needed
  first. Every number here — triangles, map sizes, colours — is measured outside the engine, and row
  67a(b) (nobody has imported a `.glb` into Studio) is still open.
- **The wood still reads as hard-edged dark shards rather than grain.** The median is on target, but
  Meshy bakes near-black angular figure into the base colour and no per-pixel correction turns that
  into walnut — 72a(b), and the fix is a different texture, not another knob.
- **The preview's top view blows out to chrome** on glossy cylinders lit from above; judge colour
  from the side and three-quarter renders (72a(c)).
- **The full selftest cannot run in CI** — there is no Blender on the runner — so CI gets a smoke
  step that loads the module and parses the default recipe (72a(e)).
- **Only one model has been through it.** Region names are the shotgun's and are hard-coded in the
  Blender side (72a(f)).
