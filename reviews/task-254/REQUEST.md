# Task 254: the real red stag roar, wired and played by measured region

Task: 254
Round: 1
Base: `cd901382` (`main`)
Code commit: `ce053db3bce1079aa819aa23a7c2d734a2f76b10`

`[harness] PASS: 34/34 checks @ ce053db3bce1079aa819aa23a7c2d734a2f76b10 (clean tree) scope=all`

`[harness2]` **N/A.** Nothing this task touches is in `TWO_PLAYER_PATHS` (`tools/agents.py`): the
files changed are `src/shared/ForestTest/`, `src/server/ForestTest/`, `tests/server/forest_line.spec.luau`
and docs. No match, no drive, no tie, no teams. A distant ambience cue sounds the same with one
player as with two.

## What changed

Task 251 part 2 shipped four Roblox-library **bull bellows** as the red stag's rut roar, and wrote
down the price at the time: *"when it lands it is this one `ids` row, changed"*. It has landed. The
real recording -- asset **122287696922128**, Freesound 653532 *"Deer rut - Brame Cerf"* by L.Finck,
**CC0** -- is now `ForestTest.ROAR.ids[1]`, played **by region**, with the four bulls kept behind it
as the revert path.

Five files of substance:

* `src/shared/ForestTest/init.luau` -- `ROAR.ids` gains the real id at the front; `ROAR.clips` is new
  and carries its three regions, their gains, its pitch and its fade; `ForestTest.roarClip` is a new
  pure chooser.
* `src/server/ForestTest/init.luau` -- `roarNow` plays what `roarClip` chose and sets **or clears**
  `PlaybackRegionsEnabled` every time; `roarFade` is new; the console line names what sounded.
* `tests/server/forest_line.spec.luau` -- the id count moves 4 -> 5, and one new case drives the
  chooser and both its branches.
* `assets/uploads.json` -- the upload row, with a **re-read** moderation state.
* `CREDITS.md`, `docs/research/2026-10-24-stag-voice-and-the-drive-s-length.md` -- provenance, and the
  note's own withdrawn sentence.

## Claims

**1. The id in the table is the id that was uploaded, and its moderation state was re-checked rather
than copied.** The dispatch said *"moderation APPROVED (read back via Open Cloud)"*; the manifest row
it told me to append says `"moderationState": "Reviewing"` and `"done": true`. Both cannot be
evidence. *Verify:* `assets/uploads.json`'s last row carries `"moderationState": "Approved"` and a
`moderationStateFrom` that names the live call and explains the discrepancy (the operation answered
`Reviewing` while the asset was queued). The id, sha256, bytes and `karenOk` match
`<assets-dir>/sounds/stag-roar/upload-row.json`. A reviewer with the key can re-run
`GET https://apis.roblox.com/assets/v1/assets/122287696922128`; it answered
`"moderationResult": {"moderationState": "Approved"}, "state": "Active"`, `assetType: Audio`,
`creator.userId: 8167651842`.

**2. It plays one roar at a time, never the 52.9-second file, and the three regions are measured and
not chosen.** *Verify:* `ForestTest.ROAR.clips[122287696922128].regions` in
`src/shared/ForestTest/init.luau` -- `0.20-5.20`, `9.45-14.45`, `35.60-40.60`, 5.00 s each. The
comment above them carries the method (a 50 ms RMS envelope of the uploaded bytes, smoothed with a
200 ms running max, gated 6 dB over the recording's own -45.2 dBFS forest floor; seven events, three
of which are one clean roar of the right length with silence at both ends) and section 6 of the
research note carries the table. `soundfile` read the file the manifest's sha256 names as 48 kHz
stereo and **52.8965 s**, against the **52.897** Roblox answers for the asset -- the same timeline,
which is what makes an offline cut legal.

**3. The level is a measurement, and without it two of the three roars would have been inaudible.**
This is the defect the measurement found, and it is the claim worth the most attention. A field
recording is not a production sample: at `Volume = 1` on a client the three regions peak
`PlaybackLoudness` **98, 54 and 50**, where the four bulls the cue ships today peak **94, 115, 161
and 198** (mean **142**). At `audibleStuds` 420 with `InverseTapered` roll-off, 8-9 dB down is the
difference between a roar and nothing. *Verify:* each region's `gain` is 142 over its own peak --
1.45, 2.63, 2.84 -- so `volume * gain` is 0.51, 0.92, 0.99 and all three arrive at the level Karen
has already heard. The spec case asserts the arithmetic (`peaks[index] * region.gain` within 1 of
142) and the ceiling (`<= 1`). The means agree within 7 % and the comment says so.

**4. `roarClip` is pure, lives with the table, and both of its branches are driven.** This closes
`reviews/task-253` note (d) -- *"`roarNow` has no spec at all; the evidence is the live console
lines"* -- for the **choosing** half. *Verify:* `ForestTest.roarClip` in `src/shared/ForestTest/init.luau`
takes an `rng` and an optional `roar` table and touches no Instance. The new case *"plays the real
stag by region, loud, and reverts to the bulls without its clip"* in `tests/server/forest_line.spec.luau`
drives 200 picks of the shipped table (always `ids[1]`, always one of the three regions, that
region's own volume, and **all three regions seen**, so a chooser that always answered `regions[1]`
fails), then 200 picks of a hand-written table with the clip removed and asserts it is task 251
part 2 exactly -- uniform over the four bulls, table pitch and volume, **no region**. An empty
`regions` list behaves as no clip; no ids at all answers `nil`.

**5. The real stag sounds every cue; the bulls are a revert path, not a rotation.** *Verify:*
`roarClip` returns `ids[1]` whenever `clips` has a usable entry for it, rather than taking its turn
in a uniform pick. The reason is in the comment: the four ids are a **bull**, and alternating a real
stag with a cow bellow reads as two animals, not as variety. The variety is the three regions. The
revert is a deletion -- drop `clips[122287696922128]` or the id from `ids` and the cue is the four
bulls again, which claim 4 proves by parameter.

**6. One Sound serves five ids, so the region is set *or cleared* on every play.** *Verify:*
`ForestTest.roarNow` -- the `if clip.from ~= nil and clip.to ~= nil then ... else
sound.PlaybackRegionsEnabled = false end` branch. Without the `else`, a library bellow played after
the real stag would inherit a 0.2-5.2 s window into a 3.6-second clip and play 3.4 s of nothing.
Reachable today only through the revert path, which is exactly why it is written rather than left to
the fact that the fallback is currently unused.

**7. The fade is real, it is bounded, and it cannot silence the next roar.** *Verify:*
`ForestTest.roarFade`. `fadeSeconds` is 0.35 and the comment carries why it is safe: the roar starts
0.60, 0.65 and 0.80 s after its region does and ends 0.60, 0.65 and 1.75 s before it, so neither fade
ever touches the bellow. Two tweens cannot be played together (TweenService cancels an earlier tween
on the same property), hence `task.delay`; and the delayed half is the only code here that can run
after a **later** roar started, hence `state.roarGen`. A new roar cancels the tween still running.
The spec asserts `fadeSeconds * 2 < length` for every region. `ForestTest` remains the only writer of
that Sound's `Volume` (rule 3).

**8. No pitch shift on the real animal.** *Verify:* `clips[...].pitch = 1` against `ROAR.pitch = 1.15`.
The 1.15 exists because a bull is three times a stag's weight; this recording is the stag.
`forest_line.spec` still asserts `roar.pitch == Boar.CONFIG.SOUND.VOICE.stag.pitch`, which is
untouched -- the per-clip pitch is an override, not a change to the dial.

**9. It was proved playing, in the region, loud, on Karen's path.** Live Play in **Driven Hunt Forest
Test** (`placeId=130094961655666`), player `team=Shooters`, Tool `Shotgun` **in the character** and
the Backpack empty. *Verify:* the numbers below, and `<runs-dir>/254-ft-console.txt`.

* `asset isLoaded=true timeLength=52.897` after `ContentProvider:PreloadAsync` (> 50, as asked).
* emitter: `soundId=rbxassetid://122287696922128 rollOff=InverseTapered 90..420`.
* client, inside the regions: `PLAY region=35.60-40.60 timePos=35.62..40.59 peakLoudness=48
  loudSamples=124/125 vol=0.00..0.99 speed=1.00` and `PLAY region=9.45-14.45 timePos=9.48..14.42
  peakLoudness=48 loudSamples=100/103 vol=0.00..0.92 speed=1.00`. `PlaybackRegion` is honoured to the
  sample, the `Volume` rising from 0.00 is the fade, and `speed=1.00` is the unshifted pitch.
* the server's own five lines for drive 1, all naming `id 122287696922128`, between them **all three
  regions** at `volume 0.51 / 0.92 / 0.99, pitch 1.00`, `~372 studs out ... audible to 420`.

**10. The Forest Test was read-only and left closed.** *Verify:* its `ServerStorage` attributes were
read before anything (`DHFlag_BOAR_BEHAVIOUR/BOAR_MODEL/COINS/DEER_ROAD_LEAP/DRIVE_BOTS/HORN/
LICENCE_POPUP/LOBBY/SHOP=true DHForestStartRole=hunter DHShopTestGrant=true`) and re-read at the end,
**identical**. Play was stopped, the place left in Edit, and the window closed before the harness, so
only DEV was open for the gate run -- the harness's own lines say
`report comes from the DEV place (136410205938347)`.

## What I could not verify, and one correction

* **Nobody here can hear it.** Every claim above is about what reaches the engine: the asset, its
  length, the region, the playback position, the volume and the speed. **Whether a real stag at these
  three regions and this level reads as a stag roaring across a valley is Karen's ears**, and it is
  the one thing this task cannot claim. It is the only thing it is asking her for.
* **`Sound.PlaybackLoudness` does NOT scale with `Volume`** -- measured on this asset, same region:
  `vol=1 peak=88`, `vol=0 peak=87`. So the dispatch's *"`IsPlaying` with `PlaybackLoudness > 0`"* is
  **not sufficient** to prove a cue is audible: a roar faded to silence would pass it. The proof in
  claim 9 therefore samples `Volume` alongside it, which is what actually carries the claim. It also
  answers **0 in Edit at every volume**, so a bench test cannot see any of this.
* **The level target is a choice, stated.** `gain` equalises the three regions to the **mean** peak of
  the four bulls (142). The min is 94 and the max 198, so a different target inside that range is
  defensible; the mean was taken because it is the centre of what the cue has actually been playing
  and because this task is meant to change which animal sounds and nothing else.
* **Two roars sound before `[report] drive 1 opened`** in the console, after which the counter resets
  and drive 1 gets its five. That is task 251 part 2's clock and it is **unchanged** by this task --
  no line of `stepRoar`'s window logic was touched -- but it is visible in the log I am pasting, so I
  am naming it rather than letting it look like something this task did.
* `ContentId: rbxassetid://203785492 failed due to: Asset type does not match requested type` appears
  three times in the console. That id is **not in this repository** (`grep` over `src/`, `tests/`,
  `tools/`, and over `main`): it is Studio's own, pre-existing and unrelated.
* Rule 5 (screenshot) is **N/A**: nothing drawn changed. The evidence for a sound is the numbers above.
