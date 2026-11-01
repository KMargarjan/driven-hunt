# Research: stand pick -- the hunter takes his own stand before the drive

Task 323 (323a built from it) · 2026-11-01 · Builder.
Design: `docs/design/stand-pick.md` (Architect, PASS). Brief: `reviews/task-323/BRIEF.md`.

Karen, 2026-10-31 ~21:00: *"...choose shooting place on map before hunt"*.

## 1. What the system must do

1. A **hunter** gets a window at the start of each drive in which he takes one of that drive place's
   numbered stands (D1, D2). The window is one CONFIG number, first value 15 s.
2. The **server** decides: first request wins; a taken stand cannot be taken; he may change his pick
   to another free stand until the window closes; a stand freed by a change or a leave is free at
   once (D4).
3. Everybody is told **one snapshot** of the whole claim table -- free, taken and by whom, his own,
   and which stands carry a high seat (D3).
4. A hunter who picks nothing is placed by today's rule, so **a drive never waits on a player** (D5).
5. **Bots never take a stand a human could still pick** (D6).
6. Picking changes WHO stands on a stand, never WHERE stands are: the line, the safety arcs and the
   penalty are untouched (D7).
7. With the flag OFF it is **today's placement bit for bit** (D8).

## 2. Sources

The design's section 11 is the source list and this note's sources are the same six, read again here
for what each one actually contributes and where it stops.

### A. Colyseus -- authoritative room state, sequential messages

<https://github.com/colyseus/colyseus> · <https://docs.colyseus.io/server/room/>
**Licence: MIT. Maintenance: actively maintained** (0.16 line).
**Well:** the clearest published statement of this exact shape. `Room.onMessage(type, handler)`
handlers run **sequentially against one authoritative state**, and `reserveSeat` is literally seat
reservation with the server as arbiter -- so "two clients claimed the same seat in the same frame" is
resolved by arrival order and nothing else.
**Badly:** its `@colyseus/schema` binary patch protocol is the half we refuse -- nine rows fit in one
snapshot, and a delta stream a client could miss would draw a taken stand as free. Its rooms own
their own Node loop; Roblox hands us the loop.
**Adopted:** one authoritative table, handlers that do not yield, whole-state broadcast.
`StandPick.claim` yielding nowhere is this guarantee written as a property of our own code.

### B. Nakama (Heroic Labs) -- the authoritative match handler

<https://github.com/heroiclabs/nakama> ·
<https://heroiclabs.com/docs/nakama/concepts/multiplayer/authoritative/>
**Licence: Apache-2.0. Maintenance: actively maintained.**
**Well:** `match_loop(ctx, dispatcher, tick, state, messages)` is handed the tick's inbound messages
as an **ordered list** and returns the new state -- a reducer over a batch, which is `Match.Phase`'s
own shape. It makes "the server decides, in order" an interface rather than a convention, and is
explicit that a client message is a **request** and the state is the server's.
**Badly:** fixed-rate loop that owns its own tick; the Go/Lua/TS runtimes bring nothing reusable; and
it has no notion of a privileged slot, which is the half `high-seats.md` borrowed elsewhere.
**Adopted:** the request/state split -- `StandRequest` carries the ask, `MatchState` carries the
truth.

### C. Valve Source SDK 2013 -- `HandleCommand_JoinTeam` / `HandleCommand_JoinClass`

<https://github.com/ValveSoftware/source-sdk-2013> (`game/server/hl2mp/hl2mp_player.cpp`)
**Licence: Source SDK 2013 licence -- source-available, non-commercial, NOT open source.**
**Maintenance: effectively dormant** (a multiplayer-branch refresh in 2024, little since; already
recorded as such in `high-seats.md` section 8).
**Well:** the canonical server-side validator for a client asking to occupy a constrained slot during
a round's setup window. The engine checks the window, the team, the limit and the "you are already
that" case **in that order**, refuses with a reason, and never trusts the client's idea of what is
free. That ordering is `StandPick.ORDER`.
**Badly:** class limits are global rather than per-slot, so it has no answer to "stand 4
specifically"; and the licence permits the **idea** and nothing else.
**Adopted:** the refusal ORDER and one reason per rule. **Nothing is copied.**

### E. Abdulkadiroglu and Sonmez -- serial dictatorship (the fallback)

*"Random Serial Dictatorship and the Core from Random Endowments in House Allocation Problems"*,
Econometrica 66(3), 1998. <https://doi.org/10.2307/2998585>
**Licence: journal article, all rights reserved -- idea only. Maintenance: n/a.**
**Well:** agents in a fixed order each take their most preferred still-unclaimed acceptable item --
**collision-free by construction**, which is the property D5's fallback must have. Already the cited
pattern of `HighSeats.dealLine`, so this is a borrowing **declared twice** (rule 2).
**Badly:** the literature randomises the order for fairness across draws and we deliberately do not
(the same roster gets the same stands every drive). It has no notion of a **prior claim**, which is
exactly what sweep A adds.
**Adopted:** the mechanism unchanged as sweep B, with sweep A making a claim **strictly stronger**
than a preference.

### D. Roblox Creator Docs -- `RemoteEvent` security and `GuiButton.Activated`

<https://create.roblox.com/docs/scripting/events/remote> ·
<https://create.roblox.com/docs/reference/engine/classes/RemoteEvent> ·
<https://create.roblox.com/docs/reference/engine/classes/GuiButton#Activated>
**Licence: Creator Docs content repo is CC BY 4.0. Maintenance: continuous, first-party.**
**Well:** two first-party facts this task rests on. (1) *"Never trust the client"* -- every argument
is validated server-side, which is why `StandPick.judge` exists at all. (2) `Activated` fires for a
mouse click, a touch tap and a gamepad button on one handler, which is the whole of D3's "mouse and
touch" and the reason 323b adds no input owner.
**Badly:** reference indexes with no prose on contention, ordering or rate limiting. **They do not
state that `OnServerEvent` handlers are serialised** -- so this design does not depend on that: the
property is made ours by `claim` not yielding.
**Adopted:** validate everything; `Activated` as the one tap entry point (323b).

### F. Deutscher Jagdverband / WILD UND HUND -- `Standvergabe` at a Drueckjagd

<https://www.jagdverband.de/> · <https://wildundhund.de/drueckjagdstaende-sicher-ist-sicher/>
**Licence: editorial, all rights reserved -- read-only reference. Maintenance: live sites.**
**Well:** the real-world source for *what* the system must do. At a German driven hunt the
*Jagdleiter* allots the stands at the *Ansprache*, commonly by drawing numbered lots, **before**
anybody walks out -- so two hunters never share a stand and every neighbour's position is known
before a shot is possible. That is D4 and D7 in one practice: one authority, in advance, changing
**who** stands where and never **where** the stands are.
**Badly:** prose with no mechanism -- no dimensions, no timings, and a real `Standvergabe` is a man
with a hat full of tickets, which says nothing about contention in a frame.
**Adopted:** the allotment happens before the hunt and one authority makes it. It is the sentence
that justifies the window being **before** the drive rather than Karen's existing walk during it.

### G. Borrowed from inside this repo (rule 2, so nothing is invented)

| Taken | From |
|---|---|
| the whole-line deal and its three passes | `HighSeats.dealLine` |
| a pure rule per question over an injected measurement | `Weapon.Rules`, `Lobby.Pads.withSize` |
| a reducer with effects as values, `phaseEndsAt` as the only clock | `Match.Phase` |
| hold -> pivot -> restore with no respawn | `Body.standCharacter` + `Body.untieCharacter` |
| the one placement rule (ground at the target's own x, z) | `Body.onGround` |
| a flag read once at the owner's boundary, passed inward as a number | `Match.CONFIG.TIE_UNTIL_DRIVE_END`, `QUICK_TEST` |
| the optional-last-argument seam that keeps every older caller identical | `ForestTest.openPick(..., standIndex?)`, `Body.placementFor(..., _line?)` |
| a public `on<X>Request` a spec drives by parameter, behind a guarded `Connect` | `Lobby.onRoleRequest`, `Lobby.onPadRequest` |
| `tostring(userId)` / `tostring(index)` keys on the wire | `MatchSnapshot.stands`, `Horn.keyFor` |

## 3. What was invented, and why it had to be (rule 2)

**Sweep A** -- honouring every claim before anybody takes anything by fallback -- is this design's one
addition to source E, and it is forced: with one pass, hunter 1 (no pick) takes `walk[1]` on his turn
and hunter 3's claim of `walk[1]` is then refused by the fallback. A claim losing to a man who
claimed nothing is the inverse of D4. Two sweeps make a claim strictly stronger, which is what
"first request wins and the rest fill what is left" means.

Nothing else is new: the window is an existing phase, the clock is an existing timestamp, the deal is
an existing function with a fifth argument, and the move is four pieces of `Body` composed.

## 4. The numeric targets (design section 12)

| Name | Value | Why |
|---|---|---|
| `STAND_PICK_SECONDS` | **15** on / **0** off | brief D2's first value. It **is** the `Assigning` phase, so there is no second number to keep in step |
| `STAND_PICK_MIN_SECONDS` | **3** | below this the map does not auto-open for a late joiner (323b): about one read and one tap |
| `STAND_PICK_MIN_INTERVAL` | **0.25** | the floor between one player's accepted changes. It is `STATE_MIN_INTERVAL` exactly, so a forced push can never outrun the throttle it bypasses |
| `STAND_PICK_MAX_REQUESTS` | **20** | per player per drive. A human changes his mind two or three times; 20 is seven times that and a hard ceiling on a forged client's cost |

Three claims that are **measurements, not targets**, each a spec case:
`dealLine` with `nil` / `{}` / a full `picks` is **equal element by element** to today's deal for
every layout at every count 1..16 (**128 assertions**); `stats.standsSettled` equals how many hunters
claimed, and is **0** with the flag off; `stats.movedStuds` is bounded by
`standSpacing x (standCount - 1)` = 1,200 studs on the `road`.

## 5. What this note does not answer

The on-screen hit-pad size at 400x800, `stats.movedStuds` in a real drive, and whether
`Body.carry` with `attempts = 1` ever misses the ground at a stand (`Body.snapMisses()` must stay 0)
are **measurements in a running place**, and the design records them as the Builder's to take. 323a
takes none of them live: the Director closed Karen's Forest Test for this task, so 323a's proof is
its specs and the two-player run, and the live figures are **NOT PROVEN** until 323b.
