# Money in dollars, and the v1 catalogue (task 221)

Rule 1. Written before the code, against `reviews/task-221/BRIEF.md` and
`docs/design/economy-v1.md` (Architect PASS, 2026-10-20).

---

## 1. What the system must do

Karen, 2026-10-20 ~08:30, verbatim:

> "We need to change coins to actual money $ / From shop remove red heat / It will be for sale in
> v1: - Access to tree stand - Rifle - Unlimited amunition - Red stag card - Beater can shoot in
> drive - Posibility to be a hunter always - We can also make a few packages bundles"

1. **Show the currency as money.** A `$` and the word MONEY wherever a player sees a balance, an
   earning, a price or a refusal, while **every persisted key keeps its name**. A rename of a saved
   field is the one change that can destroy a live profile, and the display is not the record.
2. **Retire an item without taking it off the people who bought it.** The red hat leaves the shop;
   its id is already in live `owned` sets.
3. **Sell exactly Karen's list**, with four new entitlements read by owners that already exist: who
   may stand on a high seat, who is exempt from the 12-shells-per-drive allowance, who holds a
   species licence, and who is never rotated to beater.
4. **Announce a thing that does not work yet without selling it.** There is no red stag.
5. **Sell packages** whose discount, whose hunts gate and whose overlap with what a player already
   owns are facts the build can check, not sentences in a comment.
6. **Leave one grant path for Robux** (task 222): a Robux receipt must grant the same entitlement
   through the same writer, and must survive being delivered twice.
7. **Keep the free path long.** Everything buyable with Robux is earnable by play, and the earn rate
   does not move to make that true.

### What it must not do

* Rename, migrate or version any persisted field, or touch `Economy.STORE_NAME`.
* Retune the earn rate (`COINS_PER_POINT`, `PARTICIPATION`, `FIRST_PLACE`, the floor).
* Call `MarketplaceService`, or carry a fabricated product id.
* Put a second reader of "can he buy this" anywhere: the window and the till read one answer.
* Leave a hunter off the stand line in order to enforce a privilege.

---

## 2. External sources

| # | Source | Licence | Maintenance |
|---|---|---|---|
| 1 | Roblox, `MarketplaceService.ProcessReceipt` and developer products | docs CC BY 4.0 | active, first-party |
| 2 | OpenTTD, `CommandCost` (`src/command_type.h`) | GPL-2.0 | active |
| 3 | ioquake3, `bg_itemlist` / `STAT_WEAPONS` / `SelectSpawnPoint` | GPL-2.0 | low activity, alive |
| 4 | Odoo, the "kit" / phantom bill of materials | LGPL-3.0 (Community) | active |
| 5 | Steamworks, packages, bundles and "Complete the Set" | proprietary partner docs | active |
| 6 | OpenTTD, `CurrencySpec` (`src/currency.h`, `src/currency.cpp`) | GPL-2.0 | active |
| 7 | Abdulkadiroglu & Sonmez, *Random Serial Dictatorship…*, Econometrica 66(3), 1998 | a result, not code | does not rot |

### 2.1 Roblox — `ProcessReceipt`

<https://create.roblox.com/docs/reference/engine/callbacks/MarketplaceService#ProcessReceipt> ·
<https://create.roblox.com/docs/production/monetization/developer-products> ·
source repo <https://github.com/Roblox/creator-docs>

**Well.** It states the contract the grant path has to satisfy, and states it as a hazard rather
than an API note: the callback **is called again** for a receipt that did not return
`PurchaseGranted`, including after a server restart, so granting must be **idempotent**. It also
makes plain that the money side is Roblox's — there is no balance of ours to debit and no refusal
of ours to run, which is precisely why a purchase and a grant are two different things.

**Badly.** Its sample keeps a **per-player list of processed receipt ids** — a second store of the
same fact — and grants inline inside the callback, next to the data-store write. Taken literally
that gives this repo a second writer of the owned set, which is the thing `Economy`'s header exists
to forbid.

**Adopted.** The idempotency contract, as `Economy.grant`'s *already owned → success, write
nothing* path. **The receipt-id ledger is refused, with a reason:** an entitlement SET is already
idempotent, because granting a row twice is the same set. Nothing extra has to be stored to make a
repeat delivery harmless — only to make it *countable*, which `stats.grantsBySource` does without a
key.

### 2.2 OpenTTD — `CommandCost`

<https://github.com/OpenTTD/OpenTTD>

**Well.** Test-then-execute: one function answers *may this happen* before anything is written, and
the reason travels as **data** with the number its line needs.

**Badly.** No notion of an **external** authority granting the same thing by another route, so it
has nothing to say about idempotency — which is exactly what source 1 is for.

**Adopted.** Already in this repo as `Shop.refuse` and `Weapon.Rules.refuse`, and **kept intact**:
`refuse` is still the whole test and `grant` is the whole execution. The split this task makes is
*along* that seam rather than through it.

### 2.3 ioquake3 — the item table, the ownership bitfield, the spawn choice

<https://github.com/ioquake/ioq3> — `code/game/bg_misc.c`, `code/game/g_items.c`,
`code/game/g_client.c`

**Well.** One static item table read by both sides; **ownership is a SET** and the thing owned stays
where it was declared; and the game mode chooses **among the points the world placed** rather than
inventing geometry.

**Badly.** The bitfield caps at 32 and has no notion of a bundle or a tier. And
`SelectSpawnPoint` picks **per player** and tolerates telefrags — which is exactly the collision
this task must not have.

**Adopted.** The item table and the set were already adopted in task 178. The spawn pattern is
adopted **as the division of labour** — the world places the stands, the mode chooses among them —
and **explicitly not as the algorithm**: `HighSeats.dealLine` deals the whole line at once so two
hunters cannot be given one stand.

### 2.4 Odoo — the kit / phantom bill of materials

<https://github.com/odoo/odoo> ·
<https://www.odoo.com/documentation/latest/applications/inventory_and_mrp/manufacturing/advanced_configuration/kit_shipping.html>

**Well.** A kit is defined **only** by the list it explodes into, so the kit and its parts can never
disagree about what it contains; the kit's own price is independent of the sum of its parts.

**Badly.** It is an **inventory** concept: it explodes into stock rows, where we need a **union of
entitlements**. And it has no rule at all for *the customer already owns a component*.

**Adopted.** `covers` plus a merge computed once at module load, and a bundle carries **no
hand-written grants**. `Shop.rowsOk` I11 asserts that `row.grants` IS `Shop.mergedGrants(covers)`,
so the two cannot drift. Everything about the already-owns case comes from source 5 instead.

### 2.5 Steamworks — bundles and "Complete the Set"

<https://partner.steamgames.com/doc/store/application/bundles>

**Well.** It names the exact problem a bundle creates and a single-item catalogue never does: the
store must know what the buyer **already owns**. It defines the two honest answers — *Complete the
Set* (price adjusted for what he owns) and *Must purchase all* (fixed price) — and it puts the
answer on the page rather than letting the buyer find out at the till.

**Badly.** Proprietary, no source, and *Complete the Set* needs a store that can **re-price at the
till**. Ours cannot and should not: `buyable` is computed once, on the server, off a frozen
catalogue, precisely so the window and the till cannot disagree.

**Adopted: the question, not the mechanism.** `Shop.ownedOrCovered` closes the forward case — a man
who bought THE MARKSMAN is refused RIFLE, SCOPED with `OWNED`, and the panel says IN YOUR KIT — and
`Shop.fullyCovered` closes the case of a package he is already wholly covered for. The reverse case
(he owns the rifle and buys the package anyway) is **Steam's *Must purchase all*** at a fixed price:
stated here rather than discovered by a player.

### 2.6 OpenTTD — `CurrencySpec`

<https://github.com/OpenTTD/OpenTTD> — `src/currency.h`, `src/currency.cpp`

**Well.** A currency is a **symbol plus its placement** in **one table** read by every formatter,
with the **sign handled outside the symbol** — so no screen ever hand-rolls `$-20`.

**Badly.** It also carries exchange rates, separators and localisation, none of which this game has
or needs.

**Adopted.** `ReplicatedStorage.Money`: `SYMBOL`, `WORD`, `UNKNOWN`, `text`, `signed`. The sign is
applied to the string and not inside the format, and `$` exists in exactly one module — which
`tests/client/money.spec.luau` asserts as a **negative** over every word table the game draws from,
so a screen the change missed is a failing harness line rather than something Karen finds.

### 2.7 House allocation by serial dictatorship

Abdulkadiroglu, A. and Sonmez, T., *Random Serial Dictatorship and the Core from Random Endowments
in House Allocation Problems*, Econometrica 66(3), 1998, <https://www.jstor.org/stable/2998585>;
textbook treatment in Roth and Sotomayor, *Two-Sided Matching*, CUP 1990.

**Well.** It is exactly the stand deal. Agents are ordered; each in turn takes his most preferred
item among those still unclaimed **and acceptable to him**. The outcome is deterministic and
**collision-free by construction**, and "acceptable" is where the entitlement lives: a seated stand
is not acceptable to a hunter who has not bought high-seat access. It gives the right to call the
deal a **named mechanism** rather than a loop somebody wrote, and it names the one property to
assert — no two agents hold the same house.

**Badly.** The literature's interest is in *randomising* the order (fairness across repeated draws)
and in strategy-proofness, neither of which we want: our order is `indexWithinTeam`'s sorted
userIds and must stay deterministic, or the same roster would get different stands every drive. It
also assumes a complete preference list and says nothing about running out of houses — which for us
is the wrap past `standCount`, and is a requirement the mechanism does not cover.

### 2.8 Borrowed from inside this repo (rule 2 applies to internal patterns too)

* `Weapons.loadoutFor` / `Shop.loadoutFrom` — ownership as a **set the loadout reads**, never a copy
  of the thing owned. All four new entitlements follow it exactly.
* `Shop.rowsOk` I1–I5 — a catalogue mistake is a failing harness, not an item nobody can see. The
  package's five new invariants and the retired table's I6 are the same device.
* `Rules.ORDER` / `Shop.ORDER_OF_REFUSAL` — *"an ORDER is a rule, and a rule nobody can assert is a
  rule that drifts"*.
* `Economy.owedTeams`' frozen memo and `invalidateOwed` — copied verbatim for `alwaysHunters` and
  `invalidateAlways`, for the measured reason that file already gives.
* `ForestTest.standIndexFor` — the centre-out walk, itself borrowed from Quake III's spawn family.
  `ForestTest.standWalk` **derives** the list from it rather than re-implementing the arithmetic.

---

## 3. What no source settles, and is therefore ours

1. **Which entitlements exist.** No source has this game's weapon ids, stands or roles in it.
   `Grants` is eight fields read by eight pure functions — the note's *"ownership is a set the
   loadout reads"* with our names in it.
2. **The nil rule per reader.** Every reader answers "today's game" for a set nobody filled in, and
   **today's game is not the same boolean in all eight**: `grantsHighSeat(nil)` is **true** (an
   un-wired world must deal the stands exactly as it does now) while `grantsAlwaysHunter(nil)` and
   `grantsUnlimitedAmmo(nil)` are **false**. One direction for all eight would arm every beater in
   every un-wired world, or put every player on `Shooters`.
3. **The three-tier fallback in `dealLine`.** See §4.

---

## 4. Invented, with the written reason rule 2 requires

**`HighSeats.dealLine` is a greedy sequential assignment with three preference tiers over a fixed
deterministic walk.**

No source was found that assigns scarce *privileged* positions to a roster. Quake's spawn selection
is per player and tolerates collisions, which is the failure this must not have; a general
assignment solver (Hungarian, `linear_sum_assignment`) is hundreds of lines for a 9×8 problem whose
only objective is *entitled first*. Serial dictatorship (source 7) gives the shape and the
collision-free guarantee; what it does not give is what to do when the houses run out.

So three passes, and the middle one is the one that had to be measured rather than reasoned:

1. the first free stand he is **allowed** on;
2. the first free stand **at all**;
3. the wrap, which is `standIndexFor`'s own modulo.

**Pass 2 exists because of a measurement.** Without it, five unentitled hunters on the `edge` line
(5 stands, the seat on stand 3) are dealt `2, 4, 1, 5, 5` — two men on stand 5, where today all five
fit. Eight shooters is reachable at `MAX_PLAYERS` 16, so that is a real new collision. With pass 2
the fifth man is given the seat instead: `2, 4, 1, 5, 3`. **The seat is given away rather than a
stand shared**, which is the design's own ordering and the brief's own sentence (*"a hunter with no
stand is worse than a hunter on a seat he did not pay for"*).

The greedy version is **provably collision-free** (a stand is written twice only from pass 3, and
pass 3 fires only when every stand is taken — which is exactly today's wrap) and **provably
identical to today** (with `entitled == nil`, pass 1 always takes `walk[index]`, which IS
`standIndexFor(index)`). A solver would have to be *tested* into both properties.

---

## 5. Numeric targets, each one checkable

| Target | Value | Checked by |
|---|---|---|
| rows for sale / drawn / `MAX_ITEMS` | 9 for sale, 10 drawn, cap **12** | `shop.spec` |
| shelves declared / drawn | **6** / **5** (CLOTHING holds only the retired hat) | `shop.spec`, `shop_panel.spec` |
| prices, $ | 120 · 250 · 575 · 600 · 750 · 900 · 1500 · 1800 · 2000 · 3750 | `shop.spec` |
| hunt gates | 0 · 3 · 5 · 5 · 0 · 10 · **25** · 25 · 30 · 30 | `shop.spec` |
| package discounts | HIDE **20%** (575 of 720) · MARKSMAN **25%** (1800 of 2400) · SEASON **30%** (3750 of 5370) | `rowsOk` I10 |
| a drive pays | 10 to ~105, typically **$20–60**; a drive is called $40 | unchanged (`economy.spec`) |
| drives to afford | 3 · 6 · 14 · 15 · — · 22 · 37 · 45 · 50 · 94 | this note |
| everything for sale | **$11,495**; test grant **$12,000 / 30 hunts** | `economy.spec`, against the catalogue |
| label length | `<= 18`; longest `HIGH SEAT ACCESS` (16) | `rowsOk` I2a |
| blurb length | raw 20..135; **composed** package blurb `<= 135`: 85 · 86 · **127** | `rowsOk` |
| `Money` widths | `$12000` = 6 chars against a 66 px cell; worst signed case `-$50` | `money.spec` |
| `dealLine` cost | `<= 8 x 9 = 72` comparisons, `<= 16` calls per drive, **0** per frame | this note |
| seated stands | road 3 of 9 · edge 1 of 5 · ride 1 of 5 · track 1 of 6 | `high_seats.spec` |
| unlimited pocket | the barrels stay **2**; `DRIVE_SHELLS` stays **12** | `weapon_state.spec` |
| flags | **14**, unchanged; no new flag | `flags.spec` |

---

## 6. Round 3: the Director's four decisions, 2026-10-20

The four items section 6 below raised were put to the Director and all four were decided. Three
are in code in this task; the fourth is a live check.

### 6.1 Always-hunter must WORK when bought — `Roster.assign` is rewritten

*"A paid privilege that is overruled 'every time' on even rosters is a broken product."* The
function's own header argued against rewriting it (*"rewriting a pinned pure function to add a
feature is a bigger change than the feature"*) and the Director overruled that argument with the
measurement.

**The new order of business.** The hunter slots are counted once (`Roster.shooterSlots`, the same
arithmetic the plain split does); every always-hunter takes one; then everybody else fills the
remaining hunter slots and the beaters' side, preferring the men the rotation owes a turn. **The
result is balanced by construction**, which is the whole point — the old path could produce a
3-to-1 swap and then throw the entire swap away.

**The yield order, exactly, and it deviates from the dispatch's words on purpose.** When more men
bought the place than there are hunter slots, somebody must drive. The dispatch said *"fewest
drives as always-hunter yield first"*. **Taken literally that starves the man at the bottom**:
yielding is precisely what stops him serving, so his count never rises and he is overruled for
ever — which is the defect this whole change exists to remove. So the key is RECENCY, which is the
same fairness without the trap:

1. he held `Shooters` in the previous drive → **yields first** (he has just had it);
2. he has no previous row at all (he just arrived) → yields next;
3. he drove last drive → **yields last** (it is his turn);
4. ties by userId, which is stable and total.

**It cannot starve, and that is provable rather than hoped**: a man who yields is a DRIVER this
drive, so next drive he is in group 3 with priority over everybody who just held it.
`match_roster.spec` runs four consecutive drives with four always-hunters and two slots and shows
**every man served exactly twice**.

**No new state.** The key is `previous`, which `assign` already receives — the rotation's own
memory already records who held what. So there is no new profile field, nothing added to
`Phase.freezeState`, and no second store. **Join time is not used**: a pure function cannot see it,
and carrying it would mean a new frozen-state field for a tie-break userId already settles.

`Roster.owedWith` is no longer in the `Assigning` path — the privilege is its own argument now —
and stays only on the mid-drive join branch, where `joinTeam`'s own rule applies.

### 6.2 The walk-up hole is shut

*"An unentitled hunter on a high-seat DECK cannot shoot."* `StandArea` gains `seatPaid`,
`ForestTest.standArea` fills it from an injected provider (the `setEntitlementProvider` idiom, so
the world module learns nothing about a shop), and `Rules.onUnpaidPlatform` is the one question
asked about it. The refusal is `UNPAID_PLATFORM`, treated exactly like being off-stand.

**`belowPlatform` stands down entirely for a stand he has not paid for**, and that is not a detail:
without it he would be told `CLIMB TO YOUR STAND` on the ground and refused the moment he did — a
trap with no way out. A stand he has not bought is a GROUND stand to him, and the spec sweeps every
height from 20 studs below the deck to 20 above and asserts the two rules can never both fire.

**The line is `"BUY TREE STAND"` and not the Director's `"BUY TREE STAND ACCESS"`**, because
`weapon_rules.spec` caps every notice at 20 characters and that cap is a measurement: the readout
already carries the glyphs, the ammo word and the pocket. 21 did not fit; Karen's own product words
without the noun that does not fit are 14.

### 6.3 Every row the shop sells has a picture

`ShopDisplay.DRAW` knew four ids and six of the ten rows drew nothing. Six builders added, all from
parts in the palette this file already has, no uploads: the high seat in miniature (legs, deck,
rail on the three far faces, a ladder), an ammo crate with shells standing in it, the licence card
with a stag silhouette, and a brass hunter's badge with the hunters' own orange band.

**A package draws its own contents**, through `ShopDisplay.build` per covered row and laid along a
shelf board — so there is one drawing per item, a package can never show something it does not
contain, and a row that gains a picture gains it inside every package that covers it.

**Measured live in the DEV place** (Play, a client probe over all ten rows): every row answers
`knows = true`, with part counts of 20, 42, 37, 16, 54, 15, 5, 21, 5 and 104. **That is a count and
not a look** — see section 7.

### 6.4 The climb (218a(h)) — NOT DONE, and why

It needs the Forest Test place, which is not open (see section 7).

---

## 7. What this task could NOT verify (rule 8)

**Both Studios connected during this session are the DEV place** (`136410205938347`), asked
directly rather than assumed. **The Forest Test (`130094961655666`) is not open**, and opening a
place in Studio is a click only Karen or the Director can make. Four things therefore remain
unproven, and none of them is claimed:

1. **The climb check (218a(h))**, decision 4. The seats exist only in the Forest Test
   (`ForestTestBoot` returns early anywhere else).
2. **The shop frames.** The display models are *measured* (6.3) and not *looked at*. **Rule 5 is
   not satisfied for this task.** A probe cannot stand in for the look: `execute_luau` has its own
   module cache, so `require`-ing `ShopPanel` in a probe returns a FRESH module with no GUI built —
   which is why `Panel.detailText()` came back empty from the live client, and why the frames need
   the real panel, which needs the lodge, which is the Forest Test.
3. **The live purchase with the test grant.** `Shop.withinReach` answers false with no counter, and
   the DEV place has no lodge — *"a world with no lodge has no shop, which is exactly what the DEV
   place is"* (shop design 10.4).
4. **The smoke run** (standing rule A), which is specified in the place Karen will use.

**So nobody should say "ready for Karen" on this branch.** `ESCALATE.md` carries the exact clicks.

---

## 8. What the earlier rounds could not settle (rule 8), and where each stands now

1. **CLOSED in round 3 (section 6.1).** **The always-hunter seam was weaker than the price
   implies, and it was measured.** The privilege is
   written into the **synthetic previous**, and `Roster.assign` keeps its swap only while
   `|Drivers − Shooters| <= 1`. Flipping one man's synthetic row moves the *swapped* counts by
   **two** — so on an even roster whose last split was even, honouring one always-hunter who already
   held `Shooters` **always** unbalances the swap, the whole swap is discarded, and everybody falls
   through to the plain split. That split is by sorted userId with `ODD_PLAYER_TEAM = "Shooters"`, so
   a **low userId is overruled every time rather than occasionally**. `match_roster.spec` asserts
   exactly this, beside the case that shows what the privilege does buy. Whether a $2,000 purchase
   should be stronger than that is Karen's and the Director's.
2. **CLOSED in round 3 (section 6.3).** **Six of the ten rows had no picture.** `ShopDisplay.DRAW` names four ids and declares that an id
   it does not name draws nothing while the panel says PICK AN ITEM. That is a stated fallback and
   not a crash, and no line of the design or the dispatch asks for the art — but it is what Karen
   will see.
3. **STILL OPEN (section 7).** **Task 218's high seats are inherited unproven.** TASKS.md row 218: *"NOT PROVEN: … the climb
   itself, and TrussPart.Size read-back"* (218a(h)). Gating a privilege behind money does not make
   the privilege work.
4. **CLOSED in round 3 (section 6.2).** **The walk-up hole.** In the Forest Test the placement is only where a hunter STARTS; an
   unentitled hunter can still walk to a seated stand in the 15-second pick window and climb the
   engine's own ladder. The blurb is written to match the code (*"You are given one of the wooden
   high seats on the line when one is free"*), and gating `ForestTest.lockPick` is the Director's
   D-2 because refusing a pick risks the measured *"locked to a stand nowhere near his feet"* defect.
