# Task 344b -- two animal bugs Karen still saw after #357

Task: 344b
Round: 1
Base: faf4557d (origin/main, #358)
Code commit: 4fe2f6bb3c8ade1f837201a10f91595e91061f06

Karen, 2026-11-10 ~14:15 UTC, playing her Forest Test at `6109ceea` (#357), verbatim: *"still bug
with redstag jumping then fall on side and glide"* and *"animal died and then stand and then again
die"*.

**THE TWO ARE ONE FAULT.** A stag's box tips over on a leap landing and is driven on in that state
(bug 1); shoot it there and the death clip lays the rig down **in the box's frame**, so the two
rotations compose and the carcass is drawn STANDING ON ITS FEET (bug 2) -- which is what
`Body.collapse`'s own task-150 comment has described since *"a dead boar standing on its feet, made
of two correct rotations"*. The measured chain is claim 1.

```
[harness] PASS: 34/34 checks @ 4fe2f6bb3c8ade1f837201a10f91595e91061f06 (clean tree) scope=all
```
`test2`: **N/A** -- nothing in `TWO_PLAYER_PATHS` (`src/server/Boar/`, `tests/server/` only).

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
   never a cut (`Body.driveForce`'s shape). Read live in her place at the code commit:
   `stagTorque=74627.86 boarTorque=20000` (`344b-FINAL.out`, line `build:`). Every boar kind is
   unchanged to the byte. Case: `deer.spec`, *"gives a bigger box more torque"* -- FAILS AT MAIN.
3. **`Body.levelCFrame`** + one CFrame write in `Body.collapse`'s clip-falls arm: a box that is
   rolled when the shot lands dies the way up, keeping the yaw. Same shape and same place as
   `Body.topple`'s one write. Case: `deer.spec`, *"takes the roll and the pitch out"* -- FAILS AT MAIN.
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
   198 post-fix landings, against 101 and 96 before.**
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

## Could not verify

- **The residual on bug 1 is 3 landings of 56 past 20 deg, worst 28.** The "on its side" state Karen
  reported did not occur once in 198 post-fix landings (nothing past 40), but a 20-28 deg lean on a
  landing still happens and nobody has judged whether she can see it.
- **The 6 s re-assert can still pop a carcass to its bind pose for under four seconds on a client**
  (C1, 1 of 14 kills, `344b-C1-cli.txt`: `CLIENT STOOD Boar133 6s after death span=3.07 drawn=none`).
  It is `Play`'s own frame 0, it did not recur in the 34 kills at the code commit, and cycle 2 proved
  that gating it is worse. Queued as `344b-notes`, not fixed in this task.
- **Stuck events over 1 s went 1 -> 3** between the two 300 s yaw sessions (`344b-YAW-*.txt`,
  `stuckEvents=`). Nothing in this change touches the wedge or the stuck detector; n is 1 and 3.
