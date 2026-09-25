# Task 24 — design brief for the ARCHITECT: fix `docs/design/shotgun.md` so it can be built from

Written by the Builder, carrying the Director's instruction. **This brief overrides anything older.**
The Task 23 regeneration is good and is being **built from in this same task** — this run fixes the
defects its own review found, nothing else. Do not restructure what already works.

## Context

- `docs/design/shotgun.md` on `main` is the Task 23 regeneration. `reviews/task-23/ARCH_RESULT.md` is
  `PASS`, and the Director accepted it; then the Task 23 review found six real defects in it, listed
  below, which the Builder may not fix (rule 3: `docs/design/` is yours).
- **Task 6 has landed** (`main`): the harness now drives real keyboard and mouse input into the Play
  client and a client spec asserts on what `ContextActionService` / `UserInputService` delivered
  (`tests/client/input_scenarios.txt`, `tests/client/input_driving.spec.luau`,
  `tools/studio_mcp.py` step 7a). Your §13.3 is satisfied: the three things you asked it to prove are
  proved. Rule-5 screenshots can also be saved now (`python tools/studio_mcp.py capture …`). So the
  weapon is unblocked and **this task builds it**.
- Everything else the Task 23 design says about the boar, the arena and ownership still holds.

## The six defects to fix (Task 23 review, `reviews/task-23/RESULT.md`, queued as TASKS.md row 23a)

1. **The cast seam cannot express what the shot sequence needs.** `CastFn = (origin, direction) ->
   Impact?` with one module-level `Weapon.setCast` has **no shooter**, so §5.4 step 8's "filter out
   the shooter's character and `Workspace.WeaponEffects`" is unimplementable; and step 4 casts the
   *camera* ray with the same function, which under the stock third-person camera starts **behind**
   the character — so an unfiltered cast resolves `aimPoint` onto the shooter's own body, where
   `MIN_AIM_DISTANCE` silently swallows it. Give the seam an ignore list (or build the production cast
   per shot over the shooter), and say so in steps 4 and 8.
2. **`table.freeze` is shallow.** `CONFIG.SPREAD_FULL_DEG` and the replica's `barrels` / `loaded`
   stay writable, so "frozen … has no writer" (§3.3) and the spec assertion that a write errors
   (§13.2) hold only for the top-level table. Freeze the nested tables, and assert on a nested write.
3. **No `Players.PlayerRemoving` lifecycle.** Per-player `WeaponState` and the rate-limit counters are
   keyed by `Player` and nothing clears them: a leak that also pins the `Player` instance. Name the
   cleanup beside `grant` / `revoke`.
4. **`ActionRequest` must accept only `"Reload"` and `"SelectAmmo"`.** §5.5 sends
   `ActionRequest:FireServer("Reload")`, which is not an `ActionKind`, while `Break` / `Load` /
   `Close` are meant to be server-only primitives. State the accepted set so the primitives are never
   reachable from a client by accident.
5. **The safety arc is evaluated on the wrong direction.** §5.4 step 10 uses the client's camera
   `direction`, not the `aim` the pellets actually take from the muzzle (step 6). Use the direction
   the shot uses, so a published `SafetyViolated` matches where the pellets went.
6. **A flaky spec assertion.** §13.1's preamble says specs "write their own numbers rather than
   importing `CONFIG`", but `weapon_shot.spec` item 2 is written in terms of `SPREAD_FULL_DEG`; and
   "at least one direction beyond `SPREAD_FULL_DEG/4`" is ~25 % flaky for `Slug`, which returns a
   single direction. Fix the seed and apply that half of the assertion to `Buck` only.

## What the re-run design must also do

- **Keep the scope the Director set for the build**, and say plainly what is in it: a `Tool` granted
  on spawn; fire on MouseButton1; automatic barrel select; break open, load two shells, close, as one
  uninterruptible 2.0 s action; slug vs buckshot selection that only loads while open;
  server-authoritative hit validation; `Runtime:takeHit(part, hit)` on the boar with `zone = "body"`
  (the boar may simply flee or despawn on a hit for now — hit zones and wounds are ROADMAP 1.5); the
  Hud crosshair; and the `GAME_DESIGN.md` owner rows. **Default camera: nothing writes
  `workspace.CurrentCamera`.** No ADS, no viewmodel — those are the next task.
- **Say what the client input scenarios must contain** for fire, reload and ammo select, in the
  format Task 6 landed (`{"device": "keyboard"|"mouse"|"wait", …}`), including the assertion that
  `workspace.CurrentCamera.CFrame` is unchanged by the weapon.
- **Keep every number in the one `Shotgun.CONFIG`**, with the degrees/FULL/HALF rule from §4 intact,
  and Karen's five feel defaults as config values (§12).
- Cite **files and symbols or section numbers, never line numbers**.
- `ARCH_RESULT` should be `PASS`: nothing here is an open decision. If you find a genuine blocker,
  list only that.

## Constraint

The Builder builds from this design **in this task, immediately after your run**. Anything left
ambiguous becomes a guess in the code.
