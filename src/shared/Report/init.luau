--!strict
-- Report: the WIRE CONTRACT and the layout numbers for the drive report. Deep-frozen data with NO
-- writer at run time, exactly as `src/shared/Drive/init.luau` is -- a shared table that anything may
-- read and nothing may change is the only shape in which "the server and the client agree about the
-- payload" is a fact rather than a hope.
--
-- Karen, 2026-10-05: *"we need to show when is killed logg or something similar / we need to indicate
-- a hit / and we need to show on the end what has been killed where was the hit / so after drive we
-- can see how much I killed compairing others"*.
--
-- Design: docs/design/drive-report.md (sections 5, 6.5, 7, 12)
-- Note:   docs/research/2026-10-05-drive-report.md
--
-- THE TYPES ARE DENSE ARRAYS OR PURE DICTIONARIES AND NOTHING ELSE, which is the rule
-- `src/shared/Drive/init.luau` states for `ScoreRow`: "a table that is neither a dense array nor a
-- pure dictionary does not survive the wire faithfully". `byKind` therefore always carries all four
-- keys as numbers, never nil.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Report = {}

-- ONE DOT ON THE SILHOUETTE: one shot that landed on one animal, in the ANIMAL's own frame.
--
-- `u` runs 0 at the nose to 1 at the tail, `v` 0 at the back to 1 at the belly, and `side` says which
-- flank. They are computed ONCE, at the moment of the hit (`HitLog.Shape.dot`), because a world
-- position stops meaning anything the moment the carcass is shoved or despawned and "high on the
-- shoulder" has to still mean that when the panel is drawn.
export type WireDot = {
	userId: number?,
	name: string?,
	zone: string,
	u: number,
	v: number,
	side: number,
	distance: number,
	pellets: number,
	at: number,
	fatal: boolean,
}

export type AnimalRow = {
	id: string,
	kind: string?,
	result: string,
	zone: string,
	distance: number,
	hits: number,
	droppedHits: number,
	at: number,
	dots: { WireDot },
}

export type HunterRow = {
	userId: number,
	name: string,
	kills: number,
	lost: number,
	hits: number,
	animals: number,
	byKind: { male: number, female: number, cub: number, unknown: number },
}

export type ListPayload = {
	view: string,
	drive: number,
	openedAt: number,
	seconds: number,
	closed: boolean,
	rows: { HunterRow },
	animals: number,
	truncated: boolean,
}

export type DetailPayload = {
	view: string,
	drive: number,
	userId: number,
	name: string,
	page: number,
	pages: number,
	rows: { AnimalRow },
}

-- ONE EVENT TYPE FOR THREE THINGS, because they are three things the client reacts to in the same
-- place: a kill happened, a drive opened, a drive closed. `kind` is the discriminator.
export type Event = {
	kind: string,
	drive: number,
	userId: number?,
	name: string?,
	animalKind: string?,
	zone: string?,
	distance: number?,
	at: number,
}

-- Every number here is from the design's section 12, where each one has its reason written down.
Report.CONFIG = {
	-- THE RECORD'S CEILINGS. Bounded by construction and not by hope: two drives, 96 animals each,
	-- 8 dots each is ~1,500 small tables for the whole server, and `BOARS_PER_DRIVE` is 60 today so
	-- 96 is 1.6x headroom.
	DRIVES_KEPT = 2,
	ANIMALS_PER_DRIVE_KEPT = 96,
	HITS_PER_ANIMAL = 8,

	-- THE PAYLOAD'S CEILINGS, read by the SERVER so a client cannot ask for more than this.
	HUNTER_ROWS = 16, -- Match.CONFIG.MAX_PLAYERS
	ANIMALS_PER_PAGE = 8,

	-- ONE INBOUND REMOTE, AND IT IS RATIONED. Over-fast requests are dropped and counted rather than
	-- queued: a queue is a thread a client can hold.
	REQUEST_MIN_INTERVAL = 0.5,

	-- WHAT A HUNTER READS. The payload carries STUDS, because studs are what the game measures in;
	-- the panel turns them into metres, which is what a hunter reads.
	METRES_PER_STUD = 0.28,

	-- The five zones the damage model actually has (`Boar.CONFIG.WOUND.DAMAGE`), in nose-to-tail
	-- order. The silhouette is divided into exactly these and no more: drawing a liver this game
	-- never simulates is the mistake Way of the Hunter's own players describe (research note).
	ZONES = { "head", "chest", "body", "legs", "rear" },

	-- THE SILHOUETTE, AS RECTANGLES IN THE SAME UNIT SQUARE THE DOTS LIVE IN (design section 8.2).
	--
	-- These are NOT drawn by eye. Each one is `Boar.CONFIG.ZONES[zone]`'s own box projected through
	-- `HitLog.Shape.dot`'s mapping -- u = (z + halfLength) / length, v = 0.5 - y / height -- against
	-- the male trunk `Boar.CONFIG.BODY_SIZE`. `Shape.rectOf` IS that projection, and
	-- `tests/server/report_silhouette.spec.luau` recomputes every number here from `Boar.CONFIG` and
	-- fails the harness if a zone box moves. A hand-carried constant with a check that fails when its
	-- source moves: the pattern `MatchBoot`'s arena assertion already uses.
	--
	-- WHY A SHARED CONSTANT AT ALL, when the panel could ask `Boar`: because `Boar` is a SERVER module
	-- (`src/server/Boar/`) and the panel is a client. The alternative is replicating the boar's whole
	-- config to every client to draw five rectangles.
	--
	-- The four zone rects are PAIRWISE DISJOINT in this projection, which the spec also asserts: a dot
	-- can then only ever sit in one named zone. What is left over is `body` -- the flank between chest
	-- and rump, the brisket under the head, the band above the legs -- which is exactly what the
	-- trunk's own comment says `body` is ("belly, flank, rear and brisket -- whatever no zone part
	-- covers"). So the picture tells the truth about the model, including where the model is vague.
	SILHOUETTE = {
		-- Nose at u = 0, tail at u = 1; back at v = 0, belly at v = 1.
		head = { u0 = 0.000, u1 = 0.236, v0 = 0.000, v1 = 0.383, tint = Color3.fromRGB(206, 120, 120) },
		chest = { u0 = 0.236, u1 = 0.545, v0 = 0.000, v1 = 0.650, tint = Color3.fromRGB(198, 150, 150) },
		rear = { u0 = 0.700, u1 = 1.000, v0 = 0.000, v1 = 0.600, tint = Color3.fromRGB(150, 150, 190) },
		legs = { u0 = 0.036, u1 = 1.000, v0 = 0.667, v1 = 1.000, tint = Color3.fromRGB(150, 128, 104) },
		-- The trunk itself, drawn under the four: `body` is the fallback zone and covers all of it.
		body = { u0 = 0.000, u1 = 1.000, v0 = 0.000, v1 = 1.000, tint = Color3.fromRGB(96, 84, 76) },
	},

	-- HOW SOLID THE PANEL IS, and it is NOT `Drive.CONFIG.SCORE_PANEL_TRANSPARENCY`. That number is
	-- 0.25 and it was tuned over the ARENA, which is a dark grey box; the first frame of this panel
	-- was taken over a sunlit forest and the trees, the grass and the player's own gun read straight
	-- through the text. A report is a thing you stop and read, so it is OPAQUE. 0.08 was tried first
	-- and the second frame still showed tree trunks and the mown grass line through it, so the number
	-- is 0: a hunting report is not a HUD overlay, it is a page.
	PANEL_TRANSPARENCY = 0,
	-- Lighter than the score panel's near-black (16, 18, 20), which was picked to sit at 0.25 over a
	-- dark arena. Opaque and near-black is a hole in the screen; this reads as paper.
	PANEL_COLOR = Color3.fromRGB(26, 29, 32),
	-- The silhouette's own backing, so a 104-px picture of a boar is never read against a tree.
	ART_BACKGROUND = Color3.fromRGB(26, 28, 30),

	-- THE PANEL (design section 8.3). 640 px tall leaves 440 px of a 1080p screen spare, which is the
	-- note's "one screen, no scrolling for 8 hunters".
	PANEL_WIDTH = 760,
	PANEL_HEIGHT = 640,
	PANEL_Z_INDEX = 10, -- over the feed at 1 and the score panel at 5
	TITLE_HEIGHT = 28,
	HEADER_HEIGHT = 22,
	FOOTER_HEIGHT = 24,
	LIST_ROW_HEIGHT = 22, -- the score panel's own row height
	DETAIL_ROW_HEIGHT = 68,
	SILHOUETTE_WIDTH = 104, -- the boar is 5.5 x 3, so 104 x 56 is its own proportion
	SILHOUETTE_HEIGHT = 56,
	DOT_PIXELS = 7,
	-- WHERE THE DETAIL ROW'S TEXT STARTS, and the header sits at the same x so the columns line up
	-- under their own names. MEASURED off the first frame of the detail view, where they did not.
	DETAIL_TEXT_X = 136,
	FAR_SIDE_TRANSPARENCY = 0.55, -- a dot on the far flank, so you can see which side it came in on
	TOGGLE_KEY = Enum.KeyCode.Tab,
}

Report.FOLDER_NAME = "Report"
Report.REMOTES_NAME = "Remotes"

-- The three remotes, found the way `Shotgun.remotes()` and `Drive.remotes()` find theirs. A server
-- call waits; a client call waits. Nothing here creates them -- they are a `.model.json` under
-- `src/shared/Report/`, so Rojo owns them and no script may add a fourth.
function Report.remotes()
	local folder = ReplicatedStorage:WaitForChild(Report.FOLDER_NAME):WaitForChild(Report.REMOTES_NAME)
	return {
		ReportEvent = folder:WaitForChild("ReportEvent") :: RemoteEvent,
		ReportRequest = folder:WaitForChild("ReportRequest") :: RemoteEvent,
		ReportData = folder:WaitForChild("ReportData") :: RemoteEvent,
	}
end

-- METRES, ROUNDED THE WAY A HUNTER SAYS THEM. Pure and exported so the kill line and the detail row
-- cannot disagree about what "42 m" means.
function Report.metres(studs: number?): number
	return math.round((studs or 0) * Report.CONFIG.METRES_PER_STUD)
end

-- Deep-frozen for the same reason `Drive` is: a shared table with no writer is the only kind both
-- sides can trust. `table.freeze` is shallow, so each nested table is frozen too.
local function deepFreeze(value)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in pairs(value) do
			deepFreeze(child)
		end
		table.freeze(value)
	end
	return value
end

deepFreeze(Report.CONFIG)

return Report
