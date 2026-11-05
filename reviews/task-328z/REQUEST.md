# Task 328z -- red stag herds of 5-8 in single file, in the Forest Test

Task: 328z
Round: 3
Base: 9c09c64a (main, 328i #332 merged)
Code commit: TBD

## PLAN (option B -- the Director's decision, `ESCALATE.md` 2026-11-05 ~13:20)

**(a) REAL LIFE.** Red deer are a herding animal: Wildlife Online on Clutton-Brock's Isle of Rum
study gives hind-party medians of **7 in summer and 5 in winter** and bachelor stag groups of
**7 and 4**; a mature stag outside the rut is usually **alone** (only 10-20 % associate with hinds).
`docs/research/2026-11-05-red-deer-herds.md`.

**(b) MEASURED NOW** (round 1/2, in Karen's Forest Test at :34873, `328z-AFTER-ft-c1..c3.txt`,
`328z-stuck-AFTER.txt`): herds of 5-7 came out in ONE FILE at a median centre-to-centre gap of
**8.50 studs** and a median lateral offset of **0.20-0.30 studs**; **0 of 45** animals stuck >= 3 s;
**29 of 29** crossings completed; **3 -> 19** deer per FT drive. The spacing and the file are
therefore already proven and are NOT re-tuned here. What round 2 refused was the `Match` drive's
ceiling arithmetic (findings 1-3), which this round deletes rather than repairs.

**(c) TARGET.** (1) `git diff main -- <TWO_PLAYER_PATHS>` is EMPTY: the Match drive's released
sizes, its chance, its group cap and its ceiling are main's, so findings 1-3 cannot exist. (2) In
the Forest Test, a red deer group in **about every second slot** -- 7 of 15 (47 %), from 4 (27 %) --
at sizes **5, 6, 7 and 8**, which is Karen's *"like 5 8"* read as the four Rum medians.

**(d) LEVER.** Three, and each has a writer:
- the weighted draw the Match path takes: `Boar.deerComposition`'s
  `total += math.max(0, row.weight or 0)` then `if want < seen` (`src/server/Boar/init.luau`), so a
  row at `weight = 0` is **unreachable by any `pick`** while a NAMED ask still finds it by
  `row.name == wanted` three blocks above. That is the whole of option B: the herd rows exist for
  the Forest Test's named slots and the Match drive cannot draw one.
- how many deer groups may be alive: `release.MAX_GROUPS_ALIVE or 1` in `Boar.deerGroupsAllowed`,
  read off `self._config` -- so `ForestTestBoot`'s `world.config` overrides it for that place only,
  exactly as it already overrides `maxBoars` with `Data.MAX_BOARS`.
- which party a Forest Test slot releases: `ForestTest.SCHEDULE.drive[n].party`, handed to
  `Boar.deerComposition(0, 0, boar, row.party)` in `ForestTest.releaseLine`.

**(e) HOW IT WILL BE MEASURED after.** The same instruments as (b): `328z-read.luau` /
`328z-file.luau` through `ftplay.py server` for the FT drive's census, spacing and stuck samples,
and `328z-match.luau` for the Match drive's -- plus a `git diff main` that is empty on the
two-player paths, printed in the report.
