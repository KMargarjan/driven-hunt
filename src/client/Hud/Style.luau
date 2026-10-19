--!strict
-- Hud.Style: THE ONE SOURCE for every colour, face, size, radius, stroke and duration the game
-- draws with (CLAUDE.md rule 3 applied to the look: one owner, one answer).
--
-- KAREN, 2026-10-17 ~12:30: *"all menus all information (timer  what to shoot who you are ect. )
-- has to be same design as menu colors loading ect again ask designer to fallow on this / we need
-- one unified design system and colours and style across all game"*.
--
-- THE DESIGNER'S DESIGN SYSTEM, 2026-10-17 is the spec for this file and for every surface that
-- reads it. Section 1 is the whole of what is below -- `§1.1` the palette, `§1.2` the faces and the
-- size scale, `§1.3` the spacing, the radius ladder, the strokes and the four over-the-world
-- opacities, `§1.4` the motion -- and section 3 is the six constructors at the bottom. Section 6
-- task A is this file; nothing on screen changes by creating it.
--
-- WHY IT EXISTS AT ALL, in the repo's own words: *"A second copy of a hex is a second answer to
-- 'what colour is blaze orange' -- this repo's named failure mode"* (`docs/PROJECT_CONTEXT.md`:
-- *"Most of the worst bugs were two correct pieces of code disagreeing"*). `ShopPanel.LOOK`,
-- `ShopPanel.FONT` and `ShopPanel.spaced` were that one source for the shop and the pad dialog
-- since task 197; they MOVE here unchanged in value, and `ShopPanel` keeps thin aliases so the shop
-- and the pad look exactly as `196-shop-desktop.png` and `t197d-dialog.png` already do. That is the
-- check for task A: a frame of each, side by side, with nothing different.
--
-- TWO SURFACE FAMILIES, ONE PALETTE (the system's §0.2). A *lodge* surface is an opaque panel over
-- a scrim -- the shop, the pad dialog, the report, the full map. A *field* surface is a **slate**:
-- the same charcoal at 82 % opacity, carrying every word drawn over the 3-D world. NOTHING FLOATS
-- ON THE WORLD NAKED, and no label over the world wears a black `UIStroke` ever again (§2): an
-- outline thickens every letter, halves the apparent size of 11 px type, and still fails over a
-- bright sky because the outline itself is only 1 px. The slate was MEASURED instead -- every type
-- colour here clears 4.5 : 1 against the six worst grounds this game produces, the tightest being
-- `BLAZE_HI` at 4.66 over a bright sky, which is why blaze over the world is used at 14 px and up.
--
--   UICorner    https://create.roblox.com/docs/reference/engine/classes/UICorner
--   UIStroke    https://create.roblox.com/docs/reference/engine/classes/UIStroke
--   UIGradient  https://create.roblox.com/docs/reference/engine/classes/UIGradient
--   UIPadding   https://create.roblox.com/docs/reference/engine/classes/UIPadding
--   UIListLayout  https://create.roblox.com/docs/reference/engine/classes/UIListLayout
--   Font.new    https://create.roblox.com/docs/reference/engine/datatypes/Font
--
-- Design: docs/design/shop.md (section 5), the Designer's design system, 2026-10-17
-- Note:   docs/research/2026-10-17-one-design-system.md
local Style = {}

-- ---------------------------------------------------------------- §1.2 the two faces
--
-- OSWALD (condensed) FOR A TITLE, A NAME AND EVERY NUMBER; BUILDERSANS FOR EVERY SENTENCE, BUTTON
-- WORD, COLUMN HEAD AND LABEL. Nothing else. The shop proved the pair; this only widens it to the
-- whole game, and `Enum.Font.Code` leaves with it.
Style.FONT = {
	OSWALD_SB = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.SemiBold),
	OSWALD_MD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Medium),
	SANS_BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	SANS_SEMI = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.SemiBold),
	SANS_REG = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Regular),
}

-- "WEAPONS" -> "W E A P O N S". Roblox `TextLabel` has no tracking property, so the system's
-- letter-spaced micro-labels are drawn with a plain space between the letters. ONLY for uppercase
-- strings at 11 px or smaller: at 12 px and above a full space is too wide (§1.2).
function Style.spaced(text: string): string
	return (string.gsub(string.gsub(text, "(.)", "%1 "), "%s+$", ""))
end

-- THE EXACT INVERSE OF `Style.spaced`, and it is a function rather than a `gsub` because the naive
-- one is WRONG: `spaced("NEXT DRIVE IN")` puts a space after EVERY character, the original space
-- included, so stripping every space gives "NEXTDRIVEIN". `spaced` writes the string at the odd
-- positions, so this reads them back.
function Style.unspaced(text: string): string
	local out = {}
	for index = 1, #text, 2 do
		table.insert(out, string.sub(text, index, index))
	end
	return table.concat(out)
end

-- ---------------------------------------------------------------- §1.1 the palette
--
-- ONE MEANING PER COLOUR. Blaze = act / go here. Pine = already true. Amber = later / holding.
-- Clay = harm or refusal. Brass = money. Blaze = hunters, pewter blue = beaters, and those two
-- appear ONLY as a team mark -- green is never a team colour, because green already means
-- "already true" and a roster is the one screen where both meanings would appear at once.
Style.LOOK = {
	-- surfaces
	SCRIM = Color3.fromHex("0A0907"),
	PANEL = Color3.fromHex("1C1915"),
	COLUMN = Color3.fromHex("191612"),
	HEADER_TOP = Color3.fromHex("2A251D"),
	HEADER_BOTTOM = Color3.fromHex("211D17"),
	ROW = Color3.fromHex("26221C"),
	ROW_HOVER = Color3.fromHex("2E2922"),
	ROW_LOCKED = Color3.fromHex("221E18"),
	ROW_SELECTED = Color3.fromHex("16261B"),
	CASE_TOP = Color3.fromHex("262019"),
	CASE_MID = Color3.fromHex("15120F"),
	CASE_FLOOR = Color3.fromHex("0C0A08"),
	-- NEW (§1.1): every over-the-world backing panel. One colour, two transparencies -- `SLATE_T`
	-- for 12 px type and larger, `SLATE_QUIET_T` for the 9-11 px of a compass band or a rail button.
	SLATE = Color3.fromHex("14110E"),
	-- lines
	BLAZE = Color3.fromHex("D2661B"),
	BLAZE_HI = Color3.fromHex("E8832F"),
	BLAZE_LO = Color3.fromHex("A94E12"),
	BLAZE_EDGE = Color3.fromHex("8E3F0C"),
	BUY_TOP = Color3.fromHex("E07324"),
	BUY_MID = Color3.fromHex("C25C15"),
	PINE = Color3.fromHex("2F6B3E"),
	PINE_TEXT = Color3.fromHex("8FD39C"),
	PINE_DARK = Color3.fromHex("1B2A20"),
	BRASS = Color3.fromHex("C8A258"),
	BRASS_HI = Color3.fromHex("F0D79A"),
	BRASS_LO = Color3.fromHex("8E6F30"),
	COIN_TEXT = Color3.fromHex("E2C488"),
	AMBER = Color3.fromHex("D9A95F"),
	AMBER_BAR = Color3.fromHex("A8853F"),
	AMBER_DARK = Color3.fromHex("241F18"),
	CLAY = Color3.fromHex("E7917F"),
	CLAY_EDGE = Color3.fromHex("C8604E"),
	CLAY_DARK = Color3.fromHex("2A1E1B"),
	-- type
	PAPER = Color3.fromHex("F2EBDC"),
	BODY = Color3.fromHex("D5CCBB"),
	MUTED = Color3.fromHex("9A9282"),
	FAINT = Color3.fromHex("6B655B"),
	-- NEW (§1.1 / §2): the secondary colour ON A FIELD SLATE. `MUTED` measures 4.11 : 1 over a
	-- bright sky and is therefore BANNED over the world; this measures 5.51 : 1. `FAINT` (2.20) is
	-- banned over the world outright. Both stay legal on an opaque lodge panel.
	FIELD_MUTED = Color3.fromHex("B3AA98"),
	LINE = Color3.fromHex("443C31"),
	WELL_EDGE = Color3.fromHex("322C24"),
	SOON_FILL = Color3.fromHex("232120"),
	BUTTON_TEXT = Color3.fromHex("FFF4E4"),
	HIGHLIGHT = Color3.fromHex("FFD696"),
	-- NEW (§1.1): the two sides, and nothing else is ever coloured by team. A driven hunt's
	-- shooters wear blaze orange, so the hunters ARE the game's own colour; the beaters are the one
	-- cool hue in the system, desaturated into the lodge's light rather than sitting on top of it,
	-- which is exactly what makes "the other team" read at a glance.
	HUNTER = Color3.fromHex("E8832F"),
	BEATER = Color3.fromHex("79A7C4"),
	-- How long a refusal or a receipt stays in a panel's status line. A line you caused by pressing
	-- a button does not stay on the screen for the rest of the session.
	MESSAGE_SECONDS = 4,
	-- *"Nothing in the UI moves except a 0.12 s colour tween on hover and press"* -- kept as a
	-- `LOOK` key because `ShopPanel` has read it from there since task 197. `Style.MOTION.HOVER` is
	-- the same number and the two are tied together below.
	HOVER_SECONDS = 0.12,
}

local LOOK = Style.LOOK

-- ---------------------------------------------------------------- §1.3 depth: the four opacities
--
-- OVER-THE-WORLD OPACITY, MEASURED AND NOT CHOSEN (§2). A slate over the six worst grounds this
-- game makes must keep every type colour above 4.5 : 1. If the lighting pass ends up brighter than
-- `#B4CFE4`, the ONE knob is this number, and §2's table still holds with room.
--
-- 0.14 SINCE TASK 215, ON THE DIRECTOR'S INSTRUCTION, AND THE MEASUREMENT DID NOT ASK FOR IT --
-- which is written here because the next person to read this line will otherwise assume it did.
-- The lighting spec's §6 makes the change CONDITIONAL: *"If Karen measures the sky and it is at or
-- under `#B4CFE4`, leave the slate at 0.18. The 0.14 is insurance, not an improvement."* The sky
-- was measured, off 82,945 pixels of real sky in two Forest Test frames with `AUTUMN_LIGHT` on
-- (`<runs-dir>/t215/measure.py`): the brightest patch is **`#94B9D3`, luma 176.9** -- DARKER than
-- the `#B4CFE4` (201.3) that §2 already tested, and darker than the same frames without the flag
-- (`#ACBECC`, 186.2). The new lighting makes the sky dimmer, not brighter, so §6's trigger is not
-- met.
--
-- It is 0.14 anyway because the Director asked for it and it is strictly safer: over §2's own
-- tested `#B4CFE4` the tightest colour, `BLAZE_HI`, goes from **4.66 : 1 to 5.18 : 1**, and every
-- other colour gains with it. Reverting it is this one line.
Style.SLATE_T = 0.14
Style.SLATE_QUIET_T = 0.08 -- a surface holding 9-11 px type: the compass band, a rail button
Style.CARD_T = 0.06 -- a floating card: the hit card, the start card, the results board
Style.PANEL_T = 0 -- a modal panel
Style.SCRIM_T = 0.42 -- the full-screen scrim behind any modal

-- Stroke transparencies. ALWAYS `Thickness = 1`, ALWAYS `ApplyStrokeMode = Border` -- the default
-- is `Contextual`, which on a TextButton outlines the TEXT (`MapUi`'s own lesson, and `Rail`'s).
Style.EDGE_T = {
	PANEL = 0.74,
	CARD = 0.42,
	SLATE = 0.55,
	WELL = 0.15,
	GHOST = 0.35,
}

-- ---------------------------------------------------------------- §1.3 the radius ladder
--
-- A THING THAT SITS ON ANOTHER THING IS ONE STEP LIGHTER AND ONE STEP LESS ROUND.
Style.RADIUS = {
	MODAL = 16,
	CARD = 14,
	WELL = 13,
	ROW = 11, -- a row, a chip, a FIELD SLATE, an icon button, a toast
	CHIP = 8, -- a stat chip, a small pill
	TAG = 5,
	BAR = 3, -- a progress bar
}

-- §1.3 spacing scale: 4 8 12 16 20 24 32, and nothing between the steps.
Style.SPACE = { XS = 4, S = 8, M = 12, L = 16, XL = 20, XXL = 24, HUGE = 32 }
-- Screen safe margin, all four sides, desktop and phone.
Style.MARGIN = 16

-- ---------------------------------------------------------------- §1.4 motion
--
-- NOTHING ELSE MOVES. No pulsing, no bouncing, no sliding panels: a HUD that moves is a HUD you
-- cannot read while aiming. A progress or countdown bar has NO tween at all -- it is a clock, and a
-- bar that eases is a bar that lies.
Style.MOTION = {
	HOVER = 0.12,
	IN = 0.16, -- a panel or card appearing: fade + 8 px rise
	IN_RISE_PX = 8,
	OUT = 0.12, -- leaving: fade, no movement
	TOAST_IN = 0.18,
	TOAST_RISE_PX = 10,
	TOAST_HOLD = 4.0,
	TOAST_OUT = 0.6,
	EASE_IN = Enum.EasingStyle.Quad,
	EASE_OUT = Enum.EasingStyle.Quad,
}

-- ---------------------------------------------------------------- §1.2 the size scale
--
-- `TextScaled` IS BANNED. Every label states its `TextSize` from this scale and sets
-- `TextTruncate = AtEnd` where a string can run long.
--
-- ONE BREAK POINT IN THE WHOLE GAME, and it is the one `Objective.CONFIG.SMALL_BELOW_PX` already
-- uses, so "is this a phone" has exactly one answer.
Style.PHONE_BELOW_PX = 700

Style.SIZE = {
	DISPLAY = { 28, 24 },
	TITLE = { 22, 20 },
	STAT = { 20, 17 },
	HEADING = { 17, 16 },
	BODY = { 14, 13 },
	LABEL = { 12, 11 },
	MICRO = { 10, 9 },
}

-- Desktop at or above the break point, phone below it. An unknown step is a programming error and
-- says so rather than silently drawing 14 px.
function Style.sizeFor(step: string, viewportX: number): number
	local pair = Style.SIZE[step]
	if pair == nil then
		error(string.format("[Style] no such size step: %s", tostring(step)), 2)
	end
	return if viewportX < Style.PHONE_BELOW_PX then pair[2] else pair[1]
end

-- A VIEWPORT THAT HAS NOT RENDERED YET IS NOT A PHONE. `Camera.ViewportSize` is **(1, 1)** until
-- the engine has drawn a frame, and a HUD built before that comes out at the phone step --
-- measured twice: task 201 part 1 built a 120 px compass that way, and part 2's report panel built
-- 24 px rows on a 969 px screen because it had its own ungated reader. ONE reader, here, so there
-- is one answer and one place to fix it.
Style.MIN_SENSIBLE_PX = 200

function Style.viewportX(): number
	local camera = workspace.CurrentCamera
	if camera == nil then
		return 1280
	end
	local size = camera.ViewportSize
	return if size.X >= Style.MIN_SENSIBLE_PX then size.X else 1280
end

-- Is this viewport a phone? One reader of the break point, for a caller that needs the branch
-- rather than the number (a padding, a line count, whether a chip is dropped).
function Style.isPhone(viewportX: number): boolean
	return viewportX < Style.PHONE_BELOW_PX
end

-- ---------------------------------------------------------------- the primitives
--
-- Four one-line helpers, because every constructor below needs them and a `UICorner` typed out
-- forty times is forty chances to type 12 where the ladder says 11.

function Style.corner(parent: GuiObject, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

function Style.stroke(parent: GuiObject, color: Color3, transparency: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Parent = parent
	return stroke
end

function Style.padding(parent: GuiObject, top: number, bottom: number, left: number, right: number): UIPadding
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, top)
	pad.PaddingBottom = UDim.new(0, bottom)
	pad.PaddingLeft = UDim.new(0, left)
	pad.PaddingRight = UDim.new(0, right)
	pad.Parent = parent
	return pad
end

-- A `TextLabel` from the scale: the one place a face, a size and a colour are set together, so a
-- label cannot be built at 14 px Oswald in `MUTED` over the world by accident.
--
-- `TextWrapped = false` AND `TextScaled = false` ON EVERY ONE OF THEM. A label in a chip that wraps
-- stacks one letter per line, which is what drawing the phone mockup found the hard way.
function Style.label(parent: GuiObject, name: string, step: string, viewportX: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.BorderSizePixel = 0
	text.TextScaled = false
	text.TextWrapped = false
	text.TextSize = Style.sizeFor(step, viewportX)
	text.FontFace = Style.faceFor(step)
	text.TextColor3 = LOOK.PAPER
	text.ZIndex = parent.ZIndex + 1
	text.Text = ""
	text.Parent = parent
	return text
end

-- WHICH FAMILY A STEP IS DRAWN IN (§1.2): Oswald for a title, a name and every number; BuilderSans
-- for every sentence, button word, column head and label.
function Style.faceFor(step: string): Font
	if step == "DISPLAY" or step == "TITLE" or step == "STAT" then
		return Style.FONT.OSWALD_SB
	elseif step == "HEADING" then
		return Style.FONT.OSWALD_MD
	elseif step == "BODY" then
		return Style.FONT.SANS_REG
	elseif step == "LABEL" then
		return Style.FONT.SANS_SEMI
	end
	return Style.FONT.SANS_BOLD -- MICRO: an eyebrow, a caption, a key hint, a tag
end

-- ---------------------------------------------------------------- §3 the six constructors
--
-- EVERY ONE OF THEM IS AN EXACT BUILD from section 3 of the system, and every label of a surface
-- sits at `ZIndex + 1` or above -- `src/client/Hud/init.luau` has paid for that rule twice (task
-- 159: *"the panel reads, the words do not"*).

-- §3.1 a modal panel: opaque, corner 16, one brass hairline at 0.74.
function Style.panel(parent: Instance, name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = LOOK.PANEL
	frame.BackgroundTransparency = Style.PANEL_T
	frame.BorderSizePixel = 0
	Style.corner(frame, Style.RADIUS.MODAL)
	Style.stroke(frame, LOOK.BRASS, Style.EDGE_T.PANEL)
	frame.Parent = parent
	return frame
end

-- HOW MUCH OF A CARD ITS OWN PADDING EATS (§3.2: *"UIPadding 12 all round (10 on a phone)"*).
-- ONE SOURCE, because round 1's second blocking finding was a surface measured WITHOUT it:
-- `Hud.boardHeight` returned `header + rows + footer` for a card whose content box is 24 px
-- shorter than that, so the footer -- pinned to the bottom of the PADDED box -- drew its countdown
-- across the last row of the table.
function Style.cardInset(viewportX: number): number
	return if Style.isPhone(viewportX) then 10 else 12
end

-- §3.2 a floating card over the world: the hit card, the start card, the results board.
function Style.card(parent: Instance, name: string, phone: boolean?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = LOOK.PANEL
	frame.BackgroundTransparency = Style.CARD_T
	frame.BorderSizePixel = 0
	Style.corner(frame, Style.RADIUS.CARD)
	Style.stroke(frame, LOOK.BRASS, Style.EDGE_T.CARD)
	-- `cardInset` IS THE ONE SOURCE, and this takes the step from the same boolean it is handed.
	local inset = if phone then Style.cardInset(1) else Style.cardInset(Style.PHONE_BELOW_PX)
	Style.padding(frame, inset, inset, inset, inset)
	frame.Parent = parent
	return frame
end

-- §3.3 A SLATE: the one thing that carries a word over the 3-D world. `quiet` is the 9-11 px
-- variant (the compass band, a rail button) at `SLATE_QUIET_T`.
--
-- IT IS NEVER FULL-BLEED ACROSS THE SCREEN: a band that touches both edges is a letterbox, and
-- this game is played in first person. The caller gives it `AutomaticSize` where it may be the size
-- of its text and nothing more.
function Style.slate(parent: Instance, name: string, quiet: boolean?, phone: boolean?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = LOOK.SLATE
	frame.BackgroundTransparency = if quiet then Style.SLATE_QUIET_T else Style.SLATE_T
	frame.BorderSizePixel = 0
	Style.corner(frame, Style.RADIUS.ROW)
	Style.stroke(frame, LOOK.BRASS, Style.EDGE_T.SLATE)
	if phone then
		Style.padding(frame, 4, 4, 10, 10)
	else
		Style.padding(frame, 6, 6, 12, 12)
	end
	frame.Parent = parent
	return frame
end

-- §3.4 THE EYEBROW AND THE TITLE: the pair that unifies the game. The eyebrow is the small brass
-- word above every title saying WHAT KIND OF THING THIS IS -- `HUNTING LODGE`, `TRUCK 2`, `DRIVE 1`,
-- `HIT` -- and it is never longer than three words.
--
-- `gradient` draws the 64 px panel header bar (a modal's); a CARD's header is the same pair without
-- it. Returns the frame, the eyebrow label and the title label, so the caller writes the words.
function Style.header(
	parent: GuiObject,
	width: number,
	viewportX: number,
	gradient: boolean?
): (Frame, TextLabel, TextLabel)
	local phone = Style.isPhone(viewportX)
	local height = if phone then 56 else 64
	local inset = if phone then 16 else 20
	local frame = Instance.new("Frame")
	frame.Name = "Header"
	frame.BorderSizePixel = 0
	frame.BackgroundTransparency = if gradient then 0 else 1
	frame.BackgroundColor3 = LOOK.HEADER_TOP
	frame.Size = UDim2.fromOffset(width, height)
	frame.Position = UDim2.fromOffset(0, 0)
	frame.ZIndex = parent.ZIndex + 1
	if gradient then
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Color = ColorSequence.new(LOOK.HEADER_TOP, LOOK.HEADER_BOTTOM)
		fade.Parent = frame
	end
	frame.Parent = parent

	local eyebrow = Style.label(frame, "Eyebrow", "MICRO", viewportX)
	eyebrow.TextColor3 = LOOK.BRASS
	eyebrow.TextXAlignment = Enum.TextXAlignment.Left
	eyebrow.Position = UDim2.fromOffset(inset, 11)
	eyebrow.Size = UDim2.fromOffset(width - 2 * inset, 12)

	local title = Style.label(frame, "Title", "TITLE", viewportX)
	title.TextColor3 = LOOK.PAPER
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromOffset(inset, 24)
	title.Size = UDim2.fromOffset(width - 2 * inset, height - 28)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	return frame, eyebrow, title
end

-- §3.9 A STAT CHIP -- "4:44 TIME". A number you glance at, and the word that says what it is.
--
-- IT HAS NO BACKGROUND OF ITS OWN: chips live inside ONE shared slate, separated by a 1 px divider.
-- The caption sits AFTER the number and reads as one phrase, exactly as the shop's wallet pills do.
-- NO CHIP EVER WRAPS and no chip is ever shrunk: if the row will not fit, a WHOLE CHIP IS DROPPED.
-- A chip whose value is unknown is not drawn -- it never shows `--`.
function Style.statChip(parent: GuiObject, name: string, viewportX: number): (Frame, TextLabel, TextLabel)
	local phone = Style.isPhone(viewportX)
	-- THE BOX IS THE DESKTOP STEP AT EVERY VIEWPORT, and only the TEXT inside it changes with the
	-- scale. A box is a container: a 17 px phone number in a 24 px box reads the same, and it means
	-- `Hud.applyViewportLayout` has one property to move when the window is resized (a `TextSize`)
	-- rather than a height per label. The first Play of task 201 built the whole HUD at the phone
	-- step because `Camera.ViewportSize` is (1, 1) until the first frame is rendered.
	local box = Style.SIZE.STAT[1] + 4
	local chip = Instance.new("Frame")
	chip.Name = name
	chip.BackgroundTransparency = 1
	chip.BorderSizePixel = 0
	chip.AutomaticSize = Enum.AutomaticSize.X
	-- FULL HEIGHT OF WHATEVER HOLDS IT, so one slate decides the bar's height and a chip never
	-- argues with it. The caller may overwrite this with a fixed height for a chip that stands alone.
	chip.Size = UDim2.fromScale(0, 1)
	chip.ZIndex = parent.ZIndex + 1
	Style.corner(chip, Style.RADIUS.CHIP)
	Style.padding(chip, 0, 0, if phone then 8 else 10, if phone then 10 else 12)
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Padding = UDim.new(0, 7)
	row.Parent = chip
	chip.Parent = parent

	local value = Style.label(chip, "Value", "STAT", viewportX)
	value.AutomaticSize = Enum.AutomaticSize.X
	value.Size = UDim2.fromOffset(0, box)
	value.LayoutOrder = 2
	value.TextXAlignment = Enum.TextXAlignment.Left

	-- THE CAPTION SITS AFTER THE NUMBER AND IS BOTTOM-ALIGNED TO IT, exactly as the shop's wallet
	-- pills do, so `2000 COINS` reads as one phrase and not as a form field. Same box height as the
	-- value and `TextYAlignment = Bottom`: the two baselines line up without a second layout.
	local caption = Style.label(chip, "Caption", "MICRO", viewportX)
	caption.AutomaticSize = Enum.AutomaticSize.X
	caption.Size = UDim2.fromOffset(0, box)
	caption.LayoutOrder = 3
	caption.TextColor3 = LOOK.FIELD_MUTED
	caption.TextXAlignment = Enum.TextXAlignment.Left
	caption.TextYAlignment = Enum.TextYAlignment.Bottom
	Style.padding(caption, 0, 3, 0, 0)
	return chip, value, caption
end

-- The 1 px x 18 px divider between two chips, `LINE` at 0.4 with 12 px either side (§3.9).
function Style.chipDivider(parent: GuiObject, name: string): Frame
	local bar = Instance.new("Frame")
	bar.Name = name
	bar.BackgroundColor3 = LOOK.LINE
	bar.BackgroundTransparency = 0.4
	bar.BorderSizePixel = 0
	bar.Size = UDim2.fromOffset(1, 18)
	bar.ZIndex = parent.ZIndex + 1
	bar.Parent = parent
	return bar
end

-- §3.6 A PILL: a stadium-shaped label for an IDENTITY -- a role, a rank, a team. Never pressable.
function Style.pill(parent: GuiObject, name: string, color: Color3, viewportX: number): (Frame, TextLabel)
	local phone = Style.isPhone(viewportX)
	local height = if phone then 20 else 22
	local pill = Instance.new("Frame")
	pill.Name = name
	pill.BackgroundColor3 = color
	pill.BackgroundTransparency = 0.80
	pill.BorderSizePixel = 0
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, height)
	pill.ZIndex = parent.ZIndex + 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, math.floor(height / 2))
	corner.Parent = pill
	Style.stroke(pill, color, 0.45)
	Style.padding(pill, 0, 0, 10, 10)
	pill.Parent = parent

	local text = Style.label(pill, "Text", "MICRO", viewportX)
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Size = UDim2.fromOffset(0, height)
	text.TextColor3 = color
	text.TextXAlignment = Enum.TextXAlignment.Center
	return pill, text
end

-- IT IS NEVER A DIRECT CHILD OF A LAID-OUT FRAME. `UIListLayout` lays out EVERY visible child and
-- has no opt-out, so a Scale-width bar dropped into a chip's row stretches the row -- measured on
-- `20261017T133631Z-t201-beater-running-2.png`, where the horn's cooldown bar ran the whole width
-- of the screen. The caller puts the row in a `Content` frame and the bar beside it, so the slate
-- measures the row (`AutomaticSize` ignores a child sized in Scale) and the bar spans whatever the
-- row came to.
--
-- §3.8 A PROGRESS BAR. NO TWEEN: it is a clock and moves linearly with the number beside it.
-- Returns the track and the fill; the caller writes the fill's `Size` fraction.
function Style.bar(
	parent: GuiObject,
	name: string,
	track: Color3,
	low: Color3,
	high: Color3,
	height: number
): (Frame, Frame)
	local back = Instance.new("Frame")
	back.Name = name
	back.BackgroundColor3 = track
	back.BackgroundTransparency = 0.82
	back.BorderSizePixel = 0
	back.Size = UDim2.new(1, 0, 0, height)
	back.ZIndex = parent.ZIndex + 1
	Style.corner(back, Style.RADIUS.BAR)
	back.Parent = parent

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = high
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = back.ZIndex + 1
	Style.corner(fill, Style.RADIUS.BAR)
	local sweep = Instance.new("UIGradient")
	sweep.Color = ColorSequence.new(low, high)
	sweep.Parent = fill
	fill.Parent = back
	return back, fill
end

-- HOW TALL ONE TOAST IS. The slate's own padding plus the line's box, which is exactly what
-- `Style.toast` builds -- so a caller that has to RESERVE room for a stack of them has a number
-- that matches what is drawn. Round 1's second blocking finding was a reservation that did not:
-- 28 px assumed against a toast that measures 30.
function Style.toastHeight(viewportX: number): number
	local pad = if Style.isPhone(viewportX) then 4 else 6
	return 2 * pad + Style.sizeFor("LABEL", viewportX) + 6
end

-- The gap between two stacked toasts (§3.11: *"stacked bottom-up with a 6 px gap"*).
Style.TOAST_GAP = 6

-- §3.7 A TAG: the rectangular sibling of the pill, for a STATE rather than an identity.
-- `OWNED` / `12 / 25` / `DOWN` / `WOUNDED` / `LEFT`. A STATE IS NEVER COLOUR ALONE -- the word is
-- the first reading and the colour the second -- so this always carries text.
function Style.tag(parent: GuiObject, name: string, color: Color3, viewportX: number): (Frame, TextLabel)
	local tag = Instance.new("Frame")
	tag.Name = name
	tag.BackgroundColor3 = color
	tag.BackgroundTransparency = 0.84
	tag.BorderSizePixel = 0
	tag.AutomaticSize = Enum.AutomaticSize.X
	tag.Size = UDim2.fromOffset(0, if Style.isPhone(viewportX) then 17 else 19)
	tag.ZIndex = parent.ZIndex + 1
	Style.corner(tag, Style.RADIUS.TAG)
	Style.stroke(tag, color, 0.45)
	Style.padding(tag, 0, 0, 7, 7)
	tag.Parent = parent

	local text = Style.label(tag, "Text", "MICRO", viewportX)
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Size = UDim2.fromScale(0, 1)
	text.TextColor3 = color
	text.TextXAlignment = Enum.TextXAlignment.Center
	return tag, text
end

-- ---------------------------------------------------------------- §3.10 the icon glyphs
--
-- AN ICON IS A FRAME. §3.10 names the whole permitted set and this is the one place four of them
-- are built -- the four the start card needs (`startcard-spec.md` section 2). The system's own
-- reason: *"Anything else is a Frame"*, because a glyph a font does not have comes back at the
-- `.notdef` width and draws as a rectangle, and no screenshot of a mockup will tell you that
-- happened on somebody else's machine.
--
-- EVERY NUMBER IS A FRACTION OF `px`, so one glyph draws at 16 px on a desktop row and 14 on a
-- phone without a second table of sizes. The system's numbers are quoted at its own 14..18 px and
-- the start-card spec's at 16: `tick` 7 x 2.5 and 12 x 2.5, `cross` 15 x 2.5, `chevron` 11 x 11,
-- `horn` a tapering arc of three sections with an 8 px bell (task 206; it was 15 x 6 with an
-- 8 x 8 bell, which Karen could not read) -- all at `px = 16`, which is what the ratios below reproduce.
-- ...AND THE TWO SHELLS (task 204). Karen, 2026-10-18: *"please diferenciate slug from shells"*.
-- Her own frame of the chip (`karen-2026-10-18/shot-3.png`) and this task's reproduction of it
-- showed a slug chip and a buckshot chip that differed in ONE WORD and nothing else -- same two
-- pips, same colours, same shape -- which is not something anybody reads at a glance while a boar
-- is crossing.
--
-- THEY ARE THE SAME SHELL WITH A DIFFERENT HEAD, which is what the two things actually are: one
-- brass rim, one hull, and then either ONE SOLID LEAD NOSE or a CLUSTER OF FOUR PELLETS. The hull
-- carries the load's own colour as well -- the game's shop already draws the slug box green
-- (`Hud.ShopDisplay`'s `buildShellBox`) and a red hull is what buckshot has looked like since
-- before anybody here was born -- so the two differ in SHAPE and in COLOUR, and a player who can
-- see neither still has the word.
Style.GLYPHS = { "tick", "cross", "chevron", "horn", "slug", "buck" }

-- THE TWO HULL COLOURS, as one table per load rather than a branch in the builder: `Style.glyph`
-- draws the same shell for both and this is the only thing that differs besides the head. They are
-- also what the chip's load WORD is tinted with (`Hud.AMMO_ACCENT`), so the glyph and the word
-- cannot say two different things.
Style.SHELL = table.freeze({
	slug = table.freeze({ hull = Color3.fromHex("3C7A50"), head = Color3.fromHex("D8D2C6") }),
	buck = table.freeze({ hull = Color3.fromHex("B2462F"), head = Color3.fromHex("E8E1D2") }),
})

function Style.glyph(parent: GuiObject, name: string, kind: string, px: number, color: Color3?): Frame
	local box = Instance.new("Frame")
	box.Name = name
	box.BackgroundTransparency = 1
	box.BorderSizePixel = 0
	box.Size = UDim2.fromOffset(px, px)
	box.ZIndex = parent.ZIndex + 1
	box.Parent = parent

	local function bar(partName: string, w: number, h: number, rotation: number, fill: Color3): Frame
		local part = Instance.new("Frame")
		part.Name = partName
		part.BackgroundColor3 = fill
		part.BorderSizePixel = 0
		part.AnchorPoint = Vector2.new(0.5, 0.5)
		part.Position = UDim2.fromScale(0.5, 0.5)
		part.Size = UDim2.fromOffset(math.max(1, w), math.max(1, h))
		part.Rotation = rotation
		part.ZIndex = box.ZIndex + 1
		Style.corner(part, math.max(1, math.round(px / 16)))
		part.Parent = box
		return part
	end

	if kind == "tick" then
		-- THE SHORT STROKE DOWN-LEFT AND THE LONG ONE UP-RIGHT, meeting at the heel. The two are
		-- nudged off centre so the join is the tick's corner and not its middle.
		local fill = color or LOOK.PINE_TEXT
		local short = bar("Short", px * 7 / 16, px * 2.5 / 16, 45, fill)
		short.Position = UDim2.fromScale(0.3, 0.62)
		local long = bar("Long", px * 12 / 16, px * 2.5 / 16, -50, fill)
		long.Position = UDim2.fromScale(0.58, 0.46)
	elseif kind == "cross" then
		-- 15 AND NOT 18 (the start-card spec's own note): the row is 24 px tall and the close
		-- button's 18 px X in a 16 px box would touch the text beside it.
		local fill = color or LOOK.CLAY
		bar("A", px * 15 / 16, px * 2.5 / 16, 45, fill)
		bar("B", px * 15 / 16, px * 2.5 / 16, -45, fill)
	elseif kind == "chevron" then
		local fill = color or LOOK.BLAZE_HI
		local tile = bar("Tile", px * 11 / 16, px * 11 / 16, 45, fill)
		Style.corner(tile, math.max(2, math.round(px * 2 / 16)))
	elseif kind == "horn" then
		-- A CURVED, TAPERING TUBE WITH A BELL AND A MOUTHPIECE (task 206). KAREN, 2026-10-18,
		-- looking at the beater's HORN chip: *"and what is this icon ?"*.
		--
		-- WHAT SHE WAS LOOKING AT, and it is the honest description: a 15 x 6 rounded bar with an
		-- 8 x 8 rounded square overlapping its right end -- at 16 px, a lozenge and a dot. Nothing
		-- in it tapered, nothing curved, and the "bell" was as wide as it was tall, so the two
		-- shapes read as one blob. Her own frame is `karen-2026-10-18/shot-6.png`.
		--
		-- SO IT IS FIVE SHAPES, and each one is a thing a horn actually has: a dark MOUTHPIECE nub
		-- at the narrow end, THREE tube sections that taper 2.4 -> 3.2 -> 4.2 px and turn +16, 0,
		-- -18 degrees (a shallow arc rising to the right -- the arc of this game's own horn, whose
		-- measured centre line is `Horn.TUBE_SAMPLES`), and a BELL that is 8 px tall against the
		-- 4.2 px tube it grows out of. The taper and the flare are the whole of what makes a brass
		-- shape read as a horn at this size; the old glyph had neither.
		--
		-- THREE COLOURS, NOT ONE, for the same reason the two shells have two (task 204): the
		-- mouthpiece is `BRASS_LO` and the bell `BRASS_HI` against the tube's `BRASS`, so the two
		-- ends are told apart by VALUE as well as by shape -- which is what survives being 14 px on
		-- a phone, and what a flat silhouette does not.
		--
		-- EVERY NUMBER IS A FRACTION OF `px`, exactly as the four glyphs above are, so the phone's
		-- 14 px horn is this implementation and not a second table. Drawn at 16 and at 14 before it
		-- was written down (rule 5): `.screenshots/t206-glyph-before-after.png`.
		--
		-- ...AND THE TAPER SURVIVES WHOLE PIXELS, which is a MEASUREMENT and not a rounding of the
		-- numbers that looked nice. `UDim2.fromOffset` TRUNCATES, so the first try's 2.4 / 3.2 / 4.2
		-- came out 2 / 2 / 3 px at `px = 14` -- the phone's size, where the first two sections were
		-- the same thickness and the taper that makes this read as a horn was simply not drawn. The
		-- spec case drives 14, 16 and 18 for exactly that reason, and 2.6 / 3.6 / 4.8 is the triple
		-- that comes out three distinct, increasing integers at all three.
		local brass = color or LOOK.BRASS
		local mouth = bar("Mouthpiece", px * 2.6 / 16, px * 3.0 / 16, 20, LOOK.BRASS_LO)
		mouth.Position = UDim2.fromScale(0.10, 0.60)
		Style.corner(mouth, math.max(1, math.round(px * 1.5 / 16)))
		local near = bar("TubeNear", px * 5.4 / 16, px * 2.6 / 16, 16, brass)
		near.Position = UDim2.fromScale(0.28, 0.62)
		local mid = bar("TubeMid", px * 5.4 / 16, px * 3.6 / 16, 0, brass)
		mid.Position = UDim2.fromScale(0.50, 0.57)
		Style.corner(mid, math.max(1, math.round(px * 1.5 / 16)))
		local far = bar("TubeFar", px * 5.0 / 16, px * 4.8 / 16, -18, brass)
		far.Position = UDim2.fromScale(0.70, 0.47)
		Style.corner(far, math.max(2, math.round(px * 2 / 16)))
		-- LAST, SO IT IS ON TOP. Every bar here carries the same `ZIndex`, and a sibling drawn
		-- later wins -- which is the order the old two-shape glyph already relied on.
		local bell = bar("Bell", px * 3.4 / 16, px * 8.0 / 16, -18, LOOK.BRASS_HI)
		bell.Position = UDim2.fromScale(0.83, 0.34)
		Style.corner(bell, math.max(1, math.round(px * 1.5 / 16)))
	elseif kind == "slug" or kind == "buck" then
		-- ONE SHELL, STANDING, 10 x 15 in a 16 px box: a 4 px brass rim at the foot, the hull above
		-- it, and the head on top. The parts are `bar`s like every other glyph here, so one number
		-- (`px`) sizes the whole thing and the 14 px phone shell is the same implementation as the
		-- 16 px desktop one.
		local shell = Style.SHELL[kind]
		local hull = bar("Hull", px * 10 / 16, px * 11 / 16, 0, shell.hull)
		hull.Position = UDim2.fromScale(0.5, 0.42)
		local rim = bar("Rim", px * 10 / 16, px * 5 / 16, 0, color or LOOK.BRASS)
		rim.Position = UDim2.fromScale(0.5, 0.84)
		if kind == "slug" then
			-- ONE SOLID NOSE, as wide as the hull and domed by its own corner radius: a single mass
			-- of lead, which is the whole difference from the cluster below.
			local nose = bar("Nose", px * 8 / 16, px * 6 / 16, 0, shell.head)
			nose.Position = UDim2.fromScale(0.5, 0.2)
			Style.corner(nose, math.max(2, math.round(px * 3 / 16)))
		else
			-- FOUR PELLETS, 2 x 2. Four and not nine: at 16 px nine dots are a grey smear, and what
			-- has to read is "many small" against "one big". They are square-cornered circles -- a
			-- 3 px dot with a 2 px radius -- for the same reason the horn's bell is.
			for index = 1, 4 do
				local column = (index - 1) % 2
				local row = math.floor((index - 1) / 2)
				local pellet = bar(string.format("Pellet%d", index), px * 3.4 / 16, px * 3.4 / 16, 0, shell.head)
				pellet.Position = UDim2.fromScale(0.34 + column * 0.32, 0.12 + row * 0.26)
				Style.corner(pellet, math.max(2, math.round(px * 2 / 16)))
			end
		end
	else
		error(string.format("[Style] no such glyph: %s", tostring(kind)), 2)
	end
	return box
end

-- WHERE A SECTION HEAD'S RULE STARTS. §3.12: a section head is a word plus a hairline FILLING THE
-- REST OF THE WIDTH -- so the rule begins after the word, and the word's own drawn width is the
-- only honest source for that (`TextBounds`, which the engine updates once the face has loaded).
-- Called from the render and not from the build, because a head whose word changes moves the rule.
function Style.ruleAfter(word: TextLabel, rule: Frame, gap: number)
	rule.Size = UDim2.new(1, -(math.ceil(word.TextBounds.X) + gap), 0, 1)
end

-- ---------------------------------------------------------------- §3.12 the table row
--
-- THE RESULTS BOARD AND THE REPORT ARE BUILT FROM THIS, ONE `TextLabel` PER CELL. The monospace
-- alignment they used until task 201 is gone with `Enum.Font.Code`: *"the numbers line up because
-- they are PLACED, not because every glyph is one width"* (§1.2). A column is an x and a width.
Style.ROW_H = { 28, 24 }

function Style.rowHeight(viewportX: number): number
	return if Style.isPhone(viewportX) then Style.ROW_H[2] else Style.ROW_H[1]
end

-- ONE ROW. `Rule` is the 1 px divider at its bottom (between rows, never after the last -- the
-- caller hides it on the last one) and `Bar` is the 3 px left edge your OWN row wears in its team's
-- colour. Both are built every time and shown by `Style.rowState`, so a row cannot acquire a bar it
-- has no way to lose.
function Style.tableRow(parent: GuiObject, name: string, viewportX: number, width: number): Frame
	local row = Instance.new("Frame")
	row.Name = name
	row.BackgroundColor3 = LOOK.ROW_SELECTED
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Size = UDim2.fromOffset(width, Style.rowHeight(viewportX))
	row.ZIndex = parent.ZIndex + 1
	row.Visible = false
	row.Parent = parent

	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.BackgroundColor3 = LOOK.LINE
	rule.BackgroundTransparency = 0.55
	rule.BorderSizePixel = 0
	rule.AnchorPoint = Vector2.new(0, 1)
	rule.Position = UDim2.fromScale(0, 1)
	rule.Size = UDim2.new(1, 0, 0, 1)
	rule.ZIndex = row.ZIndex
	rule.Parent = row

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundColor3 = LOOK.HUNTER
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(0, 3, 1, 0)
	bar.ZIndex = row.ZIndex + 1
	bar.Visible = false
	bar.Parent = row
	return row
end

-- WHOSE ROW IS THIS? `mine` fills it `ROW_SELECTED` and lights the left bar in the team's colour;
-- `hovered` is `ROW_HOVER` (the report's list only). ONE writer of all three properties, so a row
-- that stops being mine really stops looking like mine.
function Style.rowState(row: Frame, mine: boolean, team: string?, hovered: boolean?)
	row.BackgroundTransparency = if mine or hovered then 0 else 1
	row.BackgroundColor3 = if mine then LOOK.ROW_SELECTED else LOOK.ROW_HOVER
	local bar = row:FindFirstChild("Bar")
	if bar ~= nil then
		(bar :: Frame).Visible = mine;
		(bar :: Frame).BackgroundColor3 = Style.teamColor(team)
	end
end

-- ONE CELL. A NAME is `HEADING` Oswald Medium and left; a NUMBER is the same face and RIGHT, which
-- is what makes a column of them read as a column (§3.12).
function Style.cell(
	row: GuiObject,
	name: string,
	viewportX: number,
	x: number,
	width: number,
	right: boolean?,
	step: string?
): TextLabel
	local text = Style.label(row, name, step or "HEADING", viewportX)
	text.Position = UDim2.fromOffset(x, 0)
	text.Size = UDim2.new(0, width, 1, 0)
	text.TextXAlignment = if right then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
	text.TextColor3 = LOOK.BODY
	text.TextTruncate = Enum.TextTruncate.AtEnd
	return text
end

-- A COLUMN HEAD IS ITS OWN ROW: `MICRO` Bold, `spaced()`, `FAINT` on a lodge panel and
-- `FIELD_MUTED` on a card (§2 bans `FAINT` over the world), with the brass hairline under it.
function Style.columnHead(parent: GuiObject, name: string, viewportX: number, width: number, onCard: boolean?): Frame
	local row = Instance.new("Frame")
	row.Name = name
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Size = UDim2.fromOffset(width, Style.rowHeight(viewportX))
	row.ZIndex = parent.ZIndex + 1
	row.Parent = parent

	local hair = Instance.new("Frame")
	hair.Name = "Hairline"
	hair.BackgroundColor3 = LOOK.BRASS
	hair.BackgroundTransparency = if onCard then Style.EDGE_T.CARD else Style.EDGE_T.PANEL
	hair.BorderSizePixel = 0
	hair.AnchorPoint = Vector2.new(0, 1)
	hair.Position = UDim2.fromScale(0, 1)
	hair.Size = UDim2.new(1, 0, 0, 1)
	hair.ZIndex = row.ZIndex
	hair.Parent = row
	return row
end

-- A SECTION HEAD (`HUNTERS`, `BEATERS`) is an EYEBROW in the team's colour plus a 1 px `LINE` rule
-- filling the rest of the width, 8 px after the word. It is NOT a row and it has no rule under it.
-- `color` IS THE HEAD'S OWN WORD COLOUR and defaults to the results board's team orange, which is
-- what every caller before the start card wanted. The card's heads are `FIELD_MUTED`: they label a
-- list on a card that already has one coloured heading (the role line), and §1.1 allows one.
function Style.sectionHead(
	parent: GuiObject,
	name: string,
	viewportX: number,
	width: number,
	color: Color3?
): (Frame, TextLabel, Frame)
	local head = Instance.new("Frame")
	head.Name = name
	head.BackgroundTransparency = 1
	head.BorderSizePixel = 0
	head.Size = UDim2.fromOffset(width, if Style.isPhone(viewportX) then 18 else 20)
	head.ZIndex = parent.ZIndex + 1
	head.Visible = false
	head.Parent = parent

	local word = Style.label(head, "Word", "MICRO", viewportX)
	word.AutomaticSize = Enum.AutomaticSize.X
	word.Size = UDim2.fromScale(0, 1)
	word.TextColor3 = color or LOOK.HUNTER
	word.TextXAlignment = Enum.TextXAlignment.Left

	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.BackgroundColor3 = LOOK.LINE
	rule.BackgroundTransparency = 0.35
	rule.BorderSizePixel = 0
	rule.AnchorPoint = Vector2.new(1, 0.5)
	rule.Position = UDim2.new(1, 0, 0.5, 1)
	rule.Size = UDim2.new(1, 0, 0, 1)
	rule.ZIndex = head.ZIndex
	rule.Parent = head
	return head, word, rule
end

-- §3.5 THE CLOSE BUTTON, the one icon button: 44 x 44, and the X is TWO ROTATED FRAMES so no glyph
-- has to exist in the font -- the rule the shop's own X already follows.
function Style.closeButton(parent: GuiObject, name: string): TextButton
	local node = Instance.new("TextButton")
	node.Name = name
	node.Text = ""
	node.AutoButtonColor = false
	node.BackgroundColor3 = LOOK.ROW
	node.BorderSizePixel = 0
	node.Size = UDim2.fromOffset(44, 44)
	node.ZIndex = parent.ZIndex + 1
	Style.corner(node, Style.RADIUS.ROW)
	Style.stroke(node, LOOK.LINE, 0)
	node.Parent = parent
	for index, rotation in ipairs({ 45, -45 }) do
		local bar = Instance.new("Frame")
		bar.Name = string.format("Bar%d", index)
		bar.BackgroundColor3 = LOOK.MUTED
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromOffset(18, 2)
		bar.Rotation = rotation
		bar.ZIndex = node.ZIndex + 1
		Style.corner(bar, 1)
		bar.Parent = node
	end
	return node
end

-- §3.5 A GHOST KEY CHIP -- `TAB` `CLOSE`, `ENTER` `DETAILS` -- the footer's key hints as chips
-- rather than words inside a sentence (§5 surface 12). Not pressable: it is a legend.
function Style.keyChip(parent: GuiObject, name: string, key: string, word: string, viewportX: number): Frame
	local chip = Instance.new("Frame")
	chip.Name = name
	chip.BackgroundTransparency = 1
	chip.BorderSizePixel = 0
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Size = UDim2.fromOffset(0, if Style.isPhone(viewportX) then 26 else 30)
	chip.ZIndex = parent.ZIndex + 1
	Style.corner(chip, Style.RADIUS.CHIP)
	Style.stroke(chip, LOOK.LINE, Style.EDGE_T.GHOST)
	Style.padding(chip, 0, 0, 10, 10)
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Padding = UDim.new(0, 7)
	row.Parent = chip
	chip.Parent = parent

	local keyLabel = Style.label(chip, "Key", "MICRO", viewportX)
	keyLabel.AutomaticSize = Enum.AutomaticSize.X
	keyLabel.Size = UDim2.fromScale(0, 1)
	keyLabel.LayoutOrder = 1
	keyLabel.TextColor3 = LOOK.BRASS
	keyLabel.Text = Style.spaced(key)

	local wordLabel = Style.label(chip, "Word", "MICRO", viewportX)
	wordLabel.AutomaticSize = Enum.AutomaticSize.X
	wordLabel.Size = UDim2.fromScale(0, 1)
	wordLabel.LayoutOrder = 2
	wordLabel.TextColor3 = LOOK.FIELD_MUTED
	wordLabel.Text = Style.spaced(word)
	return chip
end

-- §3.11 A TOAST: the kill feed, the server's refusals and every receipt are ONE component. Each
-- line is its own slate with a meaning dot, and each fades on its own.
-- `zIndex` IS THE BAND THE WHOLE TOAST SITS IN, and it is a PARAMETER because round 1's third
-- blocking finding was the guard below failing silently: a `ScreenGui` is not a `GuiObject`, so a
-- toast parented straight to the screen kept `ZIndex` 1, its dot and its words were created at 2
-- (`Style.label` reads `parent.ZIndex + 1`), and the caller then raised the SLATE to 7 -- leaving
-- the words drawing BEHIND their own background under `ZIndexBehavior.Global`. That is the defect
-- task 159 paid for twice and the one this function's own header already forbade.
function Style.toast(
	parent: Instance,
	name: string,
	viewportX: number,
	step: string?,
	zIndex: number?
): (Frame, Frame, TextLabel)
	local phone = Style.isPhone(viewportX)
	local frame = Style.slate(parent, name, false, phone)
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.Size = UDim2.fromOffset(0, 0)
	-- THE SLATE TAKES ITS BAND BEFORE ITS CHILDREN ARE MADE, because `Style.label` reads
	-- `parent.ZIndex + 1` at creation: raising the frame afterwards would leave the dot and the
	-- words drawing BEHIND their own background, which is the defect task 159 paid for twice
	-- (*"the panel reads, the words do not"*).
	--
	-- AN EXPLICIT `zIndex` WINS, and a `ScreenGui` parent is exactly why it exists: it is not a
	-- `GuiObject`, so there is no band to inherit and the old guard simply did not fire.
	if zIndex ~= nil then
		frame.ZIndex = zIndex
	elseif parent:IsA("GuiObject") then
		frame.ZIndex = (parent :: GuiObject).ZIndex
	end
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Padding = UDim.new(0, 8)
	row.Parent = frame

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.BackgroundColor3 = LOOK.BODY
	dot.BorderSizePixel = 0
	dot.Size = UDim2.fromOffset(6, 6)
	dot.LayoutOrder = 1
	dot.ZIndex = frame.ZIndex + 1
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 3)
	round.Parent = dot
	dot.Parent = frame

	-- `step` IS "LABEL" FOR THE FEED AND "TITLE" FOR THE TIED BANNER (§5 surface 13: *"one centred
	-- clay toast at `TITLE`"*). It is the same component at a different step of the one scale, which
	-- is the whole point of having a scale.
	local size = step or "LABEL"
	local text = Style.label(frame, "Text", size, viewportX)
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Size = UDim2.fromOffset(0, Style.sizeFor(size, viewportX) + 6)
	text.LayoutOrder = 2
	text.TextColor3 = LOOK.BODY
	text.TextXAlignment = Enum.TextXAlignment.Left
	return frame, dot, text
end

-- WHAT A LINE MEANS, AS A COLOUR (§3.11). One table, five meanings, and the dot and the words
-- always agree because they are read from the same entry.
Style.MEANING = {
	info = LOOK.BODY, -- something happened
	good = LOOK.PINE_TEXT, -- you did well: a kill, a purchase, a bonus
	bad = LOOK.CLAY, -- you lost something: wounded-lost, a penalty, a refusal
	money = LOOK.COIN_TEXT, -- money moved
	go = LOOK.BLAZE_HI, -- the game is telling you to do something
}

function Style.meaningColor(meaning: string?): Color3
	return Style.MEANING[meaning or "info"] or LOOK.BODY
end

-- WHICH SIDE A PLAYER IS ON, AS A COLOUR. `Shooters` / `Drivers` are the TEAM names the drive
-- publishes; `HUNTER` / `BEATER` are the words Karen's design doc uses for them. One reader of the
-- mapping, so a roster, a pill and a map marker can never disagree about which orange is whose.
function Style.teamColor(team: string?): Color3
	if team == "Drivers" then
		return LOOK.BEATER
	elseif team == "Shooters" then
		return LOOK.HUNTER
	end
	return LOOK.PAPER
end

return Style
