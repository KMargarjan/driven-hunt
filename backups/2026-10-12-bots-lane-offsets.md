# Archived: `Bots.Lane.offsetFor`, `Lane.startFor`, `Lane.goalFor` and `Bots.CONFIG.LANE_SPACING_STUDS`

Archived by task 167 on 2026-10-12 (CLAUDE.md rule 7). Written by task 161.

## Why

Karen, 2026-10-12 ~16:10, having played a drive in the Forest Test as a HUNTER with the bots on:

> "and seem like all bots came to me"

She was right. These three functions spread a beater line by taking the drive's one measured BASE
and a lane number: `+-LANE_SPACING_STUDS` (18) and outward, with every lane's goal translated
sideways off the one base goal. Two things follow, and neither can be fixed inside `Bots`, which
reads no marker, no post and no player:

1. **72 studs of total front, centred on the base.** In the Forest Test the drivers' base is
   `ForestTest.beaterStartPosition()`, on the push line through the stand the drive aims at -- which
   is the stand she was standing on. Four bodies inside 72 studs of her stand is a queue at her
   feet, not a drive line. How wide a line should be is a fact about the HUNTERS' FRONT.
2. **A sideways-translated goal is not on the road.** `goalFor` keeps the base goal's z, the forest's
   road is a sine 30 studs deep (`ForestTest.ROAD.amplitudeStuds`) and
   `Match.CONFIG.BOTS.GOAL_PAST_LINE_STUDS` is 20 -- so at any width worth having, a lane's goal can
   land NORTH of the road. The bot then stops short of the line, `Match.crossedLine` never counts it
   through, and a drive can only ever end on the timer. At 18 and 36 studs the error was 8 and 15
   studs against that 20-stud margin: already most of it.

## What replaced it

* `ForestTest.beaterLaneOffset(index)` -- 0, +150, -150, +300, -300 ... on
  `ForestTest.BEATER.laneSpacingStuds` (= `STAND_SPACING`), so the lanes land on the stand grid. The
  property these functions existed to protect is kept: index 1 is the push line, so a REAL beater
  keeps the middle and the bots flank her.
* `ForestTest.beaterStartPosition(index)` measures the ground and the trunks at the lane's own x.
* `Match.botSlotsFor` asks `place(markers, "Drivers", realBeaters + lane, cfg)` per lane -- the same
  shape it already used for a hunter's stand -- and takes each lane's goal from
  `Match.beaterGoalFor(thatStart, ...)`, which is the post nearest THAT lane, 20 studs past the line:
  the same post `Match.crossedLine` measures it against, so arriving IS crossing.
* The DEV arena needed no change: `Match.Body.placementFor` already spread drivers across the pad by
  index.
* `Bots.laneOf(slot)` is now the identity and says so.

## The code, as it was

```lua
-- LANE 1 IS +spacing, LANE 2 IS -spacing, LANE 3 IS +2x, LANE 4 IS -2x. The same alternating
-- nearest-first shape `ForestTest.beaterStartPosition` uses for its side tries, so four bots span
-- 4 * LANE_SPACING_STUDS with nobody in the middle.
--
-- LANE 0 RETURNS 0, and that is not a lane: a stander carries `lane = 0` and never asks this. It
-- answers rather than erroring because a nil here would be a crash in the one place a spec cannot
-- see, and `bots_lane.spec` asserts the owner never issues it.
function Lane.offsetFor(lane: number, config): number
	if lane <= 0 then
		return 0
	end
	local step = math.ceil(lane / 2) * config.LANE_SPACING_STUDS
	return if lane % 2 == 1 then step else -step
end

-- WHERE THIS LANE STARTS: the base the drive chose, moved sideways along the base's own right.
-- The facing is the base's, unchanged -- every bot of a line looks the same way, down the push.
function Lane.startFor(base: CFrame, lane: number, config): CFrame
	local offset = Lane.offsetFor(lane, config)
	if offset == 0 then
		return base
	end
	return base + base.RightVector * offset
end

-- WHERE THIS LANE ENDS: the base's goal, moved sideways by the SAME offset and along the SAME axis.
-- Flat: the Y is the goal's, because the ground under the goal is the drive's measurement and not
-- this module's.
function Lane.goalFor(baseGoal: Vector3, base: CFrame, lane: number, config): Vector3
	local offset = Lane.offsetFor(lane, config)
	if offset == 0 then
		return baseGoal
	end
	local side = flat(base.RightVector)
	if side.Magnitude < 1e-4 then
		return baseGoal
	end
	return baseGoal + side.Unit * offset
end

```
