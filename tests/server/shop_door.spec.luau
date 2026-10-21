-- shop_door.spec: THE SHOP'S DOOR (task 178) -- the one inbound remote handler, against fakes.
--
-- IT DRIVES `Shop.onRequest` BY PARAMETER, which is why that function is public:
-- *"THE SEAM A FORGED REQUEST ARRIVES THROUGH ... `OnServerEvent` can only be raised by a client"*
-- (`Weapon.onFireRequest`'s own words, task 80). So every case here is a forged packet, a rate-limit
-- burst or a man standing in the wrong place, with no client, no lobby, no economy and no clock.
--
-- WHAT IT PROVES, and each one is a thing a player could otherwise do: a price cannot cross the
-- wire, a made-up item id buys nothing, a held-down key costs one reply and not fifty, a purchase
-- from the middle of a field is refused, a reply is never fired at a player who has left, and a boot
-- that forgot a seam gets a shop that says it is shut rather than one that takes clicks and changes
-- nothing.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/shop.md (sections 9, 10.1, 12.2)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shop = require(ServerScriptService:WaitForChild("Shop"))
local ShopData = require(ReplicatedStorage:WaitForChild("Shop"))
-- THE KIT THE GATE BELOW DECIDES (task 233b). `Weapons` is the one owner of what guns exist and
-- `ShopData.startFor` of what shells they are issued, and both take the ownership set BY PARAMETER --
-- so the second half of "a world with no counter wires nothing" can be stated here, next to the
-- boolean the composition root branches on, instead of in a third file.
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

-- A PLAYER THIS SPEC OWNS: a userId, a Parent that can be taken away, and nothing else. The
-- `fakePlayers` idiom every owner's spec here uses -- no `Players` service is touched.
local function fakePlayer(userId: number, parented: boolean?)
	return {
		UserId = userId,
		Name = string.format("P%d", userId),
		Parent = if parented == false then nil else ReplicatedStorage :: any,
	}
end

-- A TILL THIS SPEC OWNS: it records what it was asked and answers what the case wants, so the door
-- is tested without `Economy`, without a profile and without a store. The real pairing is
-- `economy.spec`'s.
local function fakeEconomy(options)
	local opts = options or {}
	local calls = { purchase = 0, snapshot = 0 }
	local asked = {}
	return {
		calls = calls,
		asked = asked,
		purchase = function(userId: number, itemId: string, facts: any)
			calls.purchase += 1
			table.insert(asked, { userId = userId, itemId = itemId, atCounter = facts and facts.atCounter })
			if opts.receipt ~= nil then
				return opts.receipt
			end
			local row = ShopData.row(itemId)
			if row == nil then
				return { ok = false, refused = ShopData.REASON.UNKNOWN }
			end
			if facts ~= nil and facts.atCounter == false then
				return { ok = false, refused = ShopData.REASON.TOO_FAR }
			end
			return { ok = true, item = itemId, price = row.price, balance = 1 }
		end,
		snapshotFor = function(_userId: number, receipt: any)
			calls.snapshot += 1
			return { coinsOn = true, balance = 1, hunts = 0, rows = {}, refused = receipt and receipt.refused }
		end,
	}
end

-- The one remote pair, faked: a `FireClient` that records who it was fired at.
local function fakeRemotes()
	local sent = {}
	return sent,
		{
			ShopRequest = {
				OnServerEvent = {
					-- A REAL `Connect` ANSWERS A CONNECTION, so the double answers one too: the
					-- owner keeps it to disconnect on `stop`, and a double that answered nil used to
					-- crash `start` (round 1 of this task).
					Connect = function()
						return { Disconnect = function() end }
					end,
				},
			},
			ShopState = {
				FireClient = function(_, player: any, payload: any)
					table.insert(sent, { userId = player.UserId, payload = payload })
				end,
			},
		}
end

return function()
	describe("the door", function()
		local function started(options)
			local opts = options or {}
			local sent, remotes = fakeRemotes()
			local economy = opts.economy or fakeEconomy()
			Shop.stop() -- never inherit another case's state
			local on = Shop.start({
				enabled = opts.enabled ~= false,
				purchase = if opts.noPurchase then nil else economy.purchase,
				snapshotFor = economy.snapshotFor,
				-- `noCounter` IS NOT `counterAt = nil` SPELT TWICE (task 233b): `opts.counterAt or
				-- <default>` cannot express "the root supplied no reader at all", which is the fact
				-- `Shop.start`'s gate reads, so the case has to say it in a field of its own.
				counterAt = if opts.noCounter
					then nil
					else opts.counterAt or function()
						return Vector3.new(0, 0, 0)
					end,
				rootOf = opts.rootOf or function()
					return Vector3.new(0, 0, 0)
				end,
				remotes = remotes,
			})
			return { on = on, sent = sent, economy = economy }
		end

		afterEach(function()
			Shop.stop()
		end)

		it("sells an item to a player standing at the counter, and replies once", function()
			local world = started()
			expect(world.on).to.equal(true)
			local player = fakePlayer(1)
			local receipt = Shop.onRequest(player, { kind = ShopData.KIND.BUY, item = ShopData.ITEM.SLUG }, 0)
			expect(receipt.ok).to.equal(true)
			expect(world.economy.calls.purchase).to.equal(1)
			-- THE DOOR MEASURED THE REACH AND HANDED IT OVER: the till never reads an Instance.
			expect(world.economy.asked[1].atCounter).to.equal(true)
			expect(world.economy.asked[1].itemId).to.equal(ShopData.ITEM.SLUG)
			expect(#world.sent).to.equal(1)
			expect(world.sent[1].userId).to.equal(1)
			expect(Shop.stats().granted).to.equal(1)
			expect(Shop.stats().buys).to.equal(1)
		end)

		it("answers an `open` with a payload and charges nothing", function()
			local world = started()
			local answer = Shop.onRequest(fakePlayer(2), { kind = ShopData.KIND.OPEN }, 0)
			expect(answer.ok).to.equal(true)
			expect(world.economy.calls.purchase).to.equal(0)
			expect(#world.sent).to.equal(1)
			expect(Shop.stats().opens).to.equal(1)
		end)

		-- A FORGED PACKET IS COUNTED AND ANSWERED WITH NOTHING: the client that sent it is not told
		-- what shape would have worked, and the counter is separate from a refusal's.
		it("refuses a forged payload, replies to nobody, and counts it apart from a refusal", function()
			local world = started()
			local player = fakePlayer(3)
			local at = 0
			for _, payload in ipairs({
				{ kind = "sell", item = ShopData.ITEM.SLUG },
				{ kind = ShopData.KIND.BUY },
				{ kind = ShopData.KIND.BUY, item = 7 },
				{ kind = ShopData.KIND.OPEN, item = ShopData.ITEM.SLUG },
				{ kind = ShopData.KIND.BUY, item = string.rep("x", ShopData.CONFIG.MAX_ID_CHARS + 1) },
				-- A PRICE IS NOT A FIELD OF A REQUEST. `kind` is missing here, so the whole thing
				-- is a bad request -- and even with a legal kind the price is simply never read.
				{ price = 0 },
				"nope",
				42,
			}) do
				at += ShopData.CONFIG.REQUEST_MIN_INTERVAL
				local answer = Shop.onRequest(player, payload, at)
				expect(answer.ok).to.equal(false)
				expect(answer.refused).to.equal("bad-request")
			end
			expect(Shop.stats().badRequests).to.equal(8)
			expect(world.economy.calls.purchase).to.equal(0)
			expect(#world.sent).to.equal(0)
			expect(next(Shop.stats().refusedBy)).to.equal(nil)
		end)

		-- A WELL-FORMED ID NAMING NO ROW IS NOT A FORGERY: it is a stale client, counted on its own.
		it("takes a made-up item to the till, which refuses it, and counts it as unknown", function()
			local world = started()
			local receipt = Shop.onRequest(fakePlayer(4), { kind = ShopData.KIND.BUY, item = "rifle.free" }, 0)
			expect(receipt.ok).to.equal(false)
			expect(receipt.refused).to.equal(ShopData.REASON.UNKNOWN)
			expect(Shop.stats().unknownItems).to.equal(1)
			expect(Shop.stats().badRequests).to.equal(0)
			expect(Shop.stats().refusedBy[ShopData.REASON.UNKNOWN]).to.equal(1)
			-- ...AND THE PLAYER IS STILL TOLD, because a shop that silently ignores a click is a shop
			-- that looks broken.
			expect(#world.sent).to.equal(1)
		end)

		it("limits one player to four requests a second and replies once to a burst", function()
			local world = started()
			local player = fakePlayer(5)
			for _ = 1, 5 do
				Shop.onRequest(player, { kind = ShopData.KIND.OPEN }, 100)
			end
			expect(Shop.stats().rateLimited).to.equal(4)
			expect(#world.sent).to.equal(1)
			-- ...and the limit is per player, not per server: a second man is not silenced by the
			-- first one's spam.
			Shop.onRequest(fakePlayer(6), { kind = ShopData.KIND.OPEN }, 100)
			expect(#world.sent).to.equal(2)
			-- ...and it lets him through once the interval has passed.
			Shop.onRequest(player, { kind = ShopData.KIND.OPEN }, 100 + ShopData.CONFIG.REQUEST_MIN_INTERVAL)
			expect(#world.sent).to.equal(3)
			-- A FORGED PACKET IS CHECKED BEFORE THE BUCKET, so a flood of rubbish is counted as
			-- rubbish rather than hidden behind the limiter.
			expect(Shop.stats().badRequests).to.equal(0)
		end)

		it("refuses a purchase from the middle of a field, measured per request", function()
			local world = started({
				rootOf = function()
					return Vector3.new(500, 0, 500)
				end,
			})
			local receipt = Shop.onRequest(fakePlayer(7), { kind = ShopData.KIND.BUY, item = ShopData.ITEM.SLUG }, 0)
			expect(receipt.refused).to.equal(ShopData.REASON.TOO_FAR)
			expect(world.economy.asked[1].atCounter).to.equal(false)
			expect(Shop.stats().refusedBy[ShopData.REASON.TOO_FAR]).to.equal(1)
		end)

		-- THE DEV PLACE HAS NO LODGE AND SO NO COUNTER, and that is not a defect (design 10.4).
		it("refuses every purchase in a world with no counter at all", function()
			local world = started({
				counterAt = function()
					return nil
				end,
			})
			local receipt = Shop.onRequest(fakePlayer(8), { kind = ShopData.KIND.BUY, item = ShopData.ITEM.SLUG }, 0)
			expect(receipt.refused).to.equal(ShopData.REASON.TOO_FAR)
			expect(world.economy.asked[1].atCounter).to.equal(false)
		end)

		it("never fires a reply at a player who has left, and counts the drop", function()
			local world = started()
			local gone = fakePlayer(9, false)
			Shop.onRequest(gone, { kind = ShopData.KIND.OPEN }, 0)
			expect(#world.sent).to.equal(0)
			expect(Shop.stats().repliesDropped).to.equal(1)
		end)

		-- ---------------------------------------------------------------- the counter gate (task 233b)
		--
		-- `SHOP` IS A V1 DEFAULT SINCE TASK 233b, so the flag is no longer the only gate and this is
		-- the other one. THE DECISION IS MADE ONCE, in `Shop.start`, and the composition root
		-- branches on its return value: `if shopOn then` is the one line in `MatchBoot` and
		-- `ForestTestBoot` that wires the entitlement, the licence, the look, the high seat and the
		-- always-hunter. So the boolean below IS the wiring, and both arms are driven BY PARAMETER.
		--
		-- WHAT THE SPEC CANNOT DO is run a composition root, so the KIT each arm produces is stated
		-- against the two pure owners of it rather than through a live `setEntitlementProvider`:
		-- unwired means the provider answers `nil`, and `nil` is the full loadout and the weapon's
		-- own shells (`Weapon.setEntitlementProvider`'s own header, design section 7.1).
		local SHOTGUN = (Weapons.ROWS :: any).shotgun
		local function kitFor(owned: { [string]: boolean }?)
			return Weapons.loadoutFor(true, owned), ShopData.startFor(SHOTGUN, owned)
		end

		it("wires nothing in a world with no counter, so that world keeps today's kit", function()
			local off = started({ noCounter = true })
			-- THE ROOT'S `if shopOn then` IS FALSE, so not one provider is wired.
			expect(off.on).to.equal(false)
			expect(Shop.isEnabled()).to.equal(false)
			-- ...AND THE DOOR IS NOT EVEN LISTENING: nothing was started, so a forged packet is not
			-- answered at all rather than answered `too-far`.
			expect(Shop.onRequest(fakePlayer(20), { kind = ShopData.KIND.BUY, item = ShopData.ITEM.SLUG }, 0)).to.equal(
				nil
			)
			expect(#off.sent).to.equal(0)
			expect(off.economy.calls.purchase).to.equal(0)
			-- THE KIT IS TODAY'S GAME, which is what the DEV place keeps: the whole loadout, and the
			-- shotgun's own shells with the slug in them.
			local loadout, start = kitFor(nil)
			expect(#loadout).to.equal(#Weapons.loadoutFor(true, nil))
			expect(#loadout > 1).to.equal(true)
			expect(start.ammo).to.equal(SHOTGUN.INITIAL_AMMO)
			expect(start.reserve.Slug).to.equal(SHOTGUN.START_RESERVE.Slug)
		end)

		it("wires the shop in a world that has one, and an un-owning player then has buckshot", function()
			local on = started({
				counterAt = function()
					return Vector3.new(0, 0, 0)
				end,
			})
			expect(on.on).to.equal(true)
			expect(Shop.isEnabled()).to.equal(true)
			-- THE OTHER ARM OF THE SAME `if`: the provider IS wired, so a player who has bought
			-- nothing is an EMPTY ownership set and not nil -- buckshot and the shotgun alone, with
			-- the slug as the ladder's first rung (120 coins).
			local loadout, start = kitFor({})
			expect(#loadout).to.equal(1)
			expect(loadout[1]).to.equal(Weapons.PRIMARY)
			expect(start.ammo).to.equal("Buck")
			-- AN EMPTY POCKET AND NOT AN ABSENT ONE, so the readout stays honest.
			expect(start.reserve.Slug).to.equal(0)
			expect(start.reserve.Buck).to.equal(SHOTGUN.START_RESERVE.Buck)
			-- ...AND HE CAN BUY HIS WAY OFF IT, which is the whole difference from the case above:
			-- there is a counter here, so the purchase is taken rather than refused `too-far`.
			local receipt = Shop.onRequest(fakePlayer(21), { kind = ShopData.KIND.BUY, item = ShopData.ITEM.SLUG }, 0)
			expect(receipt.ok).to.equal(true)
			expect(on.economy.asked[1].atCounter).to.equal(true)
		end)

		it("stays shut with the flag off, and shut when a seam is missing", function()
			local off = started({ enabled = false })
			expect(off.on).to.equal(false)
			expect(Shop.isEnabled()).to.equal(false)
			-- ...AND NOTHING IS ANSWERED AT ALL, because nothing was started.
			expect(Shop.onRequest(fakePlayer(10), { kind = ShopData.KIND.OPEN }, 0)).to.equal(nil)
			expect(#off.sent).to.equal(0)

			-- A BOOT THAT FORGOT `purchase` GETS A SHOP THAT SAYS SO, the rule `Lobby.start` states:
			-- a shop that took clicks and changed nothing would be the silent failure.
			local broken = started({ noPurchase = true })
			expect(broken.on).to.equal(false)
			expect(Shop.isEnabled()).to.equal(false)
		end)

		it("forgets a player and hands everything back on stop", function()
			started()
			local player = fakePlayer(11)
			Shop.onRequest(player, { kind = ShopData.KIND.OPEN }, 0)
			-- THE RATE BUCKET IS THE ONLY TABLE KEYED BY HIM, and `forget` empties it: the next
			-- request from the same userId is not held back by a previous session's timestamp.
			Shop.forget(11)
			Shop.onRequest(player, { kind = ShopData.KIND.OPEN }, 0)
			expect(Shop.stats().rateLimited).to.equal(0)
			expect(Shop.stats().opens).to.equal(2)
			Shop.stop()
			expect(Shop.isEnabled()).to.equal(false)
			expect(Shop.onRequest(player, { kind = ShopData.KIND.OPEN }, 1)).to.equal(nil)
		end)
	end)
end
