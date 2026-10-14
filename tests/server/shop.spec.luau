-- shop.spec: THE CATALOGUE AND THE RULES OF BUYING (task 178), and the four readers of what
-- ownership GIVES.
--
-- Karen, 2026-10-13: *"Hunting house where inside can shop things"*; 2026-10-10: *"Rifle they has to
-- purchase default is double barrel shotgun"*, *"They will have posibility to purchase rifle but has
-- to play a lot it's not few hunts"*, a beater *"can purchase license to shoot in drive"*, and *"buy
-- packages for outfit"*.
--
-- ALL OF IT IS PURE and needs no world, no player, no profile and no clock: `ReplicatedStorage.Shop`
-- takes every fact as a parameter, and so do `Weapons.loadoutFor`, `StateMachine.initial` and
-- `Body.dressFor`. The door and the money are `shop_door.spec` and `economy.spec`.
--
-- WHAT THIS FILE IS FOR, in one sentence: it is the evidence that the WINDOW and the TILL read one
-- table. Every badge the panel draws comes from `Shop.rowsFor`, every refusal the server answers
-- comes from `Shop.refuse`, and the case *"rowsFor agrees with refuse"* is the assertion that those
-- two can never disagree.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/shop.md (sections 4, 7, 12.2)
-- Note:   docs/research/2026-10-14-the-shop.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Match = require(ServerScriptService:WaitForChild("Match"))
local Shop = require(ReplicatedStorage:WaitForChild("Shop"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

local Body = Match.Body
local Join = require(ServerScriptService:WaitForChild("Lobby")).Join
local StateMachine = Weapon.StateMachine
local SHOTGUN = Weapons.ROWS.shotgun
local RIFLE = Weapons.ROWS.rifle

-- A full wallet with nothing bought, so a case says only what it changes.
local function ctx(over)
	local base = {
		itemId = Shop.ITEM.HAT_RED,
		coinsOn = true,
		hasProfile = true,
		atCounter = true,
		owned = {},
		balance = 10000,
		hunts = 100,
	}
	for key, value in pairs(over or {}) do
		base[key] = value
	end
	return base
end

return function()
	describe("the catalogue", function()
		it("is Karen's ladder, frozen, cheapest first, and no row can be edited at run time", function()
			-- HER FOUR RUNGS PLUS THE COSMETIC, in `Shop.ORDER`'s own order.
			expect(#Shop.ORDER).to.equal(5)
			expect(Shop.ORDER[1]).to.equal(Shop.ITEM.HAT_RED)
			expect(Shop.ORDER[2]).to.equal(Shop.ITEM.SLUG)
			expect(Shop.ORDER[3]).to.equal(Shop.ITEM.BEATER_LICENCE)
			expect(Shop.ORDER[4]).to.equal(Shop.ITEM.RIFLE_OPEN)
			expect(Shop.ORDER[5]).to.equal(Shop.ITEM.RIFLE)
			-- CHEAPEST FIRST, so a player with 80 coins sees something he can buy at the top.
			local previous = -1
			for _, id in ipairs(Shop.ORDER) do
				local row = Shop.ROWS[id]
				expect(row.price >= previous).to.equal(true)
				previous = row.price
			end
			-- The prices Karen decides later, written down so a change to one of them fails here
			-- rather than drifting (docs/research/2026-10-14-the-shop.md section 4).
			expect(Shop.ROWS[Shop.ITEM.HAT_RED].price).to.equal(80)
			expect(Shop.ROWS[Shop.ITEM.SLUG].price).to.equal(120)
			expect(Shop.ROWS[Shop.ITEM.BEATER_LICENCE].price).to.equal(250)
			expect(Shop.ROWS[Shop.ITEM.BEATER_LICENCE].hunts).to.equal(3)
			expect(Shop.ROWS[Shop.ITEM.RIFLE].price).to.equal(1500)
			expect(Shop.ROWS[Shop.ITEM.RIFLE].hunts).to.equal(25)
			-- The rules of the game are not writable at run time: the discipline every frozen table
			-- in this repo follows, and `deepFreeze` is what makes it reach the rows.
			expect(table.isfrozen(Shop.ROWS)).to.equal(true)
			expect(table.isfrozen(Shop.CONFIG)).to.equal(true)
			expect(function()
				(Shop.ROWS[Shop.ITEM.RIFLE] :: any).price = 1
			end).to.throw()
			expect(function()
				(Shop.CONFIG.PANEL :: any).WIDTH = 1
			end).to.throw()
		end)

		-- I1, I2 AND I3 IN ONE CALL (design section 4.2). The third is the one that matters: a row
		-- FOR SALE can actually be granted, which is what forces `rifle.open`'s `sale = false`
		-- rather than a comment asking for it.
		it("is legal against the weapons this build ships, and the open-sight rifle is not for sale", function()
			local problems = Shop.rowsOk(Weapons.ROWS, SHOTGUN.AMMO_KINDS)
			expect(#problems).to.equal(0)
			expect(#Shop.ORDER <= Shop.CONFIG.MAX_ITEMS).to.equal(true)
			-- THE RUNG IS SHOWN AND IS NOT SELLABLE, because `Weapons.ROWS` has no such weapon:
			-- Karen took it out in task 148.
			expect(Shop.ROWS[Shop.ITEM.RIFLE_OPEN].sale).to.equal(false)
			expect(Weapons.row(Shop.ROWS[Shop.ITEM.RIFLE_OPEN].grants.weapon)).to.equal(nil)
			-- ...and the invariant is what says so: flip that one word and the catalogue is illegal.
			local pretend = {}
			for id, row in pairs(Shop.ROWS) do
				local copy = table.clone(row)
				copy.grants = table.clone(row.grants)
				if id == Shop.ITEM.RIFLE_OPEN then
					copy.sale = true
				end
				pretend[id] = copy
			end
			local saved = Shop.ROWS;
			(Shop :: any).ROWS = pretend
			local broken = Shop.rowsOk(Weapons.ROWS, SHOTGUN.AMMO_KINDS);
			(Shop :: any).ROWS = saved
			expect(#broken).to.equal(1)
			expect(string.find(broken[1], "rifleOpen") ~= nil).to.equal(true)
		end)

		it("grants something in every row, and every grant is one of the four kinds", function()
			local kinds = { ammo = 0, weapon = 0, driveGun = 0, hatColor = 0 }
			for _, id in ipairs(Shop.ORDER) do
				local grants = Shop.ROWS[id].grants
				local counted = 0
				for key in pairs(kinds) do
					if (grants :: any)[key] ~= nil then
						kinds[key] += 1
						counted += 1
					end
				end
				-- A ROW THAT GRANTS NOTHING IS A ROW THAT CHARGES FOR NOTHING.
				expect(counted >= 1).to.equal(true)
			end
			expect(kinds.ammo).to.equal(1)
			expect(kinds.weapon).to.equal(2)
			expect(kinds.driveGun).to.equal(1)
			expect(kinds.hatColor).to.equal(1)
		end)
	end)

	describe("the refusal", function()
		it("lets a rich player at the counter buy, and answers no number for it", function()
			local reason, number = Shop.refuse(ctx())
			expect(reason).to.equal(nil)
			expect(number).to.equal(nil)
		end)

		it("answers each of the eight reasons, and the two that carry a number carry the right one", function()
			expect(Shop.refuse(ctx({ coinsOn = false }))).to.equal(Shop.REASON.CLOSED)
			expect(Shop.refuse(ctx({ itemId = "rifle.free" }))).to.equal(Shop.REASON.UNKNOWN)
			expect(Shop.refuse(ctx({ itemId = 7 }))).to.equal(Shop.REASON.UNKNOWN)
			expect(Shop.refuse(ctx({ itemId = Shop.ITEM.RIFLE_OPEN }))).to.equal(Shop.REASON.NOT_SALE)
			expect(Shop.refuse(ctx({ hasProfile = false }))).to.equal(Shop.REASON.NO_PROFILE)
			expect(Shop.refuse(ctx({ atCounter = false }))).to.equal(Shop.REASON.TOO_FAR)
			expect(Shop.refuse(ctx({ owned = { [Shop.ITEM.HAT_RED] = true } }))).to.equal(Shop.REASON.OWNED)

			local locked, shortHunts = Shop.refuse(ctx({ itemId = Shop.ITEM.RIFLE, hunts = 20 }))
			expect(locked).to.equal(Shop.REASON.LOCKED)
			expect(shortHunts).to.equal(5)

			local poor, shortCoins = Shop.refuse(ctx({ itemId = Shop.ITEM.RIFLE, balance = 1400 }))
			expect(poor).to.equal(Shop.REASON.POOR)
			expect(shortCoins).to.equal(100)

			-- ...AND THE LINES THOSE TWO NUMBERS GO INTO.
			expect(Shop.noticeFor(Shop.REASON.LOCKED, 5)).to.equal("LOCKED: 5 HUNTS")
			expect(Shop.noticeFor(Shop.REASON.POOR, 100)).to.equal("YOU NEED 100 COINS")
			expect(Shop.noticeFor(Shop.REASON.OWNED)).to.equal("YOU OWN IT")
			expect(Shop.noticeFor("not-a-reason")).to.equal(nil)
			-- Every reason has a line, and the order names every reason exactly once.
			local seen = {}
			for _, reason in ipairs(Shop.ORDER_OF_REFUSAL) do
				expect(Shop.NOTICE[reason]).to.be.ok()
				expect(seen[reason]).to.equal(nil)
				seen[reason] = true
			end
			for _, reason in pairs(Shop.REASON) do
				expect(seen[reason]).to.equal(true)
			end
		end)

		-- THE ORDER IS A RULE, and a rule nobody can assert is a rule that drifts (`Rules.ORDER`'s
		-- own words). Every question is tripped at once and the winner is named.
		it("asks the eight in one declared order", function()
			local all = ctx({
				coinsOn = false,
				hasProfile = false,
				atCounter = false,
				itemId = Shop.ITEM.RIFLE_OPEN,
				owned = { [Shop.ITEM.RIFLE_OPEN] = true },
				balance = 0,
				hunts = 0,
			})
			expect(Shop.refuse(all)).to.equal(Shop.REASON.CLOSED)
			all.coinsOn = true
			expect(Shop.refuse(all)).to.equal(Shop.REASON.NOT_SALE)
			all.itemId = Shop.ITEM.RIFLE
			expect(Shop.refuse(all)).to.equal(Shop.REASON.NO_PROFILE)
			all.hasProfile = true
			expect(Shop.refuse(all)).to.equal(Shop.REASON.TOO_FAR)
			all.atCounter = true
			all.owned = { [Shop.ITEM.RIFLE] = true }
			expect(Shop.refuse(all)).to.equal(Shop.REASON.OWNED)
			all.owned = {}
			expect(Shop.refuse(all)).to.equal(Shop.REASON.LOCKED)
			all.hunts = 25
			expect(Shop.refuse(all)).to.equal(Shop.REASON.POOR)
		end)

		-- NIL IS "NOTHING SAID" for the three injected facts, which is the call every gate in this
		-- repo makes: a caller that answered nothing has not said no.
		it("is not refused by a fact nobody answered", function()
			expect(Shop.refuse(ctx({ coinsOn = nil, hasProfile = nil, atCounter = nil }))).to.equal(nil)
			-- ...and `owned == nil` means HE OWNS NOTHING, here and only here: this function is asked
			-- "shall I take his money", and the safe answer to an unknown set is to let the purchase
			-- proceed and refuse the SECOND click off the set that was actually written.
			expect(Shop.refuse(ctx({ owned = nil }))).to.equal(nil)
		end)

		-- THE WINDOW AND THE TILL READ ONE TABLE, and this is the assertion. `rowsFor`'s `buyable`
		-- must equal `refuse(...) == nil` for the same facts, over a table of cases.
		it("agrees with the panel's own rows, case by case", function()
			local cases = {
				{ owned = {}, balance = 10000, hunts = 100, coinsOn = true },
				{ owned = {}, balance = 0, hunts = 0, coinsOn = true },
				{ owned = { [Shop.ITEM.SLUG] = true }, balance = 500, hunts = 4, coinsOn = true },
				{ owned = {}, balance = 2000, hunts = 24, coinsOn = true },
				{ owned = nil, balance = nil, hunts = 0, coinsOn = true },
				{ owned = {}, balance = 10000, hunts = 100, coinsOn = false },
			}
			for _, case in ipairs(cases) do
				local wire = Shop.rowsFor(case.owned, case.balance, case.hunts, case.coinsOn)
				expect(#wire).to.equal(#Shop.ORDER)
				for index, row in ipairs(wire) do
					expect(row.id).to.equal(Shop.ORDER[index])
					local refused = Shop.refuse({
						itemId = row.id,
						coinsOn = case.coinsOn,
						hasProfile = case.balance ~= nil,
						owned = case.owned,
						balance = case.balance,
						hunts = case.hunts,
					})
					expect(row.buyable).to.equal(refused == nil)
					expect(row.price).to.equal(Shop.ROWS[row.id].price)
					expect(row.label).to.equal(Shop.ROWS[row.id].label)
				end
			end
		end)
	end)

	describe("the wire", function()
		it("accepts exactly two kinds and two fields", function()
			expect(Shop.checkRequest(Shop.KIND.OPEN, nil)).to.equal(true)
			expect(Shop.checkRequest(Shop.KIND.BUY, Shop.ITEM.SLUG)).to.equal(true)
			-- AN ARGUMENT NOBODY READS IS AN ARGUMENT NOBODY CHECKED.
			expect(Shop.checkRequest(Shop.KIND.OPEN, Shop.ITEM.SLUG)).to.equal(false)
			expect(Shop.checkRequest("sell", Shop.ITEM.SLUG)).to.equal(false)
			expect(Shop.checkRequest(nil, nil)).to.equal(false)
			expect(Shop.checkRequest(7, nil)).to.equal(false)
			expect(Shop.checkRequest(Shop.KIND.BUY, nil)).to.equal(false)
			expect(Shop.checkRequest(Shop.KIND.BUY, 7)).to.equal(false)
			expect(Shop.checkRequest(Shop.KIND.BUY, "")).to.equal(false)
			-- A BOUND BEFORE THE TABLE LOOKUP, so a megabyte of string is never a key.
			expect(Shop.checkRequest(Shop.KIND.BUY, string.rep("x", Shop.CONFIG.MAX_ID_CHARS))).to.equal(true)
			expect(Shop.checkRequest(Shop.KIND.BUY, string.rep("x", Shop.CONFIG.MAX_ID_CHARS + 1))).to.equal(false)
			-- A WELL-FORMED ID NAMING NO ROW IS NOT A BAD REQUEST: it is `unknown-item`, counted
			-- apart, because a stale client is not a forged packet.
			expect(Shop.checkRequest(Shop.KIND.BUY, "rifle.free")).to.equal(true)
			expect(Shop.refuse(ctx({ itemId = "rifle.free" }))).to.equal(Shop.REASON.UNKNOWN)
		end)

		it("carries no price inbound: the only price is the catalogue's", function()
			-- The request type has two fields, and a forged third is simply not read. The proof that
			-- a price cannot cross is this: `checkRequest` takes a KIND and an ITEM, and nothing in
			-- `Shop.refuse` or `Economy.purchase` reads a price from anywhere but `Shop.ROWS`.
			expect(Shop.checkRequest(Shop.KIND.BUY, Shop.ITEM.RIFLE)).to.equal(true)
			expect(Shop.row(Shop.ITEM.RIFLE).price).to.equal(1500)
		end)
	end)

	describe("the counter's reach", function()
		it("is flat, inclusive on the line, and false when there is no counter", function()
			local at = Vector3.new(100, 0, 100)
			expect(Shop.withinReach(Vector3.new(113, 40, 100), at, 14)).to.equal(true)
			expect(Shop.withinReach(Vector3.new(114, 0, 100), at, 14)).to.equal(true)
			expect(Shop.withinReach(Vector3.new(114.1, 0, 100), at, 14)).to.equal(false)
			-- A WORLD WITH NO LODGE HAS NO SHOP, which is exactly what the DEV place is.
			expect(Shop.withinReach(Vector3.new(100, 0, 100), nil, 14)).to.equal(false)
			expect(Shop.withinReach(nil, at, 14)).to.equal(false)
			expect(Shop.CONFIG.REACH_STUDS).to.equal(14)
		end)

		-- ONE SUBTRACTION, WRITTEN TWICE, AND THIS IS THE GUARD ON IT (design section 4.4):
		-- `Lobby.Join.within` is a SERVER module and a shared module may not require one, so the
		-- shop's boundary carries its own arithmetic -- and a spec that requires both is the
		-- cheapest check that they answer the same thing. (The third copy,
		-- `ForestTest.withinStand`, takes a STAND INDEX rather than a centre and a radius, so it
		-- cannot be driven from here; folding all three into one shared predicate is queued for the
		-- Director, design 16 item 11.)
		it("still answers the same three cases now the lobby's own test is a rectangle", function()
			-- TASK 182 TOOK THE SECOND COPY AWAY RATHER THAN KEEPING IT IN STEP. `Join.within` was
			-- the lobby's CIRCLE and this case compared the two circles; the lobby's pads are
			-- RECTANGLES now (`Join.withinRect`), so there is no second radius in the repository to
			-- agree with. What is left to guard is the shop's own reach, and the three cases are kept
			-- verbatim so the counter's boundary is still stated here.
			--
			-- THE THIRD COPY, `ForestTest.withinStand`, is still a radius and still takes a STAND
			-- INDEX rather than a centre, so it cannot be driven from here either; folding what
			-- remains into one shared predicate stays queued for the Director
			-- (`docs/design/shop.md` 16 item 11).
			local centre = Vector3.new(0, 0, 0)
			for _, case in ipairs({
				{ at = Vector3.new(5, 12, 0), inside = true },
				{ at = Vector3.new(10, 0, 0), inside = true },
				{ at = Vector3.new(10.5, 0, 0), inside = false },
			}) do
				expect(Shop.withinReach(case.at, centre, 10)).to.equal(case.inside)
			end
			-- ...AND THE RECTANGLE IS FLAT AND INCLUSIVE IN THE SAME WAY, which is the property the
			-- two predicates really shared.
			local size = Vector3.new(20, 1, 20)
			expect(Join.withinRect(Vector3.new(10, 12, 0), centre, size)).to.equal(true)
			expect(Join.withinRect(Vector3.new(10.5, 0, 0), centre, size)).to.equal(false)
		end)
	end)

	describe("what ownership gives", function()
		it("puts a bought weapon in the loadout and never takes the shotgun away", function()
			-- nil IS UNRESTRICTED: today's list, which is what every world that wired no provider
			-- gets -- including every weapon spec.
			local unrestricted = Weapons.loadoutFor(true, nil)
			expect(#unrestricted).to.equal(2)
			expect(unrestricted[1]).to.equal("shotgun")
			expect(unrestricted[2]).to.equal("rifle")
			-- A set that owns nothing: the shotgun alone, which is Karen's *"default is double barrel
			-- shotgun"*.
			local bare = Weapons.loadoutFor(true, {})
			expect(#bare).to.equal(1)
			expect(bare[1]).to.equal("shotgun")
			-- ...and the rifle once it is bought.
			local bought = Weapons.loadoutFor(true, { [Shop.ITEM.RIFLE] = true })
			expect(#bought).to.equal(2)
			expect(bought[2]).to.equal("rifle")
			-- AN ITEM THAT GRANTS A WEAPON NO BUILD SHIPS GRANTS NOTHING, which is the other half of
			-- why it is not for sale.
			local pretend = Weapons.loadoutFor(true, { [Shop.ITEM.RIFLE_OPEN] = true })
			expect(#pretend).to.equal(1)
			-- THE FLAG STILL WINS FIRST: off is one weapon whatever he owns.
			expect(#Weapons.loadoutFor(false, { [Shop.ITEM.RIFLE] = true })).to.equal(1)
			expect(Shop.ownsWeapon({ [Shop.ITEM.RIFLE] = true }, "rifle")).to.equal(true)
			expect(Shop.ownsWeapon({}, "rifle")).to.equal(false)
			expect(Shop.ownsWeapon(nil, "rifle")).to.equal(false)
		end)

		it("issues buckshot until the slug is bought, and the weapon's own row when nobody has said", function()
			-- KAREN'S LADDER: *"shotgun buckshot (default) -> slugs"*.
			local bare = Shop.startFor(SHOTGUN, {})
			expect(bare.ammo).to.equal("Buck")
			expect(bare.reserve.Buck).to.equal(SHOTGUN.START_RESERVE.Buck)
			expect(bare.reserve.Slug).to.equal(0)

			local bought = Shop.startFor(SHOTGUN, { [Shop.ITEM.SLUG] = true })
			expect(bought.ammo).to.equal(SHOTGUN.INITIAL_AMMO)
			expect(bought.reserve.Slug).to.equal(SHOTGUN.START_RESERVE.Slug)
			expect(bought.reserve.Buck).to.equal(SHOTGUN.START_RESERVE.Buck)

			-- nil: UNRESTRICTED, bit for bit the gun before this task.
			local unrestricted = Shop.startFor(SHOTGUN, nil)
			expect(unrestricted.ammo).to.equal(SHOTGUN.INITIAL_AMMO)
			expect(unrestricted.reserve.Slug).to.equal(SHOTGUN.START_RESERVE.Slug)

			-- THE RIFLE'S OWN SHELL IS FREE WITH THE RIFLE: it is a 1500-coin purchase, and selling a
			-- man a rifle and then no rounds for it would be the shop taking money for nothing.
			local rifle = Shop.startFor(RIFLE, {})
			expect(rifle.ammo).to.equal(RIFLE.INITIAL_AMMO)
			expect(rifle.reserve.Slug).to.equal(RIFLE.START_RESERVE.Slug)
		end)

		-- THE POCKET IS THE ENFORCEMENT AND THERE IS NO SECOND GATE: `StateMachine` already refuses
		-- an empty pocket, so an unowned slug is simply never issued.
		it("starts a state on the allowance, and the switch to an unowned shell is refused", function()
			local bare = StateMachine.initial(SHOTGUN, Shop.startFor(SHOTGUN, {}))
			expect(bare.ammo).to.equal("Buck")
			expect(bare.loaded[1]).to.equal("Buck")
			expect(bare.reserve.Slug).to.equal(0)
			-- ...and the gun he has today, when nobody has said anything.
			local today = StateMachine.initial(SHOTGUN)
			expect(today.ammo).to.equal(SHOTGUN.INITIAL_AMMO)
			expect(today.reserve.Slug).to.equal(SHOTGUN.START_RESERVE.Slug)

			-- THE REFILL CARRIES THE SAME ALLOWANCE, on the action, and `Refill` is server-side by
			-- construction (`Validator.checkRequest` accepts only Reload and SelectAmmo from a
			-- client). A bought slug pocket arrives at the next drive's refill; an unbought one
			-- stays at zero, which is what `Load` already refuses with `no-reserve`.
			local refilled = StateMachine.apply(
				bare,
				{ kind = "Refill", reserve = Shop.startFor(SHOTGUN, { [Shop.ITEM.SLUG] = true }).reserve },
				0,
				SHOTGUN
			)
			expect(refilled.reserve.Slug).to.equal(SHOTGUN.START_RESERVE.Slug)
			local stillBare =
				StateMachine.apply(bare, { kind = "Refill", reserve = Shop.startFor(SHOTGUN, {}).reserve }, 0, SHOTGUN)
			expect(stillBare.reserve.Slug).to.equal(0)
			expect(stillBare.reserve.Buck).to.equal(SHOTGUN.START_RESERVE.Buck)
		end)

		it("gives a beater a gun only with the licence, and nil is refused", function()
			-- THE ONE READER WHOSE DEFAULT IS "REFUSED", because today a beater carries no gun.
			expect(Shop.grantsDriveGun(nil)).to.equal(false)
			expect(Shop.grantsDriveGun({})).to.equal(false)
			expect(Shop.grantsDriveGun({ [Shop.ITEM.BEATER_LICENCE] = true })).to.equal(true)
			-- AND THE DRIVE ASKS EXACTLY THAT QUESTION, through its own pure `Match.mayCarryFor` --
			-- which is where the four cases that can FAIL live (`match_teams.spec`, "a beater may
			-- carry a gun only with the licence"), because the Reviewer's round-1 finding was that
			-- this line proved nothing: it would pass with the whole feature deleted.
			expect(
				Match.mayCarryFor({ phase = "Running", team = "Drivers", owned = nil }, { DRIVERS_MAY_SHOOT = false })
			).to.equal(false)
			expect(
				Match.mayCarryFor(
					{ phase = "Running", team = "Drivers", owned = { [Shop.ITEM.BEATER_LICENCE] = true } },
					{ DRIVERS_MAY_SHOOT = false }
				)
			).to.equal(true)
		end)

		it("colours the hat only when a hat is bought", function()
			expect(Shop.hatColorFor(nil)).to.equal(nil)
			expect(Shop.hatColorFor({})).to.equal(nil)
			local red = Shop.hatColorFor({ [Shop.ITEM.HAT_RED] = true })
			expect(red).to.equal(Shop.ROWS[Shop.ITEM.HAT_RED].grants.hatColor)
			-- ...AND IT REACHES THE OUTFIT, through the one pure translator the dresser reads.
			expect(Body.tintFor(Body.SLOTS.hat, { hatColor = red })).to.equal(red)
			-- THE VEST IS NOT RECOLOURED: both roles wear safety orange in the field.
			expect(Body.tintFor(Body.SLOTS.vest, { hatColor = red })).to.equal(nil)
			expect(Body.tintFor(Body.SLOTS.hat, nil)).to.equal(nil)

			-- THE ROWS THE DRESSER WOULD BUILD: the hat takes the bought colour and nothing else
			-- moves. `OUTFITS_ENABLED` is read from a config table, so both branches are reachable.
			local config = { OUTFITS_ENABLED = true }
			local plain = Body.dressFor("Shooters", config)
			local bought = Body.dressFor("Shooters", config, { hatColor = red })
			expect(#bought).to.equal(#plain)
			for index, row in ipairs(bought) do
				expect(row.name).to.equal(plain[index].name)
				if string.find(row.name, "Hat") then
					expect(row.color).to.equal(red)
				else
					expect(row.color).to.equal(plain[index].color)
				end
			end
			-- AND THE DECLARED ROWS ARE UNTOUCHED: a bought colour belongs to one player, so the
			-- tinted row is a COPY.
			expect(plain[1].color).never.to.equal(red)
		end)
	end)
end
