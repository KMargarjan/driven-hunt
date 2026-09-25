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
-- Design: docs/design/camera.md (sections 3.1, 5.3, 10.1)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Rig = {}

local lastCFrame: CFrame? = nil
local lastFov: number? = nil
local foreignCameraWrites = 0
local warned = false
local cameras = nil -- the stock camera controller, kept so release() can re-enable it
local castFn: ((Vector3, Vector3) -> Vector3?)? = nil

local function currentCamera(): Camera?
	return Workspace.CurrentCamera
end

-- Disables the stock cameras and takes the camera. Re-run on every CharacterAdded: the engine
-- restores CameraType on respawn, and re-asserting is cheaper than a camera that silently reverts.
function Rig.acquire(): (boolean, string?)
	local cam = currentCamera()
	if not cam then
		return false, "no CurrentCamera"
	end

	local ok, err = pcall(function()
		local scripts = Players.LocalPlayer:WaitForChild("PlayerScripts", 10)
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if not module then
			error("PlayerScripts.PlayerModule missing", 0)
		end
		cameras = require(module :: ModuleScript):GetCameras()
		cameras:Disable()
	end)

	cam.CameraType = Enum.CameraType.Scriptable
	if not ok then
		-- Loud, and not fatal: the foreign-write detector below catches the consequence anyway.
		return false, tostring(err)
	end
	return true, nil
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
	lastCFrame, lastFov = nil, nil
end

-- The one assignment to the camera in the game.
function Rig.apply(cf: CFrame, fovDeg: number)
	local cam = currentCamera()
	if not cam then
		return
	end
	if lastCFrame and lastFov then
		local drifted = (cam.CFrame.Position - lastCFrame.Position).Magnitude > 1e-3
			or math.abs(cam.FieldOfView - lastFov) > 1e-3
		if drifted then
			foreignCameraWrites += 1
			if not warned then
				warned = true
				warn(
					string.format(
						"[camera] something else wrote CurrentCamera: %s fov %.2f, expected %s fov %.2f",
						tostring(cam.CFrame.Position),
						cam.FieldOfView,
						tostring(lastCFrame.Position),
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
function Rig.setLocalBodyHidden(hidden: boolean)
	local character = Players.LocalPlayer.Character
	if not character then
		return
	end
	local value = if hidden then 1 else 0
	for _, part in ipairs(character:GetDescendants()) do
		-- The Tool's Handle is deliberately excluded: the real gun keeps being drawn in third
		-- person, and in first person the viewmodel is a separate clone under the camera.
		local isBody = (part:IsA("BasePart") and part.Name ~= "Handle") or part:IsA("Decal")
		if isBody then
			part.LocalTransparencyModifier = value
		end
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
