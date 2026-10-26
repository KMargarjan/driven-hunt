--!strict
-- Weapon.Cast: the ONLY caller of `Shotgun.Pierce.cast` in this system (design section 13.5), which
-- is in turn the only thing under `Shotgun` that calls `Workspace:Raycast`. Every other module takes
-- a cast function as a parameter, so every other module is testable with no world, and a grep for
-- `Pierce.cast` under src/server/Weapon/ should find this file alone.
--
-- Pattern: RaycastParams with FilterType = Exclude, rebuilt per call from the caller's ignore list.
--   https://create.roblox.com/docs/reference/engine/datatypes/RaycastParams
--   https://create.roblox.com/docs/reference/engine/classes/WorldRoot#Raycast
-- Per call rather than one reused params object: the list differs per shooter, and a shared
-- mutable params object is a second writer waiting to happen.
--
-- IT USED TO CALL `Workspace:Raycast` ITSELF (task 280). It does not any more, because a bullet goes
-- THROUGH a `ZonesOnly` animal's own trunk and the client's claim cast has to go through it in
-- exactly the same way -- and two copies of that rule, one per side, is the disagreement this
-- project is built around. `Shotgun.Pierce` owns it; this file still owns the ignore list and the
-- shape of the params, which is what "one caller" was ever protecting.
--
-- Design: docs/design/shotgun.md (sections 5.3, 5.5)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pierce = require(ReplicatedStorage:WaitForChild("Shotgun"):WaitForChild("Pierce"))

local Cast = {}

function Cast.world(origin: Vector3, direction: Vector3, ignore: { Instance })
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local hit = Pierce.cast(params, origin, direction)
	if not hit then
		return nil
	end
	return {
		instance = hit.instance,
		position = hit.position,
		normal = hit.normal,
		distance = hit.distance,
		-- WHAT THE PELLET LANDED ON (task 249), so the client can draw soil off the floor and
		-- splinters off a trunk rather than one glowing box for both. `RaycastResult.Material` is
		-- the surface's own material -- the terrain's where it hit terrain, the part's where it hit
		-- a part -- and it is the only thing this returns that is not geometry.
		--   https://create.roblox.com/docs/reference/engine/classes/RaycastResult#Material
		material = hit.material,
	}
end

return Cast
