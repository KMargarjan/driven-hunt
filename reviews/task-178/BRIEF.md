# Task 178 BRIEF: the shop in the lodge

The input to `tools/architect.sh design shop --task 178`. Written by the Builder, carrying the
Director. It overrides anything older in `docs/`, `TASKS.md` or an earlier design.

Research note: `docs/research/2026-10-14-the-shop.md` (read it: the pattern and every number are
there).

## 1. What is already decided, and is not the Architect's to re-open

**Karen, verbatim** (2026-10-13): *"Hunting house where inside can shop things"*. (2026-10-10, her
design doc): *"There are houses where can buy weapons, License, Gear, Goods"*. (2026-10-10):
*"Rifle they has to purchase default is double barrel shotgun"*, *"They will have posibility to
purchase rifle but has to play a lot it's not few hunts"*, a beater *"can purchase license to shoot
in drive"*, *"buy packages for outfit"*. The weapon ladder she accepted with *"yes that seems
legit"*: shotgun buckshot (default) -> slugs -> open-sight rifle -> scoped rifle.

Decided by the Director in the dispatch:

1. **Coins only.** Robux is a later task. No `MarketplaceService`.
2. **The door is the counter** task 177 built inside the lodge
   (`Workspace.Lobby.Lodge.Inside.Shop.Counter`). Walk up to it, a panel opens.
3. **The panel is 165's UI language** (`Hud.Rail` / `Hud.ReportPanel`: one ScreenGui, the Hud builds
   the frame and one module writes everything inside it) with **mobile-friendly buttons**
   (`GuiButton.Activated`, >= 48 px tall).
4. **Buy is server-authoritative**: the economy owner deducts the coins and records the ownership in
   the saved profile, and refuses with a clear message when he cannot afford it.
5. **Prices are data**, named in the research note section 4, and **Karen decides them later**.
6. **The five items**: slug ammo, open-sight rifle, scoped rifle, the beater's licence to shoot, and
   one outfit item (a hat colour) to prove cosmetics.
7. **Owned items are applied at the next drive.** The loadout owner reads ownership. **The task 171
   fire rules are otherwise unchanged** -- in particular a beater with the licence is no longer
   refused a gun FOR BEING A BEATER, and `Rules.beaterInLine` still refuses him a shot AT a beater.
8. **Completed hunts are counted in the profile**, because that is the data the unlocks read.

## 2. The Builder's own reading, for the Architect to accept or correct

* **Owners.** `ReplicatedStorage.Shop` is the catalogue and the pure rules (no writer, no state);
  `ServerScriptService.Shop` is the one owner of the shop's door, its rate limit and the commit
  order; `ServerScriptService.Economy` STAYS the one owner of a player's profile and gains the
  ownership set and the hunt count as fields of it. The shop owns no store, no key and no session,
  and `Economy.purchase` is the only function that writes either half of a purchase.
* **The readers of ownership are the owners that already decide those things**, each through an
  injected provider wired at the composition root, so neither owner requires the other and an
  unwired world behaves exactly as it does today: `Weapons.loadoutFor` (the rifle),
  `Weapon.StateMachine.initial` / `Weapon.refillForDrive` (the slug allowance),
  `Match.mayCarryWeapon` (the beater's licence), `Match.Body.dress` (the hat colour).
* **The flag is `SHOP`, born OFF.** `Flags.MAX_FLAGS` is 12 and twelve are declared, so this task
  bumps it to 13 with the reason written next to it (seven of the thirteen are dark; the cap's own
  comment is about dark paths).
* **The open-sight rifle is shown and not for sale.** Karen removed that weapon in task 148
  (*"please remove rifle without scope so we don't implement now"*); its row is archived in
  `backups/2026-10-10-rifle-open-sights.md`. A shop that sells an entitlement no build can grant is
  a lie on the screen, so the catalogue carries the rung with `sale = false` and the panel prints
  SOON. **This is the one place where the dispatch's five items become four buyable ones, and it is
  deliberate.**

## 3. What the design must contain

1. The system owners and the exact boundary between `Shop`, `Economy` and the four readers above
   (what each one may write; who may read the profile).
2. The purchase order of operations -- test, then execute -- and what must be true for a double
   click, a forged item id, a forged price, a player with no open profile session, and a player who
   leaves between the request and the commit.
3. The wire: what crosses the remote in each direction, and what the server validates.
4. Where the ownership set and the hunt count live in the profile, and what a build that does not
   know about them must do with them (`Store.read`'s keep-unknown-keys rule).
5. Who owns the panel's state (open, the message line) and who owns its `Visible`.
6. Which spec proves each rule, named one by one.
7. Any open decision that needs the Director or Karen, as a numbered list.
