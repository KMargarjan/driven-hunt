# Task 264 -- prove task 261 on Karen's path with the new tools

Task: 264
Round: 1
Base: 01d9e21d (main, which includes 261 and 263)
Code commit: fb46e7dd4d23bc7401eebeca0f10ba7a71e45d42

`[harness] PASS: 34/34 checks @ fb46e7dd4d23bc7401eebeca0f10ba7a71e45d42 (clean tree) scope=all`
`[harness2]` N/A: the one changed file is `tests/client/camera_client.spec.luau`, which is not in
`TWO_PLAYER_PATHS` (the camera is on the exempt list; Director decision 2026-10-03).

## What changed in the repository

**One file, and it is item 5.** `tests/client/camera_client.spec.luau`. Items 1-4 are PROOF items:
they changed no code, because the measurement did not ask for a change -- see the ledger below.

## PLAN (core quality protocol step 0), for item 1

- **(a) REAL LIFE.** A deer shot dead does not slide. `docs/research/2026-09-25-hit-zones.md`
  source C (Stokke et al. 2018, *Sci. Rep.* 8) gives flight distance BEFORE collapse; after it the
  body stops within its own length.
- **(b) MEASURED NOW.** Before this task the number did not exist: task 261's ledger item 3 reads
  `13 shots, 0 kills`. This task measured one, with `264-watch-start.luau`, in the Forest Test:
  `SLIDE 0.83 studs = 0.14 bodyLen | HANG 0.357 studs | anchored=true`.
- **(c) TARGET.** 0 slides over 1 body length (6.03 studs for a hind), 0 hangs over 0.5 studs --
  the dispatch's numbers, and 0.5 is `CARCASS_GROUND_TOLERANCE_STUDS`, the tolerance the code
  itself already treats as "on the ground".
- **(d) LEVER.** `Body.stepCarcass` in `src/server/Boar/Body.luau` -- the one writer, through
  `Body.groundDrop` and `part.CFrame = part.CFrame + Vector3.new(0, drop, 0)`, and
  `part.Anchored = true` for the slide. **No change was made to it**: the one carcass measured was
  inside both targets, so the measurement refutes nothing and asks for nothing.
- **(e) HOW IT IS MEASURED AFTER.** The same probe, `264-watch-start.luau`.

## STEP 1 -- her path

The Forest Test (placeId 130094961655666), the player enrolled at a truck pad (rule I), a hunter on
his own stand, the gun in his hands, deer released by the drive's own schedule. Nothing was measured
in DEV.

## Claims

1. **Item 5 is done and is the only code change.** `camera_client.spec`'s *"moves the REAL camera,
   holds it there, and gives it back"* now wraps its assertions in `pcall`, restores
   `DHTestLookOff`/`DHTestLook` on both paths outside it, and re-raises with `error(why, 0)`.
   *Verify:* read the case; compare with the `DHPose` case above it, which is the pattern 263a(a)
   named. The hazard it closes: `DHTestLook` is level-triggered, so a throw before the release left
   the live camera held 85 degrees off for the rest of the session (task 252's cascade).
2. **The harness is green at the code commit, on a clean tree, full scope.** *Verify:* the line
   above; `.agent-evidence/`.
3. **Item 1 (CORE) is NOT PROVEN, and the report says so in those words.** One kill was measured,
   not eight; it was off the road and at 1.0 studs/s, so it is not a running kill either.
   *Verify:* `<runs-dir>/ledgers/264.md` item 1, and the `## Handover` block in the report.
4. **The one kill that was measured met both targets.** `SLIDE 0.83 studs = 0.14 bodyLen` against
   a target of 1.00, `HANG 0.357 studs` against 0.500, `anchored=true`. *Verify:* the ledger's
   verbatim line, which is `264-watch-start.luau`'s own output string.
5. **The measurement instrument is independent of the shooter.** `264-watch-start.luau` watches
   `Workspace.Boars` for the `Carcass` attribute and samples the body itself; it never fires, and
   it is not told which animal was shot. The slide is the flat distance from the death point at
   t = 4 s, the hang is the lowest DRAWN point (mesh box bottom and every `Bone`) above the ground
   read under the body's own x,z at t = 3 s. *Verify:* read the file; delete the shooter and the
   watcher still records any death the drive produces.
6. **Items 2 and 3 were not attempted and are NOT PROVEN for that reason**, not for a missing
   tool. *Verify:* the ledger.
7. **Item 4 now has a measured reason rather than an absent one.** The console line at the end of
   drive 3: `[match] gathered 0 animal(s) in 0 row(s) at the world's own spot (2788, 150, -2940):
   0 real model(s), 0 box(es)`. There were no kills to gather, so there was no frame to take.
   *Verify:* the console transcript quoted in the ledger.
8. **Three instrument defects were measured, and they are why item 1 stopped.** (i) a click with no
   `SetForegroundWindow` fires nothing -- twelve real clicks, `ShotLanded` unchanged, and the
   focusing click fired on the first try; (ii) `aimshot.py`'s `CLICK_XY = (960, 620)` is on the HUD
   button column of a window whose rect is `-7,0..1287,1047`; (iii) `ActionRequest("Reload",
   <ammo>, ...)` is `bad-request` by `Validator.checkRequest`, which is what `261-deerkill.luau`
   sends. *Verify:* `src/server/Weapon/Validator.luau`'s `checkRequest` for (iii); the ledger for
   the measurements.
9. **The Forest Test's attributes are identical before and after.** Read before any change and
   again after the restore, both through `<runs-dir>/attrs-id.luau`:
   `DHFlag_BOAR_BEHAVIOUR=true DHFlag_BOAR_MODEL=true DHFlag_COINS=true DHFlag_DEER_ROAD_LEAP=true
   DHFlag_DRIVE_BOTS=true DHFlag_HORN=true DHFlag_LICENCE_POPUP=true DHFlag_LOBBY=true
   DHFlag_SHOP=true DHForestStartRole=hunter DHShopTestGrant=true`. `DHTestOwns` and
   `DHForestDriveSeconds` were set for the proof only and are cleared. *Verify:* the two strings in
   the ledger and in the report are the same string.
10. **Nothing in `src/` changed, so nothing in the game changed.** *Verify:*
    `git diff --name-only 01d9e21d..fb46e7dd`.

## What could not be verified

- **Item 1's eight kills.** Three instrument faults were found and fixed in sequence inside the
  2.5 h and a fourth is still open: with the reload corrected, `FireRequest` from a client probe
  still produced 3 `ShotLanded` in about ninety requests, while the same gun fired by
  `245-gunstate.luau` and by one real focused click both landed. What refuses the rest is unknown.
- **Items 2, 3 and 4.** Not attempted.
- **No screenshot of a carcass.** The drives clear their animals at the end, and the one kill was
  recorded in drive 2; by the time the measurement was read the body was gone. Rule 5 is N/A for
  this round because no visual claim is made.
