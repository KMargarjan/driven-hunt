# Task 212 — the hand holds the horn

Task: 212
Round: 1
Base: 4e6b4ef (main, "Merge pull request #195 from KMargarjan/task-214-beater-start-role")
Code commit: bdb635d67fedff136c7ad073c2888cc653d8f659

Karen, 2026-10-19 ~09:00: *"still need to improve hand position when holding horn"*, with
`driven-hunt-runs/karen-2026-10-19/horn-carry.png` (the glove lying on the tube) and `horn-blow.png`.
She accepted this version at ~17:20 (*"accep current"*); a glove modelled round the horn is a later task.

The target is the Designer's board, `driven-hunt-runs/design/horngrip-spec.md` plus
`horngrip-carry.png` and `horngrip-blow.png`.

```
[harness] PASS: 33/33 checks @ bdb635d67fedff136c7ad073c2888cc653d8f659 (clean tree) scope=auto:viewmodel
```

`test2` is **N/A**: nothing here is in `TWO_PLAYER_PATHS` — this is `poses.json` plus the pose spec,
which is the viewmodel, and a second client renders a second copy of a picture one client already shows.

## What changed

`src/shared/Viewmodel/poses.json` (`horn`) and `tests/server/viewmodel_poses.spec.luau`. No other file.

## Claims

1. **The fist cannot wrap this tube, and that is why three tasks missed the picture.** The published
   glove (`prepped/glove_right_v4_r1/model.glb`) was voxelised at 0.004 studs in the aligned frame:
   along the THUMB axis — the way a tube must run for this grip — there is **no through-hole**
   (2 voxels, r 0.004); along the fingers none; the only hole runs along the **palm normal** and is
   0.052 x 0.072 studs, largest inscribed radius **0.0170**. The tube at the Designer's grip point is
   **0.339 studs across** unscaled. Verify: the header of `closes the right fist around the tube` in
   `viewmodel_poses.spec.luau`, and `HandAssets.GRIP_STUDS`' own header (task 188 read the same hole
   as 0.054 x 0.060). The mesh measures `Assets.HAND_RIGHT_NATURAL` exactly, so it is the drawn part.

2. **The grip case now measures what the eye sees, not the hole.** `off <= radius` and `angle < 15`
   are replaced by `hiddenShare > COVERED` — the share of the fist the horn is drawn in front of,
   by a ray from the lens against `Horn.TUBE_SAMPLES`. Verify: `hiddenShare`, `hornInFront` and
   `SAMPLES` in that describe block; the harness notes read
   `task212 carry grip: the horn covers 0.417 of the fist` and `blow ... 0.458`.

3. **It is shown failing on the build Karen rejected (L-028).** `...and the horn covered a quarter of
   the fist on the pose Karen rejected` runs task 211's own twelve shipped numbers, at their own 0.34
   scale, through the same `hiddenShare` and requires them BELOW the bound. Notes:
   `the REJECTED carry: the horn covers 0.240` and `the REJECTED blow: ... 0.260`, against 0.35.
   It is the quantity the defect moved, not a pivot or a box corner.

4. **The box proxy is checked against the mesh, not assumed.** A spec cannot read a MeshPart's
   vertices, so the samples are the fist's box. Measured off the real mesh with the same ray test,
   the vertices answer 0.29 / 0.40 for task 211's poses where the box answers 0.24 / 0.26, and
   0.59 / 0.63 for task 212's where it answers 0.42 / 0.46 — low, and moving the same way. Verify:
   the `SAMPLES` header.

5. **The grip never changes between the poses.** `blow.right` is byte-for-byte `carry.right`, held by
   one equality in `holds the horn with the same hand in the carry and at the lips`. The Designer's
   section 4 asks for it in words. Verify: the `horn` block of `poses.json`, and that note, which
   prints both CFrames.

6. **A real bug in the horn-in-the-picture bound.** Both cases compared a horizontal `|x|/depth`
   against `HALF_VIEW`, which is the **vertical** half of the view — i.e. they asked whether the horn
   fitted a square centre crop. No horn before this one reached the sides (task 211's blow spanned
   x 41..53 %), so nothing caught it. `HALF_VIEW_ACROSS` is the 16:9 half, which is the board's own
   frame. Verify: `HALF_VIEW_ACROSS` and the two `expect(worstX < HALF_VIEW_ACROSS)`.

7. **`tipOff < cuffOff` is untouched.** Task 189's end-for-end hand is the one defect a coverage
   share could still hide, so that assertion is kept exactly. Verify: the same case.

8. **The live first-person frames.** Forest Test, real player, beater through the truck pad:
   `.screenshots/t212-smoke-final.png` (carry) and `t212-blow-fp-yaw0.png` (blow), beside the boards
   in `driven-hunt-runs/karen-2026-10-19/t212-live-carry.png` and `t212-live-blow.png`. The horn
   crosses the hand, the fingers crest the tube's far edge, the cuff leaves the bottom edge, and the
   top of the view is clear. Camera height 238.8 studs (player eye, first person).

9. **The grip holds through a full body turn, a respawn and both roles (L-018).** Eight yaws over
   360 degrees: `gripOff=0.1022`, `tubeR=0.0666`, identical at every one
   (`.screenshots/t212-turn.txt`), photographed at 0/90/180/270. The blast was fired at three yaws
   and measured the same. After `Humanoid.Health=0` and a respawn the hand is unchanged
   (`t212-carry-fp-respawn.png`), with `inCHARACTER=Horn inBackpack=nil`. **Invariance here is
   expected by construction** — the hand is posed in the horn's own frame — so it proves the wiring,
   and the photographs are what prove the picture.

10. **Rule A, on a fresh 101 s Play.** Tool in the CHARACTER at 85 s and at the end
    (`team=Drivers inCHARACTER=Horn inBackpack=nil hornViewmodel=true`); whole console **CLEAN**
    (0 "Stack Begin", 0 "attempt to", 0 "invalid argument" outside CorePackages); the changed feature
    ran — the horn viewmodel is drawn, and the earlier session logged three
    `[ForestTest] horn blown at ...` lines.

## What I could not verify

- **At 15 s the player holds nothing**, and that is the documented start state, not a failure: in the
  Forest Test he is unenrolled at the lodge until he steps on a truck pad (standing rule I). He
  enrolled at ~85 s of that run. So rule A's "at 15 s" is answered by the lobby, not by the horn.
- **No wave line in the 101 s smoke window** — the drive only reached Running near the end of it. The
  earlier session of the same build released four lines and three horn blasts.
- **Third person was not reached.** Moving the camera by hand does not change `Camera.Mode`, so the
  probe still reported `hornViewmodel=true`; that is my probe's limit, not a finding, and I am not
  offering it either way.
- **The blow bell sits at x 87 % of the width against the board's 84 %** (measured by silhouette in
  the offline raster). 3 % of frame width over, reported rather than re-solved.
- **The board's four fingertips, the thumb along the tube and the horn in the web are not reached.**
  Claim 1 is why: this glove has one extended finger and three curled tips. Karen accepted it.
- The live frames are 955 x 785, not the board's 1280 x 720, so horizontal fractions are not directly
  comparable between them (L-021); the composition is.
