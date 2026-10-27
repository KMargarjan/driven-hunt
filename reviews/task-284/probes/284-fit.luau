-- TASK 284: THE COMPLEMENT, BEFORE AND AFTER, all four boar kinds in one call.
-- `reviews/task-282/probes/282-fit2.luau` with the kind loop rolled inside, so before and after come
-- off ONE instrument in ONE staging pass. Two casts per direction with the drawn mesh's `CanQuery`
-- toggled between them, because `FilterDescendantsInstances` takes the instance AND ITS DESCENDANTS
-- and the mesh is a descendant of the trunk (task 282 round 1's bug, the Reviewer's finding).
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Loader = require(ServerStorage.Assets:WaitForChild("Loader"))
local Assets = require(ServerStorage:WaitForChild("Assets"))
local KEYS = { male = Assets.KEYS.boarMale, female = Assets.KEYS.boarFemale, cub = Assets.KEYS.boarCub, legendary = Assets.KEYS.boarMale }
local KINDS = { "male", "female", "cub", "legendary" }
local STEP = 0.1
local GROUND_Y = 900
local out = {}

local function stage(kind, holder)
	Loader.preload({ KEYS[kind] })
	local template = Loader.template(KEYS[kind])
	local runtime = Boar.newRuntime({
		field = { bounds = { minX = -80, maxX = 80, minZ = -80, maxZ = 80 }, exitZ = -75, groundY = GROUND_Y },
		parent = holder, folderName = "K" .. kind, rng = Random.new(284),
		config = { KINDS = { ENABLED = true } },
		threats = function() return {} end, probe = function() return false end,
		requestPath = function(_i, _f, _t, done) done(nil) end, releasePath = function() end,
	})
	runtime:setModelSource(function() return template end, function() return nil end)
	local handle = runtime:spawn(Vector3.new(0, GROUND_Y, 0), kind)
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
	if #meshes == 0 then return nil, nil end
	for _, d in ipairs(trunk:GetDescendants()) do if d:IsA("Animator") or d:IsA("AnimationController") then d:Destroy() end end
	for _, d in ipairs(trunk:GetDescendants()) do if d:IsA("Bone") then d.Transform = CFrame.new() end end
	for _, d in ipairs(trunk:GetDescendants()) do
		if d:IsA("LinearVelocity") or d:IsA("AlignOrientation") then d.Enabled = false end
	end
	trunk.Anchored = true
	task.wait(0.15)
	trunk.CFrame = CFrame.new(0, GROUND_Y, 0)
	task.wait(0.3)
	return trunk, meshes
end

for _, KIND in ipairs(KINDS) do
	local old = Workspace:FindFirstChild("Fit284")
	if old then old:Destroy() end
	local holder = Instance.new("Folder")
	holder.Name = "Fit284"
	holder.Parent = Workspace
	local trunk, meshes = stage(KIND, holder)
	if trunk == nil then
		table.insert(out, KIND .. ": NO MESH DREW")
	else
		local hittable = {}
		for _, d in ipairs(trunk:GetDescendants()) do
			if d:IsA("BasePart") and d:GetAttribute("HitZone") then table.insert(hittable, d) end
		end
		if trunk:GetAttribute("ZonesOnly") ~= true and trunk:GetAttribute("HitZone") then table.insert(hittable, trunk) end
		local mp = RaycastParams.new() mp.FilterType = Enum.RaycastFilterType.Include mp.FilterDescendantsInstances = meshes
		local bp = RaycastParams.new() bp.FilterType = Enum.RaycastFilterType.Include bp.FilterDescendantsInstances = hittable
		local cf = trunk.CFrame
		local hz, hy, hx = trunk.Size.Z / 2, trunk.Size.Y / 2, trunk.Size.X / 2
		local REACH = math.max(trunk.Size.X, trunk.Size.Y, trunk.Size.Z) + 16
		local SWEEPS = {
			{ "FLANK", function(a, b) return Vector3.new(hx + 6, a, b), Vector3.new(-1, 0, 0) end, -hy - 0.3, hy + 1.2, -hz - 0.4, hz + 0.4 },
			{ "ABOVE", function(a, b) return Vector3.new(a, hy + 6, b), Vector3.new(0, -1, 0) end, -hx - 0.3, hx + 0.3, -hz - 0.4, hz + 0.4 },
			{ "FRONT", function(a, b) return Vector3.new(b, a, -hz - 6), Vector3.new(0, 0, 1) end, -hy - 0.3, hy + 1.2, -hx - 0.3, hx + 0.3 },
			{ "BEHIND", function(a, b) return Vector3.new(b, a, hz + 6), Vector3.new(0, 0, -1) end, -hy - 0.3, hy + 1.2, -hx - 0.3, hx + 0.3 },
		}
		local function run(params)
			local grids = {}
			for i, s in ipairs(SWEEPS) do
				local g = {}
				local a = s[3]
				while a <= s[4] + 1e-9 do
					local b = s[5]
					while b <= s[6] + 1e-9 do
						local from, dir = s[2](a, b)
						table.insert(g, Workspace:Raycast(cf:PointToWorldSpace(from), cf:VectorToWorldSpace(dir.Unit) * REACH, params) ~= nil)
						b += STEP
					end
					a += STEP
				end
				grids[i] = g
			end
			return grids
		end
		for _, m in ipairs(meshes) do m.CanQuery = true end
		local meshGrid = run(mp)
		for _, m in ipairs(meshes) do m.CanQuery = false end
		local boxGrid = run(bp)
		table.insert(out, string.format("%s: trunk %.2f,%.2f,%.2f  drawn mesh %.3f,%.3f,%.3f  hittable=%d (ZonesOnly=%s)",
			KIND, trunk.Size.X, trunk.Size.Y, trunk.Size.Z, meshes[1].Size.X, meshes[1].Size.Y, meshes[1].Size.Z,
			#hittable, tostring(trunk:GetAttribute("ZonesOnly"))))
		for i, s in ipairs(SWEEPS) do
			local both, air, uncovered = 0, 0, 0
			for k = 1, #meshGrid[i] do
				local m, b = meshGrid[i][k], boxGrid[i][k]
				if m and b then both += 1 elseif b then air += 1 elseif m then uncovered += 1 end
			end
			local onAnimal = both + uncovered
			local boxHits = both + air
			table.insert(out, string.format("  %-7s rays=%d  animal=%d: HIT %d (%.1f%%) MISS %d (%.1f%%) | box hits=%d: AIR %d (%.1f%%)",
				s[1], #meshGrid[i], onAnimal, both, if onAnimal > 0 then both / onAnimal * 100 else 0,
				uncovered, if onAnimal > 0 then uncovered / onAnimal * 100 else 0,
				boxHits, air, if boxHits > 0 then air / boxHits * 100 else 0))
		end
	end
end
local old = Workspace:FindFirstChild("Fit284")
if old then old:Destroy() end
return table.concat(out, string.char(10))
