# The continuous drive loop: everybody back to the lodge, the next drive starts by itself

Task 246. Note for rule 1. Designs it extends: `docs/design/lobby.md` (sections 4, 6, 8),
`docs/design/truck-pads.md`, `docs/design/drive.md` (section 4), `docs/design/role-switch.md`.

**KAREN, 2026-10-23, verbatim:** *"we need back to lobby after hunt to have the same not saperate
for beaters (if it's not the same) / also we need continues game so after drive new drive imidiatly
after same amount seconds and who has licesne can select who he can be next round if dont then
oposit previuos round"*.

## 1. What the system must do

1. **One return for everybody.** A drive ends; every human participant comes back to the lodge the
   same way and at the same moment, whichever side he was on.
2. **The next drive starts by itself.** After the return, one fixed countdown, then the same group
   goes again. Nobody steps on a pad again.
3. **A way out.** A player who does not want the next drive says so on that card -- button or key --
   and stays in the lodge. By default he is in.
4. **A role for the next drive.** A man who owns `ALWAYS HUNTER` picks HUNTER or BEATER during the
   countdown. A man who does not gets the opposite of the side he just played.
5. New arrivals keep joining through the truck pads, and the group size continues.

## 2. What is already here, measured before anything was written

Two of the five are already true in the shipped code, and the whole of items 1 and 4 was MEASURING
that -- which is why this note starts with it rather than with the sources.

* **`Match.Phase` ALREADY LOOPS.** `Phase.step`'s `Scoring` exit is
  `if enoughPlayers(...) and markersComplete then enterAssigning(...) else enterWaiting(...)`, so a
  drive whose roster survives its own results scene starts the next one with no outside help. The
  thing that stops it is `Lobby.onPhase("Scoring") -> dismissPending -> world.dismissAll()`: the
  lobby EMPTIES the roster one scan into the results scene, so `enoughPlayers` is false at the
  `Scoring` exit and every drive falls out through `enterWaiting`. **The loop is not missing; it is
  switched off by the lobby, deliberately, by task 177.**
* **THE RETURN IS ALREADY ONE RULE FOR BOTH SIDES.** `Join.needsReturn(inDrive, held, inField)` is
  level-triggered and reads no team at all, and `Lobby.stepPlayer` applies it to every occupant
  through the one injected `place` seam (`Match.Body.place`, the one writer of where a character
  stands). `enterWaiting` emits `free` for everybody and `unassign` for everybody, and
  `Body.setTeam(player, nil, config)` re-dresses through the same window either way. So there is no
  per-role branch on the return path in the code -- which is what section 7 then went and measured
  on Karen's own path instead of asserting.
* **THE ROLE RULE IS ALREADY BUILT, ALL THREE ARMS.** `Lobby.onRoleRequest` ->
  `Lobby.beaterWishes()` -> `Roster.wishedWith` -> `Roster.assign`'s `wishers` list is the card
  owner's pick (tasks 229, 242, 244); `Roster.previousFrom` plus `Roster.assign`'s swap against
  `state.previousAssignment` is *"oposit previuos round"* (task 217, task 242's measured
  alternation). `enterScoring` writes `previousAssignment` BEFORE the lobby dismisses anybody, so
  the alternation survives the gap between drives untouched.

**So this task is one new thing and not three:** the party that goes again. Items 1, 3 and 4 are
then a measurement, a control, and a second surface for a control that already exists.

## 3. Sources

### A. Roblox's own round loop -- `Create a Battle Royale`, "Add rounds"

<https://create.roblox.com/docs/education/battle-royale-series/coding-the-game-loop>
Roblox Creator Documentation. First-party, maintained, and the reference loop for exactly this.
Fetched 2026-10-23 and quoted:

> "Send everyone to the lobby" ... "After waiting ten seconds for an intermission, the Rounds
> server script then starts the loop again by resetting everyone's scores and sorting them into new
> teams." ... "The sample repeats this cyclical round process again until there aren't any players
> within the server."

**This is Karen's sentence in Roblox's own words**, including the order she asked for: back to the
lobby FIRST, then a fixed wait, then the next round with the teams sorted again. What it does well:
it is the platform's own idiom, so nothing here is exotic. What it does badly: it is a `while true`
loop with `task.wait` inside one script -- the shape `Match.Phase`'s header already refuses in
capitals (*"EVERY TRANSITION IS TIME-DRIVEN FROM phaseEndsAt, AND phaseEndsAt IS THE ONLY CLOCK.
There is no task.delay, no task.wait and no second timer in this system"*), because a yielded loop
cannot be driven by a spec in milliseconds and a hitch inside one skips a phase. So the ORDER is
adopted and the mechanism is not.

### B. Valve, `CTeamplayRoundBasedRules` -- Source SDK 2013 / TF2's round state machine

`game/shared/teamplayroundbased_gamerules.cpp`. Valve SDK licence (source-available, not open
source); the 2013 SDK's last substantive commits are 2021-2023, so **maintained enough to read and
never a dependency** -- nothing is copied, only the shape. The official repo's `mp/src/...` path
404s to a fetcher (recorded as a negative result; the `sp/src` tree answers), so the file was read
from the `hl2sdk-csgo` mirror <https://github.com/pmrowla/hl2sdk-csgo>, fetched 2026-10-23:

> states: `GR_STATE_INIT`, `GR_STATE_PREGAME`, `GR_STATE_STARTGAME`, `GR_STATE_PREROUND`,
> `GR_STATE_RND_RUNNING`, `GR_STATE_TEAM_WIN`, `GR_STATE_RESTART`, `GR_STATE_STALEMATE`,
> `GR_STATE_GAME_OVER`
>
> `State_Enter_PREROUND`: `m_flStateTransitionTime = gpGlobals->curtime + 5 * mp_enableroundwaittime.GetFloat();`
>
> `State_Enter_TEAM_WIN`: `m_flStateTransitionTime = gpGlobals->curtime + flTime * mp_enableroundwaittime.GetFloat();`
>
> `ConVar mp_bonusroundtime( "mp_bonusroundtime", "15", FCVAR_REPLICATED, "Time after round win until round restarts", true, 5, true, 15 );`

What it does well, and it is the whole reason this is the second source: **ONE deadline field per
state** (`m_flStateTransitionTime`) rather than a timer per transition -- which is `Phase.luau`'s
`phaseEndsAt` and `nextReleaseAt` already, so the new countdown must be A DEADLINE IN A STATE and
not a `task.delay`. And it gives the industry's own number for the gap Karen is asking for:
`mp_bonusroundtime` defaults to **15 s and is clamped to 5..15** -- "Time after round win until
round restarts". What it does badly for us: the whole state machine is the GAME's, so a player who
wants to miss one round has nowhere to say so; TF2 answers that with spectator mode, which is a
place and not a flag.

### C. id Software, `CheckIntermissionExit` -- Quake III Arena

`code/game/g_main.c`. **GPL-2.0**, `id-Software/Quake-III-Arena` on GitHub; **archived and
unmaintained** (last upstream 2017), which is why it is read as a pattern and not adopted as code.
ioquake3 is the maintained fork of the same file. Fetched 2026-10-23 and quoted:

> ```c
> if ( cl->readyToExit ) { ready++; if ( i < 16 ) { readyMask |= 1 << i; } } else { notReady++; }
> cl->ps.stats[STAT_CLIENTS_READY] = readyMask;
> if ( !level.readyToExit ) { level.readyToExit = qtrue; level.exitTime = level.time; }
> if ( level.time < level.exitTime + 10000 ) { return; }
> ```

This is the OPT-OUT, and it is the shape item 3 needs: **a boolean per client, reconciled on the
server's own frame**, published outward as one value the client renders, with a deadline that runs
whatever anybody presses. What it does well: nothing is edge-triggered -- a player who connects,
disconnects, or changes his mind halfway through is simply counted differently on the next frame,
which is Learning Agent L-029's lesson and `Join.needsReturn`'s own stated reason (*"there are four
ways to end up standing in the wrong place and only one of them is a phase change"*). What it does
badly: `readyMask` is a 16-bit field and silently drops client 17 (`if ( i < 16 )`), so above 16
players the published fact is not the measured one -- this game's cap is 16 and the attribute
written here is per-player, so the bug cannot be inherited.

### D. The negative result: `developer.valvesoftware.com` is HTTP 403 to every tool

The CS2 / CS:GO console-variable page -- where `mp_round_restart_delay` and `mp_freezetime` are
documented -- answered **403 Forbidden**, as the whole wiki does to a fetcher. So the CS lineage of
the same idea (a fixed restart delay, then a freeze window in which a player may still change team)
is **named and NOT quoted**, and source B carries the number instead. Recorded rather than
paraphrased from memory, which is this repository's rule.

## 4. The pattern adopted, and why

**A PARTY THAT GOES AGAIN, OWNED BY THE LOBBY, AS A PURE STATE MACHINE WITH ONE DEADLINE.**

`src/server/Lobby/Next.luau` -- new, pure, no Instance, no service, no clock -- beside `Join` and
`Pads`, for the reason those two are separate from their owner (*"a rule with no world in it is a
table of cases in a spec, and a rule inside the owner is a thing somebody watches in a playtest"*).
`Lobby`, which already owns WHO IS IN THE DRIVE (`world.enrol` and `world.dismissAll` are its two
doors), holds one of these and asks it what to do on the scan it already runs at `SCAN_HZ`.

Why the lobby and not `Match`:

* **the roster door is already the lobby's**, and a second enroller would be two answers to "who is
  in this drive" -- this project's named failure mode;
* **the return is already the lobby's** (`Join.needsReturn`), and the countdown must not start until
  the party is actually back at the lodge, which only the thing that does the returning can know;
* **`Match.Phase` needs no change at all.** Its `Scoring` exit already starts the next drive when
  the roster is there. A phase for the gap would be a second answer to "is a drive on" --
  `Phase.driveOpen`'s own warning -- and would put the lodge inside the match machine.

Four decisions inside it, each from a source above:

1. **ONE DEADLINE IN THE STATE** (source B): `state.at`, a server time. No `task.delay`, no second
   timer, and `Next.step` is handed `now` -- so `tests/server/lobby_next.spec.luau` runs a whole
   cycle with hand-written numbers.
2. **THE COUNTDOWN ARMS WHEN THE PARTY IS HOME, NOT WHEN THE DRIVE ENDS** (source A's order): the
   members are collected at the dismissal, and the deadline is set on the first scan on which no
   member is still in a drive and none is still held -- which is the instant `enterWaiting`'s `free`
   lands and the return rule fires. Karen asked for the lobby FIRST and then the wait.
3. **OPTING OUT IS A LEVEL FACT, RECONCILED EVERY SCAN** (source C): a `sitOut` set, not an edge. A
   man who leaves, who walks onto a pad, who presses SIT OUT and then presses it again, and a man
   whose party empties out under him, are all answered by the same pass.
4. **IT GOES OUT THROUGH `Lobby.depart`**, the seam the pads already leave through, so the not-built
   reserved-server implementation (design section 9) keeps working and there is one place a party
   leaves the lobby.

**Borrowed before built (rule 2):** the loop's ORDER is source A's, the one-deadline-per-state is
source B's, the per-client ready flag is source C's. What is ours is only that the three meet in the
module that already owns the roster -- and the reason that had to be written rather than borrowed is
that none of the three sources has a lobby a player walks back to AND a per-round role choice.

## 5. The numeric targets

| Number | Value | Where it comes from |
|---|---|---|
| `NEXT_DRIVE_SECONDS` | **8** | the Director's dispatch (*"reuse the existing between-drive length"*): `Match.CONFIG.SCORE_SECONDS` is 8 after Karen's *"make 8s max"* of 2026-10-18. It is inside source B's own clamp (`mp_bonusroundtime`, 5..15) |
| gap drive -> drive | **31 s** | 8 results scene (`SCORE_SECONDS`) + 8 lodge countdown (`NEXT_DRIVE_SECONDS`) + 15 intermission (`INTERMISSION_SECONDS`, in which the hunters walk to their stands). Only the middle number is new |
| arming | **<= 0.2 s** after the party is free | the lobby's own `SCAN_HZ` (10 Hz) plus one scan of slack, which is `Pads`' existing bound |
| the card's countdown | ticks **8 -> 0** on every member's screen | one attribute (`DHNextDriveAt`, a server time) through `Lobby.secondsLeft`, the wire `DHLobbyLeaveAt` already uses |
| SIT OUT | reversible until the deadline | source C's `readyToExit`, which a client may flip as often as it likes |
| role picks accepted | the whole countdown, and the intermission after it | `Lobby.onRoleRequest`'s existing `in-a-drive` refusal is false at the lodge, and `Lobby.wishFor` only clears a wish the drive has SPENT |
| the group | **continues**; new men arrive through the pads | `Next` adds nobody. A pad enrolment during the countdown is the existing path and drops that man from the party on the next scan, because the drive has him |

## 6. What could go wrong, named before it was built

1. **A COUNTDOWN THAT NEVER ARMS.** If one member stays `held` or `inDrive` for ever the deadline is
   never set. Bounded: `Next.ARM_TIMEOUT_SECONDS` arms it anyway, and members are dropped as they
   leave, so an empty party clears itself.
2. **TWO ENROLMENTS FOR ONE MAN.** A member walks onto a pad during the countdown and that pad
   departs; the party then enrols him again. Closed by `world.inDrive` being the membership test on
   every scan -- the same fact `occupancy` already drops a man from a pad list for.
3. **A WISH SPENT TWICE.** `Lobby.wishFor` clears on `world.assignedTeam(userId) ~= nil`, which is
   nil between drives -- so a pick made on the countdown card survives to the assignment that reads
   it, and is cleared by that assignment. Unchanged by this task, and asserted.
4. **THE RESULTS SCENE CUT SHORT.** The party is collected at the dismissal, one scan into
   `Scoring`; nothing is enrolled until the whole scene plus the countdown has run, so Karen's score
   table is on screen for its full 8 s.
5. **SIT OUT AND THEN NOTHING.** A man who sits out while everybody else goes is left at the lodge
   with the pads, which is exactly the lobby before this task. The card says so.

## 7. What was measured on Karen's own path

Recorded in `reviews/task-246/REQUEST.md` with the frames and the sampled trace: where a HUNTER and
a BEATER each end up when a drive ends, before and after, and three consecutive drives with no pad
stepping between them.
