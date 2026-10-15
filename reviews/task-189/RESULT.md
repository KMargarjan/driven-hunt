PASS

Verified independently, not taken on the request's word:
- The transport `pose_new = pose_old * (align_old * align_new^-1)` reproduces the DRAWN right-hand
  rotation for all three distinct rotations among the five untouched poses. Recomputed from the
  shipped numbers: `Ry(yaw)Rz(pitch)Rx(twist) * align` (`Mode.handOffset` order) for
  `weapons.shotgun.carry.right` and `weapons.shotgun.aim.right`/`reload.right`, and
  `Rx(pitch)Ry(yaw)Rz(twist) * align` (`Viewmodel.view`'s `hornPose`) for `horn.carry.right`/`blow`
  — every matrix entry agrees with the task-188 pose composed with the task-188 `align` to ~3e-4,
  which is my arithmetic's precision. Positions are untouched in the diff, and `align` is
  `fromMatrix(Vector3.zero, ...)`, so they cannot move. The transport angle is
  `acos((tr(mesh_old^T mesh_new) - 1)/2)` = 149.89 deg, matching the claimed 149.88.
- The pinned constants in *the shotgun's and the horn's right hand did not move* are real
  measurements, not copies of the file: every tip/cuff pair is exactly `|FINGERTIP-CUFF|` = 0.6601
  studs apart and its midpoint is 0.0361 from that pose's own `pos` (the landmark midpoint's
  magnitude, 0.0362) — i.e. a rigid placement of the glove, including the aimed pose's -0.4469 trail.
- `gravityScale` enters only `dropAt` and `advance`, which are the only gravity readers in
  `Ballistics`; `elevationTangent`, `launchDirection` and `sightOffsetAt` all route through `dropAt`,
  and `timeToRange`/`speedAt`/`leadStuds` read none. The asserted numbers are exactly 0.12x the old
  ones (2.272e-3 -> 2.7265e-4; 0.448 -> 0.0537; -0.275 -> -0.0330), which is the claimed linearity.
- No stale `Shot` literal survives: every `{ v0 = ... }` in the tree now carries `gravityScale`
  (grep), both shipped rows carry `GRAVITY_SCALE`, and `rifle.spec`'s "no row carries a gravity" case
  bans `GRAVITY_STUDS_PER_S2` only, so it is not broken.
- The five are complete: `MAGAZINE_SWAP.hand` and `cycle.load.*` are LEFT-hand poses
  (`Viewmodel.poseHands`), so the right glove's poses through `align` are the rifle's four plus
  exactly these five.
- Harness paperwork is consistent: the two `[harness] PASS: 33/33 ... @ 8663c97 (clean tree)` lines
  name the request's `Code commit:`, and `paperwork-after-code-commit.txt` says OK (only REQUEST.md
  followed). selene/stylua/rojo clean. No secret, path or address in the diff.

## Notes (non-blocking)
- `src/shared/Viewmodel/poses.json` + `Mode.handFrame` — the transport preserves the ENDPOINTS, not
  the path between them. `handFrame` lerps the three Euler angles component-wise, which does not
  commute with right-multiplying by the transport, so the shotgun's right hand mid-raise
  (`blend 0.5`) is drawn ~173 degrees from where it was drawn before this change (I computed both
  from `Ry Rz Rx * align`). Total travel is similar (196 deg before, 192 deg after) and positions are
  identical throughout, so it is a different route rather than a worse one — but it is a visible
  transient on a hand Karen accepted, and claim 1's "do not move" is true of the poses only. Worth
  one look at the shotgun's ADS transition in play, and a line in 189a; the root cause is the same
  hip-vs-aim 180 deg flip already queued as 189a(b1).
- `tests/server/viewmodel_poses.spec.luau`, the *did not move* describe — "Flip the axis again
  without re-expressing these five and every one of them moves about 150 degrees, which is what this
  fails on" is stronger than the case is. `FINGERTIP_STUDS`/`CUFF_STUDS` are constants in the ALIGNED
  frame, so `offset:PointToWorldSpace(L)` does not read `AXES` at all: the case fails on a flip only
  if the landmarks' Z is re-measured with it. That is the caveat the same file states correctly 80
  lines above (`WHAT THESE TWO CASES CAN AND CANNOT FAIL ON`); the two sentences should agree.
- `tests/server/viewmodel_poses.spec.luau` — three of the five poses are pinned, not five:
  `weapons.shotgun.reload.right` and `horn.blow.right` carry their own `rot` blocks that no outside
  constant holds (the existing "answers each pose's own numbers" case reads the file, and the horn
  case says it only answers for `carry`). The note's "pins all five" overstates it. One case each --
  `stateAt(0, 1)` for the shotgun's reload hand and `hornPoses.blow.right` -- closes it.
- `tests/server/weapon_hits.spec.luau` — the new header says *"A second 0.28 in this file would be a
  second answer to how far 100 m is"*, and `distance * 0.28` is still there in THE CORE CLAIM's
  `TestKit.note` (the "A STILL PLATE" copy was correctly replaced). `metresPerStud` is in scope only
  in the other case; hoist it or drop the literal.
- `docs/design/ballistics.md` is now behind the code in four places: section 4.1's
  `export type Shot = { v0, k, zeroStuds }`, section 3.1's three-number table, section 11.2 item 5's
  0.1438 deg bore elevation, and section 11.3's *"no row carries a flight number or a gravity"* --
  which, read literally, forbids `GRAVITY_SCALE` on a row. The shipped case only bans
  `GRAVITY_STUDS_PER_S2`, and a dimensionless per-ammo scale is a ballistic property like the zero
  rather than a server resource, so the shipped reading is defensible; the doc should say so
  explicitly. Queue a design pass with the next ballistics task.
- `tests/server/rifle.spec.luau`, "the rifle's own numbers" — the per-ammo loop still types three
  numbers (`MUZZLE_STUDS_PER_S`, `DRAG_PER_STUD`, `ZERO_STUDS`), which design 11.3 asks for. The
  fourth is covered by `ballistics.spec`'s new case, so this is tidiness, not a hole.
- `src/shared/HandAssets.luau`, `AXES` — the marker-ball evidence settles the +X/-X end only, and
  `palm`'s X sign was flipped on the same inference. If the pipeline applies a rotation rather than a
  mirror, `align`'s palm is 180 degrees out and the glove is rolled, and nothing in the spec can see
  it: both landmarks lie on the fingers axis and `GRIP_STUDS` is within 0.006 of it. The note's
  section 8 item 2 says the transform is unestablished, which is honest; the same marker test on the
  drawn part's +-Z would close it, and it belongs in 189a beside the left glove.
- `src/shared/Rifle/init.luau` `GRAVITY_SCALE` / the pose re-solve ship with no flag, recorded rather
  than asked, as 185a(h), 186a(f) and 188a(f) were. Both states stay reachable by parameter
  (`dropAt` takes `g`; the specs fly `gravityScale = 1`), so the two branches are testable.
- The new code blocks carry the pattern and the source in the research note but not the note's path:
  `Ballistics`'s header still lists only `2026-10-14-ballistics-lead.md`, and `Rifle.CONFIG`'s
  `GRAVITY_SCALE` block names neither Unreal's `ProjectileGravityScale` nor the note. One line each.
- `TASKS.md` row 189 still names `3269d91` as the tested commit; the request's gate is `8663c97`.
  Prose only.
- `tests/server/viewmodel_poses.spec.luau`, the bolt case's four-turn loop — the distance half
  (`tip` nearer `lifted` than `back`) is an identity of rigid motion, as 188a(a) already records; the
  `back.Z - tip.Z > HALF_HAND` half is the part that can fail there. The comment states the property
  honestly, so this is a pointer for the next task rather than a defect.

---
REVIEWER verdict on commit `fdd7837578ce001dfe1adaebadba899055df4d73` (round 2) · 2026-10-15 13:50 UTC · session cost $7.06, 57 turns · written by tools/agents.py
