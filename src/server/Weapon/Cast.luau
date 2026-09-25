--!strict
-- Weapon.Cast: the ONLY caller of Workspace:Raycast in this system (design section 13.5). Every
-- other module takes a cast function as a parameter, so every other module is testable with no
-- world, and a grep for Workspace:Raycast under src/server/Weapon/ should find this file alone.
--
-- Pattern: RaycastParams with FilterType = Exclude, rebuilt per call from the caller's ignore list.
--   https://create.roblox.com/docs/reference/engine/datatypes/RaycastParams
--   https://create.roblox.com/docs/reference/engine/classes/WorldRoot#Raycast
-- Per call rather than one reused params object: the list differs per shooter, and a shared
-- mutable params object is a second writer waiting to happen.
--
-- Design: docs/design/shotgun.md (sections 5.3, 5.5)
local Workspace = game:GetService("Workspace")

local Cast = {}

function Cast.world(origin: Vector3, direction: Vector3, ignore: { Instance })
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local result = Workspace:Raycast(origin, direction, params)
	if not result then
		return nil
	end
	return {
		instance = result.Instance,
		position = result.Position,
		normal = result.Normal,
		distance = result.Distance,
	}
end

return Cast
