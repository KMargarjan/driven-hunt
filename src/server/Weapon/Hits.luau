--!strict
-- Weapon.Hits: turns the impacts a shot made into hit reports. PURE -- it takes impacts and gives
-- back reports, with no cast, no clock and no world, which is what lets weapon_hits.spec drive it
-- with hand-written impacts.
--
-- SINCE TASK 185 IT NO LONGER CASTS ANYTHING. `Hits.resolve` was the hitscan resolver and it is
-- archived (see the note above `group` below); the casting is `Weapon.Flight`'s, over the same
-- injected seam `(origin, direction, ignore) -> Impact?` -- which is still what lets a spec count
-- the casts and inspect the ignore list, and the ignore list is still defect (a) of the Task 23
-- review: without it the camera ray, which starts behind the character in third person, resolves
-- onto the shooter's own back.
--
-- targetOf reads two ATTRIBUTES published by the target's own owner -- `Damageable` and `HitZone`
-- (design section 6.4) -- so the weapon never knows what a boar is, and ROADMAP 1.5 can split the
-- body into zones without touching this file.
--   Roblox attributes  https://create.roblox.com/docs/reference/engine/classes/Instance#GetAttribute
--
-- Design: docs/design/shotgun.md (sections 5.3, 5.5, 6.4), docs/design/ballistics.md (section 2.1)
-- Note:   docs/research/2026-09-24-shotgun.md, docs/research/2026-10-14-ballistics-lead.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

type Impact = Shotgun.Impact
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

-- `Hits.resolve` IS GONE, AND THAT IS TASK 185 (archived: `backups/2026-10-14_task-185_hitscan-Hits-resolve.md`,
-- rule 7). It was the HITSCAN resolver: one cast per pellet, the whole range, in the trigger's own
-- frame -- so a boar at `Boar.CONFIG.SPRINT_SPEED` (38 studs/s) was hit wherever the reticle sat
-- and aiming ahead could only miss. Karen, 2026-10-14: *"when I shoot in running animal I need to
-- aim a bit in front based on speed distance ect I wan to have that feeling"*.
--
-- `ServerScriptService.Weapon.Flight` replaces it: the shot is a projectile the server steps, and
-- each step casts only the SEGMENT just travelled, so the hit is judged where the target is when
-- the bullet gets there. It is REMOVED rather than left callable beside the stepper, because two
-- functions in one folder answering "where did the bullet go" is the exact failure
-- `docs/PROJECT_CONTEXT.md` records (docs/design/ballistics.md section 2.1).
--
-- `targetOf` above and `group` below are UNTOUCHED: `group` is still the one constructor of a
-- `HitReport`, still makes one per (shot, target), and still counts `pellets`.

-- ONE report per (shot, target): nine pellets on one boar are one report with pellets = 9, never
-- nine reports. The dominant zone wins; a tie is broken by the nearest impact, so a tie is decided
-- by geometry rather than by table order.
-- `weapon` IS THE WEAPON'S ID, AND THIS IS THE ONE PLACE IT ENTERS THE SYSTEM (task 140). A weapon
-- is a property of the SHOT, exactly as `ammo` is, and `group` is the only constructor of a
-- `HitReport` -- so `HitLog` copies it the way it copies `zone`, and the drive report can name the
-- gun without anybody deriving anything.
function Hits.group(shooter: Player, impacts: { Impact }, ammo: string, now: number, weapon: string?): { HitReport }
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
			weapon = weapon,
			at = now,
		}
	end
	return reports
end

return Hits
