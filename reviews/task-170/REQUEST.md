# Task 170 — coins per drive, saved between sessions, and two rankings

Task: 170
Round: 1
Base: `8128ed0` (main, #153 merged)
Code commit: `46607bf87a317996fc0e643aabe511b09c9dae5d`

```
[harness] PASS: 33/33 checks @ 46607bf87a317996fc0e643aabe511b09c9dae5d (clean tree) scope=all
[harness] PASS: 33/33 checks @ 46607bf87a317996fc0e643aabe511b09c9dae5d (clean tree) scope=all
```

```
[harness2] NEEDS TEST2 170 46607bf87a317996fc0e643aabe511b09c9dae5d
```

**On the commit the lines name.** It is `46607bf`, the paperwork commit that carries this request and
the task's status row, and it is at or after the last commit that changed `src/`, `tests/` or `tools/`
(`72c175d`) -- which is the definition CLAUDE.md's git workflow step 4 writes out, and it only makes
the bound stricter. Between `72c175d` and `46607bf` the one non-paperwork change is `GAME_DESIGN.md`
(`ba7ad41`, the *System owners* row this task's design asks for), which is **not** paperwork by
`tools/agents.py`'s own rule -- so the gate was re-run at the commit that includes it rather than
letting a doc change ride in behind the evidence. Both full runs above were made on a clean tree at
that commit.

**That second line is a PLACEHOLDER and the Director asked for it in those words** (dispatch: *"TWO_PLAYER_PATHS
will be touched: stop 'NEEDS TEST2 170 <sha>' with a placeholder (I run test2 + the review)"*). Five
SEVEN files on `TWO_PLAYER_PATHS` are touched, which `tools/agents.py`'s own `needs_two_player` lists
as `src/server/Match/init.luau`, `src/server/MatchBoot.server.luau`, `src/shared/Drive/init.luau`,
`src/shared/Drive/Rank.luau`, `tests/server/match_score.spec.luau`,
`tests/server/zz_drive_boundary.spec.luau` and `tests/client/match_client.spec.luau` — so the real
`[harness2]` line is the Director's to produce at this same commit, and `tools/agents.py` will refuse
this request until it replaces the placeholder. The FULL one-player run above was made TWICE on a
clean tree, as the dispatch asked.

## What changed

A drive now pays coins off the points it already scores, the balance survives the session through
ProfileStore, the results table is two rankings with two first places, and a piglet is a penalty.

**New system:** `docs/design/economy.md` (Architect, PASS at `48b5c6e`), from
`reviews/task-170/BRIEF.md` and `docs/research/2026-10-13-coins-persistence.md` (five sources,
licences and maintenance status, what each does well and badly, the pattern, the numbers).

Born behind `COINS`, **default false**.

## Claims, and how to verify each

1. **The save layer is borrowed whole and nothing of it is written here.** ProfileStore 1.0.3
   (MadStudioRoblox, **Apache-2.0** — the dispatch said MIT and the note corrects it), pinned as
   `lm-loleris/profilestore@1.0.3` under `[server-dependencies]` in `wally.toml`, mapped as
   `ServerStorage.ServerPackages`. No retry loop, no backoff, no `UpdateAsync`, no auto-save and no
   `SetConstant` anywhere.
   *Verify:* `wally.toml`, `wally.lock`, `default.project.json`; `grep -rn "DataStoreService\|ProfileStore" src/`
   finds them in `src/server/Economy/Store.luau` and nowhere else.

2. **The library is required lazily, inside one function body, and never in Studio** — because the
   require itself performs a real `SetAsync` (`ProfileStore.luau` line 2072 onward, quoted in the
   note §2.1). `RunService:IsStudio()` picks the in-memory store, so a playtest cannot write a live
   key even with *Enable Studio Access to API Services* on, and no harness run loads the library.
   *Verify:* `Store.live` in `src/server/Economy/Store.luau` (the `require` is inside the body, not
   at the top of the file); `Economy.storeKindFor` in `src/server/Economy/init.luau`;
   `tests/server/economy.spec.luau`, describe *"which store a run takes"* — the live branch is
   provable only as a pure predicate, because inside Studio `IsStudio()` is always true.

3. **Coins are a pure function of the board and no coin is awarded where a point is not.**
   `Economy.Coins` takes `{ Score.Row }` and `config` and nothing else; it is pure to the standard
   `Match.Score`'s header states, returns frozen tables and never mutates its input. Rates:
   `COINS_PER_POINT = 2`, `PARTICIPATION = 10`, `FIRST_PLACE = 25` per ranking, `FLOOR = 0`.
   *Verify:* `src/server/Economy/Coins.luau`; `tests/server/economy.spec.luau`, describe *"what a
   drive is worth"* (a male boar is 30 coins, a top hunter on 16 points is 67, a drive line may be
   negative and only the BALANCE is floored).

4. **Two rankings, two first places, ONE implementation of the rule.** `Hud.firstPlaceRank` moved
   verbatim to `src/shared/Drive/Rank.luau`, because the server now pays a bonus off the same
   question the client draws a badge off — *"Most of the worst bugs were two correct pieces of code
   disagreeing"*. `others` is NOT a ranking and gets no badge and no bonus.
   *Verify:* `Drive.Rank.firstPlaceRank` / `splitByTeam`; `Economy.Coins.forDrive`;
   `Hud.scorePanelLines`; `tests/client/match_client.spec.luau` (the moved cases, the two rankings,
   the tie at the top of one ranking leaving the other alone, OTHERS never ranked);
   `backups/2026-10-13_task-170_hud-firstplacerank.txt`. The old name is asserted GONE, not aliased.

5. **The drive pays on the `Scoring` edge, BEFORE `applyEffects`, exactly once.** The mirror of the
   `Assigning` block beside it, and the same measured reason (TASKS.md 32a(c)): `enterScoring`
   forces one broadcast, so paying after the effects would leave the coins column reading `--` for up
   to `STATE_HEARTBEAT` seconds of the results scene. One pay-out per drive is structural (one edge,
   one door into `Scoring`); the owner refuses a repeated or earlier drive number as a belt over
   that brace.
   *Verify:* `Match.dispatch` in `src/server/Match/init.luau` (the `state.phase ~= before and
   state.phase == "Scoring"` block); `Economy.payDrive`; `tests/server/economy.spec.luau` (*"refuses a
   drive number it has already paid"*); `tests/server/zz_drive_boundary.spec.luau`, which drives the
   REAL boundary and asserts `drivesPaid` rose by exactly one — or, with the flag at its default,
   that nothing was paid and no row carries a coin.

6. **`payDrive` never yields and makes no network call.** It runs inside `Match`'s dispatch; every
   yielding call (`load`, `release`, `releaseAll`) is inside a thread `Economy` spawns itself.
   *Verify:* `tests/server/economy.spec.luau`, *"pays without yielding and without a single store
   call of its own"* — a `task.defer`'d marker is still 0 after the call, and `Store.memory` counts
   its own calls.

7. **Bots earn nothing, with no new predicate.** `docs/design/bots.md`: *"no row in `Score`, no
   DataStore"*. `Coins.forDrive` COUNTS a non-numeric userId (`skippedNotAPlayer`) rather than
   filtering for it — a tripwire with a number on it, not a mechanism the game depends on.
   *Verify:* `tests/server/economy.spec.luau`, *"refuses anything that is not a real player's
   userId"*.

8. **A piglet is a penalty, and the number and the sentence are one decision.**
   `POINTS.KIND.cub` goes `2 → -10` (one whole male, the figure `SAFETY_PENALTY` already uses) and
   `QUARRY_NOTE` becomes *"a piglet COSTS you - leave them"* in the same commit — which is what that
   field's own comment promised in task 160. The start card prints `cub -10` for free.
   *Verify:* `Match.CONFIG.POINTS.KIND` and `QUARRY_NOTE`; `tests/server/match_score.spec.luau`
   (*"states the piglet rule on the start card, in the same commit as the price"*, which fails if
   either rolls back alone) and `tests/server/match_config.spec.luau`;
   `backups/2026-10-13_task-170_cub-points-and-quarry-note.txt`.

9. **No new remote, no rate on the wire.** Both numbers are optional row fields on the existing
   `MatchSnapshot` (`coins` = the balance, `earned` = this drive's line). ABSENT means unknown and is
   drawn `--`, never `0`. `Economy.CONFIG` is server-only.
   *Verify:* `Drive.ScoreRow`; `Match.snapshot()`; `tests/client/match_client.spec.luau`, *"carries no
   rule number"* — extended to the four coin rates by NAME and to anything matching `COIN` by
   PATTERN; `tests/server/match_config.spec.luau` (no economy key on `WORLD_OVERRIDABLE`, and none in
   `Match.CONFIG` at all).

10. **OFF is the game before this task, by the absence of data.** With `COINS` false `Economy.start`
    connects nothing, opens no session, writes no key; the rows carry neither field, so the panel
    draws task 159's board and `Hud.coinsText` returns `""` — the drive bar is byte-identical.
    *Verify:* `tests/server/economy.spec.luau`, *"connects nothing, loads nothing and pays nothing
    with the flag off"*; `Hud.coinsText`'s own cases; `src/shared/Flags/init.luau`.

## Screenshot (rule 5), inspected

`.screenshots/task170-results-two-rankings.png` — the real panel in a real Play session, drawn from a
scripted `Scoring` payload fired down the REAL wire by the server (a drive is 600 s and
`Match.advanceForTests` is gated on an active harness token, so no playtest reaches `Scoring`; task
159 took its own results screenshot with `DRIVE_SECONDS` shortened by hand and said so). What it
shows, read off the image: `DRIVE 4 RESULTS`; header `#  NAME  KILLS  POINTS  COINS` with **no TEAM
column**; `-- HUNTERS --` over Karen 3 / 26 / **+87 1st**, Mila 2 / 16 / +42, Jonas 1 / −4 / +2;
`-- BEATERS --` over Anya 0 / 12 / **+59 1st**, Piet 0 / 6 / +22, Sam 0 / 6 / `--` `*` (the leaver —
not paid, so no number); the rank restarting at 1 in each ranking; `NEXT DRIVE IN 11`.

`.screenshots/task170-forest-smoke.png` — Karen's own place, flag on, bar reading
`DRIVE 1  3:32  BOARS 0  SHOOTER  COINS 0`: the balance really is on the HUD in every phase.

## Smoke in the Forest Test (standing rule A), flag ON

1. **Tool in the CHARACTER**: `character=Shotgun backpack=Rifle` at **t+15 s** and at **t+95 s**.
2. **Console**: 57 lines, **0** suspicious — no "Stack Begin", no "attempt to", no "invalid
   argument", no error line (`.screenshots/task170-forest-console.txt`).
3. **The feature ran**: `[economy] coins=on store=memory (Studio: nothing is written to a live
   DataStore key)`, and the drive ran around it (drive 1 opened, the player took stand 5, five lines
   of animals crossed).

Karen's own overrides were read before and after and are untouched: `DHFlag_DRIVE_BOTS=true,
DHForestStartRole=hunter`. The `COINS` override was cleared in both places; `python tools/flags.py`
shows no override anywhere.

## What I could NOT verify

* **The live ProfileStore path is exercised by nothing**, by design (brief decision 3): no spec
  requires the library and no spec touches `DataStoreService`. Its only evidence is the pure
  `storeKindFor(false) == "live"` and the one `print`. The alternative is a harness run that writes
  live keys.
* **A real two-server session steal cannot be reproduced** — one Studio session is one server. What
  is tested is OUR reaction: a refused `StartSessionAsync` (`Store.memory{refuse}`) and
  `Profile.OnSessionEnd` (`loseSession`).
* **The request budget is arithmetic, not a measurement**: Studio with API access off issues no
  requests at all.
* **Whether ProfileStore reconciles a template on load is not verified.** `Store.read` makes the
  answer irrelevant and that is why it exists (and it is the one invented thing here, with its
  written reason in the file).
* **The panel's PIXEL width is an estimate** (≈ 8 px per glyph at `TextSize = 16`, `Enum.Font.Code`).
  The spec asserts the CHARACTER count (≤ 56 inside 448 px) and the screenshot settles the pixels.
* **A probe that `require`s a module over StudioMCP gets a sandboxed copy with empty state** (task
  122, already recorded in `MatchBoot`), so the smoke's `Economy.stats()` probe read `store=off`
  while the live server had printed `coins=on store=memory`. The console line is the honest evidence
  and the probe's numbers are not quoted above.
* **`test2` has not been run.** The Director runs it (dispatch).

## Round 1 of the gate found three real things, and they are in the second commit

The first full run failed 4 of 33. (a) `Hud.scorePanelLines` asked the first-place rule of ALL three
lists, so a row with no team wore a `1st` the server would never have paid — the exact
two-pieces-of-code-disagreeing failure this task moved the rule to `Drive.Rank` to prevent, caught by
the spec that says OTHERS is not a ranking. (b) `Economy`'s counters outlived `stop()`, so every spec
that ran second read the one before it. (c) Two spec numbers forgot that a lone scorer IS first of
his ranking. Both economy specs now put the production owner back when they finish (`afterAll`),
because they drive the live singleton.
