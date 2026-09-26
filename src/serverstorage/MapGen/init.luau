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
-- MILESTONE 2.2 BUILDS THE WHOLE 2048-STUD MAP and still does NOT make it the world:
-- `Map.EXPECTED_WORLD` stays "arena", the grey box is still what a player stands in and still the
-- rollback (design section 14). M2.5 is the switch.
--
-- Design: docs/design/map-generator.md (sections 2.2, 5.1, 5.2, 6.4)
-- Note:   docs/research/2026-09-24-map-generator.md
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ServerScriptService = game:GetService("ServerScriptService")
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

-- ONE HOME (M2.8a, closing TASKS.md row 44a(f)): the generator's version is Map.GENERATOR. Two
-- strings for one fact is how a digest and a build end up disagreeing about which generator ran.
MapGen.VERSION = Map.GENERATOR
MapGen.CONFIG = Config
MapGen.Height = Height
MapGen.Layout = Layout
MapGen.Scatter = Scatter
MapGen.Digest = Digest
-- Exported so map_contract.spec can READ THE PALETTE OFF THE ENGINE (round 2, finding 3). The spec
-- must not re-derive the four materials itself: that is the duplication the inverted roles came from.
MapGen.Ground = Ground
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

export type Reach = { from: string, status: string, waypoints: number }

-- ---------------------------------------------------------------- the plan

-- PURE: the whole run as a list, with no side effect, so `mapgen.py plan` is safe to run against a
-- place holding a map you want to keep.
function MapGen.steps(seed: number): { StepSpec }
	local steps: { StepSpec } = {}
	local function add(kind: string, label: string, estimatedMs: number)
		table.insert(steps, { index = #steps + 1, kind = kind, label = label, estimatedMs = estimatedMs })
	end
	add("clear", "clear terrain and destroy " .. Config.ROOT_NAME, 2000)
	-- SECOND, before a single voxel: the palette is global state, so writing it first means every
	-- tile that follows is already autumn and no run is ever half-recoloured (design section 8).
	add("palette", "apply the autumn terrain palette", 200)
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
	for index, track in ipairs(Config.WORLD.tracks) do
		add("track", string.format("dirt track %d: along %s at %d", index, track.axis, track.at), 6000)
	end
	-- No bog STEP: the bog is a dip in the heightfield and a material, and both are decided per voxel
	-- by the terrain pass through `Layout.bogDepth`. A separate step could only repaint what is
	-- already right, and a step that does nothing is worse than no step (design section 5.2 layer 6
	-- assumes a bog painted on top of flat ground; ours is part of the ground).
	-- THE WOOD, ONE QUADRANT PER STEP (design section 7.2). ~3,000 Models in one step is one step
	-- that can time out and tell you nothing about where it was; four steps name a quarter of the map.
	for _, block in ipairs(Layout.treeBlocks(Config)) do
		add("props", string.format("the wood: %s quadrant (seed %d)", block.name, seed), 8000)
	end
	for _, block in ipairs(Layout.treeBlocks(Config)) do
		add("brush", string.format("brush: %s quadrant", block.name), 3000)
	end
	add("stand", string.format("%d tie trees behind the shooter line", Config.WORLD.tieTrees), 2000)
	add("markers", "the five tagged marker kinds, and the tie trees", 3000)
	add("settings", "streaming from the contract", 500)
	return steps
end

-- ---------------------------------------------------------------- the world root

local function existingRoot(): Instance?
	return Workspace:FindFirstChild(Config.ROOT_NAME)
end

-- THE MAP CARRIES THE SEED IT WAS BUILT FROM (audit-004 F3). `MapGen.digest` used to report
-- `Map.SEED`, which is 0 while `EXPECTED_WORLD` is "arena" -- so `mapgen.py digest` printed
-- `"seed": 0` for a map built from seed 7, and only the CLI's own line carried the real number. Step 6
-- of the M2.5 switch (design section 9.3) copies that field into the contract, so a wrong one there is
-- a wrong one in the committed map. An attribute on the root is the map's own record of it: it
-- survives the session, it is not a script, and it does not enter the digest, which covers names,
-- classes, positions, sizes and tags.
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

-- Destroys the map root AND the terrain, and reports what is actually left. `terrainCleared` used to
-- be a hard-coded `true`: a claim with no measurement behind it, about the largest thing the
-- generator writes (audit-004 must-fix 1). It is now `cellsAfter == 0`, read back from the engine.
function MapGen.clear(): {
	removed: number,
	terrainCleared: boolean,
	cellsAfter: number,
	cellsBefore: number,
	paletteRestored: boolean,
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
	return {
		removed = removed,
		terrainCleared = after == 0,
		cellsAfter = after,
		cellsBefore = before,
		paletteRestored = paletteRestored,
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

	-- WHICH tile / hedge line / track this step is, DERIVED FROM THE PLAN rather than from a
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
			-- The palette is global state that outlives Terrain:Clear() (measurement N1). A clear that
			-- could not put it back leaves the place looking like a map that is not there.
			return finish({
				ok = false,
				message = "the terrain palette could not be restored to Map.PALETTE_DEFAULT",
			})
		end
		return finish({
			ok = true,
			message = string.format("removed %d instances, %d terrain cell(s)", result.removed, result.cellsBefore),
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
	elseif spec.kind == "terrain" then
		local tile = Layout.tiles(Config)[ordinal()]
		return finish({ ok = true, voxelsWritten = Ground.writeTile(tile, seed, Config) })
	elseif spec.kind == "hedgerow" then
		local root = ensureRoot(seed)
		local lineIndex = ordinal()
		local line = Layout.hedgeLines(Config)[lineIndex]
		-- The gates go where the line crosses the DRIVE CORRIDOR, and nowhere else: a gate outside it
		-- is a gate the drive never reaches (Task 43 review round 2, finding 2).
		local from, to = Layout.corridorSpan(line, Config)
		local gates = if from and to then Scatter.hedgeGates(Config, seed, lineIndex, from, to) else {}
		local count, keys, why = Props.hedge(root, seed, Config, lineIndex, line, gates)
		Props.clearAssets(root) -- this step can create it too, so this step also clears it (8.2)
		if why then
			return finish({ ok = false, message = why })
		end
		return finish({
			ok = true,
			partsCreated = count,
			proxyUsed = keys,
			message = if #gates > 0
				then string.format("%d gate(s) in the corridor", #gates)
				else "no corridor crossing",
		})
	elseif spec.kind == "track" then
		return finish({ ok = true, voxelsWritten = Ground.paintTrack(Config.WORLD.tracks[ordinal()], Config) })
	elseif spec.kind == "props" then
		local root = ensureRoot(seed)
		local quadrant = ordinal()
		local block = Layout.treeBlocks(Config)[quadrant]
		-- THE FIRST QUADRANT CLEARS THE WOOD, the other three add to it. Every step used to rebuild
		-- its folder, which is right for a one-step prop and wrong for one built in four: the first
		-- run of this shape ended with 964 trees in the world and 1,869 in the log.
		local placedSoFar = if quadrant == 1 then 0 else #Props.trunks(root, "Trees")
		local count, keys, why, species = Props.trees(root, seed, Config, block, placedSoFar, quadrant == 1)
		Props.clearAssets(root) -- no template outlives the run (design section 8.2)
		if why then
			return finish({ ok = false, message = why })
		end
		local total = placedSoFar + count
		-- THE BUDGET IS A CEILING THAT FAILS THE BUILD, not a number in a document (design section
		-- 7.2): a build that quietly overruns the part budget is how a place gets slow with no diff
		-- to blame. The count is a MEASUREMENT of the density tiers, so this is also the tripwire
		-- that catches a density raised too far.
		if total > Map.BUDGET.trees then
			return finish({
				ok = false,
				partsCreated = count,
				proxyUsed = keys,
				message = string.format(
					"%d trees after the %s quadrant, over Map.BUDGET.trees = %d",
					total,
					block.name,
					Map.BUDGET.trees
				),
			})
		end
		local mix = {}
		for _, row in ipairs(Config.SPECIES) do
			table.insert(mix, string.format("%s %d", row.name, species[row.name] or 0))
		end
		return finish({
			ok = true,
			partsCreated = count,
			proxyUsed = keys,
			message = string.format("%d trees (%s); %d in the wood so far", count, table.concat(mix, " "), total),
		})
	elseif spec.kind == "brush" then
		local root = ensureRoot(seed)
		local quadrant = ordinal()
		local block = Layout.treeBlocks(Config)[quadrant]
		local placedSoFar = 0
		local props = root:FindFirstChild("Props")
		local existing = props and props:FindFirstChild("Brush")
		if existing and quadrant > 1 then
			placedSoFar = #existing:GetChildren()
		end
		local count, why = Props.brush(root, seed, Config, block, placedSoFar, quadrant == 1)
		if why then
			return finish({ ok = false, message = why })
		end
		local total = placedSoFar + count
		if total > Map.BUDGET.brush then
			return finish({
				ok = false,
				partsCreated = count,
				message = string.format("%d brush parts, over Map.BUDGET.brush = %d", total, Map.BUDGET.brush),
			})
		end
		return finish({
			ok = true,
			partsCreated = count,
			message = string.format("%d bushes; %d so far", count, total),
		})
	elseif spec.kind == "stand" then
		local root = ensureRoot(seed)
		local count, keys, why = Props.tieTrees(root, seed, Config)
		Props.clearAssets(root)
		if why then
			return finish({ ok = false, message = why })
		end
		return finish({ ok = true, partsCreated = count, proxyUsed = keys })
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
			message = string.format("%d tie trees tagged (existing trunks)", tagged),
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
		digest = Digest.of(digestEntries(root), samples, Config.DIGEST_ROUND, Ground.readPalette(Config)),
		parts = partsUnder(root),
		samples = #samples,
		-- The seed THIS MAP was built from, read off the root, not the contract's `Map.SEED` -- which
		-- is 0 until the M2.5 switch sets it, and which this field is one of the inputs to.
		seed = MapGen.builtSeed(),
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

local function taggedInside(root: Instance, tag: string): { BasePart }
	local out: { BasePart } = {}
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(root) then
			table.insert(out, instance)
		end
	end
	return out
end

-- ---------------------------------------------------------------- reachability

-- CAN THE BOAR ACTUALLY GET THERE? Every BoarSpawn and the DriverStart, pathfound to the drive line
-- with the BOAR'S OWN agent parameters. This is design section 1.1 item 7 and section 13.1 check 5,
-- moved here because the harness spec can only see the world `EXPECTED_WORLD` names -- the arena --
-- and so has never looked at the generated map. That gap is exactly how an ungated hedgerow wall
-- across the drive corridor survived Task 43's first two review rounds (TASKS.md row 43a(k)).
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
	-- FIVE TARGETS ALONG THE LINE, not its centre (design section 16.4, closing TASKS.md row 44a(e)).
	-- The line is 1,240 studs wide now; pathing only to its midpoint proved one corridor down the
	-- middle of the map and said nothing about whether a boar pushed toward x = +500 can reach the
	-- road at all. Five points at 0, +/-1/4 and +/-1/2 of the span.
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
-- cannot drift from the code that places them. `Map.EXPECTED_COUNTS` describes the world
-- `Map.EXPECTED_WORLD` names, which in M2.1 is still the arena: a different world, different counts.
function MapGen.expectedCounts(): { [string]: number }
	local counts: { [string]: number } = { tree = Config.WORLD.tieTrees }
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
}
	local findings: { string } = {}
	local root = existingRoot()
	if root == nil then
		-- EVERY FIELD, even here (TASKS.md row 45a(c)). The annotation above makes `streaming`,
		-- `markerDigest` and `seed` mandatory, and this early return used to omit all three: a
		-- --!strict mismatch, and a caller that read `.markerDigest` off it got nil instead of "".
		return {
			ok = false,
			findings = { Config.ROOT_NAME .. " does not exist in Workspace" },
			counts = {},
			streaming = {},
			markerDigest = "",
			seed = nil,
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

	-- AGAINST THE MAP'S OWN RECTANGLE, not `Map.FIELD`: while `EXPECTED_WORLD` is "arena" the
	-- contract's rectangle is the arena's (it must equal `Boar.CONFIG.field`, which the spec asserts),
	-- and the generated map is 2048 studs across. At the M2.5 switch `Config.FIELD` becomes both.
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

	-- EVERY SHOOTER POST STANDS ON THE ROAD, AT GROUND (round 2, finding 4; design 6.5 and 16.1
	-- checks 4b/4c). Round 1's comment in Layout.markers claimed the post's bottom face was "the one
	-- number the contract checks" and nothing checked it at all -- so the 9.5-stud drop this task
	-- says it closed (row 43a(l), audit-004 F9) was held closed by nothing.
	for _, post in ipairs(taggedInside(root, Map.TAGS.shooterPost)) do
		local bottom = post.Position.Y - post.Size.Y / 2
		if math.abs(bottom - Config.FIELD.groundY) > Map.SPAWN_PAD.tolerance then
			table.insert(
				findings,
				string.format(
					"%s's bottom face is at y=%.2f, more than %.2f studs from groundY",
					post.Name,
					bottom,
					Map.SPAWN_PAD.tolerance
				)
			)
		end
		-- ...and ON THE GRAVEL, not merely at the right height beside it.
		if math.abs(post.Position.Z - Map.ROAD.z) > Map.ROAD.halfWidth then
			table.insert(
				findings,
				string.format(
					"%s is %.1f studs off the road centreline, past halfWidth %d",
					post.Name,
					math.abs(post.Position.Z - Map.ROAD.z),
					Map.ROAD.halfWidth
				)
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

	-- NOTHING COLLIDABLE STANDS ON THE ROAD, along its WHOLE length (round 2, finding 1). A hedge
	-- line crossing it left a 7-stud wall across the gravel that every other check was blind to,
	-- because no check looked at the road at all. This walks it end to end.
	local blockers: { string } = {}
	for _, part in ipairs(root:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			local dz = math.abs(part.Position.Z - Map.ROAD.z)
			local onRoad = part.Position.X >= Map.ROAD.from and part.Position.X <= Map.ROAD.to
			if onRoad and dz <= Map.ROAD.halfWidth + Map.ROAD.verge then
				table.insert(blockers, string.format("%s at (%.0f, %.0f)", part.Name, part.Position.X, part.Position.Z))
			end
		end
	end
	if #blockers > 0 then
		table.insert(
			findings,
			string.format(
				"%d collidable part(s) stand on the road or its verge: %s",
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
	return {
		ok = #findings == 0,
		findings = findings,
		counts = counts,
		-- What the place actually says about streaming, beside what the contract wants: the four
		-- properties Luau cannot reach read as "unreachable from Luau" rather than as a number nobody
		-- checked (row 43a(m) gave this function its reader).
		streaming = Settings.current(),
		-- The half of the digest a spec can afford, which is what M2.5's committed-digest check will
		-- compare against (design section 13.1 check 11).
		markerDigest = MapGen.markerDigest(),
		seed = MapGen.builtSeed(),
	}
end

return MapGen
