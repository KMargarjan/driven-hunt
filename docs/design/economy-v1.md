# Design: economy-v1 (money in dollars, and the v1 shop catalogue)

Task 221. Written to `reviews/task-221/BRIEF.md`, which is the Director's and Karen's input and
**overrides anything older**. Read that brief first: Karen's words (§0), the twelve decisions already
taken (§2) and every price (§D11) are settled there and are **not re-opened here**.

This is a **delta** to `docs/design/shop.md` (§2, §3, §4, §7, §8, §9, §16), `docs/design/economy.md`
(§4, §9), `docs/design/role-rotation.md` (§4.1, §5.3), `docs/design/high-seats.md` (§6.2, §9.3),
`docs/design/shotgun.md` (§5.3), `docs/design/forest-drive.md` (§4.3) and `GAME_DESIGN.md`'s *System
owners* table. §16 lists every delta. **One new owner is created**
(`ReplicatedStorage.Money`); everything else is an extension of an owner that already exists.

**The Builder's eight open questions (brief §8) are all settled below.** Six of its candidates are
accepted; two are corrected on evidence:

1. **The money formatter is a NEW tiny shared module, not `Drive.CONFIG`** (§3). `Drive.CONFIG` would
   force `ReplicatedStorage.Shop` — whose own header says *"WHAT IS NOT HERE AND MAY NOT COME HERE:
   … a coin rate"* — to require the drive wire contract, and `ShopPanel` to require `Drive`, which it
   does not today.
2. **The stand deal needs NO new collision rule and NO change to `Match`'s per-player call** (§6).
   The brief's *"a per-player remap cannot be collision-free"* is true of a remap and false of a
   **whole-line deal recomputed per call**; and the brief's own sentence — *"A hunter with no stand is
   worse than a hunter on a seat he did not pay for"* — forces a **third pass** the Builder's
   candidate did not have, which is what makes requirement 2 hold bit for bit instead of
   approximately (§6.4 proves the Builder's two-pass version doubles two hunters onto one stand at
   five hunters on the `edge` layout, which is reachable).
3. **The overrule notice's words do NOT go in `Drive.CONFIG`** (§8.4). Every objective sentence in
   this repo lives in `Objective.CONFIG.TEXT` (`words.DriverCountdown`, `words.DriverHorn`,
   `words.DriverThrough`); `Drive.CONFIG` holds no objective word at all. The brief's `Drive.CONFIG`
   is corrected to the module that already owns those words.

---

## 1. What the system must do, and what it must not do

### 1.1 Must do

1. **Show the currency as money with a `$` everywhere a player sees it** — the top-bar chip, the
   results board's head and cells, the shop panel's wallet and prices, and every refusal notice.
   Karen, 2026-10-20: *"We need to change coins to actual money $"*.
2. **Take the red hat off the shelf and keep it working for anyone who owns it.** Karen: *"From shop
   remove red heat"*.
3. **Sell exactly Karen's v1 list** — seven rows plus three bundles (brief D3, D11).
4. **Grant four new entitlements through owners that already exist**: high-seat access
   (`world.placement`), unlimited ammunition (`Weapon.StateMachine`), the red stag card
   (`Weapon.setLicenceProvider`), always-hunter (`Match.Roster`).
5. **Show the red stag card and refuse to sell it**, structurally, until an animal of that species
   ships.
6. **Tell a man whose always-hunter privilege the balance rule overruled, and nobody else.**
7. **Leave one grant path for task 222's Robux door**: `Economy.grant(userId, itemId, source)`, the
   one writer of the owned set, idempotent.

### 1.2 Must not

1. **Must not rename anything persisted** (brief D1). The profile field stays `coins`,
   `coinsEarnedTotal` stays, `Economy.CONFIG.COINS_PER_POINT` stays,
   `Economy.STORE_NAME` stays `"DrivenHuntPlayer_v1"`, `snapshot.coinsOn` stays,
   `Hud.BOARD.COLUMNS.coins` stays, `Shop.ITEM.*` keys stay. **There is no migration and no rename
   sweep.** A rename of a persisted key is the one change that can destroy a live profile, and
   `Economy.CONFIG.STORE_NAME`'s own comment says a `_v2` is only for *"a change `Store.read` cannot
   make additively"*. **Keys are internal; VALUES are drawn.** That one sentence is the whole of D1,
   and §3.4 is the spec that enforces it.
2. **Must not be a second writer of money, of the owned set, or of the roster.**
   `Economy.grant` is the only writer of `owned`; `Economy.purchase` the only writer of a debit;
   `Phase`/`Roster` the only writers of `state.assignment`; `Match.Body` the only writer of where a
   character stands.
3. **Must not retune the earn rate.** `COINS_PER_POINT = 2`, `PARTICIPATION = 10`,
   `FIRST_PLACE = 25`, `FLOOR = 0` do not move (brief §4).
4. **Must not touch the barrels.** Unlimited ammunition is about the **pocket**. A break-action still
   holds two and still has to be reloaded (brief D6).
5. **Must not use `MarketplaceService`, `ProcessReceipt` or a product id** (brief §4). The seam only.
6. **Must not sell what no build can grant.** `Shop.rowsOk`'s I3 is extended, not weakened (§5.5).
7. **Must not add a new feature flag** (§4), a second currency, a refund, a quantity or a trade.
8. **Must not make the climb work.** If task 218's ladder cannot be climbed that is 218a(h) and a
   reported finding (brief §4).

### 1.3 Out of scope, named so this design is not blamed for omitting it

Robux wiring; the red stag animal; the ladder; the earn rate; a premium currency; **gating the PICK
window** (§6.6 — it is a real hole, it is named, and it is the Director's, open decision D-2).

---

## 2. The owner table (brief §3 item 1)

| Owner | Location | Studio | What this task gives it | Writes nothing of |
|---|---|---|---|---|
| **`ReplicatedStorage.Money`** — **NEW** | `src/shared/Money/init.luau` | `ReplicatedStorage.Money` | the **symbol, the word and the ONE formatter**: `SYMBOL`, `WORD`, `UNKNOWN`, `text`, `signed`. Frozen constants plus two pure functions. **No writer, no state, no service, no clock, no remote, no Player, no rate and no price** | everything |
| **`ReplicatedStorage.Shop`** | `src/shared/Shop/init.luau` | unchanged | the **v1 catalogue**: `RETIRED`, `ALL_ORDER`, `BUNDLES`, the sixth shelf, four new `Grants` fields, `GRANT_FIELDS`, `mergedGrants`, `anyRow`, `isRetired`, `ownedOrCovered`, and four new pure readers (`grantsHighSeat`, `grantsUnlimitedAmmo`, `grantsAlwaysHunter`, `licencesFor`). Still frozen data plus pure functions | everything |
| **`ServerScriptService.Economy`** | `src/server/Economy/` | unchanged | `Economy.grant` (**the one writer of the owned set**), `Economy.SOURCE`, `Economy.alwaysHunters()` (frozen + memoised), and the new `TEST_GRANT` numbers | the door, the panel, the catalogue, the roster, a weapon, an Instance |
| **`ServerScriptService.Shop`** | `src/server/Shop/` | unchanged | one counter (`stats.retiredItems`). Nothing else | unchanged |
| **`Match.Roster`** | `src/server/Match/Roster.luau` | unchanged | two pure functions: `Roster.owedWith`, `Roster.overruled`. **`Roster.assign` WAS rewritten in round 3** (the Director's decision of 2026-10-20) | unchanged |
| **`ServerScriptService.Match`** | `src/server/Match/` | unchanged | the fifth argument to the placement seam (`line`), `roleOverruled` on the snapshot, and one more read of the economy view it already holds | what a high seat is, which stand anybody gets, a price, an item id |
| **`ReplicatedStorage.HighSeats`** | `src/shared/HighSeats/init.luau` | unchanged | `HighSeats.dealLine` — **the one rule that says which hunter gets which stand when a seat is paid for**. Pure: no Instance, no service, no raycast | a position, a part, a player |
| **`ServerScriptService.ForestTest`** | `src/server/ForestTest/init.luau` | unchanged | `ForestTest.standWalk()` — `standIndexFor`'s own sequence as a list | unchanged |
| **`Weapon.StateMachine`** | `src/server/Weapon/StateMachine.luau` | unchanged | `WeaponState.unlimited` — **the pocket that does not decrement**. Still the only producer of a `WeaponState` | the allowance (that is `Shop.startFor`'s) |
| **`ReplicatedStorage.Licences`** | `src/shared/Licences/init.luau` | unchanged | `Row.shipped` — does an animal of this species exist in this build | everything |
| **`PlayerScripts.Hud`** | `src/client/Hud/` | unchanged | `BOARD.COLUMNS[*].head` (the head word, no longer derived), `$` through `Money`, `INF` on the ammo chip | any rule, any price |
| **`Hud.ShopPanel`** | `src/client/Hud/ShopPanel.luau` | unchanged | the PACKAGES shelf and `Money.text` on every number it prints. Still **draws what arrived and decides nothing** | unchanged |
| **`Hud.Objective`** | `src/client/Hud/Objective.luau` | unchanged | one sentence: `words.DriverOverruled`. Still the ONE writer of the objective line | unchanged |

### 2.1 Why `Money` is its own module and not a field of `Drive.CONFIG` (open question 1)

Three pieces of evidence, each from a file in this repo:

1. **`ReplicatedStorage.Shop` must not require the drive wire contract.** Its own header reads
   *"WHAT IS NOT HERE AND MAY NOT COME HERE: a balance, an ownership set, a hunt count, a coin rate,
   a remote, a Player."* `Shop.NOTICE[POOR]` and `Shop.CONFIG.TEXT.POOR_BUTTON` are the two places
   the server formats money, so the formatter must be reachable from `Shop`. Requiring `Drive` for it
   drags the whole snapshot contract into the catalogue.
2. **`ShopPanel` does not require `Drive` today** and should not learn to. `Shop.CONFIG` is the one
   table it reads for words; a second words module would be a second answer to "what does this panel
   say".
3. **The precedent exists and is small.** `ReplicatedStorage.Licences` is 93 lines of frozen data
   plus four pure functions with no writer, required by `Match` and by `Weapon.Rules`. `Money` is the
   same shape and smaller.

The cost is named: **one more shared module**, and `src/shared/Money/` needs a `BLAST_RADIUS` row
(§14).

---

## 3. The money formatter: one owner, one function (brief §3 item 2)

### 3.1 `ReplicatedStorage.Money`

```luau
Money.SYMBOL  = "$"
Money.WORD    = "MONEY"   -- the caption and the column head
Money.UNKNOWN = "--"      -- NOT "0": `Economy.balanceOf`'s own rule, nil is not zero

-- "$1240", "$0", and "-$20" for a negative: THE SIGN IS OUTSIDE THE SYMBOL.
-- nil in, `Money.UNKNOWN` out.
function Money.text(amount: number?): string

-- "+$34" / "-$20": the sign is ALWAYS drawn, because a drive can cost him
-- (a piglet is -10 points, so -$20). `Drive.CONFIG.SCORE_EARNED_FORMAT`'s own reason.
function Money.signed(amount: number?): string
```

* **`-$20`, never `$-20`.** The sign is applied to the string, not inside the format: `Money.text`
  is `(if amount < 0 then "-" else "") .. SYMBOL .. tostring(math.abs(whole))`. One place, and the
  spec asserts `Money.text(-20) == "-$20"` and `Money.signed(34) == "+$34"`.
* **No thousands separator.** `$12000`, not `$12,000`. Reason, measured rather than chosen:
  `Hud.BOARD.COLUMNS.coins` is **66 px wide** at `HEADING` size, and
  `tests/client/hud_clarity.spec.luau` measures a **400 px** screen. A separator adds a character to
  the widest cell for no information — every price in the catalogue is a round number
  (brief D11: *"a round number a player can hold in his head"*). It is one branch in one function to
  add later. **Karen's, non-blocking (K-4).**
* **Non-integers are floored to a whole dollar.** No balance in this game is fractional
  (`COINS_PER_POINT = 2`, `PARTICIPATION = 10`), and a `$12.0000001` on screen would be a formatter
  inventing a precision the game does not have.
* **It is the only place `"$"` exists in `src/`.** §3.4 is what keeps that true.

### 3.2 Every place a player sees the currency today, and what each becomes

This is the complete list. It was built by grepping `src/` for `COINS`, `coinsText`, `COINS_CAP`,
`SCORE_COINS_*`, `SCORE_EARNED_FORMAT` and `string.upper` (§3.4 is the mechanism that keeps it
complete, so this table never has to be rebuilt by hand again).

| Where a player sees it | Symbol today | After |
|---|---|---|
| the top-bar chip's caption | `Drive.CONFIG.SCORE_COINS_LABEL = "COINS"` | `Money.WORD` |
| the top-bar chip's value | `Hud.coinsText` → `"COINS 1240"` | `Money.text(value)` → `"$1240"`; the caption is the chip's own, so `Hud.coinsText` answers **the value alone** and the string-splitting at `Hud.renderBar` (*"`Hud.coinsText` answers 'COINS 2000' — the LABEL first — and the chip wants the number"*) **goes** |
| the chip's unknown | `Drive.CONFIG.SCORE_COINS_UNKNOWN = "--"` | `Money.UNKNOWN`; `SCORE_COINS_UNKNOWN` is **removed** and its one reader reads `Money` |
| the results board's column head | `string.upper(key)` → `"COINS"` | `Hud.BOARD.COLUMNS[key].head`, and `coins.head = Money.WORD`. **The derivation goes** (§3.3) |
| the results board's cell | `string.format(Drive.CONFIG.SCORE_EARNED_FORMAT, row.earned)` → `"+34"` | `Money.signed(row.earned)` → `"+$34"`. `SCORE_EARNED_FORMAT` is **removed** |
| the results board's empty cell | `""` for a leaver | unchanged — *"AN UNKNOWN IS NOT DRAWN AT ALL RATHER THAN `--`"* (`scoreCellsFor`) |
| the shop's wallet pill caption | `Shop.CONFIG.TEXT.COINS_CAP = "COINS"` | `TEXT.MONEY_CAP = Money.WORD` (§3.5) |
| the shop's wallet pill value | `ShopPanel.coinsTextFor` → `"1240"` | `Money.text(state.balance)` → `"$1240"` |
| the shop's price line caption | `Shop.CONFIG.TEXT.COINS_CAP` **reused** | `TEXT.PRICE_CAP = "PRICE"` (§3.5) |
| the shop's price value | `string.format("%d", row.price)` in `ShopPanel.buttonStateFor` | `Money.text(row.price)` |
| the shop's row tag | `TEXT.ROW_POOR_TAG = "SHORT %d"` | `"SHORT %s"`, filled with `Money.text(short)` |
| the shop's poor button | `TEXT.POOR_BUTTON = "%d MORE COINS"` | `"%s MORE"`, filled with `Money.text(short)` |
| the refusal notice | `Shop.NOTICE[POOR] = "YOU NEED %d COINS"` | `"YOU NEED %s"`, filled by `Shop.noticeFor` (§3.6) |

`Shop.NOTICE[LOCKED] = "LOCKED: %d HUNTS"` is **unchanged**: hunts are not money.

### 3.3 The board's column head stops being derived

`Hud.BOARD.COLUMNS` gains one field per column:

```luau
COLUMNS = {
    rank   = { x = 0,   w = 20, right = true,  head = "#" },
    name   = { x = 28,  w = 186, right = false, head = "NAME" },
    kills  = { x = 214, w = 74, right = true,  head = "KILLS" },
    points = { x = 292, w = 78, right = true,  head = "POINTS" },
    coins  = { x = 374, w = 66, right = true,  head = Money.WORD },
    badge  = { x = 448, w = 40, right = false },   -- never drawn as a head
}
```

and the head loop becomes `cell.Text = Style.spaced(column.head)`. `string.upper(key)` goes, and with
it the `if key == "rank" then "#"` special case — the `#` is now a declared word like every other.
This is `Drive.CONFIG`'s own rule (*"every word the panel draws is written down"*) applied to the one
place in the Hud that broke it. **The KEY stays `coins`**: it is the snapshot's field name and D1
forbids renaming it.

### 3.4 How the list is kept complete — a negative assertion, not a comment

`tests/client/money.spec.luau` (new, §14) asserts, over the three word tables:

1. **No string a player sees contains `"COIN"`** (case-insensitive). The tables walked are every
   value in `Shop.CONFIG.TEXT`, every value in `Shop.NOTICE`, every value in
   `Shop.CATEGORY_LABEL`, every `Hud.BOARD.COLUMNS[*].head`, and every `Drive.CONFIG` value whose
   key begins `SCORE_`. **Keys are not walked** — `COINS_CAP`'s successor is gone, but
   `Hud.BOARD.COLUMNS.coins` and `snapshot.coinsOn` are internal and must survive (D1).
2. **No string in those tables contains `"$"`.** The symbol exists in `Money` alone, so no module can
   hand-roll it. (`Shop.NOTICE[POOR]` carries `%s`, not `$`.)
3. **`Money.text` and `Money.signed` are the two producers**: the spec asserts the exact strings for
   `nil`, `0`, `1240`, `12000`, `-20` and `+34`.

**A place this list misses is a place that still says COINS** — and assertion 1 is what makes that a
failing harness rather than a reader's job. That is the mechanism brief §3 item 2 asked for.

### 3.5 `COINS_CAP` splits into two, because it answers two questions

`Shop.CONFIG.TEXT.COINS_CAP` is read in **two** places in `ShopPanel`: the wallet pill's caption
(`coinsCaption.Text = spaced(TEXT.COINS_CAP)`) and the detail pane's **price** caption
(`priceCaption.Text = spaced(TEXT.COINS_CAP)`). Those are different facts — *how much he has* and
*what this costs* — and `Match.Penalty`'s warning applies to a word as much as to a predicate
(*"four questions in one predicate is how 'one predicate answered two unrelated questions' happened
in the previous project"*). A caption reading `MONEY` over a price would be the drift. So:

* `TEXT.MONEY_CAP = Money.WORD` — the wallet pill;
* `TEXT.PRICE_CAP = "PRICE"` — the detail pane's price line;
* `TEXT.COINS_CAP` is **removed**. `shop_panel.spec` asserts the two captions differ.

### 3.6 `Shop.noticeFor` learns one branch

```luau
function Shop.noticeFor(reason: any, number: number?): string?
    ...
    if string.find(line, "%%s") then return string.format(line, Money.text(number or 0)) end
    if string.find(line, "%%d") then return string.format(line, number or 0) end
    return line
end
```

`%s` means money, `%d` means a plain count. Two branches in the one function that fills a notice, so
neither the door nor the panel formats a number itself. `Shop` requires `Money` (its third shared
require, beside `Flags` and `Shotgun`); `Money` requires nothing, so there is no cycle.

---

## 4. The flag: no new one. `SHOP` and `COINS` already cover both halves (brief §3 item 10)

**This task is born behind the two flags that exist**, and `Flags.MAX_FLAGS` does **not** move —
TASKS.md 215a(a) stays the Director's, untouched by this task.

| What | Behind | Why that is the whole of it |
|---|---|---|
| the catalogue, the bundles, the retired row, the four entitlements, the grant split | **`SHOP`** | every one of them is read through a provider the shop wires, and `nil` from a provider is today's game (§5.6). With `SHOP` off `ServerScriptService.Shop` connects no remote, `Economy` is handed no entitlement question anybody asks, and `Shop.isOn()` is the one read |
| the `$` and the word MONEY on the drive bar and the results board | **`COINS`** | `Hud.coinsText` already draws nothing unless `snapshot.coinsOn` is true, and `coinsOn` is `Economy.isEnabled()`. With `COINS` off the chip and the coins column are absent exactly as they are today — so the `$` is unreachable, not merely unused |

**Both branches stay reachable by parameter**, which is what CLAUDE.md's feature-flag section
requires: `Shop.start({ enabled = … })`, `ShopPanel.start(frame, { enabled = … })`,
`Economy.start({ enabled = …, testGrant = … })`, and every new pure function takes its facts as
arguments (`dealLine`'s `entitled`, `Roster.owedWith`'s `always`, `Shop.startFor`'s `owned`,
`Objective.text`'s `drive.roleOverruled`). No new path reads a flag.

**The playtest recipe is unchanged and goes in `TASKS.md`'s row:**
`python tools/flags.py set COINS on`, `python tools/flags.py set SHOP on`,
`python tools/flags.py clear` before the harness. Karen's Forest Test place already carries
`DHFlag_COINS = true` (GAME_DESIGN.md row 67), and `tools/flags.py` resolves the target by Studio
**mode** and not by place (brief §7, TASKS.md 216b), so the Builder captures, restores and **reads
back** every attribute it touches.

---

## 5. `ReplicatedStorage.Shop`: the v1 catalogue

### 5.1 The row

```luau
export type Grants = {
    ammo: string?,              -- an `AmmoKind` this weapon may be issued: "Slug"
    weapon: string?,            -- a `Weapons.ROWS` key: "rifle"
    driveGun: boolean?,         -- a BEATER may carry a gun in a drive
    hatColor: Color3?,          -- the cosmetic
    highSeat: boolean?,         -- NEW: he may be DEALT a seated stand (section 6)
    unlimitedAmmo: boolean?,    -- NEW: the 12-per-drive allowance does not bind (section 7)
    licence: string?,           -- NEW: a `Licences.ROWS` key: "reddeer" (section 9)
    alwaysHunter: boolean?,     -- NEW: he is owed `Shooters` every drive (section 8)
}

export type Row = {
    id: string,
    label: string,              -- <= Shop.CONFIG.LABEL_MAX (18), and NOW ASSERTED (5.5)
    category: string,           -- one of `Shop.CATEGORY`
    blurb: string,
    price: number,
    hunts: number,
    sale: boolean,
    grants: Grants,
    covers: { string }?,        -- NEW: a BUNDLE's parts. nil on every ordinary row
    robuxProductId: number?,    -- NEW: nil on EVERY row in this task (section 11)
}
```

**`Grants` is still the one invented thing in this file** and rule 2's reason is unchanged: no source
has this game's weapon ids in it. The four new fields are four booleans/strings read by four pure
functions, which is the research note's *"ownership is a set the loadout reads"* with our names in it.

### 5.2 `Shop.GRANT_FIELDS` — the hand-written list stops being a list somebody can forget (brief §3 item 9)

`Shop.rowsOk` today enumerates four fields by hand:
`grants.ammo == nil and grants.weapon == nil and grants.driveGun == nil and grants.hatColor == nil`.
With eight fields that line is a bug waiting for a ninth. So:

```luau
Shop.GRANT_FIELDS = table.freeze({
    "ammo", "weapon", "driveGun", "hatColor",
    "highSeat", "unlimitedAmmo", "licence", "alwaysHunter",
})

function Shop.grantsAnything(grants: any): boolean   -- PURE: loops GRANT_FIELDS
```

and **both directions are asserted**, which is the half that actually catches the omission:

* `rowsOk` uses `grantsAnything`, so a row that grants nothing is refused however many fields exist;
* `shop.spec` asserts that **every key appearing in any row's `grants` is in `GRANT_FIELDS`** — so a
  ninth field added to a row and not to the list fails the harness. A list that only validates
  downward would pass while the new field was invisible to `grantsAnything`, which is exactly the
  silence `Weapons`'s header refuses a registry for (*"a weapon that forgot to register is a weapon
  that silently does not exist"*).

### 5.3 The retired row (brief D2, open question 2) — `RETIRED` + `ALL_ORDER`, accepted, with one correction

The Builder's candidate is **accepted**. The red hat's row **moves verbatim** into
`Shop.RETIRED`, with `sale = false` written over it, and is archived under
`backups/2026-10-20_task-221_shop-red-hat-row.md` with a note (rule 7) — the shape
`backups/2026-10-16_task-196_shop-rifle-open-row.md` already has. **The row stays in code**, because
it must keep granting: the id is already in live `owned` sets and `Shop.hatColorFor` reads the hat
out of the iteration order, so deleting it would silently turn a bought hat back to orange.

```luau
Shop.RETIRED = { [Shop.ITEM.HAT_RED] = { ... the row, sale = false ... } }
Shop.RETIRED_ORDER = table.freeze({ Shop.ITEM.HAT_RED })
-- ORDER then RETIRED_ORDER. A declared list and not a concatenation computed at each read, for
-- `Shop.ORDER`'s own stated reason: the order is one fact and belongs in one place.
Shop.ALL_ORDER = table.freeze({ ...Shop.ORDER..., ...Shop.RETIRED_ORDER... })

function Shop.anyRow(id: any): Row?        -- ROWS, then RETIRED
function Shop.isRetired(id: any): boolean  -- RETIRED only
```

**Who iterates which order, and this table is the interface:**

| Reader | Order | Why |
|---|---|---|
| `Shop.startFor` (the ammo loop) | **`ALL_ORDER`** | a retired ammo row must keep issuing its shells |
| `Shop.grantsDriveGun` | **`ALL_ORDER`** | |
| `Shop.hatColorFor` | **`ALL_ORDER`** | the whole reason D2 exists |
| `Shop.ownsWeapon` | **`ALL_ORDER`** | |
| `Shop.grantsHighSeat`, `grantsUnlimitedAmmo`, `grantsAlwaysHunter`, `licencesFor` | **`ALL_ORDER`** | one rule for all eight readers of what ownership gives |
| `Shop.rowsFor`, `Shop.groups`, `Shop.menuOrder` | **`ORDER`** | invisible to the panel |
| `Shop.row`, and therefore `Shop.refuse` and `Economy.purchase` | **`ROWS` only** | a retired id answers `Shop.REASON.UNKNOWN`: **unbuyable at the door** |

**The one correction.** A retired id arriving from a stale client is counted by the door as
`stats.unknownItems`, which conflates it with a forged packet — the distinction `Weapon` makes
between `stats.refused` and `stats.badRequests` and states the reason for. A new wire reason would
cost a `NOTICE` and a panel state for a row nobody can see, so instead: **`ServerScriptService.Shop`
counts `stats.retiredItems` separately and still replies `UNKNOWN`.** One counter, no wire change,
and *"a stale client after a catalogue change is a different fact from a forged packet"* stays true.

### 5.4 The catalogue, the shelves and the order

Six shelves. `ACCESS` is new because a high seat and an always-hunter place are neither a weapon, a
shell, a permit nor clothing; `BUNDLE` is new because `Shop.rowsOk`'s I4 refuses a row whose shelf is
not declared and `Shop.groups` would silently drop it (brief D13).

```luau
Shop.CATEGORY = { WEAPON = "weapon", AMMO = "ammo", LICENCE = "licence",
                  ACCESS = "access", CLOTHING = "clothing", BUNDLE = "bundle" }
Shop.CATEGORY_ORDER = { WEAPON, AMMO, LICENCE, ACCESS, CLOTHING, BUNDLE }
Shop.CATEGORY_LABEL = { ... ACCESS = "ACCESS", BUNDLE = "PACKAGES" }
```

* **`CLOTHING` stays declared with no row on it.** `Shop.groups` *"drops an EMPTY shelf rather than
  drawing a header with nothing under it"*, so the shelf disappears from the panel by itself; the
  category stays because the retired hat carries it and because clothing comes back.
* **PACKAGES is LAST.** Karen said *"We can also make a few packages bundles"* — *also*. And it is
  the safer order: `ShopPanel` opens on *the first item he may actually buy* and falls back to the
  first row in the menu, and a shop that opens on a page headed LOCKED is the defect task 196 fixed
  by looking at it.

| id | label | shelf | price | hunts | sale | grants |
|---|---|---|---|---|---|---|
| `ammo.slug` | `SLUG SHELLS` | ammo | **$120** | 0 | true | `ammo = "Slug"` — unchanged |
| `licence.beater` | `BEATER LICENCE` | licence | **$250** | 3 | true | `driveGun = true` — unchanged |
| `bundle.hide` | `THE HIDE` | bundle | **$575** | 5 | true | merged (§5.7) |
| `access.highseat` | `HIGH SEAT ACCESS` | access | **$600** | 5 | true | `highSeat = true` |
| `licence.reddeer` | `RED STAG CARD` | licence | **$750** | 0 | **false** | `licence = "reddeer"` |
| `ammo.unlimited` | `UNLIMITED AMMO` | ammo | **$900** | 10 | true | `unlimitedAmmo = true` |
| `rifle.scoped` | `RIFLE, SCOPED` | weapon | **$1500** | **25** | true | `weapon = "rifle"` — unchanged (D4) |
| `bundle.marksman` | `THE MARKSMAN` | bundle | **$1800** | 25 | true | merged |
| `role.alwayshunter` | `ALWAYS HUNTER` | access | **$2000** | 30 | true | `alwaysHunter = true` |
| `bundle.season` | `THE FULL SEASON` | bundle | **$3750** | 30 | true | merged |

`Shop.ORDER` is that table's order — **cheapest first**, bundles mixed in by price, which is
`Shop.ORDER`'s existing rule and costs nothing because the side menu regroups by shelf. Ten rows,
`Shop.CONFIG.MAX_ITEMS` rises **8 → 12** and the stale sentence *"One panel, no scrolling, no
paging"* **goes**: since task 196 the wide well is a `ScrollingFrame` with `AutomaticCanvasSize.Y`
and the tall strip scrolls in X (brief D13). Twelve, not ten, so the next row does not need a
second decision.

`Shop.ITEM` gains `HIGH_SEAT`, `UNLIMITED_AMMO`, `RED_STAG`, `ALWAYS_HUNTER`, `BUNDLE_HIDE`,
`BUNDLE_MARKSMAN`, `BUNDLE_SEASON`. `HAT_RED` stays (the retired row needs it).

### 5.5 `Shop.rowsOk` — every new rule is an assertion

Signature widens, in the shape it already has (the weapon table is already a parameter, so this
module requires nothing to validate itself):

```luau
function Shop.rowsOk(weaponRows: any, ammoKinds: { string }?, licenceRows: any?): { string }
```

Kept unchanged: `MAX_ITEMS`, ORDER↔ROWS bijection, duplicate ids, `row.id == id`, price and hunt
gate are non-negative integers, the shelf is declared, the blurb's 20..`BLURB_MAX` bounds, I3's
weapon and ammo checks.

**New:**

* **I2a — the label fits.** `#row.label <= Shop.CONFIG.LABEL_MAX` (18). The shop design has stated
  that bound since task 178 and nothing asserted it; six of the ten rows are new labels.
* **I3a — A LICENCE ROW FOR SALE NEEDS AN ANIMAL THAT EXISTS.** For a `sale = true` row with
  `grants.licence = s`: `licenceRows[s] ~= nil and licenceRows[s].shipped == true`. **This is what
  makes the red stag card's `sale = false` forced rather than chosen** (§9).
* **I6 — the retired table is disjoint and inert.** No id is in both `ROWS` and `RETIRED`;
  `ALL_ORDER` names every id of both exactly once; every retired row has `sale == false` and
  `grantsAnything(row.grants)`.
* **I7..I11 — the bundle** (§5.7).
* **I12 — a non-nil `robuxProductId` is a positive integer**, and in this task every row's is nil
  (`shop.spec` asserts that too: *"there are no products yet, and a fabricated id is a shop window
  that lies"*).

### 5.6 The eight readers of what ownership gives, and the nil rule for each

This table is the most important thing in this design, for the reason shop design §7.1 gives for its
own: *"today's game is not the same boolean in all of them"*, and writing one direction for all would
arm every beater in every un-wired world.

| Reader | `owned == nil` ("nobody answered") | `owned == {}` | owns it |
|---|---|---|---|
| `Shop.startFor` (ammo) | the weapon's own `START_RESERVE` — **unrestricted** | buck only | slug too |
| `Shop.ownsWeapon` / `loadoutFrom` | every id — **unrestricted** | the primary | + the rifle |
| `Shop.hatColorFor` | nil (the outfit's orange) — **unrestricted** | the same | the row's `Color3` |
| `Shop.grantsDriveGun` | **false** — today a beater carries no gun | false | true |
| **`Shop.grantsHighSeat`** | **TRUE** — today every hunter is dealt whatever stand the walk gives him, so an un-wired world must deal exactly as it does now (§6, requirement 4) | **false** | **true** |
| **`Shop.grantsUnlimitedAmmo`** | **false** — today the 12-per-drive allowance binds, and a limit is today's game | false | true |
| **`Shop.grantsAlwaysHunter`** | **false** — true for nil would put every player in every un-wired world on `Shooters` and break `match_roster.spec` at every roster size | false | true |
| **`Shop.licencesFor`** | **nil** — `Licences.allows`'s own rule: *"nil means he holds none, which is every player today"* | `{}` | `{ reddeer = true }` |

`grantsHighSeat`'s direction is the opposite of the other three new ones and that is deliberate: the
cost is stated rather than discovered — **during a DataStore outage a player who owns nothing may be
dealt a high seat for one drive**, which is exactly the accepted cost shop design §7.1 already names
for the rifle (*"a player who owns nothing is handed the rifle for one drive"*). Reversible in one
word; the Director's (D-5).

### 5.7 The bundle (brief D9, accepted with two additions)

**A bundle is an ordinary row that names the ids it covers, and its grants are computed once at
module load and frozen.** Declared apart from the ordinary rows so a hand-written grant is
impossible rather than merely wrong:

```luau
Shop.BUNDLES = {
    [Shop.ITEM.BUNDLE_HIDE] = {
        id = ..., label = "THE HIDE", category = Shop.CATEGORY.BUNDLE,
        blurb = "A seat above the drive, and the shells for it.",   -- 45 chars
        price = 575, hunts = 5, sale = true,
        covers = { Shop.ITEM.HIGH_SEAT, Shop.ITEM.SLUG },
        -- NO `grants` KEY. There is nothing here to get wrong.
    },
    ... THE MARKSMAN { rifle.scoped, ammo.unlimited }, price 1800, hunts 25,
        blurb "The long gun, and shells you never run out of."           -- 46
    ... THE FULL SEASON { access.highseat, ammo.slug, ammo.unlimited,
                          rifle.scoped, licence.beater, role.alwayshunter },
        price 3750, hunts 30, blurb "The whole season, in one."          -- 25
}

-- PURE and exported, so the merge is an assertion rather than a comment.
-- Returns nil plus a PROBLEM for a conflict (two covered rows naming different single-valued
-- grants), never a silent winner.
function Shop.mergedGrants(covers: { string }): (Grants?, string?)
```

At module load, one loop writes `Shop.ROWS[id] = row with grants = select(Shop.mergedGrants(covers))`
and then `Shotgun.deepFreeze(Shop.ROWS)` freezes the lot, as today.

**Why this invents nothing**: the eight readers already answer off `grants`, so a bundle grants the
rifle to `Shop.ownsWeapon` and the slug to `Shop.startFor` **with no change to either**. It is Odoo's
*phantom bill of materials* — a kit product defined only by the list it explodes into — with
entitlements where Odoo has stock (§13 source 4).

**Five invariants, each one assertion in `shop.spec` via `rowsOk`:**

* **I7 — the parts are real, sellable and flat.** Every covered id is a key of `Shop.ROWS`, has
  `sale == true`, and has no `covers` of its own. **No nesting.**
* **I8 — a bundle covers at least two ids**, and no ordinary row carries `covers`; a bundle's
  `category` is `BUNDLE` and only a bundle's is.
* **I9 — the hunts gate is at least the highest of its parts'.** `5 >= max(5,0)`,
  `25 >= max(25,10)`, `30 >= max(5,0,10,25,3,30)`. Otherwise a bundle is the way round the ladder
  Karen set.
* **I10 — the price is strictly less than the sum of the parts'.** `575 < 720`, `1800 < 2400`,
  `3750 < 5370`. Otherwise it is not a bundle.
* **I11 — the grants ARE the merge.** `row.grants` deep-equals `Shop.mergedGrants(row.covers)`, and
  `mergedGrants` reported no problem. A hand-written grant on a bundle fails here.

**`Grants.ammo`, `weapon`, `hatColor` and `licence` are single-valued, and `mergedGrants` REFUSES a
conflict** rather than letting `covers` order decide. With one ammo row and one weapon row in the
catalogue no bundle conflicts today; the limitation is named — a bundle could not grant two shell
kinds — and widening `Grants.ammo` to a set is the Director's (D-3), not this task's.

**The parts are shown on screen without a layout change.** `Shop.rowsFor` composes the wire blurb for
a bundle as `row.blurb .. " " .. string.format(TEXT.COVERS, labels)` with
`TEXT.COVERS = "INCLUDES: %s"` and the labels joined `", "`, so the existing blurb box draws them and
`ShopPanel` still *draws what arrived*. `rowsOk` checks the **composed** length against `BLURB_MAX`
(135) for a bundle, not the raw blurb — measured: HIDE 85, MARKSMAN 86, FULL SEASON **127**, which is
why FULL SEASON's own blurb is 25 characters and not 45. `BLURB_MAX` does **not** move, so the
Designer's measured box (*"about 220 on a desktop and about 156 on a phone"*) is untouched.

### 5.8 The double charge, closed (brief D9)

```luau
-- DOES HE OWN THIS, OR A BUNDLE THAT COVERS IT? PURE, and the ONE answer, used by `Shop.refuse`'s
-- OWNED question and by `Shop.rowsFor`'s `owned` field -- so the window and the till cannot disagree.
function Shop.ownedOrCovered(owned: { [string]: boolean }?, id: any): boolean
```

* `Shop.refuse`'s `OWNED` branch becomes `Shop.ownedOrCovered(context.owned, context.itemId)` — so a
  man who bought THE MARKSMAN is refused `OWNED` on RIFLE, SCOPED, and the panel's row says
  `IN YOUR KIT`. **He cannot pay for it twice.**
* **A bundle he is already fully covered for is refused too.** `OWNED` also fires when the item is a
  bundle and `ownedOrCovered` is true for **every** id it covers. This is the same predicate applied
  to the covers list, and it closes "the shop takes money for nothing" — *"selling a thing that
  grants nothing is the one failure this repository would not forgive"*, which is `rowsOk`'s own
  sentence, in the one case `rowsOk` cannot see.
* **Partial overlap stays buyable**, as the brief accepts: a man who owns the rifle may buy THE
  MARKSMAN, the discount is still a discount, and the panel's one message slot says so
  (`TEXT.HINT`). The reverse case is **not** re-priced: our till cannot re-price (§13 source 5
  names Steam's "Complete the Set" and why we do not copy it).
* The eight readers need **no** change for bundles: a bundle's merged `grants` already carries the
  weapon, the shell and the booleans.
* `Shop.owns` is unchanged and is still what `Economy.grant` uses for idempotency (§11): a bundle
  covering a row is not the same row, and a receipt for that row must still write that row.

---

## 6. High-seat access (brief D5, open question 3)

### 6.1 The rule

> **A hunter who does not own high-seat access is never placed on a seated stand while any stand he
> is allowed on is free. He gets a ground stand instead.**

### 6.2 The seam: `Match` passes the LINE, the world deals it

`world.placement` gains a **fifth, optional** argument:

```luau
export type PlacementLine = {
    count: number,                -- how many are being placed on this team
    entitled: { boolean? },       -- per index within team. nil = nobody answered = entitled
}

world.placement(markers, team, index, config, line: PlacementLine?)
```

* **`Match.Body.placementFor` ignores it.** The DEV place is byte-identical: `placementFor`'s
  arity grows by one unread parameter and `match_place.spec` is untouched.
* **`Match` builds `line` ONCE per `applyPlace` call**, not per player: it already sorts the team's
  userIds for `indexWithinTeam`, and for each member it asks the economy view it already holds —
  `Shop.grantsHighSeat(world.economy.ownedOf(userId))`.
* **`Match.botSlots` passes the same `line`**, with `count = realHunters + botHunters` and the real
  hunters' booleans in indices 1..n. A bot has no userId and no profile, so its index is nil →
  **entitled** by the nil rule (§5.6) → a bot may take a **leftover** seat. The real hunters are
  dealt first, because their indices are 1..n and bots get n+1 upward, so an entitled hunter always
  has first refusal. Accepted and named.
* **What `Match` learns**: one boolean per player, from a view it already reads for
  `Match.mayCarryWeapon` and for the hat. It does **not** learn what a high seat is, where the seats
  are, or which stand anybody gets — `HighSeats` is required by the forest's closure and not by
  `Match`. That is the answer to open question 3, and it is the same boundary `Body.setAccessorySource`
  already is (*"the module that dresses people must not learn what a shop is"*).

The Forest Test's closure (`ForestTestBoot`, `local function placement`) becomes:

```luau
local function placement(markers, team, index, cfg, line)
    if team ~= Data.PUSH_TEAM then
        local walk = ForestTest.standWalk()                      -- standIndexFor's own sequence
        local seated = ForestTest.seatedStands()                 -- HighSeats.standsFor(layout), as a set
        local deal = HighSeats.dealLine(walk, seated, line and line.entitled, (line and line.count) or index)
        local stand = deal[index] or ForestTest.standIndexFor(index)
        return Body.placementFor(markers, team, ForestTest.postIndexFor(markers.posts, stand), cfg)
    end
    ...unchanged...
end
```

`ForestTest.standWalk(): { number }` is new and is **exactly `standIndexFor`'s sequence**
(`{ standIndexFor(1) … standIndexFor(standCount) }`), so there is no second walk to drift;
`forest_stand.spec` already pins that permutation. `ForestTest.postIndexFor` and
`Body.placementFor` are **unchanged** — task 218 already raises a seated stand's post onto the deck
through `Markers.build`'s fifth `seats` parameter, which is *"the whole reason `placementFor` needs no
change at all"*.

### 6.3 `HighSeats.dealLine` — the whole line dealt at once, in three passes

```luau
-- PURE. One stand per hunter, in index order. No Instance, no service, no Random.
-- `walk`     the order stands are offered in: the caller's centre-out sequence over 1..standCount.
-- `seated`   seated[s] == true when stand s carries a high seat.
-- `entitled` entitled[i] ~= false means "may be dealt a seated stand". nil = nobody answered.
function HighSeats.dealLine(
    walk: { number }, seated: { [number]: boolean }, entitled: { boolean? }?, count: number
): { number }
    local taken, out = {}, {}
    for i = 1, count do
        local allowSeat = entitled == nil or entitled[i] ~= false
        local got = nil
        -- PASS 1: the first free stand he is ALLOWED on.
        for _, s in ipairs(walk) do
            if not taken[s] and (allowSeat or not seated[s]) then got = s; break end
        end
        -- PASS 2: the first free stand AT ALL. A hunter with no stand is worse than a hunter on a
        -- seat he did not pay for (brief D5 requirement 3, its own sentence) -- AND this is what
        -- makes requirement 2 exact rather than approximate (6.4).
        if got == nil then
            for _, s in ipairs(walk) do
                if not taken[s] then got = s; break end
            end
        end
        -- PASS 3: every stand is taken. TODAY'S ANSWER, which wraps.
        if got == nil then got = walk[((i - 1) % #walk) + 1] end
        taken[got] = true
        out[i] = got
    end
    return out
end
```

### 6.4 The five requirements, as proofs and as assertions

1. **Pure and deterministic.** No service, no Instance, no `Random`; the loop is over `walk` in
   order and hunters in index order. `high_seats.spec` calls it twice and compares.
2. **No new collisions.** A stand is written twice **only** from pass 3, and pass 3 fires only when
   every stand in `walk` is taken — that is `i > #walk`, which is **exactly today's wrap**. *Assert:*
   for every layout, every `count` 1..16 and every subset of `entitled` the spec walks, `#distinct(out[1..min(count,#walk)]) == min(count,#walk)`.
   **This is the correction to the Builder's two-pass candidate, and it is forced:** without pass 2,
   five unentitled hunters on `edge` (5 stands, seat on 3) give `2, 4, 1, 5, 5` — hunters 4 and 5
   share stand 5, where today all five fit exactly. Eight shooters is reachable at `MAX_PLAYERS` 16,
   so that is a real new collision. With pass 2 the fifth man is given the seat instead:
   `2, 4, 1, 5, 3`. Nobody doubles, nobody is off the line, and the seat is given away rather than a
   stand shared — the brief's own ordering.
3. **Nobody is left off the line.** Pass 3 is today's `standIndexFor(i)` by construction.
4. **Today's game, bit for bit, when everybody is entitled** — and the spec asserts the **identity**,
   not a description: with `entitled == nil` pass 1 always takes the first untaken stand in `walk`,
   which is `walk[i]`, which is `ForestTest.standIndexFor(i)`; past `#walk`, pass 3's
   `walk[((i-1) % #walk)+1]` is `standIndexFor`'s own `(index-1) % count`. *Assert:* for all four
   layouts and `i = 1..16`, `dealLine(standWalk(), seatedStands(), nil, 16)[i] == ForestTest.standIndexFor(i)`.
5. **A solo hunter still gets the stand the drive aims at.** Entitled solo → `walk[1]`. **Unentitled
   solo**: `road` seats `{1,4,7}`, `walk[1] = 5`, 5 is not seated → **still stand 5**, which is
   `Data.PICK.defaultIndex`, which is the x `hunterStandX()` aims every wave at — the defect task 123
   round 8 measured does not come back. *Assert that identity for `road` explicitly.*

**One layout is an exception and it is named rather than discovered.** `HighSeats.STANDS.edge = {3}`
and `edge`'s `standCount` is 5, so its walk starts at `floor(5/2)+1 = 3` — **the seated stand is also
that line's first-dealt stand**. An unentitled solo hunter on `edge` therefore starts on stand 2, one
spacing (130 studs) west, inside his 15-second pick window and inside the drawn ring. The other three
layouts are clear: `road` middle 5 vs seats {1,4,7}; `ride` middle 3 vs seat {2}; `track` middle 4 vs
seat {1}. `edge` is **already** the declared relief exception in `HighSeats.STANDS`
(*"no stand on that line satisfies the relief test at all … `edge 3` is taken on its gain alone"*), so
re-measuring it would remove even this. Asserted as the measured answer, and handed to the Director
as **D-1**.

### 6.5 Cost

`count × #walk` comparisons per call: at most `8 × 9 = 72`, called once per placed player, at most 16
calls on the `Assigning` edge. Nothing per frame, nothing per event.

### 6.6 What this entitlement is, exactly — and the hole, named

**In the Forest Test the placement is only where he STARTS.** `ForestTest.lockPick` is what decides
which stand the fire gate holds him to and which stand `hunterStandX()` aims the waves at; he picks it
by walking to it in the 15-second window. So an unentitled hunter **can still walk to a seated stand
and climb the engine's own ladder.** Gating the pick is not in this task and the reason is a measured
one, not laziness: `Match.dispatch`'s own comment records what a hunter locked to a stand away from
his feet costs — *"the pick window would then lock each of them to a stand nowhere near his feet,
gate his gun off and drag him at the soft wall"*. Refusing the pick needs its own measurement, so it
is **D-2** for the Director.

**So the product is written to match the code**, which is `rowsOk`'s I3 spirit applied to prose — the
shop must not claim more than the build does:

```
label: "HIGH SEAT ACCESS"
blurb: "You are given one of the wooden high seats on the line when one is free."
```

That sentence is true of what is built. *"Only you may climb it"* would not be, and would be the shop
window lying.

---

## 7. Unlimited ammunition (brief D6, open question 4) — (ii), the non-decrementing pocket

**(i) is refused.** A large reserve makes the Hud print a number that is a lie dressed as a fact: the
ammo chip prints `state.reserve[state.ammo]` (`Hud.ammoChipFor`), so a hunter would read `9999` and a
player reading `9999` reads a bug.

### 7.1 Where the boundary sits

**The allowance is `Shop.startFor`'s. The pocket is `Weapon.StateMachine`'s. The word is
`Shotgun.CONFIG`'s.** Three owners, one each, and the shop never touches a state:

```luau
-- `ReplicatedStorage.Shop` -- the ALLOWANCE. One more field on a table it already returns.
function Shop.startFor(row, owned): { ammo: string, reserve: { [string]: number },
                                      unlimited: { [string]: boolean }? }
```

`unlimited` is non-nil only when `Shop.grantsUnlimitedAmmo(owned)` is true, and then it names **every
kind in `row.AMMO_KINDS` the set allows** — so unlimited buckshot without the slug stays unlimited
*buckshot*. Nil otherwise, which is every caller today.

```luau
-- `Weapon.StateMachine` -- the POCKET. One more field on the state it already owns.
WeaponState.unlimited : { [string]: boolean }     -- {} by default

StateMachine.initial(config, start)      -- next.unlimited = start.unlimited or {}
StateMachine.apply(..., { kind = "Refill", reserve = …, unlimited = … })
```

* **`Load`**: the `"no-reserve"` refusal is skipped and `next.reserve[kind]` is **not decremented**
  when `state.unlimited[kind]`.
* **`Magazine`**: the same — `pocket` is treated as `#barrels` and the pocket is not written.
* **`Break`**: the *"an UNFIRED shell goes back into its own pocket"* increment is **skipped** for an
  unlimited kind, so the number on screen never moves at all.
* **`Refill`**: `next.unlimited = if action.unlimited then table.clone(action.unlimited) else {}` —
  nil is the weapon's own, which is no unlimited pockets, which is today's game.
* **THE BARRELS ARE NOT TOUCHED.** No branch in `Fire`, `Break` or `Close`. A break-action still
  holds two and still has to be reloaded, because *"a reload that no longer costs a keypress would
  change the feel of the weapon, which is Karen's to judge"* (brief D6).
* `Weapon.refillForDrive` passes `unlimited = start and start.unlimited` beside the `reserve` it
  already passes, on the same action, for the reason that comment already gives: `Refill` is a
  server-side primitive and `Validator.checkRequest` accepts only `Reload` and `SelectAmmo` over the
  wire, so **no client can send one**.

### 7.2 The word the HUD prints

`Shotgun.WeaponSnapshot` gains `unlimited: { [string]: boolean }?`, and `Shotgun.snapshot` sets it
**only when the state has one** (`if next(state.unlimited) ~= nil then table.clone(...) else nil`),
so a snapshot in a build where nobody bought it is byte-identical to today's.

The word lives beside `DRIVE_SHELLS`, in the weapon's own config, because the readout is the weapon's:

```luau
Shotgun.CONFIG.POCKET_UNLIMITED_TEXT = "INF"
```

`Hud.readoutFor` and `Hud.ammoChipFor` print it in place of the pocket count when
`state.unlimited and state.unlimited[state.ammo]`. Three ASCII characters, in the slot the two-digit
count already occupies, so no width moves. **`"--"` is deliberately NOT used**: in this repo `--`
means *unknown* (`Drive.CONFIG.SCORE_COINS_UNKNOWN`, `Money.UNKNOWN`), and an unlimited pocket is the
opposite of unknown. The word is **Karen's to change (K-2)**; the mechanism is settled either way.

---

## 8. Always-hunter, and the overrule notice (brief D8, open question 7)

### 8.1 The rule, and what still beats it

> **An always-hunter owner is owed `Shooters` every drive — and Karen's older rule still wins.**

`Roster.assign`'s swap is kept only when `|Drivers − Shooters| <= 1`; otherwise it falls through to a
plain split and he can land on Drivers. **That is correct and stays**: a drive with eight hunters and
no beaters is not a drive. `Roster.assign` was **rewritten in round 3** — see `ESCALATE.md` and the function's own header
(*"rewriting a pinned pure function to add a feature is a bigger change than the feature"*), and
`match_roster.spec` pins it at every roster size from 2 to 16.

### 8.2 The seam: NOT a third argument to `previousFrom`

Refused, and the reason is the brief's own: *"that would put two different facts in one memo, and the
overrule notice then has nothing to read to tell them apart."* `Roster.previousFrom`'s whole job is
*the stored TURN folded in as a synthetic previous*, and it carries the one trap in task 217 (the
inversion). Adding the privilege to it makes one function answer two questions.

Instead, **two new pure functions in `Match.Roster`, beside the four task 217 added:**

```luau
-- PURE. The team each player WANTS, which is his stored turn with the privilege written over it.
-- `always` nil or EMPTY -> `owed` is returned BY IDENTITY: nothing is allocated and the game is
-- bit-for-bit what it was before this task, which IS the flag-off story (`previousFrom`'s own rule).
-- IT DOES NOT INVERT. The inversion is `previousFrom`'s and stays there, and only there.
function Roster.owedWith(owed: { [number]: TeamName }?, always: { [number]: boolean }?)
    : { [number]: TeamName }?

-- PURE. Whose privilege the balance rule overruled: sorted userIds who are always-hunter and whose
-- FINAL team is `Drivers`. A LIST, sorted, so the wire is a dense array (`tied`/`through`'s shape).
function Roster.overruled(assignment: Assignment, always: { [number]: boolean }?): { number }
```

and `Phase.enterAssigning` changes by one line:

```luau
local previous = Roster.previousFrom(state.previousAssignment, Roster.owedWith(owed, always))
state.assignment = Roster.assign(userIds, previous, config)
```

The join branch's `Roster.joinTeam(counts, owed, config)` is handed `Roster.owedWith(owed, always)[userId]`
the same way, so a man who walks onto a truck pad mid-drive gets the privilege too — and
`joinTeam`'s own rule still holds (the owed team wins only off a tie), so the balance still wins
there as well.

**`always` arrives on the EVENT**, exactly as `owed` does: `Phase.step`'s `filled` gains
`alwaysShooters`, and `Match.dispatch` fills it beside `filled.owed`, one line below it. `Phase`
learns nothing about a shop or an item id — it is handed a set of userIds.

### 8.3 Where `always` comes from: `Economy.alwaysHunters()`, frozen and memoised

`Match.dispatch` reads `filled.owed` on **every** event, and while TASKS.md 214a(a) is open that
dispatch is stepped at ~15× `MATCH_STEP_HZ`. Asking `ownedOf` per participant per event would be ~16
clone-and-freezes ~60 times a second. So the answer is built where the invalidation is known:

```luau
-- `ServerScriptService.Economy`. userId -> true for every OPEN profile that owns always-hunter.
-- FROZEN, so no reader can write the table it was handed; MEMOISED, for `owedTeams`' own measured
-- reason. REBUILT AND NEVER MUTATED, so a reader holding the previous table holds a correct snapshot
-- of the moment it asked.
function Economy.alwaysHunters(): { [number]: boolean }
```

`invalidateAlways()` is called by **every writer of `ownedSets`** — `grant`, `load`, `release`,
`setOnLost`'s handler, `closeAll`, `start`, `stop` — which is the `invalidateOwed` discipline
verbatim. It is a **projection** of a profile `Economy` already owns, through the pure
`Shop.grantsAlwaysHunter`, and `Economy` already requires `ReplicatedStorage.Shop` for
`refuse`/`row`/`rowsFor`: **no new owner, no new fact, no second store.** It joins `Economy.view()`
as a sixth read-only function, so the drive still cannot open a session, write a balance, name a
profile field or buy anything.

### 8.4 The overrule notice: the objective line, and no new surface

`roleOverruled` is **derived, not stored.** `Match.snapshot()` answers
`Roster.overruled(state.assignment, world.economy.alwaysHunters())`, which means:

* it can never be stale against the live assignment — `Match.requestTeam` and the join branch both
  write `state.assignment` and neither has to remember a second field;
* **no field is added to `state`**, so `Phase.freezeState` and every `match_*.spec` are untouched;
* it is **absent** (not an empty array) when there is no economy view — the `stands` / `coinsOn`
  idiom (*"ABSENT means the server never sent it"*), so `COINS`-off is byte-identical.

```luau
MatchSnapshot.roleOverruled : { number }?    -- the `tied` / `through` shape, optional
```

**The words go where every objective sentence already lives**, which is `Objective.CONFIG.TEXT` and
**not** `Drive.CONFIG` — `Drive.CONFIG` holds no objective word at all, while
`words.DriverCountdown`, `words.DriverHorn`, `words.DriverThrough` and `words.DriverGo` are all in
`Objective.CONFIG.TEXT`. `Objective.DriveNow` gains one optional field and `Objective.text` one
branch:

```luau
DriveNow.roleOverruled : boolean?       -- optional, like every other field of DriveNow

-- inside the `team == "Drivers"` block, in place of the Assigning countdown:
if phase == "Assigning" and drive.secondsLeft ~= nil then
    local line = if drive.roleOverruled == true then words.DriverOverruled else words.DriverCountdown
    return string.format(line, math.max(0, math.ceil(drive.secondsLeft)))
end
```

```luau
words.DriverOverruled = "TEAMS MUST BE EVEN - you beat this drive. %d"
```

* **One message at a time, by construction.** The overrule sentence *replaces* the countdown and
  carries the same number, so there is no timing rule, no second surface and no new rectangle — which
  is the Director's own rule from task 197 part 2 (*"the top line … duplicates the banner"*).
* **Only the man it happened to sees it.** `Hud.renderObjective` already holds the local userId and
  already resolves `through` from a userId list; `roleOverruled` is resolved the same way.
* **Not a line everybody sees**: an always-hunter who got `Shooters` reads nothing new, and a player
  who bought nothing reads nothing new.
* It is up in `Assigning` only, so it can never collide with the tied banner —
  `enterAssigning` releases every tie before it holds anybody.
* The wording is **Karen's register and hers to change (K-3)**; the mechanism is settled.

---

## 9. The red stag card (brief D7, open questions 5 and 6)

### 9.1 Shown, priced at $750, and NOT buyable — and the refusal is structural

* **Q5: the price is SHOWN.** `Row.price` is a required non-negative integer that `rowsOk` already
  validates; `nil` would mean widening the type for one row. A price beside a row tagged `SOON` whose
  notice already reads *"NOT IN THE GAME YET"* is a **plan**, not a promise — and a player who can see
  it can plan for it, which is what brief D11 asks of every price. `$750` stands.
* Nothing new is needed on the wire: `Shop.REASON.NOT_SALE`, `Shop.NOTICE[NOT_SALE] =
  "NOT IN THE GAME YET"`, `TEXT.SOON_TAG = "SOON"` and `buttonStateFor`'s `kind = "soon"` all exist.

**What makes `sale = false` forced rather than chosen.** `Licences.ROWS.reddeer` exists today
(`licence = true`), so a naive I3-style check (*does the licence table know this species*) would
**pass** and nothing structural would stop someone flipping `sale`. So `Licences.Row` gains one field,
owned by `ReplicatedStorage.Licences` (frozen data, no writer at run time, which is what that module
already is):

```luau
Row.shipped : boolean    -- does an animal of this species exist in this build
boar    = { ..., shipped = true  }     -- `Boar.Body.create` publishes Species = "boar"
reddeer = { ..., shipped = false }     -- there is no red stag in this game
```

and `rowsOk`'s **I3a** refuses a `sale = true` row granting `licence = s` unless
`licenceRows[s].shipped == true`. `Licences.required` and `Licences.allows` do **not** read `shipped`
(the fire gate's rule is unchanged, so `weapon_rules.spec`'s stub-target cases are untouched). The
day the red stag lands, `shipped = true` and `sale = true` go in the **same commit as the animal**,
and I3a is what says the word is now legal — which is exactly the role I3 played for `rifle.open`.

### 9.2 Q6: the licence provider IS wired now

Task 178 left `Weapon.setLicenceProvider` unwired and stated the reason: *"a species permit is a
FIFTH item in the catalogue for an animal that is not in the game: it would be the thing invariant I3
exists to forbid."* **That reason is gone** — Karen has put the row in the catalogue herself. So:

```luau
-- `ReplicatedStorage.Shop`, the fifth reader of what ownership gives. PURE.
-- nil in, nil out: `Licences.allows`'s own rule, which is every player today.
function Shop.licencesFor(owned: { [string]: boolean }?): { [string]: boolean }?
```

and each composition root wires `Weapon.setLicenceProvider(function(player) return
Shop.licencesFor(Economy.ownedOf(player.UserId)) end)` beside the `setEntitlementProvider` line it
already has. `Weapon`'s `askLicences` already calls every provider through `pcall` and falls back to
*no restriction*, which is today's game.

**Why wire it now rather than leave it to the red stag's task:** it costs one pure function and one
boot line; it makes the row honest the day the animal lands instead of leaving a silent gap; and it
means the catalogue, the fire gate and the invariant are all consistent **in this commit** rather
than in three. The cost is one function with nothing to exercise it in production — which is why
`weapon_rules.spec` drives it with its existing stub target carrying `Species = "reddeer"`, and that
spec exists already.

---

## 10. `Economy`: the grant path split (brief D10)

```luau
Economy.SOURCE = table.freeze({ MONEY = "money", ROBUX = "robux" })

-- THE ONE WRITER OF THE OWNED SET, EITHER IN MEMORY OR ON THE KEY, AND IT NEVER YIELDS.
-- IDEMPOTENT: `ProcessReceipt` is documented to be called again for a receipt that was not
-- confirmed, so a second call must be a SUCCESS and not a refusal -- a refusal would make Roblox
-- retry for ever (section 13 source 1).
function Economy.grant(userId: number, itemId: any, source: string): PurchaseReceipt
```

What it checks, and nothing else:

| It refuses | Reason |
|---|---|
| the economy is off | `Shop.REASON.CLOSED` |
| no open session | `Shop.REASON.NO_PROFILE` |
| `Shop.row(itemId) == nil` — including **every retired id**, so nothing can grant a retired row | `Shop.REASON.UNKNOWN` |
| `row.sale ~= true` — so **no path can grant the red stag card** | `Shop.REASON.NOT_SALE` |

It does **not** check the price, the hunt gate, the counter or the balance. Those are `purchase`'s
rules and Roblox's, which is the whole point of the split.

**Already owned** → `{ ok = true, item = id, balance = …, already = true }` and **nothing is
written**. `Shop.owns` and not `Shop.ownedOrCovered`: a bundle covering a row is not that row, and a
receipt for that row must still write it.

```luau
function Economy.purchase(userId, itemId, facts): PurchaseReceipt
    -- unchanged: ShopData.refuse(...) with coinsOn, hasProfile, atCounter, owned, balance, hunts
    -- then the debit, then:
    return Economy.grant(userId, itemId, Economy.SOURCE.MONEY)
end
```

* **One `store.save`, not two.** `purchase` debits the in-memory balance and `grant` is what calls
  `current.save(userId, { coins = balances[userId], owned = nextOwned })` — it **reads** the live
  balance rather than being told it. So the profile write still happens once, with both fields, and
  `drivesPaid` is still not touched (hazard 2 stays closed).
* **Still atomic by construction.** `ShopData.refuse` is pure, `Store.save` performs no network call
  by contract, Luau is single-threaded per server, and neither half yields — the identical claim
  `payDrive` makes for the identical reason.
* `stats` gains `grants`, `grantsAlready` and `grantsBySource = { [string]: number }`, so "how many
  entitlements arrived by Robux" is a number in the report the day 222 lands.
* **The Robux door (task 222)** will be `ProcessReceipt` → `grant(..., Economy.SOURCE.ROBUX)`. **Nothing
  is wired in this task**: no `MarketplaceService`, no `ProcessReceipt`, no product id.
* **`robuxProductId` is a row field; the Robux PRICE is not.** The Builder's view is accepted, with
  its reason stated: Roblox is where a product's price can be changed without a deploy, so a price in
  our table is a price that will be wrong. `rowsOk`'s I12 asserts a non-nil id is a positive integer,
  and that every row's is nil today.

### 10.1 The Studio test grant (brief D12)

```luau
TEST_GRANT = { coins = 12000, hunts = 30 }
```

Arithmetic, written into the comment in place of the stale one:
items for sale `120 + 250 + 600 + 900 + 1500 + 2000 = 5370`; bundles `575 + 1800 + 3750 = 6125`;
everything for sale **$11,495**, so 12,000 covers it with $505 over. The red stag card is not
counted — it cannot be bought. `hunts = 30` is exactly the highest gate in the catalogue
(`role.alwayshunter` and `THE FULL SEASON`), **so every rung is unlocked and nothing is bought for
her** — she still presses every button and sees every state. `economy.spec` asserts both numbers
against the catalogue rather than against themselves:
`TEST_GRANT.coins >= sum(price of every sale row)` and
`TEST_GRANT.hunts == max(hunts of every sale row)`, so the grant cannot fall behind the catalogue
silently. The grant still raises rather than sets, saves nothing, and needs
`RunService:IsStudio()` **and** `DHShopTestGrant` — `Economy.testGrantFor(false, true)` is nil, which
is the only shape in which the live branch is provable from inside Studio.

---

## 11. Numeric targets

| Target | Value | Where it is asserted |
|---|---|---|
| rows for sale / rows drawn / `MAX_ITEMS` | 9 for sale (one `sale = false`) · 10 drawn · **12** | `shop.spec` |
| shelves | **6**, and `#CATEGORY_ORDER == #keys(CATEGORY)` | `shop.spec` |
| prices | 120 / 250 / 575 / 600 / 750 / 900 / 1500 / 1800 / 2000 / 3750 | `shop.spec` |
| hunt gates | 0 / 3 / 5 / 5 / 0 / 10 / **25** / 25 / 30 / 30 | `shop.spec` |
| bundle discount | HIDE **20%** (575 of 720) · MARKSMAN **25%** (1800 of 2400) · SEASON **30%** (3750 of 5370) | `shop.spec` I10 |
| a drive pays | 10 .. ~105, typically **$20–60**; "call a drive $40" | unchanged (`economy.spec`) |
| drives to afford | 3 / 6 / 14 / 15 / — / 22 / 37 / 45 / 50 / 94 | design only |
| test grant | `{ coins = 12000, hunts = 30 }` | `economy.spec`, against the catalogue |
| label length | `<= 18`, longest `HIGH SEAT ACCESS` (16) | `rowsOk` I2a |
| blurb length | raw 20..135; **composed** bundle blurb `<= 135`: HIDE 85 · MARKSMAN 86 · SEASON **127** | `rowsOk` |
| `Money.text` width | `$12000` = 6 chars against a 66 px cell; `Money.signed` worst case `-$50` | `money.spec` |
| `dealLine` cost | `<= 8 x 9 = 72` comparisons, `<= 16` calls per drive, 0 per frame | design only |
| `alwaysHunters()` | one table read per dispatch event; rebuilt `<= 2` per drive plus one per purchase | `economy.spec` |
| seated stands | road 3 of 9 · edge 1 of 5 · ride 1 of 5 · track 1 of 6; `capFor` unchanged | `high_seats.spec` |
| unlimited pocket | the barrels stay **2**; `DRIVE_SHELLS` stays **12** | `weapon_state.spec` |
| flags | **14**, unchanged. `MAX_FLAGS` does not move | `flags.spec` |

---

## 12. How it is tested (brief §3 item 11, §6)

**What the harness cannot do** (TASKS.md tasks 6–7, `tools/studio_mcp.py`'s docstring): it replays
keys, mouse buttons and mouse moves from `tests/client/input_scenarios.txt`, and it **cannot
synthesise a tap or fire `GuiButton.Activated`**. So every claim about a shop button is proved
through the named public handler `ShopPanel.press(id)` — *"what it proves is the ACTION, not the
touch. That limit is reported, not papered over."*

| Claim | Spec / proof | File | Scope |
|---|---|---|---|
| the catalogue is legal: 10 rows, 6 shelves, every price, every gate, I1–I12 | server | `tests/server/shop.spec.luau` | `shop`, `economy` |
| the retired hat still grants, is not in `ORDER`, is refused `UNKNOWN` at the door | server | `shop.spec`, `shop_door.spec` | `shop`, `economy` |
| the eight nil rules of §5.6, both directions of `GRANT_FIELDS` | server | `shop.spec` | `shop` |
| `mergedGrants`, `ownedOrCovered`, the bundle/part double charge, the fully-covered bundle refusal | server | `shop.spec` | `shop` |
| **the red stag card cannot be bought** (`refuse` → `NOT_SALE`; `grant` → `NOT_SALE`; I3a fails if `sale` is flipped while `shipped == false`) | server | `shop.spec`, `economy.spec` | `shop` |
| `grant` is idempotent; `purchase` = refuse + debit + grant; one `save`; `grantsBySource` | server | `tests/server/economy.spec.luau` | `shop`, `economy` |
| `TEST_GRANT` covers the catalogue | server | `economy.spec` | `shop`, `economy` |
| `Money.text` / `signed` / `UNKNOWN`; **no drawn string says COINS; no string but `Money` holds `$`** | **client, NEW** | `tests/client/money.spec.luau` | `shop`, `hud` |
| the top-bar chip, the board head and the board cells read `$` | client | `money.spec` (via the pure `Hud.coinsText`, `Hud.scorePanelLines`, `Hud.BOARD.COLUMNS`) | `shop`, `hud` |
| the panel: PACKAGES shelf, wallet pill, price caption vs money caption, `buttonStateFor` for a bundle and for a covered part | client | `tests/client/shop_panel.spec.luau` | `shop`, `hud` |
| **high-seat access changes the assignment**: the five requirements of §6.4, all four layouts, counts 1..16, the identity against `standIndexFor`, the `edge` exception | server | `tests/server/high_seats.spec.luau` | `match`, `places` |
| the forest closure is today's answer with `line == nil`; `standWalk() == standIndexFor`'s sequence | server | `tests/server/forest_stand.spec.luau` | `match`, `boar`, `places` |
| **unlimited ammunition**: `Load` does not decrement, no `no-reserve`, `Break` does not increment, `Magazine` does not decrement, **the barrels are unchanged**, `Refill` with nil is today's game | server | `tests/server/weapon_state.spec.luau` | `weapon`, **+`gun`** (§14) |
| `INF` on the readout and on the ammo chip | client | `tests/client/weapon_client.spec.luau` | `weapon` |
| the `reddeer` provider path through the fire gate | server | `tests/server/weapon_rules.spec.luau` | `weapon`, `match` |
| **always-hunter skips the rotation** (`owedWith` + `previousFrom` + `assign`) **and is overruled by the balance** (`overruled` is non-empty), identity when `always` is empty | server | `tests/server/match_roster.spec.luau` | `match` |
| the overrule **reaches him**: `Objective.text` with `roleOverruled` answers the sentence, without it the countdown; a player who was not overruled reads the countdown | client | `tests/client/hud_clarity.spec.luau` | `hud` |
| `roleOverruled` is absent with no economy | server | `tests/server/match_live.spec.luau` | `match`, `economy` |

**Frames to look at (rule 5), each inspected before it is claimed:**

1. the shop open on the **v1 catalogue**, wide and tall, from the player's eye;
2. the **PACKAGES** shelf with THE FULL SEASON selected, its `INCLUDES:` sentence legible;
3. **`$` on the top bar** and **`$` on the results board** with its `MONEY` head;
4. a hunter **on a deck** and an unentitled hunter **on the ground beside him**, same drive;
5. the **`INF`** ammo chip.

**A live purchase** of one item with the test grant in the Forest Test, and a **smoke PASS** (standing
rule A): a fresh Play of at least 80 s in the place Karen will use, the Tool in the character at 15 s
and at the end, a clean server+client console, the changed feature running.

**The gate.** `TWO_PLAYER_PATHS` is reached (`src/server/Match/`, `src/shared/Drive/`,
`tests/server/match_*.spec.luau`, `tests/client/match_client.spec.luau`), so the Builder **stops**
with `NEEDS TEST2 221 <sha>` before the review, and the review round may use a `scope=auto:…` line.

---

## 13. Research: the sources, and what is borrowed (rule 1, rule 2)

The note goes in `docs/research/2026-10-20-money-and-the-v1-catalogue.md` and into
`docs/research/INDEX.md`. The Builder's intended ground (brief §5) is **accepted and extended by two
sources**: currency formatting as a table, and bundles as kits.

| # | Source | Licence | Maintenance | Does well | Does badly | Adopted here |
|---|---|---|---|---|---|---|
| 1 | **Roblox — `MarketplaceService.ProcessReceipt`** · [docs](https://create.roblox.com/docs/reference/engine/callbacks/MarketplaceService#ProcessReceipt) · [in-experience purchases](https://create.roblox.com/docs/production/monetization/developer-products) · source repo [Roblox/creator-docs](https://github.com/Roblox/creator-docs) | docs **CC BY 4.0** | **Active** (first-party, continuously updated) | States the contract plainly: the callback **may be called again** for a receipt that was not confirmed, the grant must be recorded **before** returning `PurchaseGranted`, and granting must therefore be idempotent | Its sample keeps a **per-player list of processed receipt ids** — a second store of the same fact. This repo has one key, one session lock and one thing that may reach `DataStoreService` | **The idempotency contract**, as `Economy.grant`'s "already owned → success, write nothing" (§10). The receipt-id list is **refused**: an entitlement set is already idempotent, because granting a row twice is the same set |
| 2 | **OpenTTD — `CommandCost`** (`src/command_type.h`) · [github](https://github.com/OpenTTD/OpenTTD) | **GPL-2.0** | **Active** | Test-then-execute: one function answers *may this happen* before anything is written, and the reason travels as **data** with the number its line needs | No notion of an **external** authority granting the same thing by another route, so it has nothing to say about idempotency | Already adopted (`Shop.refuse`, `Weapon.Rules.refuse`). **Kept intact**: `refuse` is still the whole test and `grant` is the whole execution |
| 3 | **ioquake3** — `bg_itemlist` (`code/game/bg_misc.c`), `ps->stats[STAT_WEAPONS] \|= 1 << weapon` (`code/game/g_items.c`), and the `SelectSpawnPoint` family (`code/game/g_client.c`) · [github](https://github.com/ioquake/ioq3) | **GPL-2.0** | **Low activity, alive** (the reference id Tech 3 fork) | One static item table read by both sides; **ownership is a SET** and the thing owned stays where it was declared; the game mode chooses **among the points the world placed** | The bitfield caps at 32 and has no notion of a bundle or a tier. `SelectSpawnPoint` picks **per player** and tolerates telefrags — which is exactly the collision this design must not have | The item table and the set are already adopted. **The spawn pattern is adopted as the DIVISION OF LABOUR** (the world places the stands, the mode chooses) and **explicitly not as the algorithm**: §6.3 deals the whole line so two hunters cannot be given one stand |
| 4 | **Odoo — "kit" / phantom bill of materials** · [github](https://github.com/odoo/odoo) · [docs](https://www.odoo.com/documentation/latest/applications/inventory_and_mrp/manufacturing/advanced_configuration/kit_shipping.html) | **LGPL-3.0** (Community) | **Active** | A kit is defined **only** by the list it explodes into, so the kit and its parts can never disagree about what it contains; the kit's own price is independent of the sum | It is an **inventory** concept: it explodes into stock rows, where we need a **union of entitlements**, and it has no rule at all for *the customer already owns a component* | **`covers` plus a merge computed once at load** (§5.7). A bundle has no hand-written grants, and I11 asserts the merge |
| 5 | **Steamworks — Packages, bundles and "Complete the Set"** · [partner docs](https://partner.steamgames.com/doc/store/application/bundles) | **Proprietary** (partner documentation, no open licence) | **Active** | Names the exact problem: a bundle must know what the buyer **already owns**, and defines the two honest answers — *Complete the Set* (price adjusted for what he owns) and *Must purchase all* (fixed price) | Proprietary, no source, and *Complete the Set* needs a store that can **re-price at the till**. Ours cannot: `buyable` is computed once on the server off a frozen catalogue | **The question, not the mechanism**: `Shop.ownedOrCovered` closes the forward case (§5.8) and the reverse case is accepted at the fixed price, which is Steam's *Must purchase all* — stated, not discovered |
| 6 | **OpenTTD — `CurrencySpec`** (`src/currency.h`, `src/currency.cpp`) · [github](https://github.com/OpenTTD/OpenTTD) | **GPL-2.0** | **Active** | A currency is a **symbol plus its placement** (prefix or suffix) in **one table**, read by every formatter, with the **sign handled outside the symbol** — so no screen hand-rolls `$-20` | It also carries exchange rates, separators and localisation, none of which this game has or needs | **`ReplicatedStorage.Money`** (§3): symbol, word, one `text`, one `signed`, the sign outside the symbol, and `$` existing in exactly one module |

**What is invented, and the written reason (rule 2).** `HighSeats.dealLine` is a **greedy sequential
assignment with three preference tiers over a fixed deterministic walk**. No source was found that
assigns scarce privileged positions to a roster: Quake's spawn selection is per player and tolerates
collisions, and a general assignment solver (Hungarian / `linear_sum_assignment`) is hundreds of lines
for a 9×8 problem whose only objective is *entitled first*. The greedy version is **provably
collision-free** (§6.4 requirement 2) and **provably identical to today** (requirement 4), which a
solver would have to be tested into. That reason goes in the note.

---

## 14. The harness tables that must change (brief §3 item 11)

**`BLAST_RADIUS` (`tools/studio_mcp.py`) — one new row:**

```python
# The money a player sees (task 221): the symbol, the word and the ONE formatter. It resolves to
# `shop` and not to a scope of its own: the two readers are the shop's panel and the Hud, and
# `money.spec` is named in `hud` as well (the dual membership this table already uses).
("src/shared/Money/", "shop"),
```

Everything else already maps: `src/shared/Shop/`→`shop`, `src/server/Economy/`→`economy`,
`src/shared/HighSeats/`→`match`, `src/server/ForestTest/`→`match`,
`src/server/ForestTestBoot.server.luau`→`match`, `src/server/Match/`→`match`,
`src/shared/Drive/`→`match`, `src/server/Weapon/`→`weapon`, `src/shared/Shotgun/`→`gun`,
`src/shared/Licences/`→`weapon`, `src/client/Hud/`→`hud`.

**`SCOPE_SPECS` — two changes:**

1. `tests/client/money.spec.luau` is new and joins **`shop`** and **`hud`**. A new spec in no scope
   turns CI red (standing rule G, task 198).
2. **`tests/server/weapon_state.spec.luau` joins `gun`.** This is a real gap this task would
   otherwise walk into: `src/shared/Shotgun/` resolves to `gun`, whose tuple is
   `gun.spec`, `gun_client.spec`, `rifle.spec`, `ballistics.spec` — and this task puts
   `WeaponState.unlimited` and `POCKET_UNLIMITED_TEXT` in `src/shared/Shotgun/`, whose assertions live
   in `weapon_state.spec`. Without the dual membership a scoped run over a `Shotgun` change would
   **not play the spec that tests the change**. The dual membership is the idiom `zz_horn`,
   `boar_hit`, `boar_shot` and `shoot_boar` already use.

No new scope name is needed.

---

## 15. Hazards (brief §3 item 12)

| # | Hazard | Why it bites | What closes it |
|---|---|---|---|
| 1 | **A retired row stops granting.** The hat row is deleted, or a reader is left on `ORDER` | A bought hat silently turns orange; the money is gone and the thing is not | `ALL_ORDER` for all eight *what-ownership-gives* readers, `ORDER` for the panel and the till (§5.3); `rowsOk` I6; `shop.spec` asserts `hatColorFor({["hat.red"]=true})` is the dark red |
| 2 | **A bundle undercuts a hunts gate or a price.** Someone tunes a bundle and it becomes the way round Karen's ladder | *"has to play a lot it's not few hunts"* is defeated by a cheaper row | `rowsOk` I9 and I10 — assertions, not comments |
| 3 | **The stand deal collides or starves.** Two hunters on one circle, or a hunter off the line | A shared circle gates both men's guns and drags them at the soft wall; a man off the line has no drive | three passes (§6.3); requirement-2 and requirement-3 assertions (§6.4). **Pass 2 exists only for this** |
| 4 | **An always-hunter is silently overruled.** He paid $2000 and starts a drive with a horn | He reads the purchase as broken and says so | `Roster.overruled` + `roleOverruled` + `words.DriverOverruled` (§8.4), and the spec asserts the sentence reaches exactly the overruled man |
| 5 | **The double charge.** He buys THE MARKSMAN, then pays for the rifle again | The shop takes money for nothing — *"the one failure this repository would not forgive"* | `Shop.ownedOrCovered` in **both** `refuse` and `rowsFor` (§5.8), plus the fully-covered-bundle refusal |
| 6 | **A rename sweep.** A later reader "finishes the job" and renames `coins` on the profile | A live profile is destroyed and there is no rollback | §1.2 item 1, stated in the design and in the header of the changed files; §3.4's spec walks **values, not keys**, so the internal names are left alone by construction |
| 7 | **`$` in one place and `COINS` in another.** A word is missed | Two correct pieces of code disagreeing — this project's named failure mode | §3.4's two negative assertions: no drawn string says COINS, no string but `Money`'s holds `$` |
| 8 | **The grant stops being idempotent.** `grant` is "tidied" to refuse an already-owned item | Task 222's `ProcessReceipt` retries for ever and the player is charged with nothing to show | §10's `already = true` path, asserted in `economy.spec` with the contract quoted from source 1 |
| 9 | **`alwaysHunters()`'s memo is mutated instead of rebuilt** | A reader holding the table sees it change under it — hazard 2 of task 217, in a new place | `invalidateAlways()` on every writer of `ownedSets`, and the memo is **rebuilt and never mutated**; `economy.spec` asserts the returned table is frozen |
| 10 | **The composed bundle blurb overflows on a phone** | A clipped `INCLUDES:` line is a shop window that does not say what it sells | `rowsOk` checks the **composed** length for a bundle (§5.7); measured 85 / 86 / 127 against 135 |
| 11 | **`tools/flags.py` writes the wrong Studio** (TASKS.md 216b, queued and unfixed) | With DEV and the Forest Test both open, a playtest runs against the wrong build and is reported as the right one | The Builder captures, restores and **reads back** every attribute it touches, and reports the read-back |
| 12 | **Task 218's ground is inherited unproven.** TASKS.md row 218 reads *"NOT PROVEN: no hit card, no frames for road/ride/track, the HUD notice text, the climb itself, and TrussPart.Size read-back"* (218a(h)) | Gating a privilege behind money does not make the privilege work | **This task proves**: the deal, the assignment, the money, the catalogue and one hunter standing on one deck in one frame. **It inherits unproven**: the climb, and the frames for ride and track. If the live run shows a hunter who cannot reach the deck that is a **reported finding**, not a fix inside this task |

---

## 16. Every delta, so nothing is discovered at merge time

| Document | Change |
|---|---|
| `docs/design/shop.md` §2.1 | add `ReplicatedStorage.Money`; `Shop` gains `RETIRED`/`ALL_ORDER`/`BUNDLES`; `Economy` gains `grant` and `alwaysHunters` |
| ” §3 | **no new flag**; `SHOP` and `COINS` cover both halves; `MAX_FLAGS` does not move |
| ” §4.1–4.2 | the `Row` type (four `Grants` fields, `covers`, `robuxProductId`); the v1 catalogue; `MAX_ITEMS` 8→12; the stale *"no scrolling"* sentence goes |
| ” §4.2 I1–I3 | I2a, I3a, I6, I7–I12 added; the hand-written four-field list replaced by `GRANT_FIELDS` |
| ” §4.3 | `NOTICE[POOR]` takes `%s`; `noticeFor` gains one branch; `refuse`'s `OWNED` reads `ownedOrCovered` |
| ” §4.5 | `TEXT.COINS_CAP` splits into `MONEY_CAP` and `PRICE_CAP`; `COVERS` added; `LABEL_MAX` added |
| ” §7.1 | the four-reader table becomes **eight**, with the new nil rules |
| ” §7.3 | `startFor` returns `unlimited`; `StateMachine` and `refillForDrive` carry it |
| ” §7.4 | the three "licences" table: `setLicenceProvider` **is wired now**, so its *"it does NOT"* line is superseded |
| ” §8 | `Economy.grant` is the one writer of `owned`; `purchase` is refuse + debit + grant |
| ” §16 | items 6 and 7 (the species permit, its price) are **closed** by §9 |
| `docs/design/economy.md` §4, §9 | `TEST_GRANT` numbers and their arithmetic; `view()` gains `alwaysHunters` |
| `docs/design/role-rotation.md` §4.1, §5.3 | `Roster.owedWith` and `Roster.overruled`; `assign` and `previousFrom` unchanged; the snapshot's `roleOverruled` |
| `docs/design/high-seats.md` §6.2, §9.3 | `dealLine`; `edge`'s seat is also its middle stand (§6.4) |
| `docs/design/forest-drive.md` §4.3 | `world.placement`'s fifth argument; `ForestTest.standWalk` |
| `docs/design/shotgun.md` §5.3 | `WeaponState.unlimited`; `POCKET_UNLIMITED_TEXT`; the barrels are untouched |
| `docs/design/drive.md` §3.4 | `MatchSnapshot.roleOverruled`; `SCORE_COINS_LABEL`, `SCORE_COINS_UNKNOWN` and `SCORE_EARNED_FORMAT` are removed in favour of `Money` |
| `GAME_DESIGN.md` *System owners* | **new row** for `ReplicatedStorage.Money`; amend the rows for `ServerScriptService.Economy`, the shop's catalogue, the shop's door, the drive wire contract, **UI / anything drawn**, and **Game state / the drive** (the placement seam's fifth argument) |
| `docs/research/INDEX.md` | the new note |
| `backups/` | `2026-10-20_task-221_shop-red-hat-row.md` (rule 7) |
| `CLAUDE.md` Layout | no change: `src/shared/Money/` is an ordinary `src/shared/` module |

---

## 17. Open decisions

**None of these blocks building.** Every one has a settled default in this document; each is a line or
two to move afterwards.

### Karen's (feel and design)

* **K-1. The three bundle names and their discounts.** Defaults: THE HIDE 20%, THE MARKSMAN 25%, THE
  FULL SEASON 30% (brief D11: *"the names and the discounts are Karen's to move"*). Moving a discount
  must keep I10 (`price < sum`) and I9 (`hunts >= max`).
* **K-2. The unlimited pocket's word on the readout.** Default `"INF"` (§7.2). `"--"` is not
  available: it means *unknown* everywhere else in this repo.
* **K-3. The overrule sentence.** Default `"TEAMS MUST BE EVEN - you beat this drive. %d"` (§8.4).
  Her register, her wording.
* **K-4. Does `$` carry a thousands separator?** Default **no** — `$12000` (§3.1), on a measured
  width argument. One branch in `Money.text` to change.
* **K-5. The six new blurbs**, each written to be true of what is built — in particular HIGH SEAT
  ACCESS's (*"You are given one of the wooden high seats on the line when one is free"*, §6.6), which
  is phrased against §6.6's hole on purpose.

### The Director's (scope)

* **D-1. `HighSeats.STANDS.edge = {3}` is also `edge`'s first-dealt stand** (§6.4), so an unentitled
  solo hunter there starts one spacing west. `edge` is already the declared relief exception.
  **Recommendation:** re-measure `edge`'s seat inside 218a(h) rather than inside this task.
* **D-2. The walk-up hole** (§6.6): an unentitled hunter can still walk to a seated stand in the pick
  window and climb the engine's ladder. **Recommendation:** a task of its own to gate
  `ForestTest.lockPick`, because refusing a pick risks the measured "locked to a stand nowhere near
  his feet" defect and needs its own measurement. Until then the blurb is written to match the code.
* **D-3. `Grants.ammo`, `weapon`, `hatColor` and `licence` are single-valued**, so a bundle cannot
  grant two shell kinds; `mergedGrants` **refuses** such a bundle rather than choosing one (§5.7).
  Widening `ammo` to a set is queued.
* **D-4. Task 222's shape**: does a bundle get its own Robux product, or does a bundle purchase grant
  its parts' products? This design is indifferent — `grant` is called once per **row id** either way —
  and the answer needs her Creator Dashboard.
* **D-5. `grantsHighSeat(nil) == true`** means a DataStore outage can deal a seat to a man who owns
  nothing, for one drive (§5.6). It is the same accepted cost shop design §7.1 already names for the
  rifle. Reversible in one word.
* **D-6. The red stag's own task must flip `Licences.ROWS.reddeer.shipped` and
  `Shop.ROWS["licence.reddeer"].sale` in the SAME commit as the animal** (§9.1). That is the
  dependency I3a creates, and it should be written into that task's row now so it is not discovered
  then.
* **D-7. `Flags.MAX_FLAGS` stays 14** and TASKS.md 215a(a) / 82b are untouched by this task (§4).
  Retiring `BOAR_SOUNDERS`, `ORANGE_OUTFITS` and `RIFLE` still brings the count under 12 without
  touching the cap.
