# Roadmap

Owner: Director (the only writer). Order of work, one task at a time. Task detail lives in `TASKS.md`,
playtest feedback in `PLAYTEST.md`, design and taste decisions with Karen.

Updated 2026-09-24.

## Now: finish the scaffolding

| Step | What | State |
|---|---|---|
| 0.1 | Task 1: setup (PR #1, `task-1-review-fixes`) | Reviewer re-review pending, then Karen merges |
| 0.2 | Audit-001 on its own (PR #2, `audit-001`) | Reviewer pending, then Karen merges (docs only) |
| 0.3 | Task 5: audit-001 must-fix M1–M4 (PR #3, stacked on PR #1) | Built (`20e136b`), review pending |
| 0.4 | Task 9: four-agent workflow (`tools/review.*`, `tools/architect.*`, agent prompts, `docs/PROJECT_CONTEXT.md`, roles in CLAUDE.md), stacked on PR #3 | Builder working (`task-9-agent-workflow`) |
| 0.5 | Director dispatches the Builder headless (`claude -p`); add a `NEEDS_KAREN.md` stop file for human actions (Rojo Connect) | After 0.4 merges |

## Milestone 1: is it fun? (grey boxes, no art)

Exit test: Karen and one other player play it, and Karen says it's fun. If it isn't, fix it here.

| Step | What | Depends on |
|---|---|---|
| 1.1 | Flat test area, 400×400 studs, a few blocks as cover | 0.4 |
| 1.2 | One boar AI: idles, flees when a driver comes near, runs a route, despawns. Architect designs first | 1.1 |
| 1.3 | Harness drives real input (Task 6) | 0.4 |
| 1.4 | Play-time screenshot evidence (Task 7). **Needs Karen's decision:** tool capture, or Karen's screenshot as evidence | 0.4 |
| 1.5 | Shotgun: break action, two shells, reload, slug and buckshot; third person, first-person aim | 1.3, 1.4 |
| 1.6 | Hit zones: head/chest instant, body short run, legs long run, blood trail | 1.2, 1.5 |
| 1.7 | Score: points per boar by shot quality | 1.6 |
| 1.8 | Teams (equal drivers and shooters), 10-minute drive, score screen | 1.7 |
| 1.9 | **Karen playtests with a second player** | 1.8 |

The boar AI (server-side, testable by server specs) goes before the shotgun, because camera, input
and visual client code are blocked on 1.3 and 1.4.

## Milestone 2: the real hunt
Dogs, the safety rule (tied to a tree), the drive line and posts, several boars with real behaviour,
the match loop with several drives.

## Milestone 3: the world
Farmland-and-woods map, sound, animation, the boar model, light.

## Milestone 4: release
Menu, cosmetics shop, tutorial, strip test code (Task 2), publish to LIVE.

## Out of v1
Other species (roe deer, fox, rabbit), several maps, weapon unlocks that change power, weather.
