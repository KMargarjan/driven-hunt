# Task 351 — every drive a different pattern

Task: 351
Round: 1
Base: 2f9524ca (origin/main, #368)
Code commit: 4542600b467dc2453809ff6791fbc120ce146c61

```
[harness] PASS: 34/34 checks @ 4542600b467dc2453809ff6791fbc120ce146c61 (clean tree) scope=all
```

`[harness2]` is **N/A**: nothing changed under `TWO_PLAYER_PATHS` (`src/shared/ForestTest/`,
`src/server/ForestTest/`, `src/server/ForestTestBoot.server.luau`, `src/shared/Flags/`,
`tests/server/forest_line.spec.luau` — none of `src/server/Match/`, `src/client/Match/`,
`src/shared/Drive/`, `tests/client/Role.luau` or the match specs). CI green at 5867989b
(run 43207667214).

## PLAN (core-quality step 0)

(a) **REAL LIFE.** At a Drückjagd boar come out *"meist in kleinen Gruppen oder Rotten, oft aber
auch als Einzeltiere"* — mostly in small groups or sounders, often as singles
(`jagdwelten.de/jagden/drueckjagden/`), and red, fallow and roe deer are taken on the same drives
(`purewild.de/Glossar/Drueckjagd/`). A drive is a MIX, and which it is this time is not scripted.
(b) **MEASURED NOW.** The shipped script at `normal` is **13 groups, 73 animals, 7 deer parties**,
counted through `Boar.compositionSize` (`<runs-dir>/351-gen-probe.luau`). The `SCHEDULE` header's
"59 / 2 deer" is stale and that header says so itself.
(c) **TARGET.** Groups 9–13 and varying; 0–3 singles; each special at most once and not every
drive; deer parties never above the script's own count; animals within ±10 % of 73 (65–81), which
is inside the dispatch's ±15 %.
(d) **LEVER.** `ForestTest.SCHEDULE.drive` is read by exactly one function, `ForestTest.slotAt`,
through `ForestTest.cellSchedule`. The generator replaces the TABLE and leaves `slotAt` untouched.
(e) **HOW MEASURED AFTER.** The same probe, plus `ForestTest.patternLine()` in the live console.

## What changed

- `src/shared/ForestTest/init.luau`: `slotSpecial`, `driveSeed`, `generateDrive`, `variedSchedule`,
  `SILENT_KEEP_AT`, and a file-local `animalTarget`. Pure; nothing else in the module changed.
- `src/server/ForestTest/init.luau`: `cellSchedule(varietyIn)` wraps the cell's table;
  `weighParty`, `driveSeed`, `driveVariety`, `patternLine`; the flag and a session seed read once in
  `start`; `newDrive(now, driveNumber)`.
- `src/server/ForestTestBoot.server.luau`: hands the drive number to `newDrive` and prints the
  pattern line.
- `src/shared/Flags/init.luau`: the `DRIVE_VARIETY` row (default false, expires 2026-12-03), and
  `MAX_FLAGS` 26 → 27 with the reason written out.
- `tests/server/forest_line.spec.luau`: a new `describe` (no new spec file, so no `SCOPE_SPECS`
  change). `docs/research/2026-11-12-drive-variety.md` + `INDEX.md`.

## Claims

1. **OFF is the shipped script, by identity.** `variedSchedule(SCHEDULE, seed, weigh, false)` and
   `(…, nil)` return `SCHEDULE` itself. *Verify:* the spec case "is the shipped table BY IDENTITY
   with the switch off"; and `git show origin/main:src/shared/ForestTest/init.luau` vs `HEAD:` over
   the `drive = {` table is **byte-identical** (377 lines).
2. **OFF measured live, slot by slot, not as a summary.** One flag-OFF drive in her Forest Test
   (`<runs-dir>/351off-console.txt`) released, in order: lone male / hind party / sow and young /
   near herd / SILENT / six stags LATERAL / big sounder of nine / THE RED STAG / held / SILENT /
   SPLIT / BREAK-BACK deer / THE REFUSAL / last hinds running / THE ONE THAT STAYS — the fifteen
   shipped rows, with their own notes. No `[forest] … pattern` line was printed at all.
3. **Pure.** Same seed → the same rows field for field; the five seeds `driveSeed` produces for five
   consecutive drives of one cell give five different drives. *Verify:* the spec case "gives the
   same drive for one seed and a different one for the next" (it asserts `distinct == 5`).
4. **Karen's rules hold on every drive.** Over 40 drives the spec asserts: one species per group
   (a boar row carries a composition and no party and vice versa, and both resolve in `Boar`);
   0–3 singles; each special at most once; deer parties ≤ the script's own count; 9 ≤ groups ≤ 13;
   animals inside ±10 %; slot 1 always carries; fifteen slots and `atSeconds == slotSeconds`.
   *Verify:* "keeps every one of Karen's rules on every drive a real session deals". Independently,
   `<runs-dir>/351-band-probe.luau` ran **160 drives: animals 65..81, out of spec 0**, group counts
   9×12, 10×37, 11×66, 12×35, 13×10.
5. **"Sometimes, not every drive."** Each of SNEAK, BREAK-BACK, SPLIT and HOLD is both present in
   some of 40 drives and absent from others. *Verify:* the spec case of that name; and live, drive 2
   of `<runs-dir>/351s-console.txt` printed `specials=[]`.
6. **The dial keeps its meaning.** `quiet` fires exactly 9 groups on every generated drive and
   `normal` never more than the script's 13; a silent slot is silent at every density
   (`SILENT_KEEP_AT` > `DENSITIES.busy`). *Verify:* the spec case "keeps the dial's own shape".
7. **Nothing is invented.** Every generated row's geometry is a shipped row's of the same act and
   its party a shipped party; the vocabulary is read off the pool, not written down again. *Verify:*
   the spec case "generates from the CELL's rows" (every generated `northStuds` is one C1's own
   table wrote), and the live release lines, which carry the cell's depths and the script's crossings.
8. **Ten live drives in her Forest Test at C1, flag ON, all ten different.** `351on` drives 1–5,
   `351f` 1–2, `351s` 1–3 — groups 9–13, animals 65–70, singles 0–2, deer 1–7, specials 0–4, and
   two sessions gave drive 1 of C1 two different seeds (1562638763 and 1330611673), which is the
   session seed doing its job. *Verify:* `grep "pattern cell=" <runs-dir>/351*-console.txt`.
9. **349's action is kept, at stand 4.** First sighting 1–8 s (target ≤ 30), median gap 6–12 s
   (target ≤ 20) over the five on-stand drives; released 126–134 against the flag-OFF control's 122
   (+3 % to +10 %); peak live 60 on both paths, where `MAX_BOARS` binds. *Verify:*
   `python 351-table.py 351on` / `351off` / `351s`. **Stands 7 and 11 are NOT MEASURED** — see below.
10. **The frame.** `<runs-dir>/351f-sighting.png`, opened: a first-person view from the stand at
    `DRIVE 1 · 4:53 TIME` (≈7 s in), the shotgun's barrels and the hunter's hand low-centre, and
    **six red deer crossing left-to-right at 66–80 studs** — four broadside at the treeline edge,
    a paler calf centre-left, one more part-hidden by a bush — on open green ground before a
    birch/leafy wood. HUD: DRIVE compass bar (drive from N), minimap, verge chevrons, "stay on
    stand, animals coming", "an animal got away x4", INF SLUG. That drive's own pattern line reads
    `groups=13 … deer=5 … mix=D7 D8 D8 B6 …` — its first three groups are deer parties, which is
    what the frame shows.

## Three measured cycles (core-quality step 2)

| cycle | change | measured over 160 drives | distance to target |
|---|---|---|---|
| 1 | singles capped by the ladder's reach | animals 60..81 | 20 of 160 out of spec |
| 2 | deer then singles reduced until the ceiling clears the floor (a deer party tops out at 8, a sounder at 9) | animals 65..81 | 10 of 160 (all `singles=4`) |
| 3 | the specials' own singles counted toward the 0–3 (the SNEAK stag weighs one) | animals 65..81 | **0 of 160** |

## What I could not verify

- **Stands 7 and 11: NOT MEASURED.** The real click lands on the row (the console reads
  `clicked row 11 -> 11 WEST FREE`) but the hunter is still dealt stand 4 — `351s-track.txt` reads
  `stand=4 at=0` for every on-stand sample of that run. That is the stand-pick path (tasks 323/349),
  not this change; handing it back rather than chasing it. Stand 4's numbers are above.
- **`PLACEMENT_IN_PLACE` ON: NOT RUN.** Her live path is OFF and that is what was measured; the
  generated rows feed the same `slotAt`/`Placement` seam either way, and the spec drives the cell
  table rather than the base one.
- A per-drive `released` is read off the console's own release lines, and the console buffer rolls:
  two of the ten drives logged only a handful of lines while the watcher was between polls. Those
  two rows are reported as incomplete captures, not as small drives.

## ANSWERED (the dispatch's CHECKED flags)

- ANSWERED: L-136 — no spec failed in the run that names the code commit (34/34, 0 failed, 0 errors
  on both server and client), so no flake is named or relied on.
- ANSWERED: L-127 — every dispatch item is MET / NOT MEASURED by name in "Claims" and "What I could
  not verify" above; stands 7 and 11 and `PLACEMENT_IN_PLACE` ON are the two NOT MEASURED.
- ANSWERED: L-162 — every live proof was taken from `driven-hunt-rev` checked out at 5867989b, the
  code commit's own tree; the harness line names 4542600b, a paperwork commit after it.
- ANSWERED: L-014 — nothing was ever checked out in `driven-hunt-karen`; her Forest Test ends on
  :34873 served from `driven-hunt-karen`, in Edit (`351-ft-final.png`, reconnected).
- ANSWERED: L-101 — the override set in her place before and after is identical
  (`351-attrs-before-overrides.txt` vs `351-attrs-final2.txt`, diff empty); `DRIVE_VARIETY` was
  removed as an attribute rather than set to false, and `--place forest clear` was never run.
- ANSWERED: L-190 — the flag-OFF arm is shown slot by slot (claim 2), not as "identical to the
  drive before", and the shipped table is proved byte-identical to `origin/main`.
- ANSWERED: L-093 — delete `generateDrive`'s body and the spec cases for purity, the forty-drive
  rules, the specials and the dial all fail; delete `patternLine` and claim 8's evidence disappears.
