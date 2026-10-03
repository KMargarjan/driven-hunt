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
	-- THE FLAG ARRIVES AS A PARAMETER, which is the one permitted shape and the only way both states
	-- are reachable while `BOAR_MODEL` sits at one of them (review round 2, finding 2: the repertoire
	-- shipped unflagged for a round). `calmOn` is `CALM.ENABLED`; `ids` is the whole id table, and
	-- `Body.hasClip` only asks whether a clip has one.
	local function configWith(calmOn: boolean, ids)
		local model = table.clone(MODEL)
		model.ANIMATION_IDS = ids
		local calmTable = table.clone(CALM)
		calmTable.ENABLED = calmOn
		local config = table.clone(CONFIG)
		config.MODEL = model
		config.CALM = calmTable
		return config
	end

	-- Every clip the repertoire can ask for, under a fake id. The six real ones ARE published, but a
	-- spec that leaned on that would be testing the manifest rather than the code.
	local function withCalmIds()
		local ids = table.clone(MODEL.ANIMATION_IDS)
		for _, name in ipairs({ "smell", "grazeLoop", "grazeChew", "grazeStart", "grazeEnd", "digWalk", "idle", "walk" }) do
			ids[name] = 30000 + #name
		end
		return configWith(true, ids)
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

		it("always answers a row, however the roll falls", function()
			-- WHAT THIS PROVES AND WHAT IT DOES NOT (review round 3, note): the property is that
			-- `calmActivity` never returns nil -- a nil row would be a Brain that indexes `.speed` on
			-- nothing. The `math.clamp` inside it is belt and braces and is NOT observable here: a
			-- roll of -1 falls into row 1 through `cut < seen` anyway, and a roll of 2 falls out of
			-- the loop into the trailing `return activities[#activities]`. The case is named for
			-- what it can actually fail on.
			expect(Brain.calmActivity(-1, CALM).name).to.equal(CALM.ACTIVITIES[1].name)
			expect(Brain.calmActivity(2, CALM).name).to.equal(CALM.ACTIVITIES[#CALM.ACTIVITIES].name)
			for step = 0, 20 do
				expect(Brain.calmActivity(step / 20, CALM)).to.be.ok()
			end
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
			-- REVIEW ROUND 3, FINDING 1: this case used to drive `root` at exactly `digWalk`'s own
			-- 1.901 studs/s, where the answer is 1.0 whether the rating exists or not, and the other
			-- half at speed 0 on a clip whose ground speed is 0 -- so deleting the whole rating
			-- branch left both assertions true. Every speed below is chosen so the EXPECTED RATE IS
			-- NOT 1, and the three between them walk the clamp: under `MIN_RATE`, inside the band,
			-- and over `MAX_RATE`.
			local config = withCalmIds()
			local model = config.MODEL
			local ground = model.CLIPS.digWalk.groundStudsPerSecond

			local function rateAt(speed: number): number
				local _, rate = Boar.activityClip({
					activity = "root",
					activityFor = 99,
					exitClip = nil,
					exitFor = 0,
					speed = speed,
				}, config)
				return rate
			end

			-- INSIDE THE BAND: twice the clip's own ground speed is exactly rate 2, and half of it
			-- is exactly 0.5 -- neither of which the constant 1 can produce.
			expect(math.abs(rateAt(ground * 2) - 2) < 1e-6).to.equal(true)
			expect(math.abs(rateAt(ground * 0.5) - 0.5) < 1e-6).to.equal(true)
			-- BELOW `MIN_RATE`: a crawl asks for 0.05 and is given the floor.
			expect(math.abs(rateAt(ground * 0.05) - model.MIN_RATE) < 1e-6).to.equal(true)
			-- ABOVE `MAX_RATE`: sprint speed asks for 20 and is given the ceiling.
			expect(math.abs(rateAt(ground * 20) - model.MAX_RATE) < 1e-6).to.equal(true)
			-- ...and the two bounds really are different numbers, or the clamp proves nothing.
			expect(model.MIN_RATE < 1 and model.MAX_RATE > 2).to.equal(true)

			-- A CLIP THAT DOES NOT CARRY THE ANIMAL plays at 1 at EVERY speed, which is the other
			-- half of the branch and was driven at speed 0 (where 1 is the only possible answer).
			for _, speed in ipairs({ 0, 4, CONFIG.SPRINT_SPEED }) do
				local _, still = Boar.activityClip({
					activity = "graze",
					activityFor = 99,
					exitClip = nil,
					exitFor = 0,
					speed = speed,
				}, config)
				expect(still).to.equal(1)
			end
			TestKit.note(
				string.format(
					"boar-calm: the drag clip rates %.2f at %.1f studs/s and clamps at %.2f/%.2f",
					rateAt(ground * 2),
					ground * 2,
					model.MIN_RATE,
					model.MAX_RATE
				)
			)
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
			-- so "no id" has to be built rather than found.
			local none = configWith(true, { idle = 1, walk = 2 })
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
			local off = configWith(false, withCalmIds().MODEL.ANIMATION_IDS)
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
			-- The repertoire ON, by parameter. The OFF state -- `BOAR_MODEL`'s default, and the live
			-- game -- has its own case below.
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

		it("never draws the same activity twice running, so a one-shot is always replayed", function()
			-- `Body` draws a clip when the activity NAME changes, so the same row twice in a row is a
			-- clip that is never re-played: `smell` is a one-shot with no enter or exit, and the boar
			-- stood frozen on `Idle_5`'s last pose for a second 4.167 s (review round 3, note).
			-- A NAME ALONE CANNOT SHOW THIS, which is why the Brain publishes the DRAW NUMBER too: a
			-- row drawn twice running produces the same name, so a case watching names would pass
			-- with the rule deleted (it did -- review round 3, the Director's own mutation ask). One
			-- draw per name change, and never two draws on one name, is the rule in numbers.
			local brain = newBrain(42)
			local previousName, previousDraw, changes, draws = nil, nil, 0, 0
			for _ = 1, 60 * 240 do
				local intent = brain:step(DT, obs(Vector3.zero))
				expect(intent.activityDraw).to.be.ok()
				if intent.activityDraw ~= previousDraw then
					draws += 1
					if previousName ~= nil then
						-- THE RULE: a new draw is always a different activity.
						expect(intent.activity).never.to.equal(previousName)
					end
					previousDraw = intent.activityDraw
				end
				if intent.activity ~= previousName then
					if previousName ~= nil then
						changes += 1
					end
					previousName = intent.activity
				end
			end
			expect(changes > 20).to.equal(true) -- four minutes is dozens of activities, not two
			expect(draws).to.equal(changes + 1) -- +1 for the first draw, which changes nothing
			TestKit.note(string.format("boar-calm: %d draws and %d name changes in 240 s", draws, changes))
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

		it("two boars built the way the Runtime builds them do not move in lockstep", function()
			-- PRODUCTION SHAPE: `Runtime:spawn` hands every `Brain.new` the runtime's own shared
			-- `Random`, so two boars born on the same frame draw from ONE stream -- which is what the
			-- old case missed by giving them a seed each (review round 2, finding 4).
			--
			-- WHAT CARRIES THE PHASING IS THE CASE ABOVE, not this one (review round 3, note): the
			-- shared stream alone already gives each brain its own activity and duration, so this
			-- would pass with `Brain.firstPhase` deleted. It is here for the end-to-end statement --
			-- two boars, built as the game builds them, are not one animal twice.
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
