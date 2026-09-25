--!strict
-- Weapon.Hardware: the ONLY writer of Tool Instances in this system. It builds the gun, hands it
-- over, and destroys it. It holds no state and touches no remote.
--
-- Everything positioned or coloured is built in code from Shotgun.CONFIG, not from a .rbxm (banned,
-- CLAUDE.md) and not from typed JSON property values (which the harness cannot compare yet,
-- TASKS.md row 16). Same choice as src/server/TestArena.luau and Boar.Body.
--   Tool        https://create.roblox.com/docs/reference/engine/classes/Tool
--   Attachment  https://create.roblox.com/docs/reference/engine/classes/Attachment
-- The muzzle is an Attachment, not a number re-derived at each call site: the server reads its
-- WorldPosition for the shot and the client reads the same Attachment for the flash, so the offset
-- is defined once and cannot drift between them (design section 8).
--
-- Design: docs/design/shotgun.md (section 8)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Hardware = {}

-- The name every granted Tool carries. One per player, so it is also how a stray one is found.
Hardware.TOOL_NAME = "Shotgun"

function Hardware.build(): Tool
	local config = Shotgun.CONFIG
	local tool = Instance.new("Tool")
	tool.Name = Hardware.TOOL_NAME
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Grip = config.GRIP

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = config.HANDLE_SIZE
	handle.Color = config.HANDLE_COLOR
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Anchored = false
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.CFrame = CFrame.new(config.MUZZLE_OFFSET)
	muzzle.Parent = handle

	return tool
end

-- The Backpack is where a Tool waits; the character is where it is held.
-- Puts the tool in the player's Backpack, and SAYS WHETHER IT LANDED.
--
-- IT NEVER YIELDS, and that is a requirement, not an implementation detail. It waited for the
-- Backpack for a while (Task 34) and that wait made the grant interleavable: while it was parked
-- the player held no tool, so every other caller -- the Backpack hook the wait was waiting for, and
-- the arming sweep -- decided to grant one too, and a player ended up with two Tools, only one of
-- them recorded. The same yield also parked the drive's Heartbeat step, which applies refreshArming
-- synchronously. A Backpack that is not there yet is covered by the hook that fires when it
-- arrives, which is what it is for.
function Hardware.give(tool: Tool, player: Player): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return false
	end
	tool.Parent = backpack
	return true
end

-- Every Tool of ours this player is carrying, Backpack and character both. Arming is one-tool-per
-- -player, and this is how that is enforced rather than assumed.
function Hardware.toolsOf(player: Player): { Tool }
	local found = {}
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child.Name == Hardware.TOOL_NAME then
					table.insert(found, child)
				end
			end
		end
	end
	return found
end

function Hardware.equip(tool: Tool, player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:EquipTool(tool)
	end
end

function Hardware.muzzlePosition(tool: Tool): Vector3?
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	local muzzle = handle and handle:FindFirstChild("Muzzle") :: Attachment?
	return muzzle and muzzle.WorldPosition
end

function Hardware.destroy(tool: Tool?)
	if tool then
		tool:Destroy()
	end
end

return Hardware
