--!strict
-- Shop (server): THE OWNER OF THE SHOP'S DOOR. The one listener of `Shop.Remotes.ShopRequest`, the
-- one sender of `ShopState`, the one holder of the per-player rate bucket, the one reader of where
-- he is standing, and the one place the ORDER of a purchase is written down.
--
-- WHAT IT DOES NOT OWN, and the boundary is the whole task (design section 2):
--   * IT NEVER WRITES A BALANCE, AN OWNERSHIP SET OR A PROFILE. `Economy` is the one owner of a
--     player's profile and `Economy.purchase` is the only function in this repository that writes
--     either half of a purchase. This module is handed two injected functions and cannot open a
--     session, cannot write a key and cannot reach the store.
--   * IT NEVER WRITES A LOADOUT, A POCKET, A TEAM, A TOOL, A CHARACTER OR ANYTHING DRAWN. What
--     ownership MEANS is read by the owners that already decide those things -- `Weapons.loadoutFor`,
--     `Weapon`'s shell allowance, `Match.mayCarryWeapon`, `Match.Body.dress` -- each through a
--     provider wired at the composition root, so neither owner requires this one.
--   * IT HOLDS NO PRICE AND NO RULE. `ReplicatedStorage.Shop` is the catalogue and the pure
--     refusal; this measures the one fact a rule needs that nothing else can see (is he at the
--     counter) and hands it over.
--
-- WHY IT IS ITS OWN OWNER AND NOT A MODULE UNDER `Economy` (design section 2.2): `Economy`'s own
-- header forbids both halves of a door -- *"WHAT IT NEVER DOES: ... hold a `Player` ..., fire a
-- remote"* -- and a door is a remote handler holding a Player and answering it. It also reads no
-- Instance at all, and the counter is a part in `Workspace`.
--
-- NOTHING HAPPENS ON REQUIRE. Only `Shop.start(world)` connects anything -- the rule `Match`,
-- `Boar`, `Weapon`, `Bots`, `Economy` and `Lobby` all follow, and what lets every spec drive the
-- whole door with no players, no remotes, no lobby and no economy.
--
-- NO CLOCK OF ITS OWN. The rate bucket reads the `now` it is given, which is `os.clock()` in
-- production and a number in a spec -- `HitLog.onRequest`'s mechanism.
--
-- Design: docs/design/shop.md (sections 9, 10.1)
-- Note:   docs/research/2026-10-14-the-shop.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage:WaitForChild("Shop"))

local Shop = {}

-- Re-exported for the specs, exactly as `Lobby.Data` and `Economy.Coins` are.
Shop.Data = Data

-- THE ONE FLAG READ AT THIS OWNER'S BOUNDARY, passed inward through `start`'s `world.enabled` --
-- the only permitted shape (CLAUDE.md, feature flags). Both branches stay reachable BY PARAMETER
-- while the row sits at `false`.
Shop.ENABLED = Data.isOn()

local started = false
local world: any = nil
local enabled = false
local cfg = Data.CONFIG
local connections: { RBXScriptConnection } = {}
-- The only table keyed by a player, and `forget` empties it.
local lastRequestAt: { [number]: number } = {}

local stats = {
	requests = 0,
	-- A FORGED PAYLOAD and A REFUSED PURCHASE ARE COUNTED APART, which is `Weapon.stats`' own split
	-- and its stated reason: *"a refused shot is a LEGAL request that the game said no to, and
	-- counting it as a bad request would hide a mis-wired provider inside the forgery counter"*.
	badRequests = 0,
	rateLimited = 0,
	opens = 0,
	buys = 0,
	granted = 0,
	refusedBy = {} :: { [string]: number },
	-- A well-formed id naming no row: a STALE CLIENT after a catalogue change, which is a different
	-- fact from a forged packet.
	unknownItems = 0,
	-- A reply that could not be sent because he had already left.
	repliesDropped = 0,
}

function Shop.stats()
	local out = table.clone(stats)
	out.refusedBy = table.clone(stats.refusedBy)
	return out
end

function Shop.isEnabled(): boolean
	return enabled
end

local function count(reason: string)
	stats.refusedBy[reason] = (stats.refusedBy[reason] or 0) + 1
	if reason == Data.REASON.UNKNOWN then
		stats.unknownItems += 1
	end
end

-- ---------------------------------------------------------------- the one world read

-- WHERE HE IS STANDING, from the character the SERVER can see -- never from anything a client sent.
-- Injectable (`world.rootOf`) because a spec has no character, the `Match`/`Bots` test-seam idiom.
local function rootOf(player: any): Vector3?
	if world.rootOf ~= nil then
		local ok, at = pcall(world.rootOf, player)
		return if ok and typeof(at) == "Vector3" then at else nil
	end
	local character = player.Character
	local root = character and character.PrimaryPart
	return if root then root.Position else nil
end

-- IS HE AT THE COUNTER? Measured HERE, per request, never cached: the client's panel closing when he
-- walks away is cosmetic, and this is the rule.
--
-- A WORLD WITH NO COUNTER ANSWERS FALSE AND EVERY PURCHASE IN IT IS REFUSED `too-far`. That is the
-- DEV place, which has no lodge at all (design section 10.4), and it is why the reach rule's
-- evidence is pure plus the injected seam rather than a live walk-up.
function Shop.atCounter(player: any): boolean
	local at: Vector3? = nil
	if world.counterAt ~= nil then
		local ok, found = pcall(world.counterAt)
		at = if ok and typeof(found) == "Vector3" then found else nil
	end
	return Data.withinReach(rootOf(player), at, cfg.REACH_STUDS)
end

-- ---------------------------------------------------------------- the door

-- IS HE ASKING TOO OFTEN? One number per player. A FORGERY GUARD and not a game rule: a person
-- cannot press a button four times a second.
function Shop.rateLimited(userId: number, now: number): boolean
	local last = lastRequestAt[userId]
	if last ~= nil and now - last < cfg.REQUEST_MIN_INTERVAL then
		return true
	end
	lastRequestAt[userId] = now
	return false
end

local function reply(player: any, receipt: any?)
	if player.Parent == nil then
		-- HE LEFT BETWEEN THE REQUEST AND THE REPLY. Counted rather than fired at nobody.
		stats.repliesDropped += 1
		return
	end
	if world.remotes == nil or world.snapshotFor == nil then
		return
	end
	world.remotes.ShopState:FireClient(player, world.snapshotFor(player.UserId, receipt))
end

-- THE ONE INBOUND HANDLER, and it is PUBLIC for `Weapon.onFireRequest`'s stated reason: it is the
-- seam a forged request arrives through, reachable by parameter as well as by remote, because
-- `OnServerEvent` can only be raised by a client (task 80).
--
-- IT RETURNS ITS OWN DECISION -- `{ ok, refused, number }` or nil for a request that was not
-- answered at all -- so a spec gets a per-call answer instead of inferring one from a counter
-- (task 80 round 2's correction).
function Shop.onRequest(player: any, request: any, now: number?): any
	if not started then
		return nil
	end
	stats.requests += 1
	local kind = if type(request) == "table" then (request :: any).kind else nil
	local item = if type(request) == "table" then (request :: any).item else nil
	local ok, bad = Data.checkRequest(kind, item)
	if not ok then
		-- NOTHING IS SENT BACK: the client that forged it is not told what shape would have worked.
		stats.badRequests += 1
		return { ok = false, refused = bad }
	end
	if Shop.rateLimited(player.UserId, now or os.clock()) then
		stats.rateLimited += 1
		return nil
	end
	if kind == Data.KIND.OPEN then
		stats.opens += 1
		reply(player, nil)
		return { ok = true }
	end
	stats.buys += 1
	local receipt = world.purchase(player.UserId, item, { atCounter = Shop.atCounter(player) })
	if receipt ~= nil and receipt.ok == true then
		stats.granted += 1
	elseif receipt ~= nil and type(receipt.refused) == "string" then
		count(receipt.refused)
	end
	reply(player, receipt)
	return receipt
end

-- ---------------------------------------------------------------- lifecycle

export type World = {
	enabled: boolean?,
	-- `Economy.purchase`: the only writer of a purchase. REQUIRED.
	purchase: ((userId: number, itemId: string, facts: { atCounter: boolean? }?) -> any)?,
	-- `Economy.shopStateFor`: this player's own payload. REQUIRED.
	snapshotFor: ((userId: number, receipt: any?) -> any)?,
	-- `Lobby.counterPosition`, or nil for a world with no lodge.
	counterAt: (() -> Vector3?)?,
	rootOf: ((player: any) -> Vector3?)?,
	remotes: any?,
	players: any?,
	config: any?,
}

function Shop.start(injected: World?): boolean
	assert(not started, "Shop.start() called twice")
	world = injected or {}
	cfg = world.config or Data.CONFIG
	enabled = if world.enabled ~= nil then world.enabled == true else Shop.ENABLED
	table.clear(lastRequestAt)
	for key, value in pairs(stats) do
		if type(value) == "number" then
			stats[key] = 0
		end
	end
	stats.refusedBy = {}
	if not enabled then
		-- OFF CONNECTS NOTHING AND READS NOTHING, so the game is task 177's game bit for bit: no
		-- inbound remote, no profile field written, the hunter keeps his rifle and his twelve slugs
		-- and a beater carries nothing.
		print("[shop] off (born dark, task 178): the counter sells nothing and no ownership is read")
		return false
	end
	-- EVERY REQUIRED SEAM IS NAMED, the rule `Lobby.start` states and enforces: a boot that forgot
	-- one would get a shop that takes clicks and changes nothing, in silence.
	for _, name in ipairs({ "purchase", "snapshotFor" }) do
		if type((world :: any)[name]) ~= "function" then
			warn(string.format("[shop] start: no %s was injected, so the shop stays shut", name))
			enabled = false
			return false
		end
	end
	started = true
	world.players = world.players or Players
	-- ...AND THE ONE TABLE KEYED BY A PLAYER IS PRUNED WHEN HE LEAVES (the Reviewer's round-1 note).
	-- `Shop.forget` had no production caller at all, so `lastRequestAt` grew for the life of the
	-- server -- one number per player who ever opened the panel -- and the spec that calls `forget`
	-- was certifying a cleanup nothing ran. `Match.forget`'s own rule, on the owner that holds the
	-- table.
	if world.players ~= nil and world.players.PlayerRemoving ~= nil then
		table.insert(
			connections,
			world.players.PlayerRemoving:Connect(function(player: Player)
				Shop.forget(player.UserId)
			end)
		)
	end
	if world.remotes ~= nil then
		-- GUARDED, because a seam that answers nothing must not take the boot down with it: a
		-- `RemoteEvent` double whose `Connect` returns nil is a legal stand-in (a spec drives
		-- `Shop.onRequest` by parameter, which is the whole point of that function being public),
		-- and `table.insert(t, nil)` throws. MEASURED in round 1 of this task: nine cases of
		-- `shop_door.spec` died inside `start` rather than failing an assertion.
		local connection = world.remotes.ShopRequest.OnServerEvent:Connect(function(player: Player, payload: any)
			Shop.onRequest(player, payload)
		end)
		if connection ~= nil then
			table.insert(connections, connection)
		end
	end
	print(string.format("[shop] on: the counter in the lodge lists %d item(s)", #Data.ORDER))
	return true
end

function Shop.stop()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(lastRequestAt)
	started = false
	enabled = false
	world = nil
	cfg = Data.CONFIG
end

-- After this, no table in this system is keyed by that player -- `Match.forget`'s own rule.
function Shop.forget(userId: number)
	lastRequestAt[userId] = nil
end

return Shop
