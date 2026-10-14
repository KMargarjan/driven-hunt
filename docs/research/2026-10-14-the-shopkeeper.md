# The shopkeeper: a person at the counter, and `E` as the one way into the shop

2026-10-14, task 181. Written before the code, per CLAUDE.md rule 1.

Karen, 2026-10-14 ~09:30, verbatim:

> in lobby has to be a person bot who you need to click E to get access to shop

---

## 1. What the system must do

1. Put a **person** behind the shop counter task 177 built and task 178 opened — not a sign, not a
   trigger volume: somebody standing there.
2. Make **pressing a key at him** the way into the shop panel, on a keyboard, a gamepad and a phone.
3. **Take away task 178's "walk up and it opens by itself"**, so there is exactly one way in. Karen
   asked to *click E to get access*, and a panel that is already open when you arrive makes the key
   decorative.
4. Keep the shop itself **exactly as task 178 built it**: the same catalogue, the same
   server-authoritative door, the same reach check per purchase. Only the opener changes.
5. Cost nothing per frame. The lobby's own builder states the rule: *"nothing here is animated and
   nothing is written per frame"*.

### What it must not do

* Must not become a second owner of the shop, of the panel's `Visible`, or of a player's money.
* Must not put a Script, LocalScript or ModuleScript into `Workspace` (CLAUDE.md; the harness fails
  on one).
* Must not let the keeper be pushed, shot, walked into, or counted as a hit — a body in the lobby
  that stops a pellet changes what a shot hit (`ForestTest.Markers`' rule, which the lobby's own
  parts already follow).
* Must not make the DEV place depend on him: `Lobby.ANCHORS` has one row, so the DEV place has no
  lodge, no counter and now no keeper, and the specs must build him into a folder of their own.

---

## 2. The three ways a Roblox player can "use" a thing in the world

### 2a. `ProximityPrompt` — **ADOPTED, and it reverses two recorded rejections**
<https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt> ·
<https://create.roblox.com/docs/ui/proximity-prompts>
*Licence:* CC BY 4.0. *Maintenance:* first-party, current.

**Well:** it is the engine's own "press E to use this object". It draws its own prompt beside the
object, it has `MaxActivationDistance`, `RequiresLineOfSight`, `ActionText` and `ObjectText` as
properties rather than as code, and — the reason it wins here — **one property set does keyboard,
gamepad and touch at once**: the prompt is triggered by `KeyboardKeyCode`, by `GamepadKeyCode`, and
on a touch device by tapping the prompt itself. `Triggered` fires on the server **and** on the
client that triggered it, so the client can open its own panel with no round trip and the server
learns nothing it did not already know.

**Badly:** it draws a piece of UI this project does not own (`docs/design/hud-clarity.md` owns the
screen), and its look is the platform's, not ours.

**Why the two rejections do not apply.** `docs/design/lobby.md` §14.3 rejected it for the truck spot
because *"it is a BUTTON. Karen asked to walk to the car, not to hold E at it"*, and
`docs/design/shop.md` §15.5 rejected it for the counter because *"the prompt's own UI is a second
drawn thing"*. The first reason is **inverted by this dispatch**: Karen has now asked, in her own
words, for the button. The second is a real cost and is **accepted**, because the alternative to the
platform's prompt is drawing our own "press E" label over a world position — the same second drawn
thing, with a worse look and a third owner. Recorded here so the reversal is a decision and not a
drift.

### 2b. A `ContextActionService` key bound while standing near — **REJECTED (it is what task 178 has)**
<https://create.roblox.com/docs/reference/engine/classes/ContextActionService>
*Licence:* CC BY 4.0. *Maintenance:* first-party, current.
**Well:** no new UI, and the binding already exists (`DrivenHunt.Shop.Toggle`, `E`).
**Badly:** it tells the player nothing. There is no prompt over the counter, so "press E" has to be
taught somewhere else; on a phone there is no key at all; and a `Sink`ing `E` binding within 14
studs of the counter would **swallow the prompt's own `E`** if both existed. That last one is not a
preference: two owners of one key is the exact failure CLAUDE.md rule 3 exists for. So the binding
is **removed**, not kept beside the prompt.

### 2c. Valve, `func_button` + the `+use` key — the pattern the engine's prompt is an instance of
<https://developer.valvesoftware.com/wiki/Func_button> ·
<https://developer.valvesoftware.com/wiki/%2Buse>
*Licence:* CC BY-SA (the VDC wiki's own). *Maintenance:* community wiki, actively edited; the entity
ships in every Source game.
**Well:** the oldest and most-played version of this exact interaction — walk up to a thing in the
world, look at it, press the use key, something opens. It fixes the two numbers that matter:
Source's `+use` has a **maximum use distance** and requires the player to be **looking at** the
entity, rather than merely being inside a radius. That is exactly `MaxActivationDistance` plus
`RequiresLineOfSight`, and it is why both are set here rather than left at their defaults.
**Badly:** it is a brush entity in a compiled map; there is no such thing in Roblox.
**Adopted:** the IDEA, implemented as 2a.

### 2d. A `ClickDetector` — **REJECTED**
<https://create.roblox.com/docs/reference/engine/classes/ClickDetector>
*Licence:* CC BY 4.0. *Maintenance:* first-party, current.
**Well:** one instance, `MouseClick` carries the player, works on touch.
**Badly:** it needs a free mouse cursor, and this game locks the cursor to the middle of the screen
for the gun (`Camera.Cursor`). Karen asked for `E`, not for a click, and the one thing a
`ClickDetector` adds over a prompt — clicking from across the room — is the thing we do not want.

---

## 3. What the person is made of

### 3a. `Players:CreateHumanoidModelFromDescription` — **ADOPTED, through an injected seam**
<https://create.roblox.com/docs/reference/engine/classes/Players#CreateHumanoidModelFromDescription>
*Licence:* CC BY 4.0. *Maintenance:* first-party, current.
**Well:** one call is a complete R15 body with a Humanoid, so there is no hand-built rig, no fifteen
`Motor6D`s written by hand, and no `.rbxm` (banned). **This repository already does exactly this**:
`src/server/Bots/Rig.luau` builds every drive bot this way, with an **empty** `HumanoidDescription`
so nothing is fetched, and dresses it afterwards through `Match.Body`.
**Badly:** it is documented to load assets, so it **may yield**, and in a spec it would reach the
avatar service. Both are solved the way `Bots.Rig` solves them: the source is an injected function
(`Build.setRigSource`), the default is the engine's call inside a `pcall`, and every spec hands in a
fake body. The one possible yield happens once, at lobby build, inside the figure
`Lobby.stats().buildMs` already reports.

### 3b. The clothes: `Match.Body.dress`, through the seam that already exists — **BORROWED WHOLE**
`src/server/Match/Body.luau` (`Body.dress(character, team, config, look)`), `src/server/Bots/init.luau`
(`world.dress`), `src/server/ForestTestBoot.server.luau` (`dress = Body.dress`).
*Licence:* this project's own. *Maintenance:* live, tasks 151, 168, 178.
**Well:** `Body.dress` takes a **Model**, not a Player — which is why the bots already wear the same
green the players do — and task 178 gave it a `Look` (`{ hatColor = Color3 }`) for the shop's red
hat. So a lodge keeper in hunter green with a hat of his own is **one existing call with one
existing parameter**, and there is still exactly one dressing path in this repository.
**Badly:** `Look` recolours the hat only (`Body.tintFor` refuses every other slot, deliberately), so
"a different apron colour" is not reachable without widening another owner's type. Not widened: the
hat is the difference, and the report says so.

### 3c. A free catalogue outfit, or a bought Creator Store NPC — **REJECTED**
Task 180 measured what it costs to get a free model into this place
(`docs/research/2026-10-14-lobby-free-models.md`): a human click in Studio, a template parked in
`Workspace.LobbyAssets`, and a fallback build for every place that has not got it. For **one body
the engine makes in one call**, that is a Karen click bought with nothing.

### 3d. The idle and the look-at
The idle clip is `rbxassetid://507766666` — **`Bots.Rig.CLIPS.idle`, the same asset the drive bots
already stand in**, loaded through the Humanoid's `Animator`, played once at build and never written
again. `Rig.prepare`'s own measured note applies and is repeated in the code: a track that loads is
evidence the **call** succeeded, not that the body is moving, so the picture is still what says so
(rule 5).

The look-at is **one yaw write on the lobby's own existing 10 Hz scan**, not a new clock:
`Lobby.step` already walks every occupant's root part every scan, so the nearest one is free, and
the write happens only when the yaw moves more than `KEEPER.FACE_EPSILON_DEGREES`. The lobby owner
decides and `Lobby.Build` writes, which keeps *"the one writer of every part in `Workspace.Lobby`"*
true.

---

## 4. The numeric targets

| Number | Value | Where it comes from |
|---|---|---|
| `MaxActivationDistance` | **8 studs** | the Director's dispatch. The counter is 12 studs wide and 2 deep and the keeper stands ~1.4 studs behind it, so 8 reaches a man anywhere along the front of it and stops short of the fireplace |
| `RequiresLineOfSight` | **true** | Valve's `+use` (§2c): you use what you are looking at, not what is behind the wall |
| `HoldDuration` | **0 s** | a tap, not a hold. A hold is for a thing you can do by accident; opening a shop panel is not one |
| `KeyboardKeyCode` | **E** | Karen's word. It is free in `src/`: the bound keys are Tab, R, X, M and the report's arrows — and task 178's own `E` binding is **removed** in this task, so there is one owner of it |
| the close distance | **14 studs**, `Shop.CONFIG.REACH_STUDS`, unchanged | the dispatch says "beyond ~12". 14 is used instead because it is the **same number the server refuses a purchase at**: the panel is then open exactly while buying is possible, and "it is open but every press is refused" cannot happen. One fact, one place |
| the keeper's parts | **anchored root, every part `CanCollide = false`, `CanQuery = false`, `CanTouch = false`** | the lobby spec's existing rule for every part in the tree, plus `Bots.Rig.prepare`'s measured reason: a body that stops a pellet changes what the shot hit |
| the per-frame cost | **0** | one animation played at build; one yaw write per 10 Hz scan, and only when it changes |

---

## 5. What is borrowed from inside this repository (rule 2 applies to internal patterns too)

* **the injected rig source with an engine default, pcall-ed** — `Bots.Rig.setSource`;
* **the stander's humanoid** — `Bots.Rig.prepare` with `walks = false`: no state machine, no jump,
  `WalkSpeed = 0`, name tag off;
* **the memoised world reader whose cache dies with the instance** — `Lobby.spotPart` /
  `Lobby.counterPart` (*"a stale dot is a lie about where somebody is"*);
* **TOLD, never read** — `Rail.setWeapon` / `ShopPanel.setNear`: the Hud resolves the prompt once a
  frame and hands it to the panel, so the panel still reads no world;
* **the public handler the wire calls, so a spec drives the real path** — `ShopPanel.press`,
  `Hud.onHitMarker`: a spec cannot fire a real `ProximityPrompt.Triggered`, so
  `ShopPanel.onPromptTriggered` is the seam, and `setPrompt` takes anything carrying a `Triggered`
  signal so a spec drives a `BindableEvent` through the same connection the real prompt uses.

---

## 6. What this note could not verify

* **That `Triggered` reaches a client in this place.** It is documented
  (<https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt#Triggered>) and the
  wiring is specced against a `BindableEvent`, but the only proof that the real prompt opens the
  real panel is a Play session and a screenshot (rule 5).
* **Whether an anchored-root rig with unanchored limbs keeps its idle animation in this place.**
  `Bots.Rig` anchors a stander's root and plays clips, which is the same arrangement, but the bots
  stand outdoors and nobody has photographed one closely. The screenshot is the evidence.
