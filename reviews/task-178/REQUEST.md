# Task 178: the shop in the lodge

Task: 178
Round: 2
Base: main (`0f58b87`, #161 merged -- task 177's lobby)
Code commit: `bcccaf989d91d38e0ed45222cd5b048887bb0070`

Harness, FULL `test`, TWICE on a clean tree at the code commit:

```
[harness] PASS: 33/33 checks @ 6a17fc702a1e84a71aa4e4917d2f9f1f86d1d219 (clean tree) scope=all
[harness] PASS: 33/33 checks @ 6a17fc702a1e84a71aa4e4917d2f9f1f86d1d219 (clean tree) scope=all
[harness] PASS: 33/33 checks @ bcccaf989d91d38e0ed45222cd5b048887bb0070 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ bcccaf989d91d38e0ed45222cd5b048887bb0070 (clean tree)
```

**(Director: the two lines above are now real, run at the head; only paperwork after `6a17fc7`.)** The two-player run needs a
human click the Builder cannot make, and the Director's dispatch asked for exactly this stop:
`ESCALATE.md` carries **NEEDS TEST2 178 6a17fc7**. Round 1's line was the Director's at the previous
head; the code has changed since, so it does not carry.

Server assertions 1347 -> 1352 (the five new cases below); client unchanged in count.

## What changed since round 1

**Finding 1 -- the licensed beater now has a test that can fail.** The Reviewer was right: the rule
had no test anywhere, and the case the request cited would have passed with the feature deleted.

**Why the design's own case (§12.2, *"with an economy injected at `Match.start`"*) cannot exist:**
`Match` is a SINGLETON that `MatchBoot` has already started, and `Match.start` asserts *"called
twice"*. No spec in this repository starts one (`grep "Match.start(" tests/` is empty), and stopping
the live drive mid-session would pull the floor out from under `match_live.spec`, `zz_drive_boundary`
and `match_teams.spec`'s own two live cases. So the rule is proved the way this repo already proves
a branch nobody can reach -- and both halves are new:

* **`Match.mayCarryFor(facts, config)` is PURE and exported** -- `Match.unassignTargets`' own stated
  shape and reason (*"so the rule is a table of cases in a spec rather than a branch nobody can
  reach"*). `Match.mayCarryWeapon` is now a four-line gatherer that calls it.
* **The ownership read moved OUT of the Driver branch**, so a spec can prove the live function really
  asks. `Match.setOwnedProvider` installs a tripwire and hands back the one it replaces --
  `Weapon.setArmingPolicy`'s exact shape, and its stated reason (task 150).

**The Director's Studio test grant** (new in this round, for Karen's morning): `DHShopTestGrant=true`
on `ServerStorage` tops every profile in a **Studio** session up to `Economy.CONFIG.TEST_GRANT`
(2000 coins, 25 hunts) at load.

**Four of the round-1 notes fixed** (`Shop.forget` had no caller; the arming sweep asked the
unnarrowed loadout; `Receipt` declared twice; the panel built 8 rows into a 5-row frame), plus two
spec niggles (`rowsFor`'s unused 5th parameter, `statePayload`'s hardcoded `coinsOn`).

## Claims, and how to verify each

1. **A beater carries a gun only with the licence, and the rule fails if it is deleted.**
   *Verify:* `tests/server/match_teams.spec.luau`, "a beater may carry a gun only with the licence":
   (a) the pure case over nil / `{}` / `{ ["licence.beater"] = true }` / a set holding something else
   / `DRIVERS_MAY_SHOOT = true` winning first / `Waiting` / tied / a Shooter / no team at all --
   **delete the last line of `Match.mayCarryFor` and the licensed case answers false**; (b) the
   tripwire case: the live `Match.mayCarryWeapon(player)` asks the provider exactly once, with THIS
   player's userId -- **delete the read from the gatherer and nothing is asked**. (b) also proves the
   pcall: a provider that throws leaves his answer exactly as it was. *This is a structural argument
   from reading, not a measured mutation run -- said plainly, as rule 8 asks.*

2. **The old claims 6 and 8 are now true.** Claim 6's "four cases each" and claim 8's *"Verify:
   `shop.spec`"* were both false for this reader; `shop.spec`'s case now asserts `Match.mayCarryFor`
   over the two states that matter and points at `match_teams.spec` for the rest.

3. **The Studio test grant cannot reach a live server.** It needs `RunService:IsStudio()` AND the
   attribute to be the boolean `true`.
   *Verify:* `economy.spec`, *"is impossible on a live server, whatever the attribute says"* --
   `testGrantFor(false, true)` is nil (the only shape in which the live branch is provable from
   inside Studio, `Economy.storeKindFor`'s own argument), and `(true, nil/false/"true"/1)` are nil
   too. **The same predicate already decides the store**, so where a grant is possible nothing is
   saved and where something is saved no grant is possible.

4. **It raises, buys nothing and saves nothing.**
   *Verify:* `economy.spec`, *"tops a Studio session up without buying anything or saving anything"*:
   the poor man reaches 2000/25, the rich one keeps 9000/40, `ownedOf` is empty, `store.calls().save`
   is 0, the saved key still holds what he really earned -- and he can then buy the rifle, which is
   the whole point of the fixture. Plus *"grants nothing when it is not asked for"*, which is every
   harness run (the spec fixture passes `testGrant = false` by default, because
   `RunService:IsStudio()` is ALWAYS true in a harness run).

5. **It is not a feature flag, and the cost of that is stated.** `DHShopTestGrant` is not a
   `DHFlag_`, so `tools/flags.py clear` does not clear it and **the harness does not refuse to run
   while it is set** -- which is why it is also injected (`world.testGrant`), why every spec drives
   it by parameter, and why TASKS row 2's publish strip list now names it.
   *Verify:* the assertion on the name in `economy.spec`; `Economy.TEST_GRANT_ATTRIBUTE`'s header;
   TASKS.md row 2; `GAME_DESIGN.md`'s economy row.

6. **`Shop.forget` is actually called now.** `Shop.start` connects `PlayerRemoving` and pushes the
   connection onto `connections`, so the one table keyed by a player is pruned and `stop` still
   disconnects everything.
   *Verify:* `src/server/Shop/init.luau` `start`; `shop_door.spec`'s *"forgets a player"* case now
   certifies a cleanup production runs.

7. **The arming sweep counts a real repair again.** It asks `Weapons.loadout(askOwned(player))`, the
   same list `refreshArming` grants from, so a player who has not bought the rifle is no longer one
   `armingRepairs` per sweep.
   *Verify:* `src/server/Weapon/init.luau`, the sweep; the two calls now take the same argument.

8. **Everything round 1 claimed still holds.** The catalogue and its invariant, the eight-reason
   refusal and its order, `Economy.purchase` as the only writer (double click, forged id, poor,
   locked, no profile, too far), the profile's clone-and-freeze, the four readers' defaults, the
   slug allowance, the door's whitelist and rate limit, and the panel.
   *Verify:* `shop.spec`, `shop_door.spec`, `economy.spec`, `economy_store.spec`,
   `shop_panel.spec` -- all green in both runs above.

## What I could not verify

* **The two-player line.** As above: `ESCALATE.md`, NEEDS TEST2 178 6a17fc7.
* **A measured mutation run** behind claim 1 (reasoning from the code, not a re-run with the feature
  deleted).
* **The live grant in Karen's session.** The last smoke and screenshot were taken at `f6e6c7d`,
  before this round; the grant changes `Economy.load` only, and no harness run can exercise it
  (`testGrant = false` there by construction). The Director sets the attribute in the Forest Test.
* Unchanged from round 1: a live DataStore write, a real tap on a button, and the screenshot showing
  0 coins (the grant is exactly what fixes that for Karen's next session).

## Round-1 notes QUEUED, not fixed (and why)

* **`setNear` has no hysteresis** -- a man on the 14-stud boundary opens and closes the panel. Needs
  an in/out band (`Objective.CONFIG.ARRIVED_IN_STUDS`'s shape) plus a spec; not 60 minutes' work
  beside finding 1.
* **The panel's right edge sits under the rail on a 400 px screen** -- a real overlap, and it needs
  a measured layout decision plus the `hud_clarity.spec` case the design asked for. Karen's PC
  viewport is wide enough that it does not occur there.
* **`Lobby.counterPart` does not memoise a negative** -- harmless in both shipped worlds.
* **Three spec gaps against design §12.2** (`Lobby.counterPart`, the entitlement provider's wiring
  into `refreshArming`/`grant`/`refillForDrive`, the look provider into `dressWhenLoaded`). The red
  hat on a character still has no evidence in the repo.
* **`GAME_DESIGN.md`'s Match/Hud/Weapon rows** were not amended separately (the facts live in the new
  shop-door row); the Economy row is amended twice now. The Architect's/Director's to settle, with
  `CREDITS.md`.
