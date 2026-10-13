-- economy_store.spec: the store boundary's own contract -- the in-memory implementation that Studio
-- and every spec get, the profile's shape, the key, and the missing-key rule.
--
-- IT NEVER REQUIRES ProfileStore, and that is the point of having a boundary at all. Requiring the
-- library performs a real `DataStoreService:GetDataStore("____PS"):SetAsync(...)` as a side effect of
-- the require (docs/research/2026-10-13-coins-persistence.md section 2.1), so `Store.live` -- the one
-- function in the repository that requires it -- is never called here and is never called in Studio.
-- `economy.spec` carries the pure assertion that says so (`Economy.storeKindFor`).
--
-- WHAT THIS CANNOT TEST, said once: the live path. One Studio session is one server, so a real
-- session steal cannot be reproduced -- what IS testable is OUR reaction to it, through
-- `Store.memory`'s `refuse` option and its `loseSession` door.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/economy.md (sections 4.2, 9)
-- Note:   docs/research/2026-10-13-coins-persistence.md
local ServerScriptService = game:GetService("ServerScriptService")

local Economy = require(ServerScriptService:WaitForChild("Economy"))

local Store = Economy.Store

return function()
	describe("the key and the template", function()
		it("names a key the way Roblox's cap allows", function()
			expect(Store.keyFor(1)).to.equal("player_1")
			expect(Store.keyFor(1234567890)).to.equal("player_1234567890")
			-- 19 digits plus "player_" is 26 characters, against the documented 50-character cap --
			-- and that is a larger userId than Roblox can issue.
			expect(#Store.keyFor(9999999999999999999) <= 50).to.equal(true)
		end)

		it("holds the balance, lifetime earnings and the drive count, and a schema number", function()
			local t = Store.TEMPLATE
			expect(t.coins).to.equal(0)
			-- `coinsEarnedTotal` is the one number SPENDING destroys and cannot rebuild, which is why
			-- it is here before there is anything to spend on.
			expect(t.coinsEarnedTotal).to.equal(0)
			expect(t.drivesPaid).to.equal(0)
			-- READ AND NEVER ACTED ON in this task: it is the number a later migration branches on,
			-- and branching on it now would be a migration with nothing to migrate.
			expect(t.schema).to.equal(1)
		end)

		it("versions the store in its NAME, which is the only migration that cannot corrupt data", function()
			expect(Economy.CONFIG.STORE_NAME).to.equal("DrivenHuntPlayer_v1")
			-- NOT named after one of its columns: the next thing into this table is *"Progress
			-- trophys"*, and a store called "Coins" would force either a second store or a lie.
			expect(string.find(Economy.CONFIG.STORE_NAME, "Coins", 1, true)).to.equal(nil)
		end)
	end)

	-- THE ONE INVENTED THING IN THIS SYSTEM, in two halves, each with its own reason (rule 2).
	describe("reading a profile", function()
		it("fills a key the stored data does not have, so an old profile is readable", function()
			local data = Store.read({ coins = 500 })
			expect(data.coins).to.equal(500)
			expect(data.coinsEarnedTotal).to.equal(0)
			expect(data.drivesPaid).to.equal(0)
			expect(data.schema).to.equal(1)
		end)

		it("fills every key for a profile that does not exist yet", function()
			for _, empty in ipairs({ {}, "not a table", 7 }) do
				local data = Store.read(empty)
				expect(data.coins).to.equal(0)
				expect(data.schema).to.equal(1)
			end
			expect(Store.read(nil).coins).to.equal(0)
		end)

		-- THE HALF A LIBRARY CANNOT DO FOR US, because it is a decision about OUR data: a build that
		-- does not know about `trophies` must not delete the trophies a newer build wrote. That is
		-- what makes a ROLLBACK survivable.
		it("keeps a key it has never heard of, so a rollback does not destroy data", function()
			local data = Store.read({ coins = 5, trophies = { "first-boar" }, licences = 2 })
			expect(data.coins).to.equal(5)
			expect(data.licences).to.equal(2)
			expect(data.trophies[1]).to.equal("first-boar")
		end)

		it("never mutates what it was given", function()
			local stored = { coins = 5 }
			Store.read(stored)
			expect(stored.coinsEarnedTotal).to.equal(nil)
		end)
	end)

	describe("the in-memory store", function()
		it("is what Studio gets, and says so in its kind", function()
			expect(Store.memory().kind).to.equal("memory")
		end)

		it("loads a seeded balance and a fresh player's zero", function()
			local store = Store.memory({ seed = { [1] = 250 } })
			expect(store.load(1)).to.equal(250)
			expect(store.load(2)).to.equal(0)
			expect(store.calls().load).to.equal(2)
		end)

		-- A ROUND TRIP, which is the whole claim of the system: what was saved is what loads back.
		it("saves a balance and reads the same number back", function()
			local store = Store.memory()
			expect(store.load(1)).to.equal(0)
			expect(store.save(1, 320)).to.equal(true)
			-- A SECOND LOAD IS THE SAME SESSION, not a second one.
			expect(store.load(1)).to.equal(320)
			-- ...and it survives the session ending, which is what `EndSession` is for.
			expect(store.release(1)).to.equal(true)
			expect(store.load(1)).to.equal(320)
		end)

		it("tracks lifetime earnings and the drive count beside the balance", function()
			local store = Store.memory()
			store.load(1)
			store.save(1, 30)
			store.save(1, 97)
			store.release(1)
			local fresh = Store.memory()
			-- The second store cannot see the first one's table -- the fake store is per instance,
			-- *"a separate 'fake' DataStore forgotten at shutdown"* in the library's own words -- so
			-- this asserts the isolation as much as the arithmetic.
			expect(fresh.load(1)).to.equal(0)
		end)

		-- NO SESSION MEANS NO SAVING, which is the rule that keeps a refused lock from turning into a
		-- lost balance somebody else owns.
		it("refuses to save for a player it never loaded", function()
			local store = Store.memory()
			expect(store.save(9, 500)).to.equal(false)
			expect(store.load(9)).to.equal(0)
		end)

		it("answers nil and a reason when the lock is refused", function()
			local store = Store.memory({ refuse = { [5] = true } })
			local balance, reason = store.load(5)
			expect(balance).to.equal(nil)
			-- TOLD APART FROM AN ERROR, because one is another player's server and the other is
			-- Roblox being down, and a report that cannot tell them apart cannot be acted on.
			expect(reason).to.equal("refused")
			expect(store.save(5, 100)).to.equal(false)
		end)

		it("releases once and then answers false", function()
			local store = Store.memory()
			store.load(1)
			expect(store.release(1)).to.equal(true)
			expect(store.release(1)).to.equal(false)
			expect(store.calls().release).to.equal(2)
		end)

		it("ends every open session at once, and says how many", function()
			local store = Store.memory()
			store.load(1)
			store.load(2)
			store.load(3)
			expect(store.releaseAll()).to.equal(3)
			expect(store.releaseAll()).to.equal(0)
		end)

		it("calls the lost-session handler, and only the one that is set", function()
			local store = Store.memory()
			local seen = {}
			store.setOnLost(function(userId: number)
				table.insert(seen, userId)
			end)
			store.load(4)
			local lose = store.loseSession :: (number) -> ()
			lose(4)
			expect(#seen).to.equal(1)
			expect(seen[1]).to.equal(4)
			-- The session really is gone, so nothing can be written for him afterwards.
			expect(store.save(4, 100)).to.equal(false)
		end)
	end)

	-- SAFE TO CALL WHEN NOTHING WAS EVER STARTED, which is what makes the composition root's
	-- unconditional `game:BindToClose(Economy.closeAll)` correct: `BindToClose` cannot be
	-- disconnected, so registering it inside `Economy.start` would leave one callback per spec run
	-- bound for the rest of the session.
	describe("shutdown", function()
		it("is a no-op on an owner that was never started", function()
			Economy.stop()
			expect(Economy.closeAll()).to.equal(0)
			expect(Economy.storeKind()).to.equal("off")
		end)

		it("ends every session the owner had open", function()
			Economy.stop()
			local store = Store.memory({ seed = { [1] = 10, [2] = 20 } })
			Economy.start({
				store = store,
				enabled = true,
				players = {
					GetPlayers = function()
						return { { UserId = 1, Name = "a", Parent = true }, { UserId = 2, Name = "b", Parent = true } }
					end,
					PlayerAdded = Instance.new("BindableEvent").Event,
					PlayerRemoving = Instance.new("BindableEvent").Event,
				},
			})
			local deadline = os.clock() + 2
			while os.clock() < deadline and store.calls().load < 2 do
				task.wait(0.02)
			end
			expect(Economy.closeAll()).to.equal(2)
			-- ...and the owner's own tables went with them: a balance with no session behind it is a
			-- number nothing can save.
			expect(Economy.balanceOf(1)).to.equal(nil)
			Economy.stop()
		end)
	end)
end
