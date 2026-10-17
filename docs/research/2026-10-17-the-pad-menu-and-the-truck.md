# The pad menu, the loading message, and the truck that starts

Task 197. Karen, 2026-10-15 ~17:40, verbatim:

> *"same with entering in game menu has to be nicer and cleaner / and we need clear message that game
> is loading once clicked 1/1 or other now is delay / also could be car started sound light on
> something like that indicating loading ect"*

Three things, one moment: the half-minute between walking onto a truck pad and finding yourself on a
stand in the forest.

---

## 1. What the system must do

1. **The size dialog is redrawn in the house style.** It is `Hud.PadPanel`, built in task 182, and it
   is the FIRST panel a new player meets -- before the shop, before a gun, before a boar. Today it is
   `Enum.Font.Code` on a blue-grey rectangle with four flat green buttons. Karen has already approved
   a style for exactly this (*"menu is nice"*, about the shop), and the designer's spec section 8 was
   written to govern it.
2. **The delay after the pick is SHOWN, honestly.** From the press to being somewhere else is
   **5.0 to 5.2 seconds** in the common case and up to **50 seconds** in the worst, and until this
   task the only thing on screen saying so was 27 characters of lower case on the objective line.
3. **The pad's own truck starts.** Engine, headlights, tail lights, a little exhaust -- for exactly
   as long as that party is loading, and on no other truck.
4. **And it must not**: keep a truck idling after a party cancels; claim a progress it cannot
   measure; need a second copy of the shop's palette; or add a second answer to *"which pad is this
   man on"*.

---

## 2. What the delay actually is, measured on the player's path

Not estimated server-side and not read off the config: the numbers below come from the pad state
machine as it is written, and the end-to-end was timed in a Play session of the Forest Test (section
6). Where the time goes, for the common `1 / 1` press:

| From | To | Seconds | What it is |
|---|---|---|---|
| the press | the server applies it | ~0.03-0.08 | one `RemoteEvent` round trip. `Lobby.onPadRequest` applies the pick in the same call, so there is no scan of latency here |
| `filling` | `countdown` | **0 to 0.1** | the pad is already full at size 1, so the next scan arms it. `SCAN_HZ` is 10 |
| `countdown` | `depart` | **5.0** | `CONFIG.COUNTDOWN_SECONDS`, task 177's own five, shared by the whole party |
| `depart` | the drive has him | ~0.1-0.6 | `Match.enrol` -> `LoadCharacter` -> `Body.place` |

**So the total is ~5.2 s, and 5.0 of it is the countdown -- which is a DESIGNED wait and not a
load.** Nothing here is slow; what was wrong is that nothing said so. That matters for what gets
built: there is no loading to speed up, so the honest fix is feedback, and the one number worth
drawing is the countdown the server already publishes (`DHLobbyLeaveAt`).

The worst case is different and is NOT a countdown: a party of 8 with 2 players in it sits in
`filling` for up to `FILL_TIMEOUT_SECONDS` = **45 s** waiting for people who may never come. That is
a wait with no knowable end, and section 3 is why it gets words and no bar.

**What was shortened.** One tenth of a second, and it is the only thing in the chain that could
honestly be shortened: `Build.setTruck` is called from `Lobby.onPadRequest` on the press as well as
from the scan, so the engine and the lights land on the click rather than on the next scan. The
5-second countdown is Karen's to shorten (one row, `CONFIG.COUNTDOWN_SECONDS`) and is not touched
here: it is the window in which a second player can still join the pad.

---

## 3. External sources

### 3a. Nielsen Norman Group -- "Response Times: The 3 Important Limits" -- **ADOPTED, and it is what decides that this is a real defect**

<https://www.nngroup.com/articles/response-times-3-important-limits/> -- Jakob Nielsen, 1993,
excerpted from *Usability Engineering*; the canonical statement of the three limits, still published
and still cited. Not code, so no licence question; it is read, not copied.

Fetched and quoted:

> *"0.1 second is about the limit for having the user feel that the system is reacting
> instantaneously ... 1.0 second is about the limit for the user's flow of thought to stay
> uninterrupted ... 10 seconds is about the limit for keeping the user's attention focused on the
> dialogue."*

and, on exactly our case:

> *"Feedback during the delay is especially important if the response time is likely to be highly
> variable, since users will then not know what to expect."*

**What it does well:** it turns *"now is delay"* from a taste into a measurement. 5.2 s is far past
1.0 and inside 10, which is the band where feedback is required and an *estimate of completion* is
not yet mandatory -- so a countdown is enough and an ETA is not needed. The 45-second `filling` case
is past 10 s, which is where the article says the user will go and do something else unless told when
the system expects to be done -- and we cannot know, which is the honest reason that state gets a
sentence rather than a number.

**What it does badly, for us:** it is about a system that is WORKING, and ours is DELIBERATELY
WAITING. None of its advice is about shortening a wait that exists on purpose, so it decides the
feedback and says nothing about the five seconds themselves.

### 3b. Nielsen Norman Group -- "Progress Indicators Make a Slow System Less Insufferable" -- **ADOPTED for the bar, and for when NOT to draw one**

<https://www.nngroup.com/articles/progress-indicators/> -- Katie Sherwin, 2014. Same provenance.

Fetched and quoted:

> *"Progress indicators tell users (a) that the system needs more time to process the last user
> action ... and (b) approximately how much time remains."*

> *"Always give some type of immediate feedback. A user's wait time begins the moment when she
> initiates an action."*

and the finding that pays for the bar at all:

> *"The researchers found that the people who saw the moving feedback bar experienced higher
> satisfaction and were willing to wait on average 3 times longer than those who did not see any
> progress indicators."*

**What it does well:** it splits the two cases we have. A **percent-done bar** needs (b) -- how much
time remains -- which the `countdown` state knows exactly and the `filling` state does not. So the
bar is drawn for the countdown, where it is a true percentage of a known five seconds, and the
`filling` state's track is **hidden**, not drawn empty and not animated: a looping indeterminate bar
during a 45-second wait would be claiming (b) while knowing nothing.

**What it does badly, for us:** its whole frame is a web page loading, where the wait is a cost to be
excused. Ours is five seconds in which a second player can still walk onto the pad, so the banner's
job is as much "a friend can still join" as "please wait" -- which is why the `filling` line reads
WAITING FOR THE PARTY and not LOADING.

### 3c. Roblox -- `Sound.PlaybackRegion` and `Sound.LoopRegion` -- **ADOPTED**

<https://create.roblox.com/docs/reference/engine/classes/Sound#PlaybackRegion> ·
<https://create.roblox.com/docs/reference/engine/classes/Sound#LoopRegion> · first-party engine
reference, current. `PlaybackRegionsEnabled` turns both on.

**What it does well:** it is the only way to loop PART of an asset. The alternative -- `TimePosition`
plus `Looped` -- replays from zero, so an idle loop taken out of a clip that starts with a key turn
would re-start the engine every pass.

**What it does badly:** nothing in the API tells you WHERE the idle is. The window has to be measured
(section 5), exactly as `Horn.CONFIG`'s own cut was.

### 3d. ProSoundEffects, through Roblox's licensed audio library -- **ADOPTED, two assets**

Searched through `apis.roblox.com/toolbox-service/v1/marketplace/3` and resolved through
`economy.roblox.com/v2/assets/<id>/details` -- the procedure task 142 used for the rifle and task 124
for the hit ticks. Only `Creator.Name == "ProSoundEffects"` with `IsPublicDomain: true` was kept:
that is Roblox's own licensed catalogue, and it is the entire set of candidates this project may
ship. Every search for "truck engine" outside it returns user re-uploads.

| Use | Id | Name, creator, category | Measured |
|---|---|---|---|
| start | `9112936632` | "1942 Dodge Wc Command Car Start Idle Revs 1 (SFX)", ProSoundEffects, **Vehicles - Military** -- *"Start, Idle, Revs, Turn Off, 6 Cylinder"* | `IsLoaded=true`, `TimeLength=10.87 s` |
| idle | `9125350177` | "2003 Dodge Ram Truck Start Med Cu Long Idle 2 (SFX)", ProSoundEffects, Vehicles - Modern Cars -- *"Start Medium CU, Long Idle, Reverse"* | `IsLoaded=true`, `TimeLength=24.91 s` |

**What they do well:** the command car is the only *start* in the licensed catalogue whose category is
the same word as `CONFIG.TRUCK.CAMO`'s -- these four trucks are camouflaged military pickups since
task 186 -- and the Dodge Ram carries seventeen and a half unbroken seconds of idle, which is a loop.

**What they do badly:** both are RECORDINGS OF EVENTS, not loops. The command car turns its engine
off at the end and the Dodge Ram starts its own at the beginning, so either played whole says the
opposite of what the banner says. Hence 3c.

Rejected and why: `9112988114` "1988 Chevy Pickup Truck Idle 1" (32.5 s) is named for an idle and its
own description lists *"Slow Maneuvers In to CU, Stop, Turn Off, Restart, Lurching Forward to Pass
By"* -- six events in half a minute, no quiet window worth looping. `9112936921` (the command car's
take 2, 11.7 s) is the same event and is the one-line alternate if Karen dislikes take 1.

### 3e. Roblox -- `SpotLight`, `PointLight`, `ParticleEmitter` -- **ADOPTED, with one measured correction**

<https://create.roblox.com/docs/reference/engine/classes/SpotLight> ·
<https://create.roblox.com/docs/reference/engine/classes/PointLight> · first-party, current.

A `SpotLight` shines along its parent's `Face`, which for a part is the model author's choice and not
ours. **So the beam hangs on an `Attachment` whose CFrame this repo writes**, pointing down the
measured facing.

### 3f. The designer's shop spec, section 8 -- **ADOPTED WHOLE**

`shop-design-spec.md`, outside the repo in the Director's runs directory. Not an external source --
it is ours -- but it is the authority for every colour, face and size in this task, and its section 8
is titled *"UI style -- for the start menu, the pad-size menu and the loading line"*. It was written
for this menu.

> *"The shop sets the house style. Anything built after it follows these, and nothing else needs
> deciding."*

**Adopted in full except one item, with the reason written down:** rule 8.1's scrim. The shop dims the
whole screen because its only way out is a button on it; stepping OFF THE PAD is one of this dialog's
five exits, so dimming the world a player must walk out of would hide the way out. Everything else --
the surface ladder, the single brass hairline, Oswald + BuilderSans, one orange thing per screen,
48-60 px rows, Frames for icons, one message slot, 0.12 s colour tweens -- is followed.

**And it is READ FROM THE CODE, not copied into it.** `Hud.ShopPanel.LOOK`, `.FONT` and `.spaced` are
required by `Hud.PadPanel`. Forty hexes and five font families transcribed into a second file would
be forty-five second answers to *"what colour is blaze orange"*, which is `docs/PROJECT_CONTEXT.md`'s
named failure mode -- and it is how the old dialog came to be `Enum.Font.Code` on blue-grey while the
shop beside it was Oswald on charcoal.

---

## 4. The free truck model's own lamps, measured

Dumped out of `Workspace.LobbyAssets.Truck` in the Forest Test on 2026-10-17 -- "PickUp Truck
(Prop)", RedWood Roleplay, the model all four bays clone -- in the model's own frame, x along its
18.46-stud length:

| Part | local x | local z | size (studs) | colour |
|---|---|---|---|---|
| `Light` x2 | **-7.82** | ±2.47 | 1.29 × 1.12 × 1.35 | white 248,248,248 |
| `Light` | -8.11 | 0.00 | 5.74 × 0.59 × 0.57 | amber 213,115,61 |
| `TS` x2 | -7.99 | ±2.76 | 0.51 × 0.32 × 0.24 | amber 213,115,61 |
| `T` x2 | **+8.53** | ±3.15 | 0.40 × 1.00 × 0.66 | red 255,89,89 |
| `B` x2 | +8.63 | ±3.13 | 0.36 × 0.81 × 0.20 | red 190,104,98 |
| `Light` | 0.05 | 0.00 | 6.70 × 4.50 × **17.65** | grey 163,162,165 |

**Two findings, both load-bearing.**

**(i) The chassis is a `Neon` part named `Light`, 17.65 studs long.** `Build.truckSkinOf` classifies
anything `Neon` or named "light" as a light, which is exactly right for the paint rule it was written
for (task 186 leaves every lamp its shipped colour) and would here have hung a SpotLight inside the
frame of all four trucks. Hence `ENGINE.LAMP_MAX_STUDS = 2.5`: a lamp is small, and the biggest real
one measures 1.35.

**(ii) `CONFIG.TRUCK`'s own comment about which way a truck faces is wrong, or at least incomplete.**
It says the model *"is delivered pointing along its own +X"* and is given `YAW_RADIANS` because *"the
yard wants it pointing SOUTH"*. The headlights are at local **-X**, so after the quarter turn the free
model's trucks look **NORTH**, up the yard -- while `Build.truck`'s fallback (bonnet at `at.Z - 7.4`)
looks SOUTH. Two branches, two fronts.

**So nothing in the rig reads a heading from the config.** The white pair IS the front, wherever it
is; the facing is measured from the truck's own box centre out through its own white lamps; and the
tails are *"every other small lamp on the far half from them"* -- a POSITION test and not a colour
test, because the amber indicators at the front are the same hue family as a tail light and a red
glow on a bonnet is the kind of thing that measures correct and looks wrong. The fallback truck,
which ships no lamp at all, is the one place a heading is asserted -- and it is asserted about
geometry the same file builds twenty lines above.

This note does NOT change the comment in `CONFIG.TRUCK`; the trucks' facing is Karen's to look at
and a separate task if she wants them turned round. It is recorded here and in `Build.lampsOf`'s
header so the next person does not trust the old sentence.

---

## 5. The two clips, cut on their own loudness

`Sound.PlaybackLoudness`, sampled at render rate in a Play session of the DEV place on 2026-10-17,
peak per 0.2 s bucket. The procedure task 124 used for the hit ticks and task 152/154 for the horn.
**`PlaybackLoudness` reads 0 and `TimePosition` never advances in EDIT mode** -- measured first, which
is why this is a Play-session number.

**`9112936632` -- the 1942 command car, 10.87 s**

```
0.0:35  0.2:56  0.4:41  0.6:123 0.8:191 1.0:153 1.2:66  1.4:61  1.6:135 1.8:131   <- the start
2.0:70  2.2:71  2.4:77  2.6:84  2.8:99  3.0:91  3.2:109                           <- settling to idle
3.4:114 3.6:123 3.8:141 4.0:158 4.2:154 4.4:143                                   <- A REV
4.6:114 4.8:104 5.0:95  5.2:80  5.4:69  5.6:63  5.8:36                            <- the TURN-OFF
6.0:21 ... 10.8:0                                                                 <- the tail
```

**Cut 0 -> 3.3**: crank, catch, settle. One second later it revs and then shuts down.

**`9125350177` -- the 2003 Dodge Ram, 24.91 s**

```
0.0:2 0.2:6 0.4:240 0.6:119 0.8:121 1.0:156 1.2:85 1.4:130 1.6:93 1.8:71          <- ITS start
2.0:56 ... 6.0:17                                                                 <- settling
6.2:13 ... 23.8:13      every bucket between 13 and 18                            <- THE IDLE
24.0:7 24.2:3 24.4:3 24.6:3 24.8:2                                                <- the fade
```

**Loop 6.2 -> 23.6**, inside the flat part at both ends: 17.4 seconds, so the longest `filling` wait
(45 s) hears under three passes.

**The two volumes come out of the same measurement.** The start runs at ~100-190 and the idle window
at ~15 -- the Dodge Ram was recorded far quieter -- so equal `Volume` would have left silence under
the banner the moment the start finished, which is the thing this task exists to remove. 0.45 against
1.0 is 2.2x the other way, leaving the start the louder EVENT with the idle clearly there under it.

---

## 6. The numeric targets

| What | Number | Where it comes from |
|---|---|---|
| press to the drive, common case | **5.2 s** (5.0 of it the countdown) | measured, section 2 |
| press to the lights and engine | **< 0.1 s** | `Lobby.onPadRequest` calls `setTruck` on the press |
| worst wait with no knowable end | 45 s (`FILL_TIMEOUT_SECONDS`) | why `filling` gets words and no bar |
| dialog width | 320 px (was 300) | fits the 400 px phone `hud_clarity.spec` measures |
| row height | 60 px | spec 8.6 (48-60), over Roblox's own 44 px touch minimum |
| header | 64 px | the shop header's own height: one header drawn twice |
| banner | full width less 12 px, capped 560, at 0.68 of the screen | clear of the top band and the bottom rail |
| start clip | `9112936632`, 0 -> 3.3 s, volume 0.45 | section 5 |
| idle loop | `9125350177`, 6.2 -> 23.6 s, volume 1.0 | section 5 |
| engine carry | 14 -> 90 studs | audible at the porch (46 studs), gone at the field's corners (220) |
| headlight beam | 60 deg, 46 studs, brightness 3 | reaches the yard, not the lodge behind it |
| lamp size bound | 2.5 studs | the real lamps measure ≤ 1.35; the chassis is 17.65 |
| truck writes per party | **2** (one on, one off) | `setTruck` is edge-triggered; a counter climbing with `scans` is the bug |

---

## 7. The pattern adopted, in one paragraph

**One server-measured fact, mirrored outward, read by two things that must agree.**
`Lobby.padLoading(state)` is true for `filling`, `countdown` and `leaving` and false for everything
else; the owner writes that pad's state word onto each member as `DHPadMine` (the `DHLobbyLeaveAt`
shape exactly -- one attribute, no new wire, no inbound door) and hands the same answer to
`Build.setTruck`. So the banner on a player's screen and the engine on that pad's truck are the same
fact said twice and cannot disagree. Both are **reconciled on the owner's 10 Hz scan with
edge-triggered writes**, which is `Build.setPad`'s arrangement and is the reason a party that
cancels, resets, departs or fails its hand-over never leaves a truck idling in an empty yard -- the
four ways out are driven one after another in `lobby_live.spec`. The screen half is
`ShopPanel`'s house style read out of `ShopPanel` itself, and the bar is drawn only where a
percentage is true.

---

## 8. What this note could not establish

- **Whether Karen likes any of it.** The restyle, the banner's wording and the truck's sound and
  light are look-and-feel, and she is away. The three are independent and she can accept or reject
  each on its own.
- **Whether the engine is the right LOUDNESS in the world.** `Volume` and the roll-off are set from
  the clips' own measured loudness and from distances in the yard; what a player hears standing on
  pad 2 with ambience and a horn going is a playtest, not a measurement.
- **Whether the trucks should face north at all** (section 4 (ii)). Measured and recorded; not
  changed, because the brief did not ask and turning four trucks round is a thing to look at.
- **Whether the free model's own amber indicators should light too.** They are at the front, they are
  classified as neither head nor tail, and they are left exactly as they ship.
