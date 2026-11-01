PASS (item 1, 3, 4, 5, 6, 7 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: NOTHING in round 3 was seen in
Karen's place. The request says so itself ("RULE 5 / STEP 3: NOTHING IN THIS ROUND WAS SEEN IN
KAREN'S PLACE ... the dispatch did not require a Forest Test proof this round"), and
`.agent-evidence/` carries no frame and no live reading at `814cb8ca`. So: a second kill inside
`CARCASS_SECONDS` clearing corpse A and keeping B's clock (claim 1), LEAVE taking the corpse
(claim 3), the missing-clock guard (claim 4), the sequence invariant (claim 5) and the trunk being
named its id -- which is what decides whether she can SEE a fresh range animal at all (claims 6, 7)
-- are proven by specs and by reading only. The pass loop's one live measurement is round 1's, at
`160c25ae`, not at this code commit, and no frame of a range CARCASS exists at any commit
(318a(f) still stands). What I verified by reading, and would stake my name on: the three numbered
round-2 findings are fixed, each with a case that is red at `64edb761`.

Harness/paperwork consistency checked: both `[harness] PASS: 34/34 ... @ 814cb8ca... (clean tree)
scope=all` and `[harness2] PASS: 36/36 ... @ 814cb8ca... (clean tree)` name the request's
`Code commit:`; `paperwork-after-code-commit.txt` reads OK (only `TASKS.md` and
`reviews/task-321/REQUEST.md` after it); selene, stylua and the Rojo build are clean; no secret,
local path or non-noreply address anywhere in the diff.

## Notes (non-blocking)

- `src/server/Range/init.luau` / `scan`'s retire block — claim 4's new disjunct is convicted by no
  case. Restore it to `trial.carcassId ~= nil and carcassAt ~= nil and now - carcassAt >=
  CARCASS_SECONDS` and the whole suite stays green: nothing in `tests/` ever produces a `carcassId`
  with `carcassAt == nil` (grep `carcassAt` over `tests/` answers only `expect(trial.carcassAt)
  .to.be.ok()`, two `.to.equal(nil)`, and the invariant sweep's own read), so that case's
  `local age = if at == nil then math.huge else clock.t - (at :: number)` line is unreachable in a
  green run and, in a red one, trips on the leave instead. One case closes it: make the fake refuse
  `clearOne` ONCE for the carcass id, then assert the slot is empty on the tick after -- green here,
  stuck for ever at `64edb761`.
- `src/server/Range/init.luau` / `clearId` — claim 4's *"AT ANY CALL SITE PRESENT OR FUTURE"* and
  *"costs one tick instead of the session"* hold for a lost CLOCK, not for a refused DESPAWN:
  `if not ok or done == false then return false end` returns without nilling `carcassId`, so a body
  removed by another hand leaves the slot set for the life of the server, retried every tick, with
  `Range.mineIdsFor` still publishing the dead id. That is round-1 note (g), queued as 321a(g) and
  deliberately not fixed; the claim reads as if it were.
- `tests/server/range.spec.luau` / `it("holds no carcass older than CARCASS_SECONDS + a tick, after
  any sequence of kills and leaves")` — the case does not stage what claim 5 says it stages. Every
  round of its loop ends with `advance(fake, clock, Range.CONFIG.CARCASS_SECONDS + 0.3)`, which
  retires every corpse, so the next round's kill wave lands on an EMPTY carcass slot and there is no
  "kills again inside the hold" anywhere in it. Revert ONLY the kill-branch ordering (claim 1) and
  this case stays green; it is red at `64edb761` through the `leave` arm alone. The second-kill half
  is carried by `it("clears the previous corpse on a second kill and keeps the NEW one's own
  clock")`, whose `expect(trial.carcassAt).to.be.ok()` is genuinely red there.
- `tests/server/range.spec.luau` / `it("names his animal's id on the wire, and after a kill both
  ids")` — `expect((live.root :: any).Name).to.equal(live.id)` is still the FAKE's own convention
  (`newFakeBoars().spawn` now writes `trunk.Name = id`) and would pass with every line of
  `src/server/Boar/Body.luau` deleted. The line that bites is the one below it,
  `expect((made.part :: BasePart).Name).to.equal(realId)` against `Body.create` (`part.Name = id`,
  handle `part = part`) -- which is what makes claim 7 true. Keep the fake line as documentation,
  but it is not evidence.
- same case — `realRoot:Destroy()` is unprotected and `Body.create` ends with `part.Anchored =
  false` / `part.CanCollide = true` / `part.Parent = folder`: if any assertion between the create
  and the destroy throws, an unnamed `Folder` with a falling boar body is left in `Workspace` for
  the rest of the run. Same shape as 318a(c); a `pcall` closes it.
- `reviews/task-321/REQUEST.md` claims 2 and 3 — no FAIL-FIRST run is pasted for round 3, where
  round 2 pasted one per case. Both rednesses are derivable from the round-2 code the verdict quotes
  verbatim and I checked them that way, so nothing is unsupported; a pasted run would have made them
  evidence rather than inference.
- `ESCALATE.md` and `TASKS.md` row 321 — the round-2 entry still reads *"NEEDS DIRECTOR"* / *"this
  cannot pass from here"* / *"round 2 is the LAST"*, all settled by the two PASS lines and the
  Director's round-3 authorisation at the foot of the same file; the TASKS row is now ~40 lines of
  three rounds' history in one cell. Prose only, and round 2 noted the first half already.

---
REVIEWER verdict on commit `47f9793e54926236748ab7900186d1d1715b6d62` (round 3) · 2026-11-01 00:51 UTC · session cost $3.77, 36 turns · written by tools/agents.py
