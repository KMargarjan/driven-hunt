# Research: roles rotate each drive, and the turn survives a logout (Task 217)

Rule 1. Written before any code. The system is **not new machinery**: the drive already rotates roles
inside one server session (`Match.CONFIG.SWAP_TEAMS_EACH_DRIVE = true`, honoured by
`Roster.assign`'s `previous` swap), and persistence already has exactly one owner
(`ServerScriptService.Economy` and its `Economy.Store`, Task 170). What this task adds is the join
between the two: **the turn becomes a per-player fact that outlives the session.**

Karen, 2026-10-11 (and again on the v1 plan of 2026-10-19, *"continue working wht you can now"*):

> *"ROLES ROTATE: you start as a hunter, next round you are a beater; it is REMEMBERED across
> logout/login (no cheating back to hunter)"*

and on 2026-10-11, in her own words about the feel:

> *"you start as a hunter then next round you are beater ... and yes beater are behind animals and
> moving towards hunter line (road) like in real life"*

---

## 1. What the system must do

1. **Alternate.** A player who shot in drive *N* pushes in drive *N+1*, and back again.
2. **Remember across logout/login.** Leaving the server and coming back must not hand a beater a gun.
   This is the anti-cheat half and it is the reason the fact has to be persisted at all.
3. **Never break the teams the drive needs.** Equal sides (differing by at most one) is Karen's older
   rule and it is older than this one: the roster still decides, and a turn the roster could not
   honour is **not consumed** -- the player is still owed that role next drive.
4. **Leaving mid-drive must not advance the turn.** A beater who disconnects at 00:30 and rejoins is
   still a beater; the role he is playing is the role he comes back to.
5. **The Studio test switches still win.** `DHForestStartRole` and `/beater` (tasks 153, 157, 214) are
   how the Director and Karen test a role at all; a stored turn must not take that away.
6. **Bots fill as today.** They have no userId and no profile, so they cannot own a turn.
7. **No second store, no second clock, no second owner.** One persistence owner (Task 170), one
   roster (`Match.Roster`), one writer of `Player.Team` (`Match.Body.setTeam`).

### Must not

- No new DataStore name and no second key per player (the profile is one table: `Store.TEMPLATE`).
- No `Heartbeat`, `task.delay` or auto-save of ours (Task 170's rule; ProfileStore owns the period).
- No new source of truth for "which side is he on": that is `state.assignment`, and the stored record
  is a **mirror of it**, written by whoever already writes it.
- No client -> server remote, and nothing new on the wire.

---

## 2. What is already in the code, by symbol (read in this session)

| Fact | Where | Why it matters here |
|---|---|---|
| Rotation already happens within a session | `Roster.assign`'s `previous` swap, `SWAP_TEAMS_EACH_DRIVE = true` (`src/server/Match/init.luau` `CONFIG`) | **Alternation is not the new part.** A solo player is `Shooters` on drive 1 (`ODD_PLAYER_TEAM`) and `Drivers` on drive 2 already |
| The last drive's split is remembered in memory only | `Phase.State.previousAssignment`, written by `enterScoring` | it dies with the server, and with the player: a rejoiner is `unknown` to `assign` and fills the smaller side |
| The roster is pure and keyed by userId | `src/server/Match/Roster.luau` header | a per-player turn can be a pure input to it, with no Instance and no service |
| Teams are written in exactly one place | `applyAssignTeams` -> `Body.setTeam` (`src/server/Match/init.luau`) | the one honest place to mirror "what role is he playing" |
| The drive already calls the persistence owner on the `Scoring` edge | `dispatch`'s `world.economy.payDrive(...)` block, before `applyEffects` | the turn's flip belongs on that same edge, for the same measured reason (TASKS.md 32a(c)) |
| World facts reach the pure machine on the EVENT | `dispatch` fills `aliveBoars`, `boarEntries`, `boarCapacity`, `beaters` on every event | the shape a stored-turn reader must use, and the shape TASKS.md **214b** already prescribes |
| The profile is one table with additive keys | `Store.TEMPLATE`, `Store.read`'s fill-missing / keep-unknown halves | a new field costs no store name and survives a rollback |
| Studio never writes a live key | `Economy.storeKindFor(isStudio)`; the `require` is inside `Store.live`'s body | a playtest proves the round trip against `Store.memory`, which is also the only seam a spec has |
| The memory store's saved table outlives a release | `Store.memory`'s `saved` closure, and `peek` | so a release-and-reload **inside one Studio session** is a real round trip, not a simulation |
| The role word <-> team translation already exists | `Body.teamForWord` / `Body.ROLE_WORDS`, `ForestTest.roleFor` | no new vocabulary is needed |

---

## 3. External sources

### 3.1 ioquake3 -- `code/game/g_team.c` (`PickTeam`, `TeamCount`) -- **the balance rule adopted**

<https://github.com/ioquake/ioq3> -- GPL-2.0, maintained (active commits; this repo already borrows
its `CalculateRanks` / `RANK_TIED_FLAG` rule in `src/shared/Drive/Rank.luau`).
`PickTeam` counts both sides and answers the smaller one; a player's *requested* team is honoured by
the layer above only when it does not unbalance the match.
**Good:** the preference is advisory and the count is authoritative, which is exactly Karen's
ordering -- equal teams first, rotation second. **Bad for us:** it has no notion of a turn that
persists (a Q3 player's team dies with his client), so only the *ordering* is borrowed.

### 3.2 Xonotic -- `qcsrc/server/teamplay.qc` and `g_balance_teams_prevent_imbalance`

<https://gitlab.com/xonotic/xonotic-data.pk3dir> -- GPL-2.0, maintained.
Its documented rule is the same one, stated as a cvar: a team change -- including the auto-balance
shuffle between rounds -- is refused when it would create an imbalance.
**Good:** it names the per-round case explicitly, so sides are re-decided every round and balance is
checked at that moment rather than carried forward. **Bad for us:** the shuffle is *random*, which
Karen's rule is not (she wants a predictable alternation), and it is QuakeC.
**Honesty (rule 8):** I did not read this file in this session; the rule above is taken from its
public cvar documentation. Nothing is copied from it -- it is cited as corroboration that
"balance beats preference, checked per round" is the standard shape.

### 3.3 ProfileStore 1.0.3 -- MadStudioRoblox -- **the save layer, already adopted**

<https://github.com/MadStudioRoblox/ProfileStore> (Apache-2.0, maintained), API docs
<https://madstudioroblox.github.io/ProfileStore/api/>. Already pinned through Wally and already the
only save layer in this repo (`docs/research/2026-10-13-coins-persistence.md`).
**Good:** session locking, a server-local copy, periodic saving and `EndSession` are all its job, so
a new field costs **zero** DataStore requests -- `Store.save` writes the local table and nothing else.
**Bad:** nothing new; the one hazard is ours, and it is that `Store.TEMPLATE` is `deepFreeze`d and
enumerated by `Store.read`, so a new key must be a plain value with a safe default.

### 3.4 Roblox Creator Docs -- data stores, best practices

<https://create.roblox.com/docs/cloud-services/data-stores/best-practices> -- current, no licence
granted. *"Load a player's data at the start of a session and keep a server-local copy for gameplay.
Update the local copy instead of sending a data store request for every change."*
**Good:** it is the direct authority for "extend the existing record, do not open a second store",
which is also the Director's own instruction for this task.
**Bad:** it says nothing about game rules; it is a constraint, not a pattern.

### 3.5 Borrowed from inside this repo (rule 2 applies to internal patterns too)

- **`aliveBoars` on the event** (`Match.dispatch`): how a world fact reaches the pure machine.
- **`payDrive` on the `Scoring` edge, before `applyEffects`** (Task 170): where a per-drive write to
  the persistence owner goes, and the measured reason it goes *before* the effects.
- **`Economy.view()`** (tasks 170 and 178): the read-only-plus-named-events view a world is handed, so
  the drive cannot open a session or reach the library.
- **`Store.read`'s fill-missing / keep-unknown** (Task 170): how an additive field survives both an
  older build and a rollback.

---

## 4. The pattern adopted, and why

**One value per player, and it is the role he is OWED.** `nextRole`, persisted in the existing
profile. Two write edges, both of them places that already write:

1. **Whenever the drive writes a team** (`applyAssignTeams`, the one writer of `Player.Team`):
   `owed[u] = the role he is now playing`.
2. **On the `Scoring` edge** (the drive is finished, beside `payDrive`): `owed[u] = the OTHER role`.

and one read edge: `enterAssigning` consults it through `Roster.assign`.

**Why this shape, and not "store the role he just played" or "store a counter":**

- It makes requirement 3 (*the turn is not consumed when balance overrides it*) **structural, not
  bookkeeping**: the flip at the drive's end is `other(what he ACTUALLY played)`, so a man who was
  owed beater and was made a hunter by the balance rule is owed beater again -- with no second field
  and no "was it honoured" flag to get wrong.
- It makes requirement 4 (*leaving mid-drive does not advance the turn*) structural too: edge 1 has
  already written the role he is playing, and edge 2 only fires for a drive that reached `Scoring`.
- It is **level-triggered off the live assignment** rather than event bookkeeping, which is the
  lesson tasks 202 and 214 both paid for in this exact code path (`ESCALATE.md`, L-029).
- It needs **no new algorithm in `Roster.assign`**: `other(owed[u])` is exactly the shape `previous`
  already has, so the stored turn is folded in as a synthetic `previous` row
  (`Roster.previousFrom(previousAssignment, owed)`, pure) and today's swap, balance check and
  plain-split fallback do the rest, unchanged. With no stored turn the table is `previousAssignment`
  itself, by identity, and the game is bit-for-bit what it is today.

**Invented, with the reason rule 2 wants (small, and named):** `Roster.previousFrom` and
`Roster.other` are ours. No library has them, they are a few lines of pure Luau each, and the
alternative -- a second assignment algorithm honouring preferences up to a capacity -- would replace
a function the suite already pins at every roster size from 2 to 16, which is a bigger change than
the feature.

---

## 5. Numeric targets, each one checkable

| Target | Value | How it is checked |
|---|---|---|
| Roles alternate for one player over two completed drives | hunter -> beater | a spec over two `Scoring` edges; live, two drives in the Forest Test, a frame of each start card |
| A rejoin keeps the turn | the same owed role before and after `release` + `load` | `Store.memory`'s `peek` in a spec; live through the owner's own seam |
| Teams still differ by at most | **1** player, every roster size 2..16 | `match_roster.spec`'s existing sweep, unchanged |
| A turn the balance rule could not honour | **not consumed** (still owed next drive) | a spec: owed = beater for all N, N >= 4 -> plain split, owed unchanged after `Scoring` |
| Store calls added per drive | **0** network calls (`Store.save` writes the local copy) | `store.calls()` in a spec |
| New DataStore names | **0** | `Economy.CONFIG.STORE_NAME` unchanged |
| New profile fields | **1** (`nextRole`), additive, default *no turn* | `economy_store.spec`: an old key round-trips unchanged |
| Behaviour with no persistence (flag off, or no economy injected) | identical to today | the whole suite, plus a spec asserting `previousFrom(prev, nil) == prev` |
| Extra work per event in `dispatch` | one table read, **no clone** | the reader answers a memoised frozen table, rebuilt only on a write |

---

## 6. What I could not verify (rule 8)

- **Whether a live DataStore round trip keeps the field.** Studio uses `Store.memory` by construction
  (Task 170), so nothing in a playtest or a harness run touches a real key. The round trip is proved
  against the memory store and against `Store.read`'s contract; the live path is the same
  `Store.save` call the balance already uses.
- **Xonotic's source**, as stated in 3.2: cited from its cvar documentation, not read.
- **Whether Karen reads "the turn was not consumed" as correct** when the balance rule overrides
  rotation. It is the Director's decision as written in the dispatch; she has not seen it.
- **Persistence is gated by the `COINS` flag**, because the profile session is. With `COINS` off
  (today's default in git) the turn is remembered for the life of the server and no further. Named as
  an open decision in `reviews/task-217/BRIEF.md` section 3.
