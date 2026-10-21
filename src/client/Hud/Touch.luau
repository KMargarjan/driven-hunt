--!strict
-- Hud.Touch: THE ONE WRITER of the touch action cluster -- its four buttons, their `Visible`,
-- their position inside its frame, and their `Activated` connections.
--
-- KAREN's v1 plan, 2026-10-11, confirmed *"continue"* 2026-10-19: *"world: ... MOBILE controls"*.
-- Most Roblox players are on phones. The HUD half was already built (`Hud.Rail`, task 165, and the
-- Designer's phone step); THE INPUT is what was missing. A touch player could move, look and jump,
-- and could reload and change shell from the rail -- but had NO WAY TO FIRE, no way to aim, no way
-- to change weapon except the stock hotbar, and no way to blow a horn except a bare screen tap.
--
-- A SIBLING OF THE RAIL AND NOT MORE RAIL, and the reason is REACH rather than tidiness. Roblox's
-- own layout page: *"A button placed 40% below the screen's top edge is reachable on a phone but
-- almost unreachable on a tablet"*, and *"A reliable approach on both phones and tablets is
-- relative positioning of custom buttons near frequently-used controls like the default jump
-- button"*. The rail is the top-right column under the minimap; a TRIGGER belongs under the thumb,
-- beside the jump button. Two groups, two reach budgets, two owners.
--
-- EVERY BUTTON IS A SECOND DOOR ONTO A FUNCTION THAT ALREADY EXISTS -- `Hud.Rail`'s rule, and the
-- whole of this module's authority. It fires no remote, equips nothing and holds no rule:
-- `Weapon.Input.fire`, `Input.toggleAim`, `Input.swap` and `Input.blowHorn` do the work, and the
-- MOUSE AND THE KEYS RUN THE SAME FUNCTIONS. There is exactly ONE firer of `FireRequest` in this
-- client and the touch door has nothing to drift from, which a spec asserts by IDENTITY
-- (`Touch.actionFor("FIRE") == Weapon.Input.fire`) rather than by behaviour.
--
-- ZERO NEW REMOTES, and that is bought by two engine facts MEASURED in a live DEV session on
-- 2026-10-21 rather than remembered (`reviews/task-220/BRIEF.md` section 0):
--   M1  `tool:Activate()` from a LocalScript fires the SERVER's `Tool.Activated` -- so BLOW is a
--       second door onto the connection `Weapon.Horn.grant` already makes. This is exactly what
--       `Rail`'s header refused to guess at in task 165: *"there is no client function to call, so
--       a horn button would need a new remote -- refused for this task"*. Now there is one.
--   M2  `Humanoid:EquipTool()` from a LocalScript moves the Tool on the server -- so SWAP is too.
--
-- NO INTERACT BUTTON, AND THAT IS ALSO A MEASUREMENT (M3): `ProximityPrompt.ClickablePrompt`
-- defaults to TRUE and `Lobby.Build.shopPrompt` never sets it, so the shopkeeper's prompt is
-- already tappable. A second door onto a door that is already open is a dead button.
--
-- IT IS NOT ITS OWN SCREEN. `Hud.build` creates the `TouchCluster` frame with the rest of the HUD;
-- this module fills it and writes nothing outside it -- the `Compass` / `MapUi` / `Rail` shape.
-- It requires `Style` and nothing else: it never requires `script.Parent` (a cycle) and never reads
-- `Weapon`, `MapUi` or `Camera`. It is TOLD.
--
--   TextButton  https://create.roblox.com/docs/reference/engine/classes/TextButton
--   GuiButton.Activated  https://create.roblox.com/docs/reference/engine/classes/GuiButton#Activated
--     one event for a click AND a tap, which is why this module needs no touch branch at all.
--   Position and size UI objects  https://create.roblox.com/docs/ui/position-and-size
--     the two control zones, and the 20 px its own sample puts between a custom button and jump.
--   WCAG 2.2 SC 2.5.5  https://www.w3.org/TR/WCAG22/#target-size-enhanced
--     *"The target size is at least 44 by 44"*. The smallest button here is 56.
--
-- Design: docs/design/mobile-controls.md
-- Note:   docs/research/2026-10-20-mobile-controls.md
local TweenService = game:GetService("TweenService")
-- THE ONE SOURCE for every colour, face and size on these buttons (task 201, the Designer's design
-- system): the rail's ghost slate, borrowed whole, with two one-line departures (FIRE's rim is
-- BLAZE, and AIM wears the hover paint while the camera is aiming).
local Style = require(script.Parent.Style)

local Touch = {}

export type Button = {
	id: string,
	label: string,
	px: number,
	slot: string,
	needs: string,
}

Touch.CONFIG = {
	FIRE_PX = 88,
	AIM_PX = 64,
	SWAP_PX = 56,
	BLOW_PX = 72,
	GAP = 8,
	MARGIN = Style.MARGIN,
	-- THE TWO KEEP-OUTS ARE OURS, AND THEY ARE A GUESS WITH A COMMENT ON IT. Roblox states that
	-- *"the default controls occupy a portion of the bottom-left and bottom-right corners"* and
	-- gives NO rectangle for either, so these are our constants -- built from two numbers each so a
	-- remeasurement moves two numbers and nothing else. The engine's jump button is visibly larger
	-- than this repo's 48 px rail button and is inset from both edges; the dynamic thumbstick's ring
	-- is larger again.
	--
	-- UNVERIFIED AGAINST A LIVE `TouchGui` (design section 13.5): the harness has no Device Emulator
	-- command, so a PERSON must open Test -> Device, and `touch_controls.spec` carries a case that
	-- reads the real control frames when `TouchEnabled` is true and SAYS IN ITS OWN NAME when it did
	-- not run. A keep-out nobody measured is a guess; one nobody admits is guessing is worse.
	JUMP = { BUTTON_PX = 120, INSET_PX = 20 },
	THUMBSTICK = { RING_PX = 160, INSET_PX = 20 },
	-- Source A's own code sample places a custom button 20 px to the left of the jump button.
	JUMP_CLEAR_PX = 20,
	-- ABOVE EVERY FIELD SURFACE (<= 9) AND BELOW THE SCOPE'S MASK (11-13), every modal panel (15)
	-- and the rail (16). Deliberately below the rail: on a phone the rail is the only way to CLOSE a
	-- panel and must never lose to a trigger.
	Z_INDEX = 10,
	-- SHIPPED FALSE, AND THE RAIL'S THREE REASONS DO NOT SURVIVE THE MOVE TO THE BOTTOM-RIGHT.
	-- Karen ASKED for the rail (*"could be buttons on the side for M - map ect"*) and never asked
	-- for a trigger button, so a FIRE square over the world on the one machine she plays on is
	-- clutter she did not request. It would also MOVE HER AMMO CHIP: `Touch.reserved` is keyed on
	-- `shown`, so a desktop cluster drags the chip 144 px left and 168 px up on a screen whose owner
	-- cannot use the buttons; at `false`, `reserved` is (0, 0) and nothing on a desktop HUD moves at
	-- all. And the rail's third reason -- *"the only route to any live evidence at all"* -- is
	-- answered differently here: `Touch.press` gates on `suppressed` / `covered` and NOT on
	-- `touchEnabled`, so every live claim runs on a desktop with the cluster hidden.
	--
	-- Both states are reachable BY PARAMETER (`Touch.shown(touchEnabled, showOnDesktop)`), so one
	-- spec drives both worlds while this constant sits at one of them. One boolean for Karen.
	SHOW_ON_DESKTOP = false,
	LABEL_STEP = "LABEL",
	BACKGROUND = Style.LOOK.SLATE,
	TRANSPARENCY = Style.SLATE_QUIET_T,
	RIM_COLOR = Style.LOOK.LINE,
	RIM_TRANSPARENCY = Style.EDGE_T.GHOST,
	HOVER_TRANSPARENCY = 0,
	HOVER_RIM_COLOR = Style.LOOK.BRASS,
	HOVER_RIM_TRANSPARENCY = Style.EDGE_T.SLATE,
	PRESSED_COLOR = Style.LOOK.ROW_HOVER,
	TEXT_COLOR = Style.LOOK.FIELD_MUTED,
	HOVER_TEXT_COLOR = Style.LOOK.PAPER,
	-- §1.1 of the design system: *"Blaze = act / go here"*. A trigger is the act, and it is the one
	-- button a thumb must find without reading.
	FIRE_RIM_COLOR = Style.LOOK.BLAZE,
}

-- THE FOUR BUTTONS AND THEIR FIXED SLOTS. `needs` is the condition that draws one at all -- the
-- rail's `needsWeapon` rule generalised, and the same promise: no dead buttons.
--
-- THE SLOTS ARE FIXED AND A HIDDEN BUTTON LEAVES ITS SLOT EMPTY. This is the one place this module
-- refuses `Rail.applyVisibility`'s *"PACKED, NOT PARKED"*: a rail button is a menu item and a
-- trigger is MUSCLE MEMORY. `docs/PROJECT_CONTEXT.md` names *"a marker wandering the screen"* among
-- the bugs that killed the previous project, and a FIRE button that slides 72 px left the moment a
-- second gun is picked up is that bug with a finger on it.
Touch.BUTTONS = {
	{ id = "FIRE", label = "FIRE", px = 88, slot = "bottom-right", needs = "weapon" },
	{ id = "AIM", label = "AIM", px = 64, slot = "top-right", needs = "weapon" },
	{ id = "SWAP", label = "SWAP", px = 56, slot = "top-left", needs = "two" },
	{ id = "BLOW", label = "BLOW", px = 72, slot = "bottom-left", needs = "horn" },
} :: { Button }

-- ---------------------------------------------------------------- the arithmetic, pure

-- WIDE ENOUGH FOR BOTH COLUMNS, TALL ENOUGH FOR BOTH ROWS -- and INDEPENDENT of how many buttons
-- are showing, which is what lets the chip above it stand still too.
function Touch.clusterSize(): (number, number)
	local config = Touch.CONFIG
	local left = math.max(config.SWAP_PX, config.BLOW_PX)
	local right = math.max(config.AIM_PX, config.FIRE_PX)
	-- EACH COLUMN IS STACKED FROM THE CLUSTER'S BOTTOM EDGE, so its height is its own two buttons
	-- and the gap -- and the cluster is as tall as the taller column. Computed per column rather
	-- than as max(top) + max(bottom), which happens to give the same 160 today and would not if a
	-- button ever changed size.
	local leftTall = config.BLOW_PX + config.GAP + config.SWAP_PX
	local rightTall = config.FIRE_PX + config.GAP + config.AIM_PX
	return left + config.GAP + right, math.max(leftTall, rightTall)
end

function Touch.shown(touchEnabled: boolean, showOnDesktop: boolean?): boolean
	local onDesktop = if showOnDesktop == nil then Touch.CONFIG.SHOW_ON_DESKTOP else showOnDesktop
	return touchEnabled or onDesktop == true
end

-- THREE RULES, THREE QUESTIONS, and they are independent on purpose -- `Rail.applyVisibility`'s own
-- arrangement, for its reason: *"a sight picture and an open shop can be true independently, and
-- whichever ends first must not turn the rail back on while the other still holds it down"*.
function Touch.visible(touchEnabled: boolean, suppressed_: boolean, covered_: boolean, showOnDesktop: boolean?): boolean
	return Touch.shown(touchEnabled, showOnDesktop) and not suppressed_ and not covered_
end

-- IS THERE A FUNCTION BEHIND THIS BUTTON RIGHT NOW? Told, never read -- the Hud already reads the
-- weapon state for the rail and the chip, so there is one reader of it and this module learns
-- nothing about weapons or horns.
function Touch.buttonVisible(button: Button, hasWeapon: boolean, carried: number, hasHorn: boolean): boolean
	if button.needs == "weapon" then
		return hasWeapon
	elseif button.needs == "two" then
		return carried >= 2
	elseif button.needs == "horn" then
		return hasHorn
	end
	return true
end

-- THE TWO CONTROL ZONES, as rectangles: x, y, width, height.
function Touch.jumpKeepOut(viewport: Vector2): (number, number, number, number)
	local jump = Touch.CONFIG.JUMP
	local size = jump.BUTTON_PX + jump.INSET_PX
	return viewport.X - size, viewport.Y - size, size, size
end

function Touch.thumbstickKeepOut(viewport: Vector2): (number, number, number, number)
	local stick = Touch.CONFIG.THUMBSTICK
	local size = stick.RING_PX + stick.INSET_PX
	return 0, viewport.Y - size, size, size
end

-- WHERE THE CLUSTER GOES: beside the jump button when the bottom band is wide enough for it, and
-- ABOVE the jump button when it is not. One rule, two answers.
--
-- `leftStackRightPx` is the right edge of the bottom-left stack the Hud owns (the toast feed and
-- the hit card). It is handed IN rather than read, because this module may not require the Hud.
--
-- AT 400 x 800 THERE IS NO ROOM AT ALL: between a 180 px thumbstick and a 140 px jump a 400 px
-- screen has 80 px of bottom band, and an 88 px FIRE does not fit in it. So portrait goes up.
function Touch.placement(viewport: Vector2, leftStackRightPx: number?): string
	local config = Touch.CONFIG
	local clusterWidth = Touch.clusterSize()
	local jumpSize = config.JUMP.BUTTON_PX + config.JUMP.INSET_PX
	local stickSize = config.THUMBSTICK.RING_PX + config.THUMBSTICK.INSET_PX
	local leftEdge = math.max(stickSize, leftStackRightPx or 0)
	local freeWidth = (viewport.X - jumpSize) - leftEdge
	return if freeWidth >= clusterWidth + config.JUMP_CLEAR_PX then "left-of-jump" else "above-jump"
end

-- THE CLUSTER'S RECTANGLE: x, y, width, height. PURE AND EXPORTED, for the reason `Rail.rect` and
-- `Objective.lineRect` are: the overlap cases measure `AbsolutePosition` at whatever size the Studio
-- window happens to be (969 x 784 in this task's own probe pass), and the claim Karen is being asked
-- to believe is about 800 x 400 and 400 x 800.
function Touch.rect(viewport: Vector2, leftStackRightPx: number?): (number, number, number, number)
	local config = Touch.CONFIG
	local width, height = Touch.clusterSize()
	local jumpSize = config.JUMP.BUTTON_PX + config.JUMP.INSET_PX
	if Touch.placement(viewport, leftStackRightPx) == "left-of-jump" then
		return viewport.X - (jumpSize + config.JUMP_CLEAR_PX) - width,
			viewport.Y - config.MARGIN - height,
			width,
			height
	end
	return viewport.X - config.MARGIN - width, viewport.Y - (jumpSize + config.JUMP_CLEAR_PX) - height, width, height
end

-- WHERE ONE BUTTON SITS INSIDE THE CLUSTER: x, y, in the cluster frame's own offsets. The two
-- columns are right-aligned to their own halves and the two rows share the cluster's bottom edge,
-- so FIRE's corner is the cluster's corner whatever the other three are doing.
function Touch.slotOffset(button: Button): (number, number)
	local config = Touch.CONFIG
	local width, height = Touch.clusterSize()
	local onLeft = button.slot == "top-left" or button.slot == "bottom-left"
	local onTop = button.slot == "top-left" or button.slot == "top-right"
	local leftWidth = math.max(config.SWAP_PX, config.BLOW_PX)
	-- RIGHT-ALIGNED IN ITS OWN COLUMN, so the two different sizes in a column share an edge and the
	-- cluster has no ragged right side against the screen edge.
	local x = if onLeft then leftWidth - button.px else width - button.px
	-- BOTTOM-STACKED: the bottom button sits on the cluster's bottom edge and the top one is one gap
	-- above it. FIRE's corner IS the cluster's corner, whatever the other three are doing.
	local below = if onLeft then config.BLOW_PX else config.FIRE_PX
	local y = if onTop then height - below - config.GAP - button.px else height - button.px
	return x, y
end

function Touch.buttonRect(id: string, viewport: Vector2, leftStackRightPx: number?): (number, number, number, number)
	for _, button in ipairs(Touch.BUTTONS) do
		if button.id == id then
			local x, y = Touch.rect(viewport, leftStackRightPx)
			local dx, dy = Touch.slotOffset(button)
			return x + dx, y + dy, button.px, button.px
		end
	end
	return 0, 0, 0, 0
end

-- HOW MUCH ROOM THE BOTTOM-RIGHT CORNER MUST GIVE UP: extra (right, bottom) inset for the ammo /
-- horn chip. `(0, 0)` when the cluster is not drawn, so a desktop HUD is bit-for-bit what it was.
--
-- THE CHIP MOVES UP AND LEFT RATHER THAN STRAIGHT UP (design D-220-1). Keeping it at `right 16` and
-- lifting it above the cluster would land it at x 584..784, y 170..216 at 800 x 400 -- and
-- `MapUi.minimapRect(800, 400)` is x 692..788, y 140..236. It would be drawn on the minimap. So its
-- bottom-right corner becomes the CLUSTER's top-right corner, 8 px above it.
--
-- `Hud.renderCorner` is still the one writer of the chip; this only answers how far to move it.
function Touch.reserved(viewport: Vector2, shown_: boolean, leftStackRightPx: number?): (number, number)
	if not shown_ then
		return 0, 0
	end
	local config = Touch.CONFIG
	local x, y, width = Touch.rect(viewport, leftStackRightPx)
	local rightInset = math.max(0, (viewport.X - (x + width)) - config.MARGIN)
	local bottomInset = math.max(0, (viewport.Y - y) + config.GAP - config.MARGIN)
	return rightInset, bottomInset
end

-- ---------------------------------------------------------------- state: one writer, this module

local frame: Frame? = nil
local nodes: { [string]: TextButton } = {}
local paints: { [string]: (string) -> () } = {}
local started = false
local hasWeapon = false
local carried = 0
local hasHorn = false
local aimOn = false
local suppressed = false
local covered = false
local touchEnabled = false
local layoutViewport: Vector2? = nil
local actions: { [string]: () -> any } = {}
local stats = { presses = 0, refused = 0, byId = {} :: { [string]: number } }

function Touch.stats()
	return stats
end

-- WHAT IS ACTUALLY ON SCREEN NOW, in slot order, for a spec.
function Touch.buttonIds(): { string }
	local ids = {}
	for _, button in ipairs(Touch.BUTTONS) do
		local node = nodes[button.id]
		if node ~= nil and node.Visible then
			table.insert(ids, button.id)
		end
	end
	return ids
end

function Touch.button(id: string): TextButton?
	return nodes[id]
end

-- THE FUNCTION THIS BUTTON CALLS, so a spec can assert ONE PATH BY IDENTITY rather than by
-- behaviour: `Touch.actionFor("FIRE") == Weapon.Input.fire` is a claim no amount of drift can
-- satisfy accidentally.
function Touch.actionFor(id: string): (() -> any)?
	return actions[id]
end

function Touch.isAimOn(): boolean
	return aimOn
end

function Touch.isSuppressed(): boolean
	return suppressed
end

function Touch.isCovered(): boolean
	return covered
end

-- THE ONE WRITER of every button's `Visible` and of the frame's own, and the one place the rules
-- meet: is the cluster on this device at all, is a sight picture up, is a panel drawn over it, and
-- does this button have a function to call right now.
function Touch.applyVisibility()
	local holder = frame
	if holder == nil then
		return
	end
	local box = holder :: Frame
	box.Visible = Touch.visible(touchEnabled, suppressed, covered)
	local on = box.Visible
	for _, button in ipairs(Touch.BUTTONS) do
		local node = nodes[button.id]
		if node ~= nil then
			node.Visible = on and Touch.buttonVisible(button, hasWeapon, carried, hasHorn)
		end
	end
end

-- WHERE THE CLUSTER IS, for this viewport. Edge-triggered, so a per-frame caller costs one
-- comparison and never a write.
function Touch.applyLayout(viewport: Vector2, leftStackRightPx: number?)
	local holder = frame
	if holder == nil then
		return
	end
	if layoutViewport == viewport then
		return
	end
	layoutViewport = viewport
	local box = holder :: Frame
	local width, height = Touch.clusterSize()
	local x, y = Touch.rect(viewport, leftStackRightPx)
	-- ANCHORED (0, 0) and positioned in plain offsets: the cluster's rectangle is the arithmetic's,
	-- not an anchor's interpretation of it, so `Touch.rect` and what is drawn cannot disagree.
	box.Position = UDim2.fromOffset(x, y)
	box.Size = UDim2.fromOffset(width, height)
end

function Touch.setWeapon(next_: boolean)
	if hasWeapon == next_ then
		return
	end
	hasWeapon = next_
	Touch.applyVisibility()
end

function Touch.setCarried(count: number)
	if carried == count then
		return
	end
	carried = count
	Touch.applyVisibility()
end

function Touch.setHorn(next_: boolean)
	if hasHorn == next_ then
		return
	end
	hasHorn = next_
	Touch.applyVisibility()
end

-- THE AIM BUTTON WEARS ITS STATE. A toggle with no visible state is the previous project's
-- *"marker wandering the screen"* in another costume.
--
-- IT IS TOLD THE CAMERA'S MODE AND NOT THE AIM FLAG, which is `Hud.render`'s own rule: the camera
-- is the STATE and the flag is the REQUEST, and a lit button over an unshouldered gun is a number
-- that measured right and looked wrong.
function Touch.setAiming(on: boolean)
	if aimOn == on then
		return
	end
	aimOn = on
	local paint = paints.AIM
	if paint ~= nil then
		paint(if on then "hover" else "idle")
	end
end

function Touch.setSuppressed(on: boolean)
	if suppressed == on then
		return
	end
	suppressed = on
	Touch.applyVisibility()
end

function Touch.setCovered(on: boolean)
	if covered == on then
		return
	end
	covered = on
	Touch.applyVisibility()
end

-- THE NAMED HANDLER EVERY BUTTON CALLS, public on purpose: a spec cannot fire `GuiButton.Activated`
-- and the harness cannot synthesise a tap, so this is the only seam that makes the cluster testable
-- at all -- and what it proves is the ACTION, not the touch. That limit is reported, not papered
-- over (design section 13.4).
--
-- IT DIFFERS FROM `Rail.press` IN ONE WAY, DELIBERATELY: it refuses while suppressed or covered.
-- `Rail.press` does not, and must not -- MAP and REPORT are toggles and a spec drives them while
-- the rail is hidden. FIRE is a SHOT. The full map does not request an `Input` hold (the shop, the
-- report and the pad dialog do), so without this check a tap through an open map would fire the
-- gun.
--
-- Returns whether an action ran, so a spec can tell "pressed and did nothing" from "no such
-- button".
function Touch.press(id: string): boolean
	if suppressed or covered then
		stats.refused += 1
		return false
	end
	local action = actions[id]
	if action == nil then
		return false
	end
	stats.presses += 1
	stats.byId[id] = (stats.byId[id] or 0) + 1
	local ok, result = pcall(action)
	if not ok then
		-- A BUTTON MUST NOT TAKE THE HUD DOWN WITH IT (`Rail.press`'s rule). A warning is louder
		-- than a silent nothing and quieter than a broken render loop.
		warn(string.format("[Touch] %s failed: %s", id, tostring(result)))
		return false
	end
	-- Only an explicit `false` means "refused" (the hold, or nothing to swap to).
	return result ~= false
end

-- `collaborators` are the modules this cluster calls, each optional: a missing one means that
-- button is not built, which is the same rule as `needs` -- no dead buttons.
function Touch.start(frame_: Frame, collaborators: { Input: any?, touchEnabled: boolean? })
	if started then
		return
	end
	started = true
	frame = frame_
	touchEnabled = collaborators.touchEnabled == true

	local Input = collaborators.Input
	actions = {}
	if Input ~= nil then
		if type(Input.fire) == "function" then
			actions.FIRE = Input.fire
		end
		if type(Input.toggleAim) == "function" then
			actions.AIM = Input.toggleAim
		end
		if type(Input.swap) == "function" then
			actions.SWAP = Input.swap
		end
		if type(Input.blowHorn) == "function" then
			actions.BLOW = Input.blowHorn
		end
	end

	local config = Touch.CONFIG
	local viewportX = Style.viewportX()
	table.clear(nodes)
	table.clear(paints)
	for _, button in ipairs(Touch.BUTTONS) do
		if actions[button.id] == nil then
			continue
		end
		local node = Instance.new("TextButton")
		node.Name = button.id
		node.Size = UDim2.fromOffset(button.px, button.px)
		local slotX, slotY = Touch.slotOffset(button)
		node.Position = UDim2.fromOffset(slotX, slotY)
		node.BackgroundColor3 = config.BACKGROUND
		node.BackgroundTransparency = config.TRANSPARENCY
		node.BorderSizePixel = 0
		-- `AutoButtonColor` OFF, the rail's rule: the engine's own darken-on-press would wash the
		-- three named states below.
		node.AutoButtonColor = false
		-- THE WORD IS A CHILD LABEL AND THE BUTTON ITSELF SAYS NOTHING, so a pressed state can nudge
		-- it 1 px down without moving the slate it sits on.
		node.Text = ""
		node.ZIndex = config.Z_INDEX
		node.Visible = false
		Style.corner(node, Style.RADIUS.ROW)
		-- `Border` AND NOT THE DEFAULT: `ApplyStrokeMode` defaults to `Contextual`, which on a
		-- TextButton outlines the TEXT, and this stroke is the button's rim (`MapUi`'s lesson).
		local rimColor = if button.id == "FIRE" then config.FIRE_RIM_COLOR else config.RIM_COLOR
		local rim = Style.stroke(node, rimColor, config.RIM_TRANSPARENCY)
		rim.Name = "Rim"

		local word = Instance.new("TextLabel")
		word.Name = "Label"
		word.BackgroundTransparency = 1
		word.BorderSizePixel = 0
		word.FontFace = Style.FONT.SANS_SEMI
		word.TextScaled = false
		word.TextWrapped = false
		word.TextSize = Style.sizeFor(config.LABEL_STEP, viewportX)
		word.TextColor3 = config.TEXT_COLOR
		word.Text = button.label
		word.AnchorPoint = Vector2.new(0.5, 0.5)
		word.Position = UDim2.fromScale(0.5, 0.5)
		word.Size = UDim2.new(1, -6, 0, Style.sizeFor(config.LABEL_STEP, viewportX) + 4)
		word.ZIndex = config.Z_INDEX + 1
		word.Parent = node

		-- THE THREE STATES, from `MouseEnter` / `MouseLeave` and `MouseButton1Down` /
		-- `MouseButton1Up` -- which a `TextButton` fires for a finger as well as for a mouse. The
		-- colour tween is the design system's one permitted motion (0.12 s Quad Out), and
		-- `Activated` is still the only thing that RUNS anything.
		local idleRim = rimColor
		local function paint(state: string)
			local fill = if state == "press" then config.PRESSED_COLOR else config.BACKGROUND
			local fillT = if state == "idle" then config.TRANSPARENCY else config.HOVER_TRANSPARENCY
			local edge = if state == "idle" then idleRim else config.HOVER_RIM_COLOR
			local edgeT = if state == "idle" then config.RIM_TRANSPARENCY else config.HOVER_RIM_TRANSPARENCY
			local text = if state == "idle" then config.TEXT_COLOR else config.HOVER_TEXT_COLOR
			TweenService:Create(
				node,
				TweenInfo.new(Style.MOTION.HOVER, Style.MOTION.EASE_OUT, Enum.EasingDirection.Out),
				{ BackgroundColor3 = fill, BackgroundTransparency = fillT }
			):Play()
			rim.Color = edge
			rim.Transparency = edgeT
			word.TextColor3 = text
			word.Position = UDim2.new(0.5, 0, 0.5, if state == "press" then 1 else 0)
		end
		paints[button.id] = paint

		node.MouseEnter:Connect(function()
			paint("hover")
		end)
		node.MouseLeave:Connect(function()
			-- AIM KEEPS ITS LIT STATE when the camera is aiming: it is a TOGGLE, and a toggle that
			-- goes dark the moment the pointer leaves it is a toggle nobody can read.
			paint(if button.id == "AIM" and aimOn then "hover" else "idle")
		end)
		node.MouseButton1Down:Connect(function()
			paint("press")
		end)
		node.MouseButton1Up:Connect(function()
			-- A TAP ENDS ON A DEVICE WITH NO POINTER (the rail's measured rule): on touch there is
			-- no `MouseLeave` after `MouseButton1Up`, so painting the hover state here would leave a
			-- thumbed button lit for the rest of the session.
			if touchEnabled then
				paint(if button.id == "AIM" and aimOn then "hover" else "idle")
				return
			end
			paint("hover")
		end)

		local id = button.id
		node.Activated:Connect(function()
			Touch.press(id)
		end)
		node.Parent = frame_
		nodes[id] = node
	end
	Touch.applyVisibility()
end

return Touch
