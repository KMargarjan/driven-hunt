-- TASK 284: THE DRAWN BOAR'S OWN PROFILE, per kind, by ray. Nothing is fitted here: this is the
-- measurement the box cages are then drawn around (L-028: every box edge measured before it goes
-- into the config). Back line, belly line and leg footprints, in the TRUNK's frame.
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Loader = require(ServerStorage.Assets:WaitForChild("Loader"))
local Assets = require(ServerStorage:WaitForChild("Assets"))
local KEYS = { male = Assets.KEYS.boarMale, female = Assets.KEYS.boarFemale, cub = Assets.KEYS.boarCub }
local KINDS = _G.DH284_KINDS or { "male", "female", "cub" }
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
	for _, c in ipairs(trunk:GetChildren()) do if c:IsA("BasePart") then c.CanQuery = false end end
	trunk.CanQuery = false
	for _, m in ipairs(meshes) do m.CanQuery = true end
	return trunk, meshes
end

for _, KIND in ipairs(KINDS) do
	local old = Workspace:FindFirstChild("Prof284")
	if old then old:Destroy() end
	local holder = Instance.new("Folder")
	holder.Name = "Prof284"
	holder.Parent = Workspace
	local trunk, meshes = stage(KIND, holder)
	if trunk == nil then
		table.insert(out, KIND .. ": NO MESH DREW")
	else
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = meshes
		local cf = trunk.CFrame
		local hx, hy, hz = trunk.Size.X / 2, trunk.Size.Y / 2, trunk.Size.Z / 2
		local REACH = math.max(trunk.Size.X, trunk.Size.Y, trunk.Size.Z) + 16
		local function hit(from, dir)
			return Workspace:Raycast(cf:PointToWorldSpace(from), cf:VectorToWorldSpace(dir.Unit) * REACH, params)
		end
		local function hitAt(from, dir, reach)
			return Workspace:Raycast(cf:PointToWorldSpace(from), cf:VectorToWorldSpace(dir.Unit) * reach, params) ~= nil
		end
		local mesh = meshes[1]
		table.insert(out, string.format("#### %s trunk %.3f,%.3f,%.3f  drawn %.3f,%.3f,%.3f", KIND,
			trunk.Size.X, trunk.Size.Y, trunk.Size.Z, mesh.Size.X, mesh.Size.Y, mesh.Size.Z))
		-- THE DRAWN BOX IN THE TRUNK'S FRAME: the mesh's own centre, so y top/bottom are absolute.
		local c = cf:PointToObjectSpace(mesh.Position)
		table.insert(out, string.format("mesh centre in trunk frame %.3f,%.3f,%.3f -> y %.3f..%.3f  z %.3f..%.3f  x %.3f..%.3f",
			c.X, c.Y, c.Z, c.Y - mesh.Size.Y / 2, c.Y + mesh.Size.Y / 2,
			c.Z - mesh.Size.Z / 2, c.Z + mesh.Size.Z / 2, c.X - mesh.Size.X / 2, c.X + mesh.Size.X / 2))
		-- THE BACK LINE AND THE FLANK'S FLOOR, per z: the highest and lowest y at which a FLANK ray
		-- still meets the mesh. The floor is a hoof where a leg stands and the belly where none does.
		local STEP = 0.04
		local rows = {}
		local z = -hz - 0.2
		while z <= hz + 0.2 + 1e-9 do
			local top, bot = nil, nil
			local y = -hy - 0.2
			while y <= hy + 1.4 + 1e-9 do
				if hitAt(Vector3.new(hx + 6, y, z), Vector3.new(-1, 0, 0), REACH) then
					if bot == nil then bot = y end
					top = y
				end
				y += STEP
			end
			-- THE BELLY AT THE CENTRE PLANE: a ray fired UP at x = 0 meets the barrel's underside,
			-- because no boar leg stands at x = 0.
			local up = hit(Vector3.new(0, -hy - 4, z), Vector3.new(0, 1, 0))
			local belly = if up then cf:PointToObjectSpace(up.Position).Y else nil
			-- HALF-WIDTH: the widest |x| at which a ray from ABOVE still meets the mesh.
			local wide = 0
			local x = 0
			while x <= hx + 0.3 + 1e-9 do
				if hitAt(Vector3.new(x, hy + 6, z), Vector3.new(0, -1, 0), REACH) then wide = x end
				x += STEP
			end
			table.insert(rows, string.format("z%+.2f top=%s bot=%s belly=%s halfw=%.2f", z,
				if top then string.format("%.2f", top) else "none",
				if bot then string.format("%.2f", bot) else "none",
				if belly then string.format("%.2f", belly) else "none", wide))
			z += 0.2
		end
		table.insert(out, table.concat(rows, "  "))
		-- THE FOUR FEET: where is there mesh BELOW the barrel? A downward ray from just under the
		-- measured belly, over the whole footprint, so a leg shaft is a cell and the air between the
		-- legs is not.
		local legRows = {}
		z = -hz
		while z <= hz + 1e-9 do
			local lo, hi, deepest = nil, nil, nil
			local x = -hx - 0.2
			while x <= hx + 0.2 + 1e-9 do
				local r = hit(Vector3.new(x, -hy * 0.45, z), Vector3.new(0, -1, 0))
				if r then
					local p = cf:PointToObjectSpace(r.Position)
					if p.Y < -hy * 0.5 then
						lo = if lo then math.min(lo, x) else x
						hi = if hi then math.max(hi, x) else x
						deepest = if deepest then math.min(deepest, p.Y) else p.Y
					end
				end
				x += STEP
			end
			if lo then
				table.insert(legRows, string.format("z%+.2f x %.2f..%.2f low %.2f", z, lo, hi, deepest))
			end
			z += 0.1
		end
		table.insert(out, "FEET (mesh below the barrel): " .. table.concat(legRows, " | "))
		for _, m in ipairs(meshes) do m.CanQuery = false end
	end
end
local old = Workspace:FindFirstChild("Prof284")
if old then old:Destroy() end
return table.concat(out, string.char(10))
