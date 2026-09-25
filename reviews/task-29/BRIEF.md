# Task 29 — design brief for the ARCHITECT: `docs/design/drive.md` (ROADMAP 1.6 + 1.7)

Written by the Director, run in parallel with the Builder (camera, Task 26, in progress; hit zones,
Task 28, next). Read `docs/design/hit-zones.md` (kill/escape events), `docs/design/shotgun.md`
(the safety arc, `SAFETY_ARC_HALF_DEG`), `docs/design/camera.md`, `ROADMAP.md` (v1 scope table).

## What the system must do (Karen's v1 spec)
- One DRIVE = one round: 10 minutes, then a score screen, then the next drive.
- Two teams, EQUAL size: DRIVERS walk through the woods and push boar toward SHOOTERS standing on posts
  along a line. v1: drivers on foot, no dogs. Drivers may shoot too (Karen: "who is driving can also
  shoot, maybe not at the beginning") — design it as a config switch, default OFF.
- Individual points per boar, by shot quality (zone of the killing shot; wounds/escapes count for less
  or nothing — propose numbers, they are Karen's feel values).
- SAFETY RULE: a shooter who fires toward the drive line / toward drivers is punished, comically: frozen
  "tied to a tree" until the drive ends (v1 simple version: frozen in place at a tree/post, visible to
  everyone). Players are not damageable (shotgun §15 C).
- Posts and the drive line are gameplay markers found by CollectionService tags (the map generator
  later places them; the grey-box arena needs a first set).
- Several boars per drive (the Boar runtime already allows `maxBoars`); spawning is part of the drive.
- 10–16 players; must also work with 2 players (Karen + daughter) for the Milestone 1 playtest.

## The design must give
- Owners: match state (one writer, server), team assignment, the timer, score, the penalty, the score
  screen (UI is `PlayerScripts.Hud` or a new owner — decide), boar spawning per drive.
- The match state machine (waiting for players, assigning, drive running, drive over/score, next
  drive) and what happens on join/leave mid-drive.
- The safety-arc check: who decides a shot is "toward the line", at fire time, from the shotgun's data.
- Numbers as one config (drive length, boars per drive, points table, penalty), Karen's values marked.
- ROADMAP 1.6: what the harness needs to test with 2+ players (Studio "Clients and Servers" local
  test) — the smallest harness change, or state plainly what cannot be automated and needs Karen.
- Tests, failure modes, and what Karen checks in the Milestone 1 playtest with a second player.
