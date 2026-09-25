# Task 23 — design brief for the ARCHITECT: regenerate `docs/design/shotgun.md`

Written by the Builder, carrying the Director's and Karen's decisions verbatim where they were given
as decisions. **This brief overrides anything older** in `docs/design/shotgun.md`, `TASKS.md` or the
research note. Read it before you write.

## Why this regeneration exists

Task 19 produced `docs/design/shotgun.md` and `docs/research/2026-09-24-shotgun.md` as documents
only. The Director then ruled (2026-09-24): **the design is not built from until it is regenerated
once the boar work is merged**, because the previous run could not see the boar branch and left three
blocking open decisions that were scope calls, not design problems. All three are now answered below.
Nothing has been built from that design: there is no weapon code in the repo.

## What changed since that design was written

- **The boar is on `main`.** `src/server/Boar/` (`init.luau` holding `Boar.CONFIG`, `Boar.defaultWorld`
  and the runtime; `Brain.luau`, pure decisions; `Body.luau`, the only writer of boar Instances),
  booted by `src/server/BoarBoot.server.luau`. Its design is `docs/design/boar-ai.md` and its note is
  `docs/research/2026-09-24-boar-ai.md`. `GAME_DESIGN.md` carries its owner row. Read the code, not
  just the design: §13.3 of the old design was raised because none of it was visible.
- **The arena is on `main`** (`src/server/TestArena.luau`, `Workspace.TestArena`), and since Task 22
  `Workspace` holds nothing else: the place's default `Baseplate` and `SpawnLocation` were archived
  into `ServerStorage.Archive` (`backups/2026-09-25_workspace-defaults.md`).
- **The review loop changed (Task 21).** Per-task folders `reviews/task-<N>/`, and a finding is
  blocking only if it makes the game, a test, an owner boundary or security wrong.
- **Task 7 has moved.** Play-time `screen_capture` through Studio MCP **works** and was used for
  Tasks 17, 18 and 22; what is still missing is only that `tools/studio_mcp.py`'s `Studio._call`
  drops image blocks, so the harness itself cannot save a capture. Rule-5 evidence for a visual
  weapon change is therefore available today. Do not repeat "play-time screenshots are blocked".

## The Director's and Karen's decisions — these are settled, do not re-open them

1. **The shotgun ships FIRST on the default camera: no ADS, no viewmodel.** This answers old §13.2.
   The old design's §3.3 cut was right; make it the design, not an option.
2. **Third-to-first-person aim / ADS is the very next task, separate, with its own design**
   (`tools/architect.sh design camera`). Karen wants it in v1. Say plainly in this design which seam
   that task will attach to, and make sure the weapon does not become the camera's owner by accident.
3. **Task 6 — drive real input from the harness, smallest useful version — lands BEFORE the shotgun
   build.** This answers old §13.1: no waiver, the blocker stands. Say exactly what that smallest
   version must prove for this weapon (which actions, which assertions), so the Task 6 build has a
   target. Keep the authoritative core buildable and specced independently of it.
4. **The damage entry point is a Director scope call and it is answered here** (old §13.3):
   **name one owner** for it in this design, and specify **how the boar receives a hit** as a single
   seam of the shape `takeHit(zone, ammo)` — hit zones themselves are ROADMAP 1.5, so the seam is
   enough now. The weapon must not write boar state: `Boar` owns `Workspace.Boars` and everything in
   it (`GAME_DESIGN.md`, `docs/design/boar-ai.md` §2). Say which module gets the new function, whether
   it is the boar's own owner module or a damage router, and why.

## What the regenerated design must contain, beyond the standard list in your prompt

1. **Both spread cones in ONE unit, and the config's unit named.** The Task 19 design's §9 stated the
   slug cone as a **half-angle** in a row beside the buckshot **full angle**, while §11.1 consumed a
   half-angle — so a config built from the table as written would be out by 2x either way. The
   research note is consistent (`docs/research/2026-09-24-shotgun.md`, "Numeric targets": slug
   **0.16° full cone**, buckshot **1.6° full cone**). Pick one unit, use it in every row, and state
   in the config section which unit the stored number is in and where the conversion happens, once.
2. **The owner rows for `GAME_DESIGN.md`**, ready to paste: system, owner module, files, design/note
   link — for every system this weapon introduces, and nothing it does not own.
3. **Karen's five feel defaults, as config values in the one config table** (she has not played it
   yet, so these are defaults to be tuned, not decisions): spread (realistic 1.6° full cone); reload
   2.0 s as one uninterruptible action; **a crosshair** — Karen wants one, so give it an owner and a
   config value rather than deferring it entirely, and say what it costs if UI has no owner yet;
   barrel select (automatic next live barrel); loading allowed only while the action is broken open.
4. **The three known defects in the Task 19 documents, corrected** (found in that task's review and
   deliberately left, because the Builder never edits Architect files): the cone-unit contradiction
   above; the old `ARCH_RESULT` item 1 pointing at §11.1 where it meant §11.3; and three of the four
   `docs/PROJECT_CONTEXT.md` citations being two lines off. Cite **files and symbols or section
   numbers, not line numbers** — the whole repo now works that way (`CLAUDE.md`, the loop, step 4).
5. **`ARCH_RESULT` should be `PASS`** unless something genuinely blocks building. The four scope calls
   above are answered; do not list them again. If you find a new blocker, list only that.

## Constraints

- Docs only. No code is written in this task.
- The Builder never edits `docs/design/`; whatever you write is what gets built.
- This design is judged by whether a Builder can build the weapon from it without asking a question.
