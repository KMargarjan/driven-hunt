# Review request

Written by the Builder for `tools/review.sh`. The format is below; the script parses the first three lines.

Round: 4
Base: `7399585`
Code commit: `fbe1d6049da35f75675d532ee77d0c4f6992a235`

## Task

**Tasks 17 and 18 together, as one unit** (Director decision 2026-09-25, `ESCALATE.md`): the
grey-box test arena (ROADMAP 1.1) and the boar AI (ROADMAP 1.2). `Base:` is `origin/main`, so the
diff is both tasks.

`Round: 4` continues Task 18's count — rounds 1–3 reviewed the boar code with **nothing ever
executed**, because `rojo serve` was down. `DIRECTOR_MAX_ROUNDS=5` is authorised for this run only.

**What is different this round, and it is the whole point:** Karen connected Studio on the morning of
2026-09-25, and **this code has now actually run**. There is a real harness line, real screenshots,
and three of my specs were wrong in ways no amount of reading had found. Please review the *fixes
that came out of running it* at least as hard as the original code.

## Process

1. Research note (rule 1) `docs/research/2026-09-24-boar-ai.md`, then Architect design
   `docs/design/boar-ai.md` (`ARCH_RESULT.md` = `PASS`), then the code. Task 17 has neither by
   Director decision: throwaway geometry replaced by the Milestone 2 map generator.
2. Three review rounds with no execution. Then the harness, three times.
3. No Architect audit (`ROADMAP.md` speed rule 3).

## What changed

| File | What it is |
|---|---|
| `src/server/TestArena.luau` | Task 17. One module owns `Workspace.TestArena`; all dimensions in one `LAYOUT` table |
| `src/server/ArenaBoot.server.luau` | its boot line |
| `src/server/Boar/Brain.luau` | the boar's decisions. Pure |
| `src/server/Boar/Body.luau` | the only writer of boar Instances |
| `src/server/Boar/init.luau` | the owner: `CONFIG`, `defaultWorld`, `newRuntime`, the Heartbeat loop |
| `src/server/BoarBoot.server.luau` | its boot line, plus one assertion about the arena |
| `tests/server/test_arena.spec.luau` | 4 assertions on the arena |
| `tests/server/boar_brain.spec.luau` | 20 assertions, no physics |
| `tests/server/boar_body.spec.luau` | one real simulated boar, plus a real-arena pathfinding check |
| `GAME_DESIGN.md` | two owner rows |
| `docs/research/2026-09-24-boar-ai.md`, `docs/design/boar-ai.md`, `ARCH_RESULT.md` | note (mine) and design (the Architect's) |
| `TASKS.md`, `ESCALATE.md`, `CLAUDE.md` | paperwork; `CLAUDE.md` gains the branch-switch/rojo line |

## Claims

Files and symbols, not line numbers.

### It runs

1. **The harness passes on a clean tree at the code commit.**
   `[harness] PASS: 24/24 checks @ fbe1d6049da35f75675d532ee77d0c4f6992a235 (clean tree)`,
   **39 server + 4 client assertions across 5 spec files**. See `## Harness`.
2. **The arena is right, as measured.** `test_arena.spec` asserts on what a player meets in
   `Workspace`, with its own copy of the numbers: one folder; a 400 × 400 ground plate whose top
   surface is at y = 0 and which is centred; 6–10 anchored blocks whose **whole footprint** is on the
   plate and which stand on it; exactly one `SpawnLocation` on the ground inside the plate. All green.
3. **The boar is right, as measured.** `boar_body.spec` spawns one real physically-simulated boar and
   asserts through the public interface only: exactly one unanchored Part in the runtime's folder;
   `GetNetworkOwner() == nil`; a `LinearVelocity` and an `AlignOrientation`; it lands and idles below
   `WANDER_SPEED * 1.5` flat; on a threat it reaches half sprint speed within 1 s, stays upright
   (`UpVector.Y > 0.9`) and **grows the flat gap by ≥ 20 studs**; it despawns exactly once as
   `escaped` past the exit line and the `Despawned` record carries `id`, `reason`, `position` and
   `aliveFor`. All green.

### The three things running it found

4. **`boar_brain`'s acceleration and turn-rate tests contradicted a feature they neighbour.** Both
   held the boar at a **fixed position for 300 steps**. Standing still for 2 × `STUCK_TIME` is by
   definition stuck, so `Brain:step`'s anti-stuck branch turned it 90° in one tick — which is exactly
   what the neighbouring "turns hard when it is stuck" test asserts. Fixed by one shared
   `worstDeltas` helper that **circles** the boar (the same movement the round-2 control case used),
   so it is never stuck and never despawns, and by measuring the **worst** delta over the run rather
   than asserting per-step. Verify: `boar_brain.spec`'s `worstDeltas`, and the two tests that use it.
5. **The 1e-6 tolerance was tighter than float32 arithmetic can be.** Measured in harness run 2:
   worst acceleration overshoot **1.9e-6**, worst turn overshoot **3.8e-8**. `Vector3` components are
   float32. Fixed by one `EPSILON` constant applied to **every** arithmetic assertion in the spec,
   not only the two that failed, set to 1e-4 — ~50× the worst measured, still ~10⁴× tighter than the
   quantities under test. Verify: `EPSILON` in `boar_brain.spec` and its uses.
6. **The pathfinding assertion was asserting a property of Roblox's navmesh, not of this code.**
   `pathFailures == 0` failed with 31, then 36 of 37. Instrumenting `defaultWorld().requestPath` to
   record *why* gave `Enum.PathStatus.NoPath`, on the spec's own plate floating at y = 500 in an
   otherwise empty region. An Edit-mode probe with the **same** `CONFIG.AGENT` parameters settles it:

   | from → to | status | waypoints |
   |---|---|---|
   | (0,0,0) → (0,0,−190) | `Success` | 53 |
   | (0,**1.5**,0) → (0,0,−190) | `Success` | 53 |
   | `CONFIG.spawnPoint` → exit line | `Success` | **54** |
   | (0,**500**,30) → (0,500,−40) | `NoPath` | 0 |

   Fixed in two parts, because deleting the assertion would have lost the signal the design wanted:
   the plate test now asserts what it **can** prove there — the boar asked for paths, and when they
   failed it still sprinted, escaped and despawned on the Reynolds fallback alone — and **requires
   the reason to be `NoPath`**, so any other failure is new and fails. And a **new test routes across
   the real arena at y = 0 through the production world** and requires a path, which is the assertion
   that would catch the navmesh being genuinely unusable for a 2 × 3 × 5.5 agent. Verify:
   `boar_body.spec`'s last two tests, and `lastPathProblem` in `Boar.defaultWorld`.

### Ownership and structure

7. **One owner each, and the private parts are private in production.** `TestArena` is the only
   writer of `Workspace.TestArena`; `Boar` (`src/server/Boar/init.luau`) is the only writer of
   `Workspace.Boars` and the only production caller of `Brain.new`, `Body.create`, `Body.drive`,
   `Body.destroy` and `Body.ensureFolder`. Verify: `grep -rn "Brain\.new\|Body\." src tests` — outside
   `init.luau` the hits are the definitions in `Brain.luau`/`Body.luau` plus **two** calls in
   `boar_brain.spec` through the deliberate `Boar.Brain` export. `GAME_DESIGN.md` has both rows and
   says so.
8. **`Brain` is pure.** No `game:GetService`, no `task.`, no `Instance`, no `os.`; the only randomness
   is the injected `Random`. That is what lets `boar_brain.spec` run 10 000 steps with no physics.
   Verify: `grep -n "game:\|Instance\|task\.\|os\." src/server/Boar/Brain.luau` matches only line 1,
   the header comment's own word "Instances".
9. **Neither system touches Studio content.** Nothing references `Workspace.Baseplate` or the default
   `SpawnLocation`; `Body.destroy` destroys only the Part it made; `Body.ensureFolder` returns an
   existing folder untouched. Verify:
   `grep -rn "Baseplate\|SpawnLocation" src` returns exactly three lines, all in `TestArena.luau`:
   two header comments (a docs link, and the line saying the place's default `Baseplate` and
   `SpawnLocation` are left exactly as they are) and one `Instance.new("SpawnLocation")` creating
   **its own** `ArenaSpawn`. No code reads or writes either default.
10. **`BoarBoot` fails loudly if the arena changes.** It asserts `TestArena.LAYOUT.ground.span` and
    `.top` against `Boar.CONFIG.field` and names the file to edit. `Boar` never requires `TestArena`:
    the rectangle is data.
11. **The threat test is one function.** `CONFIG.isThreat(player)`, called only by
    `defaultWorld().threats`. `Brain` never sees a `Player` — it gets `{ id, position }` records,
    which is what lets a spec place a fake threat as a `Vector3`.

### Rule 5

12. **Three play-time screenshots were captured through MCP and I inspected them.** What they show is
    in `## Screenshots` below, including **one thing that is green in the tests and wrong on screen**.

## Harness

```
[harness] PASS: 24/24 checks @ fbe1d6049da35f75675d532ee77d0c4f6992a235 (clean tree)
```

Run 2026-09-25 on this branch, exit 0. `[tests:server] PASS: 39 passed, 0 failed, 0 skipped,
0 errors, 4 spec files`; `[tests:client] PASS: 4 passed, …, 1 spec files`. Only paperwork changed
after the code commit — `ESCALATE.md`, `TASKS.md`, `REVIEW_REQUEST.md` — see
`.agent-evidence/request-only-diff.txt`, which will show `ESCALATE.md`/`TASKS.md` as well as this
file. That is the git-workflow step 4 paperwork set, not a code change, and it is deliberate: the
Director asked for the decisions and the findings to be recorded before the review.

## Screenshots (rule 5)

Captured during **Play** through `screen_capture`, at three camera positions, and **inspected**.
A correction worth recording: my first attempt reported "capture returned empty" — that was my own
client discarding the image, because `studio_mcp.Studio._call` joins only `text` content blocks.
Using the raw RPC returns a JPEG. **Play-time capture works**, which is new information against
`TASKS.md` row 7.

- **The boar is real and behaves.** It rests at y ≈ 1.5 (`groundY + BODY_SIZE.Y/2`), wanders while
  idle, and reads as a 2 × 3 × 5.5 box. **Its sides read almost black**; only the top face shows the
  intended `Color3.fromRGB(90, 80, 70)`. Not a bug — a lighting/colour choice for Karen.
- **The arena's cover blocks and spawn pad are all there**, and the low walls and tall pillars are
  distinguishable at distance, which is what they are for.
- **The floor is wrong, and the tests cannot see it.** The arena's ground plate is coplanar with
  `Workspace.Baseplate` (2048 × 16 × 2048, top also at y = 0), and it **loses the depth test over
  half its area**: the 400 × 400 square renders as a **triangle**, split along the quad's diagonal,
  with the Baseplate showing through the other half. Two captures 1.5 s apart are **byte-different
  only where the boar moved** — the diagonal is identical — so it is **stable, not flickering**.
  I did not fix it: the fix is either Karen deleting `Workspace.Baseplate` (Studio content, hers) or
  moving the arena's surface off y = 0, which changes a documented contract the boar depends on.
  Recorded in `TASKS.md` row 17.
- **Two `SpawnLocation`s exist during Play** — the arena's `ArenaSpawn` at z = +170 and the default
  at the origin — confirmed both by a scene query (`spawns: 2`) and visually. Karen's call.

## Could not verify

- **`Path.Blocked` has never fired.** The `consumed() + 2` index arithmetic in `Runtime:_requestPath`
  is still unexercised: on the spec plate pathfinding returns `NoPath`, and in the arena the boar had
  no threat, so it never fled and never pathed under load. `stats().pathBlocked` exists to make it
  visible when it does.
- **Nothing has been tested with a real player.** No character has ever been a threat; every threat
  in every test is an injected `{ id, position }` record. The `isThreat` → `threats` path through
  `Players:GetPlayers()` and `character.PrimaryPart` is unexecuted.
- **The screenshots are mine, not Karen's**, and "the sides look almost black" is my judgement of a
  JPEG, not a measurement.
- **Whether the arena's floor problem affects gameplay at all** — it is a rendering artefact; parts,
  collisions and pathfinding all behave. It may look like nothing from a player's eye height. I only
  saw it from high oblique angles.
- **`Runtime:destroy` and `maxBoars`** are never exercised by a spec.
- **CI** is unchecked: no `gh` on this machine.
