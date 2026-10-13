--!strict
-- Drive: the wire contract of the match -- the snapshot and feed types both sides agree on, the
-- handful of numbers the Hud needs to draw, and the two remote paths. It has NO writer (rule 3):
-- CONFIG is deep-frozen at the bottom and nothing in the repo may assign to it.
--
-- THE RULE NUMBERS ARE NOT HERE, and that is the decision. The drive length, the points table, the
-- boar schedule and the safety numbers live in Match.CONFIG on the SERVER and are never replicated:
-- a client that knows the points table learns nothing it is not already told, but a client that
-- knows the safety numbers can dodge the rule by eye. The two configs hold disjoint facts.
--
-- Pattern: one frozen shared table plus the remote paths, exactly as src/shared/Shotgun/init.luau
-- already is. deepFreeze is REQUIRED FROM SHOTGUN rather than copied -- table.freeze being shallow
-- is a defect this repo has already paid for once (Task 23a note (b)).
--   RemoteEvent      https://create.roblox.com/docs/scripting/events/remote-events-and-callbacks
--   GetServerTimeNow https://create.roblox.com/docs/reference/engine/classes/Workspace#GetServerTimeNow
--     the one clock both sides can read, so a 600-second countdown is ONE number pushed once per
--     phase rather than 600 broadcasts. Note: the page documents the signature and not a
--     synchronisation guarantee (docs/research/2026-09-25-drive.md source B).
--
-- Design: docs/design/drive.md (sections 3.4, 9.1)
-- Note:   docs/research/2026-09-25-drive.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Drive = {}

-- WHO IS FIRST, AND OF WHICH RANKING (task 170). Re-exported here so there is ONE require site for
-- it: the server reads `Drive.Rank` to pay a first-place bonus per ranking and the client reads the
-- same table to draw a badge per ranking. It holds no number, so the header's rule is intact.
Drive.Rank = require(script.Rank)

export type TeamName = "Drivers" | "Shooters"
export type PhaseName = "Waiting" | "Assigning" | "Running" | "Scoring"

-- Dense arrays only, no holes and no mixed keys: a table that is neither a dense array nor a pure
-- dictionary does not survive the wire faithfully (shotgun design section 2.3).
export type ScoreRow = {
	userId: number,
	name: string,
	team: TeamName?,
	points: number,
	kills: number,
	assists: number,
	pushes: number,
	violations: number,
	left: boolean,
	-- TASK 170, THE ECONOMY. Both are ABSENT -- not 0 -- when the `COINS` flag is off or when this
	-- player has no open profile, because absent is "unknown" and 0 is the statement that he has no
	-- coins. The Hud draws an absent one as `SCORE_COINS_UNKNOWN`.
	--
	-- THE RATES ARE NOT HERE, exactly as the points table is not (see the header): these are two
	-- RESULTS, already computed on the server out of `Economy.CONFIG`, which is never replicated.
	coins: number?, -- the BALANCE after this drive's pay-out. On screen in every phase
	earned: number?, -- what THIS drive paid him. MAY BE NEGATIVE (a piglet costs points)
}

export type MatchSnapshot = {
	phase: PhaseName,
	phaseEndsAt: number, -- SERVER TIME (Workspace:GetServerTimeNow), never a duration
	driveNumber: number,
	boarsReleased: number,
	boarsLeft: number,
	waitingFor: { string }, -- why it is Waiting: "players", or the missing tag names
	-- WHAT MAY BE SHOT IN THIS DRIVE, in the server's own words -- the start card's lines
	-- (task 158). The RULE is the server's (`Match.quarryLines`); this side only lays it out, so a
	-- client holds no second copy of what is legal. Same shape as `waitingFor` above.
	quarry: { string },
	rows: { ScoreRow },
	tied: { number },
	-- WHEN THE BEATERS ARE LET GO, IN SERVER TIME, or 0 for "nobody is waiting" (task 168). KAREN,
	-- 2026-10-12: *"you can't move as a beater before horn made signal and there should be
	-- countdown"* -- so the drive's clock starts, the fanfare sounds, and the line stands still for
	-- the length of the phrase. A beater's screen counts this down locally, exactly as it counts
	-- `phaseEndsAt` down: one timestamp, no second wire and no per-second push.
	holdUntil: number,
	-- WHICH BEATERS ARE THROUGH THE HUNTERS' LINE (task 168). KAREN: *"when beater cross the line of
	-- hunter it's done for him cant use sound anymore"*. The SERVER refuses the blast
	-- (`Match.mayBlowHorn`); this list is so the man's own screen can say why, and it is the same
	-- shape as `tied` right above it, for the same reason.
	through: { number },
}

export type FeedEntry = {
	-- "kill" | "escape" | "violation" | "phase" | "join" | "leave" | "signal"
	-- "signal" IS THE ONE KIND THAT IS NOT A LINE (task 163): its `text` is "start" or "end" and the
	-- Hud answers it with the drive's horn instead of a word. The channel is reused on purpose --
	-- `MatchEvent` already reaches every client once per event, and the Hud already has the rule
	-- that an entry with no text draws nothing (`Hud.feedTextFor`).
	kind: string,
	userId: number?,
	name: string?,
	zone: string?,
	points: number?,
	text: string?,
	at: number,
}

-- Re-exported, NOT a second copy.
Drive.deepFreeze = Shotgun.deepFreeze

-- The one place the remote paths are spelled, so no caller hard-codes them twice.
function Drive.remotes()
	local folder = ReplicatedStorage:WaitForChild("Drive"):WaitForChild("Remotes")
	return {
		-- Both are server -> client. There is NO inbound remote in this system, so its inbound
		-- exploit surface is zero, and that is worth keeping (design section 9.1).
		MatchState = folder:WaitForChild("MatchState") :: RemoteEvent,
		MatchEvent = folder:WaitForChild("MatchEvent") :: RemoteEvent,
	}
end

-- Layout and colours for the Hud ONLY. Every rule number is the server's (see the header).
Drive.CONFIG = {
	-- MILESTONE 1.7b: the score screen is built, so the switch is on. It is still a switch, because
	-- "is the scoreboard in the way" is a Karen feel question she can answer with one boolean.
	SCOREBOARD_ENABLED = true,

	FEED_LINES = 5,
	FEED_SECONDS = 8,

	BAR_TEXT_SIZE = 20,
	-- 8 -> 44 (task 165). THE OBJECTIVE LINE TOOK THE TOP LINE and everything in the top band moved
	-- down one band: objective 8..40, bar 44..70, tied banner 74..104, compass 108..134, map 140.
	-- Karen, 2026-10-12: *"we need to improve design that it will be clear to understand what
	-- happening"*, and what she was reading at y 8 was a row of FACTS. The instruction is the
	-- headline now, and the facts are the line under it. The whole band is `docs/design/hud-clarity.md`
	-- section 3, which is also where the one rule about it lives: nothing may overlap anything at
	-- 400 x 800, asserted arithmetically by `tests/client/hud_clarity.spec.luau`.
	BAR_TOP_OFFSET = 44,
	FEED_TEXT_SIZE = 16,
	FEED_LEFT_OFFSET = 16,
	FEED_BOTTOM_OFFSET = 16,

	-- The score screen (design section 9.3 item 3). Layout only: the POINTS are the server's, and the
	-- panel renders whatever rows arrive in the snapshot.
	SCORE_PANEL_WIDTH = 480,
	SCORE_ROW_HEIGHT = 22,
	-- 22 -> 26 AND BOLD (task 159, the Director on the scene frame: *"the table is UNREADABLE ...
	-- make the table text WHITE (title larger and bold ...)"*). The title is the one line that says
	-- what the panel IS, and at the end of a drive it is read over a bright wood.
	SCORE_TITLE_SIZE = 26,
	SCORE_TEXT_SIZE = 16,
	-- THE HEADER IS DIMMER WHITE, not grey: a column heading should recede, and a GREY glyph over a
	-- sunlit field recedes all the way out of sight. 0.4 -> 0.25.
	SCORE_HEADER_TRANSPARENCY = 0.25,
	-- THE BLACK OUTLINE EVERY OTHER LABEL IN THIS HUD WEARS (the feed's lines, the drive report's).
	-- One pixel: enough to hold a thin Code glyph against grass, not enough to thicken it.
	SCORE_TEXT_STROKE = 1,
	-- 16 -> 20 (task 170): the panel now draws up to THREE HEADINGS over the rows, so
	-- `MAX_PLAYERS` rows no longer fit in `MAX_PLAYERS` lines. 16 + 3 = 19, and 20 leaves one spare.
	-- `tests/server/match_config.spec.luau` asserts `SCORE_ROWS_MAX >= MAX_PLAYERS + 3` on the
	-- server, where both numbers are visible -- so the budget cannot silently stop fitting.
	SCORE_ROWS_MAX = 20,
	-- THE RESULTS TABLE'S TITLE (task 159). Karen: *"showing image transperent with results table"*,
	-- and the panel she is describing IS this one -- a semi-transparent centred panel, one row per
	-- player with name, role, kills and points, up for the whole of `Scoring`. What this task
	-- changed is the WORD: the panel now says what she calls it. `%d` is the drive number.
	--
	-- THE ROLE WORDS ON THE ROWS ARE DELIBERATELY NOT TOUCHED. The board says SHOOTER / DRIVER (the
	-- team names) while Karen says hunter / beater, and which vocabulary the whole Hud should speak
	-- is her decision, still open from task 158 (TASKS.md row 158a). Renaming half the screen to
	-- settle it quietly is exactly what that row exists to prevent.
	SCORE_TITLE_FORMAT = "DRIVE %d RESULTS",
	SCORE_PANEL_COLOR = Color3.fromRGB(16, 18, 20),
	SCORE_PANEL_TRANSPARENCY = 0.25,
	SCORE_HIGHLIGHT_COLOR = Color3.fromRGB(255, 232, 150), -- your own row
	-- THE FIRST-PLACE BADGE (task 160). Karen, 2026-10-11: *"first place ofc more"*. Here rather
	-- than in the renderer for the stated reason the whole of this block is here: every word the Hud
	-- draws is written down in one file. ASCII, like `TIED_TEXT` and every other string in this
	-- repo, and since task 170 it is worn by at most one row PER RANKING -- `Drive.Rank.firstPlaceRank`
	-- decides which, and answers "nobody" for a tie at the top of one.
	SCORE_FIRST_BADGE = "1st",

	-- THE TWO RANKINGS (task 170). Karen, 2026-10-12: separate rankings for hunters and beaters, each
	-- with its own first place. LAYOUT AND WORDING ONLY -- the partition and "who is first" are
	-- `Drive.Rank`'s, one implementation read by both sides, and the coins arrive on the rows.
	--
	-- THE HEADINGS SPEAK KAREN'S WORDS, hunters and beaters, and they can: the row's TEAM column --
	-- the only place this panel ever said SHOOTER / DRIVER -- is GONE, because a `-- HUNTERS --`
	-- heading with SHOOTER on every row under it prints one fact twice. That column is what pays for
	-- the coins column, so `SCORE_PANEL_WIDTH` does not move. Which vocabulary the WHOLE Hud speaks
	-- is still Karen's open question (TASKS.md row 158a) and this settles only this panel.
	SCORE_HUNTERS_HEADING = "-- HUNTERS --",
	SCORE_BEATERS_HEADING = "-- BEATERS --",
	-- Drawn ONLY when that list has a row in it -- the rule `Match.quarryLines` already applies to
	-- its own POINTS label: *"THE WORD ONLY WHEN THERE IS A NUMBER UNDER IT"*. A row has no team
	-- when a player joined outside `Assigning`/`Running`, which is a real state and not an error.
	SCORE_OTHERS_HEADING = "-- OTHERS --",
	-- WHAT AN ABSENT NUMBER LOOKS LIKE. `--`, never `0`: a player whose profile did not open has an
	-- UNKNOWN balance, and printing 0 would be this Hud asserting he has no coins.
	SCORE_COINS_UNKNOWN = "--",
	-- `%+d`: the sign is always drawn, because this drive could have COST him (a piglet is -10
	-- points, so -20 coins). "+34" and "-20" read as a change; "34" and "-20" read as two kinds of
	-- thing.
	SCORE_EARNED_FORMAT = "%+d",
	-- The balance on the drive bar, in every phase (the dispatch: the balance on the HUD).
	SCORE_COINS_LABEL = "COINS",

	-- The tied banner (design section 9.3 item 4), for the local player only. ASCII, like everything
	-- else drawn in this repo, and it says WHY -- the penalty is also the teaching mechanism.
	TIED_TEXT = "TIED TO A TREE - you fired toward the drive",
	TIED_TEXT_SIZE = 24,
	TIED_COLOR = Color3.fromRGB(255, 95, 75),
	TIED_TOP_OFFSET = 74, -- just under the drive bar, which moved to 44..70 (task 165)

	-- THE START CARD (task 158). Karen: *"we just need to at the begining what they can shoot and
	-- timer when start"*, *"Simple, readable, a few seconds, no tutorial"*. LAYOUT AND WORDING
	-- ONLY: the quarry lines themselves arrive on the snapshot, because what is legal is a rule and
	-- rules are the server's.
	START_CARD_WIDTH = 440,
	START_CARD_TITLE_SIZE = 24,
	START_CARD_TEXT_SIZE = 18,
	START_CARD_LINE_HEIGHT = 24,
	-- One role line plus the quarry's own. Four is two more than today's rule needs, which is the
	-- room red deer and a licence will want (Karen's doc) without a second layout.
	START_CARD_LINES_MAX = 4,
	START_CARD_COLOR = Color3.fromRGB(16, 18, 20),
	START_CARD_TRANSPARENCY = 0.25,
	-- UPPER MIDDLE, not dead centre: the centre of the screen is the crosshair and the sight
	-- picture, and this is up for ten seconds while a hunter is walking to his stand.
	START_CARD_TOP_SCALE = 0.22,
	START_CARD_HEADING = "YOU MAY SHOOT",
	-- The one line that counts down, in the words of the role it is for.
	START_CARD_HUNTER_TIMER = "GET TO YOUR STAND",
	START_CARD_BEATER_TIMER = "DRIVE STARTS IN",
	START_CARD_TIMER_COLOR = Color3.fromRGB(255, 232, 150),

	TEXT_COLOR = Color3.fromRGB(255, 255, 255),
	DRIVER_COLOR = Color3.fromRGB(90, 150, 255), -- Bright blue, the Drivers team colour
	SHOOTER_COLOR = Color3.fromRGB(255, 160, 60), -- Bright orange, the Shooters team colour
}

Drive.deepFreeze(Drive.CONFIG)

return Drive
