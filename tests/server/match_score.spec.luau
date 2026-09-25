-- match_score.spec: points, with no players and no world. Match.Score is pure, keyed by userId, and
-- every board it returns is frozen -- so the table Karen will retune after the first two-player
-- drive is checked here exactly, in microseconds.
--
-- The points are written out rather than imported, so a config that drifts is a finding and not a
-- tautology; the last describe closes the loop the other way.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/drive.md (sections 7.1, 7.3, 12.3)
local ServerScriptService = game:GetService("ServerScriptService")

local Match = require(ServerScriptService:WaitForChild("Match"))
local Score = Match.Score

local CONFIG = {
	POINTS = {
		KILL = { head = 100, chest = 80, body = 50, legs = 30, unknown = 50 },
		ASSIST = 10,
		ASSIST_MIN_DAMAGE = 25,
		PUSH = 25,
		PUSH_RADIUS = 60,
		PUSH_WINDOW = 20,
		ESCAPE_WOUNDED = 0,
		SAFETY_PENALTY = -50,
	},
}

local function killRecord(zone: string?, killer: number?, contributors, at: number?)
	return {
		id = "Boar1",
		at = at or 1,
		killingZone = zone,
		killedByUserId = killer,
		killedByName = if killer then "p" .. tostring(killer) else nil,
		contributors = contributors or {},
	}
end

local function pointsOf(board, userId: number): number
	local row = board.rows[userId]
	return if row then row.points else 0
end

return function()
	describe("the kill", function()
		it("pays the zone of the killing shot, exactly", function()
			for zone, points in pairs({ head = 100, chest = 80, body = 50, legs = 30 }) do
				local board = (Score.kill(Score.new(), killRecord(zone, 1), nil, CONFIG))
				expect(pointsOf(board, 1)).to.equal(points)
				expect(board.rows[1].kills).to.equal(1)
			end
		end)

		it("pays an unknown zone as a body shot -- never free", function()
			local board = (Score.kill(Score.new(), killRecord("nose", 1), nil, CONFIG))
			expect(pointsOf(board, 1)).to.equal(50)
			local noZone = (Score.kill(Score.new(), killRecord(nil, 1), nil, CONFIG))
			expect(pointsOf(noZone, 1)).to.equal(50)
		end)

		it("pays an assist at the threshold and nothing one point below it", function()
			local atThreshold = (Score.kill(Score.new(), killRecord("chest", 1, { [2] = 25 }), nil, CONFIG))
			expect(pointsOf(atThreshold, 2)).to.equal(10)
			expect(atThreshold.rows[2].assists).to.equal(1)

			local below = (Score.kill(Score.new(), killRecord("chest", 1, { [2] = 24 }), nil, CONFIG))
			expect(below.rows[2]).to.equal(nil) -- one pellet is not an assist
		end)

		it("never pays the killer an assist for their own shot", function()
			local board = (Score.kill(Score.new(), killRecord("chest", 1, { [1] = 100, [2] = 40 }), nil, CONFIG))
			expect(pointsOf(board, 1)).to.equal(80) -- the kill only
			expect(board.rows[1].assists).to.equal(0)
			expect(pointsOf(board, 2)).to.equal(10)
		end)

		it("pays the drivers who pushed it, and not the shooter who killed it", function()
			local board = (Score.kill(Score.new(), killRecord("body", 1), { [1] = 5, [3] = 5 }, CONFIG))
			expect(pointsOf(board, 1)).to.equal(50) -- the killer keeps the kill, not a push
			expect(board.rows[1].pushes).to.equal(0)
			expect(pointsOf(board, 3)).to.equal(25)
			expect(board.rows[3].pushes).to.equal(1)
		end)

		it("records the first kill's time, and never overwrites it", function()
			local board = (Score.kill(Score.new(), killRecord("head", 1, nil, 11), nil, CONFIG))
			board = (Score.kill(board, killRecord("head", 1, nil, 22), nil, CONFIG))
			expect(board.rows[1].firstKillAt).to.equal(11)
			expect(board.rows[1].kills).to.equal(2)
		end)

		it("never mutates the board it was given, and freezes the one it returns", function()
			local before = (Score.kill(Score.new(), killRecord("body", 1), nil, CONFIG))
			local points = pointsOf(before, 1)
			local after = (Score.kill(before, killRecord("body", 1), nil, CONFIG))
			expect(pointsOf(before, 1)).to.equal(points)
			expect(pointsOf(after, 1)).to.equal(points * 2)
			expect(function()
				after.rows[1].points = 0
			end).to.throw()
		end)
	end)

	describe("the ones that got away, and the ones that cost", function()
		it("scores an escaped WOUNDED boar at ESCAPE_WOUNDED and counts it", function()
			local record = { id = "Boar1", reason = "escaped", mortallyWounded = true, contributors = { [1] = 60 } }
			local board = (Score.escape(Score.new(), record, CONFIG))
			expect(pointsOf(board, 1)).to.equal(0) -- zero by default: take the shot you can make
			expect(board.rows[1].escaped).to.equal(1)
		end)

		it("scores nothing at all for a boar that left unhurt", function()
			local record = { id = "Boar1", reason = "escaped", mortallyWounded = false, contributors = {} }
			local board = (Score.escape(Score.new(), record, CONFIG))
			expect(board.rows[1]).to.equal(nil)
		end)

		it("takes points off for a violation, and lets a score go negative", function()
			local board = (Score.violation(Score.new(), 1, CONFIG))
			expect(pointsOf(board, 1)).to.equal(-50)
			expect(board.rows[1].violations).to.equal(1)
		end)
	end)

	describe("the board", function()
		it("keeps a leaver's row for this drive's screen, marked left", function()
			local board = Score.join(Score.new(), 1, "Karen", "Shooters")
			board = (Score.kill(board, killRecord("head", 1), nil, CONFIG))
			board = Score.leave(board, 1)
			expect(board.rows[1].left).to.equal(true)
			expect(pointsOf(board, 1)).to.equal(100)
		end)

		it("sorts by points, then kills, then the earliest first kill, then userId", function()
			local board = Score.new()
			board = Score.join(board, 1, "one", "Shooters")
			board = Score.join(board, 2, "two", "Shooters")
			board = Score.join(board, 3, "three", "Drivers")
			board = Score.join(board, 4, "four", "Drivers")
			-- 1 and 2 both reach 100, but 2 killed first; 3 reaches 100 in two kills, which beats
			-- neither of them on the kill count but ties on points.
			board = (Score.kill(board, killRecord("head", 1, nil, 20), nil, CONFIG))
			board = (Score.kill(board, killRecord("head", 2, nil, 10), nil, CONFIG))
			board = (Score.kill(board, killRecord("body", 3, nil, 5), nil, CONFIG))
			board = (Score.kill(board, killRecord("body", 3, nil, 6), nil, CONFIG))

			local rows = Score.leaderboard(board)
			expect(rows[1].userId).to.equal(3) -- 100 points, 2 kills
			expect(rows[2].userId).to.equal(2) -- 100 points, 1 kill, killed at 10
			expect(rows[3].userId).to.equal(1) -- 100 points, 1 kill, killed at 20
			expect(rows[4].userId).to.equal(4) -- 0
		end)

		it("is a total order, so it cannot reorder between two broadcasts", function()
			local board = Score.new()
			for userId = 1, 6 do
				board = Score.join(board, userId, "p", "Drivers")
			end
			local first = Score.leaderboard(board)
			local second = Score.leaderboard(board)
			for index, row in ipairs(first) do
				expect(second[index].userId).to.equal(row.userId)
			end
		end)
	end)

	describe("performance", function()
		it("scores 10000 kills in under 100 ms", function()
			local board = Score.new()
			local record = killRecord("chest", 1, { [2] = 40 })
			local started = os.clock()
			for _ = 1, 10000 do
				board = (Score.kill(board, record, nil, CONFIG))
			end
			local elapsed = (os.clock() - started) * 1000
			print(string.format("[match_score] 10000 kills in %.0f ms", elapsed))
			expect(elapsed < 100).to.equal(true)
		end)
	end)

	describe("the numbers this spec asserts", function()
		it("are the numbers production ships", function()
			local live = Match.CONFIG.POINTS
			for zone, points in pairs(CONFIG.POINTS.KILL) do
				expect(live.KILL[zone]).to.equal(points)
			end
			expect(live.ASSIST).to.equal(CONFIG.POINTS.ASSIST)
			expect(live.ASSIST_MIN_DAMAGE).to.equal(CONFIG.POINTS.ASSIST_MIN_DAMAGE)
			expect(live.PUSH).to.equal(CONFIG.POINTS.PUSH)
			expect(live.PUSH_RADIUS).to.equal(CONFIG.POINTS.PUSH_RADIUS)
			expect(live.PUSH_WINDOW).to.equal(CONFIG.POINTS.PUSH_WINDOW)
			expect(live.ESCAPE_WOUNDED).to.equal(CONFIG.POINTS.ESCAPE_WOUNDED)
			expect(live.SAFETY_PENALTY).to.equal(CONFIG.POINTS.SAFETY_PENALTY)
		end)
	end)
end
