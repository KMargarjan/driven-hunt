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
}

export type MatchSnapshot = {
	phase: PhaseName,
	phaseEndsAt: number, -- SERVER TIME (Workspace:GetServerTimeNow), never a duration
	driveNumber: number,
	boarsReleased: number,
	boarsLeft: number,
	waitingFor: { string }, -- why it is Waiting: "players", or the missing tag names
	rows: { ScoreRow },
	tied: { number },
}

export type FeedEntry = {
	kind: string, -- "kill" | "escape" | "violation" | "phase" | "join" | "leave"
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
	-- 1.7b switches. They exist now so the Hud is written once and the panel stays dark until the
	-- score screen is built (design section 0, Director decision A).
	SCOREBOARD_ENABLED = false,

	FEED_LINES = 5,
	FEED_SECONDS = 8,

	BAR_TEXT_SIZE = 20,
	BAR_TOP_OFFSET = 8,
	FEED_TEXT_SIZE = 16,
	FEED_LEFT_OFFSET = 16,
	FEED_BOTTOM_OFFSET = 16,

	TEXT_COLOR = Color3.fromRGB(255, 255, 255),
	DRIVER_COLOR = Color3.fromRGB(90, 150, 255), -- Bright blue, the Drivers team colour
	SHOOTER_COLOR = Color3.fromRGB(255, 160, 60), -- Bright orange, the Shooters team colour
}

Drive.deepFreeze(Drive.CONFIG)

return Drive
