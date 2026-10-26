# Task 280 — the deer hitbox is the deer, not the air around it

Task: 280
Round: 2
Base: `main` @ `e57710ac`
Code commit: `886dd7af0a1c288dce21147f672599e37bfb2642`

```
[harness] PASS: 34/34 checks @ 886dd7af0a1c288dce21147f672599e37bfb2642 (clean tree) scope=all
```

The last commit touching `src/`, `tests/` or `tools/` is `273a5863`; `886dd7af` adds round 1's
`RESULT.md` and nothing else, so the line covers every code file (git workflow step 4).

`test2` is **N/A**: nothing here is under `TWO_PLAYER_PATHS`. The files touched are
`src/server/Boar/`, `src/server/Weapon/`, `src/client/Weapon/`, `src/shared/Shotgun/`,
`tests/server/`, `tools/studio_mcp.py` and `backups/` (Director decision 2026-10-03 — the weapon
and the animal need the one-player line only).

## PLAN (core quality protocol step 0)

**(a) REAL LIFE.** A bullet connects where the animal is and nowhere else. A red stag stands about
1.36 m at the withers and measures 0.49 m across; the space in front of its brisket, under its neck
and between its legs is air.

**(b) MEASURED NOW**, not read off the code. The pre-fix geometry, swept with the same instrument
used afterwards (`<runs-dir>/280-fit0-prefix.txt`), on a real stag built by `Runtime:spawn` from the
real model in a DEV Play session: **1,999 of 3,631 answering flank rays hit a zone part and never
crossed the drawn animal** — 55 % of every "hit" was a hit on nothing. 281 from above, 372 from the
front, 371 from behind.

**(c) TARGET.** That number, from four directions, on all three deer kinds: **0**.

**(d) LEVER.** `Boar.CONFIG.SPECIES.reddeer.ZONES` and the two new `KINDS.*.zones` rows (the
volumes); `Boar.Body.create` (what the trunk publishes); `Shotgun.Pierce`, `Weapon.Hits.targetOf`
and the two casters that read it (what a bullet does with them).

**(e) HOW IT IS MEASURED AFTER.** The same sweep, kept as `tests/server/deer_hitbox.spec.luau`.

**ONE PREMISE OF THE DISPATCH IS REFUTED BY MEASUREMENT** — item 1's mechanism ("a ray passes
through it") cannot be `CanQuery`. See claim 2. The goal is met by another route.

## What changed since round 1

Round 1's finding was right and is fixed in claim 3: the client's hit-claim cast had to pass through
the trunk exactly as the server's does, so the rule moved to **one owner both sides require**,
`src/shared/Shotgun/Pierce.luau`. Nine notes are addressed; the four that were factually wrong
(the archive's mechanism, the stale "one shape scaled" header, the reachability list missing `body`,
the box count) are corrected, and the two weak assertions the Reviewer named now measure something.

## Claims

1. **The air Karen hit is a MISS and the animal is a hit, proved against the DRAWN MESH, on all
   three kinds.** `deer_hitbox.spec` freezes a stag, a hind and a calf in the bind pose the volumes
   were measured in, makes the drawn mesh queryable for the length of the file, and sweeps a
   0.25-stud grid of real flank rays: **every** ray that answers a zone must also cross the mesh
   (AIR must be 0) and the sweep must find the animal at all (`both >= 20`, so a zero from an empty
   world cannot pass). Four named air points per kind — under the neck, in front of the chest,
   between the legs, under the barrel — must each answer **nothing**, and each is now proved to be
   INSIDE the trunk by an Include cast that must come back with the trunk (round 1's note: the old
   check compared a literal fraction with 0.5 and could not fail).
   *Verify:* read the file; the grid case errors with the first offending `(y, z)`.
2. **`CanQuery = false` CANNOT take the trunk out of a cast, measured with a control.**
   `<runs-dir>/280-diag4.luau`, a 2x2x2 control behind a 4x4x4, four rows, one variable at a time:
   `CanQuery=false, CanCollide=true` → the big part is STILL returned; `CanQuery=false,
   CanCollide=false` → it is skipped and the control behind it is returned; the same both ways round
   whether `CanQuery` is written before or after parenting. A deer's trunk must collide.
   *Verify:* the measurement is written out in `src/shared/Shotgun/Pierce.luau`.
   `Boar.Body.attachVisual`'s `CanQuery = false` on the drawn mesh is untouched and still works,
   because that mesh is `CanCollide = false`.
3. **ONE OWNER DECIDES WHAT A BULLET STOPS ON, and that is round 1's finding fixed at the root.**
   `Shotgun.Pierce.cast` holds the predicate and the step-past loop; the server's
   `Weapon.Cast.world` and the client's `Weapon.Claim.world` and `Claim.only` all call it. Before
   this, `Claim.only` cast `Include = { target.root }` — which takes that instance AND ITS
   DESCENDANTS — so it met the TRUNK, nearer than every volume now inside it; `Hits.targetOf`
   answered nil for a `ZonesOnly` root and `judgeClaimFor` refused every deer claim as
   `claim-part`.
   *Verify:* the new case `"gives the CLIENT'S CLAIM a zone part and not the trunk"` — an Include
   cast at each kind's chest must not return the trunk, and `targetOf` on what it does return must
   answer `(trunk, "chest")`, which is `judgeClaimFor`'s own first test. It fails on `a56f9727`.
   `Pierce.cast` also answers **nil** when it runs out of pass-throughs while still standing on one
   (round 1's note: the bound used to return the trunk, stopping the pellet on an invisible box).
4. **The step-past could not be a filter.** `FilterDescendantsInstances` means "these instances AND
   THEIR DESCENDANTS" and every zone part is a CHILD of the trunk; excluding the trunk excluded the
   volumes behind it, and the harness said so in one line on all three kinds — *"chest box 1
   answered no zone at its own centre"*. A ray whose origin is inside a part does not hit that part,
   so the continuation starts `Pierce.STEP` = 1e-3 studs past the surface with the same params.
   *Verify:* `Pierce.cast`; `distance` is still measured from the caller's own origin and the
   caller's `ignore` table is neither modified nor copied.
5. **A boar is untouched, and a case fails if it stops being untouched.** `TRUNK_HITTABLE` is absent
   from `Boar.CONFIG.ZONES`, so the trunk keeps `HitZone = "body"`, carries no `ZonesOnly`,
   `passesThrough` answers false and `targetOf` answers the trunk. A one-box zone keeps its bare
   part name (`ZoneChest`), which three specs and the Validator's log line use.
   *Verify:* `describe("the boar's trunk is still a target")`, and `boar_zones.spec`'s boar describe.
6. **The three deer are NOT one shape scaled, and the dispatch's parenthetical is refuted.** The
   stag's volumes at the hind's 0.8553 leave **131** cells of air on her mesh and at the calf's
   0.495 leave **312** of its 649 answering rays: three models, not one at three sizes. The hind and
   the calf carry their own `zones` rows in `Boar.CONFIG.KINDS`, in their own studs, unscaled.
   `BODY_SIZE` **is** still one box scaled, and why the two answers differ is written where both
   live.
   *Verify:* the comment on `KINDS.hind.zones`, and the case asserting the built box is the kind's
   own and **not** the species table at that kind's scale.
7. **The fit was iterated four cycles on one instrument and verified by a second.**
   `<runs-dir>/280-fit1.txt`..`fit4.txt`: flank AIR **125 → 0 → 0 → 0**, 0 from all four directions.
   Each kind's boxes were then grown from its own silhouettes (0.035-stud grid) and re-measured by
   an independent sweep at 0.05 (`280-verify1.txt`): **AIR 0 on stag, hind and calf from the flank,
   from above, from the front and from behind**, covering 4,408 / 2,501 / 762 mesh-crossing flank
   rays. Every box was then CLIPPED to the anatomy (last rib at z +0.80, rump at +2.10, as fractions
   of each kind's own trunk) because the grower grew into its neighbours — the stag's thorax reached
   z +1.175, half the barrel charged as a VITAL, and the calf's loin swallowed its rump so no ray
   reached `rear`. Clipping only shrinks, so AIR stays 0 by construction.
8. **The hit card and the drive report keep working, by construction.** `HitLog.Shape.dot`
   normalises in the TRUNK box and this task does not change `BODY_SIZE` by a thousandth. No
   `Report`, `HitLog`, `BoarArt` or silhouette file is touched.
   *Verify:* `git diff --stat main..HEAD`.
9. **Both invariants are asserted, not one dropped.** `boar_kinds.spec` asserts that a BOAR's chest,
   rump and legs stand PROUD of its trunk and a DEER's volumes sit INSIDE it in X and Z. +Y is
   excluded with the reason in its place (the head, neck and antlers stand above the back line; the
   measured skull reaches y +2.64 over a box topping out at +2.40). The FLOOR is asserted.
10. **Rule 7 and standing rule G.** The removed twelve-probe table is archived with what it was, why
    a fraction table cannot name the same place on three meshes, and the thing nine of its twelve
    points could never see — and the archive now records the mechanism that SHIPPED, not the refuted
    `CanQuery` one. `deer_hitbox.spec` is in the `boar` and `weapon` scopes;
    `tools/studio_mcp.py selftest` and `tools/agents.py selftest` both pass.

## The boar's air gap, measured (dispatch item 3)

**The boar is left alone, and here is its number.** The same rule does not fall out of the same
data: its four zones are bone-fitted exactly as the deer's were, and its trunk is `2 x 3 x 5.5`
against a drawn male measuring `1.40 x 3.26 x 5.50` — the box is **0.60 studs wider and 0.26 taller
than the animal it holds**, and its `body` fallback owns that gap down both flanks and under the
belly. Turning the same rule on needs the same per-kind mesh fit for four more models, which is a
task and not a line. Queued as **280b**.

## What I could NOT verify (rule 8)

- **THE LIVE CLICK PROOF IS NOT DONE, and nothing here should be read as if it were.** I stood a
  frozen hind 90 studs dead ahead of the player in DEV Play, with her coat drawn the way the game
  draws it, and fired two aimed `FireRequest`s from the client — one at the thorax box's own centre,
  one at the air under her neck. **Neither reached the server**: `Weapon.stats()` afterwards read
  `shots=0 flightShots=0 badRequests=0 refused=0` and `ServerStorage.DHLastHits` did not exist, so
  the StudioMCP thread's `FireServer` is dropped rather than refused — a harness limit, not a game
  fault. The route left is a real hardware click (`click.ps1`), which needs the screen-pixel mapping
  of the Studio viewport. **So no shot has gone down the server's own shot path since this change,
  and nobody has seen a deer's hit card with these volumes.**
- No frame of the hit CARD, for the same reason. What HAS been looked at is two frames of the
  volumes drawn over the model (`<runs-dir>/280-volumes-eye.png`, `280-hind-zoom.png`,
  `280-stag-zoom.png`) — instrumentation, from the player's eye height, not a player's shot.
- The calf's coverage is the worst of the three (762 of 1,606 mesh-crossing flank rays) and its four
  leg boxes are stubs the greedy fit could not grow. AIR is 0 on it, so it is harder to hit than it
  looks and never hittable where it is not — the right way round, but not a good fit. **280a.**
- The DORSAL BAND is uncovered on all three kinds and round 1's note is right that the comment's own
  list did not name it: the measured back line is y +2.30 over z -0.03..+1.97 against a thorax box
  topping out at +1.80 and a loin box at +1.98, so the top 0.32–0.50 studs of the spine is a MISS.
  Queued with **280a**.
- `docs/design/red-deer.md` §7.3 and `docs/design/hit-zones.md` §4 still describe the `PROTRUSION`
  rules this task replaced for the deer. Nothing in the game is wrong because of it; queued.
- The volumes are fitted and tested in the BIND POSE. How far a running deer's legs and head move
  inside boxes welded to the trunk is not measured here.
