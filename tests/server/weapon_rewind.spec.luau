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
		end)

		it("takes the NEAREST candidate and caps the list at maxTargets", function()
			local seen = 0
			local castOnly = function(_root, origin, _segment)
				seen += 1
				return {
					instance = Instance.new("Part"),
					position = origin,
					normal = Vector3.new(0, 1, 0),
					distance = 10 - seen,
					material = Enum.Material.Plastic,
				}
			end
			local list = { candidate(1), candidate(2), candidate(3) }
			local hit = Rewind.impact(Vector3.zero, Vector3.new(0, 0, 4), list, castOnly, 2)
			expect(seen).to.equal(2)
			expect((hit :: any).distance).to.be.near(8, 1e-4)
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
			expect(Rewind.nearer(impact(4), impact(4)).distance).to.equal(4)
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
			Weapon.setRewindPolicy(was)
		end)

		it("is 0 when the policy says off -- the flag's OFF state is today's game", function()
			local was = Weapon.setRewindPolicy(false)
			expect(Weapon.rewindFor(nil, 0.05, CONFIG)).to.equal(0)
			Weapon.setRewindPolicy(was)
		end)
	end)
end
