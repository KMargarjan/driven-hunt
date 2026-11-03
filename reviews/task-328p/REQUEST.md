# Task 328p — the capacity bound, derived

Task: 328p
Round: 1
Base: main b49dcbee
Code commit: b7ef3ac61fa0d6c20369730be20ade3bc0777e41

Karen, 2026-11-03 ~11:20 UTC, C1 playtest 2 (`PLAYTEST.md`): *"more trees"*. The bound that said no
was `grid.spec` case 14's `capacity < 3600` / `total < 3600`, derived in `grid-map.md` §8.3 from a
ratio measurement refuted. Built exactly to `docs/design/grid-roads.md` §8.2 and its §13 row.
**No world change, no density change, no geometry.** Research note: `docs/research/2026-11-03-curved-grid-roads.md` §4.

```
[harness] PASS: 34/34 checks @ b7ef3ac61fa0d6c20369730be20ade3bc0777e41 (clean tree) scope=all
```

`test2` **N/A**: no path in `TWO_PLAYER_PATHS` is touched (`src/shared/Places/`,
`tests/server/grid.spec.luau`, `docs/`, `backups/` only).

## Claims

1. **`Places.PARTS_PER_MODEL = 3.03`, measured and cited.** 5,104 parts for 1,687 planted models in
   C1 (task 328m, `reviews/task-328m/RESULT.md`). Verify: `src/shared/Places/init.luau`,
   `Places.PARTS_PER_MODEL` and its comment block. `5104 / 1687 = 3.02549`, to 2 dp **3.03**.
2. **The two budgets are rows, and the unmeasured one says so.** `PART_BUDGET_DRIVE = 22000`
   (`grid-map.md` §8.3's ceiling, unchanged) and `PART_BUDGET_CELL = 8000`, whose comment says
   **DERIVED, NOT MEASURED** and names 328g's client frame as the only thing that may move it.
3. **The caps are COMPUTED, not typed** (L-167). `Places.CELL_PLAN_CAP` /
   `Places.CELL_PART_CAP` are `math.floor(budget / PARTS_PER_MODEL)`.
   `floor(22000/3.03) = floor(7260.07) = 7260`; `floor(8000/3.03) = floor(2640.26) = 2640`.
4. **`grid.spec` case 14 is the three assertions of design §8.2, and prints both slacks.**
   `tests/server/grid.spec.luau`, `describe("the budget")`: `#plantCell <= cellCapacity`,
   `cellCapacity <= CELL_PLAN_CAP`, `#plantCell <= CELL_PART_CAP`, plus a pin on the pair the
   designs publish (7,260 / 2,640) so a ratio or budget change cannot ship undocumented.
5. **MEASURED at the code commit**, case 14's own note from the PASS run above:
   `C1 ... /3416 ... worst C1 1823 of 3416; 3.03 parts/model, caps 7260 plan / 2640 part;`
   `tightest slack 3844 plan, 817 part`. So C1 `cellCapacity` = **3,416**, `#plantCell("C1")` =
   **1,823**, plan slack **3,844** (= 7260 − 3416), part slack **817** (= 2640 − 1823).
6. **ONE DESIGN FIGURE DOES NOT REPRODUCE, and it is not fixed here.** §8.3's table says C1 is
   *"1,687 drawn ... room 953"*. 1,687 is the **planted** count in Karen's place (the ground refuses
   sites); `plantCell` is the **plan**, and at this commit it is **1,823**, so the room case 14
   prints is **817**, not 953. Both are true of different instruments; the spec's bound is on the
   plan, which is the conservative side. Verify: the note in claim 5 against `grid-roads.md` §8.3.
7. **Delete-the-producer, one harness run per assertion** (L-093, L-145). Each is a dirty-tree run at
   the same code commit; the line numbers are case 14's:
   - assertion 1 (`#plantCell <= capacity`): canopy-zone term dropped from `cellCapacity` →
     **`grid.spec:1195` reddens**, capacity 3,416 → 1,541 against C1's draw of 1,823;
   - assertion 2 (`capacity <= CELL_PLAN_CAP`): canopy-zone term ×4 → **`grid.spec:1198` reddens**,
     capacity 9,041 > 7,260;
   - assertion 3 (`#plantCell <= CELL_PART_CAP`): a **real density overrun** — C1's zone spacings
     ×0.7 and `minGapStuds` 12 → 4 → **`grid.spec:1200` reddens ALONE** (capacity 5,247, still
     under the plan cap; draw 3,305 canopy stems past the 2,640 cap). 1, 2 and the pin stayed green.
8. **The gap rule, not the new cap, is what limits "more trees" first** — measured, and it is 328s's
   problem, not this task's. `minGapStuds` 12 → 4 **alone** (capacity untouched at 3,416) moved C1's
   draw only 1,823 → 2,109: still 531 under the cap, and case 14 stayed green. The draw plateaus
   because `minGapStuds` and `Places.mask` refuse sites, which is `CELL_PLANS`' own 328m note.
9. **Rule 7, nothing deleted.** `backups/task-328p/2026-11-03_task-328p_refuted-parts-per-model-ratio.md`
   holds §8.3's two rows, `cellCapacity`'s old header and the whole of old case 14 **verbatim**, with
   the rollback named; `backups/README.md` carries the log row.
10. **`docs/design/grid-map.md` §19** carries the **capacity sentences only** of `grid-roads.md`
    §14's delta — the bend half belongs to 328q. §8.3 itself is not edited, exactly as §18
    supersedes §4.5 and §8.1–8.3 without editing them.

## Not verified

- **The 8,000 per-cell part ceiling is DERIVED, NOT MEASURED** (`grid-terrain.md` §12.2). Nothing here
  measures a client frame; 328g does. The code comment and §19 both say so.
- **No frame, and none is owed:** nothing in the world changes. Rule 5 N/A for that reason.
- `PARTS_PER_MODEL` is the design's 2-dp **3.03**, not the full 3.02549; at full precision the caps
  would be 7,271 and 2,643, so 3.03 is the conservative choice. Stated, not changed.
- The run above reddened `deer_hitbox.spec:659` once (a dispatch-named intermittent) and passed on
  the immediate re-run at the same commit; the PASS line pasted is that re-run. Both runs are at
  b7ef3ac6. The three proof runs in claim 7 also show it, which is why each names its grid.spec line.
