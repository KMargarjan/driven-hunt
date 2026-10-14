-- ballistics.spec: the pure maths of a shot that takes time to arrive (task 185).
--
-- No world, no clock, no Studio interaction, no boar, no player. `ReplicatedStorage.Ballistics` is
-- frozen numbers plus functions of their arguments, so everything here is arithmetic -- which is
-- the whole reason the module is shaped that way (docs/design/ballistics.md section 2).
--
-- WHAT IT IS FOR, said plainly: it pins the three ballistic numbers of each weapon against the
-- research note, so a muzzle velocity that drifts fails the harness instead of quietly changing how
-- much lead Karen has to hold. One case (`speedAt` at 200 yd) has its right answer from OUTSIDE the
-- repo -- a published .416 Rigby velocity the drag coefficient was never fitted to.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/ballistics.md (sections 4.1, 10, 11.1)
-- Note:   docs/research/2026-10-14-ballistics-lead.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Ballistics = require(ReplicatedStorage:WaitForChild("Ballistics"))
local Report = require(ReplicatedStorage:WaitForChild("Report"))
local Rifle = require(ReplicatedStorage:WaitForChild("Rifle"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

-- A boar at a sprint, which is the speed every lead figure in the note is quoted at. Read off the
-- animal's own owner would be a server require from a shared spec; `Boar.CONFIG.SPRINT_SPEED` is 38
-- and `boar_behaviour.spec` is what pins it, so this is a local with its source named.
local BOAR_SPRINT_STUDS = 38

local function near(actual: number, expected: number, tolerance: number)
	expect(math.abs(actual - expected) <= tolerance).to.equal(true)
end

return function()
	local rifleShot = Ballistics.shotFor(Weapons.ROWS.rifle, "Slug")
	local slugShot = Ballistics.shotFor(Weapons.ROWS.shotgun, "Slug")
	local buckShot = Ballistics.shotFor(Weapons.ROWS.shotgun, "Buck")

	describe("the three numbers come off the real rows", function()
		it("reads all three for every ammo both shipped weapons carry", function()
			for id, row in pairs(Weapons.ROWS) do
				for _, ammo in ipairs(row.AMMO_KINDS) do
					local shot = Ballistics.shotFor(row, ammo)
					expect(shot).to.be.ok()
					expect(type((shot :: any).v0)).to.equal("number")
					expect((shot :: any).v0 > 0).to.equal(true)
					expect(type((shot :: any).k)).to.equal("number")
					expect(type((shot :: any).zeroStuds)).to.equal("number")
					-- A ZERO BEYOND THE RANGE CAP IS A DATA FAULT: the trajectory would never reach
					-- the distance it is zeroed at, so a still target could not be dead centre
					-- anywhere.
					expect((shot :: any).zeroStuds <= row.RANGE_STUDS[ammo]).to.equal(true)
					expect(table.isfrozen(shot :: any)).to.equal(true)
					expect(id).to.be.ok()
				end
			end
		end)

		it("is the section-10 table, so a number that drifts fails here", function()
			near((rifleShot :: any).v0, 2612, 0)
			near((rifleShot :: any).k, 4.29e-4, 0)
			near((rifleShot :: any).zeroStuds, 714, 0)
			near((slugShot :: any).v0, 1752, 0)
			near((slugShot :: any).k, 1.059e-3, 0)
			near((slugShot :: any).zeroStuds, 180, 0)
			near((buckShot :: any).v0, 1442, 0)
			near((buckShot :: any).k, 2.631e-3, 0)
			near((buckShot :: any).zeroStuds, 70, 0)
		end)

		it("answers nil for an unknown ammo and for a row missing any one of the three", function()
			expect(Ballistics.shotFor(Weapons.ROWS.rifle, "Buck")).to.equal(nil)
			expect(Ballistics.shotFor(Weapons.ROWS.rifle, "Birdshot")).to.equal(nil)
			expect(Ballistics.shotFor(nil, "Slug")).to.equal(nil)
			expect(Ballistics.shotFor({}, "Slug")).to.equal(nil)
			-- ONE MISSING FIELD IS ENOUGH, each of the three in turn: this is the branch that
			-- refuses the shot in `onFireRequest` rather than firing it in a straight line.
			local full = {
				MUZZLE_STUDS_PER_S = { Slug = 1000 },
				DRAG_PER_STUD = { Slug = 1e-3 },
				ZERO_STUDS = { Slug = 100 },
			}
			expect(Ballistics.shotFor(full, "Slug")).to.be.ok()
			for _, field in ipairs({ "MUZZLE_STUDS_PER_S", "DRAG_PER_STUD", "ZERO_STUDS" }) do
				local partial = table.clone(full)
				partial[field] = nil
				expect(Ballistics.shotFor(partial, "Slug")).to.equal(nil)
			end
			-- A zero or negative muzzle velocity is a fault too: nothing can fly at it.
			expect(Ballistics.shotFor({
				MUZZLE_STUDS_PER_S = { Slug = 0 },
				DRAG_PER_STUD = { Slug = 1e-3 },
				ZERO_STUDS = { Slug = 100 },
			}, "Slug")).to.equal(nil)
		end)

		it("takes its numbers from each gun's own CONFIG and holds no copy", function()
			expect(Weapons.ROWS.rifle.MUZZLE_STUDS_PER_S).to.equal(Rifle.CONFIG.MUZZLE_STUDS_PER_S)
			expect(Weapons.ROWS.rifle.DRAG_PER_STUD).to.equal(Rifle.CONFIG.DRAG_PER_STUD)
			expect(Weapons.ROWS.rifle.ZERO_STUDS).to.equal(Rifle.CONFIG.ZERO_STUDS)
			expect(Weapons.ROWS.shotgun.MUZZLE_STUDS_PER_S).to.equal(Shotgun.CONFIG.MUZZLE_STUDS_PER_S)
			expect(Weapons.ROWS.shotgun.DRAG_PER_STUD).to.equal(Shotgun.CONFIG.DRAG_PER_STUD)
			expect(Weapons.ROWS.shotgun.ZERO_STUDS).to.equal(Shotgun.CONFIG.ZERO_STUDS)
		end)
	end)

	describe("gravity has exactly one source", function()
		it("derives studs/s^2 from the repo's one metre/stud conversion", function()
			expect(Ballistics.CONFIG.METRES_PER_STUD).to.equal(Report.CONFIG.METRES_PER_STUD)
			expect(Ballistics.CONFIG.GRAVITY_M_PER_S2).to.equal(9.81)
			near(Ballistics.CONFIG.GRAVITY_STUDS_PER_S2, 9.81 / Report.CONFIG.METRES_PER_STUD, 1e-9)
			near(Ballistics.CONFIG.GRAVITY_STUDS_PER_S2, 35.0357, 1e-3)
			-- NOT Workspace.Gravity (196.2), which is the engine's number for CHARACTERS: a bullet
			-- falling at that rate would drop six times too far.
			expect(Ballistics.CONFIG.GRAVITY_STUDS_PER_S2 < 40).to.equal(true)
			expect(table.isfrozen(Ballistics.CONFIG)).to.equal(true)
		end)

		it("takes g as a parameter, so a spec can read it at another value", function()
			local _, velocity = Ballistics.advance(Vector3.zero, Vector3.new(100, 0, 0), 1, rifleShot :: any, 0)
			near(velocity.Y, 0, 1e-9) -- g = 0 drops nothing
			near(Ballistics.dropAt(rifleShot :: any, 714, 0), 0, 1e-9)
		end)
	end)

	describe("time of flight, in closed form", function()
		it("is the section-10 table, per weapon per ammo", function()
			near(Ballistics.timeToRange(rifleShot :: any, 179), 0.071, 0.001)
			near(Ballistics.timeToRange(rifleShot :: any, 357), 0.148, 0.001)
			near(Ballistics.timeToRange(rifleShot :: any, 714), 0.320, 0.001)
			near(Ballistics.timeToRange(rifleShot :: any, 800), 0.365, 0.001)
			near(Ballistics.timeToRange(slugShot :: any, 179), 0.113, 0.001)
			near(Ballistics.timeToRange(slugShot :: any, 330), 0.225, 0.001)
			near(Ballistics.timeToRange(buckShot :: any, 100), 0.079, 0.001)
		end)

		it("is zero at zero range and never negative", function()
			expect(Ballistics.timeToRange(rifleShot :: any, 0)).to.equal(0)
			expect(Ballistics.timeToRange(rifleShot :: any, -10)).to.equal(0)
		end)

		it("answers the drag-free limit as s/v0 rather than dividing by zero", function()
			local noDrag = { v0 = 1000, k = 0, zeroStuds = 0 }
			near(Ballistics.timeToRange(noDrag, 500), 0.5, 1e-9)
			expect(Ballistics.speedAt(noDrag, 500)).to.equal(1000)
		end)

		it("THE LEAD KAREN HAS TO HOLD: the note's own table, at a boar's sprint", function()
			-- This is the feature as arithmetic. A boar is about 1.5 m (5.4 studs) long.
			near(Ballistics.leadStuds(rifleShot :: any, 357, BOAR_SPRINT_STUDS), 5.6, 0.1)
			near(Ballistics.leadStuds(rifleShot :: any, 714, BOAR_SPRINT_STUDS), 12.2, 0.1)
			near(Ballistics.leadStuds(slugShot :: any, 330, BOAR_SPRINT_STUDS), 8.6, 0.1)
			near(Ballistics.leadStuds(buckShot :: any, 100, BOAR_SPRINT_STUDS), 3.0, 0.1)
			-- ...AND "SAME WITH S/S" MEANS MORE LEAD, NOT THE SAME LEAD. At one distance both guns
			-- reach, the slug needs about 60% more than the rifle, because it leaves at two thirds
			-- of the speed and loses it four times as fast.
			local atFifty = 179
			local rifleLead = Ballistics.leadStuds(rifleShot :: any, atFifty, BOAR_SPRINT_STUDS)
			local slugLead = Ballistics.leadStuds(slugShot :: any, atFifty, BOAR_SPRINT_STUDS)
			expect(slugLead > rifleLead * 1.4).to.equal(true)
			expect(slugLead < rifleLead * 1.8).to.equal(true)
			TestKit.note(
				string.format("[ballistics] lead at 50 m: rifle %.2f studs, slug %.2f studs", rifleLead, slugLead)
			)
		end)
	end)

	describe("the drag model against a number it was not fitted to", function()
		it("predicts the rifle's published 200 yd velocity within 1%", function()
			-- `DRAG_PER_STUD` was fitted to 2400 -> 2086 fps over 100 yd. 200 yd is 182.88 m = 653.1
			-- studs, and the published remaining velocity there is 1797 fps = 547.7 m/s = 1956
			-- studs/s. Nothing in this repo was fitted to that number.
			local published = 1797 * 0.3048 / Report.CONFIG.METRES_PER_STUD
			local predicted = Ballistics.speedAt(rifleShot :: any, 182.88 / Report.CONFIG.METRES_PER_STUD)
			TestKit.note(
				string.format(
					"[ballistics] rifle at 200 yd: predicted %.0f studs/s, published %.0f",
					predicted,
					published
				)
			)
			expect(math.abs(predicted - published) / published < 0.01).to.equal(true)
		end)

		it("is the muzzle velocity at the muzzle and falls monotonically", function()
			expect(Ballistics.speedAt(rifleShot :: any, 0)).to.equal((rifleShot :: any).v0)
			local last = (rifleShot :: any).v0
			for studs = 50, 800, 50 do
				local speed = Ballistics.speedAt(rifleShot :: any, studs)
				expect(speed < last).to.equal(true)
				last = speed
			end
		end)
	end)

	describe("the zero, the drop, and task 183 preserved", function()
		it("is exactly on the sight line at the zero distance, for all three ammos", function()
			for _, shot in ipairs({ rifleShot, slugShot, buckShot }) do
				near(Ballistics.sightOffsetAt(shot :: any, (shot :: any).zeroStuds), 0, 1e-6)
			end
		end)

		it("is the drop table, including the slug's published check", function()
			-- Drag-corrected (`Ballistics.dropAt`), so these are ~9% flatter than the vacuum formula
			-- this task first shipped -- which is the correction that made a still target land on the
			-- reticle at its own zero rather than 4.7 cm under it.
			near(Ballistics.sightOffsetAt(rifleShot :: any, 357), 0.448, 0.02)
			near(Ballistics.sightOffsetAt(rifleShot :: any, 800), -0.275, 0.02)
			near(Ballistics.sightOffsetAt(slugShot :: any, 330), -0.409, 0.02)
			near(Ballistics.sightOffsetAt(buckShot :: any, 100), -0.034, 0.02)
			-- THE MODEL AGAINST A NUMBER IT WAS NOT FITTED TO. Federal publishes -5.7 in (-14.5 cm)
			-- at 100 yd for a rifled slug zeroed at 50 yd; this says -11.4 cm at 92 m. The same shot
			-- to about 3 cm, and the gap is honest rather than tuned away: that table is one specific
			-- load's ballistic coefficient, and it is quoted from a SIGHT LINE 1.5 in above the bore,
			-- which this model does not have. The bound is 4 cm, which is what "the same shot" is
			-- worth here -- a tighter one would be fitting to a load we do not fire.
			local cm = Ballistics.sightOffsetAt(slugShot :: any, 330) * Report.CONFIG.METRES_PER_STUD * 100
			TestKit.note(string.format("[ballistics] slug drop at 92 m: %.1f cm (Federal: -14.5 cm at 100 yd)", cm))
			near(cm, -14.5, 4.0)
		end)

		it("rides high between the muzzle and the zero, and low beyond it", function()
			-- A real rifle's trajectory: below the sight line at the muzzle is not modelled (there is
			-- no scope-height offset), so it rises from 0, peaks, returns to 0 at the zero, and falls.
			expect(Ballistics.sightOffsetAt(rifleShot :: any, 100) > 0).to.equal(true)
			expect(Ballistics.sightOffsetAt(rifleShot :: any, 357) > 0).to.equal(true)
			expect(Ballistics.sightOffsetAt(rifleShot :: any, 800) < 0).to.equal(true)
			expect(Ballistics.sightOffsetAt(slugShot :: any, 330) < 0).to.equal(true)
		end)

		it("elevates the bore by 0.1302 degrees for the rifle -- against a 45-degree safety cone", function()
			local tangent = Ballistics.elevationTangent(rifleShot :: any)
			near(tangent, 2.272e-3, 1e-5)
			local degrees = math.deg(math.atan(tangent))
			near(degrees, 0.1302, 1e-3)
			-- THE REASON THE SAFETY ARC'S VERDICT DID NOT MOVE (design section 5 of the note): the
			-- launch direction differs from the sight line by this, and the forbidden cone is
			-- SAFETY_ARC_HALF_DEG wide.
			expect(degrees < Shotgun.CONFIG.SAFETY_ARC_HALF_DEG / 100).to.equal(true)
		end)
	end)

	describe("the launch direction", function()
		it("is a unit vector elevated in the plane of aim and up", function()
			local aim = Vector3.new(0, 0, -1)
			local bore = Ballistics.launchDirection(aim, rifleShot :: any)
			near(bore.Magnitude, 1, 1e-6)
			near(math.deg(math.acos(math.clamp(bore:Dot(aim), -1, 1))), 0.1302, 1e-2)
			expect(bore.Y > 0).to.equal(true) -- elevated, not depressed
			expect(math.abs(bore.X) < 1e-9).to.equal(true) -- stayed in the aim/up plane
		end)

		it("is `aim` itself when there is no zero, and never NaN straight up", function()
			local aim = Vector3.new(0, 0, -1)
			local noZero = { v0 = 2612, k = 4.29e-4, zeroStuds = 0 }
			expect(Ballistics.launchDirection(aim, noZero)).to.equal(aim)
			local up = Ballistics.launchDirection(Vector3.yAxis, rifleShot :: any)
			near(up.Magnitude, 1, 1e-6)
			expect(up.Y == up.Y).to.equal(true) -- not NaN
			near(up.Y, 1, 1e-6)
		end)

		it("KEEPS TASK 183: a still target at the zero is hit within 0.05 studs of dead centre", function()
			-- The case that would catch an elevation with the wrong sign.
			--
			-- IT MEASURES THE SIDEWAYS MISS AT THE ZERO, NOT THE CLOSEST SAMPLE. The first version of
			-- this case took the nearest stepped position to the target point, which measures the
			-- STEP LENGTH (10.9 studs for the rifle at dt = 1/240) and not the shot: it failed at
			-- 5 studs with the maths perfectly right. What a player feels is how far from the reticle
			-- the hole is, so this finds the step where the path crosses the zero's RANGE, lands on
			-- the crossing by linear interpolation, and measures what is left -- which at that range
			-- is purely transverse.
			--
			-- Three aims, so it is not a flat-ground accident: the elevation is applied in world up,
			-- which is the standard approximation, and an uphill or downhill shot is where that shows.
			for _, shot in ipairs({ rifleShot, slugShot, buckShot }) do
				for _, pitchDeg in ipairs({ 0, 20, -20 }) do
					local pitch = math.rad(pitchDeg)
					local aim = Vector3.new(0, math.sin(pitch), -math.cos(pitch)).Unit
					local zeroStuds = (shot :: any).zeroStuds
					local target = aim * zeroStuds
					local position, velocity =
						Vector3.zero, Ballistics.launchDirection(aim, shot :: any) * (shot :: any).v0
					local dt = 1 / 2000
					local miss: number? = nil
					for _ = 1, 40000 do
						local nextPosition, nextVelocity = Ballistics.advance(position, velocity, dt, shot :: any)
						local along, alongNext = position:Dot(aim), nextPosition:Dot(aim)
						if alongNext >= zeroStuds then
							local span = alongNext - along
							local fraction = if span > 1e-9 then (zeroStuds - along) / span else 0
							miss = ((position + (nextPosition - position) * fraction) - target).Magnitude
							break
						end
						position, velocity = nextPosition, nextVelocity
					end
					expect(miss).to.be.ok()
					expect((miss :: number) < 0.05).to.equal(true)
				end
			end
		end)
	end)

	describe("the stepper agrees with the closed form", function()
		it("reaches each ammo's range cap within 1% of timeToRange", function()
			local caps = {
				{ shot = rifleShot, range = 800 },
				{ shot = slugShot, range = 330 },
				{ shot = buckShot, range = 100 },
			}
			for _, case in ipairs(caps) do
				local shot = case.shot :: any
				local aim = Vector3.new(0, 0, -1)
				local position, velocity = Vector3.zero, Ballistics.launchDirection(aim, shot) * shot.v0
				local travelled, elapsed = 0, 0
				local dt = 1 / 2000
				-- INTERPOLATED, not overshot. Stopping on the first step PAST the range adds up to a
				-- whole step of time -- 1.14% of the rifle's 0.365 s at the dt the first version of
				-- this case used, which failed a 1% bound on the quantisation alone and said nothing
				-- about the integrator. The remainder is credited at this step's own speed.
				for _ = 1, 40000 do
					local nextPosition, nextVelocity = Ballistics.advance(position, velocity, dt, shot)
					local length = (nextPosition - position).Magnitude
					if travelled + length >= case.range then
						local fraction = if length > 1e-9 then (case.range - travelled) / length else 0
						elapsed += dt * fraction
						travelled = case.range
						break
					end
					travelled += length
					elapsed += dt
					position, velocity = nextPosition, nextVelocity
				end
				expect(travelled).to.equal(case.range)
				local closed = Ballistics.timeToRange(shot, case.range)
				expect(math.abs(elapsed - closed) / closed < 0.01).to.equal(true)
			end
		end)

		it("allocates no table: advance returns two values", function()
			local position, velocity = Ballistics.advance(Vector3.zero, Vector3.new(0, 0, -1), 1 / 60, rifleShot :: any)
			expect(typeof(position)).to.equal("Vector3")
			expect(typeof(velocity)).to.equal("Vector3")
		end)
	end)
end
