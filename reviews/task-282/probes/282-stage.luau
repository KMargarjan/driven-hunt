-- TASK 282: a FROZEN BROADSIDE MALE BOAR at 88.7 studs, the aim point on ZoneChest, log cleared.
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Loader = require(ServerStorage.Assets:WaitForChild("Loader"))
local Assets = require(ServerStorage:WaitForChild("Assets"))
local KIND = (_G.DH282_KIND or "male")
local KEYS = { male = Assets.KEYS.boarMale, female = Assets.KEYS.boarFemale, cub = Assets.KEYS.boarCub, legendary = Assets.KEYS.boarMale }
local plr = Players:GetPlayers()[1]
local ch = plr and plr.Character
local head = ch and ch:FindFirstChild("Head")
if not head then return "no player head" end
local old = Workspace:FindFirstChild("Stage282")
if old then old:Destroy() end
local holder = Instance.new("Folder") holder.Name = "Stage282" holder.Parent = Workspace
-- FREEZE THE SHOOTER: the Forest Test walks a hunter to his stand, and a player who moves 60 studs
-- sideways after staging turns a broadside boar into a 35-degree quartering one (measured, 282).
local root = ch:FindFirstChild("HumanoidRootPart")
local hum = ch:FindFirstChildOfClass("Humanoid")
if hum then hum.WalkSpeed = 0 hum.AutoRotate = false end
if root then root.Anchored = true end
local fwd = (head.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
local right = Vector3.new(-fwd.Z, 0, fwd.X)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { ch, holder }
local spot = head.Position + fwd * 88.7
local g = Workspace:Raycast(spot + Vector3.new(0, 120, 0), Vector3.new(0, -400, 0), params)
local groundY = if g then g.Position.Y else head.Position.Y - 4
Loader.preload({ KEYS[KIND] })
local template = Loader.template(KEYS[KIND])
local runtime = Boar.newRuntime({
	field = { bounds = { minX = -4000, maxX = 4000, minZ = -4000, maxZ = 4000 }, exitZ = -3900, groundY = groundY },
	parent = holder, folderName = "S_" .. KIND, rng = Random.new(282),
	config = { KINDS = { ENABLED = true } },
	threats = function() return {} end, probe = function() return false end,
	requestPath = function(_i, _f, _t, done) done(nil) end, releasePath = function() end,
})
runtime:setModelSource(function(k) return if k == KIND then template else nil end, function() return nil end)
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
task.wait(0.4)
if disconnect then disconnect() end
for _, d in ipairs(trunk:GetDescendants()) do if d:IsA("Animator") or d:IsA("AnimationController") then d:Destroy() end end
for _, d in ipairs(trunk:GetDescendants()) do if d:IsA("Bone") then d.Transform = CFrame.new() end end
task.wait()
-- broadside: the animal's -Z (its front) points along `right`, so its flank faces the player
local c = Vector3.new(spot.X, groundY + trunk.Size.Y / 2, spot.Z)
-- THE BOAR S OWN AlignOrientation SNAPS IT BACK TO ITS BRAIN S HEADING (Body.create, the upright
-- constraint), so a posed CFrame set while the trunk is live lasts a tick. Take the movers out
-- first, anchor, THEN pose: measured 282 -- a broadside boar came back 80 degrees off.
for _, d in ipairs(trunk:GetDescendants()) do
	if d:IsA("LinearVelocity") or d:IsA("AlignOrientation") or d:IsA("AlignPosition") then d.Enabled = false end
end
trunk.AssemblyLinearVelocity = Vector3.zero
trunk.Anchored = true
task.wait(0.1)
trunk.CFrame = CFrame.lookAt(c, c + right)
task.wait(0.3)
local out = {}
local worst = 0
for _, z in ipairs(trunk:GetDescendants()) do
	if z:IsA("BasePart") and z:GetAttribute("HitZone") then
		worst = math.max(worst, (z.Position - trunk.Position).Magnitude)
		local lp = trunk.CFrame:PointToObjectSpace(z.Position)
		table.insert(out, string.format("  %s %s size=%.2f,%.2f,%.2f off=%.2f,%.2f,%.2f", z.Name, tostring(z:GetAttribute("HitZone")), z.Size.X, z.Size.Y, z.Size.Z, lp.X, lp.Y, lp.Z))
	end
end
-- the aim point: the CENTRE of ZoneChest, in world
local chestPart = nil
for _, z in ipairs(trunk:GetDescendants()) do
	if z:IsA("BasePart") and z:GetAttribute("HitZone") == "chest" then chestPart = z end
end
local aim = if chestPart then chestPart.Position else trunk.Position
plr:SetAttribute("DH282_aim", aim)
plr:SetAttribute("DH282_trunk", trunk.Position)
-- THE RING IS AN ATTRIBUTE ON ServerStorage, NOT A CHILD (HitLog.writeTrace). Round 1 looked for a
-- StringValue, cleared nothing, and two shots 75 s apart shared one ring (the Reviewer, round 1).
ServerStorage:SetAttribute("DHLastHits", nil)
local last = ServerStorage:GetAttribute("DHLastHits")
-- the DRAWN animal's own extent, in the trunk's frame, by raycasting the mesh (280's instrument)
for _, m in ipairs(meshes) do m.CanQuery = true end
local mp = RaycastParams.new() mp.FilterType = Enum.RaycastFilterType.Include mp.FilterDescendantsInstances = meshes
local cf = trunk.CFrame
local minZ, maxZ, minY, maxY, minX, maxX = 9e9, -9e9, 9e9, -9e9, 9e9, -9e9
for z = -4, 4, 0.05 do
	for y = -2.5, 3, 0.05 do
		local o = cf:PointToWorldSpace(Vector3.new(6, y, z))
		local r = Workspace:Raycast(o, cf:VectorToWorldSpace(Vector3.new(-1, 0, 0)) * 14, mp)
		if r then
			local lp = cf:PointToObjectSpace(r.Position)
			minZ = math.min(minZ, z) maxZ = math.max(maxZ, z)
			minY = math.min(minY, y) maxY = math.max(maxY, y)
			minX = math.min(minX, lp.X) maxX = math.max(maxX, lp.X)
		end
	end
end
for _, m in ipairs(meshes) do m.CanQuery = false end
-- LINE OF SIGHT, IN THE SAME PROBE: what the camera ray meets first, and at what angle
local lp = RaycastParams.new()
lp.FilterType = Enum.RaycastFilterType.Exclude
lp.FilterDescendantsInstances = { ch }
local rdir = (aim - head.Position).Unit
local rr = Workspace:Raycast(head.Position, rdir * 200, lp)
local losLine = "LOS: nothing"
if rr then
	local e = cf:PointToObjectSpace(rr.Position)
	local ldir = cf:VectorToObjectSpace(rdir)
	losLine = string.format("LOS: %s zone=%s d=%.2f entry local=(%.2f,%.2f,%.2f) raydir local=(%.3f,%.3f,%.3f)",
		rr.Instance.Name, tostring(rr.Instance:GetAttribute("HitZone")), (rr.Position - head.Position).Magnitude,
		e.X, e.Y, e.Z, ldir.X, ldir.Y, ldir.Z)
end
return losLine .. string.char(10) .. string.format("kind=%s trunk %.2f,%.2f,%.2f at %.1f studs\nzones:\n%s\nworst zone gap %.2f studs\nDRAWN flank extent: z %.2f..%.2f  y %.2f..%.2f  x %.2f..%.2f\naim(chest centre) %.2f,%.2f,%.2f\nmeshes=%d log cleared=%s",
	KIND, trunk.Size.X, trunk.Size.Y, trunk.Size.Z, (trunk.Position - head.Position).Magnitude,
	table.concat(out, "\n"), worst, minZ, maxZ, minY, maxY, minX, maxX, aim.X, aim.Y, aim.Z, #meshes, tostring(last == nil))
