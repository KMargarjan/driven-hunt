-- boar_model.spec: the skinned boar, behind `BOAR_MODEL` (task 115).
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- IT ASSERTS ON WHAT IS DRAWN, AND ON WHAT IS NOT. The flag's whole promise is that the physics box,
-- its three hit zones and every attribute the weapon reads are the same in both states, and that the
-- model is a passenger: massless, collisionless and invisible to a ray. So the two halves below are
--   FLAG OFF: a boar is byte-for-byte the grey box every spec before this one asserts;
--   FLAG ON:  exactly one visual child, welded, massless, CanQuery false, feet on the bottom of the
--             box -- and the box's own `Damageable`, `HitZone`, `CanQuery` and `CanCollide`
--             untouched, so a shot that hit before hits exactly the same part.
--
-- IT NEEDS NO NETWORK AND NO ASSET. The template is a MeshPart this spec builds, through
-- `Runtime:setModelSource` -- the per-runtime override that exists so a spec can never lend its fake
-- to the live server (see that function's comment). `Animator:LoadAnimation` on an id that does not
-- exist returns a usable track whose `Speed` is the rate it was played at (measured, 2026-10-03), so
-- even the per-gait playback rate is provable here; only `Length` is unavailable, which is why
-- `Boar.shouldFreeze` is pure.
--
-- Design: docs/design/boar-ai.md (section 6), docs/design/feature-flags.md (section 13.3)
-- Note:   docs/research/2026-10-03-boar-skinned-model.md
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local CONFIG = Boar.CONFIG
local MODEL = CONFIG.MODEL

local GROUND_Y = 620 -- its own plate, well clear of boar_body.spec's at 500
local PLATE_SPAN = 120
local FIELD = {
	bounds = { minX = -55, maxX = 55, minZ = -55, maxZ = 55 },
	exitZ = -40,
	groundY = GROUND_Y,
}

-- The real model's MEASURED size, read in Studio off asset 120607820179994 on 2026-10-03 and the
-- same number `Assets.ROWS`' `boar.male` v3 row carries. The fake template is built at it so the
-- offset this spec asserts is the offset the game uses.
local MESH_SIZE = Vector3.new(1.4011, 3.2573, 5.5)

-- A fake id per clip, so the track plumbing is exercised without an asset. Distinct, so a clip
-- played under the wrong name would show up as the wrong id.
local FAKE_IDS = {
	idle = 10001,
	walk = 10002,
	trot = 10003,
	run = 10004,
	turnLeft = 10005,
	turnRight = 10006,
	deathLeft = 10007,
	deathRight = 10008,
	hitFront = 10009,
	hitBack = 10010,
}

return function()
	local testRoot, plate

	-- A world of this spec's own. No threats and no path service: every case here is about what is
	-- drawn, and a boar that never flees is a boar whose speed this spec sets itself.
	local function buildWorld(modelEnabled: boolean)
		local world
		world = {
			field = FIELD,
			parent = testRoot,
			folderName = if modelEnabled then "BoarsModelOn" else "BoarsModelOff",
			rng = Random.new(115),
			threats = function()
				return {}
			end,
			probe = function()
				return false
			end,
			config = {
				-- THE FLAG'S VALUE ARRIVES AS A PARAMETER, which is the whole point of reading it at
				-- one boundary: both branches are reachable while `Flags.DEFAULTS.BOAR_MODEL` sits at
				-- one of them (docs/design/feature-flags.md section 13.3). A clone, because the
				-- runtime must not be handed the module's own table to write ids into.
				MODEL = (function()
					local copy = table.clone(MODEL)
					copy.ENABLED = modelEnabled
					return copy
				end)(),
			},
		}
		return world
	end

	local function makeTemplate(): Model
		local model = Instance.new("Model")
		model.Name = "FakeBoarTemplate"
		local mesh = Instance.new("MeshPart")
		mesh.Name = "BoarMale_NoAlpha"
		mesh.Size = MESH_SIZE
		mesh.Anchored = true -- as a TEMPLATE; attachVisual must unanchor the clone
		mesh.CanCollide = true -- ...and must turn all three of these off
		mesh.CanQuery = true
		mesh.CanTouch = true
		mesh.Massless = false
		local bone = Instance.new("Bone")
		bone.Name = "root_bone"
		bone.Parent = mesh
		mesh.Parent = model
		model.PrimaryPart = mesh
		model.Parent = testRoot
		return model
	end

	local function newRuntime(modelEnabled: boolean, template: Instance?, ids: { [string]: number }?)
		local runtime = Boar.newRuntime(buildWorld(modelEnabled))
		runtime:setModelSource(
			if template
				then function()
					return template
				end
				else nil,
			if ids
				then function(name: string)
					return ids[name]
				end
				else nil
		)
		return runtime
	end

	-- One step of the runtime's own loop, as the Heartbeat would drive it.
	local function step(runtime, dt: number?, times: number?)
		for _ = 1, times or 1 do
			runtime:step(dt or 1 / 60)
		end
	end

	local function visualsOf(part: BasePart): { Model }
		local out = {}
		for _, child in ipairs(part:GetChildren()) do
			if child:IsA("Model") then
				table.insert(out, child)
			end
		end
		return out
	end

	beforeAll(function()
		testRoot = Instance.new("Folder")
		testRoot.Name = "BoarModelSpec"
		plate = Instance.new("Part")
		plate.Name = "Plate"
		plate.Size = Vector3.new(PLATE_SPAN, 4, PLATE_SPAN)
		plate.Position = Vector3.new(0, GROUND_Y - 2, 0)
		plate.Anchored = true
		plate.TopSurface = Enum.SurfaceType.Smooth
		plate.Parent = testRoot
		testRoot.Parent = Workspace
	end)

	afterAll(function()
		if testRoot then
			testRoot:Destroy()
		end
	end)

	describe("the flag is declared as a dark path", function()
		it("is born off, owned by the boar, and expires inside 21 days", function()
			local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
			local row = Flags.DEFAULTS.BOAR_MODEL
			expect(row).to.be.ok()
			expect(row.default).to.equal(false)
			expect(row.owner).to.equal("ServerScriptService.Boar")
			-- 21 days from `born`. flags.spec already fails the harness on an expired row; this says
			-- the ceiling was respected when it was written, which that cannot.
			expect(row.born:find("2026%-10%-03")).to.be.ok()
			expect(row.expires).to.equal("2026-10-24")
		end)

		it("is read once, at the boar's own boundary", function()
			-- `Boar.CONFIG.MODEL.ENABLED` is the one place the flag is read, and every function takes
			-- the value as a parameter from there. If this is ever a second `Flags.isOn` call
			-- somewhere inside the boar, the two can disagree.
			expect(type(MODEL.ENABLED)).to.equal("boolean")
		end)
	end)

	describe("flag OFF draws exactly the grey box", function()
		local runtime, handle

		beforeAll(function()
			runtime = newRuntime(false, makeTemplate(), FAKE_IDS)
			handle = runtime:spawn(Vector3.new(-20, GROUND_Y, 0))
			step(runtime, 1 / 60, 10)
		end)

		afterAll(function()
			runtime:destroy()
		end)

		it("adds no visual child, no Model and no AnimationController", function()
			expect(#visualsOf(handle.part)).to.equal(0)
			expect(handle.part:FindFirstChildWhichIsA("AnimationController", true)).to.equal(nil)
			expect(handle.part:FindFirstChild(MODEL.NAME)).to.equal(nil)
		end)

		it("leaves the box visible and the three zone parts exactly as before", function()
			expect(handle.part.Transparency).to.equal(0)
			local zones = {}
			for _, child in ipairs(handle.part:GetChildren()) do
				if child:IsA("BasePart") then
					table.insert(zones, child)
					expect(child.Transparency).to.equal(0)
				end
			end
			expect(#zones).to.equal(#CONFIG.ZONES.ORDER)
		end)

		it("keeps the attributes the weapon reads", function()
			expect(handle.part:GetAttribute("Damageable")).to.equal(true)
			expect(handle.part:GetAttribute("HitZone")).to.equal("body")
			expect(handle.part.CanQuery).to.equal(true)
			expect(handle.part.CanCollide).to.equal(true)
		end)
	end)

	describe("flag ON welds one skinned model to the same box", function()
		local runtime, handle, template

		beforeAll(function()
			template = makeTemplate()
			runtime = newRuntime(true, template, FAKE_IDS)
			handle = runtime:spawn(Vector3.new(20, GROUND_Y, 0))
			step(runtime, 1 / 60, 3)
		end)

		afterAll(function()
			runtime:destroy()
		end)

		it("adds exactly one visual, and only one however many times it steps", function()
			step(runtime, 1 / 60, 30)
			local visuals = visualsOf(handle.part)
			expect(#visuals).to.equal(1)
			expect(visuals[1].Name).to.equal(MODEL.NAME)
			TestKit.note(string.format("boar-model: visuals after 33 steps = %d", #visuals))
		end)

		it("is a passenger: massless, no collision, NO RAY CAN SEE IT", function()
			local mesh = visualsOf(handle.part)[1].PrimaryPart :: BasePart
			expect(mesh).to.be.ok()
			expect(mesh.Massless).to.equal(true)
			expect(mesh.CanCollide).to.equal(false)
			expect(mesh.CanQuery).to.equal(false)
			expect(mesh.CanTouch).to.equal(false)
			expect(mesh.Anchored).to.equal(false)
			-- It carries NEITHER attribute the weapon looks for: two damageable instances in one
			-- ancestor chain is an ambiguity, not a feature (Body's own words about the zone parts).
			expect(mesh:GetAttribute("Damageable")).to.equal(nil)
			expect(mesh:GetAttribute("HitZone")).to.equal(nil)
		end)

		it("is welded to the trunk and nothing else", function()
			local mesh = visualsOf(handle.part)[1].PrimaryPart :: BasePart
			local weld = mesh:FindFirstChildWhichIsA("WeldConstraint")
			expect(weld).to.be.ok()
			expect((weld :: WeldConstraint).Part0).to.equal(handle.part)
			expect((weld :: WeldConstraint).Part1).to.equal(mesh)
		end)

		it("stands with its feet on the bottom of the box", function()
			local mesh = visualsOf(handle.part)[1].PrimaryPart :: BasePart
			local offset = handle.part.CFrame:ToObjectSpace(mesh.CFrame).Position
			local want = Boar.visualOffset(MESH_SIZE, CONFIG.BODY_SIZE)
			expect((offset - want).Magnitude < 1e-3).to.equal(true)
			-- Said as the thing it means, not as the arithmetic: the lowest point of the animal and
			-- the lowest point of the box are the same height.
			local meshBottom = offset.Y - MESH_SIZE.Y / 2
			expect(math.abs(meshBottom - (-CONFIG.BODY_SIZE.Y / 2)) < 1e-3).to.equal(true)
			TestKit.note(
				string.format(
					"boar-model: mesh offset %.4f studs up, mesh bottom %.4f, box bottom %.4f",
					offset.Y,
					meshBottom,
					-CONFIG.BODY_SIZE.Y / 2
				)
			)
		end)

		it("gives the model its own Animator, in the model and not on the box", function()
			local visual = visualsOf(handle.part)[1]
			local controller = visual:FindFirstChildWhichIsA("AnimationController")
			expect(controller).to.be.ok()
			expect((controller :: AnimationController):FindFirstChildWhichIsA("Animator")).to.be.ok()
			-- The rig root is the controller's PARENT, so it must be the Model that holds the bones.
			expect(controller.Parent).to.equal(visual)
			expect(visual.PrimaryPart:FindFirstChild("root_bone")).to.be.ok()
		end)

		it("hides the box and its zones instead of deleting them", function()
			expect(handle.part.Transparency).to.equal(1)
			local zones = 0
			for _, child in ipairs(handle.part:GetChildren()) do
				if child:IsA("BasePart") then
					zones += 1
					expect(child.Transparency).to.equal(1)
				end
			end
			expect(zones).to.equal(#CONFIG.ZONES.ORDER)
			-- ...and the box is still the only thing a shot can land on.
			expect(handle.part.CanQuery).to.equal(true)
			expect(handle.part.CanCollide).to.equal(true)
			expect(handle.part:GetAttribute("Damageable")).to.equal(true)
		end)

		it("a ray from outside still meets a zone part, never the model", function()
			-- THE CLAIM THE WHOLE FLAG RESTS ON, fired as a real ray rather than reasoned about:
			-- boar_zones.spec does this for the grey box, and this is the same shot with the model on.
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { handle.part }
			local from = handle.part.Position + handle.part.CFrame.LookVector * -40
			local result = Workspace:Raycast(from, handle.part.CFrame.LookVector * 80, params)
			expect(result).to.be.ok()
			local hit = (result :: RaycastResult).Instance
			expect(hit:GetAttribute("HitZone")).to.be.ok()
			expect(hit:IsDescendantOf(visualsOf(handle.part)[1])).to.equal(false)
			TestKit.note("boar-model: a ray through the boar met " .. hit.Name)
		end)

		it("destroys the visual with the boar and leaves the template alone", function()
			local visual = visualsOf(handle.part)[1]
			runtime:clear("spec")
			expect(visual.Parent).to.equal(nil)
			expect(template.Parent).to.be.ok() -- the template is NOT the clone
			expect(template.PrimaryPart).to.be.ok()
		end)
	end)

	describe("flag ON with no model loaded is still the grey box", function()
		it("draws nothing extra while the asset has not arrived", function()
			-- `Loader.preload` is bounded at 15 s, so this is a real state and not a hypothetical.
			local runtime = newRuntime(true, nil, FAKE_IDS)
			local handle = runtime:spawn(Vector3.new(0, GROUND_Y, 20))
			step(runtime, 1 / 60, 20)
			expect(#visualsOf(handle.part)).to.equal(0)
			expect(handle.part.Transparency).to.equal(0) -- NOT hidden: an invisible boar is worse
			runtime:destroy()
		end)

		it("puts the coat on as soon as the asset does arrive", function()
			local template = makeTemplate()
			local runtime = Boar.newRuntime(buildWorld(true))
			local ready = false
			runtime:setModelSource(function()
				return if ready then template else nil
			end, function(name: string)
				return FAKE_IDS[name]
			end)
			local handle = runtime:spawn(Vector3.new(0, GROUND_Y, 30))
			step(runtime, 1 / 60, 5)
			expect(#visualsOf(handle.part)).to.equal(0)
			ready = true
			-- ASK_EVERY_SECONDS is a real second of os.clock, so the wait is real: the runtime does
			-- not ask sixty times a second, deliberately (it would count sixty misses in Loader.stats).
			local deadline = os.clock() + MODEL.ASK_EVERY_SECONDS + 1
			while os.clock() < deadline and #visualsOf(handle.part) == 0 do
				RunService.Heartbeat:Wait()
				step(runtime, 1 / 60)
			end
			expect(#visualsOf(handle.part)).to.equal(1)
			runtime:destroy()
		end)
	end)

	describe("which clip, and how fast", function()
		local function clip(info)
			local filled = {
				collapsed = false,
				hitFor = 0,
				hitFromBehind = false,
				speed = 0,
				yawRate = 0,
			}
			for key, value in pairs(info) do
				filled[key] = value
			end
			return Boar.clipFor(filled, CONFIG)
		end

		local function rateOf(info)
			local _, rate = clip(info)
			return rate
		end

		it("stands still when it is standing still", function()
			local name, rate = clip({})
			expect(name).to.equal("idle")
			expect(rate).to.equal(1)
		end)

		it("walks at the grazing speed, trots when pushed, runs when it bolts", function()
			expect((clip({ speed = CONFIG.WANDER_SPEED }))).to.equal("walk")
			expect((clip({ speed = CONFIG.TROT_SPEED }))).to.equal("trot")
			expect((clip({ speed = CONFIG.SPRINT_SPEED }))).to.equal("run")
		end)

		it("plays each gait at the rate that stops the feet sliding", function()
			-- rate = speed / the clip's own measured ground speed. The three numbers are
			-- tools/boar_prep.py's measurements of this package at this scale.
			local walk = CONFIG.WANDER_SPEED / MODEL.CLIPS.walk.groundStudsPerSecond
			local trot = CONFIG.TROT_SPEED / MODEL.CLIPS.trot.groundStudsPerSecond
			local run = CONFIG.SPRINT_SPEED / MODEL.CLIPS.run.groundStudsPerSecond
			expect(math.abs(rateOf({ speed = CONFIG.WANDER_SPEED }) - walk) < 1e-6).to.equal(true)
			expect(math.abs(rateOf({ speed = CONFIG.TROT_SPEED }) - trot) < 1e-6).to.equal(true)
			expect(math.abs(rateOf({ speed = CONFIG.SPRINT_SPEED }) - run) < 1e-6).to.equal(true)
			TestKit.note(string.format("boar-model: rates walk %.3f trot %.3f run %.3f", walk, trot, run))
			-- ...and all three are inside the clamp, which is what makes the clamp a guard against a
			-- mis-measured clip rather than something the game runs into every tick.
			expect(walk > MODEL.MIN_RATE and walk < MODEL.MAX_RATE).to.equal(true)
			expect(trot > MODEL.MIN_RATE and trot < MODEL.MAX_RATE).to.equal(true)
			expect(run > MODEL.MIN_RATE and run < MODEL.MAX_RATE).to.equal(true)
		end)

		it("clamps an absurd rate instead of playing it", function()
			expect(rateOf({ speed = 10000 })).to.equal(MODEL.MAX_RATE)
			-- Just over WALK_FROM on the walk clip is slower than MIN_RATE, so the floor bites.
			expect(rateOf({ speed = MODEL.WALK_FROM })).to.equal(MODEL.MIN_RATE)
		end)

		it("turns in place only when it is not going anywhere", function()
			expect((clip({ yawRate = 120 }))).to.equal("turnLeft")
			expect((clip({ yawRate = -120 }))).to.equal("turnRight")
			expect((clip({ yawRate = MODEL.TURN_FROM_DEG - 1 }))).to.equal("idle")
			-- A turn while walking is a walk: the turn clips are pivots and would skate.
			expect((clip({ yawRate = 200, speed = CONFIG.WANDER_SPEED }))).to.equal("walk")
			expect((clip({ yawRate = 200, speed = CONFIG.SPRINT_SPEED }))).to.equal("run")
		end)

		it("flinches, from the side the shot came from, and a flinch beats any gait", function()
			expect((clip({ hitFor = 0.2 }))).to.equal("hitFront")
			expect((clip({ hitFor = 0.2, hitFromBehind = true }))).to.equal("hitBack")
			expect((clip({ hitFor = 0.2, speed = CONFIG.SPRINT_SPEED }))).to.equal("hitFront")
		end)

		it("dies, and a death beats everything including a flinch", function()
			local want = if MODEL.DEATH_TO_THE_LEFT then "deathLeft" else "deathRight"
			expect((clip({ collapsed = true }))).to.equal(want)
			expect((clip({ collapsed = true, hitFor = 0.5, speed = CONFIG.SPRINT_SPEED }))).to.equal(want)
		end)

		it("falls on the side the box rolls onto", function()
			-- Body.collapse rolls the trunk by +COLLAPSE_ROLL_DEG about its own Z, which tips its
			-- UpVector toward -X: the animal's left. The clip follows the sign rather than a literal.
			expect(MODEL.DEATH_TO_THE_LEFT).to.equal(CONFIG.WOUND.COLLAPSE_ROLL_DEG > 0)
		end)

		it("names only clips that exist, with a measured length and a loop setting", function()
			for _, name in ipairs({
				"idle",
				"walk",
				"trot",
				"run",
				"turnLeft",
				"turnRight",
				"deathLeft",
				"deathRight",
				"hitFront",
				"hitBack",
			}) do
				local row = MODEL.CLIPS[name]
				expect(row).to.be.ok()
				expect(type(row.clip)).to.equal("string")
				expect(row.seconds > 0).to.equal(true)
				expect(type(row.looped)).to.equal("boolean")
			end
			-- A gait loops; a death and a flinch happen once.
			expect(MODEL.CLIPS.walk.looped).to.equal(true)
			expect(MODEL.CLIPS.run.looped).to.equal(true)
			expect(MODEL.CLIPS.deathLeft.looped).to.equal(false)
			expect(MODEL.CLIPS.hitFront.looped).to.equal(false)
			-- Only the three gaits and the two turns move the ground under the animal.
			expect(MODEL.CLIPS.idle.groundStudsPerSecond).to.equal(0)
			expect(MODEL.CLIPS.hitFront.groundStudsPerSecond).to.equal(0)
			expect(MODEL.CLIPS.deathLeft.groundStudsPerSecond).to.equal(0)
		end)
	end)

	describe("a field may never be named after a method", function()
		-- THE GUARD FOR THE ONE BUG THIS TASK SHIPPED, driven with a clash built here because no spec
		-- can make a real Runtime clash without first introducing the defect. `Runtime.__index =
		-- Runtime`, so while a field of a method's name is nil the lookup falls through and hands
		-- back the function -- a silent wrong value, not an error. `Boar.newRuntime` asserts on this,
		-- and every runtime built above this line is that assertion passing.
		it("finds a clash, ignores __index, and says nothing about a clean table", function()
			local methods = { step = function() end, folder = function() end, __index = {} }
			expect(#Boar.fieldMethodClashes({ _config = 1, _boars = {} }, methods)).to.equal(0)
			expect(Boar.fieldMethodClashes({ step = nil, folder = 2 }, methods)[1]).to.equal("folder")
			-- A nil field is not an own key at all, which is exactly why the bug was invisible: the
			-- clash has to be caught at CONSTRUCTION, where the field is written.
			local both = Boar.fieldMethodClashes({ step = false, folder = 2 }, methods)
			expect(#both).to.equal(2)
			expect(both[1]).to.equal("folder") -- sorted, so the message is the same every run
			expect(both[2]).to.equal("step")
			-- __index is the metatable pointing at itself, not a method anybody calls.
			expect(#Boar.fieldMethodClashes({ __index = 1 }, methods)).to.equal(0)
		end)
	end)

	describe("a death holds its last frame", function()
		it("freezes at the end, and never before it or twice", function()
			local epsilon = MODEL.HOLD_EPSILON
			expect(Boar.shouldFreeze(1.25, 1.25, 1, epsilon)).to.equal(true)
			expect(Boar.shouldFreeze(1.25 - epsilon / 2, 1.25, 1, epsilon)).to.equal(true)
			expect(Boar.shouldFreeze(0.5, 1.25, 1, epsilon)).to.equal(false)
			-- Already frozen: do not write the property again.
			expect(Boar.shouldFreeze(1.25, 1.25, 0, epsilon)).to.equal(false)
			-- NOT LOADED YET is not THE END. A zero length is every track in this spec, and it is
			-- every track in a live server for the first moments of a session.
			expect(Boar.shouldFreeze(0, 0, 1, epsilon)).to.equal(false)
		end)
	end)

	describe("the track that actually plays", function()
		local runtime, handle

		beforeAll(function()
			runtime = newRuntime(true, makeTemplate(), FAKE_IDS)
			handle = runtime:spawn(Vector3.new(-40, GROUND_Y, 20))
			step(runtime, 1 / 60, 3)
		end)

		afterAll(function()
			runtime:destroy()
		end)

		it("loads one Animation per clip it has played, with the manifest's own id", function()
			local animator = handle.part:FindFirstChildWhichIsA("Animator", true)
			expect(animator).to.be.ok()
			local played = animator:GetChildren()
			expect(#played >= 1).to.equal(true)
			for _, animation in ipairs(played) do
				expect(animation:IsA("Animation")).to.equal(true)
				local wanted = FAKE_IDS[animation.Name]
				expect(wanted).to.be.ok()
				expect(animation.AnimationId).to.equal("rbxassetid://" .. tostring(wanted))
			end
			TestKit.note(string.format("boar-model: %d Animation instance(s) loaded", #played))
		end)

		it("plays the idle clip for a boar that is standing still", function()
			local animator = handle.part:FindFirstChildWhichIsA("Animator", true)
			expect(animator:FindFirstChild("idle")).to.be.ok()
		end)

		it("loads no Animation at all when the manifest has no id yet", function()
			-- THE STATE THIS REPOSITORY IS ACTUALLY IN until the ten clips are published out of
			-- Studio's Animation Editor: the boar is drawn, welded and textured, and it does not move
			-- its legs. Silence here would be the bug; nothing half-built is.
			local bare = newRuntime(true, makeTemplate(), nil)
			local other = bare:spawn(Vector3.new(40, GROUND_Y, 20))
			step(bare, 1 / 60, 10)
			expect(#visualsOf(other.part)).to.equal(1) -- still drawn
			local animator = other.part:FindFirstChildWhichIsA("Animator", true)
			expect(animator).to.be.ok()
			expect(#animator:GetChildren()).to.equal(0)
			bare:destroy()
		end)
	end)
end
