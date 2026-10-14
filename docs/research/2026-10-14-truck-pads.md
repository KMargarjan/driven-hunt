# Truck pads: a coloured rectangle behind each truck, and the first player picks the party size

2026-10-14, task 182. Written before the code, per CLAUDE.md rule 1.

Karen, 2026-10-14 ~09:30, verbatim:

> and when start hunt we need to go next to truck has to be mark where and has to be coloroude
> circle like in all games or rectangle where people stand and can be 1/1 or 4/4 you can select on
> dialiog how many like in roblox games and can be several truck like 4 of them nicly aligned next
> ot each other and you come to truck back rectangle and can click and select how many players

---

## 1. What the system must do

1. **A coloured rectangle behind each of the four trucks** task 180 parked side by side -- one pad
   per truck, distinct colours, a glowing edge, readable from the porch. It replaces task 177's
   single orange circle ("STAND HERE TO HUNT") beside truck 1.
2. **The first player onto an empty pad is asked how many**, in a dialog, with big buttons that work
   under a finger as well as under a mouse. Karen's own range is *"1/1 or 4/4"*; the Director's data
   is 1, 2, 4, 8.
3. **Others join by standing on it**, and the pad shows **`n / size`** over it, with the truck's own
   number, so a player across the yard can read how full a party is before he walks over.
4. **Stepping off leaves** -- and for the first player, stepping off *cancels the pick*, which is
   task 177's own rule (`Join.decide`: *"RE-ENTRY DOES NOT INHERIT THE OLD DEADLINE"*).
5. **A countdown when the party is full, or after N seconds**, then the party goes to the drive
   through task 177's existing door (`world.enrol`, one call per member).
6. The lobby's objective line says **"Step on a truck pad to start a hunt"**, and the chevron and the
   minimap point at the **nearest** pad rather than at one fixed circle.
7. Cost nothing per frame on the server: the lobby's builder already states the rule (*"nothing here
   is animated and nothing is written per frame"*), and the pads ride the existing 10 Hz scan.

### What it must not do

* **Must not become a second writer of the roster.** `Match.enrol` / `Match.dismissAll` stay the
  drive's only two doors and `Lobby` keeps handing players through them (design `lobby.md` 4.5).
* **Must not let a client decide who hunts, or how many.** Task 177's lobby has *no inbound door at
  all*. This task needs one -- a dialog is a message from a client -- so that door must be built the
  way `Shop.onRequest` is: server-measured facts only, rate-limited, forgery-counted, and public so
  a spec can drive it by parameter.
* **Must not promise a reserved server.** `TeleportService` does not work in Studio and this repo
  tests in Studio (section 3). The seam is designed, written down and left unbuilt.
* **Must not break `smoke.sh`.** Its lobby step pivots a player into a part named `TruckSpot` and
  requires the drive to have taken him 20 s later (section 7).
* Must not put a Script, LocalScript or ModuleScript into `Workspace` (CLAUDE.md; the harness fails
  on one).

---

## 2. What Roblox games actually do, and the three things they are made of

A queue pad in a Roblox game is three separable mechanisms, and the sources split cleanly along
them: **the presence test**, **the party**, and **the destination**.

### 2a. The presence test -- Valve's `trigger_multiple`, READ AS ARITHMETIC (already adopted here)

<https://developer.valvesoftware.com/wiki/Trigger_multiple>
*Licence:* CC BY-SA (community wiki). *Maintenance:* the entity ships in every Source game.

**Well:** a trigger volume's whole value is that it knows who is **inside** it -- presence, not
contact. Half-Life's level flow is built on it.

**Badly:** nothing, for this use. `BasePart.Touched` is the trap: it fires on CONTACT, so a player
standing perfectly still generates nothing after the first touch, and `TouchEnded` cannot reliably
answer *"has he left"* -- which is the one question a pad that cancels on stepping off must ask every
tick.

**Adopted, and it is already in this repository**: `Lobby.Join.within` is this rule for a circle
(*"In Roblox the presence test is a subtraction, not an event"*), and `ForestTest.withinStand` is the
same rule for a hunter's stand. **What changes for this task is the SHAPE, not the mechanism**: Karen
asked for a *"rectangle"*, so the subtraction becomes two `math.abs` comparisons instead of one
squared distance. One new pure function beside `Join.within`, same file, same test seam.

### 2b. The party, built in the lobby -- two open-source modules, both rejected, for the same reason

**`PartyModule`** -- <https://devforum.roblox.com/t/open-source-party-module/4265635>
*Licence:* explicitly *"free to use ... in any project (personal or commercial). Credit is
appreciated but not required."* *Maintenance:* posted 2026-01-17, author active on the thread
2026-09-26, no module update since.

**Well:** exactly our vocabulary -- `CreateParty(player, isPrivate, name)`, `AddPlayer`,
`RemovePlayer`, `ChangePartyLeader`, `GetPartyFromPlayer`. Server-side only, which is the right side.

**Badly:** *"does not replicate to clients automatically"*, *"does not auto-delete empty parties"*,
no GUI, no example place. So it is a table of players with an owner field -- and it has no concept of
a PLACE in the world, which is the entire thing Karen asked for.

**`Party Service v2.1`** -- <https://devforum.roblox.com/t/party-service-v21-create-a-party-system-more-easily/1816870>
*Licence:* **unstated** (says "open-source", names a GitHub repo, no licence file quoted).
*Maintenance:* v2.1, 2022-10-17, **dead for four years**; it also phones home over `HttpService` for
update warnings.

**Well:** invite codes, configurable max per party, cross-place data via `SetAsync`, and a documented
Studio story (`SetPartyServerEmulator`).

**Badly:** the unstated licence alone disqualifies it for a public repo. Its max-50 ceiling is a
`TeleportService` constraint we are not paying, its `SetAsync` cross-place channel is a DataStore
write per party, and `HttpService` traffic from a lobby is not something this game should carry.

**Why both are rejected, in one sentence:** our party is **four fixed pads in one lobby on one
server**, and its membership is *who is standing on this rectangle right now* -- a derived fact,
re-measured at 10 Hz, that cannot drift out of step with the world. A party OBJECT with its own
lifetime would be a second answer to "who is in party 2", and two answers to one question is this
project's named failure mode (`docs/PROJECT_CONTEXT.md`). **Borrowed instead: their vocabulary**
(a pad has a party, a party has a size and a first player) and `PartyModule`'s "server-side only, no
client authority" posture.

### 2c. The pad that already exists in the wild -- **the pattern ADOPTED whole**

"Free ADVANCED lobby model for multiplayer games" --
<https://devforum.roblox.com/t/free-advanced-lobby-model-for-multiplayer-games/2272494>
*Licence:* **none stated** (free community resource). *Maintenance:* posted 2023-04-04, bug fixes
through 2024-06, and a commenter on the thread asks whether the distributed model was ever updated
with them -- so: read for the pattern, **take no code**.

**Well, and this is the find:** its lobby is a **touch pad with a configurable maximum count and a
countdown that starts when the FIRST player steps on**, with the seconds drawn over the pad in a
`BillboardGui`. That is Karen's picture minus the dialog -- which means the shape she asked for is
the shape the community converged on, and the only thing we are adding is *who decides the maximum*.

**Badly:** no size choice at all (the max is set by the developer, not by the first player), the
count display is vague in its own documentation, and the licence is unstated -- so this note takes
the **mechanism and the numbers' SHAPE** and writes its own code.

**What is adopted:** the pad is a place in the world with (i) a max, (ii) a live occupancy, (iii) a
countdown owned by the pad and not by a player, and (iv) a `BillboardGui` above it that says both.
**What is changed:** the max is the first player's pick (Karen), and the countdown is this repo's
existing `Lobby.COUNTDOWN_SECONDS` rather than a new number.

### 2d. The size dialog -- the elevator in *Doors* and the tower-defence lobbies

<https://devforum.roblox.com/t/how-do-i-make-lobby-teleport-system-like-doors-has/2428201> ·
<https://devforum.roblox.com/t/lobbyqueue-system/3909735>
*Licence:* n/a (discussion threads). *Maintenance:* n/a.

These threads are the vernacular for what Karen means by *"like in roblox games"*: you walk into an
elevator or onto a pad, a small panel asks how many players, and the lift leaves when it is full or
when the clock runs out. **Nothing is taken from them but the wording of the question and the
confirmation that the first player is the one who answers it** -- there is no code in either thread
worth borrowing, and no licence to borrow it under.

---

## 3. The destination: why the reserved-server teleport is DESIGNED AND NOT BUILT

A real Roblox pad sends its party to **its own server**, so four pads are four simultaneous hunts.
The official route is:

<https://create.roblox.com/docs/reference/engine/classes/TeleportService>
*Licence:* CC BY 4.0. *Maintenance:* first-party, current.

Read today, three facts matter:

1. **`TeleportService:ReserveServerAsync()`** returns an access code for a fresh private server, and
   **`TeleportToPrivateServer()`** sends a list of players to it. This is the pattern.
2. **`TeleportPartyAsync` is marked Deprecated**, and so is the older `ReserveServer`. So a design
   that named the deprecated call would be wrong on the day it was written.
3. The methods require the **Teleport** capability and the docs give **no statement that any of it
   works in Studio**. In practice it does not: there is no live server to reserve and no session to
   move a player into, and this repository's entire evidence chain -- `tools/studio_mcp.py test`,
   `test2`, every spec -- runs in Studio in Edit or Play. **A teleport is therefore a thing this
   project cannot test at all**, which by rule 6 ("test the player's path") and rule 8 ("report
   honestly what you could not verify") means it must not be built in the task that cannot show it
   working.

**So: one drive at a time, on this server, and the seam written down.** The pads form parties; the
party that leaves is handed to `Match.enrol` exactly as task 177's circle hands one player; and the
place where a published build would instead call `ReserveServerAsync` + `TeleportToPrivateServer` is
a single named function with one implementation today (`enrol them here`) and one more later
(`teleport them there`), behind a flag that is born OFF and whose `why` says it cannot be tested in
Studio. The Architect fixes that seam's name and shape.

**And four pads on one server are still honest**, because the drive has exactly **eight** slots --
`Match.CONFIG.BOTS.TARGET = { hunters = 4, beaters = 4 }` -- and bots fill every slot no player
takes (task 161). A pad's party of 8 therefore IS the whole hunt; a party of 1 is one man and seven
bots, which is precisely today's game. The four pads are four doors into the one hunt, and what a
pad buys you is **leaving with your friends instead of alone**.

---

## 4. The numbers and the words, and where each comes from

| Thing | Value | Where it comes from |
|---|---|---|
| Pads | 4, one behind each truck | Karen: *"can be several truck like 4 of them"*; task 180 parked four |
| Pad position | `TRUCK.PAD_BEHIND_STUDS` = 12 behind the tailgate | **already written down** in task 180's `Lobby.CONFIG.TRUCK`, *"where a man loading into the back would stand"* |
| Pad shape | rectangle | Karen: *"rectangle where people stand"* |
| Pad size | ~14 x 10 studs | the truck model is 7.0 wide; a pad must hold 8 bodies (a character is ~4 wide, ~2 deep standing) with room to step off. 14 x 10 holds two rows of four |
| Party sizes | 1, 2, 4, 8 | the Director. 8 = `TARGET.hunters` 4 + `TARGET.beaters` 4, the drive's whole roster |
| Dialog words | `1 / 1` *alone* / `2 / 2` / `4 / 4` / `8 / 8` *full hunt* | Karen wrote the format herself: *"can be 1/1 or 4/4"*. The size is the denominator, so her words ARE the buttons |
| Billboard | `n / size` plus `TRUCK 3` | Karen: *"can be 1/1 or 4/4"*; the truck number is what makes four identical pads tellable apart |
| Countdown | `COUNTDOWN_SECONDS` = 5 | **the existing number** (task 177). A second countdown length would be a second answer to "how long until I go" |
| Pick timeout | 8 s | long enough to read four buttons and press one; short enough that `smoke.sh`'s 20 s window still sees the drive take him (8 + 5 = 13). See section 7 |
| Fill timeout | 45 s | the Director's *"a countdown when full or after N seconds"*. 45 s is the longest a solo player should ever wait for friends who are not coming; it is DATA, and Karen can retune it in one row |
| Colours | green, blue, orange, violet | four hues a colour-blind player can still tell apart by POSITION (the pads are in a row, numbered); the ring's existing hunting orange stays one of them so the lobby's palette does not change |

---

## 5. The owner boundary, which is the whole risk in this task

Task 177 said it in capitals and it still holds: **`Lobby` owns the lobby's world, the rule, and the
list of who has asked -- and it never writes a team, a character, clothes or a tool.** Four things
this task adds have to land on the right side of that line:

1. **The pads themselves** -- parts in `Workspace.Lobby`, built by `Lobby.Build`, which is already
   *"the one writer of every part in `Workspace.Lobby`"*. No new owner.
2. **The pad state machine** -- `empty -> sizing -> filling -> countdown -> leaving -> empty`. It
   belongs with `Join.decide`, as a **pure** function over `(pad, occupants, now, cfg)`, for exactly
   the reason `Join` gives: *"that is what lets `lobby.spec` drive the entry, the cancel, the
   re-entry and the exact boundary second with hand-written numbers and no character at all."*
3. **The inbound door** (the size pick) -- new, and the only genuinely new mechanism in the task. It
   is `Shop.onRequest`'s shape exactly: a `RemoteEvent` the server listens on, a public handler
   reachable by parameter, the player's position measured **server-side** per request (never sent),
   a per-player rate bucket, and a `badRequests` counter apart from a refused-but-legal pick.
4. **The dialog** -- a client panel, drawn inside the one `ScreenGui` `Hud.build` already makes,
   owning its own `Visible`, drawing what arrived and deciding nothing: `ShopPanel`'s shape, with
   `GuiButton.Activated` (*"one event for a click AND a tap, which is why this panel needs no touch
   branch at all"*) and buttons big enough for a finger.

The one thing that must be re-decided rather than assumed: **task 177's five-second walk-in no longer
enrols anybody by itself.** Standing on a pad now starts a PARTY, and the party leaves. That is a
behaviour change to a path Karen has played, and it is the reason the objective line's wording
changes with it.

---

## 6. What replaces the `TruckSpot` circle, and what keeps its name

`Lobby.SPOT_NAME = "TruckSpot"` is read by four things: `Lobby.spotPart`, `Lobby.spotPosition`, the
Hud's chevron through `Objective.targetFor` (`kind = "truck"`), and -- outside the repo --
`smoke.sh`'s `lobby-go.luau`.

**Decision: pad 1 keeps a part named `TruckSpot`.** It is the pad's own named marker, the same
invisible unqueryable slab the circle has today, just rectangular and behind truck 1. Nothing above
has to change its reader, `smoke.sh` keeps working without an edit, and `Lobby.spotPosition()`
keeps meaning *"the first place you can start a hunt"*. The chevron then gains a **nearest-pad**
reader beside it (`Lobby.padPositions()`), because pointing at pad 1 when a player is standing by
truck 4 would be the chevron lying about where to go.

---

## 7. `smoke.sh`, and the one number that keeps it honest

`smoke.sh` pivots the first player onto `TruckSpot` and sleeps 20 s, then requires a gun in hand --
i.e. it requires **the drive to have taken him** inside 20 s. It runs its snippet on the live server
through StudioMCP, and a snippet that `require`s the server's `Lobby` gets a **sandboxed copy with
empty state** (measured, task 122), so it **cannot** call the size-pick handler. There is no click
either: the dialog is a client panel.

So the pad must reach the drive **with no pick at all**, and the honest way to do that is a rule that
is good game design on its own:

> **A pick that is never made defaults to `1` after `PICK_TIMEOUT_SECONDS`.**

A player who walks onto a pad and ignores the dialog goes hunting **alone** -- which is exactly task
177's behaviour and exactly what the drive's bots are for. The dialog is therefore a choice to
**wait for friends**, not a gate you must pass to play, and that is the kinder reading of it anyway:
Karen's *"1/1"* is the default, and *"4/4"* is the thing you opt into.

`8 + 5 = 13 s` from standing on the pad to leaving, inside `smoke.sh`'s 20 s. **No change to
`smoke.sh` is needed**, and `lobby_live.spec` can assert the same path in the harness.

---

## 8. The pattern adopted, in one paragraph

**The pad is the community's lobby pad** (section 2c): a place in the world with a max, a live
occupancy, a countdown of its own and a `BillboardGui` saying both. **Its presence test is Valve's
`trigger_multiple` read as arithmetic** (2a), already this repo's own idiom, widened from a circle to
a rectangle. **Its party is derived, never stored** -- who is standing here now -- which is why both
open-source party modules are rejected (2b) and only their vocabulary is kept. **Its size is the
first player's pick**, through an inbound door shaped exactly like `Shop.onRequest` (5.3) and a
dialog shaped exactly like `ShopPanel` (5.4). **Its destination is `Match.enrol`**, with
`ReserveServerAsync` + `TeleportToPrivateServer` named as the published-game seam and left unbuilt,
because Studio cannot test a teleport (3). **Nothing invented**: every number is either Karen's
words, a number already in `Lobby.CONFIG`, or a measurement written in the table in section 4.

---

## 9. What this note could not establish

* **That the reserved-server path works at all.** It is not testable in Studio and was not tested.
  The design records the call names and the shape; the first build of it will need a published place
  and Karen's eyes, and that is a task of its own.
* **Whether 45 s is the right fill timeout.** It is a first value. Karen retunes it in one row.
* **Whether four pads on one server reads as four hunts to a player.** It does not, and the note says
  so plainly (section 3): it reads as four doors into one hunt. Only Karen can say whether that is
  disappointing enough to be worth a published-place teleport before v1.
