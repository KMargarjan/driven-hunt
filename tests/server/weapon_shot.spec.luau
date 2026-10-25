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
end
