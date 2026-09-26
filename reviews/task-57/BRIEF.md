# Task 57 — ARCHITECT: sounders (boar groups) in `docs/design/drive.md`

Written by the Director. Karen, 2026-09-26: boars come as a MIX of singles and groups (2–5), as in her
references (a sounder crossing a forest road in front of shooters in orange). The map side is done
(`docs/design/map-generator.md` §11: spawn pads radius 30, what the map guarantees). The feature-flags
system exists (`docs/design/feature-flags.md`, merged): group behaviour must merge behind a flag, OFF.

Design, in docs/design/drive.md (revise it; keep everything already built working):
- The release: how a drive mixes singles and groups (sizes, probabilities, spacing, timing), and how
  the 6-boar budget per drive and `maxBoars` interact with groups.
- The behaviour: borrow a known pattern with sources (leader-follower, boids-style cohesion/separation
  on top of the existing Brain + PathfindingService route) — who leads, how followers keep formation
  through gates in hedges and along the road crossing, what happens when the leader is shot (scatter?
  a new leader?), how a wounded group member behaves (hit zones already exist).
- Owners: the Boar runtime stays the only writer of boar state; where group state lives; one writer.
- Performance: pathfinding cost with 5 boars in a group (compute the route once for the leader?).
- The flag: name, default OFF, what it switches, how the specs test both states.
- Tests (pure specs for the group logic; a live check), what Karen checks in the playtest, the config
  numbers with her feel values marked.
No local absolute Windows paths.

## Director decisions on the design's open decisions (2026-09-26, after the Architect's PASS)
- H: agreed — MAX_ALIVE_BOARS 4 -> 6 outside the flag.
- I: agreed — build against the contract, clamped to the pad radius in the tree.
- J: agreed — split into 57a (the sounder exists, behind the flag) and 57b (the drive releases it).
- K: agreed — separation steering only; a collision group only if the checks show shoving.
- L: agreed — no group bonus, no sounder field on the wire.
- M1: agreed — boar-ai.md regenerated with the next boar task after 57a.
- M2: noted — MIN_PLAYERS back to 2 before release (ROADMAP Milestone 3).
- Karen's feel items 1–10 keep their defaults until her playtest with the flag on.
