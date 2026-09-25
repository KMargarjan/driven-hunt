-- weapon_shot.spec: the pure request validation, the pellet pattern and the safety arc. Every
-- number is a literal here, not an import from CONFIG, so a config that drifts from the design is
-- a finding. The spread assertion is Buck only, over a fixed seed and 1000 shots, as max and mean
-- bounds -- defect (f) of the Task 23 review was a single-draw assertion that was ~25% flaky for a
-- Slug, which fires one pellet.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/shotgun.md (sections 5.3, 13.1)
local ServerScriptService = game:GetService("ServerScriptService")

local Weapon = require(ServerScriptService:WaitForChild("Weapon"))

local Validator = Weapon.Validator
local Pattern = Weapon.Pattern
local SafetyArc = Weapon.SafetyArc
local Hits = Weapon.Hits

-- The spec's own config, written out: a pure function is driven by data, so the data is the spec's.
local CONFIG = {
	PELLETS = { Slug = 1, Buck = 9 },
	SPREAD_FULL_DEG = { Slug = 0.16, Buck = 1.6 },
	CAMERA_ORIGIN_TOLERANCE = 30,
	DIR_UNIT_TOLERANCE = 1e-3,
}

local function angleDeg(a: Vector3, b: Vector3): number
	return math.deg(math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1)))
end

return function()
	describe("shot validation", function()
		local root = Vector3.new(0, 5, 0)

		it("accepts a camera ray from behind the character", function()
			local ok = Validator.checkShot(
				{ origin = Vector3.new(0, 10, 20), direction = Vector3.new(0, 0, -1) },
				root,
				CONFIG
			)
			expect(ok).to.equal(true)
		end)

		it("rejects a dead shooter, bad types, NaN, a non-unit direction and an absurd origin", function()
			expect(select(2, Validator.checkShot({ origin = root, direction = Vector3.xAxis }, nil, CONFIG))).to.equal(
				"not-alive"
			)
			expect(select(2, Validator.checkShot("nope", root, CONFIG))).to.equal("bad-type")
			expect(select(2, Validator.checkShot({ origin = "x", direction = Vector3.xAxis }, root, CONFIG))).to.equal(
				"bad-type"
			)
			local nan = Vector3.new(0 / 0, 0, 0)
			expect(select(2, Validator.checkShot({ origin = nan, direction = Vector3.xAxis }, root, CONFIG))).to.equal(
				"nan"
			)
			expect(select(2, Validator.checkShot({ origin = root, direction = Vector3.new(0, 0, -2) }, root, CONFIG))).to.equal(
				"not-unit"
			)
			expect(
				select(
					2,
					Validator.checkShot({ origin = Vector3.new(0, 5, 60), direction = Vector3.xAxis }, root, CONFIG)
				)
			).to.equal("origin-far")
		end)
	end)

	describe("request validation", function()
		it("accepts only Reload and SelectAmmo, so no reducer primitive is reachable", function()
			expect(Validator.checkRequest("Reload", nil)).to.equal(true)
			expect(Validator.checkRequest("SelectAmmo", "Slug")).to.equal(true)
			expect(Validator.checkRequest("SelectAmmo", "Buck")).to.equal(true)
			-- Defect (d), written out so a later ActionKind cannot leak in unnoticed.
			for _, bad in ipairs({ "Break", "Load", "Close", "Fire", "", "reload", 42 }) do
				expect(Validator.checkRequest(bad, nil)).to.equal(false)
			end
			expect(Validator.checkRequest(nil, nil)).to.equal(false)
			expect(Validator.checkRequest({}, nil)).to.equal(false)
			expect(Validator.checkRequest("SelectAmmo", "Grenade")).to.equal(false)
			expect(Validator.checkRequest("Reload", "Slug")).to.equal(false)
			expect(select(2, Validator.checkRequest("Break", nil))).to.equal("bad-request")
		end)
	end)

	describe("pellet pattern", function()
		local aim = Vector3.new(0, 0, -1)

		it("fires one slug and nine pellets, all unit vectors", function()
			local slug = Pattern.directions("Slug", aim, Random.new(1337), CONFIG)
			local buck = Pattern.directions("Buck", aim, Random.new(1337), CONFIG)
			expect(#slug).to.equal(1)
			expect(#buck).to.equal(9)
			for _, direction in ipairs(buck) do
				expect(math.abs(direction.Magnitude - 1) < 1e-6).to.equal(true)
			end
		end)

		it("keeps buckshot inside a 1.6 degree FULL cone, and actually spreads", function()
			local rng = Random.new(1337) -- a fixture: nothing here depends on a single draw
			local maximum, total, count = 0, 0, 0
			for _ = 1, 1000 do
				for _, direction in ipairs(Pattern.directions("Buck", aim, rng, CONFIG)) do
					local deg = angleDeg(direction, aim)
					maximum = math.max(maximum, deg)
					total += deg
					count += 1
				end
			end
			expect(count).to.equal(9000)
			expect(maximum <= 0.8).to.equal(true) -- half of the full cone; a 2x error fails
			expect(maximum > 0.4).to.equal(true) -- and it is not collapsed to a point
			local mean = total / count
			expect(mean > 0.2 and mean < 0.7).to.equal(true)
		end)

		it("keeps a slug inside 0.08 degrees of the aim", function()
			local rng = Random.new(1337)
			for _ = 1, 100 do
				local direction = Pattern.directions("Slug", aim, rng, CONFIG)[1]
				expect(angleDeg(direction, aim) <= 0.08).to.equal(true)
			end
		end)

		it("is deterministic for a seed and different for another", function()
			local a = Pattern.directions("Buck", aim, Random.new(42), CONFIG)
			local b = Pattern.directions("Buck", aim, Random.new(42), CONFIG)
			local c = Pattern.directions("Buck", aim, Random.new(43), CONFIG)
			for index = 1, 9 do
				expect((a[index] - b[index]).Magnitude < 1e-9).to.equal(true)
			end
			expect((a[1] - c[1]).Magnitude > 1e-9).to.equal(true)
		end)

		it("errors on a zero aim rather than inventing a direction", function()
			expect(function()
				Pattern.directions("Buck", Vector3.zero, Random.new(1), CONFIG)
			end).to.throw()
		end)
	end)

	describe("safety arc", function()
		local line = { position = Vector3.zero, normal = Vector3.new(0, 0, -1) }

		it("forbids straight down the normal, allows 90 degrees away, and includes the boundary", function()
			expect(SafetyArc.isForbidden(Vector3.new(0, 0, -1), line, 45)).to.equal(true)
			expect(SafetyArc.isForbidden(Vector3.new(1, 0, 0), line, 45)).to.equal(false)
			expect(SafetyArc.isForbidden(Vector3.new(0, 0, 1), line, 45)).to.equal(false)
			local boundary = Vector3.new(math.sin(math.rad(45)), 0, -math.cos(math.rad(45)))
			expect(SafetyArc.isForbidden(boundary, line, 45)).to.equal(true)
			expect(SafetyArc.isForbidden(Vector3.new(math.sin(math.rad(46)), 0, -math.cos(math.rad(46))), line, 45)).to.equal(
				false
			)
		end)
	end)

	describe("shot cost", function()
		it("patterns and groups 1000 shots in under 500 ms", function()
			local rng = Random.new(7)
			local aim = Vector3.new(0, 0, -1)
			-- A real target: with instance = nil, targetOf returns on its first check and `group`
			-- does nothing, so the budget measured only Pattern.directions (round 1 note).
			local target = Instance.new("Part")
			target:SetAttribute("Damageable", true)
			target:SetAttribute("HitZone", "body")
			local started = os.clock()
			for _ = 1, 1000 do
				local directions = Pattern.directions("Buck", aim, rng, CONFIG)
				local impacts = {}
				for index, direction in ipairs(directions) do
					impacts[index] = {
						instance = target,
						position = direction * 10,
						normal = direction,
						distance = 10,
					}
				end
				local reports = Hits.group(nil :: any, impacts, "Buck", 0)
				expect(#reports).to.equal(1)
			end
			local elapsed = os.clock() - started
			target:Destroy()
			expect(elapsed < 0.5).to.equal(true)
		end)
	end)
end
