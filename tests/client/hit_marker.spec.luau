-- hit_marker.spec: the hit marker, in the real client, on the real Hud.
--
-- Karen's playtest (2026-09-25) said she could not tell whether she was hitting anything, and the
-- Director's answer was this: the server tells the shooter alone, one way, and PlayerScripts.Hud
-- draws a short tick -- a distinct one for a kill. So there are two separate things to prove, and
-- this file is careful about which is which:
--
--   1. THE WIRE. The Hud is connected to Shotgun.Remotes.HitMarker, and a marker sent by the SERVER
--      arrives here and draws. The server end is weapon_hits.spec, which calls Weapon.markHit during
--      the same Play session; this spec waits for it. Neither side can fake it: the client cannot
--      fire a server -> client remote, and the server cannot draw.
--   2. THE DRAWING. Colour, kind and the timeout, driven through Hud.onHitMarker -- the exact
--      function the remote is bound to.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/hit-zones.md (section 14, Director item C), docs/design/shotgun.md (3.4)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Hud = require(scripts:WaitForChild("Hud"))

local CONFIG = Shotgun.CONFIG

-- Counted from the real remote, alongside the Hud's own listener. This spec never fires it.
local received = {}
Shotgun.remotes().HitMarker.OnClientEvent:Connect(function(payload)
	table.insert(received, payload)
end)

local function waitUntil(seconds: number, predicate: () -> boolean): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if predicate() then
			return true
		end
		task.wait(0.03)
	end
	return predicate()
end

local function armColor(): Color3?
	local gui = Hud.gui()
	local mark = gui and gui:FindFirstChild("HitMark")
	local arm = mark and mark:FindFirstChild("TopLeft")
	return if arm and arm:IsA("Frame") then arm.BackgroundColor3 else nil
end

return function()
	describe("the marker the server sends", function()
		it("reaches this client, from the server, over the real remote", function()
			-- weapon_hits.spec calls Weapon.markHit on the server during this same run. If the wire
			-- is broken -- a missing RemoteEvent, a FireClient that never happens, a Hud that never
			-- connects -- nothing arrives and this is red.
			local arrived = waitUntil(30, function()
				return #received > 0
			end)
			if not arrived then
				print("[hit_marker] no server-sent marker arrived in 30 s")
			end
			expect(arrived).to.equal(true)
			expect(type(received[1])).to.equal("table")
			expect(received[1].kind).to.be.ok()
		end)

		it("is listened to by the Hud itself, not only by this spec", function()
			expect(Hud.hitMarkerConnected()).to.equal(true)
		end)
	end)

	describe("what it draws", function()
		it("shows a tick on a hit, and takes it away again", function()
			Hud.onHitMarker({ kind = "hit" })
			expect(Hud.isHitMarkVisible()).to.equal(true)
			expect(Hud.hitMarkKind()).to.equal("hit")
			expect(armColor()).to.equal(CONFIG.HIT_MARK_COLOR)

			-- It is a tick, not a state: it goes away on its own.
			expect(waitUntil(CONFIG.HIT_MARK_SECONDS + 1, function()
				return not Hud.isHitMarkVisible()
			end)).to.equal(true)
			expect(Hud.hitMarkKind() == nil).to.equal(true)
		end)

		it("shows a DIFFERENT one on a kill, and holds it longer", function()
			Hud.onHitMarker({ kind = "kill" })
			expect(Hud.isHitMarkVisible()).to.equal(true)
			expect(Hud.hitMarkKind()).to.equal("kill")
			expect(armColor()).to.equal(CONFIG.HIT_MARK_KILL_COLOR)
			expect(armColor()).never.to.equal(CONFIG.HIT_MARK_COLOR)

			-- Still up after a plain hit's whole lifetime would have expired.
			task.wait(CONFIG.HIT_MARK_SECONDS + 0.05)
			expect(Hud.isHitMarkVisible()).to.equal(true)

			expect(waitUntil(CONFIG.HIT_MARK_KILL_SECONDS + 1, function()
				return not Hud.isHitMarkVisible()
			end)).to.equal(true)
		end)

		it("does not let an earlier tick hide a later one", function()
			-- Two hits in quick succession: the first one's timer must not take the second one's
			-- marker off the screen. That is what the token is for.
			Hud.onHitMarker({ kind = "hit" })
			task.wait(CONFIG.HIT_MARK_SECONDS * 0.6)
			Hud.onHitMarker({ kind = "hit" })
			task.wait(CONFIG.HIT_MARK_SECONDS * 0.6)
			expect(Hud.isHitMarkVisible()).to.equal(true)
			expect(waitUntil(CONFIG.HIT_MARK_SECONDS + 1, function()
				return not Hud.isHitMarkVisible()
			end)).to.equal(true)
		end)

		it("draws something even for a payload it does not recognise", function()
			-- A marker that silently does nothing is the exact failure this feature exists to fix.
			Hud.onHitMarker(nil)
			expect(Hud.isHitMarkVisible()).to.equal(true)
			expect(Hud.hitMarkKind()).to.equal("hit")
			Hud.onHitMarker({ kind = "something new" })
			expect(Hud.hitMarkKind()).to.equal("hit")
			expect(waitUntil(CONFIG.HIT_MARK_SECONDS + 1, function()
				return not Hud.isHitMarkVisible()
			end)).to.equal(true)
		end)

		it("is a sibling of the crosshair, so it still shows while aiming", function()
			local gui = Hud.gui()
			expect(gui).to.be.ok()
			local mark = gui:FindFirstChild("HitMark")
			expect(mark).to.be.ok()
			expect(mark.Parent).to.equal(gui) -- NOT a child of the crosshair, which ADS hides
			local arms = 0
			for _, child in ipairs(mark:GetChildren()) do
				if child:IsA("Frame") then
					arms += 1
				end
			end
			expect(arms).to.equal(4)
		end)
	end)
end
