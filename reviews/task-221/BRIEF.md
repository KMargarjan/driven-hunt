# BRIEF -- Task 221: money in dollars, and the v1 shop catalogue

The input to an Architect **design** run (`tools/architect.sh design economy-v1 --task 221`).
Written by the Builder, carrying the Director. Per `docs/ARCHITECT_PROMPT.md` this file is read
first and **overrides anything older** in `docs/`, `TASKS.md` or an earlier design.

---

## 0. Karen, 2026-10-20 ~08:30, verbatim

> "We need to change coins to actual money $ / From shop remove red heat / It will be for sale in
> v1: - Access to tree stand - Rifle - Unlimited amunition - Red stag card - Beater can shoot in
> drive - Posibility to be a hunter always - We can also make a few packages bundles"

Two earlier lines of hers that bound the prices, and are not up for revision here:

> 2026-10-10: *"They will have posibility to purchase rifle but has to play a lot it's not few
> hunts"*

> the Director, carrying her: *"need to buy is the key ... everything buyable with Robux is also
> earnable by play"*

---

## 1. What this task is, in one paragraph

The economy already works: `ServerScriptService.Economy` owns the profile, `ReplicatedStorage.Shop`
is the catalogue and the pure refusal, `ServerScriptService.Shop` is the door, and
`Hud`/`ShopPanel` draw it. **Nothing in that structure is being replaced.** Three things change:
the currency is **shown** as money with a `$`; the red hat **leaves** the shop; and the catalogue
becomes **Karen's v1 list** -- which means **four new entitlements** (high-seat access, unlimited
ammunition, the red stag card, always-hunter), **two kept** (the scoped rifle, the beater licence),
and **bundles**. Each new entitlement is read by an owner that already exists, through the seam
that owner already has. The design's job is to say exactly which seam, and to settle the eight
open decisions in section 8.

---

## 2. Decisions already taken (the Director's; the design implements them, it does not reopen them)

### D1. The currency is MONEY with a `$` everywhere a player sees it; the saved record keeps its key

`$` and the word MONEY replace "coins" on the **top bar**, the **results board**, the **shop
panel**, **toasts and notices**. **Internally nothing is renamed**: the profile field stays
`coins`, `coinsEarnedTotal` stays, `Economy.CONFIG.COINS_PER_POINT` stays, the snapshot row field
stays `coins`, `Hud.BOARD.COLUMNS.coins` stays, `Economy.STORE_NAME` stays
`DrivenHuntPlayer_v1`. **There is no data migration and there is no rename sweep** -- a rename of a
persisted key is the one change that can destroy a live profile, and a rename sweep across 30+ call
sites is the failure mode lesson L-030 names. The design says this out loud so the next reader does
not "finish the job".

**It follows that the display word and the display format need ONE owner and one formatter**, read
by the Hud and by the shop panel, so that a `$` can never appear in one and not the other. Today
the results board's column head is `string.upper(key)` -- it prints the literal field name -- so
that derivation has to go.

### D2. The red hat leaves the shop, and an owner keeps it

`Shop.ITEM.HAT_RED` is off the shelf. Archived under `backups/` with a note (rule 7), as
`backups/2026-10-16_task-196_shop-rifle-open-row.md` already did for the open-sight rifle.

**Anyone who owns it keeps it.** That is a requirement and not a courtesy: the id is already in
live `owned` sets, and today `Shop.hatColorFor` reads the hat out of `Shop.ORDER` -- so deleting
the row would silently turn a bought hat back to orange. The design must name the mechanism that
keeps a retired row readable by the four "what ownership gives" readers (`Shop.startFor`,
`Shop.grantsDriveGun`, `Shop.hatColorFor`, `Shop.ownsWeapon`) while it is **invisible to the panel
and unbuyable at the door**. The Builder's candidate, for the Architect to accept or better: a
frozen `Shop.RETIRED` table plus a second order `Shop.ALL_ORDER` (= `ORDER` then retired) that
those four readers iterate, while `Shop.ORDER`, `Shop.rowsFor` and the purchase path keep reading
`Shop.ORDER` alone.

### D3. The v1 catalogue is exactly Karen's list

Seven items plus bundles. The slug stays (it is the second rung of the ladder she accepted on
2026-10-10 with *"yes that seems legit"*, and she did not ask for it to go; only the hat did).

| id | label | what it grants | state |
|---|---|---|---|
| `ammo.slug` | SLUG SHELLS | `ammo = "Slug"` | **exists, unchanged** |
| `licence.beater` | BEATER LICENCE | `driveGun = true` | **exists, unchanged** -- Karen's *"Beater can shoot in drive"* |
| `rifle.scoped` | RIFLE, SCOPED | `weapon = "rifle"` | **exists; its unlock rule is KEPT** (see D4) |
| `access.highseat` | **NEW** | the high seats of task 218 | see D5 |
| `ammo.unlimited` | **NEW** | the 12-shells-per-drive rule does not apply | see D6 |
| `licence.reddeer` | **NEW** RED STAG CARD | `licence = "reddeer"` | **shown, NOT buyable** (see D7) |
| `role.alwayshunter` | **NEW** | never rotated to beater | see D8 |
| bundles | **NEW** | 2-3 packages of the above, at a discount | see D9 |

### D4. The rifle keeps its unlock rule

`hunts = 25` stands. It is Karen's own *"has to play a lot it's not few hunts"* expressed as the
only mechanism the shop has for it, and `Economy.CONFIG.TEST_GRANT.hunts` is already 25 so she can
still reach it in a playtest. **Do not drop it, do not move it.**

### D5. HIGH-SEAT ACCESS -- task 218's high seats become a paid privilege

Karen's *"Access to tree stand"*. Task 218 built a wooden Hochsitz at some stands of each drive
place (`HighSeats.STANDS`: road {1,4,7}, edge {3}, ride {2}, track {1}), and a hunter assigned such
a stand is placed **on the deck**. Today every hunter gets whatever stand the centre-out walk deals
him. After this task:

> **A hunter who does not own high-seat access is never placed on a seated stand while an unseated
> stand on that line is free. He gets a ground stand instead.**

**What the rule must satisfy, and the design must show each one:**

1. **Pure and deterministic.** Same roster, same entitlements, same layout gives the same stands.
2. **No new collisions.** Two hunters may share a stand only where they already would today (the
   wrap past `standCount`).
3. **Nobody is left off the line.** If the walk is exhausted -- more hunters than stands -- he
   falls back to today's answer (`ForestTest.standIndexFor`, which wraps). **A hunter with no stand
   is worse than a hunter on a seat he did not pay for.**
4. **It is today's game, bit for bit, when every hunter is entitled** -- and the spec asserts that
   identity, not a description of it.
5. **A solo hunter still gets the stand the drive aims every wave at** (`standIndexFor(1)` is 5 on
   road, which is `Data.PICK.defaultIndex` -- the defect task 123 round 8 measured and fixed; it
   must not come back).

**The seam, and the one hard part.** `HighSeats.hasSeat(layoutName, standIndex)` and
`ForestTest.standIndexFor(index)` are both pure and both exist. What does **not** exist is a place
that knows **all** the hunters' entitlements at once: `Match` calls
`world.placement(markers, team, index, cfg)` **per player**, with `index` from `indexWithinTeam`
(sorted userIds), and the Forest Test's closure (`ForestTestBoot`, `local function placement`) is
what maps that index to a stand. **A per-player remap cannot be collision-free** -- two hunters
independently skipping the same seat can land on the same ground stand. So the design must either
(a) deal the whole hunter line in one pure function the closure calls, which means `Match` passes
the team's order and each member's entitlement into the placement seam, or (b) find a cheaper seam
and say why it is collision-free. The Builder's candidate for (a), for the Architect to accept or
better:

```
-- pure: layout name, stand count, hunters in index order, entitled[i] -> a stand per hunter
walk = the centre-out order over ALL stands 1..standCount   (ForestTest.standIndexFor's sequence)
for each hunter h, in index order:
    take the first stand s in `walk` that is not taken and that he is allowed on
        (a seated stand is skipped unless entitled[h])
    if none: fall back to ForestTest.standIndexFor(h)        -- requirement 3
```

Greedy, deterministic, no collisions, and identical to today when every `entitled[h]` is true.

**This is built on ground task 218 never proved live.** TASKS.md row 218 reads *"NOT PROVEN: no hit
card, no frames for road/ride/track, the HUD notice text, the climb itself, and TrussPart.Size
read-back"* (queued as 218a(h)). The design must say what task 221 proves and what it inherits
unproven; the Builder will say the same in its report. **Gating a privilege behind money does not
make the privilege work** -- and if the live run shows a hunter who cannot reach the deck, that is
a finding to report, not a thing to fix inside this task.

### D6. UNLIMITED AMMUNITION

Karen's *"Unlimited amunition"*. Today a drive issues `Shotgun.CONFIG.START_RESERVE` =
`{ Slug = 12, Buck = 12 }` (one local, `DRIVE_SHELLS = 12`) and `Weapon.refillForDrive` puts it
back **once per drive**, level-triggered on the drive number. The entitlement means:

> **For its owner, the 12-per-drive allowance does not bind.**

Two shapes, and the design picks one and says why:

* **(i) a large reserve** -- `Shop.startFor` hands a big number. Cheapest; the HUD then prints that
  number, which is a lie dressed as a fact and looks like a bug.
* **(ii) an unlimited pocket** -- the weapon state carries "this pocket does not decrement", the
  HUD prints a word for it, and the word is written down in `Drive.CONFIG`/`Shotgun.CONFIG` like
  every other word this repo draws. More code, honest on screen.

The Builder recommends **(ii)**, and asks the Architect to name the exact owner: the pocket is
`Weapon.StateMachine`'s and the allowance is `Shop.startFor`'s, so the boundary between them is the
decision. **It must not touch the barrels** -- a break-action shotgun still holds two and still has
to be reloaded; unlimited is about the POCKET, not the gun. A reload that no longer costs a
keypress would change the feel of the weapon, which is Karen's to judge and is not in this task.

### D7. THE RED STAG CARD is shown and is NOT buyable

**There is no red stag in this game.** `Licences.ROWS.reddeer` exists as data (`licence = true`,
`price = nil`) and `tests/server/weapon_rules.spec.luau` proves the fire gate with a STUB target;
no animal publishes `Species = "reddeer"`. So the row ships `sale = false` and the panel says it is
coming. **Never sell what does not work** -- and `Shop.rowsOk`'s invariant I3 (*"a row for sale can
actually be granted"*) is exactly the structure that enforces it: it refuses a `sale = true` row
granting something no build ships. The row is what `sale` was kept for; `Shop`'s own header says so
(*"A rung announced before it ships is one row with `sale = false` again"*).

It needs a new grant field (`licence = "reddeer"`, a `Licences.ROWS` key) and therefore a fifth
reader of what ownership gives -- a licence provider the fire gate reads. **The provider may be
wired now** (it costs one function and makes the row honest the day the animal lands) **or left for
the red stag's own task**; the Architect decides, but `rowsOk` must refuse the row going
`sale = true` while nothing can grant it.

The refusal reason is `Shop.REASON.NOT_SALE`, whose notice already reads **"NOT IN THE GAME YET"**
and whose row tag is already **SOON**. Nothing new is needed on the wire.

### D8. ALWAYS-HUNTER -- his owner is never rotated to beater

Karen's *"Posibility to be a hunter always"*. Task 217 made roles rotate and the turn survive a
logout: `Economy.owedTeams()` answers the stored turn, `Roster.previousFrom(previous, owed)` folds
it in as a synthetic previous (**inverted**, because `Roster.assign` swaps), and `Roster.assign`
swaps. The entitlement means:

> **An always-hunter owner is owed `Shooters` every drive.**

**Two things the design must get right, and they are the whole decision:**

1. **The balance still wins when it must.** `Roster.assign`'s swap is kept only when
   `math.abs(counts.Drivers - counts.Shooters) <= 1`; otherwise it falls through to a plain split
   and he can land on Drivers. **That is correct and stays** -- a drive with eight hunters and no
   beaters is not a drive. Karen is selling a strong preference, not an exemption, and the shop
   blurb must say so in her own register.
2. **When the balance overrules him, HE IS TOLD WHY.** A player who paid for always-hunter and
   starts a drive with a horn, with no explanation, reads it as the purchase being broken. The
   words are written down (`Drive.CONFIG`, this repo's rule that every word it draws is in a
   config), it reaches him at `Assigning`, and it is **only** for a man whose entitlement was
   overruled -- not a line everybody sees.

The design names the seam. The Builder's note: `Economy` already requires `ReplicatedStorage.Shop`,
so `Economy.owedTeams()` *could* overlay the entitlement onto the persisted turn -- but that would
put two different facts ("the turn he is owed" and "the privilege he bought") in one memo, and the
overrule notice then has nothing to read to tell them apart. A third argument to
`Roster.previousFrom`, or a separate overlay merged at the `Assigning` edge, keeps them separable.
The Architect rules.

### D9. BUNDLES -- 2 or 3 packages at a discount

Karen's *"We can also make a few packages bundles"*. **A bundle must not be a second catalogue.**
The Builder's candidate, for the Architect to accept or better: **a bundle is an ordinary row that
names the ids it covers** --

```luau
covers = { "access.highseat", "ammo.slug" },   -- and NO hand-written grants
```

-- and its `grants` is the **merge of the covered rows' grants, computed once at module load and
frozen**. Nothing new is invented: the four entitlement readers already answer off `grants`, so a
bundle grants the rifle to `Shop.ownsWeapon` and the slug to `Shop.startFor` with no change to
either. And because it names its parts, four invariants become assertions in `Shop.rowsOk` rather
than comments:

* every covered id exists, is for sale, and is **not itself a bundle** (no nesting);
* a bundle's `hunts` gate is **at least the highest** of its parts' gates -- otherwise a bundle is
  the way round the ladder Karen set;
* a bundle's price is **strictly less** than the sum of its parts -- otherwise it is not a bundle;
* a bundle covers at least two items.

**The double-charge, and it must be closed.** A man who buys THE MARKSMAN and then opens the panel
sees RIFLE as not-owned and buyable, and pays for it twice. So `Shop.refuse`'s `OWNED` question and
the panel's `owned` flag must read **"does he own this, or a bundle that covers it"** -- one new
pure predicate, used in both places, so the window and the till cannot disagree (the rule
`Shop.rowsFor` already states: `buyable` is computed once, on the server). **The reverse case** --
he owns the rifle and buys a bundle containing it -- is accepted for v1: the discount is still a
discount, and the panel's one message slot says so. The Architect may rule otherwise.

### D10. The Robux seam (task 222), designed now and wired later

Karen will also sell these for Robux. Task 222 needs her Creator Dashboard, which the Builder
cannot reach, so **nothing is wired in this task**. What this task owes 222 is **one grant path**:

> A Robux receipt grants the same entitlement, through the same owner, by the same function.

Today `Economy.purchase(userId, itemId, facts)` does both halves at once: it asks `Shop.refuse`,
debits the balance and writes the owned set. A Robux purchase has **no debit in dollars** and its
refusal rules are Roblox's, not ours. So the design must split it:

* **`Economy.grant(userId, itemId, source)`** -- the **one** writer of the owned set. Idempotent,
  because `ProcessReceipt` is documented to be called again for a receipt that was not confirmed.
* **`Economy.purchase`** -- the refusal check, the debit, then `grant(..., "money")`.
* **the Robux door (task 222)** -- `ProcessReceipt` then `grant(..., "robux")`.

The catalogue row gains an optional `robuxProductId: number?`, **nil on every row in this task**
(there are no products yet, and a fabricated id is a shop window that lies). `Shop.rowsOk` asserts
that a non-nil one is a positive integer. Whether the price in Robux is a row field or lives with
the product on Roblox's side is the Architect's call -- the Builder's view is that the Robux price
belongs to the product and not to us, because Roblox is where it can be changed without a deploy.

### D11. Prices, in dollars

The earn rate is `Economy.CONFIG`: `COINS_PER_POINT = 2`, `PARTICIPATION = 10`, `FIRST_PLACE = 25`,
floor 0 -- a drive pays **10 to ~105**, typically **20-60**, and the design doc's own targets say a
male boar is 30 and a top hunter on 16 points is 67. **Call a drive $40.** Karen's rule is *"need
to buy is the key"* and the free path must take **many hunts**.

| item | price | ~drives | hunts gate | why |
|---|---|---|---|---|
| SLUG SHELLS | **$120** | 3 | 0 | **unchanged.** The first real purchase |
| BEATER LICENCE | **$250** | 6 | 3 | **unchanged.** He walks a few drives before he carries a gun in one |
| HIGH-SEAT ACCESS | **$600** | 15 | 5 | A privilege, not a weapon: dearer than a licence, well under the rifle |
| UNLIMITED AMMUNITION | **$900** | 22 | 10 | It removes a constraint every drive, so it costs more than the thing that changes one shell |
| RIFLE, SCOPED | **$1500** | 37 | 25 | **unchanged.** Karen: *"has to play a lot it's not few hunts"* |
| ALWAYS HUNTER | **$2000** | 50 | 30 | **the dearest single item**, because it is the only one that changes the drive for everybody else |
| RED STAG CARD | **$750** shown | -- | -- | **not buyable.** The price is shown so a player can plan; see section 8 Q5 |

Bundles -- the Builder proposes three, and **the names and the discounts are Karen's to move**:

| bundle | covers | list | price | discount | hunts |
|---|---|---|---|---|---|
| **THE HIDE** | high-seat + slug | $720 | **$575** | 20% | 5 |
| **THE MARKSMAN** | rifle + unlimited ammunition | $2400 | **$1800** | 25% | 25 |
| **THE FULL SEASON** | high-seat + slug + unlimited ammo + rifle + beater licence + always-hunter | $5370 | **$3750** | 30% | 30 |

Every price is a round number a player can hold in his head, every one is reachable by play, and
the cheapest thing in the shop is still three drives away -- which is what makes it a shop.

### D12. The Studio test grant rises with the catalogue

`Economy.CONFIG.TEST_GRANT = { coins = 2000, hunts = 25 }` was sized to buy the whole old catalogue
(80 + 120 + 250 + 1500 = 1950) *"with fifty to spare"*. The new for-sale catalogue is $5,370 of
items plus $6,125 of bundles. In Studio the store is the in-memory one, so **every playtest starts
Karen at nought** -- and a grant that cannot buy the thing she asked for makes her playtest useless.
The grant rises to cover everything for sale with a little over, and the hunts gate rises to the
highest in the catalogue (30), so **every rung is unlocked and nothing is bought for her**. The
Architect sets the exact numbers against the final table; the Builder's figures are
`{ coins = 12000, hunts = 30 }`.

### D13. `MAX_ITEMS` rises, and the panel already scrolls

`Shop.CONFIG.MAX_ITEMS = 8` carries the comment *"One panel, no scrolling, no paging"*. **That
comment is already stale**: since task 196 the wide well is a `ScrollingFrame` with
`AutomaticCanvasSize.Y` and the tall strip scrolls in X. Seven items plus three bundles is ten, so
the cap rises and the stale sentence goes. A **fifth shelf** is needed for the bundles --
`Shop.CATEGORY` gains one (the Builder suggests `BUNDLE` / "PACKAGES") with its place in
`CATEGORY_ORDER`, because `Shop.rowsOk`'s I4 refuses a row whose shelf is not one of the declared
ones and `Shop.groups` would silently drop it.

---

## 3. What the design must contain

1. **The owner table for every new thing**, in `docs/design/<system>.md`'s usual shape, and the
   `GAME_DESIGN.md` *System owners* rows that change. **One writer each** (rule 3).
2. **The money formatter: one owner, one function, named.** Which module, what it exports, who
   reads it, and the full list of **every** place a player sees the currency today -- the top-bar
   chip (`Drive.CONFIG.SCORE_COINS_LABEL`, `Hud.coinsText`), the results board head (today
   `string.upper(key)`, which must stop deriving the word from the field name) and its cells
   (`Hud.scoreCellColor`, `SCORE_EARNED_FORMAT`, `SCORE_COINS_UNKNOWN`), the shop panel
   (`Shop.CONFIG.TEXT.COINS_CAP`, `POOR_BUTTON`, `ROW_POOR_TAG`, `ShopPanel.coinsTextFor`, the
   price line), and `Shop.NOTICE[POOR]`. **A place this list misses is a place that still says
   COINS**, so the design must say how the list is made complete and how a spec keeps it complete.
   Say explicitly how a negative reads (`-$20`, not `$-20`) and how a signed gain reads (`+$34`).
3. **The retired-row mechanism** (D2), and which readers iterate which order.
4. **The stand deal** (D5): the pure function, its signature, its owner, what `Match` passes into
   the placement seam, and the five requirements as assertions.
5. **The unlimited pocket** (D6): the boundary between `Shop.startFor` and the weapon state, and
   the word the HUD prints.
6. **The always-hunter overlay and the overrule notice** (D8): the seam, and the words.
7. **The bundle** (D9): `covers`, the merge, the four `rowsOk` invariants, and the
   does-a-bundle-cover-it predicate used by both `Shop.refuse` and `Shop.rowsFor`.
8. **The grant path split** (D10), with `grant`'s idempotency stated.
9. **`Grants` grows by four fields** (`highSeat`, `unlimitedAmmo`, `licence`, `alwaysHunter`). The
   "a row that grants nothing" check in `rowsOk` currently enumerates four fields by hand -- say
   how it stops being a list somebody can forget to extend.
10. **The flag.** `SHOP` and `COINS` already exist and are both read at one boundary each. State
    whether this task is born behind a **new** flag or merges under the existing two, and if a new
    one: `default = false`, `owner`, `born`, `expires` within 21 days, a one-line `why`, and a path
    reachable **by parameter as well as by flag**. `Flags.MAX_FLAGS` is a Director call
    (TASKS.md 215a(a)) -- say if this needs it moved.
11. **The spec file per claim**, and which `SCOPE_SPECS` scope each new file joins. A new spec in no
    scope turns CI red (standing rule G, task 198). Today `shop` names `shop.spec`,
    `shop_door.spec`, `economy.spec`, `economy_store.spec`, `shop_panel.spec`, `hud_style.spec`;
    the stand deal reaches `match` (`src/shared/HighSeats/` and `src/server/ForestTest/` both map
    there) and the unlimited pocket reaches `weapon`. Say whether `BLAST_RADIUS` needs a row.
12. **Hazards**, in the repo's usual form. The Builder names four to start: a retired row that
    stops granting; a bundle that undercuts a hunts gate; a stand deal that collides or starves; an
    always-hunter who is silently overruled.
13. **What the design could NOT settle**, as numbered open decisions, split into Karen's and the
    Director's (rule 8).

---

## 4. Explicitly out of scope

* **Any Robux wiring** -- no `MarketplaceService`, no `ProcessReceipt`, no product ids. Task 222,
  and it needs Karen's Creator Dashboard. **The seam only.**
* **The red stag animal.** Task 221 ships the card unbuyable and nothing else.
* **Renaming anything persisted** (D1).
* **Making the climb work.** If task 218's ladder cannot be climbed, that is 218a(h) and a reported
  finding, not a fix inside this task.
* **Retuning the earn rate.** `COINS_PER_POINT`, `PARTICIPATION`, `FIRST_PLACE` and the floor do
  not move; the prices are set against them as they are.
* **A second currency, a premium currency, trading, or a shop that sells cosmetics.** Karen's list
  is the list.

---

## 5. Research (rule 1)

A research note goes in `docs/research/2026-10-20-money-and-the-v1-catalogue.md` and into
`docs/research/INDEX.md`, with 3+ named external sources, their licence and maintenance status, and
what each does well and badly. The Builder's intended ground, so the Architect can redirect it:
**entitlement/DLC ownership as a set** rather than a per-feature boolean; **bundle pricing and the
"already owns part of it" case** as solved in shipped storefronts; and **Roblox's own
`ProcessReceipt`** contract for the grant path's idempotency (D10). Borrowing before building
(rule 2) applies to the bundle and the grant split; the stand deal is a greedy assignment and the
written reason for inventing it, if it is invented, goes in the note.

---

## 6. Proof the Director asked for

The design must make each of these reachable; the Builder produces them.

1. The shop showing the **v1 catalogue** in the design system -- a frame, looked at.
2. **`$` on the top bar and on the results** -- frames, looked at, from the player's eye.
3. A spec per entitlement: **high-seat access changes the assignment**; **unlimited ammunition**;
   **always-hunter skips the rotation** *and* **is overruled by the balance, and told why**; **the
   red stag card cannot be bought**.
4. A **live purchase** of one item with the test grant, in the Forest Test.
5. **Smoke PASS** (standing rule A): a fresh Play of at least 80 s in the place Karen will use --
   the Tool in the character at 15 s and at the end, a clean server+client console, and the changed
   feature actually running.
6. The **scoped gate**, logged, with only DEV open; and `TWO_PLAYER_PATHS` is reached
   (`src/server/Match/`, `src/shared/Drive/`), so the Builder **stops** with
   `NEEDS TEST2 221 <sha>` before the review.

---

## 7. Facts the design should not have to rediscover

* `Shop` (shared) is the catalogue, pure, no state, no Player; `ServerScriptService.Shop` is the
  door; `Economy.purchase` is the **only** function that writes either half of a purchase.
* The four readers of what ownership gives, and their nil rules (shop design section 7.1):
  `startFor`, `grantsDriveGun` (**false** for nil -- an un-wired world must not arm every beater),
  `hatColorFor`, `ownsWeapon`.
* `Roster.previousFrom`'s inversion is the one trap in task 217: the synthetic previous is the
  **other** team, because `assign` swaps.
* `ForestTest.standIndexFor` is centre-out (`5, 4, 6, 3, 7, ...`), clamped into the line, and wraps;
  `ForestTest.postIndexFor` finds the post by **name**, because a refused stand is not in the list.
* `HighSeats.STANDS` is keyed by **layout name**; `capFor` is a third of the stands, rounded up.
* `DRIVE_SHELLS = 12` is one local in `Shotgun`, feeding both pockets of `START_RESERVE`;
  `Weapon.refillForDrive` is level-triggered on the drive number.
* `tools/flags.py` resolves the target place by Studio **MODE, not by place** (TASKS.md 216b,
  queued and unfixed) -- with DEV and the Forest Test both open it can silently write the wrong
  one. The Builder captures, restores and **reads back** every attribute it touches.
* In the Forest Test a player starts **unenrolled at the lodge**; `python ftplay.py server
  lobby-go.luau` from the runs dir is what reaches a drive (standing rule I).

---

## 8. Open questions for the Architect to settle in the design

1. **Where does the money formatter live** -- a new tiny shared module, or `Drive.CONFIG` (where
   the currency's words already are, but which `ShopPanel` does not require today)?
2. **The retired-row mechanism** (D2): `RETIRED` plus `ALL_ORDER`, or better?
3. **The stand deal's seam** (D5): what exactly does `Match` pass into `world.placement`, and does
   `Match` learn anything it should not?
4. **The unlimited pocket** (D6): large number or non-decrementing pocket, and where the boundary
   sits.
5. **The red stag card's price**: shown ($750, so a player can plan) or hidden until the animal
   exists (a price nobody can pay is arguably a promise)?
6. **Is the `reddeer` licence provider wired now** or left to the red stag's own task?
7. **The always-hunter overlay** (D8): a third argument to `Roster.previousFrom`, an overlay at the
   `Assigning` edge, or something else -- and where the overrule notice is raised.
8. **The flag** (section 3 item 10): new, or under `SHOP`/`COINS`?

---

Task: 221
Written: 2026-10-20
Builder, carrying the Director's dispatch of 2026-10-20 and Karen's words of ~08:30 the same day.
