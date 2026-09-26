# Review request — Task 38: the queued review notes, triaged

Task: 38
Round: 2
Base: `task-36-test-robustness` @ `0c6c515` (**stacked twice**: Task 36 is stacked on Task 35, and
neither is merged. The Director merges 35, then 36, then this)
Code commit: `310f7b035edd497f21a93c8406a92bc550993f7e`
Branch: `task-38-note-fixes`

```
[harness]  PASS: 27/27 checks @ 310f7b035edd497f21a93c8406a92bc550993f7e (clean tree)
[harness2] PASS: 30/30 checks @ 310f7b035edd497f21a93c8406a92bc550993f7e (clean tree)
```

All three reports green: server 265 passed, shooter 70, driver 64, 0 failed / errors / skipped in
each (265/70/64 against 263/69/62 on the branch this is stacked on — three new `it` blocks).

Every `a`/`b` note row in `TASKS.md` now opens with its classification — **G** wrong or visible for a
player, **T** a test that can pass when it should fail, **D** docs or wording, **L** later — and says
which of its items this task closed.

---

## Claims

1. **35b(a), G — a tied player stopped reading an ammo count for a gun he is not holding.**
   `Weapon.revoke` reset the player's state without publishing it, so the replica kept the snapshot
   from before the gun was taken; the Hud now also draws the readout only for an *equipped* weapon, so
   neither half can leave a stale line on screen. *Verify:* `Weapon.revoke` in
   `src/server/Weapon/init.luau`; the `readout` block in `src/client/Hud/init.luau`;
   `tests/client/zz_tie_to_a_tree.spec.luau` (the tied branch now asserts `not state.equipped` and an
   empty readout — it runs in `test2`, where a tie really happens).

2. **24a(a), G — a reload aborted after `Break` left the gun open for ever.** Every later `Reload`
   and every `Fire` was then refused `"is-open"`, so the player carried a brick until they respawned.
   `runReload` closes it before giving up. *Verify:* the abort branch of `runReload` in
   `src/server/Weapon/init.luau`. No reachable path produces the abort today, which is why this is a
   guard and not a bug fix with a repro.

3. **24a(c), G — the client's Tool watcher grew by one dead Tool per respawn.** (The spec that can
   detect it is the shooter's, `it("listens to ONE Tool, however many the session has destroyed")`;
   the driver's `it` beside it is a driver-half assertion and would read 0 with the fix deleted.) The drive respawns a
   player on every placement, which destroys the Tool; the watcher kept the key and both connections
   for ever, cleared only by `Input.stop()`, which nothing calls. Each Tool's connections now live
   with it and go when it does. *Verify:* `watched` / `forgetTool` / `watchTool` in
   `src/client/Weapon/Input.luau`; `Input.watchedTools()` and the two specs in
   `tests/client/weapon_client.spec.luau` ("listens to ONE Tool…", "is listening to no Tool at all…").

4. **32a(c), G — the drive-start broadcast carried the previous drive's score rows, and round 1's
   answer to it did not work.** Entering `Assigning` emits a `broadcast` effect, `broadcast` builds
   the snapshot from `board`, and the new drive's board was built after `applyEffects` had already
   sent it — so every client showed the last drive's points until the next event or the 5-second
   heartbeat. My first fix cleared the snapshot CACHE after the push had gone out, which changed
   nothing anybody could see; the reviewer was right, and the order is the fix: the board is rebuilt
   **before** `applyEffects` runs. *Verify:* `dispatch` in `src/server/Match/init.luau` — the
   `Assigning` block now sits above the `applyEffects(effects)` line.

5. **35b(b) and 35b(c), G/T — the violation's halves agree now.** `Score.violation` returns
   `(board, awards)` and only the board was taken, so `Match.Scored` carried kills and escapes but
   never the −50; and when the map gave no tree to tie the offender to, the points and the feed line
   landed while `Punished` did not fire at all. Both fixed in `applyFreeze`. *Verify:* `applyFreeze`
   in `src/server/Match/init.luau`.

6. **26a(a), G/D — `Rig.acquire`'s reason reads correctly for the case that matters.** The owner
   printed "no stock PlayerModule to disable" for both outcomes, including the one where a
   `PlayerModule` **is** there and will not turn off — which is the one that means a second writer of
   the camera. The reason now says which it is and the owner prints it verbatim. *Verify:*
   `Rig.acquire` in `src/client/Camera/Rig.luau`; `Camera.start` in `src/client/Camera/init.luau`.

7. **6a(d), T — the harness refuses a scenario whose first mouse action is a button.** StudioMCP
   refuses a click with no established position, and the position is carried only inside one scenario;
   that is exactly the fault that cost Task 35 a run, discovered during Play. It is a property of the
   file, so it is refused in `load_scenarios`, before Play, with the rest. `6a(c)` moved the
   `readyAttribute` identifier check to the same place, and `6a(f)` gives `parse_vector` a usage line
   instead of a `ValueError` raised after Studio is already up. *Verify:* `load_scenarios`,
   `replay_input` and `parse_vector` in `tools/studio_mcp.py`.

8. **21a(a) and 21a(b), T — two holes in the loop's own gate.** `architect --task 5` with the mode
   omitted raised an uncaught `IndexError` instead of the usage refusal, and `review --task 21 22`
   dropped the stray silently. And `harness_gate` decided "docs-only" from `Base...head`, where
   `Base:` comes from the request — so a `Base:` set to the code commit made a `tools/` change look
   docs-only and skipped the gate. It now unions that range with `code_commit~1..head`, which the
   request cannot choose. *Verify:* `main` and `harness_gate` in `tools/agents.py`; both refusals
   print correctly from the command line.

9. **Three tests that could pass when they should fail.** `input_driving`'s "leaves nothing bound
   behind" performed its own teardown and then asserted it had worked (6a(a)); `weapon_client`'s
   `sawSwapInProgress` scanned the whole session, where a later scenario satisfies half of it by
   itself (30a(d)); and `boar_body` sampled `UpVector.Y` only until half sprint speed was reached,
   where the design says "throughout a 3 s flee" (36a(3)(c)). *Verify:* the three specs.

10. **28a(g), T — the zone tally and the damage now agree.** An unknown zone name opened its own
    bucket in `Runtime:stats().zoneHits` while `Wound.apply` charged its damage to `body`. One
    function, `Wound.chargedZone`, answers it for both, with a pure spec. Also `28a(f)`: the bolt
    hint's inline `10` is `WOUND.BOLT_HINT_STUDS`. *Verify:* `Wound.chargedZone` in
    `src/server/Boar/Wound.luau`; the tally in `src/server/Boar/init.luau`;
    `tests/server/boar_wound.spec.luau`, describe "the zone a hit is charged to".

---

## Also fixed, smaller

`36a(3)(d)` one source for the role in the tie spec; `36a(3)(a)` and `36a(3)(e)` two stale sentences
about the 25-second and 20-second budgets; `30a(c)` two camera headers that said "the only writer in
the repo", which the detector spec deliberately makes false (it is the only writer in `src/`);
`24a(d)` and `28a(e)` two wrong statements in `GAME_DESIGN.md`'s owners table (Workspace's three
run-time folders, and four RemoteEvents where there are five). `6a(g)` was closed as obsolete: both
things it says are never sent are sent by the committed scenarios now.

## Round 1's non-blocking notes, addressed

`runReload`'s recovery waits out a `"busy"` window (an immediate `Close` is refused for the same
reason the step was) and `break`s rather than `return`s, so the trailing publish still clears the
Hud's `R`; `Wound.apply`'s `charge` routes through `Wound.chargedZone`, so "one function, one answer"
is literally true; the zone tally skips a zero count like `charge` does; `forgetTool` unbinds, because
a Tool destroyed while equipped takes its own `Unequipped` handler with it; the arena row no longer
says Workspace holds the arena in Edit mode (it holds `Camera` and `Terrain`); the harness docstring
carries both new refusals; and two comments that claimed more than their assertions are corrected.
Left: `docs/architecture/audit-003.md` quotes the removed warning text — Architect-owned, queued in
row 38a — and the two untested items below.

## What could not be verified, and what is not fixed

- **Claim 4 has no test.** `Match` is a started singleton and a drive boundary is 600 seconds away,
  so nothing in the suite can watch `Match.snapshot().rows` across one. It is the same wall as
  32a(b), (d) and (e), and it is now named in row 32a rather than counted as closed.
- **Claim 5 (35b(b), 35b(c)) has no test either**, for the same reason: neither `Match.Scored`
  carrying the −50 nor `Punished` firing on the no-anchor path is asserted anywhere. Row 35b says so.
- **24a(a) has no test and no repro.** Nothing reachable aborts a reload after `Break` today — the
  note says so too — so this is a guard against a path that does not exist yet. A test would need a
  seam that interrupts `runReload` mid-sequence.
- **The hit-marker start-order race (36a(1), and 28a(b) is the same item) is not fixed, and it is not
  small.** The server sends its test markers once, wherever its own suite has got to; the fix is a
  send the client can ask for, or a server that keeps sending until every client has seen one. Either
  is a new inbound path or a new loop in production code for a test's benefit — a task with a design
  decision in it. It stays in 36a, classified T, with the arrival claim for a non-shooter unasserted.
- **Everything Architect-owned stays queued** (rule 3: the Builder never edits `docs/design/`), and so
  does everything that needs a new seam on a started singleton (32a(b), (d), (e); 34a(2)).
- **Two of Karen's feel calls are queued, not decided:** a tracer on a clean miss (24a(f)) and the
  sticky `NO BUCK` notice (24a(j)).
- **No screenshot.** The one visible change is a readout that is now absent when there is no gun, and
  it is asserted in the two-player run (`Hud.readoutText() == ""` on a tied player). The screenshot
  that shows the old behaviour is `.screenshots/task35-tied-to-a-tree.png`; taking the "after" needs a
  two-player Play session, and `screen_capture` is refused whenever more than one Studio is connected
  (`tools/studio_mcp.py`, and `TASKS.md` row 35). Rule 5: stated rather than skipped.
