--!strict
-- ForestTest (server): THE AMBIENT DRIVE AND THE HUNTER'S STAND, for the playtest world only.
--
-- It owns two things and writes nothing else: WHEN a wave of boars moves, and WHERE a hunter is
-- allowed to stand. It spawns boars through `Runtime:spawnSounder`/`:spawn` and pushes them with
-- THREATS -- it never writes a boar's position, its state or its path. The boar's own owner still
-- decides what a boar does; this only decides what it can see.
--
-- KAREN IS TESTING ALONE IN THE MORNING, which is the whole reason this exists. A driven hunt needs
-- drivers, and she asked for *"each 20s cross 1 flock then 1 big male then on other side few so to
-- be action"* with no second player in the world. So the beaters are PHANTOMS: positions in the
-- threat list with nobody standing on them.
--
-- THAT PATTERN IS NOT NEW HERE. `Match.quickTestPhantom` already injects
-- `{ id, position, kind = "driver" }` to push the quick-test sounder, and it is injected at the
-- same seam for the same reason: a phantom is cheaper, more repeatable and far less code than a
-- fake player, and the Brain cannot tell the difference because there is no difference -- a threat
-- is a position and a kind.
--
-- Design: no new design document. This is a playtest world, behind a world string, reachable only
-- in one place id; the game's own map and drive are untouched. TASKS.md row 122.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage:WaitForChild("ForestTest"))

local ForestTest = {}
ForestTest.Data = Data

-- ---------------------------------------------------------------- the pure half

-- HOW A WAVE BEHAVES, as a function of how long it has been running. Pure: no Instance, no clock,
-- no boar -- so the whole rhythm Karen asked for can be read, and tested, without a world.
--
-- A WAVE IS THREE PHASES.
--   PUSH   a beater stands `behindStuds` NORTH of the group and walks at it. The group runs south,
--          which is the direction the Brain already escapes in, so nothing here fights the animal.
--   TURN   only for a `turnsBack` wave: the northern beater goes and a second appears SOUTH, in
--          front of them, near the road. They break back north. This is Karen's *"several go
--          back"*, and it is what stops the road being a shooting gallery.
--   DONE   no beater at all. Whatever is still on its feet drifts and settles.
--
-- THE BEATER FOLLOWS THE HERD, AND THAT IS THE WHOLE CORRECTION. The first version walked a beater
-- along a line from where the wave was RELEASED, at the field's single `groundY`. Two things were
-- wrong with it and the Director measured both: the animals drift, so a line from where they WERE
-- stops being behind them; and `SENSE.FLUSH_STUDS` is 15 -- a 3D distance -- while the beater stood
-- at y 138 and the animals on ground 40 to 56 studs higher, so the gap alone exceeded the radius
-- and nothing was ever flushed. A beater that cannot be reached is not a beater.
--
-- So a wave keeps its members' handles, takes their live centroid, and stands `pushStuds` behind it
-- AT THEIR OWN HEIGHT. 12 is inside the 15-stud flush radius with room for the centroid to lag.
ForestTest.WAVE = {
	pushSeconds = 26, -- long enough to walk a herd 150-250 studs to the road
	turnAtSeconds = 9, -- a `turnsBack` wave is pushed for this long before it is turned
	turnSeconds = 8,
	pushStuds = 12, -- behind the herd's own centroid, inside SENSE.FLUSH_STUDS (15)
	aheadStuds = 12, -- in front of it, to turn it
	-- A turn is only worth staging once they are near enough for the hunter to SEE it happen.
	turnWithinStuds = 90,
}

export type Phase = "push" | "turn" | "done"

function ForestTest.wavePhase(elapsed: number, turnsBack: boolean): Phase
	local wave = ForestTest.WAVE
	if turnsBack then
		if elapsed < wave.turnAtSeconds then
			return "push"
		end
		if elapsed < wave.turnAtSeconds + wave.turnSeconds then
			return "turn"
		end
		return "done"
	end
	if elapsed < wave.pushSeconds then
		return "push"
	end
	return "done"
end

-- WHERE THAT WAVE'S BEATER IS, or nil when there is none.
--
-- `at` is the herd's LIVE centroid, not where it was released -- see `ForestTest.WAVE`. North of the
-- herd pushes it south across the road; south of it turns it back north.
function ForestTest.beaterPosition(at: Vector3, elapsed: number, turnsBack: boolean): Vector3?
	local wave = ForestTest.WAVE
	local phase = ForestTest.wavePhase(elapsed, turnsBack)
	if phase == "push" then
		return at + Vector3.new(0, 0, wave.pushStuds)
	end
	if phase == "turn" then
		return at + Vector3.new(0, 0, -wave.aheadStuds)
	end
	return nil
end

-- THE LIVE CENTROID of whatever is left of a wave, or nil when nothing is. Dead and despawned
-- members drop out by themselves: a handle whose part has left the world is not counted.
function ForestTest.herdCentre(handles): Vector3?
	local sum, n = Vector3.zero, 0
	for _, handle in ipairs(handles) do
		local part = handle and handle.part
		if part ~= nil and part.Parent ~= nil then
			sum += part.Position
			n += 1
		end
	end
	if n == 0 then
		return nil
	end
	return sum / n
end

-- WHICH WAVE IS DUE. The cycle repeats forever, so a playtest never runs out of action.
function ForestTest.waveAt(index: number)
	local cycle = Data.SCHEDULE.cycle
	return cycle[((index - 1) % #cycle) + 1]
end

-- WHERE A HUNTER IS PUT when he picks stand `index`, and whether a position is still within his
-- leash. Pure, so the leash is one rule and not one rule per caller.
function ForestTest.withinLeash(position: Vector3, standIndex: number): boolean
	local home = Data.standPosition(standIndex)
	local flat = Vector3.new(position.X - home.X, 0, position.Z - home.Z)
	return flat.Magnitude <= Data.PICK.leashStuds
end

-- THE NEAREST STAND to a position, which is how a hunter picks one: he walks to it. Karen asked for
-- a square to select and save; standing on it IS the selection, and the save is the timer running
-- out or the player confirming -- neither of which this function needs to know about.
function ForestTest.nearestStand(position: Vector3): number
	local best, bestDistance = 1, math.huge
	for index = 1, Data.STAND_COUNT do
		local stand = Data.standPosition(index)
		local flat = Vector3.new(position.X - stand.X, 0, position.Z - stand.Z)
		if flat.Magnitude < bestDistance then
			best, bestDistance = index, flat.Magnitude
		end
	end
	return best
end

-- ---------------------------------------------------------------- the live half

local state = {
	started = false,
	runtime = nil :: any,
	startedAt = 0,
	nextWaveAt = 0,
	waveIndex = 0,
	active = {} :: { { centre: Vector3, handles: { any }, at: number, turnsBack: boolean, id: string } },
	picks = {} :: { [number]: { index: number, lockedAt: number? } },
	released = 0,
}

function ForestTest.stats()
	return {
		started = state.started,
		waves = state.waveIndex,
		released = state.released,
		active = #state.active,
		boars = if state.runtime then state.runtime:count() else 0,
	}
end

-- EVERY THREAT A BOAR CAN SEE IN THIS WORLD: the real players who are not hunters standing still,
-- plus the phantom beaters. Handed to the boar world at the composition root, exactly where
-- `Match.boarThreats` is handed over in the DEV place.
--
-- A HUNTER IS NOT A DRIVER. He is still a threat -- `kind = "shooter"` -- which with
-- `BOAR_BEHAVIOUR` on is noticed at 25 studs and flushes at 15, so a boar will not walk into him.
-- What he must not do is push the wave: that is the beater's job, and a hunter who pushed would
-- make the animals cross somewhere he is not.
function ForestTest.boarThreats(now: number)
	local out = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character.PrimaryPart
		if root then
			table.insert(out, { id = tostring(player.UserId), position = root.Position, kind = "shooter" })
		end
	end
	for _, wave in ipairs(state.active) do
		local centre = ForestTest.herdCentre(wave.handles)
		if centre ~= nil then
			local at = ForestTest.beaterPosition(centre, now - wave.at, wave.turnsBack)
			if at then
				table.insert(out, { id = wave.id, position = at, kind = "driver" })
			end
		end
	end
	return out
end

local function holdingByName(name: string)
	for _, entry in ipairs(Data.HOLDING) do
		if entry.name == name then
			return entry
		end
	end
	return nil
end

-- RELEASES ONE WAVE. Returns how many animals it actually put on the ground, which is never assumed
-- -- `spawnSounder` can refuse, and a wave that silently released nothing is a playtest with no
-- action in it and no line saying why.
function ForestTest.release(now: number): (number, string)
	local spec = ForestTest.waveAt(state.waveIndex + 1)
	state.waveIndex += 1
	local entry = holdingByName(spec.holding)
	if entry == nil then
		return 0, string.format("wave %d: no holding called %q", state.waveIndex, spec.holding)
	end
	local runtime = state.runtime
	if runtime == nil then
		return 0, "no runtime"
	end
	-- THE CAP IS CHECKED BEFORE THE SPAWN, not after, and it is the SMALLER of two caps.
	--
	-- Karen asked for *"a lot not too much to break"*, which is `Data.MAX_BOARS`. The runtime has
	-- its own ceiling as well (`maxBoars`), and `Runtime:spawn` ASSERTS rather than refusing when it
	-- is reached -- so asking past it is not a declined wave, it is an error that kills the
	-- heartbeat this runs on.
	local ceiling = math.min(Data.MAX_BOARS, runtime:capacity())
	local room = ceiling - runtime:count()
	if room <= 0 then
		return 0, string.format("wave %d held: %d of %d boars already out", state.waveIndex, runtime:count(), ceiling)
	end
	local size = math.min(spec.size, room)
	local centre = Data.holdingPosition(entry)
	-- WHAT THESE TWO ACTUALLY RETURN, read off `Boar` rather than assumed -- the first version of
	-- this line assumed both gave a count and crashed the whole schedule on the first wave with
	-- "attempt to compare number < table", so NO wave ever ran:
	--   `Runtime:spawnSounder` returns a TABLE of handles -- `{}` when it refuses, one handle when
	--     the size is 1, otherwise one per member. Its length is the count.
	--   `Runtime:spawn` returns a HANDLE, which is truthy and is not a number.
	-- THE HANDLES ARE KEPT, because the beater follows the herd and a herd is its members.
	local handles = {}
	if size <= 1 then
		local handle = runtime:spawn(centre, "male")
		if handle ~= nil then
			table.insert(handles, handle)
		end
	else
		handles = runtime:spawnSounder(centre, size, 30)
	end
	local placed = #handles
	if placed > 0 then
		table.insert(state.active, {
			centre = centre,
			handles = handles,
			at = now,
			turnsBack = spec.turnsBack == true,
			id = string.format("beater-%d", state.waveIndex),
		})
		state.released += placed
	end
	return placed, string.format("wave %d: %s, %d animal(s) -- %s", state.waveIndex, spec.holding, placed, spec.note)
end

-- Drops waves whose beater has gone, and waves with nothing left to push. The wave's surviving
-- animals stay; only the push is over.
function ForestTest.retire(now: number)
	for index = #state.active, 1, -1 do
		local wave = state.active[index]
		local gone = ForestTest.wavePhase(now - wave.at, wave.turnsBack) == "done"
		if gone or ForestTest.herdCentre(wave.handles) == nil then
			table.remove(state.active, index)
		end
	end
end

-- ---------------------------------------------------------------- the hunter's stand

function ForestTest.pickOf(userId: number)
	return state.picks[userId]
end

-- Opens the 10-second window. Nothing is locked yet: where he walks IS the choice.
function ForestTest.openPick(userId: number, now: number)
	state.picks[userId] = { index = Data.PICK.defaultIndex, lockedAt = nil, openedAt = now } :: any
end

-- Locks whatever he is nearest to. Called by the timer, or early when he confirms.
function ForestTest.lockPick(userId: number, position: Vector3, now: number): number
	local pick = state.picks[userId]
	if pick == nil then
		ForestTest.openPick(userId, now)
		pick = state.picks[userId]
	end
	if (pick :: any).lockedAt == nil then
		pick.index = ForestTest.nearestStand(position);
		(pick :: any).lockedAt = now
	end
	return pick.index
end

function ForestTest.clearPick(userId: number)
	state.picks[userId] = nil
end

-- PULLS A LOCKED HUNTER BACK INSIDE HIS LEASH. Returns the position it moved him to, or nil.
--
-- IT PULLS, IT DOES NOT FREEZE. Karen: *"he can move few steps on each side max"* -- and *"I want
-- tomorrow to test shooting and walking"*, so anchoring the character would break the thing she is
-- testing. Walking out simply stops being possible at six studs.
function ForestTest.leash(userId: number, root: BasePart): Vector3?
	local pick = state.picks[userId]
	if pick == nil or (pick :: any).lockedAt == nil then
		return nil
	end
	if ForestTest.withinLeash(root.Position, pick.index) then
		return nil
	end
	local home = Data.standPosition(pick.index)
	local flat = Vector3.new(root.Position.X - home.X, 0, root.Position.Z - home.Z)
	local pulled = home + flat.Unit * Data.PICK.leashStuds
	local to = Vector3.new(pulled.X, root.Position.Y, pulled.Z)
	root.CFrame = CFrame.new(to) * (root.CFrame - root.CFrame.Position)
	return to
end

-- ---------------------------------------------------------------- the loop

function ForestTest.start(runtime, now: number)
	state.runtime = runtime
	state.started = true
	state.startedAt = now
	state.nextWaveAt = now + Data.SCHEDULE.intervalSeconds
	state.waveIndex = 0
	state.released = 0
	state.active = {}
end

-- ONE TICK. Returns a line when something happened and nil otherwise, so the boot script can print
-- the drive's own account of itself rather than guessing at it.
function ForestTest.step(now: number): string?
	if not state.started then
		return nil
	end
	ForestTest.retire(now)
	if now < state.nextWaveAt then
		return nil
	end
	state.nextWaveAt = now + Data.SCHEDULE.intervalSeconds
	local _placed, line = ForestTest.release(now)
	return line
end

-- Where a hunter who has not picked yet should be put: on the road, at the default stand.
function ForestTest.spawnPosition(): Vector3
	local at = Data.standPosition(Data.PICK.defaultIndex)
	-- A little above the road so the character drops onto it rather than into it.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Workspace:FindFirstChild("Boars") }
	local hit = Workspace:Raycast(at + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), params)
	local y = if hit then hit.Position.Y else at.Y
	return Vector3.new(at.X, y + 4, at.Z)
end

return ForestTest
