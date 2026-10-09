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
	-- A WILD BOAR, SIDE ON, IN THE SAME UNIT SQUARE AS THE DOTS (task 135). Karen, 2026-10-05:
	-- *"something simple but cool"*, and *"see boars where was the hit"*. What this panel drew until
	-- now was `SILHOUETTE` below painted straight onto the screen -- five tinted rectangles, which
	-- task 124 round 3's own note called "a colour-coded bar, not a boar's outline".
	--
	-- THE RECTANGLES BELOW ARE STILL THE TRUTH ABOUT WHERE A SHOT LANDED; this is the PICTURE. The
	-- two are deliberately separate: `SILHOUETTE` is `Boar.CONFIG.ZONES` projected and a spec fails
	-- the harness if it drifts, while this is drawn by eye against a photograph of the animal and
	-- nothing about the record depends on it. A dot's (u, v) is placed in the square exactly as
	-- before -- this file changed no dot by a pixel.
	--
	-- NO UPLOAD, NO IMAGE, NO MESH: eleven `Frame`s with a `UICorner` each, so it costs what the five
	-- rectangles cost, renders at any size (every number is a SCALE), and needs no asset id -- which
	-- matters because the asset tool is models-only and an image cannot be uploaded from here.
	--
	-- THE ORDER IS THE DRAW ORDER, back to front: the body masses first, then the head, then the
	-- small parts that read as detail. `corner` is a UICorner radius as a fraction of the part's own
	-- SHORTER side, so a leg stays a leg and the barrel stays round.
	--
	-- WHAT MAKES IT READ AS A BOAR AND NOT A PIG, in order of how much each one is worth at 104 x 56
	-- pixels: the high shoulder hump above a back that slopes DOWN to the rump; the long wedge head
	-- carried low, nose nearly at the ground line; short legs under a deep barrel; the small upright
	-- ear set well back; and a short straight tail.
	--
	-- `Haunch` AND `Head` ARE AXIS-ALIGNED AND ARE ASSERTED (`tests/server/report_silhouette.spec`):
	-- the head zone's centre has to land inside `Head` and the rear zone's inside `Haunch`, so the
	-- drawing cannot drift away from the record it sits under.
	BOAR = {
		-- THE BARREL, and everything else is hung on it.
		{ name = "Trunk", u0 = 0.33, u1 = 0.90, v0 = 0.16, v1 = 0.66, corner = 0.38 },
		-- THE WITHERS, the highest point on the animal and most of what separates a boar's outline
		-- from a pig's: the back falls away from here to a lower rump.
		{ name = "Shoulder", u0 = 0.32, u1 = 0.60, v0 = 0.05, v1 = 0.58, corner = 0.45 },
		{ name = "Haunch", u0 = 0.64, u1 = 0.97, v0 = 0.17, v1 = 0.71, corner = 0.45 },
		-- The underline, between the legs: it is where the belly really is, and it is also what a
		-- low hit lands on instead of hanging in the air between two legs.
		{ name = "Belly", u0 = 0.34, u1 = 0.92, v0 = 0.57, v1 = 0.74, corner = 0.35 },
		-- THE NECK, and it is not decoration: without it the head and the shoulder are two rounded
		-- lumps with a notch between them, which is what the second frame of this task showed.
		{ name = "Neck", u0 = 0.25, u1 = 0.41, v0 = 0.15, v1 = 0.54, corner = 0.25 },
		-- THE HEAD IS CARRIED HIGH, AND THAT IS THE MODEL'S OWN ANSWER RATHER THAN A PHOTOGRAPH'S.
		-- `Boar.CONFIG.ZONES.head` sits at y 0.35..1.65 on a trunk 3 studs tall, which projects to
		-- v 0..0.383 -- the TOP of the box, not the bottom. A boar drawn with its nose near the
		-- ground would be a prettier animal telling a lie about where a head shot lands, and the
		-- containment assertion in `report_silhouette.spec` is there to keep the two honest.
		{ name = "Head", u0 = 0.04, u1 = 0.33, v0 = 0.10, v1 = 0.52, corner = 0.38 },
		-- ...tapering forward and DOWN into the snout, which is the wedge.
		{ name = "Snout", u0 = 0.00, u1 = 0.13, v0 = 0.27, v1 = 0.48, corner = 0.45 },
		{ name = "Ear", u0 = 0.23, u1 = 0.32, v0 = 0.00, v1 = 0.15, corner = 0.35 },
		-- Four short legs. The near pair reaches the ground line and the far pair stops short, which
		-- is the cheapest way to read as four legs rather than two.
		{ name = "LegFrontNear", u0 = 0.36, u1 = 0.45, v0 = 0.62, v1 = 0.99, corner = 0.30 },
		{ name = "LegFrontFar", u0 = 0.48, u1 = 0.57, v0 = 0.62, v1 = 0.93, corner = 0.30 },
		{ name = "LegRearNear", u0 = 0.72, u1 = 0.81, v0 = 0.62, v1 = 0.99, corner = 0.30 },
		{ name = "LegRearFar", u0 = 0.84, u1 = 0.93, v0 = 0.62, v1 = 0.93, corner = 0.30 },
		-- Short and straight, which is what a boar's is.
		{ name = "Tail", u0 = 0.94, u1 = 1.00, v0 = 0.20, v1 = 0.40, corner = 0.45 },
	},

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
	-- THE ONE FILL THE WHOLE ANIMAL IS DRAWN IN (task 135). A silhouette is one shape, so every part
	-- of `BOAR` below is this colour and the shape alone carries the reading.
	--
	-- IT IS A LIGHT FILL ON THE DARK BACKING, not the other way round, and that is a measurement
	-- rather than a preference: `ART_BACKGROUND` is (26, 28, 30) because the first frame of this
	-- panel was read against sunlit leaves and lost (see `buildSilhouette`). A dark animal on that
	-- backing is not a silhouette, it is nothing. This is the old `body` tint (96, 84, 76) lifted
	-- until it carries against the backing while staying well under the white dots drawn on top.
	BOAR_FILL = Color3.fromRGB(112, 99, 88),

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
