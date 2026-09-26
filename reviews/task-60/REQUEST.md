# Task 60 — the sounder exists: a group of boars that moves as one

Task: 60
Round: 1
Base: `29d2ba3` (`main`)
Code commit: `3e741f20466c5feba08bef8d5775932611c69fa8` — the `[harness]` line below names it, it is the
last commit that changed `src/`, `tests/` or `tools/`, and only this request and `TASKS.md` change
after it.

Harness, clean tree, one player:

    [harness] PASS: 30/30 checks @ 3e741f20466c5feba08bef8d5775932611c69fa8 (clean tree)

Harness, clean tree, two players — run by the DIRECTOR, not by me:

    [harness2] PASS: n/n checks @ 3e741f20466c5feba08bef8d5775932611c69fa8 (clean tree)

350 server specs (327 before: **23 new**) and 84 client specs. No flag override was set during the
run (`python tools/flags.py clear` before it, and the harness's own check confirms it).

## Scope

The design's **57a half only** (Director decision J): the boar runtime learns what a sounder IS and
the Brain learns to follow one. **The drive releasing sounders is the next task**, so nothing in
production creates one: `Match` is untouched, and with `BOAR_SOUNDERS` OFF *or* ON the game behaves
exactly as it did. Research first (rule 1): `docs/research/2026-09-25-drive.md`, Addendum 2.

## Claims

1. **One owner, and the Brain holds no reference to another boar.** `_sounders` lives in the
   Runtime, which already owns every other fact about a boar; the Brain receives `obs.sounder` —
   plain values, nil for a lone boar — and `Body`/`Wound` are untouched. Verify: `Runtime:_sounderObs`,
   `Brain:_sounderDirection`; the design's ownership table.

2. **The flag-OFF world is provably today's world.** `spawnSounder(c, 1)` is exactly `spawn(c)` and
   creates **no** record, so `obs.sounder` is nil and every existing path runs unchanged — and a
   **leader**'s intents are identical to a lone boar's, step for step, over 600 steps with a
   neighbour and a centroid in its observation. Verify: `boar_brain.spec`, *"a LEADER decides exactly
   what a lone boar decides"*.

3. **All or nothing.** `spawnSounder` creates the whole sounder or nothing (`size < 1`, or over
   `maxBoars`), so a half sounder cannot exist and the drive's budget can never disagree with the
   world. The ring is clamped inside the pad the map guarantees, because `spawn` overwrites the
   caller's Y. Verify: `Runtime:spawnSounder`; live spec items 1–3.

4. **One route per sounder.** A follower never asks for a path (the one documented exception is a
   member the stuck detector has reported twice). The live block counts requests **per agent** in
   its own world rather than trusting a total: only the leader's id ever appears. Verify:
   `boar_sounder.spec` *"never asks for a route"*; `boar_body.spec`, the live block.

5. **A follower steers, it does not teleport into place.** Reynolds leader-following plus the boids
   terms are blended into the SAME setpoint `slew(TURN_RATE·dt)` and `ACCEL` already limit, so every
   existing turn-rate and acceleration assertion still holds. Measured in Edit: 30 studs off its slot
   closes to 4.98 by second 3 and holds 4.75–5.16 out to second 9, with no heading reversal at all.

6. **Separation dominates, and the research note corrects the design about why.** `drive.md` §16 H
   says the boids page insists collision avoidance wins; **it does not** — it states no hierarchy at
   all. `SEPARATION = 1.6` is this build's decision, for this build's reason (five `CanCollide` bodies
   at `MAX_FORCE = 6000`). Measured: two members 3 studs apart are 23.4 apart 1.5 s later, with the
   worst step-to-step turn exactly `TURN_RATE·dt`.

7. **The herd panics and calms as one animal**, the column latches for a tight gap, a hit scatters
   the whole sounder, the member nearest the exit is promoted, and a member leaves in exactly the
   four ways the design names — the fourth dissolving the sounder, because one animal is not a group.
   Verify: `boar_sounder.spec` (14 cases) and the live block (8).

8. **A DEFECT THIS TASK FOUND AND FIXED, and it is not about sounders.** `ComputeAsync` from the
   centre of an unanchored, collidable, boar-sized body returns **NoPath** — measured here, one body
   or five — so **every boar path request in this game has been failing since Milestone 1.2**, hidden
   by the Brain's straight-line fallback. Six studs ahead of the same body the same route returns 95
   waypoints. `PATH_START_AHEAD = 6` fixes it at the one place that asks. **This changes what a lone
   boar does**: it now follows navmesh routes, which is what `boar-ai.md` has claimed since Task 18.

9. **One forced repath per `REPATH_INTERVAL`.** `Path.Blocked` fires again every time a herd-mate
   shifts on the route ahead; a blockage found inside the window buys nothing, because the Brain's
   own repath is at most half a second away. This is the design's *"≤ 2 per second while fleeing"*.

10. **The flag is declared and dark.** `BOAR_SOUNDERS`, `default = false`, expires 2026-10-17.
    **Nothing reads it yet** — its reader is `Match.CONFIG.SOUNDER.ENABLED` in the release task — so
    turning it on today changes nothing a player can see, and the row says so in a comment.

## What the screenshots show (rule 5 — I looked at them)

Taken in a real Play session, flag ON, with `Runtime:spawnSounder` called directly (the design's own
"a spec calls it regardless of the flag"), then `flags clear` before the harness.

- **`sounder-group-1`** — five boars abreast, sweeping past the shooter's post in a loose wedge, all
  travelling the same way. That is the thing this task exists to make possible.
- **`sounder-scatter-1`** — a second after the leader was shot: the carcass flashing red, and the
  survivors already tens of studs apart on diverging lines. It reads as a group breaking up.
- **`sounder-scatter-2`** — honestly: one boar at the edge of frame. The survivors sprinted out of
  the camera's view, which is what a scatter does and also why a still picture of it is thin.

## What I could not verify

- **The camera cannot be borrowed.** The client's camera is owned by the game's own module, which
  rewrites its CFrame every frame (measured), so the shots are from the shooter's own view rather
  than a chosen angle. `tools/studio_mcp.py capture`'s camera arguments do nothing during Play.
- **Nothing in production releases a sounder**, so nothing here is evidence about the drive.
- **`SCATTER_ON_HIT` does not make the others run.** A hit scatters the formation, but a member that
  is IDLE and has no threat of its own stays IDLE unless the LEADER is fleeing: the design's panic
  rule is leader-driven. Seen in the first screenshot attempt; queued as 60a, because changing it is
  a feel decision.
- **The design's follower-speed floor of `TROT_SPEED/2` is not implemented** — it cannot coexist with
  the design's own "never exceeds `leader.speed × CATCHUP`" when the leader is standing still.
- **The live block's field is 600 studs, not the design's 120**, because five boars sprinting for
  three seconds crossed a 120-stud plate's exit line and dissolved the sounder the block is about.
