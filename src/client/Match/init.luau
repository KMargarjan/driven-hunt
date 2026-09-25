--!strict
-- PlayerScripts.Match: the client's REPLICA of the match. It subscribes to MatchState itself and has
-- NO setter -- nothing on this client can write the snapshot, which is the same shape
-- PlayerScripts.Weapon already has.
--
-- It writes nothing drawn, nothing on the camera, no Instance, and it fires NO remote: this whole
-- system has no client -> server remote at all, so its inbound exploit surface is zero
-- (docs/design/drive.md section 9.1). The Hud READS this module and is never called by it.
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

local changed = Instance.new("BindableEvent")
local feed = Instance.new("BindableEvent")
Match.Changed = changed.Event
Match.Feed = feed.Event

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
end

function Match.stop()
	started = false
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end

return Match
