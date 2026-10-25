--!strict
-- Ballistics: the pure maths of a shot that takes TIME to arrive (task 185).
--
-- Karen, 2026-10-14: *"it has to be real like in a life when I shoot in running animal I need to
-- aim a bit in front based on speed distance ect I wan to have that feeling"*, and *"same with
-- s/s"*. Until this task the shot was HITSCAN -- `Weapon.onFireRequest` resolved the ray in the
-- trigger's own frame -- so a boar at `Boar.CONFIG.SPRINT_SPEED` (38 studs/s) was hit wherever the
-- reticle sat, and aiming ahead could only miss.
--
-- PURE, AND IT WRITES NOTHING AT ALL. Frozen numbers plus functions of their arguments: no state,
-- no clock, no Instance, no Workspace, no Player, and no service beyond the one `require` below.
-- That is the shape `ReplicatedStorage.Gun`, `Horn`, `Report` and `Shop` already have, and it is
-- what lets every flight assertion run with no world (design section 2).
--
-- SHARED rather than server-only for one reason: if Karen ever asks for a tracer, the drawn path
-- must come from the same arithmetic as the hit, not from a second copy of it.
--
-- Pattern: FastCast's algorithm -- step the projectile by `v*dt + 0.5*a*dt^2`, raycast the SEGMENT
-- just travelled, stop on the first hit. The stepping lives here; the segment cast is
-- `ServerScriptService.Weapon.Flight`'s, over the cast seam this system already has.
--   https://etithespir.it/FastCastAPIDocs/   (MPL-2.0; the docs repo is marked obsolete, and the
--   living forks are MIT-0: https://github.com/010DevX101/FastCastRedux)
-- THE MODULE IS NOT VENDORED AND THE REASON IS WRITTEN DOWN (rule 2, research note section 2A): it
-- ships as a `.rbxm`, which this repo BANS (CLAUDE.md, "File types in Rojo-owned paths"), it is not
-- on Wally so it cannot be pinned the way TestEZ is, and it carries an `ActiveCast`/`PartCache`
-- visual-bullet system we do not want -- the default tracer is NONE.
--
-- Drag is ONE COEFFICIENT PER AMMO: `v(s) = v0 * exp(-k*s)`, the closed form of quadratic drag
-- (`dv/dt = -k*v^2`) written against DISTANCE rather than time.
--   https://en.wikipedia.org/wiki/Drag_equation      (drag goes as v^2 at these Reynolds numbers)
--   https://en.wikipedia.org/wiki/External_ballistics
-- Fitted to the rifle's published 100 yd velocity it PREDICTS its 200 yd velocity to 0.9%, and the
-- slug's drop then lands within 1.1 cm of a published number it was never fitted to (research note
-- section 4). A G1/G7 drag function would be the next step and is not needed: the longest shot in
-- this game is 800 studs (224 m).
--
-- `g` IS A PARAMETER WITH A DEFAULT on every function that uses it, for the reason
-- `Weapon.equipDelayFor` and `Weapons.loadoutFor` already state: a constant that can only be read
-- at one value cannot be tested at another.
--
-- AND SINCE TASK 189 EACH SHOT CARRIES ITS OWN `gravityScale`, which multiplies that g. Karen,
-- 2026-10-15, after playing: *"are you sure we have right rifle aiming? seems a bit odd when stands
-- it has to be acurat 100% 100m 150m"*. A rifle zeroed at 200 m rides +12.5 cm high at 100 m --
-- real, and not what she wants of a still target. The scale FLATTENS the arc without touching the
-- clock: `timeToRange` does not read gravity at all, so the lead on a running boar is bit-for-bit
-- what task 185 shipped. The whole derivation is in `Rifle.CONFIG.GRAVITY_SCALE`.
--
-- Design: docs/design/ballistics.md (sections 3.3, 4.1, 5, 10)
-- Note:   docs/research/2026-10-14-ballistics-lead.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- THE ONE METRE/STUD CONVERSION IN THE REPO (`Report.CONFIG.METRES_PER_STUD` = 0.28), required
-- here so gravity is DERIVED from it and this file holds no second copy of 0.28. `Report` requires
-- nothing, so it is a leaf dependency and cannot cycle. The idiom `Horn.spookStuds` already uses,
-- applied to a second quantity.
local Report = require(ReplicatedStorage:WaitForChild("Report"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Ballistics = {}

-- The four numbers one (weapon, ammo) pair flies with. A frozen record rather than four loose
-- arguments, so no caller can pass a muzzle velocity where a drag belongs.
export type Shot = {
	v0: number, -- studs/s at the muzzle
	k: number, -- the drag coefficient, per stud
	zeroStuds: number, -- where the trajectory crosses the sight line
	gravityScale: number, -- what fraction of real gravity this projectile falls at (task 189)
}

Ballistics.CONFIG = Shotgun.deepFreeze({
	METRES_PER_STUD = Report.CONFIG.METRES_PER_STUD,
	GRAVITY_M_PER_S2 = 9.81,
	-- REAL GRAVITY, IN THIS GAME'S OWN UNITS: 9.81 m/s^2 at 0.28 m/stud is 35.0357 studs/s^2.
	-- NOT `Workspace.Gravity` (196.2), which is the engine's number for CHARACTERS and would make a
	-- bullet fall six times too fast. Derived, so it cannot disagree with the distances the rest of
	-- the game measures in.
	GRAVITY_STUDS_PER_S2 = 9.81 / Report.CONFIG.METRES_PER_STUD,
})

local G = Ballistics.CONFIG.GRAVITY_STUDS_PER_S2

-- THE FOUR NUMBERS OFF A `Weapons.Row`, as one frozen record.
--
-- `nil` IS A DATA FAULT AND NEVER A FALLBACK (design 6.5). A row missing any one of the four, or
-- an ammo the row does not carry, answers nil -- and the owner REFUSES the shot rather than firing
-- it in a straight line, because a fallback would be a second answer to "where did the bullet go",
-- reachable by a typo in a data table.
function Ballistics.shotFor(row: any, ammo: string): Shot?
	if type(row) ~= "table" or type(ammo) ~= "string" then
		return nil
	end
	local v0 = row.MUZZLE_STUDS_PER_S and row.MUZZLE_STUDS_PER_S[ammo]
	local k = row.DRAG_PER_STUD and row.DRAG_PER_STUD[ammo]
	local zeroStuds = row.ZERO_STUDS and row.ZERO_STUDS[ammo]
	local gravityScale = row.GRAVITY_SCALE and row.GRAVITY_SCALE[ammo]
	if type(v0) ~= "number" or type(k) ~= "number" or type(zeroStuds) ~= "number" then
		return nil
	end
	-- THE FOURTH NUMBER IS REQUIRED LIKE THE OTHER THREE (task 189). A row without it would fly at
	-- real gravity, which is a SECOND answer to "where does the bullet go" reachable by a typo --
	-- the same reason the three above are required (design 6.5). A negative one is a bullet that
	-- falls upwards.
	if type(gravityScale) ~= "number" or gravityScale < 0 then
		return nil
	end
	if v0 <= 0 then
		return nil
	end
	return table.freeze({ v0 = v0, k = k, zeroStuds = zeroStuds, gravityScale = gravityScale })
end

-- HOW LONG A SHOT TAKES TO TRAVEL `studs` OF PATH, in closed form: integrating `v(s) = v0*exp(-k*s)`
-- gives `t = (exp(k*s) - 1) / (k*v0)`. Closed form rather than stepped, so a spec can assert a
-- weapon's flight time without simulating anything and the launch elevation below needs no loop.
--
-- `k <= 0` IS THE DRAG-FREE LIMIT and is answered as `s/v0` rather than by dividing by zero. It is
-- not a dead branch: it is the honest answer for a projectile with no drag, and it is the limit of
-- the formula as k goes to 0.
function Ballistics.timeToRange(shot: Shot, studs: number): number
	if studs <= 0 or shot.v0 <= 0 then
		return 0
	end
	if shot.k <= 0 then
		return studs / shot.v0
	end
	return (math.exp(shot.k * studs) - 1) / (shot.k * shot.v0)
end

-- WHAT IS LEFT OF THE MUZZLE VELOCITY after `studs` of path: `v0 * exp(-k*s)`. The one assertion in
-- `ballistics.spec` whose right answer came from outside the repo is made against this.
function Ballistics.speedAt(shot: Shot, studs: number): number
	if studs <= 0 or shot.k <= 0 then
		return shot.v0
	end
	return shot.v0 * math.exp(-shot.k * studs)
end

-- HOW FAR THE PROJECTILE FALLS BELOW ITS OWN LAUNCH LINE over `studs` of path. Always >= 0.
--
-- NOT `0.5*g*t^2`, AND THAT WAS MEASURED. The vacuum formula ignores that drag resists the FALL as
-- well as the flight: the drag force is along the whole velocity, so its vertical component pushes
-- UP on a dropping bullet. At the muzzle that component is `k*v*vy`, and for the rifle it reaches
-- 27% of gravity -- so the vacuum drop is 9% too large at 200 m, which put the shot 0.169 studs
-- (4.7 cm) BELOW the reticle at its own zero. `ballistics.spec`'s task-183 case is what caught it.
--
-- The vertical equation with the horizontal speed held at its path average V is linear,
-- `dvy/dt = -g - (k*V)*vy`, whose solution integrates to
--
--     drop(t) = (g/b) * (t - (1 - exp(-b*t))/b),   b = k * (studs / t)
--
-- `studs / t` is the PATH-AVERAGED speed, which is exactly the right V to hold: it is what the
-- closed form above already knows. MEASURED against the real stepper, the miss at the zero fell
-- from 0.169 studs to 0.0011 for the rifle, 0.00013 for the slug and 0.00006 for buckshot -- under a
-- millimetre at 200 m, for a horizontal shot and for 20 degrees up and down.
--
-- `k <= 0` IS STILL THE VACUUM, and so is the limit of this formula as `b` goes to 0: expanding
-- `(1 - exp(-b*t))/b = t - b*t^2/2 + ...` leaves `0.5*g*t^2`, so the two branches meet rather than
-- stepping.
-- `gravityScale` MULTIPLIES WHATEVER GRAVITY IS HANDED IN (task 189), here and in `advance`, which
-- are the only two places in this module gravity is used at all -- so the elevation, the sight
-- offset, the launch direction and the stepped flight all see one number and cannot disagree.
-- Karen, 2026-10-15: *"seems a bit odd when stands it has to be acurat 100% 100m 150m"*. See
-- `Rifle.CONFIG.GRAVITY_SCALE` for what the rifle's is and why.
function Ballistics.dropAt(shot: Shot, studs: number, g: number?): number
	local gravity = (g or G) * shot.gravityScale
	local t = Ballistics.timeToRange(shot, studs)
	if t <= 0 then
		return 0
	end
	if shot.k <= 0 then
		return 0.5 * gravity * t * t
	end
	local beta = shot.k * (studs / t)
	if beta < 1e-9 then
		return 0.5 * gravity * t * t
	end
	return (gravity / beta) * (t - (1 - math.exp(-beta * t)) / beta)
end

-- THE TANGENT OF THE LAUNCH ELEVATION: the drop at the zero, over the zero. One definition, so no
-- caller re-derives it and no sign can disagree.
function Ballistics.elevationTangent(shot: Shot, g: number?): number
	if shot.zeroStuds <= 0 then
		return 0
	end
	return Ballistics.dropAt(shot, shot.zeroStuds, g) / shot.zeroStuds
end

-- THE DIRECTION THE BORE POINTS, GIVEN THE SIGHT LINE -- and the one line that keeps task 183.
--
-- `aim` is the muzzle->aim-point unit vector the owner already computes (shotgun design 5.5 step 7),
-- which IS the sight line: whatever the reticle is over. A real rifle's bore is elevated above its
-- sight line so the falling bullet crosses that line again at the ZERO distance. This returns the
-- elevated direction: go `zeroStuds` along the sight line, rise by the drop the flight there costs,
-- and take the unit vector.
--
-- So a STILL target at the zero distance is hit DEAD CENTRE -- Karen's *"precist and on 200m
-- acurat"* (task 183) preserved by construction rather than by luck -- and everything nearer rides
-- a little high, everything beyond it a little low, exactly as a real rifle does.
--
-- THE PATTERN IS BUILT AROUND THE RESULT, so the elevation happens ONCE and the cone spreads about
-- the elevated bore, which is what a real elevated barrel does. Elevating nine pellet directions
-- instead would be nine elevations and a second place for the sign to be wrong.
--
-- WORLD UP, because the drop is vertical. `aim` pointing straight up is not degenerate: the cross
-- term vanishes and the result is `aim` itself -- no elevation is possible, and none is wanted.
function Ballistics.launchDirection(aim: Vector3, shot: Shot, g: number?): Vector3
	local forward = aim.Unit
	if shot.zeroStuds <= 0 then
		return forward
	end
	local rise = Ballistics.dropAt(shot, shot.zeroStuds, g)
	local elevated = forward * shot.zeroStuds + Vector3.yAxis * rise
	if elevated.Magnitude < 1e-6 then
		return forward
	end
	return elevated.Unit
end

-- HOW FAR ABOVE (+) OR BELOW (-) THE SIGHT LINE the projectile is at `studs`. Exactly 0 at the zero.
-- This is the quantity a player feels, and it has one definition here so that no spec and no report
-- re-derives the sign.
function Ballistics.sightOffsetAt(shot: Shot, studs: number, g: number?): number
	return Ballistics.elevationTangent(shot, g) * studs - Ballistics.dropAt(shot, studs, g)
end

-- WHERE THE PROJECTILE IS AFTER `dt`, AND HOW FAST. One kinematic step with the acceleration held
-- over the step: `p + v*dt + 0.5*a*dt^2`, `v + a*dt`. Exact for gravity, which is constant, and
-- first-order in the drag term -- which is why the step is capped (`FLIGHT_STEP_MAX_SECONDS`).
--
-- `a = -g*up - k*|v|*v`. The drag term's magnitude is `k*v^2`, so `dv/ds = -k*v` and
-- `v(s) = v0*exp(-k*s)`: the same model `timeToRange` integrates and the data was fitted to.
--
-- TWO RETURN VALUES AND NO TABLE, so stepping a projectile allocates nothing (design 10).
function Ballistics.advance(
	position: Vector3,
	velocity: Vector3,
	dt: number,
	shot: Shot,
	g: number?
): (Vector3, Vector3)
	local accel = Vector3.new(0, -(g or G) * shot.gravityScale, 0)
	local speed = velocity.Magnitude
	if shot.k > 0 and speed > 1e-6 then
		accel -= velocity * (shot.k * speed)
	end
	return position + velocity * dt + accel * (0.5 * dt * dt), velocity + accel * dt
end

-- ONE SUB-STEP OF A FLYING PROJECTILE, AND NOTHING ELSE (task 266). Returns
--     (nextPosition, nextVelocity, segment, length, capped)
-- where `segment` is the piece of path just travelled -- the thing to cast -- and `capped` says the
-- ammo's range ran out inside this sub-step, in which case `segment` has already been cut to exactly
-- `rangeStuds - pellet.travelled`.
--
-- IT IS MOVED OUT OF `Weapon.Flight.advance`, NOT WRITTEN AGAIN, and that is the whole reason it
-- exists. Before this task the arithmetic was inline in the SERVER's stepper. Task 266 makes the
-- CLIENT step the same bullet against its own view of the world (`Weapon.Claim.simulate`), and a
-- second copy of these fifteen lines would be two answers to "where did the bullet go" -- the
-- failure `docs/PROJECT_CONTEXT.md` is named after. `Flight.advance` keeps its own list, its
-- timeout, its catch-up and its counters and calls this for the geometry; the client calls the same
-- function.
--
-- THE EXACT RANGE CAP IS THIS FUNCTION'S, and it is why `capped` is returned rather than inferred.
-- A projectile whose step would carry it past its ammo's range casts only the piece that is left and
-- retires either way -- so `RANGE_STUDS[ammo]` means exactly what it meant under hitscan, where
-- `Hits.resolve` cast precisely that far.
--
-- PURE, MUTATING NOTHING, ALLOCATING NO TABLE: five return values, the idiom `Ballistics.advance`'s
-- two already set (design section 10's cost target). The caller owns its own pellet record and
-- decides what to do with the answer.
--
-- Design: docs/design/ballistics.md (section 4.1)
function Ballistics.segment(
	pellet: { position: Vector3, velocity: Vector3, travelled: number, elapsed: number },
	step: number,
	shot: Shot,
	rangeStuds: number,
	g: number?
): (Vector3, Vector3, Vector3, number, boolean)
	local nextPosition, nextVelocity = Ballistics.advance(pellet.position, pellet.velocity, step, shot, g)
	local segment = nextPosition - pellet.position
	local length = segment.Magnitude
	local remaining = rangeStuds - pellet.travelled
	if length >= remaining then
		if length > 1e-6 then
			segment = segment.Unit * remaining
		end
		return nextPosition, nextVelocity, segment, remaining, true
	end
	return nextPosition, nextVelocity, segment, length, false
end

-- ---------------------------------------------------------------- WHERE THE BORE IS (task 259)
--
-- KAREN, 2026-10-24: *"we need to work on rifle acuracy when aiming with scope, it seems there is a
-- bit off"* and *"when boar is running we need to aim in empty space to get hit in head neck or
-- heart like in real life"*. Task 256 measured the ballistics and found them true to 1.5 cm
-- (research note sections 4 and 6), so the offset she feels is not the arc. It is HERE.
--
-- THE SHOT IS AIMED BY CONVERGENCE: the owner casts the camera ray, takes the point it hits, and
-- points the bore from the MUZZLE at that point (`docs/design/shotgun.md` section 5.5 steps 5-7).
-- That cancels the eye-to-muzzle offset EXACTLY AT THE AIM POINT and nowhere else. The design says
-- why it was chosen -- *"That is the standard THIRD-PERSON shooter geometry"* -- and the game has
-- been first-person since task 89.
--
-- THE EYE-TO-MUZZLE OFFSET IS 0.73 STUDS, MEASURED, and that is what makes this visible.
-- 2026-10-25, a DEV Play session, first person, reading the world Tool's `Muzzle` attachment in the
-- live camera's own frame (`driven-hunt-runs/259-eye-muzzle.luau`):
--     shotgun  (+0.741, -0.201, -5.274) studs
--     rifle    (+0.718, -0.135, -5.249) studs
-- The gun is welded to the character's right hand (`Hardware.GRIP`) and the hand is 20 cm to the
-- RIGHT of the eye. The player never sees that gun -- in first person he sees the viewmodel, which
-- `Mode.aimOffset` lays on the camera axis -- so the 0.73 studs is an artefact of an invisible prop.
--
-- WHAT IT COSTS WHEN THE RAY MISSES. With the aim point at `origin + direction * range`, the bore
-- converges at the ammo's whole range instead of on the target, and the offset is divided down
-- rather than cancelled: at target distance `d` the shot lands `offset * (1 - d/range)` off the
-- reticle. For the rifle (range 800) that is **0.66 studs (19 cm) RIGHT at 25 m, 0.58 (16 cm) at
-- 50 m and 0.41 (12 cm) at 100 m** -- always to the right, which is exactly how "a bit off" feels.
-- `sights.spec` measures every cell.
--
-- AND THE CASE THAT MISSES IS THE CASE SHE NAMED. Leading a running animal means aiming at EMPTY
-- SPACE: the ray goes past the animal and hits the sky, or a tree a long way behind it, and the
-- convergence distance is then that background's and not the animal's. So the error is not constant
-- -- it is whatever the thing behind the animal happens to be -- which is why it reads as the sights
-- being unreliable rather than as a fixed zero error.
--
-- THE FIX IS ONE POINT: PUT THE BORE ON THE SIGHT LINE. The muzzle is projected onto the camera ray
-- at its own depth, so `(aimPoint - origin)` is the camera's own direction whatever the ray hit, and
-- the only offset left is the ballistic one -- 1.6 cm inside 60 m (research note section 4).
--
-- IT IS A PARAMETER, SO BOTH PATHS ARE REACHABLE AND TESTABLE -- the shape task 256's
-- `FLIGHT_CATCHUP_*` already ships in and which `docs/design/ballistics.md` accepted in its place
-- for a flag. The shipped value is `Shotgun.CONFIG.BORE_ON_SIGHT_LINE`, and **it ships `true`
-- since task 260**: this header said `false` until task 265 round 2, which is what it shipped as
-- when the parameter was introduced, and the stale sentence cost that round's request a wrong
-- claim. `tests/server/sights.spec.luau` passes `false` explicitly in its rollback cases, which is
-- what keeps them meaningful now that the shipped value is the other one.
--
-- Note: docs/research/2026-10-24-real-shooting.md section 6; this task's own section 12.
function Ballistics.boreOrigin(eye: Vector3, look: Vector3, muzzle: Vector3, onSightLine: boolean?): Vector3
	if not onSightLine then
		return muzzle
	end
	local direction = look.Magnitude
	if direction < 1e-6 then
		return muzzle
	end
	local unit = look / direction
	-- THE MUZZLE'S OWN DEPTH, and never behind the eye. The bullet keeps leaving from as far forward
	-- as the gun reaches -- so the flight time, the range cap and what the first segment cast can
	-- strike are what they were -- and only the 0.73 studs ACROSS the sight line goes away.
	local depth = math.max(0, (muzzle - eye):Dot(unit))
	return eye + unit * depth
end

-- THE CONVERGENCE, AS ONE EXPRESSION (task 259). It was two lines inside `Weapon.onFireRequest`,
-- which meant a spec that wanted to measure where the bullet goes relative to the reticle had to
-- write its own copy of them -- and a copy is a second answer to "which way does the bore point".
--
-- `fallback` IS USED WHEN THE AIM POINT IS TOO CLOSE TO THE ORIGIN TO GIVE A DIRECTION, which is
-- `CONFIG.MIN_AIM_DISTANCE` (4 studs) and the guard `docs/design/shotgun.md` section 5.5 step 7
-- names: the degenerate case is answered explicitly rather than letting `.Unit` produce NaN.
function Ballistics.convergeAim(origin: Vector3, aimPoint: Vector3, fallback: Vector3, minStuds: number): Vector3
	local toAim = aimPoint - origin
	if toAim.Magnitude < minStuds then
		return fallback
	end
	return toAim.Unit
end

-- HOW FAR IN FRONT OF A CROSSING TARGET THE SHOT HAS TO GO, in studs. Exported because it is the
-- sentence Karen asked for written as arithmetic, and because the spec that proves "aiming at it
-- misses, aiming ahead hits" must take its offset from the same place everything else does -- not
-- from a number typed twice.
function Ballistics.leadStuds(shot: Shot, studs: number, targetStudsPerSecond: number): number
	return Ballistics.timeToRange(shot, studs) * targetStudsPerSecond
end

return Ballistics
