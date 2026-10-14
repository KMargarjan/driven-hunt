-- lobby.spec: THE LOBBY'S ARITHMETIC AND ITS GEOMETRY -- no world, no terrain, no player and no
-- clock. `Lobby.Join` and `Lobby.Field` are pure for exactly this reason: Karen's rule is *"step
-- into a marked spot by the truck"*, and "what happens when he steps out at 4.9 seconds" is a table
-- of cases a spec can state rather than a thing somebody watches in a playtest.
--
-- `Lobby.Build` IS DRIVEN INTO A FOLDER OF THIS SPEC'S OWN, which is what makes the part budget, the
-- collision set and *"no Script anywhere in the tree"* CHECKED claims rather than promises -- and
-- what lets this spec run safely in the DEV place, where there is no lobby at all.
--
-- `Field.fill` IS DRIVEN AGAINST A FAKE TERRAIN. That is not convenience: it is the reason `terrain`
-- is an argument at all, and it is what guarantees that no spec in the harness's own place can write
-- the DEV place's terrain, ever.
--
-- THE SWITCH-OFF CASE IS THE ONE THAT MATTERS MOST (CLAUDE.md "Feature flags"): `anchorFor("map:v1")`
-- is nil, which is what makes "off means today's game bit for bit" a checked claim -- `Lobby.start`
-- returns false on a nil anchor and builds nothing.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/lobby.md (section 16.1)
-- Note:   docs/research/2026-10-13-lobby-and-the-truck.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Data = require(ReplicatedStorage:WaitForChild("Lobby"))
local Lobby = require(ServerScriptService:WaitForChild("Lobby"))
-- THE OUTFIT OWNER, READ-ONLY AND ONLY TO ASK WHAT WORDS IT KNOWS (review round 1, finding 1). The
-- lobby does not require `Match`; this spec does, because *"the keeper is dressed"* is a claim about
-- what ANOTHER owner will do with the team this one hands it, and a spec that asserts the config
-- against itself passes for any string -- which is exactly how an undressed man got through round 1.
local Match = require(ServerScriptService:WaitForChild("Match"))
local Join = Lobby.Join
local Pads = Lobby.Pads
local Field = Lobby.Field
local Build = Lobby.Build

local CFG = Data.CONFIG

-- A TERRAIN THAT RECORDS AND WRITES NOTHING. One method, because `Field.fill` calls exactly one.
local function fakeTerrain()
	local calls = {}
	return {
		calls = calls,
		FillBlock = function(_self, at: CFrame, size: Vector3, material: Enum.Material)
			table.insert(calls, { at = at, size = size, material = material })
		end,
	}
end

-- A FOLDER OF FAKE FREE MODELS (task 180). Plain parts in a Model, one per template name, so the
-- free-model branch is reachable WITHOUT a Creator Store round trip and without the Forest Test
-- place -- which is the whole point of `templates` being an argument. `withScript` plants a Script
-- inside the truck, because "a free model is the classic place to hide one" is only a checked claim
-- if a spec actually hides one.
--
-- SINCE TASK 187 THERE IS NO LODGE AND NO TROPHY HEAD HERE, because there is no template for either
-- any more: Karen judged the free cabins *"garbadge"* and the house, its windows, its fire and every
-- antler on its walls are built from parts by this repository. What is still a free model is the
-- truck and the trees.
local function fakeTemplates(withScript: boolean?): Instance
	local folder = Instance.new("Folder")
	folder.Name = Data.TEMPLATES_NAME
	local function model(name: string, size: Vector3): Model
		local made = Instance.new("Model")
		made.Name = name
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = size
		body.Anchored = false -- the clone must anchor it: a free model ships with whatever it ships
		body.Parent = made
		made.Parent = folder
		return made
	end
	local lorry = model(Data.TEMPLATE.TRUCK, Vector3.new(18, 7, 9))
	local trees = Instance.new("Folder")
	trees.Name = Data.TEMPLATE.TREES
	trees.Parent = folder
	model("Spruce", Vector3.new(6, 30, 6)).Parent = trees
	if withScript then
		local hidden = Instance.new("Script")
		hidden.Name = "Fire_Effect"
		hidden.Parent = lorry
	end
	return folder
end

local function corners(at: CFrame, size: Vector3): { Vector3 }
	local out = {}
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				table.insert(out, at.Position + Vector3.new(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2))
			end
		end
	end
	return out
end

-- A BODY THAT IS NOT AN AVATAR (task 181). `Build` takes its rig source as a seam for exactly this
-- reason: the real one is `Players:CreateHumanoidModelFromDescription`, which reaches the avatar
-- service and may yield, and no spec in this harness may do either. It ships UNANCHORED and
-- COLLIDING, so "the keeper collides with nothing and his root is anchored" is a thing the builder
-- is proved to DO rather than a property the fake handed it.
local function fakeRig(): Model
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Anchored = false
	root.CanCollide = true
	root.CanQuery = true
	root.CanTouch = true
	root.Parent = model
	for _, name in ipairs({ "Head", "UpperTorso", "LeftHand" }) do
		local limb = Instance.new("Part")
		limb.Name = name
		limb.Size = Vector3.new(1, 1, 1)
		limb.Anchored = false
		limb.CanCollide = true
		limb.CanQuery = true
		limb.CanTouch = true
		limb.Parent = model
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

return function()
	describe("where the lobby lives", function()
		it("has a row for the world Karen plays in and none for the harness's", function()
			local forest = Data.anchorFor("forest-test")
			expect(forest).to.be.ok()
			-- The MEASURED flattest open ground south of `OurForest`'s southern edge (z = -2896).
			expect((forest :: any).x).to.equal(2850)
			expect((forest :: any).z).to.equal(-2950)

			-- THE DEV PLACE HAS NO LOBBY IN THIS TASK, so the harness reads exactly what it read
			-- before it: no anchor, no build, no terrain write.
			expect(Data.anchorFor("map:v1")).to.equal(nil)
			expect(Data.anchorFor("arena")).to.equal(nil)
			expect(Data.anchorFor("not-a-world")).to.equal(nil)
			expect(Data.anchorFor(nil)).to.equal(nil)
		end)

		it("carries no Y, because nobody measured one", function()
			-- The anchor is x and z only: the shelf's height comes from the world's own ground reader
			-- at build time. A typed Y would be a guess that puts the lodge in the air.
			local forest = Data.anchorFor("forest-test") :: any
			expect(forest.y).to.equal(nil)
		end)

		-- IT IS A DISTANCE BETWEEN TWO RECTANGLES NOW, AND NOT A z COMPARISON (task 179).
		--
		-- This case used to read `forest.z < ForestTest.EXIT_Z` and `CENTRE.Z - forest.z > 500`, and
		-- BOTH became false: `EXIT_Z` is gone, and the `edge` layout's exit is z -3250 -- which is
		-- SOUTH of the lodge at -2950. A z comparison was only ever a proxy for *"the lodge is not
		-- in the way"*, and with three layouts in three different parts of the wood it is the wrong
		-- question: the edge drive is 255 studs EAST of the lodge, not north of it.
		--
		-- EACH OWNER STATES ITS OWN RECTANGLE and this spec is the only place the two meet --
		-- `ForestTest.corridorOf` is the forest's, `Lobby.anchorFor` plus `Lobby.CONFIG.FIELD` is
		-- the lobby's. Making either module require the other for one assertion would be new
		-- coupling for nothing.
		local function gapStuds(a, b): number
			local dx = math.max(a.minX - b.maxX, b.minX - a.maxX, 0)
			local dz = math.max(a.minZ - b.maxZ, b.minZ - a.maxZ, 0)
			-- 0 on either axis with the other positive is a side-on gap; both positive is a corner.
			return if dx > 0 and dz > 0 then math.sqrt(dx * dx + dz * dz) else math.max(dx, dz)
		end

		it("is clear of EVERY drive layout's ground, so it cannot interact with the drive", function()
			local forest = Data.anchorFor("forest-test") :: any
			local ForestTest = require(ReplicatedStorage:WaitForChild("ForestTest"))
			local Boar = require(ServerScriptService:WaitForChild("Boar"))
			local half = Data.CONFIG.FIELD.SPAN_STUDS / 2
			local lodge = {
				minX = forest.x - half,
				maxX = forest.x + half,
				minZ = forest.z - half,
				maxZ = forest.z + half,
			}
			expect(#ForestTest.LAYOUT_ORDER > 0).to.equal(true)
			for _, name in ipairs(ForestTest.LAYOUT_ORDER) do
				local layout = ForestTest.layoutNamed(name)
				-- The ground a drive happens on: the stands' span, from the exit to the beaters'
				-- start. Nobody stands, walks or is placed outside it.
				local corridor = ForestTest.corridorOf(layout)
				local corridorGap = gapStuds(corridor, lodge)
				expect(corridorGap >= 100).to.equal(
					true,
					string.format("layout %s: corridor is only %.0f studs from the lodge", name, corridorGap)
				)
				-- ...and the rectangle a boar may be clamped into, which is wider than the corridor.
				local boundsGap = gapStuds(ForestTest.boundsOf(layout), lodge)
				expect(boundsGap >= Boar.CONFIG.BOUNDS_SLACK + 40).to.equal(
					true,
					string.format("layout %s: boar bounds are only %.0f studs from the lodge", name, boundsGap)
				)
			end
		end)
	end)

	-- ---------------------------------------------------------------- the pads (task 182)
	--
	-- KAREN, 2026-10-14: *"you come to truck back rectangle and can click and select how many
	-- players ... can be 1/1 or 4/4"*.
	--
	-- `Lobby.Pads` IS PURE, which is why every state, every transition and every boundary second is a
	-- table of cases stated here rather than a thing somebody watches in a playtest. Task 177's
	-- `Join.within` and `Join.decide` cases are REPLACED by these: the circle is gone and the
	-- countdown belongs to the pad now (both archived in
	-- `backups/2026-10-14_task-182_the-marked-circle.txt`).
	describe("the pads: the rectangle (Valve's trigger_multiple, read as arithmetic)", function()
		local SIZE = CFG.PADS.SIZE

		it("is a RECTANGLE, flat, and ON any edge -- or a CORNER -- is IN it", function()
			local centre = Vector3.new(100, 20, -50)
			expect(Join.withinRect(centre, centre, SIZE)).to.equal(true)
			-- ON each edge, both axes: the same `<=` every other presence test in this repo makes.
			expect(Join.withinRect(centre + Vector3.new(SIZE.X / 2, 0, 0), centre, SIZE)).to.equal(true)
			expect(Join.withinRect(centre - Vector3.new(SIZE.X / 2, 0, 0), centre, SIZE)).to.equal(true)
			expect(Join.withinRect(centre + Vector3.new(0, 0, SIZE.Z / 2), centre, SIZE)).to.equal(true)
			expect(Join.withinRect(centre - Vector3.new(0, 0, SIZE.Z / 2), centre, SIZE)).to.equal(true)
			-- ...and just past each of them.
			expect(Join.withinRect(centre + Vector3.new(SIZE.X / 2 + 0.01, 0, 0), centre, SIZE)).to.equal(false)
			expect(Join.withinRect(centre + Vector3.new(0, 0, SIZE.Z / 2 + 0.01), centre, SIZE)).to.equal(false)
			-- A CORNER IS IN, AND THAT IS THE WHOLE DIFFERENCE FROM TASK 177'S CIRCLE: an inscribed
			-- circle would call the four corners of Karen's own rectangle "not the pad".
			expect(Join.withinRect(centre + Vector3.new(SIZE.X / 2, 0, SIZE.Z / 2), centre, SIZE)).to.equal(true)
			-- FLAT: fifty studs above or below is still on it -- a man on the truck's running board.
			expect(Join.withinRect(centre + Vector3.new(0, 50, 0), centre, SIZE)).to.equal(true)
			expect(Join.withinRect(centre - Vector3.new(0, 50, 0), centre, SIZE)).to.equal(true)
		end)

		it("puts one pad behind each bay, clear of the lodge, the tailgates, the trees and the field", function()
			-- EVERY CLEARANCE IN `docs/design/truck-pads.md` SECTION 4.1, AS ARITHMETIC OVER THE
			-- CONFIG AND NEVER A LITERAL -- so a retune of `SIZE` or `BAY_GAP_STUDS` that breaks one
			-- fails the harness instead of looking wrong in a screenshot.
			local anchor = Vector3.new(0, 100, 0)
			local half = CFG.FIELD.SPAN_STUDS / 2
			local lastEast = -math.huge
			for index = 1, CFG.TRUCK.COUNT do
				local centre = Pads.centreFor(anchor, index, CFG)
				-- x: THE BAY'S OWN x, the same expression `Build.trucks` steps with.
				expect(centre.X).to.equal(anchor.X + CFG.TRUCK.OFFSET.X + (index - 1) * CFG.TRUCK.BAY_GAP_STUDS)
				-- z: `PAD_BEHIND_STUDS` from the BAY CENTRE to the pad's NEAR edge.
				local nearEdge = centre.Z - SIZE.Z / 2
				expect(nearEdge).to.equal(anchor.Z + CFG.TRUCK.OFFSET.Z + CFG.TRUCK.PAD_BEHIND_STUDS)
				-- ...WHICH CLEARS BOTH TAILGATES. The parts truck's `BedTail` face is at
				-- `OFFSET.Z + 8.2`; the free model is `MODEL`-yawed and 18.5 long, so 9.25.
				local bayZ = anchor.Z + CFG.TRUCK.OFFSET.Z
				expect(nearEdge > bayZ + 8.2).to.equal(true)
				expect(nearEdge > bayZ + 9.25).to.equal(true)
				-- THE TREE LINE'S YARD EXCLUSION ENDS AT z +44 (`Build.treeLine`), so the far edge
				-- has to stay south of it or a tree can stand on a pad.
				expect(centre.Z + SIZE.Z / 2 <= anchor.Z + 44).to.equal(true)
				-- EVERY CORNER IS ON THE FIELD.
				expect(math.abs(centre.X - anchor.X) + SIZE.X / 2 <= half).to.equal(true)
				expect(math.abs(centre.Z - anchor.Z) + SIZE.Z / 2 <= half).to.equal(true)
				-- THE FOUR RECTANGLES ARE DISJOINT, which is what lets `Pads.indexAt` return on its
				-- first match.
				expect(centre.X - SIZE.X / 2 > lastEast).to.equal(true)
				lastEast = centre.X + SIZE.X / 2
				-- THE SLAB IS SUNK: its TOP is above the yard's own road-thick surface and its BOTTOM
				-- is below the shelf, so nothing floats and nothing can hide inside a slab (task
				-- 177's round-1 finding, closed in advance).
				-- A TOLERANCE AND NOT AN EQUALITY, because a `Vector3`'s components are 32-bit: the
				-- measured answer is 100.58000335097313 for an arithmetic 100.58, which is the same
				-- surface and a different number (`viewmodel_poses.spec`'s own rule for a value that
				-- makes a round trip).
				local top = centre.Y + SIZE.Y / 2
				expect(math.abs(top - (anchor.Y + CFG.ROAD.THICK_STUDS + CFG.PADS.LIFT_STUDS)) < 1e-3).to.equal(true)
				expect(centre.Y - SIZE.Y / 2 < anchor.Y).to.equal(true)
			end
			-- PAD 1 CLEARS THE PARTS LODGE'S EAST WALL, whose outer face is `LODGE.SIZE.X / 2 +
			-- LOG_DIAMETER / 2` east of the lodge's own offset -- the bound that made 14 studs wide
			-- impossible.
			local wallX = anchor.X + CFG.LODGE.OFFSET.X + CFG.LODGE.SIZE.X / 2 + CFG.LODGE.LOG_DIAMETER / 2
			expect(Pads.centreFor(anchor, 1, CFG).X - SIZE.X / 2 >= wallX).to.equal(true)
			-- ...AND THERE IS ONE PART NAME PER BAY, so four trucks and three pads cannot happen.
			expect(#CFG.PADS.PART_NAMES).to.equal(CFG.TRUCK.COUNT)
			expect(Data.padCount()).to.equal(CFG.TRUCK.COUNT)
			-- PAD 1 IS STILL `TruckSpot`, which is what `Lobby.spotPart`, the Hud's chevron and the
			-- Director's own `smoke.sh` find it by.
			expect(Data.padPartName(1)).to.equal(Data.SPOT_NAME)
		end)

		it("answers which pad a position is on, and nil for the gap, the field and no character", function()
			local anchor = Vector3.new(0, 100, 0)
			for index = 1, CFG.TRUCK.COUNT do
				expect(Pads.indexAt(Pads.centreFor(anchor, index, CFG), anchor, CFG)).to.equal(index)
			end
			-- THE 8-STUD GAP BETWEEN TWO PADS belongs to neither.
			local between = (Pads.centreFor(anchor, 1, CFG) + Pads.centreFor(anchor, 2, CFG)) / 2
			expect(Pads.indexAt(between, anchor, CFG)).to.equal(nil)
			-- ...AND SO DOES THE REST OF THE FIELD.
			expect(Pads.indexAt(anchor, anchor, CFG)).to.equal(nil)
			expect(Pads.indexAt(anchor + Vector3.new(0, 0, 200), anchor, CFG)).to.equal(nil)
			-- nil POSITION -> nil. A player with no character is standing NOWHERE, and absent is not
			-- outside: `Join.needsReturn`'s rule and `MapUi.pointsFor`'s.
			expect(Pads.indexAt(nil, anchor, CFG)).to.equal(nil)
		end)
	end)

	describe("the pads: the state machine", function()
		local PADS = CFG.PADS

		local function who(...): { any }
			local out = {}
			for _, userId in ipairs({ ... }) do
				table.insert(out, { userId = userId, since = 0 })
			end
			return out
		end

		it("asks the FIRST man on an empty pad, and asks nobody twice", function()
			local pad = Pads.empty(2)
			expect(pad.state).to.equal(Pads.EMPTY)
			expect(pad.index).to.equal(2)
			local after, verdict = Pads.step(pad, who(11, 22, 33), 1, CFG)
			expect(verdict).to.equal(Pads.ASK)
			expect(after.state).to.equal(Pads.SIZING)
			expect(after.firstUserId).to.equal(11)
			expect(after.size).to.equal(nil)
			expect(after.deadline).to.equal(1 + PADS.PICK_TIMEOUT_SECONDS)
			expect(#after.members).to.equal(3)
			-- `ASK` IS AN EDGE, because the owner turns it into an attribute write.
			local third, second = Pads.step(after, who(11, 22, 33), 1.1, CFG)
			expect(second).to.equal(Pads.NONE)
			expect(third.firstUserId).to.equal(11)
			expect(third.deadline).to.equal(after.deadline)
			-- AN EMPTY PAD THAT STAYS EMPTY SAYS NOTHING EITHER.
			expect(select(2, Pads.step(Pads.empty(1), {}, 5, CFG))).to.equal(Pads.NONE)
		end)

		it("elects the man who has been standing there longest, and breaks a tie by userId", function()
			-- `since` EXISTS FOR EXACTLY THIS. The member list is re-measured every scan and may
			-- arrive in any order, so "the first man on" cannot be "the first in the list".
			local late = { { userId = 11, since = 9 }, { userId = 22, since = 2 }, { userId = 33, since = 5 } }
			expect(select(1, Pads.step(Pads.empty(1), late, 10, CFG)).firstUserId).to.equal(22)
			local tied = { { userId = 44, since = 3 }, { userId = 22, since = 3 } }
			expect(select(1, Pads.step(Pads.empty(1), tied, 10, CFG)).firstUserId).to.equal(22)
		end)

		it("takes a pick only while it is asking, and only one of the four sizes", function()
			local pad = select(1, Pads.step(Pads.empty(1), who(11, 22), 1, CFG))
			-- A SIZE THAT IS NOT ON THE LIST CHANGES NOTHING: a forged or stale payload.
			for _, bad in ipairs({ 3, 7, 9, 0, -1, 1.5, "4", true }) do
				local nope, ok = Pads.withSize(pad, bad :: any, 1.2, CFG)
				expect(ok).to.equal(false)
				expect(nope.size).to.equal(nil)
				expect(nope.state).to.equal(Pads.SIZING)
			end
			expect(Pads.sizeAllowed(nil, CFG)).to.equal(false)
			expect(Pads.sizeAllowed(0 / 0, CFG)).to.equal(false)
			-- ...AND THE FOUR THAT ARE.
			for _, row in ipairs(PADS.SIZES) do
				expect(Pads.sizeAllowed(row.size, CFG)).to.equal(true)
				local sized, ok = Pads.withSize(pad, row.size, 1.2, CFG)
				expect(ok).to.equal(true)
				expect(sized.state).to.equal(Pads.FILLING)
				expect(sized.size).to.equal(row.size)
				expect(sized.deadline).to.equal(1.2 + PADS.FILL_TIMEOUT_SECONDS)
				-- `firstUserId` SURVIVES THE PICK, which is what lets `Lobby.padAsking` gate the
				-- dialog on the STATE and still answer "who picked".
				expect(sized.firstUserId).to.equal(11)
			end
			-- A PAD THAT IS NOT ASKING TAKES NO PICK AT ALL: every other state refuses.
			local filling = select(1, Pads.withSize(pad, 4, 1.2, CFG))
			for _, state in ipairs({ Pads.EMPTY, Pads.FILLING, Pads.COUNTDOWN, Pads.LEAVING }) do
				local other = table.clone(filling)
				other.state = state
				expect(select(2, Pads.withSize(other, 2, 1.3, CFG))).to.equal(false)
			end
		end)

		it("defaults the pick to ONE after PICK_TIMEOUT_SECONDS, and reaches the drive unattended", function()
			-- THIS IS THE PATH THE DIRECTOR'S OWN SMOKE CHECK TAKES, with no click and no dialog
			-- (design section 15.4): a snippet run over StudioMCP gets a sandboxed copy of the
			-- server's modules with empty state (measured, task 122), so it can neither pick a size
			-- nor press a button.
			local pad = select(1, Pads.step(Pads.empty(1), who(11), 1, CFG))
			-- ONE TICK BEFORE THE TIMEOUT: still asking.
			local waiting = select(1, Pads.step(pad, who(11), 1 + PADS.PICK_TIMEOUT_SECONDS - 0.05, CFG))
			expect(waiting.state).to.equal(Pads.SIZING)
			-- AT IT: sized at row 1, which is 1.
			local sized, set = Pads.step(pad, who(11), 1 + PADS.PICK_TIMEOUT_SECONDS, CFG)
			expect(set).to.equal(Pads.SET)
			expect(sized.size).to.equal(1)
			expect(sized.size).to.equal(Pads.defaultSize(CFG))
			-- ONE TRANSITION PER CALL, so the countdown starts on the NEXT scan and not in this one.
			expect(sized.state).to.equal(Pads.FILLING)
			local armed, verdict = Pads.step(sized, who(11), 1 + PADS.PICK_TIMEOUT_SECONDS + 0.1, CFG)
			expect(verdict).to.equal(Pads.ARMED)
			expect(armed.state).to.equal(Pads.COUNTDOWN)
			expect(armed.deadline).to.equal(1 + PADS.PICK_TIMEOUT_SECONDS + 0.1 + CFG.COUNTDOWN_SECONDS)
			-- THE WHOLE WALK-ON-TO-GONE, TWO SCANS OF SLACK INCLUDED, HAS TO FIT INSIDE AN UNATTENDED
			-- SMOKE WINDOW -- asserted rather than believed, because the number is load-bearing.
			expect(PADS.PICK_TIMEOUT_SECONDS + CFG.COUNTDOWN_SECONDS + 2 / CFG.SCAN_HZ < 20).to.equal(true)
		end)

		it("counts down when the party is FULL, and when the fill times out", function()
			local pad = select(1, Pads.withSize(select(1, Pads.step(Pads.empty(1), who(11), 1, CFG)), 4, 1.2, CFG))
			expect(pad.state).to.equal(Pads.FILLING)
			-- THREE OF FOUR: still filling, and a join is not a verdict.
			local three, quiet = Pads.step(pad, who(11, 22, 33), 2, CFG)
			expect(three.state).to.equal(Pads.FILLING)
			expect(quiet).to.equal(Pads.NONE)
			expect(three.deadline).to.equal(pad.deadline)
			-- THE FOURTH ARRIVES: the countdown, at task 177's own five seconds.
			local full, armed = Pads.step(three, who(11, 22, 33, 44), 3, CFG)
			expect(armed).to.equal(Pads.ARMED)
			expect(full.state).to.equal(Pads.COUNTDOWN)
			expect(full.deadline).to.equal(3 + CFG.COUNTDOWN_SECONDS)
			-- SIZE IS A TARGET AND NOT A CAP: a ninth man is in the party, because keeping him off
			-- the slab would mean MOVING him and this owner may not write a character's position.
			local over = select(1, Pads.step(three, who(11, 22, 33, 44, 55), 3, CFG))
			expect(#over.members).to.equal(5)
			expect(over.state).to.equal(Pads.COUNTDOWN)
			-- NOBODY ELSE COMES: the fill times out and the part-full party goes anyway.
			local lonely = select(1, Pads.step(pad, who(11, 22), 1.2 + PADS.FILL_TIMEOUT_SECONDS, CFG))
			expect(lonely.state).to.equal(Pads.COUNTDOWN)
			-- ...AND ONE TICK EARLIER IT DID NOT.
			local nearly = select(1, Pads.step(pad, who(11, 22), 1.2 + PADS.FILL_TIMEOUT_SECONDS - 0.05, CFG))
			expect(nearly.state).to.equal(Pads.FILLING)
		end)

		it("hands the party over exactly ONCE, at the deadline and not a frame before", function()
			local pad = select(1, Pads.withSize(select(1, Pads.step(Pads.empty(3), who(11), 1, CFG)), 2, 1.2, CFG))
			local full = select(1, Pads.step(pad, who(11, 22), 2, CFG))
			expect(full.state).to.equal(Pads.COUNTDOWN)
			-- `>=` AT THE DEADLINE: five seconds means five, not five-and-a-frame.
			local held = select(1, Pads.step(full, who(11, 22), (full.deadline :: number) - 0.01, CFG))
			expect(held.state).to.equal(Pads.COUNTDOWN)
			local gone, verdict = Pads.step(full, who(11, 22), full.deadline :: number, CFG)
			expect(verdict).to.equal(Pads.DEPART)
			expect(gone.state).to.equal(Pads.LEAVING)
			expect(#gone.members).to.equal(2)
			-- IN PRODUCTION THE LIST EMPTIES THE MOMENT THE DRIVE HAS THEM -- the owner leaves a man it
			-- has out of the member list -- and THAT is what takes the pad back to `empty` with no
			-- second `DEPART`.
			expect(select(1, Pads.step(gone, {}, 99, CFG)).state).to.equal(Pads.EMPTY)
		end)

		it("ASKS AGAIN when the hand-over failed, instead of stranding the party on a dead pad", function()
			-- STILL STANDING THERE ON THE NEXT SCAN MEANS THE DRIVE DID NOT TAKE THEM. `Lobby.depart`
			-- returns 0 whenever the injected seam throws or `world.enrol` refuses -- `Match.enrol`
			-- refuses a player it has never registered, *"Refused rather than half-done"* -- and
			-- without this the pad would sit in `leaving` with its `DHPadState` on the part, no
			-- dialog, no countdown and no second attempt, until the man happened to walk off the
			-- rectangle. That is the one state in this machine a player cannot get himself out of.
			--
			-- THE REVIEWER FOUND THIS IN ROUND 1: the design's own transition table said the pad
			-- re-enters `sizing`, two comments claimed it did, and the code returned `NONE` for ever.
			local pad = select(1, Pads.withSize(select(1, Pads.step(Pads.empty(2), who(11), 1, CFG)), 2, 1.2, CFG))
			local full = select(1, Pads.step(pad, who(11, 22), 2, CFG))
			local stuck = select(1, Pads.step(full, who(11, 22), full.deadline :: number, CFG))
			expect(stuck.state).to.equal(Pads.LEAVING)

			local retry, verdict = Pads.step(stuck, who(11, 22), (full.deadline :: number) + 0.1, CFG)
			expect(verdict).to.equal(Pads.ASK)
			expect(retry.state).to.equal(Pads.SIZING)
			-- A FRESH QUESTION AND NOT A RESUMED ONE: the size is dropped and the pick clock starts
			-- again, which is `Join.decide`'s rule read at the level of the pad.
			expect(retry.size).to.equal(nil)
			expect(retry.firstUserId).to.equal(11)
			expect(retry.deadline).to.equal((full.deadline :: number) + 0.1 + PADS.PICK_TIMEOUT_SECONDS)
			-- ...AND IT DOES NOT DEPART AGAIN ON THE WAY OUT: one `DEPART` per countdown, and the
			-- retry has to go round the whole machine to earn the next one.
			expect(verdict).never.to.equal(Pads.DEPART)
			-- THE RETRY REACHES THE DRIVE BY ITSELF, with nobody pressing anything.
			local at = (full.deadline :: number) + 0.1
			local sawDepart = false
			local walking = retry
			while at < (full.deadline :: number) + PADS.PICK_TIMEOUT_SECONDS + CFG.COUNTDOWN_SECONDS + 1 do
				at += 1 / CFG.SCAN_HZ
				local verdictAgain
				walking, verdictAgain = Pads.step(walking, who(11, 22), at, CFG)
				if verdictAgain == Pads.DEPART then
					sawDepart = true
				end
			end
			expect(sawDepart).to.equal(true)
		end)

		it("cancels when the pad EMPTIES, and a re-entry inherits nothing", function()
			local pad = select(1, Pads.withSize(select(1, Pads.step(Pads.empty(1), who(11), 1, CFG)), 8, 1.2, CFG))
			expect(pad.size).to.equal(8)
			local gone, verdict = Pads.step(pad, {}, 2, CFG)
			expect(verdict).to.equal(Pads.CANCELLED)
			expect(gone.state).to.equal(Pads.EMPTY)
			-- KAREN'S RULE, AND IT IS `Join.decide`'S WORD FOR WORD: a cancel that kept the size
			-- would make stepping out and back in a pause nobody asked for.
			expect(gone.size).to.equal(nil)
			expect(gone.firstUserId).to.equal(nil)
			expect(gone.deadline).to.equal(nil)
			expect(#gone.members).to.equal(0)
			local back, again = Pads.step(gone, who(11), 3, CFG)
			expect(again).to.equal(Pads.ASK)
			expect(back.size).to.equal(nil)
			expect(back.deadline).to.equal(3 + PADS.PICK_TIMEOUT_SECONDS)
		end)

		it("re-elects with a FRESH clock when the first man steps off mid-dialog", function()
			local pad = select(1, Pads.step(Pads.empty(1), who(11, 22), 1, CFG))
			expect(pad.firstUserId).to.equal(11)
			local after, verdict = Pads.step(pad, { { userId = 22, since = 1 } }, 1.5, CFG)
			-- THE PAD DOES NOT CANCEL WHILE ANYBODY IS ON IT: a pad that cancelled would throw away
			-- three men because the fourth walked away. It is a QUESTION and not an inheritance --
			-- `size` is still nil and the clock starts again.
			expect(verdict).to.equal(Pads.ASK)
			expect(after.firstUserId).to.equal(22)
			expect(after.size).to.equal(nil)
			expect(after.deadline).to.equal(1.5 + PADS.PICK_TIMEOUT_SECONDS)
		end)

		it("does NOT cancel or move the countdown when somebody joins or leaves it", function()
			-- TWO JUDGEMENT CALLS, ASSERTED SO THEY ARE DECISIONS AND NOT ACCIDENTS. The countdown
			-- belongs to the PAD, so (a) a party of four that loses one at second four still goes,
			-- and (b) a late arrival cannot push back a clock somebody else is watching. Only an
			-- EMPTY pad cancels.
			local pad = select(1, Pads.withSize(select(1, Pads.step(Pads.empty(1), who(11), 1, CFG)), 4, 1.2, CFG))
			local full = select(1, Pads.step(pad, who(11, 22, 33, 44), 2, CFG))
			expect(full.state).to.equal(Pads.COUNTDOWN)
			local thinner = select(1, Pads.step(full, who(11, 22), 2.5, CFG))
			expect(thinner.state).to.equal(Pads.COUNTDOWN)
			expect(thinner.deadline).to.equal(full.deadline)
			local fatter = select(1, Pads.step(full, who(11, 22, 33, 44, 55), 2.5, CFG))
			expect(fatter.deadline).to.equal(full.deadline)
			expect(#fatter.members).to.equal(5)
			-- ...AND THE LAST MAN OFF STILL CANCELS IT, with nobody enrolled.
			local empty, cancelled = Pads.step(full, {}, 2.6, CFG)
			expect(cancelled).to.equal(Pads.CANCELLED)
			expect(empty.state).to.equal(Pads.EMPTY)
		end)

		it("says what the board says, for every state", function()
			local words = PADS.BILLBOARD
			local function board(pad)
				return select(2, Pads.labelFor(pad, CFG))
			end
			local idle = Pads.empty(3)
			expect(select(1, Pads.labelFor(idle, CFG))).to.equal("TRUCK 3")
			-- `0 / -` AND NOT `0 / 0`: nobody having picked yet is not a party of nought.
			expect(board(idle)).to.equal(string.format(words.COUNT_UNSET, 0))
			local sizing = select(1, Pads.step(Pads.empty(3), who(11), 1, CFG))
			expect(board(sizing)).to.equal(string.format(words.COUNT_UNSET, 1))
			local filling = select(1, Pads.withSize(sizing, 4, 1.2, CFG))
			-- KAREN'S OWN FORMAT: *"can be 1/1 or 4/4"*.
			expect(board(select(1, Pads.step(filling, who(11, 22), 2, CFG)))).to.equal("2 / 4")
		end)

		it("offers the sizes Karen asked for, and the biggest one IS the drive's whole roster", function()
			expect(PADS.SIZES[1].size).to.equal(1)
			local biggest = PADS.SIZES[#PADS.SIZES].size
			-- 8 = 4 HUNTERS + 4 BEATERS, asserted against the DRIVE's own table and never a copy of
			-- the number: a party of eight has to BE the whole hunt, or *"full hunt"* on the button
			-- is a lie. Bots fill every slot no player takes (task 161), which is what makes a party
			-- of one today's game exactly.
			local target = Match.CONFIG.BOTS.TARGET
			expect(biggest).to.equal(target.hunters + target.beaters)
			-- IN ORDER, WHOLE, AND NONE BIGGER THAN THE DRIVE, so the dialog reads 1, 2, 4, 8 down
			-- the panel and row 1 is the default a pick nobody makes falls back to.
			local last = 0
			for _, row in ipairs(PADS.SIZES) do
				expect(row.size % 1).to.equal(0)
				expect(row.size > last).to.equal(true)
				expect(row.size <= biggest).to.equal(true)
				expect(type(row.label)).to.equal("string")
				-- THE LABEL CARRIES THE SIZE ITSELF, so a row whose words and number disagree fails
				-- here rather than on Karen's screen.
				expect(string.find(row.label, tostring(row.size), 1, true) ~= nil).to.equal(true)
				last = row.size
			end
		end)
	end)

	describe("who belongs back at the lodge", function()
		it("answers for all eight combinations", function()
			-- In the drive: never, whatever else is true -- the drive owns where he stands.
			expect(Join.needsReturn(true, true, true)).to.equal(false)
			expect(Join.needsReturn(true, true, false)).to.equal(false)
			expect(Join.needsReturn(true, false, true)).to.equal(false)
			expect(Join.needsReturn(true, false, false)).to.equal(false)
			-- HELD: never. During the results scene a dismissed player is 570 studs from the lodge,
			-- and without this the lobby would respawn him out of Karen's results scene.
			expect(Join.needsReturn(false, true, false)).to.equal(false)
			expect(Join.needsReturn(false, true, true)).to.equal(false)
			-- Out of the drive, not held, and standing on the field already: leave him alone.
			expect(Join.needsReturn(false, false, true)).to.equal(false)
			-- The one case that returns him.
			expect(Join.needsReturn(false, false, false)).to.equal(true)
		end)

		it("does nothing at all when there is no position: absent is not outside", function()
			expect(Join.needsReturn(false, false, nil)).to.equal(false)
			expect(Join.needsReturn(true, false, nil)).to.equal(false)
		end)

		it("reads the field as a rectangle and not as a circle", function()
			local anchor = Vector3.new(2850, 153, -2950)
			local half = CFG.FIELD.SPAN_STUDS / 2
			expect(Join.insideField(anchor, anchor, CFG)).to.equal(true)
			-- The corner of the yard is still the yard.
			expect(Join.insideField(anchor + Vector3.new(half - 1, 0, half - 1), anchor, CFG)).to.equal(true)
			expect(Join.insideField(anchor + Vector3.new(half + 1, 0, 0), anchor, CFG)).to.equal(false)
			expect(Join.insideField(anchor + Vector3.new(0, 0, -half - 1), anchor, CFG)).to.equal(false)
			-- Height is not bounded: the field is a footprint.
			expect(Join.insideField(anchor + Vector3.new(0, 400, 0), anchor, CFG)).to.equal(true)
		end)
	end)

	describe("the field, cut and filled", function()
		local anchor = Vector3.new(2850, 0, -2950)
		local shelf = 153

		it("puts the grass block's top AT the shelf and its bottom below the lowest ground", function()
			local at, size = Field.grassBlock(anchor, shelf, CFG)
			expect(size.X).to.equal(CFG.FIELD.SPAN_STUDS)
			expect(size.Z).to.equal(CFG.FIELD.SPAN_STUDS)
			expect(size.Y).to.equal(CFG.FIELD.DEPTH_STUDS)
			expect(at.Position.Y + size.Y / 2).to.equal(shelf)
			-- 48 studs reaches below the worst of the fifteen sampled footprints (44 studs of spread),
			-- so the slab meets undisturbed ground on every corner rather than floating.
			expect(CFG.FIELD.DEPTH_STUDS > 44).to.equal(true)
		end)

		it("starts the air block AT the shelf and clears the lodge's ridge", function()
			local at, size = Field.airBlock(anchor, shelf, CFG)
			expect(at.Position.Y - size.Y / 2).to.equal(shelf)
			expect(size.Y).to.equal(CFG.FIELD.CLEAR_STUDS)
			-- Above the ridge, so the lodge is never built inside the hill it just cut.
			expect(CFG.FIELD.CLEAR_STUDS > CFG.LODGE.RIDGE_STUDS).to.equal(true)
		end)

		it("lays pads of a material with no grass blades under the buildings AND the road", function()
			-- BOTH OF THESE WERE PHOTOGRAPHED RATHER THAN GUESSED. Task 177's inside shot came back
			-- with terrain grass growing through the lodge's floorboards; task 180's first road shot
			-- came back with a field and NO ROAD, with the player standing on it. One cause: a grass
			-- material draws its blades on the terrain surface and a part laid over them does not
			-- hide them.
			local covered = {
				anchor + CFG.LODGE.OFFSET,
				anchor + CFG.LODGE.OFFSET - Vector3.new(0, 0, CFG.LODGE.SIZE.Z / 2 + CFG.LODGE.PORCH.DEPTH),
				-- TASK 182: all four truck pads, which is what the yard has had to cover since the
				-- circle became four rectangles behind the bays.
				Pads.centreFor(anchor, 1, CFG),
				Pads.centreFor(anchor, CFG.TRUCK.COUNT, CFG),
				anchor + CFG.SPAWN.OFFSET,
				-- the far truck bay, which the 80 x 60 yard of task 177 did not reach
				anchor + CFG.TRUCK.OFFSET + Vector3.new((CFG.TRUCK.COUNT - 1) * CFG.TRUCK.BAY_GAP_STUDS, 0, 0),
				-- both ends of the road, on its centre line
				Vector3.new(anchor.X + CFG.ROAD.CENTRE_X, 0, anchor.Z + CFG.ROAD.FROM_Z - 1),
				Vector3.new(anchor.X + CFG.ROAD.CENTRE_X, 0, anchor.Z + CFG.ROAD.TO_Z + 1),
				-- and its outer verge, which is the edge the blades came through
				Vector3.new(
					anchor.X + CFG.ROAD.CENTRE_X + CFG.ROAD.WIDTH_STUDS / 2 + CFG.ROAD.VERGE_STUDS,
					0,
					anchor.Z
				),
			}
			for _, point in ipairs(covered) do
				local found = false
				for _, pad in ipairs(CFG.FIELD.PADS) do
					local at, size = Field.padBlock(anchor, shelf, pad)
					expect(at.Position.Y + size.Y / 2).to.equal(shelf)
					expect(pad.MATERIAL).never.to.equal(CFG.FIELD.MATERIAL)
					if
						math.abs(point.X - at.Position.X) <= size.X / 2
						and math.abs(point.Z - at.Position.Z) <= size.Z / 2
					then
						found = true
					end
				end
				expect(found).to.equal(true)
			end
		end)

		it("writes nothing outside the field's own rectangle", function()
			for _, block in ipairs({
				{ Field.grassBlock(anchor, shelf, CFG) },
				{ Field.airBlock(anchor, shelf, CFG) },
				{ Field.padBlock(anchor, shelf, CFG.FIELD.PADS[1]) },
				{ Field.padBlock(anchor, shelf, CFG.FIELD.PADS[2]) },
			}) do
				local at, size = block[1] :: CFrame, block[2] :: Vector3
				expect(Field.insideField(anchor, at, size, CFG)).to.equal(true)
				for _, point in ipairs(corners(at, size)) do
					local half = CFG.FIELD.SPAN_STUDS / 2
					expect(math.abs(point.X - anchor.X) <= half + 1e-6).to.equal(true)
					expect(math.abs(point.Z - anchor.Z) <= half + 1e-6).to.equal(true)
				end
			end
		end)

		it("chunks a wide box and leaves a narrow one alone", function()
			local at, size = Field.grassBlock(anchor, shelf, CFG)
			local whole = Field.chunks(at, size, 1000)
			expect(#whole).to.equal(1)
			expect(whole[1].size.X).to.equal(size.X)

			local pieces = Field.chunks(at, size, CFG.FIELD.CHUNK_STUDS)
			expect(#pieces > 1).to.equal(true)
			-- Every chunk is inside the rectangle, and together they cover it exactly.
			local total = 0
			for _, piece in ipairs(pieces) do
				total += piece.size.X
				expect(piece.size.X <= CFG.FIELD.CHUNK_STUDS + 1e-6).to.equal(true)
				expect(Field.insideField(anchor, piece.at, piece.size, CFG)).to.equal(true)
			end
			expect(math.abs(total - size.X) < 1e-6).to.equal(true)
		end)

		it("fills grass and THEN air, through the argument and never through Workspace", function()
			local fake = fakeTerrain()
			local calls, grassCalls = Field.fill(fake, anchor, shelf, CFG)
			expect(calls).to.equal(#fake.calls)
			expect(grassCalls > 0).to.equal(true)
			expect(calls > grassCalls).to.equal(true)
			-- Grass first: the other order would fill the hole the air had just made. Then the pad
			-- under the buildings, then the air that cuts the hill off.
			expect(fake.calls[1].material).to.equal(CFG.FIELD.MATERIAL)
			expect(fake.calls[#fake.calls].material).to.equal(Enum.Material.Air)
			local seen = { grass = 0, pad = 0, air = 0 }
			for _, call in ipairs(fake.calls) do
				if call.material == CFG.FIELD.MATERIAL then
					seen.grass += 1
					expect(seen.pad + seen.air).to.equal(0) -- all the grass goes down first
				elseif call.material == CFG.FIELD.PADS[1].MATERIAL then
					seen.pad += 1
					expect(seen.air).to.equal(0) -- ...and the pad before the air
				else
					expect(call.material).to.equal(Enum.Material.Air)
					seen.air += 1
				end
			end
			expect(seen.grass).to.equal(grassCalls)
			expect(seen.pad > 0).to.equal(true)
			expect(seen.air > 0).to.equal(true)
		end)
	end)

	describe("the parts build", function()
		local anchor = Vector3.new(0, 100, 0)
		local container, folder, count

		beforeEach(function()
			container = Instance.new("Folder")
			container.Name = "LobbySpecWorld"
			-- WORKSPACE AND NEVER A ROJO-OWNED CONTAINER: `ReplicatedStorage` is fully Rojo-owned with
			-- `$ignoreUnknownInstances: false`, so a folder parked there is DELETED at Karen's next
			-- Connect; `Workspace` is not mapped at all, which is the property `Workspace.Boars`,
			-- `Workspace.ForestMarkers` and `Workspace.WeaponEffects` already rely on. It is destroyed
			-- in `afterEach` either way.
			container.Parent = Workspace
			local made, _marker, _spawn, parts = Build.build(container, anchor, CFG)
			folder = made
			count = parts
		end)

		afterEach(function()
			container:Destroy()
		end)

		it("stays inside the part budget", function()
			expect(count <= CFG.MAX_PARTS).to.equal(true)
			expect(count > 50).to.equal(true) -- a lodge, a truck, a ring and a track is not five parts
		end)

		it("anchors everything, and the only things that collide are the shell", function()
			local collidable = {}
			for _, descendant in ipairs(folder:GetDescendants()) do
				if descendant:IsA("BasePart") then
					expect(descendant.Anchored).to.equal(true)
					if descendant.CanCollide then
						table.insert(collidable, descendant.Name)
					else
						-- `CanQuery = false` IS LOAD-BEARING: a slab that stops a pellet changes what
						-- the shot hit.
						expect(descendant.CanQuery).to.equal(false)
					end
				end
			end
			expect(#collidable > 0).to.equal(true)
			for _, name in ipairs(collidable) do
				local shell = string.match(name, "^Wall")
					or string.match(name, "^Roof")
					or string.match(name, "^Gable")
					or string.match(name, "^Floor")
					or string.match(name, "^WindowGlass")
					or string.match(name, "^Plinth")
					or string.match(name, "^Chimney")
					or string.match(name, "^Deck")
					or string.match(name, "^Porch")
					or string.match(name, "^DoorPost")
					or string.match(name, "^DoorLintel")
					or string.match(name, "^Fireplace")
					or string.match(name, "^Counter")
					or string.match(name, "^Table")
					or string.match(name, "^Bench")
					or string.match(name, "^SignPost")
					or string.match(name, "^Bed")
					or string.match(name, "^Cab")
					or string.match(name, "^Bonnet")
					or name == Data.SPAWN_NAME
				if shell == nil then
					error(string.format("a collidable part nothing meant to be solid: %s", name), 0)
				end
			end
		end)

		it("builds four named pads where the rule says, each untouchable and a different colour", function()
			-- THE DECK *IS* THE NAMED PART (task 182): there is no second invisible marker, so the
			-- part the rule reads, the part the client finds, the part the attributes live on and the
			-- thing Karen looks at are one instance and cannot drift apart.
			local seen: { [string]: boolean } = {}
			for index = 1, CFG.TRUCK.COUNT do
				local name = Data.padPartName(index) :: string
				local deck = folder:FindFirstChild(name, true)
				expect(deck).to.be.ok()
				local pad = deck :: BasePart
				local wanted = Pads.centreFor(anchor, index, CFG)
				expect((pad.Position - wanted).Magnitude < 1e-4).to.equal(true)
				expect(pad.Size).to.equal(CFG.PADS.SIZE)
				expect(pad.Anchored).to.equal(true)
				-- A SHOT MUST PASS STRAIGHT THROUGH IT, `Touched` must never fire (presence here is
				-- arithmetic), and a player must not step up onto a kerb.
				expect(pad.CanQuery).to.equal(false)
				expect(pad.CanTouch).to.equal(false)
				expect(pad.CanCollide).to.equal(false)
				-- IT IS VISIBLE, which the circle's marker was not: this one is the coloured
				-- rectangle Karen asked for.
				-- A TOLERANCE: `Transparency` is a 32-bit property, so 0.45 comes back as
				-- 0.44999998807907104.
				expect(math.abs(pad.Transparency - CFG.PADS.TRANSPARENCY) < 1e-4).to.equal(true)
				-- FOUR DISTINCT COLOURS.
				local key = tostring(pad.Color)
				expect(seen[key]).to.equal(nil)
				seen[key] = true
				-- ...AND ONE BILLBOARD WITH TWO LABELS, saying something from the first frame.
				local board = pad:FindFirstChild("Board")
				expect(board).to.be.ok()
				expect((board :: Instance):IsA("BillboardGui")).to.equal(true)
				local truckLine, countLine = Build.padLabel(index)
				-- AGAINST `Pads.labelFor` ITSELF and not against a second copy of the format, which is
				-- the Reviewer's round-1 note made into a check: the words have ONE formatter now.
				local wantTruck, wantCount = Pads.labelFor(Pads.empty(index), CFG)
				expect(truckLine).to.equal(wantTruck)
				expect(countLine).to.equal(wantCount)
				-- THE TWO ATTRIBUTES ARE THE WHOLE OUTBOUND WIRE, and they are set at build.
				expect(pad:GetAttribute(Data.PAD_STATE_ATTRIBUTE)).to.equal(Data.PAD_STATE.EMPTY)
				expect(pad:GetAttribute(Data.PAD_FIRST_ATTRIBUTE)).to.equal(nil)
			end
			-- PAD 1 IS THE ONE `Build.build` HANDS BACK as its marker, and it is `TruckSpot`.
			expect(Data.padPartName(1)).to.equal(Data.SPOT_NAME)
		end)

		it("sits each pad on the ground that is REALLY there, when a world can measure it", function()
			-- THE CORRECTION THIS TASK MADE AFTER LOOKING AT IT (rule 5). Measured in the live Forest
			-- Test place, 2026-10-14: every pad's top was 149.828 and the terrain under it 150.000 --
			-- the four rectangles were 0.17 studs UNDERGROUND and only their billboards showed.
			-- `Field.fill` asks for a terrain block whose top is `shelfY`, and Roblox terrain is
			-- VOXELISED, so the surface the engine produces is rounded to its own grid: 0.75 studs
			-- higher here. A constant lift cannot fix a rounding this system did not choose.
			--
			-- SO THE PAD IS LAID ON `world.groundAt`, and the claim is that its top clears whatever
			-- that reader says -- not that it clears an arithmetic shelf.
			local hump = 3.25
			local probed: { Vector3 } = {}
			local made = Build.build(
				container,
				anchor,
				CFG,
				fakeTemplates(),
				{
					groundAt = function(x: number, z: number): number
						table.insert(probed, Vector3.new(x, 0, z))
						return anchor.Y + hump
					end,
				} :: any
			)
			-- IT ASKED ONCE PER PAD, at the pad's own centre and nowhere else.
			--
			-- SINCE TASK 186 THE TRUCKS ASK THE SAME READER -- under every wheel, twice, because the
			-- tilt moves the wheels and the ground under them is a new question afterwards -- so the
			-- probe list is no longer the pads' alone. The pads are the LAST `TRUCK.COUNT` of it,
			-- because `Build.build` parks the trucks before it lays the pads, and that ORDER is what
			-- this case now pins: a pad is still measured at its own centre and nowhere else.
			local padProbes: { Vector3 } = {}
			for index = #probed - CFG.TRUCK.COUNT + 1, #probed do
				table.insert(padProbes, probed[index])
			end
			expect(#padProbes).to.equal(CFG.TRUCK.COUNT)
			for index = 1, CFG.TRUCK.COUNT do
				local wanted = Pads.centreFor(anchor, index, CFG)
				expect(padProbes[index].X).to.equal(wanted.X)
				expect(padProbes[index].Z).to.equal(wanted.Z)
				local deck = made:FindFirstChild(Data.padPartName(index) :: string, true) :: BasePart
				local top = deck.Position.Y + deck.Size.Y / 2
				-- ON the measured ground, lifted by the one number that stops z-fighting -- and
				-- ABOVE it, which is the whole of the defect this case exists for.
				expect(math.abs(top - (anchor.Y + hump + CFG.PADS.LIFT_STUDS)) < 1e-3).to.equal(true)
				expect(top > anchor.Y + hump).to.equal(true)
				-- ...AND NEVER INSIDE THE SLAB THIS SYSTEM LAID ITSELF, which is the half of the
				-- guarantee the measurement must not throw away (the Reviewer's round-1 note).
				expect(top >= anchor.Y + CFG.ROAD.THICK_STUDS).to.equal(true)
				-- ...AND ITS x AND z HAVE NOT MOVED: the RULE is flat, so a measured Y may never
				-- change where the rectangle is.
				expect(deck.Position.X).to.equal(wanted.X)
				expect(deck.Position.Z).to.equal(wanted.Z)
			end
			-- A GROUND BELOW THE ROAD SLAB IS CLAMPED TO IT, so a dip -- or a reader that measured the
			-- terrain UNDER an opaque slab -- cannot bury the deck the way task 177's ring was buried.
			local sunken = Build.build(
				container,
				anchor,
				CFG,
				fakeTemplates(),
				{
					groundAt = function(): number
						return anchor.Y - 5
					end,
				} :: any
			)
			local clamped = sunken:FindFirstChild(Data.SPOT_NAME, true) :: BasePart
			local clampedTop = clamped.Position.Y + clamped.Size.Y / 2
			expect(math.abs(clampedTop - (anchor.Y + CFG.ROAD.THICK_STUDS + CFG.PADS.LIFT_STUDS)) < 1e-3).to.equal(true)

			-- A READER THAT ANSWERS NOTHING LEAVES THE PURE ARITHMETIC STANDING, which is the branch
			-- every other case in this file builds with.
			local blind = Build.build(
				container,
				anchor,
				CFG,
				fakeTemplates(),
				{
					groundAt = function(): number?
						return nil
					end,
				} :: any
			)
			local fallback = blind:FindFirstChild(Data.SPOT_NAME, true) :: BasePart
			expect((fallback.Position - Pads.centreFor(anchor, 1, CFG)).Magnitude < 1e-3).to.equal(true)
		end)

		it("holds no trace of task 177's circle: no ring, no Spot folder, no sign", function()
			-- A DELETION IS ONLY DONE WHEN NOTHING IS LEFT BEHIND. The circle is archived in
			-- `backups/2026-10-14_task-182_the-marked-circle.txt` (rule 7); this is the check that it
			-- is actually gone from the world rather than drawn under the pads.
			expect(folder:FindFirstChild("Spot", true)).to.equal(nil)
			expect(folder:FindFirstChild("SpotSign", true)).to.equal(nil)
			-- ...AND IT NAMES WHAT IT FOUND, rather than asserting `false` and leaving the next
			-- Builder to guess which instance it was.
			local rings = {}
			for _, descendant in ipairs(folder:GetDescendants()) do
				if string.sub(descendant.Name, 1, 3) == "Seg" then
					table.insert(rings, descendant:GetFullName())
				end
			end
			expect(table.concat(rings, ", ")).to.equal("")
		end)

		it("is found by the FOUR READERS the client has, on a lobby that is really in Workspace", function()
			-- THE ONE CASE THAT CANNOT USE A FOLDER OF ITS OWN. `Lobby.padPart`, `padPositions`,
			-- `padStateOf` and `padAsking` all look for `Workspace.Lobby` by name -- that is what
			-- makes them the CLIENT's readers, and a client has no `container` to be handed. So this
			-- builds the real thing in the real place and destroys it again, which is also the only
			-- way `Data.padAsking` -- the dialog's whole visibility rule -- is provable at all.
			--
			-- IT CREATES NO SCRIPT, so the harness's own "no script outside a Rojo path" check is
			-- untouched, and the folder is gone before the case returns.
			local made = Build.build(Workspace, anchor, CFG, fakeTemplates())
			local ok, err = pcall(function()
				expect(#Data.padPositions()).to.equal(CFG.TRUCK.COUNT)
				for index = 1, CFG.TRUCK.COUNT do
					local deck = Data.padPart(index)
					expect(deck).to.be.ok()
					expect((deck :: BasePart).Name).to.equal(Data.padPartName(index))
					local state, first = Data.padStateOf(index)
					expect(state).to.equal(Data.PAD_STATE.EMPTY)
					expect(first).to.equal(nil)
					-- THE POSITION THE CHEVRON IS POINTED AT IS THE PART'S, not a second computation.
					expect((Data.padPositions()[index] - (deck :: BasePart).Position).Magnitude).to.equal(0)
				end
				-- PAD 1 IS WHAT `Lobby.spotPart` STILL ANSWERS, which is what the Director's
				-- `smoke.sh` pivots a player into and what the chevron falls back to.
				expect(Data.spotPart()).to.equal(Data.padPart(1))
				-- NOBODY IS BEING ASKED ANYTHING ON A LOBBY NOBODY IS STANDING IN.
				expect(Data.padAsking(4242)).to.equal(nil)
				-- ...AND WHEN THE SERVER SAYS SO, EXACTLY ONE PAD ASKS EXACTLY ONE MAN. The two lines
				-- come from `Pads.labelFor`, which is the one formatter of what a board says.
				local asking = Pads.empty(3)
				asking.state = Data.PAD_STATE.SIZING
				table.insert(asking.members, 4242)
				expect(Build.setPad(3, Data.PAD_STATE.SIZING, 4242, Pads.labelFor(asking, CFG))).to.equal(true)
				expect(Data.padAsking(4242)).to.equal(3)
				expect(Data.padAsking(4243)).to.equal(nil)
				-- A PAD THAT HAS MOVED ON ASKS NOBODY, even though it still remembers who picked --
				-- which is what stops the dialog re-opening after the party is sized.
				local sized = Pads.empty(3)
				sized.state = Data.PAD_STATE.FILLING
				sized.size = 4
				table.insert(sized.members, 4242)
				expect(Build.setPad(3, Data.PAD_STATE.FILLING, 4242, Pads.labelFor(sized, CFG))).to.equal(true)
				expect(select(2, Data.padStateOf(3))).to.equal(4242)
				expect(Data.padAsking(4242)).to.equal(nil)
			end)
			made:Destroy()
			-- THE MEMOISED READERS DROP A DESTROYED PART rather than answering a stale position,
			-- which is `MapUi.pointsFor`'s rule and the reason every one of them re-checks
			-- `IsDescendantOf(game)`.
			expect(Data.padPart(1)).to.equal(nil)
			expect(#Data.padPositions()).to.equal(0)
			expect(Data.padAsking(4242)).to.equal(nil)
			if not ok then
				error(err, 0)
			end
		end)

		it("writes a pad's words and attributes only when they CHANGE", function()
			-- THE EDGE CLAIM. `Build.setPad` is called every scan by the owner -- the count changes on
			-- a join and a leave, which are not verdicts -- so it has to be free when nothing moved,
			-- or a standing-empty lobby would replicate four attribute writes ten times a second.
			-- THE WORDS COME IN READY, from the one formatter (`Pads.labelFor`); this module WRITES.
			local function words(state: string, size: number?, on: number)
				local pad = Pads.empty(1)
				pad.state = state
				pad.size = size
				for index = 1, on do
					table.insert(pad.members, index)
				end
				return Pads.labelFor(pad, CFG)
			end
			local before = Build.stats().padWrites
			local idleTruck, idleCount = words(Data.PAD_STATE.EMPTY, nil, 0)
			expect(Build.setPad(1, Data.PAD_STATE.EMPTY, nil, idleTruck, idleCount)).to.equal(false)
			expect(Build.stats().padWrites).to.equal(before)
			local askTruck, askCount = words(Data.PAD_STATE.SIZING, nil, 1)
			expect(Build.setPad(1, Data.PAD_STATE.SIZING, 4242, askTruck, askCount)).to.equal(true)
			expect(Build.stats().padWrites).to.equal(before + 1)
			local deck = Build.padPart(1) :: BasePart
			expect(deck:GetAttribute(Data.PAD_STATE_ATTRIBUTE)).to.equal(Data.PAD_STATE.SIZING)
			expect(deck:GetAttribute(Data.PAD_FIRST_ATTRIBUTE)).to.equal(4242)
			expect(select(2, Build.padLabel(1))).to.equal(string.format(CFG.PADS.BILLBOARD.COUNT_UNSET, 1))
			-- THE SAME VALUES AGAIN WRITE NOTHING.
			expect(Build.setPad(1, Data.PAD_STATE.SIZING, 4242, askTruck, askCount)).to.equal(false)
			expect(Build.stats().padWrites).to.equal(before + 1)
			-- A SIZE TURNS `n / -` INTO KAREN'S OWN `n / size`.
			local fillTruck, fillCount = words(Data.PAD_STATE.FILLING, 4, 2)
			expect(Build.setPad(1, Data.PAD_STATE.FILLING, 4242, fillTruck, fillCount)).to.equal(true)
			expect(select(2, Build.padLabel(1))).to.equal("2 / 4")
			-- A PAD THAT DOES NOT EXIST IS REFUSED RATHER THAN CREATED.
			expect(Build.setPad(CFG.TRUCK.COUNT + 5, Data.PAD_STATE.EMPTY, nil, idleTruck, idleCount)).to.equal(false)
		end)

		it("builds a neutral lodge spawn that writes no team and grants no force field", function()
			local spawn = folder:FindFirstChild(Data.SPAWN_NAME, true)
			expect(spawn).to.be.ok()
			expect((spawn :: any):IsA("SpawnLocation")).to.equal(true)
			expect((spawn :: any).Neutral).to.equal(true)
			expect((spawn :: any).Enabled).to.equal(true)
			-- THE ENGINE MUST NEVER WRITE A TEAM: `Match.Body.setTeam` is the one writer of
			-- `Player.Team`, and a pad that changed it would be a second one.
			expect((spawn :: any).AllowTeamChangeOnTouch).to.equal(false)
			-- A `SpawnLocation` grants a 10-second ForceField by default; Karen did not ask for a
			-- bubble round every player at the lodge.
			expect((spawn :: any).Duration).to.equal(0)
		end)

		it("leaves the doorway a GAP: nothing stands in it", function()
			-- Karen asked for a *"door you walk through"*, so the door is the absence of parts. The
			-- leaf, the lintel and the two jambs are all BESIDE or ABOVE the hole, never in it.
			--
			-- THE VOLUME, SAMPLED, AND NOT THE CENTRES. Round 2's note: a centre test passes any part
			-- whose BOX reaches into the opening while its middle sits outside it -- which is most of
			-- the ways a doorway gets blocked, a lintel that hangs too low being the obvious one.
			local room = Build.roomFor(anchor, CFG)
			local origin = anchor + CFG.LODGE.OFFSET
			local frontZ = origin.Z - CFG.LODGE.SIZE.Z / 2
			for stepX = -2, 2 do
				for stepY = 0, 8 do
					for stepZ = -1, 1 do
						local at = Vector3.new(
							origin.X + stepX * (CFG.LODGE.DOOR.WIDTH / 2 - 0.4) / 2,
							room.centre.Y + 0.3 + stepY * (CFG.LODGE.DOOR.HEIGHT - 0.6) / 8,
							frontZ + stepZ * CFG.LODGE.LOG_DIAMETER / 2
						)
						for _, descendant in ipairs(folder:GetDescendants()) do
							if descendant:IsA("BasePart") and descendant.CanCollide then
								local piece = descendant :: BasePart
								local near = piece.CFrame:PointToObjectSpace(at)
								if
									math.abs(near.X) < piece.Size.X / 2
									and math.abs(near.Y) < piece.Size.Y / 2
									and math.abs(near.Z) < piece.Size.Z / 2
								then
									error(string.format("%s stands in the doorway", piece.Name), 0)
								end
							end
						end
					end
				end
			end
		end)

		it("really CUTS the door and every window out of the log wall, away from the origin too", function()
			-- THE CASE THAT FAILS ON THE BUG THIS LODGE SHIPPED WITH FOR ONE PHOTOGRAPH. An opening
			-- is written in the config as studs from the lodge's own middle; a wall run is built in
			-- WORLD coordinates. Comparing the two cut nothing, and every course was built whole --
			-- a hunting house with no door and no windows at all.
			--
			-- AND IT IS BUILT AT x = 2850, NOT AT THE ORIGIN. The rest of this file anchors at
			-- (0, 100, 0), where the two frames of reference are the same number and the bug cannot
			-- be seen. Karen's lobby is at x 2850, z -2950.
			local far = Vector3.new(2850, 100, -2950)
			local other = Instance.new("Folder")
			other.Name = "LobbyFarSpecWorld"
			other.Parent = Workspace
			local built = Build.build(other, far, CFG, nil)
			local origin = far + CFG.LODGE.OFFSET
			local room = Build.roomFor(far, CFG)
			local d = CFG.LODGE.LOG_DIAMETER
			local holes = {
				{
					at = Vector3.new(
						origin.X,
						room.centre.Y + CFG.LODGE.DOOR.HEIGHT / 2,
						origin.Z - room.halfZ - d / 2
					),
					fills = "DoorLintel",
					door = true,
				},
			}
			for index, row in ipairs(CFG.LODGE.WINDOWS) do
				local y = room.centre.Y + CFG.LODGE.WINDOW.SILL_STUDS + CFG.LODGE.WINDOW.HEIGHT / 2
				local at
				if row.wall == "south" then
					at = Vector3.new(origin.X + row.along, y, origin.Z - room.halfZ - d / 2)
				elseif row.wall == "north" then
					at = Vector3.new(origin.X + row.along, y, origin.Z + room.halfZ + d / 2)
				elseif row.wall == "west" then
					at = Vector3.new(origin.X - room.halfX - d / 2, y, origin.Z + row.along)
				else
					at = Vector3.new(origin.X + room.halfX + d / 2, y, origin.Z + row.along)
				end
				table.insert(holes, { at = at, fills = string.format("WindowGlass%d", index), door = false })
			end
			local filled = nil
			local problem = nil
			for _, hole in ipairs(holes) do
				for _, descendant in ipairs(built:GetDescendants()) do
					if descendant:IsA("BasePart") and string.match(descendant.Name, "^Wall%u") then
						local piece = descendant :: BasePart
						-- A LOG IS A CYLINDER whose length is its X, so its box in its own frame is
						-- the test: a wall log containing the middle of an opening is an opening
						-- that was never cut.
						local near = piece.CFrame:PointToObjectSpace(hole.at)
						local inside = math.abs(near.X) < piece.Size.X / 2
							and math.abs(near.Y) < piece.Size.Y / 2
							and math.abs(near.Z) < piece.Size.Z / 2
						if inside and filled == nil then
							filled = piece.Name
						end
					end
				end
			end
			-- ...AND THE HOLE IS EXACTLY AS TALL AS THE THING THAT FILLS IT. ROUND 1'S BLOCKING
			-- FINDING, as the case that fails without the fix: a log is a whole cylinder, so a course
			-- that overlaps an opening at all is DROPPED and the hole in the wall is always a whole
			-- number of courses -- 1.8 to 9.0 studs, while a frame built to `SILL_STUDS` 3.4 and
			-- `HEIGHT` 4.4 covered 3.4 to 7.8. Two open slots per window, eight in the house, at knee
			-- height and over the head.
			--
			-- SAMPLED RATHER THAN COMPUTED: walk a line up the wall plane at the opening's own
			-- `along` and ask what is open, which is what an eye inside the room does.
			local step = 0.15
			for _, hole in ipairs(holes) do
				local lowest, highest = nil, nil
				local wallTop = room.centre.Y + room.height
				local y = room.centre.Y + 0.05
				while y < wallTop do
					local at = Vector3.new(hole.at.X, y, hole.at.Z)
					local blocked = false
					for _, descendant in ipairs(built:GetDescendants()) do
						if descendant:IsA("BasePart") and string.match(descendant.Name, "^Wall%u") then
							local piece = descendant :: BasePart
							local near = piece.CFrame:PointToObjectSpace(at)
							if
								math.abs(near.X) < piece.Size.X / 2
								and math.abs(near.Y) < piece.Size.Y / 2
								and math.abs(near.Z) < piece.Size.Z / 2
							then
								blocked = true
								break
							end
						end
					end
					if not blocked then
						lowest = lowest or y
						highest = y
					end
					y += step
				end
				-- NOT ONE THROW BEFORE THE `Destroy` BELOW, AND `expect` THROWS. Round 2, finding 2:
				-- `expect(lowest).to.be.ok()` right here is the "the wall was never cut at all"
				-- failure this case exists to catch, so the first time it did its job it leaked a
				-- live lobby spawn into `Workspace` and poisoned the rest of the run -- the very
				-- defect the round before it had claimed to fix. Every failure is a STRING now, and
				-- nothing is asserted until the folder is gone.
				local fills = built:FindFirstChild(hole.fills, true)
				if lowest == nil then
					problem = problem or string.format("%s: the wall was never cut at all", hole.fills)
				elseif fills == nil or not fills:IsA("BasePart") then
					problem = problem or string.format("%s: nothing was built to fill the hole", hole.fills)
				else
					-- WHAT FILLS IT: the pane for a window, and for the door the floor below and the
					-- lintel above -- both measured off the parts that were really built.
					local board = fills :: BasePart
					local wantLow = if hole.door then room.centre.Y else board.Position.Y - board.Size.Y / 2
					local wantHigh = if hole.door
						then board.Position.Y - board.Size.Y / 2
						else board.Position.Y + board.Size.Y / 2
					if
						math.abs((lowest :: number) - wantLow) > step * 2
						or math.abs((highest :: number) - wantHigh) > step * 2
					then
						problem = problem
							or string.format(
								"the wall is open from %.2f to %.2f but %s covers %.2f to %.2f",
								lowest :: number,
								highest :: number,
								hole.fills,
								wantLow,
								wantHigh
							)
					end
				end
			end
			-- ...AND THE FRAME IS REALLY THERE, so "cut" cannot be satisfied by building no wall.
			local sill = built:FindFirstChild("WindowSill1", true) ~= nil
			local shutter = built:FindFirstChild("Shutter1W", true) ~= nil
			local glass = built:FindFirstChild("WindowGlass1", true) ~= nil
			-- DESTROYED BEFORE ANYTHING IS ASSERTED, AND THAT IS NOT TIDINESS. A lobby carries an
			-- ENABLED `SpawnLocation`; an `error` raised inside the loop above skipped this line
			-- once, the folder stayed in `Workspace` for the rest of the run, and three drive cases
			-- in `zz_drive_boundary` respawned their player three thousand studs from the drive. One
			-- spec bug, four failures.
			other:Destroy()
			if filled ~= nil then
				error(string.format("%s fills an opening that should be a hole", filled), 0)
			end
			if problem ~= nil then
				error(problem, 0)
			end
			expect(sill).to.equal(true)
			expect(shutter).to.equal(true)
			expect(glass).to.equal(true)
		end)

		it("is WALKABLE from the doorway to the counter, and the room is big enough to be one", function()
			-- THE TASK OWN NUMBER: *"interior at least 14x10 studs walkable"*. This is both halves of
			-- it -- the rectangle, and the line a player actually walks along it.
			local room = Build.roomFor(anchor, CFG)
			expect(room.halfX * 2 >= 14).to.equal(true)
			expect(room.halfZ * 2 >= 10).to.equal(true)
			-- A CHARACTER IS ABOUT 5 STUDS TALL AND 2 WIDE. Walk from a stud inside the doorway to
			-- the front of the counter, a step at a time, and let nothing solid stand in the
			-- corridor: the fireplace is on the far side of the room and the table is clamped to its
			-- own offset, but a bench that drifted into the line would be found here rather than by
			-- Karen.
			local counter = folder:FindFirstChild(Data.COUNTER_NAME, true) :: BasePart
			expect(counter).to.be.ok()
			local from = Vector3.new(room.centre.X, room.centre.Y + 2.6, room.centre.Z - room.halfZ + 1.5)
			local to = Vector3.new(counter.Position.X, room.centre.Y + 2.6, counter.Position.Z - counter.Size.Z / 2 - 2)
			local steps = 24
			for step = 0, steps do
				local at = from:Lerp(to, step / steps)
				for _, descendant in ipairs(folder:GetDescendants()) do
					if descendant:IsA("BasePart") and descendant.CanCollide then
						local piece = descendant :: BasePart
						local near = piece.CFrame:PointToObjectSpace(at)
						-- HALF A BODY WIDTH of clearance either side, and the body own height: a
						-- part whose box reaches into that box is a part a player walks into.
						local hitX = math.abs(near.X) < piece.Size.X / 2 + 1
						local hitZ = math.abs(near.Z) < piece.Size.Z / 2 + 1
						local hitY = math.abs(near.Y) < piece.Size.Y / 2 + 2.4
						if hitX and hitY and hitZ then
							error(string.format("%s blocks the walk from the door to the counter", piece.Name), 0)
						end
					end
				end
			end
		end)

		it("has a warm inside: a real fire, the lanterns, and the shop counter task 178 fills", function()
			local inside = folder:FindFirstChild("Inside", true)
			expect(inside).to.be.ok()
			local lights = 0
			for _, descendant in ipairs(folder:GetDescendants()) do
				if descendant:IsA("PointLight") then
					lights += 1
				end
			end
			-- THE FIRE, THREE LANTERNS INSIDE AND TWO ON THE PORCH, and every one of them is a
			-- `PointLight` written ONCE: nothing in this lodge is animated by a script, so there is
			-- no second writer of anything. The count is read off the config, so a fourth lantern is
			-- a row and not a failing test.
			expect(lights).to.equal(1 + #CFG.LODGE.LANTERN.ALONG + 2)
			-- KAREN ASKED FOR A FIREPLACE WITH A FIRE IN IT: the `Fire`, the embers and the light
			-- all hang on the one part, which is what makes "the fire is present" checkable.
			local fire = folder:FindFirstChild("Fire", true)
			expect(fire).to.be.ok()
			expect((fire :: Instance):FindFirstChildOfClass("Fire")).to.be.ok()
			expect((fire :: Instance):FindFirstChildOfClass("ParticleEmitter")).to.be.ok()
			expect((fire :: Instance):FindFirstChildOfClass("PointLight")).to.be.ok()
			expect(folder:FindFirstChild("FireplaceMantel", true)).to.be.ok()
			expect(folder:FindFirstChild("FireplaceHearth", true)).to.be.ok()
			expect(folder:FindFirstChild("Counter", true)).to.be.ok()
			local shopSign = folder:FindFirstChild("ShopSign", true)
			expect(shopSign).to.be.ok()
			local label = (shopSign :: Instance):FindFirstChild("Text", true)
			expect(label).to.be.ok()
			expect((label :: TextLabel).Text).to.equal(CFG.LODGE.SIGN_TEXT)
		end)

		-- TASK 177'S "STAND HERE TO HUNT" SIGN POST IS GONE WITH THE CIRCLE (task 182). What a pad
		-- is for is written on the pad's own billboard -- `STEP ON TO HUNT` is not a sign in the
		-- yard, it is the count line before anybody is on it -- and the case above asserts that no
		-- sign survives.

		it("holds no Script, LocalScript or ModuleScript anywhere in the tree", function()
			-- CLAUDE.md: nothing script-like is ever created outside a Rojo-owned path, and the
			-- harness fails if one exists. A world builder is the one place that could break it.
			for _, descendant in ipairs(folder:GetDescendants()) do
				expect(descendant:IsA("LuaSourceContainer")).to.equal(false)
			end
		end)

		it("rebuilds in place rather than leaving two lodges standing", function()
			local again = Build.build(container, anchor, CFG)
			expect(again).to.be.ok()
			local found = 0
			for _, child in ipairs(container:GetChildren()) do
				if child.Name == Data.FOLDER_NAME then
					found += 1
				end
			end
			expect(found).to.equal(1)
		end)
	end)

	-- ------------------------------------------------ the free models, and the fallback (task 180)
	--
	-- KAREN, 2026-10-14 ~09:30: *"we need car truck model or hunting bus also use free model"*, and
	-- ~21:30, on the free cabins: *"all of then garbadge ... you build then one proper europen
	-- standart"*.
	--
	-- SO SINCE TASK 187 THE FREE MODELS ARE THE TRUCK AND THE TREES, AND NOTHING ELSE. The lodge and
	-- every trophy on its walls are ours, which is what the first two cases below are for: the house
	-- is the SAME house whether or not the template folder exists at all.
	--
	-- THE CLAIM THAT MATTERS MOST HERE IS STILL THE FALLBACK. The models live in
	-- `Workspace.LobbyAssets`, which is Studio content in ONE place; the lobby still has to build in
	-- the other one, in a place where somebody renamed the folder, and in this spec.
	describe("the free models, and what happens without them", function()
		local anchor = Vector3.new(0, 100, 0)
		local container

		beforeEach(function()
			container = Instance.new("Folder")
			container.Name = "LobbyModelSpecWorld"
			container.Parent = Workspace
		end)

		afterEach(function()
			container:Destroy()
		end)

		it("builds OUR lodge and the four trucks out of the templates", function()
			local templates = fakeTemplates()
			local folder, _marker, _spawn, count = Build.build(container, anchor, CFG, templates)
			local stats = Build.stats()
			-- NO CLONED HOUSE, EVER AGAIN (task 187). `House` was the free cabin Karen called
			-- *"garbadge"*. The load-bearing half of this is the CONFIG -- there is no lodge template
			-- name left to look for, so no folder anybody parks in `Workspace` can bring one back --
			-- and the wall below is what says our own was built instead. (Review round 1, note: the
			-- `House` line alone cannot fail, because `fakeTemplates` no longer makes one.)
			expect((CFG :: any).LODGE.MODEL).to.never.be.ok()
			expect((Data.TEMPLATE :: any).LODGE).to.never.be.ok()
			expect((Data.TEMPLATE :: any).DEER).to.never.be.ok()
			expect(folder:FindFirstChild("House", true)).to.never.be.ok()
			expect(folder:FindFirstChild("WallN1_1", true)).to.be.ok() -- the back wall lowest log
			for index = 1, CFG.TRUCK.COUNT do
				expect(folder:FindFirstChild(string.format("Truck%d", index), true)).to.be.ok()
			end
			expect(folder:FindFirstChild("TreeLine")).to.be.ok()
			-- FOUR TRUCKS AND MOST OF THE TREE LINE, and nothing else is a clone any more.
			-- It is a BOUND and not an equality on purpose: the arc crosses the road corridor and a
			-- tree that would stand in the road is skipped, so `TREELINE.COUNT` is how many are
			-- ATTEMPTED and never how many are placed.
			local trees = stats.models - CFG.TRUCK.COUNT
			expect(trees > 0).to.equal(true)
			expect(trees <= CFG.TREELINE.COUNT).to.equal(true)
			expect(trees >= CFG.TREELINE.COUNT - 6).to.equal(true)
			expect(stats.fallbacks).to.equal(0)
			expect(count <= CFG.MAX_PARTS).to.equal(true)
			templates:Destroy()
		end)

		it("builds the SAME lodge when the template folder is not there at all", function()
			local folder, _marker, _spawn, count = Build.build(container, anchor, CFG, nil)
			local stats = Build.stats()
			-- THE DEV PLACE HAS NEVER HAD THE TEMPLATES, and the harness runs there: the house, its
			-- fire and its antlers must not depend on Studio content that exists in one place.
			expect(folder:FindFirstChild("WallN1_1", true)).to.be.ok()
			expect(folder:FindFirstChild("Floor", true)).to.be.ok()
			expect(folder:FindFirstChild("Plinth", true)).to.be.ok()
			expect(folder:FindFirstChild("ChimneyStack", true)).to.be.ok()
			expect(folder:FindFirstChild("Fire", true)).to.be.ok()
			expect(folder:FindFirstChild("Trophies", true)).to.be.ok()
			for index = 1, CFG.TRUCK.COUNT do
				local made = folder:FindFirstChild(string.format("Truck%d", index), true)
				expect(made).to.be.ok()
				expect((made :: Instance):FindFirstChild("Cab")).to.be.ok() -- the parts truck
			end
			expect(folder:FindFirstChild("TreeLine")).to.never.be.ok()
			expect(stats.models).to.equal(0)
			expect(count <= CFG.MAX_PARTS).to.equal(true)
			expect(count > 50).to.equal(true)
		end)

		it("falls back one piece at a time when only some of the templates are there", function()
			local templates = fakeTemplates()
			local truckTemplate = templates:FindFirstChild(Data.TEMPLATE.TRUCK) :: Instance
			truckTemplate:Destroy()
			local folder = Build.build(container, anchor, CFG, templates)
			expect(folder:FindFirstChild("TreeLine")).to.be.ok() -- the trees are still clones
			local first = folder:FindFirstChild("Truck1", true)
			expect(first).to.be.ok()
			expect((first :: Instance):FindFirstChild("Cab")).to.be.ok() -- ...and parts trucks
			expect(Build.stats().fallbacks >= CFG.TRUCK.COUNT).to.equal(true)
			templates:Destroy()
		end)

		it("strips a script a free model smuggled in, and says how many", function()
			local templates = fakeTemplates(true)
			local folder = Build.build(container, anchor, CFG, templates)
			-- ONE SCRIPT IN THE TEMPLATE, ONE PER CLONE OF IT: the truck is parked in four bays, so
			-- four is the right answer and `1` would mean three of them got through.
			expect(Build.stats().strippedScripts).to.equal(CFG.TRUCK.COUNT)
			for _, descendant in ipairs(folder:GetDescendants()) do
				expect(descendant:IsA("LuaSourceContainer")).to.equal(false)
			end
			-- and the TEMPLATE is untouched: the clone was stripped, never the original
			expect(templates:FindFirstChild("Fire_Effect", true)).to.be.ok()
			templates:Destroy()
		end)

		it("anchors every cloned part, however the free model shipped it", function()
			local templates = fakeTemplates()
			local folder = Build.build(container, anchor, CFG, templates)
			for _, descendant in ipairs(folder:GetDescendants()) do
				if descendant:IsA("BasePart") then
					expect(descendant.Anchored).to.equal(true)
				end
			end
			templates:Destroy()
		end)

		it("parks the trucks in a row, a bay apart, starting where 177's one truck stood", function()
			local templates = fakeTemplates()
			local folder = Build.build(container, anchor, CFG, templates)
			local previous = 0
			for index = 1, CFG.TRUCK.COUNT do
				local made = folder:FindFirstChild(string.format("Truck%d", index), true) :: Model
				local x = made:GetPivot().Position.X
				if index == 1 then
					expect(math.abs(x - (anchor.X + CFG.TRUCK.OFFSET.X)) < 0.01).to.equal(true)
				else
					expect(math.abs((x - previous) - CFG.TRUCK.BAY_GAP_STUDS) < 0.01).to.equal(true)
				end
				previous = x
			end
			templates:Destroy()
		end)

		it("stands every free model ON the shelf, not in it and not over it", function()
			local templates = fakeTemplates()
			local folder = Build.build(container, anchor, CFG, templates)
			for _, name in ipairs({ "Truck1", "Truck4" }) do
				local made = folder:FindFirstChild(name, true) :: Model
				local box, size = made:GetBoundingBox()
				expect(math.abs((box.Position.Y - size.Y / 2) - anchor.Y) < 0.05).to.equal(true)
			end
			templates:Destroy()
		end)

		-- ------------------------------------------------------------ task 186: the trucks
		--
		-- KAREN, 2026-10-14 ~17:00: *"car tyers are inside earth"*, and ~21:15 *"make cars comoflash
		-- like military like hunting cars"*.
		--
		-- WHAT WAS MEASURED IN THE LIVE PLACE BEFORE ANY OF IT WAS WRITTEN: every tyre of all four
		-- trucks 0.752 studs UNDER the terrain, and the east bay's worst wheel 2.017 under, with a
		-- 1.266-stud spread across that one truck's own four wheels. So there are two claims here
		-- and they are different claims: no wheel may be under its ground (ever, under any reader),
		-- and on ground that really is a plane every wheel must be ON it.
		it("settles every wheel onto the ground a world can measure", function()
			-- A SLOPE, not a step: 0.03 per stud is ~1.7 degrees, which is inside `MAX_TILT_DEGREES`
			-- and well over `MIN_TILT_DEGREES`, so this drives the tilt AND the lift together.
			local function sloped(x: number, _z: number): number
				return anchor.Y + 1 + (x - anchor.X) * 0.03
			end
			-- THE PARTS BUILD, because its trucks have parts named `Wheel` -- the branch the live
			-- free model takes too, through its four `Tire` MeshParts.
			local folder = Build.build(container, anchor, CFG, nil, { groundAt = sloped } :: any)
			expect(Build.stats().trucksSettled).to.equal(CFG.TRUCK.COUNT)
			local wheels = 0
			for index = 1, CFG.TRUCK.COUNT do
				local made = folder:FindFirstChild(string.format("Truck%d", index), true) :: Instance
				for _, piece in ipairs(made:GetDescendants()) do
					if piece:IsA("BasePart") and Build.truckSkinOf(piece.Name, piece.Material) == "tyre" then
						wheels += 1
						local bottom = piece.Position.Y - piece.Size.Y / 2
						local ground = sloped(piece.Position.X, piece.Position.Z)
						-- ON the ground: never under it, and never floating.
						expect(bottom >= ground - 1e-3).to.equal(true)
						expect(bottom - ground <= 0.2).to.equal(true)
					end
				end
			end
			expect(wheels).to.equal(CFG.TRUCK.COUNT * CFG.TRUCK.WHEELS)
			-- ...AND THE WORST OF THEM IS THE NUMBER THE CONSOLE PRINTS.
			expect(Build.stats().truckGroundStuds <= 0.2).to.equal(true)
		end)

		it("never sinks a truck, even where the ground is steeper than it may tilt", function()
			-- THE CLAMP'S OWN CASE. Half a stud per stud is 26 degrees, four times
			-- `MAX_TILT_DEGREES`: the truck CANNOT be stood on that plane, and the one thing it must
			-- still do is not bury a wheel. The lift is the WORST contact's, so the guarantee
			-- survives a tilt that was refused.
			local function cliff(x: number, _z: number): number
				return anchor.Y + (x - anchor.X) * 0.5
			end
			local folder = Build.build(container, anchor, CFG, nil, { groundAt = cliff } :: any)
			for index = 1, CFG.TRUCK.COUNT do
				local made = folder:FindFirstChild(string.format("Truck%d", index), true) :: Instance
				for _, piece in ipairs(made:GetDescendants()) do
					if piece:IsA("BasePart") and Build.truckSkinOf(piece.Name, piece.Material) == "tyre" then
						local bottom = piece.Position.Y - piece.Size.Y / 2
						expect(bottom >= cliff(piece.Position.X, piece.Position.Z) - 1e-3).to.equal(true)
					end
				end
			end
		end)

		it("leaves a truck exactly on the shelf when the world cannot measure the ground", function()
			-- THE FALLBACK IS THE OLD BEHAVIOUR, UNCHANGED, and it is what every other spec in this
			-- file builds with. A reader that throws is the same state as no reader at all: half a
			-- measurement is how a truck ends up tilted onto a wheel whose ground nobody knows.
			local folder = Build.build(
				container,
				anchor,
				CFG,
				nil,
				{
					groundAt = function(): number?
						error("no ground here")
					end,
				} :: any
			)
			expect(Build.stats().trucksSettled).to.equal(0)
			local made = folder:FindFirstChild("Truck1", true) :: Instance
			for _, piece in ipairs(made:GetDescendants()) do
				if piece:IsA("BasePart") and Build.truckSkinOf(piece.Name, piece.Material) == "tyre" then
					expect(math.abs((piece.Position.Y - piece.Size.Y / 2) - anchor.Y) < 1e-3).to.equal(true)
				end
			end
		end)

		it("settles a model whose wheels are not called wheels, on its own footprint", function()
			-- THE SPEC'S STAND-IN TRUCK IS ONE PART CALLED `Body`, and so is any replacement model
			-- whose author named the wheels in another language. Then the contacts are the
			-- FOOTPRINT's four corners, and the claim is the one that always holds: nothing sunk.
			local templates = fakeTemplates()
			local function hump(_x: number, _z: number): number
				return anchor.Y + 2.5
			end
			local folder = Build.build(container, anchor, CFG, templates, { groundAt = hump } :: any)
			expect(Build.stats().trucksSettled).to.equal(CFG.TRUCK.COUNT)
			for index = 1, CFG.TRUCK.COUNT do
				local made = folder:FindFirstChild(string.format("Truck%d", index), true) :: Model
				local box, size = made:GetBoundingBox()
				local lowest = box.Position.Y - size.Y / 2
				expect(lowest >= anchor.Y + 2.5 - 1e-3).to.equal(true)
				expect(lowest - (anchor.Y + 2.5) <= 0.2).to.equal(true)
			end
			templates:Destroy()
		end)

		it("paints every truck in the bay's own camouflage, and leaves the glass alone", function()
			local folder = Build.build(container, anchor, CFG, nil)
			expect(Build.stats().truckPainted > 0).to.equal(true)
			local spec = CFG.TRUCK.CAMO
			for index = 1, CFG.TRUCK.COUNT do
				local made = folder:FindFirstChild(string.format("Truck%d", index), true) :: Instance
				local palette = spec.TONES[(index - 1) % #spec.TONES + 1]
				local tones: { [string]: boolean } = {}
				local panels = 0
				for _, piece in ipairs(made:GetDescendants()) do
					if piece:IsA("BasePart") then
						local skin = Build.truckSkinOf(piece.Name, piece.Material)
						if skin == "body" then
							panels += 1
							local wanted = false
							for _, tone in ipairs(palette) do
								if piece.Color == tone then
									wanted = true
								end
							end
							expect(wanted).to.equal(true)
							expect(piece.Material).to.equal(spec.BODY_MATERIAL)
							tones[tostring(piece.Color)] = true
						elseif skin == "tyre" then
							expect(piece.Color).to.equal(spec.TYRE)
						elseif skin == "glass" then
							-- THE WINDOWS ARE KEPT (the Director's brief), and the parts truck's own
							-- windscreen is what proves it: still glass, still its own colour.
							expect(piece.Material).to.equal(Enum.Material.Glass)
						end
					end
				end
				expect(panels > 0).to.equal(true)
				-- MORE THAN ONE TONE ON ONE TRUCK is the difference between a camouflage scheme and
				-- one flat colour, and it is what the alternating walk through the palette buys.
				local distinct = 0
				for _ in pairs(tones) do
					distinct += 1
				end
				expect(distinct > 1).to.equal(true)
			end
		end)

		it("knows which part of a truck is paint, glass, a lamp or a wheel", function()
			-- PURE, and the ORDER is the claim: `WindowFrame` is a free model's real part name and it
			-- carries both words, so a frame that got painted olive would put an olive bar across a
			-- window. Glass first, then the lamps, then the wheels, and only what is left is paint.
			expect(Build.truckSkinOf("WindowFrame", Enum.Material.Fabric)).to.equal("glass")
			expect(Build.truckSkinOf("Windscreen", Enum.Material.Glass)).to.equal("glass")
			expect(Build.truckSkinOf("Light", Enum.Material.Neon)).to.equal("light")
			expect(Build.truckSkinOf("T", Enum.Material.Neon)).to.equal("light")
			expect(Build.truckSkinOf("Tire", Enum.Material.Fabric)).to.equal("tyre")
			expect(Build.truckSkinOf("Wheel3", Enum.Material.Rubber)).to.equal("tyre")
			expect(Build.truckSkinOf("Rim", Enum.Material.Fabric)).to.equal("rim")
			expect(Build.truckSkinOf("Color", Enum.Material.SmoothPlastic)).to.equal("body")
			expect(Build.truckSkinOf("Bonnet", Enum.Material.Metal)).to.equal("body")
			expect(Build.truckSkinOf("BedSide1", Enum.Material.Metal)).to.equal("body")
			-- ...AND EVERYTHING THIS SYSTEM DID NOT BUILD IS LEFT ALONE: the bumpers, the grille and
			-- the interior ship near-black, which is what a military truck's trim is anyway.
			expect(Build.truckSkinOf("Bumper", Enum.Material.Fabric)).to.equal("keep")
			expect(Build.truckSkinOf("Grill1", Enum.Material.Fabric)).to.equal("keep")
			expect(Build.truckSkinOf("Steering1", Enum.Material.Fabric)).to.equal("keep")
		end)

		it("fits a plane through four ground samples, and refuses to fit a line", function()
			-- PURE. A plane that IS y = 0.2x - 0.1z comes back as exactly that, which is what makes
			-- the tilt a measurement rather than a guess at a direction.
			local points = {}
			for _, x in ipairs({ -5, 5 }) do
				for _, z in ipairs({ -3, 3 }) do
					table.insert(points, { x = x, z = z, y = 10 + 0.2 * x - 0.1 * z })
				end
			end
			local slopeX, slopeZ = Build.groundFit(points)
			expect(math.abs(slopeX - 0.2) < 1e-6).to.equal(true)
			expect(math.abs(slopeZ + 0.1) < 1e-6).to.equal(true)
			-- FLAT GROUND IS FLAT.
			local levelX, levelZ = Build.groundFit({
				{ x = 0, z = 0, y = 7 },
				{ x = 4, z = 0, y = 7 },
				{ x = 0, z = 4, y = 7 },
				{ x = 4, z = 4, y = 7 },
			})
			expect(levelX).to.equal(0)
			expect(levelZ).to.equal(0)
			-- ...AND SAMPLES ALL IN A LINE, OR TOO FEW OF THEM, ANSWER LEVEL rather than dividing by
			-- a determinant at zero: a truck that cannot be fitted stays flat.
			local lineX, lineZ = Build.groundFit({
				{ x = 0, z = 0, y = 1 },
				{ x = 1, z = 0, y = 2 },
				{ x = 2, z = 0, y = 3 },
			})
			expect(lineX).to.equal(0)
			expect(lineZ).to.equal(0)
			local fewX, fewZ = Build.groundFit({ { x = 0, z = 0, y = 1 }, { x = 1, z = 1, y = 9 } })
			expect(fewX).to.equal(0)
			expect(fewZ).to.equal(0)
		end)

		it("clamps the tilt at both ends, so a bad ray cannot tip a truck over", function()
			-- PURE. Level ground is identity, a slope under the floor is identity, a slope over the
			-- ceiling is the ceiling -- and the lean is still the way the ground rises.
			local small = math.rad(0.25)
			local big = math.rad(6)
			expect(Build.tiltFrom(0, 0, small, big)).to.equal(CFrame.identity)
			expect(Build.tiltFrom(0.001, 0, small, big)).to.equal(CFrame.identity)
			local up = Build.tiltFrom(0.5, 0, small, big).UpVector
			-- SIX DEGREES AND NOT TWENTY-SIX: the angle off vertical is the clamp exactly.
			expect(math.abs(math.deg(math.acos(math.clamp(up.Y, -1, 1))) - 6) < 1e-3).to.equal(true)
			-- ...AND IT LEANS THE WAY THE GROUND RISES: a plane climbing in +x tips the up vector
			-- back toward -x.
			expect(up.X < 0).to.equal(true)
			local inside = Build.tiltFrom(0.05, 0, small, big).UpVector
			local leaned = math.deg(math.acos(math.clamp(inside.Y, -1, 1)))
			expect(math.abs(leaned - math.deg(math.atan(0.05))) < 1e-3).to.equal(true)
		end)

		it("keeps the road, the fences and the trees inside the field's own rectangle", function()
			-- THE SAME BOUND `Field.fill` IS HELD TO. The shelf is 220 x 220 and nothing else is
			-- flat: a verge or a fence post laid past its edge would float over the fall the raycast
			-- grid measured, which is the failure this project is named after.
			local templates = fakeTemplates()
			local folder = Build.build(container, anchor, CFG, templates)
			local half = CFG.FIELD.SPAN_STUDS / 2
			for _, group in ipairs({ "Road", "Fences", "TreeLine" }) do
				local made = folder:FindFirstChild(group)
				expect(made).to.be.ok()
				for _, descendant in ipairs((made :: Instance):GetDescendants()) do
					if descendant:IsA("BasePart") then
						local at = descendant.Position
						expect(math.abs(at.X - anchor.X) <= half).to.equal(true)
						expect(math.abs(at.Z - anchor.Z) <= half).to.equal(true)
					end
				end
			end
			templates:Destroy()
		end)

		it("hangs every trophy INSIDE the room, under its ceiling, and off the wall it names", function()
			-- THE BOUND IS THE ROOM AND NOT THE LODGE FOOTPRINT, which is task 180 round 1 finding 3:
			-- a footprint bound is a stud and a half outside the wall and cannot see the bug it was
			-- written for -- an inverted yaw puts a plaque a quarter of a stud past its own wall, in
			-- the open air. `Build.roomFor` is the same rectangle the mount itself used.
			--
			-- EVERY PART OF EVERY MOUNT is checked and not just the shield: the antler beams reach a
			-- stud and a half further out than the plaque and three higher, so they are the half of a
			-- mistake that goes through the wall or the boards first.
			local folder = Build.build(container, anchor, CFG, fakeTemplates())
			local room = Build.roomFor(anchor, CFG)
			local heads = folder:FindFirstChild("Trophies", true)
			expect(heads).to.be.ok()
			local plaques, pieces = 0, 0
			-- DESCENDANTS: a mount is a Folder of its own since task 187, which is what lets the
			-- builder measure one and move the whole thing if it does not fit.
			for _, descendant in ipairs((heads :: Instance):GetDescendants()) do
				if descendant:IsA("BasePart") then
					local piece = descendant :: BasePart
					pieces += 1
					if string.find(piece.Name, "Plaque", 1, true) then
						plaques += 1
					end
					local at = piece.Position
					expect(at.X <= room.centre.X + room.halfX).to.equal(true)
					expect(at.X >= room.centre.X - room.halfX).to.equal(true)
					expect(at.Z <= room.centre.Z + room.halfZ).to.equal(true)
					expect(at.Z >= room.centre.Z - room.halfZ).to.equal(true)
					-- ...and off the floor, and NOT THROUGH THE CEILING, which is the other half of
					-- that round: a 5.4-stud deer seated at its mount height stood 2.4 studs through
					-- a 7.4-stud room roof.
					--
					-- THE PART'S WHOLE EXTENT AND NOT ITS CENTRE (review round 1, note): an antler
					-- beam is a rotated cylinder whose top is a stud and a half above its middle, so
					-- a centre inside the room says nothing about the tine. This is the same box
					-- projection `Build.trophies` clamps with, which is what makes the clamp tested
					-- rather than asserted.
					local _, _, _, _, _, _, m10, m11, m12 = piece.CFrame:GetComponents()
					local reach = 0.5
						* (math.abs(m10) * piece.Size.X + math.abs(m11) * piece.Size.Y + math.abs(m12) * piece.Size.Z)
					expect(at.Y - reach > room.centre.Y).to.equal(true)
					expect(at.Y + reach <= room.centre.Y + room.height).to.equal(true)
				end
			end
			-- ONE SHIELD PER MOUNT, and a mount is never a bare shield: twelve rows come to well over
			-- a hundred parts, which is what a trophy wall is.
			expect(plaques).to.equal(#CFG.TROPHIES.MOUNTS)
			expect(pieces > #CFG.TROPHIES.MOUNTS * 4).to.equal(true)
		end)

		it("hangs nothing on a wall in front of a window or the shop counter", function()
			-- A TROPHY ROW IS DATA, so the way it goes wrong is a row that names a wall something
			-- else already owns -- which is exactly what task 180 shipped: two heads on the back
			-- wall, one half inside the chimney and one behind the SHOP sign.
			local folder = Build.build(container, anchor, CFG, nil)
			local room = Build.roomFor(anchor, CFG)
			local heads = folder:FindFirstChild("Trophies", true) :: Instance
			local counter = folder:FindFirstChild(Data.COUNTER_NAME, true) :: BasePart
			for _, descendant in ipairs(heads:GetDescendants()) do
				if descendant:IsA("BasePart") and string.find(descendant.Name, "Plaque", 1, true) then
					local at = (descendant :: BasePart).Position
					-- NOT OVER THE COUNTER: the shield would be behind the SHOP sign.
					local overCounter = math.abs(at.X - counter.Position.X) < counter.Size.X / 2
						and math.abs(at.Z - counter.Position.Z) < 3
					expect(overCounter).to.equal(false)
					-- NOT IN A WINDOW, and a window is a RECTANGLE: a shield clashes only when it
					-- overlaps the opening BOTH along the wall and in height. A row above a window is
					-- a thing a lodge actually has.
					for _, row in ipairs(CFG.LODGE.WINDOWS) do
						local sameWall = (row.wall == "north" and at.Z > room.centre.Z + room.halfZ - 1)
							or (row.wall == "south" and at.Z < room.centre.Z - room.halfZ + 1)
							or (row.wall == "east" and at.X > room.centre.X + room.halfX - 1)
							or (row.wall == "west" and at.X < room.centre.X - room.halfX + 1)
						if sameWall then
							local along = if row.wall == "north" or row.wall == "south"
								then at.X - room.centre.X
								else at.Z - room.centre.Z
							local across = math.abs(along - row.along)
								< CFG.LODGE.WINDOW.WIDTH / 2 + CFG.TROPHIES.ROE.PLAQUE.X / 2
							local high = at.Y - room.centre.Y
							local overlaps = high > CFG.LODGE.WINDOW.SILL_STUDS - CFG.TROPHIES.ROE.PLAQUE.Y / 2
								and high < CFG.LODGE.WINDOW.SILL_STUDS + CFG.LODGE.WINDOW.HEIGHT
							expect(across and overlaps).to.equal(false)
						end
					end
				end
			end
		end)

		it("leaves no part of the lodge floating: every one of them touches another", function()
			-- THE TASK OWN WORDS: *"no floating parts (every part within the lodge bounds and
			-- supported)"*. A plaque hangs on a wall and a rafter hangs off a roof, so "supported"
			-- cannot mean "has ground under it"; what it can mean, and what this measures, is that
			-- every part of the building TOUCHES another part of the building -- and that all of them
			-- are inside the envelope the lodge is allowed to occupy.
			local folder = Build.build(container, anchor, CFG, nil)
			local lodge = folder:FindFirstChild("Lodge") :: Instance
			expect(lodge).to.be.ok()
			local origin = anchor + CFG.LODGE.OFFSET
			local boxes = {}
			for _, descendant in ipairs(lodge:GetDescendants()) do
				-- THE KEEPER IS A BODY AND NOT MASONRY: his limbs hang off his own joints.
				if descendant:IsA("BasePart") and descendant:FindFirstAncestorOfClass("Model") == nil then
					local piece = descendant :: BasePart
					-- THE ENVELOPE: the footprint plus the roof overhang and the chimney one side,
					-- the porch to the south, the ground below and the chimney pots above.
					local west = origin.X - CFG.LODGE.SIZE.X / 2 - CFG.LODGE.CHIMNEY.WIDTH - 2
					local east = origin.X + CFG.LODGE.SIZE.X / 2 + CFG.LODGE.ROOF.GABLE_STUDS + 2
					local south = origin.Z
						- CFG.LODGE.SIZE.Z / 2
						- CFG.LODGE.PORCH.DEPTH
						- CFG.LODGE.PORCH.STEPS * CFG.LODGE.PORCH.STEP_DEPTH
						- 2
					local north = origin.Z + CFG.LODGE.SIZE.Z / 2 + CFG.LODGE.ROOF.EAVE_STUDS + 2
					expect(piece.Position.X >= west and piece.Position.X <= east).to.equal(true)
					expect(piece.Position.Z >= south and piece.Position.Z <= north).to.equal(true)
					expect(piece.Position.Y >= origin.Y - 3).to.equal(true)
					expect(
						piece.Position.Y <= origin.Y + CFG.LODGE.RIDGE_STUDS + CFG.LODGE.CHIMNEY.ABOVE_RIDGE_STUDS + 4
					).to.equal(true)
					table.insert(boxes, piece)
				end
			end
			expect(#boxes > 200).to.equal(true)
			-- TOUCHING, measured as OVERLAPPING BOXES on all three axes with three quarters of a stud
			-- of slack -- loose enough for a rotated roof slab and tight enough to mean something.
			-- Round 1 used bounding SPHERES, and the plinth's sphere alone has a 22-stud radius, so
			-- nearly anything inside the envelope passed (review note). A box projected onto the
			-- world axes is still generous for a rotated part and is no longer generous about WHERE.
			local function extent(piece: BasePart): Vector3
				local cf = piece.CFrame
				local x, y, z = cf.RightVector, cf.UpVector, cf.LookVector
				local half = piece.Size / 2
				return Vector3.new(
					math.abs(x.X) * half.X + math.abs(y.X) * half.Y + math.abs(z.X) * half.Z,
					math.abs(x.Y) * half.X + math.abs(y.Y) * half.Y + math.abs(z.Y) * half.Z,
					math.abs(x.Z) * half.X + math.abs(y.Z) * half.Y + math.abs(z.Z) * half.Z
				)
			end
			local spans = {}
			for index, piece in ipairs(boxes) do
				spans[index] = extent(piece)
			end
			for index, piece in ipairs(boxes) do
				local touched = false
				for other, another in ipairs(boxes) do
					if another ~= piece then
						local gap = another.Position - piece.Position
						local reach = spans[index] + spans[other] + Vector3.new(0.75, 0.75, 0.75)
						if math.abs(gap.X) <= reach.X and math.abs(gap.Y) <= reach.Y and math.abs(gap.Z) <= reach.Z then
							touched = true
							break
						end
					end
				end
				if not touched then
					error(string.format("%s floats: nothing of the lodge is within reach of it", piece.Name), 0)
				end
			end
		end)

		it("keeps the fence line OUT of the yard, the porch, the spawn and the lodge, in BOTH builds", function()
			-- ROUND 2'S BLOCKING FINDING, as a case that fails without the fix. `POSTS_PER_SIDE = 9`
			-- from z -98 at 18 studs ran the WEST line (x +2, two studs off the lodge's centre line)
			-- to z +46 -- the lodge's own centre. One post stood inside the cabin through its
			-- floorboards, one in the middle of the porch beside the doorway, and a rail lay across
			-- the spawn pad at knee height. Nothing bounded it: the field rectangle is 110 studs away.
			--
			-- The bound is the YARD'S southern edge, because everything the fence must not reach --
			-- the yard, the circle, the porch, the spawn, the lodge -- is north of it.
			for _, withModels in ipairs({ true, false }) do
				local templates = if withModels then fakeTemplates() else nil
				local folder = Build.build(container, anchor, CFG, templates)
				local room = Build.roomFor(anchor, CFG)
				local yardSouth = anchor.Z + CFG.TRUCK.OFFSET.Z - 22
				local fences = folder:FindFirstChild("Fences")
				expect(fences).to.be.ok()
				local pieces = 0
				for _, descendant in ipairs((fences :: Instance):GetDescendants()) do
					if descendant:IsA("BasePart") then
						pieces += 1
						local piece = descendant :: BasePart
						local north = piece.Position.Z + piece.Size.Z / 2
						expect(north <= yardSouth).to.equal(true)
						-- ...and, said the other way round, never in the room a player shops in.
						local insideX = math.abs(piece.Position.X - room.centre.X) < room.halfX
						local insideZ = math.abs(piece.Position.Z - room.centre.Z) < room.halfZ
						expect(insideX and insideZ).to.equal(false)
					end
				end
				expect(pieces > 0).to.equal(true)
				if templates then
					(templates :: Instance):Destroy()
				end
			end
		end)

		it("leaves every pad's SURFACE above the yard slab, and its underside below the shelf", function()
			-- TASK 177 ROUND 1 BURIED THE CIRCLE. `road` lays its slabs on the shelf and the yard
			-- covers the whole row of bays, so a ring lifted 0.08 studs off the SHELF sat 0.42 studs
			-- inside an opaque slab: a sign reading "STAND HERE TO HUNT" with nothing to stand in.
			-- Task 182 SINKS the pad instead -- its top above every slab, its bottom below the
			-- terrain -- so neither failure is reachable, and this measures both ends.
			local folder = Build.build(container, anchor, CFG, fakeTemplates())
			local yard = folder:FindFirstChild("Yard", true) :: BasePart
			expect(yard).to.be.ok()
			local surface = yard.Position.Y + yard.Size.Y / 2
			local shelf = anchor.Y
			for index = 1, CFG.TRUCK.COUNT do
				local deck = folder:FindFirstChild(Data.padPartName(index) :: string, true) :: BasePart
				expect(deck).to.be.ok()
				local top = deck.Position.Y + deck.Size.Y / 2
				expect(top >= surface).to.equal(true)
				-- NOTHING FLOATS: the underside is under the shelf, so there is no visible edge.
				expect(deck.Position.Y - deck.Size.Y / 2 < shelf).to.equal(true)
				-- AND THE GLOWING RIM STANDS ON THAT SURFACE rather than inside it, which is the
				-- same mistake one layer up.
				local rim = deck.Parent :: Instance
				local bars = 0
				for _, child in ipairs(rim:GetChildren()) do
					if string.sub(child.Name, 1, 3) == "Rim" then
						bars += 1
						local piece = child :: BasePart
						expect(piece.Position.Y - piece.Size.Y / 2 >= top - 1e-4).to.equal(true)
						expect(piece.Material).to.equal(Enum.Material.Neon)
					end
				end
				expect(bars).to.equal(4)
			end
		end)
	end)

	describe("where he stands when he arrives", function()
		local anchor = Vector3.new(0, 100, 0)

		it("can never put a player off the lobby's own field, however high the index climbs", function()
			-- REVIEW ROUND 1, FINDING 3, AND IT IS THE CASE THAT FAILS ON THE OLD CODE. The caller's
			-- index is a counter that only ever goes up -- one per player who has ever joined -- and
			-- unwrapped it is `floor((index + 1) / 2) * SPREAD_STUDS` studs off the middle with no
			-- bound at all: index 37 is 114 studs, outside `FIELD.SPAN_STUDS`'s half-span of 110. The
			-- man then stands exactly where `world.place` put him, `Join.insideField` answers FALSE,
			-- `Join.needsReturn` answers true, and the lobby re-places him at the same off-shelf point
			-- every `RETURN_COOLDOWN_SECONDS` for ever.
			-- THE BOUND IS THE PORCH HE LANDS ON, not the lodge behind it (task 187): the deck is
			-- the footprint less `PORCH.INSET_STUDS` either side, and a slot outside that is a man
			-- standing on the corner of his own steps.
			local half = CFG.LODGE.SIZE.X / 2 - CFG.LODGE.PORCH.INSET_STUDS
			for index = 0, 200 do
				local at = Lobby.spawnCFrame(anchor, index, CFG).Position
				-- Inside the field, which is the rule that closes the respawn loop...
				expect(Join.insideField(at, anchor, CFG)).to.equal(true)
				-- ...and inside the lodge's own front, which is the porch the design names.
				expect(math.abs(at.X - (anchor.X + CFG.SPAWN.OFFSET.X)) < half).to.equal(true)
			end
			-- The slots WRAP rather than widen: index 0 and index SLOTS are the same place.
			local first = Lobby.spawnCFrame(anchor, 0, CFG).Position
			local wrapped = Lobby.spawnCFrame(anchor, CFG.SPAWN.SLOTS, CFG).Position
			expect((first - wrapped).Magnitude < 1e-4).to.equal(true)
		end)

		it("spreads two players more than a body apart, and faces them north", function()
			local first = Lobby.spawnCFrame(anchor, 0, CFG)
			local second = Lobby.spawnCFrame(anchor, 1, CFG)
			expect((first.Position - second.Position).Magnitude >= 4).to.equal(true)
			-- +Z: he looks at the lodge with the forest behind its roof, and the truck is to his
			-- right. Karen's *"house is in fields next to forrest"* read as a camera angle.
			expect(first.LookVector.Z > 0.99).to.equal(true)
			-- Centre-out, so a solo player gets the middle of the porch.
			expect(math.abs(first.Position.X - (anchor.X + CFG.SPAWN.OFFSET.X)) < 1e-4).to.equal(true)
		end)
	end)

	-- ---------------------------------------------------------------- the shopkeeper (task 181)
	--
	-- KAREN, 2026-10-14: *"in lobby has to be a person bot who you need to click E to get access to
	-- shop"*. Since this task took task 178's auto-open away, the prompt on this body is THE ONLY
	-- WAY INTO THE SHOP -- so "is there a man there, and has he got a prompt on him" is the one
	-- assertion in this file whose missing answer makes the shop unopenable.
	describe("the shopkeeper behind the counter", function()
		local container, folder
		local seen: { model: Model?, team: string?, look: any } = { model = nil, team = nil, look = nil }

		beforeEach(function()
			seen = { model = nil, team = nil, look = nil }
			container = Instance.new("Folder")
			container.Name = "LobbyKeeperSpecWorld"
			container.Parent = Workspace
			local made = Build.build(container, Vector3.new(0, 100, 0), CFG, nil, {
				rig = fakeRig,
				dress = function(model: Model, team: string, _config, look): boolean
					seen.model = model
					seen.team = team
					seen.look = look
					return true
				end,
				dressConfig = { fake = true },
			})
			folder = made
		end)

		afterEach(function()
			container:Destroy()
		end)

		it("stands one man behind the till, and counts him", function()
			local body = folder:FindFirstChild(Data.KEEPER_NAME, true)
			expect(body).to.be.ok()
			expect((body :: Instance):IsA("Model")).to.equal(true)
			expect(Build.stats().keepers).to.equal(1)
			-- UNDER THE SHOP, with the counter and the sign: one place in the tree to look for the
			-- whole shop, which is what `Lobby.counterPart` and `Lobby.shopPrompt` rest on.
			local shop = folder:FindFirstChild("Shop", true)
			expect(shop).to.be.ok()
			expect((body :: Instance):IsDescendantOf(shop :: Instance)).to.equal(true)
			-- BEHIND the counter and not in it: further from the room by `BEHIND_STUDS`, and
			-- standing on the same floor.
			local counter = folder:FindFirstChild(Data.COUNTER_NAME, true) :: BasePart
			local root = (body :: Model).PrimaryPart :: BasePart
			expect(math.abs(root.Position.X - counter.Position.X) < 1e-3).to.equal(true)
			local behind = root.Position.Z - counter.Position.Z
			expect(math.abs(behind - CFG.LODGE.KEEPER.BEHIND_STUDS) < 1e-3).to.equal(true)
			expect(root.Position.Y > counter.Position.Y).to.equal(true)
		end)

		it("cannot be pushed, cannot be walked into, and cannot stop a pellet", function()
			local body = folder:FindFirstChild(Data.KEEPER_NAME, true) :: Model
			local root = body.PrimaryPart :: BasePart
			-- THE ROOT IS ANCHORED AND THE LIMBS ARE NOT: `Bots.Rig.place(.., anchored = true)`'s
			-- arrangement. The anchor is what stops anything nudging him off his spot; the limbs
			-- stay on their joints so the idle clip can move them.
			expect(root.Anchored).to.equal(true)
			local parts = 0
			for _, descendant in ipairs(body:GetDescendants()) do
				if descendant:IsA("BasePart") then
					parts += 1
					expect(descendant.CanCollide).to.equal(false)
					-- `CanQuery = false` IS LOAD-BEARING and is this file's own rule everywhere else
					-- in the lobby: a body that stops a pellet changes what the shot hit.
					expect(descendant.CanQuery).to.equal(false)
					expect(descendant.CanTouch).to.equal(false)
					if descendant ~= root then
						expect(descendant.Anchored).to.equal(false)
					end
				end
			end
			expect(parts >= 4).to.equal(true)
		end)

		it("carries the prompt, with Karen's key, 8 studs and line of sight", function()
			local prompt = folder:FindFirstChild(Data.PROMPT_NAME, true)
			expect(prompt).to.be.ok()
			expect((prompt :: Instance):IsA("ProximityPrompt")).to.equal(true)
			local p = prompt :: ProximityPrompt
			local want = CFG.LODGE.KEEPER.PROMPT
			expect(p.KeyboardKeyCode).to.equal(want.KEYBOARD_KEY)
			expect(p.KeyboardKeyCode).to.equal(Enum.KeyCode.E) -- Karen's word, written twice on purpose
			expect(p.GamepadKeyCode).to.equal(want.GAMEPAD_KEY)
			expect(p.MaxActivationDistance).to.equal(want.MAX_DISTANCE)
			expect(p.MaxActivationDistance).to.equal(8)
			expect(p.HoldDuration).to.equal(0) -- a tap, not a hold
			expect(p.RequiresLineOfSight).to.equal(true)
			expect(p.ActionText).to.equal("Shop")
			expect(p.ObjectText).to.equal("Press E")
			expect(p.Enabled).to.equal(true)
			-- ON AN ATTACHMENT AT HEAD HEIGHT, AND THAT IS GEOMETRY: the counter is 3.5 studs tall
			-- and queryable, so a sight line to a root 3 studs up is stopped by the till and the
			-- prompt never appears for the one person standing where he is meant to stand.
			local at = p.Parent
			expect(at).to.be.ok()
			expect((at :: Instance):IsA("Attachment")).to.equal(true)
			-- A TOLERANCE AND NOT AN EQUALITY: `Attachment.Position` is three float32s, so 2.2 comes
			-- back out of the engine as 2.200000047683716 (measured, this spec's first run).
			local lift = (at :: Attachment).Position.Y
			expect(math.abs(lift - CFG.LODGE.KEEPER.PROMPT_HEIGHT) < 1e-5).to.equal(true)
			local body = folder:FindFirstChild(Data.KEEPER_NAME, true) :: Model
			local root = body.PrimaryPart :: BasePart
			local promptY = root.Position.Y + (at :: Attachment).Position.Y
			-- The floor is y = 100 here (the anchor's own), so the till's top is 100 + 3.5.
			expect(promptY > 100 + CFG.LODGE.COUNTER.Y).to.equal(true)
		end)

		it("is dressed by the outfit owner and by nothing else", function()
			-- ONE DRESSING PATH IN THIS REPOSITORY: `Build` hands a MODEL and a TEAM to the seam the
			-- composition root filled with `Match.Body.dress`, and learns nothing about outfits.
			expect(seen.model).to.be.ok()
			expect(seen.team).to.equal(CFG.LODGE.KEEPER.TEAM)
			expect(seen.look.hatColor).to.equal(CFG.LODGE.KEEPER.HAT_COLOR)
			expect(Build.stats().keeperDressed).to.equal(1)
		end)

		-- ...AND THE TEAM IS A WORD THAT OWNER ACTUALLY KNOWS. Round 1 shipped `"Hunter"`, which
		-- matches no row in `Body.OUTFITS` (`Shooters` / `Drivers`), so `Body.dress` returned early
		-- at *"nothing to wear"* and the keeper stood at the counter in default grey. The assertion
		-- above could not see it: it compared the config with itself.
		it("hands over a team the outfit owner has an outfit for", function()
			local Body = Match.Body
			expect(Body.outfitFor(CFG.LODGE.KEEPER.TEAM, Match.CONFIG)).to.be.ok()
			expect(Body.baseFor(CFG.LODGE.KEEPER.TEAM, Match.CONFIG)).to.be.ok()
			-- The repo's own translator agrees: a lodge keeper is a hunter, in the drive's words.
			expect(CFG.LODGE.KEEPER.TEAM).to.equal(Body.ROLE_WORDS.hunter)
		end)

		-- `keeperDressed` MEANS THE OUTFIT OWNER SAID YES, not "the call did not throw" (review
		-- round 1, finding 2). It said `dressed=true` on the console over an undressed man.
		it("counts him as dressed only when the outfit owner says so", function()
			local bare = Instance.new("Folder")
			bare.Name = "LobbyUndressedSpecWorld"
			bare.Parent = Workspace
			Build.build(bare, Vector3.new(0, 100, 0), CFG, nil, {
				rig = fakeRig,
				dress = function(): boolean
					return false -- "there was nothing I could put on him"
				end,
			})
			expect(Build.stats().keepers).to.equal(1)
			expect(Build.stats().keeperDressed).to.equal(0)
			bare:Destroy()
		end)

		it("builds the lodge anyway when no body comes back", function()
			-- A SPEC THAT HAS NOT ASKED FOR A BODY DOES NOT GET ONE, which is what keeps the avatar
			-- service out of this harness -- and a source that answers nil is a lodge with nobody in
			-- it, never a lobby that failed to build.
			local bare = Instance.new("Folder")
			bare.Name = "LobbyNoKeeperSpecWorld"
			bare.Parent = Workspace
			local made = Build.build(bare, Vector3.new(0, 100, 0), CFG)
			expect(made:FindFirstChild(Data.KEEPER_NAME, true)).to.equal(nil)
			expect(made:FindFirstChild(Data.COUNTER_NAME, true)).to.be.ok()
			expect(Build.stats().keepers).to.equal(0)
			local nilled = Build.build(bare, Vector3.new(0, 100, 0), CFG, nil, {
				rig = function(): Model?
					return nil
				end,
			})
			expect(nilled:FindFirstChild(Data.KEEPER_NAME, true)).to.equal(nil)
			expect(Build.stats().keepers).to.equal(0)
			bare:Destroy()
		end)

		-- THE FLAG, READ AT THE ROOT AND PASSED INWARD, decides one thing here: whether the prompt is
		-- live. With `SHOP` off the panel is dead, and a "Press E" over a man who answers nothing is
		-- worse than no prompt.
		it("hangs a DEAD prompt on him when the shop is not in this build", function()
			local off = Instance.new("Folder")
			off.Name = "LobbyShopOffSpecWorld"
			off.Parent = Workspace
			local made = Build.build(off, Vector3.new(0, 100, 0), CFG, nil, { rig = fakeRig, shopOn = false })
			local prompt = made:FindFirstChild(Data.PROMPT_NAME, true) :: ProximityPrompt
			expect(prompt).to.be.ok()
			expect(prompt.Enabled).to.equal(false)
			-- ...and the MAN is still there. He is scenery as well as a door, and a lodge that
			-- empties itself when a flag goes off is a second thing for Karen to notice.
			expect(made:FindFirstChild(Data.KEEPER_NAME, true)).to.be.ok()
			off:Destroy()
		end)

		it("has a face, and a head that is not solid black", function()
			-- KAREN, 2026-10-14: *"person inside broken"*, and the probe said why: RGB 0,0,0 and no
			-- features. `Match.Body.paint` deliberately never writes `HeadColor3` -- *"the head is
			-- the player's own"* (design M5) -- which is right for a player and leaves a man built
			-- from an EMPTY `HumanoidDescription` with the head that description ships. He is not a
			-- player, so the LODGE gives him one, and it writes EVERY `BodyColors` on him for the
			-- reason `Body.paint` writes every one of them.
			local body = Build.keeper() :: Model
			expect(body).to.be.ok()
			local head = body:FindFirstChild("Head") :: BasePart
			expect(head).to.be.ok()
			expect(head.Color).to.equal(CFG.LODGE.KEEPER.SKIN_COLOR)
			local painted = 0
			for _, child in ipairs(body:GetChildren()) do
				if child:IsA("BodyColors") then
					painted += 1
					expect((child :: BodyColors).HeadColor3).to.equal(CFG.LODGE.KEEPER.SKIN_COLOR)
				end
			end
			expect(painted > 0).to.equal(true)
			local look = head:FindFirstChildOfClass("Decal")
			expect(look).to.be.ok()
			expect((look :: Decal).Texture).to.equal(CFG.LODGE.KEEPER.FACE_TEXTURE)
			-- AN ENGINE ASSET, NOT AN UPLOAD AND NOT A FETCH: `rbxasset://` is a file that ships
			-- with Studio, which is the whole reason this is allowed to be a texture at all.
			expect(string.sub((look :: Decal).Texture, 1, 11)).to.equal("rbxasset://")
		end)

		it("holds no script anywhere in his body", function()
			local body = folder:FindFirstChild(Data.KEEPER_NAME, true) :: Model
			for _, descendant in ipairs(body:GetDescendants()) do
				expect(descendant:IsA("LuaSourceContainer")).to.equal(false)
			end
		end)

		-- THE HEAD TURN, AND THE EPSILON IS THE POINT. The owner decides who he looks at on the scan
		-- it already runs; this writes it -- and a write per scan for a man standing still would be
		-- the bug `Lobby.stats().keeperTurns` exists to show.
		it("turns to the nearest man, and writes nothing when he has not moved", function()
			local body = folder:FindFirstChild(Data.KEEPER_NAME, true) :: Model
			local here = (body.PrimaryPart :: BasePart).Position
			-- Somebody standing well off to one side: that is a turn.
			local side = here + Vector3.new(10, 0, -4)
			expect(Build.faceKeeper(side, CFG)).to.equal(true)
			expect((body.PrimaryPart :: BasePart).CFrame.LookVector.X > 0.5).to.equal(true)
			-- ...and asking again for the same man writes nothing.
			expect(Build.faceKeeper(side, CFG)).to.equal(false)
			-- A man beyond `FACE_STUDS` is not a man he turns to: he goes back to facing the room.
			local far = here + Vector3.new(CFG.LODGE.KEEPER.FACE_STUDS + 20, 0, 0)
			expect(Build.faceKeeper(far, CFG)).to.equal(true)
			expect((body.PrimaryPart :: BasePart).CFrame.LookVector.Z < -0.99).to.equal(true)
			expect(Build.faceKeeper(nil, CFG)).to.equal(false)
		end)

		-- THE CLIENT'S OWN READER, against a lobby built where it actually looks. It is the only
		-- route the panel has to the prompt, so a renamed part or a prompt on the wrong instance is
		-- a shop nobody can open -- and `Workspace.Lobby` is where the live server builds it.
		it("is found by `Lobby.shopPrompt`, the one reader the client has", function()
			local live = Build.build(Workspace, Vector3.new(0, 100, 0), CFG, nil, { rig = fakeRig })
			local prompt = Data.shopPrompt()
			expect(prompt).to.be.ok()
			expect((prompt :: Instance):IsDescendantOf(live)).to.equal(true)
			live:Destroy()
			-- AND THE CACHE DIES WITH THE INSTANCE (`Lobby.counterPart`'s own rule): a stale prompt
			-- would be a panel listening to a lodge that is not there any more.
			expect(Data.shopPrompt()).to.equal(nil)
		end)
	end)

	describe("the countdown the client reads", function()
		it("is nil in, nil out, and floors at zero", function()
			expect(Data.secondsLeft(nil, 100)).to.equal(nil)
			expect(Data.secondsLeft(105, 100)).to.equal(5)
			-- A past deadline is "now", never a negative number counting the wrong way.
			expect(Data.secondsLeft(90, 100)).to.equal(0)
		end)
	end)
end
