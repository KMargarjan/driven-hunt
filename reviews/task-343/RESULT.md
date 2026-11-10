PASS

Rule 5, stated so this PASS is not read as rule 5 having been met: this task has NO core item
(no animal behaviour and no shooting path is touched — the diff is `Places/Cells.luau`,
`Places/Slice.luau`, `ForestTestBoot.server.luau`, `tests/server/grid.spec.luau`). What Karen will
see that was NOT seen in her place is the ~2 s during which the cell arrives model by model at each
drive start: `343-F1-after.png` is described as "6 s into drive 2 ... unbroken belt of conifers",
i.e. AFTER the fill, and the request says so itself ("it is not a measurement of the swap"). The
store half runs first, so for roughly the first second of `Assigning` the hunter's cell is being
emptied and the new one has not begun arriving; nobody has looked at that second.

Duty (a), delete the producer, case by case:
- *"swaps a cell in Slice bites, store before stand, and queues without moving"* — dies. With the
  whole-folder write back, `expect(queued.pending).to.equal(n * 2)` reads 0 (the move is already
  done at `begin`), `expect(bites > 2)` reads 1, and `expect(bothHadModels).to.equal(false)` is the
  one that tests ORDER rather than slicing: reversing store/stand leaves C1's 407 models standing
  while C2's arrive, so it flips. `peak` is read from a live `Cells.standing(world)` walk against
  the constants `n + MOVE_MAX_PER_STEP` — two different sources, not one identity.
- *"finishes the swap in one step once the drain deadline has passed"* — dies. Drop `unbudgeted`
  from `Slice.step` and the second `Cells.spend` moves only `MOVE_MAX_PER_STEP` more, so
  `expect(finished).to.equal(true)` and `expect((report).unbudgetedSteps > 0)` both go red.
- Claim 7 (the live edge run) is the only proof of the `ForestTestBoot` wiring, and it can only come
  from that wiring: "swap queued: want=%s %d model(s) to move (drive %d, %s)" and
  "drive-start wait: %.2f s for %d model(s)" exist nowhere else. The quoted lines match the two new
  `string.format`s character for character, and the numbers are mutually consistent — 5767 / 66
  bites = 87 models a bite at `MOVE_BUDGET_MS` 12 (0.138 ms/model against the header's measured
  0.127), 66 bites over 1.87 s implies ~28 ms server frames, which brackets claim 2's 75/37/55 ms
  worst frame; and 1.93 s (wait, from `swapStartedAt` set after `begin` returns) < 1943 ms (`ms`,
  from `begin`'s own `started`) is the right way round. Claim 9's 5767-vs-5671 fix is in the code:
  `if queued.reason ~= "in-flight" and queued.pending > 0`.
- Harness line names `030bfc26` with "(clean tree)" and scope=all; `paperwork-after-code-commit.txt`
  says only `REQUEST.md` followed it. selene 0/0, stylua clean, rojo build exit 0. The probe `.txt`
  files are not in the repo, as on tasks 341/342 — treated as evidence I cannot read, checked for
  producibility and internal consistency as above.
- "Two players: N/A" is true against the diff: none of the four code/test files is in
  `tools/agents.py`'s `TWO_PLAYER_PATHS`.

## Notes (non-blocking)
- `src/server/ForestTestBoot.server.luau`, the Heartbeat — the gate is `if Cells.pending() > 0`, but
  the thing that has to be drained is `flight`, and the two are not the same question. `Cells.begin`
  sets `flight` when `queued > 0`, and `queued = #plan.store + (if plan.stand ~= nil then 1 else 0)`
  counts CELLS; `Cells.pending()` counts MODELS. One cell folder with no children therefore leaves
  `flight` set with `Slice.pending() == 0`, the Heartbeat never calls `Cells.spend`, `flight` is
  never cleared, and every later `begin` answers `"in-flight"` — the forest stops swapping for the
  rest of the session. `Cells.reconcile` does not have the hole (it loops on `flight`, and its
  `ceiling = report.pending + 4` still gives it 4 bites), so the two drains disagree about the
  liveness condition. I cannot name a path that produces an empty cell folder today, which is why
  this is a note; the fix is one line — expose `Cells.inFlight()` (or have `begin` not set `flight`
  when `Slice.pending() == 0`) and gate the Heartbeat on that.
- `src/server/Places/Cells.luau`, `Cells.DRAIN_SECONDS` — the comment says
  "`Match.CONFIG.INTERMISSION_SECONDS` is 5, the drain measures ~1 s, and 3 s leaves 2 s of margin
  before the horn", but `Phase.intermissionSeconds` returns `QUICK_TEST_INTERMISSION_SECONDS` = 3
  when `QUICK_TEST` is on — a dark Studio flag the Director does set for Karen
  (`src/shared/Flags/init.luau`: "`python tools/flags.py set QUICK_TEST on`, play, then"). On that
  branch the deadline arm fires at the horn, not 2 s before it. Harmless at the measured 1.0–1.9 s
  drain; the honest form is to derive the number from `Phase.intermissionSeconds` (or state 3 as the
  shortest intermission and pick 2).
- `src/server/Places/Cells.luau`, `Cells.begin` — claim 4's "Verify: ... no `Parent` write outside a
  `Slice` job" is not literally true: `ensure(storeRoot, Cells.STORE_NAME)` and
  `ensure(root, wood.home)` both run at queue time and `ensure` ends `made.Parent = parent`. Two
  folder creations, no model, no yield — the substantive claim (`movedByBegin = 0`, safe inside
  `dispatch`) stands; the verify line overstates it.
- `tests/server/grid.spec.luau`, the new bite-walk case — it cannot tell `Slice.ORDER`'s new rows
  from `begin`'s own loop order. `begin` queues the store jobs before the stand job, and with
  `store`/`stand` absent from `ORDER` their rank is `math.huge`, so `Slice.begin`'s insertion scan
  (`if ((Slice.ORDER)[other.kind] or math.huge) > rank`) appends and the order is identical. The
  case's own comment says "`Slice.ORDER` is where that is true rather than this loop's order", which
  it does not prove. The instrument is already in the same file: the 327c case builds an `order`
  array in `work` and asserts "the first 600 work calls are all destroys". Queue a case that calls
  `Slice.begin("stand", ...)` BEFORE `Slice.begin("store", ...)` and asserts the work order anyway.
- `src/server/Places/Cells.luau`, the `store`/`stand` jobs — the items are `wood.folder:GetChildren()`
  in instance order; `Slice.order` is not applied. `Slice`'s own header gives the reason it exists
  ("the hunter is put on his stand at `enterAssigning` and the picture fills outward from his feet,
  so what he sees while it grows is the near belt and not a bald cell"), and that reason now applies
  to the swap exactly as it does to a plant, because the fill is ~2 s long and the hunter is already
  placed. `Slice.order` keys on `item.x`/`item.z`, which an Instance does not have, so this is a real
  task (a pivot read), not a line. `cell-loading.md` §12's fallback does not ask for it, so it is not
  a design contradiction — queue it as a look task and let Karen judge the fill.
- `src/server/ForestTestBoot.server.luau`, the boot reconcile — the comment says "the boot's own
  17,458-model reconcile is ~124 frames of ~12 ms instead of one 1.5 s stall". At the header's own
  rate (12 ms of clock ≈ 94 models) 17,458 models is ~186 bites, and at ~22 ms of frame each that is
  ~2.7 s of boot against the 1.5 s it replaces. Inside T5's "+4 s" bound, but boot time is the one
  number this change makes worse and the request does not measure it. Fix the count or measure it.
- `src/server/Places/Slice.luau` — the module's queue and counters now have two owners.
  `Cells.begin` calls `Slice.reset()` (including on the no-op path, which runs ~1 Hz from the
  `markers` closure while `Waiting`), and `Places.dressCell` calls `Slice.reset()` per dress. It is
  safe only because `Places.build` is boot-only (`ForestTestBoot:151`, before `Match.start`) and
  `Places.dressPending` has no runtime caller — `grep` finds it only in `grid.spec`. A later
  deferred dress would have one owner silently drop the other's queue. Worth a `jobs` owner tag or a
  refusal in `Slice.begin` while another owner's queue is live. (T8 still holds: the no-op path
  writes module state only, no Instance.)

---
REVIEWER verdict on commit `b5c5b57fbf4013a0acdca30e9bee20359b4b9702` (round 1) · 2026-11-10 07:26 UTC · session cost $4.44, 41 turns · written by tools/agents.py
