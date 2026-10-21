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

-- THE HORN'S NAME, AND NOTHING ELSE FROM IT (task 220). `Input.blowHorn` has to find a Tool called
-- `Horn.TOOL_NAME` among the ones the player carries, and the literal "Horn" in a second file is
-- how two modules come to disagree about one Tool. `src/client/Hud/init.luau` already requires this
-- same module, `Horn` requires only `Shotgun`, and there is no cycle.
local Horn = require(ReplicatedStorage:WaitForChild("Horn"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

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

-- THE TAGGED HOLD (drive-report design section 4.3). While any tag is out, every one of this module's
-- four handlers still RUNS and still returns `Pass` -- it simply does not act.
--
-- WHY IT HAS TO EXIST. With the report panel open the cursor is free and the player clicks a row. The
-- handlers are still bound and every one of them returns `Pass` by design (see the header: sinking
-- MouseButton2 would break the stock camera and sinking MouseButton1 would swallow the Task 6 input
-- probe) -- so without this, clicking a row in the report would also fire the gun. Relying on a
-- `TextButton` to swallow the click is a guess about engine behaviour, and `GuiButton.Modal` would
-- free the mouse itself and fight `Camera.Cursor`, which is the one writer of `MouseBehavior`.
--
-- IT IS A REQUEST AND THE OWNER RESOLVES IT, borrowed verbatim from this repo's own
-- `Camera.Cursor.requestFree`: a caller states a need under a tag it owns, several callers can hold at
-- once, and `Input` is still the only firer of `FireRequest` and `ActionRequest`. The one caller today
-- is `Hud.ReportPanel`, with the tag "report".
local holds: { [string]: boolean } = {}

-- Entering the held state clears the aim, exactly as `unbind()` does -- a trigger that cannot fire
-- must not leave the viewmodel shouldered either.
local function dropAim()
	if aiming then
		aiming = false
		signal:Fire(false)
	end
end

function Input.requestHold(tag: string)
	assert(type(tag) == "string" and tag ~= "", "Input.requestHold needs a non-empty tag")
	if holds[tag] then
		return
	end
	holds[tag] = true
	dropAim()
end

function Input.releaseHold(tag: string)
	assert(type(tag) == "string" and tag ~= "", "Input.releaseHold needs a non-empty tag")
	holds[tag] = nil
end

function Input.isHeld(): boolean
	return next(holds) ~= nil
end

-- Sorted, so a spec reads a stable list and not a hash order.
function Input.holdTags(): { string }
	local tags = {}
	for tag in pairs(holds) do
		table.insert(tags, tag)
	end
	table.sort(tags)
	return tags
end

local function remotes()
	return Shotgun.remotes()
end

-- THE SHOT, AS A PUBLIC FUNCTION, SO A BUTTON AND A MOUSE RUN ONE IMPLEMENTATION (task 220). This
-- is `Input.reload`'s shape applied to the trigger, and for the same reason task 165 gave: a thumb
-- has no MouseButton1, and mobile is in Karen's v1 plan. `Hud.Touch`'s FIRE button calls THIS
-- function -- not a copy of it, and not a second remote -- so there is exactly ONE firer of
-- `FireRequest` in the client and the touch door has nothing to drift from
-- (`tests/client/touch_controls.spec.luau` asserts the identity `Touch.actionFor("FIRE") ==
-- Input.fire`).
--
-- The camera ray: the client sends {origin, direction} and NOTHING else. There is no claimed
-- target, so there is nothing for the server to reconcile (design section 5.7).
--
-- THE HOLD IS CHECKED HERE and not in the caller, which is the point of moving it: a player must
-- not be able to shoot by tapping a button through an open report panel. Returns whether the
-- request actually went, so a caller can tell "refused" from "sent"; the key path ignores it,
-- exactly as it ignored the old `if`.
--
-- Design: docs/design/mobile-controls.md section 8.1
function Input.fire(): boolean
	if Input.isHeld() then
		return false
	end
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return false
	end
	local cframe = camera.CFrame
	remotes().FireRequest:FireServer({ origin = cframe.Position, direction = cframe.LookVector.Unit })
	return true
end

local function onFire(_name: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		Input.fire()
	end
	return Enum.ContextActionResult.Pass
end

-- RELOAD AND THE AMMO SWITCH AS PUBLIC FUNCTIONS, SO A BUTTON AND A KEY RUN ONE IMPLEMENTATION
-- (task 165). Karen, 2026-10-12: *"could be buttons on the side for M - map ect"*, and mobile is in
-- v1 -- a thumb has no R and no X. `Hud.Rail` calls these; `onReload` and `onSelectAmmo` below are
-- now two lines each and call the same thing.
--
-- THE HOLD IS CHECKED HERE AND NOT IN THE CALLER, which is the point of moving it: a player must not
-- be able to reload by tapping a button through an open report panel, and `Input.requestHold`'s own
-- header says that is what the hold is for. One site for the rule, two doors onto it.
--
-- `Input` IS STILL THE ONLY FIRER OF `ActionRequest` in the client. The Hud READS `Weapon.Input` --
-- it already does, for `ReportPanel`'s `requestHold` -- and `Input` has no reference to the Hud.
--
-- Returns whether the request actually went, so a caller can tell "refused, something is holding
-- input" from "sent". The key path ignores it, exactly as it ignored the old `if`.
function Input.reload(): boolean
	if Input.isHeld() then
		return false
	end
	remotes().ActionRequest:FireServer("Reload")
	return true
end

-- THE OTHER SHELL, whichever it is. The CHOICE is the client's and the RULE is the server's: it
-- answers "NO BUCK" through the weapon's own notice when the pocket is empty.
function Input.selectAmmo(): boolean
	if Input.isHeld() then
		return false
	end
	local Weapon = require(script.Parent)
	local current = Weapon.get()
	local other = if current and current.ammo == "Slug" then "Buck" else "Slug"
	remotes().ActionRequest:FireServer("SelectAmmo", other)
	return true
end

-- ---------------------------------------------------------------- the thumb's two doors (task 220)
--
-- A PHONE HAS NO HOTBAR WORTH THE NAME AND NO CLICK ON A HELD TOOL. Everything below is a SECOND
-- DOOR onto something the engine already does for a desktop player, and neither door adds a remote:
-- both engine facts were MEASURED in a live DEV session on 2026-10-21 rather than remembered, and
-- the measurements are in `reviews/task-220/BRIEF.md` section 0.
--
--   M1  `tool:Activate()` from a LocalScript fires the SERVER's `Tool.Activated` -- two calls in,
--       `SERVER activated=2` out. That is the whole of BLOW: `Weapon.Horn.grant` connects
--       `tool.Activated` on the server and that connection is the one accepted blast path.
--   M2  `Humanoid:EquipTool(tool)` from a LocalScript moves the Tool into the CHARACTER on the
--       server (`parentBefore=Backpack`, `toolInCharacter=true`). That is the whole of SWAP.
--
--   Tool:Activate       https://create.roblox.com/docs/reference/engine/classes/Tool#Activate
--   Humanoid:EquipTool  https://create.roblox.com/docs/reference/engine/classes/Humanoid#EquipTool
--
-- Design: docs/design/mobile-controls.md section 8.2
-- Note:   docs/research/2026-10-20-mobile-controls.md

-- WHICH TOOL COMES NEXT, PURE, so a spec drives the order with no Tools and no character at all.
-- `names` is sorted ascending; the answer is the one after `current`, wrapping; the FIRST when
-- `current` is nil or is not in the list; nil when there are fewer than two names.
function Input.nextToolName(names: { string }, current: string?): string?
	if #names < 2 then
		return nil
	end
	if current ~= nil then
		for index, name in ipairs(names) do
			if name == current then
				return names[if index == #names then 1 else index + 1]
			end
		end
	end
	return names[1]
end

-- WHAT THIS PLAYER IS CARRYING, in ONE walk of the Backpack and the character. Every Tool, by name,
-- SORTED -- and sorted is the point: the engine's own child order moves every time a Tool is
-- equipped (it crosses from the Backpack to the character and back), so an order read off the tree
-- would put a different gun under the same button on two consecutive taps.
--
-- IT READS THE TREE AND NOT `Weapons.ORDER`, AND NOT ANY OWNERSHIP SET (design section 2.2). The
-- server already decided which guns this player carries -- `Weapons.loadout` applied `OWNED_ONLY`
-- when it granted them (tasks 224 and 225) -- so the Tools in his hands ARE the owned-only answer,
-- delivered as Instances. A second consultation here would be a second answer to "which guns are
-- his", which is the fault CLAUDE.md rule 3 exists for.
--
-- EVERY Tool, not only a gun: the beater's horn is a Tool he carries and SWAP must reach it.
function Input.carriedSummary(): { count: number, hasHorn: boolean, equipped: string?, names: { string } }
	local player = Players.LocalPlayer
	local names: { string } = {}
	local hasHorn = false
	local equipped: string? = nil
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack ~= nil then
		for _, child in ipairs((backpack :: Backpack):GetChildren()) do
			if child:IsA("Tool") then
				table.insert(names, child.Name)
				hasHorn = hasHorn or Horn.isToolName(child.Name)
			end
		end
	end
	local character = player.Character
	if character ~= nil then
		for _, child in ipairs((character :: Model):GetChildren()) do
			if child:IsA("Tool") then
				table.insert(names, child.Name)
				hasHorn = hasHorn or Horn.isToolName(child.Name)
				-- A Tool parented to the CHARACTER is an equipped one -- that is how Roblox equips,
				-- and it is the same test `equippedWeapon()` below makes.
				equipped = child.Name
			end
		end
	end
	table.sort(names)
	return { count = #names, hasHorn = hasHorn, equipped = equipped, names = names }
end

-- THE TOOL ITSELF, by name, from the same two containers. Private: the two functions below are its
-- only callers, and nothing outside this module should be handed an Instance it might keep.
local function carriedTool(name: string): Tool?
	local player = Players.LocalPlayer
	local character = player.Character
	if character ~= nil then
		local found = (character :: Model):FindFirstChild(name)
		if found ~= nil and found:IsA("Tool") then
			return found :: Tool
		end
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack ~= nil then
		local found = (backpack :: Backpack):FindFirstChild(name)
		if found ~= nil and found:IsA("Tool") then
			return found :: Tool
		end
	end
	return nil
end

-- NEXT WEAPON, ONE TAP. Refused while something holds input, for `Input.reload`'s reason: a player
-- must not change guns by tapping through an open report panel.
--
-- `UnequipTools()` FIRST, and that is not tidiness. M2 measured `EquipTool` from a LocalScript with
-- the Tool in the BACKPACK and nothing in the hand; "EquipTool while another Tool is held" was NOT
-- measured, so this puts the swap into exactly the state that was. The live spec case proves the
-- outcome in the gate either way.
function Input.swap(): boolean
	if Input.isHeld() then
		return false
	end
	local summary = Input.carriedSummary()
	local wanted = Input.nextToolName(summary.names, summary.equipped)
	if wanted == nil then
		return false
	end
	local character = Players.LocalPlayer.Character
	local humanoid = if character ~= nil then (character :: Model):FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil then
		return false
	end
	local tool = carriedTool(wanted :: string)
	if tool == nil then
		return false
	end
	(humanoid :: Humanoid):UnequipTools();
	(humanoid :: Humanoid):EquipTool(tool :: Tool)
	return true
end

-- A BLAST, ONE TAP. It equips the horn first and then activates it, which is precisely the two
-- steps a desktop beater performs (the hotbar, then a click) -- and both halves are measured, so
-- neither is a capability the mouse door lacks.
--
-- THE COOLDOWN IS NOT RE-IMPLEMENTED HERE. `Horn.blow` holds it on the server and refuses a tap
-- inside it exactly as it refuses a click; the chip draws the readiness bar from the attribute the
-- server stamps. A client-side gate would be a second answer to "is this horn ready".
function Input.blowHorn(): boolean
	if Input.isHeld() then
		return false
	end
	local tool = carriedTool(Horn.TOOL_NAME)
	if tool == nil then
		return false
	end
	local character = Players.LocalPlayer.Character
	if character ~= nil and (tool :: Tool).Parent ~= character then
		local humanoid = (character :: Model):FindFirstChildOfClass("Humanoid")
		if humanoid ~= nil then
			(humanoid :: Humanoid):UnequipTools();
			(humanoid :: Humanoid):EquipTool(tool :: Tool)
		end
	end
	-- M1 additionally showed `Activate()` reaching the server with the Tool still in the Backpack,
	-- so a blast is not lost if the equip has not settled in this frame.
	(tool :: Tool):Activate()
	return true
end

local function onReload(_name: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		Input.reload()
	end
	return Enum.ContextActionResult.Pass
end

local function onSelectAmmo(_name: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		Input.selectAmmo()
	end
	return Enum.ContextActionResult.Pass
end

-- THE AIM FLAG, AS A PUBLIC FUNCTION THAT TAKES THE VALUE (task 220). The mouse's Begin and End
-- are `setAim(true)` and `setAim(false)`; the thumb's one tap is `toggleAim()`. ONE flag, ONE
-- signal, two callers with different arguments -- so a touch AIM cannot drift from a mouse AIM,
-- because there is nothing for it to drift from. `Input.AimChanged` is unchanged, so `CameraBoot`'s
-- `setAimSource` sees a toggle and a hold as the same fact and the ADS path needs no edit.
--
-- WHY THE TWO DOORS BEHAVE DIFFERENTLY, and it is the one place in this task that they do: on a
-- phone the right thumb IS the camera (the drag is the only look control), so a HELD aim would pin
-- the one finger that aims and leave none for the trigger. A toggle costs one tap and frees the
-- thumb. Karen's to overrule (design section 16, K-6).
--
-- HELD MEANS "NOT SHOULDERED", not "frozen": a Begin that arrives while a panel is open is dropped,
-- and `requestHold` has already cleared any aim that was live when it opened.
--
-- Design: docs/design/mobile-controls.md section 8.1
function Input.setAim(on: boolean): boolean
	if Input.isHeld() then
		return false
	end
	if on ~= aiming then
		aiming = on
		signal:Fire(aiming)
	end
	return true
end

function Input.toggleAim(): boolean
	return Input.setAim(not aiming)
end

-- Nothing visible happens in this module: the flag and the signal are the whole of it, and the
-- camera keeps doing what it does while the button is held.
local function onAim(_name: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin or state == Enum.UserInputState.End then
		Input.setAim(state == Enum.UserInputState.Begin)
	end
	return Enum.ContextActionResult.Pass
end

-- WHICH Tool the actions belong to. Before pruning existed, "there is only ever one Tool" was true
-- enough for `forgetTool` to unbind unconditionally; now that a stale Tool can be dropped while the
-- live one is in the player's hands, unbinding on its way out would take the player's own trigger
-- with it (review of Task 48).
local boundTo: Instance? = nil

-- THE WEAPON THE PLAYER IS ACTUALLY HOLDING, or nil. A Tool parented to the CHARACTER is an
-- equipped one -- that is how Roblox equips -- so this is the live answer to "is there still a
-- trigger to bind", read off the tree rather than off a table that can be a signal behind.
local function equippedWeapon(): Tool?
	local character = Players.LocalPlayer.Character
	for _, child in ipairs(if character then character:GetChildren() else {}) do
		if child:IsA("Tool") and Weapons.isToolName(child.Name) then
			return child
		end
	end
	return nil
end

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
	--
	-- ...AND "ONLY FOR THAT TOOL" IS NOT ENOUGH ON ITS OWN (task 152). This runs on `Destroying`
	-- too, and it disconnects the hooks ABOVE -- so the Tool's own `Unequipped` handler never gets
	-- to say "there is still a weapon in the hand". MEASURED: a second weapon-named Tool equipped
	-- and destroyed took the four actions from `Aim,Fire,Reload,SelectAmmo` to `NONE` with the real
	-- gun still in the player's character. The rule is the same one stated there: the actions belong
	-- to whatever weapon IS in the hand, and only a player holding none loses them.
	if boundTo == tool then
		local still = equippedWeapon()
		if still ~= nil and still ~= tool then
			bind(still)
		else
			unbind()
		end
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
	-- ANY TOOL THIS SYSTEM OWNS (task 140), from the table rather than from a literal here: with two
	-- weapons a player carries two Tools, and the machinery below was already written for a dead
	-- Tool coexisting with a live one -- `bind(tool)` records which Tool the four actions belong to,
	-- `Tool.Unequipped` unbinds, and `forgetTool` unbinds only when it was the bound one.
	if not tool:IsA("Tool") or not Weapons.isToolName(tool.Name) then
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
	-- ...AND IT UNBINDS ONLY FOR THE TOOL THE ACTIONS BELONG TO. This line used to be
	-- `tool.Unequipped:Connect(unbind)`, which took ALL FOUR actions away whichever Tool had just
	-- left -- the exact hazard `forgetTool` below already guards against, with a comment saying why,
	-- written when there was only ever one Tool to lose.
	--
	-- IT IS REACHABLE BY A PLAYER, not only by a test. With `RIFLE` on (it is) a player carries two
	-- Tools, and Roblox's signals are DEFERRED -- this file says so twice. On a hotbar switch, if
	-- `Equipped(rifle)` runs before `Unequipped(shotgun)`, the unbind took the trigger that had just
	-- been bound for the rifle: no fire, no reload, no aim and no ammo switch until the player
	-- equipped something again.
	--
	-- MEASURED in a Play session, task 152 (the four `DrivenHunt.Weapon.*` actions, by name):
	--     before a second weapon-named Tool   Aim,Fire,Reload,SelectAmmo
	--     it is equipped                      Aim,Fire,Reload,SelectAmmo
	--     it is destroyed                     NONE   <- with the real gun still in the character
	-- and that is what cost `zz_tie_to_a_tree` its shot: `R` reached nothing, the gun stayed
	-- Spent/Spent, no shot was fired and so no violation was ever judged.
	table.insert(
		hooks,
		tool.Unequipped:Connect(function()
			-- THE ACTIONS BELONG TO WHATEVER WEAPON IS STILL IN THE HAND, and that is the rule this
			-- line now states. It used to be `tool.Unequipped:Connect(unbind)`, which took ALL FOUR
			-- away whichever Tool had just left.
			local still = equippedWeapon()
			if still ~= nil then
				bind(still)
			elseif boundTo == tool then
				unbind()
			end
		end)
	)
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

-- How many Tools this client is still listening to. As many as the loadout has -- two since the RIFLE flag was lit in task 149; a spec reads it to prove the
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
