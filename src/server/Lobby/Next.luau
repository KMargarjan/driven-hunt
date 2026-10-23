--!strict
-- Lobby.Next: THE PARTY THAT GOES AGAIN. PURE: no Instance, no service, no clock, no Random, and it
-- never knows what a Player is -- it keys by userId, exactly as `Lobby.Pads` and `Match.Roster` do.
-- That is what lets `tests/server/lobby_next.spec.luau` drive a whole drive-to-drive cycle -- the
-- collection, the wait for the line to walk home, the countdown, a man sitting out, a man changing
-- his mind, a man leaving, a man walking onto a pad instead -- with hand-written numbers, no world
-- and no drive at all.
--
-- KAREN, 2026-10-23, verbatim: *"we need back to lobby after hunt to have the same not saperate for
-- beaters (if it's not the same) / also we need continues game so after drive new drive imidiatly
-- after same amount seconds and who has licesne can select who he can be next round if dont then
-- oposit previuos round"*.
--
-- WHAT THIS IS AND WHAT IT IS NOT. `Match.Phase` ALREADY loops: its `Scoring` exit is
-- `if enoughPlayers(...) then enterAssigning(...) else enterWaiting(...)`, so a drive whose roster
-- survives the results scene starts the next one with no help from anybody. The thing that stopped
-- it was `Lobby.onPhase("Scoring") -> dismissAll()`, which empties the roster one scan into the
-- scene -- deliberately, by task 177, because task 177's lobby had no way back in but a truck pad.
-- **So this module does not start drives. It re-forms the party that walks back to the lodge, and
-- hands it to the same `Lobby.depart` seam a pad's party leaves through.** Nothing in `Match`
-- changed for this task.
--
-- Pattern: **ONE DEADLINE IN THE STATE, AND A MEMBERSHIP RECONCILED EVERY SCAN.** Two borrowings,
-- both quoted in the note:
--   * Valve's `CTeamplayRoundBasedRules` (Source SDK 2013 / TF2) carries exactly one
--     `m_flStateTransitionTime` per state rather than a timer per transition -- which is
--     `Match.Phase`'s `phaseEndsAt` and `nextReleaseAt` already, and the reason that file's header
--     refuses a `task.delay` in capitals. `state.at` is that field.
--   * Quake III's `CheckIntermissionExit` keeps `cl->readyToExit` per client and recounts it on
--     every server frame, publishing one value outward -- so a man who connects, disconnects or
--     changes his mind is simply counted differently next frame. `state.sitOut` is that flag, and
--     `Next.step`'s whole first half is that recount. Learning Agent L-029's lesson said the same
--     thing in this repository's own words: *"a standing invariant must be reconciled on the tick,
--     not fired once off an event"*.
--   And the ORDER -- back to the lobby FIRST, then a fixed wait, then the next round -- is Roblox's
--   own round loop, quoted: *"Send everyone to the lobby" ... "After waiting ten seconds for an
--   intermission, the Rounds server script then starts the loop again"*.
--
-- Design: docs/design/lobby.md (sections 4, 6, 8), docs/design/truck-pads.md
-- Note:   docs/research/2026-10-23-the-continuous-drive-loop.md
local Next = {}

-- THE FIVE VERDICTS, and they are words rather than numbers for `Lobby.Pads`' stated reason: a
-- verdict that appears in a test failure should say what happened.
--
--   IDLE      there is no party. Nothing to draw, nothing to do.
--   WAITING   a party is collected and is not home yet: somebody is still in the drive, or still
--             held in the results scene. No deadline exists, so the card shows no number.
--   COUNTING  the deadline is set and has not passed.
--   GO        the deadline has passed: these userIds go. The party is cleared in the same step.
--   CLEARED   the party is gone without going -- everybody left, or everybody sat out, or the drive
--             took them all through a pad.
Next.IDLE = "idle"
Next.WAITING = "waiting"
Next.COUNTING = "counting"
Next.GO = "go"
Next.CLEARED = "cleared"

export type Verdict = string

-- THE STATE. FROZEN, like `Phase.State` and for the same reason: the owner holds it and only
-- `Next`'s own functions make a new one, so nothing else in this repository can write a membership.
--
--   members  userId -> true. WHO WAS IN THE DRIVE THAT JUST ENDED. It only ever shrinks: men are
--            added by `Next.collect` and by nothing else, which is what makes *"the group size
--            continues"* true and *"a stranger is swept into somebody's party"* impossible.
--   sitOut   userId -> true. WHO HAS PRESSED SIT OUT. A subset of `members` by construction
--            (`Next.sit` refuses a stranger), and reversible until the deadline.
--   at       THE ONE DEADLINE, or nil for *"not armed yet"*.
--   since    WHEN THE PARTY WAS COLLECTED, which is what `ARM_TIMEOUT_SECONDS` is measured from.
export type State = {
	members: { [number]: boolean },
	sitOut: { [number]: boolean },
	at: number?,
	since: number?,
}

-- WHAT THE OWNER MEASURES AND HANDS IN, every scan. Three sets, all keyed by userId:
--
--   present  who is on the server at all (`Players:GetPlayers()`, or a spec's list).
--   inDrive  who the drive has (`world.inDrive`). A member the drive already has is DROPPED, which
--            is what stops a man who walked onto a truck pad during the countdown being enrolled
--            twice -- hazard 2 of the note. It is the same fact `Lobby.occupancy` already drops a
--            man from a pad list for.
--   held     who is still frozen (`world.isHeld`). This is the results scene: `enterScoring` holds
--            the whole roster and `enterAssigning`/`enterWaiting`'s `free` lets them go, so "not
--            held" is the instant the lodge's own return rule starts moving them.
--
-- THEY ARE SETS AND NOT PREDICATES so this stays pure and a spec writes them as literals. The owner
-- builds them in the one pass it already makes over the occupants.
export type Facts = {
	present: { [number]: boolean },
	inDrive: { [number]: boolean },
	held: { [number]: boolean },
}

local function freeze<T>(value: T): T
	if type(value) == "table" and not table.isfrozen(value :: any) then
		table.freeze(value :: any)
	end
	return value
end

local function freezeState(state: State): State
	freeze(state.members)
	freeze(state.sitOut)
	return freeze(state)
end

local function copy(state: State): State
	return {
		members = table.clone(state.members),
		sitOut = table.clone(state.sitOut),
		at = state.at,
		since = state.since,
	}
end

function Next.initial(): State
	return freezeState({ members = {}, sitOut = {}, at = nil, since = nil })
end

-- HOW MANY MEN THE PARTY HOLDS. Counted rather than stored, for `Phase.participantCount`'s reason:
-- a stored count is a second answer to a question the table already answers.
function Next.count(state: State): number
	local n = 0
	for _ in pairs(state.members) do
		n += 1
	end
	return n
end

function Next.has(state: State, userId: number): boolean
	return state.members[userId] == true
end

function Next.isOut(state: State, userId: number): boolean
	return state.sitOut[userId] == true
end

-- EVERYBODY IN THE PARTY, SORTED -- the list the owner writes attributes from and hands to
-- `Lobby.depart`. Sorted for `Phase.participantIds`' stated reason: the same list every time, so a
-- spec asserts it by value.
function Next.ids(state: State): { number }
	local ids = {}
	for userId in pairs(state.members) do
		table.insert(ids, userId)
	end
	table.sort(ids)
	return ids
end

-- WHO WOULD ACTUALLY GO IF THE DEADLINE PASSED NOW: the members who have not asked to sit out.
-- SORTED, same reason.
--
-- IT IS A QUESTION AND NOT A STORED LIST, which is `Phase.heldUserIds`' arrangement: the membership
-- and the opt-out are the two facts, and "who goes" is their difference -- so a man who changes his
-- mind in the last second changes the answer and there is nothing to keep in step.
function Next.goers(state: State): { number }
	local ids = {}
	for userId in pairs(state.members) do
		if state.sitOut[userId] ~= true then
			table.insert(ids, userId)
		end
	end
	table.sort(ids)
	return ids
end

-- HOW MANY SECONDS ARE LEFT, or nil for *"there is no countdown"* -- `Lobby.secondsLeft`'s own rule
-- (*"nil in, nil out: 'there is no countdown' is not 'zero seconds left'"*), applied to this state.
function Next.secondsLeft(state: State, now: number): number?
	local at = state.at
	if at == nil then
		return nil
	end
	return math.max(0, (at :: number) - now)
end

-- ---------------------------------------------------------------- the three things that change it

-- THE DRIVE HAS ENDED AND THESE MEN WERE IN IT.
--
-- IT REPLACES WHATEVER WAS THERE and does not merge, which is deliberate: a party is per drive, and
-- a leftover member from two drives ago is a man the game would send on a hunt he did not ask for.
-- `sitOut` is cleared with it, so *"by default they are in"* is true at the start of every gap --
-- the Director's brief -- and a man who sat out one drive is not silently sitting out for ever.
--
-- AN EMPTY LIST IS AN EMPTY PARTY, not a no-op: a drive that ended with nobody in it leaves nothing
-- counting in, which is `Next.IDLE` on the next step.
function Next.collect(state: State, userIds: { number }, now: number): State
	local members: { [number]: boolean } = {}
	for _, userId in ipairs(userIds) do
		members[userId] = true
	end
	local _ = state
	return freezeState({ members = members, sitOut = {}, at = nil, since = now })
end

-- HE HAS PRESSED SIT OUT, OR PRESSED IT AGAIN.
--
-- IT REFUSES A STRANGER, so `sitOut` is a subset of `members` by construction and no part of this
-- module has to ask twice. The owner's door checks membership too, and says so to the client -- the
-- two are not one check split in half: the door answers a REQUEST and this keeps an INVARIANT.
--
-- `out == false` IS THE WAY BACK IN, which is why there is one function and not two: the card has
-- one button (`PADS.NEXT.SIT_OUT` / `SIT_IN`) because it is one boolean.
function Next.sit(state: State, userId: number, out: boolean): State
	if state.members[userId] ~= true then
		return state
	end
	local wanted = if out then true else nil
	if state.sitOut[userId] == wanted then
		return state
	end
	local next_ = copy(state)
	next_.sitOut[userId] = wanted
	return freezeState(next_)
end

-- THE WHOLE RULE, ASKED EVERY SCAN. `(state, facts, now, cfg) -> (state, verdict, goers)`.
--
-- IT IS LEVEL-TRIGGERED FROM END TO END (Quake III's recount, and L-029's lesson): there is no edge
-- in it at all. Every one of the five ways a party changes under you -- a man disconnects, a man
-- walks onto a pad and the drive takes him, a man presses SIT OUT, the last member leaves, the
-- results scene finally lets everybody go -- is answered by the same two passes, in the same order,
-- on the next tenth of a second.
--
-- THE ORDER IS THE DESIGN:
--   1. DROP whoever is no longer a candidate: gone from the server, or already in a drive. (A man
--      the drive has is not "in the next party"; he is hunting.)
--   2. If nothing is left, the party is CLEARED. This is also what makes an all-sat-out party end
--      cleanly at its deadline rather than enrol an empty list.
--   3. ARM, if it is not armed: when nobody left is held or in a drive -- the party is HOME -- or
--      when `ARM_TIMEOUT_SECONDS` has run out since it was collected (hazard 1).
--   4. GO, if the deadline has passed.
--
-- STEP 3 CANNOT RUN BEFORE STEP 1, and that is the one trap: a member who disconnected during the
-- results scene is still `held` as far as the drive's own table knows (`Match`'s `heldStill` is
-- keyed by userId and `Match.forget` clears it on the leave, but the two are a frame apart), so an
-- arming check made over the raw membership could wait for a man who is not there.
function Next.step(state: State, facts: Facts, now: number, cfg): (State, Verdict, { number })
	local none: { number } = {}
	if next(state.members) == nil then
		-- NOTHING IS COUNTING IN, and the state is normalised rather than trusted: a deadline with
		-- no members would be a number on nobody's screen.
		if state.at ~= nil or state.since ~= nil or next(state.sitOut) ~= nil then
			return Next.initial(), Next.IDLE, none
		end
		return state, Next.IDLE, none
	end

	local present = facts.present or {}
	local inDrive = facts.inDrive or {}
	local held = facts.held or {}

	-- ---------------------------------------------------------------- 1. the recount
	local kept: { [number]: boolean } = {}
	local droppedAny = false
	for userId in pairs(state.members) do
		if present[userId] == true and inDrive[userId] ~= true then
			kept[userId] = true
		else
			droppedAny = true
		end
	end

	-- ---------------------------------------------------------------- 2. nobody left
	if next(kept) == nil then
		return Next.initial(), Next.CLEARED, none
	end

	local next_ = copy(state)
	if droppedAny then
		next_.members = kept
		-- AND HIS OPT-OUT GOES WITH HIM. `sitOut` is a subset of `members`, and a row for a man who
		-- has left would come back to life if he rejoined and was collected again.
		for userId in pairs(next_.sitOut) do
			if kept[userId] ~= true then
				next_.sitOut[userId] = nil
			end
		end
	end

	-- ---------------------------------------------------------------- 3. arm
	if next_.at == nil then
		local home = true
		for userId in pairs(next_.members) do
			if held[userId] == true then
				home = false
				break
			end
		end
		local timeout = cfg.ARM_TIMEOUT_SECONDS
		local lateBy = if next_.since ~= nil and type(timeout) == "number"
			then now - (next_.since :: number) - (timeout :: number)
			else -math.huge
		if home or lateBy >= 0 then
			next_.at = now + cfg.SECONDS
			return freezeState(next_), Next.COUNTING, Next.goers(next_)
		end
		return freezeState(next_), Next.WAITING, none
	end

	-- ---------------------------------------------------------------- 4. go
	if now >= (next_.at :: number) then
		local going = Next.goers(next_)
		-- THE PARTY IS CLEARED EITHER WAY, which is what makes this verdict happen ONCE however many
		-- scans arrive in the same tenth of a second -- `enterRunning`'s *"`Assigning` has exactly
		-- one exit"* argument, in a state machine with no phases.
		if #going == 0 then
			-- EVERYBODY SAT OUT. The countdown still ran, because that is what let the last of them
			-- change his mind; nobody goes, and nothing is handed to `Lobby.depart`.
			return Next.initial(), Next.CLEARED, none
		end
		return Next.initial(), Next.GO, going
	end

	return freezeState(next_), Next.COUNTING, Next.goers(next_)
end

return Next
