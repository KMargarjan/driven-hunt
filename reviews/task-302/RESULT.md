PASS (item 1 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: nothing in this change is a core
item (no animal behaviour, no shooting), and NOTHING in it has been seen in Karen's place. The thing
she will judge -- walking from the lodge to the range mat and standing there past
`RETURN_COOLDOWN_SECONDS` -- is claim 1's subject and is unseen; `ForestTestBoot` returns at
`if Map.EXPECTED_WORLD ~= "forest-test" then return`, so the harness (DEV) cannot run the wiring
Karen's place runs, and `Lobby.ANCHORS` has no `map:v1` row. The request says the same. The
parenthesis records that, not a core item. The harness line names the request's `Code commit:`
`54093f57...` with "(clean tree) scope=all", and `paperwork-after-code-commit.txt` says OK (only
`TASKS.md` and `REQUEST.md` followed it). `test2` N/A is correct: none of the seven code/test files
is under `TWO_PLAYER_PATHS` (`src/server/Match/`, `MatchBoot`, `src/client/Match/`, `src/shared/Drive/`
and the named match/tie/role specs).

Delete-the-producer, by reading, on the cases the request offers:
- `lobby_live.spec` *"leaves a man at the range and on the walk there alone"* -- revert `stepPlayer`
  to `Join.insideField` and `:1047` (`expect(placedWith[61]).to.equal(nil)`) fails; delete
  `Lobby.start`'s `homeAreas = Join.homeAreas(...)` and `homeAreas` stays `{}` from `Lobby.stop`, so
  `insideHome` is false for all three men and `:1047` fails again; delete `Join.homeAreas` or
  `Range.footprintFor` and the case errors. `fresh` returns `seen` first, `Lobby.step` reaches
  `stepPlayer` with `inDrive`/`held` false, and `Lobby.start`/`stop` both `table.clear(returnedAt)`
  so the two halves cannot contaminate each other. The asymmetry is real and dies with the change.
- the five pure cases error at the base through `RangeData.footprintFor` (`lobby.spec:248` is the
  drive-clearance case's own call; `union()` is at `:940`, called at `:954/:993/:1042/:1087` --
  claim 3's five line numbers are exact).
- the numbers check out independently: footprint x 2558..2742 z -3368..-3200 (halfX = max(BERM 80,
  screenOut 51, MAT 4), nearZ -3212, farZ -3356, margin 12); walkway x 2626..2874 z -3308..-2926;
  both intersections non-empty, and the lodge->mat segment lies wholly inside the walkway box, so
  the walk has no gap. Claim 5's skip pattern gives exactly rect1:2, rect2:2, rect3:3 = 7. Claim 6's
  second grid gives exactly 738 differing points (678 walkway-outside-field + 60 footprint-only).
  Claim 8: the worst corridor gap is 180 (lodge vs `edge`, standSpan 3140..3660) and the worst
  bounds gap 120 (lodge vs `edge` bounds minX 3080), against thresholds 100 and
  `BOUNDS_SLACK` 10 + 40 = 50; the new rectangles' worst is 206, as claimed.
- claim 9's substance holds: no `require` of `Range` anywhere under `src/server/Lobby/`, and
  `Range.ENABLED = Flags.isOn("RANGE")` stays the single flag boundary -- `ForestTestBoot` reads
  `RangeOwner.ENABLED`, not a second `Flags.isOn`, and uses the same
  `anchorFor(Map.EXPECTED_WORLD)` row `RangeBoot` builds from.

## Notes (non-blocking)
- `reviews/task-302/REQUEST.md` claim 1 -- *"`ForestTestBoot`'s `rangeHomeAreas` [is] on that
  path"* is not true. `lobby_live.spec` never requires `ForestTestBoot` and cannot (it returns at
  line 25 outside `forest-test`, and the harness only runs DEV); the spec re-types the same
  expression and writes `world.homeAreas` itself. Delete the entire `rangeHomeAreas` `do` block and
  no case fails. The five lines are correct by reading -- same row key and same
  `footprintFor(Vector3.new(row.x, 0, row.z), RangeData.LAYOUT, RangeData.downrangeOf(row))` as
  `RangeBoot`'s own anchor -- which is why this is a note and not a finding, but the wiring Karen's
  place actually executes is proven by reading only. If B6 wants it covered, the 301 shape applies:
  move the row+flag+footprint composition into `Range.homeAreasFor(world)` and let both the root and
  the spec call it.
- `src/server/Lobby/Join.luau` `insideField` header -- *"IT IS THE ONLY QUESTION THE RETURN RULE
  ASKS about where a man is standing"* is now false; the return rule asks `insideHome`. One line.
- `src/server/Lobby/Join.luau` `needsReturn` -- the third parameter and its header paragraph are
  still `inField` after round 1's note moved `stepPlayer`'s local to `inHome`; the same rename here
  finishes it.
- *"the mat is 268 studs from the anchor"* (`Join.luau` header, `Lobby/init.luau` `stepPlayer`,
  `ForestTestBoot`, `lobby.spec`, the request) -- 268 is not any of the distances: anchor
  (2850, -2950) to mat (2650, -3216) is dx 200, dz 266, 333 Euclidean; to the measured character
  (2650, -3214) it is 264 / 331. The load-bearing part (outside the 110 half-span) is true either
  way; one number, five copies.
- `reviews/task-302/REQUEST.md` claim 9 -- *"`grep -n Range src/server/Lobby/*.luau` -> nothing"* is
  not what that grep prints: `Join.luau`'s own new header names `Range.footprintFor`, and
  `Build.luau` has `lamp.Range`, `light.Range`, `beam.Range`, `NumberRange.new`. The claim that
  matters -- no `require` -- is true; say that instead.
- `reviews/task-302/REQUEST.md` claim 7, live half -- *"still leaves a man at the range who is in
  the drive or held"* survives the narrow mutation (reverting `stepPlayer`) untouched, because
  `inDrive`/`held` short-circuit before the position is read. It is an invariance guard, which is
  how the request labels it; it carries no weight for the fix.
- `TASKS.md` row 302 -- *"`[]` for all six changed files"*; it is seven
  (`ForestTestBoot.server.luau`, `Lobby/Join.luau`, `Lobby/init.luau`, `shared/Lobby/init.luau`,
  `shared/Range/init.luau`, `lobby.spec.luau`, `lobby_live.spec.luau`), as the request says.
- Round 1's notes (b), (c), (d) and the `docs/design/lobby.md` 8.1/16.1 update are queued as 302a
  and not re-raised here; 8.1 and 16.1 still describe the rule as `insideField` over the 220 x 220
  field, so a reader of the design will not find this change until 302a lands.

---
REVIEWER verdict on commit `bd4ee381318c5e58b69dc0dbf2ce55e5e6d653df` (round 2) · 2026-10-28 03:21 UTC · session cost $3.67, 39 turns · written by tools/agents.py
