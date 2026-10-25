# Task 266 round 2 — the two corrections the Reviewer's round-1 findings require

`MEASURED.md` beside this file is round 1's readings, **left exactly as written**. This file says
what was wrong with the conclusions drawn from them. Both findings are right and neither is disputed.

---

## FINDING 1 — the metric could not fail, and here is one that can

### What was wrong

`266shot.py`'s `offTarget` is the angle between the live camera's `LookVector` and the point in
`DHTestLook` — **the attribute the probe itself writes**, which `Camera.step` reads every frame and
`Mode.anglesToward` converges on. So it measures the camera against the probe's own steering input
and reads ~0 whatever that point is. Deleting the producer (the `RenderStepped` tracker, i.e.
reverting to task 265's fixed point) leaves the number unchanged. Round 1's PLAN (b) leaned on it —
*"the held view on a running animal's chest, `offTarget=0.307 deg`"* — and that sentence is withdrawn.

### The metric that can fail, computed from readings round 1 already took

`DH266Trigger` records, **on the frame `UserInputService.InputBegan` fired** — the very event
`Weapon.Input.fire` answers — the camera's position and `LookVector` **and** the target trunk's own
`CFrame.Position` and `AssemblyLinearVelocity`. Those are two independent quantities: the camera the
client read, and where the animal was. The angle between them is blind to nothing and cannot be
produced by the tracker, because the animal's position is not something the probe writes.

Computed from the five `TRIGGER` lines round 1 printed (the arithmetic is `acos` of the normalised
dot, and the perpendicular miss is `range * sin(angle)`):

| shot | gun / load | range | **angle, trigger-frame camera → trunk centre** | **perpendicular miss** | target speed | landed? |
|---|---|---|---|---|---|---|
| A `Boar37`, no lead | shotgun / Buck | 133.0 | **0.225°** | **0.52 studs** | 4.51 | no |
| B `Boar62`, no lead | shotgun / Buck | 120.9 | **0.362°** | **0.76 studs** | 24.00 | no |
| C `Boar80`, with lead | shotgun / Buck | 127.3 | **0.414°** | **0.92 studs** | 24.00 | no |
| D `Boar3`, no lead | shotgun / Buck | 39.7 | **1.584°** | **1.10 studs** | 28.35 | **yes** |
| E `Boar3`, no lead | shotgun / Buck | 275.0 | **0.166°** | **0.80 studs** | 28.57 | no |

**What it says, and all it says:** the trigger-frame camera was pointing within 0.17-1.58° of the
animal's trunk centre, which is 0.52-1.10 studs perpendicular at those ranges. It is **not** an
aiming-error measurement of the gun, for a reason that must be said rather than left for the next
review to find: the aim point is the **chest zone**, not the trunk centre (`chestLocal` was read as
`0.000, 0.555, -0.600` for a male and `0.000, 0.472, -0.510` for a female, i.e. roughly 0.6 studs
forward and 0.5 up of the trunk origin), so a perfect chest shot does not read 0 here. It bounds the
aim; it does not measure it.

### And the misses are the AMMO, which is the honest reading

**Four of those five shots could not reach their target.** `Shotgun.CONFIG.RANGE_STUDS =
{ Slug = 330, Buck = 100 }`, the reserve was `Buck=12 Slug=0`, and the ranges above are 120.9, 127.3,
133.0 and 275.0 studs. **The one shot inside 100 studs (D, 39.7) is the one that landed.** So
nothing in round 1's batch is evidence about aiming at a running animal, in either direction, and
round 1's PLAN (b) sentence about a click that *"hit nothing at all"* is a shot that was never in
range. That is a property of what the Forest Test hands a shooter, measured in `MEASURED.md` §3, and
the instrument now takes `--range` and polls for a crossing because of it.

---

## FINDING 2 — the stated cause is WITHDRAWN. The silence is still undiagnosed.

### What was wrong

Round 1's claim 6 said the `ShotFired=0` silence was caused by the player being a beater holding a
horn. **The reading it cites contradicts it**, and the Reviewer is right:

* `266diag.py`'s own output ends every read with `tool=Shotgun` — and that is
  `me.Character:FindFirstChildOfClass("Tool")` **on the client**, during the silence being explained;
* the eye in the first selftest, `3029.99,144.71,-2096.99`, is the shooter's stand position
  (`PRE OK ... at 3030,143,-2097`), **not** the beater's `3660,190,-2670`.

So the two readings are from **different moments of the same Play session**, and the order is:
`aimshot --selftest` (5 clicks → 1 `ShotLanded`) and both `266diag` runs (9 clicks → 0 `ShotFired`)
came FIRST, at the stand, with a shotgun; then the Forest Test console shows `[report] drive 2
opened` and `Alhamdulilah824 is a beater at (3660, 191, -2670)`; and only then did `266-who.luau`
read `team=Drivers held=[Horn]`.

### What is therefore established, and what is not

**ESTABLISHED (a real, separate silence mode, demonstrated twice):** a player who is not a shooter
with a gun clicks and the game answers NOTHING — `Weapon.heldId` does not know a Horn, `id` falls
back to `Weapons.PRIMARY`, `stateOf` is nil, and `onFireRequest` does `return "untracked"` with no
publish of any kind. `266shot.py` refused on exactly that state (`PRE FAIL (not a shooter)
team=Drivers held=[Horn]`) in the next Play session, and that refusal is worth having.

**NOT ESTABLISHED, and withdrawn:** that this is what silenced the nine clicks at the stand. It is
not; the player was a shooter with a shotgun for all of them. **Those nine clicks are still
undiagnosed.** The Reviewer names candidates I cannot separate without a session, and each one is
silent in exactly the same way:

1. `Validator.checkShot` refusing (`not-alive`, `origin-far`, `not-unit`) — the publish on that path
   is **unforced and carries no `refused`**, so nothing reaches the client;
2. the reducer refusing (`is-open` during a 2.0-2.9 s reload sequence) — same unforced publish;
3. `untracked` **with a shotgun in hand**: `Weapon.heldId` reads `entry.held`, written only by
   `watchEquipped`'s sync, so an equip the server has not synced gives the same silence;
4. `Input.isHeld()` — a hold tag left set by a panel (`PadPanel` sets `"padsize"` / `"nextdrive"`,
   `ReportPanel` `"report"`, `ShopPanel` `"shop"`). `Input.fire` then returns `false` and **no
   request is sent at all**, which is what `gameProcessed=false` plus `ShotFired=0` looks like.
   `266-holds.luau` proves this cannot be read from a probe: `watchedTools=0` on a client with a Tool
   equipped means the probe got a **fresh** module copy, so `Input.isHeld()` there is always `false`.

### What round 2's precheck must gate on, per the finding

Not a Tool child plus a team name — **evidence that the server actually tracks this player's
weapon**: a `StateChanged` snapshot observed in this session. The probe already stores one
(`DH266Ammo`, e.g. `selected=2 loaded=None|Buck reserve{Buck=12 Slug=0} open=false`), so the gate is
to require a snapshot with a loaded chamber and `open=false` **before** the click, and to treat its
absence as an instrument fault. That is a change to `266shot.py` that **cannot be demonstrated
without a live Forest Test session**, and the Forest Test window was closed for this task's harness
runs (the Director's standing block). See `ESCALATE.md`.
