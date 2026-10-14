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
-- THE SHOP INSIDE THE LODGE IS TASK 178, and the DOOR INTO IT IS A MAN (task 181). Karen,
-- 2026-10-14: *"in lobby has to be a person bot who you need to click E to get access to shop"* --
-- so a shopkeeper stands behind task 177's counter with a `ProximityPrompt` on him, and walking up
-- to the counter no longer opens anything by itself. This module holds his numbers
-- (`CONFIG.LODGE.KEEPER`) and two readers: `Lobby.counterPosition`, which is where the panel closes
-- and where the server measures a purchase, and `Lobby.shopPrompt`, which is how the client finds
-- the one thing that opens it.
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
-- The two children `Build` still looks for inside it. A missing one is not an error: the piece is
-- simply not built, and `stats.fallbacks` counts it.
--
-- THE LODGE AND THE TWO TROPHY HEADS CAME OFF THIS LIST IN TASK 187. Karen, on the free cabins:
-- *"all of then garbadge ... you build then one proper europen standart"*. The house and everything
-- on its walls is ours now (`Build.lodge`), so the only free models left are the TRUCK and the
-- TREES -- both of which Karen has looked at and kept. The removed rows and their asset ids are in
-- `backups/2026-10-14_task-187_free-lodge.txt` (rule 7).
Lobby.TEMPLATE = {
	TRUCK = "Truck",
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

-- HOW A PAD'S STATE REACHES EVERY CLIENT (task 182), with no new outbound wire at all. Two
-- attributes on the PAD'S OWN PART, because a pad's state is PUBLIC and not per-player -- which is
-- the `ReplicatedStorage.Flags.State` shape and the exact fallback `docs/design/lobby.md` section 18
-- item 5 already named for a direction it could not prove.
--
-- EXACTLY TWO, AND BOTH ARE READ. `DHPadSize` and `DHPadCount` were considered and refused: the fill
-- is already on the billboard the server draws over the pad, so an attribute carrying it would be
-- *"an argument nobody reads is an argument nobody checked"* (`Shop.checkRequest`'s own words). The
-- countdown a player needs is the one he already gets, `DHLobbyLeaveAt` above.
--
-- `DHPadFirst` IS THE DIALOG'S WHOLE VISIBILITY RULE, and it is a SERVER-MEASURED fact mirrored
-- outward: the client holds no opinion about who is standing where or who may pick.
Lobby.PAD_STATE_ATTRIBUTE = "DHPadState"
Lobby.PAD_FIRST_ATTRIBUTE = "DHPadFirst"

-- THE FIVE WORDS A PAD'S STATE CAN BE, and they are HERE rather than in `Lobby.Pads` because they
-- cross the wire: the server writes one into `DHPadState` and `Lobby.padAsking` -- which both sides
-- call -- compares against it. `Pads.EMPTY` and friends are aliases of these rows, so there is one
-- spelling of "sizing" in the repository and a typo cannot make a dialog that never opens.
Lobby.PAD_STATE = {
	EMPTY = "empty",
	SIZING = "sizing",
	FILLING = "filling",
	COUNTDOWN = "countdown",
	LEAVING = "leaving",
}

-- THE PADS' REMOTE (task 182), AND IT IS THE FIRST INBOUND DOOR THIS SYSTEM HAS EVER HAD. Task 177's
-- lobby had none at all, and said so in capitals: standing somewhere is not a message. A dialog is.
Lobby.REMOTES_NAME = "Remotes"
Lobby.PAD_REQUEST_REMOTE = "PadRequest"

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
	-- ---------------- the lodge: OURS, from parts, a Central-European hunting house (task 187)
	--
	-- KAREN, 2026-10-14 ~21:30, on the free Creator Store cabins she was shown: *"all of then
	-- garbadge"*, and then the decision this table is: *"you build then one proper europen
	-- standart"* -- *"I need hunting house where will be fireplace table on walls animal antlers ect
	-- like hunting cabin"*.
	--
	-- EVERY DIMENSION OF THE BUILDING IS HERE AND `Build` INVENTS NONE OF THEM (design section 9),
	-- which is what makes the room's rectangle, the doorway's gap and the roof's pitch things a spec
	-- can assert.
	--
	-- Note: docs/research/2026-10-14-european-hunting-lodge.md
	LODGE = {
		-- 36 x 26 OUTSIDE, SEVEN COURSES OF LOG. The room inside is 32.4 x 22.4 and 12.6 studs to the
		-- boards -- a character is about 5 -- against the 14 x 10 the task asked for as a minimum.
		-- It is SMALLER than task 177's 40 x 28 on purpose: every clearance the pads, the fences and
		-- the yard are held to was computed against that footprint, so shrinking it can only widen
		-- them.
		--
		-- THE HEIGHT IS WHAT A TROPHY WALL COSTS, and it was arithmetic rather than taste: a red
		-- stag's mount is 3.2 studs of shield and four of antler, it hangs OVER a mantel that is
		-- itself five studs up, and in an eleven-stud room the two could not both be true -- the
		-- clamp pushed the stag down into the firebox. A hall is tall.
		SIZE = Vector3.new(36, 13, 26),
		-- THE LODGE SITS TOWARD THE NORTH EDGE OF THE FIELD, facing south, so a player walking out of
		-- the porch has the trucks in front of him and the forest behind the roof.
		OFFSET = Vector3.new(0, 0, 46),
		-- THE STONE PLINTH. Rubble stone under the logs is the first thing a Central-European lodge
		-- has and the reason its sills do not rot; here it is also what hides the voxel edge of the
		-- terrain, which task 186 measured at up to a stud below the nominal shelf.
		PLINTH = {
			HEIGHT = 2.2,
			OVERHANG = 1.0,
			MATERIAL = Enum.Material.Cobblestone,
			COLOR = Color3.fromRGB(124, 120, 112),
			CAP_COLOR = Color3.fromRGB(96, 94, 90),
		},
		FLOOR_THICK = 0.6,
		-- THE LOGS. 1.8 studs is about 50 cm, which is a big but buildable hand-hewn log, and
		-- `LOG_END_STUDS` is the PROJECTION past the corner ("around 15 to 20 cm from the end of the
		-- block" -- Glentleiten, via Google Arts & Culture; 0.9 studs is 25 cm at Roblox's 0.28 m).
		LOG_DIAMETER = 1.8,
		LOG_END_STUDS = 0.9,
		-- WALK-THROUGH: a gap in the front wall, never a door part (Karen, task 177). The leaf stands
		-- OPEN against the wall beside it, turned out by `LEAF_OPEN_RADIANS` (100 degrees).
		DOOR = { WIDTH = 7, HEIGHT = 9, LEAF_OPEN_RADIANS = 1.75 },
		-- THE ROOF. 28 studs to the ridge is 12.6 of rise over a 13-stud half-depth: a 44-degree
		-- pitch, which is the steep Alpine gable rather than an American cabin's shallow one. The
		-- eaves reach 3.4 studs past the wall and the gables 2.2, because the DEEP OVERHANG is most
		-- of what makes the silhouette read as European.
		RIDGE_STUDS = 28,
		ROOF = {
			THICK = 0.8,
			EAVE_STUDS = 3.4,
			GABLE_STUDS = 2.2,
			RAFTERS = 7,
			MATERIAL = Enum.Material.Slate,
			COLOR = Color3.fromRGB(58, 54, 52),
			RIDGE_COLOR = Color3.fromRGB(44, 41, 40),
			GABLE_COLOR = Color3.fromRGB(82, 58, 40),
		},
		-- THE CHIMNEY, up the OUTSIDE of the west gable: no hole in the roof, and the fireplace
		-- inside stands against the same wall at the same `ALONG_STUDS`.
		CHIMNEY = {
			WIDTH = 4.4,
			DEPTH = 6.5,
			INSET_STUDS = 1.4, -- how far it bites into the wall, so it is not a slab stuck on
			ALONG_STUDS = 4,
			ABOVE_RIDGE_STUDS = 3,
			MATERIAL = Enum.Material.Cobblestone,
			COLOR = Color3.fromRGB(118, 113, 106),
			CAP_COLOR = Color3.fromRGB(78, 76, 74),
		},
		-- THE WINDOWS, AS HOLES IN THE WALL. Each row names a wall and how far along it; the wall
		-- builder cuts the logs and the window builder dresses the hole, both from this list, so one
		-- can never happen without the other. The WEST wall has none: the fireplace and the chimney
		-- are there.
		WINDOW = {
			WIDTH = 5,
			HEIGHT = 4.4,
			SILL_STUDS = 3.4, -- above the floorboards: chest height, which is where a small window goes
			FRAME = 0.5,
			-- OPEN BY HALF A RIGHT ANGLE: at 0.38 rad they lay nearly flat on the logs and read as
			-- green smudges rather than as shutters.
			SHUTTER_OPEN_RADIANS = 0.85,
			GLASS_COLOR = Color3.fromRGB(150, 176, 186),
			GLASS_TRANSPARENCY = 0.55,
			FRAME_COLOR = Color3.fromRGB(74, 52, 36),
			SILL_COLOR = Color3.fromRGB(96, 72, 48),
			SHUTTER_COLOR = Color3.fromRGB(58, 74, 54),
			CUTOUT_COLOR = Color3.fromRGB(32, 42, 30),
		},
		-- WHICH WALL CARRIES WHAT, decided once and here, because the four walls cannot all carry
		-- everything: the SOUTH front has the door and two windows either side of it, the NORTH has
		-- the shop counter in its east half and one window in its west, the EAST gable is the trophy
		-- wall with a single window in the middle of it, and the WEST gable has the fireplace, the
		-- chimney and the gun rack and therefore no window at all.
		WINDOWS = {
			{ wall = "south", along = -11 },
			{ wall = "south", along = 11 },
			{ wall = "north", along = -13 },
			{ wall = "east", along = 0 },
		},
		-- THE PORCH. Karen's word, and it is where she arrives.
		PORCH = {
			DEPTH = 8,
			INSET_STUDS = 3, -- narrower than the house, so the gable reads above it
			OVERHANG_STUDS = 2.4,
			-- HOW TALL THE POSTS ARE, from the deck, and it has to be LESS than the main eave they
			-- hang from or the lean-to runs uphill -- which is what the first photograph showed at
			-- 8.5, with the main roof's outer edge 8.9 studs over the boards.
			POST_STUDS = 6.5,
			STEPS = 3,
			STEP_DEPTH = 1.6,
			WOOD_ROWS = 4,
			WOOD_PER_ROW = 5,
		},
		-- THE COLOURS AND THE TIMBER. One palette, read by every piece.
		MATERIAL = Enum.Material.Wood,
		-- DARKER THAN THE FIRST BUILD, which photographed almost pink: Roblox's `Wood` is a bright
		-- material and two lanterns on the front wall lift it further. A Central-European lodge is
		-- oiled, weathered brown.
		LOG_COLOR = Color3.fromRGB(99, 71, 47),
		TIMBER_COLOR = Color3.fromRGB(78, 55, 37),
		FLOOR_COLOR = Color3.fromRGB(112, 86, 60),
		DECK_COLOR = Color3.fromRGB(98, 75, 53),
		CEILING_COLOR = Color3.fromRGB(88, 65, 45),
		FURNITURE_COLOR = Color3.fromRGB(106, 78, 52),
		DOOR_COLOR = Color3.fromRGB(70, 48, 32),
		FIREWOOD_COLOR = Color3.fromRGB(148, 120, 92),
		-- THE FIREPLACE, against the west wall, at the chimney's own `ALONG_STUDS`.
		FIREPLACE = {
			ALONG_STUDS = 4,
			WIDTH = 11,
			DEPTH = 3.2, -- how far the breast stands proud of the wall
			OPENING_WIDTH = 5.4,
			OPENING_HEIGHT = 4.2,
			HEARTH_STUDS = 2.6, -- how far the hearth stone reaches out onto the floorboards
			STONE_COLOR = Color3.fromRGB(122, 118, 110),
			HEARTH_COLOR = Color3.fromRGB(86, 84, 80),
		},
		-- THE FIRE ITSELF: a `Fire`, a `ParticleEmitter` of embers and ONE `PointLight`. Karen asked
		-- for *"a fireplace"*, which is a fire and a light and not a system -- nothing here is
		-- written per frame.
		FIRE = {
			SIZE = 4.5,
			HEAT = 9,
			EMBER_RATE = 9,
			COLOR = Color3.fromRGB(255, 160, 60),
			SECONDARY_COLOR = Color3.fromRGB(216, 72, 24),
		},
		FIRE_LIGHT = { brightness = 2.4, rangeStuds = 42, color = Color3.fromRGB(255, 176, 104) },
		-- THE LANTERNS: three inside hung off the beams, two outside beside the door.
		-- DIM, AND WARM. At brightness 1.1 over 20 studs the two on the porch washed the whole front
		-- wall white in the first photograph; a lantern is a thing you see, not a floodlight.
		LANTERN = {
			ALONG = { -8, 2, 12 },
			ACROSS = -2,
			DROP_STUDS = 3.2,
			brightness = 0.75,
			rangeStuds = 15,
			color = Color3.fromRGB(255, 186, 116),
			GLASS_COLOR = Color3.fromRGB(240, 186, 118),
		},
		CEILING_BEAMS = 6,
		-- THE TABLE AND ITS BENCHES, in the middle of the room. `OFFSET` is x and z from the room's
		-- own centre.
		-- WEST OF THE MIDDLE, AND THAT IS A MEASURED CLEARANCE AND NOT AN ARRANGEMENT: the walk from
		-- the doorway to the counter runs diagonally across the room, and a bench centred on the room
		-- stood in it (the spec caught it, with the bench named).
		TABLE = {
			OFFSET = Vector2.new(-4.5, -2),
			SIZE = Vector2.new(10, 4),
			HEIGHT = 3,
			BENCH_HEIGHT = 1.8,
			BENCH_STUDS = 3.4,
		},
		-- THE GUN RACK on the WEST wall, south of the fireplace -- the one stretch of wall with no
		-- window, no chimney and no counter on it. Scenery: it holds nothing, and `Weapon.Hardware`
		-- stays the only thing in this game that builds a gun.
		RACK = { ALONG_STUDS = -7, WIDTH = 6, HEIGHT_STUDS = 5.4 },
		-- THE SHOP'S COUNTER, and `Shop.CONFIG.REACH_STUDS` (14) is measured against its 12-stud
		-- width: a man at either end of it can reach the till. `COUNTER_ALONG` is how far east of the
		-- room's centre it stands and `COUNTER_BACK` how far in from the north wall, which leaves the
		-- keeper room to stand behind it.
		COUNTER = Vector3.new(12, 3.2, 1.8),
		COUNTER_ALONG = 7,
		COUNTER_BACK = 4.6,
		-- TASK 178 REPLACED THE PLACEHOLDER, which said "SHOP - coming soon" and is archived with its
		-- reason in `backups/2026-10-14_task-178_lodge-sign.txt` (rule 7).
		SIGN_TEXT = "SHOP",
		-- THE MAN BEHIND THE COUNTER (task 181), and every number here is in
		-- `docs/research/2026-10-14-the-shopkeeper.md` section 4 with where it came from.
		KEEPER = {
			-- WHERE HE STANDS, from the counter's own centre: 1.6 studs further from the room (toward
			-- the back wall) so he is BEHIND the till and not standing in it. The counter is 1.8
			-- studs deep, so 1.6 clears its face by 0.7 -- and the north wall is three studs beyond.
			BEHIND_STUDS = 1.6,
			-- HOW HIGH HIS FEET GO ABOVE THE FLOOR, the figure `Rig.place` pivots to: an R15 rig's
			-- origin is its root, about 3 studs over the ground it stands on.
			ROOT_HEIGHT = 3,
			-- HUNTER GREEN FROM `Match.Body` AND A HAT OF HIS OWN. `Body.dress` takes the team for
			-- the green and task 178's `Look` for the hat; `Body.tintFor` recolours the hat ONLY, so
			-- a lodge keeper's brown felt is exactly one field and the apron is not modelled.
			--
			-- `"Shooters"` AND NOT `"Hunter"`, AND IT IS THE OUTFIT OWNER'S VOCABULARY AND NOT A
			-- SYNONYM (task 181 review round 1, finding 1). `Match.Body.OUTFITS` is keyed `Shooters`
			-- / `Drivers` and `Body.outfitFor` is a bare table lookup, so `"Hunter"` matched no row,
			-- `Body.dress` returned early at *"nothing to wear"*, and the man at the counter stood
			-- there in the default grey of an empty `HumanoidDescription`.
			TEAM = "Shooters",
			HAT_COLOR = Color3.fromRGB(96, 66, 42),
			-- HIS FACE. The outfit owner paints the five limb stems and never the head, which is
			-- right for a player -- and left this man with the solid black head and no features that
			-- an empty `HumanoidDescription` ships, which is what Karen saw and called broken.
			-- `rbxasset://` is an engine asset shipped with Studio: nothing is uploaded and nothing
			-- is fetched.
			SKIN_COLOR = Color3.fromRGB(205, 162, 125),
			FACE_TEXTURE = "rbxasset://textures/face.png",
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
			-- counter is queryable, so a line-of-sight ray aimed at a root 3 studs up is stopped by
			-- the till itself and the prompt never appears for the one person standing where he is
			-- meant to stand. 2.2 puts it at head height.
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
	},
	-- ---------------- the trophies on the wall (task 187: ours, from parts)
	--
	-- KAREN, 2026-10-14: *"on walls animal antlers ect like hunting cabin"*, and in task 180:
	-- *"trophys like head of deer head of boar"*. The free Creator Store heads are gone with the free
	-- cabin -- one of them was a 5.4-stud tan deer head that read as a toy next to anything else in
	-- the room -- and what hangs here now is the thing a German or Austrian lodge actually has: ROWS
	-- of small dark `Trophaeenschilde`, each with a roe buck's antlers on it, one red stag over the
	-- fireplace, and a boar's tusk plate.
	--
	-- A MOUNT NAMES A WALL, HOW FAR ALONG IT AND HOW HIGH -- never an absolute offset -- so the rows
	-- follow the room if the room ever changes. `standoff` is how far the hanging face is from the
	-- wall, which is what puts the stag on the CHIMNEY BREAST (3.2 studs proud) instead of inside it.
	--
	-- MEASURED PROPORTION, not a guess: a real roe shield is 22 cm by 10 cm carrying 10.5 cm of
	-- antler, so the plaque is 2.2 times as tall as it is wide and the antlers rise about half the
	-- plaque's height again.
	TROPHIES = {
		HEIGHT_STUDS = 4.8, -- above the floorboards: above a standing player's head
		-- THE SHIELD IS LIGHTER THAN THE WALL BEHIND IT and the antlers are not white: at RGB
		-- 228,219,198 on a 72,50,34 plaque the first photograph showed white twigs floating on a dark
		-- wall. Weathered antler is a warm grey-bone, and a `Trophaeenschild` is polished linden.
		PLAQUE_COLOR = Color3.fromRGB(104, 72, 44),
		BONE_COLOR = Color3.fromRGB(186, 173, 146),
		ROE = {
			PLAQUE = Vector3.new(1.8, 2.4, 0.35),
			SEGMENTS = 3,
			SEGMENT_STUDS = 0.9,
			TINE_STUDS = 0.7,
			TINES = 2,
			THICK = 0.34,
			SPREAD = 0.45,
			CURVE = -0.16,
		},
		-- THE ONE OVER THE DOOR IS BIGGER THAN THE ONE OVER THE FIRE, and that is deliberate: it
		-- hangs on the gable, eight studs above a man's head and read from the road, where the indoor
		-- stag is read from four studs away across a table.
		GABLE = {
			PLAQUE = Vector3.new(4.2, 4.6, 0.6),
			SEGMENTS = 4,
			SEGMENT_STUDS = 1.6,
			TINE_STUDS = 1.3,
			TINES = 3,
			THICK = 0.6,
			SPREAD = 0.5,
			CURVE = -0.16,
		},
		STAG = {
			PLAQUE = Vector3.new(2.8, 3.2, 0.5),
			SEGMENTS = 3,
			SEGMENT_STUDS = 1.15,
			TINE_STUDS = 0.9,
			TINES = 3,
			THICK = 0.42,
			SPREAD = 0.5,
			CURVE = -0.18,
		},
		BOAR = {
			PLAQUE = Vector3.new(2.2, 2.6, 0.4),
			TUSK_STUDS = 1.15,
			THICK = 0.32,
			SEGMENTS = 2,
			SEGMENT_STUDS = 1.15,
		},
		-- THE ROWS. The east wall carries the classic grid, the north wall's west half the rest, and
		-- the two beside the door are what a player sees first from inside. Nothing hangs on the
		-- south wall's windows, the counter's half of the north wall, or the west wall except the
		-- stag over the fire -- those are spoken for.
		MOUNTS = {
			-- THE EAST GABLE: three each side of its one window, and two more above them.
			{ kind = "roe", wall = "east", along = -9.4 },
			{ kind = "roe", wall = "east", along = -6.6 },
			{ kind = "roe", wall = "east", along = 6.6 },
			{ kind = "roe", wall = "east", along = 9.4 },
			{ kind = "roe", wall = "east", along = -8, height = 8.2 },
			{ kind = "roe", wall = "east", along = 8, height = 8.2 },
			-- THE NORTH WALL'S WEST HALF, clear of the counter and of its window.
			{ kind = "roe", wall = "north", along = -8 },
			{ kind = "boar", wall = "north", along = -4, height = 5 },
			{ kind = "roe", wall = "north", along = 0 },
			-- EITHER SIDE OF THE DOOR, between it and the front windows: the two a player sees
			-- first when he turns round inside.
			{ kind = "roe", wall = "south", along = -6 },
			{ kind = "roe", wall = "south", along = 6 },
			-- AND THE RED STAG OVER THE FIRE, on the chimney breast rather than inside it.
			{ kind = "stag", wall = "west", along = 4, height = 8.2, standoff = 3.2 },
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
		-- ---------------- THE TYRES ON THE GROUND (task 186)
		--
		-- KAREN, 2026-10-14 ~17:00: *"car tyers are inside earth"*.
		--
		-- MEASURED IN THE LIVE FOREST TEST THE SAME DAY, before a line of this was written: every
		-- tyre of all four trucks sat **0.752 studs UNDER the terrain**, and the east bay's worst
		-- wheel was **2.017** under. `Build.trucks` stood each truck on `anchor.Y` -- the NOMINAL
		-- shelf -- and `Field.fill`'s terrain surface is not that number: Roblox terrain is
		-- voxelised, so the surface the engine produces is rounded to its own grid (150.000 against
		-- a shelf at 149.248), and at the shelf's eastern edge the old hill leaves up to 1.27 studs
		-- of it standing. It is task 182's pad defect exactly, against the same surface: *"THEY ARE
		-- LAID ON THE GROUND THAT IS MEASURED, NOT ON THE SHELF THE ARITHMETIC PREDICTS"*.
		--
		-- A CONSTANT LIFT CANNOT FIX IT, which is why there is no "+0.75" row here: the rounding is
		-- a property of where the fill landed, and the 1.27-stud spread ACROSS one truck's own four
		-- wheels is a property of the hill. So the truck is settled on what a ray answers under each
		-- WHEEL, and where those four answers are not level it is tilted onto the plane through
		-- them -- a parked truck on uneven ground, which is what the yard is.
		SETTLE = {
			-- HOW FAR THE TILT MAY GO. The measured worst case is ~4 degrees across bay 4; six is
			-- room over it, and it is a CLAMP and not a target: a truck lying over at 30 degrees is
			-- a bad raycast, never a slope, and the clamp is what stops one answering ray from
			-- turning a lobby into a crash site.
			MAX_TILT_DEGREES = 6,
			-- ...AND HOW SMALL A TILT IS NOT WORTH APPLYING. Under this the four answers are level
			-- enough that a tilt is noise, and a truck that is level should BE level.
			MIN_TILT_DEGREES = 0.25,
		},
		-- ---------------- CAMOUFLAGE, MILITARY STYLE (task 186)
		--
		-- KAREN, 2026-10-14 ~21:15: *"make cars comoflash like military like hunting cars"*, after
		-- *"trucks has to be comoflash"*.
		--
		-- IT IS A REPAINT OF THE FREE MODEL AND NOT A SECOND MODEL (option A, the Director's
		-- preferred): the body panels of "PickUp Truck (Prop)" are eight MeshParts named `Color`,
		-- plain `SmoothPlastic` at RGB 163,162,165 with **no `TextureID` and no `SurfaceAppearance`**
		-- -- measured, 2026-10-14, in the live place -- so a `Color3` on them is the paint itself and
		-- not a tint over somebody's photograph. The windows (`Glass`) and every lamp (`Neon`) are
		-- left exactly as they shipped.
		--
		-- THERE IS NO CAMO **TEXTURE**, AND THAT IS A DECISION RATHER THAN AN OVERSIGHT. A library
		-- image would have to be PROVED to load before it could be trusted, and the only way to ask
		-- a running Studio that is an asset call -- which `tools/studio_mcp.py` forbids in capitals:
		-- a single `LoadAsset` through `execute_luau` poisoned the thread for a whole night's gate
		-- on 2026-10-02. An id that silently fails leaves four UNTEXTURED trucks and nobody told.
		-- Blotches therefore wait for an uploaded texture and Karen's OK (she OKs every upload).
		--
		-- FOUR PALETTES, ONE FAMILY. Every truck is olive drab first, so the row reads as one fleet
		-- and the four PADS keep their own colours as the thing that tells the bays apart; the
		-- second and third tone shift bay by bay, which is the Director's *"optionally slightly
		-- different camo tones"*.
		CAMO = {
			-- MATTE, AND IT IS `SmoothPlastic` BECAUSE THE OTHER ONE WAS PHOTOGRAPHED (rule 5).
			-- `Fabric` is what the rest of this model is built out of and it was the first choice
			-- here; the shot came back with four BLACK trucks, and a side-by-side -- the same three
			-- tones on two trucks, one material each, one picture -- showed `Fabric`'s own weave is
			-- dark enough to swallow an olive at this scale. `SmoothPlastic` has no reflectance to
			-- take a sheen off the sun, which is the half of "military" that is not colour.
			BODY_MATERIAL = Enum.Material.SmoothPlastic,
			-- ONE PALETTE PER BAY, WRAPPED like `PADS.COLOURS`, so a fifth bay cannot index past the
			-- end. Tone 1 is the shell, and the panels after it alternate through the rest -- which
			-- is what makes a repaint read as a camouflage scheme rather than as one flat colour.
			--
			-- THE VALUES ARE THE ONES THAT WERE LOOKED AT, and that is why they are not the darker
			-- olives this row started with: those measured as a correct olive drab and PHOTOGRAPHED
			-- as black, under the yard's own tree shade and this place's lighting. Four trucks, four
			-- brightnesses, one picture, 2026-10-14 -- and these are the two in the middle of it plus
			-- a lighter and a browner neighbour.
			TONES = {
				{ Color3.fromRGB(118, 124, 84), Color3.fromRGB(88, 94, 64), Color3.fromRGB(150, 142, 102) },
				{ Color3.fromRGB(96, 104, 70), Color3.fromRGB(72, 78, 54), Color3.fromRGB(124, 118, 84) },
				{ Color3.fromRGB(136, 142, 100), Color3.fromRGB(102, 106, 74), Color3.fromRGB(168, 158, 116) },
				{ Color3.fromRGB(120, 110, 80), Color3.fromRGB(90, 80, 58), Color3.fromRGB(148, 134, 100) },
			},
			-- THE WHEELS. The tyres ship near-black already; the RIMS ship at the body's own
			-- 163,162,165, and bright rims under a camouflaged truck are the one thing in the shot
			-- that would still say "road car".
			TYRE = Color3.fromRGB(24, 24, 24),
			RIM = Color3.fromRGB(54, 56, 48),
		},
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
	-- ---------------- THE FOUR TRUCK PADS (task 182)
	--
	-- KAREN, 2026-10-14 ~09:30: *"and when start hunt we need to go next to truck has to be mark
	-- where and has to be coloroude circle like in all games or rectangle where people stand and can
	-- be 1/1 or 4/4 you can select on dialiog how many like in roblox games and can be several truck
	-- like 4 of them nicly aligned next ot each other and you come to truck back rectangle and can
	-- click and select how many players"*.
	--
	-- ONE PAD PER TRUCK BAY, AND THE COUNT IS NOT A ROW HERE: it is `TRUCK.COUNT`, so four trucks and
	-- three pads cannot happen. `TRUCK.PAD_BEHIND_STUDS` -- written down by task 180 for this task --
	-- is how far back from the BAY CENTRE the pad's near edge sits, and `Pads.centreFor` is the one
	-- place that arithmetic is written.
	--
	-- IT REPLACES TASK 177'S `SPOT`, the single orange circle beside truck 1, archived with its
	-- reason and its two pure functions in `backups/2026-10-14_task-182_the-marked-circle.txt`
	-- (rule 7).
	--
	-- Design: docs/design/truck-pads.md (sections 4, 4.1, 5)
	-- Note:   docs/research/2026-10-14-truck-pads.md
	PADS = {
		-- 9 WIDE, 12 DEEP, AND EVERY NUMBER HERE IS A CLEARANCE RATHER THAN A TASTE (design section
		-- 4.1). The brief's first value was ~14 x 10 and 14 DOES NOT FIT: pad 1's west face has to
		-- clear the parts lodge's east wall, whose outer face is x +21 (`logWall "WallE"` with
		-- `LOG_DIAMETER` 2), which bounds the half-width at 5; and the far edge has to stay south of
		-- `Build.treeLine`'s own yard exclusion (z < +44) or a tree can stand on a pad. 108 square
		-- studs holds eight bodies two across and four deep, and `BAY_GAP_STUDS` 17 leaves 8 studs
		-- between pads, so four parties read as four places and not as one stripe.
		--
		-- `SIZE.Y` IS 0.7 AND THE SLAB IS *SUNK*, WHICH CLOSES TASK 177'S ROUND-1 FINDING IN ADVANCE.
		-- The ring was lifted 0.08 off the SHELF and therefore sat 0.42 studs inside the opaque road
		-- slab -- *"the lobby had a sign reading 'STAND HERE TO HUNT' with nothing to stand in"*. A
		-- pad straddles three surfaces (the `Yard` slab, the road `Lane` and its verge, and bare
		-- blade-free terrain north of z +40), so its TOP is `shelfY + ROAD.THICK_STUDS + LIFT_STUDS`
		-- = +0.58, above every slab, and its BOTTOM is `shelfY - 0.12`, below the terrain top. One
		-- number, both failures closed: nothing floats and nothing can hide inside a slab.
		SIZE = Vector3.new(9, 0.7, 12),
		LIFT_STUDS = 0.08, -- `SPOT.RING.LIFT_STUDS`'s number, kept: it is what stops z-fighting
		RIM_STUDS = 0.5, -- the glowing border's width: `SPOT.RING.THICKNESS_STUDS`'s number
		RIM_HEIGHT_STUDS = 0.12, -- `SPOT.RING.HEIGHT_STUDS`'s number
		TRANSPARENCY = 0.45, -- `SPOT.RING.TRANSPARENCY`'s number: the deck is a stain, not a wall
		-- FOUR HUES, AND THE RING'S HUNTING ORANGE STAYS IN THE PALETTE so the lobby's colours do not
		-- change under Karen. A colour-blind player still tells the pads apart by POSITION -- they
		-- are in a row -- and by NUMBER, because each billboard says which truck it belongs to. So
		-- the colour is what makes them pretty and never what carries the meaning, which is the only
		-- honest way to use four hues at once.
		COLOURS = {
			Color3.fromRGB(86, 170, 88), -- 1 green
			Color3.fromRGB(72, 124, 208), -- 2 blue
			Color3.fromRGB(235, 150, 60), -- 3 orange (`SPOT.RING.COLOR`'s own value)
			Color3.fromRGB(150, 96, 200), -- 4 violet
		},
		-- PAD 1'S PART IS STILL CALLED `TruckSpot`, AND IT IS A DATA ROW RATHER THAN A BRANCH IN
		-- `Build`. `Lobby.SPOT_NAME`, `Lobby.spotPart`, `Lobby.spotPosition`, the Hud's
		-- `kind = "truck"` chevron and -- outside this repository -- the Director's `smoke.sh` all
		-- find a part by that name, and none of them has to change. The asymmetry at index 1 is
		-- deliberate continuity (note section 6), not an oversight.
		PART_NAMES = { "TruckSpot", "TruckPad2", "TruckPad3", "TruckPad4" },
		-- THE FOUR PARTY SIZES, AS DATA, WITH THE WORDS BESIDE THEM.
		--
		-- 8 IS THE DRIVE'S WHOLE ROSTER (`Match.CONFIG.BOTS.TARGET`: 4 hunters + 4 beaters) and 1 is
		-- today's game exactly -- one man and seven bots, because bots fill every slot no player
		-- takes (task 161). So *"full hunt"* on the button is a checked claim and not a boast:
		-- `lobby.spec` asserts the biggest size against `Match`'s own table rather than a copy.
		--
		-- ORDER MATTERS. Row 1 is the size a pick that nobody makes falls back to (`Pads.defaultSize`),
		-- and the rows are drawn down the dialog in this order.
		--
		-- KAREN WROTE THE FORMAT HERSELF -- *"can be 1/1 or 4/4"* -- so the size is both halves of
		-- the label, and the two ends of the range are named in words so four numbers read as a
		-- choice rather than as a quiz.
		SIZES = {
			{ size = 1, label = "1 / 1  alone" },
			{ size = 2, label = "2 / 2" },
			{ size = 4, label = "4 / 4" },
			{ size = 8, label = "8 / 8  full hunt" },
		},
		-- HOW LONG THE DIALOG WAITS FOR AN ANSWER before it falls back to row 1. Long enough to read
		-- four buttons and press one -- and it is LOAD-BEARING FOR THE EVIDENCE: 8 +
		-- `COUNTDOWN_SECONDS` 5, plus two scans of slack, is 13.2 s from stepping on to leaving, which
		-- is what has to fit inside the Director's own unattended smoke window (note section 7). A
		-- snippet run over StudioMCP gets a sandboxed copy of the server's modules with empty state
		-- (measured, task 122), so it can neither pick a size nor press a button.
		PICK_TIMEOUT_SECONDS = 8,
		-- HOW LONG A PART-FULL PARTY WAITS FOR THE REST OF IT before it goes anyway (the Director:
		-- *"a countdown when full or after N seconds"*). A FIRST VALUE: the longest a solo player
		-- should ever stand on a pad waiting for friends who are not coming. One row for Karen.
		FILL_TIMEOUT_SECONDS = 45,
		-- `COUNTDOWN_SECONDS` IS DELIBERATELY NOT HERE. `CONFIG.COUNTDOWN_SECONDS` (5) is reused,
		-- because a second countdown length would be a second answer to "how long until I go".
		-- HOW OFTEN ONE PLAYER MAY ASK. `Shop.CONFIG.REQUEST_MIN_INTERVAL`'s number: four a second,
		-- and it is a FORGERY GUARD rather than a game rule -- a person cannot press a button four
		-- times a second.
		REQUEST_MIN_INTERVAL = 0.25,
		-- THE WORDS OVER THE PAD, IN THE WORLD AND NOT ON THE SCREEN -- the community pad's own
		-- arrangement (note section 2c). The count and the state are drawn where the man walking
		-- across the yard can read them before he commits to a pad; the Hud owns the screen
		-- (`docs/design/hud-clarity.md`) and this is the one thing in this task that is deliberately
		-- not on it.
		--
		-- `COUNT_UNSET` IS `%d / -` AND NOT `%d / 0`, because nobody having picked yet is not a party
		-- of nought.
		--
		-- `MAX_DISTANCE_STUDS` 160 IS MEASURED AGAINST THE LOBBY: the porch is 46 studs from the
		-- bays, so a pad is readable from the lodge door, and the field is 220 across, so the boards
		-- are gone from the far corners rather than hanging over the whole world.
		BILLBOARD = {
			TRUCK = "TRUCK %d",
			COUNT = "%d / %d",
			COUNT_UNSET = "%d / -",
			OFFSET_STUDS = 6,
			SIZE_PX = Vector2.new(180, 64),
			TRUCK_PX = 22,
			COUNT_PX = 30,
			MAX_DISTANCE_STUDS = 160,
		},
		-- THE DIALOG'S PIXELS AND ITS TITLE, here rather than in the panel for `Shop.CONFIG.PANEL`'s
		-- stated reason: both sides read them -- `Hud.build` sizes the frame and `Hud.PadPanel` fills
		-- it.
		--
		-- 300 WIDE FITS THE 400 px PHONE `hud_clarity.spec` MEASURES, which is the constraint the
		-- shop panel's own 360 was chosen against (`docs/design/shop.md` 13.1).
		PANEL = {
			TITLE = "HOW MANY PLAYERS?", -- Karen's own word: *"select how many players"*
			WIDTH = 300,
			HEADER_PX = 44,
			ROW_PX = 48,
			GAP = 8,
			-- `Rail.CONFIG.BUTTON_PX`'s number, over the 44 px Roblox's own tutorial sets as a touch
			-- minimum: this is the one dialog in the game a player meets before he has learned
			-- anything.
			BUTTON_PX = 48,
			-- `Report.CONFIG.PANEL_Z_INDEX`'s band. `Rail.CONFIG.Z_INDEX` is 16 and stays pressable
			-- over this dialog -- the `Shop.CONFIG.PANEL` arrangement.
			Z_INDEX = 15,
		},
	},
	-- WHERE HE ARRIVES: in front of the porch, looking +Z (north) at the lodge with the forest
	-- behind it, the truck and the ring to his right. Karen's *"house is in fields next to forrest"*
	-- read as a camera angle.
	SPAWN = {
		OFFSET = Vector3.new(0, 0, 16),
		SIZE = Vector3.new(12, 1, 6),
		-- 4.5 STUDS APART, AND THE BOUND IS THE PORCH (task 187). Seven slots is a worst case of
		-- `3 * SPREAD_STUDS` off the middle, which has to stay inside the porch's own half-width --
		-- 15 studs, the 36-stud lodge less the porch's 3-stud inset either side. At 6 it was 18,
		-- exactly the lodge's new half-width, and a man spawned on the corner of his own deck.
		SPREAD_STUDS = 4.5,
		-- HOW MANY PLACES THERE ARE ON THE PORCH, AND IT IS A BOUND AND NOT A PREFERENCE (review
		-- round 1, finding 3). `Lobby.spawnCFrame` lays its slots centre-out -- 0, +1, -1, +2, -2 --
		-- so slot n is `floor((n + 1) / 2) * SPREAD_STUDS` studs off the middle. SEVEN slots is a
		-- worst case of 3 * 4.5 = 13.5 studs, inside the porch's own 30-stud front (half-width 15)
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
	-- THE BUDGET IS 1500 SINCE TASK 187, and the arithmetic is written down so the number is a bound
	-- and not a shrug: OUR lodge -- plinth, seven courses of log, the corner ends, four windows with
	-- their shutters, the door, the roof with its rafter ends, the chimney, the porch with its
	-- woodpile, the beamed ceiling, the fireplace, the furniture, the gun rack and twelve trophy
	-- mounts -- is about 500 parts, four trucks 304, thirty trees about 150, and the road, verges,
	-- fences, four pads, yard and spawn about 190: roughly 1,165, with headroom for a sixth window or
	-- another row of antlers. The Director's own ceiling for this task was 1,500.
	MAX_PARTS = 1500,
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

-- ---------------------------------------------------------------- the pads (task 182)

-- HOW MANY PADS THERE ARE, and it is NOT a row of its own: it is the number of trucks, so four
-- trucks and three pads cannot happen. `lobby.spec` holds `#PADS.PART_NAMES` to it.
function Lobby.padCount(): number
	return Lobby.CONFIG.TRUCK.COUNT
end

-- WHAT PAD n'S PART IS CALLED. One table lookup, so the name is data and never a branch, and pad 1's
-- `TruckSpot` is a row in that table rather than a special case in the builder.
function Lobby.padPartName(index: number): string?
	return Lobby.CONFIG.PADS.PART_NAMES[index]
end

-- THE ONE READER OF WHERE EACH PAD IS, beside `Lobby.spotPart` and for its stated reason: the server
-- BUILDS the part, this finds it, and nobody computes the position twice.
--
-- MEMOISED PER INDEX, AND EVERY CACHE IS DROPPED WHEN ITS PART LEAVES THE DATAMODEL -- `spotPart`'s
-- rule and `MapUi.pointsFor`'s (*"a stale dot is a lie about where somebody is"*). A rebuilt lobby
-- must answer nil rather than a position from the lobby before it.
local cachedPads: { [number]: BasePart } = {}

function Lobby.padPart(index: number): BasePart?
	local cached = cachedPads[index]
	if cached ~= nil and cached:IsDescendantOf(game) then
		return cached
	end
	cachedPads[index] = nil
	local name = Lobby.padPartName(index)
	if name == nil then
		return nil
	end
	local folder = Workspace:FindFirstChild(Lobby.FOLDER_NAME)
	if folder == nil then
		return nil
	end
	local found = folder:FindFirstChild(name :: string, true)
	if found ~= nil and found:IsA("BasePart") then
		cachedPads[index] = found :: BasePart
		return cachedPads[index]
	end
	return nil
end

-- EVERY PAD THAT EXISTS, IN PAD ORDER, as positions. The Hud's chevron points at the NEAREST of them
-- (task 182) rather than at pad 1, because pointing at pad 1 while a player stands by truck 4 would
-- be the screen lying about where to go.
--
-- A SHORT LIST, REBUILT PER CALL AND NOT CACHED: `padPart` is memoised, so this is four table reads
-- and four `Position` reads -- the same order as the one subtraction `Hud.renderObjective` already
-- spends on the shop counter.
--
-- A WORLD WITH NO LOBBY ANSWERS AN EMPTY LIST, and `Objective.targetFor` reads that as *"answer
-- exactly as task 177 did"*. Absent is not "nowhere".
function Lobby.padPositions(): { Vector3 }
	local out = {}
	for index = 1, Lobby.padCount() do
		local part = Lobby.padPart(index)
		if part ~= nil then
			table.insert(out, (part :: BasePart).Position)
		end
	end
	return out
end

-- WHAT PAD n IS DOING, read off the two attributes the server wrote on its part: the state word and
-- the userId who may pick. nil, nil for a pad that does not exist or has never been written.
--
-- THE CLIENT'S ONLY WINDOW ONTO THE PAD STATE, and it is one-way: there is no setter here and
-- nothing a client does can change either value.
function Lobby.padStateOf(index: number): (string?, number?)
	local part = Lobby.padPart(index)
	if part == nil then
		return nil, nil
	end
	local state = (part :: BasePart):GetAttribute(Lobby.PAD_STATE_ATTRIBUTE)
	local first = (part :: BasePart):GetAttribute(Lobby.PAD_FIRST_ATTRIBUTE)
	return (if type(state) == "string" then state :: string else nil),
		(if type(first) == "number" then first :: number else nil)
end

-- WHICH PAD IS ASKING THIS PLAYER TO PICK, or nil. THE DIALOG'S WHOLE VISIBILITY RULE, and it is a
-- server-measured fact: `DHPadFirst` is only ever written from a man the SERVER saw standing on that
-- rectangle, so a client cannot decide it is first.
--
-- THE STATE IS CHECKED TOO, not just the userId. A pad that has moved on to `filling` still carries
-- the first man's id -- `Pads` keeps it so "who picked" survives the pick -- and a dialog that
-- opened on the id alone would re-open after the party was already sized.
function Lobby.padAsking(userId: number?): number?
	if type(userId) ~= "number" then
		return nil
	end
	for index = 1, Lobby.padCount() do
		local state, first = Lobby.padStateOf(index)
		if state == Lobby.PAD_STATE.SIZING and first == userId then
			return index
		end
	end
	return nil
end

-- THE PADS' REMOTE, found once -- `Shop.remotes`' shape exactly, including the `WaitForChild`: this
-- is called from a boot and from a client's Hud, both of which may run before the folder has
-- replicated, and it is the ONE place either side names it.
--
-- IT IS A CHILD OF THIS MODULE'S OWN FOLDER (`ReplicatedStorage.Lobby.Remotes`), because
-- `src/shared/Lobby/Remotes.model.json` syncs there -- the same place `ReplicatedStorage.Shop.Remotes`
-- lives.
local remotes: any = nil

function Lobby.remotes(): any
	local cached = remotes
	if cached ~= nil then
		return cached
	end
	local folder = ReplicatedStorage:WaitForChild("Lobby"):WaitForChild(Lobby.REMOTES_NAME)
	local built = { PadRequest = folder:WaitForChild(Lobby.PAD_REQUEST_REMOTE) :: RemoteEvent }
	remotes = built
	return built
end

return Lobby
