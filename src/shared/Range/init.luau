-- Range (shared): the lobby shooting range's FROZEN DATA and its PURE ARITHMETIC. No Instances, no
-- state, no clock -- so a server spec drives every line of it with no client and no world, which is
-- the `ReplicatedStorage.Lobby` / `ReplicatedStorage.ForestTest` shape.
--
-- Design: docs/design/shooting-range.md sections 3, 4.1 and 8.4. Task 298 phase B, step B2.
--
-- Owner (CLAUDE.md rule 3): the range's DATA -- names, words, the lane arithmetic, the whitelists --
-- has NO run-time writer; it is edited by the Builder in git. The geometry is
-- `ServerScriptService.Range.Build`'s and the state is `ServerScriptService.Range`'s.

local Range = {}

Range.FOLDER_NAME = "Range"
Range.MAT_NAME = "Mat"
Range.PROMPT_NAME = "RangePrompt"
Range.REMOTES_NAME = "Remotes"

-- THE WORDS, because they cross the wire in step B4 and a second spelling is a silent refusal
-- (`Lobby.ROLE`'s rule). `STAND` is Karen's, 2026-10-27: *"walk trot stand run"* -- a target held
-- broadside at the lane's middle, which isolates AIM from LEAD.
Range.WORD = {
	WALK = "walk",
	TROT = "trot",
	STAND = "stand",
	RUN = "run",
}

-- Every dimension in ONE table, read by `Build`, which invents none (`TestArena.LAYOUT`'s rule).
-- Offsets are relative to the anchor: +x east, +z north, Y from the shelf. The lane runs along X
-- and the shooter looks along +Z -- one axis for the crossing, one for the range, so the ballistic
-- lead and the measured crossing are perpendicular and neither contaminates the other.
Range.LAYOUT = {
	folderName = Range.FOLDER_NAME,
	-- 35 m at `Report.CONFIG.METRES_PER_STUD` 0.28. 89 (25 m) and 179 (50 m) are rows for later.
	DISTANCE_STUDS = 125,
	-- 11.2 m of open lane: 8.89 / 3.64 / 1.67 s at walk / trot / run (design section 13, TARGET 3).
	WINDOW_STUDS = 40,
	-- Room to turn around behind a screen. A FIRST VALUE, confirmed by the measured crossing time.
	APRON_STUDS = 20,
	SPOT_COUNT = 1,
	SPOT_SPACING_STUDS = 24,
	-- THE SCREENS STAND BEYOND THE ENDS OF THE LANE, NOT ON THEM, AND THIS IS A MEASUREMENT AND NOT
	-- A PREFERENCE (task 298, step B2). Design section 4.1 puts them at `+-(WINDOW/2 + APRON)`, which
	-- IS the turn-around point: built that way in DEV the target walked to the east end, hit the
	-- screen's west face and STOPPED there -- measured at x = +32.2 for 30 s, 7.8 studs short of an
	-- end it could never reach, so no leg ever finished and nothing ever crossed. `beyondStuds` is
	-- the clearance that puts the turn in FRONT of the screen, where the design's own sentence wants
	-- it: *"room to turn around behind a screen"*.
	SCREEN = { size = Vector3.new(10, 8, 1), beyondStuds = 6, color = Color3.fromRGB(96, 88, 76) },
	BERM = { size = Vector3.new(160, 10, 6), behindStuds = 12, color = Color3.fromRGB(104, 84, 62) },
	MAT = { size = Vector3.new(8, 1, 8), color = Color3.fromRGB(70, 82, 70) },
	PLATE = { minSpan = 120, marginStuds = 80, thickness = 4, color = Color3.fromRGB(150, 150, 150) },
	PROMPT = {
		ActionText = "RANGE",
		ObjectText = "SHOOTING RANGE",
		MaxActivationDistance = 12,
		HoldDuration = 0,
	},
}

-- A WORLD HAS A RANGE WHEN, AND ONLY WHEN, THERE IS A ROW FOR IT -- `Lobby.anchorFor`'s rule
-- verbatim, and for its stated reason: the answer is never found by sniffing `Workspace`, because
-- *"a predicate like that lies the moment a run half-finishes"* (`ArenaBoot`).
--
-- THERE IS NO `forest-test` ROW YET, AND THAT IS THIS STEP'S SCOPE rather than an omission: the
-- forest anchor is a MEASUREMENT over Karen's own ground (design section 4.2) and it belongs to
-- step B6. Until that row exists `Range.anchorFor("forest-test")` is nil and her place has no range.
Range.ANCHORS = {
	-- The DEV place, where the harness runs. Its own anchored ground plate (`plate = true`), clear
	-- of the generated map: x = 1200 is outside `Map.FIELD.bounds` (maxX 620) and outside
	-- `Map.SIZE_STUDS / 2` = 1024, so it touches neither the drive corridor nor one generated prop.
	["map:v1"] = { x = 1200, z = 0, y = 0, plate = true },
}

function Range.anchorFor(world: string?)
	if type(world) ~= "string" then
		return nil
	end
	local row = Range.ANCHORS[world]
	if row == nil then
		return nil
	end
	return table.clone(row)
end

-- THE ONE WHITELIST, read by both sides (`Lobby.roleAllowed`'s shape).
function Range.paceAllowed(word: any): boolean
	if type(word) ~= "string" then
		return false
	end
	for _, allowed in pairs(Range.WORD) do
		if word == allowed then
			return true
		end
	end
	return false
end

-- ...and the general door, so steps B3 and B4 have one place to ask. An unknown KIND is false and
-- never true: a whitelist whose default is "yes" is not a whitelist.
function Range.optionAllowed(kind: string, value: any): boolean
	if kind == "pace" then
		return Range.paceAllowed(value)
	elseif kind == "spot" then
		return type(value) == "number"
			and value == math.floor(value)
			and value >= 1
			and value <= Range.LAYOUT.SPOT_COUNT
	end
	return false
end

-- THE LANE, AND ITS ONE ARITHMETIC. An odd leg runs to the east end and an even leg back to the
-- west: ISSF's mandatory direction change (design section 14, source 1), which is the whole reason
-- a lane that only ever ran one way trains one lead.
function Range.laneLength(layout): number
	layout = layout or Range.LAYOUT
	return layout.WINDOW_STUDS + 2 * layout.APRON_STUDS
end

function Range.laneCentre(anchor: Vector3, layout): Vector3
	layout = layout or Range.LAYOUT
	return Vector3.new(anchor.X, anchor.Y, anchor.Z + layout.DISTANCE_STUDS)
end

function Range.laneEnds(anchor: Vector3, layout, leg: number): Vector3
	layout = layout or Range.LAYOUT
	local centre = Range.laneCentre(anchor, layout)
	local half = Range.laneLength(layout) / 2
	local east = (leg % 2) == 1
	return Vector3.new(centre.X + (if east then half else -half), centre.Y, centre.Z)
end

-- WHERE A SCREEN STANDS: beyond the end of the lane by its own half-width plus the clearance, so
-- nothing the range builds is ever inside the corridor the target walks (`range.spec` asserts it).
function Range.screenPosition(anchor: Vector3, layout, leg: number): Vector3
	layout = layout or Range.LAYOUT
	local at = Range.laneEnds(anchor, layout, leg)
	local centre = Range.laneCentre(anchor, layout)
	local beyond = layout.SCREEN.size.X / 2 + layout.SCREEN.beyondStuds
	local sign = if at.X >= centre.X then 1 else -1
	return Vector3.new(at.X + sign * beyond, at.Y, at.Z)
end

function Range.matPosition(anchor: Vector3, spot: number, layout): Vector3
	layout = layout or Range.LAYOUT
	local index = math.max(1, math.floor(spot or 1))
	local offset = (index - 1) * layout.SPOT_SPACING_STUDS
	return Vector3.new(anchor.X + offset, anchor.Y, anchor.Z)
end

-- WHICH MAT A MAN IS STANDING ON, or nil. Pure, so `Range.mayShoot` (step B3) is one position read
-- and one lookup, and never a sniff of `Workspace`.
function Range.spotAt(anchor: Vector3?, position: Vector3?, layout): number?
	if typeof(anchor) ~= "Vector3" or typeof(position) ~= "Vector3" then
		return nil
	end
	layout = layout or Range.LAYOUT
	local halfX = layout.MAT.size.X / 2
	local halfZ = layout.MAT.size.Z / 2
	for spot = 1, layout.SPOT_COUNT do
		local mat = Range.matPosition(anchor, spot, layout)
		if math.abs(position.X - mat.X) <= halfX and math.abs(position.Z - mat.Z) <= halfZ then
			return spot
		end
	end
	return nil
end

-- HOW LONG A CROSSING OF THE WINDOW TAKES at a speed. `math.huge` for a standing target, which is
-- the honest answer and not zero: a target that does not move never crosses.
function Range.crossingSeconds(windowStuds: number, speed: number): number
	if type(windowStuds) ~= "number" or type(speed) ~= "number" or speed <= 0 then
		return math.huge
	end
	return windowStuds / speed
end

-- THE RANGE RUNTIME'S FIELD (design section 5): the lane's rectangle plus slack, with an `exitZ`
-- far BEHIND the firing line so `Brain:_outcome` can never report `escaped` or `outOfBounds` for a
-- target doing exactly what it was told. The lobby sits outside the drive's field -- x 2230..3830,
-- z -2477..-1197, exitZ -2377, against the lobby anchor (2850, -2950) -- which is why this field
-- exists at all rather than the drive's being borrowed.
Range.FIELD_SLACK_STUDS = 60
Range.FIELD_EXIT_BEHIND_STUDS = 400

function Range.fieldFor(anchor: Vector3, layout)
	layout = layout or Range.LAYOUT
	local slack = Range.FIELD_SLACK_STUDS
	local half = Range.laneLength(layout) / 2
	local spots = (layout.SPOT_COUNT - 1) * layout.SPOT_SPACING_STUDS
	return {
		bounds = {
			minX = anchor.X - half - slack,
			maxX = anchor.X + half + slack + spots,
			minZ = anchor.Z - slack,
			maxZ = anchor.Z + layout.DISTANCE_STUDS + slack,
		},
		exitZ = anchor.Z - Range.FIELD_EXIT_BEHIND_STUDS,
		groundY = anchor.Y,
	}
end

-- DEEP, AND NOT `table.freeze` (which is shallow): `src/shared/Report/init.luau`'s precedent, and
-- `Lobby`'s stated reason -- *"this repo has already paid for that once"*. "No run-time writer" is a
-- claim this enforces rather than asserts, and it has to be deep here because the server owner
-- re-exports `Range.LAYOUT`, so one write anywhere would move the lane for both readers.
function Range.deepFreeze(value)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in pairs(value) do
			Range.deepFreeze(child)
		end
		table.freeze(value)
	end
	return value
end

Range.deepFreeze(Range.LAYOUT)
Range.deepFreeze(Range.ANCHORS)
Range.deepFreeze(Range.WORD)

return Range
