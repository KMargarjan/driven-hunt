-- TASK 284: one boar kind, broadside, 12 studs in front of the PLAYER, the fifteen zone volumes
-- drawn over the drawn mesh. `reviews/task-282/probes/282-pose.luau` with one addition: V280 asks the
-- staging probe to SELF-CHECK its own offsets before a frame counts, so it reports each zone part's
-- measured offset from the trunk against the config's and the worst drift between them.
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Loader = require(ServerStorage.Assets:WaitForChild("Loader"))
local Assets = require(ServerStorage:WaitForChild("Assets"))
local KIND = _G.DH284_POSEKIND or "male"
local DIST = _G.DH284_POSEDIST or 12
local KEYS = { male = Assets.KEYS.boarMale, female = Assets.KEYS.boarFemale, cub = Assets.KEYS.boarCub, legendary = Assets.KEYS.boarMale }
local plr = Players:GetPlayers()[1]
local ch = plr and plr.Character
local head = ch and ch:FindFirstChild("Head")
if not head then return "no head" end
local old = Workspace:FindFirstChild("Pose284")
if old then old:Destroy() end
local holder = Instance.new("Folder") holder.Name = "Pose284" holder.Parent = Workspace
local fwd = (head.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
local right = Vector3.new(-fwd.Z, 0, fwd.X)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { ch, holder }
local spot = head.Position + fwd * DIST
local g = Workspace:Raycast(spot + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), params)
local groundY = if g then g.Position.Y else head.Position.Y - 4
Loader.preload({ KEYS[KIND] })
local template = Loader.template(KEYS[KIND])
local runtime = Boar.newRuntime({
	field = { bounds = { minX = -4000, maxX = 4000, minZ = -4000, maxZ = 4000 }, exitZ = -3900, groundY = groundY },
	parent = holder, folderName = "P_" .. KIND, rng = Random.new(284),
	config = { KINDS = { ENABLED = true } },
	threats = function() return {} end, probe = function() return false end,
	requestPath = function(_i, _f, _t, done) done(nil) end, releasePath = function() end,
})
runtime:setModelSource(function() return template end, function() return nil end)
local handle = runtime:spawn(Vector3.new(spot.X, groundY, spot.Z), KIND)
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
local c = Vector3.new(spot.X, groundY + trunk.Size.Y / 2, spot.Z)
trunk.CFrame = CFrame.lookAt(c, c + right)
task.wait(0.25)
local n = 0
for _, z in ipairs(trunk:GetChildren()) do
	if z:IsA("BasePart") and z:GetAttribute("HitZone") then z.Transparency = 0.78 z.Material = Enum.Material.Neon n += 1 end
end
trunk.Transparency = 0.86 trunk.Material = Enum.Material.Neon trunk.Color = Color3.fromRGB(255, 255, 255)
for _, m in ipairs(meshes) do m.Transparency = 0 end
-- THE SELF-CHECK (V280): every part's LIVE offset from the trunk, in the trunk's frame, against the
-- config's own number. A frame of an animal whose boxes have drifted proves nothing.
local geometry = Boar.kindGeometry(KIND, Boar.CONFIG)
local worst, worstName = 0, "none"
local checked = 0
for _, zone in ipairs(geometry.zoneOrder) do
	local spec = geometry.zones[zone]
	for index, box in ipairs(spec.boxes) do
		local name = if #spec.boxes == 1 then spec.part else spec.part .. index
		local part = trunk:FindFirstChild(name)
		if part then
			local live = trunk.CFrame:PointToObjectSpace(part.Position)
			local drift = (live - box.offset).Magnitude
			local sizeDrift = (part.Size - box.size).Magnitude
			drift = math.max(drift, sizeDrift)
			checked += 1
			if drift > worst then worst, worstName = drift, name end
		else
			worst, worstName = math.huge, name .. " MISSING"
		end
	end
end
return string.format("%s broadside at %.1f studs: %d zone volumes + trunk %.2f,%.2f,%.2f drawn, meshes=%d | self-check: %d of %d parts, worst drift %.4f on %s",
	KIND, (trunk.Position - head.Position).Magnitude, n, trunk.Size.X, trunk.Size.Y, trunk.Size.Z, #meshes,
	checked, #trunk:GetChildren(), worst, worstName)
