# Task 257 — the real red deer alarm bark and hit call, wired

Task: 257
Round: 1
Base: `9745293b` (main, after task 256 part 1)
Code commit: `6338c12eef7026f7e09d344c2cab2c7c72b213e7`

Branch `task-257-deer-voices`.

```
[harness] PASS: 34/34 checks @ 6338c12eef7026f7e09d344c2cab2c7c72b213e7 (clean tree) scope=all
```

`[harness2]` is **N/A**. Nothing here touches `TWO_PLAYER_PATHS`: the change is
`src/server/Boar/`, three server specs and docs. No match, no drive, no tie, no teams.

## What changed

Karen, 2026-10-24: *"redsatg sound whn hit and when near need corection better real"*. Two cues, two
CC0 Freesound field recordings the Director uploaded.

- **The alarm bark is its own cue now** — `SOUND.BARK`, `VOICE.<kind>.bark`, a Sound per animal,
  played by `Runtime:check` at the edge check. It was the animal's own `cry` row (task 251 part 2);
  one row cannot be both a bark and a distress call.
- **The stag's hit and death voice** is the second recording, on his `cry` and `death` rows.
- Both play **by region**, borrowing `ForestTest.ROAR`'s pattern whole: four measured events each,
  one picked at random per cue, `Sound.PlaybackRegion`, a fade at both ends and a measured
  per-region `gain`. `Body.voiceClip` is the one reader of `VOICE.CLIPS`.
- The fade is `Body`'s own `cutIn` / `cutVolume`, with a **fade in** added, rather than a second
  writer of an animal's `Sound.Volume`.

## Claims

**1. Both assets are real, approved and the length the data says.** Their upload rows said
`moderationState: "Reviewing"`; both were re-read live as `Approved` / `Active`.
*Verify:* `assets/uploads.json`, the two new rows (`moderationStateFrom`). Live in the Forest Test:
`ASSET 85634523415950 loaded=true timeLength=177.3483` and `ASSET 99831947794105 loaded=true
timeLength=34.0000`, matching `VOICE.LENGTHS` and the offline decode of the bytes whose sha256 the
rows name.

**2. Both upload rows named the WRONG source URL, and the manifest records the correction.** They
carried task 254's roar (`sounds/653532/`) over. The saved pages beside the files title themselves
*"Freesound - Deer barking by Katerios"* (795554) and *"Deer rut - Brame Cerf 02.wav by L.Finck"*
(653533), both linking the CC0 deed, and the sha256s are the uploaded ones.
*Verify:* the `sourceCorrection` and `licence` fields on both rows in `assets/uploads.json`;
`CREDITS.md`, the two new entries under "Sounds".

**3. The bark is its own cue and no boar can reach it.** `SOUND.BARK` is in `Body.oneShotSpecs`, so
it is built, warmed and restored like every other one-shot; `VOICE.APPLIES.bark` is true;
`Runtime:check` plays `"bark"` and `SOUND.BARK`; only `MOVE.EDGE_BARKS` (the stag's and the hind's
`edge` rows) reaches it.
*Verify:* `boar_shot.spec`, *"BARKS when a deer takes the edge check, and a calf and a boar never
do"* — it counts `soundPlays.bark` **and** asserts `soundPlays.cry` stayed nil, which is the line
that fails if the cue is wired back to `cry`. Harness note:
`task257 bark: stag 1, hind 1, calf 0, boar 0 bark play(s) at the edge check`.

**4. A real animal really plays the real recording, by region, at the clip's pitch and the measured
gain.** Read off the animal's own Sound in a live runtime, for the bark and for both hit cues.
*Verify:* the harness notes
`task257 bark: ... stag sounded 85634523415950 region 39.88-41.12 gain 2.37 speed 0.995 volume 0.296`
and
`task257 hit call: cry region 10.20-11.63 gain 1.83 speed 0.920 volume 0.183 | death region 24.75-26.53 gain 1.69 speed 0.959 volume 0.638 | id 99831947794105`.
The cases are `boar_shot.spec`'s bark case and *"gives a REAL stag the real hit call on a wound and
on the death that follows"*, which enters **both** arms through `runtime:takeHit` — a non-lethal
rear pellet (`cry`, the stag still alive) and the head shot that kills (`death`, carcass true).
The sampled volumes are mid-fade-in, which is what a region cue looks like one frame after it
starts; the bound asserted is `0 < Volume <= row.volume * gain`.

**5. Nothing 177 seconds long can ever be played whole.** `Body.voiceClip` plays `ids[1]` by region
when `VOICE.CLIPS` has a usable entry for it, and otherwise picks **only among ids that are not in
`CLIPS`** — task 254's rule, both directions.
*Verify:* `deer.spec`, *"plays ONE measured region of the real recording, over the whole roll"*
(every roll 0.00–0.99 for the stag's bark, cry and death and the hind's bark: the real id, a region
of that clip's own table, every region reachable, every region inside the file) and *"NEVER plays a
clipped id whole, and falls back to the library when the real one goes"* (the documented revert —
delete the first id — answers a library sample and no region; a clipped id anywhere else in a list
is skipped).

**6. No cue outlasts the voice slot the world books it for, measured on the REGION and not on the
file.** `VOICE.LENGTHS` for the two recordings is the whole file, which the old assertion would have
divided by the pitch and compared — passing while asserting nothing about what sounds.
*Verify:* `deer.spec`'s *"cannot hold a voice slot it has already given back"*, which now takes the
longest region at the clip's own pitch for a clipped id; and *"bounds every region by the cue the
world books, and fades inside it"*, which uses the **slowest** jitter and checks two fades fit
inside what sounds. Note: `deer-257 cue budget: stag.bark 1.05s g1.86 ... stag.death 0.60s g1.69`.

**7. The death is still the short one Karen asked for.** `Body.voiceCut` takes the smaller of the
row's cut and the region's own length, so a 1.78 s region cannot lengthen a 0.6 s death.
*Verify:* the arithmetic block at the end of `boar_shot.spec`'s hit-call case
(`deathCut == DEATH.cut`, `deathCut < cryCut < SQUEAL_SECONDS`), and `deer.spec`'s
*"cuts only the deer, and never lengthens a death"*, unchanged.

**8. A region fades in as well as out, and every library cue is untouched.** `Body.cutVolume` grew
an optional third argument; `nil` is every caller written before this task.
*Verify:* `deer.spec`, *"ramps a region in as well as out, and leaves every library cue alone"* —
the three pre-task values unchanged, the ramp up, and both ramps multiplied.

**9. The hit call is the STAG's and NOT every deer's — a deliberate narrowing of the dispatch.**
The dispatch asked for *"the deer kinds' hit/death voice"*. `99831947794105` is a **male rut
bellow**, Karen's word is *"redsatg"*, and the sources this table was built on say a hind answers
with *"a louder nasal bleat, not dissimilar to that produced by sheep"* and a calf with *"a softer
bleat"*. The hind and the calf keep those bleats.
*Verify:* `deer.spec`, *"gives the STAG the real hit call and leaves the hind and the calf their
bleats"*; the comment on `VOICE.hind`; section 3 of the research note.

**10. The new cases fail against the pre-fix code (L-028).** With `src/server/Boar/` reverted and
the specs left in place, the suite is **2213 passed, 13 failed, 13 errors**:

```
failed [server] boar_shot.spec:623  attempt to index nil with 'Volume'
failed [server] boar_shot.spec:1716 attempt to index nil with 'pitch'
failed [server] boar_shot.spec:1777 Expected value "true" (boolean), got "nil" (nil) instead
failed [server] boar_shot.spec:2101 attempt to index nil with 'ids'
failed [server] deer.spec:399       ServerScriptService.Boar.Body:1746: attempt to index nil with 'ids'
TestService: ServerStorage.Tests.deer.spec:482:  attempt to index nil with 'ids'
TestService: deer.spec:1631                      Expected value "nil" to be non-nil   (SOUND.BARK)
TestService: ServerScriptService.Boar.Body:1746  (deer.spec:1676)
TestService: ServerStorage.Tests.deer.spec:1736: attempt to call a nil value          (Boar.voiceClip)
```
*Verify:* `<runs-dir>/257-prefix-fail.txt`.

## Proved on Karen's path, in the Forest Test — and what was NOT

**The bark was heard there.** Forest Test (placeId 130094961655666), read-only: attributes read
before and re-read after and **identical** (`DHFlag_* …  DHForestStartRole=hunter
DHShopTestGrant=true`). A hind took her edge check in a live drive, and both sides agree:

```
server  SRVCUE bark:hind firstAt=446.1s frames=36 id=rbxassetid://85634523415950
        region=39.88-41.12 speed=0.979 timePos=39.908..40.892 peakVolume=2.133
client  CUE    bark:hind frames=7  id=rbxassetid://85634523415950
        region=39.88-41.12 speed=0.979 timePos=39.942..40.701 peakLoudness=13.3 peakVolume=2.133
```

`TimePosition` stays inside the region, so `PlaybackRegion` is honoured on a live animal; the speed
0.979 is the clip's `pitch = 1` inside the ±8 % jitter and is **not** the hind's own 0.80; and
`Volume 2.133` is `BARK.volume 0.9 × gain 2.37` exactly. **`PlaybackLoudness` is pasted with
`Volume` beside it deliberately** — task 254 measured that loudness does not scale with volume, so
loudness alone would pass a silent cue.

**The hit call was NOT heard in the Forest Test, and that is a measurement failure and not a
claim.** Three windows (150 s, 330 s and 620 s) across four drives put one deer party inside the
shotgun's range; 25 shots through `Shotgun.Remotes.FireRequest` landed 18 impacts and **no kill** —
the deer were at 140–158 studs, past buckshot's own 100, and by the time one was at 59 studs the
barrels were empty. The deer release is a roll per drive and the team swaps each drive, so this is a
scheduling problem rather than a code one. The hit cue is therefore proved where the bark's live
half also is: a real runtime in the gate, through `runtime:takeHit` (claim 4).

## What I could not verify (rule 8)

- **Whether either recording sounds right. Karen's ears.** Nobody in this toolchain can hear a
  Sound, and the hit call is a **rut bellow standing in for a distress scream** — there is no CC0
  recording of a wounded red deer. It is also the **second take of the session task 254's distant
  roar came from**, so the animal she hears across the valley and the animal she hears when she hits
  one are the same stag.
- **Two level changes she did not ask for and will hear.** The stag's four library samples are
  **11.5 dB apart for one animal** (his cry peaks 43.1/44.0, his death 131.5/215.4 at `Volume = 1`),
  so one recording at one level makes the **reaction about 7.7 dB louder and the death about 4.2 dB
  quieter**. The arithmetic is in `VOICE.CLIPS`'s comment and section 4 of the note.
- **The stag and the hind now bark at the same pitch**, because `pitch = 1` is the only honest centre
  for a recording of the animal itself. One number per kind would part them again.
- **A 4 MB asset is a first-play fetch.** The bark id is 4,091,435 bytes. The Sound is built with the
  animal and replicates well before a deer reaches an edge, which is the same head start the roar
  has, but the first bark in a fresh session may still be late. Not measured.
- **The Forest Test was left OPEN in Edit**, as the Director left it, rather than closed before the
  gate runs. Each of the four gate runs confirmed its own place
  (`[server] report comes from the DEV place (136410205938347)`) and `HEAD unchanged during the run`.
  Stated as a deviation from the standing read-only capture block.

## Files

- `src/server/Boar/init.luau` — `SOUND.BARK`; `VOICE.APPLIES.bark`; `VOICE.CLIPS`; two
  `VOICE.LENGTHS` rows; `VOICE.stag.cry` / `.death` / `.bark`; `VOICE.hind.bark`; the calf's
  stated absence; `Runtime:check` plays `bark`; `Boar.voiceClip` / `Boar.clipSeconds` exported.
- `src/server/Boar/Body.luau` — `voiceClips`, `voiceClip`, `clipSeconds`; the region, gain, pitch
  and cut in `playOneShot`; the fade in `cutVolume` and `stepCuts`; `bark` in `oneShotSpecs`.
- `tests/server/boar_shot.spec.luau`, `tests/server/deer.spec.luau`,
  `tests/server/forest_line.spec.luau`.
- `assets/uploads.json`, `CREDITS.md`, `docs/research/2026-10-24-deer-bark-and-hit-call.md`,
  `docs/research/INDEX.md`, `TASKS.md`.
