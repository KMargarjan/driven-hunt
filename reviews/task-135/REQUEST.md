# Task 135 - the drive report shows a boar, not blocks

Task: 135
Round: 1
Base: main (`0a5329e`)
Code commit: `bbeaad465c73faa1804daa5360136d9d88a0db58`

```
[harness] PASS: 33/33 checks @ bbeaad465c73faa1804daa5360136d9d88a0db58 (clean tree) scope=all
```

`test2` is N/A: this change touches no path in `TWO_PLAYER_PATHS` -- `src/shared/Report/`,
`src/client/Hud/ReportPanel.luau` and two specs.

## What changed

Karen, 2026-10-05: *"something simple but cool"*, and *"see boars where was the hit"*. The detail
view drew `Report.CONFIG.SILHOUETTE` straight onto the screen -- the five zone rectangles, each in
its own tint -- and task 124 round 3's own note said what that looked like: **"a colour-coded bar,
not a boar's outline"**.

## Claims

1. **A side-view boar, built from UI primitives, with no upload.** `Report.CONFIG.BOAR` is thirteen
   rounded `Frame`s -- trunk, shoulder hump, haunch, belly, neck, head, snout, ear, four legs, tail --
   drawn in the single colour `Report.CONFIG.BOAR_FILL` with a `UICorner` each. No image, no mesh, no
   asset id, which matters because the asset tool is models-only. Verify: `Report.CONFIG.BOAR`, and
   `buildSilhouette` in `src/client/Hud/ReportPanel.luau`.
2. **Every number is a SCALE of the art frame**, so the same thirteen parts draw the same animal at a
   detail row's 104 x 56 and at whatever a larger view asks for. Asserted: no part lies outside
   0..1, none is empty, and no two share a name.
3. **THE RECORD IS UNTOUCHED AND IT STILL PLACES EVERY DOT.** `SILHOUETTE` is still
   `Boar.CONFIG.ZONES` projected through `Shape.rectOf`, the spec still recomputes all four
   rectangles from `Boar.CONFIG`, and `drawDots` maps `(u, v)` into the square exactly as before --
   the same half-dot inset, the same clamp, the same attributes. Not one dot moved by a pixel.
4. **The two containment checks the task asked for.** The head zone's centre lands inside the drawn
   `Head`, and the rear zone's centre inside the `Haunch`. Verify: `report_silhouette.spec.luau`,
   "puts the HEAD where the head zone is, and the HAUNCH where the rear zone is".
5. **THE HEAD IS DRAWN HIGH BECAUSE THE MODEL CARRIES IT HIGH.** `Boar.CONFIG.ZONES.head` is at
   y 0.35..1.65 on a trunk 3 studs tall, which projects to v 0..0.383 -- the TOP of the box, not the
   bottom. A prettier boar with its nose near the ground would draw head shots off its own head. That
   is exactly what claim 4 pins, and it is written into both the config and the spec.
6. **How much of each zone has animal under it, measured against the DRAWN dot position** (the inset
   the panel applies, not the raw `u, v`): head 88%, chest 96%, rear 81%, legs 49%, body 72%. The
   four extreme corners of the bounding box have nothing under them, by construction -- that is the
   air above the snout and behind the rump, and an animal is not a rectangle. A weaker whole-zone
   claim is asserted instead: **every zone's centre has animal under it**.
7. **A real dot found a real gap, and it is fixed.** In a Forest Test run that shot boars through the
   `FireRequest` route, the one dot drawn read `legs u=1.000 v=0.671` and sat on **no part at all**.
   The `Haunch` now reaches the rump's back corner (u1 0.94 -> 0.97, v1 0.66 -> 0.71) and that same
   dot lands on it; a later run's two dots read `legs u=0.476 v=0.718 on=[Belly]` and
   `chest u=0.238 v=0.410 on=[Head]`.
8. **The zone tints outlived the boxes as the RING around each dot** -- head, chest, rear, legs or
   body at a glance, which is the one thing the rectangles told you that a plain silhouette does not.
   This is also what keeps `Report.CONFIG.ZONES` with a reader in `src/`: it lost its only one when
   the rectangles stopped being the picture, and a shared list nothing reads is the lie that
   `Penalty.expired`'s own comment warns about. Verify: `RING` in `ReportPanel.luau`.
9. **Non-fatal dots are round; the fatal marker is untouched.** It was a square turned 45 degrees
   among squares; a round hit beside a turned one reads as a different KIND of mark rather than the
   same mark at an angle. Same size, same kill colour, same turn for the fatal one.
10. **`report_panel.spec` was updated, not weakened.** It asserted five frames named `Zone_<zone>`;
    it now asserts all thirteen parts of the animal by name, that each carries `BOAR_FILL`, and that
    no `Zone_*` frame is left on screen. Five claims became fourteen.

## The frames (rule 5), in the order they were taken

- `.screenshots/t135-boar-9p0.png` -- **wrong**. The panel was open on the LIST view saying "nobody
  has hit anything yet": the Hud redraws the panel from the real report on its own tick and had
  overwritten the payload the preview pushed. The preview was changed to re-render.
- `.screenshots/t135-boar2-9p0.png` -- three rows, three animals, dots on them. It read as a
  four-legged animal, but the tail and the shoulder hump did not register at 104 px.
- `.screenshots/t135-big-10p0.png` -- the same drawing at 4x, and **wrong again**: the head was a
  separate rounded lump with a notch between it and the shoulder, and the whole thing read as a
  rhino. The `Neck` part exists because of this frame.
- `.screenshots/t135-final.png` -- the one to look at. **Two real animals from real shots**
  (FEMALE/LOST/legs/60 m and MALE/DOWN/chest/71 m), their dots drawn from the stored `(u, v)`, with
  a 4x copy of the first row's drawing beside it. It reads as a boar-like quadruped: deep barrel,
  shoulder higher than the rump, wedge head with a snout, small upright ear, four short legs.

## What could not be verified

- **There is no larger detail view in the game today.** The panel draws one size, 104 x 56, in a
  detail row. "Readable larger" was judged on a 4x CLONE of that same frame, made by the temporary
  preview script -- the drawing is all scales, so it does scale, but no view in the game asks it to
  yet. That script is removed; the tree at the code commit has no instrumentation in it.
- **Whether it is "cool" is Karen's call**, and I will not claim it. What I can say from looking at
  the frames: at 4x it reads as a boar-like quadruped; at the row's 104 x 56 the tail and the ear are
  three to five pixels and read as bumps rather than as features.
- **Standing rule A was run in the Forest Test**, 85 s: the Tool in the CHARACTER at 15 s and at the
  end (`tool=true backpack=false` both times), **0 fault lines in 24**, and four wave lines released.
  It does **not** exercise this change -- the report panel is not opened by a plain Play. The evidence
  that the feature ran is the real-shot run above, where the panel drew two real animals from real
  hits, plus `report_panel.spec` and `report_silhouette.spec` in the gate.
