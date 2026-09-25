--!strict
-- Weapon.Hits: turns pellet directions into hit reports, over an INJECTED cast function. It never
-- calls Workspace:Raycast itself -- Weapon.Cast is the only module that does -- which is what lets
-- weapon_hits.spec count the casts and inspect the ignore list they were given.
--
-- The cast seam takes an ignore list: `(origin, direction, ignore) -> Impact?`. That is defect (a)
-- of the Task 23 review: without it the shooter's own character cannot be filtered out, and the
-- camera ray, which starts behind the character in third person, resolves onto the shooter's back.
--
-- targetOf reads two ATTRIBUTES published by the target's own owner -- `Damageable` and `HitZone`
-- (design section 6.4) -- so the weapon never knows what a boar is, and ROADMAP 1.5 can split the
-- body into zones without touching this file.
--   Roblox attributes  https://create.roblox.com/docs/reference/engine/classes/Instance#GetAttribute
--
-- Design: docs/design/shotgun.md (sections 5.3, 5.5, 6.4)
-- Note:   docs/research/2026-09-24-shotgun.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

type Impact = Shotgun.Impact
type CastFn = Shotgun.CastFn
type HitReport = Shotgun.HitReport

local Hits = {}

-- (target root, zone). The root is the nearest ancestor-or-self carrying Damageable == true; the
-- zone is the hit instance's HitZone, else the root's, else "unknown". No root means a miss.
function Hits.targetOf(instance: Instance?): (Instance?, string)
	local node = instance
	while node do
		if node:GetAttribute("Damageable") == true then
			local zone = instance and instance:GetAttribute("HitZone")
			if type(zone) ~= "string" then
				zone = node:GetAttribute("HitZone")
			end
			return node, if type(zone) == "string" then zone else "unknown"
		end
		node = node.Parent
	end
	return nil, ""
end

-- One cast per direction, every one of them given the same ignore list, unmodified.
function Hits.resolve(
	muzzle: Vector3,
	directions: { Vector3 },
	range: number,
	cast: CastFn,
	ignore: { Instance }
): { Impact }
	local impacts = {}
	for _, direction in ipairs(directions) do
		local impact = cast(muzzle, direction * range, ignore)
		if impact then
			impacts[#impacts + 1] = impact
		end
	end
	return impacts
end

-- ONE report per (shot, target): nine pellets on one boar are one report with pellets = 9, never
-- nine reports. The dominant zone wins; a tie is broken by the nearest impact, so a tie is decided
-- by geometry rather than by table order.
function Hits.group(shooter: Player, impacts: { Impact }, ammo: string, now: number): { HitReport }
	local order, byTarget = {}, {}
	for _, impact in ipairs(impacts) do
		local target, zone = Hits.targetOf(impact.instance)
		if target then
			local entry = byTarget[target]
			if not entry then
				entry =
					{ zones = {}, pellets = 0, nearest = math.huge, position = impact.position, normal = impact.normal }
				byTarget[target] = entry
				order[#order + 1] = target
			end
			entry.pellets += 1
			entry.zones[zone] = (entry.zones[zone] or 0) + 1
			if impact.distance < entry.nearest then
				entry.nearest = impact.distance
				entry.position = impact.position
				entry.normal = impact.normal
				entry.nearestZone = zone
			end
		end
	end

	local reports = {}
	for _, target in ipairs(order) do
		local entry = byTarget[target]
		local best, bestCount = entry.nearestZone, -1
		for zone, count in pairs(entry.zones) do
			if count > bestCount or (count == bestCount and zone == entry.nearestZone) then
				best, bestCount = zone, count
			end
		end
		reports[#reports + 1] = {
			shooter = shooter,
			target = target,
			zone = best,
			zones = entry.zones,
			pellets = entry.pellets,
			nearest = entry.nearest,
			position = entry.position,
			normal = entry.normal,
			ammo = ammo,
			at = now,
		}
	end
	return reports
end

return Hits
