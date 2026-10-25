-- sights.spec: WHERE THE BULLET LANDS RELATIVE TO THE RETICLE, measured, gun by gun and range by
-- range (task 259).
--
-- KAREN, 2026-10-24, verbatim: *"we need to work on rifle acuracy when aiming with scope, it seems
-- there is a bit off"*, *"when boar is running we need to aim in empty space to get hit in head neck
-- or heart like in real life smae with other animals"*, *"all shooting has to be like in real life /
-- this is a key of this game"*.
--
-- TASK 256 ALREADY RULED OUT THE ARITHMETIC (research note sections 4 and 6): the ballistic arc is
-- +1.5 cm at the rifle's worst point anywhere, the sway moves the CAMERA so the reticle still marks
-- where the bullet goes, and the convergence is exact at the point the aim ray hit. Its own
-- conclusion was that item 3 *"needs a MEASUREMENT IN THE PLACE, not a code change guessed from
-- here"*. This file is that measurement, written as assertions.
--
-- WHAT IT MEASURES, AND WHY IT CAN. `Flight:advance` takes its `dt` and its CAST as parameters, so a
-- target can be a PLANE answered by a stub: `plate(d)` returns the point where a cast segment
-- crosses the plane `d` studs in front of the eye. The impact that comes back is the real stepper's,
-- through the real sub-step cap, off the real `Ballistics.launchDirection` and the real
-- `Ballistics.boreOrigin`/`convergeAim` the owner calls -- no Studio, no Workspace, no player, no
-- animal. The number printed is `impact - (eye + look * d)`, decomposed into UP and RIGHT: exactly
-- "how far from the middle of the reticle did it land".
--
-- THE ONE NUMBER THAT CAME FROM THE PLACE is the eye-to-muzzle offset, and it is MEASURED rather
-- than assumed -- 2026-10-25, a DEV Play session, first person, reading the world Tool's `Muzzle`
-- attachment in the live camera's own frame (`driven-hunt-runs/259-eye-muzzle.luau`):
--     shotgun  (+0.741, -0.201, -5.274) studs
--     rifle    (+0.718, -0.135, -5.249) studs
-- The gun is welded to the character's right hand (`Hardware.GRIP`), and the hand is 20 cm RIGHT of
-- the eye. The shotgun's is used below because it is the larger of the two, and `OFFSETS` sweeps
-- three more so no case rests on one reading.
--
-- THE SHOT IS ONE PROJECTILE ALONG THE BORE and not a pattern, deliberately: this file asks where
-- the SIGHT LINE puts the bullet. The cone about that line is a separate number with its own
-- assertions (`Shotgun.CONFIG.SPREAD_FULL_DEG`, `rifle.spec`, `semiauto.spec`), and patterning here
-- would add a random radius to a measurement of a bias.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/shotgun.md (section 5.5 steps 5-7), docs/design/ballistics.md (sections 5, 11)
-- Note:   docs/research/2026-10-24-real-shooting.md (sections 4, 6 and 12)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Ballistics = require(ReplicatedStorage:WaitForChild("Ballistics"))
-- THE ONE METRE/STUD CONVERSION (`Report.CONFIG.METRES_PER_STUD`): read, never copied -- the rule
-- `Ballistics` itself states. A second 0.28 in this file would be a second answer to how far 25 m is.
local Report = require(ReplicatedStorage:WaitForChild("Report"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))

local Flight = Weapon.Flight

local METRES_PER_STUD = Report.CONFIG.METRES_PER_STUD

-- The flight config, hand-written for the same reason `weapon_hits.spec`'s is: every bound this file
-- claims something about has to be reachable at a value the game never produces.
local FLIGHT_CONFIG = {
	FLIGHT_STEP_MAX_SECONDS = Shotgun.CONFIG.FLIGHT_STEP_MAX_SECONDS,
	FLIGHT_MAX_SUBSTEPS = Shotgun.CONFIG.FLIGHT_MAX_SUBSTEPS,
	FLIGHT_MAX_SECONDS = Shotgun.CONFIG.FLIGHT_MAX_SECONDS,
	FLIGHT_MAX_LIVE_PELLETS = 512,
}

-- A Heartbeat's own step. 1/60 is what a Studio server runs at and what the shipped flight is
-- stepped by; the sub-step cap is 1/30, so this is one sub-step per frame -- the production case.
local DT = 1 / 60

local EYE = Vector3.zero
local LOOK = Vector3.new(0, 0, -1)

-- MEASURED IN THE PLACE (see the header). First the shotgun's own reading, then three more so the
-- claim is about the GEOMETRY rather than about one measurement: a gun held level under the eye, the
-- rifle's reading, and a deliberately extreme hold.
local OFFSETS = {
	{ name = "measured shotgun", at = Vector3.new(0.741, -0.201, -5.274) },
	{ name = "measured rifle", at = Vector3.new(0.718, -0.135, -5.249) },
	{ name = "under the eye", at = Vector3.new(0, -0.375, -2.0) },
	{ name = "extreme hold", at = Vector3.new(1.4, -1.6, -3.0) },
}

-- THE THREE RANGES THE DISPATCH NAMES, in metres. The lever and the semi-auto are asked only where
-- their ammo reaches: buckshot retires at 100 studs = 28 m (research note section 3), so a 50 m
-- buckshot figure is not a measurement, it is a projectile that was never there.
local RANGES_M = { 25, 50, 100 }

local GUNS = {
	{ id = "rifle", ammo = "Slug", label = "rifle .416 (scope)" },
	{ id = "lever", ammo = "Slug", label = "lever .45-70 (open sights)" },
	{ id = "semiauto", ammo = "Buck", label = "semi-auto Buck (red dot)" },
	{ id = "semiauto", ammo = "Slug", label = "semi-auto Slug (red dot)" },
	{ id = "shotgun", ammo = "Slug", label = "shotgun Slug (bead)" },
}

-- A PLATE `d` STUDS IN FRONT OF THE EYE, square to the sight line, answered as a cast. The segment
-- the stepper just travelled is intersected with the plane; a segment that does not reach it answers
-- nil, exactly as a cast into empty air does.
--
-- INFINITE IN X AND Y ON PURPOSE: a finite plate would turn "the shot landed 0.66 studs right of
-- the middle" into "the shot missed the plate", which measures nothing. The offset is the quantity.
local function plate(d: number)
	local planePoint = EYE + LOOK * d
	return function(origin: Vector3, direction: Vector3)
		local denominator = LOOK:Dot(direction)
		if math.abs(denominator) < 1e-12 then
			return nil
		end
		local u = LOOK:Dot(planePoint - origin) / denominator
		if u < 0 or u > 1 then
			return nil
		end
		local position = origin + direction * u
		return {
			instance = nil :: any,
			position = position,
			normal = -LOOK,
			distance = (position - origin).Magnitude,
		}
	end
end

-- ONE SHOT, FLOWN. Returns the impact's offset from the middle of the reticle as (up, right) studs,
-- or nil if the projectile never reached the plate.
--
-- `aimPoint` IS THE ARGUMENT, because it is the whole subject: the owner takes it from the aim cast,
-- and whether that cast hit the TARGET or something far behind it is what this file measures.
local function fire(
	row: any,
	ammo: string,
	muzzle: Vector3,
	targetStuds: number,
	aimPoint: Vector3,
	onSightLine: boolean
)
	local ballistic = Ballistics.shotFor(row, ammo)
	if ballistic == nil then
		return nil
	end
	-- THE OWNER'S OWN TWO CALLS, in the owner's order (`Weapon.onFireRequest`). Not a copy of them:
	-- these are the functions it calls, which is why this measures the shipped path.
	local origin = Ballistics.boreOrigin(EYE, LOOK, muzzle, onSightLine)
	local aim = Ballistics.convergeAim(origin, aimPoint, LOOK, Shotgun.CONFIG.MIN_AIM_DISTANCE)
	local bore = Ballistics.launchDirection(aim, ballistic)

	local flight = Flight.new(FLIGHT_CONFIG)
	flight:launch({
		shooter = nil :: any,
		shooterUserId = 1,
		weapon = "sights.spec",
		ammo = ammo,
		muzzle = origin,
		ignore = {},
		rangeStuds = row.RANGE_STUDS[ammo],
		firedAt = 0,
		epoch = 1,
	}, { bore }, ballistic)

	local cast = plate(targetStuds)
	for _ = 1, 240 do
		local finished = flight:advance(DT, cast)
		for _, resolution in ipairs(finished) do
			local impact = resolution.impacts[1]
			if impact == nil then
				return nil
			end
			local centre = EYE + LOOK * targetStuds
			local delta = impact.position - centre
			return { up = delta.Y, right = delta.X }
		end
	end
	return nil
end

local function cm(studs: number): number
	return studs * METRES_PER_STUD * 100
end

return function()
	-- THE BOUND INSIDE 60 m, from the research note's own section 4 table: every weapon and every
	-- load is within 1.6 cm of the reticle there, which is 3.5 % of a boar's chest zone. 0.06 studs
	-- is 1.68 cm -- the note's number with a hair of room for the stepper's discretisation.
	local BALLISTIC_BOUND_STUDS = 0.06
	-- ...AND AT 100 m the rifle's own arc reaches +1.5 cm and the lever crosses its zero, so the same
	-- bound holds; it is stated separately because it is a different claim about a different range.
	local BALLISTIC_BOUND_100M_STUDS = 0.06

	describe("the sights, when the aim ray lands ON the target", function()
		-- This is the case the convergence was designed for and it is already right: the bore is
		-- pointed at the exact point the camera ray struck, so the eye-to-muzzle offset cancels and
		-- what is left is the ballistic arc. Asserted FIRST because it is the baseline every number
		-- below is measured against -- and because it is what makes the next describe a DEFECT rather
		-- than a property of the arithmetic.
		for _, gun in ipairs(GUNS) do
			local row = Weapons.row(gun.id)
			it(
				string.format(
					"%s lands within %.2f cm of the reticle at every range it reaches",
					gun.label,
					cm(BALLISTIC_BOUND_STUDS)
				),
				function()
					expect(row).to.be.ok()
					local measured = 0
					for _, metres in ipairs(RANGES_M) do
						local d = metres / METRES_PER_STUD
						if d <= row.RANGE_STUDS[gun.ammo] then
							for _, offset in ipairs(OFFSETS) do
								local muzzle = EYE + offset.at
								-- THE AIM POINT IS THE TARGET: the camera ray hit the plate.
								local hit = fire(row, gun.ammo, muzzle, d, EYE + LOOK * d, false)
								expect(hit).to.be.ok()
								local bound = if metres >= 100
									then BALLISTIC_BOUND_100M_STUDS
									else BALLISTIC_BOUND_STUDS
								if math.abs(hit.up) > bound or math.abs(hit.right) > bound then
									error(
										string.format(
											"[sights] %s at %d m, muzzle %s: %+.2f cm up, %+.2f cm right -- past %.2f cm",
											gun.label,
											metres,
											offset.name,
											cm(hit.up),
											cm(hit.right),
											cm(bound)
										)
									)
								end
								measured += 1
							end
						end
					end
					-- Every gun must have been measured somewhere, or a typo in `RANGE_STUDS` would make
					-- this `it` pass by measuring nothing.
					expect(measured > 0).to.equal(true)
				end
			)
		end
	end)

	describe("the sights, when the aim ray lands PAST the target -- the defect task 260 fixed", function()
		-- KAREN'S OWN CASE, AND IT IS NOW THE ROLLBACK BRANCH. Leading a running animal means aiming
		-- at EMPTY SPACE, so the aim ray goes past it: with `BORE_ON_SIGHT_LINE` **false** the owner
		-- falls back to `origin + direction * range` (design 5.5 step 5), the bore converges at the
		-- ammo's whole range instead of on the animal, and the eye-to-muzzle offset is DIVIDED DOWN
		-- rather than cancelled -- `offset * (1 - d/range)` at the target.
		--
		-- EVERY CASE HERE PASSES `false` EXPLICITLY, which is what keeps them meaningful now that the
		-- shipped value is `true`: they are the measurement of what the game used to do, and they are
		-- what the shipped-value cases below are measured against. The numbers are LOWER bounds, so
		-- they fail if somebody quietly makes the old error smaller without saying so.
		it("puts the rifle 0.4 studs or more off the reticle at every range, always to the RIGHT", function()
			local row = Weapons.row("rifle")
			local range = row.RANGE_STUDS.Slug
			local worst = 0
			for _, metres in ipairs(RANGES_M) do
				local d = metres / METRES_PER_STUD
				local muzzle = EYE + OFFSETS[1].at
				local hit = fire(row, "Slug", muzzle, d, EYE + LOOK * range, false)
				expect(hit).to.be.ok()
				print(
					string.format(
						"[sights] rifle, ray MISSES, %d m: %+.1f cm up, %+.1f cm right",
						metres,
						cm(hit.up),
						cm(hit.right)
					)
				)
				-- RIGHT, because the gun is in the right hand. The sign is the half of this that
				-- tells a player it is the GUN and not his aim.
				expect(hit.right > 0).to.equal(true)
				-- 0.4 studs is 11 cm. The measured series is 0.66 / 0.58 / 0.41 studs at 25 / 50 /
				-- 100 m, so this bites at the loosest of the three.
				expect(hit.right >= 0.4).to.equal(true)
				worst = math.max(worst, math.abs(hit.right))
			end
			-- ...AND IT IS WORST AT THE SHORTEST RANGE, which is the opposite of how a player expects
			-- a sight error to behave and part of why it reads as unreliable rather than as a zero.
			expect(worst >= 0.6).to.equal(true)
		end)

		it("is the eye-to-muzzle offset divided down, so a gun held under the eye has no sideways error", function()
			local row = Weapons.row("rifle")
			local range = row.RANGE_STUDS.Slug
			local d = 50 / METRES_PER_STUD
			-- `under the eye` has x = 0, so the sideways half of the defect is exactly 0 and the
			-- vertical half is its own 0.375 studs divided down. That is the mechanism named, not
			-- just the symptom measured.
			local hit = fire(row, "Slug", EYE + OFFSETS[3].at, d, EYE + LOOK * range, false)
			expect(hit).to.be.ok()
			expect(math.abs(hit.right) < 1e-3).to.equal(true)
			expect(hit.up < -0.2).to.equal(true)
		end)

		it("is worse the nearer the thing behind the animal is to the animal itself", function()
			-- The background decides the convergence distance, so the SAME shot at the SAME animal
			-- is off by a different amount depending on what is behind it. That is the whole of
			-- *"it seems there is a bit off"*: not a zero error a player can learn, a different one
			-- every shot.
			local row = Weapons.row("rifle")
			local d = 50 / METRES_PER_STUD
			local far = fire(row, "Slug", EYE + OFFSETS[1].at, d, EYE + LOOK * row.RANGE_STUDS.Slug, false)
			local near = fire(row, "Slug", EYE + OFFSETS[1].at, d, EYE + LOOK * (d * 1.3), false)
			expect(far).to.be.ok()
			expect(near).to.be.ok()
			print(
				string.format(
					"[sights] rifle at 50 m: sky behind %+.1f cm right, a tree 1.3x behind %+.1f cm right",
					cm(far.right),
					cm(near.right)
				)
			)
			expect(far.right > near.right).to.equal(true)
			expect(near.right > 0).to.equal(true)
		end)
	end)

	describe("BORE_ON_SIGHT_LINE -- the fix, measured at both values", function()
		-- THE PARAMETER IS THE SHAPE TASK 256 ALREADY SHIPPED and `docs/design/ballistics.md`
		-- accepted in place of a flag by name: a path reachable at both values can be tested at both
		-- while the shipped value sits at one of them. **SINCE TASK 260 THE SHIPPED VALUE IS `true`**
		-- (the Director's decision on `ESCALATE.md`'s option 1, 2026-10-25, and
		-- `docs/design/shotgun.md` amended in the same task); `false` is the rollback and is still
		-- measured by the describe above.
		it("is TRUE in the shipped build, and the shipped build is what hits the reticle", function()
			-- TWO ASSERTIONS AND THE SECOND ONE IS THE POINT (the Learning Agent's L-028: a
			-- shipped-value assertion has to fail on the PRE-FLIP config for the right REASON, not
			-- just because a boolean changed). The first reads the row; the second fires the
			-- SHIPPED value through the whole chain at the case Karen named -- the aim ray missing --
			-- and demands the reticle. At `false` that second expectation lands 0.41 studs right at
			-- 100 m and 0.66 at 25 m, so it fails by a factor of ten.
			expect(Shotgun.CONFIG.BORE_ON_SIGHT_LINE).to.equal(true)
			local row = Weapons.row("rifle")
			local range = row.RANGE_STUDS.Slug
			for _, metres in ipairs(RANGES_M) do
				local d = metres / METRES_PER_STUD
				local hit =
					fire(row, "Slug", EYE + OFFSETS[1].at, d, EYE + LOOK * range, Shotgun.CONFIG.BORE_ON_SIGHT_LINE)
				expect(hit).to.be.ok()
				if math.abs(hit.up) > BALLISTIC_BOUND_STUDS or math.abs(hit.right) > BALLISTIC_BOUND_STUDS then
					error(
						string.format(
							"[sights] SHIPPED value at %d m with the ray missing: %+.2f cm up, %+.2f cm right -- past %.2f cm",
							metres,
							cm(hit.up),
							cm(hit.right),
							cm(BALLISTIC_BOUND_STUDS)
						)
					)
				end
			end
		end)

		it("at false, reproduces the muzzle origin exactly -- the same Vector3, not a near one", function()
			local muzzle = EYE + OFFSETS[1].at
			expect(Ballistics.boreOrigin(EYE, LOOK, muzzle, false)).to.equal(muzzle)
			expect(Ballistics.boreOrigin(EYE, LOOK, muzzle, nil)).to.equal(muzzle)
		end)

		it("at true, puts the origin on the sight line at the muzzle's own depth", function()
			local muzzle = EYE + OFFSETS[1].at
			local origin = Ballistics.boreOrigin(EYE, LOOK, muzzle, true)
			-- ON the ray: the cross product of (origin - eye) with the look vector is zero.
			expect((origin - EYE):Cross(LOOK).Magnitude < 1e-5).to.equal(true)
			-- AT THE MUZZLE'S DEPTH, so the flight time, the range cap and what the first segment
			-- cast can strike are what they were.
			expect(math.abs((origin - EYE):Dot(LOOK) - 5.274) < 1e-4).to.equal(true)
		end)

		it("never puts the origin behind the eye, however the gun is held", function()
			-- A muzzle BEHIND the eye -- a gun swung round, or a camera that has turned past it --
			-- must not launch the bullet out of the back of the player's head.
			local behind = EYE + Vector3.new(0.7, -0.2, 4.0)
			local origin = Ballistics.boreOrigin(EYE, LOOK, behind, true)
			expect(origin).to.equal(EYE)
		end)

		it("at true, holds the ballistic bound even when the aim ray MISSES -- every gun, every range", function()
			local measured = 0
			for _, gun in ipairs(GUNS) do
				local row = Weapons.row(gun.id)
				local range = row.RANGE_STUDS[gun.ammo]
				for _, metres in ipairs(RANGES_M) do
					local d = metres / METRES_PER_STUD
					if d <= range then
						for _, offset in ipairs(OFFSETS) do
							local hit = fire(row, gun.ammo, EYE + offset.at, d, EYE + LOOK * range, true)
							expect(hit).to.be.ok()
							if
								math.abs(hit.up) > BALLISTIC_BOUND_STUDS
								or math.abs(hit.right) > BALLISTIC_BOUND_STUDS
							then
								error(
									string.format(
										"[sights] ON, %s at %d m, muzzle %s: %+.2f cm up, %+.2f cm right -- past %.2f cm",
										gun.label,
										metres,
										offset.name,
										cm(hit.up),
										cm(hit.right),
										cm(BALLISTIC_BOUND_STUDS)
									)
								)
							end
							measured += 1
						end
					end
				end
			end
			expect(measured > 0).to.equal(true)
			print(
				string.format(
					"[sights] BORE_ON_SIGHT_LINE on: %d (gun, range, hold) cells inside %.2f cm with the ray missing",
					measured,
					cm(BALLISTIC_BOUND_STUDS)
				)
			)
		end)

		it("at true, changes nothing when the aim ray lands ON the target", function()
			-- The case that was already right must stay right, or the fix would be a trade.
			local row = Weapons.row("rifle")
			local d = 100 / METRES_PER_STUD
			local off = fire(row, "Slug", EYE + OFFSETS[1].at, d, EYE + LOOK * d, false)
			local on = fire(row, "Slug", EYE + OFFSETS[1].at, d, EYE + LOOK * d, true)
			expect(off).to.be.ok()
			expect(on).to.be.ok()
			expect(math.abs(on.up - off.up) < 0.01).to.equal(true)
			expect(math.abs(on.right - off.right) < 0.01).to.equal(true)
		end)

		it("prints the before-and-after table the dispatch asked for", function()
			local printed = 0
			-- NOT AN ASSERTION, A REPORT -- except that it asserts the thing it prints (the
			-- Reviewer's round-1 note): `expect(true)` here was a passing check in the harness tally
			-- that could not fail, while `fire` answers nil for a projectile that never reached the
			-- plate and `cm(nil)` would have errored anyway. `printed` is what makes the sweep's own
			-- completeness the claim.
			for _, gun in ipairs(GUNS) do
				local row = Weapons.row(gun.id)
				local range = row.RANGE_STUDS[gun.ammo]
				for _, metres in ipairs(RANGES_M) do
					local d = metres / METRES_PER_STUD
					if d <= range then
						local muzzle = EYE + OFFSETS[1].at
						local onTarget = fire(row, gun.ammo, muzzle, d, EYE + LOOK * d, false)
						local missed = fire(row, gun.ammo, muzzle, d, EYE + LOOK * range, false)
						local fixed = fire(row, gun.ammo, muzzle, d, EYE + LOOK * range, true)
						print(
							string.format(
								"[sights] %-26s %3d m | ray ON target %+5.1f/%+5.1f cm | ray MISSES %+6.1f/%+6.1f cm | FIXED %+5.1f/%+5.1f cm  (up/right)",
								gun.label,
								metres,
								cm(onTarget.up),
								cm(onTarget.right),
								cm(missed.up),
								cm(missed.right),
								cm(fixed.up),
								cm(fixed.right)
							)
						)
						printed += 1
					end
				end
			end
			-- 11 = rifle 3 + lever 3 + semi-auto Slug 2 + shotgun Slug 2 + semi-auto Buck 1. Buckshot
			-- reaches 28 m, so only its 25 m cell exists; the two 330-stud slugs stop before 100 m.
			expect(printed).to.equal(11)
		end)
	end)
end
