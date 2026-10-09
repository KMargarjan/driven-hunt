--!strict
-- PlayerScripts.Hud: THE OWNER OF ANYTHING DRAWN (CLAUDE.md rule 3, GAME_DESIGN.md "UI / anything
-- drawn", which this system fills). It is the only writer of PlayerGui.HunterHud and everything in
-- it: the crosshair, one barrel/ammo readout, the hit marker, the drive bar and the event feed
-- (Milestone 1.7a), and the SCORE SCREEN and the TIED banner (1.7b).
--
-- renderScore and renderTied are public for one reason, stated so nobody widens it: a drive is 600
-- seconds long, so no harness run reaches the Scoring phase, and a spec that cannot hand this module
-- a Scoring snapshot cannot check that the panel really is on screen -- which is the one check
-- docs/PROJECT_CONTEXT.md's "a visibility audit certified a blank screen twice" demands.
--
-- THE HIT MARKER is Karen's playtest answered ("I cannot tell whether I hit"): a short white tick on
-- a confirmed hit, a longer red one on a kill. The server tells the shooter alone, one way, over
-- Shotgun.Remotes.HitMarker; the weapon owns that remote and fires it when its own cast confirmed a
-- damageable target, and the BOAR's runtime -- through BoarBoot -- is what turns a hit into a kill.
-- Nothing about it is decided here: this module only draws.
--
-- THE DEPENDENCY DIRECTION IS ONE-WAY AND IT IS THE POINT. The Hud READS PlayerScripts.Weapon and
-- is never called by it; the weapon has no reference to the Hud and does not know it exists. The
-- previous project died partly of "one predicate answered two unrelated questions, so mounting hid
-- both the crosshair and the weapon" (docs/PROJECT_CONTEXT.md). Here the crosshair has exactly one
-- writer and that writer's only input is published state.
--   ScreenGui   https://create.roblox.com/docs/reference/engine/classes/ScreenGui
--   GuiObject   https://create.roblox.com/docs/reference/engine/classes/GuiObject
--   UIStroke    https://create.roblox.com/docs/reference/engine/classes/UIStroke
--
-- Design: docs/design/shotgun.md (sections 3.4, 5.6), docs/design/camera.md (section 6.2),
--         docs/design/drive.md (section 9.3)
-- Note:   docs/research/2026-09-24-shotgun.md
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))
-- Which world this is, so the compass knows whether anybody has said where the drive comes from
-- (task 125). Read, never written: `Map.EXPECTED_WORLD` is a commit, not a flag.
local Map = require(ReplicatedStorage:WaitForChild("Map"))
local Report = require(ReplicatedStorage:WaitForChild("Report"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

-- The Hud's own 2-D feedback sounds have one writer, and this is it (task 124).
local Sound = require(script.Sound)
-- THE REPORT PANEL (task 124 stage B). It is a sibling module and not a second ScreenGui: the Hud
-- builds the frame with everything else here, and `ReportPanel` is the one writer of what goes inside
-- it. One ScreenGui, built once, so a visibility audit has one place to look.
local ReportPanel = require(script.ReportPanel)
-- ...and the compass strip (task 125). Same shape as the report panel: the Hud builds the frame
-- with everything else, and `Compass` is the one writer of what goes inside it.
local Compass = require(script.Compass)

local Hud = {}

-- WHERE THE SIGHT PICTURE SITS IN THE STACK (task 141). The mask blacks out the screen, so it must
-- be over everything the Hud draws on top of the world -- and the compass reaches `Z_INDEX + 4`, so
-- 11 rather than the 7 the first version used. MEASURED: at 7 the compass strip, the DRIVE marker
-- and both bearing labels were drawn INSIDE the eyepiece, floating in the glass.
--
-- The duplex is over the mask, because a reticle is etched on the glass and not behind it. The
-- drive report's panel is over BOTH (`Report.CONFIG.PANEL_Z_INDEX`): the player opened that.
local SCOPE_Z = 11
local RETICLE_Z = SCOPE_Z + 2

local gui: ScreenGui? = nil
local crosshair: Frame? = nil
local readout: TextLabel? = nil
local hitMark: Frame? = nil
local hitKind: string? = nil
local hitToken = 0 -- so a second hit during the first mark's life cannot hide it early
local markerConnection: RBXScriptConnection? = nil
-- WHETHER THE DRIVE BAR IS ACTUALLY WIRED TO THE MATCH (task 134). Not a cache of what is drawn --
-- `renderDrive` is that -- but the answer to "did the Hud ever find the system it draws from", which
-- was silently NO for a whole session whenever `PlayerScripts.Match` lost a replication race.
local matchConnected = false
-- ...AND THE SYSTEM ITSELF, kept because two things need it at two different times: the connections
-- in `Hud.useMatch`, and the report panel, which is handed its collaborators further down `start`.
-- When `Match` wins its race -- the common case -- this is set before the panel is built and the
-- panel gets it the way it always did; when it loses, `useMatch` hands it over afterwards.
local matchSystem: any = nil
local driveBar: TextLabel? = nil
local feedFrame: Frame? = nil -- kept for the client spec's ancestor walk
local feedLines: { TextLabel } = {}
local feedEntries: { { text: string, at: number } } = {}
local scorePanel: Frame? = nil
local reportFrame: Frame? = nil
local compassFrame: Frame? = nil
-- Did the scope's own mask hide the compass strip? See `Hud.renderScope`.
local compassHiddenByScope = false
local scoreTitle: TextLabel? = nil
local scoreLines: { TextLabel } = {}
local scoreFooter: TextLabel? = nil
local tiedBanner: TextLabel? = nil
local started = false

function Hud.gui(): ScreenGui?
	return gui
end

function Hud.isCrosshairVisible(): boolean
	return crosshair ~= nil and crosshair.Visible
end

function Hud.readoutText(): string
	return if readout then readout.Text else ""
end

function Hud.driveBarText(): string
	return if driveBar then driveBar.Text else ""
end

function Hud.isDriveBarVisible(): boolean
	return driveBar ~= nil and driveBar.Visible
end

function Hud.feed(): Frame?
	return feedFrame
end

function Hud.feedText(): { string }
	local out = {}
	for _, line in ipairs(feedLines) do
		if line.Visible and line.Text ~= "" then
			table.insert(out, line.Text)
		end
	end
	return out
end

function Hud.scorePanel(): Frame?
	return scorePanel
end

-- The compass strip, and the module that fills it (task 125).
function Hud.compass(): Frame?
	return compassFrame
end

Hud.Compass = Compass

-- The report's frame, so a spec can read its visibility without reaching through PlayerGui by name.
function Hud.reportPanel(): Frame?
	return reportFrame
end

-- The panel module itself, for the same reason: the Hud starts it, so the Hud is where it is found.
Hud.Report = ReportPanel

function Hud.isScorePanelVisible(): boolean
	return scorePanel ~= nil and scorePanel.Visible
end

function Hud.scoreTitleText(): string
	return if scoreTitle then scoreTitle.Text else ""
end

function Hud.scoreFooterText(): string
	return if scoreFooter then scoreFooter.Text else ""
end

-- Only the lines that are actually showing something, in board order.
function Hud.scoreRowText(): { string }
	local out = {}
	for _, line in ipairs(scoreLines) do
		if line.Visible and line.Text ~= "" then
			table.insert(out, line.Text)
		end
	end
	return out
end

function Hud.tiedBanner(): TextLabel?
	return tiedBanner
end

function Hud.isTiedBannerVisible(): boolean
	return tiedBanner ~= nil and tiedBanner.Visible
end

function Hud.tiedBannerText(): string
	return if tiedBanner then tiedBanner.Text else ""
end

function Hud.isHitMarkVisible(): boolean
	return hitMark ~= nil and hitMark.Visible
end

-- "hit", "kill", or nil when nothing is showing.
function Hud.hitMarkKind(): string?
	return hitKind
end

-- Whether this Hud is actually listening to the server's one-way marker remote.
function Hud.hitMarkerConnected(): boolean
	return markerConnection ~= nil and markerConnection.Connected
end

-- ...AND WHETHER IT IS LISTENING TO THE DRIVE (task 134), which is the same question for the bar, the
-- clock and the feed. Read by `tests/client/hud_boot.spec.luau`, and the one honest answer to "is
-- there going to be a drive bar this session".
function Hud.driveConnected(): boolean
	return matchConnected
end

local function arm(parent: Frame, name: string, size: UDim2, anchor: Vector2, position: UDim2, color: Color3)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.AnchorPoint = anchor
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = frame
	frame.Parent = parent
	return frame
end

local function build(): ScreenGui
	local config = Shotgun.CONFIG
	local arms = config.CROSSHAIR_ARM_PX
	local gap = config.CROSSHAIR_GAP_PX
	local thick = config.CROSSHAIR_THICK_PX

	local screen = Instance.new("ScreenGui")
	screen.Name = "HunterHud"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 1

	local container = Instance.new("Frame")
	container.Name = "Crosshair"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromOffset(2 * (gap + arms), 2 * (gap + arms))
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.fromScale(0.5, 0.5)
	container.Visible = false
	container.Parent = screen

	arm(
		container,
		"Top",
		UDim2.fromOffset(thick, arms),
		Vector2.new(0.5, 1),
		UDim2.new(0.5, 0, 0.5, -gap),
		config.CROSSHAIR_COLOR
	)
	arm(
		container,
		"Bottom",
		UDim2.fromOffset(thick, arms),
		Vector2.new(0.5, 0),
		UDim2.new(0.5, 0, 0.5, gap),
		config.CROSSHAIR_COLOR
	)
	arm(
		container,
		"Left",
		UDim2.fromOffset(arms, thick),
		Vector2.new(1, 0.5),
		UDim2.new(0.5, -gap, 0.5, 0),
		config.CROSSHAIR_COLOR
	)
	arm(
		container,
		"Right",
		UDim2.fromOffset(arms, thick),
		Vector2.new(0, 0.5),
		UDim2.new(0.5, gap, 0.5, 0),
		config.CROSSHAIR_COLOR
	)

	-- THE SCOPE'S RETICLE (task 140): a duplex -- a ring you look through, a thin cross and four
	-- thick outer posts -- drawn from UI primitives with NO upload, exactly as the drive report's
	-- silhouette is. A SIBLING of the crosshair and of the hit marker, for the reason the hit marker
	-- is one: three marks, three questions, and no predicate that answers two of them.
	--
	-- EVERY SIZE IS IN DEGREES AND IS CONVERTED ONCE (`Hud.reticleDegToPx`). Roblox's field of view
	-- is VERTICAL, so `px = deg / fov * viewportY` is exact -- which is what makes one duplex true
	-- at any screen size AND at any magnification: change the scope's `aimFovDeg` and every element
	-- of the sight picture grows by exactly the magnification, as a real scope's does.
	-- THE SIGHT PICTURE (task 141): black everywhere except a round eyepiece, with the magnified
	-- world inside it. A SIBLING of the reticle and of the crosshair, for the reason they are
	-- siblings of each other -- a mark and a mask are two things, and no predicate answers for both.
	--
	-- THE MASK IS A `UIStroke` ON A CIRCLE, which is the one way to paint "everything except a
	-- circle" out of UI primitives with no upload: a `UICorner` of 0.5 scale makes the frame a
	-- circle, and a stroke is drawn OUTSIDE that border, so a stroke thicker than the screen's own
	-- diagonal fills the whole screen and leaves the circle untouched. The alternative needed an
	-- uploaded mask image, which needs Karen's OK and a moderation wait for a shape four lines of
	-- UI already make. MEASURED on screen -- see the frames in the request.
	local overlay = Instance.new("Frame")
	overlay.Name = "ScopeOverlay"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.AnchorPoint = Vector2.new(0.5, 0.5)
	overlay.Position = UDim2.fromScale(0.5, 0.5)
	overlay.ZIndex = SCOPE_Z
	overlay.Visible = false
	overlay.Parent = screen

	local mask = Instance.new("Frame")
	mask.Name = "Mask"
	mask.BackgroundTransparency = 1
	mask.AnchorPoint = Vector2.new(0.5, 0.5)
	mask.Position = UDim2.fromScale(0.5, 0.5)
	mask.Size = UDim2.fromOffset(2, 2)
	mask.ZIndex = SCOPE_Z
	mask.Parent = overlay
	local maskRound = Instance.new("UICorner")
	maskRound.CornerRadius = UDim.new(0.5, 0)
	maskRound.Parent = mask
	local maskEdge = Instance.new("UIStroke")
	maskEdge.Name = "Edge"
	maskEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	maskEdge.Thickness = 1
	maskEdge.Parent = mask

	-- The ocular lens's own rim, drawn INSIDE the circle: a stroke goes outward, so this frame is
	-- smaller than the mask by exactly its own thickness and its stroke lands against the mask's
	-- edge. Without it the sight picture ends on a hard mathematical line, which no glass does.
	local rim = Instance.new("Frame")
	rim.Name = "Rim"
	rim.BackgroundTransparency = 1
	rim.AnchorPoint = Vector2.new(0.5, 0.5)
	rim.Position = UDim2.fromScale(0.5, 0.5)
	rim.Size = UDim2.fromOffset(2, 2)
	rim.ZIndex = SCOPE_Z + 1
	rim.Parent = overlay
	local rimRound = Instance.new("UICorner")
	rimRound.CornerRadius = UDim.new(0.5, 0)
	rimRound.Parent = rim
	local rimEdge = Instance.new("UIStroke")
	rimEdge.Name = "Edge"
	rimEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rimEdge.Thickness = 1
	rimEdge.Parent = rim

	local reticle = Instance.new("Frame")
	reticle.Name = "Reticle"
	reticle.BackgroundTransparency = 1
	reticle.Size = UDim2.fromScale(1, 1)
	reticle.AnchorPoint = Vector2.new(0.5, 0.5)
	reticle.Position = UDim2.fromScale(0.5, 0.5)
	-- ON TOP OF THE MASK, which is the whole point of a reticle: it is etched on the glass.
	reticle.ZIndex = RETICLE_Z
	reticle.Visible = false
	reticle.Parent = screen

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.BackgroundTransparency = 1
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(2, 2)
	ring.Parent = reticle
	ring.ZIndex = RETICLE_Z
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = ring
	local edge = Instance.new("UIStroke")
	edge.Name = "Edge"
	edge.Thickness = 1
	edge.Parent = ring

	for _, piece in ipairs({
		{ name = "CrossTop", vertical = true, sign = -1, post = false },
		{ name = "CrossBottom", vertical = true, sign = 1, post = false },
		{ name = "CrossLeft", vertical = false, sign = -1, post = false },
		{ name = "CrossRight", vertical = false, sign = 1, post = false },
		{ name = "PostTop", vertical = true, sign = -1, post = true },
		{ name = "PostBottom", vertical = true, sign = 1, post = true },
		{ name = "PostLeft", vertical = false, sign = -1, post = true },
		{ name = "PostRight", vertical = false, sign = 1, post = true },
	}) do
		local bar = Instance.new("Frame")
		bar.Name = piece.name
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromOffset(1, 1)
		bar.ZIndex = RETICLE_Z
		bar.Parent = reticle
	end

	-- The hit marker: four diagonal arms around the centre, hidden until something lands. It is a
	-- sibling of the crosshair and not a child, because it must still show in ADS, where the
	-- crosshair is deliberately hidden (camera design section 6.2).
	local mark = Instance.new("Frame")
	mark.Name = "HitMark"
	mark.BackgroundTransparency = 1
	mark.Size = UDim2.fromOffset(
		2 * (config.HIT_MARK_GAP_PX + config.HIT_MARK_ARM_PX),
		2 * (config.HIT_MARK_GAP_PX + config.HIT_MARK_ARM_PX)
	)
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.fromScale(0.5, 0.5)
	mark.Visible = false
	mark.Parent = screen

	local reach = config.HIT_MARK_GAP_PX + config.HIT_MARK_ARM_PX / 2
	for _, corner in ipairs({
		{ name = "TopLeft", x = -reach, y = -reach, rotation = 45 },
		{ name = "TopRight", x = reach, y = -reach, rotation = -45 },
		{ name = "BottomLeft", x = -reach, y = reach, rotation = -45 },
		{ name = "BottomRight", x = reach, y = reach, rotation = 45 },
	}) do
		local diagonal = arm(
			mark,
			corner.name,
			UDim2.fromOffset(config.HIT_MARK_THICK_PX, config.HIT_MARK_ARM_PX),
			Vector2.new(0.5, 0.5),
			UDim2.new(0.5, corner.x, 0.5, corner.y),
			config.HIT_MARK_COLOR
		)
		diagonal.Rotation = corner.rotation
	end

	-- The drive bar, top centre: MM:SS, the phase while it is not Running, the team badge and how
	-- many boars are left. One line, because a grey box needs the numbers and not a dashboard.
	local bar = Instance.new("TextLabel")
	bar.Name = "DriveBar"
	bar.BackgroundTransparency = 1
	bar.Font = Enum.Font.Code
	bar.TextSize = Drive.CONFIG.BAR_TEXT_SIZE
	bar.TextColor3 = Drive.CONFIG.TEXT_COLOR
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, Drive.CONFIG.BAR_TOP_OFFSET)
	bar.Size = UDim2.fromOffset(520, 26)
	bar.Text = ""
	bar.Visible = false
	local barStroke = Instance.new("UIStroke")
	barStroke.Thickness = 1
	barStroke.Color = Color3.new(0, 0, 0)
	barStroke.Parent = bar
	bar.Parent = screen

	-- The event feed, bottom left: the last few things that happened, each fading on its own.
	local feed = Instance.new("Frame")
	feed.Name = "Feed"
	feed.BackgroundTransparency = 1
	feed.AnchorPoint = Vector2.new(0, 1)
	feed.Position = UDim2.new(0, Drive.CONFIG.FEED_LEFT_OFFSET, 1, -Drive.CONFIG.FEED_BOTTOM_OFFSET)
	feed.Size = UDim2.fromOffset(420, Drive.CONFIG.FEED_LINES * 20)
	feed.Parent = screen

	table.clear(feedLines)
	for index = 1, Drive.CONFIG.FEED_LINES do
		local line = Instance.new("TextLabel")
		line.Name = string.format("Line%d", index)
		line.BackgroundTransparency = 1
		line.Font = Enum.Font.Code
		line.TextSize = Drive.CONFIG.FEED_TEXT_SIZE
		line.TextColor3 = Drive.CONFIG.TEXT_COLOR
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.Position = UDim2.fromOffset(0, (index - 1) * 20)
		line.Size = UDim2.fromOffset(420, 20)
		line.Text = ""
		line.Visible = false
		local lineStroke = Instance.new("UIStroke")
		lineStroke.Thickness = 1
		lineStroke.Color = Color3.new(0, 0, 0)
		lineStroke.Parent = line
		line.Parent = feed
		table.insert(feedLines, line)
	end

	-- The score screen: a centred panel, hidden except in the Scoring phase. Built once, like
	-- everything else here, and shown by renderScore -- the ONE writer of its visibility.
	local rows = Drive.CONFIG.SCORE_ROWS_MAX
	local rowHeight = Drive.CONFIG.SCORE_ROW_HEIGHT
	local panel = Instance.new("Frame")
	panel.Name = "ScorePanel"
	panel.BackgroundColor3 = Drive.CONFIG.SCORE_PANEL_COLOR
	panel.BackgroundTransparency = Drive.CONFIG.SCORE_PANEL_TRANSPARENCY
	panel.BorderSizePixel = 0
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(Drive.CONFIG.SCORE_PANEL_WIDTH, 60 + rows * rowHeight + 30)
	panel.ZIndex = 5 -- over the feed and the bar, because it is the thing to read
	panel.Visible = false
	panel.Parent = screen

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Code
	title.TextSize = Drive.CONFIG.SCORE_TITLE_SIZE
	title.TextColor3 = Drive.CONFIG.TEXT_COLOR
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.fromOffset(Drive.CONFIG.SCORE_PANEL_WIDTH - 32, 28)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = ""
	title.Parent = panel

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.Code
	header.TextSize = Drive.CONFIG.SCORE_TEXT_SIZE
	header.TextColor3 = Drive.CONFIG.TEXT_COLOR
	header.TextTransparency = 0.4
	header.Position = UDim2.fromOffset(16, 40)
	header.Size = UDim2.fromOffset(Drive.CONFIG.SCORE_PANEL_WIDTH - 32, rowHeight)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = "#  NAME             TEAM     KILLS  POINTS"
	header.Parent = panel

	table.clear(scoreLines)
	for index = 1, rows do
		local line = Instance.new("TextLabel")
		line.Name = string.format("Row%d", index)
		line.BackgroundTransparency = 1
		line.Font = Enum.Font.Code
		line.TextSize = Drive.CONFIG.SCORE_TEXT_SIZE
		line.TextColor3 = Drive.CONFIG.TEXT_COLOR
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.Position = UDim2.fromOffset(16, 60 + (index - 1) * rowHeight)
		line.Size = UDim2.fromOffset(Drive.CONFIG.SCORE_PANEL_WIDTH - 32, rowHeight)
		line.Text = ""
		line.Visible = false
		line.Parent = panel
		table.insert(scoreLines, line)
	end

	local footer = Instance.new("TextLabel")
	footer.Name = "Footer"
	footer.BackgroundTransparency = 1
	footer.Font = Enum.Font.Code
	footer.TextSize = Drive.CONFIG.SCORE_TEXT_SIZE
	footer.TextColor3 = Drive.CONFIG.TEXT_COLOR
	footer.Position = UDim2.fromOffset(16, 60 + rows * rowHeight + 4)
	footer.Size = UDim2.fromOffset(Drive.CONFIG.SCORE_PANEL_WIDTH - 32, 22)
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.Text = ""
	footer.Parent = panel

	-- The tied banner, for the local player alone and only while they are tied. The comedy is the
	-- point and so is the teaching: it says what they did.
	local tied = Instance.new("TextLabel")
	tied.Name = "TiedBanner"
	tied.BackgroundTransparency = 1
	tied.Font = Enum.Font.Code
	tied.TextSize = Drive.CONFIG.TIED_TEXT_SIZE
	tied.TextColor3 = Drive.CONFIG.TIED_COLOR
	tied.AnchorPoint = Vector2.new(0.5, 0)
	tied.Position = UDim2.new(0.5, 0, 0, Drive.CONFIG.TIED_TOP_OFFSET)
	tied.Size = UDim2.fromOffset(620, 30)
	tied.Text = ""
	tied.Visible = false
	local tiedStroke = Instance.new("UIStroke")
	tiedStroke.Thickness = 1
	tiedStroke.Color = Color3.new(0, 0, 0)
	tiedStroke.Parent = tied
	tied.Parent = screen

	-- THE COMPASS (task 125). Karen: *"we need to indicate from what side drive is comming"*. Top
	-- centre, thin, and built empty -- `Compass.start` fills it and this file writes nothing inside.
	local compass = Instance.new("Frame")
	compass.Name = "Compass"
	compass.BackgroundColor3 = Compass.CONFIG.BACKGROUND
	compass.BackgroundTransparency = Compass.CONFIG.TRANSPARENCY
	compass.BorderSizePixel = 0
	compass.AnchorPoint = Vector2.new(0.5, 0)
	compass.Position = UDim2.new(0.5, 0, 0, Compass.CONFIG.TOP)
	compass.Size = UDim2.fromOffset(Compass.CONFIG.WIDTH, Compass.CONFIG.HEIGHT)
	compass.ZIndex = Compass.CONFIG.Z_INDEX
	compass.ClipsDescendants = true -- a mark that has scrolled off the end must not spill onto the sky
	compass.Visible = false
	compass.Parent = screen

	-- THE REPORT, over everything: it is a thing you stop and read. Empty and hidden until
	-- `ReportPanel.start` fills it -- this file creates the box and writes nothing inside it.
	local report = Instance.new("Frame")
	report.Name = "ReportPanel"
	report.BackgroundColor3 = Report.CONFIG.PANEL_COLOR
	report.BackgroundTransparency = Report.CONFIG.PANEL_TRANSPARENCY
	report.BorderSizePixel = 0
	report.AnchorPoint = Vector2.new(0.5, 0.5)
	report.Position = UDim2.fromScale(0.5, 0.5)
	report.Size = UDim2.fromOffset(Report.CONFIG.PANEL_WIDTH, Report.CONFIG.PANEL_HEIGHT)
	report.ZIndex = Report.CONFIG.PANEL_Z_INDEX
	report.Visible = false
	report.Parent = screen

	local label = Instance.new("TextLabel")
	label.Name = "Readout"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.TextSize = config.HUD_TEXT_SIZE
	label.TextColor3 = config.CROSSHAIR_COLOR
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.AnchorPoint = Vector2.new(1, 1)
	label.Position = UDim2.new(1, -16, 1, -16)
	label.Size = UDim2.fromOffset(240, 24)
	label.Text = ""
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = label
	label.Parent = screen

	crosshair = container
	readout = label
	hitMark = mark
	driveBar = bar
	feedFrame = feed
	scorePanel = panel
	reportFrame = report
	compassFrame = compass
	scoreTitle = title
	scoreFooter = footer
	tiedBanner = tied
	return screen
end

-- Shows the marker for its own lifetime. The ONE writer of the marker's colour and visibility.
-- `kind` is "kill" or anything else, which means "hit": an unknown payload must still draw
-- something, because a marker that silently does nothing is the failure this exists to fix.
function Hud.showHitMark(kind: string?)
	local mark = hitMark
	if not mark or not Shotgun.CONFIG.HIT_MARK_ENABLED then
		return
	end
	local config = Shotgun.CONFIG
	local kill = kind == "kill"
	hitKind = if kill then "kill" else "hit"

	for _, child in ipairs(mark:GetChildren()) do
		if child:IsA("Frame") then
			child.BackgroundColor3 = if kill then config.HIT_MARK_KILL_COLOR else config.HIT_MARK_COLOR
		end
	end
	mark.Visible = true
	-- THE TICK RIDES WITH THE PICTURE (task 124). It is called from here and nowhere else, because
	-- this is the one writer of the marker -- so what you hear and what you see cannot disagree about
	-- what happened. An empty id plays nothing and counts itself; see `Hud.Sound`.
	Sound.tick(hitKind)

	hitToken += 1
	local token = hitToken
	task.delay(if kill then config.HIT_MARK_KILL_SECONDS else config.HIT_MARK_SECONDS, function()
		if token ~= hitToken then
			return -- a later hit owns the marker now
		end
		hitKind = nil
		if hitMark then
			hitMark.Visible = false
		end
	end)
end

-- What the server's remote is bound to. It is a named function rather than an inline closure so a
-- client spec can drive exactly the code path the wire drives.
function Hud.onHitMarker(payload: any)
	Hud.showHitMark(if type(payload) == "table" then payload.kind else nil)
end

-- `[*]* SLUG 24`: barrel glyphs (* Live, x Spent, - Empty) with the selected barrel in brackets,
-- then the ammo the NEXT load uses, the reserve, and " R" while an action is running.
-- `row` IS THE WEAPON THIS STATE BELONGS TO (task 140), and all it decides is the WORD: the wire
-- says `Slug` for both guns because `Boar.Wound.damageFor` branches on that string, and a rifle
-- printing "SLUG" would be a lie on screen. `row.AMMO_LABEL` is the one mapping, here in the one
-- module that draws. nil is the shotgun's own words, which is every caller before the rifle.
local function textFor(state: Shotgun.WeaponSnapshot, row: any?): string
	local glyphs = ""
	for index, barrel in ipairs(state.barrels) do
		local glyph = if barrel == "Live" then "*" elseif barrel == "Spent" then "x" else "-"
		glyphs ..= if index == state.selected then "[" .. glyph .. "]" else glyph
	end
	local busyMark = if state.busyFor > 0 then " R" else ""
	-- Shells are carried per type, so the count shown is the pocket the next load comes from, and
	-- the server's one-line notice ("NO BUCK") is what tells the player why X did nothing.
	local pocket = state.reserve[state.ammo] or 0
	local notice = if state.notice then " " .. state.notice else ""
	local resolved = row or Weapons.row(state.weapon)
	local label = (resolved and resolved.AMMO_LABEL and resolved.AMMO_LABEL[state.ammo]) or string.upper(state.ammo)
	return string.format("%s %s %d%s%s", glyphs, label, pocket, busyMark, notice)
end

-- PURE, AND EXPORTED (task 112, round 3). The readout case could only ever ask the LIVE text, and
-- the live player is tied to a tree by the last scenario, so the text is empty and the case had
-- nothing to assert -- round 2 made it return early, which is a case that proves nothing. Exporting
-- the formatter lets a spec hand it a state it owns and assert the SHAPE, and still check that the
-- live text is empty exactly when there is no gun.
function Hud.readoutFor(state: Shotgun.WeaponSnapshot, row: any?): string
	return textFor(state, row)
end

local function clockText(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(whole / 60), whole % 60)
end

local function scoreRowText(rank: number, row): string
	local team = if row.team == "Drivers" then "DRIVER" elseif row.team == "Shooters" then "SHOOTER" else "-"
	-- `left` is a fact the board carries; a leaver's row stays on this drive's screen (drive design
	-- section 4.4), and a trailing "*" is how the reader knows why they are not in the next drive.
	local gone = if row.left then " *" else ""
	return string.format(
		"%-2d %-16s %-8s %5d %7d%s",
		rank,
		string.sub(tostring(row.name or "?"), 1, 16),
		team,
		row.kills,
		row.points,
		gone
	)
end

-- WHETHER THE SCORE PANEL SHOWS, and the one new clause in it: NOT WHILE THE REPORT IS OPEN. Two
-- centred panels at once is two panels nobody can read, and the report is the one the player asked
-- for by pressing Tab. Pure and exported for the same reason the renderer below is -- a drive is 600
-- seconds long, so no harness run ever reaches the Scoring phase.
function Hud.scorePanelVisible(snapshot, reportOpen: boolean?): boolean
	return snapshot ~= nil and snapshot.phase == "Scoring" and Drive.CONFIG.SCOREBOARD_ENABLED and reportOpen ~= true
end

-- THE ONE WRITER of the score panel, and it is PUBLIC on purpose: a drive is 600 seconds long, so no
-- harness run ever reaches the Scoring phase, and the design's visibility assertion (section 12.7
-- item 4) could not be written at all unless a spec can hand this the snapshot the wire would. It is
-- the same reason Hud.onHitMarker is a named function and not an inline closure. Nothing else in the
-- repo calls it but renderDrive.
function Hud.renderScore(snapshot, secondsLeft: number?)
	local panel = scorePanel
	if not panel then
		return
	end
	local show = Hud.scorePanelVisible(snapshot, ReportPanel.isOpen())
	panel.Visible = show
	if not show then
		-- Cleared, not just hidden: a stale board must not flash for a frame at the next Scoring.
		for _, line in ipairs(scoreLines) do
			line.Text = ""
			line.Visible = false
		end
		return
	end
	if scoreTitle then
		scoreTitle.Text = string.format("DRIVE %d   SCORE", snapshot.driveNumber)
	end
	local me = Players.LocalPlayer.UserId
	for index, line in ipairs(scoreLines) do
		local row = snapshot.rows[index]
		if row then
			line.Text = scoreRowText(index, row)
			line.TextColor3 = if row.userId == me then Drive.CONFIG.SCORE_HIGHLIGHT_COLOR else Drive.CONFIG.TEXT_COLOR
			line.Visible = true
		else
			line.Text = ""
			line.Visible = false
		end
	end
	if scoreFooter then
		scoreFooter.Text = string.format("NEXT DRIVE IN %d", math.max(0, math.floor(secondsLeft or 0)))
	end
end

-- THE ONE WRITER of the tied banner. The local player only: everybody else's tie is in the feed and
-- in the rope you can see across the arena.
function Hud.renderTied(isTied: boolean)
	local banner = tiedBanner
	if not banner then
		return
	end
	banner.Visible = isTied
	banner.Text = if isTied then Drive.CONFIG.TIED_TEXT else ""
end

-- The bar's whole content. `MatchSystem` may be nil -- the Hud works with no drive at all, exactly
-- as it works with no camera -- and then the bar is simply hidden.
local function renderDrive(MatchSystem)
	local bar = driveBar
	if not bar then
		return
	end
	local snapshot = if MatchSystem then MatchSystem.get() else nil
	-- The score screen and the tied banner are driven from the same snapshot as the bar, in one pass,
	-- so the three can never disagree about which phase it is.
	Hud.renderScore(snapshot, if MatchSystem then MatchSystem.secondsLeft() else 0)
	Hud.renderTied(MatchSystem ~= nil and MatchSystem.isTied())
	if not snapshot then
		bar.Visible = false
		bar.Text = ""
		return
	end

	local team = MatchSystem.myTeam()
	local badge = if team == "Drivers" then "DRIVER" elseif team == "Shooters" then "SHOOTER" else ""
	bar.TextColor3 = if team == "Drivers"
		then Drive.CONFIG.DRIVER_COLOR
		elseif team == "Shooters" then Drive.CONFIG.SHOOTER_COLOR
		else Drive.CONFIG.TEXT_COLOR

	local phase = snapshot.phase
	local pieces = { string.format("DRIVE %d", snapshot.driveNumber) }
	if phase == "Running" then
		table.insert(pieces, clockText(MatchSystem.secondsLeft()))
		table.insert(pieces, string.format("BOARS %d", snapshot.boarsLeft))
	elseif phase == "Waiting" then
		-- WHY it is waiting, in the words the server used: "players", or the missing tag names.
		table.insert(pieces, "WAITING " .. table.concat(snapshot.waitingFor, ","))
	else
		table.insert(pieces, string.upper(phase))
		table.insert(pieces, clockText(MatchSystem.secondsLeft()))
	end
	if badge ~= "" then
		table.insert(pieces, badge)
	end
	bar.Text = table.concat(pieces, "   ")
	bar.Visible = true
end

-- THE KILL LINE, AS A PURE FORMATTER (task 124). Karen: *"we need to show when is killed logg or
-- something similar"*, and her shape: who, which animal, where it was hit, how far.
--
--     KAREN         MALE BOAR   chest   42 m
--     <name,-12>    <KIND> BOAR <zone>  <metres> m
--
-- `animalKind == nil` -- which is what a world with `KINDS` off sends -- reads `BOAR` with no kind
-- word rather than `NIL BOAR`.
--
-- Exported and pure so a spec can assert the shape with no wire, no drive and no kill: the same
-- reason `Hud.crosshairVisible` and `Hud.renderScore`'s predicate are exported.
function Hud.killLineText(event): string
	local who = tostring((event and event.name) or (event and event.userId) or "?")
	local kind = event and event.animalKind
	local animal = if type(kind) == "string" and kind ~= "" then string.upper(kind) .. " BOAR" else "BOAR"
	local zone = tostring((event and event.zone) or "?")
	-- ...AND WHICH GUN (task 140). The WIRE carries the weapon's id and the SCREEN carries its word:
	-- `Weapons.row(id).label`, the same split `AMMO_LABEL` has. A record from before the rifle has
	-- no id, and prints nothing rather than the word "nil" -- the rule this function already follows
	-- for `animalKind`.
	local row = Weapons.row(event and event.weapon)
	local gun = if row ~= nil then " " .. row.label else ""
	return string.format("%-12s %-11s %-6s %d m%s", who, animal, zone, Report.metres(event and event.distance), gun)
end

-- WHAT ONE FEED ENTRY READS AS, or nil when another owner draws it. Exported for the same reason
-- `Hud.killLineText` is (task 124 round 3): the rule "a Match `kill` entry draws NO line, because
-- `HitLog`'s own line draws it with the animal's kind" is the whole of why one kill is not two, and
-- a local function cannot be asserted.
function Hud.feedTextFor(entry): string?
	local who = entry.name or (if entry.userId then tostring(entry.userId) else "")
	if entry.kind == "kill" then
		-- `Match`'s FEED OWNS THE DRIVE'S EVENTS -- escape, violation, join, leave. `HitLog`'s line
		-- OWNS THE KILL, in both worlds, over its own remote (design section 4.2): its line carries
		-- the animal's KIND, which Karen's report needs and which this entry has never had. Returning
		-- nil here is how the duplicate goes away without touching `src/server/Match/`, which is in
		-- TWO_PLAYER_PATHS and not in this task's blast radius.
		return nil
	elseif entry.kind == "escape" then
		return "a boar got away"
	elseif entry.kind == "violation" then
		return string.format("%s tied to a tree", who)
	elseif entry.kind == "join" then
		return string.format("%s joined", who)
	elseif entry.kind == "leave" then
		return string.format("%s left", who)
	end
	return tostring(entry.text or entry.kind)
end

local function renderFeed(atClock: number)
	local cutoff = atClock - Drive.CONFIG.FEED_SECONDS
	while #feedEntries > 0 and feedEntries[1].at < cutoff do
		table.remove(feedEntries, 1)
	end
	while #feedEntries > Drive.CONFIG.FEED_LINES do
		table.remove(feedEntries, 1)
	end
	for index, line in ipairs(feedLines) do
		local entry = feedEntries[index]
		line.Text = if entry then entry.text else ""
		line.Visible = entry ~= nil
	end
end

-- WHEN THE CROSSHAIR IS DRAWN, as a pure predicate so a spec can assert all eight combinations
-- without a camera, a gun or a flag (camera design section 6.2; the same reason Hud.renderScore and
-- Hud.onHitMarker are public).
--
-- Hidden while aiming: in ADS the gun's own line is the aiming reference, and leaving a hipfire
-- cross on top of it is the double-reticle mistake.
--
-- AND NEVER IN FIRST PERSON, at all, aiming or not (Karen, 2026-09-27: no crosshair at any time).
-- `firstPerson` comes from `Camera.isFirstPerson()` and NOT from a second `Flags.isOn` call: the
-- camera owns the switch and republishes it as a fact about the view, the Hud decides the drawing,
-- and there is one writer of the crosshair and one source for the fact.
-- THE ONE CONVERSION from an angle to pixels (task 140). Roblox's `FieldOfView` is the VERTICAL
-- angle, so a fraction of it is the same fraction of the viewport's height -- and `Camera.Config`'s
-- own `BEAD_CENTRE_TOLERANCE_DEG` comment measures the same thing the same way (50 degrees over
-- 1080 px). One site, which is the rule the task 19 cone-unit defect bought.
function Hud.reticleDegToPx(deg: number, fovDeg: number, viewportY: number): number
	if fovDeg <= 0 or viewportY <= 0 then
		return 0
	end
	return deg / fovDeg * viewportY
end

-- IS THE SCOPE'S RETICLE ON SCREEN? PURE, and a different question from the crosshair's: this one
-- is about the VIEW's optics (what `Camera.scope()` resolved for this frame) and the mode, and the
-- crosshair's is about the gun and first person. Two predicates, two questions -- the rule the
-- previous project's "one predicate answered two unrelated questions" is made of.
-- HAS THE SIGHT PICTURE ARRIVED? One number compared, and it is the blend rather than a clock: the
-- raise's own easing is what decides when the eye is at the glass.
--
-- `blend` nil means "assume it has", which is what a caller without one means: the question THEY are
-- asking is the other half -- is this a scoped weapon at all.
local function eyepieceIn(optics: any, blend: number?): boolean
	local at = if optics ~= nil and optics.eyepiece ~= nil then optics.eyepiece.atBlend else nil
	if at == nil then
		return true
	end
	return (blend or 1) >= at
end

-- IS THE SCOPE'S SIGHT PICTURE ON SCREEN? PURE and public, and a THIRD question beside the
-- crosshair's and the reticle's: this one is "is the eye at the glass", and its answer blacks out
-- the screen, so it may never be the same predicate as "does this gun have a reticle".
function Hud.scopeVisible(mode: string?, optics: any, blend: number?): boolean
	if optics == nil or optics.eyepiece == nil or mode ~= "Aiming" then
		return false
	end
	return eyepieceIn(optics, blend)
end

-- IS THE SCOPE'S RETICLE ON SCREEN? PURE, and a different question from the crosshair's: this one
-- is about the VIEW's optics (what `Camera.scope()` resolved for this frame) and the mode, and the
-- crosshair's is about the gun and first person. Two predicates, two questions -- the rule the
-- previous project's "one predicate answered two unrelated questions" is made of.
--
-- IT WAITS FOR THE EYEPIECE (task 141): a duplex drawn over the gun half way through the raise is a
-- mark floating in the world, which is what the Director's frames of task 140 show.
function Hud.reticleVisible(mode: string?, optics: any, blend: number?): boolean
	return optics ~= nil and optics.reticle ~= nil and mode == "Aiming" and eyepieceIn(optics, blend)
end

-- THE EYEPIECE, LAID OUT IN PIXELS FROM ITS DEGREES -- the same conversion and the same
-- recompute-only-on-change rule as the duplex's.
local lastScopeFov, lastScopeY, lastScopeSpec = -1, -1, nil :: any
function Hud.layoutScope(overlay: Frame, optics: any, fovDeg: number)
	local camera = Workspace.CurrentCamera
	local spec = if optics ~= nil then optics.eyepiece else nil
	local viewport = if camera then camera.ViewportSize else Vector2.zero
	if spec == nil or viewport.Y <= 0 then
		return
	end
	if math.abs(fovDeg - lastScopeFov) < 1e-3 and viewport.Y == lastScopeY and spec == lastScopeSpec then
		return
	end
	lastScopeFov, lastScopeY, lastScopeSpec = fovDeg, viewport.Y, spec
	-- NEVER WIDER THAN THE SCREEN'S SHORT SIDE: a circle that ran off the edges would be a black
	-- border rather than an eyepiece, and the duplex's degrees would then lie about where the edge is.
	local diameter = math.max(
		2,
		math.min(Hud.reticleDegToPx(spec.diameterDeg, fovDeg, viewport.Y), math.min(viewport.X, viewport.Y))
	)
	local rimPx = math.max(1, Hud.reticleDegToPx(spec.rimThickDeg, fovDeg, viewport.Y))
	local mask = overlay:FindFirstChild("Mask")
	if mask and mask:IsA("Frame") then
		mask.Size = UDim2.fromOffset(diameter, diameter)
		local edge = mask:FindFirstChild("Edge")
		if edge and edge:IsA("UIStroke") then
			edge.Color = spec.maskColor
			-- THE SCREEN'S DIAGONAL: the smallest thickness certain to reach every corner from the
			-- circle's edge, whatever the aspect ratio.
			edge.Thickness = math.ceil(math.sqrt(viewport.X * viewport.X + viewport.Y * viewport.Y))
		end
	end
	local rim = overlay:FindFirstChild("Rim")
	if rim and rim:IsA("Frame") then
		local inner = math.max(2, diameter - 2 * rimPx)
		rim.Size = UDim2.fromOffset(inner, inner)
		local edge = rim:FindFirstChild("Edge")
		if edge and edge:IsA("UIStroke") then
			edge.Color = spec.rimColor
			edge.Thickness = rimPx
		end
	end
end

-- THE WHOLE SIGHT PICTURE FOR THIS FRAME -- the mask, and the duplex on it.
--
-- IT IS ONCE A FRAME AND NOT ON AN EVENT (task 141), which is the second half of the Director's
-- "the scope view is wrong". Everything else in this file is event-driven, and `Camera.Changed`
-- fires on a MODE TRANSITION: at the instant `Third -> Aiming` arrives the blend is still 0, so a
-- sight picture that waits for the blend was computed exactly once, at the only moment it is false,
-- and never again. MEASURED in the Forest Test: the camera read fov 19.87 and the gun had already
-- taken itself out of the view, while the overlay was still hidden. This is the same reason the
-- compass has a `RenderStepped` of its own -- a thing that tracks the VIEW cannot be told by an
-- event about the MODE.
--
-- It is still called from `render` as well, so a mode change that happens between two frames (a
-- death, a weapon taken away) turns the mask off on that frame rather than the next.
--
-- The per-frame cost is three reads and a boolean; `layoutScope` and `layoutReticle` both return
-- immediately unless the field of view, the viewport or the spec actually moved.
function Hud.renderScope(CameraSystem)
	local reticle = Hud.reticle()
	local overlay = Hud.scopeOverlay()
	if reticle == nil and overlay == nil then
		return
	end
	local optics = if CameraSystem ~= nil and CameraSystem.scope then CameraSystem.scope() else nil
	local mode = if CameraSystem ~= nil then CameraSystem.getMode() else nil
	-- THE RAISE'S OWN PROGRESS, from the camera that is doing it. `getBlend` reads the state this
	-- frame resolved, so the mask arrives on the frame the eye does.
	local blend = if CameraSystem ~= nil and CameraSystem.getBlend then CameraSystem.getBlend() else nil
	-- THE FRAME'S OWN FIELD OF VIEW, not the weapon's target (the Reviewer's note, task 140 round
	-- 1): the mode is `Aiming` from the first frame of the raise while the blend is still easing, so
	-- laying the duplex out at `aimFovDeg` would draw the wrong degrees for the 0.2 s of
	-- `AIM_RAISE_SECONDS`. The camera is the one that knows what it is rendering.
	local camera = Workspace.CurrentCamera
	local liveFov = if camera then camera.FieldOfView else (if optics ~= nil then optics.aimFovDeg else nil) or 0
	if overlay ~= nil then
		local scoped = Hud.scopeVisible(mode, optics, blend)
		overlay.Visible = scoped
		if scoped then
			Hud.layoutScope(overlay, optics, liveFov)
		end
		-- THE COMPASS IS HIDDEN, NOT COVERED (task 141). A mask blacks out everything OUTSIDE the
		-- eyepiece, so no ZIndex in the world can take a mark that is drawn in the middle of the
		-- screen out of the glass -- and the compass strip is the one Hud element that is. MEASURED:
		-- with the mask at 11, over the compass's own 6-10, the band and its labels vanished and the
		-- red DRIVE marker and three ticks went on floating in the sight picture.
		--
		-- IT PUTS BACK EXACTLY WHAT IT HID, which is why the flag exists rather than a plain
		-- `not scoped`: the strip is invisible until `Compass.start` runs, and a Hud that switched
		-- it on would draw an empty band in a world that has no compass yet.
		local compass = Hud.compass()
		if compass ~= nil then
			if scoped then
				if compass.Visible then
					compassHiddenByScope = true
					compass.Visible = false
				end
			elseif compassHiddenByScope then
				compassHiddenByScope = false
				compass.Visible = true
			end
		end
	end
	if reticle ~= nil then
		local visible = Hud.reticleVisible(mode, optics, blend)
		reticle.Visible = visible
		if visible then
			Hud.layoutReticle(reticle, optics.reticle, liveFov)
		end
	end
end

function Hud.scopeOverlay(): Frame?
	local screen = gui
	local found = screen and screen:FindFirstChild("ScopeOverlay")
	return if found and found:IsA("Frame") then found :: Frame else nil
end

-- THE DUPLEX, LAID OUT IN PIXELS FROM ITS DEGREES. Recomputed only when the field of view or the
-- viewport has changed -- two numbers compared -- so a scoped frame costs no more per-frame work
-- than an unscoped one.
-- ...AND WHICH SPEC IT DREW, not only at what size (the Reviewer's note, round 1): two scopes at
-- the same magnification with different reticles would otherwise reuse the first one's pixels.
local lastReticleFov, lastReticleY, lastReticleSpec = -1, -1, nil :: any
function Hud.layoutReticle(reticle: Frame, spec: any, fovDeg: number)
	local camera = Workspace.CurrentCamera
	local viewportY = if camera then camera.ViewportSize.Y else 0
	if viewportY <= 0 or spec == nil then
		return
	end
	if math.abs(fovDeg - lastReticleFov) < 1e-3 and viewportY == lastReticleY and spec == lastReticleSpec then
		return
	end
	lastReticleFov, lastReticleY, lastReticleSpec = fovDeg, viewportY, spec
	local function px(deg: number): number
		return Hud.reticleDegToPx(deg, fovDeg, viewportY)
	end

	local ring = reticle:FindFirstChild("Ring")
	if ring and ring:IsA("Frame") then
		local outer = math.max(2, px(spec.ringOuterDeg))
		ring.Size = UDim2.fromOffset(outer, outer)
		local edge = ring:FindFirstChild("Edge")
		if edge and edge:IsA("UIStroke") then
			edge.Thickness = math.max(1, px(spec.ringThickDeg))
			edge.Color = spec.color
		end
	end

	-- Each bar hangs from the centre: a gap, then its own length, on its own side.
	local function place(
		name: string,
		vertical: boolean,
		sign: number,
		thickDeg: number,
		armDeg: number,
		gapDeg: number
	)
		local bar = reticle:FindFirstChild(name)
		if not (bar and bar:IsA("Frame")) then
			return
		end
		local thick = math.max(1, px(thickDeg))
		local length = math.max(1, px(armDeg))
		local gap = px(gapDeg)
		bar.BackgroundColor3 = spec.color
		if vertical then
			bar.Size = UDim2.fromOffset(thick, length)
			bar.Position = UDim2.new(0.5, 0, 0.5, sign * (gap + length / 2))
		else
			bar.Size = UDim2.fromOffset(length, thick)
			bar.Position = UDim2.new(0.5, sign * (gap + length / 2), 0.5, 0)
		end
	end

	place("CrossTop", true, -1, spec.crossThickDeg, spec.crossArmDeg, spec.crossGapDeg)
	place("CrossBottom", true, 1, spec.crossThickDeg, spec.crossArmDeg, spec.crossGapDeg)
	place("CrossLeft", false, -1, spec.crossThickDeg, spec.crossArmDeg, spec.crossGapDeg)
	place("CrossRight", false, 1, spec.crossThickDeg, spec.crossArmDeg, spec.crossGapDeg)
	-- THE POSTS START WHERE THE THIN CROSS ENDS, which is what a duplex IS: a thick bar from the
	-- edge of the view in to a point, and a hair from there to the centre.
	local postGap = spec.crossGapDeg + spec.crossArmDeg
	place("PostTop", true, -1, spec.postThickDeg, spec.postArmDeg, postGap)
	place("PostBottom", true, 1, spec.postThickDeg, spec.postArmDeg, postGap)
	place("PostLeft", false, -1, spec.postThickDeg, spec.postArmDeg, postGap)
	place("PostRight", false, 1, spec.postThickDeg, spec.postArmDeg, postGap)
end

function Hud.reticle(): Frame?
	local screen = gui
	local found = screen and screen:FindFirstChild("Reticle")
	return if found and found:IsA("Frame") then found :: Frame else nil
end

function Hud.crosshairVisible(state, aiming: boolean, firstPerson: boolean): boolean
	if not Shotgun.CONFIG.CROSSHAIR_ENABLED or firstPerson or aiming then
		return false
	end
	return state ~= nil and state.equipped == true
end

local function render(Weapon, CameraSystem)
	local state = Weapon.get()
	if crosshair then
		-- The Hud asks the CAMERA, which is the state, not the weapon's aim flag, which is the
		-- request -- and it asks the same camera which view this build is running.
		local aiming = CameraSystem ~= nil and CameraSystem.getMode() == "Aiming"
		-- NO CAMERA MEANS NO CROSSHAIR, AND THE ASYMMETRY IS DELIBERATE (task 123 round 7). `aiming`
		-- defaults to false because an unknown aim is a hipfire; `firstPerson` defaults to TRUE
		-- because Karen's rule is "no crosshair at any time" in first person and a question nobody
		-- can answer must not be the thing that overrides her. The crosshair exists for the
		-- third-person shoulder camera, so no camera system is also no third person to draw it for.
		local firstPerson = CameraSystem == nil or CameraSystem.isFirstPerson()
		crosshair.Visible = Hud.crosshairVisible(state, aiming, firstPerson)
	end
	-- THE SCOPE'S RETICLE, from the VIEW's own optics (task 140). `Camera.scope()` is what the
	-- camera resolved for this frame, so the Hud never reads the weapon table to decide whether to
	-- draw it -- exactly as it never reads the weapon to decide whether it is in first person.
	Hud.renderScope(CameraSystem)
	if readout then
		-- NO GUN, NO READOUT (TASKS.md 35b(a)). The server publishes a reset state when it revokes a
		-- Tool, and `equipped` is false in it -- so a player tied to a tree stops reading an ammo
		-- count for a gun that is not in their hands. Without both halves the old snapshot simply
		-- stayed on screen, which is what the Task 35 screenshot shows.
		readout.Text = if state and state.equipped then textFor(state) else ""
	end
end
-- ONE KILL, ONE LINE. The replica hears the server and fires `Killed`; this draws it. A NAMED
-- handler rather than a closure, exactly as `Hud.onHitMarker` is, so the client half of the kill log
-- can be driven in a spec instead of only by a live drive (task 124 round 3).
function Hud.onKilled(event)
	table.insert(feedEntries, { text = Hud.killLineText(event), at = os.clock() })
	renderFeed(os.clock())
end

-- HOW LONG THE HUD WILL WAIT FOR A SYSTEM IT DRAWS, before it says out loud that it gave up.
-- Ten seconds, the same bound `CameraBoot` uses for the same race (task 133).
local LATE_MODULE_SECONDS = 10

-- "NOT THERE YET" IS NOT "NOT THERE AT ALL", AND THAT WAS THE BUG (task 134).
--
-- `Hud.start` read `PlayerScripts.Match` with `FindFirstChild` -- on the line after it WAITED for
-- `PlayerScripts.Camera`, in a comment that describes this exact race and was written because of it
-- (task 123 round 7: the crosshair that would not go away). `PlayerScripts` is replicated, so when
-- `Match` had not arrived yet `MatchSystem` was nil FOR THE SESSION and none of the three
-- connections below was ever made: no drive bar, no clock, no feed, all drive, and not a word
-- anywhere saying why. It is the same shape as task 133's gunless session, in a different owner --
-- found while fixing that one and queued as TASKS row 133c.
--
-- SO IT CONNECTS WHENEVER THE MODULE LANDS: at once when it is already there -- which is the common
-- case and costs exactly the `FindFirstChild` it costs today -- and otherwise from a spawned wait,
-- so `Hud.start` is never blocked by a system the Hud is designed to work without. A module that
-- never arrives is a WARNING and not a silence.
--
-- IT TAKES THE CONTAINER AND THE NAME, not a module, because the thing being tested is the RACE:
-- a spec cannot create a requireable ModuleScript (`Source` is not writable outside a plugin), but
-- it can hand this a folder, add a child to it a moment later, and prove the callback still ran.
-- Returns whether the child was already there, which is what "did this cost a frame" means.
function Hud.whenReady(container: Instance, name: string, use: (Instance) -> ()): boolean
	local existing = container:FindFirstChild(name)
	if existing ~= nil then
		use(existing)
		return true
	end
	task.spawn(function()
		local late = container:WaitForChild(name, LATE_MODULE_SECONDS)
		if late == nil then
			warn(
				string.format(
					"[Hud] no %s.%s after %d s: the Hud will draw nothing for it this session (task 134)",
					container.Name,
					name,
					LATE_MODULE_SECONDS
				)
			)
			return
		end
		use(late)
	end)
	return false
end

-- EVERYTHING THE HUD DRAWS FROM THE DRIVE, AS ONE CALL. It was inline in `Hud.start`, which is why
-- it could only ever happen at start: pulled out so it can also happen a quarter of a second later,
-- when `Match` wins its race late. IDEMPOTENT -- a second call connects nothing twice, so the early
-- path and the late path cannot both land.
function Hud.useMatch(MatchSystem): boolean
	if matchConnected or MatchSystem == nil then
		return false
	end
	matchConnected = true
	matchSystem = MatchSystem
	-- THE PANEL READS THE SCORE OFF THE MATCH (design section 8.1), and it may already have been
	-- built with nothing. One setter, so a late match reaches it too rather than leaving the report
	-- without points for the session.
	ReportPanel.setMatch(MatchSystem)
	MatchSystem.Changed:Connect(function()
		renderDrive(MatchSystem)
	end)
	MatchSystem.Feed:Connect(function(entry)
		-- NO TEXT, NO LINE: `feedTextFor` answers nil for an entry another owner now draws.
		local text = Hud.feedTextFor(entry)
		if text ~= nil then
			table.insert(feedEntries, { text = text, at = os.clock() })
			renderFeed(os.clock())
		end
	end)
	-- The timer is the one thing that has to be redrawn without an event, because it counts
	-- down locally from a server timestamp (docs/design/drive.md section 9.1). Once a second,
	-- not once a frame: the text only changes that often.
	local sinceTick = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceTick += dt
		if sinceTick < 0.25 then
			return
		end
		sinceTick = 0
		renderDrive(MatchSystem)
		renderFeed(os.clock())
	end)
	renderDrive(MatchSystem)
	return true
end

function Hud.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local scripts = player:WaitForChild("PlayerScripts")
	local Weapon = require(scripts:WaitForChild("Weapon"))
	-- `WaitForChild` AND NOT `FindFirstChild`, AND THAT WAS THE BUG (task 123 round 7). Karen, in a
	-- first-person session: *"why there is corss? we dont need a cross, I mentione crossing road"*.
	-- MEASURED in her own running client: `Camera.isFirstPerson()` answered TRUE and
	-- `HunterHud.Crosshair.Visible` was TRUE anyway -- because this line ran before the engine had
	-- copied `Camera` into `PlayerScripts` (it was the LAST of thirteen children in that session),
	-- so `CameraSystem` was nil, `firstPerson` read false, and the `CameraSystem.Changed` connection
	-- below was never made either, so nothing ever corrected it.
	--
	-- IT IS A RACE AND NOT A PROPERTY OF THAT WORLD: `WeaponBoot` and `CameraBoot` are two scripts
	-- with no defined order, so the DEV place is exposed to exactly the same one and has simply been
	-- winning it. A bounded wait keeps the old promise -- the Hud still works if the camera never
	-- arrives -- and removes the race. One-way: the camera has no reference to the Hud.
	local cameraModule = scripts:WaitForChild("Camera", 5)
	if cameraModule == nil then
		-- NEVER A SILENT NIL (task 134). The wait below is left exactly as task 123 round 7 measured
		-- it -- the Hud reads `CameraSystem` synchronously a few lines down, so this one cannot move
		-- to `whenReady` without moving what reads it -- but giving up is now said out loud.
		warn("[Hud] no PlayerScripts.Camera after 5 s: the crosshair will not follow the camera this session")
	end
	local CameraSystem = if cameraModule then require(cameraModule) else nil

	gui = build();
	(gui :: ScreenGui).Parent = player:WaitForChild("PlayerGui")

	-- One way: the server tells this client that something of theirs landed. The Hud never fires it.
	markerConnection = Shotgun.remotes().HitMarker.OnClientEvent:Connect(Hud.onHitMarker)

	-- THE DRIVE BAR, THE CLOCK AND THE FEED (task 134). The drive may not exist -- it is its own
	-- system, and 1.7a is the first task that ships it -- and the Hud works without it and simply
	-- draws no bar. But "not shipped" and "not replicated YET" are different things, and this line
	-- used to answer both with nil: see `Hud.whenReady`. One-way: the match has no reference to the
	-- Hud.
	Hud.whenReady(scripts, "Match", function(module)
		Hud.useMatch(require(module))
	end)

	-- THE KILL LOG (task 124). `PlayerScripts.Report` is the replica that hears the server; the Hud
	-- draws. It may not exist yet in a world that has not booted it, and the Hud works without it --
	-- the same shape as the camera and the match above.
	local reportModule = scripts:WaitForChild("Report", 5)
	if reportModule == nil then
		warn("[Hud] no PlayerScripts.Report after 5 s: there will be no kill log this session")
	end
	local ReportSystem = if reportModule then require(reportModule) else nil
	if ReportSystem then
		ReportSystem.Killed:Connect(Hud.onKilled)
	end

	-- TAB BELONGS TO THE ROBLOX PLAYER LIST ON PC, and a `ContextActionService` binding cannot take a
	-- CoreGui key -- so the stock list is turned off and the key becomes ours. The Hud is the ONE
	-- writer of `SetCoreGuiEnabled` (it already owns screen space) and this is its only call.
	--
	-- `pcall`, because `SetCoreGuiEnabled` is one of the calls that errors when the CoreGui is not
	-- ready yet, and a Hud that fails to boot over a player list is a blank screen -- the exact
	-- failure `docs/PROJECT_CONTEXT.md` records twice.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)

	-- THE REPORT PANEL, handed its frame and its collaborators. Every one of them may be nil and the
	-- panel says so in its own header: with no camera there is no `Cursor`, and then the keyboard is
	-- the only way to drive it -- which is why the keyboard path exists.
	-- THE COMPASS, AND WHERE ITS DRIVE BEARING COMES FROM (task 125).
	--
	-- THE WORLD STATES IT AND THE HUD DRAWS IT. `ForestTest.DRIVE_BEARING_DEG` is derived in that
	-- world's own data from `DRIVERS.startNorthStuds` -- the beaters begin 700 studs north of the
	-- road -- so the HUD never works out a direction from a position. Any other world has not said
	-- yet, and then the strip is a plain compass with no marker rather than a marker pointing at a
	-- guess; `Compass.setBearing` is the one line a later Match drive needs.
	-- ONCE A FRAME, FOR THE SIGHT PICTURE (task 141): see `Hud.renderScope`. Its own connection
	-- rather than the compass's, because the compass's lives inside `if compassFrame then` and a
	-- scope that only worked in a world with a compass strip is a bug waiting for the next place.
	if CameraSystem then
		RunService.RenderStepped:Connect(function()
			Hud.renderScope(CameraSystem)
		end)
	end

	if compassFrame then
		local bearing = nil
		if Map.EXPECTED_WORLD == "forest-test" then
			-- WAITED FOR, FOR THE SAME REASON AS THE MATCH (task 134). This was the Hud's SECOND
			-- `FindFirstChild` on a replicated module, found by the sweep this task asked for, and it
			-- fails the same silent way: no `ForestTest` yet means no bearing, and a compass with no
			-- DRIVE marker on it is the thing Karen asked for in task 125 -- *"we need to indicate
			-- from what side drive is comming"* -- quietly not there. `Compass.setBearing` is public
			-- exactly so it can be told later; in the common case this closure runs here and now, and
			-- `Compass.start` two lines down sets the same number again.
			Hud.whenReady(ReplicatedStorage, "ForestTest", function(module)
				local data = require(module)
				bearing = data and data.DRIVE_BEARING_DEG
				Compass.setBearing(bearing)
			end)
		end
		Compass.start(compassFrame, bearing)
		-- ONCE A FRAME, because it tracks the view: everything else in this file is event-driven,
		-- and a compass that updates on an event is a compass that lags the turn that caused it.
		-- `RenderStepped` is the client's own draw tick and this writes nothing but its own frame.
		RunService.RenderStepped:Connect(function()
			-- ASK THE SYSTEM THAT OWNS THE VIEW (task 125 round 3). Neither `CurrentCamera` (a second
			-- writer flips it) nor the character's body (in first person the camera turns the VIEW
			-- and not the body, so the strip never moved) is the view. `Camera.viewCFrame` is.
			-- See `Compass.headingFrom` for both measurements.
			Compass.render(Compass.headingFrom(CameraSystem))
		end)
	end

	if reportFrame then
		ReportPanel.start(reportFrame, {
			Report = ReportSystem,
			Input = Weapon.Input,
			Cursor = if CameraSystem then CameraSystem.Cursor else nil,
			Match = matchSystem,
			userId = player.UserId,
		})
	end

	Weapon.Changed:Connect(function()
		render(Weapon, CameraSystem)
	end)
	if CameraSystem then
		CameraSystem.Changed:Connect(function()
			render(Weapon, CameraSystem)
		end)
	end
	render(Weapon, CameraSystem)
end

return Hud
