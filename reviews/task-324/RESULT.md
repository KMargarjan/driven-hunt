PASS (item 6 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: the pass-through has been
MEASURED in Karen's place at the code commit but not SEEN. Item 5's three crossings (4.08 / 4.11 /
3.96 s against same-session unblocked 4.05-4.21 s) are probe numbers with their own controls, which
is the right instrument for a timing. Item 6 -- "it passes THROUGH the body, not around it" -- is a
picture claim and there is no picture of it: the request's own "What I could not verify" says the
2.6-stud freeze never fired, and the one frame that exists, `324-through2.png`, is at a 5.51-stud
gap, which the same request calls "the distance at which it stopped dead on main". That frame is
therefore identical in the broken build and survives deletion of the producer; it is correctly filed
as unverified rather than offered as proof, so it is not a blocking finding, but Karen has not yet
seen a living animal inside a carcass, and she has not played the range at this commit (the kills
went through `Shotgun.Remotes.FireRequest`, not real clicks).

Checked against deletion of the producer, both spec cases bite:
- "the rule puts a carcass in its own group" calls `Body.collisionGroupFor`, which the diff creates;
  delete it and the case errors. The three non-shipped dial states use local tables, not the shipped
  config, so neither dial is proven by the state it ships at.
- "a real carcass is in the carcass group" asserts `handle.part.CollisionGroup` read back off the
  Instance. At base, `useCollisionGroup` returned false whenever `ENABLED ~= true`, so BOTH the live
  assertion (`equal(RULE.GROUP)`) and the dead one (`equal(RULE.CARCASS_GROUP)`) read "Default" and
  fail; with `Body.useCollisionGroup(part, full, true)` removed from `Body.collapse` the dead one
  reads `DrivenHuntBoars` and fails. Iteration row 2 in the request is a real negative control: the
  call present but fed the WOUND table measured as still blocking.
- `CollisionGroupsAreCollidable(RULE.GROUP, RULE.CARCASS_GROUP) == false` is asked of the engine, not
  of the config table, and with `registerGroups` deleted the groups do not exist.

## Notes (non-blocking)
- `reviews/task-324/REQUEST.md` harness block — the disclosed `FAIL: 33/34` at the same commit with
  the losing check's line lost is unexplained. The new case's `local deadline = os.clock() + 5` with
  `RunService.Heartbeat:Wait()` is a wall-clock budget under whatever else the session is running,
  which is a plausible flake source (the file's own `kill` helper uses 3 s). Queue: name the check
  before the next gate run rather than carry an unidentified intermittent.
- `src/server/Boar/Body.luau` / `registerGroups` — `collisionGroupReady` is a module-level latch and
  the function is local, so the `CARCASS_PASSES = false` engine pairing is unreachable from a spec:
  the four dial states are proven only on the pure rule, and the ENGINE pairs are only ever asserted
  at the shipped state. A `rule` parameter on an exposed pairing helper, or a reset seam, would let
  the off state be asked of the engine too.
- `reviews/task-324/REQUEST.md` claim 4 — "Nothing else about a carcass changed" overstates. One
  thing did: `CollisionGroupSetCollidable(CARCASS_GROUP, CARCASS_GROUP, ...)` makes two carcasses
  non-collidable where in `Default` they shoved each other, so two animals killed in one place now
  interpenetrate. `registerGroups`' own comment says so; the claim does not, and no case covers it.
- `src/server/Boar/init.luau` / `Runtime:_watchContacts` — "the boar's collision body is a
  `CanCollide = true` part in its own collision group (`Body.useCollisionGroup`), so animals do not
  touch each other and do not pollute this" is still false: `GROUP x GROUP` is set to
  `rule.ENABLED ~= true`, which with the shipped `ENABLED = false` is collidable. Pre-existing (it
  was false at base too, for the other reason), unchanged by this task, now sitting next to a symbol
  the diff edited.
- `src/server/Boar/init.luau` / `Boar.CONFIG.BOAR_COLLISION` — the task-127 paragraph above it still
  reads "a collision group only changes which groups collide with which, and everything else stays in
  `Default`". With `CARCASS_PASSES = true` the LIVE body no longer stays in `Default` either; the
  sentence's conclusion survives, its premise does not.
- `src/server/Boar/init.luau` / `CARCASS_PASSES = true` — a feel-critical path shipped ON with no
  `Flags` row, no `default = false` and no `expires`. It follows task 127's own `BOAR_COLLISION`
  precedent and the dial is reachable by parameter with all four states covered, which is what that
  rule exists to guarantee, so this is flagged and not pressed.

---
REVIEWER verdict on commit `5886b21e493c34c333461f27c1458fc30e8f4f37` (round 1) · 2026-11-01 10:31 UTC · session cost $2.17, 33 turns · written by tools/agents.py
