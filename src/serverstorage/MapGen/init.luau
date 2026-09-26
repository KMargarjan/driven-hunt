--!strict
-- MapGen: THE MAP GENERATOR'S ENTRY POINT. It runs at EDIT TIME ONLY, driven one step at a time by
-- `tools/mapgen.py` through StudioMCP, and it is never part of a game session: nothing requires this
-- module at run time and NOTHING HAPPENS ON REQUIRE (the rule src/server/Boar/init.luau states in its
-- own header).
--
-- (The one clause: `Contract.luau` DOES do work on require, and only in Edit -- it clones the
-- contract script so a run cannot read a stale one. At run time it is a plain require.)
--
-- IT HOLDS NO STATE BETWEEN CALLS. Each MCP call is a separate `execute_luau`, and whether Studio
-- keeps a module's upvalues between two of them is not knowable from the documentation, so the design
-- forbids depending on it (design section 0 item 2, section 5.4). Every step re-derives everything it
-- needs from (index, seed) and the world as it stands, and every world-writing step is IDEMPOTENT:
-- re-running the props step rebuilds the wood, it does not add a second one. That is what makes
-- `mapgen.py step` a usable retry.
--
-- The pure core (`Height`, `Layout`, `Scatter`, `Digest`, `Assets`) is exported, exactly as
-- `src/server/Boar/init.luau` exports `Boar.Brain` and for the same reason: a server spec can drive
-- the generator's maths in the ordinary harness run, with no Studio, no Terrain and no asset, while
-- the generator itself never runs there.
--
-- MILESTONE 2.1 BUILDS A 512-STUD SLICE and does NOT make it the world: `Map.EXPECTED_WORLD` stays
-- "arena", the grey box is still what a player stands in and still the rollback (design section 14).
--
-- Design: docs/design/map-generator.md (sections 2.2, 5.1, 5.2, 6.4)
-- Note:   docs/research/2026-09-24-map-generator.md
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Assets = require(script:WaitForChild("Assets"))
local Config = require(script:WaitForChild("Config"))
local Map = require(script:WaitForChild("Contract"))
local Digest = require(script:WaitForChild("Digest"))
local Ground = require(script:WaitForChild("Ground"))
local Height = require(script:WaitForChild("Height"))
local Layout = require(script:WaitForChild("Layout"))
local Markers = require(script:WaitForChild("Markers"))
local Props = require(script:WaitForChild("Props"))
local Scatter = require(script:WaitForChild("Scatter"))
local Settings = require(script:WaitForChild("Settings"))

local MapGen = {}

MapGen.VERSION = "m2.1"
MapGen.CONFIG = Config
MapGen.Height = Height
MapGen.Layout = Layout
MapGen.Scatter = Scatter
MapGen.Digest = Digest
MapGen.Assets = Assets

export type StepSpec = { index: number, kind: string, label: string, estimatedMs: number }

export type StepReport = {
	index: number,
	kind: string,
	label: string,
	ok: boolean,
	message: string?,
	voxelsWritten: number?,
	partsCreated: number?,
	proxyUsed: { string }?,
	elapsedMs: number,
}

-- ---------------------------------------------------------------- the plan

-- PURE: the whole run as a list, with no side effect, so `mapgen.py plan` is safe to run against a
-- place holding a map you want to keep.
function MapGen.steps(seed: number): { StepSpec }
	local steps: { StepSpec } = {}
	local function add(kind: string, label: string, estimatedMs: number)
		table.insert(steps, { index = #steps + 1, kind = kind, label = label, estimatedMs = estimatedMs })
	end
	add("clear", "clear terrain and destroy " .. Config.ROOT_NAME, 2000)
	local tiles = Layout.tiles(Config)
	for order, tile in ipairs(tiles) do
		add(
			"terrain",
			string.format(
				"terrain tile %d/%d (x=%d..%d, z=%d..%d)",
				order,
				#tiles,
				tile.minX,
				tile.minX + Config.TILE_STUDS,
				tile.minZ,
				tile.minZ + Config.TILE_STUDS
			),
			8000
		)
	end
	add("hedgerow", string.format("hedgerow at z=%d", Config.SLICE.hedgerow.z), 2000)
	add("track", string.format("dirt track material at z=%d", Config.SLICE.trackZ), 4000)
	add("props", string.format("%d trees (seed %d)", Config.SLICE.treeCount, seed), 6000)
	add("markers", "the five tagged marker kinds, and the tie trees", 3000)
	add("settings", "streaming from the contract", 500)
	return steps
end

-- ---------------------------------------------------------------- the world root

local function existingRoot(): Instance?
	return Workspace:FindFirstChild(Config.ROOT_NAME)
end

local function ensureRoot(): Instance
	local root = existingRoot()
	if root then
		return root
	end
	local made = Instance.new("Folder")
	made.Name = Config.ROOT_NAME
	made.Parent = Workspace
	return made
end

function MapGen.clear(): { removed: number, terrainCleared: boolean }
	local root = existingRoot()
	local removed = 0
	if root then
		removed = #root:GetDescendants() + 1
		root:Destroy()
	end
	Ground.clear()
	return { removed = removed, terrainCleared = true }
end

-- ---------------------------------------------------------------- one step

local function partsUnder(root: Instance): number
	local total = 0
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			total += 1
		end
	end
	return total
end

function MapGen.runStep(index: number, seed: number): StepReport
	local started = os.clock()
	local plan = MapGen.steps(seed)
	local spec = plan[index]
	local function finish(fields): StepReport
		local report = fields
		report.index = index
		report.kind = if spec then spec.kind else "unknown"
		report.label = if spec then spec.label else string.format("no step %d", index)
		report.elapsedMs = math.floor((os.clock() - started) * 1000 + 0.5)
		return report
	end
	if spec == nil then
		return finish({ ok = false, message = string.format("step %d is outside 1..%d", index, #plan) })
	end

	if spec.kind == "clear" then
		local result = MapGen.clear()
		return finish({ ok = true, message = string.format("removed %d instances", result.removed) })
	elseif spec.kind == "terrain" then
		local tile = Layout.tiles(Config)[index - 1] -- step 1 is the clear, so tile n is step n + 1
		return finish({ ok = true, voxelsWritten = Ground.writeTile(tile, seed, Config) })
	elseif spec.kind == "hedgerow" then
		local root = ensureRoot()
		local count, keys, why = Props.hedge(root, seed, Config)
		Props.clearAssets(root) -- this step can create it too, so this step also clears it (8.2)
		if why then
			return finish({ ok = false, message = why })
		end
		return finish({ ok = true, partsCreated = count, proxyUsed = keys })
	elseif spec.kind == "track" then
		return finish({ ok = true, voxelsWritten = Ground.paintTrack(Config) })
	elseif spec.kind == "props" then
		local root = ensureRoot()
		local count, keys, why = Props.trees(root, seed, Config)
		Props.clearAssets(root) -- no template outlives the run (design section 8.2)
		if why then
			return finish({ ok = false, message = why })
		end
		if count < Config.SLICE.treeCount then
			return finish({
				ok = false,
				partsCreated = count,
				proxyUsed = keys,
				message = string.format(
					"%d of %d trees placed: the scatter rejected too many cells",
					count,
					Config.SLICE.treeCount
				),
			})
		end
		return finish({ ok = true, partsCreated = count, proxyUsed = keys })
	elseif spec.kind == "markers" then
		local root = ensureRoot()
		local counts = Markers.place(root, seed, Config)
		local tagged = Markers.tagTieTrees(root, Config)
		-- partsCreated is the marker parts only. The tie trees are trunks Props already placed and
		-- this step only TAGS; counting them as parts created would claim 12 parts that do not exist.
		local placedParts = 0
		for _, n in pairs(counts) do
			placedParts += n
		end
		return finish({
			ok = true,
			partsCreated = placedParts,
			message = string.format("%d tie trees tagged (existing trunks)", tagged),
		})
	elseif spec.kind == "settings" then
		local changed, unreachable, unwritten = Settings.apply(Map.STREAMING)
		local note = if #changed == 0 then "already matched the contract" else "changed " .. table.concat(changed, ", ")
		if #unreachable > 0 then
			-- Not a failure: measured, four of the five are Studio-panel settings (Settings.luau).
			note ..= "; not reachable from Luau: " .. table.concat(unreachable, ", ")
		end
		if #unwritten > 0 then
			note ..= "; readable but NOT written: " .. table.concat(unwritten, ", ")
		end
		return finish({ ok = true, message = note })
	end
	return finish({ ok = false, message = "unknown step kind " .. spec.kind })
end

-- ---------------------------------------------------------------- the digest

local function digestEntries(root: Instance): { Digest.Entry }
	local entries: { Digest.Entry } = {}
	for _, instance in ipairs(root:GetDescendants()) do
		local isPart = instance:IsA("BasePart")
		table.insert(entries, {
			name = instance:GetFullName(),
			className = instance.ClassName,
			position = if isPart then (instance :: BasePart).Position else Vector3.zero,
			size = if isPart then (instance :: BasePart).Size else Vector3.zero,
			tags = CollectionService:GetTags(instance),
		})
	end
	return entries
end

function MapGen.digest(): { digest: string, parts: number, samples: number, seed: number, version: string }
	local root = existingRoot()
	if root == nil then
		return { digest = "", parts = 0, samples = 0, seed = Map.SEED, version = MapGen.VERSION }
	end
	local perSide = math.floor(math.sqrt(Config.DIGEST_TERRAIN_SAMPLES))
	local half = Config.SLICE_STUDS / 2
	local samples = {}
	for row = 1, perSide do
		local z = -half + (row - 0.5) * (Config.SLICE_STUDS / perSide)
		for _, sample in ipairs(Ground.sampleRow(z, perSide, Config)) do
			table.insert(samples, sample)
		end
	end
	return {
		digest = Digest.of(digestEntries(root), samples, Config.DIGEST_ROUND),
		parts = partsUnder(root),
		samples = #samples,
		seed = Map.SEED,
		version = MapGen.VERSION,
	}
end

-- The marker half alone, which is the half a server spec can afford (design section 6.4).
function MapGen.markerDigest(): string
	local root = existingRoot()
	if root == nil then
		return ""
	end
	return Digest.half(Digest.markerText(digestEntries(root), Config.DIGEST_ROUND))
end

-- ---------------------------------------------------------------- the contract

-- What the GENERATED map must hold, derived from Layout rather than written out again, so the counts
-- cannot drift from the code that places them. `Map.EXPECTED_COUNTS` describes the world
-- `Map.EXPECTED_WORLD` names, which in M2.1 is still the arena: a different world, different counts.
function MapGen.expectedCounts(): { [string]: number }
	local counts: { [string]: number } = { tree = Config.SLICE.tieTrees }
	for _, marker in ipairs(Layout.markers(Config)) do
		counts[marker.kind] = (counts[marker.kind] or 0) + 1
	end
	return counts
end

local function taggedInside(root: Instance, tag: string): { BasePart }
	local out: { BasePart } = {}
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(root) then
			table.insert(out, instance)
		end
	end
	return out
end

function MapGen.verifyContract(): { ok: boolean, findings: { string }, counts: { [string]: number } }
	local findings: { string } = {}
	local root = existingRoot()
	if root == nil then
		return { ok = false, findings = { Config.ROOT_NAME .. " does not exist in Workspace" }, counts = {} }
	end
	local counts = Markers.counts(root)
	for kind, want in pairs(MapGen.expectedCounts()) do
		local got = counts[kind] or 0
		if got ~= want then
			table.insert(findings, string.format("%s: %d tagged, %d expected", Map.TAGS[kind], got, want))
		end
	end

	local lines = taggedInside(root, Map.TAGS.driveLine)
	if #lines == 1 then
		local dot = lines[1].CFrame.LookVector:Dot(Vector3.zAxis)
		if dot <= 0.99 then
			table.insert(findings, string.format("the drive line's LookVector dots +Z at %.3f, not > 0.99", dot))
		end
	end

	for _, spawn in ipairs(taggedInside(root, Map.TAGS.boarSpawn)) do
		local p, b = spawn.Position, Map.FIELD.bounds
		if p.X < b.minX or p.X > b.maxX or p.Z < b.minZ or p.Z > b.maxZ then
			table.insert(findings, spawn.Name .. " is outside Map.FIELD.bounds")
		end
		if math.abs(p.Y - Map.FIELD.groundY) > Map.SPAWN_PAD.tolerance then
			table.insert(
				findings,
				string.format(
					"%s sits at y=%.2f, more than %.2f studs from groundY",
					spawn.Name,
					p.Y,
					Map.SPAWN_PAD.tolerance
				)
			)
		end
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("LuaSourceContainer") then
			table.insert(findings, "a script exists under the map: " .. descendant:GetFullName())
		end
	end

	local generator = ServerStorage:FindFirstChild("MapGen")
	if generator == nil then
		table.insert(findings, "ServerStorage.MapGen is missing (is Rojo connected?)")
	else
		for _, descendant in ipairs(generator:GetDescendants()) do
			if not descendant:IsA("ModuleScript") then
				table.insert(
					findings,
					"ServerStorage.MapGen holds a " .. descendant.ClassName .. ": " .. descendant.Name
				)
			end
		end
	end

	local parts = partsUnder(root)
	if parts > Map.BUDGET.parts then
		table.insert(findings, string.format("%d parts, over the budget of %d", parts, Map.BUDGET.parts))
	end
	counts.parts = parts
	return { ok = #findings == 0, findings = findings, counts = counts }
end

return MapGen
