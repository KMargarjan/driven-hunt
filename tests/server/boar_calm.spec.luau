-- boar_calm.spec: THE CALM BOAR (task 117) -- what an animal does when nothing is wrong.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- Karen, 2026-10-03: "boar also can move alon and walk and lift head like smell ect". The repertoire
-- is a WEIGHTED DRAW inside the Brain's existing IDLE -- no new state, because task 118 adds the
-- ways out of IDLE and would have to undo one. Everything here is reachable BY PARAMETER: the roll
-- that picks an activity, the activity that picks a clip, and the ids that decide whether the clip
-- can be played at all.
--
-- THE SIX CLIPS ARE PUBLISHED (2026-10-03), so the cases below drive the real config. The "no id"
-- promise is still asserted, because it is what every future clip relies on: a config whose calm
-- clips have no id draws exactly what it drew before.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Brain = Boar.Brain
local CONFIG = Boar.CONFIG
local CALM = CONFIG.CALM
local MODEL = CONFIG.MODEL

local DT = 1 / 60
local FIELD = {
	bounds = { minX = -200, maxX = 200, minZ = -200, maxZ = 200 },
	exitZ = -190,
	groundY = 0,
}

return function()
	-- A config whose calm clips all have ids, so the drawing half is reachable while the real ones
	-- are still waiting on a publish. The ids are fake; `Body.hasClip` only asks whether one exists.
	-- THE FLAG ARRIVES AS A PARAMETER, which is the one permitted shape and the only way both states
	-- are reachable while `BOAR_MODEL` sits at one of them (review round 2, finding 2: the repertoire
	-- shipped unflagged for a round). `calm` is `CALM.ENABLED`; `ids` fills in the clip ids, because
	-- `Body.hasClip` only asks whether one exists.
	local function configWith(calmOn: boolean, withIds: boolean)
		local ids = table.clone(MODEL.ANIMATION_IDS)
		if withIds then
			for _, name in ipairs({
				"smell",
				"grazeLoop",
				"grazeChew",
				"grazeStart",
				"grazeEnd",
				"digWalk",
				"idle",
				"walk",
			}) do
				ids[name] = 30000 + #name
			end
		end
		local model = table.clone(MODEL)
		model.ANIMATION_IDS = ids
		local calmTable = table.clone(CALM)
		calmTable.ENABLED = calmOn
		local config = table.clone(CONFIG)
		config.MODEL = model
		config.CALM = calmTable
		return config
	end

	local function withCalmIds()
		return configWith(true, true)
	end

	-- A world with nothing in it: every case here is about what a boar does when nothing is wrong.
	local function obs(position: Vector3)
		return {
			position = position,
			velocity = Vector3.zero,
			threats = {},
			waypoints = nil,
			pathFailed = false,
			blockedAhead = false,
		}
	end

	local function clipFor(config, info)
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
			activity = nil,
			activityFor = 99,
			exitClip = nil,
			exitFor = 0,
		}
		for key, value in pairs(info) do
			filled[key] = value
		end
		return (Boar.clipFor(filled, config))
	end

	describe("the repertoire is data, and every activity is reachable", function()
		it("names the five things a calm boar does, each with a weight and a band", function()
			local names = {}
			for _, row in ipairs(CALM.ACTIVITIES) do
				table.insert(names, row.name)
				expect(row.weight > 0).to.equal(true)
				expect(row.minSeconds > 0).to.equal(true)
				expect(row.maxSeconds >= row.minSeconds).to.equal(true)
				expect(row.speed >= 0).to.equal(true)
			end
			table.sort(names)
			expect(table.concat(names, ",")).to.equal("graze,root,smell,stand,walk")
		end)

		it("draws every one of them, in proportion to its weight", function()
			-- The roll is the parameter, so this walks the whole [0, 1) range rather than trusting a
			-- Random: a weight of zero would show up as a name that never comes back.
			local seen = {}
			for step = 0, 1000 do
				local row = Brain.calmActivity(step / 1000, CALM)
				seen[row.name] = (seen[row.name] or 0) + 1
			end
			local total = 0
			for _, row in ipairs(CALM.ACTIVITIES) do
				expect(seen[row.name]).to.be.ok()
				total += row.weight
			end
			-- ...and in proportion: a draw of 1001 evenly spaced rolls lands within a percent of the
			-- share the weight asks for.
			for _, row in ipairs(CALM.ACTIVITIES) do
				local share = seen[row.name] / 1001
				expect(math.abs(share - row.weight / total) < 0.01).to.equal(true)
			end
			TestKit.note(
				string.format("boar-calm: graze %d%% of 1001 rolls", math.floor(seen.graze / 1001 * 100 + 0.5))
			)
		end)

		it("clamps a roll outside the range instead of answering nil", function()
			expect(Brain.calmActivity(-1, CALM).name).to.equal(CALM.ACTIVITIES[1].name)
			expect(Brain.calmActivity(2, CALM).name).to.equal(CALM.ACTIVITIES[#CALM.ACTIVITIES].name)
			expect(Brain.calmActivity(1, CALM)).to.be.ok() -- the top of the range is somebody's
		end)

		it("gives the head-up smell exactly one clip length, so the lift is never cut off", function()
			local smell = Boar.activityRow("smell", withCalmIds())
			expect(smell.minSeconds).to.equal(smell.maxSeconds)
			expect(math.abs(smell.minSeconds - MODEL.CLIPS.smell.seconds) < 1e-6).to.equal(true)
			expect(smell.speed).to.equal(0) -- it stands still to do it
			expect(smell.sound).to.equal("sniff")
			TestKit.note(string.format("boar-calm: the head is up for %.2f s", smell.minSeconds))
		end)
	end)

	describe("one activity draws one clip, and never two", function()
		it("draws each activity's own clip, and lets the gait answer for a walk", function()
			local config = withCalmIds()
			expect(clipFor(config, { activity = "stand" })).to.equal("idle")
			expect(clipFor(config, { activity = "graze" })).to.equal("grazeLoop")
			expect(clipFor(config, { activity = "root", speed = 1.901 })).to.equal("digWalk")
			expect(clipFor(config, { activity = "smell" })).to.equal("smell")
			-- `walk` names no clip on purpose: at WANDER_SPEED the gait bands answer "walk", which is
			-- the clip task 115 measured so the feet do not slide.
			expect(clipFor(config, { activity = "walk", speed = 4 })).to.equal("walk")
		end)

		it("plays the ENTER clip for its own length, then the loop", function()
			local config = withCalmIds()
			local enter = MODEL.CLIPS.grazeStart.seconds
			expect(clipFor(config, { activity = "graze", activityFor = 0 })).to.equal("grazeStart")
			expect(clipFor(config, { activity = "graze", activityFor = enter - 0.01 })).to.equal("grazeStart")
			expect(clipFor(config, { activity = "graze", activityFor = enter })).to.equal("grazeLoop")
		end)

		it("plays the EXIT clip before anything the next CALM activity wants", function()
			-- The head coming out of the grass finishes first, or the animal snaps upright.
			local config = withCalmIds()
			expect(clipFor(config, { activity = "walk", speed = 4, exitClip = "grazeEnd", exitFor = 0.5 })).to.equal(
				"grazeEnd"
			)
			expect(clipFor(config, { activity = "walk", speed = 4, exitClip = "grazeEnd", exitFor = 0 })).to.equal(
				"walk"
			)
		end)

		it("DROPS the exit the moment the animal stops being calm", function()
			-- REVIEW ROUND 2, FINDING 1. The exit used to be tested before "is this animal calm at
			-- all", so a grazing boar that bolted drew `grazeEnd` -- an in-place eating transition --
			-- for its whole 1.083 s while the body accelerated to SPRINT_SPEED: about 25 studs of
			-- sliding with its head in the grass. `info.activity` is nil for every state but IDLE,
			-- and that is the test.
			local config = withCalmIds()
			expect(clipFor(config, { activity = nil, speed = CONFIG.SPRINT_SPEED, exitClip = "grazeEnd", exitFor = 1 })).to.equal(
				"run"
			)
			expect(clipFor(config, { activity = nil, speed = CONFIG.TROT_SPEED, exitClip = "grazeEnd", exitFor = 1 })).to.equal(
				"trot"
			)
			-- ...and a dead or crippled animal never draws it either.
			expect(clipFor(config, { activity = "graze", collapsed = true, exitClip = "grazeEnd", exitFor = 1 })).to.equal(
				(Boar.deathClips(config))
			)
		end)

		it("rates a clip that CARRIES the animal off its own ground speed", function()
			local config = withCalmIds()
			local _, rate = Boar.activityClip({
				activity = "root",
				activityFor = 99,
				exitClip = nil,
				exitFor = 0,
				speed = 1.901,
			}, config)
			expect(math.abs(rate - 1) < 0.01).to.equal(true)
			-- ...and a clip that does not carry it plays at 1 whatever the speed says.
			local _, still = Boar.activityClip({
				activity = "graze",
				activityFor = 99,
				exitClip = nil,
				exitFor = 0,
				speed = 0,
			}, config)
			expect(still).to.equal(1)
		end)

		it("is beaten by a death, a cripple and a flinch, which are not calm animals", function()
			local config = withCalmIds()
			local fall = (Boar.deathClips(config))
			expect(clipFor(config, { activity = "graze", collapsed = true })).to.equal(fall)
			expect(clipFor(config, { activity = "graze", hitFor = MODEL.HIT_SECONDS })).to.equal("hitFront")
			-- A CRIPPLED OR DEAD ANIMAL IS NOT CALM, and `activityClip` refuses on its own rather
			-- than relying on the branch above it having a published clip to return. This case found
			-- that: with `crippleDrag` unpublished, a crippled boar went back to grazing.
			for _, state in ipairs({ "crippled", "collapsed" }) do
				local info = {
					activity = "graze",
					activityFor = 99,
					exitClip = nil,
					exitFor = 0,
					speed = 0,
				}
				info[state] = true
				expect((Boar.activityClip(info, config))).to.equal(nil)
			end
		end)
	end)

	describe("with no id published, a calm boar is exactly what it was", function()
		it("draws no calm clip at all, so the gait bands answer every time", function()
			-- `Body.hasClip` is the one test, and it is what every clip added after this will rely
			-- on. Driven with an EMPTY id table, because the six real ones are published now.
			-- An id table with the two gait clips and nothing else: the calm six are published now,
			-- so "no id" has to be built rather than found. (The comment here used to say "only what
			-- task 115 published", which was ten clips, not two -- review round 2, note.)
			local none = configWith(true, false)
			local model = table.clone(none.MODEL)
			model.ANIMATION_IDS = { idle = 1, walk = 2 }
			none.MODEL = model
			for _, name in ipairs({ "smell", "grazeLoop", "grazeChew", "grazeStart", "grazeEnd", "digWalk" }) do
				expect(Boar.hasClip(name, none)).to.equal(false)
			end
			expect(clipFor(none, { activity = "graze" })).to.equal("idle")
			expect(clipFor(none, { activity = "smell" })).to.equal("idle")
			expect(clipFor(none, { activity = "root", speed = 1.901 })).to.equal("walk")
			expect(clipFor(none, { activity = "walk", speed = 4 })).to.equal("walk")
		end)

		it("with the FLAG off, an idle boar is exactly the boar it was before task 117", function()
			-- `CALM.ENABLED` is `Flags.isOn("BOAR_MODEL")`, whose default is false -- the live game.
			-- Then `_stepCalm` returns the old wander/graze answer and nothing publishes an activity.
			local off = configWith(false, true)
			expect(Boar.activityRow("graze", off)).to.equal(nil)
			expect(clipFor(off, { activity = "graze" })).to.equal("idle")
			local brain = Brain.new(off, FIELD, Vector3.zero, Random.new(5))
			local speeds = {}
			for _ = 1, 600 do
				local intent = brain:step(DT, obs(Vector3.zero))
				expect(intent.activity).to.equal(nil)
				speeds[string.format("%.2f", intent.targetVelocity.Magnitude)] = true
			end
			-- The old behaviour is a boar that stands still sometimes and wanders at WANDER_SPEED
			-- otherwise, so the speeds it reaches are bounded by that and nothing else.
			for speed in pairs(speeds) do
				expect(tonumber(speed) <= CONFIG.WANDER_SPEED + 1e-6).to.equal(true)
			end
		end)

		it("plays the three one-shots ONCE and the three loops for ever, whatever the asset says", function()
			-- All six were published `Loop = true` (the Animation Editor's toggle), like the thirteen
			-- before them. `Body.play` writes `Looped` from this table immediately before every
			-- `Play`, so the transitions and the head-lift end instead of repeating.
			expect(MODEL.CLIPS.smell.looped).to.equal(false)
			expect(MODEL.CLIPS.grazeStart.looped).to.equal(false)
			expect(MODEL.CLIPS.grazeEnd.looped).to.equal(false)
			expect(MODEL.CLIPS.grazeLoop.looped).to.equal(true)
			expect(MODEL.CLIPS.grazeChew.looped).to.equal(true)
			expect(MODEL.CLIPS.digWalk.looped).to.equal(true)
		end)

		it("an unknown activity, and no activity at all, both fall through to the gait", function()
			local config = withCalmIds()
			expect(Boar.activityRow(nil, config)).to.equal(nil)
			expect(Boar.activityRow("sunbathe", config)).to.equal(nil)
			expect(clipFor(config, { activity = nil, speed = 4 })).to.equal("walk")
			expect(clipFor(config, { activity = "sunbathe", speed = 4 })).to.equal("walk")
		end)
	end)

	describe("an idle boar really does change what it is doing", function()
		local function newBrain(seed: number)
			-- The flag as a parameter: with `BOAR_MODEL` off -- its default, and the live game -- the
			-- repertoire is off and an idle boar wanders as it did before task 117.
			return Brain.new(withCalmIds(), FIELD, Vector3.zero, Random.new(seed))
		end

		it("publishes an activity while IDLE, and more than one over a minute", function()
			local brain = newBrain(117)
			local seen, order = {}, {}
			for _ = 1, 60 * 60 do
				local intent = brain:step(DT, obs(Vector3.zero))
				expect(intent.state).to.equal("IDLE")
				expect(intent.activity).to.be.ok()
				if seen[intent.activity] == nil then
					seen[intent.activity] = 0
					table.insert(order, intent.activity)
				end
				seen[intent.activity] += 1
			end
			expect(#order >= 3).to.equal(true) -- a minute of standing still would be one
			TestKit.note("boar-calm: a minute of calm went " .. table.concat(order, " -> "))
		end)

		it("stops publishing one on the tick it leaves IDLE", function()
			-- REVIEW ROUND 2, FINDING 3: the case this replaces put the threat in from the first
			-- step, so the boar went IDLE->FLEE before `_stepCalm` had ever run and `activity` was
			-- nil for a reason that had nothing to do with the guard. This one gets a calm boar
			-- FIRST, with an activity it is really doing, and only then frightens it.
			local brain = newBrain(7)
			local intent
			for _ = 1, 600 do
				intent = brain:step(DT, obs(Vector3.zero))
				if intent.activity ~= nil then
					break
				end
			end
			expect(intent.state).to.equal("IDLE")
			expect(intent.activity).to.be.ok() -- it really is doing something before the threat

			local threat = { { id = "t", position = Vector3.new(0, 0, 10) } }
			local left = nil
			for _ = 1, 120 do
				local world = obs(Vector3.zero)
				world.threats = threat
				intent = brain:step(DT, world)
				if intent.state ~= "IDLE" and left == nil then
					left = intent.activity -- what it published on the very tick it stopped being calm
				end
			end
			expect(intent.state).never.to.equal("IDLE")
			expect(left).to.equal(nil) -- nil on that tick, not one frame later
			expect(intent.activity).to.equal(nil)
		end)

		it("shortens the FIRST activity, and never the one that is a clip length", function()
			-- REVIEW ROUND 2, FINDING 4: the case this replaces asserted "two brains with different
			-- seeds did not agree on all 1800 frames", which is true whatever the phasing does. The
			-- mechanism is pure now, so it is asserted directly.
			local calm = withCalmIds().CALM
			local graze = Boar.activityRow("graze", withCalmIds())
			-- A roll of 0 takes nothing; anything above it takes a real bite out of the band.
			expect(Boar.firstPhase(10, 0, graze, calm)).to.equal(10)
			expect(Boar.firstPhase(10, 1, graze, calm)).to.equal(10 - calm.FIRST_PHASE_SECONDS)
			expect(Boar.firstPhase(10, 0.5, graze, calm) < 10).to.equal(true)
			-- ...and it never goes below the floor, however short the band or however big the roll.
			expect(Boar.firstPhase(1, 1, graze, calm)).to.equal(calm.FIRST_PHASE_FLOOR)
			-- THE HEAD LIFT IS EXEMPT: `smell` is exactly one clip length, so shortening it would cut
			-- the 30.4 degree lift off in the middle.
			local smell = Boar.activityRow("smell", withCalmIds())
			expect(Boar.firstPhase(smell.minSeconds, 1, smell, calm)).to.equal(smell.minSeconds)
		end)

		it("puts two boars out of step in the shape the Runtime builds them", function()
			-- PRODUCTION SHAPE: `Runtime:spawn` hands every `Brain.new` the runtime's own shared
			-- `Random`, so two boars born on the same frame draw from ONE stream -- which is what the
			-- old case missed by giving them a seed each (review round 2, finding 4).
			local shared = Random.new(117)
			local a = Brain.new(withCalmIds(), FIELD, Vector3.zero, shared)
			local b = Brain.new(withCalmIds(), FIELD, Vector3.zero, shared)
			local same, frames = 0, 60 * 30
			for _ = 1, frames do
				local first = a:step(DT, obs(Vector3.zero))
				local second = b:step(DT, obs(Vector3.zero))
				if first.activity == second.activity then
					same += 1
				end
			end
			-- THE MEASURED BOUND, not "they differed once". Five activities drawn by weight agree
			-- about a quarter of the time by chance; lockstep would be 100 %.
			local share = same / frames
			expect(share < 0.5).to.equal(true)
			TestKit.note(string.format("boar-calm: two boars off one Random agreed on %.0f%% of 30 s", share * 100))
		end)
	end)
end
