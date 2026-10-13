--!strict
-- Lobby: THE DATA FOR THE LOBBY -- the hunting lodge in the fields, the truck, and the marked circle
-- beside it -- and nothing else. It writes no Instance, builds no part and enrols nobody.
--
-- Server and client both read it, which is why it is in ReplicatedStorage: the server BUILDS the
-- truck spot and the client's objective chevron has to know where it is. A second copy of that
-- position would be two definitions of where the truck is, which is this project's named failure
-- mode (docs/PROJECT_CONTEXT.md). So the one definition is the PART the server built, and
-- `Lobby.spotPosition` is the one reader of it -- exactly the `ReplicatedStorage.ForestTest` shape.
--
-- KAREN, 2026-10-13 ~19:20, verbatim:
--   *"I think after this fixes we need to focus on lobby / Hunting house where inside can shop
--   things / outside is fields and forrest so house is in fields next to forrest"*
-- and her two choices, asked one by one:
--   * the house is a *"Wooden log lodge"* -- logs, a porch, antlers over the door, warm inside;
--   * a hunt starts by *"Walk to a car"* -- a hunting truck parked by the lodge, and for this first
--     version you step into a marked spot beside it. THE CAR RIDE COMES LATER.
--
-- Her design doc (*Driven Hunt v1*) says the same thing in the order it happens: *"Everyone starts
-- in lobby / There are houses where can buy weapons, License, Gear, Goods / There is place to join
-- game / ... After you select a game you sit in car and drive to position - Loading"*.
--
-- THE SHOP INSIDE THE LODGE IS TASK 178. The interior gets an empty counter and a placeholder sign.
--
-- Design: docs/design/lobby.md (sections 2, 9, 10.3, 10.4, 12.1)
-- Note:   docs/research/2026-10-13-lobby-and-the-truck.md
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Lobby = {}

-- ---------------------------------------------------------------- the names

-- THE ONE FOLDER, and the two parts anything outside this system asks about by name.
Lobby.FOLDER_NAME = "Lobby"
Lobby.SPOT_NAME = "TruckSpot"
Lobby.SPAWN_NAME = "LodgeSpawn"

-- HOW THE COUNTDOWN REACHES THE CLIENT, with no new wire (design section 10.4). One attribute on the
-- `Player` it belongs to, holding `Workspace:GetServerTimeNow() + COUNTDOWN_SECONDS`, or nil.
--
-- ATTRIBUTES AS A ONE-WAY, READ-ONLY MIRROR IS THIS REPO'S OWN PATTERN: `ReplicatedStorage.Flags.State`,
-- `ServerStorage.DHFlag_*`, `ServerStorage.DHForestStartRole` and `LocalPlayer.TestReport` are all
-- the same shape. There is no inbound door at all, so nothing a client sends can enrol anybody.
Lobby.LEAVE_AT_ATTRIBUTE = "DHLobbyLeaveAt"

-- ---------------------------------------------------------------- where the lobby is

-- A WORLD HAS A LOBBY WHEN, AND ONLY WHEN, THERE IS A ROW FOR IT (design section 2).
--
-- `forest-test` is where Karen plays. The anchor is the MEASURED flattest open ground: a raycast
-- grid over fifteen 160 x 160 footprints south of `OurForest`'s southern edge (z = -2896) found
-- terrain under every sample and not one non-terrain obstacle, and this centre had the smallest
-- ground spread (16 studs). It is ~54 studs south of the forest edge -- so the forest fills the
-- northern view, which is Karen's *"house is in fields next to forrest"* -- and ~570 studs south of
-- both the road and `ForestTest.EXIT_Z`, so it cannot interact with the drive.
--
-- THERE IS NO `map:v1` ROW. The DEV place is where the harness runs and it has no lobby in this
-- task; `anchorFor` answers nil and `Lobby.start` builds nothing.
--
-- THE Y IS NOT HERE, AND THAT IS DELIBERATE. Nobody has measured the absolute ground height at this
-- point -- the measurements above are SPREADS, not altitudes -- so the shelf's top comes from the
-- world's own single ground reader at build time (`world.groundAt`, injected). A typed Y would be a
-- guess that puts the lodge in the air or inside the hill.
Lobby.ANCHORS = {
	["forest-test"] = { x = 2850, z = -2950 },
}

-- PURE, and it takes the world as a STRING so this module requires nothing (design section 2). The
-- boot passes `Map.EXPECTED_WORLD`.
function Lobby.anchorFor(world: string?): { x: number, z: number }?
	if type(world) ~= "string" then
		return nil
	end
	return Lobby.ANCHORS[world]
end

-- ---------------------------------------------------------------- every number and every word

-- Every offset below is RELATIVE TO THE ANCHOR, with +x east, +z north and y measured from the
-- field's own shelf -- so moving the lobby is one row in `ANCHORS` and nothing else.
--
-- `Build` reads this table and invents no number (design section 9).
Lobby.CONFIG = {
	-- ---------------- the field
	--
	-- TERRAIN, CUT AND FILLED, AND NOT A SLAB OF PARTS (research note section 6). A slab's downhill
	-- edge would float 16 studs over this slope, which is exactly the class of thing this project
	-- exists to stop ("Things measured correct and looked wrong").
	FIELD = {
		SPAN_STUDS = 220, -- 220 x 220, square, centred on the anchor
		-- THE GRASS BLOCK IS SOLID AND DEEP, so the downhill edge is a BANK and not a floating
		-- shelf. The measured spread over this footprint is 16 studs and the worst of the fifteen
		-- sampled footprints was 44, so 48 reaches below the lowest ground either way.
		DEPTH_STUDS = 48,
		-- ...AND THE AIR BLOCK ABOVE IT CUTS THE HILL OFF. 96 is well over the worst measured spread
		-- and well above the lodge's 18-stud ridge.
		CLEAR_STUDS = 96,
		MATERIAL = Enum.Material.Grass,
		-- HOW WIDE A CHUNK EACH `FillBlock` MAY BE, in studs along x. `MapGen.Ground`'s header
		-- records a MEASURED `WriteVoxels` ceiling of 24,576 voxels per region in this Studio
		-- version; `FillBlock` is a different API and its own ceiling is not measured here, so the
		-- fill is chunked the way `Ground.paintTrack` already chunks its regions. The count is in
		-- `Lobby.stats()` so which path ran is a number and not a belief.
		CHUNK_STUDS = 64,
	},
	-- ---------------- the lodge: "Wooden log lodge", logs, porch, antlers over the door, warm inside
	LODGE = {
		SIZE = Vector3.new(40, 10, 28), -- a 40 x 28 footprint with 10-stud walls
		RIDGE_STUDS = 18, -- the ridge, above the shelf
		LOG_DIAMETER = 2, -- 5 courses of cylinders per wall
		DOOR = Vector2.new(6, 9), -- WALK-THROUGH: a gap in the front wall, never a door part
		PORCH_DEPTH = 8,
		PORCH_POSTS = 4,
		WINDOWS = 4,
		-- THE LODGE SITS TOWARD THE NORTH EDGE OF THE FIELD, facing south, so a player walking out
		-- of the porch has the truck in front of him and the forest behind the roof.
		OFFSET = Vector3.new(0, 0, 46),
		MATERIAL = Enum.Material.Wood,
		ROOF_MATERIAL = Enum.Material.WoodPlanks,
		LOG_COLOR = Color3.fromRGB(104, 76, 50),
		ROOF_COLOR = Color3.fromRGB(74, 54, 38),
		FLOOR_COLOR = Color3.fromRGB(129, 101, 71),
		-- THE WARM INSIDE: one `PointLight` at the fireplace and nothing animated, nothing written
		-- per frame. Karen asked for *"warm inside"*, which is a light and not a system.
		FIRE_LIGHT = { brightness = 2, rangeStuds = 34, color = Color3.fromRGB(255, 180, 110) },
		ANTLERS = { tines = 2 }, -- a skull plate and two beams over the door
		-- TASK 178'S EMPTY COUNTER. The shop replaces the SIGN, not the counter.
		COUNTER = Vector3.new(12, 3.5, 2),
		SIGN_TEXT = "SHOP - coming soon",
	},
	-- ---------------- the truck, the track, the spot
	--
	-- "Walk to a car" (Karen). The truck is parked on the track, east of the lodge's front.
	TRUCK = {
		OFFSET = Vector3.new(26, 0, 18),
		SIZE = Vector3.new(7, 7, 16),
		WHEELS = 4,
		COLOR = Color3.fromRGB(46, 62, 44), -- hunting green
	},
	TRACK = { WIDTH_STUDS = 14, TO_Z = 110, MATERIAL = Enum.Material.Ground },
	SPOT = {
		OFFSET = Vector3.new(16, 0, 18), -- beside the driver's door
		RADIUS_STUDS = 8,
		-- THE RING IS `ForestTest.Markers.RING`'S, BORROWED WHOLE (design section 14.5), so the
		-- lobby's circle and the hunter's stand circle are the same piece of UI language: neon
		-- chords lifted clear of the ground, in hunting orange.
		RING = {
			SEGMENTS = 20,
			THICKNESS_STUDS = 0.5,
			HEIGHT_STUDS = 0.12,
			LIFT_STUDS = 0.08,
			TRANSPARENCY = 0.45,
			COLOR = Color3.fromRGB(235, 150, 60),
		},
		SIGN_TEXT = "STAND HERE TO HUNT",
	},
	-- WHERE HE ARRIVES: in front of the porch, looking +Z (north) at the lodge with the forest
	-- behind it, the truck and the ring to his right. Karen's *"house is in fields next to forrest"*
	-- read as a camera angle.
	SPAWN = { OFFSET = Vector3.new(0, 0, 16), SIZE = Vector3.new(12, 1, 6), SPREAD_STUDS = 6 },
	-- ---------------- the rule
	COUNTDOWN_SECONDS = 5,
	SCAN_HZ = 10,
	RETURN_COOLDOWN_SECONDS = 3,
	BUILD_TIMEOUT_SECONDS = 10,
	MAX_PARTS = 400,
}

-- deepFreeze, REQUIRED and not copied: `table.freeze` is shallow, and this repo has already paid for
-- that once (`src/shared/Drive/init.luau`, Task 23a note (b)).
Shotgun.deepFreeze(Lobby.CONFIG)
Shotgun.deepFreeze(Lobby.ANCHORS)

-- ---------------------------------------------------------------- the readers

-- THE ONE READER OF WHERE THE TRUCK SPOT IS (design section 10.3). The server BUILDS the part; this
-- finds it; nobody computes the position twice.
--
-- MEMOISED, AND THE CACHE IS DROPPED WHEN THE PART LEAVES THE DATAMODEL. A streamed-out or rebuilt
-- lobby must answer nil rather than a stale position -- `MapUi.pointsFor`'s own rule (*"a stale dot
-- is a lie about where somebody is"*). `IsDescendantOf(game)` is the test, because `Destroy` and a
-- re-parent both fail it.
local cachedSpot: BasePart? = nil

function Lobby.spotPart(): BasePart?
	local cached = cachedSpot
	if cached ~= nil and cached:IsDescendantOf(game) then
		return cached
	end
	cachedSpot = nil
	local folder = Workspace:FindFirstChild(Lobby.FOLDER_NAME)
	if folder == nil then
		return nil
	end
	local part = folder:FindFirstChild(Lobby.SPOT_NAME, true)
	if part ~= nil and part:IsA("BasePart") then
		cachedSpot = part :: BasePart
		return cachedSpot
	end
	return nil
end

function Lobby.spotPosition(): Vector3?
	local part = Lobby.spotPart()
	return if part then part.Position else nil
end

-- HOW MANY SECONDS UNTIL HE LEAVES. PURE, so the client's countdown is a spec and not a screenshot.
-- nil in, nil out -- "there is no countdown" is not "zero seconds left".
function Lobby.secondsLeft(leaveAt: number?, serverNow: number): number?
	if type(leaveAt) ~= "number" then
		return nil
	end
	return math.max(0, (leaveAt :: number) - serverNow)
end

return Lobby
