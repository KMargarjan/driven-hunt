# Task 196 — a better shop menu, the room around it, the keeper, and the trees

Task: 196
Round: 2
Base: `98f9c6b`
Code commit: 471c394a1c72638614771f516b90e1eb0c493eb7

```
[harness] PASS: 33/33 checks @ 471c394a1c72638614771f516b90e1eb0c493eb7 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ 471c394a1c72638614771f516b90e1eb0c493eb7 (clean tree)
```

Six of Karen's own looks in one branch. She asked for a better buy menu, then for the room round it,
then for the Designer to decide the look, then for a bug and a photo survey, then for the Designer's
lodge polish — and twice, on her own frames, for the trees. The look specs (`shop-design-spec.md`,
`lodge-polish-spec.md`, the mockups, the survey and after PNGs) live **outside this repo** and are
cited as *the Designer's spec, 2026-10-16* and *the Designer's lodge spec, 2026-10-16*; none of them
is copied in.

## Claims

1. **Finding 1 is fixed at the owner: the rail has TWO reasons to be down, and one writer.** Part
   3f wrote `railFrame.Visible` from `Hud.renderObjective` every frame, which beat
   `Rail.setSuppressed` — the first frame after a sight picture went up put four buttons back inside
   the eyepiece — and beat `Rail.visible(touchEnabled)` with it. Verify: `Rail.setCovered` is
   edge-triggered like `Rail.setSuppressed` beside it; `Rail.applyVisibility` makes the single
   assignment `Rail.visible(touchEnabled) and not suppressed and not covered`; and the Hud now only
   states the need. Grepped: the sole writers of that frame's `Visible` under `src/` are
   `Rail.applyVisibility` and the `false` `Hud.build` sets before `Rail.start`.

2. **The two reasons are independent, and that is asserted off the real frame.**
   `hud_clarity.spec`, "stays down while EITHER the sight picture or a panel holds it, per-frame pass
   included", drives `Hud.renderObjective` with the rail suppressed and **no shop open** — the exact
   state the defect needed — then walks suppressed-only, covered-only, both, clearing one, and both
   clear. It measures the free state against `Rail.visible(UserInputService.TouchEnabled)` rather
   than a hard-coded `true`, so it cannot pass by being loosely bounded. **It fails at `ade4711`**
   (that `src/`, this spec, `setCovered` stood in as a no-op so the case reaches the defect instead
   of dying on a nil call):

   ```
     FAIL [client] status PASS  (FAIL )
     FAIL [client] > 0 passed, 0 failed, 0 errors, 0 skipped  (352 passed, 1 failed, 1 errors, 0 skipped)
   [harness] FAIL: 31/33 checks @ bf7b7f2e2f2b71060c9c37d1bafac522724f8953 (DIRTY TREE (3 paths) - NOT valid evidence) scope=all
   ```

   The client suite is 351 passed / 0 failed at `ade4711` as it stands.

3. **The shop is master-detail, and its layout is one pure function.** `Shop.ROWS` carries
   `category` and `blurb`, both on the `WireRow`; `Shop.groups` and `Shop.menuOrder` are the pure
   functions the menu is built from; `Shop.rowsOk` refuses a row with no shelf, no explanation or one
   over `BLURB_MAX`. `ShopPanel.layoutFor` answers `mode` plus every rect and nothing else computes a
   position. Verify: `shop.spec` asserts `rowsOk` on each of those three; `shop_panel.spec` asserts
   `layoutFor` at 400×800, 800×600 and 1920×1080, including the picture capped on HEIGHT as well as
   width. **The panel's RENDER is payload-driven; its row SET is not** — `buildWell`/`buildStrip`
   create row and shelf instances from the client's own catalogue copy, so a payload row the client
   does not know is drawn nowhere (round-1 note, claim 1).

4. **The Designer's panel, with four engine deviations written down.** Oswald/BuilderSans through
   `Font.new`, row tags, the seven-state button, the display case, two layouts. The four things
   Roblox would not do — no letter spacing (`ShopPanel.spaced`), no per-corner radius, the spec's
   label print was inside the label and invisible, `Fabric` read as grey stone at 1.8 studs — are in
   the addendum to `docs/research/2026-10-15-shop-window.md`. Verify: that addendum against
   `ShopPanel.LOOK` and `Shop.CONFIG.PANEL`.

5. **The room is what Karen last asked for: one trophy, no table.** Karen, 2026-10-16: *"remove
   table and all boar heads only keep one where is on fireplace"*. Verify: `lobby.spec` "hangs ONE
   trophy, on the fireplace wall, with its point and nothing behind it" (asserts `#MOUNTS == 1`, its
   wall is `west`, no `Mount2`, no `TrophyBacking`, no `SconceFlame1`, `BACKING`/`LIGHT` gone from
   config, and the stag's place is a measurement with no parts) and "has no table and no bench left
   inside the room" (fails by NAME, listing what still stands; `PorchBench` is excluded and said to
   be). Archived per rule 7: `backups/2026-10-16_task-196_table-and-north-trophies.txt`.

6. **The shield's point is in the wall plane, not a shelf under the plaque.** It was a `WedgePart`
   whose rotations laid it flat, so 3.2 studs of width ran into the room. Verify: the same
   `lobby.spec` case asserts the point is **not** a `WedgePart` and that its `Size.Z` is the board
   thickness — the wall normal. Measured live before the north wall was emptied: feet 0.05–0.13
   below each board and rumps 1.52 proud of the wall's outside face; after, −0.12 and inside, with
   0 mounts showing anything.

7. **The keeper is dressed by the players' own system.** `Lobby` hands over a Model and a team and
   never learns what an outfit is. Three one-line bugs that made his band and brush invisible are
   fixed at their owner: the hat-slot tint painted every row, the plate builder hard-coded
   `SmoothPlastic`, and `clears` was honoured only on the accessory path. Verify: `lobby.spec`'s
   keeper-look case through **`Body.outfitFor`**, which is the public door — `OUTFITS` is a file-local
   in `src/server/Match/Body.luau` (round-1 note, claim 6) — and `Body.SLOTS`, where `beard` is a slot
   deliberately not named `hat`, so `tintFor` answers nil for it.

8. **No tree stands on its claws, and the junction is measured off the mesh, not assumed.** The
   contact is the trunk/flare junction, measured once per model and stored as data
   (`TREELINE.SPECIES[n].CLAW_FRACTION`: birch 0.075, the oak/alder 0.03 — each template rayed
   horizontally at sixty heights from its own trunk axis, not its bounding-box centre). Verify:
   `lobby.spec` "buries each tree's root claws: the trunk/flare junction is AT or UNDER the ground"
   asserts every species carries the number and refuses a result that is exactly zero (standing rule
   E). **The case samples the WHOLE bounding box, which is a weaker bound than the planter's own
   base footprint** — `treePlan` restricts its contacts to the parts near the ground (round-1 note,
   claim 7). It still fails at the pre-fix commit `9885586`: `Tree28 shows 2.19 studs of claw above
   the ground under it`.

9. **One settler, two plans.** `settleOnGround` takes a `SettlePlan`: a truck lifts until no wheel is
   buried, a tree sinks until no contact is in the air (`toLowest`), with no tilt and a missing
   ground sample skipped rather than fatal. Verify: `Build.footprintSamples` and `Build.worldBoxOf`
   are pure and asserted in `lobby.spec` ("samples the whole footprint and its corners, not just the
   middle"); the keep-out case uses `worldBoxOf` because `Model:GetBoundingBox` is ORIENTED and
   treating it as axis-aligned left seven tree parts inside the house.

10. **A tree is seated on the surface a player walks on.** The road, verges and yard are Parts half
    a stud proud of the terrain, so a terrain-only reader would plant a tree under one. Verify:
    `Build.surfaceOver` is pure and asserted in `lobby.spec` ("plants a tree on the road slab's top,
    not on the terrain hidden under it"), including that a point outside the slab answers nil and the
    higher of two overlapping slabs wins. Measured live: **0 of 38 tree footprints overlap a road or
    yard part today** — a guard for the next wider yard, not a fix for a live defect, and its header
    says so.

## What could not be verified

* **Karen's exact repro of the mouse bug was never driven.** She reported it after closing the shop
  with `E`. A `ProximityPrompt` cannot be fired by a script (`InputHoldBegin` is a no-op and a
  replayed `E` is ignored — measured this session), so the path from *her* close to the camera was
  never executed end to end. What is proved is the rule — `Camera.wantsDelta(processed, behavior)`,
  asserted directly in `camera_client.spec` — and the hand-back, asserted in `shop_panel.spec`.
  **No claim in this request rests on real OS-level mouse movement.**
* **The assertion text behind claim 2's failing run could not be captured.** Studio's output log is
  cleared when Play ends and the harness ends Play before returning, so the console held 110 bytes by
  the time it could be read. The harness's own count line is pasted instead, verbatim and unedited.
* **The tree case could not be run at the base.** At `98f9c6b` there is no tree planter, no
  `CLAW_FRACTION`, no fixture tree of either species and no such case. It was run against the pre-fix
  commit of the defect itself, `9885586`, with `src/` checked out there and the case reading the
  measured literal 0.075 for the config field that did not yet exist.
* **The junction depth reads −0.60 on every one of the 38 trees, and is reported as SUSPECT, not as
  a pass** (standing rule E): it is uniform *by construction* — the settler puts the junction exactly
  `SINK_STUDS` under the lowest ground, every time. The number that varies, and the one worth
  checking, is the claw-tip depth: **−2.33 to −7.50**.
* **`Workspace.OurForest` is untouched and is not ours.** Nothing under `src/` creates, moves or
  parents anything into it; 2 458 of its 4 819 trees stand more than 0.2 studs above the terrain,
  worst 41.4. It wants a task of its own.
* **Nothing in this branch has been judged by Karen since part 3c.** The lodge polish, the removals,
  the keeper, the trees and the phone layout are all waiting on her morning look.
