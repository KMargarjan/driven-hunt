--!strict
-- Viewmodel: the first-person POSE DATA, and the pure arithmetic that reads it. It is NOT the drawn
-- gun -- that is `StarterPlayerScripts.Camera.Viewmodel`, the one writer of the model under
-- workspace.CurrentCamera. This module holds no Instances, writes nothing, and is required by both
-- sides so a SERVER spec can drive it with no client at all.
--
-- THE ONE SOURCE OF EVERY POSE NUMBER IS `poses.json` (task 98). Karen, 2026-10-01, after task 97
-- was stopped: tuning a pose by editing Luau, running the gate and asking for a review cost hours
-- per tweak. So the numbers are DATA: `src/shared/Viewmodel/poses.json`, which Rojo syncs as the
-- ModuleScript `ReplicatedStorage.Viewmodel.poses`, and `tools/pose.py` is the one writer of the
-- live override that replaces any of them inside a running Studio session.
--
-- ONE POSE SET SINCE TASK 114 (version 3). Version 2 carried two: the top level for the gun this
-- repo drew from Task 71, and `newGun` for Karen's model B behind the gun flag. She accepted
-- model B, so its three poses ARE the poses -- moved up to the top level with every number
-- byte-identical -- and `view` no longer takes a gun to choose.
--
-- `Viewmodel.view(data)` is what makes that ONE source rather than two: `Camera.Config` publishes
-- the flat names the camera has always used (`CARRY_PITCH_DEG`, `EYE_RELIEF_STUDS`, ...) by CALLING
-- this function on the data. There is no second copy of a number to go stale -- the names are a
-- view, and `Camera.Poses` rebuilds exactly the same view when an override is live.
--
-- WHY JSON AND NOT A LUAU TABLE. A tool has to rewrite these numbers (`tools/pose.py save`) and a
-- tool that rewrites Luau has to keep stylua happy; JSON it can read, change and write with the
-- standard library, and the harness compares the synced ModuleScript against this exact file by
-- requiring a parentless clone and encoding what it returns (tools/studio_mcp.py, the "json" kind).
--
-- Pattern: animation/pose data outside the code, played by a small state machine over keyframes --
-- what every Roblox first-person viewmodel does with Motor6D goals or a Keyframe sequence, written
-- here as plain numbers because this gun is parts and meshes under the camera rather than a rigged
-- character (docs/research/2026-10-01-poses-as-data.md, sources 1-3).
--
-- Note: docs/research/2026-10-01-poses-as-data.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Viewmodel = {}

-- THE LIVE OVERRIDE'S ONE ATTRIBUTE, on this module's own Instance. ONE attribute holding a JSON
-- object rather than one attribute per number, for two reasons: a Roblox attribute name cannot
-- contain a dot, so `aim.gun.pos.z` could not be one; and clearing a tuning session has to be a
-- single write, or a half-cleared override is a build nobody can name.
--
-- It is set on the SERVER of a RUNNING session and replicates, so both clients of a two-player test
-- see the same numbers. `tools/pose.py` is its only writer (GAME_DESIGN.md owners).
Viewmodel.OVERRIDE_ATTRIBUTE = "DHPose"
-- The one key in that object that is not a pose path: which pose to HOLD, for a screenshot.
Viewmodel.HOLD_KEY = "hold"
-- ...AND THE SECOND ONE (task 102): a number `tools/pose.py fit` bumps on every candidate it writes,
-- so the tool can tell whether the reading it just took is of the pose it just asked for or of the
-- one before it. A search that reads one frame late searches a blurred objective and converges on
-- nothing. It is not a pose number, it changes nothing that is drawn, and `Viewmodel.merge` skips it
-- exactly as it skips the hold.
Viewmodel.SERIAL_KEY = "serial"
Viewmodel.HOLDS = table.freeze({ "carry", "raise", "aim", "reload" })
-- The only easing `Mode.ease` implements. A spec asserts the data asks for no other one, so a typo
-- fails the harness rather than silently becoming a linear swing nobody chose.
Viewmodel.EASING = "quadOut"

-- ---------------------------------------------------------------- the data

-- A parentless CLONE is not needed here: this is a production require of a sibling module inside the
-- same Luau environment, which is exactly the case `require` caches correctly. The clone trick
-- belongs to the Edit-mode MCP context, where Rojo rewrites the Source of a module that was already
-- required (tools/studio_mcp.py, FRESH_FLAGS).
local loaded = require(script:WaitForChild("poses")) :: any

Viewmodel.DATA = Shotgun.deepFreeze(loaded)

-- ---------------------------------------------------------------- pure helpers

local function isNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Deep copy, because every pose read is frozen and the override has to produce a NEW table. Arrays
-- and maps are both plain Luau tables, so one walk does both.
local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, inner in pairs(value) do
		out[key] = copy(inner)
	end
	return out
end

Viewmodel.copy = copy

-- A dotted path's segments, with a numeric segment turned into a number so it indexes an array.
-- "raise.keyframes.1.gun.pos.z" reaches into `keyframes[1]`.
local function segments(path: string): { any }
	local out = {}
	for part in string.gmatch(path, "[^%.]+") do
		local index = tonumber(part)
		table.insert(out, if index ~= nil and index == math.floor(index) then index else part)
	end
	return out
end

Viewmodel.segments = segments

-- EVERY NUMERIC LEAF, as dotted path -> value. It is the set `tools/pose.py set` validates against
-- and what `show` prints, so "which paths exist" has one answer and it is the data's own shape
-- rather than a list in a tool that can drift from it.
--
-- STRINGS ARE DELIBERATELY NOT IN IT (`raise.easing`, and `version` is skipped whole): a pose
-- session tunes numbers, and the one easing this repo implements is asserted by a spec instead.
function Viewmodel.paths(data: any): { [string]: number }
	local out: { [string]: number } = {}
	local function walk(node: any, prefix: string)
		if type(node) ~= "table" then
			return
		end
		for key, value in pairs(node) do
			local path = if prefix == "" then tostring(key) else prefix .. "." .. tostring(key)
			if isNumber(value) then
				out[path] = value
			elseif type(value) == "table" then
				walk(value, path)
			end
		end
	end
	for key, value in pairs(data) do
		if key ~= "version" and type(value) == "table" then
			walk(value, tostring(key))
		end
	end
	return out
end

-- THE OVERRIDE APPLIED, as a new deep-frozen table -> (data, problems). PURE: the caller reads the
-- attribute, this decides what it means, and a spec drives every refusal with no Studio at all.
--
-- A path that does not already exist as a NUMBER is refused rather than created. That is the whole
-- safety of live tuning: `aim.cheekDeg` typed as `aim.cheeckDeg` would otherwise add a field
-- nothing reads, and the Director would be looking at an unchanged gun wondering why.
function Viewmodel.merge(data: any, overrides: { [string]: any }?): (any, { string })
	local problems = {}
	local out = copy(data)
	if overrides == nil then
		return Shotgun.deepFreeze(out), problems
	end
	local known = Viewmodel.paths(data)
	local ordered = {}
	for path in pairs(overrides) do
		table.insert(ordered, path)
	end
	table.sort(ordered) -- so two runs report the same problems in the same order
	for _, path in ipairs(ordered) do
		local value = overrides[path]
		if path == Viewmodel.HOLD_KEY or path == Viewmodel.SERIAL_KEY then
			continue -- not pose numbers; `Viewmodel.hold` reads one and `tools/pose.py fit` the other
		end
		if known[path] == nil then
			table.insert(problems, string.format("%s is not a pose number", path))
		elseif not isNumber(value) then
			table.insert(problems, string.format("%s = %s is not a finite number", path, tostring(value)))
		else
			local parts = segments(path)
			local node = out
			for index = 1, #parts - 1 do
				node = node[parts[index]]
			end
			node[parts[#parts]] = value
		end
	end
	return Shotgun.deepFreeze(out), problems
end

-- WHICH POSE IS BEING HELD for a screenshot, or nil. One of `Viewmodel.HOLDS`; anything else is nil,
-- because a hold nobody implements must leave the gun being played rather than frozen in a pose the
-- code made up.
function Viewmodel.hold(overrides: { [string]: any }?): string?
	local wanted = overrides and overrides[Viewmodel.HOLD_KEY]
	if type(wanted) ~= "string" then
		return nil
	end
	for _, name in ipairs(Viewmodel.HOLDS) do
		if name == wanted then
			return name
		end
	end
	return nil
end

-- ---------------------------------------------------------------- the shape check

local function vectorProblems(where: string, node: any, keys: { string }, problems: { string })
	if type(node) ~= "table" then
		table.insert(problems, where .. " is missing")
		return
	end
	for _, key in ipairs(keys) do
		if not isNumber(node[key]) then
			table.insert(problems, string.format("%s.%s is not a number", where, key))
		end
	end
end

local function handProblems(where: string, node: any, problems: { string })
	if type(node) ~= "table" then
		table.insert(problems, where .. " is missing")
		return
	end
	vectorProblems(where .. ".pos", node.pos, { "x", "y", "z" }, problems)
	vectorProblems(where .. ".rot", node.rot, { "yaw", "pitch", "twist" }, problems)
end

local function gunProblems(where: string, node: any, problems: { string })
	if type(node) ~= "table" then
		table.insert(problems, where .. " is missing")
		return
	end
	vectorProblems(where .. ".pos", node.pos, { "x", "y", "z" }, problems)
	vectorProblems(where .. ".rot", node.rot, { "x", "y", "z" }, problems)
end

-- EVERY WAY `poses.json` CAN BE WRONG, in one list. `tests/server/viewmodel_poses.spec.luau` asserts
-- this is empty for the shipped file, so a missing field, a typo'd easing or a keyframe out of order
-- FAILS THE HARNESS and therefore blocks the merge gate -- the same shape as the flag `expires`
-- check (docs/design/feature-flags.md). A pose file that half-loads would otherwise show up as a gun
-- in the wrong place with nothing saying why.
function Viewmodel.validate(data: any): { string }
	local problems = {}
	if type(data) ~= "table" then
		return { "poses.json did not load as a table" }
	end
	-- VERSION 3 IS ONE POSE SET (task 114). Version 2 carried two -- the top level for the gun this
	-- repo drew from Task 71, and `newGun` for Karen's model B behind the gun flag. She accepted
	-- model B, the flag retired, and its three poses moved up to the top level with every number
	-- byte-identical. The number is bumped because the SHAPE changed: a version-2 file loaded by this
	-- code would silently be read as the retired gun's poses, which is the one failure a pose file
	-- must not have.
	if data.version ~= 3 then
		table.insert(problems, "version must be 3")
	end
	-- THE POSES THAT ARE ABOUT THE GUN -- carry, aim and reload. The raise's timings and keyframes and
	-- the recoil spring sit beside them rather than inside them, because they are properties of the
	-- player's hands and the shot rather than of the gun.
	for _, name in ipairs({ "carry", "reload" }) do
		local pose = data[name]
		if type(pose) ~= "table" then
			table.insert(problems, name .. " is missing")
		else
			gunProblems(name .. ".gun", pose.gun, problems)
			handProblems(name .. ".right", pose.right, problems)
			handProblems(name .. ".left", pose.left, problems)
		end
	end
	local aim = data.aim
	if type(aim) ~= "table" then
		table.insert(problems, "aim is missing")
	else
		-- THE AIMED GUN POSE IS GEOMETRY, NOT A POSITION (task 90): it is solved from the gun's own
		-- `Sight` attachment, so the data carries the eye relief and the cheek angle and no x/y/z.
		if not isNumber(aim.eyeReliefStuds) or aim.eyeReliefStuds <= 0 then
			table.insert(problems, "aim.eyeReliefStuds must be a positive number")
		end
		if not isNumber(aim.cheekDeg) then
			table.insert(problems, "aim.cheekDeg is not a number")
		end
		handProblems("aim.right", aim.right, problems)
		handProblems("aim.left", aim.left, problems)
	end
	-- THE LOOK BLOCK (task 102). One light, four numbers plus a colour, and it is validated here for
	-- the same reason every pose is: `Camera.Config` reads it at boot, so a missing field is a
	-- viewmodel with no light rather than an error anybody can trace.
	local look = data.look
	if type(look) ~= "table" or type(look.fill) ~= "table" then
		table.insert(problems, "look.fill is missing")
	else
		local fill = look.fill
		if not isNumber(fill.brightness) or fill.brightness < 0 then
			table.insert(problems, "look.fill.brightness must be a number at or above 0")
		end
		if not isNumber(fill.rangeStuds) or fill.rangeStuds <= 0 then
			table.insert(problems, "look.fill.rangeStuds must be a positive number")
		end
		vectorProblems("look.fill.offset", fill.offset, { "x", "y", "z" }, problems)
		vectorProblems("look.fill.color", fill.color, { "r", "g", "b" }, problems)
		if type(fill.color) == "table" then
			for _, channel in ipairs({ "r", "g", "b" }) do
				local value = fill.color[channel]
				if isNumber(value) and (value < 0 or value > 255) then
					table.insert(problems, "look.fill.color." .. channel .. " is outside 0-255")
				end
			end
		end
	end
	local raise = data.raise
	if type(raise) ~= "table" then
		table.insert(problems, "raise is missing")
	else
		if raise.easing ~= Viewmodel.EASING then
			table.insert(
				problems,
				string.format("raise.easing is %s; only %s is implemented", tostring(raise.easing), Viewmodel.EASING)
			)
		end
		for _, key in ipairs({ "raiseSeconds", "lowerSeconds" }) do
			if not isNumber(raise[key]) or raise[key] <= 0 then
				table.insert(problems, "raise." .. key .. " must be a positive number")
			end
		end
		if type(raise.keyframes) ~= "table" then
			table.insert(problems, "raise.keyframes is missing (use [] for a plain carry-to-aim swing)")
		else
			local previous = 0
			for index, frame in ipairs(raise.keyframes) do
				local where = string.format("raise.keyframes.%d", index)
				if type(frame) ~= "table" then
					table.insert(problems, where .. " is not a keyframe")
					continue
				end
				-- STRICTLY BETWEEN THE TWO ENDS AND IN ORDER. A mid keyframe at t = 0 or t = 1 would
				-- replace the carry or the aim without saying so, and one out of order would make the
				-- swing run backwards for a stretch.
				if not isNumber(frame.t) or frame.t <= previous or frame.t >= 1 then
					table.insert(problems, string.format("%s.t must be a number in (%.3f, 1)", where, previous))
				else
					previous = frame.t
				end
				gunProblems(where .. ".gun", frame.gun, problems)
				-- The hands are OPTIONAL in a mid keyframe: left out, they take whatever the plain
				-- carry-to-aim blend gives at that `t`, which is what `Mode.handFrame` does.
				if frame.right ~= nil then
					handProblems(where .. ".right", frame.right, problems)
				end
				if frame.left ~= nil then
					handProblems(where .. ".left", frame.left, problems)
				end
			end
		end
	end
	local fire = data.fire
	if type(fire) ~= "table" then
		table.insert(problems, "fire is missing")
	else
		for _, key in ipairs({
			"gunPitchDeg",
			"gunBackStuds",
			"camPitchDeg",
			"frequencyHz",
			"dampingRatio",
			"maxGunPitchDeg",
			"maxGunBackStuds",
			"maxCamPitchDeg",
		}) do
			if not isNumber(fire[key]) then
				table.insert(problems, "fire." .. key .. " is not a number")
			end
		end
		if isNumber(fire.frequencyHz) and fire.frequencyHz <= 0 then
			table.insert(problems, "fire.frequencyHz must be positive")
		end
	end
	local reload = data.reload
	if type(reload) == "table" then
		for _, key in ipairs({ "openSeconds", "closeSeconds", "openDeg" }) do
			if not isNumber(reload[key]) or reload[key] <= 0 then
				table.insert(problems, "reload." .. key .. " must be a positive number")
			end
		end
		vectorProblems("reload.hingeStuds", reload.hingeStuds, { "x", "y", "z" }, problems)
		-- THE LEFT HAND'S LOADING MOVE (task 111), CHECKED SINCE TASK 114. It was `newGun.reload.load`
		-- and only the new gun had one, so `view` handed `SHELL_LOAD` through as nil for the other and
		-- nothing could be asserted about its shape. One gun means one answer: the block is there, and
		-- a missing field in it is a hand that goes to `CFrame.new(nil)` rather than to a chamber.
		local load = reload.load
		if type(load) ~= "table" then
			table.insert(problems, "reload.load is missing")
		else
			for _, key in ipairs({ "fetchSeconds", "carrySeconds", "seatSeconds", "returnSeconds" }) do
				if not isNumber(load[key]) or load[key] <= 0 then
					table.insert(problems, "reload.load." .. key .. " must be a positive number")
				end
			end
			for _, key in ipairs({ "fetch", "above", "seat" }) do
				handProblems("reload.load." .. key, load[key], problems)
			end
			vectorProblems("reload.load.shellInHand", load.shellInHand, { "x", "y", "z" }, problems)
		end
		local shells = reload.shells
		if type(shells) ~= "table" then
			table.insert(problems, "reload.shells is missing")
		else
			for _, key in ipairs({ "ejectSeconds", "ejectRiseStuds", "feedSeconds", "feedFromStuds" }) do
				if not isNumber(shells[key]) then
					table.insert(problems, "reload.shells." .. key .. " is not a number")
				end
			end
		end
	end
	return problems
end

-- ---------------------------------------------------------------- the view the camera reads

local function vec(node: any): Vector3
	return Vector3.new(node.x, node.y, node.z)
end

-- 0-255 CHANNELS, because that is what a person reading `look.fill.color` in a JSON file expects and
-- what every measured pixel in this repo's comments is written in.
local function col(node: any): Color3
	return Color3.fromRGB(node.r, node.g, node.b)
end

Viewmodel.vec = vec

-- THE FLAT NAMES THE CAMERA HAS ALWAYS USED, computed from the data. `Camera.Config` merges this in
-- and `Camera.Poses` recomputes it whenever the live override changes, so there is exactly ONE
-- writer of every one of these numbers and it is `poses.json`.
--
-- Vector3 is built HERE and nowhere else, like the degree-to-radian conversion in `Camera.Mode`:
-- three numbers in a JSON object become one Vector3 at one site (the rule the Task 19 cone-unit
-- defect bought).
-- ONE SET SINCE TASK 114: this took a `newGun` boolean while the flag chose between two pose sets,
-- and there is one gun now, so there is nothing to choose and no way for `Camera.Config` and
-- `Camera.Poses` to resolve different guns.
function Viewmodel.view(data: any): { [string]: any }
	local loadBlock = data.reload.load
	local fire = data.fire
	return {
		-- the carry pose (first person, blend 0)
		VIEWMODEL_CARRY_POS_STUDS = vec(data.carry.gun.pos),
		CARRY_PITCH_DEG = data.carry.gun.rot.x,
		CARRY_YAW_DEG = data.carry.gun.rot.y,
		CARRY_ROLL_DEG = data.carry.gun.rot.z,
		-- the hands at the carry, which is where `Mode.rightHandOffset` and `Mode.leftHandOffset`
		-- answer; the aimed and reloading hands come off `POSES` in `Mode.handFrame`.
		HAND_RIGHT_POS_STUDS = vec(data.carry.right.pos),
		HAND_RIGHT_YAW_DEG = data.carry.right.rot.yaw,
		HAND_RIGHT_PITCH_DEG = data.carry.right.rot.pitch,
		HAND_RIGHT_TWIST_DEG = data.carry.right.rot.twist,
		HAND_LEFT_POS_STUDS = vec(data.carry.left.pos),
		HAND_LEFT_YAW_DEG = data.carry.left.rot.yaw,
		HAND_LEFT_PITCH_DEG = data.carry.left.rot.pitch,
		HAND_LEFT_TWIST_DEG = data.carry.left.rot.twist,
		-- THE VIEWMODEL'S OWN FILL LIGHT (task 102), and it is `look`, not a pose: it is the same
		-- light whichever gun is in the hands, which is why it is `look` and not part of a pose.
		--
		-- IT IS DATA BECAUSE IT WAS MEASURED TO BE THE DEFECT. Task 100 put the action at an albedo
		-- of (118, 120, 122) and the aimed capture still read it at (155, 161, 173) -- a pale
		-- blue-grey slab -- and the difference is this light, inches from the lens. A colour that is
		-- right in the file and wrong on screen is exactly the thing the content lane exists for:
		-- `python tools/pose.py set look.fill.brightness 0.3`, look, `save`.
		VIEWMODEL_FILL_BRIGHTNESS = data.look.fill.brightness,
		VIEWMODEL_FILL_RANGE_STUDS = data.look.fill.rangeStuds,
		VIEWMODEL_FILL_COLOR = col(data.look.fill.color),
		VIEWMODEL_FILL_OFFSET_STUDS = vec(data.look.fill.offset),
		-- the aimed pose, solved from the gun's own sight
		EYE_RELIEF_STUDS = data.aim.eyeReliefStuds,
		ADS_CHEEK_DEG = data.aim.cheekDeg,
		-- the swing between them
		AIM_RAISE_SECONDS = data.raise.raiseSeconds,
		AIM_LOWER_SECONDS = data.raise.lowerSeconds,
		-- the shot's kick
		-- THE SHOT (task 112). Karen's order: finish the weapon before the animal, and shooting is
		-- next. `fire` is this gun's kick -- harder than the retired gun's, which is what the target
		-- video shows -- plus its flash, its smoke and the three volumes. The RECOIL_* names below
		-- are the spring's; the `FIRE` block below carries the cosmetics.
		RECOIL_GUN_PITCH_DEG = fire.gunPitchDeg,
		RECOIL_GUN_BACK_STUDS = fire.gunBackStuds,
		RECOIL_CAM_PITCH_DEG = fire.camPitchDeg,
		RECOIL_FREQUENCY_HZ = fire.frequencyHz,
		RECOIL_DAMPING_RATIO = fire.dampingRatio,
		RECOIL_MAX_GUN_PITCH_DEG = fire.maxGunPitchDeg,
		RECOIL_MAX_GUN_BACK_STUDS = fire.maxGunBackStuds,
		RECOIL_MAX_CAM_PITCH_DEG = fire.maxCamPitchDeg,
		-- the break-open reload
		BREAK_OPEN_SECONDS = data.reload.openSeconds,
		BREAK_CLOSE_SECONDS = data.reload.closeSeconds,
		BREAK_OPEN_DEG = data.reload.openDeg,
		BREAK_HINGE_STUDS = vec(data.reload.hingeStuds),
		BREAK_POSE_STUDS = vec(data.reload.gun.pos),
		BREAK_POSE_PITCH_DEG = data.reload.gun.rot.x,
		BREAK_POSE_YAW_DEG = data.reload.gun.rot.y,
		BREAK_POSE_ROLL_DEG = data.reload.gun.rot.z,
		SHELL_EJECT_SECONDS = data.reload.shells.ejectSeconds,
		SHELL_EJECT_RISE_STUDS = data.reload.shells.ejectRiseStuds,
		SHELL_FEED_SECONDS = data.reload.shells.feedSeconds,
		SHELL_FEED_FROM_STUDS = data.reload.shells.feedFromStuds,
		-- THE LEFT HAND'S LOADING MOVE (task 111). Karen: "can we make that i push ammo inside
		-- pipes? just moving hand". `Viewmodel.validate` requires the whole block since task 114 --
		-- while there were two guns only one of them had one -- so `Viewmodel.loadingAt` can read it
		-- rather than ask whether it is there. Every number in it is a path `tools/pose.py set` moves.
		-- THE WHOLE BLOCK, NOT SIX FLAT NAMES (task 111, round 2). The loading motion is four
		-- moments now -- fetch, carry, above, seat -- each a position and three angles, which is a shape
		-- and not a number; the same reason `POSES` below passes the poses themselves. ONE SOURCE: this is
		-- a reference into `data`, so there is no second copy of a default to drift from the file -- the
		-- round-1 fallbacks said 0.16 where the file shipped 0.1 and 0.06 where it shipped -0.3 (the other
		-- side of the gun), and nothing would have failed if the block went missing.
		SHELL_LOAD = loadBlock,
		-- The flash, the smoke and the volumes live in the same block as the kick (task 112), and
		-- they are shapes rather than numbers, so the block goes through whole.
		FIRE = fire,
		-- THE THREE POSES THE DRAWN GUN IS MADE OF, plus the swing and the shot, because four things
		-- here have no flat name and never will: the raise's mid keyframes (a list) and the aimed and
		-- reloading hands. `Camera.Mode` reads those off here.
		--
		-- IT IS A VIEW, NOT A SECOND SOURCE: every field is a reference into `data`, the same table
		-- the flat names above were read out of, so the two can never disagree.
		POSES = table.freeze({
			version = data.version,
			carry = data.carry,
			aim = data.aim,
			reload = data.reload,
			raise = data.raise,
			fire = fire,
		}),
	}
end

return Viewmodel
