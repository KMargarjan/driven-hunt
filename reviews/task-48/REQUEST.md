# Task 48 — audit-004's test-integrity items (row 47c F1, F2, F3, F4, F5, F10)

Task: 48
Round: 2
Base: `5a17776` (task-47-audit004; stacked on 45, 44, 43, 41, 38, 36 and 35, none merged)
Code commit: `630b8670de5018d90562eb664acc3dc33da4782a` — this request's own commit, which is what
both harness lines name (CLAUDE.md git workflow step 4). The last commit that changed `src/`, `tests/`
or `tools/` is `3759e93`, and only this fill-in changed after it.

Harness, clean tree, one player:

    [harness] PASS: 28/28 checks @ 630b8670de5018d90562eb664acc3dc33da4782a (clean tree)

Harness, clean tree, two players — run by the DIRECTOR, not by me:

    [harness2] PASS: 30/30 checks @ 630b8670de5018d90562eb664acc3dc33da4782a (clean tree)

**Run TWICE at this commit, 2 of 2 PASS**, on the Director's instruction after the watcher race failed
two of the previous three runs. It did not recur.

307 server specs (303 before this task), 75 shooter-client, 69 driver-client. **28 harness checks, not
27**: the drive-clock seam is one of them now.

**THE `test2` RACE THAT RAN THROUGH THIS TASK IS FIXED HERE.** `weapon_client.spec:246`
(`Weapon.Input.watchedTools() <= 1`) failed in two of the Director's three `test2` runs — at `7adcb75`
(FAIL, then PASS) and again at `3e26863` (FAIL). That is a real race in the client Tool watcher, not a
flake in the test, and the Director's instruction was to fix the cause where the set is written and
keep the test strict. Claim 10. **Both runs at this commit passed.**

## What changed

Six findings from `docs/architecture/audit-004.md`'s fix-before-release list — all of them tests that
could not fail, or tests that damaged the run they were in. Round 1 found one real defect in my own
work (claim 8).

## Claims

1. **F1 — one genuine failure no longer arms everybody for the rest of the run.**
   `zz_drive_boundary.spec` installed a **throwing** arming policy and restored it four `expect`s later
   in the same `it`; TestEZ abandons an `it` at the first failure, including the
   `pcall(Weapon.refreshArming, …)` that is the falsifying case. It gathers its observations under the
   broken policy inside a `pcall`, **restores unconditionally**, and asserts afterwards, with a second
   `it` asserting the live owner is back on the drive's rule whatever happened above. Demonstrated: I
   injected `error(…)` into the gathering block on a dirty tree and got
   `[tests:server] FAIL: 306 passed, 1 failed` — **one** failed spec, and the three after it, including
   the new restore assertion, all passed. Before this change that failure was four.

2. **F2 — the marker-count total is measured against the configuration.** It compared
   `MapGen.expectedCounts()` with `planned + tieTrees`: the same arithmetic over the same data, true
   for any layout, and the twin of the defect Task 44 round 1 caught in the neighbouring test. It now
   compares against `postCount + #boarSpawnX + 2 + tieTrees` read from `WORLD`, so changing
   `postCount` alone fails it. **Not demonstrated by a run** — breaking the configuration would break
   four other tests — and the reasoning is two expressions side by side.

3. **F3 — the map carries the seed it was built from.** `MapGen.digest()` reported `Map.SEED`, which
   is `0` while `EXPECTED_WORLD` is `"arena"`, so `mapgen.py digest` printed `"seed": 0` for a map
   built from seed 7 — the field M2.5 step 6 copies into the contract. `ensureRoot(seed)` writes a
   `MapGenSeed` attribute on the map root; `digest`, `verifyContract` and `MapGen.builtSeed()` read it
   back, and answer **nil** when there is no map or it predates this — the honest answer, where `0` was
   not. The attribute is not a script and does not enter the digest.

4. **F4 — the streaming step refuses instead of writing.** `Settings.MAY_WRITE = false` until M2.6
   runs; `Settings.apply` collects a `refused` list instead of writing and the step reports
   `REFUSED (M2.6 has not run)`. Two specs: one hands it a contract that **disagrees** with the place
   and asserts nothing moved and `StreamingEnabled` is named in `refused`; one asserts the agreeing
   case writes nothing and refuses nothing.

5. **F4's demonstration corrected the test.** With `MAY_WRITE = true` the spec failed at its FIRST
   assertion — `expect(Settings.MAY_WRITE).to.equal(false)` — and never reached the part that proves
   the place was not written: TestEZ's abandon rule, this task's own subject, biting the task. The
   behaviour is asserted first now and the constant last. The same run showed Roblox **raises** rather
   than writing `StreamingEnabled` at run time; the hazard the audit names is the edit-time one, where
   the generator runs, and a spec cannot reach it.

6. **F5 — the drive's clock seam closes with the run, and the evidence is observed from outside.**
   `TestKit.run`'s `finish()` — the single exit from every path — clears `activeToken`, which is what
   `Match.advanceForTests` asks "is a gated test run in progress". `TestRunner` then reports
   `seamClosed = TestKit.activeToken() == nil` **after `run` returns**, rather than on the line below
   the assignment that makes it true (round 1 note), and the harness checks that field. Removed the
   clear, on a dirty tree:

       FAIL the drive-clock seam closed when the server run finished  (False)
       [harness] FAIL: 27/28 checks @ 7a3db87 (DIRTY TREE …)

7. **F5's first attempt could not fail, and the measurement is why.** I first asked the server through
   `execute_luau` whether `activeToken()` was nil — and it answered `"closed"` **with the fix
   reverted**. A query that requires `ReplicatedStorage.TestKit` gets a **different instance** from the
   runner's, out of its own require cache: adding a function to `TestKit` and calling it from the query
   raised `attempt to get length of a nil value`.

8. **The seam check no longer aborts the run it is checking** (round 1's blocking finding, right, and
   the worst class of harness fault). `reports["server"]` raises `KeyError` when the server report does
   not arrive inside `REPORT_WINDOW` — the failure that window has been widened for twice — so an
   eight-minute run would have ended in a traceback with no `[harness] FAIL: n/m checks` line and no
   HEAD check. It reads `(reports.get("server") or {})` now, so a missing report **fails** the check.
   The `tools/studio_mcp.py` docstring, which `CLAUDE.md` calls the single source of truth, carries
   `seamClosed` and the new check.

9. **F10 — the pad spec asks the question the terrain answers.** It called `Height.atFlattened`
   without `bogDepth`, which is optional, so nothing said it was asking something else. It passes
   `Layout.bogDepth` now, as `Ground.writeTile` does, and a new test measures what the argument is
   worth: at the bog's centre, omitting it is wrong by exactly `bog.depth` studs; outside the bog it
   changes nothing.

10. **The `watchedTools()` race is FIXED in the owner, not worked around in the test** (Director,
    after `test2` failed on it in two runs of three). A dead Tool was dropped only by its own
    `AncestryChanged` with `parent == nil`, and Roblox's signals are **deferred** (measured in Task
    47) — so on a respawn the new Tool, granted on `CharacterAdded` and delivered through the new
    Backpack's `ChildAdded`, was watched **before** the old one's handler ran; and a Tool whose parent
    never became nil was never forgotten at all. `watchTool` now sweeps the set before adding to it
    (`isLive` = in the player's CURRENT Backpack or character; `pruneWatched` drops the rest),
    `Destroying` is hooked beside `AncestryChanged`, and the ancestry handler asks `isLive` rather
    than testing for nil. `bind` records which Tool it bound for so `forgetTool` cannot unbind the
    live gun's trigger while dropping a dead Tool. **The test stayed strict**, and a new one
    reproduces the ordering without depending on signal order — measured against the old watcher:

        failed [client] weapon_client.spec:290 the watcher held 3 Tools where 2 is the ceiling: a dead
        Tool was still watched when a new one arrived (24a(c), Task 48)

## What I could not verify

* **The watcher fix is proved against the construction, not against a respawn.** The new spec makes a
  dead Tool the old rule could not see and shows the count reaching 3; I never caught the real
  two-player respawn at 2, because I cannot run `test2`. The two are the same defect — a dead entry
  outliving a new one — and the fix removes both, but only the constructed one is measured here.
* **Two clean `test2` runs are evidence, not proof, that the race is gone.** It failed two of three
  before the fix and none of two after it; the construction it is proved against is in claim 10.
* **F2 was not demonstrated by a failing run** (claim 2), and **F3 has no spec**: a server spec cannot
  build a map root without breaking the "exactly one world" check in the same run. F3 is verified by
  running `mapgen.py digest`.
* **F4's edit-time behaviour is unverified** — a spec can only exercise the run-time path, where the
  engine refuses the write anyway (claim 5).
* **The seam check covers the one-player run only.** `run_test2` has no equivalent; adding one I
  cannot run would risk failing the Director's run. Row 48a(b).
* **The dirty-tree demonstrations are evidence that the checks bite, not evidence of the committed
  state.** The committed state is the clean-tree line at the top.
