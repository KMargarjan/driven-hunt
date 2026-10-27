-- TASK 283: FOUR POINTS ON EACH KIND'S DRAWN FLANK, found by ray and not by guess -- the inputs the
-- card spec needs. Same load/freeze route as `283-extent.luau`; the ray is the one `282-why2.luau`
-- used (a flank ray at a given y, z, against the MESH only).
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Loader = require(ServerStorage.Assets:WaitForChild("Loader"))
local Assets = require(ServerStorage:WaitForChild("Assets"))
local KEYS = {
	male = Assets.KEYS.boarMale,
	female = Assets.KEYS.boarFemale,
	cub = Assets.KEYS.boarCub,
	legendary = Assets.KEYS.boarMale,
	stag = Assets.KEYS.deerStag,
	hind = Assets.KEYS.deerHind,
	calf = Assets.KEYS.deerCalf,
}
local GROUND_Y = 900
local lines = {}
local old = Workspace:FindFirstChild("Flank283")
if old then
	old:Destroy()
end
local holder = Instance.new("Folder")
holder.Name = "Flank283"
holder.Parent = Workspace
for _, kind in ipairs({ "male", "female", "cub", "legendary", "stag", "hind", "calf" }) do
	Loader.preload({ KEYS[kind] })
	local template = Loader.template(KEYS[kind])
	local runtime = Boar.newRuntime({
		field = { bounds = { minX = -80, maxX = 80, minZ = -80, maxZ = 80 }, exitZ = -75, groundY = GROUND_Y },
		parent = holder,
		folderName = "K" .. kind,
		rng = Random.new(283),
		config = { KINDS = { ENABLED = true } },
		threats = function()
			return {}
		end,
		probe = function()
			return false
		end,
		requestPath = function(_i, _f, _t, done)
			done(nil)
		end,
		releasePath = function() end,
	})
	runtime:setModelSource(function()
		return template
	end, function()
		return nil
	end)
	local handle = runtime:spawn(Vector3.new(0, GROUND_Y, 0), kind)
	local trunk = handle and handle.part
	local disconnect = runtime:run()
	local meshes = {}
	local t0 = os.clock()
	while os.clock() - t0 < 12 do
		meshes = {}
		if trunk then
			for _, d in ipairs(trunk:GetDescendants()) do
				if d:IsA("MeshPart") then
					table.insert(meshes, d)
				end
			end
		end
		if #meshes > 0 then
			break
		end
		task.wait(0.15)
	end
	task.wait(0.3)
	if disconnect then
		disconnect()
	end
	if trunk == nil or #meshes == 0 then
		table.insert(lines, kind .. ": NO MESH DREW")
		continue
	end
	for _, d in ipairs(trunk:GetDescendants()) do
		if d:IsA("Animator") or d:IsA("AnimationController") then
			d:Destroy()
		end
	end
	for _, d in ipairs(trunk:GetDescendants()) do
		if d:IsA("Bone") then
			d.Transform = CFrame.new()
		end
	end
	for _, d in ipairs(trunk:GetDescendants()) do
		if d:IsA("LinearVelocity") or d:IsA("AlignOrientation") then
			d.Enabled = false
		end
	end
	trunk.Anchored = true
	task.wait(0.15)
	trunk.CFrame = CFrame.new(0, GROUND_Y, 0)
	task.wait(0.3)
	local cf = trunk.CFrame
	local t = trunk.Size
	local mp = RaycastParams.new()
	mp.FilterType = Enum.RaycastFilterType.Include
	mp.FilterDescendantsInstances = meshes
	local REACH = math.max(t.X, t.Y, t.Z) + 20
	-- THE DRAWN MESH IS `CanQuery = false` SO SHOTS REACH THE ZONE BOXES THROUGH IT (that is why
	-- `282-fit2.luau` toggles it between its two passes). Turned on here, on the frozen copy only.
	for _, mesh in ipairs(meshes) do
		mesh.CanQuery = true
	end
	local function meshAt(y: number, z: number): (boolean, number)
		local from = cf * Vector3.new(t.X / 2 + 8, y, z)
		local hit = Workspace:Raycast(from, (cf.RightVector * -1) * REACH, mp)
		if hit == nil then
			return false, 0
		end
		return true, cf:PointToObjectSpace(hit.Position).X
	end
	-- THE MESH'S TOP AND BOTTOM AT ONE z, by stepping a flank ray -- `282-why2.luau`'s instrument.
	local function span(z: number): (number?, number?)
		local top, bottom = nil, nil
		local y = t.Y * 1.3
		while y > -t.Y * 0.8 do
			local ok = meshAt(y, z)
			if ok then
				if top == nil then
					top = y
				end
				bottom = y
			end
			y -= 0.02 * t.Y
		end
		return top, bottom
	end
	local out = { kind }
	-- Four stations along the body, and a fraction DOWN the mesh's own span at each: the withers
	-- (just under the back), the chest, the belly line, the rump.
	local STATIONS = {
		{ "withers", -0.22, 0.12 },
		{ "chest", -0.10, 0.45 },
		{ "belly", 0.02, 0.88 },
		{ "rump", 0.28, 0.35 },
	}
	for _, s in ipairs(STATIONS) do
		local z = s[2] * t.Z
		local top, bottom = span(z)
		if top == nil or bottom == nil then
			table.insert(out, string.format("%s z=%.3f NO MESH", s[1], z))
		else
			local y = top - s[3] * (top - bottom)
			local ok, x = meshAt(y, z)
			local u = math.clamp(z / t.Z + 0.5, 0, 1)
			local v = math.clamp(0.5 - y / t.Y, 0, 1)
			table.insert(
				out,
				string.format(
					"%s local=(%.3f,%.3f,%.3f) MESH=%s span y %.3f..%.3f uv=(%.4f,%.4f)",
					s[1],
					x,
					y,
					z,
					tostring(ok),
					bottom,
					top,
					u,
					v
				)
			)
		end
	end
	-- ...AND ONE POINT THAT IS NOT THE ANIMAL: above the crest at mid-body.
	local topMid = span(0)
	local air = (topMid or t.Y / 2) + 0.35 * t.Y
	local okAir = meshAt(air, 0)
	table.insert(
		out,
		string.format("AIR local=(0,%.3f,0) MESH=%s uv=(%.4f,%.4f)", air, tostring(okAir), 0.5, math.clamp(0.5 - air / t.Y, 0, 1))
	)
	table.insert(lines, table.concat(out, " | "))
	holder:ClearAllChildren()
	task.wait(0.2)
end
return table.concat(lines, "\n")
