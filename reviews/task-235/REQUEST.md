# Task 235 (the Director's 233b) - SHOP is a v1 default, and a world with no counter wires no shop

Task: 235
Round: 1
Base: main @ `cd3cb8be5603` (merge of #215, task 234)
Code commit: `f771624961b0438b2ddb8bee68706ef8bb39bca9`

```
[harness]  PASS: 34/34 checks @ f771624961b0438b2ddb8bee68706ef8bb39bca9 (clean tree) scope=all
[harness2] PASS: 36/36 checks @ f771624961b0438b2ddb8bee68706ef8bb39bca9 (clean tree)
```

One player: 1997 server + 519 client cases. Two players: server 1997/0, shooter 519/0, driver 513/0.
Both on a clean tree, **both naming the same commit** (L-034; this feature's two harness lines drifted
apart in task 66 and in task 179 round 3). The two-player run is the Director's
(`<runs-dir>/test2-t235.log`); the one-player run is this session's, at the same commit, after it
(`<runs-dir>/test-f7716249.log`, exit 0).

**THE CODE COMMIT IS A PAPERWORK COMMIT, DELIBERATELY.** The last commit that changed `src/` or
`tests/` is `64011862`; `f7716249` is two paperwork commits later, and it is the commit BOTH harness
lines name. CLAUDE.md git workflow step 4 allows exactly this -- *"naming a later paperwork commit is
allowed and is often unavoidable ... it only makes the bound stricter"* -- and it is the stricter
bound here, because the harness ran over everything `64011862` contained plus the paperwork.
`git diff f7716249..HEAD` is `REQUEST.md`, `ESCALATE.md` and `TASKS.md` and nothing else.

**THE TASK NUMBER IS 235, by the Director's word of 2026-10-22:** *"keep 235 for this task. The
licence popup the Director had called 235 is now 238."* The review folder needed a numeric id
(`tools/agents.py` matches `task-` plus digits) and `reviews/task-233/` already holds task 233's
round-2 `PASS`, which rule 7 forbids overwriting -- the same renumbering task 149b took to become
task 150 (`8194b0b8`).

**THE SCREENSHOT IS WAIVED FOR THIS ROUND BY THE DIRECTOR** (2026-10-22): *"The Forest Test stays
closed tonight. I will check the fresh player's kit on the player's path in my morning smoke and
report it to Karen."* So rule 5's frame for the WIRED arm -- the hotbar and the ammo chip on a fresh
player at the lodge and in the drive -- is not in this round, and it is not a gap this request
papers over: it is the Director's next step, and what a fresh player carries is stated from the data
in `ESCALATE.md` and in the report. The DEV place cannot stand in for it, because DEV has no counter
by construction and that is the whole point of the change.

CI green on the branch: `Build and lint`, run 39695695009 at `f7716249` (and 39695600861 before it).
This fill is a later paperwork commit, so the Director and the Reviewer should read CI off the PR
head rather than off this line.

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
   `src/server/MatchBoot.server.luau`; and the two gate lines above -- 34/34 one player and 36/36
   two players, with the row lit. **The two-player run is what shuts the one hole a one-player run
   leaves here**: a provider reaching players by some path that is not that `if` would show as a
   different kit on the OTHER client, and the driver's 513/0 and the shooter's 519/0 are the same
   numbers task 233's green two-player run gave with the row DARK.

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
   nil is the full loadout and the weapon's own shells. The end-to-end evidence for the UNWIRED arm
   is the DEV gate, both runs; for the WIRED arm it is the Forest Test, which the Director has taken
   into the morning smoke (see the waiver above). Nothing in this request claims a frame.

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

* **The WIRED arm on a live player's path.** The Forest Test Studio stayed closed and the Director
  **waived the frame for this round**, taking it into the morning smoke (quoted above). So no claim
  here rests on a picture of a fresh player's hotbar or ammo chip. What he carries is stated from the
  data and it is exact: one weapon (the shotgun), `ammo = "Buck"`, pockets `Buck 12 / Slug 0` --
  against `Slug 12 / Buck 12` and a rifle beside it in a world with no counter. The DEV place cannot
  stand in: it has no counter, which is the arm the gate DOES cover.
* **Whether Karen wants that first-minute experience.** It is the v1 ladder as reviewed in tasks 178
  and 221, but she has played the Forest Test with her own place attributes and a granted profile,
  never as a fresh player. It is hers to judge; the Director is reporting it to her.
* **The design doc.** `docs/design/shop.md` section 10.4 still says every purchase in the DEV place
  is *"refused `too-far`"*; it is now stricter than that -- the shop is not wired there at all. The
  Architect owns `docs/design/`, so the delta is reported, not written.
* **One thing I deliberately did NOT do** (L-041, and it is the Director's call): mapping
  `src/server/MatchBoot.server.luau` to `match` in `BLAST_RADIUS` would have opened Task 113's
  scoped lane and dropped the `[harness2]` requirement. That gate has now PASSED, so editing the map
  in this closeout round could only serve to dodge a gate that already answered. The observation
  stays an observation.
