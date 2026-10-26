-- weapon_hits.spec: target resolution, pellet grouping, THE SHOT IN THE AIR, and the ignore list,
-- with an INJECTED cast so the casts can be counted and their arguments inspected; plus Cast.world
-- against two real parts, which is the only part of this system that needs a world.
--
-- SINCE TASK 185 THE SHOT IS A PROJECTILE, not a hitscan ray, and the central case here is the
-- feature itself: a target that MOVES is judged where it is when the bullet arrives, so aiming AT a
-- crossing boar misses and aiming AHEAD by `v*t` hits. It is provable with no world because `dt` is
-- a parameter of `Flight:advance`, so a stub cast's answer can depend on the step's own time.
-- The ignore-list assertions are defect (a) of the Task 23 review: the seam had no shooter, so
-- "filter out the shooter's character" could not be implemented at all.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/shotgun.md (sections 5.3, 5.5, 13.1), docs/design/ballistics.md (11.2)
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local TestKit = require(game:GetService("ReplicatedStorage"):WaitForChild("TestKit"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
local Ballistics = require(game:GetService("ReplicatedStorage"):WaitForChild("Ballistics"))
-- THE ONE METRE/STUD CONVERSION (task 189): read, never copied -- the rule `Ballistics` itself
-- states. A second 0.28 in this file would be a second answer to how far 100 m is.
local Report = require(game:GetService("ReplicatedStorage"):WaitForChild("Report"))
local Weapons = require(game:GetService("ReplicatedStorage"):WaitForChild("Weapons"))
-- THE SHIPPED FLIGHT CONFIG (task 256): the lag-compensation block below reads its CAP and its PING
-- FACTOR off this rather than copying them, because those two rows are what its cases claim things
-- about.
local Shotgun = require(game:GetService("ReplicatedStorage"):WaitForChild("Shotgun"))

local Hits = Weapon.Hits
local Cast = Weapon.Cast
local Flight = Weapon.Flight

-- A boar at a sprint: `Boar.CONFIG.SPRINT_SPEED`, which `boar_behaviour.spec` is what pins. A local
-- rather than a server require, because this spec must stay drivable with no animal in the world.
local BOAR_SPRINT_STUDS = 38

return function()
	describe("target resolution", function()
		local folder

		beforeEach(function()
			folder = Instance.new("Folder")
			folder.Name = "WeaponHitsSpec"
			folder.Parent = Workspace
		end)

		afterEach(function()
			folder:Destroy()
		end)

		it("finds a damageable part and reads its zone", function()
			local part = Instance.new("Part")
			part:SetAttribute("Damageable", true)
			part:SetAttribute("HitZone", "body")
			part.Parent = folder
			local target, zone = Hits.targetOf(part)
			expect(target).to.equal(part)
			expect(zone).to.equal("body")
		end)

		it("walks up to the damageable ancestor and falls back through the zones", function()
			local model = Instance.new("Model")
			model:SetAttribute("Damageable", true)
			model:SetAttribute("HitZone", "body")
			model.Parent = folder
			local head = Instance.new("Part")
			head:SetAttribute("HitZone", "head")
			head.Parent = model
			local plain = Instance.new("Part")
			plain.Parent = model

			local target, zone = Hits.targetOf(head)
			expect(target).to.equal(model)
			expect(zone).to.equal("head")

			local _, fallback = Hits.targetOf(plain)
			expect(fallback).to.equal("body") -- the root's zone

			model:SetAttribute("HitZone", nil)
			local _, unknown = Hits.targetOf(plain)
			expect(unknown).to.equal("unknown")
		end)

		it("returns nothing for scenery, so a pellet into a wall is a miss", function()
			local wall = Instance.new("Part")
			wall.Parent = folder
			expect(Hits.targetOf(wall)).to.equal(nil)
			expect(Hits.targetOf(nil)).to.equal(nil)
		end)
	end)

	-- ------------------------------------------------------------------ THE FLIGHT (task 185)
	--
	-- `Hits.resolve` used to stand here: one cast per pellet, the whole range, in the trigger's own
	-- frame (archived, `backups/2026-10-14_task-185_hitscan-Hits-resolve.md`). A boar sprinting at
	-- `SPRINT_SPEED` 38 studs/s was therefore hit wherever the reticle sat, and aiming ahead could
	-- only miss. Karen, 2026-10-14: *"when I shoot in running animal I need to aim a bit in front
	-- based on speed distance ect I wan to have that feeling"*.
	--
	-- Every case below drives `Flight.new(config)` with a HAND-WRITTEN config and a SCRIPTED cast:
	-- no Studio, no Heartbeat, no boar, no player. It is only possible because `dt` is a parameter
	-- of `Flight:advance` -- so the stub's answer can depend on the step's own simulated time, which
	-- is exactly what "judged where it IS when the bullet arrives" means.
	describe("the shot in the air", function()
		local CONFIG = {
			FLIGHT_STEP_MAX_SECONDS = 1 / 30,
			FLIGHT_MAX_SUBSTEPS = 8,
			FLIGHT_MAX_SECONDS = 2.0,
			FLIGHT_MAX_LIVE_PELLETS = 512,
		}

		local function configWith(overrides)
			local merged = table.clone(CONFIG)
			for key, value in pairs(overrides) do
				merged[key] = value
			end
			return merged
		end

		-- A shot record, with the one field every case needs and nothing it does not.
		local function record(overrides)
			local shot = {
				shooter = nil :: any,
				shooterUserId = 1,
				weapon = "rifle",
				ammo = "Slug",
				muzzle = Vector3.zero,
				ignore = {},
				rangeStuds = 800,
				firedAt = 0,
				epoch = 1,
			}
			for key, value in pairs(overrides or {}) do
				shot[key] = value
			end
			return shot
		end

		local function neverHits()
			return nil
		end

		local function nineAt(direction: Vector3)
			local directions = {}
			for _ = 1, 9 do
				directions[#directions + 1] = direction
			end
			return directions
		end

		-- Drain a flight: step it until nothing is left, collecting every resolution.
		local function drain(flight, cast, dt, limit)
			local all = {}
			for _ = 1, limit or 600 do
				for _, res in ipairs(flight:advance(dt, cast)) do
					table.insert(all, res)
				end
				if flight:count() == 0 then
					break
				end
			end
			return all
		end

		it("THE CORE CLAIM: a boar that moves is judged where it IS when the bullet arrives", function()
			-- The boar crosses the shot's path `distance` studs down +X, running along +Z at a
			-- sprint, and it is at Z = 0 at the trigger. The stub advances it by the step's own `dt`,
			-- so it is at `38 * elapsed` when a segment reaches it -- and answers a hit only when
			-- that segment passes within one stud of where it is AT THAT MOMENT.
			local shot = Ballistics.shotFor(Weapons.ROWS.rifle, "Slug") :: any
			local dt = 1 / 60

			local function crossingBoar(distance)
				local boar = Instance.new("Part")
				boar:SetAttribute("Damageable", true)
				boar:SetAttribute("HitZone", "body")
				local elapsed = 0
				local function cast(origin: Vector3, direction: Vector3)
					local centre = Vector3.new(distance, 0, BOAR_SPRINT_STUDS * elapsed)
					local length = direction.Magnitude
					if length < 1e-9 then
						return nil
					end
					local unit = direction / length
					local along = math.clamp((centre - origin):Dot(unit), 0, length)
					local closest = origin + unit * along
					if (closest - centre).Magnitude <= 1 then
						return { instance = boar, position = closest, normal = Vector3.yAxis, distance = along }
					end
					return nil
				end
				local function tick()
					elapsed += dt
				end
				return boar, cast, tick
			end

			-- THE RECORD SAYS WHICH GUN IT IS (task 189, the Reviewer's note). It used to fly the
			-- shotgun's slug under `weapon = "rifle"` with a `rangeStuds` of 410 against that slug's
			-- own 330: the lead claim did not depend on either, but a record that lies about itself
			-- is the kind of thing a later case reads and believes.
			local function fireAt(aim: Vector3, cast, tick, flown, id)
				local flight = Flight.new(CONFIG)
				-- ...AND IT FLIES TO THAT GUN'S OWN RANGE, which is what the real one does. The test
				-- distances are inside it, so nothing expires on the way to the animal.
				local reach = Weapons.ROWS[id].RANGE_STUDS.Slug
				flight:launch(
					record({ weapon = id, ammo = "Slug", rangeStuds = reach }),
					{ Ballistics.launchDirection(aim, flown) },
					flown
				)
				local impacts = {}
				for _ = 1, 400 do
					tick()
					for _, res in ipairs(flight:advance(dt, cast)) do
						for _, impact in ipairs(res.impacts) do
							table.insert(impacts, impact)
						end
					end
					if flight:count() == 0 then
						break
					end
				end
				return impacts
			end

			-- BOTH GUNS, AND THAT IS KAREN'S *"same with s/s"* (task 185) still answered after task
			-- 189 flattened the rifle's arc: flattening touches gravity and the lead is made of
			-- TIME, so it is this case -- the one that fires the real stepper at a moving target --
			-- that says the lead still works. The slug's distances are its own: `RANGE_STUDS` is 330.
			for _, pair in ipairs({
				{ id = "rifle", shot = shot, ranges = { 179, 357, 714 } },
				{
					id = "shotgun",
					shot = Ballistics.shotFor(Weapons.ROWS.shotgun, "Slug") :: any,
					-- INSIDE the slug's own 330-stud range, not at it: a pellet that expires in the
					-- same step it arrives would make this case about the range cap.
					ranges = { 100, 179, 300 },
				},
			}) do
				for _, distance in ipairs(pair.ranges) do
					local flown = pair.shot
					local lead = Ballistics.leadStuds(flown, distance, BOAR_SPRINT_STUDS)
					expect(lead > 1).to.equal(true) -- or the case proves nothing

					-- AIMED AT THE BOAR'S POSITION AT THE TRIGGER: it has moved out of the path.
					local atBoar, atCast, atTick = crossingBoar(distance)
					local missed = fireAt(Vector3.new(distance, 0, 0).Unit, atCast, atTick, flown, pair.id)
					expect(#missed).to.equal(0)

					-- AIMED AHEAD BY v*t: it runs into the shot.
					local aheadBoar, aheadCast, aheadTick = crossingBoar(distance)
					local hit = fireAt(Vector3.new(distance, 0, lead).Unit, aheadCast, aheadTick, flown, pair.id)
					expect(#hit).to.equal(1)
					expect(Hits.targetOf(hit[1].instance)).to.equal(aheadBoar)

					TestKit.note(
						string.format(
							"[flight] %s at %d studs (%.0f m): aiming AT the boar missed; leading it %.1f studs hit",
							pair.id,
							distance,
							distance * 0.28,
							lead
						)
					)
					atBoar:Destroy()
					aheadBoar:Destroy()
				end
			end
		end)

		it("A STILL PLATE ON THE RETICLE: the hole is within 2 cm at 50, 100, 150 and 200 m", function()
			-- KAREN, 2026-10-15: *"seems a bit odd when stands it has to be acurat 100% 100m 150m"*.
			--
			-- THE PLATE IS THE MEASUREMENT (task 183's method, through the server's own flight).
			-- A vertical plate stands square across the shot at `distance`, its centre exactly on the
			-- sight line, and the cast answers where the stepped SEGMENT crosses that plane -- so
			-- what comes back is the hole, and the miss is the hole's height above the reticle's
			-- centre. Nothing here is the closed form: this is `Flight:advance` stepping
			-- `Ballistics.advance` behind the real cast seam, which is the path a player's shot takes.
			--
			-- BEFORE AND AFTER IN ONE RUN. The same plate is shot twice: once with the shipped shot
			-- and once with the same numbers at `gravityScale = 1`, which is what task 185 flew.
			local metresPerStud = Report.CONFIG.METRES_PER_STUD
			local TWO_CM = 0.02 / metresPerStud
			local shipped = Ballistics.shotFor(Weapons.ROWS.rifle, "Slug") :: any
			local before = { v0 = shipped.v0, k = shipped.k, zeroStuds = shipped.zeroStuds, gravityScale = 1 }

			local function plateAt(distance: number)
				local plate = Instance.new("Part")
				plate:SetAttribute("Damageable", true)
				plate:SetAttribute("HitZone", "body")
				-- The plate's plane is x = distance; the shot goes down +X from the origin.
				local function cast(origin: Vector3, direction: Vector3)
					local reach = direction.X
					if reach <= 1e-9 or origin.X >= distance then
						return nil
					end
					local fraction = (distance - origin.X) / reach
					if fraction > 1 then
						return nil -- this step does not reach the plate yet
					end
					local at = origin + direction * fraction
					return {
						instance = plate,
						position = at,
						normal = -Vector3.xAxis,
						distance = (at - origin).Magnitude,
					}
				end
				return plate, cast
			end

			local function holeAt(flown, distance: number): number?
				local plate, cast = plateAt(distance)
				local flight = Flight.new(CONFIG)
				local aim = Vector3.xAxis
				flight:launch(record({ rangeStuds = distance + 80 }), { Ballistics.launchDirection(aim, flown) }, flown)
				local height: number? = nil
				for _ = 1, 400 do
					for _, res in ipairs(flight:advance(1 / 240, cast)) do
						for _, impact in ipairs(res.impacts) do
							height = height or impact.position.Y
						end
					end
					if flight:count() == 0 or height ~= nil then
						break
					end
				end
				plate:Destroy()
				return height
			end

			for _, metres in ipairs({ 50, 100, 150, 200 }) do
				local distance = metres / metresPerStud
				local was, now = holeAt(before, distance), holeAt(shipped, distance)
				expect(was).to.be.ok()
				expect(now).to.be.ok()
				TestKit.note(
					string.format(
						"[flight] still plate at %d m (%.0f studs): was %+.1f cm high, now %+.1f cm (bar: 2 cm)",
						metres,
						distance,
						(was :: number) * metresPerStud * 100,
						(now :: number) * metresPerStud * 100
					)
				)
				expect(math.abs(now :: number) < TWO_CM).to.equal(true)
				if metres == 100 then
					-- The defect Karen felt, as an assertion: the old shot was outside the bar here.
					expect(math.abs(was :: number) > TWO_CM).to.equal(true)
				end
			end
		end)

		it("reports `distance` from the MUZZLE, not along the segment", function()
			local shot = Ballistics.shotFor(Weapons.ROWS.rifle, "Slug") :: any
			local boar = Instance.new("Part")
			boar:SetAttribute("Damageable", true)
			local rawDistances = {}
			local flight = Flight.new(CONFIG)
			flight:launch(record({}), { Vector3.new(0, 0, -1) }, shot)
			local resolved = drain(flight, function(origin: Vector3, direction: Vector3)
				-- Hit only once the projectile is past 300 studs, and report a SMALL distance --
				-- which is what a real segment cast does: `Distance` is along the segment.
				if origin.Magnitude < 300 then
					return nil
				end
				local along = math.min(2, direction.Magnitude)
				table.insert(rawDistances, along)
				return {
					instance = boar,
					position = origin + direction.Unit * along,
					normal = Vector3.yAxis,
					distance = along,
				}
			end, 1 / 60)
			expect(#resolved).to.equal(1)
			expect(#resolved[1].impacts).to.equal(1)
			-- THE RAW CAST SAID A COUPLE OF STUDS; THE DELIVERED IMPACT SAYS THE WHOLE PATH. That is
			-- the claim, and the two bounds are what make it one: the cast's own number is under 5
			-- studs, the delivered one is past 300. The window above 300 is ONE STEP WIDE, because the
			-- stub starts answering at the first segment whose origin is past 300 and a rifle step at
			-- dt = 1/60 is 43.5 studs -- a tighter bound would be measuring the step rate.
			expect(rawDistances[1] < 5).to.equal(true)
			local delivered = resolved[1].impacts[1].distance
			expect(delivered >= 300).to.equal(true)
			expect(delivered < 300 + 60).to.equal(true)
			local reports = Hits.group(nil :: any, resolved[1].impacts, "Slug", 0, "rifle")
			expect(#reports).to.equal(1)
			expect(reports[1].nearest).to.equal(delivered)
			boar:Destroy()
		end)

		it("casts the SEGMENT it just travelled, with the same ignore table every time", function()
			local shot = Ballistics.shotFor(Weapons.ROWS.shotgun, "Buck") :: any
			local ignore = { Instance.new("Model") }
			local seen, segments = {}, {}
			local previousEnd: Vector3? = nil
			local flight = Flight.new(CONFIG)
			flight:launch(record({ ammo = "Buck", rangeStuds = 100, ignore = ignore }), { Vector3.new(0, 0, -1) }, shot)
			drain(flight, function(origin: Vector3, direction: Vector3, given)
				table.insert(seen, given)
				table.insert(segments, direction.Magnitude)
				-- each cast starts where the previous one ended: the path is continuous
				if previousEnd then
					expect((origin - previousEnd).Magnitude < 1e-3).to.equal(true)
				end
				previousEnd = origin + direction
				return nil
			end, 1 / 60)
			expect(#seen > 2).to.equal(true)
			for _, given in ipairs(seen) do
				expect(given).to.equal(ignore) -- the same table, unmodified
				expect(#given).to.equal(1)
			end
			-- Each segment is one step of flight, never the whole range.
			for _, length in ipairs(segments) do
				expect(length < 100).to.equal(true)
			end
		end)

		it("still makes ONE report per (shot, target) with pellets = 9", function()
			local shot = Ballistics.shotFor(Weapons.ROWS.shotgun, "Buck") :: any
			local boar = Instance.new("Part")
			boar:SetAttribute("Damageable", true)
			boar:SetAttribute("HitZone", "body")
			local flight = Flight.new(CONFIG)
			flight:launch(record({ ammo = "Buck", rangeStuds = 100 }), nineAt(Vector3.new(0, 0, -1)), shot)
			local resolved = drain(flight, function(origin: Vector3, direction: Vector3)
				if origin.Magnitude < 30 then
					return nil
				end
				return {
					instance = boar,
					position = origin + direction,
					normal = Vector3.yAxis,
					distance = direction.Magnitude,
				}
			end, 1 / 60)
			expect(#resolved).to.equal(1)
			expect(#resolved[1].impacts).to.equal(9)
			local reports = Hits.group(nil :: any, resolved[1].impacts, "Buck", 7, "shotgun")
			expect(#reports).to.equal(1)
			expect(reports[1].pellets).to.equal(9)
			expect(reports[1].zone).to.equal("body")
			boar:Destroy()
		end)

		it("waits for the LAST pellet: one early hit and eight that run out of range", function()
			local shot = Ballistics.shotFor(Weapons.ROWS.shotgun, "Buck") :: any
			local boar = Instance.new("Part")
			boar:SetAttribute("Damageable", true)
			local directions = { Vector3.new(0, 0, -1) }
			for _ = 1, 8 do
				directions[#directions + 1] = Vector3.new(1, 0, 0)
			end
			local flight = Flight.new(CONFIG)
			flight:launch(record({ ammo = "Buck", rangeStuds = 100 }), directions, shot)
			-- The first pellet hits at once; the other eight must fly to the 100-stud cap.
			local first = flight:advance(1 / 60, function(origin: Vector3, direction: Vector3)
				if direction.Unit.Z > -0.5 then
					return nil -- the eight going +X meet nothing
				end
				return { instance = boar, position = origin, normal = Vector3.yAxis, distance = 0.5 }
			end)
			expect(#first).to.equal(0) -- NOT reported yet: eight are still in the air
			expect(flight:count()).to.equal(8)
			local rest = drain(flight, neverHits, 1 / 60)
			expect(#rest).to.equal(1)
			expect(#rest[1].impacts).to.equal(1)
			expect(flight:count()).to.equal(0)
			boar:Destroy()
		end)

		it("carries the SHOT's time into the report, not the arrival's", function()
			local shot = Ballistics.shotFor(Weapons.ROWS.rifle, "Slug") :: any
			local boar = Instance.new("Part")
			boar:SetAttribute("Damageable", true)
			local flight = Flight.new(CONFIG)
			flight:launch(record({ firedAt = 1000 }), { Vector3.new(0, 0, -1) }, shot)
			local resolved = drain(flight, function(origin: Vector3, direction: Vector3)
				return {
					instance = boar,
					position = origin + direction,
					normal = Vector3.yAxis,
					distance = direction.Magnitude,
				}
			end, 1 / 60)
			expect(#resolved).to.equal(1)
			expect(resolved[1].shot.firedAt).to.equal(1000)
			local reports = Hits.group(nil :: any, resolved[1].impacts, "Slug", resolved[1].shot.firedAt, "rifle")
			expect(reports[1].at).to.equal(1000)
			boar:Destroy()
		end)

		it("splits a long dt into capped sub-steps, and discards the rest past the cap", function()
			local shot = Ballistics.shotFor(Weapons.ROWS.rifle, "Slug") :: any
			-- 1/15 is two sub-steps at a 1/30 cap.
			local flight = Flight.new(CONFIG)
			flight:launch(record({}), { Vector3.new(0, 0, -1) }, shot)
			local before = flight.casts
			flight:advance(1 / 15, neverHits)
			expect(flight.casts - before).to.equal(2)

			-- 0.5 s would be 15 sub-steps; the cap is 8 and the remainder is DISCARDED, so the
			-- projectile advances 8/30 s of flight and not 0.5 s.
			-- ...AND THE RANGE MUST NOT BE WHAT ENDS IT, or the case counts the range cap instead of
			-- the sub-step cap: eight sub-steps of a rifle bullet is 600+ studs, which is most of its
			-- real 800. (The first version of this case used the default 800 and measured 6 casts.)
			local capped = Flight.new(CONFIG)
			capped:launch(record({ rangeStuds = 1e6 }), { Vector3.new(0, 0, -1) }, shot)
			local castsBefore = capped.casts
			local travelled = 0
			capped:advance(0.5, function(_origin: Vector3, direction: Vector3)
				travelled += direction.Magnitude
				return nil
			end)
			expect(capped.casts - castsBefore).to.equal(CONFIG.FLIGHT_MAX_SUBSTEPS)
			-- EIGHT STEPS OF 1/30 s, NOT EIGHT OF 1/16. The remainder of a `dt` past the cap is
			-- discarded, so the projectile advances 8/30 = 0.267 s of flight -- 610 studs by the
			-- closed form -- and not the 1300 studs a full half-second would carry it. This is the
			-- case that caught `step = dt / subs` taking 62.5 ms sub-steps past a 33 ms cap.
			expect(travelled > 550 and travelled < 700).to.equal(true)
		end)

		it("sags under 0.02 studs off the chord inside one capped step", function()
			-- THE CHORD-INSTEAD-OF-ARC ERROR THE CAP IS SIZED AGAINST (design section 5), and it is
			-- the PERPENDICULAR distance from the chord -- which is what "could this segment pass
			-- through something the arc would have hit" actually asks.
			--
			-- NOT the distance to the chord's midpoint: that is dominated by the drag ALONG the path
			-- (2927 studs/s^2 at the muzzle against gravity's 35), so the first version of this case
			-- measured 0.4 studs of deceleration and called it sag.
			local shot = Ballistics.shotFor(Weapons.ROWS.rifle, "Slug") :: any
			local dt = CONFIG.FLIGHT_STEP_MAX_SECONDS
			local position, velocity = Vector3.zero, Vector3.new(0, 0, -1) * shot.v0
			local wholeStep = select(1, Ballistics.advance(position, velocity, dt, shot))
			local halfStep = select(1, Ballistics.advance(position, velocity, dt / 2, shot))
			local chord = wholeStep - position
			local alongChord = chord.Unit * (halfStep - position):Dot(chord.Unit)
			local sag = ((halfStep - position) - alongChord).Magnitude
			TestKit.note(string.format("[flight] chord sag at a %.1f ms step: %.4f studs", dt * 1000, sag))
			expect(sag < 0.02).to.equal(true)
		end)

		it("retires a projectile exactly at its range cap, with no impact and nothing left over", function()
			local shot = Ballistics.shotFor(Weapons.ROWS.shotgun, "Buck") :: any
			local travelled = 0
			local flight = Flight.new(CONFIG)
			flight:launch(record({ ammo = "Buck", rangeStuds = 100 }), { Vector3.new(0, 0, -1) }, shot)
			local resolved = drain(flight, function(_origin: Vector3, direction: Vector3)
				travelled += direction.Magnitude
				return nil
			end, 1 / 60)
			expect(#resolved).to.equal(1)
			expect(#resolved[1].impacts).to.equal(0) -- a miss
			expect(math.abs(travelled - 100) < 1e-3).to.equal(true) -- EXACT, not "the first overshoot"
			expect(flight:count()).to.equal(0)
			expect(flight:shots()).to.equal(0)
		end)

		it("NOTHING LEAKS: the flight ceiling retires a projectile and counts it", function()
			local shot = Ballistics.shotFor(Weapons.ROWS.rifle, "Slug") :: any
			-- A tiny ceiling and a range it can never reach: only the ceiling can end this.
			local flight = Flight.new(configWith({ FLIGHT_MAX_SECONDS = 0.05 }))
			flight:launch(record({ rangeStuds = 1e6 }), { Vector3.new(0, 0, -1) }, shot)
			local resolved = drain(flight, neverHits, 1 / 60)
			expect(#resolved).to.equal(1)
			expect(#resolved[1].impacts).to.equal(0)
			expect(flight:count()).to.equal(0)
			expect(flight.timedOut).to.equal(1)
		end)

		it("refuses a shot past the live cap, and that refusal is a MISS and not a silence", function()
			local shot = Ballistics.shotFor(Weapons.ROWS.shotgun, "Buck") :: any
			local flight = Flight.new(configWith({ FLIGHT_MAX_LIVE_PELLETS = 2 }))
			expect(flight:launch(record({ ammo = "Buck", rangeStuds = 100 }), nineAt(Vector3.new(0, 0, -1)), shot)).to.equal(
				0
			)
			expect(flight.refused).to.equal(1)
			expect(flight:count()).to.equal(0)
			-- ...and the shot still RESOLVES, with no impacts, on the next step.
			local resolved = flight:advance(1 / 60, neverHits)
			expect(#resolved).to.equal(1)
			expect(#resolved[1].impacts).to.equal(0)
			expect(flight:shots()).to.equal(0)
		end)

		it("resolves a shot whose shooter has gone, and tells nobody", function()
			-- The bullet has left the gun (design 6.4): it still flies and still hits. Only the
			-- marker is dropped, and `Weapon.markHit` is what drops it.
			local shot = Ballistics.shotFor(Weapons.ROWS.rifle, "Slug") :: any
			local gone = Instance.new("Folder") -- a parentless stand-in: not a Player at all
			local boar = Instance.new("Part")
			boar:SetAttribute("Damageable", true)
			local flight = Flight.new(CONFIG)
			flight:launch(record({ shooter = gone :: any }), { Vector3.new(0, 0, -1) }, shot)
			local resolved = drain(flight, function(origin: Vector3, direction: Vector3)
				return {
					instance = boar,
					position = origin + direction,
					normal = Vector3.yAxis,
					distance = direction.Magnitude,
				}
			end, 1 / 60)
			expect(#resolved).to.equal(1)
			local reports = Hits.group(gone :: any, resolved[1].impacts, "Slug", 0, "rifle")
			expect(#reports).to.equal(1)
			local before = Weapon.stats().markers
			Weapon.markHit(gone :: any, "hit", reports[1].zone)
			expect(Weapon.stats().markers).to.equal(before)
			boar:Destroy()
		end)

		it("costs under 1.0 ms per step at the worst burst the game can make (288 projectiles)", function()
			-- 16 shooters firing both barrels of buckshot inside one flight time (design section 10).
			local shot = Ballistics.shotFor(Weapons.ROWS.shotgun, "Buck") :: any
			local flight = Flight.new(CONFIG)
			for _ = 1, 32 do
				flight:launch(record({ ammo = "Buck", rangeStuds = 1e6 }), nineAt(Vector3.new(0, 0, -1)), shot)
			end
			expect(flight:count()).to.equal(288)
			local frames = 60
			local started = os.clock()
			for _ = 1, frames do
				flight:advance(1 / 60, neverHits)
			end
			local perStepMs = (os.clock() - started) / frames * 1000
			TestKit.note(string.format("[flight] 288 projectiles: %.3f ms per step", perStepMs))
			expect(perStepMs < 1.0).to.equal(true)
		end)
	end)

	-- ---------------------------------------------------------------- LAG COMPENSATION (task 256)
	--
	-- KAREN, 2026-10-24: *"we need to aim ahead to hit animal when running"* / *"it seems there is a
	-- bit off"*. Until this task the lead the game demanded was the TRUE lead PLUS the round trip to
	-- the server, because the player aims at the animal his client drew one trip ago and the server
	-- resolves the shot against where it is one trip later.
	-- Research note: docs/research/2026-10-24-real-shooting.md section 5.
	describe("lag compensation", function()
		-- THE STEPPING NUMBERS ARE LOCAL, exactly as the flight block above keeps them: a spec that
		-- drives a stepper wants a step size it chose. THE TWO TASK-256 ROWS ARE READ OFF THE SHIPPED
		-- TABLE, deliberately and unlike them -- the cap and the ping factor are the things these
		-- cases make claims ABOUT, so a hand-copy here would let the game's own cap move while this
		-- file went on passing against the old one.
		local CONFIG = {
			FLIGHT_STEP_MAX_SECONDS = 1 / 30,
			FLIGHT_MAX_SUBSTEPS = 8,
			FLIGHT_MAX_SECONDS = 2.0,
			FLIGHT_MAX_LIVE_PELLETS = 512,
			FLIGHT_CATCHUP_MAX_SECONDS = Shotgun.CONFIG.FLIGHT_CATCHUP_MAX_SECONDS,
			FLIGHT_CATCHUP_PING_FACTOR = Shotgun.CONFIG.FLIGHT_CATCHUP_PING_FACTOR,
		}

		local function configWith(overrides)
			local merged = table.clone(CONFIG)
			for key, value in pairs(overrides) do
				merged[key] = value
			end
			return merged
		end

		local function record(overrides)
			local shot = {
				shooter = nil :: any,
				shooterUserId = 1,
				weapon = "rifle",
				ammo = "Slug",
				muzzle = Vector3.zero,
				ignore = {},
				rangeStuds = 800,
				firedAt = 0,
				epoch = 1,
			}
			for key, value in pairs(overrides or {}) do
				shot[key] = value
			end
			return shot
		end

		local function neverHits()
			return nil
		end

		-- The same crossing boar the core flight claim uses, and for the same reason: a stub whose
		-- answer depends on the step's own elapsed time is what makes "judged where it IS when the
		-- bullet arrives" assertable with no world.
		local DT = 1 / 60
		local function crossingBoar(distance: number)
			local boar = Instance.new("Part")
			boar:SetAttribute("Damageable", true)
			boar:SetAttribute("HitZone", "body")
			local elapsed = 0
			local function cast(origin: Vector3, direction: Vector3)
				local centre = Vector3.new(distance, 0, BOAR_SPRINT_STUDS * elapsed)
				local length = direction.Magnitude
				if length < 1e-9 then
					return nil
				end
				local unit = direction / length
				local along = math.clamp((centre - origin):Dot(unit), 0, length)
				local closest = origin + unit * along
				if (closest - centre).Magnitude <= 1 then
					return { instance = boar, position = closest, normal = Vector3.yAxis, distance = along }
				end
				return nil
			end
			-- THE WORLD MOVES ON THE FRAME, NOT ON THE SUB-STEP, and that is what makes the catch-up
			-- a real reach forward through a world that is holding still -- which is exactly what it
			-- is on the server, where `Boar.Body` moves on Heartbeat and a shot spends its whole
			-- catch-up inside one of them.
			local function tick()
				elapsed += DT
			end
			return boar, cast, tick
		end

		local function fireAt(aim: Vector3, cast, tick, flown, catchUp: number?)
			local flight = Flight.new(CONFIG)
			flight:launch(
				record({ rangeStuds = Weapons.ROWS.rifle.RANGE_STUDS.Slug }),
				{ Ballistics.launchDirection(aim, flown) },
				flown,
				catchUp
			)
			local impacts = {}
			for _ = 1, 400 do
				tick()
				for _, res in ipairs(flight:advance(DT, cast)) do
					for _, impact in ipairs(res.impacts) do
						table.insert(impacts, impact)
					end
				end
				if flight:count() == 0 then
					break
				end
			end
			return impacts, flight
		end

		it("THE CORE CLAIM: with the catch-up, the TRUE lead hits a boar it otherwise misses", function()
			-- THE MODEL IS THE RESEARCH NOTE'S SECTION 5.1, EXACTLY. Server time 0 is the trigger and
			-- the boar is at Z = 0 there, running +Z at a sprint and crossing the shot's path
			-- `distance` studs down +X.
			--
			-- The player's click was MADE at server time -L and the picture he aimed at showed the
			-- boar as it was at -2L. So he put his reticle at `v*(-2L) + lead` -- the TRUE lead, taken
			-- off the only position he could SEE. The bullet reaches that point at `tof`, by which
			-- time the boar is at `v*tof = lead`: it is `2*v*L` PAST the aim point, so the shot goes
			-- BEHIND it. With a catch-up of `2L` the bullet reaches the aim point at `tof - 2L`, when
			-- the boar is at `lead - 2*v*L` -- which IS the aim point. That is the whole feature.
			local oneWay = 0.05 -- 50 ms, an ordinary connection
			local roundTrip = 2 * oneWay
			expect(roundTrip <= CONFIG.FLIGHT_CATCHUP_MAX_SECONDS).to.equal(true)

			local flown = Ballistics.shotFor(Weapons.ROWS.rifle, "Slug") :: any
			-- THESE THREE RANGES ARE THE ONES WHERE THE CLAIM IS A HIT, and the reason is the next
			-- case: forward prediction can only give back time the bullet actually spends in the
			-- air, so the compensation is exact only where the FLIGHT is longer than the round trip.
			-- 357 studs is 148 ms against this case's 100 ms; 179 studs is 71 ms and is the limit
			-- case below, not a failure of the feature.
			for _, distance in ipairs({ 357, 536, 714 }) do
				local lead = Ballistics.leadStuds(flown, distance, BOAR_SPRINT_STUDS)
				expect(Ballistics.timeToRange(flown, distance) > roundTrip).to.equal(true)
				local pingStuds = BOAR_SPRINT_STUDS * roundTrip
				-- OR THE CASE PROVES NOTHING: the ping's own error has to be bigger than the stub's
				-- one-stud hit radius, or an uncompensated shot would land anyway.
				expect(pingStuds > 1).to.equal(true)
				local aim = Vector3.new(distance, 0, lead - pingStuds).Unit

				-- UNCOMPENSATED: the true lead is not enough, and the shot passes behind the animal.
				local missBoar, missCast, missTick = crossingBoar(distance)
				local missed = fireAt(aim, missCast, missTick, flown, 0)
				expect(#missed).to.equal(0)

				-- COMPENSATED by the round trip: the same aim, the same animal, and it connects.
				local hitBoar, hitCast, hitTick = crossingBoar(distance)
				local hit = fireAt(aim, hitCast, hitTick, flown, roundTrip)
				expect(#hit).to.equal(1)
				expect(Hits.targetOf(hit[1].instance)).to.equal(hitBoar)

				TestKit.note(
					string.format(
						"[catchup] rifle at %d studs (%.0f m): true lead %.1f st; %.0f ms round trip costs "
							.. "%.1f st, so the true lead MISSED; with the catch-up it HIT",
						distance,
						distance * Report.CONFIG.METRES_PER_STUD,
						lead,
						roundTrip * 1000,
						pingStuds
					)
				)
				missBoar:Destroy()
				hitBoar:Destroy()
			end
		end)

		it("CANNOT GIVE BACK MORE PING THAN THE BULLET SPENDS IN THE AIR, and that is stated", function()
			-- THE HONEST LIMIT OF FORWARD PREDICTION (research note section 5.5). At 179 studs the
			-- rifle's whole flight is 71 ms and this case's round trip is 100 ms, so the bullet
			-- reaches the animal's distance BEFORE the world has caught up with the picture the
			-- player aimed at -- there is no more flight left to spend. The catch-up still helps, and
			-- it cannot close the gap completely.
			--
			-- IT IS A CASE RATHER THAN A COMMENT because the degradation has to be a number somebody
			-- can read: without it, "the lead is the true lead" would be a claim this suite makes at
			-- every range, and at close range with a fast bullet it is not true.
			local oneWay = 0.05
			local roundTrip = 2 * oneWay
			local flown = Ballistics.shotFor(Weapons.ROWS.rifle, "Slug") :: any
			local distance = 179 -- 50 m
			expect(Ballistics.timeToRange(flown, distance) < roundTrip).to.equal(true)

			local lead = Ballistics.leadStuds(flown, distance, BOAR_SPRINT_STUDS)
			local pingStuds = BOAR_SPRINT_STUDS * roundTrip
			local aim = Vector3.new(distance, 0, lead - pingStuds).Unit

			-- HOW CLOSE THE SHOT GOT, instead of whether it hit: the cast NEVER answers a hit, so the
			-- projectile flies its whole path and the minimum distance to the animal is the measure.
			local function closestApproach(catchUp: number)
				local flight = Flight.new(CONFIG)
				flight:launch(
					record({ rangeStuds = Weapons.ROWS.rifle.RANGE_STUDS.Slug }),
					{ Ballistics.launchDirection(aim, flown) },
					flown,
					catchUp
				)
				local elapsed = 0
				local best = math.huge
				for _ = 1, 400 do
					elapsed += DT
					flight:advance(DT, function(origin: Vector3, direction: Vector3)
						local centre = Vector3.new(distance, 0, BOAR_SPRINT_STUDS * elapsed)
						local length = direction.Magnitude
						if length > 1e-9 then
							local unit = direction / length
							local along = math.clamp((centre - origin):Dot(unit), 0, length)
							best = math.min(best, ((origin + unit * along) - centre).Magnitude)
						end
						return nil
					end)
					if flight:count() == 0 then
						break
					end
				end
				return best
			end

			local without = closestApproach(0)
			local with = closestApproach(roundTrip)
			-- IT HELPS: the shot comes materially closer.
			expect(with < without).to.equal(true)
			-- AND IT IS STILL A MISS, which is the limit being stated rather than hidden.
			expect(with > 1).to.equal(true)
			TestKit.note(
				string.format(
					"[catchup] LIMIT at %d studs (%.0f m): flight %.0f ms is SHORTER than the %.0f ms round "
						.. "trip, so the catch-up cuts the miss from %.2f to %.2f studs and cannot clear it",
					distance,
					distance * Report.CONFIG.METRES_PER_STUD,
					Ballistics.timeToRange(flown, distance) * 1000,
					roundTrip * 1000,
					without,
					with
				)
			)
		end)

		it("ZERO IS BIT-FOR-BIT TODAY'S FLIGHT: same casts, same segments, same end state", function()
			-- The feature's failure mode has to be "the game shoots as it did yesterday", so a shot
			-- that owes nothing must take EXACTLY the path it took before this task existed. Both
			-- the nil caller (every call site written before task 256) and an explicit 0.
			local flown = Ballistics.shotFor(Weapons.ROWS.rifle, "Slug") :: any
			local function trace(catchUp: number?)
				local flight = Flight.new(CONFIG)
				flight:launch(record({}), { Vector3.new(0, 0, -1) }, flown, catchUp)
				local segments = {}
				for _ = 1, 30 do
					flight:advance(DT, function(origin: Vector3, direction: Vector3)
						table.insert(segments, { origin = origin, direction = direction })
						return nil
					end)
				end
				return segments, flight
			end
			local baseline, baseFlight = trace(nil)
			local zeroed, zeroFlight = trace(0)
			expect(#zeroed).to.equal(#baseline)
			expect(#baseline > 0).to.equal(true)
			for index, step in ipairs(baseline) do
				expect((zeroed[index].origin - step.origin).Magnitude < 1e-9).to.equal(true)
				expect((zeroed[index].direction - step.direction).Magnitude < 1e-9).to.equal(true)
			end
			expect(zeroFlight.catchUpSeconds).to.equal(0)
			expect(baseFlight.catchUpSeconds).to.equal(0)
		end)

		it("IS SPENT ONCE, however many frames the shot lives for", function()
			-- A catch-up re-applied every Heartbeat would accelerate a bullet without bound. The
			-- FIRST advance takes `dt + catchUp` and every one after it takes `dt`, which is
			-- measurable as the cast count: the first frame casts more segments than the second.
			local flown = Ballistics.shotFor(Weapons.ROWS.rifle, "Slug") :: any
			local flight = Flight.new(CONFIG)
			flight:launch(record({ rangeStuds = 1e6 }), { Vector3.new(0, 0, -1) }, flown, 0.1)
			local before = flight.casts
			flight:advance(DT, neverHits)
			local first = flight.casts - before
			flight:advance(DT, neverHits)
			local second = flight.casts - before - first
			-- 0.1 + 1/60 is 0.1167 s, which is 4 sub-steps of the 1/30 cap; a bare 1/60 is 1.
			expect(first).to.equal(4)
			expect(second).to.equal(1)
			TestKit.note(string.format("[catchup] spent once: first frame %d casts, second %d", first, second))
		end)

		it("IS CLAMPED AT THE CAP, and a negative or a NaN is zero", function()
			local flown = Ballistics.shotFor(Weapons.ROWS.rifle, "Slug") :: any
			local function granted(catchUp: number?)
				local flight = Flight.new(CONFIG)
				flight:launch(record({ rangeStuds = 1e6 }), { Vector3.new(0, 0, -1) }, flown, catchUp)
				return flight.catchUpSeconds
			end
			expect(granted(0.05)).to.equal(0.05)
			-- A WILD VALUE CANNOT BUY A BODY LENGTH OF FREE LEAD: the one door into the module clamps.
			expect(granted(10)).to.equal(CONFIG.FLIGHT_CATCHUP_MAX_SECONDS)
			expect(granted(-1)).to.equal(0)
			expect(granted(0 / 0)).to.equal(0)
			expect(granted(nil)).to.equal(0)
		end)

		it("A SHOT THE GLOBAL CAP REFUSED IS GRANTED NOTHING", function()
			-- It has no projectiles to advance and resolves as a MISS, so crediting it would put a
			-- number in `catchUpSeconds` that bought nothing.
			local flown = Ballistics.shotFor(Weapons.ROWS.shotgun, "Buck") :: any
			local flight = Flight.new(configWith({ FLIGHT_MAX_LIVE_PELLETS = 0 }))
			local launched = flight:launch(record({ ammo = "Buck" }), { Vector3.new(0, 0, -1) }, flown, 0.1)
			expect(launched).to.equal(0)
			expect(flight.refused).to.equal(1)
			expect(flight.catchUpSeconds).to.equal(0)
		end)

		it("CANNOT TUNNEL: a wall between the muzzle and the animal still stops the caught-up shot", function()
			-- The catch-up is the simulation run for longer, NOT a teleport, and this is the case that
			-- says so: the cap splits it into sub-steps and each one casts its own segment, so the
			-- first solid thing on the path is still what is hit.
			local flown = Ballistics.shotFor(Weapons.ROWS.rifle, "Slug") :: any
			local wall = Instance.new("Part")
			local flight = Flight.new(CONFIG)
			flight:launch(record({}), { Vector3.new(0, 0, -1) }, flown, CONFIG.FLIGHT_CATCHUP_MAX_SECONDS)
			local impacts = {}
			for _ = 1, 10 do
				for _, res in
					ipairs(flight:advance(DT, function(origin: Vector3, direction: Vector3)
						-- A wall 10 studs out, across the whole path.
						local length = direction.Magnitude
						local startZ, endZ = origin.Z, origin.Z + direction.Z
						if startZ >= -10 and endZ <= -10 and length > 1e-9 then
							return {
								instance = wall,
								position = Vector3.new(0, 0, -10),
								normal = Vector3.zAxis,
								distance = math.abs(-10 - startZ),
							}
						end
						return nil
					end))
				do
					for _, impact in ipairs(res.impacts) do
						table.insert(impacts, impact)
					end
				end
			end
			expect(#impacts).to.equal(1)
			expect(impacts[1].instance).to.equal(wall)
			expect(flight:count()).to.equal(0)
			wall:Destroy()
		end)

		it("Flight.substeps never exceeds the cap and is the vacuum limit at 0", function()
			local subs, step = Flight.substeps(0, CONFIG)
			expect(subs).to.equal(1)
			expect(step).to.equal(0)
			subs, step = Flight.substeps(1 / 15, CONFIG)
			expect(subs).to.equal(2)
			expect(step <= CONFIG.FLIGHT_STEP_MAX_SECONDS + 1e-12).to.equal(true)
			-- Past the cap the step stays AT the cap and the remainder is discarded.
			subs, step = Flight.substeps(0.5, CONFIG)
			expect(subs).to.equal(CONFIG.FLIGHT_MAX_SUBSTEPS)
			expect(math.abs(step - CONFIG.FLIGHT_STEP_MAX_SECONDS) < 1e-12).to.equal(true)
		end)

		it("Weapon.catchUpFor converts a ping, clamps it, and refuses a bad one", function()
			-- PURE with `ping` supplied, which is the only way this is reachable on this PC at all: a
			-- Studio Play session has no network and `GetNetworkPing` reads ~0 (research note 5.4).
			expect(Weapon.catchUpFor(nil, 0.05, CONFIG)).to.equal(0.05 * CONFIG.FLIGHT_CATCHUP_PING_FACTOR)
			expect(Weapon.catchUpFor(nil, 0, CONFIG)).to.equal(0)
			expect(Weapon.catchUpFor(nil, -0.2, CONFIG)).to.equal(0)
			expect(Weapon.catchUpFor(nil, 0 / 0, CONFIG)).to.equal(0)
			expect(Weapon.catchUpFor(nil, 10, CONFIG)).to.equal(CONFIG.FLIGHT_CATCHUP_MAX_SECONDS)
			-- THE FACTOR IS A DIAL AND BOTH READINGS ARE REACHABLE (the row's own reason for being a
			-- row): the engine's docs do not say whether its number is the round trip or one way.
			local doubled = configWith({ FLIGHT_CATCHUP_PING_FACTOR = 2.0, FLIGHT_CATCHUP_MAX_SECONDS = 1.0 })
			expect(Weapon.catchUpFor(nil, 0.05, doubled)).to.equal(0.1)
			-- A PLAYER WHO CANNOT BE ASKED IS GIVEN NOTHING, never a guessed default.
			expect(Weapon.catchUpFor(nil, nil, CONFIG)).to.equal(0)
		end)
	end)

	describe("the one cast seam in the system", function()
		it("kept Cast as the one wrapper and lost the hitscan resolver", function()
			-- A source-shape claim, in the shape `rifle.spec` already uses: the module table is the
			-- evidence, and the grep itself is the Reviewer's (design section 13 items 1 and 9).
			expect(type(Weapon.Cast.world)).to.equal("function")
			expect((Hits :: any).resolve).to.equal(nil) -- archived in task 185
			expect(type(Weapon.Flight.new)).to.equal("function")
			expect(type(Weapon.Ballistics.advance)).to.equal("function")
		end)
	end)

	describe("hit grouping", function()
		local function impactOn(instance, distance, position)
			return {
				instance = instance,
				position = position or Vector3.new(0, 0, distance),
				normal = Vector3.yAxis,
				distance = distance,
			}
		end

		it("makes one report per target, not one per pellet", function()
			local boar = Instance.new("Part")
			boar:SetAttribute("Damageable", true)
			boar:SetAttribute("HitZone", "body")
			local impacts = {}
			for index = 1, 9 do
				impacts[index] = impactOn(boar, 10 + index)
			end
			local reports = Hits.group(nil :: any, impacts, "Buck", 5)
			expect(#reports).to.equal(1)
			expect(reports[1].pellets).to.equal(9)
			expect(reports[1].zone).to.equal("body")
			expect(reports[1].zones.body).to.equal(9)
			expect(reports[1].nearest).to.equal(11)
			expect(reports[1].ammo).to.equal("Buck")
			expect(reports[1].at).to.equal(5)
			boar:Destroy()
		end)

		it("splits pellets across two targets", function()
			local a, b = Instance.new("Part"), Instance.new("Part")
			a:SetAttribute("Damageable", true)
			b:SetAttribute("Damageable", true)
			local reports = Hits.group(nil :: any, {
				impactOn(a, 10),
				impactOn(b, 20),
				impactOn(a, 30),
			}, "Buck", 0)
			expect(#reports).to.equal(2)
			local total = reports[1].pellets + reports[2].pellets
			expect(total).to.equal(3)
			a:Destroy()
			b:Destroy()
		end)

		it("breaks a zone tie with the nearest impact", function()
			local model = Instance.new("Model")
			model:SetAttribute("Damageable", true)
			local head = Instance.new("Part")
			head:SetAttribute("HitZone", "head")
			head.Parent = model
			local body = Instance.new("Part")
			body:SetAttribute("HitZone", "body")
			body.Parent = model

			local reports = Hits.group(nil :: any, { impactOn(body, 20), impactOn(head, 10) }, "Slug", 0)
			expect(#reports).to.equal(1)
			expect(reports[1].zones.head).to.equal(1)
			expect(reports[1].zones.body).to.equal(1)
			expect(reports[1].zone).to.equal("head") -- the nearer one
			model:Destroy()
		end)
	end)

	describe("the real cast", function()
		local folder, target

		beforeEach(function()
			folder = Instance.new("Folder")
			folder.Name = "WeaponCastSpec"
			folder.Parent = Workspace
			target = Instance.new("Part")
			target.Name = "CastTarget"
			target.Size = Vector3.new(4, 4, 4)
			target.Position = Vector3.new(0, 500, 0)
			target.Anchored = true
			target.Parent = folder
		end)

		afterEach(function()
			folder:Destroy()
		end)

		it("hits a part in the ray's path at the arithmetic distance", function()
			local origin = Vector3.new(0, 500, 20)
			local impact = Cast.world(origin, Vector3.new(0, 0, -40), {})
			expect(impact).to.be.ok()
			expect(impact.instance).to.equal(target)
			expect(math.abs(impact.distance - 18) < 0.05).to.equal(true) -- 20 studs minus half of 4
		end)

		it("misses the same part when it is in the ignore list", function()
			local origin = Vector3.new(0, 500, 20)
			expect(Cast.world(origin, Vector3.new(0, 0, -40), { target })).to.equal(nil)
			expect(Cast.world(origin, Vector3.new(0, 0, -40), { folder })).to.equal(nil)
		end)
	end)

	-- Milestone 1.5, Director decision C: the shooter is told that something landed. The weapon owns
	-- the one-way remote and knows nothing about boars; the BOAR's runtime is what turns a hit into a
	-- kill, through BoarBoot. The drawing is the Hud's and is proved in tests/client/hit_marker.spec,
	-- which waits for the markers this test sends -- so the two halves of the wire are asserted on
	-- the two sides that actually own them.
	describe("the marker sent to the shooter", function()
		it("fires the one-way remote at a real player and counts it", function()
			local players = Players:GetPlayers()
			expect(#players > 0).to.equal(true) -- a Play session always has the local player
			local before = Weapon.stats().markers
			local names = {}
			for _, player in ipairs(players) do
				Weapon.markHit(player, "hit", "chest")
				Weapon.markHit(player, "kill", "head")
				table.insert(names, player.Name)
			end
			expect(Weapon.stats().markers).to.equal(before + 2 * #players)
			-- WHEN this ran is half of the evidence for tests/client/hit_marker.spec, which waits for
			-- these very markers: a driver receives no others, so "the wire is broken" and "the
			-- server had not got here yet" look identical from that side without this (Task 36).
			TestKit.note(string.format("weapon_hits: marked %s at %.1f s", table.concat(names, ", "), os.clock()))
		end)

		it("says nothing to a shooter who is not a Player", function()
			-- A player can leave between the cast and the report, and a spec can pass a stand-in.
			local before = Weapon.stats().markers
			Weapon.markHit(nil :: any, "hit")
			Weapon.markHit({ Name = "not a player" } :: any, "hit")
			expect(Weapon.stats().markers).to.equal(before)
		end)
	end)
	-- ------------------------------------------------------- THE CLAIM'S OWN FOUR CASES (task 266)
	--
	-- `docs/design/ballistics.md` §12.1 cases 26-29. They were DROPPED from round 2 and the Reviewer
	-- was right to block on it: without them, deleting `judgeClaimFor`'s accept branch or pinning
	-- `Flight`'s `live.reached` at 0 left the WHOLE SUITE GREEN with the feature silently off --
	-- which is the failure task 260 round 3 proved the hard way and which this file's own neighbours
	-- quote.
	--
	-- Pure, no world: `Flight` is driven with a scripted cast and an injected `dt` exactly as every
	-- case above it is, and `Validator.claimImpact` is a pure function of three facts.
	describe("the hit claim's own facts", function()
		local CONFIG = {
			FLIGHT_STEP_MAX_SECONDS = 1 / 30,
			FLIGHT_MAX_SUBSTEPS = 8,
			FLIGHT_MAX_SECONDS = 2.0,
			FLIGHT_MAX_LIVE_PELLETS = 512,
		}
		-- This block's own `drain`: the one above is a local of the neighbouring describe.
		local function drain(flight, cast, dt, limit)
			local all = {}
			for _ = 1, limit or 600 do
				for _, res in ipairs(flight:advance(dt, cast)) do
					table.insert(all, res)
				end
				if flight:count() == 0 then
					break
				end
			end
			return all
		end
		local Validator = Weapon.Validator

		local function claimRecord(overrides)
			local shot = {
				shooter = nil :: any,
				shooterUserId = 1,
				weapon = "rifle",
				ammo = "Slug",
				muzzle = Vector3.zero,
				ignore = {},
				rangeStuds = 800,
				firedAt = 0,
				epoch = 1,
			}
			for key, value in pairs(overrides or {}) do
				shot[key] = value
			end
			return shot
		end

		-- CASE 28. `Resolution.reachedStuds` is the line-of-sight fact check 5 is judged against, and
		-- it is produced by the flight the server already runs. If it were pinned at 0 every claim in
		-- the shipped game would be refused `claim-blocked` and nothing else would notice.
		it("reachedStuds: a pellet stopped at 40 studs reports 40", function()
			local shot = Ballistics.shotFor(Weapons.ROWS.rifle, "Slug") :: any
			local flight = Flight.new(CONFIG)
			flight:launch(claimRecord({ rangeStuds = 800 }), { Vector3.new(0, 0, -1) }, shot)
			local stopper = Instance.new("Part")
			local out = drain(flight, function(origin: Vector3, direction: Vector3)
				local travelled = (origin - Vector3.zero).Magnitude
				local length = direction.Magnitude
				if travelled + length >= 40 then
					local along = 40 - travelled
					return {
						instance = stopper,
						position = origin + direction.Unit * along,
						normal = Vector3.new(0, 0, 1),
						distance = along,
					}
				end
				return nil
			end, 1 / 60)
			stopper:Destroy()
			expect(#out).to.equal(1)
			expect(math.abs(out[1].reachedStuds - 40) < 0.5).to.equal(true)
		end)

		it("reachedStuds: an unobstructed pellet reports its own range cap", function()
			local shot = Ballistics.shotFor(Weapons.ROWS.rifle, "Slug") :: any
			local flight = Flight.new(CONFIG)
			flight:launch(claimRecord({ rangeStuds = 300 }), { Vector3.new(0, 0, -1) }, shot)
			local out = drain(flight, function()
				return nil
			end, 1 / 60)
			expect(#out).to.equal(1)
			expect(math.abs(out[1].reachedStuds - 300) < 1e-3).to.equal(true)
		end)

		it("reachedStuds: of nine pellets, the GREATEST is reported", function()
			-- Eight pellets stopped at 40 studs and one let through to the 300-stud cap: the
			-- line of sight is the farthest the shot got, not the first thing it met.
			local shot = Ballistics.shotFor(Weapons.ROWS.shotgun, "Buck") :: any
			local flight = Flight.new(CONFIG)
			local directions = {}
			for _ = 1, 9 do
				table.insert(directions, Vector3.new(0, 0, -1))
			end
			flight:launch(claimRecord({ ammo = "Buck", rangeStuds = 300 }), directions, shot)
			local stopper = Instance.new("Part")
			local stopped = 0
			local out = drain(flight, function(origin: Vector3, direction: Vector3)
				local travelled = (origin - Vector3.zero).Magnitude
				local length = direction.Magnitude
				if travelled + length >= 40 and stopped < 8 then
					stopped += 1
					local along = 40 - travelled
					return {
						instance = stopper,
						position = origin + direction.Unit * along,
						normal = Vector3.new(0, 0, 1),
						distance = along,
					}
				end
				return nil
			end, 1 / 60)
			stopper:Destroy()
			expect(#out).to.equal(1)
			expect(stopped).to.equal(8)
			expect(math.abs(out[1].reachedStuds - 300) < 1e-3).to.equal(true)
		end)

		-- CASE 29. `Flight` carries the claim and NEVER reads it: it is the pending queue and nothing
		-- more. A `Flight` that touched the claim would be a second judge of a hit.
		it("Flight carries the claim and never reads it", function()
			local shot = Ballistics.shotFor(Weapons.ROWS.rifle, "Slug") :: any
			local flight = Flight.new(CONFIG)
			-- A claim whose every field would FAIL every check: if `Flight` read it at all, it could
			-- only read it to act on it, and nothing here may change.
			local claim = {
				part = Instance.new("Part"),
				offset = Vector3.new(1e6, 1e6, 1e6),
				point = Vector3.new(-1e6, -1e6, -1e6),
				firedAtView = -1,
				flightSeconds = 1e6,
				distanceStuds = 1e6,
			}
			flight:launch(claimRecord({ rangeStuds = 300, claim = claim }), { Vector3.new(0, 0, -1) }, shot)
			local out = drain(flight, function()
				return nil
			end, 1 / 60)
			expect(#out).to.equal(1)
			-- Carried, byte for byte, and the flight resolved exactly as the unclaimed case above.
			expect(out[1].shot.claim).to.equal(claim)
			expect(#out[1].impacts).to.equal(0)
			expect(math.abs(out[1].reachedStuds - 300) < 1e-3).to.equal(true)
			claim.part:Destroy()
		end)

		-- CASE 26. THE TRUNCATION, and this is the case whose absence blocked round 2: with it, the
		-- accept branch cannot be deleted without something failing.
		it("an accepted claim becomes ONE impact, and Hits.group makes ONE report of it", function()
			local zone = Instance.new("Part")
			zone.Name = "ClaimHitsSpecChest"
			zone.Size = Vector3.new(1.8, 1.8, 3)
			zone:SetAttribute("Damageable", true)
			zone:SetAttribute("HitZone", "chest")
			-- THE ANIMAL HAS MOVED since the claim was made, which is the normal case: the impact
			-- must be built from where it is NOW, so the dust lands on the animal the client is
			-- about to draw.
			local now = CFrame.new(50, 10, -120)
			local claim = {
				part = zone,
				offset = Vector3.new(0.2, 0.1, -0.5),
				point = Vector3.new(0, 0, 0), -- the client's own point; not read here
				firedAtView = 1000,
				flightSeconds = 0.05,
				distanceStuds = 131,
			}
			local bore = Vector3.new(0, 0, -1)
			local impact = Validator.claimImpact(claim, now, bore, Enum.Material.Plastic)
			expect(impact.instance).to.equal(zone)
			expect((impact.position - now * claim.offset).Magnitude < 1e-4).to.equal(true)
			expect((impact.normal - -bore).Magnitude < 1e-6).to.equal(true)
			expect(impact.distance).to.equal(131)

			local reports = Hits.group(nil :: any, { impact }, "Slug", 0, "rifle")
			expect(#reports).to.equal(1)
			expect(reports[1].target).to.equal(zone)
			expect(reports[1].pellets).to.equal(1)
			-- THE ZONE IS READ OFF THE PART'S OWN `HitZone`, on the server, by `Hits.targetOf` --
			-- the claim never names one.
			expect(reports[1].zone).to.equal("chest")
			expect(reports[1].nearest).to.equal(131)
			zone:Destroy()
		end)

		-- CASE 27 IS NOT WRITTEN, AND THAT IS SAID RATHER THAN LEFT OUT. "A refused claim changes
		-- nothing -- the resolution is identical to the same shot with no claim at all" is a property
		-- of `judgeClaimFor`, which is a module local reachable only through a live `onFireRequest`
		-- with a real player holding a loaded gun. What IS executed of it: every one of the six
		-- refusal reasons is driven by name in `weapon_shot.spec`, and case 29 above proves the
		-- flight itself resolves identically whether a claim rides the record or not. What is NOT
		-- executed is the owner's `return res.impacts` on the refused path. Queued as 266a.
	end)
	-- ======================= THE VIEW INSTANT (task 271, design 5.2.1)
	--
	-- **BOTH HELPERS ARE PURE AND BOTH ARE DRIVEN WITH HAND-WRITTEN POINTS**, which is what makes
	-- this case fail on the commit before this task: neither function existed there.
	describe("Validator.pickViewInstant -- which picture the server judges against", function()
		local Validator = Weapon.Validator
		local CLAIM = Shotgun.CONFIG.CLAIM

		-- A straight trajectory along +X from the origin, as two segments.
		local function line()
			return {
				{ from = Vector3.new(0, 0, 0), to = Vector3.new(50, 0, 0) },
				{ from = Vector3.new(50, 0, 0), to = Vector3.new(100, 0, 0) },
			}
		end

		it("measures the closest approach of a walked trajectory, not its ends", function()
			local on, studs = Validator.closestOnSegments(line(), Vector3.new(70, 3, 0))
			expect(studs).to.be.near(3, 1e-6)
			expect((on :: Vector3).X).to.be.near(70, 1e-6)
			-- A point BEHIND the start is measured from the start, not extrapolated.
			local _, behind = Validator.closestOnSegments(line(), Vector3.new(-10, 0, 0))
			expect(behind).to.be.near(10, 1e-6)
			-- No segments is no answer, never a zero that reads like a hit.
			local none, far = Validator.closestOnSegments({}, Vector3.new(0, 0, 0))
			expect(none).to.equal(nil)
			expect(far == math.huge).to.equal(true)
		end)

		it("picks the instant the SERVER'S OWN trajectory came closest, among those passing check 3", function()
			-- THE ANIMAL CROSSES THE LINE OF FIRE: at the arrival instant it is 5 studs off, and one
			-- step back it is ON the line. That is the measured live case -- 99.7 % of a 5.1-stud
			-- gap along the animal's own velocity -- written as arithmetic.
			local candidates = {
				{ at = 100.000, point = Vector3.new(70, 5, 0) },
				{ at = 100.000 - CLAIM.VIEW_LAG_STEP_SECONDS, point = Vector3.new(70, 0.4, 0) },
				{ at = 100.000 - 2 * CLAIM.VIEW_LAG_STEP_SECONDS, point = Vector3.new(70, 4, 0) },
			}
			local index, point, lineStuds, movedStuds, anyPassed =
				Validator.pickViewInstant(candidates, line(), Vector3.new(70, 0.4, 0), CLAIM)
			expect(index).to.equal(2)
			expect(anyPassed).to.equal(true)
			expect(lineStuds).to.be.near(0.4, 1e-6)
			expect(movedStuds).to.be.near(0, 1e-6)
			expect((point :: Vector3).X).to.be.near(70, 1e-6)
			-- AND IT IS A STRICT SUPERSET: what one instant accepted, this accepts. Given only the
			-- arrival instant, the answer is the arrival instant.
			local only = { candidates[1] }
			local onlyIndex, _onlyPoint, onlyLine =
				Validator.pickViewInstant(only, line(), Vector3.new(70, 5, 0), CLAIM)
			expect(onlyIndex).to.equal(1)
			expect(onlyLine).to.be.near(5, 1e-6)
		end)

		it("will not take an instant that fails check 3, however close the line is", function()
			-- The nearest-to-the-line candidate is 30 studs from what the client claimed -- five
			-- times `POSITION_TOLERANCE_STUDS`. It must not be chosen: an animal circling across
			-- the line of fire crosses the trajectory twice, and only one of those is the shooter's
			-- own picture.
			local candidates = {
				{ at = 100.000, point = Vector3.new(70, 1.0, 0) },
				{ at = 99.98, point = Vector3.new(70, 0.0, 30) },
			}
			local index, _point, lineStuds, _moved, anyPassed =
				Validator.pickViewInstant(candidates, line(), Vector3.new(70, 1.0, 0), CLAIM)
			expect(index).to.equal(1)
			expect(anyPassed).to.equal(true)
			expect(lineStuds).to.be.near(1.0, 1e-6)
		end)

		it("when nothing passes check 3 it answers the BEST number, so the refusal names claim-moved", function()
			local candidates = {
				{ at = 100.000, point = Vector3.new(70, 0, 40) },
				{ at = 99.98, point = Vector3.new(70, 0, 9) },
			}
			local index, _point, _line, movedStuds, anyPassed =
				Validator.pickViewInstant(candidates, line(), Vector3.new(70, 0, 0), CLAIM)
			expect(anyPassed).to.equal(false)
			expect(index).to.equal(2)
			expect(movedStuds).to.be.near(9, 1e-6)
			expect(movedStuds > CLAIM.POSITION_TOLERANCE_STUDS).to.equal(true)
		end)

		it("answers nothing for an empty sweep rather than a zero that reads like a hit", function()
			local index, point, lineStuds, movedStuds, anyPassed =
				Validator.pickViewInstant({}, line(), Vector3.zero, CLAIM)
			expect(index).to.equal(nil)
			expect(point).to.equal(nil)
			expect(lineStuds).to.equal(nil)
			expect(movedStuds).to.equal(nil)
			expect(anyPassed).to.equal(false)
		end)
	end)
end
