-- Task 305: the server tests an animal WHERE THE SHOOTER DREW IT.
-- Note: docs/research/2026-10-28-lag-compensation.md
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
	local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
	local Rewind = require(ServerScriptService:WaitForChild("Weapon"):WaitForChild("Rewind"))

	local CONFIG = Shotgun.CONFIG

	describe("Rewind.impact", function()
		-- A boar that was 5 studs back along X when the shooter drew it. The ray is aimed at the
		-- PAST position; with no rewind it finds nothing, with the rewind it finds the animal.
		local function candidate(backStuds: number)
			local root = Instance.new("Part")
			root.Name = "Trunk"
			return {
				root = root,
				present = CFrame.new(0, 0, 0),
				past = CFrame.new(-backStuds, 0, 0),
			}
		end

		it("moves the ray by MINUS the animal's displacement and the impact back", function()
			local asked = {}
			local castOnly = function(_root, origin, segment)
				table.insert(asked, origin)
				-- The animal's present body sits at the origin; answer a hit 2 studs along.
				return {
					instance = Instance.new("Part"),
					position = origin + segment.Unit * 2,
					normal = Vector3.new(0, 1, 0),
					distance = 2,
					material = Enum.Material.Plastic,
				}
			end
			local hit = Rewind.impact(Vector3.new(0, 0, -10), Vector3.new(0, 0, 4), { candidate(5) }, castOnly)
			expect(hit).to.be.ok()
			-- the ray was asked at origin MINUS the shift (past - present = -5 on X), so +5
			expect(asked[1].X).to.be.near(5, 1e-4)
			-- ...and the answer came back in the PAST frame, 5 studs the other way
			expect((hit :: any).position.X).to.be.near(0, 1e-4)
			expect((hit :: any).distance).to.be.near(2, 1e-4)
			-- ...AND IT SAYS WHICH FRAME THAT IS (task 308): the PAST POSITION with the PRESENT
			-- ROTATION, because translation is all this does. `HitLog` divides the card's dots down
			-- by it, so a stamp that is missing or present-tense puts a nose shot on the rump.
			local frame = (hit :: any).frame
			expect(typeof(frame)).to.equal("CFrame")
			expect((frame :: CFrame).Position.X).to.be.near(-5, 1e-4)
			expect((frame :: CFrame).LookVector.Z).to.be.near(-1, 1e-4)
		end)

		it("takes the NEAREST candidate and caps the list at maxTargets", function()
			local seen = 0
			local castOnly = function(_root, origin, _segment)
				seen += 1
				return {
					instance = Instance.new("Part"),
					position = origin,
					normal = Vector3.new(0, 1, 0),
					-- **RISING**, so the nearest answer is the FIRST one asked and not the last
					-- (round 2 finding 1). With a falling sequence the last call was also the
					-- nearest, so last-wins and nearest-wins gave one number and the assertion
					-- could not fail. `seen` is incremented ABOVE, so the answers are 6 then 7
					-- under a cap of 2: nearest-wins gives 6 and last-wins gives 7.
					distance = 5 + seen,
					material = Enum.Material.Plastic,
				}
			end
			local list = { candidate(1), candidate(2), candidate(3) }
			local hit = Rewind.impact(Vector3.zero, Vector3.new(0, 0, 4), list, castOnly, 2)
			expect(seen).to.equal(2)
			expect((hit :: any).distance).to.be.near(6, 1e-4)
		end)

		it("is nil for no candidate, and refuses a candidate with no history", function()
			local castOnly = function(_root, origin, _segment)
				return { instance = Instance.new("Part"), position = origin, normal = Vector3.yAxis, distance = 1 }
			end
			expect(Rewind.impact(Vector3.zero, Vector3.new(0, 0, 1), {}, castOnly)).to.equal(nil)
			local broken = { root = Instance.new("Part"), present = CFrame.new(), past = nil :: any }
			expect(Rewind.impact(Vector3.zero, Vector3.new(0, 0, 1), { broken :: any }, castOnly)).to.equal(nil)
		end)
	end)

	describe("Rewind.nearer", function()
		local function impact(d: number)
			return { instance = Instance.new("Part"), position = Vector3.zero, normal = Vector3.yAxis, distance = d }
		end
		it("gives the nearer of the two, and cover wins a tie", function()
			expect(Rewind.nearer(impact(5), impact(3)).distance).to.equal(3)
			expect(Rewind.nearer(impact(3), impact(5)).distance).to.equal(3)
			-- IDENTITY, not the distance: two impacts 4 studs out read 4 whichever side wins, so
			-- `<` could become `<=` and the assertion would still pass (round 1 finding 4).
			local tieStatic, tieRewound = impact(4), impact(4)
			expect(Rewind.nearer(tieStatic, tieRewound)).to.equal(tieStatic)
			expect(Rewind.nearer(nil, impact(7)).distance).to.equal(7)
			expect(Rewind.nearer(impact(7), nil).distance).to.equal(7)
			expect(Rewind.nearer(nil, nil)).to.equal(nil)
		end)
	end)

	describe("Weapon.rewindFor", function()
		it("is the MEASURED base plus the ping, capped, and 0 for a bad ping", function()
			local was = Weapon.setRewindPolicy(true)
			expect(Weapon.rewindFor(nil, 0, CONFIG)).to.be.near(CONFIG.FLIGHT_REWIND_BASE_SECONDS, 1e-6)
			expect(Weapon.rewindFor(nil, -1, CONFIG)).to.be.near(CONFIG.FLIGHT_REWIND_BASE_SECONDS, 1e-6)
			expect(Weapon.rewindFor(nil, 0 / 0, CONFIG)).to.be.near(CONFIG.FLIGHT_REWIND_BASE_SECONDS, 1e-6)
			expect(Weapon.rewindFor(nil, 0.05, CONFIG)).to.be.near(
				CONFIG.FLIGHT_REWIND_BASE_SECONDS + 0.05 * CONFIG.FLIGHT_CATCHUP_PING_FACTOR,
				1e-6
			)
			-- the ring's own span is the ceiling
			expect(Weapon.rewindFor(nil, 10, CONFIG)).to.be.near(CONFIG.CLAIM.VIEW_LAG_MAX_SECONDS, 1e-6)
			-- **THE nil-PING BRANCH, which is the one the game itself takes** (round 2 finding 2:
			-- `onFireRequest` calls `Weapon.rewindFor(player, nil, CONFIG)`). A nil player makes
			-- the `pcall` fail, and a failed ping must contribute ZERO rather than a guess.
			expect(Weapon.rewindFor(nil, nil, CONFIG)).to.be.near(CONFIG.FLIGHT_REWIND_BASE_SECONDS, 1e-6)
			Weapon.setRewindPolicy(was)
		end)

		it("is 0 when the policy says off -- the flag's OFF state is today's game", function()
			local was = Weapon.setRewindPolicy(false)
			expect(Weapon.rewindFor(nil, 0.05, CONFIG)).to.equal(0)
			Weapon.setRewindPolicy(was)
		end)
	end)

	-- ============================================================ ROUND 1 FINDING 3
	-- THE FUNCTION THAT CHANGES THE GAME, driven through its three seams with no world. Delete
	-- `Weapon.castWithRewind` and these cases go red, which is what round 1 said this file could
	-- not claim.
	-- TASK 305b: the rewind is measured from the TRIGGER, not from the cast's own wall clock.
	describe("Flight.advance's rewind anchor", function()
		local Flight = require(ServerScriptService:WaitForChild("Weapon"):WaitForChild("Flight"))

		local function fire(now: number?): number?
			local flight = Flight.new(CONFIG)
			local ballistic = { v0 = 1000, k = 0, zeroStuds = 100, gravityScale = 0 }
			local seen: number? = nil
			local shot = {
				shooter = nil :: any,
				shooterUserId = 1,
				ammo = "slug",
				muzzle = Vector3.zero,
				ignore = {},
				rangeStuds = 500,
				firedAt = 0,
				rewindSeconds = 0.18,
				-- the trigger, 0.05 s before the cast below
				firedAtServer = 100.0,
			}
			flight:launch(shot :: any, { Vector3.new(0, 0, -1) }, ballistic :: any)
			flight:advance(1 / 60, function(_o, _d, _i, rewind)
				seen = seen or rewind
				return nil
			end, now)
			return seen
		end

		it("adds the slip between the trigger and the cast", function()
			-- 0.05 s of wall clock has passed and the pellet has flown none of it yet, so the
			-- whole 0.05 s is slip the shooter must not be charged for.
			expect(fire(100.05)).to.be.near(0.23, 1e-6)
		end)

		it("is exactly today's flight with no clock", function()
			expect(fire(nil)).to.be.near(0.18, 1e-6)
		end)

		it("cannot hand out more than the ring can answer", function()
			expect(fire(1000)).to.be.near(CONFIG.CLAIM.VIEW_LAG_MAX_SECONDS, 1e-6)
		end)
	end)

	describe("Weapon.castWithRewind", function()
		-- An animal 6 studs further along +X now than when the shooter drew it. Its body is a
		-- 2-stud box, so a ray aimed at the DRAWN position misses the present one entirely.
		local DRAWN = Vector3.new(0, 0, 0)
		local PRESENT = Vector3.new(6, 0, 0)

		local function wire(hasHistory: boolean)
			local root = Instance.new("Part")
			root.Name = "Trunk"
			root.Size = Vector3.new(2, 2, 2)
			root.CFrame = CFrame.new(PRESENT)
			root:SetAttribute("Damageable", true)
			local staticAsked = {}
			Weapon.setRewindWorld(function(_origin, _segment, _pad, ignore, _rootOf, _max)
				-- the candidate finder: this animal is always near the segment
				local excluded = false
				for _, inst in ipairs(ignore) do
					if inst == root then
						excluded = true
					end
				end
				if excluded then
					return {}
				end
				return { root }
			end, function(asked, origin, segment)
				-- the one-instance cast: the box sits at PRESENT, in the ray's own frame
				if asked ~= root then
					return nil
				end
				local toBox = PRESENT - origin
				local along = toBox:Dot(segment.Unit)
				if along < 0 or along > segment.Magnitude then
					return nil
				end
				local miss = (origin + segment.Unit * along - PRESENT).Magnitude
				if miss > 1 then
					return nil
				end
				return {
					instance = root,
					position = origin + segment.Unit * along,
					normal = Vector3.yAxis,
					distance = along,
				}
			end)
			Weapon.setCast(function(_origin, _direction, ignore)
				table.insert(staticAsked, #ignore)
				return nil -- nothing static on this line: no tree, no ground
			end)
			Weapon.setHistoryProvider(function(instance, _at)
				if instance ~= root or not hasHistory then
					return nil
				end
				return CFrame.new(DRAWN)
			end)
			return root, staticAsked
		end

		local function unwire()
			Weapon.setRewindWorld(nil, nil)
			Weapon.setCast(nil)
			Weapon.setHistoryProvider(nil)
			Weapon.addHistoryProvider(nil)
		end

		it("HITS the animal where the shooter DREW it, and MISSES the server's present copy", function()
			local root = wire(true)
			-- aimed at the DRAWN position
			local drawnHit = Weapon.castWithRewind(Vector3.new(0, 0, -20), Vector3.new(0, 0, 40), {}, 0.18)
			expect(drawnHit).to.be.ok()
			expect((drawnHit :: any).instance).to.equal(root)
			-- the SAME aim with no rewind finds nothing: that is the miss Karen reported
			local noRewind = Weapon.castWithRewind(Vector3.new(0, 0, -20), Vector3.new(0, 0, 40), {}, 0)
			expect(noRewind).to.equal(nil)
			-- ...and aiming at the PRESENT copy with the rewind on is the miss, which is the
			-- "extra lead" being gone rather than merely moved.
			local presentAim = Weapon.castWithRewind(PRESENT + Vector3.new(0, 0, -20), Vector3.new(0, 0, 40), {}, 0.18)
			expect(presentAim).to.equal(nil)
			unwire()
		end)

		it("a SECOND runtime's history is asked when the first says 'not mine'", function()
			-- THE LOBBY HAS TWO RUNTIMES (round 1 finding 1): the drive's in the one replaceable
			-- slot, the range's added beside it. With only the first wired this animal has no
			-- history and is not rewound; adding the second makes the same aim hit.
			local root = wire(false)
			local aimed = Vector3.new(0, 0, -20)
			expect(Weapon.castWithRewind(aimed, Vector3.new(0, 0, 40), {}, 0.18)).to.equal(nil)
			Weapon.addHistoryProvider(function(instance, _at)
				return if instance == root then CFrame.new(DRAWN) else nil
			end)
			local hit = Weapon.castWithRewind(aimed, Vector3.new(0, 0, 40), {}, 0.18)
			expect(hit).to.be.ok()
			expect((hit :: any).instance).to.equal(root)
			unwire()
		end)

		it("an animal the provider cannot answer for is STILL hittable by the static pass", function()
			-- ROUND 1 FINDING 1. With no history the root must not be excluded from the static
			-- pass: the static cast is asked with the caller's OWN ignore list, length 0.
			local _, staticAsked = wire(false)
			local hit = Weapon.castWithRewind(Vector3.new(0, 0, -20), Vector3.new(0, 0, 40), {}, 0.18)
			expect(hit).to.equal(nil) -- this spec's static world answers nothing
			expect(#staticAsked >= 1).to.equal(true)
			for _, count in ipairs(staticAsked) do
				expect(count).to.equal(0)
			end
			unwire()
		end)
	end)
end
