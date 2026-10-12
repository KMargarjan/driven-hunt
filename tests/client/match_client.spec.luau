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
			}) do
				expect((Drive.CONFIG :: any)[field]).to.equal(nil)
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
			-- THE BADGE IS THIS PLAYER'S OWN. With one player that is SHOOTER (Director decision F);
			-- in a two-player run one client is the DRIVER and its badge must say so, in its own
			-- team colour. Asserting "SHOOTER" for everybody was a one-player claim inside a suite
			-- the two-player run has to pass (TASKS.md row 34a).
			expect(string.find(text, Role.badge()) ~= nil).to.equal(true)
			expect(Role.badge()).to.equal(if Match.myTeam() == "Drivers" then "DRIVER" else "SHOOTER")
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
			quarry = { "WILD BOAR: male, female, cub", "every one of them counts - no cub rule yet" },
			rows = {},
			tied = {},
		}

		local function scoring()
			local snapshot = table.clone(LIVE)
			snapshot.phase = "Scoring"
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

		it("draws its text IN FRONT of its own panel, in white, with an outline (task 159)", function()
			-- THE DEFECT THIS CASE EXISTS FOR, and it shipped twice before anybody looked: task 141
			-- raised this panel to `Report.CONFIG.PANEL_Z_INDEX` (15) so it would not be cut off at
			-- the scope's glass, and left every label at the default ZIndex 1 -- so the translucent
			-- dark panel was drawn OVER its own words. `Hud.scoreRowText()` read them back perfectly
			-- the whole time; the screen showed a grey rectangle
			-- (.screenshots/20261011T230908Z-task159-results-scene.png). `ReportPanel` had already
			-- paid for exactly this on 2026-10-05 ("an EMPTY BLACK RECTANGLE ... drawn BEHIND its own
			-- background"), which is why the rule is now one helper and this is asserted.
			Hud.renderScore(scoring(), 12)
			local panel = Hud.scorePanel()
			expect(panel).to.be.ok()
			local checked = 0
			for _, child in ipairs(panel:GetChildren()) do
				if child:IsA("TextLabel") then
					checked += 1
					-- IN FRONT OF ITS OWN PANEL.
					expect(child.ZIndex > panel.ZIndex).to.equal(true)
					-- WHITE. The header is dimmer by TRANSPARENCY, not by a grey colour, and the
					-- highlighted row is Karen's own gold.
					local white = child.TextColor3 == Drive.CONFIG.TEXT_COLOR
					local mine = child.TextColor3 == Drive.CONFIG.SCORE_HIGHLIGHT_COLOR
					expect(white or mine).to.equal(true)
					-- ...and not faded out of existence by its own transparency.
					expect(child.TextTransparency < 0.5).to.equal(true)
					-- THE OUTLINE every other label in this Hud wears: a thin Code glyph over sunlit
					-- grass is the half of the text that disappears first.
					local stroke = child:FindFirstChildOfClass("UIStroke")
					expect(stroke).to.be.ok()
					expect(stroke.Thickness).to.equal(Drive.CONFIG.SCORE_TEXT_STROKE)
				end
			end
			-- Title, header, footer and every row slot.
			expect(checked).to.equal(3 + Drive.CONFIG.SCORE_ROWS_MAX)
			-- The title is the line that says what the panel is: bigger than a row, and BOLD.
			local title = panel:FindFirstChild("Title")
			expect(title.TextSize > Drive.CONFIG.SCORE_TEXT_SIZE).to.equal(true)
			expect(title.TextSize).to.equal(Drive.CONFIG.SCORE_TITLE_SIZE)
			expect(title.FontFace.Weight).to.equal(Enum.FontWeight.Bold)
			-- ...and the panel is still see-through, which is what Karen asked for.
			expect(Drive.CONFIG.SCORE_PANEL_TRANSPARENCY > 0).to.equal(true)
			TestKit.note(
				string.format(
					"match_client: results table -- panel z=%d labels z=%d title %d bold, stroke %d, panel alpha %.2f",
					panel.ZIndex,
					title.ZIndex,
					title.TextSize,
					Drive.CONFIG.SCORE_TEXT_STROKE,
					panel.BackgroundTransparency
				)
			)
		end)

		it("shows this drive's points, one row per player, mine highlighted", function()
			Hud.renderScore(scoring(), 12)
			local rows = Hud.scoreRowText()
			print("[match_client] score row 1: " .. (rows[1] or "<none>"))
			expect(#rows).to.equal(2)
			expect(string.find(rows[1], player.Name, 1, true) ~= nil).to.equal(true)
			expect(string.find(rows[1], "16", 1, true) ~= nil).to.equal(true)
			expect(string.find(rows[1], "SHOOTER", 1, true) ~= nil).to.equal(true)
			expect(string.find(rows[2], "Mila", 1, true) ~= nil).to.equal(true)
			expect(string.find(rows[2], "DRIVER", 1, true) ~= nil).to.equal(true)
			expect(string.find(rows[1], "nil", 1, true) == nil).to.equal(true)

			local panel = Hud.scorePanel()
			local mine = panel:FindFirstChild("Row1")
			local theirs = panel:FindFirstChild("Row2")
			expect(mine.TextColor3).to.equal(Drive.CONFIG.SCORE_HIGHLIGHT_COLOR)
			expect(theirs.TextColor3).to.equal(Drive.CONFIG.TEXT_COLOR)

			expect(string.find(Hud.scoreTitleText(), "DRIVE 3", 1, true) ~= nil).to.equal(true)
			-- THE RESULTS TABLE (task 159). Karen: *"showing image transperent with results table"* --
			-- this panel IS that table, and it says so. The WORDING is the contract's, so the
			-- assertion is against `Drive.CONFIG` and not against a string typed twice.
			expect(Hud.scoreTitleText()).to.equal(string.format(Drive.CONFIG.SCORE_TITLE_FORMAT, 3))
			expect(string.find(Hud.scoreTitleText(), "RESULTS", 1, true) ~= nil).to.equal(true)
			-- ...and it is see-through, which is the other half of what she asked for.
			expect(Drive.CONFIG.SCORE_PANEL_TRANSPARENCY > 0).to.equal(true)
			expect(Hud.scorePanel().BackgroundTransparency).to.equal(Drive.CONFIG.SCORE_PANEL_TRANSPARENCY)
			expect(Hud.scoreFooterText()).to.equal("NEXT DRIVE IN 12")
		end)

		-- THE FIRST-PLACE BADGE (task 160). Karen, 2026-10-11: *"first place ofc more"*. The rule
		-- itself is `Hud.firstPlaceRank` and is pure, so every case below is a table rather than a
		-- rendered frame -- and the two cases that matter are the ones where the badge must NOT
		-- appear, because a wrong badge names a winner who did not win.
		it("marks the leader 1st, and marks nobody when the top two are level", function()
			local function board(first: number, second: number?)
				local rows = { { userId = 1, name = "one", team = "Shooters", points = first, kills = 1 } }
				if second ~= nil then
					table.insert(rows, { userId = 2, name = "two", team = "Drivers", points = second, kills = 0 })
				end
				return rows
			end
			expect(Hud.firstPlaceRank(board(16, 3))).to.equal(1)
			expect(Hud.firstPlaceRank(board(16))).to.equal(1) -- alone, but he shot something
			-- A TIE AT THE TOP IS NOT A FIRST PLACE, it is a tie: ioquake3's `RANK_TIED_FLAG`
			-- (docs/research/2026-10-12-scoring.md section 2.1).
			expect(Hud.firstPlaceRank(board(16, 16))).to.equal(nil)
			-- NOBODY HAS SCORED YET, which is every board for the first minute of every drive. The
			-- order there is `Score.leaderboard`'s last tiebreak -- userId -- so a badge would crown
			-- whoever joined the server first.
			expect(Hud.firstPlaceRank(board(0, 0))).to.equal(nil)
			expect(Hud.firstPlaceRank(board(0))).to.equal(nil)
			expect(Hud.firstPlaceRank({})).to.equal(nil)
			expect(Hud.firstPlaceRank(nil)).to.equal(nil)
			-- ...and a board everybody is penalised on still has a leader: -10 beats -20.
			expect(Hud.firstPlaceRank(board(-10, -20))).to.equal(1)
			-- AND SO DOES A LEADER ON 0 OVER A SECOND ON -10 (round 1, note 2). The zero test used
			-- to be asked of the leader's own points, so these two boards -- a man clear at the top
			-- of each -- disagreed with each other. It is now asked only of the row with nobody
			-- behind it, which is the board it was always for: the one where nothing has happened.
			expect(Hud.firstPlaceRank(board(0, -10))).to.equal(1)
		end)

		it("puts the badge on the drawn row, on the leader's row only", function()
			Hud.renderScore(scoring(), 12)
			local rows = Hud.scoreRowText()
			print("[match_client] badged row 1: " .. (rows[1] or "<none>"))
			local badge = Drive.CONFIG.SCORE_FIRST_BADGE
			expect(string.find(rows[1], badge, 1, true) ~= nil).to.equal(true)
			expect(string.find(rows[2], badge, 1, true) == nil).to.equal(true)
			-- AFTER THE POINTS, not before them: the badge belongs against the number it was earned
			-- with, and a reader scanning the POINTS column must not find a word in it.
			expect(string.find(rows[1], badge, 1, true) > (string.find(rows[1], "16", 1, true) :: number)).to.equal(
				true
			)
			TestKit.note("match_client: first place -> " .. rows[1])
		end)

		it("clears the board when the next drive starts, so nothing stale flashes", function()
			Hud.renderScore(scoring(), 12)
			expect(#Hud.scoreRowText()).to.equal(2)
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
		-- THE SERVER'S WORDS, AS THE SERVER NOW SAYS THEM (task 160): each kind with what it is
		-- worth, off `Match.CONFIG.POINTS.KIND`. The Hud passes this through and decides nothing
		-- about it, which is the whole point of the last case in this describe.
		local CARD_QUARRY =
			{ "WILD BOAR, POINTS: male 10, female 6, cub 2", "every one of them counts - no cub rule yet" }

		local function snapshotIn(phase: string)
			local snapshot = {
				phase = phase,
				phaseEndsAt = 0,
				driveNumber = 4,
				boarsReleased = 0,
				boarsLeft = 6,
				waitingFor = {},
				quarry = CARD_QUARRY,
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

		it("draws the card's text IN FRONT of the card, with an outline (task 159)", function()
			-- THE SAME DEFECT AS THE RESULTS TABLE, in the other frame task 141 raised: Karen reads
			-- this card for ten seconds at the start of every drive, through its own panel.
			Hud.renderStartCard(starting(), "Shooters", 7)
			local card = Hud.startCard()
			expect(card).to.be.ok()
			local checked = 0
			for _, child in ipairs(card:GetChildren()) do
				if child:IsA("TextLabel") then
					checked += 1
					expect(child.ZIndex > card.ZIndex).to.equal(true)
					expect(child.TextTransparency < 0.5).to.equal(true)
					local stroke = child:FindFirstChildOfClass("UIStroke")
					expect(stroke).to.be.ok()
				end
			end
			expect(checked).to.equal(2 + Drive.CONFIG.START_CARD_LINES_MAX)
		end)

		it("tells a HUNTER his role, what he may shoot, and how long he has to reach his stand", function()
			Hud.renderStartCard(starting(), "Shooters", 10)
			local lines = Hud.startCardText()
			print("[match_client] start card: " .. table.concat(lines, " / ") .. " / " .. Hud.startCardTimerText())
			expect(lines[1]).to.equal("YOU ARE A HUNTER")
			-- WHAT MAY BE SHOT IS THE SERVER'S WORDS, passed through: the client decides nothing
			-- about what is legal.
			expect(lines[2]).to.equal(CARD_QUARRY[1])
			expect(lines[3]).to.equal(CARD_QUARRY[2])
			expect(string.find(Hud.startCardTitleText(), "DRIVE 4", 1, true) ~= nil).to.equal(true)
			expect(Hud.startCardTimerText()).to.equal("GET TO YOUR STAND  10")
		end)

		it("tells a BEATER the drive is what is counting down, not his walk", function()
			Hud.renderStartCard(starting(), "Drivers", 3)
			expect(Hud.startCardText()[1]).to.equal("YOU ARE A BEATER")
			expect(Hud.startCardTimerText()).to.equal("DRIVE STARTS IN  3")
		end)

		it("rounds the countdown UP, so a player never reads 0 while he still has time", function()
			-- `secondsLeft` is a float counted down locally from the server's timestamp; 9.2 seconds
			-- left is "10" and 0.4 is "1", because the card is a countdown and not a stopwatch.
			expect(Hud.startCardTimerFor("Shooters", 9.2)).to.equal("GET TO YOUR STAND  10")
			expect(Hud.startCardTimerFor("Shooters", 0.4)).to.equal("GET TO YOUR STAND  1")
			expect(Hud.startCardTimerFor("Shooters", 0)).to.equal("GET TO YOUR STAND  0")
			expect(Hud.startCardTimerFor("Drivers", -5)).to.equal("DRIVE STARTS IN  0") -- never negative
		end)

		it("shows nothing at all with no drive, and no role line for a player on no team", function()
			Hud.renderStartCard(nil, nil, 0)
			expect(Hud.isStartCardVisible()).to.equal(false)
			-- The lines themselves are pure, so the no-team case is one assertion: the quarry still
			-- reads, because what may be shot does not depend on which side you are on.
			local lines = Hud.startCardLines(starting(), nil)
			expect(#lines).to.equal(2)
			expect(lines[1]).to.equal(CARD_QUARRY[1])
			expect(Hud.roleWord(nil)).to.equal("")
			expect(Hud.roleWord("Shooters")).to.equal("HUNTER")
			expect(Hud.roleWord("Drivers")).to.equal("BEATER")
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
			print("[match_client] the wire's quarry: " .. table.concat(snapshot.quarry, " | "))
			for _, field in ipairs({ "QUARRY", "QUARRY_NOTE", "START_HOLD_TEAM" }) do
				expect((Drive.CONFIG :: any)[field]).to.equal(nil)
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
	-- TASK 163. KAREN, 2026-10-12: *"when hunt starts 3 longer horn calls and when ends the same"*.
	-- The server's half is `match_phase.spec` (one entry at GO, one at the end) and the DATA's half
	-- is `zz_horn.spec` (three notes, the cut, the gaps). This is the client's half: the entry draws
	-- no line, and the sound owner sounds it once.
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
		-- and the only budget against it was a 2 s wait -- and `TimePosition` on an unloaded Sound
		-- is not kept, so a lost race plays the clip from 0, where the eight SHORT notes are. It is
		-- made and preloaded at MODULE LOAD now, and this case is what says so.
		it("has its Sound made and configured BEFORE the first cue, and preloaded", function()
			-- A FACT ABOUT LOAD TIME, not about now: once a drive has signalled, "it existed before
			-- the cue" cannot be read off the Instance, so the module records it.
			local made = (Sound.signalReady())
			expect(made).to.equal(true)
			-- The preload is a thread, so it is waited for rather than asserted on sight.
			expect(waitUntil(20, function()
				local _, done = Sound.signalReady()
				return done
			end)).to.equal(true)

			local voice = Sound.signalVoice()
			expect(voice).to.be.ok()
			local sound = voice :: Sound
			expect(sound:IsA("Sound")).to.equal(true)
			expect(sound.Name).to.equal("DriveSignal")
			-- AT THE EAR, NOT IN THE WORLD: parented to SoundService and to no part, which is what
			-- makes it 2-D -- the whole reason a drive-wide signal is drawn from the client.
			expect(sound.Parent).to.equal(SoundService)
			expect(sound.SoundId).to.equal(Horn.CONFIG.SOUND_ID)
			expect(sound.Volume).to.equal(Horn.CONFIG.SIGNAL.VOLUME)
			expect(sound.Looped).to.equal(false)

			-- ...AND THE ASSET IS REALLY HERE, which is the point of the preload: the cut can only
			-- play the measured note if the clip is loaded and long enough to hold it.
			expect(waitUntil(20, function()
				return sound.IsLoaded
			end)).to.equal(true)
			expect(sound.TimeLength > Horn.CONFIG.SIGNAL.CUT).to.equal(true)
			TestKit.note(
				string.format(
					"drive signal: voice made at load=%s, preload returned=%s, IsLoaded=%s, clip %.2f s, cut %.2f-%.2f",
					tostring(made),
					tostring(select(2, Sound.signalReady())),
					tostring(sound.IsLoaded),
					sound.TimeLength,
					Horn.CONFIG.SIGNAL.START,
					Horn.CONFIG.SIGNAL.CUT
				)
			)
		end)

		it("sounds once per cue, and refuses a second signal while one is sounding", function()
			-- A LIVE DRIVE MAY BE SIGNALLING RIGHT NOW -- this spec runs inside a real session, and
			-- the drive's own GO sounds the horn -- so wait for the horn to finish before claiming
			-- anything about a fresh one.
			local whole = Horn.signalSeconds(Horn.CONFIG)
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
					"drive signal: %d sounded, %d refused as busy, %.2f s each, note %.2f-%.2f",
					Sound.stats().signal,
					Sound.stats().signalBusy,
					whole,
					Horn.CONFIG.SIGNAL.START,
					Horn.CONFIG.SIGNAL.CUT
				)
			)
		end)

		it("plays the data's plan and holds no schedule of its own", function()
			-- The client walks `Horn.signalPlan`; it does not know how many notes there are.
			local plan = Horn.signalPlan(Horn.CONFIG)
			expect(#plan).to.equal(Horn.CONFIG.SIGNAL.NOTES)
			expect(plan[1].seconds).to.equal(Horn.CONFIG.SIGNAL.CUT - Horn.CONFIG.SIGNAL.START)
		end)
	end)
end
