# Task 190: the palm was 180 degrees out, and nothing could see it

Task: 190
Round: 1
Base: main @ 098fdd1 (#172 merged: task 189)
Code commit: 009f4e33d5c7ef0dccede76306e66c3c1b45fe3a

```
[harness] PASS: 33/33 checks @ 009f4e33d5c7ef0dccede76306e66c3c1b45fe3a (clean tree) scope=all
```

`test2` is **N/A**: no `TWO_PLAYER_PATHS` file is touched (the four code/test files are
`src/shared/HandAssets.luau`, `src/shared/Viewmodel/poses.json`,
`tests/server/viewmodel_poses.spec.luau`, `tests/server/camera_mode.spec.luau`).

## What changed, and why

Karen, 2026-10-15 ~16:30, after playing task 189 as merged:

> *"now right hand reload with outside of fingersit has to palm inside now is outside fix that"*

She is describing **189a(k)**, which task 189 wrote down as a guess and shipped: two marker balls
fix one AXIS, not a frame, and the rest of the frame was assumed (a mirror in X), which fixes
`fingers` and leaves `palm` pointing the wrong way along Z. Task 190 measured the other axis the
same way and corrected it. Karen then looked and said **"now is ok"** (2026-10-15 ~17:15,
transcribed in `PLAYTEST.md`).

Note: `docs/research/2026-10-15-hand-axis-and-flat-trajectory.md` **section 9** (task 189's note,
extended -- this is the same system and the same open question coming back, so it belongs there
rather than in a second note; `docs/research/INDEX.md` row updated).

## Claims

1. **THE PALM SIDE IS MEASURED, NOT INFERRED.** The published `HandRight` template was cloned into
   the sky at identity rotation with neon balls on its own +-Y and +-Z and photographed down all
   four faces. The **-Z face is the palm**: `.screenshots/t190-glove-minusZ.png` is the prep's own
   `render_across.png` frame for frame (the thumb and the index closing a ring you can see
   through); `t190-glove-plusZ.png` is `render_across-back.png` (the stitched back, the knuckles).
   *Verify:* open the four `.screenshots/t190-glove-*.png` beside the renders named in
   `HandAssets.AXES`'s comment, and read that comment.

2. **IT IS A ROTATION, NOT A MIRROR -- task 189's open question 8.2 closed.** In the drawn part the
   thumb lies at +Y with the fingers at +X and the palm at -Z, so `thumb = fingers x palm`, the
   RIGHT-hand relation. A mirror turns a right glove into a left one and breaks it.
   *Verify:* the argument is written out in `HandAssets.AXES`'s comment; check the cross product
   against the -Z screenshot (fingers point left, thumb at top, palm toward the lens).

3. **`HandAssets.AXES.RIGHT` carries both measured signs now** -- `fingers = (0.9632, 0.2645,
   -0.0484)`, `palm = (0.0660, 0.1061, -0.9922)`: the half turn about Y applied to task 188's
   glTF-frame measurement. *Verify:* `src/shared/HandAssets.luau`, `AXES`.

4. **THE THREE LANDMARKS GO BACK TO TASK 188's Z**, because a proper rotation moves no coordinate in
   the aligned frame (`(Rp).(Re) = p.e`, cross product included). Recomputed off the same prepped
   mesh the same way and agreeing with task 188 in X and Y to 2e-4: `GRIP_STUDS` z `-0.006`,
   `FINGERTIP_STUDS (0.3324, -0.0599, 0.0178)`, `CUFF_STUDS (-0.3238, -0.0105, -0.0315)`.
   *Verify:* `HandAssets.GRIP_STUDS` / `FINGERTIP_STUDS` / `CUFF_STUDS` and their comments.

5. **MEASURED ON THE PLAYER'S PATH, one probe printing the same frame before and after** (a Play
   session, reading the DRAWN parts, the real palm direction carried through both alignments):

   | | before | after |
   |---|---|---|
   | hip, palm vs the wrist of the stock | 115.5-154.0 deg | **37.3-70.0 deg** |
   | bolt stroke (79 samples, fist within 0.10 of the knob), palm vs the bolt's own axis | 111.0-117.9 deg | **73.3-80.3 deg** |

   *Verify:* the table is in the note section 9.1 and in `TASKS.md` row 190; the sign is the claim.

6. **TASK 189's OWN CHECKS STILL HOLD** through the same stroke: the fingertip is **0.103-0.178**
   studs from the knob against the cuff's **0.490-0.573**, and the cuff trails the fingertip by
   **0.40-0.56**. *Verify:* note section 9.1; and `viewmodel_poses.spec`'s bolt-hand cases pass in
   the harness line above.

7. **SCREENSHOTS, LOOKED AT (rule 5).** `.screenshots/t190-bolt-after.png` (the viewmodel held at
   the stroke by a probe-only render step, fist 0.061 studs from the knob, knuckles outward, cuff
   running back) and `t190-hip-after.png` (the hand wrapped on the wrist of the stock, palm on the
   wood). Karen looked at both and said *"now is ok"*. *Verify:* open them.

8. **THE FIVE ACCEPTED HANDS DO NOT MOVE** -- the shotgun's three and the horn's two, re-expressed
   by task 189's transport `pose_new = pose_old * (align_old * align_new^-1)`, reproducing each
   drawn CFrame to **5.8e-16**. *Verify:* `src/shared/Viewmodel/poses.json`, and
   `viewmodel_poses.spec`'s "the shotgun's and the horn's right hand did not move (task 189)".

9. **THE GATE CAUGHT A REAL DEFECT IN THIS TASK'S FIRST COMMIT, and it is worth a finding of its
   own.** `Viewmodel.hornPose` builds the horn's right hand as `CFrame.Angles(pitch, yaw, twist)` =
   `Rx*Ry*Rz`, while `Mode.handOffset` builds a gun's as `Ry(yaw)*Rz(pitch)*Rx(twist)` -- two
   orders behind the same three names in the same `poses.json`. The transport was computed in
   `Mode`'s order for all five poses, which moved the DRAWN horn hand **58.3 degrees**.
   `viewmodel_poses.spec`'s horn pin failed on it (first run,
   `<runs-dir>/test-t190-scoped.log`). The horn's two poses are transported in their own order now.
   Queued as **190a(a)**. *Verify:* `Viewmodel.hornPose` against `Mode.handOffset`; the first log.

10. **THE TWO SPEC CASES THAT MOVED, AND WHY NEITHER IS A HAND MOVING.**
    (a) `viewmodel_poses.spec`'s five pins are `offset:PointToWorldSpace(landmark)`, so they move
    when the LANDMARK moves as well as when a pose does -- claim 4 moves them by up to 0.063 studs.
    The three pinned pairs are updated and the header says exactly this.
    (b) `camera_mode.spec`'s "the two hands are posed differently" compared the two POSE frames,
    each read in its own glove's aligned convention, so its answer moved every time either axis was
    re-measured: **139** deg on task 188's numbers, **177** on task 189's, **41.9** on task 190's,
    while the drawn hands never moved. It measures the DRAWN rotations now (`pose * align`, which is
    what `Camera.Viewmodel.poseHands` draws) and reads **152.1** deg on both sides of this task.
    *Verify:* both specs' comments, and the harness note lines
    `task114 hand frames: 152.1 degrees apart, as drawn` and the four `task189 ... right hand` lines.

## What was NOT run, and what I could not verify (rule 8)

- **THE FULL SUITE WAS NOT CHOSEN -- but it ran anyway.** The Director's order was Karen's new rule
  (2026-10-15: *"only what has been changed or related"*), so the gate was `test --scope auto`. It
  resolved to **`scope=all`**: `src/shared/HandAssets.luau` is in no `BLAST_RADIUS` row, and an
  unmapped `src/` path can only ever mean the whole suite. So this line is FULL evidence and the
  merge gate is satisfied by it; what her rule actually bought on this task is **nothing**, and the
  missing `BLAST_RADIUS` row is queued as 190a(b).
- **`test2` was not run** and is N/A by the `TWO_PLAYER_PATHS` list.
- **Whether the roll wants finishing.** 73-80 deg is on the right side of 90 but grazing. That is
  inherent -- a closed fist's palm normal IS the axis of the hole the fist makes, and the knob sits
  in that hole (`GRIP_STUDS` is at aligned Y = 0, the middle of the hand) -- so the component
  pointing at the receiver is small whichever way round the hand is. The SIGN is the measurement.
  Karen's *"now is ok"* is what settles the look.
- **The LEFT glove is untouched** and carries the same kind of guess (189a(a), now 190a(c)).
- **The Forest Test Studio could not be confirmed Rojo-synced** from here: every Rojo script's
  `Source` reads empty through StudioMCP in that place while DEV's reads correctly. Reported as
  190a(d) rather than worked around.
- **The rifle draws with a red-marble-and-gold texture in DEV** (`t190-bolt-after.png`); seen, not
  touched (190a(e)).
- **A hunter in the Forest Test gets no Tool at all** until the rifle is bought at the lodge counter,
  which is why the measurement was taken in DEV (190a(f)).
