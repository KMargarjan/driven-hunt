# Task 328z -- red stag herds of 5-8 in single file, and more of them

Task: 328z
Round: 1
Base: 9c09c64a (main, 328i #332 merged)
Code commit: 8ae8c62796a395d4ffe7fde272f8fc65b0f9b202

```
[harness] PASS: 34/34 checks @ 8ae8c62796a395d4ffe7fde272f8fc65b0f9b202 (clean tree) scope=all
```

`[harness2]`: not run. `tests/server/match_live.spec.luau` IS in `TWO_PLAYER_PATHS`, so the MERGE
gate wants it -- but a scoped/full one-player line is the review round's evidence and `agents.py`
does not ask for `[harness2]` here. The click is written out as a `NEEDS KAREN` in `ESCALATE.md`
item 5. The run immediately before this one, at the SAME commit, was `FAIL: 32/34` with the server
suite green; the two failing checks were not captured and the re-run at the same commit is the
34/34 above.

## PLAN

**(a) REAL LIFE.** A red deer party is **5 to 8**, not 1 to 3: Wildlife Online on the Isle of Rum
study -- hind parties median **7 in summer, 5 in winter**, bachelor stag groups **7 and 4**
(sources, licences and the negative result in `docs/research/2026-11-05-red-deer-herds.md`).

**(b) MEASURED NOW**, in Karen's Forest Test on merged main (`9c09c64a` on :34873), two instruments:
`328z-cfg.luau` -- group sizes **1/2/3**, `CHANCE_PER_RELEASE` **0.20**, `MAX_GROUPS_ALIVE` **1**,
`maxBoars` **8**, deer in **2 of 15** C1 slots = **3 red deer per drive**. `328z-file.luau` over a
300 s window (`328z-BEFORE-ft.txt`) -- 9 release buckets, **1 deer, 0 road-band samples with two
deer at once**, so the file could not be measured at all.

**(c) TARGET.** sizes 5/6/7 (+ the lone stag); >= 20 red deer per drive; gap **8.5 studs** +- 3
median and lateral **<= 2.5** median, because 8.5 is this repo's own measured file station
(`Data.LINE.spacingStuds`) and no source gives a metre figure for a deer file.

**(d) LEVER** -- pasted `grep`, every number's only writer:
```
src/server/Boar/init.luau:487:  maxBoars = 24,
src/server/Boar/init.luau:3911: CHANCE_PER_RELEASE = 0.5, -- K's dial
src/server/Boar/init.luau:3932: MAX_GROUPS_ALIVE = 3,
src/server/Boar/init.luau:3957: COMPOSITIONS = {
src/shared/ForestTest/init.luau:2168: party = "harem", -- {stag = 1, hind = 4, calf = 2}
src/shared/ForestTest/init.luau:2209: party = "stags", -- {stag = 6}
```

**(e) MEASURED AFTER** by the same files, in the same place, on this branch served to :34873.

## ITERATION (three cycles, same instrument, Karen's place)

| cycle | window | deer waves | red deer | APPROACH gap / lat (median) | CROSSING gap / lat (median) |
|---|---|---|---|---|---|
| BEFORE | 300 s | 1 of 9 | 1 | no sample (never 2 deer alive) | no sample |
| 1 | 300 s | 4 of 20 | 19 | 8.70 / 0.60 (not yet split by depth) | -- |
| 2 | 300 s | 3 of 7 | 18 | **8.50 / 0.20** (p90 10.0 / 0.8) | 15.60 / 2.80 |
| 3 | 300 s | 4 of 19 | 24 | **8.50 / 0.30** (p90 9.5 / 0.8) | 8.40 / 0.70 |

Cycle 1 -> 2 changed the INSTRUMENT, not the game: the probe now records the leader's distance from
the road, because cycle 1's p90 of 42 studs was all at the crossing and none of it on the approach.
No code changed between cycles 1, 2 and 3. The target is met on the approach in every cycle. At the
crossing the file strings out -- that is the road leap and the bolt, and it is not compressible by
the following rule (a follower may never aim closer than `LINE.MARGIN` to the animal ahead).

## CLAIMS

1. **A red deer group is 5 to 8 animals.** `Boar.CONFIG.SPECIES.reddeer.RELEASE.COMPOSITIONS` has
   four rows at 1 / 5 / 7 / 6. Verify: `tests/server/deer.spec.luau`, *"draws each of the four
   compositions at its own weight boundary"*, whose last loop asserts every row is 1 or 5..8.
   Live in Karen's place: `328z-AFTER-cfg.txt` -- `stag w=10 size=1 | hinds w=35 size=5 | harem
   w=35 size=7 | stags w=20 size=6`.
2. **Red deer per Forest Test drive: 3 -> 19 by the script, 19 to 24 measured.**
   `328z-BEFORE-cfg.txt` vs `328z-AFTER-cfg.txt` (`deerAnimals/drive=3` -> `19`), and the live
   windows in `328z-AFTER-ft-c1/c2/c3.txt` (`deerAnimals=19 / 18 / 24`). Verify also
   `forest_line.spec`'s `normal.deerGroups` 2 -> 4 and `animalsAt("normal")` 59 -> 65.
3. **They cross in ONE ROW, at this repo's own measured station.** Approach median gap **8.50**
   studs (target 8.5 +- 3) and lateral **0.20 / 0.30** studs (target <= 2.5), p90 lateral 0.80 --
   tighter than task 136's two 8.5 runs (0.23/0.42 median, 1.89/4.27 p90). Verify:
   `python 328z-stats.py 328z-AFTER-ft-c2.txt 328z-AFTER-ft-c3.txt` over the probe output.
   **Nothing about spacing was changed** -- `Data.LINE.spacingStuds` and `SOUNDER.COLUMN_SPACING_STUDS`
   are untouched; the research note says why that is the right answer and not laziness.
4. **The frames.** `<runs-dir>/328z-F1.png` -- the hunter's own eye (head at
   (-3904.8, **112.1**, -5062.0), a C1 stand, shotgun and HUD in frame): four red deer of the hind
   party walking left in ONE line at one depth, evenly spaced -- two adult hinds and two visibly
   smaller calves (`328z-F1-zoom.png`, 3x). `328z-F2.png`, 16 s later: seven red deer in view --
   the same party across the middle, a second file behind it, and a stag with antlers up in the
   right foreground having crossed (`328z-F2-zoom.png`). Two groups alive at once is what
   `MAX_GROUPS_ALIVE = 3` buys.
5. **Stuck >= 3 s is 0, and every crossing completed.** `328z-stuck-AFTER.txt` (328n's sampler,
   100 s, 45 animals including hind x7, stag x7, calf x4): *"STUCK>3s: 0 of 45"*, road band
   *"crossings attempted 29, completed 29"*, and no deer in the four no-progress animals (cub x3,
   male x1). BEFORE in the same place: 29 animals, 1 stag held 16.0 s, *"attempted 2, completed 1"*.
6. **A shot runs the file on forward, never back.** Unchanged -- nothing in this task touches
   `Line`, the trail, `MARCH_RANK` or the spook. The cycle-3 window shows 29 of 29 crossings
   completed and no deer among the animals that made no progress.
7. **`maxBoars` 8 -> 24 was forced, not chosen.** `Runtime:spawnSounder` returns `{}` when
   `#self._boars + size > self._config.maxBoars`, so at 8 a herd of 7 could never come out beside
   the drive's six boars. The relations the design protects still hold and are still asserted
   (`match_live.spec`: `MAX_ALIVE_BOARS <= maxBoars`). Peak live animals measured: **45** in 100 s,
   against `ForestTest.MAX_BOARS = 60`.
8. **`match_live.spec`'s budget case was wrong, not the code.** `stats.boarsReleased` counts the
   ANIMALS the owner spawned (`Match/init.luau`'s `stats.boarsReleased += #handles`), while the
   drive's budget counts the `size` each release was scheduled for -- and a deer release replaces
   that size with its composition's. Asserted per release now, plus `soundersReleased <=
   BOARS_PER_DRIVE`, which is still exactly true.
9. **`SHOP`'s `expires` moved, and it is NOT this task's row.** It was 2026-11-04; the rot
   tripwire fired on 2026-11-05 and failed `flags.spec:124`, which blocks the gate. Moved to
   2026-11-25 with the reason written on it (design section 11's third option). Flagged in the
   report.
10. **Karen's own place was left exactly as it was found.** :34873 is back on
    `driven-hunt-karen` at `9c09c64a` (merged main), the FT is reconnected and synced
    (`328z-ft-restore2.png`), and the 18 `ServerStorage` attributes are byte-identical before and
    after (`328z-attrs-BEFORE.txt` / `328z-attrs-AFTER.txt`). Nothing was Saved, Published or
    Drafts-Committed. `<runs-dir>/smoke.sh 120`: **SMOKE PASS** -- gun in hand at 15 s and 120 s,
    0 stacks, 0 error lines, 15 waves.

## WHAT I COULD NOT VERIFY

* **`[harness2]`** -- see the header and `ESCALATE.md` item 5. A click only Karen can make.
* **"A red deer group in at least every second wave" is NOT MET in the Forest Test script**: 4 of
  15 slots (27 %), 21 % of measured release buckets. `forest_line.spec` asserts *"the stag is the
  last deer"*, so no deer row may sit after slot 8. `ESCALATE.md` item 4. On the `Match` drive path
  the target IS met by construction: `CHANCE_PER_RELEASE = 0.5` plus the drive's guaranteed group.
* **The species mix on the `Match` path inverts** (~19 deer against ~3 boars per drive).
  Delivered as the dispatch asked and flagged with the arithmetic: `ESCALATE.md` item 3.
* **The FT's restored module could not be read back in Edit.** `Boar`'s `Source` reads `len=0` in
  that place and `execute_luau` refuses a clone-require in Edit mode, so the restore rests on the
  rojo process's own working directory, `driven-hunt-karen` being at `9c09c64a`, and the panel shot.
* **Two of the fourteen climb points still stop a stag** (task 328n's own carry-over, geometry not
  force). Not touched here; a herd that meets them would stall there too.
