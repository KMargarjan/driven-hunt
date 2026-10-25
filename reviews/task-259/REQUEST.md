# Task 259 -- real-life shooting part 2: the true sights, the kill zones, the foliage reading

Task: 259
Round: 1
Base: main @ 6e2b11a7
Code commit: 968e98a1f868376e1890c0335c0316d0fd27006b

```
[harness] PASS: 34/34 checks @ 968e98a1f868376e1890c0335c0316d0fd27006b (clean tree) scope=all
```

`[harness2]` is **N/A**: nothing here touches `TWO_PLAYER_PATHS`. The files changed are
`src/shared/Ballistics/`, `src/shared/Shotgun/`, `src/server/Weapon/init.luau`,
`src/server/Boar/init.luau`, three server specs and `tools/studio_mcp.py` -- weapon, boar and tools,
which the Director's 2026-10-03 decision puts on the one-player line for the review round and for the
PR to `main`.

**Items 1, 2 and 4 of the dispatch. Item 3 (the real-click lead proof) is NOT in this task** -- the
route is proved and written down, the time ran out, and it is queued as TASKS.md 259a with the exact
shape it needs. Said here rather than left to be noticed.

## What changed

Karen, 2026-10-24: *"we need to work on rifle acuracy when aiming with scope, it seems there is a bit
off"* / *"when boar is running we need to aim in empty space to get hit in head neck or heart like in
real life smae with other animals"*.

1. **`Ballistics.boreOrigin` and `Ballistics.convergeAim`** -- two pure functions, the owner's two
   inline lines named. `BORE_ON_SIGHT_LINE` ships **false**, which is today bit for bit.
2. **`WOUND.DAMAGE_BY_WEAPON.rifle.body` 100 -> 90**, because `LETHAL` is 100 and a paunch shot was
   dropping a boar on the spot.
3. **`tests/server/sights.spec.luau`** and **`tests/server/kill_zones.spec.luau`**, both registered in
   `SCOPE_SPECS`.
4. **Nothing changed for the foliage**, as instructed: measured and reported only.

Note: `docs/research/2026-10-24-real-shooting.md` section 12 (this task's own).
`ESCALATE.md` 2026-10-25 carries the one design decision.

## Claims

1. **The sights themselves are TRUE, and the measurement says which three candidates were ruled
   out.** The rifle's reticle is a screen-space crosshair at the viewport centre on a ScreenGui with
   `IgnoreGuiInset = true`; the semi-auto's dot and the shotgun's bead are 3D parts that
   `Mode.aimOffset` lays ON the camera axis (the cheek angle is applied ABOUT the bead, so it rotates
   the gun and not the sight line); the sway moves the CAMERA, so the reticle keeps marking the bore.
   *Verify:* `Hud.init`'s `screen.IgnoreGuiInset`, the `Reticle` frame's `Position`/`AnchorPoint`;
   `Mode.aimOffset`'s expression and `camera_mode.spec`'s bead case; `Mode.cameraCFrame`'s use of
   `scopeSwayDeg` against `Input.fire` sending `camera.CFrame.LookVector`. Research note section 12.2.

2. **The defect is the BORE, not the sights: the eye-to-muzzle offset is 0.73 studs and it is
   MEASURED in the place.** 2026-10-25, DEV Play, first person, both guns, read in the live camera's
   own frame: shotgun (+0.741, -0.201, -5.274), rifle (+0.718, -0.135, -5.249).
   *Verify:* `driven-hunt-runs/259-eye-muzzle.luau` and `259-equip-probe.luau` are the read-only
   probes; the figures are quoted in `Ballistics.boreOrigin`'s header, in `sights.spec`'s `OFFSETS`
   and in research note 12.1. The cause is `Hardware`'s one line `tool.Grip = config.GRIP`: the gun
   is welded to the character's right hand, which is 20 cm right of the eye, and in first person the
   player sees the viewmodel instead.

3. **The convergence cancels that offset AT THE AIM POINT AND NOWHERE ELSE, so a shot whose aim ray
   hits nothing lands 0.4 studs or more to the RIGHT of the reticle at every range -- and that is the
   case Karen named.** Leading a running animal means aiming at empty space.
   *Verify:* `sights.spec`'s describe *"when the aim ray lands PAST the target -- the defect"*. Three
   cases: the error is >= 0.4 studs and positive (right) at 25 / 50 / 100 m and >= 0.6 at its worst;
   a gun held UNDER the eye has exactly zero sideways error and a vertical one, which names the
   mechanism rather than the symptom; and the error SHRINKS when the thing behind the animal is
   nearer, which is why it reads as unreliable rather than as a zero. They are LOWER bounds on
   purpose, so the defect cannot be made smaller without the spec saying so.

4. **When the aim ray lands ON the target, every gun and load is within 1.68 cm of the reticle at
   25 / 50 / 100 m, for ANY muzzle placement.** This is the baseline claim 3 is measured against, and
   it is research note section 4's table re-derived from the stepper instead of from the closed form.
   The asserted bound is `BALLISTIC_BOUND_STUDS = 0.06` studs, which is 1.68 cm -- the note's 1.6 cm
   with a hair of room for the stepper's discretisation, as the spec's own comment says.
   *Verify:* `sights.spec`'s first describe -- 5 (gun, load) x 3 ranges x 4 holds, each flown through
   the real `Flight` with the real sub-step cap against a plane cast, bounded at 0.06 studs.

5. **`BORE_ON_SIGHT_LINE = false` is today bit for bit, by IDENTITY and not by nearness.**
   *Verify:* `sights.spec` -- `expect(Ballistics.boreOrigin(EYE, LOOK, muzzle, false)).to.equal(muzzle)`
   and the same for `nil`; plus the shipped-value case `expect(...BORE_ON_SIGHT_LINE).to.equal(false)`,
   so none of the "defect" cases above describes a game Karen is not playing. In
   `Weapon.onFireRequest`, `origin` replaces `muzzle` in exactly three places (the launch, `stopAt`,
   the safety line) and all three are the same `Vector3` with the row off.

6. **At `true` the fix holds the ballistic bound even when the aim ray misses, for every gun, range
   and hold, and it changes nothing in the case that was already right.** It also cannot launch the
   bullet out of the back of the player's head.
   *Verify:* `sights.spec`'s last four cases -- the sweep at `true` with the ray missing; the
   on-target comparison at both values agreeing within 0.01 studs; the origin lying on the ray
   (cross product < 1e-5) at the muzzle's own DEPTH (5.274); and a muzzle BEHIND the eye answering
   the eye itself.

7. **THE KILL-ZONE GEOMETRY WAS ALREADY RIGHT AND NOTHING WAS MOVED.** Both species' boxes are on the
   drawn anatomy and were measured on the rig, with the vitals behind the shoulder.
   *Verify:* read `Boar.CONFIG.ZONES`' own header (task 119's bone readings: nose z -2.388, head
   z -1.279, `Neck` z -0.866) and `Boar.CONFIG.SPECIES.reddeer.ZONES`' (task 223: *"the two agree to
   0.02 studs on every bone"*, `hip_1_f` at z -0.53 and `thigh_f` at -0.63 putting heart and lungs
   behind the shoulder). `git diff` shows no change to either table.

8. **One damage cell WAS wrong: a .416 through a boar's paunch dropped it on the spot, which makes
   the gut shot as good as the chamber shot.** `DAMAGE_BY_WEAPON.rifle.body` was 100 and
   `WOUND.LETHAL` is 100. 90 is mortal on a boar and on a red deer (90/1.2 = 75, still fixing the
   graze task 250 existed to remove) and still 10 above the lever's 80.
   *Verify:* `Boar.CONFIG.WOUND`'s new block above `DAMAGE_BY_WEAPON`, and `kill_zones.spec`'s
   ordering cases. **The trade is stated rather than hidden**: a legendary's paunch is now a graze
   (90/2 = 45), because his paunch is mortal only at 100-or-above and a boar's is non-lethal only
   below it -- and `kill_zones.spec` ASSERTS the graze rather than excluding the kind.

9. **The hunting doctrine is now the harness's, over all seven kinds x four guns x five zones.**
   140 cells walked; head and chamber drop every kind with one shot from every gun; a leg never drops
   one; the paunch and the hindquarters are strictly worse than the chamber for every (kind, gun);
   `toughness` armours the hide and never the vitals.
   *Verify:* `kill_zones.spec`. Its first case asserts `#KINDS.ORDER == 7` and that the sweep visited
   `7 * #GUNS * #ZONES` cells, so a kind dropped from `ORDER` fails there instead of shrinking the
   sweep (the Learning Agent's L-093, from task 219). The metric is SHOTS TO DROP (reach `LETHAL`) and
   the file says why that is the right one and where it asserts severity instead.

10. **The foliage was measured and NOT changed, and one reading could not be reconciled.** The rule
    today is that foliage DOES stop a shot, deliberately. In the Forest Test's wood all 2,398
    `*branch*` parts in `OurForest` are `CanQuery = false`, and the only queryable foliage in the
    place is 357 `Session/OuterLeaves`.
    *Verify:* `MapGen.Props.placeTree`'s canopy comment (*"CanQuery stays true"*, task 63) and
    `sceneryOnly`'s own "not a project-wide rule" note; research note 12.5 for the readings and for
    the thing I could not resolve -- in the same execution a name scan found zero queryable
    `*branch*` parts while a 729-ray fan was stopped 18 times by parts reported as `Branch*`, which
    cannot both be true.

## What I could not verify

- **The live magnitude of claim 3 in a running game.** The 0.73 studs is measured live, but the
  resulting 18.6 cm was flown in the spec, not shot at a plate in Play. The spec flies it through the
  real `Flight` with the real config; what is NOT proved on screen is a frame of a shot landing right
  of a reticle. **Rule 5 is N/A because nothing drawn changed** -- but if the Director turns
  `BORE_ON_SIGHT_LINE` on, the before/after pair of frames is the acceptance for it and is Karen's.
- **The exact cm cells quoted in the note.** The harness asserts the BOUNDS and `sights.spec` prints
  the live table every run; the cell values in research note 12.2 were computed by an independent
  Python model of the same five functions (`driven-hunt-runs/259-sights.py`). The note says so, and
  says the harness wins if they ever disagree.
- **The branch/ray contradiction in claim 10.** Stated as unresolved rather than guessed; the two
  readings I trust are plain property reads and the code rule.
- **Whether the paunch retune feels right.** Ten numbers, one line each, and `Boar.CONFIG.WOUND`'s own
  header says Karen decides. What is asserted is the ORDERING the doctrine gives, not the values.
