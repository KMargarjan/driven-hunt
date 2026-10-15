# Task 189: the right hand was drawn end-for-end, and the rifle shoots flat to 200 m

Task: 189
Round: 1
Base: 34b4ae0 (main, #171 merged: task 188)
Code commit: 102f37192b060088c6883c015305df19be4e918b

Harness, full runs on the clean tree, twice (`.agent-logs/task189-r1-test1b.log`, `-test2.log`):

```
[harness] PASS: 33/33 checks @ 102f37192b060088c6883c015305df19be4e918b (clean tree) scope=all
[harness] PASS: 33/33 checks @ 102f37192b060088c6883c015305df19be4e918b (clean tree) scope=all
```

`test2` is **N/A**: no `TWO_PLAYER_PATHS` file is touched (the changed files are
`src/shared/Ballistics`, `HandAssets`, `Rifle`, `Shotgun`, `Weapons`, `Viewmodel/poses.json`, and
three server specs).

## What changed, and why

Karen, 2026-10-15, after playing task 188: *"hadn is oposit now reload with ending of arm not
fingers / also are you sure we have right rifle aiming? / seems a bit odd when stands it has to be
acurat 100% 100m 150m / when run I need a bit aim in front to be able hit in head or body does this
implemented ?"*

Two defects and a question. Note: `docs/research/2026-10-15-hand-axis-and-flat-trajectory.md`.

## Claims

1. **THE RIGHT GLOVE'S AXIS WAS MEASURED IN THE WRONG PLACE, AND THAT IS THE WHOLE OF "the hand is
   opposite".** `HandAssets.AXES.RIGHT.fingers` was task 188's measurement of the published glove's
   **glTF**; the MeshPart Roblox draws is flipped in X against that file, so `Camera.Viewmodel.align`
   pointed its +X at the **cuff**. The sign is flipped, and the comment says how it was settled.
   *Verify:* `src/shared/HandAssets.luau`, `AXES` and the block above it; `Viewmodel.align` in
   `src/client/Camera/Viewmodel.luau` is unchanged and still the only reader.

2. **IT WAS SETTLED IN THE RUNNING GAME, NOT IN A FILE (rule 5), AND TWICE.** Neon marker balls
   parked at the drawn part's own +0.36 X and -0.36 X, in a solo Play session with the rifle in
   hand: the +X ball sits on the brown fist, the -X ball on the olive cuff.
   *Verify:* `.screenshots/t189-axes2.png` and `t189-axes3.png` (two different poses). And
   `t189-nohandright.png`, which hides `HandRight` and shows the brown fist AND the olive sleeve
   disappear together -- so the two colours are one part and not the character's own arm. The
   method is in the note, section 3.

3. **MEASURED AS DRAWN, TASK 188's POSES HELD THE GUN WITH THE CUFF.** Composing its pose numbers
   with the alignment the game really applies: at the bolt the cuff was **0.212** studs from the
   knob and the fingertip **0.495**, with the wrist LEADING the hand by 0.538 in Z; at the hip the
   grip point was **0.2036** off the wrist axis and **+0.2591** along it -- outside task 188's own
   bounds of 0.0719 and 0.111, which its spec passed because every number in it was computed in the
   same wrong frame.
   *Verify:* the note's two tables in section 3, and the before/after frames
   `.screenshots/t189-before-bolt.png` against `t189-after-bolt.png` -- in the first, the olive
   cuff lies on the receiver and the brown fist is out at the bottom right; in the second the fist
   is on the bolt knob with the sleeve running back out of frame.

4. **AFTER: the fist holds, and the wrist trails.** Grip point on the knob to **0.000**, fingertip
   **0.180** from it against the cuff's **0.490**, wrist **+0.608** studs behind in Z; hip
   **0.0600** off the wrist axis, **+0.0005** along it, trail **+0.470**, and the same six numbers
   for the hip, the aim and the start of the cycle (one grip, so the hand does not re-grip when the
   eye goes to the scope).
   *Verify:* the harness's own notes in `.agent-logs/task189-r1-test1b.log` -- `rifle bolt hand:
   fingertip 0.180 from the knob, cuff 0.490, cuff 0.608 studs behind it in Z` and the three
   `rifle right hand <state>` lines. Data: `src/shared/Viewmodel/poses.json`,
   `weapons.rifle.{carry,aim,cycle}.right` and `cycle.hand.grip`.

5. **THE SPEC THAT WOULD HAVE CAUGHT IT, AND WHY THE OLD ONE COULD NOT.** The only landmark on the
   glove was the grip point, which is **exactly as far from the knob whichever way round the hand
   is** -- so no bound in task 188's spec could fail on a reversed hand. `HandAssets.FINGERTIP_STUDS`
   and `CUFF_STUDS` are the two ends, measured, and the two new cases ask whether the fingertip is
   nearer the held point than the cuff, and whether the cuff trails it along the gun by more than
   half the glove's own length. Task 188's shipped pose fails both.
   *Verify:* `tests/server/viewmodel_poses.spec.luau`, the two `it` blocks added to *the rifle's
   right hand* describe, and `HandAssets.FINGERTIP_STUDS` / `CUFF_STUDS`.

6. **THE STANDING SHOT IS WITHIN 2 cm FROM 50 TO 200 m, AND THE BAND'S PEAK IS INSIDE IT TOO.**
   `Rifle.CONFIG.GRAVITY_SCALE = 0.12`, read through `Ballistics.shotFor` beside the other three
   numbers and multiplying gravity in `dropAt` and `advance` -- the module's only two readers of it.
   50/100/150/200 m was +8.9 / **+12.5** / +9.9 / -0.1 cm and is now **+1.1 / +1.5 / +1.2 / -0.0**,
   worst **1.51 cm** anywhere in 0-200 m.
   *Verify:* the `[ballistics] still target at ... m: was ... now ...` and `worst deviation` notes
   in the harness log; `tests/server/ballistics.spec.luau`, *KAREN'S BAR (task 189)*. The before
   column is the same shot at `gravityScale = 1`, which is bit-for-bit what task 185 flew.

7. **MEASURED ON THE PLAYER'S PATH AS WELL, through the server's own flight (task 183's method).**
   A plate standing square on the sight line at 50/100/150/200 m, shot with `Weapon.Flight` stepping
   `Ballistics.advance` behind the real cast seam, and the hole's height read off the impact: was
   +8.9 / +12.5 / +9.8 / -0.1 cm, now +1.1 / +1.5 / +1.2 / -0.0.
   *Verify:* the `[flight] still plate at ... m` notes in the harness log;
   `tests/server/weapon_hits.spec.luau`, *A STILL PLATE ON THE RETICLE*.

8. **THE LEAD DOES NOT MOVE, AND THAT IS ASSERTED, NOT CLAIMED.** `Ballistics.timeToRange` does not
   read gravity at all, so flattening the arc cannot change a stud of lead; the spec compares the
   shipped shot's flight time and lead against the same shot at real gravity to **zero tolerance**.
   *Verify:* `tests/server/ballistics.spec.luau`, *keeps the lead: the flight time does not read
   gravity at all*.

9. **AND THE LEAD IS PROVED END TO END FOR BOTH GUNS** -- Karen's third clause, which was a
   question. The real `Flight` is flown at a scripted runner crossing at a boar's sprint: rifle
   2.7 / 5.6 / 12.2 studs of lead at 50 / 100 / 200 m, shotgun slug 2.3 / 4.3 / 8.6 at 28 / 50 /
   92 m. Aiming AT the animal misses in every row; leading it by `v*t` hits.
   *Verify:* the six `[flight] <gun> at <n> studs` notes in the harness log;
   `tests/server/weapon_hits.spec.luau`, *THE CORE CLAIM*, which now loops over both weapons.

10. **THE HARNESS CAUGHT A DEFECT OF MINE, and the fix is in the next commit.** Round 1's first run
    failed on one line: `acos(bore:Dot(aim))` with the dot at 1 - 3.7e-8. A Vector3 carries 32-bit
    floats, so at the flattened elevation (0.0156 degrees) that angle is rounding error. It is
    asserted as a tangent now, which is what `elevationTangent` defines and what `launchDirection`
    is built from.
    *Verify:* commit `102f371`; `tests/server/ballistics.spec.luau`, *the launch direction*.

## What I could not verify (rule 8)

* **Whether Karen likes it.** Three first-person frames and the numbers say the fist is on the knob
  with the arm behind it. Whether it reads as her own hand is hers.
* **The glove clips more now**: sampled glove vertices inside the gun's shell go 3.7% -> 10.7% at
  the bolt and 6.9% -> 29.1% at the hip, because before the change it was holding nothing. Task
  188's section 6 limit stands (the glove's gap is 0.054 x 0.060, the stock's wrist 0.144 x 0.203)
  and is 188a(j). The figures are a share of SAMPLED VERTICES, not of surface area.
* **The LEFT glove is probably wrong the same way and is deliberately not touched** -- the same
  marker test puts its cuff flat on the fore-end with the fingers in the air
  (`.screenshots/t189-left-ends.png`). Its pose was tuned by eye, so it absorbs whatever `align`
  does; flipping its axis would move a hand Karen has already accepted. Queued as 189a(a).
* **The exact transform between the source glTF and the drawn MeshPart.** What is measured is that
  the drawn +X is the fist and the file's +X is the cuff. Nothing here depends on whether the
  pipeline reflects or rotates.
* **Only two bolt phases were photographed** (the hip and full travel). The phases between are
  covered by the spec, not by eye: the hand is carried rigidly by the bolt's own transform and the
  lift is a turn about the gun's Z, neither of which can change which end is nearest the knob.
* **`tools/pose.py` cannot drive a session while two Studios are open** (`running()` asks for a
  studio that answers as `server`, and a solo Play session answers only as `client`). A harness
  fault, reported under 189a(d), worked around by naming the datamodel explicitly.
