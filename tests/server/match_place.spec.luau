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
-- WHAT THIS SPEC CANNOT ASSERT, stated rather than left to be assumed:
--   * `lastGood` (*"put him back where he was last standing"*) turns on `Humanoid.FloorMaterial`,
--     which is written by the engine and cannot be set from Luau. A fake character in the air
--     reports `Air`, so these cases exercise the OTHER branch -- back onto the ground over his own
--     x and z. The remembered-position branch is proved by the live run's own console line
--     (`[place] RESCUED <name>: ... put back at (...)`).
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
local function hillside(base: number)
	return function(x: number, _z: number): number?
		return base + x * 0.11
	end
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
			Body.setGroundReader(hillside(0))
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
			Body.setGroundReader(hillside(0))
			-- The ring exactly as `Match.applyScene` builds it: one spot, one flat Y, eight people.
			local spot = Vector3.new(3405, 171, -3024)
			local ring = Scene.ringLayout(spot, 8, Match.CONFIG, 0)
			expect(#ring).to.equal(8)
			local worstFlat, worstSnapped = 0, 0
			for _, slot in ipairs(ring) do
				local at = slot.Position
				local ground = (hillside(0))(at.X, at.Z) :: number
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
			expect(worstSnapped < 1e-4).to.equal(true)
		end)

		it("lays the animals and the torches on their own ground when it is handed a reader", function()
			local reader = hillside(0)
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
			expect(Body.floorStep(service({ player }))).to.equal(0)
			expect((root.Position - before).Magnitude < 1e-6).to.equal(true)
		end)

		it("leaves a character ABOVE the ground alone -- a jump is not a fall", function()
			local player, root = fakePlayer("InTheAir", 192002, Vector3.new(0, 140, 0))
			expect(Body.floorStep(service({ player }))).to.equal(0)
			expect(math.abs(root.Position.Y - 140) < 1e-6).to.equal(true)
		end)

		it("puts a character that is under the ground back on it", function()
			-- 17.5 studs is the number that was MEASURED in the live place at the end of a drive on
			-- the `edge` layout, so this case is that failure with the terrain replaced by a reader.
			local player, root = fakePlayer("UnderTheTerrain", 192003, Vector3.new(30, 100 - 17.5, -40))
			local before = Body.rescuedFromUnderGround()
			expect(Body.floorStep(service({ player }))).to.equal(1)
			expect(Body.rescuedFromUnderGround()).to.equal(before + 1)
			-- BACK ON THE GROUND OVER HIS OWN X AND Z: this fake reports `FloorMaterial = Air`, so
			-- nothing was ever remembered for him (see this file's header).
			expect(math.abs(root.Position.Y - (100 + CLEARANCE)) < 1e-4).to.equal(true)
			expect(math.abs(root.Position.X - 30) < 1e-4).to.equal(true)
			expect(math.abs(root.Position.Z - -40) < 1e-4).to.equal(true)
			expect(Body.worstBelowGroundStuds() >= 17.5).to.equal(true)
		end)

		it("catches a body on its way to being DESTROYED, with the ground gone", function()
			-- The death Karen reported: the lobby's return put her root at the ground itself, the
			-- engine ejected the body downward, and it fell 149.2 -> -285.7 and was destroyed below
			-- `FallenPartsDestroyHeight`. Below the floor there is no ground to measure, which is
			-- exactly why the floor is a SECOND test and not the same one.
			Body.setGroundReader(function(_x: number, _z: number): number?
				return nil
			end)
			local player, root = fakePlayer("FallingOut", 192004, Vector3.new(0, -450, 0))
			-- The floor is a parameter so this case needs no world: -400 is this place's own
			-- `FallenPartsDestroyHeight + 100`.
			expect(Body.floorStep(service({ player }), -400)).to.equal(1)
			-- With no ground under him the snap hands the frame back unchanged, so he is put at his
			-- last good position -- and there is none, so he stays where he was and the line says so.
			-- The POINT of this case is that the net FIRES: a silent fall is the death.
			expect(root).to.be.ok()
		end)

		it("walks every player it is given, and answers 0 for an empty server", function()
			local a = fakePlayer("A", 192005, Vector3.new(0, 100 - 30, 0))
			local b = fakePlayer("B", 192006, Vector3.new(50, 100 + CLEARANCE, 50))
			local c = fakePlayer("C", 192007, Vector3.new(-50, 100 - 9, -50))
			expect(Body.floorStep(service({ a, b, c }))).to.equal(2)
			expect(Body.floorStep(service({}))).to.equal(0)
			-- A player with no character is not a fault and is not a rescue.
			expect(Body.floorStep(service({ { Name = "Joining", UserId = 192008, Character = nil } }))).to.equal(0)
		end)

		it("leaves a DEAD character alone: the net is for the living", function()
			-- MEASURED in the first proof run: a dead ragdoll slid ten studs down the `edge`
			-- layout's slope and clipped 47.8 studs into the terrain, and the net put a corpse back
			-- on its stand half a second before `LoadCharacter` destroyed it. `Health` is the whole
			-- test, so a spec can drive it.
			local player, root = fakePlayer("ARagdoll", 192009, Vector3.new(0, 100 - 40, 0));
			(player.Character :: Model):FindFirstChildOfClass("Humanoid").Health = 0
			local before = Body.rescuedFromUnderGround()
			expect(Body.floorStep(service({ player }))).to.equal(0)
			expect(Body.rescuedFromUnderGround()).to.equal(before)
			expect(math.abs(root.Position.Y - (100 - 40)) < 1e-6).to.equal(true)
		end)

		it("forgets where a player was standing when he leaves", function()
			expect(Body.lastGoodPosition(192099)).to.equal(nil)
			Body.forget(192099)
			expect(Body.lastGoodPosition(192099)).to.equal(nil)
		end)
	end)
end
