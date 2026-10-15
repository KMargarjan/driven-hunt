# Task 189: the right hand was drawn end-for-end, and the rifle shoots flat to 200 m

Task: 189
Round: 2
Base: 34b4ae0 (main, #171 merged: task 188)
Code commit: 8663c97ec92da740b6115607984512bf5d45679b

Harness, full runs on the clean tree, twice (`.agent-logs/task189-r2-test3.log`, `-test4.log`):

```
[harness] PASS: 33/33 checks @ 8663c97ec92da740b6115607984512bf5d45679b (clean tree) scope=all
[harness] PASS: 33/33 checks @ 8663c97ec92da740b6115607984512bf5d45679b (clean tree) scope=all
```

`test2` is **N/A**: no `TWO_PLAYER_PATHS` file is touched.

## Round 1's two findings, and what was done

**Finding 1 was right and it was the serious one.** `Viewmodel.poseHands` draws the right glove as
`base * align` for **whatever weapon is in hand**, and the horn branch does the same -- so flipping
`HandAssets.AXES.RIGHT` turns the shotgun's three right-hand poses and the horn's two end-for-end as
well, and round 1 re-solved only the rifle's four. Claims 1-3 below.

**Finding 2 was right and mechanical:** the research note landed in a commit after the tested one.
The gate was re-run twice at a commit that contains everything, and the two lines above name it.

All seven non-blocking notes are done as well (claim 11).

## What changed, and why

Karen, 2026-10-15, after playing task 188: *"hadn is oposit now reload with ending of arm not
fingers / also are you sure we have right rifle aiming? / seems a bit odd when stands it has to be
acurat 100% 100m 150m / when run I need a bit aim in front to be able hit in head or body does this
implemented ?"*

Note: `docs/research/2026-10-15-hand-axis-and-flat-trajectory.md`.

## Claims

1. **THE FIVE RIGHT HANDS THIS TASK DID NOT RE-SOLVE DO NOT MOVE, and the arithmetic is exact.**
   The shotgun's `carry`/`aim`/`reload` and the horn's `carry`/`blow` right hands are hands Karen has
   accepted, so they are **re-expressed, not re-solved**: `pose_new = pose_old * (align_old *
   align_new^-1)`. `align` is a pure rotation about the hand's own centre, so the positions do not
   move at all and only the three angles change; the transport is **149.88 degrees** and reproduces
   the drawn CFrame to **2.2e-16**.
   *Verify:* the note's section 3a, which lists all five before and after;
   `src/shared/Viewmodel/poses.json`.

2. **AND IT IS PINNED, against numbers from the build Karen played.** Three cases hold where those
   five poses put the glove's two ends in the gun's own frame. The expected vectors were computed
   from task 188's pose numbers composed with task 188's alignment, so they are an outside constant
   and not a copy of the file the case reads; flip the axis again without re-expressing and every
   one of them moves about 150 degrees.
   *Verify:* `tests/server/viewmodel_poses.spec.luau`, the describe *the shotgun's and the horn's
   right hand did not move (task 189)*; the harness's `task189 shotgun ...` / `task189 horn ...`
   notes.

3. **LOOKED AT, NOT ONLY COMPUTED (rule 5).** A first-person frame of the shotgun after the
   transport, against one taken before any change in this task:
   `.screenshots/t189-after-shotgun.png` against `t189-dev-start.png` -- the same fist and the same
   cuff in the same places.

4. **THE RIGHT GLOVE'S AXIS WAS MEASURED IN THE WRONG PLACE, AND THAT IS THE WHOLE OF "the hand is
   opposite".** `HandAssets.AXES.RIGHT.fingers` was task 188's measurement of the published glove's
   **glTF**; the MeshPart Roblox draws is flipped in X against that file, so
   `Camera.Viewmodel.align` pointed its +X at the **cuff**.
   *Verify:* `src/shared/HandAssets.luau`, `AXES` and the block above it. `Viewmodel.align` is
   unchanged and still the only reader.

5. **IT WAS SETTLED IN THE RUNNING GAME, NOT IN A FILE, AND TWICE.** Neon marker balls at the drawn
   part's own +0.36 X and -0.36 X, in a solo Play session with the rifle in hand: the +X ball sits
   on the brown fist, the -X ball on the olive cuff.
   *Verify:* `.screenshots/t189-axes2.png` and `t189-axes3.png` (two different poses), and
   `t189-nohandright.png`, which hides `HandRight` and shows the brown fist AND the olive sleeve
   disappear together -- so they are one part and not the character's own arm. Method: note,
   section 3.

6. **MEASURED AS DRAWN, TASK 188's RIFLE POSES HELD THE GUN WITH THE CUFF.** At the bolt the cuff
   was **0.212** studs from the knob and the fingertip **0.495**, with the wrist LEADING the hand by
   0.538 in Z; at the hip the grip point was **0.2036** off the wrist axis and **+0.2591** along it
   -- outside task 188's own bounds (0.0719 and 0.111), which its spec passed because every number
   in it was computed in the same wrong frame.
   *Verify:* the note's two tables in section 3; `.screenshots/t189-before-bolt.png` against
   `t189-after-bolt.png`.

7. **AFTER: the fist holds, and the wrist trails.** Grip point on the knob to **0.000**, fingertip
   **0.180** from it against the cuff's **0.490**, wrist **+0.608** studs behind in Z; hip
   **0.0600** off the wrist axis, **+0.0005** along it, trail **+0.470**, the same six numbers for
   the hip, the aim and the start of the cycle.
   *Verify:* the `rifle bolt hand:` and `rifle right hand <state>:` notes in
   `.agent-logs/task189-r2-test3.log`; `src/shared/Viewmodel/poses.json`.

8. **THE SPEC THAT WOULD HAVE CAUGHT IT, AND WHAT IT CANNOT CATCH.** The only landmark on the glove
   was the grip point, which is **exactly as far from the knob whichever way round the hand is**.
   `FINGERTIP_STUDS` and `CUFF_STUDS` are the two ends, and the new cases ask whether the fingertip
   is nearer the held point than the cuff and whether the cuff trails it along the gun by more than
   half the glove's length. Task 188's pose fails both. What they do **not** hold is the
   mesh-to-aligned sign itself -- the landmarks are constants in the aligned frame -- and the
   comment says so, because Luau cannot read a vertex of a MeshPart.
   *Verify:* `tests/server/viewmodel_poses.spec.luau`, the two cases in *the rifle's right hand* and
   the `WHAT THESE TWO CASES CAN AND CANNOT FAIL ON` block.

9. **THE STANDING SHOT IS WITHIN 2 cm FROM 50 TO 200 m, PEAK INCLUDED.** `Rifle.CONFIG.GRAVITY_SCALE
   = 0.12`, read through `Ballistics.shotFor` beside the other three and multiplying gravity in
   `dropAt` and `advance`, the module's only two readers of it. 50/100/150/200 m was
   +8.9 / **+12.5** / +9.9 / -0.1 cm and is now **+1.1 / +1.5 / +1.2 / -0.0**; worst **1.51 cm**
   anywhere in 0-200 m. Measured twice: as arithmetic, and as a **plate standing on the sight line
   shot through the server's own `Weapon.Flight`** (task 183's method).
   *Verify:* the `[ballistics] still target at ...` and `[flight] still plate at ...` notes in the
   harness log; `tests/server/ballistics.spec.luau` (*KAREN'S BAR*) and
   `tests/server/weapon_hits.spec.luau` (*A STILL PLATE ON THE RETICLE*). The before column is the
   same shot at `gravityScale = 1`, which is bit-for-bit what task 185 flew.

10. **THE LEAD DOES NOT MOVE, AND IS PROVED END TO END FOR BOTH GUNS** -- Karen's third clause,
    which was a question. `timeToRange` never reads gravity, asserted against the same shot at real
    gravity to **zero tolerance**; and the real `Flight` is flown at a scripted runner crossing at a
    boar's sprint: rifle 2.7 / 5.6 / 12.2 studs of lead at 50 / 100 / 200 m, shotgun slug
    2.3 / 4.3 / 7.7 at 28 / 50 / 84 m. Aiming AT the animal misses in every row.
    *Verify:* the six `[flight] <gun> at <n> studs` notes; `tests/server/ballistics.spec.luau`
    (*keeps the lead*) and `weapon_hits.spec.luau` (*THE CORE CLAIM*).

11. **THE SEVEN NON-BLOCKING NOTES ARE DONE.** The stale *"its own -X"* sentences in
    `Viewmodel.align`, `gun.spec` and `camera_mode.spec`; *three numbers* -> *four* in
    `ballistics.spec`; the second copy of 0.28 in `weapon_hits.spec` replaced by
    `Report.CONFIG.METRES_PER_STUD`; the shotgun's shot record no longer flies under the rifle's
    name or the rifle's range (and its longest test distance is 300 studs, inside the slug's own
    330, so nothing expires in the step it arrives); the caveat on the two new cases (claim 8); and
    the weaker `launch direction` case left as the Reviewer describes it, with the independent
    number still pinned one case above. The no-flag decision is recorded, as 185a(h) and 186a(f)
    were.
    *Verify:* the files named; the note's section 3a for the record case.

12. **AND ONE MORE DEFECT FOUND BY THE CORRECTED FRAME, REPORTED AND NOT FIXED.** The shotgun's
    **aimed** right hand is end-for-end: read in the corrected frame its hip hand trails +0.447
    studs and its aimed hand **-0.447**. It is a pose Karen has accepted and this task was not asked
    to touch it, so it is measured, printed by the harness every run, and queued (TASKS.md 189a).
    *Verify:* the `task189 shotgun AIMED hand` note in the harness log; TASKS.md row 189a.

## What I could not verify (rule 8)

* **Whether Karen likes it.** The numbers and three first-person frames say the fist is on the knob
  with the arm behind it. Whether it reads as her own hand is hers.
* **The glove clips more now**: sampled glove vertices inside the gun's shell go 3.7% -> 10.7% at
  the bolt and 6.9% -> 29.1% at the hip, because before the change it was holding nothing. Task
  188's section 6 limit stands and is 188a(j). The figures are a share of SAMPLED VERTICES, not of
  surface area.
* **The LEFT glove is probably wrong the same way and is deliberately not touched** -- the same
  marker test puts its cuff flat on the fore-end with the fingers in the air
  (`.screenshots/t189-left-ends.png`). Its pose was tuned by eye, so it absorbs whatever `align`
  does. Queued as 189a(a).
* **The exact transform between the source glTF and the drawn MeshPart.** What is measured is that
  the drawn +X is the fist and the file's +X is the cuff. Nothing here depends on whether the
  pipeline reflects or rotates.
* **Only two rifle bolt phases were photographed** (the hip and full travel). The phases between are
  covered by the spec: the hand is carried rigidly by the bolt's own transform and the lift is a
  turn about the gun's Z, neither of which can change which end is nearest the knob.
* **`tools/pose.py` cannot drive a session while two Studios are open** (`running()` asks for a
  studio that answers as `server`; a solo Play session answers only as `client`). A harness fault,
  reported under 189a(d), worked around by naming the datamodel explicitly.
