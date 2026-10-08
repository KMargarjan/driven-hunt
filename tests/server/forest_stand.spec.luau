-- forest_stand.spec: THE PLAYTEST WORLD'S OWN ARITHMETIC -- the road, the stands, the leash and the
-- phase a wave is in. Pure: no Workspace, no boars, no clock.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- IT EXISTS BECAUSE NOTHING COVERED ANY OF IT (task 122 round 2, the Reviewer's last note). The
-- verification of record was an inlined run in the Edit place, written into TASKS.md row 122 -- "9
-- stands all within 0.0001 studs of the road curve ... the leash passes at 5 studs and fails at 7" --
-- which is a measurement nobody can repeat on a later commit. These are the same claims as
-- assertions, and they cost nothing to run.
--
-- THE TWO HALVES ARE TWO MODULES, deliberately: `ReplicatedStorage.ForestTest` is the DATA (the road
-- curve, the stands, the bands) and `ServerScriptService.ForestTest` is the drive that reads it. A
-- spec that drives both proves they agree.
--
-- Design: no new design document -- a playtest world behind a world string. TASKS.md row 122.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = require(ReplicatedStorage:WaitForChild("ForestTest"))
local ForestTest = require(ServerScriptService:WaitForChild("ForestTest"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

return function()
	describe("the road and the stands", function()
		it("puts every stand ON the road, at the spacing the world claims", function()
			local worst = 0
			for index = 1, Data.STAND_COUNT do
				local stand = Data.standPosition(index)
				worst = math.max(worst, math.abs(stand.Z - Data.roadZ(stand.X)))
			end
			-- A STAND'S z IS READ OFF THE CURVE, so the only difference between the two is the
			-- FLOAT32 a `Vector3` stores: this world sits at z = -2097, and float32 carries about
			-- seven digits, so a round trip there costs ~1e-4 studs. MEASURED on this commit, in the
			-- live module: 0.000110, 0.000043, 0.000106, 0.000020, 0.000000 and back out again --
			-- symmetric about the middle stand, which is what a rounding error looks like and what a
			-- second definition of the road would not. The bound is a thousandth of a stud: tight
			-- enough to catch a real disagreement, loose enough not to assert float32 away.
			expect(worst < 1e-3).to.equal(true)
			for index = 2, Data.STAND_COUNT do
				local gap = Data.standX(index) - Data.standX(index - 1)
				expect(math.abs(gap - Data.STAND_SPACING) < 1e-6).to.equal(true)
			end
			TestKit.note(
				string.format(
					"forest-stand: %d stands %d studs apart, worst %.6f studs off the road curve",
					Data.STAND_COUNT,
					Data.STAND_SPACING,
					worst
				)
			)
		end)

		it("centres the line on the world's centre", function()
			local middle = (Data.STAND_COUNT + 1) / 2
			expect(math.abs(Data.standX(middle) - Data.CENTRE.X) < 1e-6).to.equal(true)
		end)

		it("curves: the road is not a straight line across the stands", function()
			-- If it were, `roadZ` could be deleted and every stand would sit at CENTRE.Z -- which is
			-- what a reader checking only the first claim above might conclude.
			local lowest, highest = math.huge, -math.huge
			for index = 1, Data.STAND_COUNT do
				local z = Data.roadZ(Data.standX(index))
				lowest, highest = math.min(lowest, z), math.max(highest, z)
			end
			expect(highest - lowest > 1).to.equal(true)
		end)
	end)

	describe("the leash and the pick", function()
		it("holds a hunter inside his own leash and lets him go nowhere else", function()
			local home = Data.standPosition(4)
			expect(ForestTest.withinLeash(home, 4)).to.equal(true)
			-- Inside and outside, either side of the one number the rule is made of.
			local inside = home + Vector3.new(Data.PICK.leashStuds - 1, 0, 0)
			local outside = home + Vector3.new(Data.PICK.leashStuds + 1, 0, 0)
			expect(ForestTest.withinLeash(inside, 4)).to.equal(true)
			expect(ForestTest.withinLeash(outside, 4)).to.equal(false)
			-- HEIGHT DOES NOT COUNT: the leash is a circle on the ground, so a hunter on a rise is
			-- not dragged off his stand by the terrain.
			expect(ForestTest.withinLeash(home + Vector3.new(0, 50, 0), 4)).to.equal(true)
		end)

		it("picks the stand a hunter is standing on, and his neighbour's when he walks there", function()
			for index = 1, Data.STAND_COUNT do
				expect(ForestTest.nearestStand(Data.standPosition(index))).to.equal(index)
			end
			-- Just past the midpoint between two stands, the far one wins -- which is what makes
			-- "walk to it" the selection.
			local midpoint = (Data.standPosition(3) + Data.standPosition(4)) / 2
			expect(ForestTest.nearestStand(midpoint + Vector3.new(1, 0, 0))).to.equal(4)
			expect(ForestTest.nearestStand(midpoint - Vector3.new(1, 0, 0))).to.equal(3)
		end)
	end)

	describe("which phase a wave is in", function()
		local WAVE = ForestTest.WAVE

		it("pushes until its time is up, then it is done", function()
			expect(ForestTest.wavePhase(0, false)).to.equal("push")
			expect(ForestTest.wavePhase(WAVE.pushSeconds - 1, false)).to.equal("push")
			expect(ForestTest.wavePhase(WAVE.pushSeconds, false)).to.equal("done")
		end)

		it("stops pushing a turn-back wave once it is near the road", function()
			-- THE TURN IS A PUSH THAT STOPS, which is what this world can honestly do; the "turn"
			-- phase itself was removed in round 2 after three measured attempts all crossed anyway
			-- (`backups/2026-10-06-forest-test-turn-phase.md`).
			expect(ForestTest.wavePhase(1, true, WAVE.turnAtDz + 10)).to.equal("push")
			expect(ForestTest.wavePhase(1, true, WAVE.turnAtDz)).to.equal("done")
			expect(ForestTest.wavePhase(1, true, WAVE.turnAtDz - 10)).to.equal("done")
		end)

		it("walks a lateral wave ACROSS her front before it goes over the road", function()
			-- Coming south, still too far north to be worth watching: keep pushing.
			expect(ForestTest.wavePhase(1, false, WAVE.lateralDz + 10, "LtoR", 0)).to.equal("push")
			-- In the band and the pass has not been walked yet: across.
			expect(ForestTest.wavePhase(1, false, WAVE.lateralDz - 1, "LtoR", 0)).to.equal("lateral")
			-- The pass is done: over the road.
			expect(ForestTest.wavePhase(1, false, WAVE.lateralDz - 1, "LtoR", WAVE.lateralSpan)).to.equal("push")
			-- Out of time is out of time, whatever it was doing.
			expect(ForestTest.wavePhase(WAVE.pushSeconds, false, WAVE.lateralDz - 1, "LtoR", 0)).to.equal("done")
		end)

		it("never answers a phase that no longer exists", function()
			-- `Phase` lost "turn" in round 2; this is the assertion that keeps it gone.
			for _, turnsBack in ipairs({ true, false }) do
				for elapsed = 0, WAVE.pushSeconds, 3 do
					for _, dz in ipairs({ -50, 0, WAVE.turnAtDz, 80 }) do
						local phase = ForestTest.wavePhase(elapsed, turnsBack, dz)
						expect(phase == "push" or phase == "lateral" or phase == "done").to.equal(true)
					end
				end
			end
		end)
	end)

	describe("which way a lateral wave walks", function()
		it("reads a side as a sign, and anything else as none", function()
			-- THE WAVE SPECS NAME THE DIRECTION OF TRAVEL, not a side: "LtoR" is a herd walking from
			-- her left to her right (`src/shared/ForestTest/init.luau`), and the sign is the flank
			-- the BEATER takes, which is the one they came from.
			expect(ForestTest.lateralSign("LtoR")).to.equal(-1)
			expect(ForestTest.lateralSign("RtoL")).to.equal(1)
			expect(ForestTest.lateralSign(nil)).to.equal(0)
			expect(ForestTest.lateralSign("sideways")).to.equal(0)
		end)

		it("puts the beater on the flank they came from, at the herd's own z", function()
			local centre = Vector3.new(100, 5, -600)
			local at = ForestTest.beaterPosition(centre, 1, false, ForestTest.WAVE.lateralDz - 1, "LtoR", 0)
			expect(at).to.be.ok()
			-- A beater NORTH of them pushes them south, which is the one thing the lateral phase
			-- exists to postpone: it stands beside them, not behind them.
			expect(math.abs((at :: Vector3).Z - centre.Z) < 1e-6).to.equal(true)
			expect((at :: Vector3).X > centre.X).to.equal(true)
			-- ...and the mirror.
			local other = ForestTest.beaterPosition(centre, 1, false, ForestTest.WAVE.lateralDz - 1, "RtoL", 0)
			expect((other :: Vector3).X < centre.X).to.equal(true)
		end)

		it("pushes from BEHIND, and stands nowhere at all once the wave is done", function()
			local centre = Vector3.new(0, 5, -600)
			local pushing = ForestTest.beaterPosition(centre, 1, false)
			expect(pushing).to.be.ok()
			expect((pushing :: Vector3).Z > centre.Z).to.equal(true) -- north of them: the drive's side
			expect(ForestTest.beaterPosition(centre, ForestTest.WAVE.pushSeconds, false)).to.equal(nil)
		end)
	end)
end
