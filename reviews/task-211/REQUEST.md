# Task 211 — the first-person horn fits the view, with a real hand on it

Task: 211
Round: 1
Base: 70d7788 (main)
Code commit: 94470972649988cd95ebbdf78311b6b30a5404a9

```
[harness] PASS: 33/33 checks @ 94470972649988cd95ebbdf78311b6b30a5404a9 (clean tree) scope=auto:camera,viewmodel
[harness] PASS: 33/33 checks @ 94470972649988cd95ebbdf78311b6b30a5404a9 (clean tree) scope=all
```

`test2` is **N/A**: `agents.needs_two_player` answers `[]` for every path this branch touches —
`src/shared/Viewmodel/`, `src/client/Camera/Viewmodel.luau` and two spec files, none of them in
`TWO_PLAYER_PATHS` (the match, the drive, the tie, the teams).

**`Round: 1` and not 2 on purpose:** round 1's review came back `PASS`, so `tools/agents.py`
counts this as a fresh round — the counter advances on findings, not on builds. This is the second
BUILD round, after the Director looked at round 1's frames and bounced the blow pose.

## What changed

KAREN, 2026-10-18: *"also horn is broken arm is wrong"*. Task 206 escalated the first-person half:
a 3.125-stud horn cannot fit a 70-degree view with a hand on it. **The Director's decision was
option B — scale the FIRST-PERSON CLONE only**, so the horn every other player sees keeps the size
she asked for on 2026-10-13.

**Round 1 did that and the Director looked at the result**: the carry was *"good … Keep it exactly"*;
the blow was *"a giant glove, not a beater raising a horn to his lips"*. **Round 2 re-composes the
blow and changes nothing else.**

* `src/shared/Viewmodel/poses.json` — `horn.scale` 0.34; the carry's `item.pos` scaled and its
  `right` re-solved (round 1, unchanged since); the blow's `item` and `right` **re-composed**
  (round 2). Written by `tools/pose.py`'s own `apply_overrides` + `write_poses`.
* `src/shared/Viewmodel/init.luau` — `validate` requires `horn.scale` in (0, 1]; `view` publishes it.
* `src/client/Camera/Viewmodel.luau` — `buildHorn` applies `Model:ScaleTo`; `hornScale` makes it part
  of the build's identity so a live change rebuilds; `hornMouthpiece` carries the same factor.
* `tests/server/viewmodel_poses.spec.luau`, `tests/client/camera_client.spec.luau`.

## The claims

**1. The drawn horn is scaled and the Tool's own Handle is not.** The whole of option B. *Verify:*
`camera_client.spec`'s *"scales the clone under the camera and never the Tool's own Handle"* — the
drawn model's `GetScale()` is `HORN.scale`, its drawn body is the real one times it, and
`handle.Size` / `body.Size` are unchanged. Note: `the drawn horn is at scale 0.3400 (the file says
0.3400); the Tool's Handle is still 0.5000 x 1.1000 x 1.1000 and its mesh 3.1250 long`.

**2. The CARRY is bit-for-bit what the Director accepted.** *Verify:* `git diff 16198cd..HEAD --
src/shared/Viewmodel/poses.json` touches only `horn.blow.*`; the pin *"the horn's hand is where task
211 solved it"* still carries the carry's `tip (0.1542, -0.0003, 0.2067)` / `cuff (-0.4623, -0.2307,
0.2550)` unchanged from round 1.

**3. The blow was re-built from the gesture, not nudged.** The mouthpiece is PLACED at the lips —
`(0, -0.33, -0.42)` in the camera's own frame — and the horn's axis AIMED up and forward (35° of
elevation, 12° of yaw); only then is the grip solved on the tube. *Verify:* the measured mouthpiece
in the camera's frame is `(0.0000, -0.3300, -0.4200)`, so `camera_client.spec`'s *"within 0.15 studs
of the view's own vertical axis, below the eye"* now reads **0.000** against its bound of 0.15.

**4. The hand is at the bottom of the frame with the forearm leaving it.** The Director's bar.
*Verify:* the new case *"puts the blowing hand at the bottom of the frame, forearm leaving it"*.
Note: `blow glove: centre (-0.011, -0.490) at 0.931 studs, cuff (0.153, -0.654), fingertip (-0.241,
-0.314); half view 0.700, bottom quarter -0.700..-0.350`. The carry is held to the same
forearm-below rule and its own centre is `(0.309, -0.652)`.

**5. That case can fail, shown on the numbers it was written for.** *Verify:* *"...and round 1's
blowing hand floated in the middle of that frame"* runs the same projection over round 1's own
twelve numbers: `the REPLACED blow glove: centre (-0.189, -0.060), which is 0.060 of the way down a
half frame of 0.700 — the bottom quarter starts at -0.350`.

**6. The glove is smaller, and the grip moved toward the mouthpiece as asked.** *Verify:* measured
on the drawn pair in the Forest Test — the blow glove went **625 px → 461 px** of apparent length at
Karen's 955 × 785 (0.687 → 0.931 studs from the lens). The carry's is 334 px and the shotgun's own
right glove is 316 px. The grip's own Z on the tube went 0.53 → **0.75** (the mouthpiece is at
+1.5625).

**7. The fist still closes AROUND the tube in both poses.** The round-1 property, preserved by the
re-composition. *Verify:* *"closes the right fist around the tube in both poses"* — notes `carry
grip … hole axis 0.00 deg off the tangent` and `blow grip: (0.0000, -0.0881, 0.1802) is 0.0000 off
the centre line (tube radius 0.0673 there), hole axis 0.00 deg off the tangent, fingertip 0.1732 off
against the cuff's 0.5328`; and *"...and the same measure answers 90 degrees on the pose Karen
called broken"* keeps task 202's own numbers as the thing that must fail.

**8. The horn is still inside the picture.** *Verify:* *"draws the whole horn inside the picture at
the carry"* and *"brings the mouthpiece to the mouth without filling the screen"* — the blow's worst
ratios are now `0.259 / 0.582` against the half view 0.700, and its nearest section is 0.411 studs
against the scaled bound `max(1.0 × scale, NEAR_PLANE_MARGIN_STUDS)` = 0.34.

**9. Smoke (standing rule A), in the place Karen plays, on this commit.** Forest Test, beater: the
Tool is `Horn` in the CHARACTER at 15 s and at the end (81.4 s held), the drawn scale is 0.34 and
the glove is on it at both, **0 suspect lines in 240 console lines** (no "Stack Begin", no "attempt
to", no "invalid argument", no traceback), and the feature ran — `[ForestTest] horn blown at (…): 7
boar(s) pushed within 357 studs`.

**10. Karen's own attributes were put back.** Every run captured `ServerStorage`'s attributes, set
`DHForestStartRole=beater` + `DHFlag_HORN` + `DHForestDriveSeconds`, restored them and READ THEM
BACK: `MATCHES AS FOUND` on all four runs of this round.

## What I could not verify

* **A live 360-degree turn (L-018).** Replayed mouse moves do not rotate the first-person camera in
  this harness — the look vector was identical across four probes — so no turn I can drive is
  evidence. What stands: `camera_client.spec`'s *"draws the horn in CAMERA space, so a 360 turn
  cannot leave it behind"* drives four very different cameras (one upside down, one a thousand studs
  away) and holds the camera-space offset to 1e-3, and `buildHorn` anchors every part and destroys
  every joint, so there is no weld chain to break.
* **CI.** `selene`, `stylua --check` and `rojo build` pass locally; `gh` is not authenticated in this
  session, so the run's own green is the Director's to read.
* **"No finger pointing out" is not fully achievable and is reported rather than claimed.** The right
  glove is modelled as a fist with ONE EXTENDED digit, and its hole runs along the aligned +Y — so a
  fist whose hole is on the tube necessarily has that finger ~70° off the tube's axis. What the
  re-composition does instead is turn the hand about the tube until the finger lies low and across
  the glove's own silhouette: the fingertip projects to `(-0.241, -0.314)`, inside the hand's own
  area rather than out in the sky. Looked at in `t211r2-blow-P4.png`.
* **The four candidate compositions were judged by eye**, in one live session, against the
  Director's words. `t211r2-blow-shipped.png` (round 1) against `t211r2-blow-P1/P2/P3/P4/P5.png`;
  P4 ships. A different pick is a live `pose.py set` away.
