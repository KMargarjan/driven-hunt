-- match_score.spec: points, with no players and no world. Match.Score is pure, keyed by userId, and
-- every board it returns is frozen -- so the table Karen will retune after the first two-player
-- drive is checked here exactly, in microseconds.
--
-- The points are written out rather than imported, so a config that drifts is a finding and not a
-- tautology; the last describe closes the loop the other way.
--
-- SINCE TASK 170 A PIGLET IS A PENALTY: `KIND.cub` is -10, one whole male, and the start card says
-- so. The number and the sentence are one decision and the last describe asserts them together.
--
-- SINCE TASK 160 A KILL IS PRICED BY THE ANIMAL AND NOT BY THE HIT ZONE. Karen, 2026-10-10: *"How
-- many shoot and male is more worth then famale"*. The zone is still on the record and this spec
-- hands one in on purpose, so "the zone changes nothing about the price" is an assertion rather
-- than an absence.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/drive.md (sections 7.1, 7.3, 12.3 -- 7.1's table is stale since task 160)
-- Note:   docs/research/2026-10-12-scoring.md
local ServerScriptService = game:GetService("ServerScriptService")

local Match = require(ServerScriptService:WaitForChild("Match"))
local Score = Match.Score

local CONFIG = {
	POINTS = {
		-- `cub = -10` SINCE TASK 170: Karen, 2026-10-12, shooting a piglet is a penalty.
		-- THE THREE RED DEER (task 223): a stag is two males, a hind is exactly the sow's price,
		-- and a calf is the piglet's penalty to the point. This table is production's mirror and
		-- the case below fails in BOTH directions, so a kind priced without being asserted here
		-- is a number Karen never saw.
		KIND = { male = 10, female = 6, cub = -10, legendary = 25, stag = 20, hind = 6, calf = -10, unknown = 6 },
		ASSIST = 3,
		ASSIST_MIN_DAMAGE = 25,
		BEATER_PUSH = 3,
		PUSH_RADIUS = 60,
		PUSH_WINDOW = 20,
		ESCAPE_WOUNDED = 0,
		SAFETY_PENALTY = -10,
	},
	-- TASK 250's MONEY FINES, production's mirror. A different currency from `POINTS` and a sibling
	-- of it, which is the whole shape of the decision: both are charged by the same two events.
	FINE = {
		KIND = {
			cub = { money = 500, word = "PIGLET" },
			calf = { money = 500, word = "CALF" },
		},
		SAFETY = { money = 1000, word = "PERSON IN LINE" },
		TOTAL_WORD = "FINES",
	},
}

-- `kind` is what scores; `zone` is carried because the real record carries it, and every call below
-- leaves it at a killing chest shot so that a case which changes the KIND cannot be confused with
-- one that changed the zone.
local function killRecord(kind: string?, killer: number?, contributors, at: number?, zone: string?)
	return {
		id = "Boar1",
		at = at or 1,
		kind = kind,
		killingZone = zone or "chest",
		killedByUserId = killer,
		killedByName = if killer then "p" .. tostring(killer) else nil,
		contributors = contributors or {},
	}
end

local function pointsOf(board, userId: number): number
	local row = board.rows[userId]
	return if row then row.points else 0
end

local function finesOf(board, userId: number): number
	local row = board.rows[userId]
	return if row then row.fines else 0
end

return function()
	describe("the kill", function()
		it("pays what the ANIMAL is worth, exactly", function()
			for kind, points in pairs({ male = 10, female = 6, cub = -10, legendary = 25 }) do
				local board = (Score.kill(Score.new(), killRecord(kind, 1), nil, CONFIG))
				expect(pointsOf(board, 1)).to.equal(points)
				expect(board.rows[1].kills).to.equal(1)
			end
		end)

		it("pays a male more than a female and a female more than a cub (Karen's rule)", function()
			local kind = CONFIG.POINTS.KIND
			expect(kind.male > kind.female).to.equal(true)
			expect(kind.female > kind.cub).to.equal(true)
			expect(kind.legendary > kind.male).to.equal(true) -- "more legendary more"
		end)

		-- A PIGLET IS A PENALTY (task 170). Karen, 2026-10-12. Task 160 shipped `cub = 2` with a
		-- promise beside it -- *"The day Karen protects cubs this row goes to 0 or negative"* -- and
		-- this is that day. The OLD rule is asserted as retired, not merely changed: `cub > 0` was the
		-- assertion that used to stand here.
		it("COSTS the shooter for a piglet, and costs him a whole male", function()
			local board = (Score.kill(Score.new(), killRecord("cub", 1), nil, CONFIG))
			expect(pointsOf(board, 1)).to.equal(-10)
			-- It is still a KILL on his row: he shot an animal, the number is just against him.
			expect(board.rows[1].kills).to.equal(1)
			local kind = CONFIG.POINTS.KIND
			expect(kind.cub < 0).to.equal(true)
			-- ONE WHOLE MALE, which is the figure the other thing you must not shoot already costs.
			expect(kind.cub).to.equal(-kind.male)
			expect(kind.cub).to.equal(CONFIG.POINTS.SAFETY_PENALTY)
		end)

		-- A BAD DRIVE CAN END BELOW ZERO, and that is the drive's line and not a balance. Two piglets
		-- and a safety violation is -30, which `Economy.Coins` turns into -50 coins and
		-- `Economy.Coins.credit` then floors at the BALANCE. Here, the board simply says -30.
		it("lets a drive go negative on piglets and a violation", function()
			local board = Score.join(Score.new(), 1, "one", "Shooters")
			board = (Score.kill(board, killRecord("cub", 1, nil, 10), nil, CONFIG))
			board = (Score.kill(board, killRecord("cub", 1, nil, 20), nil, CONFIG))
			board = (Score.violation(board, 1, CONFIG))
			expect(pointsOf(board, 1)).to.equal(-30)
		end)

		it("pays an unknown kind as a female -- never free", function()
			local board = (Score.kill(Score.new(), killRecord("yearling", 1), nil, CONFIG))
			expect(pointsOf(board, 1)).to.equal(6)
			local noKind = (Score.kill(Score.new(), killRecord(nil, 1), nil, CONFIG))
			expect(pointsOf(noKind, 1)).to.equal(6)
		end)

		-- THE RETIRED RULE, ASSERTED AS RETIRED (task 160,
		-- backups/2026-10-12_task-160_points-by-hit-zone.txt). A head shot and a leg shot on the same
		-- animal were 100 and 30; they are now the same number, and the award's reason names the
		-- animal rather than the zone. Without this case, putting the zone table back would pass.
		it("pays the same for a head shot and a leg shot on the same animal", function()
			local head = (Score.kill(Score.new(), killRecord("male", 1, nil, nil, "head"), nil, CONFIG))
			local legs = (Score.kill(Score.new(), killRecord("male", 1, nil, nil, "legs"), nil, CONFIG))
			expect(pointsOf(head, 1)).to.equal(pointsOf(legs, 1))
			expect(pointsOf(head, 1)).to.equal(10)

			local _, awards = Score.kill(Score.new(), killRecord("female", 1, nil, nil, "head"), nil, CONFIG)
			expect(awards[1].reason).to.equal("kill-female")
			local _, unknown = Score.kill(Score.new(), killRecord(nil, 1, nil, nil, "head"), nil, CONFIG)
			expect(unknown[1].reason).to.equal("kill-unknown")
		end)

		it("pays an assist at the threshold and nothing one point below it", function()
			local atThreshold = (Score.kill(Score.new(), killRecord("male", 1, { [2] = 25 }), nil, CONFIG))
			expect(pointsOf(atThreshold, 2)).to.equal(3)
			expect(atThreshold.rows[2].assists).to.equal(1)

			local below = (Score.kill(Score.new(), killRecord("male", 1, { [2] = 24 }), nil, CONFIG))
			expect(below.rows[2]).to.equal(nil) -- one pellet is not an assist
		end)

		it("never pays the killer an assist for their own shot", function()
			local board = (Score.kill(Score.new(), killRecord("male", 1, { [1] = 100, [2] = 40 }), nil, CONFIG))
			expect(pointsOf(board, 1)).to.equal(10) -- the kill only
			expect(board.rows[1].assists).to.equal(0)
			expect(pointsOf(board, 2)).to.equal(3)
		end)

		it("records the first kill's time, and never overwrites it", function()
			local board = (Score.kill(Score.new(), killRecord("male", 1, nil, 11), nil, CONFIG))
			board = (Score.kill(board, killRecord("male", 1, nil, 22), nil, CONFIG))
			expect(board.rows[1].firstKillAt).to.equal(11)
			expect(board.rows[1].kills).to.equal(2)
		end)

		it("never mutates the board it was given, and freezes the one it returns", function()
			local before = (Score.kill(Score.new(), killRecord("female", 1), nil, CONFIG))
			local points = pointsOf(before, 1)
			local after = (Score.kill(before, killRecord("female", 1), nil, CONFIG))
			expect(pointsOf(before, 1)).to.equal(points)
			expect(pointsOf(after, 1)).to.equal(points * 2)
			expect(function()
				after.rows[1].points = 0
			end).to.throw()
		end)
	end)

	-- KAREN, 2026-10-10: *"beater ranking also is cool"*. The credit itself is the owner's
	-- measurement (`Match.samplePush` for proximity, `Match.creditPush` for the horn); this is the
	-- rule that turns it into points, and the rule is ioquake3's: the credit that pays is the one
	-- that caused the score *"almost immediately"* (code/game/g_team.h, GPL-2.0).
	describe("the beater's push", function()
		it("pays the beater whose credit is the LAST one before the kill", function()
			-- 3 pushed it eleven seconds ago; 5 pushed it two seconds ago. 5 is why it ran onto the gun.
			local board = (Score.kill(Score.new(), killRecord("male", 1), { [3] = 9, [5] = 18 }, CONFIG))
			expect(pointsOf(board, 5)).to.equal(3)
			expect(board.rows[5].pushes).to.equal(1)
			expect(board.rows[3]).to.equal(nil) -- he left it to somebody else
		end)

		it("pays everybody tied on the latest credit, because 2 Hz sampling ties them", function()
			local board = (Score.kill(Score.new(), killRecord("male", 1), { [3] = 18, [5] = 18 }, CONFIG))
			expect(pointsOf(board, 3)).to.equal(3)
			expect(pointsOf(board, 5)).to.equal(3)
		end)

		it("never pays the shooter who killed it a push as well", function()
			local board = (Score.kill(Score.new(), killRecord("male", 1), { [1] = 18, [3] = 18 }, CONFIG))
			expect(pointsOf(board, 1)).to.equal(10) -- the killer keeps the kill, not a push
			expect(board.rows[1].pushes).to.equal(0)
			expect(pointsOf(board, 3)).to.equal(3)
		end)

		-- PHANTOM BEATERS EARN NOTHING, and this is the half of that rule that lives here: an empty
		-- or absent credit table pays nobody. The other half is structural and is in `Match` -- a
		-- phantom has no userId, so `Match.playerDrivers` and `Match.pushCreditable` never write one
		-- into the table at all (match_live.spec asserts that side, beside task 83's own case).
		it("pays nobody at all when nothing pushed it", function()
			local none = (Score.kill(Score.new(), killRecord("male", 1), nil, CONFIG))
			expect(none.rows[2]).to.equal(nil)
			local empty = (Score.kill(Score.new(), killRecord("male", 1), {}, CONFIG))
			expect(empty.rows[2]).to.equal(nil)
		end)

		-- ASSIST AND BEATER_PUSH ARE BOTH 3 IN PRODUCTION (round 1, note 3), so every case above
		-- would pass with the two config keys swapped inside `Score.kill`. This is the one case
		-- that tells them apart: a config where they differ, one record that earns both, and each
		-- award read off its own key.
		it("reads BEATER_PUSH and not ASSIST, which production happens to set to the same number", function()
			local distinct = { POINTS = table.clone(CONFIG.POINTS) }
			distinct.POINTS.ASSIST = 5
			distinct.POINTS.BEATER_PUSH = 9
			local board = (Score.kill(Score.new(), killRecord("male", 1, { [2] = 40 }), { [3] = 18 }, distinct))
			expect(pointsOf(board, 2)).to.equal(5) -- the assist
			expect(board.rows[2].assists).to.equal(1)
			expect(pointsOf(board, 3)).to.equal(9) -- the push
			expect(board.rows[3].pushes).to.equal(1)
		end)

		it("is worth less than the animal, and switches off at 0", function()
			expect(CONFIG.POINTS.BEATER_PUSH < CONFIG.POINTS.KIND.male).to.equal(true)
			local off = { POINTS = table.clone(CONFIG.POINTS) }
			off.POINTS.BEATER_PUSH = 0
			local board = (Score.kill(Score.new(), killRecord("male", 1), { [3] = 18 }, off))
			-- The ROW still records the push -- "how many did I walk onto the guns" is a real number
			-- -- and the points are zero, which is what switching the idea off means.
			expect(pointsOf(board, 3)).to.equal(0)
			expect(board.rows[3].pushes).to.equal(1)
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
			expect(pointsOf(board, 1)).to.equal(-10)
			expect(board.rows[1].violations).to.equal(1)
		end)

		-- THE PENALTY IS SURVIVABLE, which is the whole reason it was rescaled with the kill table
		-- (note section 4): at the old -50 against a 10-point male, one violation would cost five
		-- animals and end a player's board for good.
		it("costs one animal and not a whole drive", function()
			local penalty = -CONFIG.POINTS.SAFETY_PENALTY
			expect(penalty).to.equal(CONFIG.POINTS.KIND.male)
			expect(penalty < 6 * CONFIG.POINTS.KIND.male).to.equal(true) -- BOARS_PER_DRIVE
		end)
	end)

	describe("the board", function()
		it("keeps a leaver's row for this drive's screen, marked left", function()
			local board = Score.join(Score.new(), 1, "Karen", "Shooters")
			board = (Score.kill(board, killRecord("male", 1), nil, CONFIG))
			board = Score.leave(board, 1)
			expect(board.rows[1].left).to.equal(true)
			expect(pointsOf(board, 1)).to.equal(10)
		end)

		it("sorts by points, then kills, then the earliest first kill, then userId", function()
			local board = Score.new()
			board = Score.join(board, 1, "one", "Shooters")
			board = Score.join(board, 2, "two", "Shooters")
			board = Score.join(board, 3, "three", "Drivers")
			board = Score.join(board, 4, "four", "Drivers")
			-- All three of 1, 2 and 3 reach 12. 3 got there on two females, a male and a piglet
			-- (6 + 6 + 10 - 10 = 12) -- FOUR kills, which beats the other two on the kill count; 1 and 2
			-- each shot two females, and 2 shot first. (Before task 170 this case was six cubs at +2
			-- each; a cub now COSTS 10, so the same claim needs different animals.)
			board = (Score.kill(board, killRecord("female", 1, nil, 20), nil, CONFIG))
			board = (Score.kill(board, killRecord("female", 1, nil, 21), nil, CONFIG))
			board = (Score.kill(board, killRecord("female", 2, nil, 10), nil, CONFIG))
			board = (Score.kill(board, killRecord("female", 2, nil, 11), nil, CONFIG))
			board = (Score.kill(board, killRecord("female", 3, nil, 31), nil, CONFIG))
			board = (Score.kill(board, killRecord("female", 3, nil, 32), nil, CONFIG))
			board = (Score.kill(board, killRecord("male", 3, nil, 33), nil, CONFIG))
			board = (Score.kill(board, killRecord("cub", 3, nil, 34), nil, CONFIG))

			local rows = Score.leaderboard(board)
			expect(rows[1].points).to.equal(12)
			expect(rows[1].userId).to.equal(3) -- 12 points, 4 kills
			expect(rows[2].userId).to.equal(2) -- 12 points, 2 kills, killed at 10
			expect(rows[3].userId).to.equal(1) -- 12 points, 2 kills, killed at 20
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
			local record = killRecord("male", 1, { [2] = 40 })
			local started = os.clock()
			for _ = 1, 10000 do
				board = (Score.kill(board, record, nil, CONFIG))
			end
			local elapsed = (os.clock() - started) * 1000
			print(string.format("[match_score] 10000 kills in %.0f ms", elapsed))
			expect(elapsed < 100).to.equal(true)
		end)
	end)

	describe("the money fines (task 250)", function()
		-- KAREN, 2026-10-23: *"also we need to make more damadge to shooter if shoot baby like take
		-- big amount of money and same to person"*. The points penalty and the rope round the tree
		-- are UNTOUCHED and the money is ON TOP, which is what the Director's dispatch says: *"Both
		-- come on top of any existing score penalty."*
		it("charges the piglet and the calf, and nothing else", function()
			local money, word = Score.fineForKind("cub", CONFIG)
			expect(money).to.equal(500)
			expect(word).to.equal("PIGLET")
			money, word = Score.fineForKind("calf", CONFIG)
			expect(money).to.equal(500)
			expect(word).to.equal("CALF")
			for _, kind in ipairs({ "male", "female", "legendary", "stag", "hind", "unknown" }) do
				expect(Score.fineForKind(kind, CONFIG)).to.equal(nil)
			end
			-- and the degenerate inputs a wire can produce
			expect(Score.fineForKind(nil, CONFIG)).to.equal(nil)
			expect(Score.fineForKind("", CONFIG)).to.equal(nil)
			expect(Score.fineForKind("cub", { POINTS = CONFIG.POINTS })).to.equal(nil)
			expect(Score.fineForKind("cub", { POINTS = CONFIG.POINTS, FINE = {} })).to.equal(nil)
			expect(Score.fineForKind("cub", { FINE = { KIND = { cub = { money = 0 } } } })).to.equal(nil)
		end)

		it("charges a person in the line twice what a piglet costs", function()
			local money, word = Score.fineForSafety(CONFIG)
			expect(money).to.equal(1000)
			expect(word).to.equal("PERSON IN LINE")
			expect(money).to.equal(2 * (Score.fineForKind("cub", CONFIG) :: number))
			expect(Score.fineForSafety({ POINTS = CONFIG.POINTS })).to.equal(nil)
			expect(Score.fineForSafety({ FINE = { SAFETY = { money = -1 } } })).to.equal(nil)
		end)

		it("puts the piglet's fine on the killer's row, ON TOP of the points penalty", function()
			local board, awards = Score.kill(Score.new(), killRecord("cub", 1), nil, CONFIG)
			expect(pointsOf(board, 1)).to.equal(-10)
			expect(finesOf(board, 1)).to.equal(500)
			expect(#awards).to.equal(1)
			-- THE AWARD CARRIES THE DELTA, SIGNED: `Money.signed` draws it and no screen invents it.
			expect(awards[1].money).to.equal(-500)
			expect(awards[1].points).to.equal(-10)
		end)

		it("charges a calf the same, and a male nothing at all", function()
			local calf = Score.kill(Score.new(), killRecord("calf", 1), nil, CONFIG)
			expect(finesOf(calf, 1)).to.equal(500)
			local male, awards = Score.kill(Score.new(), killRecord("male", 1), nil, CONFIG)
			expect(finesOf(male, 1)).to.equal(0)
			expect(awards[1].money).to.equal(nil)
		end)

		it("fines the SHOOTER and not the men who helped", function()
			-- *"more damadge to shooter"*. An assist on a piglet and a push that walked it up are
			-- not the shot she is punishing, and both still collect their points.
			local board = Score.kill(Score.new(), killRecord("cub", 1, { [2] = 40 }), { [3] = 1 }, CONFIG)
			expect(finesOf(board, 1)).to.equal(500)
			expect(finesOf(board, 2)).to.equal(0)
			expect(finesOf(board, 3)).to.equal(0)
			expect(pointsOf(board, 2)).to.equal(CONFIG.POINTS.ASSIST)
			expect(pointsOf(board, 3)).to.equal(CONFIG.POINTS.BEATER_PUSH)
		end)

		it("accumulates across a drive", function()
			local board = Score.kill(Score.new(), killRecord("cub", 1), nil, CONFIG)
			board = Score.kill(board, killRecord("calf", 1, nil, 2), nil, CONFIG)
			board = Score.violation(board, 1, CONFIG)
			expect(finesOf(board, 1)).to.equal(2000)
			expect(pointsOf(board, 1)).to.equal(-30)
		end)

		it("charges the safety fine beside the points penalty, as one award", function()
			local board, awards = Score.violation(Score.new(), 7, CONFIG)
			expect(pointsOf(board, 7)).to.equal(-10)
			expect(finesOf(board, 7)).to.equal(1000)
			expect(#awards).to.equal(1)
			expect(awards[1].points).to.equal(-10)
			expect(awards[1].money).to.equal(-1000)
			expect(awards[1].reason).to.equal("safety")
		end)

		it("leaves a build with no FINE table bit for bit what it was", function()
			local noFine = { POINTS = CONFIG.POINTS }
			local board, awards = Score.kill(Score.new(), killRecord("cub", 1), nil, noFine)
			expect(pointsOf(board, 1)).to.equal(-10)
			expect(finesOf(board, 1)).to.equal(0)
			expect(awards[1].money).to.equal(nil)
			local tied, tiedAwards = Score.violation(Score.new(), 1, noFine)
			expect(pointsOf(tied, 1)).to.equal(-10)
			expect(finesOf(tied, 1)).to.equal(0)
			expect(tiedAwards[1].money).to.equal(nil)
		end)

		it("starts every row at nought and keeps the board frozen", function()
			local board = Score.join(Score.new(), 1, "p1", "Shooters")
			expect(finesOf(board, 1)).to.equal(0)
			expect(table.isfrozen(board.rows[1])).to.equal(true)
			-- a row that is only ever read keeps its nought through a leave and a team change
			board = Score.setTeam(board, 1, "Drivers")
			board = Score.leave(board, 1)
			expect(finesOf(board, 1)).to.equal(0)
		end)

		it("is the table production ships, and production ships no row this spec does not know", function()
			local live = Match.CONFIG.FINE
			expect(live).to.be.ok()
			expect(live.SAFETY.money).to.equal(CONFIG.FINE.SAFETY.money)
			expect(live.SAFETY.word).to.equal(CONFIG.FINE.SAFETY.word)
			expect(live.TOTAL_WORD).to.equal(CONFIG.FINE.TOTAL_WORD)
			for kind, row in pairs(CONFIG.FINE.KIND) do
				expect(live.KIND[kind].money).to.equal(row.money)
				expect(live.KIND[kind].word).to.equal(row.word)
			end
			for kind in pairs(live.KIND) do
				expect(CONFIG.FINE.KIND[kind] ~= nil).to.equal(true)
				-- EVERY FINED KIND IS A KIND THE POINTS ALSO PUNISH, which is what makes the two
				-- tables one decision rather than two: Karen protects the young, and a kind that
				-- cost money while paying points would be the game saying both things at once.
				expect(Match.CONFIG.POINTS.KIND[kind] < 0).to.equal(true)
			end
			-- ...AND THE WORD IS NEVER THE INTERNAL ONE (the Designer's rule 4: `cub` is never
			-- printed).
			expect(live.KIND.cub.word).never.to.equal("cub")
			expect(live.KIND.cub.word).to.equal("PIGLET")
		end)
	end)

	describe("the numbers this spec asserts", function()
		it("are the numbers production ships", function()
			local live = Match.CONFIG.POINTS
			for kind, points in pairs(CONFIG.POINTS.KIND) do
				expect(live.KIND[kind]).to.equal(points)
			end
			-- ...AND NO EXTRA ROW IN EITHER DIRECTION (task 160): a kind added to production without
			-- a price asserted here is a number Karen never saw.
			for kind in pairs(live.KIND) do
				expect(CONFIG.POINTS.KIND[kind]).to.be.ok()
			end
			expect(live.ASSIST).to.equal(CONFIG.POINTS.ASSIST)
			expect(live.ASSIST_MIN_DAMAGE).to.equal(CONFIG.POINTS.ASSIST_MIN_DAMAGE)
			expect(live.BEATER_PUSH).to.equal(CONFIG.POINTS.BEATER_PUSH)
			expect(live.PUSH_RADIUS).to.equal(CONFIG.POINTS.PUSH_RADIUS)
			expect(live.PUSH_WINDOW).to.equal(CONFIG.POINTS.PUSH_WINDOW)
			expect(live.ESCAPE_WOUNDED).to.equal(CONFIG.POINTS.ESCAPE_WOUNDED)
			expect(live.SAFETY_PENALTY).to.equal(CONFIG.POINTS.SAFETY_PENALTY)
			-- THE RETIRED TABLE IS GONE, not merely unread: a `KILL` row left beside `KIND` would be
			-- two prices for one kill waiting for somebody to pick the wrong one.
			expect(live.KILL).to.equal(nil)
			expect(live.PUSH).to.equal(nil)
		end)

		-- THE NUMBER AND THE SENTENCE ARE ONE DECISION (task 170), so one assertion holds them
		-- together: `Match.CONFIG`'s own comment promised that the day a cub went negative,
		-- `QUARRY_NOTE` would change in the same commit. This is what makes that promise keepable --
		-- a rollback of either one alone fails here.
		it("states the piglet rule on the start card, in the same commit as the price", function()
			expect(Match.CONFIG.POINTS.KIND.cub).to.equal(-10)
			-- THE NOTE IS GONE AND THE ROW TOOK ITS PLACE (201 part 3). `QUARRY_NOTE` was the
			-- sentence *"a piglet COSTS you - leave them"* under a line of three prices; the card now
			-- draws the piglet as its own row -- a cross, Karen's own *"leave them"*, and the price
			-- with its sign. The rule is still ONLY here, and the row carries it.
			expect(Match.CONFIG.QUARRY_NOTE).to.equal(nil)
			local rows = Match.quarryRows(Match.CONFIG)
			local cub = nil
			for _, row in ipairs(rows) do
				if row.kind == "cub" then
					cub = row
				end
			end
			expect(cub).to.be.ok()
			expect(cub.points).to.equal(-10)
			expect(cub.points < 0).to.equal(true)
		end)
	end)
end
