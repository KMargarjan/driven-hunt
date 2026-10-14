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
-- THE SHOP INSIDE THE LODGE IS TASK 178, and it is built: the counter task 177 left is the door --
-- walk up to it and `Hud.ShopPanel` opens. This module gained one reader for it
-- (`Lobby.counterPosition`) and the sign gained the shop's name; everything else about the lodge is
-- unchanged.
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
-- THE STUDIO-MADE TEMPLATE FOLDER THE FREE MODELS LIVE IN (task 180), and the one name anything
-- outside this system finds it by. `Workspace` is not Rojo-owned, so a model parked there survives
-- Karen's Connect; `OurForest`, `Foliage` and the two `Session` folders in the same place are the
-- same kind of content, put there the same way.
--
-- WHY A FOLDER IN THE WORLD AND NOT AN ASSET ID: measured, task 180 (note section 3).
-- `InsertService:LoadAsset` refuses a free Creator Store model that its creator did not tick
-- "distribute" (task 152: *"User is not authorized to access Asset."*), and the documented escape
-- `AssetService.AllowInsertFreeAssets` is `RobloxScriptSecurity` on read AND write, so no script can
-- take it. A `.model.json` cannot carry geometry either -- the harness fails a typed value
-- (`{"Vector3": ...}`) as "cannot compare" (`tools/studio_mcp.py` docstring) -- and `.rbxm` is banned
-- (CLAUDE.md). What is left, and what StudioMCP's `insert_asset` can do with no human click, is to
-- insert the model into the place ONCE, in Edit, and have the run-time owner clone it.
Lobby.TEMPLATES_NAME = "LobbyAssets"
-- The four children `Build` looks for inside it. A missing one is not an error: the lodge, the truck
-- and the trophies each fall back to task 177's parts build, one at a time.
Lobby.TEMPLATE = {
	LODGE = "Lodge",
	TRUCK = "Truck",
	DEER = "DeerHead",
	BOAR = "BoarHead",
	TREES = "Trees", -- a folder of tree models copied out of `Workspace.OurForest`
}
-- THE SHOP COUNTER (task 178). `Build.interior` builds it under `Lodge.Inside.Shop`, and this is the
-- name both readers find it by.
Lobby.COUNTER_NAME = "Counter"

-- THE SHOPKEEPER AND HIS PROMPT (task 181). Karen, 2026-10-14: *"in lobby has to be a person bot who
-- you need to click E to get access to shop"*. `Build.shopkeeper` builds both under
-- `Lodge.Inside.Shop`, and these are the names the CLIENT finds the prompt by -- the one way into
-- the panel since this task took task 178's auto-open away.
Lobby.KEEPER_NAME = "Shopkeeper"
Lobby.PROMPT_NAME = "ShopPrompt"

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
-- both the road and `ForestTest.exitZOf(layout)` for every drive layout, so it cannot interact with the drive.
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
		-- THE YARD'S PAD: THE GROUND UNDER THE BUILDINGS, AND IT IS A LOOK FIX THAT WAS PHOTOGRAPHED
		-- RATHER THAN GUESSED (task 177). The first build laid the lodge on the grass shelf and the
		-- inside shot came back with TERRAIN GRASS GROWING THROUGH THE FLOORBOARDS: Roblox draws a
		-- grass material's blades on the terrain surface, and a part laid over them does not hide
		-- them. `Enum.Material.Ground` has no blades, so one more block of it under the footprint of
		-- the lodge, the porch, the yard and the truck is the whole fix -- and it keeps the FIELD
		-- grass, which is what makes the field read as a field from outside.
		--
		-- TWO PADS SINCE TASK 180, AND THE SECOND ONE IS WHY THE ROAD IS VISIBLE AT ALL. The first
		-- build of the road laid its slabs flush on the grass shelf and the screenshot came back with
		-- a field and NO ROAD: the player was standing on it. Same cause as the floorboards above --
		-- Roblox draws a grass material's blades on the terrain surface and a part laid over them does
		-- not hide them -- so the road corridor gets its own blade-free block, and `Build.road` lifts
		-- the slab to sit ON the shelf instead of half inside it.
		--
		-- A LIST, so a third pad is a row and not a third code path. Every entry's TOP is the shelf,
		-- and `lobby.spec` holds all of them to the same rectangle the two big blocks are held to.
		PADS = {
			-- THE YARD: under the lodge, its porch, the spawn, the circle and all four truck bays. It
			-- grew with the bays in task 180 (80 x 60 held one truck).
			{
				NAME = "Yard",
				OFFSET = Vector3.new(26, 0, 30),
				SIZE = Vector3.new(140, 6, 90),
				MATERIAL = Enum.Material.Ground,
			},
			-- THE ROAD CORRIDOR: the lane, both verges and a stud either side, from the lodge's front
			-- to the shelf's southern edge.
			{
				NAME = "Road",
				OFFSET = Vector3.new(20, 0, -24),
				SIZE = Vector3.new(34, 6, 160),
				MATERIAL = Enum.Material.Ground,
			},
		},
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
		-- THE SHOP'S COUNTER, and `Shop.CONFIG.REACH_STUDS` (14) is measured against its 12-stud
		-- width: a man at either end of it can reach the till.
		COUNTER = Vector3.new(12, 3.5, 2),
		-- TASK 178 REPLACED THE PLACEHOLDER, which said "SHOP - coming soon" and is archived with its
		-- reason in `backups/2026-10-14_task-178_lodge-sign.txt` (rule 7).
		SIGN_TEXT = "SHOP",
		-- THE MAN BEHIND THE COUNTER (task 181), and every number here is in
		-- `docs/research/2026-10-14-the-shopkeeper.md` section 4 with where it came from.
		KEEPER = {
			-- WHERE HE STANDS, from the counter's own centre: 1.4 studs further from the room
			-- (toward the back wall) so he is BEHIND the till and not standing in it. The counter is
			-- 2 studs deep, so 1.4 clears its face by 0.4 -- and the back wall is 2 studs beyond,
			-- which is why this is not 2.
			BEHIND_STUDS = 1.4,
			-- HOW HIGH HIS FEET GO ABOVE THE FLOOR, the figure `Rig.place` pivots to: an R15 rig's
			-- origin is its root, about 3 studs over the ground it stands on.
			ROOT_HEIGHT = 3,
			-- HUNTER GREEN FROM `Match.Body` AND A HAT OF HIS OWN. `Body.dress` takes the team for
			-- the green and task 178's `Look` for the hat; `Body.tintFor` recolours the hat ONLY, so
			-- a lodge keeper's brown felt is exactly one field and the apron is not modelled.
			TEAM = "Hunter",
			HAT_COLOR = Color3.fromRGB(96, 66, 42),
			-- `Bots.Rig.CLIPS.idle` -- THE SAME ASSET THE DRIVE BOTS ALREADY STAND IN, written here
			-- rather than required out of `Bots` so the lobby does not depend on the drive's owner.
			-- Played ONCE, at build: nothing in this system is written per frame.
			IDLE_ANIMATION = "rbxassetid://507766666",
			-- THE LOOK-AT, on the lobby's own existing 10 Hz scan and never on a clock of its own.
			-- `FACE_STUDS` is how near a man has to be before the keeper turns to him, and the
			-- epsilon is what stops a yaw being written every scan for a player standing still.
			LOOK_AT = true,
			FACE_STUDS = 16,
			FACE_EPSILON_DEGREES = 3,
			-- HOW HIGH THE PROMPT HANGS ABOVE HIS ROOT, and it is geometry rather than taste: the
			-- counter is 3.5 studs tall and queryable, so a line-of-sight ray aimed at a root 3
			-- studs up is stopped by the till itself and the prompt never appears for the one
			-- person standing where he is meant to stand. 2.2 puts it at head height.
			PROMPT_HEIGHT = 2.2,
			-- THE PROMPT ITSELF. `HOLD_SECONDS = 0` is a tap and not a hold; line of sight is
			-- Valve's `+use` rule (note section 2c); 8 studs is the Director's number and reaches a
			-- man anywhere along the 12-stud counter.
			PROMPT = {
				ACTION_TEXT = "Shop",
				OBJECT_TEXT = "Press E",
				MAX_DISTANCE = 8,
				HOLD_SECONDS = 0,
				REQUIRES_LINE_OF_SIGHT = true,
				KEYBOARD_KEY = Enum.KeyCode.E,
				GAMEPAD_KEY = Enum.KeyCode.ButtonX,
			},
		},
		-- THE FREE MODEL, AND THE MEASUREMENTS THAT POSITION WHAT GOES INSIDE IT (task 180).
		-- "Log Cabin" by **uhhhh17**, Creator Store 4746497269, free: 266 parts, **no script of any
		-- kind**, 23.1 x 15.9 x 30.9 studs as delivered, with a porch, steps, railings and windows.
		-- Measured by raycast inside it: an interior FLOOR 3.3 studs above its own base and a CEILING
		-- at 10.7, so a 7.4-stud room -- a character is about 5. Credited in `CREDITS.md`.
		--
		-- `SCALE` is applied with `Model:ScaleTo`, which scales a MeshPart's own geometry too (none
		-- of these four models is skinned, so there is no `boar_prep.py` problem here). The two
		-- heights below are the model's OWN numbers and this module multiplies them by `SCALE`:
		-- writing the products instead would be two numbers that silently disagree the first time
		-- the scale moves.
		MODEL = {
			SCALE = 1,
			-- The model is delivered with its porch facing -Z, which is the way task 177's parts
			-- lodge already faces, so there is no yaw to apply. Kept as a number so a replacement
			-- model that faces another way is one edit here.
			YAW_RADIANS = 0,
			-- THE ROOM INSIDE IT, RAYCAST RATHER THAN READ OFF THE LISTING (task 180), relative to
			-- the model's own bounding-box CENTRE in x and z and to its BASE in y, before `SCALE`.
			-- The bounding box is not the room: 10.6 studs of the model's 30.9-stud depth is the
			-- porch, which is why the room's centre sits 5 studs north of the box's.
			--   east wall  x = +9.76   west wall  x = -10.01
			--   back wall  z = +14.85  front wall z = -4.90
			--   floor      y =  3.31   ceiling    y =  10.72
			-- HALF_X AND HALF_Z BY NAME, not a `Vector2` whose `Y` secretly means z (review round 2,
			-- note): both happen to be 9.8, so a swapped pair would be invisible.
			ROOM = {
				CENTRE = Vector3.new(-0.1, 3.3, 5.0),
				HALF_X = 9.8,
				HALF_Z = 9.8,
				CEILING_Y = 10.7,
			},
		},
	},
	-- ---------------- the trophies on the wall
	--
	-- KAREN, 2026-10-14: *"and then on walls we can make trophys like head of deer head of boar"*.
	-- Two free Creator Store models, both script-free: "Deer Head Wall Mount Trophy Decor Home" by
	-- **bell4hd** (101243188132816, 26 parts, 5.0 x 5.4 x 2.9) and "Boar Head" by **Atejime**
	-- (15282258007, 3 parts, 3.3 x 2.1 x 2.8). The boar head has no plaque of its own, so this
	-- module builds it one -- a plank, which is what the parts build is for.
	--
	-- A MOUNT NAMES A WALL AND HOW FAR ALONG IT, never an absolute offset, so the same three rows
	-- hang the same three heads on the free model's 19.6 x 19.6 room AND on task 177's 38 x 26 one.
	-- An offset in studs would be right for exactly one of the two builds and silently wrong -- a
	-- trophy half inside a wall -- for the other.
	TROPHIES = {
		HEIGHT_STUDS = 4.4, -- above the interior floor: above a standing player's head
		PLAQUE = Vector3.new(3.4, 3.8, 0.5),
		PLAQUE_COLOR = Color3.fromRGB(78, 56, 38),
		CLEAR_STUDS = 0.7, -- how far the mount's face stands off the wall
		-- THE SIDE WALLS, AND THE BACK WALL IS DELIBERATELY EMPTY. The first build hung two of the
		-- three on the back wall and the inside shot showed why that is wrong: the fireplace stands
		-- at `centre.X - halfX/2` on that wall and the shop counter at `+ halfX/2`, with the SHOP
		-- sign above it -- so a head at -5.5 was half inside the chimney and one at +5.5 was behind
		-- the sign. The back wall of this room is already fully spoken for.
		MOUNTS = {
			{ kind = "deer", wall = "west", along = -3 },
			{ kind = "boar", wall = "east", along = -3 },
			{ kind = "deer", wall = "east", along = 3 },
		},
	},
	-- ---------------- the truck, the track, the spot
	--
	-- "Walk to a car" (Karen). The truck is parked on the track, east of the lodge's front.
	TRUCK = {
		OFFSET = Vector3.new(26, 0, 18),
		SIZE = Vector3.new(7, 7, 16),
		WHEELS = 4,
		COLOR = Color3.fromRGB(46, 62, 44), -- hunting green
		-- FOUR OF THEM, PARKED SIDE BY SIDE (the Director, task 180): one per party, with room
		-- BEHIND each for task 182's queue pad. `OFFSET` above is bay 1 and `BAY_GAP_STUDS` steps
		-- east from it, so task 177's single-truck geometry is still the first bay and the truck spot
		-- still sits beside it -- 177's flow is unchanged until 182 replaces the spot with pads.
		COUNT = 4,
		BAY_GAP_STUDS = 17,
		-- THE FREE MODEL: "PickUp Truck (Prop)" by **RedWood Roleplay GROUP**, Creator Store
		-- 8891351929, free: 76 parts, **no script of any kind**, no VehicleSeat, 18.5 x 7.0 x 8.7
		-- studs -- a prop, which is exactly what a parked truck in a lobby is. Four copies cost 304
		-- parts, against 937 for the prettiest candidate and 617 for the next. Credited in
		-- `CREDITS.md`.
		--
		-- IT IS DELIVERED POINTING ALONG ITS OWN +X, and the yard wants it pointing SOUTH down the
		-- track, so a quarter turn. Written as a number for the same reason as the lodge's.
		MODEL = { SCALE = 1, YAW_RADIANS = 1.5707963 },
		-- WHERE TASK 182'S PAD WILL GO, said once, here, so that task moves nothing: 12 studs behind
		-- the tailgate, which is where a man loading into the back would stand.
		PAD_BEHIND_STUDS = 12,
	},
	TRACK = { WIDTH_STUDS = 14, TO_Z = 110, MATERIAL = Enum.Material.Ground },
	-- ---------------- the road, the fences and the tree line: "a bit more nicer" (Karen)
	--
	-- KAREN, 2026-10-14: *"place could be a bit more nicer like road going to that house and around
	-- fields and forrests"*.
	--
	-- THE ROAD STAYS INSIDE THE FIELD, AND THAT IS A MEASUREMENT AND NOT A PREFERENCE. `Field.fill`
	-- flattens a 220 x 220 shelf and nothing else; the measured ground falls ~10 studs in the first
	-- 110 studs south of the anchor and ~20 by 160 (task 180, raycast grid). A flat strip laid past
	-- the shelf's edge would float exactly the way `docs/design/lobby.md` section 9 refuses a slab
	-- lodge to, so the road runs from the lodge to the shelf's southern edge and stops there, where
	-- the tree line closes the view anyway.
	ROAD = {
		WIDTH_STUDS = 20,
		-- THICK ENOUGH TO SIT ON THE SHELF AND BE SEEN. `Build.road` centres the slab at
		-- `shelfY + THICK_STUDS / 2`, so the whole of it is above the terrain rather than half
		-- inside it (task 180, after the first road shot came back showing no road at all).
		THICK_STUDS = 0.5,
		-- PAST the lodge's front wall (z +32 for the parts build, +30.6 for the model) and under
		-- its floor, so the lane reads as arriving AT the house rather than stopping short of it.
		FROM_Z = 56,
		TO_Z = -104, -- the field's southern edge (half-span 110, less a margin)
		CENTRE_X = 20, -- between the lodge's front door and the truck bays
		COLOR = Color3.fromRGB(128, 112, 88),
		MATERIAL = Enum.Material.Ground,
		-- THE VERGES: two strips of worn earth either side, which is what makes a road read as a
		-- road rather than as a grey rectangle.
		VERGE_STUDS = 3,
		VERGE_COLOR = Color3.fromRGB(104, 92, 68),
	},
	-- A POST-AND-RAIL FENCE down both sides of the road, ENDING SOUTH OF THE YARD so the yard, the
	-- porch and the lodge are open.
	--
	-- `TO_Z` IS A BOUND AND NOT A COUNT, and that is the whole of review round 2's blocking finding.
	-- Written as `POSTS_PER_SIDE = 9` from `FROM_Z = -98` at 18 studs, the west line (`CENTRE_X` 20
	-- less `OFF_ROAD_STUDS` 18 = x +2) ran to z +46 -- which is the LODGE's own centre. Post 9 stood
	-- inside the cabin through its floorboards, post 8 in the middle of the porch two studs from the
	-- doorway, and the rails lay across the spawn pad at knee height. The comment above already said
	-- *"a gap at the yard"*; nothing implemented it. A southern limit cannot drift into the house the
	-- way a count can: `Build.fences` walks from `FROM_Z` and stops at `TO_Z`.
	FENCE = {
		SPACING_STUDS = 18,
		FROM_Z = -98,
		-- The yard slab reaches z -4 (`TRUCK.OFFSET.Z` 18 less half of its 44-stud depth), so -8
		-- leaves it four studs clear and the last rail ends there too.
		TO_Z = -8,
		OFF_ROAD_STUDS = 18, -- how far either side of the road's centre the line runs
		POST = Vector3.new(0.9, 5, 0.9),
		RAIL_Y = { 1.6, 3.4 },
		RAIL_THICK = 0.5,
		COLOR = Color3.fromRGB(96, 76, 54),
	},
	-- THE FOREST EDGE, AND IT IS THE FOREST'S OWN TREES (Karen: *"forrests"*; the Director: *"reuse
	-- the forest's trees"*). `Workspace.LobbyAssets.Trees` is a folder of models copied out of
	-- `Workspace.OurForest` in Studio, so the lobby's edge is the same wood the drive runs in rather
	-- than a second kind of tree. No folder, no tree line -- it is scenery and it never blocks.
	TREELINE = {
		COUNT = 30,
		RADIUS_STUDS = 100, -- just inside the field's half-span of 110
		-- THE ARC THEY STAND ON: south-east round to south-west, so the trees frame the road and the
		-- yard without ever standing between the porch and the forest that is really there to the
		-- north.
		-- THE ARC LEAVES A GAP DUE NORTH, and that was a bug before it was a decision: written as
		-- -2.6 .. +2.6 it swept THROUGH angle 0, which IS north -- so the tree line stood between the
		-- lodge and `OurForest`, the real wood 54 studs behind it, and left the road's approach open.
		-- It runs east -> south -> west instead. The gap is +-34 degrees of north and no more, so
		-- there ARE trees north-east and north-west of the lodge; what the gap protects is the view
		-- straight out of the back of the lodge into the forest that is really there. 0 is north, pi
		-- is south.
		FROM_RADIANS = 0.6,
		TO_RADIANS = 5.68,
		JITTER_STUDS = 9,
		SCALE = { 0.85, 1.35 },
	},
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
	SPAWN = {
		OFFSET = Vector3.new(0, 0, 16),
		SIZE = Vector3.new(12, 1, 6),
		SPREAD_STUDS = 6,
		-- HOW MANY PLACES THERE ARE ON THE PORCH, AND IT IS A BOUND AND NOT A PREFERENCE (review
		-- round 1, finding 3). `Lobby.spawnCFrame` lays its slots centre-out -- 0, +1, -1, +2, -2 --
		-- so slot n is `floor((n + 1) / 2) * SPREAD_STUDS` studs off the middle. SEVEN slots is a
		-- worst case of 3 * 6 = 18 studs, inside the lodge's own 40-stud front (half-width 20) that
		-- `docs/design/lobby.md` section 8.3 names.
		--
		-- UNBOUNDED, IT ENDED IN A RESPAWN LOOP. The index was a counter that only ever went up, one
		-- per player who had ever joined, so slot 37 is 114 studs off the middle -- outside
		-- `FIELD.SPAN_STUDS`'s half-span of 110. `Join.insideField` then answers FALSE for the man
		-- standing exactly where `world.place` put him, `needsReturn` answers true, and the lobby
		-- re-places him at the same off-shelf point every `RETURN_COOLDOWN_SECONDS` for ever -- the
		-- loop `Join.needsReturn`'s own comment says it exists to prevent.
		SLOTS = 7,
	},
	-- ---------------- the rule
	COUNTDOWN_SECONDS = 5,
	SCAN_HZ = 10,
	RETURN_COOLDOWN_SECONDS = 3,
	BUILD_TIMEOUT_SECONDS = 10,
	-- THE BUDGET ROSE FROM 400 TO 1200 WITH THE FREE MODELS (task 180), and the arithmetic is written
	-- down so the number is a bound and not a shrug: the lodge is 266 parts, four trucks 304, three
	-- trophies 55, thirty trees about 150, and the road, verges, fences, ring, yard, sign, counter,
	-- fireplace and spawn about 190 -- roughly 965, with headroom for a replacement model. The parts
	-- fallback still builds about 330, so the old budget bound nothing that is still being built.
	MAX_PARTS = 1200,
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

-- THE ONE READER OF WHERE THE SHOP COUNTER IS (task 178), beside `Lobby.spotPart` and for its
-- stated reason: the server BUILDS the part, this finds it, and nobody computes the position twice.
-- Memoised the same way, and the cache is dropped the same way -- a streamed-out or rebuilt lodge
-- must answer nil rather than a stale position, because a stale counter would let a man buy things
-- from the middle of a field.
--
-- BOTH SIDES READ IT: the SERVER door measures the reach with it per request, and the Hud tells the
-- panel whether he is standing at it. One definition, two readers.
local cachedCounter: BasePart? = nil

function Lobby.counterPart(): BasePart?
	local cached = cachedCounter
	if cached ~= nil and cached:IsDescendantOf(game) then
		return cached
	end
	cachedCounter = nil
	local folder = Workspace:FindFirstChild(Lobby.FOLDER_NAME)
	if folder == nil then
		return nil
	end
	local part = folder:FindFirstChild(Lobby.COUNTER_NAME, true)
	if part ~= nil and part:IsA("BasePart") then
		cachedCounter = part :: BasePart
		return cachedCounter
	end
	return nil
end

function Lobby.counterPosition(): Vector3?
	local part = Lobby.counterPart()
	return if part then part.Position else nil
end

-- THE ONE READER OF THE SHOPKEEPER'S PROMPT (task 181), memoised and invalidated exactly like the
-- two above, and for the same reason: a prompt on a rebuilt lodge is a different instance, and a
-- panel still listening to the old one is a shop you cannot open.
--
-- THE CLIENT IS ITS READER. The server BUILDS it (`Lobby.Build.shopkeeper`) and never reads it back;
-- the Hud resolves it once a frame and TELLS `ShopPanel` (`Rail.setWeapon`'s rule), so the panel
-- holds no opinion about where the lodge is.
local cachedPrompt: ProximityPrompt? = nil

function Lobby.shopPrompt(): ProximityPrompt?
	local cached = cachedPrompt
	if cached ~= nil and cached:IsDescendantOf(game) then
		return cached
	end
	cachedPrompt = nil
	local folder = Workspace:FindFirstChild(Lobby.FOLDER_NAME)
	if folder == nil then
		return nil
	end
	local found = folder:FindFirstChild(Lobby.PROMPT_NAME, true)
	if found ~= nil and found:IsA("ProximityPrompt") then
		cachedPrompt = found :: ProximityPrompt
		return cachedPrompt
	end
	return nil
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
