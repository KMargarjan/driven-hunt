--!strict
-- TreeGround: which trees move, and by how much.
--
-- THE WHOLE POINT OF THE MODULE IS THAT THIS SPEC NEEDS NO WORLD. Task 196 spent rounds on the
-- lobby's floating trees because the arithmetic and the raycasting were one lump of code: nothing
-- could be asserted without building a forest, so nothing was. Here the caller measures (the part
-- only the world can answer) and these functions decide, so every decision is a table of numbers
-- and an expected answer.
--
-- EVERY CASE BUILDS ITS OWN TABLES. Nothing is installed and nothing is restored.
--
-- The numbers that appear as "the live forest" below are from `tools/forest_ground.py plan` on
-- place 130094961655666, 2026-10-17, and they are here so a change to a constant has to argue with
-- a measured tree rather than only with itself.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TreeGround = require(ReplicatedStorage:WaitForChild("TreeGround"))

local function box(minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number)
	return { minX = minX, minY = minY, minZ = minZ, maxX = maxX, maxY = maxY, maxZ = maxZ }
end

return function()
	describe("bounds", function()
		it("unions the boxes it is given", function()
			local out = TreeGround.bounds({ box(0, 10, 0, 2, 70, 2), box(-9, 40, -8, 11, 75, 12) })
			expect(out).to.be.ok()
			local b = out :: any
			expect(b.minX).to.equal(-9)
			expect(b.minY).to.equal(10)
			expect(b.maxY).to.equal(75)
			expect(b.maxZ).to.equal(12)
		end)

		it("answers nil for nothing, instead of a zero box at the origin", function()
			expect(TreeGround.bounds({})).to.equal(nil)
		end)
	end)

	describe("groundReaching", function()
		it("keeps the trunk and throws the canopy away", function()
			-- A birch: a trunk from the model's foot, and leaves whose own bottom is 9 studs up.
			local whole = box(-12, 100, -12, 12, 175, 12)
			local kept = TreeGround.groundReaching({
				box(-2, 100, -2, 2, 163, 2), -- trunk, at the foot
				box(-12, 109, -12, 12, 175, 12), -- leaves, well above it
			}, whole)
			expect(#kept).to.equal(1)
			expect(kept[1]).to.equal(1)
		end)

		it("uses a floor in studs, so a 2.8-stud fern gets a usable band", function()
			-- 0.02 of 2.8 studs is 0.056: a single mesh whose box starts 0.1 above the model's own
			-- lowest point would be excluded, and the fern would have no footprint at all.
			expect(TreeGround.groundBand(2.8)).to.equal(0.5)
			expect(TreeGround.groundBand(75)).to.equal(1.5)
		end)
	end)

	describe("flareFootprint", function()
		it("leaves a narrow trunk exactly as it is", function()
			-- The lobby's birch: a 3.7-stud trunk on a 74-stud tree. The clamp is 5.92 each side,
			-- so a trunk that narrow comes back untouched. NOTE: `Lobby.Build` does not call this
			-- at all -- its footprint is already the union of the parts that reach the ground, and
			-- applying the clamp there measurably changed how deep its trees sit (`lobby.spec`'s
			-- own claw case caught it). This asserts the function, not the lobby.
			local trunk = box(100, 50, 200, 103.7, 124, 203.7)
			local out = TreeGround.flareFootprint(trunk, 74)
			expect(out.minX).to.equal(100)
			expect(out.maxX).to.equal(103.7)
			expect(out.minZ).to.equal(200)
			expect(out.maxZ).to.equal(203.7)
		end)

		it("clamps a trunk mesh that is really the whole lower tree", function()
			-- `LarchTree_Var02`: a "Trunk" part 15.6 studs across on a 30.6-stud tree. Sampling to
			-- its corners read the ground seven studs away and down a bank, which made nineteen
			-- larches look like cliff edges and left every one of them floating thirty studs up.
			local out = TreeGround.flareFootprint(box(0, 0, 0, 15.6, 30.6, 15.6), 30.6)
			expect(out.maxX - out.minX).to.be.near(4.9, 0.01) -- 2 x max(0.08 * 30.6, 2.0)
			expect((out.minX + out.maxX) / 2).to.be.near(7.8, 1e-6) -- about its own centre
			expect(out.minY).to.equal(0) -- it never touches the vertical extent
			expect(out.maxY).to.equal(30.6)
		end)

		it("never grows a footprint", function()
			local out = TreeGround.flareFootprint(box(0, 0, 0, 1, 100, 1), 100)
			expect(out.maxX - out.minX).to.equal(1)
		end)
	end)

	describe("samples", function()
		it("puts the outermost samples on the footprint's own edges", function()
			local points = TreeGround.samples(10, 20, 14, 26, 4)
			expect(#points).to.equal(25)
			local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
			for _, p in ipairs(points) do
				minX, maxX = math.min(minX, p.x), math.max(maxX, p.x)
				minZ, maxZ = math.min(minZ, p.z), math.max(maxZ, p.z)
			end
			expect(minX).to.equal(10)
			expect(maxX).to.equal(14)
			expect(minZ).to.equal(20)
			expect(maxZ).to.equal(26)
		end)
	end)

	describe("junctionY", function()
		it("is a fraction of the model's height above its lowest point", function()
			-- `SilverBirch_Var11_LOD_0` in the live forest: 74.8 studs tall, claw fraction 0.0425,
			-- so 3.18 studs of arched claws under the trunk.
			expect(TreeGround.junctionY(100, 174.8, 0.0425)).to.be.near(103.18, 0.01)
		end)

		it("is the model's own bottom when there are no claws", function()
			expect(TreeGround.junctionY(100, 174.8, 0)).to.equal(100)
		end)
	end)

	describe("liftTo", function()
		it("drops until no contact is in the air -- the LOWEST ground wins", function()
			local lift = TreeGround.liftTo({
				{ ground = 100, bottom = 105 },
				{ ground = 98, bottom = 105 }, -- the low side decides
				{ ground = 103, bottom = 105 },
			}, 0.6)
			expect(lift).to.be.near(-7.6, 1e-9) -- 98 - 105 - 0.6
		end)

		it("answers nil for no contacts rather than moving a tree to the origin", function()
			expect(TreeGround.liftTo({}, 0.6)).to.equal(nil)
		end)
	end)

	describe("sinkFor", function()
		it("buries a tree by the lobby's own 0.6 and a fern by a tenth of itself", function()
			expect(TreeGround.sinkFor(74.8)).to.equal(0.6)
			expect(TreeGround.sinkFor(2.8)).to.be.near(0.28, 1e-9)
		end)
	end)

	describe("decide", function()
		it("sinks a floating claw birch so the junction goes under the ground", function()
			-- #2219 in the live forest: `SilverBirch_Var11_LOD_0`, 74.8 tall, ground at 163.4.
			local v = TreeGround.decide(164.5, 239.3, 0.0425, { 163.4, 163.5, 163.6 })
			expect(v.move).to.equal(true)
			expect(v.reason).to.equal("ok")
			expect(v.clawGap).to.be.near(4.28, 0.01) -- 164.5 + 3.18 - 163.4
			expect(v.bottomGap).to.be.near(1.1, 0.01) -- what task 196's own metric sees
			expect(v.lift).to.be.near(-4.88, 0.01) -- the gap plus the 0.6 sink
		end)

		it("leaves a tree that is already seated exactly where it is", function()
			local v = TreeGround.decide(100, 160, 0, { 100.1, 100.4 })
			expect(v.move).to.equal(false)
			expect(v.reason).to.equal("seated")
			expect(v.lift).to.equal(nil)
		end)

		it("never raises a tree that is buried -- that is a different question", function()
			local v = TreeGround.decide(90, 150, 0, { 100, 101 })
			expect(v.move).to.equal(false)
			expect(v.clawGap).to.be.near(-10, 1e-9)
			expect(v.lift).to.equal(nil)
		end)

		it("is on the moving side of the tolerance at 0.3 and not at 0.2", function()
			-- MEASURED FROM ZERO, NOT FROM 100. The first version of this case asked about
			-- `decide(100.2, ..., { 100 })` and failed: `100.2 - 100` is 0.20000000000000284 in a
			-- double, so a tree exactly on the tolerance read as floating. The tolerance is a
			-- judgement about studs of daylight, not about the last bit of a subtraction.
			expect(TreeGround.decide(0.2, 60, 0, { 0 }).move).to.equal(false)
			expect(TreeGround.decide(0.3, 60, 0, { 0 }).move).to.equal(true)
		end)

		it("lists a cliff edge instead of burying the tree in the bank", function()
			local v = TreeGround.decide(120, 180, 0, { 100, 112, 119 })
			expect(v.move).to.equal(false)
			expect(v.reason).to.equal("cliff")
			expect(v.spread).to.equal(19)
			expect(v.lift).to.equal(nil)
		end)

		it("reports no-ground rather than guessing when nothing could be sampled", function()
			local v = TreeGround.decide(100, 160, 0, {})
			expect(v.move).to.equal(false)
			expect(v.reason).to.equal("no-ground")
		end)

		it("would have moved the PRE-fix positions and leaves the post-fix ones alone", function()
			-- LESSON L-028: a check that reads "nothing is floating" on both the old and the new
			-- state is not a check. These are #739's own numbers off the live forest -- a
			-- `SilverBirch_Var06_LOD_0` whose foot sat 2.62 above the ground at 253.5 -- before the
			-- re-seat and after it.
			local before = TreeGround.decide(256.12, 301.52, 0, { 253.5, 253.8 })
			expect(before.move).to.equal(true)
			expect(before.lift).to.be.near(-3.22, 0.01)
			local after = TreeGround.decide(256.12 - 3.22, 301.52 - 3.22, 0, { 253.5, 253.8 })
			expect(after.move).to.equal(false)
			expect(after.clawGap).to.be.near(-0.6, 0.01) -- exactly the sink, under the surface
		end)
	end)

	describe("the caller's own cliff allowance", function()
		it("uses the number it is given, and its own only when it is given none", function()
			-- TASK 326. `CLIFF_STUDS` (4) answers *"would sinking this EXISTING tree bury it?"*. A
			-- PLANTER that has already accepted the spot has a wider number, and until this parameter
			-- existed the two disagreed and `Places.plantOne` left the tree hanging.
			-- THE TREE IS IN THE AIR TO BEGIN WITH (junction 110, lowest ground 100), or `decide` answers
			-- `seated` before it ever reaches the cliff check and the case asserts nothing.
			local grounds = { 100, 101, 102, 103, 105 } -- spread 5
			expect(TreeGround.spread(grounds)).to.equal(5)
			expect(TreeGround.CLIFF_STUDS < 5).to.equal(true)
			expect(TreeGround.decide(110, 180, 0, grounds).reason).to.equal("cliff")
			expect(TreeGround.decide(110, 180, 0, grounds, 7).reason).to.equal("ok")
			expect(TreeGround.decide(110, 180, 0, grounds, 7).move).to.equal(true)
			-- ...AND A NUMBER TIGHTER THAN ITS OWN IS HONOURED TOO, so the parameter is a threshold and
			-- not a way to switch the guard off.
			expect(TreeGround.decide(110, 180, 0, { 100, 102 }, 1).reason).to.equal("cliff")
			expect(TreeGround.decide(110, 180, 0, { 100, 102 }).reason).to.equal("ok")
		end)
	end)
end
