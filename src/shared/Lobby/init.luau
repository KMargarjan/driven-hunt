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
-- AND SINCE TASK 191 THE LOBBY ALSO OWNS WHERE THE HUNT ENDS. Karen, 2026-10-15: *"next is when hunt
-- over everyone is in clean ground no grass firstable / second it could be next to cabin"*. The
-- end-of-drive gathering used to happen at the DRIVE's own spot out in the forest, in grass that hid
-- the animals and the players; it happens in the clean yard west of the lodge now. The rectangle is
-- the `Gather` row in `CONFIG.FIELD.PADS`, the facing is `CONFIG.GATHER`, and `Lobby.gatherSpotFor`
-- is the one reader -- handed to the drive as `world.gatherSpot`, which is the `world.placement`
-- shape exactly: the world provides, the owner decides.
--
-- Design: docs/design/lobby.md (sections 2, 9, 10.3, 10.4, 12.1)
-- Note:   docs/research/2026-10-13-lobby-and-the-truck.md
--         docs/research/2026-10-16-gathering-at-the-cabin.md (task 191: the gathering yard)
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
-- you need to click E to get access to shop"*. Both live under `Lodge.Inside.Shop`, and these are
-- the names the CLIENT finds the prompt by -- the one way into the panel since task 181 took task
-- 178's auto-open away.
--
-- SINCE TASK 195 THE PROMPT HANGS ON THE COUNTER rather than on the man, and it is still built only
-- when there IS a man: the clip that stops a player jumping the counter cannot be made invisible to
-- a ray (measured), so a prompt behind it is a shop nobody can open. `Lobby.shopPrompt` searches by
-- NAME anywhere under `Workspace.Lobby`, so nothing that reads it had to change.
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

-- WHICH PAD *THIS* PLAYER IS LOADING ONTO, as the pad's own state word, or nil (task 197). One more
-- attribute on the `Player`, beside `DHLobbyLeaveAt`, and the same one-way read-only mirror: there is
-- no inbound door, so nothing a client sends can put a banner on anybody's screen.
--
-- WHY THE SERVER HAS TO SAY IT AND THE CLIENT CANNOT WORK IT OUT. The dialog's own visibility is
-- `DHPadFirst` -- *"which pad is asking THIS player"* -- and that is only ever written during
-- `sizing`. After the pick the pad moves to `filling` and this client is one of a party of up to
-- eight with no attribute of its own and no way to know WHICH of the four rectangles it is standing
-- on: `Pads.indexAt` is the server's arithmetic over a position only the server measures (it is in
-- `ServerScriptService.Lobby`, deliberately), and a client copy of it would be a SECOND answer to
-- "who is on pad 3" -- the thing `Pads` own header says the party is derived to avoid.
--
-- IT IS A STATE WORD AND NOT A BOOLEAN, because the banner says three different things (waiting for
-- the party, the countdown, going) and a boolean would need a second attribute to tell them apart.
Lobby.PAD_MINE_ATTRIBUTE = "DHPadMine"

-- IS THIS PAD LOADING A PARTY? PURE, and it is THE ONE RULE with two readers (task 197): the banner
-- on a member's screen and the engine, lights and smoke on that pad's truck come up and go down
-- together, because they are the same fact said twice -- *"this truck is about to leave with
-- somebody in it"*.
--
-- `sizing` IS NOT IN IT, AND THAT IS THE WHOLE BOUNDARY. A man standing on a pad reading the dialog
-- has not committed to anything; the Director's brief starts both at *"the moment a size is
-- picked"*, which is exactly the `sizing -> filling` edge. `empty` is not in it for the same reason
-- and `leaving` is, because the party is still standing there until the drive takes them.
function Lobby.padLoading(state: string?): boolean
	return state == Lobby.PAD_STATE.FILLING or state == Lobby.PAD_STATE.COUNTDOWN or state == Lobby.PAD_STATE.LEAVING
end

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
			-- ---------------- THE GATHERING YARD (task 191), AND IT IS THE *ONE* PLACE THIS
			-- RECTANGLE IS WRITTEN.
			--
			-- KAREN, 2026-10-15 ~17:20: *"next is when hunt over everyone is in clean ground no grass
			-- firstable / second it could be next to cabin"*. The end-of-drive gathering -- the bag
			-- laid out in rows, everybody in a ring, four torches (tasks 159/168/173) -- happened at
			-- the DRIVE's own spot out in the forest, where the tall grass hides the animals she
			-- asked to see and the players standing round them. So it happens HERE instead: the
			-- clean, flat, blade-free yard west of the lodge.
			--
			-- FOUR READERS, ONE RECTANGLE. `Field.fill` lays the block from this row (it is a LIST,
			-- as the comment above it says, so a third pad is a row and not a code path);
			-- `Lobby.gatherSpotFor` reads its centre; `Build.treeLine` keeps a spruce off it; and
			-- `lobby.spec` holds the drive scene's own worst-case square inside it. A second copy of
			-- the rectangle would be two definitions of one fact -- `docs/PROJECT_CONTEXT.md`'s named
			-- failure -- so `Lobby.gatherPad` finds this row BY NAME and nothing recomputes it.
			--
			-- 56 x 56 IS ARITHMETIC: `Match.Scene.cornerReachFor(MAX_ANIMALS)` is 23.5 studs with the
			-- shipped numbers, so the worst-case scene -- twelve animals, the ring that contains them
			-- and the four corner torches -- is a 47-stud square. 56 leaves 4.5 studs of margin on
			-- every side, and `lobby.spec` asserts that against `Match.CONFIG` rather than against a
			-- copy of it.
			--
			-- WEST OF THE LODGE AT (-50, 10), AND THE TWO BOUNDS EITHER SIDE ARE MEASURED (note
			-- section 5):
			--   * EAST: the pad stops at x -22, four studs short of the lodge's own footprint (x -18)
			--     -- and what has to clear the BUILDING is the scene, not the dirt: the gathering
			--     square reaches x -26.5, which leaves 5.5 studs to the chimney's west face (the
			--     chimney stands 3 studs proud of the wall) and 8.5 to the wall. The porch, the
			--     spawn, the road, the fences, the four trucks and the four pads are all east of
			--     that, so NOTHING of the lobby's own layout is touched. East of x -44 this pad only
			--     repaints ground the `Yard` pad has already made blade-free anyway.
			--   * WEST: the pad stops at x -78, and `TREELINE`'s western arc was MEASURED in the
			--     live place rather than predicted -- the nearest trunk of the thirty is `Tree27` at
			--     x -86, eight studs clear of this edge and four clear of `Build.treeLine`'s
			--     exclusion. So the tree line FRAMES the gathering instead of standing in it, and
			--     not one tree is lost (27 built, the same 27 as before this task: three are skipped
			--     by the road and yard rules that already existed). A centre at -62 with a 64-stud
			--     pad -- the first arithmetic -- reached x -94 and would have taken four or five out
			--     of the arc for no gain.
			--
			-- -50 AND NOT -52, AND THAT IS A VOXEL AND NOT A PREFERENCE. `Terrain:FillBlock` writes
			-- 4-stud voxels, so an edge that does not land on the grid leaves a partly-filled voxel
			-- that KEEPS ITS GRASS. Measured at -52 in the live place, 2026-10-16: 625 raycasts over
			-- the gathering square came back 623 `Ground` and **2 `Grass`**, both of them 4 studs
			-- inside the nominal west edge (2770, which is 692.5 voxels) while the z edges -- which
			-- happened to be aligned -- lost about a stud. At -50 the edges are x 2772 and 2828 and z
			-- -2968 and -2912, all four exactly on the grid.
			--
			-- Raycast grid over the footprint in Karen's own place, 2026-10-16, BEFORE any of this
			-- was written: 121 samples, **zero non-terrain obstacles, zero misses**, 13.13 studs of
			-- ground fall -- well inside `DEPTH_STUDS` 48 and `CLEAR_STUDS` 96, so the existing
			-- cut-and-fill makes this yard flat at the shelf exactly as it does the lodge's. Measured
			-- again with the yard built: **dead flat, spread 0.00 studs at y 150.00**.
			{
				NAME = "Gather",
				OFFSET = Vector3.new(-50, 0, 10),
				SIZE = Vector3.new(56, 6, 56),
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
			-- 1.4 AND NOT 1.0 (the Designer's lodge spec, 2026-10-16, section 6): at 1.0 the stone
			-- ends UNDER the bottom log instead of catching it, and the floor slab's cut edge showed
			-- as a pale board over it.
			OVERHANG = 1.4,
			MATERIAL = Enum.Material.Cobblestone,
			COLOR = Color3.fromHex("54524C"),
			CAP_COLOR = Color3.fromHex("3E3C39"),
		},
		FLOOR_THICK = 0.6,
		-- THE LOGS. 1.8 studs is about 50 cm, which is a big but buildable hand-hewn log, and
		-- `LOG_END_STUDS` is the PROJECTION past the corner ("around 15 to 20 cm from the end of the
		-- block" -- Glentleiten, via Google Arts & Culture; 0.9 studs is 25 cm at Roblox's 0.28 m).
		LOG_DIAMETER = 1.8,
		LOG_END_STUDS = 0.9,
		-- THE LONG COURSES (spec 6). Every course projected by the same 0.9, which reads machined;
		-- alternating 0.9 / 1.35 up the corner is what a hand-cut `Blockbau` corner looks like.
		LOG_END_ALT_STUDS = 1.35,
		-- WALK-THROUGH: a gap in the front wall, never a door part (Karen, task 177) -- AND SINCE
		-- TASK 195 THERE IS NO LEAF EITHER. Karen, 2026-10-15: *"doors can be open no doors"*. The
		-- leaf task 187 hung was MEASURED standing 1.34 studs INSIDE the room and 0.2 studs off the
		-- floorboards, which is the *"it's broken there"* she reported; correcting its swing puts a
		-- 7 x 8.6 slab at 100 degrees in the middle of the porch, and laying it flat on the wall
		-- covers a front window at either jamb (the windows are at `along` +-11 and the leaf is 7
		-- wide hinged 4.05 from centre). So the jambs, the lintel and the threshold frame an open
		-- doorway and nothing swings. Archived: `backups/2026-10-16_task-195_door-leaf.txt`.
		DOOR = { WIDTH = 7, HEIGHT = 9, LINTEL_STUDS = 1.4 },
		-- HOW FAR ABOVE THE WALL TOP THE GABLE STAG HANGS, on the EAST end -- the one wall on this
		-- building that is tall, flat, empty and walked towards. Over the DOOR there is no gable at
		-- all: the ridge runs along x, so the south front is an eaves wall and a 44-degree slope is
		-- already below the wall top where it meets it (round 3).
		GABLE_MOUNT_STUDS = 3.4,
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
			COLOR = Color3.fromHex("36322F"),
			RIDGE_COLOR = Color3.fromHex("282523"),
			-- THE GABLE READ AS BRICK (spec 3): 82,58,40 on `WoodPlanks` over a log wall.
			GABLE_COLOR = Color3.fromHex("3E3022"),
			-- THE SHINGLE COURSES (spec 2) and the gable's own boarding (spec 3).
			-- 14 COURSES A SIDE, each lapping the one below by 0.40 of its 1.95 depth (spec 2).
			SHINGLE_COURSES = 14,
			SHINGLE_DEPTH = 1.95,
			SHINGLE_STEP = 1.55,
			SHINGLE_THICK = 0.22,
			-- NINE VERTICAL BOARDS PER GABLE END (spec 3).
			GABLE_BOARDS = 9,
			-- THE RAFTER TAIL IS LONGER AND IS SEATED ON THE SLAB (spec 4): 7.4 against 5.6, with its
			-- top face coplanar with the slab's underside.
			RAFTER_STUDS = 7.4,
			SHINGLE_A = Color3.fromHex("3A3734"),
			SHINGLE_B = Color3.fromHex("2F2C2A"),
			GABLE_BOARD = Color3.fromHex("443527"),
			BARGE_COLOR = Color3.fromHex("2E2419"),
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
			COLOR = Color3.fromHex("54524C"),
			CAP_COLOR = Color3.fromHex("363432"),
			-- A SHOULDERED STACK AND NOT A SLAB (spec 5): wide at the base, stepped in at the wall
			-- top, stepped out again under the cap. Every number is the spec's.
			BASE_WIDTH = 5.2,
			BASE_DEPTH = 7.3,
			STACK_WIDTH = 4,
			STACK_DEPTH = 6,
			SHOULDER_STUDS = 0.5,
			CORBEL_STUDS = 0.6,
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
			GLASS_COLOR = Color3.fromHex("8096A2"),
			GLASS_TRANSPARENCY = 0.42,
			FRAME_COLOR = Color3.fromHex("30251A"),
			SILL_COLOR = Color3.fromHex("423222"),
			SHUTTER_COLOR = Color3.fromHex("2E3E2C"),
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
			-- -11 AND NOT -13: a run shorter than `LOG_DIAMETER * 0.6` is dropped as a sliver, and at
			-- -13 the 0.7 studs between the opening and the wall's own end were exactly that -- a
			-- 0.2-stud slit through the corner on the courses the stub does not cross (review round
			-- 2, note).
			-- THE NORTH WALL'S WEST HALF IS THE TROPHY WALL NOW (spec 7, 15), so this window moves to
			-- the west wall, where it lights the table corner and misses both the fireplace breast
			-- (z -1.5 .. +9.5) and the chimney's bite (z +0.75 .. +7.25).
			{ wall = "west", along = -7 },
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
			WOOD_PER_ROW = 6,
		},
		-- THE COLOURS AND THE TIMBER. One palette, read by every piece.
		MATERIAL = Enum.Material.Wood,
		-- DARKER THAN THE FIRST BUILD, which photographed almost pink: Roblox's `Wood` is a bright
		-- material and two lanterns on the front wall lift it further. A Central-European lodge is
		-- oiled, weathered brown.
		-- ONE WOOD BECAME FOUR (the Designer's lodge spec, 2026-10-16, section 1). Karen, looking at
		-- the lodge: *"boar head is good but background is bad this wood is bad"*. Seven wood fields
		-- sat within 30 RGB points of each other on two materials, so the floor, the walls, the
		-- ceiling, the furniture and the porch were all the same orange plank.
		--
		-- EVERY VALUE IS DARKER THAN IT LOOKS, AND THE SPEC GIVES THE REASON: Roblox's `Wood` and
		-- `Cobblestone` textures are light and saturated and `Part.Color` MULTIPLIES them, so a
		-- mid-brown lands as bright orange. These are the colours that land where the old ones were
		-- meant to.
		LOG_COLOR = Color3.fromHex("4A3826"),
		-- A LOG WALL IS NEVER ONE TONE: the courses alternate (spec 1a, 6).
		LOG_COLOR_ALT = Color3.fromHex("58432D"),
		TIMBER_COLOR = Color3.fromHex("342819"),
		FLOOR_COLOR = Color3.fromHex("543E2A"),
		DECK_COLOR = Color3.fromHex("483828"),
		-- THE CEILING MUST RECEDE.
		CEILING_COLOR = Color3.fromHex("3A2C1F"),
		-- ...AND THE FURNITURE GOES THE OTHER WAY: the ONE worn, lighter wood, so the table, the
		-- benches and the counter read against a now-dark room.
		FURNITURE_COLOR = Color3.fromHex("765A3C"),
		DOOR_COLOR = Color3.fromHex("2E2319"),
		FIREWOOD_COLOR = Color3.fromHex("7C6348"),
		-- THE TWO NEW SHARED COLOURS (spec 1a): iron for every hinge, peg and lantern frame, and the
		-- shop panel's own brass for the trophy plates.
		IRON_COLOR = Color3.fromHex("2A2724"),
		BRASS_COLOR = Color3.fromHex("C8A258"),
		-- THE THREE TONES OF SPLIT FIREWOOD (spec 12), indexed by `(row + index) % 3`.
		FIREWOOD_TONES = {
			Color3.fromHex("7C6348"),
			Color3.fromHex("6E5740"),
			Color3.fromHex("8A7054"),
		},
		-- THE FIREPLACE, against the west wall, at the chimney's own `ALONG_STUDS`.
		FIREPLACE = {
			ALONG_STUDS = 4,
			WIDTH = 11,
			DEPTH = 3.2, -- how far the breast stands proud of the wall
			OPENING_WIDTH = 5.4,
			OPENING_HEIGHT = 4.2,
			HEARTH_STUDS = 2.6, -- how far the hearth stone reaches out onto the floorboards
			-- **THIS IS HALF OF "BACKGROUND IS BAD"** (spec 1a): a mid-grey on `Cobblestone` renders
			-- as cream, and the boar's head hangs on it.
			STONE_COLOR = Color3.fromHex("5A5750"),
			HEARTH_COLOR = Color3.fromHex("3A3835"),
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
			-- THE ROOM WENT DARK IN SPEC 1, so the lanterns carry more of it: three pools of warm
			-- light on a dark floor is the whole look (spec 11).
			brightness = 1.05,
			rangeStuds = 22,
			color = Color3.fromRGB(255, 186, 116),
			GLASS_COLOR = Color3.fromRGB(240, 186, 118),
		},
		CEILING_BEAMS = 6,
		-- THE TABLE AND ITS BENCHES, in the middle of the room. `OFFSET` is x and z from the room's
		-- own centre.
		-- WEST OF THE MIDDLE, AND THAT IS A MEASURED CLEARANCE AND NOT AN ARRANGEMENT: the walk from
		-- the doorway to the counter runs diagonally across the room, and a bench centred on the room
		-- stood in it (the spec caught it, with the bench named).
		-- NO TABLE AND NO BENCHES (task 196 part 3d). KAREN, 2026-10-16: *"remove table and all
		-- boar heads only keep one where is on fireplace"*. Archived with the builder:
		-- `backups/2026-10-16_task-196_table-and-north-trophies.txt`. Nothing replaces them --
		-- what goes in that floor, if anything, is Karen's.
		-- THE RUG IN FRONT OF THE HEARTH (task 195). Karen: *"make nice inside"*. One flat part
		-- lying ON the floorboards -- its bottom IS the floor's top, so it cannot float and cannot
		-- z-fight -- between the hearth stone and the north bench, and clear of both: the hearth
		-- reaches 5.8 studs out from the west wall and the bench's legs stop at the rug's own south
		-- edge plus 0.15. Cosmetic, so it stops nothing and the walk to the counter is unchanged.
		RUG = {
			OFFSET = Vector2.new(-6.4, 4), -- x and z from the room's centre, the TABLE's convention
			SIZE = Vector2.new(7, 3.2),
			THICK = 0.08,
			COLOR = Color3.fromHex("602C26"), -- a dark red kelim, the one warm colour in the room
			MATERIAL = Enum.Material.Fabric,
		},
		-- THE GUN RACK on the WEST wall, south of the fireplace -- the one stretch of wall with no
		-- window, no chimney and no counter on it. Scenery: it holds nothing, and `Weapon.Hardware`
		-- stays the only thing in this game that builds a gun.
		-- THE GUN RACK, BEHIND THE SELLER (task 196). Karen: *"behind the shoper shotguns on wall
		-- rifles on wall ect"*. It used to hang on the west wall with two DRAWN guns on it; it now
		-- hangs on the NORTH wall, centred on the counter, with four of `Weapon.Hardware`'s own guns
		-- laid across it and a shelf of shells under them.
		--
		-- EVERY NUMBER IS THE WALL'S OR THE GUN'S. A gun is 4.4 studs long (`Shotgun.CONFIG` and
		-- `Rifle.CONFIG`'s `HANDLE_SIZE.Z`), so a board 7 wide holds one with a stud and a bit to
		-- spare at each end and the pegs go at a quarter of the gun's own length either side of the
		-- middle -- read off the model, never typed. Four guns at 1.05 apart is 3.15 studs of board,
		-- plus the drop to the first: 4.2 tall, which clears the counter below (3.15) and the SHOP
		-- sign above (its bottom is 6.3).
		RACK = {
			ALONG_STUDS = 0, -- from the counter's own centre: dead behind the man
			WIDTH = 7,
			-- THE BOARD DROPS AND GROWS (spec 10): at 5.6/4.2 the lowest gun sat visually ON the
			-- counter top and the SHOP sign crossed the board. At 5.1/4.4 the board spans y
			-- 2.90..7.30, the guns hang at 6.60 / 5.60 / 4.60 / 3.60, and the lowest clears the
			-- counter top (3.15) by 0.45.
			HEIGHT = 4.4,
			HEIGHT_STUDS = 5.1, -- the board's centre above the floorboards
			BOARD_THICK = 0.35,
			GUNS = 4,
			GUN_GAP = 1,
			FIRST_GUN_DROP = 0.7,
			-- HOW FAR OFF THE BOARD A GUN HANGS: on the pegs, which stand 0.5 out, so its own
			-- half-thickness clear of the wood.
			GUN_OUT = 0.42,
			PEG_STUDS = 0.5,
			PEG_THICK = 0.22,
			PEG_DROP = 0.26, -- the peg sits under the gun, not through it
			PEG_SPAN = 1.1, -- the fallback when no model arrived to measure
			SHELF_THICK = 0.3,
			SHELF_DEPTH = 1.1,
			CARDBOARD_COLOR = Color3.fromHex("8A7050"),
			LABEL_COLOR = Color3.fromRGB(150, 32, 30),
			AMMO_BOX = { SIZE = Vector3.new(1.1, 0.62, 0.72), ALONG = { -2.2, -0.9 } },
		},
		-- THE SHOP'S COUNTER, and `Shop.CONFIG.REACH_STUDS` (14) is measured against its 12-stud
		-- width: a man at either end of it can reach the till. `COUNTER_ALONG` is how far east of the
		-- room's centre it stands and `COUNTER_BACK` how far in from the north wall, which leaves the
		-- keeper room to stand behind it.
		--
		-- 2.8 AND NOT 3.2, AND IT IS A MEASUREMENT (task 195): with the top at 3.55 studs over the
		-- floorboards only 1.4 studs of a 5.5-stud man cleared it, so from the customer side the
		-- keeper was a head in a hat sitting on a shelf. At 2.8 the top is 3.15 and his chest shows.
		COUNTER = Vector3.new(12, 2.8, 1.8),
		COUNTER_ALONG = 7,
		-- 6.4 AND NOT 4.6 (task 195), AND IT IS THE MAN'S OWN SIZE: his horizontal radius about his
		-- root was MEASURED at 2.42 studs (the hands' outer corners), and `faceKeeper` turns him on
		-- the spot -- so the arms that are at his SIDES when he faces the room swing FORWARD when he
		-- turns to a customer standing off to one side. A 3.7-stud bay could not hold that, and the
		-- live scan caught a lower arm 1.182 studs inside the till. 6.4 gives a 5.5-stud bay with
		-- 2.6 studs in front of him and 2.9 behind.
		COUNTER_BACK = 6.4,
		-- THE SERVICE SIDE, AND WHY IT IS CLOSED AT ALL (task 195). Karen: *"you can't go over the
		-- table"*. The counter is 12 studs of a 32.4-stud room, so before this there was a 3.2-stud
		-- gap at its east end, seventeen studs at its west, and nothing at all against a jump.
		--
		-- VALVE'S CLIP BRUSH, APPLIED (research note section 4): close it with VISIBLE timber first
		-- -- a WING from the counter's east end to the east wall and a RETURN from its west end to
		-- the north wall, both at counter height -- and put the invisible part ONLY above counter
		-- height, flush with a visible edge, so nobody ever bumps into nothing.
		--
		-- THE CLIP IS `CanQuery = false`, AND THAT IS LOAD-BEARING TWICE: a slab that stops a pellet
		-- changes what the shot hit (this file's standing rule), and the keeper's prompt
		-- (`REQUIRES_LINE_OF_SIGHT`) would never appear through a queryable wall at head height.
		SERVICE = {
			RETURN_WIDTH = 1.8, -- the counter's own depth, so the return reads as the same bench
			CLIP_THICK = 0.4,
		},
		-- TASK 178 REPLACED THE PLACEHOLDER, which said "SHOP - coming soon" and is archived with its
		-- reason in `backups/2026-10-14_task-178_lodge-sign.txt` (rule 7).
		SIGN_TEXT = "SHOP",
		-- THE MAN BEHIND THE COUNTER (task 181), and every number here is in
		-- `docs/research/2026-10-14-the-shopkeeper.md` section 4 with where it came from.
		KEEPER = {
			-- WHERE HE STANDS, from the counter's own centre: 1.6 studs further from the room (toward
			-- the back wall) so he is BEHIND the till and not standing in it. The counter is 1.8
			-- studs deep, so 1.6 clears its face by 0.7 -- and the north wall is three studs beyond.
			-- 3.5 SINCE TASK 195, AND THE OLD 1.6 WAS MEASURED WRONG RATHER THAN CHOSEN WRONG: the
			-- counter is 1.8 deep, so 1.6 left 0.2 studs between his torso and its back face, and
			-- the live scan caught his lower arm 1.182 studs THROUGH the till (research note
			-- section 2). 3.5 puts him in the MIDDLE of the deeper bay `COUNTER_BACK` now gives --
			-- 2.6 studs of air in front of him, 2.9 behind -- which is more than the 2.42-stud
			-- horizontal radius his own hands reach, whichever way `faceKeeper` turns him.
			BEHIND_STUDS = 3.5,
			-- HOW HIGH HIS FEET GO ABOVE THE FLOOR, the figure `Rig.place` pivots to: an R15 rig's
			-- origin is its root, about 3 studs over the ground it stands on.
			--
			-- SINCE TASK 195 IT IS THE FALLBACK AND NOT THE ANSWER. It put his `LeftFoot` at 151.860
			-- on a floor whose top is 152.048 -- 0.188 studs UNDER the floorboards, which is Karen's
			-- *"person not hanging"* read the other way. `Build.shopkeeper` asks the ENGINE instead:
			-- `Humanoid.HipHeight` (measured 2.192) is the distance from the root part's bottom to
			-- the ground, so the root's centre goes at `floorY + HipHeight + rootHalfHeight`. This
			-- number is what a body with no HipHeight at all gets.
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
			-- `"Keeper"` SINCE TASK 196, AND IT IS A LOOK AND NOT A TEAM. Karen, 2026-10-16:
			-- *"improve bot visual for shopper nice hat ect"*. `Match.Body.OUTFITS` grew a `Keeper`
			-- row -- loden suit, felt hat with a band and a brush, a waistcoat -- so the man behind
			-- the counter is dressed by the SAME system the players are and still looks like
			-- somebody who works here rather than like a hunter who wandered in. Until this he wore
			-- `"Shooters"`: the field green and the players' own cap.
			TEAM = "Keeper",
			-- LODEN, AND IT AGREES WITH `Match.Body`'s OWN FELT (the Designer's lodge spec, 2026-10-16,
			-- section 13b): the tint path and the row path have to land on the same colour or the
			-- brim and the crown are two different hats.
			HAT_COLOR = Color3.fromHex("35402A"),
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
			-- WHERE THE PROMPT HANGS, AND SINCE TASK 195 IT IS ON THE COUNTER AND NOT ON THE MAN.
			--
			-- IT IS A MEASUREMENT THAT MOVED IT, and the measurement contradicts Roblox's own
			-- reference: **`CanQuery = false` is IGNORED while `CanCollide` is true.** Four parts,
			-- one per combination, each shot at with a ray in Karen's own place on 2026-10-16 --
			-- collide+query HIT, **collide+noquery HIT**, nocollide+query HIT, nocollide+noquery
			-- passed through (`docs/research/2026-10-16-lodge-inside-clean.md` section 3.1). So the
			-- clip that stops a player jumping the counter necessarily stops the prompt's
			-- `RequiresLineOfSight` ray as well, and with the prompt on the keeper -- BEHIND the
			-- clip -- the shop could not be opened at all. Measured: *"sight blocked by
			-- CounterGuard"* at 1.5, 3 and 5 studs back from the till, and no panel on a trigger.
			--
			-- A FULL-HEIGHT BARRIER AND A SIGHT LINE THROUGH IT CANNOT BOTH EXIST, so the prompt
			-- moves to the SOUTH side of the barrier: an attachment on the counter itself, floating
			-- over the till `OVER_STUDS` above its top and `OUT_STUDS` in front of its customer
			-- face -- which is clear of the clip's own 0.4-stud slab -- with the keeper standing
			-- directly behind it. It is still *"a person bot who you need to click E"*: the man is
			-- what you walk up to, and `Lobby.shopPrompt` finds the prompt by name wherever in the
			-- lodge it hangs. It is still built ONLY when there is a keeper to stand behind it.
			PROMPT_OVER_STUDS = 1.2,
			PROMPT_OUT_STUDS = 0.45,
			-- THE PROMPT ITSELF. `HOLD_SECONDS = 0` is a tap and not a hold; line of sight is
			-- Valve's `+use` rule (note section 2c); 8 studs is the Director's number and reaches a
			-- man anywhere along the 12-stud counter.
			PROMPT = {
				ACTION_TEXT = "Shop",
				OBJECT_TEXT = "Press E",
				-- STILL THE DIRECTOR'S 8, and since task 195 it is measured from the COUNTER rather
				-- than from the man behind it -- so it is 8 studs of floor in front of the till
				-- instead of the 5.5 a keeper 1.6 studs behind it used to leave. The spec asserts
				-- the floor as well as the number.
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
	-- THE TROPHY WALL IS ONE REAL ANIMAL NOW (task 196). Karen, 2026-10-16: *"remove those fake
	-- antlers we will need real deer head with antlers and boar head"*, and, asked where the heads
	-- come from: *"we use our boar head and then add on a wall thats it in when we get red stag we
	-- add also"*.
	--
	-- So the fifteen drawn mounts -- twelve roe plates, two stags and a tusk plate, every one of them
	-- a bundle of cylinders -- are gone with their four size tables, archived in
	-- `backups/2026-10-16_task-196_drawn-antlers.luau` and
	-- `backups/2026-10-16_task-196_trophy-rows.luau` (rule 7), and ONE row is left: the game's own
	-- boar, on the chimney breast over the fire.
	--
	-- THE RED STAG'S PLACE IS KEPT AND IS NOT DRAWN. When the game has a red stag, its row is
	--     { kind = "stag", wall = "east", along = 0, height = HEIGHT_STUDS }
	-- -- the east gable wall, dead centre, the wall a player faces walking in from the door, with
	-- nothing on it today. It is written here rather than built, because a wall of empty boards is
	-- not a lodge either.
	-- THE TROPHY WALL (the Designer's lodge spec, 2026-10-16, sections 14 and 15). Karen, 2026-10-16:
	-- *"boar head is good but background is bad this wood is bad"*, and *"you can make few more
	-- famale and one more male"*.
	--
	-- THE HEADS DO NOT CHANGE. What changes is what they hang on -- a carved oak shield with a round
	-- top, a point, a lighter inner panel standing 0.09 proud of a dark board, and a brass plate
	-- under the chin -- and how many of them there are: the capital Keiler stays over the fire, and
	-- a second male and three sows go on the north wall, with the RED STAG'S PLACE KEPT EMPTY.
	TROPHIES = {
		-- 6.6 above the floorboards: the mount hangs on the chimney BREAST and has to clear the
		-- mantel at about 5.4.
		HEIGHT_STUDS = 6.6,
		UPPER_STUDS = 8.9,
		-- THE DARK BOARD AND THE LIGHTER PANEL ON IT. 104,72,44 on `Wood` rendered as a bright
		-- orange plank, which is the other half of *"this wood is bad"*.
		PLAQUE_COLOR = Color3.fromHex("2A1F16"),
		PANEL_COLOR = Color3.fromHex("5C462E"),
		BRASS_COLOR = Color3.fromHex("C8A258"),
		BONE_COLOR = Color3.fromHex("B9AE93"),
		SHIELD = { BOARD_THICK = 0.3, PANEL_THICK = 0.18, PLATE_THICK = 0.07, RIM_STUDS = 0.45 },
		-- THE CAPITAL BOAR, AND THE SOW AT 0.76 OF HIM ON x AND y (thicknesses unchanged). The sow's
		-- MODEL is smaller too -- `boar.female` measures 0.8553 of the male's length -- so her head
		-- and her tusks come out smaller with no scaling anywhere.
		BOAR = {
			WIDTH = 3.2,
			BODY = 1.9,
			POINT = 1.3,
			SNOUT_STUDS = 1.7,
			TILT_DEGREES = 18,
			SCALE = 1,
			ASSET = "boar",
			LABEL = "KEILER",
		},
		SOW = {
			WIDTH = 2.43,
			BODY = 1.44,
			POINT = 0.99,
			SNOUT_STUDS = 1.45,
			TILT_DEGREES = 16,
			SCALE = 0.76,
			ASSET = "sow",
			LABEL = "BACHE",
		},
		-- THE WALL IS THE NORTH WALL'S WEST HALF, x -16.2 .. -0.8 (spec 15): it is straight in front
		-- of the doorway, it is 15.4 studs of unbroken log once the north window moves to the west
		-- wall, and the shop keeps the east half. `standoff = -0.2` pushes the board 0.2 INTO the
		-- log bellies -- an overlap, never a touch, which is this spec's rule everywhere: flush
		-- against a round log leaves a hairline gap at the belly and coplanar faces at the course
		-- joins, and that is z-fighting in both.
		MOUNTS = {
			{ kind = "boar", wall = "west", along = 4, standoff = 3.2 },
			-- ONE MOUNT, AND IT IS THE ONE OVER THE FIRE (task 196 part 3d). KAREN, 2026-10-16:
			-- *"remove table and all boar heads only keep one where is on fireplace"*. The four
			-- north-wall rows -- a second Keiler and three Bache -- are archived. The red stag's
			-- empty place below is KEPT: Karen asked for it and it is still waiting for him.
		},
		-- THE BOARDED BACK STORE AND THE TWO SCONCES WENT WITH THE NORTH WALL (part 3d). The store
		-- existed to swallow four boar rumps that stood 1.52 studs proud of the outside face, and
		-- the sconces existed to light four heads; with the heads gone there is nothing behind the
		-- wall and nothing on it to light. The capital boar over the fire needs neither: it is
		-- 6.25 studs inside the chimney stonework, measured. Archived with the rest.
		-- THE RED STAG'S PLACE, KEPT AND LEGIBLE (spec 15c). Nothing is built inside this box; two
		-- iron pegs are fixed at the top of it, where a shield would hang from, so it reads as KEPT
		-- rather than as forgotten. The day a stag model exists it mounts at
		-- `{ kind = "stag", wall = "north", along = -8.5, height = 9.2, standoff = -0.2 }`.
		-- IT BUILDS NOTHING SINCE PART 3E. The two iron pegs are gone: on a wall with no trophies
		-- left on it they read as two stray dots. What stays is the MEASUREMENT -- which stretch of
		-- wall is reserved for him and how high he hangs -- so the day a red stag exists nobody has
		-- to work it out again, and `PEG_*` goes with the parts it described.
		STAG_PLACE = {
			ALONG = { -11.2, -5.8 },
			HEIGHT = { 7.2, 11.2 },
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
		-- ---------------- THE TRUCK STARTS (task 197)
		--
		-- KAREN, 2026-10-15 ~17:40, verbatim: *"also could be car started sound light on something
		-- like that indicating loading ect"*.
		--
		-- SO THE PAD'S OWN TRUCK STARTS WHEN THE PARTY COMMITS, and the other three stay dark: an
		-- engine, headlights, tail lights and a little exhaust smoke, up for exactly as long as
		-- `Lobby.padLoading` is true of that pad (`Build.setTruck`, reconciled on the owner's own 10 Hz
		-- scan and not on a pick event -- so a party that cancels, resets or is interrupted leaves no
		-- truck idling with nobody in it).
		--
		-- THE LAMPS ARE THE MODEL'S OWN, and that is a measurement and not a preference. "PickUp
		-- Truck (Prop)" ships its lights as `Neon` parts and `camo` was already written to leave every
		-- one of them alone; dumped out of `Workspace.LobbyAssets.Truck` in the Forest Test on
		-- 2026-10-17, in the model's own frame (x along its 18.46-stud length), they are:
		--     Light  x -7.82  z +-2.47  1.29 x 1.12 x 1.35  white 248,248,248   <- the headlights
		--     Light  x -8.11  z   0.00  5.74 x 0.59 x 0.57  amber 213,115,61    <- the front bar
		--     TS     x -7.99  z +-2.76  0.51 x 0.32 x 0.24  amber 213,115,61    <- the indicators
		--     T      x +8.53  z +-3.15  0.40 x 1.00 x 0.66  red   255,89,89     <- the tail lights
		--     B      x +8.63  z +-3.13  0.36 x 0.81 x 0.20  red   190,104,98    <- the brake lights
		--     Light  x  0.05  z   0.00  6.70 x 4.50 x 17.65 grey  163,162,165   <- the CHASSIS, named
		--                                                                          "Light" and 17
		--                                                                          studs long
		-- The last row is why `LAMP_MAX_STUDS` exists: `Build.truckSkinOf` calls anything `Neon` or
		-- named "light" a light, which is right for the paint rule and would here have hung a
		-- SpotLight inside the chassis. A lamp is small.
		--
		-- SO NOTHING IS GUESSED ABOUT WHICH WAY A TRUCK FACES, and that matters because the free model
		-- faces the OPPOSITE way from `Build.truck`'s fallback: the white pair IS the front, whichever
		-- end of the box it is on, and the spotlights point from the truck's centre out through it.
		ENGINE = {
			-- A LAMP IS SMALL. Over the measured list above this keeps every real lamp (1.35 studs at
			-- the largest) and rejects the chassis (17.65) and the two 6-stud `Light`/`R` blobs.
			LAMP_MAX_STUDS = 2.5,
			-- WHITE MEANS HEADLIGHT. 248,248,248 passes; the ambers (213,115,61) and the reds
			-- (255,89,89 and 190,104,98) do not, because their lowest channel is 61, 89 and 98.
			HEAD_MIN_CHANNEL = 0.75,
			-- ...AND EVERY OTHER SMALL LAMP ON THE FAR HALF OF THE TRUCK FROM THEM IS A TAIL LIGHT.
			-- It is a POSITION test and not a colour test on purpose: the amber indicators at the
			-- FRONT are the same hue family as a tail light, and a red glow on a bonnet is exactly
			-- the kind of thing that measures correct and looks wrong (`docs/PROJECT_CONTEXT.md`).
			HEAD_COLOR = Color3.fromRGB(255, 246, 214),
			HEAD_OFF_COLOR = Color3.fromRGB(86, 84, 76),
			TAIL_COLOR = Color3.fromRGB(255, 72, 56),
			TAIL_OFF_COLOR = Color3.fromRGB(74, 40, 36),
			-- THE SPOTLIGHT IN EACH HEADLAMP. 60 degrees and 46 studs reaches the yard in front of
			-- the truck without lighting the lodge 46 studs behind it; `Shadows` is on because a beam
			-- with no shadow is a glow, and four trucks are never lit at once.
			HEAD_BRIGHTNESS = 3,
			HEAD_RANGE_STUDS = 46,
			HEAD_ANGLE_DEGREES = 60,
			-- THE TAIL LIGHTS ARE A GLOW AND NOT A BEAM, so a `PointLight` with a short range: a tail
			-- light you can see from behind the truck, which is where the pad is.
			TAIL_BRIGHTNESS = 2,
			TAIL_RANGE_STUDS = 12,
			-- ...AND A FALLBACK TRUCK HAS NO LAMPS AT ALL. `Build.truck` builds seven boxes and four
			-- cylinders and not one light, so when the free model is missing the rig builds its own
			-- four lenses off the truck's measured box: at this fraction of its half-width, this
			-- fraction of its height, flush with the end faces. Four parts a truck.
			LENS_STUDS = Vector3.new(1.1, 0.8, 0.3),
			LENS_SIDE_FRACTION = 0.62,
			LENS_HEIGHT_FRACTION = 0.42,
			-- THE EXHAUST. One `ParticleEmitter` in an `Attachment` -- no part, so no part budget --
			-- low and to one side at the rear, which is where a tailpipe is.
			SMOKE_RATE = 7,
			SMOKE_SIZE_STUDS = 1.4,
			SMOKE_SPEED_STUDS = 2.6,
			SMOKE_LIFETIME_SECONDS = 1.5,
			SMOKE_COLOR = Color3.fromRGB(176, 176, 172),
			SMOKE_TRANSPARENCY = 0.72,
			SMOKE_SIDE_FRACTION = 0.55,
			SMOKE_HEIGHT_FRACTION = 0.12,
			-- ROBLOX'S OWN PARTICLE TEXTURE, which ships inside the engine (`rbxasset://`, not
			-- `rbxassetid://`): it cannot 404, cannot be moderated away and needs no upload --
			-- `Viewmodel`'s own stated reason for using this family.
			SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds",
			-- ---------------- the voice
			--
			-- BOTH IDS ARE ROBLOX-PROVIDED LICENSED LIBRARY AUDIO, verified by name and creator
			-- through `economy.roblox.com/v2/assets/<id>/details` and measured to LOAD in this place
			-- with `ContentProvider:PreloadAsync` -- the procedure task 124 used for the hit ticks and
			-- task 142 for the rifle. `IsPublicDomain` is true for both.
			--
			-- START: "1942 Dodge Wc Command Car Start Idle Revs 1 (SFX)", **ProSoundEffects**, asset
			-- 9112936632, category *Vehicles - Military* -- *"Start, Idle, Revs, Turn Off, 6
			-- Cylinder"*. A 1940s military command car is what four camouflaged hunting trucks sound
			-- like, and it is the only start in the licensed catalogue whose category is the same
			-- word as `CAMO`'s. Measured `IsLoaded = true`, `TimeLength = 10.87 s`.
			--
			-- IDLE: "2003 Dodge Ram Truck Start Med Cu Long Idle 2 (SFX)", **ProSoundEffects**, asset
			-- 9125350177 -- *"Start Medium CU, Long Idle, Reverse"*, 24.9 s by its own description.
			-- The LOOP WINDOW is measured off the asset's own loudness, not taken from the
			-- description: see `IDLE_FROM` / `IDLE_TO`.
			START_SOUND_ID = "rbxassetid://9112936632",
			IDLE_SOUND_ID = "rbxassetid://9125350177",
			-- THE CLIPS ARE CUT, through `PlaybackRegion`, for the reason `Horn.CONFIG`'s own cut
			-- exists: an asset is a RECORDING of an event and not the event. The start clip ends by
			-- turning the engine off and the idle clip begins by starting it, and either played whole
			-- would say the opposite of what the banner says.
			--     https://create.roblox.com/docs/reference/engine/classes/Sound#PlaybackRegion
			-- BOTH WINDOWS ARE MEASURED off the assets' OWN loudness -- `Sound.PlaybackLoudness`, peak
			-- per 0.2 s bucket, sampled at render rate in a Play session of the DEV place on
			-- 2026-10-17 -- and the whole profile is in the research note's section 5.
			--
			--   9112936632, 10.87 s:  0.0-0.6 the starter turning (35-123) | 0.6-2.0 THE CATCH, the
			--     clip's loudest moment (191 at 0.8) | 2.0-3.3 settling to idle (70-114) | 3.4-4.6 A
			--     REV (158 at 4.0) | 4.6-6.0 the rev falling away into the TURN-OFF (104 to 36) |
			--     6.0-10.8 the recording's own tail (21 down to 0).
			--   SO THE CUT IS 0 -> 3.3: crank, catch, settle. One second later it revs and then shuts
			--   down, and a truck that starts, revs and dies while the banner says it is leaving is
			--   the opposite of the thing Karen asked for.
			--
			--   9125350177, 24.91 s:  0.0-0.4 silence then ITS start (240 at 0.4) | 0.4-2.0 the start
			--     (156-71) | 2.0-6.0 settling (56 down to 17) | **6.2-23.8 FLAT 13-18, seventeen and a
			--     half seconds of nothing but idle** | 24.0-24.9 the fade-out (7 to 2).
			--   SO THE LOOP IS 6.2 -> 23.6, inside the flat part at both ends: the asset's own start
			--   and fade are outside it, so the loop cannot re-start the engine every pass.
			START_FROM = 0,
			START_TO = 3.3,
			IDLE_FROM = 6.2,
			IDLE_TO = 23.6,
			-- THE TWO VOLUMES COME OUT OF THE SAME MEASUREMENT and are not a taste. The start clip
			-- runs at a loudness of ~100-190 and the idle window at ~15 -- the Dodge Ram was recorded
			-- far quieter than the command car -- so equal `Volume` would have made the idle inaudible
			-- the moment the start finished, which is exactly the silence this task exists to remove.
			-- 0.45 against 1.0 is a 2.2x gain the other way, leaving the START still the louder event
			-- (a start IS louder than an idle) with the idle clearly there under it. Karen's dials.
			START_VOLUME = 0.45,
			IDLE_VOLUME = 1,
			-- HOW FAR THE ENGINE CARRIES. 90 studs: audible from the lodge porch (46 studs from the
			-- bays) and gone from the far corners of a 220-stud field -- `BILLBOARD.MAX_DISTANCE_STUDS`
			-- 160's own reasoning, one step tighter because a sound crosses a wall and a billboard
			-- does not.
			ROLL_OFF_MIN_STUDS = 14,
			ROLL_OFF_MAX_STUDS = 90,
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
		-- BIRCH AND ALDER, AND NOTHING ELSE (the Designer's lodge spec, 2026-10-16, section 16).
		-- Karen: *"all has to be berzas or alksnis"* -- birch or alder. `treeLine` used to pick at
		-- random from everything in `LobbyAssets.Trees`, which is five models: a birch, two oaks, a
		-- larch and an aspen that MEASURES 0 x 0 in the live place (an empty model, measured
		-- 2026-10-16). An ALLOW-LIST rather than a cut-down folder, so the folder stays reusable and
		-- the empty aspen can never be picked again.
		--
		-- THERE IS NO ALDER MODEL IN THIS PLACE -- measured: `LobbyAssets.Trees` has birch, two oaks,
		-- a larch and the empty aspen; `OurForest` adds spruce. The spec's honest substitute is the
		-- forest oak RE-TINTED to alder's near-black furrowed trunk and dark cool-green leaf, and
		-- held under 0.82 scale, because size is what gives an oak away. A real alder is an upload
		-- and is listed as one (spec 18).
		-- `CLAW_FRACTION` IS A PROPERTY OF THE MESH, MEASURED ONCE (task 196 part 3e): how far above
		-- the model's lowest point its root flare stops being claws and becomes trunk, as a fraction
		-- of the model's HEIGHT so it survives the per-tree random scale. A tree is planted with
		-- that junction on the ground and its claws underneath; seating the claw TIPS on the ground
		-- is what left daylight under every arch in the two frames Karen reported.
		--
		-- HOW THEY WERE MEASURED, 2026-10-16: each template rayed horizontally at sixty heights
		-- from its own TRUNK AXIS -- not its bounding-box centre, which for the oak is 1.1 studs
		-- off it -- reading the height at which the radius falls back to the trunk's own.
		SPECIES = {
			-- 74.3 studs tall, trunk radius 0.57. Radius 2.45 at the foot, 1.48 at 5 %, 1.04 at
			-- 5.8 %, flat 0.78 from 7.5 % up: 5.6 studs of arched claws.
			{ MODEL = "SilverBirch_Var11_LOD_0", KIND = "birch", WEIGHT = 3, CLAW_FRACTION = 0.075 },
			-- 70.2 studs tall, trunk radius 0.46, and its radius is 0.79 at the foot and flat from
			-- there: this model has no flare at all, so it needs almost nothing.
			{
				MODEL = "Forest_OakTree_Var01_LOD_0",
				KIND = "alder",
				WEIGHT = 2,
				TINT = "alder",
				CLAW_FRACTION = 0.03,
			},
		},
		-- HOW DEEP THE FLAT CUT ROOT IS BURIED under the ground the engine really produced: enough
		-- that no tree stands on a disc, little enough that none reads as a bush.
		SINK_STUDS = 0.6,
		-- HOW WIDE THE CLEAR CORRIDOR IN FRONT OF THE HOUSE IS, each side of its centre line. 22
		-- covers the porch's own 14-stud width plus the view past its ends.
		FRONT_HALF_WIDTH = 22,
	},
	-- THE ALDER'S TWO COLOURS (spec 16b). Applied by name and material, the rule `Build.camo` already
	-- proves for the trucks.
	ALDER = {
		TRUNK_COLOR = Color3.fromHex("3A342C"),
		LEAF_COLOR = Color3.fromHex("2C4426"),
		SCALE = { 0.66, 0.82 },
	},
	-- ---------------- THE GROVE BY THE HOUSE (spec 16c)
	--
	-- TWELVE TREES IN THREE GROUPS, in the LODGE'S OWN FRAME (+x east, +z north, origin the lodge
	-- centre): four birches off the west gable, four north-east, and four alders tight together in
	-- the hollow behind. Nothing is planted south of z = -20 -- the front of a hunting lodge is
	-- working ground: the road, the four bays, the turning circle and the pads.
	--
	-- EVERY CROWN CLEARS THE ROOF OUTLINE (40.4 x 32.8) BY AT LEAST 3 STUDS, which is the spec's own
	-- `distance(trunk, nearest point of that rectangle) - 13.5 * scale`, and `lobby.spec` asserts it
	-- rather than trusting the table.
	LODGE_TREES = {
		{ kind = "birch", x = -37, z = 6, scale = 0.95, yaw = 77 },
		{ kind = "birch", x = -35, z = 17, scale = 0.8, yaw = 102 },
		{ kind = "birch", x = -42, z = -2, scale = 0.72, yaw = 124 },
		{ kind = "birch", x = -32, z = 27, scale = 0.88, yaw = 103 },
		{ kind = "birch", x = 35, z = 22, scale = 0.9, yaw = 117 },
		{ kind = "birch", x = 28, z = 31, scale = 0.76, yaw = 47 },
		{ kind = "birch", x = 41, z = 28, scale = 0.84, yaw = 345 },
		{ kind = "birch", x = 24, z = 40, scale = 0.95, yaw = 88 },
		{ kind = "alder", x = -8, z = 34, scale = 0.78, yaw = 338 },
		{ kind = "alder", x = -1, z = 38, scale = 0.7, yaw = 121 },
		{ kind = "alder", x = 7, z = 33, scale = 0.82, yaw = 112 },
		{ kind = "alder", x = -14, z = 41, scale = 0.66, yaw = 183 },
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
		-- clear the lodge's east wall, whose outer face is x +18 (`SIZE.X / 2`, task 187; it was +21
		-- with task 177's wider lodge and 2-stud logs, so the clearance only grew), which bounds the
		-- half-width at 5; and the far edge has to stay south of
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
		--
		-- TASK 197 SPLITS THE WORD OFF THE NUMBER, and that is the designer's row shape rather than a
		-- rewrite of Karen's: `label` is still the size and nothing else (*"1 / 1"*), and `note` is
		-- the short line under it the Director asked for -- *"big buttons with a short line each:
		-- '1/1 -- hunt alone with bots', '2/2', '4/4', '8/8 -- full hunt'"*. The two rows the brief
		-- left bare get a line anyway, because a row with no line in a list of four reads as a row
		-- that is missing something (`docs/design/shop.md`'s own rule for the catalogue).
		--
		-- `1 / 1  alone` BECOMING `1 / 1` + `hunt alone with bots` IS THE SAME SENTENCE, SAID BIGGER,
		-- and the number is now set in Oswald at 20 px with the line in BuilderSans at 12 under it --
		-- the shop panel's own two-line row (`docs/design/shop.md` 3.3: *"name on line 1, price on
		-- line 2"*).
		SIZES = {
			{ size = 1, label = "1 / 1", note = "hunt alone with bots" },
			{ size = 2, label = "2 / 2", note = "you and one friend" },
			{ size = 4, label = "4 / 4", note = "a small party" },
			{ size = 8, label = "8 / 8", note = "full hunt" },
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
		-- TASK 197 RESTYLES IT IN THE DESIGNER'S HOUSE STYLE and makes the buttons bigger. KAREN,
		-- 2026-10-15 ~17:40: *"same with entering in game menu has to be nicer and cleaner"*. The
		-- style is the shop's, which is the one Karen has already approved (*"menu is nice"*) and
		-- which its own spec section 8 was written to govern: *"The shop sets the house style.
		-- Anything built after it follows these, and nothing else needs deciding."* The COLOURS and
		-- the FONTS are not repeated here -- `Hud.PadPanel` reads `Hud.ShopPanel.LOOK` and
		-- `.FONT` -- so what is in this table is still only what BOTH SIDES read.
		PANEL = {
			TITLE = "HOW MANY PLAYERS?", -- Karen's own word: *"select how many players"*
			-- THE BRAND EYEBROW ABOVE THE TITLE (spec 3.2), and it carries the one fact the dialog
			-- used to leave to the billboard outside: WHICH truck you are standing behind. The pad
			-- index is already on this client (`Lobby.padAsking` answers it), so this costs no wire.
			EYEBROW = "TRUCK %d",
			-- THE MESSAGE SLOT (spec 8.8): *"Every panel has exactly one line that carries its
			-- caveat"*. This dialog's caveat is its own way out -- the thing a player who does not
			-- want to pick cannot otherwise guess, because there is deliberately no close button.
			HINT = "STEP OFF THE PAD TO CHANGE YOUR MIND",
			-- 320, AND IT STILL FITS THE 400 px PHONE `hud_clarity.spec` MEASURES. 20 wider than
			-- task 182's 300, which is what pays for the two-line rows.
			WIDTH = 320,
			-- 64, THE SHOP HEADER'S OWN HEIGHT (spec 3.2: *"64 px tall, identical in both modes"*),
			-- so the eyebrow, the title and the brass hairline under them land where that panel puts
			-- them and the two headers are one header drawn twice.
			HEADER_PX = 64,
			ROW_PX = 60,
			GAP = 8,
			-- 60 NOW, NOT 48. `Rail.CONFIG.BUTTON_PX`'s 48 was already over the 44 px Roblox's own
			-- tutorial sets as a touch minimum; the Director asked for *"big buttons with a short
			-- line each"*, and spec 8.6 puts a secondary row at 48-60. A two-line row needs the
			-- height anyway: 20 px of number plus 14 of line plus the padding.
			BUTTON_PX = 60,
			-- THE HINT'S OWN BAND under the last row.
			HINT_PX = 26,
			-- `Report.CONFIG.PANEL_Z_INDEX`'s band. `Rail.CONFIG.Z_INDEX` is 16 and stays pressable
			-- over this dialog -- the `Shop.CONFIG.PANEL` arrangement.
			Z_INDEX = 15,
		},
		-- ---------------- THE LOADING MESSAGE (task 197)
		--
		-- KAREN, 2026-10-15 ~17:40, verbatim: *"and we need clear message that game is loading once
		-- clicked 1/1 or other now is delay"*.
		--
		-- WHAT SHE WAS LOOKING AT: task 182 put the whole of this on the ONE objective line, 27
		-- characters of lower-case at the top of the screen (`Objective.CONFIG.TEXT.LobbyLeaving`,
		-- *"leaving for the hunt in %d"*) -- and that line is also where the compass, the chevron and
		-- every other instruction live, so the five seconds between pressing a button and being
		-- somewhere else read as nothing happening. It is a BANNER now, across the screen, with the
		-- seconds and a bar; the objective line keeps its own sentence and is not touched.
		--
		-- THE WORDS ARE ROWS BECAUSE THEY ARE WORDS, and words are Karen's to rewrite (every TEXT
		-- table in this repository). `TITLE` is the Director's own sentence.
		LEAVING = {
			TITLE = "LEAVING FOR THE HUNT",
			EYEBROW = "TRUCK %d",
			-- ONE LINE PER STATE, and there are exactly three because `Lobby.padLoading` admits
			-- exactly three states. A state with no line would be a banner that came up blank.
			FILLING = "WAITING FOR THE PARTY",
			COUNTDOWN = "THE TRUCK LEAVES IN %d",
			GOING = "GETTING YOU TO YOUR STAND",
			-- FULL WIDTH, which is the Director's word -- `UDim2.new(1, -2 * MARGIN_PX, 0, HEIGHT_PX)`
			-- on a phone -- with `MAX_WIDTH` so a 2560 px desktop gets a banner and not a letterbox.
			-- It is a SCALE and not a viewport read, so nothing has to re-measure on a resize.
			MARGIN_PX = 12,
			MAX_WIDTH = 560,
			HEIGHT_PX = 112,
			-- 0.68 OF THE SCREEN, under the middle: clear of the top band (the compass strip, the
			-- objective line, the score) and clear of the bottom rail, which is where every other
			-- thing that is not this banner already is.
			Y_SCALE = 0.68,
			BAR_PX = 10,
			-- `PANEL.Z_INDEX`'s OWN NUMBER, not one above it. The two can never be up together -- the
			-- dialog needs `sizing` and the banner needs one of the three states after it -- and
			-- `Rail.CONFIG.Z_INDEX` is 16 and must stay PRESSABLE over both (`Shop.CONFIG.PANEL`'s
			-- arrangement, and the reason the dialog is 15 rather than 17).
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
	-- ---------------- THE GATHERING AT THE CABIN (task 191)
	--
	-- The RECTANGLE is the `Gather` row in `FIELD.PADS` and is not repeated here. What is here is the
	-- one thing a rectangle cannot say: WHICH WAY THE SCENE FACES.
	--
	-- `(1, 0, 0)` IS EAST, AT THE LODGE, and it is not a taste: `Match.Scene.sideAxis` crosses the
	-- facing with +Y, so a look of +X gives a row axis of +Z -- the animals lie in a line running
	-- north-south, and a player walking out of the porch (which is east of the yard) sees the whole
	-- row BROADSIDE rather than end-on. The second row stacks WEST, away from him, which is what
	-- `Scene.rowLayout` already means by "behind". `Scene.ringLayout` is a full circle and does not
	-- read it at all.
	GATHER = {
		PAD_NAME = "Gather",
		FACING = Vector3.new(1, 0, 0),
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
	-- mounts -- is **418 parts, counted in the live place**, four trucks 304, thirty trees about 150,
	-- and the road, verges, fences, four pads, yard and spawn the rest: **885 for the whole lobby,
	-- also counted**, with headroom for a fifth window or another row of antlers. The Director's own
	-- ceiling for this task was 1,500.
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

-- ---------------------------------------------------------------- the gathering yard (task 191)

-- THE `Gather` ROW, FOUND BY NAME -- or nil for a config that has none. PURE.
--
-- BY NAME AND NOT BY INDEX, so a fourth pad added anywhere in the list cannot silently become the
-- gathering yard: `CFG.FIELD.PADS[3]` would have been a position, and a position is not an identity.
-- nil is a legal answer and every reader takes the branch it is given -- a world whose config has no
-- gathering yard gathers where the drive always did.
function Lobby.gatherPad(cfg): { [string]: any }?
	for _, pad in ipairs(cfg.FIELD.PADS) do
		if pad.NAME == cfg.GATHER.PAD_NAME then
			return pad
		end
	end
	return nil
end

-- WHERE THE DAY'S BAG IS LAID OUT, AND WHICH WAY THE SCENE FACES. PURE in the ground reader, which
-- is what lets `lobby.spec` state the spot with a hand-written function and no world at all -- the
-- `Match.gatherSpotFor` shape it replaces in this world.
--
-- THE Y IS MEASURED AND NEVER PREDICTED, and that is the one thing in this function that is not
-- arithmetic. `Field.fill`'s surface is NOT the nominal shelf: Roblox terrain is voxelised, and task
-- 186 measured 150.000 against a shelf at 149.248 in this very yard -- which is why all four trucks
-- had their tyres 0.752 studs underground. So the centre's height is `groundAt`'s answer, and the
-- shelf (`anchor.Y`) is only the fallback for a reader that answers nothing.
--
-- IT IS NOT A SECOND DEFINITION OF "WHERE IS THE GROUND": `groundAt` is the world's own single
-- reader, handed down by the owner -- the same function `Field`, `Build.pads`, `Build.trucks`,
-- `Match.Body` and `Bots` are all given. `Scene.build` asks it AGAIN per animal and per torch (task
-- 192) and `Body.stand` snaps every ring slot onto it, so three readers share one answer.
--
-- `facing` IS A UNIT VECTOR AND THE CONFIG'S OWN (`GATHER.FACING`), returned beside the spot because
-- `Match.Scene` takes the pair and this owner must not hand back half of it.
function Lobby.gatherSpotFor(anchor: Vector3, cfg, groundAt: ((number, number) -> number?)?): (Vector3?, Vector3?)
	local pad = Lobby.gatherPad(cfg)
	if pad == nil then
		return nil, nil
	end
	local centre = anchor + (pad :: any).OFFSET
	local y = anchor.Y
	if groundAt ~= nil then
		local ok, measured = pcall(groundAt :: any, centre.X, centre.Z)
		if ok and type(measured) == "number" then
			y = measured :: number
		end
	end
	return Vector3.new(centre.X, y, centre.Z), cfg.GATHER.FACING
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
-- THE CLIENT IS ITS READER. The server BUILDS it (`Lobby.Build`'s `shopPrompt`, on the counter since
-- task 195 and only when there is a keeper behind it) and never reads it back;
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
