-- bots_lane.spec: THE BEATER LINE, AS GEOMETRY -- no drive, no players, no rigs, no terrain, no
-- Instances and no clock. Everything here takes CFrames and Vector3s and returns CFrames and
-- Vector3s, which is why the line a bot walks is a thing a spec can state rather than a thing
-- somebody watches.
--
-- THE LINE IS THE FEATURE, and it is why `PathfindingService` was rejected (note section 3): a
-- shortest path is per agent, so eight shortest paths are eight detours and the line is gone. These
-- cases are what "abreast" means in arithmetic -- and the ROTATED-BASE case is the one that matters,
-- because the forest's road is a sine whose tangent swings +-23 degrees.
--
-- IT ALSO DRIVES THE DRIVE'S HALF: `Match.lineReferenceFor` (factored out of `Match.crossedLine` in
-- task 161) and `Match.beaterGoalFor`, with hand-written posts -- including the forest's case, where
-- the nearest stand LATERALLY is not the nearest stand overall.
--
-- ...AND SINCE TASK 162 THE LENGTH OF THE WALK, which is the one claim here made of SHIPPED numbers
-- rather than hand-written ones -- because it is a relation BETWEEN THREE FILES nobody changes
-- together: `Bots.CONFIG.WALK_SPEED`, the forest's own `BEATER.behindLineStuds` plus
-- `LINE.spawnNorthStuds`, and `Match.CONFIG.BOTS.GOAL_PAST_LINE_STUDS`. A bot line ENDS a drive
-- (`Match.beaterCrossing` counts bots into the line), so their quotient IS how long a drive lasts,
-- and Karen asked for it in minutes: *"need longer walk for beaters let's say 2 min"* (2026-10-12).
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/bots.md (section 9.1)
-- Note:   docs/research/2026-10-12-bots.md (sections 2.3, 2.4, 3)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Bots = require(ServerScriptService:WaitForChild("Bots"))
local Forest = require(ReplicatedStorage:WaitForChild("ForestTest"))
local Horn = require(ReplicatedStorage:WaitForChild("Horn"))
local Match = require(ServerScriptService:WaitForChild("Match"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Lane = Bots.Lane
local Rig = Bots.Rig

-- This spec's own numbers, the shape `Bots.CONFIG` is.
local CONFIG = {
	SIDE_STEP_STUDS = 10,
	SIDE_TRIES = 4,
	ARRIVE_STUDS = 4,
	AHEAD_STUDS = 12,
	-- TASK 208's own rows, hand-written here for the same reason the four above are: these cases
	-- state a rule, and a rule stated against the shipped table moves every time somebody tunes it.
	-- The cases that are about the SHIPPED numbers say so and read `Bots.CONFIG` instead.
	STUCK_FAST_SECONDS = 0.8,
	STUCK_SLOW_SPEED = 1.0,
	STUCK_ORDERED_SPEED = 2,
	DETOUR_ANGLES_DEG = { 18, 32, 50, 70, 88 },
	DETOUR_CASTS = 5,
	BACK_OFF_AFTER_TRIES = 3,
	BACK_OFF_STUDS = 8,
	JUMP_OVER_STUDS = 4,
}

-- THE DEV ARENA'S LINE: straight, with the normal pointing AT the beaters (`Markers.read`), so the
-- beaters stand at +Z and crossing means going negative.
local LINE = { position = Vector3.new(0, 10, 0), normal = Vector3.new(0, 0, 1) }
local POSTS = {
	{ Position = Vector3.new(-60, 11, 0), Size = Vector3.new(6, 2, 6) },
	{ Position = Vector3.new(0, 11, 0), Size = Vector3.new(6, 2, 6) },
	{ Position = Vector3.new(60, 11, 0), Size = Vector3.new(6, 2, 6) },
}
-- A CURVED ROAD, which is the forest's: three stands whose z wanders either side of one plane.
local CURVED_POSTS = {
	{ Position = Vector3.new(-60, 11, -30), Size = Vector3.new(6, 2, 6) },
	{ Position = Vector3.new(0, 11, 0), Size = Vector3.new(6, 2, 6) },
	{ Position = Vector3.new(60, 11, 30), Size = Vector3.new(6, 2, 6) },
}

local function near(a: number, b: number, tolerance: number?)
	return math.abs(a - b) <= (tolerance or 0.01)
end

return function()
	describe("the lanes", function()
		-- TASK 167. Karen, 2026-10-12 ~16:10, having played as a hunter with the bots on: *"and seem
		-- like all bots came to me"*. The line used to be spread by `Bots.Lane` at +-18 and +-36
		-- studs about ONE base, and in this world that base is the stand the drive aims at -- hers.
		-- The spread is the WORLD's now (it is the only owner that can see the hunters' front) and
		-- the goals are the DRIVE's, one per lane. The archived functions and the two reasons are in
		-- `backups/2026-10-12-bots-lane-offsets.md`.
		it("deals the beaters across the hunters' front, alternating, with index 1 on the push line", function()
			expect(Forest.beaterLaneOffset(1)).to.equal(0)
			expect(Forest.beaterLaneOffset(2)).to.equal(150)
			expect(Forest.beaterLaneOffset(3)).to.equal(-150)
			expect(Forest.beaterLaneOffset(4)).to.equal(300)
			expect(Forest.beaterLaneOffset(5)).to.equal(-300)
			-- nil is index 1, which is what every caller before task 167 meant.
			expect(Forest.beaterLaneOffset(nil)).to.equal(0)
			-- INDEX 1 IS THE PUSH LINE AND IT IS THE PEOPLE'S: a real beater is index 1, so she
			-- keeps the middle and the bots flank her. That is the property the archived
			-- `Lane.offsetFor` existed for, kept.
			-- ...AND THE SPACING IS THE STAND GRID, which is why a lane's goal is straight ahead of
			-- it: `Match.beaterGoalFor` and `Match.crossedLine` both take the post NEAREST the
			-- lane, so a lane on a stand's own x makes them pick the same post.
			-- ...AND IT IS THE LAYOUT'S STAND GRID, FOR EVERY LAYOUT (task 179). `laneSpacingStuds`
			-- used to be one number in `BEATER` reading `STAND_SPACING`; with three layouts at 150,
			-- 150 and 130 a single constant would be a second answer that disagrees with the live
			-- one on a ride. The property task 167 needs is asserted of each of them instead.
			for _, name in ipairs(Forest.LAYOUT_ORDER) do
				local layout = Forest.layoutNamed(name)
				expect(Forest.laneSpacing(layout)).to.equal(layout.standSpacing)
				expect(Forest.beaterLaneOffset(2, layout)).to.equal(layout.standSpacing)
				expect(Forest.beaterLaneOffset(3, layout)).to.equal(-layout.standSpacing)
			end
		end)

		it("spans 600 studs of front with four bots, not 72", function()
			local span = Forest.beaterLaneOffset(4) - Forest.beaterLaneOffset(5)
			expect(span).to.equal(600)
			-- Four lanes on the stand grid cover four stand spacings, so the line is as wide as the
			-- stands it is pushing at rather than as wide as one of them.
			expect(span / Forest.ROAD_LAYOUT.standSpacing).to.equal(4)
		end)

		it("gives every bot beater its OWN start and its OWN goal, from the world, by index", function()
			-- The drive's own slot list, so the claim is about what SHIPS. `place` is this world's
			-- shape: a point per index, spread by the same `beaterLaneOffset` the forest uses.
			local asked = {}
			local function place(_markers, team, index)
				table.insert(asked, { team = team, index = index })
				-- One lane per post of this hand-written line, which is what the forest's own
				-- `laneSpacingStuds = STAND_SPACING` makes true of the real one.
				return CFrame.new(-60 + (index - 1) * 60, 10, 240)
			end
			local slots = Match.botSlotsFor(
				{ posts = CURVED_POSTS, line = LINE },
				place,
				{ hunters = 0, beaters = 0 },
				{ hunters = 0, beaters = 3 },
				Match.CONFIG
			)
			expect(#slots).to.equal(3)
			-- ONE PLACEMENT PER LANE, by index, exactly as a hunter's stand is asked for.
			expect(#asked).to.equal(3)
			local seen = {}
			for _, slot in ipairs(slots) do
				expect(slot.team).to.equal("Drivers")
				expect(slot.lane > 0).to.equal(true)
				expect(seen[slot.from.Position.X]).to.equal(nil)
				seen[slot.from.Position.X] = true
				expect(slot.to).to.be.ok()
			end
			-- ...AND NO TWO LANES SHARE A GOAL, which is the whole of her complaint: four goals
			-- translated off one base goal all sat in front of the one stand she was standing on.
			local goals = {}
			for _, slot in ipairs(slots) do
				local key = string.format("%.2f,%.2f", (slot.to :: Vector3).X, (slot.to :: Vector3).Z)
				expect(goals[key]).to.equal(nil)
				goals[key] = true
			end
		end)

		it("puts each lane's goal STRAIGHT AHEAD on a curved road, so arriving IS crossing", function()
			local function place(_markers, _team, index)
				-- The lanes sit on the stand grid: these posts are 60 studs apart and wander +-30 in
				-- z, which is the forest's sine in miniature.
				return CFrame.new(-60 + (index - 1) * 60, 10, 240)
			end
			local slots = Match.botSlotsFor(
				{ posts = CURVED_POSTS, line = LINE },
				place,
				{ hunters = 0, beaters = 0 },
				{ hunters = 0, beaters = 3 },
				Match.CONFIG
			)
			expect(#slots).to.equal(3)
			for _, slot in ipairs(slots) do
				local goal = slot.to :: Vector3
				-- STRAIGHT AHEAD: the goal is on the lane's own x, not translated off a shared one.
				expect(near(goal.X, slot.from.Position.X)).to.equal(true)
				-- ...and it is PAST the line as `Match.crossedLine` measures it, against the same
				-- post. A goal that is not past the line is a bot that never crosses, and a drive
				-- that can only end on the timer.
				expect(Match.crossedLine(goal, LINE, CURVED_POSTS, Match.CONFIG.BEATER_CROSS_MARGIN_STUDS)).to.equal(
					true
				)
			end
		end)

		it("asks for the indices AFTER the real beaters, so the people keep the middle", function()
			local asked = {}
			local function place(_markers, _team, index)
				table.insert(asked, index)
				return CFrame.new(Forest.beaterLaneOffset(index), 10, 240)
			end
			local slots = Match.botSlotsFor(
				{ posts = POSTS, line = LINE },
				place,
				{ hunters = 0, beaters = 1 },
				{ hunters = 0, beaters = 4 },
				Match.CONFIG
			)
			expect(#slots).to.equal(4)
			expect(table.concat(asked, ",")).to.equal("2,3,4,5")
			for _, slot in ipairs(slots) do
				-- Nobody is on the push line: index 1 is hers.
				expect(slot.from.Position.X ~= 0).to.equal(true)
			end
		end)

		it("is the identity in `Bots.laneOf`, because the lane's points are the drive's now", function()
			local from = CFrame.new(150, 10, 240)
			local to = Vector3.new(150, 10, -20)
			local gotFrom, gotTo =
				Bots.laneOf({ id = "bot-beater-1", team = "Drivers", from = from, to = to, lane = 1 })
			expect(gotFrom).to.equal(from)
			expect(gotTo).to.equal(to)
			-- A STANDER keeps its post and gets no goal.
			local standFrom, standTo =
				Bots.laneOf({ id = "bot-hunter-1", team = "Shooters", from = from, to = nil, lane = 0 })
			expect(standFrom).to.equal(from)
			expect(standTo).to.equal(nil)
		end)
	end)

	describe("the walk", function()
		it("aims a fixed distance down the lane, and never past the goal", function()
			local goal = Vector3.new(0, 10, -20)
			local far = Lane.aimFor(Vector3.new(0, 10, 240), goal, 12)
			expect(near(far.Z, 228)).to.equal(true)
			expect(far.Y).to.equal(10) -- the Y is the bot's own: the humanoid finds the ground

			-- CLOSER THAN `AHEAD_STUDS`: the aim point IS the goal, never beyond it. A `MoveTo` past
			-- the line would walk a beater through the hunters and out the other side.
			local close = Lane.aimFor(Vector3.new(0, 10, -15), goal, 12)
			expect(near(close.Z, -20)).to.equal(true)
			expect(near(close.X, 0)).to.equal(true)
		end)

		it("says arrived inside ARRIVE_STUDS, flat, so a hill does not keep it walking", function()
			local goal = Vector3.new(0, 10, -20)
			expect(Lane.arrived(Vector3.new(0, 10, -17), goal, 4)).to.equal(true)
			expect(Lane.arrived(Vector3.new(0, 10, -15), goal, 4)).to.equal(false)
			-- Twenty studs BELOW the goal and 2 studs short of it: arrived.
			expect(Lane.arrived(Vector3.new(0, -10, -18), goal, 4)).to.equal(true)
		end)

		it("side-steps across the direction of travel, alternating nearest first", function()
			local at = Vector3.new(0, 10, 240)
			local goal = Vector3.new(0, 10, -20)
			local aim = Lane.aimFor(at, goal, 12)
			local first = Lane.sideStep(aim, at, goal, 1, CONFIG)
			local second = Lane.sideStep(aim, at, goal, 2, CONFIG)
			local third = Lane.sideStep(aim, at, goal, 3, CONFIG)
			-- ACROSS the lane: the z does not change, so the nudge cannot be "walk further on".
			expect(near(first.Z, aim.Z)).to.equal(true)
			expect(near(math.abs(first.X - aim.X), 10)).to.equal(true)
			expect(near(second.X - aim.X, -(first.X - aim.X))).to.equal(true)
			expect(near(math.abs(third.X - aim.X), 20)).to.equal(true)
		end)
	end)

	describe("the aim, and the stuck nudge (round 2, finding 1)", function()
		-- `Lane.clearAim` is the WHOLE aim decision, pure in the world's clearance reader -- which is
		-- what lets these four cases exist at all. Round 1 shipped the decision inline in
		-- `Bots.stepWalker` behind `if room or forced > 0`, where the stuck nudge was reachable only
		-- when the reader said BLOCKED: in the one world that has trunks, a bot pinned against
		-- something whose aim point happened to be clear was counted and never moved.
		local at = Vector3.new(0, 10, 240)
		local goal = Vector3.new(0, 10, -20)
		local function always(value: boolean)
			return function()
				return value
			end
		end

		it("walks straight down the lane when the way is clear and it is not stuck", function()
			local aim, stepped = Lane.clearAim(at, goal, 0, always(true), CONFIG)
			expect(stepped).to.equal(0)
			expect(aim).to.equal(Lane.aimFor(at, goal, CONFIG.AHEAD_STUDS))
		end)

		it("NUDGES A STUCK BOT EVEN WHEN THE READER SAYS THE WAY IS CLEAR", function()
			-- THIS IS THE CASE ROUND 1 COULD NOT REACH, and it is the one that matters: a bot is
			-- stuck BECAUSE the thing holding it is not where the 12-stud whisker is looking -- its
			-- shoulder, a root under its feet, another bot. "The aim looks fine" is the stuck case,
			-- not an exemption from it. Delete the `forced` branch in `Lane.clearAim` and this fails.
			local aim, stepped = Lane.clearAim(at, goal, 1, always(true), CONFIG)
			expect(stepped).to.equal(1)
			expect(aim).never.to.equal(Lane.aimFor(at, goal, CONFIG.AHEAD_STUDS))
			-- ...and it is the FIRST side candidate, nearest first.
			expect(aim).to.equal(Lane.sideStep(Lane.aimFor(at, goal, CONFIG.AHEAD_STUDS), at, goal, 1, CONFIG))
		end)

		it("nudges round a blocked point even when the bot is moving fine", function()
			-- Blocked straight ahead, clear 10 studs to the side: the ordinary trunk case.
			local plain = Lane.aimFor(at, goal, CONFIG.AHEAD_STUDS)
			local first = Lane.sideStep(plain, at, goal, 1, CONFIG)
			local reader = function(point: Vector3)
				return (point - plain).Magnitude > 0.01
			end
			local aim, stepped = Lane.clearAim(at, goal, 0, reader, CONFIG)
			expect(stepped).to.equal(1)
			expect(aim).to.equal(first)
		end)

		it("walks at the lane point anyway when nothing within SIDE_TRIES is clear", function()
			-- A bot that refuses to move is worse than a bot that bumps a trunk, and the stuck
			-- counter is what says so -- the same reasoning `beaterStartPosition` gives for putting a
			-- beater down behind the crossing when no clear spot was found.
			local aim, stepped = Lane.clearAim(at, goal, 1, always(false), CONFIG)
			expect(stepped).to.equal(0)
			expect(aim).to.equal(Lane.aimFor(at, goal, CONFIG.AHEAD_STUDS))
		end)

		it("treats a world with no clearance reader as all clear, which is the DEV arena", function()
			local aim, stepped = Lane.clearAim(at, goal, 0, nil, CONFIG)
			expect(stepped).to.equal(0)
			expect(aim).to.equal(Lane.aimFor(at, goal, CONFIG.AHEAD_STUDS))
			-- ...but a stuck bot still gets its nudge there.
			local nudged, steps = Lane.clearAim(at, goal, 1, nil, CONFIG)
			expect(steps).to.equal(1)
			expect(nudged).never.to.equal(aim)
		end)
	end)

	-- ---------------------------------------------------------------- not getting stuck (task 208)
	--
	-- KAREN, 2026-10-18 ~14:20: *"bot beater stuck we definatly need to fix that they not stuck the
	-- can avoid"*. MEASURED first, in her own Forest Test, all four places, every bot at 2 Hz
	-- (`docs/research/2026-10-19-bots-unstuck.md` section 4): four episodes over three seconds, the
	-- worst **169.1 s**, which hung the whole drive -- a drive ends when the line is through.
	--
	-- EVERY BRANCH OF THE LADDER HAS A CASE THAT ENTERS IT: `jump`, `sidestep` and `backoff` are
	-- three separate cases below, not one case about the easiest of them.
	describe("the fast stuck test (task 208)", function()
		it("is stuck when it was told to walk and covered almost nothing", function()
			-- 0.05 studs/s is what the 169-second pin actually measured.
			expect(Lane.isStuck(0.04, 0.8, 5, CONFIG)).to.equal(true)
		end)

		it("is NOT stuck when it is walking", function()
			-- 4.7 studs/s is what an unobstructed bot measured in the same drive: two decimal orders
			-- of room between the two answers, which is why this threshold needs no tuning.
			expect(Lane.isStuck(3.76, 0.8, 5, CONFIG)).to.equal(false)
		end)

		it("is NOT stuck inside its own window, however little it moved", function()
			-- The window has to close before it can answer: a shorter sample is noise.
			expect(Lane.isStuck(0.0, 0.5, 5, CONFIG)).to.equal(false)
		end)

		it("is NOT stuck when it was never told to move, which is a held or arrived bot", function()
			expect(Lane.isStuck(0.0, 2.0, 0, CONFIG)).to.equal(false)
			expect(Lane.isStuck(0.0, 2.0, CONFIG.STUCK_ORDERED_SPEED - 0.1, CONFIG)).to.equal(false)
		end)

		it("reads the SHIPPED numbers as a pin at the measured speeds", function()
			-- The one case here made of `Bots.CONFIG` rather than of hand-written numbers, because
			-- the claim is about the shipped build: the pin this task fixes trips it, and the walk
			-- this task must not change does not.
			local shipped = Bots.CONFIG
			expect(Lane.isStuck(0.05 * 0.8, 0.8, shipped.WALK_SPEED, shipped)).to.equal(true)
			expect(Lane.isStuck(4.7 * 0.8, 0.8, shipped.WALK_SPEED, shipped)).to.equal(false)
		end)
	end)

	describe("going round it (task 208)", function()
		local at = Vector3.new(0, 10, 240)
		local goal = Vector3.new(0, 10, -20)

		it("deflects the LANE and keeps the aim AHEAD_STUDS out, which is what keeps four a line", function()
			local straight = Lane.aimFor(at, goal, CONFIG.AHEAD_STUDS)
			local turned = Lane.turnedAim(at, goal, 32, CONFIG)
			expect(near((turned - at).Magnitude, CONFIG.AHEAD_STUDS, 0.05)).to.equal(true)
			expect(near((straight - at).Magnitude, CONFIG.AHEAD_STUDS, 0.05)).to.equal(true)
			local a = (straight - at).Unit
			local b = (turned - at).Unit
			expect(near(math.deg(math.acos(math.clamp(a:Dot(b), -1, 1))), 32, 0.5)).to.equal(true)
			expect(near(turned.Y, at.Y, 0.001)).to.equal(true)
		end)

		it("never aims past the goal, so a deflection cannot walk a beater through the line", function()
			local close = Vector3.new(0, 10, -15)
			local turned = Lane.turnedAim(close, goal, 88, CONFIG)
			expect((turned - close).Magnitude <= 5.01).to.equal(true)
		end)

		it("takes the SMALLEST deflection that has room (Reynolds), on its own side first", function()
			-- Blocked straight ahead and at 18 degrees, clear at 32.
			local bad = Lane.turnedAim(at, goal, 18, CONFIG)
			local blockedAt = function(point: Vector3)
				return (point - bad).Magnitude < 0.01
			end
			local aim = Lane.detourAim(at, goal, 1, blockedAt, CONFIG)
			expect(aim).to.be.ok()
			expect(((aim :: Vector3) - Lane.turnedAim(at, goal, 32, CONFIG)).Magnitude < 0.01).to.equal(true)
		end)

		it("goes the OTHER way for a bot whose side is the other one", function()
			local clear = function()
				return false
			end
			local right = Lane.detourAim(at, goal, 1, clear, CONFIG)
			local left = Lane.detourAim(at, goal, -1, clear, CONFIG)
			expect(right).to.be.ok()
			expect(left).to.be.ok()
			expect(((right :: Vector3) - Lane.turnedAim(at, goal, 18, CONFIG)).Magnitude < 0.01).to.equal(true)
			expect(((left :: Vector3) - Lane.turnedAim(at, goal, -18, CONFIG)).Magnitude < 0.01).to.equal(true)
		end)

		it("answers NOTHING when the whole fan is blocked, which is boxed in and not a lie", function()
			local everything = function()
				return true
			end
			expect(Lane.detourAim(at, goal, 1, everything, CONFIG)).to.equal(nil)
		end)

		it("spends at most DETOUR_CASTS casts", function()
			local spent = 0
			local everything = function()
				spent += 1
				return true
			end
			Lane.detourAim(at, goal, 1, everything, CONFIG)
			expect(spent).to.equal(CONFIG.DETOUR_CASTS)
		end)
	end)

	describe("the recovery ladder (task 208)", function()
		local at = Vector3.new(0, 10, 240)
		local goal = Vector3.new(0, 10, -20)

		it("JUMPS a low thing -- the branch ioquake3 calls a barrier jump", function()
			expect(Lane.recoveryFor(3.0, CONFIG.JUMP_OVER_STUDS - 0.5, 1, CONFIG)).to.equal("jump")
			-- ...and the aim does NOT move for a jump: the jump is the action.
			local aim = Lane.recoverAim(at, goal, "jump", 1, CONFIG)
			expect(aim).to.equal(Lane.aimFor(at, goal, CONFIG.AHEAD_STUDS))
		end)

		it("SIDESTEPS anything taller -- a trunk, or a body", function()
			expect(Lane.recoveryFor(3.0, CONFIG.JUMP_OVER_STUDS + 0.5, 1, CONFIG)).to.equal("sidestep")
			-- A measured 5-stud body, which is what `ForestTest.laneAhead` reports for a person: it
			-- is gone round and never jumped over.
			expect(Lane.recoveryFor(2.4, 5, 1, CONFIG)).to.equal("sidestep")
			local aim = Lane.recoverAim(at, goal, "sidestep", 1, CONFIG)
			expect(aim).to.equal(Lane.sideStep(Lane.aimFor(at, goal, CONFIG.AHEAD_STUDS), at, goal, 1, CONFIG))
		end)

		it("SIDESTEPS with no measurement at all, which is the DEV arena", function()
			expect(Lane.recoveryFor(nil, nil, 1, CONFIG)).to.equal("sidestep")
		end)

		it("BACKS OFF once the tries run out, and backing off aims BEHIND the bot", function()
			expect(Lane.recoveryFor(3.0, 2, CONFIG.BACK_OFF_AFTER_TRIES, CONFIG)).to.equal("backoff")
			local aim = Lane.recoverAim(at, goal, "backoff", 3, CONFIG)
			-- BEHIND: further from the goal than the bot is.
			local before = Vector3.new(at.X - goal.X, 0, at.Z - goal.Z).Magnitude
			local after = Vector3.new(aim.X - goal.X, 0, aim.Z - goal.Z).Magnitude
			expect(after > before).to.equal(true)
			-- ...and offset across the lane, so the next try starts from clear ground.
			expect(math.abs(aim.X) > 0.1).to.equal(true)
		end)

		it("alternates the side as the tries climb, so a bot does not lean harder on one trunk", function()
			local first = Lane.recoverAim(at, goal, "sidestep", 1, CONFIG)
			local second = Lane.recoverAim(at, goal, "sidestep", 2, CONFIG)
			expect(first.X > 0).to.equal(true)
			expect(second.X < 0).to.equal(true)
			-- ...and it widens: try 3 is two steps out, not one.
			local third = Lane.recoverAim(at, goal, "sidestep", 3, CONFIG)
			expect(math.abs(third.X) > math.abs(first.X)).to.equal(true)
		end)

		it("holds the recovery for longer than the sidestep it committed to takes to walk", function()
			-- THE RELATION, not a number: `RECOVER_HOLD_SECONDS` has to cover `SIDE_STEP_STUDS` at
			-- `WALK_SPEED`, or the bot turns back into the thing before it is past it -- the boar's
			-- `WEDGE_HOLD_SECONDS` reasoning, and the defect this task measured.
			local shipped = Bots.CONFIG
			expect(shipped.RECOVER_HOLD_SECONDS >= shipped.SIDE_STEP_STUDS / shipped.WALK_SPEED).to.equal(true)
			-- ...and a detour's hold outlives the interval that would re-decide it.
			expect(shipped.DETOUR_HOLD_SECONDS > 1 / shipped.SEE_HZ).to.equal(true)
			-- ...and a jump clears what it is allowed to jump.
			expect(shipped.JUMP_HEIGHT_STUDS > shipped.JUMP_OVER_STUDS).to.equal(true)
		end)
	end)

	describe("where the hunters' line is, for this beater", function()
		it("is the nearest stand LATERALLY on a curved road, not the nearest stand overall", function()
			-- A beater walking down x = 60 on the forest's curve. Stand 3 stands 30 studs north of the
			-- plane and is 240 studs away; stand 2 sits ON the plane and is nearer in a straight line
			-- from some points -- but stand 3 is the one he is walking at.
			local reference, normal = Match.lineReferenceFor(Vector3.new(60, 11, 240), LINE, CURVED_POSTS)
			expect(reference).to.equal(Vector3.new(60, 11, 30))
			expect(normal).to.equal(Vector3.new(0, 0, 1))
		end)

		it("falls back to the line marker itself with no posts, which is the arena", function()
			local reference = Match.lineReferenceFor(Vector3.new(0, 11, 240), LINE, {})
			expect(reference).to.equal(LINE.position)
		end)

		it("answers nothing without a line to measure from", function()
			expect(Match.lineReferenceFor(Vector3.new(0, 11, 240), nil, POSTS)).to.equal(nil)
			expect(Match.lineReferenceFor(nil, LINE, POSTS)).to.equal(nil)
			expect(Match.beaterGoalFor(Vector3.new(0, 11, 240), nil, POSTS, 20)).to.equal(nil)
		end)

		it("leaves Match.crossedLine's own answers exactly as they were before the factoring", function()
			-- The behaviour `match_scene.spec` already pins, re-stated here because THIS task is what
			-- pulled the reference out of it. On the line is not across it; a stride past is not either.
			expect(Match.crossedLine(Vector3.new(0, 11, 240), LINE, POSTS, 10)).to.equal(false)
			expect(Match.crossedLine(Vector3.new(0, 11, 0), LINE, POSTS, 10)).to.equal(false)
			expect(Match.crossedLine(Vector3.new(0, 11, -9), LINE, POSTS, 10)).to.equal(false)
			expect(Match.crossedLine(Vector3.new(0, 11, -10), LINE, POSTS, 10)).to.equal(true)
			-- the curved road's own case: measured against stand 3, 30 studs north of the plane
			expect(Match.crossedLine(Vector3.new(60, 11, 25), LINE, CURVED_POSTS, 10)).to.equal(false)
			expect(Match.crossedLine(Vector3.new(60, 11, 19), LINE, CURVED_POSTS, 10)).to.equal(true)
		end)
	end)

	describe("where a bot beater walks to", function()
		it("is the margin PAST the nearest stand, on the hunters' side", function()
			local goal = Match.beaterGoalFor(Vector3.new(0, 11, 240), LINE, POSTS, 20)
			expect(goal).to.equal(Vector3.new(0, 11, -20))
			-- ...and arriving there IS crossed, with the drive's own margin to spare. That is the
			-- whole reason GOAL_PAST_LINE_STUDS is twice BEATER_CROSS_MARGIN_STUDS.
			expect(Match.crossedLine(goal, LINE, POSTS, Match.CONFIG.BEATER_CROSS_MARGIN_STUDS)).to.equal(true)
		end)

		it("follows the curve: a bot on x = 60 walks past stand 3, not past the plane", function()
			local goal = Match.beaterGoalFor(Vector3.new(60, 11, 240), LINE, CURVED_POSTS, 20)
			expect(goal).to.equal(Vector3.new(60, 11, 10))
			expect(Match.crossedLine(goal, LINE, CURVED_POSTS, Match.CONFIG.BEATER_CROSS_MARGIN_STUDS)).to.equal(true)
		end)
	end)

	describe("the drive's slot list", function()
		it("gives each bot hunter a post of its own, after the real hunters", function()
			local asked = {}
			local place = function(_markers, team, index)
				table.insert(asked, string.format("%s:%d", team, index))
				return CFrame.new(index * 10, 11, 0)
			end
			local slots = Match.botSlotsFor(
				{ posts = POSTS, line = LINE },
				place,
				{ hunters = 2, beaters = 0 },
				{ hunters = 3, beaters = 0 },
				Match.CONFIG
			)
			expect(#slots).to.equal(3)
			-- AFTER the two real hunters, so a bot never asks for a post somebody is standing on.
			expect(asked[1]).to.equal("Shooters:3")
			expect(asked[2]).to.equal("Shooters:4")
			expect(asked[3]).to.equal("Shooters:5")
			for _, slot in ipairs(slots) do
				expect(slot.team).to.equal("Shooters")
				expect(slot.to).to.equal(nil) -- a hunter STANDS
				expect(slot.lane).to.equal(0)
			end
		end)

		it("asks the world for ONE PLACEMENT PER LANE, by index, as it does for a hunter's stand", function()
			-- IT USED TO TAKE THE BASE ONCE (task 161), on the grounds that this world's beater
			-- placement is a single MEASURED point and four asks would be four measurements of one
			-- fact. Task 167 is the other side of that: a line has to span the hunters' front, and
			-- the only thing that can measure a lane's own ground, trunks and goal is the world --
			-- which `ForestTest.beaterStartPosition(index)` now does per lane. Karen: *"and seem like
			-- all bots came to me"*.
			local asked = {}
			local place = function(_markers, team, index)
				if team == "Drivers" then
					table.insert(asked, index)
				end
				return CFrame.new(index * 150 - 450, 10, 240)
			end
			local slots = Match.botSlotsFor(
				{ posts = POSTS, line = LINE },
				place,
				{ hunters = 0, beaters = 0 },
				{ hunters = 0, beaters = 4 },
				Match.CONFIG
			)
			expect(#slots).to.equal(4)
			expect(table.concat(asked, ",")).to.equal("1,2,3,4")
		end)

		it("makes a bot beater a STANDER in a world with no drive line, rather than walk it nowhere", function()
			local place = function()
				return CFrame.new(0, 10, 240)
			end
			local slots = Match.botSlotsFor(
				{ posts = POSTS, line = nil },
				place,
				{ hunters = 0, beaters = 0 },
				{ hunters = 0, beaters = 2 },
				Match.CONFIG
			)
			expect(#slots).to.equal(2)
			for _, slot in ipairs(slots) do
				expect(slot.to).to.equal(nil)
			end
		end)

		it("asks for nothing at all when a world has no placement answer", function()
			local place = function()
				return nil
			end
			local slots = Match.botSlotsFor(
				{ posts = POSTS, line = LINE },
				place,
				{ hunters = 0, beaters = 0 },
				{ hunters = 4, beaters = 4 },
				Match.CONFIG
			)
			expect(#slots).to.equal(0)
			-- ...and with no placement function at all, which is a world that injected none.
			expect(
				#Match.botSlotsFor({ posts = POSTS, line = LINE }, nil, {}, { hunters = 4, beaters = 4 }, Match.CONFIG)
			).to.equal(0)
		end)
	end)

	-- -------------------------------------------------------------- how long the walk is (task 162)
	describe("the length of the walk", function()
		-- EVERY NUMBER BELOW IS THE SHIPPED ONE. That is the point of this block: the walk is a
		-- quotient of three configs in three files, and until task 162 it was only ever written in a
		-- comment -- so a drive ran for 29 seconds and nothing failed.
		local function travelStuds(): number
			return Forest.LINE.spawnNorthStuds + Forest.BEATER.behindLineStuds + Match.CONFIG.BOTS.GOAL_PAST_LINE_STUDS
		end

		it("takes about two minutes at the bot pace, and that is Karen's number", function()
			local seconds = travelStuds() / Bots.CONFIG.WALK_SPEED
			-- KAREN: *"need longer walk for beaters let's say 2 min"*. +-15 s is the tolerance on
			-- "let's say", and it is deliberately not +-1: the pair is two round numbers and the
			-- ground is a hill, so the exact quotient is not the thing being claimed.
			expect(seconds > 105).to.equal(true)
			expect(seconds < 135).to.equal(true)
			TestKit.note(
				string.format(
					"a bot beater walks %.0f studs at %.1f studs/s = %.1f s (flat; the measured ground path from the middle stand's pad is 612 studs, so ~%.0f s)",
					travelStuds(),
					Bots.CONFIG.WALK_SPEED,
					seconds,
					(612 + Match.CONFIG.BOTS.GOAL_PAST_LINE_STUDS) / Bots.CONFIG.WALK_SPEED
				)
			)
		end)

		it("finishes well inside the drive clock, so the clock is still the backstop", function()
			-- THE CLOCK STILL ENDS EVERY DRIVE and the crossing can only ever end one EARLIER
			-- (`Match.CONFIG.END_ON_BEATERS_CROSS`'s own comment). If the walk ever grew past the
			-- forest's clock, the early end would stop happening at all and Karen's
			-- *"Timer or when all beaters cross line of hunters"* would quietly become "timer".
			local seconds = travelStuds() / Bots.CONFIG.WALK_SPEED
			expect(seconds < Forest.DRIVE.seconds).to.equal(true)
			-- ...with room for the hill, the trunks and the side-steps: the walk is measured flat and
			-- the ground is not. A third of the clock is the margin.
			expect(Forest.DRIVE.seconds - seconds > Forest.DRIVE.seconds / 3).to.equal(true)
		end)

		it("walks at a real walking pace, in metres", function()
			-- `SPOOK.METRES_PER_STUD` is the one conversion in this world (0.28), the same number
			-- `Horn.CONFIG`, `Report.CONFIG` and `Boar.CONFIG.SENSE` publish. A man working a wood
			-- does 1.2-1.5 m/s; the 9 studs/s this shipped with was 2.52 m/s, which is a jog.
			local metresPerSecond = Bots.CONFIG.WALK_SPEED * Forest.SPOOK.METRES_PER_STUD
			expect(metresPerSecond >= 1.2).to.equal(true)
			expect(metresPerSecond <= 1.5).to.equal(true)
		end)

		it("keeps the aim point ahead of the bot between re-issues", function()
			-- `AHEAD_STUDS`'s own comment claims the aim point is "always still ahead of the bot when
			-- the next re-issue comes round", and that is only true while the bot cannot COVER it in
			-- `MOVE_REISSUE_SECONDS`. At `WALK_SPEED` 9 the product was 18 against 12, so the comment
			-- was false; at 5 it is 10. Asserted rather than commented, because both numbers are
			-- feel dials somebody will turn.
			expect(Bots.CONFIG.AHEAD_STUDS >= Bots.CONFIG.WALK_SPEED * Bots.CONFIG.MOVE_REISSUE_SECONDS).to.equal(true)
		end)

		it("does not slow a real beater down, and says what that costs", function()
			-- TASK 162's DISPATCH, SPELLED OUT: nothing in `Bots` writes a player's `WalkSpeed` --
			-- `Match.Body` is the only writer of it -- so a real beater still walks at this world's
			-- own `DRIVERS.walkSpeed` and reaches the road long before the bot line does. The drive
			-- ends when ALL beaters are through, so what she gets is a wait, not a short drive.
			expect(Forest.DRIVERS.walkSpeed > Bots.CONFIG.WALK_SPEED).to.equal(true)
			local hers = travelStuds() / Forest.DRIVERS.walkSpeed
			local theirs = travelStuds() / Bots.CONFIG.WALK_SPEED
			TestKit.note(
				string.format(
					"a real beater walks it in %.0f s at %d studs/s and then waits %.0f s for the bot line",
					hers,
					Forest.DRIVERS.walkSpeed,
					theirs - hers
				)
			)
		end)
	end)
	-- ---------------------------------------------------------------- the gait (task 164)
	--
	-- KAREN, 2026-10-12: *"bots looks odd improve waliking"*. `Rig.gait` is the whole of the answer
	-- that is not an Instance: a ground speed in, a clip name and a playback rate out. Every number
	-- it holds was MEASURED off the engine's own `Animate` script (`Rig.GAIT`'s header carries the
	-- table of WalkSpeed against track Speed), so these cases are that measurement asserted rather
	-- than a comment claiming it.
	describe("the gait", function()
		it("plays the walk at the rate the engine itself plays it at", function()
			-- MEASURED: a real player at WalkSpeed 5, holding W, played the walk clip at Speed
			-- 0.7411 (and 0.7473 on a second run). The law behind the whole sweep is
			-- `speed / NATURAL_WALK_SPEED`, so this is the engine's own number reproduced from our
			-- own constant, to within the sampling noise of the measurement.
			local clip, rate = Rig.gait(5, nil)
			expect(clip).to.equal("walk")
			expect(near(rate, 0.7411, 0.01)).to.equal(true)

			-- ...and at the pace a bot is actually SET to walk at, which is the defect: the clip was
			-- running at 1.000 while the body made 5 studs/s.
			local _, atPace = Rig.gait(Bots.CONFIG.WALK_SPEED, nil)
			expect(atPace < 1).to.equal(true)
		end)

		it("scales with the ground speed, and never past either end", function()
			-- The sweep's own shape: double the speed, double the rate.
			local _, slow = Rig.gait(2.5, nil)
			local _, fast = Rig.gait(5, nil)
			expect(near(fast, slow * 2, 0.02)).to.equal(true)

			-- 1.0 IS THE CEILING, because above `NATURAL_WALK_SPEED` the engine stops speeding the
			-- walk up and fades the RUN clip in by weight instead -- measured, and a run clip is not
			-- a thing a beater has.
			local _, quick = Rig.gait(40, nil)
			expect(quick).to.equal(Rig.GAIT.MAX_RATE)
			-- ...and the floor is the engine's own, so a bot inching along is not slow motion.
			local _, crawl = Rig.gait(Rig.GAIT.WALK_ABOVE_STUDS + 0.001, nil)
			expect(crawl).to.equal(Rig.GAIT.MIN_RATE)
		end)

		it("idles when it is not moving", function()
			local clip, rate = Rig.gait(0, "walk")
			expect(clip).to.equal("idle")
			expect(rate).to.equal(1)
		end)

		it("cannot flicker: the dead band keeps whatever is playing", function()
			-- A BOT SHOULDERING A TRUNK sits at a fraction of a stud per second, and with ONE
			-- threshold it would change clip every step at `STEP_HZ` 5 -- the stop-start the
			-- dispatch asks about. Inside the band the answer is "what you are already doing".
			local middle = (Rig.GAIT.IDLE_BELOW_STUDS + Rig.GAIT.WALK_ABOVE_STUDS) / 2
			expect((Rig.gait(middle, "walk"))).to.equal("walk")
			expect((Rig.gait(middle, "idle"))).to.equal("idle")
			-- Nothing playing yet inside the band: stand, do not start a walk nobody asked for.
			expect((Rig.gait(middle, nil))).to.equal("idle")

			-- THE BAND IS REAL -- a band and not two names for one number.
			expect(Rig.GAIT.WALK_ABOVE_STUDS > Rig.GAIT.IDLE_BELOW_STUDS).to.equal(true)

			-- AND IT ACTUALLY STOPS THE FLICKER, counted rather than argued: a speed wobbling
			-- inside the band 20 times switches clip NOT ONCE, where a single threshold at either
			-- edge would switch on all 20 crossings.
			local playing: string? = "walk"
			local switches = 0
			for i = 1, 20 do
				local speed = if i % 2 == 0 then Rig.GAIT.IDLE_BELOW_STUDS + 0.01 else Rig.GAIT.WALK_ABOVE_STUDS - 0.01
				local clip = (Rig.gait(speed, playing))
				if clip ~= playing then
					switches += 1
				end
				playing = clip
			end
			expect(switches).to.equal(0)
		end)

		it("holds the relation between the bot's pace and the clip's own, across two files", function()
			-- THE RELATION THAT MADE THE SLIDE, asserted between the two files that hold it:
			-- `Bots.CONFIG.WALK_SPEED` is the pace, `Rig.GAIT.NATURAL_WALK_SPEED` is what the clip
			-- was authored for, and 5 < 6.74 is why playing it at 1.000 slid the feet.
			expect(Rig.GAIT.NATURAL_WALK_SPEED > Bots.CONFIG.WALK_SPEED).to.equal(true)
		end)
	end)

	-- TASK 166. KAREN, 2026-10-12: *"yes, bots are good , just we will change horn and behaviuor hwn
	-- they push has to put to mauth blow horn"*. A bot beater now raises the horn to its face for the
	-- length of a blast. Three claims, all pure: the WINDOW (when the arm is up), the SEQUENCE (what
	-- the pose is, and that it only speaks for two joints), and the two numbers agreeing across files.
	describe("the horn at the mouth (task 166)", function()
		it("is up for exactly the length of a blast, and down before and after", function()
			-- `Bots.blowing` is the whole state machine and it is a window over a stamp: a bot with
			-- no blast behind it has its arm down, and so has one whose blast has finished.
			local bot: any = { blowUntil = nil }
			expect(Bots.blowing(bot, 100)).to.equal(false)
			expect(Bots.blowing(nil, 100)).to.equal(false)
			bot.blowUntil = 100.9
			expect(Bots.blowing(bot, 100)).to.equal(true)
			expect(Bots.blowing(bot, 100.89)).to.equal(true)
			-- THE EDGE IS EXCLUSIVE, so the arm comes down on the frame the blast ends and not one
			-- window later.
			expect(Bots.blowing(bot, 100.9)).to.equal(false)
			expect(Bots.blowing(bot, 200)).to.equal(false)
		end)

		it("is a no-op for a rig with no blow clip, so a failed registration costs nothing", function()
			-- ROUND 1 FINDING 2: this case used to be named for idempotence and proved none of it --
			-- both answers below come from `if track == nil then return false end`, so the guard,
			-- the Play/Stop calls and the `blowing` write were all unasserted. It keeps the claim it
			-- really makes, and the PLAYING half is `bots_live.spec`'s "raises the horn on top of
			-- the gait, and the drive's end takes it down again", on a real rig.
			local clips: any = {}
			-- No track: nothing to play, and nothing counted -- which is the state of every rig in a
			-- session where `Rig.blowAnimationId` could not register the pose.
			expect(Rig.blow(clips, true)).to.equal(false)
			expect(clips.blowing).to.equal(nil)
			-- A fresh rig asked to blow nothing is a no-op, not a pose (the `holdTool` rule).
			expect(Rig.blow(clips, false)).to.equal(false)
			-- ...and nil is not a rig.
			expect(Rig.blow(nil, true)).to.equal(false)
		end)

		it("speaks for the shoulder and the elbow ONLY, at a priority above the gait", function()
			local sequence = Rig.blowSequence(Rig.BLOW)
			expect(sequence:IsA("KeyframeSequence")).to.equal(true)
			-- A HELD POSE IS A LOOP OF ONE POSE, and two keyframes are what give the clip a length.
			expect(sequence.Loop).to.equal(true)
			expect(sequence.Priority).to.equal(Enum.AnimationPriority.Action)
			local keyframes = sequence:GetChildren()
			expect(#keyframes).to.equal(2)

			for _, keyframe in ipairs(keyframes) do
				expect(keyframe:IsA("Keyframe")).to.equal(true)
				-- THE CHAIN FROM THE ROOT, because a Pose is found by its place in the hierarchy.
				local node: Instance = keyframe
				for _, name in ipairs({ "HumanoidRootPart", "LowerTorso", "UpperTorso" }) do
					local pose = node:FindFirstChild(name)
					expect(pose).to.be.ok()
					-- NO WEIGHT ABOVE THE SHOULDER: a clip that wrote identity over the torso at
					-- `Action` would freeze a walking beater's lean for every blast.
					expect((pose :: any).Weight).to.equal(0)
					node = pose :: Instance
				end
				local upperArm = node:FindFirstChild("RightUpperArm")
				expect(upperArm).to.be.ok()
				expect((upperArm :: any).Weight).to.equal(1)
				local lowerArm = (upperArm :: Instance):FindFirstChild("RightLowerArm")
				expect(lowerArm).to.be.ok()
				expect((lowerArm :: any).Weight).to.equal(1)
				-- THE WRIST IS THE TOOL CLIP'S: named to close the chain, and silent.
				local hand = (lowerArm :: Instance):FindFirstChild("RightHand")
				expect(hand).to.be.ok()
				expect((hand :: any).Weight).to.equal(0)

				-- THE TWO ANGLES ARE THE DATA'S, in radians, read back off the CFrames.
				local shoulder = Rig.BLOW.SHOULDER_DEG
				local x, y, z = (upperArm :: any).CFrame:ToEulerAnglesXYZ()
				expect(math.deg(x)).to.be.near(shoulder.x, 1e-3)
				expect(math.deg(y)).to.be.near(shoulder.y, 1e-3)
				expect(math.deg(z)).to.be.near(shoulder.z, 1e-3)
				local ex = ((lowerArm :: any).CFrame:ToEulerAnglesXYZ())
				expect(math.deg(ex)).to.be.near(Rig.BLOW.ELBOW_DEG.x, 1e-3)
			end
			sequence:Destroy()

			-- THE ARM REALLY MOVES: an arm raise of a few degrees is not a raise. The shoulder
			-- swings well past horizontal and the elbow folds hard, which is what brings the hand up
			-- in front of the face.
			expect(math.abs(Rig.BLOW.SHOULDER_DEG.x) > 60).to.equal(true)
			expect(math.abs(Rig.BLOW.ELBOW_DEG.x) > 60).to.equal(true)
			-- UP QUICKLY, DOWN A LITTLE SLOWER, and both inside the blast they have to fit in.
			expect(Rig.BLOW.RAISE_SECONDS > 0).to.equal(true)
			expect(Rig.BLOW.LOWER_SECONDS > Rig.BLOW.RAISE_SECONDS).to.equal(true)
			local hold = Horn.CONFIG.BLOW_SECONDS
			expect(Rig.BLOW.RAISE_SECONDS + Rig.BLOW.LOWER_SECONDS < hold * 2).to.equal(true)
			TestKit.note(
				string.format(
					"horn pose: shoulder (%d, %d, %d) elbow (%d, %d, %d), up %.2f s, held %.2f s (Horn.BLOW_SECONDS), down %.2f s",
					Rig.BLOW.SHOULDER_DEG.x,
					Rig.BLOW.SHOULDER_DEG.y,
					Rig.BLOW.SHOULDER_DEG.z,
					Rig.BLOW.ELBOW_DEG.x,
					Rig.BLOW.ELBOW_DEG.y,
					Rig.BLOW.ELBOW_DEG.z,
					Rig.BLOW.RAISE_SECONDS,
					hold,
					Rig.BLOW.LOWER_SECONDS
				)
			)
		end)

		it("holds the arm up for as long as the Tool's own tilt, across two files", function()
			-- THE RELATION THAT MATTERS, and the reason the length is handed in at the composition
			-- root rather than written in `Bots.CONFIG`: `Weapon.Horn.blowTool` restores the Tool's
			-- grip after `Horn.CONFIG.BLOW_SECONDS`, and the arm comes down off the same number. Two
			-- numbers would be two answers to "how long is a blast".
			expect(Horn.CONFIG.BLOW_SECONDS > 0).to.equal(true)
			-- ...and a blast is at the mouth for less time than the cooldown allows the next one, so
			-- a raised arm can never still be up when the horn sounds again.
			expect(Horn.CONFIG.BLOW_SECONDS < Horn.CONFIG.COOLDOWN).to.equal(true)
		end)
	end)
end
