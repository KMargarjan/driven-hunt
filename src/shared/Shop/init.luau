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
}

export type Row = {
	id: string,
	label: string, -- what the panel prints
	price: number, -- coins. Karen's, and hers to retune
	hunts: number, -- completed hunts before it unlocks
	sale: boolean, -- false = shown and NOT buyable (see `rifle.open`)
	grants: Grants,
}

-- `grants` IS THE ONE INVENTED THING IN THIS FILE and rule 2 wants the reason: no source has this
-- game's weapon ids in it. It is five rows of data read by four functions that already exist, which
-- is the note's section 2.4 (*"ownership is a set the loadout reads"*) with our names in it.
Shop.ITEM = table.freeze({
	SLUG = "ammo.slug",
	BEATER_LICENCE = "licence.beater",
	HAT_RED = "hat.red",
	RIFLE_OPEN = "rifle.open",
	RIFLE = "rifle.scoped",
})

Shop.ROWS = {
	[Shop.ITEM.HAT_RED] = {
		id = Shop.ITEM.HAT_RED,
		label = "RED HAT",
		-- A COSMETIC IS THE CHEAPEST THING IN THE SHOP, and at 80 it is one good drive: the first
		-- thing a player can actually buy, which is what makes the shop read as a shop.
		price = 80,
		hunts = 0,
		sale = true,
		-- DARK HUNTING RED, because hunter orange is already the team colour and a second orange hat
		-- would be invisible as a purchase (design section 16 item 2). Karen's to change.
		grants = { hatColor = Color3.fromRGB(150, 38, 32) },
	} :: Row,
	[Shop.ITEM.SLUG] = {
		id = Shop.ITEM.SLUG,
		label = "SLUG SHELLS",
		-- A drive pays 10 to ~105 coins (docs/design/economy.md section 8), so ~3 drives.
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
	[Shop.ITEM.RIFLE_OPEN] = {
		id = Shop.ITEM.RIFLE_OPEN,
		label = "RIFLE, OPEN",
		price = 600,
		hunts = 10,
		-- NOT FOR SALE IN THIS BUILD, AND THE INVARIANT FORCES IT RATHER THAN A COMMENT ASKING FOR
		-- IT. KAREN TOOK THIS WEAPON OUT IN TASK 148: *"please remove rifle without scope so we
		-- don't implement now"*; its row, its pose set and its two spec cases are archived in
		-- `backups/2026-10-10-rifle-open-sights.md`, and `Weapons.ROWS` has no `rifleOpen`.
		--
		-- The RUNG IS STILL SHOWN, because the ladder Karen accepted has four rungs and a shop that
		-- hid one would tell her the ladder is shorter than it is. `Shop.rowsOk` is what says
		-- `sale = true` would be illegal today, and the day a build ships that weapon, flipping this
		-- one word is legal and the invariant is what says so.
		sale = false,
		grants = { weapon = "rifleOpen" },
	} :: Row,
	[Shop.ITEM.RIFLE] = {
		id = Shop.ITEM.RIFLE,
		label = "RIFLE, SCOPED",
		-- *"has to play a lot it's not few hunts"*: ~25 drives of money at the rates
		-- `Economy.CONFIG` pays today, and 25 finished drives before it unlocks at all.
		price = 1500,
		hunts = 25,
		sale = true,
		grants = { weapon = "rifle" },
	} :: Row,
}

-- THE ORDER THE PANEL DRAWS, CHEAPEST FIRST, so the first thing a player with 80 coins sees is a
-- thing he can buy. A list rather than a `slot` field per row, for `Weapons.ORDER`'s stated reason:
-- the order is one fact and belongs in one place.
Shop.ORDER = table.freeze({
	Shop.ITEM.HAT_RED,
	Shop.ITEM.SLUG,
	Shop.ITEM.BEATER_LICENCE,
	Shop.ITEM.RIFLE_OPEN,
	Shop.ITEM.RIFLE,
})

-- ---------------------------------------------------------------- the words and the numbers

Shop.CONFIG = {
	-- One panel, no scrolling, no paging. `shop.spec` asserts the catalogue against it.
	MAX_ITEMS = 8,
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
	PANEL = {
		-- 360, NOT 420, AND THE REASON IS MEASURED: `tests/client/hud_clarity.spec.luau` asserts
		-- against a 400 px wide screen and `Drive.CONFIG.SCORE_PANEL_WIDTH` is already 480 -- wider
		-- than that screen, which `docs/design/economy.md` section 7.2 names as an existing problem
		-- it declined to make worse. This is the first panel in the repo that fits the phone screen
		-- the clarity spec measures, and a panel that fits is worth more than three characters of
		-- label (design section 13.1).
		WIDTH = 360,
		ROW_PX = 48,
		GAP = 8,
		-- 64 AND NOT 40, AND THE FIRST FRAME IS WHY (rule 5). The header is a title at y=8 and the
		-- balance line under it at y=34, and at 40 the first row was drawn straight through
		-- "COINS 0     HUNTS 0" -- measured in `.screenshots/20261014-task178-shop-panel.png`, the
		-- first picture this panel ever took. 64 clears the balance's own 20 px with ten to spare.
		HEADER_PX = 64,
		FOOTER_PX = 56,
		-- `Report.CONFIG.PANEL_Z_INDEX` is 15 and `Rail.CONFIG.Z_INDEX` is 16, so the rail stays
		-- pressable over this panel -- which is what lets a thumb reach the map while it is open.
		Z_INDEX = 15,
	},
	-- EVERY WORD THE PANEL DRAWS IS WRITTEN DOWN, which is `Drive.CONFIG`'s own rule.
	TEXT = {
		TITLE = "SHOP",
		CLOSED = "THE SHOP IS CLOSED",
		BALANCE = "COINS %s     HUNTS %d",
		CLOSE = "CLOSE",
		BUY = "BUY",
		OWNED_TAG = "OWNED",
		SOON_TAG = "SOON",
		LOCKED_TAG = "%d HUNTS",
		POOR_TAG = "NO COINS",
		HINT = "WHAT YOU BUY IS YOURS FROM THE NEXT HUNT",
		BOUGHT = "BOUGHT: %s",
	},
}

-- deepFreeze, REQUIRED and not copied: `table.freeze` is shallow and this repo has paid for that
-- once already (`src/shared/Drive/init.luau`, Task 23a note (b)).
Shotgun.deepFreeze(Shop.ROWS)
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

function Shop.row(id: any): Row?
	if type(id) ~= "string" then
		return nil
	end
	return (Shop.ROWS :: any)[id]
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
	for _, id in ipairs(Shop.ORDER) do
		local row = (Shop.ROWS :: any)[id] :: Row
		if row.grants.weapon == weaponId and owned[id] == true then
			return true
		end
	end
	return false
end

-- IS THE CATALOGUE LEGAL? PURE and exported so the invariant is an assertion rather than a comment
-- (design section 4.2, I1-I3). It takes the weapon table as a PARAMETER, so this module requires
-- neither `Weapons` nor anything else: a shared module that required the weapon table to validate
-- itself would be a cycle the day `Weapons` reads this one -- which it does, for the loadout.
--
-- I3 IS THE ONE THAT MATTERS: a row for sale can actually be granted. It is what makes the note's
-- *"Selling a thing that grants nothing is the one failure this repository would not forgive"*
-- structural, and it is what FORCES `rifle.open`'s `sale = false`.
function Shop.rowsOk(weaponRows: any, ammoKinds: { string }?): { string }
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
		local grants = row.grants
		if
			grants == nil
			or (grants.ammo == nil and grants.weapon == nil and grants.driveGun == nil and grants.hatColor == nil)
		then
			-- A ROW THAT GRANTS NOTHING IS A ROW THAT CHARGES FOR NOTHING.
			table.insert(problems, string.format("%s grants nothing", id))
			continue
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
	[Shop.REASON.POOR] = "YOU NEED %d COINS",
})

function Shop.noticeFor(reason: any, number: number?): string?
	if type(reason) ~= "string" then
		return nil
	end
	local line = Shop.NOTICE[reason]
	if line == nil then
		return nil
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
			if Shop.owns(context.owned, context.itemId) then
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
-- Four pure readers, one per `Grants` field. EVERY ONE OF THEM ANSWERS "TODAY'S GAME" FOR A nil SET
-- -- and today's game is not the same boolean in all four, which is design section 7.1's table:
-- today a hunter HAS the rifle and his twelve slugs and an orange hat, and a beater HAS NO GUN. So
-- nil gives him the first three and must not give him the fourth, or an un-wired world -- every
-- `tests/server/weapon_*.spec.luau` -- would arm every beater in it.

-- WHAT THIS WEAPON STARTS A DRIVE WITH. nil `start` is what every existing caller of
-- `StateMachine.initial` gets, so the weapon system's own numbers are untouched.
--
-- `row` is a `Weapons.Row` -- `AMMO_KINDS`, `START_RESERVE`, `INITIAL_AMMO` -- and NOTHING HERE
-- INVENTS A NUMBER: the pocket sizes are still the weapon's own. A kind he may not be issued gets a
-- pocket of ZERO rather than an absent one, because `StateMachine.apply`'s `Load` already refuses an
-- empty pocket with `"no-reserve"` and a zero keeps the readout honest (the Hud prints the pocket).
function Shop.startFor(row: any, owned: { [string]: boolean }?): { ammo: string, reserve: { [string]: number } }
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
	for _, id in ipairs(Shop.ORDER) do
		local item = (Shop.ROWS :: any)[id] :: Row
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
	return { ammo = ammo, reserve = reserve }
end

-- MAY A BEATER CARRY A GUN IN THE DRIVE? Karen: a beater *"can purchase license to shoot in
-- drive"*. FALSE for nil and FALSE for `{}`: this is the one reader whose default is "refused",
-- because today a beater carries no gun (design section 7.1).
function Shop.grantsDriveGun(owned: { [string]: boolean }?): boolean
	if owned == nil then
		return false
	end
	for _, id in ipairs(Shop.ORDER) do
		local row = (Shop.ROWS :: any)[id] :: Row
		if row.grants.driveGun == true and owned[id] == true then
			return true
		end
	end
	return false
end

-- HIS HAT'S COLOUR, or nil for "the outfit's own orange". The LAST owned hat row in `Shop.ORDER`
-- wins, so two hats cannot flicker: there is one answer and it is a function of the set.
function Shop.hatColorFor(owned: { [string]: boolean }?): Color3?
	if owned == nil then
		return nil
	end
	local found: Color3? = nil
	for _, id in ipairs(Shop.ORDER) do
		local row = (Shop.ROWS :: any)[id] :: Row
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

-- THE WHOLE PANEL, DECIDED ONCE, ON THE SERVER. PURE and exported -- the idiom
-- `Hud.scorePanelLines`, `Hud.startCardLines` and `Match.quarryLines` already establish, and it is
-- why the panel decides nothing (design section 5.2).
--
-- `buyable` IS `Shop.refuse(...) == nil` FOR THE SAME FACTS, which `shop.spec` asserts over a table
-- of cases: one rule, and the window and the till cannot disagree.
-- FOUR PARAMETERS, AND THE REACH IS NOT ONE OF THEM (the Reviewer's round-1 note): it is the
-- DOOR's rule, measured per request, and a panel that greyed every button the moment he stepped
-- back would be a second reader of it. An argument nobody passes is what `Shop.checkRequest`'s own
-- whitelist refuses in the other direction.
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
			price = row.price,
			hunts = row.hunts,
			sale = row.sale,
			owned = Shop.owns(owned, id),
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
