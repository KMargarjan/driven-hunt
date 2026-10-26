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

-- HOW FAR PAST A PASSED-THROUGH SURFACE THE NEXT CAST STARTS, in studs. A ray whose origin is INSIDE
-- a part does not hit that part, so stepping a thousandth of a stud past the surface is what makes
-- the trunk transparent -- and it has to be done this way round. The first attempt EXCLUDED the
-- trunk instead and it was wrong for a reason worth writing down: `FilterDescendantsInstances` means
-- "these instances AND THEIR DESCENDANTS", and every zone part is a CHILD of the trunk, so excluding
-- the trunk excluded the twelve volumes behind it and a chest shot answered nothing at all (the
-- harness said so: *"chest box 1 answered no zone at its own centre"*, all three kinds).
--
-- 1e-3 is three orders above float noise on a 40-stud segment and four below the thinnest volume any
-- animal carries (a deer's leg is 0.12 studs through).
Cast.PASS_THROUGH_STEP = 1e-3

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
	-- `ignore` IS NEITHER MODIFIED NOR ADDED TO, which is the contract `Weapon.Flight` states ("the
	-- SAME table the trigger built; never modified here") -- and also, as `PASS_THROUGH_STEP` says,
	-- the only thing that can work: the zone volumes are CHILDREN of the trunk, so no filter can
	-- exclude the trunk without excluding them. The same `params` object is reused for every
	-- continuation, so a shot that passes through something allocates nothing extra at all.
	local passes = 0
	while result ~= nil and passes < Cast.MAX_PASS_THROUGH and Hits.passesThrough(result.Instance) do
		passes += 1
		-- The rest of the SAME segment, from a thousandth of a stud past this surface. `distance`
		-- below stays the distance from the CALLER'S own origin, because every caller treats it as
		-- that (`Flight` adds it to `pellet.travelled`, `Hits.group` picks the nearest impact of a
		-- pattern by it, and `HitLog` prints it as the range of the shot).
		travelled += result.Distance + Cast.PASS_THROUGH_STEP
		local left = direction.Magnitude - travelled
		if left <= 1e-6 then
			return nil
		end
		from = result.Position + direction.Unit * Cast.PASS_THROUGH_STEP
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
