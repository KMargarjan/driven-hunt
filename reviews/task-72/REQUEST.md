# Task 72 — an asset-prep tool (headless Blender), first used on Karen's own shotgun

Task: 72
Round: 1
Base: `main` (`c995574`, which is the Task 71 merge — `git merge-base --is-ancestor origin/main HEAD`
is true, so the diff against main is tools-only and nothing under `src/` or `tests/` appears in it)
Code commit: `2006fb7a92a021035636879d05cbf0f86a695885`

```
[harness] PASS: 30/30 checks @ 2006fb7a92a021035636879d05cbf0f86a695885 (clean tree)
```

**`test2`: N/A.** `git diff --name-only origin/main..HEAD` is `.github/workflows/ci.yml`, `TASKS.md`,
two research files, this request and the two tool files. Nothing under `src/`, `tests/client/` or
`tools/studio_mcp.py`.

**This is the first review round: the gate refused the earlier attempt before any verdict was
written, so nothing has been reviewed yet.** That attempt shipped a real defect and my report to the
Director described what I meant to build rather than the picture. The Director looked at the renders;
I had not, properly. What follows is the state after finding the cause, fixing it, and building the
checks that make it fail in the tool instead of in his eye. Where the text below says "the first
attempt", that is the unreviewed code at commit `5b73292`; every claim is about the code at the
`Code commit:` above.

**The run to look at:** `<assets-dir>/prepped/shotgun_sxs_r2-20260926T213701Z/` — and it now
contains `source_*.png` (the untouched model) beside `render_*.png` (the prepped one), at the same
four cameras.

## Claims

1. **The defect was the region masks being applied upside down, and it was found by bisection.**
   `image_array` flips the image so row 0 is the top — which is what the classifier samples with —
   and `rasterise` indexed the mask with the UV **v** coordinate directly. So every region's mask was
   the **vertical mirror** of the pixels it then edited: the barrels' near-black was painted onto
   whatever wood texels sat at the mirrored position and the walnut onto the barrels. One line,
   `uv[:, 1] = 1.0 - uv[:, 1]`, with the reason written beside it.

2. **Every colour still reported dead on target while the gun was in camouflage**, because the
   median was measured through the same mirrored mask. The numbers agreed with each other and with
   nothing in the world — `docs/PROJECT_CONTEXT.md`'s "things measured correct and looked wrong".

3. **It was not the decimation, and that is measured, not argued.** With **no decimation at all**
   the damage was identical: 2.00× the source's edge density, against 1.92× when decimated. Both
   runs are in the evidence (`diag-decimate-…`, `diag-nodecimate-…`). With the mask fixed, a
   6,000-triangle run is clean too (`diag-dec6k-…`, 0.60–0.98×).

4. **Four new checks catch this class in the tool.** (a) The untouched source is rendered at the same
   four cameras every run. (b) An **edge-density ratio** compares prepped against source per view and
   warns past 1.25 — the first attempt measured 1.92, it now measures **0.37–0.88**. (c) Each region's
   colour is **sampled back through the mesh** — a different route from the mask that wrote it — and
   reported as `surface`; drift over 45/255 is a warning and a selftest failure. (d) The region map's
   **speckle** is measured and smoothed.

5. **The surface check is mutation-proved against the exact defect.** Restoring the flipped line
   makes the selftest fail with `the barrel surface really shows the colour it was given (shows
   RGB(203, 203, 205), asked RGB(26, 28, 34), drift 177)`. The fixture had to change for it to bite:
   its UVs are packed into half the atlas, because a symmetric layout cannot see a mirrored mask.

6. **Three more defects of the same family, each fixed at the class.** Region classification sampled
   **one texel** at a triangle's centroid, so a dark grain streak made a stock face read as metal —
   it is the median of seven samples per triangle now, then smoothed by neighbour majority. The
   per-region roughness and metallic were **painted into the shared maps** through triangle-shaped
   masks, which with the albedo untouched measured 1.4× on its own — they are **material values**
   now, one material per region, and the maps are copied out unchanged. Masks are **feathered**, so a
   region boundary is a ramp rather than a step.

7. **Blued steel, with the two numbers the right way round.** RGB(26, 28, 34) — the p25 of Karen's
   photo, cooled six points of blue — with **metallic 0.30 and roughness 0.55**. The first attempt
   had those two the wrong way round, 0.55 / 0.30, which is a mirror. Action RGB(172, 172, 172),
   metallic 0.45, roughness 0.42. Wood
   RGB(112, 80, 69) with the source grain kept: the levels mapping that clipped it into shards is
   gone, the median moves and each pixel keeps its relation to it.

8. **No decimation by default.** Roblox's *"Individual meshes can not exceed 20,000 triangles"* and
   this model arrives at **19,325** — already legal. At 6,000, photographed and compared side by
   side, the wrist of the stock facets and the barrel/forend join grows black wedges, because a
   decimated face straddling two regions can only take one region's colour. `--target N` still
   decimates on request and the report says which happened. A genuinely cheap low-poly wants the bake
   route (72a).

9. **What the four final renders actually show, looked at.** Side: near-black blued barrels with a
   soft sheen and no mirror, a silver action and trigger guard, a smooth medium-walnut stock and
   splinter forend with visible grain. Muzzle: **two bores side by side**, bright-rimmed, on a dark
   barrel block. Top: two parallel black tubes with the rib between them, silver breech, walnut
   tapering to the butt. Three-quarter: the same, and the closest to Karen's reference photo of
   anything this project has produced. **What is still wrong:** small black wedges remain where the
   barrels meet the forend, at both triangle counts — a face on a region boundary takes one region's
   colour, and the fix is to snap region boundaries to UV islands or geometry seams (72a).

10. **Measured colours, both routes agreeing.** barrel asked RGB(26,28,34) → wrote RGB(34,34,34) →
    surface shows RGB(34,34,34), drift 8. action asked RGB(172,172,172) → wrote → surface
    RGB(171,171,171), drift 1. wood asked RGB(112,80,69) → wrote RGB(112,80,69) → surface
    RGB(110,80,70), drift 2. Selftest **45 checks**; mutations re-run after the fix: the upside-down
    mask, the echoed triangle count, the skipped lights and the touched input all still fail it.

## Not verified

- **Nothing imported into Studio, nothing uploaded.** Karen's OK is needed first; every number is
  measured outside the engine and row 67a(b) is still open.
- **The edge-density ratio is not asserted on the selftest fixtures**, only measured — the fixture is
  a 2-unit bar whose two regions meet along its length, so a real boundary dominates a 240-pixel
  frame. It is asserted by warning on real runs, and the surface check is what the selftest asserts.
- **The black wedges at the barrel/forend join are still there** (claim 9), smaller at 19,325 than at
  6,000 but present in both.
- **The full selftest cannot run in CI** (no Blender on the runner).
- **Only one model has been through this.** The region names are the shotgun's, hard-coded in the
  Blender side.
