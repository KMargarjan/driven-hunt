# The shot and the death: how a boar reacts where it was hit, and what a hunter hears

Task 116, 2026-10-04. Karen, 2026-10-03: *"when hit not head (heart) sound, can fall on side and legs
moving like in real life / can be hit to back part start to do circles with first legs on"*, and on
sound: *"I just need that once they walk you can hear (as example hunter waiting and hear something
comming and then boars are visible running, walking ect) / hit yes different one saunds you decide
what sounds"*. One boar only -- *"we need to fix one boar 100% then move to anothers"*.

## 1. What the system must do

1. **Where the shot lands changes what the animal does**, using the hit zones and the wound model
   that already exist. No change to hit detection, to the damage numbers, or to how far a wounded
   boar runs.
2. Three outcomes a player can tell apart: a **vital** hit that drops it, a **non-vital** hit it runs
   on from, and a **hindquarters** hit that takes its back legs away.
3. **A hunter hears a boar before he sees it.** Footsteps, grunts and breathing, 3D, from far enough
   out that a man standing on a post gets warning.
4. Different sounds for a hit, a cry and a death.
5. It merges behind `BOAR_MODEL`, the flag Task 115 established, with the same promise: flag off is
   the grey box and nothing else changes.

## 2. The sources

| Source | What it is | Status | Good | Bad |
|---|---|---|---|---|
| **Stokke et al. (2018), "Defining animal welfare standards in hunting"**, *Scientific Reports* 8, CC BY 4.0, [doi:10.1038/s41598-018-32102-0](https://doi.org/10.1038/s41598-018-32102-0) | The peer-reviewed flight-distance work this repo already builds `Wound.FLIGHT` on | Published, open access | Gives **measured** flight distances by body mass, which is why the existing numbers are not invented | Says nothing about *posture* -- it measures how far, not what the animal looks like doing it |
| **Deutscher Jagdverband, "Schusszeichen"** (the signs an animal gives at the shot), [jagdverband.de](https://www.jagdverband.de) | German hunting practice, the same body this repo already cites for the safety rule | Current, first-party to the practice | It is exactly this task's question, from the people who do it: a **heart/lung** hit gives the *Zeichnen* -- a sudden dash, often a stumble, then down within a short run; a **liver or gut** hit gives a hunched, slow departure; a **spine or hindquarters** hit drops the back end on the spot | Describes signs for tracking, not animation; no timings |
| **theHunter: Call of the Wild** (Expansive Worlds) and **Hunter: Primal** | The genre's reference for shot reactions | Commercial, current | Confirms the shape players expect: vitals = short sprint then collapse; gut = slow limp away; spine = front-leg drag. The "drags itself in circles on its front legs" that Karen described is the recognisable spine-shot behaviour | Closed source; nothing is borrowable but the shape |
| **Roblox `Bone` / `Animator`** ([rigging](https://create.roblox.com/docs/art/modeling/rigging), [AnimationTrack](https://create.roblox.com/docs/reference/engine/classes/AnimationTrack)) | The engine's own layering | First party, current | `AnimationTrack.Weight` and `TimePosition` are writable and do blend | **`Bone.Transform` is the Animator's output and is overwritten every frame** -- measured here, see section 4 |
| **Roblox 3D sound** ([Sound](https://create.roblox.com/docs/reference/engine/classes/Sound), [RollOffMode](https://create.roblox.com/docs/reference/engine/enums/RollOffMode)) | A `Sound` parented to a `BasePart` is positional; `RollOffMinDistance`/`MaxDistance` and `RollOffMode` set how far it carries | First party, current | Exactly the "hear it before you see it" requirement, with no new system: the boar already has one part everything is welded to | `InverseTapered` is the recommended mode and the docs give no curve, so the audible range is a number to pick and then listen to |
| **Roblox audio library, ProSoundEffects** | The sounds themselves | Library, usable by id | Karen delegated the choice (*"sound you choose best practice you do"*); the Director picked a provisional set | Library ids can be moderated away; every id must stay swappable data |

### Rejected

- **Writing `Bone.Transform` from a script to animate the legs** -- the obvious way to do paddling
  legs and a dragged hindquarter, and what this task was dispatched to do. **Measured and refused**
  (section 4).
- **Authoring a death-throes clip** -- rule 2 says borrow first, and the package has 74 clips; but
  none of them is an animal dying on the ground. Authoring one is an animator's job, not this task's.
- **A second `Sound` service / a client-side mixer** -- the boar already has a part; a `Sound` in it
  is positional for free and replicates with it. Nothing else is needed.

## 3. The pattern adopted

**The zone decides a CLASS, the class decides the reaction, and every number is data.**

`Wound` already turns a zone into damage and flight. It gains one pure lookup -- the zone's **class**
-- and nothing else: `vital` (head, chest), `crippling` (the new rear zone) and `nonVital` (body,
legs). The Brain reads the class on the hit tick and picks its state; `Body` reads it to pick the
sound. Damage, flight, thresholds and the existing four zones are untouched.

**The rear zone is added the way every other zone exists**: a row in `Boar.CONFIG.ZONES` plus its
`ORDER` entry, which is all a zone is -- `Body.buildZones` builds whatever the table lists. It sits
above the `legs` box and behind the `chest` one, so it takes the hindquarters and overlaps neither.

**Sound is data too**: one table of ids, volumes, ranges and intervals in `Boar.CONFIG.SOUND`, and
`Body` -- already the only writer of a boar's Instances -- creates the `Sound` objects inside the
trunk and starts and stops them. A `Sound` in the trunk is 3D for free and is replicated with the
boar, so every client hears the same animal from the right direction with no new remote.

## 4. The measurements that changed the design, and the one thing the brief asked for that is not here

**(a) A script cannot layer on top of a playing track.** `Bone.Transform` is what the `Animator`
writes each frame. Writing a hind-leg bone's `Transform` every Heartbeat on a live boar and reading
it back at the start of the next frame: **0 of 122 samples survived on the server, and 0 of 121 on
the client**. The written rotation was gone each frame. So the dispatched approach -- "procedurally
(Bone transforms on the leg bones layered over the held death pose)" -- is not available in this
engine while a track plays.

**(b) The held death track's `TimePosition` *is* writable, and the pose follows it.** Scrubbing the
frozen `Death_L` across the tail of its 1.208 s moved the hind hoof **0.432 studs** and the head
**1.641 studs**. So the one lever left on a dead boar is its own clip.

**What that means, said plainly:** the dying movement this task can give is a **whole-body twitch**
driven by scrubbing the death clip's own tail with a decaying amplitude -- not isolated legs
paddling while the body lies still. The package has no death-throes clip and the engine will not let
a script move one leg under a playing animation. Karen asked for *"legs moving like in real life"*;
what she will get is the body twitching and settling. **That is a judgement for her**, and the
alternative -- an animator authoring a paddle clip, or buying one -- is a separate task.

The same measurement bounds the **hindquarters** reaction: the circling is real (the Brain steers the
body in a circle at a crawl, and the physics box carries it, so `Body` stays the only writer), but
"front legs on, hind legs dragged" cannot be drawn without a drag clip. The animal walks its circle.

**(c) The "short dash" a vital hit was dispatched to give is NOT in this task, and the reason is the
dispatch's own constraint.** The brief asks for *"VITAL (heart/lungs) = short dash then falls"* and,
in the same breath, for the existing zones and outcomes with *"no change to hit detection or damage
numbers"*. Those two cannot both hold: a chest slug charges 100, which **is** `LETHAL`, and
`FLIGHT.chest` is **0** -- so the existing model drops a heart-shot boar where it stands, on the tick
it is hit, and a dash would mean raising `FLIGHT.chest` off zero or taking a chest slug below
`LETHAL`. Both are damage numbers. The constraint won, because the dash is also the half Karen did
not ask for: her words are *"when hit not head (heart) sound, can fall on side and legs moving like
in real life"* -- a sound, a fall, and movement on the ground. What ships for a vital hit is the hit
sound, the death scream, the body landing, the fall on its side and the twitch. **If the Director
wants the dash, it is a damage-model change and a separate task.**

## 4b. The fix round, after Karen's look (2026-10-03 ~19:00)

Karen, verbatim: *"1. its good / 2. body shot is a bit odd now feels late hit and odd / 3. no cicrcle
but I can see back legs disabled / 4. yes it works as expected"*. Hearing them coming (1) and the
head/heart shot (4) are accepted. Two defects, and both were measured before anything was changed.

### (a) "feels late hit and odd" -- two causes, and neither was logic

**MEASURED on the client that fired**, at `RenderStepped`, from the frame `UserInputService` saw the
mouse go down:

| t (s) | what the player's own machine had |
|---|---|
| 0.000 | the click |
| 0.069 | the server's answer lands: the `hit` Sound plays (it was already `IsLoaded`); the `cry` Sound is told to play with `IsLoaded = false` and its `TimePosition` stays 0.00; the flinch track exists with `WeightCurrent` 0.00 and `TimePosition` 0.00 |
| 0.433 | the cry finally loads and starts, and the flinch's `TimePosition` finally moves |
| 0.568 | the flinch reaches full weight |

So the animal's answer to being shot was **364 ms late** and only fully drawn at **568 ms**. The
cause is the CLIENT fetching an audio and an animation asset it had never been asked for -- a boar
that is never shot never plays its cry, so the first boar anybody shoots pays for both.

**The fix is to ask for them when nothing is watching.** Every clip is played at weight 0 and every
sound at volume 0 the moment the coat goes on, and stopped `WARM_SECONDS` (0.5) later. A client
fetches an asset when it is told to play it, so this is the same fetch moved from the worst moment to
the least important one. `ContentProvider:PreloadAsync` is the documented tool and it is a **client**
call; this repository has no client-side boar code, and inventing some would be a new owner for a job
that needs no owner, so the server asks instead -- through the Instances `Body` already owns.
**Re-measured after the fix: `hit` and `cry` both report `IsLoaded = true` from frame 0, before any
shot.**

**The second cause is a clip fighting the bolt.** The flinch clips are 0.833 s and they are IN PLACE,
and a body hit bolts the animal to `SPRINT_SPEED * BOLT_KICK` on the same tick -- so for five-sixths
of a second the boar slid some 30 studs with its legs still, and only then began to run. A running
animal now shows only the first `HIT_MOVING_SECONDS` (0.25) of the window, and a hit or a death cuts
in at `HIT_FADE_SECONDS` (0.03) instead of crossfading over 0.15. A standing animal still gets the
whole clip: it has nothing to fight with.

### (b) "no cicrcle but I can see back legs disabled"

**MEASURED on a real crippled boar**, every Heartbeat for 12 s: it *did* circle. At 3 studs/s and
70 deg/s the radius is `v / w` = 3 / 1.222 = **2.45 studs**, so the circle it drew was **4.9 studs
across** and the animal is **5.5 studs long**. A path smaller than the animal is not a circle anybody
can see -- it is a boar pivoting on the spot, which is exactly what she reported. The lap took 5.0 s.

**So the fix is a BIGGER circle, not a tighter one**, which is the opposite of what the fix round
asked for; the measurement is the reason. 4.5 studs/s and 45 deg/s give a radius of **5.73**, a
circle **11.5 studs across** (about two body lengths) and a lap of **8.0 s**: the animal travels 36
studs per lap, so from a post at 20-40 studs it is plainly going round. `FLIGHT.rear` went 60 to 90
so it still lasts the same 20 s of circling.

### (c) The clips the package does not have, authored out of the clips it does

Measurement 4(a) says a script cannot move a bone over a playing track, so paddling legs and a
dragged hindquarter need **clips**. `tools/boar_prep.py` now authors three, and **nothing is
invented** (rule 2): every authored frame is a blend between two poses this package's own animator
made.

| clip | built from | measured per hoof |
|---|---|---|
| `Death_Paddle_L` / `_R` | `Death_L`/`Death_R`'s **last frame** with the four legs swinging back toward `Run_F_IP`'s leg poses, amplitude decaying to nothing over 4.000 s | the legs on the **up** side travel 1.74-4.64 studs/s; the two against the ground 0.30-0.37. A leg under a lying animal cannot swing, and the blend reproduces that without being told |
| `Cripple_Drag` | `Walk_F_IP` everywhere, hind legs pulled 85 % toward the death pose, rear spine 30 %; 1.000 s, looped | **front 2.866 and 2.863 studs/s** (`Walk_F_IP`'s own 2.853 -- a real walk cycle) and **hind 0.826 and 0.931** (a third of it, dragging). That table *is* Karen's "circles with first legs on", in numbers |

The paddle **ends on the pose it began on**, so the hold frame after it is the pose the carcass keeps
and nothing pops. The drag is keyed one frame short of repeating itself, because Roblox blends a
looping track's last frame into its first.

**They have no asset id and cannot have one from a tool**: an animation asset is made by hand in
Studio's Animation Editor (section 4 of the Task 115 note, and `ESCALATE.md`). So the keys are
declared, the wiring is complete, and `Body.hasClip` is false until a row names an id -- with no id
the death is one clip and a crippled boar walks, exactly as before. The whole-body `TimePosition`
twitch stays as the fallback and is skipped the moment a real paddle clip exists.

## 4c. After the ids arrived (2026-10-03)

**The published lengths are 1.000 s and 4.000 s, not 1.042 and 4.042.** Read back off the live assets
with `Animator:LoadAnimation` and `AnimationTrack.Length`: `Cripple_Drag` 1.0000, both paddles 4.0000
-- and, as controls, `Walk_F_IP` 1.0000 and `Death_L` 1.2083, which are the numbers
`Boar.CONFIG.MODEL.CLIPS` already carries. **A clip's length is its INTERVALS, not its keys**: 25
keys at 24 fps is 24 intervals. `tools/boar_prep_blender.py` reported `frames / fps` for every clip
it has ever measured, which is why the ten package clips' lengths had to be corrected by hand after
Task 115 and why these three arrived 42 ms long. It now reports `(frames - 1) / fps`, which agrees
with Roblox on all thirteen.

**All three were published `Loop = true`** (the Animation Editor's toggle, like the ten before them).
`Body.play` writes `AnimationTrack.Looped` from the config immediately before every `Play`, so the
two paddles play once and hold; `boar_shot.spec` asserts that setting rather than trusting the asset.

**A pose channel an action does not key keeps the last action's value** -- a Blender hazard the
authoring hit and survived. `pose_of` now clears the rig to rest before evaluating anything, and the
tool reports `lowestHoofMetres` per clip so "the animal is drawn floating" is a number rather than a
thing somebody has to notice. Re-run with both fixes, the three clips measure **identically** (same
keys, same ground speeds, same lowest hoof), so the published ids stand and `sourceSha256` names the
files that were actually published.

**What the live frames show.** A real kill, recorded on the client at RenderStepped: `Death_L` plays,
and at about 1.2 s `Death_Paddle_L` takes over and runs its four seconds, holding at `TimePosition`
3.98-4.00 from then on -- the fall, the paddle, and then still, which is the design end to end. The
carcass frames at +0.6 s and +4.0 s show the animal flat on its side ON the surface, legs out.

**One thing could not be driven from here**: a replayed mouse shot cannot be steered onto a chosen
hit zone. The camera ray meets `ZoneRear` and the slug still charges the trunk or the legs, because
the gun's `Muzzle` attachment sits at camera-space **(-0.71, -1.69, +5.84)** -- the two rays are not
the same ray. Shots land reliably; WHICH zone they land in does not, from this harness. So the
crippled reaction is evidenced by `boar_shot.spec` (pure, and live through `Runtime:takeHit` with
real physics) rather than by a replayed click, and `Cripple_Drag` was looked at by playing it on a
live boar's own Animator -- against a control of the package's own `Walk_F_IP` played the same way,
because the first look at it seemed to float and the control floated identically.

## 5. The numbers

| | value | why |
|---|---|---|
| `ZONES.rear` box | 2.0 x 1.6 x 1.8 studs at (0, +0.5, +2.0) | the hindquarters: behind the chest box, above the legs box, 0.15 studs proud of the trunk's rear face so a ray meets it first (the same `PROTRUSION` rule every zone follows) |
| `DAMAGE.rear` | Slug 55, Pellet 11 | **the trunk's own row**, because the rump *is* trunk -- as much meat and bone as a flank. The row exists so `CLASS` can call it crippling, not to make it softer. One slug is `MORTAL` (50) and well short of `LETHAL` (100), which is the whole shape of the reaction: the back end goes and the animal is alive to be finished |
| `FLIGHT.rear` | **90** studs (was 60) | it does not run, so this is not a flight distance in the paper's sense -- it is how long it has left, carried by the same mechanism. 90 studs at `CRIPPLE_SPEED` is **20 s** of circling untapered, and `Wound.flightStuds` tapers it past MORTAL -- one 55-point rump slug is 5 of the 50-point span, so 81 studs and about **18 s**. Either way inside `BLEED_OUT_MAX_SECONDS` (25), so no crippled boar can last for ever |
| a graze does **not** cripple | `severity ~= "grazed"` | the leak this closes: a crippled boar is taken out of the escape test (it is going nowhere) and `Wound.advance` never collapses a *grazed* animal, so crippling on a graze would leave a boar turning in the arena with no way out at all. It is also right physically -- one pellet in the ham does not take the back legs off |
| `CRIPPLE_SPEED` | **4.5** studs/s (was 3) | a crawl that still shows: see section 4b(b). The walk clip reads as walking rather than sliding, and it is still well under `TROT_SPEED` |
| `CRIPPLE_TURN_DEG` | **45** deg/s (was 70) | radius 5.73 studs, a circle 11.5 across -- two body lengths, so it is visibly a circle from 20-40 studs. Lap 8.0 s, one direction throughout |
| `MODEL.PADDLE_SECONDS` | 2.5 | the twitch after it goes down, decaying to nothing. A **`MODEL`** number, not a `WOUND` one: it describes a drawn thing and is read only behind `BOAR_MODEL`. It is the FALLBACK since the fix round: with `Death_Paddle_L/R` published there is a real clip and this is skipped |
| `MODEL.WARM_SECONDS` | 0.5 | the silent pre-roll that killed the 364 ms (section 4b(a)) |
| `MODEL.HIT_MOVING_SECONDS` | 0.25 | how much of the flinch a RUNNING animal shows, so the bolt is what the player sees |
| `MODEL.HIT_FADE_SECONDS` | 0.03 | a hit and a death CUT in; a gait blends over `FADE_SECONDS` 0.15 |
| footsteps audible to | 45 / 70 / 90 studs (walk / trot / run) | Karen's requirement is hearing them before seeing them; the shooter line is ~12 studs off the road in the quick test and boars are released 1,300 studs away in the real drive, so this is "the last few seconds of approach". Per gait rather than one number, because a walking boar at 45 studs is a noise in the brush and a galloping one at 90 is something coming -- and because `makeSound` reads the range off the row, so a shared one two levels up resolved to `nil` |
| footstep `baseSpeed` | the clip's own `groundStudsPerSecond` | referenced, never copied: both the loop and the animation are rated by `speed / baseSpeed`, so a re-measured clip moves its sound and its legs together. The spec asserts the two rates are equal at every speed a boar can reach |
| grunt interval | 3-8 s | the Director's brief |
| pitch jitter | +-8% | the Director's brief: repeats must not sound looped |

Every id, volume, range and interval lives in `Boar.CONFIG.SOUND` so it can be swapped without
touching code, and the ids are the Director's provisional ProSoundEffects picks (Karen delegated
the choice).
