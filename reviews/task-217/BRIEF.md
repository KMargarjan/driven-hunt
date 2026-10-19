# Task 217 — design brief for the ARCHITECT: roles rotate each drive, and the turn survives a logout

Written by the Builder, carrying the Director (2026-10-20). This brief is the input to
`tools/architect.ps1 design role-rotation --task 217` and **overrides anything older** in `docs/`,
`TASKS.md` and any existing design where they disagree (`docs/ARCHITECT_PROMPT.md`).

Read first: **`docs/research/2026-10-20-role-rotation.md`** — this task's note. Its §2 is eleven
facts read out of the code **by symbol** (what seam already exists and what does not); §3 names the
four external sources with licence and maintenance status; §4 is the pattern and the reason;
§5 the numeric targets.

**This is NOT a new system document.** It is a **delta** to two designs that already exist, and the
Architect's commit must EDIT THEM, not only write `reviews/task-217/ARCH_RESULT.md` (Learning Agent
L-071: deltas to this same area from tasks 191, 213 and 214 sat unqueued for days):

- **`docs/design/economy.md`** — §9 (the profile: shape, key, store name, migration), §4.4 (the
  owner's interface), §4.5 (what `Match` changes), §10 (the seams and the spec claim each one buys),
  §11 (hazards), §12 (deltas), §13 (open decisions).
- **`docs/design/drive.md`** — §5.2 (`Roster`), §5.3 (what `Assigning` does, in order), §4.2 (events
  the machine consumes), §9.2 (the owner's interface).

A third file is touched only if the Architect rules differently from decision 7 below:
`docs/design/forest-drive.md` §5.2/§5.3 (the `DHForestStartRole` / `/beater` request).

---

## 1. Karen's words — the requirement, verbatim

**2026-10-11 morning, decided** (and carried forward on the v1 plan of 2026-10-19, *"continue
working wht you can now"*; on the evening of 10-11 she said *"not now"*, and the 10-19 plan puts it
next):

> *"ROLES ROTATE: you start as a hunter, next round you are a beater; it is REMEMBERED across
> logout/login (no cheating back to hunter) — persistent per player (DataStore)."*

Her earlier words on the same thing, 2026-10-11:

> *"you start as a hunter then next round you are beater"*

Her other rules still hold and are not re-opened here: **the beater licence lets a beater shoot**
(task 178), and **`/beater`, `/hunter` and `DHForestStartRole` stay as Studio test switches**.

---

## 2. The decisions already taken — do not re-open them

1. **ALTERNATE PER COMPLETED DRIVE, PER PLAYER.** Shot in drive *N* → pushes in drive *N+1* → shoots
   in *N+2*. Two roles, a strict 2-cycle, no randomness. Nothing about *which* stand or *which* lane.
2. **THE NEXT ROLE IS STORED IN THE EXISTING PROFILE, IN THE EXISTING PERSISTENCE OWNER.**
   `ServerScriptService.Economy` (task 170) is **the one persistence owner** and `Economy.Store` is
   **the only thing in this repository that may reach `DataStoreService`**. Extend its record:
   one additive field on `Store.TEMPLATE`. **NO second DataStore, no second store name, no second key
   per player, no `DataStoreService` anywhere else.** (Roblox's own best-practices page, note §3.4.)
3. **A PLAYER WHO LEAVES MID-DRIVE KEEPS THE ROLE HE WOULD HAVE HAD.** Quitting as a beater and
   rejoining must not produce a hunter — that is the *"no cheating back to hunter"* half of Karen's
   sentence, and it is the reason the feature exists at all. **Leaving mid-drive does not advance the
   turn.**
4. **THE TEAM SIZES THE DRIVE NEEDS STILL WIN.** Equal teams (differing by at most one) is Karen's
   older rule. If honouring the stored turns would leave the drive unbalanced, **the drive's own
   balancing decides** — today's `Roster.assign` balance check and plain-split fallback, unchanged —
   **and the stored turn is NOT consumed**: that player is still owed that role at the next drive.
   The design must **say how** it is not consumed. The note's §4 says how the Builder intends it
   (the flip at the drive's end is `other(the role he ACTUALLY played)`, so no second field and no
   "was it honoured" flag exists to get wrong); the Architect may rule otherwise but must then say
   which single value carries the fact.
5. **BOTS FILL AS TODAY.** A bot has no userId and no profile; `Bots` is untouched.
6. **STUDIO SAVES IN MEMORY ONLY, exactly as task 170 ruled.** `RunService:IsStudio()` → `Store.memory`;
   the `require` of ProfileStore stays inside `Store.live`'s body; **no harness run and no playtest
   may write a live key.** The memory store's `saved` table outlives a `release`, so a
   release-and-reload inside one Studio session **is** a real round trip (note §2) — that is the
   live proof route, and `Store.memory`'s `seed`/`peek` are the spec route.
7. **THE STUDIO TEST SWITCHES WIN FOR THE DRIVE THEY ARE USED IN.** `DHForestStartRole` and the
   `/beater` chat command (tasks 153, 157, 214) reach the drive through `Match.requestTeam`, whose
   header says it *"IS NOT A STICKY PREFERENCE"*. That stays true: the switch moves THIS drive, and
   the stored turn then mirrors the role he actually played, so the next drive rotates off it. The
   switch must not become a permanent preference, and a stored turn must not swallow the switch.
8. **ONE WRITER, EVERYWHERE.** `Match.Body.setTeam` stays the only writer of `Player.Team`;
   `Match.Roster` stays the only decider of who is on which side; `Economy` stays the only thing
   that persists anything. The drive is handed a **view** (`Economy.view()`) and must not be able to
   open a session, reach the library or write a balance.
9. **NO NEW CLOCK.** No `Heartbeat`, no `task.delay`, no auto-save of ours (ProfileStore owns the
   period; `Store.save` performs no network call).
10. **THE RECORD IS RECONCILED OFF THE LIVE ASSIGNMENT, NOT WRITTEN AT REMEMBERED MOMENTS**
    (Learning Agent L-029, and the root cause of task 214 in this very code path): the mirror is
    written wherever the drive ALREADY writes a team, so an assignment this design did not think of
    (a mid-drive join, a `team` request, a second placement) cannot leave the record stale.
11. **NO NEW FEATURE FLAG ROW.** `Flags.MAX_FLAGS` is at 14 with 14 rows, and a bump is the
    Director's call (TASKS.md 215a(a)) — not this task's. In-drive rotation is already on as a
    plain `Match.CONFIG` boolean (`SWAP_TEAMS_EACH_DRIVE = true`), which is where the persistence
    switch belongs if a switch is wanted at all. See open decision 3.1.
12. **THIS TASK IS NOT 214b.** TASKS.md **214b** (*the role ask as an INPUT to `Roster.assign`, so
    there is one placement instead of two*) touches the same seam and is a task of its own; and
    **214a(a)** (the Forest Test's sweep offers a refused ask on every Heartbeat, stepping the match
    at ~15× `MATCH_STEP_HZ`) is an open defect in the same path. Both are named here so the design
    can leave the seam SHAPED so 214b drops into it — and so the per-event reader this task adds is
    **cheap enough to be stepped 15× a second** while 214a(a) is open (note §5: one table read, no
    clone). The design must not fix either.

---

## 3. The open decisions — the design must rule on each, in writing

**3.1 Does persistence ride the `COINS` flag, and is that acceptable?**
The profile session is gated by `COINS` (`Economy.CONFIG.ENABLED`, `default = false` in git), whose
own row promises that OFF means *"no session is opened, no DataStore key is written"*. So with
`COINS` off the turn is remembered **for the life of the server and no further**, and Karen's
*"remembered across logout/login"* is only true where the override is on — which includes her own
Forest Test place (`DHFlag_COINS=true`). The Builder's recommendation: **accept it, say it out loud
in the design and in the task report, and let the Director decide whether to flip `COINS`'s default
in a task of its own.** The alternative (opening sessions with `COINS` off) breaks that flag's
stated meaning and its kill-switch property, and a separate store is forbidden by decision 2.
**Rule on it, and name what the player sees in each state.**

**3.2 What exactly is stored, and in what vocabulary?**
One field. Builder's recommendation: the **team name** (`"Drivers"` / `"Shooters"`) — the same
strings `Player.Team.Name`, `Score`'s rows, the wire and `Roster.TeamName` already use, so there is
no second vocabulary and no second translator; with **one validator at the `Economy` boundary** that
drops anything that is not one of the two (the discipline `Economy.load`'s four `type(...)` checks
already follow). The alternative is Karen's word (`"hunter"` / `"beater"`, readable in a DataStore
dump, translated by the existing `Body.teamForWord`). Rule on it, give the field its name, its
default for a brand-new player, and say what happens to a corrupted or unknown value.

**3.3 Where does the stored turn reach the pure machine?**
Builder's recommendation: **on the EVENT, filled by `Match.dispatch` on every event**, which is the
`aliveBoars` / `boarEntries` / `beaters` idiom this owner already uses four times and the shape
TASKS.md 214b prescribes. Alternatives: a field on `Phase.State` (then who writes it?), or a reader
in `config` (frozen once at `start`, so it cannot carry per-player data). Rule on it and say which
`Phase.Event` field is added, whether it is read anywhere but `enterAssigning`, and what `Phase`
does when it is absent.

**3.4 How is the turn folded into `Roster.assign` — a new input, or a synthetic `previous`?**
Builder's recommendation: **`Roster.previousFrom(previousAssignment, owed)`, pure**, which returns
`previousAssignment` **by identity** when `owed` is nil or empty, and overrides a player's row with
`other(owed[u])` where a turn is stored. `Roster.assign`'s algorithm, its balance check and its
plain-split fallback are then **untouched**, and the suite's 2..16 sweep still pins exactly what it
pins today. The alternative (a 4th `owed` parameter honoured up to each side's capacity) honours
*more* turns in the unbalanced-previous case but replaces a function the suite pins and changes
today's behaviour. Rule on it.

**3.5 Does a MID-DRIVE join honour the stored turn?**
Today `Phase`'s `join` branch puts a late arrival on the **smaller** team
(`Roster.smallerTeam`), and `docs/design/drive.md` §1.2 forbids moving anybody already playing. With
the lobby (tasks 177, 209) that branch is now the **normal** way a player enters a drive — he walks
onto a truck pad mid-intermission — so it is the common path, not an edge case. Builder's
recommendation: **honour the stored turn only when `smallerTeam` is a TIE** (both sides equal), where
it costs the balance nothing; otherwise the smaller team wins and the turn is not consumed. Rule on
it, and say what the lobby path means for Karen's sentence.

**3.6 When is the field written to the store, and how many store calls does a drive cost?**
Builder's recommendation: `Store.save(userId, { <field> = role })` at each of the two edges —
**0 network calls**, because `Store.save` writes the server-local copy and ProfileStore's own
auto-save and `EndSession` do the writing (note §3.3). Rule on it and state the per-drive cost as a
number the spec can assert through `store.calls()`.

**3.7 Does `Economy`'s view gain a write?**
It must: the drive is the only thing that knows the roles. Builder's recommendation: **two named
functions on `Economy.view()`, in `payDrive`'s shape** — a read (`nextRoleOf` or a whole frozen
table, memoised per decision 12) and ONE named event write — not a setter, and not a second owner.
Rule on their names and signatures, and say explicitly what the drive still cannot do through them.

**3.8 What does a drive with ONE player mean?**
A solo player is a hunter on drive 1 (`ODD_PLAYER_TEAM = "Shooters"`, `MIN_PLAYERS = 1`) and today
already becomes a beater on drive 2 through the in-memory swap — which is the live proof this task's
dispatch asks for (*"two drives in a row as one player = hunter then beater"*). State plainly that a
solo beater drive (zero hunters) **is** the accepted behaviour and is NOT what decision 4's
balancing guard is about: the guard is `Roster.assign`'s existing `|Drivers − Shooters| <= 1` check
and nothing else. `stats.emptyTeamDrives` already counts such a drive; say whether anything more is
wanted.

---

## 4. What the design must contain

1. **The owner table**: which module owns the rotation RULE, which owns the RECORD, which owns the
   WRITE of `Player.Team` — and the sentence that says no two of them can disagree.
2. **The field**: name, type, default, validator, what an unknown value does, and the `schema`
   story (`Store.TEMPLATE.schema` is read and never acted on today).
3. **Every symbol added or changed, by name and signature**, in four places:
   `src/server/Match/Roster.luau` (pure), `src/server/Match/Phase.luau` (pure),
   `src/server/Match/init.luau` (the two edges and the per-event fill),
   `src/server/Economy/init.luau` + `Store.luau` (the record and the view).
4. **The two write edges and the one read edge**, in order, with the reason each is where it is —
   including why the flip goes **before `applyEffects`** on the `Scoring` edge if it does
   (TASKS.md 32a(c) is the measured precedent beside `payDrive`).
5. **The L-030/L-096 check, written out:** `Store.TEMPLATE` is `deepFreeze`d and **enumerated** by
   `Store.read`'s fill-missing / keep-unknown logic. Name **every** consumer of that table — anything
   that enumerates it, seeds it, projects it or asserts its shape (`Store.read`, `Store.memory`'s
   `seed`, `Store.live`'s `ProfileStore.New`, `Economy.load`'s projection, `economy_store.spec`,
   `economy.spec`, `shop.spec`) — and say what each one does with a new key. A key added to a shared
   frozen table is exactly the case rule B was rewritten for after task 196.
6. **The flag-off / no-economy story**, stated as an identity: with no economy injected and with
   `COINS` off, the drive's assignment must be **what it is today, value for value**. Say which
   assertion proves it rather than hoping.
7. **Hazards**, at least these: a stale mirror after an assignment nobody thought of (decision 10);
   two players sharing one owed table reference (`Store.TEMPLATE`'s hazard 1, the frozen-table
   lesson); a turn written for a player whose session was refused or lost mid-drive; the
   `DHForestStartRole` interaction (decision 7); and the cost of the per-event read while 214a(a) is
   open (decision 12).
8. **How it is tested**, spec file by spec file, with the claim each one buys. The Builder's intent,
   for the Architect to confirm or redirect: pure rotation in `tests/server/match_roster.spec.luau`;
   the record, the round trip and the store-call count in `tests/server/economy.spec.luau` and
   `tests/server/economy_store.spec.luau`; the two edges end-to-end in
   `tests/server/match_live.spec.luau`; the balancing override and the Studio-switch case in
   `tests/server/match_phase.spec.luau` / `match_teams.spec.luau`. **If a NEW spec file is wanted,
   say so** — it must then be registered in `SCOPE_SPECS` in `tools/studio_mcp.py` or CI goes red
   (rule G, task 198).
9. **The numeric targets** of note §5, confirmed or corrected.
10. **What this design deliberately leaves alone**, naming 214a(a), 214b, the `COINS` default, and
    anything else it refuses.

---

## 5. Out of scope for this design

- **214a(a)** (the ~15× sweep) and **214b** (one placement instead of two) — named in decision 12,
  shaped for, **not built**.
- Flipping `COINS`'s default, bumping `Flags.MAX_FLAGS`, or retiring any flag row.
- Which stand, which lane, which layout a player gets — that is `drive-layouts.md`.
- Money, licences, the shop, outfits, dogs, scoring.
- Any change to the boar, the weapon, the camera, the Hud or the lobby's own geometry.
- A migration of existing saved keys: the field is **additive** and a profile without it means *no
  turn stored*, which is the brand-new-player case and already has to work.

---

## 6. How the Builder will prove it (for the design to make possible, not to describe)

- **Specs**: the alternation, the persistence round trip (save → release → load → same owed role),
  the balancing override not consuming the turn, and the Studio switches still winning.
- **The gate**: `python tools/studio_mcp.py test` (full, one player). `src/server/Match/` and
  `src/shared/Drive/` are in `TWO_PLAYER_PATHS`, so `test2` is required and the **Director runs it** —
  the Builder stops at `NEEDS TEST2 217 <sha>` before the review.
- **Live, in the Forest Test** (place `130094961655666`), two drives in a row as one player =
  hunter then beater, with a frame of the start card each time; then a rejoin keeping the turn,
  driven through the persistence owner's own seam. The literal steps (Learning Agent L-095, which
  cost task 212 two sessions):
  - `cd <runs-dir>` (the `driven-hunt-runs` folder beside the repo)
  - read and capture Karen's attributes first: `python ftplay.py edit <read-attrs>.luau`
  - `python ftplay.py start`, wait, then **`python ftplay.py server lobby-go.luau`** — in the Forest
    Test a player starts UNENROLLED at the lodge (team=nil, no gun) until he steps on a truck pad
    (rule I); without this there is no drive to be a hunter in.
  - `python ftplay.py server <probe>.luau` for the role, the owed record and the store's `peek`
  - `python ftplay.py capture <out>.png <cam> <look>` for the start card, at the player's own eye
    height (rule F)
  - restore and **read back** Karen's attributes (`DHFlag_COINS`, `DHFlag_DRIVE_BOTS`,
    `DHForestStartRole`, `DHFlag_SHOP`) before stopping
  - `bash smoke.sh 80` → **SMOKE PASS** (rule A)
