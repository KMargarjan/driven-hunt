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
	describe("the boar's hit zones", function()
		local testRoot, runtime, handle, trunk, disconnect

		-- THE CLEARANCE MEASUREMENT IS GONE WITH THE THING IT MEASURED (task 284), exactly as it
		-- went for the deer in task 280. It read how far a zone part beat the BARE TRUNK by, because
		-- a part merely FLUSH with the trunk is a coin toss (task 116, review round 2) -- and the
		-- boar's trunk is no longer on any bullet's ray at all (`TRUNK_HITTABLE = false`, so it
		-- declares `ZonesOnly` and `Weapon.Cast.world` passes a bullet through it). There is nothing
		-- left to tie with, `ZONES.PROTRUSION` is gone from the config, and every volume is fitted
		-- strictly INSIDE the drawn animal instead.
		local function partsByZone(): { [string]: { BasePart } }
			local found: { [string]: { BasePart } } = {}
			for _, child in ipairs(trunk:GetChildren()) do
				if child:IsA("BasePart") then
					local zone = child:GetAttribute("HitZone")
					if type(zone) == "string" then
						found[zone] = found[zone] or {}
						table.insert(found[zone], child)
					end
				end
			end
			return found
		end

		-- Fires a ray AT a point given in the boar's own frame, from `distance` studs away in the
		-- boar-local direction `fromDirection` (-Z is the front, +Y is up), THROUGH THE BULLET'S OWN
		-- CASTER -- not a bare `Workspace:Raycast`, because since task 284 the caster is also what
		-- steps a bullet past a `ZonesOnly` trunk. `nil` is a MISS, as it is for a pellet.
		local function zoneAt(localPoint: Vector3, fromDirection: Vector3, distance: number): (string?, Instance?)
			local cf = trunk.CFrame
			local target = cf:PointToWorldSpace(localPoint)
			local offset = cf:VectorToWorldSpace(fromDirection.Unit) * distance
			local impact = Weapon.Cast.world(target + offset, -offset * 2, { Workspace.Terrain })
			if not impact then
				return nil, nil
			end
			local hit, zone = Weapon.Hits.targetOf(impact.instance)
			if not hit then
				return nil, impact.instance
			end
			return zone, impact.instance
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

		it("is one part per MEASURED BOX, five zones, and the folder still holds ONE part", function()
			-- COUNTED FROM THE TABLE, never from a literal. Task 284 made every zone several boxes
			-- (fifteen volumes in five zones, fitted to the drawn mesh), so `buildZones` numbers the
			-- parts of a multi-box zone from 1 -- `ZoneChest1`, `ZoneChest2` -- and the old flat list
			-- `"ZoneChest,ZoneHead,ZoneLegs,ZoneRear"` is four names this animal no longer has.
			local geometry = Boar.kindGeometry(nil, CONFIG)
			local expected, names = 0, {}
			for _, zone in ipairs(CONFIG.ZONES.ORDER) do
				local boxes = geometry.zones[zone].boxes
				expected += #boxes
				for index = 1, #boxes do
					table.insert(
						names,
						if #boxes == 1 then geometry.zones[zone].part else geometry.zones[zone].part .. index
					)
				end
			end
			local parts = {}
			for _, child in ipairs(trunk:GetChildren()) do
				if child:IsA("BasePart") then
					table.insert(parts, child.Name)
				end
			end
			table.sort(parts)
			table.sort(names)
			expect(#parts).to.equal(expected)
			expect(table.concat(parts, ",")).to.equal(table.concat(names, ","))
			expect(#CONFIG.ZONES.ORDER).to.equal(5)

			-- The zone parts are children of the TRUNK, not of the runtime's folder, so the count
			-- boar_body.spec asserts is unchanged.
			local topLevel = 0
			for _, child in ipairs(runtime:folder():GetChildren()) do
				if child:IsA("BasePart") then
					topLevel += 1
				end
			end
			expect(topLevel).to.equal(1)
		end)

		it("puts Damageable on the trunk alone, and the trunk itself answers NO zone", function()
			-- WHAT CHANGED (task 284): the trunk used to carry `HitZone = "body"` and was the
			-- fallback zone, so every ray that missed the four boxes -- half of every ray that met
			-- the animal at all -- was a `body` hit in empty air. It declares `ZonesOnly` now.
			expect(trunk:GetAttribute("Damageable")).to.equal(true)
			expect(trunk:GetAttribute("HitZone")).to.equal(nil)
			expect(trunk:GetAttribute("ZonesOnly")).to.equal(true)
			expect(Weapon.Hits.passesThrough(trunk)).to.equal(true)
			expect((Weapon.Hits.targetOf(trunk))).to.equal(nil)

			local found = partsByZone()
			for _, zone in ipairs(CONFIG.ZONES.ORDER) do
				expect(found[zone]).to.be.ok()
				for _, part in ipairs(found[zone]) do
					expect(part:GetAttribute("HitZone")).to.equal(zone)
					-- Two damageable instances in one ancestor chain is an ambiguity, not a feature.
					expect(part:GetAttribute("Damageable") == nil).to.equal(true)
				end
			end
		end)

		it("welds them massless, queryable and non-colliding", function()
			local found = partsByZone()
			for _, zone in ipairs(CONFIG.ZONES.ORDER) do
				for _, part in ipairs(found[zone]) do
					expect(part.Massless).to.equal(true) -- the assembly's mass and inertia are unchanged
					expect(part.CanCollide).to.equal(false) -- the collision body is still the plain box
					expect(part.CanQuery).to.equal(true) -- being raycastable is its entire purpose
					expect(part.Anchored).to.equal(false) -- an anchored weld would anchor the whole boar
					-- A LEGACY `Weld` SINCE TASK 305c: just as rigid, but `C0` is writable, which
					-- is what lets the gait carry the box (`Body.followGait`).
					local weld = part:FindFirstChildOfClass("Weld")
					expect(weld).to.be.ok()
					expect(weld.Part0).to.equal(trunk)
					expect(weld.Part1).to.equal(part)
					expect(part:FindFirstChildOfClass("WeldConstraint")).to.equal(nil)
				end
			end
		end)

		-- TASK 305c. MEASURED in Karen's place at a run: the drawn boar sits 0.14-0.65 studs under
		-- the rest pose the boxes were fitted to, so the drawn nose was inside a zone part on 0 of
		-- 83 frames. These two cases hold the two halves of the fix: every box gets a bone, and a
		-- bone that has moved moves its box by EXACTLY that much and leaves its size alone.
		it("gives every hit box the bone nearest it, or none at all without a visual", function()
			local Body = require(ServerScriptService:WaitForChild("Boar"):WaitForChild("Body"))
			local rows = handle.zoneRows
			expect(type(rows)).to.equal("table")
			expect(#rows).to.equal(#handle.zoneParts)
			for _, row in ipairs(rows) do
				expect(row.weld).to.be.ok()
				expect(typeof(row.offset)).to.equal("Vector3")
			end
			local wired = Body.gaitRig(handle)
			if handle.mesh == nil then
				-- The grey-box world: no rig, and `followGait` must be a no-op rather than an error.
				expect(wired).to.equal(0)
				expect(Body.followGait(handle, 1)).to.equal(0)
			else
				expect(wired).to.equal(#rows)
				for _, row in ipairs(rows) do
					expect(row.bone).to.be.ok()
					expect(row.bone:IsA("Bone")).to.equal(true)
					expect(typeof(row.inBone)).to.equal("CFrame")
				end
			end
		end)

		it("moves a box by its bone's own deformation and never resizes it", function()
			local Body = require(ServerScriptService:WaitForChild("Boar"):WaitForChild("Body"))
			local rows = handle.zoneRows
			local row = rows[1]
			-- A HAND-MADE BONE ON THE TRUNK, so the case runs with or without the bought model:
			-- `followGait` reads `row.bone.TransformedWorldCFrame * row.inBone` and nothing else.
			local bone = Instance.new("Bone")
			bone.Name = "SpecBone"
			bone.CFrame = CFrame.identity
			bone.Parent = trunk
			local wasBone, wasInBone = row.bone, row.inBone
			row.bone = bone
			row.inBone = CFrame.new(row.offset)
			local size = row.part.Size
			-- The bone at its rest place: no shift, so the box keeps its measured offset.
			expect(Body.followGait(handle, 2.5) > 0).to.equal(true)
			expect((row.weld.C0.Position - row.offset).Magnitude < 1e-3).to.equal(true)
			-- Drop the bone half a stud: the box drops half a stud too, and nothing else moves.
			bone.CFrame = CFrame.new(0, -0.5, 0)
			Body.followGait(handle, 2.5)
			local shift = row.weld.C0.Position - row.offset
			expect(math.abs(shift.Y + 0.5) < 1e-2).to.equal(true)
			expect(math.abs(shift.X) < 1e-2).to.equal(true)
			expect(math.abs(shift.Z) < 1e-2).to.equal(true)
			-- THE BOX TURNS WITH ITS BONE, which is what closes the hole the drawn neck opens when
			-- the head goes down (task 305c): a bone rolled 90 degrees rolls its box 90 degrees.
			bone.CFrame = CFrame.Angles(0, 0, math.rad(90))
			Body.followGait(handle, 2.5)
			expect((row.weld.C0.RightVector - Vector3.new(0, 1, 0)).Magnitude < 1e-2).to.equal(true)
			-- ...AND THE CLAMP: 4 studs of bone asks for more than the cap allows.
			bone.CFrame = CFrame.new(0, -4, 0)
			Body.followGait(handle, 2.5)
			expect(math.abs((row.weld.C0.Position - row.offset).Y + 2.5) < 1e-2).to.equal(true)
			-- NO BOX IS EVER RESIZED: the whole fix is where the boxes are, never how big.
			expect((row.part.Size - size).Magnitude).to.equal(0)
			bone:Destroy()
			row.bone = wasBone
			row.inBone = wasInBone
			row.weld.C0 = CFrame.new(row.offset)
		end)

		it("resolves through the ancestor walk to the trunk, which is what takeHit is given", function()
			local found = partsByZone()
			for _, zone in ipairs(CONFIG.ZONES.ORDER) do
				for _, part in ipairs(found[zone]) do
					local target, resolved = Weapon.Hits.targetOf(part)
					expect(target).to.equal(trunk)
					expect(resolved).to.equal(zone)
				end
			end
		end)

		-- THE ASSERTION THAT MATTERS, and it is read OFF THE GEOMETRY since task 284. Every box's own
		-- centre, from the flank, must answer that box's zone: fifteen real rays, and shrinking or
		-- moving any volume turns one of them red. The hand-written literals this replaces named
		-- places on a GREY BOX (a head box in the air in front of the snout, a legs slab running the
		-- whole length); the boxes are the drawn animal now, so the geometry is where the points live.
		it("answers every measured box's own zone, from a real ray at its centre", function()
			local geometry = Boar.kindGeometry(nil, CONFIG)
			local flank = Vector3.new(1, 0, 0)
			local tested = 0
			for _, zone in ipairs(CONFIG.ZONES.ORDER) do
				for index, box in ipairs(geometry.zones[zone].boxes) do
					local zoneAtCentre, instance = zoneAt(box.offset, flank, 20)
					if zoneAtCentre ~= zone then
						error(
							string.format(
								"%s box %d at (%.2f, %.2f, %.2f) answered %s on %s",
								zone,
								index,
								box.offset.X,
								box.offset.Y,
								box.offset.Z,
								tostring(zoneAtCentre),
								instance and instance.Name or "?"
							),
							0
						)
					end
					tested += 1
				end
			end
			expect(tested).to.equal(15)
		end)

		it("is a HEAD shot at the drawn snout, from the front AND from the flank", function()
			-- THE RIG'S OWN `nose` BONE, measured off the loaded model in a Play session on
			-- 2026-10-04 at mesh (0, 0.538, -2.388), written here in the trunk's frame (mesh Y plus
			-- the 0.1286 `Body.visualOffset` stands the feet on the box).
			local nose = Vector3.new(0, 0.538 + 0.1286, -2.388)
			expect((zoneAt(nose, Vector3.new(0, 0, -1), 20))).to.equal("head")
			-- ...AND FROM A PURE FLANK, WHICH IS NEW (task 284). This used to be `body` and the old
			-- comment explained why: the drawn head is 1.1 studs wide inside a 2.0-wide trunk, so a
			-- flank ray met the TRUNK first and a side shot at the face was charged to the body. With
			-- the trunk out of every ray the skull box is what the ray meets, and it is a head shot.
			expect((zoneAt(nose, Vector3.new(1, 0, 0), 20))).to.equal("head")
			expect((zoneAt(Vector3.new(0, 1.0, -1.8), Vector3.new(1, 0, 0), 20))).to.equal("head")
		end)

		it("is a CHEST shot behind the shoulder, and the TOP of that back is body", function()
			-- Heart and lungs, from either flank: the chest's two slabs span z -1.29..+0.23.
			expect((zoneAt(Vector3.new(0, 0.55, -0.6), Vector3.new(1, 0, 0), 20))).to.equal("chest")
			expect((zoneAt(Vector3.new(0, 0.55, -0.6), Vector3.new(-1, 0, 0), 20))).to.equal("chest")
			-- ...AND FROM ABOVE IT IS `body`, WHICH IS THE POINT OF THE DORSAL BAND (task 284, the
			-- deer's rule from task 281): a shot along the top of the back is not the heart. Karen's
			-- lethal list is head, neck and heart, so the band over the chest is `body` -- and before
			-- this task the top of the back answered NOTHING at all on the male and the legendary,
			-- because the mane crest stands 0.107 studs above the old `ZoneHead`'s ceiling.
			expect((zoneAt(Vector3.new(0, 1.5, -0.6), Vector3.new(0, 1, 0), 20))).to.equal("body")
		end)

		it("is BODY along the barrel, where the trunk used to be the only answer", function()
			-- THE BAND THIS TASK EXISTS FOR. `chest` ended at z +0.25 and `rear` began at +1.10, so
			-- the 0.85-stud barrel between them -- the broadest part of a broadside boar -- had no
			-- box and was a hit only because the TRUNK was the `body` zone. Switching the trunk off
			-- without a real `body` part would have made it a miss.
			expect((zoneAt(Vector3.new(0, 0.55, 0.45), Vector3.new(1, 0, 0), 20))).to.equal("body")
			expect((zoneAt(Vector3.new(0, 0.55, 0.89), Vector3.new(-1, 0, 0), 20))).to.equal("body")
		end)

		it("is the HINDQUARTERS from behind and from a flank", function()
			-- TASK 116's spine shot (Karen: *"can be hit to back part start to do circles with first
			-- legs on"*), on the measured rump: three slabs over z +1.11..+1.91, where the old single
			-- box ran to +2.90 -- a stud of tail and air past the drawn animal, which ends at ~+1.95.
			expect((zoneAt(Vector3.new(0, 0.44, 1.29), Vector3.new(0, 0, 1), 20))).to.equal("rear")
			expect((zoneAt(Vector3.new(0, 0.44, 1.29), Vector3.new(1, 0, 0), 20))).to.equal("rear")
			expect((zoneAt(Vector3.new(0, 0.54, 1.61), Vector3.new(-1, 0, 0), 20))).to.equal("rear")
		end)

		it("answers NOTHING between the legs, under the belly, or past the tail", function()
			-- THE DEFECT, AS THREE KNOWN-BAD INPUTS. Every one of these was a hit before task 284:
			-- `ZoneLegs` was one 2.12 x 1.0 x 5.4 slab under the whole animal, so the air BETWEEN the
			-- legs was a `legs` hit, and the trunk answered `body` everywhere else. Karen,
			-- 2026-10-26: *"wrong I hit the chest shows outside"*.
			expect((zoneAt(Vector3.new(0, -1.0, 0.15), Vector3.new(1, 0, 0), 20))).to.equal(nil)
			expect((zoneAt(Vector3.new(0, -1.2, 0.60), Vector3.new(1, 0, 0), 20))).to.equal(nil)
			expect((zoneAt(Vector3.new(0, -1.0, 2.60), Vector3.new(0, 0, 1), 20))).to.equal(nil)
			-- ...and the TRUNK is in the way of all three, so a miss is the geometry answering and
			-- not a ray that sailed past the animal (`deer_hitbox.spec`'s own guard).
			local bare = RaycastParams.new()
			bare.FilterType = Enum.RaycastFilterType.Include
			bare.FilterDescendantsInstances = { trunk }
			for _, point in ipairs({ Vector3.new(0, -1.0, 0.15), Vector3.new(0, -1.2, 0.6), Vector3.new(0, -1.0, 2.6) }) do
				local cf = trunk.CFrame
				local target = cf:PointToWorldSpace(point)
				local offset = cf:VectorToWorldSpace(Vector3.new(1, 0, 0)) * 20
				local crossed = Workspace:Raycast(target + offset, -offset * 2, bare)
				expect(crossed).to.be.ok()
				expect(crossed.Instance).to.equal(trunk)
			end
			TestKit.note("boar-zones: the air between the legs, under the belly and past the tail answers no zone")
		end)

		it("leaves clear air between the rump's floor and the legs", function()
			-- The two volumes still do not meet: the hind legs' boxes top out at y -0.42 and the
			-- rump's slabs start at -0.30, so nothing is decided by two coincident faces. A ray into
			-- that band answers NOTHING now, where it used to answer `body` on the trunk.
			local geometry = Boar.kindGeometry(nil, CONFIG)
			local rearFloor = math.huge
			for _, box in ipairs(geometry.zones.rear.boxes) do
				rearFloor = math.min(rearFloor, box.offset.Y - box.size.Y / 2)
			end
			local legsCeiling = -math.huge
			for _, box in ipairs(geometry.zones.legs.boxes) do
				legsCeiling = math.max(legsCeiling, box.offset.Y + box.size.Y / 2)
			end
			expect(rearFloor > legsCeiling).to.equal(true)
		end)

		it("still drives, upright, with the server owning the whole assembly", function()
			-- The zone parts did not tip it, anchor it, or take the assembly root away from the
			-- trunk: Massless parts never win that election (docs/physics/assemblies). Fifteen of
			-- them now rather than four, which is why this case is worth more than it was.
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

	-- ==================================================================================
	-- THE RED DEER'S FOUR ZONE BOXES (task 223 round 2, finding 3).
	--
	-- The design calls these *"the biggest single piece of work in the task"* and names THIS spec's
	-- method as their acceptance test: *"twelve real rays fired from outside at each deer kind, each
	-- returning the zone the geometry says it should"*. Round 1 shipped the boxes with no ray at
	-- all -- which is the precise defect class this whole file exists for, quoted at the top of it:
	-- *"a spec that called takeHit with zone = 'head' directly would pass happily"* while no player
	-- could ever land a head shot.
	--
	-- EVERY KIND GETS ITS OWN RAYS (L-093), and since task 280 it gets its own BOXES too: the three
	-- deer are three MODELS and not one model at three sizes, measured -- the stag's volumes at the
	-- hind's 0.8553 leave 131 cells of air on her mesh and at the calf's 0.495 leave 312 on its. So
	-- the points below are no longer one fraction table driving all three (that premise, and the
	-- twelve fixed probes written on it, are archived in
	-- `backups/2026-10-26_task-280_boar_zones-deer-twelve-probes.md`): each kind's rays are read off
	-- its own geometry, and the sweep against the DRAWN MESH is
	-- `tests/server/deer_hitbox.spec.luau`.
	describe("the red deer's zones, with real rays, at every size", function()
		-- `DEER_PROBES` IS GONE (task 280). See the case below for where the twelve points went
		-- and why a fraction table cannot name the same place on three different meshes.

		for _, kind in ipairs({ "stag", "hind", "calf" }) do
			describe("a " .. kind, function()
				local holder, runtime, handle, trunk, disconnect
				local spawnBottom, plateTop

				-- THIS FILE'S OWN `zoneAt`, because the boar's is local to its describe. Same
				-- method, and the method is the point: cast from OUTSIDE the animal the way the
				-- weapon does, read `HitZone` off whatever the engine returns, and measure how far
				-- the zone part beat the bare trunk by -- so a part that is merely FLUSH fails
				-- instead of passing on a tie.
				-- THROUGH THE WEAPON'S OWN CASTER since task 280, and the clearance measurement is
				-- gone with the thing it measured. It read how far the zone part beat the BARE TRUNK
				-- by, because a part merely FLUSH with the trunk is a coin toss (task 116, review
				-- round 2) -- and a deer's trunk is no longer on any bullet's ray at all
				-- (`ZonesOnly`, and `Weapon.Cast.world` passes a bullet through it), so there is
				-- nothing to tie with and every deer volume is fitted strictly INSIDE the drawn
				-- animal rather than proud of a box. The boar's describe above still measures it, on
				-- the animal it is still true of.
				local function zoneAt(localPoint: Vector3, fromDirection: Vector3, distance: number)
					local cf = trunk.CFrame
					local target = cf:PointToWorldSpace(localPoint)
					local offset = cf:VectorToWorldSpace(fromDirection.Unit) * distance
					local impact = Weapon.Cast.world(target + offset, -offset * 2, { Workspace.Terrain })
					if not impact then
						return nil, nil
					end
					local hit, zone = Weapon.Hits.targetOf(impact.instance)
					if not hit then
						return nil, impact.instance
					end
					return zone, impact.instance
				end

				beforeAll(function()
					holder = Instance.new("Folder")
					holder.Name = "DeerZonesSpec_" .. kind
					local plate = Instance.new("Part")
					plate.Name = "Plate"
					plate.Size = Vector3.new(120, 4, 120)
					plate.Position = Vector3.new(0, GROUND_Y - 2, 0)
					plate.Anchored = true
					plate.Parent = holder
					holder.Parent = Workspace
					runtime = Boar.newRuntime({
						field = FIELD,
						parent = holder,
						folderName = "Deer",
						rng = Random.new(223),
						config = { KINDS = { ENABLED = true } },
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
					handle = runtime:spawn(Vector3.new(0, GROUND_Y, 20), kind)
					trunk = handle.part
					-- WHERE IT WAS PUT, read BEFORE the step loop starts and before physics has
					-- settled anything: finding 2 is about the position the spawn line CHOOSES,
					-- and a body that has already been ejected upward would hide it.
					spawnBottom = trunk.Position.Y - trunk.Size.Y / 2
					plateTop = plate.Position.Y + plate.Size.Y / 2
					disconnect = runtime:run()
				end)

				afterAll(function()
					if disconnect then
						disconnect()
					end
					runtime:destroy()
					holder:Destroy()
				end)

				it("is built from the DEER's own boxes and not from a scaled boar", function()
					local row = CONFIG.KINDS[kind]
					local want = CONFIG.SPECIES.reddeer.BODY_SIZE * row.scale
					expect((trunk.Size - want).Magnitude < 0.01).to.equal(true)
					-- ...and it is NOT the boar's box at the same scale, which is the thing a
					-- single length assertion cannot tell apart.
					local boarBox = CONFIG.BODY_SIZE * row.scale
					expect((trunk.Size - boarBox).Magnitude > 0.5).to.equal(true)
				end)

				-- THE TWELVE FIXED PROBES ARE GONE, AND TASK 280 IS WHY (archived with the reason:
				-- `backups/2026-10-26_task-280_boar_zones-deer-twelve-probes.md`, rule 7). They were
				-- twelve points written as fractions of the box, which worked only while all three
				-- deer were ONE SHAPE SCALED -- and that premise was measured and refused: the
				-- stag's boxes at the hind's scale leave 131 cells of air on her mesh and at the
				-- calf's 312 on its, so each kind now carries its own volumes and a shared fraction
				-- table names a different part of each animal.
				--
				-- WHAT REPLACES THEM IS STRONGER, and it is a whole file:
				-- `tests/server/deer_hitbox.spec.luau` sweeps a 0.25-stud grid of real flank rays
				-- over each kind and asserts that EVERY ray answering a zone also crosses the DRAWN
				-- MESH, plus that the air under the neck and between the legs answers nothing. What
				-- stays here is the one thing that file does not do: that a ray finds a zone at all,
				-- on every kind, read off whatever the geometry currently says.
				it("answers a real ray at every one of its own zone boxes, on every kind", function()
					local geometry = Boar.kindGeometry(kind, Boar.kindConfig(kind, CONFIG))
					local seen = {}
					for _, name in ipairs(geometry.zoneOrder) do
						for index, box in ipairs(geometry.zones[name].boxes) do
							local zone = zoneAt(box.offset, Vector3.new(1, 0, 0), 20)
							if zone == nil then
								error(
									string.format("%s: %s box %d answered no zone at its own centre", kind, name, index),
									0
								)
							end
							seen[zone] = (seen[zone] or 0) + 1
						end
					end
					-- ALL FIVE WORDS A DEER CAN ANSWER, `body` INCLUDED: on a boar `body` is the
					-- trunk's fallback and no part carries it, but a deer's barrel is a real part
					-- (task 280) and a zone word no ray reaches is a zone that does not exist.
					for _, name in ipairs(geometry.zoneOrder) do
						if seen[name] == nil then
							error(string.format("%s: no ray reached the %s zone", kind, name), 0)
						end
					end
				end)

				it("starts ON the ground and not inside it", function()
					-- FINDING 2, AND IT IS READ FROM THE PLATE AND NOT FROM THE SPAWN LINE (L-086).
					-- The ground is the plate's own measured top -- an independent source -- and
					-- the animal's lowest point is its real `Position.Y - Size.Y / 2`. Round 1
					-- dropped every animal from the BOAR's half-height, so a stag's box bottom
					-- started 0.40 studs under this plate and a hind's 0.053 under.
					expect(spawnBottom >= plateTop - 1e-3).to.equal(true)
					-- ...and it is not thrown absurdly high either: `SPAWN_CLEARANCE` is half a
					-- stud and the male's floor is what a small animal keeps, so the worst honest
					-- gap is the male's half-height.
					expect(spawnBottom - plateTop <= CONFIG.BODY_SIZE.Y / 2 + CONFIG.SPAWN_CLEARANCE).to.equal(true)
				end)
			end)
		end
	end)
end
