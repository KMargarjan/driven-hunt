# Architecture audit 005

Commit `755161e70bb6a48f6da985fc5b15ca8b27f10dbd`, branch `task-65-audit` (`.agent-evidence/head.txt`).
Read-only session: Read, Grep, Glob. No Studio, no network, no git. Evidence precomputed in
`.agent-evidence/` (`INDEX.md`, six files).

**Brief.** `reviews/task-65/BRIEF.md` (Director): audit `main` after Tasks 49–63 — privacy CI, fast
`test2`, feature flags, the Meshy tool and the ASSET role, map M2.8a/b, sounders behind
`BOAR_SOUNDERS`, the boar path-start fix. Previous audit `docs/architecture/audit-004.md`. Speed rule
2: must-fix only if it blocks the next tasks (Task 64 Meshy refine fix, the boar model swap, map
M2.8c–e and the map switch, Karen's next playtest) — and this audit names which. Focus: second
writers (Flags override vs defaults, Weapon Tools, Match, MapGen vs TestArena markers, Boar runtime vs
sounder state), flags that could leak into a live server, dead paths behind flags, specs that cannot
fail, drift between `docs/design/` and code, anything personal or secret in the public repo.

**Scope read.** `src/shared/Flags/init.luau`, `src/server/FlagsBoot.server.luau`,
`src/server/Match/init.luau`, `src/server/Match/Phase.luau` (the sounder and flag boundaries),
`src/server/Match/Markers.luau`, `src/server/Match/Body.luau` (`placementFor`, `anchorFor`,
`tiePointFor`, `tie`), `src/server/Boar/init.luau` and `src/server/Boar/Body.luau` in full,
`src/shared/Map/init.luau`, `src/serverstorage/MapGen/init.luau`, `Props.luau` and `Assets.luau` in
full, `Config.luau` by section; `tests/server/flags.spec.luau` in full, `tests/server/boar_body.spec.luau`
(the path and sounder blocks), `tests/server/map_contract.spec.luau` (the world and species blocks);
`docs/design/map-generator.md` §12, §17, §18 and `docs/design/asset-pipeline.md` §2.1, §5, §12.1 by
section; `GAME_DESIGN.md` owners table in full; `CLAUDE.md`, `docs/PROJECT_CONTEXT.md`,
`docs/research/INDEX.md`, `docs/design/README.md`; `TASKS.md` rows 1–63a; `tools/studio_mcp.py` and
`tools/privacy_scan.py` by grep only (`flag_overrides`, `run_test`, `run_test2`, the `DHFlag_` path);
`docs/architecture/audit-004.md`.

**Not re-raised.** audit-004's must-fix 1 (the terrain nothing looked at) and must-fix 2 (the queue
that evaporated) are both done and verified here: `MapGen.clear` returns a measured `cellsAfter` and
`MapGen.runStep`'s `clear` branch **fails the build** when cells remain;
`tests/server/map_contract.spec.luau` `it("holds the terrain the named world requires, and no other")`
asserts `Workspace.Terrain:CountCells() == 0` in the arena branch and `> 0` in the map branch, and
`MapGen.clear` restores and re-reads the palette; audit-003's F/L lists and audit-004's F list are
`TASKS.md` rows 47b and 47c. Everything already carried in rows 6a, 21a, 23a, 24a, 26a, 28a, 38a, 41a,
43a, 44a, 45a, 47a–c, 48a, 49a, 52a, 55a, 58a, 59a, 60a, 61a, 61b, 62a and 63a is referenced by number
where a finding touches it and never restated as new.

**State of the tree.** Lint, format and build are clean (`.agent-evidence/lint-selene.txt`,
`lint-stylua.txt`, `rojo-build.txt`, all exit 0).

**Nothing in the repo is personal or secret.** A grep of every tracked file for `C:\Users`, `/home/`
and any email address returns only `CLAUDE.md`'s own prohibition, `tools/privacy_scan.py`'s own rule
text and comments, and `reviews/task-49/REQUEST.md`'s description of the rules. Task 49's scrub holds
and CI enforces it. `.agent-evidence/` is git-ignored now (closing audit-004 L11 and row 49a(b)).

**Rule 3 holds everywhere the brief asked about, with one exception that is the subject of must-fix 1.**

| Resource | Only writer found |
|---|---|
| `Flags.DEFAULTS` | nobody at run time (`src/shared/Flags/init.luau`, `Shotgun.deepFreeze(Flags.DEFAULTS)`) |
| `ReplicatedStorage.Flags.State` attributes | `src/server/FlagsBoot.server.luau`, the only caller of `Flags.publish` |
| `ServerStorage` `DHFlag_*` | `tools/studio_mcp.py` (`flag_overrides` and the `flags set`/`clear` path) |
| sounder existence, membership, leader, scatter | `src/server/Boar/init.luau` — `Runtime:spawnSounder`, `_stepSounders`, `_chooseLeader`, `_leaveSounder`; membership is **rebuilt from `self._boars` every step**, never edited in two places |
| `Tool` instances | `src/server/Weapon/Hardware.luau` |
| `Player.Team`, character position, `Workspace.DriveMarkers` | `src/server/Match/Body.luau` |
| `Workspace.Terrain` and the material palette | `src/serverstorage/MapGen/Ground.luau` |
| `CollectionService:AddTag` | `src/server/TestArena.luau` and `src/serverstorage/MapGen/Markers.luau`, one per world, with `map_contract.spec` asserting only one world exists **and** that its terrain matches |
| `InsertService:LoadAsset` | `src/serverstorage/MapGen/Props.luau`, `Props.template` — **and this one has no owner row** (must-fix 1) |

**The flag cannot leak into a live server, and I checked all three guards.** `Flags.readOverrides`
takes `isStudio` as a **parameter** and returns `{}` when it is false; the one production caller is
`resolveOnServer`, which passes `RunService:IsStudio()`. `Flags.resolve` never coerces and never
creates a key for an undeclared name. `Match.CONFIG.SOUNDER.ENABLED = Flags.isOn("BOAR_SOUNDERS")` and
`Match.CONFIG.TIE_UNTIL_DRIVE_END = Flags.isOn("TIE_UNTIL_DRIVE_END")` are the only two reads in
`src/`, both at the owner's boundary, both passed inward as `config` — and both behaviours are
reachable by parameter (`Phase.sounderSize`/`Phase.releaseGap` take `config.SOUNDER.ENABLED`;
`Penalty.expired` takes `config`), so `tests/server/flags.spec.luau` asserts both states while the
flags sit at one of them. `run_test` and `run_test2` both refuse while any override is set
(`flag_overrides` in `tools/studio_mcp.py`), and `flags.spec` re-checks it from inside the run. With
`BOAR_SOUNDERS` off, `Runtime:spawnSounder(center, 1)` creates **no** sounder record, so `obs.sounder`
is nil and the whole group path is unreached rather than half-run. That is the right shape.

So the findings below are not about overlapping owners in the systems that were built. They are about
the one seam the **next** system needs and does not have, and about a measurement nobody takes of the
thing the map is made of.

---

## Must fix now

### 1. The boar model swap has no owner row, and the repo already contains the seam it needs, in the wrong module

**Blocks: the boar model swap** (the Director's named next task, and the reason Task 64 exists at all).

**Evidence.**

`GAME_DESIGN.md`'s *System owners* table states its own gate in the sentence above it: *"A system not
listed here has no owner yet, and nobody may write to it until it has one."* The table has rows for
**Generated asset runs** (`tools/meshy.py`) and **Asset briefs** (`docs/asset-briefs/`). It has **no
row** for:

- the asset **manifest** — which id, which licence, which version — which exists today as
  `src/serverstorage/MapGen/Assets.luau` (`Assets.ROWS`, `Assets.byKey`, `Assets.KEY`);
- the **id→Instance seam** — the one place an asset id becomes an Instance;
- the **boar's visible model**.

`docs/design/asset-pipeline.md` §2.1 already names all three, and names them somewhere else:
`ServerStorage.Assets.Loader` (`src/serverstorage/Assets/Loader.luau`) is *"the only caller of
`InsertService:LoadAsset` and of `AssetService:CreateMeshPartAsync` in the repo"*, `MapGen.Props` is
*"unchanged — but it asks `Assets.Loader` for the template instead of inserting one itself"*, and the
boar's model is *"unchanged: `ServerScriptService.Boar` → `Boar.Body`. It clones the Loader's
template"*.

Neither `src/serverstorage/Assets/` nor `Loader.luau` exists (`.agent-evidence/ls-files.txt`). A grep
of `src/` for `InsertService` and `CreateMeshPartAsync` returns exactly one hit:
`src/serverstorage/MapGen/Props.luau`, `Props.template`. And `src/server/Boar/Body.luau`,
`Body.create`, builds a plain `Part` with no template seam of any kind.

**Why it matters.** The swap arrives at a fork with no written answer, and both branches are wrong in
the way `docs/PROJECT_CONTEXT.md` names first:

- `Boar.Body` inserts the mesh itself → **two id→Instance seams** in the repo, one in the boar and one
  in `MapGen.Props`, each with its own cache, its own script refusal and its own licence gate. That is
  "overlapping owners" before the second consumer exists.
- `Assets.Loader` is built for the boar and `MapGen.Props` keeps `Props.template` → the same two seams,
  with the design's own migration (§15 D1, M2.7d) left half-done and nothing recording that it is.

Either way the Builder writes a system that `GAME_DESIGN.md` says nobody may write to yet, and the
Reviewer has no row to check it against. The cost is not hypothetical: `Props.template` already
implements the script refusal, the per-run cache and the container-first-child unwrap, and a second
copy of those three decisions is three chances to disagree.

**Fix**, and it is small because the Architect's half is already written:

1. Paste `docs/design/asset-pipeline.md` §2.1's three rows into `GAME_DESIGN.md`'s owners table before
   the swap commit — the manifest, the id→Instance seam, the boar's visible model — with the
   **location as it will actually be**, not as the design assumed.
2. The Director decides, in one line, which of the two shapes the swap takes: build
   `ServerStorage.Assets.Loader` now and move `Props.template` onto it in the same task, or let
   `Boar.Body` use `MapGen.Assets`/`Props.template` as the temporary single seam and record the
   migration as one row. **What is not allowed is two inserters**, and today nothing written says so
   outside a design the swap is not being built to.
3. `docs/design/map-generator.md` §12.2 already carries the rule that makes this checkable — *"`MapGen.Assets`
   is the only copy… No task may add a second id table anywhere in the meantime"* — and it belongs in
   the owner row, where the Reviewer reads it.

### 2. The wood is four species behind one asset key, and no spec looks at what was actually planted

**Blocks: M2.8c** (it adds seven more prop kinds through this same seam) **and M2.3 / M2.7d** (the
first real tree id).

**Evidence.**

`src/serverstorage/MapGen/Config.luau`, `Config.SPECIES`, declares four species with different trunks,
crowns, heights and colours: spruce (3×30 trunk, height 71), birch (2.5×34, 64), oak (5×28, 64), alder
(3×26, 57). `src/serverstorage/MapGen/Scatter.luau`'s `speciesAt` picks between them per tree, and Task
63 measured the built mix at 39.6 / 28.2 / 20.5 / 11.7 per cent.

`src/serverstorage/MapGen/Assets.luau`, `Assets.KEY`, has **two** entries: `treeSpruce` and `hedge`.
`docs/design/map-generator.md` §12.1 specifies **six** — `treeSpruce`, `treeBirch`, `treeOak`,
`treeAlder`, `hedge`, `brush` — and says so in a code block.

`src/serverstorage/MapGen/Props.luau`:

- `Props.trees` opens with `Props.template(Assets.KEY.treeSpruce, root)` and hands that one template to
  every `Props.placeTree` call in the block, whatever `Scatter.speciesAt` returned.
- `Props.placeTree`'s `template` branch calls `placed(template, name, trunk, …)` and **discards the
  species row entirely** — `row.crown`, `row.height`, `row.crownColor` and `row.trunkColor` are read
  only by the proxy branch below it.
- `Props.tieTrees` asks for the same `Assets.KEY.treeSpruce`.
- `Props.brush` never calls `Props.template` at all, so brush can never become an asset without a code
  change, against §12.1's `brush = "prop.brush.a"`.

`tests/server/map_contract.spec.luau`, `it("plants Karen's four species, in her proportions, with
alder in the wet")` and `it("draws the species independently of the density, so the mix is the same in
a thin wood")`, both measure `MapGen.Scatter.speciesAt` directly. **Neither reads
`Workspace.DrivenHuntMap.Props.Trees`.** Nothing anywhere asserts that the instance planted at a point
is the species the sampler chose for it.

**Why it matters.** The day the first tree id lands in `Assets.ROWS`, all ~2,746 trees in the wood
become the same spruce mesh, the tie trees become spruce too, and **every species spec still passes**,
because every one of them is a claim about a pure function. Task 63's round-1 blocking finding was that
one number answered two questions and half the wood was a monoculture; the aggregate share assertion
passed over it, which is why the spec was rewritten per density tier. This is the same bug with the
same blind spot one layer down — the wood is a monoculture again, and this time the tier assertion
passes too, because it is still measuring the sampler and not the world.

There is a second, smaller edge in the same function that M2.8c will copy seven times.
`Props.placed`'s `position` argument means **two different things** depending on who calls it:
`Props.hedge` passes `y + size.Y / 2` (the centre) and `Props.placeTree` passes `y` (the ground). Both
reach `clone:PivotTo(CFrame.new(position))` and `clone.Position = position`. One of them is wrong for
any real mesh, and which one depends on the caller — the "one predicate answered two unrelated
questions" shape, in the function every new prop kind will be routed through. The pivot half of this is
`TASKS.md` row 43a(d) and audit-004 F11; the **two-meanings** half is new.

**Fix.** Three pieces, all buildable now and all cheap while `Assets.ROWS` is still empty:

1. `src/serverstorage/MapGen/Assets.luau`: bring `Assets.KEY` to the design's six keys, and give
   `Config.SPECIES` each row an explicit `assetKey` so `Props.trees` asks per tree, not per block.
   `Props.template` caches per key already, so this costs one `FindFirstChild` per species per step.
2. `src/serverstorage/MapGen/Props.luau`: `Props.placeTree` records the species it placed as an
   attribute on the model (`Species`), and `tests/server/map_contract.spec.luau` gains one assertion
   over the **built** `Props.Trees` folder comparing that attribute's distribution against the
   sampler's — the check that would have failed on Task 63's monoculture and will fail on a
   single-key wood. It is a map-branch check, so it runs at M2.8e; until then `mapgen.py verify` can
   carry it.
3. `placed` takes the anchor explicitly (`"centre"` / `"ground"`) rather than letting the caller decide
   silently, or is split in two. Do it before M2.8c adds stakes, a high seat, barriers, log piles, a
   fence, a gate and reeds to the list of callers.

---

## Fix before release

**F1. audit-004's own log-only list was never queued — the exact failure audit-004 must-fix 2 was
about, one audit later.** `TASKS.md` row 47b carries audit-003's F1–F12 **and** L1–L13; row 47c carries
audit-004's **F1–F11 only**, and its title says so ("audit-004's fix-before-release list"). A grep of
`TASKS.md` for `L1-L13` returns rows 47, 47a and 47b, all about audit-003. Audit-004's L1–L13 exist
only inside `docs/architecture/audit-004.md`. Two of them are still live and cheap: **L10** —
`ServerStorage.MapGen` ships in the published place and row 2's strip list (TestRunner,
ClientTestRunner, TestKit, Tests, ClientTests, DevPackages, TestSyncToken, SyncCheck, the `DHFlag_*`
attributes) still does not name it; **L12** — CI (`.github/workflows/ci.yml`) runs nothing against
`tools/*.py` beyond `privacy_scan.py selftest` and `meshy.py selftest`, while `studio_mcp.py`,
`mapgen.py`, `agents.py` and `flags.py` have no check at all. Fix: one `TASKS.md` row for audit-004's
L1–L13 in the shape 47b already has, and one row for this audit's two lists below. The pattern to stop
repeating is "the F list gets a row and the L list does not".

**F2. The client half of the feature-flag system has no production reader, and its only caller is its
own spec.** A grep of `src/` for `Flags` returns three files: `src/shared/Flags/init.luau`,
`src/server/FlagsBoot.server.luau` and `src/server/Match/init.luau`. Nothing under `src/client/`
requires it. So `resolveOnClient`, the `Flags.WAIT_SECONDS = 10` deadline with its attribute-changed
signal, the digest-disagreement `warn`, and the whole `published` / `published-timeout` source
distinction are reached in production by nobody — only by
`tests/client/flags_client.spec.luau`. This is not wrong (it is the transport the first client-read
flag will need, and building it with the server half was the right call), but 60 lines of production
code whose sole exerciser is its own test is one step from "a test that tests only itself", and
`docs/design/feature-flags.md` does not say the client path ships ahead of its first reader. Either
name the first client-side flag or record the deliberate lead in the design.

**F3. `Match.Markers.read` publishes a flat-ground guarantee the arena does not make.**
`src/server/Match/Markers.luau`, `Markers.read`, returns `spawnRadius = Map.SPAWN_PAD.radius`
unconditionally, in every world. `src/shared/Map/init.luau`'s comment above `Map.SPAWN_PAD` says what
that number is: *"Where a spawn pad is flattened, so a boar is never released inside a hill"* — a
property of the **generated map**. While `EXPECTED_WORLD` is `"arena"` there is no pad and no easing;
30 studs of flat ground is true there only because the arena is a plate, not because anything
guarantees it. `Match`'s `applySpawnSounder` passes that number to
`Runtime:spawnSounder`, which rings up to five collidable bodies at radius 10 around the marker with no
check that the ring is clear of the arena's cover blocks — and with `BOAR_SOUNDERS` on, which is how
Karen played it (`TASKS.md` row 61b), that is a live path. Say in `Markers.read` that the arena is flat
by construction so the contract's number holds there, or return `nil` in the arena and let the runtime
fall back to `SOUNDER.SPAWN_RING_STUDS`.

**F4. `Boar.newRuntime`'s config clone is shallow, so every runtime in a session shares one `SOUNDER`
table.** `src/server/Boar/init.luau`, `Boar.newRuntime`: `self._config = table.clone(Boar.CONFIG)`
followed by a top-level merge of `world.config`. `table.clone` is shallow, so `self._config.SOUNDER`,
`.WOUND`, `.ZONES`, `.AGENT` and `.field` are the **module's own tables**, shared by production and by
every spec runtime alive at the same time. `boar_body.spec` runs two live runtimes concurrently (the
plate at y = 500 and the sounder plate at y = 1500, whose comment says so). Nothing writes into those
sub-tables today, and `Boar.CONFIG` is the only config table in the repo with no `deepFreeze` —
`Shotgun.CONFIG`, `Drive.CONFIG`, `Map`, `Flags.DEFAULTS` and `Match.CONFIG` are all deep-frozen — so
nothing stops one from doing so. This is audit-003 F3 and F4 (`TASKS.md` row 47b) with a new
consequence: freezing `Boar.CONFIG` would turn "a spec quietly retunes production" into an error at
the moment of the write. Do it before M2.8e changes `Boar.CONFIG.field`, which is the one task that
edits this table.

**F5. `MapGen` enforces three of `Map.BUDGET`'s five ceilings, and M2.8c adds props under none of
them.** `src/serverstorage/MapGen/init.luau`: the `props` branch fails the build over
`Map.BUDGET.trees`, the `brush` branch over `Map.BUDGET.brush`, and `MapGen.verifyContract` over
`Map.BUDGET.parts`. The `hedgerow` branch checks nothing, so `Map.BUDGET.hedgeParts = 400` has no
enforcer at all, and `Map.BUDGET.visibleParts = 8000` has none either. This is `TASKS.md` row 63a(n)
with the hedge half added. M2.8c's line furniture — stakes at eight posts, a high seat, two barriers,
two log piles, a fence, a gate and reeds — arrives with no budget row and no ceiling. Add the checks and
a `Map.BUDGET.furniture` before the props are placed, not after a build gets slow.

**F6. `placed`'s asset branch is written against `InsertService`'s container shape and will invert at
M2.7d.** `src/serverstorage/MapGen/Props.luau`, `placed`, does `template:GetChildren()[1] or template`
with the comment *"LoadAsset returns a container Model; the asset itself is its first child"*.
`docs/design/asset-pipeline.md` §5 has `Loader.template(key)` return **the asset**, not a container —
so the day `Props` moves onto the Loader, this line takes the asset's first child instead of the asset.
It is a one-line change, and it is exactly the sort of quiet inversion that shows up as a tree with no
trunk rather than as an error. Note it at the call site now, or delete the unwrap when the Loader
lands.

**F7. `Runtime:pathProblems()` still does not exist, and the reasons are still locked in a closure.**
`src/server/Boar/init.luau`, `Boar.defaultWorld`, builds `pathProblems` and exposes it on the world
closure; `Runtime:stats()` carries `pathFailures` as a bare count and there is no accessor for the
reasons; `src/server/MatchBoot.server.luau` keeps the world in a local and never reads it. This is
audit-003 F2 / row 47b F2, and Task 60 is what it cost: *"every boar path request has been failing
since Milestone 1.2, hidden by the Brain's straight-line fallback"*, found by a hand measurement, not
by the diagnostic written for exactly that. The count **is** now asserted live —
`tests/server/boar_body.spec.luau`'s sounder block ends `expect(after.pathFailures).to.equal(0)` on a
real physically-simulated sounder of five, which is what makes `PATH_START_AHEAD` regression-covered —
so this is no longer a false-PASS path, only a missing diagnostic. Close it at M2.8e, when the boar's
world changes from a 400-stud plate to 2,746 trunks and "why did it fail" becomes the question.

**F8. M2.8e switches the world under ~380 specs in one commit, and no spec has ever run against the
generated map.** `tests/server/map_contract.spec.luau` check 5 (pathfinding) runs against the arena
while `EXPECTED_WORLD` is `"arena"`; `boar_body.spec` builds its own plates at y = 500 and y = 1500;
the `match_*` specs use fakes; only `zz_drive_boundary.spec` touches the live world. The generated map
has only ever been walked by `MapGen.reachability` in Edit. So the switch commit is the first harness
run in which the arena's assumptions — a 400 × 400 plate at y = 0, solid 8 × 24 × 8 tie pillars, four
spawn markers 300 studs apart — are all false at once. Nothing here is broken; the recommendation is
sequencing, and it is the Director's: dispatch M2.8e as its own task with nothing else in it, run
`test` and `test2` on it, and expect a round of spec repairs rather than treating one as a regression.
Row 47a(c) is the related gap — the spec's map branch asserts only `cells > 0`.

**F9. Still open and re-verified at this commit, from earlier audits' queues.** Re-checked because each
sits in a file the next tasks open: audit-004 F6 (`GAME_DESIGN.md`'s Hud row still names no config
location while `src/client/Hud/init.luau` reads numbers from both `Shotgun.CONFIG` and `Drive.CONFIG`)
— row 47c F6; audit-004 F8 (dead numbers in `src/client/Camera/Config.luau` and
`src/shared/Shotgun/init.luau`) — row 47c F8; `MapGen.markerDigest` still has no caller, and its reader
is M2.8e's check 11 — row 43a(g); `tests/client/map_client.spec.luau` still does not exist although
measurement N1 and design §16.2 both assume it — row 58a(d); `src/client/Match/init.luau`'s
`Match.stop` still has no caller — audit-004 L8.

---

## Log only

- **L1. `BOAR_SOUNDERS` expires 2026-10-17 and nobody has recorded a decision.**
  `src/shared/Flags/init.luau`, `Flags.DEFAULTS.BOAR_SOUNDERS`, `default = false`, born 2026-09-26.
  Karen has already played with it on (`TASKS.md` row 61b) and commented only on boars sticking on
  walls — nothing about whether the sounders themselves are right. `tests/server/flags.spec.luau`'s rot
  tripwire will fail the harness on 2026-10-18. That is the mechanism working, and the answer is one of
  three lines; **Karen's call at the next playtest**, and the Director's to put on the agenda.
- **L2.** `Match.CONFIG.SOUNDER.ENABLED` is read once when `src/server/Match/init.luau` is required and
  `Match.CONFIG` is then deep-frozen, so `tools/flags.py set BOAR_SOUNDERS on` only takes effect for a
  session started **after** it. That is the design's intent (one answer per process) and
  `docs/design/feature-flags.md` says so; recorded because "set it and look" is the obvious wrong
  reading of the Director's workflow.
- **L3.** `Runtime:sounders()`, `Runtime:sounderOf()` and `Runtime:capacity()` have no production
  reader — `src/server/Boar/init.luau`'s own comment says *"the drive never reads any of them in
  production — they exist for specs, for diagnostics, and for the step's own bookkeeping"*, and
  `Match`'s `dispatch` reads `capacity`/`count` through the world. Recorded so a later audit does not
  call them dead code.
- **L4.** `Runtime:_leaveSounder` writes `entry.sounderId = nil` while `record.memberIds` still holds
  the id; the list is rebuilt from `self._boars` at the end of the same `_stepSounders` pass, and the
  dissolve branch discards the record. Correct as written, and the one place in this system where two
  tables describe one fact — worth the sentence the header does not quite give it.
- **L5.** `GAME_DESIGN.md`'s arena row still says *"the arena is the only thing this repo puts in
  Workspace at all"* and then names three run-time folders; it is four containers plus
  `Workspace.Terrain` and the material palette. Rows 24a(d), 38a(f), audit-004 L1. Unchanged.
- **L6.** `Props.speciesRow(config, nil)` returns `Config.TREE_PROXY` for the tie trees, whose trunk
  (3 × 30) is the spruce trunk and whose crown (14 × 44) is nothing in `Config.SPECIES`. It is
  deliberate — the comment says the tie trees *"are placed on purpose and are not of the wood"* — but
  it means `Props.trunks` returns twelve trees whose footprint matches no species, and `Body.tiePointFor`
  computes its radius from `max(trunk.X, trunk.Z) / 2 + TIE_GAP_STUDS`. Harmless; it becomes a visual
  question at M2.3, when the twelve are the only trees in the place with no mesh.
- **L7.** `MapGen.expectedCounts()` is derived from `Layout.markers` plus `Config.WORLD.tieTrees`, and
  `Map.EXPECTED_COUNTS` is hand-written for the arena (`tree = 4`). Both are right for their own world
  and the comment says so; noted because M2.8e must change the second and will be tempted to reach for
  the first.
- **L8.** `docs/research/INDEX.md` has a row for every note including the three new ones (meshy,
  feature-flags, asset-pipeline), and `docs/design/README.md` is current. Rule 1's paperwork is in
  order; recorded because audits usually find drift here and this one does not.
- **L9.** `tools/studio_mcp.py`'s `run_test2` still has no drive-clock seam check where `run_test`
  does (`seamClosed`), row 48a(b). Unchanged, and it is the Builder's stated reason not to add one
  blind.
- **L10.** `Config.WORLD.treeCount` and the `Map.BUDGET.trees = 3000` ceiling are both enforced per
  quadrant step, so a runaway scatter fails the build rather than the place. Verified working in
  `MapGen.runStep`'s `props` branch; noted as the one budget that is properly wired, against F5.

---

## Not verified

- **Anything requiring Roblox Studio.** No Studio in this session (`.agent-evidence/INDEX.md`). Every
  claim about what the harness, the generator or the engine *would* do is read from source. Every
  claim about what is on screen is read from the Builder's own inspected-screenshot notes in
  `TASKS.md` rows 58, 60, 61 and 63.
- **Must-fix 2's consequence is reasoning, not an observation.** That `Props.trees` asks for one key
  and that no spec reads the built wood's species are both certain from the source. That a real id
  *would* produce 2,746 identical spruces is an inference: `Assets.ROWS` is empty, so the insertion
  branch has never run (`TASKS.md` row 43a(d) says the same). The finding is about the absent check and
  the single key, not about a state I saw.
- **`Props.placed`'s pivot behaviour with a real mesh.** Which of the two callers is wrong depends on
  where the imported model's pivot sits, which needs a real asset and Studio. Row 43a(d) already says
  to fix it against a real mesh rather than by guessing; this audit only adds that the *argument* means
  two things.
- **Anything needing git.** No log, no diff, no `paperwork-after-code-commit.txt` in this run's
  evidence (six files). I could not check the merge gate, could not diff `main` against any branch, and
  could not confirm which of the many `in review` / `in progress` rows in `TASKS.md` are actually on
  `main` at this commit. Rows 49–63 are read as the Builder wrote them.
- **CI status and the harness's own numbers.** No CI output in `.agent-evidence/`. The spec counts
  (377 server, 84 shooter, 78 driver) and every `[harness]` / `[harness2]` line quoted above come from
  `TASKS.md` and were not recounted.
- **`tools/studio_mcp.py`, `tools/meshy.py` and `tools/mapgen.py` were read by grep, not in full.**
  The flag-override refusal, `run_test`'s seam check and `run_test2`'s override check were confirmed by
  name and line context only. I did not audit Task 62's refine/remesh/fetch paths at all, so this audit
  says **nothing** about whether Task 64's Meshy fix has a blocker — that is the gap the Director should
  know about, and it is a deliberate scope call given the four other named tasks.
- **DevPackages / TestEZ.** `DevPackages/` is absent from the worktree, so `devpackages.sha256` could
  not be exercised and spec-module ordering (`zz_` in two suites, audit-004 L9) is still the Builder's
  measurement, not mine.
- **Every external URL** in the new module headers and in `docs/research/2026-09-26-*.md`, and the
  licence and maintenance status of every source cited there. No network. audit-003 L9 (a fabricated
  DevForum URL reached a merged commit) makes this worth restating rather than assuming.
- **Measurement B** — whether `CollectionService` tags survive a save and a reopen — is still open from
  Task 43 and is a click only Karen can make. Every tag-based claim here assumes they do, including the
  one-world check the whole map switch rests on.
