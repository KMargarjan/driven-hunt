# Task 323b -- the stand pick on the map, with a mouse

Task: 323b
Round: 1
Base: 9be8bf0d (main, carrying 323a as #305)
Code commit: cf3beb0ce527bb54f2aceef8e940badeed632138

```
[harness]  PASS: 34/34 checks @ cf3beb0ce527bb54f2aceef8e940badeed632138 (clean tree) scope=all
[harness2] PASS: 36/36 checks @ cf3beb0ce527bb54f2aceef8e940badeed632138 (clean tree)
```

**What changed.** The two 323b-notes the round-2 Reviewer named as this task's first dependency,
then design `docs/design/stand-pick.md` section 15's 323b: the map, with a mouse. The flag stays
**OFF**.

## Claims

1. **The settle's false header sentence is gone (note (a)).** `applyStandSettle`'s header said
   *"ONLY CLAIMANTS ARE MOVED"*, which round 1's own fix had made untrue. Read the header in
   `src/server/Match/init.luau`; the surviving clause (zero `Body` calls with no claim) is stated as
   the consequence of the two deals being equal rather than of a claimant test.
2. **The settle PLAN is pure, exported and is the only rule the carry has (note (b)).**
   `Match.standSettlePlan(place, markerSet, config, provisional, settled, count)` returns the line
   indices whose settled `place(...)` differs from the provisional one; `applyStandSettle` iterates
   exactly that list and holds no second rule. Cases in `tests/server/match_stand_pick.spec.luau`,
   `describe("the settle PLAN, ...")`: it names **both** men on the `road` swap (a 2-element list,
   `{1,2}`), **nobody** with an empty claim table (4 layouts x counts 1..8, 0 named), and nobody when
   the world answers `nil`. `stats.standSettlePlanned` is the same count off production and is 0.
   **The plan is a pure unit and the one-line carry over it is argued by READING, not run** (V293b):
   no spec can stage a drive, so a revert of that single loop would not fail a case.
3. **The five rows the note found had no case now have one.** Same `describe`: the three
   claim-dropping sites -- a team switch (`StandPick.release`, the call `applyAssignTeams` makes; the
   SITE is a local and is argued by reading, said on the line), a leave (`Match.forget`, the real
   exported path) and the `Assigning` edge (`StandPick.reset`) -- plus `placementLine`'s `picks` line
   and the two snapshot fields, read off `Match.snapshot()` through the two production paths that
   invalidate its cache (`Match.onStandRequest`, `Match.forget`).
4. **`MapUi.standStateFor` is pure and answers all five states.** `map_ui.spec` case 23: mine (from
   either field), taken (with the name), free, a free high seat, and one he may not use. `entitled`
   nil is "nobody answered, which is YES" -- `Shop.grantsHighSeat`'s own rule.
5. **`MapUi.pickable` is one predicate for the grab and the release.** Case 25 sweeps all 32
   combinations and also asserts it is never true where `fullMapVisible` is false.
6. **Every stand carries exactly one 72 px `Hit` pad and no two pads overlap.** Case 28, on the REAL
   panel in the REAL client, over all four forest layouts, read off the engine's own
   `AbsolutePosition`/`AbsoluteSize`: 0 overlapping pairs out of every pair, not just neighbours.
7. **`setStandStates` writes the four properties of all nine and is edge-triggered.** Case 24 reads
   the colour, transparency, stroke and name off the drawn nodes; the same version twice and the same
   states under a NEW version both write nothing (`stats.standWrites` unmoved); a real change writes.
   "Mine" hides the square and its index and becomes the existing `Target` diamond, so the full map
   still carries exactly one orange mark.
8. **A tap asks one collaborator and a dead map asks nothing.** Case 27: `tapStand(4)` calls
   `requestStand(4)` once; with the window shut, as a beater, with the scope in, with the map closed,
   and with no collaborator at all, it calls nothing. `MapUi` fires no remote (amendment A-323-1).
9. **`map-pick` is released on all six exits.** Case 26 drives each exit and reads BOTH owners' own
   reference counts for the TAG -- not `Cursor.isFree()`, because `ReportPanel` correctly holds the
   cursor free under its own tag while the report is up (measured in the first gate run).
10. **The auto-open, the footer and the start card, measured in a live DEV Play with `STAND_PICK`
    forced on by a DEV-only override (cleared before every gate run).** `.screenshots/t323-pick.png`:
    the map opened itself in `ASSIGNING` with `0:10 LEFT`, the footer read `click a stand` -- **and
    the task-158 start card was drawn on top of it, covering the panel.** That frame is why
    `Hud.startCardVisible` gained a third argument (`reportOpen`'s own precedent) and
    `Hud.pickingStand` is the one rule both callers use; `match_client.spec` asserts both, flag-off
    included. `.screenshots/t323-pick-after.png` is the same moment at the code commit with the card
    gone and the panel clear.

## What could not be verified

* **THE PICTURE OF THE FIVE STATES, AND THE REAL MOUSE CLICK: NOT PROVEN. Nobody has seen them.**
  DEV states **zero** stands -- `MapUi.geometryFromMap` returns `stands = {}`, and the client's
  forest-geometry door is inside `if Map.EXPECTED_WORLD == "forest-test"`. Measured live, not only
  read: `canvas: 0 Stand nodes, 0 Hit pads, 1 road segments`. There is nothing on DEV's map to
  photograph and nothing for a mouse to hit, and the MCP thread cannot `require`, so no probe can
  hand `MapUi` the forest geometry from outside. The Forest Test was closed for this task by the
  Director. `ESCALATE.md` carries the request, written at the hard stop before any workaround.
* **The `seat` (barred) state is reachable by parameter and not from a drive.** `seated` comes from
  `HighSeats.standsFor` (one record, two readers) but no client-side ownership read exists, so
  `entitled` is nil -- which is YES. A free seat draws its brass ring; a barred one needs a wire
  question that is not a map question. Queued in `TASKS.md`.
* **With the flag on, the start card is down for the whole of `Assigning`**, so a hunter does not see
  what-to-shoot while he picks. That is the cost of claim 10's fix and it is a feel call: queued, not
  decided here. The countdown is still on the drive bar and the instruction in the footer.
* **The objective pick row is the line for a hunter whose map is CLOSED during the window.**
  `Objective.lineVisible`'s existing `mapOpen` rule stands the line down while the panel is up, which
  is why `t323-pick-after.png` shows no top line. Case 31 measures the row by `TextFits` at 400 px.
* `deer_hitbox.spec:659` (the dispatch's KNOWN INTERMITTENT) fired in **one of three** runs at this
  same commit; the other two passed, and the run before it at `af679528` passed. No other failure.
