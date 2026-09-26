# Task 48 — audit-004's test-integrity items (row 47c F1, F2, F3, F4, F5, F10)

Task: 48
Round: 1
Base: `5a17776` (task-47-audit004; stacked on 45, 44, 43, 41, 38, 36 and 35, none merged)
Code commit: `7adcb754041f88ec154f92df36189a9546c6f9bc` — this request's own commit, which is what
both harness lines name (CLAUDE.md git workflow step 4). The last commit that changed `src/`, `tests/`
or `tools/` is `163ed7c`, and only this fill-in changed after it.

Harness, clean tree, one player:

    [harness] PASS: 28/28 checks @ 7adcb754041f88ec154f92df36189a9546c6f9bc (clean tree)

Harness, clean tree, two players — run by the DIRECTOR, not by me:

    [harness2] PASS: 30/30 checks @ 7adcb754041f88ec154f92df36189a9546c6f9bc (clean tree)

307 server specs (303 before this task), 74 shooter-client, 68 driver-client. **28 harness checks, not
27**: the drive-clock seam is one of them now.

**AND THE RUN BEFORE IT FAILED, at the same commit.** The Director ran `test2` twice at `7adcb75`:

    run 1:  [harness2] FAIL: 28/30 — shooter 73 passed / 1 failed
            weapon_client.spec:246  Weapon.Input.watchedTools() <= 1   (the 24a(c) watcher-leak test)
    run 2:  [harness2] PASS: 30/30 checks @ 7adcb754041f88ec154f92df36189a9546c6f9bc (clean tree)

That test is **intermittent**, it is not one this task touched, and the PASS above is therefore a pass
with a known flake behind it. What I believe causes it is claim 11; it is queued as row 48a, not fixed,
because the dispatch says so and because a guess dressed as a fix is worse than a queued diagnosis.

## What changed

Six findings from `docs/architecture/audit-004.md`'s fix-before-release list, all of them about tests
that cannot fail or tests that damage the run they are in. Where a fix could be shown to bite, it was
run with the fix removed and the failure is quoted.

## Claims

1. **F1 — one genuine failure no longer arms everybody for the rest of the run.**
   `zz_drive_boundary.spec` installed a **throwing** arming policy and restored it four `expect`s
   later in the same `it`; TestEZ abandons an `it` at the first failure, including the
   `pcall(Weapon.refreshArming, …)` that is the falsifying case. It now gathers its observations under
   the broken policy inside a `pcall`, **restores unconditionally**, and asserts afterwards — with a
   second `it` that asserts the live owner is back on the drive's own rule whatever happened above.

2. **F1, demonstrated.** I injected `error("INJECTED FAILURE: …")` inside the gathering block, on a
   dirty tree, and ran the harness:

       [tests:server] FAIL: 306 passed, 1 failed, 0 skipped, 1 errors, 20 spec files

   **One** failed spec — the policy test itself — and the three specs after it, including the new
   restore assertion, all passed. Before this change that same failure skipped the restore and left
   the live server on a policy that throws, which is four failures, not one.

3. **F2 — the marker-count total is measured against the configuration.** It compared
   `MapGen.expectedCounts()` with `planned + tieTrees`, which is the same arithmetic over the same
   data: true for any layout, right or wrong, and the twin of the defect Task 44's round 1 caught in
   the neighbouring test. It now compares against `postCount + #boarSpawnX + 2 + tieTrees` read from
   `WORLD`, so changing `postCount` alone fails it. **Not demonstrated by a run**: breaking the
   configuration to show it would also break four other tests, and the reasoning is checkable by
   reading the two expressions.

4. **F3 — the map carries the seed it was built from.** `MapGen.digest()` reported `Map.SEED`, which
   is `0` while `EXPECTED_WORLD` is `"arena"`, so `mapgen.py digest` printed `"seed": 0` for a map
   built from seed 7 — and M2.5 step 6 copies that field into the contract. `ensureRoot(seed)` now
   writes a `MapGenSeed` attribute on the map root, and `digest`, `verifyContract` and
   `MapGen.builtSeed()` read it back. No map, or one built before this, answers **nil** — the honest
   answer, where `0` was not. The attribute is not a script and does not enter the digest, which
   covers names, classes, positions, sizes and tags.

5. **F4 — the streaming step refuses instead of writing.** `Settings.MAY_WRITE = false` until M2.6
   runs; `Settings.apply` collects a `refused` list instead of writing, and the step reports
   `REFUSED (M2.6 has not run)`. Two specs: one hands it a contract that **disagrees** with the place
   and asserts nothing moved and `StreamingEnabled` is named in `refused`; one asserts the agreeing
   case still writes nothing and refuses nothing.

6. **F4, demonstrated — and it corrected the test.** With `MAY_WRITE = true` (the pre-fix behaviour)
   the spec failed, but at its FIRST assertion, `expect(Settings.MAY_WRITE).to.equal(false)`, so it
   never reached the part that proves the place was not written — TestEZ's own abandon rule, which is
   this task's subject, biting the task. The behaviour is asserted first now and the constant last.
   The second run also showed that at RUN time Roblox **raises** rather than writing
   `StreamingEnabled`; the hazard the audit describes is the EDIT-time one, where the generator runs.

7. **F5 — the drive's clock seam closes with the run.** `TestKit.run`'s `finish()` — the single exit
   from every path, including the early returns — clears `activeToken`, which is what
   `Match.advanceForTests` asks "is a gated test run in progress". Left set, the seam stayed open for
   the rest of a Studio session a human is about to play in.

8. **F5's first check could not fail, and the measurement is why.** I first asked the server, through
   `execute_luau`, whether `TestKit.activeToken()` was nil — and it answered `"closed"` **with the fix
   reverted**. A query that requires `ReplicatedStorage.TestKit` gets a **different instance** from the
   one the runner is using, out of its own require cache: adding a function to `TestKit` and calling it
   from the query raised `attempt to get length of a nil value`. The evidence now travels in the
   runner's own report (`report.seamClosed`, computed in the instance that ran), and the harness checks
   that field. Removed the clear, on a dirty tree:

       FAIL the drive-clock seam closed when the server run finished  (False)
       [harness] FAIL: 27/28 checks @ 7a3db87 (DIRTY TREE …)

9. **F10 — the pad spec asks the question the terrain answers.** It called
   `Height.atFlattened` without `bogDepth`, which is optional, so nothing said it was asking something
   else. It passes `Layout.bogDepth` now, as `Ground.writeTile` does, and a new test measures what the
   argument is worth: at the bog's centre, omitting it is wrong by exactly `bog.depth` studs, and
   outside the bog it changes nothing.

11. **The intermittent failure, diagnosed but not fixed.** `it("listens to ONE Tool, however many
    the session has destroyed")` asserts `Weapon.Input.watchedTools() <= 1` at one arbitrary moment.
    `src/client/Weapon/Input.luau` watches a Tool from `ChildAdded` on the Backpack (`watchTool`) and
    forgets it from **`tool.AncestryChanged`** when its parent becomes nil (`forgetTool`) — and
    Roblox's signals are **deferred**, which I measured in Task 47 for `DescendantAdded`
    (`synchronous=false ; afterOneWait=true`). So on a respawn the order is: the old Tool is destroyed
    with the old character; the server grants a new one (`Weapon.grant` on `CharacterAdded`); the new
    Tool lands in the new Backpack and is watched **immediately**; the old Tool's `AncestryChanged`
    handler runs at the next resumption point. Between those two, `watchedTools()` is legitimately
    **2**. The drive places players through `Match.Body.place` → `LoadCharacter`, so in a two-player
    run that window can fall exactly where this spec samples.
    **That is a timing assumption in the test, not a leak in the owner** — a real leak would never
    settle. The fix I would write is to retry for a second or two and fail only if it stays above one,
    which still catches the leak 24a(c) was about. Row 48a carries it, and **I did not change the code
    this round**: the dispatch says to queue it unless the review makes it blocking, and I cannot run
    `test2` myself to show a fix worked.

10. **Nothing else changed.** `git diff --stat 5a17776..163ed7c`: `TestKit.luau`, two server specs,
    three `MapGen` files and `tools/studio_mcp.py`. No gameplay change, no new generator step.

## What I could not verify

* **F2 was not demonstrated by a failing run** — see claim 3. The change is a two-line reading.
* **F4's edit-time behaviour is unverified.** The spec can only exercise the run-time path, where the
  engine refuses the write anyway. At edit time — the generator's own build step, which is the hazard
  — the write would land; that path has never run, because the contract has always matched the place.
* **F3 has no spec.** A server spec cannot build a map root without breaking the "exactly one world"
  check in the same run. It is verified by running the tool: `mapgen.py digest` reports the seed the
  map carries, and `nil` when there is no map.
* **The seam check covers the one-player run only.** `run_test2` has no equivalent; adding one I
  cannot run myself would risk failing the Director's run. Queued for 48a.
* **The three dirty-tree demonstrations are not evidence of the committed state** — they are evidence
  that the checks bite. The committed state is the clean-tree line above.
* **Claim 11 is a reading, not a measurement.** I did not catch `watchedTools()` at 2: the failing run
  was the Director's and I cannot run `test2`. The deferred-signal half IS measured (Task 47); the
  respawn ordering is read from `Input.watchTool` / `forgetTool` and `Weapon.grant`.
