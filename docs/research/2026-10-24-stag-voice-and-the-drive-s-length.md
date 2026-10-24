# The red stag's voice, and how long a drive has to be to contain him

Task 251 part 2. Karen, 2026-10-23, verbatim: *"we need better saound and behaviour for red stag /
and them patter with animals how many where they come how they come how many groups jumping over
road red stags ect"*, and her `"ok"` to the Designer's plan,
`<runs-dir>/design/driveflow-spec.md`.

**This note covers only what part 2 decided from OUTSIDE the repository.** The behaviour numbers --
the 1.8 notice, the 0.90 edge check, the 2-6 second stop, the 150-degree look back, the 80-160 stud
sneak, the bound -- are the Designer's spec sections 3.1 and 3.2, which Karen read and approved, and
they are not re-derived here. What is here is the audio licence audit (because a licence decision
needs its sources named and linked, and because the answer changed what shipped) and the beater
line's pace (because the Director's instruction and the spec's own band disagreed, and the
disagreement had to be settled against a source rather than a preference).

---

## 1. What the system must do

1. In a drive that carries a stag, the player hears him **roaring in the distance** before he ever
   sees one -- from the far wood, not from an animal on the screen.
2. When the stag sees the player, he **barks once**: the sound that says you have been seen.
3. The sound must be legally clean in a **public repository** and uploadable to Roblox.
4. The drive must be long enough that the fifteen-slot script Karen approved actually plays, with
   the stag's slot among it.

---

## 2. The roar: three external sources, named, linked and licensed

The question is narrow and it has a hard constraint: **Roblox's Terms of Use take from an uploader a
"worldwide, non-exclusive, royalty-free, perpetual, irrevocable, fully sublicensable and
transferable" licence** over what is uploaded. You cannot grant what your own licence refuses to give
you, so a licence that forbids sublicensing cannot be used at all, however good the recording is.
This repository reached the same conclusion once before, for meshes, in
`docs/research/2026-09-26-asset-pipeline.md`.

| # | source | licence, read on the page 2026-10-24 | maintained? | good | bad | usable? |
|---|---|---|---|---|---|---|
| **S1** | [Freesound 653532, *"Deer rut - Brame Cerf.wav"* by **L.Finck**](https://freesound.org/people/L.Finck/sounds/653532/) | **Creative Commons 0** -- *"copy, modify, distribute and perform the sound, even for commercial purposes, all without asking permission"*. **VERIFIED on the page today**, which is the thing the Director's dispatch asked to be checked before anything else | Freesound is active and has been since 2005 | **A real red stag roaring in the rut** (*brame du cerf*), binaural field recording, 52.9 s at 48 kHz 24-bit. It is the animal, not a near-miss | one upload of a 14.5 MB wav, cut by hand; nobody in this toolchain can audition it | **YES, and it is the one to use.** CC0 waives every right, so there is nothing left to conflict with the Roblox grant |
| **S2** | [Freesound 757773, *"Red Deer Stag Bellowing"* by naturenotesuk](https://freesound.org/people/naturenotesuk/sounds/757773/) | **CC BY 4.0** | active | the best-sounding recording found anywhere | clause 2(a)(5)(A) of CC BY 4.0 **forbids sublicensing** | **NO** |
| **S3** | [Wikimedia Commons, *Red Deer (Cervus elaphus) (W1CDR0001424 BD3).ogg*](https://commons.wikimedia.org/wiki/File:Red_Deer_(Cervus_elaphus)_(W1CDR0001424_BD3).ogg) -- British Library, two stags calling, 48 s | **CC BY-SA 4.0** | the British Library's own Wildlife Sounds collection | provenance you can trace to a national library | not sublicensable, **and** share-alike on top | **NO** |
| **S4** | [Sonniss, *ROAR by Stags*](https://sonniss.com/sound-effects/roar-by-stags/) -- 267 files, 244 roars **at varying distances** | commercial, *"Licensee may not transfer, assign, share or sub-lease the licensed sound effects with any other party"* ([licence](https://sonniss.com/license/)) | a commercial library, actively sold | "roars at varying distances" is literally the cue this task needs | **the same no-sublicensing conflict as CC BY** | **NO** -- and that is why **money buys nothing here**: $32 would buy a library this project could not legally upload |
| **S5** | the **Roblox audio library** itself, re-measured 2026-10-23 for the spec: thirteen keywords through `apis.roblox.com/toolbox-service/v1/marketplace/3`, each hit's creator read from `economy.roblox.com/v2/assets/<id>/details`, filtered to the three creators whose audio plays in anybody's experience (Roblox, ProSoundEffects, Audioscape) | already licensed for use in any experience | Roblox's own, maintained | zero legal risk, zero upload, plays today | **95 rows and not one named deer or elk.** The wild-mammal shelf is bull, lion, tiger, elephant, coyote | **YES, as a stand-in** |

### 2.1 What was adopted, and why

**Both, in the order the spec recommends** (section 4.4): ship S5 now, upload S1 next.

`ForestTest.ROAR.ids` holds **four bull bellows from S5**, because the two sentences that decide the
substitution are the literature's own, not a convenience:

* a red stag's rut call is *"very similar to the bellow of a bull"*
  ([County Deer Stalking, "Deer Vocalisations"](https://www.countydeerstalking.co.uk/deer-vocalisations/)),
  and he *"will give a loud warning bark if it senses danger"*;
* October is the peak of the rut and roaring is *"a regular feature of dawn and dusk"* -- which is
  when this game is set (`AUTUMN_LIGHT`).

A bull is therefore not a near-miss chosen for being available; it is the animal the sources
themselves compare a stag to. The same reasoning picked the deer's whole voice table in task 240
(`docs/research/2026-10-22-deer-voice-and-run.md`), and this note does not re-argue it.

**S1 could not be uploaded by this Builder.** `tools/roblox_upload.py` implements **Model and Decal
and refuses Audio** by name -- `CONTENT_TYPES` is a per-type table and `find_model(folder, ..., "Audio")`
raises *"uploads Decal and Model only"*, which its own `selftest` asserts. So the upload is a human
action: `ESCALATE.md` carries it as **NEEDS DIRECTOR** with the file, the cut and the clicks. Karen's
standing OK for free CC0 recordings is on the record (2026-10-23, `"ok"`). When it lands it is one
`ids` row, changed, and nothing else.

### 2.2 The bark is not a new sound, and that is deliberate

Task 240 chose the stag's `cry` samples -- `9113629809` / `9113629973`, "Bull Breaths 4 / 9",
catalogued as *"Bestial Grunts, Bellowing"* -- **expressly as the warning bark**, and wrote that down
at the time. So part 2 adds no id for it: `MOVE.EDGE_BARKS` plays the animal's existing `cry` row at
the edge check. Borrowing the row this repo already verified and listened to beats introducing a
sound nobody has heard (rule 2).

### 2.3 The numeric targets

| target | value | where it is asserted |
|---|---|---|
| roar length | 3-6 s, **no cut** (every other deer cue is cut to 1.05 s because it books a voice slot; this books none) | `forest_line.spec`, "gives the rut roar its own emitter" |
| roar pitch | 1.15, the stag's own `VOICE` pitch -- one animal, one pitch | same case |
| roar reach | **420 studs**, which is 343 + 77 studs of margin. **The spec said 350 and the first live drive proved 350 wrong**: `ROAR 1: the stag answers from the far wood, 401 studs from the stand, audible to 350`. His holding is slot 13's own row -- `sqrt(330^2 + 95^2) = 343` studs before anything is added -- so the spec's range was set without the geometry of the row it was for, and Karen would have heard nothing four times a drive with a console line claiming she had | same case, as arithmetic over two rows of one table |
| how often | 4-5 roars in the first 90 s of a drive that carries a stag, then once at his release | measured: `ROAR 1`..`ROAR 5`, two live drives |
| one at a time | one Sound in the world, server-wide | `ForestTest.roarNow` reads `IsPlaying` |

---

## 3. The beater line's pace: 1.40 m/s was a man walking, 0.87 m/s is a line advancing

The Director's instruction (2026-10-24) was *"lengthen the Forest Test drive to about 210 s by
slowing the beater line ... not by cutting the script"*. The drive's length is a quotient of three
configs in three files, and `bots_lane.spec` has asserted since task 162 that the pace is **1.2-1.5
m/s**, *"a real walking pace for a man working a wood"*. 210 s over the same ground is **0.87 m/s**,
which that band refuses.

**The band was asserting the wrong claim, and the sources say so.** A beater line does not walk, it
*advances*: it stops in thick cover and beats it, and it waits for the men on either flank so the
line stays level, because a line that loses its shape lets game slip between the men.
[Livingactive, *Tipps und Tricks fuer die Drueckjagd*](https://www.livingactive.de/jagd/drueckjagd-tipps/)
-- the same source act I of the drive script is built on (*"the noise of arrival moves the
experienced animals"*) -- puts the slow, level advance at the centre of the practice. An average
advance of about 0.9 m/s is therefore a slow walk with stops in it, which is what a beater line is;
1.2-1.5 m/s is what one man does between the stops.

So the band became **0.8-1.5 m/s**, with that sentence on it, and the ceiling did not move: 2.52 m/s
(the 9 studs/s this shipped with, which ended a drive at 0:29) is still a failure.

**Moving the line further back instead was measured and refused.** 210 s at 5 studs/s needs 1,050
studs of travel. Measured in this place on 2026-10-12, the trees run out at **775-850 studs** north
of the road and the terrain past that is bare hillside -- so the wood cannot hold the walk, and a
beater line starting on open ground is something Karen would see. Part 1's escalation lists this as
option B and calls it out of bounds for the same reason.

**What was checked rather than assumed:** the feet do not slide at the slower pace. `Rig.gait` plays
the walk clip at `speed / NATURAL_WALK_SPEED` -- the engine's own law, measured in task 161 -- so 3.1
studs/s is drawn at rate 0.46, above `GAIT.MIN_RATE` 0.30 and well above `WALK_ABOVE_STUDS` 0.75.
And measured live over two drives: **0 stuck, worst pin 0.0 s, 0 recoveries** on four bot beaters.

### 3.1 The numeric targets

| target | value | measured |
|---|---|---|
| the line arrives in | ~210 s | **210.2 s** and **210.7 s**, two live drives in Karen's place |
| slot 1 | 10 s after the drive opens | `line 3: SLOT 1` at 13.8 s after `[report] drive 1 opened`, sampled at 9 s granularity |
| slot spacing | 13 s | every slot one sample apart across both drives; `[ForestTestBoot] ... waves every 13s` |
| slot 15 | ~192 s | 193.6 s after the drive opened |
| slots that play | **all fifteen** | `SLOT 1` .. `SLOT 15` logged in order, both drives |

---

## 4. The negative result, written down because it is the important one

**Act III of the drive script is released BEHIND the advancing beater line, and the stag is in act
III.** This is not a consequence of part 2 -- it has been true since the script was written -- but
part 2 is the first time a drive ran far enough for anybody to see it.

The line starts at `LINE.spawnNorthStuds + BEATER.behindLineStuds` = **580 studs** north of the road
and advances at 3.1 studs/s from the end of the countdown. So it passes:

| depth | the line passes it at | the row released there is due at |
|---|---|---|
| dz 360 (slot 15) | 86 s | 192 s |
| dz 330 (**slot 13, the stag**) | 96 s | 166 s |
| dz 300 (slot 12) | 106 s | 153 s |
| dz 275 (slot 11) | 113 s | 140 s |

Every act III row is released **30 to 106 seconds after the beaters have walked past its depth**, so
those animals are put down behind the line, meet it head-on when they start for the road, and bolt
north or sideways instead of coming. Measured live: slot 14's two males (dz 290) were **north of
their own spawn** 20-30 studs later; slot 12's nine (dz 300) covered 320 studs **west and south at a
run**; and the stag, released at dz 330, was next seen **53 studs south of the road at a bolt** --
across, but driven by a fright and not by his own sneak.

**So the stag's three new behaviours did not fire in the Forest Test**, and the reason is geometry,
not code: the edge check, the look back and the treeline sneak all happen on a walking approach to
the verge, and he never has one. The arithmetic is decisive either way -- at a walk (4.5 studs/s) his
route to the verge is about **430 studs, or 95 seconds**, and the drive gives him **44**.

This is a design decision and it is one number, so it is `ESCALATE.md`'s and not a Builder's. The
three candidates, with their arithmetic, are there.

---

## 5. What this note does not claim

* **Nobody here can hear any of it.** What is proved is what reaches the engine -- the Sound exists,
  its id, its volume, its roll-off, the point it sounds from and the distance to the stand. Whether a
  bull bellow at pitch 1.15 and 372 studs reads as a stag roaring across a valley is **Karen's ears**.
* The CC0 recording (S1) is **not uploaded**: it is verified, cut-ready and waiting on the Director.
  No asset id is claimed for it. **Superseded on 2026-10-24 by section 6 below** -- it is uploaded
  and it is in the game.
* The 0.9 m/s advance is a reasoned average, not a measured one: no source gives a figure in metres
  per second for a beater line, which is recorded here as a negative result exactly as task 126
  recorded it for the pause at a forest edge.

---

## 6. Amendment, 2026-10-24 (task 254): S1 is uploaded, and the cut is measured, not chosen

Section 2.1 adopted *"both, in the order the spec recommends: ship S5 now, upload S1 next"*. S1 is
uploaded -- asset **122287696922128**, `Audio`, creator 8167651842, moderation **Approved** -- and
`ForestTest.ROAR.ids[1]` is now that id, with the four library bulls kept behind it as the revert
path.

**Two of this note's own sentences have to be withdrawn, and one is withdrawn only in part.**

**(1) *"nobody in this toolchain can audition it"* was wrong, and that mattered.** It is true that
nobody here can judge whether the recording *sounds* like a stag -- that is section 5's point and it
still stands, it is Karen's ears. But the *loudness* of a recording is a measurement, and skipping it
would have shipped a cue two thirds of which was inaudible. Two instruments were available the whole
time:

* **Offline, on the uploaded bytes.** `soundfile` decodes the mp3 the manifest row's sha256 names:
  48 kHz stereo, **52.8965 s**, against the `TimeLength = 52.897` Roblox answers for the asset -- the
  same timeline, which is what makes cutting the file offline and playing the result by region legal.
  A 50 ms RMS envelope, smoothed with a 200 ms running max and gated 6 dB over the recording's own
  forest floor of **-45.2 dBFS**, finds **seven** events. Three are one clean roar of the right
  length with silence at both ends; the rest are a 6.9-second sequence (22.6-29.4 s) or 4-9 dB down
  and choppy.
* **Live, on the asset itself.** `Sound.PlaybackLoudness`, sampled at ~30 Hz on a client in a Play
  session. It answers **0 in Edit at every volume** -- which is how a region that plays nothing
  passes a bench test -- and real numbers in Play.

**(2) The level was the defect this measurement found.** A field recording is not a production
sample. At `Volume = 1` the three regions peak `PlaybackLoudness` **98, 54 and 50**; the four library
bulls the cue shipped with peak **94, 115, 161 and 198** (mean 142). So two of the three roars sit
8-9 dB under the voice Karen has already heard, and at `audibleStuds` 420 with `InverseTapered`
roll-off that is the difference between a roar and nothing. Each region therefore carries a `gain` of
142 over its own peak -- **1.45, 2.63, 2.84** -- which equalises the three to each other and to what
shipped. The means agree within 7 % (28/15/13 against 39.5 give 1.41/2.63/3.04); the peaks are used
because they keep every effective volume at or under 1.0.

### 6.1 The cut, and the numeric targets

| region | seconds of the recording | length | peak | over the floor | `gain` | effective volume |
|---|---|---|---|---|---|---|
| 1 | 0.20 -> 5.20 | 5.00 s | -24.4 dBFS | 20.8 dB | 1.45 | 0.51 |
| 2 | 9.45 -> 14.45 | 5.00 s | -28.2 dBFS | 17.0 dB | 2.63 | 0.92 |
| 3 | 35.60 -> 40.60 | 5.00 s | -28.5 dBFS | 16.7 dB | 2.84 | 0.99 |

* **One roar per cue, never the file**, through `Sound.PlaybackRegion` with
  `PlaybackRegionsEnabled` -- measured as honoured to a hundredth of a second: the client read
  `timePos=35.62..40.59` inside region 3 and `9.48..14.42` inside region 2. Region 1's evidence is
  the server's own line (`region 0.20-5.20 s, volume 0.51`), not a client sample.
* **4-6 s**, which is section 2.3's own target for this cue and the Director's dispatch's.
* **No overlap**, so no roar is ever two entries wearing two names.
* **Pitch 1, not 1.15.** The 1.15 exists because a bull is three times a stag's weight. This
  recording is the animal.
* **0.35 s fade at each end**, and that number is measured too: the roar starts 0.60, 0.65 and 0.80 s
  after its region does and ends 0.60, 0.65 and 1.75 s before it, so neither fade ever touches the
  bellow -- it only shapes the forest noise the region opens and closes on.

### 6.2 And one thing this amendment adds to section 5

**A manifest row's moderation state is a snapshot, not a verdict.** The upload's own row recorded
`"moderationState": "Reviewing"`, because that is what the operation answered while the asset was
still in the queue. A live re-read on 2026-10-24 (`GET /assets/v1/assets/122287696922128`) answers
`Approved` / `Active`, and so does the same operation re-polled. `assets/uploads.json` carries the
re-read state and says where it came from. Carrying the snapshot forward is how a rejected asset
ships as an approved one.
