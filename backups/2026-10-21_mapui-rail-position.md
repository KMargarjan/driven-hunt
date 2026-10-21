# Archived: `MapUi.applyLayout` wrote the rail frame's Position (task 165 → task 220)

Archived 2026-10-21 by the Builder, task 220. Removed from `src/client/Hud/MapUi.luau` at commit
`aa47adbb` (the parent of the task-220 code commit). Rule 7: never delete, archive with a note.

## What it was

Three lines inside `MapUi.applyLayout`, plus the module-level `railFrame` local and the `rail` field
of `MapUi.start`'s `frames` table:

```lua
local railFrame: Frame? = nil
...
	railFrame = frames.rail
...
	-- THE BUTTON RAIL HANGS UNDER THE DISC, AND ITS TOP COMES FROM THE RENDERED DIAMETER (task 165)
	-- -- which is what `diameter` is now that the `UIScale` is the one writer of it. 150 on a screen
	-- and 96 on a phone, so a FIXED top would either sit on the disc or leave a hole. This writes the
	-- rail's POSITION only; `Hud.Rail` is the one writer of everything inside it, including its size.
	--
	-- (This is where the old touch button's two lines were. Same arithmetic, one node further down
	-- the screen -- see `backups/2026-10-12_mapui-touch-button.txt`.)
	local rail = railFrame
	if rail ~= nil then
		rail.Position = UDim2.new(1, -config.MINIMAP_MARGIN, 0, config.MINIMAP_TOP + diameter + 8)
	end
```

## Why it is gone

Task 220 makes the rail **fold into two columns** when a landscape phone's viewport cannot hold one
(`Rail.columnsFor`, `Rail.floorFor`, `Rail.applyLayout`). Before the fold, at 800 × 400,
`Rail.topFor(96, 140)` = 244 and `Rail.heightFor(4)` = 216 put the rail's bottom at **510 on a 400 px
tall screen**: RELOAD and AMMO were simply off the bottom of the phone.

A clamp cannot live in two modules. `MapUi` knew the minimap's rendered diameter, so it wrote the
rail's top; it did **not** know how far down the rail could reach, how many columns it needed, or
how wide it therefore was. Had both stayed, `Rail.rect` (pure, exported, what the no-overlap spec
measures) and the drawn frame would have been free to disagree — and the whole value of the pure
rectangle functions is that they cannot.

So this is a **second writer removed, not one added**. `Rail.applyLayout(viewport, diameter,
minimapTop, floorY)` performs the same arithmetic — `Rail.topFor(diameter, MINIMAP_TOP)`, which
`MapUi` was recomputing by hand as `MINIMAP_TOP + diameter + 8` beside it — and `MapUi` is now
**told** the resulting column width through `MapUi.setRailColumn(px)` so the full map clears a
folded rail (124 px) instead of the constant 68.

`MapUi.CONFIG.RAIL_COLUMN_PX` stays, as the default and as the answer for every viewport that does
not fold; `hud_clarity.spec`'s identity against `Rail` now reads `Rail.columnPx(1)`.

## How to bring it back

Restore the three blocks above, delete `Rail.applyLayout`, `Rail.floorFor`, `Rail.columnsFor`,
`Rail.layoutFor`, `Rail.widthFor`, `Rail.columnPx`, `Rail.slotFor` and `Rail.CONFIG.MAX_COLUMNS`,
and pass `rail = railFrame` back into `MapUi.start`. The cost of doing so is two unreachable rail
buttons on every landscape phone, which is what this task existed to fix.

Design: `docs/design/mobile-controls.md` section 5.6. Note:
`docs/research/2026-10-20-mobile-controls.md` section 5.
