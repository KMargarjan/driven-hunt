# Task 211 — the first-person horn fits the view, with a real hand on it

Task: 211
Round: 1
Base: 70d7788 (main)
Code commit: 16198cda4df002363f87bde7a692e0c863ceaf35

```
[harness] PASS: 33/33 checks @ 16198cda4df002363f87bde7a692e0c863ceaf35 (clean tree) scope=all
```

`test2` is **N/A**: `python -c "import agents; agents.needs_two_player([...])"` answers `[]` for every
path this branch touches — `src/shared/Viewmodel/`, `src/client/Camera/Viewmodel.luau` and two spec
files, none of them in `TWO_PLAYER_PATHS` (the match, the drive, the tie, the teams).

## What changed

KAREN, 2026-10-18: *"also horn is broken arm is wrong"*. Task 206 fixed the third-person carry and
**escalated this half** (`ESCALATE.md`, 2026-10-19): a 3.125-stud horn cannot fit a 70-degree view
with a hand on it, so the glove covered 119 px against the shotgun glove's 638 and lay on the tube
like a sticker. **The Director's decision was option B — scale the FIRST-PERSON CLONE only**, so the
horn every other player sees keeps the size Karen asked for on 2026-10-13.

* `src/shared/Viewmodel/poses.json` — `horn.scale` 0.34, both `item.pos` multiplied by it, and the
  two `right` poses re-solved. **The item ROTATIONS are untouched.** Written by `tools/pose.py`'s own
  `apply_overrides` + `write_poses` (see claim 7).
* `src/shared/Viewmodel/init.luau` — `validate` requires `horn.scale` in (0, 1]; `view` publishes it
  beside the two poses, and drops the whole block without it.
* `src/client/Camera/Viewmodel.luau` — `buildHorn` takes the scale and applies `Model:ScaleTo`;
  `hornScale` makes it part of the build's identity so a live change rebuilds; `hornMouthpiece`
  carries the same factor.
* `tests/server/viewmodel_poses.spec.luau`, `tests/client/camera_client.spec.luau` — below.

## The claims

**1. The drawn horn is scaled and the Tool's own Handle is not.** This is the whole of option B.
*Verify:* `camera_client.spec`'s *"scales the clone under the camera and never the Tool's own
Handle"*: the drawn model's `GetScale()` is `HORN.scale`, its drawn body is the real one times it,
and `handle.Size` / `body.Size` are unchanged. Its note from the run:
`the drawn horn is at scale 0.3400 (the file says 0.3400); the Tool's Handle is still 0.5000 x
1.1000 x 1.1000 and its mesh 3.1250 long`.

**2. The horn's picture is unchanged — only the hand changed.** The whole camera-space geometry is
one uniform scale about the EYE (`item.pos` × scale, every `TUBE_SAMPLES` row × scale), so every
`|x|/depth` is what it was. *Verify:* measured live in the Forest Test, the drawn tube's worst
ratios are **identical** before and after — carry 0.648 / 0.620, blow 0.592 / 0.872 — and
`.screenshots/t211-before-carry.png` against `t211-after-carry.png` (and the blow pair) are the same
horn in the same place, with a hand added. Nearest section: carry 3.307 → 1.124 studs, blow 1.031 →
0.350, both inside `viewmodel_poses.spec`'s scaled bound.

**3. The glove reads at the shotgun's own size.** *Verify:* measured on the drawn parts in the Forest
Test — the horn glove sat at 4.03 studs (**107 px** of apparent length at Karen's 955 × 785) and now
sits at 1.29 (**334 px**), against the **316 px** the shotgun's own right glove gets at 1.36 studs
from the same arithmetic. At the blow, 210 px → 626 px.

**4. The fist closes AROUND the tube.** The grip point — the hole task 188 measured through the
glove, which runs along the aligned +Y — is on the tube's measured centre line with its axis ALONG
the tangent. *Verify:* `viewmodel_poses.spec`'s *"closes the right fist around the tube in both
poses"*. Notes: `carry grip: (0.0000, -0.0882, 0.1802) is 0.0001 off the centre line (tube radius
0.0564 there), hole axis 0.00 deg off the tangent`, blow the same. Measured independently on the
DRAWN pair in the running game: `0.00 deg`, `0.0000 off`, against the shipped pose's `90.00 deg` and
`0.1019 off`.

**5. That case can fail, and the case it replaces could not.** Task 202's *"lays the right glove on
the tube"* required all three landmarks inside the tube — true of a hand lying flat on the horn,
false of a hand gripping it. *Verify:* *"...and the same measure answers 90 degrees on the pose Karen
called broken"* runs `gripOf` over `poses.json`'s own replaced numbers at their own scale and notes
`the REPLACED carry grip: (-0.0894, -0.2093, 0.5318), 0.1020 off a 0.1659 tube, hole axis 90.00 deg
off the tangent` — against the new bound of 15.

**6. The hand holds with its fingers and not its sleeve** (task 189's defect, in the one place it
could return). *Verify:* the same case asserts `fingertipOff < cuffOff`; notes `fingertip 0.1719 off
against the cuff's 0.4953` (carry) and `0.1840 / 0.4689` (blow) — which is the escalation's own
prediction that a correct grip leaves the cuff about 0.49 studs off the tube.

**7. The scale is data, tunable live, and half a horn block still draws nothing.** *Verify:*
`viewmodel_poses.spec`'s *"names a horn scale that is missing or is not a scale"* (missing, 0, -0.5
and 1.5 each named by `validate`, and a file without it publishes `HORN = nil`); and it is a
`Viewmodel.paths` number, so `python tools/pose.py set horn.scale 0.3` moves it with no commit —
`updateHorn` compares `hornScale` and rebuilds. **That is how the AFTER frames were made**: the
solved numbers were put on the running session as an override, photographed, and only then written
to the file by `tools/pose.py`'s own `apply_overrides` + `write_poses` (its `save` COMMAND resolves
the session by role, and this solo session answers "client" for both DataModels).

**8. Nothing of the world horn moved.** *Verify:* `viewmodel_poses.spec`'s *"scales the drawn horn
only — the world horn and its carry are Karen's size"* pins `Horn.MESH.SIZE_STUDS.X` at 3.125 and
`Horn.CONFIG.GRIP` at `CFrame.new(0, 0, 0.25)`; `git diff 70d7788..HEAD -- src/shared/Horn/
src/server/Weapon/Horn.luau` is empty; and the `horn.*.item.rot` numbers in `poses.json` are
unchanged in the diff.

**9. Smoke (standing rule A), in the place Karen plays.** Forest Test, beater, a fresh Play: the
Tool is `Horn` in the CHARACTER at 15 s and at the end (81.5 s held), the drawn scale is 0.34 at
both, the glove is on it at both; **0 suspect lines in 241 console lines** (no "Stack Begin", no
"attempt to", no "invalid argument", no traceback); and the feature ran — three blasts,
`[ForestTest] horn blown at (...): 19 boar(s) pushed within 357 studs`.

**10. Karen's own attributes were put back.** Every run captured `ServerStorage`'s attributes, set
`DHForestStartRole=beater` + `DHFlag_HORN` + `DHForestDriveSeconds`, restored them and READ THEM
BACK: `MATCHES AS FOUND` on every run, `DHForestStartRole` back at `hunter` and no `DHFlag_HORN`.

## What I could not verify

* **A live 360-degree turn (Learning Agent L-018).** The replayed mouse moves did not rotate the
  first-person camera — the look vector is identical in all four probes — so the turn I ran proves
  nothing and is not offered as evidence. What stands instead: `camera_client.spec`'s *"draws the
  horn in CAMERA space, so a 360 turn cannot leave it behind"* drives four very different cameras
  (one upside down, one a thousand studs away) and holds the camera-space offset to 1e-3, and
  `buildHorn` anchors every part and destroys every joint, so there is no weld chain to break.
* **CI.** `selene src`, `selene --config tests/selene.toml tests`, `stylua --check src tests` and
  `rojo build` all pass locally; the branch is pushed, but `gh` is not authenticated in this session,
  so the run's own green is the Director's to read.
* **The blow pose is a feel call.** The glove at the mouth is now 626 px — a third of the frame
  (`t211-after-blow.png`). It is the arithmetic working as designed (the hand is 0.69 studs from the
  eye, which is where a hand blowing a horn is), and the horn behind it is exactly where it was. If
  Karen wants it smaller, `horn.scale` is one number and the Director can move it live.
* **The glove's hole axis** was re-checked by LOOKING at the drawn mesh posed on the real horn rather
  than by ball-marking a parked clone: the before frame shows the hand flat on the tube with the hole
  across it, the after frame shows the fist wrapped with the tube emerging both sides. That is the
  prediction the "hole runs along the aligned +Y" measurement makes, and it is what the picture does.
  A fixture that marks the axes in isolation was not built.
