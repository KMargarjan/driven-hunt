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
local Match = require(ServerScriptService:WaitForChild("Match"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Lane = Bots.Lane

-- This spec's own numbers, the shape `Bots.CONFIG` is.
local CONFIG = {
	LANE_SPACING_STUDS = 18,
	SIDE_STEP_STUDS = 10,
	SIDE_TRIES = 4,
	ARRIVE_STUDS = 4,
	AHEAD_STUDS = 12,
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
		it("alternates outward from the middle, nearest first, and never issues lane 0", function()
			expect(Lane.offsetFor(1, CONFIG)).to.equal(18)
			expect(Lane.offsetFor(2, CONFIG)).to.equal(-18)
			expect(Lane.offsetFor(3, CONFIG)).to.equal(36)
			expect(Lane.offsetFor(4, CONFIG)).to.equal(-36)
			-- LANE 0 IS THE MIDDLE AND IT IS THE PEOPLE'S: the forest puts every real beater on one
			-- measured point, on the push line through the stand the drive aims at, so the bots flank
			-- rather than stand on top of her.
			expect(Lane.offsetFor(0, CONFIG)).to.equal(0)
		end)

		it("leaves lane 0 empty for the real beaters, in the slots the drive actually issues", function()
			-- The drive's own slot list, so the claim is about what SHIPS and not about the helper.
			local base = CFrame.new(0, 10, 240)
			local place = function()
				return base
			end
			local slots = Match.botSlotsFor(
				{ posts = POSTS, line = LINE },
				place,
				{ hunters = 0, beaters = 0 },
				{ hunters = 0, beaters = 4 },
				Match.CONFIG
			)
			expect(#slots).to.equal(4)
			for _, slot in ipairs(slots) do
				expect(slot.lane > 0).to.equal(true)
				expect(slot.team).to.equal("Drivers")
				-- THE BASE AND THE LANE NUMBER, not the lane's own point: spreading the line is
				-- `Bots.Lane`'s job, because `Match` must not require `Bots`.
				expect(slot.from).to.equal(base)
			end
		end)

		it("spreads a straight line along world X, four bots over 72 studs", function()
			local base = CFrame.new(0, 10, 240)
			local xs = {}
			for lane = 1, 4 do
				table.insert(xs, Lane.startFor(base, lane, CONFIG).Position.X)
			end
			table.sort(xs)
			expect(xs[1]).to.equal(-36)
			expect(xs[4]).to.equal(36)
			expect(xs[4] - xs[1]).to.equal(72)
			-- ...and they all look the same way, down the push.
			expect(Lane.startFor(base, 3, CONFIG).LookVector.Z).to.equal(base.LookVector.Z)
		end)

		it("spreads along the BASE's own right on a rotated base, so a sine road stays square", function()
			-- The forest's look is at the road point under the beater, so the base can be rotated by
			-- up to 23 degrees. A line laid out on world X would not be square to the push.
			local base = CFrame.Angles(0, math.rad(90), 0) + Vector3.new(0, 10, 240)
			local one = Lane.startFor(base, 1, CONFIG).Position
			local two = Lane.startFor(base, 2, CONFIG).Position
			-- Rotated 90 degrees, "right" is -X... whichever way it points, the two lanes are 36
			-- studs apart ALONG THAT AXIS and the same distance from the base.
			expect(near((one - two).Magnitude, 36)).to.equal(true)
			expect(near((one - base.Position).Magnitude, 18)).to.equal(true)
			expect(near((two - base.Position).Magnitude, 18)).to.equal(true)
			-- ...and the offset really is along the base's right, not along world X.
			expect(near((one - base.Position):Dot(base.RightVector), 18)).to.equal(true)
		end)

		it("offsets the GOAL by the same amount, so a line that sets off abreast arrives abreast", function()
			local base = CFrame.new(0, 10, 240)
			local baseGoal = Vector3.new(0, 10, -20)
			for lane = 1, 4 do
				local start = Lane.startFor(base, lane, CONFIG).Position
				local goal = Lane.goalFor(baseGoal, base, lane, CONFIG)
				-- The sideways offset is identical at both ends, so the walk is parallel to the push.
				expect(near(goal.X, start.X)).to.equal(true)
				expect(goal.Y).to.equal(baseGoal.Y)
			end
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

		it("takes the beaters' base ONCE, however many of them there are", function()
			-- This world's beater placement is a single MEASURED point (the forest reads the ground
			-- and the trunks for it), so asking for it four times would be four measurements of one
			-- fact -- and could answer differently each time.
			local calls = 0
			local place = function(_markers, team)
				if team == "Drivers" then
					calls += 1
				end
				return CFrame.new(0, 10, 240)
			end
			Match.botSlotsFor(
				{ posts = POSTS, line = LINE },
				place,
				{ hunters = 0, beaters = 0 },
				{ hunters = 0, beaters = 4 },
				Match.CONFIG
			)
			expect(calls).to.equal(1)
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
end
