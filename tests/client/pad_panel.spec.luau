-- pad_panel.spec: THE TRUCK PADS' SIZE DIALOG, on the client that draws it (task 182).
--
-- KAREN, 2026-10-14: *"you come to truck back rectangle and can click and select how many players
-- ... can be 1/1 or 4/4 you can select on dialiog how many like in roblox games"*.
--
-- WHAT IT CAN PROVE AND WHAT IT CANNOT, stated rather than discovered: a spec cannot fire
-- `GuiButton.Activated` and the harness's input scenarios cannot synthesise a tap
-- (`tools/studio_mcp.py`'s docstring: keys, mouse buttons, mouse moves and gaps only). So
-- `PadPanel.press` is the seam these cases drive -- `Rail.press`' and `ShopPanel.press`' own stated
-- limit -- and what they prove is the ACTION behind the button, not the touch that reaches it.
--
-- IT RUNS IN THE DEV PLACE, WHICH HAS NO LOBBY AT ALL (`Lobby.ANCHORS` has one row), so there is no
-- pad part, no attribute and no remote here. That is exactly why the panel is TOLD which pad is
-- asking (`PadPanel.setAsk`) instead of reading the world: the dialog is drivable with no lobby, and
-- a client that could decide it was first would be a client that could put eight strangers in a
-- truck.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- TASK 197 ADDS THE RESTYLE AND THE LOADING BANNER. KAREN, 2026-10-15: *"same with entering in game
-- menu has to be nicer and cleaner / and we need clear message that game is loading once clicked 1/1
-- or other now is delay"*. The banner's two pure functions -- what it says and how full its bar is --
-- are asserted here as arithmetic, and the LIVE banner frame is driven through `PadPanel.setLeaving`,
-- which is the same TOLD seam `setAsk` already is.
--
-- Design: docs/design/truck-pads.md (sections 8.1, 10.3)
-- Note:   docs/research/2026-10-14-truck-pads.md (section 5.4)
-- Note:   docs/research/2026-10-17-the-pad-menu-and-the-truck.md (task 197)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyData = require(ReplicatedStorage:WaitForChild("Lobby"))
local PlayerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local Hud = require(PlayerScripts:WaitForChild("Hud"))

local PADS = LobbyData.CONFIG.PADS
local PANEL = PADS.PANEL
local LEAVING = PADS.LEAVING

return function()
	describe("the truck pads' size dialog", function()
		local PadPanel = Hud.PadPanel

		-- THE LIVE PANEL, the one `Hud.build` made, because *"the panel reads"* is only a claim about
		-- the real thing. Each case restores the `ask` it found, so a spec cannot leave a dialog on
		-- Karen's screen.
		local restore: number? = nil

		-- THE CLOCK THESE CASES HAND OVER (task 209). `setLeaving`'s third argument is the Hud's
		-- `os.clock()` in the real client; here it is a number this file owns, which is the whole
		-- reason the module takes one instead of reading a clock of its own -- the six-second
		-- window after a click can be stepped over in an expectation rather than waited through.
		local clock = 1000

		-- A CLICK NOW HOLDS THE BANNER UP FOR `PENDING_SECONDS` ON ITS OWN, so clearing the banner
		-- means stepping PAST that window as well as handing back a nil state.
		local function clearBanner()
			clock += LEAVING.PENDING_SECONDS + 1
			PadPanel.setLeaving(nil, nil, clock)
		end

		beforeEach(function()
			restore = PadPanel.padIndex()
			PadPanel.setAsk(nil)
			-- ...AND THE BANNER, for the same reason: a case that left one up would leave Karen
			-- reading "LEAVING FOR THE HUNT" for the rest of the session.
			clearBanner()
		end)

		afterEach(function()
			PadPanel.setAsk(restore)
			clearBanner()
		end)

		it("is built, hidden, and the right rectangle for a phone", function()
			local frame = Hud.padPanel()
			expect(frame).to.be.ok()
			local panel = frame :: Frame
			expect(panel.Visible).to.equal(false)
			-- ONE NUMBER DECIDES BOTH THE ROWS AND THE BOX (`ShopPanel.panelSize`'s rule, and the
			-- Reviewer's task-178 round-1 note: they used to be two, and a sixth row would have been
			-- drawn outside the frame in silence).
			expect(panel.Size.X.Offset).to.equal(PadPanel.widthFor())
			expect(panel.Size.Y.Offset).to.equal(PadPanel.heightFor())
			-- IT FITS A 400 px PHONE, which is the width `hud_clarity.spec` measures everything at.
			expect(PadPanel.widthFor() <= 400).to.equal(true)
			-- `Rail.CONFIG.Z_INDEX` IS 16 AND STAYS PRESSABLE OVER IT -- the shop panel's own band.
			expect(PadPanel.zIndex()).to.equal(PANEL.Z_INDEX)
			expect(PANEL.Z_INDEX < 16).to.equal(true)
		end)

		it("opens because the SERVER asked, and closes when it stops asking", function()
			expect(PadPanel.isOpen()).to.equal(false)
			local before = PadPanel.stats().opens
			PadPanel.setAsk(2)
			expect(PadPanel.isOpen()).to.equal(true)
			expect(PadPanel.padIndex()).to.equal(2)
			expect((Hud.padPanel() :: Frame).Visible).to.equal(true)
			expect(PadPanel.titleText()).to.equal(PANEL.TITLE)
			-- EDGE-TRIGGERED: the same answer twice is one open.
			PadPanel.setAsk(2)
			expect(PadPanel.stats().opens).to.equal(before + 1)
			-- ...AND STEPPING OFF IS THE SERVER'S OWN CANCEL, not a second rule on this side.
			PadPanel.setAsk(nil)
			expect(PadPanel.isOpen()).to.equal(false)
			expect((Hud.padPanel() :: Frame).Visible).to.equal(false)
			-- ANYTHING THAT IS NOT A PAD NUMBER IS "NOBODY IS ASKING".
			PadPanel.setAsk("2" :: any)
			expect(PadPanel.isOpen()).to.equal(false)
		end)

		it("draws Karen's own four labels, in order, each big enough for a thumb", function()
			PadPanel.setAsk(1)
			local rows = PadPanel.rowText()
			expect(#rows).to.equal(#PADS.SIZES)
			for index, row in ipairs(PADS.SIZES) do
				-- THE LABEL IS THE DATA'S OWN. Karen wrote `1 / 1` and `4 / 4` herself, so the panel
				-- applies no format of its own -- which is what makes the words hers to retune.
				expect(rows[index]).to.equal(row.label)
			end
			-- 48 px OR MORE, over the 44 Roblox's own tutorial sets as a touch minimum. Measured off
			-- the real buttons rather than off the config, because what matters is what was BUILT.
			local frame = Hud.padPanel() :: Frame
			local found = 0
			for _, child in ipairs(frame:GetChildren()) do
				if child:IsA("TextButton") then
					found += 1
					expect((child :: TextButton).Size.Y.Offset >= 44).to.equal(true)
					expect((child :: TextButton).Size.Y.Offset).to.equal(PANEL.BUTTON_PX)
					-- AND NONE OF THEM IS WIDER THAN THE PANEL.
					expect((child :: TextButton).Size.X.Offset <= PadPanel.widthFor()).to.equal(true)
				end
			end
			expect(found).to.equal(#PADS.SIZES)
			-- THERE IS NO CLOSE BUTTON, AND THAT IS DELIBERATE: `1 / 1` is the "leave me alone"
			-- button, stepping off the pad is the other exit, and the eight-second timeout does it by
			-- itself -- so the dialog can never be a dead end.
			expect(frame:FindFirstChild("Close")).to.equal(nil)

			-- TASK 197: EVERY ROW HAS ITS SHORT LINE (the Director: *"big buttons with a short line
			-- each"*), and it is the DATA's own line and not a format applied in the panel.
			local lines = PadPanel.rowNote()
			expect(#lines).to.equal(#PADS.SIZES)
			for index, row in ipairs(PADS.SIZES) do
				expect(lines[index]).to.equal(row.note)
				expect(#(row.note :: string) > 0).to.equal(true)
			end

			-- ...AND EXACTLY ONE ORANGE THING ON THE SCREEN (the designer's spec 8.4), on row 1 --
			-- which is `Pads.defaultSize`, the size a pick nobody makes falls back to. A second
			-- orange bar would mean the panel was recommending two things at once.
			local marks = 0
			for _, child in ipairs(frame:GetChildren()) do
				if child:IsA("TextButton") and (child :: TextButton):FindFirstChild("Default") ~= nil then
					marks += 1
					expect((child :: TextButton).Name).to.equal(string.format("Size%d", PADS.SIZES[1].size))
				end
			end
			expect(marks).to.equal(1)
		end)

		it("says what the loading banner says, as arithmetic", function()
			local WORDS = PADS.LEAVING
			local STATE = LobbyData.PAD_STATE
			-- NOTHING AT ALL FOR A PAD THAT IS NOT LOADING, including nil and a word that is not a
			-- state: the rule that decides whether the banner is up (`Lobby.padLoading`) and the rule
			-- that decides what it says can never disagree.
			expect(PadPanel.leavingLineFor(nil, nil)).to.equal("")
			expect(PadPanel.leavingLineFor(STATE.EMPTY, 3)).to.equal("")
			expect(PadPanel.leavingLineFor(STATE.SIZING, 3)).to.equal("")
			expect(PadPanel.leavingLineFor("nonsense", 3)).to.equal("")
			-- ...AND ONE LINE FOR EACH OF THE THREE THAT ARE.
			expect(PadPanel.leavingLineFor(STATE.FILLING, nil)).to.equal(WORDS.FILLING)
			expect(PadPanel.leavingLineFor(STATE.LEAVING, nil)).to.equal(WORDS.GOING)
			-- `ceil`, SO "1" IS THE LAST WHOLE SECOND and the line never reads 0 while he is still
			-- standing there -- `Objective.text`'s own rule for the same countdown.
			expect(PadPanel.leavingLineFor(STATE.COUNTDOWN, 4.2)).to.equal(string.format(WORDS.COUNTDOWN, 5))
			expect(PadPanel.leavingLineFor(STATE.COUNTDOWN, 0.1)).to.equal(string.format(WORDS.COUNTDOWN, 1))
			expect(PadPanel.leavingLineFor(STATE.COUNTDOWN, -3)).to.equal(string.format(WORDS.COUNTDOWN, 0))

			-- THE BAR FILLS AS THE COUNTDOWN RUNS DOWN, and there is NO BAR while the party is
			-- filling: in `filling` the pad waits for people who may never come, so a bar inching
			-- along would be claiming to know how long that is.
			local whole = LobbyData.CONFIG.COUNTDOWN_SECONDS
			expect(PadPanel.barFraction(STATE.FILLING, 12)).to.equal(nil)
			expect(PadPanel.barFraction(STATE.SIZING, 1)).to.equal(nil)
			expect(PadPanel.barFraction(nil, 1)).to.equal(nil)
			expect(PadPanel.barFraction(STATE.COUNTDOWN, whole)).to.equal(0)
			expect(PadPanel.barFraction(STATE.COUNTDOWN, whole / 2)).to.equal(0.5)
			expect(PadPanel.barFraction(STATE.COUNTDOWN, 0)).to.equal(1)
			-- CLAMPED AT BOTH ENDS, because the server's deadline and this client's clock are two
			-- clocks: a late frame must not draw a bar past its track or behind its start.
			expect(PadPanel.barFraction(STATE.COUNTDOWN, -5)).to.equal(1)
			expect(PadPanel.barFraction(STATE.COUNTDOWN, whole + 5)).to.equal(0)
			expect(PadPanel.barFraction(STATE.LEAVING, nil)).to.equal(1)
		end)

		it("puts the banner up when the server says so, and takes it down on arrival", function()
			local STATE = LobbyData.PAD_STATE
			local frame = Hud.padLeaving()
			expect(frame).to.be.ok()
			local box = frame :: Frame
			expect(box.Visible).to.equal(false)
			-- FULL WIDTH LESS A MARGIN, capped: a SCALE, so nothing re-measures on a resize.
			expect(box.Size.X.Scale).to.equal(1)
			expect(box.Size.X.Offset).to.equal(-2 * PADS.LEAVING.MARGIN_PX)
			expect(box.ZIndex).to.equal(PadPanel.leavingZIndex())
			-- `Rail.CONFIG.Z_INDEX` IS 16 AND STAYS PRESSABLE OVER IT, like the dialog.
			expect(PadPanel.leavingZIndex() < 16).to.equal(true)

			local opened = PadPanel.stats().leavingOpens
			PadPanel.setLeaving(STATE.FILLING, nil)
			expect(PadPanel.isLeaving()).to.equal(true)
			expect(box.Visible).to.equal(true)
			local head, line = PadPanel.leavingText()
			expect(head).to.equal(PADS.LEAVING.TITLE)
			expect(line).to.equal(PADS.LEAVING.FILLING)
			-- NO BAR WHILE FILLING -- the track itself is hidden, not merely empty.
			local track = box:FindFirstChild("Track")
			expect(track).to.be.ok()
			expect((track :: Frame).Visible).to.equal(false)
			-- EDGE-TRIGGERED: the same state twice is one open.
			PadPanel.setLeaving(STATE.FILLING, nil)
			expect(PadPanel.stats().leavingOpens).to.equal(opened + 1)

			-- THE COUNTDOWN DRAWS THE SECONDS AND FILLS THE BAR.
			local whole = LobbyData.CONFIG.COUNTDOWN_SECONDS
			PadPanel.setLeaving(STATE.COUNTDOWN, whole / 2)
			local _, counting, half = PadPanel.leavingText()
			expect(counting).to.equal(string.format(PADS.LEAVING.COUNTDOWN, math.ceil(whole / 2)))
			expect((track :: Frame).Visible).to.equal(true)
			expect(math.abs(half - 0.5) < 0.01).to.equal(true)
			PadPanel.setLeaving(STATE.COUNTDOWN, 0)
			expect(select(3, PadPanel.leavingText())).to.equal(1)

			-- AND IT CLEARS WHEN THE DRIVE HAS HIM: the owner writes the attribute nil the moment the
			-- roster has him, so this is the one edge that takes the banner down.
			PadPanel.setLeaving(nil, nil)
			expect(PadPanel.isLeaving()).to.equal(false)
			expect(box.Visible).to.equal(false)
			-- ANYTHING THAT IS NOT A LOADING STATE IS "NOBODY IS LOADING" -- `sizing` included, which
			-- is the state the dialog itself is up in.
			PadPanel.setLeaving(STATE.SIZING, 2)
			expect(box.Visible).to.equal(false)
			PadPanel.setLeaving(7 :: any, 2)
			expect(box.Visible).to.equal(false)
		end)

		it("sends ONE message per press, naming the pad the server asked about", function()
			local sent: { any } = {}
			PadPanel.setRemotes({
				PadRequest = {
					FireServer = function(_self, payload: any)
						table.insert(sent, payload)
					end,
				},
			})
			-- NO ASK, NO MESSAGE: the dialog cannot be pressed when nobody is being asked.
			expect(PadPanel.press(4)).to.equal(false)
			expect(#sent).to.equal(0)

			PadPanel.setAsk(3)
			expect(PadPanel.press(4)).to.equal(true)
			expect(#sent).to.equal(1)
			-- THE PAYLOAD IS TWO NUMBERS AND NOTHING ELSE. The server measures everything else off
			-- the character it can see, so anything extra here would be a field nobody reads.
			expect(sent[1].pad).to.equal(3)
			expect(sent[1].size).to.equal(4)
			local fields = 0
			for _ in pairs(sent[1]) do
				fields += 1
			end
			expect(fields).to.equal(2)

			-- A DOUBLE TAP IS ONE MESSAGE.
			expect(PadPanel.press(4)).to.equal(false)
			expect(#sent).to.equal(1)

			-- A SIZE THAT IS NOT IN THE DATA IS NOT SENT AT ALL. The server would count it as a
			-- forgery, and a client that sent one would be lying about its own catalogue.
			expect(PadPanel.press(3)).to.equal(false)
			expect(PadPanel.press(99)).to.equal(false)
			expect(#sent).to.equal(1)

			-- A NEW PAD IS A NEW QUESTION, so the size already sent is forgotten with the old one --
			-- without which, stepping off pad 3 after picking 4 and onto pad 1 would leave the dialog
			-- unable to send anything.
			PadPanel.setAsk(1)
			expect(PadPanel.press(4)).to.equal(true)
			expect(#sent).to.equal(2)
			expect(sent[2].pad).to.equal(1)
			PadPanel.setRemotes(nil)
		end)

		it("asks for the mouse and holds the trigger under its own name, and hands both back", function()
			-- BOTH DOORS ARE REASON-KEYED, so this dialog releases exactly its own request and never
			-- the shop's or the report's (`ShopPanel.setOpen`'s shape, tag `"padsize"`). Without the
			-- hold, the click that picks a party size would also fire the gun.
			local freed: { string } = {}
			local released: { string } = {}
			local held: { string } = {}
			local unheld: { string } = {}
			PadPanel.stop()
			PadPanel.start(Instance.new("Frame"), {
				Cursor = {
					requestFree = function(reason: string)
						table.insert(freed, reason)
					end,
					release = function(reason: string)
						table.insert(released, reason)
					end,
				},
				Input = {
					requestHold = function(reason: string)
						table.insert(held, reason)
					end,
					releaseHold = function(reason: string)
						table.insert(unheld, reason)
					end,
				},
			})
			PadPanel.setAsk(2)
			expect(freed[1]).to.equal("padsize")
			expect(held[1]).to.equal("padsize")
			expect(#released).to.equal(0)
			PadPanel.setAsk(nil)
			expect(released[1]).to.equal("padsize")
			expect(unheld[1]).to.equal("padsize")

			-- ...AND THE LIVE PANEL IS PUT BACK, because this case took it over. `PadPanel.stop` EMPTIES
			-- the frame it was given (the Reviewer's round-1 note: without that, re-starting on the
			-- live frame left it with doubled children), so the re-start below rebuilds exactly one
			-- title and four buttons -- and the assertion is what proves it rather than the comment.
			PadPanel.stop()
			local frame = Hud.padPanel()
			expect(frame).to.be.ok()
			-- THE BANNER'S FRAME GOES BACK WITH IT (task 197), or every later case -- and Karen --
			-- would have a panel with no banner attached to it.
			PadPanel.start(frame :: Frame, { remotes = nil, leaving = Hud.padLeaving() })
			local rebuilt = 0
			for _, child in ipairs((frame :: Frame):GetChildren()) do
				if child:IsA("TextButton") then
					rebuilt += 1
				end
			end
			expect(rebuilt).to.equal(#PADS.SIZES)
			-- ...AND THE BANNER HAS EXACTLY ONE OF EACH OF ITS PIECES, which is the doubled-children
			-- claim said about the second frame: `stop` destroys EVERY child and not only the
			-- `GuiObject`s, because the restyle added a `UICorner`, a `UIStroke` and a
			-- `UISizeConstraint` to each frame and a doubled stroke is a doubled stroke.
			local bannerFrame = Hud.padLeaving() :: Frame
			local tracks, corners, strokes = 0, 0, 0
			for _, child in ipairs(bannerFrame:GetChildren()) do
				if child.Name == "Track" then
					tracks += 1
				elseif child:IsA("UICorner") then
					corners += 1
				elseif child:IsA("UIStroke") then
					strokes += 1
				end
			end
			expect(tracks).to.equal(1)
			expect(corners).to.equal(1)
			expect(strokes).to.equal(1)
		end)

		-- ---------------------------------------------------------- task 209, the instant banner
		--
		-- KAREN, 2026-10-18: *"also once I click I need imeadiatly show loading (Leaving dfor
		-- hunting)"*. MEASURED on her path first (rule H): a real left click on `1 / 1`, with the
		-- timestamp taken inside the client on `UserInputService.InputBegan` and again when
		-- `PadLeaving.Visible` turned true, was **3.65 s** -- the pick travels to the server, waits
		-- for the owner's 10 Hz scan, changes the pad's state, writes `DHPadMine` and comes back.
		--
		-- WHAT THIS CASE PROVES IS THE ACTION AND NOT THE TOUCH, which is `press`' own stated limit:
		-- a spec cannot fire `GuiButton.Activated`. The real click is measured in the live Forest
		-- Test and reported with the request; what belongs here is that pressing raises the banner
		-- with NOTHING from the server, that the server's word replaces the line the moment it
		-- arrives, and that a pick nobody answers takes the banner down again.
		it("shows the leaving banner on the click, before the server has said anything (task 209)", function()
			local frame = Hud.padLeaving() :: Frame
			local sent: { any } = {}
			PadPanel.setRemotes({
				PadRequest = {
					FireServer = function(_self, payload: any)
						table.insert(sent, payload)
					end,
				},
			})
			clock += 1
			PadPanel.setLeaving(nil, nil, clock)
			PadPanel.setAsk(2)
			expect(frame.Visible).to.equal(false)
			expect(PadPanel.isLeaving()).to.equal(false)

			-- THE CLICK. One message, and the banner is up in the same call -- no server, no
			-- attribute, no scan.
			expect(PadPanel.press(1)).to.equal(true)
			expect(#sent).to.equal(1)
			expect(frame.Visible).to.equal(true)
			expect(PadPanel.isLeaving()).to.equal(true)
			local _, line = PadPanel.leavingText()
			expect(line).to.equal(LEAVING.SENT)
			expect(PadPanel.stats().optimistic >= 1).to.equal(true)

			-- ...AND IT SURVIVES THE PAD NO LONGER ASKING, which is what a pick the server ACCEPTS
			-- looks like one scan later: `DHPadFirst` goes before `DHPadMine` arrives, and a banner
			-- that fell with the dialog would blink out in exactly the gap it exists to fill.
			PadPanel.setAsk(nil)
			clock += 0.5
			PadPanel.setLeaving(nil, nil, clock)
			expect(frame.Visible).to.equal(true)

			-- THE SERVER'S WORD REPLACES IT, and from then on the words are the world's.
			clock += 0.5
			PadPanel.setLeaving(LobbyData.PAD_STATE.COUNTDOWN, 3, clock)
			local _, counted = PadPanel.leavingText()
			expect(counted).to.equal(string.format(LEAVING.COUNTDOWN, 3))
			-- ...and when the pad lets go, so does the banner: the click's own window is spent.
			clock += 0.5
			PadPanel.setLeaving(nil, nil, clock)
			expect(frame.Visible).to.equal(false)
			PadPanel.setRemotes(nil)
		end)

		it("takes the banner back down when the server never answers the click (task 209)", function()
			local frame = Hud.padLeaving() :: Frame
			PadPanel.setRemotes({ PadRequest = { FireServer = function() end } })
			clock += 1
			PadPanel.setLeaving(nil, nil, clock)
			PadPanel.setAsk(3)
			expect(PadPanel.press(2)).to.equal(true)
			expect(frame.Visible).to.equal(true)
			-- A SECOND BEFORE THE WINDOW SHUTS it is still up...
			clock += LEAVING.PENDING_SECONDS - 1
			PadPanel.setLeaving(nil, nil, clock)
			expect(frame.Visible).to.equal(true)
			-- ...and a second after it, it is not. A pick the server refuses (a pad that emptied, a
			-- forged size) leaves no word at all, and a banner with no way down is worse than a slow
			-- one -- the dialog is still open underneath, which is what says to pick again.
			clock += 2
			PadPanel.setLeaving(nil, nil, clock)
			expect(frame.Visible).to.equal(false)
			expect(PadPanel.isLeaving()).to.equal(false)
			PadPanel.setRemotes(nil)
		end)

		it("never lets the click's banner contradict the server (task 209)", function()
			-- PURE, so the rule is a spec and not a screenshot: whatever the pending flag says, a
			-- state the server HAS sent wins, and the fourth line only ever fills a silence.
			for _, state in ipairs({ LobbyData.PAD_STATE.FILLING, LobbyData.PAD_STATE.LEAVING }) do
				expect(PadPanel.bannerLineFor(state, nil, true)).to.equal(PadPanel.leavingLineFor(state, nil))
				expect(PadPanel.bannerLineFor(state, nil, false)).to.equal(PadPanel.leavingLineFor(state, nil))
			end
			expect(PadPanel.bannerLineFor(LobbyData.PAD_STATE.COUNTDOWN, 4, true)).to.equal(
				string.format(LEAVING.COUNTDOWN, 4)
			)
			-- ...AND THE FOURTH LINE IS NOT A PAD STATE. `Lobby.padLoading` must keep meaning "the
			-- SERVER says this party is leaving"; no pad is ever in it, only this client is.
			expect(PadPanel.bannerLineFor(nil, nil, true)).to.equal(LEAVING.SENT)
			expect(PadPanel.bannerLineFor(nil, nil, false)).to.equal("")
			expect(LobbyData.padLoading(LEAVING.SENT)).to.equal(false)
		end)
	end)
end
