-- touch_controls.spec: the touch action cluster, the rail's fold, and the one-path claim.
--
-- WHAT IT PROVES AND WHAT IT CANNOT. Every rectangle, every visibility rule and the tool order are
-- PURE -- a viewport in, pixels out; a list of names in, the next name out -- so everything that
-- could be arithmetically wrong is asserted here with hand-written values and no drive, no world,
-- no camera and no second player. `docs/PROJECT_CONTEXT.md`'s *"things measured correct and looked
-- wrong"* is survivable only that way round: the arithmetic is provable here and the LOOK is the
-- one thing left for Karen's eye.
--
-- THE MOST VALUABLE CASE IN THIS FILE IS THE INTERSECTION ONE, for the reason `hud_clarity.spec`
-- and `map_ui.spec` both give: task 125 round 2 shipped the compass strip over the drive bar and it
-- was not seen in any frame. This task adds four buttons to the one corner of the screen that was
-- already claimed by the engine's jump button, the ammo chip and the rail's column, so the whole
-- bottom-right is one rectangle argument -- and it is checked at 800 x 400 and 400 x 800 as well
-- as at this window, because a scale-anchored `Position` resolves against the real screen and no
-- tool here can resize a Studio viewport.
--
-- WHAT ONE DESKTOP CLIENT CANNOT PROVE, said out loud (rules 6 and 8):
--   * THE TAP. A spec cannot fire `GuiButton.Activated` and the harness cannot synthesise a touch
--     (`tools/studio_mcp.py`'s scenario file speaks `keyboard`, `mouse` and `wait` and nothing
--     else). So `Touch.press` is the seam these cases drive, and what they prove is the ACTION,
--     not the touch. That is `Hud.Rail`'s own limitation, queued as 165a.
--   * THE KEEP-OUTS. `Touch.CONFIG.JUMP` and `.THUMBSTICK` are OUR rectangles: Roblox states the
--     two zones and publishes no size for either. The case named "...only on a touch device"
--     reads the real `TouchGui` when there is one and SAYS IN ITS OWN NAME when it did not run --
--     a case that silently skips is a false-PASS path.
--   * A BEATER'S BLOW END TO END. `Match.CONFIG.ODD_PLAYER_TEAM` is "Shooters", so the one-player
--     gate is a hunter and no horn is granted. The BLOW case builds its own Tool and counts its own
--     `Activated`, which proves the client half; the server half is `zz_horn.spec`'s.
--   * WHETHER THE PICTURE IS RIGHT. Karen's eye.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/mobile-controls.md - note: docs/research/2026-10-20-mobile-controls.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Horn = require(ReplicatedStorage:WaitForChild("Horn"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Hud = require(scripts:WaitForChild("Hud"))
local Weapon = require(scripts:WaitForChild("Weapon"))

local Touch = Hud.Touch
local Rail = Hud.Rail
local MapUi = Hud.MapUi
local Input = Weapon.Input

local LANDSCAPE = Vector2.new(800, 400)
local PORTRAIT = Vector2.new(400, 800)
local PLAY = Vector2.new(969, 784)
local DESKTOP = Vector2.new(1920, 1080)
local TALL_DESKTOP = Vector2.new(800, 600)

local function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh): boolean
	return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
end

-- PUT BACK WHATEVER WAS IN THE PLAYER'S HAND. Both doors this file drives -- SWAP and BLOW --
-- really do move a Tool, and every spec file in a run shares one character: `weapon_client.spec`
-- asserts four bound actions, which exist only while a gun is equipped.
local function restoreEquipped(name: string?)
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil then
		return
	end
	humanoid:UnequipTools()
	if name == nil then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = if backpack ~= nil then backpack:FindFirstChild(name) else nil
	if tool == nil and character ~= nil then
		tool = character:FindFirstChild(name)
	end
	if tool ~= nil and tool:IsA("Tool") then
		humanoid:EquipTool(tool :: Tool)
	end
	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()
end

-- IS THIS VIEWPORT A PHONE'S? The two keep-outs and the cluster itself exist only on a touch
-- device: a keep-out is a claim about where a thumb will land, so on a desktop it is not a
-- rectangle at all, and `SHOW_ON_DESKTOP` is false so the cluster is not drawn there either.
local function isPhoneViewport(viewport: Vector2): boolean
	return viewport == LANDSCAPE or viewport == PORTRAIT
end

-- WHAT THE RAIL'S FLOOR IS RAISED ABOVE, exactly as `Hud.renderObjective` computes it: the chip,
-- the cluster when it is drawn, and the jump button when there is one. Written once here, because a
-- test that models a different floor from the renderer proves nothing about the renderer.
local function railBlockers(viewport: Vector2)
	local touchOn = isPhoneViewport(viewport)
	local leftStack = Hud.leftStackRight(viewport)
	local shown = Touch.shown(touchOn)
	local rx, ry = Touch.reserved(viewport, shown, leftStack)
	local px, py, pw, ph = Hud.cornerRect(viewport, rx, ry)
	local out = { { x = px, y = py, w = pw, h = ph } }
	if shown then
		local cx, cy, cw, ch = Touch.rect(viewport, leftStack)
		table.insert(out, { x = cx, y = cy, w = cw, h = ch })
	end
	if touchOn then
		local jx, jy, jw, jh = Touch.jumpKeepOut(viewport)
		table.insert(out, { x = jx, y = jy, w = jw, h = jh })
	end
	return out
end

local function railRect(viewport: Vector2): (number, number, number, number)
	return Rail.rect(
		viewport,
		MapUi.diameterFor(viewport.X, viewport.Y),
		MapUi.CONFIG.MINIMAP_TOP,
		#Rail.BUTTONS,
		Rail.floorFor(viewport, railBlockers(viewport))
	)
end

-- THE RECTANGLES OF EVERYTHING THAT MAY NOT TOUCH, at a given viewport, from the SAME constants the
-- renderers read -- never a number typed twice.
local function boxes(viewport: Vector2)
	local out: { { name: string, x: number, y: number, w: number, h: number } } = {}
	local function add(name: string, x: number, y: number, w: number, h: number)
		table.insert(out, { name = name, x = x, y = y, w = w, h = h })
	end
	local touchOn = isPhoneViewport(viewport)
	local leftStack = Hud.leftStackRight(viewport)
	local shown = Touch.shown(touchOn)
	if shown then
		add("cluster", Touch.rect(viewport, leftStack))
		for _, button in ipairs(Touch.BUTTONS) do
			add(button.id, Touch.buttonRect(button.id, viewport, leftStack))
		end
	end
	if touchOn then
		add("jump", Touch.jumpKeepOut(viewport))
		add("thumbstick", Touch.thumbstickKeepOut(viewport))
	end
	add("rail", railRect(viewport))
	add("minimap", MapUi.minimapRect(viewport))
	local reserveX, reserveY = Touch.reserved(viewport, shown, leftStack)
	add("chip", Hud.cornerRect(viewport, reserveX, reserveY))
	add("status", Hud.statusRect(viewport))
	return out
end

-- PAIRS THAT ARE ALLOWED TO TOUCH, each with the MEASURED reason it is here rather than fixed.
--
-- (rail, jump) AT 800 x 400 IS A REAL HOLE AND IT IS REPORTED, NOT ASSERTED AWAY. On a landscape
-- phone the minimap's bottom is y 236 and the JUMP keep-out's top is y 260, which leaves **24 px**
-- of free right-edge column -- and the smallest button in this design system is 48. No
-- right-anchored column of rail buttons can clear the jump button at that viewport, at any fold:
-- more columns move the rail's LEFT edge left and leave its RIGHT edge at the screen's margin,
-- which is inside the jump button's x-range whatever happens. The fold still fixes the thing this
-- task set out to fix -- before it, the rail's bottom was at 510 on a 400 px screen and RELOAD and
-- AMMO were OFF the phone entirely -- and a real landscape layout for the top band and the right
-- column is the Designer's, named as out of scope in the design (section 14.4) and queued.
-- Keyed on the two names SORTED, so the list cannot depend on the order the boxes happen to be
-- built in -- which is what made the first attempt at this miss ("jump/rail" against "rail/jump").
local ALLOWED_TO_TOUCH = {
	["800x400 jump|rail"] = true,
}

local function pairKey(viewport: Vector2, a: string, b: string): string
	local first, second = a, b
	if first > second then
		first, second = b, a
	end
	return string.format("%.0fx%.0f %s|%s", viewport.X, viewport.Y, first, second)
end

return function()
	describe("the touch cluster's shape and placement", function()
		it("is 168 x 160, and that does not depend on how many buttons show", function()
			local w, h = Touch.clusterSize()
			expect(w).to.equal(168)
			expect(h).to.equal(160)
		end)

		it("sits beside the jump button in landscape and above it in portrait", function()
			-- THE RULE IS ONE LINE AND IT HAS TWO ANSWERS. At 400 x 800, between a 180 px thumbstick
			-- and a 140 px jump button, a 400 px screen has 80 px of bottom band and an 88 px FIRE
			-- does not fit in it. So portrait goes up.
			expect(Touch.placement(LANDSCAPE, Hud.leftStackRight(LANDSCAPE))).to.equal("left-of-jump")
			expect(Touch.placement(PORTRAIT, Hud.leftStackRight(PORTRAIT))).to.equal("above-jump")
		end)

		it("flips at exactly clusterWidth + JUMP_CLEAR_PX of free width", function()
			-- THE BOUNDARY, one pixel either side, so the comparison cannot drift from `>=` to `>`
			-- without a test saying so. `leftStackRightPx` is driven directly here rather than
			-- through the Hud, because the free width is what the rule reads.
			local clusterWidth = Touch.clusterSize()
			local jumpSize = Touch.CONFIG.JUMP.BUTTON_PX + Touch.CONFIG.JUMP.INSET_PX
			local need = clusterWidth + Touch.CONFIG.JUMP_CLEAR_PX
			local viewport = Vector2.new(1000, 500)
			local exact = (viewport.X - jumpSize) - need
			expect(Touch.placement(viewport, exact)).to.equal("left-of-jump")
			expect(Touch.placement(viewport, exact + 1)).to.equal("above-jump")
		end)

		it("puts every rectangle exactly where the design says, at 800 x 400", function()
			local function fmt(x, y, w, h)
				return string.format("%d..%d, %d..%d", x, x + w, y, y + h)
			end
			local leftStack = Hud.leftStackRight(LANDSCAPE)
			expect(fmt(Touch.rect(LANDSCAPE, leftStack))).to.equal("472..640, 224..384")
			expect(fmt(Touch.buttonRect("FIRE", LANDSCAPE, leftStack))).to.equal("552..640, 296..384")
			expect(fmt(Touch.buttonRect("AIM", LANDSCAPE, leftStack))).to.equal("576..640, 224..288")
			expect(fmt(Touch.buttonRect("BLOW", LANDSCAPE, leftStack))).to.equal("472..544, 312..384")
			expect(fmt(Touch.buttonRect("SWAP", LANDSCAPE, leftStack))).to.equal("488..544, 248..304")
		end)

		it("puts every rectangle exactly where the design says, at 400 x 800", function()
			local function fmt(x, y, w, h)
				return string.format("%d..%d, %d..%d", x, x + w, y, y + h)
			end
			local leftStack = Hud.leftStackRight(PORTRAIT)
			expect(fmt(Touch.rect(PORTRAIT, leftStack))).to.equal("216..384, 480..640")
			expect(fmt(Touch.buttonRect("FIRE", PORTRAIT, leftStack))).to.equal("296..384, 552..640")
			expect(fmt(Touch.buttonRect("AIM", PORTRAIT, leftStack))).to.equal("320..384, 480..544")
			expect(fmt(Touch.buttonRect("BLOW", PORTRAIT, leftStack))).to.equal("216..288, 568..640")
			expect(fmt(Touch.buttonRect("SWAP", PORTRAIT, leftStack))).to.equal("232..288, 504..560")
		end)

		it("gives every target at least 44 px, 8 px of gap and 20 px of jump clearance", function()
			-- WCAG 2.2 SC 2.5.5: *"The target size is at least 44 by 44"*. Roblox's own sample puts
			-- a custom button 20 px to the left of the jump button; FIRE is at exactly that.
			local faults = {}
			for _, viewport in ipairs({ LANDSCAPE, PORTRAIT }) do
				local leftStack = Hud.leftStackRight(viewport)
				local jx, jy, jw, jh = Touch.jumpKeepOut(viewport)
				for _, button in ipairs(Touch.BUTTONS) do
					local bx, by, bw, bh = Touch.buttonRect(button.id, viewport, leftStack)
					if math.min(bw, bh) < 44 then
						table.insert(faults, button.id .. " smaller than 44")
					end
					-- The gap to the jump keep-out on whichever axis the two are separated by.
					local dx = math.max(jx - (bx + bw), bx - (jx + jw))
					local dy = math.max(jy - (by + bh), by - (jy + jh))
					if math.max(dx, dy) < Touch.CONFIG.JUMP_CLEAR_PX then
						table.insert(faults, button.id .. " within 20 of jump")
					end
					for _, other in ipairs(Touch.BUTTONS) do
						if other.id ~= button.id then
							local ox, oy, ow, oh = Touch.buttonRect(other.id, viewport, leftStack)
							local gx = math.max(ox - (bx + bw), bx - (ox + ow))
							local gy = math.max(oy - (by + bh), by - (oy + oh))
							if math.max(gx, gy) < Touch.CONFIG.GAP then
								table.insert(faults, button.id .. "/" .. other.id .. " closer than 8")
							end
						end
					end
				end
			end
			expect(table.concat(faults, ", ")).to.equal("")
		end)

		it("overlaps NOTHING, at five viewports", function()
			-- THE CASE THIS FILE EXISTS FOR. Three members of section 4.3 are EXCLUDED, each with
			-- its reason, which is the idiom `hud_clarity.spec` already uses:
			--   1. the full map, the report, the shop and the pad dialog -- the cluster is not drawn
			--      while any of them is up (`Touch.setCovered`), and that predicate is asserted
			--      below instead;
			--   2. the results board and the start card -- centred cards that already exceed a
			--      400 px screen before this task (`hud-clarity.md` 12.2), the board being in the
			--      covered set and the start card drawn above the cluster's ZIndex;
			--   3. the toast feed and the hit card against the THUMBSTICK keep-out at 400 x 800 --
			--      they are inside it TODAY, before this task adds anything (note section 6). The
			--      cluster is proved clear of the feed instead, which is what this task can own.
			local clashes = {}
			for _, viewport in ipairs({ PORTRAIT, LANDSCAPE, TALL_DESKTOP, PLAY, DESKTOP }) do
				local list = boxes(viewport)
				for i = 1, #list do
					for j = i + 1, #list do
						local a, b = list[i], list[j]
						-- A button is INSIDE the cluster by construction; that is the one pair the
						-- argument is not about.
						local nested = a.name == "cluster" or b.name == "cluster"
						local pair = pairKey(viewport, a.name, b.name)
						if
							not nested
							and not ALLOWED_TO_TOUCH[pair]
							and rectsOverlap(a.x, a.y, a.w, a.h, b.x, b.y, b.w, b.h)
						then
							table.insert(clashes, pair)
						end
					end
				end
			end
			expect(table.concat(clashes, ", ")).to.equal("")
		end)

		it("keeps the cluster clear of the bottom-left stack", function()
			-- A RECTANGLE TEST AND NOT AN X-EDGE ONE, because at 400 x 800 the feed frame is 440 px
			-- WIDE ON A 400 px SCREEN (`Hud.build`'s `feed.Size`, a defect that predates this task
			-- -- research note section 6), so no cluster could ever sit to the right of it. What
			-- must be true is that they do not overlap, and in portrait they do not: the cluster is
			-- y 480..640 and the feed's three lines sit on the bottom margin below it.
			local feedTop = {}
			feedTop[LANDSCAPE] = LANDSCAPE.Y - 16 - Hud.feedHeight(LANDSCAPE.X)
			feedTop[PORTRAIT] = PORTRAIT.Y - 16 - Hud.feedHeight(PORTRAIT.X)
			for _, viewport in ipairs({ LANDSCAPE, PORTRAIT }) do
				local cx, cy, cw, ch = Touch.rect(viewport, Hud.leftStackRight(viewport))
				local overlaps =
					rectsOverlap(cx, cy, cw, ch, 16, feedTop[viewport], Hud.FEED.WIDTH, Hud.feedHeight(viewport.X))
				expect(overlaps).to.equal(false)
			end
		end)
	end)

	describe("what is drawn, and when", function()
		it("is hidden on a desktop and shown on a touch device, both by parameter", function()
			-- SHIPPED `false`, and the two states are reachable BY PARAMETER so neither this test
			-- nor the feature rests on which way the constant happens to sit.
			expect(Touch.shown(true, false)).to.equal(true)
			expect(Touch.shown(false, false)).to.equal(false)
			expect(Touch.shown(false, true)).to.equal(true)
			expect(Touch.shown(true, true)).to.equal(true)
			expect(Touch.shown(false)).to.equal(Touch.CONFIG.SHOW_ON_DESKTOP)
		end)

		it("needs all three of on-device, not-suppressed and not-covered", function()
			for _, suppressed in ipairs({ false, true }) do
				for _, covered in ipairs({ false, true }) do
					for _, onDesktop in ipairs({ false, true }) do
						for _, touchOn in ipairs({ false, true }) do
							local want = (touchOn or onDesktop) and not suppressed and not covered
							expect(Touch.visible(touchOn, suppressed, covered, onDesktop)).to.equal(want)
						end
					end
				end
			end
		end)

		it("draws no button whose action would have nothing to do", function()
			-- "NO DEAD BUTTONS" AS A PREDICATE RATHER THAN A COMMENT: FIRE and AIM need a gun, SWAP
			-- needs two carried Tools, BLOW needs a horn.
			local function visible(id: string, hasWeapon: boolean, carried: number, hasHorn: boolean)
				for _, button in ipairs(Touch.BUTTONS) do
					if button.id == id then
						return Touch.buttonVisible(button, hasWeapon, carried, hasHorn)
					end
				end
				return false
			end
			for _, carried in ipairs({ 0, 1, 2, 3 }) do
				for _, hasHorn in ipairs({ false, true }) do
					expect(visible("FIRE", false, carried, hasHorn)).to.equal(false)
					expect(visible("AIM", false, carried, hasHorn)).to.equal(false)
					expect(visible("FIRE", true, carried, hasHorn)).to.equal(true)
					expect(visible("SWAP", true, carried, hasHorn)).to.equal(carried >= 2)
					expect(visible("BLOW", true, carried, hasHorn)).to.equal(hasHorn)
				end
			end
		end)

		it("exists in the one ScreenGui with four real buttons at their design sizes", function()
			local cluster = Hud.touchCluster()
			expect(cluster).to.be.ok()
			expect((cluster :: Frame).Parent).to.equal(Hud.gui())
			local sizes = { FIRE = 88, AIM = 64, SWAP = 56, BLOW = 72 }
			for id, px in pairs(sizes) do
				local node = Touch.button(id)
				expect(node).to.be.ok()
				expect((node :: TextButton).Size.X.Offset).to.equal(px)
				expect((node :: TextButton).Size.Y.Offset).to.equal(px)
			end
		end)

		it("follows setSuppressed and setCovered, and restores what it found", function()
			local wasSuppressed, wasCovered = Touch.isSuppressed(), Touch.isCovered()
			local cluster = Hud.touchCluster() :: Frame
			for _, suppressed in ipairs({ false, true }) do
				for _, covered in ipairs({ false, true }) do
					Touch.setSuppressed(suppressed)
					Touch.setCovered(covered)
					expect(cluster.Visible).to.equal(Touch.visible(UserInputService.TouchEnabled, suppressed, covered))
				end
			end
			Touch.setSuppressed(wasSuppressed)
			Touch.setCovered(wasCovered)
		end)
	end)

	describe("one path to the server", function()
		it("calls Weapon.Input's own functions, proved by identity", function()
			-- THE CLAIM OF THE WHOLE TASK. Not "a touch FIRE behaves like a click" -- that is a
			-- behaviour two implementations could satisfy for a while -- but "the button calls THE
			-- function the mouse calls", which nothing can drift away from.
			expect(Touch.actionFor("FIRE")).to.equal(Input.fire)
			expect(Touch.actionFor("AIM")).to.equal(Input.toggleAim)
			expect(Touch.actionFor("SWAP")).to.equal(Input.swap)
			expect(Touch.actionFor("BLOW")).to.equal(Input.blowHorn)
		end)

		it("refuses a press while something is holding input", function()
			-- The hold lives in `Input`, checked once for both doors.
			expect(Input.isHeld()).to.equal(false)
			Input.requestHold("touch_controls.spec")
			expect(Input.fire()).to.equal(false)
			expect(Input.swap()).to.equal(false)
			expect(Input.blowHorn()).to.equal(false)
			expect(Input.setAim(true)).to.equal(false)
			expect(Input.isAiming()).to.equal(false)
			Input.releaseHold("touch_controls.spec")
			expect(Input.isHeld()).to.equal(false)
		end)

		it("refuses a press while suppressed or covered, and counts the refusal", function()
			-- `Touch.press` differs from `Rail.press` here on purpose: MAP and REPORT are toggles
			-- and must stay drivable while hidden; FIRE is a shot.
			local wasCovered = Touch.isCovered()
			local before = Touch.stats().refused
			Touch.setCovered(true)
			expect(Touch.press("FIRE")).to.equal(false)
			expect(Touch.stats().refused > before).to.equal(true)
			Touch.setCovered(wasCovered)
		end)

		it("flips the aim flag on a press and flips it back", function()
			local wasCovered, wasSuppressed = Touch.isCovered(), Touch.isSuppressed()
			Touch.setCovered(false)
			Touch.setSuppressed(false)
			local before = Input.isAiming()
			Touch.press("AIM")
			expect(Input.isAiming()).to.equal(not before)
			Touch.press("AIM")
			expect(Input.isAiming()).to.equal(before)
			Touch.setCovered(wasCovered)
			Touch.setSuppressed(wasSuppressed)
		end)

		it("answers false for a button that does not exist", function()
			expect(Touch.press("NOT_A_BUTTON")).to.equal(false)
		end)
	end)

	describe("the next Tool", function()
		it("walks the sorted list, wraps, and refuses to pick from fewer than two", function()
			local four = { "Horn", "Lever", "Rifle", "Shotgun" }
			expect(Input.nextToolName(four, "Horn")).to.equal("Lever")
			expect(Input.nextToolName(four, "Shotgun")).to.equal("Horn")
			expect(Input.nextToolName(four, nil)).to.equal("Horn")
			expect(Input.nextToolName(four, "NotCarried")).to.equal("Horn")
			expect(Input.nextToolName({ "Shotgun" }, "Shotgun")).to.equal(nil)
			expect(Input.nextToolName({}, nil)).to.equal(nil)
		end)

		it("reads the carried Tools off the tree, sorted", function()
			-- SORTED IS THE POINT: the engine's own child order moves every time a Tool is
			-- equipped, so an order read off the tree would put a different gun under the same
			-- button on two consecutive taps.
			local summary = Input.carriedSummary()
			expect(type(summary.count)).to.equal("number")
			expect(type(summary.hasHorn)).to.equal("boolean")
			for index = 2, #summary.names do
				expect(summary.names[index - 1] <= summary.names[index]).to.equal(true)
			end
			expect(summary.count).to.equal(#summary.names)
		end)

		it("equips the next carried Tool, or refuses when there is only one", function()
			-- THE CASE THAT PROVES `UnequipTools` + `EquipTool` DOES WHAT THE DESIGN SAYS, because
			-- Roblox's signals are DEFERRED (measured, task 47) -- so it waits a Heartbeat and then
			-- reads the tree rather than trusting the call.
			local summary = Input.carriedSummary()
			if summary.count < 2 then
				expect(Input.swap()).to.equal(false)
				return
			end
			local wanted = Input.nextToolName(summary.names, summary.equipped)
			expect(Input.swap()).to.equal(true)
			RunService.Heartbeat:Wait()
			RunService.Heartbeat:Wait()
			expect(Input.carriedSummary().equipped).to.equal(wanted)
			-- PUT HIS HANDS BACK EXACTLY AS THEY WERE FOUND. This spec runs before
			-- `weapon_client.spec` in one Play session, and that file asserts FOUR bound
			-- `DrivenHunt.Weapon.*` actions -- which exist only while a gun is equipped. Leaving a
			-- different Tool in the hand cost this task a whole gate run.
			restoreEquipped(summary.equipped)
		end)

		it("activates a carried horn without any remote, and refuses when there is none", function()
			-- M1 ON THIS CLIENT, with a spec-made Tool so it needs no beater and no server horn:
			-- `tool:Activate()` is what `Input.blowHorn` ends with, and `Tool.Activated` is what the
			-- server connects. The real horn's cooldown is the server's and is not re-implemented.
			local character = player.Character
			if character == nil then
				expect(Input.blowHorn()).to.equal(false)
				return
			end
			local existing = Input.carriedSummary().hasHorn
			if existing then
				-- A real horn is carried (a beater). Do not fire it: a blast is the server's event
				-- and this spec is not here to make one.
				expect(type(Input.blowHorn)).to.equal("function")
				return
			end
			local tool = Instance.new("Tool")
			tool.Name = Horn.TOOL_NAME
			tool.RequiresHandle = false
			local fired = 0
			tool.Activated:Connect(function()
				fired += 1
			end)
			local wasEquipped = Input.carriedSummary().equipped
			tool.Parent = player:FindFirstChildOfClass("Backpack")
			expect(Input.blowHorn()).to.equal(true)
			RunService.Heartbeat:Wait()
			RunService.Heartbeat:Wait()
			expect(fired).to.equal(1)
			tool:Destroy()
			RunService.Heartbeat:Wait()
			expect(Input.blowHorn()).to.equal(false)
			-- ...AND THE GUN GOES BACK IN HIS HAND. `blowHorn` EQUIPS the horn, which is exactly
			-- what a beater wants and exactly what would leave the next spec file holding nothing.
			restoreEquipped(wasEquipped)
		end)
	end)

	describe("the rail fits on a phone", function()
		it("folds into two columns on a phone and into one on every desktop", function()
			-- BEFORE THIS TASK: `topFor(96, 140)` + `heightFor(4)` = 510 on a 400 px tall screen,
			-- so RELOAD and AMMO were off the bottom of a landscape phone.
			local function columnsAt(viewport: Vector2): number
				return Rail.columnsFor(
					MapUi.diameterFor(viewport.X, viewport.Y),
					MapUi.CONFIG.MINIMAP_TOP,
					Rail.floorFor(viewport, railBlockers(viewport))
				)
			end
			expect(columnsAt(LANDSCAPE)).to.equal(2)
			expect(columnsAt(PORTRAIT)).to.equal(2)
			expect(columnsAt(TALL_DESKTOP)).to.equal(1)
			expect(columnsAt(PLAY)).to.equal(1)
			expect(columnsAt(DESKTOP)).to.equal(1)
		end)

		it("keeps every rail button inside the viewport", function()
			local faults = {}
			for _, viewport in ipairs({ PORTRAIT, LANDSCAPE, TALL_DESKTOP, PLAY, DESKTOP }) do
				local x, y, w, h = railRect(viewport)
				if y + h > viewport.Y - Rail.CONFIG.MARGIN or x < 0 or x + w > viewport.X then
					table.insert(faults, string.format("%.0fx%.0f %d..%d", viewport.X, viewport.Y, y, y + h))
				end
			end
			expect(table.concat(faults, ", ")).to.equal("")
		end)

		it("is pixel-identical to before the fold at every desktop viewport", function()
			-- THE NO-REGRESSION CLAIM. `Rail.rect` with no floor is exactly the four numbers it
			-- always returned, and with the real floor a desktop answers the same.
			for _, viewport in ipairs({ TALL_DESKTOP, PLAY, DESKTOP }) do
				local diameter = MapUi.diameterFor(viewport.X, viewport.Y)
				local ax, ay, aw, ah = Rail.rect(viewport, diameter, MapUi.CONFIG.MINIMAP_TOP, #Rail.BUTTONS)
				local bx, by, bw, bh = railRect(viewport)
				expect(string.format("%d %d %d %d", ax, ay, aw, ah)).to.equal(
					string.format("%d %d %d %d", bx, by, bw, bh)
				)
			end
		end)

		it("reserves the column it actually occupies, and the old constant is columnPx(1)", function()
			expect(Rail.columnPx(1)).to.equal(MapUi.CONFIG.RAIL_COLUMN_PX)
			expect(Rail.columnPx(2)).to.equal(124)
			expect(Rail.widthFor(1)).to.equal(48)
			expect(Rail.widthFor(2)).to.equal(104)
			expect(Rail.heightFor(4, 1)).to.equal(216)
			expect(Rail.heightFor(4, 2)).to.equal(104)
			-- ...and the default is one column, so every caller written before the fold is unchanged.
			expect(Rail.heightFor(4)).to.equal(Rail.heightFor(4, 1))
		end)

		it("fills the column nearest the screen edge first", function()
			-- Top to bottom, then the next column to the LEFT -- so the column a right thumb
			-- reaches first is always the full one.
			local step = Rail.CONFIG.BUTTON_PX + Rail.CONFIG.GAP
			expect(string.format("%d,%d", Rail.slotFor(0, 2, 4))).to.equal(string.format("%d,%d", step, 0))
			expect(string.format("%d,%d", Rail.slotFor(1, 2, 4))).to.equal(string.format("%d,%d", step, step))
			expect(string.format("%d,%d", Rail.slotFor(2, 2, 4))).to.equal("0,0")
			expect(string.format("%d,%d", Rail.slotFor(3, 2, 4))).to.equal(string.format("%d,%d", 0, step))
			-- PACKED, NOT PARKED: two visible buttons in two columns is one row, not two.
			expect(string.format("%d,%d", Rail.slotFor(1, 2, 2))).to.equal("0,0")
		end)

		it("keeps the full map clear of a FOLDED rail", function()
			local clashes = {}
			for _, viewport in ipairs({ PORTRAIT, LANDSCAPE }) do
				local fx, fy, fw, fh = MapUi.fullMapRect(viewport, Rail.columnPx(2))
				local rx, ry, rw, rh = railRect(viewport)
				if rectsOverlap(fx, fy, fw, fh, rx, ry, rw, rh) then
					table.insert(clashes, string.format("%.0fx%.0f", viewport.X, viewport.Y))
				end
			end
			expect(table.concat(clashes, ", ")).to.equal("")
		end)
	end)

	describe("the bottom-right chip gets out of the way", function()
		it("reserves nothing at all when the cluster is not drawn", function()
			-- THE DESKTOP PROMISE: with `SHOW_ON_DESKTOP = false`, not one rectangle on Karen's HUD
			-- moves because of this task.
			for _, viewport in ipairs({ PLAY, DESKTOP }) do
				local rx, ry = Touch.reserved(viewport, false, Hud.leftStackRight(viewport))
				expect(rx).to.equal(0)
				expect(ry).to.equal(0)
			end
		end)

		it("reserves the design's two pairs when it is", function()
			local lx, ly = Touch.reserved(LANDSCAPE, true, Hud.leftStackRight(LANDSCAPE))
			expect(string.format("%d,%d", lx, ly)).to.equal("144,168")
			local px, py = Touch.reserved(PORTRAIT, true, Hud.leftStackRight(PORTRAIT))
			expect(string.format("%d,%d", px, py)).to.equal("0,312")
		end)

		it("puts the chip where the arithmetic says, live", function()
			-- THE CEILING IS A MEASUREMENT AND NOT A GUESS: the chip is `AutomaticSize.X`, so the
			-- overlap argument above is only conservative if the real chip never exceeds it.
			local chip = Hud.ammoChip()
			expect(chip).to.be.ok()
			local box = chip :: Frame
			if box.Visible then
				expect(box.AbsoluteSize.X <= Hud.CORNER.MAX_WIDTH_PX).to.equal(true)
			end
			local hornChip = Hud.hornChip()
			if hornChip ~= nil and (hornChip :: Frame).Visible then
				expect((hornChip :: Frame).AbsoluteSize.X <= Hud.CORNER.MAX_WIDTH_PX).to.equal(true)
			end
		end)
	end)

	describe("the keep-outs", function()
		it("reads the real TouchGui only on a touch device, and says so when it did not", function()
			-- A CASE THAT SILENTLY SKIPS IS A FALSE-PASS PATH. `Touch.CONFIG.JUMP` and
			-- `.THUMBSTICK` are OUR rectangles -- Roblox states the two zones and publishes no size
			-- for either -- so on a real phone this is where they stop being a guess. On this
			-- desktop gate the branch below does NOT run, and the request says so.
			if not UserInputService.TouchEnabled then
				TestKit.note(
					"[touch] TouchEnabled is FALSE on this client: the TouchGui branch did NOT run, "
						.. "so Touch.CONFIG.JUMP and .THUMBSTICK are still OUR unverified rectangles. "
						.. "A person must open Studio -> Test -> Device to measure them."
				)
				expect(UserInputService.TouchEnabled).to.equal(false)
				return
			end
			local touchGui = player:FindFirstChild("PlayerGui")
			touchGui = if touchGui ~= nil then touchGui:FindFirstChild("TouchGui") else nil
			expect(touchGui).to.be.ok()
			local viewport = workspace.CurrentCamera.ViewportSize
			local jx, jy, jw, jh = Touch.jumpKeepOut(viewport)
			local sx, sy, sw, sh = Touch.thumbstickKeepOut(viewport)
			local outside = {}
			for _, node in ipairs((touchGui :: Instance):GetDescendants()) do
				if node:IsA("GuiButton") or node:IsA("ImageLabel") then
					local gui = node :: GuiObject
					if gui.Visible and gui.AbsoluteSize.X > 0 then
						local p0, size = gui.AbsolutePosition, gui.AbsoluteSize
						local inJump = p0.X >= jx
							and p0.Y >= jy
							and p0.X + size.X <= jx + jw
							and p0.Y + size.Y <= jy + jh
						local inStick = p0.X >= sx
							and p0.Y >= sy
							and p0.X + size.X <= sx + sw
							and p0.Y + size.Y <= sy + sh
						if not inJump and not inStick then
							table.insert(outside, gui.Name)
						end
					end
				end
			end
			expect(table.concat(outside, ", ")).to.equal("")
		end)
	end)
end
