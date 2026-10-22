--!strict
-- Lobby.Pads: WHAT ONE TRUCK PAD IS DOING, AS ARITHMETIC. PURE: no Instance, no service, no clock,
-- no Random and no `Player` -- a pad is a small table and its occupants are a list of userIds with
-- the time each arrived. That is what lets `tests/server/lobby.spec.luau` drive every state, every
-- transition and the exact boundary second with hand-written numbers and no character at all, which
-- is the rule `Lobby.Join` already states one file over.
--
-- KAREN, 2026-10-14 ~09:30, verbatim:
--   *"and when start hunt we need to go next to truck has to be mark where and has to be coloroude
--   circle like in all games or rectangle where people stand and can be 1/1 or 4/4 you can select
--   on dialiog how many like in roblox games and can be several truck like 4 of them nicly aligned
--   next ot each other and you come to truck back rectangle and can click and select how many
--   players"*
--
-- Pattern: THE ROBLOX QUEUE PAD, as the community actually builds it.
--   https://devforum.roblox.com/t/free-advanced-lobby-model-for-multiplayer-games/2272494
--   (licence UNSTATED, bug fixes through 2024-06 with an open question on the thread about whether
--   the distributed model ever got them -- so the PATTERN is read here and no line of its code is
--   taken)
-- Its lobby is a pad with (i) a configurable maximum, (ii) a live occupancy, (iii) a countdown that
-- starts when the FIRST player steps on, owned by the pad and not by a player, and (iv) a
-- `BillboardGui` over it showing both. That is Karen's picture minus the dialog -- so the shape she
-- asked for is the shape the community converged on, and the only thing this task adds is WHO
-- decides the maximum. In that model the developer does. Karen says the first player does.
--
-- THE PRESENCE TEST IS STILL VALVE'S `trigger_multiple` READ AS ARITHMETIC -- `Join`'s own citation
-- and this repository's own idiom (`Join.withinRect`, `ForestTest.withinStand`). `BasePart.Touched`
-- fires on CONTACT, so a player standing perfectly still generates nothing after the first touch and
-- `TouchEnded` cannot answer *"has he left"* -- the one question a pad that cancels on stepping off
-- asks every tick. What changed for this task is the SHAPE and not the mechanism: Karen asked for a
-- *"rectangle"*, so the subtraction is two `math.abs` comparisons.
--
-- THE PARTY IS DERIVED AND NEVER STORED. `pad.members` is recomputed from positions every scan and
-- is never a list anybody appends to. Both open-source party modules were rejected for exactly that
-- (note section 2b): a party object with a lifetime of its own would be a second answer to "who is
-- in party 2", and two answers to one question is this project's named failure mode
-- (`docs/PROJECT_CONTEXT.md`).
--
-- ONE TRANSITION PER CALL, for the reason `Join.decide` returned one verdict: the caller does a
-- different thing for each, and a function that applied two of them would hide one. The cost is at
-- most one scan (1 / `SCAN_HZ` = 0.1 s) of slack per edge, which the pick timeout's own number is
-- chosen against.
--
-- Design: docs/design/truck-pads.md (sections 4, 6)
-- Note:   docs/research/2026-10-14-truck-pads.md (sections 2a, 2c, 5)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage:WaitForChild("Lobby"))
-- THE RECTANGLE PREDICATE LIVES IN `Join`, beside the field rectangle and the return rule, because
-- that file is already *"when standing somewhere is a request to hunt"* and it is where task 177's
-- circle lived. This module is the STATE MACHINE and asks it.
local Join = require(script.Parent.Join)

local Pads = {}

-- ---------------------------------------------------------------- the five states
--
-- ALIASES OF `Lobby.PAD_STATE`, AND DELIBERATELY NOT A SECOND SPELLING: the state word crosses the
-- wire (`DHPadState`), and `Lobby.padAsking` -- which the client calls -- compares against that
-- table. One spelling of "sizing" in the repository, so a typo cannot make a dialog that never
-- opens.
Pads.EMPTY = Data.PAD_STATE.EMPTY
Pads.SIZING = Data.PAD_STATE.SIZING
Pads.FILLING = Data.PAD_STATE.FILLING
Pads.COUNTDOWN = Data.PAD_STATE.COUNTDOWN
Pads.LEAVING = Data.PAD_STATE.LEAVING

-- ONE MAN ON A PAD. `since` is when the owner first saw him on it, and it exists for exactly one
-- rule: who is re-elected to pick when the first man walks off (the EARLIEST remaining).
export type Occupant = { userId: number, since: number }

-- ONE PAD, as it stands right now.
--
-- `firstUserId` IS A userId AND NOT AN INDEX, because the man who may pick must survive the member
-- list being re-measured in a different order next scan. It is MEASURED by the owner off the
-- character the server can see, and never sent by anybody.
--
-- `deadline` IS WHICHEVER CLOCK THIS STATE IS RUNNING -- the pick timeout in `sizing`, the fill
-- timeout in `filling`, the countdown in `countdown` -- so there is one field and not three, and
-- "what is this pad waiting for" is answered by its state.
export type Pad = {
	index: number,
	state: string,
	size: number?,
	firstUserId: number?,
	deadline: number?,
	members: { number },
}

-- THE SIX VERDICTS, as words rather than as booleans, because the caller does a different thing for
-- each one and a tuple of booleans would have states that mean nothing -- `Join.decide`'s own
-- reasoning.
Pads.NONE = "none" -- nothing happened. What a pad answers on nearly every scan
Pads.ASK = "ask" -- a pick is wanted, from `pad.firstUserId`
Pads.SET = "set" -- a size is now chosen (picked, or defaulted by the timeout)
Pads.ARMED = "armed" -- the countdown started. `pad.deadline` is when they go
Pads.DEPART = "depart" -- send `pad.members`, exactly once
Pads.CANCELLED = "cancelled" -- the pad emptied: take back whatever was told to whom

function Pads.empty(index: number): Pad
	return { index = index, state = Pads.EMPTY, size = nil, firstUserId = nil, deadline = nil, members = {} }
end

-- ---------------------------------------------------------------- where a pad is

-- WHERE PAD n'S PART SITS. PURE, and it is the ONE place this arithmetic is written: `Build.pads`
-- and `Lobby.step` both call it, so "where is pad 3" has one answer. Task 177 had the same
-- expression (`anchor + cfg.SPOT.OFFSET`) in TWO files -- `Build.spot` and `Lobby.tryBuild` -- and
-- this closes that.
--
-- **THE TWO AXES SWAPPED IN TASK 243 AND NOTHING ELSE ABOUT THIS DID** (the Designer's
-- `lobby-yard-spec.md` section 2b). The row used to step EAST with the pad NORTH of its bay; it
-- steps SOUTH now with the pad WEST of its bay, because the trucks face west at the player. Each
-- of the three rows below reads the same config row it always read.
--
-- z IS THE BAY'S OWN z: `TRUCK.OFFSET.Z` stepped SOUTH by `BAY_GAP_STUDS`, the same expression
-- `Build.trucks` uses, so a pad cannot drift away from its truck.
--
-- x READS `PAD_BEHIND_STUDS` AS "FROM THE BAY CENTRE TO THE PAD'S NEAR EDGE", and that is a
-- measurement rather than a reading of task 180's words. Task 180 wrote *"12 studs behind the
-- tailgate"* -- but there are TWO tailgates: the parts truck's `BedTail` face is at `+8.2` of its
-- own frame and the free model is 18.46 studs long, so its tail is at `+9.23`. A pad defined off
-- "the tailgate" would therefore MOVE when a model is swapped. From the bay centre it does not, and
-- it clears the tighter of the two by 3.77 studs -- task 213's own number, to the decimal.
--
-- y SINKS THE SLAB, AND THAT IS TASK 177'S ROUND-1 FINDING CLOSED IN ADVANCE. Its TOP is
-- `shelfY + ROAD.THICK_STUDS + LIFT_STUDS`, above every yard slab the pad straddles; its BOTTOM, at
-- `SIZE.Y` 0.7, is below the terrain top, so there is no floating edge anywhere and no slab the pad
-- can hide inside. The ring was lifted off the SHELF and spent task 177 buried in the road.
function Pads.centreFor(anchor: Vector3, index: number, cfg): Vector3
	return anchor
		+ Vector3.new(
			cfg.TRUCK.OFFSET.X - cfg.TRUCK.PAD_BEHIND_STUDS - cfg.PADS.SIZE.X / 2,
			cfg.ROAD.THICK_STUDS + cfg.PADS.LIFT_STUDS - cfg.PADS.SIZE.Y / 2,
			cfg.TRUCK.OFFSET.Z - (index - 1) * cfg.TRUCK.BAY_GAP_STUDS
		)
end

-- WHICH PAD THIS POSITION IS ON, or nil. The owner's one question per player per scan.
--
-- THE PADS ARE 8 STUDS APART ON A 9-STUD SPAN (`BAY_GAP_STUDS` 17 less `SIZE.Z` 9 -- it was `SIZE.X`
-- until task 243 swapped the pad's two axes, and the 8 is unchanged), so a man cannot be inside two
-- and the first match is the only match -- which is why this returns on the first hit rather than
-- measuring a distance to each.
--
-- nil POSITION -> nil. A player with no character -- joining, or mid-respawn -- is standing nowhere,
-- and ABSENT IS NOT OUTSIDE: `Join.needsReturn`'s rule and `MapUi.pointsFor`'s.
function Pads.indexAt(position: Vector3?, anchor: Vector3, cfg): number?
	if typeof(position) ~= "Vector3" then
		return nil
	end
	for index = 1, cfg.TRUCK.COUNT do
		if Join.withinRect(position :: Vector3, Pads.centreFor(anchor, index, cfg), cfg.PADS.SIZE) then
			return index
		end
	end
	return nil
end

-- ---------------------------------------------------------------- the sizes

-- IS THIS SIZE ONE OF THE FOUR? PURE and exported, because it is asked in two places -- the door
-- validates a client's pick with it, and `Pads.withSize` refuses one -- and a second copy of "which
-- sizes are legal" would be a second rule.
--
-- IT REFUSES A NON-INTEGER AND A NON-NUMBER BY CONSTRUCTION, because it compares against the rows
-- rather than against a range: `1.5`, `"4"`, `true` and `0/0` all match no row.
function Pads.sizeAllowed(size: any, cfg): boolean
	if type(size) ~= "number" then
		return false
	end
	for _, row in ipairs(cfg.PADS.SIZES) do
		if size == row.size then
			return true
		end
	end
	return false
end

-- WHAT A PICK THAT NOBODY MAKES BECOMES: row 1, which is 1.
--
-- IT IS BOTH THE KINDER RULE AND THE ONE THAT KEEPS THE EVIDENCE HONEST. A man who walks onto a pad
-- and ignores the dialog goes hunting ALONE -- task 177's behaviour exactly, and what the drive's
-- bots are for (task 161) -- so the dialog is a choice to WAIT FOR FRIENDS and never a gate you must
-- pass to play. It is also what lets the Director's unattended smoke check reach the drive with no
-- click at all: a snippet run over StudioMCP gets a sandboxed copy of this module with empty state
-- (measured, task 122), so it can neither pick a size nor press a button.
function Pads.defaultSize(cfg): number
	return cfg.PADS.SIZES[1].size
end

-- ---------------------------------------------------------------- the pick

-- A PICK, APPLIED. PURE, and the caller has already decided that this man is the one the pad asked:
-- `Lobby.onPadRequest` measures where he is standing and compares `pad.firstUserId` itself, because
-- those are facts about the world and this function holds none.
--
-- WHAT IT DOES REFUSE is a pad that is not asking and a size that is not on the list, which are the
-- two things a STALE or FORGED client sends, and it returns the pad unchanged for both.
--
-- `firstUserId` SURVIVES THE PICK, because `Lobby.padAsking` gates the dialog on the STATE as well:
-- keeping the id means "who picked" is still answerable, and the state moving to `filling` is what
-- closes the dialog.
function Pads.withSize(pad: Pad, size: number, now: number, cfg): (Pad, boolean)
	if pad.state ~= Pads.SIZING or not Pads.sizeAllowed(size, cfg) then
		return pad, false
	end
	return {
		index = pad.index,
		state = Pads.FILLING,
		size = size,
		firstUserId = pad.firstUserId,
		deadline = now + cfg.PADS.FILL_TIMEOUT_SECONDS,
		members = pad.members,
	},
		true
end

-- ---------------------------------------------------------------- one step

-- WHO PICKS WHEN THE PAD HAS TO ELECT SOMEBODY: the man who has been standing on it longest, and
-- the userId breaks a tie so two men who arrived on the same scan elect the same one of them on
-- every server and in every spec.
local function earliest(members: { Occupant }): Occupant?
	local best: Occupant? = nil
	for _, member in ipairs(members) do
		if
			best == nil
			or member.since < (best :: Occupant).since
			or (member.since == (best :: Occupant).since and member.userId < (best :: Occupant).userId)
		then
			best = member
		end
	end
	return best
end

local function userIds(members: { Occupant }): { number }
	local out = {}
	for _, member in ipairs(members) do
		table.insert(out, member.userId)
	end
	table.sort(out)
	return out
end

local function holds(members: { Occupant }, userId: number?): boolean
	if userId == nil then
		return false
	end
	for _, member in ipairs(members) do
		if member.userId == userId then
			return true
		end
	end
	return false
end

-- ONE STEP OF ONE PAD. PURE over `(pad, members, now, cfg)`, and the whole of section 6.2 of the
-- design is the table of cases below, in the order they are tested.
--
-- `members` IS WHO IS STANDING ON THIS RECTANGLE AND NOT ALREADY IN THE DRIVE. The owner leaves out
-- a man the drive has, and that exclusion is what makes `leaving` end BY ITSELF: the moment the
-- party is enrolled every list is empty, so the pad falls back to `empty` with no second verdict and
-- no flag to clear. A man `depart` FAILED on is still standing there, so his pad re-enters `sizing`
-- and he is asked again (case 6) -- a failed hand-over retries instead of stranding him.
function Pads.step(pad: Pad, members: { Occupant }, now: number, cfg): (Pad, string)
	local list = userIds(members)
	local on = #list

	-- 1. NOBODY ON IT. Everything is dropped together, which is `Join.decide`'s rule read at the
	--    level of the pad: *"RE-ENTRY DOES NOT INHERIT THE OLD DEADLINE"*. A pad nobody is standing
	--    on has no party, no size and no clock.
	--
	--    THE LAST MAN OFF IN `countdown` CANCELS IT AND NOBODY IS ENROLLED. That is Karen's own task
	--    177 rule -- stepping out cancels it -- read where the countdown now lives.
	if on == 0 then
		if pad.state == Pads.EMPTY then
			return pad, Pads.NONE
		end
		return Pads.empty(pad.index), Pads.CANCELLED
	end

	-- The member list is re-derived every scan whatever else happens, so the billboard's count and
	-- the party that departs are the same list.
	local here: Pad = {
		index = pad.index,
		state = pad.state,
		size = pad.size,
		firstUserId = pad.firstUserId,
		deadline = pad.deadline,
		members = list,
	}

	-- 2. AN EMPTY PAD WITH SOMEBODY ON IT: ask him.
	if here.state == Pads.EMPTY then
		local first = earliest(members)
		here.state = Pads.SIZING
		here.firstUserId = if first then (first :: Occupant).userId else nil
		here.deadline = now + cfg.PADS.PICK_TIMEOUT_SECONDS
		return here, Pads.ASK
	end

	if here.state == Pads.SIZING then
		-- 3a. THE FIRST MAN STEPPED OFF AND SOMEBODY IS STILL THERE: re-elect, with a FRESH clock.
		--     The pad does not cancel while anybody is on it -- a pad that cancelled would throw
		--     away three men because the fourth walked away.
		if not holds(members, here.firstUserId) then
			local first = earliest(members)
			here.firstUserId = if first then (first :: Occupant).userId else nil
			here.deadline = now + cfg.PADS.PICK_TIMEOUT_SECONDS
			return here, Pads.ASK
		end
		-- 3b. NOBODY ANSWERED: row 1, which is 1. See `Pads.defaultSize`.
		if now >= (here.deadline or math.huge) then
			here.state = Pads.FILLING
			here.size = Pads.defaultSize(cfg)
			here.deadline = now + cfg.PADS.FILL_TIMEOUT_SECONDS
			return here, Pads.SET
		end
		return here, Pads.NONE
	end

	if here.state == Pads.FILLING then
		-- 4. AS MANY AS THE SIZE, or the fill timed out: the same transition either way (the
		--    Director: *"a countdown when full or after N seconds"*).
		--
		--    SIZE IS A TARGET AND NOT A CAP, and that follows from the owner boundary rather than
		--    from taste: keeping a ninth man off a 9 x 12 slab would mean MOVING him, and `Lobby`
		--    must not write a character's position (`docs/design/lobby.md` 4.5). The game is
		--    unharmed -- the drive has eight slots and bots fill every slot no player takes -- so an
		--    over-full pad simply sends more men and fewer bots.
		local size = here.size or Pads.defaultSize(cfg)
		if on >= size or now >= (here.deadline or math.huge) then
			here.state = Pads.COUNTDOWN
			here.size = size
			-- `CONFIG.COUNTDOWN_SECONDS`, TASK 177'S OWN FIVE, because a second countdown length
			-- would be a second answer to "how long until I go".
			here.deadline = now + cfg.COUNTDOWN_SECONDS
			return here, Pads.ARMED
		end
		-- A JOIN OR A LEAVE: the member list changed and the billboard will change with it. Nothing
		-- else does, and "who picked" has no meaning after the pick.
		return here, Pads.NONE
	end

	if here.state == Pads.COUNTDOWN then
		-- 5. `>=` AT THE DEADLINE: five seconds means five, not five-and-a-frame (`Join.decide`'s
		--    rule, and it is the same five).
		--
		--    A LATE ARRIVAL IS IN THE PARTY AND DOES NOT MOVE THE CLOCK. The deadline is only ever
		--    written on the `filling -> countdown` edge, so a man stepping on at second four cannot
		--    push back a countdown somebody else is watching.
		if now >= (here.deadline or math.huge) then
			here.state = Pads.LEAVING
			here.deadline = nil
			return here, Pads.DEPART
		end
		return here, Pads.NONE
	end

	-- 6. `leaving`, AND REACHING THIS LINE MEANS THE HAND-OVER DID NOT TAKE THEM. Case 1 above
	--    returns `empty` the moment the pad has no members, and the owner leaves anyone the drive
	--    has OUT of the list -- so a party that departed normally never arrives here at all.
	--
	--    A MAN STILL STANDING ON A `leaving` PAD IS A FAILED DEPARTURE, and he is ASKED AGAIN rather
	--    than stranded. `Lobby.depart` returns 0 whenever the injected seam throws or `world.enrol`
	--    refuses -- `Match.enrol` refuses a player it has never registered, *"Refused rather than
	--    half-done"* -- and without this the pad would sit in `leaving` with his `DHPadState` on the
	--    part, no dialog, no countdown and no second attempt, until he happened to walk off the
	--    rectangle. That is the one state in this machine a player cannot get himself out of.
	--
	--    IT IS A FRESH QUESTION AND NOT A RESUMED ONE: the size is dropped and the pick clock starts
	--    again, which is `Join.decide`'s rule (*"RE-ENTRY DOES NOT INHERIT THE OLD DEADLINE"*) and
	--    the same thing case 3a does when the first man walks away.
	local first = earliest(members)
	here.state = Pads.SIZING
	here.size = nil
	here.firstUserId = if first then (first :: Occupant).userId else nil
	here.deadline = now + cfg.PADS.PICK_TIMEOUT_SECONDS
	return here, Pads.ASK
end

-- ---------------------------------------------------------------- the words over the pad

-- WHAT THE BILLBOARD OVER THIS PAD SAYS: the truck's number, and the fill. PURE, so what is written
-- over the trucks is a spec and not a screenshot -- `ShopPanel.rowNameFor`'s and
-- `ReportPanel.listRowText`'s rule (*"the panel reads, the words do not"*).
--
-- `%d / -` BEFORE A PICK AND NOT `%d / 0`, because nobody having picked yet is not a party of
-- nought. The format with a size in it is Karen's own: she wrote *"can be 1/1 or 4/4"*.
function Pads.labelFor(pad: Pad, cfg): (string, string)
	local words = cfg.PADS.BILLBOARD
	local title = string.format(words.TRUCK, pad.index)
	local on = #pad.members
	if pad.size == nil then
		return title, string.format(words.COUNT_UNSET, on)
	end
	return title, string.format(words.COUNT, on, pad.size :: number)
end

return Pads
