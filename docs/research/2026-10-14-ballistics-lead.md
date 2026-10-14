# Real lead: a shot that takes time to arrive (Task 185)

Karen, 2026-10-14 ~20:15, verbatim:

> "another thing it has to be real like in a life when I shoot in running animal I need to aim a
> bit in front based on speed distance ect I wan to have that feeling"

and ~20:20:

> "same with s/s"

(the side-by-side shotgun gets it too).

## 1. What the system must do

1. **A shot takes time to arrive.** Today it does not: `Weapon.onFireRequest` calls
   `Hits.resolve` in the same frame as the trigger pull, so the ray is resolved at the instant of
   firing. That is HITSCAN, and under hitscan a boar sprinting at `Boar.CONFIG.SPRINT_SPEED`
   (38 studs/s) is hit wherever the reticle sits. There is no lead, and no amount of aiming ahead
   can ever help -- aiming ahead can only miss.
2. **The time must be real.** Per weapon and per ammo, derived from a real cartridge's muzzle
   velocity and its real loss of speed down range, so the LEAD a player has to hold is the lead
   the real gun needs: more at distance, more with the shotgun than with the rifle.
3. **The hit must be judged where the animal IS when the bullet gets there**, not where it was at
   the trigger. A boar that ran out of the path must not be hit; a boar that ran INTO the path must
   be hit. That is the whole feature: it is what makes aiming ahead work rather than merely
   making the shot late.
4. **Gravity drop, as data.** Zeroed at a stated distance, dead centre there, dropping beyond it.
5. **A still target must stay exactly as accurate as Task 183 made it.** Karen asked for
   *"precist and on 200m acurat"* and the rifle now delivers it (`SPREAD_FULL_DEG = {Slug = 0}`).
   Nothing here may cost that.
6. **Nothing may wait for the bullet that should not.** The bang, the flash, the recoil, the shell
   and the bolt are at the TRIGGER. Only the hit, and the dust where the shot landed, wait.
7. **Cheap.** Up to nine buckshot pellets per shot, up to 16 players, inside one drive.

### Must not
- No client-side hit detection, and no new trust in the client. The client still sends one
  `FireRequest` with an origin and a direction; the server still owns every hit
  (`docs/design/shotgun.md` 3.1, 5.5).
- No per-pellet Instance. A flying Part per pellet is nine parts per shot replicating to every
  client; the pellets stay invisible maths on the server.
- No second writer of hits. `ServerScriptService.Weapon` stays the one owner, and
  `Weapon.Cast` stays the ONE caller of `Workspace:Raycast` in the system (design 13.5).

## 2. External sources

### A. FastCast / FastCast Redux -- Roblox, the standard pattern for this, **adopted as a pattern, not vendored**
- Docs: <https://etithespir.it/FastCastAPIDocs/> (the old docs repo
  <https://github.com/EtiTheSpirit/FastCastAPIDocs> is **MPL-2.0** and its README says
  "This is obsolete").
- Maintenance: no longer actively maintained by its author. The living forks are
  `010DevX101/FastCastRedux` (MIT-0, release v13.2.1 dated 2025-01-25) and the FastCast2 line
  (<https://github.com/Shellworks-Development/FastCast2>, statically typed, parallel Luau).
- Creator Store listing: <https://create.roblox.com/store/asset/4453855787/FastCast-Redux>.
- What it does well: it is the right ALGORITHM and it is the one every Roblox shooter uses.
  Its own words: "To emulate bullet physics and hit detection in pure Lua." It splits the line
  the projectile travels this frame into a segment and raycasts that segment -- so a fast
  projectile cannot tunnel through a thin wall, and a target that moved is met where it now is.
  It takes a velocity and an acceleration (gravity), so drop is free.
- What it does badly, for us: it ships as a Roblox model (`.rbxm`), which **this repo bans**
  (`CLAUDE.md`, "File types in Rojo-owned paths": binary, unreviewable in a PR; CI and the harness
  both fail on it). It is not on Wally, so it cannot be pinned in `wally.toml` the way TestEZ is.
  It is also much more than we need: `ActiveCast` objects, `PartCache` cosmetic bullets,
  `CanPierceFunction`, a `LengthChanged` signal per segment per frame, its own `RunService`
  connection, and a documented "high velocity, low simulation rate" caveat. Adopting the module
  would mean a vendored, unpinnable, binary dependency carrying a visual-bullet system we do not
  want (the default tracer is NONE -- Karen's call later).
- **The written reason (rule 2).** The pattern is borrowed and cited; the module is not vendored
  because the repo bans its distribution format and Wally has no package for it. What we take is
  exactly three sentences of it: step the projectile by `v*dt + 0.5*a*dt^2`, raycast the SEGMENT
  just travelled, and stop on the first hit. That is ~40 lines, and it is testable with no world
  because the cast is already an injected seam in this system (`Weapon.setCast`).

### B. Valve / Source-engine lag compensation, and why we do **not** need it
- Valve's backward-reconciliation technique: the server keeps ~1 s of hitbox history, and when a
  client reports a shot with the time it saw, the server rewinds the targets to that time, casts,
  and applies damage. Discussion and the projectile gap:
  <https://github.com/ValveSoftware/Source-1-Games/issues/2230> ("[TF2] Add lag compensation for
  projectiles"), and an engine-side write-up of the same technique:
  <https://snapnet.dev/blog/performing-lag-compensation-in-unreal-engine-5/>.
- What it does well: it is the correct answer for a COMPETITIVE hitscan shooter, where a 60 ms
  ping must not cost you a head shot on another player.
- What it does badly, for us: it is a large mechanism (per-target position history, a trusted
  client timestamp, a rewind window) and it exists to defeat exactly the feeling Karen asked FOR.
  Lag-compensated hitscan removes lead. We are not a competitive shooter: the target is an AI
  boar, nobody shoots players, and a drive is not ranked. Source's own projectile classes are
  NOT lag-compensated and that is the shape we want.
- **Adopted from it:** one sentence only -- the server is the single source of truth for the
  projectile's position and for the hit. We keep that; we drop the rewind.

### C. Real ballistics -- the numbers, per weapon
Two cartridges, because the game has two guns and Karen asked for both.

**The rifle -- .416 Rigby, 400 gr at 2400 fps** (the game's `AMMO_LABEL` for the rifle is already
`".416"`, so the cartridge was chosen in Task 140/183).
- <https://en.wikipedia.org/wiki/.416_Rigby>,
  <https://chuckhawks.com/416_caliber_family.html> (the 400 gr / 2400 fps / 5,115 ft-lb load),
  <https://www.americanhunter.org/content/head-to-head-375-h-h-magnum-vs-416-rigby/>.
- Muzzle 2400 fps = **731.5 m/s**. Remaining velocity: 2086 fps at 100 yd, 1797 fps at 200 yd.
- Published drop, zeroed at 100 yd: **6.8 in at 200 yd**.

**The shotgun -- 12 ga rifled slug and 00 buckshot.**
- Federal rifled slug: muzzle **1610 fps**, 1139 fps at 100 yd, drop **-5.7 in at 100 yd**
  (zeroed at 50 yd): <https://le.vistaoutdoor.com/ammunition/federal/slug/details.aspx?id=126>,
  Chuck Hawks' slug trajectory table
  <http://www.wainsworld.org/Guns/PDF/Expanded%20Shotgun%20Slug%20Trajectory%20Table.pdf>,
  and <https://en.wikipedia.org/wiki/Shotgun_slug>.
- 12 ga 2 3/4" 00 buckshot: muzzle **1325 fps**, and a .33" lead sphere sheds it fast --
  ~940 fps by 40 yd: <https://en.wikipedia.org/wiki/Military_12-gauge_cartridges>.
- What this does well: it is the ground truth, and it already explains the FEEL Karen is asking
  for -- the slug leaves at two thirds of the rifle's speed and loses it four times as fast, so a
  crossing boar needs noticeably more lead with the shotgun. That difference is the content of
  her second sentence ("same with s/s").
- What it does badly: a published table is for a specific barrel, bullet and BC. We are not
  reproducing a table; we are reproducing the two things a player feels, time of flight and drop.

### D. Drag, as one coefficient -- the model, and why it is not a table
- Exponential velocity decay with range, `v(s) = v0 * exp(-k*s)`, is the closed form of quadratic
  drag `dv/dt = -k*v^2` written against DISTANCE instead of time
  (<https://en.wikipedia.org/wiki/Drag_equation> -- drag goes as v^2 at these Reynolds numbers;
  <https://en.wikipedia.org/wiki/External_ballistics>).
- Fitted to source C, ONE coefficient per ammo reproduces the published remaining velocities to
  about 1%: fit the rifle's k to 2400 -> 2086 fps over 100 yd, then PREDICT 200 yd and get
  1813 fps against the published 1797 -- **0.9% high**, with nothing fitted to that second point.
- What it does well: one number per ammo, a closed form for the time to any range (so a spec can
  assert the flight time without stepping anything), and the stepper needs no table lookup --
  the acceleration is `-g*up - k*|v|*v`.
- What it does badly: it ignores transonic behaviour and it is not a G1/G7 drag function. It
  would be wrong for a 1000 m shot. Our longest shot is 800 studs (224 m).

### E. Borrowed from inside this repo (rule 2 applies to internal patterns too)
- **The injected cast seam.** `Weapon.Hits` already takes `cast` as a parameter and
  `Weapon.setCast` already exists for specs. The stepper takes the same seam, so every flight
  assertion runs with no world.
- **Pure core, impure owner.** `Pattern`, `Hits`, `SafetyArc`, `StateMachine` and `Validator` are
  all pure and take `now` as a parameter (design 5.3). The ballistics maths follows it exactly:
  `src/shared/Ballistics` is pure, and the clock lives in the server owner.
- **Numbers as a frozen row.** `Weapons.ROWS` already carries `RANGE_STUDS`, `PELLETS` and
  `SPREAD_FULL_DEG` per weapon, built from each gun's own CONFIG and never copied
  (`tests/server/rifle.spec.luau` asserts the row field by field). The three new numbers go in the
  same place, the same way.
- **The one conversion.** `Report.CONFIG.METRES_PER_STUD = 0.28` is the single metre/stud
  conversion in the repo. Gravity is derived from it HERE and nowhere else.

## 3. The pattern adopted

**Server-side projectile simulation, stepped on one `RunService.Heartbeat`, with a segment raycast
per projectile per step** -- FastCast's algorithm (source A), implemented in this repo's own idiom
(source E) rather than vendored, with a one-coefficient drag model (source D) fitted to real
cartridge data (source C), and no lag compensation (source B).

- One `Heartbeat` connection for the whole server, owned by `ServerScriptService.Weapon`.
- Per step, per live projectile: `p' = p + v*dt + 0.5*a*dt^2`, `v' = v + a*dt`,
  `a = -g*up - k*|v|*v`; then `cast(p, p'-p, ignore)` -- the SEGMENT, which is why a boar that
  moved into or out of the path is judged where it actually is at that moment.
- `dt` is capped (`STEP_MAX_SECONDS`) and a long step is split, so a lag spike cannot let a
  projectile jump a wall.
- A shot's impacts are grouped and reported ONCE, when the shot's LAST pellet has resolved -- which
  preserves today's contract exactly: "nine pellets on one boar is ONE report with pellets = 9".
- The trigger-side half of the shot does not change at all: rate limit, validate, state machine,
  the ignore list, the aim ray, the rules, the shell, the bang, the bolt, `ShotFired`.

**The launch direction is the existing `aim`, elevated so that the drop cancels at the zero.**
`aim` is already the muzzle-to-aim-point unit vector (design 5.5 step 7), and that is the sight
line. Elevating it by `drop(zero)/zero` makes the trajectory cross the sight line exactly at the
zero distance -- so a still target at the zero is hit dead centre, which is Task 183's result
preserved by construction rather than by luck.

## 4. The numeric targets

`g = 9.81 / 0.28 = 35.04 studs/s^2` -- real gravity in this game's own units, derived from
`Report.CONFIG.METRES_PER_STUD`.

| | rifle Slug | shotgun Slug | shotgun Buck |
|---|---|---|---|
| cartridge | .416 Rigby 400 gr | 12 ga rifled slug | 12 ga 00 buck |
| muzzle | 2400 fps = 731.5 m/s = **2612 studs/s** | 1610 fps = 490.7 m/s = **1752 studs/s** | 1325 fps = 403.9 m/s = **1442 studs/s** |
| drag k | **4.29e-4** /stud | **1.059e-3** /stud | **2.631e-3** /stud |
| zero | **714 studs** (200 m) | **180 studs** (50 m) | **70 studs** (20 m) |
| range cap (today, unchanged) | 800 studs | 330 studs | 100 studs |

Flight time, from the closed form `t = (exp(k*s) - 1)/(k*v0)`:

| range | rifle | shotgun slug | buck |
|---|---|---|---|
| 179 studs (50 m) | 0.071 s | 0.113 s | -- |
| 357 studs (100 m) | **0.148 s** | -- | -- |
| 714 studs (200 m) | **0.320 s** | -- | -- |
| 330 studs (92 m, slug cap) | -- | **0.225 s** | -- |
| 100 studs (28 m, buck cap) | -- | -- | **0.079 s** |

**Lead a boar at `SPRINT_SPEED` (38 studs/s = 10.6 m/s) crossing square-on needs:**

| | 50 m | 100 m | 200 m | at the ammo's cap |
|---|---|---|---|---|
| rifle | 2.7 studs (0.76 m) | **5.6 studs (1.57 m)** | **12.2 studs (3.40 m)** | 13.9 studs |
| shotgun slug | 4.3 studs (1.20 m) | -- | -- | **8.6 studs (2.40 m)** |
| buck | -- | -- | -- | **3.0 studs (0.84 m)** |

A boar is about 1.5 m long. So: half a body at buckshot range, one body with the rifle at 100 m,
**more than two bodies with the rifle at 200 m**, and the slug needs ~60% more lead than the rifle
at the same distance. That is the feeling, and it is the answer to "same with s/s".

**Drop, relative to the sight line** (zero as above, computed from the same model):

| | 100 m | 200 m | the ammo's cap |
|---|---|---|---|
| rifle (zero 200 m) | +0.51 studs (**14 cm high**) | **0 cm** | -0.33 studs (9 cm low at 224 m) |
| shotgun slug (zero 50 m) | -- | -- | -0.48 studs (**13 cm low at 92 m**) |
| buck (zero 20 m) | -- | -- | -0.04 studs (1 cm low at 28 m) |

The slug figure is the sanity check on the whole model: Federal publishes **-5.7 in (-14.5 cm) at
100 yd** for a 50 yd zero, and the model says **-13.4 cm at 92 m**. The model was not fitted to
that number.

**The rifle's zero is 200 m, and that is a decision with a trade-off.** Karen asked for
*"precist and on 200m acurat"* (Task 183) and the Director's dispatch asks for "0 cm at 200 m with
the zero". A 200 m zero gives exactly that and keeps 183's measured result at the distance she
named. The price is the mid-range rise: **14 cm high at 100 m**, which is real (a real rifle zeroed
at 200 m shoots high at 100) but larger than a real .416's ~7 cm, because this model has no
scope-height offset. It is ONE number (`ZERO_STUDS`), and if Karen wants the rise gone, a 150 m
zero puts the whole band inside +/-16 cm from 0 to 200 m. Flagged for her, not decided for her.

**Cost.** Longest flight 0.37 s (rifle at its 800-stud cap) = ~22 steps at 60 Hz, 1 cast each.
A nine-pellet buckshot shot is ~5 steps x 9 = 45 casts spread over 0.08 s. Target: **under 0.5 ms
per Heartbeat** with 16 shooters firing as fast as the guns allow, and the step must allocate no
table per projectile per frame.

**What does NOT change, and must be measured to prove it:**
- a still target at the zero distance is hit dead centre (Task 183, `SPREAD_FULL_DEG = 0`);
- the bang, flash, recoil, shell and bolt are at the trigger, not at the impact;
- one `HitReport` per (shot, target), with `pellets` counted;
- `Weapon.Cast` is still the only caller of `Workspace:Raycast` under `src/server/Weapon/`.

## 5. The safety arc, and why it stays at the trigger

`Weapon.SafetyArc` asks one question: *is this shot pointing into the drive line?* It is given the
direction the shot takes, and the launch direction differs from today's `aim` by the elevation
angle alone -- **0.144 degrees for the rifle at its 200 m zero**, against a cone of
`SAFETY_ARC_HALF_DEG = 45`. So the arc's verdict is identical, and judging the launch direction IS
judging the real path.

The verdict therefore stays where it is: **at the trigger**. Three reasons, in order:
1. The rule is about where the player POINTED the gun. That is known at the trigger and is not a
   property of where the bullet stopped.
2. A penalty that arrives 0.37 s after the trigger is a worse rule to be on the end of, and
   `Match.Penalty` would have to grow a delayed path for no gain.
3. `src/server/Match/` is a `TWO_PLAYER_PATH`. Leaving the safety verdict alone keeps this task
   out of that list entirely, so it needs the one-player gate only -- which is the Director's own
   2026-10-03 rule applied as written.

`stopAt` (the fourth argument, Task 35) also stays the muzzle-to-aim-point distance. The
projectile's real stopping point differs from it by centimetres on a path this flat, and the aim
point is already documented as "where the shot was actually going" rather than where a pellet
clipped the ground.

## 6. Open for Karen (feel, not engineering)

1. **The rifle's zero: 200 m (shipped) or 150 m?** 200 m is dead-on where she asked; 150 m trades
   that for a flatter band. One line either way.
2. **A visible tracer: none (shipped).** The dispatch's default. The bullet is invisible maths; the
   dust where it lands is drawn when it arrives.
3. **Muzzle velocities are dials.** If 200 m feels like too much lead, the honest knob is the
   cartridge, not the physics.
