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

local Hits = require(script.Parent.Hits)

local Cast = {}

-- HOW MANY SURFACES ONE CAST MAY PASS THROUGH (task 280). A ray entering a box meets its surface
-- once, so one deer costs one pass-through and a file of them nose to tail costs one each; four is
-- above anything a single 40-stud flight segment can line up and is a bound rather than a loop that
-- trusts the world. `Hits.passesThrough` says WHICH surfaces, and why.
Cast.MAX_PASS_THROUGH = 4

function Cast.world(origin: Vector3, direction: Vector3, ignore: { Instance })
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local from, remaining, travelled = origin, direction, 0
	local result = Workspace:Raycast(from, remaining, params)
	-- THE BULLET GOES THROUGH A `ZonesOnly` ANIMAL'S OWN BOX (task 280, and the measurement is in
	-- `Hits.passesThrough`): a red deer's trunk is the volume the physics simulates and is wider
	-- than every zone inside it, so without this the nearest surface on every flank shot is the
	-- TRUNK -- the bullet would stop a fifth of a stud short of the chest and register nothing.
	--
	-- `ignore` IS NOT MODIFIED, and that is the contract `Weapon.Flight` states ("the SAME table the
	-- trigger built; never modified here"). A COPY is made only on the step that actually passes
	-- through something, so the common path -- every shot that hits a tree, the ground or a boar --
	-- allocates exactly what it allocated before this task.
	local passes = 0
	while result ~= nil and passes < Cast.MAX_PASS_THROUGH and Hits.passesThrough(result.Instance) do
		passes += 1
		local skip = table.clone(params.FilterDescendantsInstances)
		table.insert(skip, result.Instance)
		params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = skip
		params.IgnoreWater = true
		-- The rest of the SAME segment, measured from where this surface was: `distance` below is
		-- still the distance from the caller's own origin, because every caller treats it as that
		-- (`Flight` adds it to `pellet.travelled`, `Hits.group` picks the nearest impact of a
		-- pattern by it, and `HitLog` prints it as the range of the shot).
		travelled += result.Distance
		local left = direction.Magnitude - travelled
		if left <= 1e-6 then
			return nil
		end
		from = result.Position
		remaining = direction.Unit * left
		result = Workspace:Raycast(from, remaining, params)
	end
	if not result then
		return nil
	end
	return {
		instance = result.Instance,
		position = result.Position,
		normal = result.Normal,
		distance = travelled + result.Distance,
		-- WHAT THE PELLET LANDED ON (task 249), so the client can draw soil off the floor and
		-- splinters off a trunk rather than one glowing box for both. `RaycastResult.Material` is
		-- the surface's own material -- the terrain's where it hit terrain, the part's where it hit
		-- a part -- and it is the only thing this returns that is not geometry.
		--   https://create.roblox.com/docs/reference/engine/classes/RaycastResult#Material
		material = result.Material,
	}
end

return Cast
