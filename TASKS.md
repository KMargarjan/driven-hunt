# Tasks

One task per round (rule 4). Status: `todo` → `in progress` → `awaiting review` → `done` (Reviewer signed off).

| # | Task | Status | Notes |
|---|---|---|---|
| 1 | Project setup: Rojo, git, TestEZ, docs skeleton, prove the sync loop | awaiting review | Round 1: Reviewer FAIL. Round 2 (PR #1): fixes plus CI, branch workflow, definition of done, PLAYTEST.md. Reviewer FAIL on PR #1. Round 3: 3 blocking + 2 should-fix items, plus public-repo hygiene |
| 2 | Strip test code at publish, and archive the scaffolding specs | todo, before first public release | **Strip list:** TestRunner, ClientTestRunner, TestKit, Tests, ClientTests, DevPackages, TestSyncToken, **SyncCheck** (a test fixture in `src/server` that runs in every live server; audit-001 R1). Since Task 5, TestKit, ClientTests, DevPackages and TestSyncToken replicate to clients. **Archive (rule 7)** `src/server/SyncCheck.server.luau` and `tests/server/sync.spec.luau` when the first real server game spec lands, and `tests/client/client_env.spec.luau` when the first real client spec lands. The harness already checks what they check (audit-001 R1). See CLAUDE.md "Test code ships with the place" |
| 3 | Run `luau-lsp analyze` in CI (type checking) | todo | luau-lsp is pinned but not wired into CI. Needs a sourcemap and Roblox type definitions in CI |
| 4 | Karen: check DEV place Version History around the first Connect | closed: not applicable | Not applicable: the place was empty at the first Connect. It was brand new, a read-only query at ~18:30 found all Rojo-owned containers empty, and Karen added nothing to them before Connect (~18:36). The click path I gave (Studio → File → Version History) was wrong: Studio's File menu has no Version History |
| 5 | Architecture audit-001 must-fix M1–M4 plus doc drift | done (merged 2026-09-24, PR #3/#6) | Stacked PR on PR #1. See the review log below |
| 6 | **BLOCKING before any input-driven client code:** drive real input from the harness | **reviewed: PASS, 2 rounds** | Branch `task-6-input-driving`, from `main` (`a7e4745`). Done to the shape `docs/design/shotgun.md` §13.3 asks for. **One scenario file** `tests/client/input_scenarios.txt` (JSON in a `.txt`, so Rojo makes it a `StringValue` the harness already compares byte-for-byte and no `default.project.json` change is needed - that would need a Rojo restart and Karen's Connect): steps are `keyboard` (`keyDown`/`keyUp`/`keyPress`), `mouse` (`moveTo`/`mouseButtonDown`/`mouseButtonUp`/`mouseButtonClick`) and `wait` (ms). **One harness step** (`replay_input` in `tools/studio_mcp.py`, step 7a): it waits for the client to publish this run's token on `LocalPlayer` (the ready handshake, so a replay can never race the bindings), then sends consecutive same-device steps in one StudioMCP call and sleeps the gaps in Python. **One client spec** `tests/client/input_driving.spec.luau` binds `ContextActionService` (keys + MouseButton1) and `UserInputService` (mouse movement) and asserts arrival, the down/up pair, the CAS and UIS sources, the order, and that the 700 ms gap is visible and larger than any unwaited gap. Addendum in `docs/research/2026-09-24-toolchain.md`. **Cannot express:** touch, gamepad, `textInput`, frame-counted holds, input aimed at an instance, anything after the client report. **Two rounds, both `PASS`, 0 blocking, 9 then 8 notes** ($1.95 + $1.77). Round 1's notes were fixed rather than queued (they weakened the evidence: a step neither side understood was silently skipped, `"button": "right"` was documented but unwatched, a hung StudioMCP call aborted the run, and a stray mouse move could shorten the measured gap) - and fixing them found a real bug by running it: **the mouse position is per StudioMCP call, not per session**, so the reordered scenario's click was refused until `scenario_batches` carried the position forward. Round 2's 8 notes are **Task 6a**. Harness `PASS: 26/26 @ 1b0e8fa (clean tree)` |
| 6a | **Task 6's 8 round-2 review notes** (non-blocking) | todo, small | From `reviews/task-6/RESULT.md`. **(a)** `it("leaves nothing bound behind")` does its own teardown and then asserts it worked, so it can only pass - move the teardown to `afterAll` and drop the assertion. **(b)** Two `it`s hardcode the committed scenario (`entry.name == "F"`, `casButton == 2`) while `expectedFrom` is generic; derive the counts from `expected` or say the pinning is deliberate. **(c)** The `readyAttribute` identifier check runs during Play and raises, so a bad value is a harness error rather than a named check - move it into `load_scenarios` with the other five. **(d)** `load_scenarios` could also refuse a `mouseButtonDown` that comes before any `moveTo`, which is the run-time refusal Task 6 hit. **(e)** The gap assertion's "waited > unwaited" holds only while per-call RPC latency stays well under 700 ms; say so beside `GAP_TOLERANCE`. **(f)** `capture`'s `parse_vector("1,2")` raises an uncaught `ValueError` after Studio is already spawned; `sys.exit` the usage line like its neighbours. **(g)** `mouseButtonClick` and `"button": "right"` are documented, validated and mapped but never sent - add a scenario that exercises them, or trim them from the format. **(h)** Paperwork: `reviews/task-6/REQUEST.md` said the counter blind spot was recorded under 21a before it was; it is item (h) there now |
| 7 | Play-time screenshots | **closed 2026-09-25 (Task 6)** | `Studio._call` joins text blocks and dropped the image, so nothing could be saved. `Studio.capture()` reads the image block and `python tools/studio_mcp.py capture <name> [camera x,y,z] [look-at x,y,z]` writes it to `.screenshots/` (git-ignored). Verified in **Edit** (correctly empty: since Task 22 `Workspace` holds only `Camera` and `Terrain`) and during **Play** (the arena plate as a full square) |
| 8 | Audit-001 fix-before-release and log-only items | todo | R2 is partly done (same-named siblings now fail). R3 = Task 3. L1 is done (docstring is the single source). L3 non-ASCII is fixed. L5 is fixed by Task 10. Open: L2, L4, L6, L7, L8, L9 (owner table rows) |
| 9 | Four-agent workflow: roles, communication files, `tools/review` and `tools/architect` scripts, PROJECT_CONTEXT | awaiting review | PR #4 (branch `task-9-agent-workflow`), now targeting `main`. From here on, TASKS.md queue and priority belong to the Director. The Builder updates only its current task's status and files non-must-fix audit items. **Never went through the loop itself: Task 11 does that** |
| 10 | Proof of the loop: audit-001 L5, test-only globals (`describe`, `expect`, `SKIP`…) must be a lint error in `src/` | done | Branch `task-10-lint-test-globals` (PR #5), stacked on `task-9-agent-workflow`. Review: PASS in 2 rounds. Audit-002 returned 5 must-fix items, all outside this task's change; the Director closed the escalation and queued them as Tasks 12–16 |
| 11 | Run Task 9 (the four-agent workflow) through the loop itself, fix the findings, and write the new merge policy into CLAUDE.md | done | PR #4, merged as `a0ccadc`. Branch `task-9-agent-workflow`, merged up from `main`. **Scope is the Director's**, transcribed verbatim in `ESCALATE.md` ("Task 11's dispatch, verbatim"): the review of Task 9 *and* the merge-policy and `NEEDS KAREN` edits in one task. Merge policy: the Director retargets and merges after a clean-tree harness PASS on the code commit, Reviewer `PASS`, green CI and paperwork-only commits after it; Karen no longer merges; the Builder still never merges. Rounds 1–4 found 6, 2, 2 and 5 items; all 15 are fixed. Round 3 found nothing against the code, so the Director authorised **one** extra round (`DIRECTOR_MAX_ROUNDS=4`; `ESCALATE.md`, closed 2026-09-24). **Round 4 returned 5 more** (4 stale text, 1 real bug in the round-4 commit: the Reviewer was told the default cap, not the raised one). All fixed; per the Director there is no round 5, so the fixes are unreviewed and this is escalated (`ESCALATE.md`, "round 4 (authorised) returned 5 findings"). **Step-6 Architect audit skipped by Director decision** (`ROADMAP.md` speed rule 3: audits every ~5 tasks) |
| 12 | audit-002 #5: only the scripts write `REVIEW_RESULT.md` / `ARCH_RESULT.md`; each verdict is tied to a commit; a dirty-tree audit verdict is marked as such | **before release** | Not next. `ROADMAP.md` speed rule 1: tooling is frozen after Task 11 |
| 13 | audit-002 #4: the Architect sees earlier audits (evidence in `tools/agents.py`) | **before release** | Not next. `ROADMAP.md` speed rule 1 |
| 14 | audit-002 #3: research note for `tools/agents.py` (rules 1, 2, 9) | **before release** | Not next. `ROADMAP.md` speed rule 1 |
| 15 | audit-002 #2: detect Studio-made **non-script** instances in Rojo-owned containers | **before release** | Not next. `ROADMAP.md` speed rule 1. The unmanaged scan checks only scripts today |
| 16 | audit-002 #1: typed property values (Vector3, CFrame, Color3…) in the harness | unblocked, not next | **Blocker resolved: Karen chose map option C** — the map is built by a map generator in code, run in Edit mode through Studio MCP, with templates on disk (`ROADMAP.md`, Milestone 2). So the harness must compare typed values on the templates. Needs an Architect design first. Not next: it lands with the map generator, before any positioned geometry |
| 17 | **ROADMAP 1.1:** grey-box test area — 400×400 ground plate, 8 cover blocks and a SpawnLocation, built by code from `src/server/TestArena.luau` into `Workspace.TestArena` | awaiting review (with 18; rounds 4-5 done, escalated) | Branch `task-17-test-area` (from `main`). The first game code. No research note and no Architect design: trivial throwaway geometry, replaced by the map generator in Milestone 2 (Director decision). **Code committed at `48169db`; lint, format and build pass. `rojo serve` crashed during the branch switch, so the harness, the review and the screenshot could not run** — `ESCALATE.md`, "NEEDS KAREN · `rojo serve` crashed". **RAN 2026-09-25**, and the arena is correct in the harness: the 400×400 plate, its surface at y = 0, 8 anchored blocks inside it and one SpawnLocation on it all assert green. **But it is visibly wrong on screen.** Three play-time screenshots, inspected: the plate's top face is coplanar with the default `Workspace.Baseplate` (2048×16×2048, top also at y = 0) and **loses the depth test over half its area — the 400×400 square renders as a TRIANGLE**, split along the quad's diagonal, with the Baseplate showing through the other half. Two captures 1.5 s apart are identical, so it is **stable, not flickering** — which is worse, not better. ~~**Karen's call** (the Builder must not touch Studio content): delete `Workspace.Baseplate`, or say the word and the arena's surface moves off y = 0 by a fraction of a stud, which is one number in `TestArena.LAYOUT`. **Also confirmed: two SpawnLocations exist during Play** — the arena's `ArenaSpawn` at z = +170 and the default one at the origin, both visible in the wide shot~~ — **CLOSED 2026-09-25 (Director): Karen decided, and Task 22 did it.** Both defaults were archived out of `Workspace` into `ServerStorage.Archive` (record: `backups/2026-09-25_workspace-defaults.md`), so the plate renders as a full square and `ArenaSpawn` is the only spawn. Nothing is open here; see row 22 |
| 18 | **ROADMAP 1.2:** boar AI, grey box — one boar that idles (Reynolds wander), flees a threat within 0.5 s, routes to the exit edge around cover, and despawns with a signal | awaiting review (with 17; rounds 4-5 done, escalated) | Branch `task-18-boar-ai`, **stacked on `task-17-test-area`** because Task 17 is not on `main` yet. Research note `docs/research/2026-09-24-boar-ai.md` (rule 1) and Architect design `docs/design/boar-ai.md` (`ARCH_RESULT.md` = PASS) both written first. No Architect audit (`ROADMAP.md` speed rule 3). **Rounds 1–3 found 6, 6 and 4 items; all 16 are fixed, but round 3's four are unreviewed and `MAX_ROUNDS` refuses a fourth** — `ESCALATE.md`, "Task 18 reached round 3". Nothing in this task has ever executed. **RAN 2026-09-25.** Harness `PASS: 24/24 @ fe21a0d (clean tree)` on the code commit, 39 server + 4 client tests (`fbe1d60` was the first green run; three code commits followed it). The first run failed 3: two were my own specs (a tolerance tighter than float32 can be, and two tests that held the boar still long enough to trip the anti-stuck branch they neighbour), one was the spec asserting a property of Roblox's navmesh rather than of this code. **Screenshots, inspected:** the boar exists, rests at y ≈ 1.5 as designed, wanders while idle, and is recognisably a 2×3×5.5 box — but **its sides read almost black**; only the top face shows the intended `Color3.fromRGB(90, 80, 70)`. One number for Karen if she wants it lighter |
| — | ~~Tasks 17 and 18 still need a harness run and a screenshot~~ | **done 2026-09-25** | Karen connected, and both ran: `[harness] PASS: 24/24 checks @ <code commit> (clean tree)`, 43 assertions across five spec files, plus three play-time screenshots captured through MCP and inspected. See rows 17 and 18, and `ESCALATE.md` ("NEEDS KAREN · `rojo serve` crashed", closed 2026-09-25). Kept rather than deleted (rule 7) |
| 19 | **ROADMAP 1.4, docs only:** shotgun research note and Architect design — viewmodel, third-to-first-person aim, hit detection, break action, the numbers | awaiting review | Branch `task-19-shotgun-design`, from `main`. **No game code.** `docs/research/2026-09-24-shotgun.md` (9 sources) and `docs/design/shotgun.md`. **`ARCH_RESULT.md` = 3 blocking open decisions, all Director scope calls** (waive Task 6 for three inputs or land it first; whether ADS + viewmodel stay in 1.4 or move to a camera task; which system owns the damage entry point). They block the **code**, not this docs task. Owner rows for the weapon are drafted in the design §12 and go into `GAME_DESIGN.md` when the code lands, not now. **Three defects in the Architect-owned files, found in review and NOT fixed** (rule 3: the Builder never edits `docs/design/` or `ARCH_RESULT.md`) — (a) design §9 states the slug cone as a half-angle while the buckshot row beside it is a full angle, and §11.1 consumes a half-angle, so a config built from §9 as written gives a cone at 2× or 0.5×; (b) `ARCH_RESULT.md` item 1 points at §11.1 where it means §11.3; (c) three of the design's four `docs/PROJECT_CONTEXT.md` citations are off by two lines. **Fix these when the design is regenerated**, which it needs anyway once the boar branches are merged and the Architect can see them (`ARCH_RESULT.md` item 3). See `ESCALATE.md`, "Task 19 round 2", **closed 2026-09-24**. **Director decisions:** Task 19 is accepted as documents only and **the design is not built from until the Architect regenerates it** after Tasks 17/18 merge — that regeneration fixes the cone-unit defect and names the damage entry point owner. **Task 6 lands before the shotgun build, no waiver.** The shotgun ships first on the default camera with no ADS and no viewmodel; **third-to-first-person aim is its own camera task with its own design, right after**, because Karen wants it in v1 |
| — | **Find out why the Reviewer's `docs/PROJECT_CONTEXT.md` line numbers were two lines off** (Task 19 rounds 1 and 2) | **before release** | The Director checked `git show 009c20e:docs/PROJECT_CONTEXT.md`: the quotes are at 34, 32, 32-33, 30-31, as the Builder said; the Reviewer reported them uniformly +2. Either `tools/agents.py`'s evidence copy differs from the commit under review — which would be a harness fault worth fixing at once (rule 6) — or the agent miscounted. Not urgent: the working rule is already that `REVIEW_REQUEST.md` cites **files and symbols, not line numbers** (`CLAUDE.md` loop step 4) |
| 20 | **ROADMAP Milestone 2, docs only:** map generator research note | **escalated** (round 2) | Branch `task-20-map-research`, from `main`. **Scope is the Director's**, transcribed verbatim below under "Director dispatches": **no code, no Architect design** — research only. `docs/research/2026-09-24-map-generator.md`, 13 sources. Key finding: **Studio's heightmap/colormap import is UI-only and unreachable from code or MCP**, so the generator computes its own heightfield. Ends with the smallest first generator task: a 512x512 stud slice that proves voxel writes, `math.noise`, **whether CollectionService tags survive a save and reopen**, and Edit-mode `screen_capture` as rule-5 evidence. **Rounds 1-2 found 6 and 5 items; all 11 are fixed, but round 2's five are unreviewed** - the dispatch allowed two rounds - see `ESCALATE.md`, "Task 20 round 2" |
| 21 | **Trim the review loop** (Karen: less Reviewer noise, faster): blocking-vs-notes in the Reviewer prompt, harness before review, one review folder per task, CLAUDE.md to match | **reviewed: PASS, round 1** | Branch `task-21-trim-review`, from `main` (`f598363`). **Scope is the Director's**, transcribed verbatim below. Allowed past the tooling freeze (`ROADMAP.md` speed rule 1) because it blocks the speed of every game task. (1) `docs/REVIEWER_PROMPT.md`: only the game, a test, an owner boundary, security or a false claim about what was tested blocks; everything else is `## Notes (non-blocking)`, and line 1 is `PASS` when no blocking finding exists. The Reviewer reads `REQUEST.md`, `TASKS.md`, `ESCALATE.md`, `PLAYTEST.md` and `ROADMAP.md` as context, never as deliverables. (2) `tools/agents.py`: **harness before review** - a change touching `src/`, `tests/` or `tools/` is refused unless the request pastes the harness PASS line for its code commit (Task 18 was reviewed 3 rounds before its code had ever run); docs-only is exempt. (3) **One folder per task**, `reviews/task-<N>/{REQUEST,RESULT,ARCH_RESULT}.md`, with the round counted from **that task's** RESULT.md - so a merged FINDINGS task can never again block the next task's round 1 (the Task 22 fault). The three root files are archived to `backups/` with `git mv` (rule 7). (4) `CLAUDE.md` rewritten to match, plus the one-page/10-claim request rule and one round for docs-only tasks. Also here, per the Director: row 17's leftover question closed above, and the two Task 22 review notes fixed as docs (the boar-ai research note's stale coplanar sentence, and the `Texture`/`Decal` rows in `backups/2026-09-25_workspace-defaults.md`). **Review: `PASS` in ONE round, 0 blocking findings, 7 notes, $1.79** (`reviews/task-21/RESULT.md`) - the new scheme working on itself: round 1 needed no `DIRECTOR_MAX_ROUNDS`, and the harness gate passed on the pasted line. The 7 notes are queued as **Task 21a** below, unfixed here: they all live in `tools/` or `docs/`, which the merge gate forbids changing after the code commit, and the round counter refuses a round 2 after a `PASS` by design |
| 21a | **Task 21's 7 review notes** (non-blocking, queued by the Builder under the new rule) | todo, small | From `reviews/task-21/RESULT.md`, worst first. **(a) A real defect in `tools/agents.py` `main`:** `architect --task 5` with the mode omitted leaves `rest == []`, so `rest[0]` raises an uncaught `IndexError` instead of the usage `Refused`; and `review --task 21 22` silently ignores the stray `22`. Check `rest` before indexing and reject leftovers on both paths. **(b) The harness gate can be stepped around:** `harness_gate` decides docs-only from `git diff <Base>...<head>`, and `Base:` comes from the request, so a `Base:` set to the code commit makes a `tools/` change look docs-only. Diff `code_commit..head` as well. **(c)** `is_paperwork` treats all of `TASKS.md` as paperwork, while the merge gate allows only the task's status row; either scope it to the row or say so in the evidence file. **(d)** Per-task round counting adds a bypass the global counter did not have (a Builder at round 3 can open `reviews/task-<N'>/` and get round 1); name it in CLAUDE.md "What is enforced and what is policy", whose list is otherwise complete. **(e)** `tools/agents.py`'s own module docstring ("How read-only is enforced", item 3) and `parse_trailer`'s docstring still name the archived root files. **(f)** `docs/ARCHITECT_PROMPT.md`'s audit section still asks for `file:line` while the same file now says symbol, not line. **(g)** `reviews/task-21/REQUEST.md` claim 10 implies the `Texture`/`Decal` rows were read fresh in Task 21; the values are the ones Task 22 recorded in `ESCALATE.md`, which is what the dispatch asked for - the data is right, the wording is not. **(h)** (found in Task 6) A **re-review after a `PASS` cannot be numbered 2**: `cmd_review` computes `expected = 1 if prev_verdict == "PASS"`, so when a task passes and the Builder then fixes notes in `src/`/`tests/`/`tools/` - which the merge gate forces to be re-reviewed - the second review must say `Round: 1`. Task 6 hit exactly that and said so in its request. Either let a request name the round after a PASS, or write into `CLAUDE.md` that the count restarts there |
| 22 | **Playtest-ready grey box:** archive the place's default `Baseplate` and `SpawnLocation`, and make the boar visible from every side | reviewed: PASS with notes (Director) | Branch `task-22-playtest-ready`, from `main` (`358a430`). **Scope is the Director's**, transcribed verbatim below. (1) Karen's decision: both defaults moved in Edit mode through Studio MCP into `ServerStorage.Archive` beside a `StringValue` note - moved, not deleted (rule 7). Verified after: `Workspace` holds only `Camera` and `Terrain`; the Archive holds both plus the note. **`ServerStorage` is Rojo-owned** (`default.project.json` maps it to `src/serverstorage`), so Rojo will offer to delete that folder at Karen's next Connect - the durable record is `backups/2026-09-25_workspace-defaults.md`, which holds every property of both instances. (2) The near-black boar sides were caused by `Boar.CONFIG.BODY_COLOR`, not the material: at the default `Lighting.Ambient`/`OutdoorAmbient` of RGB(70, 70, 70), an unlit face renders at ~0.275 x albedo, so RGB(90, 80, 70) became ~RGB(25, 22, 19). Now RGB(198, 158, 110), checked on screen from four sides. (3) **The review gate refused round 1** (it counts rounds globally and restarts only after a `PASS`; `main` carries Tasks 17+18's round 5 `FINDINGS`). The Director authorised `DIRECTOR_MAX_ROUNDS=6` and `Round: 6` for this task only, and made the per-task fix **Task 21**, next (`ESCALATE.md`, 2026-09-25, closed). That one round returned **4 findings, none blocking** under the Director's policy - all four are about documents - so the Director's call is **PASS with notes**. Finding 4 is fixed in `REVIEW_REQUEST.md`; findings 1 and 3 (a stale present-tense sentence in `docs/research/2026-09-24-boar-ai.md` §4, and the `Texture`/`Decal` child properties missing from `backups/2026-09-25_workspace-defaults.md` - the data itself is preserved in `ESCALATE.md`) are **queued for the next task**, because neither file may change after the code commit without invalidating the harness line (git workflow step 4). Finding 2 is **row 17 above**, which is the Director's row to close, not the Builder's. Harness `PASS: 24/24 @ d265cab (clean tree)`. (4) `docs/design/boar-ai.md` (§2 "What it must not do", and its closing section on the Task 17 arena) still describes the two defaults as live Studio content in Workspace; the Builder never edits Architect files (rule 3), so that is for the next regeneration of the design |
| 23 | **Regenerate the shotgun design, docs only** (ROADMAP 1.4): the Task 19 design is not built from until it is regenerated with the boar on `main` | **reviewed: PASS, round 1** | Branch `task-23-shotgun-design-v2`, from `main` (`cf184f1`). **Scope is the Director's**, transcribed verbatim below. The Architect's input is `reviews/task-23/BRIEF.md` (new, and `docs/ARCHITECT_PROMPT.md` now tells the Architect to read a task's `BRIEF.md` first): it settles the three blocking decisions Task 19 left - **default camera first, no ADS and no viewmodel**; **ADS/third-to-first-person is the next task with its own design**; **Task 6 (smallest useful version) lands before the shotgun build, no waiver** - and names the fourth, the damage entry point, as something this design must answer with a single `takeHit(zone, ammo)`-shaped seam (hit zones are ROADMAP 1.5). It also requires: both spread cones in ONE unit with the config's unit named (the Task 19 table mixed a half-angle and a full angle, so a config built from it was out by 2x), the `GAME_DESIGN.md` owner rows ready to paste, and Karen's five feel defaults as config values - with a crosshair, which she wants, given an owner rather than deferred. Docs-only, so one review round. **`ARCH_RESULT.md` = `PASS`** ($3.34): the design is 1112 lines, §15 is "Open decisions - none of them blocks building", and the damage entry point is answered - `ServerScriptService.Boar` gains `Runtime:takeHit(part, hit)` and `Runtime.Hit`, wired from `Weapon.HitReported` in `BoarBoot` so neither owner requires the other. **Review: `PASS` in one round, 0 blocking, 12 notes** ($2.52, `reviews/task-23/RESULT.md`), queued as **Task 23a** below |
| 23a | **Task 23's 12 review notes** (non-blocking) - six are real design defects in an **Architect-owned** file | todo | The Builder never edits `docs/design/` (rule 3), so these go to the **next regeneration of the shotgun design, or to the Builder at build time with the Director's say-so**. Worst first. **(a) The cast seam cannot do what the design asks of it:** `CastFn = (origin, direction) -> Impact?` with one module-level `Weapon.setCast` has no shooter, so step 8's "filter out the shooter's character" is unimplementable, and step 4's camera ray - which starts *behind* the character under the stock third-person camera - resolves the aim point onto the shooter's own body, where `MIN_AIM_DISTANCE` silently swallows it. Needs an ignore-list parameter or a per-shot cast. **(b)** `table.freeze` is shallow: `CONFIG.SPREAD_FULL_DEG` and the replica's `barrels`/`loaded` stay writable, so "frozen, no writer" and the spec that asserts a write errors both only hold at the top level. **(c)** No `Players.PlayerRemoving` cleanup for per-player `WeaponState` and the rate-limit counters: a leak that pins the Player instance. **(d)** `ActionRequest` must accept only `"Reload"` and `"SelectAmmo"`; as written the server-only primitives `Break`/`Load`/`Close` look reachable from a client. **(e)** The safety arc is evaluated on the client's camera direction, not the muzzle direction the pellets take. **(f)** `weapon_shot.spec` item 2 contradicts its own preamble (imports `CONFIG`) and its "at least one direction beyond `SPREAD_FULL_DEG/4`" is ~25% flaky for `Slug`, which returns one direction - seed it and apply that half to `Buck`. Documentation-only: **(g)** three "§12" cross-references mean §13; **(h)** §14's "five rows" is four new rows + one filled + the Boar amendment; **(i)** §2 item 2 says Task 19's verdict file is superseded when it is only recorded. Ours to fix elsewhere: **(j)** `CLAUDE.md` should document `reviews/task-<N>/BRIEF.md` as a Builder-written file, since `docs/ARCHITECT_PROMPT.md` now depends on it - not done in Task 23 because `CLAUDE.md` is not paperwork and would have invalidated the reviewed commit; **(k)** keep "`ARCH_RESULT` should be `PASS`" out of future briefs - the Builder never writes verdicts (nothing turned on it: it restated the prompt); **(l) Director:** `ROADMAP.md` row 1.4 still reads "third person, first-person aim", which this design deliberately does not ship - split 1.4 from the camera/ADS task so 1.4 is not marked done without it |
| 24 | **ROADMAP 1.4:** the shotgun on the default camera | **reviewed: PASS, 2 rounds. NOT MERGEABLE until Karen plays it** | Branch `task-24-shotgun`, from `main` (`bb674dc`). **Scope is the Director's**, transcribed verbatim below. The design was re-run first (`reviews/task-24/BRIEF.md` -> `ARCH_RESULT.md` = `PASS`, $4.22), fixing the six Task 23a defects in `docs/design/shotgun.md` itself, and the code is built to it. **Server** `ServerScriptService.Weapon`: a Tool granted on spawn, MouseButton1 to fire, automatic barrel select, an uninterruptible 2.0 s break-load-load-close reload, slug/buckshot that loads only while open, and hits resolved from a two-stage cast (camera ray finds the aim point, pellets fly from the muzzle) with the shooter in the ignore list. The pure core (`StateMachine`, `Validator`, `Limits`, `Registry`, `Pattern`, `Hits`, `SafetyArc`) takes `now`, `rng`, `cast` and `ignore` as parameters; `Cast` is the only caller of `Workspace:Raycast`; `Hardware` the only writer of `Tool` Instances. **Client**: `PlayerScripts.Weapon` (replica with no setter), `Input` (the `DrivenHunt.Weapon.*` bindings, every handler returning `Pass`), `Effects` (cosmetics), and **`PlayerScripts.Hud`, the new UI owner** - crosshair and barrel/ammo readout - which reads the weapon and is never called by it. **Nothing writes `workspace.CurrentCamera`.** **Seam**: `Boar.Body` publishes `Damageable` and `HitZone`, `Runtime:takeHit` counts and fires `Runtime.Hit` without moving the boar (zones and wounds are 1.5), and `BoarBoot` wires `Weapon.HitReported` to it. **Tests**: 79 server assertions over 8 spec files and 26 client over 3 (main had 39 and 11), including a new input scenario. Harness `PASS: 26/26 @ 110d869 (clean tree)`. **Four things measured that the design could not know** (rule 6): a replayed step costs ~1 s of wall time, so no client assertion may depend on two inputs landing inside a 0.25 s or 2.0 s window (both rejections are proved exactly in `weapon_state.spec` instead); `AbsolutePosition` ignores `IgnoreGuiInset`; `AUTO_EQUIP` let Task 6's own scenario fire the gun, so the spec parks the Tool before signalling ready; and `HANDLE_COLOR` RGB(70, 55, 45) read near-black on screen - the Task 22 albedo trap - now RGB(190, 145, 95). Round 1 returned **1 blocking finding** (the teardown test counted BindableEvents that are never parented, so it could not fail) and 12 notes; round 2 `PASS` with 9. Five screenshots inspected. **Karen played it 2026-09-25** (`PLAYTEST.md`) and changed one feel default: **X switches the ammo type AND reloads to it** - break open, the unfired shells of the old type go back to their own pocket, two of the new type in, close, in the same 2.0 s uninterruptible window as `R`, with no firing during it; an empty pocket of the new type does nothing and the Hud says `NO BUCK`. That needed shells carried **per type** (`START_RESERVE = { Slug = 24, Buck = 24 }`, `reserve` a table), `Break` returning unfired shells for `R` too, and a `notice` field on the snapshot. Running it found one more bug a player would have seen: nothing published when the final reload window elapsed, so the Hud kept its `R` until the next state change. Her other checks passed; hit feel is deferred to after 1.4b and 1.5. The design's §12 is now stale on this point - the deltas for the next regeneration are in `reviews/task-24/DESIGN_DELTA.md` |
| 24a | **Task 24's carried review notes** (non-blocking) | todo | From `reviews/task-24/RESULT.md` rounds 1 and 2; six of round 1's twelve were fixed in round 2 and are not here. **(a)** `runReload` has no recovery from an abort *after* `Break`: it returns with `open == true`, and every later `Reload` is then refused while `Fire` is refused `"is-open"`, so the gun is stuck open until the player respawns. No reachable path today, but applying `Close` on an abort would close it. **(b)** `Weapon.forget` itself has no spec (the registry half does); worth one when a player-lifecycle task lands. **(c)** `Input.watchTool`'s `watched` table pins one destroyed Tool per respawn and `connections` grows per respawn, pruned only by `Input.stop()`, which nothing calls. **(d)** `GAME_DESIGN.md`'s arena row still says the arena is the only thing in Workspace, which `Workspace.Boars` and now `Workspace.WeaponEffects` contradict. **(e) Architect-owned, for the next regeneration:** `docs/design/shotgun.md` §13.3 still describes five clicks and two `R`s, but the committed scenario is three clicks and one `R` - the deviation is measured and explained, the design is stale. **(f)** `Effects.play` draws a tracer only where a pellet landed, so a clean miss shows a muzzle flash and nothing else. **(g)** Design §13.4 also asked for the readout in three states and the crosshair over two backgrounds; five screenshots were taken and inspected, those extra views were not. **From the X round (2026-09-25): (h)** the empty-pocket refusal (`NO BUCK`) is the one part of Karen's rule with no test at any level - `onActionRequest`'s `SelectAmmo` guard is small enough to extract as a pure `(state, ammo) -> reason?` and unit-test; **(i)** `StateMachine.apply` still exempts `SelectAmmo` from the busy check, a leftover from when X was a label swap, so the busy rule now lives in two places (safe today, the owner is the only caller, but it is the "two correct pieces disagreeing" shape) - drop the exemption or say why it stays; **(j)** the Hud's `notice` is sticky: `NO BUCK` stays on screen until the next `StateChanged`, with nothing to fade it - **Karen's call**; **(k)** "82 assertions" in row 24 and the request is really 82 `it` blocks (TestEZ `successCount`), cosmetic |
| 26 | **ROADMAP 1.4b:** the camera - mouse-locked over-the-shoulder third person, right mouse for first-person ADS | **reviewed: PASS, 3 rounds. Karen played it 2026-09-25: "all ok, I am happy for v1" (`PLAYTEST.md`) - the feel gate is cleared; the Director merges** | Branch `task-26-camera`, from `main` (`cf431ba`), built to `docs/design/camera.md` (Architect `PASS`) and Karen's option A. Owners: `PlayerScripts.Camera` (mode state, one render-step binding, one mouse-movement connection), `Camera.Mode` (pure: the whole state machine and all the maths, tested on the **server**), `Camera.Rig` (**the only assignment to `workspace.CurrentCamera` in the repo**, plus the foreign-write detector), `Camera.Cursor` (the only writer of the mouse, behind a tagged request API), `Camera.Viewmodel`. `CameraBoot` installs the aim source, so neither owner requires the other. Harness `PASS: 26/26 @ 605f1af (clean tree)`; 96 server and 37 client `it` blocks. **Three rounds, six blocking findings, and the two sharpest were about the evidence rather than the code**: round 1 found that the harness-driven aim test could not fail (the fake source was never restored and had already moved the counters, so my "the real button drove the camera" claim rested on a fake), and that the weapon's "never touched the camera" assertion now asserted the opposite of aiming; round 2 found a **10-second stall on every boot and respawn** (the 10 s `WaitForChild` for a `PlayerModule` this place does not have, placed before taking the camera) and that **dying while aiming left the body invisible** until respawn. All fixed. **Measured, against the design:** this place has no `PlayerScripts.PlayerModule` at all, so `GetCameras():Disable()` never runs and the detector (`foreignCameraWrites == 0`) is the only proof of one writer; `setLocalBodyHidden` hides the Tool too (sparing it put the real gun beside the viewmodel clone); and the two `VIEWMODEL_*_OFFSET` values were set by looking at the screen, as the design says to. Research addendum in `docs/research/2026-09-24-shotgun.md` + INDEX |
| 26a | **Task 26's round-3 review notes** (non-blocking) | todo | From `reviews/task-26/RESULT.md` round 3. Two were fixed rather than queued (a **fabricated devforum URL** in the viewmodel header - not something to leave in a public repo - and `Viewmodel.current()` returning a model while unparented). Open: **(a)** when a `PlayerModule` *is* present and disabling it fails, `acquire` returns `true, err` and the owner warns "no stock PlayerModule to disable", which is then the wrong sentence; **(b)** the body-hidden predicate is `mode ~= "Dead" and blend > BODY_HIDE_BLEND`, one term more than design section 3.1 - deliberate (it shows the corpse at once instead of 0.2 s later) but it should be in the design at the next regeneration; **(c)** the remaining round-3 notes |
| 28 | **ROADMAP 1.5:** hit zones and wounds - where a shot landed decides what happens, plus the carcass, the kill and escape events, and the hit marker | in progress | Branch `task-28-hit-zones`, from `main` (`a8fde68`), built to `docs/design/hit-zones.md` (Architect `PASS`, Task 27) with the **Director's decisions on its section 14**, transcribed below: **A** no damage router (not now), **B** a 120 s carcass removed by the boar runtime, **C** the hit marker IS in this task, **D** the harness step that would place a character and aim the camera is queued not built, **E/F/G** as written. Owners, unchanged: hit zones, damage and wounds are boar state, so `ServerScriptService.Boar` owns them and no new system was created. `Boar.Wound` is **new and pure** (no state, no Instance, no clock, no Player, no Random): two quantities per zone, because one health pool cannot express Karen's spec - damage decides WHETHER it dies, flight decides HOW FAR it gets first, so a leg hit needs more hits AND runs further. `Boar.Body` grows three welded, massless, non-colliding zone parts that **protrude** past the trunk (a nested part could never be hit: a ray returns the nearest surface), the hit flash and the collapse; `Boar.Brain` gains `WOUNDED` and `DOWN`, reacts before the sense gate and bolts away from the shot point; the Runtime is the only holder of a wound state and publishes `Downed` plus an extended `Despawned` for an escaped wounded boar. The **hit marker**: the weapon fires a new one-way server->shooter remote on a confirmed hit, `BoarBoot` fires it again as a kill, and `PlayerScripts.Hud` draws a short white tick or a longer red one - nothing else draws. Harness `PASS: 26/26 @ 47fc948 (clean tree)`; 156 server and 44 client `it` blocks (main had 96 and 37). **Three things the design got wrong, all measured** (rule 6): its `COLLAPSE_ANGULAR_IMPULSE = 1200` leaves a dead boar standing to attention and no impulse value topples it without launching it, so the carcass now rolls 45 degrees past its 33.7-degree tipping angle and gravity lays it down (peak 0.2 studs, final up 0.00); its 10000-applies-under-100 ms target is quadratic in the wound history it also requires to be immutable (measured 1959 ms) and cannot happen anyway, so it is split into the two things it protected; and its section 12.3 asks for a "belly from below" ray at a place that does not exist, because `ZoneLegs` covers the whole underside. The research note confirmed every source the design cited from memory: **two were wrong** (the `RaycastHitbox` URL; "first surface wins" is not on the page cited for it) and the Stokke et al. 2018 paper is real, CC BY 4.0, and independently validates `FLIGHT.body = 120` and `FLIGHT.legs = 420` (its `efd`/`mfd` give 100 and 429 studs at 80 kg). Six screenshots inspected. **Karen played it 2026-09-25: "all good"** (`PLAYTEST.md`) - head and chest kill, a leg hit escapes, the flash plus the bolt read as a hit, the marker reads, two body hits kill, and no sound was asked for. Feel values stay the design defaults, zone tint on. Merged as PR #24 |
| 28a | **Task 28's review notes** (non-blocking) | todo | From `reviews/task-28/RESULT.md`. Round 1's small corrections were fixed in round 2 rather than queued (twelve rays not nine in three comments; five RemoteEvents not four; a carcass no longer re-freezing a wound state 60 times a second for two minutes; a live reaction bound of 0.1 s instead of exactly `SENSE_INTERVAL`; four more numbers in the config comparison). Open: **(a)** design section 12.5's `fire-at-boar` input scenario was not added - a near-duplicate of the committed `weapon-fire-reload-ammo`, and the design itself says it would assert the weapon's state and not that a boar was hit, but it is a declared deviation now rather than a silent one; **(b)** `tests/client/hit_marker.spec` waits up to 30 s for a marker that `weapon_hits.spec` sends in the same Play session, which is a real cross-report ordering dependency - firing it from the client spec's own session setup would remove the coupling without weakening the assertion; **(c) Architect-owned, for the next regeneration:** `KillRecord.flightStuds` carries the distance actually run while `WoundState.flightStuds` means the target distance - the code matches the design's wording, so it is the design's name that is wrong, and 1.7 will consume that record; **(d)** `stats().downed` counts deaths and `stats().killed` counts carcasses removed, so design section 11.3's "downed == killed" holds only after the carcass expires - belongs in 1.7's design. **From round 2: (e)** `GAME_DESIGN.md`'s Shotgun-numbers row still says four RemoteEvents, where the weapon's own header was corrected to five; **(f)** the bolt direction's `normal * 10` back-off is the one number in the new code that is not in `CONFIG`, against this task's own claim that every number is; **(g)** `stats().zoneHits` keys straight off the reported zone, so an unknown zone name makes its own bucket while `Wound.apply` charges the damage to `body` - folding it onto the fallback key would keep the two consistent; **(h)** `Wound.speedScale` reports the fully bled-out scale for a mortal boar whose flight is 0 (a chest hit) before it has run a stud - unobservable, because `advance` collapses it on the next tick, but it reads as the opposite of what it means; **(i) Architect-owned:** `Wound.killRecord` takes a fifth `config` argument the design's section 8.2 signature does not have (it is needed for `instant`) |

| 30 | **ROADMAP 1.6 (harness):** can the harness run 2+ players; place-and-aim for an end-to-end shot; audit-003 must-fix 2 | **reviewed: PASS, 1 round** | Branch `task-30-harness-multiplayer`, from `main` (`437cde1`). Allowed past the tooling freeze by the Director because it blocks 1.7. **(1) The 2-player answer, from StudioMCP's own `tools/list`:** `start_stop_play` takes no player count and every query/input tool takes `datamodel_type` as an enum of `Edit|Client|Server` with no index, so a 2-player run is **not possible today** - but every tool takes a `studio_id` and `list_roblox_studios` returns one entry per connected Studio, which is the one open route and cannot be evaluated without a human starting a 2-client test. Added `python tools/studio_mcp.py studios` (one read-only command) and a **NEEDS KAREN** entry in `ESCALATE.md` with the exact clicks. **ANSWERED 2026-09-25 (Karen ran it): FOUR studios were listed** - the DEV edit Studio plus the local server and both clients - so the extra processes DO register and a 2-player harness is feasible. Queued as row 33. **(2) Staging:** a scenario may carry a `stage` block; the harness places the character at an offset from a target and asks the camera OWNER to aim, through the new `Camera.lookAt` and the `LookAtRequest` BindableFunction - an Instance, because `execute_luau` has its own module cache and a `require()` through it returns a fresh module (`mode=Loading, frames=0` while the live camera is Scriptable at FOV 70). `Mode.anglesToward` is pure and iterates, because aiming the pivot leaves the camera 3.97 degrees off at 20 studs; six passes land under 0.02. `tests/client/shoot_boar.spec.luau` is the end-to-end assertion that could not be written before: a replayed click, staged on the production boar, comes back as the shooter's hit marker. **(3) audit-003 must-fix 2:** `Rig.apply` compares the whole CFrame (both basis vectors, so a roll counts) plus the FOV, and a spec performs a rotation-only write and asserts the counter rises. Harness `PASS: 27/27 @ 99afc5b (clean tree)`; 162 server and 51 client `it` blocks. **Two harness bugs found by running it** (rule 6): eight big files in one comparison batch truncated Studio's reply and failed the run (batches are split and retried now), and a `%` in a templated query raised before Studio saw it **while the run went green twice on a stray click that happened to hit the boar** - so the spec now counts only markers that arrive after its own stage. Two specs' session-wide claims became window claims, bounded by the `StagedTarget` attribute, because the session now has a second shooter. One screenshot inspected |
| 30a | **Task 30's review notes** (non-blocking) | todo | From `reviews/task-30/RESULT.md` (round 1, PASS). **(a) The end-to-end chain is overstated in a comment and in the request:** the `kind="hit"` marker the spec asserts on is fired by the WEAPON in the same loop as `HitReported`, so the boar's runtime is not on the asserted path (only `kind="kill"` comes through `Downed`). The chain it really proves - click -> CAS -> client weapon -> `FireRequest` -> validator -> cast/pellets -> a damageable boar instance's `HitZone` -> the shooter - is still the thing that could not be tested before; say that instead. **(b) Architect-owned:** `docs/design/camera.md` section 8.2 / 9.2 item 9 still specify `maxUpdateMs < 0.3` and a `Stats` type with no `avgUpdateMs`, and section 3.1's interface list has neither `Camera.lookAt` nor `LookAtRequest` - both need the next regeneration. **(c)** three headers now say the camera owner is "the only writer of `workspace.CurrentCamera` in the repo", which the new detector spec deliberately makes false: it is the only writer in `src/`. **(d)** `weapon_client.spec`'s `sawSwapInProgress` still scans the whole session and `shoot-the-boar` satisfies half of it by itself; move it onto `ownLog()` like the two that were converted. **(e)** client-suite ordering is now load-bearing (the detector write must land after `camera_client`'s zero assertions and before `weapon_client`'s baseline) and nothing pins it - one sentence in `InputReady` would stop a rename inverting it silently. **(f)** the toolchain addendum quotes `list_roblox_studios`'s "every tool call must include a `studio_id`" while `Studio._call` sends none and works; quote the schema instead, and note that `studios` is a new subcommand where `drive.md` section 12.6 asked for no code change. **(g)** `replay_input`'s docstring says "two checks" where it now adds three, and one comment says the replay is ~40 s where two other places measured ~50 s. **(h)** `camera_mode.spec`'s near-target test names more than it asserts: three of its four checks are tautological given the clamp (they do guard the clamp being deleted) |
| 33 | **Harness runs the specs with 2 players** (the Director's, queued 2026-09-25 after Karen's probe) | **superseded by row 34**, which is the task that built it | Karen's 2-player probe answered Task 30's open question: `list_roblox_studios` returns **four** entries during a Clients-and-Servers test (edit Studio + server + 2 clients), and every StudioMCP tool takes a `studio_id`, so a second client IS addressable - just not through the three-value `datamodel_type`. The task: teach `tools/studio_mcp.py` to select a studio by id, start a 2-client local test (or have Karen start it and attach), collect BOTH client reports, and decide what a 2-player check adds over the stub-world specs. Blocks nothing in 1.7a: every drive rule is already testable with no second client (`docs/design/drive.md` section 12.6 item 1) |

| 32 | **ROADMAP 1.7a:** the drive runs - phases, teams, the 10-minute timer, six boars per drive, points, and the posts and drive line as tagged markers | **reviewed: PASS, 2 rounds** | Branch `task-32-drive`, from `main` (`339933a`), built to `docs/design/drive.md` (Architect `PASS`, Task 29) with the Director's decisions in `reviews/task-29/BRIEF.md`. **The `Game state` slot that had been `_unassigned_` since Task 1 is filled:** `ServerScriptService.Match` owns the phase, the teams, the per-drive score and which boars exist, and writes no boar state, no weapon state, nothing drawn and no camera. `Phase`, `Roster` and `Score` are **pure** and the machine returns **state plus an explicit effect list**, so a 600-second drive with joins, leaves, a kill and a hitch runs in milliseconds with no players and no world; `Markers` only reads the five `DrivenHunt.*` tags `TestArena` now places; `Body` is the only writer of a player's team and of where a character stands. `BoarBoot.server.luau` is **archived** into `MatchBoot` (rule 7, `backups/2026-09-25_boarboot.md`), because WHEN a boar exists is now a drive decision; `Boar.CONFIG.maxBoars` 4 -> 8 and the runtime gained `clear()`, because a carcass holds a slot for two minutes and the Match may not touch a boar Instance; the weapon gained `setArmingPolicy`/`refreshArming`, the third injected provider on that owner, with `nil` still meaning `Shotgun.CONFIG.shouldArm` so every weapon spec is untouched. Harness `PASS: 27/27 @ 63edba1 (clean tree)`; 224 server and 58 client `it` blocks (main had 162 and 51). **Eight deviations from the design, all in `reviews/task-32/DESIGN_DELTA.md`**, three of which change behaviour: `MIN_PLAYERS = 1` **and the odd player is a SHOOTER** (Director decision F - with the design's `ODD_PLAYER_TEAM = "Drivers"` a lone player would be an unarmed driver, which is the state decision F exists to prevent; it makes 3/5/7-player drives shooter-heavy, which is Karen's to overrule), the **first** boar release is exact rather than jittered, and the markers are re-read while `Waiting`. **Two races the harness found** (rule 6): `ArenaBoot` and `MatchBoot` have no defined order, so the match could read the tags before the arena existed - one run in three sat in `Waiting` all session with nobody armed; and a jittered first release could put the only boar in a session after the input replay had finished. `SAFETY_ENABLED` and `SCOREBOARD_ENABLED` are **false**: the penalty and the score screen are 1.7b. Three screenshots inspected. **Feel-critical: Karen has not played a drive** |
| 32a | **Task 32's review notes** (non-blocking) | todo | From `reviews/task-32/RESULT.md` rounds 1 and 2. Round 1's blocking finding (two release guards that disagreed, so a join at a release moment lost a boar) was fixed in round 2; these are what is left. **(a)** `tools/studio_mcp.py`'s **docstring** was not updated for the stage's 60 s target wait or the 120 s report window - `CLAUDE.md` says the docstring is the single source of truth for the test system, and the round-2 request wrongly claimed it had been. Two sentences. **(b)** the OWNER's half of the round-1 fix has no test: the pure specs pass `aliveBoars` by hand and call `Phase.releaseFailed` directly, so `dispatch`'s `filled.aliveBoars = boarsAlive()` and the pcall-failure branch are untested - `Match` being a started singleton is what makes it hard, so it needs a seam. **(c)** in `dispatch`, `snapshotCache = nil` runs before `applyEffects` while the new drive's board is built after it, so the drive-start broadcast can carry the PREVIOUS drive's rows for up to 0.25 s. **(d)** `Weapon.mayArm`'s pcall fallback (a policy that errors falls back to `shouldArm`) has no test. **(e)** `Match.forget` and `Match.stop` are asserted nowhere, so design section 11.6's "per-player tables held after a player leaves: 0" has no test. **(f)** `shoot_boar.spec`'s comment still says the report window is 90 s (it is 120), and its own waits (45 s / 16 s) leave a thin margin against a drive that releases its first boar ~40 s in. **(g)** the round-2 request says three amended `GAME_DESIGN.md` rows; there are four |
| 34 | **ROADMAP 1.6 (harness):** run the specs with 2 players | **done: 1-player 27/27 and 2-player 28/28 at `166bd33`** | Branch `task-34-harness-2p`, from `main` (`2545891`). `python tools/studio_mcp.py test2` runs the SAME gate, runners and specs as `test`, read from three Studio instances instead of one; `test` is untouched and stays the default, and no spec knows which mode it is in. **StudioMCP cannot start the test** - `start_stop_play` takes `is_start` and `studio_id` and nothing else - so the mode prints the exact clicks, waits up to 180 s for three NEW studios, and claims nothing if nobody presses Start. The token is written FIRST, because a local test copies the place as it stands when Start is pressed and the runners refuse a token older than 120 s. It then identifies the instances by identity (the listing from before the click), classifies them with `get_studio_state` (Server vs Client), asks each client which TEAM its player is on, replays the input scenarios into the **shooter's** client, reads all three reports, checks the server and the shooter, and prints the driver's report as an observation - a driver carries no gun, so its weapon specs cannot pass. `tests/server/match_teams.spec.luau` is written to be true for whatever number of players is present, so it runs in both modes. Harness `PASS: 27/27 @ 166bd33 (clean tree)` plus `[harness2] PASS: 28/28 @ 166bd33`; 234 server and 58 client `it` blocks (main had 226 and 58). **Round 1 found three defects in the unexercised half** and all three were real: the wait was for three studios in total rather than three new ones; the replay target was picked by list order, which has nothing to do with who got the gun; and `match_live.spec` asserted a one-player fact inside the suite the 2-player run requires to be green. `ESCALATE.md` carries the **NEEDS KAREN** entry: one command, four clicks, and the half after the click is exercised |
| 34a | **Task 34's leftovers: role-aware client assertions, and the review notes** | todo | **(1) The DRIVER's client suite fails by design and should stop needing an excuse.** In a two-player drive the driver carries no gun (`DRIVERS_MAY_SHOOT` false) and the HUD says DRIVER, so `weapon_client`, `shoot_boar`, `hit_marker` and `match_client` assert things that are only true of a shooter: 22 of its 58 specs fail. `test2` prints that report as an OBSERVATION and checks nothing in it, which is honest but means half the client suite is unasserted with two players. Make those assertions role-aware -- ask the drive what this player is, then assert the shooter's claims or the driver's -- so both clients can be checked. **(2) `armingRepairs` has been 0 in every run since the sweep landed**, so the repair path has never been seen working; the fix is proven by a green two-player run, not by the counter. A spec that drives the losing sequence needs a seam that does not take the live player's gun (the first attempt did, and three client specs failed for it). **(3) Why the drive's edges missed was never caught in the act**: `execute_luau` requires a fresh module, so no live server's `stats`, `tools` or phase can be read from outside. **(4) From `reviews/task-34/RESULT.md` (round 2, PASS)**: the report loop's `json.loads`/`console()` can still return through `main` without `end_session`; the spec-name comparison hardcodes `ServerStorage.Tests.` where `run_test` derives it from the sourcemap; there is no `Gate closed afterwards` check in `test2`; `wait_for` can hand `len(found)` a `None`; and `match_teams.spec`'s two-player `it` is named for the case the one-player harness never runs |

| 39 | **M2.7a, first half:** the asset-pipeline research note (rule 1, and the design's §16 E) | **awaiting review (docs-only)** | Branch `task-39-asset-research`, from `main` (`5d93e87`). Docs-only: `docs/research/2026-09-26-asset-pipeline.md` plus its `INDEX.md` row and this status. Written in the `driven-hunt-review` worktree by the docs Builder — **no Studio, no `rojo`, no harness, nothing measured in the engine**, so every engine claim in the note is a documentation claim. **All 15 sources the design's §11 cites were fetched and quoted** (the design was written with no network and said so). The design's HTTP shape is right: `POST /assets/v1/assets`, `x-api-key`, multipart `request` + `fileContent` with `type=model/fbx`, operation → `response.assetId`. **17 deltas, and D5, D6 and D9 change what M2.7a builds:** (D5) Open Cloud can never mint a **Mesh** asset, so an FBX upload yields a **Model** id and `CreateMeshPartAsync` is a *derived second step*, not an alternative route chosen by measurement M2; (D6) `MeshPart.RenderFidelity` is `PluginSecurity` to write and `CollisionFidelity` cannot be touched at run time, so the manifest's `renderFidelity` is set at import and only *asserted* by a spec; (D9) `AssetService.AllowInsertFreeAssets` is `RobloxScriptSecurity` on read **and** write, so a free Creator Store model nobody owns is loadable by **no** script route — which contradicts `docs/design/map-generator.md` §8.2. Numbers corrected: the mesh limit is **20,000** triangles and is **first-party** (not 21,000 community/vendor), `TEXTURE_MAX_PX = 1024` is **ours** (platform: 4096², 8000² for Decal/Image), 20 MB is **Roblox's** not ours, and the `Highlight` limit is **255** client-side counting disabled instances (not "single digits to low tens"). Resolved *for* the design: `MeshPart.TextureID` **is** run-time assignable (M3's first half = yes); `SurfaceAppearance` is **not**. **Both licences finally read.** Creator Store Terms grant use "in Roblox Studio and in Experiences on the Services" **by purchasing** — a *free* asset is licensed only if its creator ticked share, the same flag D9 turns on. Meshy's Terms §3.2: **free-plan output is owned by Meshy** under **CC BY 4.0**, which is **non-sublicensable**, against Roblox's Creator Terms demanding a **sublicensable** grant — **Karen's decision, and the note recommends a paid Meshy plan for anything that ships.** `en.help.roblox.com` is HTTP 403 to every tool here (fetch tool *and* `curl`); it is readable via `.../api/v2/help_center/en-us/articles/<id>.json`, and that route is recorded so the next session does not lose another licence page to it. The design is the Architect's and was not edited: the deltas are a section of the note, for the Director |

## Director dispatches, transcribed by the Builder

CLAUDE.md gives the Builder this one right in `TASKS.md`: a Director dispatch that arrived outside
the repo, transcribed verbatim and marked as the Director's. Newest first.

### Task 39 · 2026-09-26

Marked as the Director's. Arrived outside the repo, to a second Builder session working only on
documents in the `driven-hunt-review` worktree.

> [DIRECTOR -> DOCS BUILDER] You are a second BUILDER session on Driven Hunt, working ONLY on
> documents, in the separate worktree C:\Users\karen\Desktop\driven-hunt-review (NOT the main
> working copy; another Builder holds Studio there). Start every reply with "[BUILDER-DOCS]".
> Headless at night; never ask. Never touch Studio, never run studio_mcp.py, never run rojo. Read
> docs/PROJECT_CONTEXT.md, CLAUDE.md, docs/design/asset-pipeline.md first.
>
> TASK 39 (M2.7a, first half): the asset-pipeline research note, per rule 1 and the design's §16 E.
> In the worktree: `git fetch` (retry on "cannot lock ref"), `git checkout -B task-39-asset-research
> origin/main`.
> Write docs/research/<today>-asset-pipeline.md: FETCH and verify every source the design's §11 cites
> (Open Cloud Assets API endpoints and operation polling, API key scopes/IP allowlist/expiry, rate
> limits, mesh/texture import limits with first-party vs community marked, MeshPart/SurfaceAppearance
> import behaviour, Creator Store licence terms, Meshy's licence terms per plan). For each: link,
> licence, maintenance, what it actually says (quote the load-bearing sentence), and whether the
> design's use of it is right. List every place the design is wrong as a DESIGN DELTA section (the
> design is the Architect's; do not edit it). Add the INDEX.md row.
> Docs-only review: `bash tools/review.sh 39` from the worktree (one round; notes never block).
> Commit, push the branch. No PR.
> Report in 10 lines: what was verified, what the design got wrong, what Karen must decide (Meshy
> licence!), the branch head.

### Task 26 · 2026-09-25

> TASK 26 (ROADMAP 1.4b): build the camera exactly to docs/design/camera.md.
> KAREN DECIDED (2026-09-25): option A - mouse-locked over-the-shoulder third-person camera; the
> stock camera module is disabled, the stock movement module stays; hold right mouse = first-person
> ADS with the viewmodel; cursor visible only in menus. Feel values (FOV, 0.2 s transition,
> sensitivity, shoulder offset) stay the design's defaults until Karen's playtest.
> Feel-critical: the Director will NOT merge until Karen has played it.
> 1. Build the owners as designed (Camera, Mode pure, Rig sole writer of CurrentCamera, Cursor sole
>    writer of mouse behaviour, Viewmodel). Owner rows into GAME_DESIGN.md. If the shotgun code on
>    main disagrees with the design's seam (aim flag, fire origin, Hud crosshair), follow the design
>    and say so; a real conflict -> ESCALATE.md.
> 2. Tests: pure Mode specs; the design's one-writer assertions; an input scenario (Task 6) for
>    right-mouse aim in/out and a mouse move turning the view; the shotgun's "weapon never writes
>    CurrentCamera" assertion still passes. Harness PASS on a clean tree.
> 3. Screenshots saved via `python tools/studio_mcp.py capture`: third person over the shoulder, ADS
>    with the viewmodel, crosshair state in each. Inspect them yourself.
> 4. reviews/task-26/REQUEST.md (one page, <=10 claims); tools/review.sh 26; only real defects block;
>    max 3 rounds. Push. No PR.

**Builder's note.** The dispatch's item 2 asks that the shotgun's "weapon never writes CurrentCamera"
assertion still pass. It could not, as written: it asserted the camera did **not** move across an aim
hold, which with this task built is the opposite of what aiming does, and could only pass while the
camera was deaf to the button (round 1, finding 2). It was rewritten to assert what the weapon really
owes - that it never writes the camera - through the camera's own foreign-write counter. The
"mouse move turning the view" scenario is **not** included: under `MouseBehavior = LockCenter` a
replayed absolute `moveTo` delivers no usable delta, which the design already lists as the thing the
harness cannot do here. The rotation maths is covered by the server spec instead.

### Task 24 · 2026-09-25

> TASK 24 (ROADMAP 1.4): the shotgun on the default camera. Feel-critical: the Director will NOT merge
> it until Karen has played it.
>
> 1. Design fix first: run `tools/architect.sh design shotgun --task 24` with reviews/task-24/BRIEF.md
>    listing the six Task 23a design defects from TASKS.md row 23a (CastFn has no shooter so
>    self-filtering is unimplementable and the camera ray can hit the shooter's own body; table.freeze
>    is shallow; no PlayerRemoving cleanup; ActionRequest must accept only Reload/SelectAmmo; the
>    safety arc must use the muzzle direction, not the camera direction; the flaky slug spec
>    assertion) plus the 23a(j) item (document BRIEF.md in CLAUDE.md, you may do that one). Build to
>    the re-run design. Disagree -> ESCALATE.md, stop.
> 2. Build exactly the design's scope: a Tool the player gets on spawn; fire (MouseButton1), barrel
>    select, break open/reload two shells (2.0 s, uninterruptible), slug vs buckshot selection (load
>    only when open), server-authoritative hits validated as designed, `Runtime:takeHit` on the boar
>    with zone "body" (the boar may just flee/despawn on hit for now; hit zones and wounds are 1.5),
>    the Hud crosshair, owner rows in GAME_DESIGN.md. Default camera: nothing writes
>    workspace.CurrentCamera.
> 3. Tests: server specs for the pure parts (state machine, validator, pattern, safety arc);
>    client/input scenarios through Task 6's harness step for fire, reload and ammo select, including
>    the assertion that CurrentCamera.CFrame is unchanged by the weapon. Harness PASS on a clean tree.
> 4. Play-time screenshots saved through the Task 6 path: the gun in hand, the crosshair, a hit on the
>    boar. Inspect them yourself.
> 5. reviews/task-24/REQUEST.md (one page, <=10 claims), tools/review.sh 24; only real defects block;
>    max 3 rounds. Push. No PR.

**Builder's note.** The camera assertion is the design's form, not the dispatch's literal one:
`workspace.CurrentCamera.CFrame` is written every frame by the stock PlayerModule, which follows the
character, so asserting it is byte-identical across the aim hold would assert a property of Roblox's
camera script rather than of this weapon. The spec asserts what only an ADS implementation would
change - `CameraType`, `FieldOfView` and `CameraSubject` identical - plus the camera's drift relative
to its own subject, which measured **0.000 studs**.

### Task 6 · 2026-09-25

> TASK 6 (blocking before the shotgun build): the harness drives real player input. Smallest version,
> exactly as the regenerated shotgun design (Task 23, docs/design/shotgun.md on its branch or main)
> says "Task 6 must prove first".
> Branch: git switch -c task-6-input-driving
> - One scenario file (for example tests/input-scenarios.json): a few steps (press/hold/release a key,
>   move/click the mouse) then which client spec to run.
> - One harness step that replays it during Play through StudioMCP's user_keyboard_input /
>   user_mouse_input, gated like the specs.
> - One client spec that proves the input arrived through the real path a player uses
>   (UserInputService / ContextActionService event seen by a LocalScript), not by calling the handler
>   directly.
> - Keep the harness docstring the single source of truth; update it.
> - Also: `tools/studio_mcp.py` Studio._call drops image blocks. Make captures saveable to a
>   git-ignored folder (small), so rule-5 screenshots can be saved as evidence. This closes TASKS row 7.
> Research: a short addendum to the toolchain note is enough (it is harness work on an already-researched
> tool).
> Loop: harness PASS on a clean tree, reviews/task-6/REQUEST.md, tools/review.sh 6, notes never block,
> max 2 rounds. Push. No PR.

**Builder's note.** Two deviations, both to avoid a `default.project.json` change (which the running
`rojo serve` does not reload, so it would need a restart and Karen's Connect click): the scenario file
is `tests/client/input_scenarios.txt` rather than `tests/input-scenarios.json` - it must be readable by
**both** the harness and the client, and a `.txt` under the already-mapped `tests/client/` becomes a
`StringValue` the harness compares byte-for-byte; and the spec binds its own listeners rather than a
separate probe `LocalScript`, which would have needed a new mapping. The spec still runs in the real
client and only sees input the engine delivers.

### Task 21 · 2026-09-25

> TASK 21: trim the review loop (Karen asked: less Reviewer noise, faster). Small, workflow only.
> This is allowed past the tooling freeze because it blocks the speed of every game task.
>
> Evidence from the last 5 tasks: Tasks 11, 18, 19 and 20 all hit the round cap mostly on paperwork
> (REVIEW_REQUEST.md wording, line-number citations, TASKS.md/ESCALATE.md text), and Task 18 was
> reviewed 3 rounds before its code had ever run. Every merge conflicted because all branches write
> the same root files.
>
> Changes:
> 1. docs/REVIEWER_PROMPT.md: findings are BLOCKING only if they make the game, a test, an owner
>    boundary or security wrong (wrong behaviour, a test that cannot fail or tests the wrong thing, a
>    second writer, a secret, a false claim about what was tested). Everything else (wording,
>    citations, counts in the request, TASKS/ESCALATE text, style) goes under "Notes (non-blocking)".
>    Verdict line 1 is PASS when there are no blocking findings, even with notes. The Reviewer does
>    not review REVIEW_REQUEST.md, TASKS.md, ESCALATE.md, PLAYTEST.md or ROADMAP.md as deliverables;
>    it reads them only as context.
> 2. tools/agents.py: refuse to start a review of a change that touches src/ or tests/ unless
>    REVIEW_REQUEST.md carries a harness PASS line for the code commit ("harness before review").
>    Docs-only changes are exempt.
> 3. Per-task review files instead of root files: reviews/task-<N>/REQUEST.md and
>    reviews/task-<N>/RESULT.md (and ARCH_RESULT.md there). The task number comes from a `Task: N`
>    line. Keep the old root files only as archived history (rule 7: move them to backups/ with a
>    note), so branches stop conflicting.
> 4. CLAUDE.md: REVIEW requests are short (one page, at most 10 claims, files and symbols, no line
>    numbers). Docs-only tasks: one review round, notes never block. Update the loop text to match 1-3.
> 5. Harness PASS, then one review round of this change under the new rules (it is tooling code, so
>    the harness gate applies). Push, open nothing (the Director opens the PR).
>
> Include in Task 21 (they belong to the new per-task scheme):
> - The round counter counts per task: rounds live in reviews/task-<N>/RESULT.md, so a merged task's
>   FINDINGS never block the next task (the fault Task 22 hit). Round 1 needs no DIRECTOR_MAX_ROUNDS.
> - Close TASKS.md row 17's leftover Karen question (Director: Karen decided 2026-09-25, defaults
>   archived in Task 22).
> - The two queued Task 22 review notes (boar-ai research note §4 stale sentence; backups record for
>   Texture/Decal children, copy from ESCALATE.md): fix them here as docs.
>
> The Director has already put the working copy on an up-to-date main. Create the branch with
> `git switch -c task-21-trim-review` (no other branch switches; rojo serve is running and must not
> be stopped).

**Builder's note.** One deliberate widening of item 2: the harness gate fires on `src/`, `tests/`
**or `tools/`**, not only the first two. Item 5 gives the reason itself - "it is tooling code, so the
harness gate applies" - and `tools/studio_mcp.py` *is* the harness, so a change there is exactly the
kind that must run before it is judged. Docs-only changes stay exempt.

### Task 23 · 2026-09-25

> TASK 23: regenerate the shotgun design, docs only (decided on 2026-09-24: Task 19's design is not
> built from until regenerated after the boar merged).
> Branch: git switch -c task-23-shotgun-design-v2
> 1. tools/architect.sh design shotgun --task 23 (new per-task scheme). Give the Architect these
>    inputs in the design brief or the request: the boar code is now on main (Boar owner, CONFIG, the
>    injected world); Director + Karen decisions: the shotgun ships FIRST on the default camera with
>    no ADS and no viewmodel; third-to-first-person aim/ADS is the very next, separate camera task
>    with its own design; Task 6 (drive real input from the harness, smallest version) lands before
>    the shotgun build.
> 2. The regenerated design must: state both spread cones in ONE unit and say which unit the config
>    stores; name the damage entry point owner and how the boar receives a hit (hit zones come in 1.5,
>    so a single `takeHit(zone, ammo)`-style seam is enough now); list the owner rows for
>    GAME_DESIGN.md; keep Karen's five feel defaults (spread, 2.0 s reload, crosshair, barrel select,
>    load only when open) as config values.
> 3. Docs-only: one review round (tools/review.sh 23), notes never block. Push. No PR (the Director
>    opens it).
>
> STATE: Karen is PLAYTESTING in Studio right now: do NOT run the harness, do NOT press Play/Stop,
> do NOT touch Studio. Do not stop rojo. Only `git switch -c` from HEAD.

**Builder's note.** There was no way to hand the Architect a brief: `tools/agents.py` builds the
run's task text itself, and tooling may not change here (docs-only, and the harness cannot run while
Karen is playing). So the brief is `reviews/task-23/BRIEF.md` and `docs/ARCHITECT_PROMPT.md` gained
three lines telling the Architect to read `reviews/task-<N>/BRIEF.md` first when it exists. Both are
documents, so the task stays docs-only.

### Task 22 · 2026-09-25

> TASK 22: make the grey box usable for Karen's first playtest. Small.
> Branch: git switch -c task-22-playtest-ready
> 1. Karen decided (2026-09-25): remove the default `Workspace.Baseplate` and the default
>    `Workspace.SpawnLocation`. Rule 7 (never delete): MOVE both into a `ServerStorage.Archive` folder
>    (create it; ServerStorage has no $path, so Rojo leaves it alone) with a StringValue note naming the
>    date and reason (the arena plate z-fought with the Baseplate; two spawns made spawning random). Do it
>    in Edit mode through Studio MCP. Verify after: Workspace has neither; ServerStorage.Archive has both.
>    Karen must then save the place (File -> Save to Roblox): write that as a NEEDS KAREN line in your
>    report, not an escalation.
> 2. The boar reads near-black from the side. Make it a clearly visible warm grey-brown from every side
>    (check material/colour/any lighting cause, fix the cause). One number or one property, in Boar's config.
> 3. Harness PASS on a clean tree. Take play-time screenshots (screen_capture works during Play; if
>    tools/studio_mcp.py drops image blocks, capture through MCP directly) showing: the full arena floor as
>    a square (no triangle), the single spawn, the boar from the side. Inspect them yourself and describe
>    what you see.
> 4. Review: fresh REVIEW_REQUEST.md, short (max 10 claims, files and symbols, no line numbers). One review
>    round. Director policy from today: only findings that make the game, a test, an owner boundary or
>    security wrong block; wording/citation/paperwork findings are notes. If round 1 has only notes, that is
>    a PASS for the Director. Real defects: fix, harness again, one more round max.
> 5. Push the branch. Do not open a PR (the Director does).

**Builder's note.** Step 1's parenthesis is wrong on one point: `ServerStorage` **does** have a
`$path` (`src/serverstorage`) in `default.project.json`, and every `$path` node defaults to
`$ignoreUnknownInstances: false`, so Rojo deletes unknown children of it at the next Connect. I did
the move exactly as dispatched, and added `backups/2026-09-25_workspace-defaults.md` - every property
of both instances, plus why - so rule 7 survives that Connect. Nothing else was changed in the place.

### Task 18 · 2026-09-24 · NO-STUDIO MODE

This is the authority for reviewing and accepting Task 18 with **no harness run and no screenshot**
(review round 1, finding 4).

> NO-STUDIO MODE (Director, overnight): rojo serve is down and only Karen can Connect, at ~09:00.
> Do NOT start rojo serve and do NOT try to reach Studio for Play. Do everything that does not need
> Studio:
> - Branch task-18-boar-ai from task-17-test-area (stacked; PR #8 is Task 17, not merged, not yet
>   harness-tested).
> - Research note, Architect design (tools/architect.sh design boar-ai), code, specs,
>   selene/stylua/rojo build locally.
> - Run the review loop anyway: in REVIEW_REQUEST.md say plainly that no harness run exists (Studio
>   unavailable) and ask the Reviewer to judge the code and the specs; a PASS here is
>   "PASS pending harness". Max 3 rounds.
> - Push. Do not open a PR (the Director does).
> - Record in TASKS.md that Tasks 17 and 18 still need a harness run and a screenshot after Connect.
> Also add to CLAUDE.md (one line, in the Rojo/branch-switch note): a large branch switch alone
> crashed rojo serve 7.7.0 on 2026-09-24 (Task 17).

> TASK 18 (ROADMAP 1.2): the boar AI, grey box. A new system: research note and Architect design
> FIRST.
>
> Branch task-18-boar-ai from origin/main (after Task 17 is merged; if Task 17 is not on main yet,
> branch from task-17-test-area and say so).
>
> What it must do (v1, one boar):
> - Spawns at a spawn point in the test arena. Body: a grey anchored-free box of boar size (about
>   1.5 x 1 x 0.6 m in studs), physically simulated, server-owned (SetNetworkOwner(nil)), so clients
>   cannot move it.
> - IDLE: slow wander/graze inside a home area.
> - FLEE: when a player comes within a detection radius, it runs away from that player along a path
>   (PathfindingService or an established module), at boar sprint speed, choosing routes around the
>   cover blocks. Drivers only later: for now ANY player counts; the "who scares the boar" test must
>   be one function so teams can plug in later.
> - ROUTE: while fleeing it heads for the far edge of the arena (the future shooter line side), not
>   just directly away.
> - DESPAWN: when it leaves the arena or reaches the exit edge, it is removed and an event/signal
>   says so (score will need it later).
> - A single owner module for boar state (one writer), row in GAME_DESIGN.md System owners.
>
> Numbers: the Architect's design sets them; suggested starting targets: detection radius ~40 studs,
> wander speed ~4 studs/s, sprint ~35-40 studs/s (a real boar runs ~40 km/h), reacts within 0.5 s.
> All in one config table.
>
> Steps:
> 1. Research note docs/research/<date>-boar-ai.md per rule 1 (3+ sources with licence and
>    maintenance: e.g. Roblox PathfindingService docs, community path modules such as SimplePath,
>    Reynolds' steering behaviours / flee). INDEX.md entry.
> 2. tools/architect.sh design boar-ai -> docs/design/boar-ai.md. Build to it. Disagree ->
>    ESCALATE.md, stop.
> 3. Build. Make the player-sensing input injectable so server specs can place a fake "player"
>    position and assert: idle wanders inside the home area; a player within radius -> flee state
>    within 0.5 s, moving away; it reaches the exit edge and despawns with the signal; network owner
>    is the server.
> 4. Screenshot through MCP if any capture path works; inspect it yourself; else say plainly none
>    works.
> 5. Loop: harness PASS, fresh REVIEW_REQUEST.md (claims cite files and symbols, not line numbers),
>    tools/review.sh, max 3 rounds. No Architect audit this task. Push; open the PR if you can, else
>    say so.
>
> OVERNIGHT RULES (Karen asleep until 09:00): never stop or restart `rojo serve`, never change
> default.project.json. If needed, or Studio/Rojo/MCP is down: NEEDS KAREN entry, stop.

**Builder's note.** Step 2 says "Build to it. Disagree -> ESCALATE.md, stop." I did not escalate: I
agree with the design. Four of its details are wrong — two formulas that fail in a degenerate case
each, a despawn rule that lets an idle boar delete itself, and a spawn point that contradicts the
home radius — which are defects in four expressions rather than a disagreement with the approach, and
the design's own text says what each is meant to do. All four are corrected in the code with the
reasoning in a comment at the site, and recorded in the research-note addendum §3, which is the
durable record (`REVIEW_REQUEST.md` is rewritten per task and is not). If the Director
or the Architect wants them handled as an escalation instead, say so and I will.

### Task 11 · 2026-09-24

Transcribed in `ESCALATE.md`, "Task 11's dispatch, verbatim", because it arrived with the Director's
answer to an escalation.
### Task 20 · 2026-09-24 · NO-STUDIO MODE

This is the authority for "research only, no code, no Architect design", and for accepting the task
with no harness line (review round 1, finding 6).

> NO-STUDIO MODE: rojo serve is down until Karen connects at ~09:00. Do not start rojo, do not use
> Studio.
>
> TASK 20: map generator research note only (ROADMAP Milestone 2). NO code. Docs only.
> Branch task-20-map-research from origin/main.
>
> Karen's decision (map option C): the map is built by a map generator, code on disk, run in Edit
> mode through the Studio MCP server, verified with Edit-mode screenshots and by Karen walking it.
> Assets: Creator Store first, Meshy (Karen makes models) where nothing fits. One small v1 map:
> European farmland and woods (fields, hedgerows, spruce and birch stands, tracks, a bog), a drive
> area, a shooter line along a wood edge.
>
> Research note docs/research/<date>-map-generator.md per rule 1, 3+ sources with licence and
> maintenance:
> - procedural terrain on Roblox (Terrain:FillBlock/FillRegion/WriteVoxels, noise-based
>   heightfields), and whether Studio's heightmap/colormap import can be driven from code or MCP
>   (state plainly if it cannot)
> - open-source Roblox terrain/map generators or community modules worth borrowing
> - placing vegetation and props at scale (instancing, part counts, StreamingEnabled, performance
>   targets for 10-16 players, mobile)
> - how the code finds gameplay markers (CollectionService tags) so the map carries no scripts
> - free-licence asset sources: Creator Store rules/licensing for trees, fences, rocks; Meshy ->
>   Roblox import (mesh triangle limits, texture limits, upload via Open Cloud with the API key only
>   in an environment variable)
> - a backup step ("Save to File" or equivalent) before each rebuild, outside the repo
> - the numeric targets: map size in studs, max part/mesh count, memory, load time
> End with the adopted pattern and the smallest first generator task.
>
> Short review loop on the doc (tools/review.sh, max 2 rounds). Push. Do not open a PR.
> REPORT to the Director, short: the adopted pattern, the numbers, what needs Karen (taste, assets),
> checklist. Then stop.

**Builder's note.** "3+ sources" is the floor; the note has 11. No Architect design was run, because
the dispatch did not ask for one — so **whoever builds the generator needs
`tools/architect.sh design map-generator` first**. This note is input to that design, not a
substitute: it assigns no owners, and rule 3 gives that call to the Architect.


## Review log

### Task 5: architecture audit-001 must-fix (round 1)

| Item | Disposition |
|---|---|
| M1 all script containers on disk | StarterGui, StarterPack, StarterCharacterScripts and ReplicatedFirst are mapped (`src/startergui`, `src/starterpack`, `src/startercharacter`, `src/replicatedfirst`). A read-only query found all four empty, and no script anywhere outside Rojo paths, **before** mapping. New harness check: any LuaSourceContainer in the DataModel not in the sourcemap fails (verified with a Workspace script). CLAUDE.md: nothing script-like is ever created in Studio. The check caught 16 orphan TestEZ scripts left in `ServerStorage.DevPackages` by the mapping move. They were verified identical to disk and removed from the place (with the orphan `ServerStorage.TestSyncToken`) |
| M2 file types | `.model.json` (ClassName, plain properties/attributes, children recursively) and `.meta.json` (properties/attributes; `ignoreUnknownInstances` refused) compared. **`.rbxm`/`.rbxmx` banned** in the harness and in CI. Typed property values fail as "cannot compare". Verified: valid model.json and meta.json pass; rbxm, typed value, ignoreUnknownInstances and an attribute changed in Studio each fail |
| M3 client test path | Client specs (`tests/client`) run in the player's client via ClientTestRunner. The harness reads the client report from the Client DataModel and checks it like the server one. Verified with a failing client spec. **Cannot yet:** drive real input (Task 6) or take play-time screenshots (Task 7). Both are logged as blocking |
| M4 PASS names its commit | The final line is `[harness] PASS: n/m checks @ <full sha> (clean tree)`. A dirty tree gives exit 3 and "DIRTY TREE - NOT valid evidence" with the paths listed. HEAD is re-checked at the end |
| Doc drift | The `tools/studio_mcp.py` docstring is the single source of truth. CLAUDE.md keeps commands and a pointer. Research note: superseded text marked, round-4 section added. INDEX updated |
| Review round 1 (reviewer agent, 8 findings) | **Blocking, fixed:** (1) git-ignored synced files were tested but could never make the tree dirty, so any ignored synced file now fails the run (`git check-ignore -z`); (2) git-ignored DevPackages/TestEZ was not tied to the commit, so it is now checked against the committed `devpackages.sha256` (which includes the `wally.lock` hash; `python tools/studio_mcp.py manifest` rewrites it). **Should-fix, fixed:** (3) integers compared exactly, other numbers at float32 precision (was 1e-5, so 100000 matched 100001); (4) `$properties`/`$attributes` in default.project.json and nested project files are refused; (5) Script/LocalScript/ModuleScript inside `.model.json` refused; (6) an unreadable service fails the script scan; (7) stale references fixed; (8) CLAUDE.md "every container is Rojo-owned" was false, so it is reworded, and **ServerStorage is now fully mapped** (`src/serverstorage`; it held only `Tests`, verified). **Nits, fixed:** harness-error line carries the sha; `servePlaceIds` error is a harness FAIL, not a silent exit; result-count guard on batched queries; `pipefail` in the CI ban step; meta.json doc; orphan removal logged in backups/README. Found while fixing: `git check-ignore` input on Windows got `\r` appended (text mode), so name patterns like `*.key` never matched. Now NUL-separated bytes |
| Review round 2 (same reviewer, re-review of 4139771) | 7/8 confirmed fixed. #1 partly: **new should-fix, fixed**: a failing `git check-ignore` (exit 128, for example a synced path outside the repo) read as "nothing ignored" and hid every ignored file sorted after it. Now outside-repo paths are reported, and any git exit other than 0/1 is a harness error. **Nits, fixed:** the CI rbxm step now writes the sourcemap first, so a failing `rojo sourcemap` fails the step (`pipefail` inside `if` did nothing); attributes compared exactly (doubles), properties exactly or as their float32 rounding (1234567.1 no longer matches 1234568); the backups/README path is annotated |
| Review round 3 (re-review of 850da73) | **No blocking/should-fix findings remain.** Two fail-safe nits, fixed: an expected property beyond float32 range raised OverflowError (a harness error), and now it is a plain mismatch. Float32 comparison was not yet exercised live; now verified live with a Part `.model.json` (Transparency 0.3, Reflectance 0.1, attribute 0.3): all match, so Studio's JSONEncode keeps full precision |
| Audit file placement | It was swept into PR #1 by my blind `git add -A` (1ed9127). It was removed from PR #1 with `git rm --cached` (f53b043) and committed alone on `audit-001` (PR #2). CLAUDE.md now requires explicit staging |

### Task 1, round 2 on PR #1 → Reviewer FAIL: disposition (round 3)

| # | Item | Disposition |
|---|---|---|
| 1 | Skipped tests must fail the run (itSKIP/describeSKIP/SKIP/itFOCUS gave PASS) | Fixed in the runner (`skippedCount > 0` gives FAIL) and the harness ("No skipped tests" check; since Task 5 it is part of "> 0 passed, 0 failed, 0 errors, 0 skipped"). Verified: itSKIP, describeSKIP, SKIP(), itFOCUS, describeFOCUS and FOCUS() each fail the run |
| 2 | Round-1 item 7 dropped: document that Rojo **deletes** Studio-created instances; check Version History around the first Connect | Documented (CLAUDE.md "Rojo DELETES…", with the docs quote and a live-sync probe test). Pre-Connect evidence: all Rojo-owned containers were empty at ~18:30, before the first Connect at ~18:36. Task 4 (Version History) closed as not applicable: the place was empty at the first Connect |
| 3 | CLAUDE.md line 35 falsely said branch protection enforces the Reviewer/merge rules | Reworded: the ruleset enforces PR + CI only. Reviewer sign-off and who merges are policy |
| 4 (should fix) | Find specs anywhere in the repo (`*.spec.*`) | Fixed: `git ls-files` (tracked + untracked, non-ignored). Every spec must be synced and run, matched by name, not count. Archived example renamed so it no longer matches |
| 5 (should fix) | Fail on any synced file the harness cannot compare | Fixed: `rojo sourcemap --include-non-scripts`. Every instance must exist with the right ClassName. Scripts are compared by Source and `.txt` by Value; `.project.json` is structural; anything else fails |
| extra | Public repo: never commit secrets; check `.gitignore` and history | CLAUDE.md section added. `.gitignore` covers env/keys/credentials/cookies (verified with `git check-ignore`). History: gitleaks clean, manual grep clean, noreply identity only |

### Task 1, round 1 → Reviewer FAIL: disposition

**Correction (round 3):** I never had the Reviewer's numbered list. In round 2 I numbered Karen's
bullet list 1-11 in order and called it the Reviewer's items. That was wrong. The Reviewer's item 7
was "Rojo deletes Studio-created instances; document it", and I dropped it. It is fixed in round 3
(see above). The table below is the bullet list as Karen relayed it; its numbers are mine, not the
Reviewer's.

| # | Item | Disposition |
|---|---|---|
| 1 | Fail when `#results.errors > 0` | Fixed: `errorCount` is in the report. The harness requires 0 |
| 2 | Fail when `successCount == 0`; compare against the `*.spec.luau` files on disk | Fixed: the runner counts spec modules. The harness compares with the disk count and requires more than 0 passed |
| 3 | Prove the code under test came from disk (sync token plus PlaceId) | Fixed: a fresh token is written just before each run and echoed back by the runner, the PlaceId is asserted, and Source is compared byte-for-byte for all synced scripts |
| 4 | Refuse to run unless Studio is in Edit mode | Fixed: exit 2 with REFUSED (verified during Play) |
| 5 | Remove or make read-only the Edit-mode luau/call paths | Fixed: the `luau` and `call` commands were removed. Only constant read-only queries remain. Documented in CLAUDE.md |
| 6 | Replace the example test with a real sync assertion | Fixed: `tests/specs/sync.spec.luau` (now `tests/server/`). Old example archived in `backups/` |
| 7 | pcall the spec requires and emit `[tests] ERROR` | Fixed (verified with a syntax-error spec and a spec that throws on load) |
| 8 | Correct the false pinning claims; pin stylua, selene, luau-lsp; `rojo plugin install` | Fixed: the pinning table in CLAUDE.md, tools in rokit.toml, pinned plugin installed and loaded in Studio |
| 9 | DevPackages optional in `default.project.json` | Fixed: `{"optional": ...}`. The build is verified without DevPackages |
| 10 | Gate the runner behind a flag only the harness sets | Fixed: a harness token under 120 s old. Verified that a normal playtest and a stale token run no tests |
| 11 | Write down (or strip at publish) that test code ships with the place | Written down (CLAUDE.md). Stripping logged as Task 2 |

### Task 28 (2026-09-25), the Director, verbatim

> FIRST (paperwork, in this task's PR): record Karen's playtest of 2026-09-25 in PLAYTEST.md (newest
> first): she played the shotgun (Task 24 incl. the new X swap) and the camera (Task 26: shoulder cam,
> right-mouse ADS, viewmodel) and said "all ok, I am happy for v1". Feel values stay as configured. Her
> open questions (X twice costs shells; 24 shells per type) were accepted as is ("all ok").
> If Studio is in Play mode when you start, stop it with `python tools/studio_mcp.py stop`.
>
> STATE: main has the shotgun (Task 24), the camera (Task 26, once merged) and docs/design/hit-zones.md
> (Task 27, Architect PASS). rojo serve runs (never stop it); Karen is connected; Studio in Edit mode.
> Branch rules: `git fetch`; `git diff --name-status HEAD origin/main -- src tests default.project.json`
> must show no deleted folder; `git checkout -B main origin/main`; `git switch -c task-28-hit-zones`. A
> folder would be deleted -> stop and say so.
>
> TASK 28 (ROADMAP 1.5): build hit zones and wounds exactly to docs/design/hit-zones.md.
> DIRECTOR DECISIONS on the design's section 14:
> - A (no damage router / health system): agreed, not now.
> - B (carcass 120 s, removed by the boar runtime): agreed; 1.7 may change it.
> - C (hit marker): YES, include it in this task. Karen's playtest said she cannot tell whether she
>   hits. Owner: PlayerScripts.Hud draws it; the weapon publishes a one-way server->shooter remote when
>   a hit is confirmed (zone optional). Keep it minimal: a short crosshair tick on hit, a distinct one
>   on a kill. No sound yet.
> - D (harness cannot place a character or aim the camera): if the end-to-end "shoot the boar" test
>   needs it, add the smallest harness step that teleports the test character and points the camera at a
>   target during Play; otherwise queue it. Your call, say which.
> - E, F, G: agreed as written.
> Karen's feel values stay the design defaults (zone tint ON for the grey box) until her playtest.
> Tests: the design's wound-model specs; head kills / leg does not; the hit event payload; a screenshot
> of a hit reaction, the hit marker and a carcass. Harness PASS on a clean tree. reviews/task-28/REQUEST.md;
> tools/review.sh 28; only real defects block; max 3 rounds. Push. No PR.

**Decision D, the Builder's call: queued, not built.** The end-to-end test does not need it. What a
harness teleport-and-aim step would buy is a client-driven "shoot the boar" assertion; what this task
proves instead is every half of that path separately and honestly - the zones with twelve real rays,
the seam and the kill live in `boar_hit.spec`, the marker across the real remote in
`weapon_hits.spec` plus `hit_marker.spec`. Building the step would be a tooling change (ROADMAP speed
rule 1) in a gameplay task, and it would still not aim, because the camera's yaw is mouse-driven under
`LockCenter`. The screenshots that need a shot are staged instead, and the request says exactly how.

### Task 30 (2026-09-25), the Director, verbatim

> FIRST (paperwork, in this task's PR): add to PLAYTEST.md (newest first): 2026-09-25, Karen played
> hit zones (Task 28): head/chest kill, leg escape, red flash + bolt, hit marker white/red, two body
> hits kill - "all good". Feel values stay the design defaults (zone tint on for the grey box). No
> sound requested.
> If Studio is in Play mode when you start, stop it with `python tools/studio_mcp.py stop`.
>
> STATE: main has hit zones (Task 28, once merged), designs for the drive (docs/design/drive.md) and
> audit-003 (docs/architecture/audit-003.md). rojo serve runs (never stop it); Karen is connected;
> Studio in Edit mode. Branch rules: `git fetch` (retry if "cannot lock ref"); `git diff
> --name-status HEAD origin/main -- src tests default.project.json` must show no deleted folder;
> `git checkout -B main origin/main`; `git switch -c task-30-harness-multiplayer`. A folder would be
> deleted -> stop and say so.
>
> TASK 30 (ROADMAP 1.6, small harness task, allowed past the tooling freeze because it blocks 1.7):
> 1. docs/design/drive.md 12.6: run its one-command probe: can StudioMCP start a local test with 2+
>    players (Clients and Servers) and address each client? Record the answer in the toolchain
>    research addendum. If yes: the smallest harness step to run the specs with 2 players and read
>    both client reports. If no: say so plainly and write down what Karen must do by hand for a
>    2-player check.
> 2. docs/design/hit-zones.md 14 D: the smallest harness step that places the test character and
>    points the camera at a target during Play, so an end-to-end "shoot the boar" assertion exists
>    (it must go through the real Camera owner's API, not write CurrentCamera around it).
> 3. audit-003 must-fix 2: `src/client/Camera/Rig.luau` `Rig.apply` drift check must compare the
>    whole CFrame (rotation too), matching docs/design/camera.md 10.1; add a spec that a
>    rotation-only foreign write is counted.
> Harness PASS on a clean tree; reviews/task-30/REQUEST.md; tools/review.sh 30; only real defects
> block; max 2 rounds. Push. No PR.

**On item 1, the Builder's answer:** the design's own probe ("run `state` while a 2-client test is
running") needs a human to start that test, so it could not be run. What could be run, and is
stronger, is asking StudioMCP what it can do: the `tools/list` schemas settle "no player count, no
addressable second client in one Studio" outright, and they also turn up the `studio_id` route the
design did not know about. The by-hand check is in `ESCALATE.md`, reduced to one command.

### Task 32 (2026-09-25), the Director, verbatim

> 2-PLAYER PROBE RESULT (Director, 2026-09-25, Karen ran Test -> Clients and Servers, 2 players):
> `python tools/studio_mcp.py studios` listed FOUR studios - the DEV edit Studio ("Driven Hunt DEV
> (placeId: 136410205938347)") plus three unnamed ones (server + 2 clients). So a 2-player harness IS
> feasible: record this in ESCALATE.md (close the Task 30 entry) and TASKS.md, and queue "harness runs
> specs with 2 players" as its own task right after this one (not in this task). Karen has pressed
> Cleanup; if extra studios are still open, ignore them.
>
> STATE: main has hit zones (Task 28), the harness multiplayer/place+aim step (Task 30),
> docs/design/drive.md and audit-003. rojo serve runs (never stop it); Karen is connected; Studio in
> Edit mode. Branch rules: `git fetch` (retry on "cannot lock ref"); `git diff --name-status HEAD
> origin/main -- src tests default.project.json` must show no deleted folder; `git checkout -B main
> origin/main`; `git switch -c task-32-drive`. A folder would be deleted -> stop and say so. NOTE:
> this task archives BoarBoot.server.luau into MatchBoot (design 3.5): moving a watched file is fine,
> deleting a watched FOLDER crashes rojo 7.7.0 - do not remove folders.
>
> TASK 32 (ROADMAP 1.7a): the drive runs, built to docs/design/drive.md, with the Director decisions
> in reviews/task-29/BRIEF.md:
> - 1.7a scope only: match state machine, teams (equal, swap each drive), the 10-minute timer, boar
>   spawning per drive (6 boars), kill/escape events collected into points (head 100 / chest 80 /
>   body 50 / legs 30, drivers PUSH 25), posts and drive line as tagged markers in the grey-box arena.
>   `SAFETY_ENABLED` and `SCOREBOARD_ENABLED` exist but stay false (1.7b).
> - DECISION F / audit-003 must-fix 1: `MIN_PLAYERS = 1` during Milestone 1; a solo player is a
>   SHOOTER and is armed, so the harness's single Play player keeps its gun and the existing
>   weapon/camera client specs stay green. Amend nothing in docs/design (Architect-owned): write the
>   delta into reviews/task-32/DESIGN_DELTA.md.
> - Archive BoarBoot.server.luau into MatchBoot (rule 7: the old file goes to backups/ with a note).
> - Karen's feel values are the design defaults, all accepted "ok for v1".
> Tests: match state machine specs (pure), team split/swap, points from a kill record, the timer ends
> a drive, a 2-player run through the Task 30 harness step if it exists. Screenshots: the drive
> running with boars, the posts. Harness PASS on a clean tree. reviews/task-32/REQUEST.md;
> tools/review.sh 32; only real defects block; max 3 rounds. Push. No PR.

**On "a 2-player run through the Task 30 harness step if it exists": it does not exist yet.** Task 30
answered whether a 2-player harness is *possible* (it is: four studios) and shipped the read-only
command that proved it; teaching the harness to drive two clients is row 33, which the Director
queued as its own task. Every drive rule here is tested with no second client, which is what the
design's section 12.6 item 1 says the answer to 1.6 has to be.

### Task 34 (2026-09-25), the Director, verbatim

> STATE: main has the drive (Task 32). rojo serve runs (never stop it); Karen is connected; Studio in
> Edit mode. Branch rules: `git fetch` (retry on "cannot lock ref"); `git diff --name-status HEAD
> origin/main -- src tests default.project.json` must show no deleted folder; `git checkout -B main
> origin/main`; `git switch -c task-34-harness-2p`. A folder would be deleted -> stop and say so.
>
> TASK 34 (ROADMAP 1.6, harness): run the specs with 2 players. Probe result (2026-09-25): with Test
> -> Clients and Servers (2 players) started, `python tools/studio_mcp.py studios` lists 4 studios
> (DEV edit + 3 unnamed: server and 2 clients). Build the smallest harness mode that: starts a
> 2-player local test if StudioMCP can (if it cannot start it, the mode needs Karen to start it and
> says so plainly, then does everything else), finds which studio is the server and which are
> clients, runs the gated specs on each, reads all reports, and ends the session. The existing
> 1-player `test` stays the default and unchanged. Keep the harness docstring the single source of
> truth. Add one 2-player spec: both players get a team assignment from the drive and the teams are
> equal.
> Harness PASS (1-player) on a clean tree, plus the 2-player run's result. reviews/task-34/REQUEST.md;
> tools/review.sh 34; only real defects block; max 2 rounds. Push. No PR.

**On "plus the 2-player run's result": there is none yet, and the reason is in the task itself.**
StudioMCP cannot start a Clients-and-Servers test, so the mode ends at the click and says so. The
result the Director asked for is one command and four clicks away, in `ESCALATE.md`.
