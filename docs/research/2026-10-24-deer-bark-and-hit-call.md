# The red deer's alarm bark and its hit call, out of two CC0 field recordings (task 257)

Karen, 2026-10-24, verbatim: *"redsatg sound whn hit and when near need corection better real"*.

Two cues, not one — the sound a red deer makes **when you are near**, and the sound it makes **when
it is hit** — and the word that decides the whole note is *real*. Both are library stand-ins today:
the bark is two "Bull Breaths" samples and the hit is a pig-free but bovine pair of "Bull Bellows",
chosen in task 240 because *there is no red deer in the Roblox audio library* and that was measured
twice (fourteen keyword searches, then thirteen more on 2026-10-23; not one row named deer or elk).

## 1. What the system must do

1. Play a **real red deer** on both cues, from recordings this project may legally upload.
2. Play **one short event** of each recording, not the recording: the bark is 2 minutes 57 of a
   forest edge and the hit call is 34 seconds of a rut. Neither is a cue.
3. Vary which event, so five cues in a drive are not one sample five times.
4. Sit inside the budgets the world already books a voice for — `CROWD.SQUEAL_SECONDS` 1.2 s against
   `CROWD.MAX_SQUEALS` 2 — so a barking deer cannot silence a dying one.
5. Be **as loud as the sound it replaces**, measured and not guessed. A field recording is not a
   production sample.
6. Keep the library samples as a **revert path**, reachable by deleting one id from one list.
7. Change **no boar**.

## 2. The sources

| # | Source | Licence | Maintenance |
|---|---|---|---|
| 1 | [Freesound 795554, *"Deer barking"* by Katerios](https://freesound.org/people/Katerios/sounds/795554/) | **CC0 1.0** (verified on the sound page, 2026-10-24) | Freesound is live and maintained; the upload is static |
| 2 | [Freesound 653533, *"Deer rut - Brame Cerf 02.wav"* by L.Finck](https://freesound.org/people/L.Finck/sounds/653533/) | **CC0 1.0** (verified on the sound page) | as above; the second take of the session task 254's roar (653532) came from |
| 3 | [Roblox, `Sound.PlaybackRegion` / `PlaybackRegionsEnabled`](https://create.roblox.com/docs/reference/engine/classes/Sound) | engine API, Roblox Terms | current engine, documented |
| 4 | [Roblox, `Sound.PlaybackLoudness`](https://create.roblox.com/docs/reference/engine/classes/Sound#PlaybackLoudness) | as above | as above |
| 5 | [countydeerstalking.co.uk, *"Deer Vocalisations"*](https://www.countydeerstalking.co.uk/deer-vocalisations/) | editorial, read not copied | live; the source task 240's whole voice table is built on |
| 6 | [wildlifeonline.me.uk, *"Red Deer Breeding Biology"*](https://www.wildlifeonline.me.uk/animals/article/red-deer-breeding-biology) | editorial, read not copied | live |
| 7 | [python-soundfile](https://github.com/bastibe/python-soundfile) over libsndfile, used offline only to MEASURE | BSD-3-Clause | maintained; 0.14.0 here, nothing of it ships |
| 8 | This repository's own `ForestTest.ROAR` (task 254) | ours | the pattern being borrowed |

**What each does well and badly.**

- **(1) the bark.** Does well: it is a real deer barking, in a European forest, with the barks
  isolated enough to cut. Does badly: it is **quiet** — a 2:57 field recording whose floor is
  −53.2 dBFS and whose best bark peaks −24.8 dBFS — and most of its loud passages (123–155 s) are
  dense sequences of barks and wind rather than single events. Four usable single barks came out of
  93 gated events.
- **(2) the hit call.** Does well: loud (peaks −16.7 to −20.1 dBFS), clean, and four of its calls
  are isolated with a quiet margin at both ends. Does badly: it is a **rut bellow**, not a distress
  scream — there is no CC0 recording of a wounded red deer that I could find — and it is **male**,
  so it can honestly be the stag's voice and not a hind's or a calf's. It is also the same session
  as the roar the player already hears from the far wood.
- **(3) `PlaybackRegion`.** Does well: it is the engine's own answer to "play seconds *a* to *b* of
  this asset", honoured to a hundredth of a second (measured in task 254 and again here). Does
  badly: it is **sticky on a reused Sound** — set once and never cleared, it clips the next sample
  that Sound plays — and `Play()` resumes from `TimePosition` rather than from the region start.
  Both are handled in `Body.playOneShot` and both are the reason this is code and not data alone.
- **(4) `PlaybackLoudness`.** Does well: the only way to compare two assets' levels without ears.
  Does badly: **it reads 0 in Edit**, and task 254 measured that **it does not scale with
  `Volume`** (vol=1 peak 88, vol=0 peak 87) — so "IsPlaying and PlaybackLoudness > 0" would pass a
  cue faded to silence. Every claim here therefore pastes the **sampled `Volume`** beside it.
- **(5), (6) the literature.** Does well: it is what decided task 240's table and it decides this
  one's narrowing — a stag *"will give a loud warning bark if it senses danger"*, a hind answers
  with *"a louder nasal bleat, not dissimilar to that produced by sheep"*, and a calf's call is
  *"a softer bleat"*. Does badly: nothing in it is a number.
- **(7) soundfile.** Does well: sample-accurate, offline, repeatable over the exact bytes the
  manifest's sha256 names. Does badly: it cannot tell you what Roblox will do with the asset, which
  is why every offline figure here is checked against a live `TimeLength` and a live
  `PlaybackLoudness`.

## 3. The pattern adopted, and why

**Borrowed whole from `ForestTest.ROAR` (task 254), which borrowed it from the engine.** A long
recording plus a table of measured regions, one picked at random per cue, played through
`PlaybackRegion` with a fade at each end and a per-region `gain`. Nothing is invented; what is new
is only *where it lives*.

Three decisions had to be taken on top of it, and each is a decision rather than a default:

1. **The bark becomes its own cue (`SOUND.BARK`).** Task 251 part 2 played the edge-check bark out
   of the animal's own `cry` row and wrote down why: *"a kind that barks already has the right
   sample"*. That stops being true the moment the hit cue becomes a real distress call — one row
   cannot be both — and Karen's sentence names two sounds. So `bark` joins `cry`, `death` and
   `grunt` in `VOICE.APPLIES`, gets a Sound per animal like every other one-shot, and
   `Runtime:check` plays it instead of `cry`.
2. **`VOICE.CLIPS` is keyed by asset id, not by cue.** The same recording may serve two kinds (the
   bark does), and the correction a long recording needs is a fact about the *recording*. The cue's
   own dial stays the row's `volume`; `gain` multiplies it.
3. **The hit call is the STAG's, not every deer's.** The dispatch asked for *"the deer kinds'
   hit/death voice"*. The recording is a male rut bellow, Karen's word is *"redsatg"*, and sources
   5 and 6 say a hind and a calf bleat. Giving either of them this call would be a regression for a
   kind nobody complained about. **Stated as a narrowing, in the request and in a spec case**, so
   it is a decision on the record and one data row to reverse.

**The one thing deliberately NOT borrowed:** task 254 wrote its own fade with `TweenService`
(`ForestTest.roarFade`). Here the fade is the cut machinery `Body` has had since task 120 —
`handle.cutIn` plus `Body.cutVolume`, stepped on Heartbeat — with a fade **in** added to it. A
second fader on an animal's Sound would be a second writer of a property `Body` owns (rule 3), and
`stepCuts` already runs for every animal on every frame, carcass included.

## 4. The numeric targets, and what was measured against them

**Method.** Events found offline on the uploaded bytes (the sha256 in `assets/uploads.json`) as a
50 ms RMS envelope smoothed with a 200 ms running max and gated 6 dB over each recording's own
floor — task 254's method. Levels then measured **live**, in a Play session on 2026-10-24
(`<runs-dir>/t257-loud.luau`): every Sound at `Volume = 1`, parented to `SoundService`, peak
`PlaybackLoudness` sampled every frame across the region, so the only difference between two
numbers is the recording.

| Target | Figure | Result |
|---|---|---|
| the asset loads and its timeline is the file's | `TimeLength` = the offline duration | **177.3483 s** and **34.0000 s**, to four decimals. An offline cut is therefore legal |
| 3–4 events per cue | the dispatch's ask | **4 and 4** |
| a bark is 0.4–1.2 s | the dispatch's ask | events 0.70–1.00 s, regions 0.94–1.24 s with margins |
| a hit call is 0.6–1.5 s | the dispatch's ask | events 1.05–1.30 s, regions 1.43–1.78 s with margins |
| a cue never outlasts its booking | < `SQUEAL_SECONDS` 1.2 s | bounded by `voiceCut` ∩ the region: 1.05 s for a bark or a reaction, 0.6 s for a death, at the **slowest** jitter |
| a fade never touches the event | fade ≤ the quiet margin | bark 0.12 s against margins 11.2–16.0 dB down (head) and 5.0–13.1 dB (tail); hit 0.15 s against 6.5–8.7 dB and 6.8–9.9 dB |
| the bark is as loud as the bark it replaces | mean heard level of the four samples the two barking kinds play today = **49.8 units** (0.9 × 43.1, 44.0, 63.5, 70.7) | region peaks 29.7 / 25.5 / 23.3 / 19.0 → `gain` **1.86 / 2.17 / 2.37 / 2.91** |
| the hit call is as loud as the voice it replaces | mean heard level of the stag's four samples today = **93.3 units** (0.9 × 43.1, 44.0; 0.85 × 131.5, 215.4) | region peaks 63.2 / 58.1 / 58.2 / 63.0 → `gain` **1.69 / 1.83 / 1.83 / 1.69** |
| pitch | the recording **is** the animal | `pitch = 1` on both clips, overriding the kind's 1.15 (a bull is three stags) and 0.80 (a lamb is a third of a hind). The ±8 % jitter still rides |

**Two honest consequences of the level arithmetic, written down because they are changes Karen did
not ask for and will hear.**

- The four library samples the stag's voice ships today are **11.5 dB apart** for one animal (his
  cry peaks 43, his death 215). One recording at one level cannot keep both, so at the mean the
  **reaction gets about 7.7 dB louder and the death about 4.2 dB quieter**. That is the correction
  — one animal, one voice — but it is a change in two directions and only ears can judge it.
- The stag and the hind now **bark at the same pitch**, where their library samples differed,
  because `pitch = 1` is the only honest centre for a recording of the animal itself. One number
  per kind on the clip would part them again if Karen asks.

## 5. What is NOT proved here (rule 8)

Nobody in this toolchain can hear a Sound. What is measured is that the assets load, that their
timelines match the bytes, that `PlaybackRegion` is honoured, that the regions are loud and that the
`Volume` under them is non-zero. **Whether a 2:57 forest recording cut to 0.9 s reads as a deer
barking at you, and whether a rut bellow reads as an animal that has just been hit, is Karen's ears
— and the second one is the likelier of the two to come back.**
