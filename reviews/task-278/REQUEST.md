# Task 278 -- the hit card shows where the shot struck, and every hit is logged

Task: 278
Round: 1
Base: be4de11f
Code commit: 582f1e985854d3213d49cb01b07c98c14a35d1c0

```
[harness] PASS: 34/34 checks @ 582f1e985854d3213d49cb01b07c98c14a35d1c0 (clean tree) scope=all
```

`test2`: **N/A.** Nothing changed under `TWO_PLAYER_PATHS` -- the four files are
`src/shared/Report/init.luau`, `src/client/Hud/BoarArt.luau`, `src/server/HitLog/init.luau` and
`src/server/HitLog/Shape.luau`, plus two spec files of the same two systems. A second client draws a
second copy of one player's own card and answers nothing the first did not.

## PLAN

`CORE-NA` per the dispatch: a display and logging fix; the shot is not changed. Step 0(a) REAL LIFE
is N/A. (b)-(e) are below, and the plan was committed before any `src/` edit (`e05615dd`).

### (b) MEASURED NOW

**Karen's own frame**, `<runs-dir>/design/karen-hitcard-2026-10-26.png`, measured in its own pixels
by `<runs-dir>/278/measure-card.py`:

```
plate x 10..173 (164 px) y 341..436 (96 px)      <- PLATE_WIDTH 164, PLATE_HEIGHT 96
  ink  u 0.230..0.770  v 0.037..1.000            <- the stag, in the 148 x 80 art frame
  DOT  u 0.122 v 0.444  ring-at-9px on ink 0/72 (0%)  nearest ink 16.8 px
```

Not one pixel of the ring around that dot is animal. It is 16.8 px of bare plate in front of the
stag's brisket -- her screenshot, as a number.

### (c) TARGET

Every zone's centre on the animal's ink for all six kinds, the worst non-leg zone at or above 0.70
coverage, and on a live shot the ring around the drawn dot on ink. `legs` is reported and never
targeted: a deer's legs are thin and far apart, so a rectangle over them is mostly the air between
them -- the picture, not the mapping.

### (d) LEVER

```
$ grep -n "ScaleType\|SetAttribute(\"BoxU0\"" src/client/Hud/BoarArt.luau   # before the change
120:		picture.ScaleType = Enum.ScaleType.Fit
238:	art:SetAttribute("BoxU0", inset + chosen.box.u0 * chosen.scale)
```

Line 238 did not know about line 120. `ScaleType.Fit` preserves the image's aspect and CENTRES it;
the `box` is measured in fractions of the PNG and was being applied to fractions of the FRAME. A
750 x 758 stag in a 148 x 80 frame is pillarboxed into the middle 53.5 % of the width, leaving 23 %
of bare plate down each side.

### (e) HOW IT IS MEASURED AFTER

The same two instruments: `<runs-dir>/278/cardgeom.py` for the zone table, and
`<runs-dir>/278/measure-card.py` for a captured frame -- the function that produced the "before"
line above, run again on the "after" frames.

## STEP 1 -- REPRODUCED ON HER PATH

Reproduced twice over: on her own frame (the measurement above) and in the Forest Test, where
`ReplicatedStorage.Report` was probed live and confirmed to be running this branch
(`stag px=750x758 u1=0.916 imageFit=true fitStagU0=0.2326`) before any shot was fired.

## STEP 2 -- ITERATION

| # | change | measured (zone coverage, 9x9 samples against the PNG's alpha) | to target |
|---|---|---|---|
| 1 | none (the committed code) | stag head **0.00** (centre 21.8 % off the animal) / chest 0.62 / rear 0.09; hind head **0.00** / chest 0.63 / rear 0.23; male worst 0.80 | head and rear fail outright |
| 2 | `Report.imageFit` composed into the box | stag head **0.99** / chest 0.85 / rear 0.56; hind head 0.40 / chest 0.88 / rear 0.60; male worst 0.83 | rear still short of 0.70 |
| 3 | + the boars' box refitted geometrically | male head grid lands **in the air in front of the snout** (`<runs-dir>/278/overlay-male-geom.png`, looked at) -- REFUSED, and task 205's own comment says why: this boar carries its head low and its withers high and the game's box does not | rejected |
| 4 | + the deer `u1` corrected to the measured rump | stag head 0.99 / chest 0.83 / **rear 0.74**; hind chest 0.83 / **rear 0.83**; male and female unchanged (worst 0.83 / 0.93) | met |

Every zone centre is on ink for all six kinds except the HIND's head, which is 3.3 % of the width out
(~3 px on the card, under half a dot) and is reported rather than hidden: a deer carries its head
ABOVE the trunk box, so `Shape.dot` clamps a head hit to v = 0 -- the back line -- and on the hind
that line passes just in front of her throat. Moving it means moving a hit zone, which this task does
not touch.

## STEP 3 -- LIVE PROOF, in the Forest Test, real clicks

Karen's place (130094961655666), her own `DHTestOwns` and flags untouched, `DHTestRelease` staged and
consumed, `aimshot.py`'s click path through `<runs-dir>/278-shot.py`. Three hits, each with the
server's line, the client's drawn dot, and the captured frame measured by the same function that
measured her screenshot:

| frame | `[hitlog]` (server) | drawn | ring at 9 px on ink |
|---|---|---|---|
| `<runs-dir>/278-stag-chest.png` | `#1 t=19.07s stag id=Boar11 zone=chest local=(-0.96,1.40,-0.53) uv=(0.425,0.209) dist=39.2 shotgun/Slug pellets=1 fatal=no` | u 0.443 v 0.525 | **71/72 (99 %)** |
| `<runs-dir>/278-stag-rump.png` | `#2 t=90.33s stag id=Boar28 zone=body local=(0.90,1.79,1.27) uv=(0.681,0.127) dist=38.6 shotgun/Slug pellets=1 fatal=no` | u 0.564 v 0.481 | 49/72 (68 %) |
| `<runs-dir>/278-boar-chest.png` | `#1 t=17.57s male id=Boar5 zone=rear local=(-1.06,0.71,1.13) uv=(0.705,0.262) dist=47.0 shotgun/Slug pellets=1 fatal=no` | u 0.659 v 0.381 | **72/72 (100 %)** |

**Against Karen's own before-frame: 0/72.** The two zoomed crops were opened and looked at
(`<runs-dir>/278/before-karen-zoom.png`, `after-chest-zoom.png`, `after-boar-zoom.png`): before, the
red diamond floats in bare plate in front of the stag's brisket; after, it sits behind the stag's
shoulder, and the boar's dot sits on the hindquarters just in front of the tail -- `zone=chest` and
`zone=rear`, which is what the two log lines say.

The 68 % row is the honest one and is not a miss: the slug struck `body` at local y +1.79 of a
4.8-stud box, which is the loin, and the dot is drawn on the back where the outline curves -- so part
of the ring is sky by construction. Its nearest ink is 5.0 px, which is the dot's own radius.

**NOT OBTAINED: a stag HEAD hit.** 13 real clicks across two staged releases at `ZoneHead`, 55-56
studs, no hit -- a deer's head zone is 1.0 x 1.1 x 1.7 studs on a walking animal and this instrument
does not swing. The head mapping is evidenced by the zone table (0.99) and the overlays, not by a
live frame. The dispatch asked for a shoulder shot: the chest hit above is one -- local z -0.53 is
exactly where the front legs attach (`Boar.CONFIG.SPECIES.reddeer.ZONES.chest`).

## Claims

1. **The root cause is the `Fit` letterbox, and it is measured, not argued.**
   `tests/server/hit_card.spec.luau` -> "Report.imageFit answers the letterbox, the pillarbox and the
   unmeasured image" computes the expected rectangle with its OWN arithmetic and gets
   u0 = 0.232582 for a stag -- the 0.230 measured off Karen's screenshot.
   *Verify:* read that case; it never calls `Report.imageFit` to compute what it expects.
2. **The fix is one composition in one place.** `Report.imageFit` (where `Fit` draws an image) and
   `Report.imageBox` (label inset, then fit, then box) are pure; `BoarArt.setKind` writes what they
   answer into `BoxU0..BoxV1`, which `drawDots` already read. `BoarArt.build` writes
   `FrameWidth`/`FrameHeight` so `setKind` has the frame's aspect at show time without `AbsoluteSize`,
   which is 0 on a frame built hidden.
   *Verify:* `src/shared/Report/init.luau` `Report.imageFit`/`Report.imageBox`;
   `src/client/Hud/BoarArt.luau` `BoarArt.setKind`, `BoarArt.build`.
3. **`BOAR_IMAGE` gains `px` per kind, all four measured.** stag 750 x 758 and hind 805 x 662 from
   `<assets-dir>/deer/silhouettes/boxes.json` (the uploaded PNGs); male 946 x 474 and female
   757 x 440 from Karen's two JPGs re-keyed by task 205's own documented rule, which reproduces the
   "1.99 and 1.72" already written in that config to four figures (1.9958, 1.7205).
   *Verify:* `Report.CONFIG.BOAR_IMAGE`; `boxes.json`; `<runs-dir>/278/cardgeom.py`.
4. **The deer `u1` is corrected from 1.000 to the measured rump (0.916 / 0.918).** `u = 1` is the
   trunk's rear FACE; 1.000 was the image's right edge, which on both deer is the trailing hind hoof.
   `rear` coverage 0.56 -> 0.74 (stag) and 0.60 -> 0.83 (hind).
   *Verify:* step 2's table rows 2 and 4; the comment at `Report.CONFIG.BOAR_IMAGE`.
5. **The boars' boxes are deliberately NOT re-fitted, and the alternative was looked at.** The
   geometric rule was applied to them and rendered: it puts the head grid in the air in front of the
   snout. Their letterbox error is 3.7 % (male, vertical) and 3.5 % (female, horizontal) and both
   score >= 0.80 before the change.
   *Verify:* `<runs-dir>/278/overlay-male-geom.png` against `final-male.png`.
6. **`Report.ontoBoar` is NOT changed, and that is a measurement.** It snaps to the fourteen-part
   BOAR outline, which is a wart on a deer -- so it was measured: over all six kinds and all four
   zone centres it moves exactly one dot (the deer head centre) by 0.076 of the unit square and
   changes no on-ink verdict.
   *Verify:* the arithmetic is in `<runs-dir>/278/cardgeom.py`; `Report.ontoBoar` is untouched in the
   diff.
7. **Every server-confirmed hit writes a line, and the last ten are probe-readable.**
   `Shape.traceLine` is pure; `HitLog.recordHit` writes one line with the time, the kind, the id, the
   zone, the local offset in the animal's frame, the `(u, v)` the card is drawn from, the distance,
   the gun and ammunition, the pellet count and `fatal`; `recordDown` writes a SECOND line marking
   the kill rather than editing the first. Studio only, both the `print` and
   `ServerStorage.DHLastHits`, through `RunService:IsStudio()`.
   *Verify:* `tests/server/hit_card.spec.luau` -> "writes one hit-log line per hit..." and "keeps the
   last ten hits, newest last, and clears with the drive"; the three live lines in step 3.
8. **The three proof cases FAIL when the fix is deleted.** `Report.imageFit` was made to return the
   identity rectangle -- exactly the pre-task behaviour -- and the harness was run at the same
   commit: `FAIL: 30/34`, with `hit_card.spec:350`, `hit_card.spec:393` (server) and
   `hit_card.spec:454` (client) the only three failures in 2,951 cases. The mutation was then
   reverted and the tree is clean at the code commit.
   *Verify:* re-apply the one-line mutation and run `test`.
9. **The card and the log agree on every live shot**, which is the pair the dispatch asked for: the
   drawn `(u, v)` in the "drawn" column of step 3's table is the `uv=` in the same row's log line, to
   three decimals, and the zone named in the line is the body part the dot was looked at on.
10. **The shot is untouched.** No `src/server/Weapon/`, `src/shared/Ballistics/`, `Flight`, kill zone,
    damage number or animal reaction is in the diff.
    *Verify:* `git diff --stat be4de11f..582f1e98 -- src` is four files, none of them those.

## What could not be verified

* **A live stag HEAD hit** -- 13 real clicks, none landed (above). The head mapping rests on the zone
  table and the overlays.
* **The hind and the calf, and the piglet, live.** No hind or cub was in range during the three
  sessions. They are covered by claim 3's spec case over all six kinds and by the overlays, which
  were looked at.
* **The scoped rifle.** Karen's frame was `.416`; every shot here was the Shotgun's slug, because the
  Forest Test hands a Shooter the shotgun and the rifle needs a shop purchase. The card does not read
  the gun for placement -- only for the label's words -- and claim 9 shows the gun's id travelling
  through the log instead.
