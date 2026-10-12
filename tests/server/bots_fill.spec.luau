-- bots_fill.spec: HOW MANY BOTS A DRIVE WANTS, as arithmetic -- no drive, no players, no rigs, no
-- Instances and no clock. `Bots.Fill` is pure for exactly this reason: Karen's rule is "4 hunters 4
-- beaters", and the question "what happens when three of them are real" is a subtraction a spec can
-- state at every count instead of a thing somebody watches in a playtest.
--
-- THE SWITCH-OFF CASE IS THE ONE THAT MATTERS MOST (CLAUDE.md "Feature flags"): with the flag off,
-- the answer is {0, 0}, which is what makes "off means today's game bit for bit" a checked claim --
-- `Match`'s `syncBots` builds nothing when both numbers are zero.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/bots.md (sections 7, 13, 14)
-- Note:   docs/research/2026-10-12-bots.md (section 2.1 -- ioquake3's G_CheckMinimumPlayers)
local ServerScriptService = game:GetService("ServerScriptService")

local Bots = require(ServerScriptService:WaitForChild("Bots"))
local Match = require(ServerScriptService:WaitForChild("Match"))
local Fill = Bots.Fill

-- This spec's own config, the shape `Match.CONFIG.BOTS` is, short enough to read in a failure
-- message. The ON state is driven by a TABLE while the flag itself sits at OFF, which is the
-- reachability condition the flag discipline requires.
local function configWith(enabled: boolean, hunters: number, beaters: number, cap: number?)
	return {
		BOTS = {
			ENABLED = enabled,
			TARGET = { hunters = hunters, beaters = beaters },
			MAX_BOTS = cap or 8,
			GOAL_PAST_LINE_STUDS = 20,
		},
	}
end

local ON = configWith(true, 4, 4)
local OFF = configWith(false, 4, 4)

return function()
	describe("the fill, per team (ioquake3's G_CheckMinimumPlayers, re-pointed)", function()
		it("fills every slot no real player fills, on each side separately", function()
			-- Nobody at all: a solo-less server still wants a full drive, which is the whole point.
			local none = Fill.counts({ hunters = 0, beaters = 0 }, ON)
			expect(none.hunters).to.equal(4)
			expect(none.beaters).to.equal(4)

			-- Karen alone, as a hunter -- the case she actually plays.
			local solo = Fill.counts({ hunters = 1, beaters = 0 }, ON)
			expect(solo.hunters).to.equal(3)
			expect(solo.beaters).to.equal(4)

			-- Karen alone, as a BEATER (`/beater` in the Forest Test).
			local beater = Fill.counts({ hunters = 0, beaters = 1 }, ON)
			expect(beater.hunters).to.equal(4)
			expect(beater.beaters).to.equal(3)
		end)

		it("is the subtraction at every count from 0 to 8 per side, and never negative", function()
			for real = 0, 8 do
				local counts = Fill.counts({ hunters = real, beaters = real }, ON)
				local want = math.max(0, 4 - real)
				expect(counts.hunters).to.equal(want)
				expect(counts.beaters).to.equal(want)
				-- A FULL SERVER HAS NO BOTS AT ALL, and that is ioquake3's symmetry: a bot hands its
				-- slot back the moment a human takes it. Here it is structural -- the function is
				-- level-triggered, so "remove one" is simply a smaller answer.
				if real >= 4 then
					expect(counts.hunters).to.equal(0)
					expect(counts.beaters).to.equal(0)
				end
			end
		end)

		it("gives a bot's slot back to a real player who joins", function()
			local before = Fill.counts({ hunters = 1, beaters = 1 }, ON)
			local after = Fill.counts({ hunters = 2, beaters = 1 }, ON)
			expect(before.hunters).to.equal(3)
			expect(after.hunters).to.equal(2) -- one fewer bot, because one more person
			expect(after.beaters).to.equal(before.beaters) -- and the other side is untouched
		end)
	end)

	describe("the switch", function()
		it("answers nothing at all with the flag off", function()
			local counts = Fill.counts({ hunters = 0, beaters = 0 }, OFF)
			expect(counts.hunters).to.equal(0)
			expect(counts.beaters).to.equal(0)
		end)

		it("treats a missing BOTS block as off, which is a world that never heard of them", function()
			local counts = Fill.counts({ hunters = 0, beaters = 0 }, {})
			expect(counts.hunters).to.equal(0)
			expect(counts.beaters).to.equal(0)
		end)

		it("takes a target of 0 as that side off, and leaves the other side alone", function()
			-- ioquake3's `if (minplayers <= 0) return;`, per team: the target IS the switch, so there
			-- is no second boolean beside it that could disagree with it.
			local noHunters = Fill.counts({ hunters = 0, beaters = 0 }, configWith(true, 0, 4))
			expect(noHunters.hunters).to.equal(0)
			expect(noHunters.beaters).to.equal(4)

			local noBeaters = Fill.counts({ hunters = 0, beaters = 0 }, configWith(true, 4, 0))
			expect(noBeaters.hunters).to.equal(4)
			expect(noBeaters.beaters).to.equal(0)
		end)
	end)

	describe("a bot hunter needs a stand of its own", function()
		it("never wants more hunters than there are free stands", function()
			expect(Fill.counts({ hunters = 0, beaters = 0 }, ON, 2).hunters).to.equal(2)
			expect(Fill.counts({ hunters = 0, beaters = 0 }, ON, 0).hunters).to.equal(0)
			-- ...and the beaters do not care about stands at all.
			expect(Fill.counts({ hunters = 0, beaters = 0 }, ON, 0).beaters).to.equal(4)
		end)

		it("does not clamp when the caller did not measure the stands", function()
			-- `nil` is "I did not look", which is NOT the same fact as "there are none" -- a world
			-- with no post list must not silently lose its bot hunters.
			expect(Fill.counts({ hunters = 0, beaters = 0 }, ON, nil).hunters).to.equal(4)
		end)

		it("counts the free stands as the posts the real hunters are not on", function()
			expect(Fill.standsFree(9, 0)).to.equal(9)
			expect(Fill.standsFree(9, 1)).to.equal(8)
			expect(Fill.standsFree(9, 9)).to.equal(0)
			expect(Fill.standsFree(2, 5)).to.equal(0) -- never negative
		end)
	end)

	describe("the cap", function()
		it("trims beaters first, deterministically", function()
			local counts = Fill.counts({ hunters = 0, beaters = 0 }, configWith(true, 4, 4, 5))
			expect(counts.hunters).to.equal(4)
			expect(counts.beaters).to.equal(1)
			expect(counts.hunters + counts.beaters).to.equal(5)
		end)

		it("trims hunters too when the cap is below the hunters alone", function()
			local counts = Fill.counts({ hunters = 0, beaters = 0 }, configWith(true, 4, 4, 2))
			expect(counts.beaters).to.equal(0)
			expect(counts.hunters).to.equal(2)
		end)

		it("is UNREACHABLE with the shipped numbers, and that is asserted rather than assumed", function()
			-- The `MAX_ALIVE_BOARS >= SOUNDER.MAX_SIZE` idiom (match_live.spec): a relation between
			-- two numbers in one config is an invariant somebody checks, not a coincidence. If Karen
			-- ever asks for six beaters, this is the line that says the cap now bites.
			local bots = Match.CONFIG.BOTS
			expect(bots.TARGET.hunters + bots.TARGET.beaters <= bots.MAX_BOTS).to.equal(true)
		end)
	end)

	describe("the shipped numbers are Karen's", function()
		it("is four and four, and the flag is born off", function()
			local bots = Match.CONFIG.BOTS
			expect(bots.TARGET.hunters).to.equal(4) -- Karen: "Let's make 4 hunters 4 beaters"
			expect(bots.TARGET.beaters).to.equal(4)
			expect(bots.MAX_BOTS).to.equal(8)
			-- BORN OFF, so merging this changes nothing anybody plays until the Director turns it on
			-- for a playtest and Karen looks at it.
			expect(bots.ENABLED).to.equal(false)
		end)

		it("walks a bot past the line by twice the crossing margin", function()
			-- So "arrived at its goal" means CROSSED WITH MARGIN, and the end of a drive does not
			-- turn on one stud of float error.
			expect(Match.CONFIG.BOTS.GOAL_PAST_LINE_STUDS).to.equal(2 * Match.CONFIG.BEATER_CROSS_MARGIN_STUDS)
		end)

		it("is not world-overridable, and a world that tries is REFUSED", function()
			-- Two guards, and either one alone would do: `BOTS` is absent from the allow-list, and
			-- `mergeConfig` refuses a table outright whatever the list says. A world that could turn
			-- the bots on by itself would be a second boundary read of the flag.
			expect(Match.WORLD_OVERRIDABLE.BOTS).to.equal(nil)
			expect(function()
				Match.mergeConfig(Match.CONFIG, { BOTS = { ENABLED = true } })
			end).to.throw()
			-- ...and the DEV drive is still running on the defaults table itself, by identity.
			expect(Match.config()).to.equal(Match.CONFIG)
		end)
	end)
end
