# Task 309 -- real-life hit rates, measured with the bench

Task: 309
Round: 1
Base: 8e5c0f76
Code commit: eb4be65f00512ba1e24542edd5f76c53533e50be

Harness, full one-player run on the clean tree at that commit:

    [harness] PASS: 34/34 checks @ eb4be65f00512ba1e24542edd5f76c53533e50be (clean tree) scope=all

`test2` is **N/A**: the change touches `src/server/Weapon/init.luau`,
`src/shared/Shotgun/init.luau` and `tools/aim_bench.py`, and none of them is in
`TWO_PLAYER_PATHS` (no match, no drive, no tie, no teams).

## PLAN (core quality protocol step 0)

* **(a) REAL LIFE.** At 35 m a .416's group is 1-2 cm, so a standing boar shot at the chest centre is
  hit every time, and a running one (6.7 m/s, ~0.05 s of flight) is hit in the body a third of a
  metre behind the point of aim. Nothing about the gun should make a 35 m chest shot a coin toss.
* **(b) MEASURED NOW** (the bench, Karen's Forest Test, at `8e5c0f76`; `<runs-dir>/309/before-A.txt`,
  `diag-A.txt`, `d6.txt`): rifle STAND chest **29/30 = 97 %**; RUN chest centre **11/66 = 17 %**;
  RUN chest + `Ballistics.leadStuds` (the CONTROL) **40/66 = 61 %**.
* **(c) TARGET.** The dispatch's: STAND chest >= 97 %, RUN chest >= 80 %, CONTROL >= 95 %,
  a body length ahead <= 5 %.
* **(d) LEVER.** `FLIGHT_REWIND_BASE_SECONDS` in `src/shared/Shotgun/init.luau`, read by
  `Weapon.rewindFor` and by nothing else:

      $ grep -rn "FLIGHT_REWIND_BASE_SECONDS" src/
      src/shared/Shotgun/init.luau:678:	FLIGHT_REWIND_BASE_SECONDS = 0.205,
      src/server/Weapon/init.luau:581:		cfg.FLIGHT_REWIND_BASE_SECONDS + seconds * cfg.FLIGHT_CATCHUP_PING_FACTOR,

* **(e) HOW IT IS MEASURED AFTER.** The same instrument on the same cells in the same place:
  `python tools/aim_bench.py run <cell> --shots 30 --place 130094961655666`.

## What changed, and why

**One game change.** `FLIGHT_REWIND_BASE_SECONDS` 0.18 -> **0.205**. 0.18 was measured in DEV (one
boar at 2.55 studs/s, a quiet server). The same two-sided correlation run in **Karen's place** -- the
range target at 22.5 studs/s, 130 studs, 60 animals in the world -- reads the client drawing the
animal **0.2057 s** in the past (sd 0.0181, p50 0.2048, 93 client frames against 238 server samples,
match residual 0.233 studs; the trunk beside it reads 0.2106 s, residual 0.154). So 0.18
under-rewound by 0.0257 s = **0.47 studs mean, 0.95 at p90** at a run.

**Two instruments**, which is how the diagnosis was possible at all:
* `aim_bench` rows now print `across`, `aim` and `impact`. That is what showed every missed shot
  landing on the range wall at `z = -3350.00`.
* `Weapon`'s Studio-only rewind trail counts its exits **per reason**; `plain` was one number for
  five different ones (V293b).

## Claims

1. **The fix is measured, not guessed, and the before and after are the same instrument in the same
   place.** BEFORE at `8e5c0f76`, AFTER at the code commit, bench `--shots 30`, Karen's Forest Test:

   | cell | BEFORE (`8e5c0f76`) | AFTER (code commit) | z | target |
   |---|---|---|---|---|
   | `rifle/run/chest~boar` | 11/66 = **17 %** | 17/30 = **57 %** | **4.00**, p < 0.0001 | >= 80 % **NOT MET** |
   | `rifle/run/chest+lead~boar` (CONTROL) | 40/66 = **61 %** | 55/60 = **92 %** | **4.04**, p < 0.0001 | >= 95 % **NOT MET** |
   | `rifle/run/ahead~boar` (KNOWN-BAD) | 0/6 = 0 % | 4/60 = **7 %** | -- | <= 5 % **NOT MET** |
   | `rifle/run/chestfront~boar` | not run before | 16/30 = **53 %** | -- | (not a dispatch target) |
   | `rifle/stand/chest~boar` | 29/30 = **97 %** | 27/30 = **90 %** | 1.04, p = 0.30 | >= 97 % **NOT MET** |

   Every AFTER table's own `Self-check:` line reads *"CONTROL and KNOWN-BAD both read as they must"*,
   and no table is marked `INSTRUMENT SUSPECT`. *Verify:* `reviews/task-309/bench-before-A.txt`,
   `bench-diag-A.txt`, `bench-d6.txt` (before) and `bench-after-A.txt`, `bench-after-B.txt` (after);
   each file's header prints its own `placeId=130094961655666` and the place's flags, which are the
   same thirteen in all five.
2. **The stand case is not proven to have regressed, and I am not claiming it improved.** 29/30 before
   against 27/30 after is z = 1.04, p = 0.30 -- noise at this N, not a reading. What it does mean is
   that **the >= 97 % stand target is not met by the AFTER measurement**, and that is stated as a
   failure above rather than rounded away. *Verify:* `bench-after-B.txt`, cell
   `rifle/stand/chest~boar`; `bench-before-A.txt` for the before.
3. **Four of the five causes the dispatch named are refuted in numbers, and each by its own probe.**
   Slug cone 0.16 deg FULL = **0.18 studs** at 130 (`Shotgun.CONFIG.SPREAD_FULL_DEG`, closed form);
   the bench's own aim error, camera against its own held point, **1.24 px mean / 4.68 max** = 0.29 /
   1.08 studs (`<runs-dir>/309/px2.luau`); the gait rig, `ZoneChest` moving **0.154 studs mean /
   0.227 worst** in the trunk's own frame over one rewind window (`<runs-dir>/309/gait.luau`); the
   gun's zero, **+0.03 studs** over the line of sight across 109-140 studs (`ZERO_STUDS` 714,
   `GRAVITY_SCALE` 0.12). The fifth -- the rewind's residual -- is the one that was ruled IN and
   fixed. *Verify:* the five probe files, and the table in
   `docs/research/2026-10-28-lag-compensation.md` under "What this does NOT explain".
4. **No box was widened.** `git diff 8e5c0f76..HEAD -- src/server/Boar/` is empty: not one zone
   extent, offset or clamp changed. The rate moved by making the server test the animal WHERE THE
   CLIENT DREW IT, which is the opposite of widening a box into air (rule L).
5. **The per-reason counters work and prove the rewind runs.** Over 18 bench shots the trail moved
   `plain +23 cast +25 hit +6`, and one of its lines read
   `rewind=0.185 cands=1 back=4.48 spd=24.08 eff=0.186 hit=false` -- the animal WAS translated 4.48
   studs back and the cast still missed. *Verify:* `<runs-dir>/309/rw-before.txt` against the line
   printed after the run; `trail()` in `src/server/Weapon/init.luau`.
6. **The change is inert outside a rewinding server.** `Weapon.rewindFor` returns 0 when
   `rewindPolicy == false` or `AIM_REWIND` is off, before the constant is read at all.
   *Verify:* `Weapon.rewindFor`, and `tests/server/weapon_rewind.spec.luau`, which asserts against
   `CONFIG.FLIGHT_REWIND_BASE_SECONDS` symbolically and so holds at either value.
7. **Rule G.** `python tools/studio_mcp.py selftest`, `tools/agents.py selftest`,
   `tools/aim_bench.py selftest` and `tools/privacy_scan.py selftest` all pass at HEAD; no spec file
   was added or moved, so `SCOPE_SPECS` is unchanged.

## What I could NOT verify, and what is NOT done

* **Four of the dispatch's targets are not met** (claim 1) and the remaining cause is **unnamed**.
  The one thing the AFTER tables say about it: a chest-centre shot at a run now lands in `rear`
  12 times out of 17 hits, where the whole ballistic lead at 130 studs is 1.15 studs -- so roughly a
  stud of rearward displacement is still unaccounted for, on top of the lead the shooter does owe.
  `ESCALATE.md` (2026-10-29, task 309) carries it, with the two instruments the next round needs.
* **The shotgun slug, the lever and the red deer were not run at all.** L-141 says each of those
  cells' CONTROL and KNOWN-BAD rows must first be proved to use that weapon's own ballistics, and
  there was no sense measuring four more weapons against a cause nobody has named.
* **The reported impact and the scored zone disagree.** On the CONTROL cell the bench reads
  `along` within a stud of the chest while the server scores `zone = rear` on most of those same
  shots. One of the two is wrong. `ServerStorage.DHLastHits`, the ring that would settle it with a
  local offset, **is empty for range shots** (task 307 found the same).
* **`cardu`/`cardv` read `nil` on every row**, as they have on all 900+ bench rows so far (307a(a)).
  So nothing here says anything about what Karen's HUD card draws; the proof is zone-and-ray only.
* **No screenshot.** Nothing visual changed; the deliverable is a counted table.
