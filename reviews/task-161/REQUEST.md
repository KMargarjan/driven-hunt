# Task 161 — review request: bots fill the drive

Task: 161
Round: 1
Base: `87dbccb` (main, PR #143 merged)
Code commit: `7d69a4e97ff31cd25aedf50b5db9214a68eb26c9`

```
[harness] PASS: 33/33 checks @ 7b23fddd51ea1c27e33ce1cefdd6e02333aacadb (clean tree) scope=all
[harness] PASS: 33/33 checks @ 7b23fddd51ea1c27e33ce1cefdd6e02333aacadb (clean tree) scope=all
[harness] PASS: 33/33 checks @ 7d69a4e97ff31cd25aedf50b5db9214a68eb26c9 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ 7d69a4e97ff31cd25aedf50b5db9214a68eb26c9 (clean tree)
```

**The two-player run is the Director's, by the dispatch** ("stop `NEEDS TEST2 161 <sha>` with a
`[harness2]` placeholder; I run test2 + the review"). This change touches `src/server/Match/`, which
is in `TWO_PLAYER_PATHS`, so the merge gate wants it. **Both Studios were left open and in Edit, and
no flag or pose override is set** — `test2` will start.

## What changed

A new owner, `ServerScriptService.Bots`, that fills a drive's empty slots with visible R15 rigs:
beaters in the beater outfit walking the wood abreast and blowing the real horn, hunters standing on
the free stands. Karen's v1 rule, 2026-10-11: *"Let's make 4 hunters 4 beaters"*, and she plays
**solo**. Behind the flag `DRIVE_BOTS`, **born OFF**.

Research note `docs/research/2026-10-12-bots.md` (four external sources, licences and maintenance),
brief `reviews/task-161/BRIEF.md`, design `docs/design/bots.md` (Architect **PASS**,
`reviews/task-161/ARCH_RESULT.md`).

## Claims, and how to verify each

1. **The fill is ioquake3's `G_CheckMinimumPlayers`, re-pointed, and it is pure.**
   `Bots.Fill.counts` is `max(0, target - real)` per side, total-capped, with `standsFree` clamping
   the hunters. Target 0 is the switch per side, and add/remove is symmetric.
   *Verify:* `src/server/Bots/Fill.luau` against `tests/server/bots_fill.spec.luau` — every real
   count 0…8 per side, the flag-off and missing-block cases, the per-side target-0 case, the
   `standsFree` clamp (and that `nil` is "not measured", which must NOT clamp), the cap's
   beaters-first trim, and `TARGET.hunters + TARGET.beaters <= MAX_BOTS` asserted so the trim is a
   *checked* unreachable rather than a coincidence.

2. **The line is the feature, and `PathfindingService` is rejected with three written reasons.**
   `Bots.Lane` gives lane 1..n alternating ±`LANE_SPACING_STUDS` from a base, along the **base's own
   `RightVector`**, with the goal offset by the same amount; lane 0 is never issued, so the middle
   stays the real beaters'.
   *Verify:* `src/server/Bots/Lane.luau` and `tests/server/bots_lane.spec.luau` (the rotated-base
   case is the one that matters — the forest's road is a sine). The rejection and its reasons are
   `docs/research/2026-10-12-bots.md` §3 and `docs/design/bots.md` §9.1.
   **MEASURED LIVE:** at GO in the Forest Test the four bot beaters stood at x = 2994, 3012, 3048,
   3066 about a base of 3030 — ±18 and ±36 exactly — and the three that remained arrived at the goal
   at z = −2116 still 18 studs apart. Numbers in §"What I did in the Forest Test" below.

3. **A bot is not a player, and the mechanism is that it has no userId — structurally, not by a
   filter.** No score row, no push credit, no safety verdict, no `participants` entry.
   *Verify:* `Bots.threats`/`Bots.beaters` ids are `"bot-hunter-N"`/`"bot-beater-N"`;
   `tests/server/bots_live.spec.luau` asserts `tonumber(id) == nil` for every one,
   `#Match.playerDrivers(threats) == 0` over the whole list, `Match.creditPush(nil, …) == 0`, and no
   snapshot row carries a non-numeric userId. `Match.driverThreats`, `playerDrivers`, `samplePush`,
   `pushCreditable` and `Penalty` are **unchanged** — check the diff.

4. **One dressing path, and `Match.Body`'s ownership sentence is restated rather than broken.**
   `Body.dress` already takes a `Model`; `Bots.Rig` never calls `Body.place`/`hold`/`stand`/`tie`/
   `dressWhenLoaded` and never touches the userId-keyed `held` table.
   *Verify:* the new header block in `src/server/Match/Body.luau`; the `dress` seam in
   `Bots.start{…}` in both composition roots; `bots_live.spec`'s "dressed once per body, by
   Match.Body and nothing else" (it also checks the painted `BodyColors` is `Body.BASE_COLOR`).

5. **One blast implementation, and a bot's blast pays nobody.** `Horn.blowTool` is `Horn.blow`'s own
   body factored out and keyed by a string; `Horn.blow` is now a two-line wrapper; `lastBlast` is
   re-keyed through `Horn.keyFor`. `Horn.giveTo(rig)` puts a real Tool in a rig's hand.
   *Verify:* `src/server/Weapon/Horn.luau`; the new `describe` in `tests/server/zz_horn.spec.luau`
   (one blast per key, the real cooldown refusing the second, a different bot being a different row,
   `blowerUserId == nil`, the blast published from the handle, `giveTo` idempotent). The player's own
   existing cases in that file are unchanged and still pass, which is the "no behaviour change"
   half. **MEASURED LIVE:** nine bot blasts in the Forest Test, each `0 credited`.

6. **One push source: the phantoms stand down while a bot beater is pushing.**
   `ForestTest.setBotThreats` is the one injected source; `realBeaters()` gains the driver-kind
   subset, so `spookNearBeaters` and `stepLines` flush from a bot through the **same** door;
   `boarThreats` suppresses the wave phantoms while any bot beater exists, decided inside the file
   that invented them, off a live fact.
   *Verify:* `src/server/ForestTest/init.luau` and the new `describe` in
   `tests/server/forest_stand.spec.luau` — no `phantom = true` entry with a bot beater present, the
   phantoms back when the source is cleared, a bot HUNTER not silencing them, and an erroring source
   degrading to "no bots" rather than taking the threat list down.

7. **A bot beater ends the drive, which answers Karen's 159a(f).** `Match.beaterCrossing` counts bot
   beaters into **both** numbers it already returns, against the same `Match.crossedLine`.
   `Phase.beatersThrough` is untouched and still only compares two numbers; `match_phase.spec` is
   untouched, and that is the claim.
   *Verify:* `Match.beaterCrossing` in `src/server/Match/init.luau`; `bots_live.spec`'s "puts the bot
   beaters into the drive's own beater count" (+4 with four bot beaters, and a bot *hunter* adds
   none). The arithmetic of what it costs — a Forest Test drive ending at about 0:29 — is
   `docs/design/bots.md` §5.2 and TASKS.md **161a(e)**, flagged for Karen.

8. **`Match` gained no rig, no clock and no requirement on `Bots`.** It holds a read-only **view**
   (`Bots.view()` — no `step`, `start`, rig or setter), injected at each composition root. `syncBots`
   is level-triggered at the phase boundaries and **returns before asking anything at all while the
   flag is off**, which is the strongest form of "off is today's game".
   *Verify:* `syncBots` and the `dispatch` call site; `grep -n "Bots\." src/server/Match/init.luau`
   finds only comments; `bots_fill.spec`'s "not world-overridable, and a world that tries is
   REFUSED" plus `Match.config() == Match.CONFIG`.

9. **The rig source is an injected seam and a yielding build is epoch-guarded.** Default
   `Players:CreateHumanoidModelFromDescription(…, R15)`; `Bots.setRigSource` is the seam
   (`Boar.setModelSource`'s shape). `Bots.fill` never yields; builds are spawned and rationed by
   `BUILD_PER_STEP`; a rig that arrives on a stale epoch destroys itself.
   *Verify:* `src/server/Bots/Rig.luau` and `Bots.step`/`startBuild`; `bots_live.spec`'s
   "fill … never yields" and "destroys a body that arrives after its drive has gone (the epoch)".

10. **The harness knows about the new system.** A `bots` scope in `BLAST_RADIUS`/`SCOPE_SPECS` with
    its three specs, which are also in the `match` tuple (the dual membership `zz_horn` already
    uses). `tools/agents.py` is deliberately **unchanged**: `src/server/Bots/` is not in
    `TWO_PLAYER_PATHS` — a bot is not a player, and the fill count per real-player count is a pure
    function a spec drives at every count. *Verify:* `python tools/studio_mcp.py selftest` and
    `python tools/agents.py selftest`, both green, and the reason in `docs/design/bots.md` §15.

## What I did in the Forest Test, and what it measured

Flag on (`DHFlag_DRIVE_BOTS`, set and **cleared again** — no override is set now), one Play session,
read from the server:

* **at GO:** `4 rigs: bot-beater-1 (3048,-1857) | bot-beater-2 (3012,-1857) | bot-beater-3
  (3066,-1857) | bot-beater-4 (2994,-1857)` — four abreast, ±18 and ±36 about the base, all on the
  measured beater start (roadZ + 240), with three bot hunters on free stands.
* **the symmetry, live:** the player was assigned beater at `Running`, and the fill immediately went
  to **3** bot beaters and **4** bot hunters — one bot handed its slot back to a person, and the
  player stood in **lane 0**, at the base itself (3030, −1857), with the bots either side of her.
* **the walk and the lanes:** they arrived at z = −2116 — `GOAL_PAST_LINE_STUDS` (20) past the road
  at that x — still at x = 3012 / 3048 / 3066. Walkers `WalkSpeed = 9`, not anchored, carrying a
  horn; hunters `WalkSpeed = 0`, anchored, no horn.
* **the horn, through the existing door:** nine blasts, each from a bot's own position, each
  `pushed within 357 studs` and each **`0 credited`**.
* **the console:** no `Stack Begin`, no `attempt to`, no `invalid argument`, no error line.

## What I could NOT verify (rule 8)

1. **THERE IS NO SCREENSHOT SHOWING A BOT, and I am not claiming one.** I took four captures and
   looked at all four; none of them has a bot in it. The reason is mechanical and is a harness fact,
   not a guess: **during Play `screen_capture` returns the player's own first-person view and the
   `camera_position`/`look_at_position` arguments have no effect** (the client owns the camera —
   `Camera` is its one writer). The player is a beater standing in lane 0, so the bots are either
   exactly to her left and right at ±18/±36 studs — just outside a 70° FOV — or 240 studs down the
   drive behind trees. I could not move her camera without becoming a second writer of it.
   **The exact clicks are in `ESCALATE.md`**; it is one Play session and one mouse drag.
   Everything the picture would show is measured in numbers above — the positions, the spacing, the
   anchoring, the walk speed — except the one thing a number cannot answer, which is **(2)**.
2. **The legs do not move: a bot slides.** A rig from `CreateHumanoidModelFromDescription` carries no
   `Animate` script (that comes from `StarterCharacterScripts`, which only a player's character
   gets). This is inference plus the vendor page's silence, not a measurement, and it is exactly the
   class of failure `docs/PROJECT_CONTEXT.md` is about — so it is **declared** in `docs/design/bots.md`
   §11.4 and queued as TASKS.md **161a(c)** rather than quietly shipped. It is the thing the
   screenshot in (1) exists to judge.
3. **`Bots.report()` cannot be read over StudioMCP.** The probe answered all zeros because a
   `require` on the MCP thread returns a **sandboxed copy with empty state** — measured in task 122
   and written in the module's own header. The real line prints to the server console at `Scoring`,
   and the session above never reached it. So the step-cost and walk-seconds numbers the design asks
   for exist and are wired, but **I have not seen one printed**.
4. **Whether a `Humanoid` walks normally with `CanQuery = false` on its own parts** was the
   Architect's open measurement (`docs/design/bots.md` §11.3). It **does** — the bots walked 240
   studs and arrived — so the fallback (`SHOOTABLE = true`) is not needed. That is the one open
   design question this session closed.
5. **`test2` has not been run.** Per the dispatch, the Director runs it.
