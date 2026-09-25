# Task 27 — design brief for the ARCHITECT: `docs/design/hit-zones.md` (ROADMAP 1.5)

Written by the Director. Run in parallel with the Builder (shotgun Task 24 is on branch
`task-24-shotgun`, not merged yet — read it there: `git show origin/task-24-shotgun:<path>`; its seam is
`Boar.Body` publishing `Damageable`/`HitZone` and `Runtime:takeHit(part, hit)` with
`hit = { zone, ammo, pellets, at }`, `zone = "body"` today, wired in `BoarBoot.server.luau`).

## What it must do (Karen's v1 spec, cut scope agreed 2026-09-24)
- Hit zones on the boar: HEAD and CHEST (heart/lungs) kill instantly. BODY (belly, flank, rear):
  the boar is wounded and runs a SHORT way, then drops. LEGS / hindquarters: several hits needed; it runs
  FAR before dropping, or escapes. Buckshot pellets each hit a zone; slugs are one hit.
- Out of v1: blood trail and tracking (v1.1). Dogs (v1.1).
- A dead boar stays as a carcass for scoring (score is 1.7, it needs an event: who shot, which zone,
  ammo, distance, killing shot vs wounds). An escaped wounded boar is also an event.
- The boar's reaction to any hit must be visible (flinch/bolt) so Karen can judge hitting at all:
  her playtest said "too early to say if I can hit anything".

## The design must give
- Zone geometry on the grey-box boar (5.5 x 3 x 2 studs): which parts, sizes, how the hit part maps to a
  zone; one owner for boar health/wound state (the Boar runtime, not the weapon).
- Wound model: numbers per zone per ammo (slug vs buckshot pellet), how "runs a short way / far" is
  expressed (distance or time, speed), what "drops" means (state, physics, despawn timing).
- The boar Brain's new states (wounded fleeing, dying, dead) and how they reuse flee/route.
- The kill/escape event and its payload for score (1.7), with the shooter.
- Tests: pure specs for the wound model; a spec that a head hit kills and a leg hit does not; an
  input-scenario + screenshot plan to show a hit reaction and a carcass.
- The numbers as one config table; mark which are Karen's feel values.
