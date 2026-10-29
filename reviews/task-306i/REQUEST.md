# Task 306 step B9 -- THE PROOF: T4's twelve cases in Karen's place

Task: 306i
Round: 1
Base: task-306b8-her-place @ 21c9d7bf
Code commit: <FILL>

## PLAN (core quality protocol step 0)

(a) **REAL LIFE.** A running-boar range is shot at a target crossing a 10 m window; ISSF gives the
two timed paces 5.0 s and 2.5 s across it (`Range.CROSSING_SECONDS`, design 6). A man shoots the
animal he can SEE in the window, from the bench or from a raised seat.

(b) **MEASURED NOW.** On `9bbfc71e`, task 310 in her place: rifle chest-centre at a RUN put
**11 of 65** shots in the REAR (`b310-result.json`, queued as **310b**, still QUEUED and NOT
landed -- `TASKS.md` row 310b). Task 306 B8 fired **no shot at all** on the new range
(`b306b8-result.json`: *"no shot was fired by anyone at anything"*), so T6 and design 11.5 item 3
stood NOT PROVEN before this task.

(c) **TARGET** (the dispatch's table, her place, rifle, lane 179): STAND chest >= 95 %, WALK/TROT
chest >= 90 %, RUN chest in chest-or-body >= 90 %, RUN nose >= 80 %, control >= 90 %, known-bad
<= 10 %, treestand within 10 points of the bench.

(d) **LEVER.** This task changes NO game code. The only file is the instrument,
`tools/aim_bench.py`, which did not know the six stations, the two firing positions, the two timed
paces, or that the mask hides an animal outside its station's window.

(e) **HOW MEASURED AFTER.** The same instrument, `python tools/aim_bench.py run ... --station N
--position bench|treestand --distance 179 --shots 20`, with its own CONTROL and KNOWN-BAD cells in
every session.

## What changed

`tools/aim_bench.py` only. No `src/`, no `tests/`.

## What the instrument learned (the only code in this task)

1. `--station 1..6`, `--position bench|treestand`, `--distance` -- `STAGE` moves the character onto
   the BUILT `Mat<n>` or `Stand<n>.Deck` and the downrange sign is measured from those two parts,
   never typed. The server is then asked which pair it measured (`RangeRequest {reset=true}` ->
   the board push), and the board's own `spot=`/`position=`/`dist=` print beside every pick (V298).
2. The two timed paces (`slow`, `fast`) are cells, with floors 5.7 and 11.5 studs/s under their
   7.20 and 14.40 (`Range.CROSSING_SECONDS`); `mixed` is refused, because it draws one of the two
   per run and would print two populations in one row.
3. Six stations share one corridor, so the resident and the gate take the animal NEAREST IN X to
   the camera -- his own lane's -- instead of the folder's first child.
4. **The gate refuses a shot the shooter could not see.** `Range.Mask` sets
   `LocalTransparencyModifier = 1` outside his station's window, so the gate reads the SHIPPED
   mask's own output and waits. Measured: the target is visible over x 2654..2690 at station 4 and
   hidden either side (`306b9-watch.luau`, 24 samples).
5. **A board push is what tells the mask whose animal is whose, and the pick re-releases the trunk**
   -- so the push that follows a pick can carry the trunk the pick destroyed, and the shooter sees
   nothing. Measured here: 3 cells x 3 closed gates, every poll `NOTREADY hidden` at x inside the
   window. The bench republishes with a `reset` while the gate says `hidden`; after that the same
   cell fired 3/3. **This is a game-side defect, not an instrument one** -- queued, see Notes.

## Claims

Each is verifiable from the named file in `<runs-dir>`.

1. **The twelve cases were fired in Karen's place, on the new range, from both firing positions.**
   `306b9-bench4.txt` (station 4, bench, lane 179) and `306b9-stand2.txt` (station 2, treestand,
   lane 179 -> 193 from the deck). Each line `[aim_bench] the server's own answer:` carries the
   SERVER's `spot=` and `position=`; the bench claims neither.
2. **Every shot is a real click through the live `Input.fire`** -- `aim_bench.py ray`, part 2
   (`306b9-ray.txt`): `DHClaimWhy` nil with no click, set after one.
3. **Each case carries the four pieces of evidence**: the aim (`aim=`), the server's zone and local
   offset (`zone=`, `ring[local=]`), the client's mark (the hit card, frame
   `306b9-f-hitcard-treestand.png`), and the shooter's-eye frame.
4. **Control and known-bad, in both sessions** (L-123): bench control 17/20 = 85 %, known-bad
   0/20 = 0 %.
5. **`back` is printed on every row** (L-143) and the table names every row where `back` and
   `-along` disagree by more than 0.5 studs.
6. **Three targets are NOT MET and one of them is the known, unlanded 310b** -- see the table in
   the report. No claim of >= 90 % is made for RUN chest.
7. `python tools/aim_bench.py selftest`, `python tools/studio_mcp.py selftest` and
   `python tools/agents.py selftest` pass (rule G).

## THE TWELVE CASES (her place, rifle, lane 179; N = 20 per cell)

| case | bench (station 4) | zones | treestand (station 2) | zones | gap |
|---|---|---|---|---|---|
| rifle/stand/chest | 20/20 = 100% | chest 20 | 20/20 = 100% | chest 20 | +0 |
| rifle/walk/chest | 20/20 = 100% | chest 20 | 20/20 = 100% | chest 20 | +0 |
| rifle/trot/chest | 16/20 = 80% | body 8 chest 8 | 14/20 = 70% | body 9 chest 5 | -10 |
| rifle/run/chest | 17/20 = 85% | rear 9 body 8 | 15/20 = 75% | rear 8 body 7 | -10 |
| rifle/slow/chest | 20/20 = 100% | chest 18 body 2 | 20/20 = 100% | chest 15 body 5 | +0 |
| rifle/fast/chest | 18/20 = 90% | body 15 chest 3 | 18/20 = 90% | body 18 | +0 |
| rifle/run/nose | 16/20 = 80% | chest 15 head 1 | 15/20 = 75% | chest 13 body 1 head 1 | -5 |
| rifle/run/chest+lead | 17/20 = 85% | chest 16 head 1 | 18/20 = 90% | chest 17 head 1 | +5 |
| rifle/run/ahead | 0/20 = 0% | - | 0/20 = 0% | - | +0 |

`back` (the strike's rearward offset from the aim point, in the ring's own frame) is printed on
every row of both files and the table names the rows where it and `-along` disagree by > 0.5 studs:
RUN chest `back +1.06` (bench) and `+1.43` (deck), RUN nose `+1.23` / `+1.68`. The strike is a
stud-and-a-half BEHIND the aim at a run -- which is 310b, below.

**Against the dispatch's targets:** STAND 100 % MET (>= 95). WALK 100 %, TROT 80 % / 70 % **NOT
MET** (>= 90). RUN chest in chest-or-body **8/20 = 40 % bench, 7/20 = 35 % deck -- NOT MET**
(>= 90): the rest is `rear`. RUN nose 80 % MET bench, 75 % deck (within 10). Control 85 % bench
(NOT MET, >= 90) / 90 % deck MET. Known-bad 0 % MET (<= 10). Treestand within 10 points of the
bench on every case.

**RUN chest is 310b, and 310b has NOT landed** (`TASKS.md` row 310b: `rear 11 of 65` on
`9bbfc71e`, QUEUED). This task changed no game code, so it could not have moved: 17 of 20 rear-or-
body here is the same defect at a longer lane. No claim is made that it is fixed.

## What could not be verified

- design 11.5 item 4 (the isolation frame from TWO clients at two stations): one Play client in
  this session. NOT OBTAINED.
- the hit card's own dot could not be read as an instance by the resident (`card=(None,None)` on
  every row); the drawn card shows it, and the frame is the evidence.
