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
-- TASK 196 IS THE TWO-COLUMN PANEL. Karen, 2026-10-15: *"menus for buying things has to be better
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

local Panel = Hud.Shop
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

		-- THE LAYOUT, ASSERTED AS ARITHMETIC AND NOT AS A SCREENSHOT (task 165's rule). The panel is
		-- no longer one rectangle, so "it fits a phone" is a claim about a function: two screens in,
		-- two layouts out, and every rectangle inside its own panel.
		it("fits a 400 x 800 phone and fills a monitor, with every target a thumb can hit", function()
			for _, screen in ipairs({ { 400, 800 }, { 800, 600 }, { 1920, 1080 } }) do
				local layout = Panel.layoutFor(screen[1], screen[2])
				local margin = Shop.CONFIG.PANEL.MARGIN
				-- INSIDE THE SCREEN, both ways, with its gutter.
				expect(layout.width <= screen[1] - 2 * margin).to.equal(true)
				expect(layout.height <= screen[2] - 2 * margin).to.equal(true)
				expect(layout.width <= Shop.CONFIG.PANEL.MAX_WIDTH).to.equal(true)
				-- TWO COLUMNS THAT DO NOT TOUCH AND DO NOT LEAVE THE PANEL.
				expect(layout.listX > 0).to.equal(true)
				expect(layout.detailX >= layout.listX + layout.listWidth).to.equal(true)
				expect(layout.detailX + layout.detailWidth <= layout.width).to.equal(true)
				expect(layout.detailWidth > 0).to.equal(true)
				expect(layout.listY + layout.listHeight <= layout.height).to.equal(true)
				-- A PICTURE WORTH THE NAME, and a row and a button a thumb can hit (44 px is Roblox's
				-- own minimum; 48 and 56 clear it).
				expect(layout.imageHeight >= Shop.CONFIG.PANEL.IMAGE_MIN).to.equal(true)
				expect(layout.imageHeight < layout.listHeight).to.equal(true)
				expect(layout.rowHeight >= Shop.CONFIG.BUTTON_PX).to.equal(true)
				expect(layout.buyHeight >= Shop.CONFIG.BUTTON_PX).to.equal(true)
				expect(layout.buyY > layout.imageHeight).to.equal(true)
			end
			-- THE PHONE IS THE CASE THAT MATTERS, and 360 is the width design 13.1 measured: 400 less
			-- two 12 px gutters is 376, so the panel gets its whole width on the screen
			-- `hud_clarity.spec` asserts against.
			local phone = Panel.layoutFor(400, 800)
			expect(phone.width >= Shop.CONFIG.PANEL.WIDTH).to.equal(true)
			expect(phone.listWidth >= Shop.CONFIG.PANEL.LIST_MIN).to.equal(true)
			-- ...AND THE EXPLANATION STILL FITS ON THE PHONE, which is the measurement
			-- `Shop.CONFIG.PANEL.BLURB_MAX` was taken against: five lines of 27 characters.
			expect(phone.blurbLines >= 5).to.equal(true)
			expect(phone.blurbLines * 27 >= Shop.CONFIG.PANEL.BLURB_MAX).to.equal(true)
			-- ...AND EVERY BUTTON ACTUALLY BUILT IS AT LEAST THAT TALL, including CLOSE.
			local frame = Hud.shopPanel() :: Frame
			local buttons = 0
			for _, child in ipairs(frame:GetDescendants()) do
				if child:IsA("TextButton") then
					buttons += 1
					expect(child.Size.Y.Offset >= Shop.CONFIG.BUTTON_PX).to.equal(true)
				end
			end
			-- One per catalogue item, plus CLOSE and the one BUY -- five BUY buttons became one
			-- (task 196).
			expect(buttons).to.equal(#Shop.ORDER + 2)
			expect(#Shop.ORDER <= Shop.CONFIG.MAX_ITEMS).to.equal(true)
		end)

		-- ---------------------------------------------------------------- the side menu

		it("draws the server's rows under the four shelves, with the price and one badge", function()
			Panel.onState(statePayload())
			Panel.setOpen(true)
			expect(Panel.isOpen()).to.equal(true)
			expect((Hud.shopPanel() :: Frame).Visible).to.equal(true)
			expect(Panel.titleText()).to.equal(Shop.CONFIG.TEXT.TITLE)
			expect(Panel.balanceText()).to.equal("COINS 300     HUNTS 30")

			-- THE SHELVES, IN THE DIRECTOR'S OWN ORDER: Weapons, Ammo, Licences, Clothing.
			local shelves = Panel.headerText()
			expect(#shelves).to.equal(4)
			expect(shelves[1]).to.equal("WEAPONS")
			expect(shelves[2]).to.equal("AMMO")
			expect(shelves[3]).to.equal("LICENCES")
			expect(shelves[4]).to.equal("CLOTHING")

			local lines = Panel.rowText()
			expect(#lines).to.equal(#Shop.ORDER)
			-- EVERY ROW IS ON SCREEN and each says its name and its price or its badge.
			local hat = lineFor(Shop.ITEM.HAT_RED)
			expect(hat).to.be.ok()
			expect(string.find(hat :: string, "RED HAT", 1, true) ~= nil).to.equal(true)
			expect(string.find(hat :: string, "80 COINS", 1, true) ~= nil).to.equal(true)
			-- The slug is owned: the badge says so and no price is offered for a thing you have.
			local slug = lineFor(Shop.ITEM.SLUG)
			expect(string.find(slug :: string, Shop.CONFIG.TEXT.OWNED_TAG, 1, true) ~= nil).to.equal(true)
			expect(string.find(slug :: string, "120 COINS", 1, true)).to.equal(nil)
			-- The open-sight rifle is SHOWN and not for sale.
			local soon = lineFor(Shop.ITEM.RIFLE_OPEN)
			expect(string.find(soon :: string, Shop.CONFIG.TEXT.SOON_TAG, 1, true) ~= nil).to.equal(true)
			-- The scoped rifle: 30 hunts is enough, 300 coins is not.
			local rifle = lineFor(Shop.ITEM.RIFLE)
			expect(string.find(rifle :: string, "NO COINS", 1, true) ~= nil).to.equal(true)
			-- ...and the hint, while nothing has been refused.
			expect(Panel.messageText()).to.equal(Shop.CONFIG.TEXT.HINT)
		end)

		it("locks a rung behind the hunts a player has not walked", function()
			Panel.onState(statePayload({ owned = {}, coins = 5000, hunts = 2 }))
			Panel.setOpen(true)
			-- The beater's licence needs 3 hunts and he has 2...
			expect(string.find(lineFor(Shop.ITEM.BEATER_LICENCE) :: string, "3 HUNTS", 1, true) ~= nil).to.equal(true)
			-- ...and the scoped rifle needs 25.
			expect(string.find(lineFor(Shop.ITEM.RIFLE) :: string, "25 HUNTS", 1, true) ~= nil).to.equal(true)
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
			expect(pane.price).to.equal("120 COINS")
			expect(pane.unlock).to.equal(Shop.CONFIG.TEXT.UNLOCK_OPEN)
			-- THE EXPLANATION IS THE SERVER'S OWN WORDS, verbatim: the panel does not write prose.
			expect(pane.blurb).to.equal(Shop.ROWS[Shop.ITEM.SLUG].blurb)
			expect(#pane.blurb > 40).to.equal(true)
			expect(pane.button).to.equal(Shop.CONFIG.TEXT.BUY)

			-- A SECOND CLICK MOVES THE WHOLE PAGE, not half of it.
			Panel.select(Shop.ITEM.RIFLE)
			local second = Panel.detailText()
			expect(second.name).to.equal("RIFLE, SCOPED")
			expect(second.price).to.equal("1500 COINS")
			expect(second.unlock).to.equal(string.format(Shop.CONFIG.TEXT.UNLOCK_AT, 25))
			expect(second.blurb).to.equal(Shop.ROWS[Shop.ITEM.RIFLE].blurb)
			-- 300 coins against 1500.
			expect(second.button).to.equal(Shop.CONFIG.TEXT.POOR_TAG)
		end)

		it("says how many hunts are still to go on a rung he cannot reach yet", function()
			Panel.onState(statePayload({ owned = {}, coins = 5000, hunts = 1 }))
			Panel.setOpen(true)
			Panel.select(Shop.ITEM.BEATER_LICENCE)
			local pane = Panel.detailText()
			expect(pane.unlock).to.equal(string.format(Shop.CONFIG.TEXT.UNLOCK_LEFT, 2))
			expect(pane.button).to.equal(string.format(Shop.CONFIG.TEXT.LOCKED_TAG, 3))
		end)

		-- THE FOUR STATES OF THE ONE BUTTON, each one out of the server's own `WireRow` and not out of
		-- a second opinion on this client (design hazard 10).
		it("gives the one big button four states, and the green only to the one you may press", function()
			local buy = ((Hud.shopPanel() :: Frame):FindFirstChild("Detail") :: Frame):FindFirstChild(
					"Buy"
				) :: TextButton
			expect(buy).to.be.ok()

			-- BUYABLE.
			Panel.onState(statePayload({ owned = {}, coins = 300, hunts = 30 }))
			Panel.setOpen(true)
			Panel.select(Shop.ITEM.HAT_RED)
			expect(Panel.detailText().button).to.equal(Shop.CONFIG.TEXT.BUY)
			expect(buy.BackgroundColor3).to.equal(Panel.LOOK.BUY_COLOR)

			-- OWNED.
			Panel.onState(statePayload({ owned = { [Shop.ITEM.HAT_RED] = true }, coins = 300, hunts = 30 }))
			expect(Panel.detailText().button).to.equal(Shop.CONFIG.TEXT.OWNED_TAG)
			expect(buy.BackgroundColor3).to.equal(Panel.LOOK.DEAD_COLOR)

			-- POOR -- AND THIS IS THE RECONCILIATION, WHICH IS THE POINT OF READING THE PAYLOAD AT
			-- RENDER TIME: nobody clicked anything between these two lines. A balance that changes
			-- while the panel is open changes the button with it, so an edge-triggered state set when
			-- the row was clicked cannot go stale here.
			Panel.onState(statePayload({ owned = {}, coins = 10, hunts = 30 }))
			expect(Panel.detailText().button).to.equal(Shop.CONFIG.TEXT.POOR_TAG)
			expect(buy.BackgroundColor3).to.equal(Panel.LOOK.DEAD_COLOR)

			-- LOCKED.
			Panel.onState(statePayload({ owned = {}, coins = 5000, hunts = 0 }))
			Panel.select(Shop.ITEM.RIFLE)
			expect(Panel.detailText().button).to.equal(string.format(Shop.CONFIG.TEXT.LOCKED_TAG, 25))

			-- NOT FOR SALE AT ALL.
			Panel.select(Shop.ITEM.RIFLE_OPEN)
			expect(Panel.detailText().button).to.equal(Shop.CONFIG.TEXT.SOON_TAG)
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
			local wanted = (Display.spinDegAt(2) - Display.spinDegAt(0) + 720) % 360
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

		-- ---------------------------------------------------------------- money, words and the wire

		it("prints one line when there is no money in this build at all", function()
			Panel.onState(statePayload({ coinsOn = false, noProfile = true }))
			Panel.setOpen(true)
			expect(Panel.balanceText()).to.equal(Shop.CONFIG.TEXT.CLOSED)
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
			expect(Panel.messageText()).to.equal(Shop.CONFIG.TEXT.OWNED_TAG)
			-- The open-sight rifle is shown and never sold.
			Panel.select(Shop.ITEM.RIFLE_OPEN)
			expect(Panel.pressSelected()).to.equal(false)
			expect(Panel.messageText()).to.equal(Shop.CONFIG.TEXT.SOON_TAG)
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
end
