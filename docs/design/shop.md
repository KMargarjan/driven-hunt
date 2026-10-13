# Design: shop (buying things with coins, at the counter in the lodge)

Task 178. Written to `reviews/task-178/BRIEF.md`, which is the Director's and Karen's input and
overrides anything older. Read that brief and `docs/research/2026-10-14-the-shop.md` first: the
pattern (note §3) and every price (note §4) are settled there and are **not re-opened here**.

What this file adds: the owner ruling, the module layout, the interface symbol by symbol, the
purchase order of operations, the wire, the profile shape, the four readers' exact boundaries, the
spec per rule, and the hazards.

This is a **new system document** and a **delta** to `docs/design/economy.md` (§4.2, §4.4, §4.5,
§9, §10.1, §12), `docs/design/lobby.md` (§9, §10), `docs/design/rifle.md` (§4), `docs/design/shotgun.md`
(§5.3), `docs/design/beater-kit.md` (§9) and `GAME_DESIGN.md`'s *System owners* table. §14 lists every
delta so nothing is discovered at merge time.

**The Builder's reading in brief §2 is ACCEPTED with four corrections**, each in its own section:

1. **§2's owner split is right as written** (§2 below).
2. **`Economy.Store`'s `load` and `save` must widen**, because the profile now has more than one
   field in it and the derived counters must come out of the store (§8.2). The brief did not say
   this; it is forced by brief §3 item 4.
3. **The hunt count is NOT a new field.** It is `Store.TEMPLATE.drivesPaid`, which already counts
   exactly the event the unlocks want, and a second field written on the same line by the same
   function would be two names for one fact (§8.3).
4. **The four readers' default for "nobody said" is NOT one direction.** It is *today's game*, which
   means **unrestricted** for the rifle, the slugs and the hat, and **refused** for the beater's gun
   (§7.1). The brief's "an unwired world behaves exactly as it does today" is the correct rule; this
   spells out that it resolves to opposite booleans in different readers, which is the one thing in
   this design that will be got wrong if it is not written down.

---

## 1. What the system must do, and what it must not do

### 1.1 Must do

1. **Open a panel when the player walks up to the counter** task 177 built inside the lodge
   (`src/server/Lobby/Build.luau`, `interior`, which parents a `Counter` part under a `Shop` folder
   under `Inside` — `Workspace.Lobby.Lodge.Inside.Shop.Counter`). Karen, 2026-10-13: *"Hunting house
   where inside can shop things"*.
2. **List the five items with their prices in coins**, and of each one say whether he owns it,
   whether it is locked behind hunts he has not played, whether he can afford it, and whether it is
   for sale at all.
3. **Sell on the server and nowhere else.** The client sends an item id. The server deducts the
   coins, records the ownership in the saved profile, and refuses with one clear line.
4. **Apply what he owns at the next drive**, through the owners that already decide those things:
   the loadout (`ReplicatedStorage.Weapons`), the per-drive shell allowance
   (`ServerScriptService.Weapon`), the arming policy (`Match.mayCarryWeapon`) and the outfit
   (`Match.Body`). Nothing else about the drive changes.
5. **Count completed hunts in the profile**, because that is the number the unlocks read.
6. **Say when the shop is closed rather than refusing item by item.** With the money off
   (`COINS` at `false`) every row would read "you cannot afford it", which is a lie about the build.

### 1.2 Must not

1. **Must not be a second owner of money.** `ServerScriptService.Economy` stays the one writer of a
   player's balance and of his profile (`src/server/Economy/init.luau`, whose header already says
   *"THE ONE OWNER of a player's coins (CLAUDE.md rule 3)"*). `Economy.purchase` is the only function
   that writes either half of a purchase.
2. **Must not own a store, a key, a session or ProfileStore.** `src/server/Economy/Store.luau`'s
   header — *"THE ONLY THING IN THIS REPOSITORY THAT MAY REACH `DataStoreService`, and the only place
   that requires ProfileStore"* — is untouched by this task.
3. **Must not own a clock.** No `Heartbeat`, no `task.delay`, no scan loop on the server: the reach
   test runs **inside the remote handler**, once per request, which is the whole reason the door is a
   remote and not a trigger volume. On the client the proximity test rides the Hud's existing
   per-frame `Hud.renderObjective` (`src/client/Hud/init.luau`, `Hud.renderObjective`, which already
   computes `me = Hud.localPosition()` and `lobbyData.spotPosition()` once a frame).
4. **Must not yield between the test and the write.** `Economy.purchase` touches in-memory tables
   and `Store.save`, which performs no network call by contract. The discipline `Economy.payDrive`
   already states.
5. **Must not add a weapon, a Tool, a hit zone or a hotbar slot.** It grants entitlements; the
   existing owners grant objects.
6. **Must not sell an entitlement no build can grant** (note §5, last paragraph). `rifle.open` is in
   the catalogue with `sale = false` and the panel prints `SOON`, and a spec makes that structural
   (§4.2, invariant I3).
7. **Must not use `MarketplaceService`, a developer product or Robux** (the Director's dispatch,
   decision 1).
8. **Must not put a price, a hunt gate or a balance on the shared drive wire.** The catalogue is
   shared data both sides read; a player's wallet goes to **that player alone** (§6).
9. **Must not sell back, refund, stack, quantify or trade** (note §5).

### 1.3 Out of scope, named so the design is not blamed for omitting them

Robux and `MarketplaceService`; selling back; quantities; trophies; a second shop; the open-sighted
rifle's weapon build (Karen removed it in task 148, archived in
`backups/2026-10-10-rifle-open-sights.md`); a shop in the DEV place (`Lobby.ANCHORS` has one row,
`forest-test`, so the DEV place has no lodge and no counter — §10.4).

---

## 2. The owners (brief §3 item 1)

### 2.1 The ruling

| Owner | Location | Studio | Owns | Writes nothing of |
|---|---|---|---|---|
| **`ReplicatedStorage.Shop`** | `src/shared/Shop/init.luau` | `ReplicatedStorage.Shop` | the **catalogue** and the **pure rules**: `ROWS`, `ORDER`, `CONFIG`, `REASON`, `NOTICE`, `refuse`, `withinReach`, `checkRequest`, `startFor`, `grantsDriveGun`, `hatColorFor`, `rowsFor`. Frozen data, **no writer, no state, no service, no clock, no remote** | everything |
| **`ServerScriptService.Shop`** | `src/server/Shop/init.luau` | `ServerScriptService.Shop` | **the door**: the two remote connections, the per-player rate bucket, the reach read, the commit order, the outbound push, and its own `stats` | the profile, the balance, the ownership set, a weapon, a character, a Tool, an Instance in `Workspace` |
| **`ServerScriptService.Economy`** | `src/server/Economy/` | unchanged | **unchanged and extended**: the one owner of the profile. Gains `owned` and the hunt count as **fields of the profile it already owns**, and `Economy.purchase` as the one writer of a purchase | the door, the panel, the catalogue |
| **`Hud.ShopPanel`** | `src/client/Hud/ShopPanel.luau` | `StarterPlayerScripts.Hud.ShopPanel` | everything inside the `ShopPanel` frame **including its `Visible`**, the `DrivenHunt.Shop.*` action binding, and four pieces of state: `open`, `payload`, `message`, `selected` | the frame itself (the Hud builds it), any rule, any price |

### 2.2 Why `ServerScriptService.Shop` is its own owner and not a module under `Economy`

Three pieces of evidence from this repo:

1. **`Economy` must not hold a `Player` and must not fire a remote.** Its own header states both:
   *"WHAT IT NEVER DOES: own a clock …, hold a `Player` (keyed by userId, the discipline `Score`'s
   header states), fire a remote, write anything drawn"*. A door is a remote handler holding a
   `Player` and answering it. Putting it inside `Economy` would break two written rules at once.
2. **The reach test needs the world and `Economy` must not see it.** `Economy` reads no Instance at
   all. The counter is a part in `Workspace`.
3. **The shop is the first inbound door this half of the game has had**, and
   `docs/design/economy.md` §1.2 item 2 named the cost: *"Spending re-opens that deliberately, in its
   own task."* This is that task, and the surface it opens is one module with one `OnServerEvent`, so
   "what can a client send this game" has one more place to look, not two.

The composition roots already carry the shape: `MatchBoot` and `ForestTestBoot` wire owners that
require none of each other (`Boar`, `Weapon`, `Bots`, `HitLog`, `Economy`, `Lobby`). `Shop` is the
seventh, wired the same way (§9).

### 2.3 Who may read the profile

**`ServerScriptService.Economy` only.** Everything else reads a **projection** of it, through one of
exactly three doors, and none of them can write:

| Reader | Door | What it gets |
|---|---|---|
| `ServerScriptService.Shop` | `world.purchase` / `world.snapshotFor`, injected at the root | a receipt, and a per-player payload |
| `ServerScriptService.Match` | `world.economy.ownedOf(userId)` — one read-only function added to the existing `Economy.view()` | the frozen ownership set, or nil |
| `ServerScriptService.Weapon` | `Weapon.setEntitlementProvider(provider)`, the fourth injected provider on that owner | the frozen ownership set, or nil |

`Economy.ownedOf` returns a **frozen copy** (`table.freeze(table.clone(...))`, the shape
`Economy.balances` already uses), so no reader can write the set it was handed.

---

## 3. The flag: `SHOP`, born OFF, and `MAX_FLAGS` goes to 13

One row in `src/shared/Flags/init.luau`:

```
SHOP = { default = false, owner = "ReplicatedStorage.Shop",
         born = "2026-10-14 task 178", expires = "2026-11-04",
         why = "A player walks up to the counter in the lodge and buys slug shells, a scoped "
            .. "rifle, a beater's licence to shoot in a drive or a coloured hat, with the coins "
            .. "the drive paid him. OFF is exactly the game before task 178: no panel, no "
            .. "inbound remote is connected, no profile field is written, the hunter carries the "
            .. "rifle and his twelve slugs, and a beater carries nothing." }
```

* **`owner = "ReplicatedStorage.Shop"`**, which is `RIFLE`'s shape (`owner =
  "ReplicatedStorage.Weapons"`) and `HORN`'s (`owner = "ReplicatedStorage.Horn"`): the flag's name
  lives in the shared module as `Shop.FLAG`, the one read is `Shop.isOn()`, and each owner calls it
  **once at its own boundary** and passes the value inward. `Weapons.FLAG = "RIFLE"` plus
  `Weapons.loadout()` is the precedent, verbatim.
* **Both branches are reachable by parameter**: `Shop.start({ enabled = true/false })` on the server
  and `ShopPanel.start(frame, { enabled = … })` on the client, which is what CLAUDE.md's feature-flag
  section requires of a flagged path.
* **`Flags.MAX_FLAGS` is 12 and twelve rows are declared** (`TIE_UNTIL_DRIVE_END`, `BOAR_SOUNDERS`,
  `ORANGE_OUTFITS`, `QUICK_TEST`, `BOAR_MODEL`, `BOAR_BEHAVIOUR`, `HORN`, `RIFLE`, `FIRST_PERSON`,
  `DRIVE_BOTS`, `COINS`, `LOBBY`), and `Flags.problems` fails the harness at thirteen. **It goes to
  13 in this task**, with the reason written beside it: the cap's own comment is *"more than twelve
  dark paths means the stack problem moved, not went away"*, and of the thirteen **seven are dark**
  (`QUICK_TEST`, `BOAR_MODEL`, `BOAR_BEHAVIOUR`, `HORN`, `DRIVE_BOTS`, `COINS`, `LOBBY`, plus this
  one makes eight). The honest line in the bump comment: *the cap counts rows, the rule is about dark
  paths, and eight dark rows is the number the Director should see*. Retiring the three accepted rows
  (`BOAR_SOUNDERS`, `ORANGE_OUTFITS`, `RIFLE` — all three already queued as TASKS.md 82b) brings it
  back under 12 without touching the cap, and that is a Director scope item (§16 item 10), not this
  task's.

### 3.1 `SHOP` depends on `COINS`, and that is stated rather than hidden

With `COINS` off, `Economy.start` *"connects nothing and loads nothing"* (its own comment), so
`sessions` is empty, `balances` is empty, and every purchase would be refused `no-profile` — a panel
of five rows each saying the wrong thing. So:

* `Economy.view()` **already carries `enabled: () -> boolean`**, added in task 170 round 2 for exactly
  this class of problem (its own comment: *"the SCREEN has to tell 'the economy is off' from 'this
  player has no profile open'"*). The shop reads it.
* When it answers false the payload carries `coinsOn = false` and the panel prints **one** line,
  `Shop.CONFIG.TEXT.CLOSED`, and draws no buy button. Not five refusals.
* A playtest therefore needs **both** overrides on:
  `python tools/flags.py set COINS on` and `python tools/flags.py set SHOP on`, then
  `python tools/flags.py clear` before the harness. Written into the flag's `why` is not enough; it
  goes in `TASKS.md`'s row for this task as the playtest recipe.

---

## 4. `ReplicatedStorage.Shop`: the catalogue and the pure rules

Types are Luau annotations: `luau-lsp analyze` is not in CI, so they are documentation plus editor
checking, not a gate (the wording `docs/design/drive.md` §9 and `docs/design/economy.md` §4 use).

### 4.1 The row

```luau
export type Grants = {
    ammo: string?,       -- an `AmmoKind` this weapon may be issued: "Slug"
    weapon: string?,     -- a `Weapons.ROWS` key: "rifle"
    driveGun: boolean?,  -- a BEATER may carry a gun in a drive
    hatColor: Color3?,   -- the cosmetic
}

export type Row = {
    id: string,
    label: string,       -- what the panel prints, <= 18 characters
    price: number,       -- coins. Karen's, and hers to retune
    hunts: number,       -- completed hunts before it unlocks
    sale: boolean,       -- false = shown and NOT buyable (see I3)
    grants: Grants,
}
```

**`grants` is the one invented thing in this file and rule 2 wants the reason**: no source has this
game's weapon ids in it. It is five rows of data read by four functions that already exist, which is
note §2.4's *"ownership is a set the loadout reads"* with our names in it.

### 4.2 `Shop.ROWS` and `Shop.ORDER`

```luau
Shop.ROWS = {
  ["ammo.slug"]      = { price =  120, hunts =  0, sale = true,  label = "SLUG SHELLS",
                         grants = { ammo = "Slug" } },
  ["licence.beater"] = { price =  250, hunts =  3, sale = true,  label = "BEATER LICENCE",
                         grants = { driveGun = true } },
  ["hat.red"]        = { price =   80, hunts =  0, sale = true,  label = "RED HAT",
                         grants = { hatColor = Color3.fromRGB(150, 38, 32) } },
  ["rifle.open"]     = { price =  600, hunts = 10, sale = FALSE, label = "RIFLE, OPEN",
                         grants = { weapon = "rifleOpen" } },
  ["rifle.scoped"]   = { price = 1500, hunts = 25, sale = true,  label = "RIFLE, SCOPED",
                         grants = { weapon = "rifle" } },
}
Shop.ORDER = { "hat.red", "ammo.slug", "licence.beater", "rifle.open", "rifle.scoped" }
```

Deep-frozen with `Shotgun.deepFreeze`, required and not copied — the idiom `Lobby.CONFIG`,
`Flags.DEFAULTS` and `Weapons.ROWS` all use, for the stated reason that `table.freeze` is shallow and
this repo has already paid for that once (`src/shared/Drive/init.luau`, Task 23a note (b)).

**`ORDER` is cheapest first**, so the first thing a player with 80 coins sees is a thing he can buy.
It is a list rather than a `slot` field per row for `Weapons.ORDER`'s stated reason: the order is one
fact and belongs in one place.

**Three invariants, each one assertion in `shop.spec`:**

* **I1 — the catalogue is small.** `#Shop.ORDER <= Shop.CONFIG.MAX_ITEMS` (8), and `ORDER` names
  every key of `ROWS` exactly once. One panel, no scrolling, no paging (note §4).
* **I2 — every price and hunt gate is a non-negative integer**, and no row's `grants` is empty. A row
  that grants nothing is a row that charges for nothing.
* **I3 — A ROW FOR SALE CAN ACTUALLY BE GRANTED.** For every row with `sale == true`:
  `grants.weapon == nil or Weapons.row(grants.weapon) ~= nil`, and
  `grants.ammo == nil or` that string is in `Weapons.ROWS.shotgun.AMMO_KINDS`. This is the assertion
  that makes note §5's *"Selling a thing that grants nothing is the one failure this repository would
  not forgive"* structural. `rifle.open`'s `grants.weapon = "rifleOpen"` has **no row in
  `Weapons.ROWS`** (Karen removed it in task 148; `Weapons.ORDER` is `{ "shotgun", "rifle" }`), so
  `sale = false` is **forced by the invariant** rather than chosen — and the day a build ships that
  weapon, flipping `sale` to true is one word and I3 is what says the word is now legal.

### 4.3 The refusal: test-then-execute, one order, one answer

```luau
Shop.REASON = table.freeze({
    CLOSED    = "shop-closed",    -- there is no money in this build at all
    UNKNOWN   = "unknown-item",   -- no such row: a forged or stale id
    NOT_SALE  = "not-for-sale",   -- in the catalogue, sale = false
    NO_PROFILE= "no-profile",     -- no open ProfileStore session for him
    TOO_FAR   = "too-far",        -- he is not at the counter
    OWNED     = "owned",          -- he already has it
    LOCKED    = "locked",         -- not enough completed hunts
    POOR      = "poor",           -- not enough coins
})

Shop.NOTICE = table.freeze({
    [Shop.REASON.CLOSED]     = "THE SHOP IS CLOSED",
    [Shop.REASON.UNKNOWN]    = "NO SUCH ITEM",
    [Shop.REASON.NOT_SALE]   = "SOON",
    [Shop.REASON.NO_PROFILE] = "YOUR ACCOUNT IS NOT LOADED",
    [Shop.REASON.TOO_FAR]    = "STAND AT THE COUNTER",
    [Shop.REASON.OWNED]      = "YOU OWN IT",
    [Shop.REASON.LOCKED]     = "LOCKED: %d HUNTS",
    [Shop.REASON.POOR]       = "YOU NEED %d COINS",
})

Shop.ORDER_OF_REFUSAL = table.freeze({
    Shop.REASON.CLOSED, Shop.REASON.UNKNOWN, Shop.REASON.NOT_SALE,
    Shop.REASON.NO_PROFILE, Shop.REASON.TOO_FAR,
    Shop.REASON.OWNED, Shop.REASON.LOCKED, Shop.REASON.POOR,
})

export type Context = {
    itemId: any,                        -- whatever arrived: validated here, not trusted
    coinsOn: boolean?,                  -- the economy's own `enabled()`
    hasProfile: boolean?,               -- a session is open for him
    atCounter: boolean?,                -- the door answered it
    owned: { [string]: boolean }?,
    balance: number?,
    hunts: number?,
}

Shop.refuse(context: Context): (string?, number?)   -- PURE: the reason, and the number its line needs
```

* **It is OpenTTD's `CommandCost`** (note §2.3): one function answers *may this happen* before
  anything is written, and the reason is **data** rather than a thrown error, carrying the number the
  line prints. The repo has adopted it once already — `src/server/Weapon/Rules.luau`, whose
  `Rules.refuse` walks `Rules.ORDER` and returns the first reason — and this is a second instance of
  that exact shape, named.
* **The order is declared and testable** for `Rules.ORDER`'s stated reason: *"an ORDER is a rule, and
  a rule nobody can assert is a rule that drifts"*. Why this order: facts about the **build** first
  (closed), then about the **item** (unknown, not for sale), then about the **session and the place**
  (no profile, too far — things he can fix by waiting or walking), then about **him and the item**
  (owned, locked, poor — which only mean anything once the other five have passed).
* **Nil is "nothing said" everywhere.** `coinsOn == nil`, `hasProfile == nil` and `atCounter == nil`
  do **not** refuse: a caller that answered nothing has not said no, which is the call
  `Rules.driveClosed` and `Rules.outsideStand` already make and the reason they make it (*"a gate that
  refused on an unwired world would make a mis-wiring look exactly like Karen's rule working"*). The
  door and `Economy.purchase` both pass explicit booleans, so no production path reaches a nil.
* **`owned == nil` means he owns nothing, here and only here.** This is the one reader where nil is
  not "unrestricted" (§7.1), and it is not a contradiction: this function is asked *"shall I take his
  money"*, and the safe answer to an unknown ownership set is "he does not own it, so the purchase may
  proceed" — he is then charged once and `OWNED` refuses the second click off the set that was
  actually written.

### 4.4 The other pure functions

```luau
Shop.row(id: any): Row?
Shop.isOn(): boolean                                  -- the ONE flag read; Weapons.loadout()'s shape
Shop.FLAG = "SHOP"

-- IS HE AT THE COUNTER? FLAT (the Y is ignored) and `<=` (on the line is in).
Shop.withinReach(position: Vector3?, counter: Vector3?, reachStuds: number): boolean

-- THE WHITELIST ON WHAT A CLIENT MAY SEND. `Weapon.Validator.checkRequest`'s shape.
Shop.checkRequest(kind: unknown, item: unknown): (boolean, string?)

-- WHAT THIS WEAPON STARTS A DRIVE WITH, given what he owns.
Shop.startFor(row: any, owned: { [string]: boolean }?): { ammo: string, reserve: { [string]: number } }

-- MAY A BEATER CARRY A GUN? false for nil, false for {}, true when `licence.beater` is in the set.
Shop.grantsDriveGun(owned: { [string]: boolean }?): boolean

-- HIS HAT'S COLOUR, or nil for "the default orange".
Shop.hatColorFor(owned: { [string]: boolean }?): Color3?

-- THE PANEL'S BODY, one entry per catalogue row, already decided. PURE and exported.
Shop.rowsFor(owned, balance: number?, hunts: number?, coinsOn: boolean?): { WireRow }
```

**`Shop.withinReach` is the THIRD instance of one subtraction in this repo and that is a decision,
not an oversight.** The other two are `ForestTest.withinStand` (*"Pure, so the boundary is one rule
and not one rule per reader"*) and `Lobby.Join.within`, which cites it. There is no shared home for
it: `Join` is a **server** module (`src/server/Lobby/Join.luau`) and a shared module may not require
one; `ForestTest` is one world's data. So each owner's own boundary carries the arithmetic, and
**`shop.spec` asserts that all three agree** on the same three cases (inside, on the line, outside) —
a test may require all three, which is the cheapest possible guard against the drift this repo is
most afraid of. Folding the three into one shared predicate is a queued item for the Director (§16
item 9), not this task.

**`Shop.rowsFor` is the pure formatter returning a list for a renderer to lay out** — the idiom
`Match.quarryLines`, `Hud.startCardLines` and `Hud.scorePanelLines` already establish, and it is why
the panel decides nothing (§5.2).

### 4.5 `Shop.CONFIG`

Shared (both sides read it) and deep-frozen. It holds **words, layout and the door's two numbers**,
and **no economy rate**: `COINS_PER_POINT`, `PARTICIPATION`, `FIRST_PLACE` and `FLOOR` stay in
`Economy.CONFIG` on the server, unreplicated, which `tests/client/match_client.spec.luau` already
asserts by pattern.

| Field | Value | Reads as |
|---|---|---|
| `MAX_ITEMS` | `8` | one panel, no scrolling (I1) |
| `REACH_STUDS` | `14` | the counter is 12 studs wide (`Lobby.CONFIG.LODGE.COUNTER = Vector3.new(12, 3.5, 2)`); a man at either end reaches it |
| `REQUEST_MIN_INTERVAL` | `0.25` | 4 requests/second/player (note §4) |
| `BUTTON_PX` | `48` | `Rail.CONFIG.BUTTON_PX`, over Roblox's own 44 px touch minimum |
| `PANEL` | `{ WIDTH = 420, ROW_PX = 48, GAP = 8, Z_INDEX = 15 }` | `Report.CONFIG.PANEL_Z_INDEX` is 15 and the rail is 16, so the rail stays pressable over it |
| `TEXT` | the lines in §4.3 plus `TITLE = "SHOP"`, `CLOSED`, `BALANCE = "COINS %d"`, `CLOSE = "CLOSE"`, `BUY = "BUY"`, `OWNED_TAG = "OWNED"` | every word the panel draws is written down — `Drive.CONFIG`'s own rule |

Prices and hunt gates live in `Shop.ROWS`, not here: they are the catalogue, and the catalogue is one
table (note §3 item 1).

---

## 5. The client: `Hud.ShopPanel`

### 5.1 The frame is the Hud's, the contents are the panel's — including `Visible`

`Hud.build` creates one `ShopPanel` frame with the rest of the screen. `src/client/Hud/init.luau`'s
header states the rule and the exception in one place: the report panel and the compass are built by
the Hud and filled by their modules, and the map is the *"ONE place this file does NOT copy the
compass's two-writer arrangement"* — `MapUi` owns its own `Visible`. **The shop follows `MapUi`**,
because the panel's open/closed state is a thing the player and the counter decide and the Hud has no
second opinion about it. So:

* **one ScreenGui** (`HunterHud`), built once, so a visibility audit has one place to look;
* `Hud.shopPanel(): Frame?` for a spec, the `Hud.reportPanel()` / `Hud.minimap()` shape;
* `Hud.Shop = ShopPanel`, so the module is found where the Hud starts it.

### 5.2 It draws what arrived and decides nothing

The panel's only arithmetic is pixels. Every word, every price, every `OWNED` / `SOON` / `LOCKED` tag
and the affordability of every row arrives as `WireRow` from the server (§6.2), built by the pure
`Shop.rowsFor`. The rule `ReportPanel` already states: *"IT DRAWS WHAT ARRIVED AND COMPUTES NOTHING …
so two clients can never disagree"*.

### 5.3 Its four pieces of state, and it is the only writer of all four

`open`, `payload`, `message`, `selected` — the `ReportPanel` shape (*"IT HOLDS FIVE PIECES OF STATE
AND IS THE ONLY WRITER OF ALL FIVE"*).

### 5.4 How it learns it is at the counter: it is TOLD

`Hud.renderObjective` is already *"THE ONE EVALUATION OF 'WHAT MUST I DO, AND WHERE', AND THE ONE CALL
TO EACH DRAWER"*, and it already holds both facts it needs — `me = Hud.localPosition()` and
`lobbyData`, resolved through `Hud.whenReady(ReplicatedStorage, "Lobby", …)`. One line is added there:

```
ShopPanel.setNear(Shop.withinReach(me, lobbyData and lobbyData.counterPosition(), Shop.CONFIG.REACH_STUDS))
```

* **`near` is TOLD to the panel and never read inside it** — `Rail.setWeapon`'s stated rule
  (*"`hasWeapon` is TOLD to this module by the Hud, never read here"*), so there is one reader of the
  player's position in the Hud and the panel learns nothing about the world.
* **No new client clock.** The existing `RenderStepped` connection that calls `renderObjective` is the
  tick. `MapUi`'s own 20 Hz `Heartbeat` is not needed and is not added.
* **`setNear` is edge-triggered inside the panel**: on `false -> true` it binds `DrivenHunt.Shop.Toggle`
  and (if `AUTO_OPEN`) opens; on `true -> false` it unbinds and closes. One write per change, not one
  per frame — `Lobby`'s `setRespawn` and its `nil -> COUNTING` attribute write are the precedent
  (*"It used to be written on every scan: ~50 replicated attribute writes per walk-in"*).

### 5.5 Input: one key, one button, both mobile-friendly

* **`E`** through `ContextActionService`, action name `DrivenHunt.Shop.Toggle`, under the reserved
  prefix convention `GAME_DESIGN.md`'s *Input* row sets out and `ReportPanel`'s
  `DrivenHunt.Report.*` follows. **`E` is free**: the only bound keys in `src/` today are `Tab`
  (`Report`), `R` and `X` (`Weapon.Input`), `M` (`MapUi`), and `Backspace`/`Return`/the four arrows
  (`ReportPanel`). It is bound **only while he is at the counter**, so it can never collide with a key
  a later task wants.
* **One `TextButton` per buyable row plus a `CLOSE` button**, all `>= Shop.CONFIG.BUTTON_PX` (48) tall,
  all driven by `GuiButton.Activated` — *"one event for a click AND a tap, which is why the rail needs
  no touch branch at all"* (`Rail`'s own citation). A `CLOSE` button inside the panel rather than a
  rail row, because the rail's `needsWeapon` rule has exactly two states and a third
  (`needsCounter`) would be a visibility rule in two modules.
* **`ShopPanel.press(id): boolean`**, a named public handler every button calls, for `Rail.press`'s
  stated reason: *"a spec cannot fire `GuiButton.Activated` and the harness cannot synthesise a tap …
  so this is the seam that makes the rail testable at all — and what it proves is the ACTION, not the
  touch. That limit is reported, not papered over."* The same limit applies here and is reported in
  §13.
* **A click must not fire the gun.** `Weapon.Input`'s tagged hold already exists for this
  (`requestHold` / `releaseHold` / `isHeld` / `holdTags`, added for the report panel in task 124). The
  shop takes the hold while open, tag `"shop"`, and releases it on close — no new mechanism.

### 5.6 Where the balance comes from, and why not the drive snapshot

**A player standing in the lobby has no score row**, so `MatchSnapshot`'s `coins` field (task 170,
`docs/design/economy.md` §6) is absent for him: with the lobby on, `Match` is started with
`world.enrol` and `watchPlayer` does not dispatch a `join` until he is enrolled, and the lobby clears
the roster at `Scoring`. So the panel **cannot** read his balance off the drive wire, and the shop's
own payload carries it (§6.2). That is also the better answer on its own terms: a wallet is one
player's business, and `docs/design/economy.md` §6 already wrote down the cheaper draw-only-your-own
variant as the reversible option. This is it, for the one screen that needs it.

---

## 6. The wire (brief §3 item 3)

### 6.1 Two RemoteEvents in one folder

`src/shared/Shop/Remotes.model.json` — the `Shotgun/Remotes.model.json`, `Drive/Remotes.model.json`,
`Report/Remotes.model.json` shape:

```json
{ "className": "Folder",
  "children": [ { "name": "ShopRequest", "className": "RemoteEvent" },
                { "name": "ShopState",   "className": "RemoteEvent" } ] }
```

`Shop.remotes()` resolves them with `WaitForChild`, memoised once, exactly as `Shotgun.remotes()` and
`Report.remotes()` do.

### 6.2 Inbound: client -> server, two fields and nothing else

```luau
export type Request = { kind: string, item: string? }   -- kind is "open" or "buy"
```

**No price, no balance, no position, no userId.** The server knows all four better than the client
does. The whitelist is the pure `Shop.checkRequest(kind, item)`:

| It refuses | Reason | Why it cannot be anything else |
|---|---|---|
| a non-table, or `kind` not a string | `bad-request` | `Validator.checkShot`'s `bad-type` |
| `kind` not in `{ "open", "buy" }` | `bad-request` | `Validator.checkRequest`'s closed set: *"only 'Reload' and 'SelectAmmo' cross the wire"* |
| `kind == "buy"` with `item` not a string | `bad-request` | |
| `kind == "open"` with `item ~= nil` | `bad-request` | an argument nobody reads is an argument nobody checked |
| a string longer than `MAX_ID_CHARS` (32) | `bad-request` | a bound before the table lookup |

An `item` that is a well-formed string naming no row is **not** a bad request: it is
`Shop.REASON.UNKNOWN`, counted separately (`stats.unknownItems`), because a stale client after a
catalogue change is a different fact from a forged packet and a report that conflates them cannot be
acted on. That distinction is `Weapon`'s own (`stats.refused` vs `stats.badRequests`:
*"a refused shot is a LEGAL request that the game said no to, and counting it as a bad request would
hide a mis-wired provider inside the forgery counter"*).

### 6.3 Outbound: server -> **that one client**, by `FireClient`

```luau
export type WireRow = {
    id: string, label: string, price: number, hunts: number,
    sale: boolean,
    owned: boolean,
    locked: boolean,        -- hunts not met
    afford: boolean,        -- price <= balance
    buyable: boolean,       -- sale and not owned and not locked and afford: the ONE field the button reads
}

export type State = {
    coinsOn: boolean,       -- is there money in this build at all (§3.1)
    balance: number?,       -- nil = no open profile, which is NOT zero (Economy.balanceOf's rule)
    hunts: number,
    rows: { WireRow },      -- dense array, in Shop.ORDER
    refused: string?,       -- one of Shop.REASON, for the LAST buy attempt
    refusedNumber: number?, -- the number its line needs (coins short, hunts short)
    bought: string?,        -- the item id a successful purchase just granted
}
```

* **Dense arrays and pure dictionaries only** — `Report`'s own stated rule: *"a table that is neither
  a dense array nor a pure dictionary does not survive the wire faithfully"*.
* **`buyable` is computed once, on the server, and is the only field the button reads.** Two readers
  of "can he buy this" is how a greyed-out button and an accepted purchase disagree.
* **Sent on exactly two occasions, both pulled**: an accepted `open` request, and after **every**
  `buy` attempt (granted or refused). No clock, no broadcast, no push on a balance change — a wallet
  that changed while the panel was shut is read the next time he opens it.
* **Guarded by `player.Parent ~= nil`** before every `FireClient`: he may have left between the
  request and the reply.

### 6.4 What does NOT change

`MatchSnapshot`, `MatchEvent`, `FeedEntry`, `Report`'s three remotes and the weapon's five are all
untouched. No shop line in the kill feed, no coin line on the drive bar beyond the balance task 170
already put there.

---

## 7. The four readers, and the exact boundary of each (brief §3 item 1)

### 7.1 The rule that governs all four: the default is TODAY'S GAME

Every reader asks one question of one injected provider and gets `{ [string]: boolean }?`. **`nil`
means "nobody answered", and what that resolves to is whatever this reader did before task 178** —
which is **not** the same boolean in all four:

| Reader | `owned == nil` | `owned == {}` | `owned` has the item |
|---|---|---|---|
| `Weapons.loadoutFor(rifleOn, owned)` | `{ "shotgun", "rifle" }` — **unrestricted** | `{ "shotgun" }` | `{ "shotgun", "rifle" }` |
| `Shop.startFor(row, owned)` | `row.INITIAL_AMMO` / `row.START_RESERVE` — **unrestricted** | `Buck` / `{ Slug = 0, Buck = 12 }` | `Slug` / `{ Slug = 12, Buck = 12 }` |
| `Match.mayCarryWeapon` (a Driver) | `config.DRIVERS_MAY_SHOOT` — **refused**, today's answer | the same | `true` |
| `Match.Body.dress`'s hat colour | `OUTFIT_COLOR` (hunter orange) — **unrestricted** | the same | the row's `Color3` |

**Why the directions differ, in one sentence:** today a hunter *has* the rifle and his twelve slugs
and an orange hat, and a beater *has no gun* — so "nobody answered" must give him all three and must
not give him the fourth. Writing it as "nil means unrestricted" would arm every beater in every world
that never wired a provider, including every `tests/server/weapon_*.spec.luau`.

**The provider returns nil, not `{}`, whenever the shop cannot answer**: the flag is off, the economy
is off, or this player has no open profile session. So a DataStore outage costs him nothing he paid
for; the alternative (strip the rifle when the profile will not load) loses a man the weapon he bought
because Roblox hiccuped, and *"a number in the harness report, not a safety rule that silently never
fires"* is this repo's standing preference. The cost is named: during an outage a player who owns
nothing is handed the rifle for one drive. It is reversible in one line and it is **the Director's**
(§16 item 4).

### 7.2 `ReplicatedStorage.Weapons` — the rifle

```luau
Weapons.loadoutFor(rifleOn: boolean, owned: { [string]: boolean }?): { WeaponId }   -- PURE
Weapons.loadout(owned: { [string]: boolean }?): { WeaponId }   -- the ONE flag read, unchanged
```

The flag read stays exactly where it is (`Weapons.loadout`'s own comment: *"THE ONE FLAG READ IN THE
WHOLE WEAPON SYSTEM, at this boundary, passed inward as a list"*). The set is a second parameter, and
the entitlement for a weapon id `w` is the row whose `grants.weapon == w` — resolved by a pure
`Shop.ownsWeapon(owned, id)`, so `Weapons` requires `Shop` and not the reverse (both are shared,
`Weapons` already requires four shared modules).

`Weapon.refreshArming(player, loadout?)` **already takes the loadout as a parameter with a default**,
added in task 141 for exactly this reason (its own comment: *"the flag's two worlds must both be
reachable without the flag"*). Production changes from `Weapons.loadout()` to
`Weapons.loadout(askOwned(player))`, where `askOwned` is the pcall-ed provider read (§7.6). Nothing
else in that function changes, and `Weapon.armingAction` stays pure and per weapon.

### 7.3 `ServerScriptService.Weapon` — the slug allowance

**Karen's ladder makes buckshot the default and slugs a purchase** (*"shotgun buckshot (default) ->
slugs"*, accepted with *"yes that seems legit"*). Today it is the other way round:
`Shotgun.CONFIG.INITIAL_AMMO = "Slug"` and `START_RESERVE = { Slug = 12, Buck = 12 }`
(`src/shared/Shotgun/init.luau`, `DRIVE_SHELLS`). So with `SHOP` **on** and no `ammo.slug`
entitlement a hunter starts a drive on Buck with an empty slug pocket, and with `SHOP` **off**
nothing about his gun changes by a byte.

**`Shotgun.CONFIG` is NOT edited.** The row stays the one source of every shotgun number
(`rifle.spec` asserts it field by field). What changes is the **state** the owner produces from the
row, and the owner is already the only producer of it:

```luau
StateMachine.initial(row, start: { ammo: string?, reserve: { [string]: number }? }?): WeaponState
```

* `start == nil` -> `row.INITIAL_AMMO` and `table.clone(row.START_RESERVE)`: **every existing caller
  and every weapon spec is untouched**, which is what `StateMachine.initial`'s own history asks for
  (*"a two-barrel shotgun and a one-chamber rifle start from the same function with no branch in it"*).
* `Weapon.grant` and `Weapon.revoke` — the two call sites — pass `Shop.startFor(row, askOwned(player))`.

**The refill carries the allowance on the ACTION, not as a fifth parameter:**

```luau
export type Action = { kind: ActionKind, ammo: AmmoKind?, reserve: { [string]: number }? }
```

`StateMachine.apply`'s `Refill` branch uses `action.reserve or config.START_RESERVE`. This is safe at
the wire by construction and the file already says why: *"`Refill` … is a SERVER-SIDE primitive:
`Validator.checkRequest` accepts only 'Reload' and 'SelectAmmo' over the wire, so no client can ask
for it"* — so no client can send a `Refill` at all, let alone one carrying a reserve.
`Weapon.refillForDrive` passes `{ kind = "Refill", reserve = Shop.startFor(row, owned).reserve }` per
weapon, from each weapon's own row, which is the rule that function already states.

**What stops a player switching to slugs he does not own:** nothing new. `StateMachine.apply`'s
`SelectAmmo` and `Load` branches already refuse an empty pocket (`"no-reserve"`), and the
`SelectAmmo` comment already describes the intended behaviour — *"switch and reload to it — refusable
when that pocket is empty"*. An unowned slug pocket is 0, so the existing rule is the enforcement and
there is no second gate.

### 7.4 `ServerScriptService.Match` — the beater's licence

```luau
function Match.mayCarryWeapon(player: Player): boolean
    if state.phase == "Waiting" then return false end
    if tied[player.UserId] then return false end
    local team = state.assignment[player.UserId]
    if team == "Shooters" then return true end
    if team ~= "Drivers" then return false end
    if config.DRIVERS_MAY_SHOOT then return true end
    return Shop.grantsDriveGun(world and world.economy and world.economy.ownedOf(player.UserId))
end
```

* **One fact in, one pure question.** `Match` already requires `ReplicatedStorage.Licences` (for
  `Licences.SPECIES_ATTRIBUTE` in `Match.classifyTarget`), so requiring a second frozen shared data
  module is precedented and adds no owner edge.
* **One provider, not two.** The hat (§7.5) asks the same `ownedOf` and a different pure function.
  Two injected providers for one fact would be two answers to "what does he own".
* **`world.economy` absent -> this function before task 178, by every branch.** Every
  `tests/server/match_*.spec.luau` that does not inject an economy is untouched.
* **The three "licences" in this game are three different things and must not be conflated** — this is
  the `Match.Penalty` warning (*"four questions in one predicate is how 'one predicate answered two
  unrelated questions' happened in the previous project"*) applied to a word rather than a predicate:

  | Name | What it is | Who reads it | Touched here? |
  |---|---|---|---|
  | `ReplicatedStorage.Licences` | a **species** permit (red deer) | `Weapon.Rules.unlicensed`, through `Weapon.setLicenceProvider` | **No.** `setLicenceProvider` stays unwired, exactly as its own comment says (*"The shop task wires it"* — it does **not**, and §16 item 6 says so) |
  | `licence.beater` | a **beater's** permission to carry a gun in a drive | `Match.mayCarryWeapon` only | Yes |
  | `owned` | the shop entitlement set | the four readers | Yes |

  **Why `setLicenceProvider` is deliberately left unwired:** no deer exists, `Licences.ROWS.boar` is
  `licence = false`, and `Licences.ROWS.reddeer.price` is nil *"because the shop does not exist and a
  number here would be a decision nobody has taken (it is Karen's, with the shop task)"*. A species
  permit is a **fifth** item in the catalogue for an animal that is not in the game: it would be the
  thing invariant I3 exists to forbid. Karen names its price the day a deer exists (§16 item 7).

**The task-171 fire rules are otherwise unchanged, and one of them is load-bearing in his favour and
one against:**

* `Rules.beaterInLine` **still refuses him a shot at a beater**: `Match.classifyTarget` answers
  `{ beater = state.assignment[userId] == "Drivers" }` off the roster and knows nothing about
  entitlements.
* `Rules.outsideStand` **does not hold him to a stand**: `Match.standAreaOf` returns nil for a
  non-Shooter (*"a beater is not held to a stand"*), which is already correct for him.
* `Match.Penalty.judge` **ties him like anybody else**, with **no exception to write**. That file
  already anticipated this exact day: *"Never yourself. It cannot happen in v1 (a driver carries no
  gun) but it can the day `DRIVERS_MAY_SHOOT` is true, and the design says there is no exception to
  write then."* A bought licence reaches the same branch that flag opens. **The licence buys him a
  gun, not an exemption from the safety rule** — and whether that is the game Karen wants is a feel
  question (§16 item 3), answerable without a code change.

### 7.5 `Match.Body` — the hat colour

```luau
Body.dress(character: Model?, team: TeamName?, config, look: { hatColor: Color3? }?): boolean
Body.dressFor(team: TeamName?, config, look: { hatColor: Color3? }?): { any }      -- PURE
Body.dressWhenLoaded(player: Player, character: Model, config, look: { hatColor: Color3? }?)
```

* `look == nil` -> `OUTFIT_COLOR`, hunter orange RGB(255, 112, 0): **today's game**, and every
  `match_outfit.spec` case that passes three arguments is untouched.
* **`Body` stays the one writer of what a character wears.** It is handed a colour, not an ownership
  set: the module that dresses people must not learn what a shop is, which is the same seam
  `Body.setAccessorySource` already is (*"`Match.Body` must not learn what `ServerStorage.Assets`
  calls anything. The composition root translates"*).
* **`Match` resolves it** at the one place it already calls `dressWhenLoaded`, from the same
  `world.economy.ownedOf` read as §7.4, through the pure `Shop.hatColorFor`.
* **It reaches both wear paths.** `Body.dress` wears a real catalogue accessory when one is loaded and
  falls back to the plates (*"Never both, which is what makes the count per role a thing a spec can
  assert"*). The colour is written to **both**: the plate rows take it in `Body.fit`'s row, and
  `wearAccessory` writes `Color` on the accessory's `BasePart` descendants in the same loop that
  already writes `CanQuery`, `CanTouch`, `CanCollide`, `CastShadow` and `Massless`. A colour that
  only showed on the fallback would be a cosmetic Karen cannot see once the real cap loads.
* **The vest is not recoloured.** It is safety orange on both roles for the reason `OUTFIT_COLOR`'s
  comment gives (*"In the field both sides wear safety orange"*). One cosmetic, one slot, this task.

### 7.6 How the Weapon owner is wired

One new provider, the fourth on that owner, in the shape the other three already have:

```luau
Weapon.setEntitlementProvider(provider: ((Player) -> { [string]: boolean }?)?)
```

and `askOwned(player)` is a **pcall**, the rule that file already states: *"EVERY PROVIDER IS CALLED
THROUGH `pcall` … a provider that errors must not leave a player permanently unable to shoot AND must
not silently remove the rule. It falls back to 'no restriction'"* — which here is `nil`, which is
today's game (§7.1).

---

## 8. The profile (brief §3 item 4)

### 8.1 The shape

```luau
Store.TEMPLATE = {
    schema = 1,
    coins = 0,
    coinsEarnedTotal = 0,
    drivesPaid = 0,          -- COMPLETED HUNTS. See 8.3
    owned = {},              -- itemId -> true. A PURE DICTIONARY of string keys
}
```

* **`owned` is a set, not a list and not a count.** ioquake3's `ps->stats[STAT_WEAPONS] |= 1 << weapon`
  read as a Luau table (note §2.4): *"Ownership is a set; the thing owned stays where it was
  declared."* Nothing per-player is stored about a weapon except its id.
* **The store name does not change.** `"DrivenHuntPlayer_v1"` stays: this is an **additive** change,
  and `Economy.CONFIG.STORE_NAME`'s own comment says a `_v2` is for *"a change `Store.read` cannot
  make additively"*.
* **A build that does not know about `owned` keeps it.** `Store.read`'s keep-unknown-keys half is
  exactly this case and its comment already names it: *"A build that does not know about `trophies`
  must not delete the trophies a newer build wrote."* Rolling back past task 178 leaves every
  purchase in the key, unread; rolling forward again restores it.
* **A profile written before task 178 gets `owned = {}` and `drivesPaid` as it stands**, from
  `Store.read`'s fill-missing-keys half.

### 8.2 Two changes `Store` must make, and they are forced

**(a) `Store.read` must CLONE a table-valued template default, and `Store.TEMPLATE` must be frozen.**
Today `Store.read` does `out[key] = value` straight from the template. With `owned = {}` in the
template that hands **every profile the same table**, and the first purchase would write into the
template itself — one player's hat would be worn by every player on the server, and by every player on
the next server too, because the module is required once per process. The fix is two lines and both
halves are needed:

```luau
if out[key] == nil then
    out[key] = if type(value) == "table" then table.clone(value) else value
end
```

plus `Drive.deepFreeze(Store.TEMPLATE)` at declaration, so a mutation of the template **errors loudly**
instead of corrupting silently. `economy_store.spec` asserts both: two profiles read from the same
template have `owned` tables that are not `==`, and writing to `Store.TEMPLATE` throws.

**(b) `load` and `save` must widen, and the derived counters must come out of the store.** Today:

```luau
load: (userId) -> (number?, string?)                 -- the BALANCE
save: (userId, balance: number) -> boolean           -- and it derives coinsEarnedTotal and drivesPaid
```

The second is the problem. `Store.memory`'s and `Store.live`'s `save` both do
`data.drivesPaid += 1` on **every call**, which is correct today because `payDrive` is the only
caller — and becomes a **bug the moment a purchase calls `save`**: buying a hat would count as a
completed hunt. So:

```luau
load: (userId: number) -> ({ [string]: any }?, string?)   -- YIELDS. The profile through Store.read
save: (userId: number, fields: { [string]: any }) -> boolean  -- writes exactly the named fields. Derives NOTHING
```

* **A profile is one table** (note §2.1: ProfileStore's own model), so handing it over whole is what
  the library's shape already is; `load -> number` was task 170's projection of it, and the projection
  belongs to the owner that knows which fields it wants. `Economy.load` becomes
  `local data = …; balances[userId] = data.coins; owned[userId] = data.owned; hunts[userId] = data.drivesPaid`.
* **`coinsEarnedTotal` and the hunt increment move into `Economy.payDrive`**, which is where the delta
  and the event are both known. The store writes what it is told, which is the only way "who increments
  this" has one answer.
* **`Store.memory`'s `seed` widens** from `{ [number]: number }` to `{ [number]: { [string]: any } }`
  (a profile per userId), so a spec can seed a balance, a hunt count **and** an ownership set in one
  line. Its `refuse` option is unchanged. Both are *"the double AND the Studio path"* and neither is a
  production test seam — that reasoning is unchanged.
* **`Store.live` writes no more network calls than before.** `save` is still *"NOT A NETWORK CALL"*:
  it writes `profile.Data` fields and the library's own auto-save and `EndSession` do the writing.
  **Purchases per DataStore request: 0.**

### 8.3 The hunt count is `drivesPaid`, and there is no second field

Brief §1 item 8 asks for completed hunts in the profile. `Store.TEMPLATE.drivesPaid` **already counts
exactly that event**: it rises once per player per paid drive, and `Coins.forDrive` skips a row with
`left == true` (*"`PARTICIPATION` is … for turning up **and finishing** the drive"*), so it is "drives
he finished and was paid for" — which is what "completed hunts" means.

**A separate `hunts` field is refused**, with the reason written down: it would be incremented by the
same line on the same event, so the two could only ever hold the same number, and two names for one
fact is this project's named failure mode (`docs/PROJECT_CONTEXT.md`: *"Most of the worst bugs were two
correct pieces of code disagreeing"*).

**The key is not renamed**, because renaming a persisted key under one store name orphans the old one
and restarts everybody at 0. Instead:

* the field's comment is **amended** to name both readers — the double-pay forensic **and** the
  unlock gate — and to state that they are the same number by construction, one event, one increment,
  in `Economy.payDrive`;
* the reader is the accessor `Economy.huntsOf(userId): number?`, so no caller outside `Economy` ever
  types `drivesPaid`. The day it is renamed, one function changes.

**The consequence, named:** with `COINS` off nothing is ever paid, so the count stays 0 and every
hunt-gated row stays locked for ever. That is already the state §3.1 draws as `THE SHOP IS CLOSED`,
so the two facts agree on screen.

---

## 9. The purchase: order of operations (brief §3 item 2)

### 9.1 The two halves, and the single call that writes

```
client  --ShopRequest{kind="buy", item}-->  ServerScriptService.Shop.onRequest(player, request)
  1. Shop.checkRequest(kind, item)                  PURE. bad-request -> counted, NO reply, return
  2. the rate bucket for this player                over the limit -> counted, NO reply, return
  3. atCounter = Shop.withinReach(root, counterAt(), REACH_STUDS)      the only world read
  4. receipt = world.purchase(player.UserId, item, { atCounter = atCounter })
  5. FireClient(player, world.snapshotFor(player.UserId, receipt))     if player.Parent ~= nil
```

and inside `Economy.purchase`, which is the **only** writer:

```
  a. row = Shop.row(itemId)
  b. reason, number = Shop.refuse({ itemId = itemId, coinsOn = enabled,
         hasProfile = sessions[userId] ~= nil, atCounter = facts.atCounter,
         owned = ownedSets[userId], balance = balances[userId], hunts = huntsOf(userId) })
  c. reason ~= nil -> count it, return { ok = false, refused = reason, number = number }.  NOTHING WRITTEN
  d. balances[userId] = balances[userId] - row.price            -- half one
  e. ownedSets[userId] = <a NEW table, the old one plus itemId> -- half two
  f. store.save(userId, { coins = balances[userId], owned = ownedSets[userId] })
  g. return { ok = true, item = itemId, price = row.price, balance = balances[userId] }
```

**Steps b to f contain no yield.** `Store.save` performs no network call by contract, Luau is
single-threaded per server, and the handler is not a coroutine that waits — so the test and the
execute are **atomic by construction**, not by a lock. This is the identical claim `Economy.payDrive`
makes and the identical reason, and `economy.spec` times it the same way.

**Step e replaces the set whole rather than writing a key into it.** Two reasons: `Economy.ownedOf`
hands out frozen copies and a reader may be holding one, and a replaced table is what makes "no
previous state can linger" provable — the rule `payDrive`'s `earnedThisDrive` already follows
(*"REPLACED WHOLE, never merged"*).

### 9.2 The six cases brief §3 item 2 names

| Case | What happens | What makes it so | Proved by |
|---|---|---|---|
| **A double click** | the first charges, the second is refused `owned` | step b asks `owned` **before** step d, and step e wrote the id. Idempotence is the one transferable idea from `ProcessReceipt` (note §2.5) | `economy.spec`: purchase twice, `balance` fell by `price` **once**, `stats.refusedBy.owned == 1` |
| **A forged item id** | refused `unknown-item`, counted, nothing written | `Shop.row` is a lookup in a frozen literal; a registry that could be added to at run time is what `Weapons`' header refuses | `shop_door.spec`: `onRequest` with `"rifle.free"`, then `Economy.balanceOf` unchanged |
| **A forged price** | impossible: **no price crosses the wire inbound** (§6.2). The only price is `Shop.ROWS[id].price`, read on the server from a deep-frozen table | the `Request` type has two fields | `shop.spec`: `Shop.checkRequest` refuses every extra field |
| **No open profile session** | refused `no-profile`, counted, nothing written, and **no coin is invented**: `balances[userId]` is nil, which `Economy.balanceOf`'s rule says is *"not the same fact as a balance of zero"* | step b's `hasProfile` | `economy.spec` with `Store.memory{ refuse = { [7] = true } }` |
| **He leaves between the request and the commit** | `Players.PlayerRemoving` -> `Economy.release` drops `sessions[userId]` -> step b refuses `no-profile`. If he leaves after the commit, the purchase is his and `Store.release` -> `EndSession` saves it | `Economy.release` is already idempotent and already keyed on `sessions` | `economy.spec`: release, then purchase, then `stats.refusedBy["no-profile"]` |
| **He walks away mid-panel** | refused `too-far`. The client's panel closing is cosmetic; the server's reach read at step 3 is the rule | step 3 runs per request, never cached | `shop_door.spec` with an injected `counterAt` 100 studs away |

### 9.3 Where the counter position comes from

**One definition, and it is the part the server built.** `ReplicatedStorage.Lobby` gains the reader,
alongside `Lobby.spotPart` and for its stated reason (*"The server BUILDS the part; this finds it;
nobody computes the position twice"*), with the same memoisation and the same
`IsDescendantOf(game)` drop so *"a streamed-out or rebuilt lobby must answer nil rather than a stale
position"*:

```luau
Lobby.COUNTER_NAME = "Counter"
Lobby.counterPart(): BasePart?
Lobby.counterPosition(): Vector3?
```

It finds `Workspace.Lobby` -> `FindFirstChild("Counter", true)`, which is where
`src/server/Lobby/Build.luau`'s `interior` puts it (under `Lodge.Inside.Shop`). **The server shop
reads it through an injected seam**, `world.counterAt: () -> Vector3?`, defaulted to
`Lobby.counterPosition` by the composition root — so the reach rule is drivable in a spec in the DEV
place, which has no lodge at all (§10.4). The `world.standArea` idiom.

---

## 10. Lifecycle and the composition roots

### 10.1 `ServerScriptService.Shop`'s interface

```luau
Shop.Data                      -- ReplicatedStorage.Shop, re-exported for the specs
Shop.ENABLED                   -- = Shop.Data.isOn(): the one flag read at THIS boundary

Shop.start(injected: World?): boolean    -- asserts it is not started twice; NOTHING ON REQUIRE
Shop.stop()                              -- disconnects everything it connected; clears every table
Shop.onRequest(player: Player, request: any): any   -- the seam a forged request arrives through
Shop.stats()
Shop.forget(userId: number)              -- after this, no table here is keyed by him

export type World = {
    enabled: boolean?,
    purchase: ((userId: number, itemId: string, facts: { atCounter: boolean }) -> Receipt)?,
    snapshotFor: ((userId: number, receipt: Receipt?) -> Shop.Data.State)?,
    counterAt: (() -> Vector3?)?,
    rootOf: ((player: Player) -> Vector3?)?,     -- a spec's stand-in for a character
    remotes: any?,
}
```

* **`Shop.onRequest` is public for `Weapon.onFireRequest`'s stated reason**: *"THE SEAM A FORGED
  REQUEST ARRIVES THROUGH, reachable by parameter as well as by remote … `OnServerEvent` can only be
  raised by a client"*. It returns its own decision so a spec gets a per-call answer instead of
  inferring one from a counter — the correction task 80 round 2 made.
* **`Shop.start` returns false and says why** when a required seam is missing, the rule
  `Lobby.start` states and enforces by name (*"`isHeld` IS REQUIRED AND NOT OPTIONAL … a boot that
  forgot it would get `held = false` in silence"*). Required here: `purchase`, `snapshotFor`.
  Optional with a default: `counterAt`, `rootOf`, `remotes`.
* **Its `stats`**: `requests`, `badRequests`, `rateLimited`, `opens`, `buys`, `granted`,
  `refusedBy: { [string]: number }`, `unknownItems`, `repliesDropped`. The division `Weapon.stats`
  already makes between a refusal and a forgery (§6.2).

### 10.2 `ServerScriptService.Economy` — what is added

```luau
Economy.purchase(userId: number, itemId: string, facts: { atCounter: boolean? }?): Receipt  -- NEVER YIELDS
Economy.ownedOf(userId: number): { [string]: boolean }?    -- a FROZEN copy; nil = no session
Economy.huntsOf(userId: number): number?                   -- nil = no session
Economy.shopStateFor(userId: number, receipt: Receipt?): Shop.State

export type Receipt = {           -- the purchase receipt, NOT payDrive's
    ok: boolean, item: string?, price: number?, balance: number?,
    refused: string?, refusedNumber: number?,
}

Economy.View  -- gains ONE read-only function:
    ownedOf: (userId: number) -> { [string]: boolean }?
```

One new state table, and `Economy` is the only writer of it:

| Table | Fact |
|---|---|
| `ownedSets: { [number]: { [string]: boolean } }` | what each open profile owns. Replaced whole on each purchase; dropped by `release` and by `setOnLost` beside `balances` |

`hunts` is **not** a fifth table: it is read out of the profile at load into `huntsCache[userId]` and
incremented by `payDrive` in the same breath as the store write, so the in-memory number and the
profile field have one writer and cannot diverge. `Economy.stats` gains `purchases`,
`purchasesRefused`, `coinsSpent` and `refusedBy`.

`Economy.stop` clears `ownedSets` and `huntsCache` with the other tables — the teardown assertion
every owner's spec makes.

### 10.3 The roots

Identical lines in `src/server/MatchBoot.server.luau` and `src/server/ForestTestBoot.server.luau`,
after `Economy.start()` and before `Match.start`:

```
Shop.start({
    purchase    = Economy.purchase,
    snapshotFor = Economy.shopStateFor,
    counterAt   = LobbyData.counterPosition,
})
Weapon.setEntitlementProvider(function(player) return Economy.ownedOf(player.UserId) end)
Match.start({ …, economy = Economy.view() })        -- the view now carries ownedOf
```

* **The `Player` -> userId translation is the root's**, because `Economy` *"must not hold a `Player`"*
  and `Weapon`'s providers all take one. The root is where both vocabularies are already known — the
  seam `Body.setAccessorySource` is, in that module's own words.
* **Neither owner requires the other.** `Shop` does not require `Economy`; `Economy` does not require
  `Shop`'s server half (it requires the shared data module for the pure rules, as `Match` requires
  `Licences`). The wiring is one-directional and the roots do it, which is the shape `MatchBoot`'s own
  comments name (*"`Weapon.setArmingPolicy(Match.mayCarryWeapon)` … neither owner requires the
  other"*).
* **`game:BindToClose` is unchanged.** `Economy.closeAll` already ends every session, and ending a
  session is what saves a purchase. The shop registers nothing with `BindToClose` — a bound callback
  cannot be disconnected (`docs/design/economy.md` §4.6), and the shop has nothing to flush.

### 10.4 The DEV place has no counter, and that is not a defect

`Lobby.ANCHORS` has one row, `forest-test`, so `Lobby.anchorFor("map:v1")` is nil and
`Lobby.start` *"builds nothing"* — there is no lodge and no `Counter` in the place the harness runs
in. `Lobby.counterPosition()` answers nil, `Shop.withinReach(me, nil, …)` is **false**, and every
purchase in the DEV place is refused `too-far`. So:

* the **reach rule** is proved purely and through the injected `counterAt`, never by a live walk-up;
* the **live counter** is proved by a screenshot in the Forest Test with both flags on (§12.4);
* no harness check can change its answer, which is the same property task 177 relied on.

---

## 11. Hazards

| Hazard | Mechanism that closes it | What says it stayed closed |
|---|---|---|
| **1. The template's `owned` table shared by every player** | `Store.read` clones a table default **and** `Store.TEMPLATE` is deep-frozen, so corrupting it throws instead of spreading (§8.2a) | `economy_store.spec`: two reads give tables that are not `==`; a write to the template errors |
| **2. A purchase counted as a completed hunt** | the increment moves out of `Store.save` and into `Economy.payDrive`; `save` derives nothing (§8.2b) | `economy.spec`: a purchase leaves `huntsOf` unchanged; a pay-out raises it by exactly 1 |
| **3. Charged twice for one item** | step b asks `owned` before step d, and there is no yield between them (§9.1) | `economy.spec`, and `stats.refusedBy.owned` |
| **4. A client naming its own price** | no price crosses the wire inbound; `Shop.checkRequest` is a two-field whitelist (§6.2) | `shop.spec` over `checkRequest`; `shop_door.spec` sends a price field and it is a `bad-request` |
| **5. A client spamming the door** | per-player minimum interval, `HitLog.onRequest`'s mechanism (`lastRequestAt` + `REQUEST_MIN_INTERVAL`) with the note's number. **`Weapon.Limits` was NOT borrowed**: it is pure and generic but lives inside another owner's tree (`src/server/Weapon/Limits.luau`), and the shop requiring it would be an owner edge for 8 lines. Moving it to shared is queued (§16 item 8) | `shop_door.spec`: five requests in one tick, `stats.rateLimited == 1`, one reply |
| **6. A shop that sells an entitlement no build can grant** | invariant I3 (§4.2), which is what forces `rifle.open`'s `sale = false` rather than a comment asking for it | `shop.spec`, over every row |
| **7. A beater armed in a world nobody wired** | `Shop.grantsDriveGun(nil) == false` — the one reader whose default is "refused", §7.1 | `shop.spec` asserts all three cases; `match_teams.spec` asserts an un-injected `Match` arms no Driver |
| **8. A hunter losing the rifle he paid for because a DataStore call failed** | the provider answers `nil`, not `{}`, when there is no session — and nil is today's game (§7.1) | `economy.spec` with `Store.memory{ refuse }`: `ownedOf` is nil, and `Weapons.loadoutFor(true, nil)` is the full list |
| **9. An unowned slug fired anyway** | the allowance is 0 and `StateMachine.apply`'s existing `"no-reserve"` refuses `Load`, `Magazine` and the switch. No second gate, no new rule | `weapon_state.spec`: `initial(row, startFor(row, {}))` then `SelectAmmo Slug` -> refused |
| **10. The panel greys a button the server would have accepted, or the reverse** | `buyable` is computed once, on the server, by `Shop.rowsFor`, and is the only field the button reads (§6.3) | `shop.spec` asserts `rowsFor`'s `buyable` equals `Shop.refuse(...) == nil` for the same facts, over a table of cases |
| **11. A reply fired at a player who has left** | `player.Parent ~= nil` before every `FireClient`, and `stats.repliesDropped` counts it | `shop_door.spec` with a stand-in whose `Parent` is nil |
| **12. The panel drawn behind its own background** | every child sits above the panel's `ZIndex` — task 124's measured defect, in the Hud's own words (*"its labels were at the default ZIndex 1 under a panel at 10, so every child was drawing BEHIND its own background"*) | `shop_panel` client spec asserts every child's `ZIndex > panel.ZIndex`; and the screenshot |
| **13. Two writers of the panel's `Visible`** | `ShopPanel` owns it, the `MapUi` arrangement, and the Hud only calls `setNear` (§5.1, §5.4) | the client spec: `Hud` writes nothing on the frame after `build` |
| **14. A second clock** | none is added: the server tests reach per request, the client rides `Hud.renderObjective`'s existing `RenderStepped` (§1.2 item 3) | a grep in the review; `Shop.stats().scans` does not exist because there is nothing to scan |

---

## 12. How it is tested (brief §3 item 6)

### 12.1 The seams, and the claim each one buys

| Seam (symbol) | Where | What it makes assertable in seconds |
|---|---|---|
| `Shop.refuse(context)` | `ReplicatedStorage.Shop`, PURE | all eight reasons, the declared order with several tripped at once, every nil default, the numbers the lines print |
| `Shop.rowsFor(...)` | PURE | the whole panel body, and that `buyable` agrees with `refuse` |
| `Shop.withinReach` / `checkRequest` / `startFor` / `grantsDriveGun` / `hatColorFor` / `row` | PURE | the reach boundary, the wire whitelist, the allowance, the three readers' defaults |
| `Shop.start({ purchase, snapshotFor, counterAt, rootOf })` | the server owner | the whole door with no lobby, no player and no economy: the rate limit, the forgery counter, the reach read, the reply |
| `Shop.onRequest(player, request)` | the server owner | a forged request **by parameter** — `OnServerEvent` can only be raised by a client (task 80) |
| `Economy.purchase(userId, item, facts)` | the owner | the six cases of §9.2, over a table, with `Store.memory` |
| `Store.memory{ seed = { [7] = { coins = 500, drivesPaid = 30, owned = { … } } } }` | `Economy.Store` | a rich player, a locked player and an owning player with no network and no library |
| `Store.read(data)` | PURE | the clone, the fill, the keep-unknown |
| `StateMachine.initial(row, start)` | PURE | both allowances, with no shop and no player |
| `Weapons.loadoutFor(rifleOn, owned)` | PURE | three ownership states x two flag states, with the flag at one of them |
| `Body.dressFor(team, config, look)` | PURE | the default colour and the bought one |
| `ShopPanel.press(id)` / `ShopPanel.rowText()` / `ShopPanel.isOpen()` | the client module | the ACTION behind each button and the strings that really reached the labels — the task-159 lesson (*"the panel reads, the words do not"*) |

**No production path exists for a test's benefit.** Everything above is pure, or the injected seam
another owner is handed anyway, or `Store.memory` — which is *"the double AND the Studio path"* by
task 170's own decision. Nothing new is Studio-gated.

### 12.2 The spec files

| File | Side | Covers |
|---|---|---|
| `tests/server/shop.spec.luau` | server, **new** | `Shop` whole: I1-I3, `refuse` and its order, every reason, `withinReach` (and its agreement with `Join.within` and `ForestTest.withinStand`), `checkRequest`, `startFor`, `grantsDriveGun`, `hatColorFor`, `rowsFor` vs `refuse`, `CONFIG` frozen |
| `tests/server/shop_door.spec.luau` | server, **new** | the owner against fakes: the rate limit, the forged id, the extra field, the reach read, the reply payload, `player.Parent == nil`, `start` refusing a missing seam, `stop`'s teardown, `forget` |
| `tests/server/economy.spec.luau` | server, CHANGED | `Economy.purchase`: the six cases, the double click, the balance deducted once, `owned` written and frozen, `huntsOf`, the no-yield budget, `stats` |
| `tests/server/economy_store.spec.luau` | server, CHANGED | the widened `load`/`save`, the derivation gone, the template clone and freeze, keep-unknown with `owned`, the widened `seed` |
| `tests/server/weapon_state.spec.luau` | server, CHANGED | `StateMachine.initial(row, start)` both ways; `Refill` with `action.reserve`; the slug switch refused on an empty pocket |
| `tests/server/rifle.spec.luau` | server, CHANGED | `Weapons.loadoutFor(rifleOn, owned)`: six cases; no row gained a rule field (the existing assertion, extended to `grants`) |
| `tests/server/weapon_equip.spec.luau` | server, CHANGED | `refreshArming` with an entitlement provider wired: a player who owns no rifle is granted one Tool; the pcall fallback |
| `tests/server/match_teams.spec.luau` | server, CHANGED | `mayCarryWeapon` for a Driver: nil set, empty set, licensed set, and `DRIVERS_MAY_SHOOT` still winning first |
| `tests/server/match_outfit.spec.luau` | server, CHANGED | `dressFor(team, config, look)`: the default colour, the bought colour, and the plate rows carrying it |
| `tests/server/lobby.spec.luau` | server, CHANGED | `Lobby.counterPart` / `counterPosition`: found, memoised, dropped when destroyed |
| `tests/client/shop_panel.spec.luau` | client, **new** | `setNear`'s edge, `press` per row, the strings on the labels, every child's `ZIndex`, the `CLOSE` button's height, `Visible` with one writer, the closed-shop line |
| `tests/client/hud_clarity.spec.luau` | client, CHANGED | the panel's rectangle against the 400x800 screen, and that it does not overlap the rail |

### 12.3 Harness and scope

`tools/studio_mcp.py`: `BLAST_RADIUS` gains `("src/shared/Shop/", "shop")` and
`("src/server/Shop/", "shop")`; `SCOPE_SPECS` gains

```
"shop": ("tests/server/shop.spec.luau", "tests/server/shop_door.spec.luau",
         "tests/server/economy.spec.luau", "tests/client/shop_panel.spec.luau"),
```

and `"economy"` and `"hud"` each gain the dual membership the tables already use: `economy` gains
`shop.spec` and `shop_door.spec` (a `src/server/Economy/` edit can break the purchase), `hud` gains
`shop_panel.spec` (`src/client/Hud/` already resolves to `hud`, so only the spec is named). `selftest`
fails if a spec file belongs to no scope, so all three new files must be mapped in the same commit.

**Two players: REQUIRED for the PR to `main`, and it is not avoidable.** This task touches
`src/server/Match/` (`mayCarryWeapon`, `Body.dress`, the view's `ownedOf`) and two
`tests/server/match_*.spec.luau` files — **three entries on `TWO_PLAYER_PATHS`** — so
`tools/agents.py` refuses the merge without the `[harness2]` line for the code commit. A review round
may use a `scope=auto:…` line instead. The beater's licence is also the one claim a second player
makes real: `mayCarryWeapon` answers about a Driver, and a solo session has none.

### 12.4 Screenshot (rule 5)

**Required, and it is the whole point of the task**: a new panel on screen. With
`python tools/flags.py set COINS on` and `python tools/flags.py set SHOP on`, in the Forest Test, walk
to the counter inside the lodge and capture:

1. the panel open at the counter, with five rows, the balance, one `OWNED`, one `SOON`, one `LOCKED`
   and one buyable row — inspected for the task-124 defects (a see-through panel, a header over the
   wrong column, children behind their own background);
2. the refusal line after pressing a row he cannot afford.

Then `python tools/flags.py clear` before the harness, which refuses to start while an override is set.

### 12.5 What the harness cannot do, reported not papered over

* **It cannot tap or click a `GuiButton`.** `ContextActionService` key input is replayable through
  `tests/client/input_scenarios.txt`, and `E` therefore IS drivable end to end; `Activated` is not.
  `ShopPanel.press(id)` is the seam, and what it proves is the **action**, not the touch — `Rail`'s
  own stated limit (`docs/design/hud-clarity.md` §10.4), unchanged by this task.
* **It cannot walk a character to the counter.** The DEV place has no lodge (§10.4), so the live
  walk-up is Karen's playtest and the screenshot, and the reach rule's evidence is pure plus the
  injected `counterAt`.
* **It cannot reach the live DataStore.** `Economy.storeKindFor(true) == "memory"` and no spec
  requires ProfileStore — unchanged from task 170, and the reason is unchanged.

---

## 13. Numeric targets

| Target | Value | Checked by |
|---|---|---|
| Items in the catalogue | **5**, cap `MAX_ITEMS = 8` | `shop.spec` (I1) |
| Rows for sale in this build | **4** (`rifle.open` is `sale = false`) | `shop.spec` (I3) |
| SLUG SHELLS | 120 coins, 0 hunts | note §4; `shop.spec` asserts the row |
| BEATER LICENCE | 250 coins, 3 hunts | note §4 |
| RED HAT | 80 coins, 0 hunts | note §4 |
| RIFLE, OPEN | 600 coins, 10 hunts, not for sale | note §4 |
| RIFLE, SCOPED | 1500 coins, 25 hunts | note §4 |
| Cheapest item vs one drive | 80 coins against a drive's **10 to ~105** (`docs/design/economy.md` §8) | arithmetic; `economy.spec` already bounds the drive |
| Scoped rifle vs a drive | 1500 / ~60 average = **~25 drives**, which is *"has to play a lot it's not few hunts"* | arithmetic, stated |
| Counter reach | **14 studs**, flat | `shop.spec`, at 13.9, 14.0 and 14.1 |
| Door rate limit | **4 requests/second/player** (`REQUEST_MIN_INTERVAL = 0.25`) | `shop_door.spec` |
| DataStore calls per purchase | **0** | `economy.spec`: `Store.memory().calls()` shows one `save` and no network primitive |
| `Economy.purchase` cost | no yield, two table writes, one `save`; **< 0.2 ms** | `economy.spec` times it, as it times `payDrive` |
| Inbound payload | **2 fields**, `item` <= 32 characters | `shop.spec` over `checkRequest` |
| Outbound payload | 5 rows x 9 fields + 6 scalars ~ **under 600 bytes**, one `FireClient` per request | stated |
| Profile growth | `owned` <= 8 string keys ~ **under 200 bytes** added, against the documented 4,194,304 value cap | stated; `economy_store.spec` asserts the key set is bounded by `Shop.ORDER` |
| DataStore key | **unchanged**, `"player_<userId>"`, <= 26 characters against the cap of 50 | `economy_store.spec`, existing |
| Buy and CLOSE buttons | **>= 48 px** tall | `shop_panel.spec` |
| Panel rectangle | 420 x (5 x 48 + 4 x 8 + header 40 + footer 56) = **420 x 368**, inside the 400 x 800 screen `hud_clarity.spec` asserts... **it is not: 420 > 400** | see §13.1 |

### 13.1 The one number that does not fit, and the decision

`tests/client/hud_clarity.spec.luau` asserts against a **400 px wide** screen, and
`Drive.CONFIG.SCORE_PANEL_WIDTH` is already 480 — wider than that screen —, which
`docs/design/economy.md` §7.2 names as *"an existing problem"* it declined to make worse. **The shop
panel is built at `WIDTH = 360`**, not 420: it is a title, five rows of `LABEL  PRICE  TAG` and a
button, it is the **first** panel in this repo that can fit the phone screen the clarity spec measures,
and a panel that fits is worth more than three characters of label. `Shop.CONFIG.PANEL.WIDTH = 360`,
and `shop_panel.spec` asserts the formatted row's **character count** (<= 30 at `TextSize = 14`,
`Enum.Font.Code`), with the screenshot settling the pixels — the discipline
`docs/design/economy.md` §14 states for exactly this estimate.

---

## 14. Deltas: every file this design changes

**New**

* `src/shared/Shop/init.luau`, `src/shared/Shop/Remotes.model.json`
* `src/server/Shop/init.luau`
* `src/client/Hud/ShopPanel.luau`
* `tests/server/shop.spec.luau`, `tests/server/shop_door.spec.luau`
* `tests/client/shop_panel.spec.luau`
* `backups/2026-10-14_task-178_*` — the old `Store.save` derivation and the old
  `Store.memory` `seed` shape, each with its rollback (rule 7)

**Changed**

| File | What |
|---|---|
| `src/shared/Flags/init.luau` | the `SHOP` row; `MAX_FLAGS` 12 -> 13 with the reason beside it |
| `src/server/Economy/init.luau` | `purchase`, `ownedOf`, `huntsOf`, `shopStateFor`; `ownedSets` and `huntsCache`; the `coinsEarnedTotal` and hunt increments moved in from the store; `View.ownedOf`; `stats`; `stop` clears both new tables |
| `src/server/Economy/Store.luau` | `TEMPLATE` gains `owned` and is deep-frozen; `read` clones a table default; `load` returns the profile; `save` takes a field patch and derives nothing; `memory`'s `seed` widens |
| `src/shared/Weapons/init.luau` | `loadoutFor(rifleOn, owned)`, `loadout(owned)` |
| `src/server/Weapon/StateMachine.luau` | `initial(row, start?)`; `Action` gains `reserve?`; the `Refill` branch reads it |
| `src/server/Weapon/init.luau` | `setEntitlementProvider` + `askOwned`; `grant`, `revoke` and `refillForDrive` pass the allowance; `refreshArming`'s production default |
| `src/server/Match/init.luau` | `mayCarryWeapon`'s last line; the `world.economy.ownedOf` read handed to `Body.dressWhenLoaded`; requires `ReplicatedStorage.Shop` |
| `src/server/Match/Body.luau` | `dress`, `dressFor`, `dressWhenLoaded` gain `look`; `wearAccessory` writes `Color` |
| `src/shared/Lobby/init.luau` | `COUNTER_NAME`, `counterPart`, `counterPosition` |
| `src/server/Lobby/Build.luau` | `LODGE.SIGN_TEXT` -> the shop's name; the placeholder sentence goes (rule 7: the old string archived) |
| `src/client/Hud/init.luau` | `build` creates the `ShopPanel` frame; `Hud.shopPanel()`; `Hud.Shop`; one line in `renderObjective`; `ShopPanel.start` in `Hud.start` |
| `src/server/MatchBoot.server.luau`, `src/server/ForestTestBoot.server.luau` | `Shop.start({ … })`, `Weapon.setEntitlementProvider(…)` |
| `tools/studio_mcp.py` | `BLAST_RADIUS` + `SCOPE_SPECS` for the `shop` scope, and two dual memberships |
| `CREDITS.md` | the OpenTTD and ioquake3 rows gain this task (both are already credited for `Rules` and `Rank`) |
| the eleven specs in §12.2 | |

**Design files the Architect must amend (not the Builder — rule: the Builder never writes designs)**

* `docs/design/economy.md`: §4.2 (`Store`'s widened interface), §4.4 (`purchase`, `ownedOf`,
  `huntsOf`, the view's new function), §4.5 (`Match`'s two reads), §9 (the template, `drivesPaid`'s
  two readers, `read`'s clone), §10.1 (the two changed specs), §12, §13 item 8 (*"Spending … confirmed
  out of scope"* — it is now in scope and done).
* `docs/design/lobby.md`: §9 (the counter's two readers), §10 (the shop panel at the counter), and the
  two items task 177 already queued for the Architect in `TASKS.md` 177a — (a) the `map-generator.md`
  §2.2 terrain-writer sentence and (e) the collision set — which belong in the same edit.
* `docs/design/rifle.md` §4 (`loadoutFor`'s second parameter), `docs/design/shotgun.md` §5.3
  (`initial`'s `start`, `Action.reserve`), `docs/design/beater-kit.md` §9 (the licence reaches
  `DRIVERS_MAY_SHOOT`'s branch), `docs/design/hud-clarity.md` §6 (the panel beside the rail).

**`GAME_DESIGN.md` — System owners.** Two new rows and four amendments:

1. **NEW:** *"**The shop's catalogue and its rules** (what is for sale, what it costs, how many hunts
   it needs, what it grants, and which rule refuses a purchase)"* -> owner **nobody at run time**:
   frozen data plus pure functions in `ReplicatedStorage.Shop`, `src/shared/Shop/`. The shape
   `ReplicatedStorage.Licences` and `ReplicatedStorage.Weapons` already have.
2. **NEW:** *"**The shop's door** (the inbound remote, the per-player rate limit, the counter reach
   read, the commit order and the one outbound payload)"* -> owner `ServerScriptService.Shop`,
   `src/server/Shop/`, started by each world's composition root, handed `Economy.purchase` and
   `Lobby.counterPosition`. It writes no profile, no balance, no ownership, no Instance. Flag `SHOP`,
   born OFF. Note `docs/research/2026-10-14-the-shop.md`, design `docs/design/shop.md`.
3. **A player's coins and the saved profile** (`ServerScriptService.Economy`): add that the profile now
   carries the ownership set, that `Economy.purchase` is the only writer of either half of a purchase,
   that `drivesPaid` is also the completed-hunt count read through `Economy.huntsOf`, and that
   `Economy.view()` carries `ownedOf`.
4. **Game state / the drive** (`ServerScriptService.Match`): a licensed beater may carry a gun, through
   the same branch `DRIVERS_MAY_SHOOT` opens, read off the injected economy view; and `Match.Body` is
   handed a hat colour.
5. **UI / anything drawn** (`PlayerScripts.Hud`): the Hud builds the `ShopPanel` frame and
   `Hud.ShopPanel` is the one writer of everything inside it **including its `Visible`** (the `MapUi`
   arrangement, not the compass's).
6. **The weapon** (`ServerScriptService.Weapon`): a fourth injected provider, the ownership set, read
   through one pcall and used for the loadout and the drive's shell allowance.

`docs/research/INDEX.md` gains the note (the Builder's file).

---

## 15. External sources

### 15.1 ProfileStore 1.0.3 — MadStudioRoblox — **the save layer, unchanged and extended**

<https://github.com/MadStudioRoblox/ProfileStore> · API <https://madstudioroblox.github.io/ProfileStore/api/>
· **Apache-2.0** · **maintained** (last commit on `main` 2025-07-31; the library its own predecessor
points new projects at). Pinned as `lm-loleris/profilestore@1.0.3` in `wally.toml`, `wally.lock`
committed, `ServerPackages/` pinned by `serverpackages.sha256`.

*Its own description:* *"Periodic DataStore saving solution with session locking"*, which *"prevents
other game servers from accessing this data too soon by establishing a session lock"*.

**Well:** an inventory under this library is **not** a second store and not a second key — it is more
fields in `Profile.Data`, written by whoever owns the profile, and the session lock is what makes
"two servers cannot both spend the same coins" true without a transaction. Roblox's own
best-practices page says the same in its own words: *"Update the local copy instead of sending a data
store request for every change."* **Badly:** no schema migration and no transaction across profiles
(irrelevant: a purchase touches one player), and whether it reconciles a template on load is
**unverified by this repo** — which is why `Store.read` exists and why §8.2a hardens it.

**Adopted whole and unchanged.** This task adds two keys to the one table it already saves and calls
no new library function.

### 15.2 OpenTTD — `CommandCost` / `DoCommandFlag::Execute` — **the purchase pattern**

<https://github.com/OpenTTD/OpenTTD> · `src/command_type.h`, `src/command_func.h` · **GPL-2.0** ·
**actively maintained**.

**Well:** every player action is first run **without** the execute flag; the call answers a
`CommandCost` — a price, or an error message id — and only a second, executing call commits. Nothing
is half-done, and the refusal carries the sentence the UI prints. That is exactly the shape of
"may he buy this, and what does it cost" and it keeps the reason as **data** rather than a thrown
error. **Badly:** it is a C++ flag-set API over a command table, and this game wants one pure
predicate and one commit.

**Adopted as `Shop.refuse` then `Economy.purchase`**, and it is the **second** instance in this repo —
`src/server/Weapon/Rules.luau` adopted it in task 171, with `Rules.refuse` walking a declared
`Rules.ORDER`. This design copies that file's shape deliberately, including the declared order and the
one-question-per-function rule, so there is one idiom for "the game said no" and not two.

### 15.3 ioquake3 — `bg_itemlist` / `Pickup_Weapon` — **the catalogue and the set**

<https://github.com/ioquake/ioq3> · `code/game/bg_misc.c`, `code/game/g_items.c` · **GPL-2.0** ·
**maintained fork of a shipped game**; the repo this project has already borrowed from three times
(the intermission, `Hud.firstPlaceRank`, `Drive.Rank`).

**Well:** the item table is a **static literal array in shared ("bg") code** that the server and the
client both read — so the panel draws the prices the server charges because there is one table — and
picking a weapon up does not copy a weapon: it sets a **bit in a set**,
`ps->stats[STAT_WEAPONS] |= 1 << weapon`, which the loadout then reads. **Badly:** its set is per life
and never persisted, and it has no prices at all.

**Adopted as `Shop.ROWS` (frozen literal, no registry — `Weapons`' own stated reason) and `owned` (a
set read by the loadout).** Buying a rifle adds no second rifle row and no per-player weapon table.

### 15.4 Roblox Creator Docs — remotes, security, data stores — current, no licence granted

<https://create.roblox.com/docs/scripting/events/remote-events-and-callbacks> ·
<https://create.roblox.com/docs/scripting/security/security-tactics> ·
<https://create.roblox.com/docs/cloud-services/data-stores/best-practices> ·
<https://create.roblox.com/docs/reference/engine/classes/GuiButton#Activated> ·
<https://create.roblox.com/docs/ui/size-modifiers>

**Well:** *"never trust the client"* is the one security question this task asks, and the docs state
the three answers it needs — validate every argument that crosses a remote, do the arithmetic on the
server, rate-limit the door. `GuiButton.Activated` is *"one event for a click AND a tap"*, which is
why the panel needs no touch branch, and the UI tutorial's 44 px touch minimum is what
`BUTTON_PX = 48` clears. **Badly:** no shop example, and nothing about how a catalogue should be
shaped — which is what 15.3 is for.

### 15.5 Weighed and NOT taken

* **`MarketplaceService` / `ProcessReceipt`** — the Robux path, and the Director's dispatch puts Robux
  later. Its one transferable idea is taken: a purchase must be **idempotent**, because the same
  receipt can arrive twice (§9.2, case A).
* **A generic inventory with stacks and quantities** — nothing Karen asked for has a quantity. A
  licence, a weapon, a hat and the slug unlock are each owned or not. A quantity would be a mechanism
  with no caller (rule 2).
* **A `ProximityPrompt` for the counter** — refused for the reason `Lobby.Join`'s header already gives
  about the truck spot: *"it is a BUTTON"*. Here the opposite half applies — the shop **is** a
  deliberate interaction, so a key and a button are right — but the prompt's own UI is a second
  drawn thing with a second owner, and this Hud has one ScreenGui on purpose. The panel's own
  `CLOSE` button and the `E` binding do the same job inside the one owner.
* **`Weapon.Limits`** — pure and exactly right, but inside another owner's module tree; see hazard 5.

### 15.6 Borrowed from inside this repo (rule 2 applies to internal patterns too)

* **the frozen shared table with no writer** — `Weapons.ROWS`, `Licences.ROWS`, `Drive.CONFIG`;
* **test-then-execute with a declared order** — `Weapon.Rules.refuse` / `Rules.ORDER`;
* **the inbound remote with a pure whitelist and a per-player ration** — `Weapon.Validator.checkRequest`
  + `Weapon.Limits`, and `HitLog.onRequest`'s `lastRequestAt` / `REQUEST_MIN_INTERVAL`;
* **the public handler the wire calls, so a spec drives the wire's own path** — `Weapon.onFireRequest`,
  `Hud.onHitMarker`, `Rail.press`;
* **the injected provider wired at the composition root, pcall-ed, nil meaning today's game** —
  `Weapon.setArmingPolicy`, `setTargetProvider`, `setStandProvider`, `setDriveOpenProvider`;
* **the read-only view handed to another owner** — `Economy.view()`, `Bots.view()`;
* **the one boundary flag read passed inward** — `Weapons.loadout()`, `Economy.CONFIG.ENABLED`,
  `Lobby.ENABLED`;
* **the pure formatter returning a list for a renderer to lay out** — `Hud.scorePanelLines`,
  `Match.quarryLines`;
* **the memoised reader of the one part the server built** — `Lobby.spotPart`;
* **the panel that owns its own `Visible`** — `MapUi`;
* **the fact TOLD to a drawer rather than read by it** — `Rail.setWeapon`.

### 15.7 Invented, with the written reason rule 2 requires

* **`Shop.ROWS`' `grants` field** (§4.1): no source has this game's weapon ids, ammo kinds or team
  names in it. Five rows of data read by four functions that already exist.
* **`Store.read`'s table-default clone plus the frozen template** (§8.2a): the first table-valued
  field in the profile makes the existing fill-missing-keys rule unsafe. Two lines, and a spec that
  fails without them.
* **`Shop.withinReach` as a third copy of one subtraction** (§4.4): no shared home exists, the spec
  asserts all three agree, and folding them is queued.

### The pattern adopted overall

**A frozen shared catalogue both sides read; a pure test-then-execute refusal with a declared order
and a reason that is data; ownership as a set in the ONE profile `Economy` already owns, written by
one non-yielding function; behind a server-authoritative, rate-limited, reach-checked door that owns
no money; applied by the four owners that already decide the loadout, the shells, the arming and the
outfit, each through one injected provider whose silence means today's game.**

---

## 16. Open decisions

**None of them blocks building.** Every one is one line of data, one predicate or one boolean, and the
design states the value it ships with.

### Karen (feel / design)

1. **Every price and every hunt gate** (§13, note §4). One line each in `Shop.ROWS`, after one drive.
2. **The hat's colour.** Shipped `Color3.fromRGB(150, 38, 32)`, a dark hunting red, because hunter
   orange is already the team colour and a second orange hat would be invisible as a purchase. Note
   §6 item 4 is hers.
3. **Is a licensed beater tied for an unsafe shot like anybody else?** Shipped **yes**, with no
   exception written, because `Match.Penalty.judge` already anticipated the day a Driver carries a gun
   (§7.4). The alternative — a beater exempt from the arc — would need a new rule, and she asked for
   simplification, not an exception.
4. **Does buying slugs mean a hunter STARTS with buckshot only?** Shipped **yes**: it is her ladder
   (*"shotgun buckshot (default) -> slugs"*, *"yes that seems legit"*). It is the one thing in this
   task that takes something away from the gun she has already accepted, so it is behind the flag and
   she should see it before `SHOP` flips. Note §6 item 2 (permanent vs per-drive) is also hers;
   shipped permanent.
5. **Does the rifle REPLACE the shotgun in the hotbar or sit beside it?** Shipped **beside**, which is
   what the hotbar already does (note §6 item 3). No code either way.
6. **Does the panel open by itself at the counter, or on `E`?** Shipped **auto-open**
   (`Shop.CONFIG.AUTO_OPEN = true`), the `ReportPanel.autoOpenedFor` idiom, with `E` toggling. One
   boolean.
7. **The words.** `Shop.CONFIG.TEXT` — the title, `SOON`, `LOCKED: %d HUNTS`, `YOU NEED %d COINS`, and
   the lodge sign that replaces *"SHOP - coming soon"*.

### Director (scope)

8. **`MAX_FLAGS` 12 -> 13** (§3), and whether to retire `BOAR_SOUNDERS`, `ORANGE_OUTFITS` and `RIFLE`
   instead (already queued as `TASKS.md` 82b), which would bring the count back under the cap without
   touching it.
9. **When `SHOP`'s default flips**, and that it needs `COINS` flipped too or the shop reads CLOSED
   (§3.1). `expires = 2026-11-04` forces the question within 21 days.
10. **Should `Weapon.Limits` move to `ReplicatedStorage`** so the shop's door and the weapon's wire
    share one limiter (hazard 5)? One file move plus two requires, in a task of its own.
11. **Should `ForestTest.withinStand`, `Lobby.Join.within` and `Shop.withinReach` become one shared
    predicate** (§4.4)? Three copies with a spec asserting they agree is the shipped state.
12. **Robux, a second shop, selling back, trophies, a species licence for a deer** — confirmed out of
    scope. `Store.TEMPLATE`'s keep-unknown rule means none of them costs a migration.
13. **`Weapon.setLicenceProvider` stays unwired** (§7.4), against its own comment's promise that *"The
    shop task wires it"*. A species permit for an animal that does not exist is the thing invariant I3
    forbids. The comment should be corrected to say so, which is a one-line Builder edit in this task.

---

## 17. What I could not verify (rule 8)

* **No code was run.** This session has Read, Grep and Glob only; the evidence in this document is
  the committed source at `f994887` plus the precomputed files in `.agent-evidence/`.
  `.agent-evidence/INDEX.md` records that Studio is not available, so every harness claim here is a
  claim about what the tables and prompts require, checked for consistency and not executed.
* **The external sources were fetched by the Builder on 2026-10-14** and are quoted from
  `docs/research/2026-10-14-the-shop.md`, not re-fetched by this run. Licences and maintenance status
  are that note's, which states it read ProfileStore's shipped source and `LICENSE` directly.
* **Whether an empty Lua table survives a DataStore round trip as a table rather than an array is not
  verified here.** `owned = {}` is the common case for a new player. It is irrelevant to correctness
  because `Store.read` fills a missing or wrong-typed key from the template — but the spec must assert
  exactly that (`Store.read({ owned = {} })` and `Store.read({ owned = "x" })` both answering a table),
  and `read` must check `type(value) == "table"` rather than trusting what came back.
* **Whether `RemoteEvent:FireClient` on a player who has already left errors or is dropped is not
  verified.** The design guards it with `player.Parent ~= nil` and counts the drop, so the answer does
  not matter; that is why the guard is there rather than a reason to find out.
* **The panel's pixel widths are estimates** (§13.1). The spec asserts character counts and the
  screenshot settles the pixels — the same split `docs/design/economy.md` §14 made for the score row,
  and for the same reason: a wrong glyph estimate should cost a column, not a layout.
* **The live purchase path writes a real DataStore key and no spec can reach it**, by design and
  unchanged from task 170: `Economy.storeKindFor(true) == "memory"` inside Studio, always. The only
  evidence that a live server saves a purchase is the pure predicate, the one `print` naming the store
  taken, and Karen's own session after `COINS` flips.
* **`drivesPaid`'s current live value for any player is unknown and assumed to be nothing**, because
  `COINS` has been `false` since task 170 and no default has flipped. If a live server ever ran with
  the override on, those profiles carry a count this design will read as completed hunts. That is the
  correct reading of the number; it is noted because nobody has checked whether such a profile exists.
