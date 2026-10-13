--!strict
-- Drive.Rank: WHO IS FIRST, and WHICH RANKING he is first of. PURE -- no service, no clock, no
-- Player, no Instance, no Random, and NO NUMBER AT ALL: it is a predicate over the score rows the
-- client is already sent. `ReplicatedStorage.Drive`'s header rule holds ("THE RULE NUMBERS ARE NOT
-- HERE") because there is nothing here to be a rule number.
--
-- IT LIVES IN `Drive` BECAUSE BOTH SIDES ASK THE SAME QUESTION OF IT, and that is the whole reason
-- the module exists (task 170). `Hud.firstPlaceRank` was the one implementation of "a tie at the top
-- is not a first place" (task 160); from this task the SERVER pays a first-place bonus off the same
-- question (`Economy.Coins.forDrive`) and the CLIENT draws a badge off it. Two implementations of
-- one rule is this project's named failure mode -- docs/PROJECT_CONTEXT.md: *"Most of the worst bugs
-- were two correct pieces of code disagreeing"* -- so there is one, in the module `Match` and `Hud`
-- both already require. The retired client function is archived in
-- backups/2026-10-13_task-170_hud-firstplacerank.txt (rule 7).
--
-- Design: docs/design/economy.md (sections 4.3, 7.1)
-- Note:   docs/research/2026-10-13-coins-persistence.md
local Rank = {}

-- A row is anything with `team` and `points`; the real one is `Drive.ScoreRow` / `Score.Row`. Typed
-- loosely on purpose: this module is required by the server (which holds `Score.Row`) and by the
-- client (which holds `Drive.ScoreRow`), and they are the same shape by contract, not by type.
export type Row = { userId: number, team: string?, points: number }

-- THE TWO RANKINGS, plus the rows that are in neither (task 170). Karen, 2026-10-12: separate
-- rankings for hunters and beaters.
--
-- ORDER IS PRESERVED FROM THE INPUT and nothing is re-sorted. `Score.leaderboard` has already
-- produced a TOTAL order (points, kills, earliest first kill, userId -- the last key is what makes
-- it total, so the board never reorders between two broadcasts), and a ranking that sorted again
-- could only either repeat that work or disagree with it.
--
-- `others` IS NOT DECORATION. A row can have no team: `Match`'s `watchPlayer` calls
-- `Score.join(board, ..., state.assignment[userId])` and `Phase.step`'s join branch assigns a team
-- only in `Assigning` and `Running`, so a player who joins in `Waiting` or `Scoring` has `team ==
-- nil` until the next drive. The third list is what makes "no row can be lost" one assertion:
-- `#hunters + #beaters + #others == #rows`.
function Rank.splitByTeam(rows: { Row }?): ({ Row }, { Row }, { Row })
	local hunters: { Row } = {}
	local beaters: { Row } = {}
	local others: { Row } = {}
	for _, row in ipairs(rows or {}) do
		-- The TEAM names, which are the server's and are on the wire. Karen's words for the two
		-- sides (HUNTER / BEATER) are `Hud.roleWord`'s job and are not duplicated here.
		if row.team == "Shooters" then
			table.insert(hunters, row)
		elseif row.team == "Drivers" then
			table.insert(beaters, row)
		else
			table.insert(others, row)
		end
	end
	return hunters, beaters, others
end

-- WHICH ROW IS FIRST PLACE, AS A RULE AND NOT AS "ROW 1" (task 160, moved here by task 170). Karen,
-- 2026-10-11: *"first place ofc more"*.
--
-- `nil` MEANS NOBODY IS FIRST, and both cases that return it are the point of the function:
--   * the top two are LEVEL. A tie at the top is not a first place -- it is a tie. This is
--     ioquake3's `CalculateRanks` read the other way round: *"we are tied with the previous client"*
--     sets `rank | RANK_TIED_FLAG` on both rows (code/game/g_main.c, GPL-2.0;
--     docs/research/2026-10-12-scoring.md section 2.1).
--   * NOBODY HAS SCORED AT ALL. On an all-noughts board -- which is every board for the first
--     minute of every drive -- `Score.leaderboard`'s last tiebreak is `userId`, so a badge on row 1
--     would crown whoever joined the server first. ioquake3 flags a lone playing client as tied for
--     the same reason: being the only one there is not winning.
--
-- THE SECOND TEST IS "AHEAD OF THE SECOND ROW", NOT "ABOVE ZERO" (task 160 round 1, note 2). It was
-- the leader's own points against 0, which made the function disagree with itself: a leader on 0
-- ahead of a second on -10 got no badge while a leader on -10 ahead of -20 got one, though both are
-- a man clear at the top of a board where something has happened. Being ahead of the field IS first
-- place, whatever the sign; the zero test is now only what it was always for -- the board where
-- nothing has happened yet -- and so it is asked ONLY of the row that has nobody behind it.
--
-- IT IS ASKED ONCE PER RANKING (task 170), never per row: the answer is a property of the LIST (is
-- its top row clear of its second?), and asking it per row is the same question answered sixteen
-- times. The server asks it of `splitByTeam`'s two lists to pay two bonuses; the client asks it of
-- the same two to draw two badges.
function Rank.firstPlaceRank(rows: { Row }?): number?
	local first = rows and rows[1]
	if first == nil then
		return nil
	end
	local second = (rows :: { Row })[2]
	if second == nil then
		return if (first.points or 0) == 0 then nil else 1
	end
	if (second.points or 0) >= (first.points or 0) then
		return nil
	end
	return 1
end

-- The userId of the row that is first place, or nil. The same question as `firstPlaceRank` asked by
-- the half that pays rather than the half that draws: a bonus is credited to a PLAYER, and a rank
-- index into a list the caller would have to keep is one more thing to get out of step.
function Rank.firstPlaceUserId(rows: { Row }?): number?
	local index = Rank.firstPlaceRank(rows)
	if index == nil then
		return nil
	end
	return (rows :: { Row })[index].userId
end

return Rank
