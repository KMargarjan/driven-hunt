# Task 166: the drive's fanfare, the stand as an area, and the horn at a bot's mouth

**Date:** 2026-10-12. **Builder.** Three fixes from one playtest, so one note with three sections.
Each one names what the system must do, the sources, what they do well and badly, the pattern
adopted, and the numbers.

Karen, 2026-10-12 ~16:00, verbatim (the Director asked: horn sound right? 15 s enough? bots natural?
clear?):

> "no it's not / for beater yes it's ok / for start and end of drive has to be tuturutu tu tu
> different one / yes inaught but it always put me at the same place even I moved a bit we need
> boundries but not put back where it started / yes, bots are good , just we will change horn and
> behaviuor hwn they push has to put to mauth blow horn / yes, clear"

So: the beater's one-note horn is RIGHT (task 154 stands), the 15 s countdown is right, the screen is
clear, and three things change.

---

## 1. The drive's signal is a fanfare, not three long notes

### What it must do

Sound at the start and the end of a drive, at every player's ear, as a short recognisable MELODY --
"tuturutu tu tu", a few quick notes and then held ones -- and be a DIFFERENT instrument voice from
the horn a beater carries, so a player can tell "the drive has started" from "a beater is over
there".

### Sources

| # | Source | What it is | Licence / maintenance | Good | Bad |
|---|---|---|---|---|---|
| 1 | [waidwissen.com, *Jagdleitsignale*](https://waidwissen.com/lexikon/jagdleitsignale) | German hunting lexicon | Web page, no reuse licence; current | Names the signals a drive is actually commanded with -- *Anblasen des Treibens* to open, *Jagd vorbei und Halali* to close -- and says two of them are safety-relevant | No note lengths, no notation |
| 2 | [jaegerschmiede.de, *Jagdsignale*](https://www.jaegerschmiede.de/jagdlexikon/jagdsignale/) | Hunting-shop lexicon | Web page, no reuse licence; current | Confirms the same two signals and that they are blown on a Fürst-Pless horn | Commercial page, no notation |
| 3 | [hegering-hitzacker.de, *Jagdhornsignale*](https://www.hegering-hitzacker.de/jagdhornsignale.php) | A hunting district's own signal list | Web page, no reuse licence; current | A list of real signals by name, which is what settles that a drive signal is a short named phrase and not a drone | Audio behind links, nothing usable |
| 4 | Roblox Creator Store audio search (`apis.roblox.com/toolbox-service/v1/marketplace/3`) plus `economy.roblox.com/v2/assets/<id>/details` | The live catalogue | The assets are Roblox-licensed; `IsPublicDomain: true` | Gives name, creator, duration and public-domain flag without a key. The procedure task 142 used for the rifle | Search ranks truck horns above hunting horns; duration is rounded to the second |
| 5 | [Roblox `Sound.PlaybackLoudness`](https://create.roblox.com/docs/reference/engine/classes/Sound) | Engine reference | Current | The only way to measure where a phrase is inside a clip without downloading it | Only reports while the sound is PLAYING, and it does not play in Edit mode (measured below) |

**The Fürst-Pless horn is a valveless brass signal horn: its notes are the natural harmonics.** That
is the same instrument class as a military bugle, which is why a bugle call is the right object here
and not an approximation of one.

### What the two candidate routes were, and which won

The dispatch allowed either (a) a free public library fanfare, or (b) a melody assembled from the
beater's single measured note by pitch-shifting it per note (`PlaybackSpeed`).

**(a) won, on a measurement.** The search returned a whole set of SHORT bugle calls from
**APMOfficial** -- Roblox's own licensed KPM 1000 LP Series, the same creator as the beater's
"Hunting Horn" (9038902877) -- all `IsPublicDomain: true`. Nine candidates were then **measured to
load in this place** (Play session, 2026-10-12, `Sound.IsLoaded` plus `Sound.TimeLength`):

| asset | name | measured TimeLength |
|---|---|---|
| 1842335206 | Bugle Call (a) | 4.062 s |
| 1842335210 | Bugle Call (b) | 3.859 s |
| 1842368482 | Bugle Call (c) | 2.843 s |
| 1840120074 | Bugle Call (A) | 4.101 s |
| 1840120111 | Bugle Call (B) | 3.918 s |
| 1840120155 | Bugle Call (C) | 2.900 s |
| 1845415163 | Heraldic Bugle | 5.055 s |
| 1838998408 | Bugle Charge | 6.975 s |
| 1845354030 | Bugle Call | 7.487 s |

All nine loaded. (b) would have been one timbre played at three speeds -- a kazoo, not a horn -- and
would have put a melody's worth of timing in code in order to avoid using an asset that already is
one. Rule 2 wants a reason for building: there is none here.

### Measuring the phrase

`Sound.PlaybackLoudness` at Heartbeat rate, peak per 0.05 s bucket, `Volume = 0.0001` (the loudness is
the source's own and is not scaled by Volume -- task 152 established that and these runs agree).

**A measurement that cost a run, recorded because it will be wanted again: sounds do not play in
Edit mode.** The first sweep ran against the Edit DataModel and every bucket read `TimePosition = 0`
and `loudness = 0` for all six clips. The same script against a Play client produced the profiles
below. Any future loudness probe needs a Play session.

**1842335206 "Bugle Call (a)" -- the START.**

```
0.00-0.40  silence                                     the asset's own lead-in
0.45-0.55  note        (31, 38, 23)              \
0.70-1.05  two notes   (21, 47, 27, 43, 30)       |  SIX QUICK NOTES -- "tuturutu"
1.20-1.55  two notes   (37, 48, 25, 20, 27)       |
1.70-1.85  note        (26, 19)                  /
1.95-2.40  ONE HELD NOTE (44, 56, 51, 53, 55, 40, 35, 32, 17)  -- "tu tu"
2.45-4.06  the clip's own silence (2, 1, 0 ...)
```

Cut **0.42 → 2.60** (2.18 s): the whole phrase, starting 0.03 s before the first attack so it sounds
on the cue, ending inside the clip's own silence so the stop cannot click.

**1842368482 "Bugle Call (c)" -- the END.**

```
0.00-0.30  silence
0.35-0.50  note        (34, 31)                   \
0.60-0.95  two notes   (37, 45, 17, 31, 34)        |  FOUR QUICK NOTES
1.10-1.35  two notes   (35, 36, 28, 33)           /
1.40-1.85  ONE HELD NOTE (33, 40, 33, 30, 28, 24, 24, 22, 18, 9)
1.90-2.84  the clip's own silence
```

Cut **0.32 → 2.00** (1.68 s).

**Why the end is a variation and not the same phrase.** Karen said *"when ends the same"* this
morning, about three long notes. The two phrases are the same instrument and the same shape; the end
is shorter and its figure is different, so a drive that ends says "over" rather than "go". That is
the one liberty this task takes with her sentence and it is one line to undo.

**The two rejected pairs, said plainly:** (b)/(B) are busier and do not end on a held note, so they
are not "tuturutu tu tu"; (A) measures almost the same as (a) (the held note peaks 62 at 2.05 against
56 at 2.00) and either would do.

### The volume, measured

Peak loudness, all three sampled the same way: this fanfare's held note **56**, task 163's
hunting-horn sustained note **214**, the beater's beep **418**. So at `Volume = 1` the fanfare would
arrive about a quarter as loud as the signal Karen heard this morning. `SIGNAL.VOLUME = 3` -- the
ratio rounded down, because a 2-D cue at the ear startles more easily than a sound in the world.

**Not heard, and said so (rule 8).** Every number above is a measurement. Whether the two phrases
FEEL right at the two ends of a drive is Karen's judgement, and each is one line.

### The pattern adopted

Unchanged from task 163 and still the right one: the SERVER says WHEN (`Match.Phase` emits one
`signal` feed entry carrying the word "start" or "end"), the CLIENT says what it sounds like
(`Hud.Sound`, the one writer of the Hud's 2-D cues), and the DATA says everything else
(`Horn.CONFIG.SIGNAL`). What changed inside that shape:

- `SIGNAL.PHRASES` is **keyed by the server's own word**, so the client looks a phrase up instead of
  branching on the cue;
- `Horn.signalPlan(which, config)` is still a LIST of soundings, and today each phrase is one row --
  the melody is in the asset, where a melody belongs;
- an unknown or missing word gets the start phrase (`Horn.SIGNAL_DEFAULT`), because a silent drive is
  a worse answer than the wrong phrase;
- one Sound per cue word, made and preloaded at module load -- task 163a(a)'s fix, kept for its own
  reason: `TimePosition` on an unloaded Sound is not kept, so a voice made at the cue plays the clip
  from 0, which for these assets is the lead-in silence and then half a phrase.

### Targets

| What | Value | Where |
|---|---|---|
| Start phrase | 1842335206, 0.42 → 2.60 (2.18 s) | `Horn.CONFIG.SIGNAL.PHRASES.start` |
| End phrase | 1842368482, 0.32 → 2.00 (1.68 s) | `Horn.CONFIG.SIGNAL.PHRASES["end"]` |
| Volume | 3 | `Horn.CONFIG.SIGNAL.VOLUME` |
| Fits the phase it is played at the edge of | 2.18 s and 1.68 s < 15 s intermission and 25 s results | `zz_horn.spec` |

---

## 2. The stand is an area with a wall, not a point with a leash

### What it must do

A hunter who has locked a stand may walk freely inside a circle around it; at the edge he is STOPPED
and never moved back toward the middle. He can still walk, turn and shoot -- *"I want tomorrow to
test shooting and walking"* -- and he can see where the edge is. Beaters are not bounded at all.

### What was actually putting her back -- MEASURED

Three things could have done it and the dispatch named all three: the Forest Test's own hold, 
`Match.Body.settle`'s drift re-pivot (task 157), or the stand placement re-pivoting. In a Play
session of the Forest Test on 2026-10-12, with stand 5 locked, the character was moved 20 studs north
of its stand and its flat distance from the stand sampled every Heartbeat for four seconds:

```
0.0s 20.00   0.1s 6.00   0.2s 6.00   0.3s 6.00  ...  4.0s 6.00
ended 6.000 studs from the stand (dz=6.00)
```

**One Heartbeat, 20 studs → 6.000, and 6.000 for every sample after it.** So it is
`ForestTest.leash` and `PICK.leashStuds = 6`, and nothing else: `Body.settle` fires once per
placement and would have landed her at 0.00, and no re-pivot ran at all.

6 studs is **1.7 m** at this game's 0.28 m per stud. Every step past it was written back to exactly
6.000 -- at a character's 16 studs/s that is a correction every frame while she held the key, which
is the rubber band she described as being put back where she started.

### Sources

| # | Source | What it is | Licence / maintenance | Good | Bad |
|---|---|---|---|---|---|
| 1 | [Roblox `BasePart.AssemblyLinearVelocity`](https://create.roblox.com/docs/reference/engine/classes/BasePart#AssemblyLinearVelocity) | Engine reference | Current | The whole character is one assembly, so this is the one property that means "how fast is this player moving" | Says nothing about who wins when a client is also predicting |
| 2 | [Valve Developer Wiki, `func_playerclip` / playerclip brushes](https://developer.valvesoftware.com/wiki/Clip) | Level-design convention | Wiki, community-maintained | The industry answer to "keep the player in this area": an INVISIBLE WALL he collides with, never a teleport. Says the boundary should be visible in the world even when the clip is not | A brush is a collider; this game's boundary is a circle round a moving-per-drive point |
| 3 | [Roblox `Humanoid` / character physics ownership](https://create.roblox.com/docs/reference/engine/classes/Humanoid) | Engine reference | Current | Confirms the rule this repo already measured twice (`Match.Body.holdCharacter`, `Body.settle`): a server-side pivot alone is a suggestion the client can walk out of | No guidance on soft boundaries |
| 4 | This repo, `Boar.Brain`'s own leash at twice the spread (task 126) | Prior art in the same codebase | — | The same question answered for animals: a clamp, measured, with the number in data | An animal has no client predicting its position |

### What was considered and rejected

- **A real collider** (an invisible cylinder wall) is the Valve answer and the most honest "soft
  wall", but a 12-stud cylinder of `CanCollide` parts per stand is nine more colliders in a world
  whose foliage was deliberately made non-colliding, and a collider that stops a PLAYER also stops a
  boar walking onto the stand. Rejected for now; noted as the upgrade if the clamp still reads badly.
- **Anchoring the character at the edge** breaks walking, which is the thing she is testing.
- **A bigger leash alone** (6 → 12 with the old pull) would have moved the rubber band outward
  without removing it.

### The pattern adopted

**Clamp the position onto the circle, and take away the OUTWARD component of the velocity.**

1. `ForestTest.boundaryPoint(position, standIndex)` is PURE and is the only thing that decides where
   the player ends up: `nil` inside, and otherwise a point at EXACTLY `standRadiusStuds` from the
   stand, on the player's own bearing, at his own height. "Put back to the middle" is therefore not
   expressible, which is Karen's complaint answered structurally rather than by a number.
2. `ForestTest.boundary(userId, root, role)` writes that position and then removes the part of
   `AssemblyLinearVelocity` that points away from the stand. The second write is the new half: a
   clamp alone leaves a player holding W pushing into the wall at full speed, so he is written back
   every frame; with the outward speed gone he STOPS at the edge. Sideways motion along the circle and
   the whole of the vertical are untouched, so he can walk round his own edge and still falls.
3. The edge is DRAWN. `ForestTest.Markers` -- the one writer of `Workspace.ForestMarkers` -- lays a
   thin neon ring of 20 chord segments on the ground at the same radius, each on its own ground
   reading, when a pick locks; the rings go when the next intermission drops the picks. There is no
   ring primitive in Roblox: a Cylinder is a disc, a torus needs an uploaded mesh and a decal needs an
   uploaded image. 20 chords of a 12-stud circle sag 0.15 studs at the middle, which is less than the
   ring's own thickness.

### Targets

| What | Value | Where |
|---|---|---|
| Stand radius | **12 studs (3.4 m)**, was 6 (1.7 m) | `ForestTest.PICK.standRadiusStuds` |
| What the clamp may return | only a point ON the circle, same bearing, same height | `ForestTest.boundaryPoint`, `forest_stand.spec` |
| Velocity removed | the outward radial component only | `ForestTest.boundary` |
| Ring | 20 segments, 0.5 studs thick, lifted 0.08, transparency 0.45 | `Markers.RING` |
| HUD arrival band | in at 24, out at 30 (was 12 / 18) | `Objective.CONFIG` -- twice the radius, so walking about ON the stand cannot flicker the chevron |

---

## 3. A bot beater raises the horn to its mouth while it blows

### What it must do

While a bot's horn blast sounds, its arm and the horn go up to its face: a short raise, a hold for
the length of the blast, a lower. Nothing else about the bot changes -- it keeps walking, keeps its
lane and keeps its gait.

### What was already there

`Weapon.Horn.blowTool` already tilts the Tool's own `Grip` to `GRIP_BLOW` for
`Horn.CONFIG.BLOW_SECONDS`, for a bot exactly as for a player. But a tilt at the end of an arm
hanging by the hip is a horn held at the hip, which is what Karen was looking at. The ARM has to move.

### The mechanism -- three measured failures and one that worked

All measured 2026-10-12 against a live bot beater in a Play session of the Forest Test, reading the
right hand's position in the head's own frame.

| # | Mechanism | Result |
|---|---|---|
| 1 | `AnimationConstraint.Transform` written once | hand moved **0.01 studs** |
| 2 | the same write, every Heartbeat for 40 frames | hand moved **0.12 studs** |
| 3 | the arm-side rig ATTACHMENT's CFrame (the trick that works on a `Motor6D`'s C0) | **0.3 studs** for a 60-degree turn |
| 4 | every animation track STOPPED, then one `Transform` write | hand moved **1.6 studs** and HELD |

**These rigs are not jointed by `Motor6D`.** `Players:CreateHumanoidModelFromDescription(.., R15)`
produces limbs joined by **`AnimationConstraint`** plus a `BallSocketConstraint` -- measured:
`RightUpperArm/RightShoulder` is an `AnimationConstraint` with `Attachment0` in `UpperTorso` and
`Attachment1` in `RightUpperArm`. So there is no C0/C1 to compose an offset with, and the solver pulls
the limb back to whatever the playing tracks ask for. Row 4 is the proof that nothing survives a
playing track: **the only thing that poses one of these arms while a gait plays is another
ANIMATION, at a priority that outranks it.**

### Sources

| # | Source | What it is | Licence / maintenance | Good | Bad |
|---|---|---|---|---|---|
| 1 | [Roblox `KeyframeSequenceProvider`](https://create.roblox.com/docs/reference/engine/classes/KeyframeSequenceProvider) | Engine reference | Current | `RegisterKeyframeSequence` turns a `KeyframeSequence` built in code into a content id an `Animator` can load -- an animation with no upload and no Animation Editor | The id is temporary and local to the session (which is exactly what is wanted here) |
| 2 | [Roblox `Enum.AnimationPriority`](https://create.roblox.com/docs/reference/engine/enums/AnimationPriority) | Engine reference | Current | `Action` > `Idle` > `Core` is why one clip can take the arm from the gait (`Core`) and the tool pose (`Idle`) | — |
| 3 | [Roblox `Pose.Weight`](https://create.roblox.com/docs/reference/engine/classes/Pose) | Engine reference | Current | A pose with `Weight = 0` contributes nothing, which is how a clip can name the chain from the root without speaking for the torso | — |
| 4 | This repo, `Bots.Rig.TOOL_CLIP` (task 164) | Prior art | — | The same problem solved the same way one task ago: a second track at a higher priority, on top of the gait, for the arm alone | — |
| 5 | This repo, `tools/boar_prep.py` header | Prior art | — | States the constraint that makes this necessary: an animation ASSET ID can only be made by hand in Studio's Animation Editor, which is why that tool writes FBX files for Karen to import | — |

### The pattern adopted

**A `KeyframeSequence` built from two angles in data, registered once per session, played at `Action`
priority for the length of a blast.**

- `Rig.BLOW` holds the pose: `SHOULDER_DEG`, `ELBOW_DEG`, `RAISE_SECONDS`, `LOWER_SECONDS`.
- `Rig.blowSequence(config)` builds the sequence and reads no rig, no service and no state, so a spec
  asserts the whole pose tree, the weights and both angles without a bot or a Play session.
- **Only the shoulder and the elbow carry weight.** The chain from `HumanoidRootPart` down is named
  because a `Pose` is found by its place in the hierarchy, and every pose above the shoulder carries
  `Weight = 0` -- a clip that wrote identity over the torso at `Action` would freeze a walking
  beater's lean for the length of every blast.
- **The raise and the lower are the Play/Stop FADES.** `Play(RAISE_SECONDS)` blends the pose in, the
  looping sequence holds it, `Stop(LOWER_SECONDS)` blends it out: three phases, two calls, no
  per-frame work.
- `Bots.blowing(bot, at)` is a pure window over the stamp `Bots.blowFor` writes, and the step asks it
  every tick -- level-triggered, so a missed step cannot leave an arm up.
- **The hold length is the HORN's number**, `Horn.CONFIG.BLOW_SECONDS`, handed to the bots at the
  composition root with the rest of the horn seam (`world.horn.blowSeconds`). The arm and the Tool's
  own tilt are then the same length by construction instead of by two numbers agreeing.
- **Players are NOT given the arm raise, and that is an ownership decision.** A player's character is
  animated by its own client `Animate` script and is `Match.Body`'s to write; a server-side pose on it
  would be a second writer of a body this repo gives one owner. A player beater's raise stays the
  Tool's `GRIP_BLOW` tilt, which is what he already had. Said plainly because the dispatch asked for
  the player case "if cheap": it is not cheap, it is an owner boundary.

### Targets

| What | Value | Where |
|---|---|---|
| Shoulder | (-120, 0, 15) degrees | `Rig.BLOW.SHOULDER_DEG` |
| Elbow | (-150, 0, 0) degrees | `Rig.BLOW.ELBOW_DEG` |
| Raise / lower | 0.20 s / 0.35 s | `Rig.BLOW` |
| Hold | `Horn.CONFIG.BLOW_SECONDS` = 0.9 s | the horn seam |
| Priority | `Action` | `Rig.loadClips` |

**The angles were chosen off a measured sweep of ten candidate pairs and then LOOKED AT (rule 5).**
The sweep read the horn's own `Mouthpiece` part in the head's frame for each pair; this one brought it
nearest the head. A pose is settled by a picture, not by a coordinate, and the screenshot is in the
review request.
