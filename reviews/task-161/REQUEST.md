# Task 161 — review request: bots fill the drive

Task: 161
Round: 2
Base: `87dbccb` (main, PR #143 merged)
Code commit: `9d20c376e63704d5296092ca6cdbaee126c9df49`

```
[harness] PASS: 33/33 checks @ 66e7ddf2d16923b845dc7f36c9eef9b923897f7d (clean tree) scope=all
[harness] PASS: 33/33 checks @ 66e7ddf2d16923b845dc7f36c9eef9b923897f7d (clean tree) scope=all
[harness] PASS: 33/33 checks @ 9d20c376e63704d5296092ca6cdbaee126c9df49 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ 9d20c376e63704d5296092ca6cdbaee126c9df49 (clean tree)
```

Logs `<runs-dir>/t161-r2-gate-2.log` and `t161-r2-gate-3.log`, both in the **DEV** Studio alone — the
Forest Test is closed and was not reopened. The two-player run is the Director's, by the dispatch;
this change touches `src/server/Match/`, which is in `TWO_PLAYER_PATHS`. No flag or pose override is
set, so `test2` will start.

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
   **MEASURED LIVE (round 1, in the Forest Test):** the four bot beaters stood at x = 2994, 3012,
   3048, 3066 about a base of 3030 — ±18 and ±36 exactly — and the three that remained arrived at
   the goal still 18 studs apart.

3. **The whole aim decision is `Lane.clearAim`, pure in the world's clearance reader — and a STUCK
   bot side-steps whatever that reader answers.** A bot is stuck precisely when the thing holding it
   is not where the 12-stud whisker is looking: its shoulder, a root, another bot. So "the aim looks
   clear" is the stuck case, not an exemption from it. **The stuck window starts at GO, not when the
   body landed**: `finishBuild` stamps `movedAt` during the countdown, so without that reset a bot
   held at the start line arrives already "stuck" and side-steps for no reason.
   *Verify:* `src/server/Bots/Lane.luau` (`Lane.clearAim`) and `stepWalker`'s first-released-step
   block. `bots_lane.spec`'s "the aim, and the stuck nudge" drives five cases — clear-and-not-stuck,
   **stuck-with-a-reader-that-says-clear** (delete the `forced` branch and it fails), blocked-but-
   moving, nothing-clear-within-`SIDE_TRIES`, and no-reader-at-all. `bots_live.spec`'s "nudges a bot
   that has stopped moving, WITH A READER THAT SAYS THE WAY IS CLEAR" drives the same end-to-end
   through `Bots.step`, **with an injected `roomToStand` returning `true`**, and asserts the stuck
   window does nothing inside `STUCK_SECONDS` and both counters move past it.

4. **A bot is not a player, and the mechanism is that it has no userId — structurally, not by a
   filter.** No score row, no push credit, no safety verdict, no `participants` entry.
   *Verify:* `Bots.threats`/`Bots.beaters` ids are `"bot-hunter-N"`/`"bot-beater-N"`;
   `bots_live.spec` asserts `tonumber(id) == nil` for every one, `#Match.playerDrivers(threats) == 0`
   over the whole list, `Match.creditPush(nil, …) == 0`, and no snapshot row with a non-numeric
   userId. `Match.driverThreats`, `playerDrivers`, `samplePush`, `pushCreditable` and `Penalty` are
   **unchanged** — check the diff.

5. **One dressing path, and `Match.Body`'s ownership sentence is restated rather than broken.**
   `Body.dress` already takes a `Model`; `Bots.Rig` never calls `Body.place`/`hold`/`stand`/`tie`/
   `dressWhenLoaded` and never touches the userId-keyed `held` table.
   *Verify:* the header block in `src/server/Match/Body.luau`; the `dress` seam in `Bots.start{…}`
   in both composition roots; `bots_live.spec`'s "dressed once per body, by Match.Body and nothing
   else" (it also checks the painted `BodyColors` is `Body.BASE_COLOR`).

6. **One blast implementation, and a bot's blast pays nobody.** `Horn.blowTool` is `Horn.blow`'s own
   body factored out and keyed by a string; `Horn.blow` is a two-line wrapper; `lastBlast` is
   re-keyed through `Horn.keyFor`. `Horn.giveTo(rig)` puts a real Tool in a rig's hand.
   *Verify:* `src/server/Weapon/Horn.luau`; the `describe` in `tests/server/zz_horn.spec.luau` (one
   blast per key, the real cooldown refusing the second, a different bot being a different row,
   `blowerUserId == nil`, the blast published from the handle, `giveTo` idempotent). The player's own
   existing cases are unchanged and still pass, which is the "no behaviour change" half.
   **MEASURED LIVE (round 1):** nine bot blasts in the Forest Test, each `0 credited`.

7. **One push source, and the rule is pure: `ForestTest.wavesToPush(waves, bots)`.** While any bot
   beater is pushing, no wave gets a phantom; `boarThreats` has the one call of it.
   `ForestTest.setBotThreats` is the one injected source, and `realBeaters()` gains the driver-kind
   subset so `spookNearBeaters` flushes from a bot through the **same** door.
   *Verify:* `src/server/ForestTest/init.luau`; `forest_stand.spec`'s "DECIDES WHICH WAVES GET A
   PHANTOM" drives **both** states with a hand-written wave list — two waves keep their phantoms with
   no bots **and** with a bot *hunter*, none with a bot beater; delete the rule and the first
   expectation fails. The wiring case beside it says plainly what it does **not** prove (nothing in
   the spec place fills `state.active`, so a phantom count there is not evidence), and its note no
   longer prints `(phantoms=0)` as though it were one.

8. **A bot beater ends the drive, which answers Karen's 159a(f); and the walk's own seconds are
   measured, because that number is what the decision rests on.** `Match.beaterCrossing` counts bot
   beaters into **both** numbers it already returns, against the same `Match.crossedLine`.
   `Phase.beatersThrough` is untouched and still only compares two numbers; `match_phase.spec` is
   untouched, and that is the claim. `walkSeconds` is measured from `walkStartedAt`, stamped on the
   first released step — **not** from `movedAt`, which is the stuck window's own stamp and is re-set
   every `STUCK_SECONDS`.
   *Verify:* `Match.beaterCrossing`; `bots_live.spec`'s "puts the bot beaters into the drive's own
   beater count" (+4, and a bot *hunter* adds none) and "measures the WALK, not the stuck window"
   (thirty seconds of clock, seven stuck windows deep, asserting both the number and `arrived in
   30.0s` in the printed line). The ~29 s arithmetic and what it costs is `docs/design/bots.md` §5.2
   and TASKS.md **161a(e)**, flagged for Karen.

9. **`Match` gained no rig, no clock and no requirement on `Bots`.** It holds a read-only **view**,
   injected at each composition root. `syncBots` is level-triggered at the phase boundaries and
   **returns before asking anything at all while the flag is off**.
   *Verify:* `syncBots` and the `dispatch` call site; `grep -n "Bots\." src/server/Match/init.luau`
   finds only comments; `bots_fill.spec`'s "not world-overridable, and a world that tries is
   REFUSED" plus `Match.config() == Match.CONFIG`. Both roots now print the `[bots]` line only when
   there are bots, so the flag-off game gains no console line either.

10. **The rig: an injected source, an epoch-guarded build, a stander that does no work, and legs
    that move.** Default `Players:CreateHumanoidModelFromDescription(…, R15)`; `Bots.setRigSource` is
    the seam. `Bots.fill` never yields; builds are spawned and rationed; a rig on a stale epoch
    destroys itself. A stander is anchored with `EvaluateStateMachine = false` and **every**
    `HumanoidStateType` disabled. **`Rig.loadClips` gives every bot Roblox's own default R15 walk and
    idle** — `507777826` "R15Walk" and `507766666` "R15IdleLookAround", creator Roblox, AssetTypeId
    24, verified against Roblox's asset API on 2026-10-12; `IsPublicDomain` is **false** on both and
    the header says so, because it is false for every Roblox-owned default and is the reason these
    are not marketplace assets and do not go through our upload pipeline. Without them a bot slides,
    which is the first thing Karen would see (161a(c), now closed). Every load is `pcall`'d and
    counted, so a failure is a number and not a statue.
    *Verify:* `src/server/Bots/Rig.luau`; `bots_live.spec`'s "fill … never yields", "destroys a body
    that arrives after its drive has gone (the epoch)" and "the legs move" — `clipsLoaded +
    clipsFailed == 4` for two bodies with **`clipsFailed == 0`**, an `Animator` on each,
    `playing == "walk"` while walking and `"idle"` in the ring and for a stander. **The gate is what
    proves those ids load on a server-side `Animator`:** `clipsFailed == 0` on both runs.

11. **The harness knows about the new system, and the report tells the truth per drive.** A `bots`
    scope in `BLAST_RADIUS`/`SCOPE_SPECS` with its three specs, also in the `match` tuple.
    `tools/agents.py` is deliberately **unchanged**: `src/server/Bots/` is not in `TWO_PLAYER_PATHS`
    — a bot is not a player, and the fill count per real-player count is a pure function.
    `Bots.clear()` resets the per-drive counters, so `[bots] drive N` no longer prints lifetime
    totals; `desired` counts by `slot.team`, so a world with no drive line stops reporting
    `0/4 hunters, 4/0 beaters`.
    *Verify:* `python tools/studio_mcp.py selftest` and `python tools/agents.py selftest`, both
    green; `bots_live.spec`'s "resets the per-drive counters when the drive's rigs go" (and that the
    lifetime ones stay); `docs/design/bots.md` §15 for the `TWO_PLAYER_PATHS` reason.

## Queued, not fixed (TASKS.md 161a)

The two stale **design** lines (§6.3's view list, §6.6's reader list — the Builder does not write
designs); the §16.3 additions to `match_live`/`match_score`/`match_scene`/`match_config` that were
not made, so the end-to-end early end with a bot line is untested; `restSpot` as a third reader of
`realBeaters`, which shrinks the rest-spot search by a measurement nobody has taken; `Bots.start`
connecting a Heartbeat with the flag off; and `syncBots` running per tick rather than per boundary.

## What I could NOT verify (rule 8)

1. **THERE IS STILL NO SCREENSHOT SHOWING A BOT, and I am not claiming one.** The Forest Test Studio
   is closed and the dispatch says not to reopen it, so round 2 took no new capture. Round 1 took
   four and looked at all four; none has a bot in it, because **during Play `screen_capture` returns
   the player's own first-person view and the camera arguments have no effect** — the client owns the
   camera. The exact clicks are in `ESCALATE.md`. Everything the picture would show is measured in
   numbers; the one thing it alone can answer is (3).
2. **`Bots.report()` cannot be read over StudioMCP** — a `require` on the MCP thread returns a
   sandboxed copy with empty state (measured in task 122). The spec asserts the line's content
   instead (`arrived in 30.0s`), which is the honest substitute.
3. **The clips are proved to LOAD, not to LOOK right.** `clipsFailed == 0` on both gate runs says the
   two ids resolve and `LoadAnimation` succeeds on a server-side `Animator`, and the spec says which
   clip is playing when. Whether a bot then reads as a man walking is Karen's eye — `ESCALATE.md`
   item 2 — and until she has looked, 161a(c) is closed in CODE only.
4. **`test2` has not been run.** Per the dispatch, the Director runs it.
