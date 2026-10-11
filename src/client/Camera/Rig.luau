--!strict
-- Camera.Rig: THE ONLY WRITER OF workspace.CurrentCamera IN src/ (CLAUDE.md rule 3), the only
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- THE WEAPON TABLE, for one question and nothing else: is the Tool in the hand a GUN? (task 152).
-- This module decides what the local player can see of their own character, and "a Tool" stopped
-- meaning "a gun" the day the beater got a horn. It reads no weapon state and no weapon number.
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

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
		-- `Disable` IS NOT ON EVERY PlayerModule, and that is measured rather than assumed. In the
		-- playtest place the call raised "attempt to call missing method 'Disable' of table" while
		-- the DEV place never printed it -- same `StarterPlayerScripts` in both, so it is Roblox's
		-- own injected module differing between places, not anything this project ships.
		--
		-- Asking first turns an alarming stack trace into a plain answer. It changes nothing about
		-- whether the camera is ours: `CameraType` is still Scriptable and the foreign-write
		-- detector is still what proves it (design section 10.1, which says exactly that because
		-- `GetCameras()` is thinly documented and Roblox-controlled).
		if typeof((cameras :: any).Disable) ~= "function" then
			error("this PlayerModule's GetCameras() has no Disable method", 0)
		end
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
		-- THE REASON HAS TO READ CORRECTLY ON ITS OWN (TASKS.md 26a(a)): the owner prints whatever
		-- comes back, and "no stock PlayerModule to disable" was the wrong sentence for the case
		-- where one IS there and would not turn off -- which is the case that matters, because then
		-- it is a second writer of the camera.
		return true,
			if ok then nil else "PlayerScripts.PlayerModule is there and would not be disabled: " .. tostring(err)
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

-- THE VIEW THIS SYSTEM LAST ASKED FOR (task 125 round 3), which is not the same thing as
-- `CurrentCamera.CFrame`: this file already counts FOREIGN WRITES to that property, so by its own
-- evidence the engine's copy can be something nobody here asked for. `lastCFrame` is what the camera
-- system intends and therefore what is rendered the instant after it is applied.
--
-- IT EXISTS BECAUSE THE HUD NEEDED THE YAW AND HAD NOWHERE HONEST TO GET IT. A compass driven by
-- `CurrentCamera` reads whatever the second writer left; one driven by the character's
-- `HumanoidRootPart` never moves at all, because in first person this system turns the VIEW and not
-- the body. The owner of the view publishes the view: one owner, one reader.
function Rig.appliedCFrame(): CFrame?
	return lastCFrame
end

-- The local character only, and only its own parts: LocalTransparencyModifier is client-side, so no
-- other player sees any of this.
--
-- The parts are cached per character and written ONLY when the flag changes. A GetDescendants walk
-- every frame was most of the first measurement's 0.8 ms (the budget is 0.3 ms, design section 8.2).
--
-- THE CACHE FOLLOWS THE CHARACTER (audit-003 F1, audit-004 must-fix 2). Caching once per life was
-- wrong for the one part that matters most: the shotgun's `Handle` is granted server-side on
-- `CharacterAdded` (src/server/Weapon/init.luau, `watchPlayer` -> `Weapon.grant`) and reaches the
-- client AFTER the camera's first render step with that character, so it was very likely missing from
-- the list -- and because the write loop is skipped when the flag has not changed, nothing ever wrote
-- it. The player then aimed and saw THE REAL GUN BESIDE THE VIEWMODEL: exactly the two-shotgun
-- picture the comment below says a screenshot already taught once. Layered accessories arrive the
-- same way.
--
-- So the walk stays off the frame path, and `DescendantAdded` keeps the list true: a part that
-- appears while the body is hidden is hidden as it arrives, and `DescendantRemoving` keeps the list
-- from growing across a life of accessory churn.
--
-- AND IT IS RE-ASSERTED EVERY FRAME WHILE HIDDEN, BECAUSE THERE IS A SECOND WRITER WE CANNOT
-- REMOVE (task 151 round 3). `Rig.acquire` already warns that this PlayerModule will not turn its
-- cameras off -- *"this PlayerModule's GetCameras() has no Disable method"* -- and the stock
-- `PlayerModule.CameraModule.TransparencyController` keeps running with them. It computes
-- `LocalTransparencyModifier` from ITS OWN zoom distance, not from where the camera actually is,
-- and this camera moves the eye to the head without touching that zoom -- so it decides the player
-- is in third person and writes 0 over everything, every frame.
--
-- MEASURED in the Forest Test, 2026-10-11: `LocalTransparencyModifier = 1` written on all 18
-- drawable parts of the local character, and **two seconds later only 2 were still 1**. The one
-- that put them back names itself:
-- `Players.<player>.PlayerScripts.PlayerModule.CameraModule.TransparencyController`.
--
-- Writing once on the CHANGE was therefore writing into a value something else overwrites on the
-- next frame, and the symptom was the whole body on screen in first person: the player's own right
-- arm as a tan block in the bottom-right, and -- once task 151 gave everybody one -- the brim of
-- their own orange cap across the top.
--
-- The walk stays off the frame path; what is now per-frame is the WRITE over the cached list, which
-- is ~20 property sets and is not what cost 0.8 ms (that was `GetDescendants`). `Rig.reassertions()`
-- counts the frames on which it had to, so "the stock controller is still fighting us" is a number
-- somebody can read rather than a thing somebody remembers.
-- THE TOOL THIS PART BELONGS TO, or nil for a part of the body itself. Walks up to the character
-- rather than to the DataModel root, so a part outside the character answers nil in one step.
-- Exported because `tests/client/camera_client.spec.luau` drives it with no live character.
function Rig.toolAbove(part: Instance?): Tool?
	local at = part
	while at ~= nil do
		if at:IsA("Tool") then
			return at :: Tool
		end
		if at:FindFirstChildOfClass("Humanoid") ~= nil then
			return nil -- reached the character: a part of the body, not of a Tool
		end
		at = at.Parent
	end
	return nil
end

local hiddenParts: { Instance } = {}
local hiddenFor: Model? = nil
local hiddenNow: boolean? = nil
local hiddenAdded: RBXScriptConnection? = nil
local hiddenRemoving: RBXScriptConnection? = nil
local reassertions = 0

-- EVERYTHING the local character is wearing or holding, the Tool included. Two screenshots taught
-- this: with accessories excluded the hair hung across the top of the ADS view, and with the Tool
-- excluded the real gun was drawn beside the viewmodel clone -- two shotguns on screen at once. In
-- first person the viewmodel IS the gun.
local function trackHiddenPart(part: Instance)
	if not (part:IsA("BasePart") or part:IsA("Decal")) then
		return
	end
	-- ...EXCEPT WHAT IS IN THE HAND AND IS NOT A GUN (task 152). "In first person the viewmodel IS
	-- the gun" is true of a gun and of nothing else: the beater's horn has no viewmodel, so hiding
	-- it would leave a beater in first person holding nothing at all. `Camera.Viewmodel` refuses to
	-- draw for a non-weapon Tool and this is its exact complement -- the thing in the hand is on
	-- screen once, either as the viewmodel clone or as the real Tool, never twice and never not at
	-- all.
	local tool = Rig.toolAbove(part)
	if tool ~= nil and not Weapons.isWeaponTool(tool) then
		return
	end
	table.insert(hiddenParts, part)
	if hiddenNow then
		-- It arrived while the body is hidden: hide it now rather than wait for the next frame's
		-- re-assert, so a part is never drawn for the frame it appears in. (Since task 151 round 3
		-- the hide IS written every frame -- see the header -- so this is one frame of latency
		-- saved, not the only thing that would ever write it.)
		(part :: any).LocalTransparencyModifier = 1
	end
end

-- RESTORE BEFORE DROPPING. A part that leaves the character while the body is hidden must be put
-- back first: once it is out of the list, `setLocalBodyHidden(false)` never writes it again, and this
-- module is the only writer of LocalTransparencyModifier on the local character -- so it would stay
-- invisible for the rest of that life.
--
-- The reachable path is a player's: aim, then unequip the shotgun with `1` or backtick while the
-- right button is still down. The Tool reparents to the Backpack, its `Handle` leaves the character
-- at 1, the blend decays, and the gun is gone in third person until the player respawns. Review round
-- 1 of Task 47 found this; the old code could not do it, because it never removed anything.
local function forgetHiddenPart(part: Instance)
	local index = table.find(hiddenParts, part)
	if index == nil then
		return
	end
	table.remove(hiddenParts, index)
	if hiddenNow then
		(part :: any).LocalTransparencyModifier = 0
	end
end

local function watchCharacter(character: Model?)
	if hiddenAdded then
		hiddenAdded:Disconnect()
		hiddenAdded = nil
	end
	if hiddenRemoving then
		hiddenRemoving:Disconnect()
		hiddenRemoving = nil
	end
	table.clear(hiddenParts)
	hiddenFor = character
	hiddenNow = nil
	if character == nil then
		return
	end
	for _, part in ipairs(character:GetDescendants()) do
		trackHiddenPart(part)
	end
	hiddenAdded = character.DescendantAdded:Connect(trackHiddenPart)
	hiddenRemoving = character.DescendantRemoving:Connect(forgetHiddenPart)
end

function Rig.setLocalBodyHidden(hidden: boolean)
	local character = Players.LocalPlayer.Character
	if not character then
		if hiddenFor ~= nil then
			watchCharacter(nil)
		end
		return
	end
	if hiddenFor ~= character then
		watchCharacter(character)
	end
	-- SHOWING AGAIN IS STILL WRITTEN ONCE, on the change: nothing else is trying to HIDE the local
	-- body, so there is nobody to fight and a per-frame write would be a cost with no effect.
	if hidden == false then
		if hiddenNow == false then
			return
		end
		hiddenNow = false
		for _, part in ipairs(hiddenParts) do
			(part :: any).LocalTransparencyModifier = 0
		end
		return
	end
	-- HIDING IS WRITTEN EVERY FRAME, against the stock TransparencyController (see the header above).
	if hiddenNow ~= true then
		hiddenNow = true
	else
		reassertions += 1
	end
	for _, part in ipairs(hiddenParts) do
		(part :: any).LocalTransparencyModifier = 1
	end
end

-- How many frames this module has had to write the local body hidden AGAIN after the first one.
-- Zero over a session would mean the second writer had gone away and the per-frame write could go
-- with it; it is not zero today, and the number is how anybody would find out.
function Rig.reassertions(): number
	return reassertions
end

-- How many parts the local body's cache is holding, for the spec that proves a part arriving after
-- the cache is still hidden. Read-only.
function Rig.hiddenPartCount(): number
	return #hiddenParts
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
