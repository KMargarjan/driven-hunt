--!strict
-- Places.Store: THE ONE THING THAT MOVES A STUDIO-CONTENT SOURCE OUT OF `Workspace` when it stands
-- over no ground, and the only writer of `ServerStorage.Sources`.
--
-- Task 341. After the world trim (task 340) the land outside the kept boxes is Air, and 1,862 parts
-- of the bought forest -- `Workspace.Session` (two folders) and `Workspace.LobbyAssets` -- were left
-- hanging over nothing. `docs/design/cell-loading.md` 10.3 kept them on purpose because
-- `Places.pickTemplate` chooses a template by scale among every instance of a name, so they may not
-- be thinned. The Director's answer (2026-11-09) is neither delete nor thin: MOVE them where nothing
-- is drawn, and let everything that reads them read them there.
--
-- IT MOVES AND IT NEVER CREATES OR DESTROYS, which is `Places.Cells`' split by VERB: `dressCell`
-- makes and destroys models, `Cells` moves whole cell folders, this moves whole source children.
-- Every move is stamped with the folder it came out of, so it is reversible (rule 7).
--
-- IT REFUSES AT EDIT TIME, and that refusal is not caution (design 4.3, lesson L-057):
-- `default.project.json` maps ALL of `ServerStorage` to `src/serverstorage` with Rojo's default
-- `$ignoreUnknownInstances: false`, so a store created in EDIT would be DELETED at the next Connect
-- -- and 1,862 parts of Karen's bought forest with it. https://rojo.space/docs/v7/project-format/
-- So nothing is persisted: the place file keeps its forest exactly where it is, and only the running
-- server is thinned.
--
-- Design: docs/design/cell-loading.md (4.3, 10.3)
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- `Store` REQUIRES `Places`; `Places` NEVER REQUIRES `Store` -- `Places.Cells`' rule (design 2), for
-- the same reason: `tools/terrainbake.py` rewrites every `require` in `Places/init.luau`.
local Places = require(ServerScriptService:WaitForChild("Places"))

local Store = {}

-- WHERE A SOURCE WAITS. The shared plan's one spelling, through the planter's alias.
Store.STORE_NAME = Places.SOURCE_STORE

-- WHICH `Workspace` FOLDER A STOWED CHILD CAME OUT OF, so the move is reversible and a reader can
-- see at a glance what the store holds.
Store.HOME_ATTRIBUTE = "SourceHome"

-- THE GROUND RAY STARTS ABOVE EVERYTHING. A ray begun INSIDE terrain returns nil, so a ray started
-- at a seated tree's own foot reads "no ground" for a tree that is standing on it -- measured on
-- 2026-11-09, when that mistake read 4,809 of `OurForest`'s 4,819 models as groundless. The world's
-- highest terrain after the trim is y 548 (`reviews/task-340/MEASUREMENTS.md`), so 1,200 is above
-- all of it and 3,000 of depth reaches below the lowest (y 9).
Store.RAY_TOP_STUDS = 1200
Store.RAY_DEPTH_STUDS = 3000

-- A PART IS INVISIBLE AT OR ABOVE THIS TRANSPARENCY, and an invisible part is not what Karen sees
-- hanging in the sky. `Places.INVISIBLE_AT`'s number, through the planter, not a second copy.
Store.INVISIBLE_AT = Places.INVISIBLE_AT

export type Candidate = {
	instance: Instance,
	home: string,
	parts: number,
	grounded: boolean,
}

export type Report = {
	moved: number,
	movedParts: number,
	stayed: number,
	stayedParts: number,
	roots: number,
	rows: { string },
	ms: number,
	reason: string?,
}

-- ---------------------------------------------------------------- pure

-- EDIT TIME IS `IsStudio() AND NOT IsRunning()` -- the predicate borrowed by name from
-- `src/serverstorage/MapGen/Contract.luau`, exactly as `Places.Cells.editTime` borrows it (rule 2).
--   https://create.roblox.com/docs/reference/engine/classes/RunService#IsRunning
function Store.editTime(): boolean
	return RunService:IsStudio() and not RunService:IsRunning()
end

-- WHAT MOVES. PURE: a list of candidates in, two lists out -- so every branch is reachable from a
-- spec with no world and no terrain at all.
--
-- THE RULE IS ONE FACT AND NOT A BOX: a child moves when there is NO TERRAIN UNDER IT. A keep
-- rectangle would be a second copy of `tools/terrainbake.py`'s keep set, and it is not needed:
-- measured in Karen's Forest Test on 2026-11-09, every child this rule keeps also stands inside the
-- trim's keep boxes and every child it moves stands outside them, so the box adds no answer.
function Store.plan(candidates: { Candidate }): ({ Candidate }, { Candidate })
	local move: { Candidate } = {}
	local stay: { Candidate } = {}
	for _, one in ipairs(candidates) do
		-- A CHILD WITH NO VISIBLE PART STAYS. Nothing is drawn for it, so moving it buys nothing and
		-- an empty model is exactly the shape a bad measurement produces.
		if one.parts > 0 and not one.grounded then
			table.insert(move, one)
		else
			table.insert(stay, one)
		end
	end
	return move, stay
end

-- ---------------------------------------------------------------- read-only

-- IS THERE TERRAIN UNDER THIS COLUMN? An INCLUDE filter holding only `Workspace.Terrain`, so a part
-- stacked on another part cannot read as ground -- which is what `340-floaters.luau` did, and why
-- its count (1,618) is lower than this rule's (1,862).
--
-- IT READS THE REAL `Workspace.Terrain` AND NOTHING ELSE, deliberately: there is one terrain in a
-- place and a spec can neither make nor fake one, so the SEAM is the whole function -- every caller
-- takes `terrainUnder` as an argument and a spec hands in its own hillside.
function Store.terrainUnder(): (number, number) -> boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	return function(x: number, z: number): boolean
		return Workspace:Raycast(
			Vector3.new(x, Store.RAY_TOP_STUDS, z),
			Vector3.new(0, -Store.RAY_DEPTH_STUDS, 0),
			params
		) ~= nil
	end
end

-- EVERY CHILD OF EVERY SOURCE FOLDER, WITH THE ONE FACT THE PLAN NEEDS. `Places.foliageRoots` is the
-- one rule for "which folders hold this world's own foliage", and it WALKS the children rather than
-- looking a name up -- this place has two folders both called `Session` (lesson L-169).
function Store.candidates(world: Instance?, terrainUnder: ((number, number) -> boolean)?): { Candidate }
	local root = world or Workspace
	local under = terrainUnder or Store.terrainUnder()
	local out: { Candidate } = {}
	for _, folder in ipairs(Places.foliageRoots(root)) do
		for _, child in ipairs(folder:GetChildren()) do
			local parts, lowY, lowAt = 0, math.huge, nil :: BasePart?
			local function one(part: BasePart)
				if part.Transparency < Store.INVISIBLE_AT then
					parts += 1
					local bottom = part.Position.Y - part.Size.Y / 2
					if bottom < lowY then
						lowY, lowAt = bottom, part
					end
				end
			end
			if child:IsA("BasePart") then
				one(child :: BasePart)
			end
			for _, thing in ipairs(child:GetDescendants()) do
				if thing:IsA("BasePart") then
					one(thing :: BasePart)
				end
			end
			table.insert(out, {
				instance = child,
				home = folder.Name,
				parts = parts,
				grounded = lowAt ~= nil and under((lowAt :: BasePart).Position.X, (lowAt :: BasePart).Position.Z),
			})
		end
	end
	return out
end

-- ---------------------------------------------------------------- the one writer

local function ensure(parent: Instance, name: string): Instance
	local made = Instance.new("Folder")
	made.Name = name
	made.Parent = parent
	return made
end

-- TAKE EVERY GROUNDLESS SOURCE CHILD OUT OF THE WORLD. Returns what it found and what it moved.
--
-- ONE MIRROR FOLDER PER SOURCE FOLDER, created in `foliageRoots` order and only when something
-- actually moves into it. Two folders named `Session` therefore mirror as two folders named
-- `Session` in the same order, so `Places.templates`' `FindFirstChild` answers the store's mirror of
-- the SAME one it would have answered in `Workspace` (`places.spec` asserts that rather than
-- trusting it).
function Store.stow(
	world: Instance?,
	store: Instance?,
	terrainUnder: ((number, number) -> boolean)?,
	clock: (() -> number)?,
	-- BOTH ARMS BY PARAMETER, so a spec reaches the refusal without being in Edit.
	isEdit: boolean?
): Report
	local tick = clock or os.clock
	local started = tick()
	local report: Report = {
		moved = 0,
		movedParts = 0,
		stayed = 0,
		stayedParts = 0,
		roots = 0,
		rows = {},
		ms = 0,
	}
	if if isEdit == nil then Store.editTime() else isEdit then
		report.reason = "edit-time"
		return report
	end
	local root = world or Workspace
	local storeRoot = store or ServerStorage
	local roots = Places.foliageRoots(root)
	report.roots = #roots
	if #roots == 0 then
		-- THE DEV CASE, AND IT IS NOT AN ERROR: neither `OurForest` nor `Session` exists there.
		report.reason = "no-sources"
		return report
	end
	local move, stay = Store.plan(Store.candidates(root, terrainUnder))
	for _, one in ipairs(stay) do
		report.stayed += 1
		report.stayedParts += one.parts
	end
	if #move == 0 then
		report.ms = (tick() - started) * 1000
		return report
	end
	local shelf: Instance? = nil
	-- WHICH MIRROR EACH SOURCE FOLDER GETS, keyed by the FOLDER INSTANCE and never by its name: two
	-- folders called `Session` must not pour into one.
	local mirrors: { [Instance]: Instance } = {}
	local counts: { [Instance]: { number } } = {}
	for _, one in ipairs(move) do
		local home = one.instance.Parent :: Instance
		if shelf == nil then
			shelf = storeRoot:FindFirstChild(Store.STORE_NAME) or ensure(storeRoot, Store.STORE_NAME)
		end
		local mirror = mirrors[home]
		if mirror == nil then
			mirror = ensure(shelf :: Instance, home.Name)
			mirrors[home] = mirror
			counts[home] = { 0, 0 }
		end
		one.instance:SetAttribute(Store.HOME_ATTRIBUTE, one.home)
		one.instance.Parent = mirror
		report.moved += 1
		report.movedParts += one.parts
		local row = counts[home]
		row[1] += 1
		row[2] += one.parts
	end
	-- ONE ROW PER SOURCE FOLDER, in `foliageRoots` order, so the console line names what moved and
	-- what stayed by folder and by count -- the Director's own ask.
	for _, folder in ipairs(roots) do
		local row = counts[folder]
		if row ~= nil then
			table.insert(report.rows, string.format("%s %d child(ren)/%d part(s)", folder.Name, row[1], row[2]))
		end
	end
	report.ms = (tick() - started) * 1000
	return report
end

-- THE CONSOLE LINE, OR NIL WHEN NOTHING MOVED AND NOTHING REFUSED -- `Cells.line`'s rule: a print
-- every boot saying nothing changed would bury the one that did.
function Store.line(report: Report): string?
	if report.moved == 0 and report.reason == nil then
		return nil
	end
	if report.reason ~= nil then
		return string.format("[Places.Store] %s (%d source folder(s))", tostring(report.reason), report.roots)
	end
	return string.format(
		"[Places.Store] stowed %d child(ren)/%d part(s) over no ground into ServerStorage.%s [%s]; "
			.. "left standing %d child(ren)/%d part(s) in %.0f ms",
		report.moved,
		report.movedParts,
		Store.STORE_NAME,
		table.concat(report.rows, ", "),
		report.stayed,
		report.stayedParts,
		report.ms
	)
end

return Store
