# Task 145 - the boar_body.spec scatter flake was not a flake

Task: 145
Round: 1
Base: main (`83daf04`, task 144 merged as PR #127)
Code commit: `6f2f84eab272d6eb4b6fe3e2e329e6a1b5bc83c1`

```
[harness] PASS: 33/33 checks @ 6f2f84eab272d6eb4b6fe3e2e329e6a1b5bc83c1 (clean tree) scope=all
[harness] PASS: 33/33 checks @ 6f2f84eab272d6eb4b6fe3e2e329e6a1b5bc83c1 (clean tree) scope=all
```

Two full runs back to back, both green, on the same commit. `test2` is N/A: the diff is
`tests/server/boar_body.spec.luau` alone, not in `TWO_PLAYER_PATHS`.

**No Architect run and no `src/` change:** the system is not wrong. The assertion was.

## The ten claims

1. **THE OLD LINE WAS NOT INTERMITTENT. IT WAS FALSE, AND IT PASSED BY LUCK.** It read
   `expect(spread(live(group)) > before).to.equal(true)` — 120 frames after the leader is shot, the
   survivors must be further apart than the group was before the shot. TASKS row 130a has it red on
   identical code in tasks 130, 139, 140 and 141, two of four gate runs at 141's commit.

2. **MEASURED ALONE, 30 RUNS A PASS.** `driven-hunt-runs/t145-scatter.luau` rebuilds this exact
   world — same field, same plate, same `Random.new(5)`, same `spawnSounder(CENTER, 5, 14)` — and
   repeats only the scatter scenario, including the state the case inherits from the two before it
   (a driver behind the sounder and ~3 s of running as a group). **As written it failed 26 of 30.**

3. **THE FIRST CAUSE IS A SET MISMATCH, AND IT IS WORTH ~5 STUDS.** `before` is `spread` over FIVE
   boars; the shot kills the leader, so `after` is over the four survivors. **The dead leader was one
   of the two widest-apart members in 30 of 30 runs**, so the width drops by about five studs before
   anything has moved. `beforeAll` ran 22.1–23.1 and `beforeSurvivors` 16.5–18.2 across the same 30.

4. **FIXING THAT IS NOT ENOUGH: THE SAME FOUR BOARS STILL FAILED 12 OF 30.** Comparing the survivor
   set with itself, the width after 120 frames was smaller than before in 12 runs, by up to 2.53
   studs.

5. **AND IT IS NOT THE WINDOW EITHER.** `SCATTER_SECONDS` is 6, so 120 frames is a third of the
   behaviour. Sampled at 120 / 240 / 360 frames, **the mean gap between survivors ended SMALLER than
   it started in 14 of 27 runs, by as much as 4.70 studs**. Nearest-neighbour gap: down in 9 of 30.
   Widest gap: down in 8 of 30. Heading spread: down in 2 of 30. **No positional metric is an
   invariant at any window.**

6. **THE REASON IS IN THE STEERING, AND IT IS BY DESIGN.** `Brain._herdSteer`: while scattering the
   cohesion term, the alignment term and the file are all dropped and `SEPARATION` is multiplied by
   `SCATTER_SEPARATION` (3.0) — **but every member still carries its own `FLEE_WEIGHT` 0.8 pull
   toward the same `field.exitZ`**. Five animals running at one line converge on it. "The sounder
   scattered" has never meant "the bodies are further apart N frames later".

7. **SO NO BOUND ON THAT NUMBER WOULD BE HONEST** — it would only be a bound that happened to hold
   on this machine, which is what the dispatch said not to do. The line is gone, and the measurement
   above is written into the spec beside where it stood so the next reader does not re-add it.

8. **WHAT THE CASE ASSERTS NOW IS WHAT SCATTERING IS, with no clock to lose.** The shot latches
   `SETTINGS.SCATTER_SECONDS` exactly — `expect(latched).to.equal(SETTINGS.SCATTER_SECONDS)` — and
   two frames later the timer is **strictly smaller and still positive**. `_step` does
   `scatterFor = math.max(0, scatterFor - dt)`, so that holds at any frame rate, which is the one way
   to tell a running clock from a latched flag without betting on wall time. The promotion, the
   `scatters` stat and the carcass leaving the sounder were already asserted and are unchanged.
   **Verify:** `latched` in "promotes a new leader and scatters when the leader is shot dead".

9. **THE NEW ASSERTIONS, RUN ALONE 30 TIMES: 0 FAILURES** (`driven-hunt-runs/t145-latch.luau`,
   checking all four — latch equals the dial, timer down, timer positive, leader promoted, four
   members). A sample of the latch: `6.0000` against a dial of `6.0`, five times out of five, with
   `5.9539`–`5.9656` two frames later.

10. **THE WIDTH IS STILL MEASURED, JUST NOT A GATE.** `TestKit.note` reports it every run, so the
    number stays visible in the log. The second gate run printed
    `boar sounder: scatter width 16.6 -> 32.1 studs over 120 frames (reported, not asserted: task
    145)` — which is itself the point: the same scenario that measured −2.5 studs in a probe
    measured +15.5 here.

## Standing rule A, Forest Test, 85 s, with RIFLE ON

* the Tool is in the CHARACTER at 15 s and at 85 s (`gun in hand @15s=1 @85s=1`)
* **0 "Stack Begin" and 0 error lines** in the whole console
* **five waves released**, worst 1 boar sound at once over 10 s with 29 boars alive

Rule 5 screenshot: **N/A** — nothing drawn changed. The diff is one spec file.

## What I could not verify, and what I did not do

* **I did not run the FULL SUITE 30 times**, which is the only way to measure the flake exactly as
  the gate meets it. 30 runs of the scenario alone is what fits the time box; the full gate ran
  twice, green. The probe's world is rebuilt from the spec's own constants rather than shared with
  it, so a difference between the two is possible in principle — the 26-of-30 failure rate it
  measures is in the same direction as the gate's own history (red in four tasks), not a contradiction
  of it.
* **I did not fix the sounder.** Nothing here says the scatter behaviour is wrong; the data says the
  spec's claim about it was. If the Director wants "a scattered sounder ends up looser" to BE true,
  that is a change to `Brain` — a fleeing member would have to stop aiming at the same exit line —
  and it is a game decision, not a test one.
* **`t145-scatter.luau`'s last pass reported 27 of 30 rounds** before I read it; the three missing
  rows are the tail of a run I stopped early, not failures that were hidden. The counts in claim 5
  are over the 27 that completed.
* **The probe uses `Random.new(5)` like the spec**, so the runtime's own RNG was never the variable:
  what varies is the physics step and how many draws the sounder has consumed by the time of the
  shot. I did not isolate those two from each other, because the conclusion — no positional bound is
  honest — does not depend on which of them dominates.
