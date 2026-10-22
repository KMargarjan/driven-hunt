-- licence_card.spec: THE "NO DEER LICENCE" CARD, in the real client, on the real Hud (task 238).
--
-- KAREN, 2026-10-21, verbatim: *"if you dont have a license when you aim and what to shoot it shows
-- popup you dont have license and then you want to buy and roblox popup like they do to purchase"*.
--
-- WHAT IT PROVES. The card is started by `Hud.start` in the live client, so this spec reads the
-- SCREEN -- the frame's visibility, the title, the sentence, the button's word and amount, the
-- close -- which is the one check `docs/PROJECT_CONTEXT.md`'s *"a visibility audit certified a blank
-- screen twice"* demands. It also drives the three pure rules (`shouldShow`, `expired`,
-- `buttonTextFor`) with numbers, and the OFF arm by parameter, which is the only way to reach it
-- while `LICENCE_POPUP` sits at `default = false`.
--
-- **AND IT PROVES THE CARD BLOCKS NOTHING.** `Input.isHeld()` is false while the card is open, and
-- that is the testable half of the dispatch's *"never block shooting: it is advice"*. The other half
-- of that sentence -- *"shooting a deer without it costs points"* -- is NOT what the game does, and
-- nothing in task 238 changed it: an unlicensed shot is a hard server refusal and always was
-- (`ESCALATE.md` 2026-10-22, and the note's section 1.1).
--
-- WHAT NO SPEC HERE CAN DO, reported rather than papered over:
--   * TAP OR CLICK THE BUTTON. `GuiButton.Activated` cannot be synthesised, so `LicenceCard.press`
--     is the seam -- `Rail.press` and `ShopPanel.press`'s own stated limit -- and what it proves is
--     the ACTION, not the touch.
--   * AIM AT A REAL DEER. The server is what casts the ray; this side only ever sees the `advice`
--     string, and `LicenceCard.onAdvice` is the door it comes in by.
--     `tests/server/licence_popup.spec.luau` drives the other end, including the live handler.
--   * SAY WHETHER IT LOOKS RIGHT. Rule 5's screenshot and Karen's own look answer that.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Note: docs/research/2026-10-22-licence-popup-and-robux.md
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
local Money = require(ReplicatedStorage:WaitForChild("Money"))
local Shop = require(ReplicatedStorage:WaitForChild("Shop"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Hud = require(scripts:WaitForChild("Hud"))
local WeaponSystem = require(scripts:WaitForChild("Weapon"))

local Card = Hud.LicenceCard
-- The key the card binds while it is up, by name, read off the card's own config so this file holds
-- no second copy of it.
local LicenceCard_KEY_NAME = Card.CONFIG.BUY_KEY.Name
local Panel = Hud.Shop
local Input = WeaponSystem.Input

-- A SPEC-OWNED SHOP, so the card's reads are this file's answers and no case depends on whether the
-- DEV place has a counter (it has none -- task 235: `Shop.start` answers false there).
--
-- AN EARLIER VERSION OF THIS COMMENT SAID *"the live `ShopPanel.isEnabled` would suppress every
-- card"* AND THAT WAS FALSE (round 1, finding 2): `ShopPanel.isEnabled` reads the `SHOP` FLAG, a lit
-- v1 default since task 233b, so it answers `true` in DEV. What actually keeps the card off the
-- screen there is that **no `ShopState` ever arrives** -- `Shop.start` returns false without setting
-- `started`, so `Shop.onRequest` replies to nothing -- and the card shows only once it holds a
-- `WireRow`. `row = false` below is that world.
local function fakeShop(options: any?): any
	local opts = options or {}
	local sent = {}
	local asks = 0
	-- WHETHER A `WireRow` HAS ARRIVED YET, flippable mid-case: that is what a `ShopState` landing
	-- looks like from the card's side, and the pending path needs both states in one case.
	local hidden = opts.row == false
	return {
		sent = sent,
		hideRow = function(on: boolean)
			hidden = on
		end,
		askCount = function()
			return asks
		end,
		Shop = {
			rowFor = function(id: string?)
				if hidden then
					return nil
				end
				if id ~= Shop.ITEM.RED_STAG then
					return nil
				end
				return {
					id = Shop.ITEM.RED_STAG,
					label = "DEER LICENCE",
					price = if opts.price ~= nil then opts.price else 750,
					owned = opts.owned == true,
					buyable = opts.buyable ~= false,
				}
			end,
			press = function(id: string?)
				table.insert(sent, id)
				return opts.pressFails ~= true
			end,
			isEnabled = function()
				return opts.shopOff ~= true
			end,
			ask = function()
				asks += 1
			end,
		},
	}
end

-- RESTART THE LIVE CARD WITH THIS CASE'S OWN COLLABORATORS, on the frame `Hud.build` already made.
-- `afterAll` puts the production wiring back, which is this suite's own rule: a spec that walked
-- away would leave the real card holding a stub.
--
-- `assert` AND NOT `expect`, AND THE REASON IS MEASURED (this spec's first run, 2026-10-22): TestEZ
-- 0.4.1 installs `describe`, `it` and `expect` into the environment of the function the module
-- RETURNS, not of the module chunk -- so a module-level helper like this one sees `expect` as nil
-- and every case that called it failed with *"attempt to call a nil value"*. Every `expect` in this
-- file is inside an `it`, which is where TestEZ puts it.
local function restart(options: any?): any
	local frame = Hud.licenceCard()
	assert(frame ~= nil, "Hud.licenceCard() is nil: Hud.build did not make the card's frame")
	local world = fakeShop(options)
	Card.stop()
	Card.start(frame :: Frame, {
		-- THE FLAG, BY PARAMETER. `true` unless a case asks otherwise, because the row is
		-- `default = false` and the ON arm is what every case below is about.
		enabled = if (options or {}).enabled ~= nil then (options :: any).enabled else true,
		Shop = world.Shop,
	})
	return world
end

return function()
	afterAll(function()
		-- PUT BACK WHAT `Hud.start` WIRED, not nil: the rest of the harness session, and Karen's
		-- own session after it, must run against the live seams.
		local frame = Hud.licenceCard()
		Card.stop()
		if frame ~= nil then
			Card.start(frame :: Frame, {
				Shop = {
					rowFor = Panel.rowFor,
					press = Panel.press,
					isEnabled = Panel.isEnabled,
					ask = Panel.ask,
				},
			})
		end
	end)

	describe("the card the Hud built", function()
		it("exists, is hidden, and is 300 wide in the upper third", function()
			local frame = Hud.licenceCard()
			expect(frame).to.be.ok()
			-- HIDDEN UNTIL SOMETHING ADVISES IT. A card visible at boot is the blank-screen failure
			-- in reverse.
			expect((frame :: Frame).Visible).to.equal(false)
			expect((frame :: Frame).Size.X.Offset).to.equal(Card.CONFIG.WIDTH)
			-- 300 px IS WHAT FITS THE 400 px PHONE `hud_clarity.spec` MEASURES.
			expect(Card.CONFIG.WIDTH <= 400 - 2 * 16).to.equal(true)
			-- NOT OVER THE RETICLE: the card sits in the upper third, and the reticle is at 0.5.
			expect(Card.CONFIG.Y_SCALE < 0.5).to.equal(true)
			-- WITHIN A FLOAT, NOT EQUAL TO ONE. `UDim2` stores its scales as float32, so 0.27 reads
			-- back as 0.27000001072883606 and an exact comparison fails (measured on this spec's
			-- first run). The claim is "the card is where the Hud was told to put it", and 1e-5 is
			-- a thousand times tighter than one pixel on any screen this game draws.
			expect(math.abs((frame :: Frame).Position.Y.Scale - Card.CONFIG.Y_SCALE) < 1e-5).to.equal(true)
		end)

		it("is born OFF in git, and the ON arm is reachable by parameter", function()
			-- A NEW FEEL-CRITICAL PATH IS BORN DARK (docs/design/feature-flags.md section 11 step 1).
			expect(Flags.DEFAULTS.LICENCE_POPUP.default).to.equal(false)
			expect(Flags.isOn("LICENCE_POPUP")).to.equal(false)
			expect(Card.ENABLED).to.equal(false)
			-- ...AND BOTH STATES ARE REACHABLE WHILE IT SITS THERE, which is step 2's requirement.
			restart({ enabled = true })
			expect(Card.isEnabled()).to.equal(true)
			restart({ enabled = false })
			expect(Card.isEnabled()).to.equal(false)
		end)

		it("draws the title, the rule and the close, every colour and size from Style", function()
			restart()
			local parts = Card.parts()
			expect(parts.title).to.be.ok()
			expect(parts.why).to.be.ok()
			expect(parts.buy).to.be.ok()
			expect(parts.close).to.be.ok()
			expect((parts.title :: TextLabel).Text).to.equal("NO DEER LICENCE")
			-- THE CLOSE IS NOT IN THE LIST FLOW, AND THE FRAME OF 2026-10-22 IS WHY THIS CASE EXISTS:
			-- a `UIListLayout` positions every GuiObject SIBLING, so a close button parented beside
			-- the rows was laid out as a fifth row and drew over the title in the top LEFT. The flow
			-- lives on an inner `Body`; the close sits on the card.
			local body = (parts.title :: TextLabel).Parent :: Instance
			expect(body.Name).to.equal("Body")
			expect(body:FindFirstChildOfClass("UIListLayout")).to.be.ok()
			expect((parts.close :: TextButton).Parent).never.to.equal(body)
			expect((parts.close :: TextButton).Parent).to.equal(body.Parent)
			expect((parts.close :: TextButton).Parent:FindFirstChildOfClass("UIListLayout")).to.equal(nil)
			-- ...AND IT REALLY IS IN THE TOP-RIGHT CORNER.
			expect((parts.close :: TextButton).AnchorPoint.X).to.equal(1)
			expect((parts.close :: TextButton).Position.X.Scale).to.equal(1)
			expect((parts.close :: TextButton).Position.Y.Offset).to.equal(0)
			-- WHAT THE RULE ACTUALLY IS, and it says so. The dispatch asked for "costs points";
			-- measured, the shot is REFUSED and costs nothing (this spec's header).
			local why = (parts.why :: TextLabel).Text
			expect(string.find(why, "cannot shoot") ~= nil).to.equal(true)
			expect(string.find(why, "point")).to.equal(nil)
			-- THE HINT SAYS WHAT IS TRUE, and the first version did not: it read "Esc or wait", and
			-- **Escape is not bound and cannot be** -- it belongs to the Roblox menu, which
			-- `ReportPanel.bind`'s own comment states. It now names the key that IS bound, from the
			-- same constant the binding uses, so the chip and the action cannot drift.
			local hint = Hud.Style.unspaced((parts.hint :: TextLabel).Text)
			expect(string.find(hint, LicenceCard_KEY_NAME, 1, true) ~= nil).to.equal(true)
			expect(string.find(hint, "Esc")).to.equal(nil)
			-- EVERY FACE IS ONE OF THE DESIGN SYSTEM'S TWO, so this card cannot introduce a third.
			local faces = {}
			for _, face in pairs(Hud.Style.FONT) do
				faces[tostring(face)] = true
			end
			for _, node in ipairs({ parts.title, parts.why, parts.word, parts.hint }) do
				expect(faces[tostring((node :: TextLabel).FontFace)]).to.equal(true)
			end
		end)
	end)

	describe("when it goes up", function()
		it("shows once on an unlicensed aim and not again inside the cooldown", function()
			local world = restart()
			local before = Card.stats()
			expect(Card.onAdvice("no-licence", 100)).to.equal(true)
			expect(Card.isVisible()).to.equal(true)
			expect(Card.stats().shown).to.equal(before.shown + 1)
			-- THE SECOND AIM, A SECOND LATER: nothing. "Once per aim-on, with a cooldown."
			expect(Card.onAdvice("no-licence", 101)).to.equal(false)
			expect(Card.stats().suppressedRepeat).to.equal(1)
			-- ...AND AFTER `REPEAT_SECONDS` IT MAY SAY IT AGAIN, which is the next drive's deer.
			expect(Card.onAdvice("no-licence", 100 + Card.CONFIG.REPEAT_SECONDS)).to.equal(true)
			expect(Card.stats().shown).to.equal(before.shown + 2)
			expect(#world.sent).to.equal(0)
		end)

		it("ignores every advice but its own", function()
			restart()
			for _, other in ipairs({ "off-stand", "not-at-a-beater", "drive-over", "", "no-licence-x" }) do
				expect(Card.onAdvice(other, 200)).to.equal(false)
			end
			expect(Card.onAdvice(nil, 200)).to.equal(false)
			expect(Card.isVisible()).to.equal(false)
			-- THE WIRE VALUE, pinned on this side. `tests/server/licence_popup.spec.luau` pins the
			-- server's end of the same literal (see its header).
			expect(Card.ADVICE).to.equal("no-licence")
			expect(Card.ITEM).to.equal(Shop.ITEM.RED_STAG)
			expect(Card.ITEM).to.equal("licence.reddeer")
		end)

		it("stays down for a man who already owns the card, and in a world with no shop", function()
			restart({ owned = true })
			expect(Card.onAdvice("no-licence", 300)).to.equal(false)
			expect(Card.stats().suppressedOwned).to.equal(1)
			expect(Card.isVisible()).to.equal(false)

			-- NO SHOP IN THE BUILD AT ALL (the flag off), which is what `shopOn` actually answers.
			restart({ shopOff = true })
			expect(Card.onAdvice("no-licence", 300)).to.equal(false)
			expect(Card.stats().suppressedOff).to.equal(1)
			expect(Card.isVisible()).to.equal(false)

			-- **A WORLD WHERE NO WALLET EVER ARRIVES**, which is the DEV place since task 235:
			-- `Shop.start` returns false for want of a counter WITHOUT setting `started`, so
			-- `Shop.onRequest` replies to nothing and no `ShopState` is ever sent. Round 1's
			-- finding 2: the flag does NOT answer this -- `SHOP` is a lit v1 default, so
			-- `ShopPanel.isEnabled()` says true in exactly that world. What keeps the card off the
			-- screen is that it has no `WireRow`.
			local dry = restart({ row = false })
			for index = 1, 4 do
				-- EVERY AIM, not one: a guard that only held for the first would still put the card
				-- up in a drive. Each is past `REPEAT_SECONDS`, so the cooldown is not what stops it.
				expect(Card.onAdvice("no-licence", 300 + index * 20)).to.equal(false)
			end
			expect(Card.isVisible()).to.equal(false)
			expect(Card.stats().suppressedNoWallet).to.equal(4)
			expect(Card.stats().shown).to.equal(0)
			-- ...AND IT ASKED FOR ONE, ONCE, which is the only thing it can do about it.
			expect(dry.askCount()).to.equal(1)
			-- A REPLY THAT NEVER CARRIES THE ROW CHANGES NOTHING, however long the player aims.
			Card.onShopState({ refused = Shop.REASON.CLOSED }, 385)
			expect(Card.isVisible()).to.equal(false)

			-- ...AND WITH THE FLAG OFF, for the same counter: the OFF build draws nothing and says so.
			restart({ enabled = false })
			expect(Card.onAdvice("no-licence", 300)).to.equal(false)
			expect(Card.stats().suppressedOff).to.equal(1)
			expect(Card.isVisible()).to.equal(false)
		end)

		it("leaves by itself after SHOW_SECONDS and needs no click", function()
			restart()
			expect(Card.onAdvice("no-licence", 400)).to.equal(true)
			expect(Card.isVisible()).to.equal(true)
			-- THE CLOCK, DRIVEN BY NUMBERS. `Hud`'s `RenderStepped` pass is what calls `step` live.
			Card.step(400 + Card.CONFIG.SHOW_SECONDS - 0.1)
			expect(Card.isVisible()).to.equal(true)
			Card.step(400 + Card.CONFIG.SHOW_SECONDS)
			expect(Card.isVisible()).to.equal(false)
			-- AND THE PURE RULE BEHIND IT.
			expect(Card.expired(nil, 999)).to.equal(false)
			expect(Card.expired(0, Card.CONFIG.SHOW_SECONDS)).to.equal(true)
			expect(Card.expired(0, Card.CONFIG.SHOW_SECONDS - 0.01)).to.equal(false)
		end)

		it("holds the B key only while it is up, and gives it straight back", function()
			-- IN FIRST PERSON `Camera.Cursor` LOCKS THE MOUSE TO THE CENTRE, so a `GuiButton`
			-- receives no click at all -- which is why `Hud.Rail`'s buttons each carry a key chip and
			-- why `MapUi` is `M`. The button still works wherever the cursor is free; the key works
			-- always. This case is what says the key exists and does not outlive the card.
			local function bound(): boolean
				for _, entry in pairs(ContextActionService:GetAllBoundActionInfo()) do
					for _, input in ipairs((entry :: any).inputTypes or {}) do
						if input == Card.CONFIG.BUY_KEY then
							return true
						end
					end
				end
				return false
			end
			restart()
			-- DOWN: the key is the player's.
			expect(bound()).to.equal(false)
			expect(Card.onAdvice("no-licence", 450)).to.equal(true)
			expect(bound()).to.equal(true)
			Card.hide()
			expect(bound()).to.equal(false)
			-- ...AND `stop` GIVES IT BACK TOO, whatever state the card was in: a module that stopped
			-- holding a binding would leave `B` dead for the rest of the session.
			restart()
			expect(Card.onAdvice("no-licence", 460)).to.equal(true)
			expect(bound()).to.equal(true)
			Card.stop()
			expect(bound()).to.equal(false)
			-- AND `B` IS THE CARD'S ALONE: nothing else in the game binds it.
			expect(Card.CONFIG.BUY_KEY).to.equal(Enum.KeyCode.B)
		end)

		it("blocks nothing: the trigger is as free while it is open as it was before", function()
			restart()
			local heldBefore = Input.isHeld()
			expect(Card.onAdvice("no-licence", 500)).to.equal(true)
			expect(Card.isVisible()).to.equal(true)
			-- THE TESTABLE HALF OF *"it is advice"*: no hold, so the trigger, the reload and the
			-- camera are untouched. A modal card would read `true` here.
			expect(Input.isHeld()).to.equal(heldBefore)
			expect(Input.isHeld()).to.equal(false)
			-- IT IS NOT A BUTTON ITSELF and takes no input: the frame is a Frame, so a click lands on
			-- the world behind it everywhere except the two controls.
			expect((Hud.licenceCard() :: Instance):IsA("TextButton")).to.equal(false)
			Card.hide()
			expect(Input.isHeld()).to.equal(false)
		end)
	end)

	describe("the price and the button", function()
		it("waits for the wallet, then goes up on the reply with the real price", function()
			-- THE PENDING PATH (round 1, finding 2). The first aim finds no `WireRow`, so it asks
			-- and shows NOTHING; the reply arrives inside `PENDING_SECONDS` and the card goes up
			-- then -- so the aim that asked for it still gets its card, with the number on it.
			local world = restart({ price = 750 })
			world.hideRow(true)
			expect(Card.onAdvice("no-licence", 600)).to.equal(false)
			expect(Card.isVisible()).to.equal(false)
			expect(world.askCount()).to.equal(1)
			world.hideRow(false)
			Card.onShopState({}, 600 + 0.2)
			expect(Card.isVisible()).to.equal(true)
			expect(Card.stats().shownOnWallet).to.equal(1)
			expect((Card.parts().word :: TextLabel).Text).to.equal("BUY  " .. Money.text(750))

			-- A WALLET THAT TAKES LONGER THAN `PENDING_SECONDS` IS TOO LATE: the advice is spent, so
			-- a card cannot appear minutes after the player stopped aiming.
			local late = restart({ price = 750 })
			late.hideRow(true)
			expect(Card.onAdvice("no-licence", 700)).to.equal(false)
			late.hideRow(false)
			Card.onShopState({}, 700 + Card.CONFIG.PENDING_SECONDS)
			expect(Card.isVisible()).to.equal(false)
			expect(Card.stats().shownOnWallet).to.equal(0)
		end)

		it("prints the server's own price and never a guessed one", function()
			-- THE PLACEHOLDER IS WHAT A BUTTON WITH NO ROW WOULD SAY. It is unreachable on screen
			-- now -- no row means no card at all -- and the pure function is still the one place
			-- that decides, so this is what says it never invents a number.
			expect(Card.buttonTextFor(nil)).to.equal("BUY  ...")
			expect(Card.buttonTextFor({})).to.equal("BUY  ...")
			expect(Card.buttonTextFor({ price = "750" })).to.equal("BUY  ...")

			-- WITH A PAYLOAD: the price the server sent, formatted by the ONE formatter (task 221),
			-- so the `$` exists in exactly one module.
			restart({ price = 750 })
			expect(Card.buttonTextFor({ price = 750 })).to.equal("BUY  " .. Money.text(750))
			expect(Card.onAdvice("no-licence", 700)).to.equal(true)
			expect((Card.parts().word :: TextLabel).Text).to.equal("BUY  " .. Money.text(750))
			-- AND IT IS THE CATALOGUE'S FIGURE, not a number this card chose.
			expect((Shop.row(Shop.ITEM.RED_STAG) :: any).price).to.equal(750)
		end)

		it("sends the buy through the shop's one sender, and nothing else", function()
			local world = restart()
			expect(Card.onAdvice("no-licence", 800)).to.equal(true)
			expect(Card.press()).to.equal(true)
			-- ONE ITEM ID, THROUGH `ShopPanel.press`. This card holds no remote and no money.
			expect(#world.sent).to.equal(1)
			expect(world.sent[1]).to.equal(Shop.ITEM.RED_STAG)
			expect(Card.stats().sent).to.equal(1)

			-- A SENDER THAT REFUSED IS COUNTED AND NOT RETRIED.
			local refusing = restart({ pressFails = true })
			expect(Card.press()).to.equal(false)
			expect(#refusing.sent).to.equal(1)
			expect(Card.stats().sent).to.equal(0)
			expect(Card.stats().presses).to.equal(1)
		end)

		it("prints what the server said about the purchase, in the shop's own words", function()
			restart()
			expect(Card.onAdvice("no-licence", 900)).to.equal(true)
			-- GRANTED.
			Card.onShopState({ bought = Shop.ITEM.RED_STAG })
			expect((Card.parts().word :: TextLabel).Text).to.equal("LICENCE BOUGHT")
			-- REFUSED: the SHOP's line and not one this card invented, so there is one voice for a
			-- refusal wherever it is read.
			restart()
			expect(Card.onAdvice("no-licence", 950)).to.equal(true)
			Card.onShopState({ refused = Shop.REASON.POOR, refusedNumber = 200 })
			expect((Card.parts().word :: TextLabel).Text).to.equal(Shop.noticeFor(Shop.REASON.POOR, 200))
			-- A STATE THAT ARRIVES WITH THE CARD DOWN CHANGES NOTHING.
			Card.hide()
			Card.onShopState({ refused = Shop.REASON.OWNED })
			expect(Card.isVisible()).to.equal(false)
		end)
	end)

	describe("the Robux switch, on the client", function()
		it("pays in coins today, and in Robux only when a row carries a product", function()
			-- EVERY SHIPPED ROW IS COINS, which is `rowsOk`'s I12 seen from the button's side.
			for _, id in ipairs(Shop.ALL_ORDER) do
				expect(Panel.payWith(id)).to.equal("coins")
			end
			-- BOTH BRANCHES BY PARAMETER -- the only way to reach the Robux one while I12 holds.
			local rows = {
				coin = { id = "coin" },
				robux = { id = "robux", robuxProductId = 31337 },
			}
			expect(Panel.payWith("coin", rows)).to.equal("coins")
			expect(Panel.payWith("robux", rows)).to.equal("robux")
			expect(Panel.payWith(nil, rows)).to.equal(nil)
			expect(Panel.payWith(42, rows)).to.equal(nil)
			-- NOTHING PROMPTED ROBLOX IN THIS BUILD, and the counter says so.
			expect(Panel.stats().prompted).to.equal(0)
		end)

		it("prompts Roblox for a Robux row and sends no coin BUY, driven through the real press", function()
			-- **THE ARM THAT SPENDS REAL MONEY, DRIVEN** (round 1, finding 3: *"the client Robux
			-- branch that spends real money is untested and undrivable, and the function the spec
			-- does drive is not the one the game runs"*). `ShopPanel.press` now asks
			-- `ShopPanel.payWith`, and both take the same optional `rows`; the service is injected,
			-- the seam `Economy.start`'s `world.marketplace` already is on the server.
			local prompts = {}
			local stub = {
				PromptProductPurchase = function(_self, who, productId)
					table.insert(prompts, { player = who, productId = productId })
				end,
			}
			local rows = {
				[Shop.ITEM.RED_STAG] = { id = Shop.ITEM.RED_STAG, robuxProductId = 31337 },
				[Shop.ITEM.SLUG] = { id = Shop.ITEM.SLUG },
			}
			local before = Panel.stats()
			Panel.setMarketplace(stub)
			-- THE ROBUX ROW: it prompts, with THIS player and THAT product.
			expect(Panel.press(Shop.ITEM.RED_STAG, rows)).to.equal(true)
			expect(#prompts).to.equal(1)
			expect(prompts[1].player).to.equal(player)
			expect(prompts[1].productId).to.equal(31337)
			expect(Panel.stats().prompted).to.equal(before.prompted + 1)
			-- ...AND **NO COIN BUY WENT WITH IT**, which is the half that matters: a prompt plus a
			-- `ShopRequest` would charge him twice, in two currencies.
			expect(Panel.stats().sent).to.equal(before.sent)

			-- THE COIN ROW IN THE SAME TABLE takes the other arm: no prompt, and the request goes.
			expect(Panel.press(Shop.ITEM.SLUG, rows)).to.equal(true)
			expect(#prompts).to.equal(1)
			expect(Panel.stats().sent).to.equal(before.sent + 1)
			expect(Panel.stats().prompted).to.equal(before.prompted + 1)

			-- AND THE SHIPPED CATALOGUE PROMPTS NOTHING, because every row's id is nil (I12).
			expect(Panel.press(Shop.ITEM.RED_STAG)).to.equal(true)
			expect(#prompts).to.equal(1)
			expect(Panel.stats().sent).to.equal(before.sent + 2)

			-- PUT THE REAL SERVICE BACK: a spec that walked away would leave the panel prompting
			-- into a table for the rest of the session.
			Panel.setMarketplace(nil)
			TestKit.note(
				string.format(
					"licence_card: %d catalogue rows, all priced in coins; prompted=%d",
					#Shop.ALL_ORDER,
					Panel.stats().prompted
				)
			)
		end)
	end)

	describe("the pure show rule", function()
		it("answers on the advice, the ownership and the clock, and nothing else", function()
			local R = Card.CONFIG.REPEAT_SECONDS
			-- NEVER SHOWN IS ALWAYS DUE.
			expect(Card.shouldShow("no-licence", false, nil, 0)).to.equal(true)
			expect(Card.shouldShow("no-licence", nil, nil, 0)).to.equal(true)
			-- OWNED IS NEVER DUE, whatever the clock says.
			expect(Card.shouldShow("no-licence", true, nil, 0)).to.equal(false)
			expect(Card.shouldShow("no-licence", true, 0, 1000)).to.equal(false)
			-- ANOTHER GATE IS NOT THIS CARD'S.
			expect(Card.shouldShow("off-stand", false, nil, 0)).to.equal(false)
			-- THE COOLDOWN, EITHER SIDE OF ITS EDGE.
			expect(Card.shouldShow("no-licence", false, 0, R - 0.01)).to.equal(false)
			expect(Card.shouldShow("no-licence", false, 0, R)).to.equal(true)
			-- AND ITS OWN NUMBER, passed in, so a case can drive a cooldown the game does not use.
			expect(Card.shouldShow("no-licence", false, 0, 2, 1)).to.equal(true)
			expect(Card.shouldShow("no-licence", false, 0, 0.5, 1)).to.equal(false)
		end)
	end)
end
