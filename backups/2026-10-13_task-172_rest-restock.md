# Archived: `ForestTest.REST.restockSeconds` and the re-stock branch of `ForestTest.stepRest`

Archived by task 172 on 2026-10-13 (CLAUDE.md rule 7). Written by task 154, deepened by 155 and 162,
and narrowed by 168.

## Why

Karen, 2026-10-13 ~09:25, after playing 168-171 as a beater:

> "and again no boar behing comming after beater walk"

The word is **again**: task 168 had already made the beaters' line SWEEP what it passes, and it had
already found and half-fixed this. Its own measurement, recorded in `src/server/ForestTest`'s
`restSpot` header: **7 animals of 25 appeared up to 31 studs behind the front**, because the resting
band is measured from the ROAD and the line is deep inside that band by the time the wood is
re-stocked. 168 preferred a spot in front of the line and, finding none, **placed it anyway** and let
the sweep catch it on the next tick -- which is exactly the animal Karen then saw come out behind the
beaters a second time.

The reason is geometric and no search can fix it. The band is 40-425 studs from the road; a beater
starts at 580 and walks south; fifteen seconds after the wood is empty the line is somewhere inside
the band, so the deep rows have nowhere left that is in front of anybody.

**So a wood is beaten once.** The first stock stands, and when she has pushed or shot the lot it
stays empty for this drive. The whole of the re-stock -- the timer, the empty-detector and the second
`stockWood` -- is archived here with it, and `restSpot`'s "place it anyway" fallback pass is gone.

## What was removed

### `src/shared/ForestTest/init.luau`, in `ForestTest.REST`

```lua
	-- ...AND HOW LONG AFTER THE WOOD IS EMPTY before it fills again. Long enough that she SEES it
	-- emptied -- a wood that refills the instant the last animal crosses is a wood she can never
	-- clear, which is the opposite of a drive.
	restockSeconds = 15,
```

### `src/server/ForestTest/init.luau`, in `ForestTest.stepRest`

```lua
	if #(state.rest or {}) == 0 then
		-- NOTHING HAS EVER BEEN PUT DOWN: fill it now, on the first heartbeat after she becomes a
		-- beater. Level-triggered rather than called from the boot, so a role set before the runtime
		-- existed, a `/beater` typed mid-session and a respawn all end in the same place.
		return ForestTest.stockWood(now) or spooked
	end
	if ForestTest.restAlive() > 0 then
		state.restEmptyAt = nil
		return spooked
	end
	-- EMPTY. She has pushed or shot the lot, so the wood fills again -- after a pause, so that she
	-- sees it emptied (`REST.restockSeconds`).
	if state.restEmptyAt == nil then
		state.restEmptyAt = now
		return spooked
	end
	if now - state.restEmptyAt < Data.REST.restockSeconds then
		return spooked
	end
	state.rest = {}
	state.restEmptyAt = nil
	return ForestTest.stockWood(now) or spooked
```

`state.restEmptyAt` went with it (declared in `ForestTest.start`'s reset block and cleared at the end
of `stockWood`); `state.restStocked` is the latch that replaced it. `ForestTest.restAlive` is kept --
it is published in `ForestTest.stats()` as the honest answer to "how much of the wood is left".

### `src/server/ForestTest/init.luau`, in `ForestTest.restSpot`

The second pass's fallback. It used to read:

```lua
	-- TWO PASSES, AND THE SECOND ONE IS TODAY'S SEARCH. Once the line is at the road the whole wood
	-- is behind it, and a refusal with no fallback would leave the wood empty until the next drive --
	-- which is a feel decision nobody has made. So: prefer a spot the line has not reached; if the
	-- whole search finds none, place it anyway and let the sweep do its job, exactly as before this
	-- task.
	for pass = 1, (if #beaters > 0 then 2 else 1) do
		local avoidSweep = pass == 1 and #beaters > 0
```

The feel decision nobody had made is the one Karen has now made twice, in the words above. The two
passes that are there today differ by the SIGHTLINE, not by the sweep rule: that one holds in both.

## How to put it back

Three edits, in this order: the `restockSeconds` row above, the `stepRest` body above (plus
`state.restEmptyAt = nil` in `ForestTest.start`'s reset and at the end of `stockWood`, and dropping
`state.restStocked`), and `restSpot`'s `avoidSweep` back to `pass == 1 and #beaters > 0`. The spec
case `never re-stocks the wood, which is the last way an animal could appear behind the line` in
`tests/server/forest_stand.spec.luau` asserts `Data.REST.restockSeconds == nil` and would have to go
with it.
