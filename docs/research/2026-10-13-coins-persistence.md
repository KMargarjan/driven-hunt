# Coins: what a drive pays, and how a balance survives a session

2026-10-13, task 170. Builder note, rule 1.

## 1. What the system must do

Karen, verbatim:

* 2026-10-11: *"Scoring - yes get money when shoot boar not much but get money and first place ofc
  more legendary more ect"*.
* 2026-10-10 (her design doc): *"Progress trophys, money can purchase more"*.
* 2026-10-12: separate rankings for hunters and beaters; **shooting a piglet is a penalty.**

And the Director's plan line, agreed 2026-10-11: *"Coins are saved safely between sessions"* -- with
the instruction to use a proven library and invent no save layer (rule 2).

So, four things:

1. **A drive pays coins off the POINTS it already produces.** `Match.Score` is the board; task 160
   already made a kill worth what the animal is worth (`POINTS.KIND`), already pays a beater for a
   push, and already answers "who is first" as a rule (`Hud.firstPlaceRank`). Coins are a
   **function of that board** and must not be a second scoring system -- the note that built the
   board said so in its own section 5: *"the points model is built so money is a function of it (a
   rate per point, or a per-kind price beside the per-kind points) and nothing here has to move for
   that"*.
2. **A balance survives the session.** This game has had **no DataStore at all** until today
   (`grep -rn DataStore src/` finds only four design lines saying there is none), so this is the
   first persistence in the project and the first thing in it that can lose a player's work.
3. **A piglet is a penalty.** `POINTS.KIND.cub = 2` becomes negative, and the start card's
   `QUARRY_NOTE` changes in the same commit -- which is literally what `Match.CONFIG`'s own comment
   promised: *"The day Karen protects cubs (her doc says 'NOT piglets/cubs') this row goes to 0 or
   negative and that sentence changes in the same commit"*.
4. **Two rankings, two first places.** The 2026-10-12 scoring note left this open in its section 5:
   *"Whether hunters and beaters belong in ONE table. Built as one... A split -- two columns, two
   firsts -- is a Karen decision"*. She has now decided it.

Numeric targets. Every one is Karen's to retune after one drive, and every one is one line of data:

| | target | why this number |
|---|---|---|
| coins per point | 2 | *"not much but get money"*. A male boar is 10 points, so a boar is **20 coins** -- a readable round number, and the points table stays the one place the ratios live |
| participation | 10 | half a boar for turning up and finishing the drive. The reason a beater whose animals nobody shot does not read a nought, which is the same argument `BEATER_PUSH` rests on |
| 1st place bonus | 25 | 1.25 boars, **per ranking** -- hunters and beaters each pay one. *"first place ofc more"* |
| piglet penalty | -10 points | one whole male, the figure `SAFETY_PENALTY` already uses for the other thing you must not shoot. A cub was +2; it is now -10, a 12-point swing, which is what makes it a mistake rather than a smaller prize |
| coin floor | 0 | a drive can pay a **negative** number of points (two piglets and a safety violation is -30), and a balance must not go below zero. The DRIVE's coin line may be negative; the BALANCE is clamped |
| auto-save period | ProfileStore's own default | not ours to pick; see section 2.1 |

## 2. Sources

Five, all fetched on 2026-10-13 and quoted rather than remembered. The first is the one that becomes
the design.

### 2.1 ProfileStore (MadStudioRoblox) -- **the pattern adopted**

<https://github.com/MadStudioRoblox/ProfileStore> - docs <https://madstudioroblox.github.io/ProfileStore/>
- **Apache-2.0** (`LICENSE` fetched: *"Apache License / Version 2.0, January 2004"*) - **maintained**:
last commit on `main` 2025-07-31, 32 commits, and it is the library its own predecessor now points
new projects at (2.2).

**The dispatch said MIT. It is Apache-2.0** -- for both ProfileStore and ProfileService. Recorded here
because the licence decides what has to ship with the place (Apache-2.0 section 4(a): the licence
copy travels with the distribution), and because getting it wrong in a note is how a repo ends up
distributing code under a licence nobody read. Nothing about Apache-2.0 blocks this use.

Its own one-line description, verbatim: *"Periodic DataStore saving solution with session locking"*.
What session locking is for, in its own words: it *"prevents other game servers from accessing this
data too soon by establishing a session lock"* and *"gracefully switches ownership from one server to
the other without failing new session requests"*.

The API, quoted from the API reference:

* `"ProfileStore.New(store_name, template?) --> [ProfileStore]"`
* `"ProfileStore:StartSessionAsync(profile_key, params?) --> [Profile] or nil"` -- and **it can
  fail**: *":StartSessionAsync() can return nil when another remote Roblox server attempts to
  start a session for the same profile at the same time."*
* `Profile.Data` is *"a table which will either be saved to the DataStore on the next auto-save or
  when you manually end the session"*
* `Profile:EndSession()` -- *"you must always call Profile:EndSession() after you're done working
  with a profile"*
* `Profile.OnSessionEnd` fires when the session ends by our action, by another server taking over,
  or at shutdown, and *"after the Profile.OnSessionEnd signal is fired, no further changes to
  Profile.Data should be made"*
* `"ProfileStore.SetConstant(name, value)"` for `AUTO_SAVE_PERIOD`, `SESSION_STEAL`,
  `CRITICAL_STATE_EXPIRE` -- **we set none of them**: the defaults are the tested ones.

**What it does well.** It is exactly the shape of the problem: load once per server, keep a local
table, auto-save periodically, save on leave, and refuse a second server. It is a single standalone
ModuleScript, it is on Wally (section 4), and it has a documented fake store.

**What it does badly, and both are things this task has to handle rather than hope about.** Both were
found by reading the shipped source (`ProfileStore.luau`, 2242 lines, downloaded and read), not from
the docs:

1. **It does NOT fall back to a mock on its own.** Requiring it in Studio spawns an API-access probe
   (line 2072 onward) that sets `ProfileStore.DataStoreState` to `"Access"`, `"NoAccess"` or
   `"NoInternet"` and prints *"Roblox API services unavailable - data will not be saved"* -- and then
   carries on using the real store. Switching to the fake one is the CALLER's job, and the docs say
   so in one line: `"if RunService:IsStudio() == true then PlayerStore = PlayerStore.Mock end"`.
2. **That probe is a real write.** It is, verbatim:
   `DataStoreService:GetDataStore("____PS"):SetAsync("____PS", os.time())`, with the comment *"This
   will error if current instance has no Studio API access"*. So **requiring the module in a Studio
   session that HAS API access enabled writes a live key as a side effect of the require.** That is
   harmless to our data and it is still a network write our harness must not make, which is why
   section 4 requires the module **lazily, at the boundary, and never in Studio**.

`ProfileStore.Mock` is *"a separate 'fake' DataStore forgotten at shutdown"*, and reading the source
shows how thin it is: `Mock.StartSessionAsync` sets a one-shot `MockFlag` and calls the real method,
which then routes through `MockUpdateAsync` against an in-process `UserMockStore` table. It is the
same code path with a different table -- good for proving our wiring, useless for proving our
arithmetic.

### 2.2 ProfileService (MadStudioRoblox) -- the predecessor, and why it is not used

<https://github.com/MadStudioRoblox/ProfileService> - **Apache-2.0** - **deprecated by its own
author.** The README, verbatim: *"FOR NEW PROJECTS - USE ProfileStore (Click here)"* and *"This
project is no longer supported - it's been stable for a long while and migration to ProfileStore is
possible for most projects."*

What it does well: it is the origin of the pattern, and it states the reason for it better than its
successor does -- *"session-locking is essential to keeping your data protected from multiple server
editing - this is a potential cause of item loss or item duplication loopholes."*

What it does badly: it is unsupported, and its own author says so in the first line of the README.
**Rejected for that reason alone**; the dispatch named it as the fallback and there is no need for a
fallback.

### 2.3 Roblox: `DataStoreService`, Studio API access

<https://create.roblox.com/docs/cloud-services/data-stores> - Roblox documentation, no licence
granted - current.

Verbatim: *"By default, games tested in Studio can't access data stores, so you must first enable
them. Accessing data stores in Studio can be dangerous for live games because Studio accesses the
same data stores as the client application."* The toggle is File -> Experience Settings -> Security ->
**Enable Studio Access to API Services**.

This is the whole justification for the dispatch's item 2. **Karen's Studio has it OFF**, and the
page says why that is the safe setting: Studio and the live game share one key space. So the game
has to be correct in both states, the specs must never depend on the setting, and a Studio playtest
must not be able to write a live balance even if somebody turns the toggle on.

On two servers writing one key, it only gets as far as: `SetAsync` *"can cause data inconsistency if
two servers try to set the same key at the same time"*, and `UpdateAsync` is recommended to *"handle
multi-server attempts"*. **That is not session locking** -- it is a safe single write. It is the gap
2.1 fills, and the reason raw `DataStoreService` is not enough (section 3).

### 2.4 Roblox: data store limits

<https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits> - same licence and
status.

Quoted: server request budgets are `"60 + numPlayers x 40"` per minute for read, write and remove;
key names cap at `"50"` characters; a value caps at `"4,194,304 per key"` characters; per-key
throughput is `"25 MB per minute"` read and `"4 MB per minute"` write.

What this settles: **our budget is not close to being a problem and must not become one.** Sixteen
players is 700 writes a minute available; one balance per player per drive, plus auto-saves on
ProfileStore's own period, plus one save per leave, is a handful. A key is `"player_<userId>"`,
comfortably under 50 characters. A balance plus a per-kind kill tally is a few hundred bytes against
a 4 MB ceiling.

It also sets the **negative** rule: no DataStore call per coin, per kill or per frame. Which is
Roblox's own best-practice page (<https://create.roblox.com/docs/cloud-services/data-stores/best-practices>,
fetched): *"Load a player's data at the start of a session and keep a server-local copy for gameplay.
Update the local copy instead of sending a data store request for every change."* and *"Save it
periodically, when the player leaves, when the server shuts down, and at critical checkpoints such
as purchase processing."* That is ProfileStore's feature list restated as advice, which is the
strongest argument available for borrowing it.

### 2.5 DataKeep (noahrepublic) -- the alternative that was weighed and rejected

<https://github.com/noahrepublic/DataKeep> - **MIT** - active (301 commits, not archived, docs
building). *"A Promised-base auto-saving DataStore library"*.

What it does well: MIT is a simpler licence than Apache-2.0, and it is maintained.

What it does badly, for us: its README does not mention session locking at all, and session locking
is the one property this task is buying. It is also Promise-based, which would pull a Promise library
into a repo that has none and whose every system is written in plain Luau with an injected seam. 20
stars against ProfileStore's lineage is not a reason on its own, but *"the thing I need is not in the
feature list"* is. **Rejected.**

## 3. What is NOT borrowed, and why (rule 2)

* **No save layer of our own.** Not a `DataStoreService:UpdateAsync` wrapper, not a retry loop, not a
  session lock. Section 2.3 shows what raw `DataStoreService` gives (one safe write) and 2.1 shows
  what is missing (ownership between servers, auto-save, save-on-leave, shutdown handling, a fake
  store). Writing those four is the invented foundation `docs/PROJECT_CONTEXT.md` lists as one of the
  four things that killed the previous project: *"Invented foundations... Each produced a run of bugs
  and each was fixed for good only by adopting an established pattern."*
* **No second scoring system.** Coins are a pure function of the board `Match.Score` already
  produces. No coin is awarded anywhere a point is not.
* **No client -> server remote.** `src/client/Match/init.luau`'s header records that this system
  *"fires NO remote: this whole system has no client -> server remote at all, so its inbound exploit
  surface is zero"*. A balance is a **field on the snapshot row**, not a thing a client may ask for
  or spend. A shop is a later task and will need that decision re-opened deliberately.
* **No `ProfileStore.SetConstant`.** The auto-save period and the steal timings are the author's
  tested defaults; a number we pick here is a number nobody has measured.

## 4. The pattern adopted

**ProfileStore 1.0.3, pinned through Wally, reached only through one narrow store interface that the
specs replace with an in-memory double; coins are a pure function of the drive's board, paid once at
the drive's end.**

Concretely:

1. **The library arrives through Wally, pinned.** `lm-loleris/profilestore@1.0.3`,
   `[server-dependencies]` (the package declares `realm = "server"`, so Wally resolves it into
   `ServerPackages/` and a `[dependencies]` entry is **refused**: *"No packages were found that
   matched (Shared) lm-loleris/profilestore"*). The versions published on the index are 1.0.0 to
   1.0.3; 1.0.3 is pinned exactly. `wally.lock` is committed. `ServerPackages/` is git-ignored like
   `DevPackages/`, so it is tied to the commit the same way `DevPackages` already is -- a sha256
   manifest the harness checks (section 5).
   **The vendoring alternative was the fallback and is not needed:** it is on Wally, so Wally it is.
   The one thing checked before choosing it is what Rojo actually syncs, because the package ships a
   `ProfileStoreTest.server.luau` **Script** and a docs folder with images. Its own nested
   `default.project.json` is `{"tree": {"$path": "ProfileStore.luau"}}`, and `rojo sourcemap` with
   the mapping in place resolves the whole tree to exactly **two ModuleScripts** -- the link module
   and the library -- with the test script, the markdown and the images not synced at all. Verified,
   not assumed.
2. **One owner of a player's coins, on the server.** It holds the balances, it is the only thing that
   talks to the store, and it is the only thing that converts points to coins.
3. **The store is an interface, and the specs get the double.** Two implementations behind one shape
   (`load(userId) -> balance`, `save(userId, balance)`, `release(userId)`): the real one, which
   requires ProfileStore **lazily** and only when it is actually going to be used, and an in-memory
   one. The in-memory one is chosen whenever `RunService:IsStudio()` -- so a Studio playtest cannot
   write a live key **even with the API toggle on**, and the harness never requires the library at
   all, which is what keeps 2.1's require-time probe write out of every test run. `ProfileStore.Mock`
   is NOT used for this: it is the library's own code path against a different table, so it proves
   nothing our own double does not, and reaching it still means requiring the library in Studio.
   (A live server is not Studio, gets the real store, and `print`s which one it took -- the
   dispatch's *"clearly logged"*.)
4. **The conversion is pure, and the drive pays once.** `points x COINS_PER_POINT`, plus
   `PARTICIPATION`, plus `FIRST_PLACE` for the top hunter and the top beater, floored so a balance
   never goes below zero. Bots are not in it because **bots have no row**: `docs/design/bots.md`
   states *"no row in Score, no DataStore"* and the mechanism is structural (a bot's id is a
   non-numeric string, and `Match.pushCreditable` and `Phase.participantIds` already refuse it), so
   "bots earn nothing" needs no new predicate -- only a spec that proves it stayed true.
5. **Two rankings, from one board.** `Score.leaderboard` is unchanged and still total; the SPLIT is a
   partition of its output by `row.team`, and `Hud.firstPlaceRank` -- which already answers *nil* for
   a tie at the top and for an all-noughts board -- is asked **once per ranking**. Two lists, two
   badges, one rule, and ioquake3's *"we are tied with the previous client"* still decides both.
6. **A piglet costs points, and the start card says so.** `POINTS.KIND.cub` goes negative and
   `QUARRY_NOTE` changes in the same commit. The start card already prints the kinds with their
   prices (`Match.quarryLines`), so a negative number appears there for free -- which is the test
   that the card was built right in task 158.

## 5. The harness, which this change touches on purpose

`ServerPackages/` is git-ignored, and the harness refuses a synced file that git cannot see
(`ignored_synced_files`: *"Synced files outside git's view... would be tested but could never make
the tree dirty"*). `DevPackages/` is the existing exception and it is pinned instead, by
`devpackages.sha256`, which also carries the `wally.lock` hash. ServerPackages gets the same
treatment and its own manifest -- a second file rather than a rename, so each name stays honest and
`DevPackages`' blame history is undisturbed. The nested package project file gets the same exemption
`DevPackages/` already has.

That is the whole harness change, and it is three small edits plus a generated file. It is listed
here because rule 6 is explicit that a harness fault is a bug: a pin that silently stops covering a
tree is worse than no pin.

## 6. What this note does not answer

* **Spending.** *"money can purchase more"* needs a shop, a price list and -- for the first time --
  an inbound remote. That is its own task with its own exploit surface, and section 3's "no client ->
  server remote" has to be re-opened deliberately when it arrives.
* **Trophies.** *"Progress trophys"* is a second persisted thing. The profile template is a table, so
  a second key costs nothing structurally; what it costs is a design decision about what a trophy is.
* **Legendary.** `POINTS.KIND.legendary = 25` is still a price with no animal behind it, so it pays
  50 coins the day one exists and needs nothing here.
* **Whether coins and points should be one number.** They are not: points are per drive and reset,
  coins accumulate for ever. Karen asked for both (*"get money"* and *"first place"*), and a single
  number cannot be both reset and kept.
* **A cross-server leaderboard.** `OrderedDataStore` and its own much tighter write budget (2.4:
  `"30 + numPlayers x 5"`). Not in scope and not designed for.
