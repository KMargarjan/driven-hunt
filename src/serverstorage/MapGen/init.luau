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
-- forbids depending on it. Every step re-derives everything it needs from (index, seed) and the world
-- as it stands, and every world-writing step is IDEMPOTENT: re-running the trees step for one
-- sub-block destroys and rebuilds that sub-block's trees, it does not add a second wood.
--
-- The pure core (`Height`, `Layout`, `Scatter`, `Digest`) is exported, exactly as
-- `src/server/Boar/init.luau` exports `Boar.Brain` and for the same reason: a server spec can drive
-- the generator's maths in the ordinary harness run, with no Studio, no Terrain and no asset, while
-- the generator itself never runs there.
--
-- V4 BUILDS ONE FOREST OF FOUR DRIVE BLOCKS AND BLOCK 1'S CONTENT (task 121). `Map.EXPECTED_WORLD`
-- stays "map:v1" -- the string already named the generated map -- and the facts a live check reads
-- move in the same commit that rebuilds the place.
--
-- Design: docs/design/map-generator.md, "The generator's public interface"
-- Note:   docs/research/2026-10-04-forest-block1.md
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Assets = require(ServerStorage:WaitForChild("Assets"))

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

-- ONE HOME (M2.8a, closing TASKS.md row 44a(f)): the generator's version is Map.GENERATOR. Two
-- strings for one fact is how a digest and a build end up disagreeing about which generator ran.
MapGen.VERSION = Map.GENERATOR
MapGen.CONFIG = Config
MapGen.Height = Height
MapGen.Layout = Layout
MapGen.Scatter = Scatter
MapGen.Digest = Digest
-- Exported so map_contract.spec can READ THE PALETTE AND THE VARIANTS OFF THE ENGINE (round 2,
-- finding 3). The spec must not re-derive the four materials itself: that is the duplication the
-- inverted litter/rough roles came from.
MapGen.Ground = Ground
MapGen.Props = Props
-- The ONE id table in the repo, from this revision onward: `MapGen.Assets` is archived under
-- `backups/` (rule 7) and this is `ServerStorage.Assets`. That closes TASKS.md row 74a(a).
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
	substituted: { string }?,
	elapsedMs: number,
}

export type Reach = { from: string, status: string, waypoints: number }

-- ---------------------------------------------------------------- the plan

-- PURE: the whole run as a list, with no side effect, so `mapgen.py plan` is safe to run against a
-- place holding a map you want to keep.
--
-- THE STEP COUNT IS DERIVED, NEVER TYPED (TASKS.md row 79a(a): the tool said seven, took nine, and
-- the design said eight -- three numbers for one list). `tools/mapgen.py` prints `#MapGen.steps()`.
function MapGen.steps(seed: number): { StepSpec }
	local steps: { StepSpec } = {}
	local function add(kind: string, label: string, estimatedMs: number)
		table.insert(steps, { index = #steps + 1, kind = kind, label = label, estimatedMs = estimatedMs })
	end
	add("clear", "clear terrain and destroy " .. Config.ROOT_NAME, 2000)
	-- SECOND, before a single voxel: the palette is global state, so writing it first means every
	-- tile that follows is already autumn and no run is ever half-recoloured.
	add("palette", "apply the autumn terrain palette", 200)
	-- THIRD, and it never fails the build (design, "Two layers, and the proven one ships first").
	add("materials", "the CC0 terrain material variants, or a report of what could not be reached", 1500)
	local tiles = Layout.tiles(Config)
	for order, tile in ipairs(tiles) do
		add(
			"terrain",
			string.format(
				"terrain tile %d/%d, %s band (x=%d..%d, z=%d..%d, y=%d..%d)",
				order,
				#tiles,
				tile.pass,
				tile.minX,
				tile.minX + Config.TILE_STUDS,
				tile.minZ,
				tile.minZ + Config.TILE_STUDS,
				tile.minY,
				tile.maxY
			),
			4000
		)
	end
	for index, line in ipairs(Layout.hedgeLines(Config)) do
		add(
			"hedgerow",
			string.format(
				"hedgerow %d: along %s at %d%s",
				index,
				line.axis,
				line.at,
				if line.crossesCorridor then ", gated where it crosses the drive" else ""
			),
			3000
		)
	end
	for index, track in ipairs(if Config.INCLUDE.tracks then Config.WORLD_TRACKS else {}) do
		add("track", string.format("dirt track %d: along %s at %d", index, track.axis, track.at), 6000)
	end
	-- No wet-ground STEP: wet ground is a dip in the heightfield and a material, and both are decided
	-- per column by the terrain pass through `Height.wetAt`. A separate step could only repaint what
	-- is already right, and a step that does nothing is worse than no step.
	if Config.INCLUDE.trees then
		for _, block in ipairs(Layout.treeBlocks(Config)) do
			add("trees", string.format("the wood: %s (seed %d)", block.name, seed), 8000)
		end
		for _, block in ipairs(Layout.backdropBlocks(Config)) do
			add("backdrop", string.format("the rim's backdrop wood: %s", block.name), 8000)
		end
	end
	-- THE PATCHES, EACH ITS OWN STEP AND ITS OWN FOLDER, so a thicket and a clearing can be looked
	-- at, re-run and counted separately.
	for _, patch in ipairs(Scatter.patchCentres(Config, seed)) do
		add(
			"patch",
			string.format("the %s patch: radius %d at (%d, %d)", patch.kind, patch.radiusStuds, patch.x, patch.z),
			6000
		)
	end
	if Config.INCLUDE.brush then
		for _, block in ipairs(Layout.treeBlocks(Config)) do
			add("brush", string.format("brush: %s", block.name), 3000)
		end
	end
	if Config.INCLUDE.ferns then
		for _, block in ipairs(Layout.treeBlocks(Config)) do
			add("ferns", string.format("ferns: %s", block.name), 3000)
		end
	end
	if Config.INCLUDE.deadwood then
		add("deadwood", "fallen trunks, stumps and branches", 4000)
	end
	if Config.INCLUDE.stands then
		add(
			"stands",
			string.format(
				"%d timber stands, a collidable floor at %.1f studs",
				Config.DRIVE.postCount,
				Config.STAND.floorStuds
			),
			3000
		)
	end
	add("tieTrees", string.format("%d tie trees behind the shooter line", Config.DRIVE.tieTrees), 2000)
	add("furniture", "the orange-capped stakes beside each stand", 2000)
	add("markers", "the five tagged marker kinds for the active block, and the tie trees", 3000)
	add("settings", "streaming from the contract", 500)
	return steps
end

-- THE PLAN'S SHAPE, WITHOUT ITS LABELS, because the whole list does not fit through one MCP reply.
--
-- MEASURED 2026-10-04: at 799 steps `MapGen.steps` encodes to about 100 KB of JSON and StudioMCP
-- truncates a single result at 100,015 characters -- the limit `tools/studio_mcp.py` already reads
-- long Sources in slices around. `tools/mapgen.py` needs two things from the plan before it starts:
-- how many steps there are, and what kind they are. This answers both in about 400 bytes, and the
-- label of the step actually being run comes back in that step's own report.
--
-- `sample` is the first label of each kind, so `mapgen.py plan` still prints something a human can
-- read the run against rather than a bare histogram.
function MapGen.planSummary(seed: number): {
	total: number,
	kinds: { { kind: string, count: number, sample: string, estimatedMs: number } },
	estimatedMs: number,
}
	local plan = MapGen.steps(seed)
	local order: { string } = {}
	local byKind: { [string]: { kind: string, count: number, sample: string, estimatedMs: number } } = {}
	local total = 0
	for _, step in ipairs(plan) do
		local entry = byKind[step.kind]
		if entry == nil then
			entry = { kind = step.kind, count = 0, sample = step.label, estimatedMs = 0 }
			byKind[step.kind] = entry
			table.insert(order, step.kind)
		end
		entry.count += 1
		entry.estimatedMs += step.estimatedMs
		total += step.estimatedMs
	end
	local kinds = {}
	for _, kind in ipairs(order) do
		table.insert(kinds, byKind[kind])
	end
	return { total = #plan, kinds = kinds, estimatedMs = total }
end

-- ---------------------------------------------------------------- the world root

local function existingRoot(): Instance?
	return Workspace:FindFirstChild(Config.ROOT_NAME)
end

-- THE MAP CARRIES THE SEED IT WAS BUILT FROM (audit-004 F3). `MapGen.digest` used to report
-- `Map.SEED`, which was 0 while `EXPECTED_WORLD` was "arena" -- so `mapgen.py digest` printed
-- `"seed": 0` for a map built from seed 7, and only the CLI's own line carried the real number. An
-- attribute on the root is the map's own record of it: it survives the session, it is not a script,
-- and it does not enter the digest, which covers names, classes, positions, sizes and tags.
local SEED_ATTRIBUTE = "MapGenSeed"

local function ensureRoot(seed: number?): Instance
	local root = existingRoot()
	if root == nil then
		local made = Instance.new("Folder")
		made.Name = Config.ROOT_NAME
		made.Parent = Workspace
		root = made
	end
	if seed ~= nil then
		(root :: Instance):SetAttribute(SEED_ATTRIBUTE, seed)
	end
	return root :: Instance
end

-- The seed the map in the place was built from, or nil when there is no map or it predates the
-- attribute. Nil is the honest answer; 0 was not.
function MapGen.builtSeed(): number?
	local root = existingRoot()
	if root == nil then
		return nil
	end
	local value = root:GetAttribute(SEED_ATTRIBUTE)
	return if type(value) == "number" then value else nil
end

-- Destroys the map root, the terrain, the palette's recolour AND the material variants, and reports
-- what is actually left. `terrainCleared` used to be a hard-coded `true`: a claim with no measurement
-- behind it, about the largest thing the generator writes (audit-004 must-fix 1).
function MapGen.clear(): {
	removed: number,
	terrainCleared: boolean,
	cellsAfter: number,
	cellsBefore: number,
	paletteRestored: boolean,
	variantsRemoved: number,
}
	local root = existingRoot()
	local removed = 0
	if root then
		removed = #root:GetDescendants() + 1
		root:Destroy()
	end
	local before = Ground.cells()
	local after = Ground.clear()
	-- THE PALETTE OUTLIVES Terrain:Clear() -- measured, not assumed (measurement N1) -- so a teardown
	-- that did not restore it would leave an autumn place behind while the contract still says the
	-- world is the arena. `resetPalette` READS THE COLOURS BACK and reports; it never claims.
	local paletteRestored = Ground.resetPalette(Map.PALETTE_DEFAULT, Config)
	-- AND SO DOES A MATERIAL VARIANT: it lives in MaterialService, which is not a Rojo-owned
	-- container, so nothing deletes it at Connect and a variant left behind after a `clear` is
	-- audit-004's "a world nobody chose" again. MEASURED by reading back, never asserted.
	local variantsRemoved = Ground.clearVariants(Config)
	return {
		removed = removed,
		terrainCleared = after == 0,
		cellsAfter = after,
		cellsBefore = before,
		paletteRestored = paletteRestored,
		variantsRemoved = variantsRemoved,
	}
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

-- An `image` row's id as a texture string, or nil. The one place the generator turns an asset KEY
-- into an id, and it goes through `ServerStorage.Assets` like every other id in the repo.
local function textureFor(key: string): string?
	local row = Assets.byKey(key)
	if row == nil or row.kind ~= "image" or row.modelId == 0 then
		return nil
	end
	return "rbxassetid://" .. tostring(row.modelId)
end

local function countChildren(root: Instance, folderName: string): number
	local props = root:FindFirstChild("Props")
	local existing = props and props:FindFirstChild(folderName)
	return if existing then #existing:GetChildren() else 0
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

	-- WHICH tile / sub-block / patch this step is, DERIVED FROM THE PLAN rather than from a
	-- hard-coded offset (M2.8a). Three handlers used to subtract the number of steps before them --
	-- `index - 1`, `index - 1 - #tiles`, and so on -- with the 1 standing for the clear step. Adding
	-- the palette step at position 2 would have shifted all three silently, and a terrain tile
	-- written into the wrong region is a defect no spec here would catch. `ordinal` counts the steps
	-- of this kind that come before this one, so a later insert cannot do that again.
	local function ordinal(): number
		local n = 0
		for position = 1, index do
			if plan[position] and plan[position].kind == spec.kind then
				n += 1
			end
		end
		return n
	end

	if spec.kind == "clear" then
		local result = MapGen.clear()
		if not result.terrainCleared then
			-- LOUD, not silent: every step after this one writes into terrain that is still there, and
			-- the digest would then describe a map nobody built (audit-004 must-fix 1).
			return finish({
				ok = false,
				message = string.format(
					"Terrain:Clear() left %d cell(s) (was %d): the build must not continue over them",
					result.cellsAfter,
					result.cellsBefore
				),
			})
		end
		if not result.paletteRestored then
			return finish({
				ok = false,
				message = "the terrain palette could not be restored to Map.PALETTE_DEFAULT",
			})
		end
		return finish({
			ok = true,
			message = string.format(
				"removed %d instances, %d terrain cell(s), %d material variant(s)",
				result.removed,
				result.cellsBefore,
				result.variantsRemoved
			),
		})
	elseif spec.kind == "palette" then
		local written = Ground.applyPalette(Map.PALETTE, Config)
		local got = Ground.readPalette(Config)
		-- READ BACK. The whole point of measurement N1 was that nobody should assert a colour they
		-- did not check, and the digest carries this palette, so a silent failure here would make
		-- every later digest describe a place that does not exist.
		for role, wanted in pairs(Map.PALETTE) do
			local now = got[role]
			if
				now == nil
				or math.round(now.R * 255) ~= math.round(wanted.R * 255)
				or math.round(now.G * 255) ~= math.round(wanted.G * 255)
				or math.round(now.B * 255) ~= math.round(wanted.B * 255)
			then
				return finish({ ok = false, message = string.format("the %s colour did not take", role) })
			end
		end
		return finish({ ok = true, message = string.format("%d material colour(s) set to autumn", written) })
	elseif spec.kind == "materials" then
		-- IT NEVER FAILS THE BUILD. The palette above is measured and shipped; this layer is new, and
		-- whether a terrain-bound MaterialVariant can be made from `execute_luau` in Edit is
		-- measurement M3. So the step REPORTS, and if none of it works the forest ships on the
		-- palette -- which is why block 1 is lookable at before a texture exists.
		if not Config.INCLUDE.materials then
			return finish({ ok = true, message = "the materials layer is switched off" })
		end
		Ground.applyVariants(Config.TERRAIN_VARIANTS, Config, textureFor)
		local got = Ground.readVariants(Config.TERRAIN_VARIANTS, Config)
		local lines = {}
		for _, role in ipairs({ "litter", "rough", "road", "wet" }) do
			table.insert(lines, string.format("%s: %s", role, tostring(got[role])))
		end
		return finish({ ok = true, message = table.concat(lines, "; ") })
	elseif spec.kind == "terrain" then
		local tile = Layout.tiles(Config)[ordinal()]
		local patches = Scatter.patchCentres(Config, seed)
		return finish({ ok = true, voxelsWritten = Ground.writeTile(tile, seed, Config, patches) })
	elseif spec.kind == "hedgerow" then
		local root = ensureRoot(seed)
		local lineIndex = ordinal()
		local line = Layout.hedgeLines(Config)[lineIndex]
		-- The gates go where the line crosses the ACTIVE BLOCK, and nowhere else: a gate outside it
		-- is a gate the drive never reaches (Task 43 review round 2, finding 2).
		local from, to = Layout.corridorSpan(line, Config)
		local gates = if from and to then Scatter.hedgeGates(Config, seed, lineIndex, from, to) else {}
		local count = Props.hedge(root, seed, Config, lineIndex, line, gates)
		return finish({
			ok = true,
			partsCreated = count,
			message = if #gates > 0 then string.format("%d gate(s) in the drive", #gates) else "no drive crossing",
		})
	elseif spec.kind == "track" then
		return finish({ ok = true, voxelsWritten = Ground.paintTrack(Config.WORLD_TRACKS[ordinal()], Config) })
	elseif spec.kind == "trees" or spec.kind == "backdrop" then
		local root = ensureRoot(seed)
		local which = ordinal()
		local blocks = if spec.kind == "trees" then Layout.treeBlocks(Config) else Layout.backdropBlocks(Config)
		local block = blocks[which]
		local patches = Scatter.patchCentres(Config, seed)
		-- THE FIRST WOOD STEP CLEARS THE FOLDER, the rest add to it. Every step used to rebuild its
		-- own folder, which is right for a one-step prop and wrong for one built in sixteen: the
		-- first run of that shape ended with 964 trees in the world and 1,869 in the log. The
		-- backdrop steps always append, because they run after every `trees` step.
		local fresh = spec.kind == "trees" and which == 1
		local placedSoFar = if fresh then 0 else countChildren(root, "Trees")
		-- THE RIM REFUSES EVERY BLOCK'S GROUND (see `Scatter.insideAnyBlock`): the ring is expressed
		-- as four rectangles and two of them reach into block 1.
		local reject = if spec.kind == "backdrop" then Scatter.insideAnyBlock(Config) else nil
		local count, keys, substituted, species, findings =
			Props.trees(root, seed, Config, block, patches, placedSoFar, fresh, reject)
		local total = placedSoFar + count
		-- THE BUDGET IS A CEILING THAT FAILS THE BUILD, not a number in a document: a build that
		-- quietly overruns the part budget is how a place gets slow with no diff to blame. The count
		-- is a MEASUREMENT of the density tiers, so this is also the tripwire that catches a density
		-- raised too far.
		if total > Map.BUDGET.trees then
			return finish({
				ok = false,
				partsCreated = count,
				proxyUsed = keys,
				message = string.format(
					"%d trees after %s, over Map.BUDGET.trees = %d",
					total,
					block.name,
					Map.BUDGET.trees
				),
			})
		end
		local mix = {}
		for _, name in ipairs(Config.SPECIES_ORDER) do
			table.insert(mix, string.format("%s %d", name, species[name] or 0))
		end
		local message = string.format("%d trees (%s); %d in the wood so far", count, table.concat(mix, " "), total)
		if #findings > 0 then
			message ..= "; keys that did not load: " .. table.concat(findings, ", ")
		end
		return finish({
			ok = true,
			partsCreated = count,
			proxyUsed = keys,
			substituted = substituted,
			message = message,
		})
	elseif spec.kind == "patch" then
		local root = ensureRoot(seed)
		local patch = Scatter.patchCentres(Config, seed)[ordinal()]
		local count, keys, substituted, species, findings = Props.patchTrees(root, seed, Config, patch)
		local mix = {}
		for _, name in ipairs(Config.SPECIES_ORDER) do
			if (species[name] or 0) > 0 then
				table.insert(mix, string.format("%s %d", name, species[name]))
			end
		end
		local message = string.format(
			"the %s patch: %d trees%s",
			patch.kind,
			count,
			if #mix > 0 then " (" .. table.concat(mix, " ") .. ")" else " -- a clearing, by design"
		)
		if #findings > 0 then
			message ..= "; keys that did not load: " .. table.concat(findings, ", ")
		end
		return finish({
			ok = true,
			partsCreated = count,
			proxyUsed = keys,
			substituted = substituted,
			message = message,
		})
	elseif spec.kind == "brush" then
		local root = ensureRoot(seed)
		local which = ordinal()
		local block = Layout.treeBlocks(Config)[which]
		local patches = Scatter.patchCentres(Config, seed)
		local placedSoFar = if which == 1 then 0 else countChildren(root, "Brush")
		local count = Props.brush(root, seed, Config, block, patches, placedSoFar, which == 1)
		local total = placedSoFar + count
		if total > Map.BUDGET.brush then
			return finish({
				ok = false,
				partsCreated = count,
				message = string.format("%d brush parts, over Map.BUDGET.brush = %d", total, Map.BUDGET.brush),
			})
		end
		return finish({ ok = true, partsCreated = count, message = string.format("%d bushes; %d so far", count, total) })
	elseif spec.kind == "ferns" then
		local root = ensureRoot(seed)
		local which = ordinal()
		local block = Layout.treeBlocks(Config)[which]
		local patches = Scatter.patchCentres(Config, seed)
		local placedSoFar = if which == 1 then 0 else countChildren(root, "Ferns")
		local count = Props.ferns(root, seed, Config, block, patches, placedSoFar, which == 1)
		local total = placedSoFar + count
		if total > Map.BUDGET.ferns then
			return finish({
				ok = false,
				partsCreated = count,
				message = string.format("%d ferns, over Map.BUDGET.ferns = %d", total, Map.BUDGET.ferns),
			})
		end
		return finish({ ok = true, partsCreated = count, message = string.format("%d ferns; %d so far", count, total) })
	elseif spec.kind == "deadwood" then
		local root = ensureRoot(seed)
		local patches = Scatter.patchCentres(Config, seed)
		local count = Props.deadwood(root, seed, Config, patches)
		local pieces = countChildren(root, "Deadwood")
		if pieces > Map.BUDGET.deadwood then
			return finish({
				ok = false,
				partsCreated = count,
				message = string.format(
					"%d deadwood pieces, over Map.BUDGET.deadwood = %d",
					pieces,
					Map.BUDGET.deadwood
				),
			})
		end
		return finish({
			ok = true,
			partsCreated = count,
			message = string.format("%d deadwood pieces, %d parts", pieces, count),
		})
	elseif spec.kind == "stands" then
		local root = ensureRoot(seed)
		local count, keys, findings = Props.stands(root, seed, Config)
		local message = string.format(
			"%d parts across %d stands, floor at %.1f studs",
			count,
			Config.DRIVE.postCount,
			Config.STAND.floorStuds
		)
		if #findings > 0 then
			message ..= "; " .. table.concat(findings, ", ")
		end
		return finish({ ok = true, partsCreated = count, proxyUsed = keys, message = message })
	elseif spec.kind == "tieTrees" then
		local root = ensureRoot(seed)
		local count, keys, findings = Props.tieTrees(root, seed, Config)
		local message = string.format("%d tie trees", count)
		if #findings > 0 then
			message ..= "; " .. table.concat(findings, ", ")
		end
		return finish({ ok = true, partsCreated = count, proxyUsed = keys, message = message })
	elseif spec.kind == "furniture" then
		local root = ensureRoot(seed)
		local count = Props.furniture(root, seed, Config)
		if count > Map.BUDGET.furniture then
			return finish({
				ok = false,
				partsCreated = count,
				message = string.format(
					"%d furniture parts, over Map.BUDGET.furniture = %d",
					count,
					Map.BUDGET.furniture
				),
			})
		end
		return finish({
			ok = true,
			partsCreated = count,
			message = string.format("%d stake parts beside %d stands", count, Config.DRIVE.postCount),
		})
	elseif spec.kind == "markers" then
		local root = ensureRoot(seed)
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
			message = string.format(
				"%d markers for %s, %d tie trees tagged (existing trunks)",
				placedParts,
				Config.ACTIVE_BLOCK,
				tagged
			),
		})
	elseif spec.kind == "settings" then
		local changed, unreachable, unwritten, refused = Settings.apply(Map.STREAMING)
		local note = if #changed == 0 then "already matched the contract" else "changed " .. table.concat(changed, ", ")
		if #refused > 0 then
			-- NOT a silent write and NOT a silent skip: M2.6 owns this change and has not run.
			note ..= "; REFUSED (M2.6 has not run): " .. table.concat(refused, ", ")
		end
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

function MapGen.digest(): { digest: string, parts: number, samples: number, seed: number?, version: string }
	local root = existingRoot()
	if root == nil then
		return { digest = "", parts = 0, samples = 0, seed = nil, version = MapGen.VERSION }
	end
	local perSide = math.floor(math.sqrt(Config.DIGEST_TERRAIN_SAMPLES))
	local half = Config.SIZE_STUDS / 2
	local samples = {}
	for row = 1, perSide do
		local z = -half + (row - 0.5) * (Config.SIZE_STUDS / perSide)
		for _, sample in ipairs(Ground.sampleRow(z, perSide, Config)) do
			table.insert(samples, sample)
		end
	end
	return {
		digest = Digest.of(
			digestEntries(root),
			samples,
			Config.DIGEST_ROUND,
			Ground.readPalette(Config),
			Ground.readVariants(Config.TERRAIN_VARIANTS, Config)
		),
		parts = partsUnder(root),
		samples = #samples,
		-- The seed THIS MAP was built from, read off the root, not the contract's `Map.SEED` -- which
		-- this field is one of the inputs to.
		seed = MapGen.builtSeed(),
		version = MapGen.VERSION,
	}
end

-- The marker half alone, which is the half a server spec can afford.
function MapGen.markerDigest(): string
	local root = existingRoot()
	if root == nil then
		return ""
	end
	return Digest.half(Digest.markerText(digestEntries(root), Config.DIGEST_ROUND))
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

-- ---------------------------------------------------------------- the triangle bound

-- EVERY TREE IN THE BUILT WORLD, as the position-and-tier records `Layout.visibleLoad` sums. Read off
-- the Models' own attributes, so this measures THE WOOD THAT WAS BUILT rather than a second model of
-- it -- which is the whole reason the attributes exist (audit-005 must-fix 2).
function MapGen.builtTrees(): { any }
	local root = existingRoot()
	local out = {}
	if root == nil then
		return out
	end
	local props = root:FindFirstChild("Props")
	if props == nil then
		return out
	end
	for _, folder in ipairs(props:GetChildren()) do
		local name = folder.Name
		if name == "Trees" or string.sub(name, 1, 6) == "Patch_" or name == "TieTrees" then
			for _, model in ipairs(folder:GetChildren()) do
				local species = model:GetAttribute(Props.SPECIES_ATTRIBUTE)
				local tier = model:GetAttribute(Props.TIER_ATTRIBUTE)
				local primary = if model:IsA("Model") then model.PrimaryPart else nil
				if type(species) == "string" and primary ~= nil then
					table.insert(out, {
						x = primary.Position.X,
						z = primary.Position.Z,
						species = species,
						tier = if type(tier) == "string" then tier else "mature",
					})
				end
			end
		end
	end
	return out
end

-- The bound at every point a player's eye actually is: the eight stands and the driver start.
function MapGen.visibleLoad(trees: { any }?): { [string]: number }
	local wood = trees or MapGen.builtTrees()
	local out: { [string]: number } = {}
	for _, point in ipairs(Layout.loadPoints(Config)) do
		out[point.name] = Layout.visibleLoad(point, wood, Config, Map.STREAMING.targetRadius)
	end
	return out
end

-- ---------------------------------------------------------------- the screenshots

-- THE ELEVEN NAMED CAPTURES, AS DATA, AND THE GENERATOR OWNS THE LIST (design, "Screenshots").
--
-- IT IS HERE AND NOT IN `tools/mapgen.py` FOR ONE REASON: FOUR OF THE ELEVEN ARE AT SEEDED
-- POSITIONS. The young patch, the gap, the deadwood and the wettest hollow move with the seed, so a
-- camera typed into the tool would be pointing at bare wood the first time somebody changed the
-- seed -- and a screenshot aimed at nothing is worse than no screenshot, because somebody signs it
-- off. It also closes TASKS.md row 79a(a): the tool said seven, took nine and the design said eight,
-- which was three numbers for one list. Now there is one list and the tool prints its length.
--
-- EVERY ONE CARRIES ITS QUESTION, not a label: the point of a shot is the answer a human gives it.
function MapGen.shotCameras(
	seed: number
): { { name: string, camera: { number }, lookAt: { number }, question: string } }
	local pads = Layout.pads(Config)
	local block = Layout.activeBlock(Config)
	local lineZ = Layout.lineZ(Config)
	local centreX = Config.DRIVE.centreX
	local half = Config.SIZE_STUDS / 2
	local function ground(x: number, z: number): number
		return Height.atFlattened(x, z, seed, Config, pads)
	end
	local out = {}
	local function add(name: string, camera: { number }, lookAt: { number }, question: string)
		table.insert(out, { name = name, camera = camera, lookAt = lookAt, question = question })
	end

	-- 1-3. THE WHOLE FOREST, ITS RIM AND THE LENGTH OF THE DRIVE.
	add(
		"forest-wide",
		{ 0, 1900, 2300 },
		{ 0, 0, -200 },
		"four blocks and a road grid, or one green rectangle? Blocks 2 and 4 are bare in this task: does that read as unfinished or as a clearing?"
	)
	add(
		"forest-edge",
		{ 900, ground(900, lineZ) + 10, lineZ },
		{ half, 40, lineZ },
		"does the rim read as hills, or as a wall round a box? And does the road run off the map flat, or into a ridge?"
	)
	add(
		"block1-hills",
		{ centreX, ground(centreX, block.bounds.maxZ - 16) + 14, block.bounds.maxZ - 16 },
		{ centreX, 4, lineZ },
		"the 'mountains a bit' down the whole length of the drive, from the drivers' end"
	)

	-- 4-6. THE ROAD, A STAND AND THE CROSSING -- where the game actually happens.
	local firstX, lastX = Layout.postX(1, Config), Layout.postX(Config.DRIVE.postCount, Config)
	add(
		"block1-road",
		{ firstX, ground(firstX, lineZ) + 9, lineZ },
		{ lastX, 9, lineZ },
		"standing on the gravel: do eight stands read at 160 studs? Is the cleared corridor 6 m of forest road or a firebreak?"
	)
	local stands = Layout.standPoints(Config)
	local stand = stands[math.ceil(#stands / 2)] or { x = centreX, z = lineZ + Config.STAND.offsetZ }
	-- FROM THE FLOORBOARDS: the floor's top plus a character's eye, which is the only height that
	-- answers "can a shooter see far enough to shoot".
	add(
		"block1-stand",
		{ stand.x, ground(stand.x, stand.z) + Config.STAND.floorStuds + 4, stand.z + 4 },
		{ stand.x, 6, stand.z + 300 },
		"from the floorboards: can a shooter see far enough to shoot? How much of the frame is trunk? Does the rail cut the shot?"
	)
	add(
		"block1-crossing",
		{ centreX, ground(centreX, lineZ + 340) + 4, lineZ + 340 },
		{ centreX, 3, lineZ - 260 },
		"the boar's own view: is the road a gap between two woods, and does the far side look like somewhere it went?"
	)

	-- 7. THE MATURE OAK, CLOSE. Inside the dense band, where the shooter's eye is.
	local oakX, oakZ = centreX + 180, lineZ + 120
	add(
		"block1-oak",
		{ oakX, ground(oakX, oakZ) + 6, oakZ },
		{ oakX + 90, ground(oakX, oakZ) + 16, oakZ + 50 },
		"close in the mature oak: bark, crown, litter -- does an oak read as an oak, and is the autumn even or patchy?"
	)

	-- 8-10. THE THREE SEEDED PLACES. Each camera stands outside its own feature and looks across it,
	-- because a camera INSIDE a thicket photographs one trunk.
	for _, patch in ipairs(Scatter.patchCentres(Config, seed)) do
		local radius = patch.radiusStuds
		local fromZ = patch.z - radius * 0.9
		local name = if patch.kind == "young" then "block1-young" else "block1-gap"
		local question = if patch.kind == "young"
			then "a thicket a boar hides in, or a plantation grid? And can a driver walk through it?"
			else "a clearing you could shoot across: does the ground change, and is there anything standing in it?"
		add(
			name,
			{ patch.x, ground(patch.x, fromZ) + 5, fromZ },
			{ patch.x, ground(patch.x, patch.z) + 4, patch.z + radius },
			question
		)
	end
	-- THE FOREST FLOOR, at the first piece of deadwood the seed placed -- so the shot is of something
	-- rather than of wherever a typed camera happened to point.
	local logs =
		Scatter.deadwood(Config, seed, Layout.treeBlocks(Config)[1] or block.bounds, Scatter.patchCentres(Config, seed))
	local log = logs[1] or { x = centreX, z = lineZ + 200 }
	add(
		"block1-deadwood",
		{ log.x - 18, ground(log.x - 18, log.z - 12) + 5, log.z - 12 },
		{ log.x, ground(log.x, log.z) + 2, log.z },
		"does the floor read as a forest floor -- fallen trunks, brush, ferns, litter -- or as a lawn with trees on it?"
	)

	-- 11. THE WETTEST HOLLOW IN THE BLOCK, found by sampling rather than named: wet ground is
	-- DERIVED from the heightfield, so where it is is the seed's answer and not a number.
	local wettestX, wettestZ, wettest = centreX, lineZ + 400, -math.huge
	local x = block.bounds.minX + 40
	while x <= block.bounds.maxX - 40 do
		local z = block.bounds.minZ + 40
		while z <= block.bounds.maxZ - 40 do
			local wetness = Height.wetAt(x, z, seed, Config)
			if wetness > wettest then
				wettestX, wettestZ, wettest = x, z, wetness
			end
			z += 40
		end
		x += 40
	end
	add(
		"block1-wet",
		{ wettestX - 30, ground(wettestX - 30, wettestZ - 30) + 6, wettestZ - 30 },
		{ wettestX, ground(wettestX, wettestZ) + 2, wettestZ },
		string.format(
			"the wettest hollow the seed made (wetness %.2f): alder, ferns, mud -- wet ground, or a grey hole?",
			wettest
		)
	)
	return out
end

-- ---------------------------------------------------------------- reachability

-- CAN THE BOAR ACTUALLY GET THERE? Every BoarSpawn and the DriverStart, pathfound to the drive line
-- with the BOAR'S OWN agent parameters. This is the design's walkability requirement, and it lives
-- here because the harness spec can only see the world `EXPECTED_WORLD` names and so has never
-- pathfound a generated map. That gap is exactly how an ungated hedgerow wall across the drive
-- survived Task 43's first two review rounds (TASKS.md row 43a(k)).
--
--   PathfindingService https://create.roblox.com/docs/reference/engine/classes/PathfindingService
--
-- MEASURED 2026-09-26: `ComputeAsync` works in an Edit session through `execute_luau`, and a wall
-- thrown across the corridor still answered `Success` ONE second after it appeared and `NoPath` after
-- five. Studio rebuilds its navmesh in the background, so this waits `REACH_SETTLE_SECONDS` first: a
-- check that races the navmesh answers about the map as it was, which is worse than no check.
function MapGen.reachability(): { ok: boolean, findings: { string }, results: { Reach } }
	local root = existingRoot()
	if root == nil then
		return { ok = false, findings = { Config.ROOT_NAME .. " does not exist in Workspace" }, results = {} }
	end
	local ok, Boar = pcall(function()
		return require(ServerScriptService:WaitForChild("Boar", 10))
	end)
	if not ok or type(Boar) ~= "table" then
		return {
			ok = false,
			findings = { "ServerScriptService.Boar is not requireable, so the boar's own agent is unknown" },
			results = {},
		}
	end
	local lines = taggedInside(root, Map.TAGS.driveLine)
	if #lines ~= 1 then
		return { ok = false, findings = { string.format("%d drive lines: nothing to path to", #lines) }, results = {} }
	end
	-- FIVE TARGETS ALONG THE LINE, not its centre (closing TASKS.md row 44a(e)). The line is 1,426
	-- studs wide; pathing only to its midpoint proved one corridor down the middle and said nothing
	-- about whether a boar pushed toward the block's edge can reach the road at all.
	local centre = lines[1].Position
	local halfSpan = lines[1].Size.X / 2
	local targets: { { name: string, position: Vector3 } } = {}
	for _, fraction in ipairs({ -1, -0.5, 0, 0.5, 1 }) do
		local offset = halfSpan * fraction * 0.9 -- 0.9: stay off the very ends, which are off the road
		table.insert(targets, {
			name = string.format("line%+d", math.round(fraction * 100)),
			position = centre + Vector3.new(offset, 0, 0),
		})
	end

	local froms: { { name: string, position: Vector3 } } = {}
	for _, spawn in ipairs(taggedInside(root, Map.TAGS.boarSpawn)) do
		table.insert(froms, { name = spawn.Name, position = spawn.Position })
	end
	for _, start in ipairs(taggedInside(root, Map.TAGS.driverStart)) do
		table.insert(froms, { name = start.Name, position = start.Position })
	end
	table.sort(froms, function(a, b)
		return a.name < b.name
	end)
	if #froms == 0 then
		return { ok = false, findings = { "no boar spawn and no driver start to path from" }, results = {} }
	end

	task.wait(Config.REACH_SETTLE_SECONDS)

	local findings: { string } = {}
	local results: { Reach } = {}
	-- 5 froms x 5 targets = 25 computes. Every one is reported; a single failure fails the check,
	-- because "a boar can get to the middle of the road" is not the question the drive asks.
	for _, from in ipairs(froms) do
		for _, to in ipairs(targets) do
			local path = PathfindingService:CreatePath(Boar.CONFIG.AGENT)
			local computed = pcall(function()
				path:ComputeAsync(from.position + Vector3.new(0, 2, 0), to.position)
			end)
			local waypoints = if computed then #path:GetWaypoints() else 0
			local status = if computed then tostring(path.Status) else "ComputeAsync raised"
			local label = from.name .. "->" .. to.name
			table.insert(results, { from = label, status = status, waypoints = waypoints })
			if status ~= "Enum.PathStatus.Success" then
				table.insert(findings, string.format("%s cannot reach the line: %s", label, status))
			elseif waypoints < 2 then
				table.insert(findings, string.format("%s reached the line in %d waypoint(s)", label, waypoints))
			end
		end
	end
	return { ok = #findings == 0, findings = findings, results = results }
end

-- ---------------------------------------------------------------- the contract

-- What the GENERATED map must hold, derived from Layout rather than written out again, so the counts
-- cannot drift from the code that places them.
function MapGen.expectedCounts(): { [string]: number }
	local counts: { [string]: number } = { tree = Config.DRIVE.tieTrees }
	for _, marker in ipairs(Layout.markers(Config)) do
		counts[marker.kind] = (counts[marker.kind] or 0) + 1
	end
	return counts
end

function MapGen.verifyContract(): {
	ok: boolean,
	findings: { string },
	counts: { [string]: number },
	streaming: { [string]: string },
	markerDigest: string,
	seed: number?,
	palette: { [string]: string },
	activeBlock: string,
	variants: { [string]: string },
	visibleTris: { [string]: number },
}
	local findings: { string } = {}
	local root = existingRoot()
	local function palette(): { [string]: string }
		local out: { [string]: string } = {}
		for role, colour in pairs(Ground.readPalette(Config)) do
			out[role] = string.format(
				"%d,%d,%d",
				math.round(colour.R * 255),
				math.round(colour.G * 255),
				math.round(colour.B * 255)
			)
		end
		return out
	end
	if root == nil then
		-- EVERY FIELD, even here (TASKS.md rows 45a(c), 47a(d), 48a(c), fixed once already -- keep it
		-- fixed). The annotation above makes all ten mandatory, and this early return is the one that
		-- is easy to forget: a caller that read `.markerDigest` off it got nil instead of "".
		return {
			ok = false,
			findings = { Config.ROOT_NAME .. " does not exist in Workspace" },
			counts = {},
			streaming = {},
			markerDigest = "",
			seed = nil,
			palette = palette(),
			activeBlock = Config.ACTIVE_BLOCK,
			variants = Ground.readVariants(Config.TERRAIN_VARIANTS, Config),
			visibleTris = {},
		}
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

	-- EVERY MARKER IS INSIDE THE ACTIVE BLOCK'S OWN GROUND, so a second block's markers cannot hide
	-- in the count. The block plus its road strip and the crossing band behind it: the tie trees and
	-- the posts stand behind the line on purpose.
	local active = Layout.activeBlock(Config)
	local crossing = Layout.crossingBand(Config)
	local southEdge = if crossing then crossing.minZ else active.bounds.minZ
	for _, tag in ipairs({ Map.TAGS.shooterPost, Map.TAGS.driveLine, Map.TAGS.driverStart, Map.TAGS.boarSpawn }) do
		for _, marker in ipairs(taggedInside(root, tag)) do
			local p = marker.Position
			if
				p.X < active.bounds.minX - 1
				or p.X > active.bounds.maxX + 1
				or p.Z < southEdge - 1
				or p.Z > Config.ROADS.assembly.at + 1
			then
				table.insert(
					findings,
					string.format(
						"%s at (%.0f, %.0f) is outside the active block %s",
						marker.Name,
						p.X,
						p.Z,
						active.name
					)
				)
			end
		end
	end

	for _, spawn in ipairs(taggedInside(root, Map.TAGS.boarSpawn)) do
		local p, b = spawn.Position, Config.FIELD.bounds
		if p.X < b.minX or p.X > b.maxX or p.Z < b.minZ or p.Z > b.maxZ then
			table.insert(findings, spawn.Name .. " is outside Config.FIELD.bounds (the MAP's rectangle)")
		end
		if math.abs(p.Y - Config.FIELD.groundY) > Map.SPAWN_PAD.tolerance then
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

	-- EVERY SHOOTER POST STANDS ON A FLOOR, AND THAT IS TWO CHECKS RATHER THAN ONE.
	--
	-- v3 asserted only "every post's bottom face is within tolerance of groundY", which proved a
	-- HEIGHT and not a FLOOR -- and the 9.5-stud drop (row 43a(l), audit-004 F9) is exactly what a
	-- height check misses. So: (1) the bottom face is at `ground + Map.STAND.floorStuds`, ONE
	-- expression that was true when `floorStuds` was 0 and the shooters stood on the road and is
	-- true now that it is 7.1 and they stand on boards; and (2) THERE IS A COLLIDABLE PART DIRECTLY
	-- UNDER IT whose top face is that same number.
	local pads = Layout.pads(Config)
	for _, post in ipairs(taggedInside(root, Map.TAGS.shooterPost)) do
		local bottom = post.Position.Y - post.Size.Y / 2
		local ground =
			Height.atFlattened(post.Position.X, post.Position.Z, MapGen.builtSeed() or Map.SEED, Config, pads)
		local want = ground + Map.STAND.floorStuds
		if math.abs(bottom - want) > Map.SPAWN_PAD.tolerance then
			table.insert(
				findings,
				string.format(
					"%s's bottom face is at y=%.2f, not within %.2f of ground + floorStuds = %.2f",
					post.Name,
					bottom,
					Map.SPAWN_PAD.tolerance,
					want
				)
			)
		end
		local supported = false
		for _, candidate in ipairs(root:GetDescendants()) do
			if candidate:IsA("BasePart") and candidate.CanCollide then
				local p = (candidate :: BasePart).Position
				local s = (candidate :: BasePart).Size
				local top = p.Y + s.Y / 2
				if
					math.abs(p.X - post.Position.X) <= s.X / 2 + post.Size.X / 2
					and math.abs(p.Z - post.Position.Z) <= s.Z / 2 + post.Size.Z / 2
					and math.abs(top - bottom) <= Map.SPAWN_PAD.tolerance
				then
					supported = true
					break
				end
			end
		end
		if not supported then
			table.insert(
				findings,
				string.format("%s has no collidable part under it: a shooter would be placed over a drop", post.Name)
			)
		end
	end

	-- The driver start's FOUR CORNERS, not its centre: it is 1,120 studs wide, so a centre that
	-- happens to be at ground says nothing about the strip eight drivers actually stand on.
	for _, start in ipairs(taggedInside(root, Map.TAGS.driverStart)) do
		local half = start.Size / 2
		for _, corner in ipairs({
			Vector3.new(-half.X, -half.Y, -half.Z),
			Vector3.new(half.X, -half.Y, -half.Z),
			Vector3.new(-half.X, -half.Y, half.Z),
			Vector3.new(half.X, -half.Y, half.Z),
		}) do
			local y = (start.CFrame * CFrame.new(corner)).Position.Y
			if math.abs(y - Config.FIELD.groundY) > Map.SPAWN_PAD.tolerance then
				table.insert(findings, string.format("%s has a corner at y=%.2f, off groundY", start.Name, y))
				break
			end
		end
	end

	-- NOTHING COLLIDABLE STANDS ON ANY ROAD'S CLEARED CORRIDOR, along its WHOLE length.
	--
	-- AMENDED, NOT WEAKENED. v3 walked one road and used `halfWidth + verge`; v4 walks all four and
	-- uses `halfWidth + keepClear`, which is the predicate `Layout.treeDensity` and `Props` also
	-- call. The purpose is unchanged -- the gravel a shooter stands on and a boar crosses is never
	-- blocked -- and it keeps the property it was written for (a hedge wall across the gravel, Task
	-- 58 round 1 finding 1). `keepClear` is smaller than `verge` on purpose: trunks stand on the
	-- eased verge and crowns overhang the ride, which is what a forest road looks like.
	local blockers: { string } = {}
	for _, candidate in ipairs(root:GetDescendants()) do
		if candidate:IsA("BasePart") and (candidate :: BasePart).CanCollide then
			local p = (candidate :: BasePart).Position
			if Layout.onRoadKeepClear(p.X, p.Z, Config) then
				table.insert(blockers, string.format("%s at (%.0f, %.0f)", candidate.Name, p.X, p.Z))
			end
		end
	end
	if #blockers > 0 then
		table.insert(
			findings,
			string.format(
				"%d collidable part(s) stand inside a road's cleared corridor: %s",
				#blockers,
				table.concat(blockers, ", ", 1, math.min(#blockers, 5))
			)
		)
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("LuaSourceContainer") then
			table.insert(findings, "a script exists under the map: " .. descendant:GetFullName())
		end
	end

	-- NO ASSET CACHE OUTLIVED THE RUN. `Props.withLoader` destroys the folder it made; a surviving
	-- one means a step failed between the preload and the teardown, and a template in the world is a
	-- tree nobody planted.
	if root:FindFirstChild(Props.ASSETS_FOLDER) ~= nil then
		table.insert(findings, "the asset cache folder outlived the run: a step failed mid-way")
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
	-- The map exists, so terrain MUST: a root with no ground under it is a build that half-ran.
	local cells = Ground.cells()
	counts.terrainCells = cells
	if cells == 0 then
		table.insert(findings, "the map root exists but the terrain is empty: the build did not finish")
	end

	-- THE TRIANGLE BOUND, MEASURED OFF THE BUILT WOOD at every point a player's eye is.
	local trees = MapGen.builtTrees()
	counts.trees = #trees
	local visibleTris = MapGen.visibleLoad(trees)
	for name, total in pairs(visibleTris) do
		if total > Map.BUDGET.visibleTris then
			table.insert(
				findings,
				string.format(
					"%s sees %d baked triangles, over Map.BUDGET.visibleTris = %d",
					name,
					total,
					Map.BUDGET.visibleTris
				)
			)
		end
	end

	return {
		ok = #findings == 0,
		findings = findings,
		counts = counts,
		-- What the place actually says about streaming, beside what the contract wants: the four
		-- properties Luau cannot reach read as "unreachable from Luau" rather than as a number nobody
		-- checked (row 43a(m) gave this function its reader).
		streaming = Settings.current(),
		-- The half of the digest a spec can afford.
		markerDigest = MapGen.markerDigest(),
		seed = MapGen.builtSeed(),
		palette = palette(),
		activeBlock = Config.ACTIVE_BLOCK,
		variants = Ground.readVariants(Config.TERRAIN_VARIANTS, Config),
		visibleTris = visibleTris,
	}
end

return MapGen
