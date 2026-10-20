# Mobile controls: the touch INPUT for a drive and the lobby (Task 220)

2026-10-20. Builder. For `docs/design/mobile-controls.md` (Architect) and the code that follows it.

Karen's v1 plan, 2026-10-11, confirmed *"continue"* 2026-10-19: *"world: ... MOBILE controls"*.
Most Roblox players are on phones.

## 1. What the system must do

A phone player must be able to do everything a keyboard-and-mouse player does in a drive and in the
lobby. The HUD half is already built -- the Designer's design system has a phone step (section 4.2)
and `Hud.Rail` (task 165) is a column of real touch buttons. **The INPUT is what is missing.** Today
a touch player gets, from the engine, a thumbstick and a camera drag and a jump button, and from us
four rail buttons (MAP, REPORT, RELOAD, AMMO). There is **no way to fire, no way to aim, no way to
switch weapon except the stock hotbar, and no way to blow a horn except a bare screen tap.**

What must exist, as a tappable target, by the end of this system:

| Desktop | Touch today | Must become |
|---|---|---|
| MouseButton1 -- fire | nothing of ours | a FIRE button |
| MouseButton2 hold -- aim | nothing | an AIM button |
| `R` -- reload | the rail's RELOAD | unchanged, it is already a button |
| `X` -- other shell | the rail's AMMO | unchanged, it is already a button |
| the hotbar / `1` `2` -- shotgun or rifle | the stock Backpack bar | a SWAP button, one tap |
| a click with the horn out -- blow | a bare screen tap, undiscoverable | a BLOW button |
| `E` at the shopkeeper | the `ProximityPrompt`'s own tappable circle | **verify**, do not rebuild |

Numeric targets: every target **>= 44 px** on its shorter side (source B); no target may intersect
any rectangle in the design system's section 4.3 no-overlap set, **or** either of the engine's two
control zones (source A); the layout holds at **800 x 400** (landscape, which is how phones play)
and at **400 x 800**; a touch FIRE reaches the server through the **same** `FireRequest` a click
does, with no second path (CLAUDE.md rule 3).

## 2. Sources

| # | Source | Licence / status | Good | Bad |
|---|---|---|---|---|
| A | **Roblox, "Position and size UI objects"** -- https://create.roblox.com/docs/ui/position-and-size | Roblox Creator Docs, CC BY 4.0, current | It is the only source that states the two zones as a LAYOUT constraint and gives the reach rule a number. Verbatim: *"On mobile devices, the default controls occupy a portion of the bottom-left and bottom-right corners of the screen."* -- *"Most mobile players use two thumbs -- one on the virtual thumbstick and one on the jump button."* -- *"A button placed 40% below the screen's top edge is reachable on a phone but almost unreachable on a tablet."* -- *"A reliable approach on both phones and tablets is **relative** positioning of custom buttons near frequently-used controls like the default jump button, placing them within easy reach."* Its own code sample places a custom button **20 px to the left of the jump button** | It gives no pixel size for the jump button or the thumbstick, so the keep-out rectangles below are OURS and have to be measured, not quoted |
| B | **WCAG 2.2, SC 2.5.5 Target Size (Enhanced), Level AAA** -- https://www.w3.org/TR/WCAG22/#target-size-enhanced | W3C Document Licence, W3C Recommendation 2023 (errata 2024), current | Gives the target floor as a number rather than a feel: *"The target size is at least 44 by 44 [CSS pixels]"*. It is the same document the design system already cites for its contrast floor (its source B), so the look and the reach are measured against one standard | A CSS pixel is not a Roblox offset pixel on a high-DPI phone. Treated as a floor in `Rail`'s own units, which is what task 165 already did at 48 |
| C | **Roblox, `ContextActionService`** -- https://create.roblox.com/docs/reference/engine/classes/ContextActionService | Roblox Creator Docs, CC BY 4.0, current | The engine will MAKE the touch buttons for us: *"For touch devices, a button is created on-screen automatically via the 3rd parameter"*, with `SetImage` / `SetTitle` / `SetPosition` and `GetButton` to adjust them. It is the borrow-first candidate, and it is already half-wired: `Weapon.Input` calls `BindAction` for all four weapon actions and passes `false` | **Not adopted, two reasons.** (1) Its buttons cannot wear the design system: they are the engine's `ContextActionGui` circles, and section 4.3's no-overlap set is asserted by intersection against OUR rectangles -- a rectangle the engine owns and does not publish cannot be asserted. (2) `GetButton` returns *"nothing"* on a non-touch device, so there is no desktop path to any live evidence at all -- the exact trap task 165 named for the map's old touch-only button, which *"never once appeared in her sessions"* |
| D | **Roblox, "Disable default UI"** -- https://create.roblox.com/docs/players/disable-ui | Roblox Creator Docs, CC BY 4.0, current | Names what the engine gives a touch player and how it would be taken away: *"Devices with touch capabilities include a virtual thumbstick and a jump button by default. If desired, you can hide these elements by setting `GuiService.TouchControlsEnabled` to `false` in a client-side script."* It also says the Backpack bar *"Does not appear if there are no Tools in the backpack"* -- so the stock hotbar is a real, if poor, touch weapon switch today | We do **not** hide them: the thumbstick and the drag are the movement and the camera, and this repo has no character controller of its own. So they are a constraint, not a choice |
| E | **Ours, current: `Hud.Rail` (task 165) and the Designer's design system 4.2 / 4.3** -- `src/client/Hud/Rail.luau`, `<runs-dir>/design/design-system.md` | ours | The pattern this system copies rather than invents: ONE module owning one frame, every button a *"second door onto a function that already exists"*, `GuiButton.Activated` for *"a click AND a tap, which is why the rail needs no touch branch at all"*, a named `Rail.press(id)` seam because *"a spec cannot fire `GuiButton.Activated`"*, PURE exported rectangle functions (`Rail.rect`) because *"the existing overlap case measures `AbsolutePosition` at whatever size the Studio window happens to be"*, and `SHOW_ON_DESKTOP` so the feature is reachable by the one person who judges it | Sections 4.2 and 4.3 are drawn for **400 x 800 only**. Neither says one word about landscape, and section 5 below is what that costs |

## 3. What could not be fetched, and was measured instead

Two engine facts this design rests on do not render to a fetcher. Both documentation pages come back
as navigation plus code samples with no property text -- the failure mode this repo already recorded
for the Blender manual (`docs/research/2026-09-26-asset-prep.md`: *"renders to a fetcher as
navigation, twice, so ... was MEASURED instead"*). So they are measured in a live session and the
measurement, not a remembered sentence, is what the design may rely on:

1. **`Tool:Activate()` from a LocalScript fires the server's `Tool.Activated`.** This is the whole of
   the BLOW button: `Weapon.Horn.grant` connects `tool.Activated` **on the server** and that
   connection is the one accepted blast path (`src/server/Weapon/Horn.luau`, `Horn.blowTool`). If
   `Activate()` replicates, a BLOW button needs **no new remote** and is a second door onto the
   existing one -- which is exactly what `Rail`'s header refused to guess at in task 165: *"A blast
   is `Weapon.Horn.blowTool`, which is the SERVER's; there is no client function to call, so a horn
   button would need a new remote -- refused for this task"*.
2. **`ProximityPrompt.ClickablePrompt` defaults to true, and the prompt is tappable on touch.** The
   shopkeeper's prompt (`src/server/Lobby/Build.luau`, `shopPrompt`) never sets the property. If the
   default is true, the lobby's interact needs **nothing built**, only verified.

Measurements are recorded in `reviews/task-220/REQUEST.md` with the probe that produced them. **No
line of the design may depend on either fact until its measurement is in that file.**

## 4. The pattern adopted, and why

**Borrowed from E (ours), not built.** A new sibling module `Hud.Touch` beside `Hud.Rail`, the one
writer of one frame holding the action cluster, every button a second door onto a function that
already exists, `GuiButton.Activated` as the one event, a pure exported `Touch.rect`, a named
`Touch.press(id)` spec seam, and a `SHOW_ON_DESKTOP` switch. Nothing in it is new except the
buttons.

**A sibling and not an extension of the rail**, for the reason source A gives: the rail is a column
on the **right edge under the minimap**, which is the top-right of the screen, and *"A button placed
40% below the screen's top edge is reachable on a phone but almost unreachable on a tablet"*. A
trigger belongs under the thumb, next to the jump button; MAP and REPORT do not. Two groups, two
reach budgets, two owners -- and the rail's own header already quotes Roblox's curriculum on
grouping by category.

**One input path, enforced by making the KEY the second caller.** `Input.reload` and
`Input.selectAmmo` are already public functions that the key handler and the rail both call
(task 165: *"RELOAD AND THE AMMO SWITCH AS PUBLIC FUNCTIONS, SO A BUTTON AND A KEY RUN ONE
IMPLEMENTATION"*). FIRE and AIM get the same treatment: `Input.fire()` and `Input.setAim(on)` become
the implementations, and `onFire` / `onAim` become two-line handlers that call them -- so there is
one firer of `FireRequest`, one keeper of the aim flag, and the touch door cannot drift from the
mouse door because there is nothing for it to drift from. The hold (`Input.isHeld`) is checked
inside those functions, where task 165 already moved it, so a tap through an open panel is refused
once for both doors.

**AIM is a TOGGLE on touch and stays a HOLD on the mouse.** Not a preference: on a phone the right
thumb IS the camera (source A, source D -- the drag is the only look control), so a held AIM would
pin the one finger that aims and leave none for the trigger. A toggle costs one tap and frees the
thumb. `Input.setAim(on)` takes the value, so the mouse's Begin/End and the button's toggle are the
same function called with different arguments.

**Rejected: the engine's own touch buttons** (source C), for the two reasons in its row. Rejected:
hiding the engine's controls and writing our own thumbstick (source D) -- this repo owns no
character controller and movement is not this task.

## 5. What landscape costs, measured on paper

Phones play landscape. Section 4.2 is drawn for 400 x 800 and `Style.isPhone(viewportX)` is
`viewportX < 700` (`src/client/Hud/Style.luau`), so **at 800 x 400 the HUD renders at the DESKTOP
step**: compass at y 98, minimap 150 px at y 136, and `Rail.topFor(150, 136)` = 294 with
`Rail.heightFor(4)` = 216, so the rail's bottom is **510 on a 400 px tall screen** -- RELOAD and
AMMO are off the bottom edge. Keyed on the shorter side instead it is no better: the phone step puts
the rail at y 222 + 216 = **438**, still past 400.

So a landscape phone has a right column that does not fit, today, before this task adds anything.
Two consequences, and they are deliberately different sizes:

- **In scope, because it is an input defect:** the rail is clamped inside the viewport, in
  `Rail.rect` / `Rail.topFor`'s own arithmetic, so no button of it is ever off-screen. Pure, and
  asserted at both sizes.
- **Out of scope, and queued:** a real landscape layout for the whole top band and the right column
  is the Designer's, not a Builder's, and it is a bigger thing than the buttons this task is for.
  It is reported with the numbers above rather than quietly half-done.

## 6. The keep-outs are ours to measure

Source A states the two zones and gives no rectangle for either. So the design declares them as OUR
constants -- a `THUMBSTICK` keep-out at the bottom-left and a `JUMP` keep-out at the bottom-right --
every new button is asserted clear of both, and the constants are **checked against a live emulated
session's `TouchGui` before they are believed**. A keep-out nobody measured is a guess with a
comment on it.

They also already collide with section 4.3 as written: the ammo / horn chip is `right 16, bottom 16`,
which is inside any plausible JUMP rectangle, and the toast feed and hit card are `left 16,
bottom 16`, inside the thumbstick's. Those two are **pre-existing** and are reported with numbers,
not fixed here, for the same reason as section 5.

## 7. Numeric targets

| What | Target |
|---|---|
| Every touch target, shorter side | >= 44 px (source B); FIRE 88, AIM 64, SWAP 56, BLOW 72 |
| Gap between two targets | >= 8 px (the rail's own `GAP`) |
| Cluster's distance from the JUMP keep-out | >= 20 px (source A's own sample) |
| Viewports the layout must hold at | 800 x 400 and 400 x 800 |
| Intersections with section 4.3's set or either keep-out | 0, asserted by a spec |
| Paths from a touch FIRE to the server | exactly 1, and it is `FireRequest` |
| New remotes | 0 |
