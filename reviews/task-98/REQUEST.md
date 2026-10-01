# Task 98 -- viewmodel poses as data, tuned live, compared against the video

Task: 98
Round: 1
Base: main (`ee8fed5`)
Code commit: 18f7570b342403cd72f4a5797160e71cdeb20beb

```
[harness] PASS: 34/34 checks @ 18f7570b342403cd72f4a5797160e71cdeb20beb (clean tree)
[harness2] PASS: 34/34 checks @ 18f7570b342403cd72f4a5797160e71cdeb20beb (clean tree)
```

Both run by the Director at this branch's head, which is the request commit itself: only paperwork
follows the last code change (`825b00e`), so the evidence covers everything under it (git step 4).

What changed, for the player: nothing yet. Every first-person pose number moved out of Luau into
`src/shared/Viewmodel/poses.json`, seeded with task 97 round 2's values (`9393d1e`), and the
Director can now change one inside a running Studio session and see it on the next frame.
`FIRST_PERSON` ships on.

## Claims

1. **One source.** `Camera.Config` defines no pose literal; it publishes the same flat names by
   calling `Viewmodel.view` on the data (see the merge loop at the bottom of `Config.luau`, which
   asserts rather than overwrites). Verify: `grep` for `EYE_RELIEF_STUDS` / `CARRY_PITCH_DEG` /
   `HAND_RIGHT_POS_STUDS` in `src/` -- the only definitions are in `Viewmodel.view`. The spec case
   "is what the live Config carries" compares every published name with the data.
2. **Nothing a player sees changed.** `raise.keyframes` ships empty and all three poses carry the
   same hands, so the gun is bit-for-bit what it was. Verify: `viewmodel_poses.spec`, cases "with no
   mid keyframes it is exactly the carry-to-aim ease it has always been" (11 blends) and "the
   shipped file seeds every pose's hands the same" (5 blends x 3 tilts).
3. **A live change reaches the drawn gun.** Verify: `camera_client.spec`, "the live pose override
   moves the drawn gun, and is put back" -- it noted **5.850 studs** (9.5 - 3.65), and restores the
   attribute on every path. Driven live too: `pose.py compare aim` measured the bead at 4.20 studs
   from the eye with `aim.eyeReliefStuds` overridden to 4.2.
4. **A bad file or a typo'd path cannot half-apply.** `Viewmodel.validate` fails the harness for a
   missing field, an unimplemented easing or a keyframe out of order (mutation case per shape);
   `Viewmodel.merge` and `Poses.resolve` refuse the WHOLE override and leave the base config.
   Verify: the `validate` and `paths and merge` describes, and `tools/pose.py selftest`.
5. **A tuned session cannot be reported as evidence.** `test` and `test2` refuse while a pose
   override is set in the Edit place. Verify: the `[harness]` line's "No pose override is set" check,
   and the selftest case -- removing the guard makes `studio_mcp.py selftest` fail (done).

Not verified: the two-player run (the Director's); whether the poses LOOK right -- that is Karen's,
and the two side-by-sides are in the report. `fire` is the spring's parameters, not keyframes: see
`Camera.Config` and the note, section 4.
