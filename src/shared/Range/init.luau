-- Range (shared): the lobby shooting range's FROZEN DATA and its PURE ARITHMETIC. No Instances, no
-- state, no clock -- so a server spec drives every line of it with no client and no world, which is
-- the `ReplicatedStorage.Lobby` / `ReplicatedStorage.ForestTest` shape.
--
-- Design: docs/design/shooting-range.md sections 3, 4.1 and 8.4, and its delta
-- docs/design/shooting-range-lobby.md 5.1-5.4, 7.1-7.3 and 9.1 (where every number now comes from).
-- Task 298 phase B; task 306 steps B2 and B3.
--
-- Owner (CLAUDE.md rule 3): the range's DATA -- names, words, the lane arithmetic, the whitelists --
-- has NO run-time writer; it is edited by the Builder in git. The geometry is
-- `ServerScriptService.Range.Build`'s and the state is `ServerScriptService.Range`'s.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Report = require(ReplicatedStorage:WaitForChild("Report"))
-- THE SEAT IS THE HUNT'S OWN SEAT, not a second structure: `HighSeats` says what a seat is and how
-- wide its feet stand, and this module only says WHERE one goes (design shooting-range-lobby 7.1).
local HighSeats = require(ReplicatedStorage:WaitForChild("HighSeats"))

local Range = {}

Range.FOLDER_NAME = "Range"
Range.MAT_NAME = "Mat"
Range.PROMPT_NAME = "RangePrompt"
-- THE SECOND PROMPT'S OWN STEM. Two prompts per station, both found by name (`Lobby.Data.shopPrompt`'s
-- shape), so "which one did he press" is never a guess about a position.
Range.STAND_PROMPT_NAME = "RangeStandPrompt"
-- THE TWO CLIMB PROMPTS' OWN STEMS (step B10, item 6), and the turf slab's name. Same rule as
-- above: found by NAME, so nothing downstream guesses from a position.
Range.CLIMB_UP = "RangeClimbPrompt"
Range.CLIMB_DOWN = "RangeDownPrompt"
Range.TURF_NAME = "Turf"
Range.REMOTES_NAME = "Remotes"
-- THE FOLDER THE LANE'S ANIMALS LIVE IN (task 304). `RangeBoot` names its runtime's world with it
-- and `ForestTestBoot` asks `Range.isTarget` with it, so "is this the hunt's animal or the range's"
-- has ONE answer and `HitLog` learns nothing about the range.
Range.TARGETS_FOLDER = "RangeTargets"

-- IS THIS PART A RANGE TARGET? `Boar.Body.create` parents the trunk into the runtime's folder and
-- welds the zone parts under the trunk, so one ancestor read answers for both.
function Range.isTarget(part: Instance?): boolean
	if typeof(part) ~= "Instance" then
		return false
	end
	return (part :: Instance):FindFirstAncestor(Range.TARGETS_FOLDER) ~= nil
end

-- THE WORDS, because they cross the wire in step B4 and a second spelling is a silent refusal
-- (`Lobby.ROLE`'s rule). `STAND` is Karen's, 2026-10-27: *"walk trot stand run"* -- a target held
-- broadside at the lane's middle, which isolates AIM from LEAD.
Range.WORD = {
	WALK = "walk",
	TROT = "trot",
	STAND = "stand",
	RUN = "run",
	-- ISSF's two running-target paces (design 6). They are TIMES across the window, not speeds:
	-- <https://en.wikipedia.org/wiki/50_meter_running_target> and the `mixed` event beside it.
	SLOW = "slow",
	FAST = "fast",
	MIXED = "mixed",
}

-- THE ONLY NUMBERS TYPED FOR THE TWO NEW PACES: the time the target takes to cross the window.
-- The stud speed falls out of `WINDOW_STUDS`, so a later window keeps the real timing instead of
-- silently changing it. ISSF 50 m running target: slow 5.0 s, fast 2.5 s.
Range.CROSSING_SECONDS = {
	slow = 5.0,
	fast = 2.5,
}

-- Every dimension in ONE table, read by `Build`, which invents none (`TestArena.LAYOUT`'s rule).
-- Offsets are relative to the anchor: +x east, +z north, Y from the shelf. The lane runs along X
-- and the shooter looks along +Z -- one axis for the crossing, one for the range, so the ballistic
-- lead and the measured crossing are perpendicular and neither contaminates the other.
Range.LAYOUT = {
	folderName = Range.FOLDER_NAME,
	-- 35 m at `Report.CONFIG.METRES_PER_STUD` 0.28: the distance the menu OPENS on (Karen's
	-- default, design 15 item 12).
	DISTANCE_STUDS = 125,
	-- THE THREE LANES: 30 m (Vildsvinspasset), 35 m (shipped), 50 m (ISSF running boar, inside the
	-- 48-62 m band a German driven-hunt shooter is tested in). Design 5.1.
	DISTANCES_STUDS = { 107, 125, 179 },
	-- ISSF's 10 m running-boar window at `Report.CONFIG.METRES_PER_STUD` 0.28 -- 10.08 m, because
	-- 10.00 m is 35.714 studs and the lane is laid on whole studs (306a note (b)'s rounding, stated
	-- rather than hidden). 40 was a first pick.
	WINDOW_STUDS = 36,
	-- Room to turn around behind a bank. A FIRST VALUE, confirmed by the measured crossing time.
	APRON_STUDS = 20,
	-- SIX ISOLATED STATIONS (Karen, 2026-10-28: *"several places where they can click E"*). They
	-- share ONE corridor, because each man is drawn only his own animal (design 5.3).
	SPOT_COUNT = 6,
	-- `2 * PROMPT.MaxActivationDistance`: the smallest spacing at which a man on mat n is out of
	-- reach of mat n+-1's prompt.
	SPOT_SPACING_STUDS = 24,
	-- THE BANKS STAND BEYOND THE ENDS OF THE LANE, NOT ON THEM, AND THAT IS A MEASUREMENT (task 298
	-- step B2): built on the end, the target hit the bank's inner face and STOPPED 7.8 studs short
	-- of an end it could never reach, so no leg ever finished.
	-- A LOW COVER BANK, not a screen (Karen, 2026-10-28: *"behind animal could be a mountain not
	-- high"*). `beyondStuds` is the clearance between the lane's end and the bank's NEAR face, so
	-- the bank's OUTER face stands at `beyondStuds + size.X` past that end -- which is the number
	-- the berm has to reach (306a(c)).
	BANK = { size = Vector3.new(12, 8, 14), beyondStuds = 6, color = Color3.fromRGB(96, 88, 76) },
	-- THE BERM HAS NO TYPED WIDTH: `Range.bermWidthFor` derives it so it spans every station's lane
	-- AND both banks, which is the identity `range.spec` asserts (design 5.2). 10 studs = 2.8 m,
	-- "not high" (Karen), inside the 6 m upper bound the note refused to treat as a requirement.
	-- `behindStuds` 13 AND NOT 12, so the berm's rectangle is on the terrain grid in all FOUR
	-- edges: the centre sits `distanceMax + 13` = 192 from the anchor and `depth` 8 puts its faces
	-- at 188 and 196, both multiples of `FILL.GRID_STUDS` (design 5.4). At 12 they were 187 and 195.
	-- `slopeRun` and `slopeSteps` ARE THE UPRANGE FACE (step B8). A rectangular block of earth is
	-- a wall; Karen asked for *"a mountain not high but like in real life"*, and a real berm is a
	-- trapezoid. Four 2-stud bands (10 * k / 5) over a 12-stud run is a 1:1.2 batter, and 2 studs
	-- per step is design 8.2's decided fallback for the unverified `FillWedge`. Only the terrain arm
	-- reads them -- a part berm is one box, as it was.
	BERM = {
		height = 10,
		depth = 8,
		behindStuds = 13,
		slopeRun = 12,
		slopeSteps = 4,
		color = Color3.fromRGB(104, 84, 62),
	},
	MAT = { size = Vector3.new(8, 1, 8), color = Color3.fromRGB(70, 82, 70) },
	-- THE WAY IN STANDS WHERE SHE IS LOOKING. A ProximityPrompt is drawn only while its own
	-- position is on screen, so one hung on the 8x8 mat under her feet is invisible down the lane
	-- and E does nothing (Director's real-key proof, 2026-10-28, frames 03/04/06).
	-- `Lobby.Build.shopPrompt` already solved this: the prompt sits on a PART at chest height on the
	-- customer's side. `aheadStuds` puts the post past the mat's front edge and `sideStuds` holds it
	-- out of the lane of fire -- a target at the window's far end subtends 1.9 studs of X at this
	-- post's Z, and the post stands at 3.
	POST = {
		size = Vector3.new(1.2, 4, 1.2),
		aheadStuds = 7,
		sideStuds = 3,
		color = Color3.fromRGB(88, 76, 58),
	},
	-- THE TREESTAND, AS DATA (Karen, 2026-10-28: *"we can make an option shoot from treestand so
	-- they can shoot from ground or treestand"*). `backStuds` puts the deck UPRANGE of the mat, so
	-- a shot off the deck is 14 studs LONGER and `Range.distanceFor` says so; `facing` is
	-- `HighSeats.facingOf`'s sign for a lane that runs SOUTH (`downrange` -1, design 5.4's frame)
	-- and `Range.standFacing` turns it with the row, so the ladder and the rail's gap are UPRANGE
	-- in BOTH worlds and the solid rail board is the rest downrange; `promptRise` is the rail's own
	-- top (`HighSeats.DIMS.RAIL_RISE_STUDS`). Nothing about the seat is re-derived here.
	STAND = { backStuds = 14, facing = -1, promptRise = 2.4 },
	-- THE GROUND POSITION'S REST: a 0.7-0.8 m bench top (ISSF/BSRC) is 2.5-2.9 studs, and
	-- `aheadStuds` puts it between the man and his post, downrange of the mat.
	-- `color` AND `material` BOTH, SINCE STEP B10: the box read as a brown slab in her place
	-- (evidence/306b8/f2b-lane1-view.png). Size and position are UNCHANGED -- a bench top is a
	-- gameplay number (the 0.7-0.8 m rest) and B10 moves none of them (note 8.3 L1).
	BENCH = {
		size = Vector3.new(6, 2.7, 1.2),
		aheadStuds = 3.5,
		color = Color3.fromRGB(150, 118, 78),
		material = Enum.Material.WoodPlanks,
	},
	-- ------------------------------------------------------------------- THE LOOK (step B10)
	-- Karen, 2026-10-28: *"make nice shooting range clean proper like in real life"*. Research note
	-- docs/research/2026-10-28-the-range-in-the-lobby.md section 8 (refs 1, 5, 7 and the deviations).
	-- NOT ONE GAMEPLAY NUMBER IS IN HERE (8.3 L1): the mats, posts, benches, decks, prompts, window,
	-- distances, banks and berm keep the values B2-B9 measured, and all of this is laid AROUND them.
	--
	-- THE ROOFED FIRING POINT: four corner posts and a flat roof over the mat, the bench and the
	-- prompt post -- ref-1's firing hut, ref-5's roofed line. `roofRise` is the roof's BOTTOM above
	-- the shelf; 8.3 L2 is the bound it answers.
	HUT = {
		roofSize = Vector3.new(13, 0.6, 15),
		roofRise = 9,
		-- the roof's centre DOWNRANGE of the mat, so its span covers the bench (3.5) and the prompt
		-- post (7) and still stops 6.5 studs short of the treestand's deck 14 uprange.
		roofAheadStuds = 3,
		postSection = 0.9,
		-- THE STATION'S NUMBER, on the UPRANGE fascia: the face a man walking down from the lodge
		-- reads. A `SurfaceGui` draws the digit, so there is no decal id and nothing to upload.
		boardSize = Vector3.new(3.2, 2.2, 0.25),
		boardRise = 6.4,
		roofColor = Color3.fromRGB(96, 72, 52),
		postColor = Color3.fromRGB(136, 110, 80),
		boardColor = Color3.fromRGB(236, 232, 220),
		boardTextColor = Color3.fromRGB(32, 32, 32),
	},
	-- THE MOWN LANE, AS ONE DECORATIVE PART. A BasePart's `Grass` material is a flat texture with no
	-- blades -- blades are the TERRAIN renderer's, which is the whole of B8's measured objection --
	-- so this is green grass that cannot hide the target. `CanCollide` and `CanQuery` are both false
	-- in `Build`: a ray and a body pass straight through, so no shot, no route and no walk moves.
	TURF = {
		thickness = 0.6,
		-- the slab's TOP above the shelf: just proud of the voxel surface, so no terrain shows through
		liftStuds = 0.12,
		color = Color3.fromRGB(106, 140, 74),
		material = Enum.Material.Grass,
	},
	-- THE LOT'S LOW RAIL FENCE (ref-5), ON THE BERM'S OWN SPAN IN X -- which is the corridor plus
	-- both banks in full (`bermWidthFor`), so the line is 18 studs outside the corridor's end and
	-- nothing on it is in any line of fire.
	FENCE = {
		postSection = 0.7,
		postRise = 3.2,
		spacingStuds = 24,
		-- POSTS AND NO RAIL, and that is a MEASUREMENT (her place, census 2026-10-29). The lot's two
		-- long sides stand 18 studs outside the corridor, which is OFF the cut terrace and on the
		-- hill: the measured ground falls 150 -> 158 -> 154 along the east line. A post follows that;
		-- one 155-stud board cannot, and `FenceRail3` stood 10 studs proud of the ground at one end.
		-- The dispatch allows either -- *"a low wooden fence OR POSTS along the sides"*.
		--
		-- AND A POST ON A STEP IS REFUSED, which is `HighSeats.MAX_FOOT_SPREAD_STUDS`' own rule and
		-- its own reason: the terrace's edge is a 9-stud step, and the one post whose five footprint
		-- samples straddled it stood 7.5 studs in the air (`FencePost3_7`).
		maxSpreadStuds = 2.0,
		-- PULLED INSIDE THE TERRACE BY A STUD, AND THAT IS A MEASURED REQUIREMENT, not a margin for
		-- looks: `range.spec` asserts that EVERY part of the range stands inside the ground the cut
		-- wrote, and the cut's X edges ARE the berm's span -- so a post centred on that edge hangs
		-- half its section over the lip of the terrace.
		insetStuds = 1.0,
		color = Color3.fromRGB(128, 104, 76),
		material = Enum.Material.Wood,
	},
	-- THE WAY UP AND THE WAY DOWN (dispatch item 6; note 8.2). B9 measured twice that a real `W` at
	-- the `TrussPart` never climbs, so the climb is a prompt that MOVES the character.
	-- E UP, F DOWN, AND THE SECOND KEY IS A MEASUREMENT: a man on the deck is inside
	-- `MaxActivationDistance` of this prompt AND of the station's existing RANGE prompt, and
	-- `ProximityPrompt.Exclusivity` defaults to `OnePerButton` -- one prompt per key, the closest --
	-- so two E prompts on one deck is a coin toss about which door the key opens.
	--   https://create.roblox.com/docs/reference/engine/enums/ProximityPromptExclusivity
	CLIMB = {
		UP_ACTION = "Climb",
		DOWN_ACTION = "Climb down",
		OBJECT_TEXT = "TREESTAND",
		UP_KEY = Enum.KeyCode.E,
		DOWN_KEY = Enum.KeyCode.F,
		MaxActivationDistance = 10,
		HoldDuration = 0,
		-- the prompt POINTS: chest height at the ladder's foot, and a stud and a half over the deck
		footRise = 3.0,
		deckRise = 1.6,
		-- HOW HIGH A BODY SITS over what it stands on. `Match.CONFIG.STAND_HEIGHT_STUDS`' own 3.5,
		-- restated and not required: the lobby's range reaches into no hunt module (this file's head).
		riseStuds = 3.5,
		-- THREE STUDS UPRANGE OF THE LADDER'S CENTRE, and 3 and not 1 is a MEASUREMENT (her place,
		-- real `F`, 2026-10-29): the ladder is 2 studs deep, so at 1 the step-off point was exactly
		-- on its edge -- the place's ground reader raycast down, hit the LADDER'S OWN TOP at 163.2
		-- and put the man back up in the air at 166.6. At 3 the point is 2 studs clear of the
		-- ladder's face, and still inside `standReach`'s footprint box.
		footClearStuds = 3.0,
	},
	PLATE = { minSpan = 120, marginStuds = 80, thickness = 4, color = Color3.fromRGB(150, 150, 150) },
	-- THE TERRAIN GRID. `Terrain:FillBlock` writes 4-stud voxels on a grid anchored at the world
	-- origin, so every rectangle edge is a multiple of this or voxels stand at it (task 191's
	-- measured lesson, `Lobby.CONFIG.FIELD.PADS`). `DEPTH_STUDS` and `CLEAR_STUDS` are read by the
	-- terrain writer in her place (design 8).
	FILL = { DEPTH_STUDS = 48, CLEAR_STUDS = 96, GRID_STUDS = 4 },
	-- THE TWO SURFACES, AND DESIGN 8.3's PAIR WAS REFUTED BY THE PICTURE (step B8, photographed in
	-- her place: evidence/306b8/f6-berm-view.png). 8.3 chose `Grass` for the lane against the hill's
	-- `LeafyGrass` -- short grass beside long. Two measurements say that pair cannot work here:
	--   * the ground just outside the terrace at (2800, -3120) reads `Grass` ALREADY, not
	--     `LeafyGrass`, so there is no long grass for a short lane to read against;
	--   * `Grass` DRAWS BLADES, and from a man's eye on the bench (y 153) they fill the whole frame
	--     -- no lane, no berm, no range. Karen asked for *"nice shooting range clean proper like in
	--     real life"* and a lane you cannot see over is the opposite of it.
	-- So the lane is `Ground`: blade-free, which is the EXACT reason `Lobby.CONFIG.FIELD.PADS` uses
	-- it under the yard and the road (*"a block of a material with no grass blades"*), and in
	-- `Places.Ground`'s accepted list like the rest. It reads as a groomed lane against her hill's
	-- own grass, which is the contrast 8.3 wanted and a Grass-on-Grass pair could not give.
	-- `AROUND` is now what her hill MEASURES as, not what the design assumed, so the repaint that
	-- catches what the fill could not reach is aimed at a material that is actually there.
	-- `Limestone` is pale crushed stone, in that same accepted list, and Karen's to overrule.
	-- The strip's three reaches cover every part on the line: the post sits 7.6 studs downrange of
	-- the anchor, the deck 14 uprange, and the mats span 2596..2724 for a six-station row.
	SURFACE = {
		LANE = Enum.Material.Ground,
		-- THE BERM AND THE TWO BANKS ARE GRASSED EARTH (step B10, Karen: *"behind animal could be a
		-- mountain ... or some earth formed mountain"*; refs 3 and 5). Terrain `Grass` DOES draw
		-- blades and that is why the LANE is not grass -- but these stand 190 studs downrange, where
		-- B8's measurement (blades filling the frame from the bench) does not apply, and blades are
		-- what makes a heap of soil read as a hill rather than as a brown wall.
		BERM = Enum.Material.Grass,
		AROUND = Enum.Material.Grass,
		LINE = Enum.Material.Limestone,
		LINE_AHEAD_STUDS = 10,
		LINE_BACK_STUDS = 14,
		LINE_SIDE_STUDS = 8,
		-- `Lobby.CONFIG.FIELD.CHUNK_STUDS`' own value and its own reason: `MapGen.Ground` measured a
		-- per-region voxel ceiling in this Studio version, so a fill is chunked whatever the
		-- `FillBlock` ceiling turns out to be.
		CHUNK_STUDS = 64,
	},
	-- THE FLAT TERRACE (design 8.4), as the two reaches past what stands on it: `uprangeStuds` past
	-- the anchor behind the seat's feet, `downrangeStuds` past the berm's far face. Its X is the
	-- berm's own derived span, so the cut can never be narrower than what is built on it.
	CUT = { uprangeStuds = 34, downrangeStuds = 2 },
	PROMPT = {
		ActionText = "RANGE",
		ObjectText = "SHOOTING RANGE",
		MaxActivationDistance = 12,
		HoldDuration = 0,
	},
}

-- A WORLD HAS A RANGE WHEN, AND ONLY WHEN, THERE IS A ROW FOR IT -- `Lobby.anchorFor`'s rule
-- verbatim, and for its stated reason: the answer is never found by sniffing `Workspace`, because
-- *"a predicate like that lies the moment a run half-finishes"* (`ArenaBoot`).
--
--
-- `downrange` IS THE LANE'S DIRECTION ALONG Z, AS DATA ON THE ROW and never a branch on the world's
-- name: one arithmetic, two signs, both reachable in a spec by parameter. +1 is the DEV row's north.
Range.ANCHORS = {
	-- KAREN'S PLACE, RE-MEASURED FOR SIX STATIONS (step B8, design 2.1). The B6 anchor (2650, -3216)
	-- was chosen for ONE station over a 160 x 185 footprint; six stations plus the treestand need
	-- 256 x 239, and Karen on 2026-10-28 wanted the range *"in lobby / people don't have to walk
	-- far"*. (2600, -3030) is 186.7 walked studs from the lodge door and shoots SOUTH, away from the
	-- lodge, the road, the yard, the trucks, the spawn, the gathering yard and the drive.
	-- MEASURED IN HER PLACE 2026-10-29 (evidence/306b8/census.txt): 0 BaseParts in the footprint,
	-- 990 ground samples, 0 missed, ground spread 33.0 studs and 23.5 across the firing line alone
	-- -- which is why `fill = true` exists and why nothing here is laid on natural ground.
	-- The row BEFORE this step is archived at backups/task-306b8/ (rule 7).
	--
	-- `berm = "terrain"` and `fill = true` ARE DATA, NEVER A BRANCH ON THE WORLD'S NAME (design 8.1):
	-- both arms are reachable in `range.spec` by parameter.
	-- `shelfFrom` IS THE LOBBY'S OWN ANCHOR, and it is the whole of the level walk. Read through the
	-- same `groundAt` and snapped by the same floor-to-grid rule as `Lobby.Field.shelfFor`, it
	-- resolves to the lobby's own shelf (148, measured) -- so the range terrace and the lodge yard
	-- are ONE terrace and a man walks from the door to the mat without a step. The ground at the
	-- range anchor reads 134.87, which snaps to a shelf of 132 -- a 16-stud step across her path
	-- (measured 2026-10-29, evidence/306b8/profile.txt).
	-- `keepOut` IS THE LOBBY FIELD'S WEST AND SOUTH EDGES (x 2740, z -3060, from `Lobby.CONFIG.FIELD`):
	-- north of that z the cut stops at that x, so the two terraces meet FLUSH on one voxel plane and
	-- neither writes the other's ground. `range.spec` asserts the pair against `Lobby`'s own config.
	["forest-test"] = {
		x = 2600,
		z = -3030,
		plate = false,
		downrange = -1,
		drawn = true,
		berm = "terrain",
		fill = true,
		shelfFrom = { x = 2850, z = -2950 },
		keepOut = { x = 2740, z = -3060 },
	},
	-- The DEV place, where the harness runs. Its own anchored ground plate (`plate = true`), clear
	-- of the generated map: x = 1200 is outside `Map.FIELD.bounds` (maxX 620) and outside
	-- `Map.SIZE_STUDS / 2` = 1024, so it touches neither the drive corridor nor one generated prop.
	-- `berm = "parts"` and `fill = false` SPELLED OUT and not defaulted, so the two arms read as one
	-- table with two values rather than as a row with a hole in it.
	["map:v1"] = { x = 1200, z = 0, y = 0, plate = true, berm = "parts", fill = false },
}

-- IS THE BERM EARTH OR A PART? DATA ON THE ROW (design 8.1), defaulted to parts so every row
-- written before this step keeps the berm it had.
function Range.bermIsTerrain(row: any): boolean
	return type(row) == "table" and row.berm == "terrain"
end

-- DOES THIS WORLD'S RANGE CUT ITS OWN GROUND FLAT? Same shape, same default: no.
function Range.fillsTerrain(row: any): boolean
	return type(row) == "table" and row.fill == true
end

-- WHICH WAY IS DOWNRANGE: +1 or -1 along z, read off the row and defaulted to +1 so every row
-- written before step B6 keeps the lane it had.
function Range.downrangeOf(row: any): number
	if type(row) == "table" and row.downrange == -1 then
		return -1
	end
	return 1
end

function Range.anchorFor(world: string?)
	if type(world) ~= "string" then
		return nil
	end
	local row = Range.ANCHORS[world]
	if row == nil then
		return nil
	end
	return table.clone(row)
end

-- THE ONE WHITELIST, read by both sides (`Lobby.roleAllowed`'s shape).
function Range.paceAllowed(word: any): boolean
	if type(word) ~= "string" then
		return false
	end
	for _, allowed in pairs(Range.WORD) do
		if word == allowed then
			return true
		end
	end
	return false
end

-- THE PACE ROWS THE MENU OFFERS, IN THE ORDER IT OFFERS THEM. Karen, 2026-10-27: *"animals and
-- speed (walk trot stand run)"* -- four words, STAND among them (design 7.3 lists three).
-- STAND is first because it isolates AIM from LEAD, which is what a man starts with.
-- Karen's four FIRST and unmoved (design 6); ISSF's two and `mixed` follow them.
Range.PACE_ORDER = {
	Range.WORD.STAND,
	Range.WORD.WALK,
	Range.WORD.TROT,
	Range.WORD.RUN,
	Range.WORD.SLOW,
	Range.WORD.FAST,
	Range.WORD.MIXED,
}

-- THE TIME A TIMED PACE IS SPECIFIED BY, and nil for a word that is not one of the two. That nil
-- is what routes Karen's four to the injected animal owner.
function Range.crossingTargetSeconds(word: any): number?
	local seconds = if type(word) == "string" then Range.CROSSING_SECONDS[word] else nil
	if type(seconds) ~= "number" or seconds <= 0 then
		return nil
	end
	return seconds
end

-- WHICH OF THE TWO A `mixed` LEG DRAWS. Pure when a roll is handed in, so a spec drives both arms;
-- ISSF draws it per run and does NOT announce it, which is why the board prints the issued SPEED
-- and never a second word.
function Range.mixedWord(roll: number?): string
	local value = if type(roll) == "number" then roll else math.random()
	return if value < 0.5 then Range.WORD.SLOW else Range.WORD.FAST
end

-- THE ONE ANSWER TO "HOW FAST IS THIS PACE" (design 6). Karen's four delegate to the INJECTED
-- `Boar.paceSpeed`, so the range still invents no animal speed; the two timed paces divide the
-- window by their time; `mixed` draws one of those two.
--
-- HONEST, AND MEASURED (306a note (a)): both new speeds land inside the boar's ONE TROT band
-- (`Body.gait` trots from `MODEL.TROT_FROM` 5.13 and runs from `RUN_FROM` -- 28 in the module,
-- 21 where a world lowers it), so 7.20 and 14.40 are one trot clip at two rates, not two gaits.
function Range.paceSpeedFor(word: string, layout, boarPaceSpeed: ((string) -> number)?): number
	layout = layout or Range.LAYOUT
	local asked = if word == Range.WORD.MIXED then Range.mixedWord() else word
	-- 36 / 5.0 = 7.20 studs/s and 36 / 2.5 = 14.40 studs/s, so the crossing is EXACT by
	-- construction (306a must-fix (b): the note's 7.14 / 14.29 came from the unrounded
	-- 35.714-stud window, which the design's own column header never used).
	local seconds = Range.crossingTargetSeconds(asked)
	if seconds ~= nil then
		return layout.WINDOW_STUDS / seconds
	end
	if boarPaceSpeed == nil then
		return 0
	end
	return boarPaceSpeed(asked) or 0
end

-- THE TWO FIRING POSITIONS, AND THE FIRING POSITION IS NOT A MENU PICK: it is where he is standing,
-- measured off the character the SERVER can see (`Range.mayShoot`'s own discipline, design 7.3).
-- `RangeRequest` carries no position, so a client cannot claim one.
Range.POSITION = { BENCH = "bench", TREESTAND = "treestand" }

-- THE DISTANCES THE MENU OFFERS -- the layout's own list and never a second copy of it, because
-- `Build` lays the banks and the berm at the LONGEST of them and the menu may only offer a lane
-- that is built (design 5.1).
Range.DISTANCES_STUDS = Range.LAYOUT.DISTANCES_STUDS

-- THE LONGEST LANE: what the banks, the berm, the field and the plate are sized to.
function Range.distanceMax(layout): number
	layout = layout or Range.LAYOUT
	local most = layout.DISTANCE_STUDS
	for _, studs in ipairs(layout.DISTANCES_STUDS) do
		most = math.max(most, studs)
	end
	return most
end

-- THE LANE A TRIAL RUNS, defaulted so a caller with no pick gets the distance the menu opens on.
function Range.distanceStudsOr(layout, distanceStuds: number?): number
	layout = layout or Range.LAYOUT
	return if type(distanceStuds) == "number" then distanceStuds else layout.DISTANCE_STUDS
end

-- ...and the general door, so steps B3 and B4 have one place to ask. An unknown KIND is false and
-- never true: a whitelist whose default is "yes" is not a whitelist.
--
-- `lists` is the server's own published option lists (`{ species, kinds, weapons, ammo }`). The
-- SPECIES and the KINDS are the animal owner's and cross the wire; the client sender asks this of
-- its own argument and the server's door asks it of the payload -- `Lobby.roleAllowed`'s rule, one
-- answer to "which words are legal". With no lists, a species or a kind is REFUSED, not assumed.
function Range.optionAllowed(kind: string, value: any, lists: any?): boolean
	if kind == "pace" then
		return Range.paceAllowed(value)
	elseif kind == "spot" then
		return type(value) == "number"
			and value == math.floor(value)
			and value >= 1
			and value <= Range.LAYOUT.SPOT_COUNT
	elseif kind == "weapon" then
		return type(value) == "string" and Weapons.row(value :: any) ~= nil
	elseif kind == "ammo" then
		-- A CARTRIDGE IS ONLY LEGAL FOR THE GUN THAT REALLY CARRIES IT (design 7.3): the pick is
		-- read against `Weapons.row(weapon).AMMO_KINDS`, the same pair the Hud's ammo chip reads.
		if type(value) ~= "string" then
			return false
		end
		local weapon = if type(lists) == "table" then (lists :: any).weapon else nil
		local row = Weapons.row(weapon :: any)
		if row == nil or type(row.AMMO_KINDS) ~= "table" then
			return false
		end
		for _, allowed in ipairs(row.AMMO_KINDS) do
			if value == allowed then
				return true
			end
		end
		return false
	elseif kind == "species" or kind == "kind" then
		local field = if kind == "species" then "species" else "kinds"
		local offered = if type(lists) == "table" then (lists :: any)[field] else nil
		if type(value) ~= "string" or type(offered) ~= "table" then
			return false
		end
		for _, allowed in ipairs(offered) do
			if value == allowed then
				return true
			end
		end
		return false
	elseif kind == "distanceStuds" then
		if type(value) ~= "number" then
			return false
		end
		for _, allowed in ipairs(Range.DISTANCES_STUDS) do
			if value == allowed then
				return true
			end
		end
		return false
	end
	return false
end

-- THE SIGNED MISS GAP, IN METRES, IN KAREN'S OWN WORDS, 2026-10-27: *"0.9 m behind"* /
-- *"0.4 m ahead"*. `Report.CONFIG.METRES_PER_STUD` IS THE CONVERSION -- this file holds no second
-- copy of 0.28 (`MapUi`'s stated rule). `Report.metres` rounds to a whole metre, which would print
-- every gap under half a metre as "0 m", so the tenth is taken from the same constant.
function Range.gapText(studs: number?): string
	if type(studs) ~= "number" or studs ~= studs then
		return "--"
	end
	local metres = studs * Report.CONFIG.METRES_PER_STUD
	local tenths = math.floor(math.abs(metres) * 10 + 0.5) / 10
	if tenths == 0 then
		return "0.0 m on"
	end
	return string.format("%.1f m %s", tenths, if metres < 0 then "behind" else "ahead")
end

-- IS HE AT THE SPOT? PURE, and the distance is the PROMPT'S OWN REACH -- the same number the engine
-- shows the prompt at, so the menu closes exactly where the way in disappears (`Shop.withinReach`'s
-- rule: the client's closer and the server's refusal are the same measurement).
--
-- IT IS ASKED ABOUT THE PROMPT'S OWN POINT, not the mat's (task 303). Since the prompt stands on
-- the post, measuring from the mat would leave a shell where the engine offers E and this says no.
function Range.atSpot(promptPosition: Vector3?, playerPosition: Vector3?, layout): boolean
	layout = layout or Range.LAYOUT
	if typeof(promptPosition) ~= "Vector3" or typeof(playerPosition) ~= "Vector3" then
		return false
	end
	return (promptPosition - playerPosition).Magnitude <= layout.PROMPT.MaxActivationDistance
end

-- A DISTANCE AS THE PLAYER READS IT: "125 studs (35 m)", through `Report.metres` -- the repo's one
-- conversion, so the menu and the board cannot disagree about how far 125 studs is.
function Range.distanceText(studs: number?): string
	local value = if type(studs) == "number" then studs else 0
	return string.format("%d studs (%d m)", math.floor(value + 0.5), Report.metres(value))
end

-- WHICH GUNS AND WHICH CARTRIDGES THE MENU OFFERS, read from the shipped tables and never typed
-- here (design 7.3). The server sends the animal's lists; these two are shared, so both sides read
-- the same rows.
function Range.weaponRows(): { { id: string, label: string, ammo: { string }, ammoLabel: { [string]: string } } }
	local out = {}
	for _, id in ipairs(Weapons.ORDER) do
		local row = Weapons.row(id :: any)
		if row ~= nil then
			table.insert(out, {
				id = id,
				label = tostring(row.label or row.toolName or id),
				ammo = table.clone(row.AMMO_KINDS or {}),
				ammoLabel = table.clone(row.AMMO_LABEL or {}),
			})
		end
	end
	return out
end

-- THE TWO REMOTES, resolved once and cached -- `Shop.remotes`' shape exactly, including the
-- `WaitForChild`, because a client that requires this module before replication finishes must wait
-- rather than read nil.
local remotes: { RangeRequest: RemoteEvent, RangeBoard: RemoteEvent }? = nil

Range.REQUEST_REMOTE = "RangeRequest"
Range.BOARD_REMOTE = "RangeBoard"

function Range.remotes(): { RangeRequest: RemoteEvent, RangeBoard: RemoteEvent }
	local cached = remotes
	if cached ~= nil then
		return cached
	end
	local folder = ReplicatedStorage:WaitForChild(Range.FOLDER_NAME):WaitForChild(Range.REMOTES_NAME)
	local built = {
		RangeRequest = folder:WaitForChild(Range.REQUEST_REMOTE) :: RemoteEvent,
		RangeBoard = folder:WaitForChild(Range.BOARD_REMOTE) :: RemoteEvent,
	}
	remotes = built
	return built
end

-- EVERY STATION'S PART NAMES, IN ONE PLACE. Six stations means six of each, so the name carries the
-- number -- and `Build` lays them from these, the Hud finds the prompt by `promptName`, and the
-- spec asks for them the same way.
function Range.matName(spot: number): string
	return Range.MAT_NAME .. tostring(spot)
end

function Range.postName(spot: number): string
	return "Post" .. tostring(spot)
end

-- WHICH PROMPT: the bench's post or the stand's rail. One stem per POSITION and the spot appended,
-- so `RangePrompt3` and `RangeStandPrompt3` are two names and never one with a flag on it. nil (and
-- any other word) is the bench, which is the one-position answer this file shipped with.
function Range.promptName(spot: number, position: string?): string
	local stem = if position == Range.POSITION.TREESTAND then Range.STAND_PROMPT_NAME else Range.PROMPT_NAME
	return stem .. tostring(spot)
end

function Range.standName(spot: number): string
	return "Stand" .. tostring(spot)
end

function Range.benchName(spot: number): string
	return "Bench" .. tostring(spot)
end

function Range.bankName(leg: number): string
	return if (leg % 2) == 1 then "BankEast" else "BankWest"
end

-- THE PROMPT, BY NAME ANYWHERE UNDER `Workspace.Range` (`Lobby.Data.shopPrompt`'s shape): the
-- client finds it, `Hud.step` hands it to the panel. nil when the range is not built.
function Range.promptFor(spot: number, position: string?, root: Instance?): any
	local parent = root or (game:GetService("Workspace"):FindFirstChild(Range.FOLDER_NAME))
	if parent == nil then
		return nil
	end
	local wanted = Range.promptName(spot, position)
	for _, child in ipairs(parent:GetDescendants()) do
		if child.Name == wanted then
			return child
		end
	end
	return nil
end

-- THE NEAREST WAY IN, AND WHICH STATION IT BELONGS TO. ONE walk of the folder for all twelve
-- prompts -- six benches and six decks -- so the Hud asks "which prompt is he standing at" instead
-- of asking for station 1's by name. nil position (no character yet) is no measurement and no
-- answer, and NEITHER IS ONE OUT OF REACH: the cap is the prompt's own `MaxActivationDistance`, the
-- same number `atSpot` measures with, so the panel is never told a station he is nowhere near.
-- Note: docs/design/shooting-range-lobby.md section 7.3
function Range.nearestPrompt(position: Vector3?, root: Instance?, layout): (any?, number?, string?)
	layout = layout or Range.LAYOUT
	local parent = root or (game:GetService("Workspace"):FindFirstChild(Range.FOLDER_NAME))
	if parent == nil or typeof(position) ~= "Vector3" then
		return nil, nil, nil
	end
	local wanted: { [string]: { spot: number, position: string } } = {}
	for spot = 1, layout.SPOT_COUNT do
		for _, word in ipairs({ Range.POSITION.BENCH, Range.POSITION.TREESTAND }) do
			wanted[Range.promptName(spot, word)] = { spot = spot, position = word }
		end
	end
	local best: any, bestSpot: number?, bestWord: string?, bestAt = nil, nil, nil, layout.PROMPT.MaxActivationDistance
	for _, child in ipairs(parent:GetDescendants()) do
		local row = wanted[child.Name]
		if row ~= nil then
			local point = Range.promptPointOf(child)
			if point ~= nil then
				local far = ((point :: Vector3) - (position :: Vector3)).Magnitude
				if far <= bestAt then
					best, bestSpot, bestWord, bestAt = child, row.spot, row.position, far
				end
			end
		end
	end
	return best, bestSpot, bestWord
end

-- THE LANE, AND ITS ONE ARITHMETIC. An odd leg runs to the east end and an even leg back to the
-- west: ISSF's mandatory direction change (design section 14, source 1), which is the whole reason
-- a lane that only ever ran one way trains one lead.
function Range.laneLength(layout): number
	layout = layout or Range.LAYOUT
	return layout.WINDOW_STUDS + 2 * layout.APRON_STUDS
end

-- HOW FAR EAST THE SIXTH MAT STANDS FROM THE FIRST: the span the stations occupy along X, which
-- every derived width below is measured from.
function Range.spotSpan(layout): number
	layout = layout or Range.LAYOUT
	return (layout.SPOT_COUNT - 1) * layout.SPOT_SPACING_STUDS
end

-- THE LANE IS PER STATION: each window is centred on its OWN mat, so for every one of the six the
-- crossing is perpendicular to the range and the ballistic lead and the measured crossing stay
-- about different axes (design 5.3). `spot` and `distanceStuds` default to station 1 and the
-- opening distance, which is the one-station answer this file shipped with.
function Range.laneCentre(anchor: Vector3, layout, downrange: number?, spot: number?, distanceStuds: number?): Vector3
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local mat = Range.matPosition(anchor, spot or 1, layout)
	return Vector3.new(mat.X, anchor.Y, anchor.Z + dir * Range.distanceStudsOr(layout, distanceStuds))
end

-- ONE STATION'S OWN WINDOW, IN X. The opening is centred on the mat, so it is the same span at all
-- three distances -- the lane only moves in Z. ONE predicate for the two sides that must agree: the
-- shot's ignore list (design 4.3) and the client mask's picture (4.4).
-- Note: docs/design/shooting-range-lobby.md sections 4.3, 5.3
function Range.windowSpanFor(anchor: Vector3, spot: number, layout): (number, number)
	layout = layout or Range.LAYOUT
	local mat = Range.matPosition(anchor, spot, layout)
	local half = layout.WINDOW_STUDS / 2
	return mat.X - half, mat.X + half
end

-- IS THIS X INSIDE THAT WINDOW? Both edges count (`<=`, the repo's rule), and a nil X -- no animal,
-- or no history for the instant asked about -- is NOT in the window, which is the safe answer: the
-- shot then cannot see it either.
function Range.inWindow(minX: number, maxX: number, x: number?): boolean
	if type(x) ~= "number" then
		return false
	end
	return x >= minX and x <= maxX
end

function Range.laneEnds(
	anchor: Vector3,
	layout,
	leg: number,
	downrange: number?,
	spot: number?,
	distanceStuds: number?
): Vector3
	layout = layout or Range.LAYOUT
	local centre = Range.laneCentre(anchor, layout, downrange, spot, distanceStuds)
	local half = Range.laneLength(layout) / 2
	local east = (leg % 2) == 1
	return Vector3.new(centre.X + (if east then half else -half), centre.Y, centre.Z)
end

-- THE SIX WINDOWS SHARE ONE CORRIDOR (design 5.3), and this is its two ends in X, as offsets from
-- the anchor: station 1's west apron edge and station 6's east one. The banks stand beyond THESE,
-- not beyond any one station's lane.
function Range.corridorSpan(layout): (number, number)
	layout = layout or Range.LAYOUT
	local half = Range.laneLength(layout) / 2
	return -half, Range.spotSpan(layout) + half
end

-- HOW FAR PAST THE CORRIDOR'S END A BANK'S OUTER FACE STANDS. `beyondStuds` is the clearance to the
-- bank's NEAR face (the measured turn-around), so the outer face is a whole bank further on. This
-- is the number 306a(c) found the berm 4 studs short of: the old formula used the bank's CENTRE.
function Range.bankReach(layout): number
	layout = layout or Range.LAYOUT
	return layout.BANK.beyondStuds + layout.BANK.size.X
end

-- WHERE A BANK STANDS. Leg 1 is the east bank and leg 2 the west, each beyond the CORRIDOR's end,
-- at the LONGEST lane's Z -- so what they hide is the turn-around of the deepest trial, and the
-- shorter lanes stand in front of them with no cover of their own (design 5.3, source D's 30 m).
function Range.bankPosition(anchor: Vector3, layout, leg: number, downrange: number?): Vector3
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local west, east = Range.corridorSpan(layout)
	local sign = if (leg % 2) == 1 then 1 else -1
	local from = if sign == 1 then east else west
	local offset = from + sign * (layout.BANK.beyondStuds + layout.BANK.size.X / 2)
	return Vector3.new(anchor.X + offset, anchor.Y, anchor.Z + dir * Range.distanceMax(layout))
end

-- A BANK'S TWO FACES IN X, so the berm identity is asserted against the same arithmetic that
-- places it and not against a typed pair of numbers.
function Range.bankSpanFor(anchor: Vector3, layout, leg: number): (number, number)
	layout = layout or Range.LAYOUT
	local at = Range.bankPosition(anchor, layout, leg)
	local half = layout.BANK.size.X / 2
	return at.X - half, at.X + half
end

-- THE BERM'S WIDTH IS DERIVED, NEVER TYPED (design 5.2): the corridor plus both banks in full,
-- rounded UP onto the terrain grid so her place's fill leaves no voxel standing at the edge.
-- A typed 160 would have left stations 5 and 6 shooting past its east end.
function Range.bermWidthFor(layout): number
	layout = layout or Range.LAYOUT
	local grid = layout.FILL.GRID_STUDS
	local raw = Range.spotSpan(layout) + Range.laneLength(layout) + 2 * Range.bankReach(layout)
	return math.ceil(raw / grid) * grid
end

function Range.bermSizeFor(layout): Vector3
	layout = layout or Range.LAYOUT
	return Vector3.new(Range.bermWidthFor(layout), layout.BERM.height, layout.BERM.depth)
end

-- THE BERM IS CENTRED ON THE STATIONS, not on the anchor: with six of them the anchor is the WEST
-- end of the firing line, so a berm centred there would stop halfway along it.
function Range.bermPosition(anchor: Vector3, layout, downrange: number?): Vector3
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	return Vector3.new(
		anchor.X + Range.spotSpan(layout) / 2,
		anchor.Y,
		anchor.Z + dir * (Range.distanceMax(layout) + layout.BERM.behindStuds)
	)
end

function Range.bermSpanFor(anchor: Vector3, layout): (number, number)
	layout = layout or Range.LAYOUT
	local at = Range.bermPosition(anchor, layout)
	local half = Range.bermWidthFor(layout) / 2
	return at.X - half, at.X + half
end

function Range.matPosition(anchor: Vector3, spot: number, layout): Vector3
	layout = layout or Range.LAYOUT
	local index = math.max(1, math.floor(spot or 1))
	local offset = (index - 1) * layout.SPOT_SPACING_STUDS
	return Vector3.new(anchor.X + offset, anchor.Y, anchor.Z)
end

-- WHERE THE PROMPT HANGS: the top of the post at the mat's front edge, and the ONE arithmetic for
-- it -- `Range.Build` lays the post from this and the client case projects this, so the screen's
-- claim and the built world can never be about two different points. Y is the SHELF plus the post's
-- height, while the BUILT top is the HIGHEST ground under the post's own footprint plus that same
-- height: over a plate (DEV) they are one point, and over terrain they differ by that ground
-- against the shelf read at the row's own point.
function Range.promptPosition(anchor: Vector3, spot: number, layout, downrange: number?, position: string?): Vector3
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local mat = Range.matPosition(anchor, spot, layout)
	-- THE STAND'S OWN PROMPT: on the rail's top on the UPRANGE face, which is the face the ladder
	-- and the rail's gap are on -- so a man stepping off the ladder is already at it, and a man on
	-- the mat 21 studs away is not (design 7.3).
	if position == Range.POSITION.TREESTAND then
		local deck = Range.standPosition(anchor, spot, layout, dir)
		return Vector3.new(
			deck.X,
			anchor.Y + HighSeats.DIMS.DECK_RISE_STUDS + layout.STAND.promptRise,
			deck.Z - dir * HighSeats.DIMS.RAIL_PLANE_STUDS
		)
	end
	return Vector3.new(
		mat.X + layout.POST.sideStuds,
		anchor.Y + layout.POST.size.Y,
		mat.Z + dir * layout.POST.aheadStuds
	)
end

-- ----------------------------------------------------------- THE SECOND FIRING POSITION (7.1-7.3)

-- WHICH WAY THE SEAT IS TURNED, as `HighSeats.facingOf`'s own sign. `STAND.facing` is written for a
-- lane that runs SOUTH (`downrange` -1, design 5.4's frame), so it is turned WITH the row: the
-- ladder and the rail's gap end up UPRANGE in both worlds and the solid rail board is the shooting
-- rest downrange. A constant would put the ladder in front of the DEV shooter.
function Range.standFacing(layout, downrange: number?): number
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	return if layout.STAND.facing == -1 then dir else -dir
end

-- WHERE THE DECK'S CENTRE COLUMN STANDS: `backStuds` UPRANGE of the mat, so the man on it is 14
-- studs FURTHER from the target than the man on the ground and `distanceFor` says so. Y is the
-- shelf, as every other arithmetic point here: the deck's own top is `HighSeats`' business.
function Range.standPosition(anchor: Vector3, spot: number, layout, downrange: number?): Vector3
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local mat = Range.matPosition(anchor, spot, layout)
	return Vector3.new(mat.X, anchor.Y, mat.Z - dir * layout.STAND.backStuds)
end

-- THE BENCH REST, downrange of the mat and uprange of the post. Y is the bench top's own centre.
function Range.benchPosition(anchor: Vector3, spot: number, layout, downrange: number?): Vector3
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local mat = Range.matPosition(anchor, spot, layout)
	return Vector3.new(mat.X, anchor.Y + layout.BENCH.size.Y / 2, mat.Z + dir * layout.BENCH.aheadStuds)
end

-- -------------------------------------------------------------------- THE LOOK, PURE (step B10)
--
-- Every one of these is derived from a point B2-B9 already measured, so no number below can move a
-- mat, a bench, a window or a berm (note 8.3 L1). `range.spec` asserts that identity.

-- THE ROOF'S CENTRE over one station: `roofAheadStuds` downrange of the mat, at `roofRise` plus half
-- its own thickness above the shelf -- so the BOTTOM face is at `roofRise`, which is the number the
-- sight bound in 8.3 L2 is about.
function Range.hutRoofPosition(anchor: Vector3, spot: number, layout, downrange: number?): Vector3
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local mat = Range.matPosition(anchor, spot, layout)
	local hut = layout.HUT
	return Vector3.new(mat.X, anchor.Y + hut.roofRise + hut.roofSize.Y / 2, mat.Z + dir * hut.roofAheadStuds)
end

-- THE HUT'S FOUR CORNER POSTS, as x/z pairs: the roof's own corners pulled in by half a post, so no
-- post overhangs the roof it carries.
function Range.hutPostPositions(anchor: Vector3, spot: number, layout, downrange: number?): { { x: number, z: number } }
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local hut = layout.HUT
	local at = Range.hutRoofPosition(anchor, spot, layout, dir)
	local halfX = hut.roofSize.X / 2 - hut.postSection / 2
	local halfZ = hut.roofSize.Z / 2 - hut.postSection / 2
	local out = {}
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(out, { x = at.X + sx * halfX, z = at.Z + sz * halfZ })
		end
	end
	return out
end

-- THE NUMBER BOARD, on the hut's UPRANGE fascia, under the roof's own uprange edge.
function Range.boardPosition(anchor: Vector3, spot: number, layout, downrange: number?): Vector3
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local hut = layout.HUT
	local at = Range.hutRoofPosition(anchor, spot, layout, dir)
	return Vector3.new(at.X, anchor.Y + hut.boardRise, at.Z - dir * (hut.roofSize.Z / 2 - hut.boardSize.Z / 2))
end

function Range.boardName(spot: number): string
	return string.format("Board%d", math.max(1, math.floor(spot or 1)))
end

function Range.hutRoofName(spot: number): string
	return string.format("Roof%d", math.max(1, math.floor(spot or 1)))
end

function Range.hutPostName(spot: number, corner: number): string
	return string.format("HutPost%d_%d", math.max(1, math.floor(spot or 1)), corner)
end

-- WHAT THE BOARD SAYS. One place, so the spec reads the SAME answer the `SurfaceGui` is given and a
-- board printing station 4's number at station 2 is a failing case rather than a look nobody checks.
function Range.boardText(spot: number): string
	return string.format("%d", math.max(1, math.floor(spot or 1)))
end

-- THE WORST OFF-AXIS X A SIGHT LINE REACHES at `aheadStuds` downrange of the mat: the line from the
-- firing point to the far edge of the window at the SHORTEST lane, which is the widest angle this
-- range can ever ask for. Anything standing further off axis than this, at that Z, is out of every
-- line of fire at every distance (note 8.3 L2).
function Range.sightHalfWidthAt(layout, aheadStuds: number): number
	layout = layout or Range.LAYOUT
	local nearest = nil
	for _, value in ipairs(layout.DISTANCES_STUDS) do
		if type(value) == "number" and (nearest == nil or value < nearest) then
			nearest = value
		end
	end
	if nearest == nil or nearest <= 0 then
		return math.huge
	end
	return math.abs(aheadStuds) * (layout.WINDOW_STUDS / 2) / nearest
end

-- THE TURF SLAB: the mown lane, from the firing line's DOWNRANGE edge to the berm's NEAR face,
-- across the berm's own span -- so it is the whole of what a man at the bench looks across and it
-- never covers the pale firing line he stands on.
function Range.turfRect(anchor: Vector3, layout, downrange: number?)
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local minX, maxX = Range.bermSpanFor(anchor, layout)
	local line = Range.lineRect(anchor, layout, dir)
	local berm = Range.bermPosition(anchor, layout, dir)
	local nearZ = if dir == 1 then line.maxZ else line.minZ
	local farZ = berm.Z - dir * layout.BERM.depth / 2
	return {
		minX = minX,
		maxX = maxX,
		minZ = math.min(nearZ, farZ),
		maxZ = math.max(nearZ, farZ),
	}
end

-- THE FENCE'S TWO LINES, in Z: from the firing line's own BACK edge to the COVER BANKS' near face,
-- which is exactly the lot. Returned as a rect so the posts and the rails read one span.
--
-- THE BANKS AND NOT THE BERM, AND THAT IS A MEASUREMENT (her place, census 2026-10-29): the two
-- lines stand on the berm's own span in X, and a bank's X span IS the outer end of that -- so a run
-- carried to the berm walked straight up the side of a bank and left a post 7.5 studs in the air.
-- The lot ends where the cover begins.
function Range.fenceSpan(anchor: Vector3, layout, downrange: number?)
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local minX, maxX = Range.bermSpanFor(anchor, layout)
	local line = Range.lineRect(anchor, layout, dir)
	local bank = Range.bankPosition(anchor, layout, 1, dir)
	local backZ = if dir == 1 then line.minZ else line.maxZ
	local farZ = bank.Z - dir * layout.BANK.size.Z / 2
	local inset = layout.FENCE.insetStuds
	return {
		minX = minX + inset,
		maxX = maxX - inset,
		minZ = math.min(backZ, farZ) + inset,
		maxZ = math.max(backZ, farZ) - inset,
	}
end

-- TWO RECTANGLES' OVERLAP, or nil when they do not touch. PURE, and the one place this file
-- intersects anything: the terrace can be TWO rectangles (`cutRects`' keep-out), and everything laid
-- on it has to stand inside one of them -- which is the identity `range.spec` already asserts for
-- every part of the range.
function Range.overlapOf(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return nil
	end
	local minX, maxX = math.max(a.minX, b.minX), math.min(a.maxX, b.maxX)
	local minZ, maxZ = math.max(a.minZ, b.minZ), math.min(a.maxZ, b.maxZ)
	if maxX - minX <= 0 or maxZ - minZ <= 0 then
		return nil
	end
	return { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ }
end

-- THE MOWN LANE, CLIPPED TO THE TERRACE: one slab per cut rectangle. A single slab across her
-- place's TWO rectangles would hang over the lodge terrace's own edge, which is the rule
-- "everything built stands inside the ground the cut wrote" -- and that rule is what caught it.
function Range.turfSlabs(anchor: Vector3, layout, downrange: number?, row: any)
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local want = Range.turfRect(anchor, layout, dir)
	local out = {}
	for _, cut in ipairs(Range.cutRects(anchor, layout, dir, row)) do
		local piece = Range.overlapOf(want, cut)
		if piece ~= nil then
			table.insert(out, piece)
		end
	end
	return out
end

-- THE FENCE'S RUNS: one per (side, terrace rectangle) where that side's line actually stands ON
-- that rectangle. Where the terrace narrows for the lodge's own yard (`keepOut`), the far side has
-- no ground to stand on and simply has no run there -- a fence post over the lip of a terrace is
-- the defect, not the missing post.
function Range.fenceRuns(
	anchor: Vector3,
	layout,
	downrange: number?,
	row: any
): { { leg: number, x: number, minZ: number, maxZ: number } }
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local span = Range.fenceSpan(anchor, layout, dir)
	local half = layout.FENCE.postSection / 2
	local out = {}
	for leg, x in ipairs({ span.minX, span.maxX }) do
		for _, cut in ipairs(Range.cutRects(anchor, layout, dir, row)) do
			if x - half >= cut.minX and x + half <= cut.maxX then
				-- THE RUN'S ENDS ARE PULLED IN BY A WHOLE POST SECTION, AND THAT IS A MEASUREMENT.
				-- Her place's terrace is two rectangles meeting on one voxel plane at `keepOut.z`;
				-- a post whose CENTRE sits on that plane hangs half its section into each and is
				-- inside NEITHER -- which is exactly what `range.spec`'s "the terrace reaches
				-- everything built on it" case reported (2026-10-29, gate run 3).
				local pull = layout.FENCE.postSection
				local minZ = math.max(span.minZ, cut.minZ) + pull
				local maxZ = math.min(span.maxZ, cut.maxZ) - pull
				-- A RUN SHORTER THAN ONE BAY IS NOT A FENCE, it is a post in a field.
				if maxZ - minZ > layout.FENCE.spacingStuds then
					table.insert(out, { leg = leg, x = x, minZ = minZ, maxZ = maxZ })
				end
			end
		end
	end
	return out
end

-- EVERY FENCE POST, as x/z pairs: `spacingStuds` apart along each run, with a post ON each end so
-- no run finishes in mid air.
function Range.fencePosts(
	anchor: Vector3,
	layout,
	downrange: number?,
	row: any
): { { x: number, z: number, leg: number, run: number } }
	layout = layout or Range.LAYOUT
	local spacing = math.max(1, layout.FENCE.spacingStuds)
	local out = {}
	for run, line in ipairs(Range.fenceRuns(anchor, layout, downrange, row)) do
		local length = line.maxZ - line.minZ
		local steps = math.max(1, math.ceil(length / spacing))
		for k = 0, steps do
			table.insert(out, { x = line.x, z = line.minZ + length * k / steps, leg = line.leg, run = run })
		end
	end
	return out
end

function Range.fencePostName(run: number, index: number): string
	return string.format("FencePost%d_%d", run, index)
end

-- KEPT, AND UNUSED BY THE BUILD SINCE THE CENSUS (see `FENCE`): the lot's sides are posts, not a
-- board. It is the name a rail WOULD carry, and `range.spec` asserts the build writes none.
function Range.fenceRailName(run: number): string
	return string.format("FenceRail%d", run)
end

-- ------------------------------------------------------------------ THE WAY UP (step B10, item 6)

-- THE LADDER'S FOOT, read off `HighSeats` own footprint rather than re-derived: the fifth sample is
-- the ladder's, and `standFacing` turns it with the row -- so this is 18 studs UPRANGE of the mat in
-- both worlds, which is the side a man walks in from.
function Range.ladderFootPosition(anchor: Vector3, spot: number, layout, downrange: number?): Vector3
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local stand = Range.standPosition(anchor, spot, layout, dir)
	local facing = HighSeats.facingOf(Range.standFacing(layout, dir))
	return Vector3.new(stand.X, anchor.Y, stand.Z + facing * HighSeats.DIMS.LADDER_OFFSET_STUDS)
end

-- WHICH PROMPT IS WHICH, BY NAME (`Range.promptName`'s rule): nothing downstream knows where either
-- hangs. `way` is "up" or "down" and anything else is the way up, which is the reachable default.
function Range.climbPromptName(spot: number, way: string?): string
	local index = math.max(1, math.floor(spot or 1))
	local stem = if way == "down" then Range.CLIMB_DOWN else Range.CLIMB_UP
	return string.format("%s%d", stem, index)
end

-- THE CLIMB PROMPT'S OWN POINT: chest height at the ladder's foot. Y is the SHELF plus the rise,
-- exactly as `promptPosition` is -- the BUILT point reads the ground under the ladder, and over a
-- plate the two are one point.
function Range.climbPromptPosition(anchor: Vector3, spot: number, layout, downrange: number?): Vector3
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local foot = Range.ladderFootPosition(anchor, spot, layout, dir)
	return Vector3.new(foot.X, anchor.Y + layout.CLIMB.footRise, foot.Z)
end

-- THE WAY DOWN'S POINT: over the DOWNRANGE rail -- the board he rests on -- and NOT over the rail's
-- gap he stepped through, which is where the design wanted it. MEASURED in her place 2026-10-29:
-- with the point on the UPRANGE face a man looking down his own lane has it BEHIND him, the engine
-- hides it, and a real `F` then does nothing -- the same defect task 308 measured for the RANGE
-- prompt (*"a HIDDEN prompt does not answer its key"*). The downrange rail is in front of his eye
-- whenever he is looking at the lane, which is the whole of when he wants to come down.
-- It stays `deckRise` under the station's RANGE prompt in height and is now 5.8 studs from it in Z:
-- still both in reach of a man on the deck, which is why the two keys differ.
function Range.downPromptPosition(anchor: Vector3, spot: number, layout, downrange: number?, deckTop: number?): Vector3
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local deck = Range.standPosition(anchor, spot, layout, dir)
	local top = if type(deckTop) == "number" then deckTop :: number else anchor.Y + HighSeats.DIMS.DECK_RISE_STUDS
	return Vector3.new(deck.X, top + layout.CLIMB.deckRise, deck.Z + dir * HighSeats.DIMS.RAIL_PLANE_STUDS)
end

-- WHERE THE CLIMB PUTS HIM: on the deck's centre, `riseStuds` over its top, facing DOWNRANGE -- so
-- the man who presses E is looking at his own lane and `Range.spotAt` answers `treestand` for him.
-- PURE: the spec drives both ends with no character and no world.
function Range.climbTargetFor(anchor: Vector3, spot: number, layout, downrange: number?, deckTop: number?): CFrame
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local deck = Range.standPosition(anchor, spot, layout, dir)
	local top = if type(deckTop) == "number" then deckTop :: number else anchor.Y + HighSeats.DIMS.DECK_RISE_STUDS
	local at = Vector3.new(deck.X, top + layout.CLIMB.riseStuds, deck.Z)
	return CFrame.lookAt(at, at + Vector3.new(0, 0, dir))
end

-- AND WHERE THE WAY DOWN PUTS HIM: a stud uprange of the ladder's foot, clear of the seat's legs,
-- on the ground THE CALLER MEASURED -- never on the shelf, because the shelf is one reading at the
-- row's own point and `Build.groundUnder` measured an 11.6-stud spread across this range.
function Range.climbDownTargetFor(anchor: Vector3, spot: number, layout, downrange: number?, groundY: number?): CFrame
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local foot = Range.ladderFootPosition(anchor, spot, layout, dir)
	local ground = if type(groundY) == "number" then groundY :: number else anchor.Y
	local at = Vector3.new(foot.X, ground + layout.CLIMB.riseStuds, foot.Z - dir * layout.CLIMB.footClearStuds)
	return CFrame.lookAt(at, at + Vector3.new(0, 0, dir))
end

-- HOW FAR UPRANGE OF THE MAT THE STATION REACHES: the deck plus the seat's own feet, which is the
-- ladder's outer corner (`HighSeats.footprintRadiusStuds`). The one number the station box, the
-- footprint and her place's home area are all measured from.
function Range.standReach(layout): number
	layout = layout or Range.LAYOUT
	return layout.STAND.backStuds + HighSeats.footprintRadiusStuds()
end

-- HOW FAR HE IS ACTUALLY SHOOTING FROM. The trial's lane is the ANIMAL's distance from the firing
-- line; the deck stands `STAND.backStuds` behind it. 7.8 % at 179 studs -- small, exact, and the
-- reason the board's two lead numbers are computed from THIS and not from the picked lane (9.4).
function Range.distanceFor(trial: any, position: string?, layout): number
	layout = layout or Range.LAYOUT
	local picked = if type(trial) == "number"
		then trial
		else (if type(trial) == "table" then trial.distanceStuds else nil)
	local base = Range.distanceStudsOr(layout, picked)
	if position == Range.POSITION.TREESTAND then
		return base + layout.STAND.backStuds
	end
	return base
end

-- WHERE A FOUND PROMPT ACTUALLY IS, whatever it is parented to. The prompt moved from the mat to
-- an attachment on the post (task 303), and the Hud's "is he at the spot" test used to read
-- `prompt.Parent.Position` -- an Attachment has no `Position` in world terms, so the test went dead
-- and with it the board and the door-closer (review round 1, finding 1).
function Range.promptPointOf(prompt: any): Vector3?
	local parent = if typeof(prompt) == "Instance" then prompt.Parent else nil
	if parent == nil then
		return nil
	end
	if parent:IsA("Attachment") then
		return (parent :: Attachment).WorldPosition
	elseif parent:IsA("BasePart") then
		return (parent :: BasePart).Position
	end
	return nil
end

-- IS IT ON HER SCREEN? The pinhole projection `Camera:WorldToViewportPoint` performs, as ARITHMETIC
-- -- so a case can ask it about a viewport that is not the one the test machine is running
-- (Karen's is 969 x 792). Returns the pixel and whether the point is in front of the camera.
--   https://create.roblox.com/docs/reference/engine/classes/Camera#WorldToViewportPoint
-- `FieldOfView` is VERTICAL, so the horizontal half-angle follows the aspect ratio, which is why a
-- prompt that fits a wide window can fall off a square one.
function Range.viewportPointOf(
	cameraCFrame: CFrame,
	point: Vector3,
	viewport: Vector2,
	fovDeg: number
): (Vector2, boolean)
	local local_ = cameraCFrame:PointToObjectSpace(point)
	local depth = -local_.Z
	if depth <= 1e-6 then
		return Vector2.zero, false
	end
	local halfHeight = math.tan(math.rad(fovDeg) / 2)
	local halfWidth = halfHeight * (viewport.X / viewport.Y)
	local x = (local_.X / (depth * halfWidth) * 0.5 + 0.5) * viewport.X
	local y = (-local_.Y / (depth * halfHeight) * 0.5 + 0.5) * viewport.Y
	return Vector2.new(x, y), true
end

-- WHICH STATION A MAN IS AT, AND WHICH OF ITS TWO FIRING POSITIONS. Pure, so `Range.mayShoot` is
-- one position read and one lookup and never a sniff of `Workspace` -- and the POSITION is measured
-- the same way, so it cannot disagree with reality (design 7.3).
--
-- THE STATION IS THE UNION BOX of the two positions: the mat's own X, and in Z from the mat's
-- downrange edge back past the deck to the seat's own feet. At 24-stud spacing two boxes are 16
-- studs apart, so a point belongs to at most one station -- and a man never loses his gun walking
-- from the bench to the ladder.
--
-- THE SECOND RETURN MAY BE NIL: he is AT the station but on neither position (on the ground under
-- the deck, or between the two), which is the honest answer and not a third word.
-- `bench` is the shipped 8 x 8 mat rect, flat. `treestand` is the deck's 6 x 6 rect AND
-- `position.Y >= HighSeats.minYFor(deckTops[spot])` -- the deck's own top face with no margin, the
-- same comparison `Rules.belowPlatform` makes, so there is no sliver of height that is both or
-- neither. `deckTops[spot]` is nil for a station whose seat was REFUSED: bench only, as DATA.
--
-- DEVIATION from design 9.1's signature, stated: it takes `downrange` as well, because the station
-- box is ASYMMETRIC along Z (the deck uprange, the mat's own edge downrange) and no sign means no
-- box. Every other geometry function in this file already takes it.
function Range.spotAt(
	anchor: Vector3?,
	position: Vector3?,
	layout,
	downrange: number?,
	deckTops: { [number]: number }?
): (number?, string?)
	if typeof(anchor) ~= "Vector3" or typeof(position) ~= "Vector3" then
		return nil, nil
	end
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local at = position :: Vector3
	local halfX = layout.MAT.size.X / 2
	local halfZ = layout.MAT.size.Z / 2
	local deckHalf = HighSeats.DIMS.DECK_SIZE.X / 2
	local reach = Range.standReach(layout)
	for spot = 1, layout.SPOT_COUNT do
		local mat = Range.matPosition(anchor :: Vector3, spot, layout)
		-- The station's Z, as the two signed distances downrange of the mat: the mat's own edge
		-- ahead, the seat's feet behind.
		local ahead = (at.Z - mat.Z) * dir
		if math.abs(at.X - mat.X) <= halfX and ahead <= halfZ and ahead >= -reach then
			-- ON THE MAT?
			if math.abs(at.Z - mat.Z) <= halfZ then
				return spot, Range.POSITION.BENCH
			end
			-- ON THE DECK? Its own rect, and at or above its own top face.
			local deckTop = if type(deckTops) == "table" then deckTops[spot] else nil
			if type(deckTop) == "number" then
				local deck = Range.standPosition(anchor :: Vector3, spot, layout, dir)
				if
					math.abs(at.X - deck.X) <= deckHalf
					and math.abs(at.Z - deck.Z) <= deckHalf
					and at.Y >= HighSeats.minYFor(deckTop :: number)
				then
					return spot, Range.POSITION.TREESTAND
				end
			end
			return spot, nil
		end
	end
	return nil, nil
end

-- HOW LONG A CROSSING OF THE WINDOW TAKES at a speed. `math.huge` for a standing target, which is
-- the honest answer and not zero: a target that does not move never crosses.
function Range.crossingSeconds(windowStuds: number, speed: number): number
	if type(windowStuds) ~= "number" or type(speed) ~= "number" or speed <= 0 then
		return math.huge
	end
	return windowStuds / speed
end

-- THE GROUND THE RANGE OCCUPIES, as a flat rectangle, derived from the SAME `LAYOUT` numbers
-- `Range.Build` lays its parts from -- so the box and the parts can never disagree.
-- Read by the lobby's return rule (task 302) through the composition root: a man at the range is
-- where he belongs, and `Lobby` requires nothing of this module.
-- The margin is the mat prompt's own reach (`PROMPT.MaxActivationDistance`): anywhere a man can
-- still press E on the firing line is AT the range.
function Range.footprintFor(anchor: Vector3, layout, downrange: number?)
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local margin = layout.PROMPT.MaxActivationDistance
	-- X: the two widest things are the BANKS' OUTER FACES and the BERM, and with the berm derived
	-- (design 5.2) they coincide -- so this is `min`/`max` of both rather than of one, and a typed
	-- berm could only ever widen the box, never leave a bank outside it (306a(c)).
	local west, east = Range.corridorSpan(layout)
	local reach = Range.bankReach(layout)
	local bermMin, bermMax = Range.bermSpanFor(anchor, layout)
	local minX = math.min(anchor.X + west - reach, bermMin)
	local maxX = math.max(anchor.X + east + reach, bermMax)
	-- Z: from the SEAT'S OWN FEET, uprange of the firing line (the deck stands `STAND.backStuds`
	-- back and its ladder a footprint radius further), to the far face of the berm at the LONGEST
	-- lane. The mat's back edge is no longer the uprange end: a man on the deck has to be INSIDE
	-- this box, or her place's return rule respawns him off it (task 302).
	local nearZ = anchor.Z - dir * Range.standReach(layout)
	local farZ = anchor.Z + dir * (Range.distanceMax(layout) + layout.BERM.behindStuds + layout.BERM.depth / 2)
	-- WHOLE STUDS, ROUNDED OUTWARD, AND THAT IS A MEASURED LESSON (step B3). The seat's own
	-- footprint radius is 5.1, so the uprange edge was -3196.9 -- and a fractional edge does not
	-- survive a `Vector3`'s float32: `lobby.spec`'s round-trip case asserts `withinArea` holds for
	-- the rectangle's own corner, and -3184.9 came back a ten-thousandth outside itself. Outward is
	-- the safe direction: home can only get bigger, never leave a man standing off it.
	return {
		minX = math.floor(minX - margin),
		maxX = math.ceil(maxX + margin),
		minZ = math.floor(math.min(nearZ, farZ) - margin),
		maxZ = math.ceil(math.max(nearZ, farZ) + margin),
	}
end

-- ------------------------------------------------------------------- THE TERRACE (step B8)
--
-- A NUMBER SNAPPED OUTWARD TO THE TERRAIN VOXEL GRID. `Terrain:FillBlock` writes 4-stud voxels on
-- a grid anchored at the world origin, so a box face that lands INSIDE a voxel writes it only
-- partly -- and for an AIR box that means the hill's own occupancy survives in it (task 311's
-- measured mound). Outward is the only safe direction: the terrace can grow, never shrink below
-- what stands on it.
--   Terrain:FillBlock https://create.roblox.com/docs/reference/engine/classes/Terrain#FillBlock
function Range.toGrid(value: number, up: boolean, layout): number
	local grid = (layout or Range.LAYOUT).FILL.GRID_STUDS
	if up then
		return math.ceil(value / grid) * grid
	end
	return math.floor(value / grid) * grid
end

-- THE FLAT TERRACE THE WHOLE RANGE STANDS ON, as ONE or TWO rectangles, PURE (design 8.4).
--
-- WHY THE WHOLE LANE AND NOT ONLY THE FIRING LINE, which is a MEASUREMENT and not a preference
-- (evidence/306b8/profile.txt, her place, 2026-10-29): the natural ground falls 22 studs across
-- the firing line and the two outer lanes disagree by 20 studs at the berm. On that ground T6's
-- arithmetic -- a level shot meeting the berm at 5 of its 10 studs -- is about a berm that is not
-- there, and T5's crossing is run on a hillside.
--
-- WHY IT CAN BE TWO RECTANGLES: `keepOut` is the lobby field's west and south edge. North of that
-- z the terrace stops at that x, so the lodge's terrace and the range's meet on one voxel plane
-- and neither cuts the other's ground. A row without `keepOut` gets one rectangle and the same
-- arithmetic -- no branch on a world's name.
function Range.cutRects(anchor: Vector3, layout, downrange: number?, row: any)
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local minX, maxX = Range.bermSpanFor(anchor, layout)
	local berm = Range.bermPosition(anchor, layout, dir)
	local nearZ = anchor.Z - dir * layout.CUT.uprangeStuds
	local farZ = berm.Z + dir * (layout.BERM.depth / 2 + layout.CUT.downrangeStuds)
	local lowZ, highZ = math.min(nearZ, farZ), math.max(nearZ, farZ)
	-- CLAMPED TO THE RANGE'S OWN FOOTPRINT, which is the box her lobby's return rule calls home
	-- (task 302). Ground written outside it is ground nobody is sent home from and nobody asked
	-- for -- and the uprange edge is exactly where that bites: `CUT.uprangeStuds` reaches 2.9 studs
	-- past the footprint, so this edge snaps INWARD while the others snap out.
	local box = Range.footprintFor(anchor, layout, dir)
	minX = Range.toGrid(math.max(minX, box.minX), false, layout)
	maxX = Range.toGrid(math.min(maxX, box.maxX), true, layout)
	lowZ = Range.toGrid(math.max(lowZ, box.minZ), false, layout)
	highZ = Range.toGrid(math.min(highZ, box.maxZ), false, layout)
	local keepOut = if type(row) == "table" then row.keepOut else nil
	if type(keepOut) ~= "table" or keepOut.x == nil or keepOut.z == nil then
		return { { minX = minX, maxX = maxX, minZ = lowZ, maxZ = highZ } }
	end
	local splitZ = Range.toGrid(keepOut.z, false, layout)
	local nearMaxX = Range.toGrid(math.min(maxX, keepOut.x), true, layout)
	-- The split can fall outside the terrace, and then there is one rectangle and no seam.
	if splitZ <= lowZ then
		return { { minX = minX, maxX = nearMaxX, minZ = lowZ, maxZ = highZ } }
	end
	if splitZ >= highZ then
		return { { minX = minX, maxX = maxX, minZ = lowZ, maxZ = highZ } }
	end
	return {
		{ minX = minX, maxX = maxX, minZ = lowZ, maxZ = splitZ },
		{ minX = minX, maxX = nearMaxX, minZ = splitZ, maxZ = highZ },
	}
end

-- THE FIRING LINE'S OWN STRIP, PURE: the pale crushed stone a man stands on, against the mown
-- lane. Its three reaches come from `SURFACE` and its X from the station row, so it covers every
-- mat, post and bench at six stations and nothing downrange of them.
function Range.lineRect(anchor: Vector3, layout, downrange: number?)
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local side = layout.SURFACE.LINE_SIDE_STUDS
	local aheadZ = anchor.Z + dir * layout.SURFACE.LINE_AHEAD_STUDS
	local backZ = anchor.Z - dir * layout.SURFACE.LINE_BACK_STUDS
	return {
		minX = Range.toGrid(anchor.X - side, false, layout),
		maxX = Range.toGrid(anchor.X + Range.spotSpan(layout) + side, true, layout),
		minZ = Range.toGrid(math.min(aheadZ, backZ), false, layout),
		maxZ = Range.toGrid(math.max(aheadZ, backZ), true, layout),
	}
end

-- THE RANGE RUNTIME'S FIELD (design section 5): the lane's rectangle plus slack, with an `exitZ`
-- far BEHIND the firing line so `Brain:_outcome` can never report `escaped` or `outOfBounds` for a
-- target doing exactly what it was told. The lobby sits outside the drive's field -- x 2230..3830,
-- z -2477..-1197, exitZ -2377, against the lobby anchor (2850, -2950) -- which is why this field
-- exists at all rather than the drive's being borrowed.
Range.FIELD_SLACK_STUDS = 60
Range.FIELD_EXIT_BEHIND_STUDS = 400

function Range.fieldFor(anchor: Vector3, layout, downrange: number?)
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local slack = Range.FIELD_SLACK_STUDS
	local west, east = Range.corridorSpan(layout)
	-- THE TWO ENDS OF THE RANGE IN Z, whichever way it faces: the firing line and the LONGEST lane
	-- -- a target ordered down the 179 lane is inside the field, not out of bounds.
	local nearZ = anchor.Z
	local farZ = anchor.Z + dir * Range.distanceMax(layout)
	return {
		bounds = {
			minX = anchor.X + west - slack,
			maxX = anchor.X + east + slack,
			minZ = math.min(nearZ, farZ) - slack,
			maxZ = math.max(nearZ, farZ) + slack,
		},
		-- SOUTH OF THE WHOLE FIELD, FOR BOTH ROWS, because `Brain:_outcome`'s despawn test is
		-- `position.Z <= field.exitZ` and ITS direction is not a parameter: a signed exit put
		-- Karen's line NORTH of her lane and despawned every ordered target as `escaped` on the
		-- first order (round 2, finding 1). -400 for DEV, -3741 for the forest row.
		-- Director's decision, 2026-10-28: a wounded target at a range therefore flees DOWNRANGE
		-- into the berm (`Brain:_flee` heads for `exitZ`), which is wanted -- nothing ever runs
		-- back over the firing line.
		exitZ = math.min(nearZ, farZ) - Range.FIELD_EXIT_BEHIND_STUDS,
		groundY = anchor.Y,
	}
end

-- DEEP, AND NOT `table.freeze` (which is shallow): `src/shared/Report/init.luau`'s precedent, and
-- `Lobby`'s stated reason -- *"this repo has already paid for that once"*. "No run-time writer" is a
-- claim this enforces rather than asserts, and it has to be deep here because the server owner
-- re-exports `Range.LAYOUT`, so one write anywhere would move the lane for both readers.
function Range.deepFreeze(value)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in pairs(value) do
			Range.deepFreeze(child)
		end
		table.freeze(value)
	end
	return value
end

Range.deepFreeze(Range.LAYOUT)
Range.deepFreeze(Range.ANCHORS)
Range.deepFreeze(Range.WORD)
Range.deepFreeze(Range.PACE_ORDER)
Range.deepFreeze(Range.CROSSING_SECONDS)
Range.deepFreeze(Range.DISTANCES_STUDS)

return Range
