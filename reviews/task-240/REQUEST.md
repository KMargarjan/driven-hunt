# Task 240 — the red deer feel right: its own hit sound, clean running, a little tougher

Task: 240
Round: 2
Base: `8db54c4f` (main, after #219)
Code commit: `d480d91c921b328297405ed1fad84210cdb36875`

```
[harness] PASS: 34/34 checks @ d480d91c921b328297405ed1fad84210cdb36875 (clean tree) scope=all
```

`test2` is **N/A**: not one changed path is in `TWO_PLAYER_PATHS` (`tools/agents.py`). The change is
`src/server/Boar/init.luau`, `src/server/Boar/Body.luau` and `tests/server/deer.spec.luau` — the
animal, not the match, the drive, the tie or the teams — and a deer's voice, gait and width answer
the same question with one player as with two.

Only paperwork changed after the last code commit `05af0e0a`: `TASKS.md` and
`reviews/task-240/RESULT.md` (`git diff --name-only 05af0e0a..HEAD`). The code commit named above is
that later paperwork commit, which the harness line names and which therefore covers everything the
code commit did.

## What changed

Karen, 2026-10-22, after playing the Forest Test: *"deer sound has to bee when hit now it seems it's
pig sound when I hit deer / deer running is a bit odd and seems it hitting trees be sure all correct
and nice / deer need more hits before die a bit more like 20% more"*.

* **The voice.** `SOUND.VOICE.stag/.hind/.calf` carried the BOAR's pig-squeal ids, pitched — task 223
  shipped that and wrote it down as a known compromise. They now carry Bull Bellows / Bull Breaths
  (stag, pitch 1.15) and Lamb "Deep Baa's" (hind 0.80, calf 1.25), each with its own `cut`.
* **The gait band.** `SPECIES.reddeer.MODEL_OVERRIDES` (new) is the four keys a deer really brings;
  `Boar.speciesConfig` lays them over the **world's** `MODEL` instead of replacing it with a clone of
  the module's.
* **The width.** `KINDS[kind].drawnWidthStuds` (new, all seven kinds, measured),
  `MOVE.AVOID_CLEARANCE_STUDS` (new), `Boar.avoidRadius` (new, pure), read by
  `Runtime:_avoidTurnFor`.
* **The toughness.** `toughness = 1.2` on the three deer kinds.
* **Round 2 only:** `Body.voiceCut` (new, pure), `SOUND.VOICE.LENGTHS` and `.CUE_CUT_SECONDS` (new
  data), `fade` on `SOUND.CRY` and `SOUND.GRUNTS`. Claims 12 and 13.

Everything was measured in Karen's own place (the Forest Test, live Play, real drives) before it was
changed, with the boar as a control. Note: `docs/research/2026-10-22-deer-voice-and-run.md`.

---

## Claims

**1. No deer cue can share a sample with any boar cue, kind by kind and cue by cue — and that is
what Karen heard.**
Verify: `tests/server/deer.spec.luau`, *"shares no sample with any boar cue, kind by kind and cue by
cue"* — it collects every id any boar can make (the four boar `VOICE` rows **plus** `SOUND.CRY.ids`,
`SOUND.DEATH.ids` and `SOUND.GRUNTS.ids`, because falling back to the generic set is how the deer got
pig squeals in the first place), then asks `Boar.voiceIds` — the function `playOneShot` really calls
— for all three kinds x all three cues and fails on any intersection. It also asserts each kind gets
its **own** list by identity, so a silent fallback cannot pass.

**2. It was proved on a real shot in Karen's own place, not only in a spec.**
A stag was killed through the real `FireRequest` path in the Forest Test (deer licence bought from
the shop by the client, slug, tool equipped in the character). Read off the live `Sound` instances in
the animal's own `Sounds` folder — the ones `Body.playOneShot` writes:

```
before any hit:  cry=9117369876 speed=1.00 | death=9117369876 speed=1.00   (Pig Squeals 1)
after the hit:   cry=9113629809 speed=1.18 | death=9113626628 speed=1.22   (Bull Breaths 4 / Bull Bellows 7)
```

Verify: `<runs-dir>/240-voice-PROOF.txt`. The speeds are `VOICE.stag.pitch` 1.15 x the +-8 %
`PITCH_JITTER`. **Provenance, stated:** that run was taken at the round-1 code commit. Round 2
changed only how LONG a deer cue may sound (`Body.voiceCut`, applied after the `SoundId` is written),
not which sample plays, so the reading stands — and claims 12 and 13 cover the new behaviour.

**3. Every id was loaded and timed in a live session before it was written down, and the lengths are
DATA.**
Eighteen ids — every sample any `VOICE` row or any generic cue row names — through
`ContentProvider:PreloadAsync` on the client in a live Play session: all `IsLoaded = true` with a
real `TimeLength`. Those numbers are now `SOUND.VOICE.LENGTHS` rather than a comment. Verify:
`<runs-dir>/240-audio.txt` and `240-audio2.txt`, and claim 12 for the spec that holds the table
honest.

**4. There is no red deer in the Roblox audio library, and that is a measurement, not an assumption.**
Fourteen keyword searches of `apis.roblox.com/toolbox-service/v1/marketplace/3`, filtered to the
three creators whose audio plays in anybody's experience, return not one row named deer or elk;
everything the catalogue returns for "deer" is user-uploaded and private since the 2022 audio-privacy
change. Verify: `docs/research/2026-10-22-deer-voice-and-run.md` §2B and the tools that produced it
(`<runs-dir>/240-sfx.py`, `240-sfxraw.py`). The samples that DID ship are chosen from what the
literature says a red deer sounds like — *"very similar to the bellow of a bull"* and *"a louder nasal
bleat, not dissimilar to that produced by sheep"*, both quoted with links in §2A. A CC-licensed
recording is `ESCALATE.md` / NEEDS KAREN, and **no CC0 one exists** — both Freesound hits are CC
**BY**, which this repo already measured as non-sublicensable against Roblox's terms.

**5. The stag was being drawn TROTTING while he bolted, because the world's gait band never reached
him.**
`ForestTestBoot` sets `model.RUN_FROM = (TROT_SPEED + pace.RUN_SPEED) / 2 = 21` on a clone of
`Boar.CONFIG.MODEL`, with its own reason on it; `Boar.speciesConfig` then **replaced** `MODEL`
wholesale with `SPECIES.reddeer.MODEL`, a clone of the *module's* table, so the deer kept 28 while
bolting at `PACE.RUN_SPEED x wary.runScale` = 24 x 1.18 = 28.32 — 1.1 % of margin. MEASURED over two
70 s windows of real drives, samples at >= 20 studs/s drawn at the wrong gait: **8 of 13 (62 %) and
8 of 68 (12 %)** for the stag, against 1.7 % / 2.0 % for the hind and the calf (whose edges scale by
`clipScale` to 25.2 and 18.9) and 2.1-3.4 % for every boar kind. Verify: `<runs-dir>/240-before3.txt`
(`at>=20studs/s run=5,trot=6,walk=2` and `run=60,trot=8`) against `240-after1.txt`
(`at>=20studs/s run=98,trot=3` — **3.0 %**).

**6. The fix is an overlay, and no boar number moves.**
`Boar.speciesConfig` now builds `out.MODEL` as `table.clone(config.MODEL)` with
`row.MODEL_OVERRIDES` laid over it, falling back to whole-table replacement for a species row with no
overrides. Verify: `tests/server/deer.spec.luau`, *"hands a deer its own trunk, zones and clips"*
(every override wins; `ANIMATION_IDS` and `CLIPS` are still the **same tables** the boot script
fills, which a copy would have broken) and *"takes the WORLD's gait band, not the module's, so a
bolting stag is drawn running"* — which drives a world with `RUN_FROM = 21` by parameter, walks all
three kinds through `Boar.gaitBands`, demands > 20 % of margin between the bolt speed and the band
edge, and then asserts the **un-fixed** state is still reachable (1.1 % of margin on the module's
config), so both branches are tested. `Boar.speciesConfig` is still the identity by reference for
nil, `"boar"` and an unknown species — the existing case is unchanged. Harness note:
`deer-240: stag bolts at 28.32 studs/s, run band from 21.00 (margin 26%)`.

**7. A stag is DRAWN nearly twice as wide as the box he collides with, and the avoidance sweep was
narrower than his own antlers.**
MEASURED off each kind's loaded `MeshPart.Size` in a live drive: stag drawn **3.47** against a
**1.80** collision box (1.93x); every boar is drawn **narrower** than its box (male 1.40 against
2.00). So a stag's body clears a trunk by 0.70 studs while his antlers are 0.84 studs inside it, and
`MOVE.AVOID_RADIUS_STUDS` was 1.60 — less than his drawn half-width of 1.735. Verify:
`<runs-dir>/240-before3.txt` and `240-after1.txt`, the `drawn ... vs box ...` field on every kind.

**8. The new radius widens the stag and leaves every boar at 1.600 to the last decimal.**
`Boar.avoidRadius(kind, config)` = `max(AVOID_RADIUS_STUDS, max(drawnWidthStuds, BODY_SIZE.X) / 2 +
AVOID_CLEARANCE_STUDS)`. Verify: `tests/server/deer.spec.luau`, *"sweeps for trunks as wide as the
animal a player SEES, and leaves every boar at 1.6"* — all four boar kinds, `nil` and an unknown kind
at `AVOID_RADIUS_STUDS`; each deer kind through the config it really lives by (`Boar.kindConfig`, the
same table `_avoidTurnFor` is handed); the stag asserted to be strictly greater and equal to
`3.47 / 2 + 0.6`; and **every kind in `CONFIG.KINDS.ORDER`** required to carry a `drawnWidthStuds`
(round 1's note: it walked the file's own literal, which a new kind would not be added to). The
harness note confirms it live: `deer-240 avoid radius: stag drawn 3.47, radius 2.335 | hind drawn
2.01, radius 1.605 | calf drawn 1.23, radius 1.600`.

**9. Deer trunk contacts fell by an order of magnitude, with a control that did not.**
The metric is the engine's own — a `Touched` event on the animal's collision body against a
**colliding, non-animal, non-terrain, non-character** part, the definition `MOVE.COUNT_CONTACTS`
already uses. Per animal per 70 s window:

| | before | after |
|---|---|---|
| deer (stag + hind + calf) | **4.5** (18 touches / 4 animal-windows) | **0.43** (3 / 7) |
| boar male | 5.0 (95 / 19) | 3.8 (92 / 24) |
| boar female | 2.4 (19 / 8) | 1.4 |
| boar cub | 2.3 (74 / 32) | 2.9 |

Verify: the `TOUCHED solid non-animal ... over N animals` lines in `<runs-dir>/240-before3.txt`,
`240-after1.txt` and `240-after-BANDED.txt`. **The control is the point**: the boar numbers move by a
third in both directions between runs, which is the noise floor of a randomly generated wood; the
deer number falls by an order of magnitude and the mechanism is specific and measured (claim 7). The
samples are small (one to two animals per kind per window) and the research note says so.

**10. Two things Karen named were measured and found NOT to be deer defects, and nothing was changed
for either.**
(a) **Foot sliding.** `clip.groundStudsPerSecond x clipScale x AnimationTrack.Speed` against the
body's own flat speed, every sample at >= 10 studs/s: deer mean 0.4-2.6 %, boar mean 0.5-2.3 %; the
worst cases are crossfade frames and the **boar's are worse** (+103 % / -87 % against the stag's
-31 %). (b) **Heading against velocity.** Split by speed band: at >= 15 studs/s a hind averages
**2.8 deg** with max 28.5 and **zero** samples over 30 deg, a calf 2.0 deg with zero over 30 — while a
boar **sow** in the 8-15 studs/s band averages **34.3 deg** with a max of 161.5. A running deer does
not crab; the large angles belong to the low-speed transition band and belong to every kind. Verify:
`<runs-dir>/240-after-BANDED.txt`, the `HEADING BY SPEED` lines. Both are written up with their
numbers in the research note §3D and §3E and queued as `TASKS.md` 240a(a).

**11. Twenty per cent more punishment, by the mechanism that already exists, with the vitals still
unarmoured.**
`toughness = 1.2` on stag, hind and calf; `Wound.damageFor` divides a **non-vital** hit's points by
it. Verify: `tests/server/deer.spec.luau`, *"is a fifth tougher than it was, on every one of the
three kinds"* (all three kinds; the three boar kinds still `nil`; the legendary still 2.0; and `nil`
for every deer kind with `KINDS` off, so the flag-off world is untouched), *"leaves the head and the
chest unarmoured and charges the rump and legs a fifth more"* (a chest slug is byte-identical and
still >= `LETHAL`; `rear` and `legs` are exactly `before / 1.2`), and *"names the hits to kill, before
and after"* (computed, never typed, and it fails if anything gets easier). The harness note carries
the table:

```
deer-240 hits to kill: rear/Slug mortal 1 to 2, lethal 2 to 3 | rear/Pellet mortal 5 to 6,
lethal 10 to 11 | legs/Slug mortal 2 to 2, lethal 4 to 4 | legs/Pellet mortal 9 to 10, lethal 17 to 20
```

`Wound.damageFor` has **no range term**, so that table is identical at 20 m and at 40 m; what range
changes is how many pellets land, and buckshot's own `RANGE_STUDS` is 100 studs (28 m), so **at 40 m
no buckshot reaches the animal at all**. The rump slug going 1 -> 2 is more than a fifth and is
**quantisation, not a second decision** (55 points was five over `MORTAL` 50); it is said in the
config, the note, `TASKS.md` and here, because it is the number Karen is most likely to feel.

---

### Round 2 — the two blocking findings

**12. (Finding 1) No deer cue can now hold a voice slot it has already given back, and the budget is
asserted on MEASURED lengths rather than on a comment.**
The Reviewer is right: `CROWD.SQUEAL_SECONDS` (1.2) is a **booking** against `MAX_SQUEALS`
(`Runtime:_claimSqueal` inserts `now + SQUEAL_SECONDS` flat) and `SOUND.CRY` has no `cut`, so a
sample longer than the booking frees the slot while it is still sounding — and the hind's and the
calf's bleats sound for **1.40 s to 1.99 s** at their own pitch. The config's comment claimed the
opposite. Both the comment and the behaviour are fixed:

* `Body.voiceCut(name, kind, spec, config)` is new and pure: a `VOICE` row may carry its own `cut`,
  and it may only make a cue **shorter** — `math.min` against the cue's own — so a deer death is
  still the 0.6 s Karen asked for and never 1.05.
* each deer row carries `cut = CUE_CUT_SECONDS = 1.05`, under the squeal booking **and** under
  `GRUNT_GAP_SECONDS` (which closes round 1's non-blocking grunt note in the same number).
* `SOUND.CRY` and `SOUND.GRUNTS` gain `fade = 0.15`, so a cut cue ENDS instead of being chopped —
  the fault task 120 fixed on the death.

Verify: `tests/server/deer.spec.luau`, *"cannot hold a voice slot it has already given back, on any
deer kind or cue"*. It walks **every kind in `KINDS.ORDER` and every cue**, fails on any id with no
`VOICE.LENGTHS` entry (so an unmeasured id cannot arrive), then computes each deer cue's real
sounding time as `min(LENGTHS[id] / pitch, voiceCut)` and fails on any that reaches its budget. The
harness note is the whole table:

```
deer-240 cue lengths: stag.cry 0.76s stag.cry 0.81s stag.death 0.60s stag.death 0.60s
stag.grunt 1.05s stag.grunt 1.05s hind.cry 1.05s hind.cry 1.05s hind.death 0.60s hind.grunt 1.05s
calf.cry 0.90s calf.cry 1.05s calf.death 0.60s calf.grunt 0.90s
```

**13. (Finding 1, the other half) The cut is on the DEER's rows and nowhere else, so no boar makes a
different noise than it made before this task.**
The boar's 2.54 s squeal is the sound Karen signed off (*"animal react sound is good"*), so putting
the cut on `SOUND.CRY` would have changed an animal nobody asked about. Verify:
`tests/server/deer.spec.luau`, *"cuts only the deer, and never lengthens a death"* — one arm per boar
kind (`VOICE[kind].cut == nil`, and `Boar.voiceCut` returns `spec.cut` for all three cues), one arm
per deer kind (cry and grunt take the row's 1.05; the death keeps `SOUND.DEATH.cut` = 0.6 through the
`math.min`), the two new `fade`s asserted to exist and to fit inside the cut, and the voice-OFF
branch asserted to cut nothing that was not cut before.

**14. (Finding 2) The case that claimed to cover the budget is gone, and what replaced it would have
caught finding 1.**
The old case asserted `DEATH.cut`, `SQUEAL_SECONDS` and `CRY.cut == nil` — all three predate task
240, it named no deer, and it would have passed with the whole task reverted. Claims 12 and 13 are
its replacement; both read `VOICE.<kind>` directly and both fail on the state round 1 shipped (a
1.99 s hind cry against a 1.2 s booking fails claim 12's bound).

**The three remaining round-1 notes are fixed in code** (the research-note filename in the `VOICE`
header; `boar_move.spec` -> `deer.spec` in `Boar.avoidRadius`'s header, which now also says why it
reads `KINDS[kind]` directly; the avoid case walking `KINDS.ORDER`; and the pitch case, whose title
and rationale claimed a size order across two different sample sets — it now asserts three distinct
pitches, the calf above the hind within the one sample set they share, and the hind's samples not
being the sow's). **The other four are queued**, in `TASKS.md` 240a: the stale `docs/design/red-deer.md`
(a design is the Architect's to write, rule 3), the module-level `ANIMATION_IDS` table, the
`Body.kindRow` observation (recorded as unreachable, with the reason now in the function's header),
and the grunt overlap (closed by claim 12, kept as the record).

---

## Looked at, not only counted (rules 5 and F)

`<runs-dir>/240-deer-run-1.png` and `240-deer-run-2.png`: a stag at **28.3 studs/s** — his full bolt
— from a camera **5.0 studs above the ground**, 20 studs to his side, which is a standing player's
eye height. Frame 1 is him galloping through a birch wood with trunks on both sides and one in the
foreground; frame 2 is him side-on with the nearest trunk 13.5 studs off. Both were inspected: the
gallop pose is the RUN clip (which is claim 5's whole point — before the fix this speed drew a trot
at 2.3x), the body is level, and no trunk intersects him or his antlers.

## What could not be verified

* **Nobody in this toolchain can hear a sample.** The bull and the lamb are chosen from two editorial
  sources that say what a red deer sounds like; the peer-reviewed paper on hind and calf
  vocalisations is paywalled and was **not** read. Karen's ears decide, and the ids are one data row.
* **The live hit proof predates round 2's cut** (claim 2 says so). Round 2 changes how long a cue may
  sound, not which sample plays; the spec covers the new behaviour and the Forest Test was closed
  before the gate ran.
* **The trunk-contact numbers are small samples** — one to two deer per kind per 70 s window in a
  randomly generated wood. The boar control is in the table for exactly that reason.
* **`Boar.avoidRadius` hands the hind and the calf the STAG's clearance**, in the same way
  `_avoidTurnFor` has always handed them the stag's `BODY_SIZE`. Conservative, stated, queued as
  240a(b).
* **The stag's cry and grunt are "Bull Breaths", the same library family as `SOUND.BREATH`'s ids.**
  That costs nothing today because `BREATH.enabled` has been `false` since task 123 round 4; it is
  written in the config so whoever turns the breath back on checks it.
* **A pre-existing assert, found and not fixed:** in a 320 s single drive the world fills to
  `maxBoars` and `ForestTest.releaseLine` then calls `Runtime:spawn`, which asserts
  (`ServerScriptService.Boar:5302: Boar runtime is at maxBoars`). Not reachable in a normal-length
  drive; nothing here touches it. Queued as 240a(d).
* **No two-player run**, by the rule in `tools/agents.py`: no changed path is in `TWO_PLAYER_PATHS`.

## Forest Test, read-only

Its `ServerStorage` attributes were read first and last and are **identical**
(`<runs-dir>/240-attrs-first.txt`); nothing was changed in that place. Its window was stopped, left
in Edit and closed before the harness ran, and the harness line names the DEV place
(`[server] report comes from the DEV place (136410205938347)`).
