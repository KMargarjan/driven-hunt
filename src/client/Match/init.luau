--!strict
-- PlayerScripts.Match: the client's REPLICA of the match. It subscribes to MatchState itself and has
-- NO setter -- nothing on this client can write the snapshot, which is the same shape
-- PlayerScripts.Weapon already has.
--
-- It writes nothing drawn, nothing on the camera and no Instance. SINCE TASK 323 IT FIRES EXACTLY
-- ONE REMOTE, `StandRequest`, carrying ONE NUMBER -- it is THE ONE OWNER OF THE DRIVE WIRE ON THE
-- CLIENT, so the map calls `Match.requestStand` and owns no remote of its own
-- (docs/design/stand-pick.md section 9.1, amending drive.md section 9.1's zero-inbound rule). The
-- server decides every answer; this side derives nothing. The Hud READS this module.
--
--   GetServerTimeNow https://create.roblox.com/docs/reference/engine/classes/Workspace#GetServerTimeNow
--     the snapshot carries phaseEndsAt as a SERVER TIMESTAMP, not a duration, so the countdown is
--     computed here every frame instead of being pushed 600 times. The page documents the signature
--     and not a synchronisation guarantee (docs/research/2026-09-25-drive.md source B).
--
-- Design: docs/design/drive.md (section 9.3)
-- Note:   docs/research/2026-09-25-drive.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))

local Match = {}

local snapshot: Drive.MatchSnapshot? = nil
local started = false
local connections: { RBXScriptConnection } = {}

-- THE ONE OUTBOUND REMOTE AND THE LAST ANSWER IT WAS GIVEN (task 323). Both nil until
-- `Match.start`, which is what makes `requestStand` honest before the wire exists.
local standRequest: any = nil
local verdict: Drive.StandVerdict? = nil

local changed = Instance.new("BindableEvent")
local feed = Instance.new("BindableEvent")
local standVerdict = Instance.new("BindableEvent")
Match.Changed = changed.Event
Match.Feed = feed.Event
-- The answer to one ask (task 323), so the map's footer is told rather than polling.
Match.StandVerdict = standVerdict.Event

function Match.get(): Drive.MatchSnapshot?
	return snapshot
end

-- Seconds until the current phase ends, computed locally from the server timestamp. Never negative.
function Match.secondsLeft(): number
	local current = snapshot
	if not current or current.phaseEndsAt <= 0 then
		return 0
	end
	return math.max(0, current.phaseEndsAt - Workspace:GetServerTimeNow())
end

function Match.phase(): string?
	return if snapshot then snapshot.phase else nil
end

-- From Player.Team, NOT from the snapshot: the team is one fact with one representation, and the
-- engine replicates it (docs/design/drive.md section 5.1). The snapshot's per-row team is for the
-- scoreboard.
function Match.myTeam(): string?
	local team = Players.LocalPlayer.Team
	return if team then team.Name else nil
end

-- SECONDS UNTIL THE BEATERS MAY WALK, computed locally from the server timestamp exactly as
-- `Match.secondsLeft` is (task 168). 0 whenever nobody is being held -- which is every phase but the
-- start of a drive, and the whole of a drive once the fanfare has finished.
--
-- KAREN, 2026-10-12 ~21:45: *"you can't move as a beater before horn made signal and there should be
-- countdown"*. The SERVER holds the line (`Match.Phase`'s `goFreeAt`); this is only how the screen
-- says so.
function Match.holdSecondsLeft(): number
	local current = snapshot
	if not current or (current.holdUntil or 0) <= 0 then
		return 0
	end
	return math.max(0, current.holdUntil - Workspace:GetServerTimeNow())
end

-- HOW LONG AGO THE LINE WAS LET GO, or nil for "it has not been" (task 168). The one thing that makes
-- `GO` a moment rather than a label: `holdUntil` stays on the snapshot for the whole drive, so the
-- age of it is a local subtraction and needs no second field and no event.
function Match.goAgeSeconds(): number?
	local current = snapshot
	if not current or (current.holdUntil or 0) <= 0 then
		return nil
	end
	local age = Workspace:GetServerTimeNow() - current.holdUntil
	return if age >= 0 then age else nil
end

-- IS THIS PLAYER THROUGH THE HUNTERS' LINE? (task 168). Karen: *"when beater cross the line of hunter
-- it's done for him cant use sound anymore"*. The SERVER refuses the blast (`Match.mayBlowHorn`);
-- this is so his own screen can say why, and it is `Match.isTied` right below it with another list.
function Match.isThrough(): boolean
	local current = snapshot
	if not current then
		return false
	end
	for _, userId in ipairs(current.through or {}) do
		if userId == Players.LocalPlayer.UserId then
			return true
		end
	end
	return false
end

-- DID HE PAY FOR THE HUNTER'S PLACE AND GET A HORN ANYWAY? (task 221). Karen: *"Posibility to be a
-- hunter always"* -- a strong preference, not an exemption, and `Roster.assign`'s balance rule
-- still wins. The SERVER decides it (`Roster.overruled`, off the assignment it actually made);
-- this is so his own screen can say why, and it is `Match.isThrough` right above it with another
-- list of userIds.
--
-- FALSE when the field is absent, which is every build with no economy -- so a client that never
-- heard of it reads exactly what it always did.
function Match.isRoleOverruled(): boolean
	local current = snapshot
	if not current then
		return false
	end
	for _, userId in ipairs(current.roleOverruled or {}) do
		if userId == Players.LocalPlayer.UserId then
			return true
		end
	end
	return false
end

-- ------------------------------------------------------------------- task 323: THE STAND PICK
--
-- THE CLIENT DERIVES NOTHING HERE. All three answers are the snapshot's own fields, read straight
-- off it: whether the window is open, who holds which stand, and which one is his. A client that
-- computed "free" for itself would be a second opinion about a thing the server decides.

-- WHO HOLDS WHICH STAND, keyed by `tostring(standIndex)`, or nil for "no pick in this build" --
-- which is the flag off, a world with no stands, and every build before task 323.
function Match.standPickTable(): { [string]: number }?
	local current = snapshot
	return if current then current.picks else nil
end

function Match.standPickOpen(): boolean
	local current = snapshot
	return if current then current.pickWindow == true else false
end

-- WHICH STAND IS MINE, or nil for "I have not taken one". Read out of the same table the map draws,
-- so his own mark and everybody else's cannot disagree.
function Match.myStand(): number?
	local current = snapshot
	if not current or current.picks == nil then
		return nil
	end
	local me = Players.LocalPlayer.UserId
	for key, userId in pairs(current.picks :: { [string]: number }) do
		if userId == me then
			return tonumber(key)
		end
	end
	return nil
end

-- THE CHANNEL `requestStand` FIRES ON, INJECTABLE (task 323) -- the `Body.setGroundReader` and
-- `Weapon.setEntitlementProvider` discipline, and it exists because a client CANNOT observe its own
-- `FireServer` (`OnServerEvent` may only be connected on the server), so "it sends one number and
-- nothing else" is otherwise unassertable from either side. `Match.start` sets the real remote and
-- `Match.stop` puts it back to nil, exactly as those two do.
function Match.setStandChannel(channel: any?)
	standRequest = channel
end

function Match.standChannel(): any
	return standRequest
end

-- THE ONE OUTBOUND DOOR, and it sends ONE NUMBER and nothing else. No table, no name, no position:
-- every other fact the server measures for itself (Roblox docs, "never trust the client").
--
-- It refuses to fire before `Match.start`, because `Drive.remotes()` waits on instances.
function Match.requestStand(standIndex: number): boolean
	if not started or standRequest == nil then
		return false
	end
	if type(standIndex) ~= "number" then
		return false
	end
	(standRequest :: any):FireServer(standIndex)
	return true
end

-- THE LAST VERDICT THIS CLIENT WAS GIVEN, for the footer line 323b draws. One value, overwritten:
-- the ask is one at a time and a queue of stale refusals is not a thing a screen can use.
function Match.lastStandVerdict(): Drive.StandVerdict?
	return verdict
end

function Match.isTied(): boolean
	local current = snapshot
	if not current then
		return false
	end
	for _, userId in ipairs(current.tied) do
		if userId == Players.LocalPlayer.UserId then
			return true
		end
	end
	return false
end

function Match.start()
	if started then
		return
	end
	started = true
	local remotes = Drive.remotes()
	table.insert(
		connections,
		remotes.MatchState.OnClientEvent:Connect(function(payload)
			-- Frozen on arrival: a Hud that could write the snapshot is a second writer of match
			-- state with extra steps.
			snapshot = Drive.deepFreeze(payload)
			changed:Fire(snapshot)
		end)
	)
	table.insert(
		connections,
		remotes.MatchEvent.OnClientEvent:Connect(function(entry)
			feed:Fire(Drive.deepFreeze(entry))
		end)
	)
	-- THE VERDICT CHANNEL (task 323). Server -> THIS client, one answer per ask it did not drop. It
	-- is stored and fired, never acted on: a refusal is a word on his screen and nothing else.
	standRequest = remotes.StandRequest
	table.insert(
		connections,
		remotes.StandRequest.OnClientEvent:Connect(function(answer)
			verdict = Drive.deepFreeze(answer)
			standVerdict:Fire(verdict)
		end)
	)
end

function Match.stop()
	started = false
	standRequest = nil
	verdict = nil
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end

return Match
