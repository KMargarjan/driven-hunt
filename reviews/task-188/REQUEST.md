# Task 188 — review request: the rifle's right hand, on the grip and on the bolt knob

Task: 188
Round: 1
Base: `f28fcd9` (`main`, #170 merged)
Code commit: `PENDING`

Branch `task-188-rifle-right-hand`. Note `docs/research/2026-10-15-rifle-right-hand.md`. No design
run and no Architect run: no system and no owner changes. `Camera.Viewmodel.poseHands` is still the
one site that places a hand, `poses.json` is still the one place the numbers live, and what
`Rifle.Geometry` gained is the same kind of fact it already published (`boltAxis`, `hinge`, `sight`,
`beadOffset`) — where this gun's knob and grip are, and which way its handle turns.

Karen, 2026-10-15 ~09:20: *"rifle is ok now / we need to improve right hand now seems odd it has to
be aligned perfectly"*; asked where: *"Bolt pull, Holding (hip)"*.

## The harness

```
PENDING
```

Run **twice**, both PASS, both at the code commit on a clean tree.

**`test2` is N/A.** No file this task touches is in `TWO_PLAYER_PATHS`: they are
`src/shared/Rifle/Geometry.luau`, `src/shared/HandAssets.luau`, `src/client/Camera/Viewmodel.luau`,
`src/shared/Viewmodel/poses.json` and `tests/server/viewmodel_poses.spec.luau` — the weapon and the
viewmodel, which the 2026-10-03 decision names explicitly as one-player. A second client draws a
second right hand on a second rifle and answers nothing the first did not.

## What changed, and why

Nothing in the repo said **where the rifle was held**, so the right hand's poses could not be wrong —
and they were in fact the **shotgun's six numbers, byte for byte**. Both ends are measured now and
the pose file is held to them by the spec.

1. `src/shared/Rifle/Geometry.luau` — four measured anchors and one correction:
   `boltKnobOffset`/`boltKnobRadius` (a least-squares sphere through the bolt group's surface past
   the action's right wall), `gripOffset`/`gripAxis`/`gripRadius` (the narrowest cross-section of the
   wood behind the receiver, and its principal direction), `offGripAxis` (the one expression for "is
   the hand on the grip"), and **`boltLift`**, which owns how far and **which way** the handle turns.
2. `src/shared/HandAssets.luau` — `GRIP_STUDS` and `GRIP_RADIUS_STUDS`: where the right glove's own
   fist closes, measured as the enclosed hole in its silhouette. Read by nothing at run time.
3. `src/client/Camera/Viewmodel.luau` — `hinge`'s slide path calls `Geometry.boltLift` instead of
   turning the group by a negative angle of its own. **This is the behaviour change**, claim 3.
4. `src/shared/Viewmodel/poses.json` — the rifle's `carry.right`, `aim.right`, `cycle.right` (one
   grip pose) and `cycle.hand.grip` (the bolt pose). Content lane; four entries; the shotgun's own
   numbers are untouched.
5. `tests/server/viewmodel_poses.spec.luau` — four cases holding (4) to (1) and (2).

## Claims, and how to verify each

1. **The rifle's right hand was the shotgun's, byte for byte.** `git show f28fcd9:src/shared/Viewmodel/poses.json`
   and compare `weapons.rifle.carry.right` with `weapons.shotgun.carry.right`: pos
   (-0.0456, -0.1976, 0.992), rot (pitch -24.4176, yaw -103.1991, twist -35.5376) in both, and
   `rifle.aim.right` / `rifle.cycle.right` equal to the shotgun's `aim.right` / `reload.right` the
   same way. The note's section 5(a) says what that cost on a gun whose wrist is elsewhere.

2. **The two anchors on the gun are measured, not chosen, and the numbers are written down beside
   them.** `Geometry.boltKnobOffset` / `gripOffset` in `src/shared/Rifle/Geometry.luau`: the
   constants' comment gives the fit (sphere centre, radius, mean and worst residual) and the slice
   table the wrist came from. Cross-check against the file's own header box for the bolt group —
   `bolt X[-0.0640 +0.1150] Y[+0.0167 +0.1887] Z[+0.2034 +0.8258]` — the knob's centre (0.0879,
   0.0428, 0.6340) with radius 0.0256 lies inside it and reaches x 0.1135 at its outer face, which is
   that box's +X wall to a thousandth.

3. **The bolt handle used to turn into the receiver, and now it lifts.** The knob's centre is
   0.0428, the axis it turns about is `boltAxisY` 0.11 — so the handle hangs **below** the line it
   turns about, and `CFrame.Angles(0, 0, -rad(60))` (the shipped expression, `git show
   f28fcd9:src/client/Camera/Viewmodel.luau`) carries it to (-0.0142, +0.0003): left of the gun's
   centre line and inside the stock. Verify arithmetically from those three numbers, or read the case
   *"lifts the bolt handle UP and clear, not down into the receiver"* in
   `tests/server/viewmodel_poses.spec.luau`, which asserts the closed knob is below the axis, the
   lifted knob above it, and the lifted knob further out in +X.

4. **`boltLift` takes the angle rather than reading it, and that is not fussiness.** The axis scales
   with the weapon row's `HANDLE_SIZE`; `BOLT_LIFT_DEG` comes from the **pose data**
   (`cycle.liftDeg`). The two live in different tables, and the first version of this function read
   one `config` and would have got a zero from whichever of the two it was handed. See the function's
   comment and `Viewmodel.hinge`'s call site, which passes `row` and `config.BOLT_LIFT_DEG`
   separately.

5. **The hip, aimed and cycle hands all hold the wrist, and they are the same pose.** The case
   *"holds the wrist of the stock at the hip, aimed, and when the cycle starts"* drives
   `Mode.handOffsetAt` — the one conversion site, so these are the CFrames the viewmodel really draws
   with — and asserts `offGripAxis < gripRadius` for all three; `TestKit.note` prints each distance.
   The case below it asserts the hip and the aimed hand are the same place, because a right hand that
   moved when the eye went to the scope would read as the gun being re-gripped on every aim.

6. **The bolt hand pinches the knob, and cannot come off it.** The case *"pinches the bolt knob, and
   keeps pinching it wherever the bolt has got to"* asserts the grip point is within half the hand's
   own gap of the knob's centre, then composes an **arbitrary** rigid motion onto both and asserts
   the distance is unchanged — the property `poseHands` has by construction, because it places this
   hand from the same transform the bolt is drawn with. It is a property, not a sampled frame.

7. **The two tolerances are different on purpose.** `gripRadius` (half the wrist's own narrowest
   width, 0.0719) for the hip, because a hand slides a little way along a stock and is still holding
   it — what must be true is that the grip point is inside the **wood**. `GRIP_RADIUS_STUDS` (half
   the hand's gap, 0.027) for the knob, because a knob is a ball the fist closes on. Measured:
   0.0543 against 0.0719, and 0.0208 against 0.027. Round 1 of this task bound both to the hand's
   gap and the hip case failed; the commit `b5c179c` message says so.

8. **The before/after table is measured off the shipped meshes, and the mapping is checked rather
   than assumed.** Note section 4: the game frame is `(fz, fy, -fx)` of the published group glTFs,
   which reproduces the split report's own `minStuds`/`maxStuds`; the glove is scaled so its longest
   axis is `HAND_LENGTH_STUDS`, which reproduces `HAND_RIGHT_NATURAL` to four decimals. Section 7 has
   the table: knob miss 0.5260 -> **0.0208** at every frame the hand is on the knob, glove-to-knob
   skin 0.2832 -> **0.000**, glove inside the gun through the cycle 30-43 % -> 0-2.1 %, hip wrap 0.25
   -> **1.00**, hip contact 32.8 % -> 49.7 %.

9. **Nothing but the rifle moved.** `git diff f28fcd9 -- src/shared/Viewmodel/poses.json` is four
   entries, all under `weapons.rifle`; the shotgun's and the horn's are untouched. The shotgun never
   reaches `boltLift` — its `CYCLE_KIND` is `hinge`, and that branch is unchanged.

10. **The screenshots.** Two first-person frames from a DEV Play session with the rifle in hand —
    the hip hold and the bolt drawn back — in `.screenshots/`, named in the report, looked at before
    anything was claimed about them (rule 5).

## What I could not verify (rule 8)

1. **Whether Karen likes it.** The numbers say the hand is on the grip and on the knob; whether the
   wrist angle reads as a hunter's hold is hers.
2. **The glove cannot actually close on this wrist.** Its gap is 0.054 x 0.060 and the wrist is
   0.144 x 0.203, so "on the wood with no gap" and "no fingers through the stock" cannot both be
   true. What ships is contact with the overlap spread evenly and **reported**: 23.3 % of the glove's
   surface inside the wood at the hip against 22.6 % before — about the same overlap, in the right
   place instead of the wrong one. A fist that really closes on this stock is a new glove, which is
   an asset task and Karen's call. Note section 6.
3. **The index finger cannot reach the trigger guard.** The glove's longest extended digit is 0.183
   studs from the fist's gap and the trigger is 0.29 studs forward of the wrist, so with the fist on
   the wrist it reaches the rear of the receiver at best. The dispatch asked for *"straight along the
   side of the receiver above the trigger guard"*; the first half holds, the second is out of reach
   on this hand, and nothing was bent to fake it. Note section 9.3.
4. **The forearm** is off the bottom of the first-person frame at the hip. Its direction was
   constrained to run back and down toward the shoulder and then not looked at again.
5. **`boar_body.spec`'s two live sounder cases** (`:731`, `:740`, `herd:sounders()[1]` nil) failed in
   the first run of this branch and passed in both gate runs after it, with nothing between them that
   touches a boar. Recorded as a flake seen once, not explained.
