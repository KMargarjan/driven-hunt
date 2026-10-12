# Task 163 — the drive's signals: 15 s to find a stand, three horn calls at each end

Task: 163
Round: 1
Base: `6763fed` (main, #146 merged)
Code commit: `6cc533309b4244c6d7d4c5b54606216261cfa821`

```
[harness] PASS: 33/33 checks @ 6cc533309b4244c6d7d4c5b54606216261cfa821 (clean tree) scope=auto:boar,hud,match,weapon
```

**THIS IS A SECOND REVIEW OF THE SAME TASK, AFTER A CHANGE THE FIRST REVIEW ASKED FOR, and the round
is 1 because that review PASSED.** `reviews/task-163/RESULT.md` is a **PASS at `935ac7a`** (round 1,
ten notes, none blocking). The **Director then dispatched note 163a(a)** — the one note with a
consequence Karen would hear — so there is **one more code commit on top of the reviewed one**, and
he is re-running the review at it. `tools/agents.py` computes `expected = 1` after a PASS, which is
why this still says `Round: 1`.

**WHAT TO LOOK AT FIRST, THEREFORE: `src/client/Hud/Sound.luau` and the one new client case.**
Everything else in this request is unchanged from the version that already passed, and is repeated
here because CLAUDE.md asks for the request to state the final state rather than a history.

A **scoped** one-player line, which is review-round evidence (Task 113): the scope resolved from this
branch's own changed paths, and because the change reaches specs the run was the whole suite anyway
(1,093 server + **249** client assertions). **TWO FULL `scope=all` RUNS WERE ALSO MADE AT THIS SAME
COMMIT, both 33/33, both on a clean tree** — their lines are in `TASKS.md` and the Director report,
and are deliberately not pasted here, because a full line in this file would make `tools/agents.py`
ask for the `[harness2]` line that a scoped round does not need.

`test2` is **NOT N/A for the merge**: `src/server/Match/`, `src/shared/Drive/`,
`tests/server/match_*.spec.luau` and `tests/client/match_client.spec.luau` are all in
`TWO_PLAYER_PATHS`. **The Director runs it** — placeholder, to be filled at merge:

```
[harness2] PASS: n/m checks @ 6cc533309b4244c6d7d4c5b54606216261cfa821 (clean tree)   <-- NOT RUN YET
```

## What changed

Karen, 2026-10-12 ~10:40: *"for hunter a bit more time like 15s to find a place / when hunt starts 3
longer horn calls and when ends the same"*.

**The timer.** `Match.CONFIG.INTERMISSION_SECONDS` 10 → 15. It stays **one number for three things**
(task 158's decision): the start card's life, the hunter's stand timer and the beaters' hold all
count the same `phaseEndsAt` down.

**The signal.** The server says WHEN, one data file says WHAT IT SOUNDS LIKE, one client module plays
it. `Match.Phase` emits one `signal` feed entry at GO and one at the end; `Horn.CONFIG.SIGNAL` holds
the note, the count, the gap and the volume; `Hud.Sound` plays three notes 2-D at the ear, from a
Sound it makes and preloads at module load. No new remote, no new phase, no new state, no flag row.

Six files of code, four of specs. Design: an extension of `docs/design/drive.md` section 4 and
`docs/design/beater-kit.md` section 16 item 1 — no new system, so no Architect design run. Note:
`docs/research/2026-10-12-drive-signals.md`.

## Claims

1. **THE NEW ONE (163a(a)): the signal's Sound is made and preloaded at MODULE LOAD, so the first cue
   of a session cannot play the clip from 0.** It used to be created inside `Sound.driveSignal`, so
   the asset request started at the first cue with only a 2 s `IsLoaded` wait against it — and
   `TimePosition` on an unloaded Sound is not kept, so a lost race plays the eight SHORT notes at the
   clip's head, three times, on the first signal Karen ever hears. Now `makeSignalVoice()` runs at
   load and one `ContentProvider:PreloadAsync` asks for the asset in its own thread (it yields, and
   the Hud requires this module while building itself), so the asset has the client's whole boot plus
   the 15 s countdown. Verify: the bottom of `src/client/Hud/Sound.luau` (after `driveSignal`), and
   `tests/client/match_client.spec.luau` — "has its Sound made and configured BEFORE the first cue,
   and preloaded". **It is asserted as a fact about LOAD TIME** (`madeAtLoad` / `preloaded`, exported
   as `Sound.signalReady()`), because once a drive has signalled, "it existed before the cue" cannot
   be read off the Instance. The case also asserts the configuration — `Name`, `Parent == SoundService`
   (so it is 2-D), `SoundId`, `Volume`, `Looped == false` — and that the asset is really loaded and
   longer than the cut. **MEASURED, both full runs:**
   `drive signal: voice made at load=true, preload returned=true, IsLoaded=true, clip 60.63 s, cut 23.36-26.30`.
   The bounded wait in `driveSignal` stays as the backstop (a preload can throw — no network, a
   moderated asset — and that is caught), and `driveSignal` re-makes the voice only if something
   destroyed it, so a loaded asset is never thrown away.

2. **The hunter gets 15 s, and all three halves of the countdown follow it.**
   `Match.CONFIG.INTERMISSION_SECONDS` is 15 and nothing else in the repo holds that number:
   `Phase.intermissionSeconds` reads the key (and the quick test still reads its own
   `QUICK_TEST_INTERMISSION_SECONDS`), and the start card, the stand timer and the beaters' hold all
   read `phaseEndsAt`. Verify: `grep -rn INTERMISSION_SECONDS src/ tests/`; the previous value is
   archived in `backups/2026-10-12_task163_intermission_10s.txt` (rule 7), and
   `tests/server/match_live.spec.luau` ("the drive's own numbers") asserts the 15 against the LIVE
   drive's own table.

3. **The signal fires exactly once at GO, and once at the end for BOTH endings, with the same word.**
   `Phase.enterRunning` emits one `feed` effect whose entry `kind` is `"signal"` and `text` is
   `"start"`; `Phase.enterScoring` — the one door the drive clock and the beaters' crossing both come
   through — emits one with `"end"`, and `reason` is not read, because Karen said *"when ends the
   same"*. Each phase has exactly one entry, so no number of ticks can double it. Verify:
   `tests/server/match_phase.spec.luau`, `describe("the drive's horn signal")` — once at GO; nothing
   more for a whole drive of ticks; once when the clock ends it; once when the BEATERS end it; and
   exactly **3** across two whole drives (drive 1's end, drive 2's GO, drive 2's end).

4. **Both states are reachable by parameter.** `Match.CONFIG.SIGNAL_ENABLED` is read by the pure
   machine (`Phase`'s local `signal`), so a spec can run the drive with the signal off while the
   shipped value is on. Verify: "is silent with SIGNAL_ENABLED false" — no signal entry at GO or at
   the end, and the phase LINE ("Drive on") is untouched, so the switch is the horn's alone. A plain
   boolean and not a flag row: the call task 159 made for `SCENE.ENABLED`. (The first review noted
   that my *stated reason* for that was weak — the gate is read on the server — and it is queued as
   163a(e) for the Director. The decision itself was not held up.)

5. **The clip and the cut are measured, and the numbers say which note.** `Horn.CONFIG.SIGNAL.START`
   = 23.36, `CUT` = 26.3, `NOTES` = 3, `GAP` = 0.2 — the one sustained note in a 60.63 s clip
   (attack 23.38, peak 214 at 23.70, one smooth 2.2 s decay with no second attack, the clip's own
   silence 26.30–28.00, the next phrase at 28.05). Verify: `tests/server/zz_horn.spec.luau`,
   `describe("the drive's own signal")` — the exact cut, `CUT < 28.05` (so one note is never two),
   `CUT < 60.63`, and the note LONGER than the beater's beep (`Horn.signalNoteSeconds >
   Horn.playSeconds`), which is the whole of what Karen asked for. The loudness profile and the
   method are in `docs/research/2026-10-12-drive-signals.md` section 5.

6. **The schedule is pure data, not code in the player.** `Horn.signalPlan` is a pure function
   returning one row per note; `Hud.Sound.driveSignal` walks it and holds no count and no note length
   of its own. Verify: the same describe — "lays the notes out with the gaps BETWEEN them and no gap
   after the last" and "is clamped, so a crossed-over cut cannot ask for a negative wait" (`CUT <
   START` gives 0; `NOTES = 0` gives an empty plan rather than an error). **The first review was
   right that the SPACING is re-derived in the player** (`task.wait(SIGNAL.GAP)`, never `note.at`),
   so a plan with non-uniform gaps would be played uniformly; that is queued as 163a(b) and this
   claim is narrowed to the count and the length accordingly.

7. **It adds no wire, and the inbound exploit surface is still zero.** The entry rides the existing
   `MatchEvent` (server → client), which the Hud already subscribes to. Verify: `src/shared/Drive`
   still declares exactly two remotes and `tests/client/match_client.spec.luau`'s first case still
   counts the folder's children; `grep -rn "RemoteEvent\|RemoteFunction" src/shared/Drive/` shows no
   third.

8. **The signal entry draws no feed line.** `Hud.feedTextFor` answers nil for `kind == "signal"`,
   which is the rule task 124 built for `HitLog`'s kills, so the feed never prints the bare word
   "start". The Feed handler calls the sound owner and then falls through to that one rule — no early
   return, so "what is drawn" is still decided in exactly one place. Verify:
   `tests/client/match_client.spec.luau`, "draws NO feed line, so the feed never prints the bare
   word" (and the phase line beside it still reads "Drive on", so the feed did not go quiet).

9. **One writer of the drive-wide sound, and it sounds once per cue.** `Hud.Sound` is already "THE ONE
   WRITER of the Hud's own 2-D feedback sounds"; `Weapon.Horn` keeps the positional blast on a
   beater's Tool and is untouched. A second signal arriving while one sounds is refused and counted,
   not stacked. Verify: `tests/client/match_client.spec.luau`, "sounds once per cue, and refuses a
   second signal while one is sounding" (deltas on `stats().signal` and `stats().signalBusy`; the
   refused call does not change `lastSignal()`); `grep -rn "Instance.new(\"Sound\")" src/` shows the
   only other creators are `Weapon.Sound`, `Hud.Sound`'s own hit tick, `Weapon.Horn`'s Tool-parented
   blast and `Boar.Body`'s animal voices — each one its own system's.

10. **The asset id is still written down exactly once, and the live wire was measured.**
    The signal reuses `Horn.CONFIG.SOUND_ID` (`rbxassetid://9038902877`, the asset task 152 verified
    public); nothing was uploaded and no second copy of the id exists (`grep -rn 9038902877 src/`).
    **MEASURED in a DEV Play session off the real Instance** (the link no spec covers — the first
    review's note 163a(d)): `SoundService.DriveSignal` appeared **11.6 s after the client came up**
    (GO), and played **three notes each from `TimePosition` 23.360 to 26.21, ~0.27 s apart, the third
    ending 9.63 s after the first began**; `PlaybackLoudness` through a note read **195, 187, 167,
    162, 128, 114, 97, 94, 82, 48, 15** — the smooth single-note decay the cut was chosen for. Console:
    21 lines, zero errors. The second full run's spec note shows the same wire from the other side:
    `drive signal: 2 sounded, 1 refused as busy` — one of those two is the live drive's own cue.

## What I could not verify

* **THE SOUND WAS NOT HEARD.** The cut is measured off the asset's own `PlaybackLoudness`, not
  listened to, and I cannot listen. Whether three notes of 2.94 s at `VOLUME = 1` feel right is
  **Karen's judgement**. The note, the count, the gap and the volume are each a one-line data change.
* **THE DISPATCH'S NUMBER MOVED.** It asked for ~1.5–2 s a note; this is 2.94 s, because the clip
  holds exactly one sustained note and that is its length. A stop at 25.2 cuts the note at 44% of its
  peak (the click `SOUND_CUT` exists to avoid), and a fade means a second writer ramping the Volume.
  Stated in the data file, the commit and the note.
* **`test2` WAS NOT RUN** (one human click; the Director keeps it). So the two-player claims — that
  every client in a two-player drive hears the signal, and that a beater's client hears the same one
  as a hunter's — are **unproven**. Nothing in the change is per-player:
  `MatchEvent:FireAllClients` already carries every other feed entry to both sides.
* **THE PRELOAD WINNING THE RACE ON A COLD CLIENT IS NOT PROVEN, only made very likely.** Both runs
  measured `IsLoaded = true` long before any cue, but a Studio client has a warm cache; a first-ever
  player on a slow connection still relies on the backstop, which plays the note late rather than
  wrong only if the asset arrives inside 2 s of the cue.
* **No screenshot.** Nothing visual changed. Rule 5 is N/A with that as the reason.
* **No smoke in the Forest Test**, and nothing here says "ready for Karen": that place's Studio window
  was closed part-way through this session and opening a place is a click (`ESCALATE.md`,
  2026-10-12). The DEV Play session above is what was run instead.
