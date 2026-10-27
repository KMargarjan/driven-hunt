--!strict
-- AssetFetch: ONE OWNER of "has this client downloaded that mesh, and may we ask again".
--
-- Karen, 2026-10-27: *"weapons loaded at first in game is rectangles"* -- a `MeshPart` whose mesh
-- has not downloaded draws as its plain box. Task 244 solved exactly this for the shop case and the
-- rule, the per-id cool-down and the counters lived in `Hud.ShopDisplay`; the gun's own gate
-- (`Camera.Viewmodel.meshReady`) had a second, weaker copy with no cool-down. One module now.
--   ContentProvider:GetAssetFetchStatus
--   https://create.roblox.com/docs/reference/engine/classes/ContentProvider#GetAssetFetchStatus
local ContentProvider = game:GetService("ContentProvider")

local AssetFetch = {}

-- Every id that has read `Success` on this client. Downloaded is a one-way fact: nothing takes a
-- mesh off a client mid-session, and a fresh clone reads `Loading` again for the bytes it has.
local arrived: { [string]: boolean } = {}
local asked: { [string]: boolean } = {}
local askedAt: { [string]: number } = {}
local stats = { asks = 0, retries = 0, warms = 0 }

-- A FAILED FIRST FETCH IS ASKED FOR AGAIN, AND NOT FOUR TIMES A SECOND (task 244 round 1, kept).
-- `Failure`/`TimedOut` are terminal answers, so the only way out is to ask once more -- on a
-- cool-down per id, because every caller here re-asks on its own cadence.
AssetFetch.RETRY_SECONDS = 3

-- THE WHOLE DECISION ABOUT ONE ID, AS A PURE RULE, so a spec drives it where it can FAIL:
--   "ready" the engine has it · "ask" nobody asked, or it failed and the cool-down ran out
--   "wait"  it is in flight, or it failed and the cool-down has not run out
-- `Loading` and `None` are never retryable: one is in flight, the other has not been asked for.
function AssetFetch.nextAsk(status: any, askedAlready: boolean, since: number?, now: number): string
	if status == Enum.AssetFetchStatus.Success then
		return "ready"
	end
	if not askedAlready then
		return "ask"
	end
	local terminal = status == Enum.AssetFetchStatus.Failure or status == Enum.AssetFetchStatus.TimedOut
	if terminal and now - (since or 0) >= AssetFetch.RETRY_SECONDS then
		return "ask"
	end
	return "wait"
end

-- THE TWO SEAMS. A spec holds one asset back (`setStatus`) and counts the asks (`setAsk`) without a
-- network: that is how "today it shows, after the fix it waits" is provable at all.
local statusOf: (string) -> any = function(id)
	return ContentProvider:GetAssetFetchStatus(id)
end
local askNow: (Instance) -> () = function(holder)
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ holder })
		end)
	end)
end
local clock: () -> number = os.clock

function AssetFetch.setStatus(fn: ((string) -> any)?)
	statusOf = fn or function(id)
		return ContentProvider:GetAssetFetchStatus(id)
	end
end

function AssetFetch.setAsk(fn: ((Instance) -> ())?)
	askNow = fn
		or function(holder)
			task.spawn(function()
				pcall(function()
					ContentProvider:PreloadAsync({ holder })
				end)
			end)
		end
end

function AssetFetch.setClock(fn: (() -> number)?)
	clock = fn or os.clock
end

local function request(id: string, holder: Instance)
	if asked[id] then
		stats.retries += 1
	end
	asked[id] = true
	askedAt[id] = clock()
	stats.asks += 1
	askNow(holder)
end

-- CAN THIS CLIENT DRAW THIS PART YET? A non-mesh part is always ready; a status that cannot be read
-- answers READY rather than withholding the real model for ever (a guard that failed closed would
-- ship boxes to everybody).
function AssetFetch.ready(part: Instance): boolean
	if not part:IsA("MeshPart") then
		return true
	end
	local id = (part :: MeshPart).MeshId
	if id == nil or id == "" then
		return false
	end
	return AssetFetch.readyId(id, part)
end

-- THE SAME DECISION FOR ONE ID, which is the half a spec can drive: a `MeshPart` cannot be given a
-- mesh id in a test place, so without this the gate could only be proved through its pure rule and
-- never through the bookkeeping that asks, remembers and re-asks. `holder` is what `PreloadAsync`
-- is handed.
function AssetFetch.readyId(id: string, holder: Instance): boolean
	if arrived[id] then
		return true
	end
	local ok, status = pcall(function()
		return statusOf(id)
	end)
	if not ok then
		return true
	end
	if status == Enum.AssetFetchStatus.Success then
		arrived[id] = true
		return true
	end
	if AssetFetch.nextAsk(status, asked[id] == true, askedAt[id], clock()) == "ask" then
		request(id, holder)
	end
	return false
end

-- ASK EARLY. The lobby's job: a player who has only ever carried the shotgun has never asked for the
-- rifle's meshes, so their status is `None` until the DRAW asks -- as he looks at it. Safe at any
-- time and free after the first: `arrived` short-circuits, and a folder that has not replicated yet
-- simply finds nothing and is warmed again on the next call. Returns how many it asked for.
function AssetFetch.warm(holders: { Instance }): number
	local requested = 0
	for _, holder in ipairs(holders) do
		for _, part in ipairs(if holder:IsA("MeshPart") then { holder } else holder:GetDescendants()) do
			if part:IsA("MeshPart") then
				local id = (part :: MeshPart).MeshId
				if id ~= nil and id ~= "" and not arrived[id] and not asked[id] then
					request(id, part)
					requested += 1
				end
			end
		end
	end
	stats.warms += 1
	return requested
end

function AssetFetch.stats()
	return table.clone(stats)
end

-- Specs only: a fresh client, in one line.
function AssetFetch.reset()
	table.clear(arrived)
	table.clear(asked)
	table.clear(askedAt)
	stats = { asks = 0, retries = 0, warms = 0 }
end

return AssetFetch
