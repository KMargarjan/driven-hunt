--!strict
-- ServerScriptService.Match.StandPick: THE ONE WRITER OF WHICH HUNTER HOLDS WHICH STAND, this drive.
--
-- Karen, 2026-10-31: *"...choose shooting place on map before hunt"*. The claim is a fact about the
-- DRIVE'S ROSTER, so it lives under `Match`, which already owns the roster, the phase and the line.
--
-- Pattern: a pure rule per question over an injected measurement (`Weapon.Rules`, `Lobby.Pads`), and
-- a serial-dictatorship fallback that is `HighSeats.dealLine`'s (Abdulkadiroglu and Sonmez 1998).
-- Sequential handlers over one authoritative table is Colyseus's `Room.onMessage` shape (MIT); the
-- refusal ORDER is Source SDK 2013's `HandleCommand_JoinTeam` (idea only, nothing copied).
--
-- `claim` YIELDS NOWHERE, and that is what makes "first request wins" a property of this code rather
-- than a hope: Roblox's docs do not state that `OnServerEvent` handlers are serialised, so the
-- guarantee is ours (design section 5.2).
--
-- Design: docs/design/stand-pick.md (sections 2, 5, 7)
-- Note:   docs/research/2026-11-01-stand-pick.md
local StandPick = {}

export type Ask = {
	userId: number,
	stand: any, -- `any` ON PURPOSE: a forged client sends a string, a float or a table (section 7.6)
	now: number,
	open: boolean, -- `Phase.pickWindow`, measured by the owner
	standCount: number, -- what the WORLD says, not `#markers.posts` (section 7.5)
	isHunter: boolean, -- `state.assignment[userId] == "Shooters"`, measured by the owner
	seated: boolean, -- does THIS stand carry a high seat
	entitled: boolean?, -- may he use one. nil is "nobody answered", which is YES
	heldBy: number?, -- who holds that stand now
	mine: number?, -- which stand HE holds now
	lastAt: number?, -- when his last ACCEPTED change was
	asks: number, -- how many asks he has made this drive
	config: any,
}

export type Verdict = {
	ok: boolean,
	stand: any,
	reason: string?,
}

StandPick.REASON = table.freeze({
	CLOSED = "closed",
	ROLE = "role",
	RANGE = "range",
	RATE = "rate",
	FLOOD = "flood",
	SAME = "same",
	SEAT = "seat",
	TAKEN = "taken",
})

-- THE ORDER IS `Weapon.Rules.ORDER`'S OWN RULE: the outermost fact about the asker first -- the thing
-- he must fix before any other answer is even useful. "TAKEN" to a beater, or to a man asking after
-- the horn, sends him to fix the wrong thing.
StandPick.ORDER = table.freeze({
	StandPick.REASON.CLOSED,
	StandPick.REASON.ROLE,
	StandPick.REASON.RANGE,
	StandPick.REASON.RATE,
	StandPick.REASON.FLOOD,
	StandPick.REASON.SAME,
	StandPick.REASON.SEAT,
	StandPick.REASON.TAKEN,
})

-- WHAT HIS SCREEN SAYS, or nil for a refusal that draws nothing. `rate`, `flood` and `same` are
-- silent: he did nothing wrong, and drawing "too fast" teaches a forger the limit. Every word is
-- <= 25 ASCII, inside `Objective.CONFIG.TEXT`'s measured bound of 33 (design section 5.1).
StandPick.WORDS = table.freeze({
	closed = "too late",
	role = "beaters have no stand",
	range = "no such stand",
	seat = "you need tree-stand access",
	taken = "taken",
})

-- IS IT A STAND NUMBER AT ALL? A client's `"4"` is a client's TYPE, and `tonumber` on it would be
-- the server believing one (Roblox docs: never trust the client).
local function wholeStandIn(value: any, count: number): boolean
	if type(value) ~= "number" then
		return false
	end
	local n = value :: number
	-- `n ~= n` catches 0/0; the floor test catches 2.5 and math.huge (huge == floor(huge), so the
	-- upper bound is what refuses it).
	if n ~= n or n ~= math.floor(n) then
		return false
	end
	return n >= 1 and n <= count
end

-- THE WHOLE RULE, PURE: no service, no `Player`, no clock, no state. The caller measures the world
-- and this decides, which is why every refusal is a spec case with nothing staged.
function StandPick.judge(ask: Ask): (boolean, string?)
	local cfg = ask.config or {}
	if ask.open ~= true then
		return false, StandPick.REASON.CLOSED
	end
	if ask.isHunter ~= true then
		return false, StandPick.REASON.ROLE
	end
	if not wholeStandIn(ask.stand, ask.standCount) then
		return false, StandPick.REASON.RANGE
	end
	local interval = tonumber(cfg.STAND_PICK_MIN_INTERVAL) or 0
	if ask.lastAt ~= nil and ask.now - (ask.lastAt :: number) < interval then
		return false, StandPick.REASON.RATE
	end
	local maxAsks = tonumber(cfg.STAND_PICK_MAX_REQUESTS) or math.huge
	if (ask.asks or 0) > maxAsks then
		return false, StandPick.REASON.FLOOD
	end
	if ask.mine ~= nil and ask.mine == ask.stand then
		return false, StandPick.REASON.SAME
	end
	-- nil IS "NOBODY ANSWERED", WHICH IS YES -- `Shop.grantsHighSeat`'s own nil rule, so a build with
	-- no economy answers exactly what it answers today.
	if ask.seated == true and ask.entitled == false then
		return false, StandPick.REASON.SEAT
	end
	if ask.heldBy ~= nil and ask.heldBy ~= ask.userId then
		return false, StandPick.REASON.TAKEN
	end
	return true, nil
end

-- ------------------------------------------------------------------------------------- the claim

local byUser: { [number]: number } = {} -- userId -> stand
local byStand: { [number]: number } = {} -- stand -> userId
local lastAt: { [number]: number } = {}
local askCount: { [number]: number } = {}
local driveNumber: number? = nil
local open = false

local stats = {
	asks = 0,
	accepted = 0,
	-- A PAYLOAD THAT WAS NOT A NUMBER AT ALL, counted rather than coerced (design section 7.6).
	malformed = 0,
	moved = 0,
	movedStuds = 0,
	refused = {
		closed = 0,
		role = 0,
		range = 0,
		rate = 0,
		flood = 0,
		same = 0,
		seat = 0,
		taken = 0,
	},
}

-- EVERY CLAIM DROPPED, AND THE DRIVE REMEMBERED. Called on the `Assigning` edge, so a claim of stand
-- 7 from a nine-stand `road` cannot survive into a five-stand `ride` (design section 7.5).
function StandPick.reset(drive: number)
	table.clear(byUser)
	table.clear(byStand)
	table.clear(lastAt)
	table.clear(askCount)
	driveNumber = drive
	open = true
end

function StandPick.close()
	open = false
end

function StandPick.isOpen(): boolean
	return open
end

function StandPick.driveOf(): number?
	return driveNumber
end

-- COUNTS ONE ASK AND ANSWERS HOW MANY HE HAS MADE THIS DRIVE. Separate from `claim` because a
-- REFUSED ask still costs the server a message, which is what `flood` is a ceiling on.
function StandPick.noteAsk(userId: number): number
	local n = (askCount[userId] or 0) + 1
	askCount[userId] = n
	stats.asks += 1
	return n
end

function StandPick.asksBy(userId: number): number
	return askCount[userId] or 0
end

function StandPick.noteMalformed()
	stats.malformed += 1
end

function StandPick.noteRefusal(reason: string?)
	if reason ~= nil and stats.refused[reason] ~= nil then
		stats.refused[reason] += 1
	end
end

function StandPick.lastChangeAt(userId: number): number?
	return lastAt[userId]
end

-- TAKE IT. **YIELDS NOWHERE** -- no `pcall` into a provider, no `LoadCharacter`, no `task.wait` --
-- so two requests in the same frame are resolved by the handler queue and the table is written
-- before anything in the handler can yield (design section 7.1, E1).
--
-- IT DOES NOT JUDGE. The owner judges with the world it measured and calls this only on an accept,
-- which is the `Weapon.Rules` split: one function decides, another writes.
function StandPick.claim(userId: number, stand: number, now: number): (boolean, string?)
	local holder = byStand[stand]
	if holder ~= nil and holder ~= userId then
		return false, StandPick.REASON.TAKEN
	end
	local had = byUser[userId]
	if had ~= nil and had ~= stand then
		byStand[had] = nil -- A STAND FREED BY A CHANGE IS FREE AT ONCE (D4)
	end
	byUser[userId] = stand
	byStand[stand] = userId
	lastAt[userId] = now
	stats.accepted += 1
	return true, nil
end

-- GIVE IT BACK, and answer WHICH stand was freed so the owner knows whether to force a broadcast.
function StandPick.release(userId: number): number?
	local had = byUser[userId]
	byUser[userId] = nil
	lastAt[userId] = nil
	if had ~= nil then
		byStand[had] = nil
	end
	return had
end

function StandPick.standOf(userId: number): number?
	return byUser[userId]
end

function StandPick.holderOf(stand: number): number?
	return byStand[stand]
end

-- THE SNAPSHOT FIELD: stand -> userId, keyed by `tostring(stand)` because a table on the wire has
-- string keys (`MatchSnapshot.stands` and `Horn.keyFor`'s own keying). FROZEN, so no reader can
-- write it, and nil when there is nothing claimed -- ABSENT means "no pick in this build".
function StandPick.wireTable(): { [string]: number }
	local out: { [string]: number } = {}
	for stand, userId in pairs(byStand) do
		out[tostring(stand)] = userId
	end
	return table.freeze(out)
end

function StandPick.anyClaim(): boolean
	return next(byUser) ~= nil
end

-- WHAT EACH HUNTER TOOK, BY LINE INDEX -- `dealLine`'s 5th argument and nothing else builds it.
-- `ids` is the sorted roster the owner built `entitled` from, so the two lists cannot drift.
function StandPick.picksFor(ids: { number }): { number? }
	local out: { number? } = {}
	for index, userId in ipairs(ids) do
		out[index] = byUser[userId]
	end
	return out
end

-- HOW MANY HUNTERS HOLD A CLAIM (the move count's own expected value, design section 12).
function StandPick.claimCount(): number
	local n = 0
	for _ in pairs(byUser) do
		n += 1
	end
	return n
end

function StandPick.noteMove(studs: number)
	stats.moved += 1
	stats.movedStuds = math.max(stats.movedStuds, studs)
end

function StandPick.stats()
	return {
		asks = stats.asks,
		accepted = stats.accepted,
		malformed = stats.malformed,
		moved = stats.moved,
		movedStuds = stats.movedStuds,
		refused = table.clone(stats.refused),
	}
end

-- FOR THE SPECS AND FOR `Match.stop`: no table in this module outlives a session.
function StandPick.clear()
	table.clear(byUser)
	table.clear(byStand)
	table.clear(lastAt)
	table.clear(askCount)
	driveNumber = nil
	open = false
	stats.asks = 0
	stats.accepted = 0
	stats.malformed = 0
	stats.moved = 0
	stats.movedStuds = 0
	for reason in pairs(stats.refused) do
		stats.refused[reason] = 0
	end
end

function StandPick.forget(userId: number)
	StandPick.release(userId)
	askCount[userId] = nil
end

return StandPick
