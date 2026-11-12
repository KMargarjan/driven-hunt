# Task 351 — every drive a different pattern

Task: 351
Round: 2
Base: 2f9524ca (origin/main, #368)
Code commit: 5350c8c799b961299e9e22ed0e8fa02d245d1c76

```
[harness] PASS: 34/34 checks @ 5350c8c799b961299e9e22ed0e8fa02d245d1c76 (clean tree) scope=all
```

`[harness2]` is **N/A**: nothing under `TWO_PLAYER_PATHS` changed (`src/shared/ForestTest/`,
`src/server/ForestTest/`, `src/server/ForestTestBoot.server.luau`, `src/shared/Flags/`,
`tests/server/forest_line.spec.luau` — no `Match/`, no `Drive/`, no `Role.luau`, no match spec).
**Every live figure below was taken from `driven-hunt-rev` checked out at this commit** (L-162).

## Round 1's five findings, each with what fixed it

1. **A drive could contain no red deer.** The budget's reduction was deer-first and unbounded. Two
   causes, both fixed: the reduction now has a floor of one deer party (`minDeer`, 0 only when a
   special already carries a deer, and the SINGLES give way instead); and — which the floor alone
   did not catch — a deer token can land on a slot the rank puts at `keepAt = 15`, so after the
   ranking the last firing ordinary group is turned into the deer party **nearest its own size** if
   no firing row is a deer. **Measured:** the draw floor alone still left **4 of 160** drives with
   no deer; with both, **0 of 160**. Two spec cases, both FAIL FIRST: "never deals a drive with no
   red deer in it" asserts `deerGroups >= 1`, and the 40-drive case keeps the ceiling.
2. **The last act was silenced.** The nine carrying rows are now spread by the shipped script's own
   per-act split, read off the pool (`keepAt <= quiet` gives 4 / 3 / 2), with a spill so the total
   is still nine. The spec case "still releases in the LAST act" asserts, on each of 40 drives, that
   a slot in the last third fires at `normal` **and** that the last firing one is due at ≥ 140 s.
   The 160-drive probe checks the same two (`noLateAct`, `lastSlotEarly`): 0 failures.
3. **`planDrive` keyed on the previous drive.** The drive number is a parameter now:
   `cellSchedule(varietyIn, driveNumber)` → `driveSeed(driveNumber)`, and `planDrive` passes its own
   `key`. **Proved live with `PLACEMENT_IN_PLACE` ON** (`<runs-dir>/351pip-console.txt`):
   `plan 1: … 65 animals` against `drive 1 pattern … groups=11 animals=65`, and
   `plan 2: … 66 animals` against `drive 2 pattern … groups=11 animals=66`. Before the fix plan 2
   carried drive 1's roster. No error line in that session (`Stack Begin` / `attempt to` /
   `invalid argument`: 0), and the beds include act-III slots 13 and 14.
4. **The cell-rows case survived deleting the producer.** It now pins the whole geometry tuple
   (`northStuds` / `offsetX` / `crossOffset` / `route` / `pace`) to a shipped row **of the same act**
   over twelve drives, and requires the row list to differ from `cell.drive` — so both "it returned
   the script" and "act-I geometry on an act-III slot" fail.
5. **Max gap was measured and not reported.** It is in claim 8 below, per drive.

Round 1's notes were taken too: act III may now draw act II's geometry (it had exactly one ordinary
row of its own, so every act-III slot cloned it); `ForestTest.rowNote` is one function called after
every budget step, so a resized group no longer prints the party it used to be; the act assertion
is the slot's own band rather than `1..3`; the `busy` column is written down; `INDEX.md`'s two stale
numbers are corrected.

## Claims

1. **OFF is the shipped script, by identity.** `variedSchedule(…, false)` and `(…, nil)` return
   `SCHEDULE` itself, and `SCHEDULE.drive` is **byte-identical to `origin/main`** (377 lines,
   `git show origin/main:… | awk '/^\tdrive = \{$/,/^\t\},$/'`). *Verify:* the spec case "is the
   shipped table BY IDENTITY with the switch off".
2. **OFF measured live, slot by slot.** The flag-OFF drive (`<runs-dir>/351off-console.txt`)
   released, in order: lone male / hind party / sow and young / near herd / SILENT / six stags
   LATERAL / big sounder of nine / THE RED STAG / held / SILENT / SPLIT / BREAK-BACK deer / THE
   REFUSAL / last hinds running / THE ONE THAT STAYS — the fifteen shipped rows with their own
   notes, and no `[forest] … pattern` line at all.
3. **Pure.** Same seed → the same rows field for field; the five seeds `driveSeed` gives five
   consecutive drives of one cell give five different drives (`distinct == 5`). *Verify:* "gives the
   same drive for one seed and a different one for the next".
4. **Karen's rules hold on every drive.** Over 40 drives the spec asserts one species per group,
   0–3 singles, each special at most once, 1 ≤ deer parties ≤ the script's own count, 9 ≤ groups
   ≤ 13, animals inside ±10 %, slot 1 carries, a late slot carries, fifteen slots, and each row's
   act is its own band. Independently `<runs-dir>/351-band-probe.luau` ran **160 drives: animals
   65..81, out of spec 0**; group counts 9×12, 10×37, 11×66, 12×35, 13×10.
5. **"Sometimes, not every drive."** Each of SNEAK, BREAK-BACK, SPLIT and HOLD is present in some of
   40 drives and absent from others (spec, and the probe's `seen=true missed=true` for all four).
   Live: drive 2 of `<runs-dir>/351s-console.txt` printed `specials=[]`.
6. **The dial keeps its meaning.** `quiet` fires exactly 9 groups on every generated drive, `normal`
   never more than 13, and a silent slot is silent at every density. *Verify:* "keeps the dial's own
   shape"; the probe checks `quiet` on all 160.
7. **Nothing is invented.** Claim 4's spec case (finding 4's rewrite) plus the live release lines,
   which carry the cell's own depths and the script's own crossings.
8. **Four live drives at THIS commit, all different** (`<runs-dir>/351r2-console.txt`,
   `python 351-table.py 351r2`):

   | drive | groups | animals | singles | deer | specials | first sighting | median gap | max gap | released | peak live |
   |---|---|---|---|---|---|---|---|---|---|---|
   | 1 | 12 | 73 | 1 | 5 | SNEAK, BREAK-BACK, HOLD | 6 s | 7 s | 51 s | 145 | 51 |
   | 2 | 12 | 69 | 3 | 1 | HOLD, SPLIT, BREAK-BACK | — | — | — | — | 51 |
   | 3 | 10 | 67 | 1 | 4 | HOLD | 6 s | 7 s | 44 s | 122 | 57 |
   | 4 | 10 | 65 | 2 | 1 | SPLIT | — | — | — | — | 57 |
   | **OFF control** | 13 | 73 | 1 | 7 | all four | 7 s | 7 s | 50 s | 122 | 60 |

   First sighting 6 s against the target ≤ 30; median gap 7 s against ≤ 20; max gap 44–51 s against
   the OFF control's 50 s. Drives 2 and 4 have no sighting row because the hunter was at the lodge
   for them — see "What I could not verify". Ten more drives were measured at the round-1 commit
   (`351on`, `351f`, `351s`), all fourteen patterns different, and two sessions gave drive 1 of C1
   two different seeds, which is the session seed doing its job.
9. **The frame, opened.** `<runs-dir>/351r2-sighting.png`, taken at this commit at
   `DRIVE 1 · 4:53 TIME` (≈7 s in): a first-person view from stand 4 — the shotgun's barrels and the
   hunter's hand and boot low-centre, the yellow verge chevrons across the foreground grass, a birch
   and leafy wood behind — and **two dark boar on the open grass at the left edge, ~86 studs out**,
   one broadside and one behind it. HUD: `0 ANIMALS`, `HUNTER`, `$13500`, the DRIVE compass bar
   (drive from N), the minimap, "stay on stand, animals coming", "Drive on", "an animal got away
   x2", `INF SLUG`. That drive's own pattern line begins `mix=B2 D8 B2 …` — its FIRST group is two
   boar, which is what is in the frame.
10. **`PLACEMENT_IN_PLACE` ON does not break** — finding 3's evidence above, plus 65 and 66 animals
    placed into bands `dz 150..1300` with `skipped 0` and `in view 0`, and the generated rows
    reaching `restSpot`/`bedSpot` without a refusal.

## What I could not verify

- **Stands 7 and 11: NOT MEASURED.** The real click lands on the row (`clicked row 11 -> 11 WEST
  FREE`) but the hunter is still dealt stand 4 — `351s-track.txt` reads `stand=4 at=0` for every
  on-stand sample of that run. That is the stand-pick path (tasks 323/349), not this change.
- **Drives 2 and 4 of the table have no sighting figures.** Between drives the player is returned to
  the lodge unenrolled; the watcher puts him back and re-picks, which costs about half a drive. Those
  two rows are a gap in the INSTRUMENT, not a quiet drive — their pattern lines and peak live are real.
- **`released` is not a clean comparison.** It counts the console's own release lines, which include
  the repeat window past slot 15 on the OFF placement path, so it is a function of how long the drive
  ran as much as of the roster. Drive 1's 145 against the control's 122 is **+19 %, outside the
  dispatch's ±15 %**, while drive 3's 122 is +0 %. The number the generator actually controls — the
  roster the drive declares — is 65–73 against the script's 73, i.e. **−11 % to 0 %**, inside the
  band. Saying both rather than picking the flattering one.
- **Peak live** is 51–57 against the control's 60, i.e. −5 % to −15 %, inside ±15 % at the edge.

## ANSWERED (the dispatch's CHECKED flags)

- ANSWERED: L-136 — no spec failed in the run naming the code commit (34/34, 0 failed, 0 errors on
  both server and client), so no flake is named or leaned on.
- ANSWERED: L-127 — every dispatch item is MET or NOT MEASURED by name, max gap included this round.
- ANSWERED: L-162 — every live figure in claims 8, 9 and 10 comes from `driven-hunt-rev` at
  5350c8c7, the code commit; the round-1 figures are labelled as the round-1 commit's.
- ANSWERED: L-014 — nothing was checked out in `driven-hunt-karen`; her Forest Test ends on :34873
  served from `driven-hunt-karen`, Edit, reconnected (`351-ft-final2.png`).
- ANSWERED: L-101 — the overrides in her place are identical before and after
  (`351-attrs-before-overrides.txt` vs `351-attrs-final3.txt`, diff empty): `DRIVE_VARIETY` removed
  as an attribute, `PLACEMENT_IN_PLACE` set back to the `off` it was. `--place forest clear` never run.
- ANSWERED: L-190 — the flag-OFF arm is shown slot by slot (claim 2), never as "identical to the
  drive before", and the shipped table is proved byte-identical to `origin/main`.
- ANSWERED: L-093 — delete `generateDrive`'s body and the purity, 40-rule, deer, last-act, specials,
  dial and geometry cases all fail; delete `patternLine` and claims 8 and 10's evidence disappears.
