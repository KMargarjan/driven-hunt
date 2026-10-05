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
local Compass = {}

-- Every number here is a layout choice and they are together so a retune is one block.
Compass.CONFIG = {
	-- A THIN STRIP AT THE TOP CENTRE. 360 px wide showing `SPAN_DEG` of the world, so the player
	-- sees a quarter turn either side of where they are looking and the marker arrives before the
	-- animals do.
	WIDTH = 360,
	HEIGHT = 26,
	TOP = 10,
	SPAN_DEG = 120, -- degrees of bearing visible across the whole strip
	Z_INDEX = 6, -- over the feed (1) and the score panel (5), under the report (10)

	-- The strip itself: dark enough to read against sky AND against sunlit grass, which is the one
	-- requirement a HUD element in this world actually has (the drive report learned it the hard
	-- way in task 124 -- 0.25 over an arena is see-through over a forest).
	BACKGROUND = Color3.fromRGB(16, 18, 20),
	TRANSPARENCY = 0.2, -- readable over sunlit grass as well as sky; task 124 learned this the hard way

	-- THE CARDINALS, and the minor ticks between them. 45 degrees apart for the eight letters, 15
	-- for the small marks, which is close enough to read motion and far enough not to be a comb.
	LABEL_SIZE = 13,
	LABEL_COLOR = Color3.fromRGB(255, 255, 255),
	TICK_COLOR = Color3.fromRGB(255, 255, 255),
	TICK_TRANSPARENCY = 0.3,
	MINOR_EVERY_DEG = 15,
	MINOR_HEIGHT = 5,
	MAJOR_HEIGHT = 9,

	-- WHERE THE DRIVE IS. Karen's own colour language elsewhere in this HUD is red for the thing
	-- that matters (the kill marker), so the drive marker is the same family and nothing else on
	-- the strip is coloured at all.
	DRIVE_COLOR = Color3.fromRGB(235, 90, 55),
	DRIVE_WIDTH = 13,
	DRIVE_HEIGHT = 9,
	DRIVE_LABEL = "DRIVE",
	DRIVE_LABEL_SIZE = 11,
	-- A marker that has gone off the end of the strip is PINNED to that end rather than hidden, so
	-- "it is behind me and to the left" still has an answer. It dims when it is pinned, so pinned
	-- and real are not the same picture.
	PINNED_TRANSPARENCY = 0.45,

	-- The centre mark: where the player is actually looking.
	CENTRE_COLOR = Color3.fromRGB(255, 232, 150), -- the same cream the score panel highlights your own row with
}

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
function Compass.offsetPx(heading: number, bearing: number, config): (number, boolean)
	local half = config.WIDTH / 2
	local pixelsPerDeg = config.WIDTH / config.SPAN_DEG
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

local stats = { renders = 0, pinned = 0 }

function Compass.stats()
	return table.clone(stats)
end

function Compass.frame(): Frame?
	return strip
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
		label.Font = Enum.Font.Code
		label.TextSize = config.LABEL_SIZE
		label.TextColor3 = config.LABEL_COLOR
		label.Size = UDim2.fromOffset(28, config.LABEL_SIZE + 2)
		label.Position = UDim2.new(0.5, 0, 0, 1)
		label.Text = point.text
		label.ZIndex = config.Z_INDEX + 2
		label.Visible = false
		-- The same black outline every other label in this HUD wears: a thin Code glyph over a
		-- bright sky is the half of the text that disappears first.
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Parent = label
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
	local markStroke = Instance.new("UIStroke")
	markStroke.Thickness = 1
	markStroke.Color = Color3.new(0, 0, 0)
	markStroke.Parent = mark
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
	label.Font = Enum.Font.Code
	label.TextSize = config.DRIVE_LABEL_SIZE
	label.TextColor3 = config.DRIVE_COLOR
	label.Size = UDim2.fromOffset(60, config.DRIVE_LABEL_SIZE + 2)
	label.Position = UDim2.fromScale(0.5, 1)
	label.Text = config.DRIVE_LABEL
	label.ZIndex = config.Z_INDEX + 4
	label.Visible = false
	local labelStroke = Instance.new("UIStroke")
	labelStroke.Thickness = 1
	labelStroke.Color = Color3.new(0, 0, 0)
	labelStroke.Parent = label
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
	for _, mark in ipairs(marks) do
		local x, onStrip = Compass.offsetPx(headingDeg, mark.deg, config)
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
	local x, onStrip = Compass.offsetPx(headingDeg, bearing, config)
	mark.Visible = true
	label.Visible = true
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
function Compass.setBearing(degrees: number?)
	bearing = degrees
end

function Compass.start(frame: Frame, bearingDeg: number?)
	if started then
		return
	end
	started = true
	build(frame)
	Compass.setBearing(bearingDeg)
	frame.Visible = true
	Compass.render(0)
end

return Compass
