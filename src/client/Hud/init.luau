--!strict
-- PlayerScripts.Hud: THE OWNER OF ANYTHING DRAWN (CLAUDE.md rule 3, GAME_DESIGN.md "UI / anything
-- drawn", which this system fills). It is the only writer of PlayerGui.HunterHud and everything in
-- it: the crosshair, one barrel/ammo readout, and -- since Milestone 1.5 -- the hit marker.
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
-- Design: docs/design/shotgun.md (sections 3.4, 5.6), docs/design/camera.md (section 6.2)
-- Note:   docs/research/2026-09-24-shotgun.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Hud = {}

local gui: ScreenGui? = nil
local crosshair: Frame? = nil
local readout: TextLabel? = nil
local hitMark: Frame? = nil
local hitKind: string? = nil
local hitToken = 0 -- so a second hit during the first mark's life cannot hide it early
local markerConnection: RBXScriptConnection? = nil
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

local function render(Weapon, CameraSystem)
	local state = Weapon.get()
	local config = Shotgun.CONFIG
	if crosshair then
		-- Hidden while aiming: in ADS the gun's own line is the aiming reference, and leaving a
		-- hipfire cross on top of it is the double-reticle mistake (camera design section 6.2). The
		-- Hud asks the CAMERA, which is the state, not the weapon's aim flag, which is the request.
		local aiming = CameraSystem ~= nil and CameraSystem.getMode() == "Aiming"
		crosshair.Visible = config.CROSSHAIR_ENABLED and state ~= nil and state.equipped and not aiming
	end
	if readout then
		readout.Text = if state then textFor(state) else ""
	end
end

function Hud.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local scripts = player:WaitForChild("PlayerScripts")
	local Weapon = require(scripts:WaitForChild("Weapon"))
	-- The camera may not exist (it is its own task); the Hud works without it and simply never
	-- hides the crosshair for aiming. One-way: the camera has no reference to the Hud.
	local cameraModule = scripts:FindFirstChild("Camera")
	local CameraSystem = if cameraModule then require(cameraModule) else nil

	gui = build();
	(gui :: ScreenGui).Parent = player:WaitForChild("PlayerGui")

	-- One way: the server tells this client that something of theirs landed. The Hud never fires it.
	markerConnection = Shotgun.remotes().HitMarker.OnClientEvent:Connect(Hud.onHitMarker)

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
