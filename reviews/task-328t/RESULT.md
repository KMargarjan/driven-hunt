PASS

Rule 5, stated so this PASS is not read as rule 5 having been met: there is NO core item in this
change and nothing was seen in Karen's place, because nothing she plays changed --
`.agent-evidence/changed-files.txt` is `reviews/task-328t/REQUEST.md`, `tests/TestKit.luau`,
`tests/TestRunner.server.luau`, `tests/server/weapon_equip.spec.luau`, `tools/studio_mcp.py`, and
not one file under `src/`. No animal behaviour and no shooting path is touched, so there is nothing
for her to judge and the bare `PASS` asserts nothing about her screen.

Duty (a), delete the producer, done by reading:
- `tests/server/weapon_equip.spec.luau`, the late-mesh case. Delete the mesh dressing it is built on
  (`Hardware.upgrade`'s `addMesh`, or `Weapon.upgradeLook`'s `after` callback) and the case still
  goes red: `waitUntil(TEMPLATE_WAIT, ...)`'s answer is discarded, but `if not
  Hardware.wearsMesh(tool) then error("the gun mesh template is not available ... after %d s")`
  fires, and with only the `after` callback deleted `expect(waitUntil(3, function() return
  tool.Parent == player.Character end)).to.equal(true)` fires. No added line is an assertion, and no
  assertion was removed (diff confirms): the two new `waitUntil`s delay, they do not assert.
  Nothing here is a value compared with itself.
- `TestKit.atEveryNode`'s yield. Delete it and `task.wait()` never runs, the runner thread is killed
  again, `ServerStorage.TestReport` is never set and the harness's own
  `check(f"[{side}] runner reported within {REPORT_WINDOW} s", report is not None)` goes red. The
  claimed PASS cannot survive its deletion, and the failure mode is loud either way: if
  `TestEZ.TestRunner.runPlanNode` were not the field this assumes, `inner` would be nil, the call
  would throw inside `TestKit.run`'s `pcall`, and the report would read `TestEZ run threw: ...`.
- `tools/studio_mcp.py`'s `INPUT_RETRY` loop. No case is offered for it and none exists -- see note 6.
  I read the loop instead: nothing can be swallowed, because the second `if failure is not None:`
  still appends to `problems` unless the re-send genuinely returned `None`.

Evidence checks that pass: `[harness] PASS: 34/34 checks @ 1fd399b3c7a18bd58f7c9fc1d5ae6cc3d122a8f6
(clean tree) scope=all` names the request's `Code commit:` exactly, is "(clean tree)", is `scope=all`,
and `.agent-evidence/paperwork-after-code-commit.txt` says OK (only `reviews/task-328t/REQUEST.md`
followed it). selene 0/0/0 twice, stylua clean, rojo build exit 0. Claim 8's mechanism is real
(`src/shared/ForestTest/init.luau` `partName = "StagRoar"`, `tests/server/boar_hit.spec.luau`
`testRoot.Name = "BoarEscapeSpec"`), so the three deleted instances are runtime leftovers, not
authored content, and rule 7 does not reach them. Claim 9's premise is real: `Hardware.TOOL_NAME =
"Shotgun"` and `Weapons.PRIMARY = "shotgun"` with `toolName = "Shotgun"`, so with `Weapon.heldId`
nil `upgradeLook`'s `id ~= (held or Weapons.PRIMARY)` guard lets the probe through. No secret, no
local path, no non-noreply email, no second writer -- `TestStage`/`TestStageTrail`/`TestStageAge`/
`TestStageErrors` are written only by `tests/TestRunner.server.luau`'s `mark`, which is not the
`DHFlag_*` prefix `tools/studio_mcp.py` owns.

## Notes (non-blocking)
- `tests/ClientTestRunner.client.luau` / `QUERY_TEST_STAGE["client"]` — the client half of the new
  instrument is dead. Nothing anywhere writes a player `TestStage` attribute (grep for `TestStage`
  finds only `tools/studio_mcp.py` and `tests/TestRunner.server.luau`), and ClientTestRunner never
  sets `TestKit.onStage`, so `TestKit.stage` is a no-op there. `'local p = ... return p and
  tostring(p:GetAttribute("TestStage")) or "no player"'` can only ever answer the string `"nil"`,
  and a future client-side non-report will print `[harness] client never reported; its last stage
  was nil` -- the uninformative answer this task exists to abolish. Fix: one line in
  ClientTestRunner (`TestKit.onStage = function(name) Players.LocalPlayer:SetAttribute("TestStage",
  name) end`), or drop the client key.
- `tools/studio_mcp.py`, `run_test`'s report check — the detail is now passed unconditionally, and
  `check` prints it on success too (`print(("  ok   " if ok else "  FAIL ") + name + (f"  ({detail})"
  if detail else ""))`). A green run now reads `ok   [server] runner reported within 300 s  (last
  stage: ?)`. Pass the detail only when `report is None`.
- `tests/TestRunner.server.luau` — the `TestStageAge` ticker (`while true do task.wait(5)`) and the
  `LogService.MessageOut` connection are never stopped on the `mark("no-token")` path, so both run
  for the whole of Karen's playtest session, where no run exists to instrument. Return from the
  spawned thread and `:Disconnect()` the trap before that `return`.
- `tests/server/weapon_equip.spec.luau`, `realGunOf` + the new template wait — `Hardware.toolsOf`
  walks `Backpack` then `Character` in `GetChildren()` order with `Weapons.isToolName`, so `realGun`
  may be the RIFLE. `waitUntil(TEMPLATE_WAIT, function() return Hardware.wearsMesh(realGun :: Tool)
  end)` then waits for the rifle's `MESH_NAMES` while the case needs `shotgun.handle`, and the
  flake the wait was added for can come back. Wait on the primary:
  `Hardware.toolsOf(player, Weapons.PRIMARY)[1]`.
- `tests/server/weapon_equip.spec.luau` — both new `waitUntil` answers are discarded. If the
  `heldId`-goes-nil premise is not met in 2 s the case still runs and fails downstream at
  `expect(waitUntil(3, function() return tool.Parent == player.Character end)).to.equal(true)`,
  which names the symptom and not the unmet premise. `error("heldId did not clear", 0)` on a false
  answer would say it once.
- `tools/studio_mcp.py`, `replay_input`'s retry — three small things. (1) `print(f"[input] ...
  {target} stayed unreachable for {INPUT_RETRY} s")` also fires when the loop broke out on a
  NON-loading error, so the message names the wrong reason. (2) `target` can be `None` (a one-player
  `test`, `targets = [studio_id] + ...`), so the line reads `None stayed unreachable`. (3) the
  re-sends are added to neither `calls` nor `call_seconds`, so `[input] N batch call(s) ... took X s`
  now under-reports. Nothing proves the loop runs: `selftest`'s own fake is three lines away
  (`class StagingStudio: def send_input_many(...): return {studio_id: None for ...}`) and always
  answers success, so CI cannot reach the branch; a fake that answers `RuntimeError("Target is not
  reachable")` once and then `None` would pin it in the file that already has the harness.
- `tools/studio_mcp.py` — `INPUT_RETRY = 20` is inserted between `REPORT_WINDOW`'s own explanatory
  comment ("One deadline for BOTH reports ... burned the whole window before the client was looked
  at once.") and `REPORT_WINDOW = 300`, so that comment now reads as INPUT_RETRY's. Move it above
  the block it explains.
- `tools/studio_mcp.py` docstring — the test-system description still lists only `Report:
  ServerStorage attribute "TestReport"`. It is the stated authority for the test system ("Full
  description: tools/studio_mcp.py docstring", cited from both runners), and the four new attributes
  and the `YIELD_AFTER` seam are not in it.
- `reviews/task-328t/REQUEST.md`, "Could not verify" — both queue claims are false against the repo.
  `TASKS.md` is not in `.agent-evidence/changed-files.txt`, and grep finds no `328t`, no `L-149` and
  no `Brain:838` in it; `L-149` appears in exactly one file in the repository, `REQUEST.md` itself.
  So the `Brain:838 attempt to index nil with 'minX'` nil-index and the `deer_hitbox.spec:659/:682`
  intermittents are carried by nothing. Request/TASKS prose is a note by rule, but the two defects
  need a row before this merges or they are lost.
- `tests/server/forest_stand.spec.luau` (in scope only as a blast-radius namer; unchanged here) —
  `expect(before).to.equal(1)` counts `Workspace:GetChildren()` by `Data.ROAR.partName`, so it reds
  on any saved leftover of a name a spec builds at runtime. Claim 8's fix was environmental and only
  on Karen's machine; `tests/server/boar_hit.spec.luau` makes `Workspace.BoarEscapeSpec` the same
  way. Queue a task: either the specs clean up their Workspace children, or the count excludes
  anything not built by this `start`.

---
REVIEWER verdict on commit `16745ac23c56089781c4fda0d1d88cfca36c7034` (round 1) · 2026-11-04 06:32 UTC · session cost $3.35, 44 turns · written by tools/agents.py
