-- deer_hitbox.spec: A SHOT MAY ONLY CONNECT WHERE THE DRAWN DEER IS (task 280).
--
-- KAREN, 2026-10-26, on a FROZEN broadside hind at about 28 m in her Forest Test: *"wrong I hit the
-- chest shows outside"* -- the hit card's dot sat in empty space in front of the chest, under the
-- neck. And on 2026-10-24: *"sometimes shows we hit empty space and died"*. The card was honest; the
-- HITBOX was the fault. A deer's trunk is 1.8 x 4.8 x 7.05 studs -- the nose line to the rump, the
-- back line to the hooves -- it carried `HitZone = "body"` with `CanQuery = true`, and a deer does
-- not fill it. The air in front of the chest and the air between the legs were hits.
--
-- THE METHOD IS THE ONLY THING THAT COULD HAVE CAUGHT IT, and it is the Learning Agent's L (incident
-- 2026-10-26: *"a week of shooting tasks passed while the deer's hitbox held the air under its
-- neck"*). `zone=chest` and the card's dot are both read OUT OF THE SAME BOX as the defect, so
-- neither can see a box that is in the wrong place. The only instrument that can is the DRAWN MESH:
-- every ray that hits a zone part must also cross the mesh, and a ray at a place the animal is not
-- must hit nothing at all. That is what this file does, with real rays, against the real model.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/), and
-- `boar_zones.spec`'s own method -- cast from OUTSIDE the animal the way the weapon does and read
-- `HitZone` off whatever the engine returns, never by calling `takeHit` with a zone name.
--   Raycasting + CanQuery  https://create.roblox.com/docs/workspace/raycasting
--     "You can exempt any BasePart from hit detection by setting its BasePart.CanQuery property to
--     false" -- which is what the deer's trunk now is, and what the drawn mesh has always been.
--
-- IT BUILDS ITS OWN WORLD at y = 500, the pattern `boar_body.spec` and `boar_zones.spec` use, so
-- production's animals are untouched.
--
-- WHY THE POSE IS FROZEN TO THE BIND POSE: the boxes were measured against the model's bind pose,
-- and an idle clip moves the head and the legs, so a live clip would make this file's verdict depend
-- on which frame it sampled. Every `Animator` is removed and every `Bone.Transform` is set back to
-- the identity, which is deterministic and is the same state the measurement was taken in. A MOVING
-- animal is a different question (the boxes are welded to the trunk and travel with it); that one
-- belongs to `zz_claim_window.spec` and to Karen's own frozen-animal trial.
--
-- Design: docs/design/red-deer.md (section 7.3), docs/design/hit-zones.md (sections 4, 12.3)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))

local CONFIG = Boar.CONFIG

local GROUND_Y = 500
local FIELD = {
	bounds = { minX = -90, maxX = 90, minZ = -90, maxZ = 90 },
	exitZ = -80,
	groundY = GROUND_Y,
}

-- THE DISPATCH'S OWN GRID: "every 0.25 stud".
local GRID = 0.25

return function()
	-- THE BOAR IS THE CONTROL, and it is here rather than in `boar_zones.spec` because the thing
	-- being asserted is this task's one switch: `TRUNK_HITTABLE` is absent from the boar's
	-- `Boar.CONFIG.ZONES`, so a boar's trunk still answers rays and `body` is still a zone a player
	-- can hit. Without this case, deleting the `~= false` and hard-coding `false` would pass.
	describe("the boar's trunk is still a target", function()
		local holder, runtime, handle, disconnect

		beforeAll(function()
			holder = Instance.new("Folder")
			holder.Name = "DeerHitboxSpec_boar"
			holder.Parent = Workspace
			runtime = Boar.newRuntime({
				field = FIELD,
				parent = holder,
				folderName = "Boars",
				rng = Random.new(280),
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
			handle = runtime:spawn(Vector3.new(0, GROUND_Y, 0))
			disconnect = runtime:run()
		end)

		afterAll(function()
			if disconnect then
				disconnect()
			end
			runtime:destroy()
			holder:Destroy()
		end)

		it("answers a ray, and its fallback zone is still body", function()
			expect(handle.part.CanQuery).to.equal(true)
			expect(handle.part:GetAttribute("HitZone")).to.equal("body")
			-- ...and the geometry says so too: `TRUNK_HITTABLE` is not a key of the boar's table.
			expect(CONFIG.ZONES.TRUNK_HITTABLE).to.equal(nil)
			expect(Boar.kindGeometry(nil, CONFIG).trunkHittable).to.equal(true)
		end)
	end)

	for _, kind in ipairs({ "stag", "hind", "calf" }) do
		describe("a " .. kind .. "'s shot volumes are the drawn " .. kind, function()
			local holder, runtime, handle, trunk, disconnect
			local meshes: { BasePart } = {}
			local geometry

			-- The zone parts and the trunk, and nothing else in the world.
			local function zoneAt(localPoint: Vector3): (string?, BasePart?)
				local cf = trunk.CFrame
				local target = cf:PointToWorldSpace(localPoint)
				local offset = cf:VectorToWorldSpace(Vector3.new(1, 0, 0)) * 20
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Include
				params.FilterDescendantsInstances = { trunk }
				local result = Workspace:Raycast(target + offset, -offset * 2, params)
				if not result then
					return nil, nil
				end
				local _, zone = Weapon.Hits.targetOf(result.Instance)
				return zone, result.Instance
			end

			beforeAll(function()
				holder = Instance.new("Folder")
				holder.Name = "DeerHitboxSpec_" .. kind
				local plate = Instance.new("Part")
				plate.Name = "Plate"
				plate.Size = Vector3.new(160, 4, 160)
				plate.Position = Vector3.new(0, GROUND_Y - 2, 0)
				plate.Anchored = true
				plate.Parent = holder
				holder.Parent = Workspace
				runtime = Boar.newRuntime({
					field = FIELD,
					parent = holder,
					folderName = "Deer",
					rng = Random.new(280),
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
				handle = runtime:spawn(Vector3.new(0, GROUND_Y, 0), kind)
				trunk = handle.part
				geometry = Boar.kindGeometry(kind, Boar.kindConfig(kind, CONFIG))
				disconnect = runtime:run()
				-- THE COAT ARRIVES LATE BY DESIGN (`Runtime:step`: *"late is not lost"*), so this
				-- waits for it rather than sampling once. Bounded, and the case below says out loud
				-- what it does when the wait runs out.
				local started = os.clock()
				while os.clock() - started < 20 do
					meshes = {}
					for _, descendant in ipairs(trunk:GetDescendants()) do
						if descendant:IsA("MeshPart") then
							table.insert(meshes, descendant)
						end
					end
					if #meshes > 0 then
						break
					end
					task.wait(0.1)
				end
				if disconnect then
					disconnect()
					disconnect = nil
				end
				trunk.Anchored = true
				-- FREEZE TO THE BIND POSE. See the header: the boxes were measured in it, and a
				-- playing clip would make the verdict depend on the frame.
				for _, descendant in ipairs(trunk:GetDescendants()) do
					if descendant:IsA("Animator") or descendant:IsA("AnimationController") then
						descendant:Destroy()
					end
				end
				for _, descendant in ipairs(trunk:GetDescendants()) do
					if descendant:IsA("Bone") then
						descendant.Transform = CFrame.new()
					end
				end
				task.wait()
				-- THE MESH BECOMES QUERYABLE FOR THIS FILE ONLY, and `afterAll` puts it back. In the
				-- game it is `false` and must stay so (`Body.attachVisual`: *"A RAY MUST NEVER MEET
				-- THIS"*); here it is the instrument.
				for _, mesh in ipairs(meshes) do
					mesh.CanQuery = true
				end
			end)

			afterAll(function()
				for _, mesh in ipairs(meshes) do
					if mesh.Parent ~= nil then
						mesh.CanQuery = false
					end
				end
				if disconnect then
					disconnect()
				end
				runtime:destroy()
				holder:Destroy()
			end)

			it("is built from this kind's own measured volumes, and the trunk answers no ray", function()
				-- THE SWITCH. A deer's trunk is physics and nothing else now.
				expect(trunk.CanQuery).to.equal(false)
				expect(trunk:GetAttribute("Damageable")).to.equal(true)
				expect(geometry.trunkHittable).to.equal(false)

				-- ONE PART PER MEASURED BOX, every one carrying its own zone and none of them
				-- carrying `Damageable` -- two damageable instances in one ancestor chain is an
				-- ambiguity, not a feature (`boar_zones.spec`).
				local built, expected = {}, 0
				for _, zone in ipairs(geometry.zoneOrder) do
					expected += #geometry.zones[zone].boxes
				end
				for _, child in ipairs(trunk:GetChildren()) do
					if child:IsA("BasePart") then
						table.insert(built, child)
						local zone = child:GetAttribute("HitZone")
						expect(type(zone)).to.equal("string")
						expect(geometry.zones[zone]).to.be.ok()
						expect(child:GetAttribute("Damageable") == nil).to.equal(true)
						expect(child.CanQuery).to.equal(true)
						-- ...and the weapon's own walk ends on the trunk, which is what `takeHit`
						-- is given.
						local target, resolved = Weapon.Hits.targetOf(child)
						expect(target).to.equal(trunk)
						expect(resolved).to.equal(zone)
					end
				end
				expect(#built).to.equal(expected)
				-- ...AND THEY ARE THIS KIND'S NUMBERS AND NOT THE STAG'S SCALED, which is the
				-- measurement task 280 could not scale away: the hind's and the calf's boxes are
				-- their own and `Body.kindGeometry` must not multiply them by `scale`.
				local row = CONFIG.KINDS[kind]
				if row.zones ~= nil then
					local first = row.zones.chest.boxes[1]
					expect((geometry.zones.chest.boxes[1].size - first.size).Magnitude < 1e-4).to.equal(true)
					-- and NOT the species table at this kind's scale, which is the bug this guards
					local scaled = CONFIG.SPECIES.reddeer.ZONES.chest.boxes[1].size * row.scale
					expect((geometry.zones.chest.boxes[1].size - scaled).Magnitude > 0.05).to.equal(true)
				end
			end)

			it("has a drawn mesh to be measured against", function()
				-- NOT SKIPPED SILENTLY. With `BOAR_MODEL` off there is no drawn animal at all, and
				-- the case below has nothing to compare with; that is stated, not hidden.
				if CONFIG.MODEL.ENABLED then
					expect(#meshes >= 1).to.equal(true)
				else
					expect(#meshes).to.equal(0)
					TestKit.note("deer-hitbox: BOAR_MODEL is off, so the mesh comparison did not run")
				end
			end)

			it("never answers a ray that misses the drawn animal", function()
				if #meshes == 0 then
					return
				end
				local meshParams = RaycastParams.new()
				meshParams.FilterType = Enum.RaycastFilterType.Include
				meshParams.FilterDescendantsInstances = meshes

				local cf = trunk.CFrame
				local half = trunk.Size / 2
				local air, both, meshOnly = 0, 0, 0
				local firstAir = nil
				local y = -half.Y - GRID
				while y <= half.Y + GRID * 4 do
					local z = -half.Z - GRID
					while z <= half.Z + GRID do
						local target = cf:PointToWorldSpace(Vector3.new(0, y, z))
						local offset = cf:VectorToWorldSpace(Vector3.new(1, 0, 0)) * 20
						local origin = target + offset
						local onMesh = Workspace:Raycast(origin, -offset * 2, meshParams) ~= nil
						local zone = zoneAt(Vector3.new(0, y, z))
						if zone ~= nil and not onMesh then
							air += 1
							if firstAir == nil then
								firstAir = string.format("y %+.2f z %+.2f answered %s", y, z, zone)
							end
						elseif zone ~= nil then
							both += 1
						elseif onMesh then
							meshOnly += 1
						end
						z += GRID
					end
					y += GRID
				end
				-- THE ONE NUMBER THIS TASK IS ABOUT. Before it, the same sweep on a stag counted
				-- 1,999 of 3,631 answering rays in empty air (`<runs-dir>/280-fit0-prefix.txt`).
				if air > 0 then
					error(
						string.format(
							"%s: %d of %d answering rays hit a zone and MISSED the drawn animal; first at %s",
							kind,
							air,
							air + both,
							tostring(firstAir)
						),
						0
					)
				end
				expect(air).to.equal(0)
				-- ...and the sweep really did find the animal, so a zero that came from an empty
				-- world cannot pass (the known-bad input of this case).
				-- 20 AND NOT A ROUND HUNDRED: at 0.25 studs a calf's flank is a 14 x 17 grid, so the
				-- floor has to be a number the smallest animal can reach while still refusing a
				-- sweep that found nothing.
				expect(both >= 20).to.equal(true)
				TestKit.note(
					string.format(
						"deer-hitbox %s: %d flank rays on a zone, 0 in the air, %d crossing the mesh with no zone",
						kind,
						both,
						meshOnly
					)
				)
			end)

			it(
				"is a MISS where Karen's shot landed: in front of the chest, under the neck, between the legs",
				function()
					-- THE KNOWN-BAD INPUTS, as fractions of this animal's own box so one table drives
					-- all three sizes. Every one of these answered `body` before task 280.
					local half = trunk.Size / 2
					local misses = {
						{ "under the neck, at the brisket's height", 0.00, -0.37 },
						{ "in front of the chest, mid height", 0.25, -0.45 },
						{ "between the legs", -0.30, 0.15 },
						{ "under the barrel, behind the front legs", -0.30, -0.05 },
					}
					for _, probe in ipairs(misses) do
						local point = Vector3.new(0, probe[2] * trunk.Size.Y, probe[3] * trunk.Size.Z)
						local zone, instance = zoneAt(point)
						if zone ~= nil then
							error(
								string.format(
									"%s: %s (local y %+.2f z %+.2f) answered %s on %s -- the air is still a hit",
									kind,
									probe[1],
									point.Y,
									point.Z,
									zone,
									instance and instance.Name or "?"
								),
								0
							)
						end
						expect(zone).to.equal(nil)
					end
					-- ...and the trunk really is in the way of those rays, so the misses above are the
					-- geometry answering and not a ray that went past the animal altogether.
					for _, probe in ipairs(misses) do
						local y = probe[2] * trunk.Size.Y
						local z = probe[3] * trunk.Size.Z
						expect(math.abs(y) <= half.Y).to.equal(true)
						expect(math.abs(z) <= half.Z).to.equal(true)
					end
				end
			)

			it("answers the chest, the neck, the head and the rump at their own centres", function()
				-- READ OFF THE GEOMETRY, so the case cannot drift from the table: the first `chest`
				-- box is the thorax, the last is the neck, the last `head` box is the skull and the
				-- first `rear` box is the hindquarters. A neck shot answering `chest` IS the answer
				-- this task chose (see `SPECIES.reddeer.ZONES.chest`).
				local chest = geometry.zones.chest.boxes
				local head = geometry.zones.head.boxes
				local rear = geometry.zones.rear.boxes
				local named = {
					{ "the thorax", chest[1].offset, "chest" },
					{ "the neck", chest[#chest].offset, "chest" },
					{ "the skull", head[#head].offset, "head" },
					{ "the rump", rear[1].offset, "rear" },
				}
				for _, probe in ipairs(named) do
					local zone = zoneAt(probe[2])
					if zone ~= probe[3] then
						error(
							string.format(
								"%s: %s at (%.2f, %.2f, %.2f) answered %s, wanted %s",
								kind,
								probe[1],
								probe[2].X,
								probe[2].Y,
								probe[2].Z,
								tostring(zone),
								probe[3]
							),
							0
						)
					end
					expect(zone).to.equal(probe[3])
				end
				-- EVERY box's centre answers SOME zone of this animal -- a box nothing can reach is
				-- a box that may as well not exist, which is the trap `boar_zones.spec`'s header
				-- names.
				for _, zoneName in ipairs(geometry.zoneOrder) do
					for index, box in ipairs(geometry.zones[zoneName].boxes) do
						local zone = zoneAt(box.offset)
						if zone == nil then
							error(
								string.format("%s: %s box %d is unreachable by a flank ray", kind, zoneName, index),
								0
							)
						end
						expect(type(zone)).to.equal("string")
					end
				end
			end)
		end)
	end
end
