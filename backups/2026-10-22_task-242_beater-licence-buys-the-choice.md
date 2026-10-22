# Archived: "the BEATER LICENCE buys the choice" (task 242, first cut, 2026-10-22)

Rule 7: nothing is deleted, it is archived with a note. The code below was
committed as `65745639` and reverted the same day on Karen's own clarification.

## What it was

A player holding EITHER the `ALWAYS HUNTER` card or the `BEATER LICENCE` could
choose his side on the truck pad. Four pieces, all reverted:

```luau
-- src/shared/Shop/init.luau
function Shop.grantsRoleChoice(owned: { [string]: boolean }?): boolean
    if owned == nil then
        return false
    end
    return Shop.grantsAlwaysHunter(owned) or Shop.grantsDriveGun(owned)
end

-- src/server/Economy/init.luau: a second frozen memo beside `alwaysHunters`,
-- projected off the same `ownedSets` through `ShopData.grantsRoleChoice` and
-- invalidated by the same call.
function Economy.roleChoosers(): { [number]: boolean } ... end

-- src/server/Lobby/init.luau: `setAlwaysHunters` renamed `setRoleChoosers`,
-- and the module-local reader renamed with it.

-- src/server/Match/Roster.luau: `assign` drew its `wishers` list from the
-- `beaters` argument WHOEVER made the wish, instead of only from `always`:
if always ~= nil or beaters ~= nil then
    for _, userId in ipairs(ids) do
        if beaters ~= nil and beaters[userId] == true then
            table.insert(wishers, userId)
        elseif always ~= nil and always[userId] == true then
            table.insert(holders, userId)
        end
    end
end
-- ...and an unhonoured wisher who owned nothing fell through to `rest` rather
-- than into `holders`.
```

Plus the four spec cases that asserted it: `shop.spec` ("lets a man choose his
side with EITHER card"), `economy.spec` ("projects WHO MAY CHOOSE HIS SIDE"),
`match_roster.spec` ("DOES read a wish from a man who owns nothing"), and the
`lobby_live.spec` rename.

## Why it was built

Karen, 2026-10-22, verbatim: *"in nex drive I can't select beater but I have
this license fix it"*. Read as: the card she holds is the BEATER LICENCE, whose
blurb is *"a beater may carry a gun in the drive"*, so a licence to beat in a
game that never deals you the beater's side is worth nothing.

## Why it went

Karen clarified the same day, verbatim:

> *"when you have a card always hunter technically you can choose to be what you
> ant eather beater or hunter / so it give you an option to select othervise by
> default if you don't have once time you hunter one time beater"*

So the rule is the one task 229 already built, and the first cut widened it
wrongly:

* **`ALWAYS HUNTER` is the card that buys the CHOICE.** Its owner picks HUNTER
  or BEATER per drive, from the pad switch.
* **The `BEATER LICENCE` stays what the shop says it is** -- a beater may carry
  a gun. It buys no say in which side you are on.
* **Without a card the default is to ALTERNATE**: one drive hunter, the next
  beater. Measured and found already true at every roster size
  (`match_roster.spec`, "ALTERNATES every player, drive after drive").

## What was KEPT from the same commit

The solo rule, which Karen's clarification explicitly keeps: an `ALWAYS HUNTER`
owner who chooses BEATER on a `1 / 1` bot pad now beats. Task 229 refused that
because `driverSlots` is 0 at one player; a roster of ONE cannot make
`|Drivers - Shooters|` exceed 1 either way, so the balance rule has no opinion,
and `Bots.Fill.counts` fills the stands with bot hunters.

## If it ever comes back

It would need Karen to say so. She has said the opposite, in her own words,
quoted above.
