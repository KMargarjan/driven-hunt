# Task 24 — the shotgun on the default camera

Task: 24
Round: 2
Base: `bb674dc`
Code commit: `110d869b94cc90e31713b24e857bc21eced4ab7b`

```
[harness] PASS: 26/26 checks @ 110d869b94cc90e31713b24e857bc21eced4ab7b (clean tree)
```

79 server assertions across 8 spec files and 26 client assertions across 3 (main had 39 and 11). The
last commit that changed anything but paperwork is `57f5964`; `110d869` adds only
`reviews/task-24/RESULT.md`, and the harness line above covers both.

## Task

Director, 2026-09-25: fix the design's six known defects, then build its scope — a Tool on spawn,
fire, barrel select, a 2.0 s uninterruptible reload, slug/buckshot that loads only when open,
server-authoritative hits, `Runtime:takeHit` with zone `"body"`, the Hud crosshair, and the
`GAME_DESIGN.md` owner rows. Default camera: nothing writes `workspace.CurrentCamera`.
**Feel-critical: not to be merged until Karen has played it.**

## Claims

1. **Round 1's blocking finding is fixed, and the fix is the point of the test.**
   `boar_hit.spec`'s teardown test counted `BindableEvent` descendants of its own folder — but the
   runtime never parents its signals, so it read 0 before `destroy()`, after it, and with
   `_hitSignal:Destroy()` deleted. It now holds a connection to `runtime.Hit` and `runtime.Despawned`,
   asserts both are `Connected`, destroys, and asserts both are not. Delete the destroy line and it
   goes red.

2. **Six of round 1's twelve notes are fixed in the same round**, because each was a real defect
   rather than wording: `runReload` walked past **every** `Load` rejection and now continues only
   through `"no-reserve"`; `Shotgun.remotes()` is resolved once in `start()`; the unread `lastPublish`
   table is gone; one Tool-Parent watcher per player instead of one per respawn, and the client binds
   a Tool's `Equipped`/`Unequipped` once instead of once per move between Backpack and character;
   `weapon_shot`'s cost budget grouped nothing (every impact had `instance = nil`) and now hits a real
   `Damageable` part and asserts the report; the camera-drift measurement could silently vanish and is
   now asserted to exist. The remaining six are queued in `TASKS.md` row 24a.

3. **The design was re-run first** (`reviews/task-24/BRIEF.md` → `ARCH_RESULT.md` = `PASS`), and its
   §2.1 fixes the six Task 23 defects. The code is built to that document.

4. **The cast seam carries the shooter** (defect a): `CastFn` is `(origin, direction, ignore)`,
   `Cast.world` is the only `Workspace:Raycast` in `src/server/Weapon/`, and `onFireRequest` builds one
   ignore list per shot and gives it to the camera ray **and** every pellet. `weapon_hits.spec` counts
   the casts, checks each got the same list unmodified, and proves the list reaches
   `FilterDescendantsInstances` against a real part.

5. **Freezing is deep** (b), **the per-player lifecycle is closed and tested** (c: `Weapon.forget` →
   `Registry:forget`, exercised with a stand-in key), **a client reaches only `Reload` and
   `SelectAmmo`** (d: `Validator.checkRequest`, asserted in a server spec by list and in the client
   spec over the real remote), **the safety arc uses the muzzle direction** (e), and **the spread spec
   is seeded and bounded** (f: `Buck` only, 9,000 directions, max/mean literals).

6. **The boar seam is one function on the boar's own owner.** `Body.create` publishes `Damageable`
   and `HitZone`; `Runtime:takeHit` counts, fires `Runtime.Hit`, and changes nothing else; `BoarBoot`
   wires `Weapon.HitReported` to it. `boar_hit.spec` asserts the attributes, the counters, the signal,
   the refusal of a foreign part, and **that a hit does not move the boar** — which is what keeps
   1.5's reaction out of 1.4.

7. **Nothing writes the camera.** `Input.luau` reads `CurrentCamera.CFrame` and assigns nothing;
   `weapon_client.spec` samples at both aim edges — `CameraType`, `FieldOfView` and `CameraSubject`
   identical, measured drift printed **0.000 studs**.

8. **It was driven through the real input path.** The `weapon-fire-reload-ammo` scenario sends the
   cue, three clicks, one `R`, one `X` and an aim hold; the spec asserts exactly **two** shots (the
   third click hit an empty gun), automatic barrel select, `busyFor > 0` during the reload, and the end
   state `Live/Live, Slug/Slug, selected 1, ammo Buck, reserve 22`. The crosshair check walks every
   ancestor for reachability and compares the centre with the viewport (479.0,287.5 both).

9. **Four measurements contradicted the design and the code follows the measurements** (rule 6): a
   replayed step costs ~1 s, so no client assertion depends on two inputs landing inside a 0.25 s or
   2.0 s window — both rejections are proved exactly in `weapon_state.spec`; `AbsolutePosition` ignores
   `IgnoreGuiInset`; `AUTO_EQUIP = true` let Task 6's scenario fire the gun, so the spec parks the Tool
   before signalling ready; and `HANDLE_COLOR` `RGB(70, 55, 45)` read near-black on screen — the Task 22
   albedo trap — and is now `RGB(190, 145, 95)`.

10. **Screenshots (rule 5), five, inspected by me:** the gun in hand with the crosshair centred and
    `[*]* SLUG 24`; a close side view showing the barrel pointing **away** from the player; a slug
    impact **on the boar** (orange marker on its flank, impact position inside the body volume); the
    near-black handle that made me change the colour; and the re-check afterwards, where the gun reads
    as a warm brown object in the hand.

## What I could not verify

- **Karen has not played it.** Every feel number is a default.
- **`execute_luau` has its own module cache**, so `Weapon.stats()` read through it returns a fresh
  module's zeros. Screenshot evidence therefore rests on the Hud readout and the effect Instances.
  Worth knowing before someone trusts that call (rule 6).
- **No tracer screenshot**: it lives 0.06 s and an MCP call costs ~1 s.
- **The design is now stale on the scenario** (it still describes five clicks and two `R`s). The
  Builder may not edit `docs/design/` (rule 3), so it is queued in `TASKS.md` row 24a for the next
  regeneration, together with the other five round-1 notes.
