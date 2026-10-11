-- match_config.spec: THE PER-WORLD CONFIG MERGE, and the guard round it (task 157).
--
-- PURE: no players, no boars, no clock, no world. `Match.mergeConfig` is exported precisely so this
-- spec can drive every branch of it with a table.
--
-- WHAT IT IS FOR. The real drive runs in TWO places now -- the DEV place and "Driven Hunt Forest
-- Test" -- and the forest needs its own drive length and no releases of its own. The whole of that
-- is two scalars handed to `Match.start`, and the whole of the risk is a third place where a number
-- about the SAFETY RULE could get a second value. So the allow-list is asserted by PATTERN here, not
-- by a list copied out of the module: a later hand adding `SAFETY_MISS_STUDS` to it fails this spec.
--
-- AND THE FIRST CASE IS THE ONE THAT MATTERS MOST: with no overrides the merge returns the defaults
-- THEMSELVES. That identity is what makes "the DEV drive did not change" one assertion instead of
-- thirty (`match_live.spec` asserts the live half of it), because there is only one table.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/forest-drive.md (section 4.2)
-- Note:   docs/research/2026-10-11-forest-drive.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Match = require(ServerScriptService:WaitForChild("Match"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

return function()
	describe("Match.mergeConfig", function()
		it("returns the DEFAULTS THEMSELVES when a world overrides nothing", function()
			-- BY IDENTITY, not by value: the DEV place passes no `config`, so every number the drive
			-- reads is the same object this spec is looking at.
			expect(Match.mergeConfig(Match.CONFIG, nil)).to.equal(Match.CONFIG)
			expect(Match.mergeConfig(Match.CONFIG, {})).to.equal(Match.CONFIG)
		end)

		it("changes exactly the keys it is given, and nothing else", function()
			local merged = Match.mergeConfig(Match.CONFIG, { DRIVE_SECONDS = 300, BOARS_PER_DRIVE = 0 })
			expect(merged).never.to.equal(Match.CONFIG)
			expect(merged.DRIVE_SECONDS).to.equal(300)
			expect(merged.BOARS_PER_DRIVE).to.equal(0)
			local checked = 0
			for key, value in pairs(Match.CONFIG) do
				if key ~= "DRIVE_SECONDS" and key ~= "BOARS_PER_DRIVE" then
					-- A nested block (POINTS, SOUNDER) compares by reference, which is the point:
					-- `table.clone` carries the same table over, so there is still ONE of each.
					expect(merged[key]).to.equal(value)
					checked += 1
				end
			end
			expect(checked > 20).to.equal(true)
			TestKit.note(string.format("match-config: %d keys carried over unchanged", checked))
		end)

		it("freezes what it returns, and never touches the defaults", function()
			local merged = Match.mergeConfig(Match.CONFIG, { DRIVE_SECONDS = 300 })
			expect(table.isfrozen(merged)).to.equal(true)
			local wrote = pcall(function()
				(merged :: any).DRIVE_SECONDS = 1
			end)
			expect(wrote).to.equal(false)
			-- ...and the defaults are what they always were.
			expect(Match.CONFIG.DRIVE_SECONDS).to.equal(600)
			expect(Match.CONFIG.BOARS_PER_DRIVE).to.equal(6)
			expect(table.isfrozen(Match.CONFIG)).to.equal(true)
		end)

		it("refuses a key that is not on the allow-list, and names it", function()
			local ok, err = pcall(function()
				return Match.mergeConfig(Match.CONFIG, { SAFETY_MISS_STUDS = 999 })
			end)
			expect(ok).to.equal(false)
			expect(string.find(tostring(err), "SAFETY_MISS_STUDS", 1, true) ~= nil).to.equal(true)
			-- The one that would quietly make a solo player a beater.
			expect(pcall(function()
				return Match.mergeConfig(Match.CONFIG, { ODD_PLAYER_TEAM = "Drivers" })
			end)).to.equal(false)
		end)

		it("refuses a block, because a wholesale replacement is nil for every number in it", function()
			-- The evidence is in this repo: `Boar.newRuntime`'s merge replaces a nested block, which
			-- cost `ForestTestBoot` five hand-written clones and `Boar.newRuntime` two special cases.
			local ok, err = pcall(function()
				return Match.mergeConfig(Match.CONFIG, { SOUNDER = { ENABLED = true } })
			end)
			expect(ok).to.equal(false)
			expect(string.find(tostring(err), "scalars only", 1, true) ~= nil).to.equal(true)
		end)

		it("keeps every rule number, every roster decision and every flag read OFF the allow-list", function()
			local list = Match.WORLD_OVERRIDABLE
			expect(table.isfrozen(list)).to.equal(true)
			-- BY PATTERN, so a later addition cannot sneak one in: the safety and tie numbers are not
			-- replicated at all (docs/design/drive.md section 3.4), and a per-world value for one of
			-- them would be a second answer to one rule in the world Karen actually plays.
			for key in pairs(list) do
				expect(string.match(key, "^SAFETY_")).to.equal(nil)
				expect(string.match(key, "^TIE_")).to.equal(nil)
				expect(string.match(key, "^QUICK_TEST")).to.equal(nil)
			end
			for _, key in ipairs({
				"POINTS",
				"SOUNDER",
				"MIN_PLAYERS",
				"MAX_PLAYERS",
				"ODD_PLAYER_TEAM",
				"SWAP_TEAMS_EACH_DRIVE",
				"DRIVERS_MAY_SHOOT",
				"OUTFITS_ENABLED",
				"SEED",
			}) do
				expect(list[key]).to.equal(nil)
			end
			-- ...and the two the forest actually uses ARE on it.
			expect(list.DRIVE_SECONDS).to.equal(true)
			expect(list.BOARS_PER_DRIVE).to.equal(true)
		end)
	end)

	describe("the live config", function()
		it("is the defaults in this place, which is how DEV proves it did not change", function()
			-- The harness runs in the DEV place, where `MatchBoot` started the drive with no `config`
			-- field at all. The live half of the same claim is in `match_live.spec`.
			expect(Match.config()).to.equal(Match.CONFIG)
		end)
	end)
end
