--!strict
-- Hud.Compass: THE ONE WRITER of everything inside the `Compass` frame, and the only thing in this
-- repo that turns a camera heading into a compass bearing.
--
-- Karen, 2026-10-05: *"we need to indicate from what side drive is comming"* and *"compass and
-- showing where drive come direction"*. She is standing at a stand in a wood with no landmarks, and
-- the one thing she cannot work out is which way to face.
--
-- A SCROLLING STRIP, NOT A DIAL, and the reason is what it is for. A dial tells you where north is;
-- a strip tells you **what is in front of you right now**, because the thing at the centre of the
-- strip is the thing the middle of the screen is pointing at. The drive's marker therefore reads as
-- "turn left / turn right / it is in front of you" without the player doing any arithmetic -- which
-- is the whole of her sentence.
--
-- IT IS NOT ITS OWN SCREEN. `Hud.build` creates the `Compass` frame with the rest of the HUD, for
-- the reason the Hud's own header gives: one ScreenGui, built once, so a visibility audit has one
-- place to look. This module fills it and moves what is inside it.
--
-- NO COUNTDOWN AND NO RECTANGLE. Both were described by Karen on 2026-10-05 and both were withdrawn
-- by her the same day (*"remove rectangle for now"*, *"and countdown"*), so neither exists here.
--
-- Design: no new design document -- one strip inside the HUD's own ScreenGui, drawn by the HUD,
-- reading the camera it already reads (`docs/design/camera.md` section 6.2: the Hud reads
-- `Camera.isFirstPerson()` and never writes the camera).
-- THE ONE SOURCE for every colour, face and size on this strip (task 201, the Designer's design
-- system, 2026-10-17). Surface 3 of the inventory: *"`#101214` -> `SLATE`; white -> `PAPER`; drive
-- mark `#EB5A37` -> `BLAZE_HI`; `DRIVE` becomes a `MICRO` spaced label in `BLAZE_HI`; centre line
-- `#FFE896` -> `BRASS_HI`. Corner 11, brass edge @ 0.55, 420 wide instead of 360 so a 120 degree
-- span is not cramped."* The strip is a QUIET SLATE (§3.3): it carries 9-13 px type, so it sits at
-- `Style.SLATE_QUIET_T` and not at the 0.18 a 12 px-and-up slate uses.
local Style = require(script.Parent.Style)

local Compass = {}

-- Every number here is a layout choice and they are together so a retune is one block.
Compass.CONFIG = {
	-- A THIN STRIP AT THE TOP CENTRE, showing `SPAN_DEG` of the world, so the player sees a quarter
	-- turn either side of where they are looking and the marker arrives before the animals do.
	--
	-- 420 ON A DESKTOP AND `screenW - 24` ON A PHONE (the system §4.1 / §4.2). 360 cramped a 120
	-- degree span; 420 gives it room, and the phone's 376 is what keeps the strip clear of the
	-- screen's own 12 px gutter at 400 px. `Compass.widthFor` is the one reader of the break point.
	WIDTH = 420,
	WIDTH_PHONE_MARGIN = 24,
	HEIGHT = 30,
	-- BELOW THE DRIVE BAR, NOT ON TOP OF IT (task 125 round 2, the Reviewer's blocking finding). The
	-- strip was at 10 and covered 360 of the bar's 520 px -- the clock, the boars left and the team
	-- badge -- in every world that HAS a drive. It was not seen because the frames were taken in the
	-- Forest Test, where `MatchBoot` stood aside and there was no bar at all.
	--
	-- 76 -> 108 (task 165), AND 108 IS WHERE IT STAYS (task 201). The top band now reads
	-- objective 8..38, status slate 40..74, tied banner 74..104, this strip 108..138, the minimap at
	-- 140 -- and the strip grew from 26 to 30 px, which is the 2 px it had spare over the map.
	-- `tests/client/hud_clarity.spec.luau` asserts the whole band as rectangles at three viewports,
	-- so a strip that grows into its neighbour fails there rather than in a screenshot.
	TOP = 108,
	SPAN_DEG = 120, -- degrees of bearing visible across the whole strip
	-- Over the feed and the drive bar (1), under the scope's mask (11-13), and under the drive
	-- report and the score board, which share `Report.CONFIG.PANEL_Z_INDEX` (15). Task 141 restacked
	-- the three above it; the compass is also HIDDEN while a sight picture is in, because a mask
	-- cannot cover what is drawn inside its own circle.
	Z_INDEX = 6,

	-- THE SLATE, AND IT IS NO LONGER THIS FILE'S OWN DARK BLUE-GREY (task 201). Every word over the
	-- world sits on `Style.LOOK.SLATE`, and the quiet variant is the one for 9-13 px type. The old
	-- `#101214` at 0.2 was measured by eye in task 124; this one is measured in §2's contrast table.
	BACKGROUND = Style.LOOK.SLATE,
	TRANSPARENCY = Style.SLATE_QUIET_T,

	-- THE CARDINALS, and the minor ticks between them. 45 degrees apart for the eight letters, 15
	-- for the small marks, which is close enough to read motion and far enough not to be a comb.
	LABEL_SIZE = 11,
	LABEL_COLOR = Style.LOOK.PAPER,
	TICK_COLOR = Style.LOOK.PAPER,
	TICK_TRANSPARENCY = 0.3,
	MINOR_EVERY_DEG = 15,
	MINOR_HEIGHT = 5,
	MAJOR_HEIGHT = 9,

	-- WHERE THE DRIVE IS, and nothing else on the strip is coloured at all.
	--
	-- TWO REDS BECAME ONE (§1.1). `#EB5A37` -- this strip's, the chevron's and the map's "go here"
	-- red -- is deleted; that mark is `BLAZE_HI` now, so CLAY is the only red-ish thing on screen
	-- and it always means something went wrong.
	DRIVE_COLOR = Style.LOOK.BLAZE_HI,
	DRIVE_WIDTH = 13,
	DRIVE_HEIGHT = 9,
	DRIVE_LABEL = "DRIVE",
	DRIVE_LABEL_SIZE = 10,
	-- A marker that has gone off the end of the strip is PINNED to that end rather than hidden, so
	-- "it is behind me and to the left" still has an answer. It dims when it is pinned, so pinned
	-- and real are not the same picture.
	PINNED_TRANSPARENCY = 0.45,

	-- The centre mark: where the player is actually looking.
	CENTRE_COLOR = Style.LOOK.BRASS_HI, -- §1.1: the brass highlight, which is also your own map marker
}

-- HOW WIDE THE STRIP IS AT A GIVEN VIEWPORT. PURE AND EXPORTED, for the reason
-- `Objective.lineRect` and `Rail.rect` are: `AbsolutePosition` can only answer for whatever size
-- the Studio window happens to be, and the claim being made is about 400 x 800 as well.
--
-- A PHONE GETS `screenW - 24` AND NEVER MORE THAN THE DESKTOP WIDTH, which is the design's §4.2
-- item 2 -- at 400 px a 420 px strip would hang 10 px off each edge of the screen.
function Compass.widthFor(viewportX: number): number
	local config = Compass.CONFIG
	if Style.isPhone(viewportX) then
		return math.max(120, math.min(config.WIDTH, math.floor(viewportX - config.WIDTH_PHONE_MARGIN)))
	end
	return config.WIDTH
end

-- The eight points. Names, not numbers, because a compass is read in letters.
Compass.POINTS = {
	{ deg = 0, text = "N" },
	{ deg = 45, text = "NE" },
	{ deg = 90, text = "E" },
	{ deg = 135, text = "SE" },
	{ deg = 180, text = "S" },
	{ deg = 225, text = "SW" },
	{ deg = 270, text = "W" },
	{ deg = 315, text = "NW" },
}

-- The heading the strip was last drawn at. Held so that a frame with no trustworthy source keeps
-- the last good answer instead of swinging to a wrong one (task 125 round 3).
local lastHeading = 0

-- ---------------------------------------------------------------- the arithmetic, pure

-- THE CAMERA'S HEADING AS A BEARING. North is +Z and bearings run clockwise through east (+X),
-- which is the convention every compass uses and the one `ForestTest.DRIVE_BEARING_DEG` is written
-- in.
--
-- `atan2(x, z)` AND NOT `atan2(z, x)`: the first gives the angle FROM +Z TOWARD +X, which is
-- "clockwise from north". The other one is 90 degrees out and reads as a compass that is always
-- wrong by one cardinal, which is worse than no compass.
--
-- Pure and exported so a spec can ask what facing down -X reads as with no camera in the world.
function Compass.headingDeg(look: Vector3): number
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-6 then
		return 0
	end
	local degrees = math.deg(math.atan2(flat.X, flat.Z))
	return (degrees + 360) % 360
end

-- WHERE THE VIEW IS POINTING, ASKED OF THE SYSTEM THAT OWNS THE VIEW (task 125 round 3).
--
-- THIS TOOK THREE GOES AND BOTH WRONG ANSWERS ARE WORTH WRITING DOWN, because each looks right.
--
--   1. `workspace.CurrentCamera.CFrame.LookVector`. MEASURED at spawn: 180 degrees away from where
--      the player was looking, and stable. `Camera.Rig` counts FOREIGN WRITES to that property and
--      has warned about one since task 123 -- so the engine's copy is not reliably the view.
--   2. The character's `HumanoidRootPart.CFrame.LookVector`. MEASURED by the Director with real
--      mouse input: forty moves of dx = 25 turned the rendered view right round, and the body's look
--      stayed at (0, 1) and the strip never moved a pixel. **In first person the camera system turns
--      the VIEW without turning the BODY**, so a compass driven by the body is nailed to the spot.
--
-- THE OWNER OF THE VIEW PUBLISHES THE VIEW. `Camera.viewCFrame()` is the CFrame `Rig.apply` last
-- wrote -- what this system INTENDS, rather than what the property currently holds -- which is the
-- only source that is both what is rendered and nobody else's to change. One owner, one reader; the
-- Hud still never writes the camera.
--
-- `camera` is the LAST resort and only for a world with no camera system at all: a plain
-- `Camera` instance, used as it comes.
function Compass.headingFrom(cameraSystem: any, camera: Camera?): number
	-- THE CAMERA SYSTEM CONVERTS ITS OWN CONVENTION (task 125 round 4). Reading its CFrame and
	-- applying `headingDeg` here is what made the strip 180 degrees out for three rounds: the camera's
	-- yaw zero looks down -Z and a compass bearing's looks down +Z, and that is the camera's fact to
	-- know, not the Hud's. `Camera.viewHeadingDeg` is already a world bearing.
	if cameraSystem ~= nil and type(cameraSystem.viewHeadingDeg) == "function" then
		local bearing = cameraSystem.viewHeadingDeg()
		if bearing ~= nil then
			return bearing
		end
	end
	-- `CurrentCamera` IS NEVER PASSED IN BY THE HUD, and that is the whole of the Director's rule
	-- for this round: "if CurrentCamera.CFrame is not what is rendered, do not use it". Handing it in
	-- as a fallback is how the bug came BACK on the first attempt: before the camera system has
	-- applied its first frame `viewCFrame()` is nil, the fallback ran, and the strip read S at a view
	-- that was not pointing south. With nothing trustworthy to read, the strip keeps the heading it
	-- last had -- a compass that lags by a few frames at spawn is not a compass that lies.
	--
	-- `camera` exists for a caller that has its OWN camera and means it: a spec with a plain
	-- `Instance.new("Camera")`, or a world with no camera system at all.
	if camera ~= nil then
		return Compass.headingDeg(camera.CFrame.LookVector)
	end
	return lastHeading
end

-- What the strip is actually drawn at, published so a reader does not have to guess which source
-- won. It is also an attribute on the frame (see `render`), because a sandboxed `require` from the
-- harness answers a COPY with empty state and cannot see this.
function Compass.lastHeadingDeg(): number
	return lastHeading
end

-- THE SHORTEST WAY ROUND, in degrees, from `heading` to `bearing`: negative is to the left.
-- Without this a marker 10 degrees to the left of north reads as 350 degrees to the RIGHT and flies
-- off the end of the strip every time the player crosses north.
function Compass.deltaDeg(heading: number, bearing: number): number
	local delta = (bearing - heading + 540) % 360 - 180
	return delta
end

-- WHERE A BEARING SITS ON THE STRIP, in pixels from its centre, and whether it is really there.
-- Returns (x, onStrip). A caller that gets `false` has a bearing behind the player: the x is already
-- clamped to the nearer end, so it can pin the marker rather than hide it.
-- `widthPx` IS THE WIDTH THE STRIP IS ACTUALLY DRAWN AT, and it is a parameter rather than
-- `config.WIDTH` because since task 201 those are two different numbers on a phone (`widthFor`:
-- 420 on a desktop, `screenW - 24` below the break point). Round 1's blocking finding is what this
-- is: the frame was sized from `widthFor` and the arithmetic still divided by 420, so at 400 px the
-- strip showed ~107 degrees while claiming `SPAN_DEG` 120, AND a bearing more than ~54 degrees off
-- the heading was clamped to +-210 px inside a 376 px `ClipsDescendants` frame -- which is the
-- marker VANISHING rather than pinning, against `PINNED_TRANSPARENCY`'s own stated contract and
-- against Karen's *"we need to indicate from what side drive is comming"*.
--
-- It defaults to `config.WIDTH` so every existing caller keeps the desktop answer.
function Compass.offsetPx(heading: number, bearing: number, config, widthPx: number?): (number, boolean)
	local width = widthPx or config.WIDTH
	local half = width / 2
	local pixelsPerDeg = width / config.SPAN_DEG
	local x = Compass.deltaDeg(heading, bearing) * pixelsPerDeg
	if x < -half then
		return -half, false
	elseif x > half then
		return half, false
	end
	return x, true
end

-- ---------------------------------------------------------------- the picture, built once

local strip: Frame? = nil
local marks: { { deg: number, node: GuiObject } } = {}
local driveMark: Frame? = nil
local driveLabel: TextLabel? = nil
local started = false
local bearing: number? = nil
-- WHAT THE MARKER SAYS (task 153 round 2). It is held here rather than written straight to the
-- label because `setBearing` may be called BEFORE `start` has built one -- the Hud sets the bearing
-- from `whenReady`, which lands first in the common case -- and `render` applies it.
local markerText: string = Compass.CONFIG.DRIVE_LABEL

local stats = { renders = 0, pinned = 0 }

function Compass.stats()
	return table.clone(stats)
end

function Compass.frame(): Frame?
	return strip
end

-- HOW WIDE THE STRIP IS RIGHT NOW, read off the frame itself. `Hud.build` and
-- `Hud.applyViewportLayout` are the only writers of that `Size` and both write it in OFFSETS from
-- `Compass.widthFor`, so this is the drawn width and not a layout result that might still be zero.
function Compass.drawnWidth(): number
	local frame = strip
	if frame ~= nil and frame.Size.X.Offset > 0 then
		return frame.Size.X.Offset
	end
	return Compass.CONFIG.WIDTH
end

function Compass.bearingDeg(): number?
	return bearing
end

-- What is on the strip right now, for a spec: each mark's text (or "|" for a tick) and its x.
function Compass.markPositions(): { { text: string, x: number } }
	local out = {}
	for _, mark in ipairs(marks) do
		if mark.node.Visible then
			local text = if mark.node:IsA("TextLabel") then mark.node.Text else "|"
			table.insert(out, { text = text, x = mark.node.Position.X.Offset })
		end
	end
	return out
end

function Compass.driveMarkerX(): number?
	if driveMark == nil or not driveMark.Visible then
		return nil
	end
	return driveMark.Position.X.Offset
end

-- ...AND WHAT IT SAYS, for a spec: the word actually on the screen, or nil when there is no marker.
function Compass.driveMarkerLabel(): string?
	if driveLabel == nil or not driveLabel.Visible then
		return nil
	end
	return driveLabel.Text
end

local function build(frame: Frame)
	strip = frame
	local config = Compass.CONFIG
	table.clear(marks)

	-- The minor ticks first, so a cardinal letter is never drawn under one.
	for degrees = 0, 359, config.MINOR_EVERY_DEG do
		if degrees % 45 ~= 0 then
			local tick = Instance.new("Frame")
			tick.Name = string.format("Tick%d", degrees)
			tick.AnchorPoint = Vector2.new(0.5, 1)
			tick.Size = UDim2.fromOffset(1, config.MINOR_HEIGHT)
			tick.Position = UDim2.new(0.5, 0, 1, -2)
			tick.BackgroundColor3 = config.TICK_COLOR
			tick.BackgroundTransparency = config.TICK_TRANSPARENCY
			tick.BorderSizePixel = 0
			tick.ZIndex = config.Z_INDEX + 1
			tick.Visible = false
			tick.Parent = frame
			table.insert(marks, { deg = degrees, node = tick })
		end
	end

	for _, point in ipairs(Compass.POINTS) do
		local tick = Instance.new("Frame")
		tick.Name = "Major" .. point.text
		tick.AnchorPoint = Vector2.new(0.5, 1)
		tick.Size = UDim2.fromOffset(1, config.MAJOR_HEIGHT)
		tick.Position = UDim2.new(0.5, 0, 1, -2)
		tick.BackgroundColor3 = config.TICK_COLOR
		tick.BackgroundTransparency = 0.1
		tick.BorderSizePixel = 0
		tick.ZIndex = config.Z_INDEX + 1
		tick.Visible = false
		tick.Parent = frame
		table.insert(marks, { deg = point.deg, node = tick })

		local label = Instance.new("TextLabel")
		label.Name = point.text
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		-- BUILDERSANS SEMIBOLD AND NOT `Enum.Font.Code` (task 201, the system §1.2): a compass point
		-- is a LABEL, and every label in this game is BuilderSans. Uppercase at 11 px, so it is
		-- letter-spaced (§1.2: `spaced()` applies at 11 px and below and nowhere above).
		label.FontFace = Style.FONT.SANS_SEMI
		label.TextScaled = false
		label.TextWrapped = false
		label.TextSize = config.LABEL_SIZE
		label.TextColor3 = config.LABEL_COLOR
		label.Size = UDim2.fromOffset(34, config.LABEL_SIZE + 3)
		label.Position = UDim2.new(0.5, 0, 0, 2)
		label.Text = Style.spaced(point.text)
		label.ZIndex = config.Z_INDEX + 2
		label.Visible = false
		-- AND NO BLACK OUTLINE (§2). The strip IS the backing panel, which is what an outline was
		-- standing in for: *"an outline thickens every letter, halves the apparent size of 11 px type,
		-- and still fails over a bright sky because the outline itself is only 1 px"*.
		label.Parent = frame
		table.insert(marks, { deg = point.deg, node = label })
	end

	-- WHERE THE PLAYER IS LOOKING: one hairline down the middle, so the strip reads as a sight and
	-- not as a ruler.
	local centre = Instance.new("Frame")
	centre.Name = "Centre"
	centre.AnchorPoint = Vector2.new(0.5, 0.5)
	centre.Size = UDim2.fromOffset(1, config.HEIGHT)
	centre.Position = UDim2.fromScale(0.5, 0.5)
	centre.BackgroundColor3 = config.CENTRE_COLOR
	centre.BackgroundTransparency = 0.25
	centre.BorderSizePixel = 0
	centre.ZIndex = config.Z_INDEX + 3
	centre.Parent = frame

	-- THE DRIVE. A chevron pointing DOWN at the strip -- it marks a place on the compass, so it
	-- points at it -- drawn as a rotated square, because a triangle in Roblox GUI is an image and
	-- this needs no asset.
	local mark = Instance.new("Frame")
	mark.Name = "DriveMark"
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Size = UDim2.fromOffset(config.DRIVE_WIDTH, config.DRIVE_HEIGHT)
	mark.Position = UDim2.fromScale(0.5, 0.5)
	mark.BackgroundColor3 = config.DRIVE_COLOR
	mark.BorderSizePixel = 0
	mark.Rotation = 45
	mark.ZIndex = config.Z_INDEX + 4
	mark.Visible = false
	-- NO BLACK OUTLINE (§2): the chevron sits on the strip's own slate, which is what carries it.
	mark.Parent = frame
	driveMark = mark

	local label = Instance.new("TextLabel")
	label.Name = "DriveLabel"
	-- INSIDE THE STRIP, NOT UNDER IT, AND THE FIRST FRAME IS WHY: the strip sets
	-- `ClipsDescendants` so a mark scrolling off the end cannot spill onto the sky, and this label
	-- was positioned at `1, 2` -- two pixels BELOW the bottom edge -- so the word "DRIVE" was
	-- clipped away on every frame and the marker was a bare chevron.
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	-- A `MICRO` SPACED LABEL IN `BLAZE_HI` (§5 surface 3). BuilderSans Bold, uppercase, and
	-- letter-spaced because it is 10 px -- the chevron and its word are one mark, so they are one
	-- colour, and that colour is the game's single "go here" orange.
	label.FontFace = Style.FONT.SANS_BOLD
	label.TextScaled = false
	label.TextWrapped = false
	label.TextSize = config.DRIVE_LABEL_SIZE
	label.TextColor3 = config.DRIVE_COLOR
	label.Size = UDim2.fromOffset(90, config.DRIVE_LABEL_SIZE + 3)
	label.Position = UDim2.fromScale(0.5, 1)
	label.Text = Style.spaced(config.DRIVE_LABEL)
	label.ZIndex = config.Z_INDEX + 4
	label.Visible = false
	-- No outline, for §2's reason: the strip is the backing panel.
	label.Parent = frame
	driveLabel = label
end

-- ---------------------------------------------------------------- drawing

-- PUBLIC, for the reason `Hud.renderScore` and `ReportPanel.render` are public: a spec cannot turn
-- a real camera, so the one way to prove the strip really moves is to hand it a heading.
function Compass.render(headingDeg: number)
	if strip == nil then
		return
	end
	local config = Compass.CONFIG
	stats.renders += 1
	lastHeading = headingDeg
	-- ON THE FRAME ITSELF, because MCP's `require` answers a sandboxed COPY with empty state, so the
	-- only honest way to read what the LIVE compass used is a property of a real Instance.
	strip:SetAttribute("Heading", headingDeg)
	-- THE DRAWN WIDTH, ONCE, FOR EVERYTHING ON THE STRIP. The ticks, the letters and the drive
	-- marker all have to agree with the frame they are inside, or the span is a lie and a pinned
	-- marker is clipped away (round 1, finding 1).
	local width = Compass.drawnWidth()
	for _, mark in ipairs(marks) do
		local x, onStrip = Compass.offsetPx(headingDeg, mark.deg, config, width)
		mark.node.Visible = onStrip
		if onStrip then
			local current = mark.node.Position
			mark.node.Position = UDim2.new(0.5, math.round(x), current.Y.Scale, current.Y.Offset)
		end
	end

	local mark, label = driveMark, driveLabel
	if mark == nil or label == nil then
		return
	end
	if bearing == nil then
		-- NO DRIVE DIRECTION, NO MARKER, and the compass still works: a world that has not said
		-- where its drive comes from gets a plain compass rather than a marker pointing at zero,
		-- which would be a lie in the shape of a fact.
		mark.Visible = false
		label.Visible = false
		return
	end
	local x, onStrip = Compass.offsetPx(headingDeg, bearing, config, width)
	mark.Visible = true
	label.Visible = true
	-- THE WORD FOLLOWS THE BEARING (task 153 round 2). Written only when it changes: this runs once
	-- a frame, and a `Text` write fires the property's own signals whether or not the string differs.
	-- SPACED ON THE WAY TO THE SCREEN AND NOT IN THE DATA (§1.2): `markerText` is the word the
	-- world said ("ROAD", "DRIVE"), and `Compass.driveMarkerLabel` answers what is DRAWN, so the
	-- spec that compares the two compares like with like.
	local drawn = Style.spaced(markerText)
	if label.Text ~= drawn then
		label.Text = drawn
	end
	-- The chevron rides the TOP half of the strip and the word sits under it, both inside the frame.
	mark.Position = UDim2.new(0.5, math.round(x), 0, config.DRIVE_HEIGHT)
	label.Position = UDim2.new(0.5, math.round(x), 1, 0)
	local transparency = if onStrip then 0 else config.PINNED_TRANSPARENCY
	mark.BackgroundTransparency = transparency
	label.TextTransparency = transparency
	if not onStrip then
		stats.pinned += 1
	end
end

-- The world says where its drive comes from; this draws it. nil means "not stated", and then there
-- is no marker at all.
--
-- ...AND IT CARRIES ITS OWN WORD (task 153 round 2, the Reviewer's blocking finding). The marker is
-- a chevron AND a label, and the label was written once at build time: so when a beater's marker was
-- turned round to point at the road, the word under it still read DRIVE -- a compass telling her the
-- drive is south while every animal she is pushing is north of her. One call sets both, because they
-- are one fact; `nil` keeps `CONFIG.DRIVE_LABEL`, which is what every hunter and every other world
-- gets.
function Compass.setBearing(degrees: number?, label: string?)
	bearing = degrees
	markerText = label or Compass.CONFIG.DRIVE_LABEL
end

function Compass.start(frame: Frame, bearingDeg: number?, label: string?)
	if started then
		return
	end
	started = true
	build(frame)
	Compass.setBearing(bearingDeg, label)
	frame.Visible = true
	Compass.render(0)
end

return Compass
