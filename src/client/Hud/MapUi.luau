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
local Workspace = game:GetService("Workspace")

-- `Drive` IS NOT REQUIRED HERE ANY MORE (task 201 E). It was read for three colours -- the drive
-- bar's two team badges and its white text -- and the palette answers all three now
-- (`MapUi.COLORS`), so the map's only remaining cross-system read is `Report.CONFIG.METRES_PER_STUD`
-- for the scale bar.
local Report = require(ReplicatedStorage:WaitForChild("Report"))
-- THE ONE SOURCE FOR EVERY COLOUR, FACE AND RADIUS ON THIS MAP since task 201 E (the Designer's
-- design system, 2026-10-17). `script.Parent` and not a service path: `Style` is this folder's own
-- module, exactly as `ReportPanel` and `Rail` require it.
local Style = require(script.Parent:WaitForChild("Style"))

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
	-- `BUTTON_ENABLED` IS GONE (task 165). It gated a touch-only button under the disc, and that
	-- button is now the first of `Hud.Rail`'s column -- which calls this module's own `MapUi.toggle`.
	-- Archived with its reason in `backups/2026-10-12_mapui-touch-button.txt` (rule 7).

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
	-- has a drive, and at 1080p it would not -- which is exactly how that bug hid.
	--
	-- 108 -> 140 (task 165): the objective line took the top line and the whole band moved down one
	-- band -- objective 8..40, bar 44..70, tied banner 74..104, compass 108..134 -- so 140 is what
	-- now clears all of it at every width (`docs/design/hud-clarity.md` section 3). The BUTTON RAIL
	-- hangs below this disc and its top is computed from the RENDERED diameter (`Rail.topFor`), so
	-- this one number moves both.
	MINIMAP_TOP = 140,
	MINIMAP_MARGIN = 12,
	-- HOW FAR IT SEES, as a radius. 300 studs is 84 m at 0.28 m/stud and TWO stand spacings
	-- (`ForestTest.LAYOUTS.road.standSpacing` 150), so a beater walking in sees the road and at least two stands
	-- before she reaches them.
	MINIMAP_RANGE_STUDS = 300,

	-- ---------------- the full map: a panel on M
	--
	-- The panel is built at a FIXED pixel size that holds the world's whole span at one scale, and a
	-- `UIScale` fits it to the screen. 1080p leaves 108 above and 272 below.
	FULL_MAX_WIDTH_PX = 1100,
	FULL_MAX_HEIGHT_PX = 700,
	FULL_TOP = 140, -- the same top line as the minimap (108 -> 140 with the band, task 165)
	FULL_SIDE_INSET = 24,
	FULL_BOTTOM_INSET = 48, -- clears the ammo readout's own 40
	-- BELOW THIS THERE IS NO ROOM FOR A MAP AT ALL and it is said out loud once, rather than drawn as
	-- a squashed rectangle: a decision instead of an accident.
	FULL_MIN_HEIGHT_PX = 240,
	FULL_PADDING = 14,
	-- 20 -> 36 (task 201 E). §5 surface 14: *"the title becomes eyebrow `MAP` + title = the world's
	-- name"*, which is two lines where there was one -- a 10 px brass eyebrow over a 22 px Oswald
	-- name. The 16 px comes off the CANVAS, which is the one place in this panel that can give it:
	-- the map is drawn at one scale into whatever is left, so a shorter canvas is a slightly
	-- smaller map and never a clipped one.
	FULL_TITLE_HEIGHT = 36,
	FULL_EYEBROW_HEIGHT = 12,
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
	-- HOW WIDE A COLUMN THE BUTTON RAIL OWNS on the right edge, and why the full map has to know:
	-- the panel is CENTRED, so at 400 px wide its own room (`viewportX - 2 * FULL_SIDE_INSET` = 352,
	-- spanning x 24..376) crosses the rail at x 340..388. The minimap never had this problem because
	-- `minimapVisible` hides it while the map is open; THE RAIL CANNOT HIDE, because on a phone it is
	-- the only way to CLOSE the map. So `layoutFor` reserves this much and shifts the panel left by
	-- half of it (`docs/design/hud-clarity.md` section 3). 48 + 12 + 8 = the button, its margin and a
	-- gap -- read off `Rail.CONFIG` would be a require cycle, so it is stated here and
	-- `hud_clarity.spec` asserts the two agree.
	RAIL_COLUMN_PX = 68,

	-- ---------------- what things look like
	--
	-- EVERY ONE OF THESE IS A `Style` TOKEN SINCE TASK 201 E (the Designer's design system,
	-- 2026-10-17, §5 surfaces 4, 14 and 22). What this block held before was six hand-picked
	-- colours: a `#101214` ground, a `#E6E6E6` rim, white text and a `#BEB6A4` road, each measured
	-- by eye in task 155 and each a second answer to a question the palette now answers once.
	--
	-- THE MINIMAP IS A *QUIET SLATE* AND THE FULL MAP IS A *PANEL*, which is the system's whole
	-- division (§0.2): a field surface floats over the world at 8-14 % and a lodge surface is opaque
	-- over a scrim. The minimap carries 9-11 px labels, so it takes `SLATE_QUIET_T` -- the compass
	-- band's own number, measured in §2's contrast table rather than chosen.
	BACKGROUND = Style.LOOK.SLATE,
	MINIMAP_TRANSPARENCY = Style.SLATE_QUIET_T,
	PANEL_TRANSPARENCY = Style.PANEL_T,
	-- *"rim = `BRASS` @ 0.55, 2 px"* (§5 surface 4). The full map's edge is a PANEL's -- 1 px at
	-- `EDGE_T.PANEL` -- so the two read as the two surface families they are.
	RIM_COLOR = Style.LOOK.BRASS,
	RIM_TRANSPARENCY = Style.EDGE_T.SLATE,
	RIM_THICKNESS = 2,
	PANEL_EDGE_TRANSPARENCY = Style.EDGE_T.PANEL,
	PANEL_CORNER = Style.RADIUS.MODAL,
	TEXT_COLOR = Style.LOOK.PAPER,
	-- THE SCALE BAR (§5 surface 14: *"the scale bar is `BODY` text over a brass bar"*). A scale is a
	-- measurement and not a mark, so it is the quietest thing on the panel.
	SCALE_BAR_COLOR = Style.LOOK.BRASS,
	SCALE_TEXT_COLOR = Style.LOOK.BODY,
	-- THE LEGEND IS A WELL (§3 / §5 surface 22): a sunk panel inside the panel, one step darker and
	-- one step less round than what it sits on.
	LEGEND_WELL_COLOR = Style.LOOK.COLUMN,
	LEGEND_WELL_EDGE = Style.LOOK.WELL_EDGE,
	LEGEND_WELL_CORNER = Style.RADIUS.WELL,
	LEGEND_WORD_COLOR = Style.LOOK.BODY,
	-- *"every label `MICRO` `PAPER`, no stroke"* (§5 surface 4). `MICRO` is 10 px on a desktop and 9
	-- on a phone; this map's labels are drawn inside a `UIScale`d pixel space rather than at screen
	-- size, so the DESKTOP step is the one that is true of the space they are drawn in and
	-- `legendVisible` is what decides whether that space is big enough to read at all.
	LABEL_SIZE = Style.SIZE.MICRO[1],
	-- The panel's own name, at the system's `TITLE` step and drawn in Oswald -- the same pair every
	-- other panel in the game wears. The canvas's `N` is drawn at this size too, because north is
	-- the second thing a map has to say.
	TITLE_SIZE = Style.SIZE.TITLE[1],

	-- THE ROAD is the hunters' line and the thing everything else is read against. `BODY` (§5
	-- surface 4: *"road `#BEB6A4` -> `BODY`"*) -- a pale line, quieter than the marks on it.
	ROAD_COLOR = Style.LOOK.BODY,
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

	-- THE LEGEND (task 165). Karen asked for the full map to be clearer; a map with six kinds of mark
	-- and no key is a diagram you have to be told about.
	--
	-- IT IS INSIDE THE PANEL'S FIXED PIXEL SPACE, so it scales with the panel -- and that is exactly
	-- why it has a floor: at a 400 px width the panel's `UIScale` is about a third and no font
	-- survives it. `MapUi.legendVisible` hides the whole block below `LEGEND_MIN_TEXT_PX /
	-- LEGEND_TEXT_PX`, and when it is hidden the map labels itself instead -- the `YOU` tag on your
	-- own marker and the word on the target mark, both of which exist at every size. What a phone
	-- loses is the colour key for the OTHER players' teams. Stated, not hidden: the real fix is a
	-- phone layout for the Hud's fixed-width panels, which is its own task.
	LEGEND_WIDTH_PX = 150,
	LEGEND_HEIGHT_PX = 96,
	LEGEND_ROW_HEIGHT = 15,
	LEGEND_SWATCH_PX = 9,
	LEGEND_TEXT_PX = 12,
	LEGEND_MIN_TEXT_PX = 8,

	-- THE STACK, against the one task 141 set: the feed and the drive bar at 1, the compass at 6-10,
	-- the scope's mask at 11-13, the drive report and the score board at 15. The whole map lives in
	-- 6..9 -- under the mask, under the report, over the feed and the bar. It shares numbers with
	-- the compass's band and that decides nothing, because the two never share a pixel and
	-- `map_ui.spec` asserts that by rectangle intersection rather than promising it in prose.
	Z_INDEX = 6,
}

-- WHERE THE MAP'S COLOURS COME FROM, AND IT IS `Style` SINCE TASK 201 E (§5 surface 4: *"own
-- marker `#FFE896` -> `BRASS_HI`; hunters `#FFA03C` -> `HUNTER`; beaters `#5A96FF` -> `BEATER`;
-- target mark -> `BLAZE_HI`"*).
--
-- IT USED TO READ `Drive.CONFIG`, and that was the right answer to a different question: in task
-- 155 the drive bar's badges were the only other place a team was coloured, so reading them was
-- what stopped the map and the score board disagreeing. Since task 201 B the badge is a `Style`
-- PILL and `Style.teamColor` is the one mapping, so reading `Drive.CONFIG` is now what WOULD make
-- them disagree -- the drive's three colours are the pre-system ones and nothing on screen uses
-- them any more. `teamColor` is called rather than `LOOK.HUNTER` written out, so the pill, the
-- roster row and the map marker are one answer and not three.
MapUi.COLORS = {
	own = Style.LOOK.BRASS_HI, -- you, in the cream the compass's centre hairline already uses
	Drivers = Style.teamColor("Drivers"), -- BEATER
	Shooters = Style.teamColor("Shooters"), -- HUNTER
	-- A BODY WITH NO TEAM. `FIELD_MUTED` and not `MUTED`: this is text-weight colour over a field
	-- surface, and §2 bans `MUTED` there (4.11 : 1 over a bright sky).
	none = Style.LOOK.FIELD_MUTED,
	stand = Style.teamColor("Shooters"), -- a stand is a hunter's place, so it wears their colour
	-- ONE "GO HERE" ORANGE IN THE GAME (§1.1). `#EB5A37` was this map's and the compass's and the
	-- way-mark's; all three are `BLAZE_HI` now.
	arrow = Style.LOOK.BLAZE_HI,
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
-- THE MINIMAP'S AND THE FULL MAP'S RECTANGLES AT A GIVEN VIEWPORT: x, y, width, height (task 165).
-- PURE AND EXPORTED, for the reason `Objective.lineRect` and `Rail.rect` are: the overlap case
-- further down this module's spec measures `AbsolutePosition` at whatever size the Studio window
-- happens to be, so it cannot answer for 400 x 800 -- and 400 x 800 is the claim Karen is being
-- asked to believe. Arithmetic answers for any viewport.
function MapUi.minimapRect(viewport: Vector2): (number, number, number, number)
	local config = MapUi.CONFIG
	local diameter = MapUi.diameterFor(viewport.X, viewport.Y)
	return viewport.X - config.MINIMAP_MARGIN - diameter, config.MINIMAP_TOP, diameter, diameter
end

-- THE PANEL'S RENDERED rectangle: built at a fixed size, fitted with one `UIScale`, centred in the
-- room left after the rail's column -- the same three lines `layoutFor` performs, so a change to one
-- shows up in the other's spec.
--
-- `railColumnPx` IS OPTIONAL AND nil IS THE CONSTANT (task 220), so every caller written before the
-- fold gets the answer it always got. A folded rail is 124 wide and the panel must clear THAT.
function MapUi.fullMapRect(viewport: Vector2, railColumnPx_: number?): (number, number, number, number)
	local config = MapUi.CONFIG
	-- THE CONSTANT, AND NOT `MapUi.railColumn()` (the Reviewer, round 1). Defaulting to the told
	-- value would make this function answer differently in a folded session than in an unfolded
	-- one for the SAME arguments, which is exactly what a pure exported rectangle may not do -- and
	-- `hud_clarity.spec` calls it with one argument. The renderer passes the live column in.
	local column = railColumnPx_ or config.RAIL_COLUMN_PX
	local roomX = viewport.X - config.FULL_SIDE_INSET - column
	local roomY = viewport.Y - config.FULL_TOP - config.FULL_BOTTOM_INSET
	local scale = math.max(0.1, math.min(1, roomX / config.FULL_MAX_WIDTH_PX, roomY / config.FULL_MAX_HEIGHT_PX))
	local width = config.FULL_MAX_WIDTH_PX * scale
	local height = config.FULL_MAX_HEIGHT_PX * scale
	return viewport.X / 2 - math.round(column / 2) - width / 2, config.FULL_TOP, width, height
end

-- WHAT THE LEGEND SAYS, as data. Six rows, in the order they are drawn. `shape` is "line" for the
-- road (a thin bar), "square" for a stand, "diamond" for the target mark and "dot" for a body, which
-- is exactly how each of those is drawn on the map -- a key whose swatch is a different shape from
-- the thing it keys is a key that has to be explained.
--
-- `GO HERE` BECAME A DIAMOND IN TASK 201 E, AND THAT IS A REGRESSION THIS TASK CAUSED AND FIXED.
-- Before the palette the target was `#EB5A37` and a stand `#FFA03C`: two oranges, told apart by
-- colour alone, and the key drew both as squares. The system has ONE go-here orange and the hunters
-- ARE that orange (§1.1: `HUNTER` and `BLAZE_HI` are both `#E8832F`), so after the recolour the key
-- showed three identical orange squares reading STAND, GO HERE and HUNTER. The MAP never had the
-- problem -- it has always drawn the target turned 45 degrees (`buildDrawer`'s `goal.Rotation = 45`)
-- and a body as a circle -- so the fix is to make the key draw what the map draws. Found by looking
-- at `t201e-fullmap.png` (rule 5), not by a test.
function MapUi.legendRows(): { { word: string, color: Color3, shape: string } }
	local colors = MapUi.COLORS
	return {
		{ word = "ROAD", color = MapUi.CONFIG.ROAD_COLOR, shape = "line" },
		{ word = "STAND", color = colors.stand, shape = "square" },
		{ word = "GO HERE", color = colors.arrow, shape = "diamond" },
		{ word = "YOU", color = colors.own, shape = "dot" },
		{ word = "HUNTER", color = colors.Shooters, shape = "dot" },
		{ word = "BEATER", color = colors.Drivers, shape = "dot" },
	}
end

-- IS THERE ROOM TO READ IT? The legend lives in the panel's fixed pixel space and is scaled with it,
-- so below a scale where `LEGEND_TEXT_PX` would render under `LEGEND_MIN_TEXT_PX` the whole block is
-- hidden rather than drawn illegibly. 8 px is the floor for a drawn word (it was measured for
-- `Enum.Font.Code`, which left this file in task 201 E; BuilderSans at 8 px is no more readable, so
-- the floor stands); 12 / 8 makes the threshold 0.67, which a 400 px phone (scale ~0.3) is well
-- under and 1080p (scale 1) is over.
function MapUi.legendVisible(scale: number): boolean
	local config = MapUi.CONFIG
	return scale * config.LEGEND_TEXT_PX >= config.LEGEND_MIN_TEXT_PX
end

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

-- IS THIS POINT INSIDE THE WORLD THE MAP STATES? PURE (task 177).
--
-- IT NAMES NO LOBBY, and that is the whole point of writing it this way: *"you are outside the map's
-- own frame"* is a fact about the world's stated geometry. It stays true if the lobby moves, it needs
-- no lobby concept in the Hud, and it answers for any world.
function MapUi.withinBounds(bounds: Bounds, me: Vector3): boolean
	return me.X >= bounds.minX and me.X <= bounds.maxX and me.Z >= bounds.minZ and me.Z <= bounds.maxZ
end

-- `outsideBounds` DEFAULTS TO FALSE (nil = false), so every existing caller and every existing spec
-- case is bit-identical (task 177).
--
-- WHY THE MINIMAP HIDES AND THE FULL MAP DOES NOT. The minimap is centred on the PLAYER with a
-- 300-stud range, so from the lobby -- 513 studs outside the Forest Test's stated bounds -- it would
-- draw a dark disc, a scale bar and your own wedge and nothing else. That is a half-drawn drive,
-- which is exactly what this is not allowed to be. The FULL map holds the whole stated world and
-- PINS an out-of-range marker to its border, which is its own documented rule -- so a player at the
-- lodge sees the road, the nine stands and himself pinned to the south edge. That is true, it is the
-- map's own language, and M and the rail button keep working, so there is no dead button.
function MapUi.minimapVisible(
	open: boolean,
	suppressed: boolean,
	reportOpen: boolean,
	hasGeometry: boolean,
	outsideBounds: boolean?
): boolean
	if outsideBounds == true then
		return false
	end
	return hasGeometry and MapUi.CONFIG.MINIMAP_ENABLED and not open and not suppressed and not reportOpen
end

-- PURE, because a Studio Play on a PC has `TouchEnabled` false and a spec cannot change that.
-- ---------------------------------------------------------------- what a world tells the map

-- ONE SHAPE, TWO PROVIDERS (rule 3). `MapUi` draws a `MapGeometry` and does not know which world
-- made it, so there is no second code path through the drawing.

-- THE FOREST TEST'S MAP, out of the world's own data module. EVERY NUMBER IS ASKED FOR, NOT COPIED:
-- `ForestTest.roadZ(x)` is that module's own words *"the one definition; every other reader calls
-- this"*, and `standPosition(index, layout)` is where a hunter stands. A map that re-typed the sine would be
-- a second curve that disagrees with the first the next time the Director bends the road.
--
-- `data` IS PASSED IN rather than required, so this stays pure and a spec can hand it a table.
--
-- ...AND SO IS THE LAYOUT (task 179). This world deals one of several drive layouts per drive, and
-- the LAYOUT is what says where the line is, how long it is, how many stands it has and whether it
-- bends at all. The client does not choose it and does not derive it: the server publishes the name
-- and `geometryFor` below resolves it, because a client that guessed would draw a different road
-- from the one the hunter's feet are on -- invisible in a screenshot, and this project's named
-- killer.
function MapUi.geometryFromForestTest(data: any, layout: any): MapGeometry
	local config = MapUi.CONFIG
	local centre = layout.centre
	local halfSpan = layout.halfSpanStuds
	local margin = config.GEOMETRY_MARGIN_STUDS

	local road = {}
	local samples = math.max(2, config.ROAD_SAMPLES)
	for index = 1, samples do
		local t = (index - 1) / (samples - 1)
		local x = centre.X - halfSpan + t * (2 * halfSpan)
		-- A STRAIGHT LAYOUT SAMPLES TO A STRAIGHT POLYLINE, with no second code path: `roadZ`
		-- answers `centre.Z` at every x when the amplitude is 0, which is the same shape
		-- `geometryFromMap` already draws DEV's two-point road with.
		table.insert(road, Vector2.new(x, data.roadZ(x, layout)))
	end

	local stands = {}
	for index = 1, layout.standCount do
		local at = data.standPosition(index, layout)
		table.insert(stands, Vector2.new(at.X, at.Z))
	end

	-- THE BOUNDS HOLD EVERYTHING THIS WORLD STATES. South is where a boar is gone (`EXIT_Z`, which
	-- already has the road's amplitude in it); north is the LARGER of the two drive-side starts --
	-- the drivers' 700 and a beater's own `LINE.spawnNorthStuds + BEATER.behindLineStuds` (580 since
	-- task 162; 700 is still the larger, so these bounds are unchanged by it) --
	-- because a driver walking in from 700 studs is one of the *"other players moving"* Karen asked
	-- to see, and a map that cuts him off has lost him.
	local north = math.max(data.DRIVERS.startNorthStuds, data.beaterNorthStuds())
	return {
		world = data.WORLD,
		bounds = {
			minX = centre.X - halfSpan - margin,
			maxX = centre.X + halfSpan + margin,
			minZ = data.exitZOf(layout) - margin,
			maxZ = centre.Z + layout.amplitudeStuds + north + margin,
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
--
-- `layoutName` IS THE STRING THE SERVER PUBLISHED (task 179), and an unknown or absent one gets NO
-- MAP rather than the road's: *"a world that has stated nothing gets no map at all"* is the rule
-- above, and "this drive is on a layout I have never heard of" is exactly a world that has stated
-- nothing. The attribute signal in `Hud` redraws the instant a name arrives, so the no-name case is
-- a frame at worst -- the server publishes inside `Match.start`'s first marker read, before any
-- player's Hud runs.
function MapUi.geometryFor(world: string, forestTest: any?, map: any?, layoutName: string?): MapGeometry?
	if world == "forest-test" then
		if forestTest == nil then
			return nil
		end
		local layout = forestTest.layoutNamed(layoutName)
		if layout == nil then
			return nil
		end
		return MapUi.geometryFromForestTest(forestTest, layout)
	end
	-- THE WORLD MUST BE THE ONE THE MAP MODULE IS ABOUT (task 155 round 1, the Reviewer's note).
	-- Without this compare, ANY unrecognised world fell through to the DEV geometry and would have
	-- drawn the DEV road over a place that has never heard of it -- a map that is wrong rather than
	-- absent, which is the opposite of design section 5.4's rule. Unreachable today, because
	-- `Map.EXPECTED_WORLD` is `WORLD_BY_PLACE[game.PlaceId] or DEFAULT_WORLD` and so is always one of
	-- the two; the next place id added to that table is when it would have mattered.
	if
		map ~= nil
		and map.EXPECTED_WORLD == world
		and map.ROAD ~= nil
		and map.FIELD ~= nil
		and map.FIELD.bounds ~= nil
	then
		return MapUi.geometryFromMap(map)
	end
	return nil
end

-- ---------------------------------------------------------------- state: one writer, this module

local miniFrame: Frame? = nil
local fullFrame: Frame? = nil
-- THE LEGEND, which is this module's to fill.
--
-- THE RAIL IS NO LONGER HERE AT ALL (task 220). Until this task `layoutFor` wrote the rail frame's
-- POSITION, because this module knows the minimap's rendered diameter and the rail hangs under it.
-- The rail now has to CLAMP itself inside a landscape phone's viewport and fold into two columns,
-- and a clamp cannot live in two modules -- so `Rail.applyLayout` writes its own position and this
-- module is TOLD how wide the resulting column is. One writer removed, not one added. The three
-- lines are archived in `backups/2026-10-21_mapui-rail-position.md` (rule 7).
local legendFrame: Frame? = nil
-- The modal's full-screen scrim (task 201 E). `Hud.build` creates it; `applyVisibility` is its one
-- writer, and it is written from the PANEL's own answer so the two cannot part company.
local scrimFrame: Frame? = nil
-- HOW WIDE A COLUMN THE RAIL IS ACTUALLY OCCUPYING (task 220), told by the Hud through
-- `MapUi.setRailColumn`. It used to be the constant `CONFIG.RAIL_COLUMN_PX` and could only ever be
-- one button wide; a rail that FOLDS into two columns on a landscape phone occupies 124, and a
-- panel centred against the old 68 would run under it. The constant is still the default and the
-- answer for every viewport that does not fold.
local railColumnPx = nil :: number?
local miniScale: UIScale? = nil
local fullScale: UIScale? = nil

local open = false
local suppressed = false
-- IS THIS PLAYER OUTSIDE THE WORLD THE MAP STATES? Written once per tick by `render`, which already
-- finds his position, and read by `applyVisibility`, which stays the one writer of both frames'
-- `Visible` (task 177). False until a tick has found a position: absent is not outside.
local outside = false
local geometry: MapGeometry? = nil
local pushBearing: number? = nil
local pushLabel: string? = nil
-- WHERE THE PLAYER MUST GO, told by the Hud (task 165) -- flat, because this module draws in x/z.
-- `nil` is "nowhere right now" and then no target mark is drawn at all, which is `setPush`'s own rule
-- and `Objective.targetFor`'s: a world that has stated nothing gets no mark rather than a guess.
local targetPoint: Vector2? = nil
local targetWord: string? = nil
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
	-- WHERE YOU MUST GO (task 165): one mark per drawer, and exactly one drawer is live per tick, so
	-- there is one target on screen. Karen: *"where will be hunter position where they stand and what
	-- direction to move"* -- this is the "where they stand" half, for HER stand rather than all nine.
	target: Frame,
	targetWord: TextLabel,
}
local drawers: { Drawer } = {}

-- ---------------------------------------------------------------- what this module put on screen
--
-- EVERY INSTANCE `setGeometry` PARENTS INTO A FRAME IT DOES NOT OWN goes through `claim`, and
-- `teardown` destroys exactly that list when the world hands the map a different layout (task 179,
-- round 2's finding 1 and round 3's gate run).
--
-- IT IS A LIST AND NOT A RULE, because the rule is what was wrong twice over. Round 2 cleared the
-- frames' CHILDREN "by ownership" and took `Hud.build`'s own `UICorner` (which is HOW a circle is
-- drawn in Roblox GUI without an uploaded image), both `UIStroke` rims and the `MapLegend` frame --
-- none of which `Hud.build` can make again, because it runs once. Round 3's first list then missed
-- the other direction: `buildDrawer` parents its markers, the player's own dot, the view wedge, the
-- push arrow and its word and the goal mark DIRECTLY into the minimap frame, so a rebuild left the
-- old set behind and the map carried two push arrows -- the stale one still `Visible` -- which the
-- gate caught in `map_ui.spec`. An instance nobody claimed is never destroyed by a rebuild, and an
-- instance this module parents is always claimed: the two halves of one rule, in one place.
local claimed: { Instance } = {}

local function claim<T>(instance: T & Instance): T
	table.insert(claimed, instance)
	return instance
end

local lastViewport = Vector2.new(0, 0)
-- A VIEWPORT A CALLER HAS PINNED, for as long as it holds it. A spec cannot resize a Studio window,
-- and without this the 20 Hz tick reads the real `ViewportSize` within 50 ms and undoes whatever was
-- laid out -- MEASURED, task 155 round 2: the case read 150 px back where it had asked for 96,
-- because the tick landed between the call and the read. `applyLayout(nil)` gives the screen back.
local viewportOverride: Vector2? = nil
-- `keyToggles` IS COUNTED APART FROM `toggles`, AND THAT IS THE WHOLE POINT (task 155 round 1, the
-- Reviewer's blocking finding). `toggles` counts every change, including a spec's own `setOpen`, so
-- a case asserting `toggles >= 2` passes with the M binding DELETED -- it proved nothing about the
-- key. This one is incremented only on the bound action's `Begin`, so it is evidence that a real M
-- arrived, which is rule 6: test the player's path, not the harness's.
--
-- `pinned` IS PER TICK, like `overflow` beside it, and is reset at the top of `render`: one name
-- must not answer "now" for one field and "since boot" for another.
local stats = {
	-- HOW MANY TIMES THE PICTURE WAS DRAWN AGAIN because the world's geometry changed under it
	-- (task 179): one per drive layout change. 0 in a world with one layout, which is DEV.
	rebuilds = 0,
	ticks = 0,
	toggles = 0,
	keyToggles = 0,
	pinned = 0,
	overflow = 0,
	builtAt = nil :: number?,
	elapsed = 0,
}
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
				local team = marker:GetAttribute("Team") :: string?
				table.insert(out, {
					userId = (marker:GetAttribute("UserId") :: number?) or 0,
					u = marker.Position.X.Offset,
					v = marker.Position.Y.Offset,
					pinned = marker.BackgroundTransparency > 0,
					mine = marker.Name == "Own",
					-- ONE SHAPE FOR ONE ANSWER (task 155 round 1, the Reviewer's note). The
					-- attribute cannot hold nil, so `renderDrawer` writes `""` for a player with no
					-- team; reading it straight back gave `""` here against `pointsFor`'s `nil`.
					team = if team == "" then nil else team,
				})
			end
		end
	end
	return out
end

-- ---------------------------------------------------------------- the picture, built once

-- `stroked` IS GONE (task 201 E). It put a 1 px BLACK `UIStroke` on every mark and every label on
-- this map -- the road's scale bar, each stand, each player dot, each legend swatch and all six
-- legend words -- and §2 is the whole of why that is over: *"an outline thickens every letter,
-- halves the apparent size of 11 px type, and still fails over a bright sky because the outline
-- itself is only 1 px"*. On an 8 px stand square an outline on all four sides is HALF the square.
-- What separates a mark from the ground now is the ground: the minimap is a slate and the full map
-- is an opaque panel, both measured in §2's contrast table.

local function label(parent: GuiObject, name: string, size: number, text: string): TextLabel
	local node = Instance.new("TextLabel")
	node.Name = name
	node.BackgroundTransparency = 1
	-- BUILDERSANS BOLD, WHICH IS WHAT `Style.faceFor` ANSWERS FOR `MICRO` AND `LABEL` (§1.2: Oswald
	-- for a title, a name and every number; BuilderSans for every label). `Enum.Font.Code` is gone
	-- from this file with it -- the map's numbers are stand INDEXES and a scale in metres, not a
	-- column of figures that has to line up.
	node.FontFace = Style.faceFor(if size >= MapUi.CONFIG.TITLE_SIZE then "LABEL" else "MICRO")
	node.TextScaled = false
	node.TextWrapped = false
	node.TextSize = size
	node.TextColor3 = MapUi.CONFIG.TEXT_COLOR
	node.Text = text
	node.ZIndex = MapUi.CONFIG.Z_INDEX + 3
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
		claim(node).Parent = frame
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
	claim(own).Parent = frame

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
	claim(wedge).Parent = frame

	-- WHICH WAY TO GO. Karen: *"what direction to move"*. A bar from your own marker with the word at
	-- its tip -- and the WORD TRAVELS WITH THE BEARING, which is task 153 round 2's blocking finding:
	-- a marker that moved without its label told a beater the drive was south.
	local arrow = Instance.new("Frame")
	arrow.Name = "PushArrow"
	-- CENTRED, AND THE SCREENSHOT IS WHY (rule 5, task 155). It was anchored at its BASE (0.5, 1) on
	-- the reasoning that a bar rotated about its anchor swings about its foot. MEASURED in the Forest
	-- Test, in both sizes at once: a beater's arrow pointed NORTH while her word `ROAD` and the road
	-- itself were south. **`GuiObject.Rotation` pivots about the element's CENTRE**, not its
	-- `AnchorPoint` -- so a 180-degree turn left a symmetric bar exactly where it was drawn, above
	-- the player. The fix does not depend on the pivot at all: the bar is CENTRED half its own length
	-- along the bearing, so it runs from the player outward whatever the rotation turns about.
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(config.ARROW_PX, config.ARROW_LENGTH_PX)
	arrow.Position = UDim2.fromScale(0.5, 0.5)
	arrow.BackgroundColor3 = MapUi.COLORS.arrow
	arrow.BorderSizePixel = 0
	arrow.ZIndex = config.Z_INDEX + 2
	arrow.Visible = false
	claim(arrow).Parent = frame

	local word = claim(label(frame, "PushWord", config.LABEL_SIZE, ""))
	word.TextColor3 = MapUi.COLORS.arrow
	word.AnchorPoint = Vector2.new(0.5, 0.5)
	word.Size = UDim2.fromOffset(60, config.LABEL_SIZE + 2)
	word.Visible = false

	-- THE TARGET MARK (task 165): the ONE place on this map that is yours. A rotated square in the
	-- orange-red the push arrow and the compass's DRIVE marker already share, so the full map carries
	-- exactly one mark of that colour and it is where you are going. The other stands keep
	-- `COLORS.stand` and their index labels, so "mine" and "a stand" are two pictures.
	local goal = Instance.new("Frame")
	goal.Name = "Target"
	goal.AnchorPoint = Vector2.new(0.5, 0.5)
	goal.Size = UDim2.fromOffset(config.STAND_PX + 4, config.STAND_PX + 4)
	goal.Position = UDim2.fromScale(0.5, 0.5)
	goal.BackgroundColor3 = MapUi.COLORS.arrow
	goal.BorderSizePixel = 0
	goal.Rotation = 45
	goal.ZIndex = config.Z_INDEX + 2
	goal.Visible = false
	claim(goal).Parent = frame

	-- A SIBLING AND NOT A CHILD, for the reason the waypoint's word is one in `Hud.build`: a child
	-- would inherit the 45-degree `Rotation` and read at an angle.
	local goalWord = claim(label(frame, "TargetWord", config.LABEL_SIZE, ""))
	goalWord.TextColor3 = MapUi.COLORS.arrow
	goalWord.AnchorPoint = Vector2.new(0.5, 0)
	goalWord.Size = UDim2.fromOffset(70, config.LABEL_SIZE + 2)
	goalWord.Visible = false

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
		target = goal,
		targetWord = goalWord,
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
local function layoutFor(viewport: Vector2)
	local config = MapUi.CONFIG
	local mini, full = miniFrame, fullFrame
	if mini == nil or full == nil then
		return
	end

	-- ONE WRITER OF THE RENDERED DIAMETER, AND IT IS THE `UIScale` (task 155 round 1, the Reviewer's
	-- blocking finding). This used to write `mini.Size` AS WELL as the scale, and the two multiply:
	-- **a `UIScale` scales the GuiObject it is parented to, not only its descendants** -- MEASURED on
	-- the full map in the same run, 984 x 700 built, `UIScale` 0.897, `AbsoluteSize` 883 x 628. So a
	-- 96 px minimap at a 400 px viewport rendered at 96 x 96/150 = 61 px, and the picture inside it
	-- -- built in the fixed 150 px space with a half-extent of 75 -- was drawn at radius 48 inside a
	-- frame of radius 30, under `ClipsDescendants`: a marker PINNED TO THE RIM was clipped out of
	-- existence, which is the one thing the pin exists to prevent.
	--
	-- NOTHING IN THE RUN COULD SEE IT: `diameterFor(969, 784)` is 150, so the scale was exactly 1 for
	-- both gate runs and both screenshots. `map_ui.spec` asserts it at a phone-sized viewport now,
	-- which is what `MapUi.applyLayout` is public for.
	--
	-- The frame's own `Size` is `MINIMAP_DIAMETER_PX` and stays there (written once by `Hud.build`),
	-- so `AbsoluteSize` is `MINIMAP_DIAMETER_PX * Scale` = `diameter`, exactly.
	local diameter = MapUi.diameterFor(viewport.X, viewport.Y)
	mini.Position = UDim2.new(1, -config.MINIMAP_MARGIN, 0, config.MINIMAP_TOP)
	local miniUiScale = miniScale
	if miniUiScale ~= nil then
		miniUiScale.Scale = diameter / config.MINIMAP_DIAMETER_PX
	end

	-- THE BUTTON RAIL IS NOT WRITTEN HERE ANY MORE (task 220). `Rail.applyLayout` owns its position
	-- and its fold, from `Rail.topFor(diameter, MINIMAP_TOP)` -- the same arithmetic these three
	-- lines performed by hand, now in the module that also has to clamp it inside the viewport.
	-- Archived in `backups/2026-10-21_mapui-rail-position.md` (rule 7).

	-- THE PANEL IS BUILT AT A FIXED SIZE AND SCALED TO FIT, so one number handles a phone and
	-- nothing inside it moves.
	local wanted = full.Size
	local panelWidth = wanted.X.Offset
	local panelHeight = wanted.Y.Offset
	-- THE RAIL'S COLUMN IS RESERVED (task 165). The panel is CENTRED, so without this it runs under
	-- the rail at a phone's width -- measured in `CONFIG.RAIL_COLUMN_PX`'s own comment. One number,
	-- in the one function that already writes both `UIScale`s. Since task 220 it is the column the
	-- rail SAYS it is occupying, because a folded rail is 124 wide and not 68.
	local column = MapUi.railColumn()
	local roomX = viewport.X - config.FULL_SIDE_INSET - column
	local roomY = viewport.Y - config.FULL_TOP - config.FULL_BOTTOM_INSET
	local scale = 1
	if panelWidth > 0 and panelHeight > 0 then
		scale = math.min(1, roomX / panelWidth, roomY / panelHeight)
	end
	local fullUiScale = fullScale
	if fullUiScale ~= nil then
		fullUiScale.Scale = math.max(0.1, scale)
	end
	-- SHIFTED LEFT BY HALF THE COLUMN, so the panel stays centred in the room it actually has.
	full.Position = UDim2.new(0.5, -math.round(column / 2), 0, config.FULL_TOP)

	-- THE LEGEND GOES WITH THE PANEL'S SCALE, so it is hidden when no font inside the panel could be
	-- read (`legendVisible`). It is positioned once here rather than per tick: it says nothing that
	-- changes.
	local legend = legendFrame
	if legend ~= nil then
		legend.Visible = MapUi.legendVisible(math.max(0.1, scale))
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

-- PUBLIC AND BY PARAMETER (task 155 round 1). A spec cannot resize a Studio viewport, so the one
-- way to prove the layout is right at a PHONE's width is to hand it one -- which is this repo's
-- rule for every flagged or branched path: *"reachable by parameter as well as by flag, or its two
-- states cannot be tested"*. The next real viewport change overwrites whatever a caller set.
function MapUi.applyLayout(viewport: Vector2?)
	viewportOverride = viewport
	local camera = Workspace.CurrentCamera
	local resolved = viewport or (if camera then camera.ViewportSize else lastViewport)
	lastViewport = resolved
	layoutFor(resolved)
end

-- What the layout is pinned to, or nil when it follows the real screen. Read by a spec so it can
-- assert it gave the screen back rather than assuming it did.
function MapUi.pinnedViewport(): Vector2?
	return viewportOverride
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
	-- THE SCRIM FOLLOWS THE PANEL EXACTLY (task 201 E, §5 surface 14). It is read off the panel's
	-- own answer rather than recomputed, so the two can never disagree -- a scrim left up over a
	-- closed map is a dark screen with no way to tell why, which is `docs/PROJECT_CONTEXT.md`'s own
	-- "a visibility audit certified a blank screen twice".
	if scrimFrame ~= nil then
		(scrimFrame :: Frame).Visible = full.Visible
	end
	-- `outside` IS WRITTEN BY `render`, WHICH ALREADY FINDS `me` (task 177): this stays the ONE writer
	-- of both frames' `Visible` and the Hud gains no plumbing at all. It is false until a tick has
	-- found a position, because ABSENT IS NOT OUTSIDE -- a map that hid itself while a player was
	-- respawning would flicker once per death.
	mini.Visible = MapUi.minimapVisible(open, suppressed, reportOpen, hasGeometry, outside)
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

	-- WHERE YOU MUST GO, drawn from the MAP's own projection and not from the player's (task 165):
	-- it is a place in the world, so it is projected like the road and pinned like a marker. Done
	-- BEFORE the `mine == nil` return below, because a target exists whether or not this client has a
	-- character yet -- and a map that forgot to draw the one place you are going because you were
	-- mid-respawn is the kind of hole `docs/PROJECT_CONTEXT.md` records being certified twice.
	local goal, goalWord = drawer.target, drawer.targetWord
	if targetPoint == nil then
		goal.Visible = false
		goalWord.Visible = false
	else
		local at = targetPoint :: Vector2
		local gu, gv, inView = MapUi.project(at.X, at.Y, view)
		local transparency = if inView then 0 else config.PINNED_TRANSPARENCY
		goal.Position = UDim2.new(0.5, math.round(gu), 0.5, math.round(gv))
		goal.BackgroundTransparency = transparency
		goal.Visible = true
		goalWord.Position = UDim2.new(0.5, math.round(gu), 0.5, math.round(gv) + config.STAND_PX)
		local text = targetWord or "GO"
		if goalWord.Text ~= text then
			goalWord.Text = text
		end
		goalWord.TextTransparency = transparency
		goalWord.Visible = true
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
	-- HALF A LENGTH ALONG THE BEARING, so the bar's near end sits on the player and its far end
	-- points the way to go. See the arrow's own comment in `buildDrawer` for the measurement.
	local du, dv = MapUi.facingOffsetPx(bearing, config.ARROW_LENGTH_PX / 2)
	arrow.Position = UDim2.new(0.5, math.round(point.u + du), 0.5, math.round(point.v + dv))
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
	stats.pinned = 0
	local now = os.clock()
	if firstTickAt == nil then
		firstTickAt = now
	end
	stats.elapsed = now - (firstTickAt :: number)

	local camera = Workspace.CurrentCamera
	local viewport = viewportOverride or (if camera then camera.ViewportSize else lastViewport)
	if viewport.X ~= lastViewport.X or viewport.Y ~= lastViewport.Y then
		lastViewport = viewport
		layoutFor(viewport)
	end

	-- THE ROSTER AND `me` ARE READ BEFORE THE VISIBILITY PASS (task 177), because whether the minimap
	-- is on screen now depends on where this player is standing -- and `applyVisibility` must stay the
	-- ONE writer of both frames' `Visible`. Nothing else about the order changed: `roster()` is still
	-- called once per tick and `Players:GetPlayers()` still once inside it.
	local sources = roster()
	stats.overflow = MapUi.overflowFor(sources)
	local me: Vector3? = nil
	for _, source in ipairs(sources) do
		if source.userId == localUserId then
			me = source.position
		end
	end
	outside = me ~= nil and not MapUi.withinBounds((geometry :: MapGeometry).bounds, me :: Vector3)

	MapUi.applyVisibility()
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

-- WHERE THE PLAYER MUST GO, handed in BY THE HUD and never derived here (task 165) -- the
-- `setPush` shape, and for the same reason: `Hud.renderObjective` is the ONE evaluation of the
-- objective and `MapUi.luau` is a sibling of `init.luau`, so requiring it would be a cycle.
--
-- `nil` IS "NOWHERE RIGHT NOW" and then no mark is drawn. A hunter standing on his own stand has
-- arrived, so there is nothing to point at -- which is the same answer `Objective.arrived` gives the
-- chevron and the compass, from one evaluation.
function MapUi.setTarget(point: Vector2?, word: string?)
	targetPoint = point
	targetWord = if point == nil then nil else (word or "GO")
end

-- HOW WIDE THE RAIL'S COLUMN IS RIGHT NOW: what the Hud last told this module, or the constant.
function MapUi.railColumn(): number
	return railColumnPx or MapUi.CONFIG.RAIL_COLUMN_PX
end

-- THE HUD TELLS, THIS MODULE WRITES -- the `setPush` / `setTarget` shape, and for their reason:
-- `Hud.renderObjective` is the one evaluation and `MapUi.luau` may not require `init.luau`.
-- Edge-triggered, so a per-frame caller costs one comparison and never a relayout.
-- 220a(c): IT MUST NOT CLEAR A PINNED VIEWPORT. `MapUi.applyLayout(nil)` means *"follow the real
-- screen"* -- it writes `viewportOverride` -- so calling it with no argument from here threw away a
-- viewport a spec (or a measurement pass) had pinned, and the layout snapped back to the Studio
-- window mid-case. The pin is read back and handed in again, so this function changes the COLUMN and
-- nothing else.
function MapUi.setRailColumn(px: number?, viewportOverrideNow: Vector2?)
	local next_ = if type(px) == "number" and px > 0 then px else nil
	if railColumnPx == next_ then
		return
	end
	railColumnPx = next_
	MapUi.applyLayout(viewportOverrideNow or viewportOverride)
end

function MapUi.target(): (Vector2?, string?)
	return targetPoint, targetWord
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
-- ...AND IT REBUILDS WHEN THE GEOMETRY IS A DIFFERENT WORLD (task 179 round 2, finding 3).
--
-- `built` USED TO LATCH FOR THE LIFE OF THE CLIENT, which was right while a world had exactly one
-- geometry and wrong the moment it had three: the Forest Test deals a drive layout per drive, and a
-- latched build left the hunter's minimap and full map drawn on the PREVIOUS layout's road and
-- stands from drive 2 on -- the attribute signal replaced only the `geometry` table that
-- `withinBounds` reads, so the picture itself never moved.
--
-- IT IS STILL IDEMPOTENT, and that is what the `sameGeometry` test is for: `Hud` calls this on every
-- attribute change, and an attribute that is written again with the same name must not tear a
-- drawn map down and build it back. Only a geometry that is really different is rebuilt.
--
-- THE TEAR-DOWN IS BY A LIST OF WHAT THIS MODULE MADE (`claim`, below), not by clearing the frames:
-- `Hud.build` has four instances of its own in them and round 2 destroyed all four.
local function sameGeometry(a: MapGeometry?, b: MapGeometry?): boolean
	if a == nil or b == nil then
		return a == b
	end
	if a.world ~= b.world or #a.road ~= #b.road or #a.stands ~= #b.stands then
		return false
	end
	for key, value in pairs(a.bounds) do
		if math.abs(value - (b.bounds :: any)[key]) > 1e-6 then
			return false
		end
	end
	for index, point in ipairs(a.stands) do
		if (point - b.stands[index]).Magnitude > 1e-3 then
			return false
		end
	end
	for index, point in ipairs(a.road) do
		if (point - b.road[index]).Magnitude > 1e-3 then
			return false
		end
	end
	return true
end

-- WHAT THIS MODULE PUT INSIDE THE HUD'S FRAMES, so a rebuild can take back exactly that and nothing
-- else (round 2, finding 1).
--
-- ROUND 2 CLEARED THE FRAMES' CHILDREN BY OWNERSHIP and the ownership claim was simply WRONG:
-- `Hud.build` parents four things of its own into them -- the minimap's `UICorner` (which is HOW a
-- circle is drawn in Roblox GUI without an uploaded image, and Karen asked for *"small map in left
-- or right corner circle like is on another games"*), a `UIStroke` rim on each frame, and the
-- `MapLegend` frame itself, which is a CHILD of the full map and is the very instance handed back as
-- `frames.legend`. So the first layout change turned the minimap into a square with the road in its
-- corners, took both rims, and left `legendFrame` pointing at a destroyed instance that the rebuild
-- then wrote every swatch into. `Hud.build` runs once, so nothing ever put them back.
--
-- A LIST AND NOT A RULE, because the rule is what was wrong. Every instance this module parents into
-- a frame it does not own goes through `claim`, and `teardown` destroys that list -- children go with
-- their parents. An instance nobody claimed cannot be destroyed by a rebuild, and an instance this
-- module parents is always claimed: the two halves of one rule, in one place.
--
-- THE COUNT IS NOT WRITTEN DOWN ANY MORE, and that is the third lesson rather than a shrug. It said
-- "nine" while there were fifteen, which is a comment whose job is to say the list is COMPLETE
-- getting the one number it carries wrong. What makes the list complete is checkable instead:
-- `map_ui.spec` counts the drawer's own children on the minimap after a redraw per layout, so the
-- next instance added to `buildDrawer` and not claimed fails a case rather than passing a comment.
-- Round 3 missed `TargetWord` exactly that way, one instance after missing six.
local function teardown()
	for index = #claimed, 1, -1 do
		claimed[index]:Destroy()
	end
	table.clear(claimed)
	table.clear(drawers)
	-- BOTH, not one: the two `UIScale`s were just destroyed with everything else, and leaving
	-- `fullScale` pointing at a destroyed instance was an asymmetry that read as an oversight. The
	-- rebuild assigns both again on its next statements, so this is about what is TRUE between the
	-- two halves rather than about a bug anybody could reach.
	miniScale, fullScale = nil, nil
	built = false
	stats.rebuilds += 1
end

function MapUi.setGeometry(next_: MapGeometry?)
	local before = geometry
	geometry = next_
	if next_ ~= nil and built and not sameGeometry(before, next_) then
		-- A DIFFERENT WORLD, SO THE PICTURE IS DRAWN AGAIN. `ContextActionService:BindAction` at the
		-- end of the build re-binds the same name to the same key, which the engine treats as a
		-- replacement rather than a second binding, so M stays one action.
		teardown()
	end
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
	local miniShrink = claim(Instance.new("UIScale"))
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
	claim(inner).Parent = mini
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

	local fullShrink = claim(Instance.new("UIScale"))
	fullShrink.Parent = full
	fullScale = fullShrink

	-- EYEBROW + TITLE (§3.4, §5 surface 14), and not one `MAP   forest` line any more. The eyebrow
	-- says WHAT KIND OF THING THIS IS in small spaced brass; the title is the world's own name. It
	-- is the pair every other panel in this game now wears, built out of the two labels rather than
	-- `Style.header` because that component draws a 64 px gradient bar and this panel's height is
	-- the world's span plus its furniture -- 64 px of chrome would come straight off the map.
	local eyebrow = claim(label(full, "Eyebrow", Style.SIZE.MICRO[1], Style.spaced("MAP")))
	eyebrow.TextColor3 = Style.LOOK.BRASS
	eyebrow.AnchorPoint = Vector2.new(0.5, 0)
	eyebrow.Position = UDim2.new(0.5, 0, 0, 5)
	eyebrow.Size = UDim2.new(1, -2 * config.FULL_PADDING, 0, config.FULL_EYEBROW_HEIGHT)

	local title = claim(label(full, "Title", config.TITLE_SIZE, model.world))
	title.FontFace = Style.FONT.OSWALD_SB
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 5 + config.FULL_EYEBROW_HEIGHT)
	title.Size = UDim2.new(1, -2 * config.FULL_PADDING, 0, config.FULL_TITLE_HEIGHT - config.FULL_EYEBROW_HEIGHT - 5)

	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.AnchorPoint = Vector2.new(0, 0)
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.fromOffset(usedWidth, usedHeight)
	canvas.Position = UDim2.fromOffset(config.FULL_PADDING, config.FULL_TITLE_HEIGHT + config.FULL_PADDING)
	canvas.ClipsDescendants = true
	canvas.ZIndex = config.Z_INDEX + 1
	claim(canvas).Parent = full
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
	bar.BackgroundColor3 = config.SCALE_BAR_COLOR
	bar.BorderSizePixel = 0
	bar.ZIndex = config.Z_INDEX + 3
	claim(bar).Parent = full

	local barLabel = claim(label(full, "ScaleLabel", config.LABEL_SIZE, string.format("%d m", metres)))
	barLabel.TextColor3 = config.SCALE_TEXT_COLOR
	barLabel.AnchorPoint = Vector2.new(0, 1)
	barLabel.Position = UDim2.new(0, config.FULL_PADDING, 1, -3)
	barLabel.Size = UDim2.fromOffset(80, config.LABEL_SIZE + 2)
	barLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- THE LEGEND'S ROWS (task 165), built once with the rest of the picture into the frame
	-- `Hud.build` created. `layoutFor` decides whether the block is `Visible` (`legendVisible`); this
	-- is the only thing that writes what is inside it.
	local legend = legendFrame
	if legend ~= nil then
		local holder = legend :: Frame
		holder.Position = UDim2.new(1, -config.FULL_PADDING, 1, -(config.FULL_FOOTER_HEIGHT - 4))
		-- IT IS A WELL NOW (§5 surface 22, task 201 E): *"the legend becomes a well of swatch
		-- rows"*. It was six swatches and six black-outlined words floating on the map itself, so
		-- the key and the thing it keyed were the same surface. A well is one step darker and one
		-- step less round than the panel it sits in, which is the ladder in §1.3.
		--
		-- A CLAIMED CHILD AND NOT THE HOLDER ITSELF, for two reasons. `Hud.build` owns that frame
		-- and `teardown` destroys only what `claim` recorded, so painting the holder would leave a
		-- coloured box behind on a world change; and a `UIPadding` on the holder would move every
		-- row, because each one is positioned by offset from its top-left. The well is drawn BEHIND
		-- the rows instead, one band under them and a little larger on every side, so
		-- `legendVisible`'s floor and the row arithmetic are untouched.
		local well = Instance.new("Frame")
		well.Name = "Well"
		well.BackgroundColor3 = config.LEGEND_WELL_COLOR
		well.BorderSizePixel = 0
		well.Position = UDim2.fromOffset(-Style.SPACE.M, -Style.SPACE.S)
		well.Size = UDim2.fromOffset(
			config.LEGEND_WIDTH_PX + Style.SPACE.M + Style.SPACE.S,
			config.LEGEND_HEIGHT_PX + Style.SPACE.S
		)
		well.ZIndex = config.Z_INDEX + 2
		Style.corner(well, config.LEGEND_WELL_CORNER)
		Style.stroke(well, config.LEGEND_WELL_EDGE, Style.EDGE_T.WELL)
		claim(well).Parent = holder
		for index, row in ipairs(MapUi.legendRows()) do
			local y = (index - 1) * config.LEGEND_ROW_HEIGHT
			local swatch = Instance.new("Frame")
			swatch.Name = string.format("Swatch%d", index)
			swatch.BackgroundColor3 = row.color
			swatch.BorderSizePixel = 0
			swatch.AnchorPoint = Vector2.new(0, 0.5)
			swatch.Position = UDim2.fromOffset(0, y + config.LEGEND_ROW_HEIGHT / 2)
			swatch.ZIndex = config.Z_INDEX + 3
			if row.shape == "line" then
				swatch.Size = UDim2.fromOffset(config.LEGEND_SWATCH_PX + 3, config.ROAD_PX)
			else
				swatch.Size = UDim2.fromOffset(config.LEGEND_SWATCH_PX, config.LEGEND_SWATCH_PX)
			end
			if row.shape == "dot" then
				local round = Instance.new("UICorner")
				round.CornerRadius = UDim.new(0.5, 0)
				round.Parent = swatch
			elseif row.shape == "diamond" then
				-- THE TARGET MARK'S OWN TURN (`buildDrawer`: `goal.Rotation = 45`). A square and a
				-- diamond in one orange are two marks; two squares in one orange are one mark drawn
				-- twice.
				swatch.Rotation = 45
			end
			claim(swatch).Parent = holder
			local word = claim(label(holder, string.format("Word%d", index), config.LEGEND_TEXT_PX, row.word))
			word.AnchorPoint = Vector2.new(0, 0.5)
			word.Position = UDim2.fromOffset(config.LEGEND_SWATCH_PX + 8, y + config.LEGEND_ROW_HEIGHT / 2)
			word.Size =
				UDim2.fromOffset(config.LEGEND_WIDTH_PX - config.LEGEND_SWATCH_PX - 8, config.LEGEND_TEXT_PX + 2)
			-- `BODY` AND NOT `PAPER` (§5 surface 22: *"text to `BODY` / `FIELD_MUTED`"*). A key is
			-- read once and then remembered; the marks on the map are what the eye goes back to.
			word.TextColor3 = config.LEGEND_WORD_COLOR
			word.TextXAlignment = Enum.TextXAlignment.Left
		end
	end

	table.clear(drawers)
	-- `buildDrawer` is handed the view table itself, so the minimap's centre is this one object and
	-- `renderDrawer` moves it in place -- no second copy to get out of step. The minimap's own frame
	-- IS its gate; the full map's gate is the PANEL, not the canvas it draws into.
	table.insert(drawers, buildDrawer("minimap", mini, mini, inner, miniView, layerView))
	table.insert(drawers, buildDrawer("full", canvas, full, nil, fullView, nil))

	local camera = Workspace.CurrentCamera
	lastViewport = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
	layoutFor(lastViewport)

	-- M IS BOUND ONLY ONCE THERE IS A MAP TO OPEN. An M that opens an empty panel is worse than an M
	-- that does nothing (design section 5.4).
	ContextActionService:BindAction(
		TOGGLE,
		on(function()
			stats.keyToggles += 1
			MapUi.toggle()
		end),
		false,
		config.TOGGLE_KEY
	)
	MapUi.applyVisibility()
	MapUi.render()
end

function MapUi.start(frames: { miniMap: Frame, fullMap: Frame, legend: Frame?, scrim: Frame? }, collaborators: any)
	if started then
		return
	end
	started = true
	miniFrame = frames.miniMap
	fullFrame = frames.fullMap
	legendFrame = frames.legend
	-- NO `rail` FIELD SINCE TASK 220: `Rail.applyLayout` writes its own position.
	scrimFrame = frames.scrim
	CameraSystem = collaborators and collaborators.Camera
	ReportSystem = collaborators and collaborators.Report
	localUserId = (collaborators and collaborators.userId) or 0

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
