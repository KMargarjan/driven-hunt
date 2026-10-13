# Task 170 — design brief for the ARCHITECT: the economy (coins per drive, saved)

Written by the Builder, carrying the Director (2026-10-13). This brief is the input to
`tools/architect.sh design economy --task 170` and **overrides anything older** in `docs/`,
`TASKS.md` and any existing design where they disagree (`docs/ARCHITECT_PROMPT.md`).

Read first: **`docs/research/2026-10-13-coins-persistence.md`** — this task's note. Section 2 names
the five external sources with licences and maintenance status and quotes each; section 3 says what
is deliberately not borrowed; **section 4 is the pattern, already chosen and not open**; section 5 is
the harness change; section 6 is what the note does not answer. Also read
**`docs/research/2026-10-12-scoring.md`** section 5, which is where two of this task's three
questions were explicitly left for Karen and have now been answered by her.

The design is a **new system document**, `docs/design/economy.md`. It is also a **delta** to
`docs/design/drive.md` (§7 the score, §9 the owner interfaces and the wire) and to `GAME_DESIGN.md`'s
*System owners* table.

---

## 1. The decisions already taken — do not re-open them

1. **KAREN, 2026-10-11, verbatim:** *"Scoring - yes get money when shoot boar not much but get money
   and first place ofc more legendary more ect"*. 2026-10-10, her design doc: *"Progress trophys,
   money can purchase more"*. 2026-10-12: **separate rankings for hunters and beaters**, and
   **shooting a piglet is a penalty**.
2. **THE SAVE LAYER IS BORROWED WHOLE AND IS ALREADY CHOSEN: ProfileStore 1.0.3** (MadStudioRoblox,
   **Apache-2.0**, last commit 2025-07-31), pinned through Wally as
   `lm-loleris/profilestore@1.0.3` under `[server-dependencies]`. **Already installed and already
   verified**: `wally install` resolves it into `ServerPackages/`, and `rojo sourcemap` with the
   mapping in place resolves the package to exactly two ModuleScripts (its own nested
   `default.project.json` keeps the shipped `ProfileStoreTest.server.luau` Script, the docs and the
   images out of the place). ProfileService is rejected — deprecated by its own author; raw
   `DataStoreService` is rejected — `UpdateAsync` is one safe write, not a session lock; DataKeep is
   rejected — no session locking in its feature list. **Do not re-choose the library and do not
   design a save layer.** Note §2 has the evidence for each rejection.
3. **THE SPECS NEVER TOUCH THE LIBRARY, AND NEITHER DOES STUDIO.** Two things were found by reading
   ProfileStore's shipped source (note §2.1): it does **not** fall back to a mock by itself, and its
   Studio API-access probe is a **real `SetAsync`** fired by the require. So the rule is: one narrow
   store interface, **two** implementations — the real one (requires ProfileStore **lazily**, only
   when it will be used) and an **in-memory** one — and `RunService:IsStudio()` picks the in-memory
   one. A Studio playtest cannot write a live key even with *Enable Studio Access to API Services*
   ON; the harness never requires the library at all. `ProfileStore.Mock` is **not** the mechanism
   (reaching it still means requiring the library in Studio). Which store was taken is `print`ed
   once — the dispatch's *"clearly logged"*.
4. **COINS ARE A PURE FUNCTION OF THE BOARD `Match.Score` ALREADY PRODUCES.** No second scoring
   system, and no coin awarded anywhere a point is not. The numbers (note §1): `COINS_PER_POINT = 2`,
   `PARTICIPATION = 10`, `FIRST_PLACE = 25` **per ranking**, and the **balance is floored at 0**
   while a drive's own coin line may be negative.
5. **PAID ONCE PER DRIVE, AT ITS END.** `Phase.enterScoring` is the single door out of `Running`
   (its own comment: *"The clock and the beaters' crossing both come through `enterScoring`, so one
   emit here is one signal per drive end"*). No double pay if `Scoring` is re-entered or the owner's
   dispatch runs twice.
6. **BOTS EARN NOTHING, WITH NO NEW PREDICATE.** `docs/design/bots.md`: *"no row in `Score`, no
   DataStore"*, and the mechanism is structural (a bot's id is a non-numeric string;
   `Match.pushCreditable` and `Phase.participantIds` already refuse it). The task adds a **spec**,
   not a filter.
7. **TWO RANKINGS FROM ONE BOARD.** `Score.leaderboard` is unchanged and stays total. The split is a
   **partition of its output by `row.team`**, and `Hud.firstPlaceRank` — which already answers `nil`
   for a tie at the top and for an all-noughts board, after ioquake3's `RANK_TIED_FLAG` — is asked
   **once per ranking**. Two lists, two badges, one rule.
8. **A PIGLET COSTS POINTS**, in data: `POINTS.KIND.cub` goes from `+2` to `-10` (the figure
   `SAFETY_PENALTY` already uses), and `QUARRY_NOTE` changes in the same commit — which is exactly
   what `Match.CONFIG`'s own comment promised. `Match.quarryLines` already prints the kinds with
   their prices, so the start card says so for free.
9. **NO CLIENT → SERVER REMOTE.** `src/client/Match/init.luau`'s header: *"this whole system has no
   client -> server remote at all, so its inbound exploit surface is zero"*. The balance and the
   drive's earnings ride on the **existing snapshot rows** (`MatchState`, `FireAllClients`). No new
   remote, no new wire. Spending is a later task and will re-open this deliberately.
10. **THE HARNESS CHANGE IS IN SCOPE AND IS NAMED** (note §5): `ServerPackages/` is git-ignored, so
    it gets the exemption and the sha256 pin `DevPackages/` already has — its **own**
    `serverpackages.sha256`, not a rename of `devpackages.sha256` — plus the nested-project-file
    exemption and a `BLAST_RADIUS`/`SCOPE_SPECS` entry for the new scope.

## 2. What the design must decide — the open questions

These are the owner rulings the brief does not take.

### 2.1 Who owns a player's coins, and where does the module live?

The note says "one owner of a player's coins, on the server" and does not say which instance. The
candidates and the trade the design must rule on:

* **A new system, `src/server/Economy/`**, which `Match` calls at the drive boundary. Keeps
  persistence out of a 2,478-line owner, and keeps a pure conversion module beside a pure `Score`.
* **Inside `Match`**, as `Match.Coins`, the way `Match.Score`, `Match.Penalty` and `Match.Roster`
  already are. One fewer composition root, and the drive boundary is already there.

The design must also say **what the pure/impure split is**: `Match.Score` is strictly pure (*"no
service, no clock, no Player, no Instance, no Random; `config` is a parameter"*) and the conversion
can hold to exactly that, with the store and the balances held by the impure half. State which
symbol is which.

### 2.2 Who reads the store, and when — the four lifecycle moments

The design must name the owner and the order for each: **join** (a player arrives mid-drive and his
balance must be on screen), **drive end** (the pay-out), **leave** (`Match.forget` already exists and
already drops `Body`, the hold and the rope), and **server shutdown** (`BindToClose`; the repo has no
`BindToClose` anywhere today). It must say what happens when a **load fails or the session lock is
refused** (`StartSessionAsync` returns `nil`) — the note has the quote, the ruling is the design's —
and whether a player whose balance did not load may still earn.

### 2.3 What rides on the wire

Two numbers per row are needed on screen: the **balance** (HUD, at all times) and **this drive's
earnings** (the results scene, *"+N coins"*). The design must say whether both are row fields on the
existing `MatchSnapshot`, and must state the consequence it is accepting: every client learns every
player's balance. State whether that is acceptable and why, or give the alternative.

### 2.4 Who draws the two rankings

`Hud.renderScore` is today the ONE writer of the score panel and draws one list through
`scoreRowText` into `SCORE_ROWS_MAX` pre-built labels. Two rankings with their own headers, their own
badges and a shared row budget is a layout decision inside that owner. The design must say whether
the split is a pure exported function (the repo's habit, because no harness run reaches `Scoring`)
and where the panel's words live — `Drive.CONFIG` holds every word this Hud draws today.

### 2.5 The profile's shape, and migration

`ProfileStore.New(store_name, template)` takes a template of defaults. The design must fix the
**store name**, the **key format** (note §2.4: a key caps at 50 characters), the template, and the
rule for adding a field later — because *"Progress trophys"* is the next thing into this table and
the design should not have to move when it arrives.

### 2.6 The one thing that cannot be tested in a harness run

A drive is 600 seconds, so **no harness run ever reaches `Scoring`** — the constraint that already
made `Hud.renderScore` and `Hud.firstPlaceRank` public and pure. The design must say, symbol by
symbol, which seams make the pay-out, the two rankings and the save/load round trip assertable in
seconds, and it must do so **without** a production path that exists for a test's benefit (the rule
that sent TASKS.md 36a's hit-marker race back).

## 3. What the design must contain

1. The owner ruling for §2.1 and the module layout, file by file, with the pure/impure split named.
2. The lifecycle table for §2.2: moment, owner, call, failure behaviour.
3. The interface, **symbol by symbol**, for every new module and every changed one, including what
   each refuses.
4. The wire delta for §2.3, written as the field list.
5. The ruling for §2.4 and §2.5.
6. The seams for §2.6 and the spec claims each one makes possible.
7. The delta list: every section of `docs/design/drive.md` and every `GAME_DESIGN.md` owner row this
   changes, so nothing is discovered at merge time.
8. The hazards. At minimum: double pay, a balance that goes negative, a leaver paid twice or not at
   all, two servers for one player, a Studio run reaching a live key, and a bot acquiring a row.

## 4. Out of scope — say so if the design wants them, do not design them

Spending and a shop (and the inbound remote it needs), trophies, a cross-server
`OrderedDataStore` leaderboard, Robux, and the legendary animal (its price already exists with no
animal behind it). Note §6.
