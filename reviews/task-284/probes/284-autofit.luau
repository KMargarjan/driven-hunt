-- TASK 284 AUTO-FIT, the instrument task 280 used on the deer (`<runs-dir>/280-autofit.luau`).
-- It casts the drawn mesh's THREE silhouettes -- (y,z) from the flank, (x,z) from above, (x,y) from
-- the front -- then grows each box one grid step at a time from a seed, accepting a step only while
-- all three of the box's projections still lie INSIDE the matching silhouette. A box like that
-- cannot be hit by an axis ray that misses the mesh, which is what AIR = 0 means.
--
-- The CAGES are FRACTIONS of each kind's own measured drawn box (`284-profile.luau`), not the male's
-- studs scaled: fz runs 0 at the nose to 1 at the tail, fy 0 at the hooves to 1 at the back line,
-- fx is a fraction of the half-width. The three boar meshes are not one mesh at three sizes.
-- THE SPANS, as FRACTIONS of each kind's own measured drawn box (`284-profile.luau`), nose 0 to
-- tail 1. Not the male's studs scaled: the three boar meshes are three models.
--   `band = true` carves the top `BAND` studs of the slab off as a separate DORSAL box, which is
--   `body` over the chest exactly as task 281's bands are `body` over the deer's thorax -- a shot
--   along the top of the back is not the heart. Its floor is the MEASURED minimum back line over
--   the span, so the band is inside the drawn back at every z it covers.
local SPANS = {
	{ zone = "head", fz0 = 0.000, fz1 = 0.145, fy0 = 0.430, fy1 = 0.880, fx0 = -0.80, fx1 = 0.80 }, -- the snout
	{ zone = "head", fz0 = 0.080, fz1 = 0.245, fy0 = 0.400, fy1 = 1.000, fx0 = -0.90, fx1 = 0.90 }, -- the skull
	{ zone = "chest", fz0 = 0.237, fz1 = 0.418, band = "body" }, -- the shoulder, and the crest over it
	{ zone = "chest", fz0 = 0.418, fz1 = 0.545, band = "body" }, -- heart and lungs, to today's chest line
	{ zone = "body", fz0 = 0.545, fz1 = 0.623 }, -- THE BARREL BAND THAT IS TRUNK-ONLY TODAY
	{ zone = "body", fz0 = 0.623, fz1 = 0.700 }, -- ...to today's rear line
	{ zone = "rear", fz0 = 0.700, fz1 = 0.764 }, -- the hindquarters; its own top IS `rear`, as the deer's croup is
	{ zone = "rear", fz0 = 0.764, fz1 = 0.827 },
	{ zone = "rear", fz0 = 0.827, fz1 = 0.872 },
	{ zone = "legs", fz0 = 0.270, fz1 = 0.420, fy0 = 0.000, fy1 = 0.340, fx0 = -1.00, fx1 = -0.04 },
	{ zone = "legs", fz0 = 0.270, fz1 = 0.420, fy0 = 0.000, fy1 = 0.340, fx0 = 0.04, fx1 = 1.00 },
	{ zone = "legs", fz0 = 0.660, fz1 = 0.830, fy0 = 0.000, fy1 = 0.340, fx0 = -1.00, fx1 = -0.04 },
	{ zone = "legs", fz0 = 0.660, fz1 = 0.830, fy0 = 0.000, fy1 = 0.340, fx0 = 0.04, fx1 = 1.00 },
}
local STEP = 0.04
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
	local old = Workspace:FindFirstChild("Auto284")
	if old then old:Destroy() end
	local holder = Instance.new("Folder")
	holder.Name = "Auto284"
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
		local function shot(from, dir)
			return Workspace:Raycast(cf:PointToWorldSpace(from), cf:VectorToWorldSpace(dir) * REACH, params) ~= nil
		end
		local mesh = meshes[1]
		local c = cf:PointToObjectSpace(mesh.Position)
		local Z0, Z1 = c.Z - mesh.Size.Z / 2, c.Z + mesh.Size.Z / 2
		local Y0, Y1 = c.Y - mesh.Size.Y / 2, c.Y + mesh.Size.Y / 2
		local HW = mesh.Size.X / 2
		local function axis(lo, hi)
			local t = {}
			local v = lo
			while v <= hi + 1e-9 do
				table.insert(t, v)
				v += STEP
			end
			return t
		end
		local XS = axis(-hx - 0.2, hx + 0.2)
		local YS = axis(-hy - 0.2, hy + 1.4)
		local ZS = axis(-hz - 0.3, hz + 0.3)
		local flank, top, front = {}, {}, {}
		for iy, y in ipairs(YS) do
			flank[iy] = {}
			for iz, z in ipairs(ZS) do
				flank[iy][iz] = shot(Vector3.new(hx + 6, y, z), Vector3.new(-1, 0, 0))
			end
		end
		for ix, x in ipairs(XS) do
			top[ix] = {}
			for iz, z in ipairs(ZS) do
				top[ix][iz] = shot(Vector3.new(x, hy + 7, z), Vector3.new(0, -1, 0))
			end
		end
		for ix, x in ipairs(XS) do
			front[ix] = {}
			for iy, y in ipairs(YS) do
				front[ix][iy] = shot(Vector3.new(x, y, -hz - 7), Vector3.new(0, 0, 1))
			end
		end
		table.insert(out, string.format("#### %s trunk %.3f,%.3f,%.3f  drawn y %.3f..%.3f z %.3f..%.3f halfw %.3f  grid %dx%dx%d",
			KIND, trunk.Size.X, trunk.Size.Y, trunk.Size.Z, Y0, Y1, Z0, Z1, HW, #XS, #YS, #ZS))
		local function cells(list, lo, hi)
			local t = {}
			for i, v in ipairs(list) do
				if v >= lo - 1e-9 and v <= hi + 1e-9 then table.insert(t, i) end
			end
			return t
		end
		local function inside(x0, x1, y0, y1, z0, z1)
			local ixs, iys, izs = cells(XS, x0, x1), cells(YS, y0, y1), cells(ZS, z0, z1)
			if #ixs == 0 or #iys == 0 or #izs == 0 then return false end
			for _, iy in ipairs(iys) do
				for _, iz in ipairs(izs) do
					if not flank[iy][iz] then return false end
				end
			end
			for _, ix in ipairs(ixs) do
				for _, iz in ipairs(izs) do
					if not top[ix][iz] then return false end
				end
			end
			for _, ix in ipairs(ixs) do
				for _, iy in ipairs(iys) do
					if not front[ix][iy] then return false end
				end
			end
			return true
		end
		-- EVERY SPAN'S Z EDGES ARE SNAPPED TO THE GRID, so two neighbouring slabs share a face
		-- instead of leaving a one-cell strip of unanswered animal between them.
		local function snapZ(v)
			local i = math.floor((v - ZS[1]) / STEP + 0.5)
			return ZS[1] + math.clamp(i, 0, #ZS - 1) * STEP
		end
		-- THE MEASURED BACK LINE over a z span: the highest y at which a FLANK ray still meets the
		-- mesh, taken at its WORST (lowest) z in the span, so a band built on it is inside the drawn
		-- back everywhere it reaches.
		local function backMin(z0, z1)
			local worst = nil
			for _, iz in ipairs(cells(ZS, z0, z1)) do
				local top = nil
				for iy = #YS, 1, -1 do
					if flank[iy][iz] then top = YS[iy] break end
				end
				if top == nil then return nil end
				worst = if worst then math.min(worst, top) else top
			end
			return worst
		end
		local BAND = 3 * STEP
		local function grow(zone, cx0, cx1, cy0, cy1, cz0, cz1, note)
			local mx, my, mz = (cx0 + cx1) / 2, (cy0 + cy1) / 2, (cz0 + cz1) / 2
			local seed, best = nil, math.huge
			for _, ix in ipairs(cells(XS, cx0, cx1)) do
				for _, iy in ipairs(cells(YS, cy0, cy1)) do
					for _, iz in ipairs(cells(ZS, cz0, cz1)) do
						local x, y, z = XS[ix], YS[iy], ZS[iz]
						if inside(x, x, y, y, z, z) then
							local d = ((x - mx) / math.max(cx1 - cx0, 1e-3)) ^ 2
								+ ((y - my) / math.max(cy1 - cy0, 1e-3)) ^ 2
								+ ((z - mz) / math.max(cz1 - cz0, 1e-3)) ^ 2
							if d < best then best, seed = d, { x, y, z } end
						end
					end
				end
			end
			if seed == nil then
				table.insert(out, string.format("  -- %s %s: NO SEED in cage y %.3f..%.3f z %.3f..%.3f", zone, note, cy0, cy1, cz0, cz1))
				return
			end
			local x0, x1, y0, y1, z0, z1 = seed[1], seed[1], seed[2], seed[2], seed[3], seed[3]
			local grew, guard = true, 0
			while grew and guard < 400 do
				grew = false
				guard += 1
				if x1 + STEP <= cx1 + 1e-9 and inside(x0, x1 + STEP, y0, y1, z0, z1) then x1 += STEP grew = true end
				if x0 - STEP >= cx0 - 1e-9 and inside(x0 - STEP, x1, y0, y1, z0, z1) then x0 -= STEP grew = true end
				if y1 + STEP <= cy1 + 1e-9 and inside(x0, x1, y0, y1 + STEP, z0, z1) then y1 += STEP grew = true end
				if y0 - STEP >= cy0 - 1e-9 and inside(x0, x1, y0 - STEP, y1, z0, z1) then y0 -= STEP grew = true end
				if z1 + STEP <= cz1 + 1e-9 and inside(x0, x1, y0, y1, z0, z1 + STEP) then z1 += STEP grew = true end
				if z0 - STEP >= cz0 - 1e-9 and inside(x0, x1, y0, y1, z0 - STEP, z1) then z0 -= STEP grew = true end
			end
			table.insert(out, string.format(
				"  { \"%s\", size = Vector3.new(%.3f, %.3f, %.3f), offset = Vector3.new(%.3f, %.3f, %.3f) }, -- %s x %.3f..%.3f y %.3f..%.3f z %.3f..%.3f",
				zone, x1 - x0, y1 - y0, z1 - z0, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, note, x0, x1, y0, y1, z0, z1))
		end
		for _, span in ipairs(SPANS) do
			local cz0, cz1 = snapZ(Z0 + span.fz0 * (Z1 - Z0)), snapZ(Z0 + span.fz1 * (Z1 - Z0))
			local cx0 = (span.fx0 or -1.0) * HW
			local cx1 = (span.fx1 or 1.0) * HW
			local cy0 = Y0 + (span.fy0 or 0.100) * (Y1 - Y0)
			local cy1 = Y0 + (span.fy1 or 1.000) * (Y1 - Y0)
			if span.band ~= nil then
				-- THE SLAB STOPS `BAND` UNDER ITS OWN MEASURED BACK, and the band owns the rest.
				local back = backMin(cz0, cz1)
				if back == nil then
					table.insert(out, "  -- " .. span.zone .. ": NO BACK LINE over the span")
				else
					grow(span.zone, cx0, cx1, cy0, back - BAND, cz0, cz1, "slab")
					grow(span.band, cx0, cx1, back - BAND, back, cz0, cz1, "dorsal band")
				end
			else
				grow(span.zone, cx0, cx1, cy0, cy1, cz0, cz1, "")
			end
		end
		for _, m in ipairs(meshes) do m.CanQuery = false end
	end
end
local old = Workspace:FindFirstChild("Auto284")
if old then old:Destroy() end
return table.concat(out, string.char(10))
