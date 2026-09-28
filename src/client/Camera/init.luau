--!strict
-- Camera: the owner of the camera mode state, of the one render-step binding, and of the one mouse-
-- movement connection (CLAUDE.md rule 3). Its private modules each own exactly one thing: Mode is
-- pure, Rig is the only writer of workspace.CurrentCamera in src/, Cursor the only writer of the mouse,
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
-- WHAT THE WEAPON SAYS ABOUT ITS OWN RELOAD (task 96): is it broken open, and how many barrels had
-- been fired when it opened. The server owns the reload and its clock; the camera draws it. Injected
-- by `CameraBoot` exactly as the aim source is, so this module still requires no weapon.
export type BreakSource = { state: () -> { open: boolean, spent: number, loaded: { boolean } } }

local state = Mode.initial(Config)
local lookDelta = Vector2.zero
local aimSource: AimSource? = nil
local breakSource: BreakSource? = nil
local started = false
local connections: { RBXScriptConnection } = {}
local acquired, acquireReason = false, nil :: string?
local lookAtRequest: BindableFunction? = nil
-- The last Camera.lookAt point that has NOT yet been seen on screen. Task 50: a caller needs to know
-- when its request has actually been rendered, because the harness replays mouse movement into the
-- same client and a mouse delta in the same frame takes the camera somewhere else.
local pendingLookAt: Vector3? = nil

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
	-- Camera.lookAt asked for, and a rendered frame that actually showed it. Task 50: the gap between
	-- the two is a frame in which mouse movement arrived, which is why a caller must WAIT for landed
	-- rather than count frames. See Config.LOOK_AT_LANDED_DOT for how close "showed it" is.
	lookAtRequests = 0,
	lookAtLanded = 0,
	-- How far the barrels are swung right now, in degrees, and how many shells the viewmodel has
	-- drawn since boot (task 96). The first is what a screenshot is checked against; the second says
	-- the reload was drawn at all.
	breakAngleDeg = 0,
	-- Shots this camera has kicked for, and the largest camera pitch offset any of them reached
	-- (task 92). The second number is what says the kick is "a bit" rather than a lurch, and the
	-- client spec asserts both it and the return to zero.
	recoilKicks = 0,
	maxRecoilCamPitchDeg = 0,
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

-- WHAT THE RELOAD SHOULD DRAW, from two snapshots (task 96, round 2). PURE, so a spec can drive it
-- with fabricated states, and because the answer cannot be read off the CURRENT replica at all:
-- `Break` opens the gun AND empties every barrel in one reduction, so by the time `open` is true the
-- barrels say "None" and nothing was ever spent. Round 1 asked the live snapshot and therefore drew
-- no spent shell in the game, ever -- it passed its own spec only because the spec handed the
-- viewmodel a `spent` it had made up.
--
-- So the spent count comes from the LAST SNAPSHOT BEFORE THE GUN OPENED: those are the barrels that
-- fired. The fresh shells come from the current one -- a chamber counts as fed the moment the
-- replica says it holds a shell, which is exactly when the server's `Load` step lands.
function Camera.breakFrom(lastClosed, snapshot)
	local empty = { open = false, spent = 0, loaded = { false, false } }
	if snapshot == nil or snapshot.open ~= true then
		return empty
	end
	local spent = 0
	for _, barrel in ipairs((lastClosed and lastClosed.barrels) or {}) do
		if barrel == "Spent" then
			spent += 1
		end
	end
	local loaded = { false, false }
	for index, shell in ipairs(snapshot.loaded or {}) do
		if index <= 2 then
			loaded[index] = shell ~= nil and shell ~= "None"
		end
	end
	return { open = true, spent = spent, loaded = loaded }
end

function Camera.setBreakSource(source: BreakSource?)
	breakSource = source
end

function Camera.getBreakSource(): BreakSource?
	return breakSource
end

-- WHICH CAMERA THIS BUILD IS RUNNING, republished as a fact about the view. The Hud asks this
-- rather than `Flags.isOn` (design section 6.2): the camera owns the switch, so there is one source
-- for the fact and one writer of the crosshair.
function Camera.isFirstPerson(): boolean
	return Config.FIRST_PERSON
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
	out.breakAngleDeg = Mode.breakAngleDeg(state, Config)
	out.shellsDrawn = Viewmodel.stats().shellsDrawn
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
	-- Pending until a frame has been RENDERED pointing there. The angles are set now, but update()
	-- runs Mode.step first, and a mouse delta that arrived this frame is consumed there -- so
	-- "I asked" and "it is on screen" are two different moments and the caller needs the second.
	pendingLookAt = point
	stats.lookAtRequests += 1
	return true
end

-- THE SHOT'S KICK (task 92). Karen, after playing S2: "shooting has to have recoil a bit".
--
-- A REQUEST, exactly as `Camera.lookAt` and `Cursor.requestFree` are: the weapon owner says "a shot
-- of mine landed" and the camera decides what the camera does about it. `CameraBoot` is what connects
-- the two, so neither owner requires the other -- the same wiring the aim source uses.
--
-- The spring is in `Mode`, so this is one reducer call and a counter. Off in the third-person branch
-- (`Mode.kick` refuses it by config), because task 89 promised the flag-off camera is unchanged.
function Camera.kick()
	local before = state
	state = Mode.kick(state, Config)
	if state ~= before then
		stats.recoilKicks += 1
	end
end

-- WHERE THE DRAWN GUN'S MUZZLE IS, for the shot cosmetics (task 92). Karen, after playing S2: "when
-- firing this animation where flies light has to be from pipes not from shoulder."
--
-- IN FIRST PERSON THE GUN ON SCREEN IS NOT THE GUN IN THE WORLD: the Tool is in the character's hand,
-- hidden, and what the player sees is the viewmodel clone parented to the camera. So a flash drawn at
-- the server's muzzle position appears where the character's hands are -- off to the side, at the
-- shoulder, which is exactly what she saw. This answers with the CLONE's muzzle instead, and nil
-- whenever there is no clone on screen (third person, dead, the flag off), which is when the world
-- position is the right answer.
--
-- A READ. `Weapon.Effects` draws; this module draws the gun. Neither writes the other's Instances.
-- FIRST PERSON ONLY (round 1, finding 1). In the OFF branch the clone is also on screen while
-- aiming, but the player is looking at their CHARACTER holding the real gun, so the world muzzle is
-- the right answer there -- and task 89's promise is that the flag-off branch is unchanged.
function Camera.viewmodelMuzzle(barrel: number?): CFrame?
	if not Config.FIRST_PERSON then
		return nil
	end
	return Viewmodel.muzzle(barrel)
end

local function update(dt: number)
	local startedAt = os.clock()
	local character, root, humanoid = characterParts()
	local alive = humanoid ~= nil and humanoid.Health > 0
	local aiming = aimSource ~= nil and aimSource.isAiming()

	-- THE RELOAD THE WEAPON IS ACTUALLY IN (task 96), asked once a frame and handed to both halves:
	-- the reducer swings the barrels, the viewmodel draws the shells.
	-- FIRST PERSON ONLY, AND ASKED NOWHERE ELSE (round 2, finding 2): the flag-off camera has no
	-- break to draw, so the source is not even consulted and the viewmodel is told the gun is shut.
	local breaking = if Config.FIRST_PERSON and breakSource then breakSource.state() else nil
	Viewmodel.setReload(breaking)

	local previous = state.mode
	state = Mode.step(state, {
		aiming = aiming,
		alive = alive,
		hasCharacter = character ~= nil and root ~= nil,
		lookDelta = lookDelta,
		breaking = breaking ~= nil and breaking.open,
	}, dt, Config)
	lookDelta = Vector2.zero -- consumed exactly once
	stats.maxRecoilCamPitchDeg = math.max(stats.maxRecoilCamPitchDeg, math.abs(state.recoilCamPitchDeg))

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
		-- NO RAYCAST AT ALL IN FIRST PERSON, and that is a removal rather than a saving: the eye is
		-- AIM_PIVOT_FORWARD_STUDS = 0.4 studs from the pivot and `occlude` pulls in no closer than
		-- OCCLUSION_MIN_DISTANCE_STUDS = 1.2, so a cast would return `desired` untouched every frame
		-- -- a cost with no effect, and a "one cast per frame" assertion that asserts nothing
		-- (design section 4.3).
		local position = if Config.FIRST_PERSON then desired.Position else Rig.occlude(pivot, desired.Position, Config)
		local applied = CFrame.lookAt(position, position + desired.LookVector)
		Rig.apply(applied, fov)
		if pendingLookAt then
			-- Measured against the CFrame THIS frame actually wrote, not against the angles asked
			-- for: occlusion may have pulled the camera in, and a mouse delta may have turned it.
			local toTarget = pendingLookAt - applied.Position
			if toTarget.Magnitude > 1e-3 and applied.LookVector:Dot(toTarget.Unit) >= Config.LOOK_AT_LANDED_DOT then
				pendingLookAt = nil
				stats.lookAtLanded += 1
			end
		end
		stats.maxDistanceFromRoot = math.max(stats.maxDistanceFromRoot, (position - root.Position).Magnitude)
		Viewmodel.update(applied, state, Config)
	end

	-- Every frame, whatever the mode. Round 2, finding 2: this used to live inside the `elseif root`
	-- branch, so a player who died while aimed stayed invisible to themselves until they respawned --
	-- a frozen ADS camera looking at a body nobody had told to come back.
	--
	-- IN FIRST PERSON THE BODY IS HIDDEN WHENEVER THERE IS ONE, THE DEAD INCLUDED (design section
	-- 4.6): the camera is inside the head, so drawing the body would draw the inside of a neck across
	-- the whole screen. `BODY_HIDE_BLEND` therefore decides nothing in this branch, which is said
	-- here and in Config rather than by deleting a number the OFF branch still uses.
	--
	-- THE OFF BRANCH IS LEFT EXACTLY AS IT WAS, deliberately. The design writes this step as one
	-- expression, `FIRST_PERSON and mode ~= "Loading" or blend > BODY_HIDE_BLEND`, and read literally
	-- that drops the `mode ~= "Dead"` guard from the OFF branch -- the guard round 2's finding 2 put
	-- there. Task 89 changes nothing a player sees with the flag off, so the branches are written
	-- out. Recorded in TASKS.md row 89a for the Architect.
	local hideBody
	if Config.FIRST_PERSON then
		hideBody = state.mode ~= "Loading"
	else
		hideBody = state.mode ~= "Dead" and state.blend > Config.BODY_HIDE_BLEND
	end
	Rig.setLocalBodyHidden(hideBody)

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
		-- The camera is ours, but the stock cameras were not turned off. Rig.acquire's reason says
		-- WHICH of the two that is -- none present, or one present that would not turn off -- and it
		-- is printed verbatim rather than wrapped in a sentence that is true of only one of them
		-- (TASKS.md 26a(a)). Loud either way, because a stock module that runs is a second writer --
		-- which stats().foreignCameraWrites then catches.
		warn("[camera] the stock cameras are not disabled: " .. acquireReason .. "; the camera is still ours")
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
