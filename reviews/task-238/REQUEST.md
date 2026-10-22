# Task 238 — the "NO DEER LICENCE" popup, buying from it, and the Robux switch

Task: 238
Round: 2
Base: `ffb4dfed` (merge of PR #216, task 235)
Code commit: `74718912d0416e7c039634f33759e43a5ccf176a`

```
[harness] PASS: 34/34 checks @ 74718912d0416e7c039634f33759e43a5ccf176a (clean tree) scope=all
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

## Round 1's three blocking findings, and what each cost

All three were right, and all three were the same class of fault: **a gate that no test could
reach, with a comment claiming it could.**

1. **`ROBUX_ONLY` was driven by nothing, and the comment promised a seam that did not exist.**
   `Shop.Context` now HAS `rows` — resolved in one new local, `rowFor` — and no production caller
   passes one, so every shipped path still reads the frozen catalogue through `Shop.row`. New case:
   *"really refuses a coin BUY for a Robux row, and only for one"* — the same row with and without a
   product id, beating every money question and losing to `NOT_SALE` above it.

2. **The "world with no shop" guard did not work, in the one world it mattered.**
   `ShopPanel.isEnabled()` reads the `SHOP` FLAG — a lit v1 default since 233b — so it answers
   `true` in DEV, where `Shop.start` returned `false` for want of a counter. The card would have
   shown with no price and a BUY reaching a `Shop.onRequest` that returns nil. **The fact that IS
   true of such a world is that no `ShopState` ever arrives**: `Shop.start` returns false *without
   setting `started`*, so the door replies to nothing. The card now shows only once it holds a
   `WireRow`; an advice with no wallet asks once and is picked up by `onShopState` within
   `PENDING_SECONDS` (4 s), so a player who has never visited the lodge still gets the card on the
   aim that asked for it, with the real price on it.

3. **The client Robux arm spent real money and was undrivable, and `payWith` had no caller.**
   `ShopPanel.press` now ASKS `payWith` — one pure answer to "which currency", one caller — both
   take the same optional `rows`, and the service is injected through `ShopPanel.setMarketplace`
   (the seam `Economy.start`'s `world.marketplace` already is). New case drives the **real `press`**
   down the Robux arm and asserts it prompts with THIS player and THAT product **and that no coin
   BUY went with it**.

Four of the non-blocking notes were comments that said more than the code did, and are corrected
rather than queued, because a false comment is the same defect in prose: `lookAhead`'s header named
an `onAimRequest` that never existed; the note and `Economy.processReceipt` credited I13 with
guarding `robuxProductId` when **I12** is what does; the Hud claimed `Weapon.Changed` fires exactly
once per arriving snapshot, when the payload is the HELD weapon so an unequip can re-deliver it
(harmless — `REPEAT_SECONDS` bounds it, and `suppressedRepeat` counts it); and the `ProcessReceipt`
install sits below the `not enabled` return, which is now said where the limit is. The live handler
case also names which arm ran in its note, so the fallback cannot be read as the real one.

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
   the barrel, `open`, `shots` and `refused` are unchanged. The case has a fallback arm for a run
   where nobody holds a loaded gun, and since round 2 **the note names which arm ran**, so the
   fallback cannot be read as the real one. This run: `licence_popup: LIVE HANDLER DRIVEN --
   Alhamdulilah824 questions +2 advised +1 shots +0; barrel Live -> Live`.

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
   shuts the coin till on a Robux row, before every money question. *Verify:* the cases under *"the
   Robux switch"* and *"the Robux switch, on the client"* — including the redelivered receipt
   answering `GRANTED` with `store.calls().save == 1`, the round-2 case that drives the refusal
   itself through `Shop.Context.rows`, and the round-2 case that drives the real `ShopPanel.press`
   down the prompt arm. Harness notes:
   `robux receipts=6 granted=2 already=1 unknown=3 notProcessed=1` and
   `the ONE prompt in this run went to the spec's stub, not to Roblox -- prompted=1, sent=2`.

9. **A world where nothing can be bought gets no card, and the FLAG is not what says so**
   (round 2). `onAdvice` suppresses on having no `WireRow` (`suppressedNoWallet`), which is exactly
    the DEV place: `Shop.start` returns false without setting `started`, so no `ShopState` is ever
    sent. *Verify:* `tests/client/licence_card.spec.luau`, *"stays down for a man who already owns
    the card, and in a world with no shop"* — four aims past the cooldown, `shown == 0`,
    `suppressedNoWallet == 4`, one `ask` — and *"waits for the wallet, then goes up on the reply
    with the real price"* for the other half, including the `PENDING_SECONDS` timeout.

10. **No `PurchaseId` ledger, and the limit is stated.** The entitlement SET is the record — already
   `docs/design/economy-v1.md`'s reviewed decision, and strictly stronger for a non-consumable,
   because there is no window between the grant and the record of the grant. The note's §3.5 and
   `Economy.processReceipt`'s header both say in as many words that this holds for non-consumables
   ONLY and that a coin pack would need the ledger; no row grants one (`Shop.GRANT_FIELDS` has no
   `coins` field, and I13 is what keeps the `anywhere` half of that true).

11. **Born dark, and both arms reachable.** `LICENCE_POPUP` `default = false`, expires 2026-11-12,
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

* **The price on the card, in a picture.** Both frames read `BUY  ...` — and **since round 2 that
  state is not reachable on screen at all**: no `WireRow` now means no card, which is finding 2's
  fix. The frames were taken before it, by a plain property write, and they are still the evidence
  for the LOOK (the panel, the title, the sentence, the button, the close, the hint); the amount on
  the button is the one thing in them that the shipped code would no longer draw that way. **No
  frame of the card with a price exists**, because the only world with a counter is Karen's Forest
  Test and only DEV was open. The price path is proved by parameter (`BUY  $750`, off the server's
  own `WireRow`). `ESCALATE.md` item 3 offers the Forest Test capture if the Director wants it.
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
