# Task 298 step B4 — the range's menu, its board and the two remotes

Task: 298
Round: 2
Base: 98df981b (task-298b3-range-gate, step B3's PASS)
Code commit: edc0f24a12f9d4c07fa00ab2b8c06f820f36cd9a

Harness, clean tree, full suite:

```
[harness] PASS: 34/34 checks @ edc0f24a12f9d4c07fa00ab2b8c06f820f36cd9a (clean tree) scope=all
```

`test2` is **N/A**: `agents.needs_two_player` over this branch's 25 changed paths returns `[]`.
Nothing here is in `TWO_PLAYER_PATHS` — the Hud, the weapon's own signals and the range are things
that behave the same with one player as with two.

What changed: `src/shared/Range/Remotes.model.json` (new), `src/shared/Range/init.luau`,
`src/server/Range/init.luau`, `src/server/RangeBoot.server.luau`,
`src/client/Hud/RangePanel.luau` + `RangeBoard.luau` (new), `src/client/Hud/init.luau`,
`tests/server/range.spec.luau`, `tests/client/range_panel.spec.luau` (new), `tools/studio_mcp.py`
(the two new scope rows).

## Round 1's four findings, each fixed with a case

1. **The species and the kind could disagree.** The kind now follows the species the way the load
   follows the gun; a kind named in the same request is validated against THAT species (`lists` was
   captured before the loop, which is how it got through); and the board's columns are read off the
   animal that is SPAWNED — `boars.zonesForKind(trial.kind)` → `Boar.kindConfig`, the resolution
   `Runtime:spawn` itself does. Case: *"keeps the kind with its species, and reads the columns off
   the animal it spawns"* — it also refuses `species = boar, kind = stag` in one message.
2. **`onHitReported` counted every hit in the place.** It now counts only a hit belonging to a shot
   this module counted: the `pending` slot `onShotResolved` writes, keyed on that shot's number. A
   record leaves with its player (`Range.forget`, wired to `PlayerRemoving` in `RangeBoot`) and
   `stop` hands the records back with the lane. The off-the-mat refusal has its own counter
   (`stats.offMat`). Case: *"counts only the hits of the shots it counted, and forgets a player who
   leaves"* — the first half fails on the old code.
3. **`RangePanel.setNear` had no caller.** `Hud.step` now tells both panels whether he is still at
   the spot, by `RangeData.atSpot` — the PROMPT's own reach, so the client's closer and the server's
   refusal are one measurement — and the board leaves with the menu (`RangeBoard.setNear`). Cases:
   `range_panel.spec` → *"gives both doors back when he walks off the spot"* and *"leaves the screen
   when he walks off the spot"*; `range.spec` → *"says he is at the spot by the prompt's own reach"*.
4. **The deer-columns case passed with the code deleted.** A SERVER case now picks the deer through
   `Range.onRequest` and asserts the record's order against `Boar.kindConfig(trial.kind).ZONES.ORDER`
   — the seam, not a literal the spec fed in. The spec's fake runtime gained the two readers the
   owner uses (`kindsFor`, `zonesForKind`), wired as `RangeBoot` wires them.

The non-blocking notes are not fixed in this round and are queued in `TASKS.md`.

## Claims

1. **Two remotes, and the range's one inbound door.** `RangeRequest` / `RangeBoard` in
   `src/shared/Range/Remotes.model.json`; `Range.onRequest` is public, rate-limited per player
   (`CONFIG.REQUEST_MIN_INTERVAL`), measures the mat off the character the server can see
   (`Range.mayShoot`), and counts a forged payload apart from a legal pick the game refused
   (`stats.badRequests` vs the off-the-mat return). Verify: `range.spec` →
   *"refuses a forged payload and a pick from a man who is not on the mat"*.

2. **One whitelist, read by both sides.** `RangeData.optionAllowed(kind, value, lists)` is asked by
   the server's door and by `RangePanel.select` before anything leaves the client. An unknown kind
   is false; a species or kind the server did not offer is false; a cartridge is asked against the
   gun of that same request. Verify: `range.spec` → *"accepts each gun and only the cartridges that
   gun really carries"*, *"refuses a species or a kind that the server did not offer"*;
   `range_panel.spec` → *"reads the gun rows and each gun's own cartridges from Weapons"*.

3. **The Pace list is Karen's four words with STAND.** `RangeData.PACE_ORDER`, asserted against
   `Range.WORD` and not against four strings. Verify: `range.spec` → *"offers the four pace words
   with STAND…"*; `range_panel.spec` → *"offers exactly the four pace words, STAND among them"*.

4. **`Range` is the one writer of the record; the board is a renderer.** `onShotResolved` counts a
   shot (hit or miss — a miss produces no `HitReported`), `onHitReported` counts the hit in
   `report.zone` and only once per shot, and `RangeBoard.luau` draws what it is sent. Verify:
   `range.spec` → *"counts a shot, a hit in its own zone, a miss, and resets on the same door"*.

5. **The zone columns are the animal's own.** Read through `boars.zonesFor` (wired in `RangeBoot`
   from `Boar.speciesConfig`) — five for a boar, six for a red deer — plus MISS. Verify:
   `range_panel.spec` → *"prints the animal's own zone columns…"* and *"prints a red deer's six
   columns from the order it was sent"*.

6. **The signed miss gap, in metres, in Karen's words, through the repo's one conversion.**
   `Range.gapStuds` projects `endPoint` onto the target's travel; `RangeData.gapText` says
   `0.9 m behind` / `0.4 m ahead` using `Report.CONFIG.METRES_PER_STUD` (no second copy of 0.28).
   The sign is opposite on an east leg and a west leg, and STAND has no gap. Verify: `range.spec` →
   *"signs the miss gap against the target's own direction, both ways"* and *"says the gap in metres
   through the repository's one conversion"*; `range_panel.spec` → *"prints the signed miss gap…"*.

7. **The two doors, by the tag `range`, and no `GuiButton.Modal`.** `RangePanel.setOpen` is
   `ShopPanel.setOpen` with one word changed. Verify: `range_panel.spec` → *"opens and closes
   through the prompt, and holds the two doors by the tag range"* — it asserts the tag was ADDED and
   GIVEN BACK and that `Cursor.stats().reasserts` did not move; `grep -n Modal src/client/Hud/RangePanel.luau`
   finds only the header saying it is not used.

8. **A reset is a pick, through the same door.** `request.reset` clears THIS player's record only,
   whitelisted like any other word. Verify: the reset half of claim 4's case (a second player's
   record is untouched), and `range_panel.spec` → *"asks the server to reset…"*.

9. **The CONFIRM bar contains the viewport centre** — the one point the input replay can click
   (design 11.3). `RangePanel.confirmPosition` reads `GuiService:GetGuiInset()`. Verify: the live
   reading below, and `RangePanel.rowRect("confirm")`.

10. **`Range.issuedSpeedFor` is the one answer to "what speed is asked for"** — read by `order` and
    printed by the board, which closes B2's queued note at the root: the pace's own speed is 0 at
    STAND while the target is ordered to WALK to the middle, and the board prints both, labelled.
    Verify: `range.spec` → *"publishes the speed it ISSUES, which at STAND is the walk it orders"*.

## Live, in DEV, with `RANGE` on (`tools/flags.py set RANGE on`, cleared before the harness run)

`[RangeBoot] the range's two relaxations and the four guns on loan are composed` — step B3's
*"install order NOT PROVEN — compose() never executed in evidence"* is now proven in DEV.
A real client `FireServer` on the real `RangeRequest`, after a real pick, produced:

```
ROW species: BOAR | REDDEER        ROW pace: STAND | WALK | TROT | RUN
ROW weapon: SHOTGUN | RIFLE | LEVER | AUTO    ROW ammo: .45-70   ROW distance: 125 studs (35 m)
BOARD 4: PACE TROT  pace 11.0 studs/s  issued 11.0 studs/s
BOARD 5: LEAD BALLISTIC 0.64 studs (Ballistics.leadStuds)
BOARD 6: LEAD VIEW <= 3.31 studs (the configured window, a bound)
CONFIRM 334.5, 268 size 300, 140 contains centre 484.5, 396: true
```

Screenshots, looked at: `.screenshots/298b4-menu.png` (the defect: an empty black box) and
`.screenshots/298b4-menu3.png` (fixed — six rows, the lit picks, the board's eight lines).

## What could NOT be verified (see `ESCALATE.md`)

- **The live scenario of design 11.3 is not in `input_scenarios.txt`.** With `RANGE` at its default
  the composition root returns before anything is built, so a harness scenario cannot reach a range
  by parameter: the flag is read by the BOOT, not by a module the spec can call. NEEDS-DIRECTOR.
- **A range hit has still never been seen** (B3's own open item). Four real `FireRequest` shots down
  the lane produced no resolved shot in DEV and no board row; the cause is not established. So the
  board's HIT and zone columns are proven by their cases and NOT on screen.
- **LEAD VIEW is always the bound.** `HitReported` / `ShotResolved` carry no per-shot measured lag at
  this commit, so the measured branch of design 9.2 is unreachable and is queued, not claimed.
