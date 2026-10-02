# Task 108 - the hands on model B hold the gun

Task: 108
Round: 2
Base: `content-model-b-aim-1` (`1ee7ba0`)
Code commit: `156012b9a8d88ee0941632e30617ae2213015164` (the paperwork commit; the last code commit
is `ed6ffd7` and only this file and the TASKS row changed after it)

```
[harness] PASS: 32/32 checks @ 156012b9a8d88ee0941632e30617ae2213015164 (clean tree)
[harness2] PASS: 34/34 checks @ 156012b9a8d88ee0941632e30617ae2213015164 (clean tree)
```

`test2` is required: the branch also changes `src/shared/HandAssets.luau` and
`src/client/Camera/Config.luau`, both outside `WEAPON_VIEWMODEL_PATHS`.

## Claims

1. **THE SHIPPED FRAMES, AS THEY ARE** (round 1, finding 1 -- round 1 described only a rejected
   state). `.screenshots/20261002T150634Z-pose-carry.png`: the gun runs up the left side, the left
   glove is on the forend at the bottom-left with its knuckles either side of the barrels, and the
   olive forearm leaves through the bottom-left corner; nothing crosses the picture.
   `...150606Z-pose-aim.png`: the rib runs clean from the fences to the bead with no glove over it,
   the left glove's knuckles stand either side of the barrels BELOW the rib, and the sleeve is a
   patch going out of the bottom-left. `...150618Z-pose-reload.png`: the gun is broken open with two
   brass heads showing, the left glove is still on the forend, and the forearm runs down out of the
   bottom edge. `...150646Z-inspect-aim-left-front.png` (outside): both forearms run down and back
   out of the bottom of the frame; **the gloves' own cuffs are open mouths facing up-left** -- see
   "What I could not verify". No glove touches the wood in any of the four.
2. **Each forearm runs toward its own shoulder, in the CAMERA's frame.** Round 1 ran the sleeve back
   along the pose frame's -X, which is the wrist: the left yaw of 15 that puts the hand on the forend
   also swung the arm out sideways, which is the bar the Director saw. `SLEEVE_TO_LEFT_SHOULDER` /
   `SLEEVE_TO_RIGHT_SHOULDER` are down, back and a little outboard -- the same vector in carry, aim
   and reload, because a shoulder does not move with the grip. Verify: `Viewmodel.armDirection` and
   `poseHands`'s `armFrame`; nil for the old gun, whose sleeve is placed exactly as before.
3. **The client case now fails if `Viewmodel.align` is deleted** (finding 2). Every round-1 assertion
   read a POSITION, and `align` is a pure rotation about the hand's own centre, so none of them could
   move with it -- the case said otherwise and was wrong. It now carries each glove's own measured
   `fingers` through the CFrame of the part really drawn and requires it on the pose frame's +X
   (>0.999) and the palm near +Y (>0.85, because `align` squares an estimated palm), plus `align`
   identity and `armDirection` nil with the flag off. **Mutation-checked once**: with `align`
   returning identity, `gun_client.spec:225` FAILED.
4. **`handLengthAlongFingers` projects the box onto the finger axis** (finding 3) instead of picking
   the nearest side, which answered `Size.Y` = 0.534 for the left glove where the true extent is
   0.914 -- and half of 0.534 is UNDER the 0.30 overlap, so the wrist segment's near end would have
   started on the finger side of the glove's centre. `tests/server/gun.spec.luau`'s
   "starts each gun's sleeve INSIDE the glove" now asks that bound of `gun.hand.left` as well, in the
   quantity the code really uses, and the client stubs are shaped per glove (the left one's box is
   its own diagonal), so the left branch is really exercised.
5. **`HandAssets.AXES`' comment is rewritten** (finding 1's other half): it said nothing read the
   axes and the aimed view was worse, both false at HEAD. It now says what reads them, where, and
   that it reaches the new gun only.

## What I could not verify

- **The gloves' OWN cuffs are open in the outside view** (`...150646Z`): the drawn sleeve enters the
  model's cuff at a steep angle now that the arm no longer follows the wrist, so a straight tube
  cannot fill a tilted mouth. It is not visible from the EYE in any of the three frames above, which
  is why it ships; raising the overlap enough to hide it would break the right glove's own bound.
- **Only the three held poses were photographed**, not the raise between them, and only `carry` is
  driven by the client case (`stateAtBlend(0)`); aim and reload are unasserted, which is harmless
  only while all three carry the same hand numbers.
- **The reload's LEFT hand lost task 106's measured -30/35**, which was fitted in the broken-open
  frame; it now carries the carry pose's -15/0. The open-gun frame above was looked at and the hand
  is on the forend, but the old numbers were not compared against the new ones side by side.
