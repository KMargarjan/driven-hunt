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
	-- THE CLIENT'S HIT CLAIM (task 266), CARRIED AND NEVER READ BY THIS MODULE -- exactly as `epoch`
	-- above is carried "for the record only". The owner judges it at the RESOLUTION, because the
	-- claimed arrival is in the server's FUTURE at the trigger and in its past by one upward trip by
	-- the time the bullet lands (design 5.1). **THE SHOT IN THE AIR IS THE PENDING QUEUE**: no second
	-- remote, no shot id, no pending table, no timeout, and no race between a claim and a resolution.
	claim: Shotgun.HitClaim?,
	-- THE ELEVATED BORE DIRECTION this shot left along (task 266), carried for the same reason and
	-- read by this module exactly as often: never. The owner needs it at the RESOLUTION to step its
	-- own trajectory for the claim's check 4 and to give an accepted claim an honest normal, and by
	-- then the gun has moved on -- so it is taken at the trigger, like `muzzle` and `firedAt` beside
	-- it. `nil` is every caller written before this task.
	bore: Vector3?,
	-- HOW FAR BACK THIS SHOOTER'S PICTURE IS, in seconds (task 305), taken at the trigger by
	-- `Weapon.rewindFor` and handed to the cast as its fourth argument. CARRIED AND NEVER READ
	-- HERE, like `claim` and `bore`: this module does not know what an animal is. nil is every
	-- caller written before that task and is bit-for-bit the old flight.
	rewindSeconds: number?,
	-- `GetServerTimeNow()` AT THE TRIGGER (task 305b), the anchor the rewind above is measured
	-- from. Without it the rewind is measured from the wall clock at each cast, so everything
	-- between the trigger and that cast -- the upward trip, the wait for the next Heartbeat --
	-- becomes invisible lead the shooter has to guess. nil is every caller before that task.
	firedAtServer: number?,
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
	-- HOW MUCH TIME THIS SHOT STILL OWES ITS SHOOTER (task 256), in seconds, already clamped at
	-- `FLIGHT_CATCHUP_MAX_SECONDS` by `Flight.launch`. It is SPENT ONCE, on the first `advance`
	-- after the launch, and set to 0 there -- so a shot cannot be compensated twice however many
	-- Heartbeats it lives for. 0 is every caller written before this task, and 0 is bit-for-bit
	-- today's flight.
	catchUp: number,
	-- THE GREATEST PATH DISTANCE ANY OF THIS SHOT'S PROJECTILES GOT TO before it retired (task 266),
	-- in studs from the bore. An unobstructed shot ends at its ammo's range cap; a shot stopped by a
	-- tree ends at the tree. It becomes `Resolution.reachedStuds`, the LINE-OF-SIGHT fact the claim
	-- is checked against (design 5.2 check 5) -- measured by the flight the server already runs
	-- rather than by a new cast.
	reached: number,
	-- WHERE THAT FARTHEST PROJECTILE ACTUALLY STOPPED (task 298): the impact point, or the last
	-- position it stepped to. Measured here because a curved path's end is not `muzzle + dir * reached`.
	endPoint: Vector3?,
}

-- `reachedStuds` IS NEW IN TASK 266 and every reader written before it simply does not look at it.
-- `endPoint` IS NEW IN TASK 298 and nil only for a shot the global cap refused (no projectile flew).
export type Resolution = { shot: ShotRecord, impacts: { Impact }, reachedStuds: number, endPoint: Vector3? }

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
		catchUpSeconds: number,
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
		-- THE LAG COMPENSATION THIS INSTANCE HAS HANDED OUT, in seconds (task 256). In a Studio
		-- harness run there is no network, so this must stay 0.
		catchUpSeconds = 0,
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
-- `catchUpSeconds` IS THE SHOOTER'S LAG COMPENSATION (task 256) and is OPTIONAL: nil or 0 is every
-- caller written before this task and is bit-for-bit today's flight. It is clamped HERE, at the one
-- door into this module, so no caller can hand in a negative (a bullet that starts in the past) or
-- an unbounded one (a free body length of lead) -- `Shotgun.CONFIG.FLIGHT_CATCHUP_MAX_SECONDS` says
-- why 0.15, and `Weapon.catchUpFor` is the one thing that computes it.
function Flight.launch(
	self: Flight,
	shot: ShotRecord,
	directions: { Vector3 },
	ballistic: Ballistics.Shot,
	catchUpSeconds: number?
): number
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

	local catchUp = 0
	if type(catchUpSeconds) == "number" and catchUpSeconds == catchUpSeconds then
		catchUp = math.clamp(catchUpSeconds, 0, self._config.FLIGHT_CATCHUP_MAX_SECONDS)
	end
	-- WHAT IT ACTUALLY GRANTED, SUMMED, for `Weapon.stats`: with no network this must read 0.000, so
	-- a non-zero total in a Studio harness run is this feature firing where there is no lag to
	-- compensate -- a bug said out loud rather than a silent gift of lead.
	if #projectiles > 0 then
		self.catchUpSeconds += catchUp
	end

	self._live[#self._live + 1] = {
		shot = shot,
		ballistic = ballistic,
		projectiles = projectiles,
		impacts = {},
		-- A SHOT THE GLOBAL CAP REFUSED GETS NONE: it has no projectiles to advance, it resolves as a
		-- MISS on the next `advance`, and crediting it would put a number in `catchUpSeconds` that
		-- bought nothing.
		catchUp = if #projectiles > 0 then catchUp else 0,
		-- A SHOT THE CAP REFUSED REACHES NOTHING, which is the honest answer: it has no projectiles,
		-- it resolves as a miss, and a claim against it is refused by check 5 rather than accepted
		-- because a field defaulted generously.
		reached = 0,
		endPoint = nil,
	}
	self._pellets += #projectiles
	self.launched += #projectiles
	return #projectiles
end

-- HOW A SPAN OF TIME IS CUT INTO SUB-STEPS. PURE and exported (task 256), because the catch-up made
-- it a PER-SHOT question -- each live shot advances by `dt` plus whatever it still owes -- and two
-- copies of this arithmetic would be two answers to how far a bullet moved.
--
-- `dt` IS SPLIT at `FLIGHT_STEP_MAX_SECONDS`, up to `FLIGHT_MAX_SUBSTEPS` sub-steps. Beyond the cap
-- the remainder is DISCARDED: on a hitch longer than 0.267 s a projectile arrives slightly late
-- rather than the server casting hundreds of rays in one frame. A stated degradation, and it cannot
-- leak a projectile, because `travelled` and `elapsed` still rise on every sub-step.
--
-- NO SUB-STEP IS EVER LONGER THAN THE CAP, and that `math.min` is the whole of "the remainder is
-- discarded". `total / subs` is the equal division, and while `subs` is under `FLIGHT_MAX_SUBSTEPS`
-- it is already at or under the cap, so the simulated clock and the real one agree. Once `subs` hits
-- the cap, `total / subs` would be LONGER than `FLIGHT_STEP_MAX_SECONDS` -- and taking it would
-- throw away the two guarantees the cap exists for (0.019 studs of chord sag, 1.27 studs of
-- resolution against a sprinting boar) exactly on the frame that is already in trouble.
-- (Caught by `weapon_hits.spec`'s "discards the rest past the cap" case: before this `min`, a
-- 0.5 s `dt` took eight 62.5 ms steps and advanced the full half-second.)
function Flight.substeps(total: number, config: any): (number, number)
	if total <= 0 then
		return 1, 0
	end
	local subs = math.min(math.ceil(total / config.FLIGHT_STEP_MAX_SECONDS), config.FLIGHT_MAX_SUBSTEPS)
	subs = math.max(subs, 1)
	return subs, math.min(total / subs, config.FLIGHT_STEP_MAX_SECONDS)
end

-- ADVANCE EVERY PROJECTILE BY `dt` AND HAND BACK THE SHOTS THAT FINISHED.
--
-- A shot is finished when its LAST projectile has retired -- hit something, run out of range, or
-- run out of time. That is what keeps today's contract exactly: `Hits.group` makes ONE report per
-- (shot, target) with `pellets` counted, so nine buckshot pellets on one boar must be grouped once,
-- after all nine have arrived, and never nine times as they land.
--
-- THE SUB-STEP SPLIT IS `Flight.substeps`', and it is asked PER SHOT (task 256): each live shot
-- advances by `dt` plus whatever lag compensation it still owes its shooter, so there is no single
-- step size for the frame any more. Only the shot launched this frame owes anything, and it is spent
-- once -- see `live.catchUp`.
--
-- A LONG STEP CANNOT TUNNEL THROUGH A WALL: the cast is of the SEGMENT, so for any `dt` the first
-- solid thing on the chord is found. What a long step costs is the chord instead of the arc
-- (0.019 studs of sag at the cap) and time resolution against a moving animal (1.27 studs at the
-- cap, a third of a boar's trunk).
-- `now` IS `GetServerTimeNow()` (task 305b), and nil keeps the old flight exactly: without it a
-- shot's rewind is measured from the cast's own wall clock instead of from the trigger.
function Flight.advance(self: Flight, dt: number, cast: CastFn, now: number?): { Resolution }
	if #self._live == 0 then
		return {}
	end

	local config = self._config

	local finished: { Resolution } = {}
	local keep: { Live } = {}

	for _, live in ipairs(self._live) do
		local shot = live.shot
		local ballistic = live.ballistic
		local stillFlying: { Projectile } = {}

		-- THE CATCH-UP IS ADDED TO THIS SHOT'S OWN `dt` AND SPENT (task 256), which is why the
		-- sub-step split is computed PER SHOT here rather than once for the whole list: each live
		-- shot advances by `dt` plus whatever lag it still owes its shooter, and only the shot
		-- launched this frame owes anything.
		--
		-- IT GOES THROUGH THE SAME SUB-STEPPED SEGMENT CASTS as any other span of time. That is the
		-- whole reason this is safe: the catch-up is not a teleport forward, it is the simulation
		-- run for longer, so a bullet caught up through a tree trunk still stops at the trunk and a
		-- bullet caught up into an animal still hits the animal.
		local owed = live.catchUp
		live.catchUp = 0
		local subs, step = Flight.substeps(dt + owed, config)

		for _, pellet in ipairs(live.projectiles) do
			local alive = true
			for _ = 1, subs do
				if not alive then
					break
				end
				-- ONE SUB-STEP'S GEOMETRY, AND IT IS `Ballistics.segment`'s SINCE TASK 266. These
				-- fifteen lines were inline here; the client now steps the same bullet against its
				-- own view (`Weapon.Claim.simulate`), and a second copy would be two answers to
				-- "where did the bullet go". The exact range cap moved with them -- `capped` is the
				-- old `length >= remaining` branch, and `length` is already cut to exactly what was
				-- left of `shot.rangeStuds`.
				local nextPosition, nextVelocity, segment, length, capped =
					Ballistics.segment(pellet, step, ballistic, shot.rangeStuds)
				if capped then
					alive = false
				end

				-- HOW FAR THIS SHOT GOT, for the claim's line-of-sight check (task 266, design
				-- 4.5). It is `travelled` plus whatever this sub-step actually covered -- the
				-- impact's own distance when something was struck, otherwise the whole segment --
				-- so an unobstructed shot reaches its range cap exactly and a shot stopped by a
				-- tree reports the tree. ONE `math.max` on a loop that already tracks `travelled`,
				-- and no new cast: `Weapon.Cast` is still the only caller of `Workspace:Raycast`
				-- under this folder.
				local reached = pellet.travelled + length
				local stoppedAt: Vector3? = nil

				if length > 1e-6 then
					self.casts += 1
					-- THE BULLET'S OWN CLOCK, NOT THE WALL CLOCK (task 305b). The animal must be
					-- tested where the shooter drew it at the trigger, carried forward by the
					-- time THIS PELLET has flown -- so the only lead he owes is the ballistic one.
					-- MEASURED in Karen's place: the wall-clock anchor tested 0.019 s late, 0.46
					-- studs of lead nobody can see at a 24 studs/s boar.
					local rewind = shot.rewindSeconds
					if rewind ~= nil and rewind > 0 and shot.firedAtServer ~= nil and now ~= nil then
						rewind = math.clamp(
							rewind + (now - shot.firedAtServer - pellet.elapsed),
							0,
							config.CLAIM.VIEW_LAG_MAX_SECONDS
						)
					end
					local impact = cast(pellet.position, segment, shot.ignore, rewind)
					if impact then
						stoppedAt = impact.position
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
						reached = pellet.travelled + impact.distance
						alive = false
					end
				end
				-- THE FARTHEST PROJECTILE'S END POINT TRAVELS WITH ITS DISTANCE, written in the same
				-- place so the two can never describe different pellets. `>=` and not `>`: a single
				-- -pellet shot's first sub-step must set it.
				if reached >= live.reached then
					live.reached = reached
					-- `pellet.position + segment` AND NOT `nextPosition`: `Ballistics.segment` clamps
					-- the SEGMENT to what was left of the range cap and hands back the unclamped
					-- advance beside it, so `nextPosition` overshoots a capped shot (measured this
					-- task: end 106.3 studs from the muzzle for a 100-stud cap).
					live.endPoint = if stoppedAt ~= nil then stoppedAt else pellet.position + segment
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
			finished[#finished + 1] =
				{ shot = shot, impacts = live.impacts, reachedStuds = live.reached, endPoint = live.endPoint }
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
		-- Task 256. 0.000 in any run with no network; a non-zero value in the harness is a bug.
		catchUpSeconds = self.catchUpSeconds,
	}
end

return Flight
