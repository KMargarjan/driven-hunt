--!strict
-- Match.Score: points. PURE -- no service, no clock, no Player, no Instance, no Random; `config` is
-- a parameter, not a lookup. Every board it returns is deep-frozen and it never mutates its input,
-- the discipline Boar.Wound and Weapon.StateMachine are already held to.
--
-- IT KEYS BY userId AND NEVER STORES A Player. A score row outlives a disconnect by a whole drive,
-- and holding a Player pins the instance (TASKS.md row 23a(c)).
--
-- WHY DRIVERS SCORE AT ALL, since it is the one thing here worth arguing about: if only the killer
-- scores then half the players end a ten-minute drive with an empty line, and with teams swapping
-- they waited ten minutes for their turn. BEATER_PUSH makes driving a scoring activity in the same
-- currency, off one number (BEATER_PUSH = 0 switches the whole idea off). Karen, 2026-10-10:
-- *"beater ranking also is cool"*.
--
-- WHAT A KILL IS WORTH IS THE ANIMAL, since task 160: `POINTS.KIND` off `record.kind`, not
-- `POINTS.KILL` off the hit zone. Karen: *"male is more worth then famale"*. The retired table and
-- its rollback are in backups/2026-10-12_task-160_points-by-hit-zone.txt.
--
-- Design: docs/design/drive.md (sections 7.1, 7.2, 7.3 -- 7.1's table is STALE since task 160: the
--         Architect owns that file and the Builder does not write designs)
-- Note:   docs/research/2026-09-25-drive.md, and docs/research/2026-10-12-scoring.md for the points
local Score = {}

export type TeamName = "Drivers" | "Shooters"

export type Row = {
	userId: number,
	name: string,
	team: TeamName?,
	points: number,
	-- MONEY TAKEN OFF HIM THIS DRIVE, IN DOLLARS, AS A POSITIVE TOTAL (task 250). KAREN,
	-- 2026-10-23: *"we need to make more damadge to shooter if shoot baby like take big amount of
	-- money and same to person"*.
	--
	-- IT IS NOT POINTS AND IT IS NOT A SECOND SCORE. `points` is the drive's currency and decides
	-- the ranking; this is dollars and decides what `Economy.Coins.forRow` pays out. The two are
	-- charged by the same events and are deliberately both charged: Karen's sentence is *on top of*
	-- the penalty she already has, not instead of it.
	--
	-- A MAGNITUDE, never a negative: a total of charges reads as a total. The SIGN belongs to the
	-- thing that spends it -- `Coins.forRow` subtracts it and the feed publishes `-fines` -- which
	-- is `Money.text`'s own rule (*"the sign is handled OUTSIDE the symbol, so no screen can
	-- hand-roll `$-20`"*).
	fines: number,
	kills: number,
	assists: number,
	pushes: number,
	wounded: number,
	escaped: number,
	violations: number,
	left: boolean,
	firstKillAt: number?,
}

export type Board = { rows: { [number]: Row } }
-- `money` IS THE DOLLARS THIS AWARD ALSO TOOK OFF HIM, SIGNED, and it is optional (task 250):
-- absent on every award this game made before the fines existed. It is the DELTA, so a fine is
-- negative -- the convention `Drive.CONFIG.SCORE_EARNED_FORMAT` sets and `Money.signed` draws.
export type Award = { userId: number, points: number, reason: string, money: number? }

local function freeze<T>(value: T): T
	if type(value) == "table" and not table.isfrozen(value :: any) then
		table.freeze(value :: any)
	end
	return value
end

local function freezeBoard(board: Board): Board
	for _, row in pairs(board.rows) do
		freeze(row)
	end
	freeze(board.rows)
	return freeze(board)
end

function Score.new(): Board
	return freezeBoard({ rows = {} })
end

local function blankRow(userId: number, name: string, team: TeamName?): Row
	return {
		userId = userId,
		name = name,
		team = team,
		points = 0,
		fines = 0,
		kills = 0,
		assists = 0,
		pushes = 0,
		wounded = 0,
		escaped = 0,
		violations = 0,
		left = false,
		firstKillAt = nil,
	}
end

-- One shallow copy of the board plus one of each row it touches. Rows nobody scored are shared, not
-- copied: they are frozen, so sharing them is safe and a drive with 16 players does not copy 16 rows
-- on every kill.
local function withRows(board: Board, updates: { [number]: Row }): Board
	local rows = table.clone(board.rows)
	for userId, row in pairs(updates) do
		rows[userId] = row
	end
	return freezeBoard({ rows = rows })
end

local function mutable(board: Board, userId: number, name: string?): Row
	local existing = board.rows[userId]
	if existing then
		local copy = table.clone(existing)
		if name then
			copy.name = name
		end
		return copy
	end
	return blankRow(userId, name or tostring(userId))
end

function Score.join(board: Board, userId: number, name: string, team: TeamName?): Board
	local row = mutable(board, userId, name)
	row.team = team
	row.left = false
	return withRows(board, { [userId] = row })
end

-- The row SURVIVES, marked `left`: this drive's score screen still shows what they did, and the row
-- is dropped at the next Assigning (design section 4.4).
function Score.leave(board: Board, userId: number): Board
	local existing = board.rows[userId]
	if not existing then
		return board
	end
	local row = table.clone(existing)
	row.left = true
	return withRows(board, { [userId] = row })
end

function Score.setTeam(board: Board, userId: number, team: TeamName?): Board
	local row = mutable(board, userId)
	row.team = team
	return withRows(board, { [userId] = row })
end

-- WHAT THE ANIMAL WAS WORTH (task 160). Karen, 2026-10-10: *"How many shoot and male is more worth
-- then famale"* -- so the kill's price comes off the KIND and off nothing else: no zone multiplier,
-- no range bonus, no streak. One table, one lookup, `multiplied/added by nothing`.
--
-- It replaced `pointsForZone`, which read `POINTS.KILL[record.killingZone]` and could not express
-- Karen's rule at all because it did not know what it shot
-- (backups/2026-10-12_task-160_points-by-hit-zone.txt).
-- WHAT SHOOTING THIS ANIMAL COSTS HIM IN MONEY, and the WORD the feed prints for it (task 250).
-- PURE and exported, so a spec drives every branch -- a protected kind, a paying kind, an unknown
-- kind, nil, and a config with no `FINE` table at all -- with no board and no drive.
--
-- `nil, nil` IS "NO FINE", and it is every animal but the two young. `Match.CONFIG.FINE.KIND` is
-- the whole rule: a row is `{ money = <dollars>, word = <what the feed says> }`, one row per animal
-- Karen protects, and an animal with no row costs nothing. The WORD lives in the row rather than
-- being derived, because `Report.kindWord` is a CLIENT module and this is a server one -- and
-- because the row is then one line that says both halves of the decision.
function Score.fineForKind(kind: string?, config): (number?, string?)
	local fines = config.FINE
	local rows = if type(fines) == "table" then fines.KIND else nil
	local row = if type(rows) == "table" and type(kind) == "string" then rows[kind] else nil
	if type(row) ~= "table" or type(row.money) ~= "number" or row.money <= 0 then
		return nil, nil
	end
	return row.money, if type(row.word) == "string" then row.word else nil
end

-- WHAT ENDANGERING A PERSON COSTS HIM IN MONEY (task 250), and the word for it. Same shape, same
-- `nil` meaning, one row: `Match.CONFIG.FINE.SAFETY`.
function Score.fineForSafety(config): (number?, string?)
	local fines = config.FINE
	local row = if type(fines) == "table" then fines.SAFETY else nil
	if type(row) ~= "table" or type(row.money) ~= "number" or row.money <= 0 then
		return nil, nil
	end
	return row.money, if type(row.word) == "string" then row.word else nil
end

local function pointsForKind(kind: string?, config): (number, boolean)
	local table_ = config.POINTS.KIND
	local known = kind ~= nil and table_[kind] ~= nil
	if known then
		return table_[kind :: string], true
	end
	-- Never free, and counted by the owner as unknownKindKills: a kind typo must show up as a number
	-- rather than as an animal that quietly scores nothing.
	return table_.unknown, false
end

-- WHO GETS THE BEATER'S POINTS FOR THIS ANIMAL (task 160), out of the credit the owner measured.
--
-- `pushCredit` is userId -> the instant that beater last pushed this boar, already filtered by the
-- owner to the window before the kill. THE LATEST CREDIT IS THE ONE THAT PAYS -- ioquake3's support
-- rule, which awards an assist only for the action that caused the score *"almost immediately"*
-- (code/game/g_team.h, GPL-2.0; docs/research/2026-10-12-scoring.md section 2.2). A beater who
-- walked past this animal nineteen seconds ago and then left it to somebody else does not collect
-- for the other man's work.
--
-- A TIE PAYS EVERYBODY TIED, and that is a decision rather than an oversight. Credit is sampled at
-- `PUSH_SAMPLE_HZ` (2 Hz), so two beaters walking the same animal up are written in the SAME tick
-- and hold IDENTICAL timestamps -- "the last one" would then be decided by `pairs` order or by
-- userId, which is a coin flip the loser watches happen. Two men pushed it; two men are paid.
local function latestPushers(pushCredit: { [number]: number }?): { number }
	local best, out = -math.huge, {}
	for userId, seen in pairs(pushCredit or {}) do
		if seen > best then
			best, out = seen, { userId }
		elseif seen == best then
			table.insert(out, userId)
		end
	end
	-- Sorted, so the awards this function feeds come out in a stable order for the same reason
	-- `Score.leaderboard`'s last tiebreak exists: a feed that reorders between two identical kills
	-- is this project's "a marker wandering the screen" in a new place.
	table.sort(out)
	return out
end

-- `record` is the boar's KillRecord (docs/design/hit-zones.md section 8.1): killedByUserId, kind,
-- killingZone, contributors (userId -> damage points). `kind` is what the kill is PRICED by (task
-- 160); `killingZone` is still on the record and is still what the report draws, and this module no
-- longer reads it at all.
-- `pushCredit` is userId -> the last time that BEATER pushed this boar, already filtered by the
-- owner to the window before the kill. Two doors feed it and the owner knows about both: standing
-- inside PUSH_RADIUS (sampled at PUSH_SAMPLE_HZ) and blowing a horn the animal heard.
function Score.kill(board: Board, record, pushCredit: { [number]: number }?, config): (Board, { Award })
	local awards: { Award } = {}
	local updates: { [number]: Row } = {}

	-- `money` IS THE FINE THIS AWARD ALSO CARRIES (task 250), in dollars, as a positive charge. It
	-- is added to `row.fines` and published on the award as the DELTA (`-money`), so a listener
	-- rebuilding the drive from `Match.Scored` alone sees both halves of one event.
	local function credit(userId: number, points: number, reason: string, apply: (Row) -> (), money: number?)
		local row = updates[userId] or mutable(board, userId)
		row.points += points
		local charged = if type(money) == "number" and money > 0 then money else 0
		row.fines += charged
		apply(row)
		updates[userId] = row
		if points ~= 0 or charged ~= 0 then
			table.insert(awards, {
				userId = userId,
				points = points,
				reason = reason,
				money = if charged ~= 0 then -charged else nil,
			})
		end
	end

	local killer = record.killedByUserId
	local kind = record.kind
	local killPoints, knownKind = pointsForKind(kind, config)

	if killer then
		-- THE BABY FINE LANDS ON THE KILLER AND ON NOBODY ELSE (task 250). An assist on a piglet and
		-- a push that walked it up are not the shot Karen is punishing -- *"more damadge to
		-- shooter"* -- and the `credit` calls below pass no money, which is what keeps that true.
		local fine = Score.fineForKind(kind, config)
		credit(killer, killPoints, if knownKind then "kill-" .. tostring(kind) else "kill-unknown", function(row)
			row.kills += 1
			if row.firstKillAt == nil then
				row.firstKillAt = record.at
			end
		end, fine)
	end

	-- An assist is for damage that mattered: one pellet does not earn one, and the killer never also
	-- collects an assist for the shot that killed it.
	for userId, damage in pairs(record.contributors or {}) do
		if userId ~= killer and damage >= config.POINTS.ASSIST_MIN_DAMAGE then
			credit(userId, config.POINTS.ASSIST, "assist", function(row)
				row.assists += 1
			end)
		end
	end

	for _, userId in ipairs(latestPushers(pushCredit)) do
		if userId ~= killer then
			credit(userId, config.POINTS.BEATER_PUSH, "push", function(row)
				row.pushes += 1
			end)
		end
	end

	return withRows(board, updates), awards
end

-- A boar that got away. `ESCAPE_WOUNDED` is 0 by default, so the lesson is "take the shot you can
-- make" -- but the row still records it, because "how many got away from me" is a real number.
function Score.escape(board: Board, record, config): (Board, { Award })
	local awards: { Award } = {}
	local updates: { [number]: Row } = {}
	if not record.mortallyWounded then
		return board, awards
	end
	for userId, damage in pairs(record.contributors or {}) do
		if damage > 0 then
			local row = updates[userId] or mutable(board, userId)
			row.escaped += 1
			row.points += config.POINTS.ESCAPE_WOUNDED
			updates[userId] = row
			if config.POINTS.ESCAPE_WOUNDED ~= 0 then
				table.insert(awards, { userId = userId, points = config.POINTS.ESCAPE_WOUNDED, reason = "escape" })
			end
		end
	end
	return withRows(board, updates), awards
end

-- 1.7b's penalty, scored here because points have one home. Points may go negative.
--
-- ...AND SINCE TASK 250 IT TAKES HIS MONEY TOO. KAREN, 2026-10-23: *"same to person"* -- the same
-- *"big amount of money"* she asked for on a piglet, for the thing you must not shoot at. BOTH are
-- charged and that is her sentence: the points penalty and the tie to a tree are untouched, and
-- `FINE.SAFETY` is on top.
function Score.violation(board: Board, userId: number, config): (Board, { Award })
	local row = mutable(board, userId)
	row.violations += 1
	row.points += config.POINTS.SAFETY_PENALTY
	local fine = Score.fineForSafety(config)
	local charged = if type(fine) == "number" then fine else 0
	row.fines += charged
	return withRows(board, { [userId] = row }),
		{
			{
				userId = userId,
				points = config.POINTS.SAFETY_PENALTY,
				reason = "safety",
				money = if charged ~= 0 then -charged else nil,
			},
		}
end

-- Sorted by points, then kills, then the earliest first kill, then userId. The last key makes the
-- order TOTAL, so the board never reorders between two broadcasts for no reason -- a wandering
-- scoreboard is this project's "a marker wandering the screen" in a new place.
function Score.leaderboard(board: Board): { Row }
	local rows: { Row } = {}
	for _, row in pairs(board.rows) do
		table.insert(rows, row)
	end
	table.sort(rows, function(a, b)
		if a.points ~= b.points then
			return a.points > b.points
		end
		if a.kills ~= b.kills then
			return a.kills > b.kills
		end
		local aFirst = a.firstKillAt or math.huge
		local bFirst = b.firstKillAt or math.huge
		if aFirst ~= bFirst then
			return aFirst < bFirst
		end
		return a.userId < b.userId
	end)
	return rows
end

return Score
