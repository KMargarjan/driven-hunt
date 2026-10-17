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
-- WHETHER THIS DEVICE HAS A TOUCHSCREEN, which only `Hud.Rail` asks (task 165).
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))
-- Which world this is, so the compass knows whether anybody has said where the drive comes from
-- (task 125). Read, never written: `Map.EXPECTED_WORLD` is a commit, not a flag.
local Map = require(ReplicatedStorage:WaitForChild("Map"))
local Report = require(ReplicatedStorage:WaitForChild("Report"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
-- THE SHOP'S CATALOGUE AND ITS ONE PURE GEOMETRY QUESTION (task 178): `Shop.withinReach`, asked
-- once per frame in `Hud.renderObjective` -- the one place in this file that reads where the player
-- is standing -- and handed to `ShopPanel.setNear`, which now only ever CLOSES the panel: since
-- task 181 the shopkeeper's `ProximityPrompt` is the one thing that opens it, and that prompt is
-- resolved in the same place and handed over by `ShopPanel.setPrompt`.
local Shop = require(ReplicatedStorage:WaitForChild("Shop"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

-- The Hud's own 2-D feedback sounds have one writer, and this is it (task 124).
local Sound = require(script.Sound)
-- THE REPORT PANEL (task 124 stage B). It is a sibling module and not a second ScreenGui: the Hud
-- builds the frame with everything else here, and `ReportPanel` is the one writer of what goes inside
-- it. One ScreenGui, built once, so a visibility audit has one place to look.
local ReportPanel = require(script.ReportPanel)
-- THE HIT CARD (task 198): created here with the rest of the screen, filled by `Hud.HitCard`, which
-- -- not this file -- is the only writer of what goes in it and of its `Visible`.
local HitCard = require(script.HitCard)
-- ...and the compass strip (task 125). Same shape as the report panel: the Hud builds the frame
-- with everything else, and `Compass` is the one writer of what goes inside it.
local Compass = require(script.Compass)
-- ...and the map (task 155). Karen: *"I am missing map, we need a map when click M"*. Same shape
-- again: the Hud builds the two frames and the button, and `MapUi` is the one writer of everything
-- inside them -- including their `Visible`, which is the ONE place this file does NOT copy the
-- compass's two-writer arrangement (see `Hud.renderScope` and `docs/design/map-ui.md` section 3.3).
--
-- IT IS CALLED `MapUi` AND NOT `Map` because `Map` above is the WORLD contract
-- (`ReplicatedStorage.Map`), and this file needs both at once. The world, and the picture of it.
local MapUi = require(script.MapUi)
-- ...AND THE TWO THINGS TASK 165 ADDED, in the same shape as the three above: the Hud builds the
-- nodes and each module is the one writer of everything inside its own.
--
-- `Objective` owns the objective LINE and the WAYPOINT chevron, which are one answer rendered twice
-- ("what must I do" and "where"); `Rail` owns the right-edge button column. Karen, 2026-10-12:
-- *"we need to have better map or direction that people has to walk we need to improve design that
-- it will be clear to understand what happening / could be buttons on the side for M - map ect"*.
local Objective = require(script.Objective)
local Rail = require(script.Rail)
-- ...AND THE SHOP PANEL (task 178), in the same shape: the Hud builds the frame and `ShopPanel` is
-- the one writer of everything inside it. It follows `MapUi` rather than the compass in the one
-- respect that matters -- it owns its own `Visible` -- because whether the shop is open is a thing
-- the player and the counter decide (docs/design/shop.md section 5.1).
local ShopPanel = require(script.ShopPanel)
-- THE TRUCK PADS' SIZE DIALOG (task 182), in the same shape as the shop panel: this file builds the
-- frame and that module fills it and owns its `Visible`.
local PadPanel = require(script.PadPanel)

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
local hitCardFrame: Frame? = nil
-- THE SHOP PANEL'S FRAME (task 178): created here, filled by `Hud.ShopPanel`, and that module --
-- not this one -- writes its `Visible`.
local shopFrame: Frame? = nil
-- THE PAD DIALOG'S FRAME (task 182): created here, filled by `Hud.PadPanel`, and that module -- not
-- this one -- writes its `Visible`. The shop panel's arrangement, one task later.
local padFrame: Frame? = nil
-- THE LOADING BANNER'S FRAME (task 197): created here with the rest of the screen, filled by
-- `Hud.PadPanel`, which also owns its `Visible` -- the dialog's own arrangement, one frame over.
local padLeavingFrame: Frame? = nil
-- WHICH PAD THIS CLIENT HAS ALREADY TURNED TO FACE (task 197 part 2). One number, so the camera is
-- asked ONCE per walk-on and not once a frame -- `ShopPanel.setNear`'s edge discipline.
local facedPad: number? = nil
local compassFrame: Frame? = nil
-- Did the scope's own mask hide the compass strip? See `Hud.renderScope`.
local compassHiddenByScope = false
-- THE MAP'S THREE NODES (task 155). The Hud creates them and writes their size, position and
-- `ZIndex`; `MapUi` writes everything inside them and their `Visible`.
local miniMapFrame: Frame? = nil
local fullMapFrame: Frame? = nil
-- THE MAP'S LEGEND (task 165): a fourth node of the map's, created here and filled by `MapUi`.
local mapLegendFrame: Frame? = nil
-- THE MAP'S OWN TOUCH BUTTON IS GONE (task 165, design 7.2 item 1). It was `touchEnabled and
-- BUTTON_ENABLED`, so it never appeared in a single one of Karen's PC sessions -- which is why she
-- asked for *"buttons on the side for M - map ect"* for a button that was already written. It is the
-- first button of `Hud.Rail` now, which calls the same `MapUi.toggle` the M key calls. The removed
-- block is archived with its reason in `backups/2026-10-12_mapui-touch-button.txt` (rule 7).
-- TASK 165'S OWN NODES: the objective line, the waypoint chevron and its word, and the rail.
local objectiveLine: TextLabel? = nil
local waypointMark: Frame? = nil
local waypointWord: TextLabel? = nil
local railFrame: Frame? = nil
-- WHERE THE WORLD SAYS THE DRIVE IS, resolved once by the closure in `Hud.start` and read every
-- frame by `Hud.renderObjective`. Module-level because the per-frame pass is now the ONE writer of
-- the compass's bearing and the map's push arrow -- see `Hud.renderObjective`.
local worldBearing: number? = nil
local worldBearingLabel: string? = nil
-- Has this player reached the place the objective sends them? Latched, so the chevron cannot
-- flicker: `Objective.arrived` holds the hysteresis and this is the state it is applied to.
local arrivedAtTarget = false
-- THE LOBBY'S DATA MODULE (task 177), reached through the door this file already uses for a
-- world-specific module (`Hud.whenReady`, the same call that waits for `ForestTest`). nil in a world
-- that has no such module, and then every lobby branch of `Objective` is simply never taken.
--
-- IT IS THE PRESENCE OF THE **PART** AND NOT OF THE MODULE that says a world has a lobby: the module
-- replicates to every client in every place, and `Lobby.spotPosition()` answers nil until the server
-- has actually built one. So the Hud learns nothing about worlds and reads no flag.
local lobbyData: any = nil
local scoreTitle: TextLabel? = nil
local scoreLines: { TextLabel } = {}
local scoreFooter: TextLabel? = nil
local tiedBanner: TextLabel? = nil
-- THE START CARD (task 158): built once with everything else, shown only by `Hud.renderStartCard`.
local startCard: Frame? = nil
local startCardTitle: TextLabel? = nil
local startCardLines: { TextLabel } = {}
local startCardTimer: TextLabel? = nil
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
-- THE SHOP PANEL, published where the Hud starts it -- the `Hud.Rail` / `Hud.Shop` shape a spec
-- reaches it through.
Hud.Shop = ShopPanel

-- ...AND THE PAD DIALOG (task 182), published the same way and for the same reason.
Hud.PadPanel = PadPanel

function Hud.shopPanel(): Frame?
	return shopFrame
end

function Hud.padPanel(): Frame?
	return padFrame
end

function Hud.padLeaving(): Frame?
	return padLeavingFrame
end

function Hud.reportPanel(): Frame?
	return reportFrame
end

function Hud.hitCard(): Frame?
	return hitCardFrame
end

-- The panel module itself, for the same reason: the Hud starts it, so the Hud is where it is found.
Hud.Report = ReportPanel
Hud.HitCard = HitCard

-- THE MAP (task 155): its two frames and its button, so a spec reads them off the Hud instead of
-- walking `PlayerGui` by name -- the `Hud.compass()` / `Hud.reportPanel()` shape.
function Hud.minimap(): Frame?
	return miniMapFrame
end

function Hud.fullMap(): Frame?
	return fullMapFrame
end

function Hud.mapLegend(): Frame?
	return mapLegendFrame
end

Hud.MapUi = MapUi

-- TASK 165's THREE NODES AND TWO MODULES, read off the Hud for the reason every accessor above is:
-- a spec must never walk `PlayerGui` by name.
function Hud.objectiveLine(): TextLabel?
	return objectiveLine
end

function Hud.waypoint(): Frame?
	return waypointMark
end

function Hud.waypointWord(): TextLabel?
	return waypointWord
end

function Hud.rail(): Frame?
	return railFrame
end

Hud.Objective = Objective
Hud.Rail = Rail

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

-- ------------------------------------------------------------------ the start card (task 158)

function Hud.startCard(): Frame?
	return startCard
end

function Hud.isStartCardVisible(): boolean
	return startCard ~= nil and startCard.Visible
end

function Hud.startCardTitleText(): string
	return if startCardTitle then startCardTitle.Text else ""
end

-- Only the lines actually showing something, in order -- the same shape as `Hud.scoreRowText`.
function Hud.startCardText(): { string }
	local out = {}
	for _, line in ipairs(startCardLines) do
		if line.Visible and line.Text ~= "" then
			table.insert(out, line.Text)
		end
	end
	return out
end

function Hud.startCardTimerText(): string
	return if startCardTimer then startCardTimer.Text else ""
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

	-- THE SCOPE'S RETICLE: the INSTANCES for every element any scope in this game draws -- a ring,
	-- a thin cross and four thick outer posts -- of which each one is drawn only if the weapon's own
	-- data carries it (task 146: Karen's cross has neither ring nor posts). Built from UI primitives
	-- with NO upload, exactly as the drive report's silhouette is.
	-- A SIBLING of the crosshair and of the hit marker, for the reason the hit marker
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

	-- THE ILLUMINATED DOT (task 142), two frames: a soft halo and the core on top of it. Last in
	-- build order and highest in the stack, because it is the thing the eye goes to.
	for _, name in ipairs({ "DotHalo", "Dot" }) do
		local dot = Instance.new("Frame")
		dot.Name = name
		dot.BorderSizePixel = 0
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(0.5, 0.5)
		dot.Size = UDim2.fromOffset(1, 1)
		dot.ZIndex = if name == "Dot" then RETICLE_Z + 2 else RETICLE_Z + 1
		dot.Parent = reticle
		local dotRound = Instance.new("UICorner")
		dotRound.CornerRadius = UDim.new(0.5, 0)
		dotRound.Parent = dot
	end

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

	-- EVERY LABEL OF A PANEL SITS ABOVE THE PANEL'S OWN ZINDEX, AND WEARS THE BLACK OUTLINE (task
	-- 159). THE SECOND TIME THIS REPO HAS PAID FOR IT, and the first is written down six lines into
	-- `src/client/Hud/ReportPanel.luau`: *"with the panel opaque at ZIndex 10 and its labels at the
	-- default 1, the whole report came out as an EMPTY BLACK RECTANGLE -- the text was being drawn
	-- BEHIND its own background"*. Task 141 raised the SCORE PANEL and the START CARD to
	-- `Report.CONFIG.PANEL_Z_INDEX` (15) over the scope's mask and left their labels at 1, so both
	-- have been drawing their text behind their own translucent dark background ever since -- which
	-- is what `.screenshots/20261011T230613Z-task159-results-scene.png` and `...230908Z...` show:
	-- the panel reads, the words do not.
	--
	-- One helper, so a third panel cannot be built without it. It works under either
	-- `ScreenGui.ZIndexBehavior`: under `Global` the absolute numbers order the whole screen, under
	-- `Sibling` these still order correctly among their own siblings
	-- (https://create.roblox.com/docs/reference/engine/enums/ZIndexBehavior).
	local function panelLabel(parent: Frame, name: string, size: number): TextLabel
		local text = Instance.new("TextLabel")
		text.Name = name
		text.ZIndex = parent.ZIndex + 1
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.Code
		text.TextSize = size
		text.TextColor3 = Drive.CONFIG.TEXT_COLOR
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Text = ""
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = Drive.CONFIG.SCORE_TEXT_STROKE
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Parent = text
		text.Parent = parent
		return text
	end

	-- The score screen: a centred panel, hidden except in the Scoring phase. Built once, like
	-- everything else here, and shown by renderScore -- the ONE writer of its visibility.
	-- SINCE TASK 159 IT IS ALSO KAREN'S RESULTS TABLE, read over a sunlit wood at the end of every
	-- drive, which is why every label below goes through `panelLabel`.
	local rows = Drive.CONFIG.SCORE_ROWS_MAX
	local rowHeight = Drive.CONFIG.SCORE_ROW_HEIGHT
	local panel = Instance.new("Frame")
	panel.Name = "ScorePanel"
	panel.BackgroundColor3 = Drive.CONFIG.SCORE_PANEL_COLOR
	panel.BackgroundTransparency = Drive.CONFIG.SCORE_PANEL_TRANSPARENCY
	panel.BorderSizePixel = 0
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(Drive.CONFIG.SCORE_PANEL_WIDTH, 64 + rows * rowHeight + 30)
	-- OVER THE FEED AND THE BAR, because it is the thing to read -- AND OVER THE SCOPE'S MASK
	-- (task 141): this is drawn at the centre of the screen, which is inside the eyepiece, so at the
	-- old 5 a player who could still hold the aim in `Scoring` would read a board cut off at the
	-- glass. Same class as the compass and the drive report: a panel the GAME put up outranks a
	-- sight picture, and it shares the report's own number for that reason.
	--
	-- (Round 2 added this as a SECOND assignment seven lines above the old `= 5`, which the old one
	-- then overwrote -- a dead write, and a fix claimed in a request that had not happened.)
	panel.ZIndex = Report.CONFIG.PANEL_Z_INDEX
	panel.Visible = false
	panel.Parent = screen

	local title = panelLabel(panel, "Title", Drive.CONFIG.SCORE_TITLE_SIZE)
	title.Position = UDim2.fromOffset(16, 8)
	title.Size = UDim2.fromOffset(Drive.CONFIG.SCORE_PANEL_WIDTH - 32, 30)
	-- BOLD, through `FontFace` rather than a second font: `Font.fromEnum` keeps the Code family the
	-- whole Hud is written in -- the columns below are aligned by `string.format`, so a
	-- proportional title beside a monospace table would be two typefaces for one panel -- and the
	-- weight is the one property that changes.
	-- https://create.roblox.com/docs/reference/engine/datatypes/Font
	local titleFace = Font.fromEnum(Enum.Font.Code)
	titleFace.Weight = Enum.FontWeight.Bold
	title.FontFace = titleFace

	local header = panelLabel(panel, "Header", Drive.CONFIG.SCORE_TEXT_SIZE)
	-- DIMMER WHITE, not grey (see the contract's own comment).
	header.TextTransparency = Drive.CONFIG.SCORE_HEADER_TRANSPARENCY
	header.Position = UDim2.fromOffset(16, 42)
	header.Size = UDim2.fromOffset(Drive.CONFIG.SCORE_PANEL_WIDTH - 32, rowHeight)
	-- The TEAM column is gone and COINS took its place (task 170): see `scoreRowText`.
	header.Text = "#  NAME             KILLS  POINTS   COINS"

	table.clear(scoreLines)
	for index = 1, rows do
		local line = panelLabel(panel, string.format("Row%d", index), Drive.CONFIG.SCORE_TEXT_SIZE)
		line.Position = UDim2.fromOffset(16, 64 + (index - 1) * rowHeight)
		line.Size = UDim2.fromOffset(Drive.CONFIG.SCORE_PANEL_WIDTH - 32, rowHeight)
		line.Visible = false
		table.insert(scoreLines, line)
	end

	local footer = panelLabel(panel, "Footer", Drive.CONFIG.SCORE_TEXT_SIZE)
	footer.Position = UDim2.fromOffset(16, 64 + rows * rowHeight + 4)
	footer.Size = UDim2.fromOffset(Drive.CONFIG.SCORE_PANEL_WIDTH - 32, 22)

	-- THE START CARD (task 158), upper middle, up for the countdown and gone at GO. Karen: *"we just
	-- need to at the begining what they can shoot and timer when start"* -- so: what may be shot,
	-- your role, and one line counting down. Built once, like everything else here, and shown by
	-- `Hud.renderStartCard` -- the ONE writer of its visibility and its text.
	local cardLines = Drive.CONFIG.START_CARD_LINES_MAX
	local cardHeight = 44 + cardLines * Drive.CONFIG.START_CARD_LINE_HEIGHT + 34
	local card = Instance.new("Frame")
	card.Name = "StartCard"
	card.BackgroundColor3 = Drive.CONFIG.START_CARD_COLOR
	card.BackgroundTransparency = Drive.CONFIG.START_CARD_TRANSPARENCY
	card.BorderSizePixel = 0
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.fromScale(0.5, Drive.CONFIG.START_CARD_TOP_SCALE)
	card.Size = UDim2.fromOffset(Drive.CONFIG.START_CARD_WIDTH, cardHeight)
	-- The score panel's own number, and for its reason: a panel the GAME put up outranks a sight
	-- picture, so it is drawn over the scope's mask rather than cut off at the glass (task 141).
	card.ZIndex = Report.CONFIG.PANEL_Z_INDEX
	card.Visible = false
	card.Parent = screen

	-- THE SAME DEFECT AND THE SAME FIX (task 159). The start card is the OTHER frame task 141 raised
	-- to `PANEL_Z_INDEX` with its labels left at 1, so Karen has been reading her ten-second card
	-- through its own panel too. It is fixed here, in the same commit, because it is one defect with
	-- two instances and leaving the second would mean shipping a card nobody can read on purpose.
	local cardTitle = panelLabel(card, "Title", Drive.CONFIG.START_CARD_TITLE_SIZE)
	cardTitle.Position = UDim2.fromOffset(16, 10)
	cardTitle.Size = UDim2.fromOffset(Drive.CONFIG.START_CARD_WIDTH - 32, 28)

	table.clear(startCardLines)
	for index = 1, cardLines do
		local line = panelLabel(card, string.format("Line%d", index), Drive.CONFIG.START_CARD_TEXT_SIZE)
		line.Position = UDim2.fromOffset(16, 44 + (index - 1) * Drive.CONFIG.START_CARD_LINE_HEIGHT)
		line.Size = UDim2.fromOffset(Drive.CONFIG.START_CARD_WIDTH - 32, Drive.CONFIG.START_CARD_LINE_HEIGHT)
		line.Visible = false
		table.insert(startCardLines, line)
	end

	local cardTimer = panelLabel(card, "Timer", Drive.CONFIG.START_CARD_TITLE_SIZE)
	cardTimer.TextColor3 = Drive.CONFIG.START_CARD_TIMER_COLOR
	cardTimer.Position = UDim2.fromOffset(16, 44 + cardLines * Drive.CONFIG.START_CARD_LINE_HEIGHT + 2)
	cardTimer.Size = UDim2.fromOffset(Drive.CONFIG.START_CARD_WIDTH - 32, 28)

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

	-- THE HIT CARD (task 198), in the LOWER LEFT, stacked on top of the event feed. Karen,
	-- 2026-10-16: *"so somewhere in corner after hit we indicate where it landed"*.
	--
	-- WHY THAT CORNER AND NOT ANOTHER: the minimap and the button rail own the top right, the ammo
	-- readout owns the very bottom right (`Readout`, anchored (1,1) at -16, -16), and the whole top
	-- band is the objective line (y 8), the drive bar (y 44) and the compass (y 108, 360 px wide,
	-- which on a 400 px phone is the entire width). What is left is the bottom left, where the
	-- player already looks for what just happened -- the kill feed -- so the card sits directly on
	-- top of it. Its bottom is computed from the FEED's own two constants, so the two cannot overlap
	-- at any viewport instead of being eyeballed at one.
	local hitCard = Instance.new("Frame")
	hitCard.Name = "HitCard"
	hitCard.BackgroundColor3 = Report.CONFIG.CARD.PANEL_COLOR
	hitCard.BackgroundTransparency = Report.CONFIG.CARD.PANEL_TRANSPARENCY
	hitCard.BorderSizePixel = 0
	hitCard.AnchorPoint = Vector2.new(0, 1)
	hitCard.Position = UDim2.new(
		0,
		Report.CONFIG.CARD.MARGIN_LEFT,
		1,
		-(Drive.CONFIG.FEED_BOTTOM_OFFSET + Drive.CONFIG.FEED_LINES * 20 + Report.CONFIG.CARD.FEED_GAP)
	)
	hitCard.Size = UDim2.fromOffset(Report.CONFIG.CARD.WIDTH, Report.CONFIG.CARD.HEIGHT)
	hitCard.ZIndex = Report.CONFIG.CARD.Z_INDEX
	hitCard.Visible = false
	hitCard.Parent = screen

	-- THE SHOP (task 178, two columns since task 196). Karen: *"Hunting house where inside can shop
	-- things"*, and 2026-10-15: *"side menu with click and then shows in right side image and
	-- explanation what is that"*. Centred, and AS BIG AS THE SCREEN ALLOWS between the panel's own
	-- bounds -- 640 px on a monitor, 376 on a 400 px phone -- which is `ShopPanel.panelSize()`, the
	-- panel's own pure arithmetic. Empty and hidden until `ShopPanel.start` fills it. This file
	-- creates the box from that one number and writes nothing inside it; after `build` the panel is
	-- the only writer of its `Visible` AND of its `Size`, because the size now follows the screen.
	local shop = Instance.new("Frame")
	shop.Name = "ShopPanel"
	shop.BackgroundColor3 = ShopPanel.LOOK.PANEL
	shop.BackgroundTransparency = 0
	shop.BorderSizePixel = 0
	shop.AnchorPoint = Vector2.new(0.5, 0.5)
	shop.Position = UDim2.fromScale(0.5, 0.5)
	shop.Size = ShopPanel.panelSize()
	shop.ZIndex = Shop.CONFIG.PANEL.Z_INDEX
	shop.Visible = false
	shop.Parent = screen

	-- THE TRUCK PADS' SIZE DIALOG (task 182). Karen: *"you come to truck back rectangle and can click
	-- and select how many players"*. Centred, 300 wide so it fits the 400 px phone
	-- `hud_clarity.spec` measures, empty and hidden until `PadPanel.start` fills it. This file
	-- creates the box and writes nothing inside it, and after `build` it does not write the `Visible`
	-- either.
	--
	-- THE RECTANGLE COMES FROM THE PANEL AND NOT FROM A SECOND READER OF `Lobby.CONFIG`, which is
	-- `ShopPanel.panelSize`'s own arrangement: ONE function decides both the rows and the box.
	local padDialog = Instance.new("Frame")
	padDialog.Name = "PadPanel"
	padDialog.BackgroundColor3 = PadPanel.LOOK.PANEL_COLOR
	padDialog.BackgroundTransparency = 0
	padDialog.BorderSizePixel = 0
	padDialog.AnchorPoint = Vector2.new(0.5, 0.5)
	padDialog.Position = UDim2.fromScale(0.5, 0.5)
	padDialog.Size = UDim2.fromOffset(PadPanel.widthFor(), PadPanel.heightFor())
	padDialog.ZIndex = PadPanel.zIndex()
	padDialog.Visible = false
	padDialog.Parent = screen

	-- ...AND THE LOADING BANNER (task 197). KAREN, 2026-10-15: *"we need clear message that game is
	-- loading once clicked 1/1 or other now is delay"*. The same division as the dialog above it:
	-- this file creates the box, `Hud.PadPanel` fills it and owns its `Visible`, and the two can never
	-- be up together. FULL WIDTH less a margin, capped inside the panel so a wide screen gets a
	-- banner rather than a letterbox -- a SCALE, so nothing has to re-measure on a resize.
	local padLeaving = Instance.new("Frame")
	padLeaving.Name = "PadLeaving"
	padLeaving.BackgroundColor3 = PadPanel.LOOK.LEAVING_COLOR
	padLeaving.BackgroundTransparency = 0
	padLeaving.BorderSizePixel = 0
	padLeaving.AnchorPoint = Vector2.new(0.5, 0.5)
	padLeaving.Position = PadPanel.leavingPosition()
	padLeaving.Size = PadPanel.leavingSize()
	padLeaving.ZIndex = PadPanel.leavingZIndex()
	padLeaving.Visible = false
	padLeaving.Parent = screen

	-- THE MAP (task 155). Karen: *"small map in left or right corner circle like is on another
	-- games"* and *"a map when click M"*. Two frames and a button, created empty and filled by
	-- `MapUi` -- the same division the compass and the report panel already have.
	--
	-- THE ROUND ONE IS A SQUARE FRAME WITH A `UICorner` OF HALF ITS SIDE, which is how a circle is
	-- drawn in Roblox GUI without an uploaded image. `ClipsDescendants` is what keeps the road
	-- inside it; whether the engine clips to the ROUNDED rect or to the square is the one thing an
	-- Architect run could not verify, so screenshot 1 of this task is the check (design section 17).
	local miniMap = Instance.new("Frame")
	miniMap.Name = "MiniMap"
	miniMap.BackgroundColor3 = MapUi.CONFIG.BACKGROUND
	miniMap.BackgroundTransparency = MapUi.CONFIG.MINIMAP_TRANSPARENCY
	miniMap.BorderSizePixel = 0
	miniMap.AnchorPoint = Vector2.new(1, 0)
	miniMap.Position = UDim2.new(1, -MapUi.CONFIG.MINIMAP_MARGIN, 0, MapUi.CONFIG.MINIMAP_TOP)
	miniMap.Size = UDim2.fromOffset(MapUi.CONFIG.MINIMAP_DIAMETER_PX, MapUi.CONFIG.MINIMAP_DIAMETER_PX)
	miniMap.ZIndex = MapUi.CONFIG.Z_INDEX
	miniMap.ClipsDescendants = true
	miniMap.Visible = false
	local miniCorner = Instance.new("UICorner")
	miniCorner.CornerRadius = UDim.new(0.5, 0)
	miniCorner.Parent = miniMap
	local miniRim = Instance.new("UIStroke")
	miniRim.Thickness = MapUi.CONFIG.RIM_THICKNESS
	miniRim.Color = MapUi.CONFIG.RIM_COLOR
	miniRim.Transparency = 0.25
	miniRim.Parent = miniMap
	miniMap.Parent = screen

	-- THE FULL MAP, top-anchored at the same line as the minimap so it clears the compass above it
	-- and the ammo readout below it at every viewport. Its size is written by `MapUi` from the
	-- world's own span -- a wide, shallow world gets a wide, shallow panel -- so the offset here is
	-- only what it starts at.
	local fullMap = Instance.new("Frame")
	fullMap.Name = "FullMap"
	fullMap.BackgroundColor3 = MapUi.CONFIG.BACKGROUND
	fullMap.BackgroundTransparency = MapUi.CONFIG.PANEL_TRANSPARENCY
	fullMap.BorderSizePixel = 0
	fullMap.AnchorPoint = Vector2.new(0.5, 0)
	fullMap.Position = UDim2.new(0.5, 0, 0, MapUi.CONFIG.FULL_TOP)
	fullMap.Size = UDim2.fromOffset(MapUi.CONFIG.FULL_MAX_WIDTH_PX, MapUi.CONFIG.FULL_MAX_HEIGHT_PX)
	fullMap.ZIndex = MapUi.CONFIG.Z_INDEX
	fullMap.Visible = false
	local fullRim = Instance.new("UIStroke")
	fullRim.Thickness = 1
	fullRim.Color = MapUi.CONFIG.RIM_COLOR
	fullRim.Transparency = 0.4
	fullRim.Parent = fullMap
	fullMap.Parent = screen

	-- THE MAP'S LEGEND (task 165), a frame of the map's inside the map's own panel: created here
	-- with everything else and filled by `MapUi.legendRows` -- the division the two map frames, the
	-- compass strip and the report panel all already have.
	local legend = Instance.new("Frame")
	legend.Name = "MapLegend"
	legend.BackgroundTransparency = 1
	legend.AnchorPoint = Vector2.new(1, 1)
	legend.Size = UDim2.fromOffset(MapUi.CONFIG.LEGEND_WIDTH_PX, MapUi.CONFIG.LEGEND_HEIGHT_PX)
	legend.ZIndex = MapUi.CONFIG.Z_INDEX + 1
	legend.Visible = false
	legend.Parent = fullMap

	-- ---------------------------------------------------------------- task 165: the objective line
	--
	-- THE TOP LINE OF THE SCREEN, AND THE FIRST THING READ. Karen, 2026-10-12: *"we need to improve
	-- design that it will be clear to understand what happening"*. Everything else in this Hud is a
	-- FACT; this is the only INSTRUCTION, so it is the biggest text in the band and it is at the top
	-- of it (`docs/design/hud-clarity.md` section 3).
	--
	-- Created empty. `Objective` is the one writer of its text, its size and its `Visible`.
	local objective = Instance.new("TextLabel")
	objective.Name = "ObjectiveLine"
	objective.BackgroundTransparency = 1
	objective.Font = Enum.Font.Code
	objective.TextSize = Objective.CONFIG.TEXT_SIZE
	objective.TextColor3 = Objective.CONFIG.TEXT_COLOR
	objective.TextXAlignment = Enum.TextXAlignment.Center
	-- FULL WIDTH LESS A MARGIN, IN SCALE, so a 400 px phone gets 368 px of sentence and a 1080p
	-- screen gets 1888 -- the one thing a fixed `fromOffset` width could not do, and the reason
	-- `Objective.lineRect` is pure and asserted at three viewports.
	objective.AnchorPoint = Vector2.new(0.5, 0)
	objective.Position = UDim2.new(0.5, 0, 0, Objective.CONFIG.TOP)
	objective.Size = UDim2.new(1, -2 * Objective.CONFIG.SIDE_MARGIN, 0, Objective.CONFIG.HEIGHT)
	objective.ZIndex = Objective.CONFIG.Z_INDEX
	objective.Text = ""
	objective.Visible = false
	local objectiveStroke = Instance.new("UIStroke")
	objectiveStroke.Thickness = Objective.CONFIG.TEXT_STROKE
	objectiveStroke.Color = Color3.new(0, 0, 0)
	objectiveStroke.Parent = objective
	objective.Parent = screen

	-- ...AND THE WAYPOINT: a chevron over the world, and its word with the distance under it.
	--
	-- A ROTATED SQUARE, WHICH IS A CHEVRON WITH NO ASSET -- the hit marker's own technique. Small on
	-- purpose: theHunter: Call of the Wild's players ask for theirs to be smaller (*"massive and
	-- orange"*), and this one has a whole screen to cross.
	--
	-- UNDER THE FURNITURE AND OVER THE WORLD (`MARK_Z_INDEX` 5): a mark that travels the screen must
	-- pass BEHIND the compass and the map rather than scribble on them.
	local waypoint = Instance.new("Frame")
	waypoint.Name = "Waypoint"
	waypoint.AnchorPoint = Vector2.new(0.5, 0.5)
	waypoint.Size = UDim2.fromOffset(Objective.CONFIG.MARK_PX, Objective.CONFIG.MARK_PX)
	waypoint.Position = UDim2.fromScale(0.5, 0.5)
	waypoint.BackgroundColor3 = Objective.CONFIG.MARK_COLOR
	waypoint.BorderSizePixel = 0
	waypoint.Rotation = 45
	waypoint.ZIndex = Objective.CONFIG.MARK_Z_INDEX
	waypoint.Visible = false
	local waypointStroke = Instance.new("UIStroke")
	waypointStroke.Thickness = 1
	waypointStroke.Color = Color3.new(0, 0, 0)
	waypointStroke.Parent = waypoint
	waypoint.Parent = screen

	-- THE WORD AND THE DISTANCE, A SIBLING AND NOT A CHILD. A child would inherit the chevron's
	-- 45-degree `Rotation` and read at an angle, which is the kind of thing only a screenshot finds.
	local waypointLabel = Instance.new("TextLabel")
	waypointLabel.Name = "WaypointWord"
	waypointLabel.BackgroundTransparency = 1
	waypointLabel.Font = Enum.Font.Code
	waypointLabel.TextSize = Objective.CONFIG.MARK_LABEL_SIZE
	waypointLabel.TextColor3 = Objective.CONFIG.MARK_COLOR
	waypointLabel.AnchorPoint = Vector2.new(0.5, 0)
	waypointLabel.Position = UDim2.fromScale(0.5, 0.5)
	waypointLabel.Size = UDim2.fromOffset(140, Objective.CONFIG.MARK_LABEL_SIZE + 4)
	waypointLabel.ZIndex = Objective.CONFIG.MARK_Z_INDEX
	waypointLabel.Text = ""
	waypointLabel.Visible = false
	local waypointWordStroke = Instance.new("UIStroke")
	waypointWordStroke.Thickness = 1
	waypointWordStroke.Color = Color3.new(0, 0, 0)
	waypointWordStroke.Parent = waypointLabel
	waypointLabel.Parent = screen

	-- ...AND THE BUTTON RAIL, right edge, under the minimap. Karen: *"could be buttons on the side
	-- for M - map ect"*. Created empty: `Rail` builds the buttons inside it and is the one writer of
	-- every one of them. Its `Position` is rewritten by `MapUi.applyLayout`, because the rail hangs
	-- below the minimap and the minimap's RENDERED diameter is 150 on a screen and 96 on a phone.
	local rail = Instance.new("Frame")
	rail.Name = "Rail"
	rail.BackgroundTransparency = 1
	rail.AnchorPoint = Vector2.new(1, 0)
	rail.Position =
		UDim2.new(1, -Rail.CONFIG.MARGIN, 0, Rail.topFor(MapUi.CONFIG.MINIMAP_DIAMETER_PX, MapUi.CONFIG.MINIMAP_TOP))
	rail.Size = UDim2.fromOffset(Rail.CONFIG.BUTTON_PX, Rail.heightFor(#Rail.BUTTONS))
	rail.ZIndex = Rail.CONFIG.Z_INDEX
	rail.Visible = false
	rail.Parent = screen

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
	hitCardFrame = hitCard
	shopFrame = shop
	padFrame = padDialog
	padLeavingFrame = padLeaving
	compassFrame = compass
	scoreTitle = title
	scoreFooter = footer
	tiedBanner = tied
	startCard = card
	startCardTitle = cardTitle
	startCardTimer = cardTimer
	miniMapFrame = miniMap
	fullMapFrame = fullMap
	mapLegendFrame = legend
	objectiveLine = objective
	waypointMark = waypoint
	waypointWord = waypointLabel
	railFrame = rail
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
	local resolvedRow = row or Weapons.row(state.weapon)
	local glyphs = ""
	if resolvedRow ~= nil and resolvedRow.READOUT == "magazine" then
		-- A MAGAZINE RIFLE SHOWS ROUNDS LEFT, NOT ONE GLYPH PER CHAMBER (task 142). Karen asked for
		-- *"3 shells"* in the magazine and the readout she would check it against is `3/3`; three
		-- bracketed asterisks is what a THREE-BARRELLED SHOTGUN would print, which is not this gun.
		local live = 0
		for _, chamber in ipairs(state.barrels) do
			if chamber == "Live" then
				live += 1
			end
		end
		glyphs = string.format("%d/%d", live, resolvedRow.MAGAZINE or #state.barrels)
	else
		for index, barrel in ipairs(state.barrels) do
			local glyph = if barrel == "Live" then "*" elseif barrel == "Spent" then "x" else "-"
			glyphs ..= if index == state.selected then "[" .. glyph .. "]" else glyph
		end
	end
	local busyMark = if state.busyFor > 0 then " R" else ""
	-- Shells are carried per type, so the count shown is the pocket the next load comes from, and
	-- the server's one-line notice ("NO BUCK") is what tells the player why X did nothing.
	local pocket = state.reserve[state.ammo] or 0
	local notice = if state.notice then " " .. state.notice else ""
	local resolved = resolvedRow
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

-- WHICH ROW IS FIRST PLACE IS NO LONGER DECIDED HERE (task 170). `Hud.firstPlaceRank` was this
-- Hud's own implementation of *"a tie at the top is not a first place"* (task 160, after ioquake3's
-- `RANK_TIED_FLAG`); from task 170 the SERVER pays a first-place bonus off the same question, so the
-- rule moved to `Drive.Rank` -- ONE implementation, two readers -- and the old function is archived
-- in backups/2026-10-13_task-170_hud-firstplacerank.txt (rule 7). Two correct pieces of code
-- disagreeing is this project's named failure mode (docs/PROJECT_CONTEXT.md).
local Rank = Drive.Rank

-- ONE ROW OF THE RESULTS TABLE.
--
-- THE `TEAM` COLUMN IS GONE AND THE COINS COLUMN IS WHAT IT PAID FOR (task 170). With a
-- `-- HUNTERS --` heading over the list, printing SHOOTER / DRIVER on every row under it says one
-- fact twice -- and the panel had no spare width: `SCORE_PANEL_WIDTH` is already 480 against the
-- 400-px screen `tests/client/hud_clarity.spec.luau` measures, so widening it would make an existing
-- problem worse. 41 characters plus badge and star, against today's 42.
--
-- `rank` RESTARTS AT 1 INSIDE EACH RANKING, because that is what "two first places" means.
local function scoreRowText(rank: number, row, first: boolean?): string
	-- `left` is a fact the board carries; a leaver's row stays on this drive's screen (drive design
	-- section 4.4), and a trailing "*" is how the reader knows why they are not in the next drive.
	-- A leaver is also NOT PAID (`Economy.Coins.forDrive`), so his coins column reads `--`, which is
	-- the same symbol an unknown balance uses and means the same thing here: no number for him.
	local gone = if row.left then " *" else ""
	-- AFTER THE COINS AND BEFORE THE LEAVER'S STAR, so the badge sits against the numbers it was
	-- earned with and a first-placed leaver still reads as one.
	local badge = if first then "  " .. Drive.CONFIG.SCORE_FIRST_BADGE else ""
	-- WHAT THIS DRIVE PAID HIM, not his balance: the balance is on the bar, in every phase, and the
	-- results table is about THIS drive. Absent (the flag off, or no profile) reads `--` and never
	-- `0` -- `0` would be an assertion that the drive paid him nothing.
	local coins = if type(row.earned) == "number"
		then string.format(Drive.CONFIG.SCORE_EARNED_FORMAT, row.earned)
		else Drive.CONFIG.SCORE_COINS_UNKNOWN
	return string.format(
		"%-2d %-16s %5d %7d %7s%s%s",
		rank,
		string.sub(tostring(row.name or "?"), 1, 16),
		row.kills,
		row.points,
		coins,
		badge,
		gone
	)
end

export type ScoreLine = { text: string, heading: boolean, mine: boolean }

-- THE WHOLE BODY OF THE RESULTS TABLE, AS DATA (task 170). Karen, 2026-10-12: separate rankings for
-- hunters and beaters. PURE and exported for the reason every other string on this panel is -- a
-- drive is 600 seconds long, so no CLIENT suite ever reaches the `Scoring` phase, and the only way
-- to assert what the panel says is to hand this the snapshot the wire would.
--
-- TWO RANKINGS, TWO FIRST PLACES, ONE RULE. `Drive.Rank.splitByTeam` cuts the board's own TOTAL
-- order into hunters, beaters and the rows that are in neither, and `Rank.firstPlaceRank` is asked
-- ONCE PER RANKING -- the same function the server asked to pay the two bonuses, so a badge and a
-- bonus can never land on different rows.
--
-- THE `OTHERS` HEADING IS DRAWN ONLY WHEN THAT LIST HAS A ROW IN IT, which is the rule
-- `Match.quarryLines` already applies to its own POINTS label: *"THE WORD ONLY WHEN THERE IS A
-- NUMBER UNDER IT"*. `others` gets no first place either, because it is not a ranking -- it is the
-- people who were not in one (a player who joined outside `Assigning`/`Running` has no team yet).
--
-- IT TRUNCATES BY DROPPING TRAILING ROWS AND NEVER A HEADING: a list cut short is still readable,
-- a list whose heading was dropped tells the reader the wrong ranking.
function Hud.scorePanelLines(snapshot, myUserId: number?): { ScoreLine }
	local out: { ScoreLine } = {}
	local rows = if snapshot then snapshot.rows else nil
	local hunters, beaters, others = Rank.splitByTeam(rows)
	local budget = Drive.CONFIG.SCORE_ROWS_MAX

	-- `ranked` IS FALSE FOR `others` AND THAT IS NOT A DETAIL: the server pays a first-place bonus to
	-- the top HUNTER and the top BEATER only (`Economy.Coins.forDrive` asks `Rank.firstPlaceUserId` of
	-- those two lists and of no third), so a badge over `others` would be a winner the game never
	-- paid. Asking the rule of every list is exactly how the two sides came to disagree.
	local function section(heading: string, list, ranked: boolean)
		if #list == 0 or #out >= budget then
			return
		end
		table.insert(out, { text = heading, heading = true, mine = false })
		local firstRank = if ranked then Rank.firstPlaceRank(list) else nil
		for index, row in ipairs(list) do
			if #out >= budget then
				return
			end
			table.insert(out, {
				text = scoreRowText(index, row, index == firstRank),
				heading = false,
				mine = myUserId ~= nil and (row :: any).userId == myUserId,
			})
		end
	end

	section(Drive.CONFIG.SCORE_HUNTERS_HEADING, hunters, true)
	section(Drive.CONFIG.SCORE_BEATERS_HEADING, beaters, true)
	section(Drive.CONFIG.SCORE_OTHERS_HEADING, others, false)
	return out
end

-- THE LOCAL PLAYER'S BALANCE, for the drive bar, in every phase (the dispatch: the balance on the
-- HUD). PURE and exported for the same reason as everything else on this screen.
--
-- `""` WHENEVER THIS BUILD HAS NO MONEY IN IT, and `snapshot.coinsOn` is the one fact that says so.
-- ROUND 1 OF THE GATE FOUND THIS THE HARD WAY and the old comment here was simply wrong: it said
-- `""` happened when the player "has no row at all", *"which is the whole of today's game with the
-- `COINS` flag off"*. He always has a row -- `Match.snapshot` builds one per `Score.leaderboard`
-- entry and `watchPlayer` joins every player to the board -- so with the flag off every bar in the
-- game gained a dead `COINS --`, and OFF was not the game before task 170 at all.
--
-- THE TWO ABSENCES ARE DIFFERENT QUESTIONS AND THE ROWS CANNOT TELL THEM APART, which is why the
-- answer is on the snapshot and not inferred here: `row.coins` is absent both when there IS no money
-- and when this player's profile did not open. `coinsOn` separates them --
--   no `coinsOn`            -> `""`. There is no money in this build; draw nothing.
--   `coinsOn`, no `coins`   -> `COINS --`. There IS money and his balance is UNKNOWN, which is a
--                              real thing to tell him and is not zero.
--   `coinsOn` and a number  -> `COINS 1240`.
function Hud.coinsText(snapshot, userId: number?): string
	local rows = if snapshot then snapshot.rows else nil
	-- ONE SOURCE, AND IT IS THE SERVER'S: this reads no flag of its own. A Hud that read `Flags` would
	-- be a second answer to "is there money", and the client's copy of a server rule is the thing
	-- `ReplicatedStorage.Drive`'s header exists to prevent.
	if rows == nil or userId == nil or snapshot.coinsOn ~= true then
		return ""
	end
	for _, row in ipairs(rows) do
		if row.userId == userId then
			local value = row.coins
			if type(value) == "number" then
				return string.format("%s %d", Drive.CONFIG.SCORE_COINS_LABEL, value)
			end
			return string.format("%s %s", Drive.CONFIG.SCORE_COINS_LABEL, Drive.CONFIG.SCORE_COINS_UNKNOWN)
		end
	end
	return ""
end

-- WHETHER THE SCORE PANEL SHOWS -- which since task 159 is KAREN'S RESULTS TABLE, up for the whole of
-- `Scoring` over the results scene. The one extra clause: NOT WHILE THE REPORT IS OPEN. Two centred
-- panels at once is two panels nobody can read, and the report is the one the player asked for by
-- pressing Tab -- which since task 159 is the ONLY way it opens (`Report.CONFIG`'s
-- `AUTO_OPEN_AT_DRIVE_END`, false, with the screenshot that says why). Before that it opened itself
-- when a drive closed, and this clause then hid the results table behind it every single time. Pure and exported for the same reason the renderer below is -- a drive is 600
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
		-- THE WORDING IS THE CONTRACT'S, not this renderer's (task 159): Karen asked for a "results
		-- table", and `Drive.CONFIG` is where every word this Hud draws is written down.
		scoreTitle.Text = string.format(Drive.CONFIG.SCORE_TITLE_FORMAT, snapshot.driveNumber)
	end
	local me = Players.LocalPlayer.UserId
	-- THE BODY IS DECIDED BY ONE PURE CALL AND THIS LOOP DECIDES NOTHING (task 170): it writes
	-- `.Text`, `.TextColor3`, `.TextTransparency` and `.Visible`, and the rankings, the ranks, the
	-- badges and the headings are all `Hud.scorePanelLines`'s -- which is also the only way a spec can
	-- assert them, since no client suite reaches `Scoring`.
	local lines = Hud.scorePanelLines(snapshot, me)
	for index, label in ipairs(scoreLines) do
		local entry = lines[index]
		if entry then
			label.Text = entry.text
			-- A HEADING RECEDES exactly as the column header does, and for the same reason: it is a
			-- label for the rows under it, not one of them.
			label.TextTransparency = if entry.heading then Drive.CONFIG.SCORE_HEADER_TRANSPARENCY else 0
			label.TextColor3 = if entry.mine then Drive.CONFIG.SCORE_HIGHLIGHT_COLOR else Drive.CONFIG.TEXT_COLOR
			label.Visible = true
		else
			label.Text = ""
			label.Visible = false
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

-- ---------------------------------------------------------------- the start card (task 158)
--
-- KAREN'S WORDS FOR THE TWO SIDES, and this is the one place they are said. The drive bar still says
-- SHOOTER / DRIVER, which are the TEAM names in `Match.CONFIG` and on the scoreboard; her design doc
-- and every message she sends say hunter and beater. The card is the thing she asked for in those
-- words, so it uses them -- and which vocabulary the whole Hud should speak is a Karen decision, not
-- one to take quietly in a renderer (TASKS.md row 158a).
function Hud.roleWord(team: string?): string
	if team == "Shooters" then
		return "HUNTER"
	elseif team == "Drivers" then
		return "BEATER"
	end
	return ""
end

-- WHETHER THE CARD SHOWS: the start of a drive is the `Assigning` phase and nothing else. Pure and
-- exported for the score panel's own reason -- a drive is 600 seconds long, so no harness run sees
-- the real transition and a spec has to be able to hand this the snapshot the wire would.
--
-- NOT WHILE THE REPORT IS OPEN, the same clause the score panel has: two panels at once is two
-- panels nobody reads. Since task 159 the report opens on `Tab` and nowhere else, so this is the
-- player's own choice rather than something that happened to him seconds before the drive started.
function Hud.startCardVisible(snapshot, reportOpen: boolean?): boolean
	return snapshot ~= nil and snapshot.phase == "Assigning" and reportOpen ~= true
end

-- THE CARD'S BODY, as pure text: your role, then what may be shot in the server's own words.
-- `snapshot.quarry` is the rule and this does not interpret it -- a client that decided for itself
-- what was legal would be a second answer to one rule.
function Hud.startCardLines(snapshot, team: string?): { string }
	local lines = {}
	local role = Hud.roleWord(team)
	if role ~= "" then
		table.insert(lines, "YOU ARE A " .. role)
	end
	for _, line in ipairs((snapshot and snapshot.quarry) or {}) do
		table.insert(lines, line)
	end
	return lines
end

-- THE ONE LINE THAT COUNTS DOWN, in the words of the role it is for. Karen: *"Get to your stand:
-- 10..."* for a hunter, *"Drive starts in 10..."* for a beater -- and it is the SAME ten seconds,
-- because both are this phase's own deadline.
function Hud.startCardTimerFor(team: string?, secondsLeft: number?): string
	local label = if team == "Drivers"
		then Drive.CONFIG.START_CARD_BEATER_TIMER
		else Drive.CONFIG.START_CARD_HUNTER_TIMER
	return string.format("%s  %d", label, math.max(0, math.ceil(secondsLeft or 0)))
end

-- THE ONE WRITER of the start card. Public for the same reason `Hud.renderScore` is.
function Hud.renderStartCard(snapshot, team: string?, secondsLeft: number?)
	local cardFrame = startCard
	if not cardFrame then
		return
	end
	local show = Hud.startCardVisible(snapshot, ReportPanel.isOpen())
	cardFrame.Visible = show
	if not show then
		-- Cleared, not just hidden: the next drive must not flash the last one's card for a frame.
		if startCardTitle then
			startCardTitle.Text = ""
		end
		if startCardTimer then
			startCardTimer.Text = ""
		end
		for _, line in ipairs(startCardLines) do
			line.Text = ""
			line.Visible = false
		end
		return
	end
	if startCardTitle then
		startCardTitle.Text = string.format("DRIVE %d   %s", snapshot.driveNumber, Drive.CONFIG.START_CARD_HEADING)
	end
	local lines = Hud.startCardLines(snapshot, team)
	for index, label in ipairs(startCardLines) do
		local text = lines[index]
		label.Text = text or ""
		label.Visible = text ~= nil
	end
	if startCardTimer then
		startCardTimer.Text = Hud.startCardTimerFor(team, secondsLeft)
	end
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
	local left = if MatchSystem then MatchSystem.secondsLeft() else 0
	Hud.renderScore(snapshot, left)
	Hud.renderTied(MatchSystem ~= nil and MatchSystem.isTied())
	-- IN THE SAME PASS, from the same snapshot and the same clock as the bar and the board: three
	-- things that could disagree about which phase it is, drawn from one read (task 158).
	Hud.renderStartCard(snapshot, if MatchSystem then MatchSystem.myTeam() else nil, left)
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
	-- THE BALANCE, IN EVERY PHASE (task 170). Karen, 2026-10-11: *"get money"* -- and a currency you
	-- cannot see between drives is one a player cannot count. `""` with the flag off, so this bar is
	-- byte-identical to before task 170 in that state.
	local coins = Hud.coinsText(snapshot, Players.LocalPlayer.UserId)
	if coins ~= "" then
		table.insert(pieces, coins)
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
	elseif entry.kind == "signal" then
		-- THE DRIVE'S HORN DRAWS NO LINE (task 163). Its `text` is the server's word for WHICH
		-- signal it is ("start" / "end") and not something to read: `Hud.Sound.driveSignal` answers
		-- it, and the phase entry beside it ("Drive on", "Drive over") is what the feed says in
		-- words. Without this the feed would print the bare word "start".
		return nil
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
-- raise's own easing is what decides when the eye is at the glass. (This had the RETICLE's header
-- over it for one round -- a comment describing the function below the one it sat on.)
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
local lastScopeFov, lastScopeX, lastScopeY, lastScopeSpec = -1, -1, -1, nil :: any
function Hud.layoutScope(overlay: Frame, optics: any, fovDeg: number)
	local camera = Workspace.CurrentCamera
	local spec = if optics ~= nil then optics.eyepiece else nil
	local viewport = if camera then camera.ViewportSize else Vector2.zero
	if spec == nil or viewport.Y <= 0 then
		return
	end
	-- THE WIDTH IS IN THE KEY TOO (the Reviewer's note, round 1): both the diameter clamp and the
	-- stroke's thickness are computed from X as well as Y, so a width-only resize must re-lay-out.
	if
		math.abs(fovDeg - lastScopeFov) < 1e-3
		and viewport.X == lastScopeX
		and viewport.Y == lastScopeY
		and spec == lastScopeSpec
	then
		return
	end
	lastScopeFov, lastScopeX, lastScopeY, lastScopeSpec = fovDeg, viewport.X, viewport.Y, spec
	-- THE CLAMP IS ON THE GLASS, NOT ON THE WHOLE CIRCLE (task 146, the Reviewer's finding 1). What
	-- must never run off the screen is the part you LOOK THROUGH -- a lens wider than the viewport
	-- would put the reticle's degrees somewhere off the edge and make the sight picture a lie. The
	-- SCOPE BODY around it may run off, and in Karen's own reference frame it does: the tube is cut
	-- by the top and bottom of the picture rather than floating inside it. Before this task the two
	-- were the same clamp, because the rim was a 0.45-degree hairline and the difference was a pixel.
	local rimPx = math.max(1, Hud.reticleDegToPx(spec.rimThickDeg, fovDeg, viewport.Y))
	local diameter = math.max(
		2,
		math.min(Hud.reticleDegToPx(spec.diameterDeg, fovDeg, viewport.Y), math.min(viewport.X, viewport.Y) + 2 * rimPx)
	)
	local mask = overlay:FindFirstChild("Mask")
	if mask and mask:IsA("Frame") then
		mask.Size = UDim2.fromOffset(diameter, diameter)
		local edge = mask:FindFirstChild("Edge")
		if edge and edge:IsA("UIStroke") then
			edge.Color = spec.maskColor
			-- ...AND IT IS NOT NECESSARILY OPAQUE (task 146). Karen's reference keeps the forest
			-- outside the scope body visible, just dark. `maskTransparency` nil is task 141's solid
			-- black, so every scope written before this task is unchanged.
			edge.Transparency = spec.maskTransparency or 0
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
-- The per-frame cost is two `FindFirstChild`s on the ScreenGui plus three camera reads and a
-- boolean; `layoutScope` and `layoutReticle` both return immediately unless the field of view, the
-- viewport or the spec actually moved. (The two lookups are counted here because this file throttles
-- its own staleness tick for exactly that kind of cost.)
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
		--
		-- `compassFrame.Visible` therefore has TWO writers and that is deliberate (rule 3): both are
		-- in this file -- `Compass.start`'s single switch-on at boot, and this, per frame -- and
		-- `Compass` itself never touches it. It also self-heals: a strip switched on while the mask
		-- is in is hidden again on the next frame.
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
		-- THE MAP IS HIDDEN TOO, AND BY A DIFFERENT MECHANISM ON PURPOSE (task 155, design section
		-- 3.3). The compass above needs the `compassHiddenByScope` flag because this file is a
		-- SECOND writer of its `Visible` and has to put back exactly what it hid. The map does not
		-- have that problem: this line STATES A NEED and `MapUi` performs the single write, which is
		-- this repo's own `Camera.Cursor.requestFree` pattern (borrowed once already by
		-- `Input.requestHold`). So `MapUi` stays the one writer of its own frames and nothing here
		-- has to remember what it did.
		--
		-- WHY HIDE IT AT ALL, when the minimap is in the corner and the eyepiece is in the middle:
		-- at 1080p the disc is well clear of the glass, but at 400 x 800 the eyepiece spans y
		-- 200..600 and the disc's bottom edge is at 204 -- four pixels inside. A minimap with its
		-- corner blacked out is worse than no minimap, and "is it outside the circle" is not
		-- provable at every viewport.
		MapUi.setSuppressed(scoped)
		-- ...AND THE OBJECTIVE LINE, THE WAYPOINT AND THE RAIL, on the same line and by the same
		-- mechanism (task 165). All three STATE A NEED and each module performs its own single write,
		-- so none of them needs the compass's `compassHiddenByScope` remember-what-I-hid arrangement.
		--
		-- WHY THE RAIL HIDES AT ALL, when it is at the right edge and the eyepiece is in the middle:
		-- the same measurement that put the map behind the mask -- at 400 x 800 the eyepiece spans
		-- y 200..600 and the rail runs 244..460, so it is INSIDE the glass on a phone. A sight picture
		-- with four buttons floating in it is the picture task 141 exists to prevent.
		Objective.setSuppressed(scoped)
		Rail.setSuppressed(scoped)
	end
	if reticle ~= nil then
		local visible = Hud.reticleVisible(mode, optics, blend)
		reticle.Visible = visible
		if visible then
			Hud.layoutReticle(reticle, optics, liveFov)
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
-- `optics` IS THE WHOLE SCOPE BLOCK SINCE TASK 146, not just `optics.reticle`: Karen's cross runs
-- from one side of the GLASS to the other, so the arms are a function of the eyepiece and the two
-- cannot be given separately without letting them disagree.
function Hud.layoutReticle(reticle: Frame, optics: any, fovDeg: number)
	local camera = Workspace.CurrentCamera
	local viewportY = if camera then camera.ViewportSize.Y else 0
	local spec = if optics ~= nil then optics.reticle else nil
	local eyepiece = if optics ~= nil then optics.eyepiece else nil
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

	-- A RETICLE DRAWS WHAT ITS DATA CARRIES (task 146). Karen's reference has no ring around the
	-- centre, so her scope leaves `ringOuterDeg` out and this element simply is not there. The same
	-- rule the dot has followed since task 142, applied to the rest of the furniture.
	local ring = reticle:FindFirstChild("Ring")
	if ring and ring:IsA("Frame") then
		ring.Visible = spec.ringOuterDeg ~= nil and spec.ringOuterDeg > 0
		if ring.Visible then
			local outer = math.max(2, px(spec.ringOuterDeg))
			ring.Size = UDim2.fromOffset(outer, outer)
			local edge = ring:FindFirstChild("Edge")
			if edge and edge:IsA("UIStroke") then
				edge.Thickness = math.max(1, px(spec.ringThickDeg or 0.1))
				edge.Color = spec.color
			end
		end
	end

	-- Each bar hangs from the centre: a gap, then its own length, on its own side.
	local function place(
		name: string,
		vertical: boolean,
		sign: number,
		thickDeg: number?,
		armDeg: number?,
		gapDeg: number?
	)
		local bar = reticle:FindFirstChild(name)
		if not (bar and bar:IsA("Frame")) then
			return
		end
		if thickDeg == nil or thickDeg <= 0 or armDeg == nil or armDeg <= 0 then
			bar.Visible = false -- the data does not carry this element (task 146)
			return
		end
		bar.Visible = true
		local thick = math.max(1, px(thickDeg))
		local length = math.max(1, px(armDeg))
		local gap = px(gapDeg or 0)
		bar.BackgroundColor3 = spec.color
		if vertical then
			bar.Size = UDim2.fromOffset(thick, length)
			bar.Position = UDim2.new(0.5, 0, 0.5, sign * (gap + length / 2))
		else
			bar.Size = UDim2.fromOffset(length, thick)
			bar.Position = UDim2.new(0.5, sign * (gap + length / 2), 0.5, 0)
		end
	end

	-- EDGE TO EDGE, CUT TO THE GLASS (task 146). The eyepiece's own radius minus the tube's
	-- thickness is where the clear lens stops, so an arm of exactly that length starts at the centre
	-- and ends against the inside of the scope body -- which is Karen's reference line for line. The
	-- gap is zero, because a hair that stops short of the middle is a duplex and she asked for the
	-- other thing.
	local crossArm, crossGap = spec.crossArmDeg, spec.crossGapDeg
	if spec.spanLens then
		crossGap = 0
		-- NO EYEPIECE, NO LENS TO CUT TO -- but a reticle that asked to span one must still draw a
		-- cross rather than nothing (the Reviewer's note, round 1). Half the field of view reaches
		-- the edge of any screen, which is what "spans it" means with no glass in the way.
		crossArm = if eyepiece ~= nil
			then math.max(0.01, eyepiece.diameterDeg / 2 - (eyepiece.rimThickDeg or 0))
			else fovDeg / 2
	end
	place("CrossTop", true, -1, spec.crossThickDeg, crossArm, crossGap)
	place("CrossBottom", true, 1, spec.crossThickDeg, crossArm, crossGap)
	place("CrossLeft", false, -1, spec.crossThickDeg, crossArm, crossGap)
	place("CrossRight", false, 1, spec.crossThickDeg, crossArm, crossGap)
	-- THE POSTS START WHERE THE THIN CROSS ENDS, which is what a duplex IS: a thick bar from the
	-- edge of the view in to a point, and a hair from there to the centre. A reticle with no posts
	-- in its data has none drawn.
	local postGap = (crossGap or 0) + (crossArm or 0)
	-- THE DOT, IN THE SAME DEGREES (task 142). A weapon whose reticle carries no `dot` draws none,
	-- which is what keeps this one conversion honest for a scope that is a plain duplex.
	local function circle(name: string, deg: number?, color: Color3?, transparency: number)
		local node = reticle:FindFirstChild(name)
		if not (node and node:IsA("Frame")) then
			return
		end
		if deg == nil or deg <= 0 or color == nil then
			node.Visible = false
			return
		end
		node.Visible = true
		local size = math.max(1, px(deg))
		node.Size = UDim2.fromOffset(size, size)
		node.BackgroundColor3 = color
		node.BackgroundTransparency = transparency
	end
	-- `enabled = false` IS THE ONE LINE THAT TURNS IT OFF (task 146): Karen asked for the red dot
	-- and the reference she then sent has none, so it is a data toggle and not an argument.
	local dot = if spec.dot ~= nil and spec.dot.enabled ~= false then spec.dot else nil
	circle("DotHalo", dot and dot.haloDeg, dot and dot.haloColor, (dot and dot.haloTransparency) or 0.5)
	circle("Dot", dot and dot.deg, dot and dot.color, 0)

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
	-- ...AND THE RAIL LEARNS WHETHER THERE IS A GUN FROM THE SAME READ (task 165). One reader of the
	-- weapon state in this file; the rail is told and reads nothing. A button whose action cannot run
	-- is not drawn, which is the dispatch's "no dead buttons".
	Rail.setWeapon(state ~= nil and state.equipped == true)
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

-- WHICH BEARING THIS PLAYER'S COMPASS MARKS (task 153). PURE: the world's data and the team the
-- player is on, in; the bearing the drive marker sits at, out.
--
-- TWO DIRECTIONS, ONE FACT. `DRIVE_BEARING_DEG` is where the drive comes FROM and is what a hunter
-- watches; `PUSH_BEARING_DEG` is the way a beater walks, and the world derives the second from the
-- first so they can never disagree. A world that has said neither gets no marker at all, which is
-- what `Compass.setBearing(nil)` means and what every place but the Forest Test does.
-- IT ANSWERS THE WORD TOO (task 153 round 2, the Reviewer's blocking finding): a marker that moved
-- without its label told a beater the drive was south. nil for the label means "the compass's own
-- word", which is what a hunter and every other world get.
function Hud.driveBearing(data, team: string?): (number?, string?)
	if data == nil then
		return nil, nil
	end
	if team ~= nil and team == data.PUSH_TEAM then
		return data.PUSH_BEARING_DEG, data.PUSH_LABEL
	end
	return data.DRIVE_BEARING_DEG, nil
end

-- WHERE THE LOCAL PLAYER IS, flat, read off the engine and never cached (task 165). `MapUi`'s own
-- private `roster` reads the same state for its markers: two readers of the engine, no writer of
-- anything, and neither derives state from the other. nil means "no character yet" -- joining or
-- respawning -- and then there is no target at all, which is `MapUi.pointsFor`'s rule: *"a stale dot
-- is a lie about where somebody is"*.
function Hud.localPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character.PrimaryPart
	return if root then (root :: BasePart).Position else nil
end

-- WHAT THE COMPASS MARKER AND THE MAP ARROW POINT AT, WHICH IS THE SAME PLACE THE CHEVRON DOES
-- (task 165). PURE: the live target and the player's position in, a bearing and a word out.
--
-- THIS IS WHAT MAKES THE THREE PICTURES AGREE -- the dispatch's *"a marker that shows distance, plus
-- the minimap/compass agreeing with it"* -- while keeping EXACTLY ONE MARKER on a 360 px strip. A
-- second marker is clutter, and the dispatch forbids clutter in the same breath.
--
-- NO TARGET MEANS THE WORLD'S OWN ANSWER, UNCHANGED, which is `Hud.driveBearing`'s (where the drive
-- comes from, or the way a beater pushes). That is not a fallback, it is the right answer: a hunter
-- standing ON his stand has arrived, so the strip goes back to saying where the drive is coming
-- from, which is the thing he is actually watching.
--
-- NORTH IS +Z AND BEARINGS RUN CLOCKWISE THROUGH EAST (+X) -- `Compass.headingDeg`'s convention,
-- which was settled against a PHOTOGRAPH of four neon posts in task 129 and is written `atan2(x, z)`
-- in exactly one other place. This is the second, and `hud_clarity.spec` compares it against
-- `Compass.headingDeg` of the same vector rather than copying the expression into its own case.
function Hud.markerFor(target: any?, me: Vector3?, worldDeg: number?, worldLabel: string?): (number?, string?)
	if target == nil or me == nil then
		return worldDeg, worldLabel
	end
	local to = target.point
	local here = me :: Vector3
	local dx, dz = to.X - here.X, to.Z - here.Z
	if math.abs(dx) < 1e-6 and math.abs(dz) < 1e-6 then
		-- Standing exactly on it: a bearing to where you are is noise, so the world's answer stands.
		return worldDeg, worldLabel
	end
	return (math.deg(math.atan2(dx, dz)) + 360) % 360, target.word
end

-- THE ONE EVALUATION OF "WHAT MUST I DO, AND WHERE", AND THE ONE CALL TO EACH DRAWER (task 165).
--
-- Called once a frame from its OWN `RenderStepped` connection -- not the compass's, for the reason
-- task 141 wrote down about the scope: *"a scope that only worked in a world with a compass strip is
-- a bug waiting for the next place"*.
--
-- ONE RULE, ONE EVALUATION, THREE DRAWERS. The chevron, the compass marker and the map's target mark
-- are all written from the ONE `target` resolved here; two readers of one fact that could be handed
-- different teams is how task 153 round 2's finding (*"a marker that moved without its label told a
-- beater the drive was south"*) comes back. This function is now the only caller of
-- `Compass.setBearing` and `MapUi.setPush` after boot -- the `whenReady` closure in `Hud.start` used
-- to call both directly, and no longer does, so this REMOVES a two-writer arrangement.
--
-- `Hud.startCardVisible` IS THE ONE WRITER OF "IS A CARD UP", and it is called here with the same
-- snapshot and the same `ReportPanel.isOpen()` that `Hud.renderStartCard` calls it with. One
-- function, two callers, no second rule -- so the card and the objective line can never disagree
-- about whether a card is up, which is what lets the LINE stand down while the card says
-- `GET TO YOUR STAND` and the CHEVRON carry on (design section 5.4).
function Hud.renderObjective(CameraSystem)
	local snapshot = if matchSystem then matchSystem.get() else nil
	local phase = if snapshot then snapshot.phase else nil
	-- `Player.Team` IS THE ONE REPRESENTATION OF THE TEAM (`Match.myTeam`'s own header says so), and
	-- it is read directly when there is no match replica at all -- the Hud works with no drive,
	-- exactly as it works with no camera.
	local team = if matchSystem
		then matchSystem.myTeam()
		else (if Players.LocalPlayer.Team then Players.LocalPlayer.Team.Name else nil)
	local me = Hud.localPosition()
	-- WHAT THE LOBBY IS DOING RIGHT NOW (task 177): where the truck spot is, and how long until this
	-- player leaves for the hunt. One table per frame, built from the one definition of each -- the
	-- PART the server built, and the deadline the server wrote on this player.
	-- WHICH PAD IS ASKING THIS PLAYER, read ONCE a frame and used by three things: the dialog's
	-- visibility, the objective line standing down for it, and the camera's turn toward that pad's
	-- truck (task 197 part 2). Two reads would be two answers to one question.
	local asking = if lobbyData then lobbyData.padAsking(Players.LocalPlayer.UserId) else nil
	local lobby = if lobbyData
		then {
			spot = lobbyData.spotPosition(),
			secondsLeft = lobbyData.secondsLeft(
				Players.LocalPlayer:GetAttribute(lobbyData.LEAVE_AT_ATTRIBUTE),
				Workspace:GetServerTimeNow()
			),
			-- EVERY TRUCK PAD (task 182), so the chevron points at the NEAREST one. Four memoised
			-- part lookups and four `Position` reads -- the same order as the one subtraction
			-- `ShopPanel.setNear` below already costs this function.
			pads = lobbyData.padPositions(),
			-- ...AND WHETHER EITHER OF THE PAD'S PANELS IS UP (task 197 part 2), so the objective
			-- line can stand down for them. `asking` is the one read above and `loading` is the same
			-- attribute the banner itself is told from, so the line and the panels can never
			-- disagree about whether a panel is up.
			asking = asking,
			loading = Players.LocalPlayer:GetAttribute(lobbyData.PAD_MINE_ATTRIBUTE),
		}
		else nil
	-- IS HE AT THE SHOP COUNTER (task 178)? ONE EVALUATION, HERE, because this function is already
	-- *"THE ONE EVALUATION OF 'WHAT MUST I DO, AND WHERE', AND THE ONE CALL TO EACH DRAWER"* and it
	-- already holds both facts: where he is, and where the lobby's parts are. The panel is TOLD
	-- (`Rail.setWeapon`'s rule) and `setNear` is edge-triggered inside it, so this costs one
	-- subtraction a frame and one write per walk-in.
	ShopPanel.setNear(
		Shop.withinReach(me, if lobbyData then lobbyData.counterPosition() else nil, Shop.CONFIG.REACH_STUDS)
	)
	-- ...AND WHO OPENS IT (task 181). The shopkeeper's `ProximityPrompt` is the one way into the
	-- panel since this task took task 178's auto-open away, and it is resolved HERE for `setNear`'s
	-- own stated reason: one reader of the lobby's parts on this client, and a panel that is TOLD.
	-- `Lobby.shopPrompt()` is memoised and drops its cache with the instance, so this is a cached
	-- field read a frame and `ShopPanel.setPrompt` does nothing at all unless the prompt CHANGED.
	ShopPanel.setPrompt(if lobbyData then lobbyData.shopPrompt() else nil)
	-- ...AND ONE STEP OF THE SHOP WINDOW'S TURNING PICTURE (task 196). HERE, and not in a
	-- `RenderStepped` of its own, for this function's own stated reason: it is *"THE ONE EVALUATION"*
	-- and a second per-frame loop on this client would be a second owner of the frame. It returns
	-- immediately while the panel is shut, which is every frame of a hunt.
	ShopPanel.step()
	-- ...AND THE RAIL GETS OUT OF THE SHOP'S WAY ON A PHONE (task 196 part 3f, corrected in review
	-- round 1). On a 400-wide screen the panel is the whole screen and the MAP / REPORT column sits
	-- ON TOP of it.
	--
	-- IT STATES A NEED; `Rail` DOES THE WRITING. Part 3f wrote `railFrame.Visible` here, every
	-- frame, which made a second writer of another owner's frame -- and because it wrote `true`
	-- whenever the shop was shut, the first frame after a sight picture went up turned four buttons
	-- back on inside the eyepiece, undoing `Rail.setSuppressed` and beating `SHOW_ON_DESKTOP` with
	-- it. `Rail.setCovered` is edge-triggered, so this costs one comparison a frame and
	-- `Rail.applyVisibility` stays the one place `Visible` is written.
	local screen = Workspace.CurrentCamera
	Rail.setCovered(screen ~= nil and ShopPanel.hidesRail(screen.ViewportSize.X))
	-- ...AND WHETHER A TRUCK PAD IS ASKING HIM HOW MANY (task 182). ONE server-measured fact, read
	-- here for `setNear`'s own stated reason -- this function is already *"THE ONE EVALUATION"* --
	-- and the panel is TOLD. `setAsk` is edge-triggered inside it, so this costs four memoised part
	-- lookups and eight cached attribute reads a frame, and one write per walk-on. A world with no
	-- lobby asks nobody anything. (The REMOTE is resolved once in `Hud.whenReady`, not here: it
	-- waits, and nothing on a render tick may.)
	PadPanel.setAsk(asking)
	-- ...AND THE VIEW TURNS TO FACE THAT PAD'S TRUCK (task 197 part 2). The Director, after looking
	-- at the first frames: the truck is SOUTH of the pad and a player arrives facing NORTH, so the
	-- engine start, the headlights and the smoke all happened behind her.
	--
	-- **IT ASKS; THE CAMERA DECIDES.** `Camera.faceTowards` is a request of exactly the shape
	-- `Camera.lookAt` and `Cursor.requestFree` are -- it eases the turn over `FACE_TURN_SECONDS` and
	-- drops it the instant a mouse delta arrives -- and `Rig.apply` is still the one writer of
	-- `workspace.CurrentCamera`. Nothing here touches an angle.
	--
	-- ONCE PER WALK-ON, on the edge, through `facedPad`: a request every frame would be a camera
	-- that could never be turned away from.
	--
	-- IT IS THE *DIALOG'S* EDGE AND NOT THE PICK'S, and the limit is honest: the client is told which
	-- pad only while that pad is ASKING it (`DHPadFirst`). The first man on a pad is always asked, so
	-- he always gets the turn; a late joiner who was never asked is never told an index, and this
	-- does not invent one (the same limit that took the number off the banner's eyebrow).
	if asking ~= facedPad then
		facedPad = asking
		if asking ~= nil and CameraSystem ~= nil and lobbyData ~= nil then
			local truck = lobbyData.truckPosition(asking :: number)
			if truck ~= nil then
				CameraSystem.faceTowards(truck)
			end
		end
	end
	-- ...AND WHETHER A TRUCK IS ALREADY TAKING HIM (task 197). ONE server-measured fact again --
	-- `DHPadMine`, the state word of the pad he is loading onto -- read HERE for `setAsk`'s own
	-- stated reason, and the panel is TOLD both it and the seconds. The seconds are the ONES THIS
	-- FUNCTION ALREADY HAS: `lobby.secondsLeft` is converted three lines up for the objective line,
	-- so the banner's countdown and the line's countdown are the same number and cannot disagree
	-- (task 153 round 2's finding: *"a marker that moved without its label told a beater the drive
	-- was south"*). A world with no lobby is loading nobody.
	PadPanel.setLeaving(
		if lobbyData then Players.LocalPlayer:GetAttribute(lobbyData.PAD_MINE_ATTRIBUTE) else nil,
		if lobby then lobby.secondsLeft else nil
	)
	local target = Objective.targetFor(team, phase, MapUi.geometry(), me, lobby)
	local far = Objective.distanceStuds(target, me)
	arrivedAtTarget = Objective.arrived(far, arrivedAtTarget)
	if arrivedAtTarget then
		target = nil
	end

	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	-- THE ORIENTATION FROM THE CAMERA SYSTEM AND THE ANGLE FROM THE PROPERTY, and the asymmetry is
	-- deliberate: `Rig.apply` counts FOREIGN WRITES to `CurrentCamera.CFrame` and has warned about one
	-- since task 123, so the engine's CFrame is not reliably ours and `Camera.viewCFrame()`
	-- (`Rig.appliedCFrame`) is. There is no `appliedFov` accessor and adding one is a camera change;
	-- the field of view is read off the property, which is exactly what `Hud.renderScope` already
	-- does for the mask, and whose one writer is `Rig.apply`.
	local view = if CameraSystem ~= nil and CameraSystem.viewCFrame then CameraSystem.viewCFrame() else nil
	local fov = if camera then camera.FieldOfView else 70
	local reportOpen = ReportPanel.isOpen()
	local mapOpen = MapUi.isOpen()
	local scoped = Objective.isSuppressed()
	local cardUp = Hud.startCardVisible(snapshot, reportOpen)
	-- WHAT THE DRIVE IS DOING RIGHT NOW, read from the one replica and handed to the one pure rule
	-- (task 168). All three are local subtractions off server timestamps the snapshot already
	-- carries, so a beater's countdown ticks at render rate and costs no push.
	local drive = if matchSystem
		then {
			secondsLeft = matchSystem.secondsLeft(),
			holdLeft = matchSystem.holdSecondsLeft(),
			goAge = matchSystem.goAgeSeconds(),
			through = matchSystem.isThrough(),
		}
		else nil
	Objective.render({
		text = Objective.text(phase, team, drive, lobby),
		target = target,
		distanceStuds = far,
		view = view,
		fovDeg = fov,
		viewport = viewport,
		lineVisible = Objective.lineVisible(phase, team, reportOpen, mapOpen, scoped, cardUp, lobby),
		markVisible = Objective.markVisible(target, reportOpen, mapOpen, scoped, view ~= nil),
	})
	-- THE MAP GETS THE POINT, FLAT: it draws in x/z and has no use for the height.
	MapUi.setTarget(
		if target then Vector2.new(target.point.X, target.point.Z) else nil,
		if target then target.word else nil
	)
	local deg, word = Hud.markerFor(target, me, worldBearing, worldBearingLabel)
	if compassFrame then
		Compass.setBearing(deg, word)
	end
	MapUi.setPush(deg, word)
end

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
		-- THE DRIVE'S HORN (task 163): a `signal` entry is a SOUND, and `Hud.Sound` is the one
		-- writer of it. No early return -- `feedTextFor` answers nil for it on its own, so the "no
		-- text, no line" rule below stays the only place that decides what is drawn.
		if entry.kind == "signal" then
			Sound.driveSignal(entry.text)
		end
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

	-- THE MAP (task 155). Karen: *"I am missing map, we need a map when click M"*. It is started
	-- BEFORE the bearing closure below, because that closure hands it the push direction.
	--
	-- IN THE DEV WORLD THE GEOMETRY IS READY NOW: `Map` is required synchronously at the top of this
	-- file. In the Forest Test it arrives with `ForestTest`, through the same `whenReady` door the
	-- compass's bearing uses -- `MapUi.setGeometry` is public exactly so it can be told later.
	if miniMapFrame ~= nil and fullMapFrame ~= nil then
		MapUi.start({
			miniMap = miniMapFrame :: Frame,
			fullMap = fullMapFrame :: Frame,
			-- THE LEGEND IS THE MAP'S (task 165), handed over with its two frames: the Hud created it
			-- and `MapUi` is the one writer of everything inside it. The standalone touch button that
			-- used to be this field is gone -- it is `Hud.Rail`'s first button now
			-- (`backups/2026-10-12_mapui-touch-button.txt`).
			legend = mapLegendFrame,
			rail = railFrame,
		}, {
			-- FOR `viewHeadingDeg` ONLY, and it may be nil: then there is no facing wedge and the
			-- rest of the map is unchanged. One-way, like every other thing the Hud reads.
			Camera = CameraSystem,
			-- READ, NEVER WRITTEN: `ReportPanel.isOpen()`, so two full-screen panels are never up at
			-- once -- the reason `Hud.scorePanelVisible` already takes `reportOpen`.
			Report = ReportPanel,
			geometry = if Map.EXPECTED_WORLD == "forest-test"
				then nil
				else MapUi.geometryFor(Map.EXPECTED_WORLD, nil, Map),
			userId = player.UserId,
		})
	end

	-- THE WORLD'S DIRECTION AND ITS WORD, RESOLVED ONCE AND HANDED TO BOTH DRAWERS (task 155).
	--
	-- IT IS NO LONGER INSIDE `if compassFrame then`, and that is deliberate: this closure now feeds
	-- the map as well, and a map whose push arrow only worked in a world that happens to have a
	-- compass strip is the bug task 141 fixed for the scope (*"a scope that only worked in a world
	-- with a compass strip is a bug waiting for the next place"*).
	--
	-- ONE RULE, ONE EVALUATION, TWO DRAWERS. `Hud.driveBearing` is called here and nowhere else:
	-- two readers of one fact that could be handed different teams is how task 153 round 2's
	-- finding (*"a marker that moved without its label told a beater the drive was south"*) comes
	-- back.
	local bearing = nil
	-- ...and the WORD under the marker, which travels with it (task 153 round 2).
	local bearingLabel = nil
	if Map.EXPECTED_WORLD == "forest-test" then
		-- WAITED FOR, FOR THE SAME REASON AS THE MATCH (task 134). This was the Hud's SECOND
		-- `FindFirstChild` on a replicated module, found by the sweep this task asked for, and it
		-- fails the same silent way: no `ForestTest` yet means no bearing, and a compass with no
		-- DRIVE marker on it is the thing Karen asked for in task 125 -- *"we need to indicate
		-- from what side drive is comming"* -- quietly not there. `Compass.setBearing` is public
		-- exactly so it can be told later; in the common case this closure runs here and now, and
		-- `Compass.start` further down sets the same number again.
		-- ...AND A BEATER'S MARKER IS THE ROAD (task 153). Karen, 2026-10-11: *"beater are behind
		-- animals and moving towards hunter line (road) like in real life"* -- so the direction
		-- that matters to her is the one she is PUSHING, which is the opposite of the one the
		-- drive comes from. `Hud.driveBearing` is the whole rule and it is pure.
		--
		-- `player.Team` IS THE ONE REPRESENTATION OF THE TEAM, which is the same door
		-- `Match.myTeam` reads (and says so in its own header); the client match system does not
		-- boot in this world at all, so there is nothing else to ask. Re-read on change, because
		-- `/beater` switches the team mid-session and a marker that still pointed north would be
		-- a lie in the shape of a fact.
		Hud.whenReady(ReplicatedStorage, "ForestTest", function(module)
			local data = require(module)
			-- THE MAP'S GEOMETRY COMES OFF THE SAME MODULE, through the same door. `setGeometry` is
			-- idempotent and builds once.
			--
			-- ...AND IT IS REDRAWN WHEN THE DRIVE LAYOUT CHANGES (task 179). This world deals one of
			-- several layouts per drive, so the geometry is a function of a string the SERVER
			-- publishes on the module's own Rojo-owned `Live` child -- the client never chooses and
			-- never derives, because a map drawn on a layout the hunter is not standing on is wrong
			-- in a way no screenshot shows.
			--
			-- `MapUi.setGeometry` IS STILL THE ONE WRITER of the map's geometry (task 165's rule);
			-- this is a second CALLER of a public door, not a second drawer.
			-- WAITED FOR, NOT ASKED FOR ONCE (round 3's note). `whenReady` fires when the MODULE
			-- has replicated, and its Rojo-owned `Live` child is a separate instance that may not
			-- have arrived in the same frame -- in which case a `FindFirstChild` answers nil for the
			-- session, the warn fires and the hunter has no map for the whole drive. That is round
			-- 1's finding 4 in another shape, and the fix is the door Roblox already provides.
			-- `Flags` is the cited precedent for the HOST's shape, not for how it is found: it waits
			-- on the attribute, which is a different question.
			--
			-- BOUNDED, because an unbounded `WaitForChild` in a closure would hang this branch of the
			-- Hud for ever in a world that really has no `Live` child, and the honest answer there is
			-- the warn below.
			local live = module:WaitForChild(data.LIVE_NAME, 10)
			local function drawMap()
				MapUi.setGeometry(
					MapUi.geometryFor(
						Map.EXPECTED_WORLD,
						data,
						Map,
						if live then live:GetAttribute(data.LAYOUT_ATTRIBUTE) else nil
					)
				)
			end
			drawMap()
			if live then
				live:GetAttributeChangedSignal(data.LAYOUT_ATTRIBUTE):Connect(drawMap)
			else
				warn(
					string.format(
						"[Hud] ReplicatedStorage.ForestTest.%s is missing: no map in this world",
						tostring(data.LIVE_NAME)
					)
				)
			end
			-- IT WRITES THE TWO LOCALS AND NOTHING DRAWN (task 165). It used to call
			-- `Compass.setBearing` and `MapUi.setPush` itself, which made two writers of each of
			-- those -- this closure and the per-frame pass. `Hud.renderObjective` is the one writer
			-- now and this is the one place the WORLD's answer is resolved, so a `/beater` mid-session
			-- still moves the marker: the next frame reads these.
			local function apply()
				local team = player.Team
				bearing, bearingLabel = Hud.driveBearing(data, if team then team.Name else nil)
				worldBearing, worldBearingLabel = bearing, bearingLabel
			end
			apply()
			player:GetPropertyChangedSignal("Team"):Connect(apply)
		end)
	end

	-- THE LOBBY (task 177), through the same `whenReady` door as `ForestTest` above and for the same
	-- reason: it is a world-specific module that may not have replicated yet, and the Hud is designed
	-- to work without it. It is read and never written -- the only thing the Hud asks it is where the
	-- truck spot is and how long this player has left.
	Hud.whenReady(ReplicatedStorage, "Lobby", function(module)
		lobbyData = require(module)
		-- THE PAD DIALOG'S REMOTE, RESOLVED HERE AND ONCE (task 182). It is NOT read in
		-- `renderObjective`, and that is a correctness point rather than a saving: `Lobby.remotes`
		-- is `Shop.remotes`' shape, `WaitForChild` included, and a `WaitForChild` on a render tick
		-- would block the frame -- for ever, in a world whose folder never arrives. This callback is
		-- the one place in this file that is allowed to wait, which is what `whenReady` is FOR.
		PadPanel.setRemotes((lobbyData :: any).remotes())
	end)

	-- TASK 165: THE OBJECTIVE AND THE RAIL, started after the map because the per-frame pass below
	-- hands the map its target and the rail is laid out under the minimap.
	if objectiveLine ~= nil and waypointMark ~= nil and waypointWord ~= nil then
		Objective.start({
			line = objectiveLine :: TextLabel,
			mark = waypointMark :: Frame,
			markLabel = waypointWord :: TextLabel,
		})
	end
	if railFrame ~= nil then
		Rail.start(railFrame :: Frame, {
			-- EVERY ONE OF THESE IS READ, NEVER CALLED BACK. A missing collaborator means that button
			-- is not built at all, which is the same rule as `needsWeapon`: no dead buttons.
			Map = MapUi,
			Report = ReportPanel,
			Input = Weapon.Input,
			touchEnabled = UserInputService.TouchEnabled,
		})
		-- IS THERE A GUN IN HAND? The Hud already reads `Weapon.get().equipped` for the ammo readout,
		-- so there is ONE reader of the weapon state here and the rail is TOLD. `render` below sets
		-- it every time the weapon changes; this is the first answer.
		local state = Weapon.get()
		Rail.setWeapon(state ~= nil and state.equipped == true)
	end

	-- ONE CONNECTION, OUTSIDE EVERY `if`, for the reason task 141 gives for the scope's own: a thing
	-- that only worked in a world with a compass strip is a bug waiting for the next place. The
	-- objective line and the waypoint exist in every world; what the WORLD has stated decides whether
	-- there is a target, and `Objective.targetFor` answers nil rather than guessing.
	RunService.RenderStepped:Connect(function()
		Hud.renderObjective(CameraSystem)
	end)

	if compassFrame then
		-- BOTH, OR `start` UNDOES THE WORD. In the common case the closure above has already run and
		-- `Compass.start` sets the bearing a second time; passing only the number would put a
		-- beater's marker back under the hunter's label on the first frame (task 153 round 2).
		Compass.start(compassFrame, bearing, bearingLabel)
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

	-- THE SHOP PANEL (task 178), handed its frame, the two doors it borrows and its own remotes. Every
	-- collaborator may be nil and the panel says so in its own header: with no camera there is no
	-- `Cursor`, and then the mouse is the player's own problem -- which is why the `E` key exists.
	if shopFrame then
		ShopPanel.start(shopFrame :: Frame, {
			Cursor = if CameraSystem then CameraSystem.Cursor else nil,
			Input = Weapon.Input,
			remotes = Shop.remotes(),
		})
	end

	-- THE PAD DIALOG (task 182), handed its frame and the two doors it borrows. Its remotes are TOLD
	-- to it per frame instead (`PadPanel.setRemotes`), because `ReplicatedStorage.Lobby` is resolved
	-- by `Hud.whenReady` and may land after this runs.
	if padFrame then
		PadPanel.start(padFrame :: Frame, {
			Cursor = if CameraSystem then CameraSystem.Cursor else nil,
			Input = Weapon.Input,
			leaving = padLeavingFrame,
		})
	end

	if hitCardFrame then
		HitCard.start(hitCardFrame :: Frame, { Report = ReportSystem })
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
