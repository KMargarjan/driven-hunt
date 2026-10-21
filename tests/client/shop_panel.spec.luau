-- shop_panel.spec: the shop panel, in the real client, on the real Hud (tasks 178, 181, 196).
--
-- WHAT IT PROVES AND WHAT IT CANNOT. The panel is drawn from a payload the SERVER decides, and no
-- harness run can walk a character into the lodge -- the DEV place has no lodge at all
-- (docs/design/shop.md section 10.4). So this spec does what `report_panel.spec` does: it hands the
-- panel the exact payload the wire would carry and then reads the SCREEN -- the frame's visibility,
-- the side menu's lines, the detail pane's five strings, the MODEL in the viewport, the rectangle and
-- every child's `ZIndex`. That is the one check `docs/PROJECT_CONTEXT.md`'s *"a visibility audit
-- certified a blank screen twice"* demands.
--
-- TASK 196 PART 2 IS THE DESIGNER'S PANEL. Karen handed the look over (*"give this to designer to
-- decide how it should look"*) and what came back -- the Designer's spec, 2026-10-16 -- is a palette,
-- two fonts, a row state table, a seven-state button and two layouts: WIDE (a side menu and a detail
-- column) and TALL (a strip of cards over a stacked page). The cases below read the SCREEN for all
-- of it: the tags, the button's word and amount, the mode, and the phone's three lines of blurb.
--
-- TASK 196 PART 1 IS THE TWO-COLUMN PANEL. Karen, 2026-10-15: *"menus for buying things has to be better
-- more nicer like side menu with click and then shows in right side image and explanation what is
-- that"*. So the cases below are about the BINDING: a click on the left changes the five strings and
-- the model on the right, every button state comes from the server's own `WireRow`, and a state that
-- arrives while the panel is open redraws the big button without anybody clicking again.
--
-- AND IT PROVES THE DARK PATH, which is the state this work merges in: with `SHOP` off,
-- `ShopPanel.setNear(true)` opens nothing and an injected prompt opens nothing.
--
-- WHAT NO SPEC HERE CAN DO, reported rather than papered over:
--   * TAP OR CLICK A BUTTON. `GuiButton.Activated` cannot be synthesised, so `ShopPanel.select`,
--     `ShopPanel.press` and `ShopPanel.pressSelected` are the seams -- `Rail.press`'s own stated
--     limit, and what they prove is the ACTION, not the touch.
--   * SAY WHETHER THE PICTURE LOOKS RIGHT. It can prove that the selected item's model is in the
--     viewport, that it has parts, and that the camera is aimed at it from the item's own measured
--     distance -- not that a rifle is the right way up. That is the screenshot (rule 5) and Karen's
--     own look.
--   * PRESS `E` AT THE SHOPKEEPER. `ProximityPrompt.Triggered` cannot be fired from a script, and
--     there is no keeper in the DEV place to stand in front of (`Lobby.ANCHORS` has one row).
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/shop.md (sections 5, 12.2)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage:WaitForChild("Shop"))
local Money = require(ReplicatedStorage:WaitForChild("Money"))
-- `TestKit.note` ONLY, for task 229's measured line: the owned row is judged by eye by Karen, and
-- until she has looked at it the honest substitute is a NUMBER in the report rather than a passing
-- assertion nobody can picture.
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Hud = require(scripts:WaitForChild("Hud"))

local UserInputService = game:GetService("UserInputService")

local Panel = Hud.Shop
-- THE TWO SYSTEMS THE PANEL BORROWS A SEAM FROM, required here so the mouse case can read the tags
-- back out of them: `Camera.Cursor` is the ONE writer of `UserInputService.MouseBehavior` and
-- `Weapon.Input` is the one holder of the trigger.
local CameraSystem = require(scripts:WaitForChild("Camera"))
local WeaponSystem = require(scripts:WaitForChild("Weapon"))
-- THE PICTURE'S OWN ARITHMETIC, required directly: `halfExtents` and `distanceFor` are pure, so
-- where the camera SHOULD be is a calculation this spec can redo rather than a number it copies.
local Display = require(scripts:WaitForChild("Hud"):WaitForChild("ShopDisplay"))

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
		-- `coinsOn` GOES INTO THE ROWS TOO (task 178's round-1 note): hardcoding `true` here made the
		-- closed-shop case prove its row assertion through `balance == nil` instead of through the
		-- closed shop.
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
		-- task 181's first harness run). This fires in line, which is what a real keypress on a
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

local function lineFor(id: string): string?
	for index, entry in ipairs(Shop.menuOrder(Shop.rowsFor(nil, nil, nil, true))) do
		if entry == id then
			return Panel.rowText()[index]
		end
	end
	return nil
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

		-- THE LAYOUT, ASSERTED AS ARITHMETIC AND NOT AS A SCREENSHOT (task 165's rule). The Designer's
		-- spec gives the panel two modes, so "it fits a phone" is a claim about a function: a screen
		-- size in, a mode and every rectangle out.
		it("is WIDE on a monitor and TALL on a phone, and every rectangle stays inside the panel", function()
			for _, screen in ipairs({ { 400, 800 }, { 800, 600 }, { 1280, 720 }, { 1920, 1080 } }) do
				local layout = Panel.layoutFor(screen[1], screen[2])
				local margin = Shop.CONFIG.PANEL.MARGIN
				-- INSIDE THE SCREEN, both ways, with its gutter.
				expect(layout.width <= screen[1] - 2 * margin).to.equal(true)
				expect(layout.height <= screen[2] - 2 * margin).to.equal(true)
				expect(layout.width <= Shop.CONFIG.PANEL.MAX_WIDTH).to.equal(true)
				expect(layout.height <= Shop.CONFIG.PANEL.MAX_HEIGHT).to.equal(true)
				-- THE DETAIL COLUMN AND ITS STACK, in order and inside the panel, whichever mode it
				-- is: the case, then the name, the price, the rule, the blurb, the status line and
				-- the button -- and the button's bottom is the panel's own bottom margin.
				expect(layout.detailX > 0).to.equal(true)
				expect(layout.detailX + layout.detailWidth <= layout.width).to.equal(true)
				expect(layout.caseHeight >= Shop.CONFIG.PANEL.CASE_MIN_PX).to.equal(true)
				expect(layout.eyebrowY > layout.caseY + layout.caseHeight).to.equal(true)
				expect(layout.nameY > layout.eyebrowY).to.equal(true)
				expect(layout.priceY > layout.nameY).to.equal(true)
				expect(layout.ruleY > layout.priceY).to.equal(true)
				expect(layout.blurbY > layout.ruleY).to.equal(true)
				expect(layout.statusY > layout.blurbY + layout.blurbHeight - 1).to.equal(true)
				expect(layout.buttonY > layout.statusY).to.equal(true)
				expect(layout.buttonY + layout.buttonHeight <= layout.height).to.equal(true)
				-- A TOUCH TARGET IS NEVER SMALLER THAN THE SPEC'S FLOOR, desktop included.
				expect(layout.rowHeight >= 48).to.equal(true)
				expect(layout.buttonHeight >= 56).to.equal(true)
				-- AND THE BLURB IS NEVER FEWER THAN THE THREE LINES the catalogue is written to.
				expect(layout.blurbLines >= 3).to.equal(true)
			end

			-- THE TWO MODES THE SPEC NAMES, with the exact rectangles it names them with -- the
			-- shop2 spec's section 1.2 since task 228 (`<runs-dir>/design/shop2-spec.md`).
			local desktop = Panel.layoutFor(1280, 720)
			expect(desktop.mode).to.equal("WIDE")
			expect(desktop.width).to.equal(640)
			expect(desktop.height).to.equal(576)
			expect(desktop.wellWidth).to.equal(236)
			-- 356 AND NOT THE SPEC'S DERIVED BLOCK'S 352, which is an arithmetic slip in that one
			-- line: `640 - 268 - 16` is 356, and section 1.2's own prose says *"the display case
			-- 356 x 200 at 1280 x 720 (was 364)"* -- 8 px off the case for the 8 px onto the well,
			-- which is the whole of the change.
			expect(desktop.detailWidth).to.equal(356)
			expect(desktop.detailX).to.equal(268)
			expect(desktop.rowWidth).to.equal(212)
			expect(desktop.rowHeight).to.equal(64)
			expect(desktop.wellHeight).to.equal(480)
			expect(desktop.caseHeight).to.equal(200)
			-- The side menu is a column beside the detail, and the two do not touch.
			expect(desktop.detailX >= desktop.wellX + desktop.wellWidth).to.equal(true)
			expect(desktop.wellY + desktop.wellHeight <= desktop.height).to.equal(true)

			local phone = Panel.layoutFor(400, 800)
			expect(phone.mode).to.equal("TALL")
			expect(phone.width).to.equal(376)
			expect(phone.height).to.equal(640)
			-- THE STRIP OF CARDS SITS UNDER THE HEADER AND THE PAGE UNDER IT: *"nothing is hidden
			-- behind a back button; the whole shop is one screen"*.
			expect(phone.stripY >= phone.headerHeight).to.equal(true)
			expect(phone.detailY >= phone.stripY + phone.stripHeight).to.equal(true)
			expect(phone.detailY).to.equal(172)
			expect(phone.detailHeight).to.equal(456)
			expect(phone.caseHeight).to.equal(178)
			expect(phone.stripHeight).to.equal(88)
			expect(phone.cardWidth).to.equal(108)
			-- ...AND THE EXPLANATION STILL HOLDS THREE WHOLE LINES, which is the measurement
			-- `Shop.CONFIG.PANEL.BLURB_MAX` is written against.
			expect(phone.blurbLines >= 3).to.equal(true)

			-- EVERY BUTTON ACTUALLY BUILT IS A TOUCH TARGET, including the close box.
			local frame = Hud.shopPanel() :: Frame
			local rows, buys, halves = 0, 0, 0
			for _, child in ipairs(frame:GetDescendants()) do
				if child:IsA("TextButton") then
					if child.Name == "Close" then
						expect(child.Size.Y.Offset).to.equal(Shop.CONFIG.PANEL.CLOSE_PX)
					elseif child.Name == "Buy" then
						buys += 1
					elseif child.Name == "Hunter" or child.Name == "Beater" then
						-- THE ROLE SWITCH'S TWO HALVES (task 229) AND THE ONE DOCUMENTED EXCEPTION TO
						-- THE 44 px FLOOR, which the Designer's spec 3.3 writes out: in the shop's row
						-- a half is `SWITCH_TRACK_PX - 2 * TRACK_PAD` = 28 high, and *"it sits INSIDE
						-- a 212 x 124 row that is itself a 212 x 124 target, so a miss selects the
						-- item rather than doing nothing. State that in the code comment; do not let
						-- it spread."* Counted here so it is EXPLICIT rather than filtered away: four
						-- halves exist, two in the owned row and two in the phone's detail pane, and a
						-- fifth would fail this case.
						halves += 1
						expect(child.Size.Y.Offset).to.equal(0)
						expect(child.Size.Y.Scale).to.equal(1)
					else
						rows += 1
						expect(child.Size.Y.Offset >= 48).to.equal(true)
					end
				end
			end
			expect(halves).to.equal(4)
			-- ONE ROW AND ONE CARD PER CATALOGUE ITEM -- both layouts are built once and one of them
			-- is shown -- and ONE buy button for the whole panel.
			expect(rows).to.equal(2 * #Shop.ORDER)
			expect(buys).to.equal(1)
			expect(#Shop.ORDER <= Shop.CONFIG.MAX_ITEMS).to.equal(true)
		end)

		-- ---------------------------------------------------------------- task 228: room to breathe
		--
		-- KAREN, 2026-10-21: *"in menu need more space between items now cards on left side is
		-- cluttered a bit"*. The Designer's answer is air, measured: a gap between rows, two kinds
		-- of air round a shelf head, and a well whose canvas lands on a WHOLE head at the fold.
		-- This case reads it off the BUILT instances rather than re-deriving it, so a row or a
		-- shelf that is laid out by hand somewhere else cannot pass it.
		it("spaces the list the way the shop2 spec measures it, and the fold lands on a whole head", function()
			local PANEL = Shop.CONFIG.PANEL
			local menu = (Hud.shopPanel() :: Frame):FindFirstChild("Menu") :: ScrollingFrame
			expect(menu).to.be.ok()
			local stack = menu:FindFirstChildOfClass("UIListLayout") :: UIListLayout
			-- THE ONE LINE THAT IS MOST OF THE FIX. At 0 the rows share their edges.
			expect(stack.Padding.Offset).to.equal(PANEL.ROW_GAP)
			expect(PANEL.ROW_GAP > 0).to.equal(true)
			local pad = menu:FindFirstChildOfClass("UIPadding") :: UIPadding
			expect(pad.PaddingTop.Offset).to.equal(PANEL.WELL_PAD)

			-- EVERY CHILD OF THE WELL, IN LAYOUT ORDER: a shelf head or a row, nothing else.
			local ordered: { GuiObject } = {}
			for _, child in ipairs(menu:GetChildren()) do
				if child:IsA("GuiObject") then
					table.insert(ordered, child)
				end
			end
			table.sort(ordered, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)

			-- THE CANVAS, ADDED UP THE WAY THE LAYOUT ADDS IT UP, and the FOLD it produces: the
			-- spec's section 1.5 wants FIVE WHOLE ROWS AND ONE WHOLE SHELF HEAD above the bottom of
			-- a 480 px well, with nothing cut in half -- *"a half-row at the fold reads as a bug, a
			-- whole head at the fold reads as 'there is more, and it is called LICENCES'"*.
			local viewport = Panel.layoutFor(1280, 720).wellHeight
			local y = PANEL.WELL_PAD
			local wholeRows, wholeHeads, firstCut = 0, 0, nil :: string?
			for index, child in ipairs(ordered) do
				local height = child.Size.Y.Offset
				local shelf = string.sub(child.Name, 1, 6) == "Shelf_"
				if shelf then
					local band = child:FindFirstChildOfClass("UIPadding") :: UIPadding
					-- THE HEAD'S OWN BAND IS `SHELF_PX`, and each side's padding carries only the
					-- REST of the air the spec asks to SEE, because the stack's own `ROW_GAP` is
					-- already between this frame and its neighbours.
					expect(band.PaddingTop.Offset).to.equal(if index == 1 then 0 else PANEL.SHELF_LEAD - PANEL.ROW_GAP)
					expect(band.PaddingBottom.Offset).to.equal(PANEL.SHELF_TRAIL - PANEL.ROW_GAP)
					expect(height).to.equal(band.PaddingTop.Offset + PANEL.SHELF_PX + band.PaddingBottom.Offset)
				else
					expect(height).to.equal(PANEL.ROW_PX)
				end
				if y + height <= viewport then
					if shelf then
						wholeHeads += 1
					else
						wholeRows += 1
					end
				elseif firstCut == nil then
					firstCut = child.Name
				end
				y += height + (if index < #ordered then PANEL.ROW_GAP else 0)
			end
			local canvas = y + PANEL.WELL_PAD
			-- THE NUMBER THE SPEC NAMES. If the catalogue changes, this is the one to re-check --
			-- which is exactly what this assertion is for.
			expect(canvas).to.equal(1078)
			expect(wholeRows).to.equal(5)
			-- THE FIRST TWO HEADS AND THE THIRD: WEAPONS, AMMO, and the whole of LICENCES.
			expect(wholeHeads).to.equal(3)
			expect(firstCut).to.be.ok()
			expect(string.sub(firstCut :: string, 1, 5)).to.equal("Item_")

			-- THE TWO FADE MASKS, so a row scrolling under an edge dissolves instead of being
			-- guillotined -- and NEITHER is pressable, or a press over the top row would hit a mask.
			for _, name in ipairs({ "FadeTop", "FadeBottom" }) do
				local mask = (Hud.shopPanel() :: Frame):FindFirstChild(name) :: Frame
				expect(mask).to.be.ok()
				expect(mask.Active).to.equal(false)
				expect(mask.Size.Y.Offset).to.equal(PANEL.WELL_FADE)
				expect(mask:FindFirstChildOfClass("UIGradient")).to.be.ok()
			end

			-- THE PHONE'S STRIP: 108 x 88 cards, a 10 px spacer between two cards in a category and
			-- an 18 px one with a hairline down its middle between two categories. EVERY GAP IS A
			-- FRAME, because the two gaps are different widths and a layout padding applies on both
			-- sides of a spacer.
			local strip = (Hud.shopPanel() :: Frame):FindFirstChild("Strip") :: ScrollingFrame
			local stripStack = strip:FindFirstChildOfClass("UIListLayout") :: UIListLayout
			expect(stripStack.Padding.Offset).to.equal(0)
			local cards, cardGaps, groupGaps = 0, 0, 0
			for _, child in ipairs(strip:GetChildren()) do
				if child:IsA("TextButton") then
					cards += 1
					expect(child.Size.X.Offset).to.equal(PANEL.CARD_WIDTH)
					expect(child.Size.Y.Offset).to.equal(PANEL.STRIP_PX)
				elseif child:IsA("Frame") and string.sub(child.Name, 1, 8) == "CardGap_" then
					cardGaps += 1
					expect(child.Size.X.Offset).to.equal(PANEL.CARD_GAP)
				elseif child:IsA("Frame") and string.sub(child.Name, 1, 9) == "GroupGap_" then
					groupGaps += 1
					expect(child.Size.X.Offset).to.equal(PANEL.CARD_GROUP_GAP)
					expect(child:FindFirstChild("GroupRule")).to.be.ok()
				end
			end
			expect(cards).to.equal(#Shop.ORDER)
			-- ONE GAP BETWEEN EVERY NEIGHBOURING PAIR, and one of them per category boundary.
			local groups = #Panel.headerText()
			expect(groupGaps).to.equal(groups - 1)
			expect(cardGaps).to.equal(#Shop.ORDER - groups)
		end)

		-- ---------------------------------------------------------------- the side menu

		it("draws the server's rows under the four shelves, with the price and one badge", function()
			Panel.onState(statePayload())
			Panel.setOpen(true)
			expect(Panel.isOpen()).to.equal(true)
			expect((Hud.shopPanel() :: Frame).Visible).to.equal(true)
			expect(Panel.titleText()).to.equal(Shop.CONFIG.TEXT.TITLE)
			-- THE WALLET IS TWO NUMBERS IN TWO PILLS: the captions are their own labels, so there is
			-- no sentence to format and `TEXT.BALANCE` is gone.
			expect(Panel.walletText()).to.equal("$300|30")

			-- THE SHELVES, IN THE DIRECTOR'S OWN ORDER, and FIVE drawn of six declared since task
			-- 221: CLOTHING holds only the RETIRED red hat, and `Shop.groups` drops an empty shelf
			-- rather than drawing a header with nothing under it.
			-- ...AND THEY ARE LETTER-SPACED, because Roblox `TextLabel` has no tracking property and
			-- the Designer's 10 px uppercase labels need it: `spaced("WEAPONS")` is "W E A P O N S".
			local shelves = Panel.headerText()
			expect(#shelves).to.equal(5)
			expect(shelves[1]).to.equal(Panel.spaced("WEAPONS"))
			expect(shelves[2]).to.equal(Panel.spaced("AMMO"))
			expect(shelves[3]).to.equal(Panel.spaced("LICENCES"))
			expect(shelves[4]).to.equal(Panel.spaced("ACCESS"))
			-- PACKAGES LAST, which is Karen's own *"we can ALSO make a few packages"*.
			expect(shelves[5]).to.equal(Panel.spaced("PACKAGES"))
			expect(Panel.spaced("AMMO")).to.equal("A M M O")

			local lines = Panel.rowText()
			expect(#lines).to.equal(#Shop.ORDER)
			-- EVERY ROW IS ON SCREEN and each says its name and its price or its badge.
			-- A ROW IS `NAME|PRICE|TAG`: the name, the number (the coin is a Frame beside it), and the
			-- one tag that answers *"can I buy this?"* without a click.
			-- THE PRICE CARRIES A `$` SINCE TASK 221, everywhere a player reads one.
			-- HIGH SEAT ACCESS is $600 and his wallet is $300, so the row says HOW SHORT he is --
			-- *"the affordability signal is never colour alone"*.
			expect(lineFor(Shop.ITEM.HIGH_SEAT)).to.equal(
				string.format("HIGH SEAT ACCESS|$600|%s", string.format(Shop.CONFIG.TEXT.ROW_POOR_TAG, Money.text(300)))
			)
			-- The slug is owned, so it wears the OWNED chip.
			expect(lineFor(Shop.ITEM.SLUG)).to.equal(string.format("SLUG SHELLS|$120|%s", Shop.CONFIG.TEXT.OWNED_TAG))
			-- ...AND THE DEER LICENCE IS A ROW LIKE ANY OTHER SINCE TASK 223. It was "SOON" in task
			-- 221 because there was no deer; Karen bought one on 2026-10-20, so the card went on
			-- sale in the same commit as the animal and this player is $450 short of it.
			expect(lineFor(Shop.ITEM.RED_STAG)).to.equal(
				string.format("DEER LICENCE|$750|%s", string.format(Shop.CONFIG.TEXT.ROW_POOR_TAG, Money.text(450)))
			)
			-- ...AND NOTHING IS ANNOUNCED-AND-UNSELLABLE ANY MORE. `SOON_TAG` stays for the next
			-- rung announced before it ships; `shop.spec` is what proves the mechanism still bites.
			local soon = 0
			for _, line in ipairs(lines) do
				if string.find(line, Shop.CONFIG.TEXT.SOON_TAG, 1, true) ~= nil then
					soon += 1
				end
			end
			expect(soon).to.equal(0)
			-- The scoped rifle: 30 hunts is enough, 300 coins is not, so the tag says HOW SHORT he is
			-- -- *"the affordability signal is never colour alone"*.
			expect(lineFor(Shop.ITEM.RIFLE)).to.equal(
				string.format("RIFLE, SCOPED|$1500|%s", string.format(Shop.CONFIG.TEXT.ROW_POOR_TAG, Money.text(1200)))
			)
			-- ...and the status line carries the caveat, while nothing has been refused.
			expect(Panel.statusText()).to.equal(Shop.CONFIG.TEXT.HINT)
		end)

		it("locks a rung behind the hunts a player has not walked, and shows how far he has come", function()
			Panel.onState(statePayload({ owned = {}, coins = 5000, hunts = 2 }))
			Panel.setOpen(true)
			-- THE TAG IS A PROGRESS AND NOT A GATE (the Designer's spec, 5): `2 / 3` says both how
			-- many he needs and how many he has walked.
			expect(lineFor(Shop.ITEM.BEATER_LICENCE)).to.equal(
				string.format("BEATER LICENCE|$250|%s", string.format(Shop.CONFIG.TEXT.ROW_LOCK_TAG, 2, 3))
			)
			expect(lineFor(Shop.ITEM.RIFLE)).to.equal(
				string.format("RIFLE, SCOPED|$1500|%s", string.format(Shop.CONFIG.TEXT.ROW_LOCK_TAG, 2, 25))
			)
		end)

		-- ---------------------------------------------------------------- the binding Karen asked for

		it("shows the clicked item's own page on the right: name, price, unlock and explanation", function()
			Panel.onState(statePayload({ owned = {}, coins = 300, hunts = 30 }))
			Panel.setOpen(true)
			-- SOMETHING IS ALWAYS SELECTED, so the right column is never blank on opening.
			expect(Panel.selectedId()).to.be.ok()

			Panel.select(Shop.ITEM.SLUG)
			expect(Panel.selectedId()).to.equal(Shop.ITEM.SLUG)
			local pane = Panel.detailText()
			expect(pane.name).to.equal("SLUG SHELLS")
			-- THE PRICE IS A NUMBER AND THE UNIT IS ITS OWN CAPTION, which is what lets Oswald's
			-- figures be the biggest thing on the line.
			expect(pane.price).to.equal("$120")
			-- THE EYEBROW IS THE SHELF IT CAME OFF, letter-spaced by the panel's own helper.
			expect(pane.eyebrow).to.equal(Panel.spaced("AMMO"))
			-- THE EXPLANATION IS THE SERVER'S OWN WORDS, verbatim: the panel does not write prose.
			expect(pane.blurb).to.equal(Shop.ROWS[Shop.ITEM.SLUG].blurb)
			expect(#pane.blurb > 40).to.equal(true)
			-- THE BUTTON CARRIES THE PRICE INSIDE IT: the word, a divider, a coin and the amount.
			expect(pane.button).to.equal(Shop.CONFIG.TEXT.BUY)
			expect(pane.amount).to.equal("$120")

			-- A SECOND CLICK MOVES THE WHOLE PAGE, not half of it.
			Panel.select(Shop.ITEM.RIFLE)
			local second = Panel.detailText()
			expect(second.name).to.equal("RIFLE, SCOPED")
			expect(second.price).to.equal("$1500")
			expect(second.blurb).to.equal(Shop.ROWS[Shop.ITEM.RIFLE].blurb)
			-- 300 coins against 1500, and the button says the SHORTFALL rather than "no coins":
			-- *"the number he is short is the only number that helps"*.
			expect(second.button).to.equal(string.format(Shop.CONFIG.TEXT.POOR_BUTTON, Money.text(1200)))
			expect(second.amount).to.equal("")
		end)

		it("says how many hunts are still to go on a rung he cannot reach yet, and draws the progress", function()
			Panel.onState(statePayload({ owned = {}, coins = 5000, hunts = 1 }))
			Panel.setOpen(true)
			Panel.select(Shop.ITEM.BEATER_LICENCE)
			expect(Panel.detailText().button).to.equal(string.format(Shop.CONFIG.TEXT.LOCKED_BUTTON, 2))
			-- THE LOCKED BUTTON CARRIES THE PROGRESS, which is why the item is locked drawn rather
			-- than written twice (the Designer's spec, 4): one hunt of three.
			local state = Panel.buttonStateFor(Panel.rowFor(Shop.ITEM.BEATER_LICENCE), 1, 5000)
			expect(state.kind).to.equal("locked")
			expect(state.progress).to.be.near(1 / 3, 0.001)
		end)

		-- THE FOUR STATES OF THE ONE BUTTON, each one out of the server's own `WireRow` and not out of
		-- a second opinion on this client (design hazard 10).
		it("gives the one big button its five live states, and the orange only to the pressable one", function()
			local buy = ((Hud.shopPanel() :: Frame):FindFirstChild("Detail") :: Frame):FindFirstChild(
					"Buy"
				) :: TextButton
			expect(buy).to.be.ok()

			-- BUYABLE: the word, and the price INSIDE the button (the Designer's spec, 4).
			Panel.onState(statePayload({ owned = {}, coins = 300, hunts = 30 }))
			Panel.setOpen(true)
			-- THE SLUG, because $300 buys it and HIGH SEAT ACCESS is $600: this case is about the
			-- BUYABLE state, and an item he cannot afford would be testing the other one.
			Panel.select(Shop.ITEM.SLUG)
			expect(Panel.detailText().button).to.equal(Shop.CONFIG.TEXT.BUY)
			expect(Panel.detailText().amount).to.equal("$120")
			expect(buy.BackgroundColor3).to.equal(Panel.LOOK.BLAZE)

			-- OWNED: "IN YOUR KIT", the pine fill, and no amount -- a thing you have has no price.
			Panel.onState(statePayload({ owned = { [Shop.ITEM.SLUG] = true }, coins = 300, hunts = 30 }))
			expect(Panel.detailText().button).to.equal(Shop.CONFIG.TEXT.OWNED_BUTTON)
			expect(Panel.detailText().amount).to.equal("")
			expect(buy.BackgroundColor3).to.equal(Panel.LOOK.PINE_DARK)

			-- POOR -- AND THIS IS THE RECONCILIATION, WHICH IS THE POINT OF READING THE PAYLOAD AT
			-- RENDER TIME: nobody clicked anything between these two lines. A balance that changes
			-- while the panel is open changes the button with it, so an edge-triggered state set when
			-- the row was clicked cannot go stale here. The button says the SHORTFALL, because the
			-- number he is short is the only number that helps.
			Panel.onState(statePayload({ owned = {}, coins = 10, hunts = 30 }))
			expect(Panel.detailText().button).to.equal(string.format(Shop.CONFIG.TEXT.POOR_BUTTON, Money.text(110)))
			expect(buy.BackgroundColor3).to.equal(Panel.LOOK.CLAY_DARK)

			-- LOCKED: the amber fill, the hunts still to walk, and the progress drawn along the
			-- bottom edge -- which is why the item is locked, drawn rather than written twice.
			Panel.onState(statePayload({ owned = {}, coins = 5000, hunts = 0 }))
			Panel.select(Shop.ITEM.RIFLE)
			expect(Panel.detailText().button).to.equal(string.format(Shop.CONFIG.TEXT.LOCKED_BUTTON, 25))
			expect(buy.BackgroundColor3).to.equal(Panel.LOOK.AMBER_DARK)
			local halfway = Panel.buttonStateFor(
				{ buyable = false, owned = false, sale = true, locked = true, hunts = 10, price = 1 },
				5,
				0
			)
			expect(halfway.kind).to.equal("locked")
			expect(halfway.progress).to.be.near(0.5, 0.001)

			-- NOT FOR SALE AT ALL -- the state no shipped row is in since task 196 removed the
			-- open-sighted rifle. `buttonStateFor` is pure, so this is the button's own word for a
			-- state the catalogue no longer contains.
			local soon =
				Panel.buttonStateFor({ sale = false, owned = false, buyable = false, hunts = 0, price = 1 }, 0, 0)
			expect(soon.kind).to.equal("soon")
			expect(soon.word).to.equal(Shop.CONFIG.TEXT.SOON_TAG)
		end)

		-- ---------------------------------------------------------------- the picture

		it("puts the selected item's own model in the viewport, under its own camera", function()
			Panel.onState(statePayload({ owned = {}, coins = 300, hunts = 30 }))
			Panel.setOpen(true)
			Panel.select(Shop.ITEM.RIFLE)
			local frame = Panel.viewportFrame()
			expect(frame).to.be.ok()
			-- A `ViewportFrame` RENDERS THROUGH ITS OWN CAMERA and through nothing else: a viewport
			-- with no `CurrentCamera` is the flat rectangle this spec exists to refuse.
			expect((frame :: ViewportFrame).CurrentCamera).to.be.ok()
			expect(((frame :: ViewportFrame).CurrentCamera :: Camera):IsDescendantOf(frame :: ViewportFrame)).to.equal(
				true
			)

			-- THE MODEL IS THERE, IT IS THE SELECTED ONE, AND IT HAS PARTS IN IT. Three assertions and
			-- not one, because *"a visibility audit certified a blank screen twice"*.
			expect(Panel.pictureId()).to.equal(Shop.ITEM.RIFLE)
			local model = Panel.pictureModel()
			expect(model).to.be.ok()
			expect((model :: Model):IsDescendantOf(frame :: ViewportFrame)).to.equal(true)
			local parts = 0
			for _, child in ipairs((model :: Model):GetDescendants()) do
				if child:IsA("BasePart") then
					parts += 1
				end
			end
			-- The rifle is four groups plus a drawn piece or two; one part would be a hole.
			expect(parts >= 3).to.equal(true)
			expect((model :: Model).PrimaryPart).to.be.ok()

			-- ...AND THE CAMERA IS AIMED AT IT, from the distance the item's own bounding ball asks
			-- for. `distanceFor` is pure arithmetic, so this is a measurement and not an impression.
			local camera = (frame :: ViewportFrame).CurrentCamera :: Camera
			local centre, size = Panel.pictureBall()
			local radius = size.Magnitude / 2
			local away = (camera.CFrame.Position - centre).Magnitude
			-- FAR ENOUGH BACK TO HOLD THE WHOLE THING AND NO FURTHER. The framing is the item's
			-- PROJECTED box and not its bounding ball (`ShopDisplay.halfExtents`, and the first frame
			-- that made it necessary), so a 4.4-stud rifle seen side-on is held from about five studs
			-- rather than ten: what this asserts is that the camera is outside the model and not lost
			-- in the next county.
			expect(away > size.Y).to.equal(true)
			expect(away < radius * 12).to.equal(true)
			-- ...AND THE ARITHMETIC AGREES WITH WHERE IT ACTUALLY IS, to the stud: the distance is a
			-- pure function of the box, the lens and the shape of the frame.
			local viewportBox = (frame :: ViewportFrame).AbsoluteSize
			if viewportBox.X > 1 and viewportBox.Y > 1 then
				local halfWidth, halfHeight = Display.halfExtents(size, camera.CFrame)
				local wanted = Display.distanceFor(
					halfWidth,
					halfHeight,
					viewportBox.X / viewportBox.Y,
					Display.FOV_DEG,
					Display.viewFor(Shop.ITEM.RIFLE).pad
				)
				expect(math.abs(away - wanted) < 0.05).to.equal(true)
			end
			local look = camera.CFrame.LookVector
			local toward = (centre - camera.CFrame.Position).Unit
			-- The lens points AT the thing: the two directions agree to within a degree or so.
			expect(look:Dot(toward) > 0.99).to.equal(true)

			-- ONE MODEL AT A TIME: selecting another item destroys the first rather than stacking
			-- every item the player has ever clicked inside the viewport.
			Panel.select(Shop.ITEM.BEATER_LICENCE)
			expect(Panel.pictureId()).to.equal(Shop.ITEM.BEATER_LICENCE)
			expect((model :: Model).Parent).to.equal(nil)
			local models = 0
			for _, child in ipairs((frame :: ViewportFrame):GetChildren()) do
				if child:IsA("Model") then
					models += 1
				end
			end
			expect(models).to.equal(1)
		end)

		it("has a picture for every row it sells", function()
			-- THE DIRECTOR, 2026-10-20: *"every row the shop sells gets a display model"*. Six of
			-- the ten rows drew nothing before this round, which is a declared fallback and still
			-- the wrong thing for a shop window.
			for _, id in ipairs(Shop.ORDER) do
				expect(Display.knows(id)).to.equal(true)
				local model = Display.build(id)
				expect(model).to.be.ok()
				local parts = 0
				for _, descendant in ipairs((model :: Model):GetDescendants()) do
					if descendant:IsA("BasePart") then
						parts += 1
					end
				end
				-- A MODEL WITH ONE PART IS A BLOCK, not a drawing: every existing item is at least
				-- three, and so is every new one.
				expect(parts >= 3).to.equal(true)
				expect((model :: Model).PrimaryPart).to.be.ok();
				(model :: Model):Destroy()
			end
			-- A PACKAGE DRAWS ITS OWN CONTENTS, through the same per-item builder -- so it can
			-- never show something it does not contain.
			local season = Display.build(Shop.ITEM.BUNDLE_SEASON)
			expect(season).to.be.ok()
			local drawn = 0
			for _, covered in ipairs(Shop.ROWS[Shop.ITEM.BUNDLE_SEASON].covers) do
				if Display.knows(covered) then
					drawn += 1
				end
			end
			-- Every covered row is drawable, so the board carries one model each.
			expect(drawn).to.equal(#Shop.ROWS[Shop.ITEM.BUNDLE_SEASON].covers)
			local children = 0
			for _, child in ipairs((season :: Model):GetChildren()) do
				if child:IsA("Model") then
					children += 1
				end
			end
			expect(children).to.equal(drawn);
			(season :: Model):Destroy()
			-- ...AND AN ID THE CATALOGUE DOES NOT HAVE STILL DRAWS NOTHING, which is the stated
			-- fallback and the reason the panel has words for it.
			expect(Display.knows("no.such.row")).to.equal(false)
			expect(Display.build("no.such.row")).to.equal(nil)
		end)

		-- TASK 228: the shop2 spec's section 2, counted. The LOOK is the screenshots
		-- (`.screenshots/228-after-*.png`, rule 5) and Karen's own eye; what a spec can hold is that
		-- each drawing is the one the spec names, at the part count it names, under the camera it
		-- names -- so a builder that is quietly replaced or re-pointed fails here.
		it("draws each item the shop2 spec's own model, under the spec's own camera", function()
			local function partsOf(id: string): number
				local model = Display.build(id) :: Model
				local parts = 0
				for _, descendant in ipairs(model:GetDescendants()) do
					if descendant:IsA("BasePart") then
						parts += 1
					end
				end
				model:Destroy()
				return parts
			end
			-- THE SHELL IS IDENTICAL IN BOTH LICENCES (34 parts) and the furniture is what differs:
			-- the deer's crest, stag and antlers are 36, the beater's band and two horns are 33.
			expect(partsOf(Shop.ITEM.RED_STAG)).to.equal(70)
			expect(partsOf(Shop.ITEM.BEATER_LICENCE)).to.equal(67)
			expect(partsOf(Shop.ITEM.RED_STAG) - partsOf(Shop.ITEM.BEATER_LICENCE)).to.equal(3)
			-- THE CARTON: 12 of box and print, 40 of ten shells, 9 of lid, 5 of the loose one.
			expect(partsOf(Shop.ITEM.SLUG)).to.equal(66)
			-- THE BANDOLIER: 16 loops less the one under the buckle, five parts each, plus 7.
			expect(partsOf(Shop.ITEM.UNLIMITED_AMMO)).to.equal(82)
			-- ...AND 47 INSIDE A PACKAGE, which is the ONLY place a model knows it is in one.
			local lite = Display.build(Shop.ITEM.UNLIMITED_AMMO, "lite") :: Model
			local liteParts = 0
			for _, descendant in ipairs(lite:GetDescendants()) do
				if descendant:IsA("BasePart") then
					liteParts += 1
				end
			end
			lite:Destroy()
			expect(liteParts).to.equal(47)
			expect(partsOf(Shop.ITEM.ALWAYS_HUNTER)).to.equal(25)

			-- THE HIGH SEAT IS OUR OWN OPEN STAND AND NOT THE SPEC'S CLOSED BOX BLIND (the
			-- Director's override, 2026-10-21; Karen, 2026-10-20: *"we stay what you have
			-- builded"*). Its STRUCTURE is read off `HighSeats.DIMS` -- the same numbers
			-- `HighSeats.plan` lays the real stands with -- so this sum is the seat's own list and
			-- not an envelope chosen here: four legs, one girt, two braces, a deck and five rail
			-- boards (`HighSeats.PARTS_PER_SEAT`'s own 14, less the one truss it names), then two
			-- ladder rails and seven rungs for that truss, plus the five of the brass key tag that
			-- says what the row actually sells.
			expect(partsOf(Shop.ITEM.HIGH_SEAT)).to.equal(4 + 1 + 2 + 1 + 5 + 2 + 7 + 5)

			-- THE CAMERAS. The two licences get `BOOK_VIEW` -- more pitch than a flat card so you
			-- look DOWN INTO an open booklet, and a slower, shorter rock so the print never smears.
			-- The high seat gets `TALL_VIEW`, whose 11 degrees is the whole point: at `SOLID_VIEW`'s
			-- 25 the stand was photographed from above and read as a deck.
			for _, id in ipairs({ Shop.ITEM.RED_STAG, Shop.ITEM.BEATER_LICENCE }) do
				local view = Display.viewFor(id)
				expect(view.pitchDeg).to.equal(14)
				expect(view.rockDegrees).to.equal(15)
				expect(view.rockSeconds).to.equal(10)
			end
			local seat = Display.viewFor(Shop.ITEM.HIGH_SEAT)
			expect(seat.pitchDeg).to.equal(11)
			expect(seat.rockDegrees).to.equal(nil)
			-- A SOLID STILL ORBITS, which is what the carton and the belt want.
			expect(Display.viewFor(Shop.ITEM.SLUG).rockDegrees).to.equal(nil)
		end)

		it("turns the picture while the panel is open and stands still while it is shut", function()
			Panel.onState(statePayload())
			Panel.setOpen(true)
			-- THE SLUG BOX, because its view is the plain SPINNING one: the licence CARD rocks
			-- instead (`ShopDisplay.viewFor`), and this case measures the spin against
			-- `spinDegAt(t, nil)`.
			Panel.select(Shop.ITEM.SLUG)
			local camera = (Panel.viewportFrame() :: ViewportFrame).CurrentCamera :: Camera
			Panel.step(0)
			local first = camera.CFrame.Position
			Panel.step(2)
			local second = camera.CFrame.Position
			expect((first - second).Magnitude > 0.05).to.equal(true)
			-- ...AND IT IS A TURN AROUND THE ITEM AND NOT A DRIFT AWAY FROM IT: the camera's bearing
			-- moved by exactly the pure spin, `ShopDisplay.spinDegAt(2) - spinDegAt(0)`.
			local centre = Panel.pictureBall()
			local function bearing(at: Vector3): number
				local offset = at - centre
				return math.deg(math.atan2(offset.X, offset.Z))
			end
			local turned = (bearing(second) - bearing(first) + 720) % 360
			local wanted = (Display.spinDegAt(2, nil) - Display.spinDegAt(0, nil) + 720) % 360
			expect(math.abs(turned - wanted) < 0.5).to.equal(true)
			-- THE DISTANCE IS ALLOWED TO BREATHE AS IT TURNS and that is the framing working, not a
			-- drift: the camera holds the item's PROJECTED box, so a rifle coming side-on is further
			-- away than a rifle pointing at you. What may not happen is the item swimming off: both
			-- distances are within half as much again of each other.
			local near_ = (first - centre).Magnitude
			local far = (second - centre).Magnitude
			expect(math.max(near_, far) / math.min(near_, far) < 1.5).to.equal(true)
			-- SHUT, IT COSTS NOTHING: `step` returns before it writes anything, which is every frame
			-- of a hunt.
			Panel.setOpen(false)
			local parked = camera.CFrame.Position
			Panel.step(9)
			expect(camera.CFrame.Position).to.equal(parked)
		end)

		-- A FLAT THING DOES NOT ORBIT, IT ROCKS, and that is an engine fact rather than a preference
		-- (the Designer's spec, 6.4): *"a flat card on a full orbit goes edge-on twice a revolution
		-- and disappears; a nine-second sway never does"*.
		--
		-- TWO ROCKS SINCE TASK 228, and the licences have the SLOWER one: a booklet's page is
		-- PRINTED -- seven guilloche rules, two ink bars and a signature -- and 17 degrees in nine
		-- seconds smears it. `BOOK_VIEW` is 15 in ten. `CARD_VIEW` is still 17 in nine and is what
		-- the pin on its card wears.
		it("rocks a flat thing instead of turning it all the way round", function()
			local card = Display.viewFor(Shop.ITEM.ALWAYS_HUNTER)
			expect(card.rockDegrees).to.equal(17)
			expect(card.rockSeconds).to.equal(9)
			-- A WHOLE PERIOD COMES BACK TO THE MIDDLE, and the quarter points are the extremes.
			expect(Display.spinDegAt(0, card)).to.be.near(0, 0.001)
			expect(Display.spinDegAt(9, card)).to.be.near(0, 0.001)
			expect(Display.spinDegAt(2.25, card)).to.be.near(17, 0.001)
			expect(Display.spinDegAt(6.75, card)).to.be.near(-17, 0.001)

			local book = Display.viewFor(Shop.ITEM.BEATER_LICENCE)
			expect(book.rockDegrees).to.equal(15)
			expect(book.rockSeconds).to.equal(10)
			expect(Display.spinDegAt(0, book)).to.be.near(0, 0.001)
			expect(Display.spinDegAt(10, book)).to.be.near(0, 0.001)
			expect(Display.spinDegAt(2.5, book)).to.be.near(15, 0.001)
			expect(Display.spinDegAt(7.5, book)).to.be.near(-15, 0.001)

			-- NEITHER EVER GOES EDGE-ON: the card's own yaw is 15 and its sway 17, the booklet's 13
			-- and 15, so the camera is never more than 32 degrees off either face and never at 90.
			for _, view in ipairs({ card, book }) do
				for tenth = 0, 100 do
					local yaw = view.yawDeg + Display.spinDegAt(tenth / 10, view)
					expect(math.abs(yaw) < 60).to.equal(true)
				end
			end
			-- ...AND A SOLID STILL ORBITS: a whole revolution in 18 seconds.
			local box = Display.viewFor(Shop.ITEM.SLUG)
			expect(box.rockDegrees).to.equal(nil)
			expect(Display.spinDegAt(18, box)).to.be.near(0, 0.001)
			expect(Display.spinDegAt(9, box)).to.be.near(180, 0.001)
		end)

		-- ---------------------------------------------------------------- money, words and the wire

		it("prints one line when there is no money in this build at all", function()
			Panel.onState(statePayload({ coinsOn = false, noProfile = true }))
			Panel.setOpen(true)
			expect(Panel.walletText()).to.equal("--|30")
			-- NOTHING IS BUYABLE with the money off, whichever row is selected.
			for _, id in ipairs(Shop.ORDER) do
				Panel.select(id)
				expect(Panel.detailText().button).never.to.equal(Shop.CONFIG.TEXT.BUY)
			end
		end)

		it("draws `--` and not a nought for a player whose profile is not loaded", function()
			Panel.onState(statePayload({ noProfile = true }))
			Panel.setOpen(true)
			-- `nil` IS NOT ZERO: `Economy.balanceOf`'s own rule, drawn.
			expect(string.find(Panel.walletText(), "--", 1, true) ~= nil).to.equal(true)
		end)

		it("says what the server said about the last press, and then goes back to the hint", function()
			Panel.setOpen(true)
			Panel.onState(statePayload({ refused = Shop.REASON.POOR, refusedNumber = 1200 }), 100)
			expect(Panel.statusText()).to.equal("YOU NEED $1200")
			-- ...and a purchase says what it bought, by its own label.
			Panel.onState(statePayload({ bought = Shop.ITEM.HIGH_SEAT }), 100)
			expect(Panel.statusText()).to.equal(string.format(Shop.CONFIG.TEXT.BOUGHT, "HIGH SEAT ACCESS"))
			-- THE ONE MESSAGE SLOT TAKES ITS COLOUR FROM WHAT IT IS SAYING (the Designer's spec, 4):
			-- green for the receipt, clay for the refusal, faint for the caveat.
			expect(Panel.statusColorFor("BOUGHT: X", "bought", 100, 100)).to.equal(Panel.LOOK.PINE_TEXT)
			expect(Panel.statusColorFor("NO", "refused", 100, 100)).to.equal(Panel.LOOK.CLAY)
			-- THE LINE EXPIRES: a message you caused by pressing a button does not stay on the screen
			-- for the rest of the session.
			expect(Panel.statusFor("WHATEVER", 100, 100 + Panel.LOOK.MESSAGE_SECONDS)).to.equal("WHATEVER")
			expect(Panel.statusFor("WHATEVER", 100, 100 + Panel.LOOK.MESSAGE_SECONDS + 0.1)).to.equal(
				Shop.CONFIG.TEXT.HINT
			)
			expect(Panel.statusColorFor("WHATEVER", "bought", 100, 100 + Panel.LOOK.MESSAGE_SECONDS + 0.1)).to.equal(
				Panel.LOOK.FAINT
			)
		end)

		-- THE ACTION BEHIND THE BUTTON, which is what a spec can reach (`Rail.press`'s stated limit).
		it("sends an item id for the selected row and sends nothing for a dead one", function()
			Panel.onState(statePayload({ owned = { [Shop.ITEM.SLUG] = true }, coins = 300, hunts = 30 }))
			Panel.setOpen(true)
			local before = Panel.stats().sent
			-- THE BEATER LICENCE: $250 of his $300, and 30 hunts past its gate of 3.
			Panel.select(Shop.ITEM.BEATER_LICENCE)
			expect(Panel.pressSelected()).to.equal(true)
			expect(Panel.stats().sent).to.equal(before + 1)
			-- The slug is already owned: nothing is sent and the panel says why, out of the SAME wire
			-- row the server decided.
			Panel.select(Shop.ITEM.SLUG)
			expect(Panel.pressSelected()).to.equal(false)
			expect(Panel.stats().sent).to.equal(before + 1)
			expect(Panel.statusText()).to.equal(Shop.CONFIG.TEXT.OWNED_BUTTON)
			-- The scoped rifle is locked and unaffordable: the press is refused out of the SAME wire
			-- row, with no round trip.
			Panel.select(Shop.ITEM.RIFLE)
			expect(Panel.pressSelected()).to.equal(false)
			expect(Panel.stats().sent).to.equal(before + 1)
			-- An id the catalogue does not have is not a press at all.
			expect(Panel.press(nil)).to.equal(false)
		end)

		it("hides itself when it is closed, and takes nothing with it", function()
			Panel.onState(statePayload())
			Panel.setOpen(true)
			Panel.setOpen(false)
			expect(Panel.isOpen()).to.equal(false)
			expect((Hud.shopPanel() :: Frame).Visible).to.equal(false)
			-- THE PAYLOAD AND THE SELECTION ARE KEPT, so the next open has something to draw before
			-- the server answers.
			expect(Panel.lastState()).to.be.ok()
			expect(Panel.selectedId()).to.be.ok()
		end)

		-- ---------------------------------------------------------------- the mouse (task 196 part 3a)

		-- KAREN, 2026-10-16 ~19:00: *"once I close shop I can't move mouse seems disabled need to go
		-- back to turn again fix that"*.
		--
		-- THE CAMERA TURNS ON A MOUSE DELTA, AND IT ONLY GETS ONE WHILE THE MOUSE IS LOCKED TO THE
		-- CENTRE. The shop frees the cursor so a thumb or a pointer can press BUY, through
		-- `Cursor.requestFree("shop")` -- the one tagged door, `Camera.Cursor` being the ONLY writer
		-- of `UserInputService.MouseBehavior` in this repo. Every way OUT of the shop therefore has
		-- to give that tag back, or the mouse stays free and the camera never turns again.
		--
		-- THIS CASE DRIVES EVERY WAY OUT THERE IS and asserts the two seams the panel borrows are
		-- both handed back -- and then asserts the SYMPTOM itself: one camera frame later the engine
		-- is back in `LockCenter`.
		it("gives the mouse and the trigger back on every way out of the shop", function()
			local Cursor = (CameraSystem :: any).Cursor
			local WeaponInput = (WeaponSystem :: any).Input
			expect(Cursor).to.be.ok()
			expect(WeaponInput).to.be.ok()

			local function holdsShop(): (boolean, boolean)
				local mouse = false
				for _, tag in ipairs(Cursor.stats().tags) do
					if tag == "shop" then
						mouse = true
					end
				end
				local trigger = false
				for _, tag in ipairs(WeaponInput.holdTags()) do
					if tag == "shop" then
						trigger = true
					end
				end
				return mouse, trigger
			end

			local prompt = fakePrompt()
			Panel.setEnabled(true)
			Panel.setPrompt(prompt)
			Panel.onState(statePayload())

			-- 1. THE X IN THE CORNER. `setOpen(false)` is what that button's `Activated` calls.
			prompt.fire()
			expect(Panel.isOpen()).to.equal(true)
			local mouse, trigger = holdsShop()
			expect(mouse).to.equal(true)
			expect(trigger).to.equal(true)
			Panel.setOpen(false)
			mouse, trigger = holdsShop()
			expect(mouse).to.equal(false)
			expect(trigger).to.equal(false)
			-- ...AND THE ENGINE IS BACK IN LOCKCENTER after the camera's next frame, which is the
			-- thing Karen actually sees: `Cursor.apply` is the one writer and the owner calls it
			-- every frame.
			Cursor.apply()
			expect(UserInputService.MouseBehavior).to.equal(Enum.MouseBehavior.LockCenter)

			-- 2. WALKING AWAY FROM THE COUNTER.
			prompt.fire()
			expect(Panel.isOpen()).to.equal(true)
			Panel.setNear(true)
			Panel.setNear(false)
			expect(Panel.isOpen()).to.equal(false)
			mouse, trigger = holdsShop()
			expect(mouse).to.equal(false)
			expect(trigger).to.equal(false)
			Cursor.apply()
			expect(UserInputService.MouseBehavior).to.equal(Enum.MouseBehavior.LockCenter)

			-- 3. THE FLAG GOING OUT UNDER AN OPEN PANEL -- the third door into `setOpen(false)`, and
			-- the one no player can press but a build switch can.
			prompt.fire()
			expect(Panel.isOpen()).to.equal(true)
			Panel.setEnabled(false)
			expect(Panel.isOpen()).to.equal(false)
			mouse, trigger = holdsShop()
			expect(mouse).to.equal(false)
			expect(trigger).to.equal(false)
			Cursor.apply()
			expect(UserInputService.MouseBehavior).to.equal(Enum.MouseBehavior.LockCenter)

			Panel.setPrompt(nil)
			Panel.setEnabled(Shop.isOn())
		end)

		-- ---------------------------------------------------------------- the shopkeeper (task 181)

		-- THE AUTO-OPEN IS GONE, AND ITS ABSENCE IS THAT TASK. Task 178 opened this panel by itself
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
			-- ...AND THE PICTURE IS ALREADY THERE, because something is always selected: Karen's
			-- *"image and explanation"* is what the first frame after `E` shows.
			expect(Panel.pictureModel()).to.be.ok()
			expect(Panel.detailText().name).never.to.equal("")
			-- IT OPENS AND NEVER TOGGLES: a second press is not a request to shut it. The CLOSE
			-- button and walking away are what shut it.
			prompt.fire()
			expect(Panel.isOpen()).to.equal(true)
			-- ...and walking away still does.
			Panel.setNear(true)
			Panel.setNear(false)
			expect(Panel.isOpen()).to.equal(false)
			Panel.setPrompt(nil)
			-- BACK TO THE BUILD THIS MERGES IN, so no later spec in this file inherits a lit flag.
			Panel.setEnabled(Shop.isOn())
			expect(Panel.isEnabled()).to.equal(false)
		end)

		-- THE DARK PATH, AND IT IS THE STATE THIS WORK MERGES IN. With `SHOP` off the panel is never
		-- opened by the counter and no prompt opens it.
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

	describe("the phone's right-edge rail", function()
		-- TASK 196 PART 3f. On a 400-wide screen the panel is the whole screen and the Hud's MAP /
		-- REPORT column sat ON TOP of it. The rail is the Hud's; the shop only answers the question.
		it("asks the Hud to hide the rail only while it is open AND the screen is narrow", function()
			Panel.setOpen(false)
			expect(Panel.hidesRail(400)).to.equal(false)
			expect(Panel.hidesRail(1920)).to.equal(false)
			Panel.setOpen(true)
			-- A PHONE: the panel fills it.
			expect(Panel.hidesRail(400)).to.equal(true)
			expect(Panel.hidesRail(Shop.CONFIG.PANEL.WIDE_AT - 1)).to.equal(true)
			-- ...AND A DESKTOP KEEPS ITS RAIL, because the panel does not reach the edge there.
			expect(Panel.hidesRail(Shop.CONFIG.PANEL.WIDE_AT)).to.equal(false)
			expect(Panel.hidesRail(1920)).to.equal(false)
			Panel.setOpen(false)
			expect(Panel.hidesRail(400)).to.equal(false)

			-- --------------------------------------------------- THE ROLE SWITCH (task 229)
			--
			-- KAREN, 2026-10-21: *"we also need to have posibility to choose once you have a card always
			-- hunter maybe sometimes I want to be a beater we need to find a way to do that"*.
			--
			-- THE SECONDARY SURFACE -- *"the minute you buy the thing is the minute you must learn it is
			-- a choice"*. The PRIMARY is the truck-pad dialog and its cases are in `pad_panel.spec`.
			-- Design: docs/design/role-switch.md (sections 9, 10.8, 15.5)
			it("puts the switch on exactly one surface, which is what `never both` means", function()
				-- ONE RULE AS A FUNCTION RATHER THAN AS A CONVENTION: a function can be asserted over
				-- every combination, and a convention cannot.
				local HUNTER = Panel.ROLE.HUNTER
				local ALWAYS = Shop.ITEM.ALWAYS_HUNTER
				expect(Panel.switchSurfaceFor("WIDE", HUNTER, ALWAYS)).to.equal("row")
				-- IN WIDE THE ROW IS THERE WHATEVER IS SELECTED: the switch is ON the item's own row.
				expect(Panel.switchSurfaceFor("WIDE", HUNTER, Shop.ITEM.SHOTGUN)).to.equal("row")
				expect(Panel.switchSurfaceFor("WIDE", HUNTER, nil)).to.equal("row")
				-- IN TALL THE 108 px CARD HAS NO ROOM, so it rides the SELECTED item's detail pane.
				expect(Panel.switchSurfaceFor("TALL", HUNTER, ALWAYS)).to.equal("detail")
				expect(Panel.switchSurfaceFor("TALL", HUNTER, Shop.ITEM.SHOTGUN)).to.equal("none")
				expect(Panel.switchSurfaceFor("TALL", HUNTER, nil)).to.equal("none")
				-- AND NOWHERE AT ALL FOR A MAN WHO OWNS NOTHING -- absent, not greyed, not locked.
				for _, mode in ipairs({ "WIDE", "TALL" }) do
					expect(Panel.switchSurfaceFor(mode, nil, ALWAYS)).to.equal("none")
					expect(Panel.switchSurfaceFor(mode, "shooter", ALWAYS)).to.equal("none")
				end
			end)

			it("builds the owned row 124 tall and moves nothing above it", function()
				local PANEL = Shop.CONFIG.PANEL
				local was = Panel.layoutFor(1280, 720)
				local now = Panel.layoutFor(1280, 720, "row")
				expect(now.switchRowHeight).to.equal(PANEL.ROW_SWITCH_PX)
				expect(PANEL.ROW_SWITCH_PX).to.equal(124)
				expect(was.switchRowHeight).to.equal(PANEL.ROW_PX)
				-- NOTHING ABOVE IT MOVES, and in WIDE nothing at all does: the well is a `UIListLayout`,
				-- so one row growing pushes only what is BELOW it, and the detail column is untouched.
				for _, key in ipairs({
					"width",
					"height",
					"wellY",
					"wellWidth",
					"wellHeight",
					"rowWidth",
					"detailX",
					"detailY",
					"caseHeight",
					"statusY",
					"buttonY",
				}) do
					expect((now :: any)[key]).to.equal((was :: any)[key])
				end
				-- `surface` nil IS TODAY'S ANSWER, which is what makes `Hud.build`'s `panelSize` and every
				-- existing case unchanged by construction.
				expect(was.switchSurface).to.equal("none")
				expect(was.switchBlock).to.equal(0)
				-- THE TRACK IS THE ROW LESS ITS TWO INSETS: 186 at 1280 x 720, the Designer's own number.
				expect(now.switchTrackWidth).to.equal(now.rowWidth - PANEL.SWITCH_LEFT - PANEL.SWITCH_RIGHT)
				expect(now.switchTrackWidth).to.equal(186)
				-- ...AND THE TWO HALVES PLUS ONE GAP EXACTLY FILL THE PADDED INTERIOR (the FORMULA, not
				-- the Designer's drawing, which forgot the 3 px between them).
				local ROLE = PANEL.ROLE_SWITCH
				expect(2 * now.switchHalfWidth + ROLE.TRACK_GAP + 2 * ROLE.TRACK_PAD).to.equal(now.switchTrackWidth)
				TestKit.note(
					string.format(
						"task229 shop row: %d -> %d px at 1280x720, track %dx%d, halves %.1fx%d, name y=%d,"
							.. " eyebrow y=%d, track y=%d, caption y=%d; phone detail block %d px, blurb %d line(s)",
						was.switchRowHeight,
						now.switchRowHeight,
						now.switchTrackWidth,
						PANEL.SWITCH_TRACK_PX,
						now.switchHalfWidth,
						PANEL.SWITCH_TRACK_PX - 2 * ROLE.TRACK_PAD,
						PANEL.SWITCH_NAME_Y,
						PANEL.SWITCH_EYEBROW_Y,
						PANEL.SWITCH_TRACK_Y,
						PANEL.SWITCH_CAPTION_Y,
						Panel.layoutFor(400, 800, "detail").switchBlock,
						Panel.layoutFor(400, 800, "detail").blurbLines
					)
				)
			end)

			it("gives the phone's detail pane 70 px for it and still holds three blurb lines", function()
				local PANEL = Shop.CONFIG.PANEL
				local was = Panel.layoutFor(400, 800)
				local now = Panel.layoutFor(400, 800, "detail")
				expect(now.mode).to.equal("TALL")
				expect(now.switchBlock).to.equal(PANEL.DETAIL_SWITCH_PX)
				expect(PANEL.DETAIL_SWITCH_PX).to.equal(70)
				-- THE BLOCK REPLACES THE STATUS ROW, directly above the button, and the BUTTON does not
				-- move: *"the blurb box absorbs the difference, exactly as `layoutFor` already absorbs
				-- everything else"*.
				expect(now.buttonY).to.equal(was.buttonY)
				expect(was.statusY - now.statusY).to.equal(PANEL.DETAIL_SWITCH_PX)
				-- ...AND THE THREE LINES AND THE CASE FLOOR BOTH SURVIVE IT, which is the whole of what
				-- the absorption may not cost.
				expect(now.blurbLines >= 3).to.equal(true)
				expect(now.caseHeight >= PANEL.CASE_MIN_PX).to.equal(true)
			end)

			it("hides both surfaces for a man who owns nothing, and shows one when he does", function()
				-- OFF THE BUILT INSTANCES, because *"absent"* is a claim about what is on the screen.
				local frame = Hud.shopPanel() :: Frame
				local menu = frame:FindFirstChild("Menu") :: ScrollingFrame
				local row = menu:FindFirstChild("Item_" .. Shop.ITEM.ALWAYS_HUNTER) :: TextButton
				expect(row).to.be.ok()
				local block = row:FindFirstChild("RoleBlock") :: Frame
				expect(block).to.be.ok()
				Panel.setRoleWish(nil, nil)
				expect(block.Visible).to.equal(false)
				expect(Panel.roleLit()).to.equal(nil)
				expect(#Panel.switchText()).to.equal(0)
				-- AND NO OTHER ROW EVER GREW ONE.
				local blocks = 0
				for _, child in ipairs(menu:GetChildren()) do
					if child:IsA("GuiObject") and child:FindFirstChild("RoleBlock") ~= nil then
						blocks += 1
						expect(child.Name).to.equal("Item_" .. Shop.ITEM.ALWAYS_HUNTER)
					end
				end
				expect(blocks).to.equal(1)

				-- ...AND IT SHOWS WHEN HE DOES OWN IT (review round 1, note 7): the hiding half was the
				-- only one asserted, so "shows one" was in the case's name and nowhere else.
				Panel.setRoleWish(Panel.ROLE.HUNTER, nil)
				Panel.relayout()
				-- ON A DESKTOP THE SURFACE IS THE ROW; on a phone-sized viewport it is the detail pane and
				-- this row stays 64 px. Either way EXACTLY ONE surface carries it, which is what
				-- `switchSurfaceFor` decides -- and the built instances are what this reads.
				expect(Panel.switchSurfaceFor("WIDE", Panel.ROLE.HUNTER, Shop.ITEM.ALWAYS_HUNTER)).to.equal("row")
				if Panel.layoutFor(0, 0).mode == "WIDE" then
					expect(block.Visible).to.equal(true)
					expect(Panel.roleLit()).to.equal(Panel.ROLE.HUNTER)
					expect(#Panel.switchText()).to.equal(4)
				end
				Panel.setRoleWish(nil, nil)
				Panel.relayout()
				expect(block.Visible).to.equal(false)
			end)

			it("puts the two halves above the row's own children, so a press reaches a half", function()
				-- THE HIT TEST, AS ARITHMETIC OVER THE BAND THIS PANEL ALREADY OCCUPIES: the row is a
				-- `TextButton` at `Z + 2`, its name/price/tag are at `Z + 3`, and the halves are at
				-- `Z + 4` -- which the header's wallet and the buy button already use, and the two well
				-- fade masks sit at `Z + 6` with `Active = false` so they never swallow a press.
				local frame = Hud.shopPanel() :: Frame
				local menu = frame:FindFirstChild("Menu") :: ScrollingFrame
				local row = menu:FindFirstChild("Item_" .. Shop.ITEM.ALWAYS_HUNTER) :: TextButton
				local block = row:FindFirstChild("RoleBlock") :: Frame
				local track = block:FindFirstChild("RoleSwitch") :: Frame
				expect(track).to.be.ok()
				local name = row:FindFirstChild("Name") :: TextLabel
				for _, which in ipairs({ "Hunter", "Beater" }) do
					local half = track:FindFirstChild(which) :: TextButton
					expect(half).to.be.ok()
					expect(half.ZIndex > name.ZIndex).to.equal(true)
					expect(half.ZIndex > row.ZIndex).to.equal(true)
					expect(half:FindFirstChild("Word")).to.be.ok()
				end
				for _, side in ipairs({ "FadeTop", "FadeBottom" }) do
					local mask = frame:FindFirstChild(side) :: Frame
					expect(mask.Active).to.equal(false)
				end
			end)

			it("asks through the one sender it is handed, and never decides anything", function()
				-- THIS PANEL IS NOT THE SENDER. `Hud.PadPanel` is this client's one door onto
				-- `ReplicatedStorage.Lobby.Remotes`, so the function is handed in at `start` -- which
				-- keeps ONE sender and adds no `ShopPanel` -> `PadPanel` require edge (a cycle).
				-- `ShopPanel.start` IS IDEMPOTENT AND HAS ALREADY RUN IN THE REAL CLIENT, so this case
				-- cannot re-wire the panel's sender and does not pretend to: it drives `askRole`,
				-- which is the seam, and the SENDER's own contract -- one message, one word and
				-- nothing else on the wire -- is asserted in `pad_panel.spec` against a fake remote.
				Panel.setRoleWish(Panel.ROLE.HUNTER, nil)
				local before = Panel.stats().roleBlocked + Panel.stats().roleSent
				Panel.askRole(Panel.ROLE.BEATER)
				expect(Panel.stats().roleBlocked + Panel.stats().roleSent).to.equal(before + 1)
				-- ...AND ONCE THE DRIVE HAS HIM IT IS REFUSED, which is the state the caption explains.
				Panel.setRoleWish(Panel.ROLE.HUNTER, "Shooters")
				expect(Panel.roleUsable(Panel.ROLE.HUNTER, "Shooters")).to.equal(false)
				local was = Panel.stats().roleBlocked
				expect(Panel.askRole(Panel.ROLE.BEATER)).to.equal(false)
				expect(Panel.stats().roleBlocked).to.equal(was + 1)
				Panel.setRoleWish(nil, nil)
			end)

			it("says its two sentences, and never the pad's third", function()
				-- THE SHOP HAS NO PAD AND NO PARTY SIZE, so it can never say `NO BEATERS THIS DRIVE`.
				-- That row exists in both tables because the two are ONE vocabulary and a reader
				-- comparing them should find no gap.
				local TEXT = Shop.CONFIG.TEXT
				expect(Panel.roleCaptionFor(Panel.ROLE.HUNTER, nil)).to.equal(TEXT.ROLE_HUNTING)
				expect(Panel.roleCaptionFor(Panel.ROLE.BEATER, nil)).to.equal(TEXT.ROLE_BEATING)
				expect(Panel.roleCaptionFor(Panel.ROLE.BEATER, "Drivers")).to.equal(TEXT.ROLE_ASKED)
				expect(Panel.roleCaptionFor(nil, nil)).to.equal("")
				-- THE WORDS ARE THE SAME SENTENCES THE PAD'S TABLE CARRIES, so the two surfaces read as
				-- one control rather than as two features.
				local PADS = require(ReplicatedStorage:WaitForChild("Lobby")).CONFIG.PADS
				expect(TEXT.ROLE_HUNTING).to.equal(PADS.PANEL.ROLE.NOTE_HUNTER)
				expect(TEXT.ROLE_BEATING).to.equal(PADS.PANEL.ROLE.NOTE_BEATER)
				expect(TEXT.ROLE_SOLO).to.equal(PADS.PANEL.ROLE.NOTE_NONE)
				expect(TEXT.ROLE_ASKED).to.equal(PADS.PANEL.ROLE.NOTE_SENT)
				expect(TEXT.ROLE_TITLE).to.equal(PADS.PANEL.ROLE.EYEBROW)
			end)
		end)
	end)
end
