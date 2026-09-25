# Task 24 — the shotgun on the default camera

Task: 24
Round: 1
Base: `bb674dc`
Code commit: `c993783f95579491d7521a83e67da8778721898f`

```
[harness] PASS: 26/26 checks @ c993783f95579491d7521a83e67da8778721898f (clean tree)
```

79 server assertions across 8 spec files and 26 client assertions across 3, where main had 39 and 11.

## Task

Director, 2026-09-25 (verbatim in `TASKS.md`): fix the design's six known defects, then build exactly
its scope — a Tool on spawn, fire, barrel select, a 2.0 s uninterruptible reload, slug/buckshot that
loads only when open, server-authoritative hits, `Runtime:takeHit` on the boar with zone `"body"`,
the Hud crosshair, and the `GAME_DESIGN.md` owner rows. Default camera: nothing writes
`workspace.CurrentCamera`. **Feel-critical: not to be merged until Karen has played it.**

## Claims

1. **The design was re-run first and the six defects are fixed in it**, not worked around in code:
   `reviews/task-24/BRIEF.md` lists them, `reviews/task-24/ARCH_RESULT.md` is `PASS`, and the design's
   §2.1 names each fix. The code is built to that document.

2. **The cast seam carries the shooter** (defect a). `CastFn` is
   `(origin, direction, ignore) -> Impact?`; `Weapon.Cast.world` is the only caller of
   `Workspace:Raycast` in `src/server/Weapon/`; `onFireRequest` builds one ignore list per shot from
   the shooter's character and passes it to **both** the camera ray and every pellet.
   `weapon_hits.spec` counts the casts, asserts each got the same list unmodified, and proves the list
   really reaches `FilterDescendantsInstances` by casting at a real part with and without it.

3. **Freezing is deep** (defect b). `Shotgun.deepFreeze` is applied to `CONFIG`, to every state the
   reducer returns, to every snapshot and to the replica on arrival; `weapon_state.spec` and
   `weapon_client.spec` both assert a **nested** write throws.

4. **The per-player lifecycle is closed and tested** (defect c). `Weapon.forget` calls
   `Registry:forget`, which drops every table keyed by that player, and `Players.PlayerRemoving` calls
   it. `Registry` never knows what a `Player` is, so `weapon_state.spec` exercises
   `set`/`get`/`bucket`/`forget`/`count` with a stand-in key.

5. **A client can reach only `Reload` and `SelectAmmo`** (defect d). `Validator.checkRequest` is the
   whitelist; `weapon_shot.spec` lists every rejected value including all four reducer primitives, and
   `weapon_client.spec` fires them at the real server over the real remote and asserts the snapshot
   does not move.

6. **The safety arc uses the muzzle direction** (defect e) — `onFireRequest` passes `aim`, the
   muzzle→aim-point unit vector, never the client's camera direction. **And the spread spec is not
   flaky** (defect f): `Buck` only, seed 1337, 9,000 directions, max/mean bounds as literals.

7. **The boar seam is one function on the boar's own owner.** `Boar.Body.create` publishes
   `Damageable` and `HitZone`; `Runtime:takeHit(part, hit)` counts and fires `Runtime.Hit` and changes
   nothing else; `BoarBoot` connects `Weapon.HitReported` to it, so neither owner requires the other.
   `boar_hit.spec` asserts the attributes, the counters, the signal, the refusal of a foreign part,
   **and that a hit does not move the boar** — the assertion that keeps 1.5's reaction out of 1.4.

8. **Nothing writes the camera.** `Input.luau` reads `workspace.CurrentCamera.CFrame` for the aim ray
   and assigns nothing; grep `CurrentCamera`, `CameraType`, `FieldOfView`, `CameraSubject`,
   `MouseBehavior` under `src/client/` for assignments. `weapon_client.spec` samples the camera at the
   aim-down and aim-up edges: `CameraType`, `FieldOfView` and `CameraSubject` identical, and the
   measured drift relative to the camera's subject printed **0.000 studs**.

9. **It was driven through the real input path and ended where the design says.** The new scenario
   `weapon-fire-reload-ammo` sends the cue, three clicks, one `R`, one `X` and an aim hold; the spec
   asserts over `Weapon.Changed` snapshots: exactly **two** shots (the third click hit an empty gun),
   automatic barrel select after the first, `busyFor > 0` during the reload, and the end state
   `Live/Live, Slug/Slug, selected 1, ammo Buck, reserve 22`. The crosshair assertion walks **every
   ancestor** for visibility and checks the centre against the viewport (measured 479.0,287.5 both).

10. **Three measurements contradicted the design, and the code follows the measurements** (rule 6,
    all recorded in the commits and in `TASKS.md`): a replayed step costs ~1 s of wall time, so no
    client assertion may depend on two inputs landing inside a 0.25 s or 2.0 s window — those two
    rejections are proved exactly in `weapon_state.spec` instead; `AbsolutePosition` ignores
    `IgnoreGuiInset`, so the centring check adds the inset back; and `AUTO_EQUIP = true` meant Task 6's
    own scenario fired the gun, so the weapon spec parks the Tool before signalling ready.

## What I could not verify

- **Karen has not played it.** Every feel number in the design's §12 is a default.
- **The `.model.json` fallback was not needed:** Rojo maps `src/shared/Shotgun/Remotes.model.json`
  inside the folder module, and the harness compares all four RemoteEvents (design §8 asked which).
- **`execute_luau` gets its own module cache**, so `Weapon.stats()` read through it returns a fresh
  module's zeros. Screenshot evidence therefore comes from the Hud readout and the effect Instances,
  not from that call. Harness faults are bugs (rule 6) — this is a Studio MCP property, not ours, but
  it will mislead the next person who tries it.
- **Screenshots (rule 5), four, inspected:** the gun in hand from behind with the crosshair centred and
  `[*]* SLUG 24` in the corner; a close side view showing the barrel pointing **away** from the player
  (the grip is not backwards); a slug impact **on the boar** (the orange marker on its flank, with the
  impact position 2 studs inside the body volume); and the re-check after raising `HANDLE_COLOR`,
  which the design told me to check on screen — `RGB(70, 55, 45)` read near-black, exactly the Task 22
  albedo trap, and is now `RGB(190, 145, 95)`.
- **I could not frame a tracer**: it lives 0.06 s and every MCP call costs ~1 s.
