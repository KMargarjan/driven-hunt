# Task 98 -- viewmodel poses as data, tuned live, compared against the video

Task: 98
Round: 2
Base: main (`ee8fed5`)
Code commit: 18f7570b342403cd72f4a5797160e71cdeb20beb

```
[harness] PASS: 34/34 checks @ 18f7570b342403cd72f4a5797160e71cdeb20beb (clean tree)
[harness2] PASS: 34/34 checks @ 18f7570b342403cd72f4a5797160e71cdeb20beb (clean tree)
```

Both run by the Director at this branch's head, which is the request commit itself: only paperwork
follows the last code change (`825b00e`), so the evidence covers everything under it (git step 4).

**What changed for the player.** Round 1's request said "nothing" and that was false -- the Reviewer
is right. The gun a player sees is DIFFERENT, because the file the poses moved into was seeded with
Task 97 round 2's values rather than with `main`'s, and first person is now the shipped camera.
Old (`main`) → new (`poses.json`), every player-visible number that moved:

- `carry.gun.pos` (-0.80, -0.95, -1.56) → (-0.67, -0.57, -1.22); `carry.gun.rot` 2 / 53 / -6 → 23.9 / 45.7 / -10
- `aim.eyeReliefStuds` 3.27 → 3.65; `aim.cheekDeg` 5.4 → 1.2
- right hand pos (0.02, -0.02, 1.30) → (0.12, -0.12, 0.80), pitch -6 → 10
- left hand pos (0.08, -0.09, 0.09) → (-0.02, -0.08, -0.85)  (both hands seeded into all three poses)
- `VIEWMODEL_FILL_BRIGHTNESS` 1.0 → 0.8, `VIEWMODEL_FILL_OFFSET_STUDS` (-0.6, 0.8, 0.9) → (-0.45, 0.60, -0.80)
- Why: dispatch item 1 -- "for carry/aim use the round-2 numbers on branch `task-97-sxs-poses`
  (commit `9393d1e` -- closer to Karen's target)". **The fill light is NOT covered by that and is a
  Builder choice**: it is a light, not a pose, and I took it because `9393d1e` re-measured it against
  the very aim pose seeded here (the old 1.0 at 0.9 studs behind the gun's centre blew the stock's
  left flank to white once the relief brought the stock into frame). Reverting it is two lines.

## Claims

1. **What moved is the list above, and it is authorised.** Verify: `git diff ee8fed5..18f7570 --
   src/client/Camera/Config.luau src/shared/Viewmodel/poses.json`. Authority:
   `ESCALATE.md`, entry "2026-10-01 · CLOSED 2026-10-01 · Director decision · Task 98: `FIRST_PERSON`
   ships ON, and the poses are seeded from Task 97 round 2", and the dispatch transcribed in
   `TASKS.md` row 98 (items 1 and 4). It is **not** a playtest OK of the poses: they are the starting
   point the Director now tunes live, and Karen OKs the result (CLAUDE.md, "Content lane").
2. **`FIRST_PERSON` ships ON by that same decision**, not by this task inventing it. Verify: the
   `ESCALATE.md` entry above, which records Karen's 2026-10-01 "let's try" on a plan whose item was
   *FIRST_PERSON default ON (Karen must see the current gun on every Play)*, and `TASKS.md` row 98's
   transcription of dispatch item 4. The rollback is the row's one line back to `default = false`.
3. **The MOVE TO DATA is itself a no-op** -- the numbers moved, the mechanism did not. With the file
   as shipped (`raise.keyframes` empty, all three poses carrying the same hands), the keyframe path
   and the per-pose hands reduce to exactly the composition the camera has had since task 89. Verify:
   `viewmodel_poses.spec`, "with no mid keyframes it is exactly the carry-to-aim ease it has always
   been" (11 blends, compared with `hip:Lerp(aim, ease(blend))`) and "the shipped file seeds every
   pose's hands the same" (the right hand across 5 blends x 3 tilts; the left hand is checked at
   blend 0 / tilt 0 in the case above it -- queued as 98a(b) to widen).
4. **What the two side-by-sides actually show** (rule 5; `tools/pose.py compare`, Play session
   2026-10-01, `.screenshots/20261001T203429Z-compare-carry.png` and `...203435Z-compare-aim.png`,
   both captured with `aim.eyeReliefStuds` overridden to 4.2 to demonstrate the tool):
   - **carry** -- left, the video: two barrels crossing the whole lower-left diagonal, the left hand
     on the forend at the bottom-left corner, autumn woods. Right, ours: the barrels enter at the
     bottom centre and leave the LEFT edge about 42 % down, with a green sleeve and a grey/white
     gloved hand under them. Same diagonal, but ours sits lower and reads much bigger and nearer than
     the target, and the bead is off the left edge (measured -0.2 % across).
   - **aim** -- left: the stock's wrist and receiver fill the lower centre, the two barrels run away
     and converge on the bead, the right hand's fingers show at the right of the wrist. Right, ours:
     the bead is dead centre (the green cross the tool draws, measured 50.0 % / 50.0 %), but the
     barrels are only a small black wedge under it and the **two white gloves are the brightest and
     largest things in frame**; the wood reads dark red-brown. It does not look like the target yet.
5. **One source.** `Camera.Config` defines no pose literal; it publishes the same flat names by
   calling `Viewmodel.view` on the data (the merge loop at the bottom of `Config.luau` asserts rather
   than overwrites). Verify: grep `EYE_RELIEF_STUDS` / `CARRY_PITCH_DEG` / `HAND_RIGHT_POS_STUDS` in
   `src/` -- the only definitions are in `Viewmodel.view`; and the spec case "is what the live Config
   carries" compares every published name with the data.
6. **A live change reaches the drawn gun.** Verify: `camera_client.spec`, "the live pose override
   moves the drawn gun, and is put back" -- it noted **5.850 studs** (9.5 - 3.65) and restores the
   attribute on every path. Live too: `pose.py compare aim` measured the bead at 4.20 studs from the
   eye with `aim.eyeReliefStuds` overridden to 4.2.
7. **A bad file or a typo'd path cannot half-apply.** `Viewmodel.validate` fails the harness for a
   missing field, an unimplemented easing or a keyframe out of order (a mutation case per shape);
   `Viewmodel.merge` and `Poses.resolve` refuse the WHOLE override and leave the base config. Verify:
   the `validate` and `paths and merge` describes, and `python tools/pose.py selftest`.
8. **A tuned session cannot be reported as evidence.** `test` and `test2` refuse while a pose
   override is set in the Edit place. Verify: the `[harness]` line's "No pose override is set" check,
   and the selftest case -- removing the guard makes `studio_mcp.py selftest` fail (done).

Not verified: whether the poses are RIGHT -- claim 4 is what they look like, and the judgement is
Karen's, from the content lane. `fire` is the recoil spring's parameters rather than a keyframe list
(the one deviation from the brief): see `Camera.Config` and the note, section 4. The Reviewer's seven
round-1 notes are queued as `TASKS.md` row 98a, unfixed in this round.
