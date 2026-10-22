# The "no licence" popup, and buying from it (task 238)

Karen, 2026-10-21, verbatim: *"if you dont have a license when you aim and what to shoot it shows
popup you dont have license and then you want to buy and roblox popup like they do to purchase"*.

## 1. What the system must do

1. **Tell the player, at the moment he aims at a red deer he may not shoot, that he has no licence.**
   Once per aim-on, with a cooldown; never every frame.
2. **Sell him the card from that popup, away from the lodge.** Through the SAME server purchase path
   the shop counter uses — one writer of a purchase (CLAUDE.md rule 3).
3. **Be ready for Robux without being live on Robux.** A product-id row, nil today; when it is set,
   the button calls Roblox's purchase prompt and the grant happens only in the server's
   `ProcessReceipt`.

### 1.1 THE PREMISE OF THE DISPATCH IS WRONG, AND THIS IS THE MEASUREMENT (Learning Agent L-073)

The dispatch says the popup's second line should read *"shooting a deer without it costs points"* and
that the popup must *"never block shooting: it is advice"*. **Neither sentence describes the shipped
game.** Measured, not argued:

* `Weapon.Rules.REASON.LICENCE = "no-licence"` and `Rules.NOTICE[LICENCE] = "NO LICENCE"`
  (`src/server/Weapon/Rules.luau`).
* `Rules.ORDER` asks it last of six, and `Rules.refuse` returns it when `Rules.unlicensed(target,
  held)` answers true.
* In `src/server/Weapon/init.luau`'s `onFireRequest`, a non-nil `refused` **publishes `state` and
  not `fired` and returns before `setState`**. Its own comment: *"`fired` IS NOT KEPT WHEN A GATE
  REFUSES... no shell spent, no barrel moved, no bolt started, no `ShotFired`, no pellet cast, no
  `SafetyViolated`, no hit"*, and *"**No punishment — Karen asked for none, twice**"*.
* `CameraBoot.client.luau` turns `snapshot.refused` into exactly one dry click
  (`Weapon.Sound.dry`); the Hud prints the server's `notice`.

So: **shooting a deer without the licence is already impossible, costs nothing, and says "NO
LICENCE" on a dry click.** It does not cost points. Karen asked for no punishment twice, and the
`grep` for `Rules.REASON.LICENCE` finds no penalty, no score write and no `Match.Penalty` call.

**What is built here, and the assumption it is built under.** The popup's copy says what the game
actually does — *"you cannot shoot red deer without it"* — and **nothing in this task un-blocks the
shot or adds a points cost.** Writing the dispatch's sentence would be the shop window lying, which
is the failure `Shop.Row.blurb`'s own header refuses (*"a shop window that invents a ballistic claim
is a shop window that lies"*). Changing the rule to match the dispatch's sentence would overturn a
mechanic Karen asked for twice, which is not a Builder's call. **The Director decides which of the
two he meant; `ESCALATE.md` carries the entry.** The popup is advice in the only sense that is true
of it: *it* blocks nothing, adds no rule, and the gate it explains was already there.

### 1.2 "NEVER BLOCK SHOOTING" IS STILL HONOURED, IN THE HALF THAT IS THE POPUP'S TO HONOUR

The popup takes no input focus, grabs no cursor and goes through no `Input.requestHold`. A player
who ignores it keeps aiming and keeps pulling the trigger, and the trigger does exactly what it did
before this task. That is the testable half of *"it is advice"*, and
`tests/client/licence_card.spec.luau` asserts it.

## 2. External sources

| # | Source | Licence | Maintained | Does well | Does badly |
|---|---|---|---|---|---|
| 1 | **Roblox — `MarketplaceService.ProcessReceipt`** · [API reference](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService) · source repo [Roblox/creator-docs](https://github.com/Roblox/creator-docs) | prose **CC BY 4.0**, code samples **MIT** ([LICENSE](https://github.com/Roblox/creator-docs/blob/main/LICENSE), [LICENSE-CODE](https://github.com/Roblox/creator-docs/blob/main/LICENSE-CODE)) | **Active** (first-party, open-source, continuously updated) | States the contract and the hazard in one place: the callback is retried *"until it returns `Enum.ProductPurchaseDecision.PurchaseGranted`"*, including on the player's next join; the sample's own comment is *"prevent double-granting when the same receipt is delivered to multiple servers"* and *"The purchase is now granted to the player, so record it as granted"* — i.e. **record before returning granted**. `NotProcessedYet` means "retry me later" | The sample keeps a **per-player `DataStore` list of processed `PurchaseId`s** — a second store of a fact we already hold. The prose page [developer-products.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/monetization/developer-products.md) **does not mention idempotency at all** and says only *"must return `true`"*: a creator who reads the guide and not the API page ships the double-grant |
| 2 | **Roblox DevForum, two threads filed against the official sample.** [Thread 3563250](https://devforum.roblox.com/t/3563250) — *"Logic Error in the ProcessReceipt Example Code will cause player to get the same paid items with every server join after purchase"* — and [thread 2021619](https://devforum.roblox.com/t/2021619) — *"MarketplaceService ProcessReceipt code sample robs players of money"*. (The slugs are left out of the URLs on purpose: `tools/privacy_scan.py` reads a 120-character unbroken run of base64url as a possible Open Cloud key, and the first slug is one.) | forum posts, no licence stated — **read for the failure modes, no code taken** | **Active** (filed against the live docs; the sample has been revised more than once) | The two ways the official sample has been wrong *in opposite directions* — re-granting on every join, and eating the charge — which is the whole argument for keeping the grant idempotent in the OWNER rather than in a ledger beside it | Anecdotal, unversioned, and the "fixes" posted in the replies disagree with each other. Nothing here is authoritative |
| 3 | **"ProcessReceipt and the Two-State Problem"** · [article](https://codermitchell.com/writing/processreceipt-two-state-problem/) | article, no licence stated — **read for the analysis, no code taken** | **Unknown** (undated personal site) | Names the shape of the bug precisely: the grant and the record of the grant are two states, and the window between them is where every double-grant and every eaten charge lives. Says plainly *"you return `PurchaseGranted` only after you've successfully handed over the goods"* and that a failure must return `NotProcessedYet` | One author, no review, no tests. The conclusion it reaches (keep a ledger) is the one we refuse below, for a reason it does not consider |
| 4 | **Contextual / point-of-need upsell** · [In-App Upsell Popups: Design + 10 Examples](https://flook.co/blog/in-app-upsell-popup-design) · [What is Contextual Upselling?](https://www.salesmate.io/blog/upselling-guide/) | articles, no licence stated — **read for the pattern, no code or asset taken** | **Active** (both updated 2026) | The pattern and its three parts, which is exactly the card built here: *"a headline that states the offer, benefit text that explains why they should care, and a CTA that tells them what happens next"*, shown *"contextually when users hit limits or try to access locked functionality, making the upgrade feel helpful"*. The trigger it names — *"tries clicking on greyed-out features"* — is our aim at an animal the gate refuses | SaaS and e-commerce, not games: it has nothing to say about a popup appearing while a player is holding a gun, and its advice on frequency (*"display at the right moment"*) is not a number. The cooldown is ours and is stated in §5 |

## 3. The pattern adopted, and why

### 3.1 The trigger: ONE targeting path, the server's, asked at aim-on

**Measured first (the dispatch's own instruction: *"measure and reuse, do not invent a second
targeting path"*):**

* `grep -rn "Raycast" src/client/` finds **three** casts, and none of them is a targeting ray:
  `Camera/Rig.luau`'s occlusion cast, and two comments. **The client has no idea what the player is
  aiming at, and never has.**
* The only targeting path in the game is on the SERVER, inside `onFireRequest`: `castFn(req.origin,
  req.direction * range, ignore)` → `askTarget(aimImpact.instance)` → `Rules.unlicensed`. It runs
  **once per trigger pull** and never otherwise.

So "show a popup when he AIMS" cannot be served by any existing signal, and a client-side ray would
be the second targeting path the dispatch forbids — and a second answer to *"what is in front of the
gun"*, which is `PROJECT_CONTEXT.md`'s named failure (*"Two systems wrote the creature's
position"*).

**Adopted: the client ASKS and the server ANSWERS, through the machinery that already exists.**

* `Input.setAim(true)` — already the one owner of the aim flag, already the only firer of
  `ActionRequest` — sends one `ActionRequest("Aim", nil, {origin, direction})` on the rising edge,
  behind its own cooldown.
* `Weapon.onActionRequest` gains one `kind`. It calls the **same** `castFn`, the **same**
  `askTarget` and the **same** `Rules.unlicensed` the trigger calls, through one new local
  (`adviseFor`) that `onFireRequest`'s gate and this both reach. No new remote, no new rule, no
  second cast implementation.
* The answer travels on the snapshot the client already receives, in **one new field**.

**It asks `Rules.unlicensed` and NOT `Rules.refuse`.** The narrowest of the six questions, and the
only one this popup is about. `Rules.refuse` would make the aim query answer *"NOT IN YOUR STAND"*
and *"NOT AT A BEATER"* too — five answers nothing on screen is built to receive, and a second
reader of an order that is `Rules.ORDER`'s to own.

### 3.2 `advice`, NOT `refused` — and this is the one thing that would have shipped a bug

`snapshot.refused` is **already wired to a sound**: `CameraBoot.client.luau` plays `Weapon.Sound.dry`
on every arriving snapshot whose `refused` is a string, and its comment explains that the server sets
the field *"on exactly the refusal publish — so one refused trigger pull is one click"*. Publishing
the aim answer in `refused` would make **merely aiming at a deer click the gun dry and print "NO
LICENCE" on the readout** — a trigger pull the player never made.

So the new field is `advice`: *"the gate that WOULD refuse you"*, as against `refused`, *"the gate
that DID refuse the trigger you pulled"*. Different fact, different field, no reader of either
changes.

### 3.3 The buy: the SAME door, with the reach rule relaxed BY ROW

`ShopPanel.press(id)` → `ShopRequest:FireServer{kind = BUY, item = id}` → `Shop.onRequest` →
`Economy.purchase` → `Economy.grant`. **The popup adds nothing to that chain**; it calls
`ShopPanel.press`, which is already *"the one firer"* on the client, and the server path is byte-for-
byte the counter's.

The one thing in the way is the reach rule. `Shop.refuse`'s `TOO_FAR` branch refuses any purchase
with `atCounter == false`, and a drive is 700 studs from the lodge.

**Adopted: `Row.anywhere`, a field on the catalogue row, read in that one branch.** Not a flag on
the request (a client could forge it), not a second entry point (two writers), not a parameter from
the popup (then the popup decides a rule). The row says of itself whether it needs the counter, the
one pure function that already owns the reach question reads it, and `rowsOk`'s new invariant **I13**
makes the exception structural rather than a habit: *a row with `anywhere = true` must grant a
licence and nothing else.*

**Why that is safe, stated for review (the dispatch asks):**

1. **A licence is permission, not an object.** `grants.licence` is read by `Shop.licencesFor` →
   `Weapon.setLicenceProvider` → `Rules.unlicensed`. It hands the player no Tool, no ammo, no hat,
   no seat and no roster place — nothing appears in his hands or in the world. Every other row in
   the catalogue grants something that does (`weapon`, `ammo`, `driveGun`, `hatColor`, `highSeat`,
   `unlimitedAmmo`, `alwaysHunter`), and **I13 refuses `anywhere` on every one of them.**
2. **No rule is weakened.** The coins, the hunt gate, the ownership guard, the profile and the
   `sale` flag are all still asked, in `Shop.ORDER_OF_REFUSAL`, by the same pure function, on the
   server. `TOO_FAR` is the only question that changes its answer, and only for a row that says so.
3. **The counter is a place, not a permission.** Its purpose is that the lodge's shop should be
   somewhere you go — a *feel* rule. A licence bought mid-drive is the one case where going there is
   impossible by construction: the lodge is 700 studs away and the drive is on.
4. **It is measurable and measured.** `shop.spec` asserts `anywhere` is true on exactly one row and
   nil on every other, and that the same purchase that is refused `too-far` for `access.highseat` is
   granted for `licence.reddeer`.

### 3.4 The Robux switch: `robuxProductId`, and the branch is on the CLIENT, the grant on the SERVER

**`Shop.Row.robuxProductId` already exists** (task 221, `src/shared/Shop/init.luau`), with
`rowsOk`'s **I12** asserting a non-nil one is a positive integer and **every row's is nil today**,
and with the reason written down: *"there are no products yet, and a fabricated id is a shop window
that lies"*. `docs/design/economy-v1.md` §11 planned exactly this task:
*"The Robux door (task 222) will be `ProcessReceipt` → `grant(..., Economy.SOURCE.ROBUX)`"*, and
`Economy.SOURCE.ROBUX` is already in the enum with `grantsBySource` already counting it.

So the switch is **wiring that was designed for, not invention**:

* **nil (today):** `ShopPanel.press` sends the coin BUY. Exactly what ships now.
* **set:** `ShopPanel.press` calls `MarketplaceService:PromptProductPurchase(player, id)` and sends
  **no** coin BUY. The prompt is called from the client because that is where the docs' own sample
  calls it (source 1).
* **and the coin till refuses it either way.** A new reason, `ROBUX_ONLY`, in
  `Shop.ORDER_OF_REFUSAL` immediately after `NOT_SALE`: a row with a product id cannot be bought
  with coins, so a forged `ShopRequest` cannot take the $ price for a thing Karen priced in Robux.
  Without it both doors would be open the day she sets an id.
* **the grant happens in `ProcessReceipt` and nowhere else.** `Economy.processReceipt(receiptInfo)`
  maps `ProductId` → `itemId` through the pure `Shop.itemForProduct` and calls `Economy.grant(userId,
  itemId, Economy.SOURCE.ROBUX)` — the one writer of the owned set, which performs the one
  `store.save`. It returns `PurchaseGranted` only when the grant answered `ok`, and
  `NotProcessedYet` otherwise (no session, unknown product, closed economy), which is source 1's and
  source 3's contract: *"you return `PurchaseGranted` only after you've successfully handed over the
  goods"*.

**Both branches are driven by parameter and not by a row**, because every shipped row's id is nil and
I12 keeps it that way: `Shop.robuxProductFor(itemId, rows)` and `Shop.itemForProduct(productId,
rows)` take the table, the idiom `Licences.required(species, rows)` already ships.

### 3.5 BORROWED, NOT INVENTED — and the one thing we refuse (rule 2)

**Refused: the per-`PurchaseId` DataStore ledger** of source 1's sample, source 2's threads and
source 3's conclusion. The reason is already written in `docs/design/economy-v1.md` (source 1's row
in its own table) and in `Economy.grant`'s header, and this task does not get to overturn it:

> *"An entitlement SET is naturally idempotent, which is why no receipt-id ledger is kept: granting
> a row twice is the same set, and a second store of the same fact is the thing this owner exists to
> avoid."*

**And for a licence that is not a shortcut, it is strictly stronger.** The ledger exists to stop a
double grant. For a **non-consumable** entitlement there is nothing to double: `Economy.grant`
already answers `{ok = true, already = true}` and writes nothing when the row is in the set, which is
the exact shape `ProcessReceipt` needs for a redelivered receipt — a success, so Roblox stops
retrying, with no second charge and no second write. The ledger's own failure mode (source 2: *"the
same paid items with every server join"*) is a window between the grant and the record of the grant;
with the set AS the record there is no window, and `Economy.grant` *"never yields"*.

**THE LIMIT, STATED: this holds for non-consumables only.** The day Karen sells a **coin pack** for
Robux — a consumable, where granting twice really does double the goods — the set is no longer the
record and a `PurchaseId` ledger becomes necessary. Nothing in this task sells one (`Shop.ITEM` has
no coin pack and `Shop.GRANT_FIELDS` has no `coins` field at all, so no row CAN grant one), and the
invariant that actually holds the line today is **I12**, which refuses any non-nil `robuxProductId`
outright — so no row is sold for Robux in this build at all. (An earlier draft of this paragraph
claimed I13 checked the product id; it does not — `Shop.anywhereProblems` reads `anywhere`, `grants`
and `covers` and never `robuxProductId`. The Reviewer caught it, round 1.) This is written here, in
`Economy.processReceipt`'s header, and in the task report, because it is the one thing that would
make this design wrong later: **the day a consumable is sold for Robux, I12 has to come off, and the
`PurchaseId` ledger has to go on in the same commit.**

## 4. One owner per system (rule 3)

| Question | Owner | Where |
|---|---|---|
| what is in front of the gun | `ServerScriptService.Weapon` | `castFn` + `askTarget`, one implementation, reached by the trigger and by the aim query |
| may he shoot this species | `ServerScriptService.Weapon.Rules` | `Rules.unlicensed`, unchanged |
| is there a Robux product for this row | `ReplicatedStorage.Shop` | `Shop.robuxProductFor` / `Shop.itemForProduct`, pure |
| may he buy it at all | `ReplicatedStorage.Shop` | `Shop.refuse`, pure — `anywhere` and `ROBUX_ONLY` are two more questions in its one order |
| the owned set | `ServerScriptService.Economy` | `Economy.grant`, still the only writer, now reached from `purchase` (coins) and `processReceipt` (Robux) |
| sending a purchase from the client | `StarterPlayerScripts.Hud.ShopPanel` | `ShopPanel.press`, still the only firer; the Robux branch is inside it |
| drawing the popup | `StarterPlayerScripts.Hud.LicenceCard` | new, and it decides nothing: it draws what it is handed and calls `ShopPanel.press` |
| when the popup appears | `StarterPlayerScripts.Hud.LicenceCard` | `LicenceCard.onAdvice`, pure edge + cooldown |

## 5. Numeric targets

| Thing | Number | Why that number |
|---|---|---|
| aim-query cooldown, client | **1.5 s** | A player shoulders and un-shoulders constantly. 1.5 s is longer than any deliberate double-tap and shorter than the time to re-aim at a new animal. It costs at most 0.67 `ActionRequest` per second against `CONFIG.ACTION_RATE_LIMIT`, so it cannot crowd out a reload |
| popup re-show cooldown | **12 s** | Long enough that a man working a line of deer is told once and not nagged; short enough that the next drive's first deer tells him again. Source 4 has no number; this is ours and is Karen's to retune |
| popup auto-hide | **7 s** | The hit card's own order of magnitude, and it is *advice*: it must leave the screen without a click |
| popup width | **300 px** | `PadPanel`'s measured width, which is what fits the 400 px phone `hud_clarity.spec` asserts |
| server cast per aim query | **1** | The same one `onFireRequest` makes, at the same range |

## 6. What could go wrong

| # | Hazard | What stops it |
|---|---|---|
| 1 | the aim query clicks the gun dry | `advice` is a different field from `refused`; no reader of `refused` changes. `licence_popup.spec` asserts the advice publish carries `refused == nil` |
| 2 | a forged `ActionRequest("Aim", …)` becomes a free targeting oracle | `Validator.checkRequest` whitelists the kind and `Validator.checkShot` validates the ray with the SAME origin tolerance the trigger uses; the answer it can get back is one of `Rules.REASON` about an animal already standing in plain sight, and it is spent against `ACTION_RATE_LIMIT` |
| 3 | the popup takes the player's input and he cannot shoot | it never calls `Input.requestHold` and its button is not modal. `licence_card.spec` asserts `Input.isHeld()` is false while it is open |
| 4 | coins are taken for a Robux row | `ROBUX_ONLY`, asked before the money questions in `Shop.ORDER_OF_REFUSAL`, and driven by `Shop.Context.rows` in `licence_popup.spec` (the seam was added in round 1: the Reviewer found this gate reachable by no test) |
| 5 | `ProcessReceipt` grants twice | `Economy.grant` is idempotent by the set and returns `already = true`; §3.5 states the non-consumable limit, and **I12** is what keeps it true today by refusing any non-nil product id at all |
| 6 | the popup shows a price it invented | it draws `ShopPanel.rowFor(id).price`, the server's own `WireRow`, and shows no amount at all until one has arrived |
| 7 | the popup appears in a world where nothing can be bought | **The flag is not enough and round 1 proved it**: `ShopPanel.isEnabled()` reads the `SHOP` FLAG, which is a lit v1 default since task 233b, so it answers `true` in the DEV place where `Shop.start` returned false for want of a counter. The fact that IS true of such a world is that **no `ShopState` ever arrives** -- `Shop.start` returns false without setting `started`, so `Shop.onRequest` replies to nothing. The card therefore shows only once it holds a `WireRow`: no wallet, no card (`suppressedNoWallet`), and an advice that asked for one is picked up by `onShopState` within `PENDING_SECONDS` |

## 7. What this note does NOT cover

* **The "WHAT TO SHOOT" card's deer rows.** Measured: `StartRowParts.row` is a `Frame`
  (`src/client/Hud/init.luau`), every row is built by `Style.tableRow`, and there is no
  `TextButton`, no `Activated` and no cursor anywhere in the start card. **The card is not
  interactive**, so the dispatch's *"otherwise skip that half and say so"* applies. Making it
  interactive is a separate task: the card is a countdown that lives only in the intermission phase.
* **Karen's developer product.** It does not exist (task 222 needs her Creator Dashboard). Every
  row's `robuxProductId` stays nil and I12 still asserts it.
* **Re-pricing.** 750 coins is Karen's figure and is untouched.
