# Review request — Task 244: four defects from Karen's evening test

Task: 244
Round: 2
Base: `d63f2535` (main, the merge of task 243 — PR #223)
Code commit: `0b72b550eea4c781a9a26813a5789cf00f092975`

```
[harness] PASS: 34/34 checks @ 0b72b550eea4c781a9a26813a5789cf00f092975 (clean tree) scope=all
```

## Round 1's blocking finding, and the Reviewer is right about every step of it

**The case offered as proof of the headline fix never executed the changed line.** `PadPanel.start`
opens with `if started then return end`, the live panel is already started, and the case passed
verbatim with the fix reverted — so claim 1 below was, as written, unsupported by the suite. It
drives a REAL start now, in `Hud.start`'s own order and the one that broke: `PadPanel.stop()`, then
`setRemotes(fake)`, then `start(frame, { leaving = … })` with no `remotes` key in the bag — and
`sendRoleWish` must send. Restoring `remotes = bag.remotes` turns it red. It asserts the other
direction too (a bag that BRINGS remotes still wins, so every caller written before this is
unchanged) and puts the live panel back, which the case above it already does for its own reason.

**Five of the seven non-blocking notes are taken in the same commit**, because each is a comment or
a claim that contradicts its own code:

* `textFor` (`Hud.readoutFor`) still named the SELECTION where the chip names the CHAMBER. That
  line IS the chip's content as one string, so a second answer there is the same lie in a quieter
  place; it reads `Hud.chamberedAmmo` now.
* the `ammoChipFor` comment named `weapon_client.spec`; the assertion is in `hud_style.spec`.
* `Hud.NO_LOAD` and `chamberedAmmo` had been inserted INSIDE `ammoChipFor`'s doc block, leaving
  that function with no header. Moved above it.
* `lobby.spec`'s `fakeTerrain` still said *"One method"*; it answers two.
* **THE RETRY IS A PURE RULE NOW** — `ShopDisplay.nextAsk(status, asked, since, now)`, one function
  that `meshReady` and `preloadImage` both ask, with a table of every `AssetFetchStatus` in
  `shop_panel.spec`. Deleting the re-arm turns that table red instead of leaving a counter that
  cannot go down. **And it brought a real defect with it**, which is the Reviewer's sixth note: a
  mesh that fails for good drew a `PreloadAsync` per piece per rebuild — four a second for as long
  as the shop was open. The ask is on a per-id cool-down (`ShopDisplay.RETRY_SECONDS` = 3),
  asserted longer than the `PICTURE_RETRY` it bounds.
* **the key chip and the eyebrow were both FULL WIDTH at the same Y** with `TextTruncate.AtEnd`,
  which hides a collision rather than preventing one. The row is split (`ROLE.KEY_PX` = 116) and
  the spec asserts the two rectangles are disjoint — off the DECLARED `UDim2`s, which are written
  synchronously, not off an absolute that a layout has not produced yet — and that neither word is
  truncated at its measured `TextBounds`. MEASURED in the run: eyebrow 67 px of 176, key chip 68 px
  of 116, gap 0.

The two notes NOT taken are queued for the Director as 244a: `shop_panel.spec`'s *"never shows the
glass"* exercises only the arm the DEV client's cache happens to be in (the invariant is what it
asserts, and the fail-able half is the `Loading` label, its text and the `PICTURE_RETRY` bounds),
and the `missing > 0` arm needs a client that can be made cold.

**One more thing the gate found, and it is reported rather than hidden:** the first run after these
fixes had ONE client failure and the next two had none. It was my own new case reading
`AbsoluteSize` and `TextBounds` in the frame it had made the block visible in — both are a
LAYOUT's answers, so they read 0 and `68 <= 0` is false. The disjoint claim moved to the declared
rectangles and the not-truncated claim waits for its frame. Three clean runs since.

`test2` is **N/A**: nothing this task touches is in `TWO_PLAYER_PATHS`. The files are
`src/client/Hud/` (the pad dialog, the shop window, the readout), `src/{server,shared}/Lobby/`
(the yard's terrain), `src/server/Weapon/` plus `src/shared/Shotgun/` (the shell swap), and
`src/shared/Shop/`. None of them is the match, the drive, the tie or the teams, and none of the
five spec files changed is in that list either. The one-player line above is the whole gate for a
review round **and** for the PR to `main`.

`studio_mcp selftest`, `agents selftest` and `privacy_scan selftest` + `scan` all pass. `poses.json`
is untouched, so `pose.py selftest` is not in play. CI green on the pushed head: run 39844533710,
`success`.

**Everything below was measured on Karen's own path in the live Forest Test** (rule H), before any
code was written and again after. The runner and the probes are `<runs-dir>/244*.{py,luau}`. The
Forest Test's `ServerStorage` attributes were read before the first Play and again after the last,
and are **identical** — `DHFlag_BOAR_BEHAVIOUR/BOAR_MODEL/COINS/DRIVE_BOTS/HORN/LICENCE_POPUP/
LOBBY/SHOP=true`, `DHForestStartRole=hunter`, `DHShopTestGrant=true`. Nothing was written there.
The window was then closed and the gate ran with DEV alone.

## 1. The role switch did not respond — and neither did any size row

**`PadPanel.start` wrote `nil` over the remotes `PadPanel.setRemotes` had already been given.**
`Hud.start` resolves `ReplicatedStorage.Lobby` through `Hud.whenReady`, which calls its callback
**synchronously** when the module is already there (it always is — Rojo replicates it with the
place), so `PadPanel.setRemotes(Lobby.remotes())` runs first; `PadPanel.start` then took
`bag.remotes` from a bag that carries no such key. The dialog's one outbound door has been shut
since task 182 built it.

1. **A real OS mouse click on the BEATER half sent nothing.** MEASURED: a wiretap connected to
   `Lobby.Remotes.RoleRequest.OnServerEvent` on the live server, `ALWAYS HUNTER` bought at the
   counter through `ShopRequest`, a step onto pad 1, and `click.ps1` on the half's own centre. The
   half **took** the click — `BackgroundTransparency` 0.68, which is `ROLE.PRESS_TRANSPARENCY`, so
   `Activated` fired — and the wire stayed empty. A real click on the `1 / 1` row sent no
   `PadRequest` either; that half was invisible because the pad falls back to the default size after
   `PADS.PICK_TIMEOUT_SECONDS`, so a dead button and a slow one look the same from outside.
   *Verify:* `PadPanel.start` now only takes `bag.remotes` when it is non-nil, and `setRemotes` is
   the one writer. `pad_panel.spec`, *"never lets `start` un-tell the remotes `setRemotes` already
   gave it"*.
2. **After the fix the same click works end to end.** Same script, same pixel: BEATER lit
   (`Underline.Visible` true, fill `ROLE.FILL_TRANSPARENCY`), HUNTER dark, the caption moved from
   `NOTE_HUNTER` to `NOTE_BEATER`, `DHRoleWish` read `beater` live on the player, the wiretap
   recorded `ROLE <name> beater`, and the drive then dealt her `Player.Team = Drivers`.
   *Verify:* the before/after frames in the report. A spec cannot fire `Activated`, so the click
   proof is the frame plus the live attribute read, as the Director's brief asks.
3. **A key as well, and the control says which key.** `T` (free: the sixteen `Enum.KeyCode`s bound
   anywhere in `src/` are Backspace, B, E, M, R, Tab, X, Return, four arrows, four gamepad), bound
   only while the dialog is up and released on the same edge — `LicenceCard.bindBuyKey`'s shape. It
   goes through `PadPanel.sendRoleWish`, the one sender, so the key can never do what the control
   would not. MEASURED on the live client: `T` flipped the lit half and put `beater` on the wire.
   *Verify:* `PadPanel.otherRole` / `toggleRoleWish` / `switchKeyBound`, and `pad_panel.spec`'s two
   new cases. The chip is `ROLE.KEY_HINT` formatted with the binding's own `KeyCode.Name`, on the
   eyebrow's row, so `ROLE.BLOCK_PX` does not move.
4. **`DHForestStartRole` was a suspect and is not the cause.** It records a ONE-SHOT request
   (`ForestTest.requestRole`) and `ForestTestBoot`'s `honour` consumes it at the first sweep,
   because a man with `Player.Team = nil` already reads as `ForestTest.ROLE_DEFAULT` — so it is
   spent before she ever reaches a pad. Proven by the end-to-end run above: with
   `DHForestStartRole=hunter` set, the BEATER click put her on `Drivers`.

## 2. The shop showed grey boxes while the guns loaded

5. **The measured-box fallback no longer reaches the glass.** `ShopDisplay.build` still draws it —
   that fallback is right in the player's HANDS, where a hole would be worse — and counts what it
   fell back on. `ShopPanel.showPicture` reads that count: the `ViewportFrame` goes
   `Visible = false` and the case shows `TEXT.CASE_LOADING` until every piece is real, retrying
   every `ShopPanel.PICTURE_RETRY`. *Verify:* `shop_panel.spec`, *"never shows the glass while a
   piece is still missing"* — an invariant over every id in `Shop.ORDER`, so it holds whatever the
   client's cache happens to hold when it runs.
6. **The panel asks for all three guns the moment it opens.** `ShopDisplay.warm`, through the SAME
   `meshReady` door the draw uses, so there is no second asking mechanism. MEASURED on the live
   client: before the open, `ViewmodelLever`'s three meshes were `AssetFetchStatus.None`; after it,
   all three `Success`, and selecting LEVER RIFLE put **3 MeshParts and 1 plain part** in the case —
   the real gun, in the frame, not the grey slab Karen photographed (L-094).
7. **A failed first fetch is asked for again.** `asked[id]` and `askedImage[image]` were set once
   and never cleared, so an id whose first `PreloadAsync` FAILED was never asked for again and the
   fallback stood for the session (b241a's finding, never carried into a task until now). Only the
   two TERMINAL answers — `Failure` and `TimedOut` — re-arm the ask; `Loading` and `None` still
   mean wait. *Verify:* `meshReady` and `preloadImage`; `ShopDisplay.fetchStats()` counts asks and
   retries, and `shop_panel.spec` asserts the counters and the warm.

## 3. Slug is slug and buck is buck, on both shotguns

8. **The readout printed the SELECTION and the server fires the CHAMBER.** `state.ammo` is what the
   next LOAD uses; `Weapon.onFireRequest` fires `state.loaded[state.selected]`. `Hud.chamberedAmmo`
   is now that one expression and the chip's word and glyph follow it, falling back to the selection
   only for an empty chamber. The POCKET stays the selection's — a different fact: it is the pocket
   the next load comes out of. *Verify:* `hud_style.spec`, *"names the shell in the CHAMBER"*,
   including a mixed tube read shell by shell.
9. **A shell-type swap now empties the gun of the old kind first.** The side-by-side already did
   (`CYCLE_EJECTS` is `"all"`); the semi-auto's is `"spent"`, which is right for the bolt after a
   shot and wrong for a man changing ammunition — a tube of five live buckshot has no empty chamber,
   so every `Load` answered `barrel-full` and the gun went on firing buck with SLUG on the readout.
   One optional `Action.ejects`, read by one branch, sent by one caller. *Verify:*
   `weapon_state.spec`, *"empties a TUBE of the old shell when the type is swapped"* — which also
   asserts the side-by-side is bit-for-bit what it was.
10. **Six arms, each ENTERED on the player's path** (L-093), every shot down
    `Shotgun.Remotes.FireRequest` and every count the server's own `ShotLanded.impacts`
    (`PELLETS = { Slug = 1, Buck = 9 }`):

    | arm | chip | chambered | impacts |
    |---|---|---|---|
    | side-by-side SLUG | `SLUG` + slug glyph | Slug | **1** |
    | side-by-side BUCK | `BUCK` + buck glyph | Buck | **9** |
    | semi-auto SLUG | `SLUG` + slug glyph | Slug | **1** |
    | semi-auto BUCK | `BUCK` + buck glyph | Buck | **9** |
    | after a reload | `BUCK` + buck glyph | Buck | **9** |
    | tube swapped mid-magazine | `SLUG` + slug glyph | Slug, whole tube | **1** |

    **A MIXED magazine is no longer reachable on the player's path**, and that is the fix rather
    than a gap: measured, two buckshot fired out of five and then SLUG selected leaves
    `[None, Slug, Slug, Slug, Slug]`. The mixed case is still asserted, by hand, in `hud_style.spec`.

## 4. The trucks stood on grass

11. **The yard's rectangle was never the problem; the voxel band was.** MEASURED before any code: a
    raycast grid 2.5 studs apart over the yard read `Ground` at exactly 150.00 and `Grass` at
    150.36..151.27 in a DIAGONAL band — a contour of the old hill, inside the pad's own footprint
    (x 2808..2948, z -3000..-2876), which holds every truck with ~20 studs to spare. Under the
    sixteen wheels: bay 1 none on grass, bay 2 one, bay 3 two, **bay 4 all four**. The shelf
    (149.248) falls inside the 148..152 voxel band, so a pad block whose top IS the shelf writes
    only part of that voxel and the hill's grass keeps the voxel's MATERIAL; the air block then
    trims the height and leaves the material alone. `Field.fill` now scrubs each pad's own
    rectangle with `Terrain:ReplaceMaterial` **after** the air cut. *Verify:* `Field.padRegion` and
    `lobby.spec`, *"scrubs every pad's own rectangle back to its own material"*.
12. **Filling higher was tried and rejected by measurement, not by taste.** A pad block raised 4
    studs scrubbed every grass voxel AND lifted the whole yard to 151.27 — the air block's own
    bottom lands on the same band, so it could not cut back what the pad had added — which would
    have buried the road and all four pads (they sit at `shelfY + THICK/2` = 149.50) under 1.77
    studs. `ReplaceMaterial` changes a material and nothing else. **After the fix: all sixteen
    wheels on `Ground`, and not one grass sample anywhere in the yard grid.** The trucks did not
    need to move, which keeps task 243's measured layout exactly; the ground-level frame from the
    north end of the row is in the report.

## And a harness fault, reported rather than worked around (rule 6)

13. **Nineteen cases of the role switch had never run.** In `pad_panel.spec` (11) and
    `shop_panel.spec` (8) they were written INSIDE the body of a preceding `it()`. TestEZ's
    `TestPlan.newEnvironment` closes each node's environment over THAT node, so an `it()` called
    while an `it()` is running adds a child to the It node — and `TestRunner.runPlanNode` recurses
    into `Describe` children only, never into an `It`'s. The cases were registered too late and
    never visited, and both suites still read green. Tasks 229 and 242 signed the switch off on
    them; the Learning Agent queued it as 229h on 2026-10-21 and nothing had moved it. Un-nesting
    them is the whole fix, and the first gate run after it found three real failures at once —
    `lobby_live.spec`'s own terrain stand-in answered `FillBlock` and nothing else, and
    `pad_panel.spec` asserted `switchText()` was four words where the key chip makes it five. Every
    `it(` in `tests/` now sits at its describe's own indent; the whole tree was swept and these two
    files were the only ones.

## What could not be verified

* **Karen's eye, on all four.** The frames are mine. The yard, the case and the dialog are hers to
  judge, and the switch is a feel question as well as a wiring one.
* **The grey box on a genuinely COLD client.** The loading state is proved as an INVARIANT (claim 5)
  and the warm is proved by the fetch statuses going `None -> Success` across one open (claim 6),
  but a client that has never held any gun could not be staged inside one Play session.
* **A failed fetch.** `meshReady`'s retry path is read off `GetAssetFetchStatus` and asserted
  through its counters; a real `Failure` cannot be provoked from here, so the retry is proved by
  construction and by the counter being readable, not by a failure that happened.
* **`ShopPanel.PICTURE_RETRY` at 0.25 s** is a judgement about how a blank case feels, not a
  measurement.
