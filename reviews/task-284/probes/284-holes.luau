-- TASK 284: WHERE THE REMAINING MISSES ARE. AIR is 0 after the fit; the complement of that is
-- under-coverage, and L-122 says a non-zero remainder is a LOCATED DEFECT and not a score. This
-- prints, per kind, the worst DORSAL gap (the drawn back line minus the highest covered y, per z)
-- and the uncovered flank cells sorted into regions.
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Loader = require(ServerStorage.Assets:WaitForChild("Loader"))
local Assets = require(ServerStorage:WaitForChild("Assets"))
local KEYS = { male = Assets.KEYS.boarMale, female = Assets.KEYS.boarFemale, cub = Assets.KEYS.boarCub, legendary = Assets.KEYS.boarMale }
local KINDS = { "male", "female", "cub", "legendary" }
local STEP = 0.05
local GROUND_Y = 900
local out = {}

for _, KIND in ipairs(KINDS) do
	local old = Workspace:FindFirstChild("Hole284")
	if old then old:Destroy() end
	local holder = Instance.new("Folder")
	holder.Name = "Hole284"
	holder.Parent = Workspace
	Loader.preload({ KEYS[KIND] })
	local template = Loader.template(KEYS[KIND])
	local runtime = Boar.newRuntime({
		field = { bounds = { minX = -80, maxX = 80, minZ = -80, maxZ = 80 }, exitZ = -75, groundY = GROUND_Y },
		parent = holder, folderName = "K", rng = Random.new(284),
		config = { KINDS = { ENABLED = true } },
		threats = function() return {} end, probe = function() return false end,
		requestPath = function(_i, _f, _t, done) done(nil) end, releasePath = function() end,
	})
	runtime:setModelSource(function() return template end, function() return nil end)
	local handle = runtime:spawn(Vector3.new(0, GROUND_Y, 0), KIND)
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
	trunk.CFrame = CFrame.new(0, GROUND_Y, 0)
	task.wait(0.3)
	local hittable = {}
	for _, d in ipairs(trunk:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("HitZone") then table.insert(hittable, d) end
	end
	local mp = RaycastParams.new() mp.FilterType = Enum.RaycastFilterType.Include mp.FilterDescendantsInstances = meshes
	local bp = RaycastParams.new() bp.FilterType = Enum.RaycastFilterType.Include bp.FilterDescendantsInstances = hittable
	local cf = trunk.CFrame
	local hx, hy, hz = trunk.Size.X / 2, trunk.Size.Y / 2, trunk.Size.Z / 2
	local REACH = trunk.Size.Z + 16
	local function flankHit(params, y, z)
		for _, m in ipairs(meshes) do m.CanQuery = (params == mp) end
		return Workspace:Raycast(cf:PointToWorldSpace(Vector3.new(hx + 6, y, z)), cf:VectorToWorldSpace(Vector3.new(-1, 0, 0)) * REACH, params) ~= nil
	end
	-- ONE PASS PER CAST, so the two can never see each other's parts.
	local ZS, YS = {}, {}
	local z = -hz - 0.3
	while z <= hz + 0.3 do table.insert(ZS, z) z += STEP end
	local y = -hy - 0.2
	while y <= hy + 1.4 do table.insert(YS, y) y += STEP end
	local mesh, box = {}, {}
	for _, m in ipairs(meshes) do m.CanQuery = true end
	for iy, yy in ipairs(YS) do
		mesh[iy] = {}
		for iz, zz in ipairs(ZS) do
			mesh[iy][iz] = Workspace:Raycast(cf:PointToWorldSpace(Vector3.new(hx + 6, yy, zz)), cf:VectorToWorldSpace(Vector3.new(-1, 0, 0)) * REACH, mp) ~= nil
		end
	end
	for _, m in ipairs(meshes) do m.CanQuery = false end
	for iy, yy in ipairs(YS) do
		box[iy] = {}
		for iz, zz in ipairs(ZS) do
			box[iy][iz] = Workspace:Raycast(cf:PointToWorldSpace(Vector3.new(hx + 6, yy, zz)), cf:VectorToWorldSpace(Vector3.new(-1, 0, 0)) * REACH, bp) ~= nil
		end
	end
	-- THE DORSAL GAP: per z, the drawn back line minus the highest y a box answers.
	local worstGap, worstZ, gapCols = 0, nil, 0
	local regions = { back = 0, belly = 0, legs = 0, nose = 0, tail = 0, other = 0 }
	local meshTop, meshBottom = {}, {}
	for iz = 1, #ZS do
		local top, bot = nil, nil
		for iy = #YS, 1, -1 do if mesh[iy][iz] then top = YS[iy] break end end
		for iy = 1, #YS do if mesh[iy][iz] then bot = YS[iy] break end end
		meshTop[iz], meshBottom[iz] = top, bot
		if top ~= nil then
			local boxTop = nil
			for iy = #YS, 1, -1 do if box[iy][iz] then boxTop = YS[iy] break end end
			local gap = if boxTop then top - boxTop else top - (bot or top)
			if gap > STEP + 1e-9 then gapCols += 1 end
			if gap > worstGap then worstGap, worstZ = gap, ZS[iz] end
		end
	end
	for iz = 1, #ZS do
		for iy = 1, #YS do
			if mesh[iy][iz] and not box[iy][iz] then
				local yy, zz = YS[iy], ZS[iz]
				local top, bot = meshTop[iz], meshBottom[iz]
				if zz < -hz * 0.72 then
					regions.nose += 1
				elseif zz > hz * 0.62 then
					regions.tail += 1
				elseif yy < -hy * 0.55 then
					regions.legs += 1
				elseif top ~= nil and yy > top - 0.2 then
					regions.back += 1
				elseif bot ~= nil and yy < bot + 0.45 then
					regions.belly += 1
				else
					regions.other += 1
				end
			end
		end
	end
	table.insert(out, string.format(
		"%s: worst DORSAL gap %.2f studs at z %+.2f (%d of %d columns short by more than one cell) | uncovered flank cells: back %d, belly %d, legs %d, nose/jaw %d, tail %d, other %d",
		KIND, worstGap, worstZ or 0, gapCols, #ZS, regions.back, regions.belly, regions.legs, regions.nose, regions.tail, regions.other))
end
local old = Workspace:FindFirstChild("Hole284")
if old then old:Destroy() end
return table.concat(out, string.char(10))
