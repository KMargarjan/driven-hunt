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
-- WHICH ANIMALS THIS BUILD ACTUALLY SHIPS (task 221): `rowsOk`'s I3a reads it, and it is what holds
-- the RED STAG CARD shut.
local Licences = require(ReplicatedStorage:WaitForChild("Licences"))

local Body = Match.Body
local Join = require(ServerScriptService:WaitForChild("Lobby")).Join
local StateMachine = Weapon.StateMachine
local SHOTGUN = Weapons.ROWS.shotgun
local RIFLE = Weapons.ROWS.rifle

-- A full wallet with nothing bought, so a case says only what it changes.
-- NOT_SALE, DRIVEN AGAINST A PRETEND CATALOGUE (task 196). Karen removed the one row that was shown
-- and never sold (*"remove rifle without scope soon don't need"*), so the reason has no shipped row
-- to prove it with -- and it is still a reason `Shop.refuse` answers and the panel draws. Every row
-- is copied with `sale = false`, the real table is put back whatever happens, and what is asserted
-- is the function rather than the catalogue.
local function refuseUnsellable(context): (string?, number?)
	local pretend = {}
	for id, row in pairs(Shop.ROWS) do
		local copy = table.clone(row)
		copy.grants = table.clone(row.grants)
		copy.sale = false
		pretend[id] = copy
	end
	local saved = Shop.ROWS;
	(Shop :: any).ROWS = pretend
	local reason, number = Shop.refuse(context);
	(Shop :: any).ROWS = saved
	return reason, number
end

local function ctx(over)
	local base = {
		itemId = Shop.ITEM.SLUG,
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
		it("is Karen's v1 list, frozen, cheapest first, and no row can be edited at run time", function()
			-- KAREN, 2026-10-20: *"It will be for sale in v1: - Access to tree stand - Rifle -
			-- Unlimited amunition - Red stag card - Beater can shoot in drive - Posibility to be a
			-- hunter always - We can also make a few packages bundles"*. TEN ROWS: her seven items
			-- plus three packages. The RED HAT is not one of them -- *"From shop remove red heat"* --
			-- and it is in `Shop.RETIRED` instead, still granting to whoever bought one.
			-- ELEVEN SINCE TASK 224 (the lever rifle), TWELVE SINCE TASK 225 (the semi-automatic
			-- shotgun, at 500, between the beater's licence and THE HIDE).
			--
			-- TWELVE IS `Shop.CONFIG.MAX_ITEMS`, so THIS ROW TAKES THE LAST SLOT and the next
			-- catalogue row needs that number moved. Said here, where the count is asserted, so it
			-- arrives as a one-line decision rather than as a red harness.
			expect(#Shop.ORDER).to.equal(12)
			expect(#Shop.ORDER).to.equal(Shop.CONFIG.MAX_ITEMS)
			expect(Shop.ORDER[1]).to.equal(Shop.ITEM.SLUG)
			expect(Shop.ORDER[2]).to.equal(Shop.ITEM.BEATER_LICENCE)
			expect(Shop.ORDER[3]).to.equal(Shop.ITEM.SEMIAUTO)
			expect(Shop.ORDER[4]).to.equal(Shop.ITEM.BUNDLE_HIDE)
			expect(Shop.ORDER[5]).to.equal(Shop.ITEM.HIGH_SEAT)
			-- TASK 224: the lever rifle at 650 lands between the high seat's 600 and the deer
			-- licence's 750, because `Shop.ORDER` is cheapest-first and the case below asserts it.
			-- EVERY INDEX FROM HERE ON MOVED UP ONE IN TASK 225, which is what inserting a 500-coin
			-- row into a cheapest-first list does.
			expect(Shop.ORDER[6]).to.equal(Shop.ITEM.LEVER)
			expect(Shop.ORDER[7]).to.equal(Shop.ITEM.RED_STAG)
			expect(Shop.ORDER[8]).to.equal(Shop.ITEM.UNLIMITED_AMMO)
			expect(Shop.ORDER[9]).to.equal(Shop.ITEM.RIFLE)
			expect(Shop.ORDER[10]).to.equal(Shop.ITEM.BUNDLE_MARKSMAN)
			expect(Shop.ORDER[11]).to.equal(Shop.ITEM.ALWAYS_HUNTER)
			expect(Shop.ORDER[12]).to.equal(Shop.ITEM.BUNDLE_SEASON)
			expect((Shop.ITEM :: any).RIFLE_OPEN).to.equal(nil)
			-- THE RED HAT IS OFF THE SHELF AND STILL IN THE BUILD (task 221).
			expect(Shop.ROWS[Shop.ITEM.HAT_RED]).to.equal(nil)
			expect(Shop.anyRow(Shop.ITEM.HAT_RED)).to.be.ok()
			expect(Shop.isRetired(Shop.ITEM.HAT_RED)).to.equal(true)
			expect(Shop.isRetired(Shop.ITEM.SLUG)).to.equal(false)
			-- CHEAPEST FIRST, so a player with $120 sees something he can buy at the top.
			local previous = -1
			for _, id in ipairs(Shop.ORDER) do
				local row = Shop.ROWS[id]
				expect(row.price >= previous).to.equal(true)
				previous = row.price
			end
			-- The prices Karen decides later, written down so a change to one of them fails here
			-- rather than drifting (docs/design/economy-v1.md section 11).
			expect(Shop.ROWS[Shop.ITEM.SLUG].price).to.equal(120)
			expect(Shop.ROWS[Shop.ITEM.BEATER_LICENCE].price).to.equal(250)
			expect(Shop.ROWS[Shop.ITEM.BEATER_LICENCE].hunts).to.equal(3)
			expect(Shop.ROWS[Shop.ITEM.BUNDLE_HIDE].price).to.equal(575)
			expect(Shop.ROWS[Shop.ITEM.HIGH_SEAT].price).to.equal(600)
			expect(Shop.ROWS[Shop.ITEM.HIGH_SEAT].hunts).to.equal(5)
			expect(Shop.ROWS[Shop.ITEM.RED_STAG].price).to.equal(750)
			expect(Shop.ROWS[Shop.ITEM.UNLIMITED_AMMO].price).to.equal(900)
			expect(Shop.ROWS[Shop.ITEM.UNLIMITED_AMMO].hunts).to.equal(10)
			-- UNCHANGED BY TASK 221, and that is the assertion: Karen's *"has to play a lot it's not
			-- few hunts"* is the rifle's gate and the Builder does not get to move it.
			expect(Shop.ROWS[Shop.ITEM.RIFLE].price).to.equal(1500)
			expect(Shop.ROWS[Shop.ITEM.RIFLE].hunts).to.equal(25)
			expect(Shop.ROWS[Shop.ITEM.BUNDLE_MARKSMAN].price).to.equal(1800)
			expect(Shop.ROWS[Shop.ITEM.ALWAYS_HUNTER].price).to.equal(2000)
			expect(Shop.ROWS[Shop.ITEM.ALWAYS_HUNTER].hunts).to.equal(30)
			expect(Shop.ROWS[Shop.ITEM.BUNDLE_SEASON].price).to.equal(3750)
			-- The rules of the game are not writable at run time: the discipline every frozen table
			-- in this repo follows, and `deepFreeze` is what makes it reach the rows.
			expect(table.isfrozen(Shop.ROWS)).to.equal(true)
			expect(table.isfrozen(Shop.RETIRED)).to.equal(true)
			expect(table.isfrozen(Shop.CONFIG)).to.equal(true)
			expect(function()
				(Shop.ROWS[Shop.ITEM.RIFLE] :: any).price = 1
			end).to.throw()
			expect(function()
				(Shop.CONFIG.PANEL :: any).WIDTH = 1
			end).to.throw()
		end)

		-- THE ROW KAREN ASKED FOR, AND IT IS BUYABLE SINCE TASK 223 BECAUSE THE ANIMAL EXISTS.
		--
		-- IT IS THE SAME INVARIANT AS TASK 221'S, SATISFIED RATHER THAN WEAKENED, and this case
		-- still drives BOTH arms: the shipped catalogue passes, and a hand-made one whose species
		-- is not shipped is still refused by name. That second half is the half that could rot.
		it("sells the deer licence, and would still refuse one for an animal nobody ships", function()
			local row = Shop.ROWS[Shop.ITEM.RED_STAG]
			expect(row.sale).to.equal(true)
			expect(row.grants.licence).to.equal("reddeer")
			-- IT COVERS THE WHOLE SPECIES, so it may not be named for one of its three animals.
			expect(row.label).to.equal("DEER LICENCE")
			-- THE RED DEER IS IN THIS GAME, and that is the fact the shop reads.
			expect(Licences.ROWS.reddeer.shipped).to.equal(true)
			expect(Licences.ROWS.boar.shipped).to.equal(true)
			expect(Shop.refuse(ctx({ itemId = Shop.ITEM.RED_STAG }))).never.to.equal(Shop.REASON.NOT_SALE)
			-- ...AND I3a IS STILL WHAT STOPS SOMEBODY SELLING A LICENCE FOR AN ANIMAL THAT IS NOT
			-- THERE. `Licences.ROWS` has known `reddeer` since task 171, so a check that only asked
			-- *does the table know it* would PASS even then -- which is why `shipped` exists.
			-- Driven against a pretend licence table, because no shipped row is in that state.
			local pretend = {}
			for name, existing in pairs(Licences.ROWS) do
				local copy = table.clone(existing)
				copy.shipped = false
				pretend[name] = copy
			end
			local broken = Shop.rowsOk(Weapons.ROWS, SHOTGUN.AMMO_KINDS, pretend)
			expect(#broken).to.equal(1)
			expect(string.find(broken[1], "reddeer") ~= nil).to.equal(true)
		end)

		-- I1, I2 AND I3 IN ONE CALL (design section 5.5). The third is the one that matters: a row
		-- FOR SALE can actually be granted, which is what forces the red stag card's `sale = false`
		-- rather than a comment asking for it.
		it("is legal against the weapons and the animals this build ships", function()
			local problems = Shop.rowsOk(Weapons.ROWS, SHOTGUN.AMMO_KINDS, Licences.ROWS)
			expect(#problems).to.equal(0)
			expect(#Shop.ORDER <= Shop.CONFIG.MAX_ITEMS).to.equal(true)
			-- EVERY SHOWN ROW IS SELLABLE SINCE TASK 223. Task 221's one exception was the red
			-- stag card, and the animal it waited for arrived; `sale` is kept for the next rung
			-- announced before it ships, and the case above is what proves it still bites.
			local notForSale = {}
			for _, id in ipairs(Shop.ORDER) do
				if Shop.ROWS[id].sale ~= true then
					table.insert(notForSale, id)
				end
			end
			expect(#notForSale).to.equal(0)
			-- EVERY ROBUX PRODUCT ID IS nil IN THIS BUILD (task 221, I12): there are no products
			-- yet, and a fabricated id is a shop window that lies. Task 222 is what fills them.
			for _, id in ipairs(Shop.ALL_ORDER) do
				expect(Shop.anyRow(id).robuxProductId).to.equal(nil)
			end
			-- ...AND THE INVARIANT IS STILL WHAT SAYS A ROW MAY NOT GRANT WHAT NO BUILD SHIPS. The
			-- weapon `rifleOpen` was retired in task 148 and `Weapons.ROWS` has never had it back,
			-- so a catalogue that offered it for sale is exactly the illegal case -- driven here
			-- against a PRETEND catalogue, because no shipped row is in that state any more.
			expect(Weapons.row("rifleOpen")).to.equal(nil)
			local pretend = {}
			for id, row in pairs(Shop.ROWS) do
				local copy = table.clone(row)
				copy.grants = table.clone(row.grants)
				pretend[id] = copy
			end
			pretend[Shop.ITEM.RIFLE].grants = { weapon = "rifleOpen" }
			local saved = Shop.ROWS;
			(Shop :: any).ROWS = pretend
			local broken = Shop.rowsOk(Weapons.ROWS, SHOTGUN.AMMO_KINDS, Licences.ROWS);
			(Shop :: any).ROWS = saved
			-- THE MARKSMAN AND THE FULL SEASON COVER THE RIFLE, so breaking its grant breaks their
			-- merge too (I11) -- which is the bundle invariant doing its job, not noise.
			expect(#broken >= 1).to.equal(true)
			local named = false
			for _, problem in ipairs(broken) do
				if string.find(problem, "rifleOpen") ~= nil then
					named = true
				end
			end
			expect(named).to.equal(true)
		end)

		-- ---------------------------------------------------------------- the packages (task 221)

		it("prices a package under its parts, gates it at the highest of them, and merges their grants", function()
			for _, id in ipairs({ Shop.ITEM.BUNDLE_HIDE, Shop.ITEM.BUNDLE_MARKSMAN, Shop.ITEM.BUNDLE_SEASON }) do
				local row = Shop.ROWS[id]
				expect(row.category).to.equal(Shop.CATEGORY.BUNDLE)
				expect(#row.covers >= 2).to.equal(true)
				local sum, highest = 0, 0
				for _, covered in ipairs(row.covers) do
					local part = Shop.ROWS[covered]
					expect(part).to.be.ok()
					expect(part.covers).to.equal(nil) -- NO NESTING
					expect(part.sale).to.equal(true)
					sum += part.price
					highest = math.max(highest, part.hunts)
				end
				-- I10: A PACKAGE THAT IS NOT CHEAPER THAN ITS PARTS IS NOT A PACKAGE.
				expect(row.price < sum).to.equal(true)
				-- I9: AND IT IS NOT THE WAY ROUND KAREN'S LADDER EITHER.
				expect(row.hunts >= highest).to.equal(true)
				-- I11: THE GRANTS ARE THE MERGE, not a hand-written copy of it.
				local merged = Shop.mergedGrants(row.covers)
				expect(merged).to.be.ok()
				for _, field in ipairs(Shop.GRANT_FIELDS) do
					expect((row.grants :: any)[field]).to.equal((merged :: any)[field])
				end
			end
			-- THE MEASURED DISCOUNTS (design section 11).
			expect(Shop.ROWS[Shop.ITEM.BUNDLE_HIDE].price).to.equal(575) -- 20% of 720
			expect(Shop.ROWS[Shop.ITEM.BUNDLE_MARKSMAN].price).to.equal(1800) -- 25% of 2400
			expect(Shop.ROWS[Shop.ITEM.BUNDLE_SEASON].price).to.equal(3750) -- 30% of 5370
			-- A PACKAGE GRANTS WHAT ITS PARTS GRANT, through the readers that already existed.
			local season = { [Shop.ITEM.BUNDLE_SEASON] = true }
			expect(Shop.ownsWeapon(season, "rifle")).to.equal(true)
			expect(Shop.grantsDriveGun(season)).to.equal(true)
			expect(Shop.grantsHighSeat(season)).to.equal(true)
			expect(Shop.grantsUnlimitedAmmo(season)).to.equal(true)
			expect(Shop.grantsAlwaysHunter(season)).to.equal(true)
			-- A CONFLICT IS REFUSED AND NEVER DECIDED BY `covers` ORDER.
			local conflict, problem = Shop.mergedGrants({ Shop.ITEM.SLUG, Shop.ITEM.RED_STAG, Shop.ITEM.SLUG })
			expect(conflict).to.be.ok() -- the same value twice is not a conflict
			expect(problem).to.equal(nil)
			expect(Shop.mergedGrants({ "no.such.row" })).to.equal(nil)
			-- WHAT IS IN IT IS ON SCREEN: the composed blurb names every part, and it still fits.
			local shown = Shop.blurbFor(Shop.ROWS[Shop.ITEM.BUNDLE_SEASON])
			expect(#shown <= Shop.CONFIG.PANEL.BLURB_MAX).to.equal(true)
			for _, covered in ipairs(Shop.ROWS[Shop.ITEM.BUNDLE_SEASON].covers) do
				expect(string.find(shown, Shop.ROWS[covered].label, 1, true) ~= nil).to.equal(true)
			end
		end)

		it("never charges twice for a thing a package already gave him", function()
			local marksman = { [Shop.ITEM.BUNDLE_MARKSMAN] = true }
			-- THE RIFLE IS HIS, so the till refuses it and the window says IN YOUR KIT.
			expect(Shop.ownedOrCovered(marksman, Shop.ITEM.RIFLE)).to.equal(true)
			expect(Shop.ownedOrCovered(marksman, Shop.ITEM.UNLIMITED_AMMO)).to.equal(true)
			expect(Shop.ownedOrCovered(marksman, Shop.ITEM.SLUG)).to.equal(false)
			expect(Shop.refuse(ctx({ owned = marksman, itemId = Shop.ITEM.RIFLE }))).to.equal(Shop.REASON.OWNED)
			local wire = Shop.rowsFor(marksman, 10000, 100, true)
			for _, row in ipairs(wire) do
				if row.id == Shop.ITEM.RIFLE then
					expect(row.owned).to.equal(true)
					expect(row.buyable).to.equal(false)
				end
			end
			-- ...AND A PACKAGE HE IS ALREADY FULLY COVERED FOR IS REFUSED TOO, which is the one case
			-- `rowsOk` cannot see.
			local parts = { [Shop.ITEM.RIFLE] = true, [Shop.ITEM.UNLIMITED_AMMO] = true }
			expect(Shop.fullyCovered(parts, Shop.ITEM.BUNDLE_MARKSMAN)).to.equal(true)
			expect(Shop.refuse(ctx({ owned = parts, itemId = Shop.ITEM.BUNDLE_MARKSMAN }))).to.equal(Shop.REASON.OWNED)
			-- PARTIAL OVERLAP STAYS BUYABLE: the discount is still a discount.
			local rifleOnly = { [Shop.ITEM.RIFLE] = true }
			expect(Shop.fullyCovered(rifleOnly, Shop.ITEM.BUNDLE_MARKSMAN)).to.equal(false)
			expect(Shop.refuse(ctx({ owned = rifleOnly, itemId = Shop.ITEM.BUNDLE_MARKSMAN }))).to.equal(nil)
			-- `fullyCovered` IS FALSE FOR A ROW THAT IS NOT A PACKAGE: "every part of nothing" is a
			-- vacuous truth and would refuse a row nobody owns.
			expect(Shop.fullyCovered({}, Shop.ITEM.SLUG)).to.equal(false)
		end)

		it("keeps granting a row it no longer sells, and refuses to sell it", function()
			-- KAREN, 2026-10-20: *"From shop remove red heat"*. The money was spent; the hat stays.
			local wearer = { [Shop.ITEM.HAT_RED] = true }
			expect(Shop.hatColorFor(wearer)).to.equal(Shop.RETIRED[Shop.ITEM.HAT_RED].grants.hatColor)
			-- IT IS INVISIBLE TO THE PANEL...
			for _, row in ipairs(Shop.rowsFor(wearer, 10000, 100, true)) do
				expect(row.id).never.to.equal(Shop.ITEM.HAT_RED)
			end
			for _, id in ipairs(Shop.menuOrder(Shop.rowsFor(wearer, 10000, 100, true))) do
				expect(id).never.to.equal(Shop.ITEM.HAT_RED)
			end
			-- ...AND UNBUYABLE AT THE DOOR, as an UNKNOWN item rather than as a new wire reason.
			expect(Shop.row(Shop.ITEM.HAT_RED)).to.equal(nil)
			expect(Shop.refuse(ctx({ itemId = Shop.ITEM.HAT_RED }))).to.equal(Shop.REASON.UNKNOWN)
			-- I6: THE TWO TABLES ARE DISJOINT AND `ALL_ORDER` NAMES BOTH.
			expect(#Shop.ALL_ORDER).to.equal(#Shop.ORDER + #Shop.RETIRED_ORDER)
			local seen = {}
			for _, id in ipairs(Shop.ALL_ORDER) do
				expect(seen[id]).to.equal(nil)
				seen[id] = true
				expect(Shop.anyRow(id)).to.be.ok()
			end
		end)

		it("knows every field its own rows grant", function()
			-- BOTH DIRECTIONS (task 221). `grantsAnything` loops `GRANT_FIELDS`, and this is the
			-- other half: a ninth field added to a row and not to the list fails here rather than
			-- sitting invisible to every reader.
			local known = {}
			for _, field in ipairs(Shop.GRANT_FIELDS) do
				known[field] = true
			end
			for _, id in ipairs(Shop.ALL_ORDER) do
				for field in pairs(Shop.anyRow(id).grants) do
					expect(known[field]).to.equal(true)
				end
			end
			expect(Shop.grantsAnything({})).to.equal(false)
			expect(Shop.grantsAnything(nil)).to.equal(false)
			expect(Shop.grantsAnything({ highSeat = true })).to.equal(true)
		end)

		it("answers today's game for a set nobody filled in", function()
			-- THE EIGHT NIL RULES (design section 5.6), and they are NOT the same boolean: an
			-- un-wired world must arm no beater and put nobody on `Shooters`, but must still deal
			-- the stands exactly as it does today.
			expect(Shop.grantsHighSeat(nil)).to.equal(true)
			expect(Shop.grantsHighSeat({})).to.equal(false)
			expect(Shop.grantsUnlimitedAmmo(nil)).to.equal(false)
			expect(Shop.grantsAlwaysHunter(nil)).to.equal(false)
			expect(Shop.grantsDriveGun(nil)).to.equal(false)
			expect(Shop.hatColorFor(nil)).to.equal(nil)
			expect(Shop.licencesFor(nil)).to.equal(nil)
			local held = Shop.licencesFor({ [Shop.ITEM.RED_STAG] = true })
			expect(held).to.be.ok()
			expect((held :: any).reddeer).to.equal(true)
		end)

		-- ---------------------------------------------------------------- the four shelves (task 196)

		-- KAREN, 2026-10-15: *"side menu with click and then shows in right side image and explanation
		-- what is that"*. The side menu is a pure function of what the server sent, so what it draws
		-- is asserted here and not only on the screen.
		it("sorts the catalogue onto its shelves, cheapest first inside each one", function()
			local wire = Shop.rowsFor(nil, 1000, 30, true)
			local groups = Shop.groups(wire)
			-- FIVE SHELVES DRAWN OF SIX DECLARED (task 221), in the order the panel draws them. The
			-- sixth is CLOTHING, and it is drawn by nobody because its one row is RETIRED -- which
			-- is `Shop.groups`' own rule (*"an EMPTY shelf is dropped rather than drawn as a header
			-- with nothing under it"*) proving itself on the live catalogue.
			expect(#Shop.CATEGORY_ORDER).to.equal(6)
			expect(#groups).to.equal(5)
			expect(groups[1].category).to.equal(Shop.CATEGORY.WEAPON)
			expect(groups[1].label).to.equal("WEAPONS")
			expect(groups[2].category).to.equal(Shop.CATEGORY.AMMO)
			expect(groups[3].category).to.equal(Shop.CATEGORY.LICENCE)
			expect(groups[4].category).to.equal(Shop.CATEGORY.ACCESS)
			-- PACKAGES IS LAST, which is Karen's own *"we can ALSO make a few packages"*.
			expect(groups[5].category).to.equal(Shop.CATEGORY.BUNDLE)
			expect(groups[5].label).to.equal("PACKAGES")
			for _, group in ipairs(groups) do
				expect(#group.rows > 0).to.equal(true)
			end
			-- EVERY ROW IS ON EXACTLY ONE SHELF: nothing is dropped and nothing is drawn twice, which
			-- is what `rowsOk`'s shelf check is there to keep true.
			local seen = {}
			local total = 0
			for _, group in ipairs(groups) do
				for _, row in ipairs(group.rows) do
					expect(seen[row.id]).to.equal(nil)
					seen[row.id] = true
					total += 1
				end
			end
			expect(total).to.equal(#Shop.ORDER)
			-- ...AND THE PANEL'S OWN ORDER IS THAT LIST FLATTENED, which is what decides the item a
			-- freshly opened panel shows.
			local order = Shop.menuOrder(wire)
			expect(#order).to.equal(#Shop.ORDER)
			expect(order[1]).to.equal(groups[1].rows[1].id)
			-- INSIDE A SHELF THE WIRE'S OWN ORDER SURVIVES, and the wire is `Shop.ORDER`: cheapest
			-- first. THE WEAPONS SHELF HELD ONE ROW FROM TASK 196 TO TASK 224 -- and the case's own
			-- comment then said *"the ordering it was written for comes back with the next weapon"*.
			-- It has, and THREE ROWS SINCE TASK 225: the semi-automatic shotgun is 500, the lever
			-- rifle 650 and the scoped rifle 1500, so the shelf is three rows cheapest-first and
			-- this assertion is doing the job it was written for twice over.
			expect(#groups[1].rows).to.equal(3)
			expect(groups[1].rows[1].id).to.equal(Shop.ITEM.SEMIAUTO)
			expect(groups[1].rows[2].id).to.equal(Shop.ITEM.LEVER)
			expect(groups[1].rows[3].id).to.equal(Shop.ITEM.RIFLE)
			-- ...AND A SHELF WITH THREE ROWS KEEPS THE WIRE'S CHEAPEST-FIRST ORDER, which is the
			-- ordering the case above was written for and could not show with one row.
			local packages = groups[5].rows
			expect(#packages).to.equal(3)
			expect(packages[1].id).to.equal(Shop.ITEM.BUNDLE_HIDE)
			expect(packages[2].id).to.equal(Shop.ITEM.BUNDLE_MARKSMAN)
			expect(packages[3].id).to.equal(Shop.ITEM.BUNDLE_SEASON)
			-- NOTHING IN, NOTHING OUT.
			expect(#Shop.groups(nil)).to.equal(0)
			expect(#Shop.menuOrder(nil)).to.equal(0)
		end)

		-- I4 AND I5: a shelf the menu draws, and an explanation to read in the detail pane. Both are
		-- `rowsOk` problems rather than comments, for `Weapons`'s own stated reason -- an item on a
		-- shelf nothing draws is an item that silently does not exist.
		it("refuses a row with no shelf, no explanation, or one too long to fit a phone", function()
			local function withRow(id: string, change: (any) -> ()): { string }
				local pretend = {}
				for key, row in pairs(Shop.ROWS) do
					local copy = table.clone(row)
					copy.grants = table.clone(row.grants)
					if key == id then
						change(copy)
					end
					pretend[key] = copy
				end
				local saved = Shop.ROWS;
				(Shop :: any).ROWS = pretend
				local problems = Shop.rowsOk(Weapons.ROWS, SHOTGUN.AMMO_KINDS, Licences.ROWS);
				(Shop :: any).ROWS = saved
				return problems
			end
			-- EVERY SHIPPED ROW HAS BOTH, and every explanation fits the pane it is drawn in.
			for _, id in ipairs(Shop.ORDER) do
				local row = Shop.ROWS[id]
				expect(Shop.CATEGORY_LABEL[row.category]).to.be.ok()
				expect(#row.blurb >= 20).to.equal(true)
				-- THE COMPOSED STRING, which for a package is its sentence plus the parts it names
				-- (task 221): a clipped INCLUDES line is a shop window that does not say what it
				-- sells.
				expect(#Shop.blurbFor(row) <= Shop.CONFIG.PANEL.BLURB_MAX).to.equal(true)
				-- I2a: and the NAME fits the row it is drawn in.
				expect(#row.label <= Shop.CONFIG.LABEL_MAX).to.equal(true)
			end
			local shelf = withRow(Shop.ITEM.SLUG, function(copy)
				copy.category = "gear"
			end)
			expect(#shelf).to.equal(1)
			expect(string.find(shelf[1], "gear") ~= nil).to.equal(true)
			-- ...and such a row is dropped by the menu, which is why it may not exist.
			expect(#Shop.groups({ { id = "x", category = "gear" } :: any })).to.equal(0)
			local silent = withRow(Shop.ITEM.SLUG, function(copy)
				copy.blurb = ""
			end)
			expect(#silent).to.equal(1)
			local windy = withRow(Shop.ITEM.SLUG, function(copy)
				copy.blurb = string.rep("a", Shop.CONFIG.PANEL.BLURB_MAX + 1)
			end)
			expect(#windy).to.equal(1)
			expect(string.find(windy[1], tostring(Shop.CONFIG.PANEL.BLURB_MAX)) ~= nil).to.equal(true)
		end)

		it("grants something in every row, and every grant is one of the declared kinds", function()
			-- COUNTED OVER `GRANT_FIELDS` SINCE TASK 221, so this case cannot go stale against a
			-- ninth field the way a hand-written list of four did.
			local kinds: { [string]: number } = {}
			for _, field in ipairs(Shop.GRANT_FIELDS) do
				kinds[field] = 0
			end
			for _, id in ipairs(Shop.ALL_ORDER) do
				local grants = Shop.anyRow(id).grants
				local counted = 0
				for key in pairs(kinds) do
					if (grants :: any)[key] ~= nil then
						kinds[key] += 1
						counted += 1
					end
				end
				-- A ROW THAT GRANTS NOTHING IS A ROW THAT CHARGES FOR NOTHING.
				expect(counted >= 1).to.equal(true)
				expect(Shop.grantsAnything(grants)).to.equal(true)
			end
			-- THE ORDINARY ROW GRANTS IT ONCE AND EACH PACKAGE THAT COVERS IT GRANTS IT AGAIN, so
			-- these counts are the catalogue's shape and not just its length.
			-- slug: its own row + THE HIDE + THE FULL SEASON.
			expect(kinds.ammo).to.equal(3)
			-- the three bought guns: each one's own row, + THE MARKSMAN and THE FULL SEASON, which
			-- both cover the SCOPED rifle. FIVE SINCE TASK 225, and neither the lever nor the
			-- semi-auto is in any package -- a bundle covering two guns would make `mergedGrants`
			-- conflict on a single-valued field.
			expect(kinds.weapon).to.equal(5)
			-- the beater licence: its own row + THE FULL SEASON.
			expect(kinds.driveGun).to.equal(2)
			-- the high seat: its own row + THE HIDE + THE FULL SEASON.
			expect(kinds.highSeat).to.equal(3)
			-- unlimited ammo: its own row + THE MARKSMAN + THE FULL SEASON.
			expect(kinds.unlimitedAmmo).to.equal(3)
			-- always-hunter: its own row + THE FULL SEASON.
			expect(kinds.alwaysHunter).to.equal(2)
			-- the red stag card: its own row, and no package covers a row that is not for sale.
			expect(kinds.licence).to.equal(1)
			-- THE HAT IS RETIRED AND STILL THE ONLY THING THAT GRANTS A COLOUR.
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
			-- NOT_SALE AGAINST A PRETEND CATALOGUE (task 196): no shipped row sets `sale = false` any
			-- more, and the reason has to stay provable for the day one does again.
			expect(refuseUnsellable(ctx({ itemId = Shop.ITEM.RIFLE }))).to.equal(Shop.REASON.NOT_SALE)
			expect(Shop.refuse(ctx({ hasProfile = false }))).to.equal(Shop.REASON.NO_PROFILE)
			expect(Shop.refuse(ctx({ atCounter = false }))).to.equal(Shop.REASON.TOO_FAR)
			expect(Shop.refuse(ctx({ owned = { [Shop.ITEM.SLUG] = true } }))).to.equal(Shop.REASON.OWNED)

			local locked, shortHunts = Shop.refuse(ctx({ itemId = Shop.ITEM.RIFLE, hunts = 20 }))
			expect(locked).to.equal(Shop.REASON.LOCKED)
			expect(shortHunts).to.equal(5)

			local poor, shortCoins = Shop.refuse(ctx({ itemId = Shop.ITEM.RIFLE, balance = 1400 }))
			expect(poor).to.equal(Shop.REASON.POOR)
			expect(shortCoins).to.equal(100)

			-- ...AND THE LINES THOSE TWO NUMBERS GO INTO.
			expect(Shop.noticeFor(Shop.REASON.LOCKED, 5)).to.equal("LOCKED: 5 HUNTS")
			-- `%s` AND `Money.text` SINCE TASK 221: the notice the server sends is filled in ONE
			-- place, so the line the panel prints and the price the till charges read the same way.
			expect(Shop.noticeFor(Shop.REASON.POOR, 100)).to.equal("YOU NEED $100")
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
				itemId = Shop.ITEM.RIFLE,
				owned = { [Shop.ITEM.RIFLE] = true },
				balance = 0,
				hunts = 0,
			})
			expect(Shop.refuse(all)).to.equal(Shop.REASON.CLOSED)
			all.coinsOn = true
			-- NOT_SALE comes second, and it is driven against the pretend catalogue for task 196's
			-- reason: the one row that was never for sale is gone.
			expect(refuseUnsellable(all)).to.equal(Shop.REASON.NOT_SALE)
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
			-- STILL TWO AFTER TASK 224: the accepted cost shop design 7.1 names (*"a player who owns
			-- nothing is handed the rifle for one drive"*) is unchanged for the rifle, and the lever
			-- rifle is `OWNED_ONLY` so it is not in this list at all.
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
			-- why such a row may not be for sale. `rifle.open` is not in the catalogue since task 196,
			-- so the id is simply one nothing knows -- which is the same answer.
			local pretend = Weapons.loadoutFor(true, { ["rifle.open"] = true })
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

			-- NOBODY HAS UNLIMITED SHELLS UNLESS HE BOUGHT THEM (task 221), and the ALLOWANCE is
			-- `nil` rather than an empty table in that case -- so every caller written before the
			-- entitlement hands `StateMachine.initial` exactly what it handed before.
			expect(bare.unlimited).to.equal(nil)
			expect(bought.unlimited).to.equal(nil)
			local boundless = Shop.startFor(SHOTGUN, { [Shop.ITEM.UNLIMITED_AMMO] = true })
			expect(boundless.unlimited).to.be.ok()
			-- UNLIMITED BUCKSHOT WITHOUT THE SLUG STAYS UNLIMITED *BUCKSHOT*: the entitlement
			-- cannot hand him a shell the ladder has not sold him.
			expect((boundless.unlimited :: any).Buck).to.equal(true)
			expect((boundless.unlimited :: any).Slug).to.equal(nil)
			local both = Shop.startFor(SHOTGUN, { [Shop.ITEM.UNLIMITED_AMMO] = true, [Shop.ITEM.SLUG] = true })
			expect((both.unlimited :: any).Slug).to.equal(true)
			expect((both.unlimited :: any).Buck).to.equal(true)
			-- ...AND A PACKAGE THAT CONTAINS IT DOES THE SAME, through the merged grants.
			local season = Shop.startFor(SHOTGUN, { [Shop.ITEM.BUNDLE_SEASON] = true })
			expect((season.unlimited :: any).Slug).to.equal(true)

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
			-- THE HAT IS RETIRED SINCE TASK 221 and still answers, which is the whole of why
			-- `Shop.RETIRED` exists.
			local red = Shop.hatColorFor({ [Shop.ITEM.HAT_RED] = true })
			expect(red).to.equal(Shop.RETIRED[Shop.ITEM.HAT_RED].grants.hatColor)
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
