# Task 196 — a better shop menu, the room around it, the keeper, and the trees

Task: 196
Round: 1
Base: `98f9c6b`
Code commit: ade47116f5f189bd160ceafe264c1c262beac298

```
[harness] PASS: 33/33 checks @ ade47116f5f189bd160ceafe264c1c262beac298 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ ade47116f5f189bd160ceafe264c1c262beac298 (clean tree)
```

Six rounds of Karen's own looks, in one branch. She asked for a better buy menu, then for the room
round it, then for the Designer to decide the look, then for a bug and a photo survey, then for the
Designer's lodge polish — and twice, on her own frames, for the trees. The look specs
(`shop-design-spec.md`, `lodge-polish-spec.md`, the mockups and the survey PNGs) live **outside this
repo** and are cited as *the Designer's spec, 2026-10-16* and *the Designer's lodge spec,
2026-10-16*; nothing of them is copied in. The after-frames are outside the repo too.

## Claims

1. **The shop is master-detail and draws only what arrived.** `Shop.ROWS` carries `category` and
   `blurb`, both on the `WireRow`; `Shop.groups` and `Shop.menuOrder` are the pure functions the menu
   is built from, and `Shop.rowsOk` refuses a row with no shelf, no explanation, or one over
   `BLURB_MAX`. Verify: `shop.spec` asserts `rowsOk` on each of those three, and `shop_panel.spec`
   drives the panel from a payload without the catalogue.

2. **One pure function owns the whole rectangle, at both sizes.** `ShopPanel.layoutFor` answers
   `mode` plus every rect, and nothing else computes a position. Verify: `shop_panel.spec` asserts it
   at 400×800, 800×600 and 1920×1080, including that the picture is capped on HEIGHT as well as
   width; `ShopPanel.panelSize` and `relayout` are its only consumers.

3. **The Designer's panel, with four engine deviations written down.** Oswald/BuilderSans through
   `Font.new`, row tags, the seven-state button, the display case, the two layouts. The four things
   Roblox would not do (no letter spacing → `ShopPanel.spaced`; no per-corner radius; the spec's
   label print was inside the label and invisible; `Fabric` read as grey stone at 1.8 studs) are in
   the research note's addendum, `docs/research/2026-10-15-shop-window.md`. Verify: that addendum,
   and `ShopPanel.LOOK` / `Shop.CONFIG.PANEL` against the note.

4. **The room is what Karen last asked for: one trophy, no table.** Karen, 2026-10-16: *"remove
   table and all boar heads only keep one where is on fireplace"*. Verify: `lobby.spec` "hangs ONE
   trophy, on the fireplace wall, with its point and nothing behind it" (asserts `#MOUNTS == 1`, the
   row's wall is `west`, no `Mount2`, no `TrophyBacking`, no `SconceFlame1`, and `BACKING`/`LIGHT`
   gone from config) and "has no table and no bench left inside the room" (fails by NAME, listing
   whatever is still standing; `PorchBench` is excluded and said to be). Archived per rule 7:
   `backups/2026-10-16_task-196_table-and-north-trophies.txt`.

5. **The shield's point is in the wall plane, and no animal shows a foot or a rump.** It was a
   `WedgePart` laid flat and read as a shelf under every plaque. Verify: the same `lobby.spec` case
   asserts the point is **not** a `WedgePart` and that its `Size.Z` is the board thickness (the wall
   normal). Measured live before the north wall was emptied: feet 0.05–0.13 studs below each board
   and rumps 1.52 proud of the wall's outside face; after, −0.12 and inside, 0 mounts showing
   anything.

6. **The keeper is dressed by the players' own system.** `Match.Body.OUTFITS.Keeper` is a `Look` no
   roster can hand out; `Lobby` hands over a Model and a team and never learns what an outfit is.
   Three one-line bugs that made his band and brush invisible are fixed at their owner: the hat-slot
   tint painted every row, the plate builder hard-coded `SmoothPlastic`, and `clears` was honoured
   only on the accessory path. Verify: `lobby.spec`'s keeper-look case and `Body.OUTFITS`/`Body.SLOTS`
   (`beard` is a slot, deliberately not `hat`, so `tintFor` answers nil for it).

7. **No tree stands on its claws, and the junction is measured, not assumed.** The contact is the
   trunk/flare junction, measured once per model off the mesh and stored as data
   (`TREELINE.SPECIES[n].CLAW_FRACTION`: birch 0.075, the oak/alder 0.03 — each template rayed
   horizontally at sixty heights from its own trunk axis). Verify: `lobby.spec` "buries each tree's
   root claws: the trunk/flare junction is AT or UNDER the ground" — it asserts every species
   carries the number, measures the junction against the lowest ground under each **base** footprint,
   and refuses a result that is exactly zero (standing rule E).

8. **It goes through the trucks' settler, not a second placement path.** `settleOnGround` takes a
   `SettlePlan`: a truck lifts until no wheel is buried, a tree sinks until no contact is in the air
   (`toLowest`), with no tilt and with a missing ground sample skipped rather than fatal. Verify:
   `Build.footprintSamples` and `Build.worldBoxOf` are pure and asserted in `lobby.spec` ("samples
   the whole footprint and its corners, not just the middle"; the keep-out case uses `worldBoxOf`
   because `Model:GetBoundingBox` is ORIENTED and treating it as axis-aligned left seven tree parts
   in the house).

9. **A tree is seated on the surface a player walks on.** The road, verges and yard are Parts half a
   stud proud of the terrain, so a terrain-only reader would plant a tree under one. Verify:
   `Build.surfaceOver` is pure and asserted in `lobby.spec` ("plants a tree on the road slab's top,
   not on the terrain hidden under it"), including that a point outside the slab answers nil and that
   the higher of two overlapping slabs wins. Measured live: **0 of 38 tree footprints overlap a road
   or yard part today** — this is a guard for the next wider yard, not a fix for a live defect, and
   is stated as such in its own header.

10. **The mouse comes back when the shop closes.** `Camera.Cursor` is the one writer of
    `UserInputService.MouseBehavior`; the camera's own handler dropped every `gameProcessedEvent`
    delta, so with the pointer locked the camera stopped turning. `Camera.wantsDelta(processed,
    behavior)` is the rule. Verify: `camera_client.spec` asserts it directly, and `shop_panel.spec`
    asserts the panel hands the cursor back on close.

## What could not be verified

* **Karen's exact repro of the mouse bug was never driven.** She reported it after closing the shop
  with `E`. A `ProximityPrompt` cannot be fired by a script (`InputHoldBegin` is a no-op and a
  replayed `E` is ignored — measured in this session), so the path from *her* close to the camera was
  never executed end to end. What is proved is the rule (`Camera.wantsDelta`, by spec) and the
  hand-back (`shop_panel.spec`). **No claim here rests on real OS-level mouse movement.** For the
  same reason the phone frame `P-phone-shop-strip.png` shows the HUD rail still drawn: the panel was
  made visible directly rather than opened, so `ShopPanel.hidesRail` correctly answers false. The
  rail hide is proved by `shop_panel.spec` only.
* **The tree spec case could not be run at the base.** At `98f9c6b` there is no tree planter, no
  `CLAW_FRACTION`, no `fakeTemplates` tree of either species and no such case, so there is nothing
  for it to fail against. It was run against the **pre-fix commit of the defect itself**, `9885586`
  (part 3d), with `src/` checked out there and the case reading the measured literal 0.075 in place
  of the config field that did not yet exist. That run, verbatim:

  ```
  TestService: Tree28 shows 2.19 studs of claw above the ground under it
  ServerStorage.Tests.lobby.spec:1900
  [tests:server] FAIL: 1541 passed, 2 failed, 0 skipped, 2 errors, 56 spec files
  [harness] FAIL: 31/33 checks @ 6c8f8df351e2b0192651b0e48548dec45e286847 (DIRTY TREE (3 paths) - NOT valid evidence) scope=all
  ```

  The three count specs changed with the room were shown failing on their old numbers the same way:
  `lights` expected 8 got 6, `mounts` expected 5 got 1, and the walk-path's `seen["Table"]` expected
  true got nil.
* **The junction depth reads −0.60 on every one of the 38 trees**, and is reported as SUSPECT rather
  than as a pass: it is uniform *by construction* (the settler puts the junction exactly
  `SINK_STUDS` under the lowest ground, every time). The number that varies, and the one worth
  checking, is the claw-tip depth: **−2.33 to −7.50**.
* **`Workspace.OurForest` is untouched and is not ours.** Nothing under `src/` creates, moves or
  parents anything into it; 2 458 of its 4 819 trees stand more than 0.2 studs above the terrain,
  worst 41.4. It needs a task of its own.
* **Nothing in this branch has been judged by Karen since part 3c.** Every change after that — the
  lodge polish, the removals, the keeper, the trees, the phone — is waiting on her morning look.
