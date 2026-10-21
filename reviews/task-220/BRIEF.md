# Task 220 — design brief for the ARCHITECT: the game plays on a phone (touch controls)

Written by the Builder, carrying the Director (2026-10-21). This brief is the input to
`tools/architect.ps1 design mobile-controls --task 220` and **overrides anything older** in `docs/`,
`TASKS.md` and any existing design where they disagree (`docs/ARCHITECT_PROMPT.md`).

Read first: **`docs/research/2026-10-20-mobile-controls.md`** (this task's note — five sources with
licences, what the system must do, the pattern adopted, what landscape costs, and the numeric
targets). The design is a **new** `docs/design/mobile-controls.md`, plus whatever delta it needs to
`docs/design/hud-clarity.md` section 6 (the rail) and the design system's §4.2 / §4.3.

Karen, v1 plan 2026-10-11, confirmed *"continue"* 2026-10-19: *"world: ... MOBILE controls"*. Most
Roblox players are on phones. The HUD half exists; **the INPUT is what is missing.**

## 0. The three engine facts, MEASURED (not remembered) — 2026-10-21

The research note §3 forbids any line of the design resting on an unmeasured engine fact
(*"No line of the design may depend on either fact until its measurement is in that file"*). All
three are now measured in a live session and are **inputs to the design, not assumptions**.

| # | Fact | Probe | Result |
|---|---|---|---|
| M1 | `tool:Activate()` from a **LocalScript** fires the **server's** `Tool.Activated` | DEV Play. The server made a Tool, connected `Tool.Activated` and parented it to the Backpack; the client called `Activate()` **twice**; the server counter was read back | `SERVER activated=2` — **it replicates.** So **BLOW needs NO new remote**: it is a second door onto the connection `Horn.grant` already makes |
| M2 | `Humanoid:EquipTool(tool)` from a **LocalScript** moves the Tool into the character **on the server** | the same session: `parentBefore=Backpack`, the client called `hum:EquipTool(tool)`, the server read back | `parentAfterEquip=<character>`, `SERVER equipped=1 toolInCharacter=true` — **it replicates.** So **SWAP needs NO new remote** |
| M3 | `ProximityPrompt.ClickablePrompt` defaults to **true** | DEV Edit, a fresh `Instance.new("ProximityPrompt")` | `ClickablePrompt=true` (with `Enabled=true`, `RequiresLineOfSight=true`, `KeyboardKeyCode=E`). `Build.shopPrompt` never sets the property, so **the lobby interact needs NOTHING BUILT — only verified** |

The probe files are `220-probe-server-setup.luau`, `220-probe-client.luau`,
`220-probe-server-read.luau` and `220-prompt-default.luau` in `<runs-dir>`, driven by `220run.py`
(a Studio driver pinned by **place id**, never by a name — names read null here, which is task 226's
lesson).

Also measured in the same pass, as the desktop baseline: `touchEnabled=false`, `viewport=969, 784`.

## 1. The decisions, already taken — do not re-open them

1. **The engine's own touch controls STAY.** The virtual thumbstick is movement and the camera drag
   is the look; `GuiService.TouchControlsEnabled` is **not** written by anything in this system.
   This repo owns no character controller, and movement is not this task (note §4, source D).
2. **The engine's auto-generated `ContextActionService` buttons are REFUSED** (note source C, two
   reasons: their rectangles cannot wear the design system, so §4.3 cannot be asserted against
   them, and `GetButton` answers nothing on a desktop, so there would be no route to any live
   evidence at all — task 165's own trap).
3. **A SIBLING MODULE, NOT MORE RAIL.** `Hud.Rail` stays **the one owner of its four buttons**
   (MAP / REPORT / RELOAD / AMMO) and is not extended. A new `Hud.Touch` is the one owner of the
   **action cluster**. The reason is reach, from source A: *"A button placed 40% below the screen's
   top edge is reachable on a phone but almost unreachable on a tablet"* — the rail is the top-right
   column under the minimap, and a trigger belongs under the thumb. Two groups, two reach budgets,
   two owners.
4. **What the cluster carries, and nothing else:** **FIRE**, **AIM**, **SWAP** (next weapon) and
   **BLOW** (the beater's horn). RELOAD and the ammo switch are **already** rail buttons and do not
   move or gain a twin. **E / interact gains no button at all** — M3 says the prompt is already
   tappable.
5. **AIM is a TOGGLE on touch and stays a HOLD on the mouse.** Not a preference: on a phone the
   right thumb **is** the camera (sources A and D — the drag is the only look control), so a held
   AIM pins the one finger that aims and leaves none for the trigger. A toggle costs one tap and
   frees the thumb.
6. **ONE INPUT OWNER, enforced by making the KEY the second caller.** `Weapon.Input.fire()` and
   `Weapon.Input.setAim(on)` become the implementations; the existing `onFire` / `onAim`
   `ContextActionService` handlers become two-line callers of them — exactly what task 165 already
   did to `Input.reload` / `Input.selectAmmo`. **A touch FIRE goes through the same `FireRequest`
   the mouse does. ZERO new remotes in this whole task** (M1 and M2 are why that is possible).
   The tagged hold (`Input.isHeld`) is checked **inside** those functions, where task 165 moved it,
   so a tap through an open panel is refused once for both doors.
7. **ONE TAP IS ONE SHOT.** No hold-to-repeat, for any of the four guns. The semi-auto's `AUTO_CYCLE`
   changes what the gun does between shots, not what a finger has to do.
8. **SWAP covers all four guns AND the horn, and is OWNED-ONLY by construction.** It cycles the
   Tools the player is **actually carrying** (`Backpack` + character), which is already the
   owned-only list `Weapons.loadout` handed out (`OWNED_ONLY`, tasks 224 and 225) — SWAP must
   **not** consult `Weapons.ORDER` or ownership itself, or it becomes a second answer to "which guns
   are his". One tap equips the next one, by `Humanoid:EquipTool` (M2).
9. **The cluster is drawn only when there is something behind each button**, the rail's
   `buttonVisible` rule unchanged: a hunter sees FIRE and AIM, and sees SWAP only while carrying two
   or more; a beater sees BLOW. **No dead buttons.**
10. **Landscape is the first-class layout and is designed FIRST.** Phones play landscape. Every
    number in the design is stated for **800 × 400** and then for **400 × 800**, in that order.
11. **No new remote, and no new flag.** This path is not feel-critical in the
    `docs/design/feature-flags.md` sense — it is reachable only on a device Karen does not play on,
    and `SHOW_ON_DESKTOP` is the switch that makes it visible at all; a flag with a 21-day expiry
    would be ceremony with no playtest behind it. If the Architect disagrees, say so and say which
    flag.

## 2. The open decisions the design MUST take

1. **WHO OWNS THE BOTTOM-RIGHT, and where the cluster actually goes.** This is the hard one, and it
   is arithmetic rather than taste. At **800 × 400** the bottom-right is claimed four times over:
   the engine's **jump button**, the **ammo / horn chip** (§4.2: right 16, bottom 16, auto × 42), the
   **right column** (§4.3 rule 2: `RAIL_COLUMN_PX = 68`, nothing may enter it) and now a **FIRE**
   button, which source A's own sample places *20 px to the left of the jump button*. The Builder's
   arithmetic says **they do not all fit**: an 88 px FIRE placed clear of a ~110 px jump keep-out
   lands at x 582..670, and an auto-width ammo chip at right 16 reaches back past x 634. So the
   design must **state the placement and prove it clears everything**, and say explicitly whether
   the **ammo / horn chip moves up on touch** (the Builder's recommendation: its bottom becomes the
   cluster's top − 8, which also clears the pre-existing chip-inside-the-jump-button collision), or
   whether something else gives. If the chip moves, say **who writes it**: the recommendation is
   that `Hud` stays the one writer of the chip and asks `Touch` only *how tall the cluster is*.
2. **The keep-out rectangles are OURS and are a guess until the emulator runs.** Source A states the
   two zones and gives no numbers (note §6). Declare a `THUMBSTICK` and a `JUMP` keep-out as named
   constants with the reasoning for each number, require every button to clear both, and say in the
   design that they are **unverified against a live `TouchGui` until a person runs the Device
   Emulator** — the harness cannot drive it (checked: `studio_mcp.py` has no emulator command).
3. **The shape of the cluster**: one big FIRE plus a column, an arc, or a row of the small ones.
   The sizes are the note's targets (FIRE 88, AIM 64, SWAP 56, BLOW 72; every target ≥ 44 px on its
   shorter side, 8 px gaps, ≥ 20 px from the JUMP keep-out).
4. **`SHOW_ON_DESKTOP`.** The rail ships `true`, with three reasons in its header, the third being
   *"a `TextButton` is clickable with a real mouse, which is the only route to any live evidence at
   all"*. The same three reasons apply here, and against them: a FIRE button over the world is
   clutter on the one machine Karen plays on, and on a desktop the cluster would have to clear the
   ammo chip too. **Decide it and give the reason**, and whichever way it goes, both states must be
   reachable **by parameter** so a client spec drives both.
5. **What the rail does at 800 × 400, in `Rail`'s own arithmetic.** MEASURED ON PAPER (note §5):
   `Style.isPhone` is `viewportX < 700`, so 800 × 400 renders at the **desktop** step and
   `Rail.topFor(150, 136)` + `Rail.heightFor(4)` puts the rail's bottom at **510 on a 400 px tall
   screen** — RELOAD and AMMO are **off-screen today**. At the phone step it would be 438, still
   past 400. The note rules this **in scope** as an input defect (a button nobody can reach is not
   an input), to be fixed inside `Rail.rect` / `Rail.topFor` — pure, and asserted at both sizes. The
   design says how it clamps (shrink the gap, start higher, or two columns) and must keep
   `Rail.rect` **pure**.
6. **A real landscape layout for the whole top band and the right column is OUT of scope** and is
   the Designer's, not a Builder's. Say so in the design, with the numbers, so it is queued
   and not quietly half-done.
7. **The spec seam.** `Rail.press(id)` exists because *"a spec cannot fire `GuiButton.Activated`"*.
   Name the equivalent for the cluster, and name the **pure exported rectangle function** (the
   `Rail.rect` / `Objective.lineRect` shape) that the no-overlap spec measures, since
   `AbsolutePosition` can only answer for whatever size the Studio window happens to be.

## 3. What the design must contain

1. **Owners (rule 3).** Exactly one owner of the action cluster's frame and of every button in it;
   `Hud` stays the one creator of the frame and the one writer of the ammo chip; `Weapon.Input`
   stays the only firer of `FireRequest` / `ActionRequest` and the only keeper of the aim flag;
   `Hud.Rail` stays the one writer of its own four. Say who owns **equipping a Tool on the client** —
   it is new, and it must be exactly one module.
2. **Numbers, not adjectives**: every rectangle at 800 × 400 and at 400 × 800, every keep-out, every
   gap, and the intersection set the spec asserts is **empty**.
3. **The proof list**: which claims a client spec can carry (geometry, the one-path FIRE, the
   visibility rules, both `touchEnabled` states by parameter), and which **need a person's click** in
   the Device Emulator. Be explicit that a synthesised tap is not available to the harness.
4. **What is NOT built**, and why, in one list: no new remote, no character controller, no custom
   thumbstick, no hold-to-repeat fire, no interact button, no change to the engine's touch controls,
   and no new §4.3 rectangle beyond the cluster's own.

## 4. Scope, deliberately bundled — and the risk is accepted

Six surfaces (FIRE, AIM, SWAP, BLOW, the rail clamp and the interact verification) in one task is
more than this repo's usual one-thing-at-a-time, and the Learning Agent flagged it (L-012): if Karen
rejects one on look, the bundle reopens. **It is deliberate, and it is the Director's call.** A phone
that can move and look but cannot shoot is not a playable phone, so the cut that would make this
smaller would also make it worth nothing to the one person who judges it. The LOOK of the cluster is
expected back as a second, cheap task.
