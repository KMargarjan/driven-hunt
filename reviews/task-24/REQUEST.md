# Task 24 — the shotgun on the default camera, after Karen's playtest

Task: 24
Round: 1
Base: `bb674dc`
Code commit: `b764131db9e84cd5a3fee5290e9071ee6d1ec45a`

```
[harness] PASS: 26/26 checks @ b764131db9e84cd5a3fee5290e9071ee6d1ec45a (clean tree)
```

82 server assertions across 8 spec files and 27 client across 3. Only paperwork follows the code
commit (`PLAYTEST.md`, `TASKS.md` row 24, `reviews/task-24/`).

**Round numbering:** this is the task's **third** review. It says `Round: 1` because `tools/agents.py`
restarts the count after a `PASS` (`expected = 1 if prev_verdict == "PASS"`), and rounds 1 and 2 both
passed — the blind spot recorded as `TASKS.md` 21a(h). Nothing is being reset: both earlier verdicts
are in this folder's git history.

## Task

Karen played it on 2026-09-25 (`PLAYTEST.md`) and changed one feel default. Director's dispatch:
**X must switch the ammo type AND reload to it** — break open, the unfired shells of the old type go
back to the reserve, load two of the new type, close; the same uninterruptible 2.0 s window as `R`;
no firing during it; every X press does it; and if there is no reserve of the new type, X does
nothing and the Hud says so. Her other checks passed; hit feel is deferred to after 1.4b and 1.5.

## Claims

1. **X swaps the gun, and the pure reducer owns every part of it.** The owner's `ActionRequest`
   handler applies `SelectAmmo` and then runs the same `runReload` sequence `R` uses
   (`Break → Load → Load → Close`). Uninterruptibility is unchanged and still the reducer's: `Break`
   and `Fire` both require `open == false`.

2. **Unfired shells come back, and that is a property of `Break`, not of X.** `StateMachine.apply`'s
   `Break` branch returns each `Live` barrel's shell to the pocket of its own type; a spent case is
   gone. `weapon_state.spec` asserts both cases (two live slugs → 26, one live and one spent → 25),
   and `R` keeps a live shell for the same reason.

3. **Shells are carried per type**, because "no reserve of the new type" has to be refusable:
   `CONFIG.START_RESERVE = { Slug = 24, Buck = 24 }` and `WeaponState.reserve` is a table keyed by
   `AmmoKind`. 24 of each is my number, not Karen's — one dial for the Director.

4. **An empty pocket does nothing and says so.** The owner refuses the swap before touching state,
   counts it in `stats().emptySwaps`, and publishes a snapshot carrying `notice = "NO BUCK"`; the Hud
   appends it to the readout. `Shotgun.snapshot` carries `notice` only when given one.

5. **The Hud shows the pocket the next load comes from**, not a single pool: `textFor` reads
   `state.reserve[state.ammo]`. Format: `glyphs AMMO <count>[ R][ NOTICE]`.

6. **Running it found a bug a player would have seen.** Nothing published when the reload's final
   window elapsed, so the newest snapshot a client ever held was the one made at `Close`, whose
   `busyFor` is `RELOAD_CLOSE` — the Hud kept its `R` until the next state change, a gun that looks
   stuck reloading. `runReload` now publishes once more after its last wait, guarded by `epoch`.

7. **The harness drove the new behaviour end to end.** The scenario gives X its 2.6 s; the client
   spec asserts a snapshot exists mid-swap (`ammo == "Buck"` while the barrels are not yet loaded with
   it) **and** one where the swap is done, and the end state is `Live/Live`, `loaded Buck/Buck`,
   `selected 1`, `ammo Buck`, `reserve.Slug 24` (two returned), `reserve.Buck 22`.

8. **Three server tests were added and one corrected**: shells returned on `Break`; the whole swap
   sequence pocket by pocket; a type the player has none of (`"no-reserve"`); and the
   fired-then-reloaded case is now 23, not 22, because one live shell came back.

9. **The design is stale on this point and I did not edit it** (rule 3). The six deltas are written
   for the Architect in `reviews/task-24/DESIGN_DELTA.md`, and `TASKS.md` row 24 points at it.

10. **Screenshot (rule 5), inspected:** mid-swap the readout reads `[-]- BUCK 24 R` — action open,
    both barrels empty, the type already BUCK, the buck pocket not yet spent, busy — and after it
    `[*]* BUCK 22`. Pressing X again returns to `[*]* SLUG 24`, so a swap back costs nothing.

## What I could not verify

- **Karen has not played the new X.** This is her change implemented, not her approval of it.
- **The empty-pocket path is proved in the reducer and in the owner's code, not on screen**: the
  scenario cannot drain 24 shells of a type inside a harness run, so no run exercises `"NO BUCK"`
  end to end. `Shotgun.snapshot`'s `notice` and the Hud's rendering of it are asserted; the owner's
  refusal is not.
- **`stats().emptySwaps`** is written but never read by a test, for the same reason.
- **24 of each type** is a number I chose. If she wants 24 total, or 16/8, it is one line.
