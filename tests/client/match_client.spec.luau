-- match_client.spec: the drive from the player's side -- the replica, the drive bar, and the one
-- property this system claims that a grep alone cannot prove: it has NO inbound remote at all.
--
-- It reaches the modules through Players.LocalPlayer.PlayerScripts, never through
-- StarterPlayerScripts, which is a template.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/drive.md (sections 9.1, 9.3, 12.7)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))
local Horn = require(ReplicatedStorage:WaitForChild("Horn"))
-- The one place a data kind becomes a player-facing noun (`Report.kindWord`, 201 part 3): the
-- start card, the hit card and the report all read it, and the card's rule-4 case asserts it here.
local Report = require(ReplicatedStorage:WaitForChild("Report"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Role = require(ReplicatedStorage:WaitForChild("ClientTests"):WaitForChild("Role"))

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Match = require(scripts:WaitForChild("Match"))
local Hud = require(scripts:WaitForChild("Hud"))
-- The Hud's own 2-D sound owner, reached the same way: through PlayerScripts, never the template.
local Sound = require(scripts:WaitForChild("Hud"):WaitForChild("Sound"))

local function waitUntil(seconds: number, predicate: () -> boolean): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if predicate() then
			return true
		end
		task.wait(0.05)
	end
	return predicate()
end

return function()
	describe("the wire", function()
		it("has exactly two remotes, and both are server to client", function()
			local folder = ReplicatedStorage:WaitForChild("Drive"):WaitForChild("Remotes")
			local remotes = Drive.remotes()
			expect(remotes.MatchState:IsA("RemoteEvent")).to.equal(true)
			expect(remotes.MatchEvent:IsA("RemoteEvent")).to.equal(true)

			-- No RemoteFunction, and no third RemoteEvent: this system takes no client input at all,
			-- so its inbound exploit surface is zero, and that is worth keeping (design section 9.1).
			local count = 0
			for _, child in ipairs(folder:GetChildren()) do
				expect(child:IsA("RemoteEvent")).to.equal(true)
				count += 1
			end
			expect(count).to.equal(2)
		end)

		it("keeps the shared config frozen to its nested tables", function()
			expect(Drive.CONFIG.SCOREBOARD_ENABLED).to.equal(true) -- 1.7b: the score screen is built
			expect(function()
				(Drive.CONFIG :: any).FEED_LINES = 99
			end).to.throw()
		end)

		it("carries no rule number, which is the reason the two configs are separate", function()
			-- A client that knows the safety numbers can dodge the rule by eye, so they live in
			-- Match.CONFIG on the server and are never replicated (design section 3.4). This is the
			-- assertion that keeps them there.
			for _, field in ipairs({
				"SAFETY_MISS_STUDS",
				"SAFETY_RANGE_STUDS",
				"SAFETY_BODY_STUDS",
				"TIE_SECONDS",
				"DRIVE_SECONDS",
				"POINTS",
				-- ...AND NO COIN RATE EITHER (task 170). `Economy.CONFIG` is server-only for the same
				-- reason `POINTS` is: the SCREEN is told two results (`row.coins`, `row.earned`) and
				-- never the arithmetic that produced them.
				"COINS_PER_POINT",
				"PARTICIPATION",
				"FIRST_PLACE",
				"FLOOR",
				"STORE_NAME",
			}) do
				expect((Drive.CONFIG :: any)[field]).to.equal(nil)
			end
			-- BY PATTERN AS WELL AS BY NAME, so a rate added later under a name nobody listed here
			-- still fails: nothing in the client's contract may be called COIN-anything except the
			-- words the panel draws (`SCORE_COINS_LABEL`, `SCORE_COINS_UNKNOWN`), which are strings.
			for key, value in pairs(Drive.CONFIG) do
				if string.find(key, "COIN", 1, true) ~= nil then
					expect(type(value)).to.equal("string")
				end
			end
		end)
	end)

	describe("the replica", function()
		it("arrives from the server and is frozen all the way down", function()
			expect(waitUntil(30, function()
				return Match.get() ~= nil
			end)).to.equal(true)
			local snapshot = Match.get()
			print(
				string.format(
					"[match_client] phase=%s drive=%d rows=%d",
					snapshot.phase,
					snapshot.driveNumber,
					#snapshot.rows
				)
			)
			expect(function()
				(snapshot :: any).phase = "Running"
			end).to.throw()
			-- Not `if rows[1] then`: a guard like that turns into an assertion that quietly tests
			-- nothing the day the board is empty. PlayerAdded puts this player on the board, so a
			-- row is certain, and that is asserted first.
			expect(#snapshot.rows >= 1).to.equal(true)
			expect(function()
				snapshot.rows[1].points = 999
			end).to.throw()
		end)

		it("counts down locally from the server's timestamp, and never goes negative", function()
			expect(waitUntil(30, function()
				return Match.get() ~= nil
			end)).to.equal(true)
			local snapshot = Match.get()
			local expected = math.max(0, snapshot.phaseEndsAt - Workspace:GetServerTimeNow())
			expect(math.abs(Match.secondsLeft() - expected) < 0.5).to.equal(true)
			expect(Match.secondsLeft() >= 0).to.equal(true)
		end)

		it("reads the team from Player.Team, which is the one representation", function()
			expect(waitUntil(30, function()
				return Match.myTeam() ~= nil
			end)).to.equal(true)
			expect(Match.myTeam()).to.equal(player.Team and player.Team.Name)
		end)
	end)

	describe("the drive bar", function()
		it("is really on screen: every ancestor present and visible", function()
			expect(waitUntil(30, function()
				return Hud.isDriveBarVisible()
			end)).to.equal(true)

			local gui = Hud.gui()
			local bar = gui:FindFirstChild("DriveBar")
			expect(bar).to.be.ok()
			-- The ancestor walk, not just `Visible`: "a visibility audit ignored parent visibility
			-- and certified a blank screen twice" (docs/PROJECT_CONTEXT.md).
			local node: Instance? = bar
			while node and node ~= game do
				if node:IsA("GuiObject") then
					expect(node.Visible).to.equal(true)
				elseif node:IsA("ScreenGui") then
					expect(node.Enabled).to.equal(true)
				end
				node = node.Parent
			end
			expect(node).to.equal(game)
		end)

		it("says the drive number, a clock and the team badge, and never renders a nil", function()
			expect(waitUntil(30, function()
				return Hud.driveBarText() ~= ""
			end)).to.equal(true)
			local text = Hud.driveBarText()
			print("[match_client] drive bar: " .. text)
			expect(string.find(text, "DRIVE %d") ~= nil).to.equal(true)
			expect(string.find(text, "nil") == nil).to.equal(true)
			-- THE BADGE IS THIS PLAYER'S OWN. With one player that is the hunter (Director decision
			-- F); in a two-player run one client is the beater and its badge must say so, in its own
			-- team colour. Asserting one word for everybody was a one-player claim inside a suite
			-- the two-player run has to pass (TASKS.md row 34a).
			--
			-- `HUNTER` / `BEATER` SINCE 201 PART 3 (201a), and the two halves of the claim are
			-- different: the TEAM is still `Shooters` / `Drivers` -- the string the server, the
			-- wire and `Style.teamColor` use -- and only the drawn WORD moved.
			expect(string.find(text, Role.badge()) ~= nil).to.equal(true)
			expect(Role.badge()).to.equal(if Match.myTeam() == "Drivers" then "BEATER" else "HUNTER")
			expect(Hud.roleBadge(Match.myTeam())).to.equal(Role.badge())
			-- THE OLD VOCABULARY IS ASSERTED AS GONE FROM THE BAR, not merely replaced: the defect
			-- was the HUD saying two things for one fact.
			expect(string.find(text, "SHOOTER", 1, true)).to.equal(nil)
			expect(string.find(text, "DRIVER", 1, true)).to.equal(nil)
			local phase = Match.phase()
			if phase == "Running" or phase == "Assigning" or phase == "Scoring" then
				expect(string.find(text, "%d+:%d%d") ~= nil).to.equal(true)
			end
		end)
	end)

	describe("the score screen", function()
		-- A DRIVE IS 600 SECONDS, so no harness run reaches the Scoring phase and the panel is never
		-- shown by the wire inside a test. The Hud's renderScore is public for exactly this (it says
		-- so in its header): this hands it the snapshot the server WOULD send and then checks the
		-- screen, which is the only way to make the design's visibility assertion (section 12.7 item
		-- 4) at all. The screenshot is separate evidence and is not replaced by this.
		local LIVE = {
			phase = "Running",
			phaseEndsAt = 0,
			driveNumber = 3,
			boarsReleased = 2,
			boarsLeft = 4,
			waitingFor = {},
			quarry = { "WILD BOAR: male, female, cub", "a piglet COSTS you - leave them" },
			rows = {},
			tied = {},
		}

		local function scoring()
			local snapshot = table.clone(LIVE)
			snapshot.phase = "Scoring"
			-- THIS FIXTURE IS A BUILD WITH MONEY IN IT (round 2 of the gate): `coinsOn` is the one fact on
			-- the snapshot that says so, and without it the Hud draws no balance at all.
			snapshot.coinsOn = true
			snapshot.rows = {
				{
					userId = player.UserId,
					name = player.Name,
					team = "Shooters",
					-- A MALE AND A FEMALE, PRICED BY TASK 160's TABLE (10 + 6). It was 180 -- two head
					-- shots at the retired zone table's 100 and 80 -- and the row is rescaled with it
					-- so that a fixture nobody re-reads cannot keep showing Karen a number the game
					-- can no longer produce.
					points = 16,
					kills = 2,
					assists = 0,
					pushes = 0,
					violations = 0,
					left = false,
					-- WHAT THE ECONOMY PUT ON THE WIRE (task 170): the balance after this drive, and what
					-- this drive paid him. 16 points x 2 + 10 participation + 25 for first place in his own
					-- ranking = 67, on a balance that was 1173 before it.
					coins = 1240,
					earned = 67,
				},
				{
					userId = player.UserId + 1,
					name = "Mila",
					team = "Drivers",
					points = 3, -- one animal pushed onto the guns: POINTS.BEATER_PUSH
					kills = 0,
					assists = 0,
					pushes = 1,
					violations = 0,
					left = false,
					-- 3 x 2 + 10 + 25 (she is first of the BEATERS, which is her own ranking) = 41.
					coins = 141,
					earned = 41,
				},
			}
			return Drive.deepFreeze(snapshot)
		end

		-- Whatever this describe did, put the real snapshot back: another spec may read the Hud after
		-- it, and the Heartbeat would fix it within 0.25 s anyway -- but "would" is not a test.
		-- THE SCORE BOARD IS HIDDEN WHILE THE REPORT PANEL IS OPEN. Until task 159 the report also
		-- OPENED BY ITSELF when a drive closed, and this describe -- which renders scripted snapshots
		-- and says nothing about the report -- had that as an unstated precondition; the gate found
		-- it, when a live drive closed part-way through a one-player run and all three cases below
		-- failed with an empty board (`match_client.spec` "Expected 2, got 0", `report_panel.spec`
		-- "Expected false, got true"). The auto-open is off now (the end of a drive is the results
		-- scene), so the only way the panel is open here is another spec leaving it open -- and this
		-- stays, because a precondition that is cheap to state should not depend on a default.
		--
		-- STATING IT IS NOT WEAKENING ANYTHING: `Hud.scorePanelVisible(snapshot, reportOpen)` already
		-- takes the report's state as an argument, and its own case still drives both values. This
		-- only stops a drive that ended at the wrong moment from deciding what the board shows.
		local reportWasOpen = false

		beforeAll(function()
			reportWasOpen = Hud.Report.isOpen()
			if reportWasOpen then
				TestKit.note("match_client: a drive report was open; closed for the score cases")
				Hud.Report.setOpen(false)
			end
		end)

		afterAll(function()
			if reportWasOpen then
				Hud.Report.setOpen(true)
			end
			Hud.renderScore(Match.get(), Match.secondsLeft())
			Hud.renderTied(Match.isTied())
		end)

		it("is hidden while the drive is running", function()
			Hud.renderScore(LIVE, 120)
			expect(Hud.isScorePanelVisible()).to.equal(false)
			expect(#Hud.scoreRowText()).to.equal(0)
			-- ...and the bar is the thing on screen instead.
			expect(Hud.isDriveBarVisible()).to.equal(true)
		end)

		it("is really on screen in Scoring: every ancestor present and visible", function()
			Hud.renderScore(scoring(), 12)
			expect(Hud.isScorePanelVisible()).to.equal(true)

			local panel = Hud.scorePanel()
			expect(panel).to.be.ok()
			-- The ancestor walk, not just `Visible`: "a visibility audit ignored parent visibility and
			-- certified a blank screen twice" (docs/PROJECT_CONTEXT.md).
			local node: Instance? = panel
			while node and node ~= game do
				if node:IsA("GuiObject") then
					expect(node.Visible).to.equal(true)
				elseif node:IsA("ScreenGui") then
					expect(node.Enabled).to.equal(true)
				end
				node = node.Parent
			end
			expect(node).to.equal(game)
			-- ...and it is not a fully transparent panel drawing invisible text on nothing.
			expect(panel.BackgroundTransparency < 1).to.equal(true)
		end)

		it("draws every CELL in front of its own card, and never in Code or in a black outline", function()
			-- THE DEFECT THIS CASE EXISTS FOR, and it shipped twice before anybody looked: task 141
			-- raised this board to `Report.CONFIG.PANEL_Z_INDEX` (15) so it would not be cut off at
			-- the scope's glass, and left every label at the default ZIndex 1 -- so the translucent
			-- dark panel was drawn OVER its own words. `Hud.scoreRowText()` read them back perfectly
			-- the whole time; the screen showed a grey rectangle
			-- (.screenshots/20261011T230908Z-task159-results-scene.png). `ReportPanel` had already
			-- paid for exactly this on 2026-10-05, which is why the rule is now one helper in
			-- `Hud.Style` and this is asserted.
			--
			-- IT IS A CARD OF TABLE ROWS SINCE TASK 201 PART 2 (the Designer's design system,
			-- 2026-10-17, section 3.12), so what is walked is every descendant and not the direct
			-- children: one `TextLabel` PER CELL, inside a row, inside the scrolling body.
			Hud.renderScore(scoring(), 12)
			local board = Hud.scorePanel()
			expect(board).to.be.ok()
			local Style = Hud.Style
			local checked, offenders = 0, {}
			for _, node in ipairs(board:GetDescendants()) do
				if node:IsA("TextLabel") and node.Visible and node.Text ~= "" then
					checked += 1
					-- IN FRONT OF THE SURFACE IT SITS ON.
					if node.ZIndex <= board.ZIndex then
						table.insert(offenders, node.Name .. " (behind the card)")
					end
					-- NO `Enum.Font.Code` AND NO BLACK OUTLINE. The card is what carries the words
					-- now; an outline halves the apparent size of 11 px type and still fails over a
					-- bright sky (section 2).
					if node.Font == Enum.Font.Code then
						table.insert(offenders, node.Name .. " (Code)")
					end
					local stroke = node:FindFirstChildOfClass("UIStroke")
					if stroke ~= nil and stroke.Color == Color3.new(0, 0, 0) then
						table.insert(offenders, node.Name .. " (black stroke)")
					end
					if node.TextTransparency >= 0.5 then
						table.insert(offenders, node.Name .. " (faded out)")
					end
				end
			end
			expect(table.concat(offenders, ", ")).to.equal("")
			-- Title, eyebrow, the column heads, and the cells of the rows that are drawn.
			expect(checked > 6).to.equal(true)
			-- THE CARD, and it is a card and not a modal: see-through at `Style.CARD_T`, which is
			-- the other half of what Karen asked for (*"showing image transperent with results
			-- table"*).
			expect(board.BackgroundColor3).to.equal(Style.LOOK.PANEL)
			expect(board.BackgroundTransparency).to.be.near(Style.CARD_T, 1e-5)
			expect(Style.CARD_T > 0).to.equal(true)
			-- THE EYEBROW AND THE TITLE PAIR (section 3.4): the small brass word saying what kind of
			-- thing this is, over the thing.
			local header = board:FindFirstChild("Header")
			expect(header).to.be.ok()
			local eyebrow = header:FindFirstChild("Eyebrow")
			local title = header:FindFirstChild("Title")
			expect(eyebrow.TextColor3).to.equal(Style.LOOK.BRASS)
			expect(title.TextSize).to.equal(Style.sizeFor("TITLE", Hud.viewportX()))
			expect(title.FontFace).to.equal(Style.FONT.OSWALD_SB)
			TestKit.note(
				string.format(
					"match_client: results card -- %d cells, z=%d, alpha %.2f, title %d",
					checked,
					board.ZIndex,
					board.BackgroundTransparency,
					title.TextSize
				)
			)
		end)

		it("shows this drive's points, one row per player, mine with a team bar", function()
			Hud.renderScore(scoring(), 12)
			local rows = Hud.scoreRowText()
			print("[match_client] score row 1: " .. (rows[1] or "<none>"))
			-- FOUR LINES SINCE TASK 170: a heading over each ranking, and one row under each.
			expect(#rows).to.equal(4)
			expect(rows[1]).to.equal(Drive.CONFIG.SCORE_HUNTERS_HEADING)
			expect(rows[3]).to.equal(Drive.CONFIG.SCORE_BEATERS_HEADING)
			expect(string.find(rows[2], player.Name, 1, true) ~= nil).to.equal(true)
			expect(string.find(rows[2], "16", 1, true) ~= nil).to.equal(true)
			expect(string.find(rows[4], "Mila", 1, true) ~= nil).to.equal(true)
			-- THE TEAM COLUMN IS GONE AND THE HEADING CARRIES THE SIDE (task 170): a `HUNTERS`
			-- heading with SHOOTER on every row under it printed one fact twice, and the width it
			-- freed is the coins column. Asserted as GONE, not merely absent from a name check.
			expect(string.find(rows[2], "SHOOTER", 1, true)).to.equal(nil)
			expect(string.find(rows[4], "DRIVER", 1, true)).to.equal(nil)
			-- ...AND THE NEW VOCABULARY IS NOT ON THE ROWS EITHER (201a). The pill says HUNTER now,
			-- and the point of the heading is that the ROW does not repeat it.
			expect(string.find(rows[2], "HUNTER", 1, true)).to.equal(nil)
			expect(string.find(rows[4], "BEATER", 1, true)).to.equal(nil)
			expect(string.find(rows[2], "nil", 1, true) == nil).to.equal(true)
			-- WHAT THE DRIVE PAID, with its sign, which is the "+N coins" the task asked for.
			expect(string.find(rows[2], "+67", 1, true) ~= nil).to.equal(true)
			expect(string.find(rows[4], "+41", 1, true) ~= nil).to.equal(true)

			-- EVERY CELL IS INSIDE ITS OWN COLUMN. The character count the old monospace board was
			-- held to is meaningless now -- the numbers line up because they are PLACED (section
			-- 1.2) -- so what a spec can hold is that no cell runs past the next column's x, which
			-- is the thing that actually breaks when a name or a number grows.
			local Style = Hud.Style
			local columns = Hud.BOARD.COLUMNS
			for _, key in ipairs(Hud.BOARD_ORDER) do
				local column = columns[key]
				expect(column.x >= 0).to.equal(true)
				expect(column.x + column.w <= Hud.BOARD.WIDTH - 2 * Hud.BOARD.PADDING).to.equal(true)
			end

			-- MY OWN ROW WEARS A 3 px BAR IN MY TEAM'S COLOUR and my name is `PAPER`; everybody
			-- else's name is `BODY` and their row has no bar (section 3.12).
			local body = Hud.scoreBody()
			expect(body).to.be.ok()
			local mine = body:FindFirstChild("Row2")
			local theirs = body:FindFirstChild("Row4")
			expect(mine).to.be.ok()
			expect(theirs).to.be.ok()
			expect(mine:FindFirstChild("Bar").Visible).to.equal(true)
			expect(theirs:FindFirstChild("Bar").Visible).to.equal(false)
			expect(mine:FindFirstChild("name").TextColor3).to.equal(Style.LOOK.PAPER)
			expect(theirs:FindFirstChild("name").TextColor3).to.equal(Style.LOOK.BODY)
			-- A COINS NUMBER IS BRASS, wherever it is (section 3.12).
			expect(mine:FindFirstChild("coins").TextColor3).to.equal(Style.LOOK.COIN_TEXT)
			-- A SECTION HEAD IS ITS TEAM'S COLOUR, which is the only team colour on this board
			-- besides your own row's bar.
			local hunters = body:FindFirstChild("Head1")
			local beaters = body:FindFirstChild("Head3")
			expect(hunters.Visible).to.equal(true)
			expect(hunters:FindFirstChild("Word").TextColor3).to.equal(Style.LOOK.HUNTER)
			expect(beaters:FindFirstChild("Word").TextColor3).to.equal(Style.LOOK.BEATER)

			-- THE EYEBROW IS WHICH DRIVE AND THE TITLE IS WHAT THIS IS (section 3.4). The wording is
			-- the contract's, so the assertion is against `Drive.CONFIG` and not a string typed twice.
			expect(Hud.scoreEyebrowText()).to.equal(Style.spaced(string.format(Drive.CONFIG.SCORE_EYEBROW_FORMAT, 3)))
			expect(Hud.scoreTitleText()).to.equal(Drive.CONFIG.SCORE_TITLE_WORD)
			expect(Hud.scoreFooterText()).to.equal("NEXT DRIVE IN 12")
		end)

		it("makes its HEIGHT follow the row count, which 20 fixed slots never did", function()
			-- THE ONE THING SECTION 3.12 ASKS FOR BY NAME: *"The results board today is 20 fixed row
			-- slots tall and draws a 480 x 574 box to hold three of them
			-- (`191-gathering-aimed-1.png`). From here on it is `header + rows x rowHeight + footer`,
			-- and it scrolls past 14 rows."*
			local Style = Hud.Style
			local viewX = Hud.viewportX()
			local rowH = Style.rowHeight(viewX)

			-- The arithmetic first: a board of two lines is shorter than a board of twelve, and the
			-- difference is exactly the rows.
			local small = Hud.boardHeight(2, 2, viewX)
			local big = Hud.boardHeight(12, 2, viewX)
			expect(big - small).to.equal(10 * rowH)
			-- ...and it stops growing at 14 rows, because past that the body scrolls.
			expect(Hud.boardHeight(14, 0, viewX)).to.equal(Hud.boardHeight(40, 0, viewX))

			-- THEN THE SCREEN. Two rows and two headings, drawn by the real renderer.
			Hud.renderScore(scoring(), 12)
			local board = Hud.scorePanel()
			local two = board.Size.Y.Offset
			expect(two).to.equal(Hud.boardHeight(2, 2, viewX))
			-- The old board was 574 px tall for exactly this snapshot; this one is far less.
			expect(two < 400).to.equal(true)
			TestKit.note(string.format("match_client: board is %d px for 2 rows + 2 heads", two))
		end)

		it("leaves the footer clear of the table, which the card's own padding ate", function()
			-- ROUND 1, BLOCKING FINDING 2. `Style.card` ends with a `UIPadding` of `Style.cardInset`
			-- all round, so a board of height H has a CONTENT box of H - 24. `Hud.boardHeight`
			-- returned the content height as the WHOLE height, and the footer -- anchored to the
			-- bottom of that content box -- was drawn 24 px up, with its 28 px countdown number
			-- across the last row of the table.
			local Style = Hud.Style
			local viewX = Hud.viewportX()
			local inset = Style.cardInset(viewX)
			expect(inset).to.equal(12)
			-- THE HEIGHT COUNTS THE PADDING, and the content box is what the bands are laid out in.
			expect(Hud.boardHeight(2, 2, viewX) - Hud.boardContentHeight(2, 2, viewX)).to.equal(2 * inset)
			expect(Hud.boardContentHeight(2, 2, viewX)).to.equal(
				Hud.BOARD.HEADER_H + Style.rowHeight(viewX) + 2 * Style.rowHeight(viewX) + 2 * 20 + Hud.BOARD.FOOTER_H
			)

			-- ...AND ON THE SCREEN: the footer's top really is below the last drawn row's bottom.
			Hud.renderScore(scoring(), 12)
			local board = Hud.scorePanel() :: Frame
			local body = Hud.scoreBody() :: ScrollingFrame
			local foot = board:FindFirstChild("Footer") :: Frame
			expect(foot).to.be.ok()
			task.wait()
			local bodyBottom = body.AbsolutePosition.Y + body.AbsoluteSize.Y
			local footTop = foot.AbsolutePosition.Y
			expect(footTop >= bodyBottom).to.equal(true)
			TestKit.note(string.format("match_client: body ends %d, footer starts %d", bodyBottom, footTop))

			-- THE TABLE IS CENTRED IN THE CARD'S PADDING (round 1 note): `Hud.BOARD.PADDING` was 16
			-- against the card's own 12, so the whole table sat 8 px left of centre.
			expect(Hud.BOARD.PADDING).to.equal(inset)
			expect(Hud.BOARD.WIDTH - 2 * Hud.BOARD.PADDING).to.equal(Hud.BOARD.WIDTH - 2 * inset)
		end)

		it("answers the footer's DRAWN word, not the constant it was supposed to match", function()
			-- ROUND 1 NOTE: `Hud.scoreFooterText` read the label, stripped its letter-spacing and
			-- then threw it away for `Drive.CONFIG.SCORE_FOOTER_WORD` -- so the one case that
			-- asserts this line would have passed with ANY word on screen. A seam that cannot fail.
			Hud.renderScore(scoring(), 12)
			expect(Hud.scoreFooterText()).to.equal("NEXT DRIVE IN 12")
			local board = Hud.scorePanel() :: Frame
			local word = (board:FindFirstChild("Footer") :: Frame):FindFirstChild("Word") :: TextLabel
			expect(word).to.be.ok()
			local was = word.Text
			word.Text = Hud.Style.spaced("SOMETHING ELSE")
			expect(Hud.scoreFooterText()).to.equal("SOMETHING ELSE 12")
			word.Text = was
			expect(Hud.scoreFooterText()).to.equal("NEXT DRIVE IN 12")
		end)

		-- THE FIRST-PLACE BADGE (task 160, and since task 170 the rule lives in `Drive.Rank`). Karen,
		-- 2026-10-11: *"first place ofc more"*. The rule is pure, so every case below is a table rather
		-- than a rendered frame -- and the two cases that matter are the ones where the badge must NOT
		-- appear, because a wrong badge names a winner who did not win.
		--
		-- IT IS ASSERTED THROUGH `Drive.Rank` ON PURPOSE (task 170): the SERVER pays the bonus off this
		-- same function (`Economy.Coins.forDrive`), so a badge and a bonus cannot land on different
		-- rows. `Hud.firstPlaceRank` is gone, and the last case here says so.
		it("marks the leader 1st, and marks nobody when the top two are level", function()
			local function board(first: number, second: number?)
				local rows = { { userId = 1, name = "one", team = "Shooters", points = first, kills = 1 } }
				if second ~= nil then
					table.insert(rows, { userId = 2, name = "two", team = "Drivers", points = second, kills = 0 })
				end
				return rows
			end
			local Rank = Drive.Rank
			expect(Rank.firstPlaceRank(board(16, 3))).to.equal(1)
			expect(Rank.firstPlaceRank(board(16))).to.equal(1) -- alone, but he shot something
			-- A TIE AT THE TOP IS NOT A FIRST PLACE, it is a tie: ioquake3's `RANK_TIED_FLAG`
			-- (docs/research/2026-10-12-scoring.md section 2.1).
			expect(Rank.firstPlaceRank(board(16, 16))).to.equal(nil)
			-- NOBODY HAS SCORED YET, which is every board for the first minute of every drive. The
			-- order there is `Score.leaderboard`'s last tiebreak -- userId -- so a badge would crown
			-- whoever joined the server first.
			expect(Rank.firstPlaceRank(board(0, 0))).to.equal(nil)
			expect(Rank.firstPlaceRank(board(0))).to.equal(nil)
			expect(Rank.firstPlaceRank({})).to.equal(nil)
			expect(Rank.firstPlaceRank(nil)).to.equal(nil)
			-- ...and a board everybody is penalised on still has a leader: -10 beats -20.
			expect(Rank.firstPlaceRank(board(-10, -20))).to.equal(1)
			-- AND SO DOES A LEADER ON 0 OVER A SECOND ON -10 (round 1, note 2). The zero test used
			-- to be asked of the leader's own points, so these two boards -- a man clear at the top
			-- of each -- disagreed with each other. It is now asked only of the row with nobody
			-- behind it, which is the board it was always for: the one where nothing has happened.
			expect(Rank.firstPlaceRank(board(0, -10))).to.equal(1)
			-- THE OLD NAME IS GONE, not kept as an alias: an alias is two names for one rule, which is
			-- the thing task 170 removed (backups/2026-10-13_task-170_hud-firstplacerank.txt).
			expect((Hud :: any).firstPlaceRank).to.equal(nil)
		end)

		-- TWO RANKINGS, TWO FIRST PLACES (task 170). Karen, 2026-10-12: separate rankings for hunters
		-- and beaters. `Hud.scorePanelLines` is pure, so the whole body of the panel is a table here.
		it("splits the board into hunters and beaters, each with its own 1st", function()
			local rows = {
				{ userId = 1, name = "h-top", team = "Shooters", points = 20, kills = 2, earned = 75 },
				{ userId = 2, name = "b-top", team = "Drivers", points = 9, kills = 0, earned = 53 },
				{ userId = 3, name = "h-two", team = "Shooters", points = 6, kills = 1, earned = 22 },
				{ userId = 4, name = "b-two", team = "Drivers", points = 3, kills = 0, earned = 16 },
			}
			local lines = Hud.scorePanelLines({ rows = rows }, 3)
			expect(#lines).to.equal(6)
			expect(lines[1].text).to.equal(Drive.CONFIG.SCORE_HUNTERS_HEADING)
			expect(lines[1].heading).to.equal(true)
			expect(lines[4].text).to.equal(Drive.CONFIG.SCORE_BEATERS_HEADING)
			-- THE RANK RESTARTS AT 1 INSIDE EACH RANKING, which is what "two first places" means.
			expect(string.sub(lines[2].text, 1, 1)).to.equal("1")
			expect(string.sub(lines[3].text, 1, 1)).to.equal("2")
			expect(string.sub(lines[5].text, 1, 1)).to.equal("1")
			expect(string.sub(lines[6].text, 1, 1)).to.equal("2")
			-- A BADGE ON THE TOP OF EACH, and on nobody else -- so the beater on 9 wears one even though
			-- three hunters-and-beaters scored more than him on the single board this replaced.
			local badge = Drive.CONFIG.SCORE_FIRST_BADGE
			expect(string.find(lines[2].text, badge, 1, true) ~= nil).to.equal(true)
			expect(string.find(lines[5].text, badge, 1, true) ~= nil).to.equal(true)
			expect(string.find(lines[3].text, badge, 1, true)).to.equal(nil)
			expect(string.find(lines[6].text, badge, 1, true)).to.equal(nil)
			-- MY ROW IS MINE, whichever ranking it is in.
			expect(lines[3].mine).to.equal(true)
			expect(lines[2].mine).to.equal(false)
			TestKit.note("match_client: two rankings -- " .. lines[2].text .. " | " .. lines[5].text)
		end)

		it("gives a ranking with a tie at the top no 1st at all, and leaves the other one alone", function()
			local rows = {
				{ userId = 1, name = "h-one", team = "Shooters", points = 12, kills = 1, earned = 34 },
				{ userId = 2, name = "h-two", team = "Shooters", points = 12, kills = 1, earned = 34 },
				{ userId = 3, name = "b-one", team = "Drivers", points = 6, kills = 0, earned = 47 },
			}
			local lines = Hud.scorePanelLines({ rows = rows }, nil)
			local badge = Drive.CONFIG.SCORE_FIRST_BADGE
			expect(string.find(lines[2].text, badge, 1, true)).to.equal(nil)
			expect(string.find(lines[3].text, badge, 1, true)).to.equal(nil)
			-- The beaters are alone and one of them has scored, so he IS first of his ranking.
			expect(string.find(lines[5].text, badge, 1, true) ~= nil).to.equal(true)
		end)

		-- A HEADING IS DRAWN ONLY WHEN THERE IS A ROW UNDER IT, which is `Match.quarryLines`' own rule
		-- for its POINTS label. A player who joined outside `Assigning`/`Running` has no team yet, and
		-- that is a real state: he goes under OTHERS, and OTHERS has no first place because it is not a
		-- ranking.
		it("names only the rankings that have somebody in them, and never ranks OTHERS", function()
			expect(#Hud.scorePanelLines({ rows = {} }, nil)).to.equal(0)
			expect(#Hud.scorePanelLines(nil, nil)).to.equal(0)
			local beatersOnly = Hud.scorePanelLines({
				rows = { { userId = 1, name = "b", team = "Drivers", points = 3, kills = 0, earned = 16 } },
			}, nil)
			expect(#beatersOnly).to.equal(2)
			expect(beatersOnly[1].text).to.equal(Drive.CONFIG.SCORE_BEATERS_HEADING)
			local noTeam = Hud.scorePanelLines({
				rows = { { userId = 1, name = "x", points = 12, kills = 1, earned = 34 } },
			}, nil)
			expect(#noTeam).to.equal(2)
			expect(noTeam[1].text).to.equal(Drive.CONFIG.SCORE_OTHERS_HEADING)
			expect(string.find(noTeam[2].text, Drive.CONFIG.SCORE_FIRST_BADGE, 1, true)).to.equal(nil)
		end)

		-- EVERY LINE FITS, AND NO HEADING IS EVER DROPPED (task 170). Three headings plus
		-- `MAX_PLAYERS` rows is 19, and `SCORE_ROWS_MAX` is 20 -- but the budget has to hold even when
		-- the wire sends more rows than it should, and the thing that must survive the cut is the
		-- heading: a list cut short still reads, a list whose heading went tells the reader the wrong
		-- ranking.
		it("truncates by dropping trailing rows and never a heading", function()
			local rows = {}
			for userId = 1, 40 do
				table.insert(rows, {
					userId = userId,
					name = "p" .. userId,
					team = if userId % 2 == 0 then "Drivers" else "Shooters",
					points = 40 - userId,
					kills = 0,
					earned = 10,
				})
			end
			local lines = Hud.scorePanelLines({ rows = rows }, nil)
			expect(#lines).to.equal(Drive.CONFIG.SCORE_ROWS_MAX)
			expect(lines[1].text).to.equal(Drive.CONFIG.SCORE_HUNTERS_HEADING)
			-- ...and the panel really has that many slots to put them in.
			expect(#Hud.scoreRowText() <= Drive.CONFIG.SCORE_ROWS_MAX).to.equal(true)
		end)

		-- THE BALANCE, ON THE BAR, IN EVERY PHASE (task 170). Karen, 2026-10-11: *"get money"*.
		it("puts the local player's balance on the drive bar, and `--` when it is unknown", function()
			local label = Drive.CONFIG.SCORE_COINS_LABEL
			expect(Hud.coinsText(scoring(), player.UserId)).to.equal(label .. " 1240")
			-- SOMEBODY ELSE'S ROW IS NOT MINE.
			expect(Hud.coinsText(scoring(), player.UserId + 1)).to.equal(label .. " 141")
			-- A ROW WITH NO BALANCE IN A BUILD THAT HAS MONEY READS `--`, NEVER `0`: his profile did not
			-- open, and 0 would be the screen asserting he has no coins.
			local unknown = {
				coinsOn = true,
				rows = { { userId = 7, name = "x", team = "Shooters", points = 0, kills = 0 } },
			}
			expect(Hud.coinsText(unknown, 7)).to.equal(label .. " " .. Drive.CONFIG.SCORE_COINS_UNKNOWN)
			-- ...and a row that is not his draws nothing even then.
			expect(Hud.coinsText(unknown, 9)).to.equal("")
			expect(Hud.coinsText({ coinsOn = true, rows = {} }, 7)).to.equal("")
			expect(Hud.coinsText(nil, 7)).to.equal("")
			expect(Hud.coinsText(scoring(), nil)).to.equal("")
		end)

		-- THE FLAG-OFF STATE, WHICH ROUND 1 OF THE GATE FOUND WAS NOT THE GAME BEFORE TASK 170 AT ALL.
		-- The claim was that `Hud.coinsText` answered `""` with the flag off because the player "has no
		-- row"; he always has one (`Match.snapshot` builds one per `Score.leaderboard` entry), so every
		-- bar in the game gained a dead `COINS --`. These two cases FAIL on that code.
		--
		-- THE TWO ABSENCES ARE DIFFERENT QUESTIONS and the rows cannot tell them apart -- `coins` is
		-- missing both when there is no money and when a profile did not open -- so the answer rides on
		-- the snapshot as `coinsOn`, from the server, and this side reads no flag of its own.
		it("draws NO balance at all when the build has no money in it", function()
			local offBoard = {
				rows = {
					{ userId = player.UserId, name = player.Name, team = "Shooters", points = 16, kills = 2 },
				},
			}
			expect(Hud.coinsText(offBoard, player.UserId)).to.equal("")
			-- EXPLICITLY false, not merely absent: a server that says "no" is the same as one that has
			-- never heard of the field, which is every build before task 170.
			local said = table.clone(offBoard)
			said.coinsOn = false
			expect(Hud.coinsText(said, player.UserId)).to.equal("")
			-- ...and a row that DOES carry a balance is still not drawn without `coinsOn`, because the
			-- server is the one source for whether money exists.
			local stray = {
				rows = {
					{
						userId = player.UserId,
						name = player.Name,
						team = "Shooters",
						points = 0,
						kills = 0,
						coins = 99,
					},
				},
			}
			expect(Hud.coinsText(stray, player.UserId)).to.equal("")
		end)

		-- ...AND ON THE REAL BAR, FROM THE REAL WIRE. `COINS` is born off, so the live snapshot in this
		-- run is the flag-off state itself -- this player HAS a row on it, which is exactly the
		-- condition that produced the dead `COINS --`. It is the one assertion here that needs no
		-- fixture at all, and it fails on the code round 1 reviewed.
		it("leaves no coins piece on the live drive bar while the economy is off", function()
			local snapshot = Match.get()
			expect(snapshot).to.be.ok()
			local mine = nil
			for _, scoreRow in ipairs(snapshot.rows) do
				if scoreRow.userId == player.UserId then
					mine = scoreRow
				end
			end
			-- The precondition is stated rather than assumed: without a row for me the case would pass
			-- for the wrong reason, which is how the claim it replaces came to be believed.
			expect(mine).to.be.ok()
			expect(snapshot.coinsOn).to.equal(nil)
			expect(mine.coins).to.equal(nil)
			local bar = Hud.driveBarText()
			print("[match_client] flag-off drive bar: " .. bar)
			expect(string.find(bar, Drive.CONFIG.SCORE_COINS_LABEL, 1, true)).to.equal(nil)
			expect(string.find(bar, Drive.CONFIG.SCORE_COINS_UNKNOWN, 1, true)).to.equal(nil)
			TestKit.note("match_client: COINS off -> the bar reads '" .. bar .. "'")
		end)

		-- A LEAVER IS NOT PAID (`Economy.Coins.forDrive` skips `row.left`), so his row carries no
		-- `earned` and the column says so with the same `--` an unknown balance uses. His row still
		-- SHOWS, which is `Score.leave`'s own decision.
		it("draws NO coins cell for a row the drive did not pay, and says LEFT instead", function()
			local rows = {
				{ userId = 1, name = "gone", team = "Shooters", points = 16, kills = 2, left = true },
			}
			local lines = Hud.scorePanelLines({ rows = rows }, nil)
			expect(#lines).to.equal(2)
			-- AN UNKNOWN IS NOT DRAWN AT ALL RATHER THAN `--` (the design system section 3.12), and
			-- the `LEFT` TAG beside the row is what says why he was not paid -- a `--` in the coins
			-- column was the same fact said twice and badly.
			expect((lines[2].cells :: any).coins).to.equal("")
			expect(string.find(lines[2].text, Drive.CONFIG.SCORE_COINS_UNKNOWN, 1, true)).to.equal(nil)
			expect(lines[2].left).to.equal(true)
			expect(string.find(lines[2].text, "LEFT", 1, true) ~= nil).to.equal(true)
		end)

		it("puts the badge on the drawn row, on the leader's row only", function()
			Hud.renderScore(scoring(), 12)
			local rows = Hud.scoreRowText()
			print("[match_client] badged row: " .. (rows[2] or "<none>"))
			local badge = Drive.CONFIG.SCORE_FIRST_BADGE
			-- EACH RANKING'S TOP ROW WEARS IT (task 170): row 2 under the hunters' heading, row 4 under
			-- the beaters'. The headings themselves never do.
			expect(string.find(rows[2], badge, 1, true) ~= nil).to.equal(true)
			expect(string.find(rows[4], badge, 1, true) ~= nil).to.equal(true)
			expect(string.find(rows[1], badge, 1, true) == nil).to.equal(true)
			-- AFTER THE POINTS AND THE COINS, not before them: the badge belongs against the numbers it
			-- was earned with, and a reader scanning those columns must not find a word in one.
			expect(string.find(rows[2], badge, 1, true) > (string.find(rows[2], "16", 1, true) :: number)).to.equal(
				true
			)
			expect(string.find(rows[2], badge, 1, true) > (string.find(rows[2], "+67", 1, true) :: number)).to.equal(
				true
			)
			TestKit.note("match_client: first place -> " .. rows[2])
		end)

		it("clears the board when the next drive starts, so nothing stale flashes", function()
			Hud.renderScore(scoring(), 12)
			expect(#Hud.scoreRowText()).to.equal(4)
			Hud.renderScore(LIVE, 500)
			expect(#Hud.scoreRowText()).to.equal(0)
			expect(Hud.isScorePanelVisible()).to.equal(false)
		end)
	end)

	-- THE START CARD (task 158). Karen: *"we just need to at the begining what they can shoot and
	-- timer when start"*, *"Simple, readable, a few seconds, no tutorial"*.
	--
	-- SCRIPTED SNAPSHOTS, FOR THE SCORE PANEL'S OWN REASON: the card is up for the ten seconds of
	-- `Assigning` and a one-player harness run reaches the specs well inside the drive, so the wire
	-- will not show it here. `Hud.renderStartCard` is public for exactly this. The screenshot is
	-- separate evidence and this does not replace it.
	describe("the start card", function()
		-- THE SERVER'S ROWS, AS THE SERVER NOW SENDS THEM (201 part 3): one entry per kind with what
		-- that kind is worth, off `Match.CONFIG.POINTS.KIND`, plus what shooting a PERSON costs. The
		-- Hud decides nothing about any of it -- which is what the last cases here check.
		local CARD_QUARRY = {
			{ species = "WILD BOAR", kind = "male", points = 10 },
			{ species = "WILD BOAR", kind = "female", points = 6 },
			{ species = "WILD BOAR", kind = "cub", points = -10 },
		}
		local CARD_SAFETY = -10

		local function snapshotIn(phase: string)
			local snapshot = {
				phase = phase,
				phaseEndsAt = 0,
				driveNumber = 4,
				boarsReleased = 0,
				boarsLeft = 6,
				waitingFor = {},
				quarry = CARD_QUARRY,
				safetyPenalty = CARD_SAFETY,
				rows = {},
				tied = {},
			}
			return Drive.deepFreeze(snapshot)
		end

		-- The two phases these cases need by name: the countdown, and the drive that follows it.
		local function starting()
			return snapshotIn("Assigning")
		end

		local function running()
			return snapshotIn("Running")
		end

		local reportWasOpen = false

		beforeAll(function()
			-- The same precondition the score cases state: a report left open hides this card too,
			-- and both panels hide behind it on purpose.
			reportWasOpen = Hud.Report.isOpen()
			if reportWasOpen then
				TestKit.note("match_client: a drive report was open; closed for the start-card cases")
				Hud.Report.setOpen(false)
			end
		end)

		afterAll(function()
			if reportWasOpen then
				Hud.Report.setOpen(true)
			end
			Hud.renderStartCard(Match.get(), Match.myTeam(), Match.secondsLeft())
		end)

		it("is hidden while the drive is running, and gone the moment it starts", function()
			Hud.renderStartCard(starting(), "Shooters", 7)
			expect(Hud.isStartCardVisible()).to.equal(true)
			Hud.renderStartCard(running(), "Shooters", 300)
			expect(Hud.isStartCardVisible()).to.equal(false)
			-- Cleared, not just hidden: the next drive must not flash the last one's card.
			expect(#Hud.startCardText()).to.equal(0)
			expect(Hud.startCardTimerText()).to.equal("")
			expect(Hud.startCardRoleText()).to.equal("")
			expect(Hud.startCardSectionText()).to.equal("")
		end)

		it("is really on screen in Assigning: every ancestor present and visible", function()
			Hud.renderStartCard(starting(), "Shooters", 9)
			expect(Hud.isStartCardVisible()).to.equal(true)
			local card = Hud.startCard()
			expect(card).to.be.ok()
			-- The ancestor walk, not just `Visible`: "a visibility audit ignored parent visibility and
			-- certified a blank screen twice" (docs/PROJECT_CONTEXT.md).
			local node: Instance? = card
			while node and node ~= game do
				if node:IsA("GuiObject") then
					expect(node.Visible).to.equal(true)
				elseif node:IsA("ScreenGui") then
					expect(node.Enabled).to.equal(true)
				end
				node = node.Parent
			end
			expect(node).to.equal(game)
			expect(card.BackgroundTransparency < 1).to.equal(true)
		end)

		-- THE OTHER HALF OF TASK 159'S CASE, AND THE OPPOSITE OF ITS SECOND HALF. 159 asserted that
		-- every label was in front of the card AND wore a black `UIStroke`; the design system's
		-- section 2 retires the stroke and the monospace with it, and fault 5 of the start-card spec
		-- is that helper by name. So: still in front, and now with NO outline and NO `Enum.Font.Code`
		-- anywhere in the card -- the surface is what makes the words readable.
		it("draws every word in front of the card, with no black outline and no monospace", function()
			Hud.renderStartCard(starting(), "Shooters", 7)
			local card = Hud.startCard()
			expect(card).to.be.ok()
			local checked = 0
			for _, node in ipairs(card:GetDescendants()) do
				if node:IsA("TextLabel") then
					checked += 1
					expect(node.ZIndex > card.ZIndex).to.equal(true)
					expect(node.TextTransparency < 0.5).to.equal(true)
					expect(node:FindFirstChildOfClass("UIStroke")).to.equal(nil)
					-- A `FontFace` FROM THE SCALE, AND NEVER THE MONOSPACE. Setting `FontFace` makes
					-- `Font` report the matching enum (`BuilderSansBold`, `Oswald`), so the claim is
					-- stated as the one thing that must not be true rather than as one that may.
					expect(node.Font).never.to.equal(Enum.Font.Code)
					expect(node.TextScaled).to.equal(false)
				end
			end
			-- The eyebrow, the role, the section word, the countdown's two, and four rows x (text,
			-- value, word, tag text): more than a dozen labels, and the number is not the claim --
			-- that every one of them passes is.
			expect(checked > 10).to.equal(true)
			TestKit.note(string.format("match_client: start card labels checked = %d", checked))
		end)

		it("tells a HUNTER his role, what to shoot with its price, and how long he has", function()
			Hud.renderStartCard(starting(), "Shooters", 10)
			local rows = Hud.startCardRowText()
			local drawn = {}
			for _, row in ipairs(rows) do
				table.insert(drawn, string.format("%s %s %s", row.glyph, row.text, row.value))
			end
			print(
				"[match_client] start card (hunter): "
					.. Hud.startCardTitleText()
					.. " / "
					.. Hud.startCardRoleText()
					.. " / "
					.. Hud.startCardSectionText()
					.. " / "
					.. table.concat(drawn, " | ")
					.. " / "
					.. Hud.startCardTimerText()
			)
			expect(Hud.startCardRoleText()).to.equal("YOU ARE A HUNTER")
			expect(string.find(Hud.startCardTitleText(), "DRIVE 4", 1, true) ~= nil).to.equal(true)
			expect(Hud.startCardSectionText()).to.equal("WHAT TO SHOOT")
			-- FOUR ROWS, ONE IDEA EACH, and the price is the SERVER's number with its own sign.
			expect(#rows).to.equal(4)
			expect(rows[1].glyph).to.equal("tick")
			expect(rows[1].text).to.equal("Male boar")
			expect(rows[1].value).to.equal("+10")
			expect(rows[2].glyph).to.equal("tick")
			expect(rows[2].text).to.equal("Female boar")
			expect(rows[2].value).to.equal("+6")
			-- A CROSS AND A NEGATIVE, which is the spec's rule 3: the glyph is the first reading.
			expect(rows[3].glyph).to.equal("cross")
			expect(rows[3].text).to.equal("Piglet - leave them")
			expect(rows[3].value).to.equal("-10")
			-- THE ROW THE DESIGNER ADDED, priced off the wire and not off a number typed here.
			expect(rows[4].glyph).to.equal("cross")
			expect(rows[4].text).to.equal("A person")
			expect(rows[4].value).to.equal("-10")
			expect(Hud.startCardTimerText()).to.equal("GET TO YOUR STAND  10")
		end)

		-- THE FOURTH FAULT, FIXED: *"The beater gets the hunter's card... a man who may not shoot at
		-- all is handed a price list of things to shoot, and is told nothing about the horn, the
		-- push, or the line he must not cross."*
		it("tells a BEATER his job instead of the hunter's price list", function()
			Hud.renderStartCard(starting(), "Drivers", 3)
			local rows = Hud.startCardRowText()
			local drawn = {}
			for _, row in ipairs(rows) do
				table.insert(drawn, string.format("%s %s %s", row.glyph, row.text, row.value))
			end
			print(
				"[match_client] start card (beater): "
					.. Hud.startCardRoleText()
					.. " / "
					.. Hud.startCardSectionText()
					.. " / "
					.. table.concat(drawn, " | ")
					.. " / "
					.. Hud.startCardTimerText()
			)
			expect(Hud.startCardRoleText()).to.equal("YOU ARE A BEATER")
			expect(Hud.startCardSectionText()).to.equal("WHAT TO DO")
			expect(#rows).to.equal(4)
			expect(rows[1].glyph).to.equal("cross")
			expect(rows[1].text).to.equal("You do not shoot")
			expect(rows[1].value).to.equal("NEEDS LICENCE")
			expect(rows[2].glyph).to.equal("chevron")
			expect(rows[2].text).to.equal("Push the boars to the hunters")
			expect(rows[2].value).to.equal("")
			expect(rows[3].glyph).to.equal("horn")
			expect(rows[3].text).to.equal("Click your horn as you walk")
			expect(rows[4].glyph).to.equal("cross")
			expect(rows[4].text).to.equal("Do not cross their line")
			expect(rows[4].value).to.equal("DRIVE OVER")
			-- NOT ONE OF THE HUNTER'S PRICES IS ON HIS CARD. He is told about the boars -- pushing
			-- them is his job -- and he is told nothing about what one is WORTH, which is the fourth
			-- fault: *"a man who may not shoot at all is handed a price list of things to shoot"*.
			for _, row in ipairs(rows) do
				expect(string.find(row.value, "%+%d")).to.equal(nil)
				expect(string.find(row.value, "%-%d")).to.equal(nil)
			end
			-- BOTH LAST LINES ARE INSTRUCTIONS NOW, and it is the same deadline either way.
			expect(Hud.startCardTimerText()).to.equal("WAIT FOR THE HORN  3")
		end)

		-- THE SECOND FAULT, FIXED, AND RULE 4: *"`cub` is never printed. The player-facing word is
		-- `piglet`, in one place, shared with the hit card and the report."*
		it("never prints the word cub, on either card", function()
			for _, team in ipairs({ "Shooters", "Drivers" }) do
				Hud.renderStartCard(starting(), team, 8)
				for _, row in ipairs(Hud.startCardRowText()) do
					expect(string.find(string.lower(row.text), "cub", 1, true)).to.equal(nil)
				end
			end
			-- ONE PLACE, and the hit card and the report read the same function.
			expect(Report.kindWord("cub")).to.equal("piglet")
			expect(Report.kindWord("male")).to.equal("male")
			expect(Report.kindWord(nil)).to.equal("")
		end)

		it("rounds the countdown UP, so a player never reads 0 while he still has time", function()
			-- `secondsLeft` is a float counted down locally from the server's timestamp; 9.2 seconds
			-- left is "10" and 0.4 is "1", because the card is a countdown and not a stopwatch.
			expect(Hud.startCardTimerFor("Shooters", 9.2)).to.equal("GET TO YOUR STAND  10")
			expect(Hud.startCardTimerFor("Shooters", 0.4)).to.equal("GET TO YOUR STAND  1")
			expect(Hud.startCardTimerFor("Shooters", 0)).to.equal("GET TO YOUR STAND  0")
			expect(Hud.startCardTimerFor("Drivers", -5)).to.equal("WAIT FOR THE HORN  0") -- never negative
			expect(Hud.startCardSecondsFor(nil)).to.equal(0)
		end)

		-- THE BAR IS FULL ON THE FRAME THE CARD APPEARS, whatever the phase's length is. The client
		-- is never told `Match.CONFIG.INTERMISSION_SECONDS` (15 today, 20 and 10 before), so the
		-- largest `secondsLeft` seen is the length and a typed 10 would draw a two-thirds bar.
		it("fills the countdown bar against the phase it actually saw, not a constant", function()
			expect(Hud.startCardBarScale(15, 15)).to.be.near(1, 1e-6)
			expect(Hud.startCardBarScale(15, 0)).to.be.near(1, 1e-6) -- the first frame: nothing latched yet
			expect(Hud.startCardBarScale(7.5, 15)).to.be.near(0.5, 1e-6)
			expect(Hud.startCardBarScale(0, 15)).to.be.near(0, 1e-6)
			expect(Hud.startCardBarScale(-3, 15)).to.be.near(0, 1e-6)
			expect(Hud.startCardBarScale(0, 0)).to.be.near(0, 1e-6)
		end)

		it("shows nothing at all with no drive, and no role line for a player on no team", function()
			Hud.renderStartCard(nil, nil, 0)
			expect(Hud.isStartCardVisible()).to.equal(false)
			-- The rows are pure, so the no-team case is one assertion: the quarry still reads,
			-- because what may be shot does not depend on which side you are on. A player with no
			-- team is given no ROLE line rather than "YOU ARE A ".
			local rows = Hud.startCardRows(starting(), nil, false)
			expect(#rows).to.equal(4)
			expect(rows[1].text).to.equal("Male boar")
			expect(Hud.roleWord(nil)).to.equal("")
			expect(Hud.roleWord("Shooters")).to.equal("HUNTER")
			expect(Hud.roleWord("Drivers")).to.equal("BEATER")
			Hud.renderStartCard(starting(), nil, 5)
			expect(Hud.startCardRoleText()).to.equal("")
		end)

		-- THE ROWS ARE THE WIRE'S, AND A KIND WITH NO PRICE DRAWS NO NUMBER rather than a wrong one
		-- -- the retired `QUARRY_NOTE`'s own rule, kept.
		it("draws a kind the server priced with no number, and keeps the row", function()
			local rows = Hud.startCardRows({
				phase = "Assigning",
				driveNumber = 1,
				quarry = { { species = "RED DEER", kind = "stag" } },
			}, "Shooters", false)
			expect(#rows).to.equal(1)
			expect(rows[1].value).to.equal(nil)
			expect(rows[1].glyph).to.equal("cross") -- unpriced is not "may shoot"
			expect(rows[1].text).to.equal("Stag")
			-- AND NO PERSON ROW WITHOUT THE SERVER'S NUMBER: a -10 typed on this side would be a
			-- second copy of a penalty.
			for _, row in ipairs(rows) do
				expect(row.text).never.to.equal("A person")
			end
		end)

		-- THE PHONE DROPS THE BEATER'S TWO RIGHT-HAND CELLS, and only his (the spec's amendment 2
		-- and rule 2): at 264 wide the row text wins the width, the same way the status bar drops a
		-- whole chip rather than squeezing one.
		it("drops the beater's right-hand cells at the phone step and keeps his words", function()
			local wide = Hud.startCardRows(starting(), "Drivers", false)
			local narrow = Hud.startCardRows(starting(), "Drivers", true)
			expect(wide[1].tag).to.equal("NEEDS LICENCE")
			expect(wide[4].word).to.equal("DRIVE OVER")
			expect(narrow[1].tag).to.equal(nil)
			expect(narrow[4].word).to.equal(nil)
			expect(#narrow).to.equal(#wide)
			for index, row in ipairs(narrow) do
				expect(row.text).to.equal(wide[index].text)
				expect(row.glyph).to.equal(wide[index].glyph)
			end
			-- ...AND THE TEXT CELL TAKES THE SLACK THE DROPPED CELL LEAVES.
			local phoneContent = Hud.startCardContentWidth(400)
			expect(Hud.startCardTextWidth(400, 0) > Hud.startCardTextWidth(400, 34)).to.equal(true)
			expect(Hud.startCardTextWidth(400, 0) < phoneContent).to.equal(true)
		end)

		it("is only ever the start of a drive: no other phase shows it", function()
			for _, phase in ipairs({ "Waiting", "Running", "Scoring" }) do
				expect(Hud.startCardVisible(snapshotIn(phase), false)).to.equal(false)
			end
			expect(Hud.startCardVisible(starting(), false)).to.equal(true)
			-- ...and not while the report is open: two panels at once is two panels nobody reads.
			expect(Hud.startCardVisible(starting(), true)).to.equal(false)
		end)

		it("carries what the SERVER said may be shot, with no second copy on this side", function()
			-- The snapshot really has the field (the live wire's own case is in match_live.spec), and
			-- `Drive.CONFIG` holds the WORDING of the card but no rule: a client that knew which
			-- animals were legal would be a second answer to one rule.
			expect(waitUntil(30, function()
				return Match.get() ~= nil
			end)).to.equal(true)
			local snapshot = Match.get()
			expect(type(snapshot.quarry)).to.equal("table")
			expect(#snapshot.quarry > 0).to.equal(true)
			local drawn = {}
			for _, row in ipairs(snapshot.quarry) do
				expect(type(row)).to.equal("table") -- ROWS, not a formatted sentence
				expect(type(row.kind)).to.equal("string")
				table.insert(drawn, string.format("%s=%s", row.kind, tostring(row.points)))
			end
			print(
				"[match_client] the wire's quarry: "
					.. table.concat(drawn, " | ")
					.. " / person "
					.. tostring(snapshot.safetyPenalty)
			)
			expect(type(snapshot.safetyPenalty)).to.equal("number")
			-- NO RULE ON THIS SIDE: the config holds the card's words and both its layouts, and not
			-- one fact about what is legal or what it is worth.
			for _, field in ipairs({ "QUARRY", "QUARRY_NOTE", "START_HOLD_TEAM", "POINTS" }) do
				expect((Drive.CONFIG :: any)[field]).to.equal(nil)
			end
			for _, word in pairs(Drive.CONFIG.START_CARD_QUARRY_WORDS) do
				expect(string.find(word, "%d")).to.equal(nil) -- no price is typed into the copy
			end
		end)
	end)

	describe("the tied banner", function()
		afterAll(function()
			Hud.renderTied(Match.isTied())
		end)

		it("is hidden while nobody has broken the rule", function()
			Hud.renderTied(false)
			expect(Hud.isTiedBannerVisible()).to.equal(false)
			expect(Hud.tiedBannerText()).to.equal("")
		end)

		it("says what you did, on screen, when it is you", function()
			Hud.renderTied(true)
			expect(Hud.isTiedBannerVisible()).to.equal(true)
			local text = Hud.tiedBannerText()
			print("[match_client] tied banner: " .. text)
			expect(string.find(text, "TIED TO A TREE", 1, true) ~= nil).to.equal(true)
			-- ASCII only, like everything else drawn in this repo.
			expect(string.match(text, "^[%w%s%p]+$") ~= nil).to.equal(true)

			local banner = Hud.tiedBanner()
			local node: Instance? = banner
			while node and node ~= game do
				if node:IsA("GuiObject") then
					expect(node.Visible).to.equal(true)
				elseif node:IsA("ScreenGui") then
					expect(node.Enabled).to.equal(true)
				end
				node = node.Parent
			end
			expect(node).to.equal(game)
		end)
	end)
	-- TASK 163, REDONE IN 166. KAREN, 2026-10-12: *"when hunt starts 3 longer horn calls and when ends
	-- the same"*, and then, having heard it: *"for start and end of drive has to be tuturutu tu tu
	-- different one"*. So the cue is a BUGLE FANFARE now, one phrase per cue out of its own asset.
	-- The server's half is `match_phase.spec` (one entry at GO, one at the end) and the DATA's half is
	-- `zz_horn.spec` (the two cuts, measured). This is the client's half: the entry draws no line,
	-- the sound owner has a loaded voice for EACH cue before the first one, and it sounds once.
	describe("the drive's horn signal", function()
		it("draws NO feed line, so the feed never prints the bare word", function()
			-- `Hud.feedTextFor` is the one place that decides what a feed entry reads as, and a
			-- `signal` entry's text is the server's word ("start" / "end"), not something to read.
			expect(Hud.feedTextFor({ kind = "signal", text = "start", at = 0 })).to.equal(nil)
			expect(Hud.feedTextFor({ kind = "signal", text = "end", at = 0 })).to.equal(nil)
			-- ...while the phase line beside it is still a line, so the feed did not go quiet.
			expect(Hud.feedTextFor({ kind = "phase", text = "Drive on", at = 0 })).to.equal("Drive on")
		end)

		-- TASK 163a(a), THE REVIEWER'S FIRST NOTE AND THE ONE WITH A CONSEQUENCE KAREN WOULD HEAR.
		-- The voice used to be created at the first cue, so the download started when the drive did
		-- and the only budget against it was a 2 s wait -- and `TimePosition` on an unloaded Sound is
		-- not kept, so a lost race plays the clip from 0. With task 166's bugle calls that is the
		-- asset's own lead-in silence followed by half a phrase. There is now ONE VOICE PER CUE and
		-- both are made and preloaded at module load; this case is what says so.
		it("has a Sound per cue, made and configured BEFORE the first cue, and preloaded", function()
			-- A FACT ABOUT LOAD TIME, not about now: once a drive has signalled, "they existed
			-- before the cue" cannot be read off the Instances, so the module records it.
			local made = (Sound.signalReady())
			expect(made).to.equal(true)
			-- The preload is a thread, so it is waited for rather than asserted on sight.
			expect(waitUntil(20, function()
				local _, done = Sound.signalReady()
				return done
			end)).to.equal(true)

			local lines = {}
			for _, word in ipairs(Horn.signalWords()) do
				local phrase = Horn.signalPhrase(word, Horn.CONFIG)
				local voice = Sound.signalVoice(word)
				expect(voice).to.be.ok()
				local sound = voice :: Sound
				expect(sound:IsA("Sound")).to.equal(true)
				-- ONE NAME PER CUE, so two voices in SoundService are tellable apart by eye in the
				-- Explorer as well as by this spec.
				expect(sound.Name).to.equal("DriveSignal_" .. word)
				-- AT THE EAR, NOT IN THE WORLD: parented to SoundService and to no part, which is
				-- what makes it 2-D -- the whole reason a drive-wide signal is drawn from the client.
				expect(sound.Parent).to.equal(SoundService)
				expect(sound.SoundId).to.equal(phrase.SOUND_ID)
				expect(sound.Volume).to.equal(Horn.CONFIG.SIGNAL.VOLUME)
				expect(sound.Looped).to.equal(false)

				-- ...AND THE ASSET IS REALLY HERE, which is the point of the preload: the cut can
				-- only play the measured phrase if the clip is loaded and long enough to hold it.
				expect(waitUntil(20, function()
					return sound.IsLoaded
				end)).to.equal(true)
				expect(sound.TimeLength > phrase.CUT).to.equal(true)
				table.insert(
					lines,
					string.format(
						"%s=%s %.2f s (cut %.2f-%.2f)",
						word,
						tostring(sound.IsLoaded),
						sound.TimeLength,
						phrase.FROM,
						phrase.CUT
					)
				)
			end
			-- THE TWO VOICES ARE SEPARATE INSTANCES, which is what makes "a signal is already
			-- sounding" a fact about `Sound.isSignalling` and not about one shared Sound.
			expect(Sound.signalVoice("start")).never.to.equal(Sound.signalVoice("end"))
			-- The default is the drive's first cue, so an old caller with no word still gets one.
			expect(Sound.signalVoice()).to.equal(Sound.signalVoice("start"))
			TestKit.note(
				string.format(
					"drive signal: made at load=%s, preload returned=%s, %s",
					tostring(made),
					tostring(select(2, Sound.signalReady())),
					table.concat(lines, ", ")
				)
			)
		end)

		it("sounds once per cue, and refuses a second signal while one is sounding", function()
			-- A LIVE DRIVE MAY BE SIGNALLING RIGHT NOW -- this spec runs inside a real session, and
			-- the drive's own GO sounds the horn -- so wait for the horn to finish before claiming
			-- anything about a fresh one.
			local whole = Horn.signalSeconds("start", Horn.CONFIG)
			expect(waitUntil(whole + 3, function()
				return not Sound.isSignalling()
			end)).to.equal(true)

			local before = Sound.stats()
			expect(Sound.driveSignal("start")).to.equal(true)
			expect(Sound.stats().signal).to.equal(before.signal + 1)
			expect(Sound.lastSignal()).to.equal("start")
			expect(Sound.isSignalling()).to.equal(true)

			-- THE REFUSAL IS THE RULE: two signals on top of each other read as one louder horn,
			-- not as two signals.
			expect(Sound.driveSignal("end")).to.equal(false)
			expect(Sound.stats().signalBusy).to.equal(before.signalBusy + 1)
			expect(Sound.stats().signal).to.equal(before.signal + 1)
			expect(Sound.lastSignal()).to.equal("start") -- the refused one changed nothing

			TestKit.note(
				string.format(
					"drive signal: %d sounded, %d refused as busy, start %.2f s, end %.2f s",
					Sound.stats().signal,
					Sound.stats().signalBusy,
					whole,
					Horn.signalSeconds("end", Horn.CONFIG)
				)
			)
		end)

		it("plays the END cue's own phrase, not the start one", function()
			-- *"for start and end of drive has to be ... different one"* -- the two cues really are
			-- two phrases now, so the end cue has to reach its own voice and its own cut.
			local phrase = Horn.signalPhrase("end", Horn.CONFIG)
			local voice = Sound.signalVoice("end") :: Sound
			expect(voice.SoundId).to.equal(phrase.SOUND_ID)
			-- WAITED FOR BEFORE THE CUE, NOT AFTER IT. `driveSignal` has a bounded 2 s `IsLoaded`
			-- backstop of its own and sounds the signal either way, so a cue given while the asset
			-- is still arriving can spend that whole budget before it plays -- which would race any
			-- window this case opened afterwards. The preload has had the client's whole boot; this
			-- is only the proof that it landed.
			expect(waitUntil(20, function()
				return voice.IsLoaded
			end)).to.equal(true)

			local whole = Horn.signalSeconds("start", Horn.CONFIG)
			expect(waitUntil(whole + 3, function()
				return not Sound.isSignalling()
			end)).to.equal(true)
			expect(Sound.driveSignal("end")).to.equal(true)
			expect(Sound.lastSignal()).to.equal("end")
			-- IT IS THE END VOICE THAT IS PLAYING, from the end phrase's own offset -- and the
			-- offset is read INSIDE the window, because `Stop` puts `TimePosition` back to 0 and the
			-- cut is only 1.68 s long.
			--
			-- `TimePosition > 0` IS PART OF THE PREDICATE AND NOT A TIDINESS, AND THE FIRST RUN OF
			-- THIS CASE IS WHY: `IsPlaying` goes true on the `Play` call, and a poll landing in that
			-- same frame reads the position the previous `Stop` left behind -- 0 -- before the engine
			-- has started the clip.
			--
			-- AND THE POSITION IS COMPARED WITH A TOLERANCE, which the SECOND run is why, and the
			-- reason is worth writing down: `Sound.TimePosition` is a 32-bit float, so the 0.32 this
			-- code writes reads back as 0.3199999928 -- and a poll that lands before the first
			-- advance reads exactly that, which is NOT `>= 0.32` in Luau's doubles. It failed by
			-- 7e-9. Measured in the same session, the normal first readable value is 0.341 and it
			-- climbs ~0.10 per 0.1 s; the offset itself was measured to survive three Play/Stop
			-- cycles (0.341 on the first frame of each), so what is tested here is real and only the
			-- comparison was wrong.
			local heardAt = -1
			expect(waitUntil(6, function()
				if voice.IsPlaying and voice.TimePosition > 0 then
					heardAt = voice.TimePosition
					return true
				end
				return false
			end)).to.equal(true)
			expect(heardAt >= phrase.FROM - 1e-3).to.equal(true)
			-- ...AND BELOW THE CUT, PLUS ONE POLL. The sounding thread stops the voice at `CUT`, and
			-- this poll can be up to its own 0.05 s interval behind, so the window has to allow one.
			expect(heardAt <= phrase.CUT + 0.1).to.equal(true)
			TestKit.note(string.format("drive signal: the END cue sounded, first readable position %.4f s", heardAt))
		end)

		it("plays the data's plan and holds no schedule of its own", function()
			-- The client walks `Horn.signalPlan`; it does not know how many soundings there are or
			-- which asset they come from.
			for _, word in ipairs(Horn.signalWords()) do
				local plan = Horn.signalPlan(word, Horn.CONFIG)
				local phrase = Horn.signalPhrase(word, Horn.CONFIG)
				expect(#plan).to.equal(1)
				expect(plan[1].seconds).to.equal(phrase.CUT - phrase.FROM)
				expect(plan[1].from).to.equal(phrase.FROM)
				expect(plan[1].soundId).to.equal(phrase.SOUND_ID)
			end
		end)
	end)
end
