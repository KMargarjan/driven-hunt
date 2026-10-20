# Task 221 -- money in dollars, and the v1 shop catalogue

Task: 221
Round: 2
Base: main (`2ca8bdd`)
Code commit: `1af2cf6075996db4abebfe437cd6b5b52ced3bba`

```
[harness] PASS: 33/33 checks @ 1af2cf6075996db4abebfe437cd6b5b52ced3bba (clean tree) scope=all
```

The `[harness2]` pair below is the Director's at `61ad71a`, the round-1 code commit. **It is NOT
evidence for this commit** and is reproduced only to say where the two-player gate last stood; this
round changed `Match`, `Economy` and `Objective`, so `test2` is needed again at
`1af2cf6` and the Builder stops for it:

```
[harness2] PASS: 35/35 checks @ 61ad71a9eb3ae360ff73a5b0bb8ec652fdb1623e (clean tree)
[harness2] PASS: 35/35 checks @ 61ad71a9eb3ae360ff73a5b0bb8ec652fdb1623e (clean tree)
```

The `[harness2]` line is the Director's, run twice (L-033: this change is ordering-sensitive, so one
clean run was not accepted as evidence). Only paperwork has been committed after the code commit.

Karen, 2026-10-20 ~08:30: *"We need to change coins to actual money $ / From shop remove red heat /
It will be for sale in v1: - Access to tree stand - Rifle - Unlimited amunition - Red stag card -
Beater can shoot in drive - Posibility to be a hunter always - We can also make a few packages
bundles"*. Design: `docs/design/economy-v1.md` (Architect PASS). Note:
`docs/research/2026-10-20-money-and-the-v1-catalogue.md`.

---

## What changed

**`$` is display only.** New `ReplicatedStorage.Money` owns the symbol, the word and one formatter;
nothing persisted is renamed -- the profile field, the snapshot row field and the Hud column key all
stay `coins`.

**The catalogue is Karen's v1 list**: ten rows (seven items plus three packages), the red hat
retired rather than deleted, the red stag card shown and unbuyable.

**Four new entitlements**, each read by an owner that already existed: high-seat access, unlimited
ammunition, a species licence, always-hunter.

**`Economy.grant` is now the one writer of the owned set**, which is the seam task 222 needs.

**Round 3 (the Director's decisions)**: `Roster.assign` rewritten so a bought always-hunter place
actually holds; the walk-up hole shut; a display model for every row.

---

## Claims, and how to verify each

1. **Nothing persisted is renamed.** `grep -rn "coinsEarnedTotal\|COINS_PER_POINT\|STORE_NAME"
   src/server/Economy/init.luau` -- the profile field is still `coins`,
   `Economy.CONFIG.STORE_NAME` is still `DrivenHuntPlayer_v1`, and `Hud.BOARD.COLUMNS.coins` keeps
   its key. `Money` is display only.

2. **The `$` cannot be half-done, and that is a NEGATIVE assertion rather than a checklist.**
   `tests/client/money.spec.luau` walks every word table the game draws from
   (`Shop.CONFIG.TEXT`, `Shop.NOTICE`, `Shop.CATEGORY_LABEL`, `Hud.BOARD.COLUMNS[*].head`, every
   `Drive.CONFIG.SCORE_*`) and fails if any value still says COIN or hard-codes a `$`. It also
   pins `Money.text(-20) == "-$20"` (never `$-20`) and `Money.signed(34) == "+$34"`.

3. **The results board's column head stopped being derived from its own field name.** It was
   `string.upper(key)` -- which is why it printed COINS. `Hud.BOARD.COLUMNS[*].head` is declared;
   `money.spec` asserts every column the board draws has one.

4. **The red hat is retired, not deleted, and an owner keeps it.** `Shop.RETIRED` +
   `Shop.ALL_ORDER`; all eight readers of what ownership gives iterate `ALL_ORDER`, while the panel
   and the till read `ORDER`/`ROWS`. `shop.spec` asserts the hat still grants its colour, is not in
   `ORDER`, is refused `UNKNOWN` at the door, and `rowsOk` I6 keeps the two tables disjoint.
   Archived in `backups/2026-10-20_task-221_shop-red-hat-row.md` (rule 7).

5. **A package names what it covers and its grants ARE the merge.** `Shop.BUNDLES` carries `covers`
   and no hand-written `grants`; `Shop.mergedGrants` computes them once at load. `rowsOk` I7-I11
   assert: parts real, for sale and flat (no nesting); `hunts >= max(parts)`; `price < sum(parts)`;
   and `grants` deep-equals the merge. `shop.spec` drives all of it.

6. **The shop cannot charge twice for a thing a package already gave him.**
   `Shop.ownedOrCovered` is used by BOTH `Shop.refuse`'s `OWNED` branch and `Shop.rowsFor`'s
   `owned` field, so the window and the till read one answer; `Shop.fullyCovered` refuses a package
   he is already wholly covered for. `shop.spec`.

7. **The red stag card cannot be bought, and the refusal is arithmetic rather than a promise.**
   `Licences.Row.shipped` is false for `reddeer`, and `rowsOk`'s new I3a refuses a `sale = true`
   row granting a licence for a species nothing publishes. `shop.spec` proves it by flipping `sale`
   on a pretend catalogue and asserting the problem names `reddeer`.

8. **The stand deal is collision-free and is today's game when nobody paid.**
   `HighSeats.dealLine`, three passes. `tests/server/high_seats.spec.luau` drives four layouts,
   three stand counts, four entitlement patterns and every roster size to 16: no two hunters share a
   stand up to the wrap; nobody is left off the line; with `entitled == nil` every index equals
   `ForestTest.standIndexFor(index)`; a solo hunter still gets stand 5 on the road.
   **Pass 2 exists because of a measurement** -- without it five unentitled hunters on `edge` are
   dealt `2, 4, 1, 5, 5`.

9. **Always-hunter works when bought** (the Director's round-3 decision, overruling the function's
   own header). `Roster.assign` places paid men first and the rotation fills what is left, so the
   split is balanced by construction. `match_roster.spec`: an even roster, an odd roster, and
   all-always-hunters; it also runs **four consecutive drives with four buyers and two slots and
   shows every man served exactly twice** -- the yield order is by RECENCY and cannot starve.
   **It deviates from the dispatch's literal words on purpose** and the reasoning is in the code,
   the note and `ESCALATE.md`: "fewest drives as always-hunter yield first" taken literally starves
   the man at the bottom, because yielding is what stops him serving.

10. **The walk-up hole is shut, and the two rules can never both fire.**
    `StandArea.seatPaid`, `Rules.onUnpaidPlatform`, and `belowPlatform` standing down entirely for
    a stand he has not paid for -- without that he would be told to climb on the ground and refused
    once he did. `weapon_rules.spec` sweeps 40 studs of height asserting the pair is never both
    true, and pins the order (`OFF_STAND` before `UNPAID_PLATFORM` before `OFF_PLATFORM`).

---

## Round 2: the three findings

**Finding 2 -- `roleOverruled` had no test.** Added, and **shown failing first** (L-028):
`tests/client/hud_clarity.spec.luau` asserts the overrule sentence REPLACES the driver's countdown
and carries the same number, that `false` and nil read the same, that it is the `Assigning` line
only, and that a hunter is never told it; `tests/server/match_live.spec.luau` asserts the field is
ABSENT with no money in the build.

**That new case found a real behaviour bug on its first run.** `roleOverruled` keyed off
`economy.alwaysHunters` EXISTING, and a view is wired in every world that has an economy at all --
so an empty array shipped to every client with the money switched off. It is gated on `coinsOn`
now, the same fact the row beside it keys off. The spec was right and the code was not, which is
precisely what the Reviewer said the missing test would have caught.

**Finding 3 -- `Economy.grant` and `alwaysHunters` had no test.** Added to
`tests/server/economy.spec.luau`: `grant` called DIRECTLY (the door task 222's `ProcessReceipt`
comes through), a second delivery answering `ok = true, already = true` with **nothing written**
and `store.calls().save` still 1, `grantsAlready` and `grantsBySource` counted per source, the red
stag and a retired id refused by that door too, and `alwaysHunters()` asserted frozen, memoised,
**rebuilt** (not mutated) after a grant, counted through a package's merged grants, and emptied by
`release`/`stop`.

**Shown failing first, all three at once, with the seams deliberately broken:**

```
failed [server] economy.spec:663     Expected "true", got "false"
failed [server] match_live.spec:169  Expected "nil", got "table: ..."
failed [client] Expected "TEAMS MUST BE EVEN - you beat this drive. 7", got "drive starts in 7"
```

Each new case failed on its own target and nothing else did; then reverted.

**The notes**: the `dealLine` nil-index on an empty `walk` closed (a real one); `BUNDLES`
deep-frozen like its siblings; the `Money` comment corrected to what the code does; the licence
provider restored in `weapon_rules.spec` now that the seam is wired; and the two stale sentences
that still said `Roster.assign` was untouched.

**Finding 1 -- the frames: PARTLY done, and I am not calling it closed.** See below.

---

## What I could NOT verify (rule 8) -- please weigh these as unproven, not as passing

* **The climb (TASKS.md 218a(h)) is STILL NOT PROVEN, and I am not calling it a failure either.**
  The geometry is evidenced (`Seat4`'s ladder is a real `TrussPart` 2.00 x 13.80 x 2.00, foot
  Y 131.72, deck top Y 144.52) and the hunter was placed at its foot (`placedOff 0.00`, start
  Y 135.12, needing +9.40). With **real replayed `W` input** he ended at Y 155.20 -- past the deck
  top -- but my cross-probe `Heartbeat`/`StateChanged` recorders did not survive the probe boundary,
  so `maxY` and `states` are unreliable and **no `Climbing` state was captured**. Suggestive, not
  evidence. The Director authorised recording it unproven rather than blocking the merge.
  **Two earlier attempts produced FALSE PASSES** (the character placed above the deck, so a
  "reached" test passed trivially); both were caught on the numbers and thrown away -- rule E.
* **The shop contact sheet and the live purchase are NOT done.** The panel opens from the
  shopkeeper's `ProximityPrompt`; a scripted `InputHoldBegin` at 4.98 studs did not open it, and a
  probe cannot drive the real panel because `execute_luau` has its own module cache (requiring
  `ShopPanel` in a probe returns a fresh module with no GUI). **Rule 5 is therefore NOT satisfied
  for the shop panel.**
* **Smoke (standing rule A) was not run**, so nothing here says "ready for Karen".

## What IS proven live, with frames I looked at

The panel was opened **the way the prompt does** -- standing in range with line of sight and the
prompt's own `Triggered` -- not by a probe reaching into the module.

1. **`.screenshots/221-shop-weapons.png`** -- the REAL panel, camera at the player's eye (Y 157.9,
   root Y 157.4). WEAPONS / AMMO / LICENCES / ACCESS shelves; `RIFLE, SCOPED $1500`,
   `SLUG SHELLS $120`, `UNLIMITED AMMO $900`, `BEATER LICENCE $250`, **`RED STAG CARD $750` with
   the `SOON` tag**, `HIGH SEAT ACCESS $600`, `ALWAYS HUNTER $2000`; wallet `$12000 MONEY` and
   `30 HUNTS`; the detail pane's `$1500 PRICE` (the `MONEY_CAP` / `PRICE_CAP` split) and
   `BUY | $1500`. Every number carries its `$`.
2. **`.screenshots/221-shop-packages.png`** -- the **PACKAGES** shelf: `THE HIDE $575`,
   `THE MARKSMAN $1800`, `THE FULL SEASON $3750`.
3. **`.screenshots/221-bar-dollar.png`** -- `$12000 MONEY` on the top bar IN A DRIVE, camera at the
   player's eye (Y 144.7, root Y 143.2), beside `DRIVE 1`, `4:01 TIME`, `HUNTER` and `12 BUCK`.
4. **`.screenshots/221-shop-open.png`** -- the same bar after the drive ended, reading
   **`$12010 MONEY`**: the drive paid out $10 in dollars on top of the grant.

**NOT obtained, and not claimed:**

* **THE FULL SEASON's `INCLUDES:` line in the detail pane.** The panel's row selection does not
  respond to synthetic mouse clicks (tried at both the raw `AbsolutePosition` and with Roblox's
  36 px topbar inset); the detail pane stayed on `RIFLE, SCOPED`. `ShopPanel.select` is not a seam
  a probe can reach, because `execute_luau` has its own module cache.
* **The five NEW display models individually** (high seat, ammo crate, stag card, badge, package).
  I built them with the pure `ShopDisplay.build` and stood them in the world to photograph, but the
  camera was inside the lodge and they were occluded. **So the Reviewer's specific point -- that
  five new built models have never been looked at -- still stands**, and 218's pylon lesson still
  applies to them.
* **Smoke (standing rule A) was not run**, so nothing here says "ready for Karen".
* **The climb (218a(h))** remains not proven; the Director authorised recording it rather than
  blocking.

The Forest Test's attributes were read **before and after** and are unchanged by me
(`DHShopTestGrant=true, DHFlag_SHOP=true, DHFlag_COINS=true` both times). `tools/flags.py` was not
used, because it resolves the target Studio by MODE and not by place (TASKS.md 216b).
