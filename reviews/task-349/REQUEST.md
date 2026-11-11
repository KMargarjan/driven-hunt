# Task 349 round 2: the flank stand gets a real drive

Task: 349
Round: 2
Base: 6fa59255 (origin/main, #365)
Code commit: PENDING

## PLAN (Core Quality Protocol step 0, committed before any `src/` edit)

**(a) REAL LIFE.** On a driven hunt the guns stand on one line and the beaters push a block of wood
toward THAT line; the animals break out, cross the line the guns are on, and are gone. The line the
animals cross and the line the guns stand on are the same line. There is no version of it where the
crossing happens 975 studs from the gun.

**(b) MEASURED NOW** (round 1, her Forest Test, C1, `<runs-dir>/349-arm.luau` + `349-table.py`;
`A11b-track.txt`, `B11-track.txt`): flag OFF, a hunter on west-flank stand 11 saw 0 of 120 released
animals inside 120 studs in a whole 299 s drive. Flag ON at `8939503e`, only the RELEASE frame
moved: first sighting 15 s, median gap 11 s -- but **released 120 -> 72 and peak live 35 -> 16**,
because `Data.fieldFor` still hands the animals' owner the MAIN road, so `_updateOutOfPlay`
despawns each one as `settled` 60 s after it stops being ordered and `_outcome` can never report
`escaped`. Escapes on the flank drive have never been counted.

**(c) TARGET.** From stands 4, 7 and 11: first sighting <= 30 s, median gap <= 20 s, max gap <= 40 s,
and **released and peak live within 10% of the same drive on the main line** (the dispatch's own
numbers -- no more 120 -> 72). Escapes on the flank drive > 0, because 0 is the signature of the
defect. Within 10% is the Director's figure and it is the right one: it is the margin that says the
flank drive is the SAME drive translated, not a different and poorer one.

**(d) LEVER.** One aim per drive, reaching every reader that decides an animal's fate.
```
src/shared/ForestTest/init.luau:1188:		exitZ = ForestTest.exitZOf(resolved),
src/shared/ForestTest/init.luau:1208:			zAt = function(x: number): number
src/shared/ForestTest/init.luau:1209:				return ForestTest.roadZ(x, resolved)
src/server/ForestTest/init.luau:3065:	runtime:setField(Data.fieldFor(chosen.layout))
src/server/ForestTest/init.luau:1159:		local dz = if centre then centre.Z - Data.roadZ(centre.X, chosen.layout) else nil   -- retire
src/server/ForestTest/init.luau:3593:		local dz = at.Z - Data.roadZ(at.X, chosen.layout)                                   -- urgeAcrossRoad
src/server/ForestTest/init.luau:3621:		local dz = at.Z - Data.roadZ(at.X, chosen.layout)                                   -- checkAtTheEdge
src/server/ForestTest/init.luau:4934:		(Vector3.new(at.X - ForestTest.hunterStandX(), 0, at.Z - Data.roadZ(at.X, ...)))     -- roarNow
src/server/ForestTest/init.luau:1911:				local dz = at.Z - Data.roadZ(at.X, chosen.layout)                           -- restSpot/bedSpot
src/server/ForestTest/init.luau:3897-3940  stagedLine's route points
src/server/ForestTest/init.luau:4531,4565  orderGroup's crossing and exit
```
Each of those WRITES the geometry the animals are judged by. `ForestTest.driveZ(x, aim)` becomes
the one definition of "this drive's z at an x" and every site above reads it.

**(e) HOW IT WILL BE MEASURED AFTER.** The same instrument as (b) -- `349-arm.luau` at 1 Hz in her
Forest Test, `349-table.py` -- extended with `released`, `peak live`, `step avg` and an **escape
count** read off the runtime's own despawn reasons, so before and after are the same probe.

### The roster rule (decision 4)
`ForestTest.rosterAim(frames, enabled)` is pure: 0 real locked picks -> no aim; 1, or several that
agree to within `AIM_FLAT_STUDS` -> that frame; **real players on different frames -> dz 0 (the main
road) and a `why` naming them**, which `stepLines` prints once. Bots cannot appear in `frames`:
the server builds it from `state.picks` filtered by `Players:GetPlayerByUserId`.

### One frame per drive (decision 1)
The aim is settled at the FIRST RELEASE of a drive and latched for that drive, and the runtime's
field is re-applied in the same breath -- a Brain is born with its field
(`src/server/Boar/init.luau:7144`), so every animal of that drive is judged by the frame it was
released into. A pick locked after that applies from the next drive.
