# Task 188 — review request: the rifle's right hand, on the grip and on the bolt knob

Task: 188
Round: 1
Base: `f28fcd9` (`main`, #170 merged)
Code commit: `7bcc84af1d7feff73e70327df253651d2c97b65e`

Branch `task-188-rifle-right-hand`. Note `docs/research/2026-10-15-rifle-right-hand.md`. No design
run and no Architect run: no system and no owner changes. `Camera.Viewmodel.poseHands` is still the
one site that places a hand, `poses.json` is still the one place the numbers live, and what
`Rifle.Geometry` gained is the same kind of fact it already published (`boltAxis`, `hinge`, `sight`,
`beadOffset`) — where this gun's knob and grip are, and which way its handle turns.

Karen, 2026-10-15 ~09:20: *"rifle is ok now / we need to improve right hand now seems odd it has to
be aligned perfectly"*; asked where: *"Bolt pull, Holding (hip)"*.

## The harness

```
[harness] PASS: 33/33 checks @ 7bcc84af1d7feff73e70327df253651d2c97b65e (clean tree) scope=all
[harness] PASS: 33/33 checks @ 7bcc84af1d7feff73e70327df253651d2c97b65e (clean tree) scope=all
```

Run **twice**, both PASS, both at the code commit on a clean tree, logged in
`.agent-logs/task188-r1b-test1.log` and `task188-r1b-test2.log` (1472 server assertions over 55 spec
files, 343 client over 19, both runs).

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
5. `tests/server/viewmodel_poses.spec.luau` — five cases holding (4) to (1) and (2), one of which
   exists only because this task shipped the three grip poses in the **wrong rotation convention**
   first and the other four passed it (claim 11).

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

7. **Three tolerances, each meaning a different thing.** `gripRadius` (half the wrist's own
   narrowest width, 0.0719) and `gripHalfLength` (0.111 of arc, the receiver's rear to where the
   stock swells into the comb) for the hip, because a hand slides a little way ALONG a stock and is
   still holding it but cannot be behind it. `GRIP_RADIUS_STUDS` (half the hand's gap, 0.027) for
   the knob, because a knob is a ball the fist closes on. Measured, and the spec prints all of it:
   `rifle right hand hip: 0.0543 off the wrist axis, -0.0219 along it` and `rifle bolt hand: 0.0208
   studs from the knob's centre`.

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

10. **The screenshots, and what they actually show.** Three first-person frames from a DEV Play
    session with the rifle in the character, looked at before anything was claimed about them
    (rule 5). `.screenshots/t188-hip.png`: at the hip the right hand is **entirely below the bottom
    of the frame** — what is in shot is the gun and the LEFT glove's cuff as a flat olive disc on
    the fore-end. `.screenshots/t188-bolt-1.png`: mid-cycle the right hand comes up out of
    frame-bottom onto the right of the receiver, fingers forward, beside the bolt handle.
    `.screenshots/t188-marked.png`: the same view with the engine's own
    `WorldToViewportPoint` of the knob and of the hand's grip point drawn on it — the red knob
    marker lands on the drawn bolt handle's root, which is what says the measured knob and the
    drawn one are the same thing, and the blue grip marker is off the bottom edge (`visible =
    false`), which is the hand being down on the wrist.

11. **THE DEFECT THIS TASK SHIPPED FIRST, AND WHAT CAUGHT IT.** `poses.json` holds hand rotations in
    **two conventions**: `carry/aim/cycle.right` go through `Mode.handOffset`
    (`Angles(0, yaw, 0) * Angles(0, 0, pitch) * fromAxisAngle(X, twist)`), while every other hand
    block in the same file — `cycle.hand.grip`, `magazine.hand`, the horn's two — is built in
    `Viewmodel.view` as `CFrame.Angles(pitch, yaw, twist)`. The fit was solved as a MATRIX and
    written out in the second convention for all four poses. The bolt pose was right by luck of
    being in the second group. **The three grip poses were not**: the matrix they produced put the
    hand **0.158 studs ALONG the wrist axis** — past the wrist, on the comb — while sitting only
    0.045 OFF the axis, so claim 5's bound passed it and **the harness ran green twice over a pose
    that was wrong**. It was caught by looking at the running game: the mid-cycle frame, then a live
    probe of the drawn Instances whose rotation `pose * align` reproduced only under
    `Mode.handOffset`'s order. Verify: `git show b5c179c:src/shared/Viewmodel/poses.json` against
    HEAD, and the case *"reads its three angles the way `Mode.handOffset` composes them"*, which
    asserts the shipped numbers build the one CFrame and **not** the other.

12. **It was then measured in the running game, not just in the spec.** A probe read the drawn
    `HandRight` and `Bolt` Instances' CFrames in the Handle's own frame through a real cycle and
    composed `HandAssets.GRIP_STUDS` into them. At rest the grip point is `(-0.0066, -0.0950,
    0.9776)` — the fitted value to four decimals — and through the whole draw, bolt z +0.9346 back
    to +0.5145, the miss is **0.0208 studs at every sample**, with the last two samples (0.1386,
    0.2678) the hand releasing back to the grip. That is the same number the offline table and the
    spec give, obtained three independent ways.

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
   one early run of this branch and passed in all four gate runs after it, with nothing between them
   that touches a boar. Recorded as a flake seen once, not explained.
6. **What Karen sees at the HIP may not be the right hand at all.** It is below the bottom of the
   first-person frame (claim 10). What IS in shot there is the **left** glove's cuff, end-on, as a
   flat olive disc on the fore-end. Her *"Holding (hip)"* may be about that; it is the LEFT hand,
   which this task was not asked to touch, so it is reported and not changed.
7. **Whether 0.0208 studs reads as "holding" on screen.** It is 5 mm at this gun's scale and the
   knob's radius is 6.7 mm, so the knob is inside the hand — but the glove's fist is a closed one
   and the knob is behind its fingers, which is a look Karen has to judge.
