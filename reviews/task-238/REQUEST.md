# Task 238 — the "NO DEER LICENCE" popup, buying from it, and the Robux switch

Task: 238
Round: 1
Base: `ffb4dfed` (merge of PR #216, task 235)
Code commit: `33158586ce30045afa6cf54cee65b8afc84398dc`

```
[harness] PASS: 34/34 checks @ 33158586ce30045afa6cf54cee65b8afc84398dc (clean tree) scope=all
```

`[harness2]` is **N/A**: no changed path is in `TWO_PLAYER_PATHS` (`tools/agents.py`). The change is
weapon, Hud, shop and economy — the explicit one-player list (Director, 2026-10-03).

## What changed

Karen, 2026-10-21: *"if you dont have a license when you aim and what to shoot it shows popup you
dont have license and then you want to buy and roblox popup like they do to purchase"*.

A card (`src/client/Hud/LicenceCard.luau`, new, born dark behind `LICENCE_POPUP`) shown when a
hunter aims at a red deer he has no licence for; a BUY that goes through the shop's existing server
purchase path from anywhere; and the Robux switch built and not live. Note:
`docs/research/2026-10-22-licence-popup-and-robux.md`.

**The dispatch's premise is contradicted by the shipped rule and `ESCALATE.md` carries it** (L-073):
an unlicensed shot was already a hard server refusal costing nothing, so the card's copy says that,
and nothing here un-blocks a shot or adds a penalty.

## Claims

1. **ONE targeting path, and the trigger now shares it.** `Weapon.lookAhead` is the single cast plus
   `askTarget`; `onFireRequest` calls it (where it used to cast inline and call `askTarget` again at
   the `Rules.refuse` call site) and the new `"Aim"` branch of `onActionRequest` calls the same
   function. *Verify:* `grep -n "castFn(" src/server/Weapon/init.luau` finds one call, inside
   `lookAhead`. There is no client raycast: `grep -rn "Raycast" src/client/` finds only
   `Camera/Rig.luau`'s occlusion cast and two comments.

2. **The aim answer never clicks the gun dry.** It travels in the new `WeaponSnapshot.advice`, not in
   `refused` — `CameraBoot.client.luau` plays `Weapon.Sound.dry` on every arriving snapshot whose
   `refused` is a string. *Verify:* `tests/server/licence_popup.spec.luau`, *"travels in `advice` and
   never in `refused`"*; and the publish call in `onActionRequest`'s `"Aim"` branch, which passes
   `nil` for `notice` and for `refused`.

3. **The aim question moves nothing, and it is driven live.** `tests/server/licence_popup.spec.luau`,
   *"advises an unlicensed aim at a deer, stays silent for a licensed one, and spends nothing"*,
   drives `Weapon.onActionRequest` — the function `Weapon.start` connects to the remote — and asserts
   the barrel, `open`, `shots` and `refused` are unchanged. Harness note:
   `licence_popup: Alhamdulilah824 questions +2 advised +1 shots +0; barrel Live -> Live`.

4. **It asks the licence question only.** `Rules.unlicensed`, not `Rules.refuse` — so no aim can
   produce `OFF_STAND`, `BEATER`, `DRIVE_OVER` or either platform answer. *Verify:* the `"Aim"`
   branch, and the spec case *"asks the licence question and nothing else about the aim"*.

5. **A forged aim is refused on the trigger's own terms.** `Validator.checkRequest` whitelists
   `"Aim"` with no ammo; the ray goes through the same `Validator.checkShot` with the same origin
   tolerance. *Verify:* the spec cases *"is on the whitelist, carries no ammo, and no other new
   string is"* (every reducer primitive still refused) and the `not-unit` arm of claim 3's case.

6. **No second purchase writer, at either end.** The card calls `ShopPanel.press` (the client's one
   firer of `ShopRequest`); the server path is `Shop.onRequest` → `Economy.purchase` →
   `Economy.grant`, untouched. *Verify:* `grep -rn "ShopRequest:FireServer" src/client/` finds two
   lines, both in `ShopPanel`; `LicenceCard` holds no remote at all.

7. **The reach exception is one row and one branch, and I13 makes it structural.** `Row.anywhere` is
   read only in `Shop.refuse`'s `TOO_FAR` branch; `Shop.anywhereProblems` (invariant I13, called from
   `rowsOk`) refuses it on any row granting more than a licence, on a package, and on any value but
   `true`. *Verify:* the four cases under *"the deer licence may be bought away from the counter"* —
   including that every OTHER sellable row is still refused `too-far` at the same spot (harness note:
   `11 sellable rows still need the counter`), that every other rule is still asked of the licence
   row at both distances, and the live `Economy.purchase(..., { atCounter = false })` granting it,
   debiting once, and still refusing a high seat at the same spot.

8. **The Robux switch is built, both branches drive by parameter, and nothing is live.** Every
   shipped row's `robuxProductId` is nil (I12). `Shop.robuxProductFor` / `Shop.itemForProduct` are
   pure and take `rows`; `ShopPanel.payWith` is the client branch; `Economy.processReceipt` is the
   grant, through `Economy.grant(..., SOURCE.ROBUX)`, installed on `MarketplaceService.ProcessReceipt`
   by `Economy.start` **outside Studio only**, so no spec writes the service; `Shop.REASON.ROBUX_ONLY`
   shuts the coin till on a Robux row, before every money question. *Verify:* the five cases under
   *"the Robux switch"* and *"the Robux switch, on the client"*, including the redelivered receipt
   answering `GRANTED` with `store.calls().save == 1`. Harness note:
   `robux receipts=6 granted=2 already=1 unknown=3 notProcessed=1`.

9. **No `PurchaseId` ledger, and the limit is stated.** The entitlement SET is the record — already
   `docs/design/economy-v1.md`'s reviewed decision, and strictly stronger for a non-consumable,
   because there is no window between the grant and the record of the grant. The note's §3.5 and
   `Economy.processReceipt`'s header both say in as many words that this holds for non-consumables
   ONLY and that a coin pack would need the ledger; no row grants one (`Shop.GRANT_FIELDS` has no
   `coins` field, and I13 is what keeps the `anywhere` half of that true).

10. **Born dark, and both arms reachable.** `LICENCE_POPUP` `default = false`, expires 2026-11-12,
    read once at `LicenceCard.ENABLED` and overridable by `start`'s `enabled`. *Verify:*
    `tests/client/licence_card.spec.luau`, *"is born OFF in git, and the ON arm is reachable by
    parameter"*. The server half is deliberately NOT behind it, and the module header says why.

## Rule 5 — and what the frame caught that 533 green assertions did not

`.screenshots/20261022T010608Z-238-card-dev.png` (before) and
`.screenshots/20261022T011316Z-238-card-dev-after.png` (after), both looked at. The first showed
**three defects no spec had**:

* the close button was laid out by the `UIListLayout` as a fifth row, in the top LEFT, over the title;
* **neither button was connected to anything** — `press` and `hide` were public spec seams and no
  `Activated` was ever wired, so a real player could neither buy nor dismiss;
* the hint read *"Esc or wait"*, and **Escape is not bound and cannot be** (it belongs to the Roblox
  menu, as `ReportPanel.bind`'s own comment states).

All three fixed in `33158586`, with three new cases. Fixing the second exposed the interaction
problem behind it: in first person `Camera.Cursor` locks the mouse to the centre, so a `GuiButton`
receives no click — which is why `Hud.Rail`'s buttons carry key chips and `MapUi` is `M`. The card
binds `B` (free; the fifteen KeyCodes bound anywhere in `src/` are Backspace, E, M, R, Tab, X,
Return, four arrows and four gamepad buttons) **only while it is up**, unbound by `hide` and by
`stop`, returning `Pass` so it swallows nothing.

## What could not be verified

* **The price on the card, in a picture.** Both frames read `BUY  ...`. That is the truth about DEV
  rather than a defect: task 235 (L-095) means a world with no counter wires no shop, so no
  `ShopState` ever reaches a DEV client and the card prints the word and no amount rather than a
  guessed number. The price path is proved by parameter (`BUY  $750`, off the server's own
  `WireRow`, in *"prints the server's own price and never a guessed one"*). `ESCALATE.md` item 3
  offers the Forest Test capture if the Director wants the picture with the number in it.
* **A tap or a click.** `GuiButton.Activated` cannot be synthesised and the harness cannot fake a
  tap, so `LicenceCard.press` is the seam — `ShopPanel.press` and `Rail.press`'s own stated limit.
  What is proved is the ACTION, not the touch.
* **A real deer in the ray, in the photographed session.** The card was made visible by a plain
  property write in a live Play client (`<runs-dir>/238-card-show.luau`) in order to photograph it.
  The aim → advice → card chain is proved at the server end by claim 3's live handler case and at
  the client end by the `onAdvice` cases.
* **The published snapshot, read from the server.** `StateChanged:FireClient` goes to the player's
  own client, so the server spec's observable is `Weapon.stats().aimAdvised` — incremented on exactly
  the publish line — plus the snapshot-shape case that pins what that publish contains. Said in that
  spec's own comments.
* **The Robux prompt itself.** No developer product exists (task 222 needs Karen's Creator
  Dashboard), so `PromptProductPurchase` is never called in this build and
  `ShopPanel.stats().prompted` is 0 — which the client spec asserts.

## Not done, and said so

**The "WHAT TO SHOOT" card's deer rows.** The dispatch says *"if that card is interactive; otherwise
skip that half and say so"*. Measured: `StartRowParts.row` is a `Frame`, every row is built by
`Style.tableRow`, and there is no `TextButton`, no `Activated` and no cursor anywhere in the start
card. **It is not interactive**, so this half is skipped. It is also a countdown that exists only in
the intermission phase, so making it interactive is a task of its own.

## Three NEEDS DIRECTOR, in `ESCALATE.md`, none blocking

1. The dispatch's *"costs points"* premise versus the shipped, twice-Karen-approved refusal (L-073).
2. `Flags.MAX_FLAGS` 14 → 15, because retiring the TASKS.md 82b rows is the Director's call and
   shipping a new feel-critical path LIT is what `feature-flags.md` §11 step 1 forbids.
3. One Forest Test capture, if he wants the price in the picture.

**And a delta reported rather than patched** (L-071; the Builder does not own `docs/design/`):
`docs/design/shop.md` §10.4 still reads *"every purchase in the DEV place is refused `too-far`"*. It
is now both stricter than that (task 235: the shop is not wired there at all) **and looser** (task
238: the deer licence is never refused `too-far`, anywhere). Queued for the Architect.
