# Task 280 — the deer hitbox is the deer, not the air around it

Task: 280
Round: 1
Base: `main` @ `e57710ac`
Code commit: `a56f9727ae7b5714a82ec6cd7e7f62fbeb80c3c9`

```
[harness] PASS: 34/34 checks @ a56f9727ae7b5714a82ec6cd7e7f62fbeb80c3c9 (clean tree) scope=all
```

`test2` is **N/A**: nothing here is under `TWO_PLAYER_PATHS`. The files touched are
`src/server/Boar/`, `src/server/Weapon/`, `tests/server/`, `tools/studio_mcp.py` and `backups/`
(Director decision 2026-10-03 — the weapon and the animal need the one-player line only).

## PLAN (core quality protocol step 0)

**(a) REAL LIFE.** A bullet connects where the animal is and nowhere else. A red stag stands about
1.36 m at the withers and measures 0.49 m across the body; the space in front of its brisket, under
its neck and between its legs is air.

**(b) MEASURED NOW**, not read off the code. The pre-fix geometry, swept with the same instrument
used afterwards (`<runs-dir>/280-fit0-prefix.txt`), on a real stag built by `Runtime:spawn` from the
real model in a DEV Play session: **1,999 of 3,631 answering flank rays hit a zone part and never
crossed the drawn animal** — 55 % of every "hit" was a hit on nothing. 281 from above, 372 from the
front, 371 from behind.

**(c) TARGET.** That number, from four directions, on all three deer kinds: **0**.

**(d) LEVER.** `Boar.CONFIG.SPECIES.reddeer.ZONES` and the two new `KINDS.*.zones` rows (the
volumes); `Boar.Body.create` (what the trunk publishes); `Weapon.Hits.targetOf` and
`Weapon.Cast.world` (what a bullet does with it).

**(e) HOW IT IS MEASURED AFTER.** The same sweep, and it is kept as
`tests/server/deer_hitbox.spec.luau`.

**ONE PREMISE OF THE DISPATCH IS REFUTED BY MEASUREMENT** — the mechanism in item 1 ("a ray passes
through it") cannot be `CanQuery`. See claim 2. The goal is met by another route.

## What changed

1. **Twelve measured shot volumes per deer kind**, fitted to the DRAWN MESH by raycasting it,
   replacing task 223's four bone-fitted boxes. `body` becomes a real part (the barrel) because the
   trunk no longer answers; the NECK is part of `chest` (a real kill zone, and `chest` already
   carries `Slug = 100` with `CLASS.chest = "vital"`).
2. **A deer's trunk is no longer a target.** It publishes no `HitZone` and declares `ZonesOnly`;
   `Hits.targetOf` refuses it, and `Cast.world` passes the bullet through it to the volumes inside.
3. **A zone may be several boxes** (`spec.boxes`), one welded part each. `spec.boxes or { spec }` is
   the identity for every boar.

## Claims

1. **The air Karen hit is a MISS and the animal is a hit, proved against the DRAWN MESH, on all
   three kinds.** `tests/server/deer_hitbox.spec.luau` freezes a stag, a hind and a calf in the bind
   pose the volumes were measured in, makes the drawn mesh queryable for the length of the file, and
   sweeps a 0.25-stud grid of real flank rays: **every** ray that answers a zone must also cross the
   mesh (AIR must be 0), and it must find the animal at all (`both >= 20`, so a zero from an empty
   world cannot pass). Four named air points per kind — under the neck, in front of the chest,
   between the legs, under the barrel — must each answer **nothing**.
   *Verify:* read the file. The grid case errors with the first offending `(y, z)` and the zone it
   answered. The same sweep on the pre-fix geometry counted 1,999 air hits on the stag.
2. **`CanQuery = false` CANNOT take the trunk out of a cast, and that is measured with a control.**
   The first commit on this branch used it and the harness refuted it. `<runs-dir>/280-diag4.luau`,
   a 2x2x2 control part behind a 4x4x4 one, four rows, one variable at a time:
   `CanQuery=false, CanCollide=true` → the big part is STILL returned by `Workspace:Raycast`;
   `CanQuery=false, CanCollide=false` → it is skipped and the control behind it is returned; and the
   same both ways round whether `CanQuery` is written before or after parenting. A deer's trunk must
   collide — it is the body the physics simulates.
   *Verify:* the measurement is written out above `Weapon.Hits.passesThrough`.
   `Boar.Body.attachVisual`'s own `CanQuery = false` on the drawn mesh is unaffected and still
   works, because that mesh is `CanCollide = false`.
3. **The pass-through steps PAST the surface; it could not filter it out.**
   `Weapon.Cast.world` re-casts the rest of the segment from `PASS_THROUGH_STEP` = 1e-3 studs beyond
   a surface `Hits.passesThrough` names, bounded by `MAX_PASS_THROUGH` = 4. Excluding the trunk
   instead is impossible: `FilterDescendantsInstances` means "these instances AND THEIR
   DESCENDANTS", and every zone part is a CHILD of the trunk — the harness said so in one line,
   *"chest box 1 answered no zone at its own centre"*, on all three kinds.
   *Verify:* `Cast.world`. `distance` is still measured from the CALLER's own origin (every caller
   treats it as that), and `ignore` is neither modified nor copied.
4. **A boar is untouched, and a case fails if it stops being untouched.** `TRUNK_HITTABLE` is absent
   from `Boar.CONFIG.ZONES`, so `geometry.trunkHittable` reads true: the trunk keeps
   `HitZone = "body"`, carries no `ZonesOnly`, `passesThrough` answers false and `targetOf` answers
   the trunk itself. A one-box zone keeps its bare part name (`ZoneChest`), which three other specs
   and the Validator's log line already use.
   *Verify:* `describe("the boar's trunk is still a target")` in `deer_hitbox.spec`, and the whole of
   `boar_zones.spec`'s boar describe, unchanged.
5. **The three deer are NOT one shape scaled, and the dispatch's parenthetical is refuted.** The
   stag's volumes taken to the hind's 0.8553 leave **131** cells of air on her mesh, and to the
   calf's 0.495 leave **312** of its 649 answering rays. `Red_Deer_NoAlpha`, `Red_Deer_Doe_NoAlpha`
   and `Red_Deer_Calf_NoAlpha` are three models, not one at three sizes. So the hind and the calf
   carry their own `zones` rows in `Boar.CONFIG.KINDS`, in their own studs, and `Body.kindGeometry`
   does not scale those. `BODY_SIZE` **is** still one box scaled — a hind's trunk IS the stag's
   times her scale — and why the two answers differ is written where both live: a trunk is a
   convention this file chooses, a hitbox is a measurement of somebody else's mesh.
   *Verify:* the comment on `KINDS.hind.zones`, and `deer_hitbox.spec`'s assertion that the built
   box is the kind's own and **not** the species table at that kind's scale (it refuses a match
   within 0.05 studs of the scaled value).
6. **The fit was iterated, four cycles, same instrument, and then verified by a second one.**
   `<runs-dir>/280-fit1.txt`..`280-fit4.txt`: flank AIR **125 → 0 → 0 → 0**, and 0 from all four
   directions at the end. Each kind's boxes were then grown from ITS OWN silhouettes
   (`280-autofit.luau`, 0.035-stud grid) and re-measured by an independent sweep at a 0.05-stud grid
   (`280-verify1.txt`): **AIR 0 on stag, hind and calf, from the flank, from above, from the front
   and from behind**, with 4,408 / 2,501 / 762 mesh-crossing flank rays covered.
   *Verify:* the measurement block in `SPECIES.reddeer.ZONES` carries the method and the numbers.
7. **The volumes are clipped to the anatomy, not just to the mesh.** The grower was free to grow a
   box into its neighbour and did: the stag's thorax reached z +1.175 — half the barrel charged as a
   VITAL — and the calf's loin swallowed its own rump so no ray could reach `rear` (the harness
   said *"calf: no ray reached the rear zone"*). Every `chest`, `body` and `rear` box is clipped to
   the last-rib line at z +0.80 and the rump line at +2.10, as fractions of each kind's own trunk.
   Clipping only shrinks, so AIR stays 0 by construction.
8. **The hit card and the drive report keep working, by construction.** `HitLog.Shape.dot`
   normalises in the TRUNK box, and this task does not change `BODY_SIZE` by a thousandth. No
   `Report`, `HitLog`, `BoarArt` or silhouette file is touched.
   *Verify:* `git diff --stat main..HEAD`; `report_silhouette.spec` and `hit_card.spec` are inside
   the 34/34.
9. **Both invariants are asserted, not one of them dropped.** `boar_kinds.spec` now asserts that a
   BOAR's chest, rump and legs stand PROUD of its trunk and that a DEER's volumes sit INSIDE it in X
   and Z. +Y is deliberately excluded and the reason is in its place — `SPECIES.reddeer`'s own
   comment says the head, the neck and the antlers stand above the back line, and the measured skull
   reaches y +2.64 over a box that tops out at +2.40. The FLOOR is asserted: a volume under the turf
   would be hittable and invisible.
10. **The removed deer-probe table is archived, not deleted** (rule 7):
    `backups/2026-10-26_task-280_boar_zones-deer-twelve-probes.md` — what it was, why a fraction
    table cannot name the same place on three different meshes, and the thing nine of its twelve
    points could never see (a ray at a box's own centre answers that box's zone whether or not the
    box is on the animal).
    **Scope membership** (standing rule G): `deer_hitbox.spec` is in the `boar` and `weapon` scopes;
    `python tools/studio_mcp.py selftest` and `python tools/agents.py selftest` both pass.

## The boar's air gap, measured (dispatch item 3)

**The boar is left alone, and here is its number, measured rather than asserted.** The same rule
does NOT fall out of the same data: the boar's four zones are bone-fitted exactly as the deer's
were, and its trunk is `2 x 3 x 5.5` against a drawn male measuring `1.40 x 3.26 x 5.50` — so the
collision box is **0.60 studs wider and 0.26 taller than the animal it holds**, and its `body`
fallback owns that gap down both flanks and under the belly. Turning the same rule on would need
the same per-kind mesh fit for four more models (male, female, cub, legendary), which is a task and
not a line. Queued as **280b**.

## What I could NOT verify (rule 8)

- **THE LIVE CLICK PROOF IS NOT DONE, and nothing here should be read as if it were.** The dispatch
  asks for a real shot at a standing hind at ~25 m. I stood a frozen hind 90 studs dead ahead of the
  player in DEV Play, put her coat back to the way the game draws her, and fired two aimed
  `FireRequest`s from the client — one at the thorax box's own centre, one at the air under her
  neck. **Neither reached the server.** `Weapon.stats()` afterwards read
  `shots=0 flightShots=0 badRequests=0 refused=0` and `ServerStorage.DHLastHits` did not exist, so
  the StudioMCP thread's `FireServer` is being dropped rather than refused — a harness limit, not a
  game fault. The route left is a real hardware click (`click.ps1`), which needs the screen-pixel
  mapping of the Studio viewport. **So no shot has gone down the server's own shot path since this
  change, and nobody has seen a deer's hit card with these volumes.**
- No frame of the hit CARD, for the same reason.
- The calf's coverage is the worst of the three — 762 of 1,606 mesh-crossing flank rays — and its
  four leg boxes are stubs the greedy fit could not grow (the front pair is 0.14 studs tall). AIR is
  0 on it, so it is harder to hit than it looks and never hittable where it is not, which is the
  right way round; but it is not a good fit. Queued as **280a**.
- The volumes were fitted and are tested in the BIND POSE. A walking or running deer's legs and head
  move inside boxes welded to the trunk; how far they move is not measured here.
