# Task 69 — the boar's colours, and a prep tool that can read an animal

Task: 69
Round: 1
Base: `main` (`96e13ae`)
Code commit: `7c0b6823f983361159fdc8d52a5e2d98c730fe34`

```
[harness] PASS: 30/30 checks @ 7c0b6823f983361159fdc8d52a5e2d98c730fe34 (clean tree)
```

**`test2` is N/A.** The change touches `tools/` only — no `src/`, no `tests/`, and not
`tools/studio_mcp.py` — which CLAUDE.md's git-workflow step 4 exempts ("the tools that are not the
harness"). Nothing in the game moved: `[tests:server] PASS: 408 passed`, client 86, both unchanged.

**No Meshy credits were spent and nothing was uploaded.** Karen's OK of 2026-09-26 covers her
shotgun and one asset; the boar reaching Roblox is a separate decision (69a(c), and the report's
Needs).

**What changed.** `tools/asset_prep.py` (the region plan and the view set become recipe data;
`ANIMAL_RECIPE`; `--preset`; `--model`; `find_model` takes `.glb`/`.gltf`; `check_recipe`; the
selftest's third fixture), `tools/asset_prep_blender.py` (GLB import; `split_packed_shine`;
`rule_matches`/`apply_plan`; `soft_band`/`soft_weights`/`rasterise_weights`; views from the recipe),
`.github/workflows/ci.yml` (both presets validated), `docs/research/2026-09-27-animal-recolour.md`
and its INDEX row, `TASKS.md` rows 69/69a.

## Claims

1. **The gun is untouched, and that is measured rather than argued.** Karen's shotgun re-run through
   the new region engine from its own `source/` copy gives **barrel 8,125, action 6,456, wood
   4,744** — the same three counts as the Task 75 run, the same mask pixel counts (1,315,803 /
   896,654 / 1,076,014), the same `speckleBefore 0.0013 / after 0.0 / reassigned 26`. The gun's
   three lines of Python are now three rules in `DEFAULT_RECIPE["regionPlan"]`. One thing did move
   by a hair and it is written up as 69a(d): paint ORDER.
2. **The region plan is data and it is refused when it cannot decide.** `check_recipe` runs before
   Blender is started and refuses a plan with no catch-all, or one naming a region the recipe gives
   no colours for. Selftest: three refusal checks, plus "both presets are complete enough to run",
   and CI now runs `recipe --preset animal` for the same reason.
3. **A `.glb` is accepted.** `find_model` prefers `.fbx`, then `.glb`, then `.gltf`, shortest path
   first, and `--model` names one. Proved on a fixture folder holding `model.glb` and a
   `preview.glb` decoy — which is the real Meshy run folder's shape.
4. **glTF's packed metalness-roughness map is split, not refused.** Khronos, quoted in the note and
   the code: metalness from B, roughness from G. The selftest's GLB fixture ships R=1.0, G=0.62,
   B=0.0 and leaves every band's roughness target at `None`, so what the roughness map reads back —
   **0.62 for every region** — is proof of the channel and of nothing else. Taking R gives 1.0 and
   taking B gives 0.0; both fail it (mutation 2).
5. **The split hands back its pixels, and that is this task's real defect.** A
   `bpy.data.images.new` datablock is GENERATED and Blender may free its buffer; across the region
   and mask pass it comes back BLACK. Measured: `split_packed_shine` tested on its own returned
   roughness 0.6196 and metalness 0.0000, and the full run it was part of wrote a roughness map of
   **zeros** — with every number in the report agreeing with itself. The caller uses the returned
   arrays now. See `REPORT["packedShineMap"]["medians"]` and `shine.images`.
6. **A band boundary is softened on the MODEL.** `soft_weights` gives a face near a height band's
   edge a partial weight in both bands and `rasterise_weights` paints that weight. Blurring the
   finished mask instead was tried and measured: at 110 texels every region's mask covered the whole
   2048 atlas and the snout finished 59 off target, because a generator packs unrelated UV islands a
   few texels apart.
7. **A ramp may only reach another soft band.** It is a function of height alone, so without the
   restriction the flank's ramp covers the boar's tusks — which sit at half the animal's height —
   and coat colour, painted later in plan order, goes over the ivory. The GLB fixture's `nose`
   region is decided by position, spans every height, and is asserted to keep its own metalness and
   colour; with the restriction removed it reads 0.323 against 0.95 (mutation 1).
8. **The boar's own run.** `<assets-dir>/prepped/boar_body_r4-20260927T023645Z/`: regions back
   2,460, flank 2,495, snout 324, tusk 146, underside 763; every colour within **6–13** of 255
   against a ceiling of 45 and every shine within **0.04** of a ceiling of 0.08; no warnings; input
   proved byte-for-byte unchanged; maps out at **2048** from a 4096 source.
9. **Rule 1 and rule 5 both.** The research note was written before the code, with five sources and
   their licence and maintenance status. Four renders were inspected at each of four runs and what
   they show — including what is still wrong — is in the report and in 69a.
10. **Mutations.** Three applied, run and restored: the ramp unrestricted (claim 7 fails), the split
    taking R instead of G (claim 4 fails), and `check_recipe`'s catch-all guard removed (it accepts
    a plan it must refuse). A fourth was observed live rather than staged — claim 5's black buffer
    failed the run that found it. Selftest **81 checks**, from 54.

## What I could not verify

- **Whether these are the right colours.** They are the Director's pick from the model's own texture
  and Karen's to change; only a playtest answers it. Every number is one line of the recipe.
- **The renders are one studio and one light rig** — an 18 % grey room, three area lamps. Nobody has
  seen this boar in the game's own daylight, which is exactly where Task 74's gun surprised everyone
  (69a(g)).
- **The band boundary is still slightly visible** in the side render, as an irregular tonal break
  where the ramp crosses triangles. A horizontal ramp cannot follow a sloping back (69a(a)).
- **The belly reads warm tan**, kept from the source texture (69a(b)).
- **`tools/asset_prep.py`'s selftest needs Blender and cannot run in CI** (72a(e)). It ran here, 81
  checks, three times: before the mutations, under each, and after restoring them.
