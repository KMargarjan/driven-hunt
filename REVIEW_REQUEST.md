# Review request

Written by the Builder for `tools/review.sh`. The format is below; the script parses the first three lines.

Round: 1
Base: `358a430`
Code commit: `d265cab396b2a23b61c620fe9e6594f23b925211`

## Task

**Task 22** (Director, 2026-09-25, transcribed verbatim in `TASKS.md`): make the grey box usable for
Karen's first playtest. Two things, both of them defects the Task 17 and 18 screenshots found:

1. The place's default `Workspace.Baseplate` and `Workspace.SpawnLocation` leave the arena, without
   being deleted (rule 7).
2. The boar reads near-black from the side. Find the cause and fix it, with one number or one
   property in the boar's config.

`Base:` is `main` at `358a430`, where Tasks 17 and 18 merged. This is a new task, so `Round: 1`.

## Process

No research note and no Architect design (rule 1): no new system — one config constant, four comment
and doc edits, and a change made by hand inside Studio. No Architect audit (`ROADMAP.md` speed rule 3).
Lint, format and build pass; the harness passed once, on the code commit, on a clean tree.

## What changed

| File | What it is |
|---|---|
| `src/server/Boar/init.luau` | `Boar.CONFIG.BODY_COLOR` and the comment above it: the only behavioural change |
| `src/server/TestArena.luau` | header comment only: its statement about the place's defaults was made false by this task |
| `GAME_DESIGN.md` | the world-geometry owner row, same reason |
| `backups/2026-09-25_workspace-defaults.md` | **new.** The archive record (rule 7) of both instances |
| `backups/README.md` | its log line |
| `TASKS.md` | the Task 22 row and the Director's dispatch, verbatim |

**Not in the diff:** the change to the place itself. Both instances were moved inside Studio, in Edit
mode, through Studio MCP (`execute_luau`, a reparent — no property of either was touched). A place
change cannot appear in a git diff, so claims 1–3 are verifiable only in Studio, or through the
archive record.

## Claims

1. **Workspace is now the arena and nothing else.** After the move, a Studio query of
   `Workspace:GetChildren()` returned exactly `Camera` and `Terrain`; `Workspace:FindFirstChild("Baseplate")`
   and `FindFirstChild("SpawnLocation")` are both `nil`, and `FindFirstChildWhichIsA("SpawnLocation", true)`
   is `nil`. **How to verify:** not from the diff. In Studio: the Explorer, or that query. Play-time
   screenshots (described in the report to the Director) show the 400×400 plate rendering as a full
   square, not the triangle of Task 17, and one spawn pad.

2. **Nothing was deleted (rule 7).** Both instances live in `ServerStorage.Archive`, beside a
   `StringValue` `ArchiveNote` carrying the date and the reason. **How to verify:** in Studio; and
   `backups/2026-09-25_workspace-defaults.md` holds every property of both, read from the place
   *before* the move, so they can be recreated from it alone.

3. **The Archive folder will not survive, and the repo says so.** The dispatch assumed `ServerStorage`
   has no `$path`. It does: `default.project.json` maps `ServerStorage` to `src/serverstorage`, and
   every `$path` node defaults to `$ignoreUnknownInstances: false`, so Rojo removes unknown children
   at the next Connect. The backups file, `TASKS.md` row 22 and `ArchiveNote` itself all state this,
   and name the backups file as the lasting record. **How to verify:** `default.project.json`, and
   the "Rojo DELETES Studio-created instances" section of `CLAUDE.md`.

4. **The near-black boar was the albedo, not the material or the lighting rig.** This place leaves
   `Lighting.Ambient` and `Lighting.OutdoorAmbient` at the default `RGB(70, 70, 70)` (0.275) with
   `Brightness = 3`, read from the place. A face turned away from the sun is lit by that term alone,
   so the Task 18 value `RGB(90, 80, 70)` renders at roughly `RGB(25, 22, 19)` — against an arena
   floor of `RGB(150, 150, 150)` that stays near-white. Nothing was changed in `Lighting`, and
   `Boar.Body.create` still sets `Material = Enum.Material.SmoothPlastic`. **How to verify:** the
   comment above `BODY_COLOR` in `src/server/Boar/init.luau`; the material line in
   `src/server/Boar/Body.luau`.

5. **The fix is one constant:** `Boar.CONFIG.BODY_COLOR` = `Color3.fromRGB(198, 158, 110)`. It was
   chosen on screen, not by arithmetic: the first attempt, `RGB(214, 186, 150)`, was clearly visible
   but washed to cream, because the bluish sky ambient desaturates a shaded face. **How to verify:**
   `git diff` of the commit touches exactly one expression in `src/`.

6. **Nothing else reads that constant.** `BODY_COLOR` has exactly one consumer, `part.Color` in
   `Body.create`; no spec asserts it. So the change cannot move the boar, its physics or its state
   machine. **How to verify:** grep `BODY_COLOR` across `src/` and `tests/`.

7. **Harness PASS on the code commit, on a clean tree:**
   `[harness] PASS: 24/24 checks @ d265cab396b2a23b61c620fe9e6594f23b925211 (clean tree)`,
   39 server assertions across 4 spec files and 4 client assertions. Nothing was skipped.

8. **No owner boundary moved (rule 3).** `TestArena` still writes only `Workspace.TestArena`, `Boar`
   still writes only `Workspace.Boars`, and neither touches the defaults — they are simply no longer
   there. The move was made by the Builder by hand in Edit mode, not by game code: no script creates,
   moves or deletes anything outside its own folder. **How to verify:** `TestArena.build` and
   `Body.create` / `Body.destroy` in the diff's neighbourhood are unchanged.

9. **Two stale statements are deliberately left alone.** `docs/design/boar-ai.md` (§2, and its closing
   section on the Task 17 arena) still describes both defaults as live Studio content in `Workspace`;
   the Builder never edits Architect files (rule 3), so `TASKS.md` row 22 carries it to the design's
   next regeneration. And `tests/server/boar_body.spec.luau`'s test name "routes AROUND the arena's
   cover, not straight over the Baseplate" names the Baseplate as the *history* of that regression;
   the test asserts a detour and passes unchanged (`arena route: 55 waypoints, max lateral 22.5`).

10. **What I could not verify.** That Karen saves the place: until she does (File → Save to Roblox),
    the move exists only in the open Studio session — it is a `NEEDS KAREN` line in the report, as the
    dispatch directed, not an escalation. And the play-time screenshots are described and were
    inspected by me, but they are not in the repo, so the Reviewer cannot see them.
