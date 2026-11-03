# Task 328n -- the red stag stuck on C1's slope

Task: 328n
Round: 1
Base: 4ee9f3aa
Code commit: (filled in below, at the harness line)

Karen, 2026-11-03: *"red stag stuck cant clim in this mountain"*.

## PLAN

**(a) REAL LIFE.** A red deer is a hill animal: *Cervus elaphus* lives on open hill and mountain
ground, and a stag at 160-240 kg carries proportionally more muscle than a 50-90 kg wild boar
(Animal Diversity Web, *Cervus elaphus* -- the account this file already cites for the group shapes,
`Boar.CONFIG.DEER.RELEASE`). Nothing in life makes the heavier animal the one that cannot climb what
the lighter one walks up. So the real-life target is a RELATION, not a gradient off a paper: **a stag
climbs at least what a boar climbs.**

**(b) MEASURED NOW** -- in Karen's Forest Test, in Play, C1:
- `<runs-dir>/328n-ladder.luau` (climb ladder, 4 s commanded straight uphill at 18 studs/s on
  measured C1 gradients, bodies built to the animals' own `BODY_SIZE` / density / `LinearVelocity`):
  deer box (mass 42.6) covers **67.8 studs at 10 deg and 1.3 at 15 deg, 1.0 at 20, 0.0 at 25**;
  boar box (mass 23.1) covers **70.9 / 67.9 / 62.4 / 64.0** over the same four slopes, at the same
  four points. The deer's climb limit is between 10 and 15 degrees; the boar's is over 25.
- `<runs-dir>/328n-sampler.luau` (a live C1 drive, 100 s at 5 Hz): the one stag alive spent
  **16.0 s with no progress** (commanded to move, net under 8 studs over 6 s) at (-3798,-5059) on a
  **14.8 deg** slope, 48 studs north of the main road -- which is where Karen's frame was taken. Every
  boar kind: **0** animals with no progress. Stuck samples: stag **20.7 %**, boar kinds 0.0-0.8 %.
- `<runs-dir>/328n-terrain.luau`: **12.9 %** of C1 is steeper than 15 deg, 6.9 % steeper than 20,
  0.8 % steeper than 30, worst 40.7 deg.

**(c) TARGET.** Every animal gets the drive acceleration the boar has today: 6000 / 23.1 =
**259.7 studs/s^2**. Measured climb limit goes from 15 deg to ~32 deg (derived from the ladder's own
two readings: the deer stalls AT 15 deg with a/g = 0.717, so the effective friction angle is
`atan(0.717) - 15 = 20.6 deg`, and a boar's 259.7 gives `atan(259.7/196.2) - 20.6 = 32.3 deg`).
Why that number and not a bigger one: it is the number the boar already lives by, so **no boar
changes at all**, and C1's steepest ground is 25 deg at the scale an animal's body meets it.
Target in the world: **0 animals with no progress over a C1 drive**, stag included.

**(d) LEVER.** `grep -n "mover.MaxForce\|MAX_FORCE = " src/server/Boar/Body.luau src/server/Boar/init.luau`:
```
src/server/Boar/Body.luau:447:	mover.MaxForce = config.MAX_FORCE
src/server/Boar/init.luau:450:	MAX_FORCE = 6000,
```
One writer, one constant. `MAX_FORCE` is a FORCE, and `Boar.speciesConfig` replaces `BODY_SIZE`
(boar 2 x 3 x 5.5 = 23.1 mass, red deer 1.8 x 4.8 x 7.05 = 42.6) without replacing it -- so the deer
is 1.85x the mass on the same force, and gets 54 % of the boar's acceleration.

**(e) HOW IT WILL BE MEASURED AFTER.** The same two probes, same place, same session.
