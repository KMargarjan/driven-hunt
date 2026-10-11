-- forest_markers.spec: THE FOREST'S MARKER SET -- and, first, that it can say NO (task 157).
--
-- THE HARNESS RUNS IN THE DEV PLACE, and that is what makes the most important case here free: there
-- is no terrain under this world's coordinates (x ~ 3030, z ~ -2097) in DEV, so
-- `ForestTest.Markers.build` with its real readers measures nothing, refuses all nine stands, builds
-- NO part and answers `complete = false` with the reasons named. That is the guard against the audit
-- in `docs/PROJECT_CONTEXT.md` that *"certified a blank screen twice"*: a set that could only ever
-- say yes would be a drive standing on a world nobody checked. `forest_stand.spec`'s own header
-- already relies on the same absence of terrain.
--
-- EVERYTHING ELSE IS DRIVEN WITH INJECTED GROUND READERS, which is the "reachable by parameter"
-- rule applied to a raycast: `build(standX, ground, canopy)` takes both, so the nine stands, the
-- line, the beater pad, the tolerance and the refusal are all assertable with hand-written numbers
-- and no forest.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/forest-drive.md (sections 4.1, 13.1)
-- Note:   docs/research/2026-10-11-forest-drive.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Data = require(ReplicatedStorage:WaitForChild("ForestTest"))
local ForestTest = require(ServerScriptService:WaitForChild("ForestTest"))
local Match = require(ServerScriptService:WaitForChild("Match"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local Markers = ForestTest.Markers

-- A FLAT WORLD AT A KNOWN HEIGHT, for the cases that are about the arithmetic and not about terrain.
local FLAT_Y = 140
local function flat(_x: number, _z: number): number?
	return FLAT_Y
end
local function nothing(_x: number, _z: number): number?
	return nil
end

local function hasMissing(set, needle: string): boolean
	for _, reason in ipairs(set.missing) do
		if string.find(reason, needle, 1, true) then
			return true
		end
	end
	return false
end

local function partsInFolder(): number
	local folder = Markers.folder()
	if folder == nil then
		return 0
	end
	local n = 0
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

return function()
	describe("it can say no", function()
		it("refuses every stand where there is no ground, and builds nothing", function()
			Markers.clear()
			-- THE REAL READERS, in the DEV place: no terrain under the forest's coordinates.
			local set = Markers.build(Data.standX(Data.PICK.defaultIndex))
			expect(#set.posts).to.equal(0)
			expect(set.complete).to.equal(false)
			expect(hasMissing(set, "forest:stands")).to.equal(true)
			expect(hasMissing(set, string.format("0 of %d", Data.STAND_COUNT))).to.equal(true)
			expect(Markers.folder()).to.equal(nil) -- not one Instance created
			expect(Markers.stats().refused).to.equal(Data.STAND_COUNT)
			TestKit.note(string.format("forest-markers: %s", table.concat(set.missing, ", ")))
		end)

		it("is the shape Match consumes, so the Hud says WHY it is waiting", function()
			-- The drive stays in `Waiting` while `complete` is false, and `Phase.waitingFor` passes
			-- these strings to the snapshot the drive bar prints. No client change: the Hud already
			-- renders `waitingFor`.
			local set = Markers.build(0, nothing, nothing)
			local state = Match.Phase.initial(Match.CONFIG)
			state = Match.Phase.step(state, {
				kind = "markers",
				complete = set.complete,
				missing = set.missing,
				boarSpawns = set.boarSpawns,
			}, 0, Match.CONFIG)
			expect(state.phase).to.equal("Waiting")
			local reasons = Match.Phase.waitingFor(state, Match.CONFIG)
			expect(#reasons >= 1).to.equal(true)
		end)
	end)

	describe("the set it builds on real ground", function()
		it("puts one part per stand, on the road, sorted west to east", function()
			local set = Markers.build(Data.standX(5), flat, flat)
			expect(#set.posts).to.equal(Data.STAND_COUNT)
			local worst = 0
			for index, post in ipairs(set.posts) do
				local stand = Data.standPosition(index)
				worst = math.max(worst, math.abs(post.Position.X - stand.X), math.abs(post.Position.Z - stand.Z))
				expect(post.Position.Y).to.equal(FLAT_Y)
				expect(post.Anchored).to.equal(true)
				-- A MARKER MUST NOT STOP A PELLET: what the shot hit is what the weapon reports and
				-- `Penalty.judge` reads.
				expect(post.CanQuery).to.equal(false)
				expect(post.CanCollide).to.equal(false)
				expect(post.Transparency).to.equal(1)
				if index > 1 then
					expect(post.Position.X > set.posts[index - 1].Position.X).to.equal(true)
				end
			end
			expect(worst < 1).to.equal(true)
			TestKit.note(string.format("forest-markers: 9 stands within %.4f studs of the curve", worst))
		end)

		it("is complete with no boar spawns and no trees, and both are decisions", function()
			local set = Markers.build(Data.standX(5), flat, flat)
			expect(#set.boarSpawns).to.equal(0) -- the drive releases nothing here
			expect(#set.trees).to.equal(0) -- the forest tags no trunks; anchorFor falls back to posts
			expect(set.complete).to.equal(true)
			expect(#set.missing).to.equal(0)
			expect(set.spawnRadius).to.equal(Data.REST.spreadStuds)
		end)

		it("hands over ONE drive line, pointing at the drive side", function()
			local set = Markers.build(Data.standX(5), flat, flat)
			expect(set.lineParts).to.equal(1)
			expect(set.line).to.be.ok()
			local line = set.line :: any
			expect(line.normal).to.equal(Vector3.zAxis) -- +Z: north, where the beaters are
			expect(math.abs(line.position.Z - Data.CENTRE.Z) < 1e-3).to.equal(true)
			expect(math.abs(line.position.X - Data.CENTRE.X) < 1e-3).to.equal(true)
		end)

		it("puts a hunter on her stand at the height the DEV world uses", function()
			local set = Markers.build(Data.standX(5), flat, flat)
			-- Through `Body.placementFor`, which is the one rule in both worlds, and
			-- `standIndexFor(1)` -- the solo hunter's stand.
			local cframe = Match.Body.placementFor(set, "Shooters", ForestTest.standIndexFor(1), Match.CONFIG)
			expect(cframe).to.be.ok()
			local at = (cframe :: CFrame).Position
			local stand = Data.standPosition(Data.PICK.defaultIndex)
			expect(math.abs(at.X - stand.X) < 1e-3).to.equal(true)
			expect(math.abs(at.Y - (FLAT_Y + Markers.POST_SIZE.Y / 2 + Match.CONFIG.STAND_HEIGHT_STUDS)) < 1e-3).to.equal(
				true
			)
			-- Facing +Z: north, up the drive. (`ForestTest.DRIVE_BEARING_DEG` is 0.)
			expect((cframe :: CFrame).LookVector.Z > 0.99).to.equal(true)
		end)

		it("ties a punished hunter to the nearest stand, because there are no tagged trunks", function()
			local set = Markers.build(Data.standX(5), flat, flat)
			local stand = Data.standPosition(7)
			local anchor = Match.Body.anchorFor(set, Vector3.new(stand.X, FLAT_Y, stand.Z + 5))
			expect(anchor).to.be.ok()
			expect((anchor :: BasePart).Name).to.equal("Stand7")
		end)
	end)

	describe("the ground, asked twice", function()
		it("refuses a stand when the terrain and the canopy disagree by more than a stud", function()
			local function canopy(_x: number, _z: number): number?
				return FLAT_Y + Markers.GROUND_TOLERANCE_STUDS + 5 -- a ray that stopped on a branch
			end
			local set = Markers.build(Data.standX(5), flat, canopy)
			expect(#set.posts).to.equal(0)
			expect(set.complete).to.equal(false)
			expect(Markers.stats().refused).to.equal(Data.STAND_COUNT)
			expect(Markers.stats().lastMaxDelta > Markers.GROUND_TOLERANCE_STUDS).to.equal(true)
		end)

		it("accepts a disagreement inside the tolerance", function()
			local function canopy(_x: number, _z: number): number?
				return FLAT_Y + Markers.GROUND_TOLERANCE_STUDS / 2
			end
			local set = Markers.build(Data.standX(5), flat, canopy)
			expect(#set.posts).to.equal(Data.STAND_COUNT)
			expect(set.complete).to.equal(true)
		end)
	end)

	describe("the folder", function()
		it("is rebuilt and never grows, and `clear` leaves nothing behind", function()
			Markers.build(Data.standX(5), flat, flat)
			local first = partsInFolder()
			expect(first).to.equal(Data.STAND_COUNT + 1) -- nine stands plus the beater pad
			Markers.build(Data.standX(5), flat, flat)
			expect(partsInFolder()).to.equal(first)
			expect(#Workspace:GetChildren() > 0).to.equal(true)
			Markers.clear()
			expect(Markers.folder()).to.equal(nil)
		end)
	end)
end
