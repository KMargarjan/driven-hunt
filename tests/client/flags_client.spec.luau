--!strict
-- Feature flags, client side: the mirror arrived, it agrees with the server, and a client can
-- neither publish it nor see the override that produced it.
--
-- In `test2` this file runs in BOTH client processes (the harness checks all three reports since
-- Task 36), so "the server and every client agree" is asserted across three processes -- which is
-- the one thing a one-player run cannot show.
--
-- Design: docs/design/feature-flags.md (section 13.2)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
local Role = require(ReplicatedStorage:WaitForChild("ClientTests"):WaitForChild("Role"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local function stateHost(): Instance
	return (ReplicatedStorage:WaitForChild("Flags") :: Instance):WaitForChild("State")
end

return function()
	describe("the published mirror", function()
		it("arrived: this client did not fall back to the defaults", function()
			local source = Flags.source()
			TestKit.note(
				string.format(
					"flags[%s]: source=%s digest=%s",
					if Role.isShooter() then "shooter" else "driver",
					source,
					Flags.digest(Flags.all())
				)
			)
			-- FlagsBoot runs at server start, before any player exists, so the real wait is about
			-- zero. A timeout here means the mirror never arrived, which is the one failure mode
			-- the WAIT_SECONDS budget exists for.
			expect(source).to.equal("published")
		end)

		it("agrees with what the server wrote, exactly", function()
			local state = stateHost()
			expect(Flags.digest(Flags.all())).to.equal(state:GetAttribute(Flags.DIGEST_ATTRIBUTE))
		end)

		it("carries exactly the flags this client knows about", function()
			local state = stateHost()
			local declared: { string } = {}
			for name in pairs(Flags.DEFAULTS) do
				table.insert(declared, name)
			end
			table.sort(declared)

			local mirrored: { string } = {}
			for name in pairs(state:GetAttributes()) do
				if name ~= Flags.DIGEST_ATTRIBUTE and name ~= Flags.SOURCE_ATTRIBUTE then
					table.insert(mirrored, name)
				end
			end
			table.sort(mirrored)
			expect(table.concat(mirrored, ",")).to.equal(table.concat(declared, ","))

			for _, name in ipairs(declared) do
				expect(type(state:GetAttribute(name))).to.equal("boolean")
				expect(Flags.all()[name]).to.equal(state:GetAttribute(name))
			end
		end)
	end)

	describe("what a client may not do", function()
		it("cannot publish: the mirror has one writer and it is the server", function()
			expect(function()
				Flags.publish({}, "defaults")
			end).to.throw()
		end)

		it("cannot see the override that produced the value", function()
			-- ServerStorage is not replicated, and this asserts it rather than assuming it: the
			-- whole override mechanism depends on a client being unable to read or influence it.
			local ok, storage = pcall(function()
				return game:GetService("ServerStorage")
			end)
			if not ok then
				-- Even better than empty: the service is unreachable from here.
				TestKit.note("flags: ServerStorage is not reachable from a client at all")
				return
			end
			for name in pairs(Flags.DEFAULTS) do
				expect((storage :: Instance):GetAttribute(Flags.OVERRIDE_PREFIX .. name)).to.equal(nil)
			end
		end)

		it("did not write the mirror while this suite ran", function()
			-- Ordered last in this file on purpose: if any client module had written State, the
			-- Source the server wrote would no longer be there to read.
			local state = stateHost()
			expect(Flags.SOURCES[state:GetAttribute(Flags.SOURCE_ATTRIBUTE)]).to.equal(true)
			expect(state:GetAttribute(Flags.DIGEST_ATTRIBUTE)).to.equal(Flags.digest(Flags.all()))
		end)
	end)
end
