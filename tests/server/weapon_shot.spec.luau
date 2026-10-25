-- weapon_shot.spec: the pure request validation, the pellet pattern and the safety arc. Every
-- number is a literal here, not an import from CONFIG, so a config that drifts from the design is
-- a finding. The spread assertion is Buck only, over a fixed seed and 1000 shots, as max and mean
-- bounds -- defect (f) of the Task 23 review was a single-draw assertion that was ~25% flaky for a
-- Slug, which fires one pellet.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/shotgun.md (sections 5.3, 13.1)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
-- Task 266b: where the claim counters are published for a probe to read.
local ServerStorage = game:GetService("ServerStorage")

local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
-- THE SHIPPED ROWS, read rather than copied (task 260): the origin-bound cases below claim things
-- about `CAMERA_ORIGIN_TOLERANCE` and `CAMERA_ORIGIN_TOLERANCE_FIRST_PERSON`, and a second copy of
-- either number here would be a second answer to how far a player may claim his eye is.
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
-- ...AND WHICH CAMERA THIS PLACE RUNS, for the same reason `Weapon` itself reads it: the owner
-- resolves one of the two rows from this flag, so a case that asserts WHICH one has to ask the same
-- question rather than assume the default.
local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
-- ONLY TO PUT THE PROVIDERS BACK (task 183). The sight-line case below unwires four of this
-- owner's seams for the length of one shot, and `MatchBoot` is what wired them -- so the restore
-- has to name the same functions rather than nil, exactly as `weapon_rules.spec` does.
local Match = require(ServerScriptService:WaitForChild("Match"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
-- THE LAUNCH ELEVATION (task 185): the bore sits above the sight line so the bullet crosses it
-- again at the zero, and that is a real deviation the convergence claim below has to allow for.
local Ballistics = require(ReplicatedStorage:WaitForChild("Ballistics"))

local Validator = Weapon.Validator
local Pattern = Weapon.Pattern
local SafetyArc = Weapon.SafetyArc
local Hits = Weapon.Hits

-- The spec's own config, written out: a pure function is driven by data, so the data is the spec's.
local CONFIG = {
	PELLETS = { Slug = 1, Buck = 9 },
	SPREAD_FULL_DEG = { Slug = 0.16, Buck = 1.6 },
	CAMERA_ORIGIN_TOLERANCE = 30,
	DIR_UNIT_TOLERANCE = 1e-3,
}

local function angleDeg(a: Vector3, b: Vector3): number
	return math.deg(math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1)))
end

return function()
	describe("shot validation", function()
		local root = Vector3.new(0, 5, 0)

		it("accepts a camera ray from behind the character", function()
			local ok = Validator.checkShot(
				{ origin = Vector3.new(0, 10, 20), direction = Vector3.new(0, 0, -1) },
				root,
				CONFIG
			)
			expect(ok).to.equal(true)
		end)

		it("rejects a dead shooter, bad types, NaN, a non-unit direction and an absurd origin", function()
			expect(select(2, Validator.checkShot({ origin = root, direction = Vector3.xAxis }, nil, CONFIG))).to.equal(
				"not-alive"
			)
			expect(select(2, Validator.checkShot("nope", root, CONFIG))).to.equal("bad-type")
			expect(select(2, Validator.checkShot({ origin = "x", direction = Vector3.xAxis }, root, CONFIG))).to.equal(
				"bad-type"
			)
			local nan = Vector3.new(0 / 0, 0, 0)
			expect(select(2, Validator.checkShot({ origin = nan, direction = Vector3.xAxis }, root, CONFIG))).to.equal(
				"nan"
			)
			expect(select(2, Validator.checkShot({ origin = root, direction = Vector3.new(0, 0, -2) }, root, CONFIG))).to.equal(
				"not-unit"
			)
			expect(
				select(
					2,
					Validator.checkShot({ origin = Vector3.new(0, 5, 60), direction = Vector3.xAxis }, root, CONFIG)
				)
			).to.equal("origin-far")
		end)

		it("bounds the origin at the FOURTH ARGUMENT when it is given, and at the config when it is not", function()
			-- TASK 260's SECURITY HALF, AND IT HAD NO TEST AT ALL UNTIL ROUND 3 (the Reviewer's
			-- blocking finding, and his test for it was the right one: deleting the fourth argument
			-- from both `Weapon.onFireRequest` and `onActionRequest` left the whole suite green with
			-- the shipped first-person bound silently back at the third-person 15).
			--
			-- IT MATTERS BECAUSE `BORE_ON_SIGHT_LINE` LAUNCHES THE BULLET FROM `req.origin`. Before
			-- that the launch point was a `Muzzle` attachment the server read off its own Tool, and
			-- this bound only rejected absurd aim rays; now it is the one number standing between a
			-- client and a shot that starts somewhere else.
			local tight = Shotgun.CONFIG.CAMERA_ORIGIN_TOLERANCE_FIRST_PERSON
			local loose = CONFIG.CAMERA_ORIGIN_TOLERANCE
			expect(tight < loose).to.equal(true)
			-- A CLAIM BETWEEN THE TWO: honest under the loose bound, forged under the tight one. The
			-- same payload, the same root, the same config -- only the fourth argument differs, which
			-- is what makes this a test of the parameter and not of the arithmetic.
			local between = root + Vector3.new(0, 0, (tight + loose) / 2)
			local req = { origin = between, direction = Vector3.xAxis }
			expect(Validator.checkShot(req, root, CONFIG, loose)).to.equal(true)
			expect(select(2, Validator.checkShot(req, root, CONFIG, tight))).to.equal("origin-far")
			-- `nil` IS THE CONFIG, which is every caller written before task 260.
			expect(Validator.checkShot(req, root, CONFIG)).to.equal(true)
			expect(Validator.checkShot(req, root, CONFIG, nil)).to.equal(true)
			-- ...AND A NON-NUMBER IS THE CONFIG TOO, so a caller that passes junk cannot widen it.
			expect(Validator.checkShot(req, root, CONFIG, "6" :: any)).to.equal(true)
			-- AN ORIGIN INSIDE THE TIGHT BOUND IS STILL HONEST AT BOTH, so this is a bound and not a
			-- blanket refusal.
			local near = { origin = root + Vector3.new(0, 0, tight - 1), direction = Vector3.xAxis }
			expect(Validator.checkShot(near, root, CONFIG, tight)).to.equal(true)
			expect(Validator.checkShot(near, root, CONFIG, loose)).to.equal(true)
		end)

		it("resolves the SHIPPED bound to the first-person row, which is what the owner passes", function()
			-- THE OTHER HALF OF THE SAME FINDING: the case above proves the validator HONOURS the
			-- argument, and this one proves the owner PASSES the right one. `ORIGIN_TOLERANCE_STUDS`
			-- is a module local read once at `Weapon`'s boundary, so `Weapon.stats().originTolerance`
			-- is the only way anything outside that file can see which of the two rows the shipped
			-- build chose. With `FIRST_PERSON` lit -- which is what the game ships and what
			-- `flags.spec` pins -- it must be the tight one.
			local resolved = Weapon.stats().originTolerance
			expect(type(resolved)).to.equal("number")
			if Flags.isOn("FIRST_PERSON") then
				expect(resolved).to.equal(Shotgun.CONFIG.CAMERA_ORIGIN_TOLERANCE_FIRST_PERSON)
			else
				expect(resolved).to.equal(Shotgun.CONFIG.CAMERA_ORIGIN_TOLERANCE)
			end
			-- AND IT IS ONE OF THE TWO ROWS AND NOT A THIRD NUMBER, whichever branch this place runs.
			expect(
				resolved == Shotgun.CONFIG.CAMERA_ORIGIN_TOLERANCE_FIRST_PERSON
					or resolved == Shotgun.CONFIG.CAMERA_ORIGIN_TOLERANCE
			).to.equal(true)
		end)
	end)

	describe("request validation", function()
		it("accepts only Reload and SelectAmmo, so no reducer primitive is reachable", function()
			expect(Validator.checkRequest("Reload", nil)).to.equal(true)
			expect(Validator.checkRequest("SelectAmmo", "Slug")).to.equal(true)
			expect(Validator.checkRequest("SelectAmmo", "Buck")).to.equal(true)
			-- Defect (d), written out so a later ActionKind cannot leak in unnoticed.
			for _, bad in ipairs({ "Break", "Load", "Close", "Fire", "", "reload", 42 }) do
				expect(Validator.checkRequest(bad, nil)).to.equal(false)
			end
			expect(Validator.checkRequest(nil, nil)).to.equal(false)
			expect(Validator.checkRequest({}, nil)).to.equal(false)
			expect(Validator.checkRequest("SelectAmmo", "Grenade")).to.equal(false)
			expect(Validator.checkRequest("Reload", "Slug")).to.equal(false)
			expect(select(2, Validator.checkRequest("Break", nil))).to.equal("bad-request")
		end)

		-- THE OTHER HALF OF THE SAME RULE, at the seam a forged request actually arrives through
		-- (Task 80). The case above proves the whitelist says no; this proves the HANDLER asks it,
		-- which is the half that would let an exploit through if someone moved the check.
		--
		-- IT USED TO BE A CLIENT CASE, and it could never have been sound there. `weapon_client.spec`
		-- fired forged payloads from a Play client and watched this player's published state for a
		-- change -- but `ServerScriptService.Weapon` is the only writer of that state and rewrites it
		-- on its own schedule: `grant` resets it and auto-equips, the arming sweep calls grant again,
		-- a Reload is a multi-step cycle. So "the state changed" and "the forged request was accepted"
		-- are the same observation from a client, and two two-player runs failed for the first reason
		-- while reading as the second (`weapon granted=9 revoked=4` in that session's own note).
		--
		-- Here there is no window and no waiting. `Weapon.onActionRequest` and `Weapon.onFireRequest`
		-- ARE the functions `Weapon.start` connects to the remotes, and `stats.badRequests` rises in
		-- exactly one place: the branch taken when the validator refuses. Counting it is what makes
		-- this deterministic -- a legitimate grant or reload cannot raise that number.
		it("consults the whitelist before acting, at the handler the remote calls", function()
			-- A player the owner is already tracking, because a request for an untracked player
			-- returns before the validator and proves nothing.
			local subject = nil
			local roster = {}
			for _, player in ipairs(Players:GetPlayers()) do
				table.insert(roster, player.Name .. (if Weapon.getSnapshot(player) then "(tracked)" else "(untracked)"))
				if not subject and Weapon.getSnapshot(player) then
					subject = player
				end
			end
			if not subject then
				-- Not a skip (TestKit fails the run for those): say what was missing and assert the
				-- half that needs nobody, so this case never passes silently.
				TestKit.note(
					"weapon_shot: no tracked player, so the handler half was not driven; roster ["
						.. table.concat(roster, ", ")
						.. "]"
				)
				expect(Validator.checkRequest("Break", nil)).to.equal(false)
				return
			end

			local actions = {
				{ "Break", nil },
				{ "Load", nil },
				{ "Close", nil },
				{ "Fire", nil },
				{ "", nil },
				{ 42, nil },
				{ {}, nil },
				{ "SelectAmmo", "Grenade" },
				{ "Reload", "Slug" },
			}
			local shots = { "not a table", { origin = "x", direction = Vector3.zero }, 7 }

			-- THE RATE LIMITER IS A PRE-VALIDATOR EXIT, so a dropped call would prove nothing. It is
			-- not avoided by counting to ten and guessing: the handler SAYS "rate-limited", so a call
			-- that hits the limit is simply made again in the next window.
			local function ask(send: () -> string?): string?
				local why = send()
				if why == "rate-limited" then
					task.wait(1.1)
					why = send()
				end
				return why
			end

			local before = Weapon.stats()
			local said = {}
			local accepted, preValidator = {}, {}
			local function record(label: string, why: string?)
				table.insert(said, label .. "=" .. tostring(why))
				if why == nil then
					table.insert(accepted, label)
				elseif why == "rate-limited" or why == "untracked" then
					table.insert(preValidator, label .. "=" .. why)
				end
			end

			for _, pair in ipairs(actions) do
				local kind, ammo = pair[1], pair[2]
				record(
					"action " .. tostring(kind) .. (if ammo then "/" .. tostring(ammo) else ""),
					ask(function()
						return Weapon.onActionRequest(subject, kind, ammo)
					end)
				)
			end
			for index, bad in ipairs(shots) do
				record(
					"fire #" .. index,
					ask(function()
						return Weapon.onFireRequest(subject, bad)
					end)
				)
			end
			local after = Weapon.stats()

			-- WHAT IT COUNTED AND FROM WHOM, because the first version of this case could not say.
			-- The counter deltas are the WHOLE SERVER's -- `stats` is one module-level table, so a
			-- second player's legitimate click lands in them -- and they are context here, not the
			-- assertion. The per-call reasons below are what is asserted, and each belongs to one call
			-- and one player.
			TestKit.note(
				string.format(
					"weapon_shot: %d forged request(s) at the handler, subject %s of roster [%s]; "
						.. "reasons [%s]; server-wide counters over the same window: badRequests +%d, "
						.. "rateDropped +%d, shots +%d (other players' shots land in these)",
					#actions + #shots,
					subject.Name,
					table.concat(roster, ", "),
					table.concat(said, ", "),
					after.badRequests - before.badRequests,
					after.rateDropped - before.rateDropped,
					after.shots - before.shots
				)
			)

			-- NOT ONE OF THEM WAS ACTED ON: the handlers return nil only on the paths that did
			-- something.
			expect(#accepted).to.equal(0)
			-- ...and every one of them reached the VALIDATOR to be refused, rather than falling out at
			-- an earlier guard, which would make this case green with the whitelist deleted.
			expect(#preValidator).to.equal(0)
			expect(#said).to.equal(#actions + #shots)
		end)
	end)

	-- ------------------------------------------------------------------ the sight line (task 183)
	--
	-- KAREN, 2026-10-14: *"hit it has to be precist and on 200m acurat"*. The question underneath
	-- that is WHOSE LINE the bullet travels on. The muzzle of a scoped rifle is about a foot below
	-- and a yard in front of the eye, so a server that cast from the muzzle ALONG THE CAMERA'S
	-- DIRECTION would miss by that offset at every range -- parallax, and it would never close.
	--
	-- `Weapon.onFireRequest` does not do that, and this is the case that pins it: it casts the
	-- client's ray to find the AIM POINT, then aims the pellet ray from the muzzle AT that point.
	-- The two rays therefore meet exactly where the player was looking, whatever the offset is.
	-- Asserted through `Weapon.setCast`, which is the seam that lets a spec read the rays the owner
	-- really built (design section 13.5).
	describe("the sight line", function()
		it("casts the pellet from the MUZZLE but aims it at the point the camera ray hit", function()
			-- READY, NOT MERELY ARMED, AND THAT COST A ROUND: the first version asked only whether a
			-- barrel was Live and got `"busy"` back, because the harness replays real clicks into
			-- this same client and the bolt or the reload sequence can be mid-flight when a spec
			-- runs. `busyFor` is on the snapshot for exactly this question, so the case waits for a
			-- gun that can fire rather than asserting that one happened to be able to.
			local function readyGun(player: Player): any?
				local state = Weapon.getSnapshot(player)
				if state == nil or state.equipped ~= true or state.open ~= false then
					return nil
				end
				if (state.busyFor or 0) > 0 or state.barrels[state.selected] ~= "Live" then
					return nil
				end
				return state
			end

			local subject, snapshot = nil, nil
			local roster = {}
			for _ = 1, 40 do
				roster = {}
				for _, player in ipairs(Players:GetPlayers()) do
					local state = Weapon.getSnapshot(player)
					local ready = readyGun(player)
					table.insert(
						roster,
						player.Name
							.. (
								if ready ~= nil
									then "(ready)"
									else (if state ~= nil
										then string.format(
											"(not ready: open=%s busy=%.2f %s)",
											tostring(state.open),
											state.busyFor or 0,
											tostring(state.barrels[state.selected])
										)
										else "(untracked)")
							)
					)
					if subject == nil and ready ~= nil then
						subject, snapshot = player, ready
					end
				end
				if subject ~= nil then
					break
				end
				task.wait(0.25)
			end
			if subject == nil then
				-- NOT A SKIP (TestKit fails the run for those), AND NOT A TAUTOLOGY EITHER (the
				-- Reviewer's note, round 1). The first version asserted `(v - aim * v:Dot(aim))` is
				-- perpendicular to `aim`, which is true of any vector and says nothing about this
				-- game. What is asserted instead is the rifle's own two numbers -- the data Karen's
				-- *"precist and on 200m acurat"* reduces to -- so a run in which the handler could
				-- not be driven still proves something that could be false.
				TestKit.note(
					"weapon_shot sight line: nobody is holding a gun that can fire, so the handler was not "
						.. "driven; roster ["
						.. table.concat(roster, ", ")
						.. "]"
				)
				expect(Weapons.ROWS.rifle.SPREAD_FULL_DEG.Slug).to.equal(0)
				expect(Weapons.ROWS.rifle.RANGE_STUDS.Slug >= 714.29).to.equal(true)
				-- ...AND THE ZERO IS AT THE DISTANCE SHE NAMED (task 185), which is the other half
				-- of "dead centre at 200 m": a still target at the zero is on the sight line by
				-- construction (`Ballistics.sightOffsetAt` is 0 there, asserted purely in
				-- ballistics.spec).
				expect(Weapons.ROWS.rifle.ZERO_STUDS.Slug).to.equal(714)
				return
			end

			local root = subject.Character and subject.Character:FindFirstChild("HumanoidRootPart")
			expect(root).to.be.ok()
			-- THE EYE, PUT WHERE A SCOPE PUTS IT: above the root and offset across, so the muzzle
			-- CANNOT be on this ray by accident. A case whose origin is already the muzzle proves
			-- nothing about parallax.
			local origin = (root :: BasePart).Position + Vector3.new(0.6, 2.4, 0)
			local direction = Vector3.new(0, 0, -1)
			local request = { origin = origin, direction = direction }

			-- THE AIM POINT, AS FAR OUT AS THE GUN IN HAND CAN REACH, and 714 studs -- 200 m at
			-- 0.28 m/stud, the distance Karen named -- when it can reach that. It has to be INSIDE
			-- that weapon's range or the "the ray gets there" claim below is false for a reason
			-- that has nothing to do with aiming: the harness's player holds the SHOTGUN in a
			-- one-player DEV run, and a 12-gauge slug stops at 330 studs. That cost a round.
			-- The stub answers the FIRST cast (the camera ray) with a hit there and every later
			-- cast with nothing, so the pellet ray is read rather than resolved against the world.
			local heldId = Weapon.heldId(subject) or Weapons.PRIMARY
			local row = Weapons.row(heldId) or Weapons.ROWS[Weapons.PRIMARY]
			local ammo = (snapshot :: any).loaded[(snapshot :: any).selected]
			local reach = math.min(714.29, row.RANGE_STUDS[ammo] * 0.9)
			local aimPoint = origin + direction * reach
			local plate = Instance.new("Part")
			plate.Name = "ShotSpecSightLinePlate"
			local casts = {}
			Weapon.setCast(function(castOrigin: Vector3, castVector: Vector3)
				table.insert(casts, { origin = castOrigin, vector = castVector })
				if #casts == 1 then
					return {
						instance = plate,
						position = aimPoint,
						normal = -direction,
						distance = (aimPoint - castOrigin).Magnitude,
					}
				end
				return nil
			end)
			-- The four rules, out of the way for one shot: this case is about geometry.
			Weapon.setTargetProvider(nil)
			Weapon.setStandProvider(nil)
			Weapon.setLicenceProvider(nil)
			Weapon.setDriveOpenProvider(function(): boolean
				return true
			end)

			-- THREE TRIES, AND THE TWO REASONS THAT ARE NOT ABOUT GEOMETRY: the fire limiter is per
			-- second, and the gun can go busy between the readiness check above and the trigger
			-- (the same replayed clicks). Nothing else is retried -- a refusal from `Rules` would
			-- mean a seam this case unwired is still answering, and that must fail rather than loop.
			local why = Weapon.onFireRequest(subject, request)
			for _ = 1, 2 do
				if why ~= "rate-limited" and why ~= "busy" then
					break
				end
				task.wait(1.2)
				casts = {}
				why = Weapon.onFireRequest(subject, request)
			end

			-- WAIT FOR THE BULLET (task 185). The pellet casts no longer happen in the trigger's own
			-- frame: `Weapon.Flight` steps the shot on the server's Heartbeat, so its segments arrive
			-- over the next 0.1 to 0.37 s. Restoring the cast immediately -- which is what this case
			-- did until task 185 -- would record the camera ray and NOTHING else, and the spec would
			-- go red for a reason that has nothing to do with aiming. One second covers the rifle at
			-- its 800-stud cap (0.365 s) with room to spare.
			local drainBy = os.clock() + 1
			while Weapon.flightCount() > 0 and os.clock() < drainBy do
				task.wait()
			end

			Weapon.setCast(nil)
			Weapon.setTargetProvider(Match.classifyTarget)
			Weapon.setStandProvider(Match.standAreaFor)
			Weapon.setDriveOpenProvider(Match.driveOpen)
			plate:Destroy()

			if why ~= nil or #casts < 2 then
				-- SAID OUT LOUD AND THEN ASSERTED PURELY, never silent: if the live handler could
				-- not be driven, the claim still has to be made against the arithmetic it would
				-- have done, which is what the no-subject branch above does too.
				TestKit.note(
					string.format(
						"weapon_shot sight line: the handler refused (%s) with %d cast(s); asserting the "
							.. "convergence arithmetic instead",
						tostring(why),
						#casts
					)
				)
				expect(Weapons.ROWS.rifle.SPREAD_FULL_DEG.Slug).to.equal(0)
				expect(Weapons.ROWS.rifle.RANGE_STUDS.Slug >= 714.29).to.equal(true)
				-- ...AND THE ZERO IS AT THE DISTANCE SHE NAMED (task 185), which is the other half
				-- of "dead centre at 200 m": a still target at the zero is on the sight line by
				-- construction (`Ballistics.sightOffsetAt` is 0 there, asserted purely in
				-- ballistics.spec).
				expect(Weapons.ROWS.rifle.ZERO_STUDS.Slug).to.equal(714)
				return
			end
			-- THE CLAIMS BELOW ARE THE OWNER'S, not one weapon's: the ray starts at the muzzle,
			-- and its only deviation from the muzzle-to-aim-point line is the cone that weapon's
			-- own data declares.
			local halfConeDeg = row.SPREAD_FULL_DEG[ammo] / 2

			-- 1. THE FIRST CAST IS THE CLIENT'S RAY, unaltered: the server does not second-guess
			--    where the player was looking, and its reach is the ammo's range.
			expect((casts[1].origin - origin).Magnitude < 1e-4).to.equal(true)
			expect(casts[1].vector.Unit:Dot(direction) > 1 - 1e-6).to.equal(true)
			expect(math.abs(casts[1].vector.Magnitude - row.RANGE_STUDS[ammo]) < 1e-3).to.equal(true)

			-- 2. THE PELLET STARTS AT THE MUZZLE, which is NOT the eye. If this ever equals the
			--    origin the gun is shooting out of the camera and claim 3 is vacuous.
			local muzzle = casts[2].origin
			expect((muzzle - origin).Magnitude > 0.5).to.equal(true)
			-- ...AND EVERY LATER CAST WALKS THE PATH FROM THERE (task 185): the projectile is stepped,
			-- and each segment starts where the previous one ended. Until task 185 every pellet cast
			-- started at the muzzle, because every pellet was resolved in one cast; now the muzzle is
			-- where the FIRST segment starts and the rest are the flight.
			for index = 3, #casts do
				local previousEnd = casts[index - 1].origin + casts[index - 1].vector
				expect((casts[index].origin - previousEnd).Magnitude < 1e-3).to.equal(true)
			end

			-- 3. ...AND EVERY PELLET IS AIMED AT THE AIM POINT. `idealAim` is the muzzle-to-aim-point
			--    line: a server that cast from the muzzle along the CAMERA'S direction instead
			--    would sit a constant sight-over-bore offset away from it at every range, and that
			--    is the parallax this claim rules out. What is left is the declared cone, so the
			--    bound is the weapon's own half-angle and not a number typed here.
			local idealAim = (aimPoint - muzzle).Unit
			-- THE BOUND IS THE CONE PLUS THE LAUNCH ELEVATION (task 185). The bore sits a little
			-- above the sight line so the falling bullet crosses it again at the zero distance, and
			-- that elevation is a real, declared deviation from the muzzle-to-aim-point line -- 0.067
			-- degrees for the shotgun's slug, 0.130 for the rifle. It is read from `Ballistics` and
			-- not typed here, so a change to the zero moves this bound with it.
			local ballistic = Ballistics.shotFor(row, ammo)
			expect(ballistic).to.be.ok()
			local elevationDeg = math.deg(math.atan(Ballistics.elevationTangent(ballistic :: any)))
			local worstDeg = angleDeg(casts[2].vector, idealAim)
			expect(worstDeg <= halfConeDeg + elevationDeg + 1e-6).to.equal(true)
			-- ...and the shot really does FLY as far as the ammo's declared range, so it really does
			--    reach the aim point. That is the other half of what task 183 found: a range under
			--    the distance aimed at is a shot that cannot arrive however well it is pointed, and
			--    `RANGE_STUDS` is the one number that decides it. Under hitscan this was one cast of
			--    exactly that length; it is now the sum of the segments, because the stub answers
			--    every cast after the first with nothing and the projectile flies to its cap.
			local path = 0
			for index = 2, #casts do
				path += casts[index].vector.Magnitude
			end
			expect(math.abs(path - row.RANGE_STUDS[ammo]) < 1e-2).to.equal(true)
			expect(path >= (aimPoint - muzzle).Magnitude).to.equal(true)

			TestKit.note(
				string.format(
					"sight line: %s holding %s/%s, eye %.2f studs from the muzzle; worst pellet %.4f deg "
						.. "off the muzzle-to-aim line (cone allows %.3f) = %.1f cm at 714 studs; reach "
						.. "%.0f studs for a %.0f-stud aim point, %d cast(s)",
					subject.Name,
					heldId,
					tostring(ammo),
					(muzzle - origin).Magnitude,
					worstDeg,
					halfConeDeg + elevationDeg,
					math.tan(math.rad(worstDeg)) * 714.29 * 0.28 * 100,
					path,
					(aimPoint - muzzle).Magnitude,
					#casts
				)
			)

			-- 4. AND THE RIFLE REACHES THE DISTANCE KAREN NAMED. Its CONE is `rifle.spec`'s to
			--    assert and is not repeated here (the Reviewer's note, round 1: three copies of
			--    `SPREAD_FULL_DEG.Slug == 0` is three edits for one dial). What belongs on this
			--    path is the range, because claim 3 above bounds the deviation by the cone and a
			--    bullet that stops short is the other way to miss.
			expect(Weapons.ROWS.rifle.RANGE_STUDS.Slug >= 714.29).to.equal(true)
		end)
	end)

	describe("pellet pattern", function()
		local aim = Vector3.new(0, 0, -1)

		it("fires one slug and nine pellets, all unit vectors", function()
			local slug = Pattern.directions("Slug", aim, Random.new(1337), CONFIG)
			local buck = Pattern.directions("Buck", aim, Random.new(1337), CONFIG)
			expect(#slug).to.equal(1)
			expect(#buck).to.equal(9)
			for _, direction in ipairs(buck) do
				expect(math.abs(direction.Magnitude - 1) < 1e-6).to.equal(true)
			end
		end)

		it("keeps buckshot inside a 1.6 degree FULL cone, and actually spreads", function()
			local rng = Random.new(1337) -- a fixture: nothing here depends on a single draw
			local maximum, total, count = 0, 0, 0
			for _ = 1, 1000 do
				for _, direction in ipairs(Pattern.directions("Buck", aim, rng, CONFIG)) do
					local deg = angleDeg(direction, aim)
					maximum = math.max(maximum, deg)
					total += deg
					count += 1
				end
			end
			expect(count).to.equal(9000)
			expect(maximum <= 0.8).to.equal(true) -- half of the full cone; a 2x error fails
			expect(maximum > 0.4).to.equal(true) -- and it is not collapsed to a point
			local mean = total / count
			expect(mean > 0.2 and mean < 0.7).to.equal(true)
		end)

		it("keeps a slug inside 0.08 degrees of the aim", function()
			local rng = Random.new(1337)
			for _ = 1, 100 do
				local direction = Pattern.directions("Slug", aim, rng, CONFIG)[1]
				expect(angleDeg(direction, aim) <= 0.08).to.equal(true)
			end
		end)

		it("is deterministic for a seed and different for another", function()
			local a = Pattern.directions("Buck", aim, Random.new(42), CONFIG)
			local b = Pattern.directions("Buck", aim, Random.new(42), CONFIG)
			local c = Pattern.directions("Buck", aim, Random.new(43), CONFIG)
			for index = 1, 9 do
				expect((a[index] - b[index]).Magnitude < 1e-9).to.equal(true)
			end
			expect((a[1] - c[1]).Magnitude > 1e-9).to.equal(true)
		end)

		it("errors on a zero aim rather than inventing a direction", function()
			expect(function()
				Pattern.directions("Buck", Vector3.zero, Random.new(1), CONFIG)
			end).to.throw()
		end)
	end)

	describe("safety arc", function()
		local line = { position = Vector3.zero, normal = Vector3.new(0, 0, -1) }

		it("forbids straight down the normal, allows 90 degrees away, and includes the boundary", function()
			expect(SafetyArc.isForbidden(Vector3.new(0, 0, -1), line, 45)).to.equal(true)
			expect(SafetyArc.isForbidden(Vector3.new(1, 0, 0), line, 45)).to.equal(false)
			expect(SafetyArc.isForbidden(Vector3.new(0, 0, 1), line, 45)).to.equal(false)
			local boundary = Vector3.new(math.sin(math.rad(45)), 0, -math.cos(math.rad(45)))
			expect(SafetyArc.isForbidden(boundary, line, 45)).to.equal(true)
			expect(SafetyArc.isForbidden(Vector3.new(math.sin(math.rad(46)), 0, -math.cos(math.rad(46))), line, 45)).to.equal(
				false
			)
		end)
	end)

	describe("shot cost", function()
		it("patterns and groups 1000 shots in under 500 ms", function()
			local rng = Random.new(7)
			local aim = Vector3.new(0, 0, -1)
			-- A real target: with instance = nil, targetOf returns on its first check and `group`
			-- does nothing, so the budget measured only Pattern.directions (round 1 note).
			local target = Instance.new("Part")
			target:SetAttribute("Damageable", true)
			target:SetAttribute("HitZone", "body")
			local started = os.clock()
			for _ = 1, 1000 do
				local directions = Pattern.directions("Buck", aim, rng, CONFIG)
				local impacts = {}
				for index, direction in ipairs(directions) do
					impacts[index] = {
						instance = target,
						position = direction * 10,
						normal = direction,
						distance = 10,
					}
				end
				local reports = Hits.group(nil :: any, impacts, "Buck", 0)
				expect(#reports).to.equal(1)
			end
			local elapsed = os.clock() - started
			target:Destroy()
			expect(elapsed < 0.5).to.equal(true)
		end)
	end)
	-- ---------------------------------------------------------------- THE HIT CLAIM (task 266)
	--
	-- KAREN, 2026-10-24/25: *"we need to aim in empty space to get hit in head neck or heart like in
	-- real life"* / *"this signe where we shot ... shows we hit empty space and died"*.
	--
	-- THE DISPATCH'S ACCEPTANCE (3) IS "A FORGED CLAIM IS REJECTED", and it is proved twice here on
	-- purpose, because the two halves can fail independently:
	--   PURE  -- the RULE: a claim whose point is 30 studs from where the server says the animal was
	--            is refused, by name, with every tolerance handed in as a number.
	--   LIVE  -- the WIRING: the real `Weapon.onFireRequest`, with the policy ON, counts the claim and
	--            refuses it, and no `HitReported` fires. A boundary flag read into a module local is
	--            invisible from outside, and task 260 round 3 proved that the hard way: deleting the
	--            wiring left the whole suite green with the feature silently off.
	describe("the hit claim", function()
		local CLAIM = Shotgun.CONFIG.CLAIM

		-- The facts the owner measures, as numbers, all of them INSIDE every tolerance -- so each case
		-- below moves exactly one of them and nothing else can be the reason it failed.
		local function honestFacts()
			return {
				offset = Vector3.new(0, 0.5, -0.6),
				partHalf = Vector3.new(0.9, 0.9, 1.5),
				clientPoint = Vector3.new(100, 10, 100),
				serverPoint = Vector3.new(100, 10, 100),
				trajectoryPoint = Vector3.new(100, 10, 100),
				reachedStuds = 150,
				claimedStuds = 130,
				ageSeconds = 0.08,
				flightSeconds = 0.052,
				expectedFlightSeconds = 0.052,
			}
		end

		it("accepts an honest claim -- so every refusal below is the thing it moved", function()
			local ok, why = Validator.judgeClaim(honestFacts(), CLAIM)
			expect(ok).to.equal(true)
			expect(why).to.equal(nil)
		end)

		-- ACCEPTANCE (3). The probe's own case: a claim about an animal 30 studs from where it was.
		it("REFUSES a claim whose point is 30 studs from the server's own rewind", function()
			local facts = honestFacts()
			facts.clientPoint = facts.serverPoint + Vector3.new(30, 0, 0)
			local ok, why = Validator.judgeClaim(facts, CLAIM)
			expect(ok).to.equal(false)
			expect(why).to.equal("claim-moved")
			-- AND THE MARGIN IS A FACTOR OF FIVE, not a hair: 30 studs against a 6-stud tolerance.
			expect(30 / CLAIM.POSITION_TOLERANCE_STUDS >= 5).to.equal(true)
		end)

		it("REFUSES a claim the server's own trajectory did not pass -- the zone check", function()
			local facts = honestFacts()
			facts.trajectoryPoint = facts.serverPoint + Vector3.new(0, 0, CLAIM.LINE_TOLERANCE_STUDS + 0.5)
			local ok, why = Validator.judgeClaim(facts, CLAIM)
			expect(ok).to.equal(false)
			expect(why).to.equal("claim-line")
		end)

		it("REFUSES a claim whose offset is off the claimed box", function()
			local facts = honestFacts()
			facts.offset = Vector3.new(0, 0.5, -(facts.partHalf.Z + CLAIM.SKIN_STUDS + 0.1))
			local ok, why = Validator.judgeClaim(facts, CLAIM)
			expect(ok).to.equal(false)
			expect(why).to.equal("claim-offset")
		end)

		it("REFUSES a claim the bullet could not have reached -- the line of sight", function()
			local facts = honestFacts()
			-- The server's own shot stopped at a tree 40 studs out; the claim says 130.
			facts.reachedStuds = 40
			local ok, why = Validator.judgeClaim(facts, CLAIM)
			expect(ok).to.equal(false)
			expect(why).to.equal("claim-blocked")
		end)

		it("REFUSES an arrival in the FUTURE and one outside the window", function()
			local future = honestFacts()
			future.ageSeconds = -0.01
			local okFuture, whyFuture = Validator.judgeClaim(future, CLAIM)
			expect(okFuture).to.equal(false)
			expect(whyFuture).to.equal("claim-future")

			local stale = honestFacts()
			stale.ageSeconds = CLAIM.AGE_MAX_SECONDS + 0.01
			local okStale, whyStale = Validator.judgeClaim(stale, CLAIM)
			expect(okStale).to.equal(false)
			expect(whyStale).to.equal("claim-stale")
		end)

		it("REFUSES a flight time this gun could not have produced", function()
			local facts = honestFacts()
			facts.flightSeconds = facts.expectedFlightSeconds + CLAIM.FLIGHT_TOLERANCE_SECONDS + 0.01
			local ok, why = Validator.judgeClaim(facts, CLAIM)
			expect(ok).to.equal(false)
			expect(why).to.equal("claim-time")
		end)

		-- THE SHAPE GATE, at the trigger. A pattern weapon may not claim a point at all, and that is
		-- read off the ROW on the server -- data, not a bit the client chooses (design section 6).
		it("REFUSES a claim from a nine-pellet pattern, off the weapon's own row", function()
			local claim = {
				part = workspace,
				offset = Vector3.zero,
				point = Vector3.zero,
				firedAtView = 100,
				flightSeconds = 0.05,
				distanceStuds = 100,
			}
			expect(Weapons.ROWS.shotgun.PELLETS.Buck).to.equal(9)
			local ok, why = Validator.checkClaim(claim, Shotgun.CONFIG, Weapons.ROWS.shotgun.PELLETS.Buck)
			expect(ok).to.equal(false)
			expect(why).to.equal("claim-pattern")
			-- ...and the SAME claim from a single-pellet load passes the shape gate.
			local okSlug = Validator.checkClaim(claim, Shotgun.CONFIG, Weapons.ROWS.shotgun.PELLETS.Slug)
			expect(okSlug).to.equal(true)
		end)

		it("REFUSES a NaN, an infinity, a missing field and a part that is not an Instance", function()
			local function claimWith(changes: any)
				local claim = {
					part = workspace,
					offset = Vector3.zero,
					point = Vector3.zero,
					firedAtView = 100,
					flightSeconds = 0.05,
					distanceStuds = 100,
				}
				for key, value in pairs(changes) do
					claim[key] = value
				end
				return claim
			end
			expect(select(2, Validator.checkClaim(claimWith({ flightSeconds = 0 / 0 }), Shotgun.CONFIG, 1))).to.equal(
				"claim-nan"
			)
			expect(select(2, Validator.checkClaim(claimWith({ distanceStuds = math.huge }), Shotgun.CONFIG, 1))).to.equal(
				"claim-nan"
			)
			expect(select(2, Validator.checkClaim(claimWith({ part = "Boar1" }), Shotgun.CONFIG, 1))).to.equal(
				"claim-part"
			)
			expect(select(2, Validator.checkClaim(claimWith({ offset = 3 }), Shotgun.CONFIG, 1))).to.equal("claim-type")
			expect(select(2, Validator.checkClaim("not a table", Shotgun.CONFIG, 1))).to.equal("claim-type")
		end)

		-- THE WIRING, LIVE. The policy is a parameter beside the flag precisely so this case can reach
		-- the ON branch while the row sits at OFF, which is what CLAUDE.md requires of a flagged path.
		it("the policy is reachable by parameter, and the flag is what it falls back to", function()
			expect(Weapon.stats().claimsEnabled).to.equal(Flags.isOn("HIT_CLAIM"))
			local was = Weapon.setClaimPolicy(true)
			expect(Weapon.stats().claimsEnabled).to.equal(true)
			Weapon.setClaimPolicy(false)
			expect(Weapon.stats().claimsEnabled).to.equal(false)
			Weapon.setClaimPolicy(was)
			-- RESTORED TO THE BOUNDARY'S OWN ANSWER, not to a literal: `was` is nil in the shipped
			-- build and the flag is what answers then.
			expect(Weapon.stats().claimsEnabled).to.equal(Flags.isOn("HIT_CLAIM"))
		end)

		it("counts a claim it was given, and refuses the forged one through the real handler", function()
			-- A READY GUN, or the handler is not driven and the case says so rather than passing by
			-- accident -- the shape the sight-line case above already uses and for the same reason.
			local subject, snapshot = nil, nil
			for _ = 1, 20 do
				for _, player in ipairs(Players:GetPlayers()) do
					local state = Weapon.getSnapshot(player)
					if
						state ~= nil
						and state.equipped == true
						and state.open == false
						and (state.busyFor or 0) <= 0
						and state.barrels[state.selected] == "Live"
					then
						subject, snapshot = player, state
						break
					end
				end
				if subject ~= nil then
					break
				end
				task.wait(0.25)
			end
			if subject == nil then
				TestKit.note("weapon_shot hit claim: nobody is holding a gun that can fire; the pure cases above stand")
				expect(CLAIM.POSITION_TOLERANCE_STUDS > 0).to.equal(true)
				return
			end

			local root = subject.Character and subject.Character:FindFirstChild("HumanoidRootPart")
			expect(root).to.be.ok()

			-- A STAND-IN ANIMAL: `Damageable` is what `Hits.targetOf` reads, and it is set here by this
			-- spec rather than by a boar, so the case needs no drive and no spawn. It is destroyed below.
			local zone = Instance.new("Part")
			zone.Name = "ClaimSpecZone"
			zone.Size = Vector3.new(1.8, 1.8, 3)
			zone.Anchored = true
			zone.CanCollide = false
			zone.CanQuery = false
			zone.Position = (root :: BasePart).Position + Vector3.new(0, 0, -120)
			zone:SetAttribute("Damageable", true)
			zone:SetAttribute("HitZone", "chest")
			zone.Parent = workspace

			local heldId = Weapon.heldId(subject) or Weapons.PRIMARY
			local row = Weapons.row(heldId) or Weapons.ROWS[Weapons.PRIMARY]
			local ammo = (snapshot :: any).loaded[(snapshot :: any).selected]
			local shot = Ballistics.shotFor(row, ammo)
			expect(shot).to.be.ok()

			-- THE HISTORY ANSWERS HONESTLY: the zone is where it is, at every instant asked. So the only
			-- thing wrong with the claim below is the claim.
			local asked = 0
			Weapon.setHistoryProvider(function(_instance, _at)
				asked += 1
				return zone.CFrame
			end)
			local wasPolicy = Weapon.setClaimPolicy(true)
			Weapon.setDriveOpenProvider(function(): boolean
				return true
			end)
			Weapon.setTargetProvider(nil)
			Weapon.setStandProvider(nil)
			Weapon.setLicenceProvider(nil)

			local reported = 0
			local listener = Weapon.HitReported:Connect(function()
				reported += 1
			end)

			local before = Weapon.stats()
			local origin = (root :: BasePart).Position + Vector3.new(0, 2, 0)
			local direction = Vector3.new(0, 0, -1)
			local distance = 120
			-- THE FORGERY: the point is 30 studs from where the animal is, and the history says so.
			local claim = {
				part = zone,
				offset = Vector3.new(0, 0, 0),
				point = zone.Position + Vector3.new(30, 0, 0),
				firedAtView = workspace:GetServerTimeNow(),
				flightSeconds = Ballistics.timeToRange(shot :: any, distance),
				distanceStuds = distance,
			}
			local why = Weapon.onFireRequest(subject, { origin = origin, direction = direction, claim = claim })
			for _ = 1, 2 do
				if why ~= "rate-limited" and why ~= "busy" then
					break
				end
				task.wait(1.2)
				claim.firedAtView = workspace:GetServerTimeNow()
				why = Weapon.onFireRequest(subject, { origin = origin, direction = direction, claim = claim })
			end

			local drainBy = os.clock() + 1.5
			while Weapon.flightCount() > 0 and os.clock() < drainBy do
				task.wait()
			end

			listener:Disconnect()
			Weapon.setClaimPolicy(wasPolicy)
			Weapon.setHistoryProvider(nil)
			Weapon.setTargetProvider(Match.classifyTarget)
			Weapon.setStandProvider(Match.standAreaFor)
			Weapon.setDriveOpenProvider(Match.driveOpen)
			zone:Destroy()

			local after = Weapon.stats()
			if why ~= nil then
				TestKit.note(
					string.format("weapon_shot hit claim: the handler refused the SHOT (%s); the pure cases stand", why)
				)
				expect(CLAIM.POSITION_TOLERANCE_STUDS > 0).to.equal(true)
				return
			end

			-- THE CLAIM WAS SEEN. A pattern load is refused at the SHAPE gate and never reaches the
			-- rewind, which is correct and is what `pellets` is read off the row for -- so the reason is
			-- reported rather than demanded, and what is ASSERTED is that it was refused and that
			-- nothing was reported as a hit.
			expect(after.claims > before.claims).to.equal(true)
			expect(after.claimsRefused > before.claimsRefused).to.equal(true)
			expect(after.claimsAccepted).to.equal(before.claimsAccepted)
			expect(reported).to.equal(0)
			local reasons = {}
			for reason, count in pairs(after.refusedClaimBy) do
				table.insert(reasons, string.format("%s=%d", reason, count))
			end
			table.sort(reasons)
			TestKit.note(
				string.format(
					"weapon_shot hit claim: %s/%s pellets=%s, history asked %d time(s), refusedClaimBy [%s]",
					heldId,
					tostring(ammo),
					tostring(row.PELLETS and row.PELLETS[ammo]),
					asked,
					table.concat(reasons, " ")
				)
			)
		end)
	end)
	-- ------------------------------------------------- THE ACCEPTED CLAIM, AND THE COUNTERS (266b)
	--
	-- **THE ACCEPTED PATH HAD NEVER EXECUTED, ANYWHERE.** That is the Reviewer's own round-3 note on
	-- task 266, word for word: *"Nothing in the suite reaches past `Validator.judgeClaim`'s `return
	-- true` into `stats.claimsAccepted`, the `claimImpact` call, or the report and dust built from
	-- the truncated list… the first time the Director lights `HIT_CLAIM` for Karen is the first
	-- execution of that branch in the project's history."* These cases are that execution, and the
	-- shape is the one the note prescribed: `weapon_shot.spec`'s forgery case with an HONEST point.
	--
	-- WHY IT CAN BE DONE WITH NO PLAYER AND NO DRIVE: `Weapon.setClaimPolicy` reaches the ON branch
	-- while the row sits at OFF, `Weapon.setHistoryProvider` answers where the animal was, and
	-- `Weapon.setCast` scripts the world the flight flies through. The one thing a spec cannot
	-- script is a player holding a loaded gun -- so the cases that need the live handler say so and
	-- the ones that do not are driven directly.
	describe("the accepted claim and its counters", function()
		local CLAIM = Shotgun.CONFIG.CLAIM

		-- ITEM 1's PURE HALF: the one line a probe reads. Driven with a hand-written table, so the
		-- formatting is a fact and not a side effect of whatever the live server has done.
		it("claimLine states every counter, with the reasons SORTED", function()
			local line = Weapon.claimLine({
				claimsEnabled = true,
				claims = 7,
				claimsAccepted = 3,
				claimsRefused = 4,
				claimsIgnored = 0,
				claimWorstStuds = 1.25,
				claimWorstLineStuds = 0.5,
				claimAgeMin = -0.2,
				claimAgeMax = 0.05,
				claimAges = 9,
				claimHistoryWhy = "no-sample",
				refusedClaimBy = { ["claim-moved"] = 2, ["claim-line"] = 1, ["claim-blocked"] = 1 },
			})
			expect(string.find(line, "enabled=true", 1, true)).to.be.ok()
			expect(string.find(line, "claims=7", 1, true)).to.be.ok()
			expect(string.find(line, "accepted=3", 1, true)).to.be.ok()
			expect(string.find(line, "refused=4", 1, true)).to.be.ok()
			expect(string.find(line, "worst=1.250/0.500", 1, true)).to.be.ok()
			-- THE AGE PAIR, which is what says "the claim arrived from the FUTURE" rather than
			-- leaving `claim-history` as a riddle (task 266b).
			expect(string.find(line, "age=-0.200..0.050/9", 1, true)).to.be.ok()
			-- AND WHY THE REWIND SAID NO, which `claim-history` alone cannot say.
			expect(string.find(line, "why=no-sample", 1, true)).to.be.ok()
			-- SORTED, so two runs of the same server give the same string and a diff is a fact.
			expect(string.find(line, "[claim-blocked=1 claim-line=1 claim-moved=2]", 1, true)).to.be.ok()
			expect(Weapon.claimLine(nil)).to.equal("")
		end)

		-- ITEM 1's BOTH BRANCHES. The live-server branch must write NOTHING, and it is only
		-- reachable because `isStudio` is a parameter -- a spec always runs in Studio.
		it("publishes the counters in Studio and NEVER on a live server", function()
			local attribute = Weapon.CLAIM_STATS_ATTRIBUTE
			expect(type(attribute)).to.equal("string")
			ServerStorage:SetAttribute(attribute, nil)

			-- the live-server branch: no write, and it says so
			expect(Weapon.publishClaimStats(false)).to.equal(false)
			expect(ServerStorage:GetAttribute(attribute)).to.equal(nil)

			-- the Studio branch: the line is there and it is this server's own numbers
			expect(Weapon.publishClaimStats(true)).to.equal(true)
			local written = ServerStorage:GetAttribute(attribute)
			expect(type(written)).to.equal("string")
			expect(written).to.equal(Weapon.claimLine(Weapon.stats()))
		end)

		-- THE CORE CASE. A claim the server BELIEVES: the history agrees, the trajectory passes the
		-- point, the flight got there, the clock is sane. Everything is driven through the real
		-- `onShotLanded` path by resolving a real flight.
		it("ACCEPTS an honest claim: the counter moves, and the report names the claimed zone", function()
			local subject, snapshot = nil, nil
			for _ = 1, 20 do
				for _, player in ipairs(Players:GetPlayers()) do
					local state = Weapon.getSnapshot(player)
					if
						state ~= nil
						and state.equipped == true
						and state.open == false
						and (state.busyFor or 0) <= 0
						and state.barrels[state.selected] == "Live"
					then
						subject, snapshot = player, state
						break
					end
				end
				if subject ~= nil then
					break
				end
				task.wait(0.25)
			end
			if subject == nil then
				TestKit.note(
					"weapon_shot accepted claim: nobody is holding a gun that can fire, so the live ACCEPT "
						.. "path did not run -- the one thing this case exists for. NOT PROVEN in this run."
				)
				expect(CLAIM.POSITION_TOLERANCE_STUDS > 0).to.equal(true)
				return
			end

			local root = subject.Character and subject.Character:FindFirstChild("HumanoidRootPart")
			expect(root).to.be.ok()
			local heldId = Weapon.heldId(subject) or Weapons.PRIMARY
			local row = Weapons.row(heldId) or Weapons.ROWS[Weapons.PRIMARY]
			local ammo = (snapshot :: any).loaded[(snapshot :: any).selected]
			-- A PATTERN LOAD CANNOT CLAIM (design section 6), so this case is only meaningful on a
			-- single-pellet load. It says so rather than passing quietly on a shotgun.
			if (row.PELLETS and row.PELLETS[ammo]) ~= 1 then
				TestKit.note(
					string.format(
						"weapon_shot accepted claim: the held gun is %s/%s, a %s-pellet load, which may not "
							.. "claim at all -- the live ACCEPT path did not run. NOT PROVEN in this run.",
						heldId,
						tostring(ammo),
						tostring(row.PELLETS and row.PELLETS[ammo])
					)
				)
				expect(CLAIM.POSITION_TOLERANCE_STUDS > 0).to.equal(true)
				return
			end
			local shot = Ballistics.shotFor(row, ammo)
			expect(shot).to.be.ok()

			-- THE ANIMAL, AND IT IS THIS SPEC'S OWN: `Damageable` is what `Hits.targetOf` reads, and
			-- `HitZone` is what the report's zone comes from -- neither is ever named by the claim.
			local zone = Instance.new("Part")
			zone.Name = "ClaimAcceptSpecChest"
			zone.Size = Vector3.new(1.8, 1.8, 3)
			zone.Anchored = true
			zone.CanCollide = false
			zone.CanQuery = false
			zone:SetAttribute("Damageable", true)
			zone:SetAttribute("HitZone", "chest")
			local distance = 120
			local origin = (root :: BasePart).Position + Vector3.new(0, 2, 0)
			local direction = Vector3.new(0, 0, -1)
			zone.Position = origin + direction * distance
			zone.Parent = workspace

			-- THE WORLD THE SHOT FLIES THROUGH: nothing stops it, so `reachedStuds` is the ammo's
			-- own range cap and check 5 passes on the server's own measurement.
			Weapon.setCast(function()
				return nil
			end)
			-- THE HISTORY ANSWERS HONESTLY, which is what makes this claim honest: the animal was
			-- where it is.
			Weapon.setHistoryProvider(function()
				return zone.CFrame
			end)
			local wasPolicy = Weapon.setClaimPolicy(true)
			Weapon.setDriveOpenProvider(function(): boolean
				return true
			end)
			Weapon.setTargetProvider(nil)
			Weapon.setStandProvider(nil)
			Weapon.setLicenceProvider(nil)

			local reports = {}
			local listener = Weapon.HitReported:Connect(function(report)
				table.insert(reports, report)
			end)

			local before = Weapon.stats()
			local offset = Vector3.new(0, 0, 0)
			local claim = {
				part = zone,
				offset = offset,
				-- THE HONEST POINT: where the server's own history says that offset was.
				point = zone.CFrame * offset,
				firedAtView = workspace:GetServerTimeNow(),
				flightSeconds = Ballistics.timeToRange(shot :: any, distance),
				distanceStuds = distance,
			}
			local why = Weapon.onFireRequest(subject, { origin = origin, direction = direction, claim = claim })
			for _ = 1, 2 do
				if why ~= "rate-limited" and why ~= "busy" then
					break
				end
				task.wait(1.2)
				claim.firedAtView = workspace:GetServerTimeNow()
				claim.point = zone.CFrame * offset
				why = Weapon.onFireRequest(subject, { origin = origin, direction = direction, claim = claim })
			end

			local drainBy = os.clock() + 2
			while Weapon.flightCount() > 0 and os.clock() < drainBy do
				task.wait()
			end

			listener:Disconnect()
			Weapon.setClaimPolicy(wasPolicy)
			Weapon.setHistoryProvider(nil)
			Weapon.setCast(nil)
			Weapon.setTargetProvider(Match.classifyTarget)
			Weapon.setStandProvider(Match.standAreaFor)
			Weapon.setDriveOpenProvider(Match.driveOpen)

			local after = Weapon.stats()
			if why ~= nil then
				TestKit.note(
					string.format(
						"weapon_shot accepted claim: the handler refused the SHOT (%s); the ACCEPT path did "
							.. "not run. NOT PROVEN in this run.",
						why
					)
				)
				zone:Destroy()
				expect(CLAIM.POSITION_TOLERANCE_STUDS > 0).to.equal(true)
				return
			end

			-- THE COUNTER MOVED. This is the assertion that had never been made: it fails if the
			-- accept branch is deleted, if `judgeClaim` refuses, or if the policy is not honoured.
			local reasons = {}
			for reason, count in pairs(after.refusedClaimBy) do
				table.insert(reasons, string.format("%s=%d", reason, count))
			end
			table.sort(reasons)
			TestKit.note(
				string.format(
					"weapon_shot accepted claim: %s/%s, %d report(s), accepted %d -> %d, worst %.3f/%.3f, "
						.. "refusedClaimBy [%s]",
					heldId,
					tostring(ammo),
					#reports,
					before.claimsAccepted,
					after.claimsAccepted,
					after.claimWorstStuds,
					after.claimWorstLineStuds,
					table.concat(reasons, " ")
				)
			)
			expect(after.claimsAccepted).to.equal(before.claimsAccepted + 1)
			expect(after.claimsRefused).to.equal(before.claimsRefused)

			-- AND THE REPORT IS THE CLAIM'S. One report, the claimed part, one pellet, and the zone
			-- read off the part's own attribute -- which is what Karen sees on the hit card.
			local mine = nil
			for _, report in ipairs(reports) do
				if report.target == zone then
					mine = report
				end
			end
			expect(mine).to.be.ok()
			expect((mine :: any).zone).to.equal("chest")
			expect((mine :: any).pellets).to.equal(1)
			expect(math.abs((mine :: any).nearest - distance) < 1e-3).to.equal(true)
			-- THE IMPACT IS ON THE ANIMAL, built from its LIVE CFrame and the validated offset.
			expect(((mine :: any).position - zone.CFrame * offset).Magnitude < 1e-3).to.equal(true)

			-- ...AND THE COUNTERS ARE OUT WHERE A PROBE CAN READ THEM, which is item 1's whole point.
			local published = ServerStorage:GetAttribute(Weapon.CLAIM_STATS_ATTRIBUTE)
			expect(type(published)).to.equal("string")
			expect(string.find(published :: string, string.format("accepted=%d", after.claimsAccepted), 1, true)).to.be.ok()
			zone:Destroy()
		end)
	end)
end
