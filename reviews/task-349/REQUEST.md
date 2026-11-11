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

## WHAT CHANGED (round 2)

`ForestTest.driveZ(x, aim?)` is the one definition of this drive's z at an x, and every reader of an
animal's FATE reads it. The aim is settled ONCE per drive, in front of the first thing that puts an
animal down, and the runtime's field moves with it -- a Brain is born with its field, so every
animal of a drive is judged by the frame it was released into.

- **`Data.fieldFor(layout, dz)`** shifts `exitZ`, `road.zAt` and `bounds`. These are the two the
  round-1 defect was made of: `Brain._outcome` reports `escaped` at `position.Z <= field.exitZ`, and
  `_updateOutOfPlay` measures `settledNorthStuds` from `road.zAt`. `bounds` moves with them because
  a box that excludes the band would clamp every animal in it.
- **`Data.releaseFrame(layout, dz, startX, startNorth, crossX, exitSouthStuds)`** is the one place
  the shift reaches a release's three z's. `releaseLine` AND `orderGroup` both draw the start, the
  crossing and the exit with it, so they cannot disagree.
- **`Data.rosterAim(frames, enabled)`** is the roster rule. `ForestTest.lockedFrames` builds its
  input from `state.picks` filtered by `Players:GetPlayerByUserId`, so a bot can never be in it.
- **By parameter**: `releaseLine(now, staged, inPlace, aim)`, `stepPlacement(now, inPlace, aim)` and
  `orderGroup(row, now, aim)` all take it, exactly as `inPlace` is taken.
- **The silent arms speak**: `releaseLine`'s four `return nil` arms now name their reason (no room,
  no route, no handle, nothing placed).
- `retire`, `urgeAcrossRoad`, `checkAtTheEdge`, `waveReport`, `boarThreats`, `restSpot`/`bedSpot`,
  `restReport` and the roar all read `driveZ`.

### Two things I found by reading, said here rather than left to be found
1. **`urgeAcrossRoad` and `checkAtTheEdge` do not run in today's game.** `ForestTest.step` returns
   inside the `Data.LINE.enabled == true` branch before reaching them; the code says so itself
   (`"checkAtTheEdge -- the wave path's only caller of Runtime:check"`). They are aimed for
   correctness, but round 1's finding 1(c) is about a path that is already dead with `LINE.enabled`
   true. Nothing here makes them live.
2. **`ForestTest.start` re-applied the LAST drive's shift** to a fresh runtime. Found by
   `forest_stand.spec:643` while building this round; a new runtime now starts on the main road.

### A prediction, written before the measurement
Round 1 shifted the START but not the EXIT, so every route ran from dz ~1100 to the main road's exit
plane ~1000 studs south. I expect that to be why the flank drive released 72 where the main line
released 121, and I expect the named arms to say `no route could be drawn` if I am right. If the
AFTER run shows the count restored without those lines, my explanation was wrong and I will say so.
