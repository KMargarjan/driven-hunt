# Task 309a -- name the last stud: the per-shot instrument, then the fix

Task: 309a
Round: 1
Base: 190b145d (main)
Code commit: 63866ba5c4ece14bb4e9717995cf2705e9cc09a4

```
[harness] PASS: 34/34 checks @ 63866ba5c4ece14bb4e9717995cf2705e9cc09a4 (clean tree) scope=all
```

Two players: **N/A**. No changed path is in `TWO_PLAYER_PATHS` (`tools/agents.py`) -- the change is
`src/server/HitLog/`, `src/server/Weapon/`, `src/shared/Shotgun/`, two server specs,
`tools/aim_bench.py` and one research note. Weapon work takes the one-player line.

## PLAN (core quality protocol step 0)

- **(a) REAL LIFE.** A rifleman who puts the bead on a crossing boar's shoulder hits the shoulder.
  The only lead real life charges him is the bullet's flight time; it charges him nothing for his
  own screen being behind the animal.
- **(b) MEASURED NOW** (190b145d, Karen's place, N=30, `<runs-dir>/309/after-B.txt`): STAND chest
  27/30, control 28/30 with `along` -1.25, and `ServerStorage.DHLastHits` read **`nil`** for all
  120 shots -- so no shot in that table had a local offset at all.
- **(c) TARGET.** The dispatch's five rates, and -- the instrument's own target -- a struck point
  whose local offset lies inside a boar 5.5 studs long, and a server-tested position within a stud
  of the drawn one.
- **(d) LEVER.** `HitLog.sendCard` (the ring), `Weapon.castWithRewind` (the published tenses),
  `Flight.advance`'s impact row (the tense that was dropped), `Shotgun.CONFIG.FLIGHT_REWIND_BASE_SECONDS`
  (the amount). Each is the one writer of its quantity; greps in the commit messages.
- **(e) MEASURED AFTER** by the same bench, same place, same cells.

## What changed

1. **`HitLog.sendCard` writes the ring** -- `Shape.traceLine` off `frameOf`, exactly as `recordHit`
   does -- and still writes no row, no dot, no kill and no money.
2. **`Weapon.castWithRewind` publishes `DH305Past` and `DH305Pres`** beside `DH305At`, Studio only.
3. **`tools/aim_bench.py`** prints per shot `drawn / past / pres / pastat / pastgap` and the ring's
   `zone / local / uv / id`, and per cell mean `pastgap`, mean `ring-z` and `ring N/N`.
4. **`Flight.advance` carries `frame`** -- the defect.
5. **`FLIGHT_REWIND_BASE_SECONDS` 0.205 -> 0.250** -- the residual.

## Claims

1. **The contradiction is a REPORTING defect, and it is named.** At 190b145d the ring was empty, so
   nobody could see it. With the instruments (36e5274b) it read `local=(-1.63,-0.08,5.62)` and
   `local=(-2.55,0.54,6.21)` on a boar 5.5 long and 2.0 wide -- a body length past its own rump,
   `uv` pinned at u=1.000. *Verify:* `<runs-dir>/309a/diag1.txt`, the `[aim_bench] last server hit
   trace` block and the `ring-z` column (+5.88 run chest, +6.16 control).
2. **The cause is `Flight.advance` rebuilding the impact row without `frame`.** `Weapon.Rewind.impact`
   sets it, `Hits.group` carries it (task 308), `HitLog.frameOf` falls back to `part.CFrame` without
   it. *Verify:* the field list in `Flight.advance`; and the arithmetic on diag1 control shot 12 --
   `|impact - pres|` = 5.85 against a ring z of 5.62, `|impact - past|` = 1.21.
3. **The fix is proven by the same instrument.** 7576fcd9, N=30: `ring-z` +1.17 (run chest), +0.71
   (control), +0.23 (stand) -- every struck point inside the body. *Verify:* `<runs-dir>/309a/after-A.txt`.
4. **The zone word was right all along.** In the final table each cell's mean `ring-z` falls in the
   zone its own histogram names, against `Boar.CONFIG.ZONES`: chest -1.29..+0.23, body loin
   +0.67..+1.11, rear hips from +1.11. *Verify:* `<runs-dir>/309a/after-B.txt`.
5. **The last stud is the rewind amount, measured end to end.** `pastgap` (`DH305Past` minus the
   drawn trunk, along travel) read +1.00 / +1.19 / +0.90 on three run cells at 0.205 and **+0.23 /
   +0.13 / +0.00** at 0.250, with +0.01 standing in both. *Verify:* after-A.txt against after-B.txt.
6. **Three cycles, same instrument each time.** diag1 (N=12, instruments) -> after-A (N=30, tense
   carried) -> cycle3 (N=20, 0.250 in the test build) -> after-B (N=30, shipped). Rates: run chest
   42% -> 50% -> 100% -> 83%; `pastgap` +1.47 -> +1.00 -> +0.10 -> +0.23.
7. **Nothing was widened into air.** The KNOWN-BAD cell -- a click one drawn body length ahead of
   the nose -- read 2/30 at 190b145d, 1/30 at 0.205 and **0/30** at the code commit.
8. **Both instruments have a known-bad case in the suite** (L-141). `tests/server/hit_card.spec.luau`:
   a card the range REFUSES leaves `traced` 0 and the ring empty. `tests/server/weapon_rewind.spec.luau`:
   `advance` driven with a cast that names a frame and one that does not. `tools/aim_bench.py selftest`:
   `parse_trace` on four non-ring inputs must come back empty. *Verify:* deleting the early return in
   `parse_trace` makes `selftest` raise.
9. **Two of five targets are NOT met and are not claimed.** RUN nose 24/30 = 80% (target 85%,
   CI 63-90) and CONTROL 28/30 = 93% (target 95%, one shot short). MET: STAND chest 29/30 = 97%,
   RUN chest 25/30 = 83%, known-bad 0/30.
10. **The bench ran at 92917b17, one commit before the code commit.** 63866ba5 changes only
    `tests/server/hit_card.spec.luau` (an assertion the harness caught), so no `src/` line differs
    between the measured build and the reviewed one.

## What I could not verify

- **CI on the pushed branch.** `gh` is not authenticated in this session; the branch is pushed and
  the Director sees the run.
- **Whether 0.250 or something in 0.217..0.250 is right.** The bench reads the drawn trunk up to one
  frame after the trigger (0.4 studs at a run), so 0.250 is the over-rewound end of the bracket. The
  row states the bound. It needs Karen's eye, not another number.
- **Karen's own Forest Test place** (`driven-hunt-karen`, port 34873) was not touched. The test build
  `driven-hunt-294` on 34874 was used throughout and the panel is being returned to 34873.
- **`AIM_REWIND.default` is still `false`** -- unchanged by this task, open since 305.

ANSWERED: L-136 the one FAIL was MINE (`hit_card.spec:619`, my own new case asserting `points[1]`
instead of the report's `position`); it was fixed, not called a flake, and the re-run is 34/34.
ANSWERED: L-127 every dispatch item is MET / NOT MET per item in claim 9 and in the handover block.
ANSWERED: L-123 control and known-bad are printed as numbers in every table in `<runs-dir>/309a/`.
ANSWERED: Verdict-298 the proof is the bench's moving-target table in her place (after-B.txt).
ANSWERED: ROUTE/b309-result.json the place's live flags are printed at the head of every bench run;
`DHFlag_AIM_REWIND=true` in her Forest Test, so the fix is visible to her playtest.
ANSWERED: L-141 both instruments read differently by state -- ring 12/12 on a scoring cell against
1/30 on clear air, `pastgap` +0.01 standing against +1.19 at a run.
ANSWERED: L-143 every row and every cell prints `pastgap`, `ring-z` and `ring N/N`, control included.
ANSWERED: L-121/L-028 the verdict is geometric: the struck point's local offset against the drawn
mesh's own extents, not the zone word; the known-bad click produces no ring line.
ANSWERED: L-124 the ring is populated -- 29/30, 25/30, 24/30, 28/30 -- so no proof was worked around.
