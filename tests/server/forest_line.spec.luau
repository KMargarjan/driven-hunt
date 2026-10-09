-- forest_line.spec: THE ARITHMETIC OF A FILE OF BOARS, with no world, no animal and no clock.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- `ForestTest.Line` is pure by construction -- crumbs in, an arc position or a speed out -- so every
-- rule the drive relies on is drivable here with hand-written tables. The three that have actually
-- been wrong in play get their own cases: the SIGN of a follower's slack (round 2: an unsigned
-- distance cannot tell "behind" from "overshot", so both sped up), `arcAt` finding where an animal is
-- ON the trail rather than how far it is FROM it (round 2: following a chord cuts the corner the
-- leader went round, which is a trunk), and the leader easing up for her tail.
--
-- Design: no new design document -- the playtest world's drive. TASKS.md row 127.
-- Note:   docs/research/2026-10-05-sounder-movement.md (section 4: a chain cannot orbit)
local ServerScriptService = game:GetService("ServerScriptService")

local ForestTest = require(ServerScriptService:WaitForChild("ForestTest"))
local Line = ForestTest.Line

-- A straight trail east along +X, one crumb a stud, then a right-angle turn south along -Z.
local function elbow()
	local trail = {}
	for x = 0, 20 do
		Line.addCrumb(trail, Vector3.new(x, 0, 0), 1)
	end
	for z = 1, 20 do
		Line.addCrumb(trail, Vector3.new(20, 0, -z), 1)
	end
	return trail
end

return function()
	describe("the trail", function()
		it("only remembers a crumb once the leader has moved", function()
			local trail = {}
			expect(Line.addCrumb(trail, Vector3.new(0, 0, 0), 1)).to.equal(true)
			expect(Line.addCrumb(trail, Vector3.new(0.4, 0, 0), 1)).to.equal(false)
			expect(Line.addCrumb(trail, Vector3.new(2, 0, 0), 1)).to.equal(true)
			expect(#trail).to.equal(2)
			expect(Line.length(trail)).to.equal(2)
		end)

		it("measures a station back along the path it was walked, not across it", function()
			local trail = elbow()
			-- 40 studs walked; 25 back from the head is 5 studs before the corner, on the straight.
			local point = Line.pointBack(trail, 25)
			expect(point).to.be.ok()
			expect(math.abs(point.X - 15) < 0.001).to.equal(true)
			expect(math.abs(point.Z) < 0.001).to.equal(true)
		end)

		it("has no station for a follower the leader has not yet walked past", function()
			local trail = {}
			Line.addCrumb(trail, Vector3.new(0, 0, 0), 1)
			Line.addCrumb(trail, Vector3.new(3, 0, 0), 1)
			expect(Line.pointBack(trail, 8.5)).to.equal(nil)
		end)

		it("tells an animal where it is ON the trail", function()
			local trail = elbow()
			-- Standing two studs off the straight, level with x = 12: its arc position is 12, and the
			-- order that follows is a point further ALONG the trail rather than a chord to a station.
			local at = Line.arcAt(trail, Vector3.new(12, 0, 2))
			expect(math.abs(at - 12) < 0.01).to.equal(true)
			-- ...and past the corner it keeps counting along the second leg, not back down the first.
			local after = Line.arcAt(trail, Vector3.new(20, 0, -6))
			expect(math.abs(after - 26) < 0.01).to.equal(true)
		end)

		it("refuses a branch the animal cannot have reached, when it is told where it was", function()
			-- THE DOUBLE-BACK, WHICH IS WHAT TASK 136 IS ABOUT. A leader rounding a trunk lays two
			-- passes a few studs apart; a follower on the FIRST is geometrically nearest the SECOND,
			-- and the unhinted search answers with the second one's arc length. Everything downstream
			-- then goes wrong at once: `slack` reads negative so the animal is told it has overrun
			-- and stops, and its aim is a point on the far branch so when it moves it cuts across the
			-- loop the leader just walked round.
			local trail = {}
			-- Out along z = 0, round the end, and back along z = 3: the two passes are 3 studs apart.
			for x = 0, 30, 1 do
				Line.addCrumb(trail, Vector3.new(x, 0, 0), 0.5)
			end
			for x = 30, 0, -1 do
				Line.addCrumb(trail, Vector3.new(x, 0, 3), 0.5)
			end
			-- An animal at (10, 1.6) is 1.6 studs from the OUTBOUND pass (arc 10) and 1.4 from the
			-- RETURN pass (arc ~53) -- so the RETURN branch is the nearer one, and nearest wins
			-- without a hint...
			local blind = Line.arcAt(trail, Vector3.new(10, 0, 1.6))
			-- ...so this is the number the drive used to get, and it is on the far branch.
			expect(blind > 40).to.equal(true)
			-- ...and with the hint it stays where the animal actually is.
			local hinted = Line.arcAt(trail, Vector3.new(10, 0, 1.6), 10, 14)
			expect(math.abs(hinted - 10) < 2).to.equal(true)
			-- A HINT THAT HAS FALLEN OFF THE BACK OF THE TRAIL FALLS BACK rather than answering with
			-- a stale number: the trail is trimmed from behind, so this case is reachable.
			local lost = Line.arcAt(trail, Vector3.new(10, 0, 1.6), 1000, 5)
			expect(lost > 0).to.equal(true)
		end)

		it("aims along the trail, never past the one in front and never under its own feet", function()
			-- `Line.aimFor`'s four rules, each driven on its own. 60 is the head of the trail, 0 the
			-- tail, the lookahead is 4, the no-overtake margin 1.5 and the minimum aim 2.5 -- the
			-- numbers `LINE` carries.
			local function aim(ownS: number, aheadS: number): number
				return Line.aimFor(ownS, 4, aheadS, 1.5, 2.5, 60, 0)
			end
			-- A follower with room ahead gets its lookahead.
			expect(aim(20, 40)).to.equal(24)
			-- ...one that has closed up is held short of the animal in front rather than aimed at it.
			expect(aim(20, 24)).to.equal(22.5)
			-- ...AND NEVER AT A POINT IT IS ALREADY STANDING ON. This is the rule whose absence turned
			-- 15 stuck into 58: at a 6.5-stud station the one in front is 6.5 along, so a body-length
			-- margin aimed the animal 1.0 stud ahead -- inside `LINE.ARRIVE_STUDS` -- and it stopped.
			expect(aim(20, 21)).to.equal(22.5)
			-- The head of the trail is the furthest anything can aim...
			expect(aim(58, 100)).to.equal(60)
			-- ...and the tail is the nearest.
			expect(Line.aimFor(5, 4, 6, 1.5, 2.5, 60, 9)).to.equal(9)
		end)

		it("forgets the tail nobody stands on", function()
			local trail = elbow()
			Line.trim(trail, 10)
			expect(Line.length(trail) - trail[1].s <= 11).to.equal(true)
			expect(#trail >= 2).to.equal(true)
		end)
	end)

	describe("who walks where", function()
		it("puts the sow first, the piglets in the middle and the males last", function()
			local ordered = Line.order({
				{ id = "a", kind = "male" },
				{ id = "b", kind = "cub" },
				{ id = "c", kind = "female" },
				{ id = "d", kind = "female" },
			})
			expect(ordered[1].id).to.equal("c")
			expect(ordered[2].id).to.equal("d")
			expect(ordered[3].id).to.equal("b")
			expect(ordered[4].id).to.equal("a")
		end)

		it("deals two lines so each keeps a female at its head", function()
			local groups = Line.split(
				Line.order({
					{ id = "a", kind = "female" },
					{ id = "b", kind = "female" },
					{ id = "c", kind = "cub" },
					{ id = "d", kind = "cub" },
				}),
				2
			)
			expect(#groups).to.equal(2)
			expect(groups[1][1].kind).to.equal("female")
			expect(groups[2][1].kind).to.equal("female")
		end)
	end)

	describe("holding station", function()
		it("walks the leader's speed while it is in station", function()
			expect(Line.followerSpeed(10, 1, 1.5, 0.4)).to.equal(10)
			expect(Line.followerSpeed(10, -1, 1.5, 0.4)).to.equal(10)
		end)

		it("closes when it is BEHIND and eases off when it has OVERSHOT", function()
			-- The sign is the whole point: an unsigned error made both of these speed up.
			expect(Line.followerSpeed(10, 6, 1.5, 0.4)).to.equal(14)
			expect(Line.followerSpeed(10, -6, 1.5, 0.4)).to.equal(6)
		end)

		it("keeps the sow at her pace until her tail is really behind", function()
			expect(Line.leaderSpeed(18, 5, 12, 0.45)).to.equal(18)
			expect(Line.leaderSpeed(18, 24, 12, 0.45) < 18 * 0.46).to.equal(true)
			-- ...and she never stops dead, which would open a hole in the file.
			expect(Line.leaderSpeed(18, 400, 12, 0.45) > 0).to.equal(true)
		end)
	end)
end
