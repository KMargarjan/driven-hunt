# Task 236 — a little lighter during the hunt

Task: 236
Round: 1
Base: a0cac0b5 (main)
Code commit: c7731e8600313b942a94fd4b3728c9b58472790a

`[harness] PASS: 34/34 checks @ c7731e8600313b942a94fd4b3728c9b58472790a (clean tree) scope=all`

`[harness2]` **N/A** — not one changed path is in `TWO_PLAYER_PATHS` (`src/server/Light/`,
`src/client/Hud/Style.luau` and two specs). An exposure stop looks the same to one player as to two.

## What changed

Karen, 2026-10-21: *"make a bit lighter when hunting now is a bit to dark"*. **One row of the
Designer's lighting spec moves and nothing else does**: `Light.CONFIG.LIGHTING.ExposureCompensation`
0.15 → **0.55**, +0.40 EV, the middle of the dispatched +0.30..+0.50 range. Its spec pin follows it.
Two comments that the change makes false are corrected (`src/client/Hud/Style.luau` and
`tests/client/hud_style.spec.luau`); **no value in either file moves**. The research note gains
section 6 and its INDEX row gains the same summary.

## Claims, and how to verify each

1. **Exactly one number in the shipped look changes.** `git diff a0cac0b5..c7731e86 -- src/` shows
   two files: `src/server/Light/init.luau`, where the only non-comment line is
   `ExposureCompensation = 0.55`, and `src/client/Hud/Style.luau`, where the diff is comment lines
   only (`Style.SLATE_T` and every other token is untouched). Same for `tests/`: the `0.15` → `0.55`
   pin in `tests/server/light.spec.luau` plus comments.

2. **It is the right knob, and the two alternatives were refused with measurements rather than
   taste.** The comment above `ExposureCompensation` in `Light.CONFIG` and section 6.1 of
   `docs/research/2026-10-19-one-owner-for-the-lighting.md` give the reason: exposure has no hue
   term and no fog term and scales lit and shaded by the same factor; `Brightness` lifts the sun
   alone and widens the 2.7 : 1 the spec's §1 builds its softness out of; `Ambient` is the spec's
   own named rescue knob and task 215 measured it losing boar separation (2.91 → 2.65, recorded in
   that note's INDEX row and in `light.spec`).

3. **The lift was measured on the player's own path, in one Play session, with one camera per
   scene.** `<runs-dir>/t236/shoot.py` stages a camera once and then photographs every exposure
   value from it **without moving it**, so a before/after pair differs in exactly one number — same
   spot, same clock (`ClockTime` is a constant in the table), same eye height, same framing, same
   zoom (L-021, which this system rediscovered in task 215 round 2). `cameras.json` holds the staged
   positions and the probe's read-back of where the character actually landed.

4. **The numbers.** `<runs-dir>/t236/measure.py` re-runs on the committed frames. Mean BT.601 luma
   of the **world band** (the HUD's top 13 % and bottom 12 % are cut out, so a white glyph cannot be
   counted as sky nor the dark slate as shade): stand 113.71 → 132.40, tree belt 109.99 → 127.95,
   field 116.07 → 134.79 — **+16.4 / +16.3 / +16.1 %**. 0.45 gives +12 %, 0.65 gives +20 %.

5. **The dark end, which is what "too dark" means, moves more than the mean.** Same script: the
   darkest tenth of the tree-belt frame **4.92 → 8.09 (+64 %)**, the share of that frame under luma
   24 **12.14 % → 8.96 %**. On the two open scenes the darkest tenth goes 13.99 → 16.41 and
   14.83 → 17.34.

6. **It costs no frames.** `cameras.json`'s `frame_exp0.15` and `frame_exp0.65` are a 6 s
   `RenderStepped` sample at the same camera: 60.0 fps both, mean 16.666 ms against 16.665 ms.

7. **The HUD still clears its floor, and the reason it does is the insurance task 215 took.** The
   brightest sky (99th percentile of 441k sky pixels found by colour across the three scenes, not by
   a box — t215's own lesson) goes `#B5D1D4` luma 201.0 → `#C7E1E2` luma 217.3, which is **over** the
   `#B4CFE4` (201.3) that design-system.md §2 tested. So §6's conditional — *"if the lighting pass
   makes the sky brighter than `#B4CFE4`, the ONE knob is `SLATE_T`"* — is met for the first time,
   and `Style.SLATE_T` is **already** at the 0.14 it asks for. Measured over the new sky the
   tightest colour, `BLAZE_HI`, is **5.01 : 1** against a floor of 4.5 (it was 5.18). That is why
   the two comments are corrected and no value is: `Style.luau`'s paragraph previously said §6's
   trigger "is not met", which is now history rather than the live reading.

8. **A boar in open shade separates less, and the figure is given rather than skirted.** Against the
   ground it stands on: **2.66 : 1 → 2.20 : 1** (flank 6.56 → 13.20 luma, shaded ground
   17.44 → 29.00); against sunlit ground beyond the shadow edge 15.76 : 1 → 9.61 : 1
   (`<runs-dir>/t236/boarmeasure.py`, which saves each sampled box as a 5× crop — they were looked
   at, and the first flank box was re-cut after the crop showed grass in two corners). Both are far
   above the 1.5 : 1 of the note's §5 and the sign never flips: the boar stays the darker shape.

9. **The frames prove the COMMITTED table, not a property somebody set by hand.**
   `<runs-dir>/t236/confirm.py` runs a fresh Play on the clean tree and only reads: the console
   carries `[LightBoot] AUTUMN_LIGHT is on: 29 property(ies) written on Lighting and its children`,
   the live read is `Exp=0.550` with `Amb`, `Out`, `B`, `CT`, `EDS`, `CC S` and `CC C` all unchanged,
   and the re-shot frame reproduces the sweep's 0.55 to 0.3 % (132.79 against 132.40). Zero
   "Stack Begin", "attempt to" or "invalid argument" lines in that console.

10. **The two things this does NOT prove are written in the note (§6.4) and not only here.**
    *(a)* **DEV is not the forest.** The Forest Test was closed by the dispatch, so these are DEV
    frames with DEV's grey-box tie-trees and DEV's own `Sky`. The Forest Test's sky measured
    `#94B9D3` (176.9) in task 215; the same +0.40 EV should land it near 205, which is an
    interpolation from this task's own scaling and **not a measurement**. *(b)* **The lodge is not
    photographed** — DEV has none. `ExposureCompensation` is one table written in every world, so
    the lodge task 215 warmed gets the same +0.40 EV; exposure has no hue term, so its warm/orange
    character is unchanged and only its level moves, by the same ~16 %. If it reads too bright the
    knobs are `Lobby.CONFIG.LODGE`'s `LANTERN` and `FIRE_LIGHT`, a different owner and a different
    task. Both are for the morning smoke.

## Could not be verified

* **What Karen will think of it.** +0.40 EV is a pick, not a measurement, and the nudge is this one
  number: 0.45 is a third less lift, 0.65 a quarter more, every figure above interpolates.
* **The forest and the lodge**, per claim 10. No Forest Test frame exists for this change.
* **A phone.** Every frame-time figure is Studio's, as task 215's was.

## Housekeeping

`stylua --check src tests`, `selene src`, `selene --config tests/selene.toml tests`,
`python tools/studio_mcp.py selftest`, `python tools/agents.py selftest`,
`python tools/privacy_scan.py selftest` and `scan` all clean (rule G).
