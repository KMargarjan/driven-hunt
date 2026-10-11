--!strict
-- Hud.MapUi: THE ONE WRITER of everything inside the `MiniMap` and `FullMap` frames, and the only
-- thing in this repo that turns a world position into a place on a map.
--
-- KAREN, 2026-10-11: *"I am missing map, we need a map when click M where will be hunter position
-- where they stand and what direction to move also can see other players on map moving / and small
-- map in left or right corner circle like is on another games hwere showing where to move ect"*.
-- Six things: a key, the stands, the direction to move, other players moving live, a small ROUND
-- corner map, and it should read like the maps in other games.
--
-- NO `ViewportFrame` AND NO MAP IMAGE, AND THE REASON IS AN ENGINE FACT RATHER THAN A PREFERENCE.
-- A `ViewportFrame` cannot render Terrain -- *"You can't put Terrain instances under ViewportFrame,
-- in which objects have to be parented under it to render"*, an open feature request since 2019 --
-- and the ground is Terrain in BOTH of this game's worlds (a bought terrain in the Forest Test,
-- `MapGen.Ground`'s painted materials in DEV). The option the official Roblox docs recommend FIRST
-- for exactly this use case would therefore draw 831 floating tree meshes over a transparent void,
-- which is the blank screen `docs/PROJECT_CONTEXT.md` records being certified twice. So the map is
-- PROJECTED from the numbers the server already places the road, the stands and the beaters from --
-- `ForestTest.roadZ`, `ForestTest.standPosition` -- which is the one option that cannot be wrong
-- about where they are.
--   https://devforum.roblox.com/t/add-terrain-support-rendering-from-outside-its-parental-structure-for-viewportframe/219346
--
-- IT IS NOT ITS OWN SCREEN. `Hud.build` creates both frames with the rest of the HUD, for the reason
-- `Compass` and `ReportPanel` both give in their own headers: one ScreenGui, built once, so a
-- visibility audit has one place to look. This module fills them and writes nothing outside them.
--
-- NORTH UP, NOT ROTATING, AND THAT IS RULE 3 AND NOT TASTE. A rotating map needs the view's heading,
-- and `Hud.Compass` already owns that question -- it reads `Camera.viewHeadingDeg`, and THREE rounds
-- of task 125 went into getting that one source right (`CurrentCamera.CFrame` measured 180 degrees
-- out; the character's own look does not turn in first person). A second module deriving the same
-- heading is how that bug comes back. The player's own marker carries a facing WEDGE instead, drawn
-- from the heading the camera system publishes.
--
-- ONE FIXED PIXEL SPACE PER DRAWER, AND ONE `UIScale` TO FIT THE SCREEN. Every offset inside a map
-- -- the road, the stands, the markers, the arrow -- is written in that drawer's own pixel space,
-- which is decided once at build time and never changes. A different viewport changes ONE number
-- (`UIScale.Scale`) and nothing is re-projected or rebuilt. That is why `MapView` is constant after
-- `setGeometry` and why a resize cannot leave a stale road behind.
--
--   Research note: docs/research/2026-10-11-map-ui.md
--   Design:        docs/design/map-ui.md
--   Frame      https://create.roblox.com/docs/reference/engine/classes/Frame
--   UICorner   https://create.roblox.com/docs/reference/engine/classes/UICorner
--   UIScale    https://create.roblox.com/docs/reference/engine/classes/UIScale
--   ContextActionService  https://create.roblox.com/docs/reference/engine/classes/ContextActionService
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))
local Report = require(ReplicatedStorage:WaitForChild("Report"))

local MapUi = {}

-- The one action this module binds. The `DrivenHunt.Map.` prefix is reserved, so a grep for it finds
-- every binding this module owns -- the shape `Weapon.Input` and `ReportPanel` both use.
local TOGGLE = "DrivenHunt.Map.Toggle"

-- ---------------------------------------------------------------- the numbers (design section 14)

-- Every number here is a layout or range choice and they are together so a retune is one diff --
-- the `Compass.CONFIG` shape.
MapUi.CONFIG = {
	-- TWO SWITCHES THAT ARE NOT FLAGS, matching `Shotgun.CONFIG.CROSSHAIR_ENABLED` and
	-- `Drive.CONFIG.SCOREBOARD_ENABLED`, which this repo already turns features off with in one
	-- line. Design section 15 is why this path carries no `Flags` row at all: a map covers no
	-- existing pixel and changes no existing rule, `Compass` (125) and `ReportPanel` (124) are two
	-- for two on shipping un-flagged, and an `expires` date in the past fails the harness -- a real
	-- cost for no OFF-state question.
	MINIMAP_ENABLED = true,
	BUTTON_ENABLED = true,

	-- ---------------- the minimap: a small round map, always on, top right
	--
	-- Karen: *"small map in left or right corner circle"*. The Director chose RIGHT -- the left is
	-- the event feed's side and the right is where the ammo readout already trained her eye.
	MINIMAP_DIAMETER_PX = 150, -- the drawer's OWN pixel space, and 7.8 % of a 1080p width on screen
	MINIMAP_MIN_PX = 96, -- 24 % of a 400 px phone, which is under the quarter the note promised
	MINIMAP_VIEWPORT_FRACTION = 0.22, -- of min(viewportX, viewportY); 1080p resolves to the full 150
	-- SIX PIXELS UNDER THE COMPASS, AND THAT IS THE ONE LAYOUT DECISION THAT IS NOT LITERALLY "THE
	-- CORNER". Task 125 round 2 shipped the compass strip over the drive bar and *"it was not seen
	-- because the frames were taken in the Forest Test, where there is no bar at all"*. The drive
	-- bar is a 520 px CENTRED frame and the compass a 360 px centred one, so at a ~400 px phone
	-- width those two span the WHOLE width: a disc at y 8 would sit on the clock in every world that
	-- has a drive, and at 1080p it would not -- which is exactly how that bug hid. The HUD's top
	-- band is 8..102 (bar 8..34, tied banner 44..74, compass 76..102) and 108 clears all of it at
	-- every width.
	MINIMAP_TOP = 108,
	MINIMAP_MARGIN = 12,
	-- HOW FAR IT SEES, as a radius. 300 studs is 84 m at 0.28 m/stud and TWO stand spacings
	-- (`ForestTest.STAND_SPACING` 150), so a beater walking in sees the road and at least two stands
	-- before she reaches them.
	MINIMAP_RANGE_STUDS = 300,

	-- ---------------- the full map: a panel on M
	--
	-- The panel is built at a FIXED pixel size that holds the world's whole span at one scale, and a
	-- `UIScale` fits it to the screen. 1080p leaves 108 above and 272 below.
	FULL_MAX_WIDTH_PX = 1100,
	FULL_MAX_HEIGHT_PX = 700,
	FULL_TOP = 108, -- the same top line as the minimap
	FULL_SIDE_INSET = 24,
	FULL_BOTTOM_INSET = 48, -- clears the ammo readout's own 40
	-- BELOW THIS THERE IS NO ROOM FOR A MAP AT ALL and it is said out loud once, rather than drawn as
	-- a squashed rectangle: a decision instead of an accident.
	FULL_MIN_HEIGHT_PX = 240,
	FULL_PADDING = 14,
	FULL_TITLE_HEIGHT = 20,
	FULL_FOOTER_HEIGHT = 24,

	-- ---------------- the geometry
	GEOMETRY_MARGIN_STUDS = 60, -- the road's +-30 amplitude plus a body's room
	-- 33 SAMPLES over 1,600 studs is a 50-stud chord on a 440-stud-wavelength, 30-amplitude sine:
	-- the worst chord error is under 2 studs, which at the full map's ~0.6 px/stud is ONE pixel. A
	-- finer sample buys nothing visible and costs frames.
	ROAD_SAMPLES = 33,

	-- ---------------- how often
	--
	-- 20 Hz, AND THE COMPASS'S PER-FRAME `RenderStepped` IS NOT A PRECEDENT FOR IT: a compass tracks
	-- the VIEW, which turns as fast as a mouse moves, and a map tracks POSITIONS. A Roblox Humanoid
	-- walks 16 studs a second, so 0.8 studs per tick -- 0.2 px on the minimap and 0.5 px on the full
	-- map. Under one pixel either way, and two thirds less work on the device that has least of it.
	-- The facing wedge reads the VIEW at this rate too, so it lags a turn by up to 50 ms: accepted
	-- and stated, because the wedge answers "which way am I pointing", not "aim with this".
	TICK_HZ = 20,

	-- ---------------- the input
	--
	-- `M` IS KAREN'S KEY, and it is free: the only two `BindAction` callers in `src/` are
	-- `Weapon.Input` (MouseButton1/2, R, X and their gamepad twins) and `ReportPanel` (Tab,
	-- Backspace, Return, the four arrows). ESCAPE IS NOT BOUND and cannot be -- it belongs to the
	-- Roblox menu, which `ReportPanel.bind` says in its own comment -- so M closes the map too.
	TOGGLE_KEY = Enum.KeyCode.M,
	BUTTON_PX = 48, -- over the ~44 px thumb target
	BUTTON_GAP = 8,

	-- ---------------- what things look like
	--
	-- Dark enough to read against sunlit grass as well as sky, which is the one requirement a HUD
	-- element in this world actually has: the drive report learned it the hard way in task 124
	-- (0.25 over an arena is see-through over a forest).
	BACKGROUND = Color3.fromRGB(16, 18, 20),
	MINIMAP_TRANSPARENCY = 0.2, -- the compass strip's own number
	PANEL_TRANSPARENCY = 0.25, -- the score panel's, which Karen has accepted
	RIM_COLOR = Color3.fromRGB(230, 230, 230),
	RIM_THICKNESS = 2,
	TEXT_COLOR = Color3.fromRGB(255, 255, 255),
	LABEL_SIZE = 11,
	TITLE_SIZE = 14,

	-- THE ROAD is the hunters' line and the thing everything else is read against.
	ROAD_COLOR = Color3.fromRGB(190, 182, 164), -- the same family as `Map.PALETTE.road`
	ROAD_PX = 3,

	-- EACH HUNTER STAND. A SQUARE, so a stand is not a player.
	STAND_PX = 6,

	-- THE PLAYERS.
	MARKER_PX = 8,
	OWN_MARKER_PX = 10,
	-- ...AND WHICH WAY YOU ARE LOOKING, so the map does not have to turn to answer it.
	WEDGE_PX = 3,
	WEDGE_LENGTH_PX = 9,
	WEDGE_OFFSET_PX = 8,
	-- WHICH WAY TO GO: one bar and one word, which is the compass's own marker shape -- and for the
	-- reason task 153 round 2 found, that a marker which moved without its label told a beater the
	-- drive was south.
	ARROW_PX = 3,
	ARROW_LENGTH_PX = 40,
	-- A MARKER OUT OF RANGE IS PINNED TO THE BORDER, NOT HIDDEN. `Compass.offsetPx`'s own rule --
	-- *"so 'it is behind me and to the left' still has an answer"* -- and also the rule Etheroit's
	-- open minimap GUI states (*"pinned ... will stick on the border instead of disappearing"*).
	-- Pinned is DIMMER, so pinned and real are not the same picture.
	PINNED_TRANSPARENCY = 0.45,
	MAX_MARKERS = 16, -- docs/PROJECT_CONTEXT.md: 10-16 players

	-- THE SCALE BAR, in metres, because a map with no scale is a diagram. The largest choice whose
	-- bar fits this fraction of the canvas.
	SCALE_BAR_CHOICES_M = { 25, 50, 100, 200, 500 },
	SCALE_BAR_FRACTION = 0.4,

	-- THE STACK, against the one task 141 set: the feed and the drive bar at 1, the compass at 6-10,
	-- the scope's mask at 11-13, the drive report and the score board at 15. The whole map lives in
	-- 6..9 -- under the mask, under the report, over the feed and the bar. It shares numbers with
	-- the compass's band and that decides nothing, because the two never share a pixel and
	-- `map_ui.spec` asserts that by rectangle intersection rather than promising it in prose.
	Z_INDEX = 6,
}

-- WHERE THE MAP'S COLOURS COME FROM: three of `Drive.CONFIG`'s own and the compass's marker colour.
-- Read, never re-typed, so the map and the score board can never disagree about which team is blue.
MapUi.COLORS = {
	own = Drive.CONFIG.SCORE_HIGHLIGHT_COLOR, -- your own row on the score board
	Drivers = Drive.CONFIG.DRIVER_COLOR, -- the drive bar's DRIVER badge
	Shooters = Drive.CONFIG.SHOOTER_COLOR, -- the drive bar's SHOOTER badge
	none = Drive.CONFIG.TEXT_COLOR,
	stand = Drive.CONFIG.SHOOTER_COLOR, -- a stand is a hunter's place, so it wears their colour
	arrow = Color3.fromRGB(235, 90, 55), -- `Compass.CONFIG.DRIVE_COLOR`
}

export type Bounds = { minX: number, maxX: number, minZ: number, maxZ: number }
export type ClipShape = "rect" | "disc"

export type MapView = {
	centreX: number,
	centreZ: number,
	pxPerStud: number, -- ONE scale for both axes. A map with two scales lies about distance.
	halfWidthPx: number,
	halfHeightPx: number,
	shape: ClipShape,
}

export type MapGeometry = {
	world: string,
	bounds: Bounds,
	road: { Vector2 }, -- the hunters' line as a polyline of (x, z), in x order
	stands: { Vector2 }, -- one point per stand, in index order. MAY BE EMPTY.
}

export type MarkerSource = { userId: number, team: string?, position: Vector3? }
export type MarkerPoint = {
	userId: number,
	u: number,
	v: number,
	pinned: boolean,
	mine: boolean,
	team: string?,
}

-- ---------------------------------------------------------------- the arithmetic, pure

-- WHERE A WORLD POINT LANDS, in pixels from the view's own centre, NORTH UP -- WITHOUT any clamping.
--
-- THE CONVENTION IS THIS GAME'S AND NOT A NEW ONE. North is +Z and bearings run clockwise through
-- east (+X): `Compass.headingDeg` fixes it with `atan2(x, z)` and says why the other order is *"a
-- compass that is always wrong by one cardinal, which is worse than no compass"*, and
-- `Camera.headingOfLookDeg` was settled against a PHOTOGRAPH of four neon posts. North up therefore
-- means exactly +Z is -v (up the screen) and +X is +u -- ONE minus sign, in one place, here. Getting
-- that sign wrong is a map mirrored north-for-south, which reads as a map that works until the first
-- time you trust it.
--
-- THE RAW ANSWER EXISTS SEPARATELY BECAUSE THE GEOMETRY MUST NOT BE PINNED. A clamped road sample
-- would bend the road along the border instead of leaving the frame; the road leaves the frame
-- through `ClipsDescendants` and only MARKERS are pinned.
function MapUi.rawOffsetPx(worldX: number, worldZ: number, view: MapView): (number, number)
	return (worldX - view.centreX) * view.pxPerStud, -(worldZ - view.centreZ) * view.pxPerStud
end

-- ...AND THE PINNED ANSWER, which is what a marker gets: the position to draw at, and whether the
-- point is really in view. A caller that gets `false` has somebody beyond the edge and dims the
-- marker rather than hiding it -- `Compass.offsetPx`'s rule and Etheroit's minimap GUI's.
--
-- The rect is clamped PER AXIS, because on a rectangle that is what pinning means: a player far to
-- the west and slightly north pins to the west edge at their own latitude, not to a corner.
--
-- PURE AND EXPORTED, which is the whole point: a spec asserts the projection with hand-written
-- studs, no world, no camera and no player. `docs/PROJECT_CONTEXT.md`'s *"things measured correct and
-- looked wrong"* is survivable only when the arithmetic is provable and the LOOK is the one thing
-- left for Karen's eye.
function MapUi.project(worldX: number, worldZ: number, view: MapView): (number, number, boolean)
	local u, v = MapUi.rawOffsetPx(worldX, worldZ, view)
	if view.shape == "disc" then
		local radius = view.halfWidthPx
		local distance = math.sqrt(u * u + v * v)
		if distance > radius and distance > 1e-9 then
			return u / distance * radius, v / distance * radius, false
		end
		return u, v, distance <= radius
	end
	local cu = math.clamp(u, -view.halfWidthPx, view.halfWidthPx)
	local cv = math.clamp(v, -view.halfHeightPx, view.halfHeightPx)
	return cu, cv, cu == u and cv == v
end

-- A BEARING TO AN OFFSET IN PIXELS: the inverse of `project`'s convention, and the ONLY place it is
-- written. `GuiObject.Rotation` is clockwise from "up", so a glyph drawn pointing up needs
-- `Rotation = bearingDeg` with no sign flip -- a bar rotated clockwise by 90 points east, which is
-- bearing 90. `map_ui.spec` asserts all four cardinals against `Compass.headingDeg` of the same
-- vector, so the two conventions are COMPARED and not copied: task 129 spent three rounds on a case
-- that copied the expression under test into itself and *"agreed with the wrong one"*.
function MapUi.facingOffsetPx(bearingDeg: number, radiusPx: number): (number, number)
	local radians = math.rad(bearingDeg)
	return math.sin(radians) * radiusPx, -math.cos(radians) * radiusPx
end

-- THE MINIMAP'S VIEW: centred on the player, round, `rangeStuds` to the rim. Its pixel space is the
-- CONFIGURED diameter, never the on-screen one, so a resize scales the picture and changes no
-- arithmetic.
function MapUi.minimapView(centre: Vector3, diameterPx: number, rangeStuds: number): MapView
	local radius = diameterPx / 2
	return {
		centreX = centre.X,
		centreZ = centre.Z,
		pxPerStud = if rangeStuds > 0 then radius / rangeStuds else 1,
		halfWidthPx = radius,
		halfHeightPx = radius,
		shape = "disc",
	}
end

-- THE FULL MAP'S VIEW: fixed on the geometry's own centre, rectangular, and ONE scale -- the smaller
-- of the two fits, so nothing is cut off and nothing is stretched.
function MapUi.fullView(bounds: Bounds, widthPx: number, heightPx: number): MapView
	local spanX = math.max(bounds.maxX - bounds.minX, 1)
	local spanZ = math.max(bounds.maxZ - bounds.minZ, 1)
	local pxPerStud = math.min(widthPx / spanX, heightPx / spanZ)
	return {
		centreX = (bounds.minX + bounds.maxX) / 2,
		centreZ = (bounds.minZ + bounds.maxZ) / 2,
		pxPerStud = pxPerStud,
		-- THE VIEW'S OWN EXTENT IS WHAT THE GEOMETRY FILLS, not the box it was offered: with one
		-- scale the shorter axis has air either side of it, and a marker pinned to `heightPx / 2`
		-- when the map only reaches `spanZ * pxPerStud / 2` would be pinned outside the map it is
		-- supposed to be on the edge of.
		halfWidthPx = spanX * pxPerStud / 2,
		halfHeightPx = spanZ * pxPerStud / 2,
		shape = "rect",
	}
end

-- HOW BIG THE MINIMAP IS ON THIS SCREEN. The note promised 150 px is *"readable at a phone's ~400 px
-- width without eating a quarter of it"* and 150/400 is 37.5 %, which is not under a quarter -- so
-- the on-screen diameter is a clamped fraction of the viewport rather than a constant, and the
-- promise is true at the width the note names. 1080p resolves to the full 150.
function MapUi.diameterFor(viewportX: number, viewportY: number): number
	local config = MapUi.CONFIG
	local smaller = math.min(viewportX, viewportY)
	local wanted = math.min(config.MINIMAP_DIAMETER_PX, config.MINIMAP_VIEWPORT_FRACTION * smaller)
	return math.round(math.clamp(wanted, config.MINIMAP_MIN_PX, config.MINIMAP_DIAMETER_PX))
end

-- WHAT THE SCALE BAR SAYS AND HOW LONG IT IS: the largest round number of metres whose bar fits
-- `SCALE_BAR_FRACTION` of the canvas. Returns (studs, metres) so the drawer needs no second
-- conversion.
--
-- `Report.CONFIG.METRES_PER_STUD` DOES THE CONVERSION and this file holds no copy of 0.28. That
-- constant is already published in four shared tables (`Report.CONFIG`, `Horn.CONFIG`,
-- `Boar.CONFIG.SENSE`, `ForestTest.SPOOK`); the map adds a fifth READER and no fifth copy.
function MapUi.scaleBarStuds(pxPerStud: number, canvasWidthPx: number): (number, number)
	local config = MapUi.CONFIG
	local budgetPx = canvasWidthPx * config.SCALE_BAR_FRACTION
	local best = config.SCALE_BAR_CHOICES_M[1]
	for _, metres in ipairs(config.SCALE_BAR_CHOICES_M) do
		local studs = metres / Report.CONFIG.METRES_PER_STUD
		if studs * pxPerStud <= budgetPx then
			best = metres
		end
	end
	return best / Report.CONFIG.METRES_PER_STUD, best
end

-- WHICH COLOUR A MARKER IS. PURE: the team name in, one colour out, from `MapUi.COLORS`.
function MapUi.markerColor(team: string?, mine: boolean): Color3
	if mine then
		return MapUi.COLORS.own
	elseif team == "Drivers" then
		return MapUi.COLORS.Drivers
	elseif team == "Shooters" then
		return MapUi.COLORS.Shooters
	end
	return MapUi.COLORS.none
end

-- WHO IS DRAWN, as a pure function over a list this module did not fetch -- so every absent case is
-- assertable with ONE player. `ForestTest.realBeaters`'s three steps (character, PrimaryPart,
-- position or nothing), client-side.
--
-- A SOURCE WITH NO POSITION DRAWS NOTHING, and the map never invents a last-known one: a stale dot
-- is a lie about where somebody is. Beyond `MAX_MARKERS` the extras are counted by `overflowFor`
-- rather than silently dropped.
function MapUi.pointsFor(sources: { MarkerSource }, view: MapView, localUserId: number): { MarkerPoint }
	local out = {}
	for _, source in ipairs(sources) do
		if #out >= MapUi.CONFIG.MAX_MARKERS then
			break
		end
		local position = source.position
		if position ~= nil then
			local u, v, inside = MapUi.project(position.X, position.Z, view)
			table.insert(out, {
				userId = source.userId,
				u = u,
				v = v,
				pinned = not inside,
				mine = source.userId == localUserId,
				team = source.team,
			})
		end
	end
	return out
end

-- HOW MANY SOURCES WITH A POSITION DID NOT FIT. Counted, because a silent drop is a lie.
function MapUi.overflowFor(sources: { MarkerSource }): number
	local drawable = 0
	for _, source in ipairs(sources) do
		if source.position ~= nil then
			drawable += 1
		end
	end
	return math.max(0, drawable - MapUi.CONFIG.MAX_MARKERS)
end

-- WHAT IS ON SCREEN, as two pure predicates, so a spec asserts every combination with no scope, no
-- report and no world. The `Hud.crosshairVisible` precedent.
--
-- TWO FULL-SCREEN PANELS AT ONCE IS TWO PANELS NOBODY CAN READ, which is why `Hud.scorePanelVisible`
-- already takes `reportOpen`; the map reads the same published predicate and never writes it.
function MapUi.fullMapVisible(open: boolean, suppressed: boolean, reportOpen: boolean): boolean
	return open and not suppressed and not reportOpen
end

function MapUi.minimapVisible(open: boolean, suppressed: boolean, reportOpen: boolean, hasGeometry: boolean): boolean
	return hasGeometry and MapUi.CONFIG.MINIMAP_ENABLED and not open and not suppressed and not reportOpen
end

-- PURE, because a Studio Play on a PC has `TouchEnabled` false and a spec cannot change that.
function MapUi.buttonVisible(touchEnabled: boolean): boolean
	return touchEnabled and MapUi.CONFIG.BUTTON_ENABLED
end

-- ---------------------------------------------------------------- what a world tells the map

-- ONE SHAPE, TWO PROVIDERS (rule 3). `MapUi` draws a `MapGeometry` and does not know which world
-- made it, so there is no second code path through the drawing.

-- THE FOREST TEST'S MAP, out of the world's own data module. EVERY NUMBER IS ASKED FOR, NOT COPIED:
-- `ForestTest.roadZ(x)` is that module's own words *"the one definition; every other reader calls
-- this"*, and `standPosition(index)` is where a hunter stands. A map that re-typed the sine would be
-- a second curve that disagrees with the first the next time the Director bends the road.
--
-- `data` IS PASSED IN rather than required, so this stays pure and a spec can hand it a table.
function MapUi.geometryFromForestTest(data: any): MapGeometry
	local config = MapUi.CONFIG
	local centre = data.CENTRE
	local halfSpan = data.HALF_SPAN
	local margin = config.GEOMETRY_MARGIN_STUDS

	local road = {}
	local samples = math.max(2, config.ROAD_SAMPLES)
	for index = 1, samples do
		local t = (index - 1) / (samples - 1)
		local x = centre.X - halfSpan + t * (2 * halfSpan)
		table.insert(road, Vector2.new(x, data.roadZ(x)))
	end

	local stands = {}
	for index = 1, data.STAND_COUNT do
		local at = data.standPosition(index)
		table.insert(stands, Vector2.new(at.X, at.Z))
	end

	-- THE BOUNDS HOLD EVERYTHING THIS WORLD STATES. South is where a boar is gone (`EXIT_Z`, which
	-- already has the road's amplitude in it); north is the LARGER of the two drive-side starts --
	-- the drivers' 700 and a beater's own `LINE.spawnNorthStuds + BEATER.behindLineStuds` (240) --
	-- because a driver walking in from 700 studs is one of the *"other players moving"* Karen asked
	-- to see, and a map that cuts him off has lost him.
	local beaterNorth = data.LINE.spawnNorthStuds + data.BEATER.behindLineStuds
	local north = math.max(data.DRIVERS.startNorthStuds, beaterNorth)
	return {
		world = data.WORLD,
		bounds = {
			minX = centre.X - halfSpan - margin,
			maxX = centre.X + halfSpan + margin,
			minZ = data.EXIT_Z - margin,
			maxZ = centre.Z + data.ROAD.amplitudeStuds + north + margin,
		},
		road = road,
		stands = stands,
	}
end

-- THE DEV MATCH WORLD'S MAP: the road and the bounds, and NO STANDS -- deliberately, and it is a
-- finding rather than a shrug (design section 5.3).
--
-- `Map.TAGS.shooterPost` is read by `Markers.read` in `src/server/Match/Markers.luau`, which is in
-- `TWO_PLAYER_PATHS` and is server-only; the generator's own statement of the post line lives in
-- `MapGen.Config`, and ServerStorage does not replicate, so a client cannot read it at all. The
-- shared `Map` module publishes the road and `EXPECTED_COUNTS.shooterPost = 8` but NOT the spacing.
-- Asking `CollectionService` on the client was refused for a measured reason: the posts are
-- `Transparency = 1`, `CanQuery = false` parts in a place with `Map.STREAMING.enabled = true` and a
-- 1,024-stud target radius, so the far end of a 1,120-stud line may simply not exist on this client
-- -- a map that silently drops half its stands by distance. The fix is task 155a: a pure `Map.LINE`
-- in `src/shared/Map/init.luau` asserted against the tags by `map_contract.spec`.
--
-- So the DEV map draws the road, the bounds and the players. That is NOT a blank panel: it is a map
-- of a world that has stated a road and no stands, which is the truth about that world's shared data
-- today -- and `map_ui.spec` asserts `#stands == 0`, so the next task finds a case to change rather
-- than a comment to read.
function MapUi.geometryFromMap(map: any): MapGeometry
	local margin = MapUi.CONFIG.GEOMETRY_MARGIN_STUDS
	local road = map.ROAD
	local bounds = map.FIELD.bounds
	return {
		world = map.EXPECTED_WORLD,
		bounds = {
			minX = math.min(bounds.minX, road.from) - margin,
			maxX = math.max(bounds.maxX, road.to) + margin,
			minZ = bounds.minZ - margin,
			maxZ = bounds.maxZ + margin,
		},
		-- A STRAIGHT ROAD IS TWO POINTS. The polyline shape is the same either way, so the drawing
		-- has one road and not "a curve or a line".
		road = { Vector2.new(road.from, road.z), Vector2.new(road.to, road.z) },
		stands = {},
	}
end

-- WHICH WORLD'S GEOMETRY, or `nil`. A world that has stated nothing gets NO MAP AT ALL and says so
-- out loud -- never a blank panel, because `docs/PROJECT_CONTEXT.md` records a visibility audit that
-- *"certified a blank screen twice"* and an empty map frame is exactly that picture.
function MapUi.geometryFor(world: string, forestTest: any?, map: any?): MapGeometry?
	if world == "forest-test" then
		if forestTest == nil then
			return nil
		end
		return MapUi.geometryFromForestTest(forestTest)
	end
	if map ~= nil and map.ROAD ~= nil and map.FIELD ~= nil and map.FIELD.bounds ~= nil then
		return MapUi.geometryFromMap(map)
	end
	return nil
end

-- ---------------------------------------------------------------- state: one writer, this module

local miniFrame: Frame? = nil
local fullFrame: Frame? = nil
local mapButton: TextButton? = nil
local miniScale: UIScale? = nil
local fullScale: UIScale? = nil

local open = false
local suppressed = false
local geometry: MapGeometry? = nil
local pushBearing: number? = nil
local pushLabel: string? = nil
local started = false
local built = false
local tooSmallWarned = false

local CameraSystem: any = nil
local ReportSystem: any = nil
local localUserId = 0

-- The nodes, held in locals from the build so the tick never does a `FindFirstChild`.
type Drawer = {
	name: string,
	frame: Frame, -- the clipped viewport: the disc, or the full map's canvas
	-- THE FRAME WHOSE `Visible` DECIDES WHETHER THIS DRAWER IS ON SCREEN, which is NOT always
	-- `frame` -- and that is the bug `docs/PROJECT_CONTEXT.md` names in so many words: *"a
	-- visibility audit ignored parent visibility and certified a blank screen twice"*. The full
	-- map's drawer draws into the CANVAS, a child of the panel; the canvas is always `Visible` and
	-- the PANEL is what opens and closes. MEASURED, task 155's first gate run: `drawer.frame.Visible`
	-- was true for both drawers at once, so the closed full map drew the local player a second time
	-- and `map_ui.spec` caught two "mine" markers on a screen that only shows one.
	gate: Frame,
	inner: Frame?, -- the sliding geometry layer (the minimap only)
	layerView: MapView?, -- the view the sliding layer was drawn in
	view: MapView, -- the view markers are projected through
	markers: { Frame },
	own: Frame,
	wedge: Frame,
	arrow: Frame,
	arrowWord: TextLabel,
}
local drawers: { Drawer } = {}

local lastViewport = Vector2.new(0, 0)
local stats = { ticks = 0, toggles = 0, pinned = 0, overflow = 0, builtAt = nil :: number?, elapsed = 0 }
local firstTickAt: number? = nil

function MapUi.stats()
	return table.clone(stats)
end

function MapUi.isOpen(): boolean
	return open
end

function MapUi.isSuppressed(): boolean
	return suppressed
end

function MapUi.geometry(): MapGeometry?
	return geometry
end

function MapUi.pushBearingDeg(): number?
	return pushBearing
end

function MapUi.pushLabel(): string?
	return pushLabel
end

-- EMPTY UNTIL THERE IS A MAP TO OPEN, which is what "M is not bound in a world with no geometry"
-- means, read off the module instead of guessed.
function MapUi.boundActions(): { string }
	if not built then
		return {}
	end
	return { TOGGLE }
end

-- WHICH VIEW A DRAWER IS USING, for a spec: the full map's scale and centre, without reaching into
-- `PlayerGui` and recomputing them.
function MapUi.viewOf(name: string): MapView?
	for _, drawer in ipairs(drawers) do
		if drawer.name == name then
			return drawer.view
		end
	end
	return nil
end

-- WHAT IS ACTUALLY ON SCREEN, read off the frames rather than recomputed -- the one honest answer to
-- "is the picture right", and the shape `Compass.markPositions` already has.
function MapUi.markerPoints(): { MarkerPoint }
	local out = {}
	for _, drawer in ipairs(drawers) do
		if not drawer.gate.Visible then
			continue
		end
		local nodes = table.clone(drawer.markers)
		table.insert(nodes, drawer.own)
		for _, marker in ipairs(nodes) do
			if marker.Visible then
				table.insert(out, {
					userId = (marker:GetAttribute("UserId") :: number?) or 0,
					u = marker.Position.X.Offset,
					v = marker.Position.Y.Offset,
					pinned = marker.BackgroundTransparency > 0,
					mine = marker.Name == "Own",
					team = marker:GetAttribute("Team") :: string?,
				})
			end
		end
	end
	return out
end

-- ---------------------------------------------------------------- the picture, built once

local function stroked<T>(node: T & GuiObject): T
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = node
	return node
end

local function label(parent: GuiObject, name: string, size: number, text: string): TextLabel
	local node = Instance.new("TextLabel")
	node.Name = name
	node.BackgroundTransparency = 1
	node.Font = Enum.Font.Code
	node.TextSize = size
	node.TextColor3 = MapUi.CONFIG.TEXT_COLOR
	node.Text = text
	node.ZIndex = MapUi.CONFIG.Z_INDEX + 3
	stroked(node)
	node.Parent = parent
	return node
end

-- A LINE BETWEEN TWO PIXEL POINTS, as a rotated `Frame`. No art, no mesh and no `ViewportFrame` --
-- the same technique `Compass`'s chevron (`Rotation = 45`) and `ReportPanel`'s thirteen-part
-- silhouette already use.
local function segment(parent: GuiObject, ax: number, ay: number, bx: number, by: number, thickness: number)
	local dx, dy = bx - ax, by - ay
	local length = math.sqrt(dx * dx + dy * dy)
	local node = Instance.new("Frame")
	node.Name = "Road"
	node.AnchorPoint = Vector2.new(0.5, 0.5)
	node.Size = UDim2.fromOffset(math.max(1, math.round(length + thickness)), thickness)
	node.Position = UDim2.new(0.5, math.round((ax + bx) / 2), 0.5, math.round((ay + by) / 2))
	node.Rotation = math.deg(math.atan2(dy, dx))
	node.BackgroundColor3 = MapUi.CONFIG.ROAD_COLOR
	node.BorderSizePixel = 0
	node.ZIndex = MapUi.CONFIG.Z_INDEX + 1
	node.Parent = parent
end

-- THE ROAD AND THE STANDS, drawn once into `holder` in the coordinates of `view`. The minimap's
-- holder then SLIDES under the player; the full map's never moves.
local function drawGeometry(holder: GuiObject, model: MapGeometry, view: MapView, standLabels: boolean)
	local config = MapUi.CONFIG
	local previousU: number? = nil
	local previousV: number? = nil
	for _, point in ipairs(model.road) do
		local u, v = MapUi.rawOffsetPx(point.X, point.Y, view)
		if previousU ~= nil then
			segment(holder, previousU :: number, previousV :: number, u, v, config.ROAD_PX)
		end
		previousU, previousV = u, v
	end

	for index, point in ipairs(model.stands) do
		local u, v = MapUi.rawOffsetPx(point.X, point.Y, view)
		local node = Instance.new("Frame")
		node.Name = string.format("Stand%d", index)
		node.AnchorPoint = Vector2.new(0.5, 0.5)
		node.Size = UDim2.fromOffset(config.STAND_PX, config.STAND_PX)
		node.Position = UDim2.new(0.5, math.round(u), 0.5, math.round(v))
		node.BackgroundColor3 = MapUi.COLORS.stand
		node.BorderSizePixel = 0
		node.ZIndex = config.Z_INDEX + 1
		stroked(node)
		node.Parent = holder
		if standLabels then
			local text = label(node, "Index", config.LABEL_SIZE, tostring(index))
			text.AnchorPoint = Vector2.new(0.5, 0)
			text.Position = UDim2.new(0.5, 0, 1, 1)
			text.Size = UDim2.fromOffset(18, config.LABEL_SIZE + 2)
		end
	end
end

-- THE MARKERS, THE OWN MARKER, ITS WEDGE AND THE PUSH ARROW: built once per drawer, hidden until
-- there is something to say. Nothing is cloned in the tick -- the pool is the shape `Hud.build`'s
-- feed lines and score rows already have.
local function buildDrawer(
	name: string,
	frame: Frame,
	gate: Frame,
	inner: Frame?,
	view: MapView,
	layerView: MapView?
): Drawer
	local config = MapUi.CONFIG
	local markers = {}
	for index = 1, config.MAX_MARKERS do
		local node = Instance.new("Frame")
		node.Name = string.format("Player%d", index)
		node.AnchorPoint = Vector2.new(0.5, 0.5)
		node.Size = UDim2.fromOffset(config.MARKER_PX, config.MARKER_PX)
		node.Position = UDim2.fromScale(0.5, 0.5)
		node.BackgroundColor3 = MapUi.COLORS.none
		node.BorderSizePixel = 0
		node.ZIndex = config.Z_INDEX + 2
		node.Visible = false
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = node
		stroked(node)
		node.Parent = frame
		table.insert(markers, node)
	end

	local own = Instance.new("Frame")
	own.Name = "Own"
	own.AnchorPoint = Vector2.new(0.5, 0.5)
	own.Size = UDim2.fromOffset(config.OWN_MARKER_PX, config.OWN_MARKER_PX)
	own.Position = UDim2.fromScale(0.5, 0.5)
	own.BackgroundColor3 = MapUi.COLORS.own
	own.BorderSizePixel = 0
	own.ZIndex = config.Z_INDEX + 3
	own.Visible = false
	local ownCorner = Instance.new("UICorner")
	ownCorner.CornerRadius = UDim.new(0.5, 0)
	ownCorner.Parent = own
	stroked(own)
	own.Parent = frame

	-- WHICH WAY YOU ARE LOOKING. A short bar offset along the view bearing from your own dot, in the
	-- cream the compass's centre hairline uses -- so "me" and "my view" read as one mark.
	local wedge = Instance.new("Frame")
	wedge.Name = "Wedge"
	wedge.AnchorPoint = Vector2.new(0.5, 0.5)
	wedge.Size = UDim2.fromOffset(config.WEDGE_PX, config.WEDGE_LENGTH_PX)
	wedge.Position = UDim2.fromScale(0.5, 0.5)
	wedge.BackgroundColor3 = MapUi.COLORS.own
	wedge.BorderSizePixel = 0
	wedge.ZIndex = config.Z_INDEX + 3
	wedge.Visible = false
	stroked(wedge)
	wedge.Parent = frame

	-- WHICH WAY TO GO. Karen: *"what direction to move"*. A bar from your own marker with the word at
	-- its tip -- and the WORD TRAVELS WITH THE BEARING, which is task 153 round 2's blocking finding:
	-- a marker that moved without its label told a beater the drive was south.
	local arrow = Instance.new("Frame")
	arrow.Name = "PushArrow"
	arrow.AnchorPoint = Vector2.new(0.5, 1)
	arrow.Size = UDim2.fromOffset(config.ARROW_PX, config.ARROW_LENGTH_PX)
	arrow.Position = UDim2.fromScale(0.5, 0.5)
	arrow.BackgroundColor3 = MapUi.COLORS.arrow
	arrow.BorderSizePixel = 0
	arrow.ZIndex = config.Z_INDEX + 2
	arrow.Visible = false
	stroked(arrow)
	arrow.Parent = frame

	local word = label(frame, "PushWord", config.LABEL_SIZE, "")
	word.TextColor3 = MapUi.COLORS.arrow
	word.AnchorPoint = Vector2.new(0.5, 0.5)
	word.Size = UDim2.fromOffset(60, config.LABEL_SIZE + 2)
	word.Visible = false

	return {
		name = name,
		frame = frame,
		gate = gate,
		inner = inner,
		layerView = layerView,
		view = view,
		markers = markers,
		own = own,
		wedge = wedge,
		arrow = arrow,
		arrowWord = word,
	}
end

-- ---------------------------------------------------------------- the layout, recomputed on change

-- RECOMPUTED ONLY WHEN THE VIEWPORT CHANGES, which is `Hud.layoutScope`'s own rule: a layout
-- recomputed every tick is work nobody asked for, and one computed once is wrong the first time
-- somebody resizes the window.
--
-- IT WRITES SIZES AND TWO `UIScale`S AND NOTHING ELSE. Because each drawer's pixel space is fixed,
-- no view moves and no geometry is redrawn here: that is the whole reason for building in a fixed
-- space (see the header).
local function layout(viewport: Vector2)
	local config = MapUi.CONFIG
	local mini, full = miniFrame, fullFrame
	if mini == nil or full == nil then
		return
	end

	local diameter = MapUi.diameterFor(viewport.X, viewport.Y)
	mini.Size = UDim2.fromOffset(diameter, diameter)
	mini.Position = UDim2.new(1, -config.MINIMAP_MARGIN, 0, config.MINIMAP_TOP)
	local miniUiScale = miniScale
	if miniUiScale ~= nil then
		miniUiScale.Scale = diameter / config.MINIMAP_DIAMETER_PX
	end

	local button = mapButton
	if button ~= nil then
		button.Size = UDim2.fromOffset(config.BUTTON_PX, config.BUTTON_PX)
		button.Position = UDim2.new(1, -config.MINIMAP_MARGIN, 0, config.MINIMAP_TOP + diameter + config.BUTTON_GAP)
	end

	-- THE PANEL IS BUILT AT A FIXED SIZE AND SCALED TO FIT, so one number handles a phone and
	-- nothing inside it moves.
	local wanted = full.Size
	local panelWidth = wanted.X.Offset
	local panelHeight = wanted.Y.Offset
	local roomX = viewport.X - 2 * config.FULL_SIDE_INSET
	local roomY = viewport.Y - config.FULL_TOP - config.FULL_BOTTOM_INSET
	local scale = 1
	if panelWidth > 0 and panelHeight > 0 then
		scale = math.min(1, roomX / panelWidth, roomY / panelHeight)
	end
	local fullUiScale = fullScale
	if fullUiScale ~= nil then
		fullUiScale.Scale = math.max(0.1, scale)
	end

	-- A VIEWPORT TOO SMALL FOR A MAP AT ALL is a decision, said once, rather than a squashed
	-- rectangle nobody mentioned.
	if panelHeight * scale < config.FULL_MIN_HEIGHT_PX and not tooSmallWarned then
		tooSmallWarned = true
		warn(
			string.format(
				"[Hud.MapUi] viewport %d x %d leaves %d px for the full map (needs %d): it will be small",
				math.round(viewport.X),
				math.round(viewport.Y),
				math.round(panelHeight * scale),
				config.FULL_MIN_HEIGHT_PX
			)
		)
	end
end

-- ---------------------------------------------------------------- visibility: the one writer

-- THE ONE WRITER OF BOTH FRAMES' `Visible`, AND THE ONE PLACE THE COMPASS'S PRECEDENT IS REFUSED.
-- `Hud.renderScope` hides the compass strip itself and its own comment admits the cost:
-- *"`compassFrame.Visible` therefore has TWO writers and that is deliberate (rule 3)"*. Here the Hud
-- STATES A NEED instead -- `MapUi.setSuppressed(scoped)` -- which is this repo's own
-- `Camera.Cursor.requestFree` pattern, borrowed once already by `Input.requestHold`. One writer, and
-- no comment needed to keep it honest.
function MapUi.applyVisibility()
	local mini, full = miniFrame, fullFrame
	if mini == nil or full == nil then
		return
	end
	local reportOpen = ReportSystem ~= nil and ReportSystem.isOpen() == true
	local hasGeometry = geometry ~= nil
	full.Visible = hasGeometry and MapUi.fullMapVisible(open, suppressed, reportOpen)
	mini.Visible = MapUi.minimapVisible(open, suppressed, reportOpen, hasGeometry)
	local button = mapButton
	if button ~= nil then
		button.Visible = hasGeometry and MapUi.buttonVisible(UserInputService.TouchEnabled)
	end
end

-- ---------------------------------------------------------------- drawing

-- WHO IS ON THE MAP, read once per tick. `Players:GetPlayers()` is called ONCE, never inside a loop
-- -- the hoisting task 154's review asked for.
local function roster(): { MarkerSource }
	local sources = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character.PrimaryPart
		table.insert(sources, {
			userId = player.UserId,
			team = if player.Team then player.Team.Name else nil,
			-- NIL, NEVER A GUESS. No character yet (joining, respawning) or a streamed-out one means
			-- no marker: a stale dot is a lie about where somebody is.
			position = if root then (root :: BasePart).Position else nil,
		})
	end
	return sources
end

local function renderDrawer(drawer: Drawer, sources: { MarkerSource }, me: Vector3?, headingDeg: number?)
	local config = MapUi.CONFIG
	local view = drawer.view

	-- THE MINIMAP IS CENTRED ON THE PLAYER, so its view's centre moves and its geometry layer slides
	-- the other way: ONE write moves the road and all nine stands. This is the "move the map under
	-- the player" mechanism of the image-based option, borrowed without its image.
	local inner, layerView = drawer.inner, drawer.layerView
	if inner ~= nil and layerView ~= nil then
		if me ~= nil then
			view.centreX, view.centreZ = (me :: Vector3).X, (me :: Vector3).Z
		end
		-- WHERE THE LAYER'S OWN ORIGIN SITS in the player-centred view. RAW, never pinned: a pinned
		-- layer would drag the whole road to the rim.
		local du, dv = MapUi.rawOffsetPx(layerView.centreX, layerView.centreZ, view)
		inner.Position = UDim2.new(0.5, math.round(du), 0.5, math.round(dv))
	end

	local points = MapUi.pointsFor(sources, view, localUserId)
	local index = 0
	local mine: MarkerPoint? = nil
	for _, point in ipairs(points) do
		if point.mine then
			mine = point
			continue
		end
		index += 1
		local marker = drawer.markers[index]
		if marker == nil then
			break
		end
		marker.Position = UDim2.new(0.5, math.round(point.u), 0.5, math.round(point.v))
		marker.BackgroundColor3 = MapUi.markerColor(point.team, false)
		marker.BackgroundTransparency = if point.pinned then config.PINNED_TRANSPARENCY else 0
		marker:SetAttribute("UserId", point.userId)
		marker:SetAttribute("Team", point.team or "")
		marker.Visible = true
		if point.pinned then
			stats.pinned += 1
		end
	end
	for spare = index + 1, #drawer.markers do
		drawer.markers[spare].Visible = false
	end

	-- YOUR OWN MARKER, ITS WEDGE AND THE PUSH ARROW, all hung off the one point.
	local own, wedge, arrow, word = drawer.own, drawer.wedge, drawer.arrow, drawer.arrowWord
	if mine == nil then
		own.Visible = false
		wedge.Visible = false
		arrow.Visible = false
		word.Visible = false
		return
	end
	local point = mine :: MarkerPoint
	own.Position = UDim2.new(0.5, math.round(point.u), 0.5, math.round(point.v))
	own.BackgroundTransparency = if point.pinned then config.PINNED_TRANSPARENCY else 0
	own:SetAttribute("UserId", point.userId)
	own:SetAttribute("Team", point.team or "")
	own.Visible = true

	if headingDeg == nil then
		wedge.Visible = false
	else
		local heading = headingDeg :: number
		local wu, wv = MapUi.facingOffsetPx(heading, config.WEDGE_OFFSET_PX)
		wedge.Position = UDim2.new(0.5, math.round(point.u + wu), 0.5, math.round(point.v + wv))
		wedge.Rotation = heading % 360
		wedge.Visible = true
	end

	-- NO BEARING, NO ARROW AND NO WORD, and the map still works: that is `Compass.setBearing(nil)`'s
	-- rule -- *"a marker pointing at zero would be a lie in the shape of a fact"*.
	if pushBearing == nil then
		arrow.Visible = false
		word.Visible = false
		return
	end
	local bearing = (pushBearing :: number) % 360
	arrow.Position = UDim2.new(0.5, math.round(point.u), 0.5, math.round(point.v))
	arrow.Rotation = bearing
	arrow.Visible = true
	local au, av = MapUi.facingOffsetPx(bearing, config.ARROW_LENGTH_PX + 10)
	word.Position = UDim2.new(0.5, math.round(point.u + au), 0.5, math.round(point.v + av))
	local text = pushLabel or "DRIVE"
	if word.Text ~= text then
		word.Text = text
	end
	word.Visible = true
end

-- PUBLIC, for the reason `Hud.renderScore` and `ReportPanel.render` are: a spec cannot turn a
-- camera, cannot walk a second player across a wood and cannot wait on a tick, so the only honest
-- way to prove the picture moves is to hand it the inputs.
function MapUi.render()
	if geometry == nil then
		return
	end
	stats.ticks += 1
	local now = os.clock()
	if firstTickAt == nil then
		firstTickAt = now
	end
	stats.elapsed = now - (firstTickAt :: number)

	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else lastViewport
	if viewport.X ~= lastViewport.X or viewport.Y ~= lastViewport.Y then
		lastViewport = viewport
		layout(viewport)
	end

	MapUi.applyVisibility()

	local sources = roster()
	stats.overflow = MapUi.overflowFor(sources)
	local me: Vector3? = nil
	for _, source in ipairs(sources) do
		if source.userId == localUserId then
			me = source.position
		end
	end
	local headingDeg: number? = nil
	if CameraSystem ~= nil and type(CameraSystem.viewHeadingDeg) == "function" then
		headingDeg = CameraSystem.viewHeadingDeg()
	end

	-- EXACTLY ONE DRAWER IS LIVE: the minimap when the map is closed, the full map when it is open.
	-- So the per-player work below happens once a tick, not twice.
	for _, drawer in ipairs(drawers) do
		if drawer.gate.Visible then
			renderDrawer(drawer, sources, me, headingDeg)
		end
	end
end

-- ---------------------------------------------------------------- the switch

function MapUi.setOpen(next_: boolean)
	if open == next_ then
		return
	end
	open = next_
	stats.toggles += 1
	MapUi.applyVisibility()
	MapUi.render()
end

function MapUi.toggle()
	MapUi.setOpen(not open)
end

-- A TAGGED NEED FROM `Hud.renderScope`, applied AT ONCE rather than at the next 20 Hz tick -- so the
-- blackout and the map arrive on the same frame. Task 141's lesson: *"a sight picture that waits for
-- the blend was computed exactly once, at the only moment it is false"*.
function MapUi.setSuppressed(on: boolean)
	if suppressed == on then
		return
	end
	suppressed = on
	MapUi.applyVisibility()
end

-- THE WORLD'S DIRECTION AND ITS WORD, handed in BY THE HUD and never re-derived here.
-- `Hud.driveBearing` is already the one rule (task 153) and the Hud resolves it ONCE, in the closure
-- that re-runs on `player:GetPropertyChangedSignal("Team")` because `/beater` switches the team
-- mid-session. Two readers of one fact that could be given different teams is how task 153 round 2's
-- finding comes back; `MapUi.luau` is also a sibling of `init.luau`, so requiring it would be a
-- cycle.
--
-- `nil` IS "NOT STATED" and then there is no arrow and no word. A stated bearing with no label gets
-- the compass's own word, which is what a hunter and every other world get.
function MapUi.setPush(bearingDeg: number?, labelText: string?)
	pushBearing = bearingDeg
	pushLabel = if bearingDeg == nil then nil else (labelText or "DRIVE")
end

-- ---------------------------------------------------------------- the world arrives

local function on(fn: () -> ())
	return function(_name: string, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			fn()
		end
		-- IT PASSES, NEVER SINKS, for the reason `Weapon.Input`'s header gives: a sink would swallow
		-- the Task 6 input probe, which is the harness's evidence that input arrives at all.
		return Enum.ContextActionResult.Pass
	end
end

-- THE LATE-ARRIVAL DOOR (task 134's bug), and the one that BUILDS. `Hud.whenReady` may hand the
-- Forest Test's data over a quarter of a second after `Hud.start` ran, and *"no `ForestTest` yet"*
-- must not mean no map for the session. Idempotent: a second call builds nothing twice -- the shape
-- `ReportPanel.setMatch` and `Compass.setBearing` both have.
function MapUi.setGeometry(next_: MapGeometry?)
	geometry = next_
	if next_ == nil or built or miniFrame == nil or fullFrame == nil then
		MapUi.applyVisibility()
		return
	end
	built = true
	stats.builtAt = os.clock()
	local config = MapUi.CONFIG
	local model = next_ :: MapGeometry
	local mini = miniFrame :: Frame
	local full = fullFrame :: Frame

	-- ---------------- the minimap: a sliding geometry layer inside the round, clipped frame
	local miniShrink = Instance.new("UIScale")
	miniShrink.Parent = mini
	miniScale = miniShrink

	-- CENTRED ON THE MAP'S OWN CENTRE UNTIL THERE IS A PLAYER TO CENTRE ON. `renderDrawer` moves it
	-- to the character's position every tick; before the character exists (joining, respawning) this
	-- is the only sensible answer, and `Vector3.zero` would slide the whole road out of the disc.
	local miniCentre =
		Vector3.new((model.bounds.minX + model.bounds.maxX) / 2, 0, (model.bounds.minZ + model.bounds.maxZ) / 2)
	local miniView = MapUi.minimapView(miniCentre, config.MINIMAP_DIAMETER_PX, config.MINIMAP_RANGE_STUDS)
	-- THE LAYER IS DRAWN IN MAP SPACE at the minimap's own scale, centred on the geometry's own
	-- centre, and then slid under the player. A zero-size frame, so its top-left IS its centre and a
	-- child at `(dx, dy)` sits that far from the map's centre.
	local layerView: MapView = {
		centreX = miniCentre.X,
		centreZ = miniCentre.Z,
		pxPerStud = miniView.pxPerStud,
		halfWidthPx = math.huge,
		halfHeightPx = math.huge,
		shape = "rect",
	}
	local inner = Instance.new("Frame")
	inner.Name = "Geometry"
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.fromOffset(0, 0)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.ZIndex = config.Z_INDEX + 1
	inner.Parent = mini
	drawGeometry(inner, model, layerView, false)

	-- ---------------- the full map: a fixed-size panel, scaled to fit
	--
	-- The canvas holds the whole span at one scale; the panel is the canvas plus a title, a footer
	-- and padding. Both are fixed, and `layout` scales the lot.
	local canvasWidth = config.FULL_MAX_WIDTH_PX - 2 * config.FULL_PADDING
	local canvasHeight = config.FULL_MAX_HEIGHT_PX
		- (config.FULL_TITLE_HEIGHT + config.FULL_FOOTER_HEIGHT + 2 * config.FULL_PADDING)
	local fullView = MapUi.fullView(model.bounds, canvasWidth, canvasHeight)
	-- THE PANEL IS CUT DOWN TO WHAT THE MAP ACTUALLY FILLS, so a wide, shallow world (this road is
	-- 1,720 studs by 1,100) gets a wide, shallow panel instead of a tall box with empty air in it.
	local usedWidth = math.round(2 * fullView.halfWidthPx)
	local usedHeight = math.round(2 * fullView.halfHeightPx)
	full.Size = UDim2.fromOffset(
		usedWidth + 2 * config.FULL_PADDING,
		usedHeight + config.FULL_TITLE_HEIGHT + config.FULL_FOOTER_HEIGHT + 2 * config.FULL_PADDING
	)
	full.Position = UDim2.new(0.5, 0, 0, config.FULL_TOP)

	local fullShrink = Instance.new("UIScale")
	fullShrink.Parent = full
	fullScale = fullShrink

	local title = label(full, "Title", config.TITLE_SIZE, string.format("MAP   %s", model.world))
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 3)
	title.Size = UDim2.new(1, -2 * config.FULL_PADDING, 0, config.FULL_TITLE_HEIGHT)

	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.AnchorPoint = Vector2.new(0, 0)
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.fromOffset(usedWidth, usedHeight)
	canvas.Position = UDim2.fromOffset(config.FULL_PADDING, config.FULL_TITLE_HEIGHT + config.FULL_PADDING)
	canvas.ClipsDescendants = true
	canvas.ZIndex = config.Z_INDEX + 1
	canvas.Parent = full
	drawGeometry(canvas, model, fullView, true)

	-- NORTH UP, SAID ON THE PICTURE. A map with no north is a map you have to be told about.
	local north = label(canvas, "North", config.TITLE_SIZE, "N")
	north.AnchorPoint = Vector2.new(0.5, 0)
	north.Position = UDim2.new(0.5, 0, 0, 2)
	north.Size = UDim2.fromOffset(16, config.TITLE_SIZE + 2)

	local studs, metres = MapUi.scaleBarStuds(fullView.pxPerStud, usedWidth)
	local bar = Instance.new("Frame")
	bar.Name = "ScaleBar"
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Size = UDim2.fromOffset(math.max(8, math.round(studs * fullView.pxPerStud)), 3)
	bar.Position = UDim2.new(0, config.FULL_PADDING, 1, -(config.FULL_FOOTER_HEIGHT - 8))
	bar.BackgroundColor3 = config.TEXT_COLOR
	bar.BorderSizePixel = 0
	bar.ZIndex = config.Z_INDEX + 3
	stroked(bar)
	bar.Parent = full

	local barLabel = label(full, "ScaleLabel", config.LABEL_SIZE, string.format("%d m", metres))
	barLabel.AnchorPoint = Vector2.new(0, 1)
	barLabel.Position = UDim2.new(0, config.FULL_PADDING, 1, -3)
	barLabel.Size = UDim2.fromOffset(80, config.LABEL_SIZE + 2)
	barLabel.TextXAlignment = Enum.TextXAlignment.Left

	table.clear(drawers)
	-- `buildDrawer` is handed the view table itself, so the minimap's centre is this one object and
	-- `renderDrawer` moves it in place -- no second copy to get out of step. The minimap's own frame
	-- IS its gate; the full map's gate is the PANEL, not the canvas it draws into.
	table.insert(drawers, buildDrawer("minimap", mini, mini, inner, miniView, layerView))
	table.insert(drawers, buildDrawer("full", canvas, full, nil, fullView, nil))

	local camera = Workspace.CurrentCamera
	lastViewport = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
	layout(lastViewport)

	-- M IS BOUND ONLY ONCE THERE IS A MAP TO OPEN. An M that opens an empty panel is worse than an M
	-- that does nothing (design section 5.4).
	ContextActionService:BindAction(TOGGLE, on(MapUi.toggle), false, config.TOGGLE_KEY)
	MapUi.applyVisibility()
	MapUi.render()
end

function MapUi.start(frames: { miniMap: Frame, fullMap: Frame, button: TextButton? }, collaborators: any)
	if started then
		return
	end
	started = true
	miniFrame = frames.miniMap
	fullFrame = frames.fullMap
	mapButton = frames.button
	CameraSystem = collaborators and collaborators.Camera
	ReportSystem = collaborators and collaborators.Report
	localUserId = (collaborators and collaborators.userId) or 0

	local button = mapButton
	if button ~= nil then
		-- THE SAME ENTRY POINT M USES, so there is one toggle and not two.
		button.Activated:Connect(MapUi.toggle)
	end

	MapUi.setGeometry(collaborators and collaborators.geometry)

	-- `Heartbeat` WITH AN ACCUMULATOR, which is `Hud.useMatch`'s own shape for the drive clock. NOT
	-- `RenderStepped`: see `CONFIG.TICK_HZ`. Connected even when the geometry has not arrived yet --
	-- `render` returns at once while it is nil -- so a late world does not also need a late
	-- connection.
	local sinceTick = 0
	local period = 1 / math.max(1, MapUi.CONFIG.TICK_HZ)
	RunService.Heartbeat:Connect(function(dt)
		sinceTick += dt
		if sinceTick < period then
			return
		end
		sinceTick = 0
		MapUi.render()
	end)
end

return MapUi
