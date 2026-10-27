# ESCALATE -- task 282, at the hard stop. For the Director.

**Builder, 2026-10-27.** Branch `task-282-boar-hitbox`. **Item 2's cause is measured and named;
items 1, 2's FIX and 5 are NOT done.** I am writing this AT the hard stop, before designing any
workaround, exactly as the dispatch asks.

(The previous entry, task 269b, is archived at `backups/ESCALATE-2026-10-26-task-269b.md`.)

## WHAT THE BOX BOUGHT

**Dispatch item 2's cause was unknown and is now measured** -- and it is NOT the pellets' spread and
NOT the card's mapping. Both were candidates in the dispatch; both are refuted by readings in
`reviews/task-282/MEASURED.md`:

- the pattern measures 1.8 x 1.1 studs at 88.7 studs, which is what `SPREAD_FULL_DEG.Buck = 1.6`
  gives -- correct;
- every one of the eight dots is drawn where `HitLog.Shape.dot` put it, through the measured ink box
  -- correct;
- **the pellets really struck the box at y_local +1.40, 0.09 under the trunk's top face, on a 3.00
  box holding a 3.257 animal whose back over the chest is lower than that top.** `uv v = 0.030` is
  2.8 px below the top of the ink in an 80 px frame -- under half a dot -- so the diamond draws half
  in the grey, and the top of the ink is the mane and ears. **That is item 1. Item 2 IS item 1.**

And the complement, before, per kind: **54.7 % (male), 55.4 % (female), 57.0 % (cub) of every flank
ray that meets a hittable box meets NO ANIMAL.** Nothing is uncovered -- 0 misses of 814 flank rays
on the male. The boar's defect is air only.

## WHY ITEM 1 DID NOT FIT, WITH THE ARITHMETIC

Turning the trunk off (`TRUNK_HITTABLE = false`) is three characters. **What it costs is everything
that `body` means today**, because the boar's four boxes do not tile the animal: `chest` ends at
z +0.25 and `rear` begins at z +1.10, so an 0.85-stud band of the barrel -- the broadest part of a
broadside boar -- is TRUNK ONLY. Switch the trunk off without adding a `body` box and that band
becomes a MISS, which is worse than the air. So item 1 is the deer's job again, whole:

1. a per-kind mesh fit for four kinds (male, female, cub, legendary -- `male` and `legendary` share
   a model at two scales, `female` and `cub` are their own meshes and are NOT the male scaled:
   measured 1.202/1.401 = 0.858 wide against 2.647/3.257 = 0.813 tall);
2. a `body` box added to `ZONES.ORDER`, which renames nothing but adds a fifth zone part;
3. `TRUNK_HITTABLE = false`;
4. `Report.CONFIG.SILHOUETTE` re-derived -- `tests/server/report_silhouette.spec.luau` recomputes
   every rectangle from `Boar.CONFIG.ZONES` through `Shape.rectOf` and fails the harness otherwise;
5. the specs that encode the OLD contract, each of which asserts the thing that changes:
   `boar_zones.spec.luau` (the exact child list `"ZoneChest,ZoneHead,ZoneLegs,ZoneRear"`, plus twelve
   real rays that expect the trunk to answer `body`), `deer_hitbox.spec.luau:136`
   (`expect(handle.part:GetAttribute("ZonesOnly")).to.equal(nil)` FOR A BOAR), `boar_hit.spec.luau`,
   `boar_behaviour_live.spec.luau`, `weapon_client.spec.luau:1971` ("...AND A BOAR IS UNTOUCHED").

That is task 280's shape, and task 280 was its own task. Doing it in the time left would have meant
committing a half-fitted hitbox with a green suite -- the exact self-identity trap L-121 names, and
the one that let eight "chest" acceptances pass over air across tasks 265-278.

## WHAT I ASK FOR

**One task, 282a, with task 280's box**, dispatched against the numbers in
`reviews/task-282/MEASURED.md`. The instruments are built and committed
(`reviews/task-282/probes/`): `282-stage.luau` stages a frozen broadside boar of any kind with the
shooter frozen and prints the camera ray's entry in the trunk's own frame, `282-fit.luau` prints the
complement from four directions, `282-pose.luau` puts one kind at the player's eye with the volumes
drawn, and `282-shotcard.luau` fires one real buckshot and dumps every pellet's true `(u, v)` and
its drawn position. Before and after come off the same four.

**Two things the Director should decide, not me:**

1. **Does the boar get a `body` box, or do the four boxes grow to tile the animal?** The deer got a
   `body` part (fifteen volumes in six zones). The boar's `body` is the trunk's fallback today and
   `Report.CONFIG.ZONES` lists it, so a fifth part is the smaller change to everything that reads a
   zone word -- but it is a new part on every boar in a drive.
2. **`legendary` is `male` at `meshScale` 1.35 on a trunk scaled 1.35.** Its complement is not
   measured (the probe keyed the template on the kind, not the model; fixed afterwards, the sweep
   not re-run). If `male`'s fitted boxes are simply scaled by 1.35 it needs no fit of its own --
   that is one probe run to confirm, and it should be confirmed rather than assumed.

## NEEDS KAREN

Nothing. No click is missing; this is a size problem, not a tooling one.
