-- TASK 283: the DRAWN extent of every kind that draws a card, in its TRUNK's own frame -- the one
-- measurement the card's rectangle needs. Reuses task 282's load/freeze route (282-fit2.luau).
-- Prints, per kind: the trunk box, the drawn mesh AABB, and the rectangle the TRUNK occupies inside
-- that AABB (which is what the picture's box must be, because the picture is cropped to the ink).
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
local old = Workspace:FindFirstChild("Ext283")
if old then
	old:Destroy()
end
local holder = Instance.new("Folder")
holder.Name = "Ext283"
holder.Parent = Workspace
for _, kind in ipairs({ "male", "female", "cub", "legendary", "stag", "hind", "calf" }) do
	local okKey = KEYS[kind]
	Loader.preload({ okKey })
	local template = Loader.template(okKey)
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
	-- Freeze exactly as 282 did: no animator, no bone transform, anchored, at the origin.
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
	local minv, maxv = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	for _, mesh in ipairs(meshes) do
		local half = mesh.Size / 2
		for sx = -1, 1, 2 do
			for sy = -1, 1, 2 do
				for sz = -1, 1, 2 do
					local corner = mesh.CFrame * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
					local lp = cf:PointToObjectSpace(corner)
					minv = Vector3.new(math.min(minv.X, lp.X), math.min(minv.Y, lp.Y), math.min(minv.Z, lp.Z))
					maxv = Vector3.new(math.max(maxv.X, lp.X), math.max(maxv.Y, lp.Y), math.max(maxv.Z, lp.Z))
				end
			end
		end
	end
	local size = maxv - minv
	local t = trunk.Size
	local function clamp01(n)
		return math.clamp(n, 0, 1)
	end
	local u0 = clamp01((-t.Z / 2 - minv.Z) / math.max(1e-6, size.Z))
	local u1 = clamp01((t.Z / 2 - minv.Z) / math.max(1e-6, size.Z))
	local v0 = clamp01((maxv.Y - t.Y / 2) / math.max(1e-6, size.Y))
	local v1 = clamp01((maxv.Y + t.Y / 2) / math.max(1e-6, size.Y))
	table.insert(
		lines,
		string.format(
			"%-9s trunk %.3f,%.3f,%.3f | drawn %.3f,%.3f,%.3f | local y %.3f..%.3f z %.3f..%.3f x %.3f..%.3f | TRUNK-IN-INK u %.4f..%.4f v %.4f..%.4f | meshes %d",
			kind,
			t.X,
			t.Y,
			t.Z,
			size.X,
			size.Y,
			size.Z,
			minv.Y,
			maxv.Y,
			minv.Z,
			maxv.Z,
			minv.X,
			maxv.X,
			u0,
			u1,
			v0,
			v1,
			#meshes
		)
	)
	holder:ClearAllChildren()
	task.wait(0.2)
end
return table.concat(lines, "\n")
