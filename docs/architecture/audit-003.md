# Architecture audit 003

Commit `c690f82d221778333ef234cbae6f41250a474d41`, branch `HEAD` (`.agent-evidence/head.txt`).
Read-only session: Read, Grep, Glob. No Studio, no network, no git. Evidence precomputed in
`.agent-evidence/` (`INDEX.md`).

**Brief.** `reviews/task-31/BRIEF.md` (Director): audit `main` after Tasks 17–27. Speed rule 2 applies —
an item is must-fix only if it blocks Task 28 (hit zones), Task 30 (harness 2+ players / place+aim),
1.7a (the drive) or 1.7b (safety + score), and the audit names which. Focus: second writers (camera,
cursor, Hud, boar state), silent failures, test code that cannot fail, drift between `docs/design/`
and code.

**Scope read.** Every file under `src/` and `tests/`; `tools/studio_mcp.py` (docstring plus
`load_scenarios`, `scenario_batches`, `replay_input`, `run_test`, `verdict`); `docs/design/camera.md`,
`hit-zones.md`, `drive.md` in full and `boar-ai.md`/`shotgun.md` by section; `GAME_DESIGN.md`,
`TASKS.md`, `ROADMAP.md`, `CLAUDE.md`, `docs/PROJECT_CONTEXT.md`, `docs/research/INDEX.md`;
`docs/architecture/audit-001.md` and `audit-002.md`.

**Not re-raised.** audit-001's M1–M4/R1–R3 and audit-002's must-fix 1–5 are queued as `TASKS.md`
rows 8 and 12–16 under the tooling freeze (`ROADMAP.md` speed rule 1); rows 6a, 21a, 23a, 24a and 26a
carry the open review notes. I checked each list and this audit repeats none of them except where a
finding below is a **new instance** of a pattern one of them named, which is said explicitly.

**State of the tree.** Lint, format and build are clean (`.agent-evidence/lint-selene.txt`,
`lint-stylua.txt`, `rojo-build.txt`, all exit 0). Five systems are merged and owned: arena, boar,
weapon (server and client), camera, Hud. `GAME_DESIGN.md`'s *System owners* table mirrors
`docs/design/camera.md` §11 row for row, which is the first time in this repo that rule 3's paperwork
has kept up with the code. One camera writer is real: a grep for `CurrentCamera` across `src/` finds
assignments in `Rig.luau` only (`src/client/Camera/Rig.luau`, `Rig.apply`, `Rig.acquire`,
`Rig.release`); every other hit is a read or a comment. One mouse writer is real: the only assignments
to `UserInputService.MouseBehavior`/`.MouseIconEnabled` in `src/` are in `src/client/Camera/Cursor.luau`
(`Cursor.apply`, `Cursor.stop`). Everything drawn has one writer: `Instance.new("ScreenGui")`,
`"Frame"` and `"TextLabel"` appear only in `src/client/Hud/init.luau` (`build`, `arm`).

So the findings below are not about overlapping owners in today's code. They are about the two places
where the *evidence* for one owner is weaker than the document claims, one collision the next task
walks into, and a list of smaller holes.

---

## Must fix now

### 1. The drive's own defaults leave the harness's single player unarmed, and two client specs depend on his gun

**Blocks: 1.7a, and 1.7b with it.**

**Evidence.** `docs/design/drive.md` §4.1, the `Waiting` row: entered at boot and held "until
`#participants >= MIN_PLAYERS`", and in it "no teams, no boars, no timer. Everyone is neutral and
**unarmed**". §11.1: `MIN_PLAYERS = 2`, `ODD_PLAYER_TEAM = "Drivers"`, `DRIVERS_MAY_SHOOT = false`.
§8.5 adds `Weapon.setArmingPolicy` and `Match.mayCarryWeapon`, which is true only for a Shooter (or a
Driver when `DRIVERS_MAY_SHOOT`) in `Assigning`/`Running`/`Scoring`.

The harness's Play session has exactly one player: `tools/studio_mcp.py`, `Studio.set_play` calls
`start_stop_play` with `{"is_start": bool}` and nothing else, and `QUERY_REPORT["client"]` reads
`Players.LocalPlayer` — the design says so itself in §12.6. One player is below `MIN_PLAYERS`, so every
harness run after 1.7a sits in `Waiting` and nobody is armed. Raising `MIN_PLAYERS` to 1 does not fix
it either: a lone player is the odd player, `ODD_PLAYER_TEAM = "Drivers"`, and
`DRIVERS_MAY_SHOOT = false`.

What breaks, on `main`, today:

- `tests/client/weapon_client.spec.luau`, `parkTool` returns false with no `Shotgun` in the Backpack or
  the character, and `it("equips on the cue and starts full")` asserts `expect(parked).to.equal(true)`.
  The whole `describe("the harness-driven weapon")` and `describe("the crosshair")` blocks then fail:
  no Tool, no `StateChanged` snapshot (`src/server/Weapon/init.luau`, `Weapon.grant` is the only
  publisher of a first state), no crosshair (`src/client/Hud/init.luau`, `render`, needs
  `state.equipped`).
- `tests/client/camera_client.spec.luau`, `describe("the harness-driven aim")` waits for
  `Camera.stats().aimEnters` to rise. The aim action is bound on `Tool.Equipped`
  (`src/client/Weapon/Input.luau`, `watchTool` → `bind`), so with no Tool the replayed right mouse
  reaches nothing and both the weapon scenario's hold and `aim-hold` time out.
- `tests/client/input_scenarios.txt` scenarios `weapon-fire-reload-ammo` and `aim-hold` become
  scenarios that drive nothing, while `tools/studio_mcp.py`, `replay_input`, still reports "replayed
  every step" — the steps are sent, so that check stays green while the evidence is gone.

**Why it matters.** `docs/design/drive.md` §8.5 says "`shouldArm` stays as the default for a server with
no Match — which is exactly what `tests/server/weapon_*.spec.luau` are, so **Task 24's specs are
untouched**". That is true of the server specs and silent about the two client specs, which do not run
against a stand-in world: they run inside the live Play session where `MatchBoot` will run. §12.7 says
"No new input scenario" and does not mention that the two existing ones stop working. A Builder who
starts 1.7a discovers this as a red harness on two specs it did not touch, and the cheap way out is to
weaken them — which is "the harness was wrong as often as the game"
(`docs/PROJECT_CONTEXT.md`) plus rule 6 abandoned in the same move. This is also the first task where
the answer cannot be "test it with a stub": the point of those two specs is the player's real input path.

**Fix.** A decision, then one amendment to an Architect-owned document, before 1.7a is dispatched (the
Builder never edits `docs/design/` — rule 3; the delta mechanism `reviews/task-24/DESIGN_DELTA.md`
already exists, or regenerate `drive` with this in the brief). The design must state, in §8.5 and
§12.6, how a one-player harness run is armed, and `match_live.spec` must assert it.

Options, worst to best:

1. Special-case the Match while a `TestKit` token is open. **Rejected**: production behaving
   differently under test is the failure mode the whole harness exists to avoid.
2. `DRIVERS_MAY_SHOOT = true` in the DEV place. Changes the game being tested.
3. Move the fire/reload/ammo/aim assertions off the client. Gives up rule 6 for the one system Karen
   judges by feel.
4. **Recommended:** `MIN_PLAYERS = 1` and a lone player assigned to **Shooters**, both as Karen's
   numbers in `Match.CONFIG` (§11.1). A one-person drive is already a supported state — §4.4, "A drive
   never aborts because a team emptied … With 2 players, one leaving leaves a one-person drive that runs
   to the end and scores" — so this makes the *starting* case match the running case, and the harness
   then tests exactly what a player gets. `ODD_PLAYER_TEAM` is Karen's call because it also decides
   n = 3, 5, 7.

### 2. The foreign-write detector cannot see a rotation-only write, and it is the only runtime proof of one camera writer

**Blocks: 1.7a and 1.7b** — they add `PlayerScripts.Match`, `MatchBoot.client.luau` and
`src/client/Hud/Scoreboard.luau` (`docs/design/drive.md` §3.6), whose "never writes the camera"
prohibition (§1.2, first row) has no other mechanical check.

**Evidence.** `src/client/Camera/Rig.luau`, `Rig.apply`:

```
local drifted = (cam.CFrame.Position - lastCFrame.Position).Magnitude > 1e-3
    or math.abs(cam.FieldOfView - lastFov) > 1e-3
```

Position and field of view only. The camera's **orientation** is never compared, and neither is
`CameraType` or `CameraSubject`. `docs/design/camera.md` §10.1 says the opposite: "it compares
`cam.CFrame` and `cam.FieldOfView` with that record", and calls the detector "the single most valuable
thing in this design … rule 3 enforced by mechanism instead of by policy". §1.2's first prohibition row
covers `CFrame`, `FieldOfView`, `CameraType` **and** `CameraSubject`.

Two specs rest on it. `tests/client/camera_client.spec.luau`,
`it("is the ONLY thing writing the camera and the mouse")`, asserts
`expect(stats.foreignCameraWrites).to.equal(0)` and the comment says "if the stock camera ever comes
back, or a plugin or a future LocalScript writes the camera, this is the number that says so".
`tests/client/weapon_client.spec.luau`, `it("never writes the camera itself")`, was rewritten in Task 26
specifically to replace a direct assertion with this counter ("the camera's own foreign-write detector
is the mechanical proof"). `TASKS.md` row 26 states the stakes plainly: this place has no
`PlayerScripts.PlayerModule`, so `GetCameras():Disable()` never runs and "the detector
(`foreignCameraWrites == 0`) is the only proof of one writer".

**Why it matters.** A second writer that turns the view without moving the camera — a look-at-the-score
-screen tween, a plugin, a `CameraSubject`-driven behaviour, any future client system that sets a
CFrame with the same position — passes. The number reads 0, both specs go green, and the review signs
off "one writer" on evidence that cannot see the case it exists for. That is a false-PASS path in the
one guard the next two tasks will be judged against, and it is a handful of lines in the file that owns
it.

**Fix.** In `Rig.apply`, extend `drifted` to the rotation: compare one basis vector, e.g.
`(cam.CFrame.RightVector - lastCFrame.RightVector).Magnitude > 1e-3 or
(cam.CFrame.LookVector - lastCFrame.LookVector).Magnitude > 1e-3`. Add an assertion to
`tests/client/camera_client.spec.luau` that a deliberate rotation-only write to
`workspace.CurrentCamera.CFrame` (same position, different look) raises the counter, so the detector is
itself tested rather than assumed — the property `tests/server/boar_hit.spec.luau`'s teardown test was
rewritten to have ("a test that could not fail, guarding the one line it existed for").

**Do not** add `CameraType` or `CameraSubject` to the comparison in `apply`: `Rig.acquire`'s own header
records that the engine restores `CameraType` on respawn, and the engine sets `CameraSubject` to the new
`Humanoid`, so either would count the engine's respawn as a foreign write every life. If they are to be
watched, watch them where `acquire` re-asserts them and report separately.

---

## Fix before release

**F1. `Rig.setLocalBodyHidden` caches the local character's parts once per life, so the gun the player is
holding is not hidden in ADS.** `src/client/Camera/Rig.luau`, `Rig.setLocalBodyHidden`: `hiddenParts` is
rebuilt only when `hiddenFor ~= character`, and the write loop is skipped entirely when
`hiddenNow == hidden`. The list is therefore whatever `character:GetDescendants()` returned on the first
frame of that life. The Tool is granted server-side on `CharacterAdded`
(`src/server/Weapon/init.luau`, `watchPlayer` → `Weapon.grant`, `CONFIG.AUTO_EQUIP`) and its `Handle`
reaches the client's character a moment later, i.e. after the camera's first render step with that
character — so the `Handle` is very likely absent from `hiddenParts` and keeps
`LocalTransparencyModifier = 0` while the rest of the body goes to 1. Layered accessories replicate the
same way. The symptom is exactly the one the function's own comment says two screenshots taught: "with
the Tool excluded the real gun was drawn beside the viewmodel clone — two shotguns on screen at once",
and "with accessories excluded the hair hung across the top of the ADS view". No spec can catch it:
`tests/client/camera_client.spec.luau` item 5 checks the *viewmodel's* parts, never that the real
`Handle` was hidden. **I could not run it** (see *Not verified*); this is read from the code. Fix:
re-resolve the parts when the character's descendants change (`DescendantAdded`, or rebuild when
`#hiddenParts` disagrees with the walk) and apply the current flag to any part added while hidden. Then
assert it: while aiming, every `BasePart` of `Players.LocalPlayer.Character`, the Tool's `Handle`
included, has `LocalTransparencyModifier == 1`. This is the highest-value item in this section and it is
Karen-visible at the next camera playtest; it deserves a `TASKS.md` row now.

**F2. The path-failure diagnostic is written and unreadable in production.**
`src/server/Boar/init.luau`, `Boar.defaultWorld` keeps `pathProblems` ("Record WHY, not just that it
failed. A permanent silent fallback to straight-line flee is the failure mode this exists to make
visible") and exposes it as `world.pathProblems()`. `src/server/BoarBoot.server.luau` calls
`Boar.newRuntime(Boar.defaultWorld())` and keeps no reference to the world; `Runtime:stats()` returns
`pathFailures` as a bare count and no reasons, and there is no `Runtime:pathProblems()`. Only specs
(`tests/server/boar_body.spec.luau`, which holds `Boar.defaultWorld(FIELD)`) can read it. So in a live
server the boar can fall back to straight-line flight forever and the record of why exists in a closure
nobody holds. Fix: a `Runtime:pathProblems()` accessor forwarding to `self._world.pathProblems`, read in
the composition root. 1.7a is the moment: `docs/design/drive.md` §3.6 archives `BoarBoot` into
`MatchBoot`.

**F3. `world.config` is a dead, half-working override path.** `src/server/Boar/init.luau`,
`Boar.newRuntime`, merges `world.config` into a clone of `Boar.CONFIG` for the runtime, but
`Boar.defaultWorld` opens with `local config = Boar.CONFIG` and its `threats` and `requestPath`
closures read that module table, not the clone. So `config = { isThreat = … }` in a world changes the
Brain's copy and not the function that filters threats or the one that builds the `Path` agent.
`docs/design/drive.md` §6.5 found this and routes around it with one line at the composition root
(`world.threats = Match.driverThreats`). No spec passes `world.config` at all, so the mechanism is
untested as well as wrong. Fix inside `Boar`, not around it: pass the runtime's merged config into
`defaultWorld`, or have `newRuntime` rebuild the world's config-dependent closures. Until then it is
two correct pieces of code disagreeing, which is the shape `docs/PROJECT_CONTEXT.md` names.

**F4. `Boar.CONFIG` is the only "one config table" in the repo with no writer by anything but
convention.** `src/shared/Shotgun/init.luau` ends with `Shotgun.deepFreeze(Shotgun.CONFIG)` and
`src/client/Camera/Config.luau` ends with `return table.freeze(Config)`, and both are asserted
(`tests/client/weapon_client.spec.luau`, `it("keeps CONFIG frozen to its nested tables")`;
`tests/server/camera_mode.spec.luau`, `it("keeps the config frozen")`). `Boar.CONFIG` is a plain table:
nothing freezes it, its nested `field`, `AGENT` and `spawnPoint` are writable, and any server module
could rewrite the boar's numbers at run time. Freezing it requires F3 first, because today mutating
`Boar.CONFIG.isThreat` is the only way to change who scares a boar. Task 28 adds `CONFIG.ZONES` and
`CONFIG.WOUND` to this table (`docs/design/hit-zones.md` §3.2), which makes it the right task to close
this in.

**F5. The UI owner's numbers live in the weapon's config.** `src/client/Hud/init.luau` takes
`CROSSHAIR_ARM_PX`, `CROSSHAIR_GAP_PX`, `CROSSHAIR_THICK_PX`, `CROSSHAIR_COLOR`, `CROSSHAIR_ENABLED`
and `HUD_TEXT_SIZE` from `Shotgun.CONFIG`, while `GAME_DESIGN.md`'s `ReplicatedStorage.Shotgun` row
describes that table as "every ballistic, timing, layout and rate number" of the weapon and the
`PlayerScripts.Hud` row names no config location at all. 1.7a adds drive-bar and scoreboard numbers to
the Hud from a third table (`Drive.CONFIG`). Decide now where the UI owner's numbers live and say so in
its owner row, before the Hud reads three configs and no row says which.

**F6. Four numbers in "the one config table" that nothing reads.** `Shotgun.CONFIG.SLUG_CAST_RADIUS`
and `Shotgun.CONFIG.CAMERA_DRIFT_TOLERANCE` (`src/shared/Shotgun/init.luau`) appear in no `.luau` file
but their own; `Camera.Config.CURSOR_LOCKED_DEFAULT` and `Camera.Config.FREE_CURSOR_ON_DEATH`
(`src/client/Camera/Config.luau`) likewise — `Cursor.apply` hard-codes
`Enum.MouseBehavior.LockCenter` and nothing consults either flag. `CAMERA_DRIFT_TOLERANCE` is the worst
of the four: it is commented "studs the camera may drift relative to its subject (13.3)" and the spec
that used it was rewritten in Task 26, so the config now documents a rule nothing enforces. In a repo
whose rule is "every number in one config table", a number nothing reads is a claim about behaviour
that is not there — and `CURSOR_LOCKED_DEFAULT = false` would change nothing while looking as though it
had. Fix: wire each one or archive it with a note (rule 7).

**F7. `Camera.stop()` is completely untested, and the design asked for the test.**
`docs/design/camera.md` §9.2 item 11 specifies a teardown assertion in `afterAll` — no
`DrivenHunt.Camera` render binding, no viewmodel, a free cursor, `CameraType == Custom` — and states
why it must be in `afterAll` rather than asserted inside the `it` ("Task 6a note (a) is the record of
that mistake, and this spec does not repeat it"). `tests/client/camera_client.spec.luau` has no
teardown block of any kind, so `Camera.stop`, `Rig.release` and `Cursor.stop` have never run under
test. Design §8.2's target "Zero Instances created per frame … the client spec counts
`workspace.CurrentCamera:GetDescendants()` across 120 frames" is also absent.

**F8. The teardown-then-assert anti-pattern has a second instance.** `TASKS.md` row 6a(a) records it in
`tests/client/input_driving.spec.luau`, `it("leaves nothing bound behind")`, which is still unfixed;
`tests/client/weapon_client.spec.luau`, `it("unbinds the cue key")`, is the same shape — it calls
`ContextActionService:UnbindAction(CUE_ACTION)` and then asserts the unbind worked, so it can only
pass. Fix both together: move the unbind into `afterAll` and drop the assertion, or assert the state
before tearing down.

**F9. A scenario's `spec` field is dead and the file's order is load-bearing.**
`tests/client/input_scenarios.txt` gives every scenario a `spec` ("ClientTests.input_driving.spec" and
so on) and `tools/studio_mcp.py`'s docstring documents it in the format, but nothing reads it:
`load_scenarios` and `replay_input` ignore it, and no check asserts the named spec exists or ran.
Meanwhile `tests/client/input_driving.spec.luau` selects its scenario as
`scenarios.scenarios[1]`. So the link between a scenario and the spec that asserts it is convention
only, and inserting a scenario at the head of the list silently repoints that spec. It fails loudly
today (the spec hard-codes `"F"` and `casButton == 2`) rather than passing wrongly, which is why this is
not must-fix — but Task 30 adds scenarios, and selecting by `spec` name is a two-line change.

**F10. `Shotgun.CONFIG.shouldArm`'s comment promises what the drive design forbids.**
`src/shared/Shotgun/init.luau`: "ROADMAP 1.7 makes this `player.Team == Teams.Shooters` and touches
nothing else". `docs/design/drive.md` §8.5 rules that out and gives the reason: `Shotgun.CONFIG` is
deep-frozen and replicated to every client, so a match rule cannot live there. The comment now points
the 1.7a Builder at a route the design closed. Same class: `Boar.CONFIG.isThreat`'s comment
("Milestone 1.7 replaces the body and touches nothing else") is defeated by F3. Rule 9 makes comments
load-bearing; fix both when 1.7a touches the files.

**F11. `TestArena.build` returns an existing folder untouched.** `src/server/TestArena.luau`,
`TestArena.build`: `local existing = root:FindFirstChild(LAYOUT.folderName) if existing then return
existing end`. 1.7a adds posts, a drive line, driver start and boar spawns to `LAYOUT` and tags them
(`docs/design/drive.md` §6.1). If a folder named `TestArena` is ever present before the build — a saved
place, a second call, a Studio-made stray — the new markers are silently absent and `Markers` reports
"incomplete", which the phase machine reads as `Waiting`. Low risk today (Workspace holds only `Camera`
and `Terrain` in Edit, `TASKS.md` row 22), and the failure is loud at the Match rather than silent, but
the idempotence should be "build what is missing", or at least `warn` what it skipped.

**F12. `Runtime:spawn` refuses overflow with `assert`.** `src/server/Boar/init.luau`, `Runtime:spawn`:
`assert(#self._boars < self._config.maxBoars, "Boar runtime is at maxBoars")`. 1.7a raises `maxBoars` to
8 and releases boars on a schedule with `MAX_ALIVE_BOARS = 4` (`docs/design/drive.md` §3.6, §11.2), so
the Match becomes the caller of this assert inside its own effect loop, where a throw takes the rest of
the effect list with it. A refusal (`return nil`) plus a counter is the shape the rest of this system
uses — `Runtime:takeHit` returns `false` for a part it does not own "so the caller needs no filtering of
its own".

---

## Log only

- **L1.** `GAME_DESIGN.md`'s arena row still says "Since Task 22 the arena is the only thing in
  Workspace"; `Workspace.Boars` (`src/server/Boar/Body.luau`, `Body.ensureFolder`) and
  `Workspace.WeaponEffects` (`src/client/Weapon/Effects.luau`, `Effects.folder`) both contradict it.
  Already `TASKS.md` row 24a(d). Every child of Workspace does have an owner row; only the sentence is
  stale.
- **L2.** `src/client/Camera/Rig.luau`, `Rig.acquire`, returns `true, err` when a `PlayerModule` is
  present and `disableStockCameras` fails, so `Camera.start` warns "no stock PlayerModule to disable
  (<error>)" — the wrong sentence for the one case that matters. Already `TASKS.md` row 26a(a).
- **L3.** Owner-table drift against `docs/design/camera.md` §11, both harmless and both one word:
  `GAME_DESIGN.md`'s Camera row omits `CameraSubject` from the properties it names, and its Cursor row
  omits `Mouse.Icon`. The design names both; so does `Cursor.luau`'s header. Nothing writes either
  today.
- **L4.** `docs/design/boar-ai.md` §2 and its closing section still describe `Workspace.Baseplate` and
  the default `SpawnLocation` as live Studio content; they were archived in Task 22. Recorded in
  `TASKS.md` row 22 item 4 as "for the next regeneration of the design" — repeated here only so the
  regeneration list is in one place, with L5 and L6.
- **L5.** `docs/design/shotgun.md` is stale in two places the code has moved past: §12 on ammo
  selection (Karen's X rule; the deltas are in `reviews/task-24/DESIGN_DELTA.md`) and §13.3 on the
  scenario shape (`TASKS.md` row 24a(e)).
- **L6.** `docs/design/camera.md` §8's `VIEWMODEL_HIP_OFFSET`/`VIEWMODEL_AIM_OFFSET` differ from
  `src/client/Camera/Config.luau`, and §4.3 step 8's body-hide predicate has one term fewer than
  `Camera.update`'s `state.mode ~= "Dead" and state.blend > Config.BODY_HIDE_BLEND`. Both deviations are
  measured, explained at the site, and recorded (`TASKS.md` row 26 and row 26a(b)). This is what the
  design asked for ("the screenshot and Karen decide it"); it belongs in the design at the next
  regeneration.
- **L7.** `docs/research/INDEX.md`'s camera row links
  `2026-09-24-shotgun.md#addendum-2026-09-25-task-26-the-camera`; the heading is "Addendum, 2026-09-25
  (Task 26): the camera, and what sources 4-5 meant in practice", so the anchor is truncated and the
  link lands at the top of the file.
- **L8.** Rule 1 for the camera is satisfied by an addendum to the shotgun note whose own text says it
  "records only what **building** it measured", with the 3+ sources, licences and maintenance statuses
  living in `docs/design/camera.md` §7 — an Architect-owned file. That is a reasonable division and the
  Director accepted it (`TASKS.md` row 26); recorded here so a later audit does not re-raise it as a
  rule-1 gap. If it is ever to be tightened, the rule to write down is "the design may hold the sources
  when the Builder's note confirms each one", which §13 of that design already asks the Builder to do.
- **L9.** A fabricated DevForum URL reached a merged commit and was caught only in review round 3
  (`TASKS.md` row 26a). Nothing in the repo checks that a cited link exists, and the repo is public.
  The three citations of that post (`src/client/Camera/Viewmodel.luau` header,
  `docs/design/camera.md` §7 D, `docs/research/2026-09-24-shotgun.md` source 4) now agree with each
  other; whether the URL resolves is in *Not verified*. A link check is tooling and frozen
  (`ROADMAP.md` speed rule 1); the standing control is rule 1's "confirm each URL", which
  `docs/design/hit-zones.md` §3.4 and `docs/design/camera.md` §13 both hand to the Builder explicitly.
- **L10.** The harness cannot address a second client: `tools/studio_mcp.py` passes a `datamodel_type`
  that is only ever `"Edit"`, `"Server"` or `"Client"` (`Studio.query`, `Studio.send_input`) and
  `QUERY_REPORT["client"]` reads `Players.LocalPlayer`. `docs/design/drive.md` §12.6 states this
  plainly and makes every drive rule testable without a second client. That is Task 30's own subject
  matter, not a hole it inherits; logged so the two are not confused.
- **L11.** `src/server/SyncCheck.server.luau` still runs in every live server and is on the strip list
  (`TASKS.md` row 2). Unchanged since audit-001 R1.
- **L12.** `tools/studio_mcp.py`, `load_scenarios`: "A bad file is an error, a missing one is not", and
  `run_test` prints "no tests/client/input_scenarios.txt: nothing to replay". I traced the deletion
  case: `tests/client/input_driving.spec.luau`'s first `it` asserts `scenarioError == nil` and
  `InputReady.ready("input_driving")` is never called, so the run is red either way. Documented
  behaviour, no silent pass; recorded because "not a failure" reads like one.
- **L13.** `src/client/Camera/init.luau`, `stats.cursorReasserts`, is initialised to 0 and never
  incremented — `Camera.stats()` overwrites it from `Cursor.stats().reasserts`. Dead field, correct
  value.

---

## Not verified

- **Anything requiring Roblox Studio.** No Studio in this session (`.agent-evidence/INDEX.md`). Every
  claim about what the harness *would* do is read from `tools/studio_mcp.py`; every claim about what is
  on screen is read from code and from the Builder's own notes in `TASKS.md`. In particular **F1 is
  reasoning about replication order, not an observation**: I assert that the Tool's `Handle` reaches the
  client's character after the camera's first render step with that character, because the server
  grants it on `CharacterAdded`. The Task 26 screenshots are reported as showing the body hidden
  correctly; if that was a life in which the Tool arrived first, or one taken after a respawn, both
  facts are consistent. The check that settles it is one assertion, named in F1.
- **Must-fix 1's timing** rests on the harness running exactly one player (read from
  `Studio.set_play` and `QUERY_REPORT`) and on `docs/design/drive.md`'s stated defaults. It has not
  been run, because `src/server/Match/` does not exist yet. If the Director has already decided to give
  the harness two players before 1.7a, the finding is answered by that decision and the design still
  needs to say so.
- **Must-fix 2's exploitability.** That the detector misses a rotation-only write is certain from
  `Rig.apply`'s source. Whether any writer in the place performs one today is not: this place has no
  `PlayerScripts.PlayerModule` (`TASKS.md` row 26, measured by the Builder), so the finding is about the
  guard, not about a live second writer.
- **The camera and viewmodel source URLs**, and the licence and maintenance status of every external
  source cited in `docs/design/camera.md` §7, `docs/design/hit-zones.md` §10 and
  `docs/design/drive.md` §16. No network. L9 is about the process, not about a specific broken link.
- **CI status for this commit.** No CI output in `.agent-evidence/`.
- **Anything needing git.** No log, no diff, no prior-audit text was precomputed for this run
  (`.agent-evidence/INDEX.md` lists six files); audit-001 and audit-002 are on the branch and I read
  both from disk, which is what audit-002 must-fix 4 asked for. I could not check whether anything was
  reverted between commits, or read `reviews/task-25/BRIEF.md`'s inputs against what was built beyond
  what `TASKS.md` records.
- **DevPackages / TestEZ integrity.** `DevPackages/` is absent from the worktree
  (`.agent-evidence/INDEX.md`), so the `devpackages.sha256` comparison could not be exercised and the
  TestEZ behaviour every count in every report depends on was read only through `tests/TestKit.luau`.
- **The harness's own checks.** Not run. The 26/26 figures quoted in `TASKS.md` rows 24 and 26 were not
  recounted against `run_test`.
