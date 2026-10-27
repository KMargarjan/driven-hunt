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

## 2026-10-27 -- Task 283, the hard stop, and a refuted premise

**Written at the 90-minute hard stop** (dispatch: *"At the hard stop, write ESCALATE.md AT THAT
MOMENT and report"*). The fix is built, measured and committed (`78770e71`); what is NOT done is the
proof Karen's frame asks for, and one of the dispatch's own statements is refuted.

**1. THE DISPATCH'S DIRECTION OF THE ERROR IS WRONG, and it changes what task 282 round 2 concluded.**
The dispatch (and `TASKS.md` 282b) says the rectangle mismatch means *"an honest hit on the withers
draws on the mane at every u"* -- the dot pushed UP. The arithmetic says the opposite. The old male
`box` is v 0.230..0.730 **of the image**, so v = 0 maps to 23.0 % down the PNG, not to its top; the
crest is at the top (row 0). Karen's lead pellet (y 1.41, v 0.030) drew at image v **0.266**
(measured, `hit_card 283` note on the pre-fix run) where the drawn geometry puts it at **0.107**. The
old card drew that withers hit **14 % of the picture's height too LOW**, not too high.

So the rectangle IS two rectangles and the fix is real -- but **the card was not what put her dots up
on the mane. The pellets were up on the mane**: task 282 measured them at y 1.41 on a trunk whose top
is 1.50, honest hits on the withers, and the OLD card drew them lower than they really were. The open
question is therefore **why a shot she aimed at the chest struck the withers**, which is about aim or
about the hitbox (282a), not about the drawing.

**2. NOT PROVEN, and nobody has seen it:** no card frame of any kind was drawn and looked at (rule 5),
and no three-cycle iteration table exists (CORE QUALITY protocol step 2). The proof route the dispatch
named (`282-shotcard.luau`) stages a BOAR with the shotgun only; the Learning Agent's L-121/L-123
note is right that there is no deer-capable staging probe, and I did not build one. What I did
instead was measure the DRAWN geometry of all seven kinds by ray
(`reviews/task-283/probes/283-extent.luau`, `283-flank.luau`) and assert the card's pixels against
the uploaded PNGs' own alpha. That is a stronger instrument for item 1 than one card frame, and it is
not a substitute for Karen's eye.

**3. The harness is RED at the hard stop:** `[harness] FAIL: 32/34 @ 78770e71 (clean tree) scope=all`
-- one named failure, `hit_card.spec` `hind#1`, which is a MEASURED finding for 282a rather than a
bug in the fix (a hit on the hind's raised neck is ABOVE her trunk box, `Shape.dot` clamps it to the
box's top line, and on her picture that line is air at that u), plus one unidentified client error.

**For the Director:** (a) 282b's stated cause needs correcting in `TASKS.md` with the arithmetic
above; (b) the real question behind Karen's sentence -- chest aim, withers hit -- is unanswered and
belongs with 282a or with an aim task; (c) a deer-capable shot-staging probe is still missing and the
next card or deer-shooting task will lose a session to it.

### Round 1's verdict, and why I am stopping rather than starting round 2

`reviews/task-283/RESULT.md`: three blocking findings, and **finding 1 is right and it reverses the
method**. I derived each kind's rectangle from the MESH (the trunk's top as a fraction of the drawn
height) and cross-checked only the stag, where it agreed with the hand-measured back line to 0.014.
The Reviewer checked the HIND against `HitCardInk`'s pixels: her picture's back line is row 18 of 60
(image v >= 0.283) where my geometry says 0.1951, so a hit on her box top now draws 0.09 of the
picture's height ABOVE her back -- and the old 0.276 drew it on ink. **Her card is worse than before
this change.** The artwork's proportions are not the mesh's: her drawn head sits higher over her body
in Karen's picture than in the asset.

That is a decision I should not take at 2.5x the hard stop, because it undoes claim 2 of my own
request: **if the rectangle is measured on the PICTURE it is per-PICTURE, and the cub/female and
calf/hind distinction I argued for disappears** (a cub is the sow's picture; the picture has one back
line). The two candidate answers are (a) measure `v0` as each picture's own back line and accept one
rectangle per picture, with the mesh as a cross-check that must agree, or (b) keep per-kind rows but
require every one of the seven to be confirmed against its picture's pixels, geometry only where the
two agree.

Findings 2 and 3 are also right: the dorsal case asserts the defect as the required state, and two of
my five cases pass with `TRUNK_IN_INK` deleted. Both are fixed by the same thing -- asserting the
NUMBER (the drawn image v of a dot at box v = 0, per kind) instead of "somewhere on a black blob".

**For the Director:** this is one more build round on a question that is now well posed, not a third
unknown. Nothing is merged. `main` is untouched; the branch is `task-283-card-dot` at `234a6c8d`.

## 2026-10-27 -- Task 284, at the hard stop. The fit is MEASURED AND MET; the old specs are not rewritten

**Written AT the 150-minute hard stop**, as the dispatch asks, before any workaround. Branch
`task-284-boar-fit`. Nothing is merged, nothing is pushed to `main`.

### WHAT IS DONE, AND IT IS THE TARGET

**AIR IS 0.0 % ON ALL FOUR KINDS FROM ALL FOUR DIRECTIONS**, measured by the same probe that measured
the before (`reviews/task-284/probes/284-fit.luau`, a 0.1-stud grid, two casts per direction with the
drawn mesh's `CanQuery` toggled between them):

```
BEFORE                                     AFTER
male      FLANK AIR 55.3 %  MISS  2.2 %    FLANK AIR 0.0 %  HIT 75.9 %
female    FLANK AIR 55.5 %  MISS  0.2 %    FLANK AIR 0.0 %  HIT 72.7 %
cub       FLANK AIR 57.5 %  MISS  1.9 %    FLANK AIR 0.0 %  HIT 53.8 %
legendary FLANK AIR 53.7 %  MISS  1.8 %    FLANK AIR 0.0 %  HIT 74.4 %
```
(ABOVE / FRONT / BEHIND are all 0.0 % air too; the full table is `reviews/task-284/MEASURED.md`.)

Fifteen volumes in five zones per kind, `TRUNK_HITTABLE = false`, `body` a real part, every box fitted
to that kind's OWN drawn mesh by `reviews/task-284/probes/284-autofit.luau` (three cycles). The
legendary's factor is re-measured as asked: 1.891/1.401 = **1.3498**, 4.397/3.257 = **1.3500**,
7.425/5.500 = **1.3500**, so it carries the male's boxes x `scale` and no row of its own. `female` and
`cub` carry their own absolute rows (measured: her shoulder slab is 0.880 tall against the male's
1.640 x 0.85 = 1.394). The deer's numbers are untouched.

### WHAT IS NOT DONE, AND IT IS BLOCKING

**THE SUITE IS RED AND I HAVE NOT RUN IT GREEN.** Five spec files encode the OLD contract -- the one
`TASKS.md` 282a already listed -- and rewriting them is the half of this task I did not reach:

1. `boar_zones.spec.luau` -- the big one, and its PREMISE is gone, not just its numbers: it is built
   on "a zone part stands `PROTRUSION` proud of a HITTABLE trunk". `CONFIG.ZONES.PROTRUSION` is now
   nil (`CLEARANCE_FLOOR = CONFIG.ZONES.PROTRUSION / 2`, line 46, is an arithmetic error at load),
   the child list is `"ZoneChest,ZoneHead,ZoneLegs,ZoneRear"` against fifteen numbered parts, the
   trunk's `HitZone` is asserted to be `"body"`, and about twelve real rays expect `body` where the
   trunk used to answer. ~250 of its 513 lines.
2. `deer_hitbox.spec.luau`, the "the boar's trunk is still a target" control block (lines 88-139):
   it asserts `TRUNK_HITTABLE == nil`, `trunkHittable == true`, `ZonesOnly == nil` and
   `passesThrough == false` FOR A BOAR. It was written as this task's own negative control and is
   now exactly inverted.
3. `boar_hit.spec.luau:133` -- `handle.part:GetAttribute("HitZone")` is `nil` now, not `"body"`.
4. `boar_behaviour_live.spec.luau:460` -- reads the child `ZoneChest` (now `ZoneChest1`) and compares
   its size with `CONFIG.ZONES.chest.size * scale` (the sow has her own row, so that product is not
   her box).
5. `report_silhouette.spec.luau` -- `Shape.rectOf(spec.size, spec.offset, ...)` projects box 1 only;
   every rect is a UNION of boxes now. `Report.CONFIG.SILHOUETTE` is already re-derived in
   `src/shared/Report/init.luau` (the five unions, computed and written), but the spec that recomputes
   it has not been changed, and its `body` case still asserts the whole unit square.

`weapon_client.spec.luau:1971` turns out NOT to be broken: it builds a scripted root and sets
`ZonesOnly` by hand, so "AND A BOAR IS UNTOUCHED" is prose, not an assertion about a real boar. Its
comment is now wrong and that is a note, not a fix.

**And so there is no harness line and no review.** The one full run I attempted was the FAIL-FIRST
run (src stashed, new spec present): it played both runners and then died on a harness fault --
`RuntimeError: start_stop_play: Stop play hasn't finished yet` -- after "client reported after 64 s,
server reported after 67 s", so the per-spec verdicts were never printed. **That is a harness fault
and it is reported, not worked around** (rule 6): a run whose two runners have both reported should
not lose the report to the stop. It cost the fail-first evidence this task was asked for.

### WHAT I ASK FOR

**One more build round on a question that is now closed, not an unknown.** The geometry is measured,
committed and verified; what remains is five spec files and one harness run, which is mechanical and
is about two hours of careful work -- `boar_zones.spec` has to be re-premised on "the trunk answers
nothing", the way `deer_hitbox.spec` was written for the deer in task 280.

**Two things for the Director to decide:**
1. **Does `boar_zones.spec` get rewritten, or retired in favour of `boar_hitbox.spec`?** The new file
   already asserts the built parts, the zone words through the bullet's own caster, the air and the
   coverage. What `boar_zones.spec` uniquely still holds is the PROTRUSION doctrine, which this task
   deletes on purpose, and `Body.buildZones`' weld/Massless/collision-group contract, which
   `boar_body.spec` also covers. Retiring it (archived under `backups/` with a note, rule 7) is
   smaller and loses nothing I can find; rewriting it is safer and slower.
2. **The remaining holes are listed, not scored** (L-122), and they are the honest complement of
   AIR 0: the hoof below y -1.06, the 0.12-stud strip at the very top of the mane crest, the snout's
   tip, the tail past z +1.91, a 0.12-stud slot at z -1.41..-1.29 where the shoulder slab could not
   grow forward to the head's line, and the 0.04-0.12 stud joins between the rear slabs. Per kind, as
   uncovered flank cells: male back 138 / belly 144 / legs 99 / nose 75 / tail 103, female 110 / 133 /
   57 / 54 / 86, cub 102 / 64 / 18 / 26 / 25, legendary 264 / 238 / 193 / 123 / 233
   (`reviews/task-284/probes/284-holes.luau`). The male's 75.9 % covered flank is BETTER than the
   stag's shipped 65.7 %, and the cub's 53.8 % is in family with the calf's 50.8 % -- so this is
   within the standard tasks 280/281 set, and closing it further is a fit task of its own.

### NEEDS KAREN

Nothing yet. **But the proof she has to see has not happened**: no shot has been fired at a boar on
her path with this hitbox, and no ZONE_TINT frame has been drawn or looked at (rule 5 is OPEN). The
dispatch gives that to the Director's `onray.py` shoot after review, and there has been no review.
L-010 is right that every prior "fixed" claim on this exact defect was measured and still wrong on
her path: **this is unproven on screen, and nobody has seen it.**
