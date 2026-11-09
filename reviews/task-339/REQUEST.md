# Task 339 -- only the stag leaps: the hind and the calf never jump

Task: 339
Round: 2
Base: d91d65e9
Code commit: fc323305f31521b7d2451567f3d5ad4bd0a1d4ce

Harness, full run, first try both rounds, no flake fired either time:

    [harness] PASS: 34/34 checks @ fc323305f31521b7d2451567f3d5ad4bd0a1d4ce (clean tree) scope=all

(round 1's line, same 34/34, was @ `0f0e91be`. The live BEFORE/AFTER readings below were taken at
`0f0e91be`; `git diff 0f0e91be..fc323305 -- src` is comments, one printed `note` string and no
number a running animal reads, so they stand.)

`test2` N/A: no `TWO_PLAYER_PATHS` file is touched (the change is `src/server/Boar/`,
`src/shared/ForestTest/` and two server specs).

## PLAN (core quality protocol step 0)

**(a) REAL LIFE.** A bound -- all four feet off the ground together -- is the gait a red deer uses to
clear an obstacle (Lingle 1993, `docs/research/2026-10-23-deer-road-leap.md` section 8); a stag
clears a 1.8 m fence routinely. Karen's rule for this game, 2026-11-09: *"deer famale and kid doesnt
jumt you need to remove that only male jump"*. So the number for a hind and a calf is **0 leaps per
crossing**, and the stag's 6.0 studs (1.68 m) stays.

**(b) MEASURED NOW** -- her Forest Test, 215 s, 8 staged `herd@120,-140,60,run` releases, probe
`<runs-dir>/339-instrument.luau` (task 334's instrument 6, byte-identical but for its default
window), raw `<runs-dir>/339-BEFORE-raw.txt`, summary `<runs-dir>/339-BEFORE.txt`. The FT was served
from `driven-hunt-karen` at `5cc51f81`, and `git diff --stat 5cc51f81 d91d65e9 -- src tests tools`
is EMPTY, so this reading is main `d91d65e9`'s code.

**Karen's defect is reproduced: the hind bounds 23 times and the calf 21.**

**(c) TARGET.** hind **0** bounds, calf **0** bounds, both still crossing; stag's bounds, apex and
length unchanged.

**(d) LEVER.** `grep -n`, at `d91d65e9`:

    src/server/Boar/init.luau:3583:		APEX_STUDS = { stag = 6.0, hind = 5.132, calf = 3.336 },
    src/server/Boar/init.luau:4728:function Boar.leapByKind(config, kind: string?)
    src/server/Boar/Body.luau:1619:	local apex = leap.APEX_STUDS[kind or ""]

**(e) AFTER** is the same probe, same place, same 8 herds, at the code commit.

## The change

**One rule: no `APEX_STUDS` row, no bound.** The hind's 5.132 and the calf's 3.336 are deleted
(archived, rule 7), and `Boar.leapByKind` -- the one per-kind config overlay -- now hands a kind
whose arc is 0 a config with `MODEL.LEAP.ENABLED` false. That is upstream of all three readers, so
it covers every state at once with no per-state suppression and nothing hidden in the Hud or the
animation side.

## Claims

1. **The hind and the calf no longer bound, and still cross.** Same probe both sides, 215 s, 8
   staged herds. BEFORE `339-BEFORE.txt` / AFTER `339-AFTER.txt`:

   | kind | crossings before -> after | bounds **in the road band** | all LEAP lines |
   |---|---|---|---|
   | stag | 16 -> 16 | 6 -> 6 | 10 -> 10 |
   | hind | 56 -> 54 | **9 -> 0** | **23 -> 0** |
   | calf | 30 -> 30 | **5 -> 0** | 21 -> 6 |

   Verify: `339-BEFORE-raw.txt`, `339-AFTER-raw.txt`, `339-sum.py`.

2. **The calf's 6 remaining LEAP lines are terrain hops, not bounds, and the instrument says so.**
   `339-split.txt` splits every LEAP line by take-off speed and by distance from the road centre:
   AFTER, the calf's six are all OUTSIDE the band (|dz0| > 20.5) at `vy1` **12.3..14.9**, while a
   calf's configured bound took off at `sqrt(2 * 196.2 * 3.336)` = **36.2** studs/s. The same
   background exists BEFORE on the stag (4 out-of-band lines at `vy1` 13.4..15.3). The in-band
   count, which is the one Karen's sentence is about, is 0 for both kinds.

3. **The stag is unchanged.** `git diff d91d65e9..fc323305 -- src/server/Boar/init.luau` leaves
   `stag = 6.0`, `SPEED_SCALE`, `SECONDS`, `GRAVITY` and `LIFT_STUDS.stag` untouched -- only the two
   deleted keys, `leapByKind`'s new branch and comments. Live, and stated to the digit because
   round 1 called a rise unexplained: his LEAP lines are **10 -> 10**, his bounds attributed to a
   road crossing **6 of 16 -> 6 of 16**, take-off `vy1` **40.9..42.8 -> 38.7..43.6**, median apex
   **5.274 -> 5.828** studs against a configured 6.0 (the instrument reads under the arc because
   the peak falls between frames). What DID move is where the instrument filed four of those ten:
   before, 6 lines sat inside the band at `vy1` 40.9..42.8 and 4 outside it at `vy1` 13.4..15.3 --
   bounds and terrain hops; after, all 10 sit inside at `vy1` 38.7..43.6. **I cannot say from this
   run why 4 of his crossings stopped producing a hop and started producing a bound**, and I am not
   claiming a mechanism: his per-crossing bound rate is identical, 6 of 16 both times, and the code
   that decides it is byte-identical.

4. **A case dies if the fix is deleted (L-093).** `deer.spec`, *"bounds the STAG ALONE..."* asserts
   `leap.APEX_STUDS.hind == nil` and `calf == nil` and that `leapApex`/`leapAir`/`leapPlan` answer 0
   for hind, calf and every boar: restoring the two rows fails it. `deer.spec`, *"switches the leap
   OFF in a non-leaper's OWN config, in every state"* builds a config with the flag LIT, and asserts
   the stag's `kindConfig` keeps `ENABLED` true and `leapStarts` true while the hind's and the
   calf's are false for `Brain.leapStarts` AND `Brain.boundStarts`: deleting `leapByKind`'s new
   branch fails it.

5. **Rule B -- every use of what was removed was grepped.** `5.132`/`3.336` survive only in the
   archive note, the two comments that name them and the research note's history table.
   `APEX_STUDS` has exactly two readers (`Body.leapApex`, and the type guard above it).
   `MOVE.LEAP_AIR_SECONDS` is now absent for a hind and a calf, and `deer.spec` asserts that.

6. **The Forest Test's own tally no longer claims a hind-only group bounds.** `leaps` on a
   `SCHEDULE.drive` row is a documentation field read only by `ForestTest.driveTally`. The two
   `hindherd` rows (slots 2 and 14, `{hind = 3, calf = 2}`) have no stag in them, so they lose it:
   `leapingGroups` 6 -> 4, animals in bounding groups 32 -> 22, and `forest_line.spec` now also
   asserts every bounding row's party contains a stag -- which is the case that dies if one comes
   back.

7. **Frame 339-F1, opened and described.** `<runs-dir>/339-F1.png`, first-person from the hunter's
   stand over the shotgun barrel, camera at the player's own eye height: a hind (no antlers) **mid
   stride, feet on the ground**, forelegs reaching and hind legs pushing, the dirt road running
   across the left of the frame behind her. She is the frozen subject of `339-freeze.luau`, caught
   **inside the band** at `dz=13.2` doing 28.3 -> 15.1 studs/s. She is crossing and she is not
   bounding.

8. **Frame 339-F2 was NOT OBTAINED, and here is the measured reason.** `339-freeze.luau` is the new
   instrument L-150 asked for and it WORKS at the data level: it caught three separate stags at the
   apex of real in-band bounds and logged the rise -- **5.830**, **5.815** and **6.399** studs at
   `dz` 13.9 / 7.5 / 7.0 (`339-frameread` output, quoted in the report). What it cannot do is hold
   them for a photograph: `Body`'s own step clears `Anchored` on the next frame, the capture round
   trip is ~6 s, and the two stags that WERE near the player's loaded cell had landed by the time
   the shutter opened (`339-F2b.png`: the same stag, standing, all four feet down). A per-frame
   re-anchor was added, but the next two apexes were 3,100 studs from the player's stand, where the
   trimmed world streams nothing in (`339-F2.png` is sky). **Nobody has yet seen the stag's bound at
   speed in a frame.** The claim that he bounds rests on claim 3's numbers, not on a picture.

9. **Her place was left as it was found.** `339-ft-attrs-before.txt` and `339-ft-attrs-after.txt`:
   all 50 `[flags]` rows identical, diff empty (L-101). The FT is back on `:34873` served from
   `driven-hunt-karen`, Connected, in Edit; `driven-hunt-rev` is back at `2cdf3be4`. No checkout was
   ever made in `driven-hunt-karen` (L-014).

10. **Round 1's finding is fixed, and it is fixed the way the Reviewer named.** The 2x/3x case
    pinned `2.925, 8.16, 0.332` -- the MEDIAN of task 334's seven stag bounds -- where
    `docs/research/2026-10-23-deer-road-leap.md` section 9.1 records their MEAN. Both halves now
    read **2.905, 8.14, 0.340**, the research note's own row, and the header says "the MEANS" and
    points at that section. The case still passes and by more: apex ratio 2.000, length 3.086
    (tolerance 0.45), air ratio 1.455 against sqrt(2) (tolerance 0.1).

11. **Gate.** `selene src`, `selene --config tests/selene.toml tests`, `stylua --check src tests`,
    `rojo build`, `tools/studio_mcp.py selftest` and `tools/agents.py selftest` all clean (rule G).

## What could not be verified

- **339-F2** -- see claim 8. `NOT PROVEN`: nobody has seen the stag's bound in a frame.
- The hind's and the calf's **wounded** and **spooked** states were not driven live. They are
  covered by construction rather than by a run: `Brain.boundStarts` and `Brain.leapStarts` are the
  only two things that set `_leapFor`, both read the same `MODEL.LEAP` table, and claim 4's spec
  case asserts both answer false for those kinds.
