# Task 362 -- a dead animal from the previous drive is gone when the next drive starts

Task: 362
Round: 1
Base: 243a8ea0 (origin/main)
Code commit: TBD

## PLAN (core quality protocol, step 0)

(a) **REAL LIFE.** On a driven hunt the drive ends, the bag is carried to the *Strecke* and laid
out, and the next drive starts on clean ground -- no body is left lying in the wood. Karen asks for
exactly that: *"dribve started leftover from prebviuos"* (2026-11-13 ~12:00 UTC, with a frame).
The number is **0** carcasses of an earlier drive at a drive's start.

(b) **MEASURED NOW** -- her place, the Forest Test, probe `<runs-dir>/362-watch2.luau`
(`DriveScene` up = the drive ended, `DriveScene` down = the next drive started; carcasses are the
children of `Workspace.Boars` with `Carcass=true`). Six drive changes, `DHForestDriveSeconds=60`:

| boundary | carcasses at the drive's END | carcasses at the NEXT drive's START |
|---|---|---|
| 1 | 2 | **2** |
| 2 | 0 | 0 |
| 3 | 6 | **6** |
| 4 | 5 | **5** |
| 5 | 3 | **3** |
| 6 | 0 | 0 |

A seventh, by NAME: drive end `[Boar203, Boar165, Boar181, Boar164]` -> next drive start
`[Boar203, Boar165, Boar181, Boar164]`. Not one body is removed at the boundary.

(c) **TARGET.** 0 at every drive start, and **unchanged inside a drive**: a kill still lies where it
fell for `CARCASS_SECONDS` (120) and the report, the claim and the score still count it.

(d) **LEVER, and the pasted grep.** `Match` already asks for this at both edges --
`Match/Phase.luau:783` and `:884` emit `{ kind = "clearBoars" }` -- and `Match/init.luau:1859`
`applyClearBoars` answers it:

```
src/server/Match/init.luau:1862:	if world and world.boars and world.boars.clear then
src/server/Match/init.luau:1864:		world.boars:clear("driveOver")
```

In the DEV place `world.boars` IS the runtime, so DEV clears everything at both edges and has no
defect. In Karen's place the drive holds `ForestTest.readOnlyBoars` (`ForestTest/init.luau:6008`),
which **by design** (`docs/design/forest-drive.md` 9.4, task 157) has no `clear` -- so that
conditional is false and **nothing removes a carcass at a drive boundary in the one place she
plays**. There is no writer: the lever has to be added.

**It is added without moving an owner.** `Match` still may not touch an animal in a world it does
not own, and the forest's WOOD is still never cleared at a drive boundary -- the view's shape is
unchanged. What is added is a door on the animals' own owner, `Boar.Runtime:clearCarcasses`, taking
the bodies and nothing on its feet; and the Forest Test's own boot, which already owns that runtime
and already listens to `Match.PhaseChanged`, calls it on the `Assigning` edge. A carcass is not
wood.

(e) **AFTER is measured with the same probe, in the same place, the same way.**

## What changed

1. `src/server/Boar/init.luau` -- `Runtime:clearCarcasses(reason)`: every entry that is not on its
   feet, through the same `_despawn` path `clear` and `clearOne` use. Returns how many it took.
2. `src/server/ForestTest/init.luau` -- `ForestTest.clearPreviousDriveCarcasses(runtime, phase)`:
   the decision, pure of any instance, so both of its branches are drivable by parameter.
3. `src/server/ForestTestBoot.server.luau` -- the existing `Assigning` handler calls it.
4. `tests/server/forest_carcass_clear.spec.luau` -- the two cases.

## Claims

TBD
