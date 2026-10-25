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
			-- A PATHFINDER THAT ANSWERS NOTHING, which is a state the production world reaches too
			-- (`pathFailed`), and the Brain's own Reynolds fallback is what handles it. It is here
			-- because a WOUNDED boar asks for a route the moment it is shot, and the carcass cases
			-- below shoot one: without these the step loop called a nil `requestPath`. A real
			-- PathfindingService has no business in a spec about what is drawn.
			requestPath = function(_agentId, _from, _to, done)
				done(nil)
			end,
			releasePath = function() end,
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

	-- SHAPED LIKE THE REAL ONE, INCLUDING THE PARTS THAT BIT (task 115). `InsertService:LoadAsset`
	-- hands back `Model > Model "<the asset's name>" > { MeshPart, InitialPoses, AnimationController }`
	-- -- Roblox's importer writes that controller itself. A fake without it let the first version of
	-- this spec pass while every boar in the game stood still for ever, because two controllers on
	-- one rig means neither steps. The fake carries both the nesting and the controller now.
	local function makeTemplate(): Model
		local model = Instance.new("Model")
		model.Name = "FakeBoarTemplate"
		local inner = Instance.new("Model")
		inner.Name = "Boar Male RedDeer v3"
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
		mesh.Parent = inner
		local poses = Instance.new("Folder")
		poses.Name = "InitialPoses"
		poses.Parent = inner
		local theirs = Instance.new("AnimationController")
		theirs.Parent = inner
		inner.Parent = model
		inner.PrimaryPart = mesh
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
				then function(_species: string, name: string)
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

	describe("the flag is declared, and since task 230 it is LIT", function()
		it("is born off on 2026-10-03, owned by the boar, and is ON by default since task 230", function()
			-- TASK 230 FLIPPED IT (Karen, 2026-10-21: "add deer in a game", on top of her OK of the
			-- drawn boar in task 115 -- "looks good now"). Until then this case read
			-- `default == false` and `expires == "2026-10-24"`, which is what a DARK path's row
			-- looks like; what it asserts now is the LIT row, and the two halves that did not
			-- change -- who owns it, and when it was born -- are still asserted, so the flip cannot
			-- be mistaken for a row somebody rewrote.
			local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
			local row = Flags.DEFAULTS.BOAR_MODEL
			expect(row).to.be.ok()
			expect(row.default).to.equal(true)
			expect(row.owner).to.equal("ServerScriptService.Boar")
			expect(row.born:find("2026%-10%-03")).to.be.ok()
			-- AN ACCEPTED FLAG DOES NOT KEEP A 21-DAY CEILING (`RIFLE`, `FIRST_PERSON`,
			-- `BOAR_SOUNDERS` and `ORANGE_OUTFITS` all carry this same date for this same reason):
			-- the ceiling is what stops a path nobody has judged living for ever, and this one is
			-- judged. Left at 2026-10-24 the row would fail `flags.spec`'s rot tripwire -- and so
			-- the whole harness -- on the 25th.
			expect(row.expires).to.equal("2026-12-31")
		end)

		it("publishes the flag's own value at the boar's boundary", function()
			-- RENAMED TO WHAT IT ASSERTS (review round 1, note). It cannot prove the flag is read
			-- ONCE -- a spec cannot count `Flags.isOn` calls in another module -- so it does not
			-- claim to. What it does check is worth checking: the value the rest of the boar is
			-- handed is the flag's, not a copy that has drifted from it.
			local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
			expect(type(MODEL.ENABLED)).to.equal("boolean")
			expect(MODEL.ENABLED).to.equal(Flags.isOn("BOAR_MODEL"))
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

		it("ends up with exactly ONE AnimationController and ONE Animator", function()
			-- THE BUG THIS TASK SHIPPED AND MEASURED ITS WAY OUT OF. The uploaded asset carries an
			-- AnimationController of its own, so the visual had two: every track loaded with the
			-- right `Length`, `WeightTarget` went to 1, and `WeightCurrent`, `TimePosition` and every
			-- `Bone.Transform` stayed at zero for ever on both server and client. Nothing errored.
			-- A/B'd live: a copy with a fresh controller animated, the one keeping the asset's did
			-- not. `attachVisual` asserts this too, so a regression cannot even build a boar.
			local visual = visualsOf(handle.part)[1]
			local controllers, animators = 0, 0
			for _, d in ipairs(visual:GetDescendants()) do
				if d:IsA("AnimationController") then
					controllers += 1
				elseif d:IsA("Animator") then
					animators += 1
				end
			end
			expect(controllers).to.equal(1)
			expect(animators).to.equal(1)
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
			end, function(_species: string, name: string)
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

		it("never clamps at a speed a boar can actually reach", function()
			-- THE INVARIANT THE BAND EDGES EXIST FOR, and it is here because the first version broke
			-- it silently. `WALK_FROM`..`SPRINT_SPEED` is every speed the Brain can ask for -- a
			-- WOUNDED boar is not on one of Karen's three dials, it is at whatever fraction of 18
			-- `Wound.speedScale` gives, measured live at 8.99 and 9.84 studs/s -- and at 9 the walk
			-- clip was being asked for 3.15 and clamped to 2.50, which is feet sliding by a quarter.
			-- Below about 1.1 studs/s the floor does bite, and that is the floor's whole job: an
			-- animal creeping at a tenth of a stud a second is standing still, not strolling.
			-- THE BAND THIS COUNTS IS NOT THE BAND IT STARTS AT (review round 1, note): below about
			-- 1.1 studs/s the floor does bite, and that is the floor's job, so the count begins at
			-- `countFrom` and the note prints THAT -- the earlier wording said "swept 0.5..38" for a
			-- band it was not counting.
			local countFrom = 1.2
			local clamped, worst, worstAt = 0, 0, 0
			local speed = MODEL.WALK_FROM
			while speed <= CONFIG.SPRINT_SPEED do
				local name, rate = clip({ speed = speed })
				local natural = MODEL.CLIPS[name].groundStudsPerSecond
				if natural > 0 and speed >= countFrom then
					if rate <= MODEL.MIN_RATE or rate >= MODEL.MAX_RATE then
						clamped += 1
						if math.abs(speed / natural - rate) > worst then
							worst, worstAt = math.abs(speed / natural - rate), speed
						end
					end
				end
				speed += 0.1
			end
			TestKit.note(
				string.format(
					"boar-model: swept %.1f..%.0f studs/s, %d clamped (worst %.2f at %.1f)",
					countFrom,
					CONFIG.SPRINT_SPEED,
					clamped,
					worst,
					worstAt
				)
			)
			expect(clamped).to.equal(0)
		end)

		it("hands the walk band over to the trot before the walk clip has to race", function()
			-- The boundary is derived from the walk clip's own measured speed, not from a midpoint
			-- between Karen's dials. A literal here would stop matching the moment a clip or a dial
			-- changed, which is exactly how the clamped band got in.
			expect(MODEL.TROT_FROM).to.equal(MODEL.CLIPS.walk.groundStudsPerSecond * MODEL.WALK_MAX_RATE)
			-- ...and Karen's three anchors still land on the three gaits she named.
			expect((clip({ speed = CONFIG.WANDER_SPEED }))).to.equal("walk")
			expect((clip({ speed = CONFIG.TROT_SPEED }))).to.equal("trot")
			expect((clip({ speed = CONFIG.SPRINT_SPEED }))).to.equal("run")
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
			-- A RUNNING animal shows only the first `HIT_MOVING_SECONDS` of the window (task 116 fix
			-- round, Karen: "feels late hit and odd" -- the in-place flinch used to hold the whole
			-- 0.833 s while the body bolted at sprint speed). `hitFor` counts DOWN, so a big `hitFor`
			-- is early in the window and a small one is late in it.
			local early = MODEL.HIT_SECONDS - MODEL.HIT_MOVING_SECONDS / 2
			expect((clip({ hitFor = early, speed = CONFIG.SPRINT_SPEED }))).to.equal("hitFront")
			expect((clip({ hitFor = 0.2, speed = CONFIG.SPRINT_SPEED }))).to.equal("run")
			-- ...and a standing one still gets all of it, which is what this case has always said.
			expect((clip({ hitFor = 0.2, speed = 0 }))).to.equal("hitFront")
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

	describe("every clip the boar can play has a published asset id", function()
		-- THE HOLE THIS TASK LEFT, NOW CLOSED (2026-10-03). The ten ids can only be made inside
		-- Studio's Animation Editor by hand, so for the first half of this task `BoarAssetsBoot`
		-- warned "0 of 10" and the animal stood still. These cases are what stops that silently
		-- happening again -- to the female, to the cub, or to a clip somebody adds to `CLIPS`
		-- without publishing it.
		local Assets = require(game:GetService("ServerStorage"):WaitForChild("Assets"))

		-- The same mapping `BoarAssetsBoot` holds. It is duplicated HERE on purpose: a spec that
		-- imported the boot script's table could not notice that table being wrong.
		local KEY_OF = {
			idle = "boar.anim.idle",
			walk = "boar.anim.walk",
			trot = "boar.anim.trot",
			run = "boar.anim.run",
			turnLeft = "boar.anim.turn.left",
			turnRight = "boar.anim.turn.right",
			deathLeft = "boar.anim.death.left",
			deathRight = "boar.anim.death.right",
			hitFront = "boar.anim.hit.front",
			hitBack = "boar.anim.hit.back",
			deathPaddleLeft = "boar.anim.death.paddle.left",
			deathPaddleRight = "boar.anim.death.paddle.right",
			crippleDrag = "boar.anim.cripple.drag",
			smell = "boar.anim.calm.smell",
			grazeLoop = "boar.anim.calm.graze.loop",
			grazeChew = "boar.anim.calm.graze.chew",
			grazeStart = "boar.anim.calm.graze.start",
			grazeEnd = "boar.anim.calm.graze.end",
			digWalk = "boar.anim.calm.dig.walk",
		}

		-- Every one of the nineteen clips is published, so there is no skip list any more (review
		-- round 2, note: an empty table and three `continue` guards nothing could reach).

		-- THE THREE THIS PROJECT AUTHORED (task 116 fix round), PUBLISHED by the Director on
		-- 2026-10-03 with each id verified by `AnimationClipProvider:GetAnimationClipAsync`. They are
		-- listed because every case below treats them exactly like the package's ten -- a row, an id,
		-- and a length that agrees with the config -- and because `source` is the one field where
		-- they differ: "own", not "creator-store".
		local AUTHORED_HERE = { crippleDrag = true, deathPaddleLeft = true, deathPaddleRight = true }

		it("names the same ten clips the boar knows, and no others", function()
			-- Every key string this spec uses must be one `Assets.KEYS` DECLARES. That is the
			-- `Map.TAGS` rule: a key typed as a literal where it is read is a silent nil nobody can
			-- explain, and a spec that typed its own would pass while the game found no row.
			local declared = {}
			for _, value in pairs(Assets.KEYS) do
				declared[value] = true
			end

			local inConfig, inKeys, authored = 0, 0, 0
			for name in pairs(MODEL.CLIPS) do
				inConfig += 1
				if AUTHORED_HERE[name] then
					authored += 1
				end
				expect(KEY_OF[name]).to.be.ok()
				expect(declared[KEY_OF[name]]).to.equal(true)
			end
			for name in pairs(KEY_OF) do
				inKeys += 1
				expect(MODEL.CLIPS[name]).to.be.ok()
			end
			-- Ten out of the package, three this project authored, and six more of the package's own
			-- for the calm repertoire (task 117). The two tables agree about every one of them.
			expect(inConfig).to.equal(19)
			expect(inKeys).to.equal(19)
			expect(authored).to.equal(3)
		end)

		it("has a row with a real asset id for every one of them", function()
			local missing = {}
			for name in pairs(MODEL.CLIPS) do
				local row = Assets.byKey(KEY_OF[name])
				if row == nil or row.kind ~= "animation" or row.modelId <= 0 then
					table.insert(missing, name)
				end
			end
			table.sort(missing)
			-- Named, not counted: "3 missing" sends the next reader looking for which three.
			expect(table.concat(missing, ", ")).to.equal("")

			-- ...AND THE THREE THIS PROJECT MADE SAY SO IN THE ONE FIELD THAT MATTERS. They are built
			-- by `tools/boar_prep.py` out of the package's own poses, so the licence is the package's
			-- and the creator is its creator, but the FILE is this repository's: a reader asking
			-- "where did this animation come from" gets a different answer for these three.
			for name in pairs(AUTHORED_HERE) do
				local row = Assets.byKey(KEY_OF[name])
				expect(row).to.be.ok()
				expect(row.source).to.equal("own")
			end
		end)

		it("agrees with the manifest about how long each clip is", function()
			-- The two copies of one measurement. `BoarAssetsBoot` warns at boot; this fails the
			-- build, which is the half that stops it being merged. Half a frame at 24 fps.
			local worst, worstName = 0, "none"
			for name, clip in pairs(MODEL.CLIPS) do
				local row = Assets.byKey(KEY_OF[name])
				expect(row.clipSeconds).to.be.ok()
				local drift = math.abs(row.clipSeconds - clip.seconds)
				if drift > worst then
					worst, worstName = drift, name
				end
			end
			TestKit.note(string.format("boar-model: worst clip-length drift %.4f s (%s)", worst, worstName))
			expect(worst <= 1 / 48).to.equal(true)
		end)

		it("never asks InsertService to load an animation", function()
			-- An animation is a number on an `Animation.AnimationId`, not an Instance you insert.
			-- A boot script handed one would spend a network load that can only fail, and delay the
			-- model that does need it.
			for _, key in ipairs(Assets.keysFor("boar")) do
				local row = Assets.byKey(key)
				expect(row.kind).never.to.equal("animation")
			end
			expect(#Assets.keysFor("boar-animation")).to.equal(0)
			expect(Assets.INSERTABLE.animation).to.equal(nil)
		end)

		it("plays a death and a flinch ONCE, however the asset was published", function()
			-- All ten were published `Loop = true` (the Animation Editor's dialog does not ask), so
			-- "it loops" is a fact about the asset and "it plays once" has to be a property write.
			expect(MODEL.CLIPS.deathLeft.looped).to.equal(false)
			expect(MODEL.CLIPS.deathRight.looped).to.equal(false)
			expect(MODEL.CLIPS.hitFront.looped).to.equal(false)
			expect(MODEL.CLIPS.hitBack.looped).to.equal(false)
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

	describe("the carcass lies ON the ground, not in it", function()
		-- KAREN, 2026-10-03: "yes synced in when died" / "fix syncing". After a kill only the four
		-- legs stuck out of the surface. MEASURED on a real kill: the head finished 1.20 studs BELOW
		-- the ground, an ear 1.93 below, and a hind hoof 0.85 ABOVE it. The cause is the rotation
		-- happening TWICE -- `Body.collapse` rolls the box 45 degrees past its tipping angle AND the
		-- death clip lays the animal down in the rig's own frame -- so the animal ends up roughly
		-- upside down. Measured again with the same carcass's box put back upright: the lowest bone
		-- sat at -0.02 of the ground. So the clip does the falling and the box holds still.
		local function readyBoar(modelEnabled: boolean, withTemplate: boolean, at: Vector3)
			local runtime = newRuntime(modelEnabled, if withTemplate then makeTemplate() else nil, FAKE_IDS)
			local handle = runtime:spawn(at)
			step(runtime, 1 / 60, 3)
			return runtime, handle
		end

		local function kill(runtime, handle)
			-- Through the one seam a hit enters by, so this is the path a player's slug takes. The ammo
			-- name is "Slug" with the capital the damage table uses -- `boar_hit.spec`'s own spelling --
			-- because an ammo nothing recognises charges no damage and the boar simply does not die.
			local taken = runtime:takeHit(handle.part, { zone = "head", ammo = "Slug", pellets = 1, at = 0 })
			expect(taken).to.equal(true)
			-- The collapse is decided by `Wound.advance` on a LATER step, not inside takeHit, so this
			-- waits for the carcass rather than assuming three frames are enough.
			local deadline = os.clock() + 3
			while os.clock() < deadline and handle.part:GetAttribute("Carcass") ~= true do
				step(runtime, 1 / 60)
				RunService.Heartbeat:Wait()
			end
			step(runtime, 1 / 60, 3)
		end

		it("flag OFF: the grey box still topples, exactly as since Task 28", function()
			local runtime, handle = readyBoar(false, true, Vector3.new(-40, GROUND_Y, -20))
			kill(runtime, handle)
			expect(handle.part:GetAttribute("Carcass")).to.equal(true)
			-- Rolled past its tipping angle: its own up axis is no longer the world's.
			expect(handle.part.CFrame.UpVector.Y < 0.95).to.equal(true)
			TestKit.note(string.format("boar-model: flag OFF carcass up.y = %.3f", handle.part.CFrame.UpVector.Y))
			runtime:destroy()
		end)

		it("flag ON: the box does NOT roll, because the clip lays the animal down", function()
			local runtime, handle = readyBoar(true, true, Vector3.new(-40, GROUND_Y, 20))
			expect(handle.part:FindFirstChild(MODEL.NAME)).to.be.ok() -- dressed before it can die
			kill(runtime, handle)
			expect(handle.part:GetAttribute("Carcass")).to.equal(true)
			expect(handle.part.CFrame.UpVector.Y > 0.99).to.equal(true)
			TestKit.note(string.format("boar-model: flag ON carcass up.y = %.3f", handle.part.CFrame.UpVector.Y))
			runtime:destroy()
		end)

		it("flag ON: the box's bottom is still on the ground, which is where the clip's floor is", function()
			-- The death clip was authored with the rig's origin on the floor, and the rig's origin is the
			-- BOTTOM of the box (`visualOffset`). So "the animal lies on the ground" is the same statement
			-- as "the box's bottom is still at ground level, and the mesh is still welded where it was" --
			-- which is what this asserts, because no spec in this repository can load a real animation to
			-- measure the mesh itself. The live measurement that it does land there is in the note.
			local runtime, handle = readyBoar(true, true, Vector3.new(0, GROUND_Y, 40))
			kill(runtime, handle)
			-- IT HAS TO FALL FIRST. A boar is spawned `SPAWN_CLEARANCE` (0.5) above the ground so it
			-- settles instead of starting embedded, and a carcass free-falls the rest of the way with its
			-- mover and its upright constraint switched off. So this waits for the box to come to rest on
			-- the plate rather than reading it mid-fall -- which is what `boar_body.spec` does with every
			-- physical claim, and for the same reason.
			local bottom = handle.part.Position.Y - CONFIG.BODY_SIZE.Y / 2
			local settleBy = os.clock() + 3
			while os.clock() < settleBy and math.abs(bottom - GROUND_Y) >= 0.1 do
				RunService.Heartbeat:Wait()
				step(runtime, 1 / 60)
				bottom = handle.part.Position.Y - CONFIG.BODY_SIZE.Y / 2
			end
			-- ON the ground, and not in it: the box's own bottom face is the plane the death clip was
			-- authored against, so this is the spec half of "the animal lies on the surface".
			expect(math.abs(bottom - GROUND_Y) < 0.1).to.equal(true)
			local mesh = visualsOf(handle.part)[1].PrimaryPart :: BasePart
			local offset = handle.part.CFrame:ToObjectSpace(mesh.CFrame).Position
			expect((offset - Boar.visualOffset(MESH_SIZE, CONFIG.BODY_SIZE)).Magnitude < 1e-3).to.equal(true)
			TestKit.note(string.format("boar-model: carcass box bottom %.3f, ground %d", bottom, GROUND_Y))
			runtime:destroy()
		end)

		it("flag ON: a cub's carcass is given back what the male's death clip takes off it", function()
			-- KAREN, 2026-10-04: "when shoot cub he is gone not remaining". It was not gone: the box
			-- was there, anchored, `Carcass = true`, for the whole CARCASS_SECONDS -- the PICTURE was
			-- 1.01 studs under the floor, on an animal 1.44 studs tall. All three kinds play the
			-- male's published clips, a KeyframeSequence's bone translations are absolute studs, and
			-- the fall is built out of child-bone translations, so on geometry baked smaller they
			-- are all too long and they all point down. Measured per kind at the frame the death is
			-- frozen on; the numbers are in `Boar.CONFIG.KINDS`.
			--
			-- NO REAL CLIP IS NEEDED TO ASSERT THE FIX, because the fix is a weld offset: the drawn
			-- body's transform IN THE TRUNK'S FRAME is `visualOffset` before the kill and
			-- `visualOffset + deathLift` after it. That is exactly the number the clip's overshoot
			-- cancels, and it is readable with the fake template.
			-- `KINDS.ENABLED` as a parameter on both sides: the runtime is built with it on, and
			-- the expected numbers are read from the same module with the same value.
			local kindsOn = (function()
				local kinds = table.clone(CONFIG.KINDS)
				kinds.ENABLED = true
				local copy = table.clone(CONFIG)
				copy.KINDS = kinds
				return copy
			end)()
			local world = buildWorld(true)
			world.folderName = "BoarsKindsCarcass"
			world.config.KINDS = { ENABLED = true } -- merged, not replaced: `newRuntime` deep-merges
			local runtime = Boar.newRuntime(world)
			local template = makeTemplate()
			runtime:setModelSource(function()
				return template
			end, function(_species: string, name: string)
				return FAKE_IDS[name]
			end)

			local measured = {}
			for index, kind in ipairs({ "male", "cub" }) do
				local handle = runtime:spawn(Vector3.new(-10 + index * 20, GROUND_Y, -40), kind)
				expect(handle.kind).to.equal(kind)
				step(runtime, 1 / 60, 3)
				local mesh = visualsOf(handle.part)[1].PrimaryPart :: BasePart
				local geometry = Boar.kindGeometry(kind, kindsOn)
				local before = handle.part.CFrame:ToObjectSpace(mesh.CFrame).Position
				expect((before - Boar.visualOffset(MESH_SIZE, geometry.bodySize)).Magnitude < 1e-3).to.equal(true)

				kill(runtime, handle)
				local after = handle.part.CFrame:ToObjectSpace(mesh.CFrame).Position
				-- STRAIGHT UP IN THE TRUNK'S OWN FRAME, and nothing sideways: the carcass must not
				-- slide, only rise.
				expect(math.abs(after.X - before.X) < 1e-3).to.equal(true)
				expect(math.abs(after.Z - before.Z) < 1e-3).to.equal(true)
				expect(math.abs((after.Y - before.Y) - geometry.deathLift) < 1e-3).to.equal(true)
				-- AND IT IS STILL WELDED THERE. The lift is done by disabling the weld, moving the
				-- part and enabling it again, so a weld left off would leave the drawn body loose
				-- inside the assembly -- which this is what refuses.
				local weld = mesh:FindFirstChild("VisualWeld") :: WeldConstraint
				expect(weld).to.be.ok()
				expect(weld.Enabled).to.equal(true)
				expect(weld.Part0).to.equal(handle.part)
				-- The box is untouched by the lift: it is the drawn body that was wrong.
				expect(handle.part.CFrame.UpVector.Y > 0.99).to.equal(true)
				measured[kind] = after.Y - before.Y
			end

			-- THE MALE IS UNCHANGED, which is half the claim: his clip was authored on his own rig,
			-- measured +0.002 of the ground, and Karen accepted that animal. A fix that moved him
			-- would be a regression dressed as a fix.
			expect(math.abs(measured.male) < 1e-3).to.equal(true)
			expect(measured.cub > 1.0).to.equal(true)
			TestKit.note(
				string.format(
					"boar-model: death lift -- male %.3f, cub %.3f studs given back to the drawn body",
					measured.male,
					measured.cub
				)
			)
			runtime:destroy()
		end)

		it("flag ON: lifts NOTHING when there is no death clip to fall with", function()
			-- REVIEW ROUND 1, NOTE. The lift gives back what the DEATH CLIP takes off a smaller rig,
			-- so in the world task 116 deliberately supports -- `BOAR_MODEL` on, no death animation
			-- published -- there is nothing to give back, and lifting anyway would hang a cub's
			-- carcass 1.009 studs in the air for the whole `CARCASS_SECONDS`.
			local kindsOn = (function()
				local kinds = table.clone(CONFIG.KINDS)
				kinds.ENABLED = true
				local copy = table.clone(CONFIG)
				copy.KINDS = kinds
				return copy
			end)()
			local ids = table.clone(FAKE_IDS)
			ids.deathLeft = nil
			ids.deathRight = nil
			local world = buildWorld(true)
			world.folderName = "BoarsNoDeathClip"
			world.config.KINDS = { ENABLED = true }
			local runtime = Boar.newRuntime(world)
			local template = makeTemplate()
			runtime:setModelSource(function()
				return template
			end, function(_species: string, name: string)
				return ids[name]
			end)

			local handle = runtime:spawn(Vector3.new(0, GROUND_Y, -60), "cub")
			step(runtime, 1 / 60, 3)
			local mesh = visualsOf(handle.part)[1].PrimaryPart :: BasePart
			local before = handle.part.CFrame:ToObjectSpace(mesh.CFrame).Position
			-- The cub HAS a lift to give back -- this is the same animal as the case above...
			expect(Boar.kindGeometry("cub", kindsOn).deathLift > 1).to.equal(true)
			kill(runtime, handle)
			-- ...and it stays exactly where it was drawn, because nothing laid it down.
			local after = handle.part.CFrame:ToObjectSpace(mesh.CFrame).Position
			expect((after - before).Magnitude < 1e-3).to.equal(true)
			TestKit.note("boar-model: with no death clip published, a cub's carcass is not lifted")
			runtime:destroy()
		end)

		it("never dresses a boar that is already a carcass", function()
			-- The asset can land AFTER a boar has died (preload is bounded at 15 s). Its box has already
			-- been rolled, so putting the model on now would lay the clip down a second time and bury it
			-- -- the very fault this describe exists for.
			local runtime = Boar.newRuntime(buildWorld(true))
			local template = makeTemplate()
			local ready = false
			runtime:setModelSource(function()
				return if ready then template else nil
			end, function(_species: string, name: string)
				return FAKE_IDS[name]
			end)
			local handle = runtime:spawn(Vector3.new(40, GROUND_Y, -20))
			step(runtime, 1 / 60, 3)
			expect(#visualsOf(handle.part)).to.equal(0)
			kill(runtime, handle)
			expect(handle.part:GetAttribute("Carcass")).to.equal(true)
			ready = true
			local deadline = os.clock() + MODEL.ASK_EVERY_SECONDS + 1
			while os.clock() < deadline do
				RunService.Heartbeat:Wait()
				step(runtime, 1 / 60)
			end
			expect(#visualsOf(handle.part)).to.equal(0) -- still the grey box it died as
			runtime:destroy()
		end)
	end)

	describe("a dead boar stays where it fell", function()
		-- KAREN, 2026-10-03: "when they died and lie on ground I can move them by walking it has to stay
		-- in same place without move". A carcass is an unanchored physics body with CanCollide on, so a
		-- character walking into it shoves it. MEASURED, and it is NOT the model's fault: with the flag
		-- OFF, one impulse the size of a walking character (the boar's own mass 23.1 times 16 studs/s)
		-- moved the grey carcass 1.826 studs. The grey box has been shoveable since Task 28; nobody had
		-- walked into one. So the fix is in BOTH flag states, and both are asserted below.
		local function readyBoar(modelEnabled: boolean, at: Vector3)
			local runtime = newRuntime(modelEnabled, makeTemplate(), FAKE_IDS)
			local handle = runtime:spawn(at)
			step(runtime, 1 / 60, 3)
			return runtime, handle
		end

		-- Kills it and then waits for the carcass to come to rest and anchor, stepping the runtime with
		-- real frames between so the physics actually runs. Returns how long the anchor took.
		local function killAndSettle(runtime, handle): number
			local taken = runtime:takeHit(handle.part, { zone = "head", ammo = "Slug", pellets = 1, at = 0 })
			expect(taken).to.equal(true)
			local began = os.clock()
			local deadline = began + 8
			while os.clock() < deadline and not handle.part.Anchored do
				RunService.Heartbeat:Wait()
				step(runtime, 1 / 60)
			end
			return os.clock() - began
		end

		-- The shove a character delivers by walking into it, as an impulse: the assembly's own mass
		-- times a walking speed. This is the measurement from the live session, written as a test.
		local function shove(handle): number
			local before = handle.part.Position
			handle.part:ApplyImpulse(Vector3.new(1, 0, 0) * handle.part.AssemblyMass * 16)
			local deadline = os.clock() + 1.5
			while os.clock() < deadline do
				RunService.Heartbeat:Wait()
			end
			return (handle.part.Position - before).Magnitude
		end

		it("flag OFF: a shove moves it less than a tenth of a stud", function()
			local runtime, handle = readyBoar(false, Vector3.new(-50, GROUND_Y, -40))
			local took = killAndSettle(runtime, handle)
			expect(handle.part:GetAttribute("Carcass")).to.equal(true)
			expect(handle.part.Anchored).to.equal(true)
			-- It TOPPLED before it anchored: the anchor waits for the body to stop, it does not freeze it
			-- mid-fall. This is Task 28's claim, still true.
			expect(math.abs(handle.part.CFrame.UpVector.Y) < 0.95).to.equal(true)
			local moved = shove(handle)
			TestKit.note(
				string.format("boar-model: flag OFF carcass anchored after %.2f s, shove moved %.4f studs", took, moved)
			)
			expect(moved < 0.1).to.equal(true)
			runtime:destroy()
		end)

		it("flag ON: a shove moves it less than a tenth of a stud, and it is still on the ground", function()
			local runtime, handle = readyBoar(true, Vector3.new(50, GROUND_Y, -40))
			expect(handle.part:FindFirstChild(MODEL.NAME)).to.be.ok()
			local took = killAndSettle(runtime, handle)
			expect(handle.part:GetAttribute("Carcass")).to.equal(true)
			expect(handle.part.Anchored).to.equal(true)
			-- ...and it did not freeze on its way down: the box's bottom is on the plate, which is where
			-- the death clip's own floor is.
			local bottom = handle.part.Position.Y - CONFIG.BODY_SIZE.Y / 2
			expect(math.abs(bottom - GROUND_Y) < 0.1).to.equal(true)
			local moved = shove(handle)
			TestKit.note(
				string.format(
					"boar-model: flag ON carcass anchored after %.2f s at bottom %.3f, shove moved %.4f studs",
					took,
					bottom,
					moved
				)
			)
			expect(moved < 0.1).to.equal(true)
			runtime:destroy()
		end)

		it("a LIVE boar is still unanchored, and still moves", function()
			-- The anchor must reach nothing but a carcass. A boar anchored while alive would stand in the
			-- field for ever and the drive would never end.
			local runtime, handle = readyBoar(true, Vector3.new(0, GROUND_Y, -40))
			step(runtime, 1 / 60, 30)
			expect(handle.part.Anchored).to.equal(false)
			runtime:destroy()
		end)

		it("the carcass still answers a ray exactly as it did", function()
			-- Anchoring touches no property a shot reads. `Damageable` is false because it is dead, which
			-- is Task 28's behaviour and not this fix's; the zone parts keep their `HitZone` and stay
			-- queryable, so a ray through a carcass lands where it always did.
			local runtime, handle = readyBoar(true, Vector3.new(-50, GROUND_Y, 40))
			killAndSettle(runtime, handle)
			expect(handle.part.Anchored).to.equal(true)
			expect(handle.part.CanQuery).to.equal(true)
			expect(handle.part.CanCollide).to.equal(true)
			expect(handle.part:GetAttribute("Damageable")).to.equal(false)
			expect(handle.part:GetAttribute("HitZone")).to.equal("body")
			local zones = 0
			for _, child in ipairs(handle.part:GetChildren()) do
				if child:IsA("BasePart") then
					zones += 1
					expect(child.CanQuery).to.equal(true)
					expect(child:GetAttribute("HitZone")).to.be.ok()
					-- The zone parts themselves stay unanchored: an anchored part welded into an assembly
					-- is `boar_zones.spec`'s own warning, and the trunk is what carries the anchor.
					expect(child.Anchored).to.equal(false)
				end
			end
			expect(zones).to.equal(#CONFIG.ZONES.ORDER)
			runtime:destroy()
		end)

		it("lets exactly ONE thing lay a carcass down", function()
			-- KAREN, 2026-10-10 ~21:20, the third playtest running: *"still after animal died it
			-- stands and stay still"*.
			--
			-- MEASURED on the client that draws them, over eight kills: seven lay on a flank (the
			-- spine's up vector 86-102 degrees off world up, the spine 0.00-0.25 of a body-length
			-- over the lowest hoof) and ONE stood at 4.9 degrees and 0.79 -- a LIVE standing boar's
			-- own numbers -- with no animation track playing on it at all. The clip is what lays a
			-- boar down, and a clip is not a guarantee: an Animator that never arrived, a
			-- `LoadAnimation` that failed, an id that is not published. In each of those the animal
			-- HAS a model, so the pre-150 rule left its box upright, and the model stood in its bind
			-- pose for the whole `CARCASS_SECONDS`.
			-- AND THE OTHER HALF, FROM THE OPPOSITE SIDE, measured on a real kill in the same runs: a
			-- carcass whose box had tumbled to -90.2 degrees under physics WHILE the paddle played
			-- drew its spine 4.4 degrees off world up -- a dead boar on its feet, made of two correct
			-- rotations composing. So exactly one of the two may do the falling.
			--
			-- A MODEL WITH A DEATH TRACK: the clip does it, and `Body.collapse` keeps the box's upright
			-- constraint ON -- so gravity still drops the carcass to the ground, as the case below
			-- waits for, but it can never add a second rotation to the clip's own.
			expect(Boar.boxFalls(true, true)).to.equal(false)
			-- NO MODEL AT ALL: the box does it, exactly as it has since task 28.
			expect(Boar.boxFalls(false, false)).to.equal(true)
			-- A MODEL WHOSE RIG HAS NO DEATH TRACK -- an Animator that never arrived, a
			-- `LoadAnimation` that failed, an id that is not published: the box does it. This is the
			-- row that was missing, and it is one of the two Karen has been photographing: before
			-- task 150 "there is a visual" was taken for "the clip will play", so nothing laid the
			-- animal down and it stood in its bind pose for the whole CARCASS_SECONDS.
			expect(Boar.boxFalls(true, false)).to.equal(true)
		end)

		it("says the death pose a second time, for a client that missed the first", function()
			-- THE OTHER HALF OF KAREN'S STANDING BOAR, and it is not the boar's decision at all.
			-- MEASURED over 60 kills in four runs, reading the drawn rig on the CLIENT and the same
			-- rig on the SERVER: every carcass lies down on the server -- the fall and the paddle
			-- playing on each -- and about one in ten stands on the CLIENT, with no animation track
			-- on it there and its box at the server's own angle. The client missed the one `Play`
			-- the death ever got, so it draws the bind pose, which is a boar standing up.
			local w = CONFIG.WOUND
			expect(Boar.shouldReassert(0, false, w)).to.equal(false)
			expect(Boar.shouldReassert(w.CARCASS_REASSERT_SECONDS - 0.01, false, w)).to.equal(false)
			expect(Boar.shouldReassert(w.CARCASS_REASSERT_SECONDS, false, w)).to.equal(true)
			-- ...ONCE, because re-playing a clip is only free while it is being HELD.
			expect(Boar.shouldReassert(60, true, w)).to.equal(false)
			-- ...AND ONLY ONCE BOTH DEATH CLIPS HAVE ENDED, which is what makes re-stating the pose
			-- invisible to a client that already has it: the track is held at its last frame, and it
			-- is put back on that same frame.
			local clips = CONFIG.MODEL.CLIPS
			local both = clips.deathLeft.seconds + clips.deathPaddleLeft.seconds
			expect(w.CARCASS_REASSERT_SECONDS > both).to.equal(true)
			-- ...and long before the carcass is taken off the board.
			expect(w.CARCASS_REASSERT_SECONDS < w.CARCASS_SECONDS).to.equal(true)
		end)

		it("decides to anchor on stillness, and on the backstop only when it is not falling", function()
			-- The pure rule, because a spec cannot make a physics body topple on command. The thresholds
			-- are 30x apart on purpose: a resting carcass measured 0.000-0.003 on both and one still
			-- toppling peaked at 28.6 linear and 5.6 angular in the same session.
			local w = CONFIG.WOUND
			local still = Vector3.new(0.003, 0, 0)
			local falling = Vector3.new(0, -20, 0)
			expect(Boar.carcassIsStill(still, 0.001, w)).to.equal(true)
			expect(Boar.carcassIsStill(Vector3.new(28.6, 0, 0), 0.001, w)).to.equal(false)
			expect(Boar.carcassIsStill(still, 5.6, w)).to.equal(false)
			-- Still for long enough: anchor.
			expect(Boar.shouldAnchorCarcass(still, w.CARCASS_STILL_SECONDS, 0.5, w)).to.equal(true)
			expect(Boar.shouldAnchorCarcass(still, w.CARCASS_STILL_SECONDS - 0.01, 0.5, w)).to.equal(false)
			-- The backstop: long enough since it died, and not falling.
			expect(Boar.shouldAnchorCarcass(still, 0, w.CARCASS_ANCHOR_BY_SECONDS, w)).to.equal(true)
			expect(Boar.shouldAnchorCarcass(falling, 0, w.CARCASS_ANCHOR_BY_SECONDS, w)).to.equal(false)
			-- ...and a body being SHOVED at the backstop is anchored anyway: stopping it is the point.
			expect(Boar.shouldAnchorCarcass(Vector3.new(9, 0, 0), 0, w.CARCASS_ANCHOR_BY_SECONDS, w)).to.equal(true)
			expect(w.CARCASS_ANCHOR_BY_SECONDS > 3).to.equal(true) -- boar_hit.spec allows the topple three
		end)

		-- ---------------------------------------------- the two pure rules of task 261, item 3
		--
		-- KAREN, 2026-10-25: *"one more thing deer run on road the fall and was sidding on side it's
		-- a bug / and now deer also hanging there hunted broken"*.
		it("takes the speed off a dead animal and leaves the fall alone (task 261)", function()
			local w = CONFIG.WOUND
			-- 0 TODAY: a shot animal drops where it is hit, which is the defect she reported said as
			-- a number.
			expect(w.COLLAPSE_KEEP_SPEED).to.equal(0)
			local running = Vector3.new(30, -4, -18)
			local stopped = Boar.collapseVelocity(running, w)
			expect(stopped.X).to.be.near(0, 1e-6)
			expect(stopped.Z).to.be.near(0, 1e-6)
			-- THE FALL IS KEPT WHATEVER THE DIAL SAYS: an animal shot mid-leap must still come down,
			-- and zeroing the fall would hold it up for a frame and then drop it.
			expect(stopped.Y).to.be.near(-4, 1e-6)
			-- ...AND AN UPWARD VELOCITY IS NOT A FALL. A body shot on the way up would otherwise
			-- carry on rising after it was dead.
			expect(Boar.collapseVelocity(Vector3.new(0, 25, 0), w).Y).to.be.near(0, 1e-6)
			-- THE DIAL IS REACHABLE BY PARAMETER, which is what lets Karen have a little carry back
			-- without this rule being rewritten.
			local half = table.clone(w)
			half.COLLAPSE_KEEP_SPEED = 0.5
			expect(Boar.collapseVelocity(running, half).X).to.be.near(15, 1e-6)
			-- A CONFIG WITH NO ROW AT ALL KEEPS EVERYTHING, which is this system before the task.
			local none = table.clone(w)
			none.COLLAPSE_KEEP_SPEED = nil
			expect(Boar.collapseVelocity(running, none).X).to.be.near(30, 1e-6)
		end)

		it("moves a settled carcass onto the ground, both ways, and refuses a wild answer (task 261)", function()
			local w = CONFIG.WOUND
			local tol = w.CARCASS_GROUND_TOLERANCE_STUDS
			-- ALREADY DOWN: terrain is voxelised and a fraction of a stud is noise (task 186
			-- measured 0.752 studs of it in one flat yard).
			expect(Boar.groundDrop(100, 100, w)).to.equal(0)
			expect(Boar.groundDrop(100, 100 + tol - 0.01, w)).to.equal(0)
			-- HANGING: the correction is the gap, and it is NEGATIVE because the body comes down.
			expect(Boar.groundDrop(100, 94, w)).to.be.near(-6, 1e-6)
			-- SUNK: the same defect upside down, which task 192 fixed four of.
			expect(Boar.groundDrop(100, 103, w)).to.be.near(3, 1e-6)
			-- PAST THE BOUND: NOTHING IS DONE. A reader answering 40 studs away is not answering
			-- about this body -- a column cast from the sky that found a canopy or a roof -- and
			-- moving a carcass on that number would be believing a measurement over the screen.
			expect(Boar.groundDrop(100, 100 - (w.CARCASS_GROUND_MAX_STUDS + 1), w)).to.equal(0)
			expect(Boar.groundDrop(100, 100 + w.CARCASS_GROUND_MAX_STUDS + 1, w)).to.equal(0)
			-- NOTHING KNOWN, NOTHING DONE: no reader, or a reader that found nothing under this
			-- point.
			expect(Boar.groundDrop(100, nil, w)).to.equal(0)
			-- THE RAY STARTS ABOVE THE BODY AND NOT IN THE SKY (`ForestTest.groundAt`'s `fromY`,
			-- task 192 round 2), so a canopy cannot answer a question about the ground.
			expect(w.CARCASS_GROUND_FROM_STUDS > 0).to.equal(true)
		end)
	end)

	describe("a frozen death costs nothing after it has frozen", function()
		-- REVIEW ROUND 1, FINDING 1. `clipFor` keeps answering "deathLeft, rate 1" for a dead boar while
		-- the frozen track sits at speed 0 on purpose, so `play`'s re-rate branch wrote `AdjustSpeed(1)`
		-- and the freeze wrote `AdjustSpeed(0)` back, EVERY FRAME, for `CARCASS_SECONDS` and up to
		-- `maxBoars` carcasses, on a server Animator whose every write replicates.
		--
		-- IT IS NOT OBSERVABLE FROM `AnimationTrack.Speed`: both writes landed inside one Heartbeat, so
		-- every sample read 0 and the live measurement saw a perfectly held pose. And it is not
		-- observable from a LIVE carcass in a spec either, because the freeze needs a loaded animation
		-- -- `shouldFreeze` refuses a `Length` of 0, which is every track in this file -- so the seam
		-- the writes are counted through is `Boar.shouldAdjustRate`, the decision `play` now asks.
		-- `Runtime:animationOf` carries the live counter for the measurement in the research note.
		local EPSILON = MODEL.RATE_EPSILON
		local DEATH = if MODEL.DEATH_TO_THE_LEFT then "deathLeft" else "deathRight"

		it("never re-rates the clip it is holding", function()
			-- The frozen death: speed 0, nominal rate 1, for ever.
			expect(Boar.shouldAdjustRate(DEATH, DEATH, 0, 1, EPSILON)).to.equal(false)
			-- ...and that is BECAUSE it is held, not because the numbers agree: the same track with
			-- nothing held is exactly the write the old code made 120 times a second.
			expect(Boar.shouldAdjustRate(nil, DEATH, 0, 1, EPSILON)).to.equal(true)
		end)

		it("a clip that is NOT held is still re-rated when the speed really changes", function()
			-- The fix must not freeze the living. A running gait whose rate has moved is still corrected,
			-- and one whose rate has barely moved is still left alone (`RATE_EPSILON`'s own job).
			expect(Boar.shouldAdjustRate(nil, "walk", 1.40, 1.76, EPSILON)).to.equal(true)
			expect(Boar.shouldAdjustRate(nil, "walk", 1.40, 1.41, EPSILON)).to.equal(false)
			-- Holding ONE clip does not silence another.
			expect(Boar.shouldAdjustRate(DEATH, "walk", 1.40, 1.76, EPSILON)).to.equal(true)
		end)

		it("a live boar is never holding a clip, and the counter is there to be read", function()
			-- `Runtime:animationOf` is the read-only seam the live measurement uses, the same shape
			-- `Runtime:woundOf` has. This asserts it answers, and that nothing holds a clip while the
			-- animal is alive.
			local runtime = newRuntime(true, makeTemplate(), FAKE_IDS)
			local handle = runtime:spawn(Vector3.new(-20, GROUND_Y, -50))
			step(runtime, 1 / 60, 10)
			local live = runtime:animationOf(handle.id)
			expect(live).to.be.ok()
			expect(live.heldClip).to.equal(nil)
			expect(live.collapsed).to.equal(false)
			expect(type(live.rateWrites)).to.equal("number")
			expect(runtime:animationOf("no such boar")).to.equal(nil)
			runtime:destroy()
		end)

		it("the freeze window is this repository's formula, not math.max in the spec", function()
			-- REVIEW ROUND 2, NOTE: the old case recomputed the window itself, so the production formula
			-- had no test at all. `Body.freezeReach` is what `stepVisual` calls.
			local epsilon = MODEL.HOLD_EPSILON
			local length = MODEL.CLIPS.deathLeft.seconds
			-- A normal 60 fps frame at rate 1 covers less than the epsilon, so the epsilon is the window.
			expect(Boar.freezeReach(1, 1 / 60, epsilon)).to.equal(epsilon)
			-- A 0.1 s hitch covers more, and the window grows with it -- which is the whole point.
			expect(Boar.freezeReach(1, 0.1, epsilon)).to.equal(0.1)
			-- A fast clip on the same frame covers more still; the sign of the speed does not matter.
			expect(Boar.freezeReach(2.2, 0.1, epsilon)).to.equal(0.1 * 2.2)
			expect(Boar.freezeReach(-1, 0.1, epsilon)).to.equal(0.1)
			-- Once frozen the speed is 0, so the window is the epsilon again and stays there.
			expect(Boar.freezeReach(0, 0.1, epsilon)).to.equal(epsilon)
			-- And the window is what decides: a death this close to its end is missed by the epsilon
			-- alone and caught once the frame's own reach is taken into account.
			expect(Boar.shouldFreeze(length - 0.06, length, 1, epsilon)).to.equal(false)
			expect(Boar.shouldFreeze(length - 0.06, length, 1, Boar.freezeReach(1, 0.1, epsilon))).to.equal(true)
		end)
	end)

	describe("the clip does not chatter", function()
		-- KAREN, 2026-10-03: "head shaking sometimes vierd". MEASURED over three 7-second windows on
		-- standing boars: up to 24 clip changes in 7 seconds, several lasting 0.03 s against a
		-- FADE_SECONDS of 0.15, THREE tracks playing at once all writing the same bones, and the head
		-- -- the end of the longest bone chain, so the biggest amplifier of their disagreement -- moving
		-- at up to 8.0 studs/s while the body's own speed was 0.0. Two causes, both fixed at the cause.
		local function clipWith(current: string?, heldFor: number, info)
			local filled = {
				collapsed = false,
				hitFor = 0,
				hitFromBehind = false,
				speed = 0,
				yawRate = 0,
				currentClip = current,
				heldFor = heldFor,
			}
			for key, value in pairs(info) do
				filled[key] = value
			end
			return Boar.clipFor(filled, CONFIG)
		end

		it("needs a real turn to start one, and a real stop to end it", function()
			expect((clipWith(nil, 10, { yawRate = MODEL.TURN_FROM_DEG - 1 }))).to.equal("idle")
			expect((clipWith(nil, 10, { yawRate = MODEL.TURN_FROM_DEG }))).to.equal("turnLeft")
			-- Already turning: it keeps turning well below the entry threshold...
			expect((clipWith("turnLeft", 10, { yawRate = MODEL.TURN_EXIT_DEG }))).to.equal("turnLeft")
			-- ...and only stops once the yaw has really decayed.
			expect((clipWith("turnLeft", 10, { yawRate = MODEL.TURN_EXIT_DEG - 1 }))).to.equal("idle")
			-- The band between the two is where the chatter lived: a yaw bouncing around 50 flips nothing.
			expect(MODEL.TURN_EXIT_DEG < MODEL.TURN_FROM_DEG).to.equal(true)
			expect((clipWith(nil, 10, { yawRate = 50 }))).to.equal("idle")
			expect((clipWith("turnLeft", 10, { yawRate = 50 }))).to.equal("turnLeft")
		end)

		it("will not replace a gait before its own crossfade has finished", function()
			-- The dwell, and it is why three tracks can no longer overlap.
			expect(MODEL.MIN_CLIP_SECONDS > MODEL.FADE_SECONDS).to.equal(true)
			expect((clipWith("idle", 0.0, { speed = CONFIG.SPRINT_SPEED }))).to.equal("idle")
			expect((clipWith("idle", MODEL.MIN_CLIP_SECONDS - 0.01, { speed = CONFIG.SPRINT_SPEED }))).to.equal("idle")
			expect((clipWith("idle", MODEL.MIN_CLIP_SECONDS, { speed = CONFIG.SPRINT_SPEED }))).to.equal("run")
		end)

		it("keeps following the speed with the RATE while a gait is held", function()
			-- The animal is held at the wrong GAIT for a fifth of a second, never at the wrong tempo: a
			-- walk clip held while the boar accelerates still speeds up with it, so the feet do not slide
			-- during the dwell either.
			local _, slow = clipWith("walk", 0.0, { speed = 4 })
			local _, fast = clipWith("walk", 0.0, { speed = 10 })
			expect(fast > slow).to.equal(true)
			expect(math.abs(slow - 4 / MODEL.CLIPS.walk.groundStudsPerSecond) < 1e-6).to.equal(true)
		end)

		it("rates a HELD gait by the animal's own stride, not the male's (task 139)", function()
			-- THE DWELL FORGOT `clipScale`, where every other rate in `Body.clipFor` includes it. A
			-- cub's stride is 0.4372 of a male's, so for the whole `MIN_CLIP_SECONDS` it played at
			-- 0.4372 of the rate it needed -- and the dwell is entered on EVERY gait change.
			local walk = MODEL.CLIPS.walk.groundStudsPerSecond
			local _, male = clipWith("walk", 0.0, { speed = 4 })
			local _, cub = clipWith("walk", 0.0, { speed = 4, clipScale = 0.4372 })
			expect(math.abs(male - 4 / walk) < 1e-6).to.equal(true)
			-- A SMALLER ANIMAL COVERS LESS GROUND PER STRIDE, so it has to step FASTER to keep up.
			expect(cub > male).to.equal(true)
			expect(math.abs(cub - 4 / (walk * 0.4372)) < 1e-6).to.equal(true)
		end)

		it("lets a flinch and a death through the dwell at once", function()
			-- These two must be instant: they are what a player is waiting to see after pulling the
			-- trigger, and a fifth of a second of politeness reads as the animal not reacting.
			-- Early in the flinch window, where a running animal still shows it (see the flinch case
			-- above: the window itself is shorter at speed since the task 116 fix round).
			local early = MODEL.HIT_SECONDS - MODEL.HIT_MOVING_SECONDS / 2
			expect((clipWith("run", 0.0, { hitFor = early, speed = CONFIG.SPRINT_SPEED }))).to.equal("hitFront")
			local want = if MODEL.DEATH_TO_THE_LEFT then "deathLeft" else "deathRight"
			expect((clipWith("run", 0.0, { collapsed = true, speed = CONFIG.SPRINT_SPEED }))).to.equal(want)
		end)

		it("cannot chatter: the measured yaw storm now produces one clip, not many", function()
			-- THE MEASUREMENT, REPLAYED. The live log's yaw swung -120..+173 deg/s on a standing animal;
			-- this feeds a sequence of that shape through the same decision with the dwell clock running
			-- and counts the changes. Every crossing used to be a change.
			local yaws = { 10, -40, 95, -30, 120, -110, 55, -70, 140, -20, 173, -120, 60, -50, 30 }
			local current, heldFor, changes = nil, 0.0, 0
			for _, yaw in ipairs(yaws) do
				local name = clipWith(current, heldFor, { yawRate = yaw })
				if name ~= current then
					changes += 1
					current, heldFor = name, 0.0
				else
					heldFor += 1 / 60
				end
			end
			TestKit.note(string.format("boar-model: the measured yaw storm now makes %d clip change(s)", changes))
			expect(changes <= 2).to.equal(true)
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
			-- NOT THE STATE THIS REPOSITORY IS IN ANY MORE -- the ten ids were published on
			-- 2026-10-03 and the describe below asserts all ten -- but it is still the state a server
			-- is in for the first moments of every session, and the state any FUTURE animal is in
			-- between its model landing and its clips being published. The boar is drawn, welded and
			-- textured, and it does not move its legs. Silence here would be the bug; nothing
			-- half-built is.
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
	describe("the display animal at the gathering lies dead on its side (task 173)", function()
		-- KAREN, 2026-10-13 ~09:30, verbatim: *"and after hunt over we need to see boars shooted not
		-- boxes when we stand around"*.
		--
		-- THE BAND IS TASK 150'S OWN MEASUREMENT, not a number this task chose: over eight kills on
		-- the client that draws them, seven carcasses on a flank measured their spine's up vector
		-- 86-102 degrees off world up, and the one that was standing measured 4.9. So a display that
		-- lands inside 86-104 is lying down by the same test the live carcass is judged by.
		local LYING_MIN_DEG = 86
		local LYING_MAX_DEG = 104
		-- HOW FAR THIS SPEC'S FAKE SPINE BONE IS TILTED AGAINST THE MESH IT HANGS ON. Negative, so
		-- the bone reads 90 + 8 = 98 degrees off world up where the mesh reads 90: inside the band,
		-- and far enough from the mesh's own figure that the two cannot be the same measurement
		-- (round 1, note). A real rig's spine is tilted against the body in exactly this way.
		local BONE_TILT_DEG = -8

		-- The three kinds' MEASURED mesh sizes, from `Assets.ROWS` (`boar.male` v3, `boar.female`,
		-- `boar.cub`, each read in Studio off the loaded asset). Written out here rather than
		-- required, so the expectations below are an INDEPENDENT expression of the arithmetic and not
		-- the code under test restated.
		local KIND_SIZE = {
			male = Vector3.new(1.4011, 3.2573, 5.5),
			female = Vector3.new(1.202, 2.647, 4.675),
			cub = Vector3.new(0.618, 1.439, 2.475),
		}
		-- ...and half of each one's X, which is the vertical half-extent once it has been rolled a
		-- quarter turn: that is the whole of "resting ON the ground".
		local KIND_LIFT = { male = 0.70055, female = 0.601, cub = 0.309 }

		-- A template per kind, each at that kind's own measured size, so "size by kind" is provable
		-- without the network. The shape is `makeTemplate`'s -- the nesting and the asset's own
		-- AnimationController included, because the display has to strip that.
		local function kindTemplate(kind: string): Model
			local model = Instance.new("Model")
			model.Name = "FakeBoar_" .. kind
			local inner = Instance.new("Model")
			inner.Name = "Boar " .. kind .. " RedDeer"
			local mesh = Instance.new("MeshPart")
			mesh.Name = "Boar_" .. kind
			mesh.Size = KIND_SIZE[kind]
			mesh.Anchored = false
			mesh.CanQuery = true
			mesh.CanCollide = true
			mesh.CanTouch = true
			mesh.Massless = false
			-- THE RIG'S OWN BONE, which is what the lying check is measured off: `Bone` is an
			-- `Attachment`, so its `WorldCFrame` follows the part it hangs on, and its up vector IS
			-- the spine's up vector for a rig in its bind pose.
			--
			-- AND IT IS NOT THE MESH'S OWN FRAME (round 1, note, which was right): with the default
			-- identity `CFrame` the bone's `WorldCFrame` IS the mesh's, so the bone assertion could
			-- only fail where the mesh assertion already had. A real spine bone sits inside the
			-- animal and is tilted against it, so this one is: moved up and forward, and rolled
			-- `BONE_TILT_DEG` about the mesh's own forward axis -- which is the one axis that changes
			-- how far off world up the bone points once the animal is on its side. The lying band is
			-- then a statement about the BONE's angle, and it is a different number from the mesh's.
			local bone = Instance.new("Bone")
			bone.Name = "spine_01"
			bone.CFrame = CFrame.new(0, 0.35, -0.6) * CFrame.Angles(0, 0, math.rad(BONE_TILT_DEG))
			bone.Parent = mesh
			mesh.Parent = inner
			local theirs = Instance.new("AnimationController")
			theirs.Parent = inner
			inner.PrimaryPart = mesh
			inner.Parent = model
			model.PrimaryPart = mesh
			model.Parent = testRoot
			return model
		end

		local function runtimeWithKinds()
			local runtime = Boar.newRuntime(buildWorld(true))
			local templates = {}
			for kind in pairs(KIND_SIZE) do
				templates[kind] = kindTemplate(kind)
			end
			runtime:setModelSource(function(kind: string)
				return templates[kind]
			end, nil)
			return runtime, templates
		end

		-- The angle between a CFrame's own up vector and world up, in degrees. One expression, used
		-- for the mesh and for the bone, so the two cannot be measured differently.
		local function degOffUp(cframe: CFrame): number
			return math.deg(math.acos(math.clamp(cframe.UpVector:Dot(Vector3.yAxis), -1, 1)))
		end

		it("rolls the real model onto its RIGHT side, on the ground, facing the way it was told", function()
			local runtime = runtimeWithKinds()
			-- The scene hands in a GROUND frame: a point on the floor and the direction the row
			-- faces. This is `Scene.rowLayout`'s own output shape.
			local at = Vector3.new(12, GROUND_Y, -30)
			local look = Vector3.new(0, 0, 1)
			local ground = CFrame.lookAt(at, at + look)
			local display = runtime:displayCarcass("male", ground)
			expect(display).to.be.ok()
			-- UNPARENTED: the scene is the one thing that decides where this lives, and it destroys
			-- it with its own folder.
			expect(display.Parent).to.equal(nil)
			local mesh = display.PrimaryPart
			expect(mesh).to.be.ok()
			expect(mesh:IsA("MeshPart")).to.equal(true)
			-- THE NAME THE BOAR GIVES IT, which is what it is called for as long as the scene has not
			-- renamed it into its row (round 1, note: nothing asserted this key at all).
			expect(display.Name).to.equal(CONFIG.MODEL.DISPLAY_NAME)

			-- LYING, by task 150's own band, measured off the MESH and off the rig's own BONE.
			local meshDeg = degOffUp(mesh.CFrame)
			local bone = mesh:FindFirstChildWhichIsA("Bone")
			expect(bone).to.be.ok()
			local boneDeg = degOffUp(bone.WorldCFrame)
			expect(meshDeg >= LYING_MIN_DEG and meshDeg <= LYING_MAX_DEG).to.equal(true)
			expect(boneDeg >= LYING_MIN_DEG and boneDeg <= LYING_MAX_DEG).to.equal(true)
			-- ...AND THE BONE IS ITS OWN MEASUREMENT (round 1, note): it is tilted against the mesh,
			-- so a bone assertion that merely restated the mesh's would show up here as zero.
			expect(math.abs(boneDeg - meshDeg) > 1).to.equal(true)
			expect(math.abs(boneDeg - (meshDeg - BONE_TILT_DEG)) < 1e-3).to.equal(true)

			-- ON ITS RIGHT SIDE, which is the tradition's own rule (jagdjuenger.de: *"Jedes Stueck
			-- Wild ist stets auf die rechte Koerperseite zu legen"*): the animal's up vector ends up
			-- pointing along the row frame's RIGHT, so the right flank is the one on the floor.
			expect(mesh.CFrame.UpVector:Dot(ground.RightVector) > 0.99).to.equal(true)

			-- STILL FACING THE WAY THE ROW FACES: a roll about the forward axis cannot change where
			-- the nose points, and that is what makes a row read as a row.
			expect((mesh.CFrame.LookVector - ground.LookVector).Magnitude < 1e-3).to.equal(true)

			-- ON the ground, not in it and not hovering. Rolled a quarter turn the mesh's X is its
			-- vertical extent, so its lowest point is half of that below its centre.
			local bottom = mesh.Position.Y - KIND_LIFT.male
			expect(math.abs(bottom - at.Y) < 1e-3).to.equal(true)
			-- ...and it is where it was put, sideways.
			expect(math.abs(mesh.Position.X - at.X) < 1e-3).to.equal(true)
			expect(math.abs(mesh.Position.Z - at.Z) < 1e-3).to.equal(true)

			TestKit.note(
				string.format(
					"boar-model: display mesh %.1f deg off up, bone %.1f deg, bottom %.4f of the ground",
					meshDeg,
					boneDeg,
					bottom - at.Y
				)
			)
			runtime:destroy()
		end)

		it("cannot be shot, shoved or stepped: it is scenery", function()
			local runtime = runtimeWithKinds()
			local display = runtime:displayCarcass("female", CFrame.new(0, GROUND_Y, 0))
			expect(display).to.be.ok()
			local parts = 0
			for _, descendant in ipairs(display:GetDescendants()) do
				if descendant:IsA("BasePart") then
					parts += 1
					-- A RAY MUST NEVER MEET IT: what a shot hit is what the safety rule and the hit
					-- record read, which is the one property in this folder that is not tidiness.
					expect(descendant.CanQuery).to.equal(false)
					expect(descendant.CanCollide).to.equal(false)
					expect(descendant.CanTouch).to.equal(false)
					-- ANCHORED, so nothing can shove the bag out of its row -- the same complaint
					-- Karen made about live carcasses ("it has to stay in same place without move").
					expect(descendant.Anchored).to.equal(true)
					expect(descendant.Massless).to.equal(true)
				end
			end
			expect(parts >= 1).to.equal(true)
			-- NOTHING TO ANIMATE IT, and the ASSET BRINGS ONE: Roblox's importer writes an
			-- AnimationController into these models, and a rig nothing ever steps must not keep one
			-- -- the pose has exactly one author (task 150's rule, applied to a thing that is never
			-- stepped).
			expect(display:FindFirstChildWhichIsA("AnimationController", true)).to.equal(nil)
			expect(display:FindFirstChildWhichIsA("Animator", true)).to.equal(nil)
			runtime:destroy()
		end)

		it("draws each kind from its OWN asset, at its own size", function()
			-- Karen's bag is male, female and cub, and a cub in the row has to be a cub. There is one
			-- route from a kind to an asset in the server (`Runtime:_modelTemplate` ->
			-- `BoarAssetsBoot`'s MODEL_KEYS -> `Assets.KEYS`), and this is that route with the
			-- network replaced.
			local runtime = runtimeWithKinds()
			for _, kind in ipairs({ "male", "female", "cub" }) do
				local ground = CFrame.new(0, GROUND_Y, 0)
				local display = runtime:displayCarcass(kind, ground)
				expect(display).to.be.ok()
				local mesh = display.PrimaryPart
				expect((mesh.Size - KIND_SIZE[kind]).Magnitude < 1e-3).to.equal(true)
				-- ...and each one rests on the ground at ITS own half-width, which is why no per-kind
				-- number is written down anywhere: it is read off the mesh.
				expect(math.abs((mesh.Position.Y - KIND_LIFT[kind]) - GROUND_Y) < 1e-3).to.equal(true)
			end
			-- NO KIND AT ALL GETS THE DEFAULT, which is the male: a kill record from a world with
			-- `KINDS` off carries no kind, and that is the state every animal was in before task 119.
			local noKind = runtime:displayCarcass(nil, CFrame.new(0, GROUND_Y, 0))
			expect(noKind).to.be.ok()
			expect((noKind.PrimaryPart.Size - KIND_SIZE.male).Magnitude < 1e-3).to.equal(true)
			-- ...AND AN UNKNOWN KIND IS THE SOURCE'S BUSINESS AND NOT THE RUNTIME'S, which is where
			-- that rule has always lived: `BoarAssetsBoot` maps a kind through `MODEL_KEYS[kind] or
			-- Assets.KEYS.boarMale`, so the live server answers the male for anything it does not
			-- know. A source with no row for it -- this spec's -- answers nothing, and nothing means
			-- the grey box. The runtime does not invent a kind in either case, which is what keeps
			-- ONE route from a kind to an asset id.
			expect(runtime:displayCarcass("red deer", CFrame.new(0, GROUND_Y, 0))).to.equal(nil)
			runtime:destroy()
		end)

		it("answers nil for every world that cannot draw one, so the caller keeps its grey box", function()
			-- NO MODEL SOURCE AT ALL -- the flag off, the asset not published, the loader still
			-- fetching. This is the state the scene's grey box exists for, and it is a state and not
			-- a fault.
			local bare = newRuntime(true, nil, nil)
			expect(bare:displayCarcass("male", CFrame.new(0, GROUND_Y, 0))).to.equal(nil)
			bare:destroy()

			-- `BOAR_MODEL` OFF, asked of THIS function rather than left to the fact that a flag-off
			-- world never wires a source (round 1, note). Three comments in this repository state it
			-- as a property of `displayCarcass`; this is the case that makes them true.
			local off = newRuntime(false, makeTemplate(), nil)
			expect(off:displayCarcass("male", CFrame.new(0, GROUND_Y, 0))).to.equal(nil)
			off:destroy()

			-- A TEMPLATE THAT IS NOT ONE MESH: two MeshParts is a different asset than the row
			-- describes, and `Body.attachVisual` already refuses it for the same reason.
			local twoMeshes = Instance.new("Model")
			local first = Instance.new("MeshPart")
			first.Size = KIND_SIZE.male
			first.Parent = twoMeshes
			local second = Instance.new("MeshPart")
			second.Size = KIND_SIZE.male
			second.Parent = twoMeshes
			twoMeshes.Parent = testRoot
			local twoRuntime = newRuntime(true, twoMeshes, nil)
			expect(twoRuntime:displayCarcass("male", CFrame.new(0, GROUND_Y, 0))).to.equal(nil)
			twoRuntime:destroy()

			-- ...AND A TEMPLATE WITH NO MESH IN IT AT ALL.
			local empty = Instance.new("Model")
			empty.Parent = testRoot
			local emptyRuntime = newRuntime(true, empty, nil)
			expect(emptyRuntime:displayCarcass("male", CFrame.new(0, GROUND_Y, 0))).to.equal(nil)
			emptyRuntime:destroy()
		end)

		it("works out the lying height as arithmetic, for any angle and any asset", function()
			-- PURE, so the one number standing between an animal on the grass and one sunk into it is
			-- a test case rather than a screenshot. `lyingHalfHeight` is half the VERTICAL extent of
			-- a box rolled by `rollDeg`, which at a quarter turn is half its width.
			local roll = CONFIG.MODEL.DISPLAY_ROLL_DEG
			expect(math.abs(roll)).to.equal(90)
			for kind, size in pairs(KIND_SIZE) do
				expect(math.abs(Boar.lyingHalfHeight(size, roll) - KIND_LIFT[kind]) < 1e-3).to.equal(true)
				-- NOT ROLLED AT ALL is half its HEIGHT, which is the standing animal: the function is
				-- the general one, so the roll can be tuned to prop an animal up without a second
				-- expression of this arithmetic appearing anywhere.
				expect(math.abs(Boar.lyingHalfHeight(size, 0) - size.Y / 2) < 1e-6).to.equal(true)
			end
			-- AND THE WHOLE CFRAME: the ground frame, lifted, then rolled -- in that order, so the
			-- lift is vertical in the WORLD and not along the animal's own side.
			local ground = CFrame.lookAt(Vector3.new(5, GROUND_Y, 5), Vector3.new(5, GROUND_Y, 6))
			local placed = Boar.lyingCFrame(ground, KIND_SIZE.cub, roll)
			expect(math.abs(placed.Position.Y - (GROUND_Y + KIND_LIFT.cub)) < 1e-3).to.equal(true)
			expect(degOffUp(placed) > LYING_MIN_DEG).to.equal(true)
		end)
	end)

	-- ------------------------------ THE BACKSTOP THAT WAS NEVER THERE (task 249)
	--
	-- KAREN, 2026-10-23: *"bug with dead boar standing"* -- the fourth time this has reached her
	-- (L-010: boars x3, and task 150's own count before that).
	--
	-- THE CAUSE, FOUND BY GREP AND NOT BY GUESS: `Body.topple`'s comment has said since task 150
	-- that it is called *"from exactly two places -- the collapse, and the backstop in
	-- `stepCarcass`"*, and `grep -rn "Body.topple" src/` finds **one** caller. So when
	-- `Body.boxFalls` answers false the `AlignOrientation` is left ON on purpose and the ONLY thing
	-- that can lay the animal down is the death clip really playing -- and
	-- `Animator:LoadAnimation` hands back a track for an asset that has not downloaded, which
	-- `trackFor` cannot tell apart from a loaded one.
	describe("a dead animal is laid down even when its clip never runs (task 249)", function()
		local WOUND = CONFIG.WOUND

		it("asks the one question that separates a clip that runs from one that does not", function()
			-- `TimePosition` AND NOT `IsPlaying`: a track on an asset that has not arrived reports
			-- `IsPlaying = true` and applies nothing.
			expect(Boar.deathDrawn(0.4, 1.167)).to.equal(true)
			expect(Boar.deathDrawn(0, 1.167)).to.equal(false)
			-- NO LENGTH IS NO ASSET, whatever the clock says.
			expect(Boar.deathDrawn(0.4, 0)).to.equal(false)
			expect(Boar.deathDrawn(nil, nil)).to.equal(false)
		end)

		it("fires only for a carcass that is armed, still upright and past the wait", function()
			expect(Boar.shouldBackstopDeath(2.0, true, false, false, WOUND)).to.equal(true)
			-- THE CLIP RAN: nothing to rescue.
			expect(Boar.shouldBackstopDeath(2.0, true, true, false, WOUND)).to.equal(false)
			-- THE BOX ALREADY TOPPLED IT at the moment of death (`Body.boxFalls` true), and rolling
			-- it a second time would stand it back up on its other side -- task 150's own defect.
			expect(Boar.shouldBackstopDeath(2.0, true, false, true, WOUND)).to.equal(false)
			-- NOTHING WAS PROMISED: no visual, or no track at all. `collapse` never arms it.
			expect(Boar.shouldBackstopDeath(2.0, false, false, false, WOUND)).to.equal(false)
			-- ...AND IT WAITS. A death that is really playing is well past its first frame by
			-- `DEATH_BACKSTOP_SECONDS`, and nothing is rolled before then.
			expect(Boar.shouldBackstopDeath(WOUND.DEATH_BACKSTOP_SECONDS - 0.01, true, false, false, WOUND)).to.equal(
				false
			)
			expect(Boar.shouldBackstopDeath(WOUND.DEATH_BACKSTOP_SECONDS, true, false, false, WOUND)).to.equal(true)
			-- A WORLD WITH NO BACKSTOP NUMBER IS THE BEHAVIOUR BEFORE THIS TASK, EXACTLY.
			local without = table.clone(WOUND)
			without.DEATH_BACKSTOP_SECONDS = nil
			expect(Boar.shouldBackstopDeath(60, true, false, false, without)).to.equal(false)
		end)

		-- ------------------------------ AND THE BEHAVIOUR, NOT ONLY THE ARITHMETIC
		--
		-- THE THREE CASES ABOVE ARE PURE PREDICATES AND THAT IS NOT ENOUGH (Learning Agent L-028):
		-- a predicate that answers correctly proves nothing about the carcass in the world unless
		-- something calls it. This case drives the REAL `Body.stepCarcass` on a REAL body the
		-- runtime spawned, with the one state that produced Karen's defect -- `collapsed`, the
		-- upright constraint still ON because `boxFalls` answered false, and a death track that
		-- never advances because its asset never arrived.
		--
		-- THE TRACK IS A STAND-IN AND IT HAS TO BE. The thing being reproduced is an asset that has
		-- not downloaded; there is no way to ask Roblox for one on demand, and `trackFor` cannot
		-- tell it from a loaded one -- which is the whole defect. A table with the two fields the
		-- backstop reads IS that state, exactly.
		--
		-- IT WAS SHOWN FAILING ON THE CODE BEFORE THE FIX, AND THAT IS THE POINT OF IT (L-028).
		-- The backstop block was taken back out of `Body.stepCarcass`, the suite re-run against the
		-- live place, and this is what came back:
		--
		--   failed [server] boar_model.spec:1785 Expected value "true" (boolean), got "false"
		--   failed [server] boar_model.spec:1814 Expected value "nil", got "table: ..."
		--
		-- Line 1785 is `expect(handle.toppled).to.equal(true)`: **the carcass stands**, which is
		-- Karen's defect, reproduced by the suite rather than argued from a grep. The block was put
		-- straight back (`git checkout`) and the same run goes green.
		describe("the carcass in the world, not only the arithmetic", function()
			local Body = require(ServerScriptService:WaitForChild("Boar"):WaitForChild("Body"))
			local bodies: { any } = {}

			-- A REAL BODY, built by the real constructor into this spec's own folder -- the trunk,
			-- its `Mover` and its `Upright` exactly as a spawned animal has them. `Body.create` is
			-- what `Runtime:spawn` calls; `runtime:spawn` hands back a PUBLIC handle that has no
			-- `upright` and no `collapsed`, so this takes the body itself.
			local function newBody()
				local made = Body.create(
					Boar.kindConfig("male", CONFIG),
					testRoot,
					string.format("Carcass%d", #bodies + 1),
					Vector3.new(30, GROUND_Y + 4, 30),
					"male"
				)
				table.insert(bodies, made)
				return made
			end

			-- THE ONE STATE THAT PRODUCED KAREN'S DEFECT: collapsed, the upright constraint still
			-- ON because `Body.boxFalls` answered false, and a death track whose asset never
			-- arrived. The track is a STAND-IN and it has to be -- there is no way to ask Roblox
			-- for an asset that will not download, and `trackFor` cannot tell one from a loaded
			-- one, which is the whole defect. A table with the two fields the backstop reads IS
			-- that state.
			local function deadWithTrack(handle, timePosition: number, length: number)
				local stopped = { n = 0 }
				handle.collapsed = true
				handle.toppled = false
				-- `deadFor` IS `stepVisual`'S CLOCK AND THE BACKSTOP NO LONGER READS IT (round 1,
				-- finding 1): `collapsedFor` is `stepCarcass`'s own. Set here anyway, so a case
				-- that leans on the old one would be caught rather than quietly pass.
				handle.deadFor = CONFIG.WOUND.DEATH_BACKSTOP_SECONDS + 0.5
				handle.part.Anchored = false
				handle.upright.Enabled = true
				handle.deathTrack = {
					TimePosition = timePosition,
					Length = length,
					Stop = function(_self)
						stopped.n += 1
					end,
				}
				return stopped
			end

			afterEach(function()
				for _, handle in ipairs(bodies) do
					Body.destroy(handle)
				end
				table.clear(bodies)
			end)

			-- ------------------------------ THE REAL SEQUENCE, AND ROUND 1 IS WHY (finding 2)
			--
			-- THE CASE BELOW HAND-WRITES `deadFor` PAST THE BACKSTOP AND `Anchored = false`, AND
			-- THAT IS A STATE THE GAME DOES NOT REACH. The Reviewer: *"the production path reaches
			-- `deadFor` 1.5 only while the body is still being moved, because
			-- `stillFor >= CARCASS_STILL_SECONDS` (0.25) has anchored it long before"*. So it
			-- could not fail on the defect it was written for.
			--
			-- THIS ONE STEPS THE CLOCK THE WAY THE RUNTIME DOES: one collapse, then
			-- `Body.stepCarcass` over and over at a real `dt`, letting the function anchor the
			-- body itself and letting its own `collapsedFor` carry the time. It asserts the
			-- anchoring really happened -- the mechanism the finding names -- and then that the
			-- carcass was laid down anyway.
			it("lays the carcass down on the real sequence, through the anchoring (round 1, finding 1)", function()
				local handle = newBody()
				local stopped = deadWithTrack(handle, 0, 0)
				-- FROM A FRESH COLLAPSE, not from a hand-written clock.
				handle.collapsedFor = 0
				handle.deadFor = 0
				handle.stillFor = 0
				handle.part.AssemblyLinearVelocity = Vector3.zero
				local before = handle.part.CFrame
				local anchoredOnTheWay = false
				local steps = math.ceil((CONFIG.WOUND.DEATH_BACKSTOP_SECONDS + 0.5) / 0.1)
				for _ = 1, steps do
					Body.stepCarcass(handle, 0.1, CONFIG.WOUND)
					if handle.part.Anchored then
						anchoredOnTheWay = true
					end
				end
				-- THE MECHANISM THE FINDING NAMES, ASSERTED: a carcass nothing is moving IS
				-- anchored inside a quarter of a second, long before the backstop is due.
				expect(anchoredOnTheWay).to.equal(true)
				-- ...AND IT WAS LAID DOWN ANYWAY. Run against the round-1 `stepCarcass` this case
				-- reported `boar_model.spec:1824 Expected value "true" (boolean), got "false"
				-- (boolean)` on the line below -- WITH the `anchoredOnTheWay` assertion above it
				-- PASSING, which is the Reviewer's finding 1 reproduced by the suite: the body is
				-- anchored on time and the carcass stands anyway.
				expect(handle.toppled).to.equal(true)
				expect(handle.backstopped).to.equal(true)
				expect(handle.part.CFrame).never.to.equal(before)
				expect(handle.upright.Enabled).to.equal(false)
				expect(stopped.n).to.equal(1)
				-- ...AND IT IS ANCHORED AGAIN once it has settled on its side, which is what the
				-- anchor is for: the un-anchoring is a moment, not a new state.
				for _ = 1, 40 do
					handle.part.AssemblyLinearVelocity = Vector3.zero
					Body.stepCarcass(handle, 0.1, CONFIG.WOUND)
				end
				expect(handle.part.Anchored).to.equal(true)
			end)

			it("lays a standing carcass down when its death clip never advanced", function()
				local handle = newBody()
				local before = handle.part.CFrame
				local stopped = deadWithTrack(handle, 0, 0)
				handle.collapsedFor = CONFIG.WOUND.DEATH_BACKSTOP_SECONDS + 0.5
				Body.stepCarcass(handle, 0.1, CONFIG.WOUND)
				-- THE BOX ROLLED, which is the one CFrame write that lets gravity do the rest.
				expect(handle.toppled).to.equal(true)
				expect(handle.part.CFrame).never.to.equal(before)
				-- ...AND THE CONSTRAINT LET GO FIRST, or `AlignOrientation` would pull it straight
				-- back upright -- `Body.collapse`'s own order for the box-falls case.
				expect(handle.upright.Enabled).to.equal(false)
				-- ...AND THE TRACK WAS STOPPED, so a late download cannot apply a second rotation
				-- behind its back (task 150's buried-upside-down carcass).
				expect(stopped.n).to.equal(1)
				expect(handle.deathTrack).to.equal(nil)
				expect(handle.backstopped).to.equal(true)
				-- ONCE. A second step cannot roll the same carcass again and stand it back up.
				local after = handle.part.CFrame
				Body.stepCarcass(handle, 0.1, CONFIG.WOUND)
				expect(handle.part.CFrame).to.equal(after)
				expect(stopped.n).to.equal(1)
			end)

			it("leaves a carcass whose clip IS running completely alone", function()
				local handle = newBody()
				local before = handle.part.CFrame
				local stopped = deadWithTrack(handle, 0.4, MODEL.CLIPS.deathLeft.seconds)
				handle.collapsedFor = CONFIG.WOUND.DEATH_BACKSTOP_SECONDS + 0.5
				Body.stepCarcass(handle, 0.1, CONFIG.WOUND)
				expect(handle.toppled).to.equal(false)
				expect(handle.part.CFrame).to.equal(before)
				-- THE CLIP IS DOING THE FALLING, so the constraint stays on exactly as
				-- `Body.collapse` left it -- the two rotations must never compose.
				expect(handle.upright.Enabled).to.equal(true)
				expect(stopped.n).to.equal(0)
				-- ...AND NOTHING IS WATCHED ANY MORE: the promise was kept.
				expect(handle.deathTrack).to.equal(nil)
				expect(handle.backstopped).to.equal(false)
			end)

			it("does not touch a carcass the box already toppled at the moment of death", function()
				local handle = newBody()
				local stopped = deadWithTrack(handle, 0, 0)
				handle.toppled = true
				handle.upright.Enabled = false
				handle.collapsedFor = CONFIG.WOUND.DEATH_BACKSTOP_SECONDS + 0.5
				local before = handle.part.CFrame
				handle.part.Anchored = true
				Body.stepCarcass(handle, 0.1, CONFIG.WOUND)
				expect(handle.part.CFrame).to.equal(before)
				expect(stopped.n).to.equal(0)
				expect(handle.backstopped).to.equal(false)
			end)

			-- ------------------------------ PRODUCTION ARMS IT (TASKS.md row 249b, note (i))
			--
			-- *"The one wire from production into the death backstop is asserted nowhere:
			-- `handle.deathTrack = deathTrack` in `Body.collapse` is the only thing that arms it, and
			-- all four new cases hand-write the track, so deleting that line leaves the whole suite
			-- green and the backstop dead in production."*
			--
			-- `trackFor` RETURNS A CACHED TRACK BEFORE IT ASKS FOR AN ANIMATOR, so seeding
			-- `handle.tracks` is the real wire with the one thing no spec can have -- a downloaded
			-- asset -- standing in for itself. The same stand-in the four cases above use, and for
			-- the same stated reason.
			it("arms the backstop from `Body.collapse` itself, and not on the box-falls path", function()
				local fall = Body.deathClips(CONFIG)
				local handle = newBody()
				-- A VISUAL AND A LOADABLE DEATH CLIP: `Body.boxFalls` answers false, so the clip is
				-- the only thing that can lay this animal down and the backstop must be watching it.
				local model = Instance.new("Model")
				model.Parent = testRoot
				handle.visual = model
				handle.tracks[fall] = { TimePosition = 0, Length = MODEL.CLIPS[fall].seconds }
				Body.collapse(handle, CONFIG.WOUND, CONFIG)
				expect(handle.deathTrack).to.be.ok()
				expect(handle.toppled).to.equal(false)
				expect(handle.upright.Enabled).to.equal(true)
				model:Destroy()
				-- ...AND NOTHING IS WATCHED ON THE BOX-FALLS PATH: the box has already rolled it, so
				-- a backstop here would roll it a second time and stand it back up.
				local plain = newBody()
				Body.collapse(plain, CONFIG.WOUND, CONFIG)
				expect(plain.deathTrack).to.equal(nil)
				expect(plain.toppled).to.equal(true)
			end)

			-- ------------------------------ AND THE PADDLE IS A DEATH TOO (row 249b, note (ii))
			--
			-- *"`deathDrawn` watches only the FALL track -- in a world where `deathLeft`'s id never
			-- downloads but `deathPaddleLeft`'s does, `clipFor` plays the paddle from 1.167 s and the
			-- box still rolls at 1.5 s: the two rotations composing, which is task 150's
			-- buried-upside-down carcass"* -- the exact shape of Karen's *"deer also hanging there
			-- hunted broken"*.
			it("leaves a carcass alone when the PADDLE is the clip that is running (task 261)", function()
				local fall, paddle = Body.deathClips(CONFIG)
				local handle = newBody()
				local stopped = deadWithTrack(handle, 0, 0) -- the FALL never advanced
				-- ...AND THE PADDLE IS WHAT IS ON THE RIG, advancing. `handle.clip` is what `play`
				-- last started, which is the one fact that says WHICH clip is drawing this animal.
				handle.clip = paddle
				-- THE TWO NAMES ARE THE HANDLE'S AND ARE WRITTEN BY `Body.collapse` (which is the one
				-- place that holds the whole config), so a case that hand-writes the track writes
				-- them too -- the `deadWithTrack` stand-in's own discipline.
				handle.deathClipNames = { fall, paddle }
				handle.tracks[paddle] = { TimePosition = 0.5, Length = MODEL.CLIPS[paddle].seconds }
				handle.collapsedFor = CONFIG.WOUND.DEATH_BACKSTOP_SECONDS + 0.5
				local before = handle.part.CFrame
				Body.stepCarcass(handle, 0.1, CONFIG.WOUND)
				-- THE BOX DID NOT ROLL. Before this task it did, on top of a running paddle.
				expect(handle.toppled).to.equal(false)
				expect(handle.part.CFrame).to.equal(before)
				expect(handle.upright.Enabled).to.equal(true)
				expect(handle.backstopped).to.equal(false)
				expect(stopped.n).to.equal(0)
				-- ...AND NOTHING IS WATCHED NOW: the promise was kept, by the paddle.
				expect(handle.deathTrack).to.equal(nil)
				expect(Body.deathTrackOn(handle)).to.equal(handle.tracks[paddle])
				-- A CLIP THAT IS NOT A DEATH DOES NOT ANSWER THE QUESTION: the fall track is what
				-- the backstop watches when nothing is drawing the death.
				handle.clip = "walk"
				handle.deathTrack = handle.tracks[fall]
				expect(Body.deathTrackOn(handle)).to.equal(handle.tracks[fall])
			end)

			-- ------------------------------ AND THE LIFT IS PAID BACK (task 261, item 3)
			--
			-- A CALF'S `deathLiftStuds` IS 1.325 AND THE BACKSTOP NEVER GAVE IT BACK. `Body.collapse`
			-- moves everything drawn UP by that much so the death clip's own overshoot lands the rig
			-- on the ground -- and the backstop firing is the statement that the clip never ran, so
			-- nothing cancelled it: the mesh floated for the whole `CARCASS_SECONDS` 120.
			it("gives the death lift back when the box has to lay the animal down (task 261)", function()
				local fall = Body.deathClips(CONFIG)
				local handle = newBody()
				-- A DRAWN MODEL WITH ONE WELDED PART, which is what `liftDrawn` moves: it disables
				-- every weld, moves every part and enables them again.
				local model = Instance.new("Model")
				local drawn = Instance.new("Part")
				drawn.Size = Vector3.new(1, 1, 1)
				drawn.Anchored = false
				drawn.CFrame = handle.part.CFrame
				drawn.Parent = model
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = drawn
				weld.Part1 = handle.part
				weld.Parent = drawn
				model.Parent = testRoot
				handle.visual = model
				-- A LIFT TO GIVE BACK, and it is A CALF'S OWN NUMBER rather than a round one.
				local lift = CONFIG.KINDS.calf.deathLiftStuds
				expect(lift > 1).to.equal(true)
				local at = drawn.Position.Y
				Body.liftDrawn(handle, lift)
				handle.liftedBy = lift
				expect(drawn.Position.Y - at).to.be.near(lift, 1e-3)
				-- NOW THE CLIP NEVER RUNS AND THE BACKSTOP FIRES.
				deadWithTrack(handle, 0, 0)
				handle.tracks[fall] = handle.deathTrack
				handle.collapsedFor = CONFIG.WOUND.DEATH_BACKSTOP_SECONDS + 0.5
				Body.stepCarcass(handle, 0.1, CONFIG.WOUND)
				expect(handle.backstopped).to.equal(true)
				expect(handle.liftedBy).to.equal(0)
				model:Destroy()
			end)

			-- ------------------------------ AND IT LIES **ON** THE GROUND (task 261, item 3)
			--
			-- KAREN, 2026-10-25: *"and now deer also hanging there hunted broken"*. The anchor is the
			-- one thing that can make a carcass hang, because it is the one thing that takes gravity
			-- away -- so the ground under the body's OWN x,z is read at the moment it settles.
			it("puts a settled carcass on the ground before it anchors it (task 261)", function()
				local handle = newBody()
				handle.collapsed = true
				handle.toppled = true
				handle.upright.Enabled = false
				handle.part.Anchored = false
				local half = handle.part.Size.Y / 2
				-- IT IS HANGING: the ground is 6 studs under its lowest point.
				local ground = handle.part.Position.Y - half - 6
				local asked: { any } = {}
				local reader = function(x: number, z: number, fromY: number?): number?
					table.insert(asked, { x = x, z = z, fromY = fromY })
					return ground
				end
				for _ = 1, 5 do
					handle.part.AssemblyLinearVelocity = Vector3.zero
					Body.stepCarcass(handle, 0.1, CONFIG.WOUND, reader)
				end
				expect(handle.part.Anchored).to.equal(true)
				-- ON THE GROUND, inside the tolerance, and ONCE.
				expect(handle.part.Position.Y - half).to.be.near(ground, 1e-3)
				expect(handle.grounded).to.equal(1)
				-- ASKED AT ITS OWN x,z AND FROM JUST ABOVE ITSELF, which are the two clauses task
				-- 192's four death defects all turned on: a value from somewhere else is about
				-- another point, and a ray from the sky answers about the canopy.
				expect(#asked >= 1).to.equal(true)
				expect(asked[1].x).to.be.near(handle.part.Position.X, 1e-3)
				expect(asked[1].z).to.be.near(handle.part.Position.Z, 1e-3)
				expect(asked[1].fromY > handle.part.Position.Y + half).to.equal(true)
			end)

			it("leaves a carcass that is already down alone, and refuses a wild answer (task 261)", function()
				local function settle(answers: boolean, offset: number)
					local handle = newBody()
					handle.collapsed = true
					handle.toppled = true
					handle.upright.Enabled = false
					handle.part.Anchored = false
					local before = handle.part.Position.Y
					local half = handle.part.Size.Y / 2
					local reader = function(): number?
						return if answers then before - half + offset else nil
					end
					for _ = 1, 5 do
						handle.part.AssemblyLinearVelocity = Vector3.zero
						Body.stepCarcass(handle, 0.1, CONFIG.WOUND, reader)
					end
					expect(handle.part.Anchored).to.equal(true)
					return handle, before
				end
				-- INSIDE THE TOLERANCE: terrain is voxelised and a fraction of a stud is noise.
				local a, beforeA = settle(true, CONFIG.WOUND.CARCASS_GROUND_TOLERANCE_STUDS - 0.01)
				expect(a.part.Position.Y).to.be.near(beforeA, 1e-3)
				expect(a.grounded).to.equal(0)
				-- PAST THE BOUND: a reader that answers 40 studs away is not answering about this
				-- body, and moving a carcass on that number would be believing a measurement over
				-- the screen. Nothing is done and the body stays where physics put it.
				local b, beforeB = settle(true, -(CONFIG.WOUND.CARCASS_GROUND_MAX_STUDS + 1))
				expect(b.part.Position.Y).to.be.near(beforeB, 1e-3)
				expect(b.grounded).to.equal(0)
				-- A READER THAT FOUND NOTHING UNDER THIS POINT: this system before task 261, line
				-- for line.
				local c, beforeC = settle(false, 0)
				expect(c.part.Position.Y).to.be.near(beforeC, 1e-3)
				expect(c.grounded).to.equal(0)
			end)

			-- ------------------------------ AND IT STOPS WHERE IT WAS SHOT (task 261, item 3)
			--
			-- KAREN, 2026-10-25: *"one more thing deer run on road the fall and was sidding on side
			-- it's a bug"*. `Body.collapse` disables the `LinearVelocity` that was DRIVING the
			-- animal, and a disabled constraint does not stop a BODY: the assembly kept its own
			-- momentum -- about 35 studs/s at a crossing -- and slid.
			it("takes the running speed off the body at the moment of death (task 261)", function()
				local handle = newBody()
				handle.part.AssemblyLinearVelocity = Vector3.new(30, -4, -18)
				handle.part.AssemblyAngularVelocity = Vector3.new(0, 3, 0)
				Body.collapse(handle, CONFIG.WOUND, CONFIG)
				local after = handle.part.AssemblyLinearVelocity
				-- THE HORIZONTAL IS GONE at `COLLAPSE_KEEP_SPEED` 0: a shot animal drops where it
				-- is hit.
				expect(math.abs(after.X)).to.be.near(0, 1e-3)
				expect(math.abs(after.Z)).to.be.near(0, 1e-3)
				-- ...AND SO IS THE SPIN, which `Body.carcassIsStill` tests as well: a body still
				-- turning would hold `stillFor` at 0 and wait out the whole anchor backstop.
				expect(handle.part.AssemblyAngularVelocity.Magnitude).to.be.near(0, 1e-3)
			end)
		end)

		it("is shorter than the wait that says the pose again, and longer than the clip's first frame", function()
			-- MEASURED AGAINST THE CLIP rather than chosen: `deathLeft` is 1.167 s, so a death that
			-- is running has moved long before the backstop looks.
			expect(WOUND.DEATH_BACKSTOP_SECONDS > 0).to.equal(true)
			expect(WOUND.DEATH_BACKSTOP_SECONDS < WOUND.CARCASS_REASSERT_SECONDS).to.equal(true)
			expect(WOUND.DEATH_BACKSTOP_SECONDS < MODEL.CLIPS.deathLeft.seconds * 2).to.equal(true)
			-- ...AND SHORTER THAN THE BODY IS THERE TO BE LOOKED AT, by a wide margin.
			expect(WOUND.DEATH_BACKSTOP_SECONDS < WOUND.CARCASS_SECONDS / 10).to.equal(true)
		end)
	end)
end
