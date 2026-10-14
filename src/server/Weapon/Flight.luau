--!strict
-- Weapon.Flight: the shots that are still in the air (task 185).
--
-- It holds one record per shot and one projectile per pellet, steps them over an INJECTED cast and
-- an INJECTED `dt`, and hands back the shots that have finished. It reports NOTHING: it never calls
-- `Workspace:Raycast` (the cast is a parameter), never builds a `HitReport` (`Hits.group` stays the
-- one constructor), never fires a signal, never touches a Tool, a state, a remote or a counter.
-- `ServerScriptService.Weapon` does all of that, exactly as it does today -- the only thing that
-- changed is WHICH FRAME it does it in (design section 2).
--
-- WHY THE HIT MOVED OUT OF THE TRIGGER'S FRAME. Until this task `onFireRequest` called
-- `Hits.resolve` immediately, so the ray was resolved at the instant of firing: a boar sprinting at
-- `Boar.CONFIG.SPRINT_SPEED` (38 studs/s) was hit wherever the reticle sat. Karen, 2026-10-14:
-- *"when I shoot in running animal I need to aim a bit in front based on speed distance ect"*. The
-- SEGMENT cast below is the whole mechanism -- each step casts only the piece of path just
-- travelled, so a boar that ran INTO the path is hit and a boar that ran OUT of it is not, judged
-- where it is when the bullet gets there.
--
-- Pattern: FastCast's per-step segment raycast (https://etithespir.it/FastCastAPIDocs/, MPL-2.0;
-- adopted as a pattern and deliberately NOT vendored -- it ships as a `.rbxm`, which this repo
-- bans, and it is not on Wally. Research note section 2A, rule 2). The maths is
-- `ReplicatedStorage.Ballistics`; this file is the bookkeeping.
--
-- THE CAST IS THE SEAM THIS SYSTEM ALREADY HAS: `(origin, direction, ignore) -> Impact?`, the same
-- signature `Hits.resolve` took and `Weapon.setCast` replaces, so `weapon_hits.spec` counts the
-- casts, inspects the ignore list, and answers them from a scripted world with no Workspace at all.
-- `Weapon.Cast` stays the ONLY caller of `Workspace:Raycast` under this folder (shotgun design
-- 13.5): a grep must still find that file alone.
--
-- WHY IT HOLDS STATE WHEN EVERY OTHER MODULE IN THIS FOLDER IS PURE. It holds a list, and the
-- repo's precedent for "stateful and still testable with no world" is `Weapon.Registry`:
-- `Registry.new()` returns an instance, and `weapon_state.spec` drives it with stand-in keys.
-- `Flight.new()` is the same thing -- production holds one instance, a spec makes its own, and the
-- two never meet.
--
-- Design: docs/design/ballistics.md (sections 2, 4.2, 5, 6)
-- Note:   docs/research/2026-10-14-ballistics-lead.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ballistics = require(ReplicatedStorage:WaitForChild("Ballistics"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

type Impact = Shotgun.Impact
type CastFn = Shotgun.CastFn

-- Everything the owner needs to report a shot when it LANDS, taken at the trigger -- because by
-- then the gun has moved on: the shell is spent, the barrel has swapped and the bolt may have
-- cycled.
export type ShotRecord = {
	shooter: Player, -- may have left, died or been revoked by the time it lands
	shooterUserId: number, -- taken at the TRIGGER, so a departed shooter is still identifiable
	weapon: string?, -- the Weapons.WeaponId
	ammo: string,
	muzzle: Vector3,
	ignore: { Instance }, -- the SAME table the trigger built; never modified here
	rangeStuds: number,
	firedAt: number, -- os.clock() at the trigger. This becomes HitReport.at.
	epoch: number?, -- the gun's epoch at the trigger, for the record only (design 6.4)
}

-- One projectile. MUTATED IN PLACE on purpose: nine pellets stepped sixty times a second must not
-- allocate nine tables a frame (design section 10, the cost target).
type Projectile = {
	position: Vector3,
	velocity: Vector3,
	travelled: number,
	elapsed: number,
}

type Live = {
	shot: ShotRecord,
	ballistic: Ballistics.Shot,
	projectiles: { Projectile },
	impacts: { Impact },
}

export type Resolution = { shot: ShotRecord, impacts: { Impact } }

local Flight = {}
Flight.__index = Flight

export type Flight = typeof(setmetatable(
	{} :: {
		_config: any,
		_live: { Live },
		_pellets: number,
		launched: number,
		resolved: number,
		timedOut: number,
		refused: number,
		casts: number,
	},
	Flight
))

-- `config` nil IS `Shotgun.CONFIG`, which is the production answer. A spec passes its own so the
-- step cap, the sub-step cap, the ceiling and the live cap are all reachable at values the game
-- never produces -- the discipline `Weapons.loadoutFor` already follows for the flag.
function Flight.new(config: any?): Flight
	return setmetatable({
		_config = config or Shotgun.CONFIG,
		_live = {},
		_pellets = 0,
		-- WHAT IT HAS DONE, for `Weapon.stats`. `timedOut` must stay 0 in every run: nothing
		-- legitimate reaches `FLIGHT_MAX_SECONDS`, so a non-zero value is a bug said out loud
		-- rather than a flight quietly swallowed.
		launched = 0,
		resolved = 0,
		timedOut = 0,
		refused = 0,
		casts = 0,
	}, Flight)
end

-- ONE SHOT INTO THE AIR, one projectile per direction.
--
-- `directions` are the pattern's unit vectors about the ALREADY-ELEVATED bore
-- (`Ballistics.launchDirection`), so the spread and the zero compose in the owner and this file
-- touches neither.
--
-- RETURNS HOW MANY WENT. 0 means the global cap refused the shot -- and then the shot is resolved
-- with NO impacts on the next `advance`, because a refusal is a MISS and never a silent nothing.
function Flight.launch(self: Flight, shot: ShotRecord, directions: { Vector3 }, ballistic: Ballistics.Shot): number
	local cap = self._config.FLIGHT_MAX_LIVE_PELLETS
	local projectiles: { Projectile } = {}
	if self._pellets + #directions <= cap then
		for _, direction in ipairs(directions) do
			projectiles[#projectiles + 1] = {
				position = shot.muzzle,
				velocity = direction.Unit * ballistic.v0,
				travelled = 0,
				elapsed = 0,
			}
		end
	else
		self.refused += 1
	end

	self._live[#self._live + 1] = {
		shot = shot,
		ballistic = ballistic,
		projectiles = projectiles,
		impacts = {},
	}
	self._pellets += #projectiles
	self.launched += #projectiles
	return #projectiles
end

-- ADVANCE EVERY PROJECTILE BY `dt` AND HAND BACK THE SHOTS THAT FINISHED.
--
-- A shot is finished when its LAST projectile has retired -- hit something, run out of range, or
-- run out of time. That is what keeps today's contract exactly: `Hits.group` makes ONE report per
-- (shot, target) with `pellets` counted, so nine buckshot pellets on one boar must be grouped once,
-- after all nine have arrived, and never nine times as they land.
--
-- `dt` IS SPLIT at `FLIGHT_STEP_MAX_SECONDS`, up to `FLIGHT_MAX_SUBSTEPS` sub-steps. Beyond the cap
-- the remainder is DISCARDED: on a hitch longer than 0.267 s a projectile arrives slightly late
-- rather than the server casting hundreds of rays in one frame. A stated degradation, and it cannot
-- leak a projectile, because `travelled` and `elapsed` still rise on every sub-step.
--
-- A LONG STEP CANNOT TUNNEL THROUGH A WALL: the cast is of the SEGMENT, so for any `dt` the first
-- solid thing on the chord is found. What a long step costs is the chord instead of the arc
-- (0.019 studs of sag at the cap) and time resolution against a moving animal (1.27 studs at the
-- cap, a third of a boar's trunk).
function Flight.advance(self: Flight, dt: number, cast: CastFn): { Resolution }
	if #self._live == 0 then
		return {}
	end

	local config = self._config
	local subs = 1
	if dt > 0 then
		subs = math.min(math.ceil(dt / config.FLIGHT_STEP_MAX_SECONDS), config.FLIGHT_MAX_SUBSTEPS)
		subs = math.max(subs, 1)
	end
	local step = if dt > 0 then dt / subs else 0

	local finished: { Resolution } = {}
	local keep: { Live } = {}

	for _, live in ipairs(self._live) do
		local shot = live.shot
		local ballistic = live.ballistic
		local stillFlying: { Projectile } = {}

		for _, pellet in ipairs(live.projectiles) do
			local alive = true
			for _ = 1, subs do
				if not alive then
					break
				end
				local nextPosition, nextVelocity = Ballistics.advance(pellet.position, pellet.velocity, step, ballistic)
				local segment = nextPosition - pellet.position
				local length = segment.Magnitude

				-- THE RANGE CAP IS EXACT, not "whichever sub-step first overshot it". A projectile
				-- whose step would carry it past its ammo's range casts only the piece that is left
				-- and retires either way -- so `RANGE_STUDS[ammo]` means exactly what it meant under
				-- hitscan, where `Hits.resolve` cast precisely that far.
				local remaining = shot.rangeStuds - pellet.travelled
				if length >= remaining then
					if length > 1e-6 then
						segment = segment.Unit * remaining
					end
					length = remaining
					alive = false
				end

				if length > 1e-6 then
					self.casts += 1
					local impact = cast(pellet.position, segment, shot.ignore)
					if impact then
						live.impacts[#live.impacts + 1] = {
							instance = impact.instance,
							position = impact.position,
							normal = impact.normal,
							-- HOW FAR THE PROJECTILE FLEW, not how far this segment did.
							-- `Hits.group` picks the nearest impact of a pattern with it and
							-- `HitLog` prints it as the range of the shot, so the distance a player
							-- reads must be the whole path and not the last 40 studs of it.
							distance = pellet.travelled + impact.distance,
						}
						alive = false
					end
				end

				if alive then
					pellet.travelled += length
					pellet.elapsed += step
					pellet.position = nextPosition
					pellet.velocity = nextVelocity
					if pellet.elapsed > config.FLIGHT_MAX_SECONDS then
						self.timedOut += 1
						alive = false
					end
				end
			end
			if alive then
				stillFlying[#stillFlying + 1] = pellet
			end
		end

		self._pellets -= (#live.projectiles - #stillFlying)
		live.projectiles = stillFlying
		if #stillFlying == 0 then
			self.resolved += 1
			finished[#finished + 1] = { shot = shot, impacts = live.impacts }
		else
			keep[#keep + 1] = live
		end
	end

	self._live = keep
	return finished
end

-- HOW MANY PROJECTILES ARE IN THE AIR. The leak instrument: fire everything, advance past every
-- range cap, and this must be 0.
function Flight.count(self: Flight): number
	return self._pellets
end

function Flight.shots(self: Flight): number
	return #self._live
end

function Flight.stats(self: Flight)
	return {
		launched = self.launched,
		resolved = self.resolved,
		timedOut = self.timedOut,
		refused = self.refused,
		casts = self.casts,
	}
end

return Flight
