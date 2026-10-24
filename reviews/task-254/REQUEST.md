# Task 254: the real red stag roar, wired and played by measured region

Task: 254
Round: 2
Base: `cd901382` (`main`)
Code commit: `876b051debfce457ccef38f09ba48892876eba7d`

`[harness] PASS: 34/34 checks @ 876b051debfce457ccef38f09ba48892876eba7d (clean tree) scope=all`

`[harness2]` **N/A.** Nothing this task touches is in `TWO_PLAYER_PATHS` (`tools/agents.py`), and
`agents.py` agrees -- round 1 printed *"3 code file(s) changed, 0 needing two players"*. The files are
`src/shared/ForestTest/`, `src/server/ForestTest/`, two server specs and docs: no match, no drive, no
tie, no teams. A distant ambience cue sounds the same with one player as with two.

## What changed

Task 251 part 2 shipped four Roblox-library **bull bellows** as the red stag's rut roar and wrote
down the price at the time: *"when it lands it is this one `ids` row, changed"*. It has landed. The
real recording -- asset **122287696922128**, Freesound 653532 *"Deer rut - Brame Cerf"* by L.Finck,
**CC0** -- is `ForestTest.ROAR.ids[1]`, played **by region**, with the four bulls kept behind it as
the revert path.

* `src/shared/ForestTest/init.luau` -- `ROAR.ids` gains the real id at the front; `ROAR.clips` is new
  and carries its three regions, their gains, its pitch and its fade; `ForestTest.roarClip` is a new
  pure chooser.
* `src/server/ForestTest/init.luau` -- `ForestTest.start` builds the emitter; `roarNow` plays what
  `roarClip` chose and sets **or clears** `PlaybackRegionsEnabled` every time; `roarFade` is new; the
  console line names what sounded.
* `tests/server/forest_line.spec.luau`, `tests/server/forest_stand.spec.luau` -- the id count moves
  4 -> 5, and two new cases drive the chooser (both branches, plus the trap round 1 found) and the
  start-up build.
* `assets/uploads.json` -- the upload row, with a **re-read** moderation state.
* `CREDITS.md`, `docs/research/2026-10-24-stag-voice-and-the-drive-s-length.md` -- provenance, and the
  note's own withdrawn sentence.

## Round 1's two findings, and what was done

**Finding 1 -- the emitter's comment claimed a preload the code could not do, and this change made
the latency worse.** Correct, and accepted as stated. `roarEmitter` has one caller, `roarNow`, which
calls `sound:Play()` a few statements later in the same resumption, so nothing was ever fetched
early -- and `ids[1]` is now 1.2 MB where it was a ~4 s bellow, so the first roar of a server was the
one that waited. **Fixed by making the sentence true rather than by deleting it:**
`ForestTest.start` now calls `ForestTest.roarEmitter()`, so the Sound and its `SoundId` replicate
during the lobby, tens of seconds before `ROAR.firstAtSeconds` 8 into a drive nobody has entered yet.
`roarEmitter` is idempotent and `roarNow` still calls it. *Verify:* claim 10.

**Finding 2 -- the documented revert was wrong, and the wrong one was a trap.** Correct, and the
arithmetic in the finding is right: deleting `clips[122287696922128]` left the id in `ids`, where the
uniform fallback would pick it one time in five, play **52.897 s whole** at pitch 1.15 (~46 s), and
`roarNow`'s `IsPlaying` guard would then refuse the cues at +20 s and +40 s -- one cue in five costing
three. The `empty`-regions case the old spec endorsed reached the same hole. **Fixed in two parts,
and the trap is now driven:** the fallback picks only among ids with **no** `clips` entry, and nothing
left to pick is silence rather than 46 seconds; and the revert is stated as the one safe edit. *Verify:*
claims 5 and 6.

## Claims

**1. The id in the table is the id that was uploaded, and its moderation state was re-checked rather
than copied.** The dispatch said *"moderation APPROVED (read back via Open Cloud)"*; the manifest row
it told me to append says `"moderationState": "Reviewing"` and `"done": true`. Both cannot be
evidence. *Verify:* `assets/uploads.json`'s last row carries `"moderationState": "Approved"` and a
`moderationStateFrom` naming the live call and explaining the discrepancy (the operation answered
`Reviewing` while the asset was queued). The id, sha256, bytes and `karenOk` match
`<assets-dir>/sounds/stag-roar/upload-row.json`. `GET https://apis.roblox.com/assets/v1/assets/122287696922128`
answered `"moderationResult": {"moderationState": "Approved"}, "state": "Active"`, `assetType: Audio`,
`creator.userId: 8167651842`.

**2. It plays one roar at a time, never the 52.9-second file, and the three regions are measured and
not chosen.** *Verify:* `ForestTest.ROAR.clips[122287696922128].regions` -- `0.20-5.20`,
`9.45-14.45`, `35.60-40.60`, 5.00 s each. The comment carries the method (a 50 ms RMS envelope of the
uploaded bytes, smoothed with a 200 ms running max, gated 6 dB over the recording's own -45.2 dBFS
forest floor; seven events, three of which are one clean roar of the right length with silence at
both ends) and section 6 of the research note carries the table. `soundfile` read the file the
manifest's sha256 names as 48 kHz stereo and **52.8965 s**, against the **52.897** Roblox answers for
the asset -- the same timeline, which is what makes an offline cut legal.

**3. The level is a measurement, and without it two of the three roars would have been inaudible.**
This is the defect the measurement found. At `Volume = 1` on a client the three regions peak
`PlaybackLoudness` **98, 54 and 50**, where the four bulls the cue ships today peak **94, 115, 161 and
198** (mean **142**). At `audibleStuds` 420 with `InverseTapered` roll-off, 8-9 dB down is the
difference between a roar and nothing. *Verify:* each region's `gain` is 142 over its own peak --
1.45, 2.63, 2.84 -- so `volume * gain` is 0.51, 0.92, 0.99 and all three arrive at the level Karen has
already heard. The spec asserts the arithmetic and the `<= 1` ceiling, and now says in as many words
that the `peaks` literal is **the measurement restated and not a measurement** (round 1, note).

**4. `roarClip` is pure and lives with the table.** This closes `reviews/task-253` note (d) -- *"the
evidence is the live console lines"* -- for the **choosing** half only; the fade's arithmetic half is
queued as 254a(a), which is where the Reviewer asked for it. *Verify:* `ForestTest.roarClip` takes an
`rng` and an optional `roar` table and touches no Instance.

**5. The shipped table always sounds the real stag, with one of its three regions.** *Verify:* the
case *"plays the real stag by region, loud, and reverts to the bulls without its clip"* in
`tests/server/forest_line.spec.luau` drives 200 picks of the shipped table: always `ids[1]`, always
one of the three regions, that region's own volume, and **all three regions seen**, so a chooser that
always answered `regions[1]` fails. The reason the bulls do not take turns is in the comment -- they
are a **bull**, and alternating a real stag with a cow bellow reads as two animals, not as variety.

**6. A clipped id can never be played whole, the revert is one edit, and both are driven.** The
safety property is the important half, because it holds whatever anybody edits next: a `clips` entry
is the only place this table records that an id is too long to play whole, so the fallback skips any
id that has one. *Verify:* in the same case, 200 picks over a table that still lists `ids[1]` but has
hollowed its `regions` to `{}` **never return `ids[1]`** and never carry a region; a table whose only
id is that one answers **`nil`** (silence beats 46 seconds); no ids at all answers `nil`. The revert
case now hands in the four bulls **with `clips` left orphaned in place**, exactly as the documented
edit would leave it, and gets task 251 part 2 back -- uniform, table pitch and volume, no region.
`roarClip`'s header states the one safe edit (remove the id from `ids`) and why deleting the `clips`
entry alone is not it.

**7. One Sound serves five ids, so the region is set *or cleared* on every play.** *Verify:*
`ForestTest.roarNow`'s `else sound.PlaybackRegionsEnabled = false end`. Without it, a library bellow
played after the real stag would inherit a 0.2-5.2 s window into a 3.6-second clip.

**8. The fade is real, bounded, and cannot silence the next roar.** *Verify:* `ForestTest.roarFade`.
`fadeSeconds` 0.35 against margins of 0.60/0.65/0.80 s before the bellow and 0.60/0.65/1.75 s after
it, so neither fade ever touches it. Two tweens cannot be played together (TweenService cancels an
earlier tween on the same property), hence `task.delay`; the delayed half is the only code here that
can run after a **later** roar started, hence `state.roarGen`. A new roar cancels the tween still
running, and `state.roarTween` is cleared when the fade is spent (round 1, note). The spec asserts
`fadeSeconds * 2 < length` for every region. `ForestTest` remains the only writer of that Sound's
`Volume` (rule 3).

**9. No pitch shift on the real animal.** *Verify:* `clips[...].pitch = 1` against `ROAR.pitch = 1.15`.
The 1.15 exists because a bull is three times a stag's weight. `forest_line.spec` still asserts
`roar.pitch == Boar.CONFIG.SOUND.VOICE.stag.pitch`: the per-clip pitch is an override, not a change
to the dial.

**10. The emitter is built at start-up, exactly once, and that is driven.** *Verify:* the new case
*"builds the rut roar's emitter at start-up, once, so the asset is fetched before it is due"* in
`tests/server/forest_stand.spec.luau`. After `ForestTest.start`, `Workspace.StagRoar.Roar` exists, is
a `Sound`, and carries `rbxassetid://` + `ROAR.ids[1]`; a second `start` leaves **exactly one** Part,
so a replacement can never orphan the one this module built. The harness already drove
`ForestTest.start` before this task (`forest_stand.spec` calls it with a fake runtime and with `nil`),
so the new call is exercised, and the server count moved 2204 -> **2205** with this case.

**11. It was proved playing, in the region, loud, on Karen's path.** Live Play in **Driven Hunt Forest
Test** (`placeId=130094961655666`), player `team=Shooters`, Tool `Shotgun` **in the character** and
the Backpack empty. *Verify:* the numbers below and `<runs-dir>/254-ft-console.txt`.

* `asset isLoaded=true timeLength=52.897` after `ContentProvider:PreloadAsync` (> 50, as asked).
* emitter: `soundId=rbxassetid://122287696922128 rollOff=InverseTapered 90..420`.
* client, inside the regions: `PLAY region=35.60-40.60 timePos=35.62..40.59 peakLoudness=48
  loudSamples=124/125 vol=0.00..0.99 speed=1.00` and `PLAY region=9.45-14.45 timePos=9.48..14.42
  peakLoudness=48 loudSamples=100/103 vol=0.00..0.92 speed=1.00`. `PlaybackRegion` is honoured to a
  hundredth of a second, the `Volume` rising from 0.00 is the fade, `speed=1.00` is the unshifted
  pitch. **Region 1's evidence is the server's own line, not a client sample** (round 1, note), and
  the code comment and the research note now say so.
* the server's five lines for drive 1, all naming `id 122287696922128`, between them **all three
  regions** at `volume 0.51 / 0.92 / 0.99, pitch 1.00`, `~372 studs out ... audible to 420`.

**12. The Forest Test was read-only and left closed.** *Verify:* its `ServerStorage` attributes were
read before anything (`DHFlag_BOAR_BEHAVIOUR/BOAR_MODEL/COINS/DEER_ROAD_LEAP/DRIVE_BOTS/HORN/
LICENCE_POPUP/LOBBY/SHOP=true DHForestStartRole=hunter DHShopTestGrant=true`) and re-read at the end,
**identical**. Play was stopped, the place left in Edit, the window closed before the harness, so only
DEV was open for every gate run -- the harness's own lines say `report comes from the DEV place
(136410205938347)`.

## What I could not verify, and the corrections

* **Nobody here can hear it.** Every claim above is about what reaches the engine. **Whether a real
  stag at these three regions and this level reads as a stag roaring across a valley is Karen's
  ears**, and it is the one thing this task cannot claim. It is the only thing it is asking her for.
* **`Sound.PlaybackLoudness` does NOT scale with `Volume`** -- measured on this asset, same region:
  `vol=1 peak=88`, `vol=0 peak=87`. So the dispatch's *"`IsPlaying` with `PlaybackLoudness > 0`"* is
  **not sufficient** to prove a cue is audible: a roar faded to silence would pass it. The proof in
  claim 11 samples `Volume` alongside it, which is what actually carries the claim. It also answers
  **0 in Edit at every volume**, so a bench test cannot see any of this.
* **Round 2's live evidence is round 1's, and here is why that is honest.** The live proof was taken
  at `ce053db3`. Round 2 changed **when the emitter is built** and the **fallback** branch of
  `roarClip` -- and for the shipped table the fallback is unreachable, because `ids[1]` has three
  usable regions, so `roarClip`'s first branch is byte-for-byte the one that was proved. What round 2
  changed about what Karen hears is nothing; what it changed about when the asset is fetched is
  proved by claim 10's case and by code reading, not by a live run. A live re-proof would need the
  Forest Test reopened, which the standing block makes the Director's click.
* **The level target is a choice, stated.** `gain` equalises the three regions to the **mean** peak of
  the four bulls (142). The min is 94 and the max 198, so another target inside that range is
  defensible; the mean was taken because it is the centre of what the cue has actually been playing.
* **`tests/client/camera_client.spec.luau` flaked again, and it is `253`(f).** At this commit the
  full harness ran **three times: FAIL, PASS, PASS** -- `586 passed, 1 failed, 1 errors` once, then
  34/34 twice. This branch changes **no client file** (`git diff --name-only cd901382..HEAD` has no
  hit under `src/client/` or `tests/client/`), which is exactly the signature task 253 recorded: four
  failures in six runs on a branch with no client change, *"including a pass and a fail at the same
  commit"*. The pasted PASS line is the third run. Naming it rather than quietly re-running.
* **Two roars sound before `[report] drive 1 opened`**, after which the counter resets and drive 1
  gets its five. That is task 251 part 2's clock, **unchanged** by this task -- no line of
  `stepRoar`'s window logic was touched -- but it is visible in the log I am pasting, so I am naming
  it rather than letting it look like something this task did.
* **The flag question, answered (round 1, note; 251a(h), 253(f)).** This ships with no `Flags` row and
  relies on **the parameter rule**: both states of the chooser are reachable by parameter (`roarClip`'s
  optional `roar` table) and both are driven, which is what the digest asks for in place of a flag.
  The map-switch exception does not apply -- nothing here lives in the place. It has now been answered
  in three requests running, so 254a(b) queues deciding it once in `docs/design/feature-flags.md`
  instead of re-arguing it per task.
* `ContentId: rbxassetid://203785492 failed due to: Asset type does not match requested type` appears
  three times in the console. That id is **not in this repository** (`grep` over `src/`, `tests/`,
  `tools/`, and over `main`): it is Studio's own, pre-existing and unrelated.
* Rule 5 (screenshot) is **N/A**: nothing drawn changed. The evidence for a sound is the numbers above.
* Round 1's remaining notes are queued as **254a** in `TASKS.md`: the fade's arithmetic wanting its
  own driven function (with `253`(d), where the Reviewer asked for it), and the flag question.
