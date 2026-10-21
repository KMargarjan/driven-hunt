-- high_seats.spec: THE WOODEN HIGH SEAT, AS ARITHMETIC (task 218).
--
-- EVERYTHING HERE RUNS WITH HAND-WRITTEN NUMBERS AND NO STUDIO. `HighSeats` is pure -- no Instance,
-- no service, no raycast -- so the pieces of a seat on a hillside, the deck's reference to
-- the WORST footprint corner, the rail's blocked band and the platform rule's own line are all
-- assertable in the DEV place where the harness runs, with no forest and no terrain.
--
-- THE TWO RELATIONS THE WHOLE DESIGN RESTS ON ARE ASSERTED AND NOT DESCRIBED (cases 6a and 6b):
-- lowering the deck, or raising the clearance a body is placed at, trips a case here instead of
-- silently opening the platform rule or waking the floor net under a seat.
--
-- WHAT IS NEVER ASSERTED: the MEASURED values in `HighSeats.STANDS`. Which stands carry a seat is a
-- measurement of Karen's world and hers to move; the SHAPE of that table is the rule, and the shape
-- is what this file holds to.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/high-seats.md (section 10.1)
-- Note:   docs/research/2026-10-20-high-seats.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Forest = require(ReplicatedStorage:WaitForChild("ForestTest"))
local HighSeats = require(ReplicatedStorage:WaitForChild("HighSeats"))
local Places = require(ReplicatedStorage:WaitForChild("Places"))
local Match = require(ServerScriptService:WaitForChild("Match"))

-- A HILLSIDE, IN THE FOOTPRINT'S OWN ORDER: the four leg corners and then the ladder's foot. 143 is
-- the highest, so every number below that references the deck references 143 and not 141.
local HILL = { 140, 142, 139, 141, 143 }
local STAND = Vector3.new(3030, 0, -2097)

local function pieceNamed(pieces, name: string)
	for _, piece in ipairs(pieces) do
		if piece.name == name then
			return piece
		end
	end
	return nil
end

local function bottomOf(piece): number
	return piece.cframe.Position.Y - piece.size.Y / 2
end

local function topOf(piece): number
	return piece.cframe.Position.Y + piece.size.Y / 2
end

return function()
	describe("HighSeats: which stands carry one", function()
		it("has a row for every layout and none for anything else", function()
			local names = {}
			for _, name in ipairs(Forest.LAYOUT_ORDER) do
				names[name] = true
				expect(type((HighSeats.STANDS :: any)[name])).to.equal("table")
			end
			for name in pairs(HighSeats.STANDS) do
				-- A row for a layout that does not exist would build seats nobody can stand on and
				-- would never be noticed: `Seats.ensure` simply asks for a name the world has not
				-- got.
				expect(names[name]).to.equal(true)
			end
		end)

		it("is frozen, so the world is a pure function of the commit", function()
			expect(table.isfrozen(HighSeats.STANDS)).to.equal(true)
			expect(table.isfrozen(HighSeats.DIMS)).to.equal(true)
			expect(table.isfrozen(HighSeats.COLORS)).to.equal(true)
			for _, name in ipairs(Forest.LAYOUT_ORDER) do
				expect(table.isfrozen((HighSeats.STANDS :: any)[name])).to.equal(true)
			end
		end)

		it("takes at least one stand, never more than the cap, and never two adjacent", function()
			for _, name in ipairs(Forest.LAYOUT_ORDER) do
				local layout = Forest.layoutNamed(name)
				local row = HighSeats.standsFor(name)
				-- EVERY PLACE GETS A SEAT (design 6.2 rule 4): Karen asked for them "in each of the
				-- four places", and a layout whose terrain refuses the relief test still takes its
				-- best stand rather than going without.
				expect(#row >= 1).to.equal(true)
				expect(#row <= HighSeats.capFor(layout.standCount)).to.equal(true)
				for index = 1, #row do
					expect(row[index] >= 1).to.equal(true)
					expect(row[index] <= layout.standCount).to.equal(true)
					if index > 1 then
						-- STRICTLY ASCENDING AND NEVER ADJACENT, so a hunter always has a ground
						-- neighbour and the line never reads as a row of towers.
						expect(row[index] - row[index - 1] >= 2).to.equal(true)
					end
				end
			end
		end)

		it("hands out a fresh copy, so a caller cannot sort the frozen table", function()
			local first = HighSeats.standsFor("road")
			first[1] = 99
			expect(HighSeats.standsFor("road")[1]).never.to.equal(99)
			expect(#HighSeats.standsFor("nowhere")).to.equal(0)
		end)

		it("answers hasSeat off the same table", function()
			local row = HighSeats.standsFor("road")
			expect(HighSeats.hasSeat("road", row[1])).to.equal(true)
			expect(HighSeats.hasSeat("nowhere", 1)).to.equal(false)
			local absent = nil
			for index = 1, Forest.layoutNamed("road").standCount do
				if not HighSeats.hasSeat("road", index) then
					absent = index
					break
				end
			end
			expect(absent).never.to.equal(nil)
			expect(HighSeats.hasSeat("road", absent)).to.equal(false)
		end)

		it("caps at a third of the stands, rounded up", function()
			expect(HighSeats.capFor(9)).to.equal(3)
			expect(HighSeats.capFor(5)).to.equal(2)
			expect(HighSeats.capFor(6)).to.equal(2)
			expect(HighSeats.capFor(1)).to.equal(1)
		end)

		it("names every relaxed layout as one it actually has", function()
			for name in pairs(HighSeats.RELIEF_RELAXED) do
				expect(type((HighSeats.STANDS :: any)[name])).to.equal("table")
			end
		end)
	end)

	describe("HighSeats: the two relations the design rests on", function()
		it("keeps the platform's line out of reach of a jump from the ground", function()
			-- A man standing in the seat's own footprint is placed at `STAND_HEIGHT_STUDS` and
			-- reaches `MAX_JUMP_STUDS` more at his apex. The deck must be above that, or the rule
			-- is defeated by the jump key. 12.5 - 3.5 = 9.0 against 7.2.
			local headroom = HighSeats.DIMS.DECK_RISE_STUDS - Match.CONFIG.STAND_HEIGHT_STUDS
			expect(headroom >= HighSeats.MAX_JUMP_STUDS).to.equal(true)
			-- ...and the margin that is left is the number the stand selection's relief test uses,
			-- so the two cannot drift apart.
			expect(math.abs((headroom - HighSeats.MAX_JUMP_STUDS) - HighSeats.JUMP_RELIEF_STUDS) < 1e-3).to.equal(true)
		end)

		it("keeps the deck's underside above the floor net's own near probe", function()
			-- `Body.underGroundBy` asks from `root + NEAR_PROBE_STUDS` (6). A man under the seat
			-- has his root at `footY + STAND_HEIGHT_STUDS`, so the probe starts at footY + 9.5 and
			-- the deck's BOTTOM must stay above it -- otherwise a downward ray finds the deck and
			-- the net reads him as 12 studs under "the ground".
			local deckUnderside = HighSeats.DIMS.DECK_RISE_STUDS - HighSeats.DIMS.DECK_SIZE.Y
			expect(deckUnderside >= Match.CONFIG.STAND_HEIGHT_STUDS + 6).to.equal(true)
		end)

		it("keeps the whole footprint inside the stand circle and the cleared lane", function()
			-- The soft wall can never act on a man on his platform, and nothing is planted through
			-- a seat -- both are this one inequality rather than two sentences.
			expect(HighSeats.footprintRadiusStuds() < Forest.PICK.standRadiusStuds).to.equal(true)
			expect(Places.LANE_STUDS >= HighSeats.footprintRadiusStuds()).to.equal(true)
		end)

		it("names the five footprint samples the build reads", function()
			local samples = HighSeats.footprint()
			expect(#samples).to.equal(5)
			local worst = 0
			for _, offset in ipairs(samples) do
				worst = math.max(worst, math.sqrt(offset.dx * offset.dx + offset.dz * offset.dz))
			end
			-- The ladder's own foot is the furthest point, and the radius this module publishes
			-- must cover the corner of its 2-stud truss, not just its centre.
			local ladderCorner = math.sqrt(
				(HighSeats.DIMS.LADDER_SIZE_STUDS / 2) ^ 2
					+ (math.abs(HighSeats.DIMS.LADDER_OFFSET_STUDS) + HighSeats.DIMS.LADDER_SIZE_STUDS / 2) ^ 2
			)
			expect(worst <= HighSeats.footprintRadiusStuds()).to.equal(true)
			expect(HighSeats.footprintRadiusStuds() >= ladderCorner).to.equal(true)
		end)
	end)

	describe("HighSeats: the deck is referenced to the worst corner", function()
		it("takes the HIGHEST footprint ground, not the lowest and not the mean", function()
			expect(HighSeats.deckTopFor(HILL)).to.equal(143 + HighSeats.DIMS.DECK_RISE_STUDS)
		end)

		it("does not care what order the readings arrive in", function()
			expect(HighSeats.deckTopFor({ 143, 139, 142, 141, 140 })).to.equal(HighSeats.deckTopFor(HILL))
		end)

		it("answers nil when any reading is missing", function()
			expect(HighSeats.deckTopFor({ 140, 142, nil, 141, 143 })).to.equal(nil)
			expect(HighSeats.spreadOf({ 140, 142, nil, 141, 143 })).to.equal(nil)
		end)

		it("measures the spread across all five", function()
			expect(HighSeats.spreadOf(HILL)).to.equal(4)
		end)

		it("puts the platform rule's line on the deck's own top face, with no margin", function()
			expect(HighSeats.minYFor(155.5)).to.equal(155.5)
		end)
	end)

	describe("HighSeats: the plan", function()
		it("builds exactly PARTS_PER_SEAT pieces, every one solid and queryable", function()
			local pieces, reason = HighSeats.plan(STAND, HILL)
			expect(reason).to.equal(nil)
			expect(#pieces).to.equal(HighSeats.PARTS_PER_SEAT)
			for _, piece in ipairs(pieces) do
				expect(type(piece.name)).to.equal("string")
				expect(piece.size.X > 0 and piece.size.Y > 0 and piece.size.Z > 0).to.equal(true)
				-- A DECK IS A THING, not a marker: a shot must not pass through one, and a body
				-- must not fall through one. This is the deliberate opposite of
				-- `ForestTest.Markers`, whose parts are references and set `CanQuery = false`.
				expect(piece.canCollide).to.equal(true)
				expect(piece.canQuery).to.equal(true)
				expect(piece.class == "Part" or piece.class == "TrussPart").to.equal(true)
			end
		end)

		it("is deterministic: the same arguments give the same seat", function()
			local first = HighSeats.plan(STAND, HILL)
			local second = HighSeats.plan(STAND, HILL)
			expect(#first).to.equal(#second)
			for index = 1, #first do
				expect(first[index].name).to.equal(second[index].name)
				expect(first[index].size).to.equal(second[index].size)
				expect(first[index].cframe.Position).to.equal(second[index].cframe.Position)
			end
		end)

		-- THE TOLERANCE IS 1e-3 AND NOT 1e-3 THROUGHOUT, and it is a fact about the engine rather
		-- than slack: `Vector3` and `CFrame` components are FLOAT32, so a y of 155.5 cannot be
		-- stored to better than about 1e-5 and a 1e-3 comparison fails on arithmetic that is
		-- exactly right. `forest_markers.spec` compares at 1e-3 for the same reason.
		it("cuts each leg to its own ground and still leaves the deck level", function()
			local pieces = HighSeats.plan(STAND, HILL)
			local samples = HighSeats.footprint()
			local embed = HighSeats.DIMS.FOOT_EMBED_STUDS
			local tops = {}
			for index = 1, 4 do
				local leg = pieceNamed(pieces, string.format("Leg%d", index))
				expect(leg).never.to.equal(nil)
				-- ITS OWN ground, which is what stops one leg hanging and the next one buried --
				-- lesson L-024/L-025, the bug task 207 and task 196 both paid for.
				expect(math.abs(bottomOf(leg) - (HILL[index] - embed)) < 1e-3).to.equal(true)
				expect(math.abs(leg.cframe.Position.X - (STAND.X + samples[index].dx)) < 1e-3).to.equal(true)
				expect(math.abs(leg.cframe.Position.Z - (STAND.Z + samples[index].dz)) < 1e-3).to.equal(true)
				table.insert(tops, topOf(leg))
			end
			for index = 2, #tops do
				expect(math.abs(tops[index] - tops[1]) < 1e-3).to.equal(true)
			end
		end)

		it("puts the deck's top face where the rule and the marker both read it", function()
			local pieces = HighSeats.plan(STAND, HILL)
			local deck = pieceNamed(pieces, "Deck")
			expect(math.abs(topOf(deck) - HighSeats.deckTopFor(HILL)) < 1e-3).to.equal(true)
			expect(deck.size).to.equal(HighSeats.DIMS.DECK_SIZE)
		end)

		it("stands the ladder on its own sample and runs it past the deck", function()
			local pieces = HighSeats.plan(STAND, HILL)
			local ladder = pieceNamed(pieces, "Ladder")
			expect(ladder.class).to.equal("TrussPart")
			-- `NoSupports` IS THE LOOK AND IT IS ASSERTED, because the engine's DEFAULT
			-- (`AlternatingSupports`) draws the X-lattice that made round 1 read as a steel pylon.
			-- The climb is unaffected either way -- a Humanoid climbs a `TrussPart` by its class --
			-- so nothing but a frame would ever have caught a regression here.
			expect(ladder.style).to.equal(Enum.Style.NoSupports)
			-- `TrussPart` is constrained to 2 x 2 x n, so its cross-section is not ours to choose.
			expect(ladder.size.X).to.equal(HighSeats.DIMS.LADDER_SIZE_STUDS)
			expect(ladder.size.Z).to.equal(HighSeats.DIMS.LADDER_SIZE_STUDS)
			expect(math.abs(bottomOf(ladder) - (HILL[5] - HighSeats.DIMS.FOOT_EMBED_STUDS)) < 1e-3).to.equal(true)
			expect(
				math.abs(topOf(ladder) - (HighSeats.deckTopFor(HILL) + HighSeats.DIMS.LADDER_OVER_DECK_STUDS)) < 1e-3
			).to.equal(true)
		end)

		it("ties the frame with ONE girt and two braces, not a lattice", function()
			-- THE DIRECTOR'S LOOK, 2026-10-20: round 1's four girts plus two diagonals plus the
			-- truss's default lattice read as a steel pylon. Four posts you can see between is the
			-- ref. This is the count asserted, so a later tweak cannot quietly re-lattice it.
			local pieces = HighSeats.plan(STAND, HILL)
			expect(pieceNamed(pieces, "Girt")).never.to.equal(nil)
			for _, gone in ipairs({ "GirtN", "GirtE", "GirtW" }) do
				expect(pieceNamed(pieces, gone)).to.equal(nil)
			end
			expect(pieceNamed(pieces, "BraceE")).never.to.equal(nil)
			expect(pieceNamed(pieces, "BraceW")).never.to.equal(nil)
		end)

		it("leaves a gap in the south rail wide enough to climb through", function()
			local pieces = HighSeats.plan(STAND, HILL)
			local east = pieceNamed(pieces, "RailSE")
			local west = pieceNamed(pieces, "RailSW")
			local gap = (east.cframe.Position.X - east.size.X / 2) - (west.cframe.Position.X + west.size.X / 2)
			expect(math.abs(gap - HighSeats.DIMS.LADDER_GAP_STUDS) < 1e-3).to.equal(true)
			-- A Roblox character is 2 studs across, so the opening has to be wider than that.
			expect(gap > 2).to.equal(true)
		end)

		it("puts every rail board's top at one height above the deck", function()
			local pieces = HighSeats.plan(STAND, HILL)
			local wanted = HighSeats.deckTopFor(HILL) + HighSeats.DIMS.RAIL_RISE_STUDS
			for _, name in ipairs({ "RailN", "RailE", "RailW", "RailSE", "RailSW" }) do
				local board = pieceNamed(pieces, name)
				expect(board).never.to.equal(nil)
				expect(math.abs(topOf(board) - wanted) < 1e-3).to.equal(true)
			end
		end)

		it("refuses rather than building a partial seat", function()
			local pieces, reason = HighSeats.plan(STAND, { 140, 142, nil, 141, 143 })
			expect(pieces).to.equal(nil)
			expect(type(reason)).to.equal("string")

			local overSpread, spreadReason = HighSeats.plan(STAND, { 140, 145, 140, 140, 140 })
			expect(overSpread).to.equal(nil)
			expect(string.find(spreadReason, "spread", 1, true)).never.to.equal(nil)

			local wrongCount, countReason = HighSeats.plan(STAND, { 140, 140 })
			expect(wrongCount).to.equal(nil)
			expect(type(countReason)).to.equal("string")
		end)
	end)

	describe("HighSeats: the rail, and the one band of shots it blocks", function()
		it("lets a steep shot under the board and a flat shot over it", function()
			local rise, drop = HighSeats.AIM_RISE_STUDS, HighSeats.DIMS.DECK_RISE_STUDS
			expect(HighSeats.clearsRail(rise, drop, 10)).to.equal(true)
			expect(HighSeats.clearsRail(rise, drop, 12.5)).to.equal(false)
			expect(HighSeats.clearsRail(rise, drop, 30)).to.equal(true)
			expect(HighSeats.clearsRail(rise, drop, 0)).to.equal(true)
		end)

		it("names the blocked annulus as a number", function()
			local near, far = HighSeats.blockedBand(HighSeats.AIM_RISE_STUDS, HighSeats.DIMS.DECK_RISE_STUDS)
			expect(math.abs(near - 11.3) < 0.1).to.equal(true)
			expect(math.abs(far - 13.9) < 0.1).to.equal(true)
			-- Everything inside the near edge passes UNDER the board, everything past the far edge
			-- passes OVER it, so the blind ring is 2.6 studs wide and nothing else is lost.
			expect(HighSeats.clearsRail(HighSeats.AIM_RISE_STUDS, HighSeats.DIMS.DECK_RISE_STUDS, near - 0.5)).to.equal(
				true
			)
			expect(HighSeats.clearsRail(HighSeats.AIM_RISE_STUDS, HighSeats.DIMS.DECK_RISE_STUDS, far + 0.5)).to.equal(
				true
			)
		end)
	end)

	describe("HighSeats: the seats are ground, and the one reader must say so", function()
		it("is NOT in the world's ground-ignore list", function()
			-- THE INVERSE OF `places.spec`'s OWN ASSERTION. `Places.FOLDER` IS in that list -- a
			-- tree we planted must not answer "where is the ground" -- and a DECK must, because a
			-- body stands on one. If a later task adds this folder to the list, `Body.onGround`
			-- snaps a hunter off his own platform and this case is what says so.
			for _, name in ipairs(Forest.GROUND_IGNORE) do
				expect(name).never.to.equal("HighSeats")
			end
		end)
	end)

	-- ---------------------------------------------------------------- the paid seat (task 221)
	--
	-- KAREN, 2026-10-20: *"Access to tree stand"*. The seats became a thing a player BUYS, so the
	-- deal has to put the men who paid on them and everybody else on the ground -- without ever
	-- putting two men on one stand, and without leaving anybody off the line.
	describe("dealing the line when a seat is paid for", function()
		local LAYOUTS = { "road", "edge", "ride", "track" }

		-- The centre-out walk of a layout with `count` stands, which is `standIndexFor`'s sequence
		-- written out here so this spec needs no world: 5, 4, 6, 3, 7, ... for nine.
		local function walkOf(count: number): { number }
			local out = {}
			local middle = math.floor(count / 2) + 1
			for index = 1, count do
				local zero = (index - 1) % count
				local step = math.ceil(zero / 2)
				local side = if zero % 2 == 1 then -1 else 1
				table.insert(out, math.clamp(middle + step * side, 1, count))
			end
			return out
		end

		local function seatedOf(layout: string): { [number]: boolean }
			local out: { [number]: boolean } = {}
			for _, index in ipairs(HighSeats.standsFor(layout)) do
				out[index] = true
			end
			return out
		end

		it("is today's game, exactly, when nobody has been asked", function()
			-- REQUIREMENT 4, AS AN IDENTITY AND NOT AS A DESCRIPTION. With `entitled == nil` -- an
			-- un-wired world, a build with no economy, every spec written before this task -- pass
			-- 1 always takes the first untaken stand in the walk, which IS `walk[index]`, which is
			-- `standIndexFor(index)`. Past the end of the line, pass 3 wraps on the same modulo.
			for _, count in ipairs({ 5, 6, 9 }) do
				local walk = walkOf(count)
				local deal = HighSeats.dealLine(walk, { [walk[1]] = true }, nil, 16)
				for index = 1, 16 do
					expect(deal[index]).to.equal(walk[((index - 1) % count) + 1])
				end
			end
		end)

		it("never puts two hunters on one stand, whoever paid", function()
			-- REQUIREMENT 2. A stand may be dealt twice ONLY from pass 3, and pass 3 fires only
			-- when every stand in the walk is taken -- which is `index > #walk`, exactly today's
			-- wrap. Driven over every layout, every roster size a drive can hold, and four
			-- entitlement patterns including "nobody paid", which is the live case today.
			for _, layout in ipairs(LAYOUTS) do
				local stands = HighSeats.standsFor(layout)
				expect(#stands > 0).to.equal(true)
				for _, count in ipairs({ 5, 6, 9 }) do
					local walk = walkOf(count)
					local seated: { [number]: boolean } = {}
					for _, index in ipairs(stands) do
						if index <= count then
							seated[index] = true
						end
					end
					for _, pattern in ipairs({ "none", "all", "first", "alternate" }) do
						for roster = 1, 16 do
							local entitled: { boolean? } = {}
							for index = 1, roster do
								if pattern == "none" then
									entitled[index] = false
								elseif pattern == "all" then
									entitled[index] = true
								elseif pattern == "first" then
									entitled[index] = index == 1
								else
									entitled[index] = index % 2 == 1
								end
							end
							local deal = HighSeats.dealLine(walk, seated, entitled, roster)
							expect(#deal).to.equal(roster)
							-- UP TO THE WRAP, EVERY STAND IS DIFFERENT.
							local seen: { [number]: boolean } = {}
							local upTo = math.min(roster, count)
							for index = 1, upTo do
								expect(deal[index] >= 1).to.equal(true)
								expect(deal[index] <= count).to.equal(true)
								expect(seen[deal[index]]).to.equal(nil)
								seen[deal[index]] = true
							end
							-- REQUIREMENT 3: NOBODY IS OFF THE LINE, wrap or no wrap.
							for index = 1, roster do
								expect(type(deal[index])).to.equal("number")
							end
						end
					end
				end
			end
		end)

		it("keeps an unpaid hunter off a seat while any ground stand is free", function()
			-- THE RULE ITSELF. Nine stands with seats on 1, 4 and 7 (the road's own table): a line
			-- of unentitled hunters takes the ground stands and leaves the three seats standing.
			local walk = walkOf(9)
			local seated = { [1] = true, [4] = true, [7] = true }
			local none: { boolean? } = {}
			for index = 1, 6 do
				none[index] = false
			end
			local deal = HighSeats.dealLine(walk, seated, none, 6)
			for index = 1, 6 do
				expect(seated[deal[index]]).to.equal(nil)
			end
			-- ...AND A MAN WHO PAID GETS ONE WHEN IT IS HIS TURN IN THE WALK.
			local paid: { boolean? } = { false, true, false, false }
			local mixed = HighSeats.dealLine(walk, seated, paid, 4)
			-- Hunter 2's own place in the walk is stand 4, which IS a seat: he paid, so he keeps it.
			expect(mixed[2]).to.equal(4)
			expect(seated[mixed[1]]).to.equal(nil)
			expect(seated[mixed[3]]).to.equal(nil)
			expect(seated[mixed[4]]).to.equal(nil)
		end)

		it("gives the seat away rather than share a stand, when the line is full", function()
			-- PASS 2, AND IT EXISTS FOR EXACTLY THIS. MEASURED: five unentitled hunters on a
			-- five-stand line whose seat is stand 3 get 2, 4, 1, 5, 3 -- the fifth man is given the
			-- seat, because the alternative is two men on stand 5. Without pass 2 the deal was
			-- 2, 4, 1, 5, 5, which is a stand shared where today all five fit.
			local walk = walkOf(5)
			local seated = { [3] = true }
			local none: { boolean? } = { false, false, false, false, false }
			local deal = HighSeats.dealLine(walk, seated, none, 5)
			expect(deal[1]).to.equal(2)
			expect(deal[2]).to.equal(4)
			expect(deal[3]).to.equal(1)
			expect(deal[4]).to.equal(5)
			expect(deal[5]).to.equal(3)
		end)

		it("still gives a solo hunter the stand the drive aims every wave at", function()
			-- THE DEFECT TASK 123 ROUND 8 MEASURED MUST NOT COME BACK. On the road `standIndexFor(1)`
			-- is 5 and the seats are on 1, 4 and 7 -- so stand 5 is NOT a seat, and a solo hunter
			-- gets it whether he paid or not.
			local walk = walkOf(9)
			local seated = { [1] = true, [4] = true, [7] = true }
			expect(walk[1]).to.equal(5)
			expect(HighSeats.dealLine(walk, seated, nil, 1)[1]).to.equal(5)
			expect(HighSeats.dealLine(walk, seated, { false }, 1)[1]).to.equal(5)
			expect(HighSeats.dealLine(walk, seated, { true }, 1)[1]).to.equal(5)
		end)

		it("is deterministic", function()
			-- REQUIREMENT 1: same roster, same entitlements, same layout -- same stands. There is no
			-- `Random` in it and the loops are in index order, so this is a check that nobody adds
			-- one.
			local walk = walkOf(9)
			local seated = { [1] = true, [4] = true, [7] = true }
			local entitled: { boolean? } = { true, false, false, true, false, false, true, false }
			local first = HighSeats.dealLine(walk, seated, entitled, 8)
			local again = HighSeats.dealLine(walk, seated, entitled, 8)
			for index = 1, 8 do
				expect(first[index]).to.equal(again[index])
			end
		end)

		it("names `edge` as the one layout whose seat is also its first-dealt stand", function()
			-- MEASURED AND DECLARED RATHER THAN DISCOVERED (design section 6.4): `edge`'s seat is
			-- stand 3 and its walk starts at 3, so an unentitled solo hunter there starts one
			-- spacing west. The other three layouts are clear. `edge` is ALREADY the declared
			-- relief exception in `HighSeats.STANDS`, and re-measuring it is 218a(h)'s, not this
			-- task's -- so this asserts the state of affairs rather than hiding it.
			expect(HighSeats.standsFor("edge")[1]).to.equal(3)
			expect(walkOf(5)[1]).to.equal(3)
			local deal = HighSeats.dealLine(walkOf(5), seatedOf("edge"), { false }, 1)
			expect(deal[1]).to.equal(2)
			-- ...AND THE OTHER THREE ARE CLEAR: the first-dealt stand carries no seat.
			expect(seatedOf("road")[walkOf(9)[1]]).to.equal(nil)
			expect(seatedOf("ride")[walkOf(5)[1]]).to.equal(nil)
			expect(seatedOf("track")[walkOf(6)[1]]).to.equal(nil)
		end)
	end)
end
