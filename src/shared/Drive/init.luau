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
Drive.Rank = table.freeze(require(script.Rank))
-- FROZEN, because it is the ONE implementation of "who is first" and the server pays a bonus
-- off it: an unfrozen export is a rule any requirer could replace (round 1 note).

export type TeamName = "Drivers" | "Shooters"
export type PhaseName = "Waiting" | "Assigning" | "Running" | "Scoring"

-- THE RUNTIME HALF OF `Drive.TeamName` (task 217): the membership test, so a validator does not need
-- a sixth copy of the two strings. A type is a compile-time fact and `Economy.teamFromRecord` has to
-- answer a question about a value that came off a DataStore key -- which is a run-time fact, and the
-- only thing standing between a corrupted profile and a player on the wrong side.
--
-- FROZEN SHARED DATA WITH NO WRITER, the discipline the rest of this module follows (`Drive.Rank`
-- above, `Drive.CONFIG` below). It holds no game number, so the header's rule is intact.
-- Design: docs/design/role-rotation.md (section 3.4)
Drive.TEAMS = table.freeze({ Drivers = true, Shooters = true })

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
	-- coins. The Hud draws an absent one as `Money.UNKNOWN`.
	--
	-- THE RATES ARE NOT HERE, exactly as the points table is not (see the header): these are two
	-- RESULTS, already computed on the server out of `Economy.CONFIG`, which is never replicated.
	coins: number?, -- the BALANCE after this drive's pay-out. On screen in every phase
	earned: number?, -- what THIS drive paid him. MAY BE NEGATIVE (a piglet costs points)
}

-- ONE KIND THE DRIVE ALLOWS, AND ITS PRICE. `kind` is the SERVER's data string (`male`, `female`,
-- `cub`); the player-facing noun is `Report.kindWord`'s and the start card's own copy below -- the
-- Designer's rule 4: *"`cub` is never printed. The player-facing word is `piglet`"*.
export type QuarryRow = {
	species: string,
	kind: string,
	points: number?,
}

export type MatchSnapshot = {
	phase: PhaseName,
	phaseEndsAt: number, -- SERVER TIME (Workspace:GetServerTimeNow), never a duration
	driveNumber: number,
	boarsReleased: number,
	boarsLeft: number,
	waitingFor: { string }, -- why it is Waiting: "players", or the missing tag names
	-- WHAT MAY BE SHOT IN THIS DRIVE -- the start card's rows (task 158, ROWS since 201 part 3).
	-- The RULE is the server's (`Match.quarryRows`); this side only lays it out, so a client holds
	-- no second copy of what is legal. One entry per KIND, with what that kind is worth: a `nil`
	-- `points` means the server has no price for it and the card draws the row with no number.
	quarry: { QuarryRow },
	-- WHAT SHOOTING A PERSON COSTS (`Match.CONFIG.POINTS.SAFETY_PENALTY`), for the start card's
	-- last row. ABSENT means the server never sent it, and the card then draws no person row --
	-- never a typed-in -10, which would be a second copy of a penalty.
	safetyPenalty: number?,
	rows: { ScoreRow },
	-- WHETHER THIS BUILD HAS MONEY IN IT (task 170, round 2 of the gate). ONE fact for the whole
	-- board, not a row field, because whether money exists is a property of the server. ABSENT means
	-- no -- which is exactly what every build before task 170 sends -- and the Hud then draws no
	-- balance at all, rather than a `COINS --` that says "unknown" about a thing that does not exist.
	-- It is what lets the screen tell THE ECONOMY IS OFF from THIS PLAYER HAS NO PROFILE OPEN, which
	-- the rows alone cannot: `coins` is absent in both.
	coinsOn: boolean?,
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
	-- WHO PAID FOR THE HUNTER'S PLACE AND IS DRIVING ANYWAY (task 221). Karen, 2026-10-20:
	-- *"Posibility to be a hunter always"* -- which this repo sells as a strong PREFERENCE, because
	-- `Roster.assign`'s balance rule still has to be able to make a drive out of the roster. This
	-- list is so the man's own screen can say WHY, and it is the same shape as `tied` and `through`
	-- above it, for the same reason.
	--
	-- OPTIONAL, unlike those two: ABSENT means there is no economy in this build at all, which is
	-- the `stands` and `coinsOn` idiom -- so a client that never heard of the field reads exactly
	-- what it always did.
	roleOverruled: { number }?,
	-- WHERE EACH SHOOTER'S STAND CIRCLE IS (task 171), keyed by `tostring(userId)` -- the keying
	-- `Horn.keyFor` already uses, because a JSON-ish table on the wire has string keys. Absent for a
	-- beater and for anybody the drive has nowhere to put, which means NO CIRCLE and therefore no
	-- rule (`Weapon.Rules.outsideStand`).
	--
	-- IT IS THE SERVER'S OWN ANSWER, THE SAME ONE THE FIRE GATE READS (`Match.standAreaOf`), and that
	-- is the point of publishing it: before this the client had no way to know where a hunter's stand
	-- was in the DEV world at all (`Hud.Objective`'s own note: *"doing better needs the drive to
	-- publish the assigned stand index"*), so `zz_tie_to_a_tree.spec` staged its shot 525 studs from
	-- the shooter's post and the off-stand rule correctly refused it. A client that wants to DRAW the
	-- ring -- task 166 draws one in the Forest Test only -- now has the circle to draw.
	stands: { [string]: { centre: Vector3, radius: number } }?,
}

export type FeedEntry = {
	-- "kill" | "escape" | "violation" | "phase" | "join" | "leave" | "signal" | "fine"
	-- "signal" IS THE ONE KIND THAT IS NOT A LINE (task 163): its `text` is "start" or "end" and the
	-- Hud answers it with the drive's horn instead of a word. The channel is reused on purpose --
	-- `MatchEvent` already reaches every client once per event, and the Hud already has the rule
	-- that an entry with no text draws nothing (`Hud.feedTextFor`).
	kind: string,
	userId: number?,
	name: string?,
	zone: string?,
	points: number?,
	-- MONEY THIS EVENT MOVED, SIGNED AND IN DOLLARS (task 250), or absent when it moved none. A fine
	-- is NEGATIVE, which is `Money.signed`'s own convention (*"a drive can have COST him"*) and the
	-- reason the sign is on the wire rather than invented by the screen.
	--
	-- `kind = "fine"` IS THE ONE ENTRY THAT EXISTS ONLY TO SAY THIS, and its `text` is the WORD the
	-- line prints after the figure -- "PIGLET", "CALF", "PERSON IN LINE", and "FINES" for the
	-- drive's own total at the end of it. `kind = "violation"` carries one too, because the tie and
	-- the fine are one event and two lines about one shot would read as two shots.
	money: number?,
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
	-- THE ROLE WORDS ARE OFF THE ROWS ENTIRELY (task 170 took the TEAM column; the heading carries
	-- the side), and the one word that is still drawn -- the status bar's pill -- says HUNTER /
	-- BEATER since 201 part 3, which is Karen's own vocabulary and the start card's.
	-- `Shooters` / `Drivers` remain the TEAM names on the wire; only what is DRAWN moved.
	SCORE_TITLE_FORMAT = "DRIVE %d RESULTS",
	-- THE SAME SENTENCE IN TWO PIECES SINCE TASK 201 PART 2, because the board wears an EYEBROW and
	-- a TITLE now (the Designer's design system, 2026-10-17, section 3.4): the small brass word
	-- above the title saying WHAT KIND OF THING THIS IS, and then the thing. `SCORE_TITLE_FORMAT`
	-- is kept for the one line a reader may still want whole.
	SCORE_EYEBROW_FORMAT = "DRIVE %d",
	SCORE_TITLE_WORD = "RESULTS",
	-- The footer, over the bar that drains while the next drive is coming.
	SCORE_FOOTER_WORD = "NEXT DRIVE IN",
	-- THE FEED'S FINE LINE (task 250), and the format is the Director's own wording -- the figure, a
	-- middle dot, then the reason: *"-$500 . PIGLET"* with a real U+00B7 where that dot is. Written down here because that is this table's rule -- *"every word the panel
	-- draws is written down"* -- and the FIGURE is `Money.signed`'s, never this string's.
	--
	-- THE SEPARATOR IS A MIDDLE DOT (U+00B7) AND IT IS A DATA ROW, so a font that draws it as a
	-- box is one character's edit rather than a hunt through the Hud. It is written as a `\u{}`
	-- escape rather than as the character itself, so this FILE stays ASCII and no encoding on the
	-- way through Rojo, git or a terminal can turn the string into mojibake. It is NOT drawn with
	-- `Style.glyph`, whose header warns that *"a glyph a font does not have comes back as"* a box:
	-- this is a text label and the dot is in the body font.
	FEED_FINE_FORMAT = "%s \u{00B7} %s",
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
	-- THE DASHES ARE GONE SINCE TASK 201 PART 2 and a 1 px rule took their place: a section head is
	-- an EYEBROW in the team's colour plus a rule filling the rest of the width (design system
	-- section 3.12). `-- HUNTERS --` was a rule drawn in punctuation because the old board had no
	-- way to draw one.
	SCORE_HUNTERS_HEADING = "HUNTERS",
	SCORE_BEATERS_HEADING = "BEATERS",
	-- Drawn ONLY when that list has a row in it -- the rule the retired `Match.quarryLines` applied to
	-- its own POINTS label: *"THE WORD ONLY WHEN THERE IS A NUMBER UNDER IT"*. A row has no team
	-- when a player joined outside `Assigning`/`Running`, which is a real state and not an error.
	SCORE_OTHERS_HEADING = "OTHERS",
	-- `SCORE_COINS_UNKNOWN` IS GONE (task 221): it is `Money.UNKNOWN` now, in the one module that
	-- owns how money looks. The rule it carried is unchanged and lives there -- `--`, never `0`,
	-- because a player whose profile did not open has an UNKNOWN balance and printing 0 would be
	-- the Hud asserting he has none.
	-- `SCORE_EARNED_FORMAT` IS GONE (task 221): it is `Money.signed` now. The reason it carried is
	-- unchanged and lives there -- the sign is always drawn, because a drive could have COST him (a
	-- piglet is -10 points, so -$20), and "+$34" and "-$20" read as a change where "$34" and "-$20"
	-- read as two kinds of thing.
	-- `SCORE_COINS_LABEL` IS GONE (task 221). Karen, 2026-10-20: *"We need to change coins to
	-- actual money $"* -- the word is `Money.WORD` and the number is `Money.text`, in the one
	-- module that owns both, so the drive bar and the shop window cannot disagree about either.

	-- The tied banner (design section 9.3 item 4), for the local player only. ASCII, like everything
	-- else drawn in this repo, and it says WHY -- the penalty is also the teaching mechanism.
	TIED_TEXT = "TIED TO A TREE - you fired toward the drive",
	TIED_TEXT_SIZE = 24,
	TIED_COLOR = Color3.fromRGB(255, 95, 75),
	-- 74 -> 96 (task 201 part 2). The banner is ONE CENTRED CLAY TOAST now (the Designer's design
	-- system, 2026-10-17, section 5 surface 13) and a toast at the `TITLE` step is 40 px tall, not
	-- 30 -- so it no longer fits the 74..104 slot between the status slate and the compass.
	--
	-- 96 IS THE DESIGNER'S OWN NUMBER, and it puts the toast OVER the compass strip (108..138) on
	-- purpose: section 4.3's TOP BAND contract names exactly three members -- objective, status,
	-- compass -- and this is not one of them. It is a NOTICE, it is up for seconds, and a player
	-- roped to a tree cannot walk anywhere the compass would help him get to. It is drawn above the
	-- band's own ZIndex so it covers rather than is covered.
	TIED_TOP_OFFSET = 96,

	-- ---------------------------------------------------------------- THE START CARD
	--
	-- Task 158, REBUILT TO THE DESIGNER'S OWN SPEC IN 201 PART 3 (`startcard-spec.md`, 2026-10-18,
	-- an amendment to `design-system.md` surface 10). Karen, having played that day: *"this message
	-- has to be improved maybe each from new line ask designer more user friendly"*.
	--
	-- WHAT IS HERE IS WORDS AND SIZES -- the card's COPY and its two layouts. Every colour, face,
	-- radius, duration and opacity it draws with is `Style`'s, and the one rule on it (what may be
	-- shot, and what it is worth) is the SERVER's, on the snapshot. The old block this replaces --
	-- a 440-wide panel of four 24 px lines in `Enum.Font.Code` over `Color3.fromRGB(16, 18, 20)` --
	-- is in `backups/2026-10-18_task-201-3_quarry-lines.txt`.
	--
	-- THE CARD IS 274 TALL AT FOUR ROWS AND NOT "auto, max 220" (the spec's amendment 1 to the
	-- system's section 4.1): eight children will not live in 220 at this type scale. It is up ONLY
	-- in `Assigning`, when every player is being placed and nobody is aiming, which is the same
	-- argument that exempts the results board from section 4.3's *"the centre 240 x 240 is never
	-- covered"*.
	--
	-- SINCE TASK 234 THE HEIGHT FOLLOWS THE ROW COUNT: `Hud.startCardHeight(viewX, rows)` is
	-- `chrome + rows * rowH`, and 274 is what that answers at four rows -- so a BEATER'S card is
	-- the card he has today, to the pixel, and only the hunter's grows for the deer. The number
	-- below is kept as that four-row figure because it is the Designer's own measurement and the
	-- live geometry (`Hud.START_CARD`) is checked against it.
	START_CARD_WIDTH = 440,
	START_CARD_HEIGHT = 274,
	START_CARD_TOP = 150,
	-- ON A PHONE IT IS 264 WIDE AND SITS AT THE LEFT SAFE MARGIN, not centred (amendment 2). A
	-- centred card runs x 16..384 on a 400 px screen: it buries the minimap (x 288..384) and sits
	-- under the rail, which draws OVER it. 16..280 stops 8 px short of the map, so a hunter keeps
	-- the map he needs to find his stand while the ten seconds run.
	START_CARD_WIDTH_PHONE = 264,
	START_CARD_HEIGHT_PHONE = 239,
	START_CARD_TOP_PHONE = 124,
	START_CARD_LEFT_PHONE = 16,
	-- ONE IDEA PER LINE. The Designer's section 1.4 made FOUR LINES the ceiling for a three-second
	-- read, and **task 234 raised it to eight, which is a real cost and is written down rather than
	-- smuggled**: Karen, 2026-10-21, *"I didnt see deer red tag why ?"* / *"I want to see a deer"*.
	-- A hunter's card is now three boar rows, a `RED DEER` head carrying the licence, three deer
	-- rows and the person -- eight -- and eight lines is not a three-second read. The alternative
	-- was leaving the licensed quarry off the one screen that answers *"what may I shoot"*, which
	-- is the defect she reported. Whether eight rows is still a CARD is the Designer's call and is
	-- queued.
	--
	-- A BEATER STILL HAS FOUR and his card is unchanged by identity: `START_CARD_BEATER_ROWS` has
	-- four entries and the card's height follows the rows it draws (`Hud.startCardHeight`).
	START_CARD_ROWS_MAX = 8,
	START_CARD_ROW_H = 24,
	START_CARD_ROW_H_PHONE = 21,

	-- THE EYEBROW AND THE ROLE LINE. `YOU ARE A HUNTER` is unchanged from task 158 and from
	-- `Hud.roleWord`: it is the one line Karen already approved and it is the card's first second.
	START_CARD_EYEBROW = "DRIVE %d",
	START_CARD_ROLE = "YOU ARE A %s",
	-- THE SECTION HEAD, one per role. The same two words start both -- a player who has played the
	-- other side finds the list in the same place. `YOU MAY SHOOT` (task 158's heading) was wrong
	-- over a list whose last two rows are things you must NOT shoot.
	START_CARD_SECTION_HUNTER = "WHAT TO SHOOT",
	START_CARD_SECTION_BEATER = "WHAT TO DO",

	-- WHAT EACH QUARRY KIND IS CALLED ON THIS CARD. The KINDS and their POINTS arrive on the
	-- snapshot (`Match.quarryRows`) -- this is only the copy drawn beside the number.
	--
	-- `piglet`, NEVER `cub` (the spec's rule 4). `Report.kindWord` is the one place that mapping
	-- lives and the fallback below reads it, so a kind with no row here is still never printed as
	-- `cub`. Karen's own *"leave them"* is kept from the retired `QUARRY_NOTE`, because it is the
	-- INSTRUCTION: the number says what a piglet costs, the words say what to do about it.
	START_CARD_QUARRY_WORDS = {
		male = "Male boar",
		female = "Female boar",
		cub = "Piglet - leave them",
		-- THE RED DEER (task 234). Three words that do NOT name their animal -- which is exactly
		-- why the deer get a species HEAD row above them and the boar do not: `Male boar` says what
		-- it is and `Hind` does not. `Report.kindWord` is still the fallback for a kind with no row
		-- here, so nothing is ever printed as a raw data word.
		--
		-- `Calf - leave them` IS `cub`'S OWN SENTENCE, deliberately word for word: Karen's rule of
		-- 2026-10-12 is that shooting the young is a penalty, `POINTS.KIND.calf` is the identical
		-- -10, and two different instructions for one rule would be two rules.
		stag = "Stag",
		hind = "Hind",
		calf = "Calf - leave them",
		-- THERE IS NO `legendary` ROW HERE (task 219) because there is no legendary ROW on the card:
		-- `START_CARD_ROWS_MAX` is 4 and the four are these three plus the person, which is the
		-- Designer's own ceiling two fields below. `Match.CONFIG.QUARRY` carries the whole reason.
		-- The day a fifth row exists, the word is "Legendary boar" -- not `Report.kindWord`'s
		-- "legendary", which names a rarity and not an animal.
	},
	-- THE ROW THE DESIGNER ADDED, and the only one whose price is not quarry: a tie to a tree and
	-- `SAFETY_PENALTY` were a real rule the card never mentioned, and the beaters are walking
	-- TOWARD the hunter while this card is up. Drawn only when the server sent the number.
	START_CARD_PERSON = "A person",

	-- THE SPECIES HEAD ROW, AND IT IS DRAWN ONLY OVER A SPECIES THAT NEEDS A LICENCE (task 234).
	-- Not a style: `Male boar` / `Female boar` / `Piglet` each name their animal in the words, and
	-- `Stag` / `Hind` / `Calf` cannot without three long labels -- so the deer need a line that
	-- says what they are, and that line is also the only place the LICENCE can be said. The
	-- right-hand cell is one slot and a row that shows `+20` cannot also show a tag.
	--
	-- The words are the SERVER's (`Match.quarryRows` sends the label off `Licences.ROWS`), and so
	-- is whether a licence is needed. This is the glyph and the tag only, and `NEEDS LICENCE` is
	-- the same amber tag the beater's first row already wears.
	START_CARD_SPECIES_GLYPH = "chevron",
	START_CARD_LICENCE_TAG = "NEEDS LICENCE",

	-- THE BEATER'S FOUR ROWS, in his own order. He asks "what may I shoot" too, so the answer is in
	-- the same slot on his card -- and the amber tag says WHY rather than "never": the licence is
	-- 250 coins and three hunts away in the shop, and amber already means *later / holding*.
	START_CARD_BEATER_ROWS = {
		{ glyph = "cross", text = "You do not shoot", tag = "NEEDS LICENCE" },
		{ glyph = "chevron", text = "Push the boars to the hunters" },
		{ glyph = "horn", text = "Click your horn as you walk" },
		-- Karen's rule: *"when beater cross the line of hunter it's done for him"*. The cost is not
		-- points, so the right-hand cell says the cost in WORDS.
		{ glyph = "cross", text = "Do not cross their line", word = "DRIVE OVER" },
	},

	-- THE LAST LINE IS AN INSTRUCTION ON BOTH CARDS, and it is the same deadline either way --
	-- which is what task 158's two labels obscured. `WAIT FOR THE HORN` is the phrase the objective
	-- line already shows a beater in `Assigning`.
	START_CARD_HUNTER_TIMER = "GET TO YOUR STAND",
	START_CARD_BEATER_TIMER = "WAIT FOR THE HORN",
	-- THE BAR HAS NO LENGTH CONSTANT ON PURPOSE. The phase is `Match.CONFIG.INTERMISSION_SECONDS`
	-- long -- 15 today, 20 and 10 before that -- and the client is not told it. A typed 10 here
	-- would draw a bar that is two thirds full on the frame the card appears. So the renderer
	-- LATCHES the largest `secondsLeft` it has seen since this card went up and fills against that
	-- (`Hud.startCardBarScale`): the first frame is full by construction, whatever the phase's
	-- length is, and the latch is cleared with the card.

	TEXT_COLOR = Color3.fromRGB(255, 255, 255),
	DRIVER_COLOR = Color3.fromRGB(90, 150, 255), -- Bright blue, the Drivers team colour
	SHOOTER_COLOR = Color3.fromRGB(255, 160, 60), -- Bright orange, the Shooters team colour
}

Drive.deepFreeze(Drive.CONFIG)

return Drive
