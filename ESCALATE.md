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
- **and the pellets WERE honest hits** -- round 2's Reviewer refused my first answer for asserting a
  back line nobody had measured, and he was right. Measured: at z -0.21 the drawn back is **1.60**
  and the pellet struck **1.41**, 0.19 studs inside the animal at the withers.

**THE CAUSE IS THE CARD'S RECTANGLE, AND IT IS A SMALLER FIX THAN ITEM 1.** `HitLog.Shape.dot`
normalises y by the **TRUNK** (half-height 1.50); `BoarArt.drawDots` maps the result onto the
picture's whole **INK** box (`Report.imageBox`, v 0.250..0.713), whose top edge is the mane crest at
y 1.74. Three studs of trunk stretched over 3.257 studs of animal, all the error at the top: **an
honest withers hit draws on the mane at every u**, and a hit on the trunk's own top (v = 0) draws ON
the crest line. That is Karen's "bunched on the HEAD/NECK" and her "half outside the silhouette".
The two candidate fixes are one rectangle each -- divide by the drawn extent in `Shape.dot`, or map
the unit square onto the TRUNK's rectangle inside the picture rather than the whole ink -- and
either needs the drawn extent per kind, which is the one thing it shares with item 1.

And the complement, before, all four kinds (round 2, after the Reviewer caught a bug in the probe --
`FilterDescendantsInstances` takes DESCENDANTS, so the drawn mesh was in the box cast and `uncovered`
could not be anything but 0): **49.5 %-59.2 % of every ray that meets a hittable boar meets NO
ANIMAL**, on every kind from every direction. **And the male and the legendary have holes too** --
2.2 %/3.9 % and 1.8 %/3.6 % of the visible animal is a MISS, where the mane crest (1.757) stands
0.107 studs above `ZoneHead`'s top of 1.650. Female 0.2 %, cub 1.9 %. That is the dorsal band task
280a already names for the deer, smaller.

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

**TWO tasks, not one, because the measurement split them.**

**282b -- the card's rectangle. Small, and it is the one Karen photographed.** One projection, one
spec, no hitbox change: the dots must land on the drawn animal they are drawn over. It needs the
drawn extent per kind (above) and nothing else from 282a.

**282a -- the hitbox, with task 280's box**, dispatched against the numbers in
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
2. **`legendary` is `male` at `meshScale` 1.35 on a trunk scaled 1.35**, and it is now measured:
   FLANK 53.7 % air, 1.8 % miss -- the male's profile, scaled, as expected. So its boxes can be the
   male's fitted boxes x 1.35 and it needs no fit of its own. The two that cannot share are `female`
   and `cub`: measured 1.202/1.401 = 0.858 wide against 2.647/3.257 = 0.813 tall, so neither is the
   male scaled.

## NEEDS KAREN

Nothing. No click is missing; this is a size problem, not a tooling one.
