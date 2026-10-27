# Task 284 -- the boar's hitbox fits the drawn boar

Task: 284
Round: 1
Base: 3aaa1556
Code commit: e71ddef477e9b0501be6c636639a9eada380ee19

`[harness] PASS: 34/34 checks @ e71ddef477e9b0501be6c636639a9eada380ee19 (clean tree) scope=all`

`test2` N/A: no `TWO_PLAYER_PATHS` file is touched. `git diff --name-only 3aaa1556..e71ddef4` is
`src/server/Boar/Body.luau`, `src/server/Boar/init.luau`, `src/shared/Report/init.luau`,
`tools/studio_mcp.py`, eight `tests/server/*.spec.luau` and `tests/client/weapon_client.spec.luau`
(a comment). None of them is in that list.

## WHAT CHANGED

The boar gets the deer's shape: **fifteen measured volumes in five zones per kind**, a real `body`
part, and `TRUNK_HITTABLE = false`. Every box is fitted to that kind's own drawn mesh by raycasting
its three silhouettes; `legendary` is the male's boxes x `scale`, `female` and `cub` carry their own
absolute rows. `Report.CONFIG.SILHOUETTE` is re-derived as the union per zone. Seven spec files that
asserted the old contract are rewritten and one new file asserts the new one.

## CLAIMS, AND HOW TO VERIFY EACH

1. **AIR IS 0 ON ALL FOUR KINDS, where it was 49.5 %-59.2 %.** `reviews/task-284/MEASURED.md` 1 and
   3 carry both runs of `reviews/task-284/probes/284-fit.luau` -- the same probe, before and after,
   0.1-stud grid, four directions, two casts with the mesh's `CanQuery` toggled between them so
   neither cast sees the other's parts.
2. **The suite proves it too, independently of that probe.** `tests/server/boar_hitbox.spec.luau`,
   case *"never answers a ray that misses the drawn animal"*: it sweeps the flank through
   `Weapon.Cast.world` and fails if any ray answers a zone without crossing the mesh. Its notes in
   the harness output read `0 in the air` for male, female, cub and legendary.
3. **FAIL FIRST.** With `src/` checked out at 3aaa1556 and this branch's specs, the same suite is
   `[tests:server] FAIL: 2360 passed, 40 failed, 0 skipped, 40 errors` -- named: `boar_hitbox.spec:68`
   (`TRUNK_HITTABLE` is nil), `:91` (the old head box reaches z -2.810, outside the drawn mesh's
   -2.750), `boar_hit.spec:137`, `boar_behaviour_live.spec:465`. Reproduce:
   `git checkout 3aaa1556 -- src/ && python tools/studio_mcp.py test`.
4. **Every box is inside the drawn animal, and that is measured, not asserted.**
   `boar_hitbox.spec`'s *"gives every zone several measured boxes, all strictly inside the drawn
   male"* checks |x| and z against the measured envelope; the per-kind cases check each box's own
   centre crosses the mesh.
5. **The air beside, under and over answers NOTHING, and the trunk is in the way of those rays.**
   `boar_hitbox.spec`'s *"answers NO hit beside the animal, under its belly, over its rump and past
   its snout"* -- each of the four points is measured as air by a mesh cast and measured as inside
   the trunk, so a miss cannot come from a ray that sailed past. `boar_zones.spec`'s
   *"answers NOTHING between the legs, under the belly, or past the tail"* is the same rule.
6. **`legendary` is the male x 1.35 and that factor was re-measured** (L-020): 1.891/1.401 = 1.3498,
   4.397/3.257 = 1.3500, 7.425/5.500 = 1.3500 (`MEASURED.md` 1). It therefore carries no `zones` row;
   `boar_kinds.spec` asserts both halves -- the legendary scales, the cub does not.
7. **The dorsal band is `body` and not `chest`**, task 281's rule: `boar_hitbox.spec`'s
   *"covers the drawn back line with a band that is not the chest"*, and `boar_zones.spec`'s
   *"the TOP of that back is body"*.
8. **The seven old-contract specs say what they assert now.** The commit message of `4eec5885` lists
   them one by one, old contract -> new.
9. **The deer's numbers did not move.** `git diff 3aaa1556..e71ddef4 -- src/server/Boar/init.luau`
   touches no line of `SPECIES.reddeer`; `deer_hitbox.spec`'s own measurements are unchanged.
10. **What is NOT covered is listed, not scored** (L-122): `MEASURED.md` 4 names the hoof below
    y -1.06, the 0.12-stud strip at the top of the crest, the snout's tip, the tail past z +1.91, a
    0.12-stud slot at z -1.41..-1.29, and the 0.04-0.12 joins between the rear slabs, with per-kind
    cell counts. Covered flank: male 74.8 %, female 65.3 %, cub 59.5 %, legendary 76.3 % against the
    stag's shipped 65.7 % and the calf's 50.8 %.

## WHAT I COULD NOT VERIFY

- **No shot has been fired at a boar on Karen's path with this hitbox.** The dispatch gives that to
  the Director's `onray.py` after this review. The frames I did take are
  `<runs-dir>/284/zone-*.png` and `side-*.png`, one per kind, from the player's eye at 12 studs with
  the zone volumes drawn; the staging probe's self-check reports **15 of 15 parts placed, worst drift
  0.0001 studs** on every kind (V280), so the animal is fit to shoot at. Looked at: the trunk box is
  visibly longer than the boar at both ends and reaches below its hooves, and the tinted volumes sit
  on the animal, not in that empty box.
- `Report.CONFIG.SILHOUETTE`'s two dorsal `body` boxes stand above the trunk's own top, so
  `Shape.dot` clamps their dots to the back line. On the hit CARD that line is the picture's measured
  back (task 283) and is right; on the report panel's drawn boar it is the top edge. Measured and
  noted by `report_silhouette.spec`, queued rather than fixed in this task.
