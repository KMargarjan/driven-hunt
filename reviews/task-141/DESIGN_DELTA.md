# Task 141 — what `docs/design/rifle.md` no longer describes

The Builder never edits `docs/design/` (rule 3), so the two sections task 141 moved are recorded
here, in the shape `reviews/task-24/DESIGN_DELTA.md` and `reviews/task-32/DESIGN_DELTA.md` already
have. **The Director asked for every one of these changes** after playing the merged task 140 in the
Forest Test; none of them is the Builder re-opening a design decision.

## 1. §7.2 — the reticle is no longer written on `Camera.Changed`

**The design says:** *"`render(Weapon, CameraSystem)` sets `reticle.Visible =
Hud.reticleVisible(CameraSystem.getMode(), CameraSystem.scope())` ... It is driven by the
`Camera.Changed` connection the Hud already has, which fires on every mode transition, and
`Third → Aiming` is the only transition the reticle cares about."*

**The code now:** `Hud.renderScope(CameraSystem)` writes the whole sight picture — the mask and the
duplex — from its own `RenderStepped`, and `render` still calls it so a mode change between two
frames lands on that frame.

**Why the design could not stay:** `Camera.Changed` fires on a MODE change, and at the instant
`Third → Aiming` arrives **the blend is still 0**. The sight picture has to wait for the blend (the
Director: *"the overlay snaps in when blend ≈ 1"*), so a sight picture computed only on that signal
is computed exactly once, at the only moment it is false. MEASURED in the Forest Test: the camera
read `fov=19.87` and the gun had already taken itself out of the view while the overlay was still
hidden. This is the same reason the compass has a `RenderStepped` of its own — a thing that tracks
the VIEW cannot be told about it by an event about the MODE.

## 2. §7.2 / §13.2 case 3 — `reticleVisible` gained a blend, and a third predicate exists

**The design says:** `Hud.reticleVisible(mode, optics)`, and §13.2 case 3 asserts *"`Visible` is
false in the hip view and true while `Aiming`"*.

**The code now:** `Hud.reticleVisible(mode, optics, blend?)` — the third argument is optional and a
caller that passes none gets the design's answer, so nothing written against the old signature
changed meaning. Beside it is a **third predicate**, `Hud.scopeVisible(mode, optics, blend?)`, which
answers "is the eye at the glass" and is what blacks out the screen. The duplex waits for it,
because a reticle drawn over the gun half way up the swing is a mark floating in the world — which
is what the Director's frames of task 140 show.

The design's own rule that produced this is unchanged and is why they are two predicates and not
one: *"two predicates, two questions"* (§1.2, and the Hud's own header).

## 3. §7 gained an `eyepiece` block, and the viewmodel reads it too

`Rifle.CONFIG.scope.eyepiece = { atBlend, diameterDeg, rimThickDeg, rimColor, maskColor }`, in
DEGREES like everything else in that table, so it stays true at any screen size and grows with the
magnification. `CameraBoot`'s optics adapter hands it on and `Camera.Optics` carries it.

**Two owners read the same number, deliberately:** the Hud masks the screen outside the circle, and
`Camera.Viewmodel` takes the gun out of the picture (`Viewmodel.hiddenByScope`). That is not a second
writer of anything — each owns what it already owned — and sharing `atBlend` is what keeps them from
disagreeing by more than the one frame two render-step bindings can.

## 4. §5 — the auto-equip is no longer inside `Weapon.grant`

**The design says** a spawn is *"the shotgun equipped, the rifle sitting in slot 2 of the hotbar"*.
That is still the behaviour and now it is actually true; it was not.

**Why:** the hotbar's slot numbers are the ENGINE's. Its Backpack GUI numbers a slot the first time
it sees a Tool and then keeps it (MEASURED: unequipping a weapon moved neither slot), so equipping
the shotgun inside the grant's own frame hid it from that GUI and the rifle took slot 1.
`Weapon.refreshArming` now grants the whole loadout into the Backpack in `Weapons.ORDER` and equips
the primary afterwards, by `Weapon.equipDelayFor(wanted)` — `AUTO_EQUIP_DELAY_SECONDS` for two
Tools, **zero for one**, so the shipped build's spawn is bit-for-bit what the design promises.

`Weapon.refreshArming(player, loadout?)` also takes the loadout as an optional parameter now, for
the reason CLAUDE.md gives for anything behind a flag: both worlds must be reachable without it, or
the order this function exists to get right can only be tested in whichever world the gate runs in.
