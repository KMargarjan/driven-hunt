# Archived: the RED HAT's shop row (task 221, 2026-10-20)

Rule 7: never delete, archive with a note.

## Why

Karen, 2026-10-20 ~08:30, verbatim:

> "From shop remove red heat"

The red hat was the cosmetic the shop opened with (task 178): 80 coins, no hunt gate, the cheapest
thing on the shelf and *"the first thing a player can actually buy, which is what makes the shop
read as a shop"*. Her v1 catalogue has no cosmetic in it, so it comes off the shelf.

## What actually happened to it, and why it is NOT deleted

**The row is still in the build.** It moved verbatim into `Shop.RETIRED` in
`src/shared/Shop/init.luau`, with `sale = false` written over it, and `Shop.ALL_ORDER` names it
after everything that is for sale.

That is a requirement and not a courtesy. The id `hat.red` is already in live `owned` sets, and
`Shop.hatColorFor` reads the hat out of the iteration order — so **deleting the row would have
silently turned a bought hat back to orange** and taken away a thing somebody paid 80 for. All
eight readers of what ownership gives iterate `ALL_ORDER`, so a man who owns one keeps wearing it.

What changed for everybody else:

* `Shop.ORDER` no longer names it, so `rowsFor`, `groups` and `menuOrder` never see it — it is
  **invisible to the panel**;
* `Shop.row` no longer finds it, so `Shop.refuse`, `Economy.purchase` and `Economy.grant` all answer
  `Shop.REASON.UNKNOWN` — it is **unbuyable at the door**. `ServerScriptService.Shop` counts one of
  these as `stats.retiredItems`, apart from a forged packet, because a stale client after a
  catalogue change is a different fact;
* `Shop.CATEGORY.CLOTHING` **stays declared** with no row on it. `Shop.groups` drops an empty shelf
  rather than drawing a header with nothing under it, so it disappears from the panel by itself —
  and the category has to stay, because this row carries it and because clothing comes back.

`tests/server/shop.spec.luau` asserts every half of that: the hat still grants, it is not in
`ORDER`, it is refused `UNKNOWN`, and `rowsOk`'s I6 keeps the two tables disjoint.

## The row, as it stood before task 221

```luau
[Shop.ITEM.HAT_RED] = {
    id = Shop.ITEM.HAT_RED,
    label = "RED HAT",
    category = "clothing",
    blurb = "A dark red cap in place of the team's own orange. It changes how you look and nothing else.",
    -- A COSMETIC IS THE CHEAPEST THING IN THE SHOP, and at 80 it is one good drive: the first
    -- thing a player can actually buy, which is what makes the shop read as a shop.
    price = 80,
    hunts = 0,
    sale = true,
    -- DARK HUNTING RED, because hunter orange is already the team colour and a second orange hat
    -- would be invisible as a purchase (design section 16 item 2). Karen's to change.
    grants = { hatColor = Color3.fromRGB(150, 38, 32) },
} :: Row,
```

and its place in `Shop.ORDER`, which was first (cheapest):

```luau
Shop.ORDER = table.freeze({
    Shop.ITEM.HAT_RED,
    Shop.ITEM.SLUG,
    Shop.ITEM.BEATER_LICENCE,
    Shop.ITEM.RIFLE,
})
```

## Putting it back

Move the row from `Shop.RETIRED` to `Shop.ROWS`, set `sale = true`, add its id to `Shop.ORDER` in
price order, and take it out of `Shop.RETIRED_ORDER`. `Shop.ALL_ORDER` and `Shop.ITEM.HAT_RED` do
not change, and neither does any reader: `rowsOk`'s I6 is what will say if the two tables are left
disagreeing.

See also `backups/2026-10-16_task-196_shop-rifle-open-row.md`, the same thing done for the
open-sighted rifle's row at Karen's word.
