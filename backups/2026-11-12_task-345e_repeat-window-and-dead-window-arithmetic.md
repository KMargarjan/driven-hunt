# Archived in task 345e (T5): the repeat window's reach, and five functions nothing reads

Rule 7. Nothing here is deleted without a reason and a copy.

## 1. `Data.slotAt`'s repeat branch, on the `PLACEMENT_IN_PLACE` ON path

**Not removed. SCOPED.** With the flag OFF the branch is Karen's drive today, byte for byte, and
`docs/design/animal-placement.md` 17's T6 is where the switch flips. With the flag ON `slotAt` now
answers nil past `#rows`, so `Data.SCHEDULE.repeatFrom` / `repeatTo` and `Data.repeatRoomFor` are
unreachable on that path and are left in place for the other one.

**Why.** Design 5.3: *"a fixed roster has nothing to repeat"*. `ESCALATE.md` 2026-11-10 ~00:35
measured where the overrun came from -- past slot 15 a group went out every 13 s for the rest of the
clock and nothing despawned one still walking, so live animals climbed to `MAX_BOARS` 60 in every
cell at every density and the **quiet** cell D1 reached 55. `ESCALATE.md` 2026-11-11 item 5 then
measured it still spawning with the switch on (*"SLOT 16 ... 9 of 9 animal(s)"*,
`345d-ON1-C1-console.txt`), because `releaseLine`'s roster branch only fires for a slot that HAS a
roster row and slots 16+ have none.

The clamp family (`releaseDepth`, `routeFloor`, `clampedToLine`, `SCHEDULE.leadStuds`,
`minNorthStuds`) is kept for the same reason: `releaseLine`'s spawn half is live on the OFF path and
reads all five. They go with the OFF path at T6.

## 2. `LINE.twoLineChance = 0.25` -- dead data, removed

Read by nothing. `ForestTest.release` never touched it and `releaseLine` has read `row.files` since
task 251 (round 1 of task 251 noted it dead; design 8.2 lists it for retirement). The number it
carried is Karen's *"could be 2 i line"*, and `SCHEDULE.drive`'s rows now say the same thing per
group -- slot 12 is `files = 2`.

```lua
	-- HOW MANY LINES. *"could be 2 i line"* -- the Director's figure: about a quarter of waves come
	-- as two parallel lines, the rest as one.
	twoLineChance = 0.25,
```

## 3. D-3's five functions -- no reader at all, removed

`docs/design/animal-placement.md` 15's D-3, and `forest-drive.md` 7.2 had already retained them as
*"pure window arithmetic"* with no production caller. Greps at code commit, over `src/`, `tests/`
and `tools/`:

| Function | Production reader | Spec reader |
|---|---|---|
| `ForestTest.drive` | none (`ForestTestBoot` says the Heartbeat latch on it is archived) | none |
| `ForestTest.driveIndexAt` | only `ForestTest.drive`, above | none |
| `ForestTest.wavesPerDrive` | none | `forest_line.spec` only |
| `ForestTest.deerWaveOf` | none -- `SCHEDULE.drive` says which slots carry deer (task 251) | `forest_line.spec` only |
| `ForestTest.deerWanted` | none -- same | `forest_line.spec` only |

The `forest_line.spec` block that drove the last three goes with them: a spec for an archived
function is the next reader's trap, which is the thing rule 7 and D-3 both name.

```lua
-- in; the drive's number (counting from 1) and how many seconds are left in it, out.
--
-- It is a WINDOW OVER A CLOCK and not a state machine, which is why it needs no state: at any instant
-- the answer is the same arithmetic, so a restarted script, a late join and a spec all agree.
function ForestTest.driveIndexAt(startedAt: number, now: number, seconds: number): (number, number)
	local length = math.max(1, seconds)
	local elapsed = math.max(0, now - startedAt)
	local index = math.floor(elapsed / length) + 1
	return index, length - (elapsed % length)
end

function ForestTest.drive(now: number)
	local index, left = ForestTest.driveIndexAt(state.startedAt, now, Data.DRIVE.seconds)
	return { index = index, secondsLeft = left }
end

-- HOW MANY WAVES A DRIVE OF THIS WORLD RELEASES. Pure, and it is the metronome's own arithmetic
-- rather than a number: 300 seconds at one wave per 20 is 15.
function ForestTest.wavesPerDrive(driveSeconds: number?, intervalSeconds: number?): number
	local seconds = driveSeconds or Data.DRIVE.seconds
	local gap = math.max(1, intervalSeconds or Data.SCHEDULE.intervalSeconds)
	return math.max(1, math.floor(seconds / gap))
end

-- WHICH WAVE OF A DRIVE CARRIES THE DEER. Pure: a unit draw in, an ordinal out.
--
-- IT IS DRAWN FROM THE FIRST THIRD OF THE DRIVE, AND THAT IS WHAT MAKES IT A GUARANTEE RATHER THAN
-- A BETTER CHANCE. Here the ordinal is only ever reached: a 300-second drive runs 15 waves
-- and the window is five, so the deer are out inside the first 100 seconds whatever else happens.
function ForestTest.deerWaveOf(pick: number, waves: number): number
	local window = math.max(1, math.floor(math.max(1, waves) / 3))
	return math.clamp(math.floor(math.clamp(pick, 0, 0.999999) * window) + 1, 1, window)
end

-- IS THIS WAVE THE ONE? Pure, and `>=` and not `==` on purpose: a wave that could not carry the
-- deer -- the cap said no, there was no room, the flag is off -- must not spend the drive's
-- guarantee, so the next wave picks it up. `done` is the latch.
function ForestTest.deerWanted(driveWave: number, deerWave: number?, done: boolean): boolean
	if done or deerWave == nil then
		return false
	end
	return driveWave >= (deerWave :: number)
end
```

`Data.DRIVE.seconds` is untouched and keeps its readers (the forest's `DRIVE_SECONDS` override).
