--!strict
-- Hud.Objective: THE ONE WRITER of the objective LINE and of the WAYPOINT chevron, and the only
-- thing in this repo that turns a world point into a place on the SCREEN.
--
-- KAREN, 2026-10-12: *"we need to have better map or direction that people has to walk we need to
-- improve design that it will be clear to understand what happening"*.
--
-- THE FINDING THE NOTE OPENS WITH, because it is the whole reason this file exists: EVERYTHING ON
-- SCREEN BEFORE THIS TASK WAS A FACT AND NOTHING WAS AN INSTRUCTION. The drive bar says
-- `DRIVE 1   04:51   BOARS 6   SHOOTER` and never says *stay on your stand*; the compass says the
-- drive is north and never says *that is 400 m away and this is the way you walk*. The start card
-- (task 158) is the only element that ever instructed, and it is up for ten seconds in one phase.
--
-- ONE LINE AND ONE MARK ARE ONE ANSWER RENDERED TWICE -- "what must I do" and "where" -- which is
-- why they are one module and not two (design section 4.1). Splitting them would make two readers of
-- one target, which is the failure task 153 round 2 already paid for: *"a marker that moved without
-- its label told a beater the drive was south"*.
--
-- IT IS NOT ITS OWN SCREEN. `Hud.build` creates the three nodes with the rest of the HUD, for the
-- reason `Compass`, `ReportPanel` and `MapUi` all give in their own headers: one ScreenGui, built
-- once, so a visibility audit has one place to look. This module fills them and writes nothing
-- outside them.
--
-- NO `BillboardGui` AND NO INSTANCE IN `Workspace`. A billboard needs an `Adornee`, so the Hud would
-- have to create a part in the world -- a second writer of the world, for a mark that is pure UI.
-- The chevron is projected by hand instead (`Objective.project`), which also makes it PURE: the
-- arithmetic is a spec and not a screenshot.
--
-- IT DECIDES NOTHING. It fires no remote, writes no camera, moves no character and holds no rule:
-- the phase is the server's, the team is `Player.Team`'s, the geometry is the world's and the view is
-- `Camera`'s. Everything is handed in.
--
--   Camera.FieldOfView  https://create.roblox.com/docs/reference/engine/classes/Camera#FieldOfView
--     the VERTICAL angle, which is what makes `Objective.project` exact at any viewport -- the same
--     fact `Hud.reticleDegToPx` already rests on.
--   CFrame:PointToObjectSpace  https://create.roblox.com/docs/reference/engine/datatypes/CFrame
--   TextLabel.TextFits  https://create.roblox.com/docs/reference/engine/classes/TextLabel#TextFits
--     so "the sentence fits a phone" is measured by the engine rather than guessed from a font.
--
-- Design: docs/design/hud-clarity.md (sections 5, 5.1-5.4)
-- Note:   docs/research/2026-10-12-hud-clarity.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Report = require(ReplicatedStorage:WaitForChild("Report"))

local Objective = {}

-- WHERE THE PLAYER MUST BE, as data. `word` is what the screen says and `kind` is what a spec and the
-- colour read, because "STAND" is a sentence and "stand" is a case.
export type Target = {
	point: Vector3,
	word: string,
	kind: string,
}

-- Every number and every word here is a layout or wording choice and they are together so a retune
-- is one block -- the `Compass.CONFIG` / `MapUi.CONFIG` shape.
Objective.CONFIG = {
	-- ---------------- the line
	--
	-- THE TOP LINE OF THE SCREEN, and everything else in the top band moved down one band to make
	-- room (design section 3): bar 44..70, tied banner 74..104, compass 108..134, map 140. The
	-- objective is the headline, so it is read first and it is biggest.
	TOP = 8,
	HEIGHT = 32,
	SIDE_MARGIN = 16, -- so the label is viewport-wide less this on each side, at any width
	-- 24 ON A SCREEN, 18 ON A PHONE, AND ONE BREAK POINT. The bar is 20 and the compass 13, so 24
	-- reads first; below 700 px wide a 32-character sentence at 24 does not fit, and
	-- `hud_clarity.spec` asserts that with the engine's own `TextFits` rather than a font guess.
	TEXT_SIZE = 24,
	TEXT_SIZE_SMALL = 18,
	SMALL_BELOW_PX = 700,
	TEXT_COLOR = Color3.fromRGB(255, 255, 255),
	TEXT_STROKE = 1,
	-- The compass's band: over the feed and the bar (1), under the scope's mask (11-13) and under the
	-- report and the score board (15). Top-band furniture, stacked with the rest of it.
	Z_INDEX = 6,

	-- ---------------- the mark
	--
	-- A SMALL CHEVRON, NOT A BILLBOARD. theHunter: Call of the Wild's own players ask for theirs to
	-- be smaller (*"massive and orange"*), so this is a 14 px rotated square -- the technique the
	-- compass's marker uses, with no asset and no upload.
	MARK_PX = 14,
	MARK_LABEL_SIZE = 11,
	MARK_LABEL_GAP = 12, -- the word sits under the chevron
	MARK_COLOR = Color3.fromRGB(235, 90, 55), -- `Compass.CONFIG.DRIVE_COLOR`, the game's "go here" red
	-- UNDER THE FURNITURE. A mark that crosses the whole screen must pass BEHIND the compass and the
	-- map rather than scribble on them, and over the feed and the bar.
	MARK_Z_INDEX = 5,
	-- A MARK OUT OF VIEW IS PINNED TO THE EDGE, NOT HIDDEN -- `Compass.offsetPx`'s rule (*"so 'it is
	-- behind me and to the left' still has an answer"*) and `MapUi.project`'s. Pinned is DIMMER, so
	-- pinned and real are not the same picture.
	PINNED_TRANSPARENCY = 0.45,
	-- 56 ON THREE SIDES AND 68 ON THE RIGHT, and the odd one out is not a taste: the button rail's
	-- column is 68 px wide (`Rail.CONFIG.BUTTON_PX` 48 + margin 12 + 8), so a chevron pinned at 56
	-- would sit under the RELOAD button.
	INSET_PX = 56,
	INSET_RIGHT_PX = 68,

	-- ---------------- arrival
	--
	-- IN AT 24 STUDS, OUT AT 30, AND THE DEAD BAND IS THE POINT. `ForestTest.PICK.standRadiusStuds`
	-- is 12 since task 166 -- a hunter may legally walk anywhere within 12 studs of his stand -- so
	-- 24 is twice that, and a 6-stud band means walking about ON the stand cannot flicker the chevron
	-- on and off. BOTH NUMBERS FOLLOWED THE RADIUS when it went from 6 to 12 (they were 12 and 18):
	-- an "arrived" ring INSIDE the circle a hunter may legally walk in would flicker at exactly the
	-- place he is meant to be standing. Arrived means no chevron and no compass takeover: the strip
	-- goes back to saying where the drive comes FROM, which is what a hunter standing on his stand is
	-- actually watching.
	ARRIVED_IN_STUDS = 24,
	ARRIVED_OUT_STUDS = 30,

	-- ---------------- the words
	--
	-- ASCII, A HYPHEN AND NEVER AN EM DASH, like everything else drawn in this repo. FIRST VALUES:
	-- the wording is Karen's to rewrite and the only constraint the code imposes is 32 characters,
	-- which `hud_clarity.spec` measures with `TextFits`.
	--
	-- THEY LIVE HERE AND NOT IN `Drive.CONFIG`, which is the design's one named deviation from the
	-- brief (section 1.2): the repo's real rule is one word table per DRAWER --
	-- `Compass.CONFIG.DRIVE_LABEL`, `MapUi.CONFIG`'s `"MAP"` and `"%d m"`, `Report.CONFIG` -- and
	-- `src/shared/Drive/` is in `TWO_PLAYER_PATHS`, so a sentence kept there could not be retuned
	-- without a two-player run and a human click. These are sentences Karen is going to move.
	TEXT = {
		Shooters = {
			Assigning = "get to your stand",
			Running = "stay on your stand, boars coming",
			Scoring = "drive over",
		},
		Drivers = {
			Assigning = "wait for the horn",
			Running = "walk to the road, push the boars",
			Scoring = "drive over",
		},
		-- THE BEATER'S FOUR TASK-168 LINES, and every one of them is a sentence Karen asked for in
		-- her own words (2026-10-12 ~21:45). They are rows here rather than branches in `text`
		-- because they are WORDS -- hers to rewrite, like every other row in this table.
		--
		-- `%d` IS THE COUNTDOWN and the only format in this table: *"there should be countdown"*.
		-- It counts the `Assigning` phase down, which is the same deadline the start card's timer and
		-- the hunter's stand timer count (task 158's one number), so the three cannot disagree.
		DriverCountdown = "drive starts in %d",
		-- THE FANFARE IS SOUNDING AND THE LINE IS STILL HELD: *"you can't move as a beater before
		-- horn made signal"*. GO is the END of the phrase, so there are two seconds of drive in which
		-- a beater is free to wonder why he cannot walk, and this is the answer to that.
		DriverHorn = "hold the line - horn sounding",
		-- ...AND THEN GO, for `GO_FLASH_SECONDS` (the Director's *"GO -- push toward the road"*),
		-- after which the standing instruction above takes the line back.
		DriverGo = "GO - push to the road",
		-- HIS DRIVE IS OVER: *"when beater cross the line of hunter it's done for him cant use sound
		-- anymore"*. The horn is refused by the server; this is the only thing that says why.
		DriverThrough = "you are through - wait",
		-- WITH A TEAM AND NO DRIVE YET it says so, in one short sentence with NO REASON attached: the
		-- drive bar already carries the reason (`WAITING players`), and two renderings of one reason
		-- is the duplication this task exists to remove.
		Waiting = "waiting for the drive to start",
	},

	-- THE THREE WORDS A TARGET CAN WEAR. `STAND` is a post the world has actually stated; `LINE` is
	-- the road offered to a hunter in a world that has stated no posts (design 5.2, 12.1) -- the
	-- screen never claims to know more than the world said; `ROAD` is the beater's, and it is
	-- `ForestTest.PUSH_LABEL`'s own word so the chevron, the compass and the map all say one thing.
	WORD_STAND = "STAND",
	WORD_LINE = "LINE",
	WORD_ROAD = "ROAD",

	-- HOW LONG `GO` IS ON SCREEN (task 168). Long enough to read and to connect to the fanfare that
	-- has just finished, short enough that a ten-minute drive is not spent being told to start: after
	-- it the line goes back to the standing instruction. It is a WORDS number, not a rule, so it
	-- lives with the words.
	GO_FLASH_SECONDS = 5,
}

-- ---------------------------------------------------------------- the arithmetic, pure

-- THE ONE SENTENCE, or "" for "draw nothing". PURE over the phase and the team, which is what lets
-- `hud_clarity.spec` assert all eight rows with no drive, no world and no wire -- the shape
-- `Hud.startCardLines` and `Hud.crosshairVisible` already have, and for the same reason: a drive is
-- 600 seconds long, so no harness run reaches `Scoring`.
--
-- NO TEAM, NO SENTENCE, IN EVERY PHASE. A player with no team has no objective, and a line would be
-- an instruction nobody gave. `Hud.roleWord` already answers `""` for the same case.
--
-- IT NEVER CARRIES THE DISTANCE. That belongs to the chevron, which is where the eye already is when
-- it asks "how far".
-- `drive` IS WHAT THE DRIVE IS DOING RIGHT NOW, and every field of it is optional (task 168): two
-- arguments still answer exactly what they answered before this task, which is what keeps the eight
-- role-by-phase rows one table lookup. Nothing here reads a clock -- the caller subtracts the server
-- timestamps (`Match.holdSecondsLeft`, `Match.goAgeSeconds`), so this function stays pure and
-- `hud_clarity.spec` drives every branch with numbers.
export type DriveNow = {
	secondsLeft: number?, -- until THIS phase ends (the countdown, in `Assigning`)
	holdLeft: number?, -- until the beaters may walk; > 0 means the fanfare is still sounding
	goAge: number?, -- since they were let go, or nil for "they have not been"
	through: boolean?, -- this player is past the hunters' line and his drive is over
}

function Objective.text(phase: string?, team: string?, drive: DriveNow?): string
	if team ~= "Shooters" and team ~= "Drivers" then
		return ""
	end
	local words = Objective.CONFIG.TEXT
	if phase == "Waiting" then
		return words.Waiting
	end
	local byPhase = words[team]
	if byPhase == nil or phase == nil then
		return ""
	end
	-- THE BEATER'S OWN FOUR MOMENTS (task 168), in the order they can be true: through the line beats
	-- everything, then the countdown, then the fanfare, then GO. A hunter reaches none of them, and a
	-- beater in a world that tells the screen nothing (`drive == nil`) falls through to the row.
	if team == "Drivers" and drive ~= nil then
		if drive.through == true and phase == "Running" then
			return words.DriverThrough
		end
		if phase == "Assigning" and drive.secondsLeft ~= nil then
			return string.format(words.DriverCountdown, math.max(0, math.ceil(drive.secondsLeft)))
		end
		if phase == "Running" then
			if (drive.holdLeft or 0) > 0 then
				return words.DriverHorn
			end
			if drive.goAge ~= nil and drive.goAge <= Objective.CONFIG.GO_FLASH_SECONDS then
				return words.DriverGo
			end
		end
	end
	return byPhase[phase] or ""
end

-- WHICH SIZE AT WHICH WIDTH. One break point, in one place, so "does it fit a phone" has one answer.
function Objective.textSizeFor(viewportX: number): number
	local config = Objective.CONFIG
	return if viewportX < config.SMALL_BELOW_PX then config.TEXT_SIZE_SMALL else config.TEXT_SIZE
end

-- THE LINE'S RECTANGLE at a given viewport: x, y, width, height. PURE AND EXPORTED, because the
-- existing overlap case in `map_ui.spec` measures `AbsolutePosition` at whatever size the Studio
-- window happens to be and therefore cannot answer for 400 x 800 -- and 400 x 800 is the claim Karen
-- is being asked to believe. Arithmetic can answer for any viewport.
function Objective.lineRect(viewport: Vector2): (number, number, number, number)
	local config = Objective.CONFIG
	return config.SIDE_MARGIN, config.TOP, math.max(0, viewport.X - 2 * config.SIDE_MARGIN), config.HEIGHT
end

-- WHERE THE ROAD IS AT A GIVEN x, off the polyline the map already holds. The road is sampled in x
-- (33 samples in the Forest Test, two in DEV -- `MapUi.geometryFromForestTest` /
-- `geometryFromMap`), so this is a linear interpolation along it and NOT a second copy of the sine:
-- a map that re-typed the curve would be a second curve that disagrees with the first the next time
-- the Director bends the road (`MapUi.geometryFromForestTest`'s own words).
--
-- PAST EITHER END, x IS CLAMPED TO THE POLYLINE'S RANGE, so a beater who has walked off the end of
-- the world is sent back to the end of the line rather than to a point that does not exist.
function Objective.roadZAt(road: { Vector2 }, x: number): number?
	if road == nil or #road == 0 then
		return nil
	end
	if #road == 1 then
		return road[1].Y
	end
	local first, last = road[1], road[#road]
	-- The samples may run either way in x, so the ends are compared rather than assumed.
	local lowX, lowZ = first.X, first.Y
	local highX, highZ = last.X, last.Y
	if lowX > highX then
		lowX, lowZ, highX, highZ = highX, highZ, lowX, lowZ
	end
	if x <= lowX then
		return lowZ
	end
	if x >= highX then
		return highZ
	end
	for index = 1, #road - 1 do
		local a, b = road[index], road[index + 1]
		local minX, maxX = math.min(a.X, b.X), math.max(a.X, b.X)
		if x >= minX and x <= maxX then
			local span = b.X - a.X
			if math.abs(span) < 1e-9 then
				return a.Y
			end
			local t = (x - a.X) / span
			return a.Y + t * (b.Y - a.Y)
		end
	end
	return highZ
end

-- THE NEAREST STAND to a position, in the flat plane. nil when the world has stated none.
function Objective.nearestStand(stands: { Vector2 }, me: Vector3): Vector2?
	local best: Vector2? = nil
	local bestDistance = math.huge
	for _, stand in ipairs(stands or {}) do
		local dx, dz = stand.X - me.X, stand.Y - me.Z
		local distance = dx * dx + dz * dz
		if distance < bestDistance then
			bestDistance = distance
			best = stand
		end
	end
	return best
end

-- THE ONE PLACE THIS PLAYER MUST BE, or nil. PURE over geometry it did not fetch, so a spec hands it
-- a table (design 5.2).
--
-- NO WALKING IN `Waiting` OR `Scoring`: there is nowhere to go before the drive is assigned or after
-- it has ended, and a chevron then would be an instruction the game is not giving.
--
-- A WORLD THAT HAS STATED NO GEOMETRY GETS NO WAYPOINT (D5), never a guess and never a blank frame --
-- `MapUi.geometryFor`'s rule, and `docs/PROJECT_CONTEXT.md`'s *"a visibility audit certified a blank
-- screen twice"*.
--
-- "MY STAND" IS THE NEAREST STAND, AND THE FAILURE CASE IS STATED RATHER THAN HIDDEN. The drive puts
-- a hunter on a post (`Match.Body.placementFor`) and `ForestTest.STAND_SPACING` is 150 studs, so the
-- nearest one is his until he walks 75 studs along the line -- past that the chevron silently becomes
-- his neighbour's. Doing better needs the drive to publish the assigned stand index, which is a new
-- snapshot field and is refused for this task (D3); it is queued in `TASKS.md` as 165a.
--
-- A HUNTER IN A WORLD WITH NO STANDS GETS THE LINE, AND THAT IS NOT A GUESS. `Map.ROAD`'s own comment
-- is *"The road's centreline IS the drive line -- there is no second concept"*, and
-- `MapUi.geometryFromMap` returns `stands = {}` for the DEV world deliberately. Since
-- `Match.CONFIG.ODD_PLAYER_TEAM` is `"Shooters"`, A SOLO PLAYER IN DEV IS A HUNTER -- so without this
-- clause the whole feature would be inert in the world the harness runs in. The word changes from
-- `STAND` to `LINE`, so the screen never claims more than the world has said (design 12.1).
--
-- THE BEATER'S POINT IS THE ROAD AT HER OWN x -- straight down the push, so she walks FORWARD into the
-- line instead of diagonally at the mathematically nearest point. On a sine of amplitude 30 over
-- 1,600 studs the two differ by under a stud, and "walk straight ahead" is the instruction.
function Objective.targetFor(team: string?, phase: string?, geometry: any?, me: Vector3?): Target?
	if phase ~= "Assigning" and phase ~= "Running" then
		return nil
	end
	if geometry == nil or me == nil then
		return nil
	end
	local config = Objective.CONFIG
	local here = me :: Vector3
	local function roadTarget(word: string, kind: string): Target?
		local z = Objective.roadZAt(geometry.road, here.X)
		if z == nil then
			return nil
		end
		return { point = Vector3.new(here.X, here.Y, z), word = word, kind = kind }
	end
	if team == "Shooters" then
		local stand = Objective.nearestStand(geometry.stands, here)
		if stand ~= nil then
			local at = stand :: Vector2
			-- THE PLAYER'S OWN y, AND IT IS A CHOICE. `MapGeometry` is flat -- the road and the stands
			-- are `Vector2` -- so there is no ground height to put the mark at, and this world climbs
			-- 56 studs in 400 (`ForestTest.BEATER`'s measurements). At the player's own altitude a
			-- distant mark sits on the horizon, which is what a navigation marker wants; a near one
			-- can float by the slope's difference. Stated rather than hidden: the fix is a y in the
			-- geometry, which is the map's to publish and not this module's to invent.
			return { point = Vector3.new(at.X, here.Y, at.Y), word = config.WORD_STAND, kind = "stand" }
		end
		return roadTarget(config.WORD_LINE, "line")
	elseif team == "Drivers" then
		return roadTarget(config.WORD_ROAD, "road")
	end
	return nil
end

-- HOW FAR, IN STUDS, FROM THE PLAYER -- not from the camera. The player is what has to walk there.
function Objective.distanceStuds(target: Target?, me: Vector3?): number?
	if target == nil or me == nil then
		return nil
	end
	local to = (target :: Target).point
	local here = me :: Vector3
	local dx, dz = to.X - here.X, to.Z - here.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- HAS THE PLAYER ARRIVED? Hysteresis: in at `ARRIVED_IN_STUDS`, out at `ARRIVED_OUT_STUDS`, so a
-- hunter walking the 12 studs his stand allows cannot flicker the chevron.
function Objective.arrived(distanceStuds: number?, wasArrived: boolean): boolean
	local config = Objective.CONFIG
	if distanceStuds == nil then
		return false
	end
	local far = distanceStuds :: number
	if wasArrived then
		return far < config.ARRIVED_OUT_STUDS
	end
	return far <= config.ARRIVED_IN_STUDS
end

-- A WORLD POINT -> PIXELS FROM THE SCREEN CENTRE, plus whether it is really on screen.
--
-- ROBLOX'S FIELD OF VIEW IS THE VERTICAL ANGLE, which is the fact that makes this exact at any
-- viewport and at any magnification -- the same fact `Hud.reticleDegToPx` rests on. So
-- `f = (viewportY / 2) / tan(fov / 2)` and `px = f * x / -z`, and `hud_clarity.spec` compares one
-- against the other rather than copying the expression into its own case (task 129 spent three rounds
-- on a case that *"agreed with the wrong one"*).
--
-- BEHIND THE PLAYER IS A DIRECTION, NOT A POINT, and the simplification is named. A point behind the
-- camera has no honest vertical position on screen, so it pins to the left or right edge at mid
-- height: that answers "it is behind you, to your left" and claims nothing else. Dead behind
-- (`x == 0`) pins RIGHT -- arbitrary, deterministic, and asserted so it cannot drift.
--
-- CLAMPED PER AXIS, which is what pinning means on a rectangle (`MapUi.project`'s own words): a point
-- far to the left and slightly up pins to the left edge at its own height, not to a corner.
function Objective.project(point: Vector3, view: CFrame, fovDeg: number, viewport: Vector2): (number, number, boolean)
	local config = Objective.CONFIG
	local halfX = math.max(1, viewport.X / 2 - config.INSET_RIGHT_PX)
	local halfY = math.max(1, viewport.Y / 2 - config.INSET_PX)
	-- The left inset is the smaller of the two, so the box is not symmetric; it is clamped per side.
	local leftLimit = -math.max(1, viewport.X / 2 - config.INSET_PX)
	local local_ = view:PointToObjectSpace(point)
	if local_.Z >= -1e-3 then
		local side = if local_.X >= 0 then halfX else leftLimit
		return side, 0, false
	end
	local depth = -local_.Z
	local f = (viewport.Y / 2) / math.tan(math.rad(math.clamp(fovDeg, 1, 170)) / 2)
	local x = f * local_.X / depth
	local y = -f * local_.Y / depth
	local cx = math.clamp(x, leftLimit, halfX)
	local cy = math.clamp(y, -halfY, halfY)
	return cx, cy, cx == x and cy == y
end

-- IS THE LINE DRAWN? IS THE CHEVRON DRAWN? TWO PREDICATES, TWO QUESTIONS -- because the rule the
-- previous project died of is *"one predicate answered two unrelated questions, so mounting hid both
-- the crosshair and the weapon"* (`docs/PROJECT_CONTEXT.md`).
--
-- THE ONE ROW WHERE THEY DIFFER IS THE START CARD. In `Assigning` the card's own timer already reads
-- `GET TO YOUR STAND  7`, so the LINE stands down while the card is up -- two renderings of one
-- instruction, 140 px apart, for fifteen seconds. THE WAYPOINT DOES NOT stand down: the card says
-- *what* and the chevron says *where*, and the moment the card says "get to your stand" is exactly
-- the moment the player most needs the arrow.
function Objective.lineVisible(
	phase: string?,
	team: string?,
	reportOpen: boolean,
	mapOpen: boolean,
	scoped: boolean,
	startCardUp: boolean
): boolean
	if reportOpen or mapOpen or scoped or startCardUp then
		return false
	end
	return Objective.text(phase, team) ~= ""
end

function Objective.markVisible(
	target: Target?,
	reportOpen: boolean,
	mapOpen: boolean,
	scoped: boolean,
	hasView: boolean
): boolean
	if reportOpen or mapOpen or scoped then
		return false
	end
	-- NO VIEW, NO CHEVRON, and the asymmetry with the compass is deliberate. `Compass.headingFrom`
	-- keeps its last heading when the camera has not applied a frame yet, because a strip that lags
	-- by three frames is not a strip that lies. A MARK is different: a chevron drawn from a stale
	-- camera is in the wrong PLACE on the screen, which is a lie in the shape of a fact.
	return target ~= nil and hasView
end

-- THE DISTANCE LABEL, as pure text. Metres through `Report.metres`, which is the one conversion in
-- this repo (`METRES_PER_STUD = 0.28`): a second multiplication is how task 150 spent two tasks
-- comparing a radius in studs against distances in metres.
function Objective.markText(target: Target?, distanceStuds: number?): string
	if target == nil then
		return ""
	end
	local word = (target :: Target).word
	if distanceStuds == nil then
		return word
	end
	return string.format("%s  %d m", word, Report.metres(distanceStuds))
end

-- ---------------------------------------------------------------- state: one writer, this module

local lineLabel: TextLabel? = nil
local markFrame: Frame? = nil
local markLabel: TextLabel? = nil
local started = false
local suppressed = false
local lastMarkU: number? = nil
local lastMarkV: number? = nil
local markPinned = false
local stats = { renders = 0, pinned = 0, noView = 0, marks = 0 }

function Objective.stats()
	return stats
end

function Objective.isSuppressed(): boolean
	return suppressed
end

-- WHAT IS ACTUALLY ON SCREEN, for a spec: the text the label carries and where the chevron is.
function Objective.lineText(): string
	local label = lineLabel
	return if label ~= nil then label.Text else ""
end

function Objective.markOffsetPx(): (number?, number?)
	return lastMarkU, lastMarkV
end

function Objective.isMarkPinned(): boolean
	return markPinned
end

-- THE SIGHT PICTURE IS IN: a need STATED by `Hud.renderScope`, performed here, which is this repo's
-- own `Camera.Cursor.requestFree` pattern (borrowed once already by `Input.requestHold`). The
-- compass's two-writer arrangement (`compassHiddenByScope`) is deliberately NOT copied: this module
-- stays the one writer of its own nodes and nothing outside has to remember what it hid.
function Objective.setSuppressed(on: boolean)
	suppressed = on
end

function Objective.start(nodes: { line: TextLabel, mark: Frame, markLabel: TextLabel })
	if started then
		return
	end
	started = true
	lineLabel = nodes.line
	markFrame = nodes.mark
	markLabel = nodes.markLabel
end

-- THE ONE WRITER of all three nodes. Public and taking EVERYTHING, for the reason `Hud.renderScore`
-- and `MapUi.render` are public: a spec cannot turn a camera, cannot reach `Scoring` and cannot walk
-- a second player across a wood, so the only honest way to prove the picture moves is to hand it the
-- inputs.
function Objective.render(state: {
	text: string,
	target: Target?,
	distanceStuds: number?,
	view: CFrame?,
	fovDeg: number,
	viewport: Vector2,
	lineVisible: boolean,
	markVisible: boolean,
})
	stats.renders += 1
	local label = lineLabel
	if label ~= nil then
		local show = state.lineVisible and not suppressed
		label.Visible = show
		-- CLEARED, NOT JUST HIDDEN, which is `Hud.renderStartCard`'s rule: the next phase must not
		-- flash the last one's sentence for a frame.
		local text = if show then state.text else ""
		if label.Text ~= text then
			label.Text = text
		end
		local size = Objective.textSizeFor(state.viewport.X)
		if label.TextSize ~= size then
			label.TextSize = size
		end
	end

	local mark, word = markFrame, markLabel
	if mark == nil or word == nil then
		return
	end
	local frame = mark :: Frame
	local wordLabel = word :: TextLabel
	local show = state.markVisible and not suppressed
	if show and state.view == nil then
		stats.noView += 1
		show = false
	end
	if not show or state.target == nil then
		frame.Visible = false
		wordLabel.Visible = false
		lastMarkU, lastMarkV = nil, nil
		markPinned = false
		return
	end
	local u, v, onScreen =
		Objective.project((state.target :: Target).point, state.view :: CFrame, state.fovDeg, state.viewport)
	lastMarkU, lastMarkV = u, v
	markPinned = not onScreen
	stats.marks += 1
	if markPinned then
		stats.pinned += 1
	end
	local config = Objective.CONFIG
	local transparency = if markPinned then config.PINNED_TRANSPARENCY else 0
	frame.Position = UDim2.new(0.5, math.round(u), 0.5, math.round(v))
	frame.BackgroundTransparency = transparency
	frame.Visible = true
	wordLabel.Position = UDim2.new(0.5, math.round(u), 0.5, math.round(v) + config.MARK_LABEL_GAP)
	local text = Objective.markText(state.target, state.distanceStuds)
	if wordLabel.Text ~= text then
		wordLabel.Text = text
	end
	wordLabel.TextTransparency = transparency
	wordLabel.Visible = true
end

return Objective
