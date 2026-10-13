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
-- Design: docs/design/economy.md (sections 4.1, 4.4, 10)
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
			Economy.start({ store = store, players = players, enabled = opts.enabled ~= false })
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
			local receipt = Economy.purchase(201, Shop.ITEM.HAT_RED, { atCounter = true })
			expect(receipt.ok).to.equal(true)
			expect(receipt.price).to.equal(80)
			expect(Economy.balanceOf(201)).to.equal(500 - 80)
			expect(Economy.ownedOf(201)[Shop.ITEM.HAT_RED]).to.equal(true)
			-- A FROZEN COPY, so no reader can write the set it was handed.
			expect(table.isfrozen(Economy.ownedOf(201))).to.equal(true)
			-- ONE `save`, AND IT IS NOT A NETWORK CALL (the store's own contract). Purchases per
			-- DataStore request: 0.
			expect(store.calls().save).to.equal(1)
			local saved = store.peek(201)
			expect(saved.coins).to.equal(420)
			expect(saved.owned[Shop.ITEM.HAT_RED]).to.equal(true)
			-- A PURCHASE IS NOT A DRIVE: the hunt count is untouched, which is hazard 2 closed.
			expect(saved.drivesPaid).to.equal(0)
			expect(Economy.huntsOf(201)).to.equal(0)
			expect(Economy.stats().purchases).to.equal(1)
			expect(Economy.stats().coinsSpent).to.equal(80)
		end)

		-- THE DOUBLE CLICK: the first charges, the second is refused and NOTHING is written.
		it("charges a double click once", function()
			started({ ids = { 202 }, seed = { [202] = { coins = 500 } } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(202) ~= nil
			end)).to.equal(true)
			expect(Economy.purchase(202, Shop.ITEM.HAT_RED, { atCounter = true }).ok).to.equal(true)
			local again = Economy.purchase(202, Shop.ITEM.HAT_RED, { atCounter = true })
			expect(again.ok).to.equal(false)
			expect(again.refused).to.equal(Shop.REASON.OWNED)
			expect(Economy.balanceOf(202)).to.equal(420)
			expect(Economy.stats().purchases).to.equal(1)
			expect(Economy.stats().refusedBy[Shop.REASON.OWNED]).to.equal(1)
		end)

		it("refuses a poor player, a locked item and a forged id, and writes nothing for any of them", function()
			local _, store = started({ ids = { 203 }, seed = { [203] = { coins = 100, drivesPaid = 2 } } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(203) ~= nil
			end)).to.equal(true)
			expect(Economy.huntsOf(203)).to.equal(2)
			-- POOR: the rifle is 1500.
			local poor, short = Economy.purchase(203, Shop.ITEM.RIFLE, { atCounter = true }), nil
			expect(poor.refused).to.equal(Shop.REASON.POOR)
			expect(poor.refusedNumber).to.equal(1500 - 100)
			short = Economy.purchase(203, Shop.ITEM.BEATER_LICENCE, { atCounter = true })
			-- LOCKED before POOR: no amount of coins buys past a hunt gate, so that is the line he is
			-- shown even though he is also short of the 250.
			expect(short.refused).to.equal(Shop.REASON.LOCKED)
			expect(short.refusedNumber).to.equal(1)
			-- A FORGED ID, and the open-sight rifle, which is in the catalogue and not for sale.
			expect(Economy.purchase(203, "rifle.free", { atCounter = true }).refused).to.equal(Shop.REASON.UNKNOWN)
			expect(Economy.purchase(203, Shop.ITEM.RIFLE_OPEN, { atCounter = true }).refused).to.equal(
				Shop.REASON.NOT_SALE
			)
			-- ...AND A MAN WHO IS NOT AT THE COUNTER.
			expect(Economy.purchase(203, Shop.ITEM.HAT_RED, { atCounter = false }).refused).to.equal(
				Shop.REASON.TOO_FAR
			)
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
			local refused = Economy.purchase(204, Shop.ITEM.HAT_RED, { atCounter = true })
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
			expect(Economy.purchase(205, Shop.ITEM.HAT_RED, { atCounter = true }).refused).to.equal(
				Shop.REASON.NO_PROFILE
			)
			expect(store.calls().save).to.equal(0)
		end)

		it("refuses every purchase with the coins off, and reads the whole shop as closed", function()
			started({ ids = { 206 }, enabled = false })
			task.wait(0.1)
			local receipt = Economy.purchase(206, Shop.ITEM.HAT_RED, { atCounter = true })
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
			Economy.purchase(207, Shop.ITEM.HAT_RED, { atCounter = true })
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
				elseif wire.id == Shop.ITEM.HAT_RED then
					-- 300 coins, no hunt gate: the one he can buy.
					expect(wire.buyable).to.equal(true)
				elseif wire.id == Shop.ITEM.RIFLE then
					-- 30 hunts is enough, 300 coins is not.
					expect(wire.locked).to.equal(false)
					expect(wire.afford).to.equal(false)
					expect(wire.buyable).to.equal(false)
				elseif wire.id == Shop.ITEM.RIFLE_OPEN then
					expect(wire.sale).to.equal(false)
					expect(wire.buyable).to.equal(false)
				end
			end
			-- A SEEDED SET IS READ BACK, which is the whole load/save round trip for the new field.
			expect(Economy.ownedOf(208)[Shop.ITEM.SLUG]).to.equal(true)
		end)

		it("drops the set, the hunts and the balance together when a session is lost or stopped", function()
			local _, store = started({ ids = { 209 }, seed = { [209] = { coins = 500, drivesPaid = 4 } } })
			expect(waitUntil(2, function()
				return Economy.balanceOf(209) ~= nil
			end)).to.equal(true)
			Economy.purchase(209, Shop.ITEM.HAT_RED, { atCounter = true })
			expect(Economy.ownedOf(209)).to.be.ok()
			-- A SESSION ANOTHER SERVER TOOK: no further change may be made to that profile, so the
			-- row goes -- and the readers then see nil, which is "nobody answered" and leaves his gun
			-- exactly as it is.
			store.loseSession(209)
			expect(Economy.ownedOf(209)).to.equal(nil)
			expect(Economy.huntsOf(209)).to.equal(nil)
			expect(Economy.balanceOf(209)).to.equal(nil)
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

		it("is born behind a flag that is off, so nothing is written until Karen says so", function()
			local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
			expect(Flags.DEFAULTS.COINS).to.be.ok()
			expect(Flags.DEFAULTS.COINS.default).to.equal(false)
			expect(Flags.DEFAULTS.COINS.owner).to.equal("ServerScriptService.Economy")
			expect(Economy.CONFIG.ENABLED).to.equal(Flags.isOn("COINS"))
		end)
	end)
end
