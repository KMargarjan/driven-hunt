# Task 306 step B9 -- THE PROOF: T4's twelve cases in Karen's place

Task: 306i
Round: 1
Base: task-306b8-her-place @ 21c9d7bf
Code commit: 6662ee816bcf71f22c4662f2b9102c01f2a4cae1

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

## THE OTHER GUNS AND THE RED DEER at RUN, front of chest (station 4, bench, lane 179, N = 20)

```
    shotgun:SLUG/run/chestfront~boar   20     6     30% 15% - 52%          -0.23    +1.87    -0.04    +1.34    +0.65   6/20           
    lever/run/chestfront~boar          20    11     55% 34% - 74%          -0.74    +1.59    +0.02    +0.70    +0.52  11/20           
    rifle/run/chestfront~reddeer       20    15     75% 53% - 89%          -0.73    +1.40    -0.08    +0.34    +0.68  15/20           
    rifle/run/chest+lead~boar          20    16     80% 58% - 92%          -0.69    +1.10    +0.06    +0.33    -0.30  16/20  CONTROL  
    rifle/run/ahead~boar               20     0      0% 0% - 16%           +0.20       --    -0.04    +0.43       --   0/20  KNOWN-BAD
```
zones: shotgun SLUG body 3 rear 2 chest 1 · lever body 8 chest 3 · reddeer chest 9 body 6.
This session's own CONTROL read 16/20 = 80 % and its KNOWN-BAD 0/20 = 0 % (`306b9-guns.txt`).
Same shape as the rifle: `back` +1.87 (slug), +1.59 (lever), +1.40 (red deer) -- the strike lands
one and a half to two studs BEHIND the aim at a run. 310b, again, and worse for the slower bullets.

## Frames, each opened and described in the report

`306b9-f1-lane2-bench-crop.png` · `306b9-f2-lane2-deck-crop.png` ·
`306b9-f5-deck-rail-crop.png` (design 11.5 item 3: the rail board under the gun, the lane and a
boar on it, the berm beyond) · `306b9-f3-menu-station4-crop.png` and
`306b9-f4-menu-station2-crop.png` (item 5: six paces + MIXED, three distances, and each station's
OWN board -- 21 shots at station 4 against 1 at station 2) · `306b9-f-hitcard-treestand.png`
(the hit card with its red chest dot, taken at 18:29:35 UTC while the 18:28:50 treestand batch was
firing from `Stand2.Deck`).

## Gate

```
[harness] PASS: 34/34 checks @ 6662ee816bcf71f22c4662f2b9102c01f2a4cae1 (clean tree) scope=all
```
`test2` N/A: `agents.needs_two_player(['tools/aim_bench.py'])` answers `[]` -- no changed path is in
`TWO_PLAYER_PATHS`.

## What could not be verified

- design 11.5 item 4 (the isolation frame from TWO clients at two stations): one Play client in
  this session, and design 11.6 already makes T3 the Director's ops step. **NOT OBTAINED.**
- **the real ladder climb: NOT OBTAINED.** `Stand2.Ladder` is a 13.8-stud `TrussPart` at
  (2624, 156.6, -3012). Twice the character was stood 2.5 studs off its face looking at it and W
  was held for 7 s and 8 s with `298key.ps1` after a focusing click: he walked 90 and 100 studs
  across the terrace at Y 153.15 and never left the ground. **The treestand cases in this task were
  reached by placing the character on the deck -- a teleport**, which is design 11.4's own stated
  route ("the stand cases of T4 are reached by the stage block placing the character on the deck
  ... the climb itself is a Director ops step with a screenshot").
- the hit card's own dot could not be read as an instance by the resident (`card=(None,None)` on
  every row); the drawn card shows it, and the frame is the evidence.

## Answered flags

- **ANSWERED: L-136** no spec failed; the harness is 34/34 and no FAIL line is quoted, so the
  named flake (`weapon_shot.spec.luau:1490`) never came up and nothing is called "known".
- **ANSWERED: L-127** every dispatch item is MET / NOT MET / NOT PROVEN in the handover block.
- **ANSWERED: L-123** the CONTROL and KNOWN-BAD cells are numbers in all three tables: bench
  85 % / 0 %, treestand 90 % / 0 %, guns 80 % / 0 %.
- **ANSWERED: verdict-298** the moving-target hit table from both firing positions IS the proof,
  and it is above with its zone split, not a spec.
- **ANSWERED: L-143** `back` is printed on every row and every cell whose `back` and `-along`
  disagree by more than 0.5 studs says so by name.
- **ANSWERED: the ROUTE note on 310b** `TASKS.md` row 310b is still QUEUED; no game code changed
  here, so RUN chest could not have moved, and no >= 90 % is claimed for it.
- **ANSWERED: the ROUTE note on T6 / item 3** T6 is now MET by fired shots, not computed rays
  (280 of them), and design 11.5 item 3 IS obtained (`306b9-f5-deck-rail-crop.png`).
- **ANSWERED: L-124** the ladder climb was the item that could not be made to work; it is an
  `ESCALATE.md` entry and a NOT OBTAINED line, not a workaround reported as a pass.
