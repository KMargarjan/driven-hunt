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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
local CONFIG = Boar.CONFIG

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
	-- Half of `PROTRUSION`: above float noise on a 20-stud cast by three orders of magnitude, and
	-- below the smallest clearance any zone part is built with.
	local CLEARANCE_FLOOR = CONFIG.ZONES.PROTRUSION / 2

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
				return nil, nil, 0
			end
			local _, zone = Weapon.Hits.targetOf(result.Instance)

			-- ...AND BY HOW FAR IT BEAT THE TRUNK (review round 2, finding 1). A zone part FLUSH with
			-- the trunk's own surface is not a zone, it is a coin toss: two coincident faces at the
			-- same ray distance, and which one `Raycast` returns is the engine's business. The first
			-- `rear` row was 2.0 wide -- exactly the trunk's own +-1.0 -- so two of the three new ray
			-- assertions passed on that tie and a flank shot into the rump could be charged to
			-- `body`. The same ray is cast again with every child of the trunk taken out, so the
			-- clearance is a MEASURED distance and the cases below can insist on it.
			local bare = RaycastParams.new()
			bare.FilterType = Enum.RaycastFilterType.Exclude
			bare.FilterDescendantsInstances = trunk:GetChildren()
			local behind = Workspace:Raycast(origin, -offset * 2, bare)
			local clearance = math.huge -- the trunk is not on this ray at all: nothing to tie with
			if behind and behind.Instance == trunk then
				clearance = behind.Distance - result.Distance
			end
			return zone, result.Instance, clearance
		end

		-- A ZONE PART IS MET FIRST, BY GEOMETRY. Every "reachable by a real ray" case goes through
		-- this: the zone must be the answer AND must stand clear of the trunk, so a part that is
		-- merely flush fails instead of passing on a tie.
		local function metFirst(localPoint: Vector3, fromDirection: Vector3, distance: number, want: string)
			local zone, _, clearance = zoneAt(localPoint, fromDirection, distance)
			expect(zone).to.equal(want)
			-- `PROTRUSION` is 0.06 and float noise on a 20-stud cast is parts in 1e-5, so half the
			-- protrusion is far above the noise and far below any real clearance.
			expect(clearance > CLEARANCE_FLOOR).to.equal(true)
			return clearance
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

		it("is one trunk and one zone part per declared zone, and the folder still holds ONE part", function()
			local parts = {}
			for _, child in ipairs(trunk:GetChildren()) do
				if child:IsA("BasePart") then
					table.insert(parts, child.Name)
				end
			end
			table.sort(parts)
			-- COUNTED FROM THE TABLE, not from a literal (task 116 added `rear` and this said 3).
			-- `buildZones` builds whatever `ZONES.ORDER` lists, so that is what this asserts.
			expect(#parts).to.equal(#CONFIG.ZONES.ORDER)
			expect(table.concat(parts, ",")).to.equal("ZoneChest,ZoneHead,ZoneLegs,ZoneRear")

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
			metFirst(Vector3.new(0, 0.5, -3.5), Vector3.new(0, 0, -1), 20, "head")
			metFirst(Vector3.new(0, 0.5, -3.2), Vector3.new(1, 0, 0), 20, "head")
			metFirst(Vector3.new(0, 0.5, -3.2), Vector3.new(-1, 0, 0), 20, "head")
			metFirst(Vector3.new(0, 1.0, -3.2), Vector3.new(0, 1, 0), 20, "head")
		end)

		it("is reachable by a real ray: chest from both flanks and from above", function()
			metFirst(Vector3.new(0, 0.55, -1.6), Vector3.new(1, 0, 0), 20, "chest")
			metFirst(Vector3.new(0, 0.55, -1.6), Vector3.new(-1, 0, 0), 20, "chest")
			metFirst(Vector3.new(0, 1.5, -1.6), Vector3.new(0, 1, 0), 20, "chest")
		end)

		it("is reachable by a real ray: legs low on a flank and at the rear", function()
			expect((zoneAt(Vector3.new(0, -1.0, 0.15), Vector3.new(1, 0, 0), 20))).to.equal("legs")
			metFirst(Vector3.new(0, -1.0, 2.8), Vector3.new(0, 0, 1), 20, "legs")
		end)

		it("is reachable by a real ray: the hindquarters, from behind, both flanks and above", function()
			-- TASK 116. The spine shot Karen asked for ("can be hit to back part start to do circles
			-- with first legs on") needed a zone, and a zone is only real if a ray finds it FIRST --
			-- not if it ties with the trunk, which is what the first version of the row did on both
			-- flanks (review round 2, finding 1). `metFirst` measures the clearance, so each of these
			-- now fails if the box is merely flush.
			--
			-- The box spans x +-1.06, y -0.30..+1.56 and z +1.1..+2.9: the upper rump, above the hams
			-- and behind the chest, proud by `PROTRUSION` on both flanks and on top and by 0.15 at
			-- the back.
			local back = metFirst(Vector3.new(0, 0.5, 2.8), Vector3.new(0, 0, 1), 20, "rear")
			local flank = metFirst(Vector3.new(0, 0.5, 2.0), Vector3.new(1, 0, 0), 20, "rear")
			metFirst(Vector3.new(0, 0.5, 2.0), Vector3.new(-1, 0, 0), 20, "rear")
			metFirst(Vector3.new(0, 1.4, 2.0), Vector3.new(0, 1, 0), 20, "rear")
			-- The two numbers the row is built on, read off the geometry rather than trusted.
			expect(math.abs(flank - CONFIG.ZONES.PROTRUSION) < 1e-3).to.equal(true)
			expect(math.abs(back - 0.15) < 1e-3).to.equal(true)
			TestKit.note(
				string.format("boar-zones: rear clears the trunk by %.3f on a flank, %.3f at the back", flank, back)
			)
		end)

		it("leaves the rump's FLOOR to the legs, with clear air between them", function()
			-- The one face the rear box is deliberately NOT proud of. `legs` tops out at y -0.5 and
			-- `rear` starts at -0.3, so there is 0.2 of trunk between them: two zone parts meeting at
			-- one surface would be the same tie this round removed.
			local rear = CONFIG.ZONES.rear
			local legs = CONFIG.ZONES.legs
			local rearFloor = rear.offset.Y - rear.size.Y / 2
			local legsCeiling = legs.offset.Y + legs.size.Y / 2
			expect(rearFloor > legsCeiling).to.equal(true)
			-- ...and a ray into that band finds the trunk, which is the `body` zone.
			expect((zoneAt(Vector3.new(0, (rearFloor + legsCeiling) / 2, 2.0), Vector3.new(1, 0, 0), 20))).to.equal(
				"body"
			)
		end)

		it("is the plain BODY everywhere no zone part covers", function()
			-- Mid-flank behind the chest from both sides, and the rear ABOVE the hams: the places
			-- Karen's "belly, flank, rear" has to mean the trunk. Design section 12.3 also asks for
			-- "the belly from below behind the legs band"; there is no such place, because ZoneLegs
			-- spans the boar's whole length (z -2.55..2.85) and covers the entire underside. Seen
			-- from below, a boar is all legs -- which is the right answer for a low shot, and the
			-- deviation is reported rather than quietly dropped.
			-- MOVED FORWARD BY TASK 116, and the move IS the point: `rear` now covers z +1.1..+2.9,
			-- so the two old flank probes at z 1.5 and the rear one at z 2.7 are the hindquarters
			-- now and are asserted as such above. What is still the trunk is the waist -- behind the
			-- chest box (which ends at z -0.75), in front of the rear box, above the legs band.
			expect((zoneAt(Vector3.new(0, 0.6, 0.2), Vector3.new(1, 0, 0), 20))).to.equal("body")
			expect((zoneAt(Vector3.new(0, 0.6, 0.2), Vector3.new(-1, 0, 0), 20))).to.equal("body")
			-- ...and the band between the rump and the hams, which round 2 left to the trunk on
			-- purpose (see "leaves the rump's FLOOR to the legs"). The top of the rump is NOT here
			-- any more: raising the rear box to +1.56 to clear the trunk made it the rump's.
			expect((zoneAt(Vector3.new(0, -0.4, 2.0), Vector3.new(1, 0, 0), 20))).to.equal("body")
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
