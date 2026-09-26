--!strict
-- Feature flags, server side: the pure resolver, the declaration tripwire, the production branch of
-- the Studio override, and the one migrated flag's wiring.
--
-- EVERY CASE BUILDS ITS OWN TABLES. Nothing is installed, so nothing needs restoring and there is no
-- beforeEach/afterEach: the audit-004 F1 shape -- a spec that installs a policy and leaks it into the
-- next spec (Weapon.setArmingPolicy in zz_drive_boundary.spec) -- cannot occur here.
--
-- Design: docs/design/feature-flags.md (section 13.1)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
local Match = require(ServerScriptService:WaitForChild("Match"))
local Penalty = require(ServerScriptService:WaitForChild("Match"):WaitForChild("Penalty"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

return function()
	describe("resolve", function()
		it("returns the defaults, frozen, as a new table, and does not touch the input", function()
			local defaults = { A = true, B = false }
			local out, rejected = Flags.resolve(defaults, nil)
			expect(out).never.to.equal(defaults) -- a NEW table, not the argument
			expect(out.A).to.equal(true)
			expect(out.B).to.equal(false)
			expect(#rejected).to.equal(0)
			expect(table.isfrozen(out)).to.equal(true)
			expect(function()
				(out :: any).A = false
			end).to.throw()
			-- The input is untouched, and is still writable: resolve froze its OWN result only.
			expect(defaults.A).to.equal(true)
			expect(defaults.B).to.equal(false)
		end)

		it("takes an override BOTH ways", function()
			local offByDefault = { A = false }
			local onByDefault = { A = true }
			expect((Flags.resolve(offByDefault, { A = true })).A).to.equal(true)
			expect((Flags.resolve(onByDefault, { A = false })).A).to.equal(false)
			-- and neither defaults table moved
			expect(offByDefault.A).to.equal(false)
			expect(onByDefault.A).to.equal(true)
		end)

		it("ignores an override for a name that is not declared, and says so", function()
			local out, rejected = Flags.resolve({ A = true }, { NOPE = true })
			expect(out.NOPE).to.equal(nil) -- it does NOT create the key
			expect(out.A).to.equal(true)
			expect(#rejected).to.equal(1)
			expect(string.find(rejected[1], "NOPE") ~= nil).to.equal(true)
		end)

		it("rejects a non-boolean override and never coerces it", function()
			for _, value in ipairs({ "true", 1, 0, {} } :: { any }) do
				local out, rejected = Flags.resolve({ A = false }, { A = value })
				expect(out.A).to.equal(false) -- NOT coerced to true
				expect(#rejected).to.equal(1)
				expect(string.find(rejected[1], "not a boolean") ~= nil).to.equal(true)
			end
		end)

		it("names every rejected override in a stable order", function()
			local _, rejected = Flags.resolve({ A = true }, { ZZZ = true, AAA = true })
			expect(#rejected).to.equal(2)
			expect(string.find(rejected[1], "AAA") ~= nil).to.equal(true)
			expect(string.find(rejected[2], "ZZZ") ~= nil).to.equal(true)
		end)
	end)

	describe("digest", function()
		it("is sorted by name and stable", function()
			expect(Flags.digest({ B = false, A = true })).to.equal("A=1|B=0")
			expect(Flags.digest({ A = true, B = false })).to.equal("A=1|B=0")
			expect(Flags.digest({})).to.equal("")
		end)

		it("changes when any value changes", function()
			expect(Flags.digest({ A = true })).never.to.equal(Flags.digest({ A = false }))
		end)
	end)

	describe("isOn", function()
		it("raises on a name that is not declared, rather than answering false", function()
			-- A typo that read as `false` is a dark path that silently never runs and a spec that
			-- passes for the wrong reason (design section 4.1).
			expect(function()
				Flags.isOn("NOT_A_FLAG")
			end).to.throw()
		end)

		it("answers the resolved value for a declared one", function()
			expect(type(Flags.isOn("TIE_UNTIL_DRIVE_END"))).to.equal("boolean")
			expect(Flags.isOn("TIE_UNTIL_DRIVE_END")).to.equal(Flags.all().TIE_UNTIL_DRIVE_END)
		end)
	end)

	describe("the declarations", function()
		it("are deep-frozen, not merely shallow-frozen", function()
			expect(function()
				(Flags.DEFAULTS :: any).NEW_ONE = { default = false }
			end).to.throw()
			-- DEEP: the Task 23a(b) defect was that table.freeze is shallow, so a row's own field
			-- stayed writable while the table looked frozen.
			expect(function()
				(Flags.DEFAULTS.TIE_UNTIL_DRIVE_END :: any).default = false
			end).to.throw()
		end)

		it("have no fault today -- this is the rot tripwire", function()
			-- An `expires` in the past fails HERE, which fails the harness, which blocks the merge
			-- gate. The fix is one of three: retire the flag, flip its default, or move the date
			-- with a reason in `why` (design section 11).
			local today = os.date("!%Y-%m-%d") :: string
			local problems = Flags.problems(Flags.DEFAULTS, today)
			TestKit.note(string.format("flags: %d declared, today %s, %d problem(s)", #(function()
				local n = {}
				for name in pairs(Flags.DEFAULTS) do
					table.insert(n, name)
				end
				return n
			end)(), today, #problems))
			expect(#problems).to.equal(0)
			if #problems > 0 then
				error(table.concat(problems, " | "))
			end
		end)

		it("problems() catches each fault it is there to catch", function()
			-- Otherwise the case above proves only that problems() can return an empty list.
			local good = {
				OK_ONE = {
					default = false,
					owner = "o",
					born = "b",
					expires = "2999-01-01",
					why = "w",
				},
			}
			expect(#Flags.problems(good :: any, "2026-09-26")).to.equal(0)

			local expired = table.clone(good)
			expired.OK_ONE = table.clone(good.OK_ONE)
			expired.OK_ONE.expires = "2026-09-25"
			local said = Flags.problems(expired :: any, "2026-09-26")
			expect(#said).to.equal(1)
			expect(string.find(said[1], "EXPIRED") ~= nil).to.equal(true)

			-- a bad name
			local badName = { ["lower_case"] = good.OK_ONE }
			expect(#Flags.problems(badName :: any, "2026-09-26") > 0).to.equal(true)

			-- a non-boolean default. The row is built and edited through a local, never as a
			-- statement beginning with "(": Luau reads `local x = {...}` followed by a line that
			-- opens with a parenthesis as a call on the table, and StyLua removes the guarding
			-- semicolon that would have said otherwise.
			local badRow: any = table.clone(good.OK_ONE)
			badRow.default = "yes"
			expect(#Flags.problems({ OK_ONE = badRow } :: any, "2026-09-26") > 0).to.equal(true)

			-- a missing field
			local missingRow: any = table.clone(good.OK_ONE)
			missingRow.why = nil
			expect(#Flags.problems({ OK_ONE = missingRow } :: any, "2026-09-26") > 0).to.equal(true)

			-- more than MAX_FLAGS
			local many: { [string]: any } = {}
			for index = 1, Flags.MAX_FLAGS + 1 do
				many["F" .. index] = good.OK_ONE
			end
			local tooMany = Flags.problems(many :: any, "2026-09-26")
			expect(#tooMany > 0).to.equal(true)
			expect(string.find(tooMany[1], "MAX_FLAGS") ~= nil).to.equal(true)
		end)
	end)

	describe("readOverrides", function()
		it("returns nothing when isStudio is false, EVEN WITH an attribute present", function()
			-- THE PRODUCTION BRANCH, proved from inside Studio, where RunService:IsStudio() is
			-- always true and no harness run can make it false. The test is a parameter precisely so
			-- this branch is not untestable (design section 6, guard 1).
			--
			-- On a Configuration this spec creates and destroys: NEVER on ServerStorage itself.
			-- Nothing may leave an override behind on the service the harness guards.
			local host = Instance.new("Configuration")
			host.Name = "ZZ_FlagsSpecHost"
			host:SetAttribute(Flags.OVERRIDE_PREFIX .. "ZZ_SPEC_ONLY", true)
			host:SetAttribute("NotAFlag", true)

			expect(next(Flags.readOverrides(host, false))).to.equal(nil)
			expect(next(Flags.readOverrides(nil, true))).to.equal(nil)

			local seen = Flags.readOverrides(host, true)
			expect(seen.ZZ_SPEC_ONLY).to.equal(true)
			expect(seen.NotAFlag).to.equal(nil) -- only the DHFlag_ prefix is an override
			host:Destroy()
		end)
	end)

	describe("this server process", function()
		it("resolved from the defaults, with no override set", function()
			-- The spec-level mirror of the harness guard: it catches an override the harness check
			-- somehow missed, from inside the run rather than before it.
			expect(Flags.source()).to.equal("defaults")
			expect(next(Flags.readOverrides(ServerStorage, true))).to.equal(nil)
			expect(Flags.digest(Flags.all())).to.equal(Flags.digest(Flags.defaults()))
		end)

		it("resolves inside the 1 ms budget", function()
			-- all() is memoised, so this measures the repeat cost; the first resolution is measured
			-- by Flags itself, which warns over budget (design section 12).
			local began = os.clock()
			for _ = 1, 100 do
				Flags.all()
			end
			local per = (os.clock() - began) * 1000 / 100
			TestKit.note(string.format("flags: %.4f ms per all() (budget 1 ms)", per))
			expect(per < 1).to.equal(true)
		end)

		it("published a mirror whose attributes match the digest, with Digest written last", function()
			local state = (ReplicatedStorage:WaitForChild("Flags") :: Instance):WaitForChild("State")
			local names = {}
			local count = 0
			for name, value in pairs(state:GetAttributes()) do
				count += 1
				if name ~= Flags.DIGEST_ATTRIBUTE and name ~= Flags.SOURCE_ATTRIBUTE then
					names[name] = value
				end
			end
			expect(state:GetAttribute(Flags.DIGEST_ATTRIBUTE)).to.equal(Flags.digest(Flags.all()))
			expect(Flags.SOURCES[state:GetAttribute(Flags.SOURCE_ATTRIBUTE)]).to.equal(true)
			expect(Flags.digest(names)).to.equal(Flags.digest(Flags.all()))
			-- flags + Digest + Source, and nothing else on the instance.
			local flagCount = 0
			for _ in pairs(Flags.all()) do
				flagCount += 1
			end
			expect(count).to.equal(flagCount + 2)
			TestKit.note(
				string.format(
					"flags: mirror carries %d attribute(s), source=%s",
					count,
					tostring(state:GetAttribute(Flags.SOURCE_ATTRIBUTE))
				)
			)
		end)

		it("has no writer, and publishing twice changes nothing", function()
			expect((Flags :: any).setForTests).to.equal(nil)
			expect((Flags :: any).override).to.equal(nil)
			expect((Flags :: any).set).to.equal(nil)
			local state = (ReplicatedStorage:WaitForChild("Flags") :: Instance):WaitForChild("State")
			local before = state:GetAttribute(Flags.DIGEST_ATTRIBUTE)
			Flags.publish(Flags.all(), Flags.source())
			expect(state:GetAttribute(Flags.DIGEST_ATTRIBUTE)).to.equal(before)
		end)

		it("refuses to publish a source that is not declared", function()
			expect(function()
				Flags.publish(Flags.all(), "whatever-i-like")
			end).to.throw()
		end)
	end)

	describe("the second flag: BOAR_SOUNDERS", function()
		it("is what Match.CONFIG carries -- one read, at the owner's boundary", function()
			expect(Match.CONFIG.SOUNDER.ENABLED).to.equal(Flags.isOn("BOAR_SOUNDERS"))
		end)

		it("changes the RELEASE in both states, through the parameter", function()
			-- Section 13.3 again: the release shape is reachable by parameter, so both states are
			-- asserted here while the flag itself sits at one of them. Off it, every size is 1.
			local state = { seed = 1, driveNumber = 1, boarsReleased = 0, soundersReleased = 0 }
			local sounder = Match.CONFIG.SOUNDER
			local off = {
				BOARS_PER_DRIVE = 6,
				RELEASE_INTERVAL_SECONDS = 90,
				SOUNDER = { ENABLED = false, MAX_SIZE = sounder.MAX_SIZE, SIZE_WEIGHTS = sounder.SIZE_WEIGHTS },
			}
			local on = {
				BOARS_PER_DRIVE = 6,
				RELEASE_INTERVAL_SECONDS = 90,
				SOUNDER = {
					ENABLED = true,
					MAX_SIZE = sounder.MAX_SIZE,
					SIZE_WEIGHTS = sounder.SIZE_WEIGHTS,
					EXPECTED_SIZE = sounder.EXPECTED_SIZE,
					TAIL_SECONDS = sounder.TAIL_SECONDS,
					GAP_MIN_SECONDS = sounder.GAP_MIN_SECONDS,
					GAP_MAX_SECONDS = sounder.GAP_MAX_SECONDS,
				},
			}
			expect(Match.Phase.sounderSize(state :: any, off)).to.equal(1)
			local sizes = {}
			for index = 0, 9 do
				local drawn = { seed = 1, driveNumber = 1, boarsReleased = 0, soundersReleased = index }
				table.insert(sizes, Match.Phase.sounderSize(drawn :: any, on))
			end
			local grouped = false
			for _, size in ipairs(sizes) do
				expect(size >= 1 and size <= sounder.MAX_SIZE).to.equal(true)
				grouped = grouped or size > 1
			end
			expect(grouped).to.equal(true) -- ON really does draw groups, or the flag switches nothing
			-- and the live config is untouched by either call
			expect(Match.CONFIG.SOUNDER.ENABLED).to.equal(Flags.isOn("BOAR_SOUNDERS"))
		end)
	end)

	describe("the worked example: TIE_UNTIL_DRIVE_END", function()
		it("is what Match.CONFIG carries -- one source of truth, read at the boundary", function()
			expect(Match.CONFIG.TIE_UNTIL_DRIVE_END).to.equal(Flags.isOn("TIE_UNTIL_DRIVE_END"))
		end)

		it("changes the BEHAVIOUR in both states, through the parameter", function()
			-- Section 13.3: a flagged path must be reachable by parameter, not only by the live
			-- flag, so both states are testable while the flag itself sits at one of them.
			local tiedAt, now = 0, 999
			expect(Penalty.expired(tiedAt, now, { TIE_UNTIL_DRIVE_END = false, TIE_SECONDS = 60 })).to.equal(true)
			expect(Penalty.expired(tiedAt, now, { TIE_UNTIL_DRIVE_END = true, TIE_SECONDS = 60 })).to.equal(false)
			-- and the live config is untouched by either call
			expect(Match.CONFIG.TIE_UNTIL_DRIVE_END).to.equal(Flags.isOn("TIE_UNTIL_DRIVE_END"))
		end)
	end)
end
