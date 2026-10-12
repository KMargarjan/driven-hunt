# The drive's signals: 15 seconds to find a stand, and three horn calls at each end

Task 163. Karen, 2026-10-12 ~10:40, verbatim:
*"for hunter a bit more time like 15s to find a place / when hunt starts 3 longer horn calls and when
ends the same"*.

## 1. What the system must do

1. A hunter gets **15 s** to pick a place to stand at the start of a drive, not 10.
2. At **GO** and at the **end of a drive** -- both endings, the clock and the beaters' crossing --
   **three long horn calls** that **everybody** hears at the same moment, wherever they are standing.
3. One owner for the drive-wide sound, and no second writer of the horn's voice.
4. Numeric targets: timer 15 s; three notes; each note long enough to read as a CALL rather than as
   the beater's beep (the dispatch asked for ~1.5-2 s); short gaps between them; nothing added to the
   inbound exploit surface (today it is zero).

## 2. Sources: what the real signal is

Three German hunting pages, all read on 2026-10-12. None is a library and none has a licence to
record -- they are reference pages, not code, and this section is here because the FORM of the signal
came from them.

| Source | What it gives | Good | Bad |
|---|---|---|---|
| [waidwissen.com -- Jagdleitsignale](https://waidwissen.com/lexikon/jagdleitsignale) | the list of *Jagdleitsignale*: *Aufbruch zur Jagd*, **Anblasen des Treibens**, *Treiber in den Kessel*, *Hahn in Ruh*, *Sammeln der Jaeger* | names the start-of-drive signal exactly, and says these are the signals a hunt is COMMANDED with | no note lengths, no notation, no date on the page |
| [jaegerschmiede.de -- Jagdsignale](https://www.jaegerschmiede.de/jagdlexikon/jagdsignale/) | the same **Anblasen des Treibens**, plus the end-of-hunt signals *Jagd vorbei - Halali* and the *Totsignale* | independent confirmation of the name; shows the hunt's END is signalled too | lists no *Abblasen des Treibens*; no lengths; no maintainer named |
| [hegering-hitzacker.de -- Jagdhornsignale](https://www.hegering-hitzacker.de/jagdhornsignale.php) | the fullest list: 16 *Jagdleitsignale* including **Anblasen des Treibens**, *Laut treiben*, *Aufhoeren zu schiessen*, *Sammeln der Jaeger*, and *Jagd vorbei und Halali* among the general signals | a real Hegering's own list, so it is what is actually blown | again no note lengths |

**What the sources settle, and what they do not.** They settle that a drive is OPENED with a named
horn signal (*Anblasen des Treibens*) and that its end is signalled as well, and that both are heard
by the whole party at once -- which is exactly Karen's sentence. **They do not give a note length or
a transcription**, so **"three long notes" is a stylisation of the form, not a transcription of the
signal**, and the length below comes from the asset instead. Said plainly because rule 8 asks for it:
nobody on this project has heard the real signal, and a Fuerst-Pless transcription would need sheet
music none of the three pages carries.

## 3. Sources: the pattern borrowed in code

Nothing new was invented for either half (rule 2).

| Pattern | Taken from | Why |
|---|---|---|
| the cut measured off the asset's own loudness | `docs/research/2026-10-11-beater-kit.md` section 5.4b and `Horn.CONFIG.SOUND_START`/`SOUND_CUT` (tasks 152 and 154, this repo) | the same 60.63 s asset, the same instrument (`Sound.PlaybackLoudness` at render rate), and the same rule that the cut must land in the clip's own silence so the stop cannot click |
| the signal rides the existing feed | `Drive.remotes().MatchEvent` plus `Hud.feedTextFor` returning nil for an entry another owner draws (task 124 round 3, this repo) | `MatchEvent` is already a server -> client one-shot every client hears; a second RemoteEvent for one word would be a second wire answering a question this one answers |
| a pure plan the player walks | `Horn.playSeconds` / `MapGen.Layout` + `MapGen.Props` / `Weapon.Shape` + `Weapon.Hardware` (this repo) | "three notes, this long, this far apart" becomes one assertable statement in a data file instead of a schedule inside a sound function |

## 4. The pattern adopted

**The server says WHEN, one data file says WHAT IT SOUNDS LIKE, one client module PLAYS it.**

* `Match.Phase` (pure) emits **one `signal` feed entry** -- `text = "start"` in `enterRunning`,
  `text = "end"` in `enterScoring`. Both are single-exit doors, so one drive cannot signal twice:
  `Assigning` has exactly one exit, and the clock ending and the beaters' crossing both come through
  `enterScoring`. `Match.CONFIG.SIGNAL_ENABLED` is the whole gate, read by the pure machine, so both
  states are reachable by parameter.
* `Horn.CONFIG.SIGNAL` holds the note (`START`, `CUT`), how many (`NOTES`), the `GAP` and the
  `VOLUME`, beside the beater's own beep in the file that already owns this asset's id -- so the
  asset id is still written down exactly once. `Horn.signalPlan` turns them into a pure plan.
* `Hud.Sound` plays it, 2-D at the ear, one reused Sound, one thread, and refuses a second signal
  while one is sounding. It is already "THE ONE WRITER of the Hud's own 2-D feedback sounds".

**Why not on the server.** A sound everybody hears at once can be one Instance in the world that
everybody is near, or one per client at its own ear. Nobody is "near" the start of a drive, and
`Weapon.Horn` already owns the positional blast on a beater's Tool -- a second server-side horn would
be a second writer of the same voice (rule 3).

**Why no feature flag.** A plain `SIGNAL_ENABLED` boolean, which is the call task 159 made for
`SCENE.ENABLED`: this is not an experiment whose default has to be decided, it is a thing Karen asked
for in her own words. And the client half could not read a flag anyway -- an override is an attribute
on `ServerStorage`, which no client sees.

## 5. The measurement: which note, and why that one

`Sound.PlaybackLoudness` sampled at render rate in a Play session of the DEV place, 2026-10-12,
`rbxassetid://9038902877` ("Hunting Horn", APMOfficial, the asset task 152 verified public).
`IsLoaded = true`, `TimeLength = 60.630204`. Peak per bucket: **0.05 s over all 60.63 s** (1,210
buckets), then **0.02 s over four candidates**. Task 154 measured only the first 5.2 s; this swept
the whole clip.

**It cannot be measured in Edit mode, which is new and worth writing down.** A `Sound` parented in
the Edit DataModel reports `IsPlaying = true` and then `TimePosition = 0` and
`PlaybackLoudness = 0` for ever -- measured, ten samples over 2 s. The whole sweep therefore runs in
a Play session, the same place task 154 used.

**Long runs over the whole clip** (threshold 60 of 1000, length in seconds):

| start | end | length | peak | single note? |
|---|---|---|---|---|
| 2.75 | 4.25 | 1.55 | 418 | no -- task 154's 0.02 s sweep splits it at the 3.38 valley; the note itself is 1.00 s |
| 13.10 | 15.35 | 2.30 | 325 | **no** -- dips to 162 at 14.10 and 119 at 14.72: slurred notes |
| 16.95 | 18.30 | 1.40 | **517** | no -- two notes; the louder is 17.54-18.38, **0.85 s** |
| **23.40** | **25.80** | **2.45** | 214 | **YES** |
| 31.15 | 32.30 | 1.20 | 335 | not sampled finely; shorter than the one above in any case |
| 45.10 | 46.15 | 1.10 | 493 | no -- further attacks at 45.90 and 46.08 |
| 51.45 | 52.80 | 1.40 | 366 | not sampled finely; shorter |
| 55.40 | 57.20 | 1.85 | 157 | not sampled finely; the quietest run in the clip |

**The chosen note, at 0.02 s:**

```
23.00-23.36  two short notes dying away (177 -> 27)   the end of the previous phrase
23.38-23.40  the attack (48 -> 128)
23.44-23.70  up to its peak (147 -> 214)
23.70-25.90  ONE SMOOTH DECAY, no second attack anywhere in it (214 -> 50)
25.90-26.30  the last of the tail (50 -> 11)
26.30-28.00  the clip's own silence (6-11)
28.05-       the next phrase starts (202)
```

**`SIGNAL.START = 23.36`, `SIGNAL.CUT = 26.3`** -- 2.94 s, of which ~2.6 s is sound. The start sits
0.02 s before the attack, so the horn sounds on the cue; the cut sits inside the clip's own silence
and before the next phrase, so the stop cannot click and one note is never two. **`GAP = 0.2`**: each
note already ends with ~0.4 s of tail, so what is heard between two notes is about half a second.
Whole signal: 3 x 2.94 + 2 x 0.2 = **9.22 s**, which fits inside both the 15 s countdown it starts at
the end of and the 25 s results scene.

**THE DISPATCH'S NUMBER MOVED AND IT IS SAID PLAINLY** (the way task 152 said the cooldown moved):
it asked for ~1.5-2 s a note and this is 2.94. The clip holds exactly one sustained note and that is
its length. The two ways to shorten it are both worse -- stopping at 25.2 cuts the note at 44% of its
peak, which clicks, and fading it out means a second writer ramping the Volume of a sound this module
owns.

**NOT HEARD.** These numbers are measured, not listened to. Whether three notes of this length feel
right is Karen's judgement, and the note, the count, the gap and the volume are all one-line data
changes.

## 6. The timer

`Match.CONFIG.INTERMISSION_SECONDS` 10 -> 15, archived in
`backups/2026-10-12_task163_intermission_10s.txt`. It stays **one number for three things** (task
158's decision): the start card's life, the hunter's stand timer and the beaters' hold at their line
all count the same `phaseEndsAt` down, and nothing in Karen's sentence asks to split them. The start
card is up 5 s longer, so it is no less readable; a beater stands 5 s longer against the 120 s walk
task 162 measured.

## 7. What this note does not cover

* Whether the two signals should eventually DIFFER (*Anblasen* and the end-of-hunt signals are
  different signals in the sources). Karen's words are *"when ends the same"*, so today they are the
  same cut; the wire already carries the word, so the day they differ is a change to
  `Horn.CONFIG.SIGNAL` alone.
* A signal a player can blow on purpose (*Aufhoeren zu schiessen*, *Sammeln der Jaeger*). Not asked
  for.
