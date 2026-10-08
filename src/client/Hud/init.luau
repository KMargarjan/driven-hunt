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

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))
-- Which world this is, so the compass knows whether anybody has said where the drive comes from
-- (task 125). Read, never written: `Map.EXPECTED_WORLD` is a commit, not a flag.
local Map = require(ReplicatedStorage:WaitForChild("Map"))
local Report = require(ReplicatedStorage:WaitForChild("Report"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

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

local gui: ScreenGui? = nil
local crosshair: Frame? = nil
local readout: TextLabel? = nil
local hitMark: Frame? = nil
local hitKind: string? = nil
local hitToken = 0 -- so a second hit during the first mark's life cannot hide it early
local markerConnection: RBXScriptConnection? = nil
local driveBar: TextLabel? = nil
local feedFrame: Frame? = nil -- kept for the client spec's ancestor walk
local feedLines: { TextLabel } = {}
local feedEntries: { { text: string, at: number } } = {}
local scorePanel: Frame? = nil
local reportFrame: Frame? = nil
local compassFrame: Frame? = nil
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
local function textFor(state: Shotgun.WeaponSnapshot): string
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
	return string.format("%s %s %d%s%s", glyphs, string.upper(state.ammo), pocket, busyMark, notice)
end

-- PURE, AND EXPORTED (task 112, round 3). The readout case could only ever ask the LIVE text, and
-- the live player is tied to a tree by the last scenario, so the text is empty and the case had
-- nothing to assert -- round 2 made it return early, which is a case that proves nothing. Exporting
-- the formatter lets a spec hand it a state it owns and assert the SHAPE, and still check that the
-- live text is empty exactly when there is no gun.
function Hud.readoutFor(state: Shotgun.WeaponSnapshot): string
	return textFor(state)
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
	return string.format("%-12s %-11s %-6s %d m", who, animal, zone, Report.metres(event and event.distance))
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
	local CameraSystem = if cameraModule then require(cameraModule) else nil
	-- The drive may not exist (it is its own system, and 1.7a is the first task that ships it); the
	-- Hud works without it and simply draws no bar. One-way: the match has no reference to the Hud.
	local matchModule = scripts:FindFirstChild("Match")
	local MatchSystem = if matchModule then require(matchModule) else nil

	gui = build();
	(gui :: ScreenGui).Parent = player:WaitForChild("PlayerGui")

	-- One way: the server tells this client that something of theirs landed. The Hud never fires it.
	markerConnection = Shotgun.remotes().HitMarker.OnClientEvent:Connect(Hud.onHitMarker)

	if MatchSystem then
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
	end

	-- THE KILL LOG (task 124). `PlayerScripts.Report` is the replica that hears the server; the Hud
	-- draws. It may not exist yet in a world that has not booted it, and the Hud works without it --
	-- the same shape as the camera and the match above.
	local reportModule = scripts:WaitForChild("Report", 5)
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
	if compassFrame then
		local bearing = nil
		if Map.EXPECTED_WORLD == "forest-test" then
			local forest = ReplicatedStorage:FindFirstChild("ForestTest")
			local data = if forest then require(forest) else nil
			bearing = data and data.DRIVE_BEARING_DEG
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
			Match = MatchSystem,
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
