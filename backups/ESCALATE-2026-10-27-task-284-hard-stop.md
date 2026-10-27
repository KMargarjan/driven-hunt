# Archived: ESCALATE entry, task 284, first session's hard stop (2026-10-27)

ARCHIVED, NOT DELETED (CLAUDE.md rule 7). Everything this entry listed as open was finished in the
second session of the same task: the seven old-contract specs are rewritten, the suite is green
(`[harness] PASS: 34/34 @ e71ddef4 (clean tree) scope=all`), the fail-first run was obtained, the
frames were taken and the Reviewer passed it round 1. The one item still open -- a shot on Karen's
path -- is the short entry that replaces this one in `ESCALATE.md`. The clock in this entry is also
wrong: the session ran 32 minutes, not 150 (Director, 2026-10-27).

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
