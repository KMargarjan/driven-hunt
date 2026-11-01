-- match_stand_pick.spec: THE HUNTER TAKES HIS OWN STAND (task 323a).
--
-- Karen, 2026-10-31: *"...choose shooting place on map before hunt"*.
--
-- EVERY CASE HERE IS ARITHMETIC. `StandPick.judge` is pure -- no service, no `Player`, no clock --
-- and `StandPick.claim` yields nowhere, so "first request wins" is asserted by calling it twice with
-- the same `now` rather than by racing two frames. `HighSeats.dealLine` is pure too, which is what
-- lets the flag-off claim be a MEASUREMENT (128 equal-by-value assertions) instead of a belief.
--
-- IT DOES NOT START A MATCH, for `match_live.spec`'s own stated reason: `ServerScriptService.Match`
-- is a singleton `MatchBoot` has already started. Two facts therefore come off PRODUCTION rather
-- than off a staged drive, and both are the flag-off path: `Match.CONFIG.STAND_PICK_SECONDS` and
-- `Match.stats().standsSettled`.
--
-- THE NAME IS `match_stand_pick` AND NOT `stand_pick` ON PURPOSE: `tests/server/match_*.spec.luau`
-- is already in `TWO_PLAYER_PATHS`, so this file needs no new entry (design section 10.2).
--
-- WHAT NO CASE HERE CAN PROVE, stated rather than assumed:
--   * `placementLine` and `applyStandSettle` are LOCALS of `src/server/Match/init.luau`. The seam is
--     asserted as the COMPOSITION they build -- `dealLine(walk, seated, entitled, count,
--     StandPick.picksFor(ids))`, which is that expression -- plus production's own
--     `stats().standsSettled`.
--   * two hunters racing for one stand across two clients is `test2`'s, not a spec's.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/stand-pick.md (sections 5, 6, 7, 12, 13.1)
-- Note:   docs/research/2026-11-01-stand-pick.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Forest = require(ReplicatedStorage:WaitForChild("ForestTest"))
local HighSeats = require(ReplicatedStorage:WaitForChild("HighSeats"))
local Match = require(ServerScriptService:WaitForChild("Match"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Body = Match.Body
local Phase = Match.Phase
local StandPick = Match.StandPick
local REASON = StandPick.REASON

-- THE CONFIG EVERY PURE CASE RUNS ON, as a parameter and never off the flag: 15 is "the window is
-- open", 0 is "the flag is off", and both states are reachable from a pure spec while the flag sits
-- at one of them (CLAUDE.md, feature flags).
local ON = {
	INTERMISSION_SECONDS = 5,
	STAND_PICK_SECONDS = 15,
	STAND_PICK_MIN_INTERVAL = 0.25,
	STAND_PICK_MAX_REQUESTS = 20,
}
local OFF = {
	INTERMISSION_SECONDS = 5,
	STAND_PICK_SECONDS = 0,
	STAND_PICK_MIN_INTERVAL = 0.25,
	STAND_PICK_MAX_REQUESTS = 20,
}

local function ask(over: { [string]: any }?): any
	local base = {
		userId = 1001,
		stand = 4,
		now = 100,
		open = true,
		standCount = 9,
		isHunter = true,
		seated = false,
		entitled = nil,
		heldBy = nil,
		mine = nil,
		lastAt = nil,
		asks = 1,
		config = ON,
	}
	for key, value in pairs(over or {}) do
		base[key] = value
	end
	return base
end

local function walkOf(layoutName: string): { number }
	local layout = (Forest.LAYOUTS :: any)[layoutName]
	local walk = {}
	for index = 1, layout.standCount do
		table.insert(walk, index)
	end
	return walk
end

local function seatedOf(layoutName: string): { [number]: boolean }
	local out: { [number]: boolean } = {}
	for _, stand in ipairs(HighSeats.standsFor(layoutName)) do
		out[stand] = true
	end
	return out
end

return function()
	afterEach(function()
		StandPick.clear()
	end)

	-- ------------------------------------------------------------------ case 1, case 2: the rule
	describe("StandPick.judge: pure, one reason each", function()
		it("case 2: accepts a free in-range stand for a hunter in an open window", function()
			local ok, reason = StandPick.judge(ask())
			expect(ok).to.equal(true)
			expect(reason).to.equal(nil)
		end)

		it("case 1: refuses each of the eight reasons, one case each", function()
			local cases = {
				{ over = { open = false }, want = REASON.CLOSED },
				{ over = { isHunter = false }, want = REASON.ROLE },
				{ over = { stand = 10 }, want = REASON.RANGE },
				{ over = { lastAt = 99.9 }, want = REASON.RATE },
				{ over = { asks = 21 }, want = REASON.FLOOD },
				{ over = { mine = 4 }, want = REASON.SAME },
				{ over = { seated = true, entitled = false }, want = REASON.SEAT },
				{ over = { heldBy = 2002 }, want = REASON.TAKEN },
			}
			for _, row in ipairs(cases) do
				local ok, reason = StandPick.judge(ask(row.over))
				expect(ok).to.equal(false)
				expect(reason).to.equal(row.want)
			end
			expect(#cases).to.equal(#StandPick.ORDER)
		end)

		it("case 1: answers in ORDER when two reasons apply at once", function()
			-- A BEATER ASKING AFTER THE HORN IS TOLD `closed`, NOT `role`, and a beater asking for a
			-- stand somebody holds is told `role`, not `taken`: the outermost fact about the asker
			-- first, which is `Weapon.Rules.ORDER`'s own rule.
			local _, shut = StandPick.judge(ask({ open = false, isHunter = false, heldBy = 2002 }))
			expect(shut).to.equal(REASON.CLOSED)
			local _, role = StandPick.judge(ask({ isHunter = false, heldBy = 2002, stand = 99 }))
			expect(role).to.equal(REASON.ROLE)
			local _, range = StandPick.judge(ask({ stand = 99, heldBy = 2002 }))
			expect(range).to.equal(REASON.RANGE)
			local _, rate = StandPick.judge(ask({ lastAt = 99.9, heldBy = 2002 }))
			expect(rate).to.equal(REASON.RATE)
			local _, seat = StandPick.judge(ask({ seated = true, entitled = false, heldBy = 2002 }))
			expect(seat).to.equal(REASON.SEAT)
		end)

		it("case 1: an entitled hunter may take a seated stand, and nil is entitled", function()
			expect((StandPick.judge(ask({ seated = true, entitled = true })))).to.equal(true)
			expect((StandPick.judge(ask({ seated = true, entitled = nil })))).to.equal(true)
		end)

		it('case 12: refuses 2.5, "4", 0, standCount+1, math.huge and 0/0 as range', function()
			local bad = { 2.5, "4", 0, 10, math.huge, -math.huge, 0 / 0, true, {} }
			for _, value in ipairs(bad) do
				local ok, reason = StandPick.judge(ask({ stand = value }))
				expect(ok).to.equal(false)
				expect(reason).to.equal(REASON.RANGE)
			end
			-- ...and a table/boolean never reaches `judge` in production at all: the owner drops it
			-- and counts it (`stats.malformed`).
			StandPick.noteMalformed()
			expect(StandPick.stats().malformed).to.equal(1)
		end)

		it("case 13: the rate limiter and the flood ceiling, by value", function()
			-- 0.25 is `STATE_MIN_INTERVAL` exactly, so an accepted change forces at most one
			-- broadcast per throttle slot.
			expect((StandPick.judge(ask({ now = 100, lastAt = 99.76 })))).to.equal(false)
			expect((StandPick.judge(ask({ now = 100, lastAt = 99.75 })))).to.equal(true)
			expect((StandPick.judge(ask({ asks = 20 })))).to.equal(true)
			expect((StandPick.judge(ask({ asks = 21 })))).to.equal(false)
		end)

		it("case 1: every word a refusal draws is inside Objective's 33-character bound", function()
			for reason, word in pairs(StandPick.WORDS) do
				expect(#word <= 33).to.equal(true)
				expect(StandPick.REASON[string.upper(reason)]).to.equal(reason)
			end
			-- `rate`, `flood` and `same` draw NOTHING: he did nothing wrong, and drawing "too fast"
			-- teaches a forger the limit.
			expect(StandPick.WORDS.rate).to.equal(nil)
			expect(StandPick.WORDS.flood).to.equal(nil)
			expect(StandPick.WORDS.same).to.equal(nil)
		end)
	end)

	-- ------------------------------------------------------------ case 3, case 4: the window IS the phase
	describe("Phase.pickWindow and Phase.intermissionSeconds", function()
		it("case 3: true only in Assigning, only with seconds > 0, only with stands", function()
			local phases = { "Waiting", "Assigning", "Running", "Scoring" }
			local answers = {}
			for _, phase in ipairs(phases) do
				for _, cfg in ipairs({ ON, OFF }) do
					for _, count in ipairs({ 9, 0 }) do
						local got = Phase.pickWindow({ phase = phase }, cfg, count)
						table.insert(
							answers,
							string.format("%s/%d/%d=%s", phase, cfg.STAND_PICK_SECONDS, count, tostring(got))
						)
						expect(got).to.equal(phase == "Assigning" and cfg.STAND_PICK_SECONDS > 0 and count > 0)
					end
				end
			end
			expect(#answers).to.equal(16)
			expect(Phase.pickWindow(nil, ON, 9)).to.equal(false)
			TestKit.note("match_stand_pick: Phase.pickWindow -- 16 combinations, true in exactly one")
		end)

		it("case 4: (5,0)->5, (5,15)->15, QUICK_TEST+15->3", function()
			expect(Phase.intermissionSeconds(OFF)).to.equal(5)
			expect(Phase.intermissionSeconds(ON)).to.equal(15)
			expect(Phase.intermissionSeconds({
				QUICK_TEST = true,
				QUICK_TEST_INTERMISSION_SECONDS = 3,
				INTERMISSION_SECONDS = 5,
				STAND_PICK_SECONDS = 15,
			})).to.equal(3)
			-- A config that never heard of the field is today's answer, by identity.
			expect(Phase.intermissionSeconds({ INTERMISSION_SECONDS = 5 })).to.equal(5)
		end)
	end)

	-- ------------------------------------------------------- case 5, case 6, case 11: the deal
	describe("HighSeats.dealLine: sweep A is strictly stronger than the fallback", function()
		it("case 5: nil, {} and today's call are EQUAL element by element -- 128 assertions", function()
			local asserted = 0
			for _, layoutName in ipairs(Forest.LAYOUT_ORDER) do
				local walk = walkOf(layoutName)
				local seated = seatedOf(layoutName)
				for count = 1, 16 do
					local entitled: { boolean? } = {}
					for index = 1, count do
						entitled[index] = index % 3 ~= 0 -- a mixed line, so the seat passes bite
					end
					local today = HighSeats.dealLine(walk, seated, entitled, count)
					local withNil = HighSeats.dealLine(walk, seated, entitled, count, nil)
					local withEmpty = HighSeats.dealLine(walk, seated, entitled, count, {})
					expect(#withNil).to.equal(#today)
					expect(#withEmpty).to.equal(#today)
					for index = 1, #today do
						expect(withNil[index]).to.equal(today[index])
						expect(withEmpty[index]).to.equal(today[index])
					end
					asserted += 2
				end
			end
			expect(asserted).to.equal(128)
			TestKit.note(
				string.format(
					"match_stand_pick: flag off is bit for bit -- %d equal-by-value deals over %d layouts x 16 counts",
					asserted,
					#Forest.LAYOUT_ORDER
				)
			)
		end)

		it("case 6: hunter 3 claims walk[1], hunter 1 claims nothing -- 3 gets it", function()
			-- THE CASE ONE PASS GETS WRONG. With a single pass hunter 1 takes `walk[1]` on his turn
			-- and hunter 3's claim is then refused by the fallback -- a claim losing to a man who
			-- claimed nothing, which is the inverse of D4.
			local walk = walkOf("road")
			local seated = seatedOf("road")
			local deal = HighSeats.dealLine(walk, seated, nil, 3, { nil, nil, walk[1] })
			expect(deal[3]).to.equal(walk[1])
			expect(deal[1]).never.to.equal(walk[1])
			expect(deal[2]).never.to.equal(walk[1])
			-- ...and nobody shares a stand.
			expect(deal[1]).never.to.equal(deal[2])
			expect(deal[2]).never.to.equal(deal[3])
		end)

		it("case 6: every hunter gets exactly the stand he claimed when all of them claim", function()
			local walk = walkOf("road")
			local seated = seatedOf("road")
			local picks = { 9, 7, 5, 3, 1 }
			local deal = HighSeats.dealLine(walk, seated, nil, 5, picks)
			for index, wanted in ipairs(picks) do
				expect(deal[index]).to.equal(wanted)
			end
		end)

		it("case 11: sweep A refuses an unentitled hunter's claim of a seated stand", function()
			-- THE SECOND CHECK, the belt a forged `FireServer` meets. He is dealt a stand he may
			-- stand on instead -- never nothing, and never the seat.
			local layoutName = "edge"
			local seats = HighSeats.standsFor(layoutName)
			expect(#seats > 0).to.equal(true)
			local seat = seats[1]
			local walk = walkOf(layoutName)
			local seated = seatedOf(layoutName)
			local deal = HighSeats.dealLine(walk, seated, { false }, 1, { seat })
			expect(deal[1]).never.to.equal(seat)
			expect(deal[1] ~= nil).to.equal(true)
			-- ...and an ENTITLED hunter's claim of the same seat is honoured.
			local allowed = HighSeats.dealLine(walk, seated, { true }, 1, { seat })
			expect(allowed[1]).to.equal(seat)
		end)

		it("case 11: a claim of a stand this layout does not state is ignored, not clamped", function()
			local walk = walkOf("ride") -- 5 stands
			local seated = seatedOf("ride")
			local deal = HighSeats.dealLine(walk, seated, nil, 1, { 7 })
			expect(deal[1]).to.equal(HighSeats.dealLine(walk, seated, nil, 1)[1])
		end)
	end)

	-- ---------------------------------------------- case 7, 8, 9, 10, 15: the claim table
	describe("StandPick: the claim", function()
		it("case 7: two claims, same stand, same now -- the first wins", function()
			StandPick.reset(1)
			local first, firstReason = StandPick.claim(1001, 5, 100)
			local second, secondReason = StandPick.claim(1002, 5, 100)
			expect(first).to.equal(true)
			expect(firstReason).to.equal(nil)
			expect(second).to.equal(false)
			expect(secondReason).to.equal(REASON.TAKEN)
			expect(StandPick.holderOf(5)).to.equal(1001)
			expect(StandPick.standOf(1002)).to.equal(nil)
		end)

		it("case 8: a change frees the old stand at once, and the leaver's too", function()
			StandPick.reset(1)
			expect((StandPick.claim(1001, 5, 100))).to.equal(true)
			expect((StandPick.claim(1001, 6, 101))).to.equal(true)
			expect(StandPick.holderOf(5)).to.equal(nil)
			expect(StandPick.standOf(1001)).to.equal(6)
			-- ...so somebody else may take 5 immediately.
			expect((StandPick.claim(1002, 5, 101))).to.equal(true)
			-- ...and a release frees 6 for him too.
			expect(StandPick.release(1001)).to.equal(6)
			expect(StandPick.holderOf(6)).to.equal(nil)
			expect((StandPick.claim(1002, 6, 102))).to.equal(true)
			expect(StandPick.holderOf(5)).to.equal(nil) -- his old one went with the change
			expect(StandPick.release(9999)).to.equal(nil) -- a man who held nothing frees nothing
		end)

		it("case 8: re-claiming the stand he already holds is accepted and changes nothing", function()
			StandPick.reset(1)
			expect((StandPick.claim(1001, 5, 100))).to.equal(true)
			expect((StandPick.claim(1001, 5, 101))).to.equal(true)
			expect(StandPick.standOf(1001)).to.equal(5)
			expect(StandPick.holderOf(5)).to.equal(1001)
		end)

		it("case 9: reset(n) drops every claim and remembers the drive", function()
			StandPick.reset(1)
			StandPick.claim(1001, 5, 100)
			StandPick.claim(1002, 7, 100)
			StandPick.reset(2)
			expect(StandPick.driveOf()).to.equal(2)
			expect(StandPick.standOf(1001)).to.equal(nil)
			expect(StandPick.standOf(1002)).to.equal(nil)
			expect(StandPick.holderOf(7)).to.equal(nil)
			expect(StandPick.anyClaim()).to.equal(false)
			expect(StandPick.asksBy(1001)).to.equal(0)
			expect(StandPick.lastChangeAt(1001)).to.equal(nil)
		end)

		it("case 10: picksFor is by LINE INDEX, nil where unclaimed, in the ids' own order", function()
			StandPick.reset(1)
			StandPick.claim(2002, 3, 100)
			local ids = { 1001, 2002, 3003 }
			local picks = StandPick.picksFor(ids)
			expect(picks[1]).to.equal(nil)
			expect(picks[2]).to.equal(3)
			expect(picks[3]).to.equal(nil)
			-- THE TWO LISTS CANNOT DRIFT: the same sorted ids build `entitled`, so index 2 is the
			-- same man in both, and the deal honours exactly his claim.
			local walk = walkOf("road")
			local deal = HighSeats.dealLine(walk, seatedOf("road"), { nil, nil, nil }, #ids, picks)
			expect(deal[2]).to.equal(3)
		end)

		it("case 15: wireTable is frozen, string-keyed, and holds exactly the live claims", function()
			StandPick.reset(1)
			expect(StandPick.anyClaim()).to.equal(false)
			StandPick.claim(1001, 5, 100)
			StandPick.claim(1002, 7, 100)
			local wire = StandPick.wireTable()
			expect(table.isfrozen(wire)).to.equal(true)
			expect(wire["5"]).to.equal(1001)
			expect(wire["7"]).to.equal(1002)
			expect(wire[5]).to.equal(nil) -- a table on the wire has STRING keys
			local rows = 0
			for _ in pairs(wire) do
				rows += 1
			end
			expect(rows).to.equal(2)
			expect(StandPick.anyClaim()).to.equal(true)
			-- ...and the stats are the owner's own numbers.
			StandPick.noteRefusal(REASON.TAKEN)
			local stats = StandPick.stats()
			expect(stats.accepted).to.equal(2)
			expect(stats.refused.taken).to.equal(1)
			expect(stats.refused.closed).to.equal(0)
		end)

		it("case 9: forget drops his claim and his ask count", function()
			StandPick.reset(1)
			StandPick.noteAsk(1001)
			StandPick.claim(1001, 5, 100)
			StandPick.forget(1001)
			expect(StandPick.standOf(1001)).to.equal(nil)
			expect(StandPick.asksBy(1001)).to.equal(0)
			expect(StandPick.holderOf(5)).to.equal(nil)
		end)

		it("case 13: noteAsk counts per player per drive, and reset clears it", function()
			StandPick.reset(1)
			expect(StandPick.noteAsk(1001)).to.equal(1)
			expect(StandPick.noteAsk(1001)).to.equal(2)
			expect(StandPick.noteAsk(1002)).to.equal(1)
			expect(StandPick.stats().asks).to.equal(3)
		end)

		it("case 3: close() shuts the window and reset() opens it", function()
			StandPick.reset(1)
			expect(StandPick.isOpen()).to.equal(true)
			StandPick.close()
			expect(StandPick.isOpen()).to.equal(false)
		end)
	end)

	-- --------------------------------------------- case 14: the bots wait for the window
	describe("Match.botsNeedRebuild: a bot never takes a stand a human could still pick", function()
		it("case 14: pickOpen defers the rebuild, and flag off is identity", function()
			-- WITH THE WINDOW OPEN: no rebuild, whatever the phase.
			expect(Match.botsNeedRebuild("Assigning", 1, nil, true)).to.equal(false)
			-- ...AND THE DEFERRED REBUILD HAPPENS ON THE `Running` ARM.
			expect(Match.botsNeedRebuild("Running", 1, nil, false)).to.equal(true)
			-- FLAG OFF, WHICH IS TODAY'S BEHAVIOUR BY IDENTITY: the first `Assigning` tick rebuilds,
			-- `lastRebuilt` moves, and the `Running` arm is then unreachable.
			expect(Match.botsNeedRebuild("Assigning", 1, nil, false)).to.equal(true)
			expect(Match.botsNeedRebuild("Assigning", 1, 1, false)).to.equal(false)
			expect(Match.botsNeedRebuild("Running", 1, 1, false)).to.equal(false)
			expect(Match.botsNeedRebuild("Scoring", 1, nil, false)).to.equal(false)
			expect(Match.botsNeedRebuild("Waiting", 1, nil, false)).to.equal(false)
			-- A CALLER THAT NEVER HEARD OF THE ARGUMENT IS TODAY'S ANSWER, EVERY ANSWER. nil is "this
			-- caller did not measure the pick", which is not the same fact as "the window is shut" --
			-- so the `Running` arm is unreachable without a measurement, and `bots_live.spec`'s own
			-- case at ("Running", 2, 1) keeps the value it had before task 323.
			expect(Match.botsNeedRebuild("Assigning", 1, nil)).to.equal(true)
			expect(Match.botsNeedRebuild("Assigning", 1, 1)).to.equal(false)
			expect(Match.botsNeedRebuild("Assigning", 2, 1)).to.equal(true)
			expect(Match.botsNeedRebuild("Running", 2, 1)).to.equal(false)
			expect(Match.botsNeedRebuild("Running", 1, nil)).to.equal(false)
			expect(Match.botsNeedRebuild("Scoring", 2, 1)).to.equal(false)
			expect(Match.botsNeedRebuild("Waiting", 2, 1)).to.equal(false)
		end)
	end)

	-- ------------------------------------- cases 16-20: the seam, the move, and the flag-off cost
	describe("the seam into placement, and the one move", function()
		it("case 16: the composition placementLine builds puts hunter 2 on the stand he claimed", function()
			-- `placementLine` is a LOCAL of src/server/Match/init.luau; this is the expression it
			-- builds, with the forest's own walk and seats, which is the seam end to end server-side.
			StandPick.reset(1)
			local ids = { 1001, 2002, 3003 }
			expect((StandPick.claim(ids[2], 1, 100))).to.equal(true)
			local picks = StandPick.picksFor(ids)
			expect(picks[2]).to.equal(1)
			local walk = walkOf("road")
			local deal = HighSeats.dealLine(walk, seatedOf("road"), {}, #ids, picks)
			expect(deal[2]).to.equal(1)
			expect(deal[1]).never.to.equal(1)
			expect(deal[3]).never.to.equal(1)
		end)

		it("case 17: with no claim the settle is a no-op, and production has made ZERO moves", function()
			-- THE FLAG-OFF COST, AS A MEASUREMENT OFF PRODUCTION. `MatchBoot` has been running this
			-- place's drives with `STAND_PICK` off, so these two numbers are what the flag-off path
			-- actually did -- not what a staged drive would do.
			expect(Match.CONFIG.STAND_PICK_SECONDS).to.equal(0)
			expect(Match.stats().standsSettled).to.equal(0)
			expect(Match.stats().standSettleStuds).to.equal(0)
			expect(Match.pickWindowOpen()).to.equal(false)
			expect(Match.standOf(1001)).to.equal(nil)
			-- ...and `applyStandSettle` returns on its first line because nothing is claimed.
			StandPick.reset(1)
			expect(StandPick.anyClaim()).to.equal(false)
			TestKit.note(
				string.format(
					"match_stand_pick: flag off -- STAND_PICK_SECONDS=%d standsSettled=%d standSettleStuds=%.2f (production)",
					Match.CONFIG.STAND_PICK_SECONDS,
					Match.stats().standsSettled,
					Match.stats().standSettleStuds
				)
			)
		end)

		describe("Body.carry", function()
			local folder: Folder? = nil

			local function fakePlayer(name: string, userId: number, at: Vector3)
				local character = Instance.new("Model")
				character.Name = name
				local root = Instance.new("Part")
				root.Name = "HumanoidRootPart"
				root.Size = Vector3.new(2, 2, 1)
				root.Position = at
				root.Anchored = true
				root.Parent = character
				character.PrimaryPart = root
				local humanoid = Instance.new("Humanoid")
				humanoid.Parent = character
				character.Parent = folder
				return { Name = name, UserId = userId, Character = character }, character
			end

			beforeEach(function()
				local made = Instance.new("Folder")
				made.Name = "Task323CarrySpec"
				made.Parent = Workspace
				folder = made
				Body.setGroundReader(function()
					return 100
				end)
			end)

			afterEach(function()
				Body.setGroundReader(nil)
				if folder then
					(folder :: Folder):Destroy()
					folder = nil
				end
			end)

			it("case 19: moves the character the player is already in, and calls no LoadCharacter", function()
				local player, character = fakePlayer("Claimant", 323001, Vector3.new(0, 110, 0))
				local before = Body.carried()
				local moved, studs = Body.carry(player :: any, CFrame.new(300, 500, 0), Match.CONFIG)
				expect(moved).to.equal(true)
				expect(Body.carried()).to.equal(before + 1)
				-- THE SAME OBJECT AFTERWARDS: his gun survives (a respawn would be a new Model).
				expect(player.Character).to.equal(character)
				expect(character.Parent).to.equal(folder)
				-- ON THE GROUND UNDER THE TARGET'S OWN x, z, not at the caller's Y.
				local put = character:GetPivot().Position
				expect(math.abs(put.X - 300) < 0.001).to.equal(true)
				expect(math.abs(put.Y - (100 + Body.clearanceFor(Match.CONFIG))) < 0.001).to.equal(true)
				expect(studs > 0).to.equal(true)
				-- AND THE HOLD IS HANDED STRAIGHT BACK: this is a move, not a freeze.
				expect(Body.isHolding(323001)).to.equal(false)
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				expect((humanoid :: Humanoid).WalkSpeed > 0).to.equal(true)
				expect((character.PrimaryPart :: BasePart).Anchored).to.equal(false)
			end)

			it("case 18: refuses a character somebody else is holding, and leaves the hold on", function()
				local player, character = fakePlayer("Tied", 323002, Vector3.new(0, 110, 0))
				expect(Body.holdCharacter(character, 323002) ~= nil).to.equal(true)
				local where = character:GetPivot().Position
				local refused = Body.carriesRefused()
				local moved, studs = Body.carry(player :: any, CFrame.new(300, 500, 0), Match.CONFIG)
				expect(moved).to.equal(false)
				expect(studs).to.equal(0)
				expect(Body.carriesRefused()).to.equal(refused + 1)
				expect(Body.isHolding(323002)).to.equal(true)
				expect((character:GetPivot().Position - where).Magnitude < 0.001).to.equal(true)
				Body.untieCharacter(character, 323002, nil)
			end)

			it("case 18: refuses a player with no character at all", function()
				local moved = Body.carry(
					{ Name = "Gone", UserId = 323003, Character = nil } :: any,
					CFrame.new(0, 0, 0),
					Match.CONFIG
				)
				expect(moved).to.equal(false)
			end)

			it("case 20: the move never misses the ground under a stand", function()
				-- `Body.carry` passes `attempts = 1` so it cannot yield; the reader above always
				-- answers, so a miss here would be the composition and not the terrain.
				local misses = Body.snapMisses()
				local player = fakePlayer("Settled", 323004, Vector3.new(0, 110, 0))
				Body.carry(player :: any, CFrame.new(50, 500, 50), Match.CONFIG)
				expect(Body.snapMisses()).to.equal(misses)
			end)
		end)
	end)
end
