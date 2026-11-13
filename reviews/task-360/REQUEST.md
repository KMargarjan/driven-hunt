# Task 360 -- dense forest behind the main-road stands

Task: 360
Round: 1
Base: 9bf829f7
Code commit: (filled in at the code commit)

## PLAN

**(a) REAL LIFE.** A managed 40-80 year stand carries 2-3 m between stems and a second storey of
young growth; C1's own wood is built to exactly that (`minGapStuds` 11 ~ 3.1 m, canopy 16-26 studs,
`BIRCH_UNDER` saplings at 30). Karen's own standard, 2026-11-04, is C1's interior: *"rest seems ok
I think you did good job"*. Behind the road there is no second storey at all.

**(b) MEASURED NOW.** Two instruments, and **they disagree -- which is the finding**:
* the task 352 plan instrument (`<runs-dir>/360-measure.luau`, `360-BEFORE.txt`) reads the back half
  at stands 1-7 as **91.7-100 %** road-excluded hits within 150 studs. **The dispatch's >= 90 % target
  is already met BEFORE any change.**
* a real **eye-height raycast against the drawn models** in Karen's Forest Test
  (`<runs-dir>/360-ft-eye.luau`, `360-FT-BEFORE.txt`) reads the same back half as
  **24.2 % wooded within 150 studs, and 40.5 % of rays escape 900 studs of nothing.**

The plan instrument counts a crown the eye can see UNDER: it blocks on `crownHalfWidthStuds` at any
height, and `TEMPLATE_DIMS` carries no crown base. Karen's frame
(`<runs-dir>/360-karen-behind-stand.png`, opened: high crowns, bare trunks, mown grass between them,
green hills and a blue ridge straight through at eye height) is the raycast's answer, not the plan's.
**So the eye-height raycast is this task's instrument** (V293: the contradiction is reported in the
round that writes the fix).

**(c) TARGET.** Back half at stands 1-7, eye height 5 studs: **escaped rays <= 10 %** (today 40.5 %)
and **>= 60 % wooded within 150 studs** (today 24.2 %). "Escaped" is Karen's sentence as a number --
a ray that leaves 900 studs of wood is a hill on her screen. 150 studs is the dispatch's distance;
60 % and not 90 % because the main road itself runs through the back half and is never planted.

**(d) LEVER.** `src/shared/Places/init.luau`, `Places.skirtBands` -- the only writer of the wood
behind a road. Pasted:

```
2915:		{ near = 0, far = plan.skirtFullStuds, spacing = plan.spacingStuds, widen = 0 },
2916:		{ near = plan.skirtFullStuds, far = plan.skirtStuds, spacing = plan.deepSpacingStuds, widen = 0 },
2923:			spacing = plan.deepSpacingStuds,
```

Measured today behind C1's main line (`<runs-dir>/360-bands.luau`): band 1 (0-80 studs) 148 sites at
24, band 2 (**80-230 studs, the heart of the 150-stud eye reach**) **59 sites at 52**, band 3
(230-420) 175 at 34 -- against C1's own wood in front at 16/22/21/26 **plus** a 30-stud understorey.
`plan.spacingStuds` and `plan.deepSpacingStuds` are read by nothing but the skirt and
`cellCapacity` (grep above), so this is the band and nothing else.

**(e) HOW IT WILL BE MEASURED AFTER.** The same `360-ft-eye.luau`, same seven stands, same 5-stud
eye, in the same place -- both sides replanted through `346-plant.py` (`terrainbake.plant_prelude()`)
so the two sides are the same instrument (L-181). The plan instrument runs alongside, for the
dispatch's own number and for the part census.

## CLAIMS

(filled in at the code commit)
