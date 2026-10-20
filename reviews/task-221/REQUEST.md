# Task 221 -- money in dollars, and the v1 shop catalogue

Task: 221
Round: 1
Base: main (`2ca8bdd`)
Code commit: `61ad71a9eb3ae360ff73a5b0bb8ec652fdb1623e`

```
[harness] PASS: 33/33 checks @ 61ad71a9eb3ae360ff73a5b0bb8ec652fdb1623e (clean tree) scope=all
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

* **`$` on the top bar, in a drive**: `.screenshots/221-bar-dollar.png`, camera at the player's eye
  (Y 144.7, root Y 143.2) -- the chip reads **`$12000 MONEY`**, beside `DRIVE 1`, `4:01 TIME`,
  `HUNTER`, and the ammo chip `12 BUCK`.
* **The drive paid out in dollars**: `.screenshots/221-shop-open.png`, same session after the drive
  ended -- the chip reads **`$12010 MONEY`** ($10 participation on top of the $12,000 test grant).
  (That frame was shot for the shop panel, which is why it also shows the panel NOT open.)
* `ReplicatedStorage.Money` resolves live in the Forest Test: a client probe returned
  `money1240=$1240`.

The Forest Test's attributes were **read before and after and not changed by me**
(`DHShopTestGrant=true, DHFlag_SHOP=true, DHFlag_COINS=true` both times). I did not use
`tools/flags.py`, because it resolves the target Studio by MODE and not by place (TASKS.md 216b).
