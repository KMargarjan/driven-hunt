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

			-- THE TWO MODES THE SPEC NAMES, with the exact rectangles it names them with.
			local desktop = Panel.layoutFor(1280, 720)
			expect(desktop.mode).to.equal("WIDE")
			expect(desktop.width).to.equal(640)
			expect(desktop.height).to.equal(576)
			expect(desktop.wellWidth).to.equal(228)
			expect(desktop.detailWidth).to.equal(364)
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
			expect(phone.cardWidth).to.equal(104)
			-- ...AND THE EXPLANATION STILL HOLDS THREE WHOLE LINES, which is the measurement
			-- `Shop.CONFIG.PANEL.BLURB_MAX` is written against.
			expect(phone.blurbLines >= 3).to.equal(true)

			-- EVERY BUTTON ACTUALLY BUILT IS A TOUCH TARGET, including the close box.
			local frame = Hud.shopPanel() :: Frame
			local rows, buys = 0, 0
			for _, child in ipairs(frame:GetDescendants()) do
				if child:IsA("TextButton") then
					if child.Name == "Close" then
						expect(child.Size.Y.Offset).to.equal(Shop.CONFIG.PANEL.CLOSE_PX)
					elseif child.Name == "Buy" then
						buys += 1
					else
						rows += 1
						expect(child.Size.Y.Offset >= 48).to.equal(true)
					end
				end
			end
			-- ONE ROW AND ONE CARD PER CATALOGUE ITEM -- both layouts are built once and one of them
			-- is shown -- and ONE buy button for the whole panel.
			expect(rows).to.equal(2 * #Shop.ORDER)
			expect(buys).to.equal(1)
			expect(#Shop.ORDER <= Shop.CONFIG.MAX_ITEMS).to.equal(true)
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
			expect(Panel.walletText()).to.equal("300|30")

			-- THE SHELVES, IN THE DIRECTOR'S OWN ORDER: Weapons, Ammo, Licences, Clothing.
			-- ...AND THEY ARE LETTER-SPACED, because Roblox `TextLabel` has no tracking property and
			-- the Designer's 10 px uppercase labels need it: `spaced("WEAPONS")` is "W E A P O N S".
			local shelves = Panel.headerText()
			expect(#shelves).to.equal(4)
			expect(shelves[1]).to.equal(Panel.spaced("WEAPONS"))
			expect(shelves[2]).to.equal(Panel.spaced("AMMO"))
			expect(shelves[3]).to.equal(Panel.spaced("LICENCES"))
			expect(shelves[4]).to.equal(Panel.spaced("CLOTHING"))
			expect(Panel.spaced("AMMO")).to.equal("A M M O")

			local lines = Panel.rowText()
			expect(#lines).to.equal(#Shop.ORDER)
			-- EVERY ROW IS ON SCREEN and each says its name and its price or its badge.
			-- A ROW IS `NAME|PRICE|TAG`: the name, the number (the coin is a Frame beside it), and the
			-- one tag that answers *"can I buy this?"* without a click.
			expect(lineFor(Shop.ITEM.HAT_RED)).to.equal("RED HAT|80|")
			-- The slug is owned, so it wears the OWNED chip.
			expect(lineFor(Shop.ITEM.SLUG)).to.equal(string.format("SLUG SHELLS|120|%s", Shop.CONFIG.TEXT.OWNED_TAG))
			-- NOTHING IS "SOON" ANY MORE (task 196): Karen removed the open-sighted rifle's row, which
			-- was the only one in the catalogue that was shown and never sold.
			for _, line in ipairs(lines) do
				expect(string.find(line, Shop.CONFIG.TEXT.SOON_TAG, 1, true)).to.equal(nil)
			end
			-- The scoped rifle: 30 hunts is enough, 300 coins is not, so the tag says HOW SHORT he is
			-- -- *"the affordability signal is never colour alone"*.
			expect(lineFor(Shop.ITEM.RIFLE)).to.equal(
				string.format("RIFLE, SCOPED|1500|%s", string.format(Shop.CONFIG.TEXT.ROW_POOR_TAG, 1200))
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
				string.format("BEATER LICENCE|250|%s", string.format(Shop.CONFIG.TEXT.ROW_LOCK_TAG, 2, 3))
			)
			expect(lineFor(Shop.ITEM.RIFLE)).to.equal(
				string.format("RIFLE, SCOPED|1500|%s", string.format(Shop.CONFIG.TEXT.ROW_LOCK_TAG, 2, 25))
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
			expect(pane.price).to.equal("120")
			-- THE EYEBROW IS THE SHELF IT CAME OFF, letter-spaced by the panel's own helper.
			expect(pane.eyebrow).to.equal(Panel.spaced("AMMO"))
			-- THE EXPLANATION IS THE SERVER'S OWN WORDS, verbatim: the panel does not write prose.
			expect(pane.blurb).to.equal(Shop.ROWS[Shop.ITEM.SLUG].blurb)
			expect(#pane.blurb > 40).to.equal(true)
			-- THE BUTTON CARRIES THE PRICE INSIDE IT: the word, a divider, a coin and the amount.
			expect(pane.button).to.equal(Shop.CONFIG.TEXT.BUY)
			expect(pane.amount).to.equal("120")

			-- A SECOND CLICK MOVES THE WHOLE PAGE, not half of it.
			Panel.select(Shop.ITEM.RIFLE)
			local second = Panel.detailText()
			expect(second.name).to.equal("RIFLE, SCOPED")
			expect(second.price).to.equal("1500")
			expect(second.blurb).to.equal(Shop.ROWS[Shop.ITEM.RIFLE].blurb)
			-- 300 coins against 1500, and the button says the SHORTFALL rather than "no coins":
			-- *"the number he is short is the only number that helps"*.
			expect(second.button).to.equal(string.format(Shop.CONFIG.TEXT.POOR_BUTTON, 1200))
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
			Panel.select(Shop.ITEM.HAT_RED)
			expect(Panel.detailText().button).to.equal(Shop.CONFIG.TEXT.BUY)
			expect(Panel.detailText().amount).to.equal("80")
			expect(buy.BackgroundColor3).to.equal(Panel.LOOK.BLAZE)

			-- OWNED: "IN YOUR KIT", the pine fill, and no amount -- a thing you have has no price.
			Panel.onState(statePayload({ owned = { [Shop.ITEM.HAT_RED] = true }, coins = 300, hunts = 30 }))
			expect(Panel.detailText().button).to.equal(Shop.CONFIG.TEXT.OWNED_BUTTON)
			expect(Panel.detailText().amount).to.equal("")
			expect(buy.BackgroundColor3).to.equal(Panel.LOOK.PINE_DARK)

			-- POOR -- AND THIS IS THE RECONCILIATION, WHICH IS THE POINT OF READING THE PAYLOAD AT
			-- RENDER TIME: nobody clicked anything between these two lines. A balance that changes
			-- while the panel is open changes the button with it, so an edge-triggered state set when
			-- the row was clicked cannot go stale here. The button says the SHORTFALL, because the
			-- number he is short is the only number that helps.
			Panel.onState(statePayload({ owned = {}, coins = 10, hunts = 30 }))
			expect(Panel.detailText().button).to.equal(string.format(Shop.CONFIG.TEXT.POOR_BUTTON, 70))
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
			Panel.select(Shop.ITEM.HAT_RED)
			expect(Panel.pictureId()).to.equal(Shop.ITEM.HAT_RED)
			expect((model :: Model).Parent).to.equal(nil)
			local models = 0
			for _, child in ipairs((frame :: ViewportFrame):GetChildren()) do
				if child:IsA("Model") then
					models += 1
				end
			end
			expect(models).to.equal(1)
		end)

		it("turns the picture while the panel is open and stands still while it is shut", function()
			Panel.onState(statePayload())
			Panel.setOpen(true)
			Panel.select(Shop.ITEM.HAT_RED)
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

		-- THE LICENCE DOES NOT ORBIT, IT ROCKS, and that is an engine fact rather than a preference
		-- (the Designer's spec, 6.4): *"a flat card on a full orbit goes edge-on twice a revolution
		-- and disappears; a nine-second sway never does"*. 17 degrees either side of its own yaw.
		it("rocks the flat card instead of turning it all the way round", function()
			local card = Display.viewFor(Shop.ITEM.BEATER_LICENCE)
			expect(card.rockDegrees).to.equal(17)
			expect(card.rockSeconds).to.equal(9)
			-- A WHOLE PERIOD COMES BACK TO THE MIDDLE, and the quarter points are the extremes.
			expect(Display.spinDegAt(0, card)).to.be.near(0, 0.001)
			expect(Display.spinDegAt(9, card)).to.be.near(0, 0.001)
			expect(Display.spinDegAt(2.25, card)).to.be.near(17, 0.001)
			expect(Display.spinDegAt(6.75, card)).to.be.near(-17, 0.001)
			-- IT NEVER GOES EDGE-ON: the card's own yaw is 15 degrees and the sway is 17, so the
			-- camera is between 32 and -2 degrees off its face and never at 90.
			for tenth = 0, 90 do
				local yaw = card.yawDeg + Display.spinDegAt(tenth / 10, card)
				expect(math.abs(yaw) < 60).to.equal(true)
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
			expect(Panel.statusText()).to.equal("YOU NEED 1200 COINS")
			-- ...and a purchase says what it bought, by its own label.
			Panel.onState(statePayload({ bought = Shop.ITEM.HAT_RED }), 100)
			expect(Panel.statusText()).to.equal(string.format(Shop.CONFIG.TEXT.BOUGHT, "RED HAT"))
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
			Panel.select(Shop.ITEM.HAT_RED)
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
		end)
	end)
end
