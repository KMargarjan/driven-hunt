# Review request — Task 243: the last shop goods and the lobby truck yard

Task: 243
Round: 2
Base: `3a4d7e43` (main, the merge of task 242 — PR #222)
Code commit: `f15e64255016060c9c21a8d1fada39625293ff0f`

```
[harness] PASS: 34/34 checks @ f15e64255016060c9c21a8d1fada39625293ff0f (clean tree) scope=all
```

(`f15e6425` is the commit that committed round 1's verdict; the last commit that changed `src/`
or `tests/` is `f12dc481` and the only thing between them is `reviews/task-243/RESULT.md`.)

`test2` is **N/A**: nothing this task touches is in `TWO_PLAYER_PATHS` (`src/shared/Lobby/`,
`src/server/Lobby/`, `src/client/Hud/ShopDisplay.luau` and their two specs — the lobby, the shop
window and the yard, none of which is the match, the drive, the tie or the teams). The one-player
line above is the whole gate for a review round and for the PR to `main`. `studio_mcp`, `agents` and
`privacy_scan` selftests all pass; `poses.json` is untouched, so `pose.py selftest` is not in play.
CI green: runs 39814662336 and 39815040767, both `success`.

## Round 1's two blocking findings, and what they cost

**Finding 1 was a real defect and the Reviewer is right about every step of it.** Task 243 turned
`Build.truck` -- the parts-built FALLBACK, which is the branch every spec and every world without
`Workspace.LobbyAssets.Truck` takes -- and left `truckRig`'s no-lamp branch asserting
`facing = (0, 0, -1)`. So on that branch the headlamps were built on the truck's south FLANK, the
beams were aimed sideways across the bays, and `lengthHalf` read the WIDTH half of the box and hung
the exhaust and the engine off the wrong end. Fixed, and **nothing below that constant names an axis
any more**: the lenses are placed ALONG `facing` and ACROSS its perpendicular out of the box's own
extents, and each lens is turned with `CFrame.lookAt` so its depth lies along the nose rather than
along world z. The case the Reviewer asked for is `lobby.spec`, *"builds the fallback truck's own
lamps at its own bonnet, not at a named axis"* -- written against the built `Bumper` and never
against an axis named in the test, so the two cannot drift apart again.

**Finding 2 was a comment that contradicted its own code**, and the code was right: in burgundy
`Fabric` the strap came out MOTTLED PURPLE across the whole front rim. `CaseLining`'s paragraph now
says what shipped -- nothing in this case is `Fabric` any more -- and claim 5 below says the same.

**Nine of the eleven non-blocking notes are taken in the same commit**, because every one is a
comment or a literal that contradicts the code it sits on, and leaving those to a later round is how
the next reader is misled: `lampsOf`'s two-generations-stale header, three rows still calling the
yaw a HALF turn, the deck numeral's "quarter", `TRUCK.SIZE` (now readerless -- kept under rule 7 and
said to be the fallback's nominal box), the pad-scan header's `SIZE.X`, the fence case's `-22`
literal (derived from `Build.yardRect` now), the tree-arc ceiling (sampled at the arc's INNERMOST
radius, so the bound is the one the comment claims), the rim-sight assertion's missing epsilon, and
the rock case gated on `knows`. The archive now quotes the five values it is the only record of.
**The two left are queued**, in `TASKS.md` as 243a: `docs/design/truck-pads.md` and
`docs/design/lobby.md` both contradict the shipped yard wholesale, and the Builder does not write
designs (task 242a(d)'s settled rule) -- one Architect run covers both.

## What changed

Karen, 2026-10-22, verbatim: *"always hunter card has to be replaced into nice design like you did
with deer license / package The hide has to be improved now is broke n / package marksman also
broken / the full season also broken / and I think we need to change car position / clean a bit
lobby / so once I go out from shop on right there has to be cars but looking at me so they will be
straig to me but not close to house there has to be distance / when I look now (image) it has to be
where trees starts there has to be those rectangles to enter game and behind trucks / so there is a
space"*.

Two Designer specs, both read whole: `<runs-dir>/design/goods-spec.md` section 8 (the hunter's card
and the three packages) and `<runs-dir>/design/lobby-yard-spec.md` (the yard). One upload, with
Karen's own OK recorded against it.

**Two things the plans asked for that MEASUREMENT refused**, both written up where they live and
both listed as claims below: the truck model's forward axis, and the frame `LODGE_TREES` is written
in.

## Claims

**1. `ALWAYS HUNTER` is a document now, under the licences' own one placement rule.**
`ShopDisplay`'s `DRAW` row for `ShopData.ITEM.ALWAYS_HUNTER` carries `image = ART.HUNTER_CARD` and
draws a model only `IN_PACKAGE`; `buildHunterPin`, `PIN_STAG` and `CARD_VIEW` are gone, and so are
the four palette rows nothing else read (`INK`, `FIELD`, `LODEN_DARK`, `ENAMEL`).
`ShopDisplay.dressLicenceImage` is **unedited** — the new row inherits upright, `Fit`, opaque,
centred for free, which is what `goods-spec.md` 3.5 being one function buys.
*Verify:* `shop_panel.spec`, `"draws each item the shop2 spec's own model"` (all three documents
draw nil in the case and exactly one part in a package) and `"rocks a flat thing"` (no shipped row
rocks any more). The picture is `.screenshots/243-goods-hunter-card.png`.

**2. The package case is a FIXED box and the goods are fitted into it by SHAPE.**
`buildBundle` draws a case of one of two sizes (3.30 × 1.70 for two or three items, 4.60 × 1.85 for
four to six), with a 0.22 rim, a lid with no label on it, and four slots: `FLAT` (any document, by
`imageFor`), `TALL` (the seat, by `viewFor`), `LONG` (the gun, by its own extents) and `SOLID`
(everything else, **unscaled**). `BUNDLE_SPREAD`, `BUNDLE_ITEM_STUDS`, `CaseLidLabel`, `CaseLidRule`,
the two ink bars and the `onLid`/`acrossLid` helper are deleted.
*Verify:* `shop_panel.spec`, `"fits every package into one fixed case, by shape"` — it asserts the
two case sizes, the rim's top, the four slot assignments against the Designer's own table, that
**every** model is inside the inner walls and above the floor, that **nothing is hidden by the near
rim** (the sight line from a thing's own top at 25 degrees), the gun's 2.80 studs lying on its side
with its belly on two chocks at y 0.135, the documents' 0.016 thickness and 0.022 of lift, and that
the two small cases are the SAME case.

**3. The slot rule is translated, not copied, in one place — and it is the place it had to be.**
`goods-spec.md` 8.2b writes the `LONG` test as *"extent x ≥ 2 × extent y"*, which is the Designer's
own frame. **In this repository a gun is built along `z`** (`Rifle.Geometry`'s `muzzleZ`, which is
why `RIFLE_VIEW` stands the camera at yaw 96 to photograph its side), so written against `x` the
rifle fails its own test and comes out `SOLID`. `ShopDisplay.slotFor` tests the longest HORIZONTAL
extent, and the order is `FLAT → TALL → LONG → SOLID` so the two tests that read an IDENTITY come
before the one that reads a shape.
*Verify:* `ShopDisplay.slotFor`'s own comment, and the `WANTED_SLOT` table in the spec case above.

**4. One departure from the sheet in the packages, stated in the code: the packed ammo stack.**
Section 8.2c stages each package's sub-pieces by hand — five cartons in `THE MARKSMAN`, three in
`THE FULL SEASON`. A packager that did that would hold a second copy of another row's geometry,
which breaks the one rule 8.2 says must be kept (`ShopDisplay.build(covered)` once per covered row).
So `buildAmmoStack` gained a compact `IN_PACKAGE` arrangement — section 8.2c's own three cartons,
the count that fits BOTH cases (five is 3.04 wide and the large case's back row would then be 5.06
against 4.44 of shelf) — and it is drawn in both packages. **The same carton at the same size**,
never a shrunken one.
*Verify:* the spec asserts `Display.build(UNLIMITED_AMMO, "lite")` is 3 + 3 parts and that every
`Carton%d` is exactly 1.00 × 0.70 × 0.32. `buildAmmoStack`'s own comment carries the arithmetic.

**5. NOTHING IN THE PACKAGE CASE IS `Fabric` ANY MORE, and that was photographed.**
The lining, the strap, the lid's cloth panel and the chocks were all `Fabric`. At the real 356 × 200
the lining came out as mottled dark STONE and the burgundy strap as mottled purple — the same
measurement `TRUCK.CAMO.BODY_MATERIAL` already records for this game's materials (*"the shot came
back with four BLACK trucks"*). The lining is the biggest area in the picture, under a gun this task
exists to make findable; the strap is the package's ONE SIGNATURE, the thing that tells the three
apart before a word is read.
*Verify:* `local fabric` is gone from `buildBundle` and no row in it carries a `material` but the
timber ones. The before/after pair is `.screenshots/243-goods-marksman.png`, and `CaseLining`'s
header carries both halves of the decision — round 1 found that paragraph asserting the opposite of
its own code, which is finding 2.

**6. The yard turns ninety degrees and SIX config rows keep their value.**
`TRUCK.OFFSET` `(26, 0, 18)` → `(58, 0, 24)`; the bays step SOUTH (`Build.trucks`), the pads sit WEST
of their bay (`Pads.centreFor`), `PADS.SIZE` swaps to `(12, 0.7, 9)`, and `BAY_GAP_STUDS`,
`BACK_STUDS`, `PAD_BEHIND_STUDS`, `PAD_GAP_STUDS`, `YARD_END_STUDS` and `YARD_LIP_STUDS` all keep
their numbers and change only the axis they apply to. **Task 213's 3.77-stud pad-to-bumper gap is
kept to the decimal.** The walk from the foot of the porch steps to pad 1 is 47.2 studs against 27.0,
and pad 1's west face stands 23 studs off the lodge's east wall against 3.5.
*Verify:* `lobby.spec`, the three rewritten cases — `"leaves one short step ... between every pad and
its own truck"` (the gap is now `nose − pad's east edge`, held to `PAD_GAP_STUDS` `{2, 4}`),
`"keeps every truck and every pad on the yard rectangle"` (length along x, width along z) and
`"puts one pad in front of each bay, clear of the lodge, the noses, the trees and the field"`.
Measured live in the Forest Test: pads at x 2897 (= anchor + 47) and z −2926 / −2943 / −2960 / −2977,
trucks at x 2916 (= anchor + 66), yard slab 46.2 × 85 centred on anchor + (56.1, −1.5).

**7. THE YAW IS `0` AND NOT THE PLAN'S `pi`, AND THAT IS A MEASUREMENT.**
`lobby-yard-spec.md` 2a asks for `3.1415927` because *"the model ships pointing along its own +X"* —
this row's own comment had said so since task 180. It does not. Built at `pi` and measured in the
live Forest Test on 2026-10-22, the white 248,248,248 lamps came out **dx +7.8 (EAST)** of each
truck's box centre on all four, with the tails at −8.6: the noses pointed AWAY from the lodge, which
is the opposite of Karen's *"looking at me"*. Task 197 had already found the same thing from the
other end (*"the headlights are at the model's local −X"*), and `Build.lampsOf` derives a truck's
facing from its own white lamps precisely so no config heading has to be trusted. At `0` the nose
looks west and the drawn nose lands at x 56.77 — **the Designer's own section 2b number**.
*Verify:* `TRUCK.MODEL`'s comment carries the measurement; the after frame is
`.screenshots/243-yard-porch.png` (four grilles and eight headlamps facing the camera). The
parts-built FALLBACK truck turned with it — same numbers, laid along x — so the harness's own lobby
does not park a truck across four bays.

**8. `LODGE_TREES` rows 5 and 7 have NOT moved, and that is the same kind of measurement.**
Section 2f asks for `(35, 22)` and `(41, 28)` to go to `(36, 48)` and `(44, 54)` because *"both fall
inside the new gravel"*. **That table is in the LODGE's frame** — its own header says so and
`Build.lodgeTrees` plants at `anchor + LODGE.OFFSET + (x, z)`, with the lodge at z +46 — so the two
rows sit at anchor-relative z **+68** and **+74** against a gravel edge at +41: 27 and 33 studs
clear. Moved as asked they would have landed at +94 and +100, inside `Workspace.OurForest` (southern
edge 54 studs north of the anchor) and 35 studs behind a house they are meant to stand beside.
*Verify:* `lobby.spec`'s new case asserts the FACT the plan was reaching for — no `LODGE_TREES` trunk
inside `Build.yardRect` — in the frame the builder actually plants in. The live build still plants
all twelve (`grove=12`).

**9. The gravel, the fence, the tree line and the blade-free block, as four assertions.**
`Build.yardRect` starts at the road's **east verge** and not its centre line (half the lane used to
be inside the yard); its east edge stays under the tree arc's own ceiling, which is the one number in
the plan that is BOUNDED rather than chosen (at bay x 70 the exclusion would delete a hundred studs
of wood directly behind the trucks); `FENCE.TO_Z` comes `-8 → -48`, four studs clear of the gravel's
south edge, where forty studs of post-and-rail stood inside the new yard; and the `Yard` ground block
grows to 124 deep **with its offset nudged `26 / 14 → 28 / 12`**, which is the plan's own step 8: at
the real anchor (2850, −2950) the four absolute edges then land on 2808 / 2948 / −3000 / −2876, every
one a multiple of 4, where `Terrain:FillBlock` writes 4-stud voxels and task 191 measured two grass
voxels surviving at a misaligned edge. The SIZE is untouched.
*Verify:* `lobby.spec`, `"keeps the turned yard off the fence, off the grove and inside the tree
line (task 243)"` — all six, including the voxel grid asserted at the REAL anchor. The ceiling is
sampled at the arc's INNERMOST radius (`RADIUS_STUDS - JITTER_STUDS`), which is what decides which
trunks the exclusion can actually reach, and the case prints the pair it measured:
`lobby: the yard's east edge is 79.23 against the tree arc's own ceiling of 79.75`. **That is 0.52
studs of margin and it is the tightest number in this task** — a bay moved three studs further east
would start deleting wood from behind the trucks. Live: 27 ring trees and 12 grove trees, the same
counts as before the move.

**10. "Clean a bit lobby": the five things, and the one that needed finding.**
The hot-pink panel on each truck's rear quarter is painted out; the spawn pad is invisible
(`Transparency` 0.6 → 1, every other property untouched); the fence is south of the yard; the
billboards go up 6 → 7.5 studs so a man on the pad cannot hide his own board; and each bay's number
is painted on its deck. **The pink one was measured rather than guessed:** over a BUILT truck in the
live Forest Test it is `Light`, `Neon`, **255,89,89**, **6.74 studs long** — `truckSkinOf` calls
anything `Neon` a "light" and `camo` leaves lights alone, while `ENGINE.LAMP_MAX_STUDS` 2.5 is far
too small for `truckRig` to claim it. It belonged to nobody. `camo` now paints any "light" too big to
be a lamp in the model's own near-black trim; after it, `loudprops = 0` on all four trucks and the
six real lamps are still at the rig's own off colours (3 heads at 64,62,56 and 6 tails at 58,30,28
per truck). The deck numeral's rotation, size and stroke were each looked at in the live place before
the row was written (`DECK.ROTATION_DEGREES` 180, `CAP_FRACTION` 0.705, `STROKE_PX` 5).
*Verify:* `.screenshots/243-yard-15.png` (numerals `2` and `3` painted on the decks, boards apart,
no pink anywhere), `243-pad-above.png` (the numeral from the pad), and the upload row in
`assets/uploads.json` carrying Karen's *"B"* verbatim.

## What I could not verify

* **The shop PANEL around the goods.** Three routes to photograph the live `ShopPanel` are closed and
  each was measured: a probe's `require` of a `PlayerScripts` module returns the client's own copy
  but `Hud.step` closes the panel on the next frame;
  `VirtualInputManager:SendMouseButtonEvent` is refused from a probe thread (*"lacking capability
  RobloxScript"*); and holding the counter's own `ProximityPrompt` from a probe leaves
  `ShopPanel.Visible = false` standing 4.97 studs from an enabled 8-stud prompt. So the four frames
  are the case's own `ViewportFrame` rebuilt from `ShopDisplay`'s own camera, lens and lighting
  constants (and, for the card, an `ImageLabel` at the case's own measured 334 × 182 dressed by
  `dressLicenceImage`) — the case's pixels with the panel's chrome left off. The chrome itself is
  unchanged by this task and was approved in tasks 228 and 241.
* **Karen's own eye on the look.** The Director approved the two target sheets; whether the yard and
  the four rows are right is hers.
* **The truck BODY does not drive away** when a party commits — it never did: `Build.setTruck` starts
  the engine, the lamps and the exhaust for the loading window and the player is placed at the drive.
  Measured on the pad path: stepping on pad 1 took the pad `sizing → countdown → empty` and the
  player's team from `nil` to `Shooters`, so a drive still starts; the truck's own box moved 0.0
  studs, which is the behaviour this task did not change.
* **`camera_client.spec:1618` failed once and then passed twice** (538/0 on the clean run). It is
  task 93's hand-template case, which this task touches nothing of; reported as a flake rather than
  investigated.
