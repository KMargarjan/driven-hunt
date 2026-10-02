# Task 109 - pose the hands by eye, in Studio

Task: 109
Round: 1
Base: `content-model-b-aim-1` (`4196697`)
Code commit: PENDING -- the gate runs on the paperwork commit and its lines are pasted in here

```
[harness] PENDING
[harness2] PENDING
```

`test2` is required: `tools/studio_mcp.py` is one of the three paths that always ask for it.

## Claims

1. **`pose.py edit <carry|aim|reload>` builds the real rig and hands it to Studio.** Model B's two
   group meshes, both v2 gloves and their sleeves, cloned into ONE anchored Workspace model
   `DHPoseEditor` five studs out and turned 55 degrees so the gun lies across the view; the live
   viewmodel is hidden while it is there (it is drawn AT the camera, which is where the rig now is);
   the left glove is put in Studio's Selection so Ctrl+2 rotates it immediately. `edit cancel`
   destroys it and writes nothing. Verify: `run_edit`, `EDITOR_BUILD`.
2. **It runs inside a Play session, and that is forced, not chosen.** The gloves are uploaded assets;
   only the game's own server may turn an id into an Instance, and `tools/studio_mcp.py`'s docstring
   forbids an asset call through `execute_luau` in capitals (one such call on 2026-10-02 left the
   thread carrying capabilities and every later `require` was refused). An idle editor runs no game
   scripts and so has no gloves to show. Studio's Move and Rotate work on a Workspace model during
   Play Solo exactly as in Edit, and `save` reads the places out before the session ends, so nothing
   has to survive Stop.
3. **`edit save` converts what Karen moved back into the three pose numbers, through the game's own
   frames.** It cannot ask `Camera.Viewmodel.align` -- `require` of `PlayerScripts.Camera` from this
   thread is refused, "`Camera` has additional values for the Capabilities property", the same wall
   from the other side (measured; it is why `EDITOR_READ` requires nothing). So the parent frame is
   CALIBRATED off the live viewmodel, which is at the pose the tool already knows: the left hand is
   posed from `Viewmodel.hinge`'s transform while the only readable thing is the Barrels PART, 0.84
   studs down the gun. The RIGHT hand is posed from the Handle, which IS the part read, so its
   calibration must come back identity -- that is the check, and a save is refused above 0.02.
4. **The round trip is proved twice, on the real thing and with no Studio.** Live (2026-10-02):
   `edit aim` then `edit save` with nothing moved printed "the drawn right glove is where
   newGun.aim.right says, to 0.0000" and left `poses.json` byte-identical (`git diff` empty); then
   the left glove was turned 25 degrees through Studio and `save` wrote yaw 15 -> 38.4088, pitch -15
   -> -21.8718, twist 0 -> -1.8329 with the right hand's six numbers unchanged. In `selftest` (CI):
   every shipped newGun hand composes, gets the alignment applied, comes back through `decompose_hand`
   as itself to 1e-6, and the file that would be written is byte-identical to the one on disk --
   mutation-checked once by flipping the sign in `decompose_hand`'s yaw, which failed three cases.
   The alignment there is built in Python from `HandAssets.AXES` READ OUT OF THE LUAU SOURCE, so the
   selftest fails if the two files stop agreeing.
5. **The harness refuses to run while a rig is in the edit place.** Workspace is not Rojo-owned, so
   one left there is saved with the place and published -- and it is a second gun in front of the
   camera. `check_no_pose_editor` fails the run before the token is written, in both modes, and
   prints `pose.py edit save`; `studio_mcp.py selftest` proves it fails on a rig and passes on none.

## What I could not verify

- **Nobody has dragged a handle in the viewport yet.** The 25-degree turn above was applied through
  Studio's own API, not with the Rotate gizmo, so what is proved is that a moved glove is read and
  converted -- not that the gizmo feels right to use. That is Karen's to try.
- **Float32 noise is snapped, not solved**: an untouched glove came back as z = -0.0001 and twist
  -0.0, so a saved number within 0.001 of the one in the file keeps the file's. A real move smaller
  than that is lost; it is a thousandth of a stud.
- **`edit` holds the pose through the same override `compare` uses**, so a session already tuning
  something keeps its other overrides but not its hold.
