-- licence_popup.spec: THE SERVER HALVES OF THE "NO DEER LICENCE" POPUP (task 238).
--
-- KAREN, 2026-10-21, verbatim: *"if you dont have a license when you aim and what to shoot it shows
-- popup you dont have license and then you want to buy and roblox popup like they do to purchase"*.
--
-- THREE THINGS ARE ASSERTED HERE, and the CARD itself is asserted in
-- `tests/client/licence_card.spec.luau` (it is a client module and this process cannot see it):
--
--   1. **the aim question.** The `"Aim"` kind is on the whitelist, it reaches the SAME ray the
--      trigger reaches, it answers in `advice` and NOT in `refused`, and it moves nothing -- no
--      shell, no barrel, no state.
--   2. **the reach exception.** `Row.anywhere` is on exactly one row, `Shop.refuse` reads it in
--      exactly one branch, invariant I13 refuses it on anything that grants more than a licence,
--      and `Economy.purchase` really does grant the card to a man nowhere near the counter.
--   3. **the Robux switch, BOTH BRANCHES BY PARAMETER** -- which is the only way either can be
--      driven while `rowsOk`'s I12 holds every shipped `robuxProductId` at nil.
--
-- WHY THE WIRE VALUE IS PINNED FROM BOTH SIDES. `LicenceCard.ADVICE` is a literal in a client file
-- (a client cannot require `ServerScriptService.Weapon`), so the string could drift. This file
-- asserts the SERVER's end -- `Rules.REASON.LICENCE == "no-licence"` -- and the client spec asserts
-- the card's. Between them the literal is pinned at both ends of the wire.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Note: docs/research/2026-10-22-licence-popup-and-robux.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Economy = require(ServerScriptService:WaitForChild("Economy"))
local Licences = require(ReplicatedStorage:WaitForChild("Licences"))
local Match = require(ServerScriptService:WaitForChild("Match"))
local ShopData = require(ReplicatedStorage:WaitForChild("Shop"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

-- `Economy.Store` AND NOT A REQUIRE OF THE CHILD (the idiom `economy.spec` uses): the owner
-- publishes its own store module, so there is one path to it.
local Store = Economy.Store

local Rules = Weapon.Rules
local StateMachine = Weapon.StateMachine
local Validator = Weapon.Validator
local ROW = Weapons.ROWS.shotgun

-- A FULL CONTEXT FOR `Shop.refuse` WITH NOTHING IN THE WAY, so each case below changes exactly one
-- fact and the answer names that fact. Every field is explicit: nil means "nobody said", and a case
-- that relied on a nil would be a case that passes for the wrong reason.
local function clear(overrides: any?): any
	local context = {
		itemId = ShopData.ITEM.RED_STAG,
		coinsOn = true,
		hasProfile = true,
		atCounter = true,
		owned = {},
		balance = 100000,
		hunts = 100,
	}
	for key, value in pairs(overrides or {}) do
		context[key] = value
	end
	return context
end

local function waitUntil(seconds: number, predicate: () -> boolean): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if predicate() then
			return true
		end
		task.wait(0.02)
	end
	return predicate()
end

return function()
	-- ------------------------------------------------------------------ 1. THE AIM QUESTION
	describe("the aim question", function()
		it("names the same gate the fire gate names, and the client's literal is that string", function()
			-- THE WIRE VALUE. `LicenceCard.ADVICE` is this exact string in the client file; see this
			-- spec's header for why it is pinned from both ends.
			expect(Rules.REASON.LICENCE).to.equal("no-licence")
			expect(Rules.NOTICE[Rules.REASON.LICENCE]).to.equal("NO LICENCE")
		end)

		it("is on the whitelist, carries no ammo, and no other new string is", function()
			-- ACCEPTED.
			local ok, why = Validator.checkRequest("Aim", nil, ROW)
			expect(ok).to.equal(true)
			expect(why).to.equal(nil)
			-- AND WITH AN AMMO KIND IT IS A FORGERY: the kind takes no second argument.
			local withAmmo, whyAmmo = Validator.checkRequest("Aim", "Slug", ROW)
			expect(withAmmo).to.equal(false)
			expect(whyAmmo).to.equal("bad-request")
			-- THE WHITELIST DID NOT WIDEN ANYWHERE ELSE. Every reducer primitive is still
			-- unreachable from a client, which is the defect the whitelist exists to close.
			for _, primitive in ipairs({ "Fire", "Break", "Load", "Close", "Aim2", "aim", "" }) do
				local accepted = Validator.checkRequest(primitive, nil, ROW)
				expect(accepted).to.equal(false)
			end
		end)

		it("travels in `advice` and never in `refused`, so nothing clicks dry", function()
			local state = StateMachine.initial(ROW)
			-- THE AIM ANSWER: `advice` set, `refused` and `notice` nil. `CameraBoot` plays
			-- `Weapon.Sound.dry` on every arriving snapshot whose `refused` is a string, so a
			-- non-nil `refused` here would be a dry click for merely looking at a deer.
			local advised = Shotgun.snapshot(state, 0, nil, ROW.id, nil, nil, Rules.REASON.LICENCE)
			expect(advised.advice).to.equal(Rules.REASON.LICENCE)
			expect(advised.refused).to.equal(nil)
			expect(advised.notice).to.equal(nil)
			-- THE REFUSAL ANSWER, which is the one that existed before task 238: `refused` set and
			-- `advice` nil. The two facts never share a field.
			local refused = Shotgun.snapshot(state, 0, "NO LICENCE", ROW.id, nil, Rules.REASON.LICENCE)
			expect(refused.refused).to.equal(Rules.REASON.LICENCE)
			expect(refused.advice).to.equal(nil)
			-- AND AN ORDINARY SNAPSHOT CARRIES NEITHER, which is almost every snapshot in the game.
			local quiet = Shotgun.snapshot(state, 0, nil, ROW.id)
			expect(quiet.advice).to.equal(nil)
			expect(quiet.refused).to.equal(nil)
		end)

		it("asks the licence question and nothing else about the aim", function()
			-- THE NARROWNESS IS THE DECISION (the note's section 3.1): the aim question asks
			-- `Rules.unlicensed` and not `Rules.refuse`. These are the facts it does NOT consider,
			-- and each of them WOULD have been answered by `Rules.refuse`.
			local deer = { species = "reddeer" }
			expect(Rules.unlicensed(deer, nil)).to.equal(true)
			expect(Rules.unlicensed(deer, { reddeer = true })).to.equal(false)
			-- A BOAR IS FREE, so no card for the animal the whole game is about.
			expect(Rules.unlicensed({ species = "boar" }, nil)).to.equal(false)
			-- NOTHING IN THE RAY IS NOT AN OFFENCE: a miss gets no popup.
			expect(Rules.unlicensed(nil, nil)).to.equal(false)
			-- A MAN IS NOT QUARRY and has no species, so a beater in the ray gets no card either --
			-- `Rules.refuse` would have answered `BEATER` for exactly this target.
			expect(Rules.unlicensed({ beater = true }, nil)).to.equal(false)
			expect(Rules.refuse({ target = { beater = true } })).to.equal(Rules.REASON.BEATER)
		end)

		-- THE HANDLER, LIVE. `Weapon.onActionRequest` is the function `Weapon.start` connects to
		-- `ActionRequest`, and it returns its own decision per call (task 80) -- so nothing here is
		-- inferred from a counter another player could move.
		--
		-- WHAT THIS CASE CANNOT SEE, AND IT IS REPORTED RATHER THAN PAPERED OVER: the published
		-- SNAPSHOT. `StateChanged:FireClient` goes to the player's own client and this process is
		-- the server, so the observable here is `Weapon.stats().aimAdvised` -- which is incremented
		-- on exactly the publish line -- plus the snapshot-shape case above, which pins what that
		-- publish contains. `tests/client/licence_card.spec.luau` reads the other end.
		it("advises an unlicensed aim at a deer, stays silent for a licensed one, and spends nothing", function()
			local subject, before = nil, nil
			local roster = {}
			for _, player in ipairs(Players:GetPlayers()) do
				local state = Weapon.getSnapshot(player)
				local live = state ~= nil and state.equipped == true and state.barrels[state.selected] == "Live"
				table.insert(roster, player.Name .. (if live then "(armed)" else "(not armed)"))
				if subject == nil and live then
					subject, before = player, state
				end
			end
			if subject == nil then
				TestKit.note(
					"licence_popup: nobody is holding a loaded gun, so the handler was not driven; roster ["
						.. table.concat(roster, ", ")
						.. "]"
				)
				-- NOT SILENT, AND THE REPORT SAYS WHICH ARM RAN (the Reviewer's round-1 note: the
				-- fallback *"would pass with the whole `Aim` branch deleted"*). The pure rule the
				-- handler would have asked is still checked, and the note above names the arm.
				expect(Rules.unlicensed({ species = "reddeer" }, nil)).to.equal(true)
				TestKit.note("licence_popup: LIVE HANDLER NOT DRIVEN -- the fallback arm ran")
				return
			end

			local root = subject.Character and subject.Character:FindFirstChild("HumanoidRootPart")
			expect(root).to.be.ok()
			local origin = (root :: BasePart).Position + Vector3.new(0, 2, 0)
			local ray = { origin = origin, direction = Vector3.new(0, 0, -1) }

			-- THE SEAMS, PUT BACK IN THIS CASE'S OWN LAST LINES. The cast answers one fixed impact,
			-- so the aim ray cannot depend on what happens to stand in front of the player.
			local stub = Instance.new("Part")
			stub.Name = "LicencePopupSpecStubDeer"
			local hit = {
				instance = stub,
				position = origin + Vector3.new(0, 0, -30),
				normal = Vector3.new(0, 0, 1),
				distance = 30,
			}
			Weapon.setCast(function()
				return hit
			end)
			Weapon.setTargetProvider(function(instance)
				return if instance == stub then { species = "reddeer" } else nil
			end)
			Weapon.setLicenceProvider(nil) -- he holds none, which is every player today

			local start = Weapon.stats()
			local unlicensedWhy = Weapon.onActionRequest(subject, "Aim", nil, ray)
			local afterUnlicensed = Weapon.stats()
			local stateAfter = Weapon.getSnapshot(subject)

			-- ...AND THE SAME AIM WITH THE CARD IN HIS POCKET, which is what proves the advice came
			-- from the licence rule and not from the deer, the cast or the harness.
			Weapon.setLicenceProvider(function(): { [string]: boolean }
				return { reddeer = true }
			end)
			local licensedWhy = Weapon.onActionRequest(subject, "Aim", nil, ray)
			local afterLicensed = Weapon.stats()

			-- ...AND A FORGED RAY, which is refused on the trigger's own terms and publishes nothing.
			Weapon.setLicenceProvider(nil)
			local forgedWhy = Weapon.onActionRequest(subject, "Aim", nil, { origin = origin, direction = Vector3.zero })
			local afterForged = Weapon.stats()

			Weapon.setCast(nil)
			Weapon.setTargetProvider(Match.classifyTarget)
			-- PUT BACK WHAT BOTH COMPOSITION ROOTS WIRED (task 221), not nil.
			Weapon.setLicenceProvider(function(player)
				return ShopData.licencesFor(Economy.ownedOf(player.UserId))
			end)
			stub:Destroy()

			-- THE QUESTION WAS ACCEPTED AND ANSWERED. nil is "nothing went wrong".
			expect(unlicensedWhy).to.equal(nil)
			expect(afterUnlicensed.aimQuestions).to.equal(start.aimQuestions + 1)
			expect(afterUnlicensed.aimAdvised).to.equal(start.aimAdvised + 1)

			-- IT MOVED NOTHING. No shell, no barrel, no bolt, no shot -- the aim question is a READ.
			expect(stateAfter).to.be.ok()
			expect((stateAfter :: any).barrels[(stateAfter :: any).selected]).to.equal(before.barrels[before.selected])
			expect((stateAfter :: any).open).to.equal(before.open)
			expect(afterUnlicensed.shots).to.equal(start.shots)
			expect(afterUnlicensed.refused).to.equal(start.refused)

			-- THE LICENSED AIM ASKED AND WAS NOT ADVISED: one more question, no more advice.
			expect(licensedWhy).to.equal(nil)
			expect(afterLicensed.aimQuestions).to.equal(afterUnlicensed.aimQuestions + 1)
			expect(afterLicensed.aimAdvised).to.equal(afterUnlicensed.aimAdvised)

			-- THE FORGED RAY WAS REFUSED BY THE VALIDATOR AND NEVER REACHED A CAST.
			expect(forgedWhy).to.equal("not-unit")
			expect(afterForged.aimQuestions).to.equal(afterLicensed.aimQuestions)
			expect(afterForged.badRequests).to.equal(afterLicensed.badRequests + 1)

			TestKit.note(
				string.format(
					"licence_popup: LIVE HANDLER DRIVEN -- %s questions +%d advised +%d shots +%d; barrel %s -> %s",
					subject.Name,
					afterForged.aimQuestions - start.aimQuestions,
					afterForged.aimAdvised - start.aimAdvised,
					afterForged.shots - start.shots,
					tostring(before.barrels[before.selected]),
					tostring((stateAfter :: any).barrels[(stateAfter :: any).selected])
				)
			)
		end)
	end)

	-- ------------------------------------------------------- 2. BUYING AWAY FROM THE COUNTER
	describe("the deer licence may be bought away from the counter", function()
		it("skips TOO_FAR for the licence row and for no other row", function()
			-- THE LICENCE, 700 studs from the lodge: granted.
			expect(ShopData.refuse(clear({ atCounter = false }))).to.equal(nil)
			-- EVERY OTHER SELLABLE ROW, same context, same distance: refused. This is the half that
			-- says the reach rule is still the reach rule.
			local checked = 0
			for _, id in ipairs(ShopData.ORDER) do
				local row = ShopData.row(id)
				if row ~= nil and (row :: any).sale == true and id ~= ShopData.ITEM.RED_STAG then
					checked += 1
					expect(ShopData.refuse(clear({ itemId = id, atCounter = false }))).to.equal(ShopData.REASON.TOO_FAR)
				end
			end
			-- The loop really ran: a silent zero would make this case vacuous.
			expect(checked > 0).to.equal(true)
			TestKit.note(string.format("licence_popup: %d sellable rows still need the counter", checked))
		end)

		it("skips the reach question and NO other question", function()
			-- EVERY OTHER RULE IS STILL ASKED OF THE LICENCE ROW, at the counter and away from it.
			-- A reach exception that quietly became a free pass is the defect this case exists for.
			for _, atCounter in ipairs({ true, false }) do
				expect(ShopData.refuse(clear({ atCounter = atCounter, coinsOn = false }))).to.equal(
					ShopData.REASON.CLOSED
				)
				expect(ShopData.refuse(clear({ atCounter = atCounter, hasProfile = false }))).to.equal(
					ShopData.REASON.NO_PROFILE
				)
				expect(ShopData.refuse(clear({ atCounter = atCounter, owned = { [ShopData.ITEM.RED_STAG] = true } }))).to.equal(
					ShopData.REASON.OWNED
				)
				local poor, short = ShopData.refuse(clear({ atCounter = atCounter, balance = 0 }))
				expect(poor).to.equal(ShopData.REASON.POOR)
				expect(short).to.equal((ShopData.row(ShopData.ITEM.RED_STAG) :: any).price)
				expect(ShopData.refuse(clear({ atCounter = atCounter, itemId = "nonesuch" }))).to.equal(
					ShopData.REASON.UNKNOWN
				)
			end
		end)

		it("carries `anywhere` on exactly one row, and the catalogue is legal", function()
			local withIt = {}
			for _, id in ipairs(ShopData.ALL_ORDER) do
				local row = ShopData.anyRow(id) :: any
				if row.anywhere ~= nil then
					table.insert(withIt, id)
					-- IT IS true OR IT IS ABSENT. There is no third value.
					expect(row.anywhere).to.equal(true)
				end
			end
			expect(#withIt).to.equal(1)
			expect(withIt[1]).to.equal(ShopData.ITEM.RED_STAG)
			-- ...AND THE SHIPPED CATALOGUE PASSES EVERY INVARIANT, I13 included.
			local problems = ShopData.rowsOk(Weapons.ROWS, ROW.AMMO_KINDS, Licences.ROWS)
			expect(#problems).to.equal(0)
		end)

		it("refuses `anywhere` on a row that grants anything but a licence (I13)", function()
			-- THE INVARIANT, DRIVEN WITH A ROW THIS SPEC OWNS -- the only way to reach it, because
			-- the shipped catalogue is legal. `Shop.anywhereProblems` is the question in its own
			-- pure function and `rowsOk` is what asks it of every row (the `Weapon.Rules`
			-- discipline), so this drives the rule and the case below drives the catalogue.
			local function problemsFor(grants: any, extra: any?): { string }
				local row = {
					id = "spec.anywhere",
					label = "SPEC ROW",
					category = ShopData.CATEGORY.LICENCE,
					blurb = "A row this spec owns, to drive I13.",
					price = 100,
					hunts = 0,
					sale = true,
					anywhere = true,
					grants = grants,
				}
				for key, value in pairs(extra or {}) do
					(row :: any)[key] = value
				end
				return ShopData.anywhereProblems("spec.anywhere", row)
			end
			-- A LICENCE AND NOTHING ELSE IS LEGAL.
			expect(#problemsFor({ licence = "reddeer" })).to.equal(0)
			-- A WEAPON, AMMO, A HAT, A SEAT, UNLIMITED AMMO, A DRIVE GUN OR THE HUNTER'S PLACE IS
			-- NOT -- each of those is a thing that appears in his hands or on the roster.
			for _, grants in ipairs({
				{ licence = "reddeer", weapon = "rifle" },
				{ licence = "reddeer", ammo = "Slug" },
				{ licence = "reddeer", highSeat = true },
				{ licence = "reddeer", unlimitedAmmo = true },
				{ licence = "reddeer", driveGun = true },
				{ licence = "reddeer", alwaysHunter = true },
			}) do
				expect(#problemsFor(grants) > 0).to.equal(true)
			end
			-- A ROW THAT MAY BE BOUGHT ANYWHERE AND GRANTS NO LICENCE AT ALL.
			expect(#problemsFor({ weapon = "rifle" }) > 0).to.equal(true)
			-- A PACKAGE IS REFUSED EVEN WITH A LICENCE IN IT: a bundle's grants are the merge of its
			-- parts', so an exception on one would grow whenever a part did.
			expect(#problemsFor({ licence = "reddeer" }, { covers = { "a", "b" } }) > 0).to.equal(true)
			-- AND `anywhere = false` IS NOT A VALUE: absent is how a row says it needs the counter.
			expect(#problemsFor({ licence = "reddeer" }, { anywhere = false }) > 0).to.equal(true)
			-- A ROW WITHOUT THE FIELD RAISES NOTHING AT ALL, which is every row but one.
			expect(#ShopData.anywhereProblems("spec.plain", { grants = { weapon = "rifle" } })).to.equal(0)
			-- ...AND `rowsOk` REALLY ASKS IT: the shipped catalogue's one `anywhere` row passes, and
			-- the function above is reached from inside that walk rather than only from here.
			expect(#ShopData.anywhereProblems(ShopData.ITEM.RED_STAG, ShopData.row(ShopData.ITEM.RED_STAG))).to.equal(0)
		end)

		-- THE TILL ITSELF, LIVE. `Shop.refuse` above is the pure rule; this is `Economy.purchase`,
		-- the only writer of a purchase, asked exactly as `Shop.onRequest` asks it -- with
		-- `atCounter = false`, which is what a man standing in his stand measures.
		it("really grants the card to a man nowhere near the counter, and takes his coins once", function()
			local store = Store.memory({ seed = { [9238] = { coins = 2000 } } })
			Economy.stop()
			Economy.start({
				store = store,
				players = {
					GetPlayers = function()
						return { { UserId = 9238, Name = "p9238", Parent = true } }
					end,
					PlayerAdded = Instance.new("BindableEvent").Event,
					PlayerRemoving = Instance.new("BindableEvent").Event,
				},
				enabled = true,
				testGrant = false,
				-- NO RECEIPT HANDLER FROM A SPEC: `false` refuses the install whatever the
				-- environment says, so this case writes no service callback.
				marketplace = false,
			})
			expect(waitUntil(2, function()
				return Economy.balanceOf(9238) ~= nil
			end)).to.equal(true)

			local price = (ShopData.row(ShopData.ITEM.RED_STAG) :: any).price
			local receipt = Economy.purchase(9238, ShopData.ITEM.RED_STAG, { atCounter = false })
			expect(receipt.ok).to.equal(true)
			expect(receipt.refused).to.equal(nil)
			expect(receipt.price).to.equal(price)
			expect(Economy.balanceOf(9238)).to.equal(2000 - price)
			-- THE ENTITLEMENT IS WHAT THE FIRE GATE READS, through the one function that maps a
			-- bought row to a species. This is the whole point of the purchase.
			expect(ShopData.licencesFor(Economy.ownedOf(9238)).reddeer).to.equal(true)
			expect(Rules.unlicensed({ species = "reddeer" }, ShopData.licencesFor(Economy.ownedOf(9238)))).to.equal(
				false
			)

			-- ...AND A HIGH SEAT AT THE SAME SPOT IS STILL REFUSED, which is the control: the reach
			-- rule is intact and only this one row steps around it.
			local seat = Economy.purchase(9238, ShopData.ITEM.HIGH_SEAT, { atCounter = false })
			expect(seat.ok).to.equal(false)
			expect(seat.refused).to.equal(ShopData.REASON.TOO_FAR)

			-- THE DOUBLE CLICK: refused `OWNED`, and no second debit.
			local again = Economy.purchase(9238, ShopData.ITEM.RED_STAG, { atCounter = false })
			expect(again.ok).to.equal(false)
			expect(again.refused).to.equal(ShopData.REASON.OWNED)
			expect(Economy.balanceOf(9238)).to.equal(2000 - price)

			Economy.stop()
			Economy.start()
		end)
	end)

	-- ------------------------------------------------------------------ 3. THE ROBUX SWITCH
	describe("the Robux switch", function()
		it("has no product in this build, so the coin door is the only one open", function()
			-- I12, RESTATED HERE because this is the fact that makes every Robux branch below
			-- unreachable from the shipped catalogue -- and therefore the fact that makes `rows` a
			-- parameter rather than decoration.
			for _, id in ipairs(ShopData.ALL_ORDER) do
				expect((ShopData.anyRow(id) :: any).robuxProductId).to.equal(nil)
				expect(ShopData.robuxProductFor(id)).to.equal(nil)
			end
			-- AND NO RECEIPT CAN MAP TO ANYTHING.
			expect(ShopData.itemForProduct(1)).to.equal(nil)
			expect(ShopData.itemForProduct(123456789)).to.equal(nil)
		end)

		it("answers the currency off the row, both ways, by parameter", function()
			local rows = {
				coin = { id = "coin", robuxProductId = nil },
				robux = { id = "robux", robuxProductId = 777 },
			}
			expect(ShopData.robuxProductFor("coin", rows)).to.equal(nil)
			expect(ShopData.robuxProductFor("robux", rows)).to.equal(777)
			-- A MALFORMED ID IS NOT A PRODUCT, and answering nil for one is answering "coins", which
			-- is the safe half: nothing prompts Roblox for a charge off a typo.
			for _, bad in ipairs({ 0, -5, 1.5, "777", true }) do
				expect(ShopData.robuxProductFor("x", { x = { id = "x", robuxProductId = bad } })).to.equal(nil)
			end
			-- THE REVERSE LOOKUP, which is the only one `Economy.processReceipt` makes.
			expect(ShopData.itemForProduct(777, rows)).to.equal("robux")
			expect(ShopData.itemForProduct(778, rows)).to.equal(nil)
			expect(ShopData.itemForProduct("777", rows)).to.equal(nil)
			-- TWO ROWS SHARING ONE PRODUCT IS AMBIGUOUS, so it answers nothing rather than picking
			-- the one `pairs` reached first.
			local shared = {
				a = { id = "a", robuxProductId = 900 },
				b = { id = "b", robuxProductId = 900 },
			}
			expect(ShopData.itemForProduct(900, shared)).to.equal(nil)
		end)

		it("really refuses a coin BUY for a Robux row, and only for one", function()
			-- **THE GATE ITSELF, DRIVEN** (round 1, finding 1: *"the one gate that stops a player
			-- paying coins for a Robux-priced row is driven by no test"*). `Shop.Context.rows` is
			-- the seam that makes it reachable at all -- every shipped row's `robuxProductId` is nil
			-- (I12), so no context built from the catalogue can ever take this branch.
			local function row(product: any?): any
				return {
					[ShopData.ITEM.RED_STAG] = {
						id = ShopData.ITEM.RED_STAG,
						label = "DEER LICENCE",
						category = ShopData.CATEGORY.LICENCE,
						blurb = "A spec-owned copy of the row.",
						price = 750,
						hunts = 0,
						sale = true,
						anywhere = true,
						robuxProductId = product,
						grants = { licence = "reddeer" },
					},
				}
			end
			-- WITH A PRODUCT ID: the coin till refuses it, and says which rule.
			expect(ShopData.refuse(clear({ rows = row(555) }))).to.equal(ShopData.REASON.ROBUX_ONLY)
			-- THE SAME ROW WITHOUT ONE: nothing is refused. This is the pair that says the branch is
			-- the product id and not the spec's table.
			expect(ShopData.refuse(clear({ rows = row(nil) }))).to.equal(nil)
			-- ...AND IT BEATS EVERY MONEY QUESTION, which is what its position in the order is for:
			-- a man with no coins, no profile and no counter is told THIS and not `YOU NEED $750`.
			expect(ShopData.refuse(clear({ rows = row(555), balance = 0, hasProfile = false, atCounter = false }))).to.equal(
				ShopData.REASON.ROBUX_ONLY
			)
			-- ...BUT NOT THE ITEM QUESTIONS ABOVE IT: a row that is not for sale is still not for
			-- sale, whatever currency Karen priced it in.
			local notSale = row(555)
			notSale[ShopData.ITEM.RED_STAG].sale = false
			expect(ShopData.refuse(clear({ rows = notSale }))).to.equal(ShopData.REASON.NOT_SALE)
			-- AND THE SEAM CHANGES NOTHING FOR A CONTEXT THAT DOES NOT PASS ONE, which is every
			-- production caller: `Economy.purchase` builds its context without `rows`.
			expect(ShopData.refuse(clear())).to.equal(nil)
			expect(ShopData.refuse(clear({ rows = {} }))).to.equal(ShopData.REASON.UNKNOWN)
		end)

		it("shuts the coin till on a Robux row, before any money question", function()
			local rows = {
				[ShopData.ITEM.RED_STAG] = {
					id = ShopData.ITEM.RED_STAG,
					label = "DEER LICENCE",
					category = ShopData.CATEGORY.LICENCE,
					blurb = "A spec-owned copy of the row, priced in Robux.",
					price = 750,
					hunts = 0,
					sale = true,
					anywhere = true,
					robuxProductId = 555,
					grants = { licence = "reddeer" },
				},
			}
			-- `Shop.refuse` reads the CATALOGUE for the row, so the spec's table cannot reach it
			-- through `refuse`. What is asserted here is the ORDER and the branch, through the one
			-- pure function that owns both: `ROBUX_ONLY` sits after `NOT_SALE` and before every
			-- money question in `Shop.ORDER_OF_REFUSAL`.
			local order = {}
			for index, reason in ipairs(ShopData.ORDER_OF_REFUSAL) do
				order[reason] = index
			end
			expect(order[ShopData.REASON.ROBUX_ONLY]).to.equal(order[ShopData.REASON.NOT_SALE] + 1)
			expect(order[ShopData.REASON.ROBUX_ONLY] < order[ShopData.REASON.NO_PROFILE]).to.equal(true)
			expect(order[ShopData.REASON.ROBUX_ONLY] < order[ShopData.REASON.TOO_FAR]).to.equal(true)
			expect(order[ShopData.REASON.ROBUX_ONLY] < order[ShopData.REASON.POOR]).to.equal(true)
			-- IT HAS A LINE OF ITS OWN, in the register the rest of the table is written in -- what a
			-- FORGED coin request for a Robux row is told.
			expect(ShopData.noticeFor(ShopData.REASON.ROBUX_ONLY)).to.equal("THIS ONE IS SOLD FOR ROBUX")
			-- AND THE ROW A SPEC OWNS IS STILL A LEGAL ROW: I12 is about the SHAPE of a product id
			-- (a positive integer), and `rows` above carries one -- so I12 is about this build
			-- having none rather than about a Robux row being illegal.
			expect(ShopData.robuxProductFor(ShopData.ITEM.RED_STAG, rows)).to.equal(555)
			expect(#ShopData.anywhereProblems(ShopData.ITEM.RED_STAG, rows[ShopData.ITEM.RED_STAG])).to.equal(0)
		end)

		it("installs the receipt handler outside Studio and never inside it", function()
			-- PURE, so both answers are a case. A harness run is ALWAYS Studio, which is why no spec
			-- in this repository writes `MarketplaceService.ProcessReceipt`.
			expect(Economy.installsReceiptHandler(nil, true)).to.equal(false)
			expect(Economy.installsReceiptHandler(nil, false)).to.equal(true)
			expect(Economy.installsReceiptHandler(false, false)).to.equal(false)
			expect(Economy.installsReceiptHandler({}, true)).to.equal(true)
			-- THE TWO DECISIONS, AND THE ENUM IN ONE PLACE.
			expect(Economy.decisionEnum(Economy.DECISION.GRANTED)).to.equal(
				Enum.ProductPurchaseDecision.PurchaseGranted
			)
			expect(Economy.decisionEnum(Economy.DECISION.NOT_PROCESSED)).to.equal(
				Enum.ProductPurchaseDecision.NotProcessedYet
			)
			-- ANYTHING THAT IS NOT "GRANTED" IS A RETRY, which is the safe half: Roblox holds the
			-- charge and asks again rather than the player paying for nothing.
			expect(Economy.decisionEnum(nil)).to.equal(Enum.ProductPurchaseDecision.NotProcessedYet)
			expect(Economy.decisionEnum("nonsense")).to.equal(Enum.ProductPurchaseDecision.NotProcessedYet)
		end)

		-- THE GRANT, THROUGH THE DOOR A RECEIPT COMES IN BY. `Economy.processReceipt` is what
		-- `Economy.start` installs on `MarketplaceService.ProcessReceipt` in a live server; it
		-- answers a STRING, which is why this case needs no MarketplaceService at all.
		it("grants a Robux receipt once, and answers a redelivery as a success without writing", function()
			local store = Store.memory({ seed = { [9239] = { coins = 10 } } })
			Economy.stop()
			Economy.start({
				store = store,
				players = {
					GetPlayers = function()
						return { { UserId = 9239, Name = "p9239", Parent = true } }
					end,
					PlayerAdded = Instance.new("BindableEvent").Event,
					PlayerRemoving = Instance.new("BindableEvent").Event,
				},
				enabled = true,
				testGrant = false,
				marketplace = false,
			})
			expect(waitUntil(2, function()
				return Economy.balanceOf(9239) ~= nil
			end)).to.equal(true)

			-- A SPEC-OWNED PRODUCT TABLE: the row id is the REAL one (`grant` reads the catalogue for
			-- what a row GIVES), and the product id is this case's.
			local rows = { [ShopData.ITEM.RED_STAG] = { id = ShopData.ITEM.RED_STAG, robuxProductId = 4242 } }
			local receipt = { PlayerId = 9239, ProductId = 4242, PurchaseId = "p-1", CurrencySpent = 99 }

			local first = Economy.processReceipt(receipt, rows)
			expect(first).to.equal(Economy.DECISION.GRANTED)
			expect(Economy.ownedOf(9239)[ShopData.ITEM.RED_STAG]).to.equal(true)
			-- HE PAID ROBLOX, NOT US: the balance is untouched, which is the whole reason the Robux
			-- door is `grant` and not `purchase`.
			expect(Economy.balanceOf(9239)).to.equal(10)
			expect(store.calls().save).to.equal(1)
			expect(Economy.stats().grantsBySource[Economy.SOURCE.ROBUX]).to.equal(1)

			-- THE SAME RECEIPT AGAIN -- the documented retry, and the same `PurchaseId`. A SUCCESS,
			-- so Roblox stops asking, and NOTHING is written: the entitlement set IS the record, and
			-- that is why no `PurchaseId` ledger is kept (the note's section 3.5).
			local again = Economy.processReceipt(receipt, rows)
			expect(again).to.equal(Economy.DECISION.GRANTED)
			expect(store.calls().save).to.equal(1)
			expect(Economy.stats().receiptsAlready).to.equal(1)
			expect(Economy.stats().grants).to.equal(1)

			-- ...AND A RECEIPT FOR A PRODUCT NO ROW CARRIES IS LEFT UNPROCESSED, so Roblox holds the
			-- charge and redelivers it rather than the player paying for nothing.
			expect(Economy.processReceipt({ PlayerId = 9239, ProductId = 999, PurchaseId = "p-2" }, rows)).to.equal(
				Economy.DECISION.NOT_PROCESSED
			)
			-- A MALFORMED RECEIPT, AND ONE FOR A PLAYER WITH NO SESSION ON THIS SERVER.
			expect(Economy.processReceipt(nil, rows)).to.equal(Economy.DECISION.NOT_PROCESSED)
			expect(Economy.processReceipt({ ProductId = 4242 }, rows)).to.equal(Economy.DECISION.NOT_PROCESSED)
			expect(Economy.processReceipt({ PlayerId = 1, ProductId = 4242 }, rows)).to.equal(
				Economy.DECISION.NOT_PROCESSED
			)
			expect(Economy.stats().receiptsUnknown >= 2).to.equal(true)

			TestKit.note(
				string.format(
					"licence_popup: robux receipts=%d granted=%d already=%d unknown=%d notProcessed=%d",
					Economy.stats().receipts,
					Economy.stats().receiptsGranted,
					Economy.stats().receiptsAlready,
					Economy.stats().receiptsUnknown,
					Economy.stats().receiptsNotProcessed
				)
			)

			Economy.stop()
			Economy.start()
		end)
	end)
end
