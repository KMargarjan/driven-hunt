--!strict
-- PlayerScripts.Hud: THE OWNER OF ANYTHING DRAWN (CLAUDE.md rule 3, GAME_DESIGN.md "UI / anything
-- drawn", which this system fills). It is the only writer of PlayerGui.HunterHud and everything in
-- it: in this task the crosshair and one barrel/ammo readout, and nothing else.
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
	return screen
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
