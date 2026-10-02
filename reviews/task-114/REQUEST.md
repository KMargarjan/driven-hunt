# Task 114 -- ONE GUN: the new gun is the only gun

Task: 114
Round: 1
Base: `task-112-shooting` (`26c8789`), with `origin/content-hands-karen-1` merged in (`f9d33cc`)
Code commit: 8abacd9cb3467521613cb39dcdbd3fc40cd1a066

```
[harness] PASS: n/n checks @ 8abacd9 (clean tree)   <- the Director runs it; I never run the harness
[harness2] PASS: n/n checks @ 8abacd9 (clean tree)  <- needed on THIS branch: see "the gate", below
```

## What changed

Karen, 2026-10-03 ~00:55, verbatim: *"why we using old weapon several verssion, positions gloves
et?"*, *"I can see still in test old wepons when they tesitng why we dont remove them and not align
with new one"*, and the standing order *"always fallow clenup"*. She had already accepted the new gun,
so the `NEW_GUN` flag had won and this is CLAUDE.md's "Feature flags" retirement, carried out.

Nothing about the WORLD gun moved: `Weapon.Hardware` is untouched, and so are the server shot path,
Match, the driver, the tie and the teams.

## Claims, and how to verify each

1. **The flag is gone, name and all.** `grep -r NEW_GUN src tests tools` comes back EMPTY. The row is
   out of `src/shared/Flags/init.luau`, the boundary read is out of `Camera.Config`, and no module
   takes a `config.NEW_GUN` any more. `tests/server/flags.spec.luau` iterates the table, so it still
   proves every surviving row's `expires`.

2. **The old first-person gun's drawing code is gone, and nothing reaches for it.** In
   `src/client/Camera/Viewmodel.luau`: `build` (the cloned Tool Handle), the two `ChildAdded` /
   `ChildRemoved` watchers on that Handle, `addBeadMarker`, `MARKER_NAME`, `BEAD_NAME`, the
   `DHNewGun` attribute, `sleeveLength`, `sleeveSegments`, `sleeveOverlap`, `armDirection`,
   `handLengthAlongFingers`, `placeSleeve`, `armFrame`, `SLEEVE_NAME`, `SLEEVE_BACK_ATTRIBUTE` and
   `stats.sightMissing`. In `Camera.Config`: the four `SLEEVE_*` rows, the taper, the two
   to-the-shoulder vectors and the three `BEAD_MARKER_*` rows. `Viewmodel.poseHands` dropped its
   camera-frame parameter (only the arm frames ever needed one), and `Viewmodel.align` and the glove
   lookup dropped their `config`. Verify: `selene src` is clean -- it is what caught the three
   newly-unused parameters -- and `grep -rn "SLEEVE_\|BEAD_MARKER\|addBeadMarker\|armDirection" src
   tests` is empty.

3. **One pair of gloves, and the retired pair is retired rather than deleted.**
   `HandAssets.FOLDER_NAME` is the one folder and `HandAssets.KEY_OF` the one key table, pointing at
   `gun.hand.right` / `gun.hand.left`; `NEW_GUN_FOLDER_NAME` and `NEW_GUN_KEY_OF` are gone and
   `ViewmodelAssetsBoot` publishes one pair. The v1 rows in `src/serverstorage/Assets/init.luau` are
   `scope = "retired"` -- the shape `gun.stock` set in task 105, so the row and its id stay (rule 7).
   Verify: `tests/server/gun.spec.luau`, "publishes ONE pair of gloves, under the keys the old pair
   cannot supersede", asserts both scopes, that neither row supersedes the other, both sizes, and that
   `Assets.keysFor("viewmodel")` contains neither retired key; `assets_seam.spec.luau` counts 5 keys
   where it counted 7. **The keys stay SEPARATE on purpose**: `supersededBy` takes a VERSION of the
   same key and these are a different model, which is task 106 round 1's finding.

4. **One pose set, at version 3, with every one of Karen's numbers byte-identical.**
   `poses.json`'s `newGun.{carry,aim,reload,fire}` moved to the top level and the old gun's four
   blocks came out. Verify the numbers by re-encoding the subtree -- `git show
   26c8789:src/shared/Viewmodel/poses.json`, then compare `old["newGun"][k]` with `new[k]` for
   `carry`, `aim`, `reload` and `fire` under `json.dumps(..., sort_keys=True)`: all four are equal.
   `Viewmodel.view` no longer takes a gun to choose, so `Camera.Config` and `Camera.Poses` cannot
   resolve different guns. The VERSION is bumped because the SHAPE changed: a version-2 file read by
   this code would be read, silently, as the RETIRED gun's poses.
   `tests/server/viewmodel_poses.spec.luau` drives it -- "refuses a file at the version that carried
   two guns", "reads one pose set, and poses.json carries no second one" -- and `reload.load`, which
   only one of the two guns ever had, so its shape could not be asserted at all, now has four
   refusal cases of its own.

5. **The tests are aligned, not thinned.** Every new-gun assertion is kept and now runs against the
   live `Config` rather than a hand-built second config (`gun_client.spec` lost `newGunConfig` and
   `newGunPosedConfig`). What went: the two old-gun comparisons in `gun_client.spec`, the
   muzzle-offset case that asserted the CLONED gun's tubes, `camera_client.spec`'s clone-sweep and
   clone-rebuild cases (both were `build`'s behaviour and nothing else's), and `gun.spec`'s two-pairs
   case. The drawn-bead case became the gun's OWN `Bead` piece, asserted against `Gun.LOOK.bead` and
   `Gun.beadOffset`, plus that no `SightBead` is left anywhere under the gun. Two guards the flag used
   to stand in front of are now measured instead of described: `Viewmodel.flash` refuses a
   third-person config and a config whose `fire` block carries no `flash` (`gun_client.spec`, the
   "fires" case), and `Weapon.Sound` refuses a caller with no resolved config without counting it.

6. **`tools/pose.py` follows the data, and a stale path is refused rather than ignored.** `edit save`,
   `fit` and the shipped landmark file (`tools/landmarks/reload.json`, `git mv`) all lost the
   `newGun.` prefix. Verify: `python tools/pose.py selftest` -> PASS. It asserts
   `newGun.carry.gun.pos.x` is no longer a path AND that an override naming one is REFUSED, so a
   Director typing the old path out of habit is told rather than left looking at an unchanged gun.

## The gate, and what I could not verify

- **I did not run the harness.** `python tools/studio_mcp.py test` is the Director's; the two lines at
  the top are placeholders for the Director's own output.
- **On THIS branch the review needs the `[harness2]` line as well.** `tools/agents.py` here is the
  pre-task-113 version: `TWO_PLAYER_PATHS` is `("src/", "tests/client/", "tools/studio_mcp.py")` and
  the only exemption is `WEAPON_VIEWMODEL_PATHS`. This change touches `src/shared/Flags/`,
  `src/client/Camera/Config.luau`, `src/client/Weapon/Sound.luau`,
  `src/server/ViewmodelAssetsBoot.server.luau`, `src/serverstorage/Assets/`,
  `tests/client/camera_client.spec.luau`, `tests/client/weapon_client.spec.luau` and
  `tools/studio_mcp.py` -- all outside that list -- so `needs_two_player` is non-empty and the review
  is refused without it. Task 113's list would exempt the whole change, so merging 113 first makes the
  one-player line sufficient. **Director's call.**
- **No screenshot.** Nothing about the drawn gun's appearance is meant to change: what this removes is
  the branch that was never switched on. The one visible claim worth a picture is "the gun still looks
  the way Karen OK'd on 2026-10-02", and that is a playtest rather than a capture I can judge.
- **Three tunable numbers nothing reads**: `reload.hingeStuds` (published as `BREAK_HINGE_STUDS`),
  `reload.shells.feedSeconds` and `reload.shells.feedFromStuds`. All three were already unread
  whenever the flag was ON -- that is, in every build Karen has played -- so this task made it
  permanent rather than causing it. Kept because the dispatch fenced the numbers ("keep every
  `newGun.*` number byte-identical"); queued as TASKS.md 114a(a) with both ways out.
- **`docs/design/camera.md` still describes the cloned gun** (`sightMissing` as a live counter, the
  `build` sweep, `VIEWMODEL_AIM_OFFSET` as an "OFF + ON fallback"). `sightMissing` is still in
  `stats()` and is now 0 by construction, because `buildNewGun` always adds the `Sight` attachment.
  The Builder may not write designs: queued as 114a(b) for an Architect pass.
