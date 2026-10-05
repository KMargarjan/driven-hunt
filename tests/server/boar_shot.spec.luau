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
	-- The three this project authored. They are here so the live cases cover all THIRTEEN clips --
	-- the pre-roll's own count among them -- and so a boar in this spec can reach the drag and the
	-- paddle. The "with no id" half is proved separately, by `withIds({})`, which builds its own
	-- config rather than leaning on what this table happens to leave out.
	crippleDrag = 20011,
	deathPaddleLeft = 20012,
	deathPaddleRight = 20013,
	-- The calm repertoire (task 117), here for the same reason: the live cases cover every clip the
	-- config declares, the pre-roll's own count among them.
	smell = 20014,
	grazeLoop = 20015,
	grazeChew = 20016,
	grazeStart = 20017,
	grazeEnd = 20018,
	digWalk = 20019,
}

-- Every one-shot `Body` can play, and the config row it reads. The names are the keys
-- `Body.attachSounds` puts in `handle.sounds`, so a renamed sound fails here rather than going quiet.
local ONE_SHOTS = {
	{ name = "sniff", spec = SOUND.SNIFF }, -- task 117: the head comes up
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
				-- The calm repertoire rides the same flag (task 117), and these runtimes are the only
				-- place a REAL head-lift -- and therefore a real sniff -- can happen in a spec.
				CALM = (function()
					local copy = table.clone(CONFIG.CALM)
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

	-- NOTHING MOVES INSIDE A SYNCHRONOUS SPEC, AND THE VOICE RATION ASKS WHAT IS MOVING (task 129).
	--
	-- A boar is driven by a `LinearVelocity` constraint (`Body.drive`), so its body only acquires a
	-- velocity when the PHYSICS ENGINE runs -- and a case that calls `runtime:step(DT)` two hundred
	-- times in one frame never lets it. Measured: a lone boar in FLEE was asking for 38 studs/s while
	-- its body reported 0.0, so `Runtime:_rationVoices` -- which since task 123 only gives a footstep
	-- slot to an animal that is actually moving ("a slot also only goes to an animal that would use
	-- it", measured there against 40 standing boars) -- silenced every animal in the world.
	--
	-- THAT RULE IS RIGHT and is not the thing to change: a boar wedged against a trunk should not
	-- play running footsteps. What is missing is the engine. This writes each body's velocity from
	-- the speed the Runtime asked for, which is exactly what the physics step would have produced,
	-- and it is the only honest way for a one-frame spec to test a rule about movement.
	local function stepMoving(runtime, handles, times: number?)
		for _ = 1, times or 1 do
			runtime:step(DT)
			for _, handle in ipairs(handles) do
				local status = runtime:statusOf(handle.id)
				if status ~= nil and handle.part.Parent ~= nil then
					handle.part.AssemblyLinearVelocity = Vector3.new(0, 0, -(status.want or 0))
				end
			end
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
			-- `FLIGHT.rear` at CRIPPLE_SPEED is the reaction's own length: long enough for a hunter
			-- to walk up and finish it, short enough that no boar circles for ever. 90 studs is the
			-- UNTAPERED flight; `Wound.flightStuds` tapers it past MORTAL, so one 55-point rump slug
			-- is given 81 and about 18 s (review round 2, note 1).
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
			-- The clip half of the name, which this case used not to assert at all (review round 2,
			-- note): `warmAssets` builds a track for every clip through `trackFor`, so after the
			-- pre-roll the handle holds one per entry in `MODEL.CLIPS` -- the thirteen, not the two
			-- or three a boar happens to play. That is the half of the measured 364 ms that was the
			-- animation and not the audio.
			-- The other half of the lateness, and the half no pure function can hold: a client fetches
			-- an asset when it is told to play it, so everything is played once, silently, when the coat
			-- goes on. This asserts what the warm-up leaves behind -- every sound back at its configured
			-- volume and nothing audible -- because a warm-up that never cooled would be a boar whose
			-- every sound is stuck at zero.
			local runtime = newRuntime(true, "BoarsShotWarm", true)
			local handle = runtime:spawn(Vector3.new(-20, GROUND_Y, -20))
			step(runtime, 2)
			local drawn = runtime:animationOf(handle.id)
			expect(drawn).to.be.ok() -- the coat is on, so the pre-roll has run
			local folder = soundsOf(handle) :: Instance
			local warm = 0
			for _, child in ipairs(folder:GetChildren()) do
				local sound = child :: Sound
				if sound.IsPlaying and sound.Volume == 0 then
					warm += 1
				end
			end
			-- NOTHING IS PRE-ROLLED ANY MORE, AND THAT IS THE POINT (task 126 round 2). The warm-up
			-- used to PLAY every sound at volume 0 to make the client fetch it; it now hands the list
			-- to `ContentProvider:PreloadAsync`, which fetches without playing. The Director's smoke
			-- counted 67 playing Sounds with 34 boars out and read it as the footstep ration failing
			-- -- it was this loop, 8 of every one of eleven sound names on one freshly-released wave.
			-- A silent Sound is still a voice, and a count nobody can read is a measurement nobody
			-- can use. So what is asserted is the opposite of what it was: no sound is playing
			-- silently, and the two things the pre-roll was FOR -- every track built, every volume at
			-- its configured value -- are checked exactly as before, below.
			expect(warm).to.equal(0)
			local clips = 0
			for _ in pairs(MODEL.CLIPS) do
				clips += 1
			end
			expect(drawn.tracks).to.equal(clips)
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
				string.format(
					"boar-shot: %d sound(s) pre-rolled (preloaded instead, task 126), all volumes back by %.2f s",
					warm,
					MODEL.WARM_SECONDS
				)
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

	describe("many animals must not sound like many animals", function()
		-- KAREN, 2026-10-04: "we need also think about sound when there is several walking and
		-- several sqeeng it could be anoying and shit sound / so we need realistic", and after
		-- playing the Forest Test on 2026-10-05: *"to many noise, when boars are walking and there
		-- is many only 1-2 sounds"*. Every animal has its own hooves, its own grunts and its own
		-- breathing; the rations are in `SOUND.CROWD` and these are the cases that hold them with
		-- real animals on a real plate.
		--
		-- `rationed` IS THE PARAMETER EVERY CASE BELOW TURNS, which is the only way both states are
		-- reachable while the shipped config sits at one of them. Off, every limit is `math.huge`,
		-- which is the world before task 120.
		-- THE AMBIENT VOICE IS OFF IN THE GAME, AND THESE CASES TURN IT ON BY PARAMETER (task 129).
		-- Karen, 2026-10-05: *"when they cross road or they close they don't make any pig sound
		-- besides walking"* and *"still to noisy"* -- so task 123 round 4 set `BREATH.enabled = false`
		-- and turned the grunt into a once-per-approach EVENT (`GRUNTS.ON_APPROACH`). The RATION is
		-- still a mechanism worth testing, and it cannot be tested against a cue that never fires, so
		-- the cases below switch the cue on in their own config exactly as the flag cases switch a
		-- flag on in theirs. What the game ships is asserted separately, further down.
		local function voicedSound()
			local sound = table.clone(CONFIG.SOUND)
			local breath = table.clone(CONFIG.SOUND.BREATH)
			breath.enabled = true
			sound.BREATH = breath
			local grunts = table.clone(CONFIG.SOUND.GRUNTS)
			grunts.enabled = true
			-- `ON_APPROACH = false` is the one word that brings the interval mode back, which the
			-- config's own comment says and which these rations were measured against.
			grunts.ON_APPROACH = false
			sound.GRUNTS = grunts
			return sound
		end

		local function looseSound()
			local sound = voicedSound()
			local crowd = table.clone(CONFIG.SOUND.CROWD)
			crowd.VOICES_PER_SOUNDER = math.huge
			crowd.GRUNTS_PER_SOUNDER = math.huge
			crowd.MAX_STEP_VOICES = math.huge
			crowd.MAX_BREATH_VOICES = math.huge
			crowd.MAX_MUTTER_VOICES = math.huge
			crowd.GRUNT_GAP_SECONDS = 0 -- task 123 round 2: no world-wide gap between grunt starts
			sound.CROWD = crowd
			return sound
		end

		local function crowdRuntime(name: string, rationed: boolean)
			local world = buildWorld(true, name)
			-- A HUNTER TO RUN FROM, so the animals are really moving and really have footsteps to
			-- play: a standing sounder would pass a footstep cap by making no footsteps at all.
			world.threats = function()
				-- INSIDE `DETECT_RADIUS`, or nothing runs and a footstep cap proves nothing: the
				-- sounder is dropped at z -10 and the driver stands 18 studs up-field of it.
				return { { position = Vector3.new(0, GROUND_Y, 8), kind = "driver" } }
			end
			world.config.KINDS = { ENABLED = true } -- a sow and her young, which is what a sounder is
			world.config.SOUND = voicedSound() -- the cue exists on BOTH sides; only the ration differs
			if not rationed then
				world.config.SOUND = looseSound()
			end
			local runtime = Boar.newRuntime(world)
			local template = makeTemplate()
			runtime:setModelSource(function()
				return template
			end, function(clip: string)
				return FAKE_IDS[clip]
			end)
			return runtime
		end

		-- Six animals, six seconds of running from a driver: the most footstep loops heard AT ONCE
		-- across the whole sounder, how many animals were ever heard at all, and how many BREATHS
		-- the six of them got out between them.
		--
		-- THE BREATH IS THE A/B THIS TASK TURNS, and it is a real one. A fleeing sounder runs at 18
		-- to 38 studs/s against `BREATH.MIN_SPEED` = 11, so every member is working and every member
		-- wants to breathe every 1.5-3 s -- so the unrationed run really does make six animals'
		-- worth of noise, and the rationed one cannot. Task 120's own note is why the FOOTSTEP half
		-- stays a regression guard rather than an A/B: a follower holds its slot relative to the
		-- leader, so the leader is often the only member whose setpoint reaches `STEPS.MIN_SPEED`.
		local function runSounder(name: string, rationed: boolean): (number, number, number)
			local runtime = crowdRuntime(name, rationed)
			local handles = runtime:spawnSounder(Vector3.new(0, GROUND_Y, -10), 6, 10)
			expect(#handles).to.equal(6)
			warmedUp(runtime)
			local worstLoops, heard = 0, {}
			for _ = 1, math.ceil(6 / DT) do
				stepMoving(runtime, handles)
				local loops = 0
				for _, handle in ipairs(handles) do
					local playing = #playingLoops(handle)
					loops += playing
					if playing > 0 then
						heard[handle.id] = true
					end
				end
				worstLoops = math.max(worstLoops, loops)
			end
			local fleeing, voices, breaths = 0, 0, 0
			for _, handle in ipairs(handles) do
				if handle.state() == "FLEE" then
					fleeing += 1
				end
				breaths += handle.soundPlays.breath or 0
				if heard[handle.id] then
					voices += 1
				end
			end
			-- THE RECORD'S OWN BOUND, which is the exact one: whatever happened to the loops, a
			-- rationed sounder never held more voices than the config allows it. The loose run has
			-- no bound to check -- that is what makes it the other half of the A/B.
			local record = runtime:sounderOf(handles[1].id)
			expect(record).to.be.ok()
			if rationed then
				expect(#record.voiceIds <= SOUND.CROWD.VOICES_PER_SOUNDER).to.equal(true)
			else
				expect(#record.voiceIds).to.equal(6)
			end
			-- They really were running from the driver, or none of this measured anything. NOTHING
			-- IS CLAIMED HERE ABOUT GRUNTS: a running herd is the one that cannot grunt
			-- (`GRUNTS.MAX_SPEED` = 6 against a flee at 18 or 38), which is exactly why counting
			-- them here could not fail, and why that ration has its own case on a CALM herd below.
			expect(fleeing).to.equal(6)
			runtime:destroy()
			return worstLoops, voices, breaths
		end

		-- TWELVE LONE ANIMALS, which is what a released group of twenty actually becomes. MEASURED
		-- in the Forest Test with 23 boars out: three sounders holding 3, 3 and 4, and THIRTEEN lone
		-- boars -- so this is the case the world ceiling exists for, and the one a per-sounder rule
		-- cannot touch at all. Returns the most footstep loops heard at once and the breaths between
		-- them.
		local function runLoose(name: string, rationed: boolean): (number, number)
			local world = buildWorld(true, name)
			world.threats = function()
				-- INSIDE `SENSE.DETECT_RADIUS` (40) OF ALL TWELVE, or most of them never run and a
				-- footstep ceiling proves nothing: the farthest animal below stands 38.5 studs from
				-- this. They start at z 20 rather than 0 so six seconds of fleeing cannot carry any
				-- of them over the plate's exit line at z -40.
				return { { position = Vector3.new(0, GROUND_Y, 40), kind = "driver" } }
			end
			-- ROOM FOR TWELVE (task 129). `Boar.CONFIG.maxBoars` is 8 -- the drive's own ceiling,
			-- because a real drive releases a sounder at a time -- and a WORLD-WIDE voice ration only
			-- means anything above it. Raised here by world config, the way the Forest Test raises it
			-- (`Data.MAX_BOARS`); before task 129 this case asked for twelve and got eight.
			world.config.maxBoars = 20
			world.config.SOUND = voicedSound() -- the cue exists on both sides; only the ration differs
			if not rationed then
				world.config.SOUND = looseSound()
			end
			local runtime = Boar.newRuntime(world)
			local template = makeTemplate()
			runtime:setModelSource(function()
				return template
			end, function(clip: string)
				return FAKE_IDS[clip]
			end)
			-- TWELVE IN A WORLD THAT ALLOWS TWELVE (task 129). `Boar.CONFIG.maxBoars` is 8 -- the
			-- drive's own ceiling, because a real drive releases a sounder at a time -- and this case
			-- is about a WORLD-WIDE voice ration, which only means anything above that ceiling. The
			-- Forest Test raises it the same way, by world config (`Data.MAX_BOARS`).
			local handles = {}
			for index = 1, 12 do
				-- Spread along the line so each is its OWN distance from the driver -- 20 studs for
				-- the middle pair out to 38.5 for the ends. The ceiling is awarded nearest-first,
				-- and animals stacked on one spot would not test that at all.
				table.insert(handles, runtime:spawn(Vector3.new((index - 6.5) * 6, GROUND_Y, 20)))
			end
			warmedUp(runtime)
			local worstLoops = 0
			for _ = 1, math.ceil(6 / DT) do
				stepMoving(runtime, handles)
				local loops = 0
				for _, handle in ipairs(handles) do
					loops += #playingLoops(handle)
				end
				worstLoops = math.max(worstLoops, loops)
			end
			local breaths, fleeing = 0, 0
			for _, handle in ipairs(handles) do
				breaths += handle.soundPlays.breath or 0
				if handle.state() == "FLEE" then
					fleeing += 1
				end
			end
			-- NONE OF THEM IS IN A SOUNDER, which is the whole point of this case.
			expect(runtime:sounderOf(handles[1].id)).to.equal(nil)
			expect(fleeing >= 6).to.equal(true)
			runtime:destroy()
			return worstLoops, breaths
		end

		-- A CALM sounder, where a grunt can actually happen, rationed or loose (task 120, review
		-- round 1, finding 1: both states reachable without touching the config the game ships).
		local function gruntsIn(name: string, seconds: number, rationed: boolean): (number, number)
			local world = buildWorld(true, name) -- its own `threats()` is empty: nothing to flee
			world.config.KINDS = { ENABLED = true }
			world.config.SOUND = voicedSound() -- see `voicedSound`: the game ships this cue OFF
			if not rationed then
				world.config.SOUND = looseSound()
			end
			local runtime = Boar.newRuntime(world)
			local template = makeTemplate()
			runtime:setModelSource(function()
				return template
			end, function(clip: string)
				return FAKE_IDS[clip]
			end)
			local handles = runtime:spawnSounder(Vector3.new(0, GROUND_Y, 20), 6, 10)
			warmedUp(runtime)
			for _ = 1, math.ceil(seconds / DT) do
				step(runtime)
			end
			local grunts, members = 0, 0
			for _, handle in ipairs(handles) do
				grunts += handle.soundPlays.grunt or 0
				members += 1
			end
			runtime:destroy()
			return grunts, members
		end

		it("gives a whole sounder one or two sets of hooves, and rations its breathing", function()
			-- THE RULES THEMSELVES ARE PURE and are driven both ways in the pure cases above; what
			-- six real animals add is that nothing else in the Runtime undoes them.
			local capped, voices, breaths = runSounder("BoarsCrowdSteps", true)
			local _, looseVoices, looseBreaths = runSounder("BoarsCrowdLoose", false)

			-- NO MORE ANIMALS OF ONE SOUNDER ARE EVER HEARD THAN IT HAS VOICES. The exact bound
			-- is asserted on the record itself inside `runSounder`; what these two say is that
			-- nothing in the Runtime hands the loop to a third animal.
			expect(voices <= SOUND.CROWD.MAX_STEP_VOICES).to.equal(true)
			expect(capped <= SOUND.CROWD.MAX_STEP_VOICES).to.equal(true)
			TestKit.note(
				string.format(
					"boar-crowd DIAG: breaths capped=%d loose=%d, voices capped=%d loose=%d",
					breaths,
					looseBreaths,
					voices,
					looseVoices
				)
			)
			-- THE HERD REALLY WAS WORKING, or the breath numbers mean nothing. Four and not six:
			-- how many 1.5-3 s intervals fit in six seconds is decided by physics ramping six
			-- bodies up to flee speed, not by the seeded Random, so the floor is the loose one.
			expect(looseBreaths >= 4).to.equal(true)
			-- ...AND THE RATION REMOVED BREATHS, which is this task's A/B: six animals running
			-- breathe six animals' worth unrationed, and at most two of them rationed.
			expect(breaths < looseBreaths).to.equal(true)
			-- ...WITHOUT SILENCING THE HERD. A mute herd is a worse fault than a noisy one.
			expect(breaths >= 1).to.equal(true)
			expect(looseVoices >= 1).to.equal(true)
			TestKit.note(
				string.format(
					"boar-crowd: six fleeing boars -- %d footstep loop(s) at once from %d animal(s), %d breath(s) against %d loose",
					capped,
					voices,
					breaths,
					looseBreaths
				)
			)
		end)

		it("rations TWELVE LONE boars too, nearest the hunter first", function()
			-- THE CASE THE FOREST TEST FOUND (task 123). Karen: "to many noise, when boars are
			-- walking and there is many only 1-2 sounds". A per-sounder ration was already shipped
			-- and she still heard twenty animals, because a release of twenty sheds its members: 23
			-- boars out were three sounders of 3, 3 and 4 plus THIRTEEN lone animals, each with a
			-- full voice. So the ceiling is world-wide and keyed on distance to a hunter.
			local capped, breaths = runLoose("BoarsLooseCapped", true)
			local loose, looseBreaths = runLoose("BoarsLooseLoud", false)

			-- TWELVE ANIMALS REALLY DID MAKE MORE THAN THREE ANIMALS' NOISE unrationed, or the
			-- ceiling below is being compared with nothing.
			expect(loose > SOUND.CROWD.MAX_STEP_VOICES).to.equal(true)
			-- ...AND THE CEILING HELD: never more loops at once than the world allows.
			expect(capped <= SOUND.CROWD.MAX_STEP_VOICES).to.equal(true)
			expect(breaths < looseBreaths).to.equal(true)
			-- ...and something was still heard, which is the point of awarding it nearest-first.
			expect(capped >= 1).to.equal(true)
			TestKit.note(
				string.format(
					"boar-crowd: twelve lone boars -- %d footstep loop(s) at once against %d loose, %d breath(s) against %d",
					capped,
					loose,
					breaths,
					looseBreaths
				)
			)
		end)

		it("brings a footstep loop back when something else has stopped it", function()
			-- REVIEW ROUND 1, NOTE, and the reason the live footstep numbers were so thin: the
			-- silent pre-roll plays every sound at volume 0 and `Body.coolAssets` STOPS the ones it
			-- finds there, while `stepSound` only ever played a loop on a GAIT CHANGE -- so an
			-- animal whose gait did not change across that moment ran silently for ever. It matters
			-- more since this task, because a sounder's hooves are now one animal's: the silent one
			-- could be the whole herd.
			--
			-- Driven exactly as it happens: find the loop a running boar is playing, STOP it the way
			-- the cool-down does, step once, and it is back.
			local world = buildWorld(true, "BoarsLoopBack")
			world.threats = function()
				return { { position = Vector3.new(0, GROUND_Y, 30), kind = "driver" } }
			end
			local runtime = Boar.newRuntime(world)
			local template = makeTemplate()
			runtime:setModelSource(function()
				return template
			end, function(clip: string)
				return FAKE_IDS[clip]
			end)
			local handle = runtime:spawn(Vector3.new(0, GROUND_Y, 0))
			warmedUp(runtime)

			local playing = nil
			for _ = 1, math.ceil(4 / DT) do
				stepMoving(runtime, { handle })
				local loops = playingLoops(handle)
				if #loops > 0 then
					playing = loops[1]
					break
				end
			end
			local status = runtime:statusOf(handle.id)
			TestKit.note(
				string.format(
					"boar-shot DIAG: loop=%s sounds=%d state=%s want=%.1f statusSpeed=%.1f at=(%.0f,%.0f) stepClip=%s steps_run playing=%s vol=%.2f",
					tostring(playing),
					#((soundsOf(handle) :: Instance):GetChildren()),
					tostring(status and status.state),
					(status and status.want) or -1,
					(status and status.speed) or -1,
					handle.part.Position.X,
					handle.part.Position.Z,
					tostring(handle.stepClip),
					tostring((soundNamed(handle, "steps_run") :: Sound).IsPlaying),
					(soundNamed(handle, "steps_run") :: Sound).Volume
				)
			)
			-- It really was making footsteps, or this proves nothing.
			expect(playing).to.be.ok()
			local loop = soundNamed(handle, playing) :: Sound
			loop:Stop()
			expect(audible(loop)).to.equal(false)
			stepMoving(runtime, { handle })
			expect(audible(loop)).to.equal(true)
			TestKit.note(string.format("boar-shot: %s came back the step after it was stopped", playing))
			runtime:destroy()
		end)

		it("rations a CALM sounder's grunts: the GROUP grunts, once per interval", function()
			-- KAREN, 2026-10-04: "several sqeeng it could be anoying and shit sound". A herd mutters,
			-- it does not chorus. Twenty seconds is several of each animal's own 3-8 s intervals, so
			-- six boars left alone have plenty to say.
			--
			-- THE GAP IS THE `GRUNTS` BAND ITSELF (task 123), not a number of its own: after
			-- `GRUNTS_PER_SOUNDER` grunts the group waits out one 3-8 s interval, so the herd grunts
			-- at the rate ONE animal would. The old `SOUNDER_GRUNT_GAP` was a flat 2.5 s whatever
			-- the band said, which is a herd muttering every 2.5 s for ever.
			local seconds = 20
			local capped, members = gruntsIn("BoarsGruntCapped", seconds, true)
			local uncapped = gruntsIn("BoarsGruntLoose", seconds, false)
			expect(members).to.equal(6)

			-- THE HERD REALLY WAS TALKING, or nothing below means anything.
			expect(uncapped >= 6).to.equal(true)
			-- THE RATION REMOVED GRUNTS, which is the A/B it exists for...
			expect(capped < uncapped).to.equal(true)
			-- ...down to the rate it promises: at most `GRUNTS_PER_SOUNDER` per MIN_SECONDS, plus
			-- one for the interval that was already running when the clock started.
			-- ...AND THE WORLD-WIDE GAP CAN ONLY MAKE IT FEWER, so the per-sounder bound is still the
			-- ceiling to assert (task 123 round 2).
			local most = math.ceil(seconds / SOUND.GRUNTS.MIN_SECONDS) * SOUND.CROWD.GRUNTS_PER_SOUNDER + 1
			expect(capped <= most).to.equal(true)
			-- ...and it did NOT silence the sounder: a mute herd would be a worse fault than a noisy
			-- one, and a grunt that loses the slot is skipped rather than queued, so the herd keeps
			-- talking at the rationed rate.
			expect(capped >= 1).to.equal(true)
			TestKit.note(
				string.format(
					"boar-crowd: a calm sounder over %d s -- %d grunt(s) at %d per %.0f-%.0f s band against %d loose",
					seconds,
					capped,
					SOUND.CROWD.GRUNTS_PER_SOUNDER,
					SOUND.GRUNTS.MIN_SECONDS,
					SOUND.GRUNTS.MAX_SECONDS,
					uncapped
				)
			)
		end)

		it("lets two squeals be heard and SKIPS the third, rather than queuing it", function()
			local runtime = crowdRuntime("BoarsCrowdSqueals", true)
			local handles = runtime:spawnSounder(Vector3.new(0, GROUND_Y, -10), 6, 10)
			warmedUp(runtime)

			-- Three animals shot in the same instant. Each would cry; the world has two voices.
			local cried = 0
			for index = 1, 3 do
				local handle = handles[index]
				expect(runtime:takeHit(handle.part, { zone = "legs", ammo = "Pellet", pellets = 1, at = 0 })).to.equal(
					true
				)
				step(runtime)
				cried += handle.soundPlays.cry or 0
			end
			expect(cried).to.equal(SOUND.CROWD.MAX_SQUEALS)
			expect(runtime:stats().squealsSkipped).to.equal(1)

			-- SKIPPED, NOT QUEUED: the animal that was not heard stays not heard. Stepping on past
			-- the window must not make its cry arrive late.
			step(runtime, math.ceil((SOUND.CROWD.SQUEAL_SECONDS + 0.5) / DT))
			local after = 0
			for index = 1, 3 do
				after += handles[index].soundPlays.cry or 0
			end
			expect(after).to.equal(cried)
			TestKit.note(
				string.format(
					"boar-crowd: three animals hit at once -- %d heard, %d skipped and never queued",
					cried,
					runtime:stats().squealsSkipped
				)
			)
			runtime:destroy()
		end)
	end)

	describe("the hit sound plays once, however long the animal takes to die", function()
		it("is still one play after a rump wound finishes the animal later", function()
			-- KAREN, 2026-10-04: "when I hit but it doesn't die imediatly after it falls I can hear
			-- same hit sound shoudlnt be like that". A rump slug is MORTAL and not lethal -- the case
			-- above pins that -- so this is exactly her shot: it is hit, it runs, and the wound
			-- finishes it some seconds later.
			local runtime = newRuntime(true, "SoundOnce", true)
			local handle = runtime:spawn(Vector3.new(0, GROUND_Y, 0))
			warmedUp(runtime) -- the pre-roll plays everything at volume 0 and does NOT count
			expect(handle.soundPlays.hit).to.equal(nil)

			-- THE SOFTENING REACHED THE INSTANCE, not just the table: the filter that takes the slap
			-- off the hit is an EqualizerSoundEffect built beside the Sound, and this is the only
			-- place that reads one back off a real sound.
			local hitSound = soundNamed(handle, "hit") :: Sound
			local eq = hitSound:FindFirstChildOfClass("EqualizerSoundEffect") :: EqualizerSoundEffect
			expect(eq).to.be.ok()
			expect(eq.HighGain).to.equal(SOUND.HIT.eq.high)
			-- A Sound's Volume is a float32, so the config's 0.45 reads back as 0.44999998807907104.
			expect(math.abs(hitSound.Volume - SOUND.HIT.volume) < 1e-6).to.equal(true)

			expect(runtime:takeHit(handle.part, { zone = "rear", ammo = "Slug", pellets = 1, at = 0 })).to.equal(true)
			step(runtime, 3)
			-- IT IS NOT DEAD YET, which is the whole premise of her report.
			expect(handle.part:GetAttribute("Carcass")).never.to.equal(true)
			-- TASK 120, Karen's third listen: the bullet hit is OFF, so the only thing a wounding
			-- shot makes is the animal's own answer. The cue she kept hearing at the fall cannot
			-- happen now, because neither impact sound exists to play.
			expect(handle.soundPlays.hit).to.equal(nil)
			expect(handle.soundPlays.cry).to.equal(1)
			expect(handle.soundPlays.death).to.equal(nil)

			local deadline = os.clock() + 30
			while os.clock() < deadline and handle.part:GetAttribute("Carcass") ~= true do
				step(runtime)
				RunService.Heartbeat:Wait()
			end
			step(runtime, 3)
			expect(handle.part:GetAttribute("Carcass")).to.equal(true)

			-- THE CLAIM, as it stands after her third listen: ONE cry when it is hit, ONE squeal
			-- when it dies, and no impact sound at either moment, however late the death arrives.
			expect(handle.soundPlays.hit).to.equal(nil)
			expect(handle.soundPlays.fall).to.equal(nil)
			expect(handle.soundPlays.cry).to.equal(1)
			expect(handle.soundPlays.death).to.equal(1)
			TestKit.note(
				string.format(
					"boar-sound: a rump wound -- cry %d, death %d, hit %s, fall %s",
					handle.soundPlays.cry,
					handle.soundPlays.death,
					tostring(handle.soundPlays.hit),
					tostring(handle.soundPlays.fall)
				)
			)
			runtime:destroy()
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

		it("gives the sniff, the hit and the fall pitches of their own, and nothing else one", function()
			-- THE DATA HALF ONLY, and said so (review round 3, the Director's sweep): the arithmetic
			-- `playOneShot` does with this -- `(spec.pitch or 1) * jitteredPitch(...)` -- is asserted
			-- END TO END in `boar_calm.spec`, "the sniff is played HIGH", which reads the live
			-- `Sound.PlaybackSpeed` after a real head-lift. A case that multiplied the two itself
			-- here would pass with that multiplication deleted.
			expect(SOUND.SNIFF.pitch > 1.1).to.equal(true)
			-- ...AND TWO ARE PITCHED DOWN (task 120). Karen, 2026-10-04: "sound has to be lover and
			-- softer", and the fall "I can hear same hit sound". Both are below 1, and the FALL is
			-- below the HIT: a body landing is the heaviest, dullest thing a boar does.
			expect(SOUND.HIT.pitch < 1).to.equal(true)
			expect(SOUND.FALL.pitch < SOUND.HIT.pitch).to.equal(true)
			local pitched = { sniff = true, hit = true, fall = true }
			for _, row in ipairs(ONE_SHOTS) do
				if not pitched[row.name] then
					expect(row.spec.pitch).to.equal(nil)
				end
			end
		end)

		it("has both impact cues OFF, by data and not by deletion", function()
			-- KAREN, 2026-10-04 (third listen): "so die sound still there / I hit once in back part,
			-- after while fallowed it falled on side and was sound of hit or whatever, it shouldnt
			-- be like that ... I think we can remove hit sound for now". Both the bullet and the
			-- body-fall thud are off, and so is the breath that followed the death.
			expect(SOUND.HIT.enabled).to.equal(false)
			expect(SOUND.FALL.enabled).to.equal(false)
			expect(SOUND.LAST_BREATH.enabled).to.equal(false)
			-- ...AND EVERY ONE OF THEM IS STILL FULLY DESCRIBED, which is what "for now" means: one
			-- word brings any of them back, with the id, the volume and the filter it was tuned to.
			for _, row in ipairs({ SOUND.HIT, SOUND.FALL, SOUND.LAST_BREATH }) do
				expect(row.id).to.be.ok()
				expect(row.volume > 0).to.equal(true)
				expect(row.audibleStuds > 0).to.equal(true)
			end
			-- The reaction and the death are NOT off: she kept those.
			expect(SOUND.CRY.enabled).to.equal(nil)
			expect(SOUND.DEATH.enabled).to.equal(nil)
		end)

		it("makes a death ONE SHORT squeal rather than a scream", function()
			-- "when it dies could be sqeeck sound short". The Director's band is 0.4 to 0.8 s, with a
			-- fade so it ends instead of being chopped, and the samples are the squeals rather than
			-- the beast-like scream the row carried before.
			expect(SOUND.DEATH.cut >= 0.4).to.equal(true)
			expect(SOUND.DEATH.cut <= 0.8).to.equal(true)
			expect(SOUND.DEATH.fade > 0).to.equal(true)
			expect(SOUND.DEATH.fade < SOUND.DEATH.cut).to.equal(true)
			for _, id in ipairs(SOUND.DEATH.ids) do
				local shared = false
				for _, cryId in ipairs(SOUND.CRY.ids) do
					shared = shared or cryId == id
				end
				expect(shared).to.equal(true) -- a squeal, out of the set Karen already accepted
			end
			-- THE FADE IS A RAMP, not a cliff: full volume until it starts, nothing at the end.
			expect(Boar.cutVolume(SOUND.DEATH.cut, SOUND.DEATH)).to.equal(SOUND.DEATH.volume)
			expect(Boar.cutVolume(SOUND.DEATH.fade, SOUND.DEATH)).to.equal(SOUND.DEATH.volume)
			local half = Boar.cutVolume(SOUND.DEATH.fade / 2, SOUND.DEATH)
			expect(math.abs(half - SOUND.DEATH.volume / 2) < 1e-9).to.equal(true)
			expect(Boar.cutVolume(0, SOUND.DEATH)).to.equal(0)
		end)

		it("gives each kind a voice of its own: a cub thin, a male deep", function()
			-- KAREN: "pown should sqeen differen, male differen female different" (pown = piglet).
			local male = Boar.voicePitch("death", "male", SOUND.DEATH, CONFIG)
			local female = Boar.voicePitch("death", "female", SOUND.DEATH, CONFIG)
			local cub = Boar.voicePitch("death", "cub", SOUND.DEATH, CONFIG)
			expect(male < female).to.equal(true)
			expect(female < cub).to.equal(true)
			expect(male <= 0.85).to.equal(true)
			expect(cub >= 1.3).to.equal(true)

			-- IT IS A VOICE, so it is the three cues that come OUT of the animal and nothing else:
			-- its hooves, its breathing and the sniff are the world and are untouched by kind.
			for _, name in ipairs({ "cry", "death", "grunt" }) do
				expect(SOUND.VOICE.APPLIES[name]).to.equal(true)
			end
			expect(Boar.voicePitch("breath", "cub", SOUND.BREATH, CONFIG)).to.equal(1)
			expect(Boar.voicePitch("sniff", "cub", SOUND.SNIFF, CONFIG)).to.equal(SOUND.SNIFF.pitch)

			-- ...AND A SAMPLE OF ITS OWN WHERE THERE IS A BETTER ONE: the only beast-like scream in
			-- the verified set is the male's death. Nothing here can audition a library, so every id
			-- is one this project has already listened to, and every one is live in `Assets.ROWS`.
			local maleDeath = Boar.voiceIds("death", "male", SOUND.DEATH, CONFIG)
			local cubDeath = Boar.voiceIds("death", "cub", SOUND.DEATH, CONFIG)
			expect(#maleDeath).to.equal(1)
			expect(maleDeath[1] ~= cubDeath[1]).to.equal(true)
			-- With no kind, or with the voice off, every cue answers exactly what the row says.
			expect(Boar.voicePitch("death", nil, SOUND.DEATH, CONFIG)).to.equal(1)
			expect(Boar.voiceIds("death", nil, SOUND.DEATH, CONFIG)).to.equal(SOUND.DEATH.ids)
			TestKit.note(string.format("boar-sound: voices -- male %.2f, sow %.2f, cub %.2f", male, female, cub))
		end)

		it("turns a far animal down, and never below the floor", function()
			-- "we need also think about sound when there is several walking ... we need realistic".
			-- Inside FAR_STUDS a voice is its own volume; beyond it, it fades to FAR_VOLUME and
			-- stops there, so a sounder at the far end of the field is background.
			local crowd = SOUND.CROWD
			expect(Boar.farScale(0, CONFIG)).to.equal(1)
			expect(Boar.farScale(crowd.FAR_STUDS, CONFIG)).to.equal(1)
			expect(Boar.farScale(crowd.FAR_STUDS + crowd.FAR_FADE_STUDS, CONFIG)).to.equal(crowd.FAR_VOLUME)
			expect(Boar.farScale(10000, CONFIG)).to.equal(crowd.FAR_VOLUME)
			local half = Boar.farScale(crowd.FAR_STUDS + crowd.FAR_FADE_STUDS / 2, CONFIG)
			expect(half < 1 and half > crowd.FAR_VOLUME).to.equal(true)
			-- A boar nobody is near has nothing to be far from.
			expect(Boar.farScale(nil, CONFIG)).to.equal(1)
		end)

		local function crowdOff()
			local sound = table.clone(SOUND)
			local crowd = table.clone(SOUND.CROWD)
			crowd.ENABLED = false
			sound.CROWD = crowd
			local copy = table.clone(CONFIG)
			copy.SOUND = sound
			return copy
		end

		it("gives a sounder's hooves and breath to its few voice holders", function()
			-- KAREN, 2026-10-05: "to many noise, when boars are walking and there is many only 1-2
			-- sounds". Pure, so both states are reachable while the config sits at one of them --
			-- twenty Brains cannot be made to run abreast on command, and the live cases say
			-- nothing undoes this.
			local off = crowdOff()
			expect(Boar.hasVoice({ "a", "b" }, "a", CONFIG)).to.equal(true)
			expect(Boar.hasVoice({ "a", "b" }, "b", CONFIG)).to.equal(true)
			expect(Boar.hasVoice({ "a", "b" }, "c", CONFIG)).to.equal(false)
			-- A herd with no list this tick silences nobody: a missing sound is the worse fault.
			expect(Boar.hasVoice(nil, "c", CONFIG)).to.equal(true)
			expect(Boar.hasVoice({}, "c", CONFIG)).to.equal(true)
			-- ...and with the ration off every animal is its own voice, exactly as before task 120.
			expect(Boar.hasVoice({ "a", "b" }, "c", off)).to.equal(true)
		end)

		it("picks the holders from the FRONT, keeps them, and refills when one goes", function()
			local ranked = { "front", "second", "third", "fourth" }
			-- ONE VOICE PER FLOCK IS WHAT THE GAME SHIPS (task 123 round 4). Karen: *"to many noise,
			-- when boars are walking and there is many only 1-2 sounds"*, and after a further round
			-- *"still to noisy"* -- so `VOICES_PER_SOUNDER` came down to 1. The RULE is about picking
			-- and keeping holders whatever that number is, so it is driven here with 2, by parameter,
			-- and the shipped value is asserted on its own.
			expect(SOUND.CROWD.VOICES_PER_SOUNDER).to.equal(1)
			local twoVoices = table.clone(CONFIG)
			local crowd = table.clone(CONFIG.SOUND.CROWD)
			crowd.VOICES_PER_SOUNDER = 2
			local sound = table.clone(CONFIG.SOUND)
			sound.CROWD = crowd
			twoVoices.SOUND = sound
			local first = Boar.voiceHolders(nil, "front", ranked, twoVoices)
			expect(#first).to.equal(2)
			expect(first[1]).to.equal("front")
			expect(first[2]).to.equal("second")
			-- STICKY: the ranking changed under them, and they keep their loops. A footstep loop
			-- handed between jostling animals stops and restarts, which is worse than one a few
			-- studs behind the front.
			local jostled = Boar.voiceHolders(first, "front", { "third", "front", "second", "fourth" }, twoVoices)
			expect(jostled[1]).to.equal("front")
			expect(jostled[2]).to.equal("second")
			-- A HOLDER THAT DIED OR LEFT IS REPLACED, from the front of what is left, so the herd
			-- never walks on in silence.
			local refilled = Boar.voiceHolders(first, "front", { "front", "third", "fourth" }, twoVoices)
			expect(#refilled).to.equal(2)
			expect(refilled[1]).to.equal("front")
			expect(refilled[2]).to.equal("third")
			-- A NEW LEADER TAKES ONE: the animal the herd steers by is the one it is heard by.
			local promoted = Boar.voiceHolders(first, "fourth", ranked, twoVoices)
			expect(promoted[1]).to.equal("fourth")
			-- ...and with the ration off nobody is held back at all.
			expect(#Boar.voiceHolders(nil, "front", ranked, crowdOff())).to.equal(4)
		end)

		it("hands the world's few voices to the animals NEAREST a hunter", function()
			-- MEASURED in the Forest Test: 23 boars out were three sounders of 3, 3 and 4 plus
			-- thirteen LONE animals, so a per-sounder ration governed ten of twenty-three and Karen
			-- heard 13 footstep loops at once. The ceiling is keyed on the one thing every animal
			-- has -- how far it is from the man listening.
			local rows = {
				{ id = "far", distance = 300 },
				{ id = "near", distance = 10 },
				{ id = "middle", distance = 90 },
			}
			local two = Boar.nearestVoices(rows, 2)
			expect(two.near).to.equal(true)
			expect(two.middle).to.equal(true)
			expect(two.far).to.equal(nil)
			-- A ceiling of nothing silences everything, and no ceiling silences nobody.
			expect(next(Boar.nearestVoices(rows, 0))).to.equal(nil)
			local all = Boar.nearestVoices(rows, math.huge)
			expect(all.near and all.middle and all.far).to.equal(true)
			-- A TIE IS BROKEN BY ID, so the set is the same every step and a spec can drive it.
			local tied = Boar.nearestVoices({
				{ id = "b", distance = 5 },
				{ id = "a", distance = 5 },
			}, 1)
			expect(tied.a).to.equal(true)
			expect(tied.b).to.equal(nil)
		end)

		it("counts only the squeals that are still sounding", function()
			-- The world-wide cap is two AT ONCE, so the count has to forget the ones that ended.
			expect(Boar.squealsSounding({}, 100)).to.equal(0)
			expect(Boar.squealsSounding({ 99, 101, 102 }, 100)).to.equal(2)
			expect(Boar.squealsSounding({ 99, 99.5 }, 100)).to.equal(0)
			expect(SOUND.CROWD.MAX_SQUEALS).to.equal(2)
		end)

		it("keeps the fall from sounding like the hit, which is what Karen heard", function()
			-- MEASURED FIRST (task 120), by counting every one-shot's `Played` through a real
			-- wounding shot and the bleed-out after it: `hit@1.18 cry@1.18 ... death@26.16
			-- fall@26.16 lastBreath@27.16`, counts hit=1 cry=1 death=1 fall=1. So nothing replays
			-- the hit -- the sound at the fall IS `FALL`, and "Body Fall Gooshy Mud 2" is a wet body
			-- impact one id from the hit's "Body Hit Wet 7", out of the same pack.
			--
			-- They can only be told apart by their DIALS, so this is what holds them apart: the fall
			-- is quieter AND lower than the hit, and both have the top cut off them. Nobody in this
			-- toolchain can hear either sample; what a spec can do is refuse to let them drift back
			-- into being the same noise.
			expect(SOUND.FALL.id ~= SOUND.HIT.id).to.equal(true)
			expect(SOUND.FALL.volume < SOUND.HIT.volume).to.equal(true)
			expect(SOUND.FALL.pitch < SOUND.HIT.pitch).to.equal(true)
			for _, row in ipairs({ SOUND.HIT, SOUND.FALL }) do
				expect(row.eq).to.be.ok()
				expect(row.eq.high < -6).to.equal(true) -- the slap lives in the highs
				expect(row.eq.high >= -80).to.equal(true) -- EqualizerSoundEffect's own floor
			end
			-- AND SOFTER THAN IT WAS: 0.8 and 0.7 are the volumes Karen asked to come down.
			expect(SOUND.HIT.volume < 0.8).to.equal(true)
			expect(SOUND.FALL.volume < 0.7).to.equal(true)
			TestKit.note(
				string.format(
					"boar-sound: hit vol %.2f pitch %.2f high %+d dB; fall vol %.2f pitch %.2f high %+d dB",
					SOUND.HIT.volume,
					SOUND.HIT.pitch,
					SOUND.HIT.eq.high,
					SOUND.FALL.volume,
					SOUND.FALL.pitch,
					SOUND.FALL.eq.high
				)
			)
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
		it("lets a waiting hunter HEAR the approach long before he sees it", function()
			-- KAREN, 2026-10-04: "and when its verry fal I cant hear them / when close only" -- and
			-- her scene from task 116: "hunter waiting and hear something comming and then boars are
			-- visible running, walking".
			--
			-- THE CUE ORDER TURNED OVER IN TASK 123, and this case asserted the old one. Karen, after
			-- playing the forest: *"when they cross road or they close they don't make any pig sound
			-- besides walking / and I hear only when it;s close inaf to me if it's far away I don't
			-- hear"*. A hoof on soil does not carry 130 studs and a pig's voice does -- so the VOICE
			-- is the warning that reaches him first and the hooves are the arrival.
			local steps = SOUND.STEPS
			local far = SOUND.GRUNTS
			expect(far.audibleStuds >= 120).to.equal(true)
			expect(Boar.heardAt(far, 100, CONFIG) > 0.15).to.equal(true)
			expect(Boar.heardAt(far, far.audibleStuds - 1, CONFIG) > 0).to.equal(true)
			expect(Boar.heardAt(far, far.audibleStuds, CONFIG)).to.equal(0)
			-- FAINT FIRST, GROWING: the same cue is several times louder by the time it is close.
			expect(Boar.heardAt(far, 30, CONFIG) > 3 * Boar.heardAt(far, 110, CONFIG)).to.equal(true)
			-- ...and the hooves are the CLOSE half of the same sentence: they arrive much later.
			expect(steps.run.audibleStuds < far.audibleStuds).to.equal(true)
			expect(Boar.heardAt(steps.run, 100, CONFIG)).to.equal(0)
			-- THE REACH IS ONE NUMBER NOW and the LOUDNESS is what the gait changes (task 123 round
			-- 4). Karen: *"when they close we can hear steps but also do not mix lot's so steps will
			-- be noisey and caotic"* -- so all three gaits stop at the same 40 studs, which is about
			-- seven body lengths, and a running animal is simply louder inside it.
			expect(steps.run.audibleStuds).to.equal(steps.walk.audibleStuds)
			expect(steps.trot.audibleStuds).to.equal(steps.walk.audibleStuds)
			expect(steps.run.volume > steps.trot.volume).to.equal(true)
			expect(steps.trot.volume > steps.walk.volume).to.equal(true)

			-- THE GRUNT IS THE FAR CUE NOW (task 123 round 4), and this band was the old one. Karen:
			-- *"I hear only when it;s close inaf to me if it's far away I don't hear"* -- the answer
			-- was to swap the two reaches, so the voice carries 160 studs and the hooves 40.
			expect(SOUND.GRUNTS.audibleStuds >= 120).to.equal(true)
			expect(SOUND.GRUNTS.audibleStuds > SOUND.STEPS.run.audibleStuds * 2).to.equal(true)
			expect(Boar.heardAt(SOUND.GRUNTS, 75, CONFIG) > 0).to.equal(true)
			-- An animal that is WORKING is heard about as far as it is running.
			expect(SOUND.BREATH.audibleStuds >= 90).to.equal(true)

			-- AND THE CROWD CAP MUST NOT UNDO ANY OF IT (the same listen, both halves): the far fade
			-- is there to stop a distant herd being an EVENT, and it never reaches zero.
			--
			-- THE FADE NOW BEGINS INSIDE THE GRUNT'S REACH, which is deliberate since task 123 round
			-- 4 swapped the two cues: the voice carries 160 studs so that a hunter hears a herd
			-- coming at all, and the far fade quiets a herd that is still a long way off -- *"when
			-- its verry fal I cant hear them"* cuts both ways. What must still hold is that a grunt
			-- at the Director's own listening band is at FULL volume, which is the next line.
			expect(SOUND.CROWD.FAR_STUDS >= 100).to.equal(true)
			expect(SOUND.CROWD.FAR_VOLUME >= 0.5).to.equal(true)
			expect(Boar.farScale(SOUND.CROWD.FAR_STUDS - 1, CONFIG)).to.equal(1)
			TestKit.note(
				string.format(
					"boar-far: run hooves reach %d studs (%.2f of full at 100), trot %d, walk %d, grunts %d, breath %d",
					steps.run.audibleStuds,
					Boar.heardAt(steps.run, 100, CONFIG),
					steps.trot.audibleStuds,
					steps.walk.audibleStuds,
					SOUND.GRUNTS.audibleStuds,
					SOUND.BREATH.audibleStuds
				)
			)
		end)

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

		it("has a playable id, a volume and a range for every sound the code can play", function()
			-- IDS ARE DATA, on purpose: the Director's picks are provisional and a library sound can
			-- be moderated away, so a swap is one value in `Boar.CONFIG.SOUND` and no code change.
			--
			-- A ROW MAY NOW BE A STRING (task 126). The footsteps are `rbxasset://` ENGINE assets --
			-- Roblox's own files, which ship inside the engine and so cannot 404 or be moderated --
			-- because the audio catalogue turned out to hold nothing usable: every id a search
			-- returned was user-uploaded music and none of it loaded, since audio uploaded by another
			-- user is private to that user's experiences. `Body.soundUri` is what tells the two
			-- apart, and this asserts the same thing it tests.
			local function checkSpec(what: string, spec)
				local ids = spec.ids or { spec.id }
				expect(#ids > 0).to.equal(true)
				for _, id in ipairs(ids) do
					if type(id) == "string" then
						expect(string.find(id, "://", 1, true) ~= nil).to.equal(true)
						expect(Boar.soundUri(id)).to.equal(id)
					else
						expect(type(id)).to.equal("number")
						expect(id > 0).to.equal(true)
						expect(Boar.soundUri(id)).to.equal("rbxassetid://" .. tostring(id))
					end
				end
				expect(spec.volume > 0).to.equal(true)
				expect(spec.volume <= 1).to.equal(true)
				expect(type(spec.audibleStuds)).to.equal("number")
				TestKit.note(
					string.format(
						"boar-shot: %s = %d id(s) (%s), vol %.2f, %d studs",
						what,
						#ids,
						tostring(ids[1]),
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
			-- ...AND THE HOOVES ARE THE CLOSE SOUND, NOT THE APPROACH ONE, which is the opposite of
			-- what this file used to assert and the opposite of what task 120 built.
			--
			-- THIS ASSERTION WAS WRONG AND HAD BEEN SINCE TASK 123 ROUND 4 (found in task 126, and
			-- reported rather than quietly fixed): it demanded `run.audibleStuds >= 60` and
			-- `run > walk`, while the config Karen accepted in that round sets all three to 40 --
			-- *"when they close we can hear steps but also do not mix lot's so steps will be noisey
			-- and caotic"*. The gate has not run since (the DEV place has not been open), so nobody
			-- saw it fail. What is asserted now is the rule those numbers express: a hoof is a CLOSE
			-- sound and the GRUNT is the one that carries, which is the whole of task 123's finding.
			expect(SOUND.STEPS.run.audibleStuds <= 60).to.equal(true)
			expect(SOUND.GRUNTS.audibleStuds > SOUND.STEPS.run.audibleStuds).to.equal(true)
		end)

		it("only ever grunts when calm and only ever breathes when working", function()
			-- Two bands that must not overlap, or a boar does both at once and sounds like two
			-- animals. They MEET at `RUN_FROM` rather than leaving a gap (task 123): the config's own
			-- line is "walking and trotting animals grunt; a running one breathes", so the boundary
			-- belongs to exactly one of them and `<=` is the claim.
			expect(SOUND.GRUNTS.MAX_SPEED <= SOUND.BREATH.MIN_SPEED).to.equal(true)
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
				"breath,cry,death,fall,grunt,hit,lastBreath,sniff,steps_run,steps_trot,steps_walk"
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
				-- A ROW MAY CARRY ITS OWN NEAR DISTANCE, and the far cues do since task 123: a grunt
				-- meant to be heard at 160 studs cannot start falling off at 24. `makeSound` reads
				-- `spec.nearStuds or SOUND.NEAR_STUDS`, so the claim is that it is one of the two.
				expect(sound.RollOffMinDistance == SOUND.NEAR_STUDS or sound.RollOffMinDistance > SOUND.NEAR_STUDS).to.equal(
					true
				)
				expect(sound.RollOffMaxDistance > SOUND.NEAR_STUDS).to.equal(true)
				-- AN `rbxasset://` ENGINE FILE IS A SOUND ID TOO (task 126). Karen: *"and walking
				-- sound sounds like horse we need animal not horse"* -- the footsteps are now
				-- Roblox's own CC0 file, which ships inside the engine and has no numeric id.
				expect(
					string.match(sound.SoundId, "^rbxassetid://%d+$") ~= nil
						or string.match(sound.SoundId, "^rbxasset://%S+$") ~= nil
				).to.equal(true)
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

		it("flag ON: a REAL shot plays the CRY and NOT the bullet hit, which is now off", function()
			-- Through `takeHit`, so this is the path a player's slug takes, and the class is worked
			-- out by the production code rather than handed in.
			--
			-- TASK 120. Karen, 2026-10-04: "I think we can remove hit sound for now" / "animal react
			-- sound is good". So the animal still answers and the bullet does not: `HIT.enabled` is
			-- false, and this case is what says the row -- not a deleted call -- is doing it.
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
			expect(audible(hit)).to.equal(false) -- the Sound exists and stays silent
			expect(handle.soundPlays.hit).to.equal(nil)
			expect(audible(cry)).to.equal(true)
			local chosen = tonumber(string.match(cry.SoundId, "%d+"))
			local known = false
			for _, id in ipairs(SOUND.CRY.ids) do
				known = known or id == chosen
			end
			expect(known).to.equal(true)
			runtime:destroy()
		end)

		it("flag ON: the sniff is played HIGH, which is the pitch centre end to end", function()
			-- `Body.playOneShot` multiplies the jitter by the spec's own `pitch`, which is how the
			-- sniff is the same breath sample played high (task 117). This drives the WHOLE path --
			-- the Brain drawing `smell`, the Runtime firing the sound on that edge, `playOneShot`
			-- doing the arithmetic -- and reads the `PlaybackSpeed` the player would hear. A case
			-- that multiplied the two numbers itself would pass with the multiplication deleted
			-- (review round 3, the Director's sweep).
			-- THE SNIFF IS OFF IN THE GAME and is switched on here by parameter (task 129), for the
			-- same reason and with the same quote as `voicedSound`: Karen asked for a boar that makes
			-- no ambient pig sound at all (*"they don't make any pig sound besides walking"*), so
			-- `SOUND.SNIFF.enabled` is false in the config the game ships. The PITCH PATH is still
			-- worth driving end to end, and it cannot be driven through a cue that never plays.
			local sniffWorld = buildWorld(true, "BoarsShotSniff")
			local sniffSound = table.clone(CONFIG.SOUND)
			local sniffRow = table.clone(CONFIG.SOUND.SNIFF)
			sniffRow.enabled = true
			sniffSound.SNIFF = sniffRow
			sniffWorld.config.SOUND = sniffSound
			local runtime = Boar.newRuntime(sniffWorld)
			local sniffTemplate = makeTemplate()
			runtime:setModelSource(function()
				return sniffTemplate
			end, function(clip: string)
				return FAKE_IDS[clip]
			end)
			local handle = runtime:spawn(Vector3.new(40, GROUND_Y, 0))
			warmedUp(runtime)
			local sniff = soundNamed(handle, "sniff") :: Sound
			local heard = false
			for _ = 1, 40000 do
				step(runtime)
				if audible(sniff) then
					heard = true
					break
				end
			end
			expect(heard).to.equal(true) -- a calm boar lifts its head sooner or later
			local centre = SOUND.SNIFF.pitch
			local jitter = SOUND.PITCH_JITTER
			-- Inside the band the centre allows, and ABOVE 1 -- which is the whole point of the
			-- field: the same sample, played high.
			expect(sniff.PlaybackSpeed >= centre * (1 - jitter) - 1e-4).to.equal(true)
			expect(sniff.PlaybackSpeed <= centre * (1 + jitter) + 1e-4).to.equal(true)
			expect(sniff.PlaybackSpeed > 1 + jitter).to.equal(true)
			TestKit.note(
				string.format("boar-shot: the sniff played at %.3f (centre %.2f)", sniff.PlaybackSpeed, centre)
			)
			runtime:destroy()
		end)

		it("flag ON: a dead boar has no footsteps and ONE SHORT squeal, and nothing after it", function()
			-- TASK 120. Karen, 2026-10-04: "when it dies could be sqeeck sound short" and "when die
			-- last sqeek need short one". It was a long scream, a wet thud and a breath a second
			-- later; it is one squeal that ENDS, and the two cues she did not want are off by data.
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
			expect(audible(fall)).to.equal(false) -- the thud she heard as a second shot
			-- EVERY LOOP IS CUT: a carcass with footsteps is the thing this exists to prevent.
			expect(#playingLoops(handle)).to.equal(0)

			-- IT IS SHORT, AND IT FADES. A head shot collapses on the tick it lands, so the squeal
			-- started a handful of frames ago: stepping to half a fade before the cut lands INSIDE
			-- the fade, where the volume is below the row's own, and stepping past it finds the
			-- squeal over. Both numbers come from the config, so retuning the cut moves the case.
			step(runtime, math.ceil((SOUND.DEATH.cut - SOUND.DEATH.fade / 2) / DT))
			expect(death.Volume < SOUND.DEATH.volume).to.equal(true)
			expect(death.Volume > 0).to.equal(true)
			step(runtime, math.ceil(SOUND.DEATH.fade / DT) + 2)
			expect(audible(death)).to.equal(false)

			-- ...AND NOTHING FOLLOWS IT: no breath, ever, however long this waits.
			step(runtime, math.ceil(SOUND.LAST_BREATH.delay / DT) + 30)
			expect(audible(breath)).to.equal(false)
			expect(handle.soundPlays.lastBreath).to.equal(nil)
			expect(#playingLoops(handle)).to.equal(0)
			TestKit.note(
				string.format(
					"boar-shot: the death squeal is cut at %.2f s (fade %.2f), fall and last breath silent",
					SOUND.DEATH.cut,
					SOUND.DEATH.fade
				)
			)
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
			-- IT STAYS WHERE IT WAS HIT.
			-- IT IS CRIPPLED, SAID BY THE BRAIN AND NOT INFERRED FROM NOT STRAYING (review round 2,
			-- note): `handle.state()` is the runtime's own read-only seam onto `Brain:state`.
			expect(handle.state()).to.equal("CRIPPLED")
			-- A bolting boar covers 38 studs a second; three seconds of circling at CRIPPLE_SPEED
			-- cannot leave a circle about 11.5 studs across (see the radius case above).
			expect(far < 18).to.equal(true)
			TestKit.note(string.format("boar-shot: crippled boar strayed %.2f studs in 3 s", far))
			runtime:destroy()
		end)
	end)
end
