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

-- THE CLIENT'S LAYOUT CONTRACT, read here for one claim only (task 170): the results panel's row
-- budget is the one number that has to be compared against `Match.CONFIG.MAX_PLAYERS`, and this is
-- the only side that can see both.
local Drive = require(ReplicatedStorage:WaitForChild("Drive"))
local Match = require(ServerScriptService:WaitForChild("Match"))
local Licences = require(ReplicatedStorage:WaitForChild("Licences"))
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
			--
			-- THE KEY HERE IS ONE THAT *IS* ALLOWED, because the allow-list is checked first: a block
			-- off the list (`SOUNDER`) is refused by the other rule and would prove nothing about
			-- this one. MEASURED: round 1 of this task asserted `SOUNDER` and read back the
			-- allow-list's message.
			local ok, err = pcall(function()
				return Match.mergeConfig(Match.CONFIG, { DRIVE_SECONDS = { 300 } })
			end)
			expect(ok).to.equal(false)
			expect(string.find(tostring(err), "scalars only", 1, true) ~= nil).to.equal(true)
			-- ...and a block that is ALSO off the list is still refused, by whichever rule gets there
			-- first.
			expect(pcall(function()
				return Match.mergeConfig(Match.CONFIG, { SOUNDER = { ENABLED = true } })
			end)).to.equal(false)
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
			-- NO ECONOMY KEY IS ON IT EITHER (task 170): the coin rates are `Economy.CONFIG`'s and a
			-- world may not give any rule a second value. They are not in `Match.CONFIG` at all, which is
			-- the stronger half of the claim.
			for _, key in ipairs({ "COINS_PER_POINT", "PARTICIPATION", "FIRST_PLACE", "FLOOR", "STORE_NAME" }) do
				expect(list[key]).to.equal(nil)
				expect((Match.CONFIG :: any)[key]).to.equal(nil)
			end
		end)
	end)

	-- THE RESULTS PANEL'S ROW BUDGET (task 170), asserted HERE because this is the one side that can
	-- see both numbers: `Drive.CONFIG.SCORE_ROWS_MAX` is the client's layout and
	-- `Match.CONFIG.MAX_PLAYERS` is the server's rule. Three headings (hunters, beaters, others) plus
	-- a full server is 19 lines, so a panel with fewer slots would silently drop real rows off the
	-- bottom of Karen's results table.
	describe("the results panel's budget", function()
		it("has room for every player plus the three headings", function()
			expect(Drive.CONFIG.SCORE_ROWS_MAX >= Match.CONFIG.MAX_PLAYERS + 3).to.equal(true)
			expect(Drive.CONFIG.SCORE_ROWS_MAX).to.equal(20)
			expect(Match.CONFIG.MAX_PLAYERS).to.equal(16)
		end)
	end)

	-- WHAT MAY BE SHOT, AS THE START CARD DRAWS IT (task 158, ROWS since 201 part 3).
	-- `Match.quarryRows` is pure and exported for exactly this: the rule is the server's and the
	-- card only lays it out, so what a player is told can be checked with no client and no world.
	--
	-- IT USED TO BE A SENTENCE and the cases under it asserted the sentence's wording
	-- (`WILD BOAR, POINTS: male 10, female 6, cub -10`). The Designer's `startcard-spec.md` section
	-- 0 is why they are gone: *"One line carries three prices... Nothing can be found in it at a
	-- glance, and the one number that is negative is the one hiding at the end."* They are in
	-- `backups/2026-10-18_task-201-3_quarry-lines.txt`.
	describe("the quarry rows", function()
		it("sends one row per kind, with the species on each, from the config and not a literal", function()
			local rows = Match.quarryRows({
				QUARRY = { { species = "WILD BOAR", kinds = { "male", "female" } } },
			})
			expect(#rows).to.equal(2)
			expect(rows[1].species).to.equal("WILD BOAR")
			expect(rows[1].kind).to.equal("male")
			expect(rows[2].kind).to.equal("female")
		end)

		-- ...AND WHAT EACH KIND IS WORTH, OFF `POINTS.KIND` AND NOT OFF A SECOND COPY OF IT (task
		-- 160). Karen asked *"How many shoot and male is more worth then famale"*, and the screen
		-- that answers "what may I shoot" is where that answer belongs.
		it("prices each kind from POINTS.KIND", function()
			local rows = Match.quarryRows({
				QUARRY = { { species = "WILD BOAR", kinds = { "male", "female", "cub" } } },
				POINTS = { KIND = { male = 10, female = 6, cub = -10 } },
			})
			expect(rows[1].points).to.equal(10)
			expect(rows[2].points).to.equal(6)
			expect(rows[3].points).to.equal(-10)
		end)

		it("sends a kind the table has no price for with NO number, rather than a wrong one", function()
			local rows = Match.quarryRows({
				QUARRY = { { species = "WILD BOAR", kinds = { "male", "yearling" } } },
				POINTS = { KIND = { male = 10, unknown = 6 } },
			})
			-- `unknown` is a FALLBACK and not a price for this animal: the card does not claim a
			-- yearling is worth 6 when nobody decided that it is. The row still goes out, so the
			-- player is told the animal is quarry -- it is the NUMBER that is absent.
			expect(rows[2].kind).to.equal("yearling")
			expect(rows[2].points).to.equal(nil)
		end)

		it("takes more than one species, which is what red deer will be", function()
			local rows = Match.quarryRows({
				QUARRY = {
					{ species = "WILD BOAR", kinds = { "male", "female", "cub" } },
					{ species = "RED DEER", kinds = { "stag" } },
				},
			})
			expect(#rows).to.equal(4)
			expect(rows[4].species).to.equal("RED DEER")
			expect(rows[4].kind).to.equal("stag")
		end)

		it("says nothing at all when nothing is named, rather than erroring", function()
			expect(#Match.quarryRows({})).to.equal(0)
		end)

		it("SAYS WHAT THE RULE REALLY IS: a piglet is legal and it COSTS you", function()
			-- Karen's words were "wild boar -- male, female; NOT piglets/cubs", and on 2026-10-12 she
			-- settled the half of it the code can hold: shooting a piglet is a PENALTY. So since task
			-- 170 `POINTS.KIND.cub` is -10 and the card says so.
			--
			-- THE WEAPON-SIDE REFUSAL EXISTS AND A CUB IS DELIBERATELY NOT IN IT (task 171): what
			-- `Weapon.Rules` refuses is a shot at a BEATER, a shot from off your stand and a species
			-- you have no licence for. A piglet is the one Karen settled the other way.
			local rows = Match.quarryRows(Match.CONFIG)
			local byKind = {}
			local joined = {}
			for _, row in ipairs(rows) do
				byKind[row.kind] = row
				table.insert(joined, string.format("%s %s", row.kind, tostring(row.points)))
			end
			for _, kind in ipairs({ "male", "female", "cub" }) do
				expect(byKind[kind]).to.be.ok()
				expect(byKind[kind].species).to.equal("WILD BOAR")
				expect(type(byKind[kind].points)).to.equal("number")
			end
			expect(byKind.cub.points < 0).to.equal(true)
			expect(byKind.cub.points < byKind.female.points).to.equal(true)
			expect(byKind.female.points < byKind.male.points).to.equal(true)
			-- THE SENTENCE AND ITS NOTE ARE GONE, asserted as gone -- a config that still carried
			-- `QUARRY_NOTE` would mean the card has two sources for the piglet rule again.
			expect(Match.quarryLines).to.equal(nil)
			expect(Match.CONFIG.QUARRY_NOTE).to.equal(nil)
			TestKit.note("match-config: the start card's quarry rows -> " .. table.concat(joined, " | "))
		end)

		-- WHAT SHOOTING A PERSON COSTS, ON THE WIRE (201 part 3). The Designer added that row to the
		-- card -- *"a real rule the card never mentioned, and the beaters are walking toward the
		-- hunter while this card is up"* -- and the client is given the number rather than holding a
		-- copy of it.
		it("prices a person off SAFETY_PENALTY, which is the number the card draws", function()
			expect(Match.CONFIG.POINTS.SAFETY_PENALTY < 0).to.equal(true)
			expect(Match.CONFIG.POINTS.SAFETY_PENALTY).to.equal(-10)
		end)

		-- THE RED DEER IS ON THE CARD (task 234). Karen, 2026-10-21, having played: *"I didnt see
		-- deer red tag why ?"* / *"I want to see a deer"*. The deer have been licensed quarry since
		-- task 223 and the one screen that answers *"what may I shoot"* never mentioned them.
		it("NAMES THE RED DEER, with its own prices, off the one table that holds them", function()
			local rows = Match.quarryRows(Match.CONFIG)
			local byKind = {}
			for _, row in ipairs(rows) do
				byKind[row.kind] = row
			end
			for _, kind in ipairs({ "stag", "hind", "calf" }) do
				expect(byKind[kind]).to.be.ok()
				expect(byKind[kind].species).to.equal("RED DEER")
				-- OFF `POINTS.KIND` AND NOT A LITERAL: this is the same table the SCORE is paid
				-- from, so the card cannot promise a number the kill does not pay.
				expect(byKind[kind].points).to.equal(Match.CONFIG.POINTS.KIND[kind])
			end
			-- Karen's own order of worth: a stag is the prize, a hind is a sow, a calf is a piglet.
			expect(byKind.stag.points > byKind.male.points).to.equal(true)
			expect(byKind.hind.points).to.equal(byKind.female.points)
			expect(byKind.calf.points).to.equal(byKind.cub.points)
			expect(byKind.calf.points < 0).to.equal(true)
		end)

		it("SAYS WHICH ROWS NEED A LICENCE, off Licences and not off a second copy of it", function()
			-- The card has to say `NEEDS LICENCE` over the deer, and the CLIENT must not be the
			-- thing that knows which species those are -- *"a second copy of 'a red deer needs a
			-- licence' living on the client is exactly the two-correct-pieces-of-code failure"*
			-- (`Licences`' own header). So it rides the wire.
			local rows = Match.quarryRows(Match.CONFIG)
			local seen = {}
			for _, row in ipairs(rows) do
				seen[row.species] = row.licence
				expect(type(row.licence)).to.equal("boolean")
			end
			expect(seen["WILD BOAR"]).to.equal(false)
			expect(seen["RED DEER"]).to.equal(true)
			-- ...AND IT IS THE SAME ANSWER THE WEAPON ENFORCES. TO SEE IT FAIL: flip
			-- `Licences.ROWS.reddeer.licence` to false -- the gate stops refusing the shot AND this
			-- row stops asking for the card, together, because there is one row.
			expect(seen["RED DEER"]).to.equal(Licences.required("reddeer"))
			expect(seen["WILD BOAR"]).to.equal(Licences.required("boar"))
		end)

		it("turns the species KEY into the printed label, and leaves a literal alone", function()
			-- `QUARRY` names `boar` / `reddeer`; the wire carries `WILD BOAR` / `RED DEER`, which
			-- is `Licences.ROWS[key].label` and nothing else. A row whose species is NOT a licence
			-- key passes through unchanged with `licence = false` -- which is what keeps every case
			-- above, written with literals, reading exactly as it did.
			expect(Match.CONFIG.QUARRY[1].species).to.equal("boar")
			expect(Match.CONFIG.QUARRY[2].species).to.equal("reddeer")
			local rows = Match.quarryRows({ QUARRY = { { species = "GREY WOLF", kinds = { "dog" } } } })
			expect(rows[1].species).to.equal("GREY WOLF")
			expect(rows[1].licence).to.equal(false)
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
