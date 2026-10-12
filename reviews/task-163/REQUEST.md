# Task 163 — the drive's signals: 15 s to find a stand, three horn calls at each end

Task: 163
Round: 1
Base: `6763fed` (main, #146 merged)
Code commit: `d3791cb21fc6482878c1e5d6b50bca9f04626a9e`

```
[harness] PASS: 33/33 checks @ d3791cb21fc6482878c1e5d6b50bca9f04626a9e (clean tree) scope=auto:boar,hud,match,weapon
```

A **scoped** one-player line, which is review-round evidence (Task 113): the scope resolved from this
branch's own changed paths, and because the change reaches specs the run was the whole suite anyway
(1,093 server + 248 client assertions; `scope=` decides whether Play happens, not which specs run).
**TWO FULL `scope=all` RUNS WERE ALSO MADE AT THIS SAME COMMIT, both 33/33, both on a clean tree** —
their lines are in the report to the Director and in `TASKS.md`, and are deliberately not pasted
here, because a full line in this file would make `tools/agents.py` ask for the `[harness2]` line
that a scoped round does not need.

`test2` is **NOT N/A for the merge**: `src/server/Match/`, `src/shared/Drive/`,
`tests/server/match_*.spec.luau` and `tests/client/match_client.spec.luau` are all in
`TWO_PLAYER_PATHS`. **The Director runs it** (his dispatch: *"stop 'NEEDS TEST2 163 <sha>' with a
placeholder"*), and the PR to `main` needs it plus a full `test` for this commit.

## What changed

Karen, 2026-10-12 ~10:40: *"for hunter a bit more time like 15s to find a place / when hunt starts 3
longer horn calls and when ends the same"*.

**The timer.** `Match.CONFIG.INTERMISSION_SECONDS` 10 → 15. It stays **one number for three things**
(task 158's decision): the start card's life, the hunter's stand timer and the beaters' hold all
count the same `phaseEndsAt` down.

**The signal.** The server says WHEN, one data file says WHAT IT SOUNDS LIKE, one client module plays
it. `Match.Phase` emits one `signal` feed entry at GO and one at the end; `Horn.CONFIG.SIGNAL` holds
the note, the count, the gap and the volume; `Hud.Sound` plays three notes 2-D at the ear. No new
remote, no new phase, no new state, no flag row.

Six files of code (two of them one line each), four of specs. Design: an extension of
`docs/design/drive.md` section 4 and `docs/design/beater-kit.md` section 16 item 1 — no new system, so
no Architect design run. Note: `docs/research/2026-10-12-drive-signals.md`.

## Claims

1. **The hunter gets 15 s, and all three halves of the countdown follow it.**
   `Match.CONFIG.INTERMISSION_SECONDS` is 15 and nothing else in the repo holds that number:
   `Phase.intermissionSeconds` reads the key (and the quick test still reads its own
   `QUICK_TEST_INTERMISSION_SECONDS`), and the start card, the stand timer and the beaters' hold all
   read `phaseEndsAt`. Verify: `grep -rn INTERMISSION_SECONDS src/ tests/`; the previous value is
   archived in `backups/2026-10-12_task163_intermission_10s.txt` (rule 7), and
   `tests/server/match_live.spec.luau` ("the drive's own numbers") asserts the 15 against the LIVE
   drive's own table.

2. **The signal fires exactly once at GO.** `Phase.enterRunning` emits one `feed` effect whose entry
   `kind` is `"signal"` and whose `text` is `"start"`, and nothing else in the file emits one for a
   start. `Assigning` has exactly one exit, so no number of ticks can double it. Verify:
   `tests/server/match_phase.spec.luau`, `describe("the drive's horn signal")` — "sounds exactly once
   at GO, and says which signal it is" plus "does not sound again on any later tick of the same
   drive" (a whole drive of ticks collects zero more).

3. **It fires exactly once at the end, for BOTH endings, with the same word.** `Phase.enterScoring`
   is the one door the drive clock and the beaters' crossing both come through, and the emit is there
   and nowhere else; `reason` is not read, because Karen said *"when ends the same"*. Verify: the same
   describe — "sounds exactly once when the clock ends the drive" and "sounds exactly once when the
   BEATERS end the drive"; both assert the count is 1 and the word is `"end"`. "sounds once per drive
   and no more, across two whole drives" counts exactly 3 over drive 1's end, drive 2's GO and drive
   2's end.

4. **Both states are reachable by parameter.** `Match.CONFIG.SIGNAL_ENABLED` is read by the pure
   machine (`Phase`'s local `signal`), so a spec can run the drive with the signal off while the
   shipped value is on. Verify: "is silent with SIGNAL_ENABLED false" — no signal entry at GO or at
   the end, and the phase LINE ("Drive on") is untouched, so the switch is the horn's alone. It is a
   plain boolean and not a flag row on purpose: the call task 159 made for `SCENE.ENABLED`, and the
   client half could not read a flag anyway (an override is an attribute on `ServerStorage`).

5. **The clip and the cut are measured, and the numbers say which note.** `Horn.CONFIG.SIGNAL.START`
   = 23.36, `CUT` = 26.3, `NOTES` = 3, `GAP` = 0.2 — the one sustained note in a 60.63 s clip
   (attack 23.38, peak 214 at 23.70, one smooth 2.2 s decay with no second attack, the clip's own
   silence 26.30–28.00, the next phrase at 28.05). Verify: `tests/server/zz_horn.spec.luau`,
   `describe("the drive's own signal")` — the exact cut, `CUT < 28.05` (so one note is never two),
   `CUT < 60.63`, and the note LONGER than the beater's beep (`Horn.signalNoteSeconds >
   Horn.playSeconds`), which is the whole of what Karen asked for. The loudness profile and the
   method are in `docs/research/2026-10-12-drive-signals.md` section 5.

6. **The schedule is pure data, not code in the player.** `Horn.signalPlan` is a pure function
   returning one row per note; `Hud.Sound.driveSignal` walks it and holds no count of its own. Verify:
   the same describe — "lays the notes out with the gaps BETWEEN them and no gap after the last"
   (`plan[1].at == 0`, `plan[i].at == (i-1) * (note + GAP)`, `signalSeconds == last.at + note`), and
   "is clamped, so a crossed-over cut cannot ask for a negative wait" (`CUT < START` gives 0, and
   `NOTES = 0` gives an empty plan rather than an error).

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
   second signal while one is sounding" (counts `stats().signal` and `stats().signalBusy` as deltas,
   and the refused call does not change `lastSignal()`); `grep -rn "Instance.new(\"Sound\")" src/`
   shows the only other creators are `Weapon.Sound`, `Hud.Sound`'s own hit tick, `Weapon.Horn`'s
   Tool-parented blast and `Boar.Body`'s animal voices — each one its own system's.

10. **The asset id is still written down exactly once.** The signal reuses `Horn.CONFIG.SOUND_ID`
    (`rbxassetid://9038902877`, the asset task 152 verified public); nothing new was uploaded and no
    second copy of the id exists. Verify: `grep -rn 9038902877 src/`.

## What I could not verify

* **THE SOUND WAS NOT HEARD.** The cut is measured off the asset's own `PlaybackLoudness`, not
  listened to, and I cannot listen. Whether three notes of 2.94 s at the start of a drive feel right
  — and whether the volume is right against the beater's beep — is **Karen's judgement**. The note,
  the count, the gap and the volume are each a one-line data change.
* **THE DISPATCH'S NUMBER MOVED.** It asked for ~1.5–2 s a note; this is 2.94 s, because the clip
  holds exactly one sustained note and that is its length. The two ways to shorten it are worse: a
  stop at 25.2 cuts the note at 44% of its peak (the click `SOUND_CUT` exists to avoid), and a fade
  means a second writer ramping the Volume. Stated in the data file, the commit and the note.
* **`test2` WAS NOT RUN** (one human click; the Director's dispatch keeps it). So the two-player
  claims of this change — that every client in a two-player drive hears the signal, and that a
  beater's client hears the same one as a hunter's — are **unproven**. Nothing in the change is
  per-player: `MatchEvent:FireAllClients` already carries every other feed entry to both sides.
* **No screenshot.** Nothing visual changed; the only picture this task could take is the start card,
  which changed by being up 5 s longer. Rule 5 is N/A with that as the reason.
* **No smoke run in the Forest Test**, and therefore nothing here says "ready for Karen": the
  Director's own dispatch has him close that place and run `test2`.
