--!strict
-- Shop: THE CATALOGUE AND THE RULES OF BUYING -- frozen data plus pure functions. One row per item,
-- no writer, no state, no service, no clock, no remote, no Player: every fact about a player is a
-- parameter. The shape `ReplicatedStorage.Licences` and `ReplicatedStorage.Weapons` already ship,
-- and the reason `Weapons`'s own header gives for refusing a registry: *"a weapon that forgot to
-- register is a weapon that silently does not exist"*.
--
-- KAREN, verbatim:
--   2026-10-13: *"Hunting house where inside can shop things"*
--   2026-10-10, her design doc: *"There are houses where can buy weapons, License, Gear, Goods"*
--   2026-10-10: *"Rifle they has to purchase default is double barrel shotgun"*, and *"They will
--   have posibility to purchase rifle but has to play a lot it's not few hunts"*
--   2026-10-10: a beater *"can purchase license to shoot in drive"*, and *"buy packages for
--   outfit"*
--   2026-10-10, the ladder she accepted with *"yes that seems legit"*: shotgun buckshot (default)
--   -> slugs -> open-sight rifle -> scoped rifle.
--
-- IT IS SHARED AND NOT SERVER-ONLY, for `Licences`'s own stated reason: the PANEL that prints a
-- price and the SERVER that charges it must read ONE table, or a shop window is a second opinion
-- about what things cost -- which is this project's named failure mode
-- (docs/PROJECT_CONTEXT.md: *"Most of the worst bugs were two correct pieces of code
-- disagreeing"*). A client that knows the prices learns nothing it is not already shown.
--
-- WHAT IS NOT HERE AND MAY NOT COME HERE: a balance, an ownership set, a hunt count, a coin rate, a
-- remote, a Player. The profile is `ServerScriptService.Economy`'s, the door is
-- `ServerScriptService.Shop`'s, and the coin RATES stay unreplicated in `Economy.CONFIG`.
--
-- Pattern: a static literal item table read by both sides (ioquake3's `bg_itemlist`,
-- `code/game/bg_misc.c`); ownership as a SET the loadout reads rather than a copy of the thing
-- owned (`ps->stats[STAT_WEAPONS] |= 1 << weapon`, `code/game/g_items.c`); and a purchase that is
-- TESTED before it is EXECUTED, the refusal carried as DATA rather than thrown, with the number its
-- line needs (OpenTTD's `CommandCost`, `src/command_type.h`) -- the shape `Weapon.Rules` adopted in
-- task 171.
--   https://github.com/ioquake/ioq3        (GPL-2.0)
--   https://github.com/OpenTTD/OpenTTD     (GPL-2.0)
--
-- Design: docs/design/shop.md (sections 4, 6)
-- Note:   docs/research/2026-10-14-the-shop.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
-- THE ONE FORMATTER OF MONEY (task 221). `Shop.NOTICE[POOR]` and `CONFIG.TEXT.POOR_BUTTON` are two
-- places the SERVER formats a number a player reads, so the symbol has to be reachable from here.
-- `Money` requires nothing, so there is no cycle.
local Money = require(ReplicatedStorage:WaitForChild("Money"))

local Shop = {}

-- ---------------------------------------------------------------- the flag

-- THE FLAG'S NAME LIVES IN THE SHARED MODULE and `Shop.isOn()` is the one read, which is
-- `Weapons.FLAG` + `Weapons.loadout()` verbatim (design section 3). Each owner calls it ONCE at its
-- own boundary and passes the value inward, so both branches stay reachable by parameter while the
-- row sits at `false`.
Shop.FLAG = "SHOP"

function Shop.isOn(): boolean
	return Flags.isOn(Shop.FLAG)
end

-- ---------------------------------------------------------------- the rows

export type Grants = {
	ammo: string?, -- an `AmmoKind` the shotgun may be issued: "Slug"
	weapon: string?, -- a `Weapons.ROWS` key: "rifle"
	driveGun: boolean?, -- a BEATER may carry a gun in a drive
	hatColor: Color3?, -- the cosmetic
	-- THE FOUR KAREN ADDED ON 2026-10-20, each read by ONE pure function below and by an owner that
	-- already exists (design section 5.1). `Shop.GRANT_FIELDS` is the list, and a ninth field that
	-- is not in it fails the harness rather than going quietly unread.
	highSeat: boolean?, -- he may be DEALT one of task 218's high seats
	unlimitedAmmo: boolean?, -- the 12-shells-per-drive allowance does not bind
	licence: string?, -- a `Licences.ROWS` key he may shoot: "reddeer"
	alwaysHunter: boolean?, -- he is owed `Shooters` every drive
}

export type Row = {
	id: string,
	label: string, -- what the panel prints
	-- WHICH SHELF IT SITS ON (task 196). Karen, 2026-10-15: *"menus for buying things has to be
	-- better more nicer like side menu with click and then shows in right side image and explanation
	-- what is that"*. A side menu with four shelves needs the shelf written down beside the price,
	-- for `Shop.CONFIG.TEXT`'s own rule -- and `Shop.rowsOk` refuses a row whose shelf is not one of
	-- `Shop.CATEGORY`, so a sixth item cannot land in a group nothing draws.
	category: string, -- one of `Shop.CATEGORY`
	-- WHAT IT DOES IN THE GAME, in the player's own words, for the detail pane to read out. Karen
	-- asked for the *"explanation what is that"* and this is it: one or two sentences, and EVERY
	-- NUMBER IN ONE IS A NUMBER THIS REPO ALREADY MEASURED (the slug's 330 studs and the buckshot's
	-- 100, `Shotgun.CONFIG.RANGE_STUDS`; the rifle's 800, `Rifle.CONFIG.RANGE_STUDS`; at 0.28 m per
	-- stud, which is `Map.CONFIG`'s scale). A shop window that invents a ballistic claim is a shop
	-- window that lies, and this game's own code is the one thing that can check it.
	blurb: string,
	price: number, -- coins. Karen's, and hers to retune
	hunts: number, -- completed hunts before it unlocks
	-- false = shown and NOT buyable. NO ROW SETS IT TODAY (task 196 removed the one that did), and
	-- it stays because it is the switch invariant I3 turns on -- `Shop.rowsOk` refuses a row that is
	-- for sale and grants something no build ships, which is what makes *"selling a thing that
	-- grants nothing is the one failure this repository would not forgive"* structural. A rung
	-- announced before it ships is one row with `sale = false` again.
	sale: boolean,
	grants: Grants,
	-- A BUNDLE'S PARTS, and nil on every ordinary row. A bundle carries NO hand-written `grants`:
	-- they are the MERGE of the covered rows', computed once at module load by `Shop.mergedGrants`
	-- and frozen with everything else, so a bundle and its parts can never disagree about what it
	-- contains. Pattern: Odoo's phantom bill of materials (LGPL-3.0) -- a kit defined only by the
	-- list it explodes into -- with entitlements where Odoo has stock.
	covers: { string }?,
	-- THE ROBUX PRODUCT, AND IT IS nil ON EVERY ROW IN THIS BUILD (task 222 needs Karen's Creator
	-- Dashboard). `rowsOk`'s I12 asserts a non-nil one is a positive integer and that every row's
	-- is nil today: there are no products yet, and a fabricated id is a shop window that lies.
	--
	-- THE ROBUX PRICE IS NOT HERE and will not be: Roblox is where a product's price can be changed
	-- without a deploy, so a price in this table is a price that will one day be wrong.
	robuxProductId: number?,
}

-- `grants` IS THE ONE INVENTED THING IN THIS FILE and rule 2 wants the reason: no source has this
-- game's weapon ids in it. It is five rows of data read by four functions that already exist, which
-- is the note's section 2.4 (*"ownership is a set the loadout reads"*) with our names in it.
Shop.ITEM = table.freeze({
	SLUG = "ammo.slug",
	BEATER_LICENCE = "licence.beater",
	-- RETIRED AT KAREN'S WORD, 2026-10-20: *"From shop remove red heat"*. The id STAYS, because the
	-- row stays: it is in live `owned` sets and must keep granting (`Shop.RETIRED` below).
	HAT_RED = "hat.red",
	-- THERE IS NO `RIFLE_OPEN` SINCE TASK 196. Karen, 2026-10-16: *"remove rifle without scope soon
	-- don't need"* -- she had taken the WEAPON out in task 148 and task 178 kept a `sale = false`
	-- row so her ladder would show all four rungs. The two-column panel made that decision visible
	-- (the shop opened on a page headed SOON) and she removed it. The row is archived in
	-- `backups/2026-10-16_task-196_shop-rifle-open-row.md` (rule 7).
	RIFLE = "rifle.scoped",
	-- KAREN'S v1 LIST, 2026-10-20 (task 221).
	HIGH_SEAT = "access.highseat",
	UNLIMITED_AMMO = "ammo.unlimited",
	RED_STAG = "licence.reddeer",
	ALWAYS_HUNTER = "role.alwayshunter",
	BUNDLE_HIDE = "bundle.hide",
	BUNDLE_MARKSMAN = "bundle.marksman",
	BUNDLE_SEASON = "bundle.season",
})

-- EVERY FIELD OF `Grants`, AS DATA (task 221). `rowsOk` used to enumerate four of them by hand to
-- ask *"does this row grant anything"*, and with eight that line is a bug waiting for a ninth.
--
-- BOTH DIRECTIONS ARE ASSERTED, and the second one is the half that catches the omission:
-- `Shop.grantsAnything` loops this list, AND `shop.spec` asserts that every key appearing in any
-- row's `grants` is IN this list. A list that only validated downward would pass while a new field
-- sat invisible to `grantsAnything` -- the silence `Weapons`'s header refuses a registry for
-- (*"a weapon that forgot to register is a weapon that silently does not exist"*).
Shop.GRANT_FIELDS = table.freeze({
	"ammo",
	"weapon",
	"driveGun",
	"hatColor",
	"highSeat",
	"unlimitedAmmo",
	"licence",
	"alwaysHunter",
})

-- PURE. Does this row hand over anything at all? A row that grants nothing is a row that charges
-- for nothing.
function Shop.grantsAnything(grants: any): boolean
	if type(grants) ~= "table" then
		return false
	end
	for _, field in ipairs(Shop.GRANT_FIELDS) do
		if (grants :: any)[field] ~= nil then
			return true
		end
	end
	return false
end

Shop.ROWS = {
	[Shop.ITEM.SLUG] = {
		id = Shop.ITEM.SLUG,
		label = "SLUG SHELLS",
		category = "ammo",
		-- 330 studs and 100 studs are `Shotgun.CONFIG.RANGE_STUDS`, and 0.28 m per stud is the map's
		-- own scale: 92 m and 28 m. Rounded DOWN to 90 and 28 rather than invented.
		blurb = "One heavy ball instead of nine pellets: it carries to about 90 m where buckshot is "
			.. "spent by 28. A pocket of them every hunt.",
		-- A drive pays 10 to ~105 (docs/design/economy.md section 8), so ~3 drives.
		price = 120,
		hunts = 0,
		sale = true,
		-- THE SECOND RUNG OF THE LADDER. The shotgun already KNOWS this shell
		-- (`Weapons.ROWS.shotgun.AMMO_KINDS`); what the shop sells is the per-drive ALLOWANCE of it,
		-- so nothing about the gun, its pattern or its range is decided here.
		grants = { ammo = "Slug" },
	} :: Row,
	[Shop.ITEM.BEATER_LICENCE] = {
		id = Shop.ITEM.BEATER_LICENCE,
		label = "BEATER LICENCE",
		category = "licence",
		blurb = "A beater may carry a gun in the drive. The safety rule still holds: a shot toward "
			.. "the line ties you to a tree.",
		price = 250,
		-- He must have walked a few drives before he may carry a gun in one.
		hunts = 3,
		sale = true,
		-- IT BUYS HIM A GUN, NOT AN EXEMPTION. `Rules.beaterInLine` still refuses him a shot AT a
		-- beater and `Match.Penalty.judge` still ties him for an unsafe one -- that file already
		-- anticipated this exact day (*"It cannot happen in v1 (a driver carries no gun) but it can
		-- the day `DRIVERS_MAY_SHOOT` is true, and the design says there is no exception to write
		-- then"*).
		grants = { driveGun = true },
	} :: Row,
	[Shop.ITEM.HIGH_SEAT] = {
		id = Shop.ITEM.HIGH_SEAT,
		label = "HIGH SEAT ACCESS",
		category = "access",
		-- THE SENTENCE IS WRITTEN AGAINST WHAT IS BUILT, which is `rowsOk`'s I3 spirit applied to
		-- prose: in the Forest Test the placement is only where he STARTS, and an unentitled hunter
		-- can still walk to a seat in the pick window and climb the engine's own ladder (design
		-- section 6.6, the Director's D-2). *"Only you may climb it"* would be the shop lying.
		blurb = "You are given one of the wooden high seats on the line when one is free.",
		-- A PRIVILEGE, NOT A WEAPON: dearer than a licence, well under the rifle. ~15 drives.
		price = 600,
		hunts = 5,
		sale = true,
		grants = { highSeat = true },
	} :: Row,
	[Shop.ITEM.RED_STAG] = {
		id = Shop.ITEM.RED_STAG,
		label = "RED STAG CARD",
		category = "licence",
		blurb = "Permission to shoot red stag. Coming with the animal: you cannot buy it yet.",
		-- THE PRICE IS SHOWN SO A PLAYER CAN PLAN, beside a row already tagged SOON whose refusal
		-- already reads "NOT IN THE GAME YET". A plan, not a promise (design section 9.1).
		price = 750,
		hunts = 0,
		-- `sale = false`, AND IT IS FORCED RATHER THAN CHOSEN. `Licences.ROWS.reddeer.shipped` is
		-- false -- there is no red stag in this game -- and `rowsOk`'s I3a refuses a row that is for
		-- sale and grants a licence for a species nothing publishes. This is what `sale` was kept
		-- for when task 196 removed the last row that used it: *"A rung announced before it ships is
		-- one row with `sale = false` again"*. NEVER SELL WHAT DOES NOT WORK.
		sale = false,
		grants = { licence = "reddeer" },
	} :: Row,
	[Shop.ITEM.UNLIMITED_AMMO] = {
		id = Shop.ITEM.UNLIMITED_AMMO,
		label = "UNLIMITED AMMO",
		category = "ammo",
		-- 12 IS `Shotgun.CONFIG`'s own `DRIVE_SHELLS`, not a number invented here. The second
		-- sentence is the honest bound: this is the POCKET and not the gun (design section 7.1).
		blurb = "The twelve shells a drive gives you never run out. You still break and load.",
		-- IT REMOVES A CONSTRAINT EVERY DRIVE, so it costs more than the thing that changes one
		-- shell. ~22 drives.
		price = 900,
		hunts = 10,
		sale = true,
		grants = { unlimitedAmmo = true },
	} :: Row,
	[Shop.ITEM.RIFLE] = {
		id = Shop.ITEM.RIFLE,
		label = "RIFLE, SCOPED",
		category = "weapon",
		-- 800 studs is `Rifle.CONFIG.RANGE_STUDS` (224 m) against the slug's 330 (92 m), and three
		-- rounds is `Rifle.CONFIG.MAGAZINE`. Neither number is invented here.
		blurb = "Bolt action, three rounds, and a scope: it reaches about 220 m where the slug stops at 90.",
		-- *"has to play a lot it's not few hunts"*: ~37 drives of money at the rates
		-- `Economy.CONFIG` pays today, and 25 finished drives before it unlocks at all. UNCHANGED by
		-- task 221 -- the gate is Karen's own words and is not the Builder's to move.
		price = 1500,
		hunts = 25,
		sale = true,
		grants = { weapon = "rifle" },
	} :: Row,
	[Shop.ITEM.ALWAYS_HUNTER] = {
		id = Shop.ITEM.ALWAYS_HUNTER,
		label = "ALWAYS HUNTER",
		category = "access",
		-- THE BLURB SAYS THE LIMIT, because the limit is the design: Karen is selling a strong
		-- preference and not an exemption, and a man who read "always" and got a horn would read the
		-- purchase as broken (design section 8.1).
		blurb = "You keep the hunter's place every drive, unless the teams cannot be made even.",
		-- THE DEAREST SINGLE ITEM, because it is the only one that changes the drive for everybody
		-- else. ~50 drives.
		price = 2000,
		hunts = 30,
		sale = true,
		grants = { alwaysHunter = true },
	} :: Row,
}

-- ---------------------------------------------------------------- the bundles (task 221)
--
-- KAREN, 2026-10-20: *"We can also make a few packages bundles"*.
--
-- A BUNDLE IS AN ORDINARY ROW THAT NAMES THE IDS IT COVERS, AND CARRIES NO `grants` OF ITS OWN.
-- They are declared in their own table precisely so a hand-written grant is IMPOSSIBLE rather than
-- merely wrong: the merge loop below writes `grants` from `covers` at module load, and `rowsOk`'s
-- I11 asserts the two agree.
--
-- IT INVENTS NO MECHANISM. The eight readers of what ownership gives already answer off `grants`,
-- so a bundle grants the rifle to `Shop.ownsWeapon` and the slug to `Shop.startFor` with no change
-- to either. Pattern: Odoo's phantom bill of materials (LGPL-3.0): a kit defined ONLY by the list
-- it explodes into, so the kit and its parts cannot disagree about what it contains.
--
-- THE NAMES AND THE DISCOUNTS ARE KAREN'S TO MOVE (design section 17, K-1). Moving one must keep
-- I9 (`hunts >= max of the parts'`) and I10 (`price < sum of the parts'`), which is what stops a
-- bundle becoming the way round the ladder she set.
Shop.BUNDLES = {
	[Shop.ITEM.BUNDLE_HIDE] = {
		id = Shop.ITEM.BUNDLE_HIDE,
		label = "THE HIDE",
		category = "bundle",
		blurb = "A seat above the drive, and the shells for it.",
		-- 20% off 720.
		price = 575,
		hunts = 5,
		sale = true,
		covers = { Shop.ITEM.HIGH_SEAT, Shop.ITEM.SLUG },
	},
	[Shop.ITEM.BUNDLE_MARKSMAN] = {
		id = Shop.ITEM.BUNDLE_MARKSMAN,
		label = "THE MARKSMAN",
		category = "bundle",
		blurb = "The long gun, and shells you never run out of.",
		-- 25% off 2400.
		price = 1800,
		hunts = 25,
		sale = true,
		covers = { Shop.ITEM.RIFLE, Shop.ITEM.UNLIMITED_AMMO },
	},
	[Shop.ITEM.BUNDLE_SEASON] = {
		id = Shop.ITEM.BUNDLE_SEASON,
		label = "THE FULL SEASON",
		category = "bundle",
		-- 25 CHARACTERS AND NOT 45, AND IT IS MEASURED: `rowsOk` checks a bundle's COMPOSED blurb
		-- (its own sentence plus `INCLUDES: ...`) against `BLURB_MAX` 135, and this one composes to
		-- 127. `BLURB_MAX` does not move, so the Designer's measured box is untouched.
		blurb = "The whole season, in one.",
		-- 30% off 5370.
		price = 3750,
		hunts = 30,
		sale = true,
		covers = {
			Shop.ITEM.HIGH_SEAT,
			Shop.ITEM.SLUG,
			Shop.ITEM.UNLIMITED_AMMO,
			Shop.ITEM.RIFLE,
			Shop.ITEM.BEATER_LICENCE,
			Shop.ITEM.ALWAYS_HUNTER,
		},
	},
}

-- PURE and exported, so the merge is an assertion rather than a comment.
--
-- Returns nil plus a PROBLEM for a conflict -- two covered rows naming different values for a
-- single-valued field -- and NEVER a silent winner: `covers` order deciding what a bundle grants
-- would be a rule nobody wrote down. No bundle conflicts today (one ammo row, one weapon row); the
-- limitation is named -- a bundle cannot grant two shell kinds -- and widening `Grants.ammo` to a
-- set is the Director's (design section 17, D-3).
function Shop.mergedGrants(covers: { string }?): (Grants?, string?)
	if type(covers) ~= "table" then
		return nil, "covers is not a list"
	end
	local out: any = {}
	for _, id in ipairs(covers :: { string }) do
		local row = (Shop.ROWS :: any)[id] :: Row?
		if row == nil then
			return nil, string.format("covers %s, which has no row", tostring(id))
		end
		for _, field in ipairs(Shop.GRANT_FIELDS) do
			local value = (row.grants :: any)[field]
			if value ~= nil then
				if out[field] ~= nil and out[field] ~= value then
					return nil, string.format("two covered rows disagree about `%s`", field)
				end
				out[field] = value
			end
		end
	end
	return out :: Grants, nil
end

-- THE MERGE, ONCE, AT MODULE LOAD. After this loop a bundle is an ordinary row in `Shop.ROWS` and
-- nothing downstream knows the difference -- which is the whole point.
--
-- A CONFLICT IS LEFT AS AN EMPTY `grants` RATHER THAN THROWN: a module that errors on require takes
-- the whole place down, and `rowsOk`'s I11 turns the same mistake into a failing harness line that
-- names the bundle. The repo's own rule -- a catalogue mistake is a failing harness, not a crash.
for id, bundle in pairs(Shop.BUNDLES) do
	local merged = Shop.mergedGrants((bundle :: any).covers)
	local row: any = table.clone(bundle :: any)
	row.grants = merged or {}
	Shop.ROWS[id] = row :: Row
end

-- ---------------------------------------------------------------- what is no longer sold
--
-- KAREN, 2026-10-20: *"From shop remove red heat"*.
--
-- THE ROW STAYS IN CODE, AND THAT IS THE REQUIREMENT RATHER THAN A COURTESY. The id is already in
-- live `owned` sets, and `Shop.hatColorFor` reads the hat out of the iteration order -- so deleting
-- it would silently turn a bought hat back to orange and take away a thing somebody paid for.
-- Archived under `backups/2026-10-20_task-221_shop-red-hat-row.md` with a note (rule 7).
--
-- IT IS INVISIBLE TO THE PANEL AND UNBUYABLE AT THE DOOR: `Shop.ORDER` does not name it, so
-- `rowsFor`, `groups` and `menuOrder` never see it; `Shop.row` does not find it, so `Shop.refuse`,
-- `Economy.purchase` and `Economy.grant` all answer `UNKNOWN`. Only the eight readers of what
-- ownership GIVES iterate `ALL_ORDER`, and they are the ones that must keep answering.
Shop.RETIRED = {
	[Shop.ITEM.HAT_RED] = {
		id = Shop.ITEM.HAT_RED,
		label = "RED HAT",
		category = "clothing",
		blurb = "A dark red cap in place of the team's own orange. It changes how you look and nothing else.",
		price = 80,
		hunts = 0,
		-- WRITTEN OVER THE ROW AS IT WAS. `rowsOk`'s I6 asserts every retired row carries it.
		sale = false,
		-- DARK HUNTING RED, because hunter orange is already the team colour and a second orange hat
		-- would be invisible as a purchase (shop design section 16 item 2).
		grants = { hatColor = Color3.fromRGB(150, 38, 32) },
	} :: Row,
}

Shop.RETIRED_ORDER = table.freeze({
	Shop.ITEM.HAT_RED,
})

-- THE ORDER THE PANEL DRAWS, CHEAPEST FIRST, so the first thing a player with $120 sees is a thing
-- he can buy. A list rather than a `slot` field per row, for `Weapons.ORDER`'s stated reason: the
-- order is one fact and belongs in one place. Bundles are mixed in BY PRICE and not grouped here,
-- because the side menu regroups by shelf anyway (`Shop.groups`).
Shop.ORDER = table.freeze({
	Shop.ITEM.SLUG,
	Shop.ITEM.BEATER_LICENCE,
	Shop.ITEM.BUNDLE_HIDE,
	Shop.ITEM.HIGH_SEAT,
	Shop.ITEM.RED_STAG,
	Shop.ITEM.UNLIMITED_AMMO,
	Shop.ITEM.RIFLE,
	Shop.ITEM.BUNDLE_MARKSMAN,
	Shop.ITEM.ALWAYS_HUNTER,
	Shop.ITEM.BUNDLE_SEASON,
})

-- EVERY ID THIS BUILD KNOWS, FOR SALE OR RETIRED: `ORDER` then `RETIRED_ORDER`. A DECLARED list and
-- not a concatenation recomputed at each read, for `Shop.ORDER`'s own stated reason -- the order is
-- one fact and belongs in one place.
--
-- WHO ITERATES WHICH, and this is the interface (design section 5.3):
--   `ALL_ORDER` -- all eight readers of what ownership GIVES. A retired row must keep granting.
--   `ORDER`     -- `rowsFor`, `groups`, `menuOrder`. Invisible to the panel.
--   `ROWS` only -- `Shop.row`, and therefore `refuse`, `purchase` and `grant`. Unbuyable.
Shop.ALL_ORDER = table.freeze({
	Shop.ITEM.SLUG,
	Shop.ITEM.BEATER_LICENCE,
	Shop.ITEM.BUNDLE_HIDE,
	Shop.ITEM.HIGH_SEAT,
	Shop.ITEM.RED_STAG,
	Shop.ITEM.UNLIMITED_AMMO,
	Shop.ITEM.RIFLE,
	Shop.ITEM.BUNDLE_MARKSMAN,
	Shop.ITEM.ALWAYS_HUNTER,
	Shop.ITEM.BUNDLE_SEASON,
	Shop.ITEM.HAT_RED,
})

-- ---------------------------------------------------------------- the four shelves (task 196)
--
-- KAREN, 2026-10-15 ~17:40: *"menus for buying things has to be better more nicer like side menu
-- with click and then shows in right side image and explanation what is that"*. A side menu with
-- headers needs the shelves and their ORDER written down once, here, where the prices already are.
--
-- THE ORDER IS THE DIRECTOR'S DISPATCH, NOT THE PRICE: Weapons, Ammo, Licences, Clothing. It is a
-- SECOND order over the same rows and not a replacement for `Shop.ORDER` -- the wire still arrives
-- cheapest-first, `Shop.ORDER` is still what the server iterates, and the grouping is a pure
-- function of what arrived. One list, read two ways, so a row can never be in one and not the other.
--
-- SIX SHELVES SINCE TASK 221. `ACCESS` is new because a high seat and an always-hunter place are
-- neither a weapon, a shell, a permit nor clothing; `BUNDLE` is new because `Shop.rowsOk`'s I4
-- refuses a row whose shelf is not declared and `Shop.groups` would otherwise silently drop it.
Shop.CATEGORY = table.freeze({
	WEAPON = "weapon",
	AMMO = "ammo",
	LICENCE = "licence",
	ACCESS = "access",
	CLOTHING = "clothing",
	BUNDLE = "bundle",
})

-- PACKAGES IS LAST, and that is Karen's own word: *"We can ALSO make a few packages bundles"*. It
-- is also the safer order -- the panel opens on the first item he may actually buy and falls back
-- to the first row in the menu, and a shop that opens on a page headed LOCKED is the defect task
-- 196 fixed by looking at it.
--
-- CLOTHING STAYS DECLARED WITH NO ROW ON IT. `Shop.groups` drops an EMPTY shelf rather than drawing
-- a header with nothing under it, so it disappears from the panel by itself; the category stays
-- because the RETIRED hat carries it and because clothing comes back.
Shop.CATEGORY_ORDER = table.freeze({
	Shop.CATEGORY.WEAPON,
	Shop.CATEGORY.AMMO,
	Shop.CATEGORY.LICENCE,
	Shop.CATEGORY.ACCESS,
	Shop.CATEGORY.CLOTHING,
	Shop.CATEGORY.BUNDLE,
})

-- THE HEADER THE PANEL PRINTS, which is `Shop.CONFIG.TEXT`'s own rule -- every word written down.
Shop.CATEGORY_LABEL = table.freeze({
	[Shop.CATEGORY.WEAPON] = "WEAPONS",
	[Shop.CATEGORY.AMMO] = "AMMO",
	[Shop.CATEGORY.LICENCE] = "LICENCES",
	[Shop.CATEGORY.ACCESS] = "ACCESS",
	[Shop.CATEGORY.CLOTHING] = "CLOTHING",
	[Shop.CATEGORY.BUNDLE] = "PACKAGES",
})

export type Group = { category: string, label: string, rows: { WireRow } }

-- THE SIDE MENU, GROUPED. PURE and exported, for `Shop.rowsFor`'s own stated reason: what the panel
-- draws is a function of what arrived and the panel decides nothing. An EMPTY shelf is dropped
-- rather than drawn as a header with nothing under it, and a row whose `category` is not one of the
-- four is dropped by the loop and caught by `Shop.rowsOk` -- so a catalogue mistake is a failing
-- harness rather than an item nobody can see. The rows inside a shelf keep the order they arrived
-- in, which is `Shop.ORDER`'s cheapest-first.
function Shop.groups(rows: { WireRow }?): { Group }
	local out: { Group } = {}
	for _, category in ipairs(Shop.CATEGORY_ORDER) do
		local kept: { WireRow } = {}
		for _, row in ipairs(rows or {}) do
			if row.category == category then
				table.insert(kept, row)
			end
		end
		if #kept > 0 then
			table.insert(out, { category = category, label = Shop.CATEGORY_LABEL[category], rows = kept })
		end
	end
	return out
end

-- EVERY ROW THE SIDE MENU DRAWS, IN THE ORDER IT DRAWS THEM -- the headers dropped. The panel's
-- selection is an item ID and never an index (task 196), and this is the list that says which id is
-- FIRST: what a freshly opened panel shows before anything is clicked.
function Shop.menuOrder(rows: { WireRow }?): { string }
	local out: { string } = {}
	for _, group in ipairs(Shop.groups(rows)) do
		for _, row in ipairs(group.rows) do
			table.insert(out, row.id)
		end
	end
	return out
end

-- ---------------------------------------------------------------- the words and the numbers

Shop.CONFIG = {
	-- 8 -> 12 (task 221). Ten rows ship; twelve so the next one needs no second decision.
	--
	-- THE OLD SENTENCE HERE READ *"One panel, no scrolling, no paging"* AND IT WAS ALREADY STALE:
	-- since task 196 the wide well is a `ScrollingFrame` with `AutomaticCanvasSize.Y` and the tall
	-- strip scrolls in X. `shop.spec` asserts the catalogue against this number.
	MAX_ITEMS = 12,
	-- HOW LONG A ROW'S NAME MAY BE. The shop design has stated this bound since task 178 and nothing
	-- asserted it; `rowsOk`'s I2a does now, because six of the ten rows are new labels. The longest
	-- today is `HIGH SEAT ACCESS` at 16.
	LABEL_MAX = 18,
	-- HOW CLOSE TO THE COUNTER HE HAS TO BE. The counter is 12 studs wide
	-- (`Lobby.CONFIG.LODGE.COUNTER`), so 14 lets a man at either end of it reach.
	REACH_STUDS = 14,
	-- The door's rate limit: 4 requests/second/player. A person cannot press a button four times a
	-- second, so this is a forgery guard and not a game rule.
	REQUEST_MIN_INTERVAL = 0.25,
	-- A bound BEFORE the table lookup, so a 4 MB string cannot be used as a key.
	MAX_ID_CHARS = 32,
	-- 48 px, `Rail.CONFIG.BUTTON_PX`, over the 44 px Roblox's own tutorial sets as a touch button's
	-- minimum height.
	BUTTON_PX = 48,
	-- THERE IS NO `AUTO_OPEN` ANY MORE, AND ITS ABSENCE IS THE TASK (181). Task 178 opened this
	-- panel by itself when the player came within `REACH_STUDS` of the counter. Karen, 2026-10-14:
	-- *"in lobby has to be a person bot who you need to click E to get access to shop"* -- so the
	-- shopkeeper's `ProximityPrompt` is the one way in, and a panel that was already open when you
	-- got there would make her key decorative. `REACH_STUDS` still CLOSES it, at the same distance
	-- the server refuses a purchase at. `tests/client/shop_panel.spec.luau` asserts both halves.
	-- THE SIDE MENU AND THE DETAIL PANE (task 196). Karen: *"side menu with click and then shows in
	-- right side image and explanation"*. Every number is a PIXEL and the panel's own
	-- `ShopPanel.layoutFor` is the ONE function that turns them into rectangles -- pure, so the
	-- phone-sized case is an assertion rather than a screenshot (task 165's layout check).
	PANEL = {
		-- THE DESIGNER'S NUMBERS (the Designer's spec, 2026-10-16, section 3). Karen handed the look
		-- over -- *"give this to designer to decide how it should look"* -- and these are the pixels
		-- that came back. `ShopPanel.layoutFor` is still the ONE function that turns them into
		-- rectangles, and it is still pure, so the phone case is an assertion and not a screenshot.
		--
		--   margin = 12; width = clamp(screenW - 2*margin, 300, 640)
		--   height = clamp(floor(screenH * 0.80), 300, 640)
		--   mode   = width >= 520 and "WIDE" or "TALL"
		--
		-- 1280 x 720 -> 640 x 576 WIDE. 400 x 800 -> 376 x 640 TALL.
		MARGIN = 12,
		MIN_WIDTH = 300,
		MAX_WIDTH = 640,
		MIN_HEIGHT = 300,
		MAX_HEIGHT = 640,
		HEIGHT_FRACTION = 0.8,
		-- THE SPLIT BETWEEN THE TWO LAYOUTS, and it is a width and not a device: a 520 px panel can
		-- hold a 228 px list and a 260 px picture, and a narrower one cannot -- *"at 376 px the
		-- detail column would be 178 px wide. So the phone stacks"* (spec 3.4).
		WIDE_AT = 520,
		CORNER = 16,
		-- The header is the same 64 px in both modes (spec 3.2).
		HEADER_PX = 64,
		-- WIDE: the side-menu well and the detail column beside it (spec 3.3).
		WELL_X = 16,
		WELL_Y = 72,
		WELL_WIDTH = 228,
		WELL_BOTTOM = 24,
		WELL_PAD = 10,
		DETAIL_GAP = 16,
		ROW_PX = 60,
		SHELF_PX = 24,
		SHELF_GAP = 9,
		-- TALL: the horizontal strip of cards under the header (spec 3.4).
		STRIP_Y = 74,
		STRIP_PX = 82,
		CARD_WIDTH = 104,
		CARD_GAP = 8,
		STRIP_PAD = 16,
		-- 44 AND NOT 26 (task 196 part 3f). At 26 the hint was too narrow to read as "there is more"
		-- and the last card still looked CHOPPED -- which is what the Director read off the 400-wide
		-- frame. It is as wide as the gap between two cards plus a card's own padding now, so the
		-- card under it fades out instead of ending mid-word.
		STRIP_FADE = 44,
		-- THE DISPLAY CASE, and the floor under it is the spec's: *"take the difference off the
		-- display case, down to a floor of 110 px"*.
		CASE_WIDE_PX = 200,
		CASE_TALL_PX = 178,
		CASE_MIN_PX = 110,
		-- THE STACK UNDER THE CASE, as the gaps between one thing and the next (spec 3.3's table
		-- read as deltas, so the two modes are one arithmetic).
		EYEBROW_GAP = 12,
		EYEBROW_PX = 12,
		NAME_GAP = 14,
		NAME_PX = 30,
		PRICE_GAP = 38,
		PRICE_PX = 24,
		RULE_GAP = 36,
		BLURB_GAP = 14,
		LINE_PX = 21, -- the blurb's line height
		STATUS_PX = 14,
		STATUS_GAP = 26, -- the status line sits this far above the button (spec 4)
		BUTTON_PX = 56,
		BOTTOM_PX = 12,
		-- A TOUCH TARGET, UNCHANGED AND STILL THE RULE: the close button is 44 x 44, a row is 60, the
		-- one big button is 56. *"Never smaller, desktop included"* (spec 8.6).
		CLOSE_PX = 44,
		TAG_PX = 19,
		SCROLLBAR_PX = 3,
		-- The scrim over the whole screen behind the panel (spec 2).
		SCRIM_TRANSPARENCY = 0.42,
		-- HOW LONG AN EXPLANATION MAY BE. 135 still, and the Designer checked it against the new box:
		-- *"the new blurb box holds about 220 characters on a desktop and about 156 on a phone, so
		-- every sentence in the catalogue fits with room to spare"*. `Shop.rowsOk` refuses a longer
		-- one and the client spec asserts the phone still holds three whole lines.
		BLURB_MAX = 135,
		-- `Report.CONFIG.PANEL_Z_INDEX` is 15 and `Rail.CONFIG.Z_INDEX` is 16, so the rail stays
		-- pressable over this panel -- which is what lets a thumb reach the map while it is open.
		Z_INDEX = 15,
	},
	-- EVERY WORD THE PANEL DRAWS IS WRITTEN DOWN, which is `Drive.CONFIG`'s own rule.
	TEXT = {
		-- EVERY WORD THE PANEL DRAWS IS WRITTEN DOWN, which is `Drive.CONFIG`'s own rule -- and since
		-- the Designer's spec (2026-10-16, section 7) these are the words. `BALANCE` is gone: the
		-- wallet is two pills with a number and a caption each, so there is no sentence to format.
		-- `CLOSE_GLYPH` is gone too -- the X is two rotated Frames, so no glyph has to exist in a
		-- font for the panel to be closable.
		TITLE = "SHOP",
		EYEBROW = "HUNTING LODGE",
		-- TWO CAPTIONS AND NOT ONE (task 221). `COINS_CAP` was read in BOTH the wallet pill and the
		-- detail pane's PRICE line, and those are different facts -- *how much he has* and *what this
		-- costs*. A caption reading MONEY over a price would be the drift `Match.Penalty`'s own warning
		-- names (*"four questions in one predicate is how 'one predicate answered two unrelated
		-- questions' happened in the previous project"*). `shop_panel.spec` asserts the two differ.
		MONEY_CAP = Money.WORD,
		PRICE_CAP = "PRICE",
		HUNTS_CAP = "HUNTS",
		CLOSED = "THE SHOP IS CLOSED",
		BUY = "BUY",
		-- THE ROW'S TAGS. A row answers *"can I buy this?"* without being clicked (spec 0.3), and
		-- the affordability signal is never colour alone: a row you cannot afford says SHORT.
		OWNED_TAG = "OWNED",
		SOON_TAG = "SOON",
		ROW_LOCK_TAG = "%d / %d",
		-- `%s` AND NOT `%d` SINCE TASK 221: the number is money and `Money.text` is the one thing that
		-- formats it. A `%d` here would be a second place a `$` had to be remembered.
		ROW_POOR_TAG = "SHORT %s",
		-- THE BUTTON'S OWN WORDS, one per state (spec 4).
		OWNED_BUTTON = "IN YOUR KIT",
		LOCKED_BUTTON = "%d MORE HUNTS TO GO",
		POOR_BUTTON = "%s MORE",
		-- THE ONE MESSAGE SLOT, above the button: the caveat, the receipt and the refusal all read
		-- where the player is already looking (spec 4).
		HINT = "YOURS FROM THE NEXT HUNT",
		BOUGHT = "BOUGHT: %s",
		PICK = "PICK AN ITEM",
		-- WHAT A BUNDLE CONTAINS, APPENDED TO ITS OWN BLURB BY `Shop.rowsFor` (task 221), so the parts
		-- are on screen with no layout change and `ShopPanel` still *draws what arrived*. `rowsOk`
		-- checks the COMPOSED length against `BLURB_MAX` for a bundle, not the raw blurb.
		COVERS = "INCLUDES: %s",
	},
}

-- deepFreeze, REQUIRED and not copied: `table.freeze` is shallow and this repo has paid for that
-- once already (`src/shared/Drive/init.luau`, Task 23a note (b)).
-- ...AND THE DECLARED PACKAGES, which every other catalogue table already was (the Reviewer's
-- round-1 note). The merge loop clones them and the clones are frozen with `ROWS`, so this changes
-- no behaviour -- it keeps the module's own stated discipline that the rules of the game are not
-- writable at run time.
Shotgun.deepFreeze(Shop.BUNDLES)
Shotgun.deepFreeze(Shop.ROWS)
-- THE RETIRED TABLE IS FROZEN LIKE THE LIVE ONE. It is still read by all eight readers of what
-- ownership gives, so a caller that could edit it could edit the rules of the game at run time.
Shotgun.deepFreeze(Shop.RETIRED)
Shotgun.deepFreeze(Shop.CONFIG)

-- ---------------------------------------------------------------- what a weapon comes with
--
-- WHICH SHELL KINDS A WEAPON IS ISSUED WHEN NOTHING HAS BEEN BOUGHT. Karen: *"default is double
-- barrel shotgun"* with buckshot, and the slug is the first rung of her ladder.
--
-- A WEAPON WITH NO ROW HERE IS UNRESTRICTED, the default every gate in this repo takes
-- (`Rules.outsideStand`'s nil area): a weapon somebody adds later must not silently arrive with no
-- ammunition at all. AND THE RIFLE'S OWN SHELL IS FREE WITH THE RIFLE -- it is a 1500-coin
-- purchase, and selling a man a rifle and then no rounds for it would be the shop taking money for
-- nothing.
Shop.BASE_AMMO = table.freeze({
	shotgun = table.freeze({ Buck = true }),
	rifle = table.freeze({ Slug = true }),
})

-- ---------------------------------------------------------------- reads of the catalogue

-- WHAT IS FOR SALE, AND ONLY THAT. A RETIRED id answers nil here, which is what makes it
-- unbuyable: `Shop.refuse`, `Economy.purchase` and `Economy.grant` all ask this one and all answer
-- `Shop.REASON.UNKNOWN` for a row nobody may buy any more.
function Shop.row(id: any): Row?
	if type(id) ~= "string" then
		return nil
	end
	return (Shop.ROWS :: any)[id]
end

-- EVERY ROW THIS BUILD KNOWS, FOR SALE OR RETIRED (task 221). This is what the eight readers of
-- what ownership GIVES ask, because a retired row must keep granting to the people who bought it.
function Shop.anyRow(id: any): Row?
	if type(id) ~= "string" then
		return nil
	end
	local row = (Shop.ROWS :: any)[id]
	if row ~= nil then
		return row
	end
	return (Shop.RETIRED :: any)[id]
end

-- IS THIS A ROW THAT USED TO BE SOLD? `ServerScriptService.Shop` counts one of these apart from a
-- forged packet -- the split `Weapon` makes between `stats.refused` and `stats.badRequests` and
-- states the reason for: *"a stale client after a catalogue change is a different fact from a
-- forged packet"*. The REPLY is still `UNKNOWN`: a new wire reason would cost a notice and a panel
-- state for a row nobody can see.
function Shop.isRetired(id: any): boolean
	if type(id) ~= "string" then
		return false
	end
	return (Shop.RETIRED :: any)[id] ~= nil
end

-- Every item, in `Shop.ORDER`. A COPY, so a caller cannot edit the order of the game.
function Shop.ids(): { string }
	return table.clone(Shop.ORDER)
end

-- DOES HE OWN IT? `owned` is whatever the profile answered -- a set of item ids. What `nil` means
-- depends on WHO IS ASKING, and that is written down once, in `Shop.refuse` and in design section
-- 7.1: for the purchase it is "he owns nothing", for the four readers of what ownership GIVES it is
-- "nobody answered, so leave the game as it was".
function Shop.owns(owned: { [string]: boolean }?, id: any): boolean
	if owned == nil or type(id) ~= "string" then
		return false
	end
	return owned[id :: string] == true
end

-- DOES HE OWN THE ROW THAT GRANTS THIS WEAPON? The entitlement for a weapon id is the row whose
-- `grants.weapon` is that id, so `Weapons` asks this and never learns an item id.
function Shop.ownsWeapon(owned: { [string]: boolean }?, weaponId: any): boolean
	if owned == nil or type(weaponId) ~= "string" then
		return false
	end
	for _, id in ipairs(Shop.ALL_ORDER) do
		local row = Shop.anyRow(id) :: Row
		if row.grants.weapon == weaponId and owned[id] == true then
			return true
		end
	end
	return false
end

-- DOES HE OWN THIS, OR A BUNDLE THAT COVERS IT? PURE, and THE ONE ANSWER: it is used by
-- `Shop.refuse`'s OWNED question and by `Shop.rowsFor`'s `owned` field, so the window and the till
-- cannot disagree about whether he already has a thing (task 221).
--
-- WITHOUT IT THE SHOP CHARGES TWICE: a man who bought THE MARKSMAN would see RIFLE, SCOPED as not
-- owned and buyable, and pay $1500 for a thing he has. *"Selling a thing that grants nothing is the
-- one failure this repository would not forgive"* is `rowsOk`'s own sentence, and this is that
-- failure in the one case `rowsOk` cannot see.
--
-- IT IS NOT `Shop.owns`, AND THE TWO ARE NOT INTERCHANGEABLE: `Economy.grant`'s idempotency asks
-- `owns`, because a bundle covering a row is not that row and a receipt for that row must still
-- write it.
function Shop.ownedOrCovered(owned: { [string]: boolean }?, id: any): boolean
	if owned == nil or type(id) ~= "string" then
		return false
	end
	if owned[id :: string] == true then
		return true
	end
	for _, other in ipairs(Shop.ALL_ORDER) do
		if owned[other] == true then
			local row = Shop.anyRow(other)
			for _, covered in ipairs((row and row.covers) or {}) do
				if covered == id then
					return true
				end
			end
		end
	end
	return false
end

-- IS EVERY PART OF THIS BUNDLE ALREADY HIS? PURE. `Shop.refuse` asks it so a man who owns the whole
-- of a package is refused the package: the same predicate applied to the covers list, and it closes
-- "the shop takes money for nothing" in the one case `ownedOrCovered` alone does not.
--
-- FALSE for a row that is not a bundle, and false for an empty `covers`: "every part of nothing" is
-- a vacuous truth and would refuse a row nobody owns.
function Shop.fullyCovered(owned: { [string]: boolean }?, id: any): boolean
	local row = Shop.anyRow(id)
	local covers = row and row.covers
	if covers == nil or #(covers :: { string }) == 0 then
		return false
	end
	for _, covered in ipairs(covers :: { string }) do
		if not Shop.ownedOrCovered(owned, covered) then
			return false
		end
	end
	return true
end

-- IS THE CATALOGUE LEGAL? PURE and exported so the invariant is an assertion rather than a comment
-- (design section 4.2). It takes the weapon and licence tables as PARAMETERS, so this module
-- requires neither `Weapons` nor `Licences`: a shared module that required the weapon table to
-- validate itself would be a cycle the day `Weapons` reads this one -- which it does, for the
-- loadout.
--
-- I3 IS STILL THE ONE THAT MATTERS: a row for sale can actually be granted. It is what makes
-- *"Selling a thing that grants nothing is the one failure this repository would not forgive"*
-- structural. It FORCED `rifle.open`'s `sale = false` until task 196 removed that row at Karen's
-- word, and since task 221 its licence half (I3a) is what holds the RED STAG CARD shut: the animal
-- does not exist, so the row cannot go on sale, and that is arithmetic rather than a promise.
function Shop.rowsOk(weaponRows: any, ammoKinds: { string }?, licenceRows: any?): { string }
	local problems = {}
	local seen: { [string]: boolean } = {}
	if #Shop.ORDER > Shop.CONFIG.MAX_ITEMS then
		table.insert(
			problems,
			string.format("%d items declared, and MAX_ITEMS is %d", #Shop.ORDER, Shop.CONFIG.MAX_ITEMS)
		)
	end
	for _, id in ipairs(Shop.ORDER) do
		local row = (Shop.ROWS :: any)[id] :: Row?
		if row == nil then
			table.insert(problems, string.format("%s is in ORDER and has no row", id))
			continue
		end
		if seen[id] then
			table.insert(problems, string.format("%s is in ORDER twice", id))
		end
		seen[id] = true
		if row.id ~= id then
			table.insert(problems, string.format("%s carries the id %s", id, tostring(row.id)))
		end
		if type(row.price) ~= "number" or row.price < 0 or row.price % 1 ~= 0 then
			table.insert(problems, string.format("%s has a price of %s", id, tostring(row.price)))
		end
		if type(row.hunts) ~= "number" or row.hunts < 0 or row.hunts % 1 ~= 0 then
			table.insert(problems, string.format("%s has a hunt gate of %s", id, tostring(row.hunts)))
		end
		-- I2a (task 221): THE LABEL FITS. The bound has been stated since task 178 and nothing
		-- asserted it; six of the ten rows are new labels.
		if type(row.label) ~= "string" or #row.label == 0 or #row.label > Shop.CONFIG.LABEL_MAX then
			table.insert(
				problems,
				string.format(
					"%s has a %d character name and %d is the most that fits",
					id,
					if type(row.label) == "string" then #row.label else -1,
					Shop.CONFIG.LABEL_MAX
				)
			)
		end
		-- I4 AND I5 (task 196): A SHELF THE SIDE MENU DRAWS, AND AN EXPLANATION TO READ.
		-- `Shop.groups` drops a row whose category is not one of the declared ones, so without this
		-- check a mistyped shelf would be an item nobody can see and nobody can buy -- the exact
		-- silence `Weapons`'s header refuses a registry for.
		if Shop.CATEGORY_LABEL[row.category] == nil then
			table.insert(
				problems,
				string.format("%s sits on the shelf %s, which is not one of six", id, tostring(row.category))
			)
		end
		-- THE BLURB IS CHECKED AS THE PLAYER READS IT (task 221): for a bundle that is its own
		-- sentence PLUS the `INCLUDES:` line `Shop.rowsFor` appends, because a clipped list of parts
		-- is a shop window that does not say what it sells.
		local shown = if row.covers ~= nil then Shop.blurbFor(row) else row.blurb
		if type(row.blurb) ~= "string" or #row.blurb < 20 then
			table.insert(problems, string.format("%s has no explanation to read in the shop window", id))
		elseif #shown > Shop.CONFIG.PANEL.BLURB_MAX then
			-- A LONGER ONE IS CLIPPED ON A PHONE, which is not a judgement about prose: see
			-- `PANEL.BLURB_MAX` for the measurement it comes from.
			table.insert(
				problems,
				string.format(
					"%s shows a %d character explanation and %d is the most that fits",
					id,
					#shown,
					Shop.CONFIG.PANEL.BLURB_MAX
				)
			)
		end
		local grants = row.grants
		-- `grantsAnything` AND NOT A HAND-WRITTEN LIST OF FIELDS (task 221): with eight fields that
		-- line was a bug waiting for a ninth. `Shop.GRANT_FIELDS` is the list, and `shop.spec`
		-- asserts the other direction too -- every key any row actually uses is in it.
		if not Shop.grantsAnything(grants) then
			-- A ROW THAT GRANTS NOTHING IS A ROW THAT CHARGES FOR NOTHING.
			table.insert(problems, string.format("%s grants nothing", id))
			continue
		end
		-- I12 (task 221): a Robux product id, if a row has one, is a positive integer. Every row's
		-- is nil in this build -- there are no products yet, and a fabricated id is a shop window
		-- that lies -- and `shop.spec` asserts that separately.
		if
			row.robuxProductId ~= nil
			and (type(row.robuxProductId) ~= "number" or row.robuxProductId <= 0 or row.robuxProductId % 1 ~= 0)
		then
			table.insert(
				problems,
				string.format("%s carries the Robux product id %s", id, tostring(row.robuxProductId))
			)
		end
		-- I7/I8 (task 221): THE BUNDLE. Its parts are real, sellable and flat; it covers at least
		-- two; and only a bundle sits on the bundle shelf.
		if row.covers ~= nil then
			local covers = row.covers :: { string }
			if #covers < 2 then
				table.insert(problems, string.format("%s is a package covering %d items", id, #covers))
			end
			if row.category ~= Shop.CATEGORY.BUNDLE then
				table.insert(problems, string.format("%s covers items and does not sit on the package shelf", id))
			end
			local sum, highest = 0, 0
			for _, covered in ipairs(covers) do
				local part = (Shop.ROWS :: any)[covered] :: Row?
				if part == nil then
					table.insert(problems, string.format("%s covers %s, which has no row for sale", id, covered))
					continue
				end
				if part.covers ~= nil then
					table.insert(problems, string.format("%s covers %s, which is itself a package", id, covered))
				end
				if part.sale ~= true then
					table.insert(problems, string.format("%s covers %s, which is not for sale", id, covered))
				end
				sum += part.price
				highest = math.max(highest, part.hunts)
			end
			-- I9: A PACKAGE IS NOT THE WAY ROUND THE LADDER KAREN SET.
			if row.hunts < highest then
				table.insert(
					problems,
					string.format("%s unlocks at %d hunts and covers an item that needs %d", id, row.hunts, highest)
				)
			end
			-- I10: A PACKAGE THAT IS NOT CHEAPER THAN ITS PARTS IS NOT A PACKAGE.
			if row.price >= sum then
				table.insert(problems, string.format("%s costs %d and its items cost %d apart", id, row.price, sum))
			end
			-- I11: THE GRANTS **ARE** THE MERGE. A hand-written grant on a bundle fails here.
			local merged, problem = Shop.mergedGrants(covers)
			if merged == nil then
				table.insert(problems, string.format("%s cannot be merged: %s", id, tostring(problem)))
			else
				for _, field in ipairs(Shop.GRANT_FIELDS) do
					if (grants :: any)[field] ~= (merged :: any)[field] then
						table.insert(problems, string.format("%s grants a `%s` its own items do not", id, field))
					end
				end
			end
		elseif row.category == Shop.CATEGORY.BUNDLE then
			table.insert(problems, string.format("%s sits on the package shelf and covers nothing", id))
		end
		if row.sale ~= true then
			continue
		end
		if grants.weapon ~= nil and (weaponRows == nil or weaponRows[grants.weapon] == nil) then
			table.insert(
				problems,
				string.format(
					"%s is for sale and grants the weapon %s, which no build ships",
					id,
					tostring(grants.weapon)
				)
			)
		end
		-- I3a (task 221): A LICENCE ROW FOR SALE NEEDS AN ANIMAL THAT EXISTS. `Licences.ROWS` has
		-- known `reddeer` since task 171, so a check that only asked *does the table know it* would
		-- PASS and nothing structural would stop someone flipping `sale` on the RED STAG CARD.
		-- `shipped` is the fact, and it lives with the species (`ReplicatedStorage.Licences`).
		if grants.licence ~= nil then
			local licence = if licenceRows ~= nil then licenceRows[grants.licence] else nil
			if licence == nil or licence.shipped ~= true then
				table.insert(
					problems,
					string.format(
						"%s is for sale and grants a licence for %s, which no build ships",
						id,
						tostring(grants.licence)
					)
				)
			end
		end
		if grants.ammo ~= nil then
			local known = false
			for _, kind in ipairs(ammoKinds or {}) do
				if kind == grants.ammo then
					known = true
					break
				end
			end
			if not known then
				table.insert(
					problems,
					string.format(
						"%s is for sale and grants the shell %s, which no gun takes",
						id,
						tostring(grants.ammo)
					)
				)
			end
		end
	end
	for id in pairs(Shop.ROWS) do
		if not seen[id] then
			table.insert(problems, string.format("%s has a row and is not in ORDER", id))
		end
	end
	-- I6 (task 221): THE RETIRED TABLE IS DISJOINT AND INERT, and `ALL_ORDER` names every id of
	-- both exactly once. Without this a row could be live and retired at the same time, and the
	-- eight readers would answer off whichever table they happened to ask.
	local allSeen: { [string]: boolean } = {}
	for _, id in ipairs(Shop.ALL_ORDER) do
		if allSeen[id] then
			table.insert(problems, string.format("%s is in ALL_ORDER twice", id))
		end
		allSeen[id] = true
		if Shop.anyRow(id) == nil then
			table.insert(problems, string.format("%s is in ALL_ORDER and has no row", id))
		end
	end
	for _, id in ipairs(Shop.ORDER) do
		if not allSeen[id] then
			table.insert(problems, string.format("%s is for sale and is not in ALL_ORDER", id))
		end
	end
	for _, id in ipairs(Shop.RETIRED_ORDER) do
		if not allSeen[id] then
			table.insert(problems, string.format("%s is retired and is not in ALL_ORDER", id))
		end
		if (Shop.ROWS :: any)[id] ~= nil then
			table.insert(problems, string.format("%s is both for sale and retired", id))
		end
		local row = (Shop.RETIRED :: any)[id] :: Row?
		if row == nil then
			table.insert(problems, string.format("%s is in RETIRED_ORDER and has no row", id))
			continue
		end
		if row.sale ~= false then
			table.insert(problems, string.format("%s is retired and still says it is for sale", id))
		end
		-- A RETIRED ROW THAT GRANTS NOTHING IS WORSE THAN A DELETED ONE: it is kept precisely so it
		-- keeps granting to the people who bought it.
		if not Shop.grantsAnything(row.grants) then
			table.insert(problems, string.format("%s is retired and grants nothing", id))
		end
	end
	for id in pairs(Shop.RETIRED) do
		if not allSeen[id] then
			table.insert(problems, string.format("%s has a retired row and is not in ALL_ORDER", id))
		end
	end
	return problems
end

-- ---------------------------------------------------------------- the refusal

-- The closed set of reasons. They are WIRE VALUES: the server answers one and the panel prints
-- `Shop.NOTICE[reason]`.
Shop.REASON = table.freeze({
	CLOSED = "shop-closed", -- there is no money in this build at all
	UNKNOWN = "unknown-item", -- no such row: a forged or stale id
	NOT_SALE = "not-for-sale", -- in the catalogue, `sale = false`
	NO_PROFILE = "no-profile", -- no open ProfileStore session for him
	TOO_FAR = "too-far", -- he is not at the counter
	OWNED = "owned", -- he already has it. THE DOUBLE-CLICK GUARD
	LOCKED = "locked", -- not enough completed hunts
	POOR = "poor", -- not enough coins
})

-- ONE SHORT LINE EACH, in the Hud's own voice -- the register `Rules.NOTICE` sets ("NOT AT A
-- BEATER", "NO LICENCE"). Two of them carry a NUMBER, which is why `Shop.refuse` answers one
-- beside the reason and `Shop.noticeFor` is the one place it is filled in.
Shop.NOTICE = table.freeze({
	[Shop.REASON.CLOSED] = "THE SHOP IS CLOSED",
	[Shop.REASON.UNKNOWN] = "NO SUCH ITEM",
	[Shop.REASON.NOT_SALE] = "NOT IN THE GAME YET",
	[Shop.REASON.NO_PROFILE] = "YOUR ACCOUNT IS NOT LOADED",
	[Shop.REASON.TOO_FAR] = "STAND AT THE COUNTER",
	[Shop.REASON.OWNED] = "YOU OWN IT",
	[Shop.REASON.LOCKED] = "LOCKED: %d HUNTS",
	-- `%s` AND NOT `%d` SINCE TASK 221: the number is MONEY, and `Shop.noticeFor` fills it with
	-- `Money.text` so the `$` exists in one module. `LOCKED` keeps `%d` -- hunts are not money.
	[Shop.REASON.POOR] = "YOU NEED %s",
})

function Shop.noticeFor(reason: any, number: number?): string?
	if type(reason) ~= "string" then
		return nil
	end
	local line = Shop.NOTICE[reason]
	if line == nil then
		return nil
	end
	-- TWO BRANCHES, AND THE PLACEHOLDER IS THE TYPE (task 221): `%s` means money and `%d` means a
	-- plain count. So neither the door nor the panel formats a number itself, and there is exactly
	-- one place a `$` is put in front of one.
	if string.find(line, "%%s") then
		return string.format(line, Money.text(number or 0))
	end
	if string.find(line, "%%d") then
		return string.format(line, number or 0)
	end
	return line
end

-- THE ORDER THE QUESTIONS ARE ASKED IN, DECLARED AND TESTABLE, for `Rules.ORDER`'s stated reason:
-- *"an ORDER is a rule, and a rule nobody can assert is a rule that drifts"*.
--
-- WHY THIS ORDER: facts about the BUILD first (closed), then about the ITEM (unknown, not for
-- sale), then about the SESSION AND THE PLACE (no profile, too far -- things he fixes by waiting or
-- by walking), then about HIM AND THE ITEM (owned, locked, poor), which only mean anything once the
-- other five have passed.
Shop.ORDER_OF_REFUSAL = table.freeze({
	Shop.REASON.CLOSED,
	Shop.REASON.UNKNOWN,
	Shop.REASON.NOT_SALE,
	Shop.REASON.NO_PROFILE,
	Shop.REASON.TOO_FAR,
	Shop.REASON.OWNED,
	Shop.REASON.LOCKED,
	Shop.REASON.POOR,
})

export type Context = {
	itemId: any, -- whatever arrived: validated here, not trusted
	coinsOn: boolean?, -- the economy's own `enabled()`
	hasProfile: boolean?, -- a session is open for him
	atCounter: boolean?, -- the door answered it
	owned: { [string]: boolean }?,
	balance: number?,
	hunts: number?,
}

-- PURE. The first question in `Shop.ORDER_OF_REFUSAL` that answers yes -- and the number its line
-- needs -- or nil for "he may buy it".
--
-- NIL IS "NOTHING SAID" for `coinsOn`, `hasProfile` and `atCounter`, the call `Rules.driveClosed`
-- and `Rules.outsideStand` already make and for their stated reason (*"a gate that refused on an
-- unwired world would make a mis-wiring look exactly like Karen's rule working"*). The door and
-- `Economy.purchase` both pass explicit booleans, so no production path reaches a nil.
--
-- `owned == nil` MEANS HE OWNS NOTHING, HERE AND ONLY HERE (design section 4.3). This function is
-- asked *"shall I take his money"*, and the safe answer to an unknown set is "he does not own it,
-- so the purchase may proceed": he is charged once, and the second click is refused `OWNED` off the
-- set that was actually written. Every reader of what ownership GIVES makes the opposite call, and
-- design section 7.1 is the table of why.
function Shop.refuse(context: Context): (string?, number?)
	local row = Shop.row(context.itemId)
	for _, reason in ipairs(Shop.ORDER_OF_REFUSAL) do
		if reason == Shop.REASON.CLOSED then
			if context.coinsOn == false then
				return reason, nil
			end
		elseif reason == Shop.REASON.UNKNOWN then
			if row == nil then
				return reason, nil
			end
		elseif reason == Shop.REASON.NOT_SALE then
			if (row :: Row).sale ~= true then
				return reason, nil
			end
		elseif reason == Shop.REASON.NO_PROFILE then
			if context.hasProfile == false then
				return reason, nil
			end
		elseif reason == Shop.REASON.TOO_FAR then
			if context.atCounter == false then
				return reason, nil
			end
		elseif reason == Shop.REASON.OWNED then
			-- `ownedOrCovered` AND NOT `owns` (task 221): a man who bought a bundle already HAS the
			-- rows it covers, and charging him again would be the shop taking money for nothing. The
			-- second clause is the same question asked of a bundle: every part already his.
			if
				Shop.ownedOrCovered(context.owned, context.itemId) or Shop.fullyCovered(context.owned, context.itemId)
			then
				return reason, nil
			end
		elseif reason == Shop.REASON.LOCKED then
			local hunts = context.hunts or 0
			if hunts < (row :: Row).hunts then
				return reason, (row :: Row).hunts - hunts
			end
		elseif reason == Shop.REASON.POOR then
			local balance = context.balance or 0
			if balance < (row :: Row).price then
				return reason, (row :: Row).price - balance
			end
		end
	end
	return nil, nil
end

-- ---------------------------------------------------------------- the wire

Shop.KIND = table.freeze({
	OPEN = "open", -- "tell me what I have"
	BUY = "buy", -- "sell me `item`"
})

export type Request = { kind: string, item: string? }

-- ONE ROW OF THE PANEL, ALREADY DECIDED. `buyable` is computed ONCE, on the server, and is the only
-- field the button reads: two readers of "can he buy this" is how a greyed-out button and an
-- accepted purchase disagree (design section 6.3, hazard 10).
export type WireRow = {
	id: string,
	label: string,
	-- THE SHELF AND THE EXPLANATION TRAVEL ON THE WIRE (task 196) and are not read off the shared
	-- catalogue by the panel, even though the panel could. `ShopPanel`'s own rule is *"IT DRAWS WHAT
	-- ARRIVED AND DECIDES NOTHING"*, and a panel that read half a row from the wire and half from its
	-- own copy of the table would be two readers of one row the day the catalogue changes under a
	-- client that has not rejoined. Twelve extra fields per state message, once per press.
	category: string,
	blurb: string,
	price: number,
	hunts: number,
	sale: boolean,
	owned: boolean,
	locked: boolean,
	afford: boolean,
	buyable: boolean,
}

export type State = {
	coinsOn: boolean,
	balance: number?, -- nil = no open profile, which is NOT zero (`Economy.balanceOf`'s rule)
	hunts: number,
	rows: { WireRow },
	refused: string?, -- one of `Shop.REASON`, for the LAST buy attempt
	refusedNumber: number?,
	bought: string?, -- the item id a successful purchase just granted
}

-- THE WHITELIST ON WHAT A CLIENT MAY SEND, pure, and the shape `Weapon.Validator.checkRequest` has.
-- NO PRICE, NO BALANCE, NO POSITION, NO userId: the server knows all four better than the client
-- does (Roblox's own security page, the note's section 2.2).
--
-- A WELL-FORMED id NAMING NO ROW IS NOT A BAD REQUEST: it is `Shop.REASON.UNKNOWN`, counted
-- separately, because a stale client after a catalogue change is a different fact from a forged
-- packet -- `Weapon`'s own split between `stats.refused` and `stats.badRequests`.
function Shop.checkRequest(kind: any, item: any): (boolean, string?)
	if type(kind) ~= "string" then
		return false, "bad-request"
	end
	if kind ~= Shop.KIND.OPEN and kind ~= Shop.KIND.BUY then
		return false, "bad-request"
	end
	if kind == Shop.KIND.OPEN then
		-- AN ARGUMENT NOBODY READS IS AN ARGUMENT NOBODY CHECKED.
		if item ~= nil then
			return false, "bad-request"
		end
		return true, nil
	end
	if type(item) ~= "string" or #item == 0 or #item > Shop.CONFIG.MAX_ID_CHARS then
		return false, "bad-request"
	end
	return true, nil
end

Shop.REMOTES_NAME = "Remotes"
Shop.REQUEST_REMOTE = "ShopRequest"
Shop.STATE_REMOTE = "ShopState"

local remotes: { ShopRequest: RemoteEvent, ShopState: RemoteEvent }? = nil

-- Memoised, exactly as `Shotgun.remotes()` and `Report.remotes()` are: five `WaitForChild` calls
-- per ask is a cost nobody needs twice.
function Shop.remotes(): { ShopRequest: RemoteEvent, ShopState: RemoteEvent }
	local cached = remotes
	if cached ~= nil then
		return cached
	end
	local folder = ReplicatedStorage:WaitForChild("Shop"):WaitForChild(Shop.REMOTES_NAME)
	local built = {
		ShopRequest = folder:WaitForChild(Shop.REQUEST_REMOTE) :: RemoteEvent,
		ShopState = folder:WaitForChild(Shop.STATE_REMOTE) :: RemoteEvent,
	}
	remotes = built
	return built
end

-- ---------------------------------------------------------------- what ownership GIVES
--
-- EIGHT pure readers since task 221, one per `Grants` field. EVERY ONE OF THEM ANSWERS "TODAY'S
-- GAME" FOR A nil SET -- and today's game is NOT the same boolean in all eight, which is design
-- section 5.6's table. Today a hunter HAS the rifle and his twelve slugs and an orange hat and
-- whatever stand the walk deals him; a beater HAS NO GUN; nobody has unlimited shells, nobody is
-- owed a role by purchase, and nobody holds a species licence. So nil must give him the first
-- four and must not give him the last three, or an un-wired world -- every
-- `tests/server/weapon_*.spec.luau` -- would arm every beater in it and put every player on
-- `Shooters`.
--
-- ALL EIGHT ITERATE `Shop.ALL_ORDER` AND ASK `Shop.anyRow`, so a RETIRED row keeps granting to the
-- people who bought it (task 221, Karen: *"From shop remove red heat"*). The panel and the till
-- read `Shop.ORDER` and `Shop.ROWS` instead, so the hat is invisible and unbuyable.

-- WHAT THIS WEAPON STARTS A DRIVE WITH. nil `start` is what every existing caller of
-- `StateMachine.initial` gets, so the weapon system's own numbers are untouched.
--
-- `row` is a `Weapons.Row` -- `AMMO_KINDS`, `START_RESERVE`, `INITIAL_AMMO` -- and NOTHING HERE
-- INVENTS A NUMBER: the pocket sizes are still the weapon's own. A kind he may not be issued gets a
-- pocket of ZERO rather than an absent one, because `StateMachine.apply`'s `Load` already refuses an
-- empty pocket with `"no-reserve"` and a zero keeps the readout honest (the Hud prints the pocket).
--
-- `unlimited` IS THE ALLOWANCE AND NOT THE POCKET (task 221, design section 7.1): this says WHICH
-- KINDS the 12-per-drive allowance stops binding for, and `Weapon.StateMachine` is what does not
-- decrement them. It is nil unless he owns the row, which is every caller today -- so a build where
-- nobody bought it hands exactly the table it handed before.
function Shop.startFor(
	row: any,
	owned: { [string]: boolean }?
): { ammo: string, reserve: { [string]: number }, unlimited: { [string]: boolean }? }
	local initial = row.INITIAL_AMMO
	if owned == nil then
		return { ammo = initial, reserve = table.clone(row.START_RESERVE) }
	end
	local base = (Shop.BASE_AMMO :: any)[row.id]
	if base == nil then
		-- An unmapped weapon is unrestricted: see `Shop.BASE_AMMO`.
		return { ammo = initial, reserve = table.clone(row.START_RESERVE) }
	end
	local allowed: { [string]: boolean } = {}
	for kind in pairs(base) do
		allowed[kind] = true
	end
	for _, id in ipairs(Shop.ALL_ORDER) do
		local item = Shop.anyRow(id) :: Row
		if item.grants.ammo ~= nil and owned[id] == true then
			allowed[item.grants.ammo :: string] = true
		end
	end
	local reserve: { [string]: number } = {}
	local first: string? = nil
	for _, kind in ipairs(row.AMMO_KINDS) do
		if allowed[kind] then
			reserve[kind] = row.START_RESERVE[kind] or 0
			if first == nil then
				first = kind
			end
		else
			reserve[kind] = 0
		end
	end
	-- A GUN THAT CAN FIRE NOTHING IS NOT A RULE, IT IS A BROKEN GUN: if his set allows none of this
	-- weapon's kinds, the weapon's own initial stands and the pockets are all zero, so he carries
	-- what is in the barrels and no more.
	local ammo = if allowed[initial] then initial else (first or initial)
	-- UNLIMITED BUCKSHOT WITHOUT THE SLUG STAYS UNLIMITED *BUCKSHOT*: only the kinds he may be
	-- issued at all, so the entitlement cannot hand him a shell the ladder has not sold him.
	local unlimited: { [string]: boolean }? = nil
	if Shop.grantsUnlimitedAmmo(owned) then
		local kinds: { [string]: boolean } = {}
		for _, kind in ipairs(row.AMMO_KINDS) do
			if allowed[kind] then
				kinds[kind] = true
			end
		end
		if next(kinds) ~= nil then
			unlimited = kinds
		end
	end
	return { ammo = ammo, reserve = reserve, unlimited = unlimited }
end

-- MAY A BEATER CARRY A GUN IN THE DRIVE? Karen: a beater *"can purchase license to shoot in
-- drive"*. FALSE for nil and FALSE for `{}`: this is one of the readers whose default is "refused",
-- because today a beater carries no gun (design section 5.6).
function Shop.grantsDriveGun(owned: { [string]: boolean }?): boolean
	if owned == nil then
		return false
	end
	for _, id in ipairs(Shop.ALL_ORDER) do
		local row = Shop.anyRow(id) :: Row
		if row.grants.driveGun == true and owned[id] == true then
			return true
		end
	end
	return false
end

-- MAY HE BE DEALT ONE OF TASK 218'S HIGH SEATS? Karen, 2026-10-20: *"Access to tree stand"*.
--
-- **TRUE FOR nil**, and it is the only one of the four new readers that way round. Today every
-- hunter is dealt whatever stand the centre-out walk gives him, so an un-wired world -- and a
-- DataStore outage -- must deal exactly as it does now. The cost is stated rather than discovered:
-- during an outage a player who owns nothing may be dealt a high seat for one drive, which is the
-- same accepted cost shop design section 7.1 already names for the rifle (*"a player who owns
-- nothing is handed the rifle for one drive"*). Reversible in one word; the Director's (D-5).
function Shop.grantsHighSeat(owned: { [string]: boolean }?): boolean
	if owned == nil then
		return true
	end
	for _, id in ipairs(Shop.ALL_ORDER) do
		local row = Shop.anyRow(id) :: Row
		if row.grants.highSeat == true and owned[id] == true then
			return true
		end
	end
	return false
end

-- DOES THE 12-SHELLS-PER-DRIVE ALLOWANCE STOP BINDING? Karen: *"Unlimited amunition"*.
-- FALSE for nil: a limit is today's game, and an un-wired world must keep it.
function Shop.grantsUnlimitedAmmo(owned: { [string]: boolean }?): boolean
	if owned == nil then
		return false
	end
	for _, id in ipairs(Shop.ALL_ORDER) do
		local row = Shop.anyRow(id) :: Row
		if row.grants.unlimitedAmmo == true and owned[id] == true then
			return true
		end
	end
	return false
end

-- IS HE OWED THE HUNTER'S PLACE EVERY DRIVE? Karen: *"Posibility to be a hunter always"*.
-- FALSE for nil: true would put every player in every un-wired world on `Shooters` and break
-- `match_roster.spec` at every roster size.
--
-- IT IS A PREFERENCE AND NOT AN EXEMPTION. `Roster.assign`'s balance rule still wins, and
-- `Roster.overruled` is what tells the man it happened to.
function Shop.grantsAlwaysHunter(owned: { [string]: boolean }?): boolean
	if owned == nil then
		return false
	end
	for _, id in ipairs(Shop.ALL_ORDER) do
		local row = Shop.anyRow(id) :: Row
		if row.grants.alwaysHunter == true and owned[id] == true then
			return true
		end
	end
	return false
end

-- WHICH SPECIES HE HOLDS A CARD FOR, as the set `Licences.allows` takes (task 221).
--
-- nil IN, nil OUT -- `Licences.allows`'s own rule: *"nil means he holds none, which is every player
-- today"*. nil and `{}` mean the same thing to that function, and answering nil keeps the un-wired
-- world byte-identical.
function Shop.licencesFor(owned: { [string]: boolean }?): { [string]: boolean }?
	if owned == nil then
		return nil
	end
	local out: { [string]: boolean } = {}
	for _, id in ipairs(Shop.ALL_ORDER) do
		local row = Shop.anyRow(id) :: Row
		if row.grants.licence ~= nil and owned[id] == true then
			out[row.grants.licence :: string] = true
		end
	end
	return out
end

-- HIS HAT'S COLOUR, or nil for "the outfit's own orange". The LAST owned hat row in `ALL_ORDER`
-- wins, so two hats cannot flicker: there is one answer and it is a function of the set.
--
-- IT ITERATES `ALL_ORDER` AND THAT IS THE WHOLE OF WHY `Shop.RETIRED` EXISTS (task 221): the red
-- hat left the shop at Karen's word, and a man who bought one keeps wearing it.
function Shop.hatColorFor(owned: { [string]: boolean }?): Color3?
	if owned == nil then
		return nil
	end
	local found: Color3? = nil
	for _, id in ipairs(Shop.ALL_ORDER) do
		local row = Shop.anyRow(id) :: Row
		if row.grants.hatColor ~= nil and owned[id] == true then
			found = row.grants.hatColor
		end
	end
	return found
end

-- WHICH WEAPON IDS BELONG IN HIS LOADOUT, given the ids the weapon system ships and which one is
-- the PRIMARY. The primary is never taken away: Karen's *"default is double barrel shotgun"*.
--
-- It is GIVEN the ids rather than reading `Weapons` itself, and that direction is the whole point:
-- `Weapons` requires this module and not the reverse, so there is no cycle and the weapon system
-- learns only that some ids are allowed.
function Shop.loadoutFrom(ids: { string }, primary: string, owned: { [string]: boolean }?): { string }
	if owned == nil then
		return table.clone(ids)
	end
	local out = {}
	for _, id in ipairs(ids) do
		if id == primary or Shop.ownsWeapon(owned, id) then
			table.insert(out, id)
		end
	end
	return out
end

-- ---------------------------------------------------------------- the panel's body

-- WHAT THE DETAIL PANE READS FOR THIS ROW. PURE. For an ordinary row it is the row's own sentence;
-- for a BUNDLE it is that sentence plus the list of what is in it, because a package whose contents
-- are not on screen is a package nobody can judge (task 221).
--
-- IT IS COMPOSED HERE AND NOT IN THE PANEL, for `ShopPanel`'s own stated rule -- *"IT DRAWS WHAT
-- ARRIVED AND DECIDES NOTHING"* -- and `rowsOk` measures THIS string against `BLURB_MAX`, so a
-- package whose list would be clipped fails the harness instead of the eye.
function Shop.blurbFor(row: Row): string
	local covers = row.covers
	if covers == nil or #(covers :: { string }) == 0 then
		return row.blurb
	end
	local labels: { string } = {}
	for _, id in ipairs(covers :: { string }) do
		local part = Shop.anyRow(id)
		table.insert(labels, if part ~= nil then part.label else id)
	end
	return row.blurb .. " " .. string.format(Shop.CONFIG.TEXT.COVERS, table.concat(labels, ", "))
end

-- THE WHOLE PANEL, DECIDED ONCE, ON THE SERVER. PURE and exported -- the idiom
-- `Hud.scorePanelLines` and `Hud.startCardRows` already establish, and it is
-- why the panel decides nothing (design section 5.2).
--
-- `buyable` IS `Shop.refuse(...) == nil` FOR THE SAME FACTS, which `shop.spec` asserts over a table
-- of cases: one rule, and the window and the till cannot disagree.
-- FOUR PARAMETERS, AND THE REACH IS NOT ONE OF THEM (the Reviewer's round-1 note): it is the
-- DOOR's rule, measured per request, and a panel that greyed every button the moment he stepped
-- back would be a second reader of it. An argument nobody passes is what `Shop.checkRequest`'s own
-- whitelist refuses in the other direction.
--
-- IT ITERATES `Shop.ORDER` AND NOT `ALL_ORDER`: a retired row is invisible to the panel (task 221).
function Shop.rowsFor(owned: { [string]: boolean }?, balance: number?, hunts: number?, coinsOn: boolean?): { WireRow }
	local out: { WireRow } = {}
	for _, id in ipairs(Shop.ORDER) do
		local row = (Shop.ROWS :: any)[id] :: Row
		local refused = Shop.refuse({
			itemId = id,
			coinsOn = coinsOn,
			hasProfile = balance ~= nil,
			owned = owned,
			balance = balance,
			hunts = hunts,
		})
		table.insert(out, {
			id = id,
			label = row.label,
			category = row.category,
			blurb = Shop.blurbFor(row),
			price = row.price,
			hunts = row.hunts,
			sale = row.sale,
			-- `ownedOrCovered` AND NOT `owns` (task 221): the row the man already has through a
			-- package says IN YOUR KIT rather than offering to sell it to him again. It is the same
			-- predicate `Shop.refuse` asks, which is what keeps the button and the till in step.
			owned = Shop.ownedOrCovered(owned, id) or Shop.fullyCovered(owned, id),
			locked = (hunts or 0) < row.hunts,
			afford = (balance or 0) >= row.price,
			buyable = refused == nil,
		})
	end
	return out
end

-- IS HE AT THE COUNTER? FLAT -- the Y is ignored -- and `<=`, so standing exactly on the line is
-- in. `ForestTest.withinStand`'s rule (*"a hunter standing on his post is a stud or three above the
-- ground he picked it from and that is not leaving the stand"*), and the same comparison as
-- `Lobby.Join.within`, which cites it.
--
-- IT IS THE THIRD COPY OF ONE SUBTRACTION AND THAT IS A DECISION (design section 4.4): `Join` is a
-- SERVER module and a shared module may not require one, and `ForestTest` is one world's data. So
-- each owner's boundary carries the arithmetic and `shop.spec` asserts that all three agree on the
-- same three cases -- the cheapest guard against the drift this repo fears most. Folding them into
-- one shared predicate is queued for the Director (design 16 item 11).
--
-- nil in, FALSE out for a missing counter: a world with no lodge has no shop, which is exactly what
-- the DEV place is (design section 10.4).
function Shop.withinReach(position: Vector3?, counter: Vector3?, reachStuds: number?): boolean
	if position == nil or counter == nil then
		return false
	end
	local flat = Vector3.new(position.X - counter.X, 0, position.Z - counter.Z)
	return flat.Magnitude <= (reachStuds or Shop.CONFIG.REACH_STUDS)
end

return Shop
