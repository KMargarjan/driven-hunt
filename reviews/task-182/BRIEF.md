# Task 182 BRIEF: four trucks, a coloured pad behind each, and the first player picks how many

Input to `tools/architect.sh design truck-pads --task 182`. Read this first; it overrides anything
older in `docs/`, `TASKS.md` or an earlier design (`docs/ARCHITECT_PROMPT.md`), **including
`docs/design/lobby.md` sections 6, 10.3 and 14.3**, which this task supersedes where they disagree.

Research note: `docs/research/2026-10-14-truck-pads.md`. It is the reasoning; this is the decision
list.

---

## 0. What the task is

**Karen, 2026-10-14 ~09:30, verbatim:**

> and when start hunt we need to go next to truck has to be mark where and has to be coloroude
> circle like in all games or rectangle where people stand and can be 1/1 or 4/4 you can select on
> dialiog how many like in roblox games and can be several truck like 4 of them nicly aligned next
> ot each other and you come to truck back rectangle and can click and select how many players

Task 180 already parked **four trucks side by side** and already wrote down where this task's pads go
(`Lobby.CONFIG.TRUCK.PAD_BEHIND_STUDS = 12`, *"where a man loading into the back would stand"*). Task
177 built the single orange circle beside truck 1 that this task **replaces**.

**Karen judges the look in the morning.** Where a choice was open, the Director's standing
instruction is *"pick the simpler, Karen judges"*. Two screenshots are owed: the four trucks with
their pads, and the size dialog.

**Time box 3.5 h.** The design must be buildable inside it. Prefer the smaller honest thing.

---

## 1. Decisions already taken. The design does not re-open these.

**(a) ONE DRIVE AT A TIME, ON THIS SERVER. NO TELEPORT IS BUILT.**
`TeleportService:ReserveServerAsync` + `TeleportToPrivateServer` is the real-game route (and
`TeleportPartyAsync` and `ReserveServer` are both **deprecated** -- note section 3). **None of it
works in Studio**, which is this repository's entire evidence chain. So v1 is: a pad's party is
handed to the drive through **task 177's existing door**, `world.enrol`, one call per member. The
reserved-server path is a **named seam, designed and left unbuilt**, behind a flag born OFF per
CLAUDE.md's feature-flag section, with a `why` that says Studio cannot test it. The Architect fixes
the seam's name and shape; it writes no teleport code.

**(b) FOUR PADS ARE FOUR DOORS INTO ONE HUNT, AND THE DESIGN SAYS SO IN WORDS.** The drive has eight
slots (`Match.CONFIG.BOTS.TARGET = { hunters = 4, beaters = 4 }`) and bots fill every slot no player
takes (task 161). A party of 8 **is** the whole hunt; a party of 1 is one man and seven bots, which
is today's game exactly. What a pad buys a player is **leaving with his friends instead of alone**.
A pad is therefore **not blocked** while a drive runs: the drive already supports a mid-drive join
(`Match.enrol` dispatches `join` in any phase), so a pad that fills during `Running` enrols its party
into the running hunt, which is what task 177's circle already does for one player. **If the
Architect prefers "HUNT IN PROGRESS, pads inert" it must say why losing the mid-drive join is worth
it** -- the Director's default is: keep the join.

**(c) THE PAD'S PARTY IS DERIVED, NEVER STORED.** Membership is *who is standing on this rectangle
right now*, re-measured on the lobby's existing 10 Hz scan. A party object with its own lifetime
would be a second answer to "who is in party 2" -- this project's named failure mode. Both
open-source party modules are rejected for that reason (note 2b); their vocabulary is borrowed.

**(d) PRESENCE IS ARITHMETIC, NOT `Touched`.** `Lobby.Join.within` is already Valve's
`trigger_multiple` read as a subtraction, and the pads use the same mechanism widened to a
**rectangle** (Karen's word): one new pure predicate beside `within`, in `Join`, pure, no Instance.
`BasePart.Touched` is refused for the reason `Join`'s own header gives.

**(e) `Lobby` STAYS THE OWNER AND GAINS NO NEW ONE.** It owns the pads (parts in `Workspace.Lobby`,
built by `Lobby.Build`, *"the one writer of every part in Workspace.Lobby"*), the pad state machine
(pure, in `Join` or a sibling module), and the inbound door. It still **never** writes a team, a
character's position, clothes, a tool or a roster entry. `Match.enrol` / `Match.dismissAll` stay the
drive's only two doors.

**(f) THE INBOUND DOOR IS `Shop.onRequest`'S SHAPE, AND THAT IS THE ONE GENUINELY NEW MECHANISM.**
Task 177's lobby has *no inbound door at all*; a dialog is a message from a client, so one is needed.
Non-negotiable properties, all of them already true of `src/server/Shop/init.luau`:
* a `RemoteEvent` in `ReplicatedStorage` (a `.model.json` folder, like `Shop/Remotes.model.json`);
* a **public** handler reachable **by parameter** as well as by remote, so specs drive it with no
  remote at all (`OnServerEvent` can only be raised by a client -- task 80);
* **every fact measured server-side**: which pad he is on comes from the character the server can
  see, never from the payload. The payload carries at most `{ pad = n, size = k }` and both are
  validated against the data table;
* a **per-player rate bucket**, and `badRequests` (a forged payload) counted **apart from** a
  legal-but-refused pick (`Weapon.stats`' own split);
* **only the first player on the pad may pick**, measured server-side; a pick from anyone else is
  refused, not applied.

**(g) THE DIALOG IS `ShopPanel`'S SHAPE.** A frame inside the one `ScreenGui` `Hud.build` already
makes; it owns its own `Visible`; it draws what arrived and decides nothing; `GuiButton.Activated`
(one event for a click **and** a tap, so there is no touch branch); buttons big enough for a finger.
It closes when he steps off the pad, which is the server's own cancel read on the client.

**(h) A PICK THAT IS NEVER MADE DEFAULTS TO `1` AFTER `PICK_TIMEOUT_SECONDS`, AND THIS IS LOAD-BEARING
FOR THE EVIDENCE.** `smoke.sh` pivots player 1 onto `TruckSpot` and requires the drive to have taken
him 20 s later; its snippet runs on the live server through StudioMCP, where a `require` of the
server's `Lobby` gets a **sandboxed copy with empty state** (measured, task 122), so it can neither
call the handler nor press a button. With this default the whole path works unattended:
`PICK_TIMEOUT 8 + COUNTDOWN 5 = 13 s`, inside the 20 s window. It is also the kinder rule -- the
dialog is a choice to **wait for friends**, not a gate you must pass to play.

**(i) PAD 1 KEEPS A PART NAMED `TruckSpot`.** It is pad 1's own invisible, unqueryable marker slab
(rectangular now, behind truck 1 instead of beside it). `Lobby.SPOT_NAME`, `Lobby.spotPart`,
`Lobby.spotPosition`, `Objective.targetFor`'s `kind = "truck"` and `smoke.sh` all keep working with
no edit. **No change to `smoke.sh` is requested.**

**(j) THE CHEVRON AND THE MINIMAP POINT AT THE NEAREST PAD**, not at pad 1. A new reader beside
`spotPart` (`Lobby.padPart(n)` / `Lobby.padPositions()`), and the nearest-of-a-set choice is
`Objective.nearestStand`'s existing rule, reused rather than reinvented.

**(k) EVERY NUMBER AND EVERY WORD IS DATA IN `Lobby.CONFIG`**, in the `PADS` block, the way `SPOT`,
`TRUCK` and `TROPHIES` already are; `Shotgun.deepFreeze` keeps covering it. Nothing numeric in
`Build`, `Join` or the panel.

---

## 2. The data the design must fix (first values; Karen retunes rows)

| Row | First value | Note |
|---|---|---|
| Party sizes | `{ 1, 2, 4, 8 }` | the Director. 8 = the drive's whole roster |
| Dialog labels | `1 / 1` "alone", `2 / 2`, `4 / 4`, `8 / 8` "full hunt" | Karen wrote the `n / n` format herself |
| Billboard | `n / size` and `TRUCK 3` | the truck number is what tells four pads apart |
| Pad size | ~14 x 10 studs | must hold 8 bodies; see note section 4 |
| Pad offset | `TRUCK.PAD_BEHIND_STUDS` = 12 behind the tailgate | **already written down**, task 180 |
| `COUNTDOWN_SECONDS` | 5, **unchanged** | one answer to "how long until I go" |
| `PICK_TIMEOUT_SECONDS` | 8 | decision (h) |
| `FILL_TIMEOUT_SECONDS` | 45 | the longest a solo player waits for friends |
| Colours | green, blue, orange, violet | distinguishable, and the ring's hunting orange stays in the palette |

---

## 3. What the design MUST contain

1. **The state machine, as a table of states and transitions**: `empty -> sizing -> filling ->
   countdown -> leaving -> empty`, with every trigger named (first player on, pick, pick timeout,
   join, leave, last man off, full, fill timeout, countdown elapsed) and **what happens at each
   boundary**. Say explicitly what the first player stepping off does in `sizing` and in `filling`,
   and what the *last* man stepping off does in `countdown`.
2. **The owner table**: who writes the pad parts, the billboard text, the `Visible` of the dialog,
   the enrolment, and the `DHLobbyLeaveAt` attribute (which task 177 already owns) -- one writer
   each, named.
3. **The wire**: the remote's name and payload shape, what the server sends back (or whether the pad
   state reaches the client through attributes / a replicated value instead of a remote -- task 177
   deliberately used **one attribute per player and no remote at all**, and if the pad state can
   reach the client the same way, say so and prefer it: a pad's state is public, not per-player).
4. **The published-game seam** for `ReserveServerAsync` + `TeleportToPrivateServer`: the function's
   name, its signature, its two implementations, the flag row, and the one sentence saying it cannot
   be tested in Studio.
5. **What `docs/design/lobby.md` sections this supersedes**, and the exact replacement wording for
   section 6 (the join rule) and 10.3 (`TruckSpot`).
6. **The spec list**: the state machine's states and every transition, the first-player-picks rule,
   join/leave, the party reaching the drive, a forged pick, a pick from a non-first player, and the
   pick-timeout default. All driveable with hand-written numbers and no character (`Join`'s rule).
7. **Open decisions, if any**, listed as blocking so the Builder escalates rather than guesses.

## 4. What the design must NOT do

* Must not add a second clock. The lobby's 10 Hz scan off the boot's one `Heartbeat` is the clock
  (`docs/design/lobby.md` open decision 2).
* Must not make a pad write anything per frame. The billboard changes on an edge, like
  `setRespawn` and `clearLeaveAt` already do.
* Must not require the DEV place to have a lobby. `Lobby.ANCHORS` has one row (`forest-test`); the
  DEV place builds nothing and every spec builds into a folder of its own.
* Must not put a Script, LocalScript or ModuleScript into `Workspace`.
* Must not design the car RIDE. Karen's doc has one (*"you sit in car and drive to position"*); it is
  a later task and the design may mention it only as the seam the pad's `leaving` state would feed.
