--!strict
-- Camera: the owner of the camera mode state, of the one render-step binding, and of the one mouse-
-- movement connection (CLAUDE.md rule 3). Its private modules each own exactly one thing: Mode is
-- pure, Rig is the only writer of workspace.CurrentCamera, Cursor the only writer of the mouse,
-- Viewmodel the only writer of the first-person model.
--
-- Karen's decision (2026-09-25, option A): mouse-locked over-the-shoulder third person, the stock
-- camera module disabled, the stock MOVEMENT module kept, hold right mouse for first-person ADS.
--
-- Pattern: an owner over a pure core, as src/server/Boar/init.luau and src/server/Weapon/init.luau
-- already are here. Nothing happens on require -- only start() begins production -- which is what
-- lets a spec require this module and drive Mode with no game running.
--   RunService:BindToRenderStep + Enum.RenderPriority.Camera
--     https://create.roblox.com/docs/reference/engine/classes/RunService#BindToRenderStep
--   UserInputService.InputChanged is the ONLY way to see mouse movement; ContextActionService
--     cannot bind it (tests/client/input_driving.spec.luau learned this in Task 6)
--
-- It never requires PlayerScripts.Weapon: the aim flag arrives through an injected source that
-- CameraBoot -- the composition root -- installs, the idiom BoarBoot already uses. So the camera
-- builds, boots and tests with no weapon in the place at all.
--
-- Design: docs/design/camera.md (sections 3, 4, 5.1)
-- Note:   docs/research/2026-09-24-shotgun.md (sources 4-5)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Config)
local Cursor = require(script.Cursor)
local Mode = require(script.Mode)
local Rig = require(script.Rig)
local Viewmodel = require(script.Viewmodel)

local Camera = {}

-- Exported for specs only, exactly as src/server/Boar/init.luau exports Boar.Brain.
Camera.Config = Config
Camera.Mode = Mode
Camera.Rig = Rig
Camera.Cursor = Cursor
Camera.Viewmodel = Viewmodel

export type AimSource = { isAiming: () -> boolean }

local state = Mode.initial(Config)
local lookDelta = Vector2.zero
local aimSource: AimSource? = nil
local started = false
local connections: { RBXScriptConnection } = {}
local acquired, acquireReason = false, nil :: string?

local signal = Instance.new("BindableEvent")
Camera.Changed = signal.Event

local stats = {
	frames = 0,
	cursorReasserts = 0,
	maxDistanceFromRoot = 0,
	maxUpdateMs = 0,
	viewmodelParented = false,
	aimEnters = 0,
	aimExits = 0,
}

-- Every mode the camera has been in, in order, from boot. The harness-driven spec asserts over this
-- rather than over whatever mode happens to be current when TestEZ starts (design section 9.3).
local history: { string } = { state.mode }

function Camera.getMode(): Mode.ModeName
	return state.mode
end

function Camera.getBlend(): number
	return state.blend
end

function Camera.getState(): Mode.State
	return state
end

function Camera.modeHistory(): { string }
	return table.clone(history)
end

function Camera.setAimSource(source: AimSource?)
	aimSource = source
end

function Camera.stats()
	local out = table.clone(stats)
	out.foreignCameraWrites = Rig.stats().foreignCameraWrites
	out.cursorReasserts = Cursor.stats().reasserts
	out.viewmodelParented = Viewmodel.isParented()
	return table.freeze(out)
end

local function characterParts()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return character, root, humanoid
end

local function update(dt: number)
	local startedAt = os.clock()
	local character, root, humanoid = characterParts()
	local alive = humanoid ~= nil and humanoid.Health > 0
	local aiming = aimSource ~= nil and aimSource.isAiming()

	local previous = state.mode
	state = Mode.step(state, {
		aiming = aiming,
		alive = alive,
		hasCharacter = character ~= nil and root ~= nil,
		lookDelta = lookDelta,
	}, dt, Config)
	lookDelta = Vector2.zero -- consumed exactly once

	if state.mode ~= previous then
		table.insert(history, state.mode)
		if state.mode == "Aiming" then
			stats.aimEnters += 1
		elseif previous == "Aiming" then
			stats.aimExits += 1
		end
		signal:Fire(state.mode, state.blend)
	end

	if root then
		local pivot, desired, fov = Mode.cameraCFrame(root.CFrame, state, Config)
		local position = Rig.occlude(pivot, desired.Position, Config)
		local applied = CFrame.lookAt(position, position + desired.LookVector)
		Rig.apply(applied, fov)
		stats.maxDistanceFromRoot = math.max(stats.maxDistanceFromRoot, (position - root.Position).Magnitude)
		Rig.setLocalBodyHidden(state.blend > Config.BODY_HIDE_BLEND)
		Viewmodel.update(applied, state.blend, Config)
	end

	Cursor.apply()
	stats.frames += 1
	stats.maxUpdateMs = math.max(stats.maxUpdateMs, (os.clock() - startedAt) * 1000)
end

function Camera.start()
	assert(not started, "Camera.start() called twice")
	started = true

	acquired, acquireReason = Rig.acquire()
	if not acquired then
		warn("[camera] could not take the camera: " .. tostring(acquireReason))
	elseif acquireReason then
		-- The camera is ours, but there was no stock module to disable. Loud, because if one ever
		-- appears it becomes a second writer -- which stats().foreignCameraWrites then catches.
		warn("[camera] no stock PlayerModule to disable (" .. acquireReason .. "); the camera is still ours")
	end
	Cursor.start()

	table.insert(
		connections,
		Players.LocalPlayer.CharacterAdded:Connect(function()
			-- The engine restores CameraType on respawn, so the rig is re-asserted rather than
			-- assumed (design section 5.3).
			acquired, acquireReason = Rig.acquire()
		end)
	)

	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
			if processed or input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end
			lookDelta += Vector2.new(input.Delta.X, input.Delta.Y)
		end)
	)

	RunService:BindToRenderStep(Config.RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value, update)
end

function Camera.stop()
	if not started then
		return
	end
	started = false
	RunService:UnbindFromRenderStep(Config.RENDER_STEP_NAME)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	Viewmodel.clear()
	Rig.setLocalBodyHidden(false)
	Rig.release()
	Cursor.stop()
end

function Camera.acquired(): (boolean, string?)
	return acquired, acquireReason
end

function Camera.viewportCamera(): Camera?
	return Workspace.CurrentCamera
end

return Camera
