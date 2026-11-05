# Task 328z -- red stag herds of 5-8 in single file, and more of them

Task: 328z
Round: 1
Base: 9c09c64a (main, 328i #332 merged)
Code commit: (pending)

## PLAN

**(a) REAL LIFE.** A red deer party is **five to eight animals**, not one to three: Wildlife
Online's account of the Isle of Rum study gives hind parties at a **median of 7 in summer and 5 in
winter**, and bachelor stag groups at **7 and 4**
(<https://www.wildlifeonline.me.uk/animals/article/red-deer-behaviour-social-structure>; full
sourcing and the negative result on spacing in `docs/research/2026-11-05-red-deer-herds.md`).

**(b) MEASURED NOW**, in Karen's own Forest Test on the merged main (`9c09c64a`, served to her place
on :34873), two instruments:
* `<runs-dir>/328z-cfg.luau` (live module read) -- `COMPOSITIONS` sizes **1 / 2 / 3**,
  `CHANCE_PER_RELEASE` **0.20**, `MAX_GROUPS_ALIVE` **1**, `maxBoars` **8**, and the C1 drive script
  carries deer in **2 of 15 slots (13 %)** = **3 red deer per drive** (`slot2:hinds=2 slot8:stag=1`).
* `<runs-dir>/328z-file.luau` (300 s live window, 5 Hz, `328z-BEFORE-ft.txt`) -- 9 release buckets,
  **1 carried a deer, 1 animal**, and **0 road-band samples held two deer at once**, so the file
  Karen asked about could not be measured at all: there was never more than one red deer alive.

**(c) TARGET.** Group sizes **5, 6, 7** (plus the solitary stag at 1) because that is the Rum band;
red deer per Forest Test drive **>= 20** (from 3); deer in **>= 4 of 15** script slots and
`CHANCE_PER_RELEASE` **0.5** on the drive path, which is "a group in at least every second release"
with the drive's one guaranteed group; centre-to-centre gap in the file **8.5 studs** +- 3 median
and lateral offset **<= 2.5 studs** median, because 8.5 is this repo's own MEASURED file station
(`Data.LINE.spacingStuds`, a 3-stud nose-to-tail gap on a 5.5-stud body; 6.5 was tried and measured
no better in task 136) and no published source gives a metre figure for a deer file.

**(d) LEVER.** Every number has a writer, and these are the only writers:
```
src/server/Boar/init.luau:3957:			COMPOSITIONS = {
src/server/Boar/init.luau:3911:			CHANCE_PER_RELEASE = 0.5, -- K's dial
src/server/Boar/init.luau:3932:			MAX_GROUPS_ALIVE = 3,
src/server/Boar/init.luau:487:	maxBoars = 24,
src/shared/ForestTest/init.luau:2168:			party = "harem", -- {stag = 1, hind = 4, calf = 2}
src/shared/ForestTest/init.luau:2209:			party = "stags", -- {stag = 6}
```
`maxBoars` is a lever that had to move: `Runtime:spawnSounder` refuses a release that does not fit
WHOLE (`#self._boars + size > self._config.maxBoars`), so at 8 a herd of 7 could never come out
beside the drive's six boars. The file SPACING has a writer (`Data.LINE.spacingStuds = 8.5`) and is
deliberately **not** moved -- the target is this repo's own measurement.

**(e) HOW IT WILL BE MEASURED AFTER.** The same two files, in the same place, over the same window
length: `328z-cfg.luau` for the table and the dials, `328z-file.luau` for the live window (waves,
deer waves, group sizes, per-member gap and lateral offset at the road band), and
`328n-sampler.luau` for stuck >= 3 s and road crossings.
