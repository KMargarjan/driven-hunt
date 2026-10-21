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
-- pure dictionary does not survive the wire faithfully". `byKind` therefore always carries all EIGHT
-- keys as numbers, never nil (`legendary` is the fifth, task 219).
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
	-- WHICH GUN MADE THIS HIT (task 140): a weapon id, nil for a record from before the rifle. The
	-- WIRE carries the id and the SCREEN carries the word, which `Weapons.row(id).label` resolves --
	-- the same split `AMMO_LABEL` has.
	weapon: string?,
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
	weapon: string?, -- task 140: the gun the best shot came from
	dots: { WireDot },
}

-- ONE SHOT'S WORTH OF DOTS, SENT TO THE PLAYER WHO FIRED IT AND TO NOBODY ELSE (task 198). This is
-- the hit card's whole payload, and every number in it is the SERVER's: the client decides nothing
-- about where a pellet landed.
--
-- `dots` is one entry per PROJECTILE that struck the animal -- nine for a full buckshot pattern,
-- one for a slug -- each projected by `HitLog.Shape.dot`, the same function the drive report's dots
-- come out of. `lead` marks the one dot that IS the drive report's dot for this shot (the nearest
-- impact, which is the position `Weapon.Hits.group` reports), so the card and the TAB report can be
-- put side by side and the same mark found on both.
export type CardDot = {
	u: number,
	v: number,
	side: number,
	zone: string,
	lead: boolean,
}

export type CardPayload = {
	kind: string,
	drive: number,
	animal: string,
	animalKind: string?,
	weapon: string?,
	ammo: string?,
	hits: number,
	fired: number?,
	distance: number,
	at: number,
	dots: { CardDot },
}

export type HunterRow = {
	userId: number,
	name: string,
	kills: number,
	lost: number,
	hits: number,
	animals: number,
	-- ...AND `legendary` SINCE TASK 219, because `unknown` means a kind TYPO and is counted so a
	-- typo shows up as a number rather than as an animal that quietly scores nothing. A legendary
	-- falling into that bucket would have destroyed exactly that signal -- and it would have been
	-- invisible, because the list table already adds `unknown` into its MALE column.
	-- EIGHT KEYS SINCE TASK 223 (the three red deer), and ALL of them always, as numbers: a
	-- dictionary with a hole does not survive the wire faithfully.
	byKind: {
		male: number,
		female: number,
		cub: number,
		legendary: number,
		stag: number,
		hind: number,
		calf: number,
		unknown: number,
	},
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
	weapon: string?, -- task 140; see `WireDot.weapon`
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

	-- KAREN'S OWN TWO SILHOUETTES (task 205). She played on 2026-10-18 and said of the hit card:
	-- *"and what is that? you need proper image for wildboar when showing hit now it feels mess
	-- unclear wtf ? / it's in download male named"*. `karen-2026-10-18/shot-4.png` is what she was
	-- looking at: the fourteen `Frame`s of `BOAR` below, which at 148 x 80 read as two rounded blobs
	-- with four stubs.
	--
	-- THEY ARE UPLOADS, AND THAT IS THE CHANGE. Her two JPGs carry a BAKED grey/white checkerboard
	-- (not an alpha channel), so each was keyed to a transparent PNG -- every pixel under luminance
	-- 60 opaque black, over 150 clear, a narrow ramp between for the anti-aliased edge -- cropped to
	-- the animal, and uploaded as a `Decal`. Her OK and the moderation state are in
	-- `assets/uploads.json`; the JPG and the PNG live outside the repo and are never committed.
	--
	-- `box` IS WHERE THE DOTS' UNIT SQUARE SITS ON THE IMAGE, as fractions of the PNG, and it was
	-- MEASURED on the keyed pixels rather than inherited from the frame drawing. The unit square is
	-- the boar's TRUNK (nose u = 0, tail u = 1, back v = 0, belly v = 1) and the image is the whole
	-- animal -- legs, tail and mane included -- so the two are not the same rectangle.
	--
	-- IT IS A FIT AND NOT THE OUTLINE'S EXTREMES, and that is the measurement worth writing down.
	-- Taking the raw nose/rump/back/belly of the PNG put the HEAD zone's centre OFF the animal (11 %
	-- of a head box's sample grid on black, male) because this boar carries its head low and its
	-- withers high, which the game's box model does not. The box below was searched for the one that
	-- keeps every zone of `SILHOUETTE` on the animal while still SPANNING it -- 82 % of the worst
	-- zone's grid and every zone's centre on black, against 11 % before. A box that scored 100 %
	-- was available and refused: it shrank onto the torso, so a head shot and a rump shot both drew
	-- inside the belly and the picture stopped meaning where the shot landed.
	-- THE ID IS THE IMAGE'S AND NOT THE DECAL'S, AND THAT COST THIS TASK A WHOLE ROUND. An Open
	-- Cloud upload of a PNG creates a **Decal** (`AssetTypeId 13`), and the id it returns is the
	-- DECAL's -- which an `ImageLabel` cannot draw. Measured in Play on 2026-10-18, three labels on
	-- one plate (`.screenshots/20261018T173221Z-t205-mirror-probe.png`): with the decal ids every
	-- label was `IsLoaded = false` and the plate was EMPTY, while a built-in `rbxasset://` control
	-- beside them loaded. So the card has been drawing NO ANIMAL AT ALL since the silhouettes
	-- landed, which no spec could see -- `Image` is a string and it was set correctly.
	--
	-- HOW TO GET THE IMAGE ID FROM A DECAL ID: on the SERVER,
	-- `InsertService:LoadAsset(decalId)` returns a model holding a `Decal`, and its `.Texture` is
	-- the image. Run on 2026-10-18: `80206901277832 -> rbxassetid://135789362198066` and
	-- `108874258373849 -> rbxassetid://121961957713451`. Both decal ids stay in
	-- `assets/uploads.json`, because that file records what was UPLOADED.
	--
	-- THE TWO RED DEER (task 223), through the same route and with the same trap avoided. Karen's
	-- `male deer.jpg` and `famale deer.jpg`, upload OK verbatim `"yes"` on 2026-10-20 ~13:10, keyed
	-- off their baked checkerboards by the identical rule (under luminance 60 opaque, over 150
	-- clear, a ramp between) and cropped to the animal. The DECAL ids are in `assets/uploads.json`
	-- (108848438402547 and 83171385137200); the ids below are the IMAGE ids those decals carry,
	-- resolved on the server with `InsertService:LoadAsset(decalId).Texture` on 2026-10-20 --
	-- 108848438402547 -> 82382119550819 and 83171385137200 -> 134628251396589.
	--
	-- **THE DEER'S `box` IS THE PICTURE'S OWN GEOMETRY AND NOT A FITTED COMPROMISE, AND THAT IS A
	-- DEPARTURE FROM THE BOAR'S WORTH WRITING DOWN.** The unit square is the animal's own trunk box
	-- -- `HitLog.Shape.dot` normalises every dot by it -- so it was MEASURED on the keyed pixels as
	-- nose, rump, BACK LINE and hooves: the stag's back is row 288 of 758 (v0 = 0.380) and the
	-- hind's row 183 of 662 (v0 = 0.276), with the antlers and the raised head standing ABOVE the
	-- square exactly as they stand above the physics box.
	--
	-- A fitted box was tried first, maximising the same zone coverage task 205 maximised, and it was
	-- REFUSED for the reason task 205 itself gives: it slid onto the torso (the stag's came back
	-- spanning only the back to the belly, so a leg hit would have drawn a dot on the brisket) and
	-- *"a head shot and a rump shot both drew inside the belly and the picture stopped meaning where
	-- the shot landed"*. The overlays were rendered and LOOKED AT at every step
	-- (`<assets-dir>/deer/silhouettes/overlay-*.png`).
	--
	-- **WHAT THIS BOX SCORES AGAINST THE BOAR'S `SILHOUETTE` RECTANGLES IS LOW AND IT IS REPORTED
	-- RATHER THAN HIDDEN**: 0.48 / 0.76 / 0.54 / 0.14 for head / chest / rear / legs on the stag,
	-- against the boar sow's 0.93 worst zone measured the same way. That is not this box being
	-- wrong -- it is `SILHOUETTE` being the BOAR's zones, projected. A deer's legs are thin and far
	-- apart where a boar's are stubby, and a deer holds its head above its back where a boar holds
	-- it below. The rectangles a deer's dots really land in are
	-- `Boar.CONFIG.SPECIES.reddeer.ZONES`, which are measured and are a different shape, and
	-- `SILHOUETTE` is deliberately NOT species-aware (it is the boar's `ZONES` projected and
	-- `report_silhouette.spec` asserts that by path). Validating this box against the DEER's zones
	-- is queued with the screenshot that can show it.
	BOAR_IMAGE = {
		male = { id = "rbxassetid://135789362198066", box = { u0 = 0.100, u1 = 0.900, v0 = 0.230, v1 = 0.730 } },
		female = { id = "rbxassetid://121961957713451", box = { u0 = 0.120, u1 = 0.920, v0 = 0.150, v1 = 0.650 } },
		stag = { id = "rbxassetid://82382119550819", box = { u0 = 0.000, u1 = 1.000, v0 = 0.380, v1 = 1.000 } },
		hind = { id = "rbxassetid://134628251396589", box = { u0 = 0.000, u1 = 1.000, v0 = 0.276, v1 = 1.000 } },
	},

	-- HOW SMALL A CALF IS DRAWN (task 223). The HIND's picture at 70 %, which is what a calf is
	-- beside its mother and is honest about being the same drawing -- Karen has no third deer image
	-- and did not ask for one.
	--
	-- IT IS ITS OWN ROW AND NOT `PIGLET_SCALE` REUSED, although both are 0.70: they are two
	-- independent drawn choices about two different animals, and a change to how a piglet is drawn
	-- must not silently move the calf.
	CALF_SCALE = 0.70,

	-- HOW SMALL A PIGLET IS DRAWN. Karen has no third image and did not ask for one: a piglet is the
	-- SOW's silhouette at 70 %, which is about what a cub is beside its mother and is honest about
	-- being the same drawing. The dots' box scales with it, so a piglet's hit lands in the same
	-- place on the same animal.
	PIGLET_SCALE = 0.70,

	-- A WILD BOAR, SIDE ON, IN THE SAME UNIT SQUARE AS THE DOTS (task 135). Karen, 2026-10-05:
	-- *"something simple but cool"*, and *"see boars where was the hit"*. What this panel drew until
	-- now was `SILHOUETTE` above painted straight onto the screen -- five tinted rectangles, which
	-- task 124 round 3's own note called "a colour-coded bar, not a boar's outline".
	--
	-- THE RECTANGLES BELOW ARE STILL THE TRUTH ABOUT WHERE A SHOT LANDED; this is the PICTURE. The
	-- two are deliberately separate: `SILHOUETTE` above is `Boar.CONFIG.ZONES` projected and a spec fails
	-- the harness if it drifts, while this is drawn by eye against a photograph of the animal and
	-- nothing about the record depends on it. A dot's (u, v) is placed in the square exactly as
	-- before -- this file changed no dot by a pixel.
	--
	-- NO UPLOAD, NO IMAGE, NO MESH: thirteen `Frame`s with a `UICorner` each, so it costs what the five
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
		-- THE BRISKET: the deep front of the chest, under the jaw and in front of the forelegs.
		--
		-- IT IS ANATOMY AND IT IS ALSO WHERE THE HITS ARE (task 138). MEASURED over seven real shots
		-- in the Forest Test: EVERY `body` hit landed in the front quarter of the animal -- u 0.000,
		-- 0.005, 0.170, 0.194, 0.210, 0.236 -- with v 0.50 to 0.61, because the drive walks the
		-- animals straight AT the hunter and the first surface a pellet meets is the front of the
		-- trunk. Four of the seven struck the box's front FACE exactly (`local.Z` = -size.Z/2), which
		-- projects to u = 0 by construction and is the truth about the shot. The drawn boar had
		-- nothing there below the snout, so the commonest hit in the game was drawn under the chin.
		{ name = "Brisket", u0 = 0.02, u1 = 0.36, v0 = 0.42, v1 = 0.68, corner = 0.40 },
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
	-- HOW FAR A DOT'S RING HAS TO BE FROM THE FILL IT SITS ON, in relative luminance (task 137).
	--
	-- THE `body` RING WAS INVISIBLE AND THE REVIEWER MEASURED IT: `SILHOUETTE.body.tint` is
	-- (96, 84, 76) and `BOAR_FILL` is (112, 99, 88) -- about 16 of 255 per channel, which at one
	-- pixel is no ring at all. So of the five zones task 135 called readable "at a glance", the
	-- commonest one -- `body` is the fallback zone, the flank and the belly, whatever no zone part
	-- covers -- was the one you could not read.
	--
	-- 0.22 is a fifth of the full range, chosen so the WORST case (body, 0.06 apart) is lifted well
	-- clear while the two that already pass (chest at 0.23) are not touched at all. See
	-- `Report.ringColor`.
	RING_MIN_LUMA = 0.22,
	RING_THICKNESS = 1.5,

	-- THE PANEL (design section 8.3). 640 px tall leaves 440 px of a 1080p screen spare, which is the
	-- note's "one screen, no scrolling for 8 hunters".
	PANEL_WIDTH = 760,
	PANEL_HEIGHT = 640,
	-- OVER EVERYTHING THE HUD DRAWS, the scope's own mask included (task 141): the panel is a
	-- thing the player deliberately opened, and a mask that hid it would read as a broken game.
	-- The SCORE BOARD shares this number for the same reason -- it is drawn at screen centre, so a
	-- mask would cut it off at the glass.
	-- The stack, bottom to top: feed 1, drive bar 1, compass 6-10, scope 11-13, this and the score
	-- board.
	PANEL_Z_INDEX = 15,
	-- WHETHER THE REPORT OPENS ITSELF WHEN A DRIVE CLOSES. **FALSE since task 159**, and it is a
	-- deviation from `docs/design/drive-report.md` section 1 item 6 ("auto-open once when a drive
	-- closes") that is named rather than buried: the end of a drive is now Karen's RESULTS SCENE --
	-- the animals laid out, four lamps, everybody standing round them and the semi-transparent
	-- results table over it. A near-opaque full-screen report in front of all of that is the thing
	-- she asked to see, hidden. MEASURED, not reasoned: .screenshots/20261011T230613Z-task159-
	-- results-scene.png is the forest's own drive ending with the report covering the whole scene,
	-- and `Hud.scorePanelVisible` returning false because the report was open -- so the table did
	-- not show either.
	--
	-- NOTHING IS DELETED. `Tab` still opens the report, it is still the one place a player sees
	-- where every shot landed on every animal, and the auto-open is still implemented and still
	-- tested: `ReportPanel.onDriveChanged` takes the config, so a spec drives BOTH states while
	-- this sits at one of them.
	AUTO_OPEN_AT_DRIVE_END = false,
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

	-- THE HIT CARD (task 198). Karen, 2026-10-16, with a reference frame of somebody else's video:
	-- *"there is a black boar image as you can see and red dot / so once we hit boar we can show
	-- where it has been hitted / red dot will indicate so if shells then several of them / so
	-- somewhere in corner after hit we indicate where it landed"*.
	--
	-- IT IS THE REPORT'S OWN BOAR AND THE REPORT'S OWN PROJECTION, drawn small and now (dispatch:
	-- *"reuse them, do not make a second boar drawing or a second projection"*). `Hud.BoarArt` is the
	-- one builder of both pictures and `HitLog.Shape.dot` is the one projection; this block is only
	-- the card's own numbers -- where it sits, how long it lives, and what colour the animal is.
	CARD = {
		-- HOW MANY DOTS ONE CARD MAY CARRY. A full two-barrel buckshot pattern on one animal is 18
		-- (`Shotgun.CONFIG.PELLETS.Buck` x `BARRELS`), so 24 is above anything a legal shot makes;
		-- `Weapon.Hits.POINTS_MAX` is the same ceiling at the other end of the wire.
		DOTS_MAX = 24,
		-- THE CORNER IS THE LOWER LEFT, ABOVE THE KILL FEED, and the other three are taken at every
		-- width: the minimap plus the button rail own the top right, the ammo readout owns the very
		-- bottom right (`Hud.build`'s `Readout`, anchored (1,1) at -16,-16), and the whole top band
		-- is the objective line (y 8), the drive bar (y 44) and the compass (y 108, 360 px wide --
		-- which on a 400 px phone is the entire width). What is left is the left edge under the
		-- compass, and the bottom of it is where the player already looks for *what just happened*:
		-- the event feed. So the card stacks directly on top of the feed, and its own bottom is
		-- computed from the feed's own two constants rather than guessed, so the two cannot overlap
		-- at any viewport.
		MARGIN_LEFT = 16,
		FEED_GAP = 8,
		WIDTH = 188,
		-- ART_TOP + PLATE_HEIGHT + the trophy band (task 219 round 2: 30 + 96 + 2 + 14 + 2 = 144).
		-- It was 138 -- the plate plus a bottom margin equal to `ART_INSET_X` -- until the tag needed
		-- a band of its own that is not on top of the animal; see `TROPHY_HEIGHT`.
		HEIGHT = 144,
		-- The surface ladder of the house style (the Designer's `shop-design-spec.md` section 8.1):
		-- panel `#1C1915` corner 16, and a thing that sits on it one step lighter and one step less
		-- round. Near-opaque, because this is read for three seconds over a sunlit wood.
		PANEL_COLOR = Color3.fromHex("1C1915"),
		PANEL_TRANSPARENCY = 0.06,
		CORNER = 14,
		-- ONE BRASS HAIRLINE, which in the house style separates a header from a body. A card this
		-- small has no header, so the hairline is its EDGE -- the one rule the spec allows a card to
		-- wear, and what stops a dark box over a dark wood from having no border at all.
		EDGE_COLOR = Color3.fromHex("C8A258"),
		EDGE_TRANSPARENCY = 0.42,
		EDGE_THICKNESS = 1,
		-- THE PLATE THE BLACK ANIMAL IS PRINTED ON, and the one place this card leaves the dark
		-- ladder. Karen's reference is a SOLID BLACK boar, and a black boar on a `#1C1915` card is
		-- not a picture of anything. So the animal gets its own pale ground, the way a paper hit
		-- card has one: bone, one step less round than the card, inset inside it.
		PLATE_COLOR = Color3.fromHex("D9D2C4"),
		PLATE_CORNER = 11,
		-- Her reference exactly: the animal is one solid near-black shape and nothing else.
		BOAR_FILL = Color3.fromHex("0A0907"),
		ART_INSET_X = 12,
		ART_TOP = 30,
		PLATE_WIDTH = 164,
		PLATE_HEIGHT = 96,
		-- AIR ROUND THE ANIMAL. In the first frame the art filled the plate edge to edge, so the
		-- snout ran off the left side and the feet stood on the bottom rule: a shape with no room
		-- reads as a blob. 8 px of plate on every side is what makes it a picture of something.
		ART_PAD = 8,
		-- THE ANIMAL'S OWN PROPORTION, and the first frame is why it is not 164 x 70.
		-- `Report.CONFIG.BOAR` is drawn in a box 104 x 56 -- 1.857:1 -- and at 2.34:1 the legs came
		-- out stubby and the head ran into the shoulder. 148 x 80 is 1.85:1, the same animal.
		ART_WIDTH = 148,
		ART_HEIGHT = 80,
		-- THE RED DOT, with a thin light ring so it reads ON the black animal -- the same problem
		-- `RING_MIN_LUMA` solves on the report, answered here with one fixed pale ring because the
		-- fill is one fixed colour.
		DOT_COLOR = Color3.fromHex("D8251F"),
		RING_COLOR = Color3.fromHex("F6F1E6"),
		RING_THICKNESS = 1,
		DOT_PIXELS = 7,
		-- THE TROPHY TAG (task 219): a second micro-label, drawn only when `Report.trophyWord`
		-- answers -- which is only for a legendary.
		--
		-- IT IS UNDER THE PLATE, ON THE CARD, AND ROUND 1 PUT IT ON TOP OF THE ANIMAL (round 1,
		-- finding 4). The derivation written here then was arithmetically FALSE and nobody had looked
		-- at a frame of it: the art box is `ART_PAD` 8 + `ART_HEIGHT` 80, so it spans plate y 8..88,
		-- and a 14 px tag at `PLATE_HEIGHT - 6 - 14` sits at y 76..90 -- twelve pixels INSIDE the
		-- picture, in `BOAR_FILL`, which is the ink the animal itself is printed in, above both the
		-- animal and the dots. There are only 8 px of bone below the art; a 14 px tag can never be
		-- clear of it.
		--
		-- SO THE CARD GREW BY SIX PIXELS AND THE TAG WENT BELOW THE PLATE. `HEIGHT` 138 -> 144: the
		-- plate ends at `ART_TOP` 30 + `PLATE_HEIGHT` 96 = 126, the tag takes y 128..142 and the
		-- card's own bottom margin is the 2 px left. That band is DARK CARD, not bone, so the tag is
		-- `LABEL_COLOR` like the headline above it -- and it can never cover the animal or a pellet
		-- dot, which is the one thing this card exists to show. The card's bottom is pinned to the
		-- feed, so the six pixels come off its top.
		--
		-- IT IS DRAWN ONLY FOR A LEGENDARY, so an ordinary card has six pixels of empty card under
		-- its plate. That is the price, and it is said out loud rather than discovered in a frame.
		-- MEASURED: `LEGENDARY BOAR` spaced is 104.0 px, inside the tag's own box of
		-- `WIDTH - 2 * LABEL_X` = 164.
		TROPHY_SIZE = 10,
		TROPHY_HEIGHT = 14,
		TROPHY_GAP = 2, -- between the plate's bottom edge and the tag
		-- The label: BuilderSans Bold, letter-spaced, 10 px -- the house style's micro-label.
		LABEL_SIZE = 10,
		LABEL_COLOR = Color3.fromHex("E8E2D6"),
		LABEL_X = 12,
		LABEL_Y = 10,
		-- HOW LONG IT LIVES. 3 s is the dispatch's; the fade is the only motion the house style
		-- allows anything but the display case, and it is on transparency alone.
		HOLD_SECONDS = 3,
		FADE_SECONDS = 0.5,
		-- OVER THE SCOPE'S MASK (11-13) AND UNDER THE REPORT PANEL (15). A hunter who has just
		-- fired through the scope is exactly the player this card is for, so a mask that cut it off
		-- would hide it from its own audience; the report is a thing the player opened on purpose
		-- and stays on top.
		Z_INDEX = 14,
	},
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
-- THE COLOUR A DOT'S RING IS ACTUALLY DRAWN IN: the zone's own tint, lifted until it can be read
-- against the animal it is drawn on (task 137).
--
-- THE TINT IS THE RECORD AND THIS IS THE DRAWING, which is the same split `SILHOUETTE` and `BOAR`
-- already have. `SILHOUETTE[zone].tint` is mirrored from `Boar.CONFIG.ZONES` and a spec fails the
-- harness if the two drift; nothing about that may be bent to make a picture legible. So this leaves
-- the record alone and moves the PIXEL instead.
--
-- RELATIVE LUMINANCE, not an RGB distance: a ring is one pixel wide, and what makes one pixel
-- readable against a flat field is how much lighter or darker it is, not how far round the colour
-- wheel it sits. The coefficients are the Rec. 709 ones every contrast formula uses
-- (https://www.w3.org/TR/WCAG20/#relativeluminancedef, without the gamma step -- these are already
-- the values the engine draws).
--
-- IT PUSHES AWAY FROM THE FILL, toward whichever of white or black has the room: the fill is dark
-- (luma 0.40), so every lifted ring goes pale, which is also the direction that reads over the
-- dark panel behind the animal. A tint that is already far enough away is returned untouched, so
-- chest and rear keep exactly the colours task 135 shipped.
function Report.luma(colour: Color3): number
	return 0.2126 * colour.R + 0.7152 * colour.G + 0.0722 * colour.B
end

function Report.ringColor(tint: Color3, fill: Color3, want: number?): Color3
	local need = want or Report.CONFIG.RING_MIN_LUMA
	local base = Report.luma(fill)
	if math.abs(Report.luma(tint) - base) >= need then
		return tint
	end
	-- Toward the end of the range with more room, so the lift cannot run out of headroom.
	local toward = if base < 0.5 then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
	for step = 1, 20 do
		local mixed = tint:Lerp(toward, step / 20)
		if math.abs(Report.luma(mixed) - base) >= need then
			return mixed
		end
	end
	return toward
end

-- A DOT THAT FALLS OFF THE DRAWN ANIMAL IS MOVED TO THE NEAREST POINT ON IT (task 138).
--
-- IT IS A DRAWING DECISION AND THE RECORD IS UNTOUCHED, which is the same line `drawDots`' half-dot
-- inset already draws: the attributes on the pip still carry the true `(u, v)` the server measured,
-- and `SILHOUETTE` -- the rectangles every dot is placed against -- is not consulted here at all.
--
-- WHY IT IS NEEDED AT ALL, and the honest version of task 137a's claim: a hit is recorded where the
-- pellet MET THE BOX, and the box is a rectangle while the animal is not. A shot into the front face
-- projects to u = 0 exactly -- correct arithmetic, and the commonest shot there is, because the
-- drive walks the animals at the hunter. The corners of that box are air above the snout and behind
-- the rump, and an animal cannot be drawn into them. So the rare dot that still lands in one is put
-- on the nearest bit of animal rather than left floating in front of its nose.
--
-- `u` AND `v` ARE NOT THE SAME LENGTH: the art is 104 x 56, so "nearest" is measured in PIXELS and
-- not in the unit square, or a dot would always be pulled sideways.
function Report.ontoBoar(u: number, v: number): (number, number)
	for _, piece in ipairs(Report.CONFIG.BOAR) do
		if u >= piece.u0 and u <= piece.u1 and v >= piece.v0 and v <= piece.v1 then
			return u, v
		end
	end
	local wide = Report.CONFIG.SILHOUETTE_WIDTH
	local tall = Report.CONFIG.SILHOUETTE_HEIGHT
	local bestU, bestV, bestD = u, v, math.huge
	for _, piece in ipairs(Report.CONFIG.BOAR) do
		local onU = math.clamp(u, piece.u0, piece.u1)
		local onV = math.clamp(v, piece.v0, piece.v1)
		local dx, dy = (onU - u) * wide, (onV - v) * tall
		local far = dx * dx + dy * dy
		if far < bestD then
			bestD, bestU, bestV = far, onU, onV
		end
	end
	return bestU, bestV
end

function Report.metres(studs: number?): number
	return math.round((studs or 0) * Report.CONFIG.METRES_PER_STUD)
end

-- WHAT THE PLAYER IS TOLD THE ANIMAL IS. PURE, and the ONE place a data kind becomes a noun --
-- the start card, the hit card and the drive report all read it, so a player cannot be shown two
-- words for one animal.
--
-- `cub` -> `piglet`, AND THAT IS WHY THIS EXISTS. The Designer's start-card spec, 2026-10-18,
-- section 0 fault 2: *"Two words for one animal. The server's kind is `cub`; `QUARRY_NOTE` calls
-- the same animal a `piglet`. A new player reads them as two animals and shoots the one he thinks
-- is safe."* Rule 4 of the same spec: *"`cub` is never printed. The player-facing word is
-- `piglet`, in one place, shared with the hit card and the report."* This is that place. The data
-- string stays `cub` everywhere it is a key (`Match.CONFIG.POINTS.KIND`, the kill record,
-- `Report.boarImage`) -- renaming the key would be renaming the rule.
--
-- AN UNKNOWN KIND IS RETURNED AS IT CAME. A kind nobody has a word for is still a fact about the
-- animal that died, and printing `boar` over it would be this function inventing one.
function Report.kindWord(kind: string?): string
	local word = string.lower(tostring(kind or ""))
	if word == "cub" then
		return "piglet"
	end
	return word
end

-- WHICH IMAGE AN ANIMAL GETS, AND HOW BIG. PURE, and the one place the record's `kind` becomes a
-- picture -- so the hit card and the drive report cannot show a player two different animals for
-- one shot. `male` and anything unknown take the boar; `female` takes the sow; `cub` takes the sow
-- at `PIGLET_SCALE`, which is said out loud rather than hidden in a renderer.
--
-- `cub` IS A DATA STRING AND `piglet` IS THE WORD (the Designer's start-card spec, 2026-10-18,
-- section 1.3: *"the player-facing word is piglet everywhere"*). This function takes the data
-- string; nothing here prints either.
--
-- `legendary` NEEDS NO ROW HERE AND THAT IS DELIBERATE (task 219): the rule above -- *"an unknown
-- kind is returned as it came"* -- already answers `legendary`, which is the right word, so the
-- drive report's ANIMAL column prints `LEGENDARY` with nothing added to this function. The hit card
-- says `LEGENDARY BOAR` instead, out of `Report.trophyWord`. TWO screens, one word each, neither of
-- them guessing. **The start card names it on NEITHER**, and that is not an oversight: its row cap
-- is four and the four are spoken for, so `Drive.CONFIG.START_CARD_QUARRY_WORDS` has no `legendary`
-- row and `boar_legendary.spec` asserts the absence. (An earlier draft of this paragraph claimed
-- the start card said "Legendary boar"; it never did -- round 1, note 2.)
-- THE WORD A TROPHY PUTS ON THE HIT CARD, or `nil` for every animal that is not one (task 219).
-- PURE, and the one place that decision is made, so the card cannot say "legendary" for a sow.
--
-- IT IS A SECOND LABEL ON THE PLATE AND NOT PART OF THE HEADLINE, and that is a MEASUREMENT.
-- `Report.cardLabel` writes `HIT - BUCKSHOT 4/9`, which `Style.spaced` doubles the length of;
-- measured with `TextService:GetTextBoundsAsync` in the card's own face (BuilderSans Bold 10) against
-- the label's own 164 px box:
--
--     HIT - BUCKSHOT 4/9        117.0 px      LEGENDARY - BUCKSHOT 4/9    167.0 px   <- does not fit
--     LEGENDARY BOAR            104.0 px      LEGENDARY BOAR - SLUG       147.0 px
--
-- So the headline keeps its job and the animal is named on the bone plate it is printed on, where
-- 104 px sits inside 164 with room. Every other shot's card is drawn exactly as it was.
--
-- `stag` SINCE TASK 223, AND ONLY THE STAG. A red stag IS the trophy of his species and the card has
-- room for the word -- `RED STAG` is 8 characters against the measured `LEGENDARY BOAR`'s 104 px in
-- a 164 px box. A hind and a calf get nothing, which is this function's own rule: *"nil for every
-- animal that is not one"*, and a calf is a penalty.
function Report.trophyWord(kind: string?): string?
	local word = string.lower(tostring(kind or ""))
	if word == "legendary" then
		return "LEGENDARY BOAR"
	elseif word == "stag" then
		return "RED STAG"
	end
	return nil
end

--
-- ...AND THE THREE DEER SINCE TASK 223, through the same three shapes: `stag` takes the stag's own
-- picture, `hind` takes the hind's, and `calf` takes the HIND's at `CALF_SCALE` -- the piglet's
-- pattern, said out loud rather than hidden in a renderer.
function Report.boarImage(kind: string?): { id: string, box: any, scale: number }
	local word = string.lower(tostring(kind or ""))
	local art = Report.CONFIG.BOAR_IMAGE
	if word == "female" then
		return { id = art.female.id, box = art.female.box, scale = 1 }
	elseif word == "cub" or word == "piglet" then
		return { id = art.female.id, box = art.female.box, scale = Report.CONFIG.PIGLET_SCALE }
	elseif word == "stag" then
		return { id = art.stag.id, box = art.stag.box, scale = 1 }
	elseif word == "hind" then
		return { id = art.hind.id, box = art.hind.box, scale = 1 }
	elseif word == "calf" then
		return { id = art.hind.id, box = art.hind.box, scale = Report.CONFIG.CALF_SCALE }
	end
	return { id = art.male.id, box = art.male.box, scale = 1 }
end

-- WHICH WAY THE HIT CARD DRAWS THE ANIMAL (task 198).
--
-- The drive report always draws the boar nose-LEFT and half-fades a dot that landed on the far
-- flank (`FAR_SIDE_TRANSPARENCY`), because a report is a page you compare rows on and the rows have
-- to be the same way round. A hit card is one animal and one shot, and Karen's whole ask is *"we can
-- show where it has been hitted"* -- so it turns the animal around instead of fading the mark: if
-- the shot came in on the far flank, the picture is MIRRORED and you are looking at the flank that
-- was hit, with every dot drawn solid.
--
-- THE DECISION IS THE MAJORITY OF THIS SHOT'S OWN DOTS. `side` is -1 or 1 out of `HitLog.Shape.dot`
-- and a buckshot pattern can straddle the spine, so one pellet cannot decide the picture; a tie
-- keeps the report's own facing, so the default is always the one the player already knows.
-- Pure, so `tests/server/hit_card.spec.luau` drives it with hand-written dots.
function Report.cardFacing(dots: { any }?): boolean
	local near, far = 0, 0
	for _, dot in ipairs(dots or {}) do
		if (dot.side or 1) < 0 then
			far += 1
		else
			near += 1
		end
	end
	return far > near
end

-- THE CARD'S ONE LINE OF TEXT. `word` is the ammunition's own, which the client resolves through
-- `Weapons.row(id).AMMO_LABEL` -- the same split the wire already has for the gun (`WireDot.weapon`):
-- the wire carries the id and the screen carries the word.
--
-- A SINGLE PROJECTILE GETS NO FRACTION. "HIT - SLUG" says everything there is to say about one
-- bullet; "HIT - BUCK 4/9" is the whole point of a buckshot card, because the number of dots on the
-- animal IS the four.
--
-- THE SEPARATOR IS A PLAIN HYPHEN AND IT WAS A MIDDLE DOT FOR ONE FRAME. U+00B7 came out of
-- BuilderSans as two missing-glyph boxes -- `.screenshots`/`<runs-dir>/t198-buck-card.png` of
-- 2026-10-17 reads "HIT (box)(box) BUCK 4/9" -- which is exactly what the Designer's spec means by
-- *"No glyph is used unless it has been checked in the family that renders it"*.
function Report.cardLabel(word: string?, hits: number?, fired: number?): string
	local name = string.upper(tostring(word or "HIT"))
	local landed = math.max(0, math.floor(hits or 0))
	if fired ~= nil and fired > 1 then
		return string.format("HIT - %s %d/%d", name, landed, math.floor(fired))
	end
	return string.format("HIT - %s", name)
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
