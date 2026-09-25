--!strict
-- Camera.Rig: THE ONLY WRITER OF workspace.CurrentCamera IN THE REPO (CLAUDE.md rule 3), the only
-- module that disables the stock PlayerModule cameras, and the only writer of
-- LocalTransparencyModifier on the local character. It holds no mode state, reads no input, and
-- touches neither the cursor nor anything drawn.
--
-- THE FOREIGN-WRITE DETECTOR is the most valuable thing here. apply() records what it wrote; the next
-- apply() compares the camera with that record first. A difference means something else wrote the
-- camera between frames -- the stock camera coming back after a Studio update, a plugin, a future
-- LocalScript -- and it shows up as a NUMBER a spec asserts is zero, at run time, in the failing
-- case. That is rule 3 enforced by mechanism rather than by policy (design section 10.1).
--   Camera / CameraType.Scriptable  https://create.roblox.com/docs/workspace/camera
--   LocalTransparencyModifier       https://create.roblox.com/docs/reference/engine/classes/BasePart
--   PlayerModule:GetCameras():Disable()  https://create.roblox.com/docs/reference/engine/classes/PlayerScripts
--
-- The foreign-write detector below compares the WHOLE CFrame -- position and orientation -- plus the
-- field of view, which is what docs/design/camera.md section 10.1 always said it did.
--
-- Design: docs/design/camera.md (sections 3.1, 5.3, 10.1)
-- Audit:  docs/architecture/audit-003.md (must-fix 2)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Rig = {}

local lastCFrame: CFrame? = nil
local lastFov: number? = nil
local foreignCameraWrites = 0
local warned = false
local cameras = nil -- the stock camera controller, kept so release() can re-enable it
local stockDisabled = false
local watcher: RBXScriptConnection? = nil
local castFn: ((Vector3, Vector3) -> Vector3?)? = nil

local function currentCamera(): Camera?
	return Workspace.CurrentCamera
end

-- Takes the camera, and disables the stock cameras if this place has a PlayerModule to disable.
-- Re-run on every CharacterAdded: the engine restores CameraType on respawn, and re-asserting is
-- cheaper than a camera that silently reverts.
--
-- MEASURED, 2026-09-25: this place has NO Players.LocalPlayer.PlayerScripts.PlayerModule at all --
-- PlayerScripts during Play holds only our own modules plus RbxCharacterSounds. So `ok` means "the
-- camera is ours" (CameraType is Scriptable and nothing errored), and disabling the stock module is
-- a belt-and-braces step reported separately by stockCamerasDisabled(). The real proof that nothing
-- else writes the camera is the foreign-write detector below, which the client spec asserts is zero
-- -- the design (section 10.1) already says that detector is what matters, precisely because
-- GetCameras() is thinly documented and Roblox-controlled.
-- Disables the stock cameras if this place has a PlayerModule. Never yields.
local function disableStockCameras(module: Instance): (boolean, string?)
	local ok, err = pcall(function()
		cameras = require(module :: ModuleScript):GetCameras()
		cameras:Disable()
	end)
	stockDisabled = ok
	return ok, if ok then nil else tostring(err)
end

function Rig.acquire(): (boolean, string?)
	local cam = currentCamera()
	if not cam then
		return false, "no CurrentCamera"
	end

	-- TAKE THE CAMERA FIRST, and never yield on this path. Round 2, finding 1: this used to
	-- WaitForChild("PlayerModule", 10) BEFORE setting CameraType, and since this place has no
	-- PlayerModule at all the full 10 s elapsed on every boot and every respawn -- ten seconds in
	-- which nothing was bound, the cursor was not locked and the view did not follow the character.
	cam.CameraType = Enum.CameraType.Scriptable

	local scripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if module then
		local ok, err = disableStockCameras(module)
		return true, if ok then nil else tostring(err)
	end

	-- Not there now. Watch for it off the boot path, so a module that appears later is still
	-- disabled and this call still returns immediately.
	if scripts and not watcher then
		watcher = scripts.ChildAdded:Connect(function(child: Instance)
			if child.Name == "PlayerModule" then
				disableStockCameras(child)
			end
		end)
	end
	return true, "no PlayerScripts.PlayerModule yet (watching for one)"
end

-- Whether the stock PlayerModule cameras were found and disabled. False in a place that has no
-- PlayerModule, which is not an error: see the header.
function Rig.stockCamerasDisabled(): boolean
	return stockDisabled
end

function Rig.release()
	local cam = currentCamera()
	if cam then
		cam.CameraType = Enum.CameraType.Custom
	end
	if cameras then
		pcall(function()
			cameras:Enable()
		end)
		cameras = nil
	end
	if watcher then
		watcher:Disconnect()
		watcher = nil
	end
	stockDisabled = false
	lastCFrame, lastFov = nil, nil
end

-- The one assignment to the camera in the game.
function Rig.apply(cf: CFrame, fovDeg: number)
	local cam = currentCamera()
	if not cam then
		return
	end
	if lastCFrame and lastFov then
		-- POSITION, ORIENTATION and field of view. Audit-003 must-fix 2: this compared position and
		-- FOV only, so a second writer that turned the view without moving the camera -- a look-at
		-- tween, a plugin, any future client system setting a CFrame with the same position -- read
		-- as zero, and both specs that rest on this counter went green on evidence that could not
		-- see the case they exist for. Two basis vectors, because LookVector alone misses a roll.
		-- CameraType and CameraSubject are deliberately NOT compared: the engine restores both on
		-- respawn, so either would count the engine as a foreign writer every life (audit-003).
		local drifted = (cam.CFrame.Position - lastCFrame.Position).Magnitude > 1e-3
			or (cam.CFrame.LookVector - lastCFrame.LookVector).Magnitude > 1e-3
			or (cam.CFrame.RightVector - lastCFrame.RightVector).Magnitude > 1e-3
			or math.abs(cam.FieldOfView - lastFov) > 1e-3
		if drifted then
			foreignCameraWrites += 1
			if not warned then
				warned = true
				warn(
					string.format(
						"[camera] something else wrote CurrentCamera: %s look %s fov %.2f,"
							.. " expected %s look %s fov %.2f",
						tostring(cam.CFrame.Position),
						tostring(cam.CFrame.LookVector),
						cam.FieldOfView,
						tostring(lastCFrame.Position),
						tostring(lastCFrame.LookVector),
						lastFov
					)
				)
			end
		end
	end
	cam.CFrame = cf
	cam.FieldOfView = fovDeg
	lastCFrame, lastFov = cf, fovDeg
end

-- The local character only, and only its own parts: LocalTransparencyModifier is client-side, so no
-- other player sees any of this.
--
-- The parts are cached per character and written ONLY when the flag changes. A GetDescendants walk
-- every frame was most of the first measurement's 0.8 ms (the budget is 0.3 ms, design section 8.2).
local hiddenParts: { Instance } = {}
local hiddenFor: Model? = nil
local hiddenNow: boolean? = nil

function Rig.setLocalBodyHidden(hidden: boolean)
	local character = Players.LocalPlayer.Character
	if not character then
		hiddenFor, hiddenNow = nil, nil
		return
	end
	if hiddenFor ~= character then
		hiddenFor = character
		hiddenNow = nil
		table.clear(hiddenParts)
		for _, part in ipairs(character:GetDescendants()) do
			-- EVERYTHING the local character is wearing or holding, the Tool included. Two
			-- screenshots taught this: with accessories excluded the hair hung across the top of
			-- the ADS view, and with the Tool excluded the real gun was drawn beside the viewmodel
			-- clone -- two shotguns on screen at once. In first person the viewmodel IS the gun.
			if part:IsA("BasePart") or part:IsA("Decal") then
				table.insert(hiddenParts, part)
			end
		end
	end
	if hiddenNow == hidden then
		return
	end
	hiddenNow = hidden
	local value = if hidden then 1 else 0
	for _, part in ipairs(hiddenParts) do
		(part :: any).LocalTransparencyModifier = value
	end
end

function Rig.setCast(cast: ((Vector3, Vector3) -> Vector3?)?)
	castFn = cast
end

-- Production's one ray per frame. A spec injects its own through setCast.
local function worldCast(from: Vector3, to: Vector3): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = Players.LocalPlayer.Character
	local ignore: { Instance } = {}
	if character then
		table.insert(ignore, character)
	end
	local cam = currentCamera()
	if cam then
		table.insert(ignore, cam) -- the viewmodel lives here; CanQuery = false as well (belt and braces)
	end
	local effects = Workspace:FindFirstChild("WeaponEffects")
	if effects then
		table.insert(ignore, effects)
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local result = Workspace:Raycast(from, to - from, params)
	return if result then result.Position else nil
end

-- Pulls the camera in short of whatever the one ray found, floored so it never ends up inside the
-- character. Returns `desired` untouched when nothing is in the way.
function Rig.occlude(pivot: Vector3, desired: Vector3, config): Vector3
	local cast = castFn or worldCast
	local hit = cast(pivot, desired)
	if not hit then
		return desired
	end
	local toDesired = desired - pivot
	local distance = toDesired.Magnitude
	if distance < 1e-4 then
		return desired
	end
	local hitDistance = (hit - pivot).Magnitude
	local pulled = math.max(config.OCCLUSION_MIN_DISTANCE_STUDS, hitDistance - config.OCCLUSION_PAD_STUDS)
	if pulled >= distance then
		return desired
	end
	return pivot + toDesired.Unit * pulled
end

function Rig.stats()
	return { foreignCameraWrites = foreignCameraWrites, lastApplied = lastCFrame }
end

return Rig
