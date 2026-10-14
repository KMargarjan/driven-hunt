# Task 178: the shop in the lodge

Task: 178
Round: 1
Base: main (`0f58b87`, #161 merged -- task 177's lobby)
Code commit: `f6ec1fe20c3787546ef13a88ef8d5c7ffda95437`

Harness, FULL `test`, TWICE on a clean tree at the code commit:

```
[harness] PASS: 33/33 checks @ f6e6c7df0f3ef5df55f346a54e39d3ffb1e8530a (clean tree) scope=all
[harness] PASS: 33/33 checks @ f6e6c7df0f3ef5df55f346a54e39d3ffb1e8530a (clean tree) scope=all
[harness] PASS: 33/33 checks @ f6ec1fe20c3787546ef13a88ef8d5c7ffda95437 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ f6ec1fe20c3787546ef13a88ef8d5c7ffda95437 (clean tree)
```

DIRECTOR NOTE: the last two lines are the Director's at the head `f6ec1fe` (only paperwork after `f6e6c7d`).

`[harness2]` **IS REQUIRED FOR THIS TASK AND IS NOT HERE YET**: the change touches
`src/server/Match/` (`mayCarryWeapon`, `Body.dress`) and `tests/server/economy*`, and the two-player
run needs a human click the Builder cannot make. The Director's dispatch asked for exactly this stop:
`ESCALATE.md` carries **NEEDS TEST2 178 f6e6c7d**.

## What changed

The shop Karen asked for, at the counter task 177 left inside the lodge: walk up to it, a panel
opens, buy with coins. **Behind the flag `SHOP`, born OFF**, and OFF is task 177's game bit for bit.
Built to `docs/design/shop.md` (Architect **PASS** at `f994887`), from
`docs/research/2026-10-14-the-shop.md`.

New: `src/shared/Shop/` (the catalogue and the pure rules), `src/server/Shop/` (the door),
`src/client/Hud/ShopPanel.luau` (the panel), three specs. Changed: `Economy` (+`purchase`,
`ownedOf`, `huntsOf`, `shopStateFor`), `Economy.Store` (the profile's `owned`, the widened
`load`/`save`), `Weapons.loadoutFor`, `Weapon` (+ one provider, the shell allowance),
`StateMachine.initial`, `Match.mayCarryWeapon`, `Match.Body` (the hat's colour), `Lobby`
(the counter's reader), `Hud`, both composition roots, `Flags`, `tools/studio_mcp.py`,
`GAME_DESIGN.md`.

## Claims, and how to verify each

1. **The catalogue is Karen's ladder and no row can lie about what it grants.** Five rows in
   `Shop.ROWS`, frozen, cheapest first; `Shop.rowsOk` refuses a row for sale whose grant no build
   ships, which is what FORCES `rifle.open`'s `sale = false` (Karen removed that weapon in task 148).
   *Verify:* `tests/server/shop.spec.luau`, "the catalogue" -- including the case that flips
   `sale` on and gets one problem naming `rifleOpen`.

2. **One rule decides a purchase, and the window and the till read it.** `Shop.refuse` answers the
   first of eight reasons in `Shop.ORDER_OF_REFUSAL`, with the number its line prints; `Shop.rowsFor`
   is the same rule read the other way for the panel.
   *Verify:* `shop.spec`, "the refusal" -- the eight reasons, the declared order with everything
   tripped at once, and *"agrees with the panel's own rows"* (`buyable == (refuse(...) == nil)`
   over six states).

3. **`Economy.purchase` is the only writer of either half, and it cannot double-charge.** It
   re-asks the two facts it owns, deducts, replaces the set WHOLE, and saves two fields; nothing
   between the test and the write yields.
   *Verify:* `tests/server/economy.spec.luau`, "the purchase" -- deducts once, `owned` frozen,
   one `save`, the double click refused `owned` with the balance unchanged, poor/locked/unknown/
   not-for-sale/too-far all writing nothing, no profile refused before and after a `release`.

4. **A purchase is not a completed hunt.** `Store.save` derives nothing now; `payDrive` increments
   `drivesPaid` (the hunt count the gates read, through `Economy.huntsOf`) and `coinsEarnedTotal`.
   *Verify:* `economy.spec`, *"counts one completed hunt per paid drive, and none for a purchase"*;
   `economy_store.spec`, *"writes exactly the fields it was given and derives nothing"*.

5. **One player's purchase cannot be written into every other player's profile.** `Store.TEMPLATE`
   is deep-frozen and `Store.read` CLONES a table default and replaces a wrong-typed key.
   *Verify:* `economy_store.spec`, *"holds an ownership set that no profile shares and nobody can
   write"*.

6. **The four readers of ownership default to TODAY'S GAME, and they do not all default the same
   way.** nil gives the full loadout, the weapon's own shells and the orange hat -- and gives a
   beater NO gun.
   *Verify:* `shop.spec`, "what ownership gives" (four cases each); `docs/design/shop.md` section
   7.1 is the table of why they differ.

7. **The slug is the enforcement and there is no second gate.** `Shop.startFor` gives a shotgun
   `Buck` and a slug pocket of 0 until `ammo.slug` is owned; `StateMachine`'s existing `"no-reserve"`
   refuses the rest. `Shotgun.CONFIG` is not edited.
   *Verify:* `shop.spec`, *"issues buckshot until the slug is bought"* and *"starts a state on the
   allowance"*; `rifle.spec` still asserts the shotgun row against `Shotgun.CONFIG` field by field.

8. **A licensed beater may CARRY a gun -- and nothing else about task 171 moves.**
   `Match.mayCarryWeapon` ends in `Shop.grantsDriveGun(ownedOf(userId))`, the same branch
   `DRIVERS_MAY_SHOOT` opens; `classifyTarget` still refuses him a shot AT a beater and
   `Penalty.judge` still ties him.
   *Verify:* `shop.spec`, *"gives a beater a gun only with the licence"*; `weapon_rules.spec` and
   `match_safety.spec` unchanged and passing.

9. **The door takes an item id and nothing else, and a forged packet buys nothing.** Two fields, a
   32-character bound, a per-player 4/s bucket, the reach measured per request, and a reply that is
   never fired at a player who has left.
   *Verify:* `tests/server/shop_door.spec.luau`, all ten cases.

10. **The panel draws what arrived and decides nothing, and with the flag off it opens nothing.**
    Every child above the panel's `ZIndex`, 360 px wide (it fits the 400 px screen
    `hud_clarity.spec` measures), every button >= 48 px.
    *Verify:* `tests/client/shop_panel.spec.luau`, nine cases -- and
    `.screenshots/20261014-task178-shop-panel-2.png`, the live panel at the counter in the Forest
    Test with `DHFlag_SHOP` and `DHFlag_COINS` on.

## What I could not verify

* **The two-player line.** `test2` needs a human click; `ESCALATE.md` has the entry.
* **A LIVE purchase reaching a real DataStore key.** Unchanged from task 170 and for the same
  reason: `Economy.storeKindFor(true) == "memory"` inside Studio, always. The pure predicate and the
  one `print` naming the store are the only evidence a live server would save one.
* **A tap on a button.** `GuiButton.Activated` cannot be synthesised by the harness, so
  `ShopPanel.press` / `pressRow` are the seams -- `Rail.press`'s stated limit, unchanged.
* **The screenshot shows a player with 0 coins**, so every row reads NO COINS: a Studio profile
  starts empty in the memory store and a drive is 300 s. The OWNED and BUY states are proved in
  `shop_panel.spec` from the same `Shop.rowsFor` the server calls.
* **The open-sight rifle is shown and not for sale** -- the one place the dispatch's five items
  become four buyable ones. Karen removed that weapon in task 148 and the catalogue's own invariant
  refuses to sell a grant no build ships.
* **`CREDITS.md` is not touched**, against the design's delta list: that file credits third-party
  ASSETS under licences that require it, and the two patterns borrowed here (OpenTTD, ioquake3) are
  ideas, not code -- neither is credited there for `Weapon.Rules` or `Drive.Rank` either. The note
  and the module headers carry the attribution.
* **Three design items are the ARCHITECT'S to write, not mine** (design section 14): the amendments
  to `economy.md`, `lobby.md`, `rifle.md`, `shotgun.md`, `beater-kit.md` and `hud-clarity.md`.
  `GAME_DESIGN.md`'s owner rows ARE updated here (two new, one amended).

## One deviation from the design, named

`Match.Body` gained an injected **look provider** (`Body.setLookProvider`) beside the `look`
parameter the design asked for. The parameter alone would have lost the bought hat on every
respawn: this module re-dresses a character from three of its OWN paths (the appearance window's
close, the respawn watch, the tie), and none of them is reached by a caller's argument. The seam is
`Body.setAccessorySource`'s, which the design itself cites as the right shape, and the pure
`Body.dressFor(team, config, look)` is unchanged from the design and is what the spec drives.
