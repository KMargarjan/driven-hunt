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
		afterAll(function()
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
