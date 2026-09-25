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
			expect(Drive.CONFIG.SCOREBOARD_ENABLED).to.equal(false) -- 1.7b
			expect(function()
				(Drive.CONFIG :: any).FEED_LINES = 99
			end).to.throw()
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
			expect(Match.isTied()).to.equal(false) -- nobody can be tied: the safety rule is 1.7b
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
			-- The player is a Shooter in a one-player drive (Director decision F).
			expect(string.find(text, "SHOOTER") ~= nil).to.equal(true)
			local phase = Match.phase()
			if phase == "Running" or phase == "Assigning" or phase == "Scoring" then
				expect(string.find(text, "%d+:%d%d") ~= nil).to.equal(true)
			end
		end)
	end)
end
