-- zz_claim_window.spec: THE TWO NUMBERS THAT HAVE TO AGREE ACROSS TWO OWNERS (task 266)
--
-- `Shotgun.CONFIG.CLAIM.AGE_MAX_SECONDS` is the WEAPON's: how old a claimed arrival may be when the
-- shot resolves. `Boar.CONFIG.HISTORY.SAMPLES` is the ANIMAL's: how far back it remembers being
-- somewhere. **A claim the weapon is willing to judge must be inside the span the animal can
-- remember**, or the feature fails in the one way nobody would notice -- every claim refused, every
-- shot falling back to the server's own flight, and the game looking exactly as it did before.
--
-- `zz_` BECAUSE OF WHAT SORTS AFTER IT, the reason `zz_horn.spec`'s header gives: TestEZ runs spec
-- files in name order and `sync.spec` asks whether the gate token is still fresh, so anything that
-- spends real seconds belongs last. This file spends none -- it is four comparisons -- but it is
-- named for the pair it guards and it sits with `zz_drive_boundary`, which is the other
-- cross-system invariant in this suite.
--
-- THE IDIOM IS `zz_horn.spec`'s, which already holds `Horn`, `Boar.CONFIG.SENSE` and
-- `ForestTest.SPOOK` to one `METRES_PER_STUD`: a number that two owners must agree about is
-- asserted in ONE file, so a change to either side fails here rather than quietly in a drive.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/ballistics.md (sections 3.1, 3.2, 3.3)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

return function()
	local CLAIM = Shotgun.CONFIG.CLAIM
	local HISTORY = Boar.CONFIG.HISTORY

	describe("the claim window fits inside the animal's memory", function()
		it("both halves of the pair exist", function()
			expect(CLAIM).to.be.ok()
			expect(HISTORY).to.be.ok()
			expect(type(CLAIM.AGE_MAX_SECONDS)).to.equal("number")
			expect(type(CLAIM.VIEW_LAG_MAX_SECONDS)).to.equal("number")
			-- THE LOOP'S CAP MAY NEVER SILENTLY TRUNCATE THE WINDOW (task 271).
			expect(CLAIM.VIEW_LAG_MAX_SAMPLES >= CLAIM.VIEW_LAG_MAX_SECONDS / CLAIM.VIEW_LAG_STEP_SECONDS + 1).to.equal(
				true
			)
			expect(type(HISTORY.SAMPLES)).to.equal("number")
		end)

		-- THE INVARIANT. The ring holds one sample per Heartbeat, so at 60 Hz its span is
		-- `SAMPLES / 60` seconds. The weapon may ask about an arrival up to `AGE_MAX_SECONDS` old,
		-- and the lookup itself can land one step before the oldest sample, so the margin needs one
		-- step on top.
		--
		-- 60 Hz IS THE WORST CASE AND NOT AN ASSUMPTION: a slower server takes FEWER samples per
		-- second, so its ring spans LONGER. The direction is what makes this safe to assert against
		-- one number.
		it("remembers longer than the weapon is willing to judge, with margin", function()
			local span = HISTORY.SAMPLES / 60
			-- ...AND THE VIEW-LAG WINDOW (task 271): the sweep looks back as far as
			-- `arrivalAt - VIEW_LAG_MAX_SECONDS`, so the ring must span the claim's own age PLUS
			-- that window PLUS the Heartbeat the arrival instant can sit past the newest sample.
			local window = CLAIM.AGE_MAX_SECONDS + CLAIM.VIEW_LAG_MAX_SECONDS + 1 / 60
			expect(span >= window).to.equal(true)
			-- Stated as a ratio so a future edit that halves the ring fails LOUDLY here rather than
			-- scraping past with no margin at all.
			expect(span / window >= 1.5).to.equal(true)
		end)
	end)

	describe("a tolerance cannot be wider than the thing it measures", function()
		-- A LINE TOLERANCE WIDER THAN HALF A BODY would let a claim name the WRONG END of the animal:
		-- the check that makes the zone geometric (design 5.2 check 4) would stop distinguishing a
		-- chest from a rump, which is precisely the distinction Karen asked for (*"to get hit in
		-- head neck or heart"*).
		it("the line tolerance is under half a boar's own body", function()
			local half = Boar.CONFIG.BODY_SIZE.Z / 2
			expect(CLAIM.LINE_TOLERANCE_STUDS < half).to.equal(true)
		end)

		-- AND THE POSITION TOLERANCE IS THE OTHER WAY ROUND ON PURPOSE: it is about ONE WHOLE BODY,
		-- because it asks "the same animal in the same place" and not "the same millisecond" -- the
		-- shared clock is unestablished (task 265 round 3), so a tight bound there would refuse every
		-- honest claim. It must not be so loose that it spans two animals standing apart.
		it("the position tolerance is about one body, not two", function()
			local body = Boar.CONFIG.BODY_SIZE.Z
			expect(CLAIM.POSITION_TOLERANCE_STUDS >= body).to.equal(true)
			expect(CLAIM.POSITION_TOLERANCE_STUDS <= body * 2).to.equal(true)
		end)
	end)

	describe("the client's own bound covers the longest shot in the game", function()
		-- `CLAIM.MAX_SUBSTEPS` bounds ONE simulation's whole flight inside ONE frame, so if it were
		-- shorter than the longest flight the client would stop stepping before its bullet arrived
		-- and simply never claim a long shot -- a silent hole in the feature at exactly the range
		-- where the view error is largest.
		it("MAX_SUBSTEPS x the step cap exceeds the rifle's longest flight", function()
			local reach = CLAIM.MAX_SUBSTEPS * Shotgun.CONFIG.FLIGHT_STEP_MAX_SECONDS
			local Ballistics = require(ReplicatedStorage:WaitForChild("Ballistics"))
			local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
			local row = Weapons.ROWS.rifle
			local shot = Ballistics.shotFor(row, "Slug")
			expect(shot).to.be.ok()
			local longest = Ballistics.timeToRange(shot :: any, row.RANGE_STUDS.Slug)
			expect(reach > longest).to.equal(true)
		end)
	end)
end
