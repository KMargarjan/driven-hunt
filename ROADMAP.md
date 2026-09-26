# Roadmap

Owner: Director (the only writer). Order of work, one task at a time. Task detail lives in `TASKS.md`,
playtest feedback in `PLAYTEST.md`, design and taste decisions with Karen.

Updated 2026-09-26. Target: **Milestone 1 in ~1–2 weeks, public v1 in ~4–6 weeks.**

## Speed rules (Director, 2026-09-24)

1. **Tooling is frozen after Task 11.** Process improvements go to "before release" unless they block
   the next game task.
2. **An audit item is must-fix only if it blocks the next game task,** and the audit names that task.
   Everything else is queued for "before release".
3. **Architect:** a design when a new system starts, and an audit every ~5 tasks, not after every task.
4. **Reviewer:** every task. Anything outside the task goes to `TASKS.md`, not into the round.
5. **One whole system per task** (for example the boar AI: idle, flee, route, despawn).
6. **Borrow before generating:** Roblox terrain tools and the map generator first; Meshy models via the asset pipeline. Creator Store props are withdrawn until M5 (free ones cannot be loaded by script, research 2026-09-26).
7. **Merge after review; playtest after.** Playtest findings become new tasks. Feel-critical tasks
   (shooting, camera) wait for Karen's OK before merging.
8. **One playtest session per day.** The Director batches what Karen must check. Every gameplay task
   report ends with "Karen: check this" (3–5 concrete things).

## v1 scope (Karen, 2026-09-24)

| In v1 | Later (v1.1+) |
|---|---|
| Wild boar, AI only | roe deer, fox, rabbit |
| Drivers and shooters, equal teams, drivers push on foot | AI dogs |
| Break-action shotgun, slugs and buckshot | other guns |
| Hit zones: head/chest instant; body and legs wound, boar runs on | blood trail and tracking |
| Safety penalty, simple: frozen at a tree until the drive ends | a funnier version |
| One small map (European farmland and woods), built by a map generator through MCP | more maps |
| A few on-screen hints | full tutorial |
| Free to play | cosmetics shop |

## Now: finish the scaffolding

| Step | What | State |
|---|---|---|
| 0.1 | Tasks 1, 5 and audit-001 | Merged to main |
| 0.2 | Tasks 9, 10, 11, 21: agent workflow, Director merges, review trimmed (blocking vs notes, harness before review, per-task review files) | Merged |
| — | Tasks 12–15 (audit-002 workflow items) | Moved to "before release" |

## Milestone 1: is it fun? (grey boxes, no art) — ~1–2 weeks

Exit test: Karen and a second player play it, and Karen says it's fun. If it isn't, change it here.

| Step | What | Depends on |
|---|---|---|
| 1.1 | Grey-box test area, 400×400 studs, a few blocks as cover | **Done** (Tasks 17, 22; Karen accepted 2026-09-25) |
| 1.2 | Boar AI: idles, flees from drivers, runs a route, despawns. Architect designs first | **Done** (Task 18; Karen accepted 2026-09-25) |
| 1.3 | Harness drives real input (Task 6); play-time screenshots saved (Tasks 6, 41) | **Done** |
| 1.4 | Shotgun: break action, two shells, reload, slug and buckshot, X swaps and reloads | **Done** (Task 24; Karen accepted 2026-09-25) |
| 1.4b | Camera: shoulder cam, right-mouse ADS with viewmodel, one camera owner | **Done** (Task 26; Karen accepted 2026-09-25) |
| 1.5 | Hit zones, wounds, carcass, hit marker | **Done** (Task 28; Karen accepted 2026-09-25) |
| 1.6 | 2-player harness (`test2`), started/ended by the Director without Karen | **Done** (Task 34; found the gunless-shooter bug); part of the merge gate for gameplay since Task 43 |
| 1.7 | 1.7a drive (Task 32, merged); 1.7b tree penalty + score screen (Task 35) | 1.7b built and tested, **waiting for Karen's playtest** (PR #30; #31/#33/#36/#37 stacked on it) |
| 1.8 | **Karen playtests with a second player** | 1.7 |

## Milestone 2: the world — ~2 weeks
Map-generator research note, then the generator (terrain, woods, fields, posts and drive-line markers
by tag), Creator Store and Meshy assets through an upload tool (Open Cloud key only in an environment
variable, never in the repo), boar model and animation, sound, light. A "Save to File" copy of the
place outside the repo before every map rebuild.

## Milestone 3: release — ~1–2 weeks
On-screen hints, several boars, a match loop with several drives, strip test code (Task 2), the
"before release" queue, publish to LIVE.

## Out of v1
See the scope table. Weather, weapon unlocks, several maps.
