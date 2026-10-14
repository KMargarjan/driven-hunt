-- shop_panel.spec: the shop panel, in the real client, on the real Hud (task 178).
--
-- WHAT IT PROVES AND WHAT IT CANNOT. The panel is drawn from a payload the SERVER decides, and no
-- harness run can walk a character into the lodge -- the DEV place has no lodge at all
-- (docs/design/shop.md section 10.4). So this spec does what `report_panel.spec` does: it hands the
-- panel the exact payload the wire would carry and then reads the SCREEN -- the frame's visibility,
-- the row text, the button words, the rectangle and every child's `ZIndex`. That is the one check
-- `docs/PROJECT_CONTEXT.md`'s *"a visibility audit certified a blank screen twice"* demands.
--
-- AND IT PROVES THE DARK PATH, which is the state this task MERGES in: with `SHOP` off,
-- `ShopPanel.setNear(true)` opens nothing and an injected prompt opens nothing, so the game is
-- task 177's game.
--
-- SINCE TASK 181 IT ALSO PROVES THE ONE WAY IN. Karen: *"in lobby has to be a person bot who you
-- need to click E to get access to shop"*. A spec cannot fire a real `ProximityPrompt`, so what is
-- driven is the SEAM the real prompt is wired through -- `ShopPanel.setPrompt` with a
-- `BindableEvent` standing in for the prompt, and the panel connecting to the same `Triggered`
-- signal. What that proves is the WIRING, not the keystroke; the keystroke is the screenshot and
-- Karen's playtest, and that limit is reported rather than papered over.
--
-- WHAT NO SPEC HERE CAN DO, reported rather than papered over:
--   * TAP OR CLICK A BUTTON. `GuiButton.Activated` cannot be synthesised, so `ShopPanel.press` and
--     `ShopPanel.pressRow` are the seams -- `Rail.press`'s own stated limit, and what they prove is
--     the ACTION, not the touch.
--   * OPEN THE PANEL BY WALKING UP TO THE COUNTER with the flag off. The live walk-up is the
--     screenshot and Karen's playtest.
--   * PRESS `E` AT THE SHOPKEEPER. `ProximityPrompt.Triggered` cannot be fired from a script, and
--     there is no keeper in the DEV place to stand in front of (`Lobby.ANCHORS` has one row).
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/shop.md (sections 5, 12.2)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage:WaitForChild("Shop"))

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Hud = require(scripts:WaitForChild("Hud"))

local Panel = Hud.Shop

-- THE PAYLOAD THE SERVER WOULD SEND, built by hand with `Shop.rowsFor` -- the same pure function
-- `Economy.shopStateFor` calls, so this spec cannot disagree with the server about what a row says.
local function statePayload(options)
	local opts = options or {}
	-- `noProfile` IS ITS OWN OPTION because nil cannot be passed through a table literal as "say
	-- nothing": `opts.coins == nil` is also what "the default" looks like. A player with no open
	-- profile has NO balance and NO set, and the panel must draw `--` rather than a nought.
	local owned = if opts.noProfile then nil else (opts.owned or { [Shop.ITEM.SLUG] = true })
	local coins = if opts.noProfile then nil else (if opts.coins ~= nil then opts.coins else 300)
	local hunts = if opts.hunts ~= nil then opts.hunts else 30
	return {
		coinsOn = if opts.coinsOn ~= nil then opts.coinsOn else true,
		balance = coins,
		hunts = hunts,
		-- `coinsOn` GOES INTO THE ROWS TOO (the Reviewer's round-1 note): hardcoding `true` here made
		-- the closed-shop case prove its row assertion through `balance == nil` instead of through
		-- the closed shop.
		rows = Shop.rowsFor(owned, coins, hunts, if opts.coinsOn ~= nil then opts.coinsOn else true),
		refused = opts.refused,
		refusedNumber = opts.refusedNumber,
		bought = opts.bought,
	}
end

-- A PROMPT THIS SPEC CAN FIRE. `ProximityPrompt.Triggered` cannot be raised from a script -- there
-- is no `:Trigger()` and no keypress to synthesise -- so what stands in for the keeper's prompt is a
-- `BindableEvent`'s own signal under the same field name. That is exactly why `ShopPanel.setPrompt`
-- takes anything carrying a `Triggered` signal rather than a typed `ProximityPrompt`: the panel
-- connects to the same signal, through the same line, in the spec and in the lodge.
local function fakePrompt()
	local handlers: { { fn: () -> (), live: boolean } } = {}
	return {
		-- A SYNCHRONOUS SIGNAL, AND IT HAS TO BE ONE. A `BindableEvent` was the obvious stand-in and
		-- it does not work: Roblox's signal behaviour has been DEFERRED since 2022, so the handler
		-- runs at the next resumption point and no `expect` in the same `it` can see it (measured,
		-- this task's first harness run). This fires in line, which is what a real keypress on a
		-- `ProximityPrompt` does to the panel as far as this module can tell.
		Triggered = {
			Connect = function(_self, fn: () -> ())
				local entry = { fn = fn, live = true }
				table.insert(handlers, entry)
				return {
					Disconnect = function()
						entry.live = false
					end,
				}
			end,
		},
		fire = function()
			for _, entry in ipairs(handlers) do
				if entry.live then
					entry.fn()
				end
			end
		end,
		live = function(): number
			local n = 0
			for _, entry in ipairs(handlers) do
				if entry.live then
					n += 1
				end
			end
			return n
		end,
	}
end

return function()
	describe("the shop panel", function()
		afterEach(function()
			Panel.setOpen(false)
			-- ...AND THE FLAG GOES BACK TO THE BUILD'S OWN VALUE. Two tests drive it ON by parameter,
			-- and a failing `expect` aborts an `it` where it stands -- so restoring it inside the
			-- test would leave the next one running against a lit flag it never asked for.
			Panel.setEnabled(Shop.isOn())
			Panel.setNear(false)
			Panel.setPrompt(nil)
		end)

		it("is one frame in the one ScreenGui, hidden, and no child is drawn behind it", function()
			local frame = Hud.shopPanel()
			expect(frame).to.be.ok()
			expect((frame :: Frame):IsDescendantOf(Hud.gui() :: ScreenGui)).to.equal(true)
			expect((frame :: Frame).Name).to.equal("ShopPanel")
			-- TASK 124'S MEASURED DEFECT, CLOSED BY CONSTRUCTION: with a panel opaque at ZIndex 10 and
			-- its labels at the default 1, a whole panel came out as an EMPTY BLACK RECTANGLE.
			local zIndex = (frame :: Frame).ZIndex
			expect(zIndex).to.equal(Shop.CONFIG.PANEL.Z_INDEX)
			local children = 0
			for _, child in ipairs((frame :: Frame):GetDescendants()) do
				if child:IsA("GuiObject") then
					children += 1
					expect(child.ZIndex > zIndex).to.equal(true)
				end
			end
			expect(children > 0).to.equal(true)
		end)

		-- THE FIRST PANEL IN THIS REPO THAT FITS THE PHONE SCREEN `hud_clarity.spec` MEASURES
		-- (design section 13.1): 360 px wide, against the 400 px that spec asserts against, and
		-- `Drive.CONFIG.SCORE_PANEL_WIDTH` is already 480.
		it("fits a 400 px screen and gives every button a thumb's worth of height", function()
			local frame = Hud.shopPanel() :: Frame
			expect(Shop.CONFIG.PANEL.WIDTH).to.equal(360)
			expect(frame.AbsoluteSize.X <= 400).to.equal(true)
			expect(frame.Size.X.Offset).to.equal(360)
			expect(frame.Size.Y.Offset).to.equal(Panel.heightFor(#Shop.ORDER))
			-- 48 px, over Roblox's own 44 px minimum, on every button including CLOSE.
			expect(Shop.CONFIG.BUTTON_PX).to.equal(48)
			local buttons = 0
			for _, child in ipairs(frame:GetDescendants()) do
				if child:IsA("TextButton") then
					buttons += 1
					expect(child.Size.Y.Offset >= Shop.CONFIG.BUTTON_PX).to.equal(true)
				end
			end
			-- One per catalogue ROW, plus CLOSE -- and the frame is sized from the same number, so a
			-- sixth row cannot be drawn over the footer.
			expect(buttons).to.equal(#Shop.ORDER + 1)
			expect(#Shop.ORDER <= Shop.CONFIG.MAX_ITEMS).to.equal(true)
		end)

		it("draws the server's own rows, its own words and the player's balance", function()
			Panel.onState(statePayload())
			Panel.setOpen(true)
			expect(Panel.isOpen()).to.equal(true)
			expect((Hud.shopPanel() :: Frame).Visible).to.equal(true)
			expect(Panel.titleText()).to.equal(Shop.CONFIG.TEXT.TITLE)
			expect(Panel.balanceText()).to.equal("COINS 300     HUNTS 30")

			local lines = Panel.rowText()
			-- ONE ROW PER CATALOGUE ITEM, in `Shop.ORDER`, and no more.
			expect(#lines).to.equal(#Shop.ORDER)
			-- The hat is first, cheapest, and buyable at 300 coins.
			expect(string.find(lines[1], "RED HAT", 1, true) ~= nil).to.equal(true)
			expect(string.find(lines[1], "80", 1, true) ~= nil).to.equal(true)
			expect(string.find(lines[1], Shop.CONFIG.TEXT.BUY, 1, true) ~= nil).to.equal(true)
			-- The slug is owned: the badge says so and the button is not a BUY.
			expect(string.find(lines[2], Shop.CONFIG.TEXT.OWNED_TAG, 1, true) ~= nil).to.equal(true)
			-- The open-sight rifle is SHOWN and not for sale.
			expect(string.find(lines[4], Shop.CONFIG.TEXT.SOON_TAG, 1, true) ~= nil).to.equal(true)
			-- The scoped rifle: 30 hunts is enough, 300 coins is not.
			expect(string.find(lines[5], "NO COINS", 1, true) ~= nil).to.equal(true)
			-- ...and the hint, while nothing has been refused.
			expect(Panel.messageText()).to.equal(Shop.CONFIG.TEXT.HINT)
		end)

		it("locks a rung behind the hunts a player has not walked", function()
			Panel.onState(statePayload({ owned = {}, coins = 5000, hunts = 2 }))
			Panel.setOpen(true)
			local lines = Panel.rowText()
			-- The beater's licence needs 3 hunts and he has 2.
			expect(string.find(lines[3], "3 HUNTS", 1, true) ~= nil).to.equal(true)
			-- ...and the scoped rifle needs 25.
			expect(string.find(lines[5], "25 HUNTS", 1, true) ~= nil).to.equal(true)
		end)

		it("prints one line when there is no money in this build at all", function()
			Panel.onState(statePayload({ coinsOn = false, noProfile = true }))
			Panel.setOpen(true)
			expect(Panel.balanceText()).to.equal(Shop.CONFIG.TEXT.CLOSED)
			for _, line in ipairs(Panel.rowText()) do
				expect(string.find(line, Shop.CONFIG.TEXT.BUY .. "|", 1, true)).to.equal(nil)
			end
		end)

		it("draws `--` and not a nought for a player whose profile is not loaded", function()
			Panel.onState(statePayload({ noProfile = true }))
			Panel.setOpen(true)
			-- `nil` IS NOT ZERO: `Economy.balanceOf`'s own rule, drawn.
			expect(string.find(Panel.balanceText(), "--", 1, true) ~= nil).to.equal(true)
		end)

		it("says what the server said about the last press, and then goes back to the hint", function()
			Panel.setOpen(true)
			Panel.onState(statePayload({ refused = Shop.REASON.POOR, refusedNumber = 1200 }), 100)
			expect(Panel.messageText()).to.equal("YOU NEED 1200 COINS")
			-- ...and a purchase says what it bought, by its own label.
			Panel.onState(statePayload({ bought = Shop.ITEM.HAT_RED }), 100)
			expect(Panel.messageText()).to.equal(string.format(Shop.CONFIG.TEXT.BOUGHT, "RED HAT"))
			-- THE LINE EXPIRES, which is `footerFor`'s pure rule: a message you caused by pressing a
			-- button does not stay on the screen for the rest of the session.
			expect(Panel.footerFor("WHATEVER", 100, 100 + Panel.LOOK.MESSAGE_SECONDS)).to.equal("WHATEVER")
			expect(Panel.footerFor("WHATEVER", 100, 100 + Panel.LOOK.MESSAGE_SECONDS + 0.1)).to.equal(
				Shop.CONFIG.TEXT.HINT
			)
		end)

		-- THE ACTION BEHIND A BUTTON, which is what a spec can reach (`Rail.press`'s stated limit).
		it("sends an item id for a buyable row and sends nothing for a dead one", function()
			Panel.onState(statePayload({ owned = { [Shop.ITEM.SLUG] = true }, coins = 300, hunts = 30 }))
			Panel.setOpen(true)
			local before = Panel.stats().sent
			-- Row 1 is the hat: buyable at 300 coins.
			expect(Panel.pressRow(1)).to.equal(true)
			expect(Panel.stats().sent).to.equal(before + 1)
			-- Row 2 is the slug, already owned: nothing is sent and the panel says why, out of the
			-- SAME wire row the server decided.
			expect(Panel.pressRow(2)).to.equal(false)
			expect(Panel.stats().sent).to.equal(before + 1)
			expect(Panel.messageText()).to.equal(Shop.CONFIG.TEXT.OWNED_TAG)
			-- Row 4 is the open-sight rifle: shown, never sold.
			expect(Panel.pressRow(4)).to.equal(false)
			expect(Panel.messageText()).to.equal(Shop.CONFIG.TEXT.SOON_TAG)
			-- A row the catalogue does not have is not a press at all.
			expect(Panel.pressRow(99)).to.equal(false)
			expect(Panel.press(nil)).to.equal(false)
		end)

		it("hides itself when it is closed, and takes nothing with it", function()
			Panel.onState(statePayload())
			Panel.setOpen(true)
			Panel.setOpen(false)
			expect(Panel.isOpen()).to.equal(false)
			expect((Hud.shopPanel() :: Frame).Visible).to.equal(false)
			-- THE PAYLOAD IS KEPT, so the next open has something to draw before the server answers.
			expect(Panel.lastState()).to.be.ok()
		end)

		-- ---------------------------------------------------------------- the shopkeeper (task 181)

		-- THE AUTO-OPEN IS GONE, AND ITS ABSENCE IS THE TASK. Task 178 opened this panel by itself
		-- when the player came within reach of the counter; Karen asked for a man and a key, and a
		-- panel that was already open when you got there would make her key decorative.
		it("does not open itself at the counter any more", function()
			expect((Shop.CONFIG :: any).AUTO_OPEN).to.equal(nil)
			Panel.setPrompt(nil)
			Panel.setNear(false)
			Panel.setNear(true)
			expect(Panel.isOpen()).to.equal(false)
			expect((Hud.shopPanel() :: Frame).Visible).to.equal(false)
			Panel.setNear(false)
		end)

		-- ...AND WALKING AWAY STILL CLOSES IT, which is the half of `near` that survived. The
		-- distance is `REACH_STUDS`, the same number the SERVER refuses a purchase at, so the panel
		-- is open exactly while buying is possible.
		it("closes when he walks away from the counter", function()
			-- THE FLAG DRIVEN ON BY PARAMETER, because `near` cannot be true while it is off and
			-- "walking away closes it" is a claim about the lit path (CLAUDE.md, feature flags:
			-- *"a flagged path must be reachable by parameter as well as by flag"*).
			Panel.setEnabled(true)
			Panel.setPrompt(nil)
			Panel.setNear(true)
			expect(Panel.isNear()).to.equal(true)
			Panel.setOpen(true)
			expect(Panel.isOpen()).to.equal(true)
			Panel.setNear(false)
			expect(Panel.isOpen()).to.equal(false)
			expect(Shop.CONFIG.REACH_STUDS).to.equal(14)
			-- The Hud asks the ONE pure question with that number, and nothing else does.
			local counter = Vector3.new(100, 0, 100)
			expect(Shop.withinReach(Vector3.new(113, 0, 100), counter, Shop.CONFIG.REACH_STUDS)).to.equal(true)
			expect(Shop.withinReach(Vector3.new(115, 0, 100), counter, Shop.CONFIG.REACH_STUDS)).to.equal(false)
		end)

		-- THE WIRING, DRIVEN THROUGH THE SAME SIGNAL THE REAL PROMPT FIRES.
		it("connects to one prompt at a time, and a trigger reaches the panel", function()
			local first = fakePrompt()
			local second = fakePrompt()
			Panel.setPrompt(first)
			expect(Panel.hasPrompt()).to.equal(true)
			-- THE SAME PROMPT HANDED IN AGAIN IS NOT A SECOND CONNECTION: the Hud hands it over
			-- every frame, so a connection per frame would be thousands of them in a minute.
			local connected = Panel.stats().prompts
			Panel.setPrompt(first)
			expect(Panel.stats().prompts).to.equal(connected)
			-- A REBUILT LODGE IS A NEW PROMPT, and the old connection goes with the old one.
			Panel.setPrompt(second)
			expect(Panel.stats().prompts).to.equal(connected + 1)
			local triggers = Panel.stats().triggers
			first.fire()
			expect(Panel.stats().triggers).to.equal(triggers)
			second.fire()
			expect(Panel.stats().triggers).to.equal(triggers + 1)
			Panel.setPrompt(nil)
			expect(Panel.hasPrompt()).to.equal(false)
			second.fire()
			expect(Panel.stats().triggers).to.equal(triggers + 1)
			-- ONE LIVE HANDLER AT MOST, EVER: the second prompt's connection is the only one left.
			expect(first.live()).to.equal(0)
			expect(second.live()).to.equal(0)
		end)

		-- ...AND WHAT THE TRIGGER DOES, with the flag driven ON by parameter -- which CLAUDE.md asks
		-- for in so many words: *"a flagged path must be reachable by parameter as well as by flag,
		-- or its two states cannot be tested while the flag sits at one of them"*. This is the one
		-- place in the repo that proves pressing E at the keeper OPENS THE SHOP; what it cannot
		-- prove is the keypress itself, which is the screenshot.
		it("opens the panel when the keeper's prompt fires, with the flag on", function()
			local prompt = fakePrompt()
			Panel.setEnabled(true)
			Panel.setPrompt(prompt)
			Panel.onState(statePayload())
			expect(Panel.isOpen()).to.equal(false)
			prompt.fire()
			expect(Panel.isOpen()).to.equal(true)
			expect((Hud.shopPanel() :: Frame).Visible).to.equal(true)
			-- IT OPENS AND NEVER TOGGLES: a second press is not a request to shut it. The CLOSE
			-- button and walking away are what shut it.
			prompt.fire()
			expect(Panel.isOpen()).to.equal(true)
			-- ...and walking away still does.
			Panel.setNear(true)
			Panel.setNear(false)
			expect(Panel.isOpen()).to.equal(false)
			Panel.setPrompt(nil)
			-- BACK TO THE BUILD THIS TASK MERGES IN, so no later spec in this file inherits a lit
			-- flag from this one.
			Panel.setEnabled(Shop.isOn())
			expect(Panel.isEnabled()).to.equal(false)
		end)

		-- THE DARK PATH, AND IT IS THE STATE THIS TASK MERGES IN. With `SHOP` off the panel is never
		-- opened by the counter, no prompt opens it, and the game is task 177's game.
		it("opens nothing at the counter while the flag is off", function()
			expect(Shop.isOn()).to.equal(false)
			Panel.setNear(true)
			expect(Panel.isNear()).to.equal(false)
			expect(Panel.isOpen()).to.equal(false)
			expect((Hud.shopPanel() :: Frame).Visible).to.equal(false)
			-- ...AND NEITHER DOES THE KEEPER. There is no keeper with the flag off, but an injected
			-- one must not open a panel this build does not have.
			local prompt = fakePrompt()
			Panel.setPrompt(prompt)
			prompt.fire()
			expect(Panel.isOpen()).to.equal(false)
			expect((Hud.shopPanel() :: Frame).Visible).to.equal(false)
			Panel.setPrompt(nil)
		end)
	end)
end
