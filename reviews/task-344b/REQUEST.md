# Task 344b -- two animal bugs Karen still saw after #357

Task: 344b
Round: 2
Base: faf4557d (origin/main, #358)
Code commit: ac8c100574caa48debea80c3231931321b880ed8

Karen, 2026-11-10 ~14:15 UTC, playing her Forest Test at `6109ceea` (#357), verbatim: *"still bug
with redstag jumping then fall on side and glide"* and *"animal died and then stand and then again
die"*.

**THE TWO ARE ONE FAULT.** A stag's box tips over on a leap landing and is driven on in that state
(bug 1); shoot it there and the death clip lays the rig down **in the box's frame**, so the two
rotations compose and the carcass is drawn STANDING ON ITS FEET (bug 2) -- which is what
`Body.collapse`'s own task-150 comment has described since *"a dead boar standing on its feet, made
of two correct rotations"*. The measured chain is claim 1.

```
[harness] PASS: 34/34 checks @ ac8c100574caa48debea80c3231931321b880ed8 (clean tree) scope=all
```
`test2`: **N/A** -- nothing in `TWO_PLAYER_PATHS` (`src/server/Boar/`, `tests/server/` only).

**L-162, said plainly: the live runs in claims 5-9 were taken at `4fe2f6bb`, not at this round's code
commit `ac8c1005`.** What round 1 added between them is three spec cases and four code COMMENTS --
`git diff 4fe2f6bb..ac8c1005 -- src/` is comments only, and `Body.uprightTorque`, `Body.levelCFrame`,
the `Body.create` line, the `Body.collapse` write and the landing brake are byte-for-byte the build
those runs measured. The two delete-and-fail proofs below WERE run at `ac8c1005`.

## PLAN (core quality protocol, step 0)

- **(a) REAL LIFE.** A red deer lands a bound on its feet and runs on: it does not tip. A body's
  angular acceleration is torque / inertia, and a box's roll inertia is `m * (X^2 + Y^2) / 12`.
- **(b) MEASURED NOW** (`<runs-dir>/344b-srv.luau`, Karen's Forest Test at `faf4557d`, runs B2+B3):
  **96 stag landings, 16 past 20 deg of tilt, worst 101 and 96** -- the body on its side, still
  driven at 28.3 studs/s. Of 22 kills, **one carcass drew a 5.20-stud bone span** (a deer standing;
  lying is ~1.4) for the whole 110 s it was watched, and it had died at **tilt=90**.
- **(c) TARGET.** No landing past 20 deg of tilt; 0 carcasses standing in >= 20 kills; exactly one
  death per animal.
- **(d) LEVER.** `upright.MaxTorque = config.MAX_TORQUE` in `Body.create` -- `MAX_TORQUE` 20000 was
  tuned on the BOAR's box (`docs/design/boar-ai.md`: *"Mass = 33 studs^3 x 0.7"*), and the stag's box
  has **3.73x** its roll inertia. Plus `Body.collapse`, which writes no CFrame in the clip-falls arm.
- **(e) HOW MEASURED AFTER.** The same probe, the same place, the same staged stag.

## Claims

1. **The two bugs are one fault, and it is measured.** `<runs-dir>/344b-B3-srv.txt`, the `DEATH stag
   Boar28` block: `tilt=90` at the moment of death, `drawn=deathLeft@1.14` (the clip correctly held),
   and `span=5.20` for 110 s. Verify: that block, beside the `LEAP stag Boar28 ... land=62deg
   spin=252deg/s | +0.5 84deg | +1.0 90deg` line in the same file -- the same animal, tipped by its
   landing and then shot.
2. **`Body.uprightTorque`** scales `MAX_TORQUE` by roll inertia against `MAX_FORCE_BODY`, a floor and
   never a cut (`Body.driveForce`'s shape). Read live in her place at the proof commit:
   `stagTorque=74627.86 boarTorque=20000` (`344b-FINAL.out`, line `build:`). **The male, the sow and
   the cub keep 20000 to the byte; TWO ANIMALS ARE BIGGER AND BOTH ARE RAISED** -- the three red deer
   and **the legendary boar**, who is the male's box at `scale` 1.35 and so gets ~89,680 (4.48x).
   **The legendary is UNMEASURED: every run in this task staged a stag.** It is the same arithmetic
   in the same direction, and `Body.driveForce` already scales him the same way ("THE TWO ANIMALS
   BIGGER THAN IT"). Round 1, findings 1 and 2. Cases: `deer.spec` *"gives a bigger box more torque"*
   (pure, and the legendary's 4.48x asserted) and **`deer.spec` *"gives the stag the upright torque
   his inertia needs"*, which reads `Upright.MaxTorque` off the seven REAL trunks the block already
   builds** -- the line in `Body.create` itself, not the pure rule.
3. **`Body.levelCFrame`** + one CFrame write in `Body.collapse`'s clip-falls arm: a box that is
   rolled when the shot lands dies the way up, keeping the yaw. Same shape and same place as
   `Body.topple`'s one write. Cases: `deer.spec` *"takes the roll and the pitch out"* (the pure rule)
   and **`boar_model.spec` *"levels a rolled box at the moment of death"*, which collapses a body
   rolled 90 degrees with a visual and a seeded death track** -- the `boxFalls == false` arm -- and
   asserts the box is the way up with its yaw kept, plus that the box-falls arm still topples. Round
   1, finding 3: every other collapse case in that block passes an UNROLLED body, where the write is
   an identity.
4. **The landing brake**: one `AssemblyAngularVelocity = Vector3.zero` at the instant the bound ends,
   beside the write that already cancels the second hop there. Case: `deer.spec`, *"stops the tumble
   on the frame the bound ends, and not before"* -- drives the real `Boar.stepVisual` on a real Part,
   asserts the spin is still there mid-bound and gone on the frame it ends. FAILS AT MAIN.
5. **BUG 1, MEASURED, same probe both sides, Karen's Forest Test, one staged stag every 18-20 s:**

   | run | commit | landings | past 20 deg | worst tilt | mean worst |
   |---|---|---|---|---|---|
   | before B2 | `faf4557d` | 38 | 6 | **101** | 14 |
   | before B3 | `faf4557d` | 58 | 10 | **96** | 12 |
   | cycle 1 C1 | `e197f635` | 42 | **0** | 15 | 4 |
   | cycle 2 C2 | `23ed6fdf` | 55 | **0** | 9 | 3 |
   | cycle 2 C3 | `23ed6fdf` | 50 | 3 | 39 | 5 |
   | cycle 3 C4 | `4fe2f6bb` | 52 | 4 | 23 | 5 |
   | **FINAL** | **`4fe2f6bb`** | **56** | **3** | **28** | **5** |

   Files `344b-B2-srv.txt` .. `344b-FINAL-srv.txt`, line `BUG1`. **Not one landing past 40 deg in
   the 255 post-fix landings of the five rows below the line, against 101 and 96 before** (round 1's
   note: 255 is the sum of 42+55+50+52+56; 108 of them are at the shipped build, C4 and FINAL).
6. **BUG 2, MEASURED, same probe both sides, server AND client** (task 150 measured the standing
   carcass only on the CLIENT, so both are sampled; `span` is task 293's own
   `Bone.TransformedWorldCFrame` instrument -- lying ~1.0-1.4 studs, standing bind ~5):

   | run | commit | kills | second deaths | stood after death srv/cli | revived |
   |---|---|---|---|---|---|
   | before B2+B3 | `faf4557d` | 22 | 0 | **1 / 1** (110 s standing) | 0 |
   | cycle 1 C1 | `e197f635` | 14 | 0 | 0 / 1 (a pop under 4 s at the 6 s mark) | 0 |
   | cycle 2 C3 | `23ed6fdf` | 19 | 0 | 0 / **2** (one standing 50 s) | 0 |
   | cycle 3 C4 | `4fe2f6bb` | 11 | 0 | **0 / 0** | 0 |
   | **FINAL** | **`4fe2f6bb`** | **23** | 0 | **0 / 0** | 0 |

   **34 kills at the code commit, every animal exactly one death and one fall, nothing standing.**
7. **CYCLE 2 WAS REFUTED BY ITS OWN MEASUREMENT AND IS REVERTED.** `23ed6fdf` gated task 150's 6 s
   re-assert on the server's own pose; `344b-C3-cli.txt` then shows `CLIENT STOOD Boar56 2s after
   death span=5.66 drawn=none`, standing 50 s -- task 150's client exactly, with its one repair
   removed. `4fe2f6bb` reverts it. Verify: `git show 4fe2f6bb --stat` and that `Body.shouldReassert`
   is byte-for-byte `faf4557d`'s.
8. **NO REGRESSION ON TASK 344's OWN METRIC**, measured with task 344's own probe
   (`344-probe.luau`), one 300 s session each side, same place, same staged stag:
   before `faf4557d` **n=16 mean@0.5 18.6 deg, mean@1.0 18.1, worst@0.5 56.3**;
   after `4fe2f6bb` **n=17, 16.4 / 17.8 / 33.9**. Files `344b-YAW-BEFORE.txt`, `344b-YAW-AFTER.txt`,
   line `LEAP n=`. `MOVE.LAND_TURN_DEG/LAND_SECONDS/WEDGE_SECONDS` read `90/0.8/0.4` live in every
   run (`build344:` lines) -- #357's landing yaw cap is untouched.
9. **FRAMES, both opened and described.** `344b-F1.png`: a red stag **1.0 s after its leap landing**
   (anchored at that instant by `344b-freeze.luau`, which recorded `tilt=0.3 speed=28.3`), standing
   square on its feet on the forest road, antlers and head up, legs under it -- camera at the
   player's eye height 16 studs away. `344b-F2.png`: a cub boar **5.0 s after death** (`tilt=0.4
   span=1.06`), lying flat on its side at the road edge, head down in the grass, legs out -- the kill
   feed in the same frame reads *"CUB BOAR head 11 m SHOTGUN"*. Both in her Forest Test at the code
   commit.
10. **Her place, her attributes, untouched.** Proof ran against `driven-hunt-rev` on :34874 at the
    code commit (panel shot `evidence/port-34874-20261110-164630.png`); the Forest Test ends on
    **:34873 from `driven-hunt-karen`, Edit** (`evidence/port-34873-20261110-165313.png`). The
    ServerStorage attribute dump before and after is **identical** (`344b-ft-attrs-before.txt` vs
    `344b-ft-attrs-final.txt`). Nothing was ever checked out in `driven-hunt-karen`.

## L-093 delete-and-fail, both RUN at `ac8c1005` (the round-1 findings' own test)

- Restore `upright.MaxTorque = config.MAX_TORQUE` in `Body.create` -> **`deer.spec:341` fails**,
  *"Expected value to be near 74627.860000 (within 0.010000) but got 20000.000000 instead"*.
- Delete `handle.part.CFrame = Body.levelCFrame(handle.part.CFrame)` from `Body.collapse` ->
  **`boar_model.spec:2596` fails**, *"Expected value true, got false"*.
  That same dirty run also failed `deer_hitbox.spec:682`, which is on the Director's known-flake
  list for this task; it **passed** in the clean 34/34 run at this same commit immediately before and
  after, so it is not caused by either change.

## Could not verify

- **The residual on bug 1 is 3 landings of 56 past 20 deg, worst 28.** The "on its side" state Karen
  reported did not occur once in 255 post-fix landings (nothing past 40), but a 20-28 deg lean on a
  landing still happens and nobody has judged whether she can see it.
- **THE FIXED DEFECT STATE HAS NOT BEEN SEEN BY EYE IN HER PLACE** (round 1's first note, and it is
  right). `344b-F1.png` is a stag that did not tip (`tilt=0.3`) -- the healthy case; `344b-F2.png` is
  a cub boar dying level, not a stag shot while rolled, which is the state claim 3 exists for. Both
  cures are carried by the probe numbers (`tilt`, `span`) and the delete-and-fail cases. Items 1 and
  2 are **NOT PROVEN BY EYE**.
- **The legendary boar's 4.48x upright torque is unmeasured** (claim 2). No run in this task staged
  him, and the only live kind whose torque changes without a measurement behind it.
- **No dial and no flag** on any of the three changes (round 1's note). If Karen dislikes the
  residual lean or the levelled death there is no way to turn one off without a code change; queued
  as `344b-notes`.
- **The 6 s re-assert can still pop a carcass to its bind pose for under four seconds on a client**
  (C1, 1 of 14 kills, `344b-C1-cli.txt`: `CLIENT STOOD Boar133 6s after death span=3.07 drawn=none`).
  It is `Play`'s own frame 0, it did not recur in the 34 kills at the code commit, and cycle 2 proved
  that gating it is worse. Queued as `344b-notes`, not fixed in this task.
- **Stuck events over 1 s went 1 -> 3** between the two 300 s yaw sessions (`344b-YAW-*.txt`,
  `stuckEvents=`). Nothing in this change touches the wedge or the stuck detector; n is 1 and 3.
