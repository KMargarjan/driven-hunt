# Review request

Written by the Builder for `tools/review.sh`. The format is below; the script parses the first three lines.

Round: 5
Base: `7399585`
Code commit: `b6cf3dec736347f65c42ad3d05129d302389349a`

## Task

**Tasks 17 and 18 together, as one unit** (Director decision 2026-09-25, `ESCALATE.md`): the
grey-box test arena (ROADMAP 1.1) and the boar AI (ROADMAP 1.2). `Base:` is `origin/main`, so the
diff is both tasks.

`Round: 5` continues Task 18's count. Rounds 1–3 reviewed the boar with **nothing ever executed**,
because `rojo serve` was down. Karen connected Studio on 2026-09-25, and rounds 4 and 5 were the
first with real evidence. `DIRECTOR_MAX_ROUNDS=5` was authorised for this run only, so **round 5 was
the last**: this document records its outcome for the Director, and `ESCALATE.md` carries what is
left unreviewed.

## Process

1. Research note (rule 1) `docs/research/2026-09-24-boar-ai.md`, then Architect design
   `docs/design/boar-ai.md` (`ARCH_RESULT.md` = `PASS`), then the code. Task 17 has neither by
   Director decision: throwaway geometry, replaced by the Milestone 2 map generator.
2. Three review rounds with no execution. Then the harness **seven times** across rounds 4–5, the
   last on the code commit.
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
| `tests/server/boar_brain.spec.luau` | 24 assertions, no physics |
| `tests/server/boar_body.spec.luau` | 8 assertions: one real simulated boar, plus a real-arena routing check |
| `GAME_DESIGN.md` | two owner rows |
| `docs/research/2026-09-24-boar-ai.md` | the note (mine), with the addendum rewritten now everything has run |
| `docs/design/boar-ai.md`, `ARCH_RESULT.md` | the Architect's, untouched by me |
| `TASKS.md`, `ESCALATE.md`, `CLAUDE.md` | paperwork; `CLAUDE.md` gains the branch-switch/rojo line and the step-4 reconciliation |

## Claims

Files and symbols, not line numbers. **One continuous numbering** — round 5's finding 3 was right
that reusing numbers made every cross-reference here ambiguous.

### It runs

1. **The harness passes on a clean tree at the code commit.**
   `[harness] PASS: 24/24 checks @ b6cf3dec736347f65c42ad3d05129d302389349a (clean tree)`, **39 server + 4 client assertions across
   5 spec files** (sync 3, test_arena 4, boar_brain 24, boar_body 8). See `## Harness`.
2. **The arena is right, as measured.** `test_arena.spec` asserts on what a player meets in
   `Workspace`, with its own copy of the numbers: one folder; a 400 × 400 ground plate whose top
   surface is at y = 0 and which is centred; 6–10 anchored blocks whose **whole footprint** is on the
   plate and which stand on it; exactly one `SpawnLocation` on the ground inside the plate.
3. **The boar is right, as measured.** `boar_body.spec` spawns one real physically-simulated boar and
   asserts through the public interface only: exactly one unanchored Part in the runtime's folder;
   `GetNetworkOwner() == nil`; a `LinearVelocity` and an `AlignOrientation`; it lands and idles below
   `WANDER_SPEED * 1.5` flat; on a threat it reaches half sprint speed within 1 s, stays upright
   (`UpVector.Y > 0.9`) and **grows the flat gap by ≥ 20 studs**; it despawns exactly once as
   `escaped` and the `Despawned` record carries `id`, `reason`, `position` and `aliveFor`.

### What running it found

4. **Two `boar_brain` tests contradicted a feature they neighbour.** Both held the boar at a **fixed
   position for 300 steps**. Standing still for 2 × `STUCK_TIME` is by definition stuck, so the
   anti-stuck branch turned it 90° in one tick — exactly what the neighbouring "turns hard when it is
   stuck" test asserts. Fixed by one shared `worstDeltas` helper that **circles** the boar, so it is
   never stuck and never despawns, and by measuring the **worst** delta over the run rather than
   asserting per step. Verify: `worstDeltas` in `boar_brain.spec` and its two callers.
5. **The 1e-6 tolerance was tighter than float32 arithmetic can be.** Measured: worst acceleration
   overshoot **1.9e-6**, worst turn overshoot **3.8e-8**; `Vector3` components are float32. Fixed by
   one `EPSILON` = 1e-4 — ~50× the worst measured, ~10⁴× tighter than the quantities under test —
   applied to **every assertion that bounds a measured quantity against a `CONFIG` limit**. Verify:
   `EPSILON` in `boar_brain.spec` and its four uses. **One tolerance is deliberately tighter:** the
   determinism test's `1e-9`, because two brains with the same seed are bit-identical, so it asserts
   determinism rather than bounding a physical quantity and float32 error does not enter. Round 5's
   finding 4 was right that "every arithmetic assertion" was false; the reason is now at that line.
6. **The pathfinding assertion was asserting a property of Roblox's navmesh, not of this code.**
   `pathFailures == 0` failed with 31, then 36 of 37. Instrumenting `requestPath` gave the reason:
   `Enum.PathStatus.NoPath`, on the spec's own plate floating at y = 500 in an otherwise empty
   region. An Edit-mode probe with the same `CONFIG.AGENT` parameters:

   | from → to | status | waypoints |
   |---|---|---|
   | (0,0,0) → (0,0,−190) | `Success` | 53 |
   | (0,**1.5**,0) → (0,0,−190) | `Success` | 53 |
   | `CONFIG.spawnPoint` → exit line | `Success` | 54 |
   | (0,**500**,30) → (0,500,−40) | `NoPath` | 0 |

   **Round 4's finding 1 was right that this table proves less than I claimed.** It was taken in
   **Edit** mode, where no server script has run, so `Workspace.TestArena` did not exist and the
   first three rows were measured over the bare default Baseplate — 54 waypoints for a 210-stud route
   is a straight line, i.e. `WallWest` was not in the navmesh, because the arena was not there. The
   table shows only what it was taken for: pathfinding works at y = 0 and not at y = 500.
7. **So the arena test was rewritten to prove the thing that matters, and now does.** It waits for
   `Workspace.TestArena`, requires `WallWest` to exist, then requires the route from
   `CONFIG.spawnPoint` to the exit line to **leave the straight line by more than 15 studs** and to
   put no waypoint inside the wall's footprint. Measured green: **`arena route: 57 waypoints, max
   lateral 22.5`** — the boar routes *around* an 80-stud wall. A straight line cannot pass this.
8. **Every unanswerable request is counted, not just the last.** `lastPathProblem` was a single
   overwritten slot, so a rarer failure was discarded by the next `NoPath`.
   `defaultWorld().pathProblems()` now returns reason → count, and the plate test asserts **every**
   reason is `NoPath`. Round 5's finding 1 then caught a **second** hole in it: a `ComputeAsync` that
   returns `Success` with no waypoint past index 1 also produces the silent straight-line fallback,
   and was recorded nowhere. It is now counted as `"success: no waypoints"`, which is what makes
   claim 9's invariant rest on containment rather than on coincidence.
9. **Two counters that look alike count different things, and the spec says which.** Asserting
   `counted == stats.pathFailures` failed 37 vs 36 — the assertion was wrong, not the code.
   `pathProblems` is the **world's** tally of every request it could not answer with usable
   waypoints; `stats.pathFailures` is the **runtime's** tally of those that reached a **live** boar,
   and `Runtime:_requestPath` deliberately drops a reply whose boar has already despawned
   (`entry.dead`). The world records a superset, so the invariant is `world >= runtime`, and that is
   what it asserts, with the reason written at the assertion.

### Ownership and structure

10. **One owner each, and the private parts are private in production.** `TestArena` is the only
    writer of `Workspace.TestArena`; `Boar` is the only writer of `Workspace.Boars` and the only
    production caller of `Brain.new`, `Body.create`, `Body.drive`, `Body.destroy` and
    `Body.ensureFolder`. Verify: `grep -rn "Brain\.new\|Body\." src tests` — outside `init.luau` the
    hits are the definitions in `Brain.luau`/`Body.luau` plus **two** calls in `boar_brain.spec`
    through the deliberate `Boar.Brain` export. `GAME_DESIGN.md` has both rows and says so.
11. **`Brain` is pure.** No `game:GetService`, no `task.`, no `Instance`, no `os.`; the only
    randomness is the injected `Random`. Verify:
    `grep -n "game:\|Instance\|task\.\|os\." src/server/Boar/Brain.luau` matches only line 1, the
    header comment's own word "Instances".
12. **Neither system touches Studio content.** Verify:
    `grep -rn "Baseplate\|SpawnLocation" src` returns exactly three lines, all in `TestArena.luau`:
    two header comments and one `Instance.new("SpawnLocation")` creating **its own** `ArenaSpawn`.
    No code reads or writes either default.
13. **`BoarBoot` fails loudly if the arena changes.** It asserts `TestArena.LAYOUT.ground.span` and
    `.top` against `Boar.CONFIG.field` and names the file to edit. `Boar` never requires
    `TestArena`: the rectangle is data.
14. **The threat test is one function.** `CONFIG.isThreat(player)`, called only by
    `defaultWorld().threats`. `Brain` never sees a `Player` — it gets `{ id, position }` records,
    which is what lets a spec place a fake threat as a `Vector3`.

### Rule 5

15. **Three play-time screenshots were captured through MCP and I inspected them.** See
    `## Screenshots`, including one thing that is green in the tests and wrong on screen.

## Round 5: what rounds 4 and 5 found

Thirteen findings across the two rounds, all right. Listed as bullets, not numbers, so nothing
collides with the claims above.

- **Round-4 finding 1 — the "real arena" test was testing the default Baseplate.** The sharpest of
  the thirteen. It never waited for `Workspace.TestArena` and never checked it existed, so it ran
  before `ArenaBoot` had built anything — and the 54 waypoints for a 210-stud route *said so*, a
  straight line with no detour, which I read past. Claims 6 and 7.
- **Round-4 finding 2, then round-5 finding 1 — the diagnostic had two holes.** One overwritten
  "last reason" slot, and then a whole failure class (`Success` with no usable waypoints) recorded
  nowhere. Claim 8. Fixing the first immediately exposed the counter mismatch in claim 9.
- **Round-4 findings 3 and 4 — the durable record.** The fifth departure from the design (dropping
  `pathFailures == 0`) was only in this file, which is rewritten per task; and the note's addendum
  §4, "what I could not measure", was three-quarters false now that everything has run. Both fixed
  in `docs/research/2026-09-24-boar-ai.md`.
- **Round-4 finding 5 — `TASKS.md` contradicted itself** after my own paperwork commit. Closed,
  struck through rather than deleted (rule 7).
- **Round-4 finding 6 — a correction to a BLOCKING queue row was sitting only in this file.**
  Play-time `screen_capture` **works**; row 7 says it cannot. Now an `ESCALATE.md` entry for the
  Director, naming the cause: `studio_mcp.Studio._call` joins only `text` content blocks, so an
  image-only reply comes back empty and I read that as "unavailable during Play".
- **Round-4 findings 7 and 8, round-5 findings 3 and 4 — four false statements in this file.**
  "20 assertions" where there are 24; "`Runtime:destroy` never exercised" when `afterAll` calls it;
  six claim numbers used twice; and "every arithmetic assertion" when one tolerance is deliberately
  tighter. All fixed above.
- **Round-4 finding 9 — `CLAUDE.md` contradicted itself**, and the mechanical check was red because
  of it. Fixed in loop step 4; see `## Harness`.
- **Round-5 finding 2 — the durable record named a superseded harness sha.** `TASKS.md` row 18 and
  the `ESCALATE.md` closure both cited `fbe1d60`, the *first* green run, while three code commits
  followed it. Both now name the code commit.

## Harness

```
[harness] PASS: 24/24 checks @ b6cf3dec736347f65c42ad3d05129d302389349a (clean tree)
```

Run 2026-09-25 on this branch, exit 0. `[tests:server] PASS: 39 passed, 0 failed, 0 skipped,
0 errors, 4 spec files`; `[tests:client] PASS: 4 passed, …, 1 spec files`.

**On `.agent-evidence/request-only-diff.txt`:** it may read "NOT OK". Round 4's finding 9 was right
that `CLAUDE.md` contradicted itself here — loop step 4 said "commit **only** `REVIEW_REQUEST.md`"
while git-workflow step 4 permits the whole paperwork set, and round 4's own findings 5 and 6
*required* commits to `TASKS.md` and `ESCALATE.md`. I own `CLAUDE.md` and have reconciled it: step 4
now states the allowed set once and says the evidence file checks the strictest case, so "NOT OK"
means "check the list", not "fail". **What to check:** every file between the code commit and HEAD is
on that list, and **no `src/`, `tests/` or `tools/` file moved after the code commit** —
`.agent-evidence/changed-files.txt` and `log.txt` show it. If one did, the harness line does not
cover HEAD and that is a finding.

## Screenshots (rule 5)

Captured during **Play** through `screen_capture`, at several camera positions, and **inspected**.
A correction worth recording: my first attempt reported "capture returned empty" — that was my own
client discarding the image, because `studio_mcp.Studio._call` joins only `text` content blocks.
The raw RPC returns a JPEG. **Play-time capture works**, which contradicts `TASKS.md` row 7 and is
now an `ESCALATE.md` entry for the Director.

- **The boar is real and behaves.** It rests at y ≈ 1.5 (`groundY + BODY_SIZE.Y/2`), wanders while
  idle, and reads as a 2 × 3 × 5.5 box. **Its sides read almost black**; only the top face shows the
  intended `Color3.fromRGB(90, 80, 70)`. Not a bug — a colour choice for Karen.
- **The arena's cover blocks and spawn pad are all there**, and the low walls and tall pillars are
  distinguishable at distance, which is what they are for.
- **The floor is wrong, and no test can see it.** The arena's ground plate is coplanar with
  `Workspace.Baseplate` (2048 × 16 × 2048, top also at y = 0) and **loses the depth test over half
  its area**: the 400 × 400 square renders as a **triangle**, split along the quad's diagonal, with
  the Baseplate showing through the other half. Two captures 1.5 s apart differ only where the boar
  moved — the diagonal is identical — so it is **stable, not flickering**. I did not fix it: the fix
  is either Karen deleting `Workspace.Baseplate` (Studio content, hers) or moving the arena's surface
  off y = 0, which changes a contract the boar depends on. Recorded in `TASKS.md` row 17.
- **Two `SpawnLocation`s exist during Play** — the arena's `ArenaSpawn` at z = +170 and the default
  at the origin — confirmed by a scene query (`spawns: 2`) and visually. Karen's call.

## Could not verify

- **`Path.Blocked` has never fired.** The `consumed() + 2` index arithmetic in
  `Runtime:_requestPath`'s `onBlocked` is unexercised: the plate returns `NoPath`, and in the arena
  no threat ever appeared, so no boar pathed under load. `stats().pathBlocked` exists for when it
  does.
- **No real player has ever been a threat.** Every threat in every test is an injected
  `{ id, position }` record, so `CONFIG.isThreat` → `Players:GetPlayers()` →
  `character.PrimaryPart` is unexecuted.
- **`Runtime:destroy` runs but is never asserted on** — `afterAll` calls it, so the green run proves
  only that it does not throw. **`maxBoars` is never exercised at all.**
- **The screenshots are mine, not Karen's**, and "the sides look almost black" is my judgement of a
  JPEG, not a measurement.
- **Whether the floor artefact matters in play** — it is a rendering artefact; parts, collisions and
  pathfinding all behave. I only saw it from high oblique angles and never from eye height.
- **The arena route test depends on Roblox's navmesh having picked up runtime-created parts.** It
  passes with 22.5 studs of detour today; it waits up to 5 s for the arena and 10 s for the path,
  which are guesses, not measurements. On a slower machine it could fail for timing rather than for
  a regression.
- **The round-5 fixes are unreviewed.** Round 5 was the last authorised round. `ESCALATE.md` says
  what they are.
- **CI** is unchecked: no `gh` on this machine.
