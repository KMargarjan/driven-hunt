# Task 345e (T5): retire the repeat window, restate the budget

Task: 345e
Round: 2
Base: 1fe6d2ea (main, #366 merged)
Code commit: 713711b859a344a7e90c6731f339566138ff6a22

```
[harness] PASS: 34/34 checks @ 713711b859a344a7e90c6731f339566138ff6a22 (clean tree) scope=all
```

`test2` is **N/A**: nothing here is in `TWO_PLAYER_PATHS` (`src/server/ForestTest/`,
`src/shared/ForestTest/`, two server specs), and `docs/design/animal-placement.md` 17 says so for
all six of T1..T6. No spec FAILED in the run above, so no flake is claimed.

**Round 1's blocking finding is accepted and fixed** (claim 5). The live measurements of claims 3,
4 and 8 were taken at `982e52c9`; round 2 changed two specs, four comments and one exported type,
and nothing that could move them -- `git diff 982e52c9..713711b8 -- src/` is comments plus the
three new `Placement.RosterRow` field declarations.

## What changed

`docs/design/animal-placement.md` 17's **T5**. `ESCALATE.md` 2026-11-11 item 5 measured slots 16+
still spawning with `PLACEMENT_IN_PLACE` on; `releaseLine`'s roster branch only fires for a slot
that HAS a roster row, and slots past 15 have none.

* `Data.slotAt` gains `inPlace`. **ON, a slot past `#rows` is SILENT** (design 5.3). **OFF is
  Karen's drive today**, by the Director's decision of 2026-11-12 (*"Flag OFF stays today's drive
  byte for byte"*), so `repeatFrom`/`repeatTo`, `Data.repeatRoomFor` and the clamp family are KEPT
  and go with the OFF path at T6. `ForestTest.waveAt` hands the switch through.
* `ForestTest.budget()` publishes design 5.2's rows; every ENFORCED row is asked of its own owner.
* `laneSpawns` / `laneSlots` / `laneWorstSlot`: the instrument for design 5.2's **0**.
* `wokeWalk` / `wokeHorn` / `wokeSlot` beside `wokeBand` -- `ESCALATE.md` item 4's count, **count
  only**. Both took a per-row latch after being measured as tick counts.
* Archived under rule 7 in
  `backups/2026-11-12_task-345e_repeat-window-and-dead-window-arithmetic.md`: `LINE.twoLineChance`
  and D-3's `ForestTest.drive`, `driveIndexAt`, `wavesPerDrive`, `deerWaveOf`, `deerWanted`.

## Claims

1. **With the switch ON, a slot past the end of the script is silent; the OFF path still repeats.**
   `Data.slotAt` in `src/shared/ForestTest/init.luau`; `forest_line.spec.luau`, "is SILENT past the
   end of the script with PLACEMENT_IN_PLACE on, and repeats with it off". **FAIL-FIRST (L-093):**
   delete the `if inPlace == true then return nil end` branch and the thirty in-loop
   `expect(...).to.equal(nil)` rows fail, and `expect(onRows).to.equal(0)` with them -- `onRows` is
   now incremented when the ON arm answers a row (round 1's note). The case also covers all three
   densities and asserts the fifteen scripted slots are the SAME ROW BY IDENTITY in both states.
   The run's note line reads
   `task 345 T5: slots 16..45 answer a row 30/30 times OFF and 0/30 ON; 13 scripted rows identical`.
2. **The live path cannot keep the window.** `ForestTest.waveAt(slot, inPlace)` in
   `src/server/ForestTest/init.luau`; its two callers pass the value the owner resolved.
   `forest_line.spec.luau`, "hands the switch through ForestTest.waveAt". The ON arm
   (`to.equal(nil)`) is the half that bites; the OFF arm is a same-arguments identity and is noted
   as such rather than claimed (round 1's note).
3. **MEASURED, flag ON, Karen's Forest Test, one drive and one window per row.** BEFORE is the
   merge base `1fe6d2ea`, AFTER is `982e52c9`; both served to her Studio from `driven-hunt-rev` on
   :34873. Files: `<runs-dir>/345e2-BEF-{C1,D1,A2}-{track,console}.txt`,
   `345e4-AFT-{C1,D1,A2}-{track,console}.txt`.

   | cell | when | peak live | step avg | step peak | hb p95 | parts | **lane spawns** | groups bedded |
   |---|---|---|---|---|---|---|---|---|
   | C1 normal | BEFORE | 24 | 4.07 | 80.83 | 38.19 | 438 | **75 in 10 slots, worst 25** | 4 |
   | C1 normal | AFTER  | 24 | 3.41 | 73.29 | 38.02 | 438 | **0** | 4 |
   | D1 quiet  | BEFORE | 24 | 4.21 | 82.88 | 31.09 | 428 | **27 in 4 slots, worst 26** | 3 |
   | D1 quiet  | AFTER  | 24 | 2.39 | 62.86 | 35.98 | 428 | **0** | 4 |
   | A2 busy   | BEFORE | 24 | 2.96 | 77.93 | 27.93 | 418 | **43 in 9 slots, worst 27** | 2 |
   | A2 busy   | AFTER  |  7 | 1.41 | 93.55 | 31.93 | 129 | **0** | 2 |

   Verify: `grep -cE "SLOT 1[6-9] act|SLOT [2-9][0-9] act" <tag>-console.txt` is 10 / 4 / 9 on the
   three BEFORE consoles and **0** on all three AFTER consoles; `grep -oE "drive 1 woke:.*"` on each
   AFTER console ends `LANE SPAWNS 0 in 0 slot(s), worst slot 0 (target 0)`.
   **Against design 5.2:** live <= 24 MET, step avg <= 7.0 MET, parts < 2,000 MET, lane spawns 0
   MET. **Step peak <= 20 NOT MET (73-94 ms) and heartbeat p95 <= 32 NOT MET in C1 and D1** -- both
   miss on BOTH sides and are escalated with the readings (`ESCALATE.md` 2026-11-12, items 3, 4).
4. **Flag OFF is today's drive.** `345e2-BEF-OFF-C1-console.txt` (merge base) against
   `345e4-AFT-OFF-C1-console.txt` (`982e52c9`): every slot present in both -- the scripted
   1,2,3,4,6,7,8,9,11,12,13,14,15 **and the repeat slots 18..25** -- is identical in act, route,
   size, kinds and files. The only difference is that the merge base's drive reached slot 17 and
   this one did not: its 340 s window opened one slot later. The repeat window demonstrably still
   runs with the flag off -- peak live 60 and 55, parts 1,020 and 935, against 24 and 438 ON.
5. **Round 1's finding: the lane counter now has a case that sees it FIRE, and the case bites.**
   `tests/server/forest_placement.spec.luau`, helper `laneSpawnOnce()` plus
   "counts a lane spawn when a slot the roster does not own reaches the spawn half". The helper
   plans a drive, `table.remove`s one roster row -- the hole `Placement.plan` leaves for a deer the
   cap refused -- hands `computeRouteVia` a route (no navmesh here, the T4 file case's patch point),
   and `Forest.step(..., true)` releases that slot, so `releaseLine` reaches its spawn half. The
   case asserts `laneSpawns > 0`, `laneSlots == 1`, `laneWorstSlot == slot`, and that the runtime
   made exactly `laneSpawns` handles.
   **L-093 DELETE-AND-FAIL RUN, at this commit:** with the
   `if onNow and staged == nil then state.laneSpawns = ... end` block removed,
   `[tests:server] FAIL: 2953 passed, 2 failed, 2 errors` --
   `forest_placement.spec:1695` and `forest_placement.spec:1551 function laneSpawnOnce ... :1763`.
   The block was restored by `git checkout` and the tree is clean at this commit.
6. **The reset case now drives the owner and asserts by VALUE.**
   `forest_placement.spec.luau`, "zeroes all six new counters in planDrive, and the reset is what
   answers". Five of the six are dirtied through real paths first -- the lane three from
   `laneSpawnOnce()`, `wokeHorn` from a bedded group the runtime calls FLYING with no latch of ours,
   `wokeSlot` from a walker lying past its clock -- each asserted `> 0`, then `planDrive` runs and
   each is asserted `== 0` by value. **`wokeWalk` is not dirtied and the comment says why**: only
   `spookNearBeaters` writes `state.latched`, and that needs a live beater, so its reset is the one
   of the six this case does not cover.
   The same case also pins the two latches: nine further `stepPlacement` calls move neither
   `wokeHorn` nor `wokeSlot`, and both stay at or below `#Forest.roster()`.
7. **The two wake counters were wrong, are fixed, and the fix is also what proved the live sync.**
   `345e2-AFT-C1-track.txt` read `wokeSlot=7866` and `345e3-AFT-D1-console.txt` `wokeHorn=6677`
   over single drives -- tick counts, because the wake block's guard is `bedded OR awake` and
   neither arm leaves that state. `row.slotDue` and `row.wokeAs` are the latches. At `982e52c9` the
   same cells read `band 0, horn 7, walk-up 0, slot clock 2` (C1) and `horn 4, slot clock 0` (D1);
   `slot clock 2` is exactly `walkersPerDrive`.
   **`wokeBand` is NOT mutually exclusive with the other three** and the comment now says so
   (round 1's note): it is T4's and still counts the line's reach whether or not a fright had the
   group on the same tick. "First claim wins" is true of `row.wokeAs` only.
8. **The budget is asserted against its own owners.** `ForestTest.budget()` and
   `forest_placement.spec.luau`, `describe("the budget")`: the rows against `Data.LIVE_CAP`,
   `Placement.CONFIG.bedCap`, `Data.MAX_BOARS` and `SPOOK.BEATER_STUDS`; the dormant roster at 0
   instances and 0 parts, now asserted at design 5.2's own **83** animals at `busy` and not only
   "inside 120" (round 1's note). **It asserts `animal-placement.md` 5.2 and NOT `grid-map.md` 9.2**,
   which still prints the old 4.0 / 8.0 rows -- `ESCALATE.md` item 1.
9. **The archives are rule 7, each with a pasted grep.**
   `backups/2026-11-12_task-345e_repeat-window-and-dead-window-arithmetic.md`. `twoLineChance` and
   D-3's five functions had no production reader; `wavesPerDrive` / `deerWaveOf` / `deerWanted` had
   `forest_line.spec` readers only and those four cases go with them. Verify:
   `grep -rn "deerWaveOf\|deerWanted\|wavesPerDrive\|driveIndexAt\|twoLineChance" src/ tests/`
   returns comments only. The clamp family and `repeatRoomFor` are KEPT, with the reason written
   where they live, because the OFF path reads them.
10. **One hunter-view frame, A2, mid-drive, flag ON, opened and described.**
    `.screenshots/345e5-AFT-A2-F2.png`, with `345e5-AFT-A2-F1.png` beside it. From the hunter's OWN
    camera, not a parked one: L-150 and `ESCALATE.md` 2026-11-11 item 1 measured four camera parks
    failing because the character is the streaming anchor and a camera is not. **What is in it:**
    the shotgun barrel with the hunter's gloved hands and green sleeve across the bottom; the yellow
    safety arc painted on the grass in front of his stand; an open grass lane running left to right;
    a birch-and-spruce tree line beyond it; the HUD reading `stay on stand, animals coming`,
    `DRIVE 1`, `TIME 2:50`, `0 ANIMALS`, `HUNTER`, `$13500`, the compass bar and the minimap.
    **No animal anywhere in the lane or at the tree line.** That is this task's claim -- nothing is
    created in front of her -- and **not** a claim that a bedded animal is visible: design K-3 puts
    no bed in the near 150 studs. F1 (`TIME 3:32`) is the same view with the toast
    `an animal got away x2`.

## Not verified

* **Rule 5: of this task's core items only claim 10 has been SEEN** in Karen's place -- one
  hunter-view frame of an A2 lane with no animal in it, which is the absence T5 claims. Claims 3, 4
  and 7 are MEASURED off the console and the `DHForestPlacement` attribute, not seen. Nobody has
  watched a flag-ON drive's groups be found by the line; that is T6.
* **Design 5.2's step peak (20 ms) and heartbeat p95 (32 ms) are NOT MET** -- 73-94 ms and
  38.0 / 36.0 / 31.9 ms. Both miss on BOTH sides and nothing in T5 touches either. `ESCALATE.md`
  items 3 and 4. One run per row, as the dispatch specified, so the p95 deltas cannot be separated
  from noise.
* **The six-way bed tally (`swept/band/ground/lane/zone/unseen`) could not be read** -- it prints
  only on the per-group SKIPPED console line, and those roll out of the 6,000-character buffer in a
  340 s drive. `ESCALATE.md` item 6.
* **"C1 beds 0 animals from stand 11" did not reproduce** at `982e52c9`: 13 placed, 4 groups with
  bodies, `budget 4 nobed 5` (`345e-S11-console.txt`, stand 11 locked, aim ON as Karen has it).
  `ESCALATE.md` item 7.
* **Bedded groups go without any wake being counted** (`band 0` in all three cells), the same shape
  on both sides. That is `src/server/Boar/`'s and is `ESCALATE.md` item 5.
* **`wokeWalk`'s reset has no case** (claim 6), and round 1's note about two further ON-path doors
  into the spawn half -- `state.owedRow` resurrecting a deer row past `#rows`, and a scheduled slot
  `Placement.plan` dropped -- has a case for the second only, through `laneSpawnOnce()`. Neither
  fires in her Forest Test today, which is consistent with the measured `laneSpawns` 0; the first
  is queued, not covered.
