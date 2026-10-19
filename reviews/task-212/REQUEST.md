# Task 212 — the hand holds the horn

Task: 212
Round: 2
Base: 4e6b4ef (main, "Merge pull request #195 from KMargarjan/task-214-beater-start-role")
Code commit: 6abfa8a7c2e11b104f36812747cfd96b1e347879

Karen, 2026-10-19 ~09:00: *"still need to improve hand position when holding horn"*, with
`driven-hunt-runs/karen-2026-10-19/horn-carry.png` (the glove lying on the tube) and `horn-blow.png`.
She accepted this grip at ~17:20 (*"accep current"*); a glove modelled round the horn is a later task.
The target is `driven-hunt-runs/design/horngrip-spec.md` with `horngrip-carry.png` / `horngrip-blow.png`.

```
[harness] PASS: 33/33 checks @ 6abfa8a7c2e11b104f36812747cfd96b1e347879 (clean tree) scope=all
```

`test2` is **N/A**: no `TWO_PLAYER_PATHS` file changed. The diff is `src/shared/Viewmodel/poses.json`
and `tests/server/viewmodel_poses.spec.luau` — the viewmodel, where a second client renders a second
copy of a picture one client already shows.

## Changed

`src/shared/Viewmodel/poses.json` (`horn` only) and `tests/server/viewmodel_poses.spec.luau`.

## Claims

1. **The fist cannot wrap this tube, which is why 202, 206 and 211 missed the picture.** The published
   glove (`prepped/glove_right_v4_r1/model.glb` — its bounds times 100 are `Assets.HAND_RIGHT_NATURAL`
   to the digit, and it carries that row's 6,192 triangles, so it is the drawn part) was voxelised at
   0.004 studs in the aligned frame. Along the **thumb axis**, the way a tube must run for this grip:
   **no through-hole** (2 voxels, r 0.004). Along the fingers: none. The only hole runs along the
   **palm normal**, 0.052 x 0.072 studs, largest inscribed radius **0.0170**; the tube at the grip is
   **0.339 studs across** unscaled. Verify: the header on `expect(share > COVERED)`.

2. **The grip case measures what the eye sees.** `off <= radius` / `angle < 15` — which asked whether
   the fist's *hole* was threaded on the tube — are replaced by `hiddenShare > COVERED`: the share of
   the fist the horn is drawn in front of, by a ray from the lens through `Horn.tubeAt`. Verify:
   `SAMPLES`, `hornInFront`, `hiddenShare`. Harness notes: `the horn covers 0.427 of the fist` (carry)
   and `0.438` (blow).

3. **Shown failing on the build Karen rejected (L-028).** The case
   `...and the horn covered a quarter of the fist on the pose Karen rejected` runs task 211's own
   shipped `horn` block — both poses, 24 numbers, at their own 0.34 scale — through the same
   `hiddenShare` and requires them BELOW the bound. Notes: `the REJECTED carry: ... 0.240` and
   `the REJECTED blow: ... 0.260`, against 0.35. It is the quantity the defect moved, not a pivot or a
   box corner.

4. **The box proxy is checked against the mesh.** A spec cannot read a MeshPart's vertices, so the
   samples are the fist's box. With the same ray test the real vertices answer 0.29 / 0.39 where the
   box answers 0.24 / 0.26 (task 211), and 0.56 / 0.43 where it answers 0.43 / 0.44 (task 212). Verify:
   the `SAMPLES` header.

5. **The grip never changes between the poses.** `blow.right` is byte-for-byte `carry.right`, held by
   `holds the horn with the same hand in the carry and at the lips`. The note prints both CFrames.

6. **ROUND 1's FINDING 1, FIXED — and round 1 was wrong about it.** Round 1 widened the horizontal
   bound to 16:9 (`HALF_VIEW_ACROSS`) and called the old one a bug. It is **not** a bug: the describe
   header documents the vertical half as used on both axes deliberately, *"the strictest any window can
   ask for"*, and Karen plays at **955 x 785**, where the horizontal room is 0.8517. Round 1's blow put
   the bell's widest section at `worstX = 1.0392` — inside the bound it had just written, **outside her
   window**. `poses.json` is the content lane the Director tunes live with no review round, so that
   bound is the only thing between a live tune and her screen. `HALF_VIEW_ACROSS` is gone and both
   poses are re-solved to fit the original bound. Verify: no `HALF_VIEW_ACROSS` in the file; the notes
   read `task202 carry: worst |x|/depth 0.6801, |y|/depth 0.6790 ... half view 0.7002` and
   `task202 blow: worst |x|/depth 0.6748, |y|/depth 0.6692 over the horn up to z=0.4`.

7. **The tube has ends (round 1 Reviewer note, taken).** `hornInFront` trusted `Horn.tubeAt` past the
   horn, where its header says it holds the end row — an infinite cylinder, r 0.108 past the bell and
   0.0715 past the mouthpiece, so a ray that misses the horn could count as covered. It now rejects
   |z| > 1.5. **Verified to change no shipped number**: both poses here and both of task 211's answer
   the same share with the clamp and without it; it is in so the measure cannot be fooled later.

8. **The raise is measured at the mouthpiece (round 1 Reviewer note, taken).** That note said the
   `Magnitude > 0.5` case had 4 % of margin and nobody was thinking about it; the re-solve spent it.
   The swing is 130 degrees about the horn's middle, so the Handle's **pivot** barely moves while the
   **mouthpiece** — the point `Viewmodel.hornMouthpiece` exists to aim at — travels hip to lips.
   **The bound is unchanged at 0.5**; only which point it asks about changed, and both builds answer
   the same way round: task 211 pivot 0.6240 / mouthpiece 1.0440, task 212 0.4542 / 0.7162.

9. **Live first person, real player, beater through the truck pad.** Carry
   `.screenshots/t212r2-carry-fp.png`, blow `t212r2-blow-fp.png`, beside the boards in
   `driven-hunt-runs/karen-2026-10-19/t212-live-carry.png` and `t212-live-blow.png`. The blow was
   fired only once the drive was running, detected on the blast door itself (`Horn.BLOW_ATTRIBUTE`
   going `nil` to `1`) with the HUD chip reading `DRIVE 1 | 4:55 | TIME` rather than `ASSIGNING`.
   Camera height 239.2 studs (player eye, first person). The grip also holds through a full body yaw:
   `gripOff=0.1023, tubeR=0.0666` identical at 0/90/180/270 degrees, and unchanged after a respawn.

10. **Rule A, fresh 96 s Play.** (1) Tool: at 15 s the player is unenrolled at the lodge
    (standing rule I) — at the end `team=Drivers inCHARACTER=Horn inBackpack=nil vm=true`.
    (2) Whole console **CLEAN**: 0 "Stack Begin", 0 "attempt to", 0 "invalid argument" outside
    CorePackages. (3) The changed feature ran: the horn viewmodel is drawn, one
    `[ForestTest] horn blown` line and one wave line.

## What I could not verify

- **`Match.phase()` is not the Forest Test's drive clock.** It read `Waiting` for 221 s while the
  player was enrolled with the horn in hand and blasts were logging. The route that works is the HUD
  chip (what Karen reads) plus `Horn.BLOW_ATTRIBUTE`; that is what claim 9 used. Worth a look by
  somebody who owns `Match` — reported, not chased.
- **The "whole horn inside the 955 x 785 window" claim is analytic, not per-pixel.** `worstX = 0.6748`
  over every tube section with its radius, against the bound 0.7002 and against that window's own
  horizontal half 0.8517 — 21 % of margin. Per-pixel segmentation of the live frame was
  **inconclusive** and is not offered: the horn's silver bands break it into components (the largest
  came to 7,461 px, one lit segment). The frame corroborates by eye; the number is the measurement.
- **The Designer's blow composition is not reachable under this bound.** The board puts the bell at
  x = 80 % of a 16:9 width, which is outside a square centre crop. The bell now sits lower and further
  in. Changing the frame the picture is composed against is the Director's call, not this task's.
- **The board's four fingertips, the thumb along the tube and the horn in the web are not reached** —
  claim 1 is why. Karen accepted it as it is.
- The live frames are 955 x 785, not the board's 1280 x 720, so horizontal fractions are not directly
  comparable between them; the composition is.
