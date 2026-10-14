# Task 185 — design brief for the ARCHITECT: ballistics, and the lead a running animal needs

Written by the Builder, carrying the Director (2026-10-14). This brief is the input to
`tools/architect.sh design ballistics --task 185` and **overrides anything older** in `docs/`,
`TASKS.md` and the existing designs where they disagree (`docs/ARCHITECT_PROMPT.md`).

Read first: **`docs/research/2026-10-14-ballistics-lead.md`** — this task's note. It carries the
sources with their licences and maintenance status, the written reason for not vendoring FastCast
(rule 2), the drag model, and every number below with its derivation. The design is a **delta** to
`docs/design/shotgun.md` (sections 3.1, 5.3, 5.5, 11, 13) and to `docs/design/rifle.md` (section 4),
plus one new system design for the flight itself.

## 1. The decisions, already taken — do not re-open them

1. **KAREN, 2026-10-14 ~20:15, verbatim:** *"another thing it has to be real like in a life when I
   shoot in running animal I need to aim a bit in front based on speed distance ect I wan to have
   that feeling"*. And ~20:20: *"same with s/s"* — the side-by-side shotgun gets the same treatment.
2. **The shot stops being hitscan.** Today `Weapon.onFireRequest` calls `Hits.resolve` in the
   trigger's own frame. From this task a shot is a **projectile the server steps**, and the hit is
   judged where the target is **when the bullet gets there**.
3. **The algorithm is FastCast's and it is NOT vendored.** Step `p += v*dt + 0.5*a*dt^2`, raycast
   the **segment just travelled**, stop on the first hit. The module itself is refused for a
   written reason (ships as `.rbxm`, which this repo bans; not on Wally; carries a visual-bullet
   system we do not want) — note section 2A.
4. **No lag compensation.** Rewinding hitboxes exists to remove the feeling Karen asked for
   (note 2B).
5. **Muzzle velocity, drag and the zero are DATA, per weapon per ammo**, and they live where every
   other ballistic number already lives: each gun's own CONFIG, surfaced through `Weapons.ROWS`,
   never copied (the discipline `rifle.spec` already asserts field by field).
6. **The numbers, decided** (note section 4; derivations and sources there):

   | | rifle Slug | shotgun Slug | shotgun Buck |
   |---|---|---|---|
   | muzzle studs/s | 2612 | 1752 | 1442 |
   | drag k per stud | 4.29e-4 | 1.059e-3 | 2.631e-3 |
   | zero studs | 714 (200 m) | 180 (50 m) | 70 (20 m) |

   `g = 9.81 / 0.28 = 35.04 studs/s^2`, derived from `Report.CONFIG.METRES_PER_STUD` and from
   nothing else. `RANGE_STUDS`, `PELLETS` and `SPREAD_FULL_DEG` are **unchanged**.
7. **Task 183's still-target accuracy is preserved by construction, not by luck.** The launch
   direction is the existing `aim` (the muzzle→aim-point unit vector, design 5.5 step 7) elevated
   so the drop cancels **at the zero distance**. A still target at the zero is hit dead centre.
   The rifle's zero is **200 m**, because that is the distance Karen named in Task 183
   (*"precist and on 200m acurat"*). The 14 cm mid-range rise at 100 m that this costs is real,
   is measured in the note, and is **one line** if she wants it flatter (a 150 m zero).
8. **The default tracer is NONE** (the Director's dispatch; Karen's call later). The projectile is
   invisible maths on the server. **No Instance per pellet, ever** — nine replicating parts per
   shot is refused here and now.
9. **Nothing that is at the trigger today moves to the impact.** The rate limit, the validator, the
   state machine, the ignore list, the aim ray, `Rules.refuse`, the spent shell, the bang, the
   flash, the recoil and the bolt all stay exactly where they are and when they are. Only the
   **hit** and the **dust where the shot landed** wait for the bullet.
10. **The safety arc's verdict stays at the TRIGGER** (note section 5). The launch direction differs
    from today's `aim` by **0.144 degrees** against `SAFETY_ARC_HALF_DEG = 45`, so judging the
    launch direction *is* judging the real path; a penalty 0.37 s late is worse to be on the end of;
    and `src/server/Match/` is a `TWO_PLAYER_PATH`, so leaving it alone keeps this task on the
    one-player gate, which is the Director's own 2026-10-03 rule applied as written. `stopAt` stays
    the muzzle→aim-point distance.
11. **`ServerScriptService.Weapon` stays the ONE owner of hits, and `Weapon.Cast` stays the ONE
    caller of `Workspace:Raycast` under `src/server/Weapon/`** (design 13.5). A grep must still find
    that file alone.
12. **It does not merge dark behind a flag.** This is not a parallel path that can sit beside the
    old one: hitscan and flight are two different answers to "where did the bullet go", and a flag
    would mean two hit owners (rule 3). It merges on the Reviewer's PASS and the gate, like Task 183
    and Task 184 did.

## 2. What the design must contain

1. **Owners, and exactly one writer each (rule 3).** Name the owner of:
   - the in-flight projectiles (the list, and the clock that advances them);
   - the pure ballistics maths (time of flight, drop, the launch velocity, one step);
   - the decision that a shot has finished and may be reported;
   - the drawn impact, if the dust is kept (see item 5).
   Say for each whether it is a new module and, if so, why it is not a second writer of something
   that already has one. The Builder's proposal, to confirm or replace:
   - **`src/shared/Ballistics/init.luau`** — pure, no services, no clock. `timeToRange`,
     `dropAt`, `launchVelocity`, `advance` (one step). Shared rather than server-only so a tracer,
     if Karen ever asks for one, has one answer and not two.
   - **`src/server/Weapon/Flight.luau`** — the list of live projectiles, over an **injected cast**
     (`(origin, direction, ignore) -> Impact?`, the seam `Hits` and `Weapon.setCast` already use)
     and an **injected `dt`**, so every assertion below runs with no world and no Heartbeat.
   - **`ServerScriptService.Weapon`** — the one `RunService.Heartbeat` connection, started in
     `Weapon.start`, calling `Flight:advance(dt)` and firing the signals. Unchanged as the owner.
2. **The step, written out**, including: the acceleration (`-g*up - k*|v|*v`), the segment cast, the
   `dt` cap and what happens to a `dt` larger than it (split, so a lag spike cannot tunnel a
   projectile through a wall), the range cap, and a hard flight-time ceiling so a projectile can
   never leak.
3. **When a shot is reported, and in what shape.** Today `Hits.group` makes **one `HitReport` per
   (shot, target)** with `pellets` counted, and `HitLog`, `Match`, `ForestTest` and the hit marker
   all depend on that. Say when the group is formed (the Builder's proposal: when the shot's **last**
   projectile has resolved — hit, out of range, or out of time) and what `report.at` is then: the
   time of the **shot** or the time of the **arrival**. `Hits.group` already takes `now` as a
   parameter and `HitLog` copies it, so this is a decision, not an accident. The Builder's
   proposal: `at` stays the **shot's** time, because the drive report means "when was this shot
   taken" and because a 0.3 s change there is invisible while a two-clock report is not.
4. **What the per-shot record carries, and its lifetime.** The ignore list, the shooter, the ammo,
   the weapon id, the muzzle and the shot time are needed when the shot resolves, not when it is
   fired. Say who holds it, and what happens when the shooter **dies, is revoked, respawns or
   leaves** between the trigger and the arrival — explicitly, because `epoch` already exists for
   exactly this class of question on the reload sequence. The Builder's proposal: the bullet is in
   the air and has left the gun, so it **still flies and still hits**; only the hit *marker* to a
   player who has gone is dropped.
5. **The dust where the shot lands — decide it.** `ShotFired` carries `impacts` today and
   `client/Weapon/Effects.luau` draws a tracer bar and an impact cube from each one. With flight,
   those positions do not exist at the trigger. Three options; pick one and say why:
   (a) `ShotFired` carries `impacts = {}` and the dust is simply lost (smallest change, a visible
   regression Karen may notice); (b) **one new RemoteEvent `ShotLanded`** (`{shooterUserId,
   impacts}`), fired when the shot resolves, from which `Effects` draws the impact cubes and **no**
   tracer (the Builder's proposal — it is honest, the bang is now and the dust is when the bullet
   arrives, and it is the only shape that keeps the tracer code dead while the default is none);
   (c) something else. If (b), say who owns the new remote and name the client spec that asserts it.
6. **The data, and where each number lives.** Which fields go in `Shotgun.CONFIG`, which in
   `Rifle.CONFIG`, which in the `Weapons.Row` type, and the one place `g` is derived. State the rule
   that already governs this: a row may not carry a rule of the drive or of the protocol.
7. **How it is tested — the specs, by name and by claim.** The design must say what is provable with
   **no world** and what needs Play. The Builder's list, to confirm or extend:
   - flight time per weapon per ammo at named ranges, against the closed form (pure);
   - **a target that MOVES into and out of the path is judged where it is when the bullet arrives**
     — the core claim, staged with a scripted cast whose answer depends on the step's own time
     (pure, over the injected cast);
   - a still target at the zero distance is hit **dead centre** (pure: the launch elevation and the
     drop cancel), and again live;
   - **aiming AT a crossing boar misses behind it, and aiming AHEAD by `v*t` hits** — at 50, 100 and
     200 m, which is the Director's measurement on the player's path;
   - the drop at the named distances, including the slug's -13.4 cm at 92 m;
   - one report per (shot, target) with `pellets = 9` for a buckshot shot that lands on one target,
     unchanged;
   - the grep claim: `Workspace:Raycast` appears once under `src/server/Weapon/`;
   - the cost claim (note section 4) and how it is measured.
8. **The `BLAST_RADIUS` and `SCOPE_SPECS` rows** a new `src/shared/Ballistics/` needs in
   `tools/studio_mcp.py`, and the scope it resolves to. `selftest` fails if a spec belongs to no
   scope, so this cannot be left out.
9. **Say plainly whether anything here is in `TWO_PLAYER_PATHS`.** The Builder's reading is **no**,
   given decision 1.10: the files touched are `src/shared/Ballistics/`, `src/shared/Rifle/`,
   `src/shared/Shotgun/`, `src/shared/Weapons/`, `src/server/Weapon/`, `src/client/Weapon/` and
   their specs, and not one of those is in the list. If the design disagrees, say which file and
   why, because that decides whether the task needs a human click.

## 3. What the design must NOT do

- Do not invent a new owner for anything that has one. In particular the camera, the Hud and the
  boar are untouched by this task.
- Do not move the safety verdict, the penalty, or anything under `src/server/Match/`
  (decision 1.10). If the design believes it must, that is an `ESCALATE.md` entry and a Director
  decision, not a line in a design.
- Do not add a feature flag (decision 1.12).
- Do not change `RANGE_STUDS`, `PELLETS` or `SPREAD_FULL_DEG`. Task 183 and Task 184 set them and
  Karen has played them.
- Do not design a visible bullet, a bullet-drop reticle, or a lead indicator. Karen asked to *feel*
  the lead, not to be told it.
