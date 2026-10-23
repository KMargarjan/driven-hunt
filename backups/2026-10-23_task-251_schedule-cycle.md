# Archived: `ForestTest.SCHEDULE.cycle`, the six-row repeating wave list

**Task 251, 2026-10-23.** Rule 7: archived with a note rather than deleted.

**What it was.** Six rows, repeated for ever by `ForestTest.waveAt(index)`
(`cycle[((index - 1) % #cycle) + 1]`), so wave 7 was wave 1 again. It carried
`offsetX`, `northStuds`, `composition`, `turnsBack`, `lateral` and `note`.

```lua
	cycle = {
		-- Close, straight down across the road: 2 females, 3 males, 4 cubs.
		{ offsetX = -55, northStuds = 95, composition = 1, turnsBack = false, note = "a mixed flock, close and west" },
		-- Across her front, left to right, then over the road.
		{
			offsetX = 95,
			northStuds = 115,
			composition = 3,
			lateral = "LtoR",
			turnsBack = false,
			note = "five males and three females, across the front left to right",
		},
		-- Far out on the east, so it is not always the same spot.
		{ offsetX = 140, northStuds = 100, composition = 4, turnsBack = false, note = "sows and piglets, far east" },
		-- Across her front the other way.
		{
			offsetX = -95,
			northStuds = 115,
			composition = 2,
			lateral = "RtoL",
			turnsBack = false,
			note = "two males, across the front right to left",
		},
		-- Close again, and this one thinks better of it.
		{
			offsetX = 45,
			northStuds = 90,
			composition = 5,
			turnsBack = true,
			note = "a sow and her young, close, and back",
		},
		-- The lone big male, close enough to be worth the barrel.
		{ offsetX = -40, northStuds = 85, composition = 6, turnsBack = false, note = "one big lone male, close" },
	},
```

**Why it went.** KAREN, 2026-10-23: *"we need better saound and behaviour for red
stag / and them patter with animals how many where they come how they come how
many groups jumping over road red stags ect"*. A six-row loop repeated over
fifteen waves has no shape: no beginning, no end, no act, and every group drawn
from the same two or three depths. The Designer's spec
(`<runs-dir>/design/driveflow-spec.md` §2.2) replaces it with a FIFTEEN-ROW
DRIVE SCRIPT -- one row per slot of one drive, in three acts -- which is
`ForestTest.SCHEDULE.drive`. Every field above survives in the new rows under
the same name (`turnsBack` became the explicit `route = "BREAK-BACK"` plus
`turnAtDz`).

**A second reason, measured while reading the code.** The cycle was ALREADY
dormant in the world Karen plays: `ForestTest.LINE.enabled` is `true`, so the
live release path is `ForestTest.releaseLine`, which drew its own count (4-9),
its own crossing and its own pace and never read `cycle` at all. The only
readers were `ForestTest.waveAt` -> `ForestTest.release` (the pre-task-127 wave
path, unreachable at runtime) and one case in
`tests/server/forest_stand.spec.luau`. The drive script is read by BOTH paths,
so the data is live again.
