PASS (items 2, 4 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: this task is a CORE item
(shooting). NOTHING has been seen in Karen's place by Karen. The request says so itself -- "Nobody
has played this. No real mouse click, no screenshot" -- and its own click proof is 6/10 against the
8/10 the dispatch asked, with its control reading 4/10 where `reviews/task-305b/MEASURED.md` reads
9/10. Claims 2 (86/94 frames inside `ZoneHead1` on the moving animal) and 4 (air ahead of the drawn
animal is still a miss) rest entirely on `<runs-dir>/305c/` probes that are not in the repository
and that I cannot run. The path ships behind `ZONES_FOLLOW_GAIT`, default false.

Round 1's blocking finding is closed. `picks the NEAR bone for each box and never the far one`
calls the real `Body.gaitRig` with two hand-made `Bone`s at (0, 0.666, -2.388) and
(0, 0.948, 1.486) on a carrier at `trunk.CFrame`, against the real
`CONFIG.ZONES.head.boxes[1].offset` = (0.000, 0.600, -2.250) and `.rear.boxes[1].offset` =
(0.000, 0.440, 1.290). Checked by hand: snout box to snout bone 0.153 studs, to rump bone 3.752;
rump box to rump bone 0.544, to snout bone 3.685. Flipping `distance < bestDistance` to `>` leaves
`best` nil for every row (the first comparison against `math.huge` never passes), so both
`expect(...bone).to.equal(...)` lines go red while `gaitRig` still returns 2 -- the case bites the
one comparison the whole rule is, and it uses no bought asset. Deleting `Body.gaitRig`'s body for
`return 0` turns `expect(Body.gaitRig(view)).to.equal(2)` red. Same for `followGait`:
`expect(Body.followGait(handleView, 2.5) > 0).to.equal(true)` in the third case fails on deletion.
Geometry re-derived and correct: `row.inBone = (mesh.CFrame * bestRest):ToObjectSpace(trunk.CFrame *
CFrame.new(row.offset))` with `want = trunkCFrame:ToObjectSpace(bone.TransformedWorldCFrame *
row.inBone)` is identity at rest, so flag-off geometry is byte-identical; `Weld.C0 =
CFrame.new(box.offset)`, `C1 = identity` reproduces the old `zonePart.CFrame = trunk.CFrame *
CFrame.new(box.offset)` exactly. 21 flag rows against `MAX_FLAGS = 21`; `expires = "2026-11-18"` is
exactly 21 days from `born`; `Flags.isOn("ZONES_FOLLOW_GAIT")` appears once in `src/`, at
`Boar.CONFIG.GAIT.ENABLED`, and is reachable by parameter through `world.config.GAIT`. Nothing in
`src/`, `tests/` or `tools/` calls `BreakJoints` or looks for a `WeldConstraint` on a zone part, so
the legacy-`Weld` swap breaks no reader. Harness line names `c32004a4`, "(clean tree)";
`paperwork-after-code-commit.txt` says OK (only `ESCALATE.md` and `REQUEST.md` after it); selene,
stylua and rojo are clean.

## Notes (non-blocking)
- `tests/server/boar_zones.spec.luau`, `gives every hit box the bone nearest it, or none at all
  without a visual` — the grey-box branch still survives deletion of the producer: replace both
  function bodies with `return 0` and `expect(wired).to.equal(0)` /
  `expect(Body.followGait(handleView, 2.5)).to.equal(0)` stay green. It now prints
  `branch=grey-box` and the new near-bone case covers the rule in every environment, which is what
  closed the finding, but this case is still a no-op guard and not a producer test. It prints the
  branch; it does not assert it.
- `reviews/task-305c/REQUEST.md` claim 2 / the ITERATION table — the headline `86/94` is attributed
  by the table to **cycle 2** ("clamp 2.5", translation only), while the shipped code is cycle 3
  ("box skinned to its bone, rotation too"), whose row reads only "91 %" with no denominator. The
  shipped build's own server-side count is therefore never stated as n/N. Both clear the (c) target
  of >= 90 %, so the substance stands; the attribution does not.
- `reviews/task-305c/MEASURED.md` section 2 — claim 2's "FAIL FIRST, same build, flag off: 0/98" is
  the **client** row; the server/flag-OFF cell in the same table is `--`. There is no server-side
  before-number. The two sides were measured to agree on the envelope (0.003), so the proxy is
  reasonable, but the claim should say which side it came from.
- The production wiring is not held by the gate: no spec sets `GAIT.ENABLED`, so deleting the
  `if gait ~= nil and gait.ENABLED then Body.followGait(...)` branch in `Runtime:step` or the
  `Body.gaitRig(handle)` line in `attachVisual` leaves the harness at 34/34. The seam exists --
  `Boar.newRuntime` copies `world.config` keys, so `config = { GAIT = { ENABLED = true,
  MAX_SHIFT_STUDS = 2.5 } }` reaches `Runtime:step` -- so this is one case away. Same gap the
  Director queued as 305d (c).
- `Runtime:cframeAt` — this is production code and not only a stale comment: for a zone part it
  returns `trunkThen * (trunk.CFrame:Inverse() * instance.CFrame)` under the line "THE WELD'S OWN
  CONSTANT, READ NOW AND APPLIED THEN". With `ZONES_FOLLOW_GAIT` on that offset is no longer
  constant, so the rewound test pairs a 0.18 s-old trunk CFrame with a PRESENT-pose box. Both flags
  are lit in Karen's Forest Test. The request names this as the first thing to measure; it belongs
  in `TASKS.md` as a measurement, not as wording.
- `tests/server/boar_zones.spec.luau`, `moves a box by its bone's own deformation and never resizes
  it` — `row.weld.C0 = CFrame.new(row.offset)` is the last statement of the `it`, not an
  `afterEach`. A failed assertion leaves a real zone part displaced by up to 2.5 studs for the
  real-ray cases that follow in the same file, so one red turns into several. Same shape as 305a
  note (c).
- `Boar.CONFIG.GAIT.MAX_SHIFT_STUDS = 2.5` is justified in its own comment by one box ("the snout")
  and applied to all fifteen; `Body.gaitRig` runs from `attachVisual` unconditionally, so the dark
  build pays fifteen boxes x every bone x a parent-chain walk per spawn; and there is still no
  frame-time number for fifteen `Weld.C0` writes per boar per `Runtime:step`. All three are round
  1's notes, unchanged, and the Director should have the last one before flipping the flag.
- `docs/design/hit-zones.md` section 4.3 still reads "joint | one `WeldConstraint` per zone part",
  and section 10 source A is the `WeldConstraint` reference; the code now makes a legacy `Weld`
  unconditionally. Architect's file (precedent 305a note (k)) -- queue it, do not let the Builder
  edit it.
- `Body.liftDrawn`'s header ("IT TOUCHES NOTHING A SHOT READS ... the hit boxes stay exactly where
  the animal died") is false with the flag on: the lift moves the bones, so the next `followGait`
  carries every box up by the lift, clamped. No gameplay effect today -- `Damageable` is already
  false by then -- but the sentence should name the flag.

---
REVIEWER verdict on commit `edac1d2bd3706e9e3dc595400ed79119c5f6cee1` (round 2) · 2026-10-28 17:49 UTC · session cost $2.53, 32 turns · written by tools/agents.py
