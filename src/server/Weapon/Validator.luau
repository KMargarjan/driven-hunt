--!strict
-- Weapon.Validator: pure checks on what a client sent. Nothing here trusts a client, and nothing
-- here touches an Instance, a service or a clock.
--
-- checkRequest is the whitelist that makes the reducer's primitives unreachable from a client
-- (design section 2.1 defect d): only "Reload", "SelectAmmo" and -- since task 238 -- "Aim" cross
-- the wire; Break, Load, Close and Fire are server-side ActionKinds and are not in the accepted set
-- at all. "Aim" is not a reducer primitive and moves no state: it is a QUESTION, answered in the
-- snapshot's `advice` field (docs/research/2026-10-22-licence-popup-and-robux.md section 3.1).
--
-- Design: docs/design/shotgun.md (section 5.3)
-- Note:   docs/research/2026-09-24-shotgun.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

local Validator = {}

local function isFinite(v: Vector3): boolean
	return v.X == v.X
		and v.Y == v.Y
		and v.Z == v.Z
		and math.abs(v.X) ~= math.huge
		and math.abs(v.Y) ~= math.huge
		and math.abs(v.Z) ~= math.huge
end

-- `req.origin` is the CAMERA position and `req.direction` its unit LookVector, so the tolerance is
-- generous on purpose: under the stock third-person camera the origin is MEANT to be behind the
-- character (design section 5.5 step 2).
-- `toleranceStuds` IS THE FOURTH ARGUMENT SINCE TASK 260, and `nil` is `config.CAMERA_ORIGIN_TOLERANCE`
-- -- every caller written before it, bit for bit. The owner passes the FIRST-PERSON number when the
-- camera is first person, because the two branches put the eye in genuinely different places (1.99
-- studs from the root against the third-person clamp's 14.5) and one number for both is the looser of
-- the two. It is an argument rather than a second config read for the reason `g` is an argument all
-- through `Ballistics`: a bound that can only be read at one value cannot be tested at another.
function Validator.checkShot(req: any, rootPosition: Vector3?, config, toleranceStuds: number?): (boolean, string?)
	if rootPosition == nil then
		return false, "not-alive"
	end
	if type(req) ~= "table" or typeof(req.origin) ~= "Vector3" or typeof(req.direction) ~= "Vector3" then
		return false, "bad-type"
	end
	if not isFinite(req.origin) or not isFinite(req.direction) then
		return false, "nan"
	end
	if math.abs(req.direction.Magnitude - 1) > config.DIR_UNIT_TOLERANCE then
		return false, "not-unit"
	end
	local tolerance = if type(toleranceStuds) == "number" then toleranceStuds else config.CAMERA_ORIGIN_TOLERANCE
	if (req.origin - rootPosition).Magnitude > tolerance then
		return false, "origin-far"
	end
	return true, nil
end

-- ---------------------------------------------------------------- THE HIT CLAIM (task 266)
--
-- KAREN, 2026-10-24/25: *"we need to aim in empty space to get hit in head neck or heart like in
-- real life"* / *"all shooting has to be like in real life / this is a key of this game"*.
--
-- THE CLIENT IS AUTHORITATIVE FOR WHAT IT SAW AND THE SERVER DECIDES WHETHER TO BELIEVE IT. These
-- two functions are the deciding, and they live here for the reason this module's own header gives:
-- **nothing here trusts a client, and nothing here touches an Instance, a service or a clock.** The
-- owner gathers the facts -- it is the only thing that may read a part's `Size` or ask the Boar where
-- an animal was -- and hands them in as numbers, so every tolerance can be driven from both sides at
-- values the shipped game never produces.
--
-- Design: docs/design/ballistics.md (sections 4.3, 5.2, 5.4)

-- THE SHAPE AND THE NUMBERS, at the trigger, before anything is committed.
--
-- `pellets` IS READ OFF THE WEAPON'S OWN ROW BY THE OWNER, never off the payload: a claim exists only
-- where the shot IS one line and one point (`row.PELLETS[ammo] == 1`), so buckshot's nine-pellet
-- pattern is refused `"claim-pattern"` as DATA and a client cannot select its own mechanism by lying
-- (design section 6). nil means "the owner did not say", which is accepted -- every pure caller
-- written before this task.
function Validator.checkClaim(claim: any, config: any, pellets: number?): (boolean, string?)
	if type(claim) ~= "table" then
		return false, "claim-type"
	end
	if type(pellets) == "number" and pellets ~= 1 then
		return false, "claim-pattern"
	end
	-- `typeof`, THE SAME TEST `checkShot` MAKES OF A Vector3. An Instance the client invented locally
	-- does not survive the remote at all, and whether this one belongs to an animal is the OWNER's
	-- question (it needs `Damageable`, which only the animal's owner writes).
	if typeof(claim.part) ~= "Instance" then
		return false, "claim-part"
	end
	if typeof(claim.offset) ~= "Vector3" or typeof(claim.point) ~= "Vector3" then
		return false, "claim-type"
	end
	if not isFinite(claim.offset) or not isFinite(claim.point) then
		return false, "claim-nan"
	end
	for _, field in ipairs({ "firedAtView", "flightSeconds", "distanceStuds" }) do
		local value = claim[field]
		-- `value ~= value` IS THE NaN TEST, the idiom `TestLook.point` already uses: a NaN compares
		-- false against every bound below, so it would pass a naive `< max` check.
		if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
			return false, "claim-nan"
		end
		if value < 0 then
			return false, "claim-nan"
		end
	end
	-- `config` IS `Shotgun.CONFIG` AND NOT ITS `CLAIM` SUB-TABLE, because the one bound this check
	-- needs is the FLIGHT's own ceiling, which the whole system shares with `Flight`: a claim longer
	-- than a projectile may live is a claim about a bullet that cannot exist. `judgeClaim` below takes
	-- `CONFIG.CLAIM`, which is the protocol's own tolerances.
	if claim.flightSeconds > config.FLIGHT_MAX_SECONDS then
		return false, "claim-flight"
	end
	if claim.distanceStuds <= 0 then
		return false, "claim-range"
	end
	return true, nil
end

-- THE SIX CHECKS, IN ONE PURE FUNCTION, DRIVEABLE WITH NUMBERS AND NO WORLD.
--
-- Every tolerance is a named field of `limits` (= `Shotgun.CONFIG.CLAIM`), so a spec reaches BOTH
-- sides of each boundary without a boar, a player or a clock. The owner's job is to measure the
-- facts; this function's job is to say yes or no and to name the reason, so `stats.refusedClaimBy`
-- can say WHICH check a real server is failing rather than only how often.
--
-- THE ORDER IS THE DIRECTOR'S, cheapest and most specific first, and each reason is its own string.
function Validator.judgeClaim(facts: any, limits: any): (boolean, string?)
	if type(facts) ~= "table" or type(limits) ~= "table" then
		return false, "claim-type"
	end
	-- (1) THE OFFSET IS ON THE CLAIMED BOX. Componentwise against the part's own half-extents plus
	-- one skin, because both sides read the same `Size` and the only disagreement should be floating
	-- point. A claim whose offset is off the box is naming a point that is not on the thing it says
	-- it hit, whatever the rest of the arithmetic says.
	local half, offset = facts.partHalf, facts.offset
	if typeof(half) ~= "Vector3" or typeof(offset) ~= "Vector3" then
		return false, "claim-type"
	end
	local skin = limits.SKIN_STUDS
	if
		math.abs(offset.X) > half.X + skin
		or math.abs(offset.Y) > half.Y + skin
		or math.abs(offset.Z) > half.Z + skin
	then
		return false, "claim-offset"
	end

	-- (2) THE CLIENT AND THE SERVER AGREE ABOUT WHERE IT WAS. This is the ONE check that exists to be
	-- disagreed with, and the loose one: the shared clock is unestablished, so it asks "the same
	-- animal in the same place", not "the same millisecond". `CLAIM.POSITION_TOLERANCE_STUDS` says
	-- why 6.0 and not 0.5.
	local moved = (facts.clientPoint - facts.serverPoint).Magnitude
	if moved > limits.POSITION_TOLERANCE_STUDS then
		return false, "claim-moved"
	end

	-- (3) THE SHOT WENT THERE. The SERVER's own trajectory at the claimed flight time against the
	-- SERVER's own rewind of the claimed point -- never against the client's point, which is what
	-- keeps a modified client from moving the line as well as the target. **This is the check that
	-- makes the ZONE geometric rather than chosen** (design 5.2, 5.4).
	local line = (facts.trajectoryPoint - facts.serverPoint).Magnitude
	if line > limits.LINE_TOLERANCE_STUDS then
		return false, "claim-line"
	end

	-- (4) THE BULLET GOT THERE: the line of sight, measured by the flight that already ran. A tree
	-- between the muzzle and the animal stopped the server's own shot, so the claim dies with it --
	-- and no new raycast is needed to know it.
	if facts.reachedStuds + limits.REACH_SLACK_STUDS < facts.claimedStuds then
		return false, "claim-blocked"
	end

	-- (5) THE CLOCK IS SANE. A NEGATIVE age is an arrival in the server's FUTURE, which is a claim
	-- about something that has not happened; too old is outside the window the animal remembers.
	if facts.ageSeconds < 0 then
		return false, "claim-future"
	end
	if facts.ageSeconds > limits.AGE_MAX_SECONDS then
		return false, "claim-stale"
	end

	-- (6) THE GUN COULD HAVE MADE THIS SHOT. The claimed flight time against the server's own
	-- `Ballistics.timeToRange` for that weapon, that ammo and that range. It refuses a NONSENSE
	-- claim; it does not pin the geometry -- check 3 does that.
	if math.abs(facts.flightSeconds - facts.expectedFlightSeconds) > limits.FLIGHT_TOLERANCE_SECONDS then
		return false, "claim-time"
	end

	return true, nil
end

-- The ONLY strings ActionRequest accepts. Everything else, including every reducer primitive, is
-- "bad-request".
--
-- `row` IS THE WEAPON THE PLAYER IS HOLDING (task 140), and the ammo whitelist is ITS kinds rather
-- than the two shotgun literals this used to carry. That is the whole of what "the rifle has one
-- ammo kind" costs: `X` on the rifle is a `bad-request` at the wire and `stats.badRequests` counts
-- it, with no new branch in the owner. A nil row keeps the old behaviour, which is what every
-- caller written before two weapons existed expects.
function Validator.checkRequest(kind: unknown, ammo: unknown, row: any?): (boolean, string?)
	if kind == "Reload" then
		if ammo ~= nil then
			return false, "bad-request"
		end
		return true, nil
	end
	-- THE AIM QUESTION (task 238), and it carries no ammo: *"what would stop me shooting the thing
	-- in front of me"*. Its RAY is validated by `Validator.checkShot` -- the same function, the same
	-- origin tolerance and the same unit check the trigger's ray gets -- so there is one validator
	-- for one kind of payload. Being on this whitelist is what makes the kind reachable at all: the
	-- `return false, "bad-request"` at the bottom is what every other string still gets.
	if kind == "Aim" then
		if ammo ~= nil then
			return false, "bad-request"
		end
		return true, nil
	end
	if kind == "SelectAmmo" then
		-- THE SHOTGUN'S OWN LIST FOR A NIL ROW, from its row rather than typed again here (the
		-- Reviewer's note, round 1): a second copy of a weapon's ammo kinds living outside that
		-- weapon is exactly what the table exists to stop.
		local kinds = if row ~= nil then row.AMMO_KINDS else Weapons.ROWS.shotgun.AMMO_KINDS
		for _, allowed in ipairs(kinds) do
			if ammo == allowed then
				return true, nil
			end
		end
	end
	return false, "bad-request"
end

return Validator
