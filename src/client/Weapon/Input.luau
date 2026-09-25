--!strict
-- PlayerScripts.Weapon.Input: the ONLY binder of the DrivenHunt.Weapon.* actions and the ONLY
-- firer of FireRequest / ActionRequest. The prefix is reserved to this system: a grep for
-- "DrivenHunt.Weapon." finds every binding it owns, and no other system may use it.
--
-- EVERY handler returns Pass, deliberately (design section 2.3 item 5):
--   * Sink on MouseButton2 would break the stock camera's own rotation -- and the camera is not
--     this system's to own (ROADMAP 1.4b);
--   * Sink on MouseButton1 or R would swallow the Task 6 input probe, which binds the same inputs
--     and is the harness's evidence that input arrives at all.
-- Tool.Activated is NOT the fire path: it carries no payload, so the server would learn that a
-- shot happened but not where it pointed.
--   ContextActionService  https://create.roblox.com/docs/reference/engine/classes/ContextActionService
--   Camera.CFrame (read)  https://create.roblox.com/docs/reference/engine/classes/Camera
--
-- This module READS workspace.CurrentCamera.CFrame and never writes it, or CameraType, FieldOfView,
-- CameraSubject, MouseBehavior or MouseIconEnabled. AimChanged is the one seam the camera/ADS task
-- attaches to (design section 9).
--
-- Design: docs/design/shotgun.md (sections 3.2, 5.6, 9)
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Input = {}

local FIRE = "DrivenHunt.Weapon.Fire"
local RELOAD = "DrivenHunt.Weapon.Reload"
local SELECT_AMMO = "DrivenHunt.Weapon.SelectAmmo"
local AIM = "DrivenHunt.Weapon.Aim"

local aiming = false
local bound = false
local started = false
local connections: { RBXScriptConnection } = {}

local signal = Instance.new("BindableEvent")
Input.AimChanged = signal.Event

function Input.isAiming(): boolean
	return aiming
end

local function remotes()
	return Shotgun.remotes()
end

-- The camera ray: the client sends {origin, direction} and NOTHING else. There is no claimed
-- target, so there is nothing for the server to reconcile (design section 5.7).
local function onFire(_name: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		local camera = Workspace.CurrentCamera
		if camera then
			local cframe = camera.CFrame
			remotes().FireRequest:FireServer({ origin = cframe.Position, direction = cframe.LookVector.Unit })
		end
	end
	return Enum.ContextActionResult.Pass
end

local function onReload(_name: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		remotes().ActionRequest:FireServer("Reload")
	end
	return Enum.ContextActionResult.Pass
end

local function onSelectAmmo(_name: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		local Weapon = require(script.Parent)
		local current = Weapon.get()
		local other = if current and current.ammo == "Slug" then "Buck" else "Slug"
		remotes().ActionRequest:FireServer("SelectAmmo", other)
	end
	return Enum.ContextActionResult.Pass
end

-- Nothing visible happens in this task: the flag and the signal are the whole of it, and the stock
-- camera keeps doing what it does while the button is held.
local function onAim(_name: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin or state == Enum.UserInputState.End then
		local next = state == Enum.UserInputState.Begin
		if next ~= aiming then
			aiming = next
			signal:Fire(aiming)
		end
	end
	return Enum.ContextActionResult.Pass
end

local function bind()
	if bound then
		return
	end
	bound = true
	ContextActionService:BindAction(FIRE, onFire, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:BindAction(RELOAD, onReload, false, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
	ContextActionService:BindAction(SELECT_AMMO, onSelectAmmo, false, Enum.KeyCode.X, Enum.KeyCode.DPadLeft)
	ContextActionService:BindAction(AIM, onAim, false, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)
end

local function unbind()
	if not bound then
		return
	end
	bound = false
	for _, name in ipairs({ FIRE, RELOAD, SELECT_AMMO, AIM }) do
		ContextActionService:UnbindAction(name)
	end
	if aiming then
		aiming = false
		signal:Fire(false)
	end
end

local watched: { [Instance]: boolean } = {}

local function watchTool(tool: Instance)
	if not tool:IsA("Tool") or tool.Name ~= "Shotgun" then
		return
	end
	-- The Tool moves between the Backpack and the character every time it is equipped, and both
	-- containers report it as a new child. Bind its events once (round 1 note).
	if watched[tool] then
		return
	end
	watched[tool] = true
	table.insert(connections, tool.Equipped:Connect(bind))
	table.insert(connections, tool.Unequipped:Connect(unbind))
	if tool.Parent == Players.LocalPlayer.Character then
		bind()
	end
end

function Input.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer

	local function watchContainer(container: Instance?)
		if not container then
			return
		end
		table.insert(connections, container.ChildAdded:Connect(watchTool))
		for _, child in ipairs(container:GetChildren()) do
			watchTool(child)
		end
	end

	watchContainer(player:FindFirstChildOfClass("Backpack"))
	table.insert(
		connections,
		player.ChildAdded:Connect(function(child)
			if child:IsA("Backpack") then
				watchContainer(child)
			end
		end)
	)
	local function watchCharacter(character: Model)
		watchContainer(character)
	end
	table.insert(connections, player.CharacterAdded:Connect(watchCharacter))
	if player.Character then
		watchCharacter(player.Character)
	end
end

function Input.stop()
	started = false
	unbind()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end

return Input
