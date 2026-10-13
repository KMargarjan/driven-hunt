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
-- `ShopPanel.setNear(true)` opens nothing and binds no key, so the game is task 177's game.
--
-- WHAT NO SPEC HERE CAN DO, reported rather than papered over:
--   * TAP OR CLICK A BUTTON. `GuiButton.Activated` cannot be synthesised, so `ShopPanel.press` and
--     `ShopPanel.pressRow` are the seams -- `Rail.press`'s own stated limit, and what they prove is
--     the ACTION, not the touch.
--   * OPEN THE PANEL BY WALKING UP TO THE COUNTER with the flag off. The live walk-up is the
--     screenshot and Karen's playtest.
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
	local owned = opts.owned or { [Shop.ITEM.SLUG] = true }
	local coins = if opts.coins ~= nil then opts.coins else 300
	local hunts = if opts.hunts ~= nil then opts.hunts else 30
	return {
		coinsOn = if opts.coinsOn ~= nil then opts.coinsOn else true,
		balance = coins,
		hunts = hunts,
		rows = Shop.rowsFor(owned, coins, hunts, true),
		refused = opts.refused,
		refusedNumber = opts.refusedNumber,
		bought = opts.bought,
	}
end

return function()
	describe("the shop panel", function()
		afterEach(function()
			Panel.setOpen(false)
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
			-- One per catalogue slot, plus CLOSE.
			expect(buttons).to.equal(Shop.CONFIG.MAX_ITEMS + 1)
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
			Panel.onState(statePayload({ coinsOn = false, coins = nil }))
			Panel.setOpen(true)
			expect(Panel.balanceText()).to.equal(Shop.CONFIG.TEXT.CLOSED)
			for _, line in ipairs(Panel.rowText()) do
				expect(string.find(line, Shop.CONFIG.TEXT.BUY .. "|", 1, true)).to.equal(nil)
			end
		end)

		it("draws `--` and not a nought for a player whose profile is not loaded", function()
			Panel.onState(statePayload({ coins = nil, owned = nil }))
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

		-- THE DARK PATH, AND IT IS THE STATE THIS TASK MERGES IN. With `SHOP` off the panel is never
		-- opened by the counter and no key is bound, so the game is task 177's game.
		it("opens nothing at the counter while the flag is off", function()
			expect(Shop.isOn()).to.equal(false)
			Panel.setNear(true)
			expect(Panel.isNear()).to.equal(false)
			expect(Panel.isOpen()).to.equal(false)
			expect((Hud.shopPanel() :: Frame).Visible).to.equal(false)
		end)
	end)
end
