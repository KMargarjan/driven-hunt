-- economy.spec: what a drive pays, who it refuses, and the whole owner driven against an in-memory
-- store -- with no ProfileStore, no DataStore, no network and no drive.
--
-- Karen, 2026-10-11: *"Scoring - yes get money when shoot boar not much but get money and first
-- place ofc more legendary more ect"*. 2026-10-12: separate rankings for hunters and beaters.
--
-- THE NUMBERS ARE WRITTEN OUT AND NOT IMPORTED, so a config that drifts is a finding and not a
-- tautology; the last describe closes the loop the other way against `Economy.CONFIG`.
--
-- NOTHING HERE REQUIRES THE LIBRARY, and that is a claim rather than an accident: requiring
-- ProfileStore performs a real `SetAsync` as a side effect of the require
-- (docs/research/2026-10-13-coins-persistence.md section 2.1), so a harness run must never do it.
-- `Economy.storeKindFor` is the pure predicate that proves a live server takes the real store and
-- Studio can never -- which is the only way to assert it from inside Studio, where
-- `RunService:IsStudio()` is always true.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/economy.md (sections 4.1, 4.4, 10), docs/design/role-rotation.md (section 11.3)
-- Note:   docs/research/2026-10-13-coins-persistence.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))
local Economy = require(ServerScriptService:WaitForChild("Economy"))

local Coins = Economy.Coins
local Store = Economy.Store
-- The catalogue, for the purchase cases (task 178): the ids, the prices and the reasons live in one
-- table and this spec reads the same one the owner charges from.
local Shop = require(ReplicatedStorage:WaitForChild("Shop"))
local Rank = Drive.Rank

local CONFIG = {
	COINS_PER_POINT = 2,
	PARTICIPATION = 10,
	FIRST_PLACE = 25,
	FLOOR = 0,
}

-- A row the way `Score.leaderboard` hands one over: already sorted, already frozen in production.
local function row(userId: number, team: string?, points: number, left: boolean?)
	return {
		userId = userId,
		name = "p" .. tostring(userId),
		team = team,
		points = points,
		kills = 0,
		assists = 0,
		pushes = 0,
		violations = 0,
		left = left or false,
	}
end

-- Players, the way `Economy.start` reads them: one object with `GetPlayers`, plus the two signals.
local function fakePlayers(ids: { number })
	local added = Instance.new("BindableEvent")
	local removing = Instance.new("BindableEvent")
	local list = {}
	for _, userId in ipairs(ids) do
		table.insert(list, { UserId = userId, Name = "p" .. userId, Parent = true })
	end
	return {
		GetPlayers = function()
			return list
		end,
		PlayerAdded = added.Event,
		PlayerRemoving = removing.Event,
		_added = added,
		_removing = removing,
		_list = list,
	}
end

local function waitUntil(seconds: number, predicate: () -> boolean): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if predicate() then
			return true
		end
		task.wait(0.02)
	end
	return predicate()
end

return function()
	-- THE PRODUCTION OWNER IS PUT BACK, and this is not tidiness: the cases below drive the LIVE
	-- singleton -- `Economy.start{ store = ..., enabled = ... }` is the design's seam and there is one
	-- module -- so a spec that walked away would leave `ServerScriptService.Economy` stopped, with the
	-- drive still holding a view of it. `zz_drive_boundary.spec` reads that owner at the real drive
	-- boundary, and a spec that broke a later one is this suite's own named failure
	-- (tests/client/weapon_client.spec.luau, task 34: *"a spec that revoked this gun mid-session broke
	-- exactly this window, and was withdrawn"*).
	--
	-- `Economy.start()` WITH NO ARGUMENT IS EXACTLY WHAT THE COMPOSITION ROOT CALLS: the real
	-- `Players` service and the real flag. So this restores the boot, it does not imitate it.
	afterAll(function()
		Economy.stop()
		Economy.start()
	end)

	describe("what a drive is worth", function()
		it("pays points at the rate, plus participation", function()
			-- A male boar is 10 points: 20 coins, plus 10 for turning up and finishing = 30.
			expect(Coins.forRow(10, false, CONFIG)).to.equal(30)
			expect(Coins.forRow(0, false, CONFIG)).to.equal(10)
			-- *"first place ofc more"*.
			expect(Coins.forRow(16, true, CONFIG)).to.equal(67)
		end)

		it("lets a bad drive pay a negative number of coins", function()
			-- Two piglets and a safety violation is -30 points (`match_score.spec` asserts that
			-- board): -60 + 10 participation = -50. THE DRIVE'S LINE MAY BE NEGATIVE; the balance is
			-- what is floored, and `Coins.credit` is the only place that floors it.
			expect(Coins.forRow(-30, false, CONFIG)).to.equal(-50)
		end)

		it("floors the BALANCE at zero and nothing else", function()
			expect(Coins.credit(20, -50, CONFIG)).to.equal(0)
			expect(Coins.credit(0, -50, CONFIG)).to.equal(0)
			expect(Coins.credit(100, -50, CONFIG)).to.equal(50)
			expect(Coins.credit(0, 30, CONFIG)).to.equal(30)
		end)

		-- TWO RANKINGS, TWO FIRST PLACES, ONE RULE (task 170). Karen, 2026-10-12. The server pays the
		-- bonus off `Drive.Rank` and the Hud draws the badge off the same function, so a bonus and a
		-- badge cannot land on different rows.
		it("pays a first-place bonus to the top hunter AND the top beater", function()
			local rows = {
				row(1, "Shooters", 16),
				row(2, "Drivers", 9),
				row(3, "Shooters", 6),
				row(4, "Drivers", 3),
			}
			local out = Coins.forDrive(rows, CONFIG)
			expect(out.firstHunter).to.equal(1)
			expect(out.firstBeater).to.equal(2)
			expect(out.coins[1]).to.equal(16 * 2 + 10 + 25)
			expect(out.coins[2]).to.equal(9 * 2 + 10 + 25)
			-- Second in each ranking gets no bonus -- and the BEATER on 9 is paid one although two
			-- hunters out-scored him, which is the whole point of splitting the board.
			expect(out.coins[3]).to.equal(6 * 2 + 10)
			expect(out.coins[4]).to.equal(3 * 2 + 10)
		end)

		it("pays nobody a bonus in a ranking whose top two are level", function()
			local rows = { row(1, "Shooters", 12), row(2, "Shooters", 12), row(3, "Drivers", 6) }
			local out = Coins.forDrive(rows, CONFIG)
			expect(out.firstHunter).to.equal(nil)
			expect(out.coins[1]).to.equal(12 * 2 + 10)
			expect(out.coins[2]).to.equal(12 * 2 + 10)
			-- ...and the other ranking is untouched by that tie.
			expect(out.firstBeater).to.equal(3)
			expect(out.coins[3]).to.equal(6 * 2 + 10 + 25)
		end)

		it("pays nobody a bonus on a board where nothing has happened", function()
			local out = Coins.forDrive({ row(1, "Shooters", 0), row(2, "Drivers", 0) }, CONFIG)
			expect(out.firstHunter).to.equal(nil)
			expect(out.firstBeater).to.equal(nil)
			expect(out.coins[1]).to.equal(10)
			expect(out.coins[2]).to.equal(10)
		end)

		-- PARTICIPATION IS FOR TURNING UP *AND FINISHING*, and the man is not on the server: paying
		-- him means writing into a profile whose session this server has already ended.
		it("does not pay a leaver, and counts him", function()
			local out = Coins.forDrive({ row(1, "Shooters", 16, true), row(2, "Shooters", 6) }, CONFIG)
			expect(out.coins[1]).to.equal(nil)
			expect(out.skippedLeft).to.equal(1)
			-- HE IS STILL IN THE RANKING FOR THE PURPOSE OF FIRST PLACE, because the results table
			-- still shows his row -- so the second man did not inherit a bonus he did not win.
			expect(out.firstHunter).to.equal(1)
			expect(out.coins[2]).to.equal(6 * 2 + 10)
		end)

		-- A ROW WITH NO TEAM IS A REAL STATE: a player who joined in `Waiting` or `Scoring` has none
		-- until the next `Assigning`. He is paid, and he is in no ranking, so he wins nothing.
		it("pays a row with no team, and never gives it a first place", function()
			local out = Coins.forDrive({ row(1, nil, 12) }, CONFIG)
			expect(out.coins[1]).to.equal(12 * 2 + 10)
			expect(out.firstHunter).to.equal(nil)
			expect(out.firstBeater).to.equal(nil)
		end)

		-- A BOT CANNOT GET HERE, and the mechanism is structural (docs/design/bots.md: *"no row in
		-- `Score`, no DataStore"* -- a bot's id is a non-numeric string, and `Phase.participantIds`
		-- and `Match.pushCreditable` already refuse it). This is the tripwire with a number on it.
		it("refuses anything that is not a real player's userId, and counts it", function()
			local rows = {
				{ userId = "bot-beater-1", name = "bot", team = "Drivers", points = 9, kills = 0 },
				{ userId = 0, name = "zero", team = "Shooters", points = 9, kills = 0 },
				{ userId = 1.5, name = "frac", team = "Shooters", points = 9, kills = 0 },
				row(7, "Shooters", 9),
			}
			local out = Coins.forDrive(rows, CONFIG)
			expect(out.skippedNotAPlayer).to.equal(3)
			expect((out.coins :: any)["bot-beater-1"]).to.equal(nil)
			expect(out.coins[7]).to.equal(9 * 2 + 10)
		end)

		it("returns a frozen breakdown and never touches its input", function()
			local rows = { row(1, "Shooters", 16) }
			local out = Coins.forDrive(rows, CONFIG)
			expect(table.isfrozen(out)).to.equal(true)
			expect(table.isfrozen(out.coins)).to.equal(true)
			expect(rows[1].points).to.equal(16)
			expect(next(Coins.forDrive(nil, CONFIG).coins)).to.equal(nil)
		end)

		it("splits every row into exactly one ranking, in the board's own order", function()
			local rows = { row(1, "Shooters", 16), row(2, "Drivers", 9), row(3, nil, 6), row(4, "Shooters", 3) }
			local hunters, beaters, others = Rank.splitByTeam(rows)
			expect(#hunters + #beaters + #others).to.equal(#rows)
			expect(#hunters).to.equal(2)
			expect(#beaters).to.equal(1)
			expect(#others).to.equal(1)
			-- ORDER PRESERVED: `Score.leaderboard` already produced a total order and no ranking
			-- re-sorts it.
			expect(hunters[1].userId).to.equal(1)
			expect(hunters[2].userId).to.equal(4)
		end)
	end)

	describe("the owner", function()
		local function started(options)
			local opts = options or {}
			local players = fakePlayers(opts.ids or { 1, 2 })
			local store = Store.memory({ seed = opts.seed, refuse = opts.refuse })
			Economy.stop() -- never inherit another case's state
			Economy.start({
				store = store,
				players = players,
				enabled = opts.enabled ~= false,
				-- `false` BY DEFAULT, NOT nil: nil would ask the two production facts, and one of
				-- them is `RunService:IsStudio()`, which is ALWAYS true in a harness run. A case that
				-- wants the grant says so (task 178).
				testGrant = if opts.testGrant ~= nil then opts.testGrant else false,
			})
			return players, store
		end

		afterEach(function()
			Economy.stop()
		end)

		it("loads every player already on the server, and reports which store it took", function()
			local _, store = started({ ids = { 11, 12 }, seed = { [11] = 400 } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(11) ~= nil and Economy.balanceOf(12) ~= nil
			end)).to.equal(true)
			expect(Economy.balanceOf(11)).to.equal(400)
			-- A player with no key starts at the template's own value and not at nil.
			expect(Economy.balanceOf(12)).to.equal(0)
			expect(Economy.storeKind()).to.equal("memory")
			expect(store.calls().load).to.equal(2)
		end)

		-- `nil` IS NOT ZERO. A refused session means an UNKNOWN balance, which the Hud draws as `--`,
		-- and the man earns nothing until a retry succeeds.
		it("gives a refused session no balance, no earning and a retry at the next drive", function()
			local players, store = started({ ids = { 21 }, refuse = { [21] = true } })
			expect(waitUntil(2, function()
				return Economy.stats().loadsRefused == 1
			end)).to.equal(true)
			expect(Economy.balanceOf(21)).to.equal(nil)

			local receipt = Economy.payDrive(1, { row(21, "Shooters", 16) })
			expect(receipt.skippedNoProfile).to.equal(1)
			expect(receipt.paid).to.equal(0)
			expect(Economy.balanceOf(21)).to.equal(nil)
			expect(store.calls().save).to.equal(0)

			-- THE LEVEL-TRIGGERED RETRY. It asks again; the store still refuses, so the number rises
			-- instead of the game pretending it worked.
			Economy.onDriveStart()
			expect(waitUntil(2, function()
				return Economy.stats().loadsRefused == 2
			end)).to.equal(true)
			expect(#players:GetPlayers()).to.equal(1)
		end)

		it("pays a drive into the balance, saves it, and puts the figure on `earned`", function()
			started({ ids = { 31, 32 }, seed = { [31] = 100, [32] = 0 } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(31) ~= nil and Economy.balanceOf(32) ~= nil
			end)).to.equal(true)
			local receipt = Economy.payDrive(1, { row(31, "Shooters", 16), row(32, "Drivers", 3) })
			expect(receipt.paid).to.equal(2)
			expect(receipt.duplicate).to.equal(false)
			expect(Economy.balanceOf(31)).to.equal(100 + 67)
			expect(Economy.balanceOf(32)).to.equal(41)
			expect(Economy.earnedOf(31)).to.equal(67)
			expect(Economy.earnedOf(32)).to.equal(41)
			expect(Economy.stats().drivesPaid).to.equal(1)
		end)

		-- NO DOUBLE PAY. The phase edge in `Match`'s dispatch makes it structural; this is the belt
		-- over that brace, and the reason it exists is that `Match.start` resets `driveNumber` to 0.
		it("refuses a drive number it has already paid, and writes nothing", function()
			started({ ids = { 41 }, seed = { [41] = 50 } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(41) ~= nil
			end)).to.equal(true)
			Economy.payDrive(3, { row(41, "Shooters", 10) })
			local after = Economy.balanceOf(41)
			local again = Economy.payDrive(3, { row(41, "Shooters", 10) })
			expect(again.duplicate).to.equal(true)
			expect(again.paid).to.equal(0)
			expect(Economy.balanceOf(41)).to.equal(after)
			expect(Economy.stats().duplicatePayouts).to.equal(1)
			expect(Economy.stats().drivesPaid).to.equal(1)
			-- An EARLIER number is refused too: a drive counter that went backwards is a bug, not a
			-- second pay day.
			expect(Economy.payDrive(2, { row(41, "Shooters", 10) }).duplicate).to.equal(true)
			-- ...and the NEXT drive pays normally.
			expect(Economy.payDrive(4, { row(41, "Shooters", 10) }).paid).to.equal(1)
		end)

		it("clamps a balance at zero and counts the clamp", function()
			started({ ids = { 51 }, seed = { [51] = 20 } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(51) ~= nil
			end)).to.equal(true)
			-- -30 points is -60 coins, plus 10 participation, plus 25 because he is the only hunter and
			-- something DID happen on his row: -25. Against a balance of 20 that is -5, floored to 0.
			-- (The bonus is not charity -- `Rank.firstPlaceRank` answers 1 for a lone row whose points
			-- are not zero, which is the same rule that gives a lone man on -10 a badge over a -20.)
			local receipt = Economy.payDrive(1, { row(51, "Shooters", -30) })
			expect(receipt.clamped).to.equal(1)
			expect(Economy.balanceOf(51)).to.equal(0)
			-- THE DRIVE'S OWN LINE IS STILL NEGATIVE, because that is what the results table prints.
			expect(Economy.earnedOf(51)).to.equal(-25)
		end)

		-- A PREVIOUS DRIVE'S FIGURE MUST NOT LINGER NEXT TO A NEW DRIVE'S.
		it("replaces `earned` whole at every pay-out", function()
			started({ ids = { 61, 62 } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(61) ~= nil and Economy.balanceOf(62) ~= nil
			end)).to.equal(true)
			Economy.payDrive(1, { row(61, "Shooters", 10), row(62, "Drivers", 3) })
			expect(Economy.earnedOf(62)).to.be.ok()
			Economy.payDrive(2, { row(61, "Shooters", 10) })
			expect(Economy.earnedOf(61)).to.be.ok()
			expect(Economy.earnedOf(62)).to.equal(nil)
		end)

		it("drops a balance the instant another server takes the session", function()
			local _, store = started({ ids = { 71 }, seed = { [71] = 300 } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(71) ~= nil
			end)).to.equal(true)
			-- THE MEMORY STORE'S OWN DOOR for the one case that cannot be reproduced here: a real session
			-- steal needs a second Roblox server, and one Studio session is one server. What IS testable
			-- is OUR reaction to `Profile.OnSessionEnd`, which is what this fires.
			local lose = store.loseSession :: (number) -> ()
			lose(71)
			expect(Economy.balanceOf(71)).to.equal(nil)
			expect(Economy.stats().sessionsLost).to.equal(1)
			-- ...and he earns nothing afterwards: no write is attempted into a dead table.
			expect(Economy.payDrive(1, { row(71, "Shooters", 16) }).skippedNoProfile).to.equal(1)
		end)

		it("releases a session on leave, exactly once", function()
			local players, store = started({ ids = { 81 } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(81) ~= nil
			end)).to.equal(true)
			players._removing:Fire({ UserId = 81 })
			expect(waitUntil(2, function()
				return store.calls().release == 1
			end)).to.equal(true)
			expect(Economy.balanceOf(81)).to.equal(nil)
			-- IDEMPOTENT: a second release does nothing at all.
			Economy.release(81)
			task.wait(0.05)
			expect(store.calls().release).to.equal(1)
			expect(Economy.stats().releases).to.equal(1)
		end)

		-- THE PAY-OUT RUNS INSIDE `Match`'s DISPATCH, BEFORE `applyEffects`, so a yield there would
		-- apply the drive's own effects late.
		it("pays without yielding and without a single store call of its own", function()
			local _, store = started({ ids = { 91 } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(91) ~= nil
			end)).to.equal(true)
			local before = store.calls()
			local marker = 0
			-- `task.defer` AND NOT `task.spawn`: spawn resumes the new thread IMMEDIATELY, so it would
			-- set the marker before `payDrive` was even called. A deferred thread runs at the end of the
			-- current resumption cycle, so `marker == 0` after the call IS the no-yield assertion -- if
			-- `payDrive` had yielded anywhere, the scheduler would have run it.
			task.defer(function()
				marker = 1
			end)
			Economy.payDrive(1, { row(91, "Shooters", 16) })
			expect(marker).to.equal(0)
			-- ...and it really was deferred, so the assertion above is not vacuous.
			task.wait(0.05)
			expect(marker).to.equal(1)
			local after = store.calls()
			expect(after.load).to.equal(before.load)
			-- One LOCAL write, which performs no network call by contract -- and nothing else.
			expect(after.save).to.equal(before.save + 1)
		end)

		-- OFF IS THE GAME BEFORE TASK 170, and the mechanism is the ABSENCE OF DATA.
		it("connects nothing, loads nothing and pays nothing with the flag off", function()
			local _, store = started({ ids = { 101 }, enabled = false })
			task.wait(0.1)
			expect(Economy.isEnabled()).to.equal(false)
			expect(Economy.storeKind()).to.equal("off")
			expect(store.calls().load).to.equal(0)
			local receipt = Economy.payDrive(1, { row(101, "Shooters", 16) })
			expect(receipt.paid).to.equal(0)
			expect(Economy.balanceOf(101)).to.equal(nil)
			expect(next(Economy.balances())).to.equal(nil)
			expect(next(Economy.earned())).to.equal(nil)
			expect(Economy.stats().drivesPaid).to.equal(0)
		end)

		it("hands the drive a view with no way to open a session or write a balance", function()
			started({ ids = { 111 }, seed = { [111] = 7 } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(111) ~= nil
			end)).to.equal(true)
			local view = Economy.view()
			expect(type(view.payDrive)).to.equal("function")
			expect(type(view.balances)).to.equal("function")
			expect(type(view.earned)).to.equal("function")
			-- ...AND WHAT HE HAS BOUGHT (task 178), read-only like the three above: the drive asks it
			-- to answer whether a licensed beater may carry a gun, and it cannot write a set, cannot
			-- buy anything and cannot reach the store.
			expect(type(view.ownedOf)).to.equal("function")
			expect((view :: any).purchase).to.equal(nil)
			expect((view :: any).shopStateFor).to.equal(nil)
			for _, name in ipairs({ "start", "stop", "load", "release", "closeAll", "Store", "CONFIG" }) do
				expect((view :: any)[name]).to.equal(nil)
			end
			-- 10 points x 2 + 10 participation + 25 (he is the only hunter and he scored) = 55.
			view.payDrive(1, { row(111, "Shooters", 10) })
			expect(view.balances()[111]).to.equal(7 + 55)
			expect(view.earned()[111]).to.equal(55)
			-- FROZEN COPIES, so the drive cannot write the owner's tables through them.
			expect(table.isfrozen(view.balances())).to.equal(true)
			expect(table.isfrozen(view.earned())).to.equal(true)
		end)

		-- ------------------------------------------------------------------ the purchase (task 178)
		--
		-- `Economy.purchase` IS THE ONLY WRITER OF EITHER HALF of a purchase, so every case a player
		-- could cause is driven here, against `Store.memory`: no network, no library, no DataStore.
		it("deducts once, records the ownership and saves both halves", function()
			local _, store = started({ ids = { 201 }, seed = { [201] = { coins = 500 } } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(201) ~= nil
			end)).to.equal(true)
			local receipt = Economy.purchase(201, Shop.ITEM.SLUG, { atCounter = true })
			expect(receipt.ok).to.equal(true)
			expect(receipt.price).to.equal(120)
			expect(Economy.balanceOf(201)).to.equal(500 - 120)
			expect(Economy.ownedOf(201)[Shop.ITEM.SLUG]).to.equal(true)
			-- A FROZEN COPY, so no reader can write the set it was handed.
			expect(table.isfrozen(Economy.ownedOf(201))).to.equal(true)
			-- ONE `save`, AND IT IS NOT A NETWORK CALL (the store's own contract). Purchases per
			-- DataStore request: 0.
			expect(store.calls().save).to.equal(1)
			local saved = store.peek(201)
			expect(saved.coins).to.equal(380)
			expect(saved.owned[Shop.ITEM.SLUG]).to.equal(true)
			-- A PURCHASE IS NOT A DRIVE: the hunt count is untouched, which is hazard 2 closed.
			expect(saved.drivesPaid).to.equal(0)
			expect(Economy.huntsOf(201)).to.equal(0)
			expect(Economy.stats().purchases).to.equal(1)
			expect(Economy.stats().coinsSpent).to.equal(120)
		end)

		-- THE DOUBLE CLICK: the first charges, the second is refused and NOTHING is written.
		it("charges a double click once", function()
			started({ ids = { 202 }, seed = { [202] = { coins = 500 } } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(202) ~= nil
			end)).to.equal(true)
			expect(Economy.purchase(202, Shop.ITEM.SLUG, { atCounter = true }).ok).to.equal(true)
			local again = Economy.purchase(202, Shop.ITEM.SLUG, { atCounter = true })
			expect(again.ok).to.equal(false)
			expect(again.refused).to.equal(Shop.REASON.OWNED)
			expect(Economy.balanceOf(202)).to.equal(380)
			expect(Economy.stats().purchases).to.equal(1)
			expect(Economy.stats().refusedBy[Shop.REASON.OWNED]).to.equal(1)
		end)

		it("refuses a poor player, a locked item and a forged id, and writes nothing for any of them", function()
			-- TWO PLAYERS, because LOCKED is asked BEFORE POOR and one man cannot be both at once on
			-- the same row: 203 has walked thirty drives and has no money, 213 has money and has
			-- walked two. (Round 1 of this task got exactly this wrong, which is the order working.)
			local _, store = started({
				ids = { 203, 213 },
				seed = { [203] = { coins = 100, drivesPaid = 30 }, [213] = { coins = 300, drivesPaid = 2 } },
			})
			expect(waitUntil(2, function()
				return Economy.balanceOf(203) ~= nil and Economy.balanceOf(213) ~= nil
			end)).to.equal(true)
			expect(Economy.huntsOf(203)).to.equal(30)
			-- POOR: the rifle is 1500 and he has 100, with the hunts behind him.
			local poor = Economy.purchase(203, Shop.ITEM.RIFLE, { atCounter = true })
			expect(poor.refused).to.equal(Shop.REASON.POOR)
			expect(poor.refusedNumber).to.equal(1500 - 100)
			-- LOCKED before POOR: no amount of coins buys past a hunt gate, so THAT is the line he is
			-- shown -- and 213 can afford the licence's 250 and has walked one drive too few.
			local short = Economy.purchase(213, Shop.ITEM.BEATER_LICENCE, { atCounter = true })
			expect(short.refused).to.equal(Shop.REASON.LOCKED)
			expect(short.refusedNumber).to.equal(1)
			-- A FORGED ID. The second case here used to be the open-sight rifle -- in the catalogue and
			-- not for sale -- and task 196 removed that row at Karen's word, so an id nothing knows is
			-- the only shape of refusal left at this door. `Shop.refuse`'s own NOT_SALE case is driven
			-- against a pretend catalogue in `shop.spec`.
			expect(Economy.purchase(203, "rifle.free", { atCounter = true }).refused).to.equal(Shop.REASON.UNKNOWN)
			expect(Economy.purchase(203, "rifle.open", { atCounter = true }).refused).to.equal(Shop.REASON.UNKNOWN)
			-- ...AND A MAN WHO IS NOT AT THE COUNTER.
			expect(Economy.purchase(203, Shop.ITEM.SLUG, { atCounter = false }).refused).to.equal(Shop.REASON.TOO_FAR)
			expect(Economy.balanceOf(203)).to.equal(100)
			expect(next(Economy.ownedOf(203))).to.equal(nil)
			expect(store.calls().save).to.equal(0)
			expect(Economy.stats().purchases).to.equal(0)
			expect(Economy.stats().purchasesRefused).to.equal(5)
		end)

		-- NO SESSION, NO PURCHASE, AND NO COIN INVENTED. `balanceOf` is nil, which is *"not the same
		-- fact as a balance of zero"*, and a man who leaves between the request and the commit falls
		-- into exactly this branch -- `Economy.release` has already dropped his row.
		it("refuses a purchase with no open profile, before and after a release", function()
			local players = started({ ids = { 204 }, refuse = { [204] = true } })
			expect(waitUntil(2, function()
				return Economy.stats().loadsRefused == 1
			end)).to.equal(true)
			local refused = Economy.purchase(204, Shop.ITEM.SLUG, { atCounter = true })
			expect(refused.refused).to.equal(Shop.REASON.NO_PROFILE)
			expect(Economy.balanceOf(204)).to.equal(nil)
			expect(Economy.ownedOf(204)).to.equal(nil)
			expect(Economy.huntsOf(204)).to.equal(nil)
			local _ = players

			-- ...AND THE SAME ANSWER FOR A MAN WHO HAS JUST LEFT.
			local second, store = started({ ids = { 205 }, seed = { [205] = { coins = 500 } } })
			local _ = second
			expect(waitUntil(2, function()
				return Economy.balanceOf(205) ~= nil
			end)).to.equal(true)
			Economy.release(205)
			expect(Economy.purchase(205, Shop.ITEM.SLUG, { atCounter = true }).refused).to.equal(Shop.REASON.NO_PROFILE)
			expect(store.calls().save).to.equal(0)
		end)

		it("refuses every purchase with the coins off, and reads the whole shop as closed", function()
			started({ ids = { 206 }, enabled = false })
			task.wait(0.1)
			local receipt = Economy.purchase(206, Shop.ITEM.SLUG, { atCounter = true })
			expect(receipt.refused).to.equal(Shop.REASON.CLOSED)
			-- ...AND THE PANEL IS TOLD THE SAME THING IN ONE LINE rather than five refusals.
			local state = Economy.shopStateFor(206, receipt)
			expect(state.coinsOn).to.equal(false)
			expect(state.balance).to.equal(nil)
			expect(state.refused).to.equal(Shop.REASON.CLOSED)
		end)

		-- THE COMPLETED-HUNT COUNT IS `drivesPaid`, and the pay-out is the one event that raises it.
		it("counts one completed hunt per paid drive, and none for a purchase", function()
			local _, store = started({ ids = { 207 }, seed = { [207] = { coins = 500, drivesPaid = 7 } } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(207) ~= nil
			end)).to.equal(true)
			expect(Economy.huntsOf(207)).to.equal(7)
			Economy.payDrive(1, { row(207, "Shooters", 10) })
			expect(Economy.huntsOf(207)).to.equal(8)
			expect(store.peek(207).drivesPaid).to.equal(8)
			-- ...and the total earned is the store's own number now, incremented where the DELTA is
			-- known rather than inside `save`.
			expect(store.peek(207).coinsEarnedTotal).to.equal(55)
			Economy.purchase(207, Shop.ITEM.SLUG, { atCounter = true })
			expect(Economy.huntsOf(207)).to.equal(8)
			expect(store.peek(207).drivesPaid).to.equal(8)
			-- A SECOND DRIVE RAISES IT AGAIN; the same drive number does not (the double-pay guard).
			Economy.payDrive(1, { row(207, "Shooters", 10) })
			expect(Economy.huntsOf(207)).to.equal(8)
			Economy.payDrive(2, { row(207, "Shooters", 10) })
			expect(Economy.huntsOf(207)).to.equal(9)
		end)

		-- WHAT THE PANEL IS SENT, for one player, built by the pure `Shop.rowsFor` on this side.
		it("builds one player's own shop payload, with the rows already decided", function()
			started({
				ids = { 208 },
				seed = { [208] = { coins = 300, drivesPaid = 30, owned = { [Shop.ITEM.SLUG] = true } } },
			})
			expect(waitUntil(2, function()
				return Economy.balanceOf(208) ~= nil
			end)).to.equal(true)
			local state = Economy.shopStateFor(208, nil)
			expect(state.coinsOn).to.equal(true)
			expect(state.balance).to.equal(300)
			expect(state.hunts).to.equal(30)
			expect(#state.rows).to.equal(#Shop.ORDER)
			for _, wire in ipairs(state.rows) do
				if wire.id == Shop.ITEM.SLUG then
					expect(wire.owned).to.equal(true)
					expect(wire.buyable).to.equal(false)
				elseif wire.id == Shop.ITEM.BEATER_LICENCE then
					-- $250 of his $300, and 30 hunts past its gate of 3: the one he can buy.
					expect(wire.buyable).to.equal(true)
				elseif wire.id == Shop.ITEM.RIFLE then
					-- 30 hunts is enough, $300 is not.
					expect(wire.locked).to.equal(false)
					expect(wire.afford).to.equal(false)
					expect(wire.buyable).to.equal(false)
				elseif wire.id == Shop.ITEM.RED_STAG then
					-- ON SALE SINCE TASK 223, AND THAT IS THE SAME INVARIANT, SATISFIED. Task 221
					-- shipped this row `sale = false` because `Licences.ROWS.reddeer.shipped` was
					-- false -- there was no deer. Karen bought one on 2026-10-20 and the stag, the
					-- hind and the calf publish `Species = "reddeer"`, so the row went on sale in
					-- the same commit as the animal. `shop.spec` still drives the refused arm with
					-- a hand-made table.
					expect(wire.sale).to.equal(true)
					expect(wire.buyable).to.equal(false)
				elseif wire.id == Shop.ITEM.ALWAYS_HUNTER then
					-- 30 hunts is EXACTLY its gate, so what stops him is the money and not the gate.
					expect(wire.locked).to.equal(false)
					expect(wire.buyable).to.equal(false)
				end
				-- THE RED HAT IS NOT ON THE WIRE AT ALL (task 221): retired, and invisible to the
				-- panel.
				expect(wire.id).never.to.equal(Shop.ITEM.HAT_RED)
			end
			-- A SEEDED SET IS READ BACK, which is the whole load/save round trip for the new field.
			expect(Economy.ownedOf(208)[Shop.ITEM.SLUG]).to.equal(true)
		end)

		-- ------------------------------------------------------ the grant path (task 221, round 1 finding 3)
		--
		-- THE REVIEWER: *"the task's two new `Economy` seams have no test ... the idempotent branch
		-- is unreachable through `purchase` -- `ShopData.refuse` answers `OWNED` first -- so
		-- `already = true`, the documented `ProcessReceipt` contract this task exists to leave for
		-- 222, is never executed"*. Right on both counts. These cases call `grant` DIRECTLY, which
		-- is exactly the door task 222's `ProcessReceipt` will come through.
		it("grants once, answers the second delivery as a success, and writes nothing twice", function()
			local _, store = started({ ids = { 401 }, seed = { [401] = { coins = 5000 } } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(401) ~= nil
			end)).to.equal(true)

			-- FIRST DELIVERY: the set is written and the profile saved once.
			local first = Economy.grant(401, Shop.ITEM.RIFLE, Economy.SOURCE.ROBUX)
			expect(first.ok).to.equal(true)
			expect(first.item).to.equal(Shop.ITEM.RIFLE)
			expect(first.already).to.equal(nil)
			expect(Economy.ownedOf(401)[Shop.ITEM.RIFLE]).to.equal(true)
			expect(store.calls().save).to.equal(1)
			-- A ROBUX GRANT DEBITS NOTHING OF OURS: the balance is untouched, which is the whole
			-- reason `grant` is not `purchase`.
			expect(Economy.balanceOf(401)).to.equal(5000)

			-- SECOND DELIVERY OF THE SAME RECEIPT: a SUCCESS, and nothing written. A refusal here
			-- would make Roblox retry for ever (the documented contract, research note source 1).
			local again = Economy.grant(401, Shop.ITEM.RIFLE, Economy.SOURCE.ROBUX)
			expect(again.ok).to.equal(true)
			expect(again.already).to.equal(true)
			expect(store.calls().save).to.equal(1)
			expect(Economy.stats().grantsAlready).to.equal(1)
			expect(Economy.stats().grants).to.equal(1)

			-- WHERE EACH ONE CAME FROM, so "how many arrived by Robux" is a number the day 222 lands.
			expect(Economy.stats().grantsBySource[Economy.SOURCE.ROBUX]).to.equal(1)
			expect(Economy.stats().grantsBySource[Economy.SOURCE.MONEY]).to.equal(nil)
		end)

		it("refuses to grant what nobody may own, by either door", function()
			local _, store = started({ ids = { 402 }, seed = { [402] = { coins = 5000 } } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(402) ~= nil
			end)).to.equal(true)

			-- THE DEER LICENCE: the animal arrived in task 223, so `NOT_SALE` no longer refuses it
			-- -- which is what that reason was protecting until the deer existed. It is granted to
			-- a DIFFERENT player here, because this case's last two assertions are that 402 bought
			-- nothing and that nothing was saved.
			local stag = Economy.grant(403, Shop.ITEM.RED_STAG, Economy.SOURCE.ROBUX)
			expect(stag.refused).never.to.equal(Shop.REASON.NOT_SALE)

			-- A RETIRED ROW: Karen took the red hat off the shelf, so it cannot be granted either --
			-- `ShopData.row` answers only what is for sale.
			local hat = Economy.grant(402, Shop.ITEM.HAT_RED, Economy.SOURCE.ROBUX)
			expect(hat.ok).to.equal(false)
			expect(hat.refused).to.equal(Shop.REASON.UNKNOWN)

			-- A FORGED ID, and a man with no open session.
			expect(Economy.grant(402, "no.such.row", Economy.SOURCE.ROBUX).refused).to.equal(Shop.REASON.UNKNOWN)
			expect(Economy.grant(999, Shop.ITEM.RIFLE, Economy.SOURCE.ROBUX).refused).to.equal(Shop.REASON.NO_PROFILE)

			expect(next(Economy.ownedOf(402))).to.equal(nil)
			expect(store.calls().save).to.equal(0)
		end)

		it("is the one writer, so a purchase goes through it and saves once", function()
			local _, store = started({ ids = { 403 }, seed = { [403] = { coins = 5000 } } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(403) ~= nil
			end)).to.equal(true)
			local receipt = Economy.purchase(403, Shop.ITEM.SLUG, { atCounter = true })
			expect(receipt.ok).to.equal(true)
			expect(receipt.price).to.equal(120)
			expect(Economy.balanceOf(403)).to.equal(5000 - 120)
			-- ONE SAVE WITH BOTH HALVES, not one per half.
			expect(store.calls().save).to.equal(1)
			local saved = store.peek(403)
			expect(saved.coins).to.equal(5000 - 120)
			expect(saved.owned[Shop.ITEM.SLUG]).to.equal(true)
			-- ...AND IT WAS COUNTED AS A GRANT FROM THE MONEY DOOR.
			expect(Economy.stats().grants).to.equal(1)
			expect(Economy.stats().grantsBySource[Economy.SOURCE.MONEY]).to.equal(1)
		end)

		-- ------------------------------------------------------ who bought the hunter's place (221)
		it("projects the always-hunters off the profiles, frozen, and rebuilds when one changes", function()
			local _, store = started({
				ids = { 404, 405 },
				seed = {
					[404] = { coins = 9000 },
					-- HE ALREADY OWNS IT, so the projection has something to find at load.
					[405] = { coins = 100, owned = { [Shop.ITEM.ALWAYS_HUNTER] = true } },
				},
			})
			local _ = store
			expect(waitUntil(2, function()
				return Economy.balanceOf(404) ~= nil and Economy.balanceOf(405) ~= nil
			end)).to.equal(true)

			local first = Economy.alwaysHunters()
			expect(first[405]).to.equal(true)
			expect(first[404]).to.equal(nil)
			-- FROZEN, so no reader can write the table it was handed -- `owedTeams`' own discipline.
			expect(table.isfrozen(first)).to.equal(true)
			-- MEMOISED: the same table comes back until something invalidates it.
			expect(Economy.alwaysHunters()).to.equal(first)

			-- A GRANT INVALIDATES IT, and the memo is REBUILT rather than mutated -- so a reader
			-- still holding `first` holds a correct snapshot of the moment it asked.
			Economy.grant(404, Shop.ITEM.ALWAYS_HUNTER, Economy.SOURCE.ROBUX)
			local second = Economy.alwaysHunters()
			expect(second).never.to.equal(first)
			expect(second[404]).to.equal(true)
			expect(first[404]).to.equal(nil)

			-- ...AND A PACKAGE THAT COVERS IT COUNTS, because the projection reads the merged grants.
			Economy.grant(404, Shop.ITEM.SLUG, Economy.SOURCE.MONEY)
			expect(Economy.alwaysHunters()[404]).to.equal(true)

			-- THE ROW GOES WITH THE SESSION: a released player is not owed anything.
			Economy.release(405)
			expect(Economy.alwaysHunters()[405]).to.equal(nil)
			Economy.stop()
			expect(next(Economy.alwaysHunters())).to.equal(nil)
		end)

		it("answers an empty set with the shop off, which is the game before this task", function()
			started({ ids = { 406 }, enabled = false })
			expect(next(Economy.alwaysHunters())).to.equal(nil)
			expect(table.isfrozen(Economy.alwaysHunters())).to.equal(true)
			-- ...and nothing can be granted either.
			expect(Economy.grant(406, Shop.ITEM.RIFLE, Economy.SOURCE.ROBUX).refused).to.equal(Shop.REASON.CLOSED)
		end)

		it("drops the set, the hunts and the balance together when a session is lost or stopped", function()
			local _, store = started({ ids = { 209 }, seed = { [209] = { coins = 500, drivesPaid = 4 } } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(209) ~= nil
			end)).to.equal(true)
			Economy.purchase(209, Shop.ITEM.SLUG, { atCounter = true })
			expect(Economy.ownedOf(209)).to.be.ok()
			-- A SESSION ANOTHER SERVER TOOK: no further change may be made to that profile, so the
			-- row goes -- and the readers then see nil, which is "nobody answered" and leaves his gun
			-- exactly as it is.
			store.loseSession(209)
			expect(Economy.ownedOf(209)).to.equal(nil)
			expect(Economy.huntsOf(209)).to.equal(nil)
			expect(Economy.balanceOf(209)).to.equal(nil)
		end)

		-- ------------------------------------------------------- the Studio test grant (task 178)
		--
		-- THE DIRECTOR, 2026-10-14: in Studio the store is the in-memory one and every session starts
		-- a player at nought, so with `SHOP` on Karen can walk up to the counter and afford nothing
		-- she is meant to try. This is the staging fixture for that, and the cases below are the
		-- evidence that it cannot reach a live server.
		it("is impossible on a live server, whatever the attribute says", function()
			-- THE ONE ASSERTION THAT MATTERS. Inside Studio `IsStudio()` is always true, so this
			-- pure predicate is the only shape in which the live branch is provable at all --
			-- `Economy.storeKindFor`'s own argument, and the same fact gates both: where a grant is
			-- possible nothing is saved, and where something is saved no grant is possible.
			expect(Economy.testGrantFor(false, true)).to.equal(nil)
			expect(Economy.testGrantFor(false, false)).to.equal(nil)
			-- ...and in Studio it needs the attribute to be the BOOLEAN true: a stale `false`, a
			-- string, a number or nothing at all grants nobody anything.
			expect(Economy.testGrantFor(true, nil)).to.equal(nil)
			expect(Economy.testGrantFor(true, false)).to.equal(nil)
			expect(Economy.testGrantFor(true, "true")).to.equal(nil)
			expect(Economy.testGrantFor(true, 1)).to.equal(nil)
			local grant = Economy.testGrantFor(true, true)
			expect(grant).to.be.ok()
			expect((grant :: any).coins).to.equal(Economy.CONFIG.TEST_GRANT.coins)
			expect((grant :: any).hunts).to.equal(Economy.CONFIG.TEST_GRANT.hunts)
			-- IT IS NOT A `DHFlag_`, and that is deliberate: it is a test fixture, the shape
			-- `DHForestStartRole` has, not a feature switch that `tools/flags.py` clears and the
			-- harness refuses to run against.
			expect(Economy.TEST_GRANT_ATTRIBUTE).to.equal("DHShopTestGrant")
			expect(string.find(Economy.TEST_GRANT_ATTRIBUTE, "DHFlag_", 1, true)).to.equal(nil)
			-- ...AND IT UNLOCKS THE WHOLE CATALOGUE WITHOUT BUYING ANY OF IT (task 221): $12,000
			-- covers every row that is for sale and 30 hunts is the highest gate. ASSERTED AGAINST
			-- THE CATALOGUE AND NOT AGAINST ITSELF, so the grant cannot fall behind a row somebody
			-- adds later without the harness saying so.
			local total, highest = 0, 0
			for _, id in ipairs(Shop.ORDER) do
				local item = Shop.ROWS[id]
				if item.sale then
					total += item.price
					highest = math.max(highest, item.hunts)
				end
			end
			-- 11495 + 750 SINCE TASK 223 (the DEER LICENCE), + 650 SINCE TASK 224 (the LEVER RIFLE),
			-- + 500 SINCE TASK 225 (the SEMI-AUTOMATIC SHOTGUN).
			expect(total).to.equal(13395)
			expect(highest).to.equal(30)
			-- ...AND THE TEST GRANT HAD TO MOVE WITH IT, which is what this pair of assertions is
			-- for: the grant exists so Karen can buy EVERY rung and see every state, and at 13000
			-- against a 13395 catalogue she would have been 395 short of the last one.
			expect(Economy.CONFIG.TEST_GRANT.coins).to.equal(13500)
			expect(Economy.CONFIG.TEST_GRANT.coins >= total).to.equal(true)
			-- EXACTLY the highest gate, not above it: every rung is unlocked and nothing is bought
			-- FOR her, so she still presses every button and sees every state.
			expect(Economy.CONFIG.TEST_GRANT.hunts).to.equal(highest)
		end)

		it("tops a Studio session up without buying anything or saving anything", function()
			local _, store = started({
				ids = { 301, 302 },
				-- 302 has already earned more than the grant and walked more drives than it gives.
				seed = { [301] = { coins = 5 }, [302] = { coins = 9000, drivesPaid = 40 } },
				testGrant = { coins = 2000, hunts = 25 },
			})
			expect(waitUntil(2, function()
				return Economy.balanceOf(301) ~= nil and Economy.balanceOf(302) ~= nil
			end)).to.equal(true)
			-- RAISED, not set: the poor man is topped up...
			expect(Economy.balanceOf(301)).to.equal(2000)
			expect(Economy.huntsOf(301)).to.equal(25)
			-- ...and the rich one keeps everything he earned.
			expect(Economy.balanceOf(302)).to.equal(9000)
			expect(Economy.huntsOf(302)).to.equal(40)
			expect(Economy.stats().testGrants).to.equal(2)
			-- NOTHING IS BOUGHT FOR HIM: every item is still a button he has to press.
			expect(next(Economy.ownedOf(301))).to.equal(nil)
			-- ...AND NOTHING IS SAVED. The grant touches the in-memory copy only, so the key still
			-- holds what he really earned.
			expect(store.calls().save).to.equal(0)
			expect(store.peek(301).coins).to.equal(5)
			-- ...and he can now buy what the shop sells, which is the whole point of the fixture.
			expect(Economy.purchase(301, Shop.ITEM.RIFLE, { atCounter = true }).ok).to.equal(true)
			expect(Economy.balanceOf(301)).to.equal(500)
		end)

		it("grants nothing when it is not asked for, which is every harness run", function()
			started({ ids = { 303 }, seed = { [303] = { coins = 5 } } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(303) ~= nil
			end)).to.equal(true)
			expect(Economy.balanceOf(303)).to.equal(5)
			expect(Economy.huntsOf(303)).to.equal(0)
			expect(Economy.stats().testGrants).to.equal(0)
		end)

		it("refuses to start twice", function()
			started({ ids = { 121 } })
			expect(function()
				Economy.start({ store = Store.memory() })
			end).to.throw()
		end)
	end)

	-- THE ONE ASSERTION THAT SAYS A LIVE SERVER TAKES THE REAL STORE AND STUDIO CAN NEVER. Inside
	-- Studio `RunService:IsStudio()` is always true, so this is the only shape in which the live
	-- branch is provable at all -- `Match.quickTestEnabled`'s own argument, verbatim.
	describe("which store a run takes", function()
		it("is memory in Studio and live on a real server, as a pure predicate", function()
			expect(Economy.storeKindFor(true)).to.equal("memory")
			expect(Economy.storeKindFor(false)).to.equal("live")
		end)

		it("is memory in THIS run, so no harness run can write a live key", function()
			local RunService = game:GetService("RunService")
			expect(RunService:IsStudio()).to.equal(true)
			expect(Economy.storeKindFor(RunService:IsStudio())).to.equal("memory")
		end)
	end)

	describe("the numbers this spec asserts", function()
		it("are the numbers production ships", function()
			for key, value in pairs(CONFIG) do
				expect((Economy.CONFIG :: any)[key]).to.equal(value)
			end
			-- A BOAR IS A ROUND NUMBER, which is the whole reason the rate is 2: a male is 10 points.
			expect(Economy.CONFIG.COINS_PER_POINT * 10).to.equal(20)
			-- THE KEY FITS ROBLOX'S DOCUMENTED CAP at a userId far larger than it can issue: 19 digits
			-- plus "player_" is 26 characters against 50 (the limits page: key name length *"50"*).
			expect(Store.keyFor(1234567)).to.equal("player_1234567")
			expect(#Store.keyFor(9999999999999999999) <= Economy.CONFIG.KEY_MAX).to.equal(true)
			expect(Economy.CONFIG.KEY_MAX).to.equal(50)
			-- FROZEN: nothing in the repository may assign a rate at run time.
			expect(function()
				(Economy.CONFIG :: any).COINS_PER_POINT = 99
			end).to.throw()
		end)

		it("was born behind a flag that was off, and since task 233 that flag is LIT", function()
			-- FLIPPED ON 2026-10-21 (task 233, "v1 default"): Karen's v1 decisions put money in the
			-- game, so a server without her place attributes has to pay a drive. `owner` is asserted
			-- unchanged beside the flip, so a row somebody rewrote cannot pass as one somebody lit.
			--
			-- THE LINE THAT MATTERS MOST IS THE LAST ONE, and it is unchanged: the module's
			-- `ENABLED` is the flag and nothing else, read ONCE at the boundary. Every case in this
			-- file still drives both branches by parameter (`enabled = true` / `false` through
			-- `Economy.start`'s world), because no harness run may set a `DHFlag_` override at all --
			-- so the flip changes which branch the LIVE build takes and no case's coverage.
			local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
			expect(Flags.DEFAULTS.COINS).to.be.ok()
			expect(Flags.DEFAULTS.COINS.default).to.equal(true)
			expect(Flags.DEFAULTS.COINS.owner).to.equal("ServerScriptService.Economy")
			expect(Economy.CONFIG.ENABLED).to.equal(Flags.isOn("COINS"))
		end)
	end)
	-- ---------------------------------------------------------------- the stored turn (task 217)
	--
	-- KAREN, 2026-10-11: *"ROLES ROTATE: you start as a hunter, next round you are a beater; it is
	-- REMEMBERED across logout/login (no cheating back to hunter) -- persistent per player
	-- (DataStore)."*
	--
	-- EVERY CASE HERE DRIVES THE ON BRANCH BY PARAMETER (`enabled = true`), and it has to: `test`
	-- and `test2` both REFUSE to start while a `DHFlag_` override is set, so no harness run can ever
	-- have `COINS` on (design hazard 11). That is `docs/design/feature-flags.md`'s own rule -- a
	-- flagged path must be reachable by parameter as well as by flag -- and it is why the flag-OFF
	-- case below is driven the same way.
	-- Design: docs/design/role-rotation.md (sections 4.4, 11.3)
	describe("the role a player is owed", function()
		local function started(options)
			local opts = options or {}
			local players = fakePlayers(opts.ids or { 1 })
			local store = Store.memory({ seed = opts.seed, refuse = opts.refuse })
			Economy.stop()
			Economy.start({
				store = store,
				players = players,
				enabled = opts.enabled ~= false,
				testGrant = false,
			})
			return players, store
		end

		afterEach(function()
			Economy.stop()
		end)

		-- THE ONE VALIDATOR, and it is the only thing standing between a corrupted profile and a man
		-- on the wrong side. `nil` out MEANS *no turn stored*, which is the brand-new-player path and
		-- already has to work -- so a bad value is never an error, never a crash and never a guess.
		it("accepts only the two team names, and reads everything else as no turn stored", function()
			expect(Economy.teamFromRecord("Drivers")).to.equal("Drivers")
			expect(Economy.teamFromRecord("Shooters")).to.equal("Shooters")
			expect(Economy.teamFromRecord("")).to.equal(nil) -- the template's own default
			expect(Economy.teamFromRecord(nil)).to.equal(nil)
			expect(Economy.teamFromRecord("hunter")).to.equal(nil) -- Karen's word is not a team name
			expect(Economy.teamFromRecord("beater")).to.equal(nil)
			expect(Economy.teamFromRecord("drivers")).to.equal(nil) -- and the case matters
			expect(Economy.teamFromRecord(7)).to.equal(nil)
			expect(Economy.teamFromRecord(true)).to.equal(nil)
			expect(Economy.teamFromRecord({})).to.equal(nil)
		end)

		it("installs the row from a seeded profile at load", function()
			started({ ids = { 51, 52 }, seed = { [51] = { nextTeam = "Drivers" }, [52] = { coins = 10 } } })
			expect(waitUntil(2, function()
				return Economy.owedTeams()[51] ~= nil
			end)).to.equal(true)
			expect(Economy.owedTeams()[51]).to.equal("Drivers")
			-- A profile with no turn stored has NO ROW, which is not the same fact as a team: the
			-- drive reads nil as "nobody answered" and the roster decides.
			expect(Economy.owedTeams()[52]).to.equal(nil)
		end)

		it("hands out a FROZEN table, and the same one until something writes", function()
			started({ ids = { 53 }, seed = { [53] = { nextTeam = "Shooters" } } })
			expect(waitUntil(2, function()
				return Economy.owedTeams()[53] ~= nil
			end)).to.equal(true)
			local first = Economy.owedTeams()
			expect(function()
				(first :: any)[999] = "Drivers"
			end).to.throw()
			-- MEMOISED, and that is a measurement rather than a preference: `Match.dispatch` reads
			-- this on EVERY event, and while TASKS.md 214a(a) is open that dispatch is stepped at
			-- ~15x `MATCH_STEP_HZ`. Identity is the assertion, because a deep compare would pass for
			-- a fresh clone per call -- which is the thing this is here to forbid.
			expect(Economy.owedTeams()).to.equal(first)
			expect(Economy.noteNextTeams({ [53] = "Drivers" })).to.equal(1)
			local second = Economy.owedTeams()
			expect(second).never.to.equal(first)
			expect(second[53]).to.equal("Drivers")
			-- ...and a write that changes NOTHING does not throw the memo away.
			expect(Economy.noteNextTeams({ [53] = "Drivers" })).to.equal(1)
			expect(Economy.owedTeams()).to.equal(second)
		end)

		-- THE ROUND TRIP, THROUGH THE OWNER. It is the feature: "two drives in a row, hunter then
		-- beater" is already true without this task (the in-memory swap), so the only evidence of
		-- the record is that it SURVIVES a release and a reload (design hazard 10).
		it("writes the turn to the key, and reads it back after a release and a reload", function()
			local players, store = started({ ids = { 54 } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(54) ~= nil
			end)).to.equal(true)
			local savesBefore = store.calls().save
			expect(Economy.noteNextTeams({ [54] = "Drivers" })).to.equal(1)
			expect((store.peek :: any)(54).nextTeam).to.equal("Drivers")
			expect(store.calls().save).to.equal(savesBefore + 1)

			-- HE LEAVES. The in-memory row goes with the session and the key keeps the value.
			Economy.release(54)
			expect(Economy.owedTeams()[54]).to.equal(nil)
			expect((store.peek :: any)(54).nextTeam).to.equal("Drivers")

			-- ...AND HE COMES BACK. `Store.memory`'s saved table outlives a release, so this is a
			-- real round trip and not a simulation of one.
			Economy.load(players:GetPlayers()[1] :: any)
			expect(waitUntil(2, function()
				return Economy.owedTeams()[54] ~= nil
			end)).to.equal(true)
			expect(Economy.owedTeams()[54]).to.equal("Drivers")
		end)

		it("writes every accepted row and says how many, one `save` each", function()
			local _, store = started({ ids = { 55, 56 } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(55) ~= nil and Economy.balanceOf(56) ~= nil
			end)).to.equal(true)
			local savesBefore = store.calls().save
			expect(Economy.noteNextTeams({ [55] = "Drivers", [56] = "Shooters" })).to.equal(2)
			-- EXACTLY ONE LOCAL `save` PER ROW AND NO NETWORK CALL AT ALL: `Store.save` writes the
			-- server-local copy and ProfileStore's own auto-save does the writing (design section
			-- 8.6). Over a complete drive of N players that is 2N -- one at each edge.
			expect(store.calls().save).to.equal(savesBefore + 2)
			expect(Economy.stats().nextTeamsWritten).to.equal(2)
		end)

		-- A RACE ON THE PROFILE LOAD COSTS ONE DRIVE AND NEVER THE RECORD (design section 5.4):
		-- `Economy.load` runs in a spawned thread and the store yields, so a player can be assigned
		-- before his profile answers. He is skipped here, his key is NOT overwritten, and the drive's
		-- end writes `other(what he played)` -- which for a turn that was not honoured is the turn
		-- itself.
		it("skips a userId with no open session, counts it, and leaves his key alone", function()
			local _, store = started({ ids = { 57 }, seed = { [57] = { nextTeam = "Drivers" } } })
			expect(waitUntil(2, function()
				return Economy.owedTeams()[57] ~= nil
			end)).to.equal(true)
			local savesBefore = store.calls().save
			-- 99 is not on this server at all.
			expect(Economy.noteNextTeams({ [99] = "Shooters" })).to.equal(0)
			expect(Economy.stats().nextTeamSkippedNoProfile).to.equal(1)
			expect(store.calls().save).to.equal(savesBefore)
			expect((store.peek :: any)(57).nextTeam).to.equal("Drivers")
		end)

		it("refuses a value that is not a team, counts it, and writes nothing", function()
			local _, store = started({ ids = { 58 } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(58) ~= nil
			end)).to.equal(true)
			local savesBefore = store.calls().save
			expect(Economy.noteNextTeams({ [58] = "hunter" })).to.equal(0)
			expect(Economy.stats().nextTeamRefused).to.equal(1)
			expect(store.calls().save).to.equal(savesBefore)
			expect(Economy.owedTeams()[58]).to.equal(nil)
		end)

		it("does not retain the caller's table", function()
			started({ ids = { 59 } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(59) ~= nil
			end)).to.equal(true)
			local asked = { [59] = "Drivers" }
			Economy.noteNextTeams(asked)
			asked[59] = "Shooters"
			asked[60] = "Drivers"
			expect(Economy.owedTeams()[59]).to.equal("Drivers")
			expect(Economy.owedTeams()[60]).to.equal(nil)
		end)

		-- A SESSION ANOTHER SERVER TAKES OFF US. The row goes the instant ownership moves, so a
		-- `Store.save` into a dead table cannot happen -- and he reads as *no turn stored* until a
		-- session opens again (design hazard 3).
		it("drops the row when the session is lost, and never writes into a dead profile", function()
			local _, store = started({ ids = { 61 }, seed = { [61] = { nextTeam = "Drivers" } } })
			expect(waitUntil(2, function()
				return Economy.owedTeams()[61] ~= nil
			end)).to.equal(true)
			local savesBefore = store.calls().save;
			(store.loseSession :: any)(61)
			expect(Economy.stats().sessionsLost).to.equal(1)
			expect(Economy.owedTeams()[61]).to.equal(nil)
			expect(Economy.noteNextTeams({ [61] = "Shooters" })).to.equal(0)
			expect(store.calls().save).to.equal(savesBefore)
		end)

		it("empties the table on release, closeAll and stop", function()
			started({ ids = { 62 }, seed = { [62] = { nextTeam = "Drivers" } } })
			expect(waitUntil(2, function()
				return Economy.owedTeams()[62] ~= nil
			end)).to.equal(true)
			Economy.closeAll()
			expect(next(Economy.owedTeams())).to.equal(nil)
			Economy.stop()
			expect(next(Economy.owedTeams())).to.equal(nil)
		end)

		-- THE FLAG-OFF STORY'S FIRST LINK (design section 7): off, nothing is read and nothing is
		-- written, so `Roster.previousFrom` is handed an empty table and answers `previous` BY
		-- IDENTITY -- which is the whole claim that the drive's assignment is unchanged.
		it("answers an empty frozen table with the money off, and writes nothing", function()
			local _, store = started({ ids = { 63 }, seed = { [63] = { nextTeam = "Drivers" } }, enabled = false })
			expect(Economy.isEnabled()).to.equal(false)
			local owed = Economy.owedTeams()
			expect(next(owed)).to.equal(nil)
			expect(table.isfrozen(owed :: any)).to.equal(true)
			expect(Economy.noteNextTeams({ [63] = "Drivers" })).to.equal(0)
			expect(store.calls().save).to.equal(0)
			expect(store.calls().load).to.equal(0)
			expect(Economy.stats().nextTeamsWritten).to.equal(0)
		end)

		-- NEITHER THE PAY-OUT NOR A PURCHASE MAY TOUCH THE TURN (design hazard 6). `Store.save`
		-- writes exactly the fields it is told and derives nothing, which is the discipline task 178
		-- forced on it after a purchase started counting as a completed hunt.
		it("is left alone by a pay-out and by a purchase", function()
			local _, store = started({ ids = { 64 }, seed = { [64] = { coins = 2000, drivesPaid = 25 } } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(64) ~= nil
			end)).to.equal(true)
			Economy.noteNextTeams({ [64] = "Drivers" })
			Economy.payDrive(1, { row(64, "Shooters", 16) })
			expect((store.peek :: any)(64).nextTeam).to.equal("Drivers")
			local receipt = Economy.purchase(64, Shop.ITEM.SLUG, { atCounter = true })
			expect(receipt.ok).to.equal(true)
			expect((store.peek :: any)(64).nextTeam).to.equal("Drivers")
			expect(Economy.owedTeams()[64]).to.equal("Drivers")
		end)

		-- THE VIEW'S EXACT KEY SET, so a setter cannot be slipped onto it later without a failing
		-- case. The drive gets four reads, one named write for the money and one named write for the
		-- turn -- and no `start`, no `stop`, no `Store`, no `release` and no balance setter.
		it("reaches the drive through a view of exactly seven functions", function()
			started({ ids = { 65 } })
			local view = Economy.view()
			local expected = {
				payDrive = true,
				balances = true,
				earned = true,
				enabled = true,
				ownedOf = true,
				owedTeams = true,
				-- WHO BOUGHT THE HUNTER'S PLACE (task 221): the eighth read-only member, and still
				-- nothing the drive can write through.
				alwaysHunters = true,
				noteNextTeams = true,
			}
			local seen = 0
			for key, value in pairs(view :: any) do
				expect(expected[key]).to.equal(true)
				expect(type(value)).to.equal("function")
				seen += 1
			end
			expect(seen).to.equal(8)
		end)

		it("and that view reads and writes the turn the owner holds", function()
			local _, store = started({ ids = { 66 } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(66) ~= nil
			end)).to.equal(true)
			local view = Economy.view()
			view.noteNextTeams({ [66] = "Drivers" })
			expect(view.owedTeams()[66]).to.equal("Drivers")
			expect((store.peek :: any)(66).nextTeam).to.equal("Drivers")
		end)
	end)
	describe("a fine comes off the drive's pay-out (task 250)", function()
		-- KAREN, 2026-10-23: *"take big amount of money"*. `Coins.forRow` subtracts dollars FLAT --
		-- never through `COINS_PER_POINT`, because a flat charge whose size depends on an exchange
		-- rate is not a flat charge.
		local CFG = Economy.CONFIG

		it("subtracts the fine after the points and the participation", function()
			local clean = Coins.forRow(10, false, CFG)
			expect(Coins.forRow(10, false, CFG, 500)).to.equal(clean - 500)
			-- the first-place bonus is paid and THEN fined: a man can top the board and still owe
			expect(Coins.forRow(10, true, CFG, 500)).to.equal(clean + CFG.FIRST_PLACE - 500)
		end)

		it("is a FLAT charge and not a points one", function()
			-- the difference that matters: 500 dollars, not 500 x COINS_PER_POINT
			expect(CFG.COINS_PER_POINT).to.equal(2)
			expect(Coins.forRow(0, false, CFG) - Coins.forRow(0, false, CFG, 500)).to.equal(500)
		end)

		it("leaves a row with no fine arithmetically untouched", function()
			for _, fines in ipairs({ 0, -1 }) do
				expect(Coins.forRow(10, false, CFG, fines)).to.equal(Coins.forRow(10, false, CFG))
			end
			expect(Coins.forRow(10, false, CFG, nil)).to.equal(Coins.forRow(10, false, CFG))
		end)

		it("reads the fine off the board row, so no coin is fined where no point was scored", function()
			local rows = {
				{ userId = 101, team = "Shooters", points = 10, fines = 500 },
				{ userId = 102, team = "Shooters", points = 10 },
			}
			local breakdown = Coins.forDrive(rows, CFG)
			expect(breakdown.coins[102] - breakdown.coins[101]).to.equal(500)
		end)

		it("takes the drive to nothing but never the balance below zero", function()
			-- `Economy.CONFIG.FLOOR` is the one clamp in this system, and a $1000 fine is the first
			-- number in the game big enough to reach it from a normal balance.
			expect(CFG.FLOOR).to.equal(0)
			local drive = Coins.forRow(10, false, CFG, 1000)
			expect(drive < 0).to.equal(true)
			expect(Coins.credit(0, drive, CFG)).to.equal(0)
			expect(Coins.credit(200, drive, CFG)).to.equal(0)
			-- and a balance big enough just pays it
			expect(Coins.credit(5000, drive, CFG)).to.equal(5000 + drive)
		end)

		it("prices a whole bad drive the way the task reported it", function()
			-- two piglets and a shot down the line: -30 points and $2000, against a good drive's
			-- $40-$80. That IS Karen's "big amount of money" and it is what makes it a mistake.
			local good = Coins.forRow(10, false, CFG)
			expect(good >= 20 and good <= 80).to.equal(true)
			local bad = Coins.forRow(-30, false, CFG, 2000)
			expect(bad <= -2000).to.equal(true)
			expect(Coins.credit(1500, bad, CFG)).to.equal(0)
		end)
	end)
end
