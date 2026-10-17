# Task 197 -- the pad menu in the house style, a clear "leaving" message, and the truck starts

Task: 197
Round: 1
Base: `4644b3e` (main)
Code commit: `b8c3c05`

Harness (clean tree, one player, FULL scope -- the Director's own run at the branch head):

```
[harness] PASS: 33/33 checks @ b8c3c0561a5e3d72345cf681f9d91b01ba8e3135 (clean tree) scope=all
```

**`Round: 1` AND NOT `Round: 2`, deliberately.** The Director's dispatch for this run says round 2,
and `tools/agents.py` would refuse that: `expected = 1 if prev_rnd is None or prev_verdict == "PASS"`,
and this task's committed `RESULT.md` trailer reads *"(round 1)"* with `PASS` on line 1. A PASS
resets the count, so a second review of the same task after a PASS is a fresh round 1. Flagged to
the Director in the report rather than worked around.

`b8c3c05` is the last commit that changed `src/` or `tests/` and is the HEAD of the branch at the
time of this request; the only commit after it will be this file. The harness line above is the
Director's `scope=all` run, so it is full evidence for the PR to `main` as well as for this round.

Two players: **N/A, checked rather than assumed.** `git diff --name-only origin/main...HEAD` lists
21 files and not one of them is in `TWO_PLAYER_PATHS` (`tools/agents.py`): the changed code is
`src/client/Camera/`, `src/client/Hud/`, `src/server/Lobby/` and `src/shared/Lobby/` plus five
specs, and the two client specs touched (`pad_panel`, `hud_clarity`) are not on that list.
**`tools/agents.py` itself is not in the diff**, so the list was not edited to change what the gate
asks for.

---

## What changed

**KAREN, 2026-10-15 ~17:40, verbatim (transcribed from the Director's dispatch):**

> *"same with entering in game menu has to be nicer and cleaner / and we need clear message that
> game is loading once clicked 1/1 or other now is delay / also could be car started sound light on
> something like that indicating loading ect"*

Four visible things in one moment -- from stepping onto a truck pad to standing on a stand.
**They are independent and Karen can accept or reject each on its own.**

1. **The size dialog** (`Hud.PadPanel`) redrawn in the **shop's house style**, read out of
   `Hud.ShopPanel` rather than copied.
2. **A loading banner** for the three pad states after the pick, with the countdown and a bar.
3. **That pad's truck starts** -- engine, headlights, exhaust -- and the other three stay dark.
4. **The view turns to face that truck**, because it is behind her, and the top hint line stands
   down while either panel is up.

(2), (3) and the banner's whole visibility hang on **one pure predicate with two readers**:
`Lobby.padLoading(state)` is true for `filling`, `countdown` and `leaving`. The owner mirrors that
pad's state word onto each member as the `Player` attribute `DHPadMine` and hands the same answer to
`Build.setTruck`, so the banner and the engine are one fact said twice.

Research note: `docs/research/2026-10-17-the-pad-menu-and-the-truck.md`.

---

## Claims, and how to verify each

**1. The delay was measured on the player's own path, and it is not a load.**
Press to the drive is **5.30 s measured live**, of which 5.0 is `CONFIG.COUNTDOWN_SECONDS` -- a
designed wait in which a second player can still step on. So the fix is feedback, not speed; the one
thing shortened is the tenth of a second the lights used to wait for the next scan, because
`Lobby.onPadRequest` calls `Build.setTruck` on the press beside the `Build.setPad` it already called.
*Verify:* the `setTruck` call in `Lobby.onPadRequest` (`src/server/Lobby/init.luau`); the note's
section 2 and section 6; `CONFIG.COUNTDOWN_SECONDS` and `PADS.FILL_TIMEOUT_SECONDS` unchanged in
`src/shared/Lobby/init.luau`.

**2. The truck is RECONCILED on the owner's scan, not fired on the pick.**
`Build.setTruck(index, Data.padLoading(pad.state))` is asked every scan in `stepPads` beside
`Build.setPad` and is edge-triggered inside, so a running truck costs one comparison a scan per bay.
That is why no truck is ever left idling: the four ways a party can end are driven one after another.
*Verify:* `stepPads` in `src/server/Lobby/init.luau`; `Build.setTruck` in `src/server/Lobby/Build.luau`;
`tests/server/lobby_live.spec.luau`, *"turns the truck off again whichever way the party ends"*
(departure, stepping off during the countdown, a refused `enrol`) and the twenty-scan edge claim in
*"starts THAT pad's truck when the size is picked"* (`stats.truckWrites` does not move).

**3. The banner says nothing the server did not tell it.**
`DHPadMine` is written only by `ServerScriptService.Lobby`, level-triggered with edge writes
(`setPadMine`), cleared the moment `world.inDrive` is true and again in `Lobby.stop`. There is no
inbound door. The banner's eyebrow carries **no truck number**, because `Lobby.padAsking` only
answers during `sizing` and the first live frame read TRUCK 1 over a player on pad 2.
*Verify:* `setPadMine` and its two call sites in `src/server/Lobby/init.luau`; the
`PAD_MINE_ATTRIBUTE` and `LEAVING.EYEBROW` blocks in `src/shared/Lobby/init.luau`;
`tests/server/lobby.spec.luau` (`WORDS.EYEBROW` carries no format specifier);
`tests/server/lobby_live.spec.luau`, *"tells every member of the party that his truck is loading,
and nobody else"* and *"leaves no banner and no running truck behind when the owner stops"*.

**4. There is no bar while the party is filling, and that is deliberate.**
`PadPanel.barFraction` answers `nil` for `filling` and the track is hidden, not drawn empty and not
animated. NN/g's rule (fetched and quoted, note 3b) is that a progress indicator says *"approximately
how much time remains"*; `countdown` knows that exactly and `filling` -- up to 45 s waiting for
people who may never come -- cannot.
*Verify:* `PadPanel.barFraction` in `src/client/Hud/PadPanel.luau`;
`tests/client/pad_panel.spec.luau`, *"says what the loading banner says, as arithmetic"* and the
`Track.Visible` assertion in the case after it.

**5. THE VIEW TURNS THROUGH THE CAMERA'S OWNER, AS A REQUEST.**
A player arrives on a pad facing north -- `Camera.faceCharacter` starts the view where the BODY is --
and his truck is eighteen studs SOUTH, so the engine start, the headlights and the smoke all
happened behind her. `Camera.faceTowards(point)` is a request of exactly the shape `Camera.lookAt`
has: it eases over `Config.FACE_TURN_SECONDS` inside the camera's own `update`, through the pure
`Mode.towardAngles` / `Mode.angleGapDeg`, and **`Rig.apply` is still the only writer of
`workspace.CurrentCamera`** -- the foreign-write counter is untouched. The Hud ASKS, once, on the
edge where a pad starts asking (`facedPad` in `Hud.renderObjective`), and the point comes from
`Lobby.truckPosition(index)`, which reads the model the SERVER built rather than repeating
`Pads.centreFor`'s arithmetic on the client.
*Verify:* `Camera.faceTowards` and the `facingTarget` block in `update` (`src/client/Camera/init.luau`);
`Mode.towardAngles` and `Mode.angleGapDeg` (`src/client/Camera/Mode.luau`); `facedPad` in
`Hud.renderObjective` (`src/client/Hud/init.luau`); `Lobby.truckPosition` (`src/shared/Lobby/init.luau`);
`tests/server/camera_mode.spec.luau`, the four cases under *"turning the view toward something in the
world"* -- the short-way yaw, the clamp, the gap, and a whole turn walked frame by frame exactly as
`update` drives it. **Measured live** against the truck's own position (not scenery): the view's flat
LookVector dotted with the direction to the truck goes **0.037 -> 1.000**.

**6. THE TAIL `PointLight`s ARE GONE, AND THE CAB-ROOF BRAKE LIGHT IS NOT A TAIL LIGHT.**
Measured like for like -- one held camera, one `ClockTime`, only the rig changed -- the rig ON washed
the two NEIGHBOURING trucks, their wheels and the ground salmon pink. Two causes, both mine: the
model's `B` lamp at local x **+2.80** of a 9.2 half-length is the HIGH CENTRE BRAKE LIGHT on the cab
roof and a far-HALF test called it a tail light; and the tail lights themselves, which the
rear-quarter frame showed were pure spill -- the lit `Neon` LENS is what reads as a tail light. A
tail is now in the far QUARTER (`ENGINE.TAIL_MIN_FRACTION`) and `ENGINE.TAIL_BRIGHTNESS` is **0**,
which builds no tail `PointLight` at all; above 0 brings it back, so it is a dial and not a deletion.
**After it the rig turns on 3 lights, all cream `SpotLight`s at the truck's own front.**
*Verify:* `lampsOf` and the `TAIL_BRIGHTNESS > 0` branch in `truckRig` (`src/server/Lobby/Build.luau`);
`ENGINE.TAIL_MIN_FRACTION` / `TAIL_BRIGHTNESS` in `src/shared/Lobby/init.luau`;
`tests/server/lobby.spec.luau`, the far-quarter block in *"tells a lamp from a chassis, and a
headlight from a tail light"*; `tests/server/lobby_live.spec.luau`'s `2 + tailGlows` light count.

**7. AN UNLIT LAMP IS NOT EMISSIVE AT ALL.**
A dark `Neon` lamp still glows at night, so three unlit trucks looked lit and the started one did not
stand out. The rig remembers each lamp's SHIPPED material (`TruckRig.lamps[].was`) and `setTruck`
swaps the material with the colour, to `ENGINE.OFF_MATERIAL` when dark.
*Verify:* the `was` field on `TruckRig` and the material lines in `truckRig` and `Build.setTruck`
(`src/server/Lobby/Build.luau`); `ENGINE.OFF_MATERIAL` in `src/shared/Lobby/init.luau`;
`tests/server/lobby.spec.luau` asserts it is never `Enum.Material.Neon`.

**8. THE EXHAUST AND THE ENGINE ARE PLACED AFTER PARENTING, AND A SPEC BOXES THEM.**
`Attachment.WorldCFrame` written BEFORE the attachment is parented lands in the LOCAL `CFrame` and
the engine then multiplies it by the part's own: measured live, the exhaust reported
**(5783.8, 304.8, -5872.9)** against a lobby at (2893, 150, -2941). The smoke was emitting three
thousand studs away and the ENGINE SOUND was playing there with it -- the whole of Karen's *"car
started sound"* -- and no spec could see it, because an attachment has no failure to assert, only a
position nobody looked at. Both are parented first now; measured after: smoke at
(2891.0, 150.8, -2941.1), the sounds at (2892.3, 152.1, -2925.3).
*Verify:* the `pipe` / `block` blocks in `truckRig` (`src/server/Lobby/Build.luau`) -- `Parent` then
`WorldCFrame`; `tests/server/lobby_live.spec.luau`, *"puts the engine and the exhaust ON the truck,
not three thousand studs away"*, which boxes EVERY attachment of every truck's rig and fails on an
empty loop.

**9. ONE MESSAGE AT A TIME, AS A LEVEL RULE.**
*"step on a truck pad to hunt"* showed while she stood on the pad, and *"leaving for the hunt in 5"*
duplicated the banner word for word. `Objective.text` returns `""` while either of the pad's panels
is up, read from `lobby.asking` and `lobby.loading`, which `Hud.renderObjective` fills from the same
two server-written facts the panels themselves are told. It is asked EVERY FRAME from the state as it
is -- no enter/exit edge to miss and nothing to get stuck in -- and the line comes back by itself.
*Verify:* the `lobby.asking ~= nil or lobby.loading ~= nil` branch and the `LobbyNow` type in
`src/client/Hud/Objective.luau`; the `asking` local and the `lobby` table in `Hud.renderObjective`
(`src/client/Hud/init.luau`); `tests/client/hud_clarity.spec.luau`, *"stands the top line down while
either of the pad's own panels is up"* -- which also asserts it RETURNS, and that a player in the
drive is unaffected.

**10. The style is the shop's, read from the shop.**
`ShopPanel.FONT` is new and that file's own five locals read it, so the faces have one definition;
`PadPanel` requires `ShopPanel` for `LOOK`, `FONT` and `spaced` and spells no hex and no font path of
its own. One documented departure from the designer's spec 8: **no scrim**, because stepping off the
pad is one of this dialog's five exits and dimming the world you must walk out of hides the way out.
One orange thing on the dialog, on row 1, which is `Pads.defaultSize`.
*Verify:* the two `require`s and the absence of `Color3.fromHex` / `fonts/families` in
`src/client/Hud/PadPanel.luau`; `ShopPanel.FONT` in `src/client/Hud/ShopPanel.luau`; the AND THERE IS
NO SCRIM paragraph in `PadPanel`'s header; `tests/client/pad_panel.spec.luau`'s `marks == 1` block.

---

## What is NOT proven

- **The mouse cancel, live.** The rule is one branch in `Camera.update` (`lookDelta.Magnitude >
  config.FACE_CANCEL_DELTA_PX` drops the target for good) and no live run has made it fire.
  StudioMCP's `user_mouse_input` sends ABSOLUTE `moveTo`, and under `MouseBehavior = LockCenter`
  that delivers no usable delta at all (`tools/studio_mcp.py` design section 9.3). A second attempt
  with OS-level relative `mouse_event` (`<runs-dir>/mouse-move.ps1`) also left the view on the truck
  (`dot=1.000`), most likely because PowerShell's `Add-Type` costs about a second to start and the
  turn is only 0.6 s long. **So "it does not fight her hand" is a claim about code I have read and
  not about a frame I have seen.** A resident sender, or lengthening `FACE_TURN_SECONDS` for one
  run, would settle it.
- **The banner's `GETTING YOU TO YOUR STAND` state, on the real path.** `leaving` lasts under one
  scan when the hand-over succeeds, so no poll ever caught it; in practice it is the FAILED-hand-over
  state, which `lobby_live.spec` drives. The line itself is asserted in
  `tests/client/pad_panel.spec.luau`.
- **Eleven `Neon` parts on the free truck model are larger than `ENGINE.LAMP_MAX_STUDS` (2.5) and are
  left exactly as they ship** -- measured: 11 still `Neon`, 9 named lamps dulled. So an unlit truck
  keeps a faint lens glow. The started truck is still unmistakably the lit one in the night pair, but
  "the others are fully dark" is not true and is not claimed.
- **Whether Karen likes any of it.** All four parts are look and feel and she has seen none of them.
- **How loud the engine is in the world.** The volumes come from the clips' own measured loudness and
  the roll-off from distances in the yard; what a player hears with ambience and a horn going is a
  playtest.
- **The tap itself.** A spec cannot fire `GuiButton.Activated` and the harness cannot synthesise a
  tap, so `PadPanel.press` is the seam the client spec drives and the live runs fire the remote
  directly. Unchanged from task 182.

---

## The frames, and the camera each was taken with

All at the player's own eye height on pad 2 unless a camera is named. `t197d-*` predate the
tail-light removal and still show pink on the neighbours' wheels; `t197e-*` are the final build.

| Frame | Camera | Look-at |
|---|---|---|
| `t197d-dialog`, `t197d-filling`, `t197d-countdown` | her own first-person camera, standing on pad 2 | -- |
| `t197e-rig-off` / `t197e-rig-on` (**the pair**) | `2893.0, 154.73, -2913.0` | `2893.0, 153.23, -2932.0`, ClockTime 19.6 |
| `t197e-tail-smoke` | `2903.0, 154.73, -2958.0` | `2893.0, 152.73, -2948.0`, ClockTime 19.6 |

Pad 2's deck is at `(2893.0, 149.73, -2914.0)`; truck 2's box is
`min (2888.65, 150.00, -2941.23)` / `max (2897.35, 157.01, -2922.77)`.
