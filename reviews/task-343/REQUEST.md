# Task 343 — the cell swap in Slice bites

Task: 343
Round: 1
Base: 6f1156e9 (main, PR #355)
Code commit: 030bfc267f852056650c683a926bd30fa276cbdf

`[harness] PASS: 34/34 checks @ 030bfc267f852056650c683a926bd30fa276cbdf (clean tree) scope=all`

Two players: N/A — no `TWO_PLAYER_PATHS` path is touched. The files are
`src/server/Places/Cells.luau`, `src/server/Places/Slice.luau`,
`src/server/ForestTestBoot.server.luau` and `tests/server/grid.spec.luau`. The drive-start wait is in
`ForestTestBoot`, NOT in `src/server/Match/`, exactly as the dispatch required when no human click
is available.

## What changed

`cell-loading.md` section 12's own named fallback for T7: the store/stand moves go through `Slice`
per model, in time-budgeted bites, store before stand, with `Places.Cells` still the one writer.

- `Slice.ORDER` gains `store = 1, stand = 2`. A move is one `Parent` write and costs a fifth of a
  plant, so it has its own measured budget (`MOVE_BUDGET_MS = 12`, `MOVE_MAX_PER_STEP = 200`) and its
  own counter (`moved`). `Slice.step(now, unbudgeted)` finishes a job in one call when asked.
- `Cells.begin` plans and queues and **moves nothing**; `Cells.spend` is one bite; `Cells.reconcile`
  is begin-then-drain and keeps its old signature plus a `breathe`.
- `ForestTestBoot`'s `markers` closure calls `begin` (it runs inside `Match`'s `dispatch`, which may
  not yield); the file's one Heartbeat spends the bites, and past `Cells.DRAIN_SECONDS` (3 s, against
  `INTERMISSION_SECONDS` = 5) finishes the rest in one step. The wait is printed.

## Claims

1. **The whole-folder move was 738 ms of SERVER FRAME, not the 400 ms its own clock said.**
   Measured on main 6f1156e9 in Karen's Forest Test: `343-before-swap-{B2,D2,C1}.txt` —
   `report.ms` 400 / 438 / 400 against `worstFrameMs` **691 / 749 / 738**. Verify: those files'
   `report.ms` and `worstFrameMs`, same probe both sides.
2. **After: the worst single server frame across a swap is 75 / 37 / 55 ms**, against the dispatch's
   100 ms ceiling. `343-cycle2-swap-{B2,D2,C1}.txt`, same probe, same place, driving one bite per
   frame as the Heartbeat does. Verify: `worstFrameMs` in those three files.
3. **The swap really goes in bites and the budget holds.** 52 / 58 / 58 bites of 87–102 models,
   each 12.1 ms (`biteRows` in the same files), `unbudgetedSteps = 0`. Verify: `report.bites`,
   `report.biteRows`.
4. **`begin` moves nothing** — `movedByBegin = 0` with `pendingAfterBegin = 5767` in all three
   (`343-cycle2-swap-*.txt`). This is what lets the `markers` closure call it from inside `dispatch`.
   Verify: those two fields, and `Cells.begin`'s body (no `Parent` write outside a `Slice` job).
5. **Store before stand: the peak in `Workspace` is one cell's models plus one bite, never two
   cells'.** `peakCellModelsInWorkspace` 3039 / 3054 / 3141 (one cell is 2,626–3,141) and
   `twoCellsHadModelsAtOnce = false`, sampled at EVERY bite. Verify: those two fields.
6. **A per-cell census on both sides shows no cell but the pair was touched (L-182).**
   `343-cycle2-swap-*.txt` `before.standing` / `after.stored`: the six stored cells keep their exact
   model counts (A2 3054, B1 2947, B2 2626, C2 3005, D1 3132, D2 2694), and only the store/stand pair
   changes side. Verify: those maps.
7. **At a REAL drive boundary in her place, the drive-start wait is 1.93 s and the cell is whole
   before the horn.** `343-edge-console.txt`, at the code commit:
   `[Places.Cells] swap queued: want=B2 5767 model(s) to move (drive 2, Assigning)` →
   `... moved=2 cell(s)/5767 model(s) in 1943 ms over 66 bite(s) / 1.87 s (unbudgeted=0)` →
   `[Places.Cells] drive-start wait: 1.93 s for 5767 model(s) (drive 2, Assigning)`, and the next
   line is drive 2's own `[ForestTest] the wood is stocked`. 1.93 s is under the 5 s the dispatch
   set as the ESCALATE line, and under the 5 s intermission.
8. **Three cases die if the fix is deleted (L-093).** `tests/server/grid.spec.luau`:
   *"swaps a cell in Slice bites, store before stand, and queues without moving"* asserts
   `queued.pending == n*2` with `queued.models == 0`, that no bite ever has two cells with models in
   the world, and `bites > 2` — a single `Parent` write fails all three. *"finishes the swap in one
   step once the drain deadline has passed"* asserts a budgeted bite leaves work pending and the
   `unbudgeted` call does not, plus `in-flight` refusal. Verify: delete the slicing and run them.
9. **The log line's two halves agree (V298).** The first live edge run printed `5767` on the swap
   line and `5671` on the wait line, because an in-flight (refused) `begin` was printed as a fresh
   queue and overwrote the start. Fixed in `030bfc26`; the run above reads 5767 on both.
10. **Total swap time grew, as the dispatch allowed: 400/438/400 ms → 1012/1408/1562 ms** of wall
    clock, spread over 52–58 frames instead of one. Client frame p95 across the swap window
    23.5–29.4 ms → 28.0–36.2 ms, and client worst frame **689/821/742 ms → 103/126/104 ms**.
    Verify: `343-before-client-*.txt` and `343-cycle2-client-*.txt`.

## What I could not verify

- **The 100 ms ceiling at the live drive boundary itself.** Claim 2's 75/37/55 ms comes from the swap
  probe, which is a second driver of the same two functions in the same place; the live edge run
  (claim 7) prints the wait and the bite count but no per-frame dt. The bite sizes and budget are the
  same on both paths.
- **The deadline arm firing live.** `unbudgetedSteps = 0` on every live run, because the drain
  always finished in 1.0–1.9 s against the 3 s deadline. The arm is proved only by the spec.
- **Frame `343-F1-after.png`**, opened: a hunter's view from B2 stand 8, HUD reading
  `DRIVE 2 · 4:54 TIME · 0 ANIMALS · BEATER` — a 300 s drive (`ForestTest.DRIVE.seconds`), so 6 s
  into drive 2 — with an unbroken belt of conifers to the horizon, no gap and no half-removed tree.
  It shows the cell fully stood in the drive's first seconds; it is not a measurement of the swap.
