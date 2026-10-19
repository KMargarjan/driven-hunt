# Task 214 -- starting as a beater works again in the Forest Test

Task: 214
Round: 1
Base: 7127ed1 (main)
Code commit: 029c68d11969c02d7f2f7943f4c38c84bbe78ef4

Harness, clean tree, FULL run:

```
[harness] PASS: 33/33 checks @ 029c68d11969c02d7f2f7943f4c38c84bbe78ef4 (clean tree) scope=all
```

`test2`: **N/A.** Not one path this task touches is in `TWO_PLAYER_PATHS`
(`src/server/ForestTest/init.luau`, `src/server/ForestTestBoot.server.luau`,
`tests/server/forest_stand.spec.luau`). The dispatch expected `src/server/Match/` and
`tests/client/Role.luau`; neither is touched -- `Match` is asked, never changed.

## What changed, and what was actually wrong

**The dispatch's premise did not reproduce, and the honest answer is narrower.** Task 212 reported
that with `DHForestStartRole=beater` the player "still boots as a hunter", `Match.requestTeam`
returns `false`, and after two minutes `team=nil tool=nil`. Measured on Karen's own path first
(rule H), lodge -> truck pad -> drive, in her place: **the ask is never lost.** 212 never walked to
a truck pad, so it was never enrolled, so there was no drive to move it inside of -- which is
exactly what `Match.requestTeam` answers `false` to, by design. (Its probe also read a `require`d
copy of `ForestTest`, which over StudioMCP is a sandboxed instance with empty state --
`ForestTest.toWire`'s own header says so.)

**What IS wrong is WHEN the ask is offered.** It was offered at exactly one instant -- the `Running`
edge -- and the lobby (177/209) moved enrolment to after that instant. Measured, `console-a/b/c.txt`
in the runs directory:

```
[ForestTest] ... asked to join as a beater (start switch)      <- the ask IS recorded at the join
[ForestTest] ... is a hunter at (3030, 143, -2097), 0 studs from the road
[ForestTest] ... is walking to stand 5 this intermission (edge ring 12 studs, 48 segments)
[ForestTest] ... is now a beater (team=Drivers)                 <- only at GO
```

So she spent the whole intermission as a hunter -- `team=Shooters hand=[Shotgun]`, on stand 5 with a
ring round it and the objective reading *get to your stand* -- and was then flipped and respawned
580 studs north in the middle of the fanfare. Before the lobby she was in the drive from the frame
she joined, so `Assigning` and the `Running` edge were one intermission and the gap could not exist.

**The fix is task 202's own shape, one layer further in** (L-029): "he asked" is a STATE, not an
instant. `ForestTest.toHonour` is asked on the same Heartbeat as `toWire` -- who is owed the role he
asked for -- and the `Running` edge stops honouring anything, so there is one owner and not two.
`Match` still decides: `honour` calls `Match.requestTeam` exactly as before.

**The guard is a measurement, and the first version of it was wrong.** `Body.place` connects
`CharacterAdded` and only then calls `LoadCharacter`, disconnecting once its own pivot is done -- so
two placements in flight for one player both pivot the SAME new character. The first version of this
sweep guarded on the character alone and produced, for ONE enrolment:

```
[place] spawn ... at (3030, 237.6, -1517)   <- the beater line
[place] spawn ... at (3030, 143.5, -2097)   <- the road
[ForestTest] ... is a beater at (3030, 144, -2097), 0 studs from the road
```

a beater with the horn standing on the hunters' stand. The record is therefore TWO facts -- the
character the caller watched land, AND the `Player.Team` he had at that moment -- because
`assignTeams` is applied before `placePlayers` in the same dispatch, so a drive that is about to
move a man has already written his new side, and that is the only signal that exists in the window
before `LoadCharacter` swaps anything. Together: *his body has stood still since the drive last
changed its mind about him.*

## Claims

1. **`ForestTest.toHonour` answers who is owed his role ask, and nobody while a placement is
   landing.** `tests/server/forest_stand.spec.luau`, *"says whose role ask is owed, once his body
   has stood still (task 214)"* -- no ask -> nil; ask + stood still -> him; a newer body -> nil; a
   newer team -> nil; no body at all -> nil; taken -> nil. It writes nothing: the ask is still
   pending after the sweep has named him.
2. **The case fails on the pre-fix code** (L-028). `src/server/ForestTest/init.luau` and
   `src/server/ForestTestBoot.server.luau` checked out at `7127ed1` with the new spec kept:
   `[harness] FAIL: 31/33 ... (DIRTY TREE ...)`, `1675 passed, 1 failed, 1 errors`,
   `ServerStorage.Tests.forest_stand.spec:1115: attempt to call a nil value`. Saved verbatim in
   `<runs-dir>/t214/PREFIX-FAIL.txt`.
3. **The `Running` edge no longer honours anything, and the sweep is the one owner.**
   `src/server/ForestTestBoot.server.luau`: the loop that called `honour` in the `PhaseChanged`
   handler is gone; the Heartbeat calls `ForestTest.toHonour` beside `ForestTest.toWire`. The
   `player.Chatted` handler still calls `honour` directly, which is what prints *"the drive is
   Waiting, so it happens when the next one starts"* -- that message is unchanged.
4. **The settle record is written in exactly one place and dropped in one place.**
   `settledCharacter` in `ForestTestBoot`: written only inside `reportStart`'s existing
   `PLACEMENT_SETTLE_SECONDS` delay -- and BEFORE that function's early return, so a character that
   is still unparented cannot leave a player's ask unhonourable for ever -- and dropped only by
   `PlayerRemoving`. Nothing clears it on a respawn or a team change: the reader compares both
   fields with what the player has now.
5. **No stand pick or ring is opened for a man who has asked to be a beater.** Same file, the
   `Assigning` block: `ForestTest.pendingRequest(player.UserId) == nil` is a third condition.
   `roleOfPlayer` cannot see an ask -- it reads `Player.Team`, which is the drive's answer and not
   the question. Live: no `is walking to stand N this intermission` line appears for either route
   now.
6. **LIVE, ROUTE 1 (`DHForestStartRole=beater`), on Karen's path** -- `<runs-dir>/t214/console-after-2.txt`.
   In order: lodge spawn -> `[report] drive 1 opened` -> stand placement ->
   `is now a beater (team=Drivers)` -> `[place] spawn ... at (3030, 237.6, -1517)` ->
   `is a beater at (3030, 238, -1517), 580 studs from the road`. The flip is inside the
   intermission, the two placements are serialised, and the beater one lands last.
   Probe: `team=Drivers pending=nil hand=[Horn] bag=[] at=(3030,237,-1517)`.
7. **LIVE, ROUTE 2 (`/beater` typed in chat at the lodge, attribute at `hunter`)** --
   `<runs-dir>/t214/console-chat.txt`: `asked to be a beater; the drive is Waiting, so it happens
   when the next one starts` -> enrol -> stand placement -> `is now a beater (team=Drivers)` ->
   `is a beater at (3030, 238, -1517), 580 studs from the road`. Probe:
   `team=Drivers pending=nil hand=[Horn] bag=[] at=(3030,238,-1517)`.
8. **The horn is in the CHARACTER, not the Backpack, at the drive start, and it is drawn** (L-018).
   Client probe in the live session: `char=Alhamdulilah824`, `equipped tool Horn`, `bag=[]`,
   `camera child DrivenHuntHornViewmodel`. Frame at the player's own eye height,
   `<runs-dir>/t214/beater-eye.png`, looked at: first person in the wood, the horn in the gloved
   hand, the HUD reading **BEATER**, *walk to the road, push the boars*, **DRIVE 1 4:40**,
   **HORN READY**.
9. **Smoke PASS** (rule A), Forest Test, 100 s, after the fix, with the attribute restored to
   `hunter`: `gun in hand @15s=1 @100s=1 | stacks=0 errorLines=0 | waves=10`,
   `position @15s=[... ok hp=100 y=143.2] @end=[... ok] respawn+10s=[... ok]`, `SMOKE PASS`.
10. **Karen's place is as she left it.** Her `ServerStorage` attributes were written to a file
    before anything was changed (L-056, `<runs-dir>/t214/ATTRS-BEFORE.txt`) and read back after:
    `DHFlag_COINS=true | DHFlag_DRIVE_BOTS=true | DHFlag_LOBBY=true | DHFlag_SHOP=true |
    DHForestStartRole=hunter | DHShopTestGrant=true` -- identical, and Studio is in Edit.

## What I could not verify, and what is still open

- **The wasted first placement is still there.** She is placed on the stand and then placed again at
  the beater line about a second later; the only way to make it ONE placement is for the ask to be
  an INPUT to `Roster.assign` at the `Assigning` entry instead of a correction applied after it.
  That is a `src/server/Match/` change (`Phase.enterAssigning` plus a pure `Roster` function plus
  one injected world reader, the `aliveBoars` idiom), which is `TWO_PLAYER_PATHS` and a task of its
  own. Queued for the Director.
- **A player who enrols mid-`Running` with a pending ask.** His ask is now honoured by the sweep as
  soon as his body has stood still, which is new and better than before (it used to wait for the
  NEXT drive's `Running` edge) -- but it is a two-player case and I did not run two players, because
  nothing this task touches is in `TWO_PLAYER_PATHS`.
- **Drive 2 onwards is unchanged and is by design:** the ask is one-shot, so the second drive is the
  `SWAP_TEAMS_EACH_DRIVE` rotation's. Not re-measured here.
- **The horn's grip** (task 212's open item) is visible in the frame and is not this task's.
