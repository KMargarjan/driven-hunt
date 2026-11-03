PASS (item 1, 3, 6, 7 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: what was seen in Karen's place is
the DEFECT (claim 2 -- the stag's 16.0 s no-progress at (-3798,-5059) on 14.8 deg, on merged `main`).
The AFTER halves -- claim 1's ladder, claim 3's census, claim 6's `-AFTER-K1`/`-AFTER4-K2` frames and
claim 7's boar census -- were produced with `Mover.MaxForce` written at RUNTIME by
`328n-patch.luau`, not by this branch's `Body.create`; the request says so itself ("the AFTER force in
her place is a runtime write, not this branch's code"). So the code that ships has never driven an
animal in her place, and Karen has not judged the stag on the slope (`TASKS.md`: "NEEDS KAREN").
Everything the harness proves is the FORCE VALUE on the Instance, not the climb.

Checks that passed, in brief: `geometry.bodySize` IS `part.Size` (`Body.create`), density is uniform
(no `CustomPhysicalProperties` anywhere in `src/`, `Material = SmoothPlastic` on every trunk), zones
and the drawn mesh are `Massless` -- so force/mass is the same number for every kind by arithmetic:
male/sow/cub/calf on the floor at 6000, stag 11,075, hind 6,927, legendary 14,762. `speciesConfig`
and `scaledByWary` `table.clone` the config, so `MAX_FORCE_BODY` survives to the deer. `MaxForce` has
exactly one writer (`Body.luau`). `test2` N/A is correct -- none of the three non-paperwork files is
in `TWO_PLAYER_PATHS` (checked against `tools/agents.py`, not against the request's prose).
DELETE THE PRODUCER: reverting `mover.MaxForce = Body.driveForce(...)` to `config.MAX_FORCE`, or
deleting the `MAX_FORCE_BODY` row that feeds it, fails the live case's accel equality (stag 0.54 of
the male's); deleting the `math.max` floor fails the cub-box line. Two lines DO survive deletion --
`expect(ratio > 1.8)` (arithmetic on two config tables, not on the code) and the `>= MAX_FORCE` loop
(6000 >= 6000) -- but each sits in a case whose other assertions bite, so neither is a hole.
Harness line names the `Code commit:` `782fc1ab`, "(clean tree)";
`paperwork-after-code-commit.txt` OK; selene/stylua/rojo clean.

## Notes (non-blocking)
- `tests/server/deer.spec.luau`, "gives the stag the force his mass needs" — the comment says the
  force is "asserted as an EQUAL ACCELERATION across all seven kinds -- the property", and it is
  asserted for TWO (stag, legendary). The HIND is scaled too (volume 38.10 against the reference 33,
  so 6,927 N) and gets only `expect(mover.MaxForce >= Boar.CONFIG.MAX_FORCE)` — the one deer besides
  the stag that climbs the same ground, and she is in no measurement in this task either. Fix: move
  "hind" into the `{ "stag", "legendary" }` loop and "calf" into the floor loop, so all seven kinds
  are named in one of the two arms.
- `tests/server/deer.spec.luau`, "scales UP by volume for the red deer" — `expect(math.abs(driveForce(deer, config) - config.MAX_FORCE * ratio) < 1e-6)` re-computes `force * volume / refVolume`, the body of the function under test (verdict 278). The two numbers the request and `TASKS.md` quote — 11,075 and 14,762 — are asserted nowhere; put them in as literals and the transcription stops carrying the case.
- `tests/server/deer.spec.luau` — the floor line uses `Vector3.new(1, 1.5, 2.75)` (the male's box at 0.5) while the comment beside it says "came out at 547". 547 is the REAL cub, `BODY_SIZE * KINDS.cub.scale` 0.45 (33 x 0.091 -> 6000 x 3.008/33); this box answers 750. Drive it off `Boar.CONFIG.KINDS.cub.scale` so the number in the comment is the number tested.
- `src/server/Boar/init.luau`, `MAX_FORCE_BODY` — the comment says it "IS this table's own `BODY_SIZE`"; it is a second copy of the literal. The guard in the spec (`driveForce(config.BODY_SIZE, config) == MAX_FORCE`) is one-directional: a GROWN `BODY_SIZE` fails it, a SHRUNK one passes on the floor while leaving the reference stale and the male quietly faster than the stag. One line fixes it: `expect(config.MAX_FORCE_BODY).to.equal(config.BODY_SIZE)`.
- `src/server/Boar/Body.luau`, `Body.driveForce` — returns `0` when `config.MAX_FORCE` is not a number, so a config without it yields `MaxForce = 0`: an animal that cannot be driven at all, silently, where the old line raised. No caller reaches it today (every config is a clone of `Boar.CONFIG`). Either return `force` unchanged is impossible here, so say in the header why 0 is the safe answer, or let it error.
- No `src/shared/Flags/init.luau` row. This is a change to what an animal does, which is what Karen judges, and the digest's rule is that a feel-critical path is born behind a flag at `default = false`. Two mitigations, both real: both states are reachable by parameter (`Body.driveForce(size, { MAX_FORCE = 6000 })` is the old world, and the spec drives it), and with `BOAR_MODEL`/`KINDS` off no kind is bigger than the reference box, so the grey-box world is byte-identical. What is lost is Karen's own A/B in her place, where kinds are ON. The Director's call, not another round.
- The LEGENDARY's 2.46x (6000 -> 14,762) is beyond the task statement — a stag that cannot climb — and is measured nowhere: the AFTER census is cub n=28, female n=14, male n=18 plus the one stag, so the hind, the calf and the legendary appear in no run on either side. Queue a drive census that holds a legendary and a hind.
- Nothing measures what the new force does to a PLAYER the animal walks into — the shooters stand in the drive's path, and the stag now pushes with 1.85x and the legendary with 2.46x of what Karen has played against. Not the reported defect; queue it beside 328n-notes(c)'s `MAX_TORQUE`.
- `docs/design/boar-ai.md` section 6 still specifies the mover as `MaxForce = MAX_FORCE`; the shipped line is `Body.driveForce(geometry.bodySize, config)`. Stale design sentence — for the Architect, with `MAX_TORQUE`'s own paragraph two lines below it.
- `TASKS.md` 328n row leads the evidence with "**LIVE IN HER PLACE AT THE CODE COMMIT** (climb ladder...)", which reads as her place having run this branch. The request's own "WHAT I COULD NOT VERIFY" says the AFTER force was a runtime write. The Director's merge gate reads that row — say "in her place, with the force injected at runtime; the code's own write is proved in the harness".

---
REVIEWER verdict on commit `1aef03123110166061ef9e1770186a049dabcd78` (round 1) · 2026-11-03 14:03 UTC · session cost $2.52, 30 turns · written by tools/agents.py
