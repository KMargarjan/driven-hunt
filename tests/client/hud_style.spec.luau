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
			-- `#B4CFE4`, the ONE knob is `SLATE_T`: 0.18 -> 0.12 -- and that is a decision, not a
			-- drift, so it changes here and the table is recomputed.
			expect(Style.SLATE_T).to.equal(0.18)
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
			expect(string.find(text, Drive.CONFIG.SCORE_COINS_UNKNOWN, 1, true)).to.equal(nil)
			expect(string.find(text, "nil", 1, true)).to.equal(nil)
			-- ...and the words are the chips' own: whatever is drawn is in it, and nothing else is.
			local bar = Hud.gui():FindFirstChild("DriveBar") :: Frame
			if bar.Visible then
				expect(#text > 0).to.equal(true)
			end
			TestKit.note("hud_style: status bar reads " .. string.format("%q", text))
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
	end)
end
