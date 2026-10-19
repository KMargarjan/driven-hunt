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
--      ARRIVAL IS THE SHOOTER'S CLAIM ONLY, since Task 36: the server sends once, wherever its own
--      suite has got to, and a client hears it only if its listener already exists. The shooter is
--      immune to that race by accident (he also gets one for every shot he lands); a driver is not,
--      and the first `it` below says exactly what he asserts instead.
--   2. THE DRAWING. Colour, kind and the timeout, driven through Hud.onHitMarker -- the exact
--      function the remote is bound to.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/hit-zones.md (section 14, Director item C), docs/design/shotgun.md (3.4)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Role = require(ReplicatedStorage:WaitForChild("ClientTests"):WaitForChild("Role"))

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Hud = require(scripts:WaitForChild("Hud"))
-- THE MARKER'S COLOURS ARE `Style`'S SINCE TASK 201 E (the Designer's design system, 2026-10-17,
-- §5 surface 19). They were `Shotgun.CONFIG.HIT_MARK_COLOR` / `HIT_MARK_KILL_COLOR`, which are
-- archived in `backups/2026-10-19_hit-mark-colours.txt`.
local Style = Hud.Style

-- How long to wait for the SERVER's marker. It was 30 s, and that was a claim about the shooter
-- dressed up as a claim about the wire: a shooter also receives a marker for every shot he lands, so
-- his window is satisfied within seconds of his first hit, while a DRIVER receives only the one
-- tests/server/weapon_hits.spec sends -- and that fires wherever the SERVER suite happens to have
-- reached, which in a two-player run was after this window had closed (Task 36, measured from the
-- Task 35 run: the driver was the only report that failed here). The listener below has been
-- collecting since require time, so waiting longer costs a passing run nothing at all.
local SERVER_MARKER_TIMEOUT = 150

local CONFIG = Shotgun.CONFIG

-- Counted from the real remote, alongside the Hud's own listener. This spec never fires it.
local received = {}
local startedAt = os.clock()
local firstAt: number? = nil
Shotgun.remotes().HitMarker.OnClientEvent:Connect(function(payload)
	firstAt = firstAt or os.clock()
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

-- THE ARM'S DROP LINE (§2's one exception, task 201 E): a SIBLING of the arm, one band under it,
-- `SCRIM` and offset 1 px down and right. Read back off the real screen, because "the stroke went
-- away" and "something replaced it" are two different claims.
local function armDrop(): Frame?
	local gui = Hud.gui()
	local mark = gui and gui:FindFirstChild("HitMark")
	local drop = mark and mark:FindFirstChild("TopLeftDrop")
	return if drop and drop:IsA("Frame") then drop :: Frame else nil
end

return function()
	describe("the marker the server sends", function()
		it("reaches a shooter from the server over the real remote; a driver keeps the wire", function()
			-- weapon_hits.spec calls Weapon.markHit on the server during this same run. If the wire
			-- is broken -- a missing RemoteEvent, a FireClient that never happens, a Hud that never
			-- connects -- nothing arrives and this is red.
			--
			-- THE SHOOTER'S CLAIM, AND ONLY HIS, BECAUSE THE OTHER HALF IS A START-ORDER RACE
			-- (Task 36, TASKS.md row 36a). weapon_hits.spec sends its markers ONCE, wherever the
			-- server's suite has got to; a client only hears them if its own listener already
			-- exists. The shooter is immune by accident -- he also receives one for every shot he
			-- lands, all session -- but a DRIVER receives nothing else at all, so on a run where his
			-- client starts after the send he is told about a broken wire that is not broken.
			-- MEASURED, and it is why this is written this way rather than with a longer window: in
			-- one two-player run he received 0 in 174 s, and in the next, with the same code on both
			-- sides, 2 within 14 s of his suite starting. A window cannot fix an event that was
			-- already over. The note below records the number every run.
			local arrived = waitUntil(if Role.isShooter() then SERVER_MARKER_TIMEOUT else 5, function()
				return #received > 0
			end)
			-- A NOTE, not a print: a two-player session's console comes back truncated and takes the
			-- numbers that explain a failure with it (Task 34). This one says whether the wire was
			-- broken or merely slower than the window.
			TestKit.note(
				string.format(
					"hit_marker: %d marker(s), first at %+.1f s from suite start, waited %.1f s",
					#received,
					if firstAt then firstAt - startedAt else -1,
					os.clock() - startedAt
				)
			)
			if Role.isDriver() then
				-- What IS asserted for a driver: the remote exists on his client and the Hud is
				-- listening to it (the next `it`), and the whole drawing path works (the describe
				-- below drives Hud.onHitMarker, the exact function the remote is bound to). And if
				-- a marker did arrive -- it usually does -- it must be a well-formed one.
				expect(Shotgun.remotes().HitMarker:IsA("RemoteEvent")).to.equal(true)
				if #received > 0 then
					expect(type(received[1])).to.equal("table")
					expect(received[1].kind).to.be.ok()
				end
				return
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
			expect(armColor()).to.equal(Style.hitMarkColor("hit"))
			expect(armColor()).to.equal(Style.LOOK.PAPER)

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
			expect(armColor()).to.equal(Style.hitMarkColor("kill"))
			expect(armColor()).to.equal(Style.LOOK.PINE_TEXT)
			expect(armColor()).never.to.equal(Style.hitMarkColor("hit"))

			-- Still up after a plain hit's whole lifetime would have expired.
			task.wait(CONFIG.HIT_MARK_SECONDS + 0.05)
			expect(Hud.isHitMarkVisible()).to.equal(true)

			expect(waitUntil(CONFIG.HIT_MARK_KILL_SECONDS + 1, function()
				return not Hud.isHitMarkVisible()
			end)).to.equal(true)
		end)

		it("shows a THIRD one on a wound, and the drop line keeps its own colour", function()
			-- §5 surface 19: *"a hit `PAPER`, a kill `PINE_TEXT`, a wound `CLAY`. One colour serves
			-- all three today."* THE THIRD ARM IS REACHABLE BY PARAMETER AND NOT YET BY THE WIRE:
			-- `Weapon.markHit` is called with "hit" and with "kill" only, so this case is what
			-- proves the screen already answers a wound the day the server learns to say it.
			Hud.onHitMarker({ kind = "wound" })
			expect(Hud.isHitMarkVisible()).to.equal(true)
			expect(Hud.hitMarkKind()).to.equal("wound")
			expect(armColor()).to.equal(Style.LOOK.CLAY)
			-- THREE DISTINCT COLOURS, asserted as three and not as "not the other one".
			expect(Style.hitMarkColor("hit")).never.to.equal(Style.hitMarkColor("kill"))
			expect(Style.hitMarkColor("kill")).never.to.equal(Style.hitMarkColor("wound"))
			expect(Style.hitMarkColor("wound")).never.to.equal(Style.hitMarkColor("hit"))

			-- THE DROP LINE IS NOT AN ARM. `Hud.showHitMark` recolours every `Frame` under the
			-- marker, and a shadow recoloured to the kind's colour would double the mark's apparent
			-- thickness. It is skipped by its own attribute, and this reads that off the screen.
			local drop = armDrop()
			expect(drop).to.be.ok()
			expect((drop :: Frame):GetAttribute("DropLine")).to.equal(true)
			expect((drop :: Frame).BackgroundColor3).to.equal(Style.LOOK.SCRIM)
			expect((drop :: Frame).BackgroundColor3).never.to.equal(armColor())
			-- ...offset exactly one pixel down and right of its arm, and under it.
			local gui = Hud.gui()
			local mark = (gui :: ScreenGui):FindFirstChild("HitMark") :: Frame
			local arm = mark:FindFirstChild("TopLeft") :: Frame
			expect((drop :: Frame).Position.X.Offset - arm.Position.X.Offset).to.equal(1)
			expect((drop :: Frame).Position.Y.Offset - arm.Position.Y.Offset).to.equal(1)
			expect((drop :: Frame).ZIndex < arm.ZIndex).to.equal(true)
			-- ...and turned with it, which a square shadow under a diagonal arm would not be.
			expect((drop :: Frame).Rotation).to.equal(arm.Rotation)

			-- AND NO BLACK `UIStroke` IS LEFT ANYWHERE UNDER EITHER MARK (§2). The whole point of
			-- the drop line is that it replaced one.
			for _, holder in ipairs({ mark, (gui :: ScreenGui):FindFirstChild("Crosshair") }) do
				if holder ~= nil then
					for _, node in ipairs((holder :: Instance):GetDescendants()) do
						expect(node:IsA("UIStroke")).to.equal(false)
					end
				end
			end
			TestKit.note("hit marker: three kinds, drop line present, no stroke under either mark")

			expect(waitUntil(CONFIG.HIT_MARK_SECONDS + 1, function()
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
