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
--
-- **THE NUMBERS BELOW ARE `docs/design/ballistics.md` SECTION 5.2's**, which is why they start at 2:
-- check 1 is *"the claimed part belongs to a live animal the server knows"*, and that one is the
-- OWNER's (`Hits.targetOf` plus the history provider) because it needs an Instance and a provider,
-- which this module may not touch. They were numbered 1-6 from here until task 266b, so "check 4"
-- meant the LINE check in this file and the REACH check in the design, `Shotgun.CONFIG.CLAIM` and
-- `zz_claim_window.spec` -- the Reviewer carried that from round 2 to round 3.
--
-- IT ALSO ANSWERS **THE MEASURED VALUE AND ITS BUDGET** (task 269b), as a third and fourth return.
-- Purely additive: every caller written before this task takes two values and is untouched.
--
-- WHY: task 269 measured `claims=10 accepted=2 refused=8 [claim-blocked=4 claim-line=4]` on real
-- shots at running deer and **could not say by how much**. `claim-line` is a distance against
-- `LINE_TOLERANCE_STUDS`; "refused" alone does not say whether it missed by a tenth of a stud or by
-- thirty, and those are different defects with different fixes. A rule that can refuse without
-- leaving a number behind cannot be argued with, which is the whole reason this task exists.
--
-- THE PAIR IS ALWAYS (measured, budget) IN THE SAME UNIT, so a reader can divide them. For a check
-- whose refusal is not a magnitude -- a type, a NaN -- both are nil, which says "this one has no
-- number" rather than a zero that reads like a measurement.
function Validator.judgeClaim(facts: any, limits: any): (boolean, string?, number?, number?)
	if type(facts) ~= "table" or type(limits) ~= "table" then
		return false, "claim-type"
	end
	-- CHECK 2 OF THE DESIGN (section 5.2): THE OFFSET IS ON THE CLAIMED BOX. Componentwise against the part's own half-extents plus
	-- one skin, because both sides read the same `Size` and the only disagreement should be floating
	-- point. A claim whose offset is off the box is naming a point that is not on the thing it says
	-- it hit, whatever the rest of the arithmetic says.
	local half, offset = facts.partHalf, facts.offset
	if typeof(half) ~= "Vector3" or typeof(offset) ~= "Vector3" then
		return false, "claim-type"
	end
	local skin = limits.SKIN_STUDS
	-- THE MEASURE IS THE WORST OF THE THREE AXES, as a fraction over its own half-extent plus a
	-- skin: componentwise is how the check reads, and one number is what a counter can keep.
	local overX = math.abs(offset.X) - (half.X + skin)
	local overY = math.abs(offset.Y) - (half.Y + skin)
	local overZ = math.abs(offset.Z) - (half.Z + skin)
	local over = math.max(overX, overY, overZ)
	if over > 0 then
		return false, "claim-offset", over, skin
	end

	-- CHECK 3: THE CLIENT AND THE SERVER AGREE ABOUT WHERE IT WAS. This is the ONE check that exists to be
	-- disagreed with, and the loose one: the shared clock is unestablished, so it asks "the same
	-- animal in the same place", not "the same millisecond". `CLAIM.POSITION_TOLERANCE_STUDS` says
	-- why 6.0 and not 0.5.
	local moved = (facts.clientPoint - facts.serverPoint).Magnitude
	if moved > limits.POSITION_TOLERANCE_STUDS then
		return false, "claim-moved", moved, limits.POSITION_TOLERANCE_STUDS
	end

	-- CHECK 4: THE SHOT WENT THERE. The SERVER's own trajectory at the claimed flight time against the
	-- SERVER's own rewind of the claimed point -- never against the client's point, which is what
	-- keeps a modified client from moving the line as well as the target. **This is the check that
	-- makes the ZONE geometric rather than chosen** (design 5.2, 5.4).
	local line = (facts.trajectoryPoint - facts.serverPoint).Magnitude
	if line > limits.LINE_TOLERANCE_STUDS then
		return false, "claim-line", line, limits.LINE_TOLERANCE_STUDS
	end

	-- CHECK 5: THE BULLET GOT THERE -- the line of sight, measured by the flight that already ran. A tree
	-- between the muzzle and the animal stopped the server's own shot, so the claim dies with it --
	-- and no new raycast is needed to know it.
	-- ...AND THE CLAIMED ANIMAL CANNOT BLOCK ITSELF (task 269b). **MEASURED in Karen's place**:
	-- `claim-blocked worst 2.137/1.000 (reached 11.26 of 13.40 studs, stopped by nothing it
	-- reported)` -- the server's own flight stopped two studs SHORT of the claimed distance on the
	-- very animal the claim was about, because the server's copy of a deer running at 30 studs/s sits
	-- a replication interval further along the ray than the client's. That is not a blocked line of
	-- sight; it is the same bullet hitting the same animal, measured twice.
	--
	-- THE RULE STILL DOES ITS JOB: a TREE between the muzzle and the animal stopped the flight at a
	-- part that is not the claimed target, `stoppedByClaimedTarget` is false, and the claim dies
	-- exactly as it did before. The owner decides the identity, because it needs Instances and this
	-- module touches none; `nil` is every caller written before this task and behaves as `false`.
	--
	-- ...AND THE WAIVER IS BOUNDED BY THE ANIMAL'S OWN BODY (round 2's blocking finding, which was
	-- right). Unbounded, "the animal stopped my bullet" would excuse ANY claimed distance the
	-- flight-time check could be made to match, and `Validator.claimImpact` writes that number into
	-- the report's `distance`. The shortfall a body can honestly explain is the body: the claimed
	-- part's own largest extent, plus the slack every claim already gets. The live reading this was
	-- built for is 2.137 studs against a deer's trunk, which is well inside it.
	local shortfall = facts.claimedStuds - facts.reachedStuds
	local span = 0
	if typeof(facts.partHalf) == "Vector3" then
		span = 2 * math.max(facts.partHalf.X, facts.partHalf.Y, facts.partHalf.Z)
	end
	local waived = facts.stoppedByClaimedTarget == true and shortfall <= span + limits.REACH_SLACK_STUDS
	if not waived and facts.reachedStuds + limits.REACH_SLACK_STUDS < facts.claimedStuds then
		-- THE MEASURE IS HOW FAR SHORT THE SERVER'S OWN FLIGHT STOPPED, in studs, against the slack
		-- it is allowed. The owner adds WHAT stopped it, which is an Instance and so not this
		-- module's to name.
		return false, "claim-blocked", facts.claimedStuds - facts.reachedStuds, limits.REACH_SLACK_STUDS
	end

	-- CHECK 6, first half: THE CLOCK IS SANE. A NEGATIVE age is an arrival in the server's FUTURE, which is a claim
	-- about something that has not happened; too old is outside the window the animal remembers.
	if facts.ageSeconds < 0 then
		return false, "claim-future", facts.ageSeconds, 0
	end
	if facts.ageSeconds > limits.AGE_MAX_SECONDS then
		return false, "claim-stale", facts.ageSeconds, limits.AGE_MAX_SECONDS
	end

	-- CHECK 6, second half: THE GUN COULD HAVE MADE THIS SHOT. The claimed flight time against the server's own
	-- `Ballistics.timeToRange` for that weapon, that ammo and that range. It refuses a NONSENSE
	-- claim; it does not pin the geometry -- check 3 does that.
	local flightOff = math.abs(facts.flightSeconds - facts.expectedFlightSeconds)
	if flightOff > limits.FLIGHT_TOLERANCE_SECONDS then
		return false, "claim-time", flightOff, limits.FLIGHT_TOLERANCE_SECONDS
	end

	return true, nil
end

-- THE CLOSEST APPROACH OF A WALKED TRAJECTORY TO A POINT (task 271, design 4.3). PURE, and it is
-- `judgeClaimFor`'s own loop MOVED here rather than written again: the owner walked the shot and
-- kept the nearest point on the nearest segment, and the sweep needs that answer once per candidate
-- against ONE walk.
--
-- A SEGMENT IS `{ from: Vector3, to: Vector3 }` and nothing else, which is what keeps this module
-- free of `Ballistics`, of a shot record and of a clock.
function Validator.closestOnSegments(segments: any, point: Vector3): (Vector3?, number)
	if type(segments) ~= "table" or typeof(point) ~= "Vector3" then
		return nil, math.huge
	end
	local best, bestStuds = nil :: Vector3?, math.huge
	for _, segment in ipairs(segments) do
		local from, to = segment.from, segment.to
		if typeof(from) == "Vector3" and typeof(to) == "Vector3" then
			local span = to - from
			local length = span.Magnitude
			local on = from
			if length > 1e-6 then
				-- The standard clamped projection: the nearest point ON the segment, so a
				-- trajectory that passes the animal is measured perpendicular to its path and not
				-- from whichever end happened to be sampled.
				on = from + span * math.clamp((point - from):Dot(span) / (length * length), 0, 1)
			end
			local studs = (on - point).Magnitude
			if studs < bestStuds then
				best, bestStuds = on, studs
			end
		end
	end
	return best, bestStuds
end

-- WHICH PICTURE OF THE ANIMAL THE SERVER WILL JUDGE AGAINST (task 271, design 5.2.1). PURE: the
-- owner does the Instance work and hands numbers in.
--
-- `candidates` is NEWEST FIRST, each `{ at, point }` where `point` is the server's OWN rewind of
-- the claimed offset at `at`. Returns `(index, trajectoryPoint, lineStuds, movedStuds, anyPassed)`.
--
-- THE RULE, ORDER-INDEPENDENT AND A STRICT SUPERSET OF what one instant did: among the candidates
-- that PASS check 3 (`|clientPoint - point| <= POSITION_TOLERANCE_STUDS`), pick the one whose
-- distance from the trajectory is smallest. If none passes check 3, pick the one with the smallest
-- `movedStuds`, so the refusal `judgeClaim` names is `claim-moved` with the best number the server
-- could find rather than an arbitrary one.
--
-- **WHY FILTER ON 3 AND MINIMISE 4, AND NOT THE OTHER WAY ROUND.** Minimising check 4 alone could
-- pick an instant that fails check 3 where the arrival instant would have passed it -- an animal
-- circling across the line of fire crosses the trajectory twice. Filtering first makes the result a
-- strict superset: the arrival instant is always candidate 1, so anything the single-instant rule
-- accepted, this accepts.
--
-- **AND IT IS NOT TASK 269b's REFUSED SEARCH.** That one minimised check 3's OWN expression, so
-- check 3 became "the best of thirteen" and measured nothing. This minimises check 4's, whose
-- left-hand side is the server's own re-step of the shot: `clientPoint` appears in neither term of
-- the thing being minimised, and check 3 is still a real comparison at an instant the client does
-- not choose.
function Validator.pickViewInstant(
	candidates: any,
	segments: any,
	clientPoint: Vector3,
	limits: any
): (number?, Vector3?, number?, number?, boolean)
	if type(candidates) ~= "table" or #candidates == 0 or type(limits) ~= "table" then
		return nil, nil, nil, nil, false
	end
	local bestIndex, bestPoint, bestLine, bestMoved = nil, nil :: Vector3?, math.huge, math.huge
	local fallbackIndex, fallbackPoint, fallbackLine, fallbackMoved = nil, nil :: Vector3?, math.huge, math.huge
	for index, candidate in ipairs(candidates) do
		local point = candidate.point
		if typeof(point) == "Vector3" then
			local moved = (clientPoint - point).Magnitude
			local on, studs = Validator.closestOnSegments(segments, point)
			if moved <= limits.POSITION_TOLERANCE_STUDS then
				if studs < bestLine then
					bestIndex, bestPoint, bestLine, bestMoved = index, on, studs, moved
				end
			elseif moved < fallbackMoved then
				fallbackIndex, fallbackPoint, fallbackLine, fallbackMoved = index, on, studs, moved
			end
		end
	end
	if bestIndex ~= nil then
		return bestIndex, bestPoint, bestLine, bestMoved, true
	end
	return fallbackIndex, fallbackPoint, fallbackLine, fallbackMoved, false
end

-- WHAT AN ACCEPTED CLAIM'S SHOT ACTUALLY HIT: exactly one impact, built from the claim and from the
-- part as it is NOW (task 266, design 5.2).
--
-- IT IS A FUNCTION AND NOT FOUR LINES INSIDE THE OWNER, and the Reviewer's round-2 finding is why:
-- the truncation was reachable only through a live `onFireRequest` with a real player holding a
-- loaded gun, so **deleting the whole accept branch left the entire suite green** -- the exact
-- failure `weapon_shot.spec`'s own header quotes from task 260 round 3. Pure, exported and handed
-- its three facts, it is driven by `weapon_hits.spec` with no world at all, and deleting it now
-- fails that spec.
--
-- TRUNCATION IS THE WHOLE OF THE SINGLE-ANSWER RULE: the claim says where the bullet actually
-- stopped, so every impact the flight found farther out never happened. A claimable shot is
-- single-pellet by construction (design section 6), so the flight had at most one impact and this
-- is "the accepted claim replaces it" -- no merging, no second report, and `pellets` is 1 exactly
-- as it is for a slug today.
--
-- `partCFrame` IS PASSED IN rather than read off `claim.part` here, because this module touches no
-- Instance -- its own header's first sentence -- and because a spec must be able to drive the case
-- where the animal has MOVED between the claim and the resolution, which is the normal case.
function Validator.claimImpact(claim: any, partCFrame: CFrame, bore: Vector3, material: any?): any
	return {
		instance = claim.part,
		-- THE LIVE CFrame WITH THE VALIDATED OFFSET, not the client's world point: the dust is drawn
		-- from this, and it has to land on the same spot of the same animal the client is about to
		-- draw it on -- which is where the animal IS now, not where it was.
		position = partCFrame * claim.offset,
		-- THE SHOT'S OWN DIRECTION, REVERSED: the only honest normal a claim has, and what
		-- `Runtime:takeHit` reads a normal for (the direction the shot came FROM, for the bolt).
		normal = -bore,
		-- PATH STUDS FROM THE BORE, the meaning `HitReport.nearest` has everywhere else.
		distance = claim.distanceStuds,
		material = material,
	}
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
