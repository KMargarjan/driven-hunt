# Task 176 - the horn in the first-person view, held in the hands

Task: 176
Round: 1
Base: `9976665` (main, #159 merged -- 175)
Code commit: `15bbc0c0ad1430a4cf629ba245f2c1e7c5c43e49`

```
[harness] PASS: 33/33 checks @ 15bbc0c0ad1430a4cf629ba245f2c1e7c5c43e49 (clean tree) scope=all
[harness] PASS: 33/33 checks @ 15bbc0c0ad1430a4cf629ba245f2c1e7c5c43e49 (clean tree) scope=all
```

`test2` is **N/A**: no path in `TWO_PLAYER_PATHS` is touched. The nine code files are
`src/shared/HeldTool/init.luau` (new), `src/shared/Horn/init.luau`,
`src/shared/Viewmodel/init.luau`, `src/shared/Viewmodel/poses.json`,
`src/client/Camera/Viewmodel.luau`, `src/client/Camera/Rig.luau`,
`src/server/Weapon/Horn.luau`, plus the three specs `tests/server/zz_horn.spec.luau`,
`tests/server/viewmodel_poses.spec.luau` and `tests/client/camera_client.spec.luau`.

## What changed

KAREN, 2026-10-13 ~19:05: *"horn still hangign somewhere it has to be in hand now I can turn around
and horn stand in place somehwere behind"*, and 2026-10-12 ~21:45: *"we need when I am playing beater
to make animation when raising horn to face and blow"*.

**DIRECTOR DECISION on task 175's escalation (item 1), 2026-10-13: option B now** -- the horn gets a
first-person view like the gun's. Option A (the character's body faces the camera) is queued as its
own later task and is deliberately NOT done here. The decision is transcribed into `ESCALATE.md`
under the 175 entry and marked as the Director's.

Five pieces:

1. **One shared fact.** `ReplicatedStorage.HeldTool.kindOf(tool)` answers *what does the first-person
   view draw for this Tool?* -- `"weapon"`, `"horn"`, or nil. `Camera.Viewmodel` draws what it names;
   `Camera.Rig` hides the real Tool's parts when it names something. Task 152's refusal is kept for
   every OTHER non-weapon Tool.
2. **The drawn horn is a clone of the Tool's own Handle**, stripped to what may live under a camera
   (no `Sound`, no joint, no script; anchored, `CanQuery = false`, `LocalTransparencyModifier = 0`),
   with the same fill light the gun gets and the right glove on it.
3. **The blast window** is task 168's three numbers and no fourth. `Weapon.Horn.blowTool` -- the one
   door every accepted blast comes through -- stamps an increasing counter on the Tool
   (`Horn.BLOW_ATTRIBUTE`); the viewmodel starts ITS OWN clock on the change and asks the pure
   `Horn.blowWeight(since, config, pose)` how far through the gesture it is.
4. **The two poses are data**: `poses.json`'s new top-level `horn` block (`carry` and `blow`, each an
   `item` and a `right`), published by `Viewmodel.view` as `HORN`, tunable live with
   `tools/pose.py set horn.blow.item.pos.y <n>`. No timing lives there.
5. **Third person is untouched**: the server still welds the horn to the hand, still tilts `GRIP_BLOW`
   and still plays task 168's arm clip on the character's `Animator`.

## Claims, and how to verify each

1. **The drawn horn is in CAMERA space, which is Karen's complaint.** MEASURED in the Forest Test
   (place 130094961655666) on a real player beater, 2026-10-13, with the camera turned through its
   own owner (`LocalPlayer:SetAttribute("DHLookAt", ...)`, the seam the harness's input stage uses):
   ```
   yaw 0   off=(0.9500,-1.0500,-2.3000)   yaw 90  off=(0.9500,-1.0500,-2.2998)
   yaw 180 off=(0.9500,-1.0500,-2.3000)   yaw 270 off=(0.9500,-1.0500,-2.3000)
   yaw 45  off=(0.9500,-1.0500,-2.3000)   yaw 315 off=(0.9500,-1.0500,-2.3000)
   worst delta = 0.000244 studs over a full 360
   ```
   and `(0.950, -1.050, -2.300)` is exactly `poses.json`'s `horn.carry.item.pos`. The same claim is
   a spec: `camera_client.spec`, *"draws the horn in CAMERA space, so a 360 turn cannot leave it
   behind"*, four very different camera CFrames, position AND rotation delta under 1e-3.

2. **There is ONE horn on screen, not two.** Same session, same frame: of the real Tool's parts,
   `hidden=3 shown=0` -- `Camera.Rig` holds all three at `LocalTransparencyModifier = 1`. The spec
   half is in `camera_client.spec`'s *"leaves a non-weapon Tool visible, and still hides a gun's"*,
   which now carries three probes that differ by NAME alone: a gun (hidden), a Tool named
   `Horn.TOOL_NAME` (hidden, new) and `CameraSpecProbeHorn` (still visible).

3. **The complement cannot drift**, because both modules ask the same function. Grep: the only
   callers of `HeldTool.drawsFirstPerson`/`kindOf` are `Camera.Rig.trackHiddenPart`,
   `Camera.Viewmodel.update` and the specs. `Weapons.isWeaponTool` is unchanged and still answers
   false for a horn (`zz_horn.spec`, *"is not a weapon, so the first-person viewmodel will not draw a
   gun out of it"*, which now asserts both facts).

4. **A Tool neither module names draws nothing and stays visible** -- task 152 kept.
   `camera_client.spec`, *"draws NOTHING for a Tool it does not name"* (a `CameraSpecProbeLantern`),
   and `zz_horn.spec`'s `HeldTool.kindOf(other) == nil` for a `Lantern`, a `Part` and nil.

5. **The raise reaches the mouth.** MEASURED on a real ACCEPTED blast (the player's own
   `Tool:Activate()`, the server's own gate, stamp 19): the drawn horn sat at exactly
   `horn.blow.item` `(1.045, 0.095, -1.075)` and its MOUTHPIECE at **(-0.001, -0.450, -0.050)** in
   the camera's own frame -- within 0.001 studs of the view's vertical axis and below the eye, which
   is the note's target (|x| <= 0.15). `camera_client.spec` measures the same point and prints it;
   its run of the gate printed `(-0.001, -0.450, -0.050)`, the same numbers.

6. **It comes back down, on task 168's clock.** Live: 1.4 s after the blast the offset was
   `(0.950, -1.050, -2.300)` again -- the carry. Pure: `zz_horn.spec`'s *"raises, holds and lowers on
   TASK 168's three numbers and no fourth"* drives `Horn.blowWeight` at nil, -0.5, 0, up/2, up,
   (up+held)/2, held, held+down/2, held+down and held+down+10, and a second case walks both ramps at
   a twentieth of their length to prove it monotonic.

7. **A REFUSED blast raises nothing.** `zz_horn.spec`, *"sounds once per cooldown..."*: the attribute
   reads 1 after an accepted blast, is STILL 1 after a click inside the cooldown, and 2 after the
   next accepted one. That is why the camera watches this attribute and not the player's click.

8. **The pose numbers are content-lane data.** `viewmodel_poses.spec`: `validate` names a missing
   `horn` block, a missing `horn.blow`, and every half of a pose; `view().HORN` is four CFrames built
   at the one conversion site, with no timing field under any name; `Viewmodel.paths` lists seven
   `horn.*` paths, and an override of `horn.blow.item.pos.y` reaches `view()`. Confirmed with the
   tool itself: `python tools/pose.py show` lists the twelve `horn.*` numbers.

9. **Third person is unchanged.** `src/server/Weapon/Horn.luau` gains exactly one statement (the
   attribute stamp) -- `git diff main..HEAD -- src/server/Weapon/Horn.luau` is that plus its comment.
   `Horn.CONFIG.GRIP`, `GRIP_BLOW`, `BLOW_POSE`, `blowSequence` and `Horn.raise` are untouched, and
   the mouthpiece invariant case of task 175 still passes unchanged.

10. **The gate.** Two full clean-tree runs at the code commit, both `33/33 ... scope=all` (pasted
    above), `1250 passed, 0 failed` on the server and `305 passed, 0 failed` on the client. The
    Director's `smoke.sh` in the Forest Test: `gun in hand @15s=1 @80s=1 | stacks=0 errorLines=0 |
    waves=5` -> **SMOKE PASS**. A Forest Test Play console over the beater session: 0 "Stack Begin",
    0 error lines, three `[ForestTest] horn blown at ...` lines from the player's own blasts.

## What I could not verify, and what I got wrong

* **The LOOK is Karen's** (rule 5 and her own rule). Two frames inspected, both in
  `.screenshots/` on this machine (git-ignored):
  `20261013T190825Z-t176-fp-carry-d.png` -- the pale horn across the lower right, the decorated band,
  the bell forward-down-left, the brown glove on the tube; and
  `20261013T191258Z-t176-fp-raised-c.png` -- the horn rising from the bottom-right corner up the
  right side with the mouthpiece at the frame's bottom edge, the view otherwise clear. **It took
  three tries each.** The first carry was end-on at the lens (a slab of tube, no shape); the second
  blow put the mouthpiece cup 0.4 studs in front of the lens and filled a quarter of the screen with
  a grey funnel. Both are tunable by the Director in the content lane without a round.
* **The right glove is drawn in the live game and was NOT drawn in the gate's own client run** --
  `camera_client: the drawn horn has NO right glove`. The hand templates are loaded by the server
  and published to `ReplicatedStorage`; in the Forest Test they were there (the glove is in both
  screenshots), in that DEV spec frame they were not. The case notes it rather than demanding it,
  which is the same honesty `Viewmodel.hands` already keeps with `stats.handsMissing`.
* **The glove's ROTATION is the gun's grip rotation**, seeded rather than fitted: it reads as a hand
  on the tube in the frames, not as fingers wrapped round it. It is four numbers in `poses.json`
  (`horn.carry.right.rot`), tunable live; I did not spend the task's time on it.
* **`tools/pose.py` could not drive the live session** while the DEV Studio was also connected:
  `[pose] no running session (no Studio answered as 'server'; connected: client/<name>, edit)`. The
  Forest Test's Play-solo process answers `client`, and `pose.py` asks `studio_for_role(..., "server")`.
  So the poses here were tuned by editing `poses.json` and restarting Play, three times. That is a
  TOOL limitation, not this change's, and it is reported rather than worked around -- it will bite
  the Director the first time they try to tune the horn live with both Studios open.
* **A `/beater` role switch at runtime was not driven** (the chat command cannot be fired from a
  probe). What was driven instead: a server-side `LoadCharacter()` respawn, after which the horn is
  drawn again at the carry pose with its six children; and the gun<->horn switch, as a spec claim.
* **`poses.json` stays at version 4** and the reason is written into `Viewmodel.validate`: the version
  marks a change to how EXISTING numbers are read, and this block changes the meaning of no existing
  path -- it is a new sibling, as `look` is. A file without it is refused by `validate` (`horn is
  missing`), so the absence is loud rather than silent.
* **I got the first-person gesture's own clock wrong twice in the spec** and the gate caught both:
  the frame that NOTICES the attribute change is the start of the gesture, not a frame into it; and
  `Viewmodel.update` asks its source four times a second, so an update called the instant after
  `setSource` still draws what was in the hand before.
