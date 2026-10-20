--!strict
-- `ReplicatedStorage.Money`: the symbol, the word and the one formatter (task 221).
--
-- KAREN, 2026-10-20 ~08:30: *"We need to change coins to actual money $"*.
--
-- THE TWO NEGATIVE ASSERTIONS ARE THE POINT OF THIS FILE. Changing a currency means visiting every
-- place a player reads one, and a list built by hand is a list with a hole in it. So instead of
-- enumerating the screens, this walks every WORD TABLE the game draws from and fails if any of
-- them still says COIN, or if any of them hard-codes a `$`. A place the change missed is then a
-- failing harness line rather than something Karen finds.
--
-- IT WALKS VALUES AND NOT KEYS, and that is deliberate: `Hud.BOARD.COLUMNS.coins`,
-- `snapshot.coinsOn` and the profile's `coins` field all keep their names, because nothing
-- persisted is renamed (design section 1.2 item 1) and a key is not a thing a player reads.
--
-- IT IS A CLIENT SPEC because the Hud's tables are the client's. `Money` itself is shared and pure.
--
-- Design: docs/design/economy-v1.md sections 3.1, 3.4
-- Note:   docs/research/2026-10-20-money-and-the-v1-catalogue.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Money = require(ReplicatedStorage:WaitForChild("Money"))
local Shop = require(ReplicatedStorage:WaitForChild("Shop"))
local Drive = require(ReplicatedStorage:WaitForChild("Drive"))

-- THROUGH PlayerScripts, NEVER THE TEMPLATE: the running copy is the one with the state in it, and
-- that is how every client spec in this folder reaches the Hud.
local scripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local Hud = require(scripts:WaitForChild("Hud"))

-- Every string a player can read out of a word table, as a flat list of `where -> what`.
local function drawnStrings(): { { where: string, text: string } }
	local out: { { where: string, text: string } } = {}
	local function take(where: string, value: any)
		if type(value) == "string" then
			table.insert(out, { where = where, text = value })
		end
	end
	for key, value in pairs(Shop.CONFIG.TEXT) do
		take("Shop.CONFIG.TEXT." .. tostring(key), value)
	end
	for key, value in pairs(Shop.NOTICE) do
		take("Shop.NOTICE." .. tostring(key), value)
	end
	for key, value in pairs(Shop.CATEGORY_LABEL) do
		take("Shop.CATEGORY_LABEL." .. tostring(key), value)
	end
	for key, column in pairs(Hud.BOARD.COLUMNS) do
		take("Hud.BOARD.COLUMNS." .. tostring(key) .. ".head", (column :: any).head)
	end
	for key, value in pairs(Drive.CONFIG) do
		if string.sub(tostring(key), 1, 6) == "SCORE_" then
			take("Drive.CONFIG." .. tostring(key), value)
		end
	end
	return out
end

return function()
	describe("money", function()
		it("prints whole dollars with the sign outside the symbol", function()
			expect(Money.SYMBOL).to.equal("$")
			expect(Money.WORD).to.equal("MONEY")
			expect(Money.text(1240)).to.equal("$1240")
			expect(Money.text(0)).to.equal("$0")
			expect(Money.text(12000)).to.equal("$12000")
			-- `-$20`, NEVER `$-20`. `string.format("$%d", -20)` gives the second, which is why the
			-- sign is applied to the string and not inside the format -- OpenTTD's `CurrencySpec`
			-- is borrowed for exactly this.
			expect(Money.text(-20)).to.equal("-$20")
			-- THE SIGN IS ALWAYS DRAWN ON AN EARNING, because a drive can have COST him: a piglet
			-- is -10 points, which is -$20. "+$34" and "-$20" read as a change.
			expect(Money.signed(34)).to.equal("+$34")
			expect(Money.signed(-20)).to.equal("-$20")
			expect(Money.signed(0)).to.equal("+$0")
			-- AN UNKNOWN BALANCE IS `--` AND NEVER `0`: a player whose profile did not open has an
			-- unknown balance, and printing 0 would be the screen asserting he has none.
			expect(Money.UNKNOWN).to.equal("--")
			expect(Money.text(nil)).to.equal(Money.UNKNOWN)
			expect(Money.signed(nil)).to.equal(Money.UNKNOWN)
			expect(Money.text("1240" :: any)).to.equal(Money.UNKNOWN)
			-- NO THOUSANDS SEPARATOR: the widest cell is 66 px and every price is a round number.
			expect(string.find(Money.text(12000), ",", 1, true)).to.equal(nil)
			-- A WHOLE DOLLAR. No balance in this game is fractional, and a `$12.0000001` on screen
			-- would be this formatter inventing a precision the game does not have.
			expect(Money.text(12.7)).to.equal("$12")
			expect(Money.signed(-12.7)).to.equal("-$12")
		end)

		it("is the only thing in the game that says COINS, or prints a dollar", function()
			local drawn = drawnStrings()
			-- THE TABLES ARE ACTUALLY THERE. A spec that walked an empty list would pass for ever.
			expect(#drawn > 20).to.equal(true)
			for _, entry in ipairs(drawn) do
				-- NOTHING A PLAYER READS STILL SAYS COIN.
				expect(string.find(string.upper(entry.text), "COIN", 1, true)).to.equal(nil)
				-- ...AND NOTHING HARD-CODES THE SYMBOL. `Shop.NOTICE[POOR]` carries `%s`, which
				-- `Shop.noticeFor` fills with `Money.text` -- so there is one place a `$` is put in
				-- front of a number and one rule for how it looks.
				expect(string.find(entry.text, Money.SYMBOL, 1, true)).to.equal(nil)
			end
			-- THE WORDS THAT WENT, named so a reader of this file knows where they went.
			expect((Drive.CONFIG :: any).SCORE_COINS_LABEL).to.equal(nil)
			expect((Drive.CONFIG :: any).SCORE_COINS_UNKNOWN).to.equal(nil)
			expect((Drive.CONFIG :: any).SCORE_EARNED_FORMAT).to.equal(nil)
			expect((Shop.CONFIG.TEXT :: any).COINS_CAP).to.equal(nil)
		end)

		it("gives the board a declared column head instead of its own field name", function()
			-- THE HEAD USED TO BE `string.upper(key)` -- the literal SNAPSHOT FIELD NAME -- which is
			-- why the results table said COINS. The field keeps its name and the WORD is declared,
			-- which is `Drive.CONFIG`'s own rule (*"every word the panel draws is written down"*).
			expect(Hud.BOARD.COLUMNS.coins.head).to.equal(Money.WORD)
			expect(Hud.BOARD.COLUMNS.rank.head).to.equal("#")
			expect(Hud.BOARD.COLUMNS.name.head).to.equal("NAME")
			expect(Hud.BOARD.COLUMNS.kills.head).to.equal("KILLS")
			expect(Hud.BOARD.COLUMNS.points.head).to.equal("POINTS")
			-- THE BADGE COLUMN IS NEVER DRAWN AS A HEAD, and has no word.
			expect(Hud.BOARD.COLUMNS.badge.head).to.equal(nil)
			-- EVERY COLUMN THE BOARD DRAWS HAS ONE, so the loop can never print an empty cell.
			for _, key in ipairs(Hud.BOARD_ORDER) do
				expect(type(Hud.BOARD.COLUMNS[key].head)).to.equal("string")
			end
		end)

		it("prints the player's own balance and his drive's earning in dollars", function()
			-- THE TOP BAR: the value alone, because the chip owns its caption.
			local snapshot = {
				coinsOn = true,
				rows = { { userId = 11, name = "a", team = "Shooters", points = 3, kills = 1, coins = 1240 } },
			}
			expect(Hud.coinsText(snapshot, 11)).to.equal("$1240")
			-- THE RESULTS BOARD: the earning, signed.
			local lines = Hud.scorePanelLines({
				coinsOn = true,
				phase = "Scoring",
				rows = {
					{ userId = 11, name = "a", team = "Shooters", points = 16, kills = 2, coins = 1240, earned = 67 },
					{ userId = 12, name = "b", team = "Drivers", points = -10, kills = 0, coins = 0, earned = -20 },
				},
			}, 11)
			-- THE CELLS ARE WHAT THE BOARD PLACES (the padding went with `Enum.Font.Code`), so the
			-- money is asserted where it is actually drawn rather than only in a joined line.
			local body = ""
			for _, line in ipairs(lines) do
				body ..= tostring(line.text) .. "\n"
				if line.cells then
					body ..= tostring((line.cells :: any).coins) .. "\n"
				end
			end
			expect(string.find(body, "+$67", 1, true) ~= nil).to.equal(true)
			expect(string.find(body, "-$20", 1, true) ~= nil).to.equal(true)
			-- ...AND NEVER `$-20`, which is the one formatting mistake this module exists to make
			-- impossible.
			expect(string.find(body, "$-", 1, true)).to.equal(nil)
		end)

		it("prices the shop in dollars, and says PRICE over a price", function()
			-- THE TWO CAPTIONS ANSWER DIFFERENT QUESTIONS (task 221): *how much he has* and *what
			-- this costs*. They read one field before, which is how a caption saying MONEY ends up
			-- over a price.
			expect(Shop.CONFIG.TEXT.MONEY_CAP).to.equal(Money.WORD)
			expect(Shop.CONFIG.TEXT.PRICE_CAP).to.equal("PRICE")
			expect(Shop.CONFIG.TEXT.MONEY_CAP).never.to.equal(Shop.CONFIG.TEXT.PRICE_CAP)
			-- THE REFUSAL THE SERVER SENDS IS FILLED IN ONE PLACE, with the one formatter.
			expect(Shop.noticeFor(Shop.REASON.POOR, 380)).to.equal("YOU NEED $380")
			-- ...AND A COUNT IS STILL A COUNT: hunts are not money, and keep `%d`.
			expect(Shop.noticeFor(Shop.REASON.LOCKED, 3)).to.equal("LOCKED: 3 HUNTS")
		end)
	end)
end
