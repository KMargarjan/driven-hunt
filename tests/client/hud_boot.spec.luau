-- hud_boot.spec: THE HUD DOES NOT LOSE A SYSTEM TO A REPLICATION RACE. In the real client, on the
-- real Hud, with one folder of this spec's own for the race itself.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- IT EXISTS BECAUSE THE HUD LOOKED FOR THE MATCH INSTEAD OF WAITING FOR IT (task 134, queued as
-- TASKS row 133c while task 133 was being fixed). `Hud.start` read `PlayerScripts.Match` with
-- `FindFirstChild` -- on the line after it WAITED for `PlayerScripts.Camera`, under a comment that
-- describes this exact race and was written because of it (task 123 round 7: the crosshair that
-- would not go away). `PlayerScripts` is replicated and its children arrive in no defined order, so
-- on a boot that lost the race `MatchSystem` was nil FOR THE SESSION and none of the drive's three
-- connections was ever made: no drive bar, no clock, no feed, for the whole drive, silently.
--
-- IT IS THE SAME SHAPE AS TASK 133's GUNLESS SESSION, which was measured at 4 failures in 10 fresh
-- Plays in the Forest Test for `CameraBoot`'s copy of it. The failure is a RACE, so a spec cannot
-- make the real `PlayerScripts.Match` arrive late; what it CAN do is drive the rule that decides --
-- `Hud.whenReady` -- with a container it owns, and that is the second case below.
--
-- WHY THE CONTAINER AND THE NAME RATHER THAN A MODULE: a spec cannot create a requireable
-- ModuleScript, because `Source` is not writable outside a plugin context. `whenReady` takes the
-- lookup, not the result, so the race is testable without one.
--
-- Design: docs/design/drive.md (section 9.1, the clock), docs/design/drive-report.md (section 8.1,
-- the points column the panel reads off the match). TASKS.md rows 133c, 134.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Hud = require(scripts:WaitForChild("Hud"))

local function waitUntil(seconds: number, predicate: () -> boolean): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if predicate() then
			return true
		end
		RunService.Heartbeat:Wait()
	end
	return predicate()
end

return function()
	describe("the Hud finds the systems it draws", function()
		it("is connected to the drive in this session", function()
			-- THE LIVE CLAIM, and the one that would have caught the bug in the place it happened:
			-- the Hud is listening to the match, so there is going to be a drive bar. It is the same
			-- assertion `camera_client.spec` gained in task 133 for the viewmodel's source, and for
			-- the same reason -- every other Hud case passes happily with no match at all, because
			-- "no drive" and "no drive SYSTEM" draw the same thing.
			expect(waitUntil(15, Hud.driveConnected)).to.equal(true)
			TestKit.note("hud_boot: the Hud is connected to the drive")
		end)

		it("connects to a system that arrives AFTER it looked", function()
			-- THE RACE, DRIVEN. The folder is this spec's; the child lands a quarter of a second
			-- after the lookup, which is exactly what losing the race looks like. With the old
			-- `FindFirstChild` this callback never runs -- that is the whole bug -- so this case is
			-- what fails if the fix is taken out.
			-- PARENTED NOWHERE. `ReplicatedStorage` is Rojo-owned, so a Folder this spec parks there
			-- is an instance with no file behind it; `WaitForChild` and `FindFirstChild` do not care
			-- whether the container is in the DataModel, so it never enters it.
			local container = Instance.new("Folder")
			container.Name = "HudBootSpecContainer"

			local seen: Instance? = nil
			local ok, err = pcall(function()
				local wasThere = Hud.whenReady(container, "Match", function(child)
					seen = child
				end)
				-- IT SAYS IT WAS NOT THERE, and it has not called back yet: a `whenReady` that
				-- answered true here would mean the early path had run on an empty container.
				expect(wasThere).to.equal(false)
				expect(seen).to.equal(nil)

				task.wait(0.25)
				local late = Instance.new("Folder")
				late.Name = "Match"
				late.Parent = container

				expect(waitUntil(5, function()
					return seen ~= nil
				end)).to.equal(true)
				expect(seen).to.equal(late)
				TestKit.note("hud_boot: a system that arrived 0.25 s late was still connected")
			end)
			-- THE FOLDER GOES WHETHER THE CASE PASSED OR NOT, and with it the spawned wait's own
			-- subject: a failing assertion must not leave this spec's rubbish in the session.
			container:Destroy()
			if not ok then
				error(err, 0)
			end
		end)

		it("calls back at once when the system is already there, and says so", function()
			-- THE COMMON PATH, which must stay exactly as cheap as the `FindFirstChild` it replaced:
			-- no spawn, no frame, no wait. `wasThere` is how a caller knows which path it took.
			local container = Instance.new("Folder")
			container.Name = "HudBootSpecContainer2"
			local early = Instance.new("Folder")
			early.Name = "Match"
			early.Parent = container

			local seen: Instance? = nil
			local ok, err = pcall(function()
				local wasThere = Hud.whenReady(container, "Match", function(child)
					seen = child
				end)
				-- SYNCHRONOUS: asserted before any yield, so a callback deferred by even one frame
				-- fails.
				expect(seen).to.equal(early)
				expect(wasThere).to.equal(true)
			end)
			container:Destroy()
			if not ok then
				error(err, 0)
			end
		end)

		it("will not wire the drive twice", function()
			-- IDEMPOTENT, because there are now two ways in -- `Hud.start`'s early call and the late
			-- one from the spawned wait -- and a drive connected twice would draw the feed twice and
			-- run two Heartbeat timers. The session's own match is already in, so this is the second
			-- call by construction and it must refuse.
			expect(Hud.driveConnected()).to.equal(true)
			expect(Hud.useMatch({})).to.equal(false)
			-- ...AND NOTHING AT ALL IS STILL NOTHING: `useMatch(nil)` is what a world with no drive
			-- hands it, and it must not claim to have connected one.
			expect(Hud.useMatch(nil)).to.equal(false)
		end)
	end)
end
