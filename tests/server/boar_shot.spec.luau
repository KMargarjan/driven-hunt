-- boar_shot.spec: THE SHOT AND THE DEATH (task 116) -- what a hit in each zone makes the animal do,
-- and what the player HEARS. Pattern: TestEZ describe/it/expect
-- (https://roblox.github.io/testez/api-reference/).
--
-- THE THREE REACTIONS ARE REACHABLE BY PARAMETER, which is the only way they can be asserted at all:
-- a spec cannot fire a shotgun, so the hit event's `class` and `severity` are handed to the Brain
-- directly -- exactly the two fields `Runtime:takeHit` fills in from `Wound.hitClass` and
-- `Wound.severityFor`. The live half below then proves the same three through a REAL hit on a real
-- boar, so neither half can pass on its own fiction.
--
-- WHAT IS NOT ASSERTED HERE, and is reported rather than hidden: nothing in this repository can load
-- an audio or an animation asset, so no spec can hear a sound or measure a bone. What a Sound's
-- properties ARE is assertable, and that is what the live cases read -- the id, the volume, the
-- roll-off mode, the two distances, and which loop is playing. Whether 9114623726 sounds like a boar
-- is Karen's judgement and is in PLAYTEST.md.
--
-- Design: docs/design/boar-ai.md (section 6), docs/design/hit-zones.md
-- Note:   docs/research/2026-10-04-boar-shot-and-death.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Brain = Boar.Brain
local Wound = Boar.Wound
local CONFIG = Boar.CONFIG
local MODEL = CONFIG.MODEL
local SOUND = CONFIG.SOUND
local WOUND = CONFIG.WOUND

local DT = 1 / 60
local GROUND_Y = 760 -- its own plate, clear of boar_body.spec (500) and boar_model.spec (620)
local PLATE_SPAN = 120
local FIELD = {
	bounds = { minX = -55, maxX = 55, minZ = -55, maxZ = 55 },
	exitZ = -40,
	groundY = GROUND_Y,
}
local MESH_SIZE = Vector3.new(1.4011, 3.2573, 5.5) -- the real asset's, as boar_model.spec reads it

-- Every clip the boar can play, under a fake id: `Animator:LoadAnimation` on an id that does not
-- exist still returns a usable track, so the sound and the twitch can be driven with no network.
local FAKE_IDS = {
	idle = 20001,
	walk = 20002,
	trot = 20003,
	run = 20004,
	turnLeft = 20005,
	turnRight = 20006,
	deathLeft = 20007,
	deathRight = 20008,
	hitFront = 20009,
	hitBack = 20010,
}

-- Every one-shot `Body` can play, and the config row it reads. The names are the keys
-- `Body.attachSounds` puts in `handle.sounds`, so a renamed sound fails here rather than going quiet.
local ONE_SHOTS = {
	{ name = "hit", spec = SOUND.HIT },
	{ name = "cry", spec = SOUND.CRY },
	{ name = "death", spec = SOUND.DEATH },
	{ name = "lastBreath", spec = SOUND.LAST_BREATH },
	{ name = "fall", spec = SOUND.FALL },
	{ name = "grunt", spec = SOUND.GRUNTS },
	{ name = "breath", spec = SOUND.BREATH },
}

return function()
	local testRoot, plate

	---------------------------------------------------------------- the pure half: no world at all
	local function newBrain(seed: number?)
		return Brain.new(CONFIG, FIELD, Vector3.new(0, GROUND_Y, 0), Random.new(seed or 116))
	end

	local function obs(position: Vector3, extra)
		local o = {
			position = position,
			velocity = Vector3.zero,
			threats = {},
			waypoints = nil,
			pathFailed = false,
			blockedAhead = false,
		}
		for key, value in pairs(extra or {}) do
			o[key] = value
		end
		return o
	end

	-- One step carrying one hit, with the zone's CLASS worked out the way the Runtime works it out.
	local function shoot(brain, zone: string, severity: string, at: Vector3?)
		return brain:step(
			DT,
			obs(at or Vector3.new(0, GROUND_Y, 0), {
				hitEvents = {
					{
						severity = severity,
						zone = zone,
						class = Wound.hitClass(zone, WOUND),
						from = Vector3.new(0, GROUND_Y, 30),
					},
				},
			})
		)
	end

	---------------------------------------------------------------- the live half: a real boar
	local function buildWorld(modelEnabled: boolean, name: string)
		return {
			field = FIELD,
			parent = testRoot,
			folderName = name,
			rng = Random.new(116),
			threats = function()
				return {}
			end,
			probe = function()
				return false
			end,
			requestPath = function(_agentId, _from, _to, done)
				done(nil)
			end,
			releasePath = function() end,
			config = {
				-- THE FLAG AS A PARAMETER, the one permitted shape (docs/design/feature-flags.md
				-- section 13.3). A clone, so the runtime never writes into the module's own table.
				MODEL = (function()
					local copy = table.clone(MODEL)
					copy.ENABLED = modelEnabled
					return copy
				end)(),
			},
		}
	end

	-- Shaped like the real import, its own AnimationController included: `attachVisual` has to strip
	-- that, and a fake without it hid a bug for a whole task (boar_model.spec says so at length).
	local function makeTemplate(): Model
		local model = Instance.new("Model")
		model.Name = "FakeBoarTemplate"
		local inner = Instance.new("Model")
		inner.Name = "Boar Male RedDeer v3"
		local mesh = Instance.new("MeshPart")
		mesh.Name = "BoarMale_NoAlpha"
		mesh.Size = MESH_SIZE
		mesh.Anchored = true
		local bone = Instance.new("Bone")
		bone.Name = "root_bone"
		bone.Parent = mesh
		mesh.Parent = inner
		local theirs = Instance.new("AnimationController")
		theirs.Parent = inner
		inner.Parent = model
		inner.PrimaryPart = mesh
		model.PrimaryPart = mesh
		model.Parent = testRoot
		return model
	end

	local function newRuntime(modelEnabled: boolean, name: string, withTemplate: boolean)
		local runtime = Boar.newRuntime(buildWorld(modelEnabled, name))
		local template = if withTemplate then makeTemplate() else nil
		runtime:setModelSource(
			if template
				then function()
					return template
				end
				else nil,
			function(clip: string)
				return FAKE_IDS[clip]
			end
		)
		return runtime
	end

	local function step(runtime, times: number?)
		for _ = 1, times or 1 do
			runtime:step(DT)
		end
	end

	local function soundsOf(handle): Instance?
		return handle.part:FindFirstChild(SOUND.FOLDER)
	end

	local function soundNamed(handle, name: string): Sound?
		local folder = soundsOf(handle)
		return if folder then folder:FindFirstChild(name) :: Sound? else nil
	end

	-- AUDIBLE, NOT MERELY PLAYING. The warm-up (task 116 fix round) plays every clip and every sound
	-- once at volume 0 so the client fetches them before the first shot, so `IsPlaying` alone stops
	-- meaning "a player can hear this". The volume is what `Body.coolAssets` itself tests, and it is
	-- the honest reading of the claim anyway.
	local function audible(sound: Sound?): boolean
		return sound ~= nil and sound.IsPlaying and sound.Volume > 0
	end

	-- Steps past the silent pre-roll, so a case about what can be HEARD starts from silence.
	local function warmedUp(runtime)
		step(runtime, math.ceil(MODEL.WARM_SECONDS / DT) + 4)
	end

	local function playingLoops(handle): { string }
		local out = {}
		local folder = soundsOf(handle)
		if folder then
			for _, child in ipairs(folder:GetChildren()) do
				local sound = child :: Sound
				if sound.Looped and audible(sound) then
					table.insert(out, sound.Name)
				end
			end
		end
		table.sort(out)
		return out
	end

	local function flatDistance(a: Vector3, b: Vector3): number
		return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
	end

	-- A real hit through the one seam a player's slug enters by, then wait for the carcass: the
	-- collapse is decided by `Wound.advance` on a later step, never inside takeHit.
	local function killFor(runtime, handle, zone: string)
		expect(runtime:takeHit(handle.part, { zone = zone, ammo = "Slug", pellets = 1, at = 0 })).to.equal(true)
		local deadline = os.clock() + 3
		while os.clock() < deadline and handle.part:GetAttribute("Carcass") ~= true do
			step(runtime)
			RunService.Heartbeat:Wait()
		end
		step(runtime, 3)
	end

	beforeAll(function()
		testRoot = Instance.new("Folder")
		testRoot.Name = "BoarShotSpec"
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

	describe("what a hit in each zone MEANS", function()
		it("is a lookup in the live config, not a list of zone names in code", function()
			expect(Wound.hitClass("head", WOUND)).to.equal("vital")
			expect(Wound.hitClass("chest", WOUND)).to.equal("vital")
			expect(Wound.hitClass("rear", WOUND)).to.equal("crippling")
			expect(Wound.hitClass("body", WOUND)).to.equal("nonVital")
			expect(Wound.hitClass("legs", WOUND)).to.equal("nonVital")
			-- Every zone the boar actually HAS is classed: a zone added without a class would still
			-- work (see below) but it would never be the reaction whoever added it had in mind.
			for _, zone in ipairs(CONFIG.ZONES.ORDER) do
				expect(WOUND.CLASS[zone]).to.be.ok()
			end
		end)

		it("is nonVital for a zone nobody classed, which is what EVERY zone did before task 116", function()
			-- The safe fallback, asserted because it is the whole reason the lookup has one: a new
			-- zone must flinch and run on, never silently become a kill or a crippled animal.
			expect(Wound.hitClass("snout", WOUND)).to.equal("nonVital")
			expect(Wound.hitClass(nil, WOUND)).to.equal("nonVital")
			expect(Wound.hitClass("rear", {})).to.equal("nonVital")
		end)

		it("charges the rump at the trunk's own numbers, and one slug there is MORTAL, not lethal", function()
			-- The reaction is the CLASS's job; the damage is the damage table's, and the rump carries
			-- the same meat as a flank. Mortal-not-lethal is what makes the reaction possible at all:
			-- a lethal hit drops the animal and there is nothing left to cripple.
			expect(WOUND.DAMAGE.rear.Slug).to.equal(WOUND.DAMAGE.body.Slug)
			expect(WOUND.DAMAGE.rear.Pellet).to.equal(WOUND.DAMAGE.body.Pellet)
			local one = Wound.apply(Wound.new(), { zone = "rear", ammo = "Slug", pellets = 1 }, WOUND)
			expect(Wound.severityFor(one.damage, WOUND)).to.equal("mortal")
			local two = Wound.apply(one, { zone = "rear", ammo = "Slug", pellets = 1 }, WOUND)
			expect(Wound.severityFor(two.damage, WOUND)).to.equal("lethal")
		end)

		it("gives a rump wound a flight it can finish at a crawl, inside the bleed-out ceiling", function()
			-- 60 studs at CRIPPLE_SPEED is the reaction's own length: long enough for a hunter to
			-- walk up and finish it, short enough that no boar circles for ever.
			local seconds = WOUND.FLIGHT.rear / WOUND.CRIPPLE_SPEED
			expect(seconds > 5).to.equal(true)
			expect(seconds < WOUND.BLEED_OUT_MAX_SECONDS).to.equal(true)
			TestKit.note(
				string.format(
					"boar-shot: a crippled boar lasts %.1f s of circling (%d studs at %.1f studs/s)",
					seconds,
					WOUND.FLIGHT.rear,
					WOUND.CRIPPLE_SPEED
				)
			)
		end)
	end)

	describe("the three reactions, each reachable BY PARAMETER", function()
		it("VITAL: a chest slug drops it where it stands, on the same tick, for ever", function()
			local brain = newBrain()
			local intent = shoot(brain, "chest", "lethal")
			expect(brain:state()).to.equal("DOWN")
			expect(intent.downed).to.equal(true)
			expect(intent.targetVelocity.Magnitude).to.equal(0)
			for _ = 1, 120 do
				local later = brain:step(DT, obs(Vector3.new(0, GROUND_Y, 0)))
				expect(later.downed).to.equal(false)
				expect(later.targetVelocity.Magnitude).to.equal(0)
			end
		end)

		it("NON-VITAL: it bolts away from the gun and is still running wounded five seconds later", function()
			local brain = newBrain()
			brain:step(DT, obs(Vector3.new(0, GROUND_Y, 0))) -- settle in IDLE first
			local intent = shoot(brain, "body", "mortal")
			expect(brain:state()).to.equal("WOUNDED")
			-- The bolt: no threat anywhere, so this speed can only have come from the hit.
			expect(intent.targetVelocity.Magnitude >= CONFIG.SPRINT_SPEED * WOUND.BOLT_KICK * 0.9).to.equal(true)
			expect(intent.targetVelocity.Z < 0).to.equal(true) -- away from the shot at +Z
			for _ = 1, 300 do
				brain:step(DT, obs(Vector3.new(0, GROUND_Y, 0)))
			end
			expect(brain:state()).to.equal("WOUNDED")
		end)

		it("CRIPPLING: the back end goes -- it does NOT bolt, and it crawls instead", function()
			local brain = newBrain()
			brain:step(DT, obs(Vector3.new(0, GROUND_Y, 0)))
			local intent = shoot(brain, "rear", "mortal")
			expect(brain:state()).to.equal("CRIPPLED")
			expect(intent.targetVelocity.Magnitude <= WOUND.CRIPPLE_SPEED + 1e-4).to.equal(true)
			-- ...and it stays a crawl. A bolt would show up here as 38-odd studs/s on the next tick.
			for _ = 1, 240 do
				local later = brain:step(DT, obs(Vector3.new(0, GROUND_Y, 0)))
				expect(later.state).to.equal("CRIPPLED")
				expect(math.abs(later.targetVelocity.Magnitude - WOUND.CRIPPLE_SPEED) < 1e-3).to.equal(true)
			end
		end)

		it("CRIPPLING: it circles ONE way, at the configured turn rate, and keeps circling", function()
			local brain = newBrain(7)
			shoot(brain, "rear", "mortal")
			local previous: Vector3? = nil
			local signs, total = {}, 0
			for _ = 1, 600 do
				local later = brain:step(DT, obs(Vector3.new(0, GROUND_Y, 0)))
				local facing = later.facing :: Vector3
				if previous then
					-- The signed turn between two headings, from the Y component of their cross
					-- product: positive is one way round, negative the other.
					local cross = previous:Cross(facing).Y
					table.insert(signs, if cross >= 0 then 1 else -1)
					total += math.abs(math.deg(math.asin(math.clamp(cross, -1, 1))))
				end
				previous = facing
			end
			-- ONE direction, every frame: a wobbling animal reads as a glitch, not as an injury.
			for _, sign in ipairs(signs) do
				expect(sign).to.equal(signs[1])
			end
			-- ...and ten seconds of it is ten times CRIPPLE_TURN_DEG of turning, bar the arcsine.
			local expected = WOUND.CRIPPLE_TURN_DEG * (#signs * DT)
			expect(math.abs(total - expected) / expected < 0.02).to.equal(true)
			TestKit.note(
				string.format(
					"boar-shot: crippled turn %.0f deg over %.1f s (expected %.0f)",
					total,
					#signs * DT,
					expected
				)
			)
		end)

		it("CRIPPLING: it cannot escape, because it is not going anywhere", function()
			-- A fleeing or wounded boar over the exit line is an ESCAPE and despawns. A crippled one
			-- is excluded from that test on purpose: it circles where it was hit. Driven here by
			-- putting it past the line, which is the strongest form of the claim.
			local brain = newBrain()
			shoot(brain, "rear", "mortal")
			for _ = 1, 60 do
				local later = brain:step(DT, obs(Vector3.new(0, GROUND_Y, FIELD.exitZ - 5)))
				expect(later.despawn).to.equal(false)
				expect(later.state).to.equal("CRIPPLED")
			end
			-- ...but every other despawn still reaches it: out of the arena sideways is still out.
			local out = brain:step(DT, obs(Vector3.new(500, GROUND_Y, 0)))
			expect(out.despawn).to.equal(true)
			expect(out.reason).to.equal("outOfBounds")
		end)

		it("CRIPPLING: a GRAZE to the rump is a graze, so no boar can circle for ever", function()
			-- The leak this closes: a crippled boar is out of the escape test and `Wound.advance`
			-- never collapses a GRAZED animal, so crippling on a graze would leave a boar turning in
			-- the arena with no way out at all. One pellet in the ham does not take the back legs off.
			local brain = newBrain()
			brain:step(DT, obs(Vector3.new(0, GROUND_Y, 0)))
			local intent = shoot(brain, "rear", "grazed")
			expect(brain:state()).never.to.equal("CRIPPLED")
			expect(brain:state()).to.equal("FLEE")
			expect(intent.targetVelocity.Magnitude > WOUND.CRIPPLE_SPEED).to.equal(true)
		end)

		it("CRIPPLING: a second shot still kills it, and the wound still finishes it", function()
			local brain = newBrain()
			shoot(brain, "rear", "mortal")
			expect(brain:state()).to.equal("CRIPPLED")
			local intent = shoot(brain, "chest", "lethal")
			expect(brain:state()).to.equal("DOWN")
			expect(intent.downed).to.equal(true)

			-- ...and with no second shot, the wound's own collapse reaches a crippled boar: the
			-- Runtime hands `wound.collapse` in exactly as it does for a wounded one.
			local other = newBrain()
			shoot(other, "rear", "mortal")
			local downed = other:step(DT, obs(Vector3.new(0, GROUND_Y, 0), { wound = { collapse = true } }))
			expect(other:state()).to.equal("DOWN")
			expect(downed.downed).to.equal(true)
		end)
	end)

	describe("the hit lands on the frame the player expects", function()
		-- Karen, 2026-10-03: "body shot is a bit odd now feels late hit and odd". Measured on the
		-- client that fired: the cry and the flinch both arrived 364 ms after the bullet because
		-- nothing had ever asked the client to fetch them, and the flinch then held the animal's
		-- animation for its whole 0.833 s while the body was already bolting at sprint speed.
		it("shows a STANDING animal the whole flinch, which is what the clip is for", function()
			expect(Boar.flinchWindow(0, CONFIG)).to.equal(MODEL.HIT_SECONDS)
			expect(Boar.flinchWindow(MODEL.HIT_FULL_BELOW - 0.01, CONFIG)).to.equal(MODEL.HIT_SECONDS)
		end)

		it("cuts it short on one that is RUNNING, so the bolt is what the player sees", function()
			expect(Boar.flinchWindow(MODEL.HIT_FULL_BELOW, CONFIG)).to.equal(MODEL.HIT_MOVING_SECONDS)
			expect(Boar.flinchWindow(CONFIG.SPRINT_SPEED, CONFIG)).to.equal(MODEL.HIT_MOVING_SECONDS)
			-- Short enough that the run begins while the player is still watching the impact, and long
			-- enough to be seen at all: a frame at 60 fps is 0.017 s.
			expect(MODEL.HIT_MOVING_SECONDS > 4 / 60).to.equal(true)
			expect(MODEL.HIT_MOVING_SECONDS < MODEL.HIT_SECONDS / 2).to.equal(true)
		end)

		it("is the clip for the first part of the window and the gait after it", function()
			-- `hitFor` counts DOWN from HIT_SECONDS, so this walks a bolting animal through its own
			-- flinch and asserts where the gait takes over.
			local function clipAt(elapsed: number, speed: number)
				return (
					Boar.clipFor({
						collapsed = false,
						hitFor = math.max(MODEL.HIT_SECONDS - elapsed, 0),
						hitFromBehind = false,
						speed = speed,
						yawRate = 0,
						currentClip = nil,
						heldFor = 1,
					}, CONFIG)
				)
			end
			expect(clipAt(0, CONFIG.SPRINT_SPEED)).to.equal("hitFront")
			expect(clipAt(MODEL.HIT_MOVING_SECONDS - 0.01, CONFIG.SPRINT_SPEED)).to.equal("hitFront")
			expect(clipAt(MODEL.HIT_MOVING_SECONDS + 0.01, CONFIG.SPRINT_SPEED)).to.equal("run")
			-- ...and a standing animal keeps it for the whole clip.
			expect(clipAt(MODEL.HIT_MOVING_SECONDS + 0.01, 0)).to.equal("hitFront")
			expect(clipAt(MODEL.HIT_SECONDS + 0.01, 0)).to.equal("idle")
		end)

		it("CUTS a hit and a death in, and blends a gait", function()
			for _, name in ipairs({ "hitFront", "hitBack", "deathLeft", "deathRight" }) do
				expect(Boar.fadeFor(name, CONFIG)).to.equal(MODEL.HIT_FADE_SECONDS)
			end
			for _, name in ipairs({ "idle", "walk", "trot", "run", "turnLeft", "turnRight" }) do
				expect(Boar.fadeFor(name, CONFIG)).to.equal(MODEL.FADE_SECONDS)
			end
			-- A cut is under a frame at 30 fps; a blend is several.
			expect(MODEL.HIT_FADE_SECONDS < 1 / 30).to.equal(true)
			expect(MODEL.FADE_SECONDS > MODEL.HIT_FADE_SECONDS * 3).to.equal(true)
		end)

		it("flag ON: every clip and every sound is ASKED FOR before the first shot", function()
			-- The other half of the lateness, and the half no pure function can hold: a client fetches
			-- an asset when it is told to play it, so everything is played once, silently, when the coat
			-- goes on. This asserts what the warm-up leaves behind -- every sound back at its configured
			-- volume and nothing audible -- because a warm-up that never cooled would be a boar whose
			-- every sound is stuck at zero.
			local runtime = newRuntime(true, "BoarsShotWarm", true)
			local handle = runtime:spawn(Vector3.new(-20, GROUND_Y, -20))
			step(runtime, 2)
			local folder = soundsOf(handle) :: Instance
			local warm = 0
			for _, child in ipairs(folder:GetChildren()) do
				local sound = child :: Sound
				if sound.IsPlaying and sound.Volume == 0 then
					warm += 1
				end
			end
			expect(warm > 0).to.equal(true) -- it really did pre-roll
			-- ...and it is over after WARM_SECONDS, with every volume back.
			step(runtime, math.ceil(MODEL.WARM_SECONDS / DT) + 4)
			-- `Sound.Volume` is a float32, so 0.8 comes back as 0.800000011920929: compared to a
			-- tolerance, not for equality (the same reason boar_brain.spec keeps an EPSILON).
			for _, row in ipairs(ONE_SHOTS) do
				local sound = soundNamed(handle, row.name) :: Sound
				expect(math.abs(sound.Volume - row.spec.volume) < 1e-5).to.equal(true)
				expect(audible(sound)).to.equal(false)
			end
			for _, gait in ipairs({ "walk", "trot", "run" }) do
				local sound = soundNamed(handle, "steps_" .. gait) :: Sound
				expect(math.abs(sound.Volume - SOUND.STEPS[gait].volume) < 1e-5).to.equal(true)
			end
			TestKit.note(
				string.format("boar-shot: %d sound(s) pre-rolled, all cooled by %.2f s", warm, MODEL.WARM_SECONDS)
			)
			runtime:destroy()
		end)
	end)

	describe("a crippled boar draws a circle a player can SEE", function()
		it("is wider than the animal is long, which is what was wrong", function()
			-- MEASURED before the fix: radius 2.45 studs, a circle 4.9 studs across on an animal 5.5
			-- studs long -- a pivot, not a circle, and Karen saw exactly that. The radius is the whole
			-- claim: v / w, with w in radians.
			local radius = WOUND.CRIPPLE_SPEED / math.rad(WOUND.CRIPPLE_TURN_DEG)
			expect(radius * 2 > CONFIG.BODY_SIZE.Z).to.equal(true)
			-- ...and not so wide that it reads as a wounded animal simply running away.
			expect(radius * 2 < CONFIG.BODY_SIZE.Z * 3).to.equal(true)
			local lap = 360 / WOUND.CRIPPLE_TURN_DEG
			expect(lap < 12).to.equal(true) -- a lap she can watch, not one she has to wait out
			TestKit.note(
				string.format(
					"boar-shot: crippled circle r=%.2f studs (%.1f across), lap %.1f s",
					radius,
					radius * 2,
					lap
				)
			)
		end)

		it("still crawls: slower than a trot, and it still dies of the wound", function()
			expect(WOUND.CRIPPLE_SPEED < CONFIG.TROT_SPEED).to.equal(true)
			-- Fast enough that the walk clip reads as walking rather than sliding: the clip's own ground
			-- speed is what `clipFor` rates against.
			expect(WOUND.CRIPPLE_SPEED > MODEL.CLIPS.walk.groundStudsPerSecond).to.equal(true)
			local seconds = WOUND.FLIGHT.rear / WOUND.CRIPPLE_SPEED
			expect(seconds > 10).to.equal(true)
			expect(seconds < WOUND.BLEED_OUT_MAX_SECONDS).to.equal(true)
		end)
	end)

	describe("which footstep loop a speed asks for", function()
		it("is SILENCE while it stands, which is most of what a grazing boar is doing", function()
			expect((Boar.stepSoundFor(0, CONFIG))).to.equal(nil)
			expect((Boar.stepSoundFor(SOUND.STEPS.MIN_SPEED - 0.01, CONFIG))).to.equal(nil)
			expect((Boar.stepSoundFor(SOUND.STEPS.MIN_SPEED, CONFIG))).to.equal("walk")
		end)

		it("follows the GAIT the model is playing, at every speed a boar can reach", function()
			-- The same three bands `Body.clipFor` uses, so the steps can never belong to a different
			-- gait from the legs. Walked rather than sampled at three points, and the clip is asked
			-- for through the production function with a FULL info table -- a live boar that is
			-- neither dead nor flinching and is not turning on the spot.
			for speed = 1, CONFIG.SPRINT_SPEED, 0.25 do
				local gait = Boar.stepSoundFor(speed, CONFIG)
				local clip = Boar.clipFor({
					collapsed = false,
					hitFor = 0,
					hitFromBehind = false,
					speed = speed,
					yawRate = 0,
					currentClip = nil,
					heldFor = 1,
				}, CONFIG)
				expect(gait).to.equal(clip)
			end
		end)

		it("plays each loop near 1.0 at that gait's own speed, and never clamps at the TOP", function()
			-- THE CEILING IS WHAT MATTERS, and the floor is a deliberate difference from the legs:
			-- a boar creeping at 0.6 studs/s asks the walk loop for 0.21, which `MIN_RATE` lifts to
			-- 0.4 -- footstep audio played at a fifth speed is a groan, not a footfall. It is only
			-- clamped below the speed where the rate reaches `MIN_RATE`, which is a crawl.
			local floorSpeed = SOUND.STEPS.walk.baseSpeed * MODEL.MIN_RATE
			for speed = SOUND.STEPS.MIN_SPEED, CONFIG.SPRINT_SPEED, 0.25 do
				local _, rate = Boar.stepSoundFor(speed, CONFIG)
				expect(rate >= MODEL.MIN_RATE).to.equal(true)
				expect(rate < MODEL.MAX_RATE).to.equal(true)
				if speed >= floorSpeed then
					expect(rate > MODEL.MIN_RATE).to.equal(true)
				end
			end
			TestKit.note(string.format("boar-shot: footsteps clamp below %.2f studs/s only", floorSpeed))
		end)

		it("is rated off the CLIP'S OWN measured ground speed, so the steps land under the hooves", function()
			-- THE SAME NUMBER, NOT A COPY OF IT. `stepSoundFor` and `clipFor` both divide by the
			-- clip's measured `groundStudsPerSecond`, so a re-measured clip moves its animation and
			-- its footsteps together. A typed duplicate would let them drift apart silently -- and
			-- the drift is inaudible until somebody watches the feet.
			for _, gait in ipairs({ "walk", "trot", "run" }) do
				expect(SOUND.STEPS[gait].baseSpeed).to.equal(MODEL.CLIPS[gait].groundStudsPerSecond)
			end
			-- ...which makes the strong claim assertable: at every speed a boar can reach, the
			-- footstep loop plays at exactly the rate the legs play at.
			for speed = 1, CONFIG.SPRINT_SPEED, 0.25 do
				local _, soundRate = Boar.stepSoundFor(speed, CONFIG)
				local _, clipRate = Boar.clipFor({
					collapsed = false,
					hitFor = 0,
					hitFromBehind = false,
					speed = speed,
					yawRate = 0,
					currentClip = nil,
					heldFor = 1,
				}, CONFIG)
				expect(math.abs(soundRate - clipRate) < 1e-6).to.equal(true)
			end
		end)
	end)

	describe("the clips this project authored, and the day they have no id", function()
		-- Task 116 fix round. `tools/boar_prep.py` authors `Death_Paddle_L/R` and `Cripple_Drag` out of
		-- the package's own poses, because a script cannot move a bone over a playing track (0 of 122
		-- frames survived). An animation asset id can only be made by hand in Studio, so the whole
		-- wiring has to be correct BEFORE any id exists and has to change nothing until one does.
		local function withIds(ids)
			local model = table.clone(MODEL)
			model.ANIMATION_IDS = ids
			local config = table.clone(CONFIG)
			config.MODEL = model
			return config
		end

		local function clipAt(config, info)
			local filled = {
				collapsed = false,
				deadFor = 0,
				crippled = false,
				hitFor = 0,
				hitFromBehind = false,
				speed = 0,
				yawRate = 0,
				currentClip = nil,
				heldFor = 1,
			}
			for key, value in pairs(info) do
				filled[key] = value
			end
			return (Boar.clipFor(filled, config))
		end

		it("knows a clip it cannot play from one it can", function()
			local none = withIds({})
			local some = withIds({ crippleDrag = 4242, deathPaddleLeft = 4243, deathPaddleRight = 4244 })
			for _, name in ipairs({ "crippleDrag", "deathPaddleLeft", "deathPaddleRight" }) do
				expect(Boar.hasClip(name, none)).to.equal(false)
				expect(Boar.hasClip(name, some)).to.equal(true)
			end
			-- An id of zero is a row that exists and names nothing, which is what an unpublished clip's
			-- row will look like the moment somebody adds one: still not playable.
			expect(Boar.hasClip("crippleDrag", withIds({ crippleDrag = 0 }))).to.equal(false)
			-- ...and a clip name nobody declared is not playable however the ids are filled in.
			expect(Boar.hasClip("somersault", withIds({ somersault = 99 }))).to.equal(false)
		end)

		it("plays the two paddles ONCE and the drag for ever, whatever the asset says", function()
			-- THE DIRECTOR PUBLISHED ALL THREE WITH `clip.Loop = true` (the Animation Editor's loop
			-- toggle), and for the paddles that is wrong: a looping death-throe restarts the twitch
			-- every four seconds on a carcass that is supposed to be lying still. `Body.play` writes
			-- `AnimationTrack.Looped` from THIS table immediately before every `Play`, which is the
			-- same guard the ten published clips already needed -- they are all `Loop = true` too.
			expect(MODEL.CLIPS.deathPaddleLeft.looped).to.equal(false)
			expect(MODEL.CLIPS.deathPaddleRight.looped).to.equal(false)
			expect(MODEL.CLIPS.crippleDrag.looped).to.equal(true)
			-- ...and a one-shot that ends is what the carcass is then HELD at, so the two paddles
			-- must be the same length as each other and end where the fall ended.
			expect(MODEL.CLIPS.deathPaddleLeft.seconds).to.equal(MODEL.CLIPS.deathPaddleRight.seconds)
		end)

		it("plays each authored clip at the id the manifest published", function()
			-- The two copies of one number, compared where both are visible: the config knows the
			-- clip by name and the manifest knows it by id, and `BoarAssetsBoot` is the only thing
			-- that joins them. A wrong id here is a boar that plays somebody else's animation.
			local Assets = require(ServerStorage:WaitForChild("Assets"))
			local ids = {
				crippleDrag = "boar.anim.cripple.drag",
				deathPaddleLeft = "boar.anim.death.paddle.left",
				deathPaddleRight = "boar.anim.death.paddle.right",
			}
			for name, key in pairs(ids) do
				local row = Assets.byKey(key)
				expect(row).to.be.ok()
				expect(row.kind).to.equal("animation")
				expect(row.modelId > 0).to.equal(true)
				-- The length the config plays by and the length read back off the published asset.
				expect(math.abs(row.clipSeconds - MODEL.CLIPS[name].seconds) <= 1 / 48).to.equal(true)
				TestKit.note(string.format("boar-shot: %s = %d, %.3f s", name, row.modelId, row.clipSeconds))
			end
		end)

		it("pairs each death with its own paddle, from the same side the box rolls to", function()
			local fall, paddle = Boar.deathClips(CONFIG)
			if MODEL.DEATH_TO_THE_LEFT then
				expect(fall).to.equal("deathLeft")
				expect(paddle).to.equal("deathPaddleLeft")
			else
				expect(fall).to.equal("deathRight")
				expect(paddle).to.equal("deathPaddleRight")
			end
			-- The paddle starts on the pose the fall ends on, so the two lengths are what decides when
			-- the hand-over happens, and the paddle is the longer of the two by a wide margin.
			expect(MODEL.CLIPS[paddle].seconds > MODEL.CLIPS[fall].seconds * 2).to.equal(true)
			expect(MODEL.CLIPS[paddle].looped).to.equal(false) -- it ends, and the carcass holds there
		end)

		it("WITH NO ID the death is one clip and a crippled boar walks, exactly as before", function()
			local config = withIds({})
			local fall = (Boar.deathClips(config))
			expect(clipAt(config, { collapsed = true, deadFor = 0 })).to.equal(fall)
			-- ...and it is STILL the fall long after the fall has ended, which is the promise.
			expect(clipAt(config, { collapsed = true, deadFor = 60 })).to.equal(fall)
			-- A crippled boar falls through to the speed bands, which at CRIPPLE_SPEED is the walk.
			expect(clipAt(config, { crippled = true, speed = WOUND.CRIPPLE_SPEED })).to.equal("walk")
		end)

		it("WITH AN ID the death becomes fall then paddle, and a crippled boar drags", function()
			local config = withIds({ crippleDrag = 4242, deathPaddleLeft = 4243, deathPaddleRight = 4244 })
			local fall, paddle = Boar.deathClips(config)
			-- The fall first, for exactly its own length...
			expect(clipAt(config, { collapsed = true, deadFor = 0 })).to.equal(fall)
			expect(clipAt(config, { collapsed = true, deadFor = MODEL.CLIPS[fall].seconds - 0.01 })).to.equal(fall)
			-- ...then the paddle, and it never goes back.
			expect(clipAt(config, { collapsed = true, deadFor = MODEL.CLIPS[fall].seconds })).to.equal(paddle)
			expect(clipAt(config, { collapsed = true, deadFor = 60 })).to.equal(paddle)
			-- A crippled boar drags, at whatever speed it is crawling.
			expect(clipAt(config, { crippled = true, speed = WOUND.CRIPPLE_SPEED })).to.equal("crippleDrag")
			-- ...and a boar that is NOT crippled never does, however slowly it is moving.
			expect(clipAt(config, { crippled = false, speed = WOUND.CRIPPLE_SPEED })).to.equal("walk")
			-- A death still beats it: a dead crippled boar is dead.
			expect(clipAt(config, { crippled = true, collapsed = true, deadFor = 0 })).to.equal(fall)
		end)

		it("rates the drag off its FRONT hooves, so the walking legs match the ground", function()
			-- MEASURED by `tools/boar_prep_blender.py` on the authored clip: front hooves 2.866 and
			-- 2.863 studs/s (Walk_F_IP's own 2.853 -- a real walk cycle) and hind 0.826 and 0.931 (a
			-- third of it, dragging). The config carries the FRONT number, because those are the legs
			-- carrying the animal, and `clipFor` divides the crawl by it.
			local config = withIds({ crippleDrag = 4242 })
			local drag = MODEL.CLIPS.crippleDrag
			expect(drag.looped).to.equal(true)
			expect(math.abs(drag.groundStudsPerSecond - MODEL.CLIPS.walk.groundStudsPerSecond) < 0.1).to.equal(true)
			local _, rate = Boar.clipFor({
				collapsed = false,
				deadFor = 0,
				crippled = true,
				hitFor = 0,
				hitFromBehind = false,
				speed = WOUND.CRIPPLE_SPEED,
				yawRate = 0,
				currentClip = nil,
				heldFor = 1,
			}, config)
			expect(math.abs(rate - WOUND.CRIPPLE_SPEED / drag.groundStudsPerSecond) < 1e-6).to.equal(true)
			expect(rate > MODEL.MIN_RATE).to.equal(true)
			expect(rate < MODEL.MAX_RATE).to.equal(true)
			TestKit.note(string.format("boar-shot: the drag plays at %.2f at the crippled crawl", rate))
		end)
	end)

	describe("a repeat must not sound like a loop", function()
		it("is the configured band, centred on 1.0", function()
			expect(Boar.jitteredPitch(0.5, SOUND.PITCH_JITTER)).to.equal(1)
			expect(Boar.jitteredPitch(0, SOUND.PITCH_JITTER)).to.equal(1 - SOUND.PITCH_JITTER)
			expect(Boar.jitteredPitch(1, SOUND.PITCH_JITTER)).to.equal(1 + SOUND.PITCH_JITTER)
			-- 8 % is audible and is not a different animal: a wide jitter turns a pig into a toy.
			expect(SOUND.PITCH_JITTER > 0.02).to.equal(true)
			expect(SOUND.PITCH_JITTER < 0.2).to.equal(true)
		end)
	end)

	describe("the dying twitch", function()
		it("is bounded, NEGATIVE only, and decays to nothing", function()
			-- Negative only because the scrub must never run a non-looped death clip past its end:
			-- the track stops and the animal stands back up in its rest pose (task 115's own fault).
			local worst = 0
			for i = 0, 400 do
				local elapsed = i * MODEL.PADDLE_SECONDS / 200
				local offset = Boar.paddleOffset(elapsed, CONFIG)
				expect(offset <= 0).to.equal(true)
				expect(offset >= -MODEL.PADDLE_SPAN).to.equal(true)
				worst = math.min(worst, offset)
			end
			expect(worst < 0).to.equal(true) -- it really does move
			expect(Boar.paddleOffset(MODEL.PADDLE_SECONDS, CONFIG)).to.equal(0)
			expect(Boar.paddleOffset(MODEL.PADDLE_SECONDS + 1, CONFIG)).to.equal(0)
			expect(Boar.paddleOffset(-1, CONFIG)).to.equal(0)
			TestKit.note(string.format("boar-shot: twitch span %.3f s over %.1f s", -worst, MODEL.PADDLE_SECONDS))
		end)

		it("is quieter at the end than at the start, which is an animal going still", function()
			local early, late = 0, 0
			for i = 0, 60 do
				local t = i * 0.3 / 60
				early = math.min(early, Boar.paddleOffset(t, CONFIG))
				late = math.min(late, Boar.paddleOffset(MODEL.PADDLE_SECONDS - 0.3 + t, CONFIG))
			end
			expect(math.abs(late) < math.abs(early)).to.equal(true)
		end)
	end)

	describe("every sound is configured, spatial and swappable", function()
		it("names a real RollOffMode and a near distance inside every audible range", function()
			expect(Enum.RollOffMode[SOUND.ROLL_OFF]).to.be.ok()
			expect(SOUND.NEAR_STUDS > 0).to.equal(true)
			local rows = { SOUND.STEPS.walk, SOUND.STEPS.trot, SOUND.STEPS.run }
			for _, row in ipairs(ONE_SHOTS) do
				table.insert(rows, row.spec)
			end
			for _, spec in ipairs(rows) do
				expect(spec.audibleStuds > SOUND.NEAR_STUDS).to.equal(true)
			end
		end)

		it("has a numeric id, a volume and a range for every sound the code can play", function()
			-- IDS ARE DATA, on purpose: the Director's picks are provisional and a library sound can
			-- be moderated away, so a swap is one number in `Boar.CONFIG.SOUND` and no code change.
			local function checkSpec(what: string, spec)
				local ids = spec.ids or { spec.id }
				expect(#ids > 0).to.equal(true)
				for _, id in ipairs(ids) do
					expect(type(id)).to.equal("number")
					expect(id > 0).to.equal(true)
				end
				expect(spec.volume > 0).to.equal(true)
				expect(spec.volume <= 1).to.equal(true)
				expect(type(spec.audibleStuds)).to.equal("number")
				TestKit.note(
					string.format(
						"boar-shot: %s = %d id(s), vol %.2f, %d studs",
						what,
						#ids,
						spec.volume,
						spec.audibleStuds
					)
				)
			end
			for _, gait in ipairs({ "walk", "trot", "run" }) do
				checkSpec("steps_" .. gait, SOUND.STEPS[gait])
				expect(SOUND.STEPS[gait].baseSpeed > 0).to.equal(true)
			end
			for _, row in ipairs(ONE_SHOTS) do
				checkSpec(row.name, row.spec)
			end
			-- ...and a boar can be heard coming from a post, which is what Karen asked for: the
			-- Director's brief is 60-80 studs, and a gallop carries further than a walk.
			expect(SOUND.STEPS.run.audibleStuds >= 60).to.equal(true)
			expect(SOUND.STEPS.run.audibleStuds > SOUND.STEPS.walk.audibleStuds).to.equal(true)
		end)

		it("only ever grunts when calm and only ever breathes when working", function()
			-- Two bands that must not overlap, or a boar does both at once and sounds like two animals.
			expect(SOUND.GRUNTS.MAX_SPEED < SOUND.BREATH.MIN_SPEED).to.equal(true)
			expect(SOUND.GRUNTS.MIN_SECONDS < SOUND.GRUNTS.MAX_SECONDS).to.equal(true)
			expect(SOUND.BREATH.MIN_SECONDS < SOUND.BREATH.MAX_SECONDS).to.equal(true)
			-- ...and breathing starts where the animal is actually working: the trot band.
			expect(SOUND.BREATH.MIN_SPEED >= MODEL.TROT_FROM - 1).to.equal(true)
		end)
	end)

	describe("the sounds live on the boar", function()
		it("flag OFF: a boar makes no sound at all, and has no folder to make one with", function()
			local runtime = newRuntime(false, "BoarsShotOff", true)
			local handle = runtime:spawn(Vector3.new(-40, GROUND_Y, -20))
			step(runtime, 10)
			expect(soundsOf(handle)).to.equal(nil)
			local found = 0
			for _, child in ipairs(handle.part:GetDescendants()) do
				if child:IsA("Sound") then
					found += 1
				end
			end
			expect(found).to.equal(0)
			runtime:destroy()
		end)

		it("flag ON: ONE folder on the trunk, with one Sound per thing a boar can do", function()
			local runtime = newRuntime(true, "BoarsShotOn", true)
			local handle = runtime:spawn(Vector3.new(-40, GROUND_Y, 20))
			step(runtime, 10)
			local folder = soundsOf(handle)
			expect(folder).to.be.ok()
			-- ON THE TRUNK, not on the model: the trunk is the one part everything is welded to, so
			-- every client hears the animal from the right place with no owner but `Body`.
			expect((folder :: Instance).Parent).to.equal(handle.part)
			local names = {}
			for _, child in ipairs((folder :: Instance):GetChildren()) do
				expect(child:IsA("Sound")).to.equal(true)
				table.insert(names, child.Name)
			end
			table.sort(names)
			expect(table.concat(names, ",")).to.equal(
				"breath,cry,death,fall,grunt,hit,lastBreath,steps_run,steps_trot,steps_walk"
			)
			-- ...and only ever one folder, however many times it steps.
			step(runtime, 60)
			local folders = 0
			for _, child in ipairs(handle.part:GetChildren()) do
				if child.Name == SOUND.FOLDER then
					folders += 1
				end
			end
			expect(folders).to.equal(1)
			runtime:destroy()
		end)

		it("flag ON: is spatial, with the configured roll-off and each sound's own range", function()
			local runtime = newRuntime(true, "BoarsShotSpatial", true)
			local handle = runtime:spawn(Vector3.new(0, GROUND_Y, 20))
			warmedUp(runtime) -- the pre-roll holds every volume at 0 while it runs
			local folder = soundsOf(handle) :: Instance
			for _, child in ipairs(folder:GetChildren()) do
				local sound = child :: Sound
				expect(sound.RollOffMode).to.equal(Enum.RollOffMode[SOUND.ROLL_OFF])
				expect(sound.RollOffMinDistance).to.equal(SOUND.NEAR_STUDS)
				expect(sound.RollOffMaxDistance > SOUND.NEAR_STUDS).to.equal(true)
				expect(string.match(sound.SoundId, "^rbxassetid://%d+$")).to.be.ok()
				expect(sound.Volume > 0).to.equal(true)
				-- Exactly the three footstep loops loop. A looping squeal never stops.
				expect(sound.Looped).to.equal(string.sub(sound.Name, 1, 6) == "steps_")
			end
			TestKit.note(
				string.format(
					"boar-shot: %s roll-off, %d..%d studs on the walk loop",
					SOUND.ROLL_OFF,
					SOUND.NEAR_STUDS,
					(soundNamed(handle, "steps_walk") :: Sound).RollOffMaxDistance
				)
			)
			runtime:destroy()
		end)

		it("flag ON: a boar does not grunt on the frame its coat goes on", function()
			-- A countdown that starts at zero fires immediately, and a sounder is five boars: they
			-- would grunt in chorus on the tick the asset lands and read as one loud animal. The
			-- first interval is ARMED instead, so nothing one-shot is playing on a boar that has
			-- only been alive for a tenth of a second.
			local runtime = newRuntime(true, "BoarsShotQuiet", true)
			local handle = runtime:spawn(Vector3.new(-20, GROUND_Y, 20))
			warmedUp(runtime)
			local folder = soundsOf(handle) :: Instance
			for _, child in ipairs(folder:GetChildren()) do
				local sound = child :: Sound
				if not sound.Looped then
					expect(audible(sound)).to.equal(false)
				end
			end
			runtime:destroy()
		end)

		it("flag ON: at most ONE footstep loop is ever playing, however the boar moves", function()
			-- Two loops at once is two animals. Driven over two seconds of real steps rather than
			-- asserted at one instant, because the gait changes are what could leave one behind.
			local runtime = newRuntime(true, "BoarsShotLoops", true)
			local handle = runtime:spawn(Vector3.new(20, GROUND_Y, 20))
			warmedUp(runtime)
			local worst = 0
			for _ = 1, 120 do
				step(runtime)
				worst = math.max(worst, #playingLoops(handle))
			end
			expect(worst <= 1).to.equal(true)
			runtime:destroy()
		end)

		it("flag ON: a REAL shot plays the hit and the cry, from the configured ids", function()
			-- Through `takeHit`, so this is the path a player's slug takes, and the class is worked
			-- out by the production code rather than handed in.
			local runtime = newRuntime(true, "BoarsShotHeard", true)
			local handle = runtime:spawn(Vector3.new(-20, GROUND_Y, 0))
			warmedUp(runtime)
			local hit = soundNamed(handle, "hit") :: Sound
			local cry = soundNamed(handle, "cry") :: Sound
			expect(audible(hit)).to.equal(false)
			expect(runtime:takeHit(handle.part, { zone = "legs", ammo = "Pellet", pellets = 1, at = 0 })).to.equal(true)
			step(runtime)
			-- A played Sound reports IsPlaying even while its asset is still loading, and the id it
			-- was given is one of the configured ones: that is the whole of what a spec can assert.
			expect(audible(hit)).to.equal(true)
			expect(audible(cry)).to.equal(true)
			local chosen = tonumber(string.match(cry.SoundId, "%d+"))
			local known = false
			for _, id in ipairs(SOUND.CRY.ids) do
				known = known or id == chosen
			end
			expect(known).to.equal(true)
			runtime:destroy()
		end)

		it("flag ON: a dead boar has no footsteps, screams once, and then only breathes out", function()
			local runtime = newRuntime(true, "BoarsShotDeath", true)
			local handle = runtime:spawn(Vector3.new(20, GROUND_Y, -20))
			warmedUp(runtime)
			local death = soundNamed(handle, "death") :: Sound
			local fall = soundNamed(handle, "fall") :: Sound
			local breath = soundNamed(handle, "lastBreath") :: Sound
			expect(audible(death)).to.equal(false)
			killFor(runtime, handle, "head")
			expect(handle.part:GetAttribute("Carcass")).to.equal(true)
			expect(audible(death)).to.equal(true)
			expect(audible(fall)).to.equal(true)
			-- EVERY LOOP IS CUT: a carcass with footsteps is the thing this exists to prevent.
			expect(#playingLoops(handle)).to.equal(0)
			-- ...and the last breath lands AFTER its delay, not with the scream.
			expect(audible(breath)).to.equal(false)
			step(runtime, math.ceil(SOUND.LAST_BREATH.delay / DT) + 2)
			expect(audible(breath)).to.equal(true)
			expect(#playingLoops(handle)).to.equal(0)
			TestKit.note(string.format("boar-shot: last breath after %.1f s, loops cut", SOUND.LAST_BREATH.delay))
			runtime:destroy()
		end)

		it("flag ON: a real rump slug leaves a CRIPPLED boar that circles and does not run off", function()
			-- The live half of the crippling reaction: through `takeHit`, with the class and the
			-- severity decided by production code, and measured on the body the player would see.
			local runtime = newRuntime(true, "BoarsShotCripple", true)
			local handle = runtime:spawn(Vector3.new(0, GROUND_Y, -20))
			warmedUp(runtime)
			local at = handle.part.Position
			expect(runtime:takeHit(handle.part, { zone = "rear", ammo = "Slug", pellets = 1, at = 0 })).to.equal(true)
			local far = 0
			for _ = 1, 180 do
				step(runtime)
				RunService.Heartbeat:Wait()
				if handle.part:GetAttribute("Carcass") == true then
					break
				end
				far = math.max(far, flatDistance(handle.part.Position, at))
			end
			-- IT STAYS WHERE IT WAS HIT. A bolting boar covers 38 studs a second; three seconds of
			-- circling at CRIPPLE_SPEED cannot leave a circle a few studs across.
			-- A bolting boar covers 38 studs a second; three seconds of circling at CRIPPLE_SPEED
			-- cannot leave a circle about 11.5 studs across (see the radius case above).
			expect(far < 18).to.equal(true)
			TestKit.note(string.format("boar-shot: crippled boar strayed %.2f studs in 3 s", far))
			runtime:destroy()
		end)
	end)
end
