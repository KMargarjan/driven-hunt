# Task 28 — hit zones, wounds and the hit marker

Task: 28
Round: 1
Base: `a8fde68`
Code commit: `1f0642bb963ae62ff6037b3023cec6ffa2fa9129`

```
[harness] PASS: 26/26 checks @ 1f0642bb963ae62ff6037b3023cec6ffa2fa9129 (clean tree)
```

156 server and 44 client `it` blocks across 16 spec files (`main` had 96 and 37).

## Task

ROADMAP 1.5, built to `docs/design/hit-zones.md` (Architect, Task 27), with the Director's decisions
on its §14: **A** no damage router (not now), **B** a 120 s carcass removed by the boar runtime,
**C** the hit marker **is** in this task, E/F/G as written. **D** (a harness step that places the
character and aims the camera) is **queued, not built** — see claim 8.

## Claims

1. **The zones are reachable by real rays, and that is the assertion that matters.**
   `boar_zones.spec` fires **twelve** rays from outside a live boar, in its own frame, and reads the
   zone back through the **weapon's** `Hits.targetOf`: head from the front, both flanks and above;
   chest from both flanks and above; legs low on a flank and at the rear; body at both mid-flanks and
   the rear above the hams. Nest a zone part inside the trunk (design §4.1's trap — a ray returns the
   nearest surface, so every shot would report `body` while a `takeHit(zone = "head")` spec passed
   happily) and these go red. It also asserts the ancestor walk resolves to the trunk, `Damageable` is
   on the trunk **alone**, and the runtime folder still holds exactly **one** `BasePart`, so
   `boar_body.spec` is undisturbed.

2. **The weapon did not change, except where the Director told it to.** Design §2.2's test for its own
   seam is "nothing in the weapon changes"; the only weapon edits are the ones decision C requires —
   a fifth RemoteEvent and `Weapon.markHit` — plus one line in the fire loop. No damage number, no
   zone table, no health concept anywhere in `src/server/Weapon/`, `src/client/Weapon/` or
   `src/shared/Shotgun/`. `Hits.targetOf` was **read before anything was written** (design §2.3): it
   already walks ancestors and prefers the hit instance's `HitZone`, and `report.zones` already
   carries the per-pellet tally, so the seam took the zone parts unmodified.

3. **The wound model is pure, frozen and exact.** `Boar.Wound` has no state, no Instance, no clock,
   no `Player` and no `Random`; every state it returns is deep-frozen (a write throws) and `apply`
   never touches its input. `boar_wound.spec` writes its own config table rather than importing
   `CONFIG` — so it cannot agree with a broken config by construction — and checks the damage table,
   the thresholds, the four flight distances (108, 336, 126, 0), buckshot per-pellet tallies, the
   tally-less fallback flag, contributors, the speed ramp and the kill record. **One** test closes
   the loop the other way, comparing that table with production's.

4. **A hit reads as a hit, within one tick.** `takeHit` → the Brain reacts at the top of `step`,
   before the sense gate: the boar bolts at `SPRINT * BOLT_KICK` with no `ACCEL` ramp, away from the
   shot point, with no threat anywhere near. **Measured live: 2 ms** (`boar_hit.spec` prints it), not
   the 200 ms a sense-gated reaction would cost. `WOUNDED` never returns to `IDLE`, still routes to
   the exit line by the existing `FLEE` code, and the wound scales the speed **setpoint** — measured
   live at **29.4 studs/s against a 38-stud sprint** with `speedScale 0.75`.

5. **The kill, the carcass and the escape are three separate published facts.** `Downed` fires
   exactly once with the killing zone, ammo, distance, shooter and whether it dropped on the spot; the
   body collapses (mover off, upright off, `Damageable = false`, `Carcass = true`); a further
   `takeHit` returns `false` and moves no counter, so 1.7 cannot count one animal twice; `Despawned`
   follows at `CARCASS_SECONDS` with `reason = "killed"`. A mortally wounded boar that crosses the
   exit line fires `Despawned` with `reason = "escaped"`, `mortallyWounded = true` and the wound
   payload. `stats().downed` counts deaths and `stats().killed` counts carcasses removed — I read
   design §11.3's "downed == killed" as "after the carcass expires", and say so here because it is an
   interpretation.

6. **The design's collapse number does not work, and the screenshot is what caught it** (rule 5 and
   rule 6). `COLLAPSE_ANGULAR_IMPULSE = 1200` left a dead boar **standing to attention**. Probed in
   Play against a body moving at a sprint: 1200 and 2000 do not topple it; 3500 topples it but throws
   it 9 studs into the air; 12000 launched the real boar to y = 87 at 161 studs/s; setting
   `AssemblyAngularVelocity` directly topples it at no rate up to 12 rad/s. Replaced by
   `COLLAPSE_ROLL_DEG = 45` — past the box's 33.7-degree tipping angle, so **gravity** lays it down:
   peak height 0.2 studs, final `UpVector.Y = 0.00`. One CFrame write at death, not the per-frame
   CFrame writing `boar-ai.md` §6 forbids. `boar_hit.spec` now asserts the topple.

7. **The design's performance target was impossible as written, and the measurement says why.**
   §12.1 item 12 asks for 10000 applies under 100 ms; its own immutability rule makes that quadratic,
   because each apply copies the wound history. Measured: **1959 ms**. It also cannot happen — the
   smallest charge is 6 points against `MORTAL = 50`, so nine hits make any boar mortal and a downed
   boar refuses hits. Split into what the target protected: 10000 applies onto a realistic history,
   200 accumulating applies, and 10000 per-tick `speedScale`+`advance` pairs, all measured and
   printed.

8. **The hit marker is proved on both sides, by the side that owns each.** Server: `weapon_hits.spec`
   calls `Weapon.markHit` and counts it, and it refuses a non-`Player` shooter. Client:
   `hit_marker.spec` waits for a marker **sent by the server over the real remote** (the client cannot
   fire a server → client event, so nothing about that is fakeable), asserts the Hud's own connection
   is live, and drives the drawing through `Hud.onHitMarker` — the exact function the remote is bound
   to. Owners: the weapon owns the remote and knows nothing of boars, `BoarBoot` turns `Downed` into
   a kill marker, the **Hud** is the only thing that draws.

9. **Every number is in one config table, with Karen's dials marked.** `CONFIG.ZONES` and
   `CONFIG.WOUND` in `Boar.CONFIG`; the marker's numbers in `Shotgun.CONFIG` beside the crosshair's,
   because anything drawn is the Hud's. No magic number anywhere else. `GAME_DESIGN.md`'s Boar and UI
   owner rows are amended; `Game state` is deliberately still `_unassigned_`.

10. **The research note checked every source the design cited from memory, and two were wrong**
    (`docs/research/2026-09-25-hit-zones.md`, rule 1): the `RaycastHitbox` URL does not exist (it is
    `Swordphin/raycastHitboxRbxl`, MIT) and "a ray returns the first surface" is **not** on the page
    cited for it — which is why claim 1 proves it with rays instead. The Stokke et al. 2018 paper is
    real, CC BY 4.0, and independently validates two numbers the design called first guesses:
    `efd = 1.14·M^0.73` and `mfd = 4.92·M^0.73` give **100 and 429 studs** at 80 kg against
    `FLIGHT.body = 120` and `FLIGHT.legs = 420`.

## What I could not verify

- **Karen has not played it.** Every feel value is the design's default, `ZONE_TINT` included.
- **The flash could not be photographed.** It lasts `FLASH_SECONDS = 0.25`; one capture round trip is
  about a second. The property change is asserted in `boar_hit.spec` (flash on, own colours back,
  zone tint intact) and the capture was not attempted rather than implied.
- **Every screenshot of a shot is staged**, because the harness cannot aim (design §12.5, and D is
  queued): a scratchpad script teleports the character and has the **client** compute a direction and
  fire the **real** `FireRequest` remote. Validation, the cast, the pellets, `takeHit`, the wound
  model and the collapse are all production code; only the aiming is scripted.
- **The client's "a server marker arrived" test depends on run ordering.** It waits 30 s for the
  markers `weapon_hits.spec` sends in the same Play session. It passed in both runs; if the server
  side ever runs late, that test is the one that would flake.
- **Design §12.3's "belly from below behind the legs band" does not exist**: `ZoneLegs` spans the
  whole length, so from below a boar is all legs. The three body rays are the two mid-flanks and the
  rear above the hams instead.
- **`unknownZoneHits` counts hits, not pellets** (the design names neither), and `zoneHits` counts
  **pellets** per zone so that it sums to `pelletsTaken`.
