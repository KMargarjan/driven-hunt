--!strict
-- Economy.Coins: WHAT A DRIVE IS WORTH TO WHOM. PURE -- no service, no clock, no Player, no
-- Instance, no Random; `config` is a parameter, not a lookup. Every table it returns is deep-frozen
-- and it never mutates its input, the discipline `Match.Score`, `Boar.Wound` and
-- `Weapon.StateMachine` are already held to.
--
-- IT KEYS BY userId AND NEVER STORES A Player, for `Match.Score`'s own reason: a row outlives a
-- disconnect by a whole drive, and holding a Player pins the instance (TASKS.md row 23a(c)).
--
-- COINS ARE A FUNCTION OF THE BOARD AND OF NOTHING ELSE, which is the one rule that keeps this from
-- becoming a second scoring system. Its only input is `Score.leaderboard(board)` -- already sorted,
-- already frozen -- so no coin can ever be awarded anywhere a point is not. Karen, 2026-10-11:
-- *"Scoring - yes get money when shoot boar not much but get money and first place ofc more
-- legendary more ect"*. The points half of that sentence was task 160; this is the money half, and
-- the note that built the board predicted this shape in its own section 5.
--
-- WHO IS FIRST IS NOT DECIDED HERE. `Drive.Rank` is the one implementation of "a tie at the top is
-- not a first place" (ioquake3's `RANK_TIED_FLAG`), read by this module to pay the bonus and by the
-- Hud to draw the badge -- one rule, two readers, because two correct pieces of code disagreeing is
-- this project's named failure mode (docs/PROJECT_CONTEXT.md).
--
-- Design: docs/design/economy.md (section 4.1)
-- Note:   docs/research/2026-10-13-coins-persistence.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))

local Rank = Drive.Rank

local Coins = {}

export type Row = {
	userId: number,
	team: string?,
	points: number,
	-- DOLLARS TAKEN OFF HIM THIS DRIVE (task 250), a positive total, absent on a board written
	-- before the fines existed. `Match.Score.Row.fines` is the one producer.
	fines: number?,
	left: boolean?,
}

export type Breakdown = {
	-- userId -> coins for THIS drive. MAY BE NEGATIVE: two piglets and a safety violation is -30
	-- points, which is -50 coins. The clamp is the BALANCE's, not the drive's (`Coins.credit`).
	coins: { [number]: number },
	-- The userId that took each ranking's first place, or nil for a tie at the top and for a list
	-- where nothing has happened yet. Reported so the owner can log what it paid rather than
	-- recomputing it.
	firstHunter: number?,
	firstBeater: number?,
	-- Refusals, COUNTED rather than hidden. A number in a report is this repo's standing rule for a
	-- rule that fires; a silent skip is how a pay-out that stops paying looks exactly like one that
	-- never had anybody to pay.
	skippedLeft: number,
	skippedNotAPlayer: number,
}

local function freeze<T>(value: T): T
	if type(value) == "table" and not table.isfrozen(value :: any) then
		table.freeze(value :: any)
	end
	return value
end

-- WHAT ONE ROW EARNS. `points * COINS_PER_POINT + PARTICIPATION + (FIRST_PLACE if first) - fines`.
--
-- `fines` IS DOLLARS AND NOT POINTS (task 250), which is why it is subtracted at the END rather
-- than folded into `points`: Karen's *"big amount of money"* is a FLAT charge, and multiplying it
-- by `COINS_PER_POINT` would make its size depend on an exchange rate it has nothing to do with.
-- `nil` is every board written before the fines existed and leaves this line arithmetically
-- untouched.
--
-- NO CLAMP HERE, and that is deliberate: a drive's line may be negative, and it is the thing the
-- results table prints as `-20`. The floor belongs to the balance and lives in exactly one place
-- (`Coins.credit`), so a man who shoots two piglets earns nothing from the drive rather than
-- going into debt -- `Economy.CONFIG.FLOOR`'s own stated rule, now with a much bigger number able
-- to reach it.
function Coins.forRow(points: number, isFirst: boolean, config, fines: number?): number
	local coins = points * config.COINS_PER_POINT + config.PARTICIPATION
	if isFirst then
		coins += config.FIRST_PLACE
	end
	if type(fines) == "number" and fines > 0 then
		coins -= fines
	end
	return coins
end

-- THE BALANCE'S ONE WRITER-OF-ARITHMETIC, and the ONLY clamp in this system. Karen's balance never
-- goes below zero: a player who shoots two piglets in his first drive owes nobody anything, he just
-- earns nothing from it.
--
-- It says nothing about whether it clamped. The owner compares before and after and counts
-- (`stats().coinsClamped`), because "how often does a player lose coins to the floor" is a real
-- number about the rates and belongs in the report rather than in this function's signature.
function Coins.credit(balance: number, delta: number, config): number
	return math.max(config.FLOOR, balance + delta)
end

-- IS THIS A REAL PLAYER'S ROW? A userId is a positive integer.
--
-- A TRIPWIRE WITH A NUMBER ON IT, NOT A FILTER THE GAME DEPENDS ON (docs/design/bots.md section 2:
-- a bot has *"no row in `Score`, no DataStore"*, and the mechanism is structural -- a bot's id is a
-- non-numeric string, which `Match.pushCreditable`, `Match.playerDrivers` and `Phase.participantIds`
-- each already refuse). If a non-numeric id ever reaches this table, `skippedNotAPlayer` says so
-- instead of a bot quietly collecting coins into a profile nobody can open.
local function isPlayerId(userId: any): boolean
	return type(userId) == "number" and userId > 0 and userId % 1 == 0
end

-- THE WHOLE CONVERSION, and the only caller of the two functions above.
--
-- `rows` is `Score.leaderboard(board)`: sorted by points, then kills, then the earliest first kill,
-- then userId -- a TOTAL order, so the two rankings below are cut out of it without re-sorting and
-- the drive's own tiebreaks still decide inside each.
--
-- WHAT IT REFUSES:
--   * `left == true` -> NOT PAID, `skippedLeft += 1`. Participation is for turning up AND FINISHING
--     the drive, and the man is not on the server: crediting him means writing into a profile whose
--     session this server has already ended (`Economy.release` runs on `PlayerRemoving`). His row
--     still SHOWS on this drive's results table, which is `Score.leave`'s own decision.
--   * a non-numeric or non-positive userId -> NOT PAID, `skippedNotAPlayer += 1` (above).
--   * `team == nil` -> PAID points and participation, but NEVER a first-place bonus. A row with no
--     team is a real state, not an error: a player who joins in `Waiting` or `Scoring` has no team
--     until the next `Assigning`. `Rank.splitByTeam` puts him in `others`, and `others` has no
--     first place because it is not a ranking -- it is the people who were not in one.
function Coins.forDrive(rows: { Row }?, config): Breakdown
	local coins: { [number]: number } = {}
	local skippedLeft, skippedNotAPlayer = 0, 0

	local hunters, beaters, others = Rank.splitByTeam(rows :: any)
	-- ONCE PER RANKING, outside the loop: first place is a property of the LIST, and asking it per
	-- row is the same question answered sixteen times.
	local firstHunter = Rank.firstPlaceUserId(hunters :: any)
	local firstBeater = Rank.firstPlaceUserId(beaters :: any)

	for _, list in ipairs({ hunters, beaters, others }) do
		for _, row in ipairs(list) do
			local userId = (row :: any).userId
			if not isPlayerId(userId) then
				skippedNotAPlayer += 1
			elseif (row :: any).left == true then
				skippedLeft += 1
			else
				local isFirst = userId == firstHunter or userId == firstBeater
				coins[userId] = Coins.forRow((row :: any).points or 0, isFirst, config, (row :: any).fines)
			end
		end
	end

	return freeze({
		coins = freeze(coins),
		firstHunter = firstHunter,
		firstBeater = firstBeater,
		skippedLeft = skippedLeft,
		skippedNotAPlayer = skippedNotAPlayer,
	}) :: Breakdown
end

return Coins
