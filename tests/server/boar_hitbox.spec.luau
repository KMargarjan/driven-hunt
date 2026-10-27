-- boar_hitbox.spec: A SHOT MAY ONLY CONNECT WHERE THE DRAWN BOAR IS (task 284).
--
-- KAREN, 2026-10-24: *"aim in empty space to get hit in head neck or heart like in real life"*, and
-- 2026-10-26 on a frozen broadside animal: *"wrong I hit the chest shows outside"*. The deer was
-- fixed in tasks 280 and 281; the boar is the commonest animal in the game and still held air.
-- MEASURED before this task: 49.5 %-59.2 % of every ray that met a hittable boar met NO ANIMAL, on
-- all four kinds from all four directions (`reviews/task-282/MEASURED.md` 3).
--
-- THE METHOD IS THE ONLY THING THAT CAN CATCH IT (Learning Agent L, 2026-10-26): `zone=chest` and
-- the hit card's dot are both read OUT OF THE SAME BOX as the defect, so neither can see a box in
-- the wrong place. Only the DRAWN MESH can -- every ray that hits a zone part must also cross the
-- mesh, and a ray where the animal is not must hit nothing at all. Same shape as
-- `deer_hitbox.spec`, same instrument.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/). It asks
-- through `Weapon.Cast.world`, the BULLET's own caster, because `CanQuery = false` is not what takes
-- a trunk out of a shot (measured: ignored for a COLLIDABLE part -- `Shotgun.Pierce`); the trunk
-- declares `ZonesOnly` and the caster steps past it.
--
-- Design: docs/design/hit-zones.md (sections 4, 12.3). Readings: reviews/task-284/MEASURED.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Assets = require(ServerStorage:WaitForChild("Assets"))
local Loader = require(ServerStorage.Assets:WaitForChild("Loader"))
local Boar = require(ServerScriptService:WaitForChild("Boar"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))

local CONFIG = Boar.CONFIG
local GROUND_Y = 620
local FIELD = {
	bounds = { minX = -90, maxX = 90, minZ = -90, maxZ = 90 },
	exitZ = -80,
	groundY = GROUND_Y,
}
local GRID = 0.25

-- HOW MUCH OF EACH KIND'S VISIBLE FLANK MUST ANSWER A ZONE. Measured on a 0.1-stud grid by
-- `reviews/task-284/probes/284-fit.luau` (male 75.9 %, female 72.7 %, cub 53.8 %, legendary 74.4 %);
-- the floor sits under that so a lost volume fails here. The complement is listed in
-- `reviews/task-284/MEASURED.md` -- the hoof, the crest's top strip, the snout's tip and the tail.
local COVERAGE_FLOOR = {
	male = 0.68,
	female = 0.64,
	cub = 0.45,
	legendary = 0.66,
}

local MODEL_KEY = {
	male = Assets.KEYS.boarMale,
	female = Assets.KEYS.boarFemale,
	cub = Assets.KEYS.boarCub,
	legendary = Assets.KEYS.boarMale, -- the same bought asset at `meshScale` 1.35
}

return function()
	describe("the boar's zone table", function()
		it("has a body zone part, and the trunk answers no ray", function()
			-- THE TWO SWITCHES THIS TASK IS. `body` used to be the TRUNK's fallback zone, which is
			-- why the trunk could not be taken out of the cast until it became a part: `chest` ended
			-- at z +0.25 and `rear` began at +1.10, so the barrel band between them was trunk only.
			expect(CONFIG.ZONES.TRUNK_HITTABLE).to.equal(false)
			expect(CONFIG.ZONES.body).to.be.ok()
			expect(CONFIG.ZONES.body.part).to.equal("ZoneBody")
			local order = table.concat(CONFIG.ZONES.ORDER, ",")
			expect(order).to.equal("head,chest,body,rear,legs")
			expect(Boar.kindGeometry(nil, CONFIG).trunkHittable).to.equal(false)
		end)

		it("gives every zone several measured boxes, all strictly inside the drawn male", function()
			-- THE DRAWN MALE, MEASURED (`<runs-dir>/284-profile.txt`): y -1.500..+1.757, z +-2.750,
			-- |x| <= 0.701 on a trunk 2.00 x 3.00 x 5.50. Every box must be inside that envelope in
			-- x and z, which is the cheap half of the fit and the one a hand edit breaks first.
			local geometry = Boar.kindGeometry("male", CONFIG)
			local count = 0
			for _, zone in ipairs(geometry.zoneOrder) do
				local boxes = geometry.zones[zone].boxes
				expect(#boxes >= 1).to.equal(true)
				for index, box in ipairs(boxes) do
					count += 1
					local x = math.abs(box.offset.X) + box.size.X / 2
					local z0 = box.offset.Z - box.size.Z / 2
					local z1 = box.offset.Z + box.size.Z / 2
					if x > 0.701 + 1e-6 or z0 < -2.750 - 1e-6 or z1 > 2.750 + 1e-6 then
						error(
							string.format(
								"%s box %d is outside the drawn male: |x| %.3f (<= 0.701), z %.3f..%.3f (within +-2.750)",
								zone,
								index,
								x,
								z0,
								z1
							),
							0
						)
					end
				end
			end
			expect(count).to.equal(15)
		end)
	end)

	for _, kind in ipairs({ "male", "female", "cub", "legendary" }) do
		describe("a " .. kind .. "'s shot volumes are the drawn " .. kind, function()
			local holder, runtime, handle, trunk, disconnect
			local meshes: { BasePart } = {}
			local geometry

			-- THE QUESTION A BULLET ASKS, along any axis, through the bullet's own caster. `nil` is a
			-- MISS, exactly as it is for a pellet.
			local function zoneAt(localPoint: Vector3, dir: Vector3): (string?, Instance?)
				local cf = trunk.CFrame
				local target = cf:PointToWorldSpace(localPoint)
				local offset = cf:VectorToWorldSpace(dir) * 20
				local impact = Weapon.Cast.world(target - offset, offset * 2, { Workspace.Terrain })
				if not impact then
					return nil, nil
				end
				local hit, zone = Weapon.Hits.targetOf(impact.instance)
				if not hit then
					return nil, impact.instance
				end
				return zone, impact.instance
			end

			local function crossesMesh(localPoint: Vector3, dir: Vector3): boolean
				if #meshes == 0 then
					return false
				end
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Include
				params.FilterDescendantsInstances = meshes
				local cf = trunk.CFrame
				local target = cf:PointToWorldSpace(localPoint)
				local offset = cf:VectorToWorldSpace(dir) * 20
				return Workspace:Raycast(target - offset, offset * 2, params) ~= nil
			end

			local function crossesTrunk(localPoint: Vector3, dir: Vector3): boolean
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Include
				params.FilterDescendantsInstances = { trunk }
				params.IgnoreWater = true
				local cf = trunk.CFrame
				local target = cf:PointToWorldSpace(localPoint)
				local offset = cf:VectorToWorldSpace(dir) * 20
				local hit = Workspace:Raycast(target - offset, offset * 2, params)
				return hit ~= nil and hit.Instance == trunk
			end

			beforeAll(function()
				holder = Instance.new("Folder")
				holder.Name = "BoarHitboxSpec_" .. kind
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
					folderName = "Boars",
					rng = Random.new(284),
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
				-- `Loader.preload` fetches and yields; `template` only answers (`deer_hitbox.spec`
				-- learnt that the hard way -- polling `template` turned a download into a lost race).
				Loader.preload({ MODEL_KEY[kind] })
				local template = Loader.template(MODEL_KEY[kind])
				runtime:setModelSource(function(): Instance?
					return template
				end, function(): number?
					return nil
				end)
				handle = runtime:spawn(Vector3.new(0, GROUND_Y, 0), kind)
				trunk = handle.part
				geometry = Boar.kindGeometry(kind, CONFIG)
				disconnect = runtime:run()
				local started = os.clock()
				while os.clock() - started < 8 do
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
				-- FREEZE TO THE BIND POSE: the boxes were measured in it, and a playing clip would
				-- make the verdict depend on which frame was sampled.
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
				trunk.Anchored = true
				task.wait()
				-- The mesh becomes queryable FOR THIS FILE ONLY; in the game it is false and must
				-- stay so (`Body.attachVisual`: *"A RAY MUST NEVER MEET THIS"*).
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

			it("is built from measured boxes, and its trunk is not a target", function()
				expect(geometry.trunkHittable).to.equal(false)
				expect(trunk:GetAttribute("Damageable")).to.equal(true)
				expect(trunk:GetAttribute("ZonesOnly")).to.equal(true)
				expect(trunk:GetAttribute("HitZone")).to.equal(nil)
				expect(Weapon.Hits.passesThrough(trunk)).to.equal(true)
				expect((Weapon.Hits.targetOf(trunk))).to.equal(nil)

				local built, expected = 0, 0
				for _, zone in ipairs(geometry.zoneOrder) do
					expected += #geometry.zones[zone].boxes
				end
				for _, child in ipairs(trunk:GetChildren()) do
					if child:IsA("BasePart") then
						built += 1
						local zone = child:GetAttribute("HitZone")
						expect(type(zone)).to.equal("string")
						expect(geometry.zones[zone]).to.be.ok()
						expect(child:GetAttribute("Damageable") == nil).to.equal(true)
						expect(child.CanQuery).to.equal(true)
						local target, resolved = Weapon.Hits.targetOf(child)
						expect(target).to.equal(trunk)
						expect(resolved).to.equal(zone)
					end
				end
				expect(built).to.equal(expected)

				-- WHOSE NUMBERS THESE ARE, and it is the measurement that decided it: the sow and
				-- the cub are different MESHES, so they carry their own absolute rows; `legendary`
				-- IS the male's mesh at 1.35 (measured 1.3498/1.3500/1.3500), so it is the male's
				-- boxes times `scale` and nothing of its own.
				local row = CONFIG.KINDS[kind]
				local maleChest = CONFIG.ZONES.chest.boxes[1].size
				if kind == "female" or kind == "cub" then
					expect(row.zones).to.be.ok()
					local own = row.zones.chest.boxes[1].size
					expect((geometry.zones.chest.boxes[1].size - own).Magnitude < 1e-4).to.equal(true)
					expect((geometry.zones.chest.boxes[1].size - maleChest * row.scale).Magnitude > 0.05).to.equal(true)
				else
					expect(row.zones).to.equal(nil)
					expect((geometry.zones.chest.boxes[1].size - maleChest * row.scale).Magnitude < 1e-4).to.equal(true)
				end
			end)

			it("has a drawn mesh to be measured against", function()
				if CONFIG.MODEL.ENABLED then
					expect(#meshes >= 1).to.equal(true)
				else
					expect(#meshes).to.equal(0)
					TestKit.note("boar-hitbox: BOAR_MODEL is off, so the mesh comparison did not run")
				end
			end)

			it("never answers a ray that misses the drawn animal", function()
				if #meshes == 0 then
					return
				end
				-- THE GRID SCALES WITH THE ANIMAL, so every kind is sampled the same number of times:
				-- a cub is 0.45 of the male and a fixed 0.25-stud grid gave it a quarter of his rays,
				-- which is under the vacuity floor below (measured: 13 of a needed 20).
				local grid = GRID * (trunk.Size.Z / CONFIG.BODY_SIZE.Z)
				local half = trunk.Size / 2
				local flank = Vector3.new(1, 0, 0)
				local air, both, meshOnly = 0, 0, 0
				local firstAir = nil
				local y = -half.Y - grid
				while y <= half.Y + grid * 4 do
					local z = -half.Z - grid
					while z <= half.Z + grid do
						local point = Vector3.new(0, y, z)
						local onMesh = crossesMesh(point, flank)
						local zone = zoneAt(point, flank)
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
						z += grid
					end
					y += grid
				end
				-- THE ONE NUMBER THIS TASK IS ABOUT. Before it, 53.7 %-59.2 % of the answering flank
				-- rays on every boar kind met no animal at all.
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
				-- ...and the sweep found the animal, so a zero out of an empty world cannot pass.
				expect(both >= 20).to.equal(true)
				local covered = both / (both + meshOnly)
				if covered < COVERAGE_FLOOR[kind] then
					error(
						string.format(
							"%s: only %d of %d mesh-crossing flank rays answer a zone (%.1f %%), under the %.1f %% floor",
							kind,
							both,
							both + meshOnly,
							covered * 100,
							COVERAGE_FLOOR[kind] * 100
						),
						0
					)
				end
				expect(covered >= COVERAGE_FLOOR[kind]).to.equal(true)
				TestKit.note(
					string.format(
						"boar-hitbox %s: %d of %d flank rays on a zone (%.1f %%), 0 in the air, %d crossing the mesh with no zone",
						kind,
						both,
						both + meshOnly,
						covered * 100,
						meshOnly
					)
				)
			end)

			it("answers NO hit beside the animal, under its belly, over its rump and past its snout", function()
				if #meshes == 0 then
					return
				end
				-- THE FOUR KNOWN-BAD INPUTS, as fractions of this animal's own trunk, and each one
				-- answered a zone before this task because the trunk WAS the zone. They are the
				-- dispatch's three words -- beside, under, over -- plus the wedge past the snout.
				--   `dir` is the axis the ray flies along: BESIDE is only a miss from the front,
				--   because a flank ray at that x would still cross the animal further in.
				local misses = {
					-- 0.42 OF THE TRUNK'S WIDTH is |x| 0.84 on the male: outside the drawn body (half-width
					-- 0.701 at its widest) and inside the trunk (half-width 1.00), which is what makes
					-- the miss mean something. A fraction of the SIZE, not of the half-width.
					{ "beside the flank, outside the drawn body", Vector3.new(0.42, 0.00, 0.00), Vector3.new(0, 0, 1) },
					{ "under the belly, between the legs", Vector3.new(0.00, -0.42, 0.05), Vector3.new(1, 0, 0) },
					{ "over the rump", Vector3.new(0.00, 0.40, 0.42), Vector3.new(1, 0, 0) },
					{ "past the snout, at the brow's height", Vector3.new(0.00, 0.45, -0.47), Vector3.new(1, 0, 0) },
				}
				local airPoints = 0
				local onMeshPoints = {}
				for _, probe in ipairs(misses) do
					local f = probe[2]
					local point = Vector3.new(f.X * trunk.Size.X, f.Y * trunk.Size.Y, f.Z * trunk.Size.Z)
					local dir = probe[3]
					-- THE PREMISE IS MEASURED PER POINT, never assumed: the animal must not be
					-- there, and the TRUNK must be, or the miss proves nothing.
					if crossesMesh(point, dir) then
						table.insert(onMeshPoints, probe[1])
					else
						airPoints += 1
						local zone, instance = zoneAt(point, dir)
						if zone ~= nil then
							error(
								string.format(
									"%s: %s (local %.2f, %.2f, %.2f) answered %s on %s -- the air is still a hit",
									kind,
									probe[1],
									point.X,
									point.Y,
									point.Z,
									zone,
									instance and instance.Name or "?"
								),
								0
							)
						end
						expect(zone).to.equal(nil)
						if not crossesTrunk(point, dir) then
							error(
								string.format(
									"%s: %s is not inside the trunk, so its miss proves nothing",
									kind,
									probe[1]
								),
								0
							)
						end
					end
				end
				-- ...AND THE CASE CANNOT GO VACUOUS.
				if airPoints < 3 then
					error(
						string.format(
							"%s: only %d of %d known-bad points are air at all, so this case proves nothing",
							kind,
							airPoints,
							#misses
						),
						0
					)
				end
				if #onMeshPoints > 0 then
					TestKit.note(
						string.format(
							"boar-hitbox %s: %s is ON the drawn animal, so a hit there is not air",
							kind,
							table.concat(onMeshPoints, ", ")
						)
					)
				end
			end)

			it("answers the head, the chest, the back, the barrel and the rump at their own boxes", function()
				-- THE OTHER HALF OF THE RULE: where the animal IS, the named zone answers. Read at
				-- each box's own centre, so this is the zone table's own word checked through the
				-- bullet's caster rather than through `takeHit`.
				local flank = Vector3.new(1, 0, 0)
				local checks = {
					{ "the skull", "head", geometry.zones.head.boxes[2] },
					{ "heart and lungs", "chest", geometry.zones.chest.boxes[2] },
					{ "the top of the back", "body", geometry.zones.body.boxes[1] },
					{ "the barrel", "body", geometry.zones.body.boxes[3] },
					{ "the rump", "rear", geometry.zones.rear.boxes[1] },
					{ "a front leg", "legs", geometry.zones.legs.boxes[1] },
				}
				for _, check in ipairs(checks) do
					local box = check[3]
					local zone = zoneAt(box.offset, flank)
					if zone ~= check[2] then
						error(
							string.format(
								"%s: %s (local %.2f, %.2f, %.2f) answered %s, not %s",
								kind,
								check[1],
								box.offset.X,
								box.offset.Y,
								box.offset.Z,
								tostring(zone),
								check[2]
							),
							0
						)
					end
					expect(zone).to.equal(check[2])
					-- ...and that centre is ON the drawn animal, so the case is not satisfied by a
					-- box sitting in the air (which is exactly the defect this task removed).
					if #meshes > 0 then
						expect(crossesMesh(box.offset, flank)).to.equal(true)
					end
				end
			end)

			it("covers the drawn back line with a band that is not the chest", function()
				-- THE DORSAL HOLE (task 282's measurement): the male's mane crest reaches y +1.757
				-- against `ZoneHead`'s old top of +1.650, so the top of the back answered NOTHING on
				-- the male and the legendary. The band is `body` and not `chest`, which is task 281's
				-- rule for the deer: a shot along the top of the back is not the heart.
				local bodyTop, chestTop = -math.huge, -math.huge
				for _, box in ipairs(geometry.zones.body.boxes) do
					bodyTop = math.max(bodyTop, box.offset.Y + box.size.Y / 2)
				end
				for _, box in ipairs(geometry.zones.chest.boxes) do
					chestTop = math.max(chestTop, box.offset.Y + box.size.Y / 2)
				end
				expect(bodyTop > chestTop).to.equal(true)
				-- ...and the band's own top is ON the animal, measured, not asserted.
				local band = geometry.zones.body.boxes[1]
				if #meshes > 0 then
					local crown = band.offset + Vector3.new(0, band.size.Y / 2 - 0.01, 0)
					local flank = Vector3.new(1, 0, 0)
					expect(crossesMesh(crown, flank)).to.equal(true)
					expect(zoneAt(crown, flank)).to.equal("body")
				end
			end)
		end)
	end
end
