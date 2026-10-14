# Task 185 — review request: a shot takes time to arrive, so a running animal needs lead

Task: 185
Round: 1
Base: `2eedfce` (`main`, #168 merged)
Code commit: `fa38ffaefc50a4c8e97ca969966ee50db1528ff8`

Branch `task-185-bullet-flight`. Design `docs/design/ballistics.md` (Architect **PASS**,
`reviews/task-185/ARCH_RESULT.md`, no blocking open decisions). Note
`docs/research/2026-10-14-ballistics-lead.md`. Brief `reviews/task-185/BRIEF.md`.

## The harness

```
[harness] PASS: 33/33 checks @ fa38ffaefc50a4c8e97ca969966ee50db1528ff8 (clean tree) scope=all
```

Run **twice**, both PASS, both at the code commit on a clean tree:
`.agent-logs/task185-r1-test1.log`, `.agent-logs/task185-r1-test2.log`.

**`test2` is N/A, and the reason is a decision rather than an omission.** Not one file this task
touches is in `TWO_PLAYER_PATHS`: the files are `src/shared/Ballistics/`, `src/shared/Shotgun/`,
`src/shared/Rifle/`, `src/shared/Weapons/`, `src/server/Weapon/`, `src/client/Weapon/`,
`tools/studio_mcp.py` and their specs. That is a direct consequence of brief decision 1.10 and
design 12.2 — **leaving the safety verdict at the trigger is what keeps this task off that list**.

## What changed

The shot was **hitscan**: `Weapon.onFireRequest` called `Hits.resolve`, one cast per pellet over the
whole range, in the trigger's own frame. A boar at `Boar.CONFIG.SPRINT_SPEED` (38 studs/s) was
therefore hit wherever the reticle sat, and aiming ahead could only miss.

It is now a **projectile the server steps** on one `RunService.Heartbeat`, casting the **segment just
travelled**, so the hit is judged where the target is when the bullet gets there. FastCast's
algorithm, adopted as a pattern and refused as a dependency with a written reason (rule 2).

## Claims, and how to verify each

1. **A moving target is judged where it IS when the bullet arrives — the feature.**
   `tests/server/weapon_hits.spec.luau`, *"THE CORE CLAIM"*. A stub cast holds a boar crossing at 38
   studs/s and advances it by the step's own `dt`; at 179, 357 and 714 studs, aiming **AT** the boar
   produces no impact and leading it by `Ballistics.leadStuds` produces exactly one.
   Measured in the run: `[flight] 179 studs: aiming AT the boar missed; leading it 2.7 studs hit`,
   and the same at 357 (5.6) and 714 (12.2).
   *Verify:* read the case, and the three `[flight] … studs:` notes in either harness log.

2. **The lead is real, per weapon and per ammo, and the shotgun needs MORE of it.**
   `tests/server/ballistics.spec.luau`, *"THE LEAD KAREN HAS TO HOLD"*: the note's table to ±0.1
   studs, plus the assertion that at 50 m the slug's lead is 1.4–1.8× the rifle's — which is the
   content of Karen's *"same with s/s"*. Measured: `[ballistics] lead at 50 m: rifle 2.71 studs,
   slug 4.27 studs`.
   *Verify:* that case, and the note in either log.

3. **The drag model predicts a published number it was never fitted to.**
   `DRAG_PER_STUD` was fitted to the rifle's 100 yd velocity only. `ballistics.spec` asserts the
   predicted 200 yd velocity is within 1% of the published 1797 fps. Measured:
   `[ballistics] rifle at 200 yd: predicted 1974 studs/s, published 1956` — 0.92%.
   *Verify:* the case, and the note.

4. **Task 183 survives, by construction: a still target at the zero is dead centre.**
   `Ballistics.launchDirection` elevates the bore so the trajectory crosses the sight line at
   `ZERO_STUDS` — 714 (200 m) for the rifle, the distance Karen named in Task 183.
   `ballistics.spec`'s *"KEEPS TASK 183"* steps the real stepper, interpolates the crossing of the
   zero's range and measures the **sideways** miss: **under 0.05 studs** for all three ammos and for
   aims horizontal, 20° up and 20° down.
   *Verify:* that case; and `tests/server/weapon_shot.spec.luau`'s live sight-line case, which still
   asserts the pellet leaves the **muzzle** and is aimed at the camera ray's own impact point —
   now bounded by the cone **plus** the launch elevation, both read from the data rather than typed.
   Measured live: `worst pellet 0.0442 deg off the muzzle-to-aim line (cone allows 0.147)`.

5. **The three ballistic numbers are DATA, per weapon per ammo, out of each gun's own CONFIG.**
   `Shotgun.CONFIG` and `Rifle.CONFIG` carry `MUZZLE_STUDS_PER_S`, `DRAG_PER_STUD`, `ZERO_STUDS`;
   `Weapons.ROWS` surfaces them and copies nothing. `tests/server/rifle.spec.luau` asserts the
   shotgun's row field by field against `Shotgun.CONFIG`, and that **every ammo of every row** has
   all three with `ZERO_STUDS <= RANGE_STUDS`.
   *Verify:* those two cases; and that `rifle.spec`'s "carries NO rule that belongs to the drive or
   the protocol" now also refuses `FLIGHT_*` and a gravity on any row.

6. **Gravity is derived once and nowhere else.** `Ballistics.CONFIG.GRAVITY_STUDS_PER_S2` is
   `9.81 / Report.CONFIG.METRES_PER_STUD` = 35.04 — **not** `Workspace.Gravity` (196.2), which would
   make a bullet fall six times too fast. `g` is a parameter with a default on every function that
   uses it, so both values are reachable in a spec.
   *Verify:* `ballistics.spec` *"gravity has exactly one source"*; and `grep -rn "9.81" src/` finds
   `src/shared/Ballistics/init.luau` alone.

7. **Nothing that was at the trigger moved.** Rate limit, `Validator`, `StateMachine`, the ignore
   list, the aim ray, `Rules.refuse`, the spent shell, **`SafetyArc` on `aim` with `stopAt` =
   muzzle→aim-point**, `publish`, the `AUTO_CYCLE` bolt, `Weapon.ShotFired` (the BindableEvent, with
   `at = aimPoint`, so the boar still hears the bang now) and `ShotFired:FireAllClients` — all in
   `onFireRequest`, in the same order, in the same frame. Only the **hit** and the **dust** wait.
   *Verify:* read `onFireRequest` end to end. The launch replaces exactly the two lines that were
   `Hits.resolve` + `Hits.group`.

8. **One `HitReport` per (shot, target), with `pellets` counted, made when the LAST pellet lands.**
   `Hits.group` is still the one constructor and is untouched. `weapon_hits.spec` asserts nine
   pellets on one boar is one report with `pellets == 9`; and that a shot with one early hit and
   eight pellets still flying reports **nothing** until the eight run out of range.
   `report.at` is the **shot's** time, not the arrival's (asserted).
   *Verify:* those three cases, plus `Hits.luau` itself.

9. **Nothing leaks, and a long frame cannot tunnel a bullet through a wall.** `weapon_hits.spec`
   covers the exact range cap (`travelled` lands on `RANGE_STUDS` to 1e-3, not on the first
   overshoot), the flight ceiling (`timedOut` counts it, `count()` returns to 0), the live cap (a
   refusal is a **miss**, and the shot still resolves), and the sub-step split. `weapon_state.spec`
   adds: at the end of the suite `Weapon.flightCount()` is 0 and `flightTimeouts`, `flightRefused`
   and `noBallistics` are all 0.
   *Verify:* those cases. Cost measured: `[flight] 288 projectiles: 0.080 ms per step` against the
   design's 1.0 ms budget, and `[flight] chord sag at a 33.3 ms step: 0.0050 studs`.

10. **The dust arrives with the bullet, and only the dust.** One new RemoteEvent `ShotLanded`
    (`{shooterUserId, impacts}`), fired by `ServerScriptService.Weapon` alone when a shot resolves;
    `Effects.playLanded` draws one `Impact` part per point and **no Flash, no Smoke, no Tracer**.
    `ShotFired` keeps the muzzle, the barrel and the `muzzleCFrame` and now carries `impacts = {}`,
    so `Effects.play` still draws the flash and the smoke and never enters its tracer branch.
    `firedSignal:Fire` — the recoil — appears once in `src/client/Weapon/init.luau`, inside the
    `ShotFired` handler.
    *Verify:* `tests/client/weapon_client.spec.luau`'s three new cases, and that one grep.

## Measured on the player's path, in the Forest Test (the place Karen plays)

- **Smoke, 90 s:** `gun in hand @15s=1 @90s=1 | stacks=0 errorLines=0 | waves=6 | worst playing
  sounds over 10 s: 1 (boars=16)` → **SMOKE PASS**.
- **The flight itself, live:** a probe fired the player's own `FireRequest` and timed the gap
  between the `Flash` (drawn from `ShotFired`, at the trigger) and the first `Impact` (drawn from
  `ShotLanded`, when the bullet arrives):
  `shot 2: flash +76 ms, impact +110 ms, FLIGHT 34 ms over 47 studs (13 m)`.
  `Ballistics.timeToRange` predicts **35 ms** for buckshot at 47 studs. A second probe counted
  **9 Impact parts** from one shot — the whole buckshot pattern, arriving together.
- **Console after that session:** 0 "Stack Begin", 0 error lines, 64 lines.

## Screenshot (rule 5), inspected

`<runs-dir>/185-dust-a.png` and `185-dust-b.png`, two frames 0.45 s apart in the Forest Test.
What I actually see: first person, the side-by-side across the bottom of the frame, forest and tall
grass. Frame **a** readout `[*]* BUCK 10`; frame **b** `x[*] BUCK 10 R` — one barrel spent and the
reload running, so the shot falls between them. The impact dust is visible in both as small
orange-yellow specks scattered across the grass at about 10 m, spread as a nine-pellet pattern.
**Honestly: it is small.** The `Impact` part is 0.3 studs and the Forest Test's grass is taller than
that, so the dust reads as flecks rather than as puffs. It is the same part, the same size and the
same lifetime `Effects.play` has drawn since Task 23 — this task only moved **when** it is drawn —
so making it bigger would be a change to the look and is Karen's, not mine.

## Design delta — `Ballistics.dropAt` is NOT the design's formula, and the design's own target is why

`docs/design/ballistics.md` 4.1 specifies `dropAt` as `0.5 * g * timeToRange(s)^2`, and section 10's
drop table and its 0.1438° elevation follow from it. **That form is wrong and the design's own
numeric target is what proved it.** The vacuum formula ignores that drag acts along the *whole*
velocity, so its vertical component pushes **up** on a dropping bullet — 27% of gravity for the
rifle — and the vacuum drop is 9% too large at 200 m. A still target at the rifle's own zero landed
**0.169 studs (4.7 cm) low**, against design 10's *"a still target at the zero is hit within 0.05
studs of dead centre"*. Since that is Task 183's whole claim, it had to be right rather than close.

Shipped instead (derivation in the module and in note section 2D): holding the horizontal speed at
its path average `V = s/t` makes the vertical equation linear, `dvy/dt = -g - (k*V)*vy`, giving
`drop(t) = (g/b)*(t - (1-exp(-b*t))/b)` with `b = k*(s/t)`, whose `b → 0` limit **is** the vacuum
formula, so the two branches meet rather than stepping. The miss at the zero fell to 0.0011 studs
(rifle), 0.00013 (slug), 0.00006 (buck).

Consequences, all re-derived rather than nudged, and carried into the note, the specs and both
CONFIG comments:

| | design 10 (vacuum) | shipped (drag-corrected) |
|---|---|---|
| rifle at 100 m | +0.51 studs (14 cm high) | **+0.45 studs (12.5 cm)** |
| rifle at its 800-stud cap | −0.33 studs | **−0.28 studs** |
| slug at 92 m | −0.48 studs (−13.4 cm) | **−0.41 studs (−11.4 cm)** |
| buck at 28 m | −0.04 studs | **−0.03 studs** |
| rifle launch elevation | 2.509e-3, 0.1438° | **2.272e-3, 0.1302°** |

The elevation is *smaller*, so section 5's safety-arc argument only gets stronger. **Flight times,
leads, muzzle velocities, drag coefficients and zeros are unchanged** — this touches the fall only.

`docs/design/ballistics.md` is **not edited**: `docs/design/` is the Architect's (rule 3). This is
the record.

## What I could not verify

1. **The FEEL.** Whether leading a boar is satisfying, whether 12.2 studs at 200 m is too much, and
   whether the 12.5 cm mid-range rise bothers her, are Karen's and only a playtest answers them. The
   zero is one line (`Rifle.CONFIG.ZERO_STUDS`); a 150 m zero would put the whole band inside ±15 cm
   from 0 to 200 m.
2. **The average cost in a full drive.** The 288-projectile burst is measured (0.080 ms per step);
   the 16-player average needs a drive with 16 players in it, which does not exist yet.
3. **The `"no-ballistics"` branch is unreachable in the shipped build** — both rows carry all three
   numbers and `rifle.spec` asserts it — so it is proved only as `shotFor` returning `nil` for a
   hand-written row, plus reading the guard.
4. **Whether a boar's welded zone parts are exactly where the server thinks sub-frame.** The weapon
   reads the world through one ray and never reads boar state; the 1.27-stud resolution claim at the
   step cap assumes those parts move smoothly between Heartbeats.
5. **The live flight probe measured the shotgun, not the rifle** — the Forest Test arms the shotgun,
   and 34 ms over 47 studs is what it could reach. The rifle's 0.32 s at 200 m is asserted purely
   and in the closed form, not measured in a session.
