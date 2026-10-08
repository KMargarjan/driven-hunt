--!strict
-- Report (client): the REPLICA of what the server's `HitLog` says. It subscribes to the report
-- remotes and republishes them as signals; it draws nothing and it decides nothing.
--
-- ONE READER OF THE WIRE, MANY DRAWERS. The Hud listens to `Killed` for the kill-log line and the
-- report panel will listen to `Data` for the panel body -- the same shape `PlayerScripts.Match` has
-- for the drive, and the reason the Hud needs no remote of its own.
--
-- IT IS THE ONE FIRER OF `ReportRequest`. A client that asks from two places is a client whose
-- throttle means nothing.
--
-- NO `Match` ANYWHERE IN HERE. The Forest Test has no drive, no roster and no teams, and this file is
-- identical in both worlds -- which is the whole reason the kill line does not travel on `Match`'s
-- feed remote (design section 4.2).
--
-- Design: docs/design/drive-report.md (section 3)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Report = require(ReplicatedStorage:WaitForChild("Report"))

local ReportClient = {}

local killedSignal = Instance.new("BindableEvent")
local dataSignal = Instance.new("BindableEvent")
local driveSignal = Instance.new("BindableEvent")

-- A kill happened, anywhere, to anybody: the kill-log line.
ReportClient.Killed = killedSignal.Event
-- A payload came back for something this client asked for.
ReportClient.Data = dataSignal.Event
-- A drive opened or closed. `kind` says which.
ReportClient.DriveChanged = driveSignal.Event

local remotes = nil
local started = false
local lastData: any = nil
local drive = { number = 0, open = false }

local stats = { kills = 0, payloads = 0, driveEvents = 0, asked = 0 }

function ReportClient.stats()
	return table.clone(stats)
end

-- The last payload the server sent, so a panel that opens after one arrived does not have to ask
-- again, and a spec can read what the wire delivered.
function ReportClient.last()
	return lastData
end

function ReportClient.drive()
	return table.clone(drive)
end

-- THE ONE FIRER. `drive`, `hunter` and `page` are all optional and all advisory: the server resolves
-- them against what it actually holds and never trusts a number (`HitLog.Shape.resolveRequest`).
function ReportClient.ask(request)
	if remotes == nil then
		remotes = Report.remotes()
	end
	stats.asked += 1
	remotes.ReportRequest:FireServer(if type(request) == "table" then request else {})
end

function ReportClient.start()
	if started then
		return
	end
	started = true
	remotes = Report.remotes()

	remotes.ReportEvent.OnClientEvent:Connect(function(event)
		if type(event) ~= "table" then
			return
		end
		if event.kind == "kill" then
			stats.kills += 1
			killedSignal:Fire(event)
		elseif event.kind == "driveOpened" then
			stats.driveEvents += 1
			drive = { number = event.drive or 0, open = true }
			driveSignal:Fire(event)
		elseif event.kind == "driveClosed" then
			stats.driveEvents += 1
			drive = { number = event.drive or drive.number, open = false }
			driveSignal:Fire(event)
		end
	end)

	remotes.ReportData.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		stats.payloads += 1
		lastData = payload
		dataSignal:Fire(payload)
	end)
end

return ReportClient
