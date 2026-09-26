# Architecture audit 004

Commit `83922a4f2c745fd252ec101ff170d4b897a05113`, branch `task-46-audit` (`.agent-evidence/head.txt`).
Read-only session: Read, Grep, Glob. No Studio, no network, no git. Evidence precomputed in
`.agent-evidence/` (`INDEX.md`, six files).

**Brief.** `reviews/task-46/BRIEF.md` (Director): audit the UNMERGED stack as it will land on `main` —
`origin/task-44-map-full`, carrying Tasks 35, 36, 38, 41, 43 and 44. Previous audit
`docs/architecture/audit-003.md`. Speed rule 2: must-fix only if it blocks merging this stack or the
next game tasks (M2.3–M2.5 map, M2.7 assets, Karen's two-player playtest), and the audit names which.
Focus: second writers (Weapon/Tools, Match, Hud, Camera, MapGen vs TestArena markers), level- vs
edge-triggered state, test-only seams that could run in a live server, silent failures, specs that
cannot fail, drift between `docs/design/` and code, and anything personal or secret in a public repo.

**Scope read.** Every file under `src/` except the unchanged pure Weapon and Boar submodules;
`tests/TestKit.luau`, `tests/client/Role.luau`, `tests/client/InputReady.luau`,
`tests/client/zz_tie_to_a_tree.spec.luau`, `tests/server/zz_drive_boundary.spec.luau`,
`tests/server/map_contract.spec.luau`; `tools/studio_mcp.py` (`run_test`, `still_loading`, the token
path) and `tools/mapgen.py` in full; `docs/design/map-generator.md` by section; `GAME_DESIGN.md`
owners table in full; `CLAUDE.md`, `docs/PROJECT_CONTEXT.md`, `TASKS.md` rows 1–44a;
`reviews/task-41/RESULT.md`, `reviews/task-43/RESULT.md`, `reviews/task-44/{REQUEST,RESULT}.md`;
`docs/architecture/audit-003.md`; `.gitignore`, `default.project.json`, `.github/workflows/ci.yml`.

**Not re-raised.** audit-003's must-fix 1 and 2 are both done and verified here: `Match.CONFIG` carries
`MIN_PLAYERS = 1` with `ODD_PLAYER_TEAM = "Shooters"` (`src/server/Match/init.luau`, `Match.CONFIG`),
and `src/client/Camera/Rig.luau`'s foreign-write detector compares the whole `CFrame` per
`GAME_DESIGN.md`'s Camera row. Everything already carried in `TASKS.md` rows 6a, 21a, 23a, 24a, 26a,
28a, 30a, 32a, 34a, 35b, 36a, 38a, 41a, 43a and 44a is referenced by number where a finding touches it,
never restated as new. Where a queued item is now realised rather than hypothetical, that is said.

**State of the tree.** Lint, format and build are clean (`.agent-evidence/lint-selene.txt`,
`lint-stylua.txt`, `rojo-build.txt`, all exit 0). Every review in the stack passed: Task 35 round 1,
Task 36 round 3, Task 38 round 2, Task 41 round 1, Task 43 round 3, Task 44 round 1.

**Rule 3 holds, mechanically, everywhere I could check it.** A grep across `src/` for each owned
resource returns exactly one writing module:

| Resource | Only writer found |
|---|---|
| `workspace.CurrentCamera` | `src/client/Camera/Rig.luau` (`Rig.apply`, `Rig.acquire`, `Rig.release`) |
| `UserInputService.MouseBehavior` / `.MouseIconEnabled` | `src/client/Camera/Cursor.luau` (`Cursor.apply`, `Cursor.stop`) |
| `ScreenGui` / `Frame` / `TextLabel` | `src/client/Hud/init.luau` (`build`, `arm`, `renderScore`, `renderTied`) |
| `Player.Team`, `Humanoid.WalkSpeed`, `Workspace.DriveMarkers` | `src/server/Match/Body.luau` (`Body.setTeam`, `Body.tieCharacter`, `Body.driveMarkers`) |
| `Tool` instances | `src/server/Weapon/Hardware.luau` (`Instance.new("Tool")`, `tool:Destroy()`) |
| `Workspace.Terrain` | `src/serverstorage/MapGen/Ground.luau` (`Ground.writeTile`, `Ground.paintTrack`, `Ground.clear`) |
| `CollectionService:AddTag` | `src/server/TestArena.luau` (`buildDriveMarkers`) and `src/serverstorage/MapGen/Markers.luau` (`Markers.place`, `Markers.tagTieTrees`) — one per world, and `tests/server/map_contract.spec.luau` asserts only one world exists |
| the five tag strings | `src/shared/Map/init.luau` (`Map.TAGS`), read by all three |

The two test-only seams are correctly gated. `Match.advanceForTests`
(`src/server/Match/init.luau`, `testGateOpen`) requires `RunService:IsStudio()` **and**
`ReplicatedStorage.TestKit` to exist **and** `TestKit.activeToken() ~= nil`, reached through
`FindFirstChild` plus `pcall` so the publish strip cannot break the owner; `TestKit.activeToken` is set
only by `TestKit.run`, which a playtest never reaches because nothing writes it a token. A published
place fails at the first clause. `Weapon.mayArmForTests` (`src/server/Weapon/init.luau`) is read-only.
Client state is level-triggered throughout: `src/client/Match/init.luau` replaces the whole snapshot on
every `MatchState` push and the Hud re-derives the bar, the panel and the banner from it in one pass
(`renderDrive`), so the three cannot disagree about the phase.

Nothing in the repo is personal or secret. A grep over all tracked files for emails, `.ROBLOSECURITY`,
API keys, credential paths and `C:\Users\...` returns only `CLAUDE.md`'s and `.gitignore`'s own
prohibitions, `tools/studio_mcp.py`'s `%LOCALAPPDATA%` expansion, and one placeholder
`C:\Users\<user>\...` in `docs/research/2026-09-24-map-generator.md`. `.agent-evidence/` is untracked
and lives only inside the throwaway worktree (`tools/agents.py`, `Worktree.__exit__` removes it), so
its local temp path cannot reach a commit.

So the findings below are not about overlapping owners. The first is about the one resource this stack
added that **no check of any kind can see**, and the second is about the loop losing a whole audit's
queue.

---

## Must fix now

### 1. Terrain is the largest thing the new system writes and nothing — spec, harness, tool or runtime — ever looks at it

**Blocks: M2.3 (the real tree and hedge ids), M2.5 (the switch), and Karen's two-player playtest**,
because all three build a map into the DEV place, look at it, clear it, and then take a harness run or
a playtest as evidence about the *arena*.

**Evidence.**

`src/serverstorage/MapGen/Ground.luau`, `Ground.writeTile` and `Ground.paintTrack`, write 6.3 M voxels
into `Workspace.Terrain` (`reviews/task-44/REQUEST.md`, "268 steps, 1,238 parts, 6.3 M voxels"). That
terrain is a **global singleton with no container**: it is not under `Workspace.DrivenHuntMap`, so
destroying the map root does not touch it.

The one check that answers "which world is this" is
`tests/server/map_contract.spec.luau`, `it("names exactly one world, and that world is the one that
exists")`. In full, its guard against the generated world being left behind is:

```
local other = if namedRootName() == ARENA_ROOT then MAP_ROOT else ARENA_ROOT
expect(Workspace:FindFirstChild(other)).to.equal(nil)
```

A folder name. The design's own check list is the same: `docs/design/map-generator.md` §12.1 check 1 is
"exactly one of `Workspace.TestArena` / `Workspace.DrivenHuntMap` exists — the one it names", and no
check in §12.1 mentions Terrain at all. The code implements the design faithfully; the hole is in both.

The other two places that could have caught it do not:

- `src/serverstorage/MapGen/init.luau`, `MapGen.clear`, returns
  `{ removed = removed, terrainCleared = true }`. `terrainCleared` is a **hard-coded literal**. It
  never reads a voxel back. The one report in the system that says "the terrain is gone" is a claim
  with no measurement behind it — `docs/PROJECT_CONTEXT.md`'s "the agent verified its own work with
  numbers and never looked", in one word.
- `tools/mapgen.py`, `WORKSPACE_ALLOWED = ("Terrain", "Camera")`, and the census refusal built on it.
  `--backup census` exists to prove "nothing here would be lost by a rebuild" (module docstring, "it
  stops and prints a NEEDS KAREN block … because that thing is something a rebuild would destroy").
  Terrain is unconditionally on the allow-list, so the census is structurally incapable of mentioning
  the single biggest thing `clear` destroys, or of noticing that a map's terrain is already there.

**The reachable path.** `reviews/task-44/REQUEST.md` states the working practice: "the map is cleared
out of Workspace before a harness run." Clearing correctly, through `mapgen.py clear` or step 1 of a
build, does clear both. But the obvious alternative — deleting `Workspace.DrivenHuntMap` in the
Explorer, which is one right-click and which Karen or the Builder will reach for between a screenshot
and a test — removes the folder and leaves the entire heightfield. So does any run where the map root
is gone and `Ground.clear()` did not complete. In that state:

- `map_contract.spec` check 1 passes (no `DrivenHuntMap`);
- check 2 passes (`GetTagged` finds only the arena's 8/1/1/4/4);
- check 5, the pathfinding check, plausibly still passes — `Boar.CONFIG.AGENT` walking rolling terrain
  is exactly what the reachability work proved is walkable;
- the harness prints `[harness] PASS: n/n checks @ <sha> (clean tree)`.

Meanwhile `Workspace.TestArena`'s plate top is at `y = 0` (`src/server/TestArena.luau`, `LAYOUT.ground.top`)
and `Config.CORRIDOR_RELIEF = 16` / `Config.RELIEF = 40`, so the arena is buried in or floating over a
2048-stud heightfield. Boars route over terrain, shots stop in hills, and the screenshot Karen looks at
is of a world nobody chose. Nothing in the run says so.

**Why it matters.** This is the false-PASS path the audit prompt names, in the newest system, in the
one state M2.3 and M2.5 will pass through dozens of times. It is also the shape
`docs/PROJECT_CONTEXT.md` names twice: "its own test harness was wrong as often as the game was", and
"a visibility audit ignored parent visibility and certified a blank screen twice". A world check that
names a folder and ignores the ground is that audit again. And it compounds at M2.5: once
`EXPECTED_WORLD` is `"map:v1"` the spec will confirm the right markers exist and still say nothing
about whether the terrain under them is the terrain the committed seed produced — `MapGen.markerDigest`
was built for exactly that comparison and still has no caller (`TASKS.md` row 43a(g)).

**Fix.** Three small pieces, all buildable now; the Builder owns two of them and the design change is
mine.

1. `tests/server/map_contract.spec.luau`, in the same `it("names exactly one world…")`: when
   `Map.EXPECTED_WORLD == "arena"`, assert the place holds no terrain. `Workspace.Terrain:CountCells()
   == 0` is the one-liner if that method is available (**I could not run it** — see *Not verified*);
   the certain form, using code this repo already has, is one `Terrain:ReadVoxels` over the arena's
   400 × 400 footprint at resolution 4 with every occupancy asserted 0, which is
   `src/serverstorage/MapGen/Ground.luau`'s `Ground.sampleRow` with the loop inverted. Make the failure
   message name `tools/mapgen.py clear` so whoever hits it knows the cure.
2. `src/serverstorage/MapGen/init.luau`, `MapGen.clear`: read back before claiming. Sample one row
   through `Ground.sampleRow` after `Ground.clear()` and return the measured occupancy instead of
   `terrainCleared = true`. A literal `true` in a report is not evidence.
3. `tools/mapgen.py`, the census path: report terrain occupancy beside the Workspace children, and
   refuse `--backup census` on a mutating command when terrain is non-empty and the map root is absent
   — that combination is precisely "somebody deleted the folder by hand", and it is the state a rebuild
   should not start from silently.

And at the next regeneration of `docs/design/map-generator.md`, §12.1 gains a terrain check as check 1b
and §9.1's rollback list says that `EXPECTED_WORLD = "arena"` is only a rollback once the terrain is
cleared too.

### 2. audit-003's fix-before-release and log-only lists were never queued anywhere, and the top item is a player-visible camera defect

**Blocks: Karen's two-player playtest** (audit-003 F1 is the item she would see), **and M2.5**
(audit-003 F2 and F3 are both in the boar world the switch rewrites).

**Evidence.** `CLAUDE.md`, the loop, step 6: "An item is must-fix only if it blocks the next game task
… fix those and go back to 4. **Everything else goes into `TASKS.md` under 'before release'**." That
happened for the two earlier audits: audit-001's items are `TASKS.md` row 8, audit-002's five are rows
12–16, each with a row of its own and a status.

audit-003's must-fix 1 and 2 were dispatched and are done (both visible in the Director dispatches at
the foot of `TASKS.md`). Its **F1–F12 and L1–L13 have no row**. A grep of `TASKS.md` for `audit-003`
returns only the two must-fix dispatches; a grep for the F-items' own subjects (`setLocalBodyHidden`,
`hiddenParts`, `pathProblems`) returns nothing in `TASKS.md`. Twenty-five findings, produced by a paid
session, exist only inside `docs/architecture/audit-003.md`.

Three of them I re-checked against this commit and they are unchanged:

- **F1**, the worst. `src/client/Camera/Rig.luau`, `Rig.setLocalBodyHidden`: `hiddenParts` is still
  rebuilt only when `hiddenFor ~= character`, and the write loop is still skipped entirely when
  `hiddenNow == hidden`. The Tool's `Handle` arrives on the client after the first render step of that
  life (`src/server/Weapon/init.luau`, `watchPlayer` → `Weapon.grant` on `CharacterAdded`), so it is
  very likely absent from the cached list and keeps `LocalTransparencyModifier = 0` while the body goes
  to 1. The function's own comment records what that looks like: "the real gun was drawn beside the
  viewmodel clone — two shotguns on screen at once." audit-003 called it "the highest-value item in
  this section … Karen-visible at the next camera playtest; it deserves a `TASKS.md` row now". It never
  got one.
- **F2.** `src/server/MatchBoot.server.luau` builds `Boar.defaultWorld()` into a local and never reads
  `world.pathProblems()`; `src/server/Boar/init.luau` still exposes it only on the world closure, with
  no `Runtime:pathProblems()`. audit-003 said "1.7a is the moment". 1.7a is Task 32, in this stack, and
  the moment passed.
- **F3.** `src/server/Boar/init.luau`, `Boar.newRuntime`, still merges `world.config` into a clone the
  world's own `threats` and `requestPath` closures do not read; `MatchBoot` still routes around it with
  `world.threats = Match.driverThreats`.

**Why it matters.** Rule 8 is "report honestly what you could not verify", and the loop's step 6 is how
a finding survives the round it was found in. A queue that silently evaporates is worse than no audit:
it produces the *appearance* of coverage while the findings decay, and it is why I am re-raising three
items rather than trusting they are in hand. The immediate cost is concrete — Karen is about to play
this stack with two players, and the one known defect that will be in front of her eyes is on no list.

**Fix.** Paperwork, and it is explicitly allowed after a code commit (`CLAUDE.md` git workflow step 4
admits "the task's status row in `TASKS.md`" and the Builder's right to file non-must-fix audit items
under the task). One `TASKS.md` row per audit, in the shape rows 12–16 already have: a row for
audit-003 F1–F12 and L1–L13, and a row for this audit's own lists below, each classified with Task 38's
letters (G / T / D / L). audit-003 F1 is a **G** and should be lifted out into its own row with a
screenshot named, because it is the only one that costs a playtest.

---

## Fix before release

**F1. `zz_drive_boundary.spec` can leave the live server holding a throwing arming policy.**
`tests/server/zz_drive_boundary.spec.luau`, `it("falls back to the weapon's own rule when the drive's
policy errors (32a(d))")`, installs `Weapon.setArmingPolicy(function() error(...) end)` and restores
`Match.mayCarryWeapon` in the last four lines of the same `it`. TestEZ abandons an `it` at the first
failed `expect`, and there are four `expect`s between the two — including
`expect(pcall(Weapon.refreshArming, player)).to.equal(true)`, which is the falsifying case the test
exists for. If that one ever fires, the production `Weapon` owner keeps a policy that throws for the
rest of the Play session; every later `refreshArming` falls through the pcall to
`Shotgun.CONFIG.shouldArm` and arms everybody, and the three specs after it in the same file assert gun
state and tie state. One genuine failure becomes four, in the two-player run the merge gate now depends
on (`CLAUDE.md` git workflow step 4). Fix: install and restore around a `pcall`, or install in a
`beforeAll` and restore in an `afterAll`, and assert after the restore has happened.

**F2. A test in the new map spec cannot fail, and it is the one Task 44's own review round 1 already
caught the twin of.** `tests/server/map_contract.spec.luau`, `it("expects one tagged instance per
planned marker, plus the tie trees")`, ends with `expect(total).to.equal(planned + c.WORLD.tieTrees)`.
`total` is the sum over `MapGen.expectedCounts()`, which is built as `{ tree = Config.WORLD.tieTrees }`
plus one per entry of `Layout.markers(config)`; `planned` is `#Layout.markers(config)`. No marker has
kind `"tree"`, so the two sides are the same arithmetic on the same data for **any** layout, right or
wrong. Its neighbour carries the comment that names this exact defect — "Against the CONFIGURATION, not
against `MapGen.expectedCounts()`: that function is the same loop over the same data, so comparing the
two could not fail for any layout, right or wrong (review round 1, finding 2)" — and this one was not
converted. The `it` is not worthless: `expect(Map.TAGS[kind]).to.be.a("string")` inside the loop is
real and is what the comment claims ("a sixth kind added to Layout without a tag would break this").
Drop the total assertion, or compare the total against the configuration (`postCount + #boarSpawnX + 2
+ tieTrees`) the way the neighbouring test does.

**F3. `MapGen.digest()` reports the wrong seed, in the record the M2.5 switch will be built from.**
`src/serverstorage/MapGen/init.luau`, `MapGen.digest`, returns `seed = Map.SEED`. `Map.SEED` is `0`
while `EXPECTED_WORLD` is `"arena"` (`src/shared/Map/init.luau`, and the comment says so), but the map
is built from the `--seed` argument (`tools/mapgen.py`, `command_build`, `MapGen.runStep(index, seed)`).
So `python tools/mapgen.py digest` prints `"seed": 0` for a map built from seed 7, and only
`mapgen.py`'s own printed line carries the real seed — from the CLI, not from the map. Step 6 of the
M2.5 sequence (`docs/design/map-generator.md` §9.3) is "sets `Map.SEED` and `Map.DIGEST`", and it will
be copied from this output. Return the seed the geometry was actually built from, or drop the field;
a number that is wrong is worse than one that is absent.

**F4. `MapGen.Settings` still runs as the last step of every build, and it is the one step that changes
a place setting for every existing system.** `src/serverstorage/MapGen/init.luau`, the `settings`
branch, calls `Settings.apply(Map.STREAMING)`, and `src/serverstorage/MapGen/Settings.luau`,
`Settings.apply`, writes `Workspace.StreamingEnabled` whenever it differs from the contract. It is
inert today only because `Map.STREAMING.enabled = true` happens to match the place. This is `TASKS.md`
row 43a(f), raised there and unchanged: `docs/design/map-generator.md` §14's build-order table puts
`Settings` in **M2.6, alone**, because the change needs a playtest. Until then, make the coincidence
into a guard: `Settings.apply` should refuse to write and report "M2.6 has not run" rather than write
silently, so a one-character edit to the contract cannot make M2.6's change during an M2.3 build.

**F5. `TestKit.activeToken` is never cleared, so the drive's clock seam stays open after the run that
opened it.** `tests/TestKit.luau`: `activeToken` is set at the top of `TestKit.run` and nothing ever
sets it back to `nil`. Once the server suite finishes, `Match.advanceForTests`
(`src/server/Match/init.luau`, `testGateOpen`) still answers `true` for the remainder of that Studio
Play session. Nothing exploits it today — only a gated harness session ever gets there — but the seam's
whole safety argument, written in its own header, is "is a gated test run in progress", and after
`TestKit.run` returns no run is in progress. One line in `TestKit.run`'s `finish` closes the gap, and
it is safe: `finish` runs after `TestBootstrap:run` returns, so `zz_drive_boundary.spec`'s
`clientsFinished()` — the one other reader of `activeToken()` — has already done its work.

**F6. The UI owner now reads two config tables and its owner row names neither.** audit-003's F5 asked
for this decision "before the Hud reads three configs and no row says which"; 1.7a and 1.7b landed and
it now reads two. `src/client/Hud/init.luau` takes `CROSSHAIR_*`, `HIT_MARK_*` and `HUD_TEXT_SIZE` from
`Shotgun.CONFIG` and `FEED_SECONDS`, `FEED_LINES`, `TEXT_COLOR`, `DRIVER_COLOR`, `SHOOTER_COLOR`,
`SCORE_HIGHLIGHT_COLOR`, `TIED_TEXT` and `SCOREBOARD_ENABLED` from `Drive.CONFIG`. `GAME_DESIGN.md`'s
`PlayerScripts.Hud` row still names no config location, while the `ReplicatedStorage.Shotgun` row calls
its table "every ballistic, timing, layout and rate number" **of the weapon**. Either say in the Hud's
owner row that its numbers live in the two wire contracts it draws from (which is defensible — each
number travels with the system it describes), or give the Hud its own table. Say one of them.

**F7. Three audit-003 items in the boar are still open at the moment the map switch will rewrite the
boar's world.** F2 (no `Runtime:pathProblems()` accessor: a live server can fall back to straight-line
flight for ever with the reasons locked in a closure nobody holds), F3 (`world.config` is a
half-working override the composition root routes around), F4 (`Boar.CONFIG` is the only "one config
table" in the repo that nothing freezes, while `Shotgun.CONFIG` and `Camera.Config` are both frozen and
asserted). All three are in `src/server/Boar/init.luau`, all three are unchanged at this commit, and
M2.5 changes `Boar.CONFIG.field` (`docs/design/map-generator.md` §9.3 step 6) — the task that opens
that file is the task to close them in. Details in `docs/architecture/audit-003.md`; recorded here only
so they reach a `TASKS.md` row with must-fix 2.

**F8. audit-003 F6's dead config numbers are still dead, and one of them changed value without gaining
a reader.** `src/client/Camera/Config.luau`, `CURSOR_LOCKED_DEFAULT`, now reads `true` where audit-003
recorded `false`; `src/client/Camera/Cursor.luau`, `Cursor.apply`, still hard-codes
`Enum.MouseBehavior.LockCenter` and consults neither it nor `FREE_CURSOR_ON_DEATH`.
`Shotgun.CONFIG.SLUG_CAST_RADIUS` and `Shotgun.CONFIG.CAMERA_DRIFT_TOLERANCE`
(`src/shared/Shotgun/init.luau`) still appear in no `.luau` file but their own. A number whose value can
be edited with no effect is a claim about behaviour that is not there. Wire each or archive it (rule 7).

**F9. The stand point and the tie anchor both assume a solid post, and the generated map's posts are
neither solid nor visible.** `src/server/Match/Body.luau`, `Body.placementFor`, puts a shooter at
`post.Position + post.Size.Y / 2 + STAND_HEIGHT_STUDS`; `src/serverstorage/MapGen/Markers.luau`,
`Markers.place`, builds every marker `CanCollide = false`, `CanQuery = false`, `Transparency = 1`. On
the arena the posts are solid (`src/server/TestArena.luau`, `makePart`, which sets no `CanCollide` and
so gets the default `true`); on the map they are metadata, so a shooter is placed 9.5 studs above the
ground with nothing under him. That is `TASKS.md` row 43a(l), queued for M2.5. **New, same shape:**
`Body.anchorFor` falls back to `markers.posts` when `#markers.trees == 0`, so a map whose `stand` step
failed would tie a punished player to an invisible, non-collidable marker in mid-air — the fallback is
written for the arena, where posts are real. Decide at M2.5 whether `placementFor` should drop to the
ground beneath the post, and whether `anchorFor`'s fallback should simply return `nil` (which the
function already treats as "do not tie") rather than aim at metadata.

**F10. `Height.atFlattened`'s `bogDepth` argument is optional, and the spec that checks the pads omits
it while production passes it.** `src/serverstorage/MapGen/Height.luau`, `Height.atFlattened`, takes
`bogDepth` as a `?` parameter and silently returns terrain without the bog when it is absent — which is
deliberate and documented ("a caller that omits it gets the terrain without the bog, which is exactly
what the corridor and slope checks want to measure"). But `tests/server/map_contract.spec.luau`,
`it("flattens every spawn pad to exactly the ground the contract asserts")`, calls
`MapGen.Height.atFlattened(pad.x, pad.z, SEED, c, pads)` with five arguments, while `Ground.writeTile`,
`Markers.place`, `Props.hedge`, `Props.trees` and `Props.tieTrees` all pass six. The spec therefore
measures a function the world never calls. Harmless today — the bog is at `(-700, -300)` and every pad
is inside the corridor — and it becomes wrong the moment a pad and a bog share a place. Make the
optional argument explicit at the call site in the spec, or split the two functions so a caller cannot
forget.

**F11. Karen's two feel calls and the asset-pivot fault are the gate on M2.3, and none of them is an
Architect item.** `TASKS.md` rows 43a(a), 43a(b), 44a(b), 44a(c) and 44a(d): the props read as green
lollipops and dark banks because `Assets.ROWS` is empty by design (§8.3), and
`src/serverstorage/MapGen/Props.luau`, `placed`, pivots a model to the **ground** point while the proxy
branch sits it at half its own height — so the first real mesh whose pivot is its centre lands
half-buried. Row 43a(d) already says the right thing ("fix it with the first real id, against a real
mesh, not by guessing now"). Recorded here so M2.3's dispatch treats it as the first thing that task
does, not as a note it discovers.

---

## Log only

- **L1.** `GAME_DESIGN.md`'s arena row says "Since Task 22 the arena is the only thing this repo puts in
  Workspace at all" and then names three run-time folders; with this stack it is four containers plus
  `Workspace.Terrain` (`Workspace.Boars`, `Workspace.WeaponEffects`, `Workspace.DriveMarkers`,
  `Workspace.DrivenHuntMap`). Already `TASKS.md` rows 24a(d) and 38a(f); noted only because the stack
  added the fourth. Every one of them does have an owner row.
- **L2.** `docs/architecture/audit-003.md` quotes a warning string `Camera.start` no longer prints
  (`TASKS.md` row 38a(g), which says "it waits for the next audit"). Confirmed: `Rig.acquire`'s reason
  was corrected in Task 38 and audit-003's F-section text is now stale on that one sentence. Audits are
  a record of a commit and are not edited; this is the correction.
- **L3.** `src/serverstorage/MapGen/Layout.luau`, `Layout.hedgeSegments`: `count = math.floor((to -
  from) / segmentStuds)` gives 85 for a 2048-stud line at 24 studs, and the loop runs `0..85`, so the
  last segment centre is at `+1016` and the final 8 studs of every line are open. Cosmetic, at the map
  edge, outside every corridor span, so `Layout.widestGap` never sees it.
- **L4.** `src/serverstorage/MapGen/Contract.luau` requires `module:Clone()` at edit time and never
  parents or destroys it, and `tools/mapgen.py`'s `CALL` requires a fresh clone of `ServerStorage.MapGen`
  on **every** MCP call — so a 268-step build leaves ~268 orphan `Map` ModuleScripts held by Studio's
  require cache for the length of the session. Parentless, so the harness's unmanaged-script scan
  cannot see them, which is what the `mapgen.py` comment intends; memory only, and gone at the next
  place open. Recorded because "requires a clone per call" reads as free and is not quite.
- **L5.** `src/serverstorage/MapGen/init.luau`, `MapGen.reachability`, requires
  `ServerScriptService.Boar` through the *session's* cache (not through a clone, as everything else in
  the generator does), so a `Boar.CONFIG.AGENT` edited since the session opened would be invisible to
  the one check that walks the map. It reads four numbers and they change rarely; the asymmetry is
  worth one sentence at the call site.
- **L6.** `tools/mapgen.py`'s `command_verify` docstring says "Build, digest, clear, build again,
  compare" and the loop contains no clear — the clear is step 1 of the plan it runs twice
  (`MapGen.steps`, `add("clear", ...)`). The behaviour is right; the sentence describes a structure the
  function does not have.
- **L7.** The only runtime guard against two worlds coexisting is the drive bar. `ArenaBoot`
  (`src/server/ArenaBoot.server.luau`) builds the arena unconditionally and does not read
  `Map.EXPECTED_WORLD` — deliberate, and `docs/design/map-generator.md` §9.2 shows the early return
  arriving at M2.5. Until then, a saved generated map means `Match.Markers.read` finds two drive lines,
  reports `complete = false`, and the Hud prints `WAITING DrivenHunt.DriveLine (2 found, want 1)`
  (`src/server/Match/Markers.luau`, `Markers.read`; `src/client/Hud/init.luau`, `renderDrive`). That is
  a good failure — loud, and it names the tag. It is also the exact contrast that makes must-fix 1
  sharp: the parts half of that state announces itself on screen and the terrain half does not.
- **L8.** `src/client/Match/init.luau`, `Match.stop`, has no caller, so its connections live for the
  session. Same class as `Input.stop` (`TASKS.md` rows 24a(c), 38a(b)); one client, one session, no
  growth per respawn.
- **L9.** `tests/client/InputReady.luau`'s header records that TestEZ's module order is load-bearing in
  two directions (`camera_client` before `weapon_client`; `zz_tie_to_a_tree` last) and that nothing
  pins it but the file names. Confirmed still true, and now with a third dependant:
  `tests/server/zz_drive_boundary.spec.luau` must be the last server spec for the same reason. The
  `zz_` convention is doing real work in two suites with no mechanism behind it.
- **L10.** `src/serverstorage/MapGen/` ships in the published place: `ServerStorage` is fully Rojo-owned
  (`default.project.json`) and the strip list (`TASKS.md` row 2) names TestRunner, ClientTestRunner,
  TestKit, Tests, ClientTests, DevPackages, TestSyncToken and SyncCheck — not MapGen. It is inert
  (nothing requires it at run time; `Contract.luau`'s edit-time branch is `RunService:IsStudio() and not
  RunService:IsRunning()`, false on a live server) and server-only, so it is dead weight rather than a
  risk. Add it to row 2's list.
- **L11.** `.agent-evidence/` is not in `.gitignore`. It cannot reach a commit today — `tools/agents.py`
  writes it only inside the throwaway worktree and removes the worktree with `--force` — and
  `CLAUDE.md` git workflow step 2 forbids the blind `git add -A` that would be needed. One line in
  `.gitignore` would make it structural rather than procedural, which is the standing preference.
- **L12.** CI (`.github/workflows/ci.yml`) lints Luau and builds the place; it runs nothing at all
  against `tools/*.py`, which is now 1,900 lines of `studio_mcp.py` plus `mapgen.py` and `agents.py`.
  Tooling is frozen (`ROADMAP.md` speed rule 1); logged so the gap is on the record and not rediscovered.
- **L13.** `src/serverstorage/MapGen/Config.luau`, `Config.WORLD`'s comment, and
  `Config.CORRIDOR_MAX_SLOPE_DEG`'s ("the spec measures it", which no spec does): both are `TASKS.md`
  rows 44a(i) and 44a(g). Re-checked, both still true at this commit. Rule 9 makes comments
  load-bearing, and a comment that names a test which does not exist is the same false assurance as a
  test that cannot fail.

---

## Not verified

- **Anything requiring Roblox Studio.** No Studio in this session (`.agent-evidence/INDEX.md`). Every
  claim about what the harness or the generator *would* do is read from `tools/studio_mcp.py` and
  `tools/mapgen.py`; every claim about what is on screen is read from code and from the Builder's own
  inspected-screenshot notes in `TASKS.md` rows 43, 44 and 44a(b).
- **Must-fix 1's reachable path is reasoning, not an observation.** That nothing checks Terrain is
  certain from the source of `map_contract.spec`, `MapGen.clear` and `mapgen.py`. That a run has ever
  actually happened with the map root gone and the heightfield present is **not** established — I have
  no run log (`.mapgen/` is git-ignored) and no Studio. The finding is about the absent check, not
  about a state I saw. `TASKS.md` row 43a(j) records an unexplained `FAIL: 25/27` seconds after a
  `mapgen.py clear`, diagnosed in Task 44 as the navmesh race; that diagnosis is itself called an
  inference in `reviews/task-44/REQUEST.md` ("Row 43a(j)'s diagnosis is an inference, not a
  measurement"), so it is not evidence either way for this.
- **`Terrain:CountCells()`.** I named it as the one-line form of must-fix 1's assertion from memory of
  the Roblox API and could not check it against a live engine or the docs (no network). The
  `Terrain:ReadVoxels` form given beside it uses only calls this repo already makes in
  `Ground.sampleRow`, so the fix does not depend on `CountCells` existing.
- **Anything needing git.** No log, no diff, no `paperwork-after-code-commit.txt` in this run's evidence
  (`INDEX.md` lists six files). I could not check the merge gate's fourth condition — that only
  paperwork lies between `805e0e0` and the PR head — nor `git diff origin/main...HEAD`, so "the stack
  as it will land" is reconstructed from `TASKS.md` rows 35–44a and the four `reviews/task-*/REQUEST.md`
  files rather than from a diff. `reviews/task-44/RESULT.md`'s last note and rows 36a(3)(f), 38a(h) and
  44a(k) all record that the `Code commit:` label names a paperwork-only commit; I could not verify the
  trees are identical, only that four independent readers say so.
- **CI status for this commit.** No CI output in `.agent-evidence/`.
- **The harness's own numbers.** Not run. `27/27` and `30/30` at `805e0e0`, and the 301/70/64 spec
  counts, are quoted from `reviews/task-44/REQUEST.md` and were not recounted against `run_test`.
- **DevPackages / TestEZ integrity.** `DevPackages/` is absent from the worktree, so
  `devpackages.sha256` could not be exercised and TestEZ's behaviour was read only through
  `tests/TestKit.luau`. In particular, "TestEZ runs the spec modules in the order the specs folder
  lists them" — which two suites now depend on (L9) — is the Builder's measurement, not mine.
- **Every external URL** cited in `docs/design/map-generator.md` §11 and in the new module headers, and
  the licence and maintenance status of RTerrainGenerator. No network. audit-003's L9 (a fabricated
  DevForum URL reached a merged commit) makes this worth restating rather than assuming.
- **Measurement B** — whether `CollectionService` tags survive a save and a reopen — is still open from
  Task 43 and is a click only Karen can make. Every tag-based claim in this audit, including must-fix
  1's, assumes they do.
