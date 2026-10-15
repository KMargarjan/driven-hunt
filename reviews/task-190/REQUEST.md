# Task 190: the palm was 180 degrees out, and nothing could see it

Task: 190
Round: 2
Base: main @ 098fdd1 (#172 merged: task 189)
Code commit: 67df9a9d8bebbd0c1e644ec215ea548f75ceeb56

```
[harness] PASS: 33/33 checks @ 67df9a9d8bebbd0c1e644ec215ea548f75ceeb56 (clean tree) scope=all
```

`test2` is **N/A**: no `TWO_PLAYER_PATHS` file is touched (the five code/test files are
`src/shared/HandAssets.luau`, `src/shared/Viewmodel/poses.json`, `src/client/Camera/Viewmodel.luau`,
`tests/server/viewmodel_poses.spec.luau`, `tests/server/gun.spec.luau`,
`tests/server/camera_mode.spec.luau`).

**Round 1's blocking finding is fixed.** The research note landed in `e72e5bf`, after the commit
the harness had tested — the same defect task 189 round 1 was blocked on, with the same file. The
note is in at `e72e5bf`, the Reviewer's notes are fixed in `faf056c`, and the gate above was re-run
at `67df9a9`, which contains both.

## What changed, and why

Karen, 2026-10-15 ~16:30, after playing task 189 as merged:

> *"now right hand reload with outside of fingersit has to palm inside now is outside fix that"*

She is describing **189a(k)**, which task 189 wrote down as a guess and shipped: two marker balls
fix one AXIS, not a frame, and the rest of the frame was assumed (a mirror in X), which fixes
`fingers` and leaves `palm` pointing the wrong way along Z. Task 190 measured the other axis the
same way and corrected it. Karen then looked and said **"now is ok"** (2026-10-15 ~17:15,
transcribed in `PLAYTEST.md`).

Note: `docs/research/2026-10-15-hand-axis-and-flat-trajectory.md` **section 9** (task 189's note,
extended -- the same system and the same open question coming back, so it belongs there rather than
in a second note; `docs/research/INDEX.md` row updated).

## Claims

1. **THE PALM SIDE IS MEASURED, NOT INFERRED.** The published `HandRight` template was cloned into
   the sky at identity rotation with neon balls on its own +-Y and +-Z and photographed down all
   four faces. The **-Z face is the palm**: `.screenshots/t190-glove-minusZ.png` is the prep's own
   `render_across.png` frame for frame (the thumb and the index closing a ring you can see
   through); `t190-glove-plusZ.png` is `render_across-back.png` (the stitched back, the knuckles).
   *Verify:* open the four `.screenshots/t190-glove-*.png` beside the renders named in
   `HandAssets.AXES`'s comment, and read that comment.

2. **IT IS A ROTATION, NOT A MIRROR -- task 189's open question 8.2 closed, AND IT IS ASSERTED NOW.**
   In the drawn part the thumb lies at +Y with the fingers at +X and the palm at -Z, so
   `thumb = fingers x palm`, the RIGHT-hand relation; a mirror turns a right glove into a left one
   and breaks it. Round 1's Reviewer was right that nothing in the suite held this, so
   `gun.spec`'s **"has the RIGHT glove modelled as a right hand: the thumb is fingers x palm"** is
   new. It prints `task190 right glove: fingers x palm = -0.2598, 0.9619, 0.0856` and requires that
   to be the glove's own +Y. *Verify:* that case; the harness note line above; the -Z screenshot.
   The LEFT glove is deliberately NOT pinned -- its thumb has not been photographed and its `palm`
   is still the task 108 estimate, so a pin would assert the guess (190a(c)).

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
   Claim 6 is the same measurement made by the harness, and the two agree to four decimals.

6. **THE CASE THAT WOULD HAVE CAUGHT THIS IS IN THE SUITE NOW** -- the Director asked for it and
   round 1's Reviewer found `HandAssets` claiming it already existed when it did not.
   `viewmodel_poses.spec`'s **"turns the PALM onto the bolt, not the knuckles (task 190)"** and
   **"...and onto the wood at the hip and aimed"** require the drawn palm (`offset.UpVector`, which
   is what `align` is defined to produce) to point IN at the line the bolt turns about, and at the
   wrist of the stock, at every sample. Printed: `palm . inward 0.2869` at all four bolt turns
   (invariant, because the lift rotates the hand and the reference together) and
   `palm . toward the wrist 0.3416` at hip, aimed and cycle -- the same numbers the live probe in
   claim 5 measured (0.2870 and 0.3414). **THE REFERENCE IS THE BOLT'S AXIS, NOT THE KNOB,** and
   the comment says why: the knob sits inside the fist's own hole, whose axis IS the palm
   (`GRIP_STUDS` is at aligned Y = 0, the middle of the hand), so "palm toward the knob" is near 90
   degrees whichever way round the hand is and says nothing. *Verify:* both cases and their header.
   What they hold is the POSE, not `AXES` -- the header says that too, and claim 2 is what holds
   `AXES`.

7. **TASK 189's OWN CHECKS STILL HOLD** through the same stroke: the fingertip is **0.103-0.178**
   studs from the knob against the cuff's **0.490-0.573**, and the cuff trails the fingertip by
   **0.40-0.56**. *Verify:* note section 9.1, and `viewmodel_poses.spec`'s two task-189 cases, which
   pass in the harness line above.

8. **SCREENSHOTS, LOOKED AT (rule 5).** `.screenshots/t190-bolt-after.png` (the viewmodel held at
   the stroke by a probe-only render step, fist 0.061 studs from the knob, knuckles outward, cuff
   running back) and `t190-hip-after.png` (the hand wrapped on the wrist of the stock, palm on the
   wood). Karen looked at both and said *"now is ok"*. *Verify:* open them.

9. **THE FIVE ACCEPTED HANDS DO NOT MOVE** -- the shotgun's three and the horn's two, re-expressed
   by task 189's transport `pose_new = pose_old * (align_old * align_new^-1)`, reproducing each
   drawn CFrame to **5.8e-16**. The pins in `viewmodel_poses.spec` move, and by exactly two amounts
   for all three pairs -- **0.0901** studs at the fingertip and **0.0468** at the cuff -- because it
   is one 170.2 degree roll applied to one pair of landmarks. (Round 1's "up to 0.063 studs" was the
   landmark's own displacement, not the pin's; the header says the right thing now, and round 1's
   Reviewer computed the two numbers independently and got the same.) *Verify:*
   `src/shared/Viewmodel/poses.json` and that case's header.

10. **THE GATE CAUGHT A REAL DEFECT IN THIS TASK'S FIRST COMMIT.** The local `hornPose` inside
    `Viewmodel.view` (`src/shared/Viewmodel/init.luau`) builds the horn's right hand as
    `CFrame.Angles(pitch, yaw, twist)` = `Rx*Ry*Rz`, and so do `BOLT_HAND.grip` and
    `MAGAZINE_SWAP.hand`; `Mode.handOffset` builds `carry`/`aim`/`reload`/`cycle` and `loadKey` as
    `Ry(yaw)*Rz(pitch)*Rx(twist)`. Five sites, two orders, the same three names in the same
    `poses.json`. The transport was computed in `Mode`'s order for all five poses, which moved the
    DRAWN horn hand **58.3 degrees**; `viewmodel_poses.spec`'s horn pin failed on it
    (`.agent-logs/task190-r1-test1.log`). The horn's two poses are transported in their own order
    now. Queued as **190a(a)**. *Verify:* the two builders in `src/shared/Viewmodel/init.luau` and
    `src/client/Camera/Mode.luau`; the first log.

## What round 1's notes cost, and what was fixed rather than queued

Round 1 passed ten notes. The costliest was a comment in `HandAssets.AXES` claiming a spec case that
did not exist -- the Reviewer said so plainly ("the next Builder will believe a guard exists"), and
the answer was to write the case (claims 2 and 6) rather than to soften the sentence. Also fixed
here: the `AXES` heading still asserting "a MIRROR IN X" twenty lines above the body that refutes it;
`Camera.Viewmodel.align`'s header saying the palm faces +Z when it faces -Z; the pin header's 0.063
(claim 9); the shotgun carry prose's 0.447, which is 0.4252; TASKS.md 190a(a) naming
`Viewmodel.hornPose` as though it were in `Camera.Viewmodel` and calling it two sites (claim 10); the
105-character comment line with a dangling "The"; and the gate logs, now at `.agent-logs/` where
every other row cites them.

## What was NOT run, and what I could not verify (rule 8)

- **THE FULL SUITE WAS NOT CHOSEN -- but it ran anyway.** The Director's order was Karen's new rule
  (2026-10-15: *"only what has been changed or related"*), so the gate was `test --scope auto`. It
  resolved to **`scope=all`**: `src/shared/HandAssets.luau` is in no `BLAST_RADIUS` row, and an
  unmapped `src/` path can only ever mean the whole suite. So this line is FULL evidence and the
  merge gate is satisfied by it; what her rule actually bought on this task is **nothing**, and the
  missing `BLAST_RADIUS` row is queued as 190a(b).
- **`test2` was not run** and is N/A by the `TWO_PLAYER_PATHS` list.
- **Whether the roll wants finishing.** 73-80 deg is on the right side of 90 but grazing, inherently
  (claim 6). The SIGN is the measurement. Karen's *"now is ok"* is what settles the look.
- **The LEFT glove is untouched** and carries the same kind of guess (189a(a), now 190a(c)). Claim 2
  says why it is not pinned.
- **The Forest Test Studio could not be confirmed Rojo-synced** from here: every Rojo script's
  `Source` reads empty through StudioMCP in that place while DEV's reads correctly. Reported as
  190a(d) rather than worked around.
- **The rifle draws with a red-marble-and-gold texture in DEV** (`t190-bolt-after.png`); seen, not
  touched (190a(e)).
- **A hunter in the Forest Test gets no Tool at all** until the rifle is bought at the lodge counter,
  which is why the measurement was taken in DEV (190a(f)).
