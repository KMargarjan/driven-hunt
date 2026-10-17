# Task 197 -- the pad menu in the house style, a clear "leaving" message, and the truck starts

Task: 197
Round: 1
Base: `4644b3e` (main)
Code commit: `392d773`

Harness (clean tree, one player, SCOPED):

```
HARNESS_LINE_PLACEHOLDER
```

`392d773` is the one commit that changed `src/` or `tests/`; everything after it in this branch is
paperwork (`reviews/`, `TASKS.md`'s own row). The scope is `auto:…`, which `tools/agents.py` accepts
as evidence **for a review round** (Task 113) and which the Director's dispatch for this task asked
for in as many words: *"GATE RULE: scoped test only (`test --scope auto`, logged)"*. The PR to
`main` still needs the full run; that is the Director's to take at the branch head.

Two players: **N/A.** Nothing this task touches is in `TWO_PLAYER_PATHS` (`tools/agents.py`). The
changed paths are `src/client/Hud/` (hud), `src/server/Lobby/` and `src/shared/Lobby/` (lobby), and
their three specs. Hud and lobby need the one-player line only, for the PR to `main` as well
(Director decision, 2026-10-03).

---

## What changed

**KAREN, 2026-10-15 ~17:40, verbatim (transcribed from the Director's dispatch):**

> *"same with entering in game menu has to be nicer and cleaner / and we need clear message that
> game is loading once clicked 1/1 or other now is delay / also could be car started sound light on
> something like that indicating loading ect"*

Three visible things in one moment -- the half-minute between walking onto a truck pad and standing
on a stand in the forest. **They are independent and Karen can accept or reject each on its own.**

1. **The size dialog** (`Hud.PadPanel`, task 182's) is redrawn in the **shop's house style** -- the
   designer's spec section 8, which is titled *"UI style -- for the start menu, the pad-size menu and
   the loading line"* and which Karen has already approved as a look (*"menu is nice"*). The palette,
   the five `Font` values and the letter-spacing helper are **read out of `Hud.ShopPanel`**
   (`LOOK`, the new `FONT`, `spaced`), not copied into a second file.
2. **A loading banner**, full width under the middle of the screen, for the three pad states after
   the pick: one line each and a bar that fills over the countdown.
3. **That pad's truck starts** -- engine, headlights, tail lights, exhaust -- and the other three
   stay dark.

The whole of (2) and (3) hangs on **one new pure predicate with two readers**:
`Lobby.padLoading(state)` is true for `filling`, `countdown` and `leaving`. The owner mirrors that
pad's own state word onto each member as the new `Player` attribute **`DHPadMine`** (the
`DHLobbyLeaveAt` shape: one attribute, no new wire, no inbound door) and hands the same answer to
**`Build.setTruck`**. So the banner on a member's screen and the engine on that truck are one fact
said twice.

Research note: `docs/research/2026-10-17-the-pad-menu-and-the-truck.md`.

---

## Claims, and how to verify each

**1. The delay was measured on the player's own path, and it is not a load.**
Press to the drive is **~5.2 s, and 5.0 s of it is `CONFIG.COUNTDOWN_SECONDS`** -- a designed wait in
which a second player can still step on. The note's section 2 breaks it into four spans, and section
6 of this request has the live timeline. So the honest fix is feedback and not speed, and the one
thing actually shortened is the tenth of a second the lights and engine used to wait for the next
scan: `Lobby.onPadRequest` calls `Build.setTruck` on the press, beside the `Build.setPad` it already
called there.
*Verify:* `docs/research/2026-10-17-the-pad-menu-and-the-truck.md` section 2; the `setTruck` call in
`Lobby.onPadRequest`; `CONFIG.COUNTDOWN_SECONDS` and `PADS.FILL_TIMEOUT_SECONDS` unchanged.

**2. There is no bar while the party is filling, and that is deliberate.**
`PadPanel.barFraction` answers `nil` for `filling` and the track is **hidden**, not drawn empty and
not animated. NN/g's rule, fetched and quoted in the note (3b), is that a progress indicator says
*"approximately how much time remains"* -- `countdown` knows that exactly and `filling` (up to 45 s
waiting for people who may never come) cannot.
*Verify:* `PadPanel.barFraction`; `tests/client/pad_panel.spec.luau`, *"says what the loading banner
says, as arithmetic"* and the `Track.Visible` assertion in the case after it.

**3. The banner's visibility is a server-measured fact, and it says nothing the server did not tell
it.** `DHPadMine` is written only by `ServerScriptService.Lobby`, level-triggered with edge writes
(`setPadMine`, `clearLeaveAt`'s own shape), cleared the moment `world.inDrive` is true -- the same
edge the roster is written on -- and cleared again in `Lobby.stop`. There is no inbound door. A
client cannot work it out for itself: after the pick there is no `DHPadFirst` for him, and
`Pads.indexAt` is the server's arithmetic over a position only the server measures.

**THE FIRST LIVE FRAME CAUGHT ME BREAKING EXACTLY THAT RULE, and the fix is in this branch** (commit
`6a279f0`): the banner's eyebrow read **TRUCK 1 while the player was standing on pad 2**, because
`Lobby.padAsking` only answers during `sizing` and the label kept whatever `buildBanner` wrote once.
The number is gone -- *"the screen never claims to know more than the world said"*
(`Objective.CONFIG.TEXT`'s rule) -- the pad's own billboard says which truck fifteen studs in front
of him, and `lobby.spec` now fails on a format specifier in that row. Putting the index back means
the SERVER publishing it beside the state word; queued rather than invented here. The DIALOG's
eyebrow keeps its number, because that one is up exactly when the client has been told the index --
and the frame in section 6 shows it reading TRUCK 2 on pad 2.
*Verify:* `setPadMine` and its two call sites in `src/server/Lobby/init.luau`; the `PAD_MINE_ATTRIBUTE`
and `LEAVING.EYEBROW` blocks in `src/shared/Lobby/init.luau`; `tests/server/lobby_live.spec.luau`,
*"tells every member of the party that his truck is loading, and nobody else"* and *"leaves no banner
and no running truck behind when the owner stops"*.

**4. The truck is RECONCILED on the scan, not fired on the pick -- which is why no truck is ever
left idling.** `Build.setTruck(index, Data.padLoading(pad.state))` is asked every scan in `stepPads`
beside `Build.setPad`, and is edge-triggered inside, so a running truck costs one comparison a scan
per bay. The four ways a party can end are driven one after another.
*Verify:* `tests/server/lobby_live.spec.luau`, *"turns the truck off again whichever way the party
ends"* (departure, stepping off during the countdown, and a refused `enrol` that puts the pad back
into `sizing`) and the fifty-scan edge claim in the case before it (`stats.truckWrites` does not move).

**5. Which way a truck faces is MEASURED, not read from the config -- and the config's comment about
it is wrong.** The free model's headlights are at its local **-X**, so after `YAW_RADIANS` these
trucks look NORTH, while `Build.truck`'s parts fallback puts its bonnet at `at.Z - 7.4` and looks
SOUTH. `Build.lampsOf` takes the white pair as the front wherever it is and derives the facing from
the truck's own box centre; only the fallback branch asserts a heading, about geometry the same file
builds. **I did not change `CONFIG.TRUCK`'s comment or turn any truck round** -- that is a look
decision and the brief did not ask for it; it is recorded in the note (section 4) and in
`Build.lampsOf`'s header.
*Verify:* `Build.lampsOf`; the note's section 4 table; `CONFIG.TRUCK.MODEL`'s own comment, unchanged.

**6. A lamp is small, and that bound is why no SpotLight ended up inside a chassis.** The free
model's CHASSIS is a `Neon` part **named `Light`, 6.70 × 4.50 × 17.65 studs**, which
`Build.truckSkinOf` correctly calls a light for the paint rule it was written for.
`Build.isTruckLamp` adds `ENGINE.LAMP_MAX_STUDS = 2.5`; the biggest real lamp measures 1.35.
*Verify:* `tests/server/lobby.spec.luau`, *"tells a lamp from a chassis, and a headlight from a tail
light"* -- every row of it is a measurement from the real model, listed in the note's section 4.

**7. Both engine clips are licensed library audio, cut on their own measured loudness.**
`9112936632` (1942 Dodge WC command car, ProSoundEffects, *Vehicles - Military*, `IsPublicDomain`
true, 10.87 s measured) cut **0 → 3.3 s**, because it revs at 3.4 and turns the engine off at 4.6;
`9125350177` (2003 Dodge Ram, 24.91 s) looped **6.2 → 23.6 s**, the flat middle of the clip, through
`PlaybackRegion` + `LoopRegion` -- the only way to loop part of an asset, since `Looped` replays from
zero and would re-start the engine every pass. The full `PlaybackLoudness` profiles are in the note's
section 5. **`PlaybackLoudness` reads 0 and `TimePosition` never advances in EDIT mode**, measured
first, which is why those are Play-session numbers.
*Verify:* the note's section 5; `CONFIG.TRUCK.ENGINE`'s comment block;
`tests/server/lobby.spec.luau`, *"cuts both engine clips inside what was measured"*.

**8. The style is the shop's, read from the shop.** `ShopPanel.FONT` is new and the five locals in
that file now read it, so the faces have one definition. `PadPanel` requires `ShopPanel` for `LOOK`,
`FONT` and `spaced` and spells no hex and no font path of its own. **One documented departure from
spec 8:** no scrim, because stepping off the pad is one of this dialog's five exits and dimming the
world you must walk out of hides the way out.
*Verify:* the two `require`s and the absence of `Color3.fromHex`/`fonts/families` in
`src/client/Hud/PadPanel.luau`; the AND THERE IS NO SCRIM paragraph in its header.

**9. One orange thing on the screen, and it marks a fact rather than a recommendation.** The blaze
bar is on row 1 only, which is `Pads.defaultSize` -- the size a pick nobody makes falls back to.
*Verify:* `tests/client/pad_panel.spec.luau`, the `marks == 1` block, which also asserts the marked
row is `PADS.SIZES[1]`.

**10. `stop` empties both frames completely, including the pieces that are not `GuiObject`s.** The
restyle added a `UICorner`, a `UIStroke` and (on the banner) a `UISizeConstraint` per frame; the old
`stop` destroyed only `GuiObject` children, so a re-start would have doubled every stroke.
*Verify:* `PadPanel.stop` / the local `empty`; `tests/client/pad_panel.spec.luau`'s teardown case,
which now counts the banner's `Track`, `UICorner` and `UIStroke` and expects exactly one of each.

---

## What I could not verify

- **Whether Karen likes any of the three.** All of it is look-and-feel and she has not seen it.
  *"Ready to merge" is not "ready for Karen"*: the PR should stay open for her look.
- **The tap itself.** A spec cannot fire `GuiButton.Activated` and the harness cannot synthesise a
  tap (`tools/studio_mcp.py` docstring: keys, mouse buttons, mouse moves and gaps only), so
  `PadPanel.press` is the seam the client spec drives and the live run fires the remote directly.
  What is proved is the ACTION behind the button, not the touch that reaches it. Unchanged from task
  182, and stated rather than papered over.
- **How loud the engine is in the world.** `Volume` and the roll-off come from the clips' own
  measured loudness and from distances in the yard; what a player hears standing on pad 2 with
  ambience and a horn going is a playtest.
- **The model branch of the rig, live.** The harness place (DEV) has no `LobbyAssets`, so the live
  spec exercises `Build.truck`'s PARTS fallback -- the branch that builds its own four lenses. The
  free model's own lamps are covered by the pure classifier over the measured table, and by the
  Forest Test frames in section 6.

---

## 6. What the live Forest Test measured, and the frames I looked at

A Play session in Karen's own Forest Test, driving the REAL path: the server sees the character on
the rectangle and asks, the client fires the pad remote, and the server's own attributes are what is
polled. Everything the run touched -- including the `ClockTime` the night frame needed -- lives in
the Play session and is discarded; `ClockTime` in the saved place reads **15** before and after.

**The delay, timed from the press (`t197-timeline.txt`):**

```
+0.13 s   DHPadMine=nil                       (the remote is in flight)
+0.50 s   DHPadMine=countdown  DHLobbyLeaveAt set   <- THE BANNER IS UP
+5.30 s   DHPadMine=nil        Team=Shooters        <- THE DRIVE HAS HIM
```

**5.30 s press to drive, with the banner up by the first poll at 0.50 s.** The note predicted ~5.2 s
from the state machine; measured 5.30. 5.0 of it is `COUNTDOWN_SECONDS`.

**The truck, read off the instances rather than off a screenshot** (pad 2, a pick of 8 so the pad
holds in `filling`):

```
before the pick   Truck1 lights=0 sounds=0 smoke=0 | Truck2 lights=0 sounds=0 smoke=0 | Truck3 ... | Truck4 ...
after the pick    Truck1 lights=0 sounds=0 smoke=0 | Truck2 lights=10 sounds=2 smoke=1 | Truck3 ... 0 | Truck4 ... 0
four seconds on   Truck2 lights=10 sounds=1 smoke=1      <- the START one-shot has finished; the IDLE loops
stepping off      every truck lights=0 sounds=0 smoke=0
after departure   every truck lights=0 sounds=0 smoke=0
```

`sounds=2 -> 1` is the cut working: the 3.3 s start plays once and the idle loop carries on alone.

**The beams, read off the attachments this task writes** -- which is the facing claim, measured:

```
at(2890.5,153.6,-2924.2) look(-0.10,-0.00,0.99)
at(2895.5,153.6,-2924.2) look(-0.10,-0.00,0.99)
```

**+Z, i.e. NORTH, up the yard at the pad** -- confirming section 4 of the note and `CONFIG.TRUCK`'s
comment being wrong, and confirming that the `WorldCFrame` fix landed: before it the beams were
aimed by the lamp part's own rotation.

**The frames (`<runs-dir>`), all four looked at:**

| File | Camera | Look-at | What it shows |
|---|---|---|---|
| `t197-dialog.png` | the player's own first-person view, standing on pad 2 | — | **TRUCK 2**, HOW MANY PLAYERS?, four two-line rows, the orange bar on `1 / 1` only, the hint line |
| `t197-leaving-countdown.png` | the same | — | LEAVING FOR THE HUNT / **THE TRUCK LEAVES IN 5** / the bar starting to fill |
| `t197-truck-day.png` | `2893.0, 154.73, -2913.0` | `2893.0, 154.5, -2932.0` | pad 2 at a player's eye height: **truck 2's headlights lit, the two neighbours dark**, WAITING FOR THE PARTY and no bar |
| `t197-truck-night.png` | the same, `ClockTime 19.6` | the same | the same at dusk -- the lit truck reads as the only one running |
| `t197-truck-night-side.png` | `2910.0, 157.5, -2919.0` | `2893.0, 154.5, -2932.0` | from the east, three trucks in frame, one lit |

The truck box, for the Director's own frames: `min (2888.65, 150.00, -2941.23)`,
`max (2897.35, 157.01, -2922.77)`; pad 2's deck is at `(2893.0, 149.73, -2914.0)`.

**What the frames do NOT show, said plainly:** the TAIL lights and the exhaust smoke. Both are at
the truck's south end, which is the end a player standing on the pad never sees -- the counts above
(`lights=10`, `smoke=1`) are what evidences them, and a frame of them would need a camera behind the
bays. And the banner sits over the truck's lower half at `Y_SCALE = 0.68`; moving it is one row if
Karen wants the truck clear.
