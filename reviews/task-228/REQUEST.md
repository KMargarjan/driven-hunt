# Task 228 — the shop, round 2: room to breathe and better goods

Task: 228
Round: 1
Base: bce5177f (main)
Code commit: 1fc8f820a5b0d713b3f4bbe4e1c23ee86b0f0ada

```
[harness] PASS: 33/33 checks @ 1fc8f820a5b0d713b3f4bbe4e1c23ee86b0f0ada (clean tree) scope=all
```

`test2` is **N/A**: nothing here is in `TWO_PLAYER_PATHS` (`tools/agents.py`). The change is
`src/shared/Shop/`, `src/client/Hud/` and one client spec — the shop panel and the models in its
window, which behave the same with one player as with two.

## What changed

Karen, 2026-10-21: *"in menu need more space between items now cards on left side is cluttered a bit
/ and better desig on actual things we selling like licenses amunitions designer can handle that"*.
The Designer's answer is `<runs-dir>/design/shop2-spec.md` (2026-10-21), with `shop2-shop.png`,
`shop2-items.png` and `shop2-mockups.png` beside it. This is its **sections 1, 2 and 4**.

**Section 3, the HUNTER/BEATER role switch, is NOT here** — it is task 229 (it touches the match).
No switch control, no owned row of its own, and `ROW_SWITCH_PX` is not added.

Four files of code, plus one archive:

* `src/shared/Shop/init.luau` — `CONFIG.PANEL` only: the spacing numbers.
* `src/client/Hud/ShopPanel.luau` — the well, the row's interior, two fade masks, the phone's strip.
* `src/client/Hud/ShopDisplay.luau` — `Piece.reflectance`, the palette, two cameras, and seven
  item drawings replaced.
* `tests/client/shop_panel.spec.luau` — the new numbers, a new case for the list's geometry, a new
  case for the models, and the rock case now asserts both rocks.
* `backups/2026-10-21_task-228_ShopDisplay-old-item-models.luau.txt` + `backups/README.md` (rule 7).

No owner moves. `Shop` still decides the data, `ShopPanel` is still the one writer of every
rectangle in the panel, `ShopDisplay` is still the one drawer of an item's model.

---

## Claims

**1. The list has air, and it is the spec's air.** `PANEL.ROW_GAP` 8 is new and is the
`UIListLayout`'s padding in `buildWell` — at 0 the rows shared their edges. `SHELF_GAP` 9 is gone,
split into `SHELF_LEAD` 20 (above a head, 0 for the first) and `SHELF_TRAIL` 10 (below it).
`WELL_WIDTH` 228→236, `WELL_PAD` 10→12, `ROW_PX` 60→64, `SHELF_PX` 24→20.
*Verify:* `Shop.CONFIG.PANEL` in `src/shared/Shop/init.luau`; `buildWell` in `ShopPanel`;
`.screenshots/228-before-list.png` beside `.screenshots/228-after-list.png`.

**2. The shelf frame subtracts the stack's own gap from each side, and that is deliberate.** The
`UIListLayout` already puts `ROW_GAP` between the shelf frame and its neighbours, so the frame's
`PaddingTop` is `SHELF_LEAD - ROW_GAP` and its `PaddingBottom` is `SHELF_TRAIL - ROW_GAP`. Without
the subtraction the visible air would be 28 above and 18 below, not the spec's 20 and 10, and the
canvas would be 72 px out.
*Verify:* the `lead`/`trail` locals in `buildWell`; the measured canvas in claim 3.

**3. The canvas is exactly the spec's 1078, and the fold lands on a whole shelf head.** Section 1.5
wants five whole rows and the whole of the next head above the bottom of a 480 px well. Measured
live in Play: `Menu.AbsoluteCanvasSize = (236, 1078)`.
*Verify:* the new case `"spaces the list the way the shop2 spec measures it, and the fold lands on a
whole head"` in `tests/client/shop_panel.spec.luau` — it walks the BUILT children of `Menu` in
layout order, adds the heights the way the layout adds them, and asserts `canvas == 1078`,
`wholeRows == 5`, `wholeHeads == 3` and that the first thing cut is an `Item_`.

**4. The well has two fade masks and neither is pressable.** `FadeTop` / `FadeBottom`, `WELL_FADE`
10 tall, children of the panel (not of the `ScrollingFrame`, or they would scroll with the rows they
mask), placed by `relayout`, `Active = false`.
*Verify:* the `for _, side in ipairs(...)` block at the end of `buildWell`, the `fadeInset` block in
`relayout`, and the `FadeTop`/`FadeBottom` assertions in the new spec case.

**5. The phone's strip: every gap is a frame, because the two gaps are different widths.** A
`UIListLayout` padding applies on BOTH sides of a spacer, so a padding of 10 could never make a
boundary of `CARD_GROUP_GAP` 18 — the spacer would have to be −2 wide. So the layout's padding is 0
and each gap is an explicit frame: `CardGap_*` at `CARD_GAP` 10, `GroupGap_*` at 18 with a 1 px
`LINE` @ 0.55 hairline down its middle. Cards are 108 × 88; the category word is gone from the card.
*Verify:* `buildStrip`'s `spacer` helper; the strip assertions in the new spec case (card count,
`groupGaps == groups - 1`, `cardGaps == #Shop.ORDER - groups`);
`.screenshots/228-after-strip.png`.

**6. The two licences are one open booklet in two cloths, and the print is placed on each leaf's own
normal.** `buildLicence(parent, kind)` replaces two builders. The booklet stands open at 160°, so
"0.034 proud of the page" is an offset along the leaf's own normal and not a world `z` — `leaf()`
and `onLeaf()` are that arithmetic, and `CFrame.Angles(0, yaw, rz)` puts the in-plane turn first.
Deer is 70 parts (34 shell + 12 crest + 14 body + 10 antlers), beater is 67 (34 + 3 band + 2×15
horn).
*Verify:* `leaf`, `onLeaf`, `licenceShell`, `deerFurniture`, `beaterFurniture`, `horn` in
`ShopDisplay`; the part counts in the new spec case; `.screenshots/228-before-licence-reddeer.png`
(the old stag is invisible inside its own panel) beside `.screenshots/228-after-licence-reddeer.png`
and `-licence-beater.png`.

**7. Every printed face is on the wall the camera is actually on.** `SOLID_VIEW` (yaw 34) and
`TALL_VIEW` (yaw 30) look from `+x / +z`, so the carton's label is on `WallNear` at `z = +0.40`, the
case's strap and plate are on `+z`, and the case's lid is hinged at `−z` so the camera sees its
inside. The `buildAmmoCrate` this replaces stencilled `−z`.
*Verify:* `buildSlugCarton`'s `NearLabel`/`NearRule`/`NearBar`, `buildBundle`'s `Strap`/`Plate` and
its `lidAt`/`onLid` derivation; `.screenshots/228-after-ammo-slug` is in the list frame
(`228-after-list.png`), `.screenshots/228-after-bundle-marksman.png`.

**8. The high seat is OUR open stand, read off `HighSeats`, not the spec's closed box blind.** The
Director's override, 2026-10-21 (Karen, 2026-10-20: *"we stay what you have builded"*). Every
dimension comes from `HighSeats.DIMS` and every colour from `HighSeats.COLORS` — the same module
`ForestTest.Seats` plans the real stands from — times one scale, `SEAT_TALL_STUDS / (DECK_RISE +
RAIL_RISE)`. `seatAt`/`seatSize` turn it a quarter about Y so the ladder (the real seat's south
face) faces `+x`, where `TALL_VIEW`'s camera is. The roof, walls, window cut-outs and dark interior
of spec 2.8 are dropped; its brass key tag is kept, because what the row grants is access.
*Verify:* `buildHighSeat` in `ShopDisplay` against `HighSeats.plan` in `src/shared/HighSeats/`; the
part-count assertion `4 + 1 + 2 + 1 + 5 + 2 + 7 + 5`; `.screenshots/228-before-access-highseat.png`
(a table seen from above at `SOLID_VIEW`'s 25°) beside `.screenshots/228-after-access-highseat.png`.

**9. A model knows it is inside a package in exactly one place.** `ShopDisplay.build` gains an
optional `detail`, and `buildBundle` is the only caller that passes it — `"lite"` for the bandolier,
which is 82 parts on its own and 47 inside a 1.42-stud thumbnail. Every other builder ignores it.
The package rule is unchanged: a package draws `ShopDisplay.build(covered)` per content, so it can
never show something it does not contain.
*Verify:* `ShopDisplay.build`'s signature and the one `detail` argument in `buildBundle`; the `lite`
assertion (47) in the new spec case.

**10. One spec number is wrong on the screen and is deviated from, with the measurement written
down.** The pin's enamel at `reflectance` 0.30 (spec 2.7) came out TAN — the same tone as the brass
rim and the brass stag standing on it — because a `ViewportFrame` has no sky and `Reflectance`
blends the colour toward the frame's own light. Proved by tinting `PinFace` magenta in the live
viewport: it rendered pale pink (`.screenshots/228-pin-probe.png`). It is 0.06 now, and the blaze
band's 0.10 is 0.
*Verify:* the comment on `PinFace` in `buildHunterPin`; `.screenshots/228-pin-probe.png` and
`.screenshots/228-after-role-alwayshunter.png`.

---

## What I could not verify, and what is wrong in the spec

* **The TALL layout was never rendered at 400 × 800.** The Studio window is 969 × 784 and
  `ViewportSize` is read-only, so the panel clamps to WIDE in every frame I could take. The TALL
  *numbers* are asserted purely (`detailY == 172`, `detailHeight == 456`, `caseHeight == 178`,
  `stripHeight == 88`, `cardWidth == 108`), and the cards' own geometry is in
  `.screenshots/228-after-strip.png` — taken by forcing the strip visible in a WIDE panel, which is
  a real render of the real card instances and is labelled as forced in the rig. What no frame here
  shows is the TALL panel as a whole. The Device Simulator would show it and is deliberately not
  used: it outlives the session and cost task 220 three gate runs.
* **The WIDE frames are 640 × 627, not 640 × 576.** Same reason — the Studio window is 784 tall, not
  720. Everything in the panel is identical; only the well is 51 px taller, so the fold in the
  frames is one row lower than at 1280 × 720. The fold itself is asserted at 1280 × 720 in the spec
  (claim 3).
* **`detailWidth` is 356 and not the spec's 352.** Section 1.2's derived block writes
  `640 - 268 - 16 = 352`; that is 356. Section 1.2's own prose agrees with 356 (*"the display case
  356 × 200 at 1280 × 720 (was 364)"*) — 8 px off the case for the 8 px onto the well. The spec's
  §5 check 1 repeats the slip. The code's arithmetic is unchanged and the spec asserts 356.
* **Section 2.4.2 says the licence shell is "28 parts"; it is 34**, and the spec's own totals prove
  34 is right (34 + 36 = the stated 70 for deer, 34 + 33 = the stated 67 for beater).
* **The card's picture slot is empty.** Section 1.6 wants "picture slot top, name at the bottom",
  and there is no picture to put there: a `ViewportFrame` per card would be ten cameras in a strip,
  which is the count `Hud.ReportPanel` refused one for. The top of a card holds the tag and nothing
  else. Visible in `.screenshots/228-after-strip.png` — Karen's call.
* **`THE FULL SEASON` is a 10-stud case holding six small things**
  (`.screenshots/228-after-bundle-season.png`). The spec predicts exactly this and calls it *"the
  honest picture of a six-item package"*, with *"if the Director wants them bigger, the lever is
  `covers`, not this file"*. Reported, not changed.
* **Nothing about what the goods DO was checked.** This task redraws rows; it does not price them or
  change what they grant. The Learning Agent's standing note (L-100) that task 221's rows were
  proven by `knows = true` rather than by a player performing what they unlock is still open and is
  not addressed here.
