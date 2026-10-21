# Task 220 -- BRIEF for the Architect: `docs/design/mobile-controls.md`

The Builder, carrying the Director. 2026-10-21. Read this first; it overrides anything older in
`docs/`, `TASKS.md` or an earlier design (`docs/ARCHITECT_PROMPT.md`).

Research note, already committed on this branch and to be read with this brief:
`docs/research/2026-10-20-mobile-controls.md` (sources A-E, the numeric targets, what could not be
fetched and must be measured).

Karen's v1 plan, 2026-10-11, confirmed *"continue"* 2026-10-19: *"world: ... MOBILE controls"*.
Most Roblox players are on phones. **The HUD half is built** (the design system's §4.2 phone step and
`Hud.Rail`'s four buttons, task 165). **The INPUT is what is missing.**

---

## 1. Decisions already taken. The design states them; it does not re-open them.

**D1. The engine's own controls stay.** The default touch thumbstick, the camera drag and the jump
button are the movement and the look, and this repo owns no character controller.
`GuiService.TouchControlsEnabled` is never written. They are therefore a **layout constraint**, not
a choice (research note, source D).

**D2. Four new buttons, and only four: FIRE, AIM, SWAP, BLOW.** They are what a keyboard-and-mouse
player has and a thumb does not. Explicitly NOT built again:
- RELOAD (`R`) and AMMO (`X`) -- `Hud.Rail` already draws both as real touch buttons.
- MAP (`M`) and REPORT (`TAB`) -- the same.
- **`E` for the seller / interact -- NOTHING IS BUILT.** The shopkeeper's `ProximityPrompt`
  (`src/server/Lobby/Build.luau`, `shopPrompt`) is already tappable: `ClickablePrompt` defaults to
  true and that property is never set. The design's job here is to say **VERIFY, do not rebuild**,
  and to name the measurement (below). If the measurement says otherwise, the design says what the
  one-line fix is -- it does not design a second prompt.

**D3. A SIBLING OWNER, not an extension of the rail.** A new module `Hud.Touch` beside
`Hud.Rail`, the one writer of one frame holding the action cluster. **`Hud.Rail` stays the one owner
of its own four buttons and nothing about them moves.** The reason is reach, and it is quoted:
the rail is a column on the right edge **under the minimap**, and source A says *"A button placed
40% below the screen's top edge is reachable on a phone but almost unreachable on a tablet"*, and
*"A reliable approach ... is relative positioning of custom buttons near frequently-used controls
like the default jump button"*. A trigger belongs under the thumb at the bottom; MAP and REPORT do
not. Two groups, two reach budgets, two owners.

`Hud.Touch` copies `Hud.Rail`'s shape verbatim, because it is this repo's own proven pattern
(research note §4): one module filling a frame `Hud.build` created, every button a second door onto
a function that already exists, `GuiButton.Activated` as the one event (a click AND a tap, so no
touch branch), **pure exported rect functions**, a named `Touch.press(id)` spec seam, and a
`SHOW_ON_DESKTOP` switch -- for the reason task 165 recorded: a touch-only feature is one Karen can
never see, which is exactly what happened to the map's old touch-only button.

**D4. ONE INPUT PATH, and the KEY becomes the second caller.** A touch FIRE must reach the server
through **the same `FireRequest` the mouse fires**, with no second path (CLAUDE.md rule 3).
The mechanism is already in this repo and is extended, not invented: task 165 made `Input.reload`
and `Input.selectAmmo` public implementations that the key handler and the rail both call.
`Weapon.Input.fire()` and `Weapon.Input.setAim(on)` get the same treatment, and `onFire` / `onAim`
become two-line `ContextActionService` handlers that call them.
- `Weapon.Input` stays **the only binder of `DrivenHunt.Weapon.*` and the only firer of
  `FireRequest` / `ActionRequest`**. `Hud.Touch` holds no rule, fires no remote and reads no camera.
- The `Input.isHeld()` tagged hold is checked **inside** those functions, where task 165 put it, so
  a tap through an open panel is refused once for both doors.
- **New remotes: 0.** The design must say so as a target.

**D5. AIM is a TOGGLE on touch and stays a HOLD on the mouse.** Not a preference. On a phone the
right thumb IS the camera (sources A and D: the drag is the only look control), so a held AIM pins
the one finger that aims and leaves none for the trigger. `Input.setAim(on)` takes the value, so the
mouse's Begin/End and the button's toggle are one function called with different arguments, and
`Input` stays the one keeper of the aim flag and the one firer of `AimChanged`.

**D6. SWAP covers all four guns AND the horn, and is owned-only by construction.** Since the first
dispatch the lever rifle (224) and the semi-auto shotgun (225) merged, so a player can carry more
than two Tools. SWAP equips **the next of the player's own Tools** in a stable order, cycling.
- Which Tools count is asked through **`HeldTool.kindOf`** -- the existing shared fact, the one file
  in the repo that knows both what a gun is and what the horn is, and the reason it exists is that
  *"or it is a horn"* in two places is how two correct pieces of code start disagreeing. The design
  must not add a second answer to "is this one of our Tools".
- **Owned-only needs no ownership check here and must not add one.** A player carries only what the
  server granted (`Shop.loadoutFrom` / `Weapons.loadoutFor` already apply `OWNED_ONLY`, task 224's
  rule), so cycling over the Tools that are actually in the Backpack and character cannot offer a
  gun the player has not bought. The design states this as the reason there is no second gate, and
  SWAP is not drawn at all when fewer than two of our Tools are carried (`Rail.buttonVisible`'s rule:
  no dead buttons).
- The equip itself is `Humanoid:EquipTool` on the local character, which is **the same door the
  engine's own hotbar uses** and the same call the server's `Hardware.equip` / `Horn.equip` make.
  The Architect rules on where that call may live and says so in the owner table.

**D7. BLOW needs no new remote, and the reason must be MEASURED before the design leans on it.**
`Weapon.Horn.grant` connects **`tool.Activated` on the server**, and that connection is the one
accepted blast path. So a BLOW button is `tool:Activate()` on the held horn -- a second door onto the
existing one. This is the fact task 165 refused to guess at (*"there is no client function to call,
so a horn button would need a new remote -- refused for this task"*). It is measured, not remembered
(below). The server's cooldown in `Horn.blow` is unchanged and is still the answer to a forged click.

**D8. LANDSCAPE FIRST, and said so.** Phones play landscape. The cluster is laid out **from the
bottom-right corner inward**, so it is correct at **800 x 400** and at **400 x 800** by construction
rather than by a second layout. Both viewports are asserted.

**D9. The rail is clamped inside the viewport, and that IS in scope.** Measured on paper in the
research note §5: `Style.isPhone` is `viewportX < 700`, so at 800 x 400 the HUD renders at the
DESKTOP step and the rail's bottom lands at **510 on a 400 px screen** -- RELOAD and AMMO are off
the bottom edge, today, before this task adds anything. Keyed on the shorter side it is 438, still
past 400. A landscape phone therefore **cannot reload at all**, which contradicts the whole point of
this task, so the clamp is in scope: pure arithmetic inside `Rail`'s own rect functions, asserted at
both viewports. Nothing else about the rail moves.

**D10. What is OUT of scope, and is reported with numbers rather than half-done.**
- A real landscape layout for the top band and the right column. That is the Designer's: §4.2 and
  §4.3 are drawn for 400 x 800 only and neither says one word about landscape.
- The two **pre-existing** §4.3 collisions with the engine's zones: the ammo / horn chip at
  `right 16, bottom 16` is inside any plausible JUMP rectangle, and the toast feed and hit card at
  `left 16, bottom 16` are inside the thumbstick's. Both are older than this task.

## 2. What the design must contain

1. **An owner table** in this repo's usual form: one writer per thing. At minimum -- the action
   cluster frame and its buttons (`Hud.Touch`); the rail and its buttons (`Hud.Rail`, unchanged);
   the frames' existence, position and `ZIndex` (`Hud.build`); the `DrivenHunt.Weapon.*` bindings,
   `FireRequest`, `ActionRequest` and the aim flag (`Weapon.Input`); the blast (`Weapon.Horn`,
   server); which Tool is equipped (name the owner -- D6); "is this one of our Tools"
   (`HeldTool.kindOf`). Say explicitly that `Hud.Touch` writes nothing outside its own frame.
2. **The layout, as pure functions over `(viewport, ...)`**, in the `Rail.rect` /
   `Objective.lineRect` idiom and for the reason those exist: *"the existing overlap case measures
   `AbsolutePosition` at whatever size the Studio window happens to be"*, and
   `tests/client/hud_clarity.spec.luau` already records that **no tool here can resize a Studio
   viewport**. Every rectangle must be computable at any `(x, y)` without a screen.
3. **The two keep-out rectangles as OUR constants** -- `THUMBSTICK` bottom-left, `JUMP`
   bottom-right. Source A states the two zones and gives no pixels, so these are ours. The design
   says they are to be **checked against a live `TouchGui`** and that a keep-out nobody measured is
   reported as a guess, not asserted as a fact.
4. **§4.3 extended by exactly one row** -- the bottom-right action cluster -- with the no-overlap
   set it must be asserted against, and the intersection assertion named as the spec's job.
5. **The numeric targets**, from the research note §7: every target >= 44 px on its shorter side
   (source B); >= 8 px between targets; >= 20 px clear of the JUMP keep-out (source A's own sample
   places a custom button 20 px from it); 0 intersections with §4.3's set or either keep-out; exactly
   1 path from a touch FIRE to the server, and it is `FireRequest`; 0 new remotes. Sizes proposed in
   the note: FIRE 88, AIM 64, SWAP 56, BLOW 72 -- the design may change them and says why.
6. **Which button exists when**, as a pure predicate per button, in `Rail.buttonVisible`'s shape:
   FIRE and AIM need a weapon in hand; BLOW needs the horn in hand; SWAP needs two or more of our
   Tools carried. No dead buttons.
7. **What a spec can and cannot prove**, said plainly, because task 165 already hit this: a spec
   cannot fire `GuiButton.Activated` and the harness cannot synthesise a tap, so `Touch.press(id)`
   is the seam and what it proves is the **ACTION**, not the touch. Name that limit; do not paper
   over it.
8. **The three measurements** this design may not rely on until they are in
   `reviews/task-220/REQUEST.md` with the probe that produced them:
   (a) `tool:Activate()` from a LocalScript fires the server's `Tool.Activated` (D7);
   (b) `ProximityPrompt.ClickablePrompt` is true on the shopkeeper's prompt as built (D2);
   (c) the two keep-out rectangles against a live `TouchGui` (item 3).
   For each: what the design does if the measurement comes back the other way.

## 3. Open decisions the Architect MUST close (they are not closed above)

1. **Where `Humanoid:EquipTool` may be called from** for SWAP, and who is named its owner (D6).
   A client-side equip is what the engine's hotbar already does; say whether that makes `Hud.Touch`
   a permitted caller, or whether it must go through a function on a weapon-side module that
   `Hud.Touch` calls -- and if the latter, which module.
2. **Whether FIRE repeats while held** or is one shot per tap. The shotgun and the lever are
   manually cycled; the semi-auto (225) is not. Decide, and say which existing rule decides it.
3. **The cluster's exact geometry** relative to the JUMP keep-out: the four rectangles at
   800 x 400 and at 400 x 800, as numbers.
4. **Whether the clamp of D9 lives in `Rail.topFor`, `Rail.rect`, or a new pure function**, given
   that `hud_clarity.spec` already asserts the band through `Rail.rect`.
5. **Whether `Hud.Touch` needs its own `setSuppressed` / `setCovered`**, or whether the cluster
   follows the rail's two flags. A sight picture is up and the shop is open are both real states
   (`Rail.setSuppressed`, `Rail.setCovered`), and a FIRE button inside a scope eyepiece is the
   picture `Hud.renderScope` exists to prevent.

## 4. Constraints the design may not break

- CLAUDE.md rule 3, one owner per system; rule 2, borrow before building.
- `Weapon.Input` remains the only binder of `DrivenHunt.Weapon.*` and the only firer of its remotes.
- `Hud.Touch` reads no camera, writes no `CameraType` / `MouseBehavior`, and owns no state but its
  own nodes.
- Nothing may be `.rbxm`; no new remotes; no test-only hook in production code beyond the
  `Touch.press` seam this repo already uses.
- `tests/client/` is where the client specs go, and a new spec file must be named in a `SCOPE_SPECS`
  scope in `tools/studio_mcp.py` or CI goes red (standing rule G).
