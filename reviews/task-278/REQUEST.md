# Task 278 -- the hit card shows where the shot struck, and every hit is logged

Task: 278
Round: 0 (PLAN ONLY -- no `src/` change yet)
Base: be4de11f
Code commit: (none yet)

## PLAN

Dispatch: `CORE-NA` -- a display and logging fix, the shot itself is not changed. Step 0(a) REAL
LIFE is therefore N/A; every other row is filled.

### (b) MEASURED NOW -- the reading, not the code

**Karen's own frame**, `<runs-dir>/design/karen-hitcard-2026-10-26.png`, measured in pixels
(`<runs-dir>/278/cardgeom.py` and the crop arithmetic in the report below):

| what | measured |
|---|---|
| plate | x 10..173 (164 px = `PLATE_WIDTH`), y 341..436 (96 px = `PLATE_HEIGHT`) -- so the art frame is x 18..166, y 349..429, 148 x 80 |
| the STAG's drawn ink | art-frame fractions **u 0.236..0.757**, v 0.037..0.988 |
| the red fatal dot | art-frame fractions **u 0.118**, v 0.438 |

The dot is **0.118 left of 0.236**: 17 px of empty plate in front of the stag's chest. That is
Karen's screenshot, as a number.

**Why**: `Hud.BoarArt.build` draws the silhouette with `ScaleType.Fit`, and `setKind` writes
`BoxU0..BoxV1` as if the image filled the art frame. The stag PNG is **750 x 758** (aspect 0.9894,
`<assets-dir>/deer/silhouettes/boxes.json`) and the art frame is 148 x 80 (aspect 1.85), so `Fit`
**pillarboxes** it: the image is drawn across only `0.9894 / 1.85 = 0.535` of the frame's width,
centred -- u 0.2326..0.7674. The measured ink, 0.236..0.757, is that rectangle. Every `u` the card
draws is therefore stretched across 148 px of frame when the animal only occupies 79 px of it.

**Zone coverage today**, `cardgeom.py report` (each zone box of `Boar.CONFIG(.SPECIES.reddeer).ZONES`
projected through `HitLog.Shape.rectOf`, 9x9 samples, counted against the PNG's own alpha):

| kind | head | chest | rear | legs |
|---|---|---|---|---|
| male | 0.81 | 1.00 | 0.81 | 0.80 |
| female | 0.83 | 1.00 | 0.83 | 0.86 |
| **stag** | **0.00** (centre 21.8 % of the width off the animal) | 0.62 | **0.09** | 0.06 |
| **hind** | **0.00** (centre 11.5 % off) | 0.63 | 0.23 | 0.05 |

A stag head shot draws, today, on empty plate. There is no probe-readable record of the last hit.

### (c) TARGET

1. Every zone's **centre on the animal's ink** for all six kinds, and the worst non-leg zone at or
   above **0.70** coverage. (`legs` is reported, never targeted: a deer's legs are thin and far
   apart, so a rectangle over them is mostly the air between them -- that is the picture, not the
   mapping. It is called out rather than hidden.)
2. A `[hitlog]` line and a `ServerStorage.DHLastHits` ring of the last 10, in Studio only.

### (d) LEVER -- the code that writes it, grepped

```
$ grep -n "ScaleType\|BoxU0\|GetAttribute(\"BoxU0\")" src/client/Hud/BoarArt.luau
120:		picture.ScaleType = Enum.ScaleType.Fit
238:	art:SetAttribute("BoxU0", inset + chosen.box.u0 * chosen.scale)
276:	local boxU0 = art:GetAttribute("BoxU0") or 0
```
`BoarArt.setKind` is the one writer of the box the dots are placed in, and line 238 is the line that
does not know about line 120. The fix composes the `Fit` rectangle into it, from a **measured** image
size per kind, through one new pure function in `Report`.

### What changes, and what deliberately does not

1. `Report.CONFIG.BOAR_IMAGE` gains `px` per kind, measured: male 946 x 474 and female 757 x 440
   (Karen's two JPGs re-keyed by task 205's own documented rule -- aspects 1.9958 and 1.7205, which
   are the "1.99 and 1.72" already written in that config), stag 750 x 758 and hind 805 x 662
   (`boxes.json`, the uploaded PNGs).
2. `Report.imageFit` / `Report.imageBox` -- pure, spec-driven: where `ScaleType.Fit` actually draws
   an image, and the unit square's rectangle in FRAME fractions. `BoarArt.setKind` writes what they
   answer.
3. The stag's and hind's `u1` are corrected from 1.000 to the **measured rump** (0.916 / 0.918).
   `u = 1` is the trunk's rear face; 1.000 was the image's right edge, which is the trailing hind
   hoof, so a rump hit drew behind the animal. This is the box's own stated rule applied, not a new
   one: `rear` goes 0.56 -> 0.74 (stag) and 0.60 -> 0.83 (hind).
4. **The boar boxes are NOT re-fitted.** The geometric rule was measured and LOOKED AT
   (`<runs-dir>/278/overlay-male-geom.png`): it puts the head grid in the air in front of the snout,
   because Karen's boar carries its head low and its withers high and the game's box does not --
   exactly what task 205's comment says. Their letterbox error is 3.7 % (male, vertical) and 3.5 %
   (female, horizontal), and both already score >= 0.80.
5. **`Report.ontoBoar` is NOT changed.** It snaps to the fourteen-part BOAR outline, which is a wart
   on a deer -- so it was measured instead of assumed: over all six kinds it moves one dot (the deer
   head centre) by 0.076 of the unit square and changes no on/off verdict.
6. **The shot is not touched.** No `Weapon/`, `Ballistics/`, `Flight`, zone box or damage change.

### (e) HOW IT WILL BE MEASURED AFTER

The same `cardgeom.py` table, plus the live proof on Karen's path: `DHTestRelease` staged deer and
boar, `aimshot.py` real clicks at chest / shoulder / rump, and for each shot the `[hitlog]` line
beside the captured card frame with the dot measured against the drawn ink in that frame's pixels.
