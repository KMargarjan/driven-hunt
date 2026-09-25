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
local lookAtRequest: BindableFunction? = nil

local signal = Instance.new("BindableEvent")
Camera.Changed = signal.Event

local stats = {
	frames = 0,
	cursorReasserts = 0,
	maxDistanceFromRoot = 0,
	maxUpdateMs = 0,
	totalUpdateMs = 0,
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

-- So a spec can put back what CameraBoot installed rather than rebuilding the adapter, which would
-- duplicate production logic in a test (round 1, finding 1).
function Camera.getAimSource(): AimSource?
	return aimSource
end

function Camera.stats()
	local out = table.clone(stats)
	-- The budget (design section 8.2) is what this costs every frame, so the AVERAGE is the number
	-- that means it. The max is kept and reported, but one 0.4 ms frame while Studio is compiling a
	-- spec file is a hitch in the session, not a camera that costs too much: Task 26's own runs
	-- measured maxima between 0.22 and 0.34 ms for identical code.
	out.avgUpdateMs = if stats.frames > 0 then stats.totalUpdateMs / stats.frames else 0
	out.foreignCameraWrites = Rig.stats().foreignCameraWrites
	out.cursorReasserts = Cursor.stats().reasserts
	out.viewmodelParented = Viewmodel.isParented()
	return table.freeze(out)
end

-- The character's parts are cached and refreshed only when the character changes. Three
-- FindFirstChild calls per frame were measurable against a 0.3 ms budget (the first runs of this
-- task sat between 0.22 and 0.34 ms).
local cachedCharacter: Model? = nil
local cachedRoot: BasePart? = nil
local cachedHumanoid: Humanoid? = nil

local function characterParts()
	local character = Players.LocalPlayer.Character
	if character ~= cachedCharacter then
		cachedCharacter = character
		cachedRoot, cachedHumanoid = nil, nil
	end
	-- Keep looking while either is missing. Round 1, finding 3: caching them once meant a character
	-- whose root or humanoid had not replicated on the first frame left the camera in Loading for
	-- that whole life -- and Loading is a transient state by design (section 4.1). The lookup costs
	-- a frame only while they are absent, and the stale-part case re-resolves the same way.
	if character then
		if not cachedRoot or not cachedRoot.Parent then
			cachedRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		end
		if not cachedHumanoid or not cachedHumanoid.Parent then
			cachedHumanoid = character:FindFirstChildOfClass("Humanoid")
		end
	end
	return cachedCharacter, cachedRoot, cachedHumanoid
end

-- Point the camera at a world position, through the state machine, as if the player had turned to
-- it. Returns false when there is no character to turn yet. The OWNER writes; the caller asks.
--
-- It exists so a test can aim: the camera's yaw comes from mouse movement, and under
-- MouseBehavior = LockCenter the harness cannot deliver usable deltas (design section 9.3), which is
-- why there has never been an end-to-end "shoot the thing you are looking at" assertion.
function Camera.lookAt(point: Vector3): boolean
	local _, root = characterParts()
	if not root then
		return false
	end
	state = Mode.anglesToward(state, root.CFrame, point, Config)
	return true
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

	if state.mode == "Dead" then
		-- Design section 4.1: the camera HOLDS its position, the viewmodel goes immediately, and no
		-- input moves it. Nothing is applied, so whatever Rig last wrote stays on screen.
		Viewmodel.clear()
	elseif root then
		local pivot, desired, fov = Mode.cameraCFrame(root.CFrame, state, Config)
		local position = Rig.occlude(pivot, desired.Position, Config)
		local applied = CFrame.lookAt(position, position + desired.LookVector)
		Rig.apply(applied, fov)
		stats.maxDistanceFromRoot = math.max(stats.maxDistanceFromRoot, (position - root.Position).Magnitude)
		Viewmodel.update(applied, state.blend, Config)
	end

	-- Every frame, whatever the mode. Round 2, finding 2: this used to live inside the `elseif root`
	-- branch, so a player who died while aimed stayed invisible to themselves until they respawned --
	-- a frozen ADS camera looking at a body nobody had told to come back.
	Rig.setLocalBodyHidden(state.mode ~= "Dead" and state.blend > Config.BODY_HIDE_BLEND)

	Cursor.apply()
	stats.frames += 1
	local tookMs = (os.clock() - startedAt) * 1000
	stats.maxUpdateMs = math.max(stats.maxUpdateMs, tookMs)
	stats.totalUpdateMs += tookMs
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

	-- The harness's only way in. execute_luau has its OWN module cache -- measured 2026-09-25: a
	-- require() through it reports mode=Loading and frames=0 while the live camera is Scriptable at
	-- FOV 70 -- so it cannot call this module's functions at all. An Instance is shared, so the
	-- request crosses on one. This is a REQUEST, exactly as Cursor.requestFree is: the owner still
	-- does the writing, and workspace.CurrentCamera still has one writer in the whole repo.
	lookAtRequest = Instance.new("BindableFunction")
	lookAtRequest.Name = "LookAtRequest"
	lookAtRequest.OnInvoke = function(x: any, y: any, z: any)
		if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
			return false
		end
		return Camera.lookAt(Vector3.new(x, y, z))
	end
	lookAtRequest.Parent = script

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
	if lookAtRequest then
		lookAtRequest:Destroy()
		lookAtRequest = nil
	end
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
