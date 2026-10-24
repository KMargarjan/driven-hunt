--!strict
-- ForestTest: THE DATA FOR THE PLAYTEST WORLD "Driven Hunt Forest Test", and nothing else.
--
-- It writes no Instance, spawns no boar and arms no gun. Server and client both read it, which is
-- why it is in ReplicatedStorage: the client's stand picker has to know where the road is, and a
-- second copy of a curve is two curves that disagree.
--
-- KAREN, 2026-10-04 ~22:40, on what she wants to test in the morning:
--   *"one side hunters respawn and on another side driver people walk is let's say 1 minute max"*
--   *"hunter line just a hunter no treestand anything"*
--   *"hunter has square where can select stand within 10s and save then he can move few steps"*
--   *"each 20s cross 1 flock then 1 big male then on other side few so to be action"*
--   *"several animals cross road / several go back"*
--   *"I want tomorrow to test shooting and walking"*
--
-- THIS IS A PLAYTEST WORLD, NOT THE GAME'S MAP. The real map is `Map` + `MapGen` and still builds
-- in the DEV place. This describes a hand-built place the Director made from a bought terrain, and
-- its whole job is to let one person stand on a road and shoot things that cross it.
local Workspace = game:GetService("Workspace")

local ForestTest = {}

-- THE PLACE. Everything below is only ever read when `Map.EXPECTED_WORLD` resolves to
-- `ForestTest.WORLD`, which happens only in this place id -- see `Map.WORLD_BY_PLACE`.
ForestTest.PLACE_ID = 130094961655666
ForestTest.WORLD = "forest-test"

-- ---------------------------------------------------------------- THE DRIVE LAYOUTS (task 179)
--
-- KAREN, 2026-10-13 ~13:55, verbatim: *"we will improve terrain that not all a time same place
-- hunters standing and not the same terrain for beaters / we will make view for hunter from
-- different places and diffretent tree lines road ect like in real life"*.
--
-- SO A DRIVE IS A LAYOUT, AND A LAYOUT IS DATA. Until today this world had exactly one place to
-- stand -- the curved road at z -2097 with nine stands -- and every drive Karen played was the same
-- ground seen from the same nine spots. The table below is the whole of the difference between one
-- drive and the next: where the line is, what shape it is, how many stands it has and how far
-- apart. Everything else in this file is SHARED, because no shipped layout varies it (design 3.3).
--
-- Pattern: THE WORLD PLACES THE ENTITIES THE GAME MODE QUERIES -- Valve's `info_player_terrorist`,
-- Unreal's `AGameModeBase::ChoosePlayerStart` -- with one level added: the world holds SEVERAL sets
-- of them and names which set is live. The same two sources `ForestTest.Markers`' header cites.
--   https://developer.valvesoftware.com/wiki/De/Info_player_counterterrorist
--   https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Runtime/Engine/GameFramework/AGameModeBase
-- Design: docs/design/drive-layouts.md (sections 3 and 4)
-- Note:   docs/research/2026-10-14-drive-layouts.md
--
-- EVERY NUMBER HERE WAS MEASURED IN THIS PLACE before it was written (note section 5, read in Edit
-- on 2026-10-14, read-only). A stand is only taken where the two ground readings agree to within
-- `Markers.GROUND_TOLERANCE_STUDS` AND nothing colliding stands within 8 studs of it -- today's
-- road is 9 of 9 on both counts, which is the bar, and candidate lines at 6 of 9 were REJECTED
-- rather than nudged.
export type Layout = {
	name: string,
	-- What a HUD may print. Nothing draws it yet; it is here so the name a player sees is the
	-- world's to state rather than a client's to invent.
	label: string,
	-- The middle of the stand line. Y IS A FALLBACK GROUND ONLY: every production reader of a
	-- layout point re-measures the ground (`Markers.groundFor`, `terrainYAt`, `groundAt`), so this
	-- value is reached only in a column with no terrain in it at all. It is the mean of the
	-- layout's own measured stand terrain.
	centre: Vector3,
	-- The sine's amplitude, and **0 IS A STRAIGHT LINE**: one shape, not two, so a straight layout
	-- needs no second code path anywhere.
	amplitudeStuds: number,
	standCount: number,
	standSpacing: number,
	-- How far the line's ground runs either side of `centre.X`: half the stand span plus a run-out,
	-- so a boar fleeing past the end stand has ground to do it on.
	halfSpanStuds: number,
}

-- THE SHAPE EVERY LAYOUT SHARES. The wavelength and the lane width are the same in all three, so
-- they live here and not in the record: three copies of 70 are a constant written three times
-- (design 3.3, a named deviation from the brief, which listed them per layout).
ForestTest.SHAPE = table.freeze({
	wavelengthDivisor = 70, -- z = centre.Z + amplitude * sin((x - centre.X) / this)
	halfWidthStuds = 20, -- the cut lane is about 40 studs across
})

-- HOW FAR SOUTH OF THE LINE A BOAR IS GONE. The curve's lowest z is `centre.Z - amplitude`, so this
-- much past that is clear of the whole length. `Brain:_outcome` despawns at `position.Z <= exitZ`.
ForestTest.EXIT_SOUTH_STUDS = 250

-- THE ONE GROUND HEIGHT THE BOAR FIELD CARRIES, and it stays 138 for every layout on purpose.
-- `Brain:_outcome` despawns at `position.Y < field.groundY - FALL_LIMIT` (50), so a per-layout 185
-- would put the floor at 135 on an edge drive -- and the terrain inside this wood was measured as
-- low as 99. A number that cannot be bounded must not be allowed to despawn animals; 138 - 50 = 88
-- is below every value measured anywhere in this place (design 3.4).
ForestTest.GROUND_Y = 138

ForestTest.LAYOUTS = table.freeze({
	-- TODAY'S DRIVE, FROZEN NUMBER FOR NUMBER (the Director's decision 2 in
	-- `reviews/task-179/BRIEF.md`; `forest_stand.spec` asserts every one of them).
	--
	-- THE ROAD IS A SINE, NOT A LINE. Karen: *"hunter position one long road not straight as we have
	-- now"*. Amplitude 30 studs over a 440-stud wavelength is a road that bends enough that a
	-- shooter cannot see his neighbour down the whole length -- which is the point of it -- without
	-- ever doubling back on itself.
	--
	-- 9 SPOTS OVER 1,200 STUDS is 150 studs apart, which is a real driven-hunt spacing: far enough
	-- that two hunters never share a target, close enough that a boar crossing anywhere is
	-- somebody's shot. 150 studs is 42 m at `ForestTest.SPOOK.METRES_PER_STUD`.
	road = table.freeze({
		name = "road",
		label = "Road",
		centre = Vector3.new(3030, 138, -2097),
		amplitudeStuds = 30,
		standCount = 9,
		standSpacing = 150,
		halfSpanStuds = 800,
	}),

	-- KAREN'S PLACE 2, *"forest ending then field and then again forest"* (task 193): the hunters
	-- stand on their OWN edge at the south side of an open field, and the far forest across it is
	-- this world's real wood, which the drive comes out of. The hunter's own frame is karen-ref-6 --
	-- a stand inside a hedge, a wide field, a dark tree line across it, a boar crossing.
	--
	-- IT MOVED SOUTH, FROM z -3000 TO z -3400, AND THE FIELD IS WHY. At -3000 the hunters stood 100
	-- studs from the tree line: that is 28 m, a lane and not a field, and task 179's own note called
	-- it *"100 studs out in the open"*. Karen asked for 80-150 m. The wood's southern face is at
	-- z -2900 straight across this whole stand span (measured 2026-10-17 at every column x
	-- 3100..3800: -2900 +/- 25), so -3400 would put 500 studs = 140 m of open ground in front of the
	-- line. **THAT LINE WAS NOT SHIPPED** -- see the next paragraph, which is why -- and the field
	-- this place actually has is the 350 studs = 98 m from z -3250.
	--
	-- AND THE BEATERS STILL START IN THE TREES. `beaterNorthStuds()` is 580, so they form up at
	-- z -2670, which is **230 studs INSIDE** the wood's face at -2900 -- they push out of cover into
	-- the open, which is what makes this a Feldrand stand rather than two lines in a paddock.
	--
	-- IT IS THE MOST CLASSICAL OF THE THREE, and that is a borrowed judgement rather than a taste:
	-- WILD UND HUND's "Drueckjagdstaende -- Sicher ist sicher?" says a stand does NOT belong on a
	-- path or a narrow clearing between two thickets (panicked game runs down those light bridges)
	-- but where the passages converge and the bullet catch is safe -- and it names hillsides and
	-- natural terrain edges as the two places that are. This is both.
	--   https://wildundhund.de/drueckjagdstaende-sicher-ist-sicher/
	--
	-- z -3250 AND NOT -3400, AND A SCREENSHOT IS WHY. The first build put this line at z -3400 and
	-- the hunter's-eye frame came back with the ground RISING in front of him: a ray north from eye
	-- height (+5) died on terrain at **60 studs**, so he could see neither the field nor the wood he
	-- was supposed to be watching -- only tree crowns over a ridge
	-- (`.screenshots`/`<runs-dir>/193-p2-north.png`, first build). The dispatch's gate rule for this
	-- task is *"every stand: the hunter stands ON the ground, can see the drive area"*, and that
	-- frame fails it.
	--
	-- SO THE LINE WAS MEASURED INSTEAD OF MOVED BY EYE. 120 candidate lines (z -3150..-3300, 5 and 6
	-- stands, 130 and 150 apart, x centres 3200..3700) were scored by walking the terrain from each
	-- stand's eye height to a point 4 studs above the ground at the wood's face (z -2900) and taking
	-- the worst intrusion above that sight ray. 18 came out with EVERY stand clear; this one is the
	-- northernmost of those that still keeps Karen's field width and the lodge clearance:
	-- **5 stands, 130 apart, centre x 3400, z -3250 -- worst intrusion 0.0 studs at all five**, and
	-- a horizontal ray north from each reaches past 400 studs. Measured 2026-10-17 in the place.
	--
	-- THE FIELD IS 98 m (350 studs from the line to the wood's face at z -2900), inside Karen's
	-- *"80-150 m"*. At -3400 it was 140 m and unusable; 98 m that he can see across is the trade, and
	-- it is her own range either way.
	--
	-- FIVE STANDS CENTRED x 3400, AND THE LODGE IS STILL WHY the line sits east.
	-- `Lobby.anchorFor("forest-test")` is (2850, -2950) and the lobby's own field is x 2740..2960;
	-- `halfSpanStuds` 320 is 260 (half the stand span) + the 60-stud run-out task 179 sized for
	-- exactly this, which puts `boundsOf`'s west edge at x 3080 -- **120 studs clear** of that field.
	--
	-- `centre.Y` 190 IS THE MEAN OF THE FIVE STANDS' OWN TERRAIN AT THIS z, measured, not carried
	-- over: 188, 168, 180, 207, 208. It is a FALLBACK only -- every production reader re-measures.
	edge = table.freeze({
		name = "edge",
		label = "Field edge",
		centre = Vector3.new(3400, 190, -3250),
		amplitudeStuds = 0,
		standCount = 5,
		standSpacing = 130,
		halfSpanStuds = 320,
	}),

	-- KAREN'S PLACE 3, *"just cut tree line and forest on both sides"* (task 193): a straight ride cut
	-- through dense wood, hunters spaced along it, the animal crossing from cover into cover.
	-- karen-ref-5 is the frame -- a grassy ride with two ruts, a band of young pines right at its
	-- edge, taller forest behind them, and the next hunter a long way down it.
	--
	-- IT LEFT THE EXISTING WOOD, AND THAT IS A MEASUREMENT AND NOT A PREFERENCE. Task 179 placed
	-- this line at (3350, -2600) because the wood happened to leave its five STAND POINTS clear
	-- within 8 studs. A ride is not five points, it is a STRIP, and on 2026-10-17 the strip was
	-- measured along that same line (x 3060..3640 every 20 studs, `RespectCanCollide`): a trunk
	-- within 10 studs at **12 of 30** samples, within 20 studs at 23 of 30, within 32 studs at
	-- **30 of 30**. A sweep for ANY line clear at +-10 studs over 900 studs (z -2400..-2800 by 25,
	-- three x centres) found **NONE**. There is no cut line in this wood and one cannot be made
	-- without deleting bought Studio trees -- rule 7, and Karen's call. Deutsche Jagdzeitung's
	-- "Saubere Ansitz-Drueckjagden!" describes a drive's preparation as exactly that cutting:
	--   https://djz.de/saubere-ansitz-drueckjagden-858/
	-- ...so the ride is CUT HERE INSTEAD, on clean ground, by planting the wood either side of it
	-- (`src/shared/Places`). A strip nothing is planted into is a strip no later tweak can grow a
	-- tree back into.
	--
	-- WHY NOT x 1500, z -4100, WHICH IS WHERE THE FIRST BUILD PUT IT. That plot is the flattest clean
	-- ground in this world (zero non-terrain parts, 29 studs of relief along its line) and it still
	-- fails the one test that matters: from stand 1's eye height a ray north dies on terrain at
	-- **89 studs**, and at stand 3 at 241 -- two of the five cannot see the drive. **The whole
	-- WEST ground was then swept** (x 1200..2000, z -3700..-4500, 5- and 6-stand lines) for a line
	-- where every stand sees at least 180 studs: **none exists**. Flat is not the same as open, and
	-- the gate rule asks for open.
	--
	-- SO IT MOVED EAST, TO THE OTHER ZERO-PART GROUND. Of 30 all-clear candidates there, this is the
	-- one with the longest sight line and no part in its plot: **5 stands, 130 apart, centre x 4900,
	-- z -4500 -- every stand sees past 400 studs north**, `worstSight` 400. Measured 2026-10-17.
	-- Stand terrain 160..178; `centre.Y` 166 is their mean.
	--
	-- AND BEING EAST BUYS THE HORIZON. `track`'s line is 640 studs north of this one, so this place's
	-- north belt and that place's south belt are one wood -- with a 42-stud cleared corridor through it
	-- where the forest road crosses (`Places.clearOfEveryLane`). A hunter here looks up the ride into
	-- trees rather than at open hillside, which is what karen-ref-5 shows and what the first build's
	-- frame did not (`<runs-dir>/193-p3-north.png`, first build: open grass hill over the belt's far
	-- edge).
	--
	-- z -4540 AND NOT -4500, WHICH IS WHERE ROUND 3 LEFT IT (TASKS.md 193a(a)). At -4500 the beaters
	-- mustered at `beaterNorthStuds()` 580 north = z -3920, which is INSIDE the forest road's lane
	-- (-3921..-3879): they formed up ON that place's track instead of in cover, which is the one thing
	-- design 10.2 raised the belt to 640 to prevent. 40 studs south puts the muster at **-3960, 39
	-- studs clear of that lane**, and it is the ONLY candidate that keeps the sight line: measured
	-- 2026-10-17, -4540 holds 400 studs at every stand, while -4560, -4580 and -4600 collapse to 52,
	-- 62 and 18.
	--
	-- Five stands 130 apart is 520 studs of front instead of the road's 1,200: a different kind of
	-- drive on purpose, and the one Karen described, where the next gun is "far down the ride".
	-- `halfSpanStuds` 320 is 260 + the same 60-stud run-out as the edge.
	ride = table.freeze({
		name = "ride",
		label = "Cut line",
		centre = Vector3.new(4900, 166, -4540),
		amplitudeStuds = 0,
		standCount = 5,
		standSpacing = 130,
		halfSpanStuds = 320,
	}),

	-- KAREN'S PLACE 4, *"again forest road and forests on side"* (task 193): a SECOND forest road,
	-- and deliberately the opposite of the first. The road is a wide gravel sweep through open high
	-- forest you can see 40-60 m into; this is karen-ref-1 -- a narrow dirt double track under brown
	-- leaves with the forest CLOSE on both sides, young firs right at the wheel ruts.
	--
	-- STRAIGHT, WHERE THE ROAD CURVES (`amplitudeStuds` 0 against the road's 30). That is the whole
	-- difference a hunter reads between the two: on the road the bend takes his neighbour out of
	-- sight; here he sees the length of the track and the next gun standing on it, which is what
	-- ref-1 shows.
	--
	-- NARROW IS A BORROWED NUMBER. A `Rueckegasse` -- the skid trail this is -- is **3-4 m wide**,
	-- "at least four metres" recommended, 20-60 m apart (LWF-Merkblatt Nr. 38 / Wald-Prinz):
	--   https://www.waldwissen.net/de/technik-und-planung/forsttechnik-und-holzernte/walderschliessung/merkblatt-feinerschliessung
	-- The planted strip is 18 studs = 5 m, the generous end of that, because a boar has to be
	-- shootable crossing it.
	--
	-- WHY NOT x 4800, z -4100 EITHER. Same defect as the ride's, measured the same way: at that line
	-- the two east stands (x 4995 and 5125) see **65 and 62 studs** north before the terrain cuts them
	-- off -- 18 m, which is not a drive you can watch. **x 4700, z -3900, six stands 130 apart** is
	-- the all-clear candidate with the longest sight line of the thirty: **every stand sees past 400
	-- studs**, `worstSight` 400, zero non-terrain parts in its plot. Measured 2026-10-17. Stand
	-- terrain mean 159, which is `centre.Y`.
	--
	-- Six stands 130 apart = 650 studs of front; `halfSpanStuds` 385 is 325 + the 60-stud run-out.
	track = table.freeze({
		name = "track",
		label = "Forest road",
		centre = Vector3.new(4700, 159, -3900),
		amplitudeStuds = 0,
		standCount = 6,
		standSpacing = 130,
		halfSpanStuds = 385,
	}),
})

-- THE ROTATION, IN ONE PLACE AND IN KAREN'S OWN ORDER (task 193): her 1 road, 2 field edge, 3 cut
-- line, 4 forest road. Since task 193 this is not a bag's contents but the CYCLE ITSELF -- drive 1
-- plays the first, drive 5 plays the first again (`nextLayout`).
--
-- It is still the one-line commit that puts this world back to exactly today's game: `{ "road" }`.
-- `forest_stand.spec` proves `road` is unchanged number for number, so that commit is a real
-- rollback and not a hope (design 15).
ForestTest.LAYOUT_ORDER = table.freeze({ "road", "edge", "ride", "track" })

-- THE DEFAULT PARAMETER, NAMED FOR WHAT IT IS. A default meaning "the live layout" cannot exist in
-- a replicated module: on a client this module has no live anything, so it would answer `road` for
-- ever and draw the wrong road -- which is the one defect this whole design exists to prevent. A
-- default called `ROAD_LAYOUT` means the road layout, so a reader who omits the argument has said
-- what they got (design 4).
ForestTest.ROAD_LAYOUT = ForestTest.LAYOUTS.road
ForestTest.DEFAULT_LAYOUT = "road"

-- WHERE THE LIVE NAME IS PUBLISHED. A Rojo-owned `Configuration` that is a CHILD OF THIS MODULE
-- (`src/shared/ForestTest/Live.model.json`), which is exactly the shape `Flags` uses for its own
-- mirror and for the reason that file writes down: it is found through `script` and never by
-- searching `ReplicatedStorage`, so one file means one instance and Rojo owns both. An attribute on
-- `ReplicatedStorage` itself would be a global name with no owner.
--
-- The attribute is written only in a Play session by the server's forest owner, so it can never
-- dirty a harness run -- the same property `Flags.publish` has.
ForestTest.LIVE_NAME = "Live"
ForestTest.LAYOUT_ATTRIBUTE = "Layout"

-- THE DIRECTOR'S OVERRIDE: an attribute on `ServerStorage`, set in Edit, that forces one layout for
-- a test. Exactly `START_ROLE_ATTRIBUTE`'s idiom -- it survives into Play because Play copies the
-- Edit DataModel, it never shows up in the git tree, and it is NOT a `DHFlag_*` name, so the
-- harness's override guard neither sees it nor can be defeated by it. The other half of that is a
-- cost and it is logged: `test` does NOT refuse to start while this is set, so the chooser prints
-- which source it used (design 11, D3).
ForestTest.LAYOUT_OVERRIDE_ATTRIBUTE = "DHForestLayout"

-- THE LAYOUT BY NAME, OR NIL. PURE. Nil for a name the table does not know, which is what makes
-- "a typo gets no map rather than the wrong map" possible all the way out to the client.
function ForestTest.layoutNamed(name: string?): Layout?
	if type(name) ~= "string" then
		return nil
	end
	return (ForestTest.LAYOUTS :: any)[name]
end

-- A FRESH COPY of the order, so a caller that shuffles its own bag cannot shuffle the table.
function ForestTest.layoutNames(): { string }
	return table.clone(ForestTest.LAYOUT_ORDER)
end

-- WHICH LAYOUT COMES NEXT: THE ROTATION, IN ORDER, FOR EVER. PURE -- a spec drives it with no world
-- and no randomness at all.
--
-- KAREN DECIDED THIS, 2026-10-15: *"each time person will be in new place when is hunter then loop
-- it again"*. Task 179 dealt from a shuffled bag (the Tetris 7-bag,
-- https://tetris.wiki/Random_Generator, and the DevForum's map-rotation answer,
-- https://devforum.roblox.com/t/an-efficient-way-to-randomize-a-list-of-maps-or-items/223583); task
-- 193 replaces it with a fixed cycle, and the bag's own stated reason is the thing the cycle does
-- BETTER rather than worse: *"a layout she is never dealt is a layout she cannot judge"*. A bag only
-- guarantees that within a shuffle; a rotation deals every place exactly once per cycle in an order
-- she can predict, which is what "then loop it again" asks for.
--
-- WHAT A ROTATION LOSES, said plainly: it is predictable, so a player who has seen four drives knows
-- the fifth. That is a cost for a shipped game and an advantage for a playtest, and this world is a
-- playtest world. If it ever becomes the real rotation for players, the fix is a bag per CYCLE
-- (shuffle the four, deal all four, reshuffle) -- which is the 7-bag again, and keeps "every place
-- once per cycle".
--
-- NO ROLL, NO BAG, NO STATE. The only argument is what was played last, so the caller keeps one
-- string instead of a list, and there is no way for the two to disagree.
function ForestTest.nextLayout(previous: string?): string
	local order = ForestTest.LAYOUT_ORDER
	-- A NAME NOBODY KNOWS -- nil at the start of a session, or a layout deleted from the table
	-- between one drive and the next -- starts the cycle again rather than answering nil. A drive
	-- with no layout is the one outcome the whole design forbids.
	for index, name in ipairs(order) do
		if name == previous then
			return order[(index % #order) + 1]
		end
	end
	return order[1]
end

-- WHERE THE LINE IS AT A GIVEN x. The one definition; every other reader calls this.
--
-- THE LAYOUT IS A TRAILING OPTIONAL PARAMETER, which is the idiom this file already uses for
-- `spook`, `beater` and `rest`: the arithmetic is pure in a table handed in, and a spec can ask any
-- layout anything with no world running.
function ForestTest.roadZ(x: number, layout: Layout?): number
	local resolved = layout or ForestTest.ROAD_LAYOUT
	if resolved.amplitudeStuds == 0 then
		-- A STRAIGHT LINE IS THE SINE AT AMPLITUDE 0, so this branch changes no answer. It is here
		-- because `roadZ` is called from every ground read and a straight layout's z is then exact
		-- arithmetic rather than a sine evaluated to be multiplied by zero.
		return resolved.centre.Z
	end
	return resolved.centre.Z
		+ resolved.amplitudeStuds * math.sin((x - resolved.centre.X) / ForestTest.SHAPE.wavelengthDivisor)
end

-- WHERE A BOAR IS GONE, for this layout. It was a constant (`EXIT_Z` = -2377) and it cannot be one:
-- -2377 is 223 studs NORTH of the ride's line, so a boar on the ride would be despawned before it
-- ever reached the hunters.
function ForestTest.exitZOf(layout: Layout?): number
	local resolved = layout or ForestTest.ROAD_LAYOUT
	return resolved.centre.Z - resolved.amplitudeStuds - ForestTest.EXIT_SOUTH_STUDS
end

-- THE HUNTER LINE. Karen: *"hunter line just a hunter no treestand anything"* -- so a stand here is
-- a SPOT, not a structure. These are the x values a hunter may choose between; the z comes from the
-- line, so every one of them is on it.
function ForestTest.standX(index: number, layout: Layout?): number
	local resolved = layout or ForestTest.ROAD_LAYOUT
	local middle = (resolved.standCount + 1) / 2
	return resolved.centre.X + (index - middle) * resolved.standSpacing
end

-- WHERE A HUNTER STANDS, as a world position on the line.
function ForestTest.standPosition(index: number, layout: Layout?): Vector3
	local resolved = layout or ForestTest.ROAD_LAYOUT
	local x = ForestTest.standX(index, resolved)
	return Vector3.new(x, resolved.centre.Y, ForestTest.roadZ(x, resolved))
end

-- THE GROUND THE STANDS THEMSELVES OCCUPY, as minX and maxX. The one answer to "how wide is this
-- line", so no caller re-derives it from the count and the spacing.
function ForestTest.standSpan(layout: Layout?): { minX: number, maxX: number }
	local resolved = layout or ForestTest.ROAD_LAYOUT
	return {
		minX = ForestTest.standX(1, resolved),
		maxX = ForestTest.standX(resolved.standCount, resolved),
	}
end

-- THE PICK. Karen: *"hunter has square where can select stand within 10s and save then he can move
-- few steps on each side max"*.
ForestTest.PICK = {
	seconds = 10,
	-- HOW FAR HE MAY THEN MOVE, AND IT IS NOW A BOUNDARY RATHER THAN A LEASH (task 166).
	--
	-- KAREN, 2026-10-12 ~16:00, having played it: *"yes inaught but it always put me at the same
	-- place even I moved a bit we need boundries but not put back where it started"*.
	--
	-- WHAT WAS PUTTING HER BACK WAS MEASURED, not guessed, because three things could have done it
	-- (the Forest Test's own hold, `Match.Body.settle`'s drift re-pivot, or the stand placement
	-- re-pivoting). In a Play session of the Forest Test on 2026-10-12, with stand 5 locked, the
	-- character was moved 20 studs north of its stand and its distance from the stand sampled every
	-- Heartbeat for four seconds:
	--     0.0s 20.00   0.1s 6.00   0.2s 6.00   ... 4.0s 6.00
	-- ONE Heartbeat, 20 studs -> 6.000, and 6.000 for every sample after it. So it is this number
	-- and the hold that reads it, and nothing else: `Body.settle` fires once per placement and
	-- would have landed her at 0.00, and no re-pivot ran at all.
	--
	-- 6 STUDS WAS 1.7 METRES. At `Report.CONFIG`'s 0.28 m per stud a hunter could stand up and shift
	-- his feet and nothing more, and every step past it was written back to exactly 6.000 -- at 16
	-- studs a second that is a correction every frame, which is the rubber band she felt and
	-- described as being put back where she started.
	--
	-- 12 IS THE DIRECTOR'S START VALUE AND IT IS 3.4 METRES: a stand's own platform is 6 studs
	-- across (`Markers.POST_SIZE`), so 12 studs of radius is a circle four platform-widths wide --
	-- room to walk off the post, turn, and take a step to either side for a shot, which is what a
	-- hunter on a stand actually does. It is one line, and Karen's to change.
	standRadiusStuds = 12,
	-- If he picks nothing, he gets one anyway. A playtest that begins by refusing to start is a
	-- playtest nobody runs.
	defaultIndex = 5,
}

-- THE DRIVERS. Karen: *"driver people walk is let's say 1 minute max"*.
--
-- 700 STUDS, AND THE ARITHMETIC IS WORTH WRITING DOWN. A Roblox Humanoid walks 16 studs a second,
-- so 700 studs is 44 seconds on open ground. This line is through standing forest with trunks to go
-- round, which is what makes it about a minute in practice. It is NORTH of the road because the
-- boar's escape axis is baked southward (`Boar.CONFIG.field.exitZ`), and the Director's instruction
-- was not to change that axis.
-- WHICH WAY THE DRIVE COMES FROM, as a compass bearing (task 125). Karen, 2026-10-05: *"we need to
-- indicate from what side drive is comming"* and *"compass and showing where drive come direction"*.
--
-- DERIVED, NOT CHOSEN. `DRIVERS.startNorthStuds` is 700 and `driverStart` puts them at
-- `roadZ(x) + that` -- so the beaters begin 700 studs NORTH of the road and push south onto it.
-- North is +Z and is bearing 0, so the drive comes from 0. It is written down as its own value
-- because the HUD must not re-derive a fact from a position: the drive's direction is this world's
-- to state and the compass's to draw.
ForestTest.DRIVE_BEARING_DEG = 0

ForestTest.DRIVERS = {
	startNorthStuds = 700,
	walkSpeed = 16,
}

-- NOTHING IN PRODUCTION CALLS THIS any more -- task 157 gave the drive the beaters' own start line
-- (`beaterStart`) and its only reader left in the repo is `tests/client/map_ui.spec.luau`. It takes
-- the layout parameter for consistency and is a candidate for archiving with a note (rule 7), the
-- same treatment `forest-drive.md` 7.2 gave `ForestTest.drive`: a function nothing reads is the next
-- reader's trap. Not archived here, because that is its own commit (design 11, D6).
function ForestTest.driverStart(index: number, count: number, layout: Layout?): Vector3
	local resolved = layout or ForestTest.ROAD_LAYOUT
	local spread = resolved.halfSpanStuds * 1.2
	local t = if count <= 1 then 0.5 else (index - 1) / (count - 1)
	local x = resolved.centre.X - spread / 2 + spread * t
	return Vector3.new(x, resolved.centre.Y, ForestTest.roadZ(x, resolved) + ForestTest.DRIVERS.startNorthStuds)
end

-- ---------------------------------------------------------------- starting AS a beater (task 153)
--
-- KAREN, 2026-10-11: *"how to start a game as a beter?"*, and then the decision --
--   *"you start as a hunter then next round you are beater ... and yes beater are behind animals and
--   moving towards hunter line (road) like in real life ... I think we need to focus now to be a
--   beater / we will try walk spook, use horn have that feeling and improve"*.
--
-- SO A BEATER STARTS BEHIND THE ANIMALS, ON THE DRIVE SIDE, FACING THE ROAD. The rotation between
-- the two roles is the NEXT task; this is the geometry of the experience.
--
-- IT IS MEASURED FROM THE LINE'S OWN START. `LINE.spawnNorthStuds` (180) is where this world
-- releases a line of boars; a beater `behindLineStuds` further north is therefore behind every
-- animal the drive has just put on the ground. `DRIVERS.startNorthStuds` (700) is the OTHER
-- drive-side point this world owns, and it is not this one.
--
-- 60 -> 400, AND THE REASON CHANGED WITH IT (task 162). KAREN, 2026-10-12: *"can we make drive
-- longer, it's to fast / good for testing but now need longer walk for beaters let's say 2 min"*.
-- Until today this number only had to CLEAR the line's animals, and 60 studs did; now it has to
-- make a two-minute walk at the bot pace, so it is chosen by the walk and being behind the line is
-- a CHECKED CONSEQUENCE (`forest_stand.spec`) rather than the reason.
--
--   (spawnNorthStuds 180 + behindLineStuds 400 + Match.CONFIG.BOTS.GOAL_PAST_LINE_STUDS 20)
--     / Bots.CONFIG.WALK_SPEED 3.1  =  193.5 s flat, and ~210 s on the ground (MEASURED: 210.2 s and
--     210.7 s over two live drives of task 251 part 2)
--
-- A BOT LINE IS WHAT ENDS A DRIVE HERE (`Match.beaterCrossing` counts bots into the line), so that
-- product IS the length of a drive. `bots_lane.spec` asserts it, and since part 2 it asserts it
-- against the thing that matters -- that the walk outlasts the fifteen-slot script
-- (`ForestTest.slotSeconds`) -- rather than against a literal 120 s, which is a figure somebody will
-- keep moving. `forest_stand.spec` does the same per layout. **The old "120.0 s" in this header was
-- the figure before part 2 and is kept nowhere: it is 193.5 s flat.**
--
-- **THIS NUMBER DID NOT MOVE IN TASK 251 PART 2 AND THE WALK DID**, which is worth writing down here
-- because this is where the other half of the pair lives. The Director asked for a ~210 s drive
-- (2026-10-24, answering part 1's escalation) and 210 s at 5 studs/s needs 1,050 studs of travel --
-- `behindLineStuds` would have to be about 850, and the measurement below says the trees run out at
-- 775-850 studs. So the wood is what refused it, exactly as it refused keeping 9 studs/s in task 162,
-- and `Bots.CONFIG.WALK_SPEED` went 5 -> 3.1 instead. Its own comment carries the reason a beater
-- LINE advances slower than a man walks.
--
-- 580 IS WHAT THE WOOD HOLDS, MEASURED in this place on 2026-10-12 (`test`'s own Edit session, nine
-- stand columns from x 2430 to 3630, sampled every 25 studs out to 1,000):
--   * TERRAIN carries on past 1,000 studs north at every one of the nine, with no gap;
--   * TREES -- a colliding part within 25 studs -- run out at 775-850 studs depending on x, and
--     past that it is bare hillside. So the WOOD is about 775 studs deep and a start at 580 is
--     inside it with room to spare;
--   * the ground rises from y 140 at the road to y 234 at 575 studs north and falls away beyond
--     600, so 580 puts the line ON the crest, looking down the hill at the road;
--   * the ground path from the pad at the middle stand down to the road is 611.6 studs against 580
--     flat, so the real walk is ~126 s rather than 120 -- longer, never shorter;
--   * the pad column itself (x 3030): terrain 234.1, `groundAt` 234.1 (delta 0.00, so
--     `Markers.groundFor` builds `BeaterStart` and the drive starts), `roomToStand` true at
--     `clearStuds`, nearest trunk 12.4 studs -- in the trees, not inside one.
-- 700 WOULD ALSO FIT THE WOOD. It was not taken in task 162 because the pair had to make 120 s and
-- 580 was the half of it that left the pace realistic -- and since task 251 part 2 the pace is the
-- half that moved instead (`Bots.CONFIG.WALK_SPEED` 3.1, **0.87 m/s**, which is a beater LINE
-- advancing and not a man walking; its own comment carries the source). 580 stays because the wood
-- is what bounds it: 210 s at the old 5 studs/s would need 1,050 studs of travel and the trees run
-- out at 775-850.
ForestTest.BEATER = {
	behindLineStuds = 400,
	-- HOW CLOSE A TRUNK MAY BE to where she is put down. A Roblox character is 2 studs across, so 6
	-- is a body's width of clearance on every side: enough that she does not land inside a tree.
	clearStuds = 6,
	-- ...and how a clear spot is looked for when the straight-behind point is blocked: sideways,
	-- alternating east and west, so the first answer is always the nearest one to the push line.
	sideStepStuds = 10,
	sideTries = 8,
	-- How far above the ground she is put, so she drops onto it rather than into it. It used to be
	-- *"the same 4 studs `ForestTest.spawnPosition` uses for a hunter"*, and task 157 archived that
	-- function: a hunter is now put down by the drive, on the marker part `ForestTest.Markers` builds
	-- at the ground `terrainYAt` measured, plus `Match.CONFIG.STAND_HEIGHT_STUDS`.
	dropStuds = 4,
}

-- HOW CLOSE SHE MAY GET BEFORE THEY GO, AND WHAT GOING MEANS (task 154).
--
-- KAREN, 2026-10-11, after the first beater playtest: *"so animals already there somewhere in
-- bushes close to trees ect / once I get a bit closer they just run away without stop it's not like
-- they cool down they spooked and run away / so from me direction they looking they run away / horn
-- reach is further once they hear also run without stop"*.
--
-- TWO NUMBERS AND ONE RULE. The numbers are the two reaches -- how close she has to walk, and how
-- far the horn carries -- and the rule is the SAME ONE for both, and the same one task 150 built
-- for a heard shot: the fright latches, the animal keeps the line it set off on, it never settles,
-- and the only thing that ends it is leaving at `EXIT_Z`. There is no second panic system, because
-- two systems that both decide when an animal calms down is this project's named killer (rule 3).
--
-- IN METRES *AND* IN STUDS, which is task 150's lesson and `Horn.CONFIG`'s shape: a radius written
-- in studs was compared against distances in metres for two tasks. Both spellings are here so a
-- world or a spec may override either unit, and `forest_stand.spec` asserts they agree to the stud.
--
-- 25 m IS THE DIRECTOR'S START VALUE, and it is a real number for this animal rather than a round
-- one: the flight-initiation distance of wild boar to a person on foot is tens of metres, not the
-- 25 STUDS (7 m) this world used before today -- `PACE.DRIVER_RUN_STUDS`, which is "a driver this
-- close makes it run" and was the whole of the beater's reach in task 153. At 7 m she was on top of
-- them before anything moved, which is not what walking a wood is like.
--
-- ...AND SINCE TASK 172 THERE ARE TWO REACHES AND A CLOCK, because one reach is a disappearance.
-- KAREN, 2026-10-13 ~09:20, after playing 168-171: *"beaters has to see more animals when walking I
-- want to see how they stand and then start to run or run but I want to see them more"*.
--
-- WHAT SHE WAS LOOKING AT, AND IT IS ARITHMETIC RATHER THAN TASTE: the one reach was 25 m and the
-- fright LATCHED, so the first thing a walking beater ever did to a group was make it bolt -- at 25 m,
-- through a wood whose trunks close the view long before that. By the time she could see where the
-- noise came from, the animals were running away at `PACE.RUN_SPEED`. She never saw an animal; she
-- saw a wood with something leaving it.
--
-- SO THE ENCOUNTER HAS THREE STAGES NOW, and every one of them is a number in this table:
--   NOTICE   35 m -- the group STOPS, puts its head up and faces him (`Brain:notice`, which is task
--            118's own ALERT state asked for from outside). Nothing runs; nothing latches.
--   ALERT    2 s  -- how long that look holds before the group breaks. The Director's start value,
--            inside the dispatch's "~1-2 s".
--   FLUSH    20 m -- ...or closer than this, whichever comes first, and THEN they bolt and never
--            stop, which is task 154's latch unchanged.
-- `ForestTest.encounterStage` is the whole machine, pure, and `forest_stand.spec` asserts each stage.
ForestTest.SPOOK = {
	METRES_PER_STUD = 0.28, -- the same number `Horn.CONFIG`, `Report.CONFIG` and `Boar.CONFIG.SENSE` publish
	-- HOW FAR OFF A GROUP NOTICES HIM. 35 m is the Director's start value and it is a real number for
	-- this animal as well: the flight-initiation distance of wild boar to a person on foot is tens of
	-- metres, and the whole band between noticing and fleeing is what a stalker calls the stand.
	NOTICE_M = 35,
	NOTICE_STUDS = 125, -- 35 m / 0.28
	-- HOW LONG THEY STARE BEFORE THEY GO. It is the WORLD's number and not the animal's -- the Brain
	-- has `SENSE.ALERT_SECONDS` (2.5) for a hunter who happens to be standing about, and a drive is a
	-- man walking at them, so the drive says how long its own stage lasts and hands it in.
	ALERT_SECONDS = 2,
	-- ...AND HOW CLOSE HE MAY GET BEFORE THEY GO WHATEVER THE CLOCK SAYS. 20 m, down from 25: the
	-- stage above is what she asked to see, so the bolt belongs at the near edge of it.
	BEATER_M = 20,
	BEATER_STUDS = 71, -- 20 m / 0.28

	-- ...AND A DEER IS NOT A BOAR ABOUT IT (task 253). **THE DIRECTOR'S DECISION, 2026-10-24**, after
	-- task 251c measured the stag bolting the moment he was put down: *"a wary stag slips out quietly
	-- AHEAD of the beaters and only flees hard when pressed close"*. So for a DEER kind, noticing the
	-- line is not a flush: beyond this radius from the NEAREST BEATER'S BODY a deer that would have
	-- been flushed SNEAKS instead -- it keeps walking the route the drive gave it, which for the stag
	-- is the approach, the treeline sneak and the crossing, with the edge check at the verge still
	-- offered. Inside it, at a shot, or at the hand horn's flush, it bolts exactly as before.
	--
	-- 40 STUDS IS 11 m, and it is the Director's start value as one data row. What it has to be
	-- SMALLER than is the geometry that was flushing him: the notice band is
	-- `noticeAheadStuds` = 100 studs deep in front of the line and the flush circle
	-- (`BEATER_STUDS`) is 71, so at 60 -- task 251c's lead -- every clamped group was spawned inside
	-- both and `ALERT_SECONDS` ended the stand two seconds later (`ESCALATE.md`, 2026-10-24).
	-- `forest_stand.spec` asserts the ORDER of the three rather than the numbers:
	-- `DEER_FLUSH_STUDS < BEATER_STUDS < NOTICE_STUDS`.
	--
	-- A BOAR IS UNTOUCHED, and that is why this is a separate row rather than a smaller
	-- `BEATER_STUDS`: a sounder that would not break for a man at 50 studs is not what Karen has been
	-- watching for twenty tasks, and nothing about the boar's drive was reported wrong.
	DEER_FLUSH_STUDS = 40,

	-- THE LINE SWEEPS WHAT IT PASSES (task 168, the Director's second pass). KAREN, 2026-10-12
	-- ~21:50: *"animals can't come behind beaters"*, and ~21:55: *"once beater push they go or turn
	-- around but not after beaters ahead and they come from backs"*.
	--
	-- WHAT THE CIRCLE LEFT BEHIND, MEASURED: a live drive left **13 of 27 animals behind the line
	-- without their ever having moved**. `BEATER_STUDS` is a RADIUS round each body, so the depth it
	-- covers TAPERS to nothing sideways -- midway between two lanes 150 studs apart it is
	-- `sqrt(89^2 - 75^2)` = 47.9 studs, and the two lanes' circles leave the ground between them
	-- thinly covered rather than swept. The animals Karen watched come out behind the beaters were
	-- never pushed at all: the line walked past them.
	--
	-- SO THE FRONT IS A LINE AND NOT A ROW OF CIRCLES. `ForestTest.lineFrontAt` interpolates the
	-- beaters' own z ACROSS the front, so every x on it has a front -- there is no gap between two
	-- lanes to derive, because there is no gap. What IS derived from the lane spacing is the DEPTH,
	-- below.
	SWEEP = {
		ENABLED = true,
		-- A FLOOR under the derived depth, so a world that put its lanes `2 * BEATER_STUDS` apart
		-- (where the formula answers 0) still sweeps something. 30 studs is 8.4 m -- about three
		-- strides of a walking man, which is one tick of the line at any pace it will ever walk.
		MIN_AHEAD_STUDS = 30,
		-- ...AND EVERYTHING BEHIND THE FRONT IS SWEPT, WITH NO LIMIT, which is the whole rule: an
		-- animal the line has passed is exactly the animal Karen is complaining about. It is written
		-- as a number rather than as `math.huge` so a spec can state it, and it is this world's own
		-- depth: nothing is ever further behind the line than the walk itself.
		BEHIND_STUDS = 1200,
	},
}

-- HOW FAR APART THE LANES OF THE LINE ARE, AND IT IS ONE STAND (task 167, made per layout by 179).
-- PURE, and the ONE definition.
--
-- THE SPACING IS THE STAND GRID, AND THAT IS THE WHOLE REASON FOR THE NUMBER. A lane laid out on the
-- stand grid lands square in front of a stand, so `Match.beaterGoalFor` (which takes the post
-- NEAREST the lane's own start) and `Match.crossedLine` (which takes the same one) pick that same
-- post -- the goal is straight ahead of the lane and arriving at it IS crossing. Any other spacing
-- puts the goal in front of a stand the lane is not walking at, on a road that is a sine 30 studs
-- deep. It is also a real beater interval: 150 studs is 42 m at `ForestTest.SPOOK.METRES_PER_STUD`.
--
-- IT USED TO BE A CONSTANT IN `BEATER` (`laneSpacingStuds`, reading `STAND_SPACING`), and task 179
-- took it out: with three layouts the spacing is 150, 150 and 130, so one number there would be a
-- SECOND answer disagreeing with the live layout on a ride. This paragraph came with it -- round 3
-- of that task left it sitting above `BEATER.dropStuds`, so a reader met a lane-spacing essay as the
-- drop height's header. `forest_stand.spec` asserts the identity for every layout rather than for
-- one constant.
--
-- ONE ANSWER, AND IT IS THE LAYOUT'S (round 2's note). This used to honour a `laneSpacingStuds` on
-- the `beater` table first, so a spec could drive the band arithmetic with a spacing no layout has --
-- which made it a SECOND answer to "how far apart is a lane", reachable by any caller that passed a
-- table. A spec that wants a made-up spacing hands in a made-up LAYOUT instead, which is the same
-- thing said once.
function ForestTest.laneSpacing(layout: Layout?): number
	return (layout or ForestTest.ROAD_LAYOUT).standSpacing
end

-- HOW DEEP THE SWEEP REACHES IN FRONT OF THE LINE, derived from the lane spacing (task 168).
-- PURE, and the derivation is the whole point: it is the depth the OLD per-beater circle really had
-- at the worst place on the front -- midway between two lanes -- promoted to the whole front.
--
--     sqrt(BEATER_STUDS^2 - (laneSpacing / 2)^2)
--
-- So the band is NO WEAKER than the circles anywhere (it is exactly their worst case) and strictly
-- stronger between two lanes, where the circle tapered. WITH TASK 172'S NUMBERS the flush reach is
-- 71 and the lanes are 150, so `sqrt(71^2 - 75^2)` is imaginary and the answer is the floor, 30
-- studs. (It was 47.9 at the pre-172 reach of 89, and that number stood here until round 2 of
-- task 179 caught it; `noticeAheadStuds` below has always stated the current 100/30 correctly.)
--
-- THE FLOOR IS `MIN_AHEAD_STUDS`, for a lane spacing at or past `2 * BEATER_STUDS`, where the
-- formula answers zero or is imaginary: a line of men that far apart is not a line, and the honest
-- answer is "a man's own few strides" rather than an error.
--
-- THE SPACING IS NOW PASSED IN rather than read off `beater` (task 179): the lane spacing is the
-- LAYOUT's stand spacing, so there is no number in `BEATER` to read and no table reaches this
-- parameter at all -- it is a plain number, which is what makes "how far apart is a lane" ONE
-- answer. (Round 2 of that task left this sentence saying a `beater` table was still honoured, which
-- was the second answer it had just removed.)
local function bandDepth(reach: number, laneSpacing: number, spook): number
	local half = (laneSpacing or 0) / 2
	local floor = ((spook or ForestTest.SPOOK).SWEEP or {}).MIN_AHEAD_STUDS or 0
	local inside = reach * reach - half * half
	if inside <= 0 then
		return floor
	end
	return math.max(floor, math.sqrt(inside))
end

function ForestTest.sweepAheadStuds(spook, layout: Layout?): number
	return bandDepth(ForestTest.beaterSpookStuds(spook), ForestTest.laneSpacing(layout), spook)
end

-- ...AND THE SAME DERIVATION FOR THE NOTICE BAND (task 172), because it is the same geometry asked
-- of the bigger reach: midway between two lanes a circle of radius `NOTICE_STUDS` reaches
-- `sqrt(125^2 - 75^2)` = 100 studs in front of the front, and that is the depth promoted to the
-- whole of it. With the shipped numbers the two bands are 100 studs (notice) and 30 studs (flush,
-- the floor -- a flush circle of 71 studs does not reach halfway across a 150-stud lane gap at all),
-- so a group is looked at a long way before anything decides to run. That ORDER is not an accident
-- and `forest_stand.spec` asserts it: a notice band narrower than the flush band would mean animals
-- that bolt without ever having been seen to stand, which is the whole defect this task fixes.
function ForestTest.noticeAheadStuds(spook, layout: Layout?): number
	return bandDepth(ForestTest.noticeStuds(spook), ForestTest.laneSpacing(layout), spook)
end

-- WHERE THE LINE'S FRONT IS AT THIS x. PURE: a list of beater positions in, the z of the line at
-- `x` out, or nil when nobody is pushing.
--
-- LINEAR INTERPOLATION BETWEEN THE TWO NEAREST LANES, and CLAMPED to the outermost beater past
-- either end -- which is what makes the front continuous and the coverage gapless by construction
-- rather than by a number somebody tuned. A front of one man is that man's own z everywhere, which
-- is right: a solo beater IS the line.
--
-- THE SORT IS DONE HERE AND NOT ASSUMED, because the caller's list is built from
-- `Players:GetPlayers()` plus the bot rigs in creation order, and neither is sorted by x.
function ForestTest.lineFrontAt(beaters, x: number): number?
	local points = {}
	for _, beater in ipairs(beaters or {}) do
		if typeof(beater.position) == "Vector3" then
			table.insert(points, beater.position)
		end
	end
	if #points == 0 then
		return nil
	end
	table.sort(points, function(a, b)
		return a.X < b.X
	end)
	if x <= points[1].X then
		return points[1].Z
	end
	local last = points[#points]
	if x >= last.X then
		return last.Z
	end
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		if x >= a.X and x <= b.X then
			local span = b.X - a.X
			if math.abs(span) < 1e-9 then
				return a.Z
			end
			return a.Z + (b.Z - a.Z) * ((x - a.X) / span)
		end
	end
	return last.Z
end

-- IS THIS ANIMAL INSIDE THE SWEEP? PURE, in the two numbers that matter: how far IN FRONT of the
-- front it is (`aheadStuds`, positive toward the road, negative for an animal the line has passed)
-- and how deep the band reaches.
--
-- EVERYTHING BEHIND THE FRONT IS CAUGHT, which is the rule Karen asked for -- *"not after beaters
-- ahead"*. An animal can therefore be behind the line for one tick of the push and no longer: the
-- band moves with the front, so the moment the front reaches it, it goes.
function ForestTest.sweepCatches(aheadStuds: number, depthStuds: number, spook): boolean
	local sweep = (spook or ForestTest.SPOOK).SWEEP
	if sweep == nil or sweep.ENABLED ~= true then
		return false
	end
	if aheadStuds > depthStuds then
		return false -- still comfortably in front of the line: its turn has not come
	end
	return aheadStuds >= -(sweep.BEHIND_STUDS or 0)
end

-- WHAT THIS ANIMAL'S ENCOUNTER WITH THE LINE HAS REACHED (task 172). PURE, in the four numbers that
-- decide it, and it is the WHOLE state machine -- `ForestTest.spookNearBeaters` does nothing but
-- take the measurements and obey the answer.
--
--   `aheadStuds`   how far IN FRONT of the line's interpolated front it is (`lineFrontAt`), negative
--                  for an animal the line has passed. The 168 band, which is gapless across x.
--   `gapStuds`     how far the NEAREST beater's body is, flat. The 154 circle.
--   `alertedFor`   how long it has been holding a look, or nil for an animal that has not noticed.
--
-- THREE ANSWERS: "none", "notice" (stand and look) and "flush" (bolt, and never stop).
--
-- THE BAND AND THE CIRCLE ARE A UNION, AND THAT IS DELIBERATE. Task 154 used the circle alone and
-- its coverage TAPERED sideways, so a group midway between two lanes was never touched (168 measured
-- 13 animals of 27 standing where they were while the line walked past them). Task 168 replaced it
-- with the band, which is gapless but shallow. Either one alone is weaker than both: the band is
-- what makes "nothing is left behind the line" true at any x, and the circle is what makes a beater
-- walking straight at a group matter at his own reach rather than at the band's depth. They are both
-- "how close is too close", asked of one geometry, and the nearer trigger wins.
--
-- ...AND THE CLOCK IS WHAT ENDS THE STAND. A group that has looked for `ALERT_SECONDS` breaks
-- whether or not he has closed any further, which is what a real group does and what stops an
-- approach that stalls from freezing a herd in a stare for ever.
function ForestTest.encounterStage(
	aheadStuds: number,
	gapStuds: number,
	alertedFor: number?,
	spook,
	layout: Layout?,
	isDeer: boolean?
): string
	local resolved = spook or ForestTest.SPOOK
	local flush = ForestTest.beaterSpookStuds(resolved)
	if
		ForestTest.sweepCatches(aheadStuds, ForestTest.sweepAheadStuds(resolved, layout), resolved)
		or gapStuds <= flush
		or (alertedFor ~= nil and alertedFor >= ForestTest.alertSeconds(resolved))
	then
		-- A DEER SLIPS AWAY UNLESS THE MAN IS CLOSE (task 253, the Director's decision). Everything
		-- that flushes a boar -- the band, the circle, the clock -- reaches a deer as "sneak" while
		-- the nearest beater is further than `DEER_FLUSH_STUDS`, and "sneak" means the drive does
		-- NOTHING to it: it keeps walking the route it was given, which is the one thing a flush
		-- throws away (`MOVE.FLIGHT` runs straight and ignores a route, a check and a sneak band).
		--
		-- IT IS DECIDED HERE AND NOT AT THE CALL SITE because this function is the whole state
		-- machine (task 172) and a second place that could answer "does this one run" is exactly
		-- what one-owner is for. The caller measures `gapStuds` off the nearest beater's BODY, live,
		-- on the tick it asks (Learning Agent L-024).
		if isDeer == true and gapStuds > ForestTest.deerFlushStuds(resolved) then
			return "sneak"
		end
		return "flush"
	end
	if
		ForestTest.sweepCatches(aheadStuds, ForestTest.noticeAheadStuds(resolved, layout), resolved)
		or gapStuds <= ForestTest.noticeStuds(resolved)
	then
		return "notice"
	end
	return "none"
end

-- THE REACH IN STUDS, from whichever unit the table carries. PURE, and the ONE place the conversion
-- happens -- `Horn.spookStuds`'s rule, for the same reason: no caller multiplies by
-- `METRES_PER_STUD` itself. The studs win when they are there, because a world that overrides the
-- studs means the studs.
-- HOW FAR OFF A GROUP NOTICES A BEATER, in studs, from whichever unit the table carries (task 172).
-- `beaterSpookStuds`'s own rule, one reach up: the studs win when they are there.
function ForestTest.noticeStuds(spook): number
	local resolved = spook or ForestTest.SPOOK
	if type(resolved.NOTICE_STUDS) == "number" then
		return resolved.NOTICE_STUDS
	end
	if type(resolved.NOTICE_M) == "number" then
		return resolved.NOTICE_M / resolved.METRES_PER_STUD
	end
	-- A WORLD THAT NAMES NO NOTICE REACH gets the flush reach, which is the game before this task:
	-- noticing and fleeing at one distance is exactly what 154 built.
	return ForestTest.beaterSpookStuds(resolved)
end

-- HOW CLOSE A BEATER HAS TO BE BEFORE A DEER BOLTS (task 253), in studs, from whichever unit the
-- table carries -- `beaterSpookStuds`'s own rule, a third time. A WORLD THAT NAMES NO DEER REACH
-- gets the flush reach, which is the game before this task: deer and boar breaking at one distance.
function ForestTest.deerFlushStuds(spook): number
	local resolved = spook or ForestTest.SPOOK
	if type(resolved.DEER_FLUSH_STUDS) == "number" then
		return resolved.DEER_FLUSH_STUDS
	end
	if type(resolved.DEER_FLUSH_M) == "number" then
		return resolved.DEER_FLUSH_M / resolved.METRES_PER_STUD
	end
	return ForestTest.beaterSpookStuds(resolved)
end

-- HOW LONG A NOTICED GROUP HOLDS ITS LOOK, in seconds, with a world's override honoured the same way.
function ForestTest.alertSeconds(spook): number
	local resolved = spook or ForestTest.SPOOK
	if type(resolved.ALERT_SECONDS) == "number" then
		return resolved.ALERT_SECONDS
	end
	return 0
end

function ForestTest.beaterSpookStuds(spook): number
	local resolved = spook or ForestTest.SPOOK
	if type(resolved.BEATER_STUDS) == "number" then
		return resolved.BEATER_STUDS
	end
	return resolved.BEATER_M / resolved.METRES_PER_STUD
end

-- WHICH WAY A BEATER IS PUSHING, as a compass bearing. `DRIVE_BEARING_DEG` is where the drive comes
-- FROM (0, north) and that is what a hunter's compass marks; a beater walks the other way, so her
-- marker is the road. Derived from the one fact above it, never written twice.
ForestTest.PUSH_BEARING_DEG = (ForestTest.DRIVE_BEARING_DEG + 180) % 360

-- ...AND THE WORD THAT GOES WITH IT (task 153 round 2, the Reviewer's blocking finding). The marker
-- is a chevron and a label, and turning the chevron round without the label gave a beater a compass
-- saying the DRIVE is south while every animal she is pushing is north of her. The hunter's word is
-- the Hud's own `Compass.CONFIG.DRIVE_LABEL`; this is the beater's, and it lives beside the bearing
-- it belongs to so the two can never be changed apart.
ForestTest.PUSH_LABEL = "ROAD"

-- WHICH TEAM IS DOING THE PUSHING, so the HUD never hard-codes a team name. The string itself is
-- `Drive.TeamName`'s and the one translator from Karen's word to it is `Match.Body.ROLE_WORDS`;
-- this is the world saying which of the two is the beater's, for a client that can only see
-- `Player.Team`.
ForestTest.PUSH_TEAM = "Drivers"

-- THE START SWITCH (task 153). An attribute on `ServerStorage`, set in Edit mode, that says which
-- role a player STARTS as in this place -- so Karen can press Play and already be a beater instead
-- of typing `/beater` on the road. Default (no attribute) is the hunter this world has always
-- started her as.
--
-- AN ATTRIBUTE AND NOT A FILE, for the same reason `tools/flags.py` uses one: it is a playtest
-- setting, it must not show up in the git tree, and it survives into the Play session because Play
-- copies the Edit DataModel. It is NOT a `DHFlag_*` name, so the harness's override guard -- which
-- refuses to run while a flag override is set -- cannot see it and cannot be defeated by it.
ForestTest.START_ROLE_ATTRIBUTE = "DHForestStartRole"

-- HOW LONG A DRIVE RUNS IN THIS WORLD, for a Director who needs to SEE the end of one (task 201
-- part 2). `ForestTest.DRIVE.seconds` is 300, so a results board -- the screen Karen reads at the
-- end of every drive -- costs five minutes a frame, and `Match.advanceForTests` is the server's and
-- cannot be reached from the harness (`tools/studio_mcp.py`'s own docstring: that thread may not
-- `require`). This is the same kind of switch as `DHForestLayout` and `DHForestStartRole` above and
-- is read in the same place, the composition root, through `Match.WORLD_OVERRIDABLE`'s
-- `DRIVE_SECONDS`.
--
-- AN ATTRIBUTE AND NOT A FILE, for their reason: it is a playtest setting, it must not show up in
-- the git tree, and it survives into Play because Play copies the Edit DataModel. It is not a
-- `DHFlag_*` name, so the harness's override guard cannot see it and cannot be defeated by it.
ForestTest.DRIVE_SECONDS_ATTRIBUTE = "DHForestDriveSeconds"

-- THE BOUNDS, AND THEY ARE THE POINT OF HAVING A RESOLVER AT ALL. Below 20 s a drive cannot reach
-- its own first release (`FIRST_RELEASE_SECONDS`), so a "short drive" that ended before any animal
-- moved would be a worse lie than the long one; above `DRIVE.seconds` the switch would be making
-- the playtest LONGER, which nobody has asked for and which a typo could do by accident.
ForestTest.DRIVE_SECONDS_MIN = 20

-- WHICH LANE OF THE LINE THIS BEATER WALKS, as an offset along the road from the push line (task
-- 167). PURE, and the one answer to *"all bots came to me"*.
--
-- INDEX 1 IS THE PUSH LINE ITSELF and gets 0, so a REAL beater -- she is always index 1, because the
-- drive numbers its own players first -- starts exactly where task 153 put her and nothing about
-- Karen's own walk changes. The bots take 2, 3, 4, 5 and therefore +-1 and +-2 stand spacings, so
-- when she walks as a beater the middle of the line is hers and the bots flank her. That is the
-- property `Bots.Lane`'s archived `offsetFor` was written for (*"lane 0 is never issued, so the
-- middle stays the PEOPLE's"*), kept, and moved to the world that knows how wide a front is.
--
-- HOW FAR APART THE LANES OF THE LINE ARE, AND IT IS ONE STAND (task 167).
--
-- KAREN, 2026-10-12 ~16:10, having played a drive as a hunter with the bots on: *"and seem like
-- all bots came to me"*. She was right, and the geometry says why: every beater -- real or bot --
-- was put down at ONE measured point, the push line through the stand she had locked, and the
-- bot lanes were +-18 and +-36 studs about it. Four bodies inside 72 studs of her stand is not a
-- drive line, it is a queue at her feet.
--
-- A LINE SPANS THE FRONT. `index` is the beater's place in it (the drive asks `placement` for
-- index 1, 2, 3 ... exactly as it asks for a hunter's stand), and `beaterLaneOffset` deals those
-- indices out across the hunters' line: 0, +150, -150, +300, -300 ... So four bot beaters cover
-- 600 studs of front -- stands 3 to 7 with her in the middle of them -- and each walks its own
-- lane down to its own stretch of road.
--
--
-- ALTERNATING, NEAREST FIRST, which is the same shape `beaterStartPosition` searches for a clear
-- spot with and the same shape the archived lane offsets had: one idiom in this repo for "deal these
-- out either side of a line".
function ForestTest.beaterLaneOffset(index: number?, layout: Layout?): number
	local which = (index or 1) - 1
	if which <= 0 then
		return 0
	end
	local step = math.ceil(which / 2) * ForestTest.laneSpacing(layout)
	return if which % 2 == 1 then step else -step
end

-- WHERE A BEATER STARTS, as flat geometry: north of the line's own spawn, on the push line through
-- `standX`. PURE -- the ground and the trunks are the server's to measure (`beaterStartPosition`).
function ForestTest.beaterStart(standX: number, sideOffset: number?, layout: Layout?): Vector3
	local resolved = layout or ForestTest.ROAD_LAYOUT
	local x = standX + (sideOffset or 0)
	return Vector3.new(x, resolved.centre.Y, ForestTest.roadZ(x, resolved) + ForestTest.beaterNorthStuds())
end

-- HOW FAR NORTH OF THE LINE A BEATER STARTS, AND IT IS THE SAME IN EVERY LAYOUT (task 179). That is
-- deliberate: a bot line is what ends a drive here (`Match.beaterCrossing` counts bots into the
-- line), so this distance IS the length of a drive --
--
--   (LINE.spawnNorthStuds 180 + BEATER.behindLineStuds 400 + Match.CONFIG.BOTS.GOAL_PAST_LINE_STUDS
--     20) / Bots.CONFIG.WALK_SPEED 5  =  120.0 s
--
-- -- and task 162 measured that pair against the wood's own depth. A per-layout distance would make
-- a drive's LENGTH a property of which layout was dealt, which is a thing nobody asked for and
-- which Karen would feel as a drive that is sometimes short. `forest_stand.spec` asserts the 120 s
-- for every layout, which holds by construction because no layout carries the number.
function ForestTest.beaterNorthStuds(): number
	return ForestTest.LINE.spawnNorthStuds + ForestTest.BEATER.behindLineStuds
end

-- WHICH WAY SHE LOOKS: at the line, straight down the push. The point on the line at her own x,
-- which is also where the animals she is behind are heading.
function ForestTest.roadPointAt(x: number, layout: Layout?): Vector3
	local resolved = layout or ForestTest.ROAD_LAYOUT
	return Vector3.new(x, resolved.centre.Y, ForestTest.roadZ(x, resolved))
end

-- THE GROUND A DRIVE USES, as a rectangle: the stands' own span, from the exit in the south to the
-- beaters' start in the north. The one answer to "where does this drive happen", so the lodge can be
-- asserted clear of every layout's without either module knowing about the other
-- (`tests/server/lobby.spec.luau`; design 9.4).
function ForestTest.corridorOf(layout: Layout?): { minX: number, maxX: number, minZ: number, maxZ: number }
	local resolved = layout or ForestTest.ROAD_LAYOUT
	local span = ForestTest.standSpan(resolved)
	return {
		minX = span.minX,
		maxX = span.maxX,
		minZ = ForestTest.exitZOf(resolved),
		maxZ = resolved.centre.Z + ForestTest.beaterNorthStuds(),
	}
end

-- THE BOAR FIELD'S BOUNDS FOR THIS LAYOUT. It is `ForestTestBoot`'s own formula, moved here and
-- given the layout's numbers, because with three layouts the boot cannot compute it once at load
-- time: a drive on the ride has to swap the field when the layout is promoted, or `Brain.insideField`
-- clamps every animal to the road's rectangle 500 studs away.
--
-- EVERY NUMBER IN `fieldFor(ROAD_LAYOUT)` IS THE ONE THE BOOT USED TO BUILD, and that is asserted
-- rather than claimed (`forest_stand.spec`): bounds 2230..3830 by -2477..-1197, exit -2377, ground
-- 138. That identity is how "the road layout is unchanged" is checked (design 10.1). Task 245b adds
-- a `road` KEY beside them for the deer's leap -- where the lane runs, which is the same kind of
-- fact about this world's geometry -- and changes none of the four.
function ForestTest.boundsOf(layout: Layout?): { minX: number, maxX: number, minZ: number, maxZ: number }
	local resolved = layout or ForestTest.ROAD_LAYOUT
	return {
		minX = resolved.centre.X - resolved.halfSpanStuds,
		maxX = resolved.centre.X + resolved.halfSpanStuds,
		minZ = ForestTest.exitZOf(resolved) - 100,
		maxZ = resolved.centre.Z + ForestTest.DRIVERS.startNorthStuds + 200,
	}
end

-- ...AND THE WHOLE FIELD, which is what `Boar.defaultWorld` and `Runtime:setField` take.
function ForestTest.fieldFor(layout: Layout?)
	local resolved = layout or ForestTest.ROAD_LAYOUT
	return {
		bounds = ForestTest.boundsOf(resolved),
		exitZ = ForestTest.exitZOf(resolved),
		-- ONE GROUND HEIGHT FOR EVERY LAYOUT, and `GROUND_Y`'s own comment is why: a per-layout 185
		-- would put `Brain:_outcome`'s fall floor at 135 on an edge drive, and this wood goes down to
		-- 99.
		groundY = ForestTest.GROUND_Y,
		-- WHERE THE ROAD RUNS, for the deer's leap (task 245b). It is on the FIELD because that is
		-- already this world's geometry as the animals' owner sees it -- `bounds` and `exitZ` are
		-- the same kind of fact -- and because the field is what a `Brain` is born with, so an
		-- animal cannot be handed a road its world does not have.
		--
		-- A FUNCTION AND NOT A NUMBER, because this ride is a SINE: `roadZ` swings by
		-- `amplitudeStuds` over the map's length, so a constant z would put the band in the trees at
		-- one end and off the lane at the other. The layout is captured here, so an animal born on
		-- one layout keeps reading that layout's road even if the next drive picks another.
		--
		-- THE DEV MAP'S FIELD HAS NO `road` and nothing adds one, which is what makes the leap inert
		-- in that world: `Brain.onRoad` answers false for a nil road, so the DEV harness measures the
		-- same game it measured before this task.
		road = {
			halfWidthStuds = ForestTest.SHAPE.halfWidthStuds,
			zAt = function(x: number): number
				return ForestTest.roadZ(x, resolved)
			end,
		},
	}
end

-- WHERE THE BOARS WAIT. Karen: *"so wildboars will be located in different places"*. Each is a
-- point north of the road with a sounder size; the schedule below decides when each one moves.
--
-- SIZES ARE KAREN'S: *"we have make a groups 10 8 20 25"*, plus the lone big males she asked for.
--
-- THEY MOVED IN AND THEY MOVED CLOSER TO THE MIDDLE, and both are measured rather than tidied.
--
-- DISTANCE: at 240-450 studs a pushed herd needs minutes to reach the road, and Karen's whole test
-- is action inside 20 seconds. A flushed boar runs at roughly 20 studs a second, so 130-210 studs
-- is 7-11 seconds of running -- which lands a wave on the road inside the 20-second beat with time
-- to be seen coming.
--
-- SIDEWAYS: she stands at stand 5, x = 3030. The first spread ran to +-610, so the far ones crossed
-- 600 studs away and she would never have seen them. These sit within +-330, which at the road is
-- inside a few seconds' walk of her and well within sight down a 40-stud lane.
-- WHERE A WAVE IS RELEASED, relative to the stand the hunter actually locked (task 123 round 8).
-- With nobody playing, `standX` is the default stand's, which is what the drive used before.
function ForestTest.wavePoint(standX: number, spec, layout: Layout?): Vector3
	local resolved = layout or ForestTest.ROAD_LAYOUT
	local x = standX + (spec.offsetX or 0)
	return Vector3.new(x, resolved.centre.Y, ForestTest.roadZ(x, resolved) + (spec.northStuds or 100))
end

-- THE NAMED HOLDINGS ARE GONE (task 123 round 8), and what replaced them is above:
-- `ForestTest.wavePoint` plus the `offsetX`/`northStuds` the SCHEDULE now carries per wave.
--
-- They were six fixed points on the map -- west-hollow, centre-thicket, east-ridge, far-east and two
-- singles, 60 to 110 studs north of the road at x offsets of -300 to +330 from the map's centre --
-- and the indirection was a name in the schedule looked up in a table. It had to go because every
-- one of those x values was absolute: stands are 150 studs apart, so a wave released at a fixed
-- point could be 300 studs from the stand Karen had actually picked, and whether she ever got a
-- close crossing was luck. The distances they encoded (`northStuds` 60-110, which is 13-24 s at a
-- walk) are carried forward in the schedule's own numbers.

-- THE AMBIENT DRIVE: ACTION WITHOUT ANOTHER PLAYER.
--
-- Karen: *"let's make each 20s cross 1 flock then 1 big male then on other side few so to be
-- action"*, and *"several animals cross road / several go back"*. She is testing alone in the
-- morning, so nothing here may depend on a driver existing.
--
-- `turnsBack` IS THE HALF SHE ASKED FOR TWICE. A drive where every animal crosses is a shooting
-- gallery; the ones that come to the edge, think better of it and go back are what makes a hunter
-- wait. It is per-entry data so the rhythm is readable rather than random.
-- EVERY WAVE IS AIMED AT THE HUNTER (task 123 round 8). Karen, 2026-10-05: *"also they has to
-- cross close to me also / ... they has to cross like from left to right or opositi so I can shoot
-- straigh also not only on sides"*.
--
-- `offsetX` IS RELATIVE TO THE STAND SHE LOCKED, not to the middle of the map. Before this round the
-- holdings sat at fixed world positions and whether a crossing was near her was luck -- stands are
-- 150 studs apart, so a wave released at a fixed x could be 300 studs away from the one she picked.
-- `ForestTest.wavePoint` adds her stand's x to this, so "55 studs west of me" means that wherever
-- she stands.
--
-- `lateral` IS THE PASS ACROSS HER VIEW. She faces NORTH (+Z), so -- and this is the half that is
-- easy to get backwards -- her RIGHT is -X and her LEFT is +X (a CFrame looking down +Z has
-- RightVector -X). So a LEFT-TO-RIGHT pass travels from +X to -X, and `"LtoR"` means exactly that.
-- A lateral wave comes south to `WAVE.lateralDz` first, walks ACROSS her front for
-- `WAVE.lateralSpan` studs, and only then is pushed over the road -- which is the broadside shot she
-- asked for. It is a beater POSITION, not a new behaviour: see `ForestTest.beaterPosition`.
--
-- `composition` IS AN INDEX INTO `Boar.CONFIG.SOUNDER.COMPOSITIONS`, because who is in a flock is
-- the boar system's fact and which flock comes next is the drive's.
-- THE REPORTING WINDOW, AND NOTHING ELSE (task 124). This world has no drive to end, so it is given
-- one -- but it moves no animal and resets no schedule. "The next drive starts" here means exactly
-- one thing: the report's window rolls over. The wave cycle, the active waves, the boars on the ground
-- and the hunter's stand are all untouched, because resetting them would change the push rhythm Karen
-- accepted in task 123 and nothing asked for that.
--
-- 300 seconds is the Director's number: about fifteen waves at the 20 s interval.
-- ------------------------------------------------- THE RED STAG'S RUT ROAR (task 251 part 2)
--
-- KAREN, 2026-10-23, verbatim: *"we need better saound and behaviour for red stag"*, and her "ok" to
-- the plan (`<runs-dir>/design/driveflow-spec.md` section 4). October is the peak of the red deer rut
-- and the stag's rut call is *"very similar to the bellow of a bull"*, *"a regular feature of dawn
-- and dusk"* (countydeerstalking.co.uk, "Deer Vocalisations"; the same source task 240's whole deer
-- voice table is built on). So in a drive that carries a stag you hear him ROARING IN THE DISTANCE
-- before you ever see him, from his own holding in the far wood.
--
-- WHY IT LIVES HERE AND NOT IN `Boar.CONFIG.SOUND.VOICE` -- rule 3, and the spec says it in as many
-- words: *"it is an AMBIENCE cue, not an animal's voice"*. A voice comes out of an animal somebody
-- can see, is parented to that animal's trunk, dies with it and is rationed against
-- `SOUND.CROWD.MAX_SQUEALS`. THIS SOUNDS BEFORE THE STAG EXISTS: he is released at slot 13, t 166 s,
-- and the roar is wanted in the first 90. It is a fact about the WOOD this drive is happening in --
-- which is this module's -- and a 5-second roar booking one of the world's two squeal slots would
-- have silenced a dying boar to play it. **It is its own emitter with its own single slot**, exactly
-- as the spec asks: `ForestTest.stepRoar` is the one writer and there is one Sound in the world.
--
-- IT IS THE REAL ANIMAL NOW (task 254), AND THE LIBRARY BULLS ARE THE REVERT PATH. Task 251 part 2
-- shipped the spec's option A -- four Roblox-library BULL BELLOWS, because there is no deer in that
-- library and that was measured twice (task 240's note, and again on 2026-10-23: thirteen keywords,
-- 95 rows from the three creators whose audio plays in anybody's experience, not one named deer or
-- elk) and because the literature's own sentence is that a stag's rut call is *"very similar to the
-- bellow of a bull"*. Option A's price was written down at the time: *"when it lands it is this one
-- `ids` row, changed"*. It has landed.
--
-- `122287696922128`, *"Driven Hunt red stag rut roar"* -- **Freesound 653532, "Deer rut - Brame
-- Cerf" by L.Finck, CC0** (verified on its page 2026-10-24; section 2 of
-- `docs/research/2026-10-24-stag-voice-and-the-drive-s-length.md` is the licence audit, and CC0 is
-- the only one of the five licences there that survives Roblox's *"fully sublicensable and
-- transferable"* grant). The Director uploaded it on 2026-10-24 under Karen's standing OK for free
-- CC0 recordings; `assets/uploads.json` carries the row, the sha256 and the OK, and `CREDITS.md`
-- carries the provenance.
--
-- **ITS MODERATION STATE WAS RE-READ LIVE AND IT IS `Approved`.** The upload's own manifest row said
-- `Reviewing`, which is what the operation answered while the asset was still in the queue and is
-- not a verdict -- so the state in `assets/uploads.json` is a second, later
-- `GET /assets/v1/assets/122287696922128`, and the row says so. A stale status string is how a
-- rejected asset ships as an approved one.
--
-- IT IS 52.897 SECONDS OF A RUT, SO IT PLAYS BY REGION AND NEVER WHOLE. `clips` carries the three
-- roars worth hearing, MEASURED off the uploaded bytes (`soundfile` decoded the same sha256 the
-- manifest row names: 48 kHz stereo, 52.8965 s, against the `TimeLength = 52.897` Roblox answers for
-- the asset -- the same timeline, which is what makes an offline cut legal) as a 50 ms RMS envelope
-- smoothed with a 200 ms running max and gated 6 dB over the recording's own forest floor of -45.2
-- dBFS. Seven events stand out of it; three are a single clean roar of the right length with silence
-- at both ends, and the other four are either a sequence (22.6-29.4 s, 6.9 s long) or 4-9 dB down
-- and choppy.
--
-- WHAT IS PROVED AND WHAT IS NOT (rule 8): that the id loads, that its `TimeLength` is the
-- recording's, that `PlaybackRegion` is honoured TO THE SAMPLE and that each region is LOUD is
-- measured in a live Play session -- `ContentProvider:PreloadAsync`, then `IsLoaded`, `TimeLength`,
-- `TimePosition` read back inside the region and `PlaybackLoudness` peaked across it.
-- `PlaybackLoudness` answers 0 in Edit at every volume, which is how a region that plays nothing
-- passes a bench test. **NOBODY HERE CAN HEAR IT.** Whether a real stag at these three regions, at
-- this level, heard at the 372 studs the live run measured, reads as a stag roaring across a valley
-- is KAREN'S EARS, and it is the one thing this row cannot claim.
ForestTest.ROAR = {
	enabled = true,
	-- THE REAL STAG FIRST, then the four library bulls, longest first. `ForestTest.roarClip` is what
	-- reads this: it sounds `ids[1]` whenever `clips` has a usable entry for it, and the four below
	-- are reached only when it does not -- which is the revert path, BY DELETION, and is exactly what
	-- task 251 part 2 shipped (a uniform pick over the ids at `pitch` 1.15 and no region). The
	-- lengths are the live run's, because an id's length is a fact about the asset and not a dial.
	ids = {
		122287696922128, -- THE REAL RED STAG (task 254), 52.897 s of a rut -- played BY REGION
		9113626902, -- "Bull Bellows 13" -- "Anxious Cries, Slowed", the longest of all (6.17 s)
		9113625767, -- "Bull Bellows 3" -- "Isolated Roars, Complaining, Uneasy" (4.45 s)
		9119634882, -- "Steer Bellows 1" -- "Cry, Groaning", a held note rather than a cry (3.99 s)
		9113629096, -- "Bull Bellows 4" -- "Isolated Roars, Anxious, Panicked" (3.62 s)
	},
	-- WHAT TO PLAY *OF* AN ID THAT IS LONGER THAN A CUE, keyed by the id so a reader looking at `ids`
	-- finds it. One entry today, and an id with no entry plays whole -- which is every library clip.
	clips = {
		[122287696922128] = {
			-- EACH REGION IS ONE ROAR WITH SILENCE AT BOTH ENDS, in seconds of the recording, and
			-- `roarClip` picks one at random per cue so that five cues in a 90-second window are not
			-- one sample five times. `from`/`to` go straight into `Sound.PlaybackRegion` (with
			-- `PlaybackRegionsEnabled`), which the live run proved is honoured to the sample:
			-- `timePos=0.20..5.20` for the first of them.
			--
			-- `gain` MULTIPLIES `volume`, AND IT IS A MEASUREMENT AND NOT A TASTE. A field recording
			-- is not a production sample: at `Volume = 1` on a client these three peaked
			-- `PlaybackLoudness` 98, 54 and 50, where the four bulls this cue ships today peak 94,
			-- 115, 161 and 198 -- mean **142**. So two of the three roars are 8-9 dB under the voice
			-- Karen has already heard, and at `audibleStuds` 420 with `InverseTapered` roll-off that
			-- is the difference between a roar and nothing at all. `gain` is 142 divided by each
			-- one's own peak, which equalises the three to each other AND to what ships today: the
			-- ONE thing this task changes is WHICH ANIMAL it is, not how loud the cue is. (The means
			-- say the same: 28, 15 and 13 against the bulls' 39.5 give 1.41, 2.63 and 3.04, within
			-- 7 % of these. The peaks are used because they keep every effective volume at or under
			-- 1.0.)
			regions = {
				{ from = 0.2, to = 5.2, gain = 1.45 }, -- peak -24.4 dBFS, 20.8 dB over the floor
				{ from = 9.45, to = 14.45, gain = 2.63 }, -- peak -28.2 dBFS, 17.0 dB over
				{ from = 35.6, to = 40.6, gain = 2.84 }, -- peak -28.5 dBFS, 16.7 dB over
			},
			-- NO PITCH SHIFT: THIS ONE IS THE ANIMAL. The 1.15 below exists because a bull is three
			-- times a stag's weight; applying it to a real stag would make him a smaller deer than
			-- he is.
			pitch = 1,
			-- A SHORT FADE AT BOTH ENDS, because a cut into the middle of a 48 kHz field recording
			-- clicks. 0.35 s FITS INSIDE THE QUIET MARGIN OF EVERY REGION, AND THAT IS MEASURED: the
			-- roar itself starts 0.60, 0.65 and 0.80 s after its region does and ends 0.60, 0.65 and
			-- 1.75 s before it, so neither fade ever touches the bellow -- it only shapes the forest
			-- noise the region opens and closes on.
			fadeSeconds = 0.35,
		},
	},
	-- A BULL IS THREE TIMES A STAG'S WEIGHT, so his bellow goes UP for a stag. The same 1.15 the
	-- stag's own `VOICE` row carries (task 240), and for the same reason -- one animal, one pitch.
	pitch = 1.15,
	-- NO CUT. The spec's cue table says so in the column: *"none -- a distant roar must be long"*.
	-- Every other deer cue is cut to 1.05 s because it books a voice slot; this books nothing.
	--
	-- QUIET AND FAR, which is the whole of "in the distance", and `nearStuds` 90 is the plateau:
	-- `InverseTapered` falls as `near / distance`, so a high plateau is what gives a long tail rather
	-- than a loud middle. 0.35 against the voice's 0.9.
	--
	-- 350 -> 420, AND IT IS A MEASUREMENT AND NOT A PREFERENCE. The spec's cue table says *"heard at
	-- 350 studs"*, and the FIRST live drive of this task printed the number that makes 350 wrong:
	-- `ROAR 1: the stag answers from the far wood, 401 studs from the stand, audible to 350`. His
	-- holding is slot 13's own (`northStuds` 330, `offsetX` -95), which is sqrt(330^2 + 95^2) = **343
	-- studs** from the stand before `deeperStuds` is added at all -- so the spec's range was set
	-- without the geometry of the row it was for, and at 350 Karen would have heard **nothing**,
	-- four times a drive, with a console line each time claiming she had.
	--
	-- 420 IS 343 PLUS 77 STUDS OF MARGIN, which is what the stand being 150 studs from its
	-- neighbour costs: she locks one of nine (`PICK.defaultIndex` 5 is only the default), and
	-- `wavePoint` puts the row relative to the stand she took, so his bearing moves with her and the
	-- distance does not. It is now the longest-carrying sound in this world -- past the hand horn's
	-- 357 -- which is right for the one cue that is meant to come from somewhere she cannot see.
	volume = 0.35,
	nearStuds = 90,
	audibleStuds = 420,
	-- WHEN. The spec: *"t 0-90 s of a drive that carries a stag; then once at his release"*. 20 s
	-- apart is **five** roars in the window -- 8, 28, 48, 68 and 88 s -- which is a stag answering
	-- himself across a wood rather than a loop; the first is 8 s in, after the opening signal's own
	-- fanfare. Five is what `forest_line.spec` computes off these three numbers rather than reading
	-- it here, and it is what both live drives printed (`ROAR 1` .. `ROAR 5`). (Review round 2's note:
	-- this said "four", which was the figure before `firstAtSeconds` was set to 8.)
	windowSeconds = 90,
	firstAtSeconds = 8,
	everySeconds = 20,
	-- HOW FAR BEHIND HIS OWN HOLDING he roars from, in studs north of it. He has not moved yet -- the
	-- script holds him at `northStuds` 330 until slot 13 -- and a roar from exactly his spawn point
	-- would give his position away to the second.
	--
	-- 60 -> 30, FOR THE REASON `audibleStuds` MOVED: at 60 the measured distance from the stand was
	-- **401 studs** and the whole cue was out of earshot. It is kept rather than zeroed because the
	-- reason for it is still good -- a roar from exactly the spawn point is a map pin -- and 30 studs
	-- is still a hundred feet of wood, which no hunter can resolve at 350.
	deeperStuds = 30,
	-- The instance's name in Workspace, so a reader looking for it can find it.
	partName = "StagRoar",
}

ForestTest.DRIVE = { seconds = 300 }

-- ONE SIDE TO THE OTHER, IN A LINE (task 127). Karen, 2026-10-05: *"imagine they have to go from one
-- side to another / crossing roud with one line could be 2 i line ect how in real life ... imagine
-- they come from one side in one line and crossing road thats it"* -- and, about the whole thing,
-- *"it's simple"*.
--
-- THIS REPLACES THE WAVE BEHAVIOUR AND DOES NOT DELETE IT. With `enabled = false` the world does
-- exactly what tasks 122, 123 and 126 left it doing -- pushes, turn-backs, lateral passes, phantom
-- beaters -- and every one of those code paths is still there and still tested. One word switches
-- between them, because Karen has accepted parts of the old behaviour before and may want them back.
ForestTest.LINE = {
	enabled = true,

	-- HOW MANY LINES. *"could be 2 i line"* -- the Director's figure: about a quarter of waves come
	-- as two parallel lines, the rest as one.
	twoLineChance = 0.25,
	-- Two leaders this far apart across the direction of travel. 5 studs is a body's width plus a
	-- gap: close enough to read as one group, far enough that the two files do not merge.
	lineGapStuds = 5,

	-- NOSE TO TAIL IS 3 STUDS, AND THE STATION SPACING IS THEREFORE 8.5, because a boar is 5.5 studs
	-- long (`Boar.CONFIG.BODY_SIZE.Z`). The Director's figure is the GAP a hunter sees; this number is
	-- centre to centre, and the two are a body apart.
	--
	-- MEASURED, AND THE FIRST VERSION HAD IT WRONG. With `spacingStuds = 3` as a centre-to-centre
	-- station, eight 5.5-stud bodies were asked to stand 3 studs apart -- so they overlapped by 2.5
	-- studs each and the physics solver spent every frame shoving them out of one another. The line
	-- never settled: nose-to-nose gaps came out at a 9.9-stud median with a p90 of 176, 29 trunk
	-- contacts and 23 animals that moved less than a stud in three seconds. None of that was the
	-- following rule; all of it was eight animals standing inside each other.
	-- 8.5 STAYS, AND TASK 136 TRIED 6.5 AND MEASURED IT WORSE. The Director asked for "body length
	-- + ~1 stud, try ~6.5 if 8.5 still reads loose", which is the right instinct -- a boar is 5.5
	-- studs long, so 6.5 centre to centre is a one-stud nose-to-tail gap and 8.5 is three.
	--
	-- WHAT IT ACTUALLY DID, over 150 s of two-line waves, measured on the APPROACH AND THE CROSSING
	-- (the half of the trace north of the road, which is the half a hunter watches):
	--
	--                   offset median   p75           p90           gap median
	--   8.5 (this)        0.23 / 0.42   0.65 / 1.72   1.89 / 4.27   8.79 / 9.15
	--   6.5               0.77          1.97          4.02          7.39
	--
	-- BOTH RUNS OF 8.5 ARE CARRIED, AND THEY HAVE TO BE (round 2, the Reviewer's note -- round 1's
	-- comment quoted the better one as fact). They are the same build 150 s apart and they disagree
	-- by more than the difference being measured. So the honest reading is NOT "8.5 is twice as
	-- tight": it is that 6.5 closes the gap by a stud and a half, nothing here says the file gets
	-- laterally tighter for it, and one of the two 8.5 runs says it gets looser. 8.5 stays because it
	-- is the incumbent and 6.5 did not earn the change -- not because 6.5 was shown to be worse.
	-- Settling it needs a longer trace or a per-wave statistic; this was neither.
	spacingStuds = 8.5,
	-- HOW CLOSE A FOLLOWER MAY AIM TO THE ONE IN FRONT, measured along the trail: just short of its
	-- tail, which is what "no follower ever ahead of the one in front" means when the thing being
	-- regulated is an arc length.
	--
	-- IT WAS A BODY LENGTH FIRST, AND THAT BROKE THE LINE. An animal standing exactly where it
	-- belongs has the one ahead a station along, so with the 6.5-stud station this task was trying at
	-- the time, a 5.5-stud margin handed it a point 1.0 stud in front of its own nose -- inside `Boar.CONFIG.LINE.ARRIVE_STUDS`, which is 1.0. The Brain
	-- quite correctly answered "arrived", the animal stopped, the file walked on and the gap opened:
	-- MEASURED at 58 stuck and 18.2 % breaks against 15 and 9.0 % before the change. It is the same
	-- trap task 127 round 3 dug itself with `aim = min(ownS + lookahead, stationS)`, in a new place.
	--
	-- 1.5 studs bites only when a follower has closed to within a body length of the one ahead, which
	-- is the case it is for; the floor below (`minAimStuds`) makes sure it can never bite into a
	-- point the animal is already standing on.
	noOvertakeStuds = 1.5,
	-- A FOLLOWER IS NEVER AIMED AT A POINT UNDER ITS OWN FEET. Above
	-- `Boar.CONFIG.LINE.ARRIVE_STUDS` (1.0) by
	-- enough that an order is always a direction; the SPEED is what holds a closed-up animal back,
	-- which is `Line.followerSpeed`'s job and not the aim's.
	minAimStuds = 2.5,
	-- HOW LONG A WEDGED LEADER IS LEFT TO FREE HERSELF (task 136).
	--
	-- THE ASYMMETRY WAS THE BUG, AND IT COST A WHOLE FILE AT A TIME. A wedged FOLLOWER is put back on
	-- the trail -- a few studs onto ground the leader has already walked. A wedged LEADER was handed
	-- another route, computed from the position she is wedged IN, through the trunk she is wedged
	-- AGAINST; if the pathfinder answered the same way, she stayed there. MEASURED in a 150 s trace:
	-- `Boar6` sat at one point 17 studs north of the road for 110 SECONDS with an ordered speed of
	-- 24, and the stuck detector counted it every three seconds -- 464 of the run's stuck reports
	-- were a handful of animals doing exactly that, and the file behind each of them never crossed.
	--
	-- SO SHE IS LET GO OF, BRIEFLY. An ordered animal runs no whiskers and no wedge recovery, by
	-- design (task 127: the route was already checked for trunks). Dropping the order for a moment
	-- hands her back to `Brain`'s own machinery -- `steerAroundTrunk` and the `stuckTurn` sidestep,
	-- both of which are gated on `not ordered` and both of which exist to get an animal off a trunk.
	-- The drive takes her back when the window closes. Nothing new is invented here; a thing that was
	-- switched off for a good reason is switched on again for the one case that reason does not cover.
	leaderFreeSeconds = 1.5,
	-- HOW FAR ALONG THE TRAIL `Line.arcAt` will look for an animal, given where it was last step.
	-- Generous against one step of a running boar (RUN_SPEED is ~24 studs/s and the drive steps on
	-- Heartbeat), and far tighter than the length of a doubled-back loop round a trunk, which is
	-- what it exists to refuse.
	arcWindowStuds = 14,
	-- How far the leader walks between breadcrumbs. 1 stud is a third of the spacing, so a follower's
	-- station is interpolated between crumbs that are always close together.
	crumbStuds = 1,
	-- Inside this of its station a follower just matches the leader's speed; outside it, it closes at
	-- +-`catchup`. +-20 % is the Director's clamp: a line that closes gently instead of concertinaing.
	stationToleranceStuds = 1.5,
	-- +-40 % (the Director's round-2 figure, up from 20): a follower that has fallen behind has to be
	-- able to close faster than the line walks, or the gap is permanent.
	catchup = 0.4,
	-- HOW FAR ALONG THE TRAIL a follower aims each step. Short, because it is a straight-line order
	-- and the only guarantee is that the leader walked this bit: 4 studs is under a body length, so
	-- the chord it cuts is never wide enough to leave her path.
	lookaheadStuds = 4,
	-- THE SOW WAITS. Past this much arc-length lag on the LAST animal she eases toward `tailSlow` of
	-- her pace. 12 studs is about one and a half stations -- a gap a hunter would notice.
	tailPatienceStuds = 12,
	tailSlow = 0.45,

	-- THE PACE OF A WAVE, drawn once when it is released. *"then trot sometimes walk sometimes run"*
	-- -- so a trot is the common case and the other two are the variation. Weights, not percentages,
	-- so adding a fourth is one row.
	-- A CALM WAVE WALKS OR TROTS, AND NEVER RUNS (task 139 round 3). Karen, 2026-10-09: *"when no
	-- shoot not moving they come to road cal trot when spooked run and same when beater close"*.
	--
	-- `run` WAS A FIFTH OF ALL WAVES, drawn before anything had happened, so a hunter at a stand
	-- regularly watched a line come out of the trees at a flat gallop with nothing chasing it. A run
	-- is a REACTION in this world and it still happens: a shot inside `SENSE.SHOT_AUDIBLE_STUDS`, a
	-- beater inside the flush radius, or a hit -- all three reach `Brain:spook` and all three
	-- override the wave's pace. What this mix decides is only the pace of a wave that nothing has
	-- happened to yet, and the answer to that is a trot.
	paceMix = {
		{ pace = "walk", weight = 30 },
		{ pace = "trot", weight = 70 },
	},

	-- WHERE A LINE STARTS: this far north of the road, in the trees on the drive side.
	spawnNorthStuds = 180,
	-- ...and how far east or west of the hunter's own stand it crosses. Task 123 round 8's close/far
	-- choice, kept: some waves cross in front of her and some give her a longer shot.
	crossOffsets = { -70, -35, 20, 55, 95 },
	-- The line is spawned pointing at its crossing point, so the first thing a hunter sees is a file
	-- already aimed at the road rather than a group turning round.
	spawnSpreadStuds = 3,

	-- STUCK IS ZERO, AND THIS IS HOW IT IS CAUGHT. Karen: *"also I saw that some boars stuck in
	-- tree"*. An animal that has moved less than a stud in three seconds while it was asked to move
	-- is re-pathed (a leader) or snapped back onto the trail (a follower), and every occurrence is
	-- counted so "zero" is a number in the report rather than a hope.
	-- AND IT ONLY COUNTS WHILE THE ANIMAL WAS ASKED TO MOVE (task 127 round 2): a follower that has
	-- overrun its station is told to stand still on purpose, and standing still on purpose is not
	-- being stuck. 2 studs/s is below every gait this world uses and above the float noise of a
	-- speed that is meant to be zero.
	-- HOW CLOSE TO THE ROAD THE LEADER IS OFFERED HER LOOK (task 126 round 2). Karen: *"they can stop
	-- before entering the road"*. 45 studs is about two seconds at a trot, so the stop happens in the
	-- open where a hunter can see it rather than on the gravel; the Brain decides whether she takes
	-- it at all (`MOVE.EDGE_CHANCE`) and refuses outright if she is already frightened.
	checkWithinStuds = 45,
	-- WHERE THE DRIVE IS, FOR AN ANIMAL THAT HAS JUST CROSSED (task 139 round 3). Karen: *"and they
	-- run away when cross the road"*. `ForestTest.stepLines` spooks the member it is dropping and
	-- has to say what from; this is how far NORTH of it that is, so the Brain's one latched heading
	-- points south at `field.exitZ` and not back over the road. 40 studs is the width of the push
	-- behind a crossing line -- far enough to be the drive and not the animal's own shadow.
	runAwayFromStuds = 40,
	stuckAskedSpeed = 2,
	stuckSeconds = 3,
	stuckStuds = 1,

	-- How long a line lives before the drive gives up on it, whatever it is doing. A route of about
	-- 600 studs at a walk (4.5) is 130 s; this is the ceiling that stops a wedged wave living for ever.
	maxSeconds = 150,
}

-- ---------------------------------------------------------------- the wood is already full (154)
--
-- KAREN, 2026-10-11, on her first beater playtest: *"didn;t see any animals probably need to wait
-- 10s ?"* and then *"so animals already there somewhere in bushes close to trees ect"*.
--
-- SHE WAS RIGHT ABOUT THE WAIT AND THE DIRECTOR MEASURED IT: a wave is released every
-- `SCHEDULE.intervalSeconds` (20 s), and a beater put down `BEATER.behindLineStuds` behind the
-- line's own spawn walked the 240 studs to the road in about sixteen seconds at 15.7 studs/s -- so
-- she arrived BEFORE THE FIRST WAVE EXISTED and the wood she walked through was empty. (That 240 is
-- 580 since task 162 and the arithmetic is 37 s, which does not change the finding: a timer is
-- still the wrong shape for somebody who walks at the animals.)
--
-- A TIMER IS THE WRONG SHAPE FOR A BEATER, which is why this is not "release the first wave
-- sooner". A hunter stands still and the drive comes to him, so a schedule is exactly right for
-- him; a beater WALKS AT animals that are already lying up, and what she is testing is the moment
-- she finds them. So in beater mode there is no schedule at all: the wood is STOCKED when she
-- starts, and -- since task 172 -- never re-stocked: a wood is beaten once, and the re-stock was the
-- last way an animal could appear behind the line (see the end of `REST`). `ForestTest.stepRest` is
-- the whole of it.
--
-- THEY ARE RESTING, AND THAT IS NOTHING NEW EITHER. A sounder spawned and not ordered is an IDLE
-- sounder, and `CALM.ENABLED` -- on in this world -- is already the graze/stand/lie repertoire
-- (task 117). This file adds no behaviour; it only says where to put them.
ForestTest.REST = {
	-- WHERE A GROUP MAY BE PUT, as the band between her and the road. She starts at
	-- `LINE.spawnNorthStuds + BEATER.behindLineStuds` = 580 studs north of it, so a group inside this
	-- band is in front of her and short of the road -- which is both "between her and the road" and
	-- far enough from the verge that a hunter at a stand is not looking at a boar standing still.
	--
	-- (TASK 162's VERSION OF THIS PARAGRAPH IS HISTORY NOW, and it is kept as history rather than
	-- deleted: the band was 40-460 then, derived the same way from the one reach there was --
	-- `behindLineStuds 400 + spawnNorthStuds 180 - (SPOOK.BEATER_STUDS 89 + clearOfStartStuds 30)` =
	-- 461, taken down to 460. Task 172 split the reach in two and the derivation follows the NOTICE
	-- one, below.)
	nearRoadStuds = 40,
	-- 425, AND IT IS STILL DERIVED (task 172 moved it from 460). The band's far edge is as deep as
	-- the keep-away below allows, and the keep-away is now the NOTICE reach rather than the flush
	-- reach, because noticing is the first thing that happens to a group and a group that notices her
	-- before she has taken a step is the same defect task 162 measured in its flush form:
	--
	--   behindLineStuds 400 + spawnNorthStuds 180 - (SPOOK.NOTICE_STUDS 125 + clearOfStartStuds 30)
	--     = 425
	--
	-- `forest_stand.spec` asserts the relation, so the number cannot drift away from the reach.
	farRoadStuds = 425,

	-- ...AND NOT ALREADY INSIDE HER REACH. MEASURED, task 154's first run: the group nominally at
	-- `offsetX +45, northStuds 185` is sqrt(45^2 + 55^2) = 71 studs from where a beater is put down,
	-- which was inside the one reach there was then -- so it was latched and gone on the first
	-- heartbeat, before she had taken a step. A wood she has already emptied by standing in it is not
	-- a wood. One reach plus 30 studs is far enough that the nearest group is a walk away.
	clearOfStartStuds = 30,

	-- CLOSE TO A TRUNK, AND NOT INSIDE ONE. Karen: *"somewhere in bushes close to trees ect"*. A
	-- spot is taken when the nearest SOLID thing is at least `clearStuds` away (nothing is spawned
	-- inside a trunk) and at most `nearTrunkStuds` away (it is a spot in the trees and not out in
	-- the open). `roomToStand`'s own header is why "solid" is the test and a fern is not.
	clearStuds = 8,
	nearTrunkStuds = 22,

	-- ...AND ON THE GROUND. `Runtime:spawn` places every member at `world.groundAt`, which raycasts
	-- past `OurForest`/`Foliage` but NOT past the two `Session` folders of 831 more trees (task 153
	-- measured them) -- so that ray can stop on a canopy and drop a sounder out of a tree. A spot is
	-- refused when the terrain's own answer and that one disagree by more than this.
	canopySlackStuds = 6,

	-- ---------------------------------------------------------------- SEEN FROM THE LANE (task 172)
	--
	-- KAREN, 2026-10-13 ~09:20: *"beaters has to see more animals when walking ... I want to see them
	-- more"*. Two of the three answers to that are in this block; the third is the staged reaction in
	-- `SPOOK` above.
	--
	-- A SPOT IS PREFERRED WHEN THE LANE CAN SEE IT. `ForestTest.restSeenFromLane` casts one ray from
	-- the walking line -- the group's own lane, `sightFromStuds` short of it, at a walking man's eye
	-- height -- to the spot, and a spot with a trunk in the way is tried later than one without. It
	-- is a PREFERENCE and not a rule: the search's second pass drops it, because a wood where every
	-- legal spot happens to be screened is a wood with no animals in it, which is worse than a wood
	-- with one animal behind a tree.
	sightEyeStuds = 3.5, -- a standing man's eyes above the ground he is on
	sightTargetStuds = 2, -- ...and the animal's shoulder, not its feet
	sightFromStuds = 45, -- how far short of the group the look is taken from: inside the notice band
	-- ...AND HOW FAR OFF HIS LANE A GROUP MAY BE AT ALL. Every row below is within 24 studs of its
	-- own lane, and this is the ceiling that keeps it that way -- 40 studs is 11 m, about three
	-- lengths of the animal, so a group is beside the lane rather than somewhere in the wood.
	laneSideStuds = 40,

	-- How a spot is looked for: the nominal point first, then rings of eight around it. Deterministic
	-- on purpose -- the same wood gives the same answer twice, so a trace can be repeated.
	searchRings = 4,
	searchStepStuds = 16,

	-- The ring `spawnSounder` may spread a group over; the same 90 the wave path passes, and for the
	-- same reason (a sounder of 9 needs room not to spawn inside itself).
	spreadStuds = 90,

	-- ---------------------------------------------------------------- AND IT IS NEVER RE-STOCKED
	--
	-- KAREN, 2026-10-13 ~09:25, verbatim: *"and again no boar behing comming after beater walk"* --
	-- after task 168 had already made the line sweep what it passes.
	--
	-- THE RE-STOCK WAS THE ONE SOURCE 168 LEFT, AND 168 MEASURED IT ITSELF: *"7 animals of 25
	-- appeared up to 31 studs behind the front; the sweep caught them on the next tick and they ran
	-- out, but a group that has to be swept the instant it exists is a group Karen saw come from
	-- behind"*. The reason is geometric and no search can fix it: this band is measured from the
	-- ROAD, and fifteen seconds after the wood is empty the line is deep inside the band -- so the
	-- deep rows have nowhere left to go that is in front of anybody.
	--
	-- SO THE WOOD IS STOCKED ONCE AND STAYS AS SHE LEAVES IT, which is the dispatch's own words
	-- (*"no re-stock or spawn behind the line at all -- if the wood empties, it stays empty for this
	-- drive"*) and is also what a drive IS: a wood is beaten once. `restockSeconds` is gone with the
	-- behaviour it timed; `ForestTest.stepRest` now stocks on the first heartbeat of beater mode and
	-- never again, and `state.restStocked` is the latch that says so. The old row and the branch it
	-- timed are archived in `backups/2026-10-13_task-172_rest-restock.md`, with the reason, as rule 7
	-- asks.
	--
	-- ONCE PER **DRIVE**, NOT ONCE PER SESSION (round 2, finding 1, which was right). The latch lives
	-- in `ForestTest`'s state and is cleared by `ForestTest.newDrive()`, which the boot calls on the
	-- `Assigning` edge -- the same edge it already opens a report window on. Without that the wood was
	-- stocked once per SERVER: a beater who cleared it in drive 1 walked 580 studs of empty wood in
	-- every drive after it, which is task 154's founding defect in a new form, and the behaviour that
	-- used to cover the boundary (the 15-second re-stock) is the one this task archived.

	-- HOW OFTEN THE STOCK MAY BE RE-TRIED while it has not succeeded. The attempt is level-triggered,
	-- and at the instant a drive begins the PREVIOUS drive's beaters can still be standing at the
	-- ROAD -- so every candidate is behind the front, nothing is placed, and a latch set on the
	-- ATTEMPT would lose that whole drive's wood. The latch is set when something is actually PLACED;
	-- until then it is tried again, at most this often, so a wood that cannot be stocked costs one
	-- search every two seconds instead of one per heartbeat.
	stockRetrySeconds = 2,

	-- THE GROUPS, SPREAD ALONG THE LANES (task 172). `composition` indexes
	-- `Boar.CONFIG.SOUNDER.COMPOSITIONS` for the same reason the schedule does: who is in a flock is
	-- the boar system's fact and where they are lying up is this world's. `offsetX` is relative to the
	-- stand the drive aims at -- which is the x the line is walking at -- and `laneOffset` says WHICH
	-- lane of the line this group belongs to (`ForestTest.beaterLaneOffset` deals out 0, +150, -150,
	-- +300, -300), so a spot can be judged by what that lane will see of it.
	--
	-- 36 ANIMALS IN TEN GROUPS, up from 28 in six. Karen: *"make them a lot not too much to break
	-- but enough to test"* and now *"I want to see them more"*. `MAX_BOARS` is 60 and a measured
	-- session has carried 32 at once in this place, so 36 is more wood than she has played and inside
	-- what the place has shown it can hold.
	--
	-- FOUR OF THE TEN ARE ON HER OWN LANE (`laneOffset = 0`, which is always the real beater's --
	-- `beaterLaneOffset` gives index 1 the middle), 110 studs apart down the whole 355-stud depth of
	-- the walk, so she meets a group about every twenty-five seconds at a beater's pace. The other
	-- six are on the two lanes either side of her, within 24 studs of them, so the bot beaters' walks
	-- produce encounters she can see across the front instead of an empty wood on both sides.
	--
	-- AND NEVER TWO AT ONCE, which is what the depths and the offsets are spaced for: the flush reach
	-- is `SPOOK.BEATER_STUDS` (71) and the fright LATCHES, so two groups inside 71 studs of each other
	-- both bolt on one approach. MEASURED over all 45 pairs in the world frame -- which is not the
	-- same as the depth difference, because the road is a sine and `restPoint` adds `roadZ(x)`: the
	-- closest pair is 101.3 studs (rows 1 and 2, both on her lane), which clears the reach by 30.
	-- `forest_stand.spec` asserts no pair is inside the reach with the ring search's own margin.
	groups = {
		{
			offsetX = -18,
			laneOffset = 0,
			northStuds = 415,
			composition = 6,
			note = "a lone big male, the first thing she meets",
		},
		{
			offsetX = 22,
			laneOffset = 0,
			northStuds = 305,
			composition = 5,
			note = "a sow and her young, deep on her lane",
		},
		{
			offsetX = -20,
			laneOffset = 0,
			northStuds = 195,
			composition = 2,
			note = "two males, half way down her lane",
		},
		{
			offsetX = 24,
			laneOffset = 0,
			northStuds = 85,
			composition = 1,
			note = "a mixed flock on her lane, close to the road",
		},
		{
			offsetX = 132,
			laneOffset = 150,
			northStuds = 370,
			composition = 2,
			note = "two males, deep on the east lane",
		},
		{ offsetX = 168, laneOffset = 150, northStuds = 230, composition = 5, note = "a sow and her young, east" },
		{
			offsetX = 140,
			laneOffset = 150,
			northStuds = 90,
			composition = 6,
			note = "a lone male, east and close to the road",
		},
		{
			offsetX = -168,
			laneOffset = -150,
			northStuds = 340,
			composition = 6,
			note = "a lone male, deep on the west lane",
		},
		{ offsetX = -132, laneOffset = -150, northStuds = 200, composition = 2, note = "two males, west" },
		{
			offsetX = -162,
			laneOffset = -150,
			northStuds = 60,
			composition = 5,
			note = "a sow and her young, west and close to the road",
		},
	},
}

-- WHAT THE WOOD'S ONE STOCK SHOULD DO ON THIS TICK (task 172 round 3). PURE, in the three facts it
-- depends on -- has this drive been stocked, when was it last tried, and what time is it -- so the
-- whole rule can be asserted from hand-written numbers instead of needing a live runtime.
--
-- IT EXISTS BECAUSE THE RULE WAS UNREACHABLE (round 3's finding, which was right). `stepRest`'s first
-- line is `if state.runtime == nil then return nil end`, and no spec starts the Forest Test's
-- runtime -- so a case that called `stepRest` returned before any of this and could not fail. The
-- same division `wavesToPush` was given for the same reason: the decision here, the effect there.
--
-- THREE ANSWERS:
--   "done"   the wood has been stocked for this drive. It is NOT re-stocked inside one (Karen,
--            2026-10-13: *"and again no boar behing comming after beater walk"*); the latch is
--            cleared by `ForestTest.newDrive()` at the drive boundary and nowhere else.
--   "wait"   a stock was tried this recently and did not take. At the instant a drive begins the
--            PREVIOUS drive's beaters can still be standing at the road, so every candidate is
--            behind the front and nothing can be placed; the search is 41 candidates' worth of
--            raycasts per group, so it is re-tried on a clock rather than every heartbeat.
--   "stock"  try now.
function ForestTest.stockStep(stocked: boolean, triedAt: number?, now: number, rest): string
	if stocked then
		return "done"
	end
	local resolved = rest or ForestTest.REST
	if triedAt ~= nil and now - triedAt < (resolved.stockRetrySeconds or 0) then
		return "wait"
	end
	return "stock"
end

-- WHERE A RESTING GROUP IS NOMINALLY PUT, before the ground and the trunks are measured. PURE, the
-- same division `wavePoint` has: the arithmetic here, the world's own answer in
-- `ForestTest.restSpot`.
function ForestTest.restPoint(standX: number, spec, sideOffset: number?, outOffset: number?, layout: Layout?): Vector3
	local resolved = layout or ForestTest.ROAD_LAYOUT
	local x = standX + (spec.offsetX or 0) + (sideOffset or 0)
	local north = (spec.northStuds or 120) + (outOffset or 0)
	return Vector3.new(x, resolved.centre.Y, ForestTest.roadZ(x, resolved) + north)
end

-- WHERE A BEATER IS STANDING WHEN HE OUGHT TO SEE THIS GROUP (task 172). PURE: the point on the
-- group's own lane, `sightFromStuds` short of it along the walk, at the ground's z for that x -- the
-- same division `restPoint` has, arithmetic here and the raycast in `ForestTest.restSeenFromLane`.
--
-- `sightFromStuds` IS INSIDE THE NOTICE BAND ON PURPOSE (45 studs against 125): the question this
-- point asks is not "can he see it from anywhere" but "can he see it from where he will be standing
-- when it puts its head up", and the answer has to be taken from inside the band or it is about a
-- different moment.
function ForestTest.laneLookPoint(standX: number, spec, spot: Vector3, rest, layout: Layout?): Vector3
	local laneX = standX + (spec.laneOffset or 0)
	local resolved = rest or ForestTest.REST
	local where = layout or ForestTest.ROAD_LAYOUT
	local north = spot.Z - ForestTest.roadZ(spot.X, where) + (resolved.sightFromStuds or 0)
	return Vector3.new(laneX, where.centre.Y, ForestTest.roadZ(laneX, where) + north)
end

-- HOW FAR OFF ITS OWN LANE A GROUP'S SPOT IS. PURE, flat, and the one thing `laneSideStuds` is
-- compared against -- so "beside the lane" is measured in one place.
function ForestTest.offLaneStuds(standX: number, spec, spot: Vector3): number
	return math.abs(spot.X - (standX + (spec.laneOffset or 0)))
end

-- ---------------------------------------------------------------- THE DRIVE SCRIPT (task 251)
--
-- KAREN, 2026-10-23, verbatim: *"we need better saound and behaviour for red stag / and them patter
-- with animals how many where they come how they come how many groups jumping over road red stags
-- ect"*. She then read the Designer's plan and said *"ok"* to its defaults: ~57 animals per drive in
-- 13 groups, 2 deer groups (the hind party early, the stag last).
--
-- THE SPEC IS `<runs-dir>/design/driveflow-spec.md` and the drawing beside it is
-- `driveflow-plan.png`. Its section 2.2 table IS the fifteen rows below, row for row; its section 1
-- is where the shape comes from -- the German hunting press on what a *Drueckjagd* does to each
-- species (Jaeger, *Drueckjagdplanung*; waidwissen.com, *Drueckjagd*) and the GPS studies behind the
-- counts (Bonnot et al., PLOS ONE 2020, open access: 68 % of hinds flee and 32 % STAY; the wild-boar
-- drive-hunt papers for the sounder sizes).
--
-- THE SIX-ROW REPEATING `cycle` IS GONE and is archived with its reason in
-- `backups/2026-10-23_task-251_schedule-cycle.md` (rule 7). It had no shape: wave 7 was wave 1
-- again, every group came from the same two or three depths, and -- measured while reading the code
-- for this task -- it was ALREADY DORMANT in the world Karen plays, because `LINE.enabled` is true
-- and `ForestTest.releaseLine` drew its own count, crossing and pace and never read it.
--
-- A DRIVE OF THIS WORLD IS ABOUT 210 SECONDS AND FIFTEEN SLOTS, THIRTEEN SECONDS APART, THE FIRST AT
-- TEN (`SCHEDULE.firstSlotSeconds`, `SCHEDULE.intervalSeconds`; `ForestTest.slotSeconds` is that
-- arithmetic). `DRIVE.seconds` is 300 and is only the CEILING -- what actually ends a drive here is
-- the beater line arriving (`Match.beaterCrossing`), which is why part 2 moved the gap: see the two
-- rows at the top of `SCHEDULE` and `ESCALATE.md`, 2026-10-23. THIS TABLE IS ONE ROW PER SLOT, in
-- three acts:
--   ACT I   (slots 1-4, zone A, 85-125 studs out) the near holding and the jumpy ones. The drive
--           starts BEFORE the beaters do, because the noise of arrival moves the experienced animals
--           (Livingactive, *Tipps und Tricks fuer die Drueckjagd*).
--   ACT II  (slots 6-9, zones B, C and D, 145-330) the body of it: the big sounders, the broadside
--           pass -- and THE STAG, released here since task 251c so that he can WALK to the road.
--   ACT III (slots 11-15, zones B and C, 145-360) the far wood and the late, pressed ones, both
--           refusals, and the stag arriving at the verge out of act II.
--   SLOTS 5 AND 10 ARE THE TWO SILENCES, and they are the one place the act numbers and the zones
--           part company (round 1's note, which was right about the mismatch): each carries the row a
--           BUSY drive puts there instead of the gap -- slot 5 a second broadside pass from the flank
--           (zone D, 150), slot 10 two males out of the far wood (zone C, 265) -- so its ZONE belongs
--           to what it would release and its `act` to where it sits in the drive.
--
-- WHAT THE NUMBERS COME OUT AT, with the dial at `normal` (and they are counted by
-- `ForestTest.driveTally`, not by hand, so a changed row changes the count):
--   13 groups, 59 animals (boar 11 groups / 56, red deer 2 / 3)
--   10 groups cross the road -- one about every 16 seconds across the middle of the drive
--   2 refuse at the verge and break back through the beaters, and 1 never comes at all
--      (that last one is the PLOS ONE study's 32 % of animals that stay put, made visible)
--   2 leaping GROUPS and 3 leaping ANIMALS -- the hind, her calf and the stag. NO BOAR EVER LEAPS.
--      (`driveTally.leapingGroups` counts the rows and the spec adds the animals through the boar's
--      own weigher. Round 1's note: the field was called `leapers` and answered 2 against a header
--      that said 3.)
--
-- 59 AND NOT THE SPEC'S 57, AND THE DIFFERENCE IS HONEST. Rows 3, 11 and 15 are written in the spec
-- as `{females = 1, cubs = 4}` and `{females = 2, cubs = 3, males = 1}`, which are NOT among the six
-- `Boar.CONFIG.SOUNDER.COMPOSITIONS` rows -- and the spec's own sentence is *"not one new
-- composition is invented"*. So each takes composition 5, `{females = 1, cubs = 4, males = 1}`, the
-- nearest real row, which weighs 6 instead of 5: three groups, one animal each, so 56 boar instead
-- of 53, plus the 3 deer. Inventing a seventh composition to hit 57 would break rule 2.
--
-- `MAX_BOARS` IS 60 AND THIS NEVER APPROACHES IT: about five groups are on their feet at once in
-- act II, ~25 animals, released across five minutes and most gone within a minute of crossing.
--
-- EVERY FIELD, AND WHO OWNS THE FACT BEHIND IT:
--   `slot`, `atSeconds`, `act`      this drive's own shape. `atSeconds` is DERIVED and asserted, not
--                                   read: `firstSlotSeconds + (slot - 1) * intervalSeconds`. It is
--                                   here so the table can be read as a timeline, and
--                                   `forest_line.spec` checks every row against
--                                   `ForestTest.slotSeconds`.
--   `species`                       "boar" or "reddeer".
--   `party`                         for `reddeer` only: which of
--                                   `SPECIES.reddeer.RELEASE.COMPOSITIONS`, BY NAME ("hinds",
--                                   "stag"). The drive says which party; the ANIMAL's owner knows
--                                   which row that is (`Boar.deerComposition`).
--   `composition`                   for `boar` only: an index into `SOUNDER.COMPOSITIONS`, because
--                                   who is in a flock is the boar system's fact and which flock
--                                   comes next is the drive's. A composition carries its own SIZE.
--   `zone`, `northStuds`, `offsetX` where it starts: `northStuds` is studs north of the road at that
--                                   x, `offsetX` studs east (+) or west (-) of THE HUNTER'S OWN
--                                   STAND (`ForestTest.wavePoint` adds it), so "150 studs west of
--                                   me" means that wherever she stands. `zone` is the band's name,
--                                   for reading.
--   `files`                         1, or 2 for a sounder that comes down in two files.
--   `crossOffset`                   which of `LINE.crossOffsets` it crosses at. Groups SHARE them on
--                                   purpose: a *Wechsel* is a path, not a one-off, and waidwissen
--                                   puts the guns *"an Wechseln und Paessen"* for exactly that
--                                   reason.
--   `route`                         STRAIGHT / LATERAL / BREAK-BACK / SPLIT / HOLD. What the group
--                                   does; `ForestTest.slotRoute` is the one reader.
--   `lateral`                       "LtoR" or "RtoL", for `route = "LATERAL"` only.
--   `turnAtDz`                      for `BREAK-BACK`: how close to the road it comes before it
--                                   refuses and goes home north.
--   `pace`                          the pace at RELEASE ("walk" / "trot" / "run"); a shot, a beater
--                                   or a hit overrides it, exactly as before.
--   `check`, `sneak`, `leaps`       the DEER's own behaviour at the verge, declared here and
--                                   honoured by the ANIMAL's owner. See "WHAT PART 1 DOES NOT DO"
--                                   below, which says exactly what each one does today.
--   `sneakStuds`, `sneakDz`         for `sneak` only: how far he walks inside the treeline and how
--                                   far north of the road that walk runs.
--   `keepAt`                        the smallest density at which this row carries animals. THE DIAL.
--   `note`                          what a reader should see happen.
--
-- THE DIAL IS ONE NUMBER (spec section 2.6), `SCHEDULE.density`, and `normal` is the default Karen
-- OK'd:
--
--   | dial           | quiet | NORMAL | busy |
--   |----------------|-------|--------|------|
--   | groups         | 9     | 13     | 15   |
--   | animals        | 37    | 59     | 69   |
--   | deer groups    | 1     | 2      | 2    |
--   | refusals       | 0     | 2      | 2    |
--   | ones that hold | 0     | 1      | 1    |
--
-- AND IT IS ONE RULE, NOT FIVE: a row fires when `row.keepAt <= groups`. The four rows at
-- `keepAt = 13` are exactly the stag, the two refusals and the hold -- so the single number moves
-- all five columns of that table at once, which is why there is no `refusalsPerDrive` to keep in
-- step with it. `ForestTest.slotAt` is the whole of it, pure, and `forest_line.spec` asserts each
-- column of the table above against the rows rather than against a second copy of the numbers
-- (round 1's note: this used to cite `forest_stand.spec`, whose only change here is the
-- `cycle` -> `drive` loop in task 168's "nothing behind the beaters" case).
--
-- WHAT PART 1 DOES NOT DO, said here rather than discovered in a playtest (rule 8). This is the
-- FIRST half of task 251 (the Director's own split point: items 1 and 4 now, the stag's behaviour
-- and his voice next). So today:
--   * `check = true` on rows 2 and 13 is honoured by the EXISTING edge stop and nothing more: every
--     line's leader is already offered `Runtime:check` as she comes inside `LINE.checkWithinStuds`
--     (`ForestTest.stepLines`), at the Brain's own `MOVE.EDGE_CHANCE` of 0.55 and for 1-4 s. The
--     deer's own longer, likelier, look-BACK check (0.90, 2-6 s, 150 deg) is spec section 3.2 and is
--     part 2.
--   * `sneak = true` on row 13 IS WALKED SINCE PART 2, and the two numbers beside it
--     (`sneakStuds` 120, `sneakDz` 75) are what it walks. `ForestTest.sneakEntryX` is the pure half
--     and `releaseLine` pins the extra point. He is still alone and still 55 studs deeper than the
--     next-deepest group that comes -- and SINCE TASK 251c he is released at slot 8 rather than 13,
--     because a 95-second walk cannot be done in the 44 seconds slot 13 left him. He is last AT THE
--     ROAD, which is what *"the stag last"* always meant (`ESCALATE.md`, 2026-10-24).
--   * `leaps` is the measured road leap, already built and already behind `DEER_ROAD_LEAP` (which is
--     ON in Karen's place). The STAG'S BOUND WHEN SPOOKED (spec section 3.2 `BOUND_ON_SPOOK`) is
--     part 2, and the spec itself holds it behind the leap's known hoof sink (TASKS.md 245c).
ForestTest.SCHEDULE = {
	-- ------------------------------------------------- THE LENGTH OF THE DRIVE (task 251 part 2)
	--
	-- 20 -> 13, AND 10 FOR THE FIRST SLOT: the two numbers that answer part 1's escalation
	-- (`ESCALATE.md`, 2026-10-23 -- *"a Forest Test drive is ~130 seconds, not 300, so slots 6-15 all
	-- but never happen -- the stag included"*). **THE DIRECTOR ANSWERED IT on 2026-10-24**, Karen
	-- having delegated the feel for the night: lengthen the drive to about 210 s by slowing the beater
	-- line, and space the fifteen slots so every one of them -- the stag's slot 13 included -- plays
	-- before the line arrives. Slot 1 at 10 s, 13 s apart, slot 15 at 192 s.
	--
	-- SO THE SCRIPT IS UNCUT (the escalation's option D is refused by name) and the two halves are:
	--   the DRIVE got longer: `Bots.CONFIG.WALK_SPEED` 5 -> 3.1, which is the other half of this and
	--     lives there because the walk is that module's number (`bots_lane.spec` holds the relation);
	--   the SLOTS got closer: 20 -> 13 here, which is this module's.
	-- 10 + 14 x 13 = 192 s, and the line arrives at ~210: every slot plays, with ~18 s to spare.
	--
	-- BOTH ARE DATA ROWS AND KAREN MOVES THEM IN THE MORNING, which is the dispatch's own condition.
	-- Nothing derives from them but `ForestTest.slotSeconds` and the metronome in `ForestTest.step`.
	intervalSeconds = 13,
	-- WHEN SLOT 1 IS DUE, measured from the drive's own start. It used to be `intervalSeconds` by
	-- accident rather than by decision -- `ForestTest.start` set `nextWaveAt = now + intervalSeconds`
	-- and the rows' own `atSeconds` read `slot * gap - gap / 2`, so the TABLE said 10 s and the WORLD
	-- released at 20. Two numbers for one fact, differing by half a gap, and neither was wrong on its
	-- own terms. Now it is one row, the derivation reads it, and the metronome is based on it.
	firstSlotSeconds = 10,

	-- ------------------------------------------ AHEAD OF THE BEATER LINE (task 251c)
	--
	-- A SLOT'S START DEPTH IS RELATIVE TO THE LINE AND NOT ABSOLUTE. **THE DIRECTOR ANSWERED part 2's
	-- escalation on 2026-10-24** (`ESCALATE.md`, *"ACT III ... IS RELEASED BEHIND THE ADVANCING
	-- BEATER LINE"*): a group is released at `min(its table depth, the line's own depth - leadStuds)`,
	-- so it is never put down behind the men who are supposed to be pushing it.
	--
	-- WHY IT HAD TO BE RELATIVE, AND IT WAS MEASURED: the beaters start 580 studs north
	-- (`ForestTest.beaterNorthStuds`) and advance at `Bots.CONFIG.WALK_SPEED` 3.1, so the line is past
	-- dz 330 by 96 s -- while act III's rows are due at 140 to 192 s. Every one of them was put down
	-- 30 to 106 s AFTER the line had walked through its own start: slot 14's two males were next seen
	-- NORTH of their own spawn, slot 12's nine covered 320 studs at a run in 14 s, and the stag
	-- crossed on a fright rather than on the sneak part 2 had just built for him.
	--
	-- `ForestTest.releaseDepth` IS THE WHOLE RULE and it is pure. `releaseLine` measures the line's
	-- depth AT THE MOMENT OF RELEASE (`ForestTest.lineNorthAt`, off the beaters' own bodies, at that
	-- row's own x) and hands it in. A figure derived from the walk instead would be this very defect
	-- in reverse -- a number used where it was not measured, which is what all four of task 192's
	-- deaths were (Learning Agent L-024).
	--
	-- THE TABLE'S ORDERING SURVIVES, which is the Director's own condition: the clamp is a `min`, so
	-- it never puts a row DEEPER than the script wrote, and act III is still deeper than act I
	-- wherever the line leaves room for it.
	--
	-- 60 -> 130, AND IT WAS MEASURED (task 253; the Director's decision, 2026-10-24). 60 studs is
	-- INSIDE two of the line's own reaches -- the notice band is `noticeAheadStuds` = 100 studs deep
	-- and the flush circle is `BEATER_STUDS` = 71 -- so every clamped group was spawned already
	-- noticed, and `SPOOK.ALERT_SECONDS` = 2 broke it two seconds later whatever the line did. The
	-- stag was in `MOVE.SPRINT_SPEED` 1.5 s after release and over the road 7 s later, with no edge
	-- check, no look back and no sneak (`<runs-dir>/251c-stag-track.txt`). 130 is clear of the
	-- deepest of the three by 30 studs -- one tick of the line at any pace it walks -- and
	-- `forest_stand.spec` asserts that relation rather than the number.
	leadStuds = 130,
	-- ...AND THE FLOOR UNDER IT, so a clamped row is never put on the tarmac. By the last slots the
	-- line IS the road -- at 192 s it is at dz ~32, and `32 - 60` is south of the verge -- so there is
	-- no room ahead of it at all and those rows take this floor instead. They are then level with the
	-- line rather than ahead of it, which is reported rather than hidden (`releaseLine` prints both
	-- depths every slot): the alternative is releasing a group behind the hunter. 25 studs is just
	-- north of the verge and well short of every depth the script writes.
	--
	-- A ROW THAT SNEAKS TAKES ITS OWN `sneakDz` AS THE FLOOR instead (`releaseLine` hands it in): the
	-- sneak's two pins sit `sneakDz` north of the road, so a start clamped SHALLOWER than that would
	-- walk the stag NORTH into the treeline band and then south again -- a doubling back, not a sneak.
	-- A ROW THAT HOLDS IS NOT CLAMPED AT ALL (`ForestTest.clampedToLine`).
	minNorthStuds = 25,

	-- HOW BUSY A DRIVE IS: "quiet", "normal" or "busy". Karen OK'd `normal`.
	density = "normal",
	-- HOW MANY OF THE FIFTEEN SLOTS CARRY ANIMALS at each setting. The one number the dial is.
	DENSITIES = { quiet = 9, normal = 13, busy = 15 },

	-- A DRIVE THAT OUTLIVES ITS SCRIPT REPEATS THIS WINDOW -- the body of act II and act III, which
	-- is the part of a drive that can bear repeating -- so a longer `DRIVE.seconds` can never run out
	-- of animals.
	--
	-- IT EXCLUDES THE STAG, AND SINCE TASK 251c THAT IS A RULE IN `slotAt` RATHER THAN AN ACCIDENT OF
	-- THESE TWO NUMBERS. It used to be true positionally -- he was slot 13 and the window is 6-12 --
	-- and moving him to slot 8 put him INSIDE it, so slot 18 of a long drive would have asked for a
	-- second stag (the live run that found it got as far as slot 17). A second stag in one drive is
	-- not a drive with a stag in it; `MAX_GROUPS_ALIVE` would usually refuse him, but "usually" is
	-- not what the comment claimed.
	repeatFrom = 6,
	repeatTo = 12,

	drive = {
		-- ------------------------------------------------------------------ ACT I: the near holding
		{
			slot = 1,
			atSeconds = 10,
			act = 1,
			species = "boar",
			composition = 6, -- {males = 1}
			zone = "A",
			northStuds = 95,
			offsetX = -150,
			files = 1,
			crossOffset = -70,
			route = "STRAIGHT",
			pace = "trot",
			keepAt = 9,
			note = "the first mover: one big lone male, west, out before the beaters are heard",
		},
		{
			slot = 2,
			atSeconds = 23,
			act = 1,
			species = "reddeer",
			party = "hinds", -- {hind = 1, calf = 1}
			zone = "A",
			northStuds = 125,
			offsetX = 170,
			files = 1, -- a deer group is a column, never two files (`RELEASE.FORMATION`)
			crossOffset = 55,
			route = "STRAIGHT",
			pace = "walk",
			check = true,
			leaps = true,
			keepAt = 9,
			note = "the hind party, early and in file: she stops at the verge, then they leap",
		},
		{
			slot = 3,
			atSeconds = 36,
			act = 1,
			species = "boar",
			composition = 5, -- {females = 1, cubs = 4, males = 1}
			zone = "A",
			northStuds = 110,
			offsetX = -215,
			files = 2,
			crossOffset = -35,
			route = "STRAIGHT",
			pace = "trot",
			keepAt = 9,
			note = "a sow and her young, close and west, in two files",
		},
		{
			slot = 4,
			atSeconds = 49,
			act = 1,
			species = "boar",
			composition = 2, -- {males = 2}
			zone = "A",
			northStuds = 85,
			offsetX = 60,
			files = 1,
			crossOffset = 20,
			route = "STRAIGHT",
			pace = "trot",
			keepAt = 9,
			note = "the near pair, straight down the front of the stand",
		},
		{
			-- SILENCE AT quiet AND normal. A drive with no gaps in it is a shooting gallery; this is
			-- the first of the two, and at `busy` it carries a second broadside pass.
			slot = 5,
			atSeconds = 62,
			act = 1,
			species = "boar",
			composition = 3, -- {males = 5, females = 3}
			zone = "D",
			northStuds = 150,
			offsetX = -235,
			files = 1,
			crossOffset = -70,
			route = "LATERAL",
			lateral = "RtoL",
			pace = "trot",
			keepAt = 15,
			note = "silence -- unless the drive is busy, and then a second broadside pass, west",
		},
		-- ------------------------------------------------------------------ ACT II: the body of it
		{
			slot = 6,
			atSeconds = 75,
			act = 2,
			species = "boar",
			composition = 3, -- {males = 5, females = 3}
			zone = "D",
			northStuds = 150,
			offsetX = 235,
			files = 1,
			crossOffset = 20,
			route = "LATERAL",
			lateral = "LtoR",
			pace = "trot",
			keepAt = 9,
			note = "the broadside pass: across her front left to right, then over the road",
		},
		{
			slot = 7,
			atSeconds = 88,
			act = 2,
			species = "boar",
			composition = 1, -- {females = 2, males = 3, cubs = 4}
			zone = "B",
			northStuds = 170,
			offsetX = -120,
			files = 2,
			crossOffset = -35,
			route = "STRAIGHT",
			pace = "trot",
			keepAt = 9,
			note = "the big sounder, nine of them in two files",
		},
		{
			-- THE STAG. Alone, deeper than anything else that comes, and LATE AT THE ROAD -- which is
			-- the Isle of Rum finding (*"only 10 % to 20 % of mature stags associated with hinds
			-- outside the rut"*, `docs/research/2026-10-21-deer-in-every-drive.md`) and the Jaeger
			-- finding (red deer come *"lange nach Beginn des Treibens -- klammheimlich aus der
			-- Dickung"*) in one row. The hinds came out at slot 2 and 85 studs; he is at the verge
			-- about 135 seconds later, out of a holding the script writes at 330.
			--
			-- HE IS RELEASED HERE SO THAT HE CAN WALK IT (task 251c). He was slot 13 and
			-- part 2 measured what that cost: released at 166 s he had 44 seconds for a 95-second
			-- walk, so the sneak, the 0.90 edge check and the 150-degree look back -- the three
			-- things part 2 is FOR -- could not happen at all. **THE DIRECTOR ANSWERED IT on
			-- 2026-10-24**: *"THE STAG ARRIVES LAST, SO HE IS RELEASED EARLY ENOUGH TO DO IT. 'The
			-- stag last' means the last to CROSS, not the last to be released."*
			--
			-- THE ARITHMETIC, AND IT IS WHY SLOT 8 AND NOT 7 OR 13. Due at 101 s. The beater line is
			-- then at dz `580 - 3.1 x 101` = 267 (flat) or 290 (at the 1.081 ground factor
			-- `bots_lane.spec` measured), so the clamp above bites either way and releases him at
			-- `267 - 130` = **137** (flat) or 160:
			--
			--     approach  137 - 75 (`sneakDz`) = 62 studs
			--     sneak                           120 studs along the treeline
			--     verge     75 - 0                 75 studs
			--     total                          257 studs / `PACE.WALK_SPEED` 4.5 = 57 s
			--
			-- -- so he is at the verge at **158 s** (flat) or 163 (ground), against a line that
			-- reaches the road at 187 s flat / ~202 s measured: **a margin of 29 s and 39 s**, and
			-- both inside act III's own window (140-192 s), which is the Director's *"reaches the
			-- verge in act III"*. Slot 7 (88 s) would put him there 8 s earlier for no gain; slot 9
			-- (114 s) is 8 s later and still clear, and slot 13 -- where he was -- cannot be done at
			-- all, which is what task 251c measured.
			--
			-- `leadStuds` WAS 60 WHEN THIS ROW MOVED (task 251c) AND IS 130 SINCE TASK 253, and the
			-- arithmetic above is the second one. The first put him 207 studs out and 60 studs in
			-- front of a line whose NOTICE BAND is 100 studs deep, so he was flushed on release and
			-- bolted across the road: a shallower, later-looking release is the one that lets him
			-- walk.
			--
			-- HE IS THE LAST DEER, AND HE IS NOT THE LAST WALKER: slot 9's big lone male walks at
			-- 114 s, and slot 14 -- released at 179 s at a RUN from a depth the clamp pulls to its
			-- floor -- is over the road about two seconds later, so it crosses after him. Both are
			-- said out loud rather than discovered (rule 8), and the second is the clamp's own
			-- consequence rather than a second rule: a deep row released when the line is already at
			-- the verge has nowhere ahead of it to start from.
			--
			-- HIS `act` IS 2 BECAUSE A ROW'S ACT IS WHERE IT SITS IN THE DRIVE (five slots each, and
			-- `forest_line.spec` asserts the quotient). WHAT REACHES ACT III IS THE STAG HIMSELF, at
			-- the verge at 174-179 s, which is act III's own window (140-192) -- which is exactly what
			-- the Director asked for: *"reaches the verge in act III"*.
			slot = 8,
			atSeconds = 101,
			act = 2,
			species = "reddeer",
			party = "stag", -- {stag = 1}
			zone = "C",
			northStuds = 330,
			offsetX = -95,
			files = 1,
			crossOffset = -35,
			route = "STRAIGHT",
			pace = "walk",
			check = true,
			-- THE SNEAK, WALKED SINCE PART 2 (spec section 3.2, Karen OK'd): *"ein Stueck innerhalb
			-- des Waldrands ... ehe es das offene Feld annimmt"* -- he comes down to the band inside
			-- the treeline, walks `sneakStuds` along it parallel to the road, and only then takes the
			-- open at his crossing. It is the one two-leg route in the script and it is the same
			-- machinery as every other (`computeRouteVia`, pinned through one extra point).
			--
			-- TWO NUMBERS AND NOT TWO RANGES, which is part 1's own principle and the reason this
			-- table exists: a SCRIPT draws nothing. The spec's bands are 80-160 studs parallel at a
			-- `dz` of 60-90, and these are the middle of each -- Karen's to move, one row, no code.
			--
			-- `sneakDz` IS ALSO THE FLOOR OF HIS OWN RELEASE CLAMP (task 251c): see `minNorthStuds`.
			sneak = true,
			sneakStuds = 120,
			sneakDz = 75,
			leaps = true,
			keepAt = 13,
			note = "THE RED STAG: out of the far wood at a walk, alone, and he sneaks the treeline",
		},
		{
			slot = 9,
			atSeconds = 114,
			act = 2,
			species = "boar",
			composition = 6, -- {males = 1}
			zone = "B",
			northStuds = 210,
			offsetX = -185,
			files = 1,
			crossOffset = -70,
			route = "STRAIGHT",
			pace = "walk",
			keepAt = 9,
			note = "the big lone male, slow, and worth the barrel",
		},
		{
			-- THE SECOND SILENCE, and at `busy` a pair of males out of the far wood.
			slot = 10,
			atSeconds = 127,
			act = 2,
			species = "boar",
			composition = 2, -- {males = 2}
			zone = "C",
			northStuds = 265,
			offsetX = 85,
			files = 1,
			crossOffset = 55,
			route = "STRAIGHT",
			pace = "trot",
			keepAt = 15,
			note = "silence -- unless the drive is busy, and then two males out of the far wood",
		},
		-- ------------------------------------------------------ ACT III: the far wood, and the stag
		{
			slot = 11,
			atSeconds = 140,
			act = 3,
			species = "boar",
			composition = 5, -- {females = 1, cubs = 4, males = 1}
			zone = "C",
			northStuds = 275,
			offsetX = 200,
			crossOffset = 95,
			files = 2,
			route = "SPLIT",
			-- WHERE THE SPLINTER GOES: the SECOND file takes its own crossing this far west of the
			-- group's, so the group crosses in two places 40 studs apart and a hunter gets two
			-- chances out of one sounder. `SOUNDER.BREAK_STUDS` already dissolves a stretched group;
			-- this ASKS for it rather than inventing a rule.
			--
			-- WHO IS IN WHICH FILE IS `Line.split`'S, AND IT DEALS ALTERNATELY (rank 1, 3, 5 to the
			-- first file and 2, 4, 6 to the second) after `Boar.MARCH_RANK` has put the sow at the
			-- head. So the spec's *"the sow and cubs keep the crossing and the adult male takes
			-- the other"* is NOT what happens -- it is three and three, led by the two highest ranks.
			-- Said plainly rather than claimed: splitting a composition by KIND would be a new rule
			-- in the file-dealing owner, and the thing Karen asked for (one sounder, two crossings)
			-- is already true without it.
			splitStuds = -40,
			pace = "trot",
			keepAt = 9,
			note = "the pressed sounder, flushed from inside: it splits at the verge and crosses twice",
		},
		{
			slot = 12,
			atSeconds = 153,
			act = 3,
			species = "boar",
			composition = 4, -- {females = 3, cubs = 6}
			zone = "C",
			northStuds = 300,
			offsetX = -250,
			files = 1,
			route = "BREAK-BACK",
			turnAtDz = 55,
			pace = "trot",
			keepAt = 13,
			note = "the second refusal: nine of them turn at 55 studs and break back through the beaters",
		},
		{
			-- THE REFUSAL, AND IT IS SLOT 13 BECAUSE THE STAG TOOK ITS 101 s (task 251c). The two rows
			-- SWAPPED and nothing else in the script moved -- the Director's *"keep the other slots'
			-- release times"*. They are the same `keepAt` (13), so the swap cannot move one column of
			-- the dial's table at any density: this is still the second of the drive's two refusals.
			--
			-- IT IS LATE AND SHALLOW NOW, and that reads right rather than merely harmless: at 166 s
			-- the line is at dz 65 (flat) or 104 (in Karen's place), so the clamp releases her at her
			-- own route floor -- `turnAtDz` 40 + the 25-stud floor = **65** -- and she walks those 25
			-- studs to her turn, thinks better of the road with the beaters right behind her, and
			-- breaks back THROUGH them. That is what a late refusal is. Her `zone` stays "B" because
			-- a zone says where a row's TABLE depth is, not which act it sits in (the same split the
			-- two silences already keep).
			slot = 13,
			atSeconds = 166,
			act = 3,
			species = "boar",
			composition = 5, -- {females = 1, cubs = 4, males = 1}
			zone = "B",
			northStuds = 145,
			offsetX = 115,
			files = 1,
			route = "BREAK-BACK",
			turnAtDz = 40,
			pace = "trot",
			keepAt = 13,
			note = "THE REFUSAL: she comes to 40 studs of the road, thinks better of it, and goes home",
		},
		{
			slot = 14,
			atSeconds = 179,
			act = 3,
			species = "boar",
			composition = 2, -- {males = 2}
			zone = "C",
			northStuds = 290,
			offsetX = 145,
			files = 1,
			crossOffset = 95,
			route = "STRAIGHT",
			pace = "run",
			keepAt = 9,
			note = "the last of them, running: the beaters are at their backs by now",
		},
		{
			slot = 15,
			atSeconds = 192,
			act = 3,
			species = "boar",
			composition = 5, -- {females = 1, cubs = 4, males = 1}
			zone = "C",
			northStuds = 360,
			offsetX = 265,
			files = 1,
			route = "HOLD",
			-- HOW FAR IT MOVES BEFORE IT LIES UP. The PLOS ONE study's stayers net-displace 426 m
			-- against a fleeing hind's 1 452; 60 studs is 17 m, which is a group that has heard the
			-- drive, moved off its bed and decided that is enough.
			holdStuds = 60,
			pace = "walk",
			-- 13 AND NOT 9, and the gate caught it: the dial's own table says a QUIET drive has no
			-- group that holds (`holdsPerDrive` 0), so this row belongs to `normal` with the stag and
			-- the two refusals. At 9 it made a quiet drive ten groups instead of nine.
			keepAt = 13,
			note = "THE ONE THAT STAYS: moves 60 studs toward the road and lies up. It never comes",
		},
	},

	-- HOW FAR SHORT OF THE ROAD A TURNED-BACK GROUP STOPS before it goes home. Close enough for the
	-- hunter to see it and raise the gun, which is the whole point of letting it refuse. It is the
	-- FALLBACK for a `BREAK-BACK` row that names no `turnAtDz` of its own, and the old wave path's
	-- `turnsBack` number unchanged.
	turnBackStuds = 70,
	-- HOW FAR NORTH A REFUSAL WALKS BEFORE IT IS LET GO OF. Past the beater line (`beaterStart` is
	-- 580 studs north of the road) is where it is going; this is where the drive stops ordering it
	-- and hands it back to the Brain, which is what `LINE.maxSeconds` would do anyway a few seconds
	-- later. 420 is the spec's number (section 2.3).
	breakBackToDz = 420,
}

-- ---------------------------------------------------- READING THE DRIVE SCRIPT (task 251)
--
-- FIVE PURE FUNCTIONS, and they are pure for the reason every other rule in this file is: a spec can
-- drive the whole fifteen-slot script, at all three densities, from hand-written numbers and with no
-- runtime, no world and no animal. `ForestTest.releaseLine` is then the only thing that needs a
-- Studio to run.

-- HOW MANY OF THE FIFTEEN SLOTS CARRY ANIMALS. The dial's word in, the one number out.
--
-- AN UNKNOWN WORD IS `normal`, not an error and not zero: a drive that released nothing because a
-- typo reached this far would be a world with no animals in it, which is a worse answer than the
-- default Karen OK'd.
function ForestTest.groupsWanted(density: string?, schedule): number
	local resolved = schedule or ForestTest.SCHEDULE
	local dials = resolved.DENSITIES or {}
	local want = if density ~= nil then dials[density] else nil
	if type(want) ~= "number" then
		want = dials.normal
	end
	return if type(want) == "number" then want else #(resolved.drive or {})
end

-- WHEN A SLOT IS DUE, in seconds from the drive's start. PURE, and DERIVED -- `firstSlotSeconds +
-- (slot - 1) * intervalSeconds`, so slot 1 is at 10 s and slot 15 at 192 -- which is what makes each
-- row's own `atSeconds` an assertion (`forest_line.spec` checks every row against this) instead of a
-- second copy of the clock that can drift away from the two numbers above.
--
-- IT USED TO BE `slot * gap - gap / 2` (task 251 part 1), which is the same arithmetic with the first
-- slot pinned to `gap - gap / 2` -- 10 s only because the gap happened to be 20. It is spelled out as
-- two rows now because part 2 moves the gap and NOT the first slot, and because the metronome in
-- `ForestTest.step` is based on the same `firstSlotSeconds`, so the table and the world agree.
function ForestTest.slotSeconds(slot: number, schedule): number
	local resolved = schedule or ForestTest.SCHEDULE
	local gap = math.max(1, resolved.intervalSeconds or 20)
	local first = resolved.firstSlotSeconds
	if type(first) ~= "number" then
		first = gap - gap / 2
	end
	return first + (slot - 1) * gap
end

-- HOW DEEP A SLOT IS ACTUALLY RELEASED, given where the beater line has got to (task 251c). PURE:
-- three numbers in, one out, so the whole of the Director's rule is a spec case with no world, no
-- beater, no clock and no animal.
--
--     max(the floor, min(the table's depth, the line's own depth - `leadStuds`))
--
-- `lineNorth` IS NIL FOR A WORLD WITH NOBODY PUSHING, and then the answer is the table's own depth,
-- unchanged -- which is right rather than merely safe: with no line there is no behind. It is also
-- every drive of the DEV place, which has no beaters at all.
--
-- ...AND A LINE THAT IS AT OR PAST THE ROAD IS NOT A LINE EITHER, which is MEASURED rather than
-- tidy. A drive ends when the beaters arrive, but `DRIVE.seconds` is 300 and the script's repeat
-- window (`repeatFrom`..`repeatTo`) keeps releasing until it runs out -- so the first live run of
-- this task logged `SLOT 16 ... from dz 25 of 150, line at dz 26` and `SLOT 17 ... from dz 25 of
-- 170, line at dz -9`: two sounders put down ON THE VERGE, 25 studs in front of the hunter. Once the
-- men are through there is nothing left to be behind, so the script's own depths are right again and
-- the second of those two comes out of the wood as it always did (measured after: *"from dz 170 of
-- 170"*).
--
-- IT FIXES THE SECOND OF THE PAIR AND NOT THE FIRST, said plainly because the round-1 Reviewer was
-- right to pin it: a line at dz 26 is still NORTH of the road, so that release is still clamped to
-- the floor and slot 16 still comes out on the verge. What is left there is the drive's own last
-- seconds, where there genuinely is no room in front of the men -- the same case as slots 13 and 14.
--
-- IT ONLY EVER PULLS A ROW TOWARD THE ROAD. The `min` is what keeps the script's relative ordering
-- (the Director's own condition), and it is why there is no "has the line passed this row" branch at
-- all: a row the line has not reached clamps to itself.
--
-- THE FLOOR IS APPLIED LAST AND CAN THEREFORE WIN, which is deliberate and is the one case where the
-- answer is not ahead of the line: once the line is within `leadStuds` of the road there is no room
-- in front of it, and a group on the tarmac behind the hunter would be worse than one level with the
-- beaters. `releaseLine` prints both depths for every slot, so it is visible rather than silent.
-- `forest_line.spec` asserts the floor is below every depth the script writes, so the floor can
-- never make a row DEEPER than its own row says.
function ForestTest.releaseDepth(tableNorth: number?, lineNorth: number?, floorStuds: number?, schedule): number
	local resolved = schedule or ForestTest.SCHEDULE
	-- THE SAME DEFAULT `wavePoint` USES for a row with no depth, so the two cannot disagree about
	-- where an unspecified row starts.
	local wanted = if type(tableNorth) == "number" then tableNorth else 100
	local floor = math.max(resolved.minNorthStuds or 0, if type(floorStuds) == "number" then floorStuds else 0)
	if type(lineNorth) ~= "number" or lineNorth <= 0 then
		return wanted
	end
	return math.max(floor, math.min(wanted, lineNorth - (resolved.leadStuds or 0)))
end

-- THE SHALLOWEST A ROW MAY BE RELEASED AND STILL WALK ITS OWN ROUTE (task 251c). PURE: one row
-- in, a depth out, and it is the floor `releaseDepth` is handed.
--
-- IT EXISTS BECAUSE THE CLAMP PULLS A ROW TOWARD THE ROAD, and three of the five route words have a
-- point of their own that has to stay NORTH of where they start. Without this the clamp would break
-- the very rows it was meant to save, which is worth spelling out because each one is a different
-- shape of wrong:
--   a SNEAK's two pins sit at `sneakDz`, so a shallower start walks the stag NORTH into the treeline
--     band and then south again -- a doubling back, not a sneak.
--   a BREAK-BACK turns at `turnAtDz`, so a shallower start walks north to its turn and then home,
--     and the refusal Karen asked for twice (*"several go back"*) is never seen coming at the road
--     at all.
-- STRAIGHT, LATERAL and SPLIT need nothing: they walk south to their crossing from wherever they
-- are, so their floor is `minNorthStuds` and the clamp is free. A HOLD is not clamped at all --
-- see `ForestTest.clampedToLine` just below.
--
-- THE ONE THAT TURNS GETS `minNorthStuds` ON TOP OF ITS OWN POINT, so there is a few studs of walk
-- between the release and the turn rather than a group that spawns already turning.
function ForestTest.routeFloor(row, schedule): number
	local resolved = schedule or ForestTest.SCHEDULE
	local min = resolved.minNorthStuds or 0
	if row == nil then
		return min
	end
	if row.sneak == true and type(row.sneakDz) == "number" then
		return math.max(min, row.sneakDz)
	end
	if ForestTest.slotRoute(row) == "BREAK-BACK" then
		local turn = row.turnAtDz or resolved.turnBackStuds or 0
		return math.max(min, turn + min)
	end
	return min
end

-- IS THE LINE'S DEPTH THIS ROW'S BUSINESS AT ALL (task 253, round 1's blocking finding, which was
-- right)? PURE, one row in.
--
-- A `HOLD` IS NOT CLAMPED, AND BEING PASSED BY THE MEN IS WHAT IT IS FOR. The clamp exists because a
-- group released behind the line MEETS IT HEAD-ON when it starts for the road; the one that stays
-- never starts. It is the PLOS ONE study's 32 % that hold -- it moves `holdStuds` off its bed and
-- lies up -- so the beaters walking through it is the behaviour, not a defect in it.
--
-- AND THE CLAMP BROKE EXACTLY THAT, MEASURED: with a floor of `holdStuds + minNorthStuds` = 85 it
-- was released at dz 85 with the line at 66 (`ESCALATE.md`'s own live table) and its hold leg --
-- `start dz - holdStuds` -- then put a sow, four cubs and a male down to lie up **25 studs from the
-- road, in front of the hunter**, against a row whose note reads *"It never comes"*. The round-1
-- Reviewer found it in the arithmetic before Karen found it in her place.
--
-- EVERY OTHER ROUTE WORD IS CLAMPED, the refusal included: a `BREAK-BACK` comes to its `turnAtDz`
-- before it goes home, so it does start for the road and it does meet the line.
function ForestTest.clampedToLine(row): boolean
	return ForestTest.slotRoute(row) ~= "HOLD"
end

-- WHICH ROW A SLOT RELEASES, or **nil for silence**. THE WHOLE OF THE DIAL IS THIS FUNCTION.
--
-- TWO RULES AND NOTHING ELSE:
--   1. a slot past the end of the script repeats the window (`repeatFrom`..`repeatTo`), so a drive
--      longer than `DRIVE.seconds` can never run out of animals. The window excludes the stag.
--   2. a row fires only when `row.keepAt <= groups`. That is how one number moves all five columns
--      of the dial's table at once: the four rows at `keepAt = 13` ARE the stag, the two refusals
--      and the one that holds, and the two at `keepAt = 15` are the drive's two silences.
function ForestTest.slotAt(slot: number, density: string?, schedule)
	local resolved = schedule or ForestTest.SCHEDULE
	local rows = resolved.drive or {}
	if #rows == 0 or type(slot) ~= "number" or slot < 1 then
		return nil
	end
	local index = math.floor(slot)
	local want = ForestTest.groupsWanted(density, resolved)
	if index > #rows then
		local from = math.clamp(resolved.repeatFrom or 1, 1, #rows)
		local to = math.clamp(resolved.repeatTo or #rows, from, #rows)
		local span = to - from + 1
		local at = from + ((index - 1 - #rows) % span)
		-- ...AND IT WALKS PAST THE ROWS THIS DIAL SILENCES (the gate caught this). The window holds
		-- the drive's own two silences and its refusals, so at `quiet` a repeated slot could land on
		-- a row the dial had turned off -- and *"a drive that outlives its script can never run out
		-- of animals"* would have been false at exactly the setting that has the fewest. It is
		-- bounded by the window's own length: if the dial has silenced the whole window, the answer
		-- is a silence rather than a loop.
		for _ = 1, span do
			local candidate = rows[at]
			-- ...AND IT NEVER REPEATS THE STAG (task 251c). See `repeatFrom`: the exclusion used to
			-- be positional and his slot moved inside the window, so it is said here instead.
			local isStag = candidate ~= nil and candidate.species == "reddeer" and candidate.party == "stag"
			if candidate ~= nil and not isStag and (candidate.keepAt or 1) <= want then
				return candidate
			end
			at = from + ((at - from + 1) % span)
		end
		return nil
	end
	local row = rows[index]
	if row == nil then
		return nil
	end
	if (row.keepAt or 1) > want then
		return nil
	end
	return row
end

-- WHERE THE STAG ENTERS THE TREELINE BAND, so that walking `studs` along it brings him to his own
-- crossing (task 251 part 2). PURE: three numbers in, one out, so the two-leg route is a spec case
-- with no world, no layout and no pathfinder.
--
-- HE ENTERS ON THE SIDE HE CAME FROM, which is the whole rule and is why no new "which way" word is
-- needed: slot 13 starts 95 studs west of the stand and crosses 35 studs west of it, so he is coming
-- from the west, he enters the band at `crossX - studs` and walks EAST inside the trees to his
-- crossing. Move his `offsetX` to the other side of his `crossOffset` and he sneaks the other way,
-- with nothing else edited. `crossX == startX` takes the west, because a tie has to take something
-- and the stag's own row is a westerly one.
--
-- 0 OR A MISSING NUMBER -> THE CROSSING ITSELF, which collapses the two legs into one and is exactly
-- the STRAIGHT route part 1 shipped. So a row that declares `sneak` and no distance is not an error;
-- it is the behaviour before this task.
function ForestTest.sneakEntryX(startX: number, crossX: number, studs: number?): number
	if type(studs) ~= "number" or studs <= 0 then
		return crossX
	end
	local sign = if crossX >= startX then -1 else 1
	return crossX + sign * studs
end

-- WHICH ROW OF THE SCRIPT CARRIES THE STAG at this density, or nil for a drive that has none (task
-- 251 part 2). PURE, and it is read by exactly two things, both of which need "is there a stag in
-- this drive, and where is he holding": his rut roar in the first 90 seconds (`ForestTest.ROAR`,
-- which must sound from his own holding before he is released) and the proof that logs the drive.
--
-- IT ASKS `slotAt` AND NOT `pairs`, so the DIAL decides: at `quiet` the stag's row is `keepAt = 13`
-- and does not fire, and this answers nil -- which is the right answer, because a quiet drive has no
-- stag in it and a roar from an empty wood would be a lie.
function ForestTest.stagRow(density: string?, schedule)
	local resolved = schedule or ForestTest.SCHEDULE
	local rows = resolved.drive or {}
	for slot = 1, #rows do
		local row = ForestTest.slotAt(slot, density, resolved)
		if row ~= nil and row.species == "reddeer" and row.party == "stag" then
			return row, slot
		end
	end
	return nil, nil
end

-- WHICH ROAR SOUNDS, AND WHICH PIECE OF IT (task 254). The pick lives here, with the table, because
-- it is a fact ABOUT THE TABLE and nothing to do with Workspace: `ForestTest.roarNow` on the server
-- takes this answer and writes it onto the one Sound it owns, so the choosing is drivable in a spec
-- with no Sound, no emitter and no Play session -- which is what `reviews/task-253` asked for in as
-- many words (*"`roarNow` has no spec at all; the evidence is the live console lines"*).
--
-- THE REAL STAG SOUNDS WHENEVER HE IS IN THE TABLE. `ids[1]` with a usable `clips` entry wins
-- outright rather than taking its turn in a uniform pick -- because the four library ids are a BULL,
-- and alternating a real stag with a cow bellow would not read as variety, it would read as two
-- animals. The variety is the three REGIONS instead.
--
-- AND WITHOUT THAT ENTRY THIS IS TASK 251 PART 2, UNCHANGED: a uniform pick over whatever ids are
-- there, at the table's own `pitch` and `volume`, with no region. That is the revert path -- delete
-- `clips[122287696922128]` (or the id from `ids`) and the cue is the four bulls again -- and it is
-- reachable BY PARAMETER, so the spec drives both halves without touching what ships.
function ForestTest.roarClip(rng: Random, roar: any?)
	local resolved = roar or ForestTest.ROAR
	local ids = resolved.ids or {}
	if #ids == 0 then
		return nil
	end
	local clip = (resolved.clips or {})[ids[1]]
	local regions = if clip ~= nil then clip.regions or {} else {}
	if clip == nil or #regions == 0 then
		return {
			id = ids[rng:NextInteger(1, #ids)],
			pitch = resolved.pitch,
			volume = resolved.volume,
			fadeSeconds = 0,
		}
	end
	local region = regions[rng:NextInteger(1, #regions)]
	return {
		id = ids[1],
		pitch = clip.pitch or resolved.pitch,
		-- `gain` IS WHY THIS IS A FUNCTION AND NOT A FIELD READ: the three regions are 1.45, 2.63 and
		-- 2.84 times quieter than each other at the source, and `volume` alone would ship one roar
		-- Karen can hear and two she cannot. See the `regions` comment for the measurement.
		volume = resolved.volume * (region.gain or 1),
		from = region.from,
		to = region.to,
		fadeSeconds = clip.fadeSeconds or 0,
	}
end

-- WHAT THIS ROW DOES. One word, defaulted, so no caller writes `row.route or "STRAIGHT"` twice.
function ForestTest.slotRoute(row): string
	if row == nil then
		return "SILENT"
	end
	local route = row.route
	return if type(route) == "string" then route else "STRAIGHT"
end

-- WHAT ONE DRIVE ADDS UP TO at a density: the counts Karen's question asks for, read OFF THE ROWS
-- rather than written down a second time. *"how many where they come how they come how many groups
-- jumping over road"*.
--
-- IT COUNTS NO ANIMALS, and that is deliberate: how many animals a composition weighs is the BOAR
-- system's fact (`Boar.compositionSize`), and this module must not learn it. The spec, the request
-- and `forest_stand.spec` get the animal count by adding this function's `groups` list through that
-- one function.
function ForestTest.driveTally(density: string?, schedule)
	local resolved = schedule or ForestTest.SCHEDULE
	local rows = resolved.drive or {}
	local out = {
		groups = 0,
		silent = 0,
		crossings = 0,
		refusals = 0,
		holds = 0,
		deerGroups = 0,
		boarGroups = 0,
		leapingGroups = 0,
		rows = {},
	}
	for slot = 1, #rows do
		local row = ForestTest.slotAt(slot, density, resolved)
		if row == nil then
			out.silent += 1
			continue
		end
		out.groups += 1
		table.insert(out.rows, row)
		local route = ForestTest.slotRoute(row)
		if route == "BREAK-BACK" then
			out.refusals += 1
		elseif route == "HOLD" then
			out.holds += 1
		else
			-- STRAIGHT, LATERAL and SPLIT all end over the road. SPLIT crosses twice and is still
			-- one group that got across, which is what this column counts.
			out.crossings += 1
		end
		if row.species == "reddeer" then
			out.deerGroups += 1
		else
			out.boarGroups += 1
		end
		if row.leaps == true then
			out.leapingGroups += 1
		end
	end
	return out
end

-- WHERE THE GROUND IS, ASKED OF THE WORLD ITSELF.
--
-- `Boar`'s `field.groundY` is ONE number for a whole field. That is true of the generated map, whose
-- drive corridor is flat, and FALSE here: MEASURED in this place, the ground is y 140 at the road,
-- 149 at 200 studs north and 196 at 400. Every boar released up there was spawned at 140 -- inside
-- the hill -- which is why they stood still and why fresh ones vanished within a second.
--
-- `Runtime:spawn` now asks the world through `world.groundAt`, a seam the boar's own comment
-- predicted and deferred. A world that does not supply one behaves exactly as before.
--
-- A PERSON IS NOT GROUND, AND IT IS THE SAME RULE `ForestTest.roomToStand` ALREADY MAKES
-- (*"A PLAYER IS NOT AN OBSTACLE"*). One rule, one function, two callers: a question about a person
-- answered twice is how two systems end up disagreeing about what a person is.
--
-- IT WALKS UP, because a hit is not always the character itself: a hat's `Handle` is parented to an
-- `Accessory`, which is parented to the character, so the hit's immediate `Parent` has no Humanoid
-- and a parent-only test would call a hat the ground.
--
-- Returns the character MODEL (what a raycast filter needs), or nil.
function ForestTest.characterOf(instance: Instance?): Model?
	local node: Instance? = instance
	while node ~= nil and node ~= Workspace do
		if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") ~= nil then
			return node :: Model
		end
		node = node.Parent
	end
	return nil
end

-- HOW MANY BODIES ONE COLUMN MAY HOLD before this gives up and answers "no ground here". Eight is
-- already absurd -- a drive is at most sixteen players and they are spread along a line -- and the
-- bound exists so a raycast loop can never be unbounded, not because anybody expects to use it.
ForestTest.MAX_BODIES_IN_A_COLUMN = 8

-- WHAT `groundAt` RAYS STRAIGHT THROUGH, as data rather than as a literal in the loop below
-- (design `drive-places.md` 10.1). `DrivePlaces` joined the list in task 193 and the reason is a
-- defect the Architect found before it shipped: the planter's own trees keep `CanQuery = true` (a
-- trunk must stop a bullet), and this same function is the CANOPY half of `Markers.groundFor` --
-- where a disagreement of one stud with the terrain reader REFUSES A STAND, and all six refused is
-- `WAITING forest:stands (0 of 6)` for ever. A tree we planted must not be allowed to answer the
-- question "where is the ground".
--
-- `places.spec` asserts that `Places.FOLDER` is in this list, so the name exists once and the list
-- cannot drift from the folder it is about.
ForestTest.GROUND_IGNORE = table.freeze({ "OurForest", "Foliage", "Boars", "DrivePlaces" })

-- IT IGNORES THE FOREST, THE ANIMALS AND THE PEOPLE. A boar must be put on the GROUND, not on a
-- fern, not on the back of the boar spawned a moment earlier -- and not on a player's head.
--
-- THE LAST ONE IS MEASURED AND IT STOPPED A PLAYTEST (task 158a(f), fixed in task 158). The drive
-- PUTS a beater on the beater pad and holds her there, and the next read of the markers cast this
-- ray down the same column: it hit `<player>.Head` at y 161.09 where the terrain is 155.81, a
-- 5.3-stud delta against `Markers.GROUND_TOLERANCE_STUDS` of 1 -- so `forest:beater-start` was
-- refused, and the Forest Test sat in `Waiting` for ever after its first drive. A standing person
-- must not change the world's answer about where the ground is.
--
-- A CHARACTER IS SKIPPED AND THE RAY CARRIES ON, rather than every character being excluded up
-- front: this module is shared and knows nothing about `Players`, and the rule it applies is about
-- what was HIT -- which covers a dog, an NPC or anything else with a Humanoid, the day one exists.
-- `fromY` IS WHERE THE RAY STARTS, AND IT IS THE WHOLE OF TASK 192 ROUND 2 (Reviewer, round 1,
-- finding 1). A ray that starts 600 studs up answers *"what is the first solid thing from the sky"*,
-- and indoors that is the LODGE'S ROOF: a player standing at the shop counter measured 7-15 studs
-- *"under the ground"* and the floor net teleported him out four times a second. A DOWNWARD RAY CAN
-- ONLY HIT WHAT IS BELOW ITS ORIGIN, so asking from just above the point asks the only question that
-- was ever meant -- *what would this body land on* -- and nothing overhead can answer it.
--
-- `nil` IS THE OLD 600, unchanged, for every caller that is asking about a COLUMN rather than about
-- a body: `Markers.groundFor`, `Bots`, `Lobby.tryBuild` and the boar world all mean "where is the
-- ground at this x,z" with no body anywhere near it.
function ForestTest.groundAt(x: number, z: number, fromY: number?): number?
	local from = if type(fromY) == "number" then fromY :: number else 600
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, name in ipairs(ForestTest.GROUND_IGNORE) do
		local found = Workspace:FindFirstChild(name)
		if found then
			table.insert(ignore, found)
		end
	end
	params.FilterDescendantsInstances = ignore
	for _ = 1, ForestTest.MAX_BODIES_IN_A_COLUMN + 1 do
		local hit = Workspace:Raycast(Vector3.new(x, from, z), Vector3.new(0, -1200, 0), params)
		if hit == nil then
			return nil
		end
		local character = ForestTest.characterOf(hit.Instance)
		if character == nil then
			return hit.Position.Y
		end
		table.insert(ignore, character)
		params.FilterDescendantsInstances = ignore
	end
	return nil
end

-- HOW MANY BOARS MAY EXIST AT ONCE. Karen: *"make them a lot not too much to break but enough to
-- test"*. The number itself is MEASURED on the machine and lives in the server system's own
-- report, not guessed here; this is the ceiling it may not exceed whatever it measures.
ForestTest.MAX_BOARS = 60

return ForestTest
