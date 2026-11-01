# REQUEST -- Task 323a: stand pick, the owner and the wire

Task: 323
Round: 1
Base: `origin/main` (merged into this branch at `81946956`, carrying 313-322)
Code commit: `a0db684d61d3671913659b0b6c6b44215e471cf2`

```
[harness]  PASS: 34/34 checks @ a0db684d61d3671913659b0b6c6b44215e471cf2 (clean tree) scope=all
[harness2] PASS: 36/36 checks @ a0db684d61d3671913659b0b6c6b44215e471cf2 (clean tree)
```

`git diff --name-only a0db684d..HEAD` is **empty**: the code commit IS the head, so the harness
lines cover every line under review. `test2` was run **twice**, both clean, at that same commit.

## What changed

Built to `docs/design/stand-pick.md` section 15's **323a**, with the research note first (rule 1):
`docs/research/2026-11-01-stand-pick.md`, indexed. The server decides which hunter has which stand.
**Born OFF behind `STAND_PICK`**; no pixel is drawn (that is 323b). No design file was edited --
two doc deltas the Architect owns are listed under *Not verified / for the Architect* below.

## Claims, and how to verify each

1. **`StandPick` is the one writer of the claim, and `judge` is pure.** `src/server/Match/StandPick.luau`
   has `judge`, `claim`, `release`, `reset`, `close`, `standOf`, `holderOf`, `wireTable`, `picksFor`
   and `stats`. `judge` takes no service, no `Player` and no clock; `claim` contains no `task.wait`,
   no `pcall` and no provider call, which is what makes "first request wins" a property of the code.
   *Verify:* read the module; grep it for `task.`, `Players`, `pcall`, `os.clock` -- none appear.
   Cases 1, 2, 7, 12, 13 in `tests/server/match_stand_pick.spec.luau`.

2. **The window IS the `Assigning` phase: no new phase, no new clock.** `Phase.pickWindow` is a new
   pure predicate beside `driveOpen`/`lineHeld`/`insideDrive`; `Phase.intermissionSeconds` returns
   `max(INTERMISSION_SECONDS, STAND_PICK_SECONDS)` with `QUICK_TEST` still winning; `settleStands` is
   emitted **first** in `enterRunning`. No `PhaseName` was added and no timestamp was added.
   *Verify:* `Phase.luau`; `grep -n "Picking" src/` is empty; cases 3 and 4.

3. **Flag off is today's placement bit for bit, and it is a measurement.** Case 5 compares
   `dealLine(walk, seated, entitled, count)` against the same call with `picks = nil` and with
   `picks = {}`, element by element, for all four `LAYOUT_ORDER` layouts at every count 1..16 --
   **128 equal-by-value assertions**, and the case asserts the count is 128. Case 17 reads
   PRODUCTION: `Match.CONFIG.STAND_PICK_SECONDS == 0`, `stats().standsSettled == 0`,
   `standSettleStuds == 0`, `pickWindowOpen() == false`.
   *Verify:* case 5 and case 17; the `Flags` row's `default = false`.

4. **Sweep A makes a claim strictly stronger than the fallback.** `HighSeats.dealLine` gained a 5th
   parameter and one sweep before its three unchanged passes. Case 6 is the case one pass gets
   wrong: hunter 3 claims `walk[1]`, hunter 1 claims nothing, and **3 gets it**.
   *Verify:* case 6, plus the all-claim case beside it; sweep B's loop is unchanged line for line.

5. **The entitlement is checked twice, and a bad claim is ignored rather than clamped.** `judge`'s
   `seat` reason is what the player sees; sweep A's `allowSeat` is what a forged `FireServer` meets,
   and it gives him a stand he may stand on -- never nothing, never the seat. A claim of a stand the
   layout does not state takes today's deal. *Verify:* case 11 (both directions) and its sibling.

6. **The one inbound remote carries one number, and nothing is coerced.** `StandRequest` is the third
   remote in `src/shared/Drive/Remotes.model.json`. `Match.onStandRequest` drops a non-number before
   `judge` and counts it (`stats.malformed`); `judge`'s `range` refuses `2.5`, `"4"`, `0`,
   `standCount+1`, `±math.huge` and `0/0`. *Verify:* case 12; the client spec's remote-count case now
   asserts **3 remotes, exactly one inbound** (it asserted 2 and "zero inbound" before this task).

7. **The client derives nothing and has one outbound door.** `src/client/Match` gained
   `standPickTable`, `standPickOpen`, `myStand` (all three read snapshot fields, and all three take
   the snapshot as an optional argument -- the `Phase.pickWindow(state, ...)` discipline) and
   `requestStand`, which fires one number. *Verify:* cases 21 and 22 in
   `tests/client/match_client.spec.luau`.

8. **`Body` stays the one writer of where a character stands.** `Body.carry` is `holdCharacter` ->
   `onGround(attempts = 1)` -> `PivotTo` -> `untieCharacter`: four pieces already in that file. It
   calls no `LoadCharacter` (so his gun survives), refuses a character something else is holding, and
   cannot yield. *Verify:* cases 18, 19, 20; `Body.carried()` / `Body.carriesRefused()`.

9. **A stand freed by a change, a leave or a role switch is free at once.** `claim` clears the old
   stand in the same call; `Match.forget` releases and forces a broadcast past the throttle;
   `applyAssignTeams` -- *the ONE place a team is written* -- releases on `team ~= "Shooters"`.
   *Verify:* case 8; the three call sites in `src/server/Match/init.luau`.

10. **Zero new `TWO_PLAYER_PATHS` entries, and nothing is left on an old arity.** The new spec is
    named `match_stand_pick` so `tests/server/match_*.spec.luau` already covers it; it was added to
    `SCOPE_SPECS["match"]` in `tools/studio_mcp.py`. Every `lockPick` and `dealLine` call site was
    grepped: one production `lockPick` caller (`ForestTestBoot`, now passing `Match.standOf`), four
    spec callers on three arguments (unchanged by the optional 4th), one `dealLine` caller
    (`ForestTestBoot`, now passing `line.picks`). *Verify:* `grep -rn "lockPick\|dealLine" src/ tests/`;
    both `selftest`s pass and ran in these two gate runs.

## Three things I changed beyond the design's list, each with its reason

* **`Flags.MAX_FLAGS` 22 -> 23.** The rot tripwire refused the twenty-third flag -- the cap doing its
  job, MEASURED as `flags.spec:124` in the first harness run at `1d27c22`. Said out loud in the
  comment rather than paid for by quietly retiring somebody else's row, which is the sentence tasks
  266, 298, 305, 305c and 313 each wrote. **The Director may prefer to spend TASKS.md 82b instead:
  this is one line either way.**
* **`botsNeedRebuild`'s `Running` arm is reachable only on a real `false`, not on `nil`.** The design's
  §8 form changed a PURE answer that `bots_live.spec:887` already measured
  (`("Running", 2, 1)`: false -> true). `nil` means *this caller did not measure the pick*, which is
  not *the window is shut*. Production always passes a boolean, so the deferred rebuild still happens.
* **Two new world fields, `world.standCount` and `world.seatedStands`** (`ForestTestBoot`). §5.1's
  `Ask` needs both measured by the owner, and §7.5 requires the count to be the **layout's**, not
  `#markerSet.posts` (a refused post is absent from that list). `Match` learns one number and one
  boolean per stand and nothing about what a seat is.

## What could NOT be verified

* **NOT PROVEN LIVE.** The Director closed Karen's Forest Test for this task, so nothing was taken in
  her place: no `stats.movedStuds` from a real drive, no live `Body.snapMisses()` after a settle, and
  no frame. Said plainly: **nobody has seen this run in her place.**
* **The two-player race is NOT provable live at this commit, and the reason is the flag.** With
  `STAND_PICK` off, `Phase.pickWindow` is false, so every ask is refused `closed` -- there is no race
  to run. The property is case 7 (two `claim` calls, same stand, same `now`: first `true`, second
  `(false, "taken")`), which holds because `claim` yields nowhere. `test2` ran twice, clean, and what
  it proves here is that **nothing in the match, the drive, the tie or the teams moved**.
* **A real tap / `GuiButton.Activated`** is 323b's and the harness cannot synthesise it.
* **`placementLine` and `applyStandSettle` are locals** of `src/server/Match/init.luau`. Case 16
  asserts the **composition they build** -- `dealLine(walk, seated, entitled, count,
  StandPick.picksFor(ids))` -- not the locals themselves. Design case 20 (`standAreaOf` after a
  settle) is **not** asserted: it needs a started `Match`, which `match_live.spec`'s own rule
  forbids; what stands in its place is case 20's snap-miss check on `Body.carry`.

## Not verified / for the Architect (no design file was edited)

* `docs/design/drive.md` §9.1 and line 117 still say this system takes **no** client remote. §4.1 of
  `stand-pick.md` deliberately departs from that, and §14's delta table does not list the amendment.
  The code comments in `src/shared/Drive` and `src/client/Match` name the departure; the design text
  is the Architect's to correct.
* `stand-pick.md` §10.1 does not mention `Flags.MAX_FLAGS`, which the row cannot be added without.
