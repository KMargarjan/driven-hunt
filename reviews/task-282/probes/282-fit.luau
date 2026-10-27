-- TASK 282 item 3: THE COMPLEMENT, per boar kind. For each kind: spawn the real model, pose it,
-- then fire a 0.1-stud grid of rays from the FLANK, ABOVE, FRONT and BEHIND and count
--   both      = the ray met the DRAWN mesh and a hittable box      (a hit on the animal: right)
--   AIR       = it met a hittable box and NO mesh                  (a hit on nothing: wrong)
--   uncovered = it met the mesh and NO box                         (a miss on the animal: wrong)
-- "hittable" is what the WEAPON can hit: the zone parts, plus the trunk when it has no ZonesOnly.
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Loader = require(ServerStorage.Assets:WaitForChild("Loader"))
local Assets = require(ServerStorage:WaitForChild("Assets"))
local KEYS = { male = Assets.KEYS.boarMale, female = Assets.KEYS.boarFemale, cub = Assets.KEYS.boarCub, legendary = Assets.KEYS.boarMale }
local GROUND_Y = 900
local old = Workspace:FindFirstChild("Fit282")
if old then old:Destroy() end
local holder = Instance.new("Folder") holder.Name = "Fit282" holder.Parent = Workspace
local plate = Instance.new("Part")
plate.Name = "Plate" plate.Size = Vector3.new(300, 4, 300)
plate.Position = Vector3.new(0, GROUND_Y - 2, 0) plate.Anchored = true plate.Parent = holder
local out = {}
local STEP = 0.1
local function measure(kind, slot)
	Loader.preload({ KEYS[kind] })
	local template = Loader.template(KEYS[kind])
	if not template then table.insert(out, kind .. ": NO TEMPLATE") return end
	local runtime = Boar.newRuntime({
		field = { bounds = { minX = -140, maxX = 140, minZ = -140, maxZ = 140 }, exitZ = -130, groundY = GROUND_Y },
		parent = holder, folderName = "K_" .. kind, rng = Random.new(282),
		config = { KINDS = { ENABLED = true } },
		threats = function() return {} end, probe = function() return false end,
		requestPath = function(_i, _f, _t, done) done(nil) end, releasePath = function() end,
	})
	runtime:setModelSource(function() return template end, function() return nil end)
	local handle = runtime:spawn(Vector3.new(slot, GROUND_Y, 0), kind)
	local trunk = handle.part
	local disconnect = runtime:run()
	local meshes = {}
	local t0 = os.clock()
	while os.clock() - t0 < 12 do
		meshes = {}
		for _, d in ipairs(trunk:GetDescendants()) do if d:IsA("MeshPart") then table.insert(meshes, d) end end
		if #meshes > 0 then break end
		task.wait(0.15)
	end
	task.wait(0.3)
	if disconnect then disconnect() end
	for _, d in ipairs(trunk:GetDescendants()) do if d:IsA("Animator") or d:IsA("AnimationController") then d:Destroy() end end
	for _, d in ipairs(trunk:GetDescendants()) do if d:IsA("Bone") then d.Transform = CFrame.new() end end
	for _, d in ipairs(trunk:GetDescendants()) do
		if d:IsA("LinearVelocity") or d:IsA("AlignOrientation") then d.Enabled = false end
	end
	trunk.Anchored = true
	task.wait(0.15)
	trunk.CFrame = CFrame.new(slot, GROUND_Y, 0)
	task.wait(0.25)
	for _, m in ipairs(meshes) do m.CanQuery = true end
	-- what the WEAPON can hit
	local hittable = {}
	for _, d in ipairs(trunk:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("HitZone") then table.insert(hittable, d) end
	end
	if trunk:GetAttribute("ZonesOnly") ~= true and trunk:GetAttribute("HitZone") then table.insert(hittable, trunk) end
	local mp = RaycastParams.new() mp.FilterType = Enum.RaycastFilterType.Include mp.FilterDescendantsInstances = meshes
	local bp = RaycastParams.new() bp.FilterType = Enum.RaycastFilterType.Include bp.FilterDescendantsInstances = hittable
	local cf = trunk.CFrame
	local hz, hy, hx = trunk.Size.Z / 2, trunk.Size.Y / 2, trunk.Size.X / 2
	local function pair(from, dir)
		local o = cf:PointToWorldSpace(from)
		local d = cf:VectorToWorldSpace(dir.Unit) * (math.max(trunk.Size.X, trunk.Size.Y, trunk.Size.Z) + 16)
		return Workspace:Raycast(o, d, mp) ~= nil, Workspace:Raycast(o, d, bp) ~= nil
	end
	local function sweep(name, mk, a0, a1, b0, b1)
		local both, air, uncovered, none = 0, 0, 0, 0
		local a = a0
		while a <= a1 + 1e-9 do
			local b = b0
			while b <= b1 + 1e-9 do
				local from, dir = mk(a, b)
				local m, bx = pair(from, dir)
				if m and bx then both += 1 elseif bx then air += 1 elseif m then uncovered += 1 else none += 1 end
				b += STEP
			end
			a += STEP
		end
		local onAnimal = both + uncovered
		table.insert(out, string.format("  %-7s rays=%d  on the animal=%d: HIT %d (%.1f%%) MISS %d (%.1f%%) | AIR hits=%d",
			name, both + air + uncovered + none, onAnimal, both,
			if onAnimal > 0 then both / onAnimal * 100 else 0, uncovered,
			if onAnimal > 0 then uncovered / onAnimal * 100 else 0, air))
	end
	if #meshes == 0 then table.insert(out, kind .. ": NO MESH DREW (template present=" .. tostring(template ~= nil) .. ")") return end
	table.insert(out, string.format("%s: trunk %.2f,%.2f,%.2f  drawn mesh %.3f,%.3f,%.3f  hittable parts=%d (ZonesOnly=%s)",
		kind, trunk.Size.X, trunk.Size.Y, trunk.Size.Z,
		meshes[1].Size.X, meshes[1].Size.Y, meshes[1].Size.Z, #hittable, tostring(trunk:GetAttribute("ZonesOnly"))))
	sweep("FLANK", function(y, z) return Vector3.new(hx + 6, y, z), Vector3.new(-1, 0, 0) end, -hy - 0.3, hy + 1.2, -hz - 0.4, hz + 0.4)
	sweep("ABOVE", function(x, z) return Vector3.new(x, hy + 6, z), Vector3.new(0, -1, 0) end, -hx - 0.3, hx + 0.3, -hz - 0.4, hz + 0.4)
	sweep("FRONT", function(y, x) return Vector3.new(x, y, -hz - 6), Vector3.new(0, 0, 1) end, -hy - 0.3, hy + 1.2, -hx - 0.3, hx + 0.3)
	sweep("BEHIND", function(y, x) return Vector3.new(x, y, hz + 6), Vector3.new(0, 0, -1) end, -hy - 0.3, hy + 1.2, -hx - 0.3, hx + 0.3)
	for _, m in ipairs(meshes) do m.CanQuery = false end
end
measure(_G.DH282_FITKIND or "male", 0)
return table.concat(out, string.char(10))
