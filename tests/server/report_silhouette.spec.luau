-- The drive report's geometry: the silhouette the panel draws, and the dot it puts on it.
--
-- WHY THIS SPEC EXISTS AT ALL. `Report.CONFIG.SILHOUETTE` is five rectangles carried by hand into a
-- SHARED module, because the panel is a client and `Boar` is a server module -- so the one thing that
-- can go wrong is the boar's zone boxes moving and the picture quietly lying about where a shot
-- landed. Every number is recomputed here from `Boar.CONFIG` through `Shape.rectOf`, which is the same
-- projection `Shape.dot` uses for the dots. A zone box that moves fails the harness.
--
-- It is the pattern `MatchBoot`'s arena assertion already uses: a hand-carried constant with a check
-- that fails when its source moves.
--
-- Design: docs/design/drive-report.md (sections 6.2, 8.2)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Report = require(ReplicatedStorage:WaitForChild("Report"))
local Shape = require(ServerScriptService:WaitForChild("HitLog"):WaitForChild("Shape"))

-- The constants are the projection rounded to three decimals, which at the panel's 110-px silhouette
-- is 0.04 of a pixel. The tolerance is that rounding and nothing more.
local TOL = 1e-3

return function()
	describe("the silhouette's rectangles", function()
		it("is Boar.CONFIG.ZONES projected, zone by zone", function()
			local body = Boar.CONFIG.BODY_SIZE
			for _, zone in ipairs(Boar.CONFIG.ZONES.ORDER) do
				local spec = Boar.CONFIG.ZONES[zone]
				local want = Shape.rectOf(spec.size, spec.offset, body)
				local got = Report.CONFIG.SILHOUETTE[zone]
				expect(got).to.be.ok()
				for _, key in ipairs({ "u0", "u1", "v0", "v1" }) do
					if math.abs(got[key] - want[key]) > TOL then
						error(
							string.format(
								"SILHOUETTE.%s.%s is %.4f but Boar.CONFIG.ZONES.%s projects to %.4f",
								zone,
								key,
								got[key],
								zone,
								want[key]
							)
						)
					end
				end
			end
		end)

		it("carries each zone's own tint, so the dot's colour and the box's agree", function()
			for _, zone in ipairs(Boar.CONFIG.ZONES.ORDER) do
				local tint = Report.CONFIG.SILHOUETTE[zone].tint
				local want = Boar.CONFIG.ZONES[zone].tint
				expect(tint.R).to.be.near(want.R, 1 / 255)
				expect(tint.G).to.be.near(want.G, 1 / 255)
				expect(tint.B).to.be.near(want.B, 1 / 255)
			end
		end)

		it("has a rect for every zone the damage model names", function()
			-- `Report.CONFIG.ZONES` is the five the panel draws; four come from zone parts and `body`
			-- is the trunk's own fallback, which is why it is not in `Boar.CONFIG.ZONES.ORDER`.
			for _, zone in ipairs(Report.CONFIG.ZONES) do
				expect(Report.CONFIG.SILHOUETTE[zone]).to.be.ok()
				expect(Boar.CONFIG.WOUND.DAMAGE[zone]).to.be.ok()
			end
			local covering = Report.CONFIG.SILHOUETTE.body
			expect(covering.u0).to.equal(0)
			expect(covering.u1).to.equal(1)
			expect(covering.v0).to.equal(0)
			expect(covering.v1).to.equal(1)
		end)

		it("keeps the four named zones pairwise disjoint, so a dot is in at most one of them", function()
			local named = { "head", "chest", "rear", "legs" }
			for i = 1, #named do
				for j = i + 1, #named do
					local a, b = Report.CONFIG.SILHOUETTE[named[i]], Report.CONFIG.SILHOUETTE[named[j]]
					local overlaps = a.u0 < b.u1 - TOL and b.u0 < a.u1 - TOL and a.v0 < b.v1 - TOL and b.v0 < a.v1 - TOL
					if overlaps then
						error(string.format("%s and %s overlap on the silhouette", named[i], named[j]))
					end
				end
			end
		end)
	end)

	describe("Shape.rectOf", function()
		it("puts the nose at u = 0 and the tail at u = 1", function()
			local body = Vector3.new(2, 3, 5.5)
			local whole = Shape.rectOf(body, Vector3.zero, body)
			expect(whole.u0).to.equal(0)
			expect(whole.u1).to.equal(1)
			expect(whole.v0).to.equal(0)
			expect(whole.v1).to.equal(1)
		end)

		it("clamps a box that stands proud of the trunk, as every zone part does by design", function()
			-- PROTRUSION is the point: a zone part is deliberately outside the trunk so a ray meets it
			-- first, so the projection must survive a box that overhangs.
			local body = Vector3.new(2, 3, 5.5)
			local proud = Shape.rectOf(Vector3.new(2.2, 1, 1), Vector3.new(0, 1.6, -2.9), body)
			expect(proud.u0).to.equal(0)
			expect(proud.v0).to.equal(0)
		end)

		it("measures v downward, so the animal's back is 0 and its belly is 1", function()
			local body = Vector3.new(2, 3, 5.5)
			local back = Shape.rectOf(Vector3.new(1, 1, 1), Vector3.new(0, 1.0, 0), body)
			local belly = Shape.rectOf(Vector3.new(1, 1, 1), Vector3.new(0, -1.0, 0), body)
			expect(back.v1 < belly.v0).to.equal(true)
		end)
	end)

	describe("Shape.dot and the rects together", function()
		it("lands a nose-on impact inside the head's own rectangle", function()
			-- The trunk at the origin, facing -Z, and a point on the drawn skull (`Boar.CONFIG.ZONES`
			-- measures the head at z -2.81..-1.45, y 0.35..1.65).
			local body = Boar.CONFIG.BODY_SIZE
			local cframe = CFrame.new(0, 0, 0)
			local u, v = Shape.dot(cframe, body, Vector3.new(0.3, 0.9, -2.2))
			local head = Report.CONFIG.SILHOUETTE.head
			expect(u >= head.u0 - TOL and u <= head.u1 + TOL).to.equal(true)
			expect(v >= head.v0 - TOL and v <= head.v1 + TOL).to.equal(true)
		end)

		it("lands a rump impact inside the rear's rectangle, and reports the flank it came in on", function()
			local body = Boar.CONFIG.BODY_SIZE
			local u, _, side = Shape.dot(CFrame.new(0, 0, 0), body, Vector3.new(-0.9, 0.7, 1.9))
			local rear = Report.CONFIG.SILHOUETTE.rear
			expect(u >= rear.u0 - TOL and u <= rear.u1 + TOL).to.equal(true)
			expect(side).to.equal(-1)
		end)

		it("is the same (u, v) on a cub as on a male, because it divides by the box it was handed", function()
			local male = Boar.CONFIG.BODY_SIZE
			local cub = male * 0.6
			local mu, mv = Shape.dot(CFrame.new(0, 0, 0), male, Vector3.new(0, 0.6, -1.65))
			local cu, cv = Shape.dot(CFrame.new(0, 0, 0), cub, Vector3.new(0, 0.36, -0.99))
			expect(cu).to.be.near(mu, 1e-6)
			expect(cv).to.be.near(mv, 1e-6)
		end)
	end)

	describe("Report.metres", function()
		it("turns studs into the metres a hunter reads", function()
			expect(Report.metres(0)).to.equal(0)
			expect(Report.metres(nil)).to.equal(0)
			expect(Report.metres(100)).to.equal(28)
		end)
	end)
end
