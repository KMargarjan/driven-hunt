# Task 235 (the Director's 233b) - SHOP is a v1 default, and a world with no counter wires no shop

Task: 235
Round: 1
Base: main @ `cd3cb8be5603` (merge of #215, task 234)
Code commit: `64011862741483b04ab28fda270cb98232f4be02`

```
[harness] PASS: 34/34 checks @ 64011862741483b04ab28fda270cb98232f4be02 (clean tree) scope=all
```

1997 server + 519 client cases on a clean tree at the code commit, including the two new
`shop_door.spec` cases this task adds.

**`[harness2]` IS PENDING THE DIRECTOR AND THE REVIEW CANNOT RUN WITHOUT IT.** This change touches
`src/server/MatchBoot.server.luau`, which is in `TWO_PLAYER_PATHS`, and the line above is a FULL
`scope=all` line, so Task 113's scoped lane does not apply: `tools/agents.py` asks for `[harness2]`
and is right to. That lane is not reachable here either -- `src/server/MatchBoot.server.luau` is in
no `BLAST_RADIUS` row, so `test --scope auto` resolves to the whole suite and is tagged `scope=all`
-- and the Director's dispatch asked for `test2` on its own merits anyway (*"SHOP changes what a
drive's players carry"*). The exact clicks are in `ESCALATE.md`.

**THE TASK NUMBER.** The Director dispatched this as **233b**. The review folder takes a numeric id
(`tools/agents.py` matches `task-` plus digits), and `reviews/task-233/` already holds task 233's
round-2 `PASS`, which rule 7 forbids overwriting -- so this is `task-235`, the next free id, exactly
as task 149b became task 150 for the same reason (`8194b0b8`, *"the review folder takes a numeric
id"*). The Director may renumber the `TASKS.md` row; nothing in the code depends on it.

CI green on the branch: `Build and lint`, run 39695600861 (at `daede335`, the request's own
commit; this line is a later one-line edit to the same paperwork, so its own CI run is the
one the Director and the Reviewer should read off the PR head).

## What changed

`ESCALATE.md` 2026-10-21 item 2, **option A**, which the Director accepted: *"Do not wire a shop in
a world with no counter."*

Four files of `src/`, two specs. `SHOP.default` is `true`; `Shop.start` answers `false` when the
world was composed with no counter; and `ForestTestBoot` now says whether this world has one using
the lobby's own answer.

**Both new cases were shown FAILING on the pre-fix code before being offered as proof** (L-028).
One probe run, the gate deleted from `Shop.start` and nothing else changed:

```
failed [server] shop_door.spec:263 Expected value "false" (boolean), got "true" (boolean) instead
failed [server] weapon_equip.spec:366 / :486 / :603  Expected "true", got "false"
failed [server] weapon_rules.spec:442                Expected "12", got "0"
failed [client] weapon_client.spec:892               Expected "true", got "false"
[harness] FAIL: 30/34 checks @ 64011862 (DIRTY TREE (1 paths) - NOT valid evidence) scope=all
```

`shop_door.spec:263` is `expect(off.on).to.equal(false)` in *"wires nothing in a world with no
counter, so that world keeps today's kit"*. The five other lines are task 233's own measured red
list reproducing, which is the second half of the evidence: the gate is what closes them, and no
spec was re-baselined to hide them. The probe was reverted with `git checkout` and never committed.

## Claims, and how to verify each

1. **`SHOP` is a v1 default.** `Flags.DEFAULTS.SHOP.default` is `true`, with the flip's date, task
   and reason in the row, and the file's LIT/DARK census now reads `LIT (12)` / `DARK (2)`.
   *Verify:* read `src/shared/Flags/init.luau`, the `SHOP` row and the census comment above
   `Flags.MAX_FLAGS`. `python tools/flags.py` prints `SHOP on none on`.

2. **One decision, made once, at one boundary.** `Shop.start` returns `false` when
   `world.counterAt == nil`, before `started` is set and before the seam checks, and sets `enabled`
   false so `Shop.isEnabled()` agrees. Nothing else in the repository asks the counter question:
   the two composition roots branch on the single `shopOn` they already had.
   *Verify:* `Shop.start` in `src/server/Shop/init.luau`; then grep `src/` for `Shop.isOn` and
   `ShopData.isOn` -- three reads, all accounted for in claims 4, 7 and 8.

3. **The predicate is the SEAM, not its answer.** `world.counterAt == nil` (no reader was supplied)
   and not `world.counterAt() == nil` (a reader that answers nil right now). So task 178's existing
   case *"refuses every purchase in a world with no counter at all"* -- which supplies a reader
   returning nil -- is untouched and still gets a started shop and a `too-far` refusal. It passes
   unchanged in the green run.
   *Verify:* the gate's comment in `Shop.start`, and that case in `tests/server/shop_door.spec.luau`
   beside the two new ones.

4. **The DEV place is unchanged, which is why the flip is safe.** `MatchBoot` passes
   `counterAt = nil` (`Lobby.ANCHORS` has no `map:v1` row, and `MatchBoot` never calls `Lobby.start`
   at all), so `shopOn` is false there and not one of the three providers it hangs off that `if` is
   wired -- the entitlement, the licence, the look. Every reader then answers nil, which is today's
   game by every branch (`docs/design/shop.md` section 7.1).
   *Verify:* the `Shop.start` call and the `if shopOn then` block in
   `src/server/MatchBoot.server.luau`; and the gate line above -- 34/34 with the row lit.

5. **Both arms are reachable BY PARAMETER and both are specced.** `shop_door.spec` gains
   *"wires nothing in a world with no counter, so that world keeps today's kit"* (the door is not
   even listening, `onRequest` answers nil, nothing is sent, nothing is purchased, and the kit is
   the full loadout with the shotgun's own `START_RESERVE.Slug`) and *"wires the shop in a world
   that has one, and an un-owning player then has buckshot"* (`on == true`, the purchase is taken
   with `atCounter == true`, and `{}` gives one weapon -- `Weapons.PRIMARY` -- with `ammo == "Buck"`
   and `reserve.Slug == 0`).
   *Verify:* both cases in `tests/server/shop_door.spec.luau`; the `noCounter` field in that file's
   `started` helper, which exists because `opts.counterAt or <default>` cannot express "no reader at
   all". And the L-028 probe above, which shows the first one red on the pre-fix code.

   **The limit, stated rather than papered over:** a spec cannot run a composition root, so the KIT
   half of each arm is asserted against the two pure owners of it (`Weapons.loadoutFor` and
   `Shop.startFor`), not through a live `setEntitlementProvider`. What ties them is
   `setEntitlementProvider`'s own documented contract -- unwired means the provider answers nil, and
   nil is the full loadout and the weapon's own shells. The end-to-end evidence is the DEV gate (the
   unwired arm, 34/34) and the Forest Test (the wired arm), which is NEEDS DIRECTOR in `ESCALATE.md`.

6. **The Forest Test says whether it has a counter the way it says everything else about its
   lobby.** `counterAt = if lobbyOn then Lobby.Data.counterPosition else nil` -- the counter is a
   part of the lodge, `Lobby.start` is the one thing that builds a lodge, and `enrol` and
   `gatherSpot` in the same file's `Match.start` call are written in exactly that shape. Before this
   change a lobby that failed to build still handed the shop a live reader, so a player would have
   carried buckshot with no counter anywhere to buy at.
   *Verify:* the `Shop.start` call in `src/server/ForestTestBoot.server.luau`, and `enrol` /
   `gatherSpot` in the `Match.start` call below it.

7. **The two flag reads in that file cannot disagree, and the reason is the order.**
   `Lobby.start`'s `shopOn = ShopData.isOn()` decides one thing -- whether the keeper's prompt is
   live -- and it runs well before `Shop.start`, because `Shop.start` needs the counter that call
   builds. Inside the build "there is a counter" is true by construction, so the only arm where they
   could differ is the arm where `Lobby.Build` never ran and there is no keeper to hang a prompt on.
   *Verify:* the `shopOn` field comment in that file's `Lobby.start` call.

8. **The client's dark path is driven by parameter, not by the default.** Two cases in
   `tests/client/shop_panel.spec.luau` pinned `Shop.isOn() == false`, which the flip makes false.
   They now call `Panel.setEnabled(false)` and assert `Panel.isEnabled()`; the `afterEach` that
   restores *"the build's own value"* is unchanged and now restores `true`. No assertion was
   weakened: the off case still proves `setNear(true)` opens nothing and an injected prompt opens
   nothing.
   *Verify:* that file's header, its `afterEach`, and *"opens nothing at the counter while the flag
   is off"*.

9. **The run was repeated, because this suite flakes** (L-033). Four `test` runs at this commit:
   run 1 FAIL 32/34 on `camera_client.spec:1618`, runs 2 and 4 PASS 34/34, run 3 the deliberate
   L-028 probe. `camera_client.spec:1618` is the known flake `ESCALATE.md` named at `e2d41773`, at
   this same line; the inner assertion is `handsMissing > missingBefore` after a cleared hand
   template and a `task.wait(0.3)`, inside the viewmodel's own templates case. It cannot reach this
   change: `shopOn` is false in DEV, so no provider is wired and the player's path is the one that
   was already green on `main`.
   *Verify:* re-run `python tools/studio_mcp.py test` at this commit; and
   `tests/client/camera_client.spec.luau` around that line.

10. **No spec was re-baselined to let the flip through.**
    `backups/2026-10-21_task-233_shop-on-spec-pins.txt` -- the archived diff that took the server
    side to zero failures by unwiring the entitlement inside `weapon_equip.spec` and
    `weapon_rules.spec` and giving `Weapon.setEntitlementProvider` a return value -- is **not
    applied**. Nothing under `src/server/Weapon/` or `tests/server/weapon_*.spec.luau` changed. The
    probe run above is what shows those cases still red on the pre-fix code and green only because
    of the gate.
    *Verify:* `git diff cd3cb8be..64011862 --stat` -- six files, and no `weapon` file among them.

## What I could not verify

* **`test2`.** The Builder cannot run it. `ESCALATE.md` carries the NEEDS DIRECTOR with the clicks.
* **The Forest Test, which is the whole WIRED arm's live evidence.** Its Studio is not open
  (`list_roblox_studios` answers one Studio, DEV / `136410205938347`), and the Director's standing
  capture block says the Director opens it. So the dispatch's item 3 -- the hotbar and the ammo chip
  on a fresh player at the lodge and in the drive -- is NOT measured here. What a fresh player
  carries is stated from the data instead, in the report and in `ESCALATE.md`, and it is exact: one
  weapon (the shotgun), `ammo = "Buck"`, pockets `Buck 12 / Slug 0`, against `Slug 12 / Buck 12` and
  a rifle beside it in a world with no counter.
* **Whether Karen wants that first-minute experience.** It is the v1 ladder as reviewed in tasks 178
  and 221, but she has played the Forest Test with her own place attributes and a granted profile,
  never as a fresh player. It is hers to judge and it is in the report.
* **The design doc.** `docs/design/shop.md` section 10.4 still says every purchase in the DEV place
  is *"refused `too-far`"*; it is now stricter than that -- the shop is not wired there at all. The
  Architect owns `docs/design/`, so the delta is reported, not written.
