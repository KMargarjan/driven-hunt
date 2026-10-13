# Task 170 — coins per drive, saved between sessions, and two rankings

Task: 170
Round: 2
Base: `8128ed0` (main, #153 merged)
Code commit: `87c5baf55b84d51acfacb5d159a08f6fde48108d`

```
[harness] PASS: 33/33 checks @ 87c5baf55b84d51acfacb5d159a08f6fde48108d (clean tree) scope=all
[harness] PASS: 33/33 checks @ 87c5baf55b84d51acfacb5d159a08f6fde48108d (clean tree) scope=all
```

```
[harness2] NEEDS TEST2 170 87c5baf55b84d51acfacb5d159a08f6fde48108d
```

**The `[harness2]` line is a PLACEHOLDER and the Director asked for it in those words** (round-2
dispatch: *"[harness2] placeholder. Stop 'NEEDS TEST2 170 <sha>'"*). Seven files on
`TWO_PLAYER_PATHS` are touched, which `tools/agents.py`'s own `needs_two_player` lists as
`src/server/Match/init.luau`, `src/server/MatchBoot.server.luau`, `src/shared/Drive/init.luau`,
`src/shared/Drive/Rank.luau`, `tests/server/match_score.spec.luau`,
`tests/server/zz_drive_boundary.spec.luau` and `tests/client/match_client.spec.luau`. Both full
one-player runs above were made on a clean tree at that commit, **in the DEV place alone** — the
Forest Test Studio is closed, as the dispatch said it would be.

## What changed

A drive pays coins off the points it already scores, the balance survives the session through
ProfileStore, the results table is two rankings with two first places, and a piglet is a penalty.
Born behind `COINS`, **default false**.

**New system:** `docs/design/economy.md` (Architect PASS at `48b5c6e`), from
`reviews/task-170/BRIEF.md` and `docs/research/2026-10-13-coins-persistence.md` (five sources, each
with licence and maintenance status, what it does well and badly, the pattern, the numbers).

## Round 1's finding, and what it cost

**It was right, and the claim it killed was mine.** `Hud.coinsText` answered `""` only when the
snapshot had no row for the player, and its comment said that was *"the whole of today's game with
the `COINS` flag off"*. **He always has a row** — `Match.snapshot` builds one per
`Score.leaderboard` entry and `watchPlayer` joins every player to the board — so with the flag off
only `coins` was absent, the no-balance branch fired, and **every drive bar in the game carried a
dead `COINS --`** for a currency that did not exist. OFF was not the game before task 170, and claim
10 of round 1 was false.

**The fix is one source, and it is the server's.** The snapshot carries `coinsOn`, true only when the
economy is actually running and **absent otherwise** — which is exactly what every build before task
170 sends, so a client reading the field is byte-identical to one that never heard of it. The Hud
reads **no flag of its own**: a client's copy of a server rule is what `ReplicatedStorage.Drive`'s
header exists to prevent.

**Why a field and not "drop the piece when there is no balance":** the two absences are *different
questions* and the rows cannot tell them apart. `coins` is missing both when there is no money and
when a player's profile did not open, and the second is a real thing to tell him. So:

| snapshot | bar |
|---|---|
| no `coinsOn` | nothing drawn |
| `coinsOn`, no `coins` | `COINS --` (balance unknown — not zero) |
| `coinsOn` + a number | `COINS 1240` |

## Claims, and how to verify each

1. **With `COINS` off the drive bar is byte-identical to before task 170**, and it is MEASURED rather
   than argued. The flag is born off, so a harness run IS the flag-off state.
   *Verify:* `tests/client/match_client.spec.luau`, *"leaves no coins piece on the live drive bar
   while the economy is off"* — it reads the LIVE wire, asserts its own precondition (this player has
   a row; `snapshot.coinsOn` is nil; `mine.coins` is nil) and then that the bar contains neither
   `SCORE_COINS_LABEL` nor `SCORE_COINS_UNKNOWN`. Harness note from run 2:
   `match_client: COINS off -> the bar reads 'DRIVE 1   9:30   BOARS 5   SHOOTER'`.
   Also *"draws NO balance at all when the build has no money in it"* (pure: absent `coinsOn`,
   explicit `false`, and a stray `coins` with no `coinsOn` — all `""`). **All three fail on the code
   round 1 reviewed.**

2. **The four sentences that said otherwise are corrected, and three of the four are in code.**
   `Hud.coinsText`'s own comment (it now states the defect by name), `COINS.why` in
   `src/shared/Flags/init.luau` (it claimed OFF left *"task 159's one-table board"*, which was never
   true — the split into two rankings is Karen's decision and is not about money), and this request's
   claim 10, which is gone. **The fourth is `docs/design/economy.md` §7.4 and I did not touch it**:
   the Architect owns `docs/design/` and the Builder does not write designs (CLAUDE.md roles). It is
   queued as `TASKS.md` row 170a(a) for the next Architect run, which is the same thing this repo did
   with `docs/design/drive.md` §7.1 after task 160 retuned the points table.

3. **The save layer is borrowed whole and nothing of it is written here.** ProfileStore 1.0.3
   (MadStudioRoblox, **Apache-2.0** — the dispatch said MIT and the note corrects it), pinned as
   `lm-loleris/profilestore@1.0.3` under `[server-dependencies]`, mapped as
   `ServerStorage.ServerPackages`. No retry loop, no backoff, no `UpdateAsync`, no auto-save of ours
   and no `SetConstant`.
   *Verify:* `wally.toml`, `wally.lock`, `default.project.json`;
   `grep -rn "DataStoreService\|ProfileStore" src/` finds them in `src/server/Economy/Store.luau`
   and nowhere else.

4. **The library is required lazily, inside one function body, and never in Studio** — the require
   itself performs a real `SetAsync` (note §2.1). `RunService:IsStudio()` picks the in-memory store,
   so a playtest cannot write a live key even with *Enable Studio Access to API Services* ON, and no
   harness run loads the library. **And a live store that cannot be built no longer takes the server
   with it** (round 1 note 2): `Store.live` waits a bounded 10 s for the package tree — an OPTIONAL
   Rojo path, so a build without `wally install` really has none — refuses loudly, and
   `Economy.start` falls back to the memory store with a `warn` and `stats().storeFellBack`, because
   a bare `WaitForChild` there would have hung the whole boot (it runs before `Match.start`) in order
   to save nothing.
   *Verify:* `Store.live` and `WAIT_FOR_LIBRARY_SECONDS` in `src/server/Economy/Store.luau`;
   the `pcall` branch in `Economy.start`; `tests/server/economy.spec.luau`, describe *"which store a
   run takes"* — the live branch is provable only as a pure predicate, because inside Studio
   `IsStudio()` is always true.

5. **Coins are a pure function of the board and no coin is awarded where a point is not.**
   `Economy.Coins` takes `{ Score.Row }` and `config` and nothing else, is pure to the standard
   `Match.Score`'s header states, returns frozen tables and never mutates its input. Rates:
   `COINS_PER_POINT = 2`, `PARTICIPATION = 10`, `FIRST_PLACE = 25` **per ranking**, `FLOOR = 0`.
   *Verify:* `src/server/Economy/Coins.luau`; `tests/server/economy.spec.luau`, describe *"what a
   drive is worth"* (a male boar is 30 coins, a top hunter on 16 points is 67, a drive line may be
   negative and only the BALANCE is floored).

6. **Two rankings, two first places, ONE implementation of the rule.** `Hud.firstPlaceRank` moved
   verbatim to `src/shared/Drive/Rank.luau`, because the server now pays a bonus off the same
   question the client draws a badge off. `others` is NOT a ranking and gets no badge and no bonus.
   The export is **frozen** (round 1 note 5): it is a rule the server pays off, and an unfrozen one
   is a rule any requirer could replace.
   *Verify:* `Drive.Rank`; `Economy.Coins.forDrive`; `Hud.scorePanelLines`;
   `tests/client/match_client.spec.luau` (the moved cases, the two rankings, a tie at the top of one
   ranking leaving the other alone, OTHERS never ranked);
   `backups/2026-10-13_task-170_hud-firstplacerank.txt`. The old name is asserted GONE, not aliased.

7. **The drive pays on the `Scoring` edge, BEFORE `applyEffects`, exactly once.** The mirror of the
   `Assigning` block beside it and the same measured reason (TASKS.md 32a(c)): `enterScoring` forces
   one broadcast, so paying after the effects would leave the coins column reading `--` for up to
   `STATE_HEARTBEAT` seconds of the results scene. One pay-out per drive is structural (one edge, one
   door into `Scoring`); the owner refuses a repeated **or earlier** drive number as a belt over that
   brace.
   *Verify:* the `Scoring` edge block in `Match.dispatch`; `Economy.payDrive`;
   `tests/server/economy.spec.luau` (*"refuses a drive number it has already paid"*).

8. **`payDrive` never yields and makes no network call.**
   *Verify:* `tests/server/economy.spec.luau`, *"pays without yielding and without a single store
   call of its own"* — a `task.defer`'d marker is still 0 after the call (and 1 a frame later, so the
   assertion is not vacuous), and `Store.memory` counts its own calls.

9. **Bots earn nothing, with no new predicate.** `Coins.forDrive` COUNTS a non-numeric userId
   (`skippedNotAPlayer`) rather than filtering for it.
   *Verify:* `tests/server/economy.spec.luau`, *"refuses anything that is not a real player's
   userId"*.

10. **A piglet is a penalty, and the number and the sentence are one decision.** `POINTS.KIND.cub`
    goes `2 → -10` and `QUARRY_NOTE` becomes *"a piglet COSTS you - leave them"* in the same commit —
    which is what that field's own comment promised in task 160.
    *Verify:* `tests/server/match_score.spec.luau` (*"states the piglet rule on the start card, in
    the same commit as the price"*, which fails if either rolls back alone) and
    `tests/server/match_config.spec.luau`; `backups/2026-10-13_task-170_cub-points-and-quarry-note.txt`.

## Screenshots (rule 5), inspected

`.screenshots/task170-results-two-rankings.png` — the real panel in a real Play session, drawn from a
scripted `Scoring` payload fired down the REAL wire by the server (a drive is 600 s and
`Match.advanceForTests` is gated on an active harness token, so no playtest reaches `Scoring`; task
159 took its own results screenshot with `DRIVE_SECONDS` shortened by hand and said so). Read off the
image: `DRIVE 4 RESULTS`; header `#  NAME  KILLS  POINTS  COINS` with **no TEAM column**;
`-- HUNTERS --` over Karen 3 / 26 / **+87 1st**, Mila 2 / 16 / +42, Jonas 1 / −4 / +2;
`-- BEATERS --` over Anya 0 / 12 / **+59 1st**, Piet 0 / 6 / +22, Sam 0 / 6 / `--` `*` (the leaver —
not paid); the rank restarting at 1 in each ranking; `NEXT DRIVE IN 11`.

`.screenshots/task170-forest-smoke.png` — Karen's own place, flag ON, bar reading
`DRIVE 1  3:32  BOARS 0  SHOOTER  COINS 0`.

**Both were taken before this round's fix and the fix does not change either picture**: both show the
flag ON, which is the branch that was always correct. What round 2 changed is the flag-OFF bar, and
that is asserted on the live wire in claim 1 rather than photographed — a screenshot of a bar with
nothing extra on it proves nothing a reader could check.

## Smoke in the Forest Test (standing rule A), flag ON — from round 1, not re-run

The Forest Test Studio is **closed** this round (the dispatch), so this is round 1's evidence and is
labelled as such. Nothing in this round's diff touches the forest's own path; what it changes is what
the bar draws with the economy OFF, and the smoke was run with it ON.

1. **Tool in the CHARACTER**: `character=Shotgun backpack=Rifle` at **t+15 s** and at **t+95 s**.
2. **Console**: 57 lines, **0** suspicious — no "Stack Begin", no "attempt to", no "invalid
   argument", no error line (`.screenshots/task170-forest-console.txt`).
3. **The feature ran**: `[economy] coins=on store=memory (Studio: nothing is written to a live
   DataStore key)`, with the drive running around it.

## What I could NOT verify

* **The live ProfileStore path is exercised by nothing**, by design (brief decision 3): no spec
  requires the library and no spec touches `DataStoreService`. Its only evidence is the pure
  `storeKindFor(false) == "live"` and the one `print`.
* **A real two-server session steal cannot be reproduced** — one Studio session is one server. What
  IS tested is our reaction: a refused `StartSessionAsync` (`Store.memory{refuse}`) and
  `Profile.OnSessionEnd` (`loseSession`).
* **The request budget is arithmetic, not a measurement**: Studio with API access off issues no
  requests at all.
* **The production pay-out path still runs in no harness run** (round 1 note 1), because the flag is
  born off. `economy.spec` covers `payDrive` by parameter. Queued as 170a(b) rather than fixed here:
  a case that stops and restarts the live owner around the real drive boundary is a change to
  `zz_drive_boundary.spec`, which is on `TWO_PLAYER_PATHS`, and the round-2 dispatch is a 45-minute
  box for finding 1.
* **The panel's PIXEL width is an estimate**; the spec asserts the character count and the
  screenshot settles the pixels.
* **`test2` has not been run.** The Director runs it.
