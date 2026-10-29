PASS (item 1, 2, 3, 4, 7 NOT PROVEN)

Round 3's two additions hold, and both are entered by a case that fails when its own producer is
deleted — checked by reading, and the claimed red run is consistent with the tree.

R1, `tests/server/boar_behaviour_live.spec.luau` "clearOne despawns ONE animal by id": it drives the
REAL `Boar.Runtime` the file's `beforeAll` builds (`runtime = Boar.newRuntime(buildWorld())`), not a
fake. Gut `Runtime:clearOne` to `return false` and `expect(runtime:clearOne(a.id, "spec")).to.equal(true)`
(spec line 742, the line the request names) fails. Gut only the despawn half — bookkeep without
`_despawn` — and `expect(a.part.Parent).to.equal(nil)` fails: `Body.destroy` is `handle.part:Destroy()`
and `Body.create` parents the trunk straight into the folder (`part.Parent = folder`), so the Instance
assertion is a real one. `b.part.Parent == folder` / `rootOf(b.id) == b.part` is the "and only his"
side and is a different Instance, not one value through two names. `clearOne` really is the same path:
`_despawn` is called bare at `Runtime:_step`'s `intent.despawn` too, and `_stepSounders` rebuilds
membership from `self._boars` every step, so the per-id despawn needs no sounder bookkeeping.

R2, `src/server/Range/init.luau` `scan`'s idle arm: the `continue` now lives inside
`if clearTarget(trial, "range idle") then`, so a refusal falls through to `boars.statusOf`. Restore the
`continue` and `range.spec`'s "does not hold a DEAD id for ever when the clear seam refuses" fails at
`expect(Range.stats().lostTargets).to.equal(1)` — spec line 1828, the line the request names — because
the `statusOf` cleanup is then unreachable for the whole run. The ordering the request says was
measured is the thing that makes it bite: the seam is refusing BEFORE the threshold and the animal
leaves (`fake.animals = {}`) only after it, so the cleanup cannot catch the dead id on an ordinary tick.

Fail-first chain is real: `6cbc0e6e` added both cases AND gutted both producers, `24710ac5`/`b1403cca`
fixed the case's ordering, `b1403cca` is 32/34, and `fcba11b0` restores ONLY `src/` (10 lines in
`Boar/init.luau`, 6 in `Range/init.luau`) to reach 34/34 — so the green and the red differ by the
producer and nothing else. `1844`/`1879`/`1921` are indeed `startRange` assertions in the three
following cases, which is the cascade claimed.

Harness: `[harness] PASS: 34/34 @ fcba11b0 (clean tree) scope=all` names the request's `Code commit:`;
`paperwork-after-code-commit.txt` says only `reviews/task-306g/REQUEST.md` changed after it. selene
0/0, stylua clean, rojo builds. `test2` N/A is correct — none of the five changed code paths is in
`TWO_PLAYER_PATHS` (`tools/agents.py`, the explicit match/drive/tie/team list).

The rest of the step still verifies. `occupancy` -> `playerSpot` -> `Range.spotAt` reads only
`Character.HumanoidRootPart.Position`, and `RangeData.spotAt`'s first return covers the whole union box
(`ahead >= -reach`, `reach = STAND.backStuds + footprintRadius`), so a man on the treestand deck still
occupies his station and does not lose his animal at 30 s. `Range.start` rebuilds `state.trials` and
zeroes every numeric stat, so `occupied`/`idleClears`/`wideClears` describe one run. `RangeBoot` is the
only `Range.start` caller and wires `players`, `clearOne` and `world.config.SOUND` (a `table.clone` with
`ENABLED = false`; `newRuntime` does `self._config[key] = value` wholesale for `SOUND`, and
`Body.attachSounds` returns on `not sound.ENABLED`). `grep "boars.clear("` gives exactly the two lines
claim 3 names. Design §7.4's own numbers — release when `spotAt ~= nil`, `IDLE_CLEAR_SECONDS` 30,
`SOUND` off — are what the code does. No new writer: the range reads characters and writes nothing
outside its own folder and its own runtime.

Rule 5, stated so this PASS is not read as rule 5 having been met: nothing in this step has been seen
in Karen's place. Items 1, 2 and 7 were seen live in DEV only (the Builder's `Workspace.RangeTargets`
child counts and three frames I cannot see); items 3 and 4 — the carcass and the pick cleared per
station — were seen in NO live run at all, their only evidence being `range.spec` and now R1's live
`clearOne` case. The DEV numbers are at least arithmetically possible in this code: station 2's mat is
x 1224 (`SPOT_SPACING_STUDS` 24) and its own west lane end is 1224 - 38 (`laneLength` = 36 + 2*20),
which is the 1186 the request read, 24 studs from station 1's 1162. Her place is B8 and the proof is
B9. For the merge gate: items 1, 2, 3, 4, 7 are NOT PROVEN in Karen's place.

## Notes (non-blocking)
- `src/server/Range/init.luau` / `occupancy` — the `if players == nil then return out end` guard has no
  case of its own: delete that line and `pcall(players)` on a nil seam already fails closed, so
  "releases nothing at all when the root wired no player list" stays green. The claim-5 BEHAVIOUR is
  still produced and the case does go red when the `occupied` gate in the release arm is removed, so
  nothing passes for the wrong reason — the second guard is simply invisible to the gate. If it is
  meant to be the load-bearing one, assert it where it differs (a `players` seam that RAISES versus one
  that is absent).
- `src/server/Range/init.luau` / `Range.onRequest`'s respawn arm — it calls `clearTarget(trial, "range pick")`
  and then `trial.targetId = nil` regardless of the answer. That is round-2 note 2's shape without the
  `statusOf` net: on a refusal the owner forgets the id, so nothing steers that animal and nothing
  clears it before `Range.stop`. Dark in the shipped wiring, because `runtime:clearOne` answers `false`
  only for an id that is already out of `_boars` — but a raise inside `_despawn` would orphan a body on
  the lane. One `if` (nil the id only when the clear succeeded, else leave it for the next scan's
  `statusOf`) closes it the same way the idle arm was just closed.
- `src/server/Range/init.luau` / `playerSpot` — declared `: number?`, and its last statement is
  `return Range.spotAt(position)`, which returns `(number?, string?)`. Every caller takes one value, so
  it is harmless today; `local spot = Range.spotAt(position); return spot` makes the signature true.
- `tests/server/range.spec.luau` / "counts a range-WIDE clear when the root wired no clearOne" — after
  the wide clear it asserts `fake.at(1) == nil`, which holds only because the run ends ~1 s after the
  clear and `RELEASE_SECONDS` is 2: lower that constant and the case goes red for a reason that is not
  the defect. Assert the re-release explicitly, or advance a known amount past the clear.
- `reviews/task-306g/REQUEST.md` claim 8 — "this module still reaches no DataModel" is too strong:
  `src/server/Range/init.luau` opens with three `game:GetService` calls and `Range.start` falls back to
  `Workspace` for its root. What is true, and is the claim that matters, is that the OCCUPANCY path
  reads no `Players` service and believes no payload field.
- Still open from round 2 and already queued by the Builder, repeated here only so the Director's row
  keeps them: design §7.4's "through the shipped `boars.spawn` / `boars.clear` verbs" and §9.2's "exactly
  two readers" are stale (must-fix 1 added a third, plus the `players` seam); design §12's T10 row names
  `Range.stats()`, which carries no step-time field, so claim 10's 0.0209 ms is measured by an
  instrument that row does not name; `fake.clearOne`'s comment still says "wired exactly as `RangeBoot`
  wires it" while it also bumps `fake.clears`; and `startRange`'s default six-man crowd means group 12
  is the only place a partly occupied range is exercised.

---
REVIEWER verdict on commit `7be5f4ebfa1d1f4ac532e6f9d268fc9e0cfd0f12` (round 3) · 2026-10-29 15:00 UTC · session cost $5.17, 57 turns · written by tools/agents.py
