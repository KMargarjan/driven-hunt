# Task 196 — a better shop menu, the room around it, the keeper, and the trees

Task: 196
Round: 3
Base: `98f9c6b`
Code commit: adfce971c5670853d688de8190bb183788ec1e0f

```
[harness] PASS: 33/33 checks @ adfce971c5670853d688de8190bb183788ec1e0f (clean tree) scope=all
[harness2] PASS: 35/35 checks @ adfce971c5670853d688de8190bb183788ec1e0f (clean tree)
```

Six of Karen's own looks in one branch: a better buy menu, then the room round it, then the Designer
deciding the look, then a bug and a photo survey, then the Designer's lodge polish, and twice — on
her own frames — the trees. The look specs (`shop-design-spec.md`, `lodge-polish-spec.md`, the
mockups, the survey and after PNGs) live **outside this repo** and are cited as *the Designer's spec,
2026-10-16* and *the Designer's lodge spec, 2026-10-16*; none of them is copied in.

## Claims

1. **Round-1 finding 1: the rail has two reasons to be down, and one writer.** Part 3f wrote
   `railFrame.Visible` from `Hud.renderObjective` every frame, which beat `Rail.setSuppressed` — the
   first frame after a sight picture went up put four buttons back inside the eyepiece — and beat
   `Rail.visible(touchEnabled)`, Karen's `SHOW_ON_DESKTOP`, with it. Verify: `Rail.setCovered` is
   edge-triggered beside `Rail.setSuppressed`; `Rail.applyVisibility` makes the single assignment
   `Rail.visible(touchEnabled) and not suppressed and not covered`; `Hud.renderObjective` only calls
   `Rail.setCovered(...)`. Grep: the sole writers of that frame's `Visible` under `src/` are
   `Rail.applyVisibility` and the `false` `Hud.build` sets before `Rail.start`.

2. **…and the two reasons are asserted independent, off the real frame.** `hud_clarity.spec`,
   "stays down while EITHER the sight picture or a panel holds it, per-frame pass included", drives
   `Hud.renderObjective` with the rail suppressed and no shop open — the state the defect needed —
   then walks suppressed-only, covered-only, both, clearing one, both clear, and measures the free
   state against `Rail.visible(UserInputService.TouchEnabled)` rather than a literal `true`. At
   `ade4711` that run was `352 passed, 1 failed, 1 errors`; **the `1 failed` and the `1 errors` are
   the same case counted in two columns** — `TestKit.run` takes `failureCount` from TestEZ's
   `results.failureCount` and `errorCount` from `#results.errors`, and a failed `it` lands in both.
   I could not capture that case's assertion text: Studio's console is cleared when Play ends and
   the harness ends Play before returning. The count line is the whole of the evidence for this one.

3. **Round-2 finding 1: `Body.SLOTS` means one thing again, and the invariant is callable.** Task
   196 put `waistcoat` and `beard` into `Body.SLOTS`; the composition root loops that table and
   asserts every entry has an asset key, so `OutfitAssetsBoot` died at boot, before
   `Body.setAccessorySource` and `Loader.preload`. Verify: `Body.SLOTS` is `{ hat, vest }`,
   `Body.PLATE_SLOTS` is `{ waistcoat, beard }`, and `Body.unmappedSlots(mapping)` is pure — the boot
   asserts on it and `match_outfit.spec`, "maps every accessory slot the asset pipeline must fetch,
   and no plate-only slot", calls it with the same mapping. **It fails at `471c394`:**

   ```
   TestService: OutfitAssetsBoot's mapping does not name beard, waistcoat -- its assert kills the boot
   ServerStorage.Tests.match_outfit.spec:1097
   ```

   Chosen over a "no accessory" sentinel in the boot's mapping because the boot's loop is then
   correct for every future slot with nobody remembering an exception in a second file.

4. **Fixing the boot exposed a second bug, and it is fixed too: the keeper was handed the hunters'
   cap.** His hat group is slot `"hat"` so `Body.tintFor` can paint it from `LODGE.KEEPER.HAT_COLOR`,
   and the accessory source answers that slot with `outfit.cap` — which only showed once the source
   started working. `KEEPER_HAT`'s own comment already claimed he never wears a catalog accessory.
   Verify: `Group.platesOnly` is on `KEEPER_HAT` and `wearAccessory` returns false for it; the same
   `match_outfit` case asserts the keeper's hat group carries it and that **no** `Shooters` or
   `Drivers` group does.

5. **Live, in the Forest Test (`game.PlaceId` 130094961655666, read in the probe).** Boot:
   `[OutfitAssetsBoot] 2 of 2 catalog accessory(ies) loaded: outfit.vest=ok(371ms)
   outfit.cap=ok(1632ms)`, with `Stack Begin` 0, `error` 0, `invalid argument` 0, `attempt to` 0 in
   the console read 9 s after boot. The player on `Shooters` wears `SolidCap<MeshPart Handle>` and no
   plate parts; `bot-beater-1..4` wear `SolidCap` **and** `Accessory (High Vis Vest)`, both MeshParts,
   with 0 vest plates; the `Shopkeeper` wears **no** Accessory and all of `HatBrim`, `HatBrimBack`,
   `HatCrown`, `HatBand`, `HatCrease`, `HatBrush1..3`, `BeardJaw`, `BeardChin`, `Moustache` and five
   `Waistcoat*` plates.

6. **The shop is master-detail, and its layout is one pure function.** `Shop.ROWS` carries
   `category` and `blurb`, both on the `WireRow`; `Shop.groups` and `Shop.menuOrder` are the pure
   functions the menu is built from; `Shop.rowsOk` refuses a row with no shelf, no explanation or one
   over `BLURB_MAX`. Verify: `shop.spec` asserts `rowsOk` on each of those three; `shop_panel.spec`
   asserts `ShopPanel.layoutFor` at 400×800, 800×600 and 1920×1080, including the picture capped on
   HEIGHT as well as width. **The panel's RENDER is payload-driven; its row SET is not** —
   `buildWell`/`buildStrip` create instances from the client's own catalogue copy, so a payload row
   the client does not know is drawn nowhere.

7. **The Designer's panel, with four engine deviations written down.** Verify: the addendum to
   `docs/research/2026-10-15-shop-window.md` against `ShopPanel.LOOK` and `Shop.CONFIG.PANEL` — no
   letter spacing (`ShopPanel.spaced`), no per-corner radius, the spec's label print was inside the
   label and invisible, and `Fabric` read as grey stone at 1.8 studs.

8. **The room is what Karen last asked for: one trophy, no table, and the shield has a point.**
   Karen, 2026-10-16: *"remove table and all boar heads only keep one where is on fireplace"*.
   Verify: `lobby.spec` "hangs ONE trophy, on the fireplace wall, with its point and nothing behind
   it" (asserts `#MOUNTS == 1`, its wall is `west`, no `Mount2`, no `TrophyBacking`, no
   `SconceFlame1`, `BACKING`/`LIGHT` gone, the stag's place a measurement with no parts, and the
   point is **not** a `WedgePart` with its `Size.Z` on the wall normal) and "has no table and no
   bench left inside the room" (fails by NAME, listing what still stands; `PorchBench` excluded and
   said to be). Archived per rule 7: `backups/2026-10-16_task-196_table-and-north-trophies.txt`.

9. **No tree stands on its claws, and both the junction and the surface are measured.** The contact
   is the trunk/flare junction, measured once per model off the mesh and stored as data
   (`TREELINE.SPECIES[n].CLAW_FRACTION`: birch 0.075, oak/alder 0.03). Verify, all in `lobby.spec`:
   "buries each tree's root claws…" asserts every species carries the number and **refuses a result
   that is exactly zero** (standing rule E) — it fails at `9885586` with `Tree28 shows 2.19 studs of
   claw above the ground under it`; "samples the whole footprint and its corners…" pins
   `Build.footprintSamples`; the keep-out case uses `Build.worldBoxOf` because
   `Model:GetBoundingBox` is ORIENTED and treating it as axis-aligned left seven tree parts inside
   the house; and "plants a tree on the road slab's top…" pins `Build.surfaceOver`, including that a
   point outside the slab answers nil and the higher of two overlapping slabs wins. One settler:
   `settleOnGround` takes a `SettlePlan` — a truck lifts until no wheel is buried, a tree sinks until
   no contact is in the air.

10. **The mouse comes back when the shop closes.** `Camera.Cursor` is the one writer of
    `UserInputService.MouseBehavior`; the camera's handler dropped every `gameProcessedEvent` delta,
    so with the pointer locked the camera stopped turning. Verify: `Camera.wantsDelta(processed,
    behavior)` asserted directly in `camera_client.spec`, and the hand-back on close asserted in
    `shop_panel.spec`.

## What could not be verified

* **Karen's exact repro of the mouse bug was never driven.** She reported it after closing the shop
  with `E`. A `ProximityPrompt` cannot be fired by a script (`InputHoldBegin` is a no-op and a
  replayed `E` is ignored — measured this session), so the path from *her* close to the camera was
  never executed end to end. **No claim here rests on real OS-level mouse movement.** The same limit
  is why the phone frame `P-phone-shop-strip.png` shows the rail still drawn: the panel was made
  visible directly rather than opened, so `ShopPanel.hidesRail` correctly answers false, and claims 1
  and 2 rest on the spec, not on that frame.
* **Claim 2's assertion text could not be captured** — see the claim. The count line is all there is.
* **The claw case could not be run at the base.** At `98f9c6b` there is no tree planter, no
  `CLAW_FRACTION`, no fixture tree of either species and no such case. It ran against the pre-fix
  commit of the defect itself, `9885586`.
* **The junction depth reads −0.60 on every one of the 38 trees, and is reported as SUSPECT, not as
  a pass** (standing rule E): it is uniform *by construction* — the settler puts the junction exactly
  `SINK_STUDS` under the lowest ground. The number that varies is the claw-tip depth, **−2.33 to
  −7.50**.
* **No eye-height frames were taken of the cap, the vest or the keeper after the round-2 fix.**
  Claim 5 is instance-level — Accessory class, `Handle` MeshPart, plate names — which settles *real
  accessory vs plates* better than a photograph, but it is not a look under rules E and F.
* **`Workspace.OurForest` is untouched and is not ours.** Nothing under `src/` creates, moves or
  parents anything into it; 2 458 of its 4 819 trees stand more than 0.2 studs above the terrain,
  worst 41.4. Its own task.
* **`smoke.sh` was blind to boot asserts for six runs** — it greps a console tail taken at the end of
  an 85 s run, and the assert's message contains none of its error words. The Director has since
  fixed it to read the whole console. The harness gap, not this branch's code, is what let round-2
  finding 1 live that long.
* **Nothing in this branch has been judged by Karen since part 3c.**
