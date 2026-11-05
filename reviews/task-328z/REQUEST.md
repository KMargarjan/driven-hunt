# Task 328z -- red stag herds of 5-8 in single file, in the Forest Test

Task: 328z
Round: 3
Base: 9c09c64a (main, 328i #332 merged)
Code commit: e4a05fbf7ae30a8ce655bfcb3b3d33302f51341b

```
[harness] PASS: 34/34 checks @ e4a05fbf7ae30a8ce655bfcb3b3d33302f51341b (clean tree) scope=all
```

`e4a05fbf` is the last commit that changed `src/` or `tests/`, and the FULL suite passed on it with
a clean tree. **`test2` is N/A for this round AND for the merge**, shown rather than argued:
`git diff main -- <TWO_PLAYER_PATHS>` is EMPTY (claim 1).

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

## ITERATION (three cycles, one instrument, Karen's place)

`328z-file.luau` through `ftplay.py server` plus the `[ForestTest] line N:` console, in the Forest
Test (place 130094961655666), at the commit named on each row.

| # | Commit | Change | Measured: deer waves / deer per drive | Distance to target |
|---|---|---|---|---|
| 1 | `9c09c64a` (main) | none -- the BEFORE | **2 of 15 slots, 3 deer** (`328z-BEFORE-ft.txt`) | 7 slots short |
| 2 | `2b558bb3` | herds in 7 slots, `MAX_DEER_GROUPS` 3 | **4 of 12 waves (33 %), 24 deer**; console: *"slot 6 wanted the stags and the deer cap refused"*, same for 8 and 9 (`328z-r3-ft-c2.txt`, `328z-r3-console.txt`) | 3 scripted slots released NOTHING |
| 3 | `e4a05fbf` | `MAX_DEER_GROUPS` 3 -> 40 | **7 of 14 waves (50 %), 39 deer, sizes 5/7/6/1/8/7/5**, 0 refusals (`328z-r3-ft-c3.txt`, `328z-r3-console2.txt`) | MET |

Why row 2 failed, from the code rather than from a guess: `Boar.deerGroupsAllowed` counts a deer
with **no sounder id as its own group**, so one herd that strings out at the crossing and dissolves
(`SOUNDER.BREAK_STUDS`) is already five groups. The cap has to clear every deer the script can have
afoot (39); `forest_line.spec` asserts that RELATION, not the literal.

## CLAIMS

1. **The `Match` drive is main's, byte for byte.** `git diff main --` over every `TWO_PLAYER_PATHS`
   entry (`src/server/Match/`, `MatchBoot.server.luau`, `src/client/Match/`,
   `MatchBoot.client.luau`, `src/shared/Drive/`, `tests/client/Role.luau`, the seven
   `tests/server/match_*.spec.luau` and `zz_drive_boundary.spec.luau`) prints NOTHING. So does
   `git diff main -- tests/server/boar_body.spec.luau`. `Boar.CONFIG`'s `maxBoars` (8),
   `CHANCE_PER_RELEASE` (0.2), `MAX_GROUPS_ALIVE` (1) and the three WEIGHTED `COMPOSITIONS` rows
   (1/2/3 animals) are main's as well -- `git diff main -- src/server/Boar/init.luau` is 17 lines
   and every one of them is an addition.
2. **Round 2 finding 1 is closed by deletion:** the `animals` / `DEER_PARTY_MAX` gate does not
   exist. `grep -rn DEER_PARTY_MAX src/ tests/` answers nothing, and `Phase.maybeRelease` is main's.
3. **Round 2 finding 2 is closed by deletion:** there is no `DEER_PARTY_MAX` branch left for a case
   to have teeth on. What replaces it is claim 5, and claim 5 fails when its producer is deleted.
4. **Round 2 finding 3 is closed by deletion:** `MAX_ALIVE_BOARS` is main's **6** and there is no
   second ceiling beside it. `grep -n "MAX_ALIVE_BOARS = " src/server/Match/init.luau` answers two
   lines -- `init.luau:555`, the value, and `:909`, its row in the config's own key-presence set --
   and both are main's, as claim 1's empty diff over `src/server/Match/` says.
5. **`weight = 0` is what keeps a herd off the drive, and the zero is load-bearing.** `deer.spec`,
   *"KEEPS THE HERDS OUT OF THE WEIGHTED DRAW"*: 1001 picks across [0, 1) all answer a row of <= 3
   animals; every herd is reachable BY NAME at 5 / 6 / 7 / 8; and the second arm gives `bigherd` a
   weight in a CLONE, where the same walk then answers 8. Delete `weight = 0` from the four new
   rows and the 1001-pick loop fails.
6. **The Forest Test carries a deer group in about every second slot.** 7 of 15 rows (2, 4, 6, 8, 9,
   12, 14) = 47 %. `forest_line.spec` asserts `deerGroups` 7 / `boarGroups` 6 at `normal`, 39
   scripted deer, 73 animals, `leapingGroups` 6 and 32 leaping animals; LIVE it measured 7 of 14
   waves (50 %) and 39 deer.
7. **"The stag is last" is relaxed to "no second LONE stag after him", both arms by parameter.**
   `forest_line.spec`'s stag case: `loneStagsAfter(SCHEDULE.drive, stag.slot) == 0`, and
   `deerAfter(SCHEDULE.drive, stag.slot) == 3` -- so the OLD rule is FALSE on the shipped script,
   which is the FAIL-FIRST line: restore the case to *"every row after him is a boar"* and it fails
   now. Then a hand-built schedule with a second lone stag behind him answers 1, and the same
   schedule with that row made a herd answers 0.
8. **The file holds at five, six, seven and eight.** LIVE at the code commit, 317 approach pairs
   over five releases: centre-to-centre gap **median 8.50** studs (p90 9.10), lateral offset
   **median 0.20** (p90 0.90); per release 8.50 / 8.50 / 8.60 / 8.50 / 8.55. Nothing about spacing
   was changed -- 8.5 is `Data.LINE.spacingStuds`, this repo's own measured station.
9. **Nothing sticks and they cross.** `328z-r3-stuck3.txt`: **stuck >= 3 s = 0 of 83 animals**
   (worst run 1.8 s, a cub), crossings **53 of 54 completed** -- the 54th was still inside the band
   when the 205 s window closed.
10. **One real shot runs the file ON FORWARD** (round 1 item 4, which was NOT PROVEN).
    `328z-r3-shoot.luau` fires through `FireRequest:FireServer`, the player's own seam and never a
    UI click: *"FIRED at Boar3 (hind) 56 studs, clear LOS, t=1"*. `328z-r3-forward.txt` over the
    next 16 s reads **forward=12 back=0 held=0**; eleven of the twelve crossed the road (dz
    +84..+181 -> -67..-193) and the hind that was hit still moved 17 studs forward. Worst single
    backward step 1.28 studs.

**Karen's place was left exactly as it was found.** The proof ran against a rojo served from
`driven-hunt-rev` on **:34876**; `driven-hunt-karen` was never checked out, built or played
(L-014). Afterwards the Forest Test's Rojo was pointed back at **:34873** and reconnected
(`evidence/port-34873-20261105-145027.png`), the 18 `ServerStorage` attributes are byte-identical
(`328z-r3-attrs-BEFORE.txt` / `-AFTER.txt`; `diff` is empty), `driven-hunt-rev` is back on
`8ae8c627`, the :34876 server is stopped, and `smoke.sh 120` on her restored build reads
**SMOKE PASS** -- gun in hand at 15 s and 120 s, 0 stacks, 0 error lines, 15 waves.

## FRAMES (rule 5, looked at)

Re-shot at the code commit, not reused (L-162, L-086): `328z-r3-G1.png` and `328z-r3-G2.png`, from
the C1 stand at the hunter's own eye height **y = 112.1** (the `head=` reading of
`328z-where.luau`), HUD reading `DRIVE 1 / HUNTER`. **G1**: the five-animal hind party coming out of
the far treeline in ONE line, shotgun barrel across the lower right. **G2**: a herd crossing the
road directly in front of the stand -- two animals close enough to fill a third of the frame, four
more strung along the road behind them, an orange beater beyond. No boar in either.

## WHAT I COULD NOT VERIFY

* **Karen has played neither.** The Match drive is main's, so there is nothing new there to play;
  the Forest Test half wants her eye on the herds.
* **`MAX_DEER_GROUPS = 40` never binds on a scripted drive, and that is deliberate.** What binds in
  this place is `Data.MAX_BOARS` = 60 and `releaseLine`'s whole-line-or-nothing. PEAK concurrent
  animals was not measured -- only "83 seen over 205 s".
* **Two of the fourteen climb points still stop a stag** (task 328n's own carry-over, geometry not
  force). Untouched here.

## ANSWERED LEARNING FLAGS

* **ANSWERED: L-136** -- the run quoted above is 34/34 with no FAIL line, so no flake is claimed and
  no control run is owed. An earlier run did hit `deer_hitbox:682`, `weapon_shot:1490` / `:1890`,
  `camera_client:375`, `semiauto_client:93` and `weapon_client:1211`; it is NOT the evidence here.
* **ANSWERED: L-127** -- every dispatch item carries MET / NOT MET / NOT PROVEN in the report, in my
  own words, and the shot claim quotes the probe's own printed line rather than "aimed at a deer".
* **ANSWERED: L-162** -- every live number and both frames were taken at `e4a05fbf`, the code
  commit. The `2b558bb3` readings appear only as iteration row 2, labelled with their commit.
* **ANSWERED: L-014** -- `driven-hunt-karen` was never checked out, built or played; the proof ran
  from `driven-hunt-rev` on :34876 and her place was put back on :34873.
* **ANSWERED: L-086** -- both frames are from the hunter's own eye height (y = 112.1) at the C1
  stand, opened and described above; neither is aerial and neither is reused.
* **ANSWERED: L-101** -- the 18 `ServerStorage` attributes were dumped BEFORE anything was touched
  and diffed afterwards; `diff` is empty. No `flags.py clear` was run on her place (rule K).
* **ANSWERED: L-093** -- claim 5's 1001-pick loop fails when `weight = 0` is deleted, and claim 7's
  `deerAfter(...) == 3` fails when the old rule is restored. Both are stated as both arms, not one.
