--!strict
-- Shotgun.Pierce: THE NEAREST SURFACE A BULLET CAN REGISTER. One rule, three callers -- the server's
-- `Weapon.Cast.world`, and the client's `Weapon.Claim.world` and `Claim.only` -- because "what does
-- a bullet stop on" is one question and two answers to it is the failure this project is built
-- around (docs/PROJECT_CONTEXT.md, "Overlapping owners": *"Most of the worst bugs were two correct
-- pieces of code disagreeing"*).
--
-- IT LIVES IN ReplicatedStorage because the client asks it as well, and it is the only thing under
-- `Shotgun` that touches `Workspace`. The two headers that used to say "the ONLY caller of
-- `Workspace:Raycast`" now say "the only caller of `Pierce.cast`", which is the same guarantee one
-- level up: there is still exactly one place per side that decides what a shot met.
--
-- WHY A BULLET GOES THROUGH ANYTHING AT ALL (task 280). A red deer's physics trunk is
-- 1.8 x 4.8 x 7.05 studs -- the nose line to the rump, the back line to the hooves -- and the animal
-- does not fill it. Karen, 2026-10-26, on a FROZEN broadside hind at ~28 m: *"wrong I hit the chest
-- shows outside"*; the hit card drew its dot under her neck, in front of her chest, where nothing is
-- drawn. So the trunk declares `ZonesOnly` and only its named zone parts are targets -- and the
-- trunk's own SURFACE, which is nearer than every volume inside it, has to be stepped past or no
-- deer could be hit at all.
--
-- `CanQuery = false` IS NOT AN OPTION AND THAT IS MEASURED, not assumed. In a DEV Play session on
-- 2026-10-26, a 2 x 2 x 2 control part behind a 4 x 4 x 4 one
-- (`<runs-dir>/280-diag4.luau`), four rows, one variable at a time:
--     CanQuery=false, CanCollide=true  -> the big part is STILL returned by Workspace:Raycast
--     CanQuery=false, CanCollide=false -> it is skipped, and the control behind it is returned
-- and the same both ways round whether `CanQuery` is written before or after parenting. A deer's
-- trunk must collide -- it is the body the physics simulates. (`Boar.Body.attachVisual`'s own
-- `CanQuery = false` on the drawn mesh DOES work, because that mesh is `CanCollide = false`.)
--
-- AND IT CANNOT BE A FILTER EITHER. `RaycastParams.FilterDescendantsInstances` means "these
-- instances AND THEIR DESCENDANTS", and every zone part is a CHILD of the trunk -- so excluding the
-- trunk to get past it excludes the twelve volumes behind it. The harness said so in one line, on
-- all three deer kinds: *"chest box 1 answered no zone at its own centre"*. A ray whose ORIGIN is
-- inside a part does not hit that part, so the continuation starts a thousandth of a stud past the
-- surface instead, with the same `RaycastParams`.
--   Raycasting  https://create.roblox.com/docs/workspace/raycasting
--   RaycastParams  https://create.roblox.com/docs/reference/engine/datatypes/RaycastParams
--
-- Design: docs/design/hit-zones.md (section 4), docs/design/ballistics.md (section 2.1)
local Workspace = game:GetService("Workspace")

local Pierce = {}

-- HOW MANY SURFACES ONE CAST MAY PASS THROUGH. A ray entering a box meets its surface once, so one
-- deer costs one pass-through and a file of them nose to tail costs one each, so the bound is a
-- number about HOW MANY ANIMALS can stand in one sub-step. The longest sub-step in the game is the
-- rifle's, about 87 studs (`Weapon.Claim`'s own measurement), and `Boar.CONFIG.SOUNDER` spaces a
-- file 7.0 to 8.5 studs centre to centre -- so ten could line up in principle. FOUR is taken, and
-- what the fifth costs is a MISS on the animal behind four others, which is the safe way for this
-- to be wrong: a bullet that stops at nothing rather than one that hits through a herd. Queued as
-- 280a if a drive ever puts five trunks on one segment.
Pierce.MAX_PASS_THROUGH = 4

-- HOW FAR PAST A PASSED-THROUGH SURFACE THE NEXT CAST STARTS, in studs. Three orders above float
-- noise on a 40-stud segment and four below the thinnest volume any animal carries (a deer's leg is
-- 0.12 studs through).
Pierce.STEP = 1e-3

-- A SURFACE A BULLET GOES STRAIGHT THROUGH, as opposed to one it stops on.
--
-- IT IS NOT "this is not a target": a tree is not a target and a tree stops a bullet. This is the
-- narrow case of a surface that belongs to a `ZonesOnly` animal and is not one of its named zones --
-- its physics trunk, or the skinned mesh welded to it.
--
-- IT READS ATTRIBUTES THE ANIMAL'S OWN OWNER PUBLISHES (`Damageable`, `HitZone`, `ZonesOnly`), which
-- is the seam `Weapon.Hits.targetOf` has used since the shotgun design's section 6.4: nothing in the
-- weapon knows what a boar is, and a boar publishes no `ZonesOnly` at all.
function Pierce.passesThrough(instance: Instance?): boolean
	local node = instance
	while node do
		if node:GetAttribute("Damageable") == true then
			if node:GetAttribute("ZonesOnly") ~= true then
				return false
			end
			return type(instance and instance:GetAttribute("HitZone")) ~= "string"
		end
		node = node.Parent
	end
	return false
end

export type Hit = {
	instance: BasePart,
	position: Vector3,
	normal: Vector3,
	distance: number,
	material: Enum.Material,
}

-- ONE CAST, WITH THE PASS-THROUGHS APPLIED. `params` is the caller's own -- its filter, its type,
-- its `IgnoreWater` -- and it is neither modified nor copied, which is what lets `Weapon.Flight`
-- keep its contract (*"the SAME table the trigger built; never modified here"*) and what makes the
-- step-past the only mechanism that can work at all.
--
-- `distance` IS FROM THE CALLER'S OWN ORIGIN, because every caller treats it as that: `Flight` adds
-- it to `pellet.travelled`, `Hits.group` picks the nearest impact of a pattern by it, and `HitLog`
-- prints it as the range of the shot.
function Pierce.cast(params: RaycastParams, origin: Vector3, direction: Vector3): Hit?
	local length = direction.Magnitude
	if length <= 1e-6 then
		return nil
	end
	local unit = direction.Unit
	local from, remaining, travelled = origin, direction, 0
	local result = Workspace:Raycast(from, remaining, params)
	local passes = 0
	while result ~= nil and passes < Pierce.MAX_PASS_THROUGH and Pierce.passesThrough(result.Instance) do
		passes += 1
		travelled += result.Distance + Pierce.STEP
		local left = length - travelled
		if left <= 1e-6 then
			return nil
		end
		from = result.Position + unit * Pierce.STEP
		remaining = unit * left
		result = Workspace:Raycast(from, remaining, params)
	end
	if result == nil then
		return nil
	end
	-- THE BOUND IS A MISS, NOT THE LAST SURFACE. Running out of pass-throughs while still standing
	-- on one means the segment never reached anything a bullet can register, and returning the
	-- surface anyway would stop the pellet on an invisible box and charge it to nothing.
	if Pierce.passesThrough(result.Instance) then
		return nil
	end
	return {
		instance = result.Instance,
		position = result.Position,
		normal = result.Normal,
		distance = travelled + result.Distance,
		material = result.Material,
	}
end

return Pierce
