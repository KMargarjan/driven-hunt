-- hud_style.spec: THE ONE SOURCE, and the surfaces that read it.
--
-- Karen, 2026-10-17 ~12:30: *"all menus all information (timer  what to shoot who you are ect. ) has
-- to be same design as menu colors loading ect again ask designer to fallow on this / we need one
-- unified design system and colours and style across all game"*. The Designer's design system,
-- 2026-10-17 is the answer, and build task A is `src/client/Hud/Style.luau`.
--
-- WHAT THIS FILE IS FOR, and it is not "does Style have a table in it". A design system is only
-- worth having if there is ONE of it, so what is asserted here is the two things that can actually
-- go wrong:
--
--   1. a SECOND copy of a token -- the shop's palette and the HUD's drifting apart, which is this
--      repo's named failure mode (`docs/PROJECT_CONTEXT.md`: *"two correct pieces of code
--      disagreeing"*) and is exactly how the pad dialog came to be `Enum.Font.Code` on a blue-grey
--      panel while the shop beside it was Oswald on charcoal;
--   2. a surface that stopped reading the source -- the one failure a screenshot catches late and a
--      grep catches never, because a hard-coded `Color3.fromRGB(255, 255, 255)` looks fine until
--      the palette moves under it.
--
-- SO EVERY CASE EITHER COMPARES TWO READERS OF ONE TOKEN, or reads a property OFF THE LIVE SCREEN
-- and compares it with the token. The second kind is the one that matters: it is the difference
-- between "the file says blaze" and "the pixel is blaze".
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
-- The drive's own contract, for the two strings this file asserts are NOT on the status bar.
local Drive = require(ReplicatedStorage:WaitForChild("Drive"))
local Money = require(ReplicatedStorage:WaitForChild("Money"))

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Hud = require(scripts:WaitForChild("Hud"))

local Style = Hud.Style
local Compass = Hud.Compass
local Objective = Hud.Objective
local Rail = Hud.Rail
local ShopPanel = Hud.Shop

return function()
	describe("the tokens", function()
		it("holds every colour the system names, as a Color3", function()
			-- §1.1's four tables, by name. A missing token is a surface that will reach for a hex of
			-- its own, so the list is spelled out rather than counted.
			local wanted = {
				"SCRIM",
				"PANEL",
				"COLUMN",
				"HEADER_TOP",
				"HEADER_BOTTOM",
				"ROW",
				"ROW_HOVER",
				"ROW_LOCKED",
				"ROW_SELECTED",
				"SLATE",
				"BRASS",
				"BRASS_HI",
				"BRASS_LO",
				"LINE",
				"WELL_EDGE",
				"HIGHLIGHT",
				"PAPER",
				"BODY",
				"MUTED",
				"FAINT",
				"FIELD_MUTED",
				"BUTTON_TEXT",
				"BLAZE",
				"BLAZE_HI",
				"BLAZE_LO",
				"BLAZE_EDGE",
				"PINE",
				"PINE_TEXT",
				"PINE_DARK",
				"AMBER",
				"AMBER_BAR",
				"AMBER_DARK",
				"CLAY",
				"CLAY_EDGE",
				"CLAY_DARK",
				"COIN_TEXT",
				"HUNTER",
				"BEATER",
			}
			local missing = {}
			for _, name in ipairs(wanted) do
				if typeof(Style.LOOK[name]) ~= "Color3" then
					table.insert(missing, name)
				end
			end
			expect(table.concat(missing, ", ")).to.equal("")
		end)

		it("gives the four NEW tokens the hexes the system measured them at", function()
			-- These four did not exist before task 201 and every one of them was MEASURED rather
			-- than chosen: the slate against six grounds (§2), `FIELD_MUTED` because `MUTED` comes
			-- out at 4.11 : 1 over a bright sky, and the two team colours because green already
			-- means "already true".
			expect(Style.LOOK.SLATE).to.equal(Color3.fromHex("14110E"))
			expect(Style.LOOK.FIELD_MUTED).to.equal(Color3.fromHex("B3AA98"))
			expect(Style.LOOK.HUNTER).to.equal(Color3.fromHex("E8832F"))
			expect(Style.LOOK.BEATER).to.equal(Color3.fromHex("79A7C4"))
			-- THE HUNTERS' ORANGE IS THE BLAZE AND NOT A SECOND ORANGE BESIDE IT.
			expect(Style.LOOK.HUNTER).to.equal(Style.LOOK.BLAZE_HI)
		end)

		it("is the SHOP'S palette and not a second copy of it", function()
			-- TASK A'S WHOLE CHECK. `ShopPanel.LOOK` / `.FONT` / `.spaced` are thin aliases now, so
			-- the shop and the pad dialog look exactly as `196-shop-desktop.png` and
			-- `t197d-dialog.png` already do. Comparing the TABLES and not their contents is the
			-- point: two tables with equal values today are two tables that can disagree tomorrow.
			expect(ShopPanel.LOOK).to.equal(Style.LOOK)
			expect(ShopPanel.FONT).to.equal(Style.FONT)
			expect(ShopPanel.spaced).to.equal(Style.spaced)
			-- ...and the values the shop's own spec names are still what they were.
			expect(Style.LOOK.BLAZE).to.equal(Color3.fromHex("D2661B"))
			expect(Style.LOOK.PANEL).to.equal(Color3.fromHex("1C1915"))
			expect(Style.LOOK.MESSAGE_SECONDS).to.equal(4)
			expect(Style.LOOK.HOVER_SECONDS).to.equal(Style.MOTION.HOVER)
		end)

		it("letter-spaces an uppercase label and strips the trailing space", function()
			expect(Style.spaced("AMMO")).to.equal("A M M O")
			-- ...AND `unspaced` IS ITS EXACT INVERSE, which a `gsub` of every space is NOT: a spaced
			-- sentence has TWO spaces where the original had one, so stripping them all gave
			-- "NEXTDRIVEIN" and that is what the footer accessor answered on round 2's first gate.
			expect(Style.unspaced(Style.spaced("NEXT DRIVE IN"))).to.equal("NEXT DRIVE IN")
			expect(Style.unspaced(Style.spaced("AMMO"))).to.equal("AMMO")
			expect(Style.unspaced(Style.spaced("N"))).to.equal("N")
			expect(Style.spaced("N")).to.equal("N")
			expect(Style.spaced("")).to.equal("")
		end)

		it("has ONE break point, and the objective line reads the same one", function()
			-- §1.2: *"which is the break point `Objective.CONFIG.SMALL_BELOW_PX` already uses, so
			-- there is one break point in the game"*. Two would be two answers to "is this a phone".
			expect(Style.PHONE_BELOW_PX).to.equal(Objective.CONFIG.SMALL_BELOW_PX)
			expect(Style.isPhone(400)).to.equal(true)
			expect(Style.isPhone(699)).to.equal(true)
			expect(Style.isPhone(700)).to.equal(false)
			expect(Style.isPhone(1280)).to.equal(false)
		end)

		it("answers the desktop step above the break point and the phone step below it", function()
			for step, pair in pairs(Style.SIZE) do
				expect(Style.sizeFor(step, 1280)).to.equal(pair[1])
				expect(Style.sizeFor(step, 400)).to.equal(pair[2])
				-- A PHONE STEP IS NEVER BIGGER THAN ITS DESKTOP STEP, which is the only thing that
				-- makes the scale a scale.
				expect(pair[2] <= pair[1]).to.equal(true)
			end
			expect(Style.sizeFor("STAT", 1280)).to.equal(20)
			expect(Style.sizeFor("MICRO", 400)).to.equal(9)
		end)

		it("draws a title in Oswald and a sentence in BuilderSans, and never in Code", function()
			-- §1.2: Oswald for a title, a name and every number; BuilderSans for every sentence,
			-- button word, column head and label. Nothing else.
			expect(Style.faceFor("TITLE")).to.equal(Style.FONT.OSWALD_SB)
			expect(Style.faceFor("STAT")).to.equal(Style.FONT.OSWALD_SB)
			expect(Style.faceFor("HEADING")).to.equal(Style.FONT.OSWALD_MD)
			expect(Style.faceFor("BODY")).to.equal(Style.FONT.SANS_REG)
			expect(Style.faceFor("LABEL")).to.equal(Style.FONT.SANS_SEMI)
			expect(Style.faceFor("MICRO")).to.equal(Style.FONT.SANS_BOLD)
		end)

		it("colours a meaning and a team from one table each", function()
			expect(Style.meaningColor("good")).to.equal(Style.LOOK.PINE_TEXT)
			expect(Style.meaningColor("bad")).to.equal(Style.LOOK.CLAY)
			expect(Style.meaningColor("money")).to.equal(Style.LOOK.COIN_TEXT)
			expect(Style.meaningColor("go")).to.equal(Style.LOOK.BLAZE_HI)
			-- An unknown meaning is "something happened" and never an error on screen.
			expect(Style.meaningColor(nil)).to.equal(Style.LOOK.BODY)
			expect(Style.meaningColor("nonsense")).to.equal(Style.LOOK.BODY)
			expect(Style.teamColor("Shooters")).to.equal(Style.LOOK.HUNTER)
			expect(Style.teamColor("Drivers")).to.equal(Style.LOOK.BEATER)
			expect(Style.teamColor(nil)).to.equal(Style.LOOK.PAPER)
		end)

		it("keeps the four over-the-world opacities the contrast table was computed at", function()
			-- §2's whole table rests on these. If the lighting pass makes the sky brighter than
			-- `#B4CFE4`, the ONE knob is `SLATE_T` -- and that is a decision, not a drift, so it
			-- changes here and the table is recomputed.
			--
			-- 0.14 SINCE TASK 215, ON THE DIRECTOR'S INSTRUCTION. The lighting spec's §6 makes the
			-- change conditional on the sky measuring brighter than `#B4CFE4`, and it does NOT:
			-- with `AUTUMN_LIGHT` on the brightest sky over two Forest Test frames is `#94B9D3`
			-- (luma 176.9) against that `#B4CFE4` (201.3). The change is kept because it is
			-- strictly safer -- `BLAZE_HI`, the tightest colour, goes 4.66 : 1 -> 5.18 : 1 over
			-- §2's own tested ground -- and reverting it is one line in `Style.luau` and this one.
			expect(Style.SLATE_T).to.equal(0.14)
			expect(Style.SLATE_QUIET_T).to.equal(0.08)
			expect(Style.CARD_T).to.equal(0.06)
			expect(Style.PANEL_T).to.equal(0)
			expect(Style.SCRIM_T).to.equal(0.42)
		end)
	end)

	-- A PROPERTY READ BACK OFF AN INSTANCE IS A float32 AND THE TOKEN IS A DOUBLE, so 0.18 comes
	-- back as 0.18000000715255737 and `to.equal` is the wrong question (the first run of this file
	-- failed on exactly that, four times). `to.be.near` at 1e-5 is two orders finer than any
	-- transparency step the system names and cannot hide a wrong value.
	describe("the constructors", function()
		-- EVERY ONE OF THEM IS BUILT INTO A REAL `ScreenGui` AND THEN DESTROYED, because a `Frame`
		-- with no parent reports no `AbsoluteSize` and half of what is asserted here is a property
		-- the engine resolves.
		local holder: Frame? = nil

		beforeEach(function()
			local box = Instance.new("Frame")
			box.Name = "StyleSpecHolder"
			box.Size = UDim2.fromOffset(600, 400)
			box.Visible = false
			box.Parent = Hud.gui()
			holder = box
		end)

		afterEach(function()
			if holder then
				(holder :: Frame):Destroy()
			end
			holder = nil
		end)

		it("gives a slate the charcoal, the corner and the brass hairline §3.3 asks for", function()
			local slate = Style.slate(holder :: Frame, "Probe")
			expect(slate.BackgroundColor3).to.equal(Style.LOOK.SLATE)
			expect(slate.BackgroundTransparency).to.be.near(Style.SLATE_T, 1e-5)
			local corner = slate:FindFirstChildOfClass("UICorner")
			expect(corner).to.be.ok()
			expect((corner :: UICorner).CornerRadius).to.equal(UDim.new(0, Style.RADIUS.ROW))
			local edge = slate:FindFirstChildOfClass("UIStroke")
			expect(edge).to.be.ok()
			expect((edge :: UIStroke).Color).to.equal(Style.LOOK.BRASS)
			expect((edge :: UIStroke).Transparency).to.be.near(Style.EDGE_T.SLATE, 1e-5)
			-- `Border` AND NOT THE DEFAULT `Contextual`, which outlines the TEXT instead of the box.
			expect((edge :: UIStroke).ApplyStrokeMode).to.equal(Enum.ApplyStrokeMode.Border)
			expect((edge :: UIStroke).Thickness).to.equal(1)
			-- The quiet variant is the SAME colour at the 9-11 px transparency, and nothing else.
			local quiet = Style.slate(holder :: Frame, "Quiet", true)
			expect(quiet.BackgroundColor3).to.equal(Style.LOOK.SLATE)
			expect(quiet.BackgroundTransparency).to.be.near(Style.SLATE_QUIET_T, 1e-5)
		end)

		it("gives a panel and a card their own rung of the radius ladder", function()
			local panel = Style.panel(holder :: Frame, "Panel")
			local card = Style.card(holder :: Frame, "Card")
			expect((panel:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).to.equal(
				UDim.new(0, Style.RADIUS.MODAL)
			)
			expect((card:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).to.equal(
				UDim.new(0, Style.RADIUS.CARD)
			)
			expect(panel.BackgroundTransparency).to.be.near(Style.PANEL_T, 1e-5)
			expect(card.BackgroundTransparency).to.be.near(Style.CARD_T, 1e-5)
			-- §1.3's ladder: a thing that sits on another thing is one step LESS ROUND.
			expect(Style.RADIUS.MODAL > Style.RADIUS.CARD).to.equal(true)
			expect(Style.RADIUS.CARD > Style.RADIUS.ROW).to.equal(true)
			expect(Style.RADIUS.ROW > Style.RADIUS.CHIP).to.equal(true)
			expect(Style.RADIUS.CHIP > Style.RADIUS.TAG).to.equal(true)
		end)

		it("builds a stat chip whose caption follows its number and never wraps", function()
			local chip, value, caption = Style.statChip(holder :: Frame, "Probe", 1280)
			expect(chip.AutomaticSize).to.equal(Enum.AutomaticSize.X)
			expect(value.FontFace).to.equal(Style.FONT.OSWALD_SB)
			expect(value.TextSize).to.equal(Style.sizeFor("STAT", 1280))
			expect(caption.FontFace).to.equal(Style.FONT.SANS_BOLD)
			expect(caption.TextSize).to.equal(Style.sizeFor("MICRO", 1280))
			expect(caption.TextColor3).to.equal(Style.LOOK.FIELD_MUTED)
			-- §3.9: the caption sits AFTER the number.
			expect(value.LayoutOrder < caption.LayoutOrder).to.equal(true)
			-- NO CHIP EVER WRAPS and `TextScaled` is banned (§1.2, §3.9).
			for _, label in ipairs({ value, caption }) do
				expect(label.TextWrapped).to.equal(false)
				expect(label.TextScaled).to.equal(false)
			end
			-- EVERY LABEL OF A SURFACE SITS ABOVE IT (§3's rule). `src/client/Hud/init.luau` has paid
			-- for this twice: *"the panel reads, the words do not"* (task 159).
			expect(value.ZIndex > chip.ZIndex).to.equal(true)
			expect(caption.ZIndex > chip.ZIndex).to.equal(true)
		end)

		it("builds a §3.12 table row: a rule, a team bar, and one label per cell", function()
			-- THE COMPONENT BOTH TABLES ARE BUILT FROM (task 201 part 2). The results board and the
			-- TAB report draw the same row, which is the whole of what §3.12 asks for -- and the
			-- monospace alignment they used until now is gone with `Enum.Font.Code`: *"the numbers
			-- line up because they are PLACED, not because every glyph is one width"* (§1.2).
			local row = Style.tableRow(holder :: Frame, "Probe", 1280, 400)
			expect(row.Size).to.equal(UDim2.fromOffset(400, Style.rowHeight(1280)))
			expect(Style.rowHeight(1280)).to.equal(28)
			expect(Style.rowHeight(400)).to.equal(24)
			-- A RULE AT THE BOTTOM, 1 px of `LINE` at 0.55 (§3.12).
			local rule = row:FindFirstChild("Rule") :: Frame
			expect(rule).to.be.ok()
			expect(rule.BackgroundColor3).to.equal(Style.LOOK.LINE)
			expect(rule.BackgroundTransparency).to.be.near(0.55, 1e-5)
			expect(rule.Size).to.equal(UDim2.new(1, 0, 0, 1))
			-- A 3 px LEFT BAR, built and hidden: a row cannot acquire a bar it has no way to lose.
			local bar = row:FindFirstChild("Bar") :: Frame
			expect(bar).to.be.ok()
			expect(bar.Size).to.equal(UDim2.new(0, 3, 1, 0))
			expect(bar.Visible).to.equal(false)
			expect(row.BackgroundTransparency).to.equal(1)

			-- YOUR OWN ROW is `ROW_SELECTED` with the bar in your TEAM's colour; the report's
			-- selected row is `ROW_HOVER`; everybody else's row is transparent and bare.
			Style.rowState(row, true, "Drivers")
			expect(row.BackgroundTransparency).to.equal(0)
			expect(row.BackgroundColor3).to.equal(Style.LOOK.ROW_SELECTED)
			expect(bar.Visible).to.equal(true)
			expect(bar.BackgroundColor3).to.equal(Style.LOOK.BEATER)
			Style.rowState(row, true, "Shooters")
			expect(bar.BackgroundColor3).to.equal(Style.LOOK.HUNTER)
			Style.rowState(row, false, nil, true)
			expect(row.BackgroundColor3).to.equal(Style.LOOK.ROW_HOVER)
			expect(bar.Visible).to.equal(false)
			Style.rowState(row, false, nil, false)
			expect(row.BackgroundTransparency).to.equal(1)

			-- ONE `TextLabel` PER CELL, placed at an x and a width. A NUMBER is right-aligned, which
			-- is what makes a column of them read as a column.
			local name = Style.cell(row, "name", 1280, 28, 160, false)
			local points = Style.cell(row, "points", 1280, 300, 80, true)
			expect(name.Position).to.equal(UDim2.fromOffset(28, 0))
			expect(points.Size).to.equal(UDim2.new(0, 80, 1, 0))
			expect(name.TextXAlignment).to.equal(Enum.TextXAlignment.Left)
			expect(points.TextXAlignment).to.equal(Enum.TextXAlignment.Right)
			expect(points.FontFace).to.equal(Style.FONT.OSWALD_MD)
			expect(points.TextTruncate).to.equal(Enum.TextTruncate.AtEnd)
			-- EVERY LABEL SITS ABOVE THE ROW IT IS IN (§3's rule, paid for twice in this repo).
			expect(name.ZIndex > row.ZIndex).to.equal(true)
		end)

		it("builds a §3.7 tag that always carries its word, and a §3.5 close button of two Frames", function()
			-- A STATE IS NEVER COLOUR ALONE: a clay row also says `WOUNDED`, so the tag carries text.
			local tag, word = Style.tag(holder :: Frame, "Probe", Style.LOOK.PINE_TEXT, 1280)
			expect(tag.BackgroundColor3).to.equal(Style.LOOK.PINE_TEXT)
			expect(tag.BackgroundTransparency).to.be.near(0.84, 1e-5)
			expect((tag:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).to.equal(
				UDim.new(0, Style.RADIUS.TAG)
			)
			expect(word.TextColor3).to.equal(Style.LOOK.PINE_TEXT)
			expect(word.TextSize).to.equal(Style.sizeFor("MICRO", 1280))

			-- THE X IS TWO ROTATED FRAMES and not a glyph, so no font has to carry it.
			local close = Style.closeButton(holder :: Frame, "Close")
			expect(close.Text).to.equal("")
			expect(close.Size).to.equal(UDim2.fromOffset(44, 44))
			local bars = 0
			for _, node in ipairs(close:GetChildren()) do
				if node:IsA("Frame") then
					bars += 1
					expect(math.abs((node :: Frame).Rotation)).to.equal(45)
				end
			end
			expect(bars).to.equal(2)
		end)

		it("builds a toast as its own slate with a meaning dot", function()
			local toast, dot, text = Style.toast(holder :: Frame, "Probe", 1280)
			expect(toast.BackgroundColor3).to.equal(Style.LOOK.SLATE)
			expect(toast.BackgroundTransparency).to.be.near(Style.SLATE_T, 1e-5)
			expect(toast.AutomaticSize).to.equal(Enum.AutomaticSize.XY)
			expect(dot.Size).to.equal(UDim2.fromOffset(6, 6))
			expect(text.FontFace).to.equal(Style.FONT.SANS_SEMI)
			expect(text.TextSize).to.equal(Style.sizeFor("LABEL", 1280))
		end)

		it("builds a progress bar that is a clock and not a tween", function()
			local track, fill =
				Style.bar(holder :: Frame, "Probe", Style.LOOK.LINE, Style.LOOK.LINE, Style.LOOK.PAPER, 3)
			expect(track.BackgroundColor3).to.equal(Style.LOOK.LINE)
			expect((track:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).to.equal(
				UDim.new(0, Style.RADIUS.BAR)
			)
			-- It starts EMPTY and the caller fills it; §7 refuses the other direction outright.
			expect(fill.Size).to.equal(UDim2.fromScale(0, 1))
			expect(fill:IsDescendantOf(track)).to.equal(true)
		end)
	end)

	describe("the surfaces read the source", function()
		it("has no `Enum.Font.Code` and no black stroke left on the surfaces task 201 part 1 touched", function()
			-- THE ACCEPTANCE TEST OF §6, NARROWED TO THIS TASK'S SEVEN SURFACES and asked of the
			-- LIVE SCREEN rather than of a grep: the status bar, the objective line, the compass,
			-- the rail, the ammo chip, the horn chip and the toast feed.
			--
			-- WHAT IS LEFT ELSEWHERE IS LISTED AND NOT SILENTLY PASSED: the results board, the TAB
			-- report, the tied banner, the start card, the hit card's header, the map and the
			-- way-mark are tasks C, D and E of the system's own build order, and they still carry
			-- both. That is why this walks NAMED roots and not the whole `ScreenGui`.
			local roots = {}
			for _, node in ipairs({
				Hud.statusChip("Drive"),
				Hud.statusChip("Clock"),
				Hud.statusRolePill(),
				Hud.objectiveSlate(),
				Hud.compass(),
				Hud.rail(),
				Hud.ammoChip(),
				Hud.hornChip(),
				Hud.feed(),
			}) do
				if node ~= nil then
					table.insert(roots, node)
				end
			end
			expect(#roots >= 8).to.equal(true)

			local offenders = {}
			for _, root in ipairs(roots) do
				local nodes = (root :: Instance):GetDescendants()
				table.insert(nodes, root :: Instance)
				for _, node in ipairs(nodes) do
					if node:IsA("TextLabel") or node:IsA("TextButton") then
						local text = node :: any
						if text.Font == Enum.Font.Code then
							table.insert(offenders, node:GetFullName() .. " (Code)")
						end
						if text.TextScaled then
							table.insert(offenders, node:GetFullName() .. " (TextScaled)")
						end
					end
					if node:IsA("UIStroke") and node.Color == Color3.new(0, 0, 0) then
						table.insert(offenders, node:GetFullName() .. " (black stroke)")
					end
				end
			end
			expect(table.concat(offenders, ", ")).to.equal("")
			TestKit.note(string.format("hud_style: %d surfaces clear of Code and black strokes", #roots))
		end)

		it("is clear of Code, white and black strokes over the WHOLE Hud (the system's §6 test)", function()
			-- THE ACCEPTANCE TEST OF THE WHOLE SYSTEM (§6, after part E), asked of the LIVE SCREEN
			-- and not of a grep. The case above narrowed it to part 1's seven surfaces because C, D
			-- and E had not landed; this one walks every descendant of the `ScreenGui`.
			--
			-- WHAT THE GREP CANNOT SEE AND THIS CAN: a colour read from another module's config
			-- (the map's marks came from `Drive.CONFIG` and would have passed every grep while
			-- drawing `#FFA03C`), and a stroke added at RUN time rather than at build time.
			local gui = Hud.gui() :: ScreenGui
			expect(gui).to.be.ok()
			local banned = {
				[tostring(Color3.fromRGB(255, 255, 255))] = "white",
				[tostring(Color3.fromHex("101214"))] = "101214",
				[tostring(Color3.fromHex("EB5A37"))] = "EB5A37",
				[tostring(Color3.fromHex("5A96FF"))] = "5A96FF",
				[tostring(Color3.fromHex("FFA03C"))] = "FFA03C",
				[tostring(Color3.fromHex("FFE896"))] = "FFE896",
			}
			local offenders = {}
			local labels, strokes = 0, 0
			for _, node in ipairs(gui:GetDescendants()) do
				if node:IsA("TextLabel") or node:IsA("TextButton") then
					labels += 1
					local text = node :: any
					if text.Font == Enum.Font.Code then
						table.insert(offenders, node:GetFullName() .. " (Code)")
					end
					if text.TextScaled then
						table.insert(offenders, node:GetFullName() .. " (TextScaled)")
					end
					local tint = banned[tostring(text.TextColor3)]
					if tint ~= nil then
						table.insert(offenders, string.format("%s (text %s)", node:GetFullName(), tint))
					end
				end
				if node:IsA("UIStroke") then
					strokes += 1
					-- BLACK IS BANNED ON TEXT, which is what §2 actually says: *"UIStroke whose
					-- Color is `Color3.new(0, 0, 0)` -- on any TextLabel"*. THE ONE BLACK STROKE
					-- LEFT IN THE GAME is the scope's MASK, and it is not an outline at all: it is
					-- the paint OUTSIDE the eyepiece, a stroke thicker than the screen's diagonal
					-- on a circle, and §5 surface 20 says in so many words *"Mask stays
					-- `#000000`"*. It is excluded BY NAME AND BY PARENT so nothing else can hide
					-- behind the exemption.
					local parent = node.Parent
					local isScopeMask = node.Name == "Edge" and parent ~= nil and parent.Name == "Mask"
					if node.Color == Color3.new(0, 0, 0) and not isScopeMask then
						table.insert(offenders, node:GetFullName() .. " (black stroke)")
					end
				end
				if node:IsA("Frame") then
					-- A FRAME'S FILL CARRIES THE OLD PALETTE TOO. The minimap's own marker was
					-- `#FFE896` and its rim `#E6E6E6`; neither is text, and neither would have been
					-- caught by a grep for a font or a stroke.
					local fill = node :: Frame
					local tint = banned[tostring(fill.BackgroundColor3)]
					if tint ~= nil and fill.BackgroundTransparency < 1 then
						table.insert(offenders, string.format("%s (fill %s)", node:GetFullName(), tint))
					end
				end
			end
			expect(table.concat(offenders, ", ")).to.equal("")
			expect(labels > 40).to.equal(true)
			TestKit.note(
				string.format(
					"hud_style: §6 acceptance over the whole Hud -- %d labels, %d strokes, 0 offenders",
					labels,
					strokes
				)
			)
		end)

		it("collapses a repeated feed line into one line with a count, and caps the feed at 3", function()
			-- THE DIRECTOR, 2026-10-19, after `t212r2-blow-fp.png`: *"the toast feed stacks
			-- identical lines ('a boar got away' x5 for a beater): collapse repeats into one line
			-- with a count ('a boar got away x5') and cap the feed at 3."*
			--
			-- EVERY ARM, AND NOT ONLY THE ONE THE SCREENSHOT SHOWS: a new line, a repeat, an
			-- INTERLEAVED repeat (the arm a consecutive-only collapse would get wrong), and the
			-- over-cap drop.
			local now = os.clock()
			-- A CLEAN SLATE, AND IT REALLY IS ONE: `Hud.clearFeedForTests` empties the list. A push
			-- with an ancient timestamp would NOT have cleared it -- `pushFeed` appends to the
			-- newest end and `renderFeed` trims from the front.
			Hud.clearFeedForTests()
			Hud.renderFeedForTests(now)
			expect(#Hud.feedText()).to.equal(0)

			-- ARM 1: a new line is count 1 and reads as itself.
			local first = Hud.pushFeed("a boar got away", "bad", now)
			expect(first.count).to.equal(1)
			expect(Hud.feedLineText(first)).to.equal("a boar got away")

			-- ARM 2: the same sentence again is ONE line with a count, not two lines.
			Hud.pushFeed("a boar got away", "bad", now)
			Hud.renderFeedForTests(now)
			local shown = Hud.feedText()
			expect(#shown).to.equal(1)
			expect(shown[1]).to.equal("a boar got away x2")

			-- ARM 3: INTERLEAVED. Something else happens, then the escape repeats: still two lines,
			-- and the repeat is the NEWEST, because it is what just happened.
			Hud.pushFeed("Anna tied to a tree", "bad", now)
			local third = Hud.pushFeed("a boar got away", "bad", now)
			expect(third.count).to.equal(3)
			Hud.renderFeedForTests(now)
			shown = Hud.feedText()
			expect(#shown).to.equal(2)
			expect(shown[1]).to.equal("Anna tied to a tree")
			expect(shown[2]).to.equal("a boar got away x3")

			-- ...and the meaning survives a repeat that carried none.
			local keeps = Hud.pushFeed("a boar got away", nil, now)
			expect(keeps.meaning).to.equal("bad")

			-- ARM 4: THE CAP. Five DISTINCT lines, and only the newest three are on screen.
			for index = 1, 5 do
				Hud.pushFeed(string.format("line %d", index), "info", now)
			end
			Hud.renderFeedForTests(now)
			shown = Hud.feedText()
			expect(#shown).to.equal(Style.FEED_LINES)
			expect(Style.FEED_LINES).to.equal(3)
			expect(shown[#shown]).to.equal("line 5")
			expect(shown[1]).to.equal("line 3")
			-- THE SLOTS THEMSELVES ARE THE CAP TOO, which is the half an entry-list test cannot
			-- answer: a fourth toast cannot appear because a fourth toast was never built.
			expect(#Hud.feedToasts()).to.equal(Style.FEED_LINES)

			-- Left as it was found, so the next case does not inherit this one's five lines.
			Hud.clearFeedForTests()
			Hud.renderFeedForTests(now)
			TestKit.note("hud_style: feed collapse -- new, repeat, interleaved repeat, over-cap drop")
		end)

		it("draws the map in the palette, with a brass rim and a scrim that follows it", function()
			-- §5 SURFACES 4 AND 14. The marks were `Drive.CONFIG`'s three colours and the rim was
			-- `#E6E6E6`; a grep over `src/client/` would have passed on every one of them, because
			-- those hexes live in `src/shared/Drive/`.
			local mini = Hud.minimap() :: Frame
			local full = Hud.fullMap() :: Frame
			expect(mini).to.be.ok()
			expect(full).to.be.ok()
			-- The minimap is a QUIET SLATE: it carries 9-11 px labels (§2's second opacity).
			expect(mini.BackgroundColor3).to.equal(Style.LOOK.SLATE)
			expect(mini.BackgroundTransparency).to.be.near(Style.SLATE_QUIET_T, 1e-6)
			local rim = mini:FindFirstChildOfClass("UIStroke") :: UIStroke
			expect(rim).to.be.ok()
			expect(rim.Color).to.equal(Style.LOOK.BRASS)
			expect(rim.Transparency).to.be.near(Style.EDGE_T.SLATE, 1e-6)
			expect(rim.Thickness).to.equal(2)
			-- The full map is a PANEL: opaque, corner 16, brass edge at the panel's own opacity.
			expect(full.BackgroundColor3).to.equal(Style.LOOK.PANEL)
			expect(full.BackgroundTransparency).to.be.near(Style.PANEL_T, 1e-6)
			local corner = full:FindFirstChildOfClass("UICorner") :: UICorner
			expect(corner).to.be.ok()
			expect(corner.CornerRadius).to.equal(UDim.new(0, Style.RADIUS.MODAL))
			local edge = full:FindFirstChildOfClass("UIStroke") :: UIStroke
			expect(edge.Color).to.equal(Style.LOOK.BRASS)
			expect(edge.Transparency).to.be.near(Style.EDGE_T.PANEL, 1e-6)
			-- ...AND ITS SCRIM FOLLOWS IT EXACTLY, in both directions. A scrim left up over a shut
			-- map is a dark screen with nothing to explain it.
			local scrim = Hud.mapScrim() :: Frame
			expect(scrim).to.be.ok()
			expect(scrim.BackgroundColor3).to.equal(Style.LOOK.SCRIM)
			expect(scrim.BackgroundTransparency).to.be.near(Style.SCRIM_T, 1e-6)
			expect(scrim.ZIndex < full.ZIndex).to.equal(true)
			expect(scrim.Visible).to.equal(full.Visible)
			local was = Hud.MapUi.isOpen()
			Hud.MapUi.setOpen(not was)
			expect(scrim.Visible).to.equal(full.Visible)
			Hud.MapUi.setOpen(was)
			expect(scrim.Visible).to.equal(full.Visible)
			TestKit.note(
				string.format(
					"hud_style: map rim brass, scrim follows panel (open=%s, drawn=%s)",
					tostring(Hud.MapUi.isOpen()),
					tostring(full.Visible)
				)
			)
		end)

		it("gives the way-mark's word its own slate, and dims all of it when pinned", function()
			-- §5 SURFACE 21: *"the word (`STAND` / `LINE` / `ROAD` / `TRUCK`) gets its own tiny
			-- slate so it reads over sky, instead of a stroke. Pinned stays dimmer (T 0.45)."*
			local view = CFrame.new(Vector3.new(0, 0, 0))
			local viewport = Vector2.new(1920, 1080)
			local word = Hud.waypointWord() :: TextLabel
			local slate = Hud.waypointSlate() :: Frame
			expect(slate).to.be.ok()
			-- THE WORD IS IN THE SLATE and not beside it: a slate the word is not inside is a tile
			-- with a word floating next to it.
			expect(word.Parent).to.equal(slate)
			expect(slate.BackgroundColor3).to.equal(Style.LOOK.SLATE)
			expect(word.ZIndex > slate.ZIndex).to.equal(true)

			local ahead = { point = Vector3.new(0, 0, -100), word = "ROAD", kind = "road" }
			Hud.Objective.render({
				text = "",
				target = ahead,
				distanceStuds = 100,
				view = view,
				fovDeg = 70,
				viewport = viewport,
				lineVisible = false,
				markVisible = true,
			})
			expect(slate.Visible).to.equal(true)
			expect(slate.BackgroundTransparency).to.be.near(Style.SLATE_QUIET_T, 1e-6)
			local slateEdge = slate:FindFirstChildOfClass("UIStroke") :: UIStroke
			expect(slateEdge.Transparency).to.be.near(Style.EDGE_T.SLATE, 1e-6)

			-- PINNED: the chevron, the word AND the slate all dim together, from the one number.
			local behind = { point = Vector3.new(5000, 0, 100), word = "STAND", kind = "stand" }
			Hud.Objective.render({
				text = "",
				target = behind,
				distanceStuds = 5000,
				view = view,
				fovDeg = 70,
				viewport = viewport,
				lineVisible = false,
				markVisible = true,
			})
			local pinned = Hud.Objective.CONFIG.PINNED_TRANSPARENCY
			expect(Hud.Objective.isMarkPinned()).to.equal(true)
			expect(word.TextTransparency).to.be.near(pinned, 1e-6)
			expect(slate.BackgroundTransparency > Style.SLATE_QUIET_T).to.equal(true)
			expect(slateEdge.Transparency > Style.EDGE_T.SLATE).to.equal(true)

			-- ...and nothing of the three is left on screen when there is nowhere to go.
			Hud.Objective.render({
				text = "",
				target = nil,
				distanceStuds = nil,
				view = view,
				fovDeg = 70,
				viewport = viewport,
				lineVisible = false,
				markVisible = false,
			})
			expect(slate.Visible).to.equal(false)
			expect(word.Visible).to.equal(false)
			expect((Hud.waypoint() :: Frame).Visible).to.equal(false)
		end)

		it("rims the scope in the system's darkest surface, with a brass ring on the glass", function()
			-- §5 SURFACE 20: *"Mask stays `#000000`; the rim goes from the flat grey of
			-- `t146-scope-aim.png` to `#0A0907` with a 1 px inner `BRASS` @ 0.70 ring"*. The two
			-- colours came off `Rifle.CONFIG.scope.eyepiece` until task 201 E; the tube's GEOMETRY
			-- is the weapon's and its COLOUR is the system's
			-- (`backups/2026-10-19_rifle-eyepiece-colours.txt`).
			local overlay = Hud.scopeOverlay() :: Frame
			expect(overlay).to.be.ok()
			local optics = {
				aimFovDeg = 20,
				eyepiece = { atBlend = 0.98, diameterDeg = 21, rimThickDeg = 1.69, maskTransparency = 0.45 },
			}
			-- HANDED ITS INPUTS, for the reason every other render case here is: a spec cannot
			-- raise a rifle, and `layoutScope` writes nothing but the nodes it is given.
			Hud.layoutScope(overlay, optics, 20)
			local mask = overlay:FindFirstChild("Mask") :: Frame
			local rim = overlay:FindFirstChild("Rim") :: Frame
			local bezel = overlay:FindFirstChild("Bezel") :: Frame
			expect(mask).to.be.ok()
			expect(rim).to.be.ok()
			expect(bezel).to.be.ok()
			expect((mask:FindFirstChild("Edge") :: UIStroke).Color).to.equal(Style.SCOPE_MASK)
			expect((rim:FindFirstChild("Edge") :: UIStroke).Color).to.equal(Style.LOOK.SCRIM)
			local ring = bezel:FindFirstChildOfClass("UIStroke") :: UIStroke
			expect(ring).to.be.ok()
			expect(ring.Color).to.equal(Style.LOOK.BRASS)
			expect(ring.Transparency).to.be.near(Style.SCOPE_RING_T, 1e-6)
			expect(ring.Thickness).to.equal(1)
			-- THE RING IS ON THE GLASS'S EDGE, which is the rim's INNER size and not the tube's
			-- outer one: a ring drawn at the outer diameter would sit in the black.
			expect(bezel.Size.X.Offset).to.equal(rim.Size.X.Offset)
			expect(bezel.Size.X.Offset < mask.Size.X.Offset).to.equal(true)
			expect(bezel.ZIndex > mask.ZIndex).to.equal(true)
			TestKit.note(
				string.format(
					"hud_style: scope glass %d px inside a %d px tube, brass ring on it",
					bezel.Size.X.Offset,
					mask.Size.X.Offset
				)
			)
		end)

		it("backs every word of the top band with a slate, and no word with an outline", function()
			-- §2 is the rule this task exists to apply: *"Text over the 3-D world always sits on a
			-- backing panel. It never wears a black `UIStroke`."*
			local bar = Hud.gui():FindFirstChild("DriveBar") :: Frame
			expect(bar).to.be.ok()
			expect(bar.BackgroundColor3).to.equal(Style.LOOK.SLATE)
			expect(bar.BackgroundTransparency).to.be.near(Style.SLATE_T, 1e-5)

			local slate = Hud.objectiveSlate() :: Frame
			expect(slate).to.be.ok()
			expect(slate.BackgroundColor3).to.equal(Style.LOOK.SLATE)
			local line = Hud.objectiveLine() :: TextLabel
			expect(line:IsDescendantOf(slate)).to.equal(true)
			expect(line.FontFace).to.equal(Style.FONT.OSWALD_MD)
			expect(line.TextColor3).to.equal(Style.LOOK.PAPER)

			-- The compass is a QUIET slate, because it carries 10-11 px type (§3.3).
			local strip = Hud.compass() :: Frame
			expect(strip.BackgroundColor3).to.equal(Style.LOOK.SLATE)
			expect(strip.BackgroundTransparency).to.be.near(Style.SLATE_QUIET_T, 1e-5)
			expect(Compass.CONFIG.BACKGROUND).to.equal(Style.LOOK.SLATE)
			expect(Compass.CONFIG.LABEL_COLOR).to.equal(Style.LOOK.PAPER)
			expect(Compass.CONFIG.CENTRE_COLOR).to.equal(Style.LOOK.BRASS_HI)
		end)

		it("has ONE go-here colour, and it is the blaze", function()
			-- §1.1: *"Two reds became one. `#EB5A37` -- today's compass / chevron / map 'go here'
			-- red -- is deleted; that mark is now `BLAZE_HI`. Clay is therefore the only red-ish
			-- thing on screen, and it always means something went wrong."*
			expect(Compass.CONFIG.DRIVE_COLOR).to.equal(Style.LOOK.BLAZE_HI)
			expect(Objective.CONFIG.MARK_COLOR).to.equal(Style.LOOK.BLAZE_HI)
			expect(Objective.CONFIG.GO_COLOR).to.equal(Style.LOOK.BLAZE_HI)
			expect(Compass.CONFIG.DRIVE_COLOR).to.equal(Objective.CONFIG.MARK_COLOR)
			-- ...and the GO line is the only sentence that takes it.
			expect(Objective.isGo(Objective.CONFIG.TEXT.DriverGo)).to.equal(true)
			expect(Objective.isGo(Objective.CONFIG.TEXT.Shooters.Running)).to.equal(false)
			expect(Objective.isGo(Objective.CONFIG.TEXT.Drivers.Running)).to.equal(false)
		end)

		it("draws the rail as a ghost over the world, with a brass key hint", function()
			-- §3.5 "Ghost": no fill of its own on a panel, a QUIET slate over the world, a `LINE`
			-- stroke at 0.35, `FIELD_MUTED` label and a `MICRO` Bold BRASS key hint under it.
			expect(Rail.CONFIG.BACKGROUND).to.equal(Style.LOOK.SLATE)
			expect(Rail.CONFIG.TRANSPARENCY).to.equal(Style.SLATE_QUIET_T)
			expect(Rail.CONFIG.RIM_COLOR).to.equal(Style.LOOK.LINE)
			expect(Rail.CONFIG.TEXT_COLOR).to.equal(Style.LOOK.FIELD_MUTED)
			expect(Rail.CONFIG.KEY_COLOR).to.equal(Style.LOOK.BRASS)
			local drawn = Rail.buttonIds()
			if #drawn == 0 then
				-- The rail can be legitimately empty (suppressed, covered, or no weapon), and that
				-- is stated rather than passed over: the CONFIG above is still the claim.
				TestKit.note("hud_style: the rail drew no button in this run; config asserted only")
				return
			end
			local node = Rail.button(drawn[1]) :: TextButton
			local word = node:FindFirstChild("Label") :: TextLabel
			local hint = node:FindFirstChild("Key") :: TextLabel
			expect(word).to.be.ok()
			expect(hint).to.be.ok()
			expect(word.FontFace).to.equal(Style.FONT.SANS_SEMI)
			expect(word.TextColor3).to.equal(Style.LOOK.FIELD_MUTED)
			expect(hint.FontFace).to.equal(Style.FONT.SANS_BOLD)
			expect(hint.TextColor3).to.equal(Style.LOOK.BRASS)
			-- The hint is 9 px and uppercase, so it is letter-spaced (§1.2).
			expect(string.find(hint.Text, " ", 1, true) ~= nil or #hint.Text == 1).to.equal(true)
			-- THE BUTTON ITSELF SAYS NOTHING: the words are children, so a press can nudge them.
			expect(node.Text).to.equal("")
			expect(node.AutoButtonColor).to.equal(false)
		end)

		it("keeps the top band's rectangles stacked, and the status slate inside its column", function()
			-- The band this task moved, as arithmetic, at the viewport `hud_clarity.spec` cannot
			-- resize to. 8..38 objective, 40..74 status, 74..104 tied banner, 108..138 compass.
			local x, y, width, height = Hud.statusRect(Vector2.new(1280, 720))
			expect(y).to.equal(Hud.STATUS.TOP)
			expect(height).to.equal(Hud.STATUS.HEIGHT)
			expect(width).to.equal(1280 - 2 * Hud.STATUS.SIDE_INSET)
			expect(x).to.equal((1280 - width) / 2)
			-- IT STOPS SHORT OF THE RIGHT COLUMN (§4.3 rule 2), which is the rail's own width plus
			-- its margin plus a gap -- read off the rail rather than typed again.
			expect(Hud.STATUS.SIDE_INSET > Rail.CONFIG.BUTTON_PX + Rail.CONFIG.MARGIN + 8).to.equal(true)
			-- ...and a phone gets the full width less a gutter, because there is no column beside it.
			local px, _, pw = Hud.statusRect(Vector2.new(400, 800))
			expect(pw).to.equal(400 - 2 * Hud.STATUS.SIDE_INSET_PHONE)
			expect(px).to.equal(Hud.STATUS.SIDE_INSET_PHONE)
			-- The three bands do not land on one another at either viewport.
			local _, oy, _, oh = Objective.lineRect(Vector2.new(1280, 720))
			expect(oy + oh <= Hud.STATUS.TOP).to.equal(true)
			expect(Hud.STATUS.TOP + Hud.STATUS.HEIGHT <= Compass.CONFIG.TOP).to.equal(true)
			expect(Compass.CONFIG.TOP + Compass.CONFIG.HEIGHT <= Hud.MapUi.CONFIG.MINIMAP_TOP).to.equal(true)
		end)

		it("never prints `--` or a nil on the status bar, whatever this run's phase is", function()
			-- §3.9: *"A chip whose value is unknown is not drawn -- it never shows `--`."* Asked of
			-- the LIVE bar, so it is valid in whatever phase the run happens to be in -- the shape
			-- `hud_clarity.spec`'s own live case uses, and the reason it needs no phase arranged.
			local text = Hud.driveBarText()
			expect(string.find(text, Money.UNKNOWN, 1, true)).to.equal(nil)
			expect(string.find(text, "nil", 1, true)).to.equal(nil)
			-- ...and the words are the chips' own: whatever is drawn is in it, and nothing else is.
			local bar = Hud.gui():FindFirstChild("DriveBar") :: Frame
			if bar.Visible then
				expect(#text > 0).to.equal(true)
			end
			TestKit.note("hud_style: status bar reads " .. string.format("%q", text))
			-- THE QUARRY CHIP SAYS `ANIMALS` AND NEVER `BOARS` (task 231). The number it carries has
			-- always counted every animal the drive accounted for -- `Phase.step` adds one on any
			-- `kill` or `gone` whatever the species -- and since task 230 a drive carries red deer,
			-- so the word was the only wrong part. Asserted on the LIVE bar, in whatever phase this
			-- run is in: the chip is hidden in `Waiting`, so the claim is "if it is drawn it says
			-- ANIMALS", which is what a player can ever read.
			expect(string.find(text, "BOARS", 1, true)).to.equal(nil)
			local quarry = (Hud.gui() :: ScreenGui):FindFirstChild("DriveBar", true)
			local chip = quarry and quarry:FindFirstChild("Boars")
			if chip ~= nil and (chip :: Frame).Visible then
				expect(string.find(text, "ANIMALS", 1, true)).to.be.ok()
			end
		end)

		it("maps a feed entry to one meaning, and the dot and the words take it together", function()
			expect(Hud.feedMeaningFor({ kind = "kill" })).to.equal("good")
			expect(Hud.feedMeaningFor({ kind = "escape" })).to.equal("bad")
			expect(Hud.feedMeaningFor({ kind = "violation" })).to.equal("bad")
			expect(Hud.feedMeaningFor({ kind = "join" })).to.equal("info")
			expect(Hud.feedMeaningFor({})).to.equal("info")
			-- ON THE SCREEN. One kill through the real handler, then the toast it drew: the dot and
			-- the words must be the SAME colour, because they are one answer.
			Hud.onKilled({ name = "StyleSpec", userId = player.UserId, zone = "chest", distance = 30 })
			local toasts = Hud.feedToasts()
			expect(#toasts > 0).to.equal(true)
			local shown = nil
			for _, toast in ipairs(toasts) do
				if toast.Visible then
					shown = toast
				end
			end
			expect(shown).to.be.ok()
			local dot = (shown :: Frame):FindFirstChild("Dot") :: Frame
			local text = (shown :: Frame):FindFirstChild("Text") :: TextLabel
			expect(dot).to.be.ok()
			expect(text).to.be.ok()
			expect(dot.BackgroundColor3).to.equal(text.TextColor3)
			expect(dot.BackgroundColor3).to.equal(Style.LOOK.PINE_TEXT)
			TestKit.note("hud_style: kill toast drew " .. text.Text)
		end)

		it("reserves the toast feed's REAL height, so a full stack cannot reach the hit card", function()
			-- ROUND 1, BLOCKING FINDING 2. `Hud.feedHeight` was `FEED_LINES * 28` against a toast
			-- that measures 30 with a 6 px gap, so the stack came to more than its reservation --
			-- and the feed frame has no `ClipsDescendants`, so it grew onto the hit card. A full
			-- stack inside `FEED_SECONDS` is reachable: `renderFeed` trims only past the cap.
			--
			-- THE CAP IS `Style.FEED_LINES` SINCE TASK 201 E and it is 3, not `Drive.CONFIG`'s 5
			-- (the Director, 2026-10-19). Both of this case's numbers move with it.
			local viewX = Hud.viewportX()
			local toast = Style.toastHeight(viewX)
			local lines = Style.FEED_LINES
			-- THE NUMBERS AND NOT THE EXPRESSION (round 2 note): restating `feedHeight`'s own
			-- arithmetic back at it is a case that cannot fail. A desktop toast is 6 + 6 of slate
			-- padding around an 18 px line box, and three of them with two 6 px gaps is 102.
			expect(Style.toastHeight(1280)).to.equal(30)
			expect(Style.toastHeight(400)).to.equal(25)
			expect(Hud.feedHeight(1280)).to.equal(3 * 30 + 2 * 6)
			expect(Hud.feedHeight(viewX)).to.equal(lines * toast + (lines - 1) * Style.TOAST_GAP)
			-- THE NUMBER IS TRUE OF WHAT IS DRAWN, and that is the half the arithmetic cannot
			-- answer: every toast this Hud built is measured against it.
			local feed = Hud.feed() :: Frame
			expect(feed).to.be.ok()
			expect(feed.AbsoluteSize.Y >= lines * toast + (lines - 1) * Style.TOAST_GAP).to.equal(true)
			local tallest = 0
			for _, node in ipairs(Hud.feedToasts()) do
				tallest = math.max(tallest, node.AbsoluteSize.Y)
			end
			if tallest > 0 then
				expect(tallest <= toast + 1).to.equal(true)
			end
			-- ...and the hit card's reserved band really does start above the feed's.
			local card = Hud.hitCard() :: Frame
			expect(card).to.be.ok()
			local cardBottom = card.AbsolutePosition.Y + card.AbsoluteSize.Y
			local feedTop = feed.AbsolutePosition.Y
			expect(cardBottom <= feedTop + 1).to.equal(true)
			TestKit.note(
				string.format(
					"hud_style: toast %d px, feed reserves %d px, card bottom %d vs feed top %d",
					toast,
					Hud.feedHeight(viewX),
					cardBottom,
					feedTop
				)
			)
		end)

		it("starts no clock on the first look at a horn, and always on the first BLAST", function()
			-- BOTH HALVES HAVE BEEN WRONG ONCE EACH IN THIS TASK, which is why the latch is pure and
			-- why this case drives the EDGE rather than a frame: round 1 started the clock on the
			-- first stamp it saw (a horn handed back carrying an old stamp read `WAIT` although it
			-- was ready), and round 2 gated that on `seen ~= nil`, which SWALLOWED the first blast
			-- of every fresh horn -- `Weapon.Horn.blowTool` creates the attribute INSIDE the blast,
			-- so a horn that has never been blown carries none and nil is a real value of `seen`.
			local NOW = 100

			-- A BRAND-NEW HORN: no attribute at all. Primed, and nothing started.
			local seen, primed, at = Hud.hornBlowLatch(nil, false, nil, nil, NOW)
			expect(seen).to.equal(nil)
			expect(primed).to.equal(true)
			expect(at).to.equal(nil)
			-- ...and the player's own FIRST blast (nil -> 1) starts it.
			seen, primed, at = Hud.hornBlowLatch(seen, primed, at, 1, NOW + 2)
			expect(seen).to.equal(1)
			expect(at).to.equal(NOW + 2)
			-- A frame with no change moves nothing.
			local seen2, _, at2 = Hud.hornBlowLatch(seen, primed, at, 1, NOW + 3)
			expect(seen2).to.equal(1)
			expect(at2).to.equal(NOW + 2)
			-- ...and the next blast does.
			local _, _, at3 = Hud.hornBlowLatch(seen, primed, at, 2, NOW + 4)
			expect(at3).to.equal(NOW + 4)

			-- A HORN HANDED BACK ALREADY CARRYING A STAMP: primed at that value, clock untouched.
			local oldSeen, oldPrimed, oldAt = Hud.hornBlowLatch(nil, false, nil, 7, NOW)
			expect(oldSeen).to.equal(7)
			expect(oldPrimed).to.equal(true)
			expect(oldAt).to.equal(nil)
			-- ...and only a CHANGE after that is a blast this client watched.
			local _, _, laterAt = Hud.hornBlowLatch(oldSeen, oldPrimed, oldAt, 8, NOW + 1)
			expect(laterAt).to.equal(NOW + 1)
		end)

		it("draws the two tables from ONE row component, and the tied toast over the band", function()
			-- SURFACES 11, 12 AND 13 (task 201 part 2). What is checked is the thing that can
			-- actually drift: that both panels read the one source, and that the tied banner really
			-- is drawn ABOVE the band it deliberately covers.
			local board = Hud.scorePanel() :: Frame
			local report = Hud.reportPanel() :: Frame
			local scrim = Hud.reportScrim() :: Frame
			local tied = Hud.tiedBanner() :: Frame
			expect(board).to.be.ok()
			expect(report).to.be.ok()
			expect(scrim).to.be.ok()
			expect(tied).to.be.ok()

			-- THE BOARD IS A CARD and the REPORT IS A MODAL over a 0.42 scrim (§1.3): a non-modal
			-- surface lays no scrim and carries its own card, a modal lays one.
			expect(board.BackgroundTransparency).to.be.near(Style.CARD_T, 1e-5)
			expect(report.BackgroundTransparency).to.be.near(Style.PANEL_T, 1e-5)
			expect(scrim.BackgroundColor3).to.equal(Style.LOOK.SCRIM)
			expect(scrim.BackgroundTransparency).to.be.near(Style.SCRIM_T, 1e-5)
			expect(scrim.ZIndex < report.ZIndex).to.equal(true)
			-- The scrim goes with the panel: one owner of "is the report open".
			expect(scrim.Visible).to.equal(Hud.Report.isOpen())

			-- ONE ROW COMPONENT SERVES BOTH. A row of either table has the same three parts.
			local boardRow = (Hud.scoreBody() :: ScrollingFrame):FindFirstChild("Row1") :: Frame
			-- THE ROWS LIVE IN THE SCROLLING BODY since round 2, not in the clipping well.
			local reportRow = (Hud.Report.body :: ScrollingFrame):FindFirstChild("ListRow1")
			expect(boardRow).to.be.ok()
			expect(reportRow).to.be.ok()
			local reportInner = (reportRow :: Instance):FindFirstChild("Row") :: Frame
			expect(reportInner).to.be.ok()
			for _, row in ipairs({ boardRow, reportInner }) do
				expect((row :: Frame):FindFirstChild("Rule")).to.be.ok()
				expect((row :: Frame):FindFirstChild("Bar")).to.be.ok()
				expect((row :: Frame).Size.Y.Offset).to.equal(Style.rowHeight(Hud.viewportX()))
			end

			-- THE TIED BANNER IS A CLAY TOAST AT THE `TITLE` STEP, drawn OVER the compass's band --
			-- which §5 surface 13 asks for by putting it at y 96, inside 108..138. It is a notice,
			-- it is up for seconds, and a player roped to a tree is not walking anywhere.
			local text = tied:FindFirstChild("Text") :: TextLabel
			local dot = tied:FindFirstChild("Dot") :: Frame
			expect(text).to.be.ok()
			expect(text.TextColor3).to.equal(Style.LOOK.CLAY)
			expect(dot.BackgroundColor3).to.equal(Style.LOOK.CLAY)
			expect(text.TextSize).to.equal(Style.sizeFor("TITLE", Hud.viewportX()))
			expect(tied.BackgroundColor3).to.equal(Style.LOOK.SLATE)
			local compass = Hud.compass() :: Frame
			expect(tied.ZIndex > compass.ZIndex).to.equal(true)

			-- ...AND ITS WORDS ARE IN FRONT OF ITS OWN SLATE. ROUND 1, BLOCKING FINDING 3: the toast
			-- is parented to the `ScreenGui`, which is not a `GuiObject`, so `Style.toast`'s guard
			-- never fired -- the dot and the label were created at ZIndex 2 and the slate was raised
			-- to 7 a line later, leaving Karen's `TIED TO A TREE` as an empty clay rectangle under
			-- `ZIndexBehavior.Global`. That is the defect task 159 paid for twice.
			expect(text.ZIndex > tied.ZIndex).to.equal(true)
			expect(dot.ZIndex > tied.ZIndex).to.equal(true)
			-- The same rule, on the feed's own toasts, which take their band from the feed frame.
			for _, node in ipairs(Hud.feedToasts()) do
				local word = node:FindFirstChild("Text") :: TextLabel
				expect(word.ZIndex > node.ZIndex).to.equal(true)
			end
		end)

		it("opens the report and the SCRIM goes with it, and closes them together", function()
			-- ROUND 1 NOTE: the case above asserted `scrim.Visible == Hud.Report.isOpen()`, which is
			-- `false == false` with the report shut -- so it passed with the `setOpen` scrim write
			-- deleted. A case that cannot fail is worse than no case; this one opens the panel.
			local report = Hud.reportPanel() :: Frame
			local scrim = Hud.reportScrim() :: Frame
			local was = Hud.Report.isOpen()
			Hud.Report.setOpen(false)
			expect(scrim.Visible).to.equal(false)
			expect(report.Visible).to.equal(false)
			Hud.Report.setOpen(true)
			expect(report.Visible).to.equal(true)
			expect(scrim.Visible).to.equal(true)
			-- ...and the scrim is BEHIND the panel and in front of the world (§1.3's stacking).
			expect(scrim.ZIndex < report.ZIndex).to.equal(true)
			Hud.Report.setOpen(false)
			expect(scrim.Visible).to.equal(false)
			Hud.Report.setOpen(was)
		end)

		it("draws ONE of the ammo chip and the horn chip, never both", function()
			-- §4.3: *"BOTTOM RIGHT ammo chip OR horn chip -- alone, and only one of the two ever
			-- exists."* Whatever this run's role is, the rule is the same.
			local ammo = Hud.ammoChip() :: Frame
			local horn = Hud.hornChip() :: Frame
			expect(ammo).to.be.ok()
			expect(horn).to.be.ok()
			expect(ammo.Visible and horn.Visible).to.equal(false)
			-- They share one corner, which is what makes the rule necessary.
			expect(ammo.AnchorPoint).to.equal(horn.AnchorPoint)
			expect(ammo.Position).to.equal(horn.Position)
			TestKit.note(
				string.format("hud_style: corner ammo=%s horn=%s", tostring(ammo.Visible), tostring(horn.Visible))
			)
		end)

		it("reads the chambers as pips, and the magazine rifle as rounds held", function()
			-- PURE, and handed a state this case owns -- the reason `Hud.readoutFor` is exported:
			-- a driver holds no gun at all, and a one-player run can be tied to a tree.
			local breakAction = Hud.ammoChipFor({
				equipped = true,
				barrels = { "Live", "Spent" },
				loaded = { "Slug", "None" },
				selected = 2,
				ammo = "Slug",
				reserve = { Slug = 7 },
				busyFor = 0,
				weapon = "shotgun",
			} :: any)
			expect(#breakAction.pips).to.equal(2)
			expect(breakAction.pips[1]).to.equal("live")
			expect(breakAction.pips[2]).to.equal("spent")
			expect(breakAction.selected).to.equal(2)
			expect(breakAction.pocket).to.equal(7)
			expect(breakAction.busy).to.equal(false)

			local magazine = Hud.ammoChipFor(
				{
					equipped = true,
					barrels = { "Live", "Live", "Empty" },
					loaded = { "Slug", "Slug", "None" },
					selected = 1,
					ammo = "Slug",
					reserve = { Slug = 12 },
					busyFor = 1.2,
					weapon = "rifle",
				} :: any,
				{ READOUT = "magazine", MAGAZINE = 3, AMMO_LABEL = { Slug = "SLUG" } }
			)
			expect(#magazine.pips).to.equal(3)
			expect(magazine.pips[1]).to.equal("live")
			expect(magazine.pips[3]).to.equal("empty")
			-- A MAGAZINE HAS NO SELECTED CHAMBER: it is not two barrels and is not drawn as them.
			expect(magazine.selected).to.equal(nil)
			expect(magazine.label).to.equal("SLUG")
			expect(magazine.busy).to.equal(true)
		end)

		-- ---------------------------------------------------------------- the shell (task 204)
		--
		-- Karen, 2026-10-18: *"please diferenciate slug from shells"*. Her frame of the chip, and
		-- this task's reproduction of it, showed two chips that differed in ONE WORD.
		it("names a different shell for each load, and none for a gun that has one", function()
			local function chipFor(ammo: string, row: any?)
				return Hud.ammoChipFor(
					{
						equipped = true,
						barrels = { "Live", "Live" },
						loaded = { ammo, ammo },
						selected = 1,
						ammo = ammo,
						reserve = { [ammo] = 8 },
						busyFor = 0,
						weapon = "shotgun",
					} :: any,
					row
				)
			end
			local slug = chipFor("Slug")
			local buck = chipFor("Buck")
			expect(slug.glyph).to.equal("slug")
			expect(buck.glyph).to.equal("buck")
			expect(slug.glyph).never.to.equal(buck.glyph)
			expect(slug.label).never.to.equal(buck.label)
			-- THE SHOTGUN'S ROW IS WHERE THE MAPPING LIVES, not the wire word: the rifle's `Slug`
			-- is a .416 Rigby cartridge and must not be drawn as a shotgun shell.
			expect(Hud.ammoChipFor(
				{
					equipped = true,
					barrels = { "Live" },
					loaded = { "Slug" },
					selected = 1,
					ammo = "Slug",
					reserve = { Slug = 9 },
					busyFor = 0,
					weapon = "rifle",
				} :: any,
				{ READOUT = "magazine", MAGAZINE = 3, AMMO_LABEL = { Slug = ".416" } }
			).glyph).to.equal(nil)
			-- ...AND THE TWO ACCENTS ARE THE TWO HULL COLOURS, so the word and the glyph agree.
			expect(Hud.AMMO_ACCENT.slug).to.equal(Style.SHELL.slug.hull)
			expect(Hud.AMMO_ACCENT.buck).to.equal(Style.SHELL.buck.hull)
			expect(Hud.AMMO_ACCENT.slug).never.to.equal(Hud.AMMO_ACCENT.buck)
		end)

		it("builds both shells into the chip as Frames, and shows at most one", function()
			-- §3.10: *"Anything else is a Frame"*. BOTH are built and one is shown, the discipline
			-- the start card's row glyphs and the chamber pips already use -- a chip that rebuilt
			-- the Frame on every X press would flicker, and the corner is drawn once a frame.
			local chip = Hud.ammoChip() :: Frame
			expect(chip).to.be.ok()
			local row = chip:FindFirstChild("Content") :: Frame
			expect(row).to.be.ok()
			local shown = 0
			for _, kind in ipairs({ "Slug", "Buck" }) do
				local shell = row:FindFirstChild("Shell" .. kind) :: Frame
				expect(shell).to.be.ok()
				expect(shell:IsA("Frame")).to.equal(true)
				expect(shell.LayoutOrder).to.equal(0) -- before Pip1: the shell, then the chambers
				if shell.Visible then
					shown += 1
				end
			end
			expect(shown <= 1).to.equal(true)
			-- THE TWO ARE DIFFERENT PICTURES, not one picture in two colours: a slug is one solid
			-- nose and buckshot is a cluster of four pellets, which is what reads at a glance.
			local slug = row:FindFirstChild("ShellSlug") :: Frame
			local buck = row:FindFirstChild("ShellBuck") :: Frame
			expect(slug:FindFirstChild("Nose")).to.be.ok()
			expect(buck:FindFirstChild("Nose")).to.equal(nil)
			local pellets = 0
			for _, part in ipairs(buck:GetChildren()) do
				if string.sub(part.Name, 1, 6) == "Pellet" then
					pellets += 1
				end
			end
			expect(pellets).to.equal(4)
			expect((slug:FindFirstChild("Hull") :: Frame).BackgroundColor3).to.equal(Style.SHELL.slug.hull)
			expect((buck:FindFirstChild("Hull") :: Frame).BackgroundColor3).to.equal(Style.SHELL.buck.hull)
			-- BOTH STEPS ARE ONE IMPLEMENTATION (§3.10: every number is a fraction of `px`), so the
			-- phone shell is the desktop shell at 14. This is what makes the phone claim checkable
			-- without a phone: build one of each at both steps and compare the ratios.
			local holder = Instance.new("Frame")
			local sizes = {}
			for _, px in ipairs({ 16, 14 }) do
				local made = Style.glyph(holder, string.format("Probe%d", px), "slug", px)
				sizes[px] = { box = made.Size, hull = (made:FindFirstChild("Hull") :: Frame).Size }
			end
			holder:Destroy()
			expect(sizes[16].box).to.equal(UDim2.fromOffset(16, 16))
			expect(sizes[14].box).to.equal(UDim2.fromOffset(14, 14))
			expect(sizes[14].hull.X.Offset < sizes[16].hull.X.Offset).to.equal(true)
			TestKit.note(
				string.format(
					"ammo shells: slug hull %s @16 / %s @14, buck pellets=%d, chipShown=%d",
					tostring(sizes[16].hull),
					tostring(sizes[14].hull),
					pellets,
					shown
				)
			)
		end)
	end)

	-- ---------------------------------------------------------------- the start card (surface 10)
	--
	-- THE DESIGNER'S `startcard-spec.md`, 2026-10-18, after Karen: *"this message has to be improved
	-- maybe each from new line ask designer more user friendly"*. What is asserted here is the BUILD
	-- -- that the card is the system's floating card, that its eight children are in the spec's
	-- order, that the glyphs are Frames and not characters, and that both layouts are the numbers
	-- the Designer measured. The WORDS are `match_client.spec`'s, per role.
	describe("the start card", function()
		local function card(): Frame
			local frame = Hud.startCard()
			expect(frame).to.be.ok()
			return frame :: Frame
		end

		it("is the system's floating card and nothing hand-rolled", function()
			local frame = card()
			expect(frame.BackgroundColor3).to.equal(Style.LOOK.PANEL)
			expect(frame.BackgroundTransparency).to.be.near(Style.CARD_T, 1e-5)
			local corner = frame:FindFirstChildOfClass("UICorner")
			expect(corner).to.be.ok()
			expect(corner.CornerRadius.Offset).to.equal(Style.RADIUS.CARD)
			local stroke = frame:FindFirstChildOfClass("UIStroke")
			expect(stroke).to.be.ok()
			expect(stroke.Color).to.equal(Style.LOOK.BRASS)
			expect(stroke.Transparency).to.be.near(Style.EDGE_T.CARD, 1e-5)
			-- OVER THE SCOPE'S MASK, which is the number task 141 settled: a panel the GAME put up
			-- outranks a sight picture.
			expect(frame.ZIndex).to.equal(15)
		end)

		it("lays its eight children out in the Designer's own order", function()
			local frame = card()
			local list = frame:FindFirstChildOfClass("UIListLayout")
			expect(list).to.be.ok()
			expect(list.FillDirection).to.equal(Enum.FillDirection.Vertical)
			expect(list.SortOrder).to.equal(Enum.SortOrder.LayoutOrder)
			-- EVERY GAP IS A `UIPadding` (the spec's section 2), so the list's own padding is 0.
			expect(list.Padding.Offset).to.equal(0)
			-- CENTRED, because the two hairlines are FULL-BLEED: wider than the content box, so a
			-- centred list overhangs it equally and the line runs to the card's own edges.
			expect(list.HorizontalAlignment).to.equal(Enum.HorizontalAlignment.Center)
			local order = {}
			for _, child in ipairs(frame:GetChildren()) do
				if child:IsA("GuiObject") then
					order[child.LayoutOrder] = child.Name
				end
			end
			expect(order[1]).to.equal("Eyebrow")
			expect(order[2]).to.equal("Role")
			expect(order[3]).to.equal("Rule1")
			expect(order[4]).to.equal("Section")
			expect(order[5]).to.equal("Rows")
			expect(order[6]).to.equal("Rule2")
			expect(order[7]).to.equal("Countdown")
			expect(order[8]).to.equal("Bar")
		end)

		it("draws both hairlines full-bleed, as a gradient and not a hard line", function()
			local frame = card()
			local pad = frame:FindFirstChildOfClass("UIPadding")
			expect(pad).to.be.ok()
			local side = pad.PaddingLeft.Offset
			expect(side > 0).to.equal(true)
			for _, name in ipairs({ "Rule1", "Rule2" }) do
				local slot = frame:FindFirstChild(name) :: Frame
				expect(slot).to.be.ok()
				-- `2 x side` WIDER THAN THE CONTENT BOX: that is what full-bleed IS, and it is the
				-- one number that has to agree with the card's own padding.
				expect(slot.Size.X.Offset).to.equal(2 * side)
				local line = slot:FindFirstChild("Line") :: Frame
				expect(line).to.be.ok()
				expect(line.BackgroundColor3).to.equal(Style.LOOK.BRASS)
				expect(line.Size.Y.Offset).to.equal(1)
				expect(line:FindFirstChildOfClass("UIGradient")).to.be.ok()
			end
		end)

		it("builds every glyph as Frames, never as a character in a font", function()
			-- §3.10: *"Icons are Frames"*. A glyph a font does not have comes back at the `.notdef`
			-- width and draws as a rectangle, and no mockup screenshot says that happened.
			for _, kind in ipairs(Style.GLYPHS) do
				local probe = Instance.new("Frame")
				local glyph = Style.glyph(probe, "Probe", kind, 16)
				expect(glyph:IsA("Frame")).to.equal(true)
				expect(#glyph:GetChildren() > 0).to.equal(true)
				for _, part in ipairs(glyph:GetChildren()) do
					if part:IsA("GuiObject") then
						expect(part:IsA("TextLabel")).to.equal(false)
					end
				end
				probe:Destroy()
			end
			-- ...AND THE FOUR THE CARD USES ARE ALL BUILT ON EVERY ROW, one shown (the board's
			-- badge/tag discipline: a renderer never makes instances).
			local rows = card():FindFirstChild("Rows")
			expect(rows).to.be.ok()
			local row = rows:FindFirstChild("Row1")
			expect(row).to.be.ok()
			local icon = row:FindFirstChild("Icon")
			expect(icon).to.be.ok()
			for _, kind in ipairs(Style.GLYPHS) do
				expect(icon:FindFirstChild(kind)).to.be.ok()
			end
		end)

		-- ---------------------------------------------------------------- the horn reads as a horn (task 206)
		--
		-- KAREN, 2026-10-18, of the beater's HORN chip: *"and what is this icon ?"*. It was a 15 x 6
		-- rounded bar with an 8 x 8 rounded square over its right end -- at 16 px a lozenge and a
		-- dot, with nothing tapering and nothing curving.
		--
		-- A TEST CANNOT SAY "THIS LOOKS LIKE A HORN", so what it says is the three things that make
		-- a brass shape read as one at this size and that the old glyph had none of: it TAPERS from
		-- the mouthpiece end to the bell, it CURVES (the sections do not all share one rotation),
		-- and the BELL is clearly taller than the tube it grows out of. Those are measurable off
		-- the built Frames. What it looks like is a screenshot's job
		-- (`.screenshots/t206-glyph-before-after.png`, looked at).
		it("draws the horn as a tapering, curving tube with a bell (task 206)", function()
			for _, px in ipairs({ 14, 16, 18 }) do
				local probe = Instance.new("Frame")
				local glyph = Style.glyph(probe, "Probe", "horn", px)
				local function part(name: string): Frame
					local found = glyph:FindFirstChild(name)
					expect(found).to.be.ok()
					return found :: Frame
				end
				local mouth, near, mid, far, bell =
					part("Mouthpiece"), part("TubeNear"), part("TubeMid"), part("TubeFar"), part("Bell")

				-- IT TAPERS, section by section, toward the bell.
				expect(near.Size.Y.Offset < mid.Size.Y.Offset).to.equal(true)
				expect(mid.Size.Y.Offset < far.Size.Y.Offset).to.equal(true)
				-- ...AND IT CURVES: three sections, three different angles, turning one way.
				expect(near.Rotation > mid.Rotation).to.equal(true)
				expect(mid.Rotation > far.Rotation).to.equal(true)
				-- ...AND THE BELL FLARES. Taller than the widest tube section, which is the one
				-- thing that separates a horn from a stick, and it is the last child so it draws on
				-- top of the section it grows out of.
				expect(bell.Size.Y.Offset > far.Size.Y.Offset).to.equal(true)
				local children = glyph:GetChildren()
				expect(children[#children]).to.equal(bell)
				-- THREE VALUES, so the two ends are told apart without colour vision doing the work:
				-- a dark mouthpiece, the tube, a bright bell.
				expect(mouth.BackgroundColor3).to.equal(Style.LOOK.BRASS_LO)
				expect(near.BackgroundColor3).to.equal(Style.LOOK.BRASS)
				expect(bell.BackgroundColor3).to.equal(Style.LOOK.BRASS_HI)
				-- IT STAYS IN ITS BOX, near enough to sit in a 16 px slot beside a word: the
				-- mouthpiece is at the left end and the bell at the right, inside the box's width.
				expect(mouth.Position.X.Scale < 0.2).to.equal(true)
				expect(bell.Position.X.Scale > 0.75).to.equal(true)
				expect(bell.Position.X.Scale < 0.95).to.equal(true)
				probe:Destroy()
			end
		end)

		-- ONE HORN GLYPH IN THE GAME, not two (task 206). The beater's HORN chip used to build its
		-- own 18 x 7 bar and 9 x 9 bell here in `Hud`, beside `Style.GLYPHS`' own "horn" -- two
		-- hand-built icons, and no way to improve one without the other going stale. It asks the
		-- design system now, like every other icon in that file.
		it("builds the HORN chip's icon out of Style.glyph (task 206)", function()
			local chip = Hud.hornChip()
			expect(chip).to.be.ok()
			local icon = (chip :: Frame):FindFirstChild("Icon", true)
			expect(icon).to.be.ok()
			local horn = (icon :: Frame):FindFirstChild("Horn")
			expect(horn).to.be.ok()
			expect((horn :: Frame):FindFirstChild("Bell")).to.be.ok()
			expect((horn :: Frame):FindFirstChild("Mouthpiece")).to.be.ok()
			expect((horn :: Frame):FindFirstChild("TubeMid")).to.be.ok()
			-- ...AND THE OLD HAND-BUILT PAIR IS GONE: a "Body" directly under the icon box is the
			-- shape Karen could not read.
			expect((icon :: Frame):FindFirstChild("Body")).to.equal(nil)
		end)

		it("puts the role and the seconds at DISPLAY, at opposite corners, and nothing else there", function()
			-- The card's two answers -- WHO AM I and HOW LONG HAVE I GOT -- and the spec's reason for
			-- them being the only two at that step: *"they sit at opposite corners, and they never
			-- compete"*.
			local frame = card()
			local viewX = Hud.viewportX()
			local display = Style.sizeFor("DISPLAY", viewX)
			local role = frame:FindFirstChild("Role") :: TextLabel
			expect(role.TextSize).to.equal(display)
			expect(role.FontFace).to.equal(Style.FONT.OSWALD_SB)
			expect(role.TextXAlignment).to.equal(Enum.TextXAlignment.Left)
			local seconds = frame:FindFirstChild("Countdown"):FindFirstChild("Seconds") :: TextLabel
			expect(seconds.TextSize).to.equal(display)
			expect(seconds.TextXAlignment).to.equal(Enum.TextXAlignment.Right)
			expect(seconds.TextColor3).to.equal(Style.LOOK.PAPER)
			local label = frame:FindFirstChild("Countdown"):FindFirstChild("Label") :: TextLabel
			expect(label.TextSize).to.equal(Style.sizeFor("MICRO", viewX))
			expect(label.TextColor3).to.equal(Style.LOOK.FIELD_MUTED)
			-- NO OTHER LABEL IN THE CARD IS AT `DISPLAY`.
			local atDisplay = 0
			for _, node in ipairs(frame:GetDescendants()) do
				if node:IsA("TextLabel") and node.TextSize == display then
					atDisplay += 1
				end
			end
			expect(atDisplay).to.equal(2)
		end)

		it("never wraps a row, and reserves the right-hand cell out of the measured width", function()
			-- The spec's rule 2: *"A row never wraps. `TextWrapped = false`, `TextTruncate = AtEnd`.
			-- If a row would truncate at the phone step, the right-hand cell is dropped first."*
			local rows = card():FindFirstChild("Rows")
			for index = 1, Drive.CONFIG.START_CARD_ROWS_MAX do
				local text = rows:FindFirstChild(string.format("Row%d", index)):FindFirstChild("Text") :: TextLabel
				expect(text.TextWrapped).to.equal(false)
				expect(text.TextTruncate).to.equal(Enum.TextTruncate.AtEnd)
				expect(text.TextXAlignment).to.equal(Enum.TextXAlignment.Left)
			end
			-- The arithmetic, at both steps: the text cell plus the glyph, the gap and the reserve
			-- never exceed the content box -- which is the whole of "a row fits".
			for _, viewX in ipairs({ 1280, 400 }) do
				local step = Hud.startCardStep(viewX)
				local content = Hud.startCardContentWidth(viewX)
				expect(content).to.equal(step.width - 2 * step.side)
				local full = Hud.startCardTextWidth(viewX, 0)
				local reserved = Hud.startCardTextWidth(viewX, step.value)
				expect(full + step.glyph + step.gap).to.equal(content)
				expect(reserved + step.glyph + 2 * step.gap + step.value).to.equal(content)
				expect(reserved < full).to.equal(true)
			end
		end)

		it("is the Designer's two measured layouts, and the phone one is anchored left", function()
			-- Section 3 of the spec, and these numbers were MEASURED on `startcard-mockups.png`
			-- rather than typed: 440 x 274 centred at y 150, or 264 x 239 at the left safe margin.
			--
			-- SINCE TASK 234 THE HEIGHT FOLLOWS THE ROWS (`Hud.startCardHeight`), because the
			-- hunter's card grew to eight for the red deer and the beater's stayed at four -- and
			-- one fixed number cannot be right for both. The Designer's own two figures are what it
			-- must still answer AT FOUR ROWS, which is what pins `chrome` to a measurement instead
			-- of to a comment.
			local desktop = Hud.startCardStep(1280)
			expect(desktop.width).to.equal(440)
			expect(Hud.startCardHeight(1280, 4)).to.equal(Drive.CONFIG.START_CARD_HEIGHT)
			expect(Hud.startCardHeight(1280, 4)).to.equal(274)
			expect(desktop.top).to.equal(150)
			expect(desktop.left).to.equal(nil)
			local phone = Hud.startCardStep(400)
			expect(phone.width).to.equal(264)
			expect(Hud.startCardHeight(400, 4)).to.equal(Drive.CONFIG.START_CARD_HEIGHT_PHONE)
			expect(Hud.startCardHeight(400, 4)).to.equal(239)
			expect(phone.top).to.equal(124)
			expect(phone.left).to.equal(16)
			-- ...AND A ROW IS WORTH EXACTLY ONE ROW HEIGHT, at both steps, so eight rows is four
			-- rows plus four rows and the card can never cut its own countdown off.
			for _, viewX in ipairs({ 1280, 400 }) do
				local step = Hud.startCardStep(viewX)
				expect(Hud.startCardHeight(viewX, 8) - Hud.startCardHeight(viewX, 4)).to.equal(4 * step.rowH)
				expect(Hud.startCardHeight(viewX, 0)).to.equal(step.chrome)
				-- the ceiling is a clamp, not a hope: nothing can ask for a taller card than the
				-- renderer has rows to draw.
				expect(Hud.startCardHeight(viewX, 99)).to.equal(
					Hud.startCardHeight(viewX, Drive.CONFIG.START_CARD_ROWS_MAX)
				)
			end
			-- 16..280 STOPS 8 px SHORT OF THE MINIMAP (x 288..384 on a 400 px screen), which is the
			-- whole reason it is not centred.
			expect(phone.left + phone.width).to.equal(280)
			-- ...and the card on screen IS one of the two, whichever step this harness is running at.
			local frame = card()
			local step = Hud.startCardStep(Hud.viewportX())
			expect(frame.Size.X.Offset).to.equal(step.width)
			-- ...AND AS TALL AS THE ROWS IT IS DRAWING (task 234). The renderer writes the count
			-- and `layoutStartCard` is the one writer of the size, so what is on screen must be
			-- `startCardHeight` of SOME legal row count -- and it must be one of them exactly,
			-- which is what would catch a card sized from a stale constant again.
			local matched = false
			for rows = 0, Drive.CONFIG.START_CARD_ROWS_MAX do
				if frame.Size.Y.Offset == Hud.startCardHeight(Hud.viewportX(), rows) then
					matched = true
				end
			end
			expect(matched).to.equal(true)
			expect(frame.Size.Y.Offset >= step.chrome).to.equal(true)
			TestKit.note(
				string.format(
					"hud_style: start card drawn %dx%d at viewport %d",
					frame.Size.X.Offset,
					frame.Size.Y.Offset,
					Hud.viewportX()
				)
			)
		end)
	end)
end
