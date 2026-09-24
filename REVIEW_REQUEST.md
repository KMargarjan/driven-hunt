# Review request

Written by the Builder for `tools/review.sh`. The format is below; the script parses the first three lines.

Round: 1
Base: `e81eb4d`
Code commit: `8a6edd05a3e03e7de4485c9282e406c51b4d16f3`

## Task

TASKS.md #18, ROADMAP step 1.2: **the boar AI, grey box.** One boar that idles, flees a threat,
routes to the exit edge around cover, and despawns with a signal. The first AI in the project.

**Please read this first: there is no harness run, and there cannot be one.** `rojo serve` crashed
during Task 17 and only Karen can press Connect, which she will do at ~09:00 (`ESCALATE.md`,
"NEEDS KAREN · `rojo serve` crashed"). The Director dispatched this task in "no-Studio mode" and
asked explicitly that the review go ahead anyway and judge **the code and the specs**. So:

- **A `PASS` here means "PASS pending harness"**, not "this works". Nothing in this task has ever
  executed — not the module, not either spec.
- The `## Harness` section below says N/A with that reason, as the format allows.
- Please weigh the specs as carefully as the code: they are the only thing that will catch this when
  it does finally run, and a wrong spec is worse than none (`docs/PROJECT_CONTEXT.md`, "Its own test
  harness was wrong as often as the game").

`Base:` is `e81eb4d`, the head of `task-17-test-area`. This branch is **stacked** on Task 17 because
Task 17 is not on `main` yet, so the diff is Task 18 only.

## Process followed

1. **Research note first** (rule 1): `docs/research/2026-09-24-boar-ai.md`, 5 sources with licence
   and maintenance status, numeric targets, the pattern adopted, and a written reason for not
   borrowing SimplePath (rule 2).
2. **Architect design second**: `tools/architect.ps1 design boar-ai` → `docs/design/boar-ai.md`,
   `ARCH_RESULT.md` = `PASS`. The code is built to it.
3. **Then the code.** No Architect audit this task (`ROADMAP.md` speed rule 3).

## What changed

| File | What it is |
|---|---|
| `docs/research/2026-09-24-boar-ai.md` | the note, plus a dated addendum (see claims 12–14) |
| `docs/research/INDEX.md` | its row |
| `docs/design/boar-ai.md`, `ARCH_RESULT.md` | written by `tools/agents.py`, not by me |
| `src/server/Boar/Brain.luau` | the decisions. Pure |
| `src/server/Boar/Body.luau` | the only writer of boar Instances |
| `src/server/Boar/init.luau` | the owner: `CONFIG`, `defaultWorld`, `newRuntime`, the Heartbeat loop |
| `src/server/BoarBoot.server.luau` | the boot line, and one assertion about the arena |
| `tests/server/boar_brain.spec.luau` | 17 assertions, no physics, no waiting |
| `tests/server/boar_body.spec.luau` | one real simulated boar on its own plate |
| `GAME_DESIGN.md` | the owner row |
| `TASKS.md` | row 18, and a reminder that 17 and 18 both still need a harness run and a screenshot |
| `CLAUDE.md` | one line: a large branch switch alone crashed `rojo serve` 7.7.0 (Task 17) |

## Claims

Each names a file and a symbol. No line numbers (CLAUDE.md loop step 4).

1. **One owner for boar state, and `Brain`/`Body` are private to it.** `Boar.newRuntime` in
   `src/server/Boar/init.luau` is the only thing that constructs a `Brain` or calls `Body.create`,
   `Body.drive` or `Body.destroy`. Verify: `grep -rn "Body\.\|Brain\.new" src tests` — outside
   `init.luau` the only hits are `Boar.Brain` (the deliberate export, used by `boar_brain.spec`) and
   comments. `GAME_DESIGN.md` has the matching row.
2. **Nothing but this system writes in Workspace, and it never deletes anything it did not create.**
   `Body.ensureFolder` returns an existing folder untouched or makes one; `Body.destroy` destroys
   only the Part it made and never the folder; `Runtime:destroy` destroys only its own boars.
   Nothing references `Workspace.TestArena`, the default `Baseplate` or the default `SpawnLocation`.
   Verify: `grep -rn "Workspace\|workspace" src/server/Boar src/server/BoarBoot.server.luau`.
3. **`Brain` is pure.** No `game:GetService`, no `task.`, no `Instance`, no `os.`, no `wait`, and the
   only randomness is the injected `Random`. Verify:
   `grep -n "game:\|Instance\|task\.\|os\.\|math.random" src/server/Boar/Brain.luau` matches only
   line 1, the header comment's own word "Instances". This is what lets `boar_brain.spec` run
   10 000 steps with no physics and no Studio.
4. **The reaction requirement is met by construction and asserted.** `Brain:step` accumulates
   `_sinceSense` and senses every `CONFIG.SENSE_INTERVAL` (0.2 s), so the worst case is 0.2 s plus
   one frame against the Director's 0.5 s. `boar_brain.spec`, "enters FLEE within 0.5 s…", asserts it
   against its own `REACTION_LIMIT = 0.5` constant, not against `CONFIG`.
5. **The threat test is exactly one function.** `CONFIG.isThreat(player)` in `src/server/Boar/init.luau`,
   called only by `defaultWorld().threats`. `Brain` never sees a `Player`: it gets
   `{ id, position }` records. Verify: `grep -rn "isThreat\|Players" src` — `Players` appears only in
   `init.luau`'s `defaultWorld`.
6. **The route heads for the exit line, not just away.** `Brain._routeTarget` always returns
   `Vector3.new(targetX, field.groundY, field.exitZ)`. `boar_brain.spec` asserts `target.Z` equals the
   exit line, that `targetX` is inside the bounds minus `EDGE_MARGIN`, and that it is on the opposite
   side in X from the threat.
7. **Despawn fires once and only once, and carries what a score system needs.**
   `Brain` sets `_despawned` so `intent.despawn` is true on one step only; `Runtime:_despawn` fires
   the `BindableEvent` with `{ id, reason, position, aliveFor }` and removes the entry.
   `boar_brain.spec` asserts the once-only behaviour directly; `boar_body.spec` asserts
   `#records == 1` and `stats().despawned == stats().spawned`.
8. **The body is unanchored and server-owned.** `Body.create` sets `Anchored = false` and then
   `part:SetNetworkOwner(nil)` after parenting. It must be unanchored: the Roblox docs say "the
   server always owns anchored BaseParts and you cannot manually change their ownership", so the call
   errors on an anchored part. `boar_body.spec` asserts both.
9. **Pathfinding never yields inside a step.** `defaultWorld().requestPath` wraps
   `ComputeAsync` in `task.spawn` and calls back on a later frame; `Runtime:_requestPath` keeps at
   most one request in flight per boar (`entry.pending`) and drops a late reply for a despawned boar
   (`entry.dead`). `Runtime:step` itself calls nothing that yields.
10. **A failed path degrades visibly, not silently.** `Brain._fleeDirection` falls back to Reynolds
    flee blended toward the route target, so the boar never freezes; `Runtime._stats.pathFailures`
    counts it, and `boar_body.spec` asserts `pathFailures == 0` and `pathRequests > 0`, so a
    permanent fallback fails the run instead of looking fine.
11. **`BoarBoot` fails loudly if the arena changes.** It asserts
    `TestArena.LAYOUT.ground.span == span` and `.top == field.groundY` and names the file to edit.
    `Boar` itself never requires `TestArena` — the rectangle is data in `CONFIG.field` — so swapping
    in the Milestone 2 map means changing one table, not the state machine.
12. **Correction to the design, 1 of 2: `onExitSide`.** `docs/design/boar-ai.md` §5 writes
    `onExitSide = (c.Z - exitZ) * sign(exitZ - position.Z) > 0`. That is **false exactly when the
    threat is in the way**: boar at z = 0, exit at z = −190, threat at z = −60 gives
    `130 * −1 = −130`, not > 0 — so the doubled side-bias would never apply in the one case it
    exists for, and the design's own spec assertion 4 would fail. `Brain._routeTarget` uses
    `(centroid.Z - position.Z) * (field.exitZ - position.Z) > 0`. The arithmetic is in a comment at
    the site, in the research-note addendum §3, and asserted by `boar_brain.spec`, "never routes
    through a threat standing between the boar and the exit".
13. **Correction to the design, 2 of 2: the home pull.** §5 writes
    `heading = unit(heading + toHome * HOME_PULL)`. With the heading pointing exactly away from home
    that is `(−toHome) + 0.6·toHome = −0.4·toHome`, whose unit vector **is the original heading** —
    the boar walks away for ever and only the wander jitter can rescue it, which the design's own
    assertion 8 does not tolerate. `Brain._senseIdle` rotates the heading toward home by at most
    `HOME_PULL` radians per sense tick, so `HOME_PULL` is now an angle; `CONFIG` says so.
    `boar_brain.spec`, "wanders without leaving the home area", covers it over 120 simulated seconds.
14. **The design's scale correction is carried into the note and the numbers.** The note originally
    assumed 1 stud ≈ 1 m. Roblox's units page states 1 stud = 28 cm
    (<https://create.roblox.com/docs/physics/units>), so 40 km/h = 39.7 studs/s and
    `SPRINT_SPEED = 38` is physically right rather than a compromise; the body is
    `Vector3.new(2, 3, 5.5)`. Addendum §1. **The design's URL for that source
    (`/docs/art/modeling/roblox-units`) is a 404**; the working one is in the addendum table.
15. **Every number is in one table.** `Boar.CONFIG` in `src/server/Boar/init.luau`. Verify: no numeric
    literal outside it in `Brain.luau` or `Body.luau` except `0`, `1`, `2`, `1e-6` and the
    `math.pi / 2` stuck-turn, all of which are structural rather than tunable.
16. **No client code, no RemoteEvent, no `Humanoid`, no per-frame `CFrame` write.** Verify:
    `grep -rn "Remote\|Humanoid\|LocalPlayer" src/server/Boar src/server/BoarBoot.server.luau`
    matches exactly one line, the comment on `CONFIG.TROT_SPEED` explaining why it must exceed the
    default `Humanoid.WalkSpeed`; there is no code hit. The only `CFrame` writes are `Body.create`'s
    initial placement and
    `Body.drive`'s `AlignOrientation.CFrame`, which is a constraint goal, not a position write.
17. **Lint, format and build are clean.** `selene src`, `selene --config tests/selene.toml tests`,
    `stylua --check src tests` and `rojo build -o build/place.rbxl` all pass locally — the same
    commands CI runs. See `.agent-evidence/lint-selene.txt`, `lint-stylua.txt`, `rojo-build.txt`.
18. **`src/server/Boar/` is the repo's first folder module** (`init.luau` with siblings). The mapping
    is documented in CLAUDE.md's file-types table and `rojo build` accepts it, but no other folder
    module exists in the repo, so this is the first exercise of it. The design names the fallback
    (three flat files) if Rojo or the harness mishandles it.

## Harness

**N/A — Studio is unreachable.** `rojo serve` crashed during Task 17 (the known Rojo 7.7.0 bug, on a
large branch switch); there is no `rojo.exe` and nothing on port 34872, and reconnecting needs
Karen's Connect click, which cannot happen before ~09:00. The Director's dispatch for this task says
to run the review anyway and treat a `PASS` as "PASS pending harness". `ESCALATE.md` has the exact
clicks. `TASKS.md` records that **Tasks 17 and 18 both still owe a harness run and a screenshot**.

## Could not verify

- **Nothing in this task has ever run.** Not `Brain`, not `Body`, not `BoarBoot`, not either spec.
  Every behavioural claim above is a claim about code as written, not an observation. The specs have
  never been executed, so I do not know that they pass — or even that they load.
- **No screenshot (rule 5).** A moving grey box is a visual change, so rule 5 applies and is **not**
  met. `screen_capture` over MCP is Edit-mode only and the boar exists only during Play (Task 7 is
  the blocker). Karen's screenshot is the intended evidence. I am not claiming the boar looks right;
  I have never seen it.
- **The mover configuration is unmeasured.** The code uses the design's first choice,
  `LinearVelocity` with `VelocityConstraintMode.Plane`. If Plane mode does not leave Y free on the
  pinned engine, the boar will hover or sink; the design's `ForceLimitMode`/`MaxAxesForce` fallback
  is deliberately **not** in the code, because guessing between two untested options helps nobody.
- **Whether `PathfindingService` returns a usable path** on the arena or on the spec's elevated
  plate is unknown. Claim 10 is the mitigation, not a verification.
- **Whether the specs' timings hold on this machine.** `boar_body.spec` waits up to 1 s for sprint
  speed and up to 8 s for the despawn. Those are guesses about physics I have not watched.
- **Source 10 (Buckland, *Programming Game AI by Example*) is not verified online.** I have no copy.
  It is cited for a pattern that sources 1 and 3 already carry, so nothing rests on it alone.
- **CI status.** No `gh` on this machine. The Director checks it.
- **`Brain:debug()` is used by the spec's probe assertion.** It is a debug accessor being leaned on
  as a test seam; if you think that is the wrong shape, say so — it would be cheap to change now.
