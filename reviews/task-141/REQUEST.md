# Task 141 - the three rifle bugs, before Karen tests

Task: 141
Round: 1
Base: main (`f05d91b`, task 140 merged as PR #123)
Code commit: `790974ef285380078fa0c678ad7a74c0a38f951e`

```
[harness] PASS: 33/33 checks @ 790974ef285380078fa0c678ad7a74c0a38f951e (clean tree) scope=all
```

`test2` is N/A: nothing in this diff touches `TWO_PLAYER_PATHS` (`src/server/Match/`, `MatchBoot`,
`src/client/Match/`, `src/shared/Drive/`, `tests/client/Role.luau` or their specs). Weapon,
viewmodel, camera and hud changes need the one-player line only.

The Director found all three by playing the merged rifle in the Forest Test with `RIFLE` on. Every
one was real, and each had a different cause. **No Architect run:** no new owner and no new system --
the mask is the Hud's, which already owns everything drawn, and taking the gun out of the sight
picture is the viewmodel's, which is already the one writer of the drawn gun. The three owner rows
this moved are amended in `GAME_DESIGN.md`.

## The ten claims

1. **The rifle was drawn as boxes for ever, and the cause was one hardcoded folder name.**
   `Viewmodel`'s staleness signal is two numbers -- how many pieces the server has PUBLISHED and how
   many this client has DOWNLOADED -- and the second was counted by a function that looked only in
   `Gun.FOLDER_NAME`, the shotgun's. So for the rifle BOTH halves were constants: its own folder's
   child count had not moved since boot, and the ready count belonged to another weapon whose meshes
   had arrived long before. A rifle built while its four groups were still downloading had nothing
   left that could ever mark it stale. **Verify:** `readyMeshesIn(folderName)` in
   `src/client/Camera/Viewmodel.luau` and its three call sites -- the build uses `geometry.FOLDER_NAME`
   and the per-quarter-second tick uses `geometryNow().FOLDER_NAME`. MEASURED in the Forest Test:
   before, `mesh=2 box=7` at +0/+4/+8/+12 s (the two meshes were the gloves); after,
   `Bolt* Stock* Action* Scope*` -- six meshes and one box, the box being the drawn `Lens`.

2. **It is the MESHES, not the download, that were broken.** `meshReady` requests the fetch itself,
   so the four groups did come down; nobody asked again afterwards. **Verify:** the probe read
   `ViewmodelRifle: Scope=Success Action=Success Stock=Success Bolt=Success` in the same session that
   was drawing boxes.

3. **A scope view is a SIGHT PICTURE, and the gun is not in it.** Task 140 drew the model's own tube
   in front of the eye with the duplex painted over it; through a scope the eye is AT the ocular
   lens. `Viewmodel.hiddenByScope(state, optics)` is pure and public and the viewmodel unparents the
   clone -- it is **not destroyed**, so `Viewmodel.sight()` keeps answering off `model` and
   `Mode.aimOffset` solves the aimed pose from the same gun. **Verify:** `rifle_client.spec`, "has no
   gun in it, and the gun comes back when the eye leaves", drives both sides plus a weapon with no
   scope. MEASURED live: `fov=19.87 ... viewmodel in camera = false`, and `true` again on release.

4. **The mask is a `UIStroke` on a circle, and it is the one way to do this with no upload.** A
   `UICorner` of 0.5 scale makes a frame a circle and a stroke is drawn OUTSIDE that border, so a
   stroke thicker than the screen's diagonal fills the screen and leaves the circle alone. The
   alternative was an uploaded mask image, which needs Karen's OK and a moderation wait for a shape
   four lines of UI already make. **Verify:** `rifle_client.spec`, "is a circle of the scope's own
   degrees, and black to the corners", measures the eyepiece against `reticleDegToPx` and the LIVE
   viewport (within 2 px) and asserts the stroke is at least the viewport's diagonal. The gate's own
   note: `eyepiece 678 px of 793 viewport (asked 678.5), mask stroke 3619 of 3619 diagonal`.

5. **The sight picture is a THIRD predicate, and the duplex waits for it.**
   `Hud.scopeVisible(mode, optics, blend)` is pure and public; its answer blacks out the screen, so
   it may never be the same question as "does this gun have a reticle". **Verify:** `rifle_client.spec`
   drives eight cases of it, including `atBlend - 0.01` and `atBlend`, plus the two
   `Hud.reticleVisible` cases that prove the duplex is hidden during the raise and that a caller
   passing no blend still gets the old answer.

6. **It had to become once-a-frame, and that is the second half of the bug.** `Camera.Changed` fires
   on a MODE change, and at the instant `Third -> Aiming` arrives the blend is still 0 -- so a sight
   picture gated on the blend was computed exactly once, at the only moment it is false. MEASURED:
   the camera read `fov=19.87`, the gun had already taken itself out of the view, and the overlay was
   still hidden. `Hud.renderScope` is now on its own `RenderStepped`, the same reason the compass has
   one. **Verify:** `Hud.renderScope`'s three call sites, and that the connection is NOT inside
   `if compassFrame then` -- a scope that only worked in a world with a compass strip is the next
   place's bug. The per-frame cost is three reads and a boolean; both layout functions return
   immediately unless the fov, the viewport or the spec moved.

7. **The compass is HIDDEN, not covered.** A mask blacks out everything OUTSIDE the eyepiece, so no
   ZIndex can take a mark drawn in the middle of the screen out of the glass -- and the compass strip
   is the one Hud element that is. MEASURED and looked at: with the mask at ZIndex 7 the band and its
   labels vanished and the red DRIVE marker and three ticks went on floating in the sight picture.
   It puts back exactly what it hid (`compassHiddenByScope`), because the strip is invisible until
   `Compass.start` runs and a Hud that switched it on would draw an empty band in a world with no
   compass. **Verify:** the `compassHiddenByScope` branch in `Hud.renderScope`; the stack is now
   feed 1, score 5, compass 6-10, scope 11-13, report 15 (`Report.CONFIG.PANEL_Z_INDEX`, raised so
   that a panel the player deliberately opened is never masked).

8. **The hotbar's slot numbers are the ENGINE's, and the only lever is what its GUI sees first.**
   Roblox's Backpack GUI numbers a slot the first time it sees a Tool and then keeps it -- MEASURED:
   unequipping a weapon moved neither slot. Equipping the shotgun inside the grant's own frame put it
   in the CHARACTER before that GUI looked, so the rifle was the first thing in the bag and took slot
   1. `Weapon.grant` no longer equips; `Weapon.refreshArming` grants the whole loadout into the
   Backpack in `Weapons.ORDER` and equips the primary afterwards, by
   `Shotgun.CONFIG.AUTO_EQUIP_DELAY_SECONDS`. **Verify:** `weapon_equip.spec`, "puts the whole
   loadout in the BACKPACK before it puts anything in the hand" -- it takes every gun away, lets the
   owner's own sweep hand them back, and asserts every bag arrival precedes the first hand arrival
   and that the bag arrivals are in `Weapons.ORDER`. MEASURED live, reading the CoreGui hotbar
   itself: `1 Shotgun, 2 Rifle`.

9. **The equip is still narrow, and a sweep still cannot fight the player.** The delayed equip
   re-reads its guards when it fires rather than capturing them: a player who picked up the rifle,
   holstered, died or left in that half second is untouched, and so is a Tool that has gone.
   **Verify:** the `task.delay` body in `Weapon.refreshArming` -- `primary.Parent`, the recorded-tool
   identity and `Weapon.heldId(player)` are all checked again inside it.

10. **An adapter that names its fields is why the first build of this drew nothing.**
    `CameraBoot`'s optics adapter lists every field it hands the camera -- deliberately, so the
    camera is told what a VIEW needs and never a weapon's whole row. `eyepiece` added to
    `Rifle.CONFIG.scope` and not to that list reached nothing: the overlay never drew while the
    reticle did, because the Hud reads "no eyepiece" as "nothing to wait for". **Verify:** the
    adapter in `src/client/CameraBoot.client.luau` and `Camera.Optics`' new field. Reported here
    because it cost a measurement cycle and the next field will cost another.

## The frames, looked at (rule 5)

| frame | what it shows, wrong first |
|---|---|
| `t141-rifle-scoped.png` | The duplex reads as a thick CROSS in a ring rather than a classic duplex -- the 0.055-degree hair and the 0.22-degree posts both come out as solid black bars of similar weight at this size, and the posts stop well short of the eyepiece edge instead of running to it. It is otherwise exactly the sight picture asked for: black to all four corners, one round eyepiece with a dark lens rim, the magnified world (a birch at 19.87 degrees) inside it, the duplex dead centre and etched over the view, and **no gun, no hands, no compass, no readout** anywhere in the glass |
| `t141-rifle-carry.png` | The gun is very large in frame and sits low-right with the muzzle crossing the lower half -- it reads more like carrying the rifle across the chest than a low ready -- and the pale disc on the ocular bell is the drawn `Lens` part seen from behind, which looks like a grey plug rather than glass. Both are content-lane data. What the frame is for IS there: the REAL Rigby, after a real `2` keypress -- blued barrel, engraved action, figured walnut, the scope tube with its turret, the bolt handle, a gloved hand on it, `[*] .416 10` in the readout |
| `t141-shotgun-carry.png` | The readout is EMPTY bottom-right in this frame, where the hotbar frame taken moments earlier read `[*]* SLUG 24` -- the capture caught it before the server published the shotgun's state on the switch. Not chased. The gun is right: the double barrels, no scope, the glove on the fore-end, after a real `1` keypress |
| `t141-hotbar.png` | The slot numbers are faint (the engine's own hotbar: `1` sits under the selection highlight), but the two slots read **Shotgun** -- highlighted, so equipped -- and **Rifle**, in that order, which is the claim |

## Standing rule A, Forest Test, 85 s, with RIFLE ON (how the Director is testing it)

* the Tool is in the CHARACTER at 15 s and at 85 s (`gun in hand @15s=1 @85s=1`)
* **0 "Stack Begin" and 0 error lines** in the whole console
* **five waves released**, worst 1 boar sound at once over 10 s with 23 boars alive
* the changed features ran: that session is the one the hotbar, switch and sight-picture
  measurements above were taken in

## What I could not verify, and what I found that is not mine

* **The `1`/`2` keys cannot be driven through the harness, and now I have the engine's own refusal
  rather than a guess.** `VirtualInput` answers *"key is permanently bound to a CoreGUI core action.
  VirtualInput cannot process this key"* -- exactly what design 16.1 predicted. So the switch was
  driven with **real OS keystrokes** into the focused Studio window instead, and that needed a click
  into the viewport first: `SetForegroundWindow` focuses the Studio WINDOW while a dock can still
  hold the caret, and without the click the keys reached nothing. Both directions then worked
  repeatedly: `held=Shotgun drawnMeshes=4` -> `2` -> `held=Rifle drawnMeshes=6` -> `1` -> back.
  **It is still not in `tests/client/input_scenarios.txt`**, because the harness cannot send it.
* **A respawn can leave a player with no shotgun, and it is NOT this task's.** MEASURED twice in a
  long-running session, on the real death path (`Humanoid.Health = 0`) as well as `LoadCharacter`:
  afterwards the Backpack held only the Rifle and nothing was in the hand, 14 s later. I checked
  whether I had caused it by reverting `src/server/Weapon/init.luau` to its merged state and
  repeating the test -- **identical**, so it is pre-existing. On a FRESH session the same death
  re-armed correctly, so it is a long-session state rather than a clean reproduction. Queued for the
  Director; it wants its own task, because guessing at the arming sweep is how this repo has
  produced gunless players before.
* **The "wears a mesh for every downloaded piece" case is vacuous in DEV.** Its own note reads
  `shotgun wears 0 of 0 downloaded piece(s)` -- DEV has no ready templates in that folder, so the
  assertion passes trivially there. The rule is real and weapon-agnostic, but the evidence for bug 1
  is the Forest Test measurement in claim 1, not that case.
* **`AUTO_EQUIP_DELAY_SECONDS` is half a second of empty hands at a spawn.** Measured as enough for
  the engine's GUI to enumerate, and far inside the time a player takes to look at anything -- but it
  is a timing number against another system's initialisation, so if the hotbar ever reads `1 Rifle`
  again this is the first dial to turn.
* **The duplex's posts are short and read as a cross.** `postArmDeg` 1.50 against an eyepiece of 17
  degrees; a real duplex's thick posts run to the field edge. Content-lane data in
  `Rifle.CONFIG.scope.reticle`, for the Director to tune -- not changed here, because the Director
  asked for "a clean duplex/crosshair reticle" and this is clean and centred.
* **`maxBoars` stacks appeared in the long-running session's console** (`Boar:3612`, from
  `ForestTest.releaseLine`). Not in the 85-second rule-A run, and not touched by this task.
