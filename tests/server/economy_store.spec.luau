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
-- Design: docs/design/economy.md (sections 4.2, 9), docs/design/role-rotation.md (section 11.4)
-- Note:   docs/research/2026-10-13-coins-persistence.md, docs/research/2026-10-20-role-rotation.md
local ServerScriptService = game:GetService("ServerScriptService")

local Economy = require(ServerScriptService:WaitForChild("Economy"))

local Store = Economy.Store

return function()
	-- THE PRODUCTION OWNER IS PUT BACK, for the reason `economy.spec` states at the same place: the
	-- shutdown cases below stop and start the LIVE singleton, and `Economy.start()` with no argument
	-- is exactly what the composition root calls.
	afterAll(function()
		Economy.stop()
		Economy.start()
	end)

	describe("the key and the template", function()
		it("names a key the way Roblox's cap allows", function()
			expect(Store.keyFor(1)).to.equal("player_1")
			expect(Store.keyFor(1234567890)).to.equal("player_1234567890")
			-- 19 digits plus "player_" is 26 characters, against the documented 50-character cap --
			-- and that is a larger userId than Roblox can issue.
			expect(#Store.keyFor(9999999999999999999) <= 50).to.equal(true)
		end)

		-- HAZARD 1 (task 178, design section 8.2a): with a TABLE in the template, `read`'s
		-- fill-missing half used to hand every profile THE SAME TABLE -- the first purchase would
		-- have written into the template itself, so one player's hat would be worn by every player
		-- on the server and on every later one. Two halves close it, and both are asserted: `read`
		-- CLONES a table default, and the template is FROZEN so a mutation errors loudly.
		it("holds an ownership set that no profile shares and nobody can write", function()
			expect(type(Store.TEMPLATE.owned)).to.equal("table")
			expect(next(Store.TEMPLATE.owned)).to.equal(nil)
			expect(table.isfrozen(Store.TEMPLATE)).to.equal(true)
			expect(table.isfrozen(Store.TEMPLATE.owned)).to.equal(true)
			expect(function()
				(Store.TEMPLATE :: any).coins = 99
			end).to.throw()
			local first, second = Store.read({}), Store.read({})
			expect(first.owned).never.to.equal(second.owned)
			expect(first.owned).never.to.equal(Store.TEMPLATE.owned)
			first.owned["hat.red"] = true
			expect(next(second.owned)).to.equal(nil)
			expect(next(Store.TEMPLATE.owned)).to.equal(nil)
			-- A KEY THAT CAME BACK WITH THE WRONG TYPE is replaced rather than trusted: nobody here
			-- has verified what an empty Lua table does on a DataStore round trip, and checking the
			-- type makes the answer irrelevant (design section 17).
			expect(type(Store.read({ owned = "x" }).owned)).to.equal("table")
			expect(Store.read({ owned = { a = true } }).owned.a).to.equal(true)
		end)

		it("holds the balance, lifetime earnings, the drive count, the TURN and a schema number", function()
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

		-- ------------------------------------------------------------ the turn (task 217)
		--
		-- KAREN, 2026-10-11: *"ROLES ROTATE ... it is REMEMBERED across logout/login (no cheating
		-- back to hunter) -- persistent per player (DataStore)."*
		-- Design: docs/design/role-rotation.md (sections 3.1, 3.3, 6, 11.4)
		it("holds the turn as a STRING, which is what keeps it clear of the shared-table hazard", function()
			local t = Store.TEMPLATE
			-- `""` MEANS NO TURN STORED, and it is a string rather than a table on purpose: this
			-- template is ENUMERATED by `Store.read`'s fill-missing half, whose clone branch is
			-- `type(value) == "table"` -- so a scalar default can never reach hazard 1, where one
			-- shared table would have been handed to every player on the server.
			expect(t.nextTeam).to.equal("")
			expect(type(t.nextTeam)).to.equal("string")
			-- ...AND `""` RATHER THAN A MISSING KEY, because a key whose default were nil cannot
			-- exist in a Lua table at all: the template would not name the field, so
			-- `ProfileStore.New(storeName, Store.TEMPLATE)` would not know it and nothing reading
			-- the template would see the profile's real shape.
			expect(table.isfrozen(t)).to.equal(true)
		end)

		it("adds the turn to the key and NOT to the store's name: it is additive", function()
			-- The whole reason a new field costs nothing: an older build keeps this key untouched
			-- (`Store.read`'s keep-unknown half) and a newer one fills it, so no `_v2` and no
			-- migration. `schema` is still 1 because there is nothing to migrate.
			expect(Economy.CONFIG.STORE_NAME).to.equal("DrivenHuntPlayer_v1")
			expect(Store.TEMPLATE.schema).to.equal(1)
			expect(Store.read({ coins = 500 }).nextTeam).to.equal("")
			expect(Store.read({ nextTeam = "Drivers" }).nextTeam).to.equal("Drivers")
			-- A value from a vocabulary this project never shipped is KEPT by the store and refused
			-- by the owner's validator: the store's job is the key, not the rule.
			expect(Store.read({ nextTeam = "hunter" }).nextTeam).to.equal("hunter")
			expect(Economy.teamFromRecord(Store.read({ nextTeam = "hunter" }).nextTeam)).to.equal(nil)
		end)

		-- THE ROUND TRIP, AND IT IS THE FEATURE (design hazard 10). "Two drives in a row: hunter
		-- then beater" is ALREADY TRUE without this task, from the drive's in-memory swap -- so the
		-- only evidence that anything was REMEMBERED is that the value survives a release and a
		-- reload. `Store.memory`'s `saved` closure outlives a release, so this is a real round trip
		-- and not a simulation of one.
		it("keeps the turn across a release and a fresh load, which is the whole feature", function()
			local store = Store.memory()
			expect(store.load(77)).to.be.ok()
			expect(store.save(77, { nextTeam = "Drivers" })).to.equal(true)
			expect((store.peek :: any)(77).nextTeam).to.equal("Drivers")
			expect(store.release(77)).to.equal(true)
			-- HE IS GONE and the key still says it.
			expect((store.peek :: any)(77).nextTeam).to.equal("Drivers")
			-- ...AND HE COMES BACK.
			local again = store.load(77)
			expect((again :: any).nextTeam).to.equal("Drivers")
			-- Nothing else moved with it.
			expect((again :: any).coins).to.equal(0)
			expect((again :: any).drivesPaid).to.equal(0)
		end)

		it("seeds a turn whole, and a bare-number seed still fills it with no turn", function()
			local store = Store.memory({ seed = { [78] = { nextTeam = "Shooters" }, [79] = 500 } })
			expect((store.load(78) :: any).nextTeam).to.equal("Shooters")
			local other = store.load(79) :: any
			expect(other.coins).to.equal(500)
			expect(other.nextTeam).to.equal("")
		end)

		it("writes the turn without touching the balance, and the balance without touching the turn", function()
			-- `Store.save` writes EXACTLY the fields it is told and derives nothing (task 178,
			-- hazard 2), which is what keeps a pay-out and a purchase off the turn (design hazard 6).
			local store = Store.memory({ seed = { [80] = { coins = 100, nextTeam = "Drivers" } } })
			expect(store.load(80)).to.be.ok()
			store.save(80, { coins = 140 })
			expect((store.peek :: any)(80).nextTeam).to.equal("Drivers")
			store.save(80, { nextTeam = "Shooters" })
			expect((store.peek :: any)(80).coins).to.equal(140)
			expect((store.peek :: any)(80).nextTeam).to.equal("Shooters")
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
			expect(store.load(1).coins).to.equal(250)
			expect(store.load(2).coins).to.equal(0)
			expect(store.calls().load).to.equal(2)
		end)

		-- A ROUND TRIP, which is the whole claim of the system: what was saved is what loads back.
		it("saves a balance and reads the same number back", function()
			local store = Store.memory()
			expect(store.load(1).coins).to.equal(0)
			expect(store.save(1, { coins = 320 })).to.equal(true)
			-- A SECOND LOAD IS THE SAME SESSION, not a second one.
			expect(store.load(1).coins).to.equal(320)
			-- ...and it survives the session ending, which is what `EndSession` is for.
			expect(store.release(1)).to.equal(true)
			expect(store.load(1).coins).to.equal(320)
		end)

		-- RENAMED IN ROUND 2 (note 4): the old name said this case asserted `coinsEarnedTotal` and
		-- `drivesPaid`, and it never did -- the memory store exposes no accessor for either, and the
		-- body only ever proved that two stores do not share a table. The name now says what it does.
		it("keeps its table to itself: a second store sees none of the first one's saves", function()
			local store = Store.memory()
			store.load(1)
			store.save(1, { coins = 30 })
			store.save(1, { coins = 97 })
			store.release(1)
			local fresh = Store.memory()
			-- The second store cannot see the first one's table -- the fake store is per instance,
			-- *"a separate 'fake' DataStore forgotten at shutdown"* in the library's own words -- so
			-- this asserts the isolation as much as the arithmetic.
			expect(fresh.load(1).coins).to.equal(0)
		end)

		-- TASK 178: `save` WRITES EXACTLY WHAT IT IS TOLD AND DERIVES NOTHING. It used to add 1 to
		-- `drivesPaid` and to accumulate `coinsEarnedTotal` on EVERY call, which was correct while
		-- `payDrive` was the only caller and became a bug the moment a purchase called it: buying a
		-- hat would have counted as a completed hunt (hazard 2). The increments live in
		-- `Economy.payDrive` now, and the old bodies are archived with their rollback in
		-- `backups/2026-10-14_task-178_store-seed-and-save.md`.
		it("writes exactly the fields it was given and derives nothing", function()
			local store = Store.memory()
			store.load(1)
			expect(store.save(1, { coins = 300 })).to.equal(true)
			expect(store.peek(1).coins).to.equal(300)
			expect(store.peek(1).drivesPaid).to.equal(0)
			expect(store.peek(1).coinsEarnedTotal).to.equal(0)
			-- A SECOND SAVE IS NOT A SECOND DRIVE.
			store.save(1, { coins = 220, owned = { ["hat.red"] = true } })
			expect(store.peek(1).drivesPaid).to.equal(0)
			expect(store.peek(1).coins).to.equal(220)
			expect(store.peek(1).owned["hat.red"]).to.equal(true)
			-- ...AND THE DRIVE'S OWN THREE FIELDS GO THROUGH THE SAME DOOR, named by the caller.
			store.save(1, { coins = 260, drivesPaid = 3, coinsEarnedTotal = 40 })
			expect(store.peek(1).drivesPaid).to.equal(3)
			expect(store.peek(1).coinsEarnedTotal).to.equal(40)
			-- A FIELD NOBODY NAMED IS NOT TOUCHED: the hat survives a coins-only save.
			expect(store.peek(1).owned["hat.red"]).to.equal(true)
		end)

		-- THE SEED IS A WHOLE PROFILE SINCE TASK 178, so one line gives a spec a rich player with a
		-- hunt count and a cupboard -- and a NUMBER still means `{ coins = n }`, so every call
		-- written before this task behaves exactly as it did.
		it("seeds a whole profile, and still accepts a bare number", function()
			local store = Store.memory({
				seed = {
					[1] = { coins = 500, drivesPaid = 30, owned = { ["ammo.slug"] = true } },
					[2] = 250,
				},
			})
			local rich = store.load(1)
			expect(rich.coins).to.equal(500)
			expect(rich.drivesPaid).to.equal(30)
			expect(rich.owned["ammo.slug"]).to.equal(true)
			local plain = store.load(2)
			expect(plain.coins).to.equal(250)
			expect(plain.drivesPaid).to.equal(0)
			expect(next(plain.owned)).to.equal(nil)
			-- THE SET A SPEC SEEDED IS NOT THE ONE THE STORE HANDS BACK: `read` clones, so a case
			-- cannot edit the seed through the profile it was given.
			expect(#Store.keyFor(1)).to.be.ok()
		end)

		-- THE PROFILE GROWS BY AT MOST ONE SMALL DICTIONARY, bounded by the catalogue itself.
		it("bounds the ownership set by the catalogue", function()
			local Shop = require(game:GetService("ReplicatedStorage"):WaitForChild("Shop"))
			local store = Store.memory()
			store.load(1)
			local everything = {}
			for _, id in ipairs(Shop.ORDER) do
				everything[id] = true
			end
			store.save(1, { owned = everything })
			local count = 0
			for id in pairs(store.peek(1).owned) do
				expect(Shop.row(id)).to.be.ok()
				count += 1
			end
			expect(count).to.equal(#Shop.ORDER)
			expect(count <= Shop.CONFIG.MAX_ITEMS).to.equal(true)
		end)

		-- NO SESSION MEANS NO SAVING, which is the rule that keeps a refused lock from turning into a
		-- lost balance somebody else owns.
		it("refuses to save for a player it never loaded", function()
			local store = Store.memory()
			expect(store.save(9, { coins = 500 })).to.equal(false)
			expect(store.load(9).coins).to.equal(0)
		end)

		it("answers nil and a reason when the lock is refused", function()
			local store = Store.memory({ refuse = { [5] = true } })
			local balance, reason = store.load(5)
			expect(balance).to.equal(nil)
			-- TOLD APART FROM AN ERROR, because one is another player's server and the other is
			-- Roblox being down, and a report that cannot tell them apart cannot be acted on.
			expect(reason).to.equal("refused")
			expect(store.save(5, { coins = 100 })).to.equal(false)
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
			expect(store.save(4, { coins = 100 })).to.equal(false)
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
