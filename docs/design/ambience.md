# Ambience: the lodge bed and the hunt bed

Architect design for task 250, item 4. Input: `reviews/task-250/BRIEF.md` (Builder carrying the
Director), which overrides anything older in `docs/`, `TASKS.md` and any earlier design. There is no
earlier `docs/design/ambience.md`; this is the first.

Karen, 2026-10-23, verbatim: *"any lobby music, like birds relax quuiet ?"*

---

## 0. The brief's premise check, and where "volume 3.00" actually came from

The brief says there is no ambience owner in `src/` and that the forest ambience Karen hears is a
Studio-made `Workspace.Ambience`. I confirmed both from the tree, and I can also name the thing the
dispatch mis-measured.

**Evidence.** The only five `Instance.new("Sound")` sites in `src/` are
`src/client/Hud/Sound.luau` (`Sound.tick`, `makeSignalVoice`), `src/client/Weapon/Sound.luau`
(`play`), `src/server/Boar/Body.luau` (`makeSound`), `src/server/Lobby/Build.luau` (`engineSound`)
and `src/server/Weapon/Horn.luau` (inside the Tool builder). None is looped-and-global. Nothing in
`src/` writes any `SoundService` property: the only mentions of `SoundService` in the whole of `src/`
are `game:GetService("SoundService")` and `.Parent = SoundService` in the two client sound modules.

**The 3.00 reading.** `src/client/Weapon/Sound.luau`'s `play` carries a measurement comment from task
248: *"two ambience sounds sitting in `SoundService` at **3.00**"*. Those are not ambience. They are
`Hud.Sound`'s own drive-signal voices:

* `Hud.Sound`'s module-load loop walks `Horn.signalWords()`, which returns one word per row of
  `Horn.CONFIG.SIGNAL.PHRASES` — `start` and `end`, so exactly **two**;
* `makeSignalVoice` sets `sound.Name = SIGNAL_NAME .. "_" .. which`
  (`DriveSignal_start`, `DriveSignal_end`), `sound.Volume = Horn.CONFIG.SIGNAL.VOLUME` and
  `sound.Parent = SoundService`;
* `Horn.CONFIG.SIGNAL.VOLUME = 3` (`src/shared/Horn/init.luau`, with the loudness measurement that
  chose it written above the row).

Two Sounds, in `SoundService`, at Volume 3.00, present from client boot whether a drive is running or
not. That is the whole of what was read. **The dispatch's "the forest ambience runs at volume 3.00"
is a reading of the two bugle voices**, and the real forest bed is Karen's `Workspace.Ambience` at
0.50 that the brief probed. Both halves of the brief's finding stand, and the third half is this: the
number the dispatch quoted belongs to a system that already has an owner, and the new owner must be
named so the two can never be confused again.

---

## 1. What the system must do

1. Play a **quiet bed at the lodge** — birdsong plus a soft wind — for the local player, at the ear,
   not positional.
2. Play a **hunt bed during the drive**, as a second bed the machine supports and the shipped data
   leaves silent (section 6.3 says why).
3. **Crossfade** between the two: when the player leaves for the drive, and again when he comes back.
4. Be **one Instance per client**, never one Instance in the world everybody is near — the rule
   `src/client/Hud/Sound.luau`'s header already states for the drive's signal and
   `src/client/Weapon/Sound.luau`'s header states for the gun.
5. Hold **every id, level, loop window and fade length as one data row** Karen can turn (brief
   decision 5; the discipline of `Horn.CONFIG.SIGNAL.PHRASES`, `Rifle.CONFIG.SOUND`,
   `Lever.CONFIG.SOUND`).
6. Be **provable without ears**: the Instance exists, its `SoundId`, `Looped`, loop window, `Parent`,
   `IsLoaded`, and the resolved `Volume` at each state. Nothing in this repo can hear it (brief
   decision 6).

## 2. What it must not do

1. **It must not touch `Workspace.Ambience`** (brief decision 4). Not read, not written, not
   reparented, not destroyed, not stopped, not volume-adjusted. It is a Studio-edited non-script
   instance in a container Rojo does not own (CLAUDE.md, Layout), so a Connect would not put it back,
   and writing it would make this repository a second writer of something Karen placed by hand.
2. **It must not write any `SoundService` property** — `Volume`, `AmbientReverb`, `DistanceFactor`,
   `DopplerScale`, `RolloffScale`, `RespectFilteringEnabled`. Nobody writes them today (section 0),
   and a module that did would be a second answer to how loud the whole game is.
3. **It must not measure a position.** No `Vector3`, no distance to a lodge, no `Region3`, no
   `.Magnitude`. The state comes from one replicated fact (section 4).
4. **It must not learn what a lodge model is.** It never requires `Lobby`, never reads
   `Lobby.CONFIG.LODGE`, never looks for a part, a tag or a prompt.
5. **It must not create a positional Sound**, an `Attachment`, or a Sound parented to a `BasePart`.
6. **It must not own a cue.** A hit tick, a shot, a bugle and a horn blast are events with owners
   already. A bed has no cue: it is on for a whole state.
7. **No remote, in either direction.** The system has no server half, so its inbound exploit surface
   is zero — the shape `src/client/Match/init.luau`'s header records
   (`docs/design/drive.md` section 9.1).
8. **It must not upload audio** (brief decision 3). The voices are Roblox-provided licensed library
   audio. `tools/roblox_upload.py` implements Model and Decal only and its own selftest asserts that
   `Audio` is refused; the upload route would be a tool change inside a four-item task.
9. It must not write anything drawn, anything on the camera, or `Lighting`.

---

## 3. The owner

**`src/client/Ambience/init.luau` → `StarterPlayerScripts.Ambience` → `Player.PlayerScripts.Ambience`.**
It is the one writer of every bed `Sound` instance and the one writer of their `Volume`.

Three files, the shape `Drive` / `Match` / `MatchBoot` already uses:

| Disk | Studio | Role |
|---|---|---|
| `src/shared/Ambience/init.luau` | `ReplicatedStorage.Ambience` | **the data and the pure rules.** `CONFIG`, `bedFor`, `targetsFor`, `stepGain`, `volumeFor`, `rowsOk`. No Instance, no service, no state, no writer at run time — the discipline `src/shared/Horn/init.luau` keeps (*"frozen data with no run-time writer"*, `GAME_DESIGN.md`'s horn row) |
| `src/client/Ambience/init.luau` | `StarterPlayerScripts.Ambience` | **THE OWNER.** Holds the two gains, makes the voices at module load, connects one `Heartbeat` and one `Team` signal, writes `Sound.Volume` |
| `src/client/AmbienceBoot.client.luau` | `StarterPlayerScripts.AmbienceBoot` | boot line only: `Ambience.start()`. Verbatim the shape of `src/client/MatchBoot.client.luau` |

### 3.1 Why not a voice class inside `src/client/Hud/Sound.luau`

The brief asks this as a naming question and it is the right question. Five reasons, in order of
weight:

1. **That module's own header says it is not this.** `src/client/Hud/Sound.luau` line 2: *"THE ONE
   WRITER of the Hud's own 2-D feedback sounds"*. A bed is not feedback. Nothing happened. Widening a
   stated owner boundary to fit a thing that does not match it is how the previous project got
   *"one predicate answered two unrelated questions"* (`docs/PROJECT_CONTEXT.md`).
2. **It would couple the ear to the screen.** `Hud.Sound` is reached only by being required from
   `src/client/Hud/init.luau`. `Hud.start` does a `WaitForChild("Camera", 5)`, a `pcall` around
   `SetCoreGuiEnabled`, and builds a whole `ScreenGui`; a bed inside it is born only in a world where
   the Hud boots and dies with any Hud boot failure. The bed has nothing to do with screen space.
3. **A bed needs a clock and that module has none.** Every path in `Hud.Sound` is edge-driven
   (`Sound.tick`, `Sound.driveSignal`), with `task.spawn`/`task.wait` inside one cue. A crossfade is a
   per-frame stepper. Putting a `RunService.Heartbeat` connection into the Hud's sound module makes
   that module a clock owner on top of being a cue owner.
4. **`Volume` after creation.** `Hud.Sound` sets `Volume` once at creation and never again
   (`makeSignalVoice`, `driveSignal`'s `voice.Volume = config.SIGNAL.VOLUME`). The bed's whole
   behaviour is writing `Volume` every frame. One module with both rules is one module where
   "who last wrote this Sound's Volume" has two answers.
5. **Scope.** `src/client/Hud/` resolves to `hud` in `BLAST_RADIUS`. A bed inside it would make every
   bed-level tweak play the entire 14-spec `hud` tuple, and every Hud edit play the bed's spec.

### 3.2 Why a `shared` half at all

`bedFor`, `targetsFor`, `stepGain`, `volumeFor` and `rowsOk` are pure. Put in `src/shared/`, a **server**
spec drives every branch of the state machine and every data invariant with no client, no Sound and
no clock — the cheap half of the proof. The client spec is then only about Instances. This is the
`src/shared/Horn/` + `src/client/Hud/Sound.luau` split that `zz_horn.spec` already exploits.

`src/shared/Ambience/init.luau` requires exactly one other module: `ReplicatedStorage.Drive`, for
`Drive.TEAMS` (`table.freeze({ Drivers = true, Shooters = true })`, `src/shared/Drive/init.luau`). The
two team words are not copied: a third spelling of `"Shooters"` in this repo is a bug waiting for a
rename.

---

## 4. The one fact, and the one boundary it is read at

**The fact: `Players.LocalPlayer.Team`.** A player at the lodge has no team. That is not an inference
about the lodge; it is what "not being in the drive" means everywhere in this repo:

* `src/shared/Drive/init.luau` `Match.myTeam`'s rule, quoted in `src/client/Match/init.luau`:
  *"From `Player.Team`, NOT from the snapshot: the team is one fact with one representation, and the
  engine replicates it (`docs/design/drive.md` section 5.1)"*;
* `src/client/Hud/Objective.luau` `Objective.text`: `if team ~= "Shooters" and team ~= "Drivers"` is
  *the* lobby branch, with the note *"A man standing by the lodge is not in a drive, so he has no
  team"*;
* `src/server/ForestTestBoot.server.luau`, in the respawn path: *"player was out of the drive
  (`Player.Team` nil, `RespawnLocation` back at the lodge)"*.

**The boundary: one private `refresh()` in `src/client/Ambience/init.luau`**, called from exactly two
places — once at the end of `Ambience.start()`, and from
`Players.LocalPlayer:GetPropertyChangedSignal("Team")`. `refresh()` does one thing:
`Ambience.applyTeam(if player.Team then player.Team.Name else nil)`. Nothing else in the module reads
the world.

That signal is not a guess: `src/client/Hud/init.luau`'s `apply` closure already does
`player:GetPropertyChangedSignal("Team"):Connect(apply)` for the compass bearing, with the reason
written beside it (*"`/beater` switches the team mid-session and a marker that still pointed north
would be a lie in the shape of a fact"*). `Player.Team` is a replicated property, so the client is
told.

### 4.1 Why not `Match.myTeam()`, and why not the snapshot

`src/client/Match/init.luau`'s `Match.myTeam` reads `Players.LocalPlayer.Team` and returns
`team.Name`. Going through it buys nothing and costs three things: a `WaitForChild("Match")` and its
boot race (the exact failure `src/client/Hud/init.luau` records at `WaitForChild("Camera")` — *"this
line ran before the engine had copied `Camera` into `PlayerScripts`"*), a module dependency on a
system that may not be booted in a given world, and a `BLAST_RADIUS` dual membership that makes every
`src/client/Match/` edit play the bed's spec.

The **snapshot** is the wrong door for a different reason: `Drive.MatchSnapshot` carries per-row teams
*for the scoreboard*, and `Match.myTeam`'s own header says the team has one representation and it is
`Player.Team`. Reading the bed's state off the scoreboard copy would be a second representation.

If the Director prefers the replica door, it is one line in `refresh()` plus one `SCOPE_SPECS` entry,
and nothing else in this design moves. **The design's decision is `Player.Team`.**

---

## 5. The crossfade, as a state machine

### 5.1 State

Two beds, `"lodge"` and `"hunt"`. The whole state of the system is:

* `gains: { lodge: number, hunt: number }` — where each bed is now, in `[0, 1]`;
* `targets: { lodge: number, hunt: number }` — where each bed is going;
* `bed: string` — the bed last applied, for reporting.

**Invariant I1: exactly one target is `1` and the other is `0`, always.** `Ambience.targetsFor(bed)`
is the only producer of a target table, and it builds one from `Ambience.BED_WORDS`. So "at most one
rising and one falling at a time" is not a rule the stepper enforces; it is a property of the only
shape a target table can have.

### 5.2 The transition

`Ambience.applyTeam(team)` → `bed = Ambience.bedFor(team)` → `targets = Ambience.targetsFor(bed)`.
That is all it does. **It never writes a gain and never writes a Volume.** It is the one writer of
`targets`.

`Ambience.step(dt)` is the one writer of `gains` and the **one writer of every bed voice's
`Sound.Volume`**:

```
for each bed word w:
    gains[w] = Shared.stepGain(gains[w], targets[w], dt, CONFIG.FADE_SECONDS)
    for each voice v of bed w with a Sound:
        v.Sound.Volume = Shared.volumeFor(gains[w], v.LEVEL)
```

`stepGain` is pure, dt-proportional and clamped:

```
step = dt / fadeSeconds        (fadeSeconds <= 0 => step = 1, i.e. instant)
if target > gain then return math.min(target, gain + step)
if target < gain then return math.max(target, gain - step)
return gain
```

### 5.3 A state change mid-fade

Nothing special happens, and that is the design. `applyTeam` writes only `targets`; `gains` are
untouched and keep their current values, so the next `step` reverses direction **from where the fade
had got to**. There is no "cancel", no tween to destroy, no latch, no enter/exit edge to miss.
`gains` are continuous across any number of flips.

**Invariant I2: `Ambience.step(0)` never changes anything**, so a flip followed by a zero-length step
is observably a pure retarget. The spec asserts exactly that.

This is also why **there is no `TweenService`**. A tween on `Sound.Volume` would be a second writer of
`Volume` (the engine writes it while the module believes it owns it), and two tweens overlapping on a
mid-fade flip is the *"two correct pieces of code disagreeing"* failure
`docs/PROJECT_CONTEXT.md` records. One `Heartbeat` → one `step` → one `Volume` write per voice.

### 5.4 Playing and stopping

Every voice with a non-empty id is `:Play()`ed **once, at module load, at `Volume = 0`, and is never
stopped for the rest of the session.** `gains` start at `0` for both beds.

Why never stop: `Play()` on a stopped Sound restarts it at the `PlaybackRegion` start, so a
stop-on-silent rule puts an audible restart at the far end of every crossfade; and a second edge
("is it playing") would be a second place the truth lives. With this rule **the gain is the whole
truth** and `Volume` is a function of it. The cost is two silent looped streams during a drive, which
is nothing.

Consequence, stated because it is a feel decision Karen will notice: **a joining player's lodge bed
fades in from silence over `FADE_SECONDS`** rather than starting at level. One rule, no join
special case.

### 5.5 A world with no lodge — the DEV arena, where every spec runs

**There is no world gate, and the module never asks which world it is in.** It knows two states, and
a player with no team is in the `lodge` state because he is, verifiably, not in the drive. In the DEV
arena that means the quiet bed plays while he is unassigned and the hunt bed (silent, section 6.3)
takes over once `Match` assigns him a team. Both are true statements about the world.

A `Map.EXPECTED_WORLD` gate was considered and rejected: the arena is the place every spec runs in, so
a branch that turns the system off there is a branch no spec can cover, and a design whose only
tested path is the dead one is the *"harness was wrong as often as the game"* failure in another
shape.

**This has a direct consequence for the client spec, and it is a false-PASS trap.** In the DEV place
`src/server/MatchBoot.server.luau` starts a real drive with no lobby, so a single harness player
**is** assigned a team at some point in the run. A spec that asserted "the lodge bed is at full gain"
would pass or fail on the drive's phase. So the client spec **drives the state through the parameter
door `Ambience.applyTeam(word)` after `Ambience.stop()`**, and never asserts the ambient team.
See section 10.2.

---

## 6. Public interface

### 6.1 `ReplicatedStorage.Ambience` (`src/shared/Ambience/init.luau`)

```luau
export type Voice = {
    ID: string,            -- "rbxassetid://<n>", or "" for silent-and-not-an-error
    LEVEL: number,         -- this layer's own Volume at full gain, 0..10
    FROM: number,          -- loop window start, seconds
    TO: number,            -- loop window end, seconds. 0 == "the whole clip"
    CLIP_SECONDS: number,  -- the asset's measured TimeLength
    WHAT: string,          -- "birds" / "wind": the layer's word, for the Instance name
}
export type Bed = { WORD: string, VOICES: { Voice } }
export type Config = { FADE_SECONDS: number, BEDS: { [string]: Bed } }

Ambience.CONFIG: Config                 -- deep-frozen
Ambience.BED_WORDS: { string }          -- { "lodge", "hunt" }, frozen, in this order
Ambience.DEFAULT_BED: string            -- "lodge"

Ambience.bedFor(team: string?): string
Ambience.targetsFor(bed: string?): { [string]: number }
Ambience.stepGain(gain: number, target: number, dt: number, fadeSeconds: number): number
Ambience.volumeFor(gain: number, level: number): number
Ambience.loopWindow(voice: Voice): (number, number)      -- resolves TO == 0 to CLIP_SECONDS
Ambience.voiceName(bed: string, voice: Voice): string    -- "Ambience_lodge_birds"
Ambience.rowsOk(config: Config?): (boolean, string?)
```

All six functions are **pure** and take their config or their numbers as arguments, so a spec drives
every branch with no Sound, no clock and no player. `bedFor` returns `"hunt"` when
`Drive.TEAMS[team]` is true and `Ambience.DEFAULT_BED` otherwise — nil, `""`, `"Spectators"` and any
future team word all land on the lodge, which is the safe answer (the rule
`Horn.signalPhrase` already sets: *"a silent drive would be a worse answer than the wrong phrase"*).

`rowsOk` is the data invariant checker, the shape `Shop.rowsOk` already has. It returns false with a
named reason when, for any voice with a non-empty `ID`: `LEVEL` is not in `(0, 10]`; `FROM < 0`;
`TO ~= 0` and not `FROM < TO <= CLIP_SECONDS`; `CLIP_SECONDS <= 0`; `WHAT` is empty or repeats inside
its bed; or when `FADE_SECONDS <= 0`; or when `BEDS` has a key that is not in `BED_WORDS` or is
missing one.

### 6.2 `PlayerScripts.Ambience` (`src/client/Ambience/init.luau`) — the owner

```luau
Ambience.start()                       -- idempotent; connects Heartbeat + Team, then refresh()
Ambience.stop()                        -- disconnects both. Leaves gains, targets and Instances alone
Ambience.applyTeam(team: string?)      -- THE ONE WRITER of `targets`
Ambience.step(dt: number)              -- THE ONE WRITER of `gains` and of every bed Sound's Volume
Ambience.gains(): { [string]: number }         -- a clone
Ambience.targets(): { [string]: number }       -- a clone
Ambience.bed(): string                         -- the bed last applied
Ambience.voices(bed: string): { Sound }        -- the Instances this module made, in row order
Ambience.ready(): (boolean, boolean)           -- madeAtLoad, preloaded
Ambience.stats(): { [string]: number }         -- applied, silent, stepped, arrived
Ambience.resetStats()
```

No events, no remotes, no `BindableEvent`, no setter for `gains`. `stats` and `ready` are verbatim the
seams `Hud.Sound.stats` / `Hud.Sound.signalReady` are, for the reason that module's header gives:
*"So a spec can hear what was asked for without a speaker"*.

`arrived` counts fades that reached their target exactly once each, so "the crossfade finished" is a
number and not a sleep.

There is no `advanceForTests`: `Ambience.step(dt)` **is** the public stepper, and the `Heartbeat`
connection is just a caller of it. One function, one writer, and the spec and the engine take the same
door — which is the opposite of the harness having a private path (`Match.advanceForTests` exists
because a drive's clock is the server's; a bed's clock is not).

### 6.3 The data, as it ships

```luau
Ambience.CONFIG = {
    FADE_SECONDS = 2.5,
    BEDS = {
        lodge = { WORD = "lodge", VOICES = {
            { WHAT = "birds", ID = "<Pro Sound Effects, Morning Forest Birds>", LEVEL = 0.18, FROM = ?, TO = ?, CLIP_SECONDS = ? },
            { WHAT = "wind",  ID = "<Pro Sound Effects, Leaves Rustle Wind Blowing Through Trees 1>", LEVEL = 0.10, FROM = ?, TO = ?, CLIP_SECONDS = ? },
        } },
        hunt = { WORD = "hunt", VOICES = {
            { WHAT = "forest", ID = "", LEVEL = 0.20, FROM = 0, TO = 0, CLIP_SECONDS = 0 },
        } },
    },
}
```

**The hunt bed ships with an empty id, deliberately, and that is not a stub.** In the Forest Test
place the hunt's forest ambience already exists and is Karen's `Workspace.Ambience` at 0.50, which
brief decision 4 forbids this owner from touching. A second global forest layer during the drive
would double a bed nobody in git owns. So what the crossfade does today is exactly what Karen asked
for — *at the lodge*, quiet birds and wind over the place's own forest; *during the drive*, the
place's own forest alone — and the hunt bed is a row she fills the day she wants the drive to sound
different, with no code change. An empty id plays nothing and is not an error: the standing rule, with
its reason, at `src/client/Weapon/Sound.luau`'s `play` (*"a gun that is silent is the gun this repo
has had all along; a warn per shot would be worse than the silence"*) and again twice in
`src/client/Hud/Sound.luau` (`played.silent`).

**The three `?` are measurements, not open decisions.** The Builder fills each from the same place
`Horn.CONFIG.SIGNAL.PHRASES`' numbers came from: re-run the brief's own sweep
(`apis.roblox.com/toolbox-service/v1/marketplace/audio`, filtered to licensed partners) for the two
named creators and takes, then measure `Sound.TimeLength` and a `PlaybackLoudness` peak per 0.05 s
bucket in a Play session at `Volume = 0.0001`, exactly as task 166 measured the two bugle phrases, and
write the measurement in the comment above the row. If a take will not load, **the row ships with
`ID = ""`**: the module, the machine, both specs and the whole of this design still build and still
pass, and the one thing missing is a sound nobody here can hear anyway (brief decision 6). That is why
this design is buildable as written rather than blocked on an id.

`FROM`/`TO` give each take its own loop window. The engine's own way of doing that is
`PlaybackRegionsEnabled` + `PlaybackRegion` + `LoopRegion`, and **this repo already uses it**:
`src/server/Lobby/Build.luau`'s `engineSound`, with the reason written beside it — *"the alternative,
`TimePosition` with a `Looped` sound, replays from zero and so would re-start the engine on every
pass"*. Borrowed from there, same three lines. A row with `TO == 0` gets `Looped = true` and no region
at all, which loops the whole clip.

### 6.4 No feature flag

`src/shared/Flags/init.luau` is not used here. Reason: the flags section exists so a feel-critical
path can merge dark without a playtest in the merge gate, and the off state the flag would provide
**already exists in the data** — `LEVEL = 0`, or `ID = ""`, one row each, the content lane's own
switch. A flag on top would be a second answer to "is the bed on", which is the thing rule 3 exists to
prevent, and the section's own test (*"a flagged path must be reachable by parameter as well as by
flag"*) is satisfied without one: `applyTeam` takes the team as a parameter and `step` takes the
clock. The Director may overrule this; it is one row and one boundary read in `start()`.

Nor is this the **content lane** in the `poses.json` sense: the brief's decision 5 says the numbers
live as Luau rows, and a JSON data file would need a `tools/pose.py`-shaped live-tuning instrument
that does not exist for it. So a level change is an engineering-lane commit, which for a two-number
diff is cheap.

---

## 7. What it reads, what it writes, and who owns each

### Reads (never writes)

| Thing | Owner | Where read |
|---|---|---|
| `Players.LocalPlayer.Team` | `ServerScriptService.Match` (`src/server/Match/init.luau`, `Roster.assign`); the engine replicates it | `refresh()` only |
| `Players.LocalPlayer:GetPropertyChangedSignal("Team")` | engine | `Ambience.start()` only |
| `ReplicatedStorage.Ambience.CONFIG` | nobody at run time (frozen shared data) | module load, `step` |
| `Drive.TEAMS` (`src/shared/Drive/init.luau`) | nobody at run time (`table.freeze`) | `Ambience.bedFor` |
| `RunService.Heartbeat` | engine | `Ambience.start()` only |
| `ContentProvider:PreloadAsync` | engine | module load, in its own `task.spawn`, inside a `pcall` |

### Writes

| Thing | Properties written | Who else may |
|---|---|---|
| `SoundService.Ambience_<bed>_<what>` (`Sound`, at most 4) | `Name`, `SoundId`, `Looped`, `PlaybackRegionsEnabled`, `PlaybackRegion`, `LoopRegion`, `Parent` at module load; `Volume` every frame | **nobody.** No other module in `src/` creates, finds or writes an instance of that name |

Writes nothing else. No `Instance` outside those Sounds, nothing drawn, no attribute, no remote, no
`task.wait` in the owner's own code path, no `Lighting`, no `Workspace`.

---

## 8. The owner boundary against the five existing sound writers, and against `SoundService`

| Module | What it owns | Why it is not this |
|---|---|---|
| `src/client/Hud/Sound.luau` (`Sound.tick`, `Sound.driveSignal`, `makeSignalVoice`) | the Hud's 2-D feedback cues: the hit tick, and the drive's bugle at start and end. Instances `DriveSignal_start` / `DriveSignal_end` in `SoundService`, `Looped = false`, `Volume = Horn.CONFIG.SIGNAL.VOLUME` | **cues, not a bed.** Its header scopes it to *"the Hud's own 2-D feedback sounds"*. Section 3.1 |
| `src/client/Weapon/Sound.luau` (`play`, `cutAfter`) | the gun's voices for the local player: shot, open, close, bolt, magazine, load, dry. One short-lived `Sound` per event in `SoundService`, `Debris:AddItem(made, 8)` | **one-shots it creates and destroys.** `cutAfter` writes `Volume` only on a Sound it made and is about to `Destroy` |
| `src/server/Boar/Body.luau` (`makeSound`) | the animal's voice: positional, parented into the body, with `RollOff*`, an equalizer and a pitch shift | **server-side and positional.** A bed has no body to hang on |
| `src/server/Lobby/Build.luau` (`engineSound`) | the truck's engine: positional, on the rig, `RollOffMode.InverseTapered`, `PlaybackRegion`/`LoopRegion` | **server-side and positional.** This design *borrows its loop-window pattern* and owns none of its instances |
| `src/server/Weapon/Horn.luau` | the beater's blast: one `Sound` named `Horn.SOUND_NAME` parented to the Tool's `Handle` — *"which is what makes it 3D"* | **server-side and positional**, and it is a cue |

**The line, stated once:** this owner is the only module in the repo that creates a `Sound` that is
**looped, global (parented to `SoundService`, never to a part), and alive for the whole session**, and
the only one that writes `Sound.Volume` after creation on an instance it does not immediately destroy.
Every existing writer is either positional or a one-shot. No instance name collides:
`Ambience_lodge_birds`, `Ambience_lodge_wind`, `Ambience_hunt_forest` against `DriveSignal_start`,
`DriveSignal_end`, `Horn.SOUND_NAME` and the unnamed one-shots.

**`SoundService` itself keeps no owner, by decision.** Nothing in `src/` writes a `SoundService`
property today (section 0) and this module must not be the first. `AmbientReverb` and
`SoundService.Volume` are *global* answers: a bed that set them would change the gun, the boar, the
horn and the bugle, and "how loud is the game" would have a writer that thinks it is only the lodge's
birds. If the game ever needs a master mixer it is its own system with its own design and its own row
in `GAME_DESIGN.md`.

**`Workspace.Ambience` keeps no owner in git, and that is a hole this design records rather than
fills.** Brief decision 4 puts it out of reach, correctly, for this task. It is in the open decisions
(section 12, D2).

---

## 9. External sources

Rule 1's 3+, named and linked, with licence and maintenance status. These are the design's sources;
the Builder must still write the research note (section 11).

**A. Roblox engine reference — `Sound`, `SoundService`, `ContentProvider`, `Instance`.**
<https://create.roblox.com/docs/reference/engine/classes/Sound> ·
`#Volume` · `#Looped` ·
<https://create.roblox.com/docs/reference/engine/classes/Sound#PlaybackRegion> ·
`#LoopRegion` · `#PlaybackRegionsEnabled` ·
<https://create.roblox.com/docs/reference/engine/classes/SoundService> ·
<https://create.roblox.com/docs/reference/engine/classes/ContentProvider#PreloadAsync> ·
<https://create.roblox.com/docs/reference/engine/classes/Instance#GetPropertyChangedSignal>
*Licence:* content CC BY 4.0, code samples MIT, in `github.com/Roblox/creator-docs`.
*Maintenance:* actively maintained by Roblox staff, continuous commits.
*Well:* authoritative on exactly the properties this design turns — that a `Sound` with no `BasePart`
ancestor is non-positional, that `Volume` is `0..10`, and that `PlaybackRegion`/`LoopRegion` need
`PlaybackRegionsEnabled`. *Badly:* it documents properties, not systems. It says nothing about
crossfading, about layering a bed, or about what a bed's level should be relative to anything else, and
the `PlaybackRegionsEnabled` caveats are thin. **Adopted:** the non-positional-`SoundService` parenting
(already this repo's rule in both client sound modules), the loop window via the two region
properties, and `PreloadAsync` at module load — the last one verbatim from `Hud.Sound`'s own
task 163a(a) fix, which is cited in that file against the same doc page.

**B. Valve — Source engine *Soundscapes*.** <https://developer.valvesoftware.com/wiki/Soundscape>
*Licence:* Valve Developer Community wiki text, CC BY-NC-SA 2.5 — documentation only, no code is taken.
*Maintenance:* community-maintained, still edited; the engine itself is legacy but shipped a dozen
titles on this system.
*Well:* it is the oldest widely-shipped formulation of exactly this problem, and it names the three
rules this design uses. **Exactly one soundscape is active at a time**; a soundscape is a **named set
of looping layers each with its own level**; and **the client mixes it**, crossfading when the active
soundscape changes rather than cutting. It also names the failure mode — overlapping soundscapes
stacking into mud — which is invariant I1.
*Badly:* it is driven by world **triggers and entities** (`env_soundscape` with a radius and a line of
sight), which is a position measurement and is forbidden here by brief decision 2 and section 2.3;
and its layers are `.txt` script files for a C++ mixer, so there is nothing to copy.
**Adopted:** "one active bed, layers with per-layer level, the client crossfades" — sections 5.1–5.3.
**Not adopted:** the trigger. Our trigger is one replicated fact (section 4), which is strictly better
here because it cannot disagree with who is in the drive.

**C. Firelight Technologies — FMOD Studio mixing: snapshots and parameters.**
<https://www.fmod.com/docs/2.02/studio/mixing.html> ·
<https://www.fmod.com/docs/2.02/studio/parameters.html>
*Licence:* proprietary (FMOD End User Licence Agreement; free for indie under a revenue threshold).
Documentation is public; no code or tool is used.
*Maintenance:* actively maintained commercial product, versioned docs.
*Well:* it is the industry's formalisation of "one scalar drives a whole mix state": a parameter in
`[0, 1]` scales a bus, the bus scales its layers, and **the game code writes the parameter, never the
individual volumes**. That one sentence is sections 5.2 and 6.2 — `applyTeam` writes a target,
`step` writes the gain, and `volumeFor(gain, LEVEL)` is the only place a `Volume` number is produced.
It also names the anti-pattern explicitly: many systems writing individual event volumes, which is the
*"three scripts set the mouse cursor"* failure in `docs/PROJECT_CONTEXT.md` with sound instead of a
cursor.
*Badly:* proprietary, unusable in Roblox, and the whole value is in a mixer graph and an authoring
tool we do not have. Its parameter model also assumes seek/snapshot interpolation curves we are not
building — our fade is linear in gain, which section 12 K2 flags for Karen's ear.
**Adopted:** the gain/level split and "the game writes one scalar per bed".
**Not adopted:** anything else.

**D. Quenty — NevermoreEngine.** <https://github.com/Quenty/NevermoreEngine>
*Licence:* MIT. *Maintenance:* actively maintained, Wally-published, hundreds of packages, the most
widely used open-source Roblox framework.
*Well:* it is the Roblox-native prior art for sound lifetime management, and reading it is what
settled section 5.3 against tweens: its utilities are built around explicit, disposable, single-owner
objects rather than fire-and-forget property animations.
*Badly:* every package assumes the whole framework — `ServiceBag`, `Binder`, its Promise
implementation, its Maid — so taking one would add a dependency stack and a second DI idiom to a repo
that has neither, for two `Sound` instances and one `Heartbeat`.
**Not adopted, and this is rule 2's written reason:** the borrowed thing here is the *pattern* (one
owner, explicit lifetime, no implicit property animator), not the code. Pulling in a framework to own
four `Volume` writes a frame would be the opposite of "borrow before building".

**E. Roblox's newer audio API — `AudioPlayer`, `AudioEmitter`, `AudioListener`, `Wire`.**
<https://create.roblox.com/docs/audio> · same licence and maintenance as source A.
**Considered and rejected, deliberately.** It is a genuinely better mixer-graph model and is where
Roblox audio is going, and it is still the wrong choice today: all five existing sound writers in this
repo are classic `Sound` instances, and a bed on the new stack would mean **two audio architectures in
one game** — two answers to how anything is routed, which is rule 3 broken at the architecture level
rather than the module level. Migrating the whole game's audio to it is a system-sized task with its
own design, and is logged for the Director (section 12, D3).

---

## 10. Numeric targets

| # | Target | How it is checked |
|---|---|---|
| N1 | **At most 4** `Sound` instances for the whole system, for the whole session. Shipped data makes **2** (lodge birds, lodge wind); the hunt row's id is empty, so it makes none | client spec counts `Ambience.voices("lodge")` + `Ambience.voices("hunt")`, and counts `SoundService` children whose name starts `Ambience_` |
| N2 | Created **once, at module load**, before `start()` and before any state change. `Ambience.ready()` returns `madeAtLoad == true` | client spec, the `Hud.Sound.signalReady` shape |
| N3 | **`FADE_SECONDS = 2.5`.** A target flip completes in `<= 2.5 s + 1 frame` | server spec: `stepGain` from 0 to 1 at `dt = 1/60`, 150 iterations, reaches 1.0 |
| N4 | **Frame-rate independent:** stepping 2.5 s of fade at `dt = 1/30`, `1/60` and `1/144` lands within `1e-6` of the target in all three | server spec |
| N5 | **No overshoot, no undershoot:** `stepGain` output is always in `[0, 1]`, monotone toward the target, and `dt >= fadeSeconds` lands exactly on the target | server spec, including `dt = 1e6` and `dt = 0` |
| N6 | Shipped levels: **lodge birds `0.18`, lodge wind `0.10`.** Both below `Workspace.Ambience`'s measured `0.50`, and far below the drive signal's `3` (`Horn.CONFIG.SIGNAL.VOLUME`) so a bed can never mask the bugle | server spec asserts `LEVEL < 0.5` for every lodge voice and `rowsOk` |
| N7 | **Loudness target (the measurement, not a guess):** at full gain the lodge bed's combined `PlaybackLoudness` peak is **25–40 %** of `Workspace.Ambience`'s own peak at its `0.50`, sampled at `Heartbeat` rate, peak per 0.05 s bucket, at `Volume = 0.0001` — the method `Horn.CONFIG.SIGNAL` used. **If a take lands outside that band, the two `LEVEL` rows move, never the code** | Builder's measurement, written into the comment above each row. Not spec-assertable: `PlaybackLoudness` needs a Play session and a loaded asset |
| N8 | **Loop window `>= 20 s`** for every bed voice, so an audible repeat happens at most 3 times a minute. The brief's takes (36–75 s birds, 76 s and 87 s wind) all clear it | server spec: `loopWindow` span `>= 20` for every non-empty row |
| N9 | Both voices requested in **one** `ContentProvider:PreloadAsync` call, issued in the frame of module load, in one `task.spawn`, inside a `pcall`. `Ambience.ready()`'s second return is true within **10 s** in the harness, and `Sound.IsLoaded` is true for every non-empty row | client spec, bounded wait; `IsLoaded` recorded, and a failure reported rather than asserted (N9a below) |
| N9a | A take that does not load leaves the bed **silent, not broken**: `madeAtLoad` stays true, `step` still runs, `Volume` is still written, no error and no `warn` per frame | client spec: a loaded-ness failure is reported, never a spec failure (rule 8) |
| N10 | **One `RunService.Heartbeat` connection** for the whole system. Zero `RenderStepped`, zero remotes, zero `BindableEvent`, zero `task.wait` in the owner's own code | review of the source; `Ambience.stop()` then `start()` twice leaves exactly one connection (the `started` guard, `Match.start`'s shape) |
| N11 | **`Ambience.step` allocates no table** and performs at most 4 `Volume` writes per frame | source review; `stats().stepped` proves it ran |
| N12 | `volumeFor` clamps to the engine's `Volume` range `[0, 10]`; `rowsOk` refuses a `LEVEL` outside `(0, 10]` | server spec |
| N13 | Invariant I1: for every input to `targetsFor` — each bed word, `nil`, `""`, an unknown word — exactly one target is 1, the rest 0, and the sum is 1 | server spec |
| N14 | Invariant I2: `Ambience.step(0)` after any `applyTeam` changes no gain and no `Volume` | client spec |
| N15 | `arrived` increments **once** per completed fade, not once per frame at the target | client spec |

---

## 11. How it is tested

Nobody here can hear it (brief decision 6). What is proved is what reaches the engine; **Karen's ears
decide** whether it is right.

### 11.1 Server spec — `tests/server/ambience.spec.luau`

Pure, no Sound, no clock, no player. Requires `ReplicatedStorage.Ambience`.

* `rowsOk(Ambience.CONFIG)` is true — and `rowsOk` is itself driven with hand-built bad configs for
  each named refusal: a `LEVEL` of 0, of 11, a `TO` past `CLIP_SECONDS`, a crossed `FROM`/`TO`, a
  duplicate `WHAT`, a missing bed, an unknown bed key, `FADE_SECONDS = 0`. A checker nobody has shown
  can fail is not evidence.
* `bedFor`: `"Shooters"` → `"hunt"`, `"Drivers"` → `"hunt"`, `nil` → `"lodge"`, `""` → `"lodge"`,
  `"Spectators"` → `"lodge"`, `"shooters"` (wrong case) → `"lodge"`.
* `bedFor` reads `Drive.TEAMS`: the spec asserts the two words it answers `"hunt"` for are exactly
  the keys of `Drive.TEAMS`, so a rename on one side cannot pass.
* `targetsFor`: N13, for every input.
* `stepGain`: N3, N4, N5; `fadeSeconds <= 0` is instant; `target == gain` is a no-op.
* **Mid-fade flip (section 5.3):** step 1.0 s toward `hunt`, flip the targets, assert the gains are
  unchanged by the flip, then step and assert each moves the *other* way from where it was, and that
  both stay in `[0, 1]` across 20 alternating flips.
* `volumeFor`: N12, and `volumeFor(0, level) == 0`.
* `loopWindow`: `TO == 0` resolves to `CLIP_SECONDS`; N8.
* `Ambience.CONFIG` and `BED_WORDS` are frozen (`table.isfrozen`), the rule `Drive.TEAMS` and
  `Drive.CONFIG` already keep.
* **Negative:** the source of `src/shared/Ambience/init.luau` contains no `SoundService`, no
  `Instance.new`, no `game:GetService` — the shared half is data and arithmetic.

### 11.2 Client spec — `tests/client/ambience_client.spec.luau`

Runs in the player's client, in the DEV arena, where there is no lodge and no lobby.

`beforeAll`: `local Ambience = require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Ambience"))`,
then **`Ambience.stop()`** — so the live `Team` signal and the live `Heartbeat` are detached and the
spec is the only writer of `targets` and the only driver of the clock. This is the section 5.5
false-PASS guard: in the DEV place a real drive assigns the harness player a team mid-run, so a spec
that read the ambient state would pass or fail on the phase. `afterAll`: `Ambience.start()`.

* **The Instances.** `Ambience.ready()` → `madeAtLoad == true` (N2). For every non-empty row:
  the Sound exists, `Name == Shared.voiceName(bed, voice)`, `SoundId == voice.ID`,
  `Looped == true`, `Parent == SoundService`, and — the non-positional assertion, stated as a
  negative — **no ancestor is a `BasePart` or an `Attachment`**. For every empty row: no Sound, and
  `stats().silent` counted it.
* **The count.** N1, both ways: `Ambience.voices` and a scan of `SoundService` children named
  `Ambience_*`.
* **The loop window.** `PlaybackRegionsEnabled`, `PlaybackRegion` and `LoopRegion` equal
  `NumberRange.new(loopWindow(voice))` for a row with `TO > FROM`; for a row with `TO == 0`,
  `PlaybackRegionsEnabled == false`.
* **The preload.** Bounded wait up to 10 s for `Ambience.ready()`'s second return (N9). `IsLoaded`
  per voice is **recorded in the report, not asserted** — a moderated or network-starved asset must
  not fail the suite (N9a, rule 8) — and the spec *does* assert that an unloaded voice still gets its
  `Volume` written.
* **The state machine through the parameter door.** `applyTeam(nil)` → `bed() == "lodge"`,
  `targets().lodge == 1`; `applyTeam("Shooters")` → `"hunt"`; `applyTeam("Drivers")` → `"hunt"`;
  `applyTeam("Spectators")` → `"lodge"`.
* **The Volume is a function of the gain.** After `applyTeam(w)` and `step(dt)` repeatedly, every
  voice's `Volume` equals `volumeFor(gains()[bed], voice.LEVEL)` to within `1e-6`, at every
  intermediate step and at the end.
* **I2 (N14):** `step(0)` changes no gain and no `Volume`.
* **Crossfade end to end, with no yielding clock:** `applyTeam(nil)`, step `2.5 s` in `1/60`
  slices → lodge `Volume` at level, hunt at 0, `arrived` 1. `applyTeam("Shooters")`, step 1.25 s →
  both strictly between (one falling, one rising), then step 1.25 s → lodge at 0, hunt at its level,
  `arrived` 2 (N15).
* **Idempotence:** `start(); start(); stop(); stop()` leaves one connection's worth of behaviour and
  does not reset `gains` (N10).
* **Negative, against section 2:** the source of `src/client/Ambience/init.luau` contains no
  `AmbientReverb`, no `SoundService.Volume =`, no `Workspace`, no `.Magnitude`, no `Vector3`, no
  `Lobby`, no `TweenService`, no `RemoteEvent` and no `Map.EXPECTED_WORLD`. Each of those is a rule in
  section 2 and each is one `string.find` — cheap, and the only kind of assertion that keeps a
  boundary from drifting across the next ten tasks.

### 11.3 Harness input and screenshots

* **Harness input:** N/A. `tests/client/input_scenarios.txt` replays keys, mouse buttons, mouse moves
  and gaps (TASKS.md task 6); the bed has no input. The state change is a `Team` write on the server,
  which the scenario format cannot express and which this spec drives by parameter instead.
* **Screenshot (rule 5):** N/A, with the reason: **nothing drawn changes.** No `ScreenGui`, no
  `Instance` in `Workspace`, no `Lighting`. `python tools/studio_mcp.py capture` is the repo's visual
  evidence tool (TASKS.md task 7) and there is nothing for it to show.
* **What the harness cannot do, named plainly:** **it cannot hear.** There is no audio capture in
  `tools/studio_mcp.py` and none is proposed. Every claim in this design is "what reached the engine".
  Whether quiet birds and a soft wind at the lodge feel *"relax quuiet"*, whether 2.5 s is the right
  fade, and whether the lodge should be this much quieter than the hunt are **Karen's**, in a playtest,
  and the task report must say so (rule 8).
* **`test2`:** N/A. No path here is in `TWO_PLAYER_PATHS`, and a bed is identical with one player and
  two — it is one Instance per client at that client's own ear. `src/client/Ambience/` is a new path,
  so the Builder must confirm `tools/agents.py selftest` agrees rather than assume it.

---

## 12. Harness and docs the Builder must change

**Mandatory, or CI goes red.** `tools/studio_mcp.py` `selftest` fails if a spec file belongs to no
scope, and it runs in CI. Add a scope **`ambience`**:

```python
"ambience": ("tests/server/ambience.spec.luau", "tests/client/ambience_client.spec.luau"),
```

and name `tests/server/ambience.spec.luau` in the **`match`** tuple as well — the dual membership this
table already uses — because `Ambience.bedFor` reads `Drive.TEAMS` and `src/shared/Drive/` resolves to
`match`: a team rename must play the spec that asserts the identity.

**For speed, not for correctness** (an unmapped `src/` path falls through to `all`, which is the
fail-safe, not a failure) — three `BLAST_RADIUS` rows:

```python
("src/shared/Ambience/", "ambience"),
("src/client/Ambience/", "ambience"),
("src/client/AmbienceBoot.client.luau", "ambience"),
```

Also:

* **`docs/research/2026-10-23-ambience.md`** plus its row in `docs/research/INDEX.md`. Rule 1 is the
  Builder's and this design does not discharge it: section 9 is the input to that note, and the note
  must carry the asset ids, the measured `TimeLength` and `PlaybackLoudness` figures (N7), and the
  sweep that produced them.
* **`GAME_DESIGN.md` System owners** — one row, mirroring section 3: *"The ambience bed (the lodge's
  quiet birds and wind, the hunt bed, and the crossfade between them)"* → owner
  `StarterPlayerScripts.Ambience`, the only writer of the `Ambience_*` Sounds in `SoundService` and of
  their `Volume`; location `src/client/Ambience/init.luau`, `src/shared/Ambience/init.luau`,
  `src/client/AmbienceBoot.client.luau`; note the research file. **State in the row that
  `Workspace.Ambience` is Karen's Studio instance and has no owner in git** (section 8, D2).
* **`docs/design/README.md`** — the index entry for this file.
* **Code comments** carry the pattern name, the source links and the research note (rule 9): source B
  for the one-active-bed rule, source C for the gain/level split, `Lobby.Build.engineSound` for the
  loop window, `Hud.Sound`'s task 163a(a) note for the module-load preload.

---

## 13. Open decisions

None of these block building: the design ships a value for every one of them.

**Karen (feel), after a playtest — each is one row:**

* **K1.** The two levels: lodge birds `0.18`, wind `0.10`. Louder, quieter, or one of them gone.
* **K2.** `FADE_SECONDS = 2.5`, linear in gain. A slower fade, or a curve. Source C's parameter
  interpolation is the richer model and we deliberately did not build it (section 9 C).
* **K3.** Whether the **hunt bed should have a voice at all** (section 6.3), given that the Forest
  Test place's own `Workspace.Ambience` already plays through the drive. Ships silent. Filling it is
  one row; it needs the brief's sweep for an id and an N7 measurement.
* **K4.** **Crossfade or duck.** The lodge bed fades to **0** during the drive. If Karen wants the
  birds faintly present out on the line instead, that is not a row — it is a per-voice
  `HUNT_LEVEL` and a change to `volumeFor`, so it is a small engineering-lane task. Deliberately not
  built until she asks for it.
* **K5.** The fade-in from silence on join (section 5.4). A player who joins at the lodge hears the
  bed arrive over 2.5 s rather than being already there.

**Director (scope):**

* **D1.** The scope name `ambience`, the dual membership of `ambience.spec` in `match`, and the three
  `BLAST_RADIUS` rows (section 12). If the Director would rather this sat in the existing `hud` scope,
  say so before the Builder starts — but section 3.1 argues against it on owner grounds as well as
  scope grounds.
* **D2.** **`Workspace.Ambience` has no owner in git.** Brief decision 4 correctly puts it out of
  reach for this task, and the consequence is that the game's loudest ambience is a hand-placed
  instance a Connect cannot restore and no diff records. A later task could own it as
  `src/serverstorage/` content plus a server-side builder, which would need Karen to delete the
  Studio original. Logged, not proposed.
* **D3.** The newer `AudioPlayer`/`Wire` audio API (section 9 E) is where Roblox audio is going, and
  adopting it for one system would give the game two audio architectures. A whole-game migration is
  its own design. Logged.
* **D4.** Section 0's finding: the dispatch's *"volume 3.00"* is `Hud.Sound`'s two `DriveSignal_*`
  voices, not an ambience. If the Director accepts that, the ambience premise in the task 250 dispatch
  and anything downstream of it should be corrected in `TASKS.md`, and `src/client/Weapon/Sound.luau`'s
  task 248 measurement comment should name them for what they are. That is a one-line comment fix in a
  file this task does not otherwise touch — the Director's call whether it rides here or waits.
* **D5.** No feature flag (section 6.4). The off state is a data row. Overrulable.
