-- match_client.spec: the drive from the player's side -- the replica, the drive bar, and the one
-- property this system claims that a grep alone cannot prove: it has NO inbound remote at all.
--
-- It reaches the modules through Players.LocalPlayer.PlayerScripts, never through
-- StarterPlayerScripts, which is a template.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/drive.md (sections 9.1, 9.3, 12.7)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Role = require(ReplicatedStorage:WaitForChild("ClientTests"):WaitForChild("Role"))

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Match = require(scripts:WaitForChild("Match"))
local Hud = require(scripts:WaitForChild("Hud"))

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
					points = 180,
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
					points = 25,
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
		-- THE SCORE BOARD IS HIDDEN WHILE THE REPORT PANEL IS OPEN, and the report panel OPENS BY
		-- ITSELF when a drive closes (`Hud.ReportPanel.onDriveChanged`, "auto-opens ONCE"). This
		-- describe renders scripted snapshots and says nothing about the report, so that was an
		-- unstated precondition -- and the gate found it: a live drive closed part-way through a
		-- one-player run and all three cases below failed with an empty board
		-- (`match_client.spec` "Expected 2, got 0", `report_panel.spec` "Expected false, got true").
		--
		-- STATING IT IS NOT WEAKENING ANYTHING: `Hud.scorePanelVisible(snapshot, reportOpen)` already
		-- takes the report's state as an argument, and its own case still drives both values. This
		-- only stops a drive that ended at the wrong moment from deciding what the board shows.
		local reportWasOpen = false

		beforeAll(function()
			reportWasOpen = Hud.Report.isOpen()
			if reportWasOpen then
				TestKit.note("match_client: a drive report had auto-opened; closed for the score cases")
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

		it("shows this drive's points, one row per player, mine highlighted", function()
			Hud.renderScore(scoring(), 12)
			local rows = Hud.scoreRowText()
			print("[match_client] score row 1: " .. (rows[1] or "<none>"))
			expect(#rows).to.equal(2)
			expect(string.find(rows[1], player.Name, 1, true) ~= nil).to.equal(true)
			expect(string.find(rows[1], "180", 1, true) ~= nil).to.equal(true)
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
		local CARD_QUARRY = { "WILD BOAR: male, female, cub", "every one of them counts - no cub rule yet" }

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
			-- The same precondition the score cases state: the report auto-opens when a drive closes,
			-- and both panels hide behind it on purpose.
			reportWasOpen = Hud.Report.isOpen()
			if reportWasOpen then
				TestKit.note("match_client: a drive report had auto-opened; closed for the start-card cases")
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
end
