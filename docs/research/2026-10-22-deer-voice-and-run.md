# The red deer's voice, its running, and how much it takes (task 240)

**2026-10-22.** Karen, after playing the Forest Test, verbatim:

> deer sound has to bee when hit now it seems it's pig sound when I hit deer / deer running is a bit
> odd and seems it hitting trees be sure all correct and nice / deer need more hits before die a bit
> more like 20% more

Three sentences, three systems. This note covers all three because they are one playtest and because
two of them turn out to have the **same cause**: task 223 built the red deer by borrowing the boar's
tables, and in two places the borrowed thing is wrong for a different animal.

Design: `docs/design/red-deer.md`. Code: `src/server/Boar/init.luau` (`SOUND.VOICE`, `KINDS`,
`SPECIES.reddeer`, `Boar.avoidRadius`, `Boar.speciesConfig`).

---

## 1. What the three systems must do

1. **The voice.** A hit, hurt or dying deer must sound like a deer. No boar sample on a deer, for
   any of the three kinds, on any of the three cues a voice has (`cry`, `death`, `grunt`). The id
   must be one data row so Karen or the Director can swap it without a code change.
2. **The running.** At the speed a deer actually bolts it must be *drawn* running, its feet must
   keep time with the ground, and it must not go through tree trunks.
3. **The toughness.** A deer must take about 20 % more punishment than it does today, with the
   shots-to-kill stated before and after.

---

## 2. Sources

### 2A. What a red deer actually sounds like

| Source | Licence / status | What it is good for | What it is bad for |
|---|---|---|---|
| [countydeerstalking.co.uk, "Deer Vocalisations"](https://www.countydeerstalking.co.uk/blog/deer-vocalisations) | Editorial, a UK deer-stalking outfitter; live and maintained | The one sentence this whole table turns on: the stag's rut call is *"very similar to the bellow of a bull"*, and he *"will give a loud warning bark if it senses danger"*. Species by species, plain English | Not peer-reviewed, no recordings, no frequencies |
| [wildlifeonline.me.uk, "Red Deer Breeding Biology"](https://www.wildlifeonline.me.uk/animals/article/red-deer-breeding-biology) | Editorial, cited to the primary literature; live | The hind and the calf: the calf emits *"a softer 'bleat'"*, which the hind answers with *"a louder nasal bleat, **not dissimilar to that produced by sheep**"*. Also the alarm call: *"a short sharp scream ending in a grunt"* | Same: prose, not samples |
| [Bioacoustics 7(4), "Characteristics of the vocalisations of Red Deer *Cervus elaphus* hinds and calves"](https://doi.org/10.1080/09524622.1997.9753340) | Peer-reviewed, 1997, paywalled | Would give the actual frequencies | **Not readable from here.** Recorded as a limit rather than cited as if it had been read: the two editorial sources above are what the choice rests on |

**The two sentences decide the whole table.** A bull bellow and a sheep/lamb bleat are not two
convenient near-misses picked because the library has nothing better: they are the two animals the
sources themselves compare a red deer to. A pig squeal is not one of them.

### 2B. What audio is actually available

**MEASURED, not assumed.** Fourteen keyword searches of Roblox's own
`toolbox-service/v1/marketplace/3` ("deer", "elk", "stag", "deer grunt", "elk bugle", "stag roar",
"red deer roar", "deer bark", "fawn", "goat", "goat bleat", "calf", "antelope", "moose"), filtered to
the three creators whose audio plays in anybody's experience (ProSoundEffects, Audioscape, Roblox):

* **not one row named deer or elk.** The library's `Mammals - Wild` category is bull, lion, tiger,
  elephant and coyote; `Mammals - Farm` is sheep, lamb, goat, steer and pig.
* everything the catalogue returns for "deer" is **user-uploaded** — "99 nights deer scream",
  "Deer grunt", "deer screech", "Deer Trumpet" — and therefore private to its own uploader's
  experiences since Roblox's 2022 audio-privacy change. This is the **same negative result task 126
  recorded for footsteps**, re-measured here because a year-old negative is not evidence.
* So the usable pool is exactly what that task listed: the ids this repo already has, a Roblox-owned
  `rbxasset://` engine file, or **an upload Karen pays for**.

Tooling: `<runs-dir>/240-sfx.py` (a utf-8-safe copy of task 126's `sfxfilter.py`, with a duration
column) and `240-sfxraw.py` (the unfiltered listing that shows the user uploads).

### 2C. CC-licensed recordings of a real red deer — and why none of them is in this commit

| Candidate | Licence, read on the page | Note |
|---|---|---|
| [Freesound 757773, "Red Deer Stag Bellowing" by naturenotesuk](https://freesound.org/people/naturenotesuk/sounds/757773/) | **Attribution 4.0** (CC BY 4.0), 2:28.610, 96 kHz mono | Bedfords Park, Essex, during the rut |
| [Freesound 104608, "20100910.deer.rut.wav" by dobroide](https://freesound.org/people/dobroide/sounds/104608/) | **Attribution 4.0** (CC BY 4.0), 1:40.236 | Doñana, S Spain, stags summoning hinds |
| [Pixabay "red deer" sound effects](https://pixabay.com/sound-effects/search/red%20deer/) | **Pixabay Content Licence** — royalty-free, no attribution required | e.g. "The call of Red Stag_Animal Sound" by NickyPe |

**NEGATIVE RESULT: no CC0 red-deer recording was found.** The dispatch asked for CC0 candidates and
the honest answer is that the two Freesound hits are CC **BY**, not CC0, and Pixabay's is its own
licence. That matters here for a reason this repo has already written down once:
`docs/research/2026-09-26-asset-pipeline.md` found that **CC BY 4.0 is not sublicensable** (clause
2(a)(5)(A)) while Roblox's Creator Terms demand a sublicensable grant — exactly the conflict that
made Meshy's free tier Karen's decision rather than mine. So an upload is **`ESCALATE.md`, NEEDS
KAREN**, with the licences quoted, and not something this task ships.

### 2D. The avoidance pattern (unchanged, re-cited because this task re-sizes it)

Craig Reynolds, [*Steering Behaviors For Autonomous Characters*](https://www.red3d.com/cwr/steer/gdc99/)
(GDC 1999), "obstacle avoidance": probe the volume the character will **sweep**, and steer by the
intrusion into it. Task 167 adopted it as a swept-sphere fan; what this task changes is the one
number that says how wide that sphere is, and why it cannot be a constant.

---

## 3. What was measured, before anything was changed

All of it in **Karen's own place** (the Forest Test, live Play, real drives), sampling every 0.1 s
for 70 s at a time. Probe: `<runs-dir>/240-run3.luau` / `240-run4.luau`; raw output in
`240-before3.txt`, `240-after1.txt`, `240-after2.txt`.

### 3A. The drawn animal is not the animal that collides

`MeshPart.Size` of the loaded model against the collision trunk's `Size`:

| kind | drawn X | collision box X | drawn / box |
|---|---|---|---|
| male | 1.40 | 2.00 | 0.70 |
| female | 1.20 | 2.00 | 0.60 |
| cub | 0.62 | 2.00 | 0.31 |
| legendary | 1.89 | 2.00 | 0.95 |
| **stag** | **3.47** | **1.80** | **1.93** |
| hind | 2.01 | 1.80 | 1.12 |
| calf | 1.23 | 1.80 | 0.68 |

**Every boar is drawn narrower than the box it collides with**, so its box meets a trunk before the
model does and nobody has ever seen a boar inside one. **A stag is not**: his box clears a trunk by
0.70 studs while his **antlers are 0.84 studs inside it** — and the swept avoidance cast that exists
to keep him off trunks was 1.60 studs, **narrower than his own drawn half-width of 1.735**. That is
Karen's *"seems it hitting trees"*, and the word "seems" is exact.

### 3B. The stag was sitting on his own gait-band edge

`ForestTestBoot` lowers `MODEL.RUN_FROM` from 28 to `(TROT_SPEED + PACE.RUN_SPEED) / 2 = 21`, with
its own reason written on it: *"an animal bolting at 24 would be DRAWN trotting"*. The deer never got
it, because `Boar.speciesConfig` **replaced** `MODEL` with a clone of the module's table instead of
laying the species' own keys over the world's. A stag bolts at `PACE.RUN_SPEED x runScale` =
24 x 1.18 = **28.3 studs/s** against a band edge of **28.0** — 1.1 % of margin — so he flickered
between the trot clip played at 28.3 / 12.312 = **2.3x** (a blur) and the run clip.

Counted, at 20 studs/s or more:

| | drawn RUNNING | drawn trotting or walking | wrong |
|---|---|---|---|
| stag, window 1 | 5 | 8 | **62 %** |
| stag, window 2 | 60 | 8 | **12 %** |
| hind | 176 | 3 | 1.7 % |
| calf | 197 | 4 | 2.0 % |
| boar male, two windows | 518 / 1381 | 18 / 29 | 3.4 % / 2.1 % |

The hind's and the calf's edges are 25.2 and 18.9 (the band scales by `clipScale`), comfortably under
28.3. **The stag was the only animal in the game standing on a rail.**

### 3C. Trunk contacts, with a control

The metric is the engine's own: a `Touched` event on the animal's collision body against a
**colliding, non-animal, non-terrain, non-character** part — the same definition
`MOVE.COUNT_CONTACTS` uses. Per animal per 70 s window:

| | before | after | |
|---|---|---|---|
| **deer (stag + hind + calf)** | **4.5** (18 touches / 4 animal-windows) | **0.43** (3 / 7) | **-90 %** |
| boar male | 5.0 (95 / 19) | 3.8 (92 / 24) | control |
| boar female | 2.4 (19 / 8) | 1.4 | control |
| boar cub | 2.3 (74 / 32) | 2.9 | control |

**The control is the point.** The boar numbers move by a third in both directions between runs, which
is how noisy a randomly generated wood makes this; the deer number falls by an order of magnitude,
and the mechanism is specific and measured (§3A).

### 3D. Foot sliding: NOT a deer defect (negative result)

`clip.groundStudsPerSecond x clipScale x AnimationTrack.Speed` against the body's own flat speed, for
every sample at 10 studs/s or more:

| | mean | worst |
|---|---|---|
| stag | 1.5-1.7 % | -31 % / -56 % |
| hind | 0.4-2.6 % | +18 % / -66 % |
| calf | 0.4-1.4 % | +7 % / -86 % |
| boar male | 1.0-2.3 % | +103 % / -87 % |
| boar cub | 0.5-1.2 % | +101 % / -79 % |

A running deer's feet keep time with the ground to within about 1.5 % on average, and the worst
cases are crossfade frames (two tracks at partial weight, the heaviest one sampled) that **every kind
has, the boar worse than the deer**. So there is no deer-specific sliding to fix, and nothing was
changed for it. What Karen saw as "odd" is §3B — the wrong *clip*, not a sliding one.

### 3E. Heading against velocity: a LOW-SPEED artefact, shared by every kind (negative result)

The angle between the body's facing and its own velocity, split by speed:

| kind | 3-8 studs/s | 8-15 studs/s | 15+ studs/s |
|---|---|---|---|
| hind | - | - | mean 2.8, max 28.5, **over 30 deg: 0 of 289** |
| calf | 1 sample at 60.7 | - | mean 2.0, max 29.0, **over 30 deg: 0 of 300** |
| boar male | mean 0.4, max 37.5 | **mean 19.7, max 73.9** | mean 3.9, max 56.8, over 30: 10 of 719 |
| boar female | mean 1.4, max 86.1 | **mean 34.3, max 161.5** | mean 3.9, max 66.0 |
| boar cub | mean 4.2, max 30.1 | **mean 16.5, max 155.5** | mean 4.9, max 53.8 |

**A running deer never crabs.** The large angles live in the 8-15 studs/s transition band, where the
velocity setpoint is being slewed while the `AlignOrientation` catches up, and they are **worse for
the boar's sow (34.3 deg mean) than for any deer**. An earlier window read a stag at mean 31.6 deg —
that stag spent 349 of 551 samples *walking*, which is the same band.

So nothing is changed here either. A fix would mean re-sizing `ALIGN_RESPONSIVENESS` by each
animal's yaw inertia (a stag's is about 2.9x a boar male's for the same gain), which would move every
animal Karen has already signed off, to cure something she has not complained about and which her
deer do not do while running. **Queued, not done.**

---

## 4. The patterns adopted, and why

### 4A. The voice: borrow the animal the sources name

Not "pitch the pig squeal further", which is what task 223 shipped and what Karen heard through.
A pitched pig squeal is still the most recognisable noise in the set.

* **stag** -> *Bull Bellows* for the death and *Bull Breaths / Bestial Grunts* for the bark and the
  grunt, pitched **up** to 1.15 (a stag is roughly a third of a bull's weight).
* **hind** and **calf** -> *Lamb, Deep Baa's, Big Lamb*, pitched **down** to 0.80 for the hind and
  **up** to 1.25 for the calf.

Task 223's own rule is kept — *"a new sample nobody has heard would be a second thing to judge"* —
and inverted in one respect: the pitch now moves the *other* way from its numbers, because the
reference animal changed. Every id was loaded and timed in a live Play session before it was written
down (§5).

**Invented nothing.** The one thing that is new is a spec assertion: no deer cue may share an id with
any boar cue, or with the module-level generic rows a kind with no voice falls back to — because
falling back **is** how the deer got pig squeals.

### 4B. The running: the band edge belongs to the world, the clips belong to the species

`Boar.CONFIG.SPECIES.reddeer.MODEL_OVERRIDES` is now the whole of what a deer brings to `MODEL`:
its clip table, its own animation-id table, the band edge those clips imply (`TROT_FROM`) and its
flinch length. `Boar.speciesConfig` lays exactly those keys over whatever `MODEL` the **world** is
running, so `RUN_FROM`, `ENABLED`, `MIN_RATE`, `MAX_RATE`, `FADE_SECONDS` and the other thirty are
the world's own numbers and can never be a stale module default again. `SPECIES.reddeer.MODEL` is
still there, built from the same `MODEL_OVERRIDES`, because `BoarAssetsBoot` and `deer.spec` name it
by that path.

This is **borrowed from inside this repo** (rule 2): it is the shape `Runtime.new` already uses for
`SENSE` and `KINDS` ("merged key by key"), applied to the one block that was still replaced whole.

### 4C. The trees: the sweep is as wide as the animal a player SEES

`Boar.avoidRadius(kind, config)` = `max(AVOID_RADIUS_STUDS, max(drawnWidthStuds, BODY_SIZE.X) / 2 +
AVOID_CLEARANCE_STUDS)`, with `AVOID_CLEARANCE_STUDS = 0.6` — the clearance the old literal 1.6
always contained, said out loud. `drawnWidthStuds` is the measurement in §3A, one number per kind.

* male / female / cub / legendary: `max(1.6, 2.00/2 + 0.6)` = **1.600**, which is task 167's number
  to the last decimal. No boar moves.
* **stag: 2.335**, hind: 1.605, calf: floored at 1.600.

The collision box is deliberately **not** widened to match the antlers: it decides where a shot lands
and how animals pack, and antlers are neither of those.

### 4D. The toughness: the mechanism that already exists

`toughness = 1.2` on all three deer kinds. `Wound.damageFor` divides a **non-vital** hit's points by
it, so each point is worth 83.3 % and it takes 20 % more of them — Karen's sentence, arithmetically.
The vitals stay unarmoured, which is that function's own rule and the hunting rule behind it (take
the chamber or the head), exactly as the legendary's 2.0 works.

**A bigger `LETHAL`/`MORTAL` for the deer was refused for task 219's reason, restated:**
`Wound.flightStuds` tapers the wounded run across the span `MORTAL..LETHAL`, so scaling the
thresholds would also change how far a wounded deer runs for the same fraction of a mortal wound — a
second change nobody asked for, hidden in a number that looks like it only means "tougher".

---

## 5. The numeric targets

| | target | measured after |
|---|---|---|
| deer cues sharing an id with any boar cue | **0** | 0 (spec, every kind x every cue) |
| candidate audio ids that load in a live session | all | 19 of 19, `IsLoaded = true` with a real `TimeLength` (`240-audio.txt`) |
| stag samples at >= 20 studs/s drawn at the wrong gait | <= 3 % (the boar's own rate) | **3.0 %** (3 of 101), from 62 % / 12 % |
| deer `Touched` events per animal per 70 s | at or below the boar's | **0.43**, from 4.5; boar male 3.8 |
| running deer heading vs velocity | within the boar's | mean **2.0-2.8 deg**, **zero** samples over 30 deg at >= 15 studs/s |
| non-vital damage per point | x 1 / 1.2 | exact, asserted |
| band-edge margin at a bolt, every deer kind | > 20 % | stag 25.8 %, hind 33 %, calf 50 % |

**Shots to kill, before -> after** (`Wound.damageFor` has **no range term**, so these are identical at
20 m and at 40 m; what range changes is how many pellets land, and buckshot's own `RANGE_STUDS` is
100 studs = 28 m, so **at 40 m no buckshot reaches the animal at all**):

| zone | ammo | mortal | lethal |
|---|---|---|---|
| chest / head (vital) | slug | 1 -> **1** | 1 -> **1** |
| rear | slug | 1 -> **2** | 2 -> **3** |
| rear | buckshot pellets | 5 -> **6** | 10 -> **11** |
| legs | slug | 2 -> **2** | 4 -> **4** |
| legs | buckshot pellets | 9 -> **10** | 17 -> **20** |

At 20 m one trigger pull of 00 buck puts up to 9 pellets inside a 2.0-stud pattern, which fits the
stag's 1.92-stud chest box, so a well-centred rump shot is still mortal in one pull — what changed is
that it now takes 6 pellets on the rump instead of 5 and 11 instead of 10 to drop it on the spot.

**The one that is more than a fifth is the rump slug**, and that is quantisation rather than a second
decision: 55 points was five points over `MORTAL` = 50, so taking a sixth off it drops under the line
and a second slug is needed. Stated here, in the config and in the task report, because it is the
number Karen is most likely to feel. If it is too much, `toughness` is the dial.

---

## 6. What this note could not establish

* **No frequency data.** The Bioacoustics paper is paywalled; the two editorial sources are what the
  sample choice rests on, and nobody in this toolchain can hear any of it. **Karen's ears decide.**
* **The stag's cry and grunt are "Bull Breaths", the same library family as `SOUND.BREATH`'s own
  ids.** That costs nothing today because `BREATH.enabled` has been `false` since task 123 round 4;
  it is written in the config so that whoever turns the breath back on checks it against a stag's
  bark rather than discovering it.
* **The deer-contact numbers are small samples** — one to two animals per kind per window in a
  randomly generated wood. The boar control is there precisely so the reader can see the noise floor.
* **`Boar.avoidRadius` hands the hind and the calf the stag's clearance** in the same way
  `_avoidTurnFor` has always handed them the stag's `BODY_SIZE`. The error is conservative (a smaller
  animal turns a little earlier than it needs to) and making it per-kind would change how the boar's
  cubs move, which nobody asked for.
* **A pre-existing fault, found and not fixed here:** in a 320 s single drive the world fills to
  `maxBoars` and `ForestTest.releaseLine` then calls `Runtime:spawn`, which **asserts** —
  `ServerScriptService.Boar:5302: Boar runtime is at maxBoars`, once per release from then on.
  Queued in `TASKS.md`; it is not reachable in a normal-length drive and nothing in this task touches
  it.
