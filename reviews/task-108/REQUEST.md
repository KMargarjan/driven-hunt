# Task 108 - the hands on model B hold the gun

Task: 108
Round: 1
Base: `content-model-b-aim-1` (`1ee7ba0`)
Code commit: `dcec68e05483053e5bdbf73378c05fd80d9fe51c` (the paperwork commit; the last code
commit is `22f6bc4` and only `reviews/task-108/REQUEST.md` and the TASKS row changed after it)

```
[harness] PASS: 32/32 checks @ dcec68e05483053e5bdbf73378c05fd80d9fe51c (clean tree)
[harness2] PASS: 34/34 checks @ dcec68e05483053e5bdbf73378c05fd80d9fe51c (clean tree)
```

`test2` is required: the branch also changes `src/shared/HandAssets.luau` and
`src/client/Camera/Config.luau`, both outside `WEAPON_VIEWMODEL_PATHS`.

## Claims

1. **Both gloves now answer the same three angles.** `Camera.Viewmodel.align` builds, per glove, the
   rotation that takes its own measured axes (`HandAssets.AXES`, task 108's first commit) into one
   convention -- FINGERS ALONG +X, PALM TOWARD +Y -- and `poseHands` applies it on the RIGHT of the
   pose offset, so it turns the mesh inside the pose and never moves where the pose put it. The
   measured palm is squared against the measured fingers, because the fingers are the axis that was
   measured exactly (centroid to centroid) and the palm normal is a plane fit. It returns
   `CFrame.identity` unless `config.NEW_GUN`, so the old gun is untouched. This is Karen's
   *"left hand is oposit180deg"*: one `twist` used to turn the two meshes about different axes.
2. **Carry, aim and reload are re-seeded in that convention**, through `pose.py set` + `pose.py save`
   (the one writer of `poses.json`), and ONLY the `newGun` block of the file changed -- the top-level
   poses, which are the old gun's, are byte-identical. Left hand `(0, -0.13, 0)` yaw 15 pitch -15,
   under the forend; right hand `(0, -0.22, 1.1)` yaw 115 pitch -12 twist 60, on the wrist of the
   stock.
3. **The sleeve is a forearm, not a pipe.** Three segments wrist -> elbow
   (`SLEEVE_TAPER_NEW_GUN_STUDS` 0.150 / 0.125 / 0.105 against one 0.20 cylinder), at the same TOTAL
   length, because the length is what keeps the far end behind the eye. It NARROWS toward the elbow,
   which is not how an arm is shaped, and the frame is why: at 0.080 the drawn sleeve was thinner
   than the glove model's own turned cuff, so both gloves showed an open ellipse at the wrist
   (`.screenshots/20261002T142154Z-inspect-aim-left-front.png`). The wrist segment is sized to plug
   that cuff.
4. **The sleeve is placed in the POSE's frame, not the hand's**, and that was a real defect: once the
   mesh is aligned, the hand part's own X is the MESH's X, which on the left glove is not the arm at
   all. `poseHands` passes the pre-alignment CFrame to `placeSleeve`; each segment's distance back is
   worked out once in `addHand` from that glove's length along ITS OWN finger axis (`Size.X` is
   wrong for the left glove, whose longest axis is Z).
5. **One client case measures all of it on the drawn instances**, standing in its own glove-sized
   stubs so it says the same thing on a run where the uploads have not landed: the left hand is
   between the muzzle and the breech and BELOW the barrels (the rib stays clear), the right hand is
   behind the breech and inside the Handle, and every sleeve segment of both hands is further from
   the muzzle than its own hand -- which is "no open sleeve end facing the camera" as geometry. It
   carries model B's own pose numbers in its own config, because `Camera.Config` folds in ONE set at
   boot and the flag is OFF during a harness run; the first gate run failed exactly there.

## What I could not verify

- **`test2` took three runs, and the first two are worth saying.** Run 1 was
  `[harness2] FAIL: 32/34`, both failures in `tests/client/weapon_client.spec.luau`, a file this task
  does not touch: that run's own notes say the shooter *"is tied to a tree"*, `equipped=false`, his
  gun in the backpack from +54 s, so "equips on the cue and starts full" had no gun to equip. Run 2
  passed 34/34 but on a DIRTY tree -- I was writing this file while it ran -- which is not evidence.
  Run 3 is the line above. So the tie flake is NOT reproducible and was not caused by this change,
  but it is a real thing the two-player scenario does.
- **Nothing was captured of the RAISE blend**: the three poses were each held and photographed, and
  the frames between them were not.
- **The reload's right hand was not judged**: in that frame it is below the bottom edge
  (`HandRight ... OFF SCREEN`), so what ships for it is the carry hand carried over, not a hand
  measured in the open-gun view.
