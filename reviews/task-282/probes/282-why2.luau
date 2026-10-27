-- Round 2: the Reviewer says a flank ray at y ~ 1.70 must be mesh-and-no-box. Print the top rows.
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Loader = require(ServerStorage.Assets:WaitForChild("Loader"))
local Assets = require(ServerStorage:WaitForChild("Assets"))
local old = Workspace:FindFirstChild("Why282")
if old then old:Destroy() end
local holder = Instance.new("Folder") holder.Name = "Why282" holder.Parent = Workspace
local GROUND_Y = 900
Loader.preload({ Assets.KEYS.boarMale })
local template = Loader.template(Assets.KEYS.boarMale)
local runtime = Boar.newRuntime({
	field = { bounds = { minX = -60, maxX = 60, minZ = -60, maxZ = 60 }, exitZ = -55, groundY = GROUND_Y },
	parent = holder, folderName = "W", rng = Random.new(282),
	config = { KINDS = { ENABLED = true } },
	threats = function() return {} end, probe = function() return false end,
	requestPath = function(_i, _f, _t, done) done(nil) end, releasePath = function() end,
})
runtime:setModelSource(function() return template end, function() return nil end)
local handle = runtime:spawn(Vector3.new(0, GROUND_Y, 0), "male")
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
for _, m in ipairs(meshes) do m.CanQuery = true end
local hittable = {}
for _, d in ipairs(trunk:GetDescendants()) do
	if d:IsA("BasePart") and d:GetAttribute("HitZone") then table.insert(hittable, d) end
end
if trunk:GetAttribute("ZonesOnly") ~= true and trunk:GetAttribute("HitZone") then table.insert(hittable, trunk) end
local out = {}
table.insert(out, "mesh part: " .. meshes[1]:GetFullName() .. " size " .. tostring(meshes[1].Size) .. " canq=" .. tostring(meshes[1].CanQuery))
local lp = trunk.CFrame:PointToObjectSpace(meshes[1].Position)
table.insert(out, string.format("mesh centre in trunk frame: %.3f,%.3f,%.3f -> top %.3f bottom %.3f",
	lp.X, lp.Y, lp.Z, lp.Y + meshes[1].Size.Y / 2, lp.Y - meshes[1].Size.Y / 2))
for _, h in ipairs(hittable) do
	local o = trunk.CFrame:PointToObjectSpace(h.Position)
	table.insert(out, string.format("  hittable %-9s top %.3f (centre y %.2f, size y %.2f)", h.Name, o.Y + h.Size.Y / 2, o.Y, h.Size.Y))
end
local mp = RaycastParams.new() mp.FilterType = Enum.RaycastFilterType.Include mp.FilterDescendantsInstances = meshes
local bp = RaycastParams.new() bp.FilterType = Enum.RaycastFilterType.Include bp.FilterDescendantsInstances = hittable
local cf = trunk.CFrame
local hz = trunk.Size.Z / 2
-- (1) THE BACK LINE AS A FUNCTION OF z: the highest y at which a FLANK ray still meets the mesh.
table.insert(out, "back line (highest y the flank ray still meets the drawn mesh), by z:")
local line = {}
for z = -2.8, 2.8, 0.2 do
	local top = nil
	local y = 2.0
	while y >= -1.6 do
		local o = cf:PointToWorldSpace(Vector3.new(7, y, z))
		if Workspace:Raycast(o, cf:VectorToWorldSpace(Vector3.new(-1, 0, 0)) * 22, mp) then top = y break end
		y -= 0.02
	end
	table.insert(line, string.format("z%+.1f=%s", z, if top then string.format("%.2f", top) else "none"))
end
table.insert(out, "  " .. table.concat(line, " "))
-- (2) THE EXACT PELLET: the hitlog row #1 point, cast from the flank against the MESH alone.
for _, pt in ipairs({ { 1.41, -0.21 }, { 1.40, 0.16 } }) do
	local o = cf:PointToWorldSpace(Vector3.new(7, pt[1], pt[2]))
	local d = cf:VectorToWorldSpace(Vector3.new(-1, 0, 0)) * 22
	local rm = Workspace:Raycast(o, d, mp)
	local rb = Workspace:Raycast(o, d, bp)
	table.insert(out, string.format("hitlog point y=%.2f z=%.2f : MESH %s | BOX %s", pt[1], pt[2],
		if rm then string.format("HIT at local x %.3f", cf:PointToObjectSpace(rm.Position).X) else "NO HIT (air)",
		if rb then rb.Instance.Name else "none"))
end
return table.concat(out, string.char(10))
