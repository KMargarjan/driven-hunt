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
	-- THE SPAN'S ONE TYPED ROW (task 313, design 3.1). The aim point may be anywhere on the animal,
	-- so each bound is pulled in by half the longest body: `Boar.CONFIG.BODY_SIZE` is 2 x 3 x 5.5
	-- and the stag's `KINDS` row 1.8 x 4.8 x 7.05, so half a length is 3.525 -- 4 on whole studs.
	SIGHT = { silhouetteStuds = 4 },
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
	-- THE BANKS MATCH THE BERM (306k item 2): 18 studs, three under the crest, so the two side
	-- banks read as spurs off the same heap rather than as two kerbs in front of a hill.
	BANK = { size = Vector3.new(12, 18, 14), beyondStuds = 6, color = Color3.fromRGB(96, 88, 76) },
	-- THE BERM HAS NO TYPED WIDTH: `Range.bermWidthFor` derives it so it spans every station's lane
	-- AND both banks, which is the identity `range.spec` asserts (design 5.2). 10 studs = 2.8 m,
	-- "not high" (Karen), inside the 6 m upper bound the note refused to treat as a requirement.
	-- `behindStuds` IS KEPT CONGRUENT TO 13 MOD 4, so the berm's rectangle stays on the terrain
	-- grid in all four edges relative to the anchor (design 5.4). 306l moved it 13 -> 17: the
	-- centre sits `distanceMax + 17` = 196 and `depth` 8 puts its faces at 192 and 200.
	--
	-- 21 STUDS AND NOT 10 (306k item 2). MEASURED from the bench: at 10 studs the crest subtended
	-- 3.0 degrees at 190 studs and read as "a thin band of tall grass on the horizon"
	-- (playtest/range-v2 item 1, 06-downlane-ft.png, 11-boar-ft.png). REAL LIFE: a live-fire impact
	-- berm is 4-6 m -- the NRA Range Source Book's 15 ft (4.6 m) minimum stop butt, and US Army
	-- TC 25-8's own 6 m -- so 21 studs is 5.9 m at this project's 0.28 m/stud, the top of that band.
	-- It subtends 6.3 degrees, 4.5x the 1.4 degrees a boar's own 3 studs make at 125.
	--   NRA Range Source Book, ch. 3 (impact berms)  https://www.nrahq.org/pdf/RangeSourceBook.pdf
	--   US Army TC 25-8, Training Ranges, app. B    https://armypubs.army.mil/
	-- THAT "176 IS THREE STUDS CLEAR OF 179" WAS WRONG, and 306l measured it: the toe stood at 176
	-- and the earth on the 179 lane itself was 7.28 studs deep. See the 306l paragraph below, which
	-- is what `behindStuds` and `slopeRun` now say. The far face still cannot go back far, because
	-- her ground DROPS to 141-144 where the asphalt road crosses -- so the face stays steeper than a
	-- real 1:1.2 batter, named and not hidden.
	-- `slopeRun` and `slopeSteps` ARE THE UPRANGE FACE (step B8). A rectangular block of earth is
	-- a wall; Karen asked for *"a mountain not high but like in real life"*, and a real berm is a
	-- trapezoid. Four 2-stud bands (10 * k / 5) over a 12-stud run is a 1:1.2 batter, and 2 studs
	-- per step is design 8.2's decided fallback for the unverified `FillWedge`. Only the terrain arm
	-- reads them -- a part berm is one box, as it was.
	--
	-- 306l: THE HEAP MOVED BACK OFF THE FAR LANE, AND THAT IS A MEASUREMENT, NOT A MARGIN.
	-- With `behindStuds` 13 and `slopeRun` 12 the battered toe stood at 176 and a terrain raycast
	-- down lane 2 read 7.28 studs of earth standing ON the 179 lane itself (306l first measure,
	-- <runs-dir>/306l-profile.luau). A real `RangeRequest` for 179 then put the boar at d 171.9,
	-- 1.5 studs up the batter and INVISIBLE from bench 2 (306l-BEFORE-boar-zoom.png). So:
	--   behindStuds 13 -> 17  (the crest's near face goes 192 -> ... see `bermToeClearance`)
	--   slopeRun    12 ->  8  (the toe comes back to 184)
	-- and `bermToeClearance` is then 5 studs of clear ground past the farthest lane.
	-- THE FAR FACE CANNOT GO FURTHER BACK THAN THIS: the same profile reads her ground at -6.0 at
	-- d 200 and ASPHALT at d 204, so the terrace's own downrange edge (202) stands 2 studs clear
	-- of the road. That bound is why the face is steeper than a 1:1 batter -- named, not hidden.
	BERM = {
		height = 21,
		depth = 8,
		behindStuds = 17,
		slopeRun = 8,
		-- FOUR BANDS AND NOT SIX: over an 8-stud run six bands are 1.3 studs deep, under the
		-- 4-stud voxel, so two of them write nothing. Four gives a 2-stud step, design 8.2's own.
		slopeSteps = 4,
		-- HOW MUCH CLEAR GROUND THE FARTHEST LANE KEEPS BEHIND IT. The released boar's trunk
		-- measures 2 x 3 x 5.5 (306l-fire, her place), so half its length is 2.75 and this leaves
		-- 2.25 studs over it -- more than the half voxel a partial terrain fill can reach with.
		-- `bermToeClearance` is the DERIVED number; this is the bound `range.spec` holds it to.
		toeClearStuds = 5,
		-- ------------------------------------------------- THE HILL'S SHAPE (306l item 2)
		-- Karen: *"an earth formed mountain"*. A box with one level crest reads as a WALL from the
		-- bench (306k-AFTER-bench2.png, 306l-BEFORE-boar-zoom.png -- a dead-straight top and a
		-- dead-straight toe). A hill is built here as COLUMNS across the span, each with its own
		-- crest height and its own batter run, so neither line is straight.
		-- `crestStepStuds` is one column's width. 306m MOVED IT 12 -> 4 (one voxel): at 12 studs
		-- each column was a BOX with its own top and the skyline was a row of square crenellations
		-- (306l-R2-AFTER-marker-crop.png -- Karen's "castle battlement"). The wave below is now a
		-- function of STUDS and not of the column index, so sampling finer rolls the same hill
		-- rather than combing it.
		crestStepStuds = 4,
		-- ------------------------------------------------- THE HILL IS BALLS NOW (306m)
		-- `Terrain:FillBall` is the smoothing instrument: it writes PARTIAL voxel occupancy, so the
		-- renderer's isosurface comes out curved, where `FillBlock` writes a box with a vertical
		-- face and a flat top. `FillWedge`'s orientation inside its CFrame is NOT documented
		-- (create.roblox.com lists the signature only), so it is not used -- an undocumented
		-- orientation cannot be asserted.
		--   Terrain:FillBall https://create.roblox.com/docs/reference/engine/classes/Terrain#FillBall
		-- One ball per (column, level): the ball INSCRIBED in the hill's own cross-section at that
		-- level, so the union is a cone of earth rounded over at the top and at the toe.
		levelStuds = 4,
		-- ...and the crest's own cap radius. 3 AND NOT 1: two caps `crestStepStuds` apart must
		-- OVERLAP or the skyline is a comb of cusps -- at radius 3 and step 4 the dip between two
		-- caps is 0.76 studs (3 - sqrt(9-4)), which is 0.23 degrees at the bench's 190.
		capRadius = 3,
		-- HOW MUCH THE CREST MAY RISE OR FALL OVER ONE `crestStepStuds` -- the battlement bound
		-- (306m item 4). The outer bound carries the shoulder's own taper (shoulderDrop /
		-- shoulderStuds = 5/16 per stud); the inner one is what a man down the lane actually sees,
		-- inside the shoulders, where only the wave moves the crest.
		crestStepMaxStuds = 2.5,
		crestStepInnerMaxStuds = 1.5,
		-- THE STEEPEST SLOPE THE HILL IS ALLOWED, MEASURED OVER ONE VOXEL (4 studs) -- and it is a
		-- BOUND ON A MEASUREMENT, not a target. The envelope 306l fixed is `slopeRun + depth` = 16
		-- studs deep and `height` 21 tall, so the shallowest possible steepest face here is
		-- atan(21/8) = 69.1 degrees; the frustum that spheres can actually build reads 77.2. A
		-- 50-degree face would need 17.6 studs of run and put the toe at 174 -- 4.6 studs INSIDE
		-- the 179 lane -- so it is refused by the toe clearance, not by taste. `range.spec` samples
		-- the union's own surface and holds it here.
		faceMaxDegrees = 79,
		-- ...AND THE STEEPEST RISE OVER ONE STUD, which is the bound that actually REJECTS the two
		-- shapes this task exists to kill (round 1, finding 1): a 4-stud chord cannot see them,
		-- because it averages the jump with the slope under it. Measured over all 58 columns the
		-- frustum's worst one-stud rise is 5.13 studs; the pedestal the first 306m draft simulated
		-- was 8.7, and a 306l box's face was its WHOLE crest in one sample, up to 21. 6.5 sits
		-- between the shipped shape and both of them.
		riseMaxStuds = 6.5,
		-- how far under `height` the lowest point of the RIPPLE sits: the crest wanders 18..21, and
		-- 3 AND NOT 4 IS A BOUND AND NOT A TASTE (review round 1, finding 1). A man on the deck
		-- fires from `HighSeats.DIMS.DECK_RISE_STUDS + AIM_RISE_STUDS` = 17.5 studs over the shelf,
		-- so a crest under that is a backstop he shoots over. `range.spec` asserts the floor.
		crestDropStuds = 3,
		-- ...and how far the heap's own SHOULDERS fall, over the outer `shoulderStuds` of the span,
		-- so the ends die away into the ground instead of stopping square. 16 AND NOT 24, for the
		-- same bound: the firing fan reaches `sightHalfWidthAt` past the outer mats at the crest
		-- face, which is 23.7 studs in from the heap's end -- a taper any wider dips into it.
		shoulderDropStuds = 5,
		shoulderStuds = 16,
		-- SCRUB ALONG THE CREST TOP (306l item 2), as TERRAIN and not as parts -- so there is no
		-- pivot to float (rule E / L-086), no gap a shot could pass under, and nothing to upload.
		-- Each clump stands from the terrace like every other band, so the heap invariant is
		-- untouched; only its top shows, on the crest, BEHIND the bare lip.
		-- 13 CLUMPS, IRREGULAR, AND THAT IS A MEASUREMENT OFF THE FIRST 306m FRAME. With 7 clumps of
		-- one radius at even spacing the crest photographed as a row of regular CONES -- the
		-- battlement's rhythm with rounded tops (306m-cmp-crest.png, the first AFTER). The EARTH's
		-- own roll cannot carry the skyline on its own: `crestDropStuds` is 3 and cannot grow,
		-- because `height - crestDrop` = 18 is already within half a stud of the deck's own eye at
		-- 17.5 and a crest under that is a backstop a man on the deck shoots over. So the scrub is
		-- what makes the skyline roll, and it has to be scattered rather than combed.
		scrubCount = 13,
		-- `.Y` is how far a clump stands PROUD of its crest, and it is now the TOP of a range: each
		-- clump takes its own share of it, correlated with its own radius so a tall clump is also a
		-- wide one and every clump stays embedded in the ridge (rule E).
		scrubSize = Vector3.new(11, 5, 4),
		-- ONE BALL PER CLUMP, radius 3.5, so a clump is 7 studs of bush and not a 11 x 5 x 4 BOX
		-- standing on the ridge (306m item 1: no flat tops anywhere on the hill). `scrubSize.Y` is
		-- still how far it stands PROUD of the hill's own surface, and `.X` is unused by the ball
		-- arm -- kept because the DEV parts arm reads the same row.
		scrubRadius = 3.5,
		-- how far a clump's own radius may fall under `scrubRadius`: 2.25..3.5 with the same wave
		-- that sets its height, so no two neighbours read as the same bush.
		scrubRadiusDropStuds = 1.25,
		-- the clump's own front face, uprange-clear of the crest's bare lip.
		scrubBackStuds = 2,
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
		-- THE BOARD HANGS FROM THE ROOF, so its rise is DERIVED and never typed: its TOP meets the
		-- roof's underside. Typed at 6.4 it spanned shelf+5.3..shelf+7.5 against an underside at
		-- shelf+9.0 -- six signs in 1.5 studs of air, which is the very defect the lot's side line
		-- was refused over (review round 1, finding 1). `boardRiseFor` is the one answer, and there
		-- is deliberately NO `boardRise` key here for it to drift from.
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
		-- NOTHING ON THESE TWO LINES IS BUILT, AND IT IS REFUTED RATHER THAN DROPPED (census in her
		-- place, 2026-10-29; `Range.Build` carries the full reading). They stand 18 studs outside the
		-- corridor, which there is OFF the cut terrace and on the hill: a rail could not follow
		-- ground falling 150 -> 158 -> 154, and a POST laid on the build's own ground reader stood
		-- 7.5 studs in the air, because that reader and a terrain raycast disagree by that much at
		-- (2775, -3061). This table is the arithmetic a later task needs; `range.spec` asserts the
		-- build writes none of it.
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
		-- the prompt POINT at the ladder's foot: chest height.
		footRise = 3.0,
		-- HOW FAR A STANDING MAN'S EYE IS OVER HIS ROOT (an R15 head centre). The down prompt hangs
		-- at his EYE, so `downPromptRiseFor` derives its height and there is deliberately NO
		-- `deckRise` key for it to drift from -- `boardRiseFor`'s pattern.
		eyeOverRootStuds = 1.5,
		-- HOW HIGH A BODY SITS over what it stands on. `Match.CONFIG.STAND_HEIGHT_STUDS`' own 3.5,
		-- restated and not required: the lobby's range reaches into no hunt module (this file's head).
		riseStuds = 3.5,
		-- THREE STUDS UPRANGE OF THE LADDER'S CENTRE, and 3 and not 1 is a MEASUREMENT (her place,
		-- real `F`, 2026-10-29): at 1 the man came down at (2624, 166.6, -3011) -- 13 studs up, on
		-- top of his own ladder. The GROUND READING is not what moved: `onClimbDown` reads it at the
		-- ladder's own centre either way, and the live 153.1 says it answers 149.6 there. What moved
		-- is where the BODY is PLACED: the ladder is 2 studs deep, so at 1 the man was set inside the
		-- truss's own volume and the engine pushed him out onto its top. At 3 he is 2 studs clear of
		-- its face, and still inside `standReach`'s footprint box.
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
		-- THE BERM AND THE TWO BANKS ARE BARE EARTH (306k item 2), AND THAT REVERSES B10's GUESS ON
		-- A MEASUREMENT. B10 chose `Grass` reasoning that blades "makes a heap of soil read as a
		-- hill"; from the bench they instead made it read as "a thin band of tall grass on the
		-- horizon" and not as a backstop at all (playtest/range-v2 item 1, 06-downlane-ft.png).
		-- `Ground` is what a live-fire impact berm is in life -- worked soil, no sward -- and it
		-- stands brown against the mown lane and the grass around it. Karen: *"earth formed
		-- mountain"*.
		BERM = Enum.Material.Ground,
		-- THE HILL'S GRASSED HALF (306l item 2): the crest, the back, and the two side banks. Bare
		-- earth is the IMPACT FACE only, which is what a live-fire berm looks like -- the face is
		-- scoured and everything the rounds never reach keeps its sward.
		HILL = Enum.Material.Grass,
		-- the scrub along the crest top. `LeafyGrass` is the terrain renderer's own tall blade
		-- material -- the very thing B8 refused for the LANE, which is exactly why it reads as a
		-- bush on a ridge and not as a mown surface.
		SCRUB = Enum.Material.LeafyGrass,
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

-- THE ISSF PACE WINDOW, 10 m. The ONLY reader is `paceSpeedFor`: a pace is a TIME across the ISSF
-- window, so this number must not move with what a man can SEE (design 2) -- that is
-- `Range.sightSpanFor`. Were the two one number, `slow` would become 39.2 studs/s on the wide span.
-- Note: docs/design/shooting-range-lobby.md section 2
function Range.paceWindowStuds(layout): number
	layout = layout or Range.LAYOUT
	return layout.WINDOW_STUDS
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
		return Range.paceWindowStuds(layout) / seconds
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

-- ============================ THE SPAN: WHERE HIS ANIMAL MAY BE =============================
-- Task 313, Karen 2026-10-30: *"when I click E it will make that I am alone in all shooting range
-- ... now is to short for one specific stand"*. The 36-stud window is 1.5 s at run; the span below
-- is 71-156 studs, 3.0-6.5 s. It is the INTERSECTION of three bounds, each off `LAYOUT` and each
-- load-bearing -- the built earth behind, his own bay's opening, and the corridor's apron.
-- Note: docs/design/shooting-range-lobby.md sections 3, 10.1

-- THE EARTH THAT IS AT FULL HEIGHT: the berm's span less its two tapered shoulders, which are the
-- only part of the crest `bermColumns` does NOT carry to `height`. The banks and the shoulders are
-- margin; the bound may not lean on them.
function Range.backstopSpanFor(anchor: Vector3, layout): (number, number)
	layout = layout or Range.LAYOUT
	local minX, maxX = Range.bermSpanFor(anchor, layout)
	local shoulder = math.max(0, layout.BERM.shoulderStuds)
	return minX + shoulder, maxX - shoulder
end

-- THE WIDEST ANGLE THE BUILT EARTH SUBTENDS, as a slope: the reach from the outermost mat to the
-- opposite backstop corner, over the crest face's Z. 160/192 = 0.8333 (39.81 degrees). It is the
-- same both ways because the backstop spans the mats symmetrically.
function Range.backstopSlope(layout): number
	layout = layout or Range.LAYOUT
	local origin = Vector3.new(0, 0, 0)
	local minX, maxX = Range.backstopSpanFor(origin, layout)
	local reach = math.max(maxX, Range.spotSpan(layout) - minX)
	local ahead = math.abs(Range.bermCrestFaceZ(origin, layout, 1))
	if ahead <= 0 then
		return 0
	end
	return reach / ahead
end

-- HIS OWN BAY'S OPENING, as a slope. The two downrange hut posts are the ONLY furniture of his own
-- station in the bore's plane (design 3.1 bound 2), so the ray must stay inboard of their inner
-- face through the roof's whole Z extent: (roofSize.X/2 - postSection) / (roofAheadStuds +
-- roofSize.Z/2) = 5.6/10.5.
function Range.bayHalfSlope(layout): number
	layout = layout or Range.LAYOUT
	local hut = layout.HUT
	local ahead = hut.roofAheadStuds + hut.roofSize.Z / 2
	if ahead <= 0 then
		return math.huge
	end
	return math.max(0, hut.roofSize.X / 2 - hut.postSection) / ahead
end

-- WHERE HIS ANIMAL MAY BE, AND THEREFORE WHAT HE SEES AND WHAT HIS SHOT MAY HIT. THE ONE PREDICATE:
-- `Range.maskFor` (the picture), `Range.ignoredFor` (the shot's door) and `timeWindow` (the
-- crossing) all read this and derive no copy of their own.
-- `wide = false` IS `windowSpanFor`'s body, so the flag-off branch is bit-for-bit today's game.
function Range.sightSpanFor(
	anchor: Vector3,
	spot: number,
	layout,
	distanceStuds: number?,
	wide: boolean?
): (number, number)
	layout = layout or Range.LAYOUT
	if wide ~= true then
		return Range.windowSpanFor(anchor, spot, layout)
	end
	local matX = Range.matPosition(anchor, spot, layout).X
	local lane = Range.distanceStudsOr(layout, distanceStuds)
	local silhouette = math.max(0, (layout.SIGHT and layout.SIGHT.silhouetteStuds) or 0)

	-- BOUND 1, THE BACKSTOP: the aim point whose ray crosses the crest face on the full-height
	-- earth. `x(Zcrest) = matX + (x - matX) * Zcrest/lane`, inverted.
	local ahead = math.abs(Range.bermCrestFaceZ(Vector3.new(0, 0, 0), layout, 1))
	local backMin, backMax = Range.backstopSpanFor(anchor, layout)
	local scale = if ahead > 0 then lane / ahead else 0
	local lo = matX + (backMin - matX) * scale + silhouette
	local hi = matX + (backMax - matX) * scale - silhouette

	-- BOUND 2, HIS OWN BAY: what he can see out of his own firing hut.
	local bay = Range.bayHalfSlope(layout) * lane
	lo = math.max(lo, matX - bay + silhouette)
	hi = math.min(hi, matX + bay - silhouette)

	-- BOUND 3, THE APRON: the leg is the span plus one apron at each end and may not leave the
	-- corridor, or the turn-around walks into the built cover.
	local west, east = Range.corridorSpan(layout)
	lo = math.max(lo, anchor.X + west + layout.APRON_STUDS)
	hi = math.min(hi, anchor.X + east - layout.APRON_STUDS)

	if hi < lo then
		-- A layout whose bounds do not intersect gets the shipped window, never an inverted span.
		return Range.windowSpanFor(anchor, spot, layout)
	end
	return lo, hi
end

-- THE LEG: the span plus ONE APRON at each end. The apron is what keeps `timeWindow` alive -- an
-- animal released inside the span never enters it, so no crossing is ever recorded -- and it is the
-- turn-around out of sight. A SUBSET of `corridorSpan` by bound 3 above.
function Range.laneEndsFor(
	anchor: Vector3,
	layout,
	leg: number,
	downrange: number?,
	spot: number?,
	distanceStuds: number?,
	wide: boolean?
): Vector3
	layout = layout or Range.LAYOUT
	local centre = Range.laneCentre(anchor, layout, downrange, spot, distanceStuds)
	local lo, hi = Range.sightSpanFor(anchor, spot or 1, layout, distanceStuds, wide)
	local east = (leg % 2) == 1
	local x = if east then hi + layout.APRON_STUDS else lo - layout.APRON_STUDS
	return Vector3.new(x, centre.Y, centre.Z)
end

function Range.laneEnds(
	anchor: Vector3,
	layout,
	leg: number,
	downrange: number?,
	spot: number?,
	distanceStuds: number?
): Vector3
	-- THE OFF BRANCH, AND ONE ARITHMETIC: `laneEndsFor(..., false)` is the span `mat +- 18` grown
	-- by one apron, which IS `centre.X +- laneLength/2`. Kept as the shipped name.
	return Range.laneEndsFor(anchor, layout, leg, downrange, spot, distanceStuds, false)
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

-- THE CREST'S NEAR FACE: the Z the battered face is measured back from, and the Z the grassed
-- crest and back are measured forward from. One answer, so the two halves of the heap meet.
function Range.bermCrestFaceZ(anchor: Vector3, layout, downrange: number?): number
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	return Range.bermPosition(anchor, layout, dir).Z - dir * layout.BERM.depth / 2
end

-- THE FORWARD-MOST EARTH OF THE WHOLE HEAP. Every column's batter is `slopeRun` or less, so the
-- toe of the heap is the crest face less the full run -- the one number the far lane must clear.
function Range.bermToeZ(anchor: Vector3, layout, downrange: number?): number
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	return Range.bermCrestFaceZ(anchor, layout, dir) - dir * layout.BERM.slopeRun
end

-- HOW MUCH CLEAR GROUND THE FARTHEST LANE KEEPS BEHIND IT, in studs, derived from the three dials
-- that move the heap. 306l's whole first item is this number being positive and bigger than the
-- animal's half length: at `behindStuds` 13 / `slopeRun` 12 it was -3, and a boar asked for at 179
-- stood at 171.9 on the slope (306l first measure).
function Range.bermToeClearance(layout): number
	layout = layout or Range.LAYOUT
	return layout.BERM.behindStuds - layout.BERM.depth / 2 - layout.BERM.slopeRun
end

-- THE HILL'S COLUMNS, PURE: the heap across its own span as `crestStepStuds`-wide columns, each
-- with its OWN crest height and its OWN batter run, so neither the crest line nor the toe line is
-- straight. Two incommensurate sines and NOT a random seed: a seeded `Random` would give her a
-- different hill at every build and no spec could state what it asserts.
--   top  = height - crestDrop * (1 - wave)   - shoulderDrop * (1 - taper)
--   run  = slopeRun * (0.55 + 0.45 * wave2)  -- never MORE than `slopeRun`, so the toe holds
--
-- 306m: THE WAVE IS A FUNCTION OF STUDS, NOT OF THE COLUMN INDEX. 306l's `sin(2.7 * i)` carried a
-- wavelength of 2.7 rad per COLUMN, so halving the column width halved the wavelength and a finer
-- sample came out as a comb. The four rates below are 306l's own divided by its 12-stud column, so
-- the hill KEEPS ITS SHAPE (27.9 and 90.8 stud rolls on the crest) and may now be sampled as
-- finely as the voxel grid allows.
function Range.bermColumns(anchor: Vector3, layout, downrange: number?)
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local berm = layout.BERM
	local width = Range.bermWidthFor(layout)
	local count = math.max(1, math.floor(width / math.max(1, berm.crestStepStuds) + 0.5))
	local step = width / count
	local minX = Range.bermPosition(anchor, layout, dir).X - width / 2
	-- QUARTER STUDS, AND THAT IS NOT TIDINESS. A band's box is a `CFrame` and a `Vector3`, both
	-- float32, so `(shelf + h/2) - h/2` comes back a ten-thousandth off the shelf for an arbitrary
	-- `h` -- and "every box stands FROM the terrace" (rule E) is asserted to 1e-6. On a quarter
	-- stud every height, half-height and `k/steps` share is a binary fraction and the identity is
	-- exact. `range.spec`'s own float32 lesson, in `footprintFor`'s comment, one step further in.
	local function quarter(value: number): number
		return math.floor(value * 4 + 0.5) / 4
	end
	local out = {}
	for i = 1, count do
		local x = minX + (i - 0.5) * step
		local u = x - minX
		local wave = 0.5 + 0.32 * math.sin(0.225 * u + 0.6) + 0.18 * math.sin(0.069166667 * u + 2.1)
		local wave2 = 0.5 + 0.30 * math.sin(0.158333333 * u + 2.4) + 0.20 * math.sin(0.039166667 * u)
		local edge = math.min(x - minX, minX + width - x)
		local taper = math.clamp(edge / math.max(1, berm.shoulderStuds), 0, 1)
		local top = berm.height - berm.crestDropStuds * (1 - wave) - berm.shoulderDropStuds * (1 - taper)
		out[#out + 1] = {
			x = x,
			width = step,
			top = math.max(1, quarter(top)),
			-- NEVER MORE THAN `slopeRun`: the toe is what the far lane clears, so it is a bound and
			-- not an average. `quarter` rounds to nearest, so the factor's own ceiling is 1.
			-- 306m MOVED THE FACTOR 0.55 -> 0.85, and that is arithmetic. The crest must be
			-- `2 * capRadius` wide for two caps to overlap, so the BATTER's own run is
			-- `run - capRadius`: at 0.55 the narrowest column had 4.5 - 3 = 1.5 studs of run under
			-- 18 studs of crest, an 85-degree face. At 0.85 it is 3.75..5, and the toe line still
			-- wanders 1.25 studs, which is what "the toe is not one line" asserts.
			run = math.min(
				layout.BERM.slopeRun,
				quarter(layout.BERM.slopeRun * (0.85 + 0.15 * math.clamp(wave2, 0, 1)))
			),
		}
	end
	return out
end

-- THE HILL'S OWN CROSS-SECTION, PURE (306m). The apex line is `bermCrestFaceZ` -- the MIDPOINT of
-- the envelope 306l measured and fixed: the toe at `crestFace - slopeRun` (the farthest lane keeps
-- `bermToeClearance`) and the back at `bermPosition + depth/2` (the terrace's own edge keeps the
-- road 2 studs). So the front run is the column's own `run` and the back run is `depth`.
--
-- A FRUSTUM AND NOT A CONE, AND THAT IS MEASURED, NOT CHOSEN. A cone -- half-depth falling to ZERO
-- at the crest -- is the shape with the shallowest possible steepest face here (atan(21/8) = 69.1
-- degrees), but it CANNOT BE BUILT OUT OF SPHERES: at the crest the inscribed ball's radius goes to
-- nothing, so two neighbouring crest balls stop overlapping and the skyline comes out a comb of
-- cusps. Hold the radius at `capRadius` instead and the crown becomes a CYLINDER standing on the
-- cone -- a pedestal with a vertical face (simulated before it was built: the surface jumped 8.7
-- studs in one stud at z = -2.8). So the section tapers LINEARLY from its base half-depth to
-- `capRadius` at the crown: a trapezoid, which is also what a built berm is in life. It costs face
-- angle -- 74.5 degrees at `run` 8 instead of 69.1 -- and it is monotone, which a pedestal is not.
-- Returns the half-depth of the section at `rise` and the Z of its centre, measured from the apex.
-- The taper never needs a floor: `base` is `(run + depth) / 2` >= 7.375, so `cap + (base - cap) *
-- share` is already >= `cap` at every share (round 1, note).
local function sectionAt(layout, column, rise: number): (number, number)
	local cap = math.max(1, layout.BERM.capRadius)
	local back = layout.BERM.depth
	local crown = math.max(cap, column.top - cap)
	local share = math.clamp(1 - rise / crown, 0, 1)
	local base = (column.run + back) / 2
	return cap + (base - cap) * share, (back - column.run) / 2 * share
end

-- THE HILL AS BALLS (306m item 1), PURE. One `Terrain:FillBall` per (column, level): the ball
-- INSCRIBED in `sectionAt`'s interval, so the union is a cone of earth with a rounded crest and a
-- rounded toe and NO vertical face and NO flat top anywhere. A ball writes partial voxel
-- occupancy, which is why the renderer draws it curved.
-- The radius never falls below `capRadius`: two caps `crestStepStuds` apart must overlap or the
-- crest is a comb, and the topmost ball's top IS the column's crest (rise = top - capRadius).
-- A clamped ball stands PROUD of the ideal cone -- `capRadius - section` studs, at most 2.5 at the
-- crown -- which rounds the ridge; it never reaches the toe or the back, and the spec asserts that
-- against `bermToeZ` and the terrace edge rather than trusting it.
function Range.bermBalls(anchor: Vector3, layout, downrange: number?)
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local berm = layout.BERM
	local apex = Range.bermCrestFaceZ(anchor, layout, dir)
	local cap = math.max(1, berm.capRadius)
	local step = math.max(1, berm.levelStuds)
	local out = {}
	for _, column in ipairs(Range.bermColumns(anchor, layout, dir)) do
		local rises = {}
		local rise = 0
		local crown = math.max(cap, column.top - cap)
		while rise < crown - 1e-6 do
			rises[#rises + 1] = rise
			rise += step
		end
		rises[#rises + 1] = crown
		for _, at in ipairs(rises) do
			local half, centre = sectionAt(layout, column, at)
			out[#out + 1] = {
				x = column.x,
				z = apex + dir * centre,
				rise = at,
				radius = math.max(cap, half),
				surface = "BERM",
			}
		end
	end
	return out
end

-- THE TWO SIDE BANKS, THE SAME WAY (306m item 2). 306l filled each as ONE 12 x 18 x 14 BLOCK and
-- that is the "square block with a vertical face" on the left of 306l-R2-AFTER-marker-crop.png.
-- Here each is a rounded mound on the same level/inscribed-ball rule, in TWO chains -- one on the
-- bank's own centre and one `levelStuds` downrange of it -- so the mound runs INTO the heap's toe
-- instead of standing in front of it as a separate block.
function Range.bankBalls(anchor: Vector3, layout, leg: number, downrange: number?)
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local at = Range.bankPosition(anchor, layout, leg, dir)
	local size = layout.BANK.size
	local cap = math.max(1, layout.BERM.capRadius)
	local step = math.max(1, layout.BERM.levelStuds)
	local base = math.min(size.X, size.Z) / 2
	local out = {}
	for _, z in ipairs({ at.Z, at.Z + dir * step }) do
		local rise = 0
		local crown = math.max(cap, size.Y - cap)
		while rise < crown - 1e-6 do
			local share = math.clamp(1 - rise / crown, 0, 1)
			out[#out + 1] = { x = at.X, z = z, rise = rise, radius = cap + (base - cap) * share, surface = "HILL" }
			rise += step
		end
		out[#out + 1] = { x = at.X, z = z, rise = crown, radius = cap, surface = "HILL" }
	end
	return out
end

-- WHERE THE SCRUB STANDS: `scrubCount` clumps spread across the columns INSIDE the shoulders, each
-- on its own column's crest and BEHIND the bare lip by `scrubBackStuds` -- never DOWN the face,
-- which is the half a shot travels to. A ball is round, so a clump's own uprange edge does reach
-- `scrubRadius - scrubBackStuds` = up to 1.5 studs past the apex line, at the very top of the
-- crest and nowhere near where a round lands (round 1, note); `range.spec` holds it to that.
-- 306m: ONE BALL PER CLUMP (`scrubRadius`), not a box. `rise` is set so the ball's TOP stands
-- `scrubSize.Y` over the column's crest -- 306l's own number -- and its BOTTOM is under the crest's
-- own surface, so a clump is embedded in the ridge and cannot float (rule E). Measured here, not
-- assumed: at `scrubBackStuds` 2 the crown ball of radius `capRadius` reaches
-- `top - capRadius + sqrt(capRadius^2 - 4)` = top - 0.76, and the clump's bottom is top - 2.
function Range.bermScrubPoints(anchor: Vector3, layout, downrange: number?)
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local columns = Range.bermColumns(anchor, layout, dir)
	local wanted = math.max(0, math.floor(layout.BERM.scrubCount or 0))
	local apex = Range.bermCrestFaceZ(anchor, layout, dir)
	local radius = layout.BERM.scrubRadius
	local out = {}
	if wanted == 0 or #columns < 3 then
		return out
	end
	for n = 1, wanted do
		-- ONE WAVE PER CLUMP, carrying its place, its size and its height together: a tall clump is
		-- a wide one, which is what keeps every clump embedded in the crest it stands on (rule E).
		local wave = 0.5 + 0.5 * math.sin(2.3 * n + 1.1)
		-- inside the heap, never on a shoulder: the band 0.12..0.88 of the column row, with the
		-- clump's own share of it moved by up to 0.35 of a step so the spacing is not a comb.
		local place = (n - 0.5 + (wave - 0.5) * 0.7) / wanted
		local index = math.floor(0.12 * #columns + (0.76 * #columns) * place) + 1
		local column = columns[math.clamp(index, 1, #columns)]
		local size = radius - layout.BERM.scrubRadiusDropStuds * (1 - wave)
		local proud = layout.BERM.scrubSize.Y * (0.5 + 0.5 * wave)
		out[#out + 1] = {
			x = column.x,
			z = apex + dir * layout.BERM.scrubBackStuds,
			rise = column.top + proud - size,
			radius = size,
			top = column.top,
		}
	end
	return out
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

-- HOW HIGH THE BOARD'S CENTRE SITS over whatever the roof is measured from: the roof's own
-- underside less half the board. DERIVED, so the board cannot drift off the roof it hangs on.
function Range.boardRiseFor(layout): number
	layout = layout or Range.LAYOUT
	return layout.HUT.roofRise - layout.HUT.boardSize.Y / 2
end

-- THE NUMBER BOARD, on the hut's UPRANGE fascia, hanging from the roof's own uprange edge: its TOP
-- face IS the roof's underside, which is what makes it a sign on a building rather than a sign in
-- the air (round 1, finding 1).
function Range.boardPosition(anchor: Vector3, spot: number, layout, downrange: number?): Vector3
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local hut = layout.HUT
	local at = Range.hutRoofPosition(anchor, spot, layout, dir)
	return Vector3.new(
		at.X,
		anchor.Y + Range.boardRiseFor(layout),
		at.Z - dir * (hut.roofSize.Z / 2 - hut.boardSize.Z / 2)
	)
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

-- THE WORST OFF-AXIS X A SIGHT LINE REACHES at `aheadStuds` downrange of the mat. TASK 313: the
-- widest angle is no longer the window's edge at the shortest lane (9.55 deg) but the BUILT EARTH's
-- own corner from the outermost mat, `Range.backstopSlope` -- 0.8333, 39.81 deg -- because that is
-- the widest ray the span may ever offer. Anything further off axis at that Z is out of every line
-- of fire, at every lane and every station.
function Range.sightHalfWidthAt(layout, aheadStuds: number): number
	layout = layout or Range.LAYOUT
	return math.abs(aheadStuds) * Range.backstopSlope(layout)
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

-- HOW HIGH THE WAY DOWN'S POINT SITS over the deck's top: at the EYE of the man the climb put
-- there -- his root (`riseStuds`) plus an R15 head. DERIVED, so the prompt cannot sink under the
-- view cone again.
function Range.downPromptRiseFor(layout): number
	layout = layout or Range.LAYOUT
	return layout.CLIMB.riseStuds + layout.CLIMB.eyeOverRootStuds
end

-- THE WAY DOWN'S POINT: over the DOWNRANGE rail -- the board he rests on -- and NOT over the rail's
-- gap he stepped through, which is where the design wanted it. MEASURED in her place 2026-10-29:
-- with the point on the UPRANGE face a man looking down his own lane has it BEHIND him, the engine
-- hides it, and a real `F` then does nothing -- the same defect task 308 measured for the RANGE
-- prompt (*"a HIDDEN prompt does not answer its key"*). The downrange rail is in front of his eye
-- whenever he is looking at the lane, which is the whole of when he wants to come down.
-- AND AT HIS EYE AND NOT AT HIS KNEE, which is the 306k fix and was ARITHMETIC before it was a
-- frame: at `deckRise` 1.6 the point sat 3.4 studs under the eye 2.9 studs in front of it -- 49
-- degrees below a view held down the lane, where a 70-degree FOV reaches 35 -- so it was off the
-- bottom of the screen, undrawn, and real `F` did nothing (playtest/range-v2 item 4, frames
-- 28/29/30). `range_panel.spec` now projects it into Karen's own viewport.
-- It is 5.8 studs from the station's RANGE prompt in Z: still both in reach of a man on the deck,
-- which is why the two keys differ.
function Range.downPromptPosition(anchor: Vector3, spot: number, layout, downrange: number?, deckTop: number?): Vector3
	layout = layout or Range.LAYOUT
	local dir = if downrange == -1 then -1 else 1
	local deck = Range.standPosition(anchor, spot, layout, dir)
	local top = if type(deckTop) == "number" then deckTop :: number else anchor.Y + HighSeats.DIMS.DECK_RISE_STUDS
	return Vector3.new(deck.X, top + Range.downPromptRiseFor(layout), deck.Z + dir * HighSeats.DIMS.RAIL_PLANE_STUDS)
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
--
-- ...OR AS FAR AS ITS OWN WAY DOWN, WHICHEVER IS FURTHER, AND THAT IS A READING (306k item 3, her
-- place, 2026-10-29): a real `F` on Stand2's deck put the man at z -3009 with the box ending at
-- -3010.9, so `mayShoot` answered false where his own ladder had just left him -- the loan was
-- revoked and he landed with an EMPTY backpack, no Rifle, no Shotgun. 19.10 against the 21 the way
-- down needs. A station that does not reach where it sets a man down is the bug, not the margin.
function Range.standReach(layout): number
	layout = layout or Range.LAYOUT
	local feet = layout.STAND.backStuds + HighSeats.footprintRadiusStuds()
	local wayDown = layout.STAND.backStuds + math.abs(HighSeats.DIMS.LADDER_OFFSET_STUDS) + layout.CLIMB.footClearStuds
	return math.max(feet, wayDown)
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

-- AND THE WAY BACK: WHICH CHIP AN EFFECTIVE DISTANCE WAS PICKED FROM. `distanceFor` adds
-- `STAND.backStuds` on the deck, so a record made there carries 139 while the menu's chips are
-- 107 / 125 / 179 -- and NONE of them lit (playtest/range-v2, "seen by accident": *"the DISTANCE
-- row loses its selection on the deck"*, 23-deckmenu.png). This is that addition undone, so the
-- menu and the board read one pick. PURE, and the inverse is exact because the term is a constant.
function Range.distancePickOf(record: any, layout): number?
	layout = layout or Range.LAYOUT
	local studs = if type(record) == "table" then record.distanceStuds else record
	if type(studs) ~= "number" then
		return nil
	end
	local position = if type(record) == "table" then record.position else nil
	if position == Range.POSITION.TREESTAND then
		return (studs :: number) - layout.STAND.backStuds
	end
	return studs :: number
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
