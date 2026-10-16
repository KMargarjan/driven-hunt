# Archived: the shop's "RIFLE, OPEN" row (task 196)

**Karen, 2026-10-16 ~16:10, looking at the new shop:** *"remove rifle without scope soon don't
need"*.

She had already taken the WEAPON out in task 148 (*"please remove rifle without scope so we don't
implement now"*, archived with its pose set in `backups/2026-10-10-rifle-open-sights.md`). Task 178
kept a **shop row** for it anyway, with `sale = false`, so the ladder she had accepted would show all
four rungs and nobody would think it was shorter than it is. The new two-column panel made that
decision visible — the first thing the shop opened on was a page headed SOON — and she removed it.

So the row is gone from `src/shared/Shop/init.luau`: `Shop.ITEM.RIFLE_OPEN`, the `Shop.ROWS` entry
below, and its place in `Shop.ORDER`. The catalogue is four rows now, and every one of them is for
sale.

## The row, as it stood at `5d11e44`

```lua
Shop.ITEM.RIFLE_OPEN = "rifle.open"

[Shop.ITEM.RIFLE_OPEN] = {
	id = Shop.ITEM.RIFLE_OPEN,
	label = "RIFLE, OPEN",
	category = "weapon",
	blurb = "The same bolt rifle with the glass off, on iron sights. Not in this build yet.",
	price = 600,
	hunts = 10,
	-- NOT FOR SALE IN THIS BUILD, AND THE INVARIANT FORCES IT RATHER THAN A COMMENT ASKING FOR
	-- IT. KAREN TOOK THIS WEAPON OUT IN TASK 148 ...
	sale = false,
	grants = { weapon = "rifleOpen" },
} :: Row,

-- in Shop.ORDER, between the beater's licence and the scoped rifle:
Shop.ITEM.RIFLE_OPEN,
```

## What was NOT removed, and why

`Row.sale`, `Shop.REASON.NOT_SALE`, `Shop.ORDER_OF_REFUSAL`'s entry for it and the panel's `SOON`
badge all stay. They are not that row's machinery: `sale` is the switch invariant **I3** turns on
(`Shop.rowsOk`: *a row for sale can actually be granted*), which is what makes the note's *"selling a
thing that grants nothing is the one failure this repository would not forgive"* structural rather
than a comment. With this row gone, **no row in the catalogue sets `sale = false`**, and the
refusal's cases are driven in `tests/server/shop.spec.luau` against a pretend catalogue instead of
against a shipped row.

To put a rung back on the wall before it ships: add the row with `sale = false` again. Nothing else
has to come back with it.
