--!strict
-- Money: THE SYMBOL, THE WORD AND THE ONE FORMATTER. Frozen constants plus two pure functions.
-- No writer, no state, no service, no clock, no remote, no Player, no rate and no price.
--
-- KAREN, 2026-10-20 ~08:30, verbatim: *"We need to change coins to actual money $"*.
--
-- IT IS A MODULE AND NOT A FIELD OF `Drive.CONFIG`, and the design gives three reasons
-- (docs/design/economy-v1.md section 2.1):
--   1. `ReplicatedStorage.Shop` must not require the drive's wire contract. Its own header reads
--      *"WHAT IS NOT HERE AND MAY NOT COME HERE: a balance, an ownership set, a hunt count, a coin
--      rate, a remote, a Player"* -- and `Shop.NOTICE[POOR]` and `Shop.CONFIG.TEXT.POOR_BUTTON` are
--      two places the SERVER formats money, so the formatter has to be reachable from `Shop`.
--   2. `Hud.ShopPanel` does not require `Drive` today and should not learn to: `Shop.CONFIG` is the
--      one table it reads for words, and a second words module would be a second answer to "what
--      does this panel say".
--   3. The precedent exists and is smaller than this: `ReplicatedStorage.Licences` is frozen data
--      plus pure functions with no writer, required by `Match` and by `Weapon.Rules`.
--
-- THE SAVED RECORD KEEPS ITS KEY. The profile field is still `coins`, `coinsEarnedTotal` is still
-- `coinsEarnedTotal`, `Economy.CONFIG.COINS_PER_POINT` is still that, the snapshot row field is
-- still `coins` and `Hud.BOARD.COLUMNS.coins` is still that. THIS MODULE IS DISPLAY AND NOTHING
-- ELSE: a rename of a persisted key is the one change that can destroy a live profile, and there is
-- no migration here because there is nothing to migrate (design section 1.2 item 1).
--
-- `$` EXISTS IN THIS FILE AND NOWHERE ELSE IN `src/`, and that is not a convention but an
-- assertion: `tests/client/money.spec.luau` walks every word table a player reads and fails on a
-- `$` outside this module and on the word COIN inside one.
--
-- Pattern: OpenTTD's `CurrencySpec` (`src/currency.h`, GPL-2.0) -- a currency is a SYMBOL plus its
-- PLACEMENT in one table read by every formatter, with the sign handled OUTSIDE the symbol, so no
-- screen can hand-roll `$-20`. Its exchange rates, separators and localisation are not taken: this
-- game has one currency and no locale.
--
-- Design: docs/design/economy-v1.md section 3
-- Note:   docs/research/2026-10-20-money-and-the-v1-catalogue.md
local Money = {}

Money.SYMBOL = "$"

-- The caption over a balance and the results board's column head. ONE word, so the chip and the
-- board cannot disagree.
Money.WORD = "MONEY"

-- WHAT AN ABSENT NUMBER LOOKS LIKE. `--`, never `0`: a player whose profile did not open has an
-- UNKNOWN balance, and printing 0 would be the Hud asserting he has none. `Economy.balanceOf`'s own
-- rule, and the string `Drive.CONFIG.SCORE_COINS_UNKNOWN` used to hold.
Money.UNKNOWN = "--"

-- A WHOLE DOLLAR. No balance in this game is fractional (`COINS_PER_POINT` is 2 and
-- `PARTICIPATION` is 10), so a `$12.0000001` on screen would be this formatter inventing a
-- precision the game does not have. `math.floor` on the magnitude, so -0.5 reads `$0` and not
-- `-$1`.
local function whole(amount: number): number
	return math.floor(math.abs(amount) + 0.0000001)
end

-- "$1240", "$0", and "-$20" for a negative. THE SIGN IS OUTSIDE THE SYMBOL, which is the one thing
-- `CurrencySpec` is borrowed for: `string.format("$%d", -20)` gives `$-20`, and every screen that
-- did its own formatting would have to remember not to.
--
-- NO THOUSANDS SEPARATOR, and it is a measured decision rather than a taste one:
-- `Hud.BOARD.COLUMNS.coins` is 66 px wide and `tests/client/hud_clarity.spec.luau` measures a
-- 400 px screen, so a separator spends a character of the widest cell on no information -- and
-- every price in the catalogue is a round number a player can hold in his head. One branch here to
-- add later; Karen's (design section 17, K-4).
--
-- nil in, `Money.UNKNOWN` out: an unknown balance is not a zero one.
function Money.text(amount: number?): string
	if type(amount) ~= "number" then
		return Money.UNKNOWN
	end
	local value = amount :: number
	local sign = if value < 0 then "-" else ""
	return string.format("%s%s%d", sign, Money.SYMBOL, whole(value))
end

-- "+$34" / "-$20": THE SIGN IS ALWAYS DRAWN, because a drive can have COST him -- a piglet is -10
-- points, which is -$20. `Drive.CONFIG.SCORE_EARNED_FORMAT`'s own stated reason: *"+34" and "-20"
-- read as a change; "34" and "-20" read as two kinds of thing*.
--
-- ZERO READS `+$0`, not `$0`: it is still a change, and a column where one row reads `$0` and the
-- next `+$12` is a column with two kinds of thing in it.
function Money.signed(amount: number?): string
	if type(amount) ~= "number" then
		return Money.UNKNOWN
	end
	local value = amount :: number
	local sign = if value < 0 then "-" else "+"
	return string.format("%s%s%d", sign, Money.SYMBOL, whole(value))
end

return Money
