# Viewmodel poses as data, tuned live (task 98)

2026-10-01. Short note (rule 1) for a task whose novelty is a workflow rather than a system.

## 1. What the system must do

Karen, 2026-10-01, after task 97 was stopped mid-round: *"weapon is shit, aiming is shit, no recoil,
smoke is shit -- follow the video"*, and then, on the process, that it was **too slow**. Task 97 spent
three rounds and several hours moving numbers by hand, and each move cost a Luau edit, a harness run
and a review. What is being tuned is a **picture** -- the gun against a video frame -- so the loop
has to be: change a number, look at the screen, change it again.

So:

1. Every first-person pose number lives in **one data file**, not in Luau.
2. The **Director can change one inside a running Studio session** and see it on the next frame, with
   no commit, no review and nothing in the git tree.
3. The keepers are written **back into the file** by a tool, and only that commit goes through the
   gate.
4. A pose can be **held and photographed beside the reference frame**, with the landmarks measured
   rather than eyeballed.
5. Today's behaviour -- the blend, the timings, the bead on the shot line -- is **unchanged** by the
   move to data.

## 2. Sources

| # | Source | Licence / status | Good | Bad |
|---|---|---|---|---|
| 1 | Roblox engine API: [`Keyframe`](https://create.roblox.com/docs/reference/engine/classes/Keyframe), [`KeyframeSequence`](https://create.roblox.com/docs/reference/engine/classes/KeyframeSequence), [`Pose`](https://create.roblox.com/docs/reference/engine/classes/Pose) | First-party, maintained | **The platform's own answer to this exact question.** A `KeyframeSequence` is a tree of `Keyframe`s, each holding `Pose`s (a `CFrame` per joint) at a `Time`, interpolated between on playback. That is the shape: named poses, each a transform per part, keyed by time, with the easing named per pose | It is built for **rigged characters driven by `Motor6D`/`Animator`**. Our first-person gun is anchored parts and MeshParts parented to `workspace.CurrentCamera` with no rig and no humanoid (that is what `Camera.Viewmodel` is), so the *classes* do not apply even though the *shape* does. A `KeyframeSequence` also has to be uploaded or built as Instances -- neither is a file a tool can rewrite and a PR can diff |
| 2 | Rojo [Sync Details](https://rojo.space/docs/v7/sync-details/) -- "JSON Modules" | MIT, actively maintained; pinned at 7.7.0 in `rokit.toml` | **A `.json` file that is not a project or a JSON model syncs as a ModuleScript returning the same table.** So one file is both the thing a tool rewrites and the thing the game requires -- no build step, no second copy, no uploaded asset. MEASURED on 2026-10-01: `rojo sourcemap --include-non-scripts` reports `src/shared/Viewmodel/poses.json` as `ReplicatedStorage.Viewmodel.poses`, className `ModuleScript` | The ModuleScript's Source is **generated**, so this repo's harness could not compare it: a `.json` file failed check 4 as "cannot compare (unsupported file type)". Task 98 had to teach the harness a comparison (require a parentless clone, encode what it returns, compare the structure) before the file could exist at all |
| 3 | DevForum, viewmodel posing from camera-space `CFrame` offsets: [*FPS using Viewmodels, the improved version*](https://devforum.roblox.com/t/fps-using-viewmodels-the-improved-version-parts-2-out-of-3/1129877) (rokoblox5, 2021) and [*Rotating arms, weapon and head relative to first-person camera movement*](https://devforum.roblox.com/t/rotating-arms-weapon-and-head-relative-to-first-person-camera-movement/938884) | Community posts, **no licence** -- the technique only, no code copied | The pattern this repo already uses and task 89 adopted: the viewmodel is **posed each frame from an offset in camera space**, so a "pose" is a `CFrame` and nothing more. That is why the data can be plain numbers | Both pose from literals in code, which is exactly the problem. Neither has a live-tuning story, and the second reaches for `Motor6D` -- see source 1 on why that does not fit anchored parts under a camera |

Searched again for a maintained, openly licensed Roblox viewmodel **framework** to borrow outright:
the 2026-09-27 note (`docs/research/2026-09-27-first-person-viewmodel.md`) surveyed four and found
them unlicensed or ten years stale, and nothing has changed. So the **shape** is borrowed from source
1, the **transport** from source 2, and the **posing** from source 3.

## 3. The pattern adopted, and why

**Named poses as JSON on disk, played by the camera owner, with a Studio-only override layer.**

- `src/shared/Viewmodel/poses.json` -- `carry`, `aim`, `raise`, `fire`, `reload`, each a set of
  numbers. Source 1's shape (named poses, a transform per part, times on the keyframes) written as
  plain numbers rather than as `Pose` Instances, because source 3's technique needs nothing more.
- `ReplicatedStorage.Viewmodel` -- the pure reader: `paths`, `merge`, `validate`, `view`. `view` is
  what keeps ONE source: `Camera.Config` publishes the flat names the camera has always used
  (`CARRY_PITCH_DEG`, `EYE_RELIEF_STUDS`, ...) **by computing them from the data**, so the ~100 call
  sites and both big camera specs are untouched and no number exists in two places.
- `Camera.Poses` -- the one reader of the live override, `RunService:IsStudio()` only, cached on the
  attribute's own text so a production frame does one boolean and no work.
- `tools/pose.py` -- the Director's instrument: `set`, `show`, `save`, `clear`, `compare`.

**Why an override layer rather than editing the file live.** Rojo patches the EDITOR, not a running
Play process (measured in task 34 and written into the `tools/studio_mcp.py` docstring), so writing
`poses.json` during a session changes nothing on screen. The override goes the other way: one JSON
string in the attribute `DHPose` on `ReplicatedStorage.Viewmodel`, written on the session's server
and replicated to every client, read every frame.

**Why one attribute and not one per number.** A Roblox attribute name cannot contain a dot, so
`aim.cheekDeg` could not be one; and clearing a tuning session has to be a single write, or a
half-cleared override is a build nobody can name.

**Why the attribute is on `ReplicatedStorage` and the flag overrides are on `ServerStorage`.** A flag
is resolved once at server boot, so it is set BEFORE the session and never needs to reach a client. A
pose is read every frame by the thing that draws the gun, which is a client. Hence the opposite
Edit/Play rule in the two tools, which is written into both docstrings.

## 4. What was NOT done, and why

**`fire` is the spring's parameters, not a keyframe list.** The brief asked for recoil as keyframes.
The kick is a critically damped spring and `tests/server/camera_mode.spec.luau` rests on its
behaviour -- no overshoot, the same settle at 240, 60 and 20 fps, and a return to EXACTLY the aim
point. Replacing it with keyframes would change all three, and the brief's own rule is that today's
behaviour is preserved. So `fire` carries the amplitudes, the frequency, the damping ratio and the
three ceilings, which is every dial the feel actually has. Recorded here and in `Camera.Config`.

**Hand poses in a mid keyframe are optional, not required.** A `raise` keyframe that names no hand
takes whatever the plain carry-to-aim blend gives at its own time, so adding a keyframe to bend the
GUN's path cannot silently move a hand.

## 5. The numeric targets

| Target | Value | How it is held |
|---|---|---|
| Behaviour unchanged by the move to data | the drawn gun is **bit-for-bit** what it was, at every blend and tilt | `viewmodel_poses.spec`: with no mid keyframes the pose equals `carry:Lerp(aim, ease(blend))` at 11 blends; the hands equal `Mode.rightHandOffset`/`leftHandOffset` at every blend and tilt, because all three poses are seeded with the same hands |
| A live change reaches the screen | the next frame | `Camera.Poses` is read in `Camera.update`, once per frame, cached on the attribute text; `camera_client.spec` measures the drawn gun moving |
| The file can never half-load | a bad `poses.json` **fails the harness** | `Viewmodel.validate` + `viewmodel_poses.spec`, with a mutation case per failure shape |
| A typo can never half-apply | the whole override is refused | `Viewmodel.merge` returns the base data and a problem; `Poses.resolve` applies nothing; `tools/pose.py` refuses before it writes |
| A tuned session can never be reported as evidence | `test` and `test2` REFUSE | `check_no_pose_override`, with a selftest case and a mutation check |
| The drawn break finishes before the server's step | `reload.openSeconds` < `RELOAD_BREAK` (0.22 < 0.5), `closeSeconds` < `RELOAD_CLOSE` (0.16 < 0.6) | `viewmodel_poses.spec`, against `Shotgun.CONFIG` |

## 6. Where the seeded numbers came from

`poses.json` ships with task 97 round 2's values (branch `task-97-sxs-poses`, commit `9393d1e`), the
Director's pick as closest to Karen's target, solved from the 2026-10-01 reference video:

- **carry** -- position `(-0.67, -0.57, -1.22)`, pitch 23.9, yaw 45.7, roll -10. Three readings of
  `TARGET-carry.jpg`: the action at the bottom edge 31 % across, the muzzle leaving the LEFT edge
  40 % down, the barrel pair about 8 % of the screen wide where it meets the bottom. Those are three
  equations; turned into camera-space rays through the carry's own 70-degree vertical field they put
  the breech 1.17 studs from the eye and the muzzle 3.44, and the Handle's centre 0.54 studs behind
  the breech along that line. Then re-solved once against what actually rendered, which was about
  8 % of the screen height high.
- **aim** -- `eyeReliefStuds` 3.65, `cheekDeg` 1.2. 3.65 is what brings the stock's wrist, the top
  tang and the right hand's fingers in front of the camera, which is what `TARGET-aim.jpg` contains;
  4.15 put the glove's cuff through the lens (a MeshPart renders both faces, so the aimed view
  carried the inside of the glove as a pale untextured blob). 1.2 degrees is an eye a finger's width
  above the bore, which is what looking nearly along the rib means.
- **the hands** -- right `(0.12, -0.12, 0.80)` yaw 78 pitch 10 twist -15; left `(-0.02, -0.08, -0.85)`
  yaw -80 pitch -4 twist 180. Seeded into all three poses identically.
- **everything else** -- `raise`, `fire`, `reload` and the shells are `main`'s values, which task 97
  did not touch.

Roblox's field of view is VERTICAL, so the same composition reads at a different angle ACROSS a
16:9 video frame and a 1.24:1 Studio Play window. `tools/pose.py compare` therefore scales both
halves to the same HEIGHT, and the composition -- not the angle -- is what is matched.

## 7. The reference frames are not in the repo

They are third-party video stills. `--assets-dir`, or `DRIVEN_HUNT_ASSETS`, says where they live, and
the default is `<assets-dir>/references/inspiration-2026-10-01/TARGET-<pose>.jpg`. No local absolute
path is written into a committed file (CLAUDE.md, "Public repository"; `tools/privacy_scan.py`
enforces it in CI).
