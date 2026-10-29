# Task 310 -- the running chest shot: two rigs, one build, one answer

Task: 310
Round: 1
Base: 9bbfc71e
Code commit: 068a6103a1eda6f964ba55dcaf277a66427944dd

## THE ONE OUTCOME (L-155)

**A rifle chest-centre shot at a running boar must land in the chest or the body, not the rear.**
Measured on main 9bbfc71e, in Karen's Forest Test, in ONE session: it lands in the **rear about a
quarter of the time**, and the bench's own headline column hides it.

## PLAN

### (a) REAL LIFE
A .416 over 35 m reaches the animal in ~0.05 s; a boar at 24 studs/s (6.7 m/s) moves **0.33 m** in
that time, so a chest-centre shot with no lead lands 0.33 m behind the aim -- in the body just
behind the shoulder, not in the heart. The game already carries that figure: the range board prints
`LEAD BALLISTIC 1.18 studs`, and 1.18 studs x `Report.CONFIG.METRES_PER_STUD` (0.28) = **0.33 m**.
Same number, so the game's physics is not in dispute.

### (b) MEASURED NOW -- one session, one build, both rigs side by side
All readings are from Play in placeId 130094961655666 on 2026-10-29 08:58-09:12 UTC, Rojo
`localhost:34873`, client probe `FLIGHT_REWIND_BASE_SECONDS=0.25` and `placeId=130094961655666`
printed in each rig's own header (L-139), flags `RANGE` / `AIM_REWIND` / `ZONES_FOLLOW_GAIT` all
true, **no `DHFlag_*` attribute written or cleared** (rule K).

| rig | file | click transport | N | hits | zones | mean along | mean pastgap |
|---|---|---|---|---|---|---|---|
| aim bench | `<runs-dir>/310/bench-A.txt` | StudioMCP, ~0 s after the gate | 22 | **22 (100 %)** | chest 5 body 11 **rear 5** head 1 | -0.48 | -0.02 |
| bench rig, real click | `<runs-dir>/310/cycle1-real-noreload.txt` | `click.ps1`, **1.68 s** after the gate | 21 | **20 (95 %)** | chest 1 body 13 **rear 6** | -0.93 | -0.01 |
| CONTROL chest+lead (L-123) | `310/bench-A.txt` | StudioMCP | 22 | 20 (91 %) | chest 15 body 5 | -1.48 | +0.30 |
| KNOWN-BAD nose + 1 body length (L-123) | `310/bench-A.txt` | StudioMCP | 22 | **0 (0 %)** | -- | -2.09 | +0.17 |

Four candidate causes of the Playtester's 2-in-10, each **eliminated by measurement in this session**:

1. *the click transport* -- `<runs-dir>/310/realclick.py` runs the bench's own rig and gate with the
   Playtester's `click.ps1`: **20/21 hits**, mean gate-to-click **1.680 s** (StudioMCP's is ~0). The
   1.68 s is 35 studs of travel and costs nothing, because the held look is level-triggered and
   keeps tracking (`src/client/Camera/TestLook.luau`).
2. *the tracked instance* -- `310/children.luau`: `RangeTargets` has **one** child, unanchored, with
   chest parts. The Playtester's `GetChildren()[1]` and the bench's "first unanchored" are the same
   instance.
3. *the aim point* -- `310/aimdiff.luau` computes both rigs' chest centres on the same 12 frames:
   they differ by **0.09 studs**, on every frame.
4. *the bolt cycle / no reload* -- the bench presses `R` between shots and the Playtester did not.
   Row 2 above is **no-reload** and still reads 20/21; a swallowed click produces no row at all
   (`answered=False`), never a miss.

**THE DISPATCH'S PREMISE IS REFUTED, and here is what is wrong instead.** Both rigs measure the same
geometry, so neither is "not measuring what Karen's eye and finger do". The disagreement is a column
**inside `tools/aim_bench.py`**: the table prints `along` and `ring-z` side by side as if they were
comparable, and **they have different origins** -- `along` is the strike's offset from the AIM POINT
along travel, `ring-z` is the strike's coordinate from the TRUNK CENTRE. In
`<runs-dir>/309a/after-C.txt`, RUN row 8, `along=-0.778` sits beside `ring local=0.56|0.44|1.42`;
`310/zonemap.luau` reads the aimed chest centre at local z **-0.41**, so that strike is **1.83
studs** behind the aim, not 0.78. That is how "30/30, mean along -0.52" read as healthy while the
same table's own zone split said `rear 5`.

`310/zonemap.luau`, the running boar, in its own frame: chest spans local z **[-1.38 .. +0.36]**
(1.74 studs), aimed chest centre **-0.41**, body `[-1.56 .. +1.21]`, rear starts **+1.14**. So only
**0.77 studs** of chest lie behind the aim point while real life asks **1.18 studs** of lead: a
no-lead chest shot *must* leave the chest, and anything past +1.14 is credited REAR.

### (c) TARGET
Every bench row carries **`aimz`**, the aim point's own body-axis coordinate in the animal's frame on
the fire frame, so `back = ringz - aimz` is the strike's rearward offset from the aim **in the ring's
own frame** -- directly comparable with `-along`. A cell where the two disagree by more than
**0.5 studs** on the same shot prints `OFFSET DISAGREEMENT` instead of averaging it away.
0.5 studs because the chest's half-span is **0.87 studs** (measured above): a disagreement above
0.5 can move a shot's verdict from chest to body.

### (d) LEVER (grep output, the code that WRITES it)

```
tools/aim_bench.py:858:      local along, up, across = 0 / 0, 0 / 0, 0 / 0
tools/aim_bench.py:860:        local gap = impact - aim
tools/aim_bench.py:861:        along = gap:Dot(dir)
tools/aim_bench.py:318:            "along": mean([r.get("along") for r in rows]),
tools/aim_bench.py:412:        % ("cell", "N", "hits", "rate", "95% interval", "along", "up", "pastgap", "ring-z", "ring", "role")
```

The frame is the right one: `src/server/HitLog/init.luau` (`recordHit`, the `writeTrace` call)
divides the ring's offset down by `frameOf(part, report)` = `report.targetCFrame`, the trunk's CFrame
at the hit's instant (`frameOf`, same file), and `pastgap` is -0.02, so the fire-frame root CFrame
the bench reads and that frame coincide.

### (e) HOW IT IS MEASURED AFTER
The same probe as (b): `python tools/aim_bench.py run rifle/run/chest --shots N` in the Forest Test.

## STEP 1 -- KAREN'S CASE ON HER PATH
Reproduced, in her place, on her build: rows 1 and 2 of the (b) table. Her sentence as numbers --
rifle, RUN, chest centre, no lead, 103-138 studs: **43 shots, 42 on the animal, 6 in the chest,
24 in the body, 11 in the rear, 1 in the head.** The mark lands behind the chest.

## STEP 2 -- ITERATION (three cycles, same probe before and after)

| cycle | change | N | hits | zones | mean along | mean **back** | OFFSET DISAGREEMENT | distance to target |
|---|---|---|---|---|---|---|---|---|
| 1 (before) | none -- main 9bbfc71e | 22 | 22 | chest 5 body 11 **rear 5** head 1 | -0.48 | **not measurable** | not printed | the table could not say where the strike sat relative to the aim |
| 2 (after) | `aimz` per row, `back`, the disagreement rule | 20 | 20 | chest 5 body 13 rear 2 | -0.83 | **+0.72** | **3 of 20** | target met: the column reads live and the rule fires |
| 2 CONTROL (same table) | chest + `Ballistics.leadStuds` | 22 | 22 | **chest 20** body 2 | -1.01 | **+1.01** | 4 of 22 | the lead aim puts the strike at ring-z **-0.58**, deep inside the chest |
| 3 (after, 2nd sample) | real `click.ps1` transport, no reload | 22 | **22** | body 19 rear 3 | -0.86 | `--` (this rig reads no ring) | 0 of 0 | repeatability confirmed; see the finding below |

Files: cycle 1 `<runs-dir>/310/bench-A.txt`; cycle 2 `310/cycle2-back.txt`; cycle 3
`310/cycle3-real-back.txt` (summarised from the resident's own rows by `310/summ.py`).

**What the new column shows, in one line.** The aimed chest centre sits at ring-z **-0.41** and the
strike lands **+0.72 studs** behind it, i.e. at ring-z **+0.31** -- and the chest's back edge is at
**+0.36**. The no-lead chest shot lands **0.05 studs inside the chest's back edge**, so the zone it
is credited to is a coin flip between chest and body. With the 1.18-stud lead the board already
prints, the strike sits at ring-z -0.58, and 20 of 22 are credited chest.

**Found in cycle 3, and it is why the coin flip is a coin flip:** `aimz` -- the drawn chest centre's
own body-axis coordinate -- swings between **-0.52 and +0.78** across the 22 rows while the boar
runs (`ZONES_FOLLOW_GAIT` is on). The chest zone's own centre moves ~1.3 studs along the body over
a gait cycle, which is 75 % of the chest's whole length. Queued as a note, not fixed here: it is a
`src/server/Boar/` zone question and this task is one task.

## THE GATE

```
[harness] PASS: 34/34 checks @ 068a6103a1eda6f964ba55dcaf277a66427944dd (clean tree) scope=all
```

Two players: **N/A**. The only code file is `tools/aim_bench.py`, and `tools/` is not in
`TWO_PLAYER_PATHS` (Director decision 2026-10-03). `python -c "agents.needs_two_player([...])"`
answers `[]` for this change's paths.

## CLAIMS

1. The game's physics is right and needs no change: the required lead is 1.18 studs = 0.33 m, which
   is real life's figure. Verify: `310/bench-A.txt`'s CONTROL cell (chest + `Ballistics.leadStuds`)
   reads **chest 15 / body 5** out of 20 hits, against chest 5 / body 11 / rear 5 for the same aim
   with no lead -- the game rewards the real-life aim.
2. The Playtester's 2-in-10 does not reproduce. Verify: the summary line of
   `310/cycle1-real-noreload.txt`, 20/21 on her own click transport, and the four eliminations in (b).
3. The bench's `along` and `ring-z` columns have different origins and are printed side by side.
   Verify: `309a/after-C.txt` RUN row 8 (`along=-0.778`, `ring local=0.56|0.44|1.42`) against
   `310/zonemap.luau`'s aimed chest centre -0.41.
4. `tools/aim_bench.py` records `aimz` per row and prints `back` (= ringz - aimz) beside `along`,
   with an `OFFSET DISAGREEMENT` line above 0.5 studs. Verify: `tools/aim_bench.py`'s
   `RESIDENT` (the `aimz` write), `summarise` (`back`, `backdisagree`), `render` (the column and the
   line), and `python tools/aim_bench.py selftest`.
5. No `DHFlag_*` attribute was written or cleared, in any run (rule K). Verify: every rig prints the
   flag row it read; nothing under `310/` calls `flags.py`.

## WHAT I COULD NOT VERIFY

- **Why the Playtester's own 10-shot sample read 2 hits.** Four causes eliminated by measurement in
  one session; the fifth possibility -- a 10-shot sample against 43 -- is not something this session
  can settle, and I do not claim it. Her sample's ZONE finding (the mark lands behind the chest) is
  confirmed, three times over.
