-- match_place.spec: THE ONE PLACEMENT RULE (task 192) -- a target's Y is the ground measured at that
-- target's own x, z, plus a clearance -- and the floor net under it.
--
-- KAREN, 2026-10-14: *"when drive ends I am underground ... when next round is started respawn in
-- under terrain and I dead all a time"*. Three defects were measured in the live place and all three
-- were the same mistake: a Y that was not measured at the point it was used for
-- (docs/research/2026-10-15-one-placement-rule.md section 2).
--
-- IT IS DRIVEN BY AN INJECTED GROUND READER AND A FAKE PLAYERS SERVICE, so every case here is
-- arithmetic with hand-written numbers: no drive, no terrain, no clock, and no raycast. `Body` is
-- `Match.Body`, a singleton every spec shares, so each case sets its own reader and the last one
-- puts it back -- the discipline `Match.start`/`Match.stop` already follow for `world.groundAt`.
--
-- ROUND 2 IS WHERE THE READER STARTS FROM (Reviewer round 1, finding 1). Round 1 asked "where is
-- the ground" with a ray from 300-600 studs UP, so the first solid thing OVERHEAD answered -- the
-- lodge's roof for a man at the shop counter, a canopy for a beater in the wood -- and the net
-- pivoted him out of the building four times a second. The reader `roofedBuilding` below is that
-- place written as arithmetic: it answers the ROOF when it is asked from the sky and the FLOOR when
-- it is asked from just above a body, which is exactly what the live geometry does.
--
-- WHAT THIS SPEC CANNOT ASSERT, stated rather than left to be assumed:
--   * `lastGood` (*"put him back where he was last standing"*) is WRITTEN only when
--     `Humanoid.FloorMaterial` says the engine has him standing on something, and that property
--     cannot be set from Luau. A fake character in the air reports `Air`, so these cases exercise
--     the OTHER branch -- back onto the ground over his own x and z -- and assert that nothing was
--     remembered. The remembered branch is proved by the live run's own console line
--     (`[place] RESCUED <name>: ... put back at (...)`), where the place it names is the stand he
--     had been standing on.
--   * the SECOND WRITER this task removed (`ForestTest.boundary` dragging a gathered player off his
--     ring slot while keeping the ring's Y) is one guard in a composition root
--     (`src/server/ForestTestBoot.server.luau`), which has no spec. It is proved by the live log:
--     the player stays at the slot the scene chose for the whole scoring phase.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/drive.md (sections 5.1, 5.3)
-- Note:   docs/research/2026-10-15-one-placement-rule.md
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Match = require(ServerScriptService:WaitForChild("Match"))
local Body = Match.Body
local Scene = Match.Scene
local TestKit = require(game:GetService("ReplicatedStorage"):WaitForChild("TestKit"))

-- THE HILLSIDE, AS A FUNCTION. The `edge` layout's six stands measured 147.9, 148.0, 171.5, 191.6,
-- 223.4 and 228.2 over 750 studs of x -- about 0.11 studs of climb per stud east. This is that
-- slope, exactly: a reader whose answer DEPENDS on where it is asked, which is the whole of what the
-- defect could not see.
--
-- IT IS ANCHORED AT A POINT, so `base` is the ground AT `anchorX` and every error this file prints
-- is the error over the DISTANCE in the case, not over the distance from the world origin. A note
-- reading "205 studs" about a ring 14 studs across is a true number about the wrong thing, which is
-- the class of mistake this whole task is about.
local function hillside(base: number, anchorX: number)
	return function(x: number, _z: number): number?
		return base + (x - anchorX) * 0.11
	end
end

-- THE LODGE, AS A READER. Karen's lodge stands on the shelf and its roof is 10-18 studs over it
-- (`Lobby.CONFIG.LODGE.SIZE` 40 x 10 x 28 with `RIDGE_STUDS` 18), and the roof parts are in no
-- excluded folder -- so a ray from the sky stops on the ROOF and a ray from just above a man
-- standing inside stops on the FLOOR. This answers both, by where it is asked from, which is the
-- whole of finding 1.
--
-- It is the canopy case too: a beater under the `Session` trees is a man with something solid
-- overhead and the ground under his feet, which is the same two answers.
local FLOOR_Y, ROOF_Y = 150, 167
local function roofedBuilding(_x: number, _z: number, fromY: number?): number?
	if fromY == nil or (fromY :: number) > ROOF_Y then
		return ROOF_Y -- asked from the sky: the first solid thing down is the roof
	end
	return FLOOR_Y -- asked from inside the room: the floor
end

local CLEARANCE = Match.CONFIG.STAND_HEIGHT_STUDS

return function()
	describe("Body.onGround: a target's Y is the ground under it", function()
		afterEach(function()
			Body.setGroundReader(nil)
		end)

		it("puts the root the clearance above the measured ground, and moves nothing else", function()
			Body.setGroundReader(function()
				return 100
			end)
			-- A frame with a rotation AND a wrong Y, which is every real case: the caller knows
			-- where and which way, and only the Y is the ground's business.
			local asked = CFrame.lookAt(Vector3.new(30, 500, -40), Vector3.new(30, 500, 0))
			local put, ground = Body.onGround(asked, CLEARANCE)
			expect(put).to.be.ok()
			expect(ground).to.equal(100)
			expect(math.abs((put :: CFrame).Position.Y - (100 + CLEARANCE)) < 1e-4).to.equal(true)
			expect(math.abs((put :: CFrame).Position.X - 30) < 1e-4).to.equal(true)
			expect(math.abs((put :: CFrame).Position.Z - -40) < 1e-4).to.equal(true)
			-- THE ROTATION IS THE CALLER'S: `LookVector` is identical, not merely close.
			expect(((put :: CFrame).LookVector - asked.LookVector).Magnitude < 1e-5).to.equal(true)
		end)

		it("asks at the TARGET's own x and z, which is the defect", function()
			-- The gathering carried the MIDDLE post's ground 24 studs sideways and then laid a
			-- 14-stud ring at that one Y. Over the hillside above, two points 138 studs apart differ
			-- by 15.2 studs -- so a rule that measures per point and a rule that does not cannot
			-- agree, and this is the assertion that says which one is in the code.
			Body.setGroundReader(hillside(171, 3405))
			local _, near = Body.onGround(CFrame.new(3405, 171, -3000), CLEARANCE)
			local _, far = Body.onGround(CFrame.new(3543, 171, -3001), CLEARANCE)
			expect(near).to.be.ok()
			expect(far).to.be.ok()
			expect(math.abs(((far :: number) - (near :: number)) - 138 * 0.11) < 1e-6).to.equal(true)
		end)

		it("hands the caller's frame back, unchanged and counted, when the ground cannot be read", function()
			local before = Body.snapMisses()
			Body.setGroundReader(function()
				return nil
			end)
			local asked = CFrame.new(10, 777, 20)
			local put, ground = Body.onGround(asked, CLEARANCE)
			expect(ground).to.equal(nil)
			-- UNCHANGED, not dropped to zero and not refused: a placement that cannot measure must
			-- still happen, and the miss is a number instead of a feeling.
			expect(math.abs((put :: CFrame).Position.Y - 777) < 1e-6).to.equal(true)
			expect(Body.snapMisses() > before).to.equal(true)
		end)

		it("survives a world reader that throws, and counts that as a miss too", function()
			local before = Body.snapMisses()
			Body.setGroundReader(function(): number?
				error("this world's reader is broken")
			end)
			local put = Body.onGround(CFrame.new(1, 2, 3), CLEARANCE)
			expect(math.abs((put :: CFrame).Position.Y - 2) < 1e-6).to.equal(true)
			expect(Body.snapMisses() > before).to.equal(true)
		end)

		it("answers nil for nil, and takes the clearance from the config", function()
			expect(Body.onGround(nil, CLEARANCE)).to.equal(nil)
			expect(Body.clearanceFor(Match.CONFIG)).to.equal(Match.CONFIG.STAND_HEIGHT_STUDS)
			expect(Body.clearanceFor({ STAND_HEIGHT_STUDS = 9 })).to.equal(9)
			-- A caller with no config at all still gets a clearance, and it is this module's own.
			expect(Body.clearanceFor(nil) > 0).to.equal(true)
		end)
	end)

	describe("the results scene's ring, on sloping ground", function()
		afterEach(function()
			Body.setGroundReader(nil)
		end)

		it("ends with every slot on its own ground, where one flat Y was 15 studs out", function()
			local slope = hillside(171, 3405)
			Body.setGroundReader(slope)
			-- The ring exactly as `Match.applyScene` builds it: one spot, one flat Y, eight people.
			local spot = Vector3.new(3405, 171, -3024)
			local ring = Scene.ringLayout(spot, 8, Match.CONFIG, 0)
			expect(#ring).to.equal(8)
			local worstFlat, worstSnapped = 0, 0
			for _, slot in ipairs(ring) do
				local at = slot.Position
				local ground = slope(at.X, at.Z) :: number
				-- WHAT THE OLD RULE LEFT: the flat ring's Y against the ground under that slot.
				worstFlat = math.max(worstFlat, math.abs(at.Y - (ground + CLEARANCE)))
				local put = Body.onGround(slot, CLEARANCE) :: CFrame
				worstSnapped = math.max(worstSnapped, math.abs(put.Position.Y - (ground + CLEARANCE)))
			end
			TestKit.note(
				string.format(
					"match_place: ring of 8 on a 0.11 slope -- worst error flat %.2f studs, snapped %.4f studs",
					worstFlat,
					worstSnapped
				)
			)
			-- The ring's own radius is `RING_RADIUS_STUDS` (14), so the slope alone puts a slot
			-- 1.5 studs out even before the 24-stud carry and the 138-stud drag that were measured
			-- live. Snapped, every slot is exact.
			expect(worstFlat > 1).to.equal(true)
			expect(worstFlat < 2).to.equal(true) -- 14 * 0.11, and nothing bigger: the ring is the case
			expect(worstSnapped < 1e-4).to.equal(true)
		end)

		it("lays the animals and the torches on their own ground when it is handed a reader", function()
			local reader = hillside(50, 200)
			local spot = Vector3.new(200, 50, -100)
			local kills = { { kind = "male" }, { kind = "female" }, { kind = "cub" } }
			Scene.build(spot, Vector3.zAxis, kills, Match.CONFIG, nil, reader)
			local folder = Scene.folder()
			expect(folder).to.be.ok()
			local worst = 0
			for index = 1, #kills do
				local animal = (folder :: Folder):FindFirstChild(string.format("Animal%d", index)) :: BasePart
				expect(animal).to.be.ok()
				-- The box's BOTTOM is the ground: `Scene.build` lifts it by half its own height.
				local bottom = animal.Position.Y - animal.Size.Y / 2
				worst = math.max(worst, math.abs(bottom - (reader(animal.Position.X, animal.Position.Z) :: number)))
			end
			for index = 1, 4 do
				local post = (folder :: Folder):FindFirstChild(
						string.format("%s%d", Scene.LIGHT_PREFIX, index)
					) :: BasePart
				expect(post).to.be.ok()
				local foot = post.Position.Y - post.Size.Y / 2
				worst = math.max(worst, math.abs(foot - (reader(post.Position.X, post.Position.Z) :: number)))
			end
			TestKit.note(string.format("match_place: scene on a slope -- worst foot error %.4f studs", worst))
			expect(worst < 1e-3).to.equal(true)

			-- NO READER IS THE SCENE THIS REPO ALREADY BUILT: everything on the spot's own Y, which
			-- is what every case in match_scene.spec asserts and must stay true.
			Scene.build(spot, Vector3.zAxis, kills, Match.CONFIG, nil)
			local flat = (Scene.folder() :: Folder):FindFirstChild("Animal1") :: BasePart
			expect(math.abs((flat.Position.Y - flat.Size.Y / 2) - spot.Y) < 1e-3).to.equal(true)
			Scene.clear()
		end)
	end)

	describe("indoors and under a canopy: nothing OVERHEAD is ever the ground", function()
		afterEach(function()
			Body.setGroundReader(nil)
		end)

		it("asks from just above the point, so the floor wins over the roof", function()
			Body.setGroundReader(roofedBuilding)
			-- A man standing on the lodge floor: his root is CLEARANCE above it.
			local standing = FLOOR_Y + CLEARANCE
			expect(Body.groundUnder(0, 0, standing)).to.equal(FLOOR_Y)
			-- ...and the column question -- no body, no `fromY` -- still gets the far cast, which is
			-- what the scene's layout points and the DEV place have always used.
			expect(Body.groundUnder(0, 0)).to.equal(ROOF_Y)
		end)

		it("does not call a man standing indoors 14 studs underground", function()
			Body.setGroundReader(roofedBuilding)
			local standing = Vector3.new(0, FLOOR_Y + CLEARANCE, 0)
			-- ROUND 1 MEASURED `ROOF_Y - standing.Y` here -- 13.5 studs "under the ground" -- and
			-- `MAX_BELOW_GROUND_STUDS` is 5, so the wall lifted him onto the roof.
			local below = Body.underGroundBy(standing)
			expect(below).to.be.ok()
			expect((below :: number) < 0).to.equal(true)
			local at, moved = Body.liftOntoGround(standing, CLEARANCE)
			expect(moved).to.equal(false)
			expect(math.abs(at.Y - standing.Y) < 1e-6).to.equal(true)
		end)

		it("places a spawn target inside the building on the floor, not on the roof", function()
			Body.setGroundReader(roofedBuilding)
			-- The lobby's return asks for a Y at the floor itself (`SPAWN.OFFSET.Y` is 0).
			local put, ground = Body.onGround(CFrame.new(10, FLOOR_Y, 20), CLEARANCE)
			expect(ground).to.equal(FLOOR_Y)
			expect(math.abs((put :: CFrame).Position.Y - (FLOOR_Y + CLEARANCE)) < 1e-4).to.equal(true)
		end)
	end)

	describe("Body.liftOntoGround: one-sided, for a caller that writes a position itself", function()
		afterEach(function()
			Body.setGroundReader(nil)
		end)

		it("lifts a point that is inside the hill, and says it moved it", function()
			Body.setGroundReader(function()
				return 190
			end)
			-- THE MEASURED CASE: `ForestTest.boundary` clamped a respawned hunter onto his stand's
			-- circle while keeping the SPAWN's Y, which put him at (3549, 143.7, -2990) with the
			-- terrain at 191.5 -- 47.8 studs inside the hill, twice, to the stud.
			local at, moved = Body.liftOntoGround(Vector3.new(3549, 143.7, -2990), CLEARANCE)
			expect(moved).to.equal(true)
			expect(math.abs(at.Y - (190 + CLEARANCE)) < 1e-4).to.equal(true)
			expect(math.abs(at.X - 3549) < 1e-6).to.equal(true)
			expect(math.abs(at.Z - -2990) < 1e-6).to.equal(true)
		end)

		it("never touches a point that is on the ground or above it -- a jump is not a burial", function()
			Body.setGroundReader(function()
				return 190
			end)
			for _, y in ipairs({ 190 + CLEARANCE, 190, 240, 186 }) do
				local at, moved = Body.liftOntoGround(Vector3.new(0, y, 0), CLEARANCE)
				expect(moved).to.equal(false)
				expect(math.abs(at.Y - y) < 1e-6).to.equal(true)
			end
		end)

		it("leaves a point alone when the ground cannot be measured", function()
			Body.setGroundReader(function()
				return nil
			end)
			local at, moved = Body.liftOntoGround(Vector3.new(0, -9000, 0), CLEARANCE)
			expect(moved).to.equal(false)
			expect(math.abs(at.Y - -9000) < 1e-6).to.equal(true)
		end)
	end)

	describe("Body.floorStep: the floor under the rule", function()
		local folder: Folder? = nil

		local function fakePlayer(name: string, userId: number, at: Vector3)
			local character = Instance.new("Model")
			character.Name = name
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Size = Vector3.new(2, 2, 1)
			root.Position = at
			root.Anchored = true
			root.Parent = character
			character.PrimaryPart = root
			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = character
			character.Parent = folder
			return { Name = name, UserId = userId, Character = character }, root
		end

		-- THE BURIED SEAM, AS TWO CONSTANTS. `Terrain:ReadVoxels` needs real terrain, so "is this body
		-- inside the hill" is a parameter here and an engine query in production -- the same split
		-- `service` and `floorY` already have.
		local function always(): boolean
			return true
		end
		local function never(): boolean
			return false
		end

		local function service(players: { any })
			return {
				GetPlayers = function()
					return players
				end,
			}
		end

		beforeEach(function()
			local made = Instance.new("Folder")
			made.Name = "Task192PlaceSpec"
			made.Parent = Workspace
			folder = made
			Body.setGroundReader(function()
				return 100
			end)
		end)

		afterEach(function()
			Body.setGroundReader(nil)
			if folder then
				(folder :: Folder):Destroy()
				folder = nil
			end
		end)

		it("leaves a character that is standing on the ground exactly where it is", function()
			local player, root = fakePlayer("OnTheGround", 192001, Vector3.new(0, 100 + CLEARANCE, 0))
			local before = root.Position
			expect(Body.floorStep(service({ player }), nil, never)).to.equal(0)
			expect((root.Position - before).Magnitude < 1e-6).to.equal(true)
		end)

		it("leaves a character ABOVE the ground alone -- a jump is not a fall", function()
			local player, root = fakePlayer("InTheAir", 192002, Vector3.new(0, 140, 0))
			expect(Body.floorStep(service({ player }), nil, never)).to.equal(0)
			expect(math.abs(root.Position.Y - 140) < 1e-6).to.equal(true)
		end)

		it("leaves a man STANDING UNDER A ROOF alone, however low the sky says the ground is", function()
			-- THE FAULT ROUND 1 SHIPPED (Reviewer, finding 1): the lodge and the shop counter. The
			-- reader answers the ROOF from the sky, the net read that as "the ground", and a man
			-- standing on the floor was 13.5 studs "under" it -- pivoted away four times a second.
			-- Nothing but the reader's starting height changed, and this case is 0 either way ONLY
			-- because the net no longer asks a depth at all.
			Body.setGroundReader(roofedBuilding)
			local player, root = fakePlayer("AtTheShopCounter", 192010, Vector3.new(0, FLOOR_Y + CLEARANCE, 0))
			local before = root.Position
			local rescues = Body.rescuedFromUnderGround()
			expect(Body.floorStep(service({ player }), nil, never)).to.equal(0)
			expect(Body.floorStep(service({ player }), nil, never)).to.equal(0)
			expect(Body.rescuedFromUnderGround()).to.equal(rescues)
			expect((root.Position - before).Magnitude < 1e-6).to.equal(true)
		end)

		it("leaves a beater UNDER A CANOPY alone, for the same reason", function()
			-- The 831 Studio-built `Session` trees: `ForestTest.terrainYAt`'s own header says the
			-- world's reader can stop on one of them. A beater walks 580 studs under that.
			Body.setGroundReader(roofedBuilding)
			local player, root = fakePlayer("InTheWood", 192011, Vector3.new(120, FLOOR_Y + CLEARANCE, -300))
			local before = root.Position
			expect(Body.floorStep(service({ player }), nil, never)).to.equal(0)
			expect((root.Position - before).Magnitude < 1e-6).to.equal(true)
		end)

		it("puts a character INSIDE SOLID TERRAIN back on the ground", function()
			-- 17.5 studs is the number MEASURED in the live place at the end of a drive on the
			-- `edge` layout. `buried` is the seam here because `Terrain:ReadVoxels` needs real
			-- terrain; the live run proves the engine half.
			local player, root = fakePlayer("UnderTheTerrain", 192003, Vector3.new(30, 100 - 17.5, -40))
			local before = Body.rescuedFromUnderGround()
			expect(Body.floorStep(service({ player }), nil, always)).to.equal(1)
			expect(Body.rescuedFromUnderGround()).to.equal(before + 1)
			-- BACK ON THE GROUND OVER HIS OWN X AND Z: this fake reports `FloorMaterial = Air`, so
			-- nothing was ever remembered for him (see this file's header).
			expect(math.abs(root.Position.Y - (100 + CLEARANCE)) < 1e-4).to.equal(true)
			expect(math.abs(root.Position.X - 30) < 1e-4).to.equal(true)
			expect(math.abs(root.Position.Z - -40) < 1e-4).to.equal(true)
			expect(Body.lastGoodPosition(192003)).to.equal(nil)
		end)

		it("catches a body on its way to being DESTROYED, and puts it back on the ground", function()
			-- The death Karen reported: the lobby's return put her root at the ground itself, the
			-- engine ejected the body downward, and it fell 149.2 -> -285.7 and was destroyed below
			-- `FallenPartsDestroyHeight`. Below the floor nothing is buried and nothing is standing,
			-- which is exactly why the floor is a SECOND test and not the same one.
			local player, root = fakePlayer("FallingOut", 192004, Vector3.new(0, -450, 0))
			-- The floor is a parameter so this case needs no world: -400 is this place's own
			-- `FallenPartsDestroyHeight + 100`. The reader is the beforeEach's 100.
			expect(Body.floorStep(service({ player }), -400, never)).to.equal(1)
			expect(math.abs(root.Position.Y - (100 + CLEARANCE)) < 1e-4).to.equal(true)
		end)

		it("counts nothing when there is nowhere to put him (a rescue of nobody is not a rescue)", function()
			-- Reviewer round 1, note 1: with no remembered place and no measurable ground the
			-- "rescue" pivoted the body to where it already was, counted it and printed a line --
			-- at 4 Hz, into the counter whose whole value is that it stays 0.
			Body.setGroundReader(function(): number?
				return nil
			end)
			local player, root = fakePlayer("NowhereToGo", 192012, Vector3.new(0, -450, 0))
			local before = Body.rescuedFromUnderGround()
			expect(Body.floorStep(service({ player }), -400, never)).to.equal(0)
			expect(Body.rescuedFromUnderGround()).to.equal(before)
			expect(math.abs(root.Position.Y - -450) < 1e-6).to.equal(true)
		end)

		it("walks every player it is given, and answers 0 for an empty server", function()
			local a = fakePlayer("A", 192005, Vector3.new(0, 100 - 30, 0))
			local b = fakePlayer("B", 192006, Vector3.new(50, 100 + CLEARANCE, 50))
			local c = fakePlayer("C", 192007, Vector3.new(-50, 100 - 9, -50))
			-- `a` and `c` are buried, `b` is not: the seam answers per POSITION, so one pass sorts
			-- three bodies by where each of them is.
			local buriedBelow = function(at: Vector3): boolean
				return at.Y < 100 - 5
			end
			expect(Body.floorStep(service({ a, b, c }), nil, buriedBelow)).to.equal(2)
			expect(Body.floorStep(service({}), nil, never)).to.equal(0)
			-- A player with no character is not a fault and is not a rescue.
			expect(Body.floorStep(service({ { Name = "Joining", UserId = 192008, Character = nil } }), nil, never)).to.equal(
				0
			)
		end)

		it("leaves a DEAD character alone: the net is for the living", function()
			-- MEASURED in the first proof run: a dead ragdoll slid ten studs down the `edge`
			-- layout's slope and clipped 47.8 studs into the terrain, and the net put a corpse back
			-- on its stand half a second before `LoadCharacter` destroyed it. `Health` is the whole
			-- test, so a spec can drive it.
			local player, root = fakePlayer("ARagdoll", 192009, Vector3.new(0, 100 - 40, 0));
			(player.Character :: Model):FindFirstChildOfClass("Humanoid").Health = 0
			local before = Body.rescuedFromUnderGround()
			expect(Body.floorStep(service({ player }), nil, always)).to.equal(0)
			expect(Body.rescuedFromUnderGround()).to.equal(before)
			expect(math.abs(root.Position.Y - (100 - 40)) < 1e-6).to.equal(true)
		end)

		-- THE "FORGETS HIM WHEN HE LEAVES" CASE IS GONE, and that is the honest move (Reviewer round
		-- 1, note 2, which was right). It asserted nil, called `Body.forget`, and asserted nil again
		-- -- and `lastGood` can never be populated from a spec, so it passed with the line it was
		-- supposed to cover deleted. `Body.forget` clearing `lastGood` is one line beside the two it
		-- already clears, and a case that cannot fail is worse than no case.
	end)
end
