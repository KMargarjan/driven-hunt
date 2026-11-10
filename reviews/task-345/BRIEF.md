# Task 345 BRIEF: animals already in place, spooked or walking toward the line (Architect design run)

Carried by the Director. Read this first; it overrides anything older in `docs/`, `TASKS.md` or an earlier design.

## Karen's words (2026-11-10 ~10:30 UTC, after playing)

> "animals has to be in palces not just apear magically"
> "animal patter is ok but as I mentioned we need to have them not magically apearing it has to be there then it spooked or it walkks towards"

## Decisions already taken

1. **No animal appears in view.** Every animal a player can see was in the world before that player could see it. Today `ForestTest.releaseLine` spawns each scheduled group just ahead of the beater line. That is the "magic".
2. **The per-cell patterns stay** (Task 327h, `Grid.CELLS[i].animals`: density, startDepth, routeBias, restZones). Karen: "animal patter is ok". The schedule still decides WHEN each group moves and WHERE it breaks out. It no longer decides when the group comes into existence.
3. **Two ways an animal comes to the line**, both from a place where it already stood:
   - (a) **spooked**: resting or feeding in cover when the beaters reach it, then it breaks;
   - (b) **walking toward**: already moving ahead of the line from deeper in the cell.
4. **The server budget holds** (design `grid-map.md` 9.2, and Task 342's measured cost of 0.19-0.22 ms per live animal plus about 1.3 ms fixed; `ESCALATE.md` 2026-11-10 entries). Placed-in-advance animals must therefore cost close to nothing until they are woken: dormant, no AI step, cheap or no physics. The design states how, and what a dormant animal costs in parts and ms.
5. **Only the stag leaps** (Task 339), and out-of-play despawn (Task 342) stays.
6. **One owner** for "which animals exist in this drive and in what state" (rule 3). Name it.
7. **Streaming / replication.** A dormant animal far from every player may also be absent on the client. The design must say what a client sees when it wakes inside its stream radius. It must NOT pop in.

## What the design must contain

- The owner and the interfaces: the placement at drive start (or at the cell swap), dormant vs awake, the wake triggers (beater distance, the drive's slot time, a shot nearby), and how `cellSchedule` slots map onto WAKING placed groups instead of spawning them.
- How many animals are placed per drive per density, and where (`restZones` / cover, `startDepth`), within the budget. State the numbers.
- A "never spawn in view" rule as a testable predicate (for example: no spawn within N studs or in line of sight of any player), with N derived from the streaming radius.
- The measurement plan: spawns-in-view per drive (target 0), live-awake peak, dormant count, boar step ms, and what Karen sees at a stand.
- A task split into Builder tasks of at most 1 day each, with the gate for each (one-player unless `TWO_PLAYER_PATHS` is touched).
- Research per rule 1: at least 3 external sources on dormant / pooled NPC simulation and spawn-out-of-view rules, with licence and maintenance status.
