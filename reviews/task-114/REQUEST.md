# Task 114 -- ONE GUN: the new gun is the only gun

Task: 114
Round: 2
Base: `main` (`a77b0ed`, task 113's scoped gate), merged into this branch at `839ce0c`
Code commit: 4cdd1db60a23e4cd01b3008c55c2243567c07cda

```
[harness] PASS: 33/33 checks @ 4cdd1db60a23e4cd01b3008c55c2243567c07cda (clean tree) scope=all
```

**ONE LINE IS THE WHOLE GATE for this change** -- no `[harness2]`. `tools/agents.py` on `main`
(task 113) answers it: `needs_two_player` over `git diff --name-only origin/main...HEAD` returns
**`[]`** -- not one of the 41 changed files is in `TWO_PLAYER_PATHS`. The whole PR is weapon,
viewmodel, camera, hud, sound, assets and tools; it touches no `src/server/Match/`, no
`MatchBoot`, no `src/client/Match/`, no `src/shared/Drive/`, no `tests/client/Role.luau` and none
of the match / tie / outfit specs. `python tools/studio_mcp.py test --scope auto` on this branch
resolves to **`all`** anyway (`src/shared/HandAssets.luau`, `src/server/ViewmodelAssetsBoot.server.luau`,
`src/client/CameraBoot.client.luau` and `tools/studio_mcp.py` are not in `BLAST_RADIUS`, and an
unmapped code path can only mean the whole suite), so the plain `test` the merge gate wants is the
same run either way.

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

5. **SIX SPECS STILL ASSERTED THE RETIRED GUN, AND THE FIRST GATE RUN FOUND THEM**
   (`[harness] FAIL: 29/33 @ c6d730f`). Every one is a spec whose PREMISE was the retired gun or the
   retired pose file: they kept passing only because the flag made `Camera.Config` read the old set
   during a harness run. **No new-gun behaviour is broken and no new-gun assertion is weakened** --
   each claim is re-anchored to this gun's own geometry, which is stricter than what it replaced.
   Verify each by reading the case beside the number:
   - `camera_mode.spec:558` -- `left.Y < 0` meant "under the barrels" because the retired gun was a
     CLONE of the Tool's Handle and its tubes lay on the Handle's axis, so zero WAS the bore. Model
     B's sit at `Gun.layout().barrelY`, 0.12 up. Now measured against `barrelY - barrelRadius`
     (0.081); the left hand is at +0.035 and the right at -0.198, so both really are under the rib.
   - `camera_mode.spec:586` -- it read the pose frame's own +X as "the fingers", true only while
     `align` was identity for the v1 gloves. Model B's pair do not share an axis
     (`HandAssets.AXES`), so each MESH is turned into one convention before the three angles are
     read, and where the drawn fingers end up is a claim about the DRAWN PARTS --
     `gun_client.spec`'s "holds the gun like a hunter" already carries each glove's own measured
     vector through the CFrame really on screen, and passed. What is left here is the rule a server
     can judge: the two hands are posed differently (their +X are 124 degrees apart), and the left
     twist is not the retired pair's 180.
   - the server CFrame mismatch (`viewmodel_poses.spec`) -- "the shipped file seeds every pose's
     hands the same" was a fact about the retired FILE (task 98 seeded them identical so that task
     moved no pixel). Karen posed model B's hands by eye and her reload holds the grip 0.12 studs
     further forward than the carry. The claim underneath it is asserted instead: each pose's own
     state gives back exactly that pose's own numbers (bit-exact -- `lerpHand` returns its endpoint
     at `t >= 1`), and they really are three poses.
   - `camera_client.spec:550` -- the built gun has TWO invisible envelopes, the `Handle` and the
     `Barrels` group that swings; the clone had one. Both are named now rather than counted.
   - `camera_client.spec:610` -- the bead was looked for on the Handle; `Gun.pieces` gives it
     `group = "barrels"`, because a bead is a sight ON the barrels and swings with them.
   - `camera_client.spec:1001`, `gun_client.spec:807` and the bore-line case with them -- a fresh
     shell exists ONLY once the left hand has fetched and carried it (task 111, Karen: *"either we
     have 2 animation when shells go inside or one go straight another from hand"*). The retired
     gun's shells slid themselves in the instant the replica said "loaded". All three drive the load
     on the viewmodel's own clock seam now, and the `camera_client` one also asserts the half the
     old feed could never make: **before the fetch is over there is nothing on screen**. Its
     OFF-branch "no shells" check is re-armed with a fresh rising edge first, so it cannot be
     satisfied by an eject that had simply finished, and `withNewGun` puts the clock back whatever
     happens.
   - `camera_client.spec:1189` -- "the right hand did not move when the gun broke open" was the same
     seeded-identical premise. The owner boundary it stood for is asserted directly now: the right
     hand is where `Mode.handOffsetAt` says, in the BODY's own frame (the left stays
     "its place on the barrels did not change", because its own frame is the one `hinge` RETURNS
     rather than the barrel part's).

6. **The tests are aligned, not thinned.** Every new-gun assertion is kept and now runs against the
   live `Config` rather than a hand-built second config (`gun_client.spec` lost `newGunConfig` and
   `newGunPosedConfig`). What went: the two old-gun comparisons in `gun_client.spec`, the
   muzzle-offset case that asserted the CLONED gun's tubes, `camera_client.spec`'s clone-sweep and
   clone-rebuild cases (both were `build`'s behaviour and nothing else's), and `gun.spec`'s two-pairs
   case. The drawn-bead case became the gun's OWN `Bead` piece, asserted against `Gun.LOOK.bead` and
   `Gun.beadOffset`, plus that no `SightBead` is left anywhere under the gun. Two guards the flag used
   to stand in front of are now measured instead of described: `Viewmodel.flash` refuses a
   third-person config and a config whose `fire` block carries no `flash` (`gun_client.spec`, the
   "fires" case), and `Weapon.Sound` refuses a caller with no resolved config without counting it.

7. **THE ROUND-1 BLOCKING FINDING: the glove bound is the DRAWN glove's.**
   `tests/server/gun.spec.luau` / "seeds the left hand ON THE FOREND and the right ON THE GRIP" took
   its tolerance off `Assets.byKey("hand.left")` -- the RETIRED v1 row -- while its own comment said
   "the hand's OWN half-width". **The Reviewer is right and the numbers are exact**: 0.2412 for the
   retired model against 0.2671 for the drawn one. It was the tighter of the two, so nothing had been
   loosened; it was simply the wrong gun's hand, which is the one thing this task set out to remove.
   It reads `Assets.byKey(HandAssets.KEY_OF[HandAssets.LEFT])` now -- the one definition of which
   pair is drawn -- and asserts that row's `scope` is `"viewmodel"`, so the measurement cannot drift
   back onto a retired row without failing. The shipped offsets are -0.080, -0.025 and -0.080, well
   inside either number. Verify: read the case; `grep -n '"hand.left"' tests/` finds only a comment.

   **THE SAME CLASS, EVERYWHERE ELSE: exactly one case, and it was that one.** I grepped every spec
   for `hand.left` / `hand.right`, `Assets.KEYS.handLeft` / `handRight`, `HAND_*_V1` and
   `scope = "retired"`. The six other hits are claims whose SUBJECT is the retired row, which rule 7
   wants checked rather than removed -- `assets_seam.spec` ("FIVE SINCE TASK 114", the three retired
   scopes, and the 1.2-1.4 size band for the retired pair) and `gun.spec` ("publishes ONE pair of
   gloves, under the keys the old pair cannot supersede", "retires the pieces this gun replaced").
   Two further hits are comments quoting the history, and no `HAND_*_V1` constant is referenced
   outside the manifest. Verify with the same four greps.

8. **The round-1 notes are fixed in the same lines** -- `HandAssets.KEY_OF`'s archive sentence (the
   v1 rows stay in the manifest at `scope = "retired"`, which is what `backups/README.md` already
   said); the two places that said Karen's left twist is 0 when the file ships -150, 110 and -150;
   `Camera.Mode`'s reference to the removed `stats().sightMissing`; `GAME_DESIGN.md` **row 44**, the
   Viewmodel owner row, which still said "It clones the Tool's `Handle`" and named `SightBead`;
   `ESCALATE.md`'s playtest recipe, which keeps its words as the record and carries a dated line
   saying the flag is retired; `Camera.Viewmodel`'s two leftover old-gun sentences plus `hinge`'s
   duplicated "FIRST PERSON ONLY" block, and the two "flag-OFF" mentions that meant FIRST_PERSON.
   **And one that was not a comment:** the `setViewmodelFlash(nil)` ... restore pair I added to
   `weapon_client.spec` in round 1 was not inside a `pcall`, so a failing assertion between them
   would have left the live first-person flash provider nil for the rest of the session -- the body
   is wrapped now and both seams are restored before the rethrow, which also closes the same
   pre-existing hole around `setMuzzleProvider`. Only `docs/design/camera.md` is left, and it is the
   Architect's lane (TASKS 114a(b)).

9. **`tools/pose.py` follows the data, and a stale path is refused rather than ignored.** `edit save`,
   `fit` and the shipped landmark file (`tools/landmarks/reload.json`, `git mv`) all lost the
   `newGun.` prefix. Verify: `python tools/pose.py selftest` -> PASS. It asserts
   `newGun.carry.gun.pos.x` is no longer a path AND that an override naming one is REFUSED, so a
   Director typing the old path out of habit is told rather than left looking at an unchanged gun.

## The gate, and what I could not verify

- **I did not run the harness; the Director did, at this round's head.** The line at the top is the
  Director's own output, verbatim: 33/33 on a clean tree, Rojo restarted and Connected. `test2` is
  **N/A** -- `needs_two_player` returns `[]`. Round 1's own run was the same line at `9a1806f`, and
  round 2 touches `src/` and `tests/`, which is why it needed its own.
  `test2` is **N/A** -- `needs_two_player` returns `[]` (weapon and camera only; Karen, 2026-10-03:
  no two-player run for the weapon and the animal). **The FIRST gate run FAILED (29/33 @ `c6d730f`)
  and claim 5 is what came out of it** -- still `Round: 1`, because no review has run.
- **I could not re-run the suite myself**, so the six fixes are reasoned from the log and from the
  data rather than observed green. Each one was checked against the shipped numbers by hand: the
  bore underside is 0.081 and the two hands are at +0.035 and -0.198; the two hand frames' +X differ
  by a dot of -0.55; `lerpHand` returns its endpoint exactly at `t >= 1`, so the per-pose equalities
  are bit-exact; and the load is 0.45 s of fetch-carry-seat against a 0.35 s eject, which is why the
  OFF-branch shell check had to be re-armed rather than left where it was.
- **`main` is merged in (task 113's scoped gate), and that settled the two-player question**: see the
  box at the top -- `needs_two_player` returns `[]`, so the one-player line is the whole gate, for the
  review round AND for the PR to `main`. The merge's one conflict was `TASKS.md` and both sides are
  kept (rows 114/114a from here, 113/113a from main, nothing reordered); row 113's own status is left
  exactly as main wrote it, because the queue is the Director's. `tools/studio_mcp.py` auto-merged
  with both sides' intent in it -- 113's `BLAST_RADIUS` / `SCOPE_SPECS`, and 114's one-line landmark
  change -- and `tools/agents.py` and `CLAUDE.md` are main's 113 versions untouched, because task 114
  changed neither file and so had nothing to re-apply.
- **No screenshot.** Nothing about the drawn gun's appearance is meant to change: what this removes is
  the branch that was never switched on. The one visible claim worth a picture is "the gun still looks
  the way Karen OK'd on 2026-10-02", and that is a playtest rather than a capture I can judge.
- **Three tunable numbers nothing reads**: `reload.hingeStuds` (published as `BREAK_HINGE_STUDS`),
  `reload.shells.feedSeconds` and `reload.shells.feedFromStuds`. All three were already unread
  whenever the flag was ON -- that is, in every build Karen has played -- so this task made it
  permanent rather than causing it. Kept because the dispatch fenced the numbers ("keep every
  `newGun.*` number byte-identical"); queued as TASKS.md 114a(a) with both ways out.
- **`docs/design/camera.md` still describes the cloned gun** (`sightMissing` as a live counter, the
  `build` sweep, `VIEWMODEL_AIM_OFFSET` as an "OFF + ON fallback"). **Round 1's request said
  `sightMissing` was "still in `stats()` and now 0 by construction" -- that was wrong**, and the
  Reviewer caught it: the field was REMOVED with the builder that could raise it (claim 2 says so),
  and nothing in `tests/` read it. The Builder may not write designs, so the doc is queued as
  114a(b) for an Architect pass.
