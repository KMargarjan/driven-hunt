# Task 328n -- the red stag stuck on C1's slope

Task: 328n
Round: 1
Base: 4ee9f3aa
Code commit: 782fc1ab15956ca6964783e137b2d5a2fb201d2a

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

## HARNESS

```
[harness] PASS: 34/34 checks @ 782fc1ab15956ca6964783e137b2d5a2fb201d2a (clean tree) scope=all
```
2795 server + 676 client assertions, 0 failed, 0 errors. **No flake fired**, so no control run is
owed. `test2` is **N/A**: no path in `TWO_PLAYER_PATHS` is touched (`src/server/Boar/`,
`tests/server/deer.spec.luau`). `studio_mcp.py selftest` and `agents.py selftest` both pass.

## WHAT CHANGED

`src/server/Boar/init.luau` -- one new row, `MAX_FORCE_BODY = Vector3.new(2, 3, 5.5)`, the box
`MAX_FORCE` was tuned on. `src/server/Boar/Body.luau` -- `Body.driveForce` (pure) and one call site,
`Body.create`'s `mover.MaxForce`. `tests/server/deer.spec.luau` -- three cases.

## CLAIMS

1. **The cause is measured, not argued.** `<runs-dir>/328n-ladder-CYCLE3.txt`: of 18 C1 points
   at >= 8 deg, 14 are ground a BOAR crosses (>= 50 studs in 4 s commanded uphill). On those the
   deer-sized body covered **5/14 before, 12/14 after**; mean **26.5 -> 60.8 studs**. Every failing
   row is 17-21 deg and reads 0.0-4.0 before, 59.6-67.7 after. *Verify:* read the file; the boar
   column is the control and is unchanged between the two.
2. **Karen's sentence, reproduced as a number.** `<runs-dir>/328n-stuck-BEFORE.txt`: a counted
   100 s window of a live C1 drive -- the one stag held **16.0 s with no progress** (commanded to
   move, net under 8 studs over 6 s) at (-3798,-5059) on a **14.8 deg** slope, 48 studs north of the
   main road; stuck samples **20.7 %** against 0.0-0.8 % for every boar kind.
3. **...and answered.** `<runs-dir>/328n-stuck-AFTER2.txt`, same probe, same place, same cell, with
   the force the shipped `Body.driveForce` computes: stag no-progress worst **0.0 s**, stuck samples
   **0.6 %**, **0 of 61** animals with no progress >= 6 s (BEFORE: 1 of 29), road crossings
   **17 of 18** (BEFORE: 1 of 2). *Verify:* the two files, read side by side.
4. **No animal loses force.** `driveForce` is `math.max(force, force * volume / refVolume)`. Male,
   sow and cub keep **6000** exactly; the stag gets 11,075 and the legendary 14,762. The first form
   scaled both ways and took the cub to **547** -- measured in her place
   (`<runs-dir>/328n-patch.txt`) and rejected before it shipped. *Verify:* `deer.spec`'s two pure
   cases and the live one, which reads `Mover.MaxForce` off the real trunks `Runtime:spawn` built.
5. **The live case bites when the producer is deleted (L-093).** It reads `MaxForce / AssemblyMass`
   off seven real trunks: revert the `Body.create` line and the stag's and legendary's accelerations
   fall to 0.54 and 0.41 of the male's, failing the `1e-6` equality. The harness proved this for
   real: the FIRST version of that case asserted every boar kept 6000 and the run FAILED
   (`expected 6000, got 14762.25`) because the legendary is scale 1.35 -- the case found a fact I
   had got wrong. *Verify:* `<runs-dir>/328n-harness2.txt` is that failing run.
6. **Frames, at hunter eye height, same camera both sides** (rule F, L-076). Camera K1 on the main
   road at (-3798, 124.63, -5112), ground 119.03, eye 5.6, looking at (-3798, -5045).
   `328n-BEFORE3-K1.png` (+ `-zoom.png`, 4x): the stag broadside among the trunks past the grass
   verge, not moving -- Karen's own frame. `328n-AFTER-K1.png`: same camera, same placement, he has
   left within 2 s. `328n-AFTER4-K2.png`: the same stag mid-stride in the wood on C1's slope. All
   four opened and described in the report.
7. **The boar did not regress.** AFTER census: cub n=28, female n=14, male n=18, **0** with no
   progress, worst stuck 1.4 s. BEFORE: cub n=12, female n=7, male n=9, 0 with no progress.
8. **Her place is untouched.** `328n-attrs-BEFORE.txt` and `328n-attrs-AFTER.txt` diff to nothing
   (L-101). Nothing was saved, published or committed there; every force change was a runtime write
   inside a Play session that is now stopped, and her build stays on merged `main` (L-014).

## WHAT I COULD NOT VERIFY

- **The AFTER force in her place is a runtime write, not this branch's code.** Her Forest Test only
  ever runs merged `main` (L-014), so the AFTER runs set `Mover.MaxForce` to the number
  `Body.driveForce` computes (`<runs-dir>/328n-patch.luau`, the same `math.max` arithmetic). The
  code's own writing of that number is proved by `deer.spec`'s live case in the harness, not here.
- **The staged 8-second placement is a weak instrument and no claim rests on it.** The stag's
  setpoint is his brain's: with a player anchored on the road he flees north and downhill, so that
  pair reads -5.06 -> -3.57 studs climbed. It measures the brain, not the body.
- **Two of the 14 crossable points still stop the stag**, and more force changes neither, so neither
  is this cause: `TASKS.md` 328n-notes(a).
- **One stag per drive.** Deer are rare by design (`DEER.RELEASE`), so each census window holds
  n=1 stag. The ladder is what carries the claim statistically; the census is what carries it
  end-to-end.
