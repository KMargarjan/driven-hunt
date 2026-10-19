# Task 217 — review request: roles rotate each drive, and the turn survives a logout

Task: 217
Round: 1
Base: `167dbaf` (`main`)
Code commit: `af0c257fbe927246853fc68c6b91856d91654999`

Branch `task-217-role-rotation`. Design `docs/design/role-rotation.md` (Architect, PASS round 1,
`reviews/task-217/ARCH_RESULT.md`). Brief `reviews/task-217/BRIEF.md`. Note
`docs/research/2026-10-20-role-rotation.md`.

```
[harness] PASS: 33/33 checks @ af0c257fbe927246853fc68c6b91856d91654999 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ af0c257fbe927246853fc68c6b91856d91654999 (clean tree)
```

Both lines name the **same** commit, and it is the code commit: `src/server/Match/` and
`src/shared/Drive/` are both in `TWO_PLAYER_PATHS`, so this task needs the two-player run. The
**Director ran it**, first try, on the clean tree at that commit.

---

## What changed

Karen, 2026-10-11: *"ROLES ROTATE: you start as a hunter, next round you are a beater; it is
REMEMBERED across logout/login (no cheating back to hunter) — persistent per player (DataStore)."*

**Alternation was not the new part** — `Roster.assign`'s `previous` swap plus
`SWAP_TEAMS_EACH_DRIVE` already rotated within one server session. What is new is that the turn is a
per-player fact that outlives the session: one additive field (`Store.TEMPLATE.nextTeam`) on the
existing key of the existing persistence owner, four new pure functions in `Match.Roster`, one new
`Phase.Event` field, and two write edges in `Match` that sit beside writes that already happen.

---

## The claims, and how to verify each

**1. The rotation rule is pure, and `Roster.assign` is untouched.**
`src/server/Match/Roster.luau` gains `other`, `invert`, `previousFrom`, `joinTeam`. `Roster.assign`,
`Roster.counts` and `Roster.smallerTeam` are unchanged except for one comment line on `assign`'s
header. Verify: `git diff 167dbaf..af0c257 -- src/server/Match/Roster.luau` — the body of `assign`
below `local ids = sorted(userIds)` is identical. The 2..16 sweep in
`tests/server/match_roster.spec.luau` is **unedited** and is the regression.

**2. The flag-off story is an IDENTITY, not a hope.**
`Roster.previousFrom(previous, nil)` and `previousFrom(previous, {})` return `previous` **by
identity** (the same table, not a copy), and `joinTeam(counts, nil, config)` is
`Roster.smallerTeam(counts, config)` exactly. Verify: the cases *"hands `previous` back BY IDENTITY
when nobody is owed anything"*, *"and the split is then byte-for-byte today's, for every size from 2
to 16"* and *"is `smallerTeam` exactly when nothing is owed"* in `match_roster.spec`. With no
economy injected `Match.dispatch` never sets `filled.owed` at all.

**3. The inversion is in exactly one place, and both directions of it are asserted on one value.**
`previousFrom` INVERTS (because `assign` swaps) and `joinTeam` does NOT (it places a man directly).
That asymmetry is the one trap in the design (its hazard 9). Verify: *"lands a player on the team he
is owed, through assign's own swap"* and *"is placed directly, where previousFrom is inverted — the
same owed value, both ways"* in `match_roster.spec`. A spec that asserted only `previousFrom`'s
output would pass with the inversion backwards; these do not.

**4. The turn is NOT consumed when the team sizes overrule it — structurally, with no second field.**
The only thing that ever writes the record is `other(the role he ACTUALLY played)` at the drive's
end, so a man owed beater whom the balance rule made a hunter is written beater again. Verify: *"lets
the balance rule overrule the turn, and still splits the teams equally"* in `match_roster.spec`
(which also walks the second drive and shows the turn paid), and *"is overruled by the team sizes,
and the roster still splits equally"* in `tests/server/match_phase.spec.luau`. Equal teams still hold
at every roster size with every player owed the same side.

**5. The stored turn reaches the pure machine on the EVENT, and `Phase.State` gains nothing.**
`Phase.Event.owed`, filled by `Match.dispatch` beside `aliveBoars` / `boarEntries` / `beaters`; read
in `enterAssigning` and the `join` branch and nowhere else. Verify: the `describe` *"the role a
player is OWED, arriving on the event"* in `match_phase.spec` — including *"is never written into
the state"* and *"adds no effect kind and no second assignTeams"*. **This is the only place the
stored turn can be told apart from the in-memory swap**, because `previousAssignment` can be held at
nil there while `event.owed` carries a value.

**6. The record is written where a team is already written, so it cannot go stale.**
`applyAssignTeams` (`src/server/Match/init.luau`) calls `world.economy.noteNextTeams(assignment)`
after `Body.setTeam` — one call site covering `enterAssigning`'s whole-roster write, the `join`
branch's one row and the `team` branch's one row. Verify: `git diff` of that function; and
`tests/server/match_teams.spec.luau`'s new case, which asserts on the REAL drive that the record
agrees with `Player.Team` for every player (or, with the flag off, that there is no record at all).

**7. The flip is on the `Scoring` edge, and its reason is NOT the pay-out's reason.**
Beside `payDrive`, before `applyEffects`, `world.economy.noteNextTeams(Roster.invert(state.assignment))`.
The comment says why plainly: nothing about the turn goes on the wire, so TASKS.md 32a(c) does not
apply — it is there because `applyEffects` applies `scene`, which moves every character, and a
`PlayerRemoving` landing in a yield would reach `Economy.release` and drop the session before the
flip was written. Verify: the comment and the code in `dispatch`; and
`tests/server/zz_drive_boundary.spec.luau`, which asserts on the real production boundary that every
player's record is `Roster.other(the team he played)`.

**8. One additive field, on the same key, under the same store name, and it is a STRING on purpose.**
`Store.TEMPLATE.nextTeam = ""`. `Store.read`'s clone branch is `type(value) == "table"`, so a scalar
default can never reach hazard 1 (one shared table handed to every player) — structural, not a
promise. `""` rather than a missing key because a nil-valued key cannot exist in a Lua table, so the
template would not name the field at all. Verify: the three new cases in
`tests/server/economy_store.spec.luau`, and the design's section 6, which enumerates **every**
consumer of the frozen template and what each does with the new key (L-030/L-096: `Store.read`'s two
halves, `deepFreeze`, `memory`'s `seed`/`peek`/`save`, `live`'s `ProfileStore.New` and `load`,
`Economy.load`'s projection, and the three specs that read it). `STORE_NAME` and `schema` are
unchanged.

**9. The owner validates, memoises and derives nothing.**
`Economy.teamFromRecord` is the one validator (anything that is not one of the two team names reads
as *no turn stored*); `Economy.owedTeams()` is frozen **and memoised** — `Match.dispatch` reads it on
every event, and while TASKS.md 214a(a) is open that dispatch is stepped at ~15× `MATCH_STEP_HZ`, so
a clone per call would be ~60 table builds a second; `Economy.noteNextTeams` is the one writer, skips
and counts a userId with no session and a value it refuses, and stores exactly what it is told.
Verify: the `describe` *"the role a player is owed"* in `tests/server/economy.spec.luau` — the
validator over ten values, the identity assertion on two consecutive reads, the skip/refuse counters,
*"does not retain the caller's table"*, the lost-session case, and *"is left alone by a pay-out and by
a purchase"*.

**10. The round trip is the feature, and it is asserted twice.**
`load` → `save{nextTeam}` → `peek` → `release` → `load` → the same value.
`tests/server/economy_store.spec.luau` *"keeps the turn across a release and a fresh load"* drives the
store directly; `economy.spec` *"writes the turn to the key, and reads it back after a release and a
reload"* drives the OWNER through `Economy.release` / `Economy.load`. `Store.memory`'s `saved`
closure outlives a release, so both are real round trips.

---

## What I could not verify, and the two false-pass paths the design named

1. **The live run cannot evidence the RECORD, and it is a harness-seam limitation I had not met
   before.** `execute_luau` through StudioMCP runs with its **own module cache**: a probe that does
   `require(ServerScriptService.Match)` in the running server gets a FRESH `Match` and `Economy`
   (`driveNumber=0`, `phase=Waiting`, `isEnabled()=false`, `loads=0`) while the real server's console
   prints `[economy] coins=on store=memory` and the drive is in `Running`. I proved the probe really
   is on the live server (`placeId=130094961655666 isRunning=true isServer=true players=1`), so the
   divergence is the module cache and not the datamodel. **Instance facts (`Player.Team`, the Tool in
   the character, the HUD) read correctly; module state does not.** I did not add a print to
   production to get round it. Reporting it as a harness fact (rule 6); it is not a regression of
   this task and it affects every future task that wants to read owner state live.
2. **"Two drives in a row: hunter then beater" is NOT evidence of this task** (the design's hazard
   10). The in-memory swap already does it, and `enterWaiting` does not clear `previousAssignment`,
   so even the lobby's dismissal between drives leaves the swap able to produce the same answer. The
   live run below is therefore evidence that nothing regressed and that the two new production call
   sites run with `COINS` on without error — not that anything was remembered. **The feature's
   evidence is the round trip (claim 10), in the suite.**
3. **No harness run can ever exercise the ON branch of the production call sites** (hazard 11):
   `test` and `test2` both refuse to start while a `DHFlag_` override is set. Every ON claim in the
   suite is therefore driven **by parameter** (`Economy.start{ enabled = true, store = Store.memory() }`),
   and `zz_drive_boundary` and `match_teams` keep an `if Economy.isEnabled()` conditional whose OFF
   branch asserts there is no record at all. Said out loud rather than papered over.
4. **A live DataStore round trip is not verified and cannot be from Studio** — `Store.memory` by
   construction (task 170). The live path is the same `Store.save` call the balance already uses.
5. **Karen has not seen** the balance-override rule, the mid-drive-join tie rule, or `/beater`
   winning one drive and then rotating off it. Queued as 217b.

## The live run (Forest Test, place 130094961655666, Karen's own attributes untouched)

Her settings captured before and read back identical afterwards:
`DHFlag_COINS=true DHFlag_DRIVE_BOTS=true DHFlag_SHOP=true DHFlag_HORN=nil DHFlag_LOBBY=true
DHForestStartRole=hunter DHForestLayout=nil DHShopTestGrant=true`. **I changed none of them.**

Three consecutive drives, one player, enrolling at a truck pad each time (`ftplay.py server
lobby-go.luau` — rule I):

| Drive | `Player.Team` | In hand | Frame |
|---|---|---|---|
| 1 | `Shooters` | `Shotgun` | no frame (the session was spent diagnosing item 1 above) |
| 2 | `Drivers` | `Horn` | `<runs-dir>/t217/drive2-beater-eye.png` — **DRIVE 2**, badge **BEATER**, *"walk to the road, push the boars"*, **HORN READY**, 2010 coins |
| 3 | `Shooters` | `Shotgun` | `<runs-dir>/t217/drive3-hunter-eye.png` — **DRIVE 3**, badge **HUNTER**, *"stay on your stand, boars coming"*, 12 BUCK, 2020 coins |

Both frames are from the player's own head CFrame (rule F) and I looked at both. The coins rising
2000 → 2010 → 2020 is the useful part: `payDrive` ran on each `Scoring` edge, which is the **same
dispatch block** that now also calls `noteNextTeams(Roster.invert(...))` — so write edge 2 executed
on the real path with the economy live. Whole session: **209 console lines, 0 `Stack Begin`, 0 error
lines.** `bash smoke.sh 80` → **SMOKE PASS** (gun in hand at 15 s and at 80 s, 0 stacks, 0 errors,
9 waves, on the ground at both samples and after a respawn).

## Not fixed, by the Director's own instruction

TASKS.md **214a(a)** (the Forest Test sweep re-offering a refused role ask every Heartbeat) and
**214b** (the role ask as an input to `Roster.assign`) are both open in this exact path. This task
fixes neither; it designs AROUND 214a(a) (the memoised read, claim 9) and shapes the seam for 214b
(`Phase.Event.owed` is the per-event injected reader it prescribes).

## Paperwork only after the code commit

`git diff --name-only af0c257..HEAD` answers exactly two paths — `reviews/task-217/REQUEST.md` and
`TASKS.md` (the task's own status row plus the rows queued as 217a/217b/217c). Nothing under `src/`,
`tests/` or `tools/` changed after the tested commit, so both harness lines above cover the head.
