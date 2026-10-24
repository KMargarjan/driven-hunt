# Task 255 review request

Task: 255
Round: 2
Base: `eec467ae` (main)
Code commit: `197abe26cba2c0ebb9ff62227de0d87c97d57acb`

```
[harness] PASS: 34/34 checks @ 197abe26cba2c0ebb9ff62227de0d87c97d57acb (clean tree) scope=all
[harness2] PASS: 36/36 checks @ 197abe26cba2c0ebb9ff62227de0d87c97d57acb (clean tree)
```

## What changed

Four fixes from Karen's evening test. **Two are built; two are escalated, and that is the finding
rather than a shortfall** -- item 3's premise is refuted by measurement and item 4's upload is a
human action the dispatch itself routes through the Director.

1. **The licence popup never fires while nobody knows what he owns.** `Weapon.askLicences` answers
   `(held, known)`; `Rules.licencesUnknown` is a new pure predicate; both the aim advice and the fire
   refusal read one call.
2. **The end-of-drive bag is laid out in rows that do not overlap**, ordered by species then size.
   `SPACING_STUDS` 6 -> 9, `ROW_SPACING_STUDS` 8 -> 9, `PER_ROW` 6 -> 4, `MAX_ANIMALS` 12 -> 16, and
   `Scene.ordered` is new.
3. **The leap** -- measured, escalated, no code.
4. **The deer's hit and bark** -- researched, escalated, no code.

## Claims

### 1. The licence gate now tells "he holds none" from "nobody has answered yet", and only the second one is new

`src/server/Weapon/init.luau` `askLicences` returns two values: `(nil, true)` with no provider at all,
`(nil, false)` for a wired provider that errored or answered a non-table, `(held, true)` for a table.
`src/server/Weapon/Rules.luau` gains `Rules.licencesUnknown(known)` and `Context.licencesKnown`, and
`Rules.refuse` skips the `LICENCE` question only on an explicit `false`.

**Verify:** read `askLicences`' header and `Rules.refuse`'s `LICENCE` branch. `Rules.unlicensed` is
UNCHANGED and still answers `true` for `(deer, nil)` -- `deer.spec`, `weapon_rules.spec` and
`licence_popup.spec` all drive it that way and all still pass.

### 2. The cause is three modules agreeing, and the chain is readable without running anything

`Economy.ownedOf` returns `nil` -- not `{}` -- for a player with no open profile, and its own comment
says the difference is load-bearing. `Shop.licencesFor(nil)` returns `nil`. `Licences.allows(species,
nil, rows)` returns `false`. So an unopened profile and an empty one were the same answer.

**Verify:** `src/server/Economy/init.luau` `Economy.ownedOf`; `src/shared/Shop/init.luau`
`Shop.licencesFor`; `src/shared/Licences/init.luau` `Licences.allows`. Then `Economy.load`'s warn
path -- *"he earns nothing this drive and nothing is saved. Retried at the next drive start"* -- which
is Karen's *"just after a while I can shoot"*.

### 3. It is proved through the PRODUCTION wire, on the live handler, not through a hand-written table

`tests/server/licence_popup.spec.luau`, case *"neither advises nor refuses while nobody knows what he
owns, and does both once they do"*: it builds the provider both composition roots install
(`ShopData.licencesFor(Economy.ownedOf(player.UserId))`), asserts it answers nil for a userId with no
profile, drives `Weapon.onActionRequest(subject, "Aim", ...)` twice -- once with an unknown provider
and once with an open-and-empty one -- and asserts `aimAdvised` moves on the second and not the first.
It asserts the fire gate through `Rules.refuse` with the same two values.

**Verify:** the harness note `licence_popup: UNKNOWN aim advised +0 (unknown skips 1), KNOWN-and-empty
aim advised +1` in the run above. Delete the `known and` from the Aim branch and the case fails.

### 4. It is not a hole: the man who really has no card is still refused

`Economy.load` writes `ownedSets[userId] = {}` for an open profile, so his provider answers a TABLE.
The spec asserts `Rules.refuse({ target = deer, licences = ShopData.licencesFor({}), licencesKnown =
true }) == Rules.REASON.LICENCE`.

**Verify:** that assertion, and `Economy.load`'s `ownedSets[userId] = ...` line.

### 5. The bag overlapped, and the number is 1.9202 studs

A display lies on its SIDE -- `Body.lyingCFrame` rolls it about the long axis, standing the mesh's X
up and laying its **Y** across the row -- so what an animal takes up sideways is its STANDING HEIGHT.
MEASURED off the loaded meshes in a live Play session of the Forest Test, 2026-10-24
(`MeshPart.Size` read back off each animal's own `Visual`, plus the published stag model):

| kind | mesh X | Y | Z | rolled ACROSS | ALONG |
|---|---|---|---|---|---|
| boar male | 1.4011 | 3.2573 | 5.5000 | 3.2573 | 5.5000 |
| female | 1.2019 | 2.6473 | 4.6750 | 2.6473 | 4.6750 |
| cub | 0.6177 | 1.4390 | 2.4750 | 1.4390 | 2.4750 |
| stag | 3.4666 | 7.9202 | 7.0500 | 7.9202 | 7.0500 |

`7.9202 - 6 = 1.9202` studs of stag-on-stag overlap. `SPACING_STUDS` is 9 and
`ROW_SPACING_STUDS` 9 (the legendary boar is 7.4250 long).

**Verify:** `Match.CONFIG.SCENE.SPACING_STUDS`' comment carries the table; `match_scene.spec`'s case
*"spaces the rows wide enough that the biggest animal in the game cannot overlap"* carries the same
four rows as data and asserts both spacings clear every one.

### 6. Staged at the cap with the REAL models, the worst gap is +1.080 studs and nothing overlaps

Sixteen kills -- legendary, 3 male, 2 female, 3 cub, 3 stag, 2 hind, 2 calf -- laid out at
`SPACING_STUDS` 9 / `ROW_SPACING_STUDS` 9 / `PER_ROW` 4 with each kind's published model loaded,
scaled and posed by `Boar.lyingCFrame`, then every pair's WORLD-space extents compared.

* **worst flat gap between any two animals: `+1.080` studs, `stag` vs `stag`** (positive = clear);
* lowest visible point of every animal sits ON the plate (`-0.000`). **Reported as BY CONSTRUCTION,
  not as a terrain measurement** (rule E): `lyingCFrame` lifts by half the rolled height and the
  plate is flat, so a 0.00 here is arithmetic and says nothing about sloped ground.

**Verify:** `.screenshots/20261024T185521Z-t255-rows-eye.png` (camera 3.5 studs above the plate, the
height a man stands at the ring) and `.screenshots/20261024T185525Z-t255-rows-high.png` -- **both
looked at**: four tidy rows of four, three stags side by side with clear grass and clear antlers
between them. **One honest caveat:** the BOAR models in those two frames came from an id I picked
(`73934667856496`) and they read 1.14 studs across, not the game's measured 3.2573 -- so the boars in
the picture are not the game's boars. The deer are exact (7.92 / 6.77 / 3.92), and the worst pair is
stag-on-stag, so the claim does not rest on the boars.

### 7. The order is by species then size, it is data, the sort is stable, and ROUND 1 GOT THE CAP BACKWARDS

`Scene.ordered(kills, cfg)` ranks a kill by its kind's place in `SCENE.KIND_ORDER` (`legendary, male,
female, cub, stag, hind, calf`) and breaks ties on the SHOT index, so `Scene` still never learns what
a boar is. It returns a NEW list -- `Match` keeps reading `kills` for the score and the report.

**ROUND 1'S FINDING 1 WAS CORRECT AND IT WAS MINE.** `Scene.build` computed `count = math.min(#kills,
MAX_ANIMALS)` and then called `Scene.ordered(kills, cfg)` on the WHOLE list, so `laidOut[1..count]`
was the first `count` of the SORTED bag -- sort-then-cap, the exact failure the comment three lines
above said the chosen order prevents. At the shipped numbers a drive of 4 calves then 16 males laid
out 16 MALES, four of them shot after the cap. `Scene.build` now takes the slice on the SHOT order
first -- `table.move(kills, 1, count, 1, {})` -- and `Scene.ordered` never sees the rest.

**Verify:** `Scene.build`'s `capped` local; `Scene.ordered`; `match_scene.spec`'s case *"orders the
bag by species then size, stably, and leaves an unknown kind at the back"* (which also asserts every
kind in `ANIMAL_SCALES` appears in `KIND_ORDER`).

### 7b. A case now drives `Scene.build`'s ordering, and it FAILS on round 1's code

Round 1's finding 2 was that nothing did. `match_scene.spec`'s new case *"drops the kills she shot
LAST, never the ones she shot first, whatever species they are"* builds its own config **with** a
`KIND_ORDER` -- this file's `CONFIG` deliberately has none, which is now declared where it is
declared -- drives `Scene.build` with `cap` calves followed by `cap * 4` males, and reads the `Kind`
attribute off what landed in the folder. It asserts `calf` `cap` times; **round 1's code answers
`male` `cap` times.** Its second half proves the tidying still happens INSIDE the slice: a
half-and-half slice comes out males-first and stays half and half.

The old case is renamed to what it actually asserted (*"sorts exactly the list it is handed, and
reads nothing beyond it"*) and strengthened -- every kill handed in comes back, none dropped, so
`Scene.ordered` has no cap in it and `Scene.build` is the only thing that drops anything.

**Verify:** both cases; and the harness note `match_scene: cap 4 of 8 kills -> ...` in the run above.

### 8. The cap is 16 and not the Director's 20+, and the binding number is the lodge's chimney

MEASURED off the live lobby (`<runs-dir>/255-yard.luau`): the `Gather` pad is **56 x 56** at x -50,
the lodge's chimney is at x -21, so **29.0 studs** from the gathering's centre, and `lobby.spec` holds
the whole scene inside both. Back through `cornerReachFor` -> `ringRadiusFor` -> `layoutExtent`, a
reach of 28 allows a block of half-diagonal 20, which at spacing 9 is `(PER_ROW-1)^2 + (rows-1)^2 <=
19.75`: **4 x 4 fits (18), 5 x 4 does not (25)**. A bigger pad does not help. Shipped: reach 27.09.

**Verify:** the harness note `lobby: the gathering square is 54.2 studs across (16 animals) inside a
56 x 56 yard -- 0.9 studs of margin`; `match_scene.spec`'s case *"lays the whole cap out in four rows"*
asserts `cornerReachFor(cap) < 28` AND that `PER_ROW = 5` would exceed 29. `ESCALATE.md` carries the
decision with the full table.

### 9. Round 1's six non-blocking notes: five taken in this round, one was already true

Taken: `Scene.rowLayout`'s header (it said index 1 is *"the first animal shot"* and the front row is
*"the first animals that were shot"* -- both false after this task -- and `Scene.ordered` had been
inserted between that header and its own function, so the sentences read as if they described the
sort; `ordered` is moved above the pair and the two sentences corrected); `Scene.build`'s header (it
never said the layout is no longer the shot order); the spec `CONFIG`'s missing `KIND_ORDER` (now
declared as deliberate, with the task-173 ask-order case named); the licence fix's COST (a case now
states it out loud -- a refused session lock leaves `ownedSets[userId]` nil and the question skipped
for that whole drive, with `stats.licenceUnknown` counting it); and `lobby.spec`'s broken sentence.

The sixth is this request's own claim 7 and it is rewritten above.

### 10. Four task-168 cases failed on the first gate run and were rewritten, not weakened

`match_scene.spec`'s task-168 block had `6`, `12`, `15` and `4` typed into it. Those cases are about
the SHAPE (one row, rows behind it, a short last row centred on its own width, the people outside all
of it) and the retune broke them for reasons none of them asserts. They now read `Scene.perRow(LIVE)`
and `MAX_ANIMALS`. Three got STRONGER: the split case walks EVERY row's depth (it checked only rows 1
and 2); the centring case asserts both parities; the extent case asserts `layoutExtent` against the
arithmetic of the two spacings. A fifth, `ringRadiusFor(3) == 14`, is now a BOUNDARY asserted from
both sides -- the floor holds to `floor((RING - MARGIN) * 2 / SPACING) + 1` animals and one more
grows it.

**Verify:** the rewritten block, and the two fix commits' messages (`4472f20c`, `f4d78694`).

### 11. What I could not verify, and the two escalations

* **Item 3's premise is refuted and nothing was shipped.** The published leap clip, measured on the
  stag's own rig at 49 samples (`AnimationTrack.Length` is 0 in Edit, so this ran in Play): the
  highest bone rises **0.7961 studs = 0.223 m** at t = 0.4167, against the brief's target of 0.8-1.2 m
  (= 2.85-4.28 studs, at this project's own `1 stud = 0.2804 m` from
  `SPECIES.reddeer.BODY_SIZE`). And **nothing in `src/server/Boar/` ever writes a vertical velocity**
  -- the mover is `VelocityConstraintMode.Plane` and a grep for `AssemblyLinearVelocity =`,
  `ApplyImpulse`, `Velocity =` and `VectorVelocity` is empty -- so there is no height dial to turn.
  **I did not reproduce her defect** (rule H): ~800 s of live drives across all three layouts tracked
  exactly ONE deer, whose worst airborne excursion was 0.23 studs, and it despawned before the band.
  A deer-sized unanchored probe IS ejected 6.45 studs (1.81 m) at a crossing, but it carried no
  `Upright` constraint, so that is suggestive and not proof. `ESCALATE.md` has all of it, three
  options and one question for Karen.
* **Item 4 shipped no code and that is the dispatch's own route.** Four CC0 deer BARKS were found
  (795554, 203593, 710264, 569926; 653533 and 351113 for the hit) with their licences read on their
  pages; L-071's *"no CC0 one exists"* was a fact about the search METHOD. The asset we already own
  carries no bark -- measured on the uploaded bytes, every short event sits inside the long roars'
  spectral range on all four columns. No `PlaybackRegion` support was added, deliberately: a region
  reader with no id to read for is code written for a guess. `ESCALATE.md` is `NEEDS DIRECTOR`.
* **The unknown window could not be reproduced live** and the reason is in the code: `Store`'s own
  header says *"in Studio nothing ever calls `Store.live`"*, so the Forest Test uses `Store.memory`
  and the profile opens immediately. The 55.9 s Forest Test session I did run shows the
  `LicenceCard` frame built with its title `NO DEER LICENCE` and `Visible = false` throughout -- which
  is consistent but is not the window.
* **Nobody here can hear anything.** Item 4's spectral argument is about measurable structure only.

## Forest Test

Attributes read before (`<runs-dir>/attrs-id.luau`) and again at the end: **identical**, and nothing
was written --
`DHFlag_BOAR_BEHAVIOUR=true DHFlag_BOAR_MODEL=true DHFlag_COINS=true DHFlag_DEER_ROAD_LEAP=true
DHFlag_DRIVE_BOTS=true DHFlag_HORN=true DHFlag_LICENCE_POPUP=true DHFlag_LOBBY=true DHFlag_SHOP=true
DHForestStartRole=hunter DHShopTestGrant=true`. Play was stopped, the place left in Edit and its
window CLOSED before either harness run; both runs report `[server] report comes from the DEV place
(136410205938347)`.
