--!strict
-- Hud.Rail: THE ONE WRITER of the button rail on the right edge -- its buttons' text, their
-- `Visible` and their `Activated` connections.
--
-- KAREN, 2026-10-12: *"could be buttons on the side for M - map ect"*, and she wants mobile in v1.
--
-- WHY A RAIL AND NOT A SECOND LONE BUTTON. Roblox's own UI-design curriculum, quoted in the research
-- note: *"If you group UI elements from different categories together throughout the screen, players
-- won't know where to look for what they need. To assist players in navigating your game, group UI
-- elements from the same category together."* So the map's touch button stops being a circle under
-- the minimap and becomes the FIRST BUTTON OF ONE COLUMN, and everything a thumb can press lives in
-- that column. The old button is removed rather than left behind (design 7.2 item 1): a
-- `buttonVisible` with no caller is dead code pretending to be an owner.
--
-- EVERY BUTTON IS A SECOND DOOR ONTO A FUNCTION THAT ALREADY EXISTS, and that is the whole of this
-- module's authority. It toggles nothing itself, fires no remote and holds no rule: `MapUi.toggle`,
-- `ReportPanel.toggle`, `Weapon.Input.reload` and `Weapon.Input.selectAmmo` do the work, and each is
-- the one implementation the KEY also runs. A button with no function behind it is not built --
-- which is the dispatch's *"only real actions, no dead buttons"* turned into a pure predicate
-- (`Rail.buttonVisible`) rather than a comment.
--
-- NO HORN BUTTON, AND THE REASON IS NAMED. A blast is `Weapon.Horn.blowTool`, which is the SERVER's;
-- there is no client function to call, so a horn button would need a new remote -- refused for this
-- task (design D3, 6.1). Queued instead.
--
-- IT IS NOT ITS OWN SCREEN. `Hud.build` creates the `Rail` frame with the rest of the HUD; this
-- module fills it and writes nothing outside it -- the `Compass` / `MapUi` / `ReportPanel` shape.
--
-- IT IS THE ONE NODE IN THIS HUD DRAWN OVER THE CENTRED PANELS, and that is deliberate: on a touch
-- device the REPORT button is the only way to CLOSE the report panel, and the MAP button the only way
-- to close the map. Everything else about those panels is unchanged.
--
--   TextButton  https://create.roblox.com/docs/reference/engine/classes/TextButton
--   GuiButton.Activated  https://create.roblox.com/docs/reference/engine/classes/GuiButton#Activated
--     one event for a click AND a tap, which is why the rail needs no touch branch at all.
--   UISizeConstraint  https://create.roblox.com/docs/ui/size-modifiers
--     Roblox's own tutorial caps a touch button at 44 px of height; 48 clears it.
--
-- Design: docs/design/hud-clarity.md (section 6)
-- Note:   docs/research/2026-10-12-hud-clarity.md, docs/research/2026-10-17-one-design-system.md
local TweenService = game:GetService("TweenService")
-- THE ONE SOURCE for every colour, face and size on this column (task 201, the Designer's design
-- system, 2026-10-17). Surface 5: *"Flat `#101214` squares -> ghost slates, corner 11, `LINE`
-- stroke. Label `LABEL` SemiBold `FIELD_MUTED`; key hint `MICRO` Bold `BRASS` spaced, on its own
-- line. Hover and press states, which do not exist today. `SHOW_ON_DESKTOP` and `buttonVisible` are
-- unchanged."*
local Style = require(script.Parent.Style)

local Rail = {}

export type Button = {
	id: string,
	label: string,
	key: string,
	needsWeapon: boolean,
}

Rail.CONFIG = {
	-- 48 OVER THE 44 Roblox's own tutorial sets as a touch button's maximum height, and the number
	-- `MapUi.CONFIG.BUTTON_PX` already used for the button this rail replaces.
	BUTTON_PX = 48,
	GAP = 8,
	-- The minimap's own right margin, so the rail and the disc share one edge line.
	MARGIN = 12,
	-- EIGHT PIXELS UNDER THE MINIMAP. The rail's top is computed from the minimap's RENDERED diameter
	-- (`Rail.topFor`), not from a constant, because that diameter is 150 on a screen and 96 on a phone
	-- (`MapUi.diameterFor`) -- a fixed top would either overlap the disc or leave a hole.
	TOP_GAP = 8,
	-- HOW MANY COLUMNS THIS RAIL MAY FOLD INTO (task 220). One, until the viewport cannot hold one.
	-- MEASURED, and this is why it is 2 rather than a shrunken gap: at 800 x 400 -- a landscape
	-- phone, which is how phones play -- the free right-edge column under the minimap is y 236..384,
	-- which is 148 px, and four 48 px buttons are 192 px with NO gaps at all. Shrinking the gap
	-- cannot save it. Before this, `topFor(96, 140)` + `heightFor(4)` put the rail's bottom at
	-- **460** on a 400 px screen, so RELOAD and AMMO were simply off the bottom of the phone. (The
	-- brief's 510 is the same arithmetic at the DESKTOP step's 150 px minimap, `topFor(150, 136)`,
	-- which is what a landscape phone renders at today -- `Style.isPhone` is keyed on WIDTH. Both
	-- are off a 400 px screen; 460 is the one this file's own constants produce.)
	MAX_COLUMNS = 2,
	LABEL_SIZE = 11,
	KEY_SIZE = 9,
	-- A GHOST CONTROL OVER THE WORLD IS A QUIET SLATE (the system §3.5 "Ghost"): the charcoal every
	-- field surface uses, at the 9-11 px transparency, with a `LINE` edge at 0.35 instead of the old
	-- near-white rim. Hover lifts the slate to opaque and turns the edge brass; press darkens it and
	-- nudges both labels 1 px down -- three states that did not exist at all before task 201.
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
	KEY_COLOR = Style.LOOK.BRASS, -- §3.5: a key hint is `MICRO` Bold BRASS, letter-spaced
	-- OVER THE CENTRED PANELS (`Report.CONFIG.PANEL_Z_INDEX` is 15), for the reason in the header.
	Z_INDEX = 16,
	-- SHIPPED TRUE, AND THREE REASONS. Karen asked for the buttons and plays on a PC, so a touch-only
	-- rail is a feature she can never see (which is exactly what happened to the map's old button --
	-- it was `touchEnabled and BUTTON_ENABLED`, so it never once appeared in her sessions, and
	-- "could be buttons on the side" is her asking for a button that was already written); the key
	-- hints make the rail a legend for the keyboard as well as a target for a thumb; and a
	-- `TextButton` is clickable with a real mouse, which is the only route to any live evidence at
	-- all. One boolean for Karen to turn off.
	SHOW_ON_DESKTOP = true,
}

-- THE ORDER THEY ARE DRAWN IN, top to bottom. `label` is ASCII and at most 6 characters so it fits a
-- 48 px button; `key` is the hint under it; `needsWeapon` is what makes a button disappear instead of
-- becoming dead.
Rail.BUTTONS = {
	{ id = "MAP", label = "MAP", key = "M", needsWeapon = false },
	{ id = "REPORT", label = "REPORT", key = "TAB", needsWeapon = false },
	{ id = "RELOAD", label = "RELOAD", key = "R", needsWeapon = true },
	{ id = "AMMO", label = "AMMO", key = "X", needsWeapon = true },
} :: { Button }

-- ---------------------------------------------------------------- the arithmetic, pure

function Rail.visible(touchEnabled: boolean): boolean
	return touchEnabled or Rail.CONFIG.SHOW_ON_DESKTOP
end

-- A WEAPON BUTTON IS NOT DRAWN WITHOUT A WEAPON. `hasWeapon` is TOLD to this module by the Hud
-- (`Rail.setWeapon`), never read here: the Hud already reads `Weapon.get().equipped` for the ammo
-- readout, so there is one reader of the weapon state in the Hud and the rail learns nothing about
-- weapons.
function Rail.buttonVisible(button: Button, hasWeapon: boolean): boolean
	if button.needsWeapon then
		return hasWeapon
	end
	return true
end

-- WHERE THE COLUMN STARTS, from the minimap's rendered diameter.
function Rail.topFor(minimapDiameterPx: number, minimapTopPx: number): number
	return minimapTopPx + minimapDiameterPx + Rail.CONFIG.TOP_GAP
end

-- HOW MANY ROWS A GIVEN NUMBER OF BUTTONS NEEDS IN A GIVEN NUMBER OF COLUMNS.
local function rowsFor(count: number, columns: number): number
	if count <= 0 then
		return 0
	end
	return math.ceil(count / math.max(1, columns))
end

-- HOW TALL THE WHOLE BLOCK IS, for however many buttons are showing and however many columns they
-- are folded into. `columns` is optional and defaults to 1, so every caller written before task 220
-- -- and every existing case in `hud_clarity.spec` -- gets the same answer it always got.
function Rail.heightFor(count: number, columns: number?): number
	local config = Rail.CONFIG
	local rows = rowsFor(count, columns or 1)
	if rows <= 0 then
		return 0
	end
	return rows * config.BUTTON_PX + (rows - 1) * config.GAP
end

-- HOW WIDE IT IS, which used to be one button and now depends on the fold.
function Rail.widthFor(columns: number): number
	local config = Rail.CONFIG
	local n = math.max(1, columns)
	return n * config.BUTTON_PX + (n - 1) * config.GAP
end

-- THE WHOLE COLUMN THE REST OF THE HUD MUST KEEP OUT OF (the design system 4.3 rule 2): the
-- buttons, their right margin and 8 px of air. `MapUi.CONFIG.RAIL_COLUMN_PX` is `columnPx(1)`, and
-- `MapUi` is TOLD this number now rather than holding its own copy (`MapUi.setRailColumn`), so a
-- folded rail actually reserves the width it occupies instead of letting the full map run under it.
function Rail.columnPx(columns: number): number
	return Rail.widthFor(columns) + Rail.CONFIG.MARGIN + Rail.CONFIG.TOP_GAP
end

-- WHERE A GIVEN VISIBLE BUTTON SITS INSIDE THE FRAME: x, y, in the frame's own offsets.
--
-- `index` is 0-based AMONG THE VISIBLE BUTTONS, which is what keeps `applyVisibility`'s *"PACKED,
-- NOT PARKED"* rule true through the fold: a hidden RELOAD must not leave a 48 px hole. Filling is
-- top-to-bottom and then the NEXT COLUMN TO THE LEFT, so the column nearest the screen edge -- the
-- one a right thumb reaches first -- is always the one that is full.
--
-- IT TAKES `count` as well as `columns` (a small deviation from the design's two-argument
-- signature, section 5.6): how many rows there are depends on how many buttons are SHOWING, and two
-- visible buttons in two columns is one row, not two.
function Rail.slotFor(index: number, columns: number, count: number): (number, number)
	local config = Rail.CONFIG
	local n = math.max(1, columns)
	local rows = math.max(1, rowsFor(count, n))
	local column = math.floor(index / rows)
	local row = index % rows
	-- COLUMN 0 IS THE RIGHTMOST one, because the frame is anchored to the right edge.
	return (n - 1 - column) * (config.BUTTON_PX + config.GAP), row * (config.BUTTON_PX + config.GAP)
end

-- HOW FAR DOWN THE SCREEN THE RAIL MAY REACH. The bottom margin, raised above anything already
-- drawn in the column the rail would occupy -- today the ammo / horn chip and the touch cluster,
-- both handed in as rectangles so this function reads nothing and stays pure.
--
-- THE WORST-CASE COLUMN IS USED (`columnPx(MAX_COLUMNS)`), deliberately: the floor is an input to
-- the decision about how many columns there are, so it must not depend on that decision.
function Rail.floorFor(viewport: Vector2, blockers: { { x: number, y: number, w: number, h: number } }?): number
	local config = Rail.CONFIG
	local floorY = viewport.Y - config.MARGIN
	local columnLeft = viewport.X - Rail.columnPx(config.MAX_COLUMNS)
	for _, box in ipairs(blockers or {}) do
		if box.x + box.w > columnLeft and box.x < viewport.X and box.y - config.GAP < floorY then
			floorY = box.y - config.GAP
		end
	end
	return floorY
end

-- THE FEWEST COLUMNS THE WHOLE RAIL FITS IN, or `MAX_COLUMNS` when it fits in none of them.
--
-- `#Rail.BUTTONS` AND NOT THE VISIBLE COUNT, on purpose: the column this rail reserves must not
-- change width the moment a player picks up a gun, or the full map would jump sideways under him.
--
-- IT TAKES NO VIEWPORT, which is a deviation from the design's four-argument signature (section
-- 5.6): the viewport decides only how far DOWN the rail may reach, and that is already `floorY`.
-- A parameter nothing reads is a parameter that will one day be passed wrong.
function Rail.columnsFor(minimapDiameterPx: number, minimapTopPx: number, floorY: number): number
	local top = Rail.topFor(minimapDiameterPx, minimapTopPx)
	for columns = 1, Rail.CONFIG.MAX_COLUMNS do
		if top + Rail.heightFor(#Rail.BUTTONS, columns) <= floorY then
			return columns
		end
	end
	return Rail.CONFIG.MAX_COLUMNS
end

-- THE WHOLE LAYOUT IN ONE PURE ANSWER: x, y, width, height, columns.
function Rail.layoutFor(
	viewport: Vector2,
	minimapDiameterPx: number,
	minimapTopPx: number,
	count: number,
	floorY: number?
): (number, number, number, number, number)
	local config = Rail.CONFIG
	local columns = if floorY == nil then 1 else Rail.columnsFor(minimapDiameterPx, minimapTopPx, floorY :: number)
	local width = Rail.widthFor(columns)
	return viewport.X - config.MARGIN - width,
		Rail.topFor(minimapDiameterPx, minimapTopPx),
		width,
		Rail.heightFor(count, columns),
		columns
end

-- THE COLUMN'S RECTANGLE: x, y, width, height. PURE AND EXPORTED, for the reason
-- `Objective.lineRect` is: the existing overlap case measures `AbsolutePosition` at whatever size the
-- Studio window happens to be, and the claim Karen is being asked to believe is about 400 x 800.
--
-- `floorY` IS OPTIONAL AND nil IS TODAY'S ANSWER (task 220): one column, one button wide, exactly
-- the four numbers this function has always returned. Pass the floor and it folds.
function Rail.rect(
	viewport: Vector2,
	minimapDiameterPx: number,
	minimapTopPx: number,
	count: number,
	floorY: number?
): (number, number, number, number)
	local x, y, w, h = Rail.layoutFor(viewport, minimapDiameterPx, minimapTopPx, count, floorY)
	return x, y, w, h
end

-- ---------------------------------------------------------------- state: one writer, this module

local frame: Frame? = nil
local nodes: { [string]: TextButton } = {}
-- THE FOLD THIS RAIL IS CURRENTLY DRAWN AT (task 220), written only by `Rail.applyLayout` and read
-- only by `Rail.applyVisibility`. One until something tells it otherwise, so a world that never
-- calls `applyLayout` is pixel-identical to the rail before this task.
local layoutColumns = 1
local layoutViewport: Vector2? = nil
local started = false
local hasWeapon = false
local suppressed = false
-- IS SOMETHING DRAWN OVER THE RAIL? (task 196, review round 1, finding 1.) On a phone the shop panel
-- is the whole screen and this column sits on top of it. It is a SECOND reason to be hidden and NOT
-- the same one as `suppressed`: a sight picture and an open shop can be true independently, and
-- whichever ends first must not turn the rail back on while the other still holds it down.
--
-- WHY IT IS A FLAG HERE AND NOT A WRITE THERE: part 3f had the Hud write `railFrame.Visible` every
-- frame from the shop's answer, which made a second writer of this frame -- and because it wrote
-- `true` whenever the shop was shut, the first frame after a scope went up turned four buttons back
-- on INSIDE the eyepiece, which is the picture `Hud.renderScope` exists to prevent. It also beat
-- `Rail.visible(touchEnabled)`, which is Karen's `SHOW_ON_DESKTOP`.
local covered = false
local touchEnabled = false
local actions: { [string]: () -> any } = {}
local stats = { presses = 0, byId = {} :: { [string]: number } }

function Rail.stats()
	return stats
end

-- WHAT IS ACTUALLY ON SCREEN NOW, in rail order, for a spec.
function Rail.buttonIds(): { string }
	local ids = {}
	for _, button in ipairs(Rail.BUTTONS) do
		local node = nodes[button.id]
		if node ~= nil and node.Visible then
			table.insert(ids, button.id)
		end
	end
	return ids
end

function Rail.button(id: string): TextButton?
	return nodes[id]
end

function Rail.isSuppressed(): boolean
	return suppressed
end

function Rail.isCovered(): boolean
	return covered
end

-- THE ONE WRITER of every button's `Visible`, and the one place the two rules meet: is the rail on
-- this device at all, and does this button have a function to call right now.
function Rail.applyVisibility()
	local holder = frame
	if holder == nil then
		return
	end
	local box = holder :: Frame
	-- A LOCAL AND NOT `(holder :: Frame).Visible`: a line that STARTS with an open bracket is read as
	-- a call on the line above it, which is Luau's one real syntax trap.
	-- THE THREE RULES MEET HERE AND NOWHERE ELSE: is the rail on this device at all, is a sight
	-- picture up, and is a panel drawn over it.
	box.Visible = Rail.visible(touchEnabled) and not suppressed and not covered
	local on = box.Visible
	local index = 0
	local visible = 0
	for _, button in ipairs(Rail.BUTTONS) do
		local node = nodes[button.id]
		if node == nil then
			continue
		end
		local show = on and Rail.buttonVisible(button, hasWeapon)
		node.Visible = show
		if show then
			visible += 1
		end
	end
	-- PACKED, NOT PARKED. A hidden RELOAD must not leave a 48 px hole in the middle of the column,
	-- so the buttons that ARE drawn are laid out in order -- down the rightmost column first, then
	-- the next one to its left (`Rail.slotFor`). TWO PASSES SINCE TASK 220, because a slot's row
	-- depends on how many buttons are showing in total, which the first pass is what counts.
	for _, button in ipairs(Rail.BUTTONS) do
		local node = nodes[button.id]
		if node ~= nil and node.Visible then
			local slotX, slotY = Rail.slotFor(index, layoutColumns, visible)
			node.Position = UDim2.fromOffset(slotX, slotY)
			index += 1
		end
	end
	box.Size = UDim2.fromOffset(Rail.widthFor(layoutColumns), Rail.heightFor(index, layoutColumns))
end

-- THE ONE WRITER OF THIS FRAME'S POSITION, AND OF THE FOLD (task 220). `MapUi.applyLayout` used to
-- write `rail.Position` from its own copy of `MINIMAP_TOP + diameter + 8`; those three lines are
-- gone (`backups/2026-10-21_mapui-rail-position.md`) and this is where they live now. That is a
-- SECOND WRITER REMOVED rather than one added: the clamp cannot live in two places, and the module
-- that owns the rail is the one that must decide how many columns it has.
--
-- Returns the columns it settled on, so the caller can tell `MapUi` what to reserve without
-- recomputing it.
function Rail.applyLayout(viewport: Vector2, minimapDiameterPx: number, minimapTopPx: number, floorY: number?): number
	local holder = frame
	local _x, y, _w, _h, columns = Rail.layoutFor(viewport, minimapDiameterPx, minimapTopPx, #Rail.BUTTONS, floorY)
	if holder == nil then
		-- 220a(d): THE ANSWER IS RECORDED EVEN WITH NO FRAME. It used to return `columns` and leave
		-- `layoutColumns` at 1, so a world with no rail told `MapUi` to reserve 124 px while
		-- `Rail.columns()` still said 1 -- two readings of one fact, which is the shape of defect
		-- `docs/PROJECT_CONTEXT.md` opens with. `layoutViewport` is deliberately NOT written here,
		-- so the edge trigger below still fires the first time a frame exists.
		layoutColumns = columns
		return columns
	end
	local box = holder :: Frame
	-- EDGE-TRIGGERED on everything that can move it, so a per-frame caller costs comparisons and
	-- never a write -- `Rail.setCovered`'s own discipline.
	if layoutColumns ~= columns or layoutViewport ~= viewport then
		layoutColumns = columns
		layoutViewport = viewport
		-- The frame is anchored (1, 0), so this offset is where its RIGHT edge goes: the margin,
		-- whatever the fold. `MapUi.CONFIG.MINIMAP_MARGIN` is the same 12, which is why the disc and
		-- the column have always shared one edge line.
		box.Position = UDim2.new(1, -Rail.CONFIG.MARGIN, 0, y)
		Rail.applyVisibility()
	end
	return columns
end

-- WHAT THE RAIL IS FOLDED TO RIGHT NOW, for a spec.
function Rail.columns(): number
	return layoutColumns
end

function Rail.setWeapon(next_: boolean)
	if hasWeapon == next_ then
		return
	end
	hasWeapon = next_
	Rail.applyVisibility()
end

-- The sight picture is in: a need stated by `Hud.renderScope`, performed here -- the
-- `MapUi.setSuppressed` shape, so this module stays the one writer of its own nodes.
function Rail.setSuppressed(on: boolean)
	if suppressed == on then
		return
	end
	suppressed = on
	Rail.applyVisibility()
end

-- A PANEL IS DRAWN OVER THE RAIL, OR IS NOT (task 196 review round 1). The caller states a NEED and
-- this module does the writing -- the `MapUi.setSuppressed` / `Cursor.requestFree` shape this file
-- already uses one function up, and for the same reason: one frame, one writer.
--
-- EDGE-TRIGGERED like its neighbour, so a per-frame caller costs one comparison and never a write.
function Rail.setCovered(on: boolean)
	if covered == on then
		return
	end
	covered = on
	Rail.applyVisibility()
end

-- THE NAMED HANDLER EVERY BUTTON CALLS, and it is public on purpose. `Hud.onHitMarker`'s own header
-- gives the reason: *"a named function rather than an inline closure, so a client spec can drive
-- exactly the code path the wire drives"*. A spec cannot fire `GuiButton.Activated` and the harness
-- cannot synthesise a tap (design 10.4), so this is the seam that makes the rail testable at all --
-- and what it proves is the ACTION, not the touch. That limit is reported, not papered over.
--
-- Returns whether an action ran, so a spec can tell "pressed and did nothing" from "no such button".
function Rail.press(id: string): boolean
	local action = actions[id]
	if action == nil then
		return false
	end
	stats.presses += 1
	stats.byId[id] = (stats.byId[id] or 0) + 1
	local ok, result = pcall(action)
	if not ok then
		-- A BUTTON MUST NOT TAKE THE HUD DOWN WITH IT. `MapUi.toggle` and `ReportPanel.toggle` return
		-- nothing and cannot fail; `Input.reload` fires a remote. A warning is louder than a silent
		-- nothing and quieter than a broken render loop.
		warn(string.format("[Rail] %s failed: %s", id, tostring(result)))
		return false
	end
	-- `MapUi.toggle` returns nil and still ran; only an explicit `false` means "refused" (the hold).
	return result ~= false
end

-- `collaborators` are the modules the rail calls, each optional: a missing one means that button is
-- not built, which is the same rule as `needsWeapon` -- no dead buttons.
function Rail.start(
	holder: Frame,
	collaborators: {
		Map: any?,
		Report: any?,
		Input: any?,
		touchEnabled: boolean?,
	}
)
	if started then
		return
	end
	started = true
	frame = holder
	touchEnabled = collaborators.touchEnabled == true

	local Map, ReportUi, Input = collaborators.Map, collaborators.Report, collaborators.Input
	actions = {}
	if Map ~= nil and type(Map.toggle) == "function" then
		actions.MAP = function()
			Map.toggle()
			return true
		end
	end
	if ReportUi ~= nil and type(ReportUi.toggle) == "function" then
		actions.REPORT = function()
			ReportUi.toggle()
			return true
		end
	end
	if Input ~= nil and type(Input.reload) == "function" then
		actions.RELOAD = Input.reload
	end
	if Input ~= nil and type(Input.selectAmmo) == "function" then
		actions.AMMO = Input.selectAmmo
	end

	local config = Rail.CONFIG
	table.clear(nodes)
	for _, button in ipairs(Rail.BUTTONS) do
		if actions[button.id] == nil then
			continue
		end
		local node = Instance.new("TextButton")
		node.Name = button.id
		node.Size = UDim2.fromOffset(config.BUTTON_PX, config.BUTTON_PX)
		node.Position = UDim2.fromOffset(0, 0)
		node.BackgroundColor3 = config.BACKGROUND
		node.BackgroundTransparency = config.TRANSPARENCY
		node.BorderSizePixel = 0
		-- `AutoButtonColor` OFF SINCE TASK 201. The engine's own darken-on-press fights the three
		-- states below -- it would wash the hover's brass edge and the pressed fill both -- and the
		-- design asks for named states and not for a tint the engine picks.
		node.AutoButtonColor = false
		-- THE WORDS ARE CHILD LABELS AND THE BUTTON ITSELF SAYS NOTHING (§3.5), so the pressed state
		-- can nudge them 1 px down without moving the slate they sit on.
		node.Text = ""
		node.ZIndex = config.Z_INDEX
		node.Visible = false
		Style.corner(node, Style.RADIUS.ROW)
		-- `Border` AND NOT THE DEFAULT, which is `MapUi`'s own lesson: `ApplyStrokeMode` defaults to
		-- `Contextual`, which on a TextButton outlines the TEXT, and this stroke is the button's rim.
		local rim = Style.stroke(node, config.RIM_COLOR, config.RIM_TRANSPARENCY)
		rim.Name = "Rim"

		local word = Instance.new("TextLabel")
		word.Name = "Label"
		word.BackgroundTransparency = 1
		word.BorderSizePixel = 0
		word.FontFace = Style.FONT.SANS_SEMI
		word.TextScaled = false
		word.TextWrapped = false
		word.TextSize = config.LABEL_SIZE
		word.TextColor3 = config.TEXT_COLOR
		word.Text = button.label
		word.AnchorPoint = Vector2.new(0.5, 0)
		word.Position = UDim2.new(0.5, 0, 0, 10)
		word.Size = UDim2.new(1, -6, 0, config.LABEL_SIZE + 3)
		word.ZIndex = config.Z_INDEX + 1
		word.Parent = node

		-- The key hint, under the word: a legend for the keyboard and a label for the thumb.
		local hint = Instance.new("TextLabel")
		hint.Name = "Key"
		hint.BackgroundTransparency = 1
		hint.BorderSizePixel = 0
		hint.FontFace = Style.FONT.SANS_BOLD
		hint.TextScaled = false
		hint.TextWrapped = false
		hint.TextSize = config.KEY_SIZE
		hint.TextColor3 = config.KEY_COLOR
		-- LETTER-SPACED, because it is 9 px and uppercase (§1.2: `spaced()` at 11 px and smaller).
		hint.Text = Style.spaced(button.key)
		hint.AnchorPoint = Vector2.new(0.5, 1)
		hint.Position = UDim2.new(0.5, 0, 1, -8)
		hint.Size = UDim2.new(1, -4, 0, config.KEY_SIZE + 2)
		hint.ZIndex = config.Z_INDEX + 1
		hint.Parent = node

		-- THE THREE STATES (§3.5), drawn from `MouseEnter` / `MouseLeave` and
		-- `MouseButton1Down` / `MouseButton1Up` -- which a `TextButton` fires for a finger as well
		-- as for a mouse. The colour tween is the system's one permitted motion (§1.4, 0.12 s
		-- Quad Out), and `Activated` is still the only thing that RUNS anything.
		--
		-- A TAP ENDS ON A DEVICE WITH NO POINTER (round 1 note): on touch there is no `MouseLeave`
		-- after `MouseButton1Up`, so painting the hover state there would leave a thumbed button lit
		-- for the rest of the session. On touch the release goes back to IDLE; on a desktop the
		-- pointer really is still over the button, so it goes to hover.
		local function paint(fill: Color3, fillT: number, edge: Color3, edgeT: number, text: Color3, drop: number)
			TweenService:Create(
				node,
				TweenInfo.new(Style.MOTION.HOVER, Style.MOTION.EASE_OUT, Enum.EasingDirection.Out),
				{ BackgroundColor3 = fill, BackgroundTransparency = fillT }
			):Play()
			rim.Color = edge
			rim.Transparency = edgeT
			word.TextColor3 = text
			word.Position = UDim2.new(0.5, 0, 0, 10 + drop)
			hint.Position = UDim2.new(0.5, 0, 1, -8 + drop)
		end
		node.MouseEnter:Connect(function()
			paint(
				config.BACKGROUND,
				config.HOVER_TRANSPARENCY,
				config.HOVER_RIM_COLOR,
				config.HOVER_RIM_TRANSPARENCY,
				config.HOVER_TEXT_COLOR,
				0
			)
		end)
		node.MouseLeave:Connect(function()
			paint(
				config.BACKGROUND,
				config.TRANSPARENCY,
				config.RIM_COLOR,
				config.RIM_TRANSPARENCY,
				config.TEXT_COLOR,
				0
			)
		end)
		node.MouseButton1Down:Connect(function()
			paint(
				config.PRESSED_COLOR,
				0,
				config.HOVER_RIM_COLOR,
				config.HOVER_RIM_TRANSPARENCY,
				config.HOVER_TEXT_COLOR,
				1
			)
		end)
		node.MouseButton1Up:Connect(function()
			if touchEnabled then
				paint(
					config.BACKGROUND,
					config.TRANSPARENCY,
					config.RIM_COLOR,
					config.RIM_TRANSPARENCY,
					config.TEXT_COLOR,
					0
				)
				return
			end
			paint(
				config.BACKGROUND,
				config.HOVER_TRANSPARENCY,
				config.HOVER_RIM_COLOR,
				config.HOVER_RIM_TRANSPARENCY,
				config.HOVER_TEXT_COLOR,
				0
			)
		end)

		local id = button.id
		node.Activated:Connect(function()
			Rail.press(id)
		end)
		node.Parent = holder
		nodes[id] = node
	end
	Rail.applyVisibility()
end

return Rail
