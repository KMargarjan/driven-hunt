# Design: the role switch (a man who bought the hunter's place asks to beat, for one drive)

**Task 229.** Written to `reviews/task-229/BRIEF.md`, which carries the Director's dispatch of
2026-10-21 and overrides anything older in `docs/`, `TASKS.md` and any earlier design. Note:
`docs/research/2026-10-21-the-role-switch.md`. The Designer's spec is section 3 of
`<runs-dir>/design/shop2-spec.md`, which is **final and not revisited here**.

Karen, 2026-10-21, verbatim:

> *"we also need to have posibility to choose once you have a card always hunter maybe sometimes I
> want to be a beater we need to find a way to do that"*

**This is not a new system.** The bought privilege already exists and already reaches the roster
(`Roster.assign`'s fourth argument `always`, task 221 round 3) and the shop already sells it
(`Shop.ROWS[Shop.ITEM.ALWAYS_HUNTER]`, `grants = { alwaysHunter = true }`). What this task adds is
the one input the drive has never had: **a one-drive opt-out, owned by the server, drawn in two
places, and spent by exactly one assignment.**

---

## 1. What it must do, and what it must not do

### 1.1 Must do

1. **One wish per player**, `HUNTER` (the default) or `BEATER`, **server-owned and client-told**. A
   client ASKS; one server function writes.
2. **`BEATER` means both halves together**: the `always` override is not applied to him for that
   drive, **and** the roster seats him on the beater side FIRST. Either half alone is not the feature
   (note §1, rule 2).
3. **It resets to `HUNTER` when the drive he asked for has given him a side**, and the reset is a
   level rule on the owner's own scan, never a handler on a signal (BRIEF 4).
4. **Invisible to a non-owner**, in both places: absent, not greyed, not locked.
5. **Unavailable with words when it cannot be honoured.** Four captions, as data rows.
6. **Two surfaces, one value.** Both redraw from one attribute; neither holds a copy.
7. **No new feature flag, no new profile field, nothing persisted.**

### 1.2 Must not

* **No second writer of the wish.** One function in one module.
* **No second writer of a team.** `Match.Body.setTeam` stays the only one; the wish is an INPUT to
  `Roster.assign` and never a team.
* **No client decides anything**: not whether he owns the item, not whether the wish is honoured, not
  whether a drive has beaters.
* **No new per-frame wire.** One memo read per scan, one attribute write per change.
* **No new remote on the SHOP's folder**, and no second client sender.
* **No new spec file**, therefore no new `SCOPE_SPECS` key and no new `BLAST_RADIUS` prefix.
* **It must not touch `Economy.Store`'s template, `Flags.DEFAULTS`, or `Roster.previousFrom`'s
  inversion.**

---

## 2. The one question: who owns `roleWish`

**Ruled: `ServerScriptService.Lobby`.** `Lobby.setRoleWish` is the one writer.

The reason is the reset, and it is structural rather than aesthetic. BRIEF 4 fixes the reset as
level-triggered reconciliation **on the owner's own scan**. Exactly one candidate has a scan over
every player that already reconciles per-player state against the drive:

* `Lobby.step` runs at `cfg.SCAN_HZ` (10) and walks every occupant through `stepPlayer`
  (`src/server/Lobby/init.luau`);
* `stepPlayer` already reconciles **two** per-player facts level-triggered with edge writes —
  `clearLeaveAt` and `setPadMine`, whose own comment is *"WRITTEN ONLY WHEN IT DIFFERS … and asked
  every scan so it is a LEVEL rule"*;
* it already reads the drive through injected readers (`world.inDrive` = `Match.isParticipant`,
  `world.isHeld` = `Match.isHeld`);
* and it already owns *"the truck leaving"* — `Pads.DEPART` → `Lobby.depart` → `Lobby.enrolHere`.

The other four candidates each fail on something their own header says:

| Candidate | Why not |
|---|---|
| `ServerScriptService.Shop` | its header: *"IT NEVER WRITES A LOADOUT, A POCKET, A TEAM, A TOOL, A CHARACTER OR ANYTHING DRAWN"*. A role wish is team-shaped. It also has no scan: it is a door and a rate bucket (`Shop.onRequest`, `Shop.rateLimited`) |
| `ServerScriptService.Economy` | its header forbids holding a `Player` and firing a remote (quoted in `Shop`'s own header); it reads no Instance, so it cannot write a `Player` attribute; and the wish is neither owned nor saved, so it is not this owner's kind of fact |
| `ServerScriptService.Match` | the wish is set **before any drive exists**, by a man who may never join one, and `Match` is *"HANDED the roster instead of taking it"* (`Lobby`'s header). `Match.requestTeam` is deliberately *"NOT A STICKY PREFERENCE"* — a stored wish inside `Match` would contradict that function's stated rule in the same file |
| a fifth owner | rule 3 needs a written reason, and there is none: every mechanism this feature needs already exists in `Lobby` (a scan, a door, a rate bucket, two per-player attributes, a frozen reader handed to the drive) |

**The sentence that says no two of them can disagree.** There is one table (`roleWish`), one writer
(`Lobby.setRoleWish`), one mirror of it on the wire (the `DHRoleWish` attribute, written by the same
function), one reader for the drive (`Lobby.beaterWishes()`, frozen and memoised) and one read on the
client (`Hud.renderObjective`, which tells both panels). `Match` learns a boolean table and nothing
else; `Roster` stays pure; `Economy` is not touched at all beyond being READ through the memo it
already publishes.

### 2.1 The full owner table

| Thing | The one writer | Who decides | On disk |
|---|---|---|---|
| **the wish itself** (`roleWish[userId]`) | `ServerScriptService.Lobby` — `Lobby.setRoleWish`, the only writer, called from `Lobby.onRoleRequest` and from the reconciliation in `stepPlayer` | `Lobby.onRoleRequest` (the ask) and the level rule (the reset) | `src/server/Lobby/init.luau` |
| **the `Player` attribute `DHRoleWish`** | `ServerScriptService.Lobby`, in `setRoleWish`, edge-triggered — `setPadMine`'s shape, and for its reason | the same function | `src/server/Lobby/init.luau` |
| **the attribute's NAME and the two words** | nobody at run time: frozen data (`Lobby.ROLE_WISH_ATTRIBUTE`, `Lobby.ROLE_WISH`), beside `PAD_MINE_ATTRIBUTE` and `PAD_STATE` | — | `src/shared/Lobby/init.luau` |
| **who owns `ALWAYS HUNTER`** | `ServerScriptService.Economy` (unchanged): `Economy.alwaysHunters()`, the frozen memo over `ownedSets` | `Shop.grantsAlwaysHunter`, pure | `src/server/Economy/init.luau`, `src/shared/Shop/init.luau` |
| **the ROSTER RULE** (what a wish does to a split) | `Match.Roster` — PURE, no services, no Instances, no clock | — | `src/server/Match/Roster.luau` |
| **WHO IS ON WHICH SIDE this drive** | `Match.Phase` (`enterAssigning`, the `join` branch), in `Phase.State.assignment` — **unchanged** | — | `src/server/Match/Phase.luau` |
| **`Player.Team`** | `Match.Body.setTeam` — **unchanged** | `applyAssignTeams` / `applyUnassign` | `src/server/Match/Body.luau` |
| **the pad dialog's switch block, and every rectangle in that dialog** | `Hud.PadPanel` (`PadPanel.relayout`, new) | the server, through `DHRoleWish` | `src/client/Hud/PadPanel.luau` |
| **the shop row's two halves / the detail pane's switch block** | `Hud.ShopPanel` (`ShopPanel.relayout`, existing) | the server, through the same attribute | `src/client/Hud/ShopPanel.luau` |
| **the one client read of the attribute** | `Hud.renderObjective` — *"THE ONE EVALUATION"*; two panels are TOLD | — | `src/client/Hud/init.luau` |
| **the words** | nobody at run time: `Lobby.CONFIG.PADS.PANEL` rows and `Shop.CONFIG.TEXT` rows | Karen | `src/shared/Lobby/init.luau`, `src/shared/Shop/init.luau` |
| **the per-player role rate bucket** | `ServerScriptService.Lobby` (`lastRoleRequestAt`), emptied by `Lobby.forget` and `Lobby.stop` | — | `src/server/Lobby/init.luau` |

---

## 3. The value: one attribute, three states

```luau
Lobby.ROLE_WISH_ATTRIBUTE = "DHRoleWish"
Lobby.ROLE_WISH = { HUNTER = "hunter", BEATER = "beater" }
```

| Attribute | Means | What the two surfaces draw |
|---|---|---|
| **absent (nil)** | he does not own `ALWAYS HUNTER` — **or there is no shop, no economy and no lobby in this build** | nothing. No block, no row growth, no halves |
| `"hunter"` | he owns it and wants his stand | the control, `HUNTER` lit |
| `"beater"` | he owns it and has asked to beat the next drive | the control, `BEATER` lit, caption `ASKED FOR ALREADY` |

**ONE attribute answers both questions, and that is the ruling BRIEF 2c asks for.** The two facts
("does he own it" and "what did he ask for") are not separable in anything that draws: decided item 5
makes the control **absent** for a non-owner, so no surface ever needs "owned" without also needing
the wish. Keeping them apart would mean two attributes with a window in which they disagree, and
would leave the pad dialog needing a second source — which is the thing BRIEF 2c measured:
`ShopState` is fired **only in reply to a request** (`Shop.onRequest` → `reply` → `ShopState:FireClient`),
so a man standing on a pad who never opened the shop has no wire answer at all.

**It is a state WORD and not a boolean**, for `DHPadMine`'s stated reason (*"the banner says three
different things and a boolean would need a second attribute to tell them apart"*) — here, three
states.

**`WireRow.owned` is NOT a second source.** It keeps deciding the row's `OWNED` tag and its big
button (`Shop.rowsFor`, `ShopPanel.buttonStateFor`) and it decides **nothing about the switch**. The
switch, on both surfaces, is drawn from the attribute alone. That is what makes "two panels drifting
apart" structurally impossible rather than merely unlikely.

**Nothing is persisted.** `Economy.Store.TEMPLATE` is untouched; the wish dies with the drive and a
logout clears it by construction (`Lobby.forget`, wired at `ForestTestBoot.server.luau`'s
`Players.PlayerRemoving`).

---

## 4. The wire IN: one new door on the lobby's own folder

**Ruled: a second `RemoteEvent` in `ReplicatedStorage.Lobby.Remotes`, `RoleRequest`, handled by
`Lobby.onRoleRequest`. One wire in, none out.**

`Lobby.onPadRequest` is **not** extended. It is *"the pad's one door"*, every field of its payload is
about a pad, and it refuses everything else as `bad-request` — a message that is not about a pad
would make one handler answer two questions, which is `docs/PROJECT_CONTEXT.md`'s named failure.
`Shop.onRequest` is not extended either: `Shop.KIND` is a two-row whitelist over a purchase, and its
owner may not write a team.

```luau
-- src/shared/Lobby/init.luau
Lobby.ROLE_REQUEST_REMOTE = "RoleRequest"   -- beside PAD_REQUEST_REMOTE
-- `Lobby.remotes()` gains one member: { PadRequest = …, RoleRequest = … }
```

```luau
-- src/server/Lobby/init.luau
-- PUBLIC, for `onPadRequest`'s stated reason: `OnServerEvent` can only be raised by a client
-- (task 80), so a spec must drive it by parameter.
function Lobby.onRoleRequest(player: any, request: any, now: number?): any
```

The order of its checks, and what each one counts:

| # | Check | Verdict | Counter |
|---|---|---|---|
| 1 | not started | `nil` | — |
| 2 | `type(request) ~= "table"` or `request.role` is not one of the two words, or any other field is present | `{ ok = false, refused = "bad-request" }` | `stats.badRequests` |
| 3 | `Lobby.roleRateLimited(userId, at)` | `nil` | `stats.rateLimited` |
| 4 | he does not own `ALWAYS HUNTER` (the injected reader) | `{ ok = false, refused = "not-an-owner" }` | `stats.refusedBy["not-an-owner"]` |
| 5 | `world.inDrive(userId) == true` | `{ ok = false, refused = "in-a-drive" }` | `stats.refusedBy["in-a-drive"]` |
| — | otherwise | `{ ok = true, role = r }` | `stats.roleAsks`, `stats.roleWrites` on a change |

**Check 4 is NOT a forgery.** It is `Lobby.stats`' own split, written in that file: *"a FORGED payload
(`badRequests`) is a different fact from a legal request the game said no to (`refusedBy`), because
counting it as a bad request would hide a mis-wired provider inside the forgery counter"*. A build
where the provider was never wired would otherwise read as an attack. That split **is** research-note
target 6.

**Its own rate bucket, with `PADS.REQUEST_MIN_INTERVAL`'s number (0.25 s) and not its bucket.**
Sharing the bucket would make "press BEATER, then press `1 / 1`" lose the size pick, because
`Lobby.padRateLimited` writes `lastPadRequestAt` on every accepted call. One number, two buckets,
both pruned by `Lobby.forget` and `Lobby.stop` — the Reviewer's task-178 note (*"a bucket with no
pruner grows for the life of the server"*).

**THERE IS NO REPLY REMOTE**, which is `Lobby`'s own rule: the attribute is the answer, and every
refusal is a state the client could already see.

### 4.1 The client's one sender

`Hud.PadPanel` is already *"this client's one door onto `ReplicatedStorage.Lobby.Remotes`"* (its
header) and is already handed the whole remotes table by `Hud.whenReady` → `PadPanel.setRemotes`. It
gains the one sender:

```luau
-- src/client/Hud/PadPanel.luau
-- ONE PRESS, ONE MESSAGE, and it sends nothing for a word that is not in `Lobby.ROLE_WISH`.
function PadPanel.sendRoleWish(wish: string): boolean
```

**`ShopPanel` does not send and holds no lobby remote.** It is handed `roleAsk` in its
`collaborators` bag at `Hud.start`, exactly as it is handed `Cursor` and `Input` today, and
`Hud.start` binds it to `PadPanel.sendRoleWish`. That keeps **one** sender, adds **no** require edge
(and in particular no `ShopPanel` → `PadPanel` edge, which would be a cycle: `PadPanel` already
requires `ShopPanel` for `LOOK`/`FONT`/`spaced`).

**No optimistic redraw.** The press sends and nothing else; the lit half changes when the attribute
changes, one scan later (≤ 0.1 s + a frame). This is deliberately **not** task 209's optimistic
banner: that existed because a measured 3.65 s of silence followed a click, and that 3.65 s was the
pad's own `sizing → filling` round trip through a 10 Hz scan plus a state change plus replication.
Here the server writes the attribute **inside `onRoleRequest`**, not on the next scan, so the round
trip is one network hop — and a control that lit optimistically would be a client holding an opinion
about a value whose whole security is that it does not.

---

## 5. The wire OUT: the attribute, read once, told twice

```luau
-- src/client/Hud/init.luau, inside Hud.renderObjective, beside the DHPadMine read
local wish = if lobbyData then Players.LocalPlayer:GetAttribute(lobbyData.ROLE_WISH_ATTRIBUTE) else nil
…
PadPanel.setRoleWish(wish, viewportHeight)
ShopPanel.setRoleWish(wish)
```

One read a frame (a cached attribute read), two tells, both edge-triggered inside. That is this
function's own rule, stated for `asking`: *"read ONCE a frame and used by three things … Two reads
would be two answers to one question."* The caption-selecting facts are **already in this function**
and nothing new is read for them:

| Fact the captions need | Where it already is |
|---|---|
| does he own it / what did he ask for | the one attribute read above |
| what side has the drive given him | `team` — `matchSystem.myTeam()`, or `Players.LocalPlayer.Team.Name`, read at the top of `renderObjective` |
| has this client already asked for a party of one | `PadPanel`'s own `sent`, which it holds |

**`Player.Team` is nil between drives**, because task 177's `applyUnassign` hands a team back
(`Phase`'s `unassign` effect, *"the one that hands a team BACK"*), so `team == nil` is "no drive has
him" and the control is available. No new snapshot field, no new remote, nothing added to
`Match.snapshot`.

---

## 6. The RESET: one level rule, two different drive facts, and why they cannot contradict

The reconciliation lives in `stepPlayer`, **before** its `inDrive` early return, and is one call:

```luau
-- THE WISH IS SPENT BY AN ASSIGNMENT AND BY NOTHING ELSE (task 229). `clearLeaveAt`'s and
-- `setPadMine`'s discipline: asked every scan, written only when it differs.
setRoleWish(player, Lobby.wishFor(userId, owns, assigned))
```

```luau
-- PURE and exported. WHAT THIS MAN'S ATTRIBUTE MUST SAY RIGHT NOW.
--   * he does not own it            -> nil   (no control anywhere)
--   * the drive has given him a side -> HUNTER (the wish has been spent)
--   * otherwise                      -> the stored wish, or HUNTER
function Lobby.wishFor(stored: string?, owns: boolean, assigned: string?): string?
```

and the stored row is dropped by the same call whenever the answer is `HUNTER`, so **the
reconciliation only ever clears; it never invents a wish.** Once cleared it stays cleared until he
asks again — which is what makes every case below terminal.

**The reader is `world.assignedTeam` and NOT `world.inDrive`, and that is the whole correctness of
the reset.** `Match.assignmentOf(userId)` already exists and is already public, described in its own
header as the read half of this seam (*"beside `isTied` / `isHeld` / `assignmentOf`"*), so this is
a seventh injected seam over an existing function and no new reader in `Match`.

Keying the reset on `inDrive` would **break the feature in its commonest path**: `Lobby.depart` →
`Match.enrol` → a `join` event in `Waiting` makes him a participant immediately, while
`enterAssigning` (which reads the wish) happens on a LATER `Match` step. The lobby's next scan is
0.1 s away. So a wish cleared on `inDrive` would be gone before the assignment that was supposed to
spend it. Measured from the code: `Phase.step`'s `join` branch assigns a team only when the phase is
`Running` or `Assigning`; in `Waiting` it adds a participant and nothing else.

**The door uses the other fact on purpose.** `Lobby.onRoleRequest` refuses on `inDrive` (check 5):
*may he still change his mind* — no, once the truck has him. The reset asks *has it been spent* —
only once the drive has given him a side. `inDrive` becomes true first and `assignedTeam` second, so
the two can never contradict; they can only leave a window of one or two scans in which the wish is
unchangeable and not yet spent, which is exactly right.

| Case the BRIEF names | What closes it | Worst-case lag |
|---|---|---|
| **the truck departs** | he is assigned (on the `join` in `Assigning`/`Running`, or at `enterAssigning` out of `Waiting`); the next scan reads a team and writes `HUNTER` | **1 scan = 0.1 s** after the assignment, plus one frame of replication |
| **a dismissal between drives** | already cleared at that drive's assignment; `dismiss` empties the roster and the reconciliation never re-invents a wish | — |
| **`Scoring -> Assigning`** | `assignedTeam` answers a team across the whole of both drives, so the wish is cleared once and cannot survive into the second | 1 scan |
| **he leaves** | `Lobby.forget(userId)` drops `roleWish[userId]` and `lastRoleRequestAt[userId]`, beside the four rows it already drops. Wired in production at `ForestTestBoot.server.luau`'s `Players.PlayerRemoving` | immediate |
| **a Reset** | `Lobby.stop()` clears the table and sets `DHRoleWish` to nil on every `touched` player, in the loop that already hands back `DHLobbyLeaveAt` and `DHPadMine`; `Lobby.start()` clears the table with the other six | immediate |

**A party that cancels keeps its wishes, and that is correct**: a man who enrolled and was dismissed
before any assignment never got the drive he asked for. It falls straight out of the reader choice
rather than needing a rule.

---

## 7. The ROSTER rule: a fifth argument, not a filter

**Ruled: `Roster.assign(userIds, previous, config, always, beaters)`.** Filtering `always` at the
owner's edge is rejected, and the rejection is measured rather than argued.

* **Filtering alone fails requirement 2.** Drop him out of `always` and he lands in `assign`'s `rest`
  list, ordered by `owedRank` — the ordinary rotation, which seats him as a hunter about half the
  time. The note's own words: *"One without the other is not the feature."*
* **Filtering plus a synthetic `owed` row fails on a measurement that is already in the file.**
  `Roster.assign`'s header records the Director's 2026-10-20 overrule: *"folding the privilege into
  the synthetic `previous` moved the SWAPPED counts by two, so on an even roster the balance check
  discarded the whole swap and the plain split put a low userId on the beaters EVERY drive."* A wish
  fed through `owed` is the same device and inherits the same defect — and worse, whenever anybody
  else owns the item `assign` takes the privilege branch, where `previous` is only a tie-break.
* **A fifth argument is symmetric with the fourth**, deals against the same `Roster.shooterSlots`
  arithmetic, and is balanced **by construction** rather than by a check that can throw the whole
  thing away.

### 7.1 The algorithm, with the balance proved

`slots = Roster.shooterSlots(#ids, config)` (unchanged), `driverSlots = #ids - slots`.

1. **`wishers = ids ∩ always ∩ beaters`**, sorted by userId (deterministic, this module's own rule).
   `holders = ids ∩ always \ beaters`.
2. **The wishers take driver places FIRST**, up to `driverSlots`. A wisher beyond `driverSlots` is
   **not honoured** and is appended to `holders` — he owns the hunter's place and did not get what he
   asked for, so he gets what he paid for. No second branch.
3. Today's privilege pass over `holders` against `slots`, unchanged: `Roster.yieldOrder` from the
   back, the front `yielding` to `Drivers`, the rest to `Shooters`.
4. Today's `rest` pass, unchanged: remaining hunter slots by `owedRank`, the remainder drive.

**`beaters` nil or empty takes today's path, untouched, and that is structural**: step 1 produces an
empty `wishers` list, step 2 does nothing, and `holders` is today's `holders` — so the `#holders > 0`
branch, the swap branch and the plain split are the lines they are today, value for value. That is
research-note target 2, and `match_roster.spec` asserts the identity at every size 2..16 rather than
describing it.

**Balance, proved.** Let `w = min(#wishers, driverSlots)`, `keep = min(#holders', slots)`,
`yielding = #holders' - keep`, `#rest = #ids - w - #holders'`, `remaining = slots - keep`. Final
shooters `= keep + min(#rest, remaining)`.
*If `yielding > 0`* then `keep = slots`, `remaining = 0`, so shooters `= slots`.
*If `yielding = 0`* then `#rest ≥ remaining ⟺ #ids - w ≥ slots ⟺ w ≤ driverSlots`, true by step 2,
so shooters `= slots`.
**Shooters = `slots` in every case**, and `Roster.shooterSlots`'s own arithmetic is what makes
`|Drivers − Shooters| ≤ 1` — which `match_roster.spec`'s existing sweep already pins. Target 1.

**`Roster.overruled` gains a third argument, and this is a defect the feature would otherwise
create.** Today a wisher is in `always` and finishes on `Drivers`, so `Roster.overruled(assignment,
always)` would put his name on the wire and his own Hud would tell him the balance rule beat the
place he paid for — when in fact he asked for it. So:

```luau
-- `wishes` nil -> today's answer BY IDENTITY. A man who ASKED to beat was not overruled.
function Roster.overruled(assignment: Assignment, always: { [number]: boolean }?, wishes: { [number]: boolean }?): { number }
```

and the one call site (`Match.snapshot`'s `roleOverruled`, gated on `coinsOn`) passes it.

---

## 8. The `1 / 1` case, ruled on both halves

**The Builder's reading is confirmed**: a party of one cannot honour `BEATER`, because
`docs/design/bots.md` fills both sides with rigs but states twice that no bot shoots (§1.3 *"They do
not shoot"*; §2 *"No bot shoots, and no bot is protected by the safety rule"*), so a solo beater is a
drive in which nothing can be shot.

**The SERVER half needs no guard at all, and that is the ruling.** `Match.CONFIG.ODD_PLAYER_TEAM` is
`"Shooters"`, so `Roster.shooterSlots(1, config) = ceil(1/2) = 1` and `driverSlots = 0`: step 2 of
§7.1 honours nobody, he is a hunter, and nothing is consumed — `Roster` is pure and writes no wish.
**Target 3 is arithmetic, not a branch.** At two players `driverSlots = 1`, so one wisher is honoured
and the other man gets the gun, which is the honest reading of Karen's sentence.

**The CLIENT half: the pad shows `NO BEATERS THIS DRIVE` only when this client's own `sent == 1`.**
Stated plainly, as the BRIEF asks: **the caption is never shown before a size is pressed.** The
client cannot know the party size — `src/shared/Lobby/init.luau` records that `DHPadSize` and
`DHPadCount` were *"considered and refused"* — and `PadPanel.sent` is the only size fact this client
holds. Before a press the control is **available**.

**The gap that leaves, named rather than discovered:** a pad that TIMES OUT takes
`Pads.defaultSize(cfg)` = 1 without this client pressing anything, so a wisher whose party defaulted
to one sees no caption and his wish is silently not honoured. Publishing the pad's size would mean
reviving an attribute that was already considered and refused, so it is queued for the Director
(§20) rather than invented here. The outcome is the item's own blurb — *"unless the teams cannot be
made even"* — and he keeps the hunter's place, which is the side he paid for.

---

## 9. The shop row's hit test, and the Z discipline

The spec's arrangement is confirmed against this repo's bands:

* a well row is a `TextButton` at `ZIndex = Z + 2` (`buildWell`), and its children — name, price
  coin, price, tag chip — sit at `Z + 3`;
* the panel already uses `Z + 4` (`buildHeader`'s wallet value, caption and disc; `buildButton`'s
  word, divider, coin and amount) and `Z + 6` (the two well fade masks), so **`Z + 4` is inside the
  band this panel already occupies** and is above every child of the row;
* the fade masks are `Active = false` *"so a press over the top row still reaches the row"* — the
  halves are the opposite case and must be pressable, which `Z + 4` over `Z + 3` gives;
* `Rail.CONFIG.Z_INDEX` is 16 and `Shop.CONFIG.PANEL.Z_INDEX` is 15, and the rail's "stays
  pressable" claim is about the panel's own background. The panel's children already exceed 16 and
  the rail is hidden on a narrow screen (`ShopPanel.hidesRail`), so `Z + 4` changes nothing about it.

**Pressing a half also calls `ShopPanel.select(id)`**, as the spec fixes, and the order is: select,
then ask. `select` is a no-op when the row is already selected (`if id == nil or selected == id then
return`), so a second press on the same row costs one message and no redraw.

---

## 10. Every symbol added or changed, by name and signature, per file

### 10.1 `src/shared/Lobby/init.luau` — frozen data, no run-time writer

```luau
Lobby.ROLE_REQUEST_REMOTE = "RoleRequest"      -- beside PAD_REQUEST_REMOTE
Lobby.ROLE_WISH_ATTRIBUTE = "DHRoleWish"       -- on the PLAYER, beside DHPadMine
Lobby.ROLE_WISH = table.freeze({ HUNTER = "hunter", BEATER = "beater" })

-- PURE. Is this a word this system knows? The whitelist the door and both panels ask, so
-- "which words are legal" has one answer (`Pads.sizeAllowed`'s rule).
function Lobby.roleAllowed(wish: any): boolean

-- `Lobby.remotes()` gains `RoleRequest`, found by the same `WaitForChild`.
```

New rows in `Lobby.CONFIG.PADS.PANEL`, words first (*"words are Karen's to rewrite"*):

```luau
SWITCH = {
    -- The block's own words. The four captions are the Designer's, verbatim.
    TITLE = "NEXT DRIVE",
    HUNTER = "HUNTER",
    BEATER = "BEATER",
    CAPTION_HUNTING = "A STAND ON THE LINE",
    CAPTION_BEATING = "WALKING THE DRIVE",
    CAPTION_SOLO = "NO BEATERS THIS DRIVE",
    CAPTION_ASKED = "ASKED FOR ALREADY",
    -- THE BLOCK IS 119 px TALL, AND THAT SUM IS THE SPEC'S (section 3). The inner pixels below
    -- are the spec's table and `PadPanel.layoutFor` is the one thing that turns them into
    -- rectangles -- `heightFor(count, true) - heightFor(count, false) == BLOCK_PX` is what the
    -- client spec asserts, so the parts cannot drift from the whole.
    BLOCK_PX = 119,
    …the spec's internal rows (title band, the two halves' height, the caption band, the gaps)…
    TWEEN_SECONDS = 0.12,   -- design-system 1.4: colour only, nothing slides
}
```

### 10.2 `src/server/Lobby/init.luau` — the owner

```luau
-- THE ONE WRITER. Private; `onRoleRequest` and the scan are its only callers.
local function setRoleWish(player: any, wish: string?)

-- PURE and exported (§6).
function Lobby.wishFor(stored: string?, owns: boolean, assigned: string?): string?

-- THE DOOR (§4). PUBLIC, so a spec drives it by parameter with no remote.
function Lobby.onRoleRequest(player: any, request: any, now: number?): any

-- ITS OWN BUCKET, `PADS.REQUEST_MIN_INTERVAL`'s number (§4). PUBLIC, `padRateLimited`'s shape.
function Lobby.roleRateLimited(userId: number, now: number): boolean

-- WHO HAS ASKED TO BEAT, as a FROZEN MEMO: userId -> true. The `Economy.alwaysHunters` idiom
-- exactly -- rebuilt and never mutated by the one writer, so a reader still holding the previous
-- table holds a correct snapshot of the moment it asked. EMPTY when nobody owns the item, which
-- is what makes `Roster.assign` answer BY IDENTITY (§12).
function Lobby.beaterWishes(): { [number]: boolean }

-- WHO OWNS THE HUNTER'S PLACE, injected at the composition root AFTER `Shop.start`.
-- `ForestTest.setSeatProvider`'s shape and its reason: `Lobby.start` runs before `Shop.start`, so
-- an ownership read cannot be a `start` field. nil provider = nobody owns anything = today's game.
function Lobby.setAlwaysHunters(reader: (() -> { [number]: boolean })?)
```

`Lobby.start`'s world gains **one optional seam** and no required one:

```luau
assignedTeam: ((userId: number) -> string?)?,   -- `Match.assignmentOf`. nil = no drive, so nothing is ever spent
```

It is **optional and not in the six-name required list**, for the reason `depart` and `remotes` are
not in it: a world that injects nothing gets a lobby that still works, and the one thing it loses —
the reset — is unreachable in a world with no drive. `lobby.spec` drives it with a fake.

`Lobby.step` reads the ownership memo **once per scan** and hands it to `stepPlayer`, exactly as it
reads `Workspace:GetServerTimeNow()` once per scan *"so every member of one party is handed the same
deadline"*.

`Lobby.stats` gains `roleAsks`, `roleWrites`, `roleRateLimited`; `refusedBy` gains the two reasons.
`Lobby.forget` drops two rows. `Lobby.stop` clears two tables and hands back one more attribute.
`Lobby.start` clears two more tables.

### 10.3 `src/server/Match/Roster.luau` — PURE

```luau
-- PURE. A one-drive BEATER wish written over the team he WANTS. `wishes` nil or EMPTY -> `owed`
-- returned BY IDENTITY. It is the mirror of `Roster.owedWith` and is applied AFTER it, so the
-- wish beats the privilege and the privilege beats the stored turn.
function Roster.wishedWith(owed: { [number]: TeamName }?, wishes: { [number]: boolean }?): { [number]: TeamName }?

-- CHANGED: a fifth argument (§7). nil or empty is today's function, line for line.
function Roster.assign(userIds: { number }, previous: Assignment?, config, always: { [number]: boolean }?, beaters: { [number]: boolean }?): Assignment

-- CHANGED: a third argument (§7). A man who ASKED to beat was not overruled.
function Roster.overruled(assignment: Assignment, always: { [number]: boolean }?, wishes: { [number]: boolean }?): { number }
```

`Roster.previousFrom`, `other`, `invert`, `joinTeam`, `owedWith`, `counts`, `smallerTeam`,
`shooterSlots` and `yieldOrder` are **not touched**.

### 10.4 `src/server/Match/Phase.luau` — PURE, one event field, two readers

```luau
export type Event = {
    …
    -- WHO HAS ASKED TO BEAT THIS ONE DRIVE (task 229). Same shape, same discipline and same reason
    -- as `owed` and `alwaysShooters`: filled by the owner on EVERY event off a FROZEN memo, read
    -- here, never stored in the state. Absent or empty is the game before this task, BY IDENTITY.
    -- IT IS KEPT APART FROM `alwaysShooters` ON PURPOSE: `Roster.overruled` has to be able to tell
    -- a privilege the balance BEAT from one its owner GAVE UP.
    beaterWishes: { [number]: boolean }?,
}
```

* `enterAssigning(state, effects, now, config, owed, always, wishes)` → `Roster.assign(userIds,
  previous, config, always, wishes)`;
* the `join` branch → `Roster.wishedWith(Roster.owedWith(event.owed, event.alwaysShooters),
  event.beaterWishes)`, then `Roster.joinTeam` unchanged. A mid-drive joiner's wish is therefore
  honoured **only on a tie**, which is `joinTeam`'s own unchanged rule and task 217's named
  weakening, not a new one.

`Phase.State` gains no field, `Phase.Effect` no kind, `freezeState` is unchanged.

### 10.5 `src/server/Match/init.luau` — one fill, one argument

```luau
-- WHO HAS ASKED TO BEAT (task 229), beside the turn and the bought place and for the identical
-- reasons: one read of a memoised FROZEN table, no clone, no freeze, on EVERY event because an
-- assignment can happen on a join as well as on a tick.
if filled.beaterWishes == nil and world and world.roleWishes then
    filled.beaterWishes = world.roleWishes()
end
```

`Match.start`'s world gains `roleWishes: (() -> { [number]: boolean })?` — a **bare injected
function**, not a view, because there is exactly one thing to read and nothing to write
(`world.placement` / `world.groundAt` / `world.standArea`'s shape). `Match` requires no lobby and
learns only a function, which is `Match.isParticipant`'s own stated arrangement (*"the world
provides; the owner decides"*).

`Match.snapshot`'s `roleOverruled` passes the same table to `Roster.overruled`. **No new snapshot
field, no new remote, nothing new drawn by the Hud's start card.**

### 10.6 `src/shared/Shop/init.luau` — words and pixels, no rule

```luau
Shop.CONFIG.PANEL.ROW_SWITCH_PX = 124      -- the owned ALWAYS HUNTER row in WIDE, instead of ROW_PX 64
Shop.CONFIG.PANEL.DETAIL_SWITCH_PX = 70    -- the detail pane's status block in TALL
Shop.CONFIG.TEXT.ROLE_TITLE / ROLE_HUNTER / ROLE_BEATER
Shop.CONFIG.TEXT.ROLE_HUNTING / ROLE_BEATING / ROLE_SOLO / ROLE_ASKED   -- the four captions
```

`Shop.ROWS`, `Shop.BUNDLES`, `Shop.rowsFor`, `Shop.refuse`, `Shop.KIND`, `Shop.checkRequest`,
`Shop.rowsOk` and `Shop.grantsAlwaysHunter` are **not touched**. No new wire field on `WireRow` or
`State`: the switch is not on the shop's wire at all.

### 10.7 `src/client/Hud/PadPanel.luau`

```luau
-- PURE. EVERY RECTANGLE IN THIS DIALOG, from the data plus two facts. `ShopPanel.layoutFor`'s rule
-- (task 165: "asserted ARITHMETICALLY rather than by a screenshot").
export type Layout = {
    width: number, height: number,
    switchShown: boolean, switchY: number, switchHeight: number,
    halfWidth: number, captionY: number,
    rowY: { number }, hintY: number,
}
function PadPanel.layoutFor(count: number?, wish: string?, screenHeight: number?): Layout

-- CHANGED: the second argument. `heightFor(count, nil)` is today's number, so every existing
-- caller is unchanged by construction.
function PadPanel.heightFor(count: number?, withSwitch: boolean?): number

-- PURE. Is there room for the block on this screen (§14.2)?
function PadPanel.switchFitsIn(screenHeight: number?): boolean

-- PURE. THE BOTTOM EDGE NEVER MOVES (§14.1): AnchorPoint (0.5, 1) and a position fixed off
-- today's height, so the block grows UPWARD.
function PadPanel.anchorPoint(): Vector2
function PadPanel.positionFor(): UDim2

-- PURE. WHY THE SWITCH CANNOT BE USED, or "" when it can. ONE function, four rows, no literals.
function PadPanel.roleCaptionFor(wish: string?, team: string?, sent: number?): string

-- PURE. WHICH HALF IS LIT. nil wish -> no block at all.
function PadPanel.roleSelected(wish: string?): string?

-- TOLD, edge-triggered on both arguments, and it calls `relayout` when either moves.
function PadPanel.setRoleWish(wish: string?, screenHeight: number?)

-- THE ONE WRITER OF EVERY RECTANGLE IN THIS DIALOG, from `layoutFor` (new; `ShopPanel.relayout`'s
-- arrangement). `build` writes no position any more.
function PadPanel.relayout()

-- THE ONE CLIENT SENDER (§4.1).
function PadPanel.sendRoleWish(wish: string): boolean

-- for the specs, beside `titleText` / `rowText` / `rowNote`
function PadPanel.switchText(): { string }
function PadPanel.roleWish(): string?
```

`stats` gains `roleSent`, `roleBlocked`, `relayouts`. `PadPanel.press`, `setAsk`, `setLeaving`,
`render`, `renderLeaving` and the banner are otherwise untouched.

### 10.8 `src/client/Hud/ShopPanel.luau`

```luau
-- PURE. WHERE THE SWITCH GOES: "row" in WIDE (the item has a row), "detail" in TALL (it has no row,
-- so it rides the selected item's status block), "none" when he does not own it. ONE rule, so
-- "never both" is a function and not a convention.
function ShopPanel.switchSurfaceFor(mode: string, wish: string?, selectedId: string?): string

-- CHANGED: a third argument. `layoutFor(w, h)` is today's answer, so `Hud.build` is unchanged.
-- Three new fields: switchSurface, switchRowHeight, switchDetailHeight.
function ShopPanel.layoutFor(screenWidth: number, screenHeight: number, switch: boolean?): Layout

-- PURE, the shop's own four rows.
function ShopPanel.roleCaptionFor(wish: string?, team: string?): string

-- TOLD, edge-triggered; calls `relayout` on a change, because the row's height is a rectangle and
-- `relayout` is this panel's ONE writer of every rectangle.
function ShopPanel.setRoleWish(wish: string?)

-- for the specs
function ShopPanel.roleWish(): string?
function ShopPanel.switchText(): { string }
```

`buildWell` builds the two halves **once**, inside the `ALWAYS HUNTER` row, at `ZIndex = Z + 4`,
`Visible = false`; `buildDetail` builds the detail block once; `relayout` places and shows them;
`render` paints the lit half (`0.12 s` Quad Out on `BackgroundColor3` / `TextColor3`, nothing else).
A half's `Activated` closes over its word and the row's id and calls `ShopPanel.select(id)` then
`roleAsk(word)`.

### 10.9 `src/client/Hud/init.luau`

One attribute read and two tells in `renderObjective` (§5); `roleAsk` in `ShopPanel.start`'s
collaborator bag; `Hud.build` keeps seeding `padDialog`'s rectangle from `PadPanel`'s own pure
functions (`anchorPoint`, `positionFor`, `heightFor()`), which is the arrangement the shop already
has — `Hud.build` sets `shop.Size = ShopPanel.panelSize()` and `ShopPanel.relayout` rewrites it.

### 10.10 `src/server/ForestTestBoot.server.luau` — the composition root

Inside the existing `if shopOn then` block, beside `ForestTest.setSeatProvider`:

```luau
Lobby.setAlwaysHunters(Economy.alwaysHunters)
```

and in `Lobby.start`'s table `assignedTeam = Match.assignmentOf`, and in `Match.start`'s table
`roleWishes = Lobby.beaterWishes`. Neither owner requires the other; this root hands each one what
the other answers.

**`Economy.alwaysHunters` and not `Economy.ownedOf`**, and the reason is measured in that file:
`ownedOf` does `table.freeze(table.clone(set))` **per call**, so one call per player per scan would
be ~160 clones a second at 16 players; `alwaysHunters` is the frozen memo *"rebuilt and never
mutated"*, so the scan costs one table read and sixteen row lookups. That is research-note target 9.

### 10.11 `src/shared/Lobby/Remotes.model.json`

One more child: `{ "name": "RoleRequest", "className": "RemoteEvent" }`.

---

## 11. The owner row for `GAME_DESIGN.md`

The **lobby** row (currently *"The lobby (… and WHO HAS ASKED TO HUNT)"*) gains, in its own voice:

> **Since Task 229 it also owns WHICH ROLE A MAN HAS ASKED FOR, for one drive.** `Lobby.setRoleWish`
> is the one writer of the wish and of the `Player` attribute **`DHRoleWish`** (absent = he does not
> own `ALWAYS HUNTER`, `"hunter"` = the default, `"beater"` = he has asked to beat the next drive),
> reconciled level-triggered on the same 10 Hz scan that writes `DHPadMine` and against the drive's
> own `Match.assignmentOf` — so the wish is **spent by an assignment and by nothing else**, and a
> party that cancels keeps its wishes. `Lobby.onRoleRequest`, on
> `ReplicatedStorage.Lobby.Remotes.RoleRequest`, is its one inbound door and there is still no reply
> remote; a well-formed ask from a man who does not own the item is counted in `refusedBy`, not in
> `badRequests`. It writes **no team**: the drive is handed `Lobby.beaterWishes()`, a frozen memo
> read on every event like `Economy.alwaysHunters()`, and `Roster.assign`'s fifth argument is what
> seats a wisher on the beater side first. Whether he owns the item at all is injected after
> `Shop.start` (`Lobby.setAlwaysHunters(Economy.alwaysHunters)`), so with the shop off nothing is
> read, nothing is written and no control is built.

The **Economy** row (which already names the role a player is owed) and the **shop catalogue** row
need no change: nothing is persisted and no rule moves.

---

## 12. The flag-off / no-economy story, stated as an identity

> With the shop off, with `COINS` off, with no economy injected, or in a world with no lobby, **the
> drive's assignment is what it is today, value for value, and nothing is drawn.**

The mechanism, in five links, each of which a spec asserts:

1. **Nobody can own the row.** `Shop.ROWS[ALWAYS_HUNTER].sale` is true but `Economy.purchase` is the
   only writer of ownership and `Shop.start` *"OFF CONNECTS NOTHING AND READS NOTHING"*. So
   `ownedSets` is empty and `Economy.alwaysHunters()` is an **empty frozen table** — the honest
   flag-off story the BRIEF asks to be stated, and it is the same one `docs/design/role-rotation.md`
   §7 tells.
2. **The ownership reader is never wired.** `Lobby.setAlwaysHunters` is called inside
   `if shopOn then`, so with the shop off `owns` is false for everybody, `Lobby.wishFor` answers
   **nil**, the attribute is never written and **neither control is built**.
3. **`Lobby.beaterWishes()` is empty**, so `Match.dispatch` fills `beaterWishes` with an empty table
   (or, with no `world.roleWishes`, does not fill it at all).
4. **`Roster.assign(ids, previous, config, always, nil)` and `(…, {})` take today's path**: the
   `wishers` list is empty and `holders` is today's `holders`. The spec asserts a deep-equal against
   `Roster.assign(ids, previous, config, always)` at **every roster size 2..16**, and
   `Roster.wishedWith(owed, nil)` / `(owed, {})` return `owed` **by identity** — raw table equality,
   which is stronger than a deep compare and is the whole claim (`previousFrom`'s and `owedWith`'s
   own device).
5. **`Roster.overruled(assignment, always, nil)`** is today's function, and `Match.snapshot` still
   sends **absent** rather than an empty array when `coinsOn` is false — task 221 round 1's finding 2,
   untouched.

The DEV place, where the harness runs, has **no lobby at all** (`Lobby.anchorFor("map:v1")` is nil),
so `world.roleWishes` is unwired there and `zz_drive_boundary.spec` asserts link 3 on the production
drive.

---

## 13. Numeric targets

| # | Target | How it is checked |
|---|---|---|
| 1 | a `BEATER` wish puts the owner on the beater side at **every roster size 2..16**, and the two sides still differ by at most one | `match_roster.spec`, pure |
| 2 | no wish (nil or `{}`) answers the pre-task assignment **by identity** at every size 2..16 | `match_roster.spec`, pure, deep-equal plus raw identity for `wishedWith` |
| 3 | the wish is **not honoured for a roster of 1** and nothing is consumed | `match_roster.spec`, pure (`driverSlots == 0`) |
| 4 | after an assignment the stored wish reads `HUNTER` again **within one scan = 0.1 s** | `lobby.spec`, driven by a fake `assignedTeam` and a number for `now` |
| 5 | a non-owner's wish is **absent**, so neither control is built | `lobby.spec` + `pad_panel.spec` + `shop_panel.spec` |
| 6 | a forged `BEATER` from a non-owner changes nothing and is **counted apart** from a forged payload | `lobby.spec`: `refusedBy["not-an-owner"] == 1` and `badRequests == 0` |
| 7 | the pad dialog is **exactly 119 px taller** with the block and **exactly today's height** without it, and **its bottom edge is the same pixel in both states** | `pad_panel.spec`, pure |
| 8 | the shop's owned `ALWAYS HUNTER` row is **124 px** and **nothing above it moves**; in TALL the detail block is **70 px** and the blurb still holds **three lines** at 400 x 800 | `shop_panel.spec`, off `layoutFor` and off the built instances |
| 9 | the feature costs **no new per-frame wire**: 1 memoised table read per scan on the server, 1 cached attribute read per frame on the client, 1 write per change | `lobby.spec`: `roleWrites` does not climb with `scans`; `beaterWishes()` returns the SAME table by identity while nothing writes |
| 10 | new flag rows **0** (`Flags.MAX_FLAGS` stays 14 with 14 rows); new profile fields **0**; new spec files **0**; new `SCOPE_SPECS` keys **0**; new snapshot fields **0**; new clocks **0** | `flags.spec`, `economy_store.spec`, `tools/studio_mcp.py selftest`, `match_client.spec` |
| 11 | new remotes **1** (`RoleRequest`), new `Player` attributes **1** (`DHRoleWish`), new reply remotes **0** | the model file; `lobby.spec`'s teardown case |
| 12 | the rate floor is **0.25 s per player**, in a bucket of its own | `lobby.spec`: a pick and a wish in the same 0.1 s both succeed |

---

## 14. Two geometry rulings that fall out, with the arithmetic

### 14.1 The dialog grows UPWARD: its bottom edge does not move

**This is a correction made in advance, not a preference.** `Lobby.CONFIG.PADS.LEAVING.Y_SCALE`'s own
comment carries the band task 209 round 2 measured, derived from a 368-tall centred dialog:
`0.5 + 240/H <= Y_SCALE <= 1 - 56/H`, which is [0.8334, 0.9222] at 720 and holds 0.88. With the block
the dialog is **487** tall, so a centred dialog's half-height becomes 243.5 and the lower bound
becomes `0.5 + 299.5/H` = **0.916 at 720** — above 0.88. Measured out: at 1280 x 720 the dialog's
bottom would land at 603.5 and the banner's top at 577.6, **a 26 px overlap** of the dialog's hint
band — the exact defect, in the exact place, that round 2 was spent on. (The two ARE up together:
since task 209 `PadPanel.press` raises the banner optimistically while the dialog is still open.)

**Ruling: the dialog's bottom edge is invariant.** `AnchorPoint = (0.5, 1)` and
`Position = UDim2.new(0.5, 0, 0.5, PadPanel.heightFor(#SIZES) / 2)` — the bottom sits where today's
centred dialog's bottom sits, and the block is added at the top. Then the whole of the 209 band
arithmetic holds unchanged, `Y_SCALE` **is not touched**, and the claim is pure and assertable:
`layoutFor(4, "hunter").height - layoutFor(4, nil).height == 119` **and** the two rectangles' bottom
edges are equal. Growing downward was rejected by the same arithmetic (it makes the overlap worse);
moving the banner was rejected because the band at 720 is then only 4 px wide, which is not a number
anybody should have to hold.

### 14.2 On a screen too short for it, the pad surface drops the block

At 487 px the dialog no longer fits a **landscape phone**: `docs/design/camera.md`'s sibling task 220
records 800 x 400 as *"a landscape phone, which is how phones play"*, and today's 368 already leaves
only 16 px of margin there. So:

```luau
-- PURE. The block is drawn only when the whole dialog still fits, with the banner's own margin
-- either side: screenHeight >= heightFor(count, true) + 2 * LEAVING.MARGIN_PX  (487 + 24 = 511).
function PadPanel.switchFitsIn(screenHeight: number?): boolean
```

720, 800 and 1080 pass; 400 does not. **The feature is never unreachable, and that is why the second
surface exists**: the shop panel scales (`layoutFor`'s `clamp(floor(screenH * 0.8), 300, 640)`), so a
landscape-phone owner flips his role at the counter. A nil screen height answers **false** — the
small guess, which is `ShopPanel.screenSize`'s own stated rule (*"a layout that guessed big would
overflow a phone"*).

---

## 15. How it is tested

**No new spec file**, so `SCOPE_SPECS` and `BLAST_RADIUS` are untouched (rule G, task 198). Every
changed path already maps: `src/server/Match/` → `match`, `src/server/Lobby/` and `src/shared/Lobby/`
→ `lobby`, `src/shared/Shop/` → `shop`, `src/client/Hud/` → `hud`.

### 15.1 `tests/server/match_roster.spec.luau` — PURE, no world (scope `match`)

Targets 1, 2, 3, and the `overruled` correction:

* `wishedWith(owed, nil)` and `(owed, {})` return `owed` **by identity**; `wishedWith(nil, {[7]=true})`
  is `{ [7] = "Drivers" }`; neither input is written (both may be frozen).
* for every size 2..16: `assign(ids, prev, config, always, nil)` **deep-equals**
  `assign(ids, prev, config, always)`; and the existing sweep is **unedited**.
* for every size 2..16 with one wisher who also owns the place: his team is `Drivers`, and
  `|Drivers − Shooters| <= 1`.
* with **two** wishers at size 2 (`driverSlots == 1`): one is honoured, the other is a hunter, and
  the sides still differ by at most one — the overflow rule of §7.1 step 2.
* size 1: the wisher is `Shooters`.
* `overruled(assignment, always, wishes)` never names a wisher; `overruled(a, always, nil)` is
  today's answer.

### 15.2 `tests/server/match_phase.spec.luau` — PURE (scopes `match`, `lobby`)

* `event.beaterWishes` reaches `enterAssigning` and moves the side; absent → the file's existing
  `enterAssigning` cases are the regression.
* a mid-drive `join` in `Running`: equal sides → the wisher's `Drivers`; unequal → `smallerTeam`,
  and the wish is not consumed (nothing in `Phase` writes one).
* a `team` event (the Studio switch) still beats an opposite wish **for that drive**, so
  `docs/design/forest-drive.md`'s rule is untouched.

### 15.3 `tests/server/lobby.spec.luau` — the owner with fakes (scopes `lobby`, `match`)

* `Lobby.roleAllowed` over the two words and six bad values; `Lobby.wishFor`'s three branches.
* `onRoleRequest`: the five verdicts of §4, each with its counter, and **nothing sent back** on a
  forgery.
* the rate bucket: two asks inside 0.25 s → the second is `nil` and counted; a `pad` pick in the same
  window still succeeds (the two buckets are separate).
* the reset, driven by parameter: a wish stands while `assignedTeam` answers nil, and is `HUNTER`
  **one scan** after it answers a team; `roleWrites` rises by exactly 1 over that scan and does not
  climb with `scans` afterwards.
* a wish is **not** cleared by enrolment alone (a party that cancels keeps it).
* `beaterWishes()` is frozen, writing into it throws, two reads return the **same table by identity**
  while nothing writes, and a different one after a change.
* `forget` and `stop`: no table in the module is keyed by him, and `DHRoleWish` is nil on every
  player it wrote to — the teardown assertion every owner's spec in this repo makes.
* **off**: with no `setAlwaysHunters` reader, every ask is refused `not-an-owner` and no attribute is
  ever written.

### 15.4 `tests/client/pad_panel.spec.luau` — the live dialog (scopes `lobby`, `hud`)

* `heightFor(4, true) - heightFor(4, false) == PANEL.SWITCH.BLOCK_PX` (119), and
  `heightFor(4)` is today's 368 — **the existing case at line "the frame is the panel's own
  rectangle" must be re-stated as `heightFor()` with no switch**, which is the one edit this spec
  needs to an existing assertion.
* the two layouts' **bottom edges are equal** (§14.1), computed from `anchorPoint` and `positionFor`.
* `switchFitsIn`: true at 720/800/1080, false at 400 and at nil.
* `setRoleWish(nil)` → no block instance is visible and the rows sit at today's Y; `setRoleWish("beater")`
  → the block is visible, every row's Y and the hint's Y have moved by exactly 119, and
  `roleSelected` is `BEATER`.
* `roleCaptionFor` over its four rows and its empty case; **no string literal in the module**
  (the words come from `PANEL.SWITCH`).
* `sendRoleWish("beater")` fires once and counts; `sendRoleWish("nonsense")` sends nothing;
  with no remotes it still returns without throwing.
* the halves are pressable: their `ZIndex` is above the block's labels, and their width is half the
  block's less the padding (the arithmetic, not a screenshot).

### 15.5 `tests/client/shop_panel.spec.luau` — the panel (scopes `shop`, `hud`)

* `switchSurfaceFor` over the six combinations of mode × wish × selection: `"row"` only in WIDE,
  `"detail"` only in TALL **and** only for the selected `ALWAYS HUNTER`, `"none"` for nil wish —
  **never both**, which is one assertion over the function rather than a convention.
* `layoutFor(1280, 720, true)`: the owned row is `ROW_SWITCH_PX` (124), every other row is `ROW_PX`
  (64), and **every y above that row is identical to `layoutFor(1280, 720)`**.
* `layoutFor(400, 800, true)`: the detail block is `DETAIL_SWITCH_PX` (70), `blurbLines >= 3` still
  holds, and `caseHeight >= CASE_MIN_PX`.
* off the **built** instances: the two halves exist inside `Item_role.alwayshunter`, their `ZIndex`
  is `Z + 4` over the row's `Z + 2` and the row's children's `Z + 3`, and they are hidden when
  `setRoleWish(nil)`.
* a press on a half calls `select(id)` **and** the injected `roleAsk` exactly once each (both driven
  through a fake bag, which is how this spec already drives `press`).
* `money.spec`'s two negative assertions still hold: no new drawn string says `COINS` and none but
  `Money`'s holds a `$`.

### 15.6 `tests/server/zz_drive_boundary.spec.luau` — the real boundary (scope `match`)

One case in the shape this file already uses: on the production drive in the DEV place there is **no
lobby**, so `world.roleWishes` is unwired, `beaterWishes` never reaches the event and the assignment
is the roster's alone. *"Off is the game before this task"*, measured at the one boundary that could
break it.

### 15.7 The harness, two players, and the screenshot

* **Harness input (`tests/client/input_scenarios.txt`): none.** The two halves are `GuiButton`s and
  the harness cannot synthesise a tap or fire `Activated` (TASKS.md tasks 6–7). What the specs prove
  is the **action** — `press`/`sendRoleWish`/`select` — and not the touch. That limit goes in the
  review request, not papered over.
* **Two players: required for the PR**, because the change touches `src/server/Match/`,
  `tests/server/match_*.spec.luau` and `tests/client/match_client.spec.luau`'s scope — the explicit
  `TWO_PLAYER_PATHS` list in `tools/agents.py`. What a second player genuinely adds here is **one**
  claim: a wisher and a non-wisher on the same live roster end on **opposite** sides with the sides
  still level. Everything else — the whole roster rule at 16 sizes, the reset, the door, both
  layouts — is proved with one client or with none.
* **A screenshot is required (rule 5)** and there are two: the pad dialog with the block, at the
  player's own eye height, showing that the four size rows and the hint did not move off the bottom;
  and the shop's owned `ALWAYS HUNTER` row at 1280 x 720 showing the 124 px row with the lit half.
  The Builder must look at both. The thing a frame must show that no number can: that the block reads
  as **one choice with two halves** and not as two buttons.

---

## 16. Hazards

| # | Hazard | What closes it | What says it stayed closed |
|---|---|---|---|
| 1 | **The wish surviving a drive it should not** — the defect Karen's 2000 coins are at risk from | The level rule of §6, keyed on `assignedTeam` (the drive has given him a side), reconciled on the owner's own scan; the reconciliation only ever CLEARS, so a cleared wish cannot come back | `lobby.spec`: `HUNTER` within one scan of the assignment, and nothing re-invents it across a dismissal |
| 2 | **The reset racing the assignment the other way** — clearing before the roster has read it, which would make the feature silently do nothing | Structural: the reader is `Match.assignmentOf`, which is written by `Phase` in the same dispatch that reads the wish. `inDrive` (the earlier fact) is the DOOR's rule and never the reset's, and the design says so in both headers | `lobby.spec`: a wish with `inDrive` true and `assignedTeam` nil is NOT cleared; `match_phase.spec`: the wish moves the side it is read on |
| 3 | **A non-owner's forged ask** | Check 4 of §4, against the server's own memo, counted in `refusedBy` and not in `badRequests`; and the attribute is never written, so no control is ever built for him | `lobby.spec`, target 6 |
| 4 | **Two panels drifting apart** | Structurally impossible: ONE attribute, ONE read in `Hud.renderObjective`, two tells. `WireRow.owned` decides the row's tag and button and **nothing about the switch** | `shop_panel.spec` + `pad_panel.spec`: both panels answer `roleWish()` with the value they were told, and neither reads an attribute |
| 5 | **The `ZIndex` press reaching the row instead of the half** | `Z + 4` over the row's `Z + 2` and its children's `Z + 3`, inside the band the panel already uses up to `Z + 6`; the halves are the only new pressable thing and the fade masks stay `Active = false` | `shop_panel.spec`, off the built instances |
| 6 | **The taller dialog across the loading banner** — the exact defect task 209 round 2 measured | §14.1: the dialog's bottom edge is invariant, so the 209 band holds and `Y_SCALE` is not touched | `pad_panel.spec`: the two layouts' bottom edges are equal, and the existing *"never draws the click's banner across the size dialog"* case run at BOTH heights |
| 7 | **The block off the bottom of a landscape phone** | §14.2: `switchFitsIn`, pure, and the shop surface is the way in on a short screen | `pad_panel.spec` at four heights |
| 8 | **`Roster.overruled` telling a wisher the balance beat him** | The third argument (§7); a man who asked is never named | `match_roster.spec` |
| 9 | **The ownership read costing a clone per player per scan** | `Economy.alwaysHunters` (the frozen memo) and not `Economy.ownedOf` (which clones and freezes per call), read ONCE per scan | `lobby.spec`: `roleWrites` flat across scans; the memo's identity case in `economy.spec` is already there |
| 10 | **Five other rectangles moving silently.** The size rows' Y is `HEADER_PX + (i-1)*(ROW_PX+GAP)` and the hint's is `heightFor() - HINT_PX`, both written once in `build` — a block inserted under the header would leave all five where they were | `PadPanel.relayout` becomes the one writer of every rectangle in the dialog, from the pure `layoutFor`; `build` writes no position. That is the honest cost of this task and it is named, not hidden | `pad_panel.spec`: every row's Y and the hint's Y in both states |
| 11 | **A second writer of the shop row's height** (`render` per frame vs `relayout`) | `relayout` stays the one writer; `setRoleWish` is edge-triggered and calls it on a change. `render` paints colour and words only | `shop_panel.spec`: `stats().layouts` rises once per change, not per render |
| 12 | **The attribute is readable by every client.** A `Player` attribute replicates to all clients (the repo's own measured precedent: the Hud reads `DHPadMine` and `DHLobbyLeaveAt` off `LocalPlayer`, and `DHPadState` off a part) | **Accepted and named.** What leaks is "he owns `ALWAYS HUNTER`" and "he means to beat" — both already public: `Match.snapshot.roleOverruled` is broadcast to every client, and the start card shows everybody's role. No balance, no wallet, no profile field is on it | stated; §19 item 2 records that I did not measure the replication myself |
| 13 | **A false-PASS path: "he beat a drive" proves nothing.** A beater drive happens every other drive from the rotation alone (`SWAP_TEAMS_EACH_DRIVE`) | The only evidence of THIS feature is a **pair**: the same man, same roster, with the wish and without it, landing on opposite sides — which is why target 1 is a sweep over `Roster.assign` and not a frame of a start card | `match_roster.spec`; the live run's two drives are corroboration, labelled as such |
| 14 | **A second false-PASS path: the harness can never run the ON branch.** `test` and `test2` refuse to start while any `DHFlag_` override is set, so no harness run can have `SHOP` or `COINS` on | Every ON claim is reached **by parameter**: `Lobby.setAlwaysHunters(fake)`, `Lobby.start({ assignedTeam = fake })`, `Roster.assign(…, wishes)`, `PadPanel.setRoleWish(…)`. The production ON path's evidence is Karen's Forest Test, where `DHFlag_SHOP` and `DHFlag_COINS` are set, and it is labelled as such | §19 item 1 |

---

## 17. External sources

The three gameplay sources are the research note's (`docs/research/2026-10-21-the-role-switch.md`
§2), with its licence and maintenance findings as it recorded them on 2026-10-21. **I did not
re-check them in this read-only session** (rule 8, and §19 item 3).

### 17.1 ioquake3 — `code/game/g_cmds.c`, `SetTeam()` — **the refusal that speaks**

<https://github.com/ioquake/ioq3/blob/main/code/game/g_cmds.c> — **GPL-2.0**, active (last push
2026-10-12, not archived, per the note). This repo already borrows the same family in
`src/shared/Drive/Rank.luau` and `docs/design/role-rotation.md` §12.1.

**Adopted:** the client sends a *request*, the server is the one writer of `sess.sessionTeam`, and a
refusal **prints a sentence naming the reason** (`trap_SendServerCommand(… "cp \"Red team has too
many players.\n\"")`). Our four captions are that `cp` line; `Lobby.onRoleRequest` is that one
writer.
**Not adopted:** it applies the change immediately and **stores no pending preference at all**.
Karen asked about a drive that has not started and the control says `NEXT DRIVE`, so we need exactly
the thing ioquake3 declines to keep — a stored wish with a lifetime, which is §6.

### 17.2 Xonotic — `qcsrc/server/teamplay.qc`, `TeamBalance_CheckAllowedTeams` — **unavailability computed before the click**

<https://github.com/xonotic/xonotic-data.pk3dir/blob/master/qcsrc/server/teamplay.qc> — the GitHub
mirror declares no licence field; the gamecode is distributed under the **GPL**. Active (last push
2026-10-21, per the note). **Pattern read, no code copied**, so the licence does not reach this
repository either way.

**Adopted:** the balance entity marks a team `TEAM_NOT_ALLOWED` and the menu is **drawn from that**,
so a team you cannot join is drawn unjoinable rather than discovered by clicking. That is exactly
`PadPanel.roleCaptionFor` / `ShopPanel.roleCaptionFor`: the unavailability is a fact the control is
drawn FROM.
**Deliberately inverted:** its `Player_SetTeamIndex` / `MoveToTeam` refuse by returning false **with
no message**. Karen reads a silent no-op as broken and `docs/design/hud-clarity.md` says so in
writing, so every refusal here carries a caption row.

### 17.3 Shine (Natural Selection 2 admin mod), Vote Shuffle — **a preference the optimiser may overrule**

<https://github.com/Person8880/Shine/wiki/Vote-Random>, repo <https://github.com/Person8880/Shine> —
**no licence declared** in the repository metadata; last push 2026-02-07, not archived (per the
note). **Pattern read, no code copied.**

**Adopted:** the preference is an **input to the balancer and never a decision**, and whether it was
honoured is read off the FINAL teams. That is this repo's existing family — `Roster.previousFrom` is
*"a SUGGESTION"* and `Roster.overruled` is computed *from the assignment that was actually made* — so
the wish joins it instead of inventing a fourth rule, and §7.1's `driverSlots` cap is where the
balancer overrules it.
**Not adopted / not verified:** a web summary says Shine clears the preference at the end of a round;
the note records that the wiki text fetched does not say so and the source was not read. So *"one
drive only"* is **this repository's own rule**, from the Designer's spec §3.1 and Karen's *"maybe
sometimes"* — not borrowed.

### 17.4 Roblox Creator Docs — instance attributes

<https://create.roblox.com/docs/reference/engine/classes/Instance#SetAttribute> — **current, no
licence granted.** The one-way read-only attribute mirror is this repository's own established wire
(`ReplicatedStorage.Flags.State`, `DHPadState`, `DHPadFirst`, `DHPadMine`, `DHLobbyLeaveAt`), and
`DHRoleWish` is the fifth instance of it.
**Good:** no remote, no reply, no per-frame cost, and a client cannot write it.
**Bad, and it is hazard 12:** an attribute on a replicated instance is readable by every client, so
"one player's own business" is not what an attribute is for. A wallet goes out by `FireClient`
(`Economy.shopStateFor`'s own rule); a role does not need to.

### 17.5 Borrowed from inside this repo (rule 2 applies to internal patterns too)

* **`Lobby.setPadMine` / `clearLeaveAt`** — level-triggered reconciliation with edge writes, on the
  owner's own scan. The reset is this, once more.
* **`Lobby.Join.needsReturn`** — *"there are four ways to end up standing in the wrong place and only
  one of them is a phase change"*. The reason the reset is not a handler on `DEPART`.
* **`Economy.alwaysHunters` / `owedTeams`** — a frozen, memoised, rebuilt-never-mutated table read by
  `Match.dispatch` on every event. `Lobby.beaterWishes` is that, exactly.
* **`Lobby.onPadRequest`** — a public door, every fact measured server-side, a forgery counted apart
  from a refusal, its own decision returned, no reply remote. `onRoleRequest` is that, exactly.
* **`ForestTest.setSeatProvider`** — an ownership predicate injected at the root after `Shop.start`,
  inside `if shopOn`. `Lobby.setAlwaysHunters` is that, exactly.
* **`ShopPanel.layoutFor` / `relayout`** — one pure layout, one writer of every rectangle.
  `PadPanel.layoutFor` / `relayout` is that, newly.
* **`Rail.setWeapon`** — *"`hasWeapon` is TOLD to this module by the Hud, never read here"*. Both
  panels are told the wish.

### 17.6 Invented, with the reason rule 2 demands

Nothing about the mechanism. The **two-way segmented control with no travelling thumb** is this
project's own, and the reason is `design-system.md` §1.4 (*"A HUD that moves is a HUD you cannot read
while aiming"*): every off-the-shelf toggle slides, and here the selected half simply **is** the lit
one, 0.12 s Quad Out on colour and nothing else. `Lobby.wishFor` and `Roster.wishedWith` are ours:
three and four lines of pure Luau, and no library has them.

---

## 18. What this design deliberately leaves alone

1. **Sections 1, 2 and 4 of the shop2 spec** (task 228, merged). Untouched.
2. **Persistence of the wish.** `Economy.Store.TEMPLATE` is not touched and no profile field is
   added. A logout clears the wish by construction.
3. **A role wish for a man who does NOT own `ALWAYS HUNTER`.** A different feature; Karen did not ask
   for it. The attribute's absence is the whole gate.
4. **Bots that shoot** (TASKS.md 161a). §8 depends on them not shooting and does not change it.
5. **`Match.requestTeam` and `/beater`.** The Studio switch still wins for ITS drive and is still not
   a sticky preference; the wish is read at `enterAssigning` and the switch moves a live drive, so
   neither swallows the other. `docs/design/forest-drive.md` needs no rule change.
6. **The stored turn** (`Economy.nextTeam`, task 217). The wish is applied after it and
   `Roster.previousFrom`'s inversion — *"the one trap in this design"* — is not touched.
7. **`Flags.MAX_FLAGS`**, every flag row, and `COINS`'s default. All the Director's.
8. **The pad's size dialog's own behaviour**: the four sizes, the eight-second timeout,
   `Pads.defaultSize`, the optimistic banner, `Y_SCALE`, the truck's lights.
9. **The party size on the client.** `DHPadSize` stays refused (§8).
10. **Anything about the truck, the countdown, the gathering, the scoring, the boar, the weapon or
    the camera.**

---

## 19. What I could not verify (rule 8)

1. **Nothing here was run.** This is a read-only session: the evidence is the symbols cited,
   `.agent-evidence/` (lint and build for `afbb722`), and the committed designs and research note.
   In particular no frame was taken, and the two screenshots §15.7 asks for are the Builder's.
2. **That a `Player` attribute replicates to every client** (hazard 12). Documented behaviour and
   consistent with this repo's own use of `DHPadMine`, but I did not measure who can read it.
3. **The three gameplay sources' licences and last-push dates** are the research note's, dated
   2026-10-21. I did not re-fetch them.
4. **The Designer's spec section 3 is outside the repo and I have not read it.** The BRIEF's
   quotations of it are treated as final. Two things are therefore the spec's and not mine, and the
   Builder must take them from it verbatim: **the 119 px block's internal pixel table** (this design
   pins the SUM, the two halves' geometry needed for the hit test, and the fact that
   `PANEL.SWITCH.BLOCK_PX` is the one number both the layout and the spec assertion read), and **the
   mapping of the four captions to the four states**. §5 and §10.7 give my reading of the mapping —
   `A STAND ON THE LINE` / `WALKING THE DRIVE` off `Player.Team`, `NO BEATERS THIS DRIVE` off
   `sent == 1`, `ASKED FOR ALREADY` as the receipt line while the control stays usable — and if the
   spec says otherwise it is a one-line change inside one named pure function
   (`roleCaptionFor`), which is why it blocks nothing.
5. **Whether Karen reads a wish that was silently not honoured** (a party that defaulted to one, §8)
   **as correct.** She has not seen it.
6. **The exact replication lag of the attribute** after `onRoleRequest` writes it. The server write
   is inside the call; what a player sees is one network hop plus a frame. Not measured, and the
   Builder should print it once in the live run — task 209 measured 3.65 s for the pad's own round
   trip and that number is why §4.1 states this one is different.

---

## 20. Open decisions

**None of them blocks building.** Each is one row of data or one predicate, and this design states
the value it ships with.

### Karen (feel / design)

1. **Pressing a half does not light it until the server answers** (≤ 0.1 s + a frame, §4.1). The
   alternative is task 209's optimistic redraw, which this design refuses on principle. If it reads
   as a dead button she will say so, and the fix is a client-side "pending" tint — colour only,
   nothing new on the wire.
2. **On a landscape phone the pad dialog has no switch** (§14.2) and the shop does. She has not seen
   either on a phone.
3. **The four captions' words**, and whether `ASKED FOR ALREADY` should be a receipt (usable) or an
   unavailability (locked). Rows in two tables; hers to rewrite.
4. **A wish that cannot be honoured leaves him a hunter in silence** when the party defaulted to one
   (§8). The item's own blurb already says *"unless the teams cannot be made even"*.

### Director (scope)

1. **Should the pad publish its party SIZE** so the client can show `NO BEATERS THIS DRIVE` before a
   press, and for a party that defaulted to one (§8)? It means reviving `DHPadSize`, which
   `src/shared/Lobby/init.luau` records as *"considered and refused"*. Shipped without it.
2. **Should an unhonoured wish be told to the man**, as `Roster.overruled` tells an overruled owner?
   It would be a `Roster.unhonoured` list and one snapshot field. Shipped as nothing, because today
   the case is a hunter who kept the place he paid for.
3. **Should a mid-drive joiner's wish be honoured off a tie too** (§10.4)? It is task 217 §8.5's own
   open question, unchanged by this task and inherited by it.
4. **TASKS.md 214b** — the role ask as an input to `Roster.assign` — is now **half built**: this task
   adds exactly the per-event injected table 214b prescribes, for a wish rather than for a one-shot
   ask. Whether 214b is now closed, narrowed or still open is the Director's.

---

## 21. THE DELTA TABLE: what this design supersedes in the designs that already exist

`tools/agents.py` writes exactly `docs/design/role-switch.md` and `reviews/task-229/ARCH_RESULT.md`.
It cannot edit a second design, so **this table is the only record of these deltas** and each row is
one `TASKS.md` entry for the Builder to queue (L-071).

### `docs/design/truck-pads.md`

| § | What it says now | What it says after this task |
|---|---|---|
| **7** (the owner table) | eleven rows; the dialog's `Visible` and *"everything inside the `PadPanel` frame"* is `Hud.PadPanel`'s, and *"the `PadPanel` frame itself"* is `Hud.build`'s | three rows more: the wish and the `DHRoleWish` attribute (`ServerScriptService.Lobby`), the role rate bucket, and **the dialog's own rectangle** — `PadPanel.relayout` is now the one writer of its Size and Position, with `Hud.build` seeding them from the panel's pure functions (`ShopPanel.panelSize`'s arrangement) |
| **8.1** (outbound: two attributes, no new remote) | two pad attributes plus `DHLobbyLeaveAt` and `DHPadMine` | one more `Player` attribute, `DHRoleWish`, with the three states of §3 — and still **no reply remote** |
| **8.2** (inbound: one `RemoteEvent`) | *"one `RemoteEvent`, `Shop.onRequest`'s shape"* | **two**: `PadRequest` and `RoleRequest`, each with its own handler, its own bucket and the same shape. The sentence *"the first inbound door this system has ever had"* becomes *"the first two"* |
| **8.3 / the payload table** | `{ pad, size }` | unchanged — `onPadRequest` is **not** extended, and the design says why (§4) |
| **10.3** (the dialog) | 320 x 368, centred, four rows and a hint | a sixth rectangle between the header hairline and the rows, +119 px, **bottom edge invariant**, dropped on a screen shorter than 511 px |

### `docs/design/shop.md`

| § | What it says now | What it says after this task |
|---|---|---|
| **the panel's layout** | `ROW_PX` 64 for every row; the detail stack's eleven gaps | `ROW_SWITCH_PX` 124 for the owned `ALWAYS HUNTER` row in WIDE, `DETAIL_SWITCH_PX` 70 in the detail stack in TALL, and `ShopPanel.switchSurfaceFor` as the one rule for *"never both"* |
| **the wire** | `ShopState` is fired only in reply to a request | unchanged, and that is now **load-bearing**: it is the measured reason the switch is drawn from an attribute and not from `WireRow.owned` (§3) |
| **the door** | *"IT NEVER WRITES A LOADOUT, A POCKET, A TEAM …"* | unchanged and **upheld**: the role wish does not go through `Shop.onRequest`, and `Shop.KIND` stays two rows |
| **section 7.1** (what ownership means, nil = leave the game as it was) | eight readers of what ownership gives | a ninth: `Lobby.setAlwaysHunters`, wired inside `if shopOn`, nil = nobody owns anything = today's game |

### `docs/design/role-rotation.md`

| § | What it says now | What it says after this task |
|---|---|---|
| **2** (owners) | five rows | one more: **the one-drive role wish**, `ServerScriptService.Lobby`. The sentence *"there is exactly one place a team is written"* is untouched |
| **4.1** (`Roster`'s symbols) | seven functions; `Roster.assign` has four arguments | **eight** (`wishedWith`), `assign` has **five** and `overruled` has **three**; `previousFrom`'s inversion is untouched |
| **4.2** (`Phase.Event`) | gains `owed`; task 221 added `alwaysShooters` | one more field, `beaterWishes`, with the same discipline and the same reason, and the stated reason it is kept APART from `alwaysShooters` |
| **8.5** (a mid-drive join honours the turn only on a tie) | the turn | the same rule now also bounds the WISH, and §20 Director item 3 is the same question asked once |
| **14** (what it leaves alone) | item 2: *"TASKS.md 214b — the role ask as an INPUT to `Roster.assign` … Not built. The seam is shaped for it"* | the seam is now **used**, for a stored wish rather than a one-shot ask (§20 Director item 4) |

### `docs/design/drive.md`

| § | What it says now | What it says after this task |
|---|---|---|
| **5.2** | `Roster`'s functions and its numbered rules | a rule more: *a one-drive BEATER wish, when one is supplied, drops its owner out of the bought-place pass and takes a driver place FIRST, up to `#ids − shooterSlots`; past that it is not honoured and the privilege stands* |
| **4.2** (the `Event` type) | already stale (the printed `kind` union lacks `"team"` and `"dismiss"`) | gains `beaterWishes`; **fix the pre-existing staleness in the same edit** |
| **9.2** (`Match`'s `World`) | already stale (lacks `economy`, `bots`, `placement`, `config`, `enrol`, `groundAt`) | gains `roleWishes`; same edit |

### `docs/design/lobby.md`

| § | What it says now | What it says after this task |
|---|---|---|
| **4.5** (what this owner never writes) | *"it NEVER writes a team, a character's position, clothes or a tool"* | **unchanged and upheld**, with one sentence added: it writes a man's *request* about a team and never a team — the drive is handed a frozen boolean table and decides |
| **12.4** (the injected seams) | six required, two optional | one more optional (`assignedTeam`) and one setter (`setAlwaysHunters`), with the stated reason the latter is a setter: `Lobby.start` runs before `Shop.start` |
