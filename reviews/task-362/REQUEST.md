# Task 362 -- a dead animal from the previous drive is gone when the next drive starts

Task: 362
Round: 1
Base: 243a8ea0 (origin/main)
Code commit: 887f3ceb106551a00e4d8c762993445fe8a9f126

```
[harness] PASS: 34/34 checks @ 887f3ceb106551a00e4d8c762993445fe8a9f126 (clean tree) scope=all
```

`test2` is **N/A**: nothing changed is in `TWO_PLAYER_PATHS` -- `src/server/Boar/`,
`src/server/ForestTest/`, `src/server/ForestTestBoot.server.luau`, `tests/server/`,
`tools/studio_mcp.py`, none of them in that list.

## PLAN (core quality protocol, step 0; committed at 43054faa before any `src/` edit)

(a) **REAL LIFE.** A drive ends, the bag goes to the *Strecke*, and the next drive starts on clean
ground. Karen, 2026-11-13 ~12:00 UTC: *"dribve started leftover from prebviuos"*. The number is
**0** bodies of an earlier drive when a drive starts.

(b) **MEASURED NOW**, in HER place and not DEV (claim 2), probe `<runs-dir>/362-watch2.luau`: a
carcass is a child of `Workspace.Boars` with `Carcass=true`; `Workspace.DriveScene` going up is the
drive ending and going down is the next drive starting (`Phase.enterAssigning` emits `clearScene`
in the same dispatch as `clearBoars`). `DHForestDriveSeconds=60`, six drive changes:

| boundary | at the drive's END | at the NEXT drive's START (+1 s) |
|---|---|---|
| 1 | 2 | **2** |
| 2 | 0 | 0 |
| 3 | 6 | **6** |
| 4 | 5 | **5** |
| 5 | 3 | **3** |
| 6 | 0 | 0 |

and a seventh BY NAME: drive end `[Boar203,Boar165,Boar181,Boar164]`, next drive start the same
four. Not one body was ever removed at a boundary.

(c) **TARGET.** 0 at every drive start; nothing changes inside a drive.

(d) **LEVER.** `Match` already asks at both edges (`Match/Phase.luau:783`, `:884` emit
`clearBoars`) and `applyClearBoars` answers:

```
src/server/Match/init.luau:1862:	if world and world.boars and world.boars.clear then
src/server/Match/init.luau:1864:		world.boars:clear("driveOver")
```

In DEV `world.boars` IS the runtime. In the Forest Test it is `ForestTest.readOnlyBoars`, which has
no `clear` **by design** (`docs/design/forest-drive.md` 9.4), so that conditional is false and
nothing removes a body in the one place Karen plays. No writer existed; one was added.

(e) **AFTER: the same probe, the same place.**

## What changed

1. `src/server/Boar/init.luau` -- `Runtime:clearCarcasses(reason)`: every entry that is not on its
   feet (`liveCount`'s test, inverted), through the same `_despawn` path `clear` and `clearOne`
   use. Returns the count.
2. `src/server/ForestTest/init.luau` -- `ForestTest.CARCASS_CLEAR_PHASES` (`Scoring`, `Assigning`)
   and `ForestTest.clearPreviousDriveCarcasses(runtime, phase)`, pure of any instance.
3. `src/server/ForestTestBoot.server.luau` -- the `Match.PhaseChanged` handler it already has calls
   it and holds no rule of its own.
4. `tests/server/forest_carcass_clear.spec.luau`, in the `boar` and `match` scopes.

## Claims

1. **No owner moved.** `Match` still cannot touch an animal in this world: `readOnlyBoars` is
   unchanged, and a case asserts it has no `clear`, no `clearCarcasses`, no `spawn`, no
   `spawnSounder`. The WOOD is still never cleared at a boundary; only bodies go. Verify:
   `git diff 243a8ea0..887f3ceb -- src/server/ForestTest/init.luau` (the view's table is untouched)
   and the third case in `forest_carcass_clear.spec`.
2. **DEV was never the defect, so it was not measured there.** `applyClearBoars` in DEV holds the
   real runtime, and `Runtime:clear` takes carcasses too (its own header: *"Carcasses go too: the
   drive is over"*). The dispatch asked to reproduce in DEV; the read of `applyClearBoars` above
   refutes that as the place to look, and the measurement was taken in the Forest Test instead.
3. **FAIL FIRST, case 1 (L-028), the producer deleted.** With the `_despawn` call inside
   `Runtime:clearCarcasses` disabled, a dirty-tree run gave
   `forest_carcass_clear.spec:117 -- Expected value "1" (number), got "0" (number)`
   (`[harness] FAIL: 32/34 checks @ 6dc9332e... (DIRTY TREE (1 paths) - NOT valid evidence)`).
   Restored; 34/34 at the code commit.
4. **FAIL FIRST, case 2 (L-093), the other branch.** With the phase guard in
   `clearPreviousDriveCarcasses` disabled: `forest_carcass_clear.spec:130 -- Expected value "0"
   (number), got "1" (number)` -- the kill inside the drive was removed early. Restored.
5. **`Running` is in neither set**, so a kill lies where it fell for the whole `CARCASS_SECONDS`
   and the report, the claim and the score are untouched. Verify `CARCASS_CLEAR_PHASES` and the
   second case's loop over `{"Waiting", "Running"}`.
6. **MEASURED AFTER, in her place**, same instrument (`362-watch4.luau` adds one column: how many
   bodies lay in the drive that ended, which the fix makes invisible at the boundary itself):

   | boundary | bodies that lay in that drive | standing at the next drive's start, +1 s / +5 s / +12 s |
   |---|---|---|
   | A | 3 `[Boar10,Boar9,Boar6]` | **0 / 0 / 0** |
   | B | 2 `[Boar75,Boar94]` | **0 / 0 / 0** |
   | C | 1 `[Boar95]` | **0 / 0 / 0** |
   | D | 1 `[Boar122]` | **0 / 0 / 0** |

   plus fourteen further boundaries in which no animal died, all 0. The owner's own line was seen
   in the console: `[ForestTest] drive 3: 1 body(ies) of the previous drive removed`.
7. **The first hook was wrong, and the measurement is why it moved** (commit 887f3ceb). With
   `Assigning` alone the bodies were still standing 3 s into the next drive
   (`NEXT DRIVE #1 STARTED +3s: carcasses=3 [Boar9,Boar10,Boar14]`): `Match` fires `PhaseChanged`
   at the END of its dispatch and `enterAssigning`'s `placePlayers` yields on
   `Player:LoadCharacter()`. `Scoring` has nothing before it that yields, so it does the work and
   `Assigning` is the backstop -- the two edges `Match.Phase` emits `clearBoars` on.
8. **Her Forest Test is as it was.** 25 `DH*` attributes before and after, diff empty
   (`<runs-dir>/362-attrs-before.txt`, `362-attrs-after.txt`); the `DHForestDriveSeconds=60` the
   measurement needed is removed; `:34873` is served from `driven-hunt-karen` again, connected, in
   Edit. No Save, no Publish, no Drafts Commit, and no code was ever checked out in that copy.
9. **NOT PROVEN: my own AFTER frame (rule 5).** Karen's frame is the BEFORE and is opened and
   described below. An AFTER frame of the same spot could not be taken: `capture` in Play
   photographs what the CLIENT draws, and the client's camera controller overwrites any camera set
   from outside, so the only way to aim it is to move the player -- and both body spots recorded
   were in a cell the next drive had unloaded (task 337 loads one cell), so `362-AFTER-spot.png`
   and `362-AFTER-spot2.png` came back as sky and ground fog with a readable HUD and no terrain
   (both opened). Four routes were tried: `362-spotframe.py` (a scriptable camera, overwritten),
   `362-eye.py`, `362-frame.py`, and `362-frame3.py` (restricted to a body within 150 studs of the
   player -- no animal died in that window). `ft-open.sh` is a cold restart and does not aim a
   camera. Claim 6's table is the evidence instead.

   **Karen's frame, opened** (`<runs-dir>/362-karen-leftover-carcass.png`): a black boar lying on
   its right side, legs out, tusks showing, on the bare dirt verge beside the grass, the yellow
   stand ring curving across the frame behind it and the shooter's barrel in the lower-left corner.
   A body on the ground at a stand -- which is what claim 6's four rows now read 0 for.
10. **Flakes, named.** `licence_popup.spec:367` (`Expected nil, got "no-range"`) fired at
    `4101ba15` and in the dirty FAIL-FIRST run, and did NOT fire at `6dc9332e` nor in any of the
    three runs at `887f3ceb`; it is not in the dispatch's list and is queued as 362a. Two runs at
    the code commit preceded the PASS: one with a client failure whose spec the console buffer had
    rolled past before it could be read, and one in which all 3704 specs passed and only the input
    replay failed with a StudioMCP transport fault (`tie-the-driver: user_mouse_input ... Target is
    not reachable`). The third run is the PASS pasted above.
