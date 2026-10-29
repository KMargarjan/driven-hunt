# Task 309 -- real-life hit rates, measured with the bench

Task: 309
Round: 2
Base: 8e5c0f76
Code commit: ea7095033dffc9a77600eb5a61ef5dc491982118

Harness, full one-player run on the clean tree at that commit:

    [harness] PASS: 34/34 checks @ ea7095033dffc9a77600eb5a61ef5dc491982118 (clean tree) scope=all

The last commit that changed `src/`, `tests/` or `tools/` is `eb4be65f`, and that one also ran clean
(`[harness] PASS: 34/34 checks @ eb4be65f00512ba1e24542edd5f76c53533e50be (clean tree) scope=all`).
`Code commit:` names the LATER one because `docs/research/2026-10-28-lag-compensation.md` changed in
`ea709503` and a research note is not on the merge gate's paperwork list -- naming the later commit
keeps the bound strict, which is what git workflow step 4 says to do.

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
   place -- BUT ONE BEFORE RUN IS NOT ADMISSIBLE AND IS DROPPED** (round 1, finding 1; the Reviewer
   was right and the fault was mine). `bench-before-A.txt`'s CONTROL cell reads **14/30 = 47 %**,
   under `aim_bench.CONTROL_MIN_RATE` (0.50), so by the bench's own rule that whole run is
   `INSTRUMENT SUSPECT` and no cell in it is a measurement. The note never printed only because my
   595-second shell cap killed the process inside the KNOWN-BAD cell, before `summarise` ran --
   which is also why `bench-before-A.txt` and `bench-diag-A.txt` carry **no summary table at all**.
   Both facts are disclosed here rather than left to be found. The admissible BEFORE is therefore
   `bench-diag-A.txt` (CONTROL 21/30 = 70 %, over the floor) plus `bench-d6.txt` (complete,
   self-checked, CONTROL 5/6 = 83 %, KNOWN-BAD 0/6):

   | cell | BEFORE `8e5c0f76` (diag-A + d6) | AFTER `eb4be65f` (after-A + after-B) | z | dispatch target |
   |---|---|---|---|---|
   | `rifle/run/chest~boar` | 5/36 = **14 %** | 17/30 = **57 %** | **3.67**, p = 0.0002 | >= 80 % **NOT MET** |
   | `rifle/run/chest+lead~boar` (CONTROL) | 26/36 = **72 %** | 55/60 = **92 %** | **2.54**, p = 0.011 | >= 95 % **NOT MET** |
   | `rifle/run/ahead~boar` (KNOWN-BAD) | 0/6 = 0 % | 4/60 = **7 %** | -- | <= 5 % **NOT MET** |
   | `rifle/run/chestfront~boar` | not run before | 16/30 = **53 %** | -- | (not a dispatch target) |
   | `rifle/stand/chest~boar` | 29/30 = **97 %** (before-A, SUSPECT RUN -- see below) | 27/30 = **90 %** | 1.04, p = 0.30 | >= 97 % **NOT MET** |

   **The dropped run, stated and not hidden:** `bench-before-A.txt` read chest 6/30 = 20 %, CONTROL
   14/30 = 47 %, stand 29/30 = 97 %. Its chest figure agrees with the admissible runs and including
   it would only make the BEFORE look worse (11/66 = 17 %), so dropping it is the conservative
   direction for claim 1 and the direction of the move survives either way. **The one number that
   has no admissible BEFORE at all is the STAND cell**, which only that run measured: so claim 2 now
   rests on the AFTER reading alone, and the request says so there.

   *Verify:* the five `reviews/task-309/bench-*.txt` files -- the per-cell rates above are the
   `hit=True` counts in their own rows, and `bench-after-A.txt` / `bench-after-B.txt` / `bench-d6.txt`
   each end in a summary table whose `Self-check:` line reads *"CONTROL and KNOWN-BAD both read as
   they must"* with no `INSTRUMENT SUSPECT` line. Every file's header prints its own
   `placeId=130094961655666` and the same thirteen `DHFlag_*`.
2. **The stand case: the only BEFORE reading comes from the run claim 1 just ruled inadmissible, so
   there is no admissible before/after pair for it.** The AFTER reading is **27/30 = 90 %**, which
   does not meet the >= 97 % target, and that is stated as a failure. I am not claiming the stand
   case improved and I cannot prove from admissible evidence that it did not regress -- 29/30
   against 27/30 is z = 1.04 (p = 0.30) if the suspect run is admitted at all. *Verify:*
   `bench-after-B.txt`, cell `rifle/stand/chest~boar`.
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
5. **WITHDRAWN (round 1, finding 2, and the Reviewer is right).** I claimed the per-reason counters
   were proven; they are not. Every token I quoted -- `plain +23 cast +25 hit +6` and
   `rewind=0.185 cands=1 back=4.48 spd=24.08 eff=0.186 hit=false` -- comes from counters and from an
   `extra` string that this task did not touch, so the quoted evidence survives deleting
   `rewindTrail.why` byte for byte, and that `rewind=0.185` line was read at base 0.18, BEFORE the
   constant under test. **The new `counts[...]` field has never been read back**, and `counts[`
   appears nowhere in this repo. So: the counters are shipped **UNVERIFIED**, carried as such here
   and queued as 309a(a) with the exact reading needed to close it
   (`counts[no-roots=N rewind-zero=N rewound=N]` out of `ServerStorage.DH305Rewind` on a run at this
   commit). What claim 5 said about the REWIND itself still stands on untouched instrumentation: the
   trail did move `cast +25 hit +6` over 18 bench shots and did print a line in which the animal was
   translated 4.48 studs back and the cast still missed -- but that is the pre-task trail speaking,
   not this task's addition.
6. **The change is inert outside a rewinding server.** `Weapon.rewindFor` returns 0 when
   `rewindPolicy == false` or `AIM_REWIND` is off, before the constant is read at all.
   *Verify:* `Weapon.rewindFor`, and `tests/server/weapon_rewind.spec.luau`, which asserts against
   `CONFIG.FLIGHT_REWIND_BASE_SECONDS` symbolically and so holds at either value.
7. **Rule G.** `python tools/studio_mcp.py selftest`, `tools/agents.py selftest`,
   `tools/aim_bench.py selftest` and `tools/privacy_scan.py selftest` all pass at HEAD; no spec file
   was added or moved, so `SCOPE_SPECS` is unchanged.

## What I could NOT verify, and what is NOT done

* **ROUND 1'S OTHER ELEVEN FINDINGS ARE NOTES AND ARE QUEUED, NOT FIXED HERE** (CLAUDE.md rule 10:
  notes under a PASS go into `TASKS.md`). Three of them are factual corrections I would otherwise
  have made, and they are written out verbatim in `TASKS.md` row 309a so the next task applies them
  rather than rediscovering them: (i) the rifle's own `SPREAD_FULL_DEG` is `{ Slug = 0 }`, not
  `Shotgun`'s 0.16 deg, so that row of the error budget should read **0 studs** and be dropped
  (the refutation is unaffected and more conservative, not less); (ii) `0.0257 x 22.5 = 0.58` studs
  against the bare 0.18, and **0.47** is against the effective 0.185 (base + 0.005 ping) -- the
  request and the note should pick one base and say which; (iii) `Weapon.rewindFor`'s and
  `Weapon/Rewind.luau`'s headers still name the superseded DEV 0.180. (iii) is a `src/` edit and
  fixing it in this round would move the code commit and re-open the whole gate, which is exactly
  what rule 10 says not to do for a note.
* **Four of the dispatch's targets are not met** (claim 1) and the remaining cause is **unnamed**.
  The one thing the AFTER tables say about it: a chest-centre shot at a run now lands in `rear`
  12 times out of 17 hits, where the whole ballistic lead at 130 studs is 1.15 studs -- so roughly a
  stud of rearward displacement is still unaccounted for, on top of the lead the shooter does owe.
  `ESCALATE.md` (2026-10-29, task 309) carries it, with the two instruments the next round needs.
* **The shotgun slug, the lever and the red deer were not run at all.** L-141 says each of those
  cells' CONTROL and KNOWN-BAD rows must first be proved to use that weapon's own ballistics, and
  there was no sense measuring four more weapons against a cause nobody has named.
* **The reported impact and the scored zone disagree.** On the CONTROL cell the bench reads
  `along` within a stud of the chest while the server scores `zone = rear` on **8 of those 28
  shots** (`bench-after-B.txt`: `body 14 rear 8 chest 6`). One of the two is wrong. `ServerStorage.DHLastHits`, the ring that would settle it with a
  local offset, **is empty for range shots** (task 307 found the same).
* **`cardu`/`cardv` read `nil` on every row**, as they have on all 900+ bench rows so far (307a(a)).
  So nothing here says anything about what Karen's HUD card draws; the proof is zone-and-ray only.
* **No screenshot.** Nothing visual changed; the deliverable is a counted table.
