PASS (items 6, 7, 8 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: nothing in this change has been
SEEN. Karen has not played it; no shooter's-eye frame of a back-slab hit was taken; no real click
was fired — every count in items 6, 7 and 8 is a `FireRequest` from the client VM on a rig the
request itself disclaims ("rifle RUN nose 4/10 here vs the board's 9/10 on `5c444dbe`"), so none of
them is the game's hit rate. Items 4 and 5 WERE read live in her place at this commit by
instance-fact probes (`carrier.luau` predicts `C0` from each bone and matches the live one;
`rig.luau` reads the weld `C0` frame by frame), and the code can produce those readings. The red
deer has no before/after at all on the carrier question.

Verification done by reading, not taken on trust:
- Claim 1 is in the code. `Body.gaitRig`: `local centreX = math.max(mesh.Size.X, 1e-3) * 0.1`,
  `sideOf`, and `if (boneSide == boxSide or boneSide == 0) and distance < bestDistance then`.
- Claim 3, the deletion check (RULE 3(a)), done by arithmetic on the repo's own numbers.
  `CONFIG.ZONES.body.boxes[1].offset` is `Vector3.new(0.000, 1.560, -0.950)` and
  `CONFIG.ZONES.legs.boxes[1].offset` is `Vector3.new(-0.300, -0.740, -0.690)`. The carrier is
  `Size = (1.4011, 1, 1)` so `centreX = 0.14011`; the back box reads side 0, `ear_1.L` at
  x -0.359 reads side -1 and is refused, `Neck` at x 0 is the only candidate. Distances: ear 0.5337,
  neck 0.6931 — so with the filter deleted `best` is the ear and `expect(backBox.bone).to.equal(neck)`
  goes red. The case bites its own producer. `expect(legBox.bone).to.equal(shin)` (shin 0.0711, neck
  1.650) bites the opposite mutation, a centre-bones-only filter. The two weaker lines
  (`toEar < toNeck`, `gaitRig(view) == 2`) survive the deletion, which the request says itself.
- The rule does not regress any shipped kind. `KINDS` records each kind's measured
  `MeshPart.Size.X`: male 1.40, female 1.20, cub 0.62, legendary 1.89, stag 3.47, hind 2.01, calf
  1.23. Every trunk box offset is |x| <= 0.025 (centre under all seven) and every leg box offset
  clears its own `centreX`: boar 0.300 > 0.140, female 0.250 > 0.120, cub 0.130 > 0.062, stag 0.420
  > 0.347, hind 0.350 > 0.201, calf 0.235 > 0.123. No box flips class, and the worst case of a
  misread bone is the old plain-nearest answer.
- The path is still dark where it was. `gaitRig` runs in `attachVisual`, but its output is read only
  by `Body.followGait`, which `Boar` steps behind `if gait ~= nil and gait.ENABLED`, i.e.
  `ZONES_FOLLOW_GAIT`, `default = false`. No new flag was needed.
- Claim 8's repo half is true: `SemiAuto.CONFIG.RANGE_STUDS = Shotgun.CONFIG.RANGE_STUDS` and the
  six rows beside it, "THE SAME SHELL, BY REFERENCE AND NOT BY COPY".
- Harness line names the `Code commit:` 472b8c68 with "(clean tree)";
  `paperwork-after-code-commit.txt` reads "Not paperwork: none / OK". selene 0/0, stylua clean,
  rojo build exit 0. `docs/design/hit-zones.md` says nothing the new rule contradicts.

## Notes (non-blocking)
- `Body.gaitRig` — claim 2's fallback is held by NO case. Every shipped rig has centre bones
  (`Neck`, `Spine_01..05`, `head`, `nose`, `root_bone`), so `best` is never nil and
  `if best == nil then best, bestRest = anyBest, anyRest end` plus the whole `anyBest`/`anyRest`/
  `anyDistance` tracking can be deleted with the harness still at 34/34. One case with two
  same-side-only bones and a box on the other side would hold it.
- `Body.gaitRig`, `centreX` — a tenth of the mesh's BOUNDING BOX is an antler measurement on the
  deer. `KINDS.stag.drawnWidthStuds = 3.47, -- MEASURED off the loaded mesh; the stag is 1.93x his
  own box`, so `centreX` is 0.347 on the stag against 0.140 on the male, and every stag bone inside
  |x| < 0.347 reads as a CENTRE bone and stays eligible to carry a centre-line box. The rule is
  therefore close to inert on the one animal the request lists as NOT PROVEN. A width taken from the
  trunk's own `BODY_SIZE.X` or from the measured torso half-width would not be a measurement of
  antlers. Queue it with the deer-side probe `MEASURED.md` section 3 already asks for.
- Claim 5 — per-lag TRAVEL is not FIT. 0.420 -> 0.268 studs says the box moves less; it does not say
  the slab now sits on the drawn back, and a box welded rigidly would read 0.000. 305c's own
  instrument (the drawn point inside a zone part, 0/98 -> 86/94) exists and was not re-run for the
  two `body` boxes on this build. That re-run plus one frame is what would close it.
- `reviews/task-305d/MEASURED.md`, the before/after table — the BEFORE carrier is `rig2.luau`, which
  the file says "re-implements the old rule"; it is a transcription of the deleted code, not a
  reading of `5c444dbe` (verdict 278). The independent before is `rig.luau`'s 0.420 on the base
  build. Label which column came from which so the next reader does not take the carrier row as a
  base-build measurement.
- `REQUEST.md` — no fail-first harness line. Tasks 305 and 305c each pasted an `[harness] FAIL: ...`
  with the producer reverted; here the deletion check holds only because the arithmetic above can be
  done by hand. One red run would have cost one command.
- `src/shared/Flags/init.luau`, `ZONES_FOLLOW_GAIT.why` — still reads "the bone nearest it", which
  is exactly the rule this task replaced.
- Claim 8 — the back-to-back counts cannot distinguish the two guns, because the tables they read
  are the same objects; 3/5 vs 3/5 adds nothing the identity fact did not already give. The counts
  are the weaker half of that item, not its evidence.
- `TASKS.md` — two rows are now keyed `305d`: the new task row and the pre-existing "Task 305b's
  review notes ... QUEUED" row that 305c queued under that id. One needs a different id before the
  Director dispatches from the table.
- `docs/design/hit-zones.md` — neither the gait rig nor the bone-carrier rule appears in it (a grep
  for "bone" and "gait" returns only `HitReport.nearest` lines), so the one rule deciding which bone
  carries which hit box lives only in code comments. 305c's debt, surfaced by touching it: queue an
  Architect pass.

---
REVIEWER verdict on commit `a8964fd19ada8082d8f449faba13eff6dd429647` (round 1) · 2026-10-28 19:56 UTC · session cost $2.54, 30 turns · written by tools/agents.py
