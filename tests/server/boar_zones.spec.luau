-- boar_zones.spec: the hit-zone geometry, proved with REAL RAYS against a real boar.
--
-- This is the spec that makes the trap in hit-zones design section 4.1 impossible. A raycast returns
-- the nearest surface, so zone parts NESTED inside the trunk would never be hit: every shot would
-- report `body`, while a spec that called takeHit with zone = "head" directly would pass happily. A
-- green test and a game in which no player can ever land a head shot is exactly the failure this
-- project exists to avoid (docs/PROJECT_CONTEXT.md, "the harness was wrong as often as the game").
-- So every zone here is reached the way the weapon reaches it: cast a ray from outside the boar and
-- read the HitZone attribute of whatever the engine returns.
--
-- It builds its own world at y = 500, the pattern tests/server/boar_body.spec.luau uses, so
-- production's boar is untouched.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/hit-zones.md (sections 4, 12.3)
-- Note:   docs/research/2026-09-25-hit-zones.md (sources A and B)
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))

local GROUND_Y = 500
local FIELD = {
	bounds = { minX = -55, maxX = 55, minZ = -55, maxZ = 55 },
	exitZ = -40,
	groundY = GROUND_Y,
}

local function waitUntil(timeout: number, predicate: () -> boolean): boolean
	local started = os.clock()
	while os.clock() - started < timeout do
		if predicate() then
			return true
		end
		task.wait()
	end
	return predicate()
end

return function()
	describe("the boar's hit zones", function()
		local testRoot, runtime, handle, trunk, disconnect

		local function zonePart(name: string): BasePart?
			local found = trunk:FindFirstChild(name)
			return if found and found:IsA("BasePart") then found else nil
		end

		-- Fires a ray AT a point given in the boar's own frame, coming FROM `distance` studs away in
		-- the boar-local direction `fromDirection` (-Z is the boar's front, +Y is up). Returns the
		-- HitZone of whatever the engine returns first -- read through the weapon's own targetOf, so
		-- this is the zone a real pellet would report. Working in the boar's frame is what makes the
		-- test independent of which way it happens to be facing; nothing yields between reading the
		-- CFrame and casting, so a wandering boar cannot move underneath the ray.
		local function zoneAt(localPoint: Vector3, fromDirection: Vector3, distance: number): (string?, Instance?)
			local cf = trunk.CFrame
			local target = cf:PointToWorldSpace(localPoint)
			local offset = cf:VectorToWorldSpace(fromDirection.Unit) * distance
			local origin = target + offset

			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { trunk } -- the boar and its zone parts, nothing else
			local result = Workspace:Raycast(origin, -offset * 2, params)
			if not result then
				return nil, nil
			end
			local _, zone = Weapon.Hits.targetOf(result.Instance)
			return zone, result.Instance
		end

		beforeAll(function()
			testRoot = Instance.new("Folder")
			testRoot.Name = "BoarZonesSpec"
			local plate = Instance.new("Part")
			plate.Name = "Plate"
			plate.Size = Vector3.new(120, 4, 120)
			plate.Position = Vector3.new(0, GROUND_Y - 2, 0)
			plate.Anchored = true
			plate.Parent = testRoot
			testRoot.Parent = Workspace

			runtime = Boar.newRuntime({
				field = FIELD,
				parent = testRoot,
				folderName = "Boars",
				rng = Random.new(3),
				threats = function()
					return {}
				end,
				probe = function()
					return false
				end,
				requestPath = function(_id, _from, _to, done)
					done(nil)
				end,
				releasePath = function() end,
			})
			handle = runtime:spawn(Vector3.new(0, GROUND_Y, 20))
			trunk = handle.part
			disconnect = runtime:run()
		end)

		afterAll(function()
			if disconnect then
				disconnect()
			end
			runtime:destroy()
			testRoot:Destroy()
		end)

		it("is one trunk and three zone parts, and the folder still holds ONE part", function()
			local parts = {}
			for _, child in ipairs(trunk:GetChildren()) do
				if child:IsA("BasePart") then
					table.insert(parts, child.Name)
				end
			end
			table.sort(parts)
			expect(#parts).to.equal(3)
			expect(table.concat(parts, ",")).to.equal("ZoneChest,ZoneHead,ZoneLegs")

			-- The zone parts are children of the TRUNK, not of the runtime's folder, so the count
			-- boar_body.spec asserts is unchanged. Written down because a green suite going red for
			-- a reason unrelated to the change is the expensive kind of surprise.
			local topLevel = 0
			for _, child in ipairs(runtime:folder():GetChildren()) do
				if child:IsA("BasePart") then
					topLevel += 1
				end
			end
			expect(topLevel).to.equal(1)
		end)

		it("puts Damageable on the trunk alone, and a HitZone on every part", function()
			expect(trunk:GetAttribute("Damageable")).to.equal(true)
			expect(trunk:GetAttribute("HitZone")).to.equal("body")

			for zone, name in pairs({ head = "ZoneHead", chest = "ZoneChest", legs = "ZoneLegs" }) do
				local part = zonePart(name)
				expect(part).to.be.ok()
				expect(part:GetAttribute("HitZone")).to.equal(zone)
				-- Two damageable instances in one ancestor chain is an ambiguity, not a feature.
				expect(part:GetAttribute("Damageable") == nil).to.equal(true)
			end
		end)

		it("welds them massless, queryable and non-colliding", function()
			for _, name in ipairs({ "ZoneHead", "ZoneChest", "ZoneLegs" }) do
				local part = zonePart(name)
				expect(part.Massless).to.equal(true) -- the assembly's mass and inertia are unchanged
				expect(part.CanCollide).to.equal(false) -- the collision body is still the plain box
				expect(part.CanQuery).to.equal(true) -- being raycastable is its entire purpose
				expect(part.Anchored).to.equal(false) -- an anchored weld would anchor the whole boar
				local weld = part:FindFirstChildOfClass("WeldConstraint")
				expect(weld).to.be.ok()
				expect(weld.Part0).to.equal(trunk)
				expect(weld.Part1).to.equal(part)
			end
		end)

		it("resolves through the ancestor walk to the trunk, which is what takeHit is given", function()
			for _, name in ipairs({ "ZoneHead", "ZoneChest", "ZoneLegs" }) do
				local target, zone = Weapon.Hits.targetOf(zonePart(name))
				expect(target).to.equal(trunk)
				expect(zone).to.equal(zonePart(name):GetAttribute("HitZone"))
			end
		end)

		-- THE ASSERTION THAT MATTERS. Twelve directions, every one of them a real ray from outside
		-- the boar (the design asks for nine at least). Shrink a zone part back inside the trunk and
		-- these go red.
		it("is reachable by a real ray: head from the front, both sides and above", function()
			-- -Z is the boar's front.
			expect((zoneAt(Vector3.new(0, 0.5, -3.5), Vector3.new(0, 0, -1), 20))).to.equal("head")
			expect((zoneAt(Vector3.new(0, 0.5, -3.2), Vector3.new(1, 0, 0), 20))).to.equal("head")
			expect((zoneAt(Vector3.new(0, 0.5, -3.2), Vector3.new(-1, 0, 0), 20))).to.equal("head")
			expect((zoneAt(Vector3.new(0, 1.0, -3.2), Vector3.new(0, 1, 0), 20))).to.equal("head")
		end)

		it("is reachable by a real ray: chest from both flanks and from above", function()
			expect((zoneAt(Vector3.new(0, 0.55, -1.6), Vector3.new(1, 0, 0), 20))).to.equal("chest")
			expect((zoneAt(Vector3.new(0, 0.55, -1.6), Vector3.new(-1, 0, 0), 20))).to.equal("chest")
			expect((zoneAt(Vector3.new(0, 1.5, -1.6), Vector3.new(0, 1, 0), 20))).to.equal("chest")
		end)

		it("is reachable by a real ray: legs low on a flank and at the rear", function()
			expect((zoneAt(Vector3.new(0, -1.0, 0.15), Vector3.new(1, 0, 0), 20))).to.equal("legs")
			expect((zoneAt(Vector3.new(0, -1.0, 2.8), Vector3.new(0, 0, 1), 20))).to.equal("legs")
		end)

		it("is the plain BODY everywhere no zone part covers", function()
			-- Mid-flank behind the chest from both sides, and the rear ABOVE the hams: the places
			-- Karen's "belly, flank, rear" has to mean the trunk. Design section 12.3 also asks for
			-- "the belly from below behind the legs band"; there is no such place, because ZoneLegs
			-- spans the boar's whole length (z -2.55..2.85) and covers the entire underside. Seen
			-- from below, a boar is all legs -- which is the right answer for a low shot, and the
			-- deviation is reported rather than quietly dropped.
			expect((zoneAt(Vector3.new(0, 0.6, 1.5), Vector3.new(1, 0, 0), 20))).to.equal("body")
			expect((zoneAt(Vector3.new(0, 0.6, 1.5), Vector3.new(-1, 0, 0), 20))).to.equal("body")
			expect((zoneAt(Vector3.new(0, 0.9, 2.7), Vector3.new(0, 0, 1), 20))).to.equal("body")
		end)

		it("still drives, upright, with the server owning the whole assembly", function()
			-- The zone parts did not tip it, anchor it, or take the assembly root away from the
			-- trunk: Massless parts never win that election (docs/physics/assemblies).
			-- An idle boar grazes for up to GRAZE_MAX seconds at a time, so this waits rather than
			-- sampling once.
			expect(waitUntil(10, function()
				return trunk.AssemblyLinearVelocity.Magnitude > 1
			end)).to.equal(true)
			expect(trunk.CFrame.UpVector.Y > 0.9).to.equal(true)
			expect(trunk:GetNetworkOwner()).to.equal(nil)
			expect(trunk.AssemblyRootPart).to.equal(trunk)
		end)
	end)
end
