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

-- `TestKit.note` ONLY, for the measured lines task 229's block prints: the two surfaces are judged
-- by eye by Karen, and until she has looked at them the honest substitute is a NUMBER in the report
-- rather than a passing assertion nobody can picture.
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

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

		-- WHERE A FRAME'S TOP AND BOTTOM EDGES LAND ON A SCREEN `height` PIXELS TALL. It reads the
		-- LIVE frame's own `Position`, `Size` and `AnchorPoint` rather than restating `Hud.build`'s
		-- arithmetic, so a rectangle that moves in the Hud moves here too -- and it takes the height
		-- as an argument because a spec cannot resize the viewport and the rule has to hold at more
		-- than the one size this machine happens to run at.
		local function bandOf(frame: GuiObject, height: number): (number, number)
			local tall = height * frame.Size.Y.Scale + frame.Size.Y.Offset
			local top = height * frame.Position.Y.Scale + frame.Position.Y.Offset - frame.AnchorPoint.Y * tall
			return top, top + tall
		end

		-- A CLICK NOW HOLDS THE BANNER UP FOR `PENDING_SECONDS` ON ITS OWN, so clearing the banner
		-- means stepping PAST that window as well as handing back a nil state.
		local function clearBanner()
			clock += LEAVING.PENDING_SECONDS + 1
			PadPanel.setLeaving(nil, nil, clock)
		end

		-- ...AND THE ROLE SWITCH (task 229): a case that left a wish set would leave a 487 px dialog
		-- and a lit half on Karen's screen for the rest of the session.
		local restoreWish: string? = nil

		beforeEach(function()
			restore = PadPanel.padIndex()
			restoreWish = PadPanel.roleWish()
			PadPanel.setRoleWish(nil, nil, 720)
			PadPanel.setAsk(nil)
			-- ...AND THE BANNER, for the same reason: a case that left one up would leave Karen
			-- reading "LEAVING FOR THE HUNT" for the rest of the session.
			clearBanner()
		end)

		afterEach(function()
			PadPanel.setAsk(restore)
			PadPanel.setRoleWish(restoreWish, nil, 720)
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

		-- ---------------------------------------------------- task 209 round 1's blocking finding
		--
		-- THE OPTIMISTIC BANNER PUT TWO OPAQUE RECTANGLES ON THE SCREEN AT ONCE. Before this task the
		-- banner and the dialog shared one `Z_INDEX` on a stated premise -- `LEAVING.Z_INDEX`'s own
		-- comment: *"The two can never be up together -- the dialog needs `sizing` and the banner
		-- needs one of the three states after it"*. Raising the banner on the CLICK made that false:
		-- the dialog's `Visible` is a SERVER-measured fact (`docs/design/truck-pads.md` 8.1, through
		-- `DHPadState` + `DHPadFirst`) and the pad goes on asking until the owner's next 10 Hz scan,
		-- so for that scan -- or for the whole of `PENDING_SECONDS` when the pick is refused and no
		-- word ever comes -- both were up, 112 px of banner across the dialog's last button and its
		-- one stated way out. Measured by the Reviewer at 96 px of overlap on a 400x800 screen and
		-- 110 px on 1280x720.
		--
		-- THE RULE IS "THEY DO NOT INTERSECT", NOT "THE BANNER IS ON TOP". Equal-`ZIndex` siblings
		-- have no defined precedence in Roblox, and the banner may not be raised above the dialog
		-- either: `Rail.CONFIG.Z_INDEX` 16 has to stay pressable over both. So the fix is geometry,
		-- and this is the case that holds it.
		it("never draws the click's banner across the size dialog (task 209 round 2)", function()
			local dialog = Hud.padPanel() :: Frame
			local banner = Hud.padLeaving() :: Frame
			-- A REMOTE THAT SWALLOWS THE PICK, because this case is about two rectangles and not
			-- about the message: what it must NOT do is reach a real server from a spec.
			PadPanel.setRemotes({ PadRequest = { FireServer = function() end } })
			clock += 1
			PadPanel.setLeaving(nil, nil, clock)
			PadPanel.setAsk(2)
			expect(PadPanel.press(1)).to.equal(true)
			-- THE STATE THE CLICK CREATES, asserted rather than assumed: the dialog is STILL OPEN,
			-- because nothing here may close it, and the banner is up over the same screen.
			expect(dialog.Visible).to.equal(true)
			expect(banner.Visible).to.equal(true)
			-- ...AND THE BANNER IS NOT ABOVE IT. Written as `<=` and not as an equality so that a
			-- later restack of the dialog is not a failure here, but raising the banner over the
			-- dialog -- the fix this case exists to forbid -- is.
			expect(banner.ZIndex <= dialog.ZIndex).to.equal(true)
			-- THE TWO VIEWPORT STEPS THE REVIEWER NAMED: a 400x800 phone and a 1280x720 desktop.
			for _, height in ipairs({ 800, 720 }) do
				local dialogTop, dialogBottom = bandOf(dialog, height)
				local bannerTop, bannerBottom = bandOf(banner, height)
				expect(bannerTop >= dialogBottom or bannerBottom <= dialogTop).to.equal(true)
				-- ...and "move it off the screen" is not a fix: the whole banner is still drawn.
				expect(bannerTop >= 0).to.equal(true)
				expect(bannerBottom <= height).to.equal(true)
			end
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

		-- ======================================================= THE ROLE SWITCH (task 229)
		--
		-- **THESE ELEVEN CASES HAD NEVER RUN (task 244).** They were written INSIDE the body of the
		-- case above -- an `it()` inside a running `it()` -- so TestEZ registered nothing and the
		-- suite still read green. Task 229 and task 242 both signed off the role switch on them, and
		-- what they did not catch is the defect Karen reported on 2026-10-22: the dialog's one
		-- outbound door was nil, so neither half nor any size row could send anything at all.
		-- The Learning Agent queued the nesting as 229h on 2026-10-21 and nothing had moved it.
		-- The `end)` above is the whole fix; everything below it is the same eleven cases, de-dented
		-- by one tab, plus task 244's own.
		-- --------------------------------------------------- THE ROLE SWITCH (task 229)
		--
		-- KAREN, 2026-10-21: *"we also need to have posibility to choose once you have a card always
		-- hunter maybe sometimes I want to be a beater we need to find a way to do that"*.
		--
		-- THE PRIMARY SURFACE. Every claim here is either ARITHMETIC off the pure `layoutFor` or a
		-- read of the LIVE instances `Hud.build` made -- never a screenshot. What it cannot prove is
		-- the TOUCH: a spec cannot fire `GuiButton.Activated` and the harness cannot synthesise a
		-- tap, so `sendRoleWish` is the seam, exactly as `press` already is.
		-- Design: docs/design/role-switch.md (sections 10.7, 14, 15.4)
		it("adds exactly BLOCK_PX to the dialog, and nothing when he owns nothing", function()
			local ROLE = PANEL.ROLE
			expect(PadPanel.heightFor(4, true) - PadPanel.heightFor(4, false)).to.equal(ROLE.BLOCK_PX)
			-- `withSwitch` nil IS TODAY'S NUMBER, which is what makes every existing caller unchanged
			-- by construction -- `Hud.build` among them.
			expect(PadPanel.heightFor(4)).to.equal(PadPanel.heightFor(4, false))
			expect(PadPanel.heightFor()).to.equal(
				PANEL.HEADER_PX + 4 * PANEL.ROW_PX + 3 * PANEL.GAP + PANEL.HINT_PX + 14
			)
		end)

		it("grows UPWARD: the dialog's bottom edge is the same pixel in both states", function()
			-- A CORRECTION MADE IN ADVANCE. `LEAVING.Y_SCALE`'s own comment carries the band task 209
			-- round 2 measured off a 368-tall CENTRED dialog; a centred 487 px dialog would put 26 px
			-- of its hint band under the loading banner at 1280 x 720 -- the exact defect, in the
			-- exact place, that round 2 was spent on. So the block is added at the TOP.
			local dialog = Hud.padPanel() :: Frame
			PadPanel.setAsk(2)
			PadPanel.setRoleWish(nil, nil, 720)
			local _, bottomWithout = bandOf(dialog, 720)
			local withoutTall = dialog.Size.Y.Offset
			PadPanel.setRoleWish(LobbyData.ROLE_WISH.HUNTER, nil, 720)
			local _, bottomWith = bandOf(dialog, 720)
			expect(dialog.Size.Y.Offset - withoutTall).to.equal(PANEL.ROLE.BLOCK_PX)
			expect(math.abs(bottomWith - bottomWithout) < 0.01).to.equal(true)
			-- ...AND THE BANNER STILL CANNOT CROSS IT at the taller height, which is the whole point
			-- of the bottom edge being invariant (the two ARE up together since task 209).
			local banner = Hud.padLeaving() :: Frame
			local dialogTop, dialogBottom = bandOf(dialog, 720)
			local bannerTop, bannerBottom = bandOf(banner, 720)
			expect(bannerTop >= dialogBottom or bannerBottom <= dialogTop).to.equal(true)
			expect(dialogTop >= 0).to.equal(true)
		end)

		it("is dropped on a screen too short for it, and the shop is the way in there", function()
			-- 487 + 24 = 511. A LANDSCAPE PHONE (800 x 400, *"which is how phones play"*) does not
			-- clear it, and today's 368 already leaves only 16 px of margin there. The feature is
			-- still reachable because the shop's panel scales -- which is why there are two surfaces.
			expect(PadPanel.switchFitsIn(720)).to.equal(true)
			expect(PadPanel.switchFitsIn(800)).to.equal(true)
			expect(PadPanel.switchFitsIn(1080)).to.equal(true)
			expect(PadPanel.switchFitsIn(511)).to.equal(true)
			expect(PadPanel.switchFitsIn(510)).to.equal(false)
			expect(PadPanel.switchFitsIn(400)).to.equal(false)
			-- A nil HEIGHT ANSWERS false: the small guess (`ShopPanel.screenSize`'s own rule).
			expect(PadPanel.switchFitsIn(nil)).to.equal(false)
			local short = PadPanel.layoutFor(4, LobbyData.ROLE_WISH.BEATER, 400)
			expect(short.switchShown).to.equal(false)
			expect(short.height).to.equal(PadPanel.heightFor(4))
		end)

		it("moves every row and the hint by exactly BLOCK_PX, and nothing else", function()
			-- THE ONE REAL COST OF THIS TASK, NAMED: the four rows' Y and the hint's Y used to be
			-- written once in `build`, so a block inserted under the header would have left all five
			-- where they were. `relayout` is now the one writer of every rectangle in this dialog.
			local without = PadPanel.layoutFor(4, nil, 720)
			local with = PadPanel.layoutFor(4, LobbyData.ROLE_WISH.BEATER, 720)
			expect(without.switchShown).to.equal(false)
			expect(with.switchShown).to.equal(true)
			for index = 1, 4 do
				expect(with.rowY[index] - without.rowY[index]).to.equal(PANEL.ROLE.BLOCK_PX)
			end
			expect(with.hintY - without.hintY).to.equal(PANEL.ROLE.BLOCK_PX)
			-- ...AND THE BLOCK'S OWN FOUR BANDS ARE THE DESIGNER'S TABLE, in order, under the header.
			local ROLE = PANEL.ROLE
			expect(with.switchY).to.equal(PANEL.HEADER_PX + ROLE.LEAD_PX)
			expect(with.trackY).to.equal(with.switchY + ROLE.EYEBROW_PX + ROLE.GAP_PX)
			expect(with.captionY).to.equal(with.trackY + ROLE.TRACK_PX + ROLE.NOTE_GAP)
			expect(with.ruleY).to.equal(with.captionY + ROLE.NOTE_PX + ROLE.RULE_GAP)
			-- THE RULE IS CLEAR OF THE FIRST SIZE ROW BY `TRAIL_PX`.
			expect(with.rowY[1] - (with.ruleY + ROLE.RULE_PX)).to.equal(ROLE.TRAIL_PX)
			TestKit.note(
				string.format(
					"task229 pad block: dialog %d -> %d px, block %d, track %dx%d at y=%d, halves %.1fx%d,"
						.. " caption y=%d, rule y=%d, first row y=%d -> %d",
					without.height,
					with.height,
					ROLE.BLOCK_PX,
					with.trackWidth,
					ROLE.TRACK_PX,
					with.trackY,
					with.halfWidth,
					ROLE.TRACK_PX - 2 * Hud.Shop.ROLE_SWITCH.TRACK_PAD,
					with.captionY,
					with.ruleY,
					without.rowY[1],
					with.rowY[1]
				)
			)
			-- THE TWO HALVES PLUS ONE GAP EXACTLY FILL THE PADDED INTERIOR -- the FORMULA, which is
			-- what is built, and not the Designer's drawing, which forgot the 3 px between them.
			local SWITCH = Hud.Shop.ROLE_SWITCH
			expect(2 * with.halfWidth + SWITCH.TRACK_GAP + 2 * SWITCH.TRACK_PAD).to.equal(with.trackWidth)
		end)

		it("draws nothing at all for a man who does not own the place", function()
			-- ABSENT, NOT GREYED AND NOT LOCKED. The attribute's absence is the whole gate.
			PadPanel.setAsk(2)
			PadPanel.setRoleWish(nil, nil, 720)
			local block = (Hud.padPanel() :: Frame):FindFirstChild("RoleBlock") :: Frame?
			expect(block).to.be.ok()
			expect((block :: Frame).Visible).to.equal(false)
			-- ...AND THE TRACK GOES WITH IT, which is the other half of finding 1: it is shown and
			-- hidden by the ONE writer of this dialog's rectangles, never left behind.
			local hidden = (block :: Frame):FindFirstChild("RoleSwitch") :: Frame
			expect(hidden).to.be.ok()
			expect(hidden.Visible).to.equal(false)
			expect(PadPanel.roleSelected(nil)).to.equal(nil)
			expect(PadPanel.roleLit()).to.equal(nil)
			expect(#PadPanel.switchText()).to.equal(0)
			expect(PadPanel.roleCaptionFor(nil, nil, nil)).to.equal("")
			-- ...AND A WORD THIS SYSTEM DOES NOT KNOW IS NOT A THIRD STATE.
			PadPanel.setRoleWish("shooter", nil, 720)
			expect(PadPanel.roleWish()).to.equal(nil)
			expect((block :: Frame).Visible).to.equal(false)
		end)

		it("lights the half the SERVER chose, and the words are the data's", function()
			local ROLE = PANEL.ROLE
			PadPanel.setAsk(2)
			PadPanel.setRoleWish(LobbyData.ROLE_WISH.HUNTER, nil, 720)
			local block = (Hud.padPanel() :: Frame):FindFirstChild("RoleBlock") :: Frame
			expect(block.Visible).to.equal(true)
			-- ...AND THE CONTROL ITSELF IS ACTUALLY RENDERED (review round 2, finding 1). The block is
			-- only the HOLDER -- it carries the eyebrow and the caption, and the two halves live
			-- inside the TRACK. `buildRoleSwitch` builds that track `Visible = false` and for two
			-- rounds nothing wrote it true, so the switch was positioned, painted and never drawn: a
			-- `GuiObject` at `Visible = false` is not rendered and takes no input however visible its
			-- parent is. Asserting the holder could never catch that; this is what does.
			local track = block:FindFirstChild("RoleSwitch") :: Frame
			expect(track).to.be.ok()
			expect(track.Visible).to.equal(true)
			for _, name in ipairs({ "Hunter", "Beater" }) do
				local half = track:FindFirstChild(name) :: TextButton
				expect(half).to.be.ok()
				expect(half.Visible).to.equal(true)
			end
			expect(PadPanel.roleLit()).to.equal(LobbyData.ROLE_WISH.HUNTER)
			expect(PadPanel.switchText()).to.be.ok()
			local words = PadPanel.switchText()
			-- FIVE SINCE TASK 244, not four: the key chip rides the eyebrow's own row.
			expect(#words).to.equal(5)
			expect(words[1]).to.equal(Hud.Shop.spaced(ROLE.EYEBROW))
			expect(words[2]).to.equal(Hud.Shop.spaced(string.format(ROLE.KEY_HINT, PadPanel.switchKeyName())))
			expect(words[3]).to.equal(Hud.Shop.spaced(ROLE.HUNTER))
			expect(words[4]).to.equal(Hud.Shop.spaced(ROLE.BEATER))
			expect(words[5]).to.equal(Hud.Shop.spaced(ROLE.NOTE_HUNTER))
			-- THE OTHER HALF, AND THE CAPTION FOLLOWS IT.
			PadPanel.setRoleWish(LobbyData.ROLE_WISH.BEATER, nil, 720)
			expect(PadPanel.roleLit()).to.equal(LobbyData.ROLE_WISH.BEATER)
			expect(PadPanel.switchText()[5]).to.equal(Hud.Shop.spaced(ROLE.NOTE_BEATER))
		end)

		it("says WHY it cannot be used, in four rows and never in silence", function()
			-- THE HALF OF XONOTIC'S TEAM MENU THIS REPOSITORY INVERTS: it refuses by returning
			-- `false` with nothing said to the player, and Karen reads a silent no-op as broken.
			local ROLE = PANEL.ROLE
			expect(PadPanel.roleCaptionFor(LobbyData.ROLE_WISH.HUNTER, nil, nil)).to.equal(ROLE.NOTE_HUNTER)
			expect(PadPanel.roleCaptionFor(LobbyData.ROLE_WISH.BEATER, nil, nil)).to.equal(ROLE.NOTE_BEATER)
			-- A PARTY OF ONE READS LIKE ANY OTHER SINCE TASK 242 (Karen, 2026-10-22). It used to
			-- say `NO BEATERS THIS DRIVE`, because `Roster.assign` honoured nobody at one player;
			-- she held the `ALWAYS HUNTER` card -- the card that buys the choice, and the ONLY
			-- one that does -- stood on the pad alone and asked to beat, and a solo wisher is
			-- now dealt the beaters' side with bot hunters on the stands.
			expect(PadPanel.roleCaptionFor(LobbyData.ROLE_WISH.BEATER, nil, 1)).to.equal(ROLE.NOTE_SENT)
			-- A PARTY OF TWO OR MORE, ALREADY ASKED FOR.
			expect(PadPanel.roleCaptionFor(LobbyData.ROLE_WISH.BEATER, nil, 2)).to.equal(ROLE.NOTE_SENT)
			expect(PadPanel.roleCaptionFor(LobbyData.ROLE_WISH.BEATER, nil, 4)).to.equal(ROLE.NOTE_SENT)
			-- THE DRIVE ALREADY HAS HIM.
			expect(PadPanel.roleCaptionFor(LobbyData.ROLE_WISH.HUNTER, "Shooters", nil)).to.equal(ROLE.NOTE_SENT)
			-- AND THE DIMMING AND THE WORDS CANNOT DISAGREE, because one predicate decides both.
			expect(PadPanel.roleUsable(LobbyData.ROLE_WISH.HUNTER, nil, nil)).to.equal(true)
			expect(PadPanel.roleUsable(LobbyData.ROLE_WISH.BEATER, nil, 1)).to.equal(false)
			expect(PadPanel.roleUsable(LobbyData.ROLE_WISH.BEATER, nil, 4)).to.equal(false)
			expect(PadPanel.roleUsable(LobbyData.ROLE_WISH.BEATER, "Drivers", nil)).to.equal(false)
			expect(PadPanel.roleUsable(nil, nil, nil)).to.equal(false)
		end)

		it("goes dim WITH the rows once a size is pressed, and is not hidden", function()
			-- HIDING IT AT THAT MOMENT WOULD MAKE THE DIALOG JUMP 119 px UNDER THE PLAYER'S THUMB
			-- while the truck is loading, *"which is the one thing a dialog must never do"*.
			PadPanel.setRemotes({
				PadRequest = { FireServer = function() end },
				RoleRequest = { FireServer = function() end },
			})
			PadPanel.setAsk(2)
			PadPanel.setRoleWish(LobbyData.ROLE_WISH.BEATER, nil, 720)
			local block = (Hud.padPanel() :: Frame):FindFirstChild("RoleBlock") :: Frame
			local tall = (Hud.padPanel() :: Frame).Size.Y.Offset
			expect(PadPanel.press(1)).to.equal(true)
			expect(block.Visible).to.equal(true)
			expect((Hud.padPanel() :: Frame).Size.Y.Offset).to.equal(tall)
			expect(PadPanel.switchText()[5]).to.equal(Hud.Shop.spaced(PANEL.ROLE.NOTE_SENT))
			-- ...AND A PRESS ON A HALF IS REFUSED FROM HERE ON, counted and not sent.
			local blocked = PadPanel.stats().roleBlocked
			expect(PadPanel.sendRoleWish(LobbyData.ROLE_WISH.HUNTER)).to.equal(false)
			expect(PadPanel.stats().roleBlocked).to.equal(blocked + 1)
			PadPanel.setRemotes(nil)
		end)

		it("sends one message per press, and nothing for a word it does not know", function()
			local sent: { any } = {}
			PadPanel.setRemotes({
				PadRequest = { FireServer = function() end },
				RoleRequest = {
					FireServer = function(_self, payload: any)
						table.insert(sent, payload)
					end,
				},
			})
			PadPanel.setAsk(2)
			PadPanel.setRoleWish(LobbyData.ROLE_WISH.HUNTER, nil, 720)
			expect(PadPanel.sendRoleWish(LobbyData.ROLE_WISH.BEATER)).to.equal(true)
			expect(#sent).to.equal(1)
			expect(sent[1].role).to.equal(LobbyData.ROLE_WISH.BEATER)
			-- NOTHING BUT THE ONE WORD IS ON THE WIRE: the server measures every other fact itself.
			local keys = 0
			for _ in pairs(sent[1]) do
				keys += 1
			end
			expect(keys).to.equal(1)
			-- A WORD THIS SYSTEM DOES NOT KNOW IS NOT SENT: the server refuses it anyway, and a
			-- client that sent one would be telling the server a lie about its own catalogue.
			expect(PadPanel.sendRoleWish("Drivers")).to.equal(false)
			expect(#sent).to.equal(1)
			-- NO OPTIMISTIC REDRAW: the lit half is still the server's last word, not the press.
			expect(PadPanel.roleLit()).to.equal(LobbyData.ROLE_WISH.HUNTER)
			-- ...AND WITH NO REMOTE AT ALL IT RETURNS RATHER THAN THROWING.
			PadPanel.setRemotes(nil)
			expect(PadPanel.sendRoleWish(LobbyData.ROLE_WISH.BEATER)).to.equal(false)
		end)

		it("writes every rectangle once per CHANGE, not once per frame", function()
			-- `relayout` IS THE ONE WRITER, and it must stay edge-triggered: a dialog re-laid-out
			-- every frame would be a second writer of what `render` paints.
			PadPanel.setAsk(2)
			PadPanel.setRoleWish(LobbyData.ROLE_WISH.HUNTER, nil, 720)
			local was = PadPanel.stats().relayouts
			for _ = 1, 10 do
				PadPanel.setRoleWish(LobbyData.ROLE_WISH.HUNTER, nil, 720)
			end
			expect(PadPanel.stats().relayouts).to.equal(was)
			-- THE WORD CHANGING REPAINTS AND DOES NOT MOVE ANYTHING, because the rectangle is the
			-- same: only the wish APPEARING or DISAPPEARING changes the dialog's height.
			PadPanel.setRoleWish(LobbyData.ROLE_WISH.BEATER, nil, 720)
			expect(PadPanel.stats().relayouts).to.equal(was)
			PadPanel.setRoleWish(nil, nil, 720)
			expect(PadPanel.stats().relayouts).to.equal(was + 1)
		end)

		-- ======================================================= TASK 244: THE DEAD WIRE
		--
		-- KAREN, 2026-10-22, with a frame of the dialog and her cursor ON the BEATER half: *"I still
		-- can't select before game who I want to be"*.
		--
		-- WHAT THE DEFECT ACTUALLY WAS, measured on her path in the live Forest Test with a wiretap
		-- on `Lobby.Remotes` and a REAL OS mouse click: the half TOOK the click -- its press tint was
		-- drawn -- and `RoleRequest` never reached the server. `Hud.start` tells this module its
		-- remotes through `PadPanel.setRemotes` BEFORE it calls `PadPanel.start`, because
		-- `Hud.whenReady` runs its callback synchronously for a module that has already replicated;
		-- `start` then wrote `bag.remotes` -- nil, the Hud passes no such key -- straight over it.
		-- Every size row was dead the same way, hidden behind the pad's 8-second default.
		--
		-- A SPEC CANNOT FIRE `Activated`, so what it CAN hold is the one thing that broke: `start`
		-- must not un-tell what `setRemotes` told it. The click proof is a frame plus a live
		-- attribute read, in the review request.
		it("never lets `start` un-tell the remotes `setRemotes` already gave it (task 244)", function()
			-- **IT DRIVES A REAL `start`, IN THE HUD'S OWN ORDER** (round 1, finding 1). The first
			-- version of this case asserted the rule where it could not fail: `PadPanel.start` opens
			-- with `if started then return end` and the live panel is already started, so the changed
			-- line never ran and the case passed with the fix reverted. The Reviewer is right, and the
			-- fix is to stop the panel first -- which is what the mouse-and-trigger case above already
			-- does, and it puts the live one back the same way.
			local sent: { any } = {}
			local fake = {
				RoleRequest = {
					FireServer = function(_self, payload: any)
						table.insert(sent, payload)
					end,
				},
			}

			-- THE HUD'S ORDER, AND IT IS THE WHOLE DEFECT: `Hud.start` resolves `ReplicatedStorage.Lobby`
			-- through `Hud.whenReady` -- which calls its callback SYNCHRONOUSLY for a module that has
			-- already replicated, and it always has -- so `setRemotes` lands BEFORE `start`, and the bag
			-- `Hud.start` passes carries no `remotes` key at all.
			PadPanel.stop()
			PadPanel.setRemotes(fake)
			PadPanel.start(Hud.padPanel() :: Frame, { leaving = Hud.padLeaving() })
			PadPanel.setAsk(2)
			PadPanel.setRoleWish(LobbyData.ROLE_WISH.HUNTER, nil, 720)
			expect(PadPanel.sendRoleWish(LobbyData.ROLE_WISH.BEATER)).to.equal(true)
			expect(#sent).to.equal(1)
			expect(sent[1].role).to.equal(LobbyData.ROLE_WISH.BEATER)

			-- ...AND A BAG THAT BRINGS ONE STILL WINS, so every caller written before this is unchanged.
			PadPanel.stop()
			PadPanel.setRemotes(nil)
			PadPanel.start(Hud.padPanel() :: Frame, { remotes = fake, leaving = Hud.padLeaving() })
			PadPanel.setAsk(2)
			PadPanel.setRoleWish(LobbyData.ROLE_WISH.HUNTER, nil, 720)
			expect(PadPanel.sendRoleWish(LobbyData.ROLE_WISH.BEATER)).to.equal(true)
			expect(#sent).to.equal(2)

			-- ...AND WITH NO WIRE AT ALL IT REFUSES rather than pretending. That is the state Karen was
			-- in, and the counter is what tells the two apart from outside.
			PadPanel.setRemotes(nil)
			local was = PadPanel.stats().roleBlocked
			expect(PadPanel.sendRoleWish(LobbyData.ROLE_WISH.BEATER)).to.equal(false)
			expect(PadPanel.stats().roleBlocked).to.equal(was + 1)

			-- THE LIVE PANEL GOES BACK, because this case took it over -- the restore the
			-- mouse-and-trigger case makes, for its reason, and asserted rather than assumed.
			PadPanel.stop()
			PadPanel.start(Hud.padPanel() :: Frame, { remotes = nil, leaving = Hud.padLeaving() })
			local rebuilt = 0
			for _, child in ipairs((Hud.padPanel() :: Frame):GetChildren()) do
				if child:IsA("TextButton") then
					rebuilt += 1
				end
			end
			expect(rebuilt).to.equal(#PADS.SIZES)
		end)

		it("offers a KEY as well as a click, and says which key on the control (task 244)", function()
			-- THE OTHER HALF, PURE: one rule, so the key, a press and a probe cannot disagree about
			-- what *"the other one"* means.
			expect(PadPanel.otherRole(LobbyData.ROLE_WISH.HUNTER)).to.equal(LobbyData.ROLE_WISH.BEATER)
			expect(PadPanel.otherRole(LobbyData.ROLE_WISH.BEATER)).to.equal(LobbyData.ROLE_WISH.HUNTER)
			-- A MAN WITH NO WISH HAS NO BLOCK AND NOTHING TO TOGGLE.
			expect(PadPanel.otherRole(nil)).to.equal(nil)
			expect(PadPanel.otherRole("rabbit")).to.equal(nil)

			local sent: { any } = {}
			PadPanel.setRemotes({
				RoleRequest = {
					FireServer = function(_self, payload: any)
						table.insert(sent, payload)
					end,
				},
			})
			PadPanel.setAsk(2)
			PadPanel.setRoleWish(LobbyData.ROLE_WISH.HUNTER, nil, 720)
			-- THE KEY GOES THROUGH THE ONE SENDER, so every guard is asked once and the key cannot
			-- do something the control would not.
			expect(PadPanel.toggleRoleWish()).to.equal(true)
			expect(#sent).to.equal(1)
			expect(sent[1].role).to.equal(LobbyData.ROLE_WISH.BEATER)
			-- ...AND IT IS REFUSED IN EXACTLY THE STATES THE CONTROL IS: a side already dealt.
			PadPanel.setRoleWish(LobbyData.ROLE_WISH.HUNTER, "Shooters", 720)
			expect(PadPanel.toggleRoleWish()).to.equal(false)
			expect(#sent).to.equal(1)
			PadPanel.setRoleWish(LobbyData.ROLE_WISH.HUNTER, nil, 720)

			-- THE CHIP SAYS THE KEY'S OWN NAME, so the words and the binding cannot drift.
			local block = (Hud.padPanel() :: Frame):FindFirstChild("RoleBlock") :: Frame
			local chip = block:FindFirstChild("RoleKey") :: TextLabel
			expect(chip).to.be.ok()
			expect(chip.Text).to.equal(Hud.Style.spaced(string.format(PANEL.ROLE.KEY_HINT, PadPanel.switchKeyName())))
			expect(chip.TextXAlignment).to.equal(Enum.TextXAlignment.Right)
			-- IT SHARES THE EYEBROW'S ROW rather than taking one, which is what keeps `BLOCK_PX`
			-- the same number it was.
			local brow = block:FindFirstChild("RoleEyebrow") :: TextLabel
			expect(chip.AbsolutePosition.Y).to.equal(brow.AbsolutePosition.Y)
			expect(PadPanel.heightFor(4, true) - PadPanel.heightFor(4, false)).to.equal(PANEL.ROLE.BLOCK_PX)

			-- **AND THE TWO RECTANGLES ARE DISJOINT** (round 1 note). Both labels were full-width at
			-- the same Y with `TextTruncate.AtEnd`, which HIDES a collision rather than preventing
			-- one -- and `spaced()` makes both of them long. The row is split now, and this is the
			-- arithmetic rather than a screenshot.
			local browRight = brow.AbsolutePosition.X + brow.AbsoluteSize.X
			expect(chip.AbsolutePosition.X >= browRight).to.equal(true)
			expect(chip.AbsoluteSize.X).to.equal(PANEL.ROLE.KEY_PX)
			-- ...AND NEITHER WORD IS ACTUALLY TRUNCATED at the size it is drawn, which is the claim
			-- `TextTruncate` would otherwise be covering up. `TextBounds` is what the engine
			-- measured for the text that is really in the label.
			expect(chip.TextBounds.X <= chip.AbsoluteSize.X).to.equal(true)
			expect(brow.TextBounds.X <= brow.AbsoluteSize.X).to.equal(true)
			TestKit.note(
				string.format(
					"pad_panel: eyebrow %.0f px of %.0f, key chip %.0f px of %.0f, gap %.0f",
					brow.TextBounds.X,
					brow.AbsoluteSize.X,
					chip.TextBounds.X,
					chip.AbsoluteSize.X,
					chip.AbsolutePosition.X - browRight
				)
			)
			PadPanel.setRemotes(nil)
		end)

		it("binds the key only while the dialog is up, and hands it back (task 244)", function()
			-- `T` BELONGS TO THE PLAYER AGAIN THE INSTANT HE STEPS OFF THE PAD, which is
			-- `LicenceCard.bindBuyKey`'s rule and its stated reason.
			PadPanel.setAsk(nil)
			expect(PadPanel.switchKeyBound()).to.equal(false)
			PadPanel.setAsk(2)
			expect(PadPanel.switchKeyBound()).to.equal(true)
			-- A SECOND OPEN BINDS NOTHING TWICE.
			PadPanel.setAsk(3)
			expect(PadPanel.switchKeyBound()).to.equal(true)
			PadPanel.setAsk(nil)
			expect(PadPanel.switchKeyBound()).to.equal(false)
		end)

		it("puts the two halves above the block's own labels, so a press reaches them", function()
			PadPanel.setAsk(2)
			PadPanel.setRoleWish(LobbyData.ROLE_WISH.HUNTER, nil, 720)
			local block = (Hud.padPanel() :: Frame):FindFirstChild("RoleBlock") :: Frame
			local track = block:FindFirstChild("RoleSwitch") :: Frame
			expect(track).to.be.ok()
			local brow = block:FindFirstChild("RoleEyebrow") :: TextLabel
			for _, name in ipairs({ "Hunter", "Beater" }) do
				local half = track:FindFirstChild(name) :: TextButton
				expect(half).to.be.ok()
				expect(half.ZIndex > brow.ZIndex).to.equal(true)
				expect(half.AutoButtonColor).to.equal(false)
				-- THE HALF CARRIES NO TEXT OF ITS OWN: the word is a centred child label.
				expect(half.Text).to.equal("")
				expect(half:FindFirstChild("Word")).to.be.ok()
			end
		end)
	end)
end
