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

-- WHICH Tool the actions belong to. Before pruning existed, "there is only ever one Tool" was true
-- enough for `forgetTool` to unbind unconditionally; now that a stale Tool can be dropped while the
-- live one is in the player's hands, unbinding on its way out would take the player's own trigger
-- with it (review of Task 48).
local boundTo: Instance? = nil

local function bind(tool: Instance?)
	boundTo = tool
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
	boundTo = nil
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

-- One entry per Tool this client is listening to, holding that Tool's own connections. It is a
-- table and not a `true` because of TASKS.md 24a(c): a respawn or a revoke DESTROYS the Tool, and
-- with the connections in the module-wide list and the key never removed, every respawn left one
-- dead Tool pinned here and two more connections behind it, cleared only by Input.stop(), which
-- nothing calls. Now the Tool's own departure takes both with it.
local watched: { [Instance]: { RBXScriptConnection } } = {}

local function forgetTool(tool: Instance)
	local hooks = watched[tool]
	if not hooks then
		return
	end
	watched[tool] = nil
	for _, connection in ipairs(hooks) do
		connection:Disconnect()
	end
	-- AND UNBIND, but only for the Tool the actions actually belong to. Disconnecting the hooks takes
	-- the Unequipped handler with them, so a Tool destroyed while equipped -- which is what a revoke
	-- does -- would otherwise leave the DrivenHunt.Weapon.* actions bound with nothing in the player's
	-- hands. It used to unbind unconditionally on the grounds that there is only ever one Tool; with
	-- pruning below, a DEAD Tool can be forgotten while the live one is equipped, and unbinding then
	-- would take the player's own trigger away.
	if boundTo == tool then
		unbind()
	end
end

-- IS THIS TOOL STILL THE PLAYER'S? A Tool the client should listen to is in the player's CURRENT
-- Backpack or CURRENT character. Anything else -- destroyed, or hanging off the character a respawn
-- replaced -- is dead to this client.
local function isLive(tool: Instance): boolean
	if not tool:IsDescendantOf(game) then
		return false
	end
	local player = Players.LocalPlayer
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	return (backpack ~= nil and tool:IsDescendantOf(backpack)) or (character ~= nil and tool:IsDescendantOf(character))
end

-- THE INVARIANT IS ENFORCED WHERE THE SET IS WRITTEN (Director, Task 48, after `test2` failed twice in
-- three runs on `watchedTools() <= 1`). A dead Tool used to be dropped only by its own
-- `AncestryChanged` with `parent == nil`, and Roblox's signals are DEFERRED (measured in Task 47), so
-- on a respawn the new Tool -- granted by the server on `CharacterAdded` and delivered through the new
-- Backpack's `ChildAdded` -- was watched BEFORE the old one's handler ran. For that moment two Tools
-- were watched, and any spec sampling there read 2. Worse, a Tool whose parent never becomes nil (it
-- moves elsewhere instead) was never forgotten at all.
--
-- So the set is swept before anything is added to it: no new Tool can be watched while a dead one is
-- still in the table, whatever order the signals arrive in.
local function pruneWatched()
	for tool in pairs(watched) do
		if not isLive(tool) then
			forgetTool(tool)
		end
	end
end

local function watchTool(tool: Instance)
	if not tool:IsA("Tool") or tool.Name ~= "Shotgun" then
		return
	end
	pruneWatched()
	-- The Tool moves between the Backpack and the character every time it is equipped, and both
	-- containers report it as a new child. Bind its events once (round 1 note).
	if watched[tool] then
		return
	end
	local hooks: { RBXScriptConnection } = {}
	watched[tool] = hooks
	table.insert(
		hooks,
		tool.Equipped:Connect(function()
			bind(tool)
		end)
	)
	table.insert(hooks, tool.Unequipped:Connect(unbind))
	-- Parent nil is how a Tool leaves: Hardware.destroy unparents and destroys it, and a respawn
	-- takes the old one with the old character. ChildAdded watches it again if it ever comes back.
	-- `Destroying` catches the destroy itself, and both are belt and braces over `pruneWatched`.
	table.insert(
		hooks,
		tool.AncestryChanged:Connect(function()
			if not isLive(tool) then
				forgetTool(tool)
			end
		end)
	)
	table.insert(
		hooks,
		tool.Destroying:Connect(function()
			forgetTool(tool)
		end)
	)
	if tool.Parent == Players.LocalPlayer.Character then
		bind(tool)
	end
end

-- How many Tools this client is still listening to. One, normally; a spec reads it to prove the
-- count does not climb with respawns.
function Input.watchedTools(): number
	local n = 0
	for _ in pairs(watched) do
		n += 1
	end
	return n
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
	for tool in pairs(watched) do
		forgetTool(tool)
	end
end

return Input
