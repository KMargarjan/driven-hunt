# Task 202: one horn in the picture, and a glove that is on it

Task: 202
Round: 1
Base: 1e49c40 (main, #182 merged -- task 193)
Code commit: dbd60db8eed360b44362706653d6c24a7967cb37

KAREN, 2026-10-14 ~17:00, verbatim: *"beater hadn is bad and 2 horsn instead 1 it's broken"*.

Gate, both at the code commit and both on a clean tree:

```
[harness] PASS: 33/33 checks @ dbd60db8eed360b44362706653d6c24a7967cb37 (clean tree) scope=all
[harness] PASS: 33/33 checks @ dbd60db8eed360b44362706653d6c24a7967cb37 (clean tree) scope=auto:boar,match,places,viewmodel,weapon
```

`test2` is **N/A**: no `TWO_PLAYER_PATHS` file is touched, checked against `tools/agents.py`'s own
list over `git diff --name-only 1e49c40..HEAD` (the nine paths are `TASKS.md`, the horn research note,
`src/server/ForestTest/init.luau`, `src/server/ForestTestBoot.server.luau`, `src/shared/Horn/init.luau`,
`src/shared/Viewmodel/poses.json`, `tests/server/forest_stand.spec.luau`,
`tests/server/viewmodel_poses.spec.luau`, `tests/server/zz_horn.spec.luau`). SMOKE PASS in the Forest
Test: `gun in hand @15s=1 @80s=1 | stacks=0 errorLines=0 | waves=2`.

## What changed, and how to verify each claim

**1. There is exactly ONE horn drawn, and there always was -- so the premise this task was given is
wrong and I did not build to it.** Measured as a real player beater in Karen's Forest Test, in five
states: at rest, blowing, after a respawn, after `/hunter` -> `/beater`, and (pre-fix session) after a
new drive. Every one: the viewmodel clone under `workspace.CurrentCamera` with 2 drawn parts (the horn
mesh and the right glove), the real Tool's 2 parts on the character at `LocalTransparencyModifier = 1`,
and `strayPieces=0` over the whole of `Workspace`. **Verify:** `Camera.Rig.trackHiddenPart` and
`Camera.Viewmodel.update` ask the same `HeldTool.drawsFirstPerson` / `HeldTool.kindOf`, unchanged by
this task; task 176's complement holds.

**2. The ONE horn was DRAWN as two, and that is Karen's sentence.** At the shipped carry pose the
3.125-stud horn ran from 3.61 studs in front of the lens to **0.99**, and its near end projected to
**x = 1455 on a 955-pixel screen**. A ray cast through the viewmodel at eye height hit the horn mesh at
x = 500..700, the glove at 740..800, **NOTHING at 840..880**, and the horn again at 910..940: two pale
masses with clear background between them. **Verify:** `.screenshots/t202-before-carry.png` (eye height,
camera `(3030, 238.81, -1517.40)` looking -Z) against `t202-after-carry.png` at the SAME camera.

**3. Nothing in the repo knew where the horn was inside its own envelope, which is why nothing could
see it.** `Horn.MESH` gives the mesh's BOX (3.125 x 1.084 x 0.599); the box is nearly empty, and both
the first-person pose and its hand were solved against it. `Horn.TUBE_SAMPLES` is the tube itself,
raycast off a clone of the real Handle at 0.125-stud steps along the Handle's Z; `Horn.tubeAt(z)` reads
it. **Verify:** the samples' two ends agree with `Horn.mouthpieceOffset` and `Horn.bellOffset` (+Z is
0.13 studs across, -Z is 0.56), and `.screenshots/t202-horn-fixture.png` photographs that clone with a
red ball on the Handle's +Z and a blue one on its -Z -- the red one is at the dark narrow tip.

**4-6. Three new cases in `viewmodel_poses.spec` measure the drawn horn against the PICTURE and the
glove against the HORN, and all three FAIL on the pose data this task replaces.** Run at the pre-fix
commit (`<runs-dir>/t202-prefix-fail.log`): carry `worst |x|/depth 1.6282` against a half view of
`0.7002`; blow `nearest -0.2297` studs -- the mouthpiece was BEHIND the eye -- and `|y|/depth 1.3913`
over the horn up to z = 1.0; the glove's grip `0.2100` off the centre line of a tube whose radius there
is `0.1854`. At the code commit they read 0.6473 / 0.6203 / 3.3068, 0.5918 / 0.5373 / 1.0315, and
0.615 / 0.916 / 0.738 of the local radius. **Verify:** the three `it(...)` names under *"the drawn horn
is in the picture, and the glove is on it (task 202)"*, and the `TestKit.note` lines they print.

**7. The mouthpiece was not on the horn either, and the CLIENT gate is what caught it.**
`camera_client`'s *"within 0.15 studs of the view's own vertical axis"* failed on the new blow pose --
rightly, because `Horn.mouthpieceOffset` answered the centre of the box's +Z end FACE, which is 0.4415
studs above the tube there. Task 176 met that target with a point in mid-air beside the horn. The end
is still chosen by `MESH.ROTATION_DEG`; it is now lifted onto the measured centre line. In this task's
blow pose the box end reads **0.410** studs off the view axis and the measured tip **0.025**.
**Verify:** `Horn.mouthpieceOffset`, and `zz_horn.spec`'s *"puts the MOUTHPIECE where task 175's
invariant says it is"*, which now pins the measured point and asks the samples whether it is on the tube.

**8. Karen's `/beater` and the Director's `DHForestStartRole` were both dead, and the fix is a sweep
rather than a second edge handler.** `Players.PlayerAdded` did not fire for the only player in a Play
Solo session -- measured twice, and the proof is that NEITHER print inside that handler appeared
(`[ForestTest] ... asked to join as a <role> (start switch)` and `[ForestTest] ... is a <role> at
(...)`). Both routes into a role live in there, the `player.Chatted` connection included. The boot now
asks `ForestTest.toWire` every Heartbeat who is unwired, against its own `wired` record, and
`PlayerRemoving` forgets a player so a rejoin is wired again. **Verify:** after the fix the same session
prints `asked to join as a beater (start switch)` and `is now a beater (team=Drivers)`;
`forest_stand.spec`'s *"says who is still unwired, however early he joined (task 202)"* fails at the
previous commit with `forest_stand.spec:1028: attempt to call a nil value`.

**9. The two poses and the glove are `poses.json` data; what is NOT data is what holds them.** The
numbers were solved from `TUBE_SAMPLES` and `HandAssets.GRIP_STUDS` / `FINGERTIP_STUDS` / `CUFF_STUDS`,
not eyeballed, and then LOOKED at. The glove is laid ALONG the tube, which is the shotgun's own carry
shape. Because the carry and the blow no longer share one roll, both right-hand poses are pinned.
**Verify:** `.screenshots/t202-after-carry.png` and `t202-after-blow.png`, both at eye height from the
camera above; `t202-after-carry-hand.png` is the carry's hand at 4x.

## What I could NOT verify

* **Karen has not seen it.** It is all look; the frames are mine.
* **"After a new drive" was measured pre-fix only** (1 horn). Post-fix I measured rest, blowing,
  respawn and the role swap. After a new drive the solo player is a SHOOTER again unless she asks for
  the role again -- that is the roster's `ODD_PLAYER_TEAM` rule and not a horn fault.
* **The third-person `GRIP_BLOW` still aims the BOX end at the hand** (`zz_horn.spec`'s
  `MOUTH_IN_HAND` invariant, untouched). The same error as claim 7, in a pose Karen has already
  accepted; reported rather than changed here.
* **A harness fault, reported per rule 6:** with two Studios connected, `list_roblox_studios`
  intermittently returns only ONE of them, and when that one is the Forest Test the harness pins no
  default and addresses the WRONG place -- `Studio has the DEV place open (130094961655666 vs
  136410205938347)` is what catches it, so no run is wrongly passed, but three runs were wasted. Every
  gate line above comes from a run whose first line reads *"unscoped calls default to Driven Hunt DEV"*.
