# Task 266 — what the probes answered, pasted

Every line below is copied from the run that produced it, in the **Driven Hunt Forest Test**
(placeId 130094961655666), live Play, 2026-10-25. The probe files beside this one are the ones that
produced them, **with the absolute paths replaced by `<runs-dir>` / `<repo>` placeholders so
`tools/privacy_scan.py` passes** — the runnable copies live outside the repo under `<runs-dir>`
(Director ops, CLAUDE.md's ops split).

## 1. The instrument was broken, and it was not the click, the binding or the gun

### 1a. `aimshot.py --selftest`, the instrument task 265 relied on — FAIL, reproduced

```
ARM AIM Boar3/calf at 3014.51,140.64,-2174.51 range=79.2 eye=3029.99,144.71,-2096.99
  shot 1: clicked 640,523      shot 2: clicked 640,523      shot 3: clicked 640,523
  shot 4: clicked 640,523      shot 5: clicked 640,523
SELFTEST: 5 click(s) -> 1 ShotLanded
SELFTEST FAIL
```

### 1b. `266diag.py` — the clicks ARRIVE and the server answers NOTHING

Four counters for the same real, focused clicks: `UserInputService.InputBegan` on the client,
`ShotFired`, `ShotLanded`, and every `StateChanged` carrying `refused`.

```
ARM armed tool=Shotgun
  click 1..5: clicked 640,523
clicks=5 gameProcessed=false ShotFired=0 ShotLanded=0 refused=[] tool=Shotgun
```

Repeated with no reload in front of the clicks, reading after each one — the same:

```
  click 1: clicked 640,523
      clicks=6 gameProcessed=false ShotFired=0 ShotLanded=0 refused=[] tool=Shotgun
  click 2 .. click 4: clicks=7,8,9   ShotFired=0 ShotLanded=0 refused=[]
```

### 1c. `266-bound.luau` — the binding is NOT the fault

```
mouseBehavior=Enum.MouseBehavior.LockCenter bound=22 | ... DrivenHunt.Weapon.Aim{MouseButton2,ButtonL2}
DrivenHunt.Weapon.Fire{Enum.UserInputType.MouseButton1,Enum.KeyCode.ButtonR2}
DrivenHunt.Weapon.Reload{R,ButtonX} DrivenHunt.Weapon.SelectAmmo{X,DPadLeft} ...
|| GUIs: BubbleChat=true Chat=true Freecam=true HunterHud=true
```

### 1d. `266-who.luau` — THE CAUSE. The player was a BEATER holding a HORN

```
name=Alhamdulilah824 team=Drivers role=nil health=100 held=[Horn] backpack=[] at 3660,190,-2670
```

and the Forest Test's own console, from the same session:

```
[place] spawn Alhamdulilah824 at (3660, 190.9, -2670) ground=187.4 askedY=191.4 dY=-0.5
[ForestTest] Alhamdulilah824 is a beater at (3660, 191, -2670), 580 studs from the road (settled=0)
[report] drive 2 opened (300s windows)
```

while the SAME session's first reading, in drive 1, was `266-state.luau`:

```
team=Shooters tool=Shotgun backpack=nil animals=10 | Boar1 kind=male v=4.5 ... Boar4 kind=female v=24.3 ...
```

**So the role changes between drives**, and `DHForestStartRole=hunter` (read below) does not hold it:
it is read once at join.

### 1e. `266-holds.luau` — why the obvious client-side check cannot be made from a probe

```
held=false tags=[] watchedTools=0 isAiming=false (watchedTools>0 means this IS the live module instance)
```

`watchedTools=0` on a client with a Tool equipped proves this is a **fresh** module copy, which is
the memory `studio-mcp-execute-luau-single-line` records. So `Input.isHeld()` cannot be read from a
probe at all, and the diagnosis had to be made out of instance facts.

## 2. The instrument now refuses, and that was shown in both directions

`266shot.py --check`, with the player a shooter:

```
PRECHECK PRE OK team=Shooters held=[Shotgun] gun=Shotgun at 3030,143,-2097 attrs{DrivenHunt.Weapon=shotgun}
```

and later in the same Play session, after the drive rolled over:

```
PRECHECK PRE FAIL (not a shooter) team=Drivers held=[Horn] gun=nil at 3660,190,-2670
REFUSED: the player cannot fire. This is an INSTRUMENT fault, not data.
```

With `PRE OK`, a real focused click produces a shot, and the two signals are now separate:

```
ARM AIM Boar37/male chestLocal=0.000,0.555,-0.600 v=4.50 lead=0.00 range=169.3 ...
CLICK clicked 640,523
offTarget=0.307 deg clicks=2 ShotFired=2 ShotLanded=0 refused=[] mark=[]
  TRIGGER ray 3029.643,144.725,-2096.825 -> -0.8936,-0.1009,0.4373 | Boar37 v=4.51 at 2910.91,130.81,-2038.55
```

`ShotFired` moved and `ShotLanded` did not: **the trigger worked and the shot hit nothing.** Under
`aimshot`'s old metric that same event reads as a dead click.

## 3. What the shooter in the Forest Test actually has, measured

```
  AMMO    selected=2 loaded=None|Buck reserve{Buck=12 Slug=0} open=false
```

**Buck only — `reserve{Buck=12 Slug=0}`.** `Shotgun.CONFIG.RANGE_STUDS = { Slug = 330, Buck = 100 }`,
and the animals the drive presents were at these ranges, read off the player's own eye with a
line-of-sight cast per animal (`266-look.luau`):

```
Boar23(female) d=137 v=11.1 CLEAR | Boar24(female) d=177 v=15.6 CLEAR | Boar25 d=170 v=14.1 CLEAR
Boar26(male) d=165 v=14.1 CLEAR | ... | Boar39(male) d=204 v=11.0 CLEAR      (19 animals, 137-230)
```

and twelve seconds later the same sounder, mid-crossing:

```
Boar27(male) 17 v=24.0 CLEAR | Boar26(male) 22 v=24.5 CLEAR | Boar28(male) 21 v=27.4 CLEAR
Boar25 25 | Boar29 28 | Boar30 33 | Boar36 37 | Boar31 39 | Boar38 41 | Boar37 43 | Boar32 45
Boar33 49 | Boar34 56 | Boar35 64 | Boar23 58            (nine inside 30 studs, at 24 studs/s)
```

then nothing within 90 studs for the next four polls (about a minute). **So a shot taken between
waves cannot reach what it is aimed at**, and one shot in this task's batch was fired at an animal
183 studs out with buckshot and landed on a tree and the ground, 2 and 3 pellets:

```
[1] Trunk zone=Trunk world 2983.59,136.02,-2162.79 local 3.003,-55.918,-2.100 ACROSS 1.061 ;;
[2] Terrain zone=Terrain world 2973.36,135.00,-2176.10 ... ACROSS 0.735 ;;
[3] Terrain zone=Terrain world 2971.45,134.94,-2177.72 ... ACROSS 1.219
```

That is **not** a measurement of the aim: it is the ammo's range, and it is why `--range` and the
crossing poll exist in the instrument now.

## 4. The Forest Test's own attributes — unchanged by this task

Read during Play and again in Edit at the end of the session (`attrs-id.luau`), character for
character identical:

```
placeId=130094961655666 DHFlag_BOAR_BEHAVIOUR=true DHFlag_BOAR_MODEL=true DHFlag_COINS=true
DHFlag_DEER_ROAD_LEAP=true DHFlag_DRIVE_BOTS=true DHFlag_HORN=true DHFlag_LICENCE_POPUP=true
DHFlag_LOBBY=true DHFlag_SHOP=true DHForestStartRole=hunter DHShopTestGrant=true
```

**No "before" read was taken at the very start of the session**, which the Director's standing block
asks for; the two reads above are both from the end. Nothing this task ran writes a `ServerStorage`
attribute — the probes write `ReplicatedStorage` and `Player` attributes inside a Play session, which
do not survive it — but that is an argument, not the reading the block asked for, and it is said here
rather than left out.
