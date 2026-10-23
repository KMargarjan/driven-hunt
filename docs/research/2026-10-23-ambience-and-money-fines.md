# The ambience bed, and money as a penalty (task 250)

2026-10-23. Two systems from one dispatch, researched together because both were asked for in one
sentence of Karen's and both needed a pattern this repository did not have.

CLAUDE.md rule 1. The weapon half of task 250 (the semi-auto's voice, the rifle's report, its damage
column and its recoil) is covered by existing notes -- `2026-10-10-rifle-bolt-magazine-sound.md`,
`2026-09-25-hit-zones.md`, `2026-10-01-poses-as-data.md` -- and the measurements it produced are in
the code comments where they are read. This note is the two NEW systems.

---

## 1. What they must do

**Karen, 2026-10-23, verbatim:**

> any lobby music, like birds relax quuiet ? ... and also semiauto same sound like rifle / we need to
> change rifle sound and make more damadge recoil and sound / also we need to make more damadge to
> shooter if shoot baby like take big amount of money and same to person

**The ambience bed.** At the lodge/lobby: quiet birdsong plus a soft wind, calmer and quieter than
the hunt's forest. It crossfades when you leave for the drive and when you come back. One writer. No
positional sound. Nothing uploaded unless the licensed catalogue cannot serve it.

**The money penalties.** Shooting a piglet or a deer calf costs **$500**; a shot that endangers a
person costs **$1000**. Both come **on top of** the existing score penalty (the Director's dispatch).
Shown on the HUD when it happens and in the drive's report. A balance may not go below $0.

---

## 2. THE DISPATCH'S AMBIENCE PREMISE WAS WRONG, and that is finding zero

The dispatch says: *"Find the existing ambience owner (the forest ambience runs at volume 3.00, per
task 248) and add a lodge bed."*

**There is no ambience owner in `src/`, and the 3.00 was not an ambience.** Measured, 2026-10-23:

* `grep -rni "ambien" src/ --include=*.luau` returns only `Lighting.Ambient` reasoning, one
  `MAX_MUTTER_VOICES` comment and the sound owners' own headers. No module plays a bed.
* The only five `Sound` creators in the tree are `src/client/Hud/Sound.luau` (the hit tick and the
  drive's bugle), `src/client/Weapon/Sound.luau` (the gun), `src/server/Boar/Body.luau` (the
  animal), `src/server/Lobby/Build.luau` (a truck engine) and `src/server/Weapon/Horn.luau` (the
  beater's blast). Every one is positional or a one-shot. None is a bed.
* The forest ambience Karen hears is a **Studio-made instance**: probed in the Forest Test's Edit
  session through `<runs-dir>/ftq.py`, the place holds exactly ONE ambience Sound --
  `Workspace.Ambience`, `rbxassetid://4629533497`, `Volume 0.50`, `Looped = true`, playing, parented
  straight to `Workspace`. Nothing in this repository names that id.
* **The "two ambience sounds at volume 3.00" of task 248 were `Hud.Sound`'s two `DriveSignal_*`
  voices** -- the drive's bugle at `Horn.CONFIG.SIGNAL.VOLUME = 3`, made at module load and parented
  to `SoundService`, which is exactly what a `SoundService` scan during Play reports. The Architect's
  design reaches the same conclusion independently (`docs/design/ambience.md` section 0).

So the lodge bed is a **new system with a new owner**, which is why it got an Architect design run
(`docs/design/ambience.md`, PASS at `8e5c3e96`) before any code.

---

## 3. External sources: the crossfade

### A. id Tech 4 (DOOM 3 BFG), `neo/sound/snd_world.cpp` / `snd_emitter.cpp`

GPL-3.0, <https://github.com/id-Software/DOOM-3-BFG>. Maintained as a reference release; not
actively developed.

**Good:** the ambient emitter model is exactly this problem solved once -- a looping emitter whose
*volume* is driven toward a target each frame, the sound never stopped while its gain is zero, and
the gain being the whole truth. `idSoundChannel` keeps the loop running and scales amplitude; a
"stop on silence" rule is deliberately absent because restarting a loop is audible.

**Bad:** everything around it. Its ambience is positional and world-space (`soundShaderParms`,
occlusion, reverb zones), it carries a whole DSP graph, and its fade is expressed in milliseconds
inside a mixer we do not have. The numbers are a 1990s-era indoor shooter's.

**Taken:** the one-active-bed rule, and *never stop a bed* -- with its reason, which is the part a
later task would otherwise undo.

### B. Audiokinetic Wwise -- State-based music/ambience transitions

Proprietary, maintained (the documentation is public:
<https://www.audiokinetic.com/library/edge/?source=Help&id=understanding_states>). Not usable in
Roblox and not borrowed as code.

**Good:** it names the shape. A "state" owns a set of simultaneous layers; changing state
crossfades every layer at once over one transition time; a state change *during* a transition
retargets rather than restarting. That is `applyTeam` writing only the targets, and it is the
decision the design's section 5.3 rests on.

**Bad:** the model is far richer than this game needs -- per-state transition matrices, sync points,
RTPC curves. Adopting the full idea would mean a parameter-interpolation engine for two beds.

**Taken:** the vocabulary (state -> targets, one transition time) and the mid-transition retarget.
Deliberately **not** taken: per-pair transition times and curves (design K2/K4).

### C. OpenTTD, `src/music/` + `src/mixer.cpp`

GPL-2.0, actively maintained, <https://github.com/OpenTTD/OpenTTD>. Already borrowed from in this
repo (`src/shared/Money/init.luau` takes `CurrencySpec`).

**Good:** the clean split between a channel's **own level** and a global **gain** applied over it
(`MixerChannel` volume against the effect/music sliders). That is exactly `Voice.LEVEL` against the
bed's `gain`, and it is the reason this design has two numbers per voice rather than one: a single
number cannot express "half way into a quiet bed".

**Bad:** its fade is a music-track fade-out in fixed steps per mixer tick, tied to its own sample
rate -- not frame-rate independent and not reusable here.

**Taken:** the level/gain split, and the rule that the level is data and the gain is state.

### D. Roblox's own engine API

<https://create.roblox.com/docs/reference/engine/classes/Sound#PlaybackRegion>,
<https://create.roblox.com/docs/reference/engine/classes/ContentProvider#PreloadAsync>.

The loop window is `PlaybackRegionsEnabled` + `PlaybackRegion` + `LoopRegion`, which **this
repository already uses** in `src/server/Lobby/Build.luau`'s `engineSound`, with the reason written
beside it there: *"the alternative, `TimePosition` with a `Looped` sound, replays from zero and so
would re-start the engine on every pass"*. Borrowed from our own code rather than re-derived.

### E. Rejected: `TweenService`, and the new `AudioPlayer`/`Wire` API

A tween on `Sound.Volume` would make the engine a **second writer** of a property this owner
believes it owns, and two overlapping tweens on a mid-fade flip is this project's named cause of
death (*"two correct pieces of code disagreeing"*, `docs/PROJECT_CONTEXT.md`). One `Heartbeat`, one
`step`, one `Volume` write per voice instead.

Roblox's newer `AudioPlayer`/`AudioEmitter`/`Wire` graph is where the platform's audio is going, and
adopting it for one system would leave the game with two audio architectures. A whole-game migration
is its own design (the Architect logs it as D3).

### F. Negative result, recorded as such

**No source gives a fade length for this.** None of A, B or C states a number for "how long should
an ambience crossfade take when a player walks out of a lodge into a wood". `FADE_SECONDS = 2.5` is
mine, reasoned from this game: a truck ride out of the lodge is seconds, and anything under about a
second reads as a switch. It is Karen's to turn and it is one row (design K2).

---

## 4. The takes: swept, then MEASURED

**No audio was uploaded and none was needed.** Karen's OK of 2026-10-23 covers CC0 uploads for four
sounds; it permits them, it does not require them, and the licensed catalogue carried every one.
Recorded plainly because it is a decision and not an omission:

* `tools/roblox_upload.py` implements **Model and Decal only** -- its own selftest asserts that
  `Audio` is refused -- so the upload route would have needed a tool change (new content types, a new
  selftest case) on top of a four-item task.
* Roblox-provided **licensed library audio** needs no upload, carries no licence risk, cannot be
  moderated away under us, and is the route six previous tasks in this repo took (142, 152, 163, 166,
  183, 204). Every id below is by a licensed partner, verified by creator through the public
  `toolbox-service` details endpoint.
* A CC0 upload remains available the day a take here is not good enough. The Audio route would have
  to be added to the tool first, and that is queued rather than hidden.

**The sweep.** `https://apis.roblox.com/toolbox-service/v1/marketplace/audio?keyword=<k>` returns
ids; `.../v1/items/details?assetIds=<ids>` returns name, artist and duration. Filtered to licensed
partners (`Pro Sound Effects`, `Audioscape`, and the other first-party packs), because an unfiltered
search for "hunting rifle" is almost entirely user re-uploads of Call of Duty, Fortnite, PUBG and
Cry of Fear audio -- none of it ours to ship, which is the same finding
`2026-10-10-rifle-bolt-magazine-sound.md` section 4 recorded.

**The measurement.** In a Forest Test **Play** session, on the **CLIENT**: a `Sound` per id,
`ContentProvider:PreloadAsync`, then `IsLoaded`, `TimeLength`, and `PlaybackLoudness` sampled at
`Heartbeat` rate as a peak and a mean. **On the SERVER every loudness reads 0.0** -- the first run of
this measurement was thrown away for exactly that reason, and it is written down here because it will
catch somebody again.

| id | name (artist) | len s | peak | mean | used for |
|---|---|---|---|---|---|
| 9116970949 | Morning Forest Birds 6 (Pro Sound Effects) | 75.20 | 23.6 | 16.7 | **lodge birds** |
| 9116258071 | Leaves Rustle Wind Blowing Through Trees 1 (PSE) | 75.77 | 7.1 | 3.7 | **lodge wind** |
| 9116971174 | Morning Forest Birds 1 (PSE) | 36.01 | 22.5 | 15.1 | rejected: shorter |
| 9116969466 | Morning Birds 2 (PSE) | 36.01 | 18.0 | 5.1 | rejected: mean 5.1 of peak 18 is a few calls with silence between them, not a chorus |
| 9116258282 | Leaves Rustle Wind 2 (PSE) | 87.38 | 5.7 | 0.5 | rejected: a recording of a wind that mostly was not blowing |
| 9112781510 | Forest Ambience 1 (PSE) | 36.01 | 1.1 | 0.9 | rejected: nearly silent |
| 4629533497 | `Workspace.Ambience` (Karen's own, at 0.50) | 117.59 | 7.9 | 6.0 | the thing the lodge is measured against |
| 106454770387605 | AS_shotgun_shot-03 (Audioscape) | 0.92 | 86.9 | 19.6 | **the semi-auto's shot** |
| 99008924129683 | AS_shotgun_shot-01 (Audioscape) | 0.92 | 85.3 | 19.2 | the side-by-side's, unchanged |
| 82409501948316 / 84039532799719 | AS_shotgun_shot-02 / -04 | 0.92 | 76.0 / 84.3 | 15.2 / 19.1 | the other two takes of the family |
| 9114725315 | Gun Retort 1 (PSE) | 4.95 | 603.6 | 30.1 | **both rifles**, kept -- see below |
| 9118173739 | Rifle Single Shots 1 (PSE), the Barrett | 3.36 | 257.7 | 11.4 | rejected in task 183, re-measured here |
| 9118174270 / 9118174271 / 9118174539 | Rifle Single Shots 6 / 7 / 8 | 3.68 / 3.70 / 3.40 | 250.6 / 260.3 / 258.5 | 11.8 / 14.4 / 22.5 | rejected: quieter AND shorter |
| 128650101411844 / 86903016850225 / 72333449737130 | AS_rifle_shot-01 / -03 / -04 | 0.35 | 86.4 / 92.4 / 77.4 | 7.3 / 8.4 / 6.8 | rejected: 0.35 s is a dry crack with no roll |

**All 21 ids load** (`IsLoaded == true`), which is the engine-side fact an asset id is proved by -- not
a moderation state and not the upload call succeeding.

### 4.1 Why the rifle's RECORDING did not change, and what did

Karen asked to change the rifle's sound. The sweep says the sample it already has is **2.3x the peak
and 1.3x the length of every alternative in the licensed catalogue**. Swapping the recording would
make the rifle quieter and shorter.

What was wrong was the **cut**. The loudness profile of `Gun Retort 1`, peak per 0.1 s on the client:

```
t  0.0  0.1  0.2  0.3  0.4  0.5  0.6  0.8  1.0  1.2  1.5  1.8  2.1  2.4  2.8  2.9+
L  442  204   59   38   26   18   14   12   10    8    6    4    2    2    1    0
```

ONE bang at t=0 and a smooth decay to silence at 2.8 s. There is no doublet -- the old comment's
worry that *"Gun Shot**s**" is a TAKE, not a round* is unfounded for this clip, and it was cutting at
2.0 s against that worry. At `pitch = 0.88` a 2.0 s cut is **1.76 s of source**, with the fade
starting at 1.06 s: the rifle was fading its own roll out from loudness 11 and cutting it dead at 4.
**The last second of the report was never heard.** `cut = 3.45, fade = 0.55` at `pitch = 0.82` plays
2.83 s of source and fades only where the sample is at 2 of 442.

### 4.2 Why the lodge's levels are below the design's first pick

`docs/design/ambience.md` N7 asks for the lodge bed at 25-40 % of `Workspace.Ambience`'s loudness and
suggests `0.18` / `0.10`. Computed against the takes that were actually chosen, those give
`0.18 x 16.7 + 0.10 x 3.7 = 3.38` against the forest's `0.50 x 6.0 = 3.00` -- **113 %**, not 25-40 %:
at 0.18 the birds alone would be as loud as the whole wood. `0.055` and `0.030` give
`0.92 + 0.11 = 1.03`, which is **34 %**. The design's band was right and its numbers were a guess
made before the takes were measured; the band is what was kept.

---

## 5. External sources: money as a penalty

### A. ioquake3, `code/game/g_combat.c` + `g_team.h`

GPL-2.0, maintained, <https://github.com/ioquake/ioq3>. Already borrowed from in this repo
(`Match.Score`'s support-award rule and `Drive.Rank`'s `RANK_TIED_FLAG`).

**Good:** the shape of a self-inflicted penalty. A team kill subtracts from the killer's score and
from his alone -- never from the assisters, never from the team -- and it is one constant in one
place. That is `Score.kill` charging the **killer** and nothing else, which is Karen's *"more damadge
to shooter"* read literally.

**Bad:** it has one currency. Score IS the money in Quake 3, so it has nothing to say about the
question this task actually turns on.

### B. OpenTTD, `src/economy.cpp` -- `SubtractMoneyFromCompany` and `EXPENSES_*`

GPL-2.0, maintained. **This is the source for the decision that mattered**: a fine is booked as a
**flat cash expense** against the balance, in its own expense category, and is *never* expressed in
the scoring/rating currency. Company rating and company money are two numbers that move for
overlapping reasons and are never converted into each other.

**Taken:** `Match.CONFIG.FINE` is a **sibling** of `POINTS`, not a field inside it, and
`Coins.forRow` subtracts dollars **flat** rather than through `COINS_PER_POINT`. Folding $500 into
points would let an exchange rate decide the size of the fine, and would also move the man five
hundred places down the board.

**Bad / not taken:** OpenTTD lets a company go bankrupt and OpenTTD's loan mechanics. Karen's rule is
a floor at zero, which this game already has (`Economy.CONFIG.FLOOR`) and which the design of task
170 already argued for.

### C. The DJV's *Jagdhandwerk* conventions, and German hunting-lease practice

The real-world rule this is a model of: shooting a *Frischling* (a piglet) or a *Kalb* out of order is
a **monetary** penalty against the hunter's lease -- a fixed sum per animal, published in advance,
separate from whether he is invited back. Not a code source and not a numeric one: no published
tariff maps to a Roblox drive's economy. It is cited because it is why the fine is money and the tie
to a tree is the social penalty, and the two are not substitutes.

**Negative result:** no source gives the figures. **$500 and $1000 are the Director's**, from the
dispatch, and their size was checked against this game rather than against a source: at
`COINS_PER_POINT = 2` and `PARTICIPATION = 10` a clean drive pays $40-$80, so $500 is five to twelve
drives' earnings and $1000 is twice that. That is what makes it *"a big amount of money"* and it is
the pair of numbers Karen is most likely to want moved -- which is why each is one row.

---

## 6. The patterns adopted, and why

| Decision | Pattern | Source | Why not the alternative |
|---|---|---|---|
| One active bed, two gains, never stopped | ambient emitter with a driven gain | A | Stopping a silent bed puts an audible restart at the far end of every crossfade, and "is it playing" becomes a second place the truth lives |
| A flip mid-fade is a pure retarget | state transition | B | A cancel/restart needs a latch and an edge, both of which can be missed |
| `LEVEL` (data) x `gain` (state) | channel level vs mixer gain | C | One number cannot express "half way into a quiet bed" |
| `PlaybackRegion` + `LoopRegion` | the engine's own loop window | D, and our own `Lobby.Build.engineSound` | `TimePosition` on a looped Sound replays from zero |
| No `TweenService` | -- | E | A second writer of `Volume` |
| The fine is a sibling currency, subtracted flat | flat cash expense vs rating | B | A fine inside `POINTS` has its size set by an exchange rate and wrecks the ranking |
| The fine lands on the killer alone | team-kill penalty | A | *"more damadge to shooter"*; an assist and a push are not the shot being punished |
| The damage column is chosen by the WEAPON, by the ANIMAL | -- | `docs/design/hit-zones.md` 3.1 | The ammo word cannot tell a bullet from a slug, and renaming it is ~300 lines across 25 spec files |

---

## 7. Numeric targets

| # | Target | Where it is checked |
|---|---|---|
| T1 | `FADE_SECONDS = 2.5`; a flip completes in <= 2.5 s + one frame | `tests/server/ambience.spec.luau` |
| T2 | Frame-rate independent to 1e-6 at 30, 60 and 144 fps | same |
| T3 | Gains never leave [0, 1], never overshoot, land exactly on the target | same |
| T4 | Exactly one target is 1, always (invariant I1) | same |
| T5 | At most 4 bed `Sound`s for the session; shipped data makes 2 | `tests/client/ambience_client.spec.luau` |
| T6 | Every bed voice loops >= 20 s, so an audible repeat is at most 3x a minute | server spec |
| T7 | Lodge bed at 25-40 % of `Workspace.Ambience`'s measured loudness: **34 %** | section 4.2; the levels are asserted < 0.5 each and < 0.5 together |
| T8 | Every voice's `Volume` == `volumeFor(gain, LEVEL)` at every step | client spec |
| T9 | Rifle: `cut * pitch >= 2.8 s` of source, so the whole measured tail plays | `tests/server/rifle.spec.luau` |
| T10 | The semi-auto's shot id is not either rifle's and not the side-by-side's | `tests/server/semiauto.spec.luau` |
| T11 | Rifle shots-to-kill, body zone: boar 2 -> 1, deer 3 -> 1 (a deer body slug was a GRAZE) | `tests/server/boar_wound.spec.luau` |
| T12 | A gun with no `DAMAGE_BY_WEAPON` row is bit for bit unchanged | same |
| T13 | A fine is subtracted flat, not through `COINS_PER_POINT` | `tests/server/economy.spec.luau` |
| T14 | A $1000 fine takes the drive negative and the balance to exactly 0, never below | same |
| T15 | The HUD line is `Money.signed` + the dot + the word, and never `$-500` | `tests/client/report_panel.spec.luau` |

---

## 8. What nobody here can verify

**The Builder cannot hear.** There is no audio capture in `tools/studio_mcp.py` and none is proposed.
Every claim about a sound in this task is *what reached the engine*: the Sound exists, it loaded, it
is playing, its id, and its resolved `Volume` and `PlaybackSpeed`.

**KAREN'S EARS DECIDE** whether the semi-auto now sounds like a shotgun, whether the rifle's longer
roll is the *"more sound"* she asked for, whether the lodge's birds and wind are *"relax quuiet"*, and
whether 2.5 s is the right crossfade. Each of those is one data row.

**Karen also decides the two figures.** $500 and $1000 are the Director's defaults from the dispatch,
not hers, and section 5's last paragraph is the arithmetic she would want before moving them.
