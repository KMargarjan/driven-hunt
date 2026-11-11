# Task 349 round 2: the flank stand gets a real drive

Task: 349
Round: 2
Base: 6fa59255 (origin/main, #365)
Code commit: f4e7962d81034ab428d1bce3e7e179250d743fad

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

## MEASURED, on her Forest Test, C1, hunter, stands picked by REAL clicks on the map

```
[harness] PASS: 34/34 checks @ f4e7962d81034ab428d1bce3e7e179250d743fad (clean tree) scope=all
```
`test2`: N/A -- no changed file is in `TWO_PLAYER_PATHS`.

One drive each, 299 s, same instrument (`<runs-dir>/349-arm.luau`, 1 Hz: an animal counts when it
is within 120 studs of her stand AND the ray from her own eye to it is unobstructed).

| run | commit | stand | in view | worst gap | released | peak live | step avg | escaped | outOfBounds |
|---|---|---|---|---|---|---|---|---|---|
| `B11` OFF | 6fa59255 | 11 corner | **0 of 290** | -- (never) | 120 | 35 | -- | -- | -- |
| `A11d` ON | f4e7962d | 11 corner | **212 of 304** | none > 20 s | 121 | 28 | 3.294 | 105 | 0 |
| `A4` ON | f4e7962d | 4 central | first at 2 s | none > 20 s | 121 | 33 | 3.618 | 112 | 0 |

**THREE CYCLES ON HER PATH, each one a live drive at its own commit (core protocol step 2):**

| cycle | commit | change | corner stand measured | distance to target |
|---|---|---|---|---|
| 1 | c6d6e7a2 | one frame per drive, latched at the first release | `minD` 1112 studs, `drive aimed: dz +0, nobody locked`, 0 in view | inert: the latch fired before the pick locked |
| 2 | 03b279ee | "nobody locked" is a not-yet; field box translated | frame taken from her eye, but `released` 72, `outOfBounds` 101 | band culled by the field's box |
| 3 | f4e7962d | box unioned ACROSS as well as along | 212 of 304 in view, `released` 121, `outOfBounds` 0, `escaped` 105 | **met** |

Cycle 1 was found by the diagnostic line this round added (`drive aimed:`); cycle 2 by
`DespawnByReason`, which the instrument now reads.

## Claims

1. **The corner stand went from nothing to a drive.** `B11-track.txt` line 1: `near=0` on every row
   of 290. `A11d-track.txt`: 212 of 304 rows carry a visible animal, `minD` reaching 26 studs, and
   `349-gaps.py A11d:9` reports no gap over 20 s. Target was <= 40 s.
2. **Nothing can escape on an unaimed flank drive, and now 105 do.** Round 1: `escaped` absent.
   `A11d` `fate=escaped=105` with `outOfBounds=0`. The lever is `Data.fieldFor`'s `exitZ`.
3. **The flank drive is the same drive, translated.** `released` 121 against the main line's 121
   (0%), `escaped` 105 against 112 (-6%), `step avg` 3.294 against 3.618 (-9%, cost DOWN).
   **`peak live` 28 against 33 is -15% and misses the dispatch's 10%** -- in the direction of less
   load, and reported rather than rounded.
4. **The field's box is a union, not a translation, on BOTH axes, and both halves were measured.**
   Translating z culled the groups released before she locks (114 in a drive); leaving x alone
   culled the whole aimed band, because a flank stand is 604 studs outside the main line's box
   (101 in a drive). `forest_stand.spec` asserts the stand is inside its own drive's box and that
   the main road stays inside it.
5. **A pick locked after the first slot still aims its own drive.** The first slot is due at 10 s
   and the pick window is 15 s, so latching at the first release latched `nobody locked`. The
   invariant kept is the stronger one -- every animal is judged by the frame it was RELEASED into,
   because a Brain is born with its field -- and the case asserts `settleAim` returns `latched=false`
   while nobody is locked.
6. **The case fails if the server wiring is deleted (L-093), run twice.** Deleting `lockedFrames`'
   producer: `failed [server] forest_stand.spec:160` (`math.abs(on.dz - want) < 1e-6`). Deleting
   `applyField`'s shift: `failed [server] forest_stand.spec:163` (the field's `road.zAt`). Both were
   run, both reverted, tree clean.
7. **The frame.** `<runs-dir>/A11d-sighting.png`, from stand 11's own eye (-4504.4, 133.7, -4087.3;
   stand 11 is at -4504, -4087) at the instant the probe measured a hind 118 studs out with a clear
   ray. I opened it: hunter's first-person view, shotgun barrel and glove bottom-left, long grass,
   the yellow verge, two tracks running north, conifers either side; HUD `DRIVE 1 / 4:45 TIME /
   0 ANIMALS / HUNTER`. **`A11d-left.png` is its left edge at 6x: four red deer walking across the
   open under the treeline.** The hind the probe named is NOT identifiable at the frame centre --
   a hind at a run covers ~20 studs in the second between the probe and the capture -- so the frame
   is cited for what it shows: animals in front of her stand, which is the thing that was absent.

## What I could not verify

- **No OFF row at the code commit for stands 4 and 7, and no ON row for stand 7.** The window in
  her place opened at 21:30 and three of the four drives I could fit went into the three iteration
  cycles. `B11` is at `6fa59255` and is labelled with it (L-162); with the flag OFF the aim is 0 for
  every stand and the released points are identical to that commit, but I did not re-measure it.
- `neverNearAnyStand` 10 at the corner against 0 on the main line: a band translated onto one stand
  passes hers and no other. Nobody has judged whether that reads as emptier elsewhere.
- **`urgeAcrossRoad` and `checkAtTheEdge` do not run in today's game** (`ForestTest.step` returns
  inside the `LINE.enabled == true` branch). They are aimed; nothing here makes them live.
- The roster SPLIT branch is proven as the pure rule only. Two real Players with locked picks on
  different frames cannot be reached by a one-player harness, and `src/server/ForestTest/` is not in
  `TWO_PLAYER_PATHS`. Said here rather than assumed (L-137/L-158): adding it is the Director's call.
- Karen has not played it. The flag is OFF in her Forest Test.
