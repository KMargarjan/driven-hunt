-- weapon_hits.spec: target resolution, pellet grouping and the ignore list, with an INJECTED cast
-- so the casts can be counted and their arguments inspected; plus Cast.world against two real
-- parts, which is the only part of this system that needs a world.
-- The ignore-list assertions are defect (a) of the Task 23 review: the seam had no shooter, so
-- "filter out the shooter's character" could not be implemented at all.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/shotgun.md (sections 5.3, 5.5, 13.1)
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Weapon = require(ServerScriptService:WaitForChild("Weapon"))

local Hits = Weapon.Hits
local Cast = Weapon.Cast

return function()
	describe("target resolution", function()
		local folder

		beforeEach(function()
			folder = Instance.new("Folder")
			folder.Name = "WeaponHitsSpec"
			folder.Parent = Workspace
		end)

		afterEach(function()
			folder:Destroy()
		end)

		it("finds a damageable part and reads its zone", function()
			local part = Instance.new("Part")
			part:SetAttribute("Damageable", true)
			part:SetAttribute("HitZone", "body")
			part.Parent = folder
			local target, zone = Hits.targetOf(part)
			expect(target).to.equal(part)
			expect(zone).to.equal("body")
		end)

		it("walks up to the damageable ancestor and falls back through the zones", function()
			local model = Instance.new("Model")
			model:SetAttribute("Damageable", true)
			model:SetAttribute("HitZone", "body")
			model.Parent = folder
			local head = Instance.new("Part")
			head:SetAttribute("HitZone", "head")
			head.Parent = model
			local plain = Instance.new("Part")
			plain.Parent = model

			local target, zone = Hits.targetOf(head)
			expect(target).to.equal(model)
			expect(zone).to.equal("head")

			local _, fallback = Hits.targetOf(plain)
			expect(fallback).to.equal("body") -- the root's zone

			model:SetAttribute("HitZone", nil)
			local _, unknown = Hits.targetOf(plain)
			expect(unknown).to.equal("unknown")
		end)

		it("returns nothing for scenery, so a pellet into a wall is a miss", function()
			local wall = Instance.new("Part")
			wall.Parent = folder
			expect(Hits.targetOf(wall)).to.equal(nil)
			expect(Hits.targetOf(nil)).to.equal(nil)
		end)
	end)

	describe("pellet resolution", function()
		it("casts once per direction and hands every cast the same ignore list", function()
			local calls, seen = 0, {}
			local ignore = { Instance.new("Model") }
			local cast = function(_origin, _direction, given)
				calls += 1
				table.insert(seen, given)
				return nil
			end
			local directions = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }
			Hits.resolve(Vector3.zero, directions, 100, cast, ignore)
			expect(calls).to.equal(3)
			for _, given in ipairs(seen) do
				expect(given).to.equal(ignore) -- the same table, unmodified
				expect(#given).to.equal(1)
			end
		end)
	end)

	describe("hit grouping", function()
		local function impactOn(instance, distance, position)
			return {
				instance = instance,
				position = position or Vector3.new(0, 0, distance),
				normal = Vector3.yAxis,
				distance = distance,
			}
		end

		it("makes one report per target, not one per pellet", function()
			local boar = Instance.new("Part")
			boar:SetAttribute("Damageable", true)
			boar:SetAttribute("HitZone", "body")
			local impacts = {}
			for index = 1, 9 do
				impacts[index] = impactOn(boar, 10 + index)
			end
			local reports = Hits.group(nil :: any, impacts, "Buck", 5)
			expect(#reports).to.equal(1)
			expect(reports[1].pellets).to.equal(9)
			expect(reports[1].zone).to.equal("body")
			expect(reports[1].zones.body).to.equal(9)
			expect(reports[1].nearest).to.equal(11)
			expect(reports[1].ammo).to.equal("Buck")
			expect(reports[1].at).to.equal(5)
			boar:Destroy()
		end)

		it("splits pellets across two targets", function()
			local a, b = Instance.new("Part"), Instance.new("Part")
			a:SetAttribute("Damageable", true)
			b:SetAttribute("Damageable", true)
			local reports = Hits.group(nil :: any, {
				impactOn(a, 10),
				impactOn(b, 20),
				impactOn(a, 30),
			}, "Buck", 0)
			expect(#reports).to.equal(2)
			local total = reports[1].pellets + reports[2].pellets
			expect(total).to.equal(3)
			a:Destroy()
			b:Destroy()
		end)

		it("breaks a zone tie with the nearest impact", function()
			local model = Instance.new("Model")
			model:SetAttribute("Damageable", true)
			local head = Instance.new("Part")
			head:SetAttribute("HitZone", "head")
			head.Parent = model
			local body = Instance.new("Part")
			body:SetAttribute("HitZone", "body")
			body.Parent = model

			local reports = Hits.group(nil :: any, { impactOn(body, 20), impactOn(head, 10) }, "Slug", 0)
			expect(#reports).to.equal(1)
			expect(reports[1].zones.head).to.equal(1)
			expect(reports[1].zones.body).to.equal(1)
			expect(reports[1].zone).to.equal("head") -- the nearer one
			model:Destroy()
		end)
	end)

	describe("the real cast", function()
		local folder, target

		beforeEach(function()
			folder = Instance.new("Folder")
			folder.Name = "WeaponCastSpec"
			folder.Parent = Workspace
			target = Instance.new("Part")
			target.Name = "CastTarget"
			target.Size = Vector3.new(4, 4, 4)
			target.Position = Vector3.new(0, 500, 0)
			target.Anchored = true
			target.Parent = folder
		end)

		afterEach(function()
			folder:Destroy()
		end)

		it("hits a part in the ray's path at the arithmetic distance", function()
			local origin = Vector3.new(0, 500, 20)
			local impact = Cast.world(origin, Vector3.new(0, 0, -40), {})
			expect(impact).to.be.ok()
			expect(impact.instance).to.equal(target)
			expect(math.abs(impact.distance - 18) < 0.05).to.equal(true) -- 20 studs minus half of 4
		end)

		it("misses the same part when it is in the ignore list", function()
			local origin = Vector3.new(0, 500, 20)
			expect(Cast.world(origin, Vector3.new(0, 0, -40), { target })).to.equal(nil)
			expect(Cast.world(origin, Vector3.new(0, 0, -40), { folder })).to.equal(nil)
		end)
	end)
end
