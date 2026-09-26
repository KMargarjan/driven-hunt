-- match_live.spec: the REAL drive, the one the player in this Play session is standing in.
--
-- It does not start a Match of its own, and that is deliberate. ServerScriptService.Match is a
-- singleton that MatchBoot has already started with the production boar runtime, the real markers
-- and the real weapon; a spec that called Match.start again would either assert ("called twice") or,
-- worse, stop production and run a stub in its place while the client specs were reading the Hud it
-- feeds. So this asserts on production -- which is also the only thing here that tests the player's
-- path rather than the harness's (rule 6). The pure machine is driven hard, with stand-in players
-- and simulated time, in match_phase.spec and match_roster.spec.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/drive.md (sections 9.2, 12.4)
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Teams = game:GetService("Teams")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Flags = require(game:GetService("ReplicatedStorage"):WaitForChild("Flags"))
local Map = require(game:GetService("ReplicatedStorage"):WaitForChild("Map"))
local Match = require(ServerScriptService:WaitForChild("Match"))
local TestKit = require(game:GetService("ReplicatedStorage"):WaitForChild("TestKit"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
local Markers = Match.Markers

local function waitUntil(timeout: number, predicate: () -> boolean): boolean
	local started = os.clock()
	while os.clock() - started < timeout do
		if predicate() then
			return true
		end
		task.wait(0.1)
	end
	return predicate()
end

return function()
	describe("the drive that is running now", function()
		it("left Waiting, because one player IS a drive in Milestone 1", function()
			-- Director decision F / audit-003 must-fix 1. If MIN_PLAYERS were 2, this Play session
			-- would sit in Waiting forever, nobody would be armed, and the weapon and camera client
			-- specs would go red for a reason that has nothing to do with them.
			expect(#Players:GetPlayers() >= 1).to.equal(true)
			local left = waitUntil(20, function()
				return Match.phase() ~= "Waiting"
			end)
			if not left then
				local snapshot = Match.snapshot()
				print("[match_live] still waiting for: " .. table.concat(snapshot.waitingFor, ", "))
			end
			expect(left).to.equal(true)
		end)

		it("made two teams that Roblox will not assign anybody to itself", function()
			local drivers = Teams:FindFirstChild("Drivers")
			local shooters = Teams:FindFirstChild("Shooters")
			expect(drivers).to.be.ok()
			expect(shooters).to.be.ok()
			-- The page does not state AutoAssignable's default, so this is set explicitly and
			-- asserted rather than assumed (docs/research/2026-09-25-drive.md source A): Roblox
			-- assigning players itself would be a second writer of the one field this system owns.
			expect(drivers.AutoAssignable).to.equal(false)
			expect(shooters.AutoAssignable).to.equal(false)
		end)

		it("put every player on a team, and armed exactly the shooters", function()
			-- PLAYER-COUNT AWARE, because this same suite runs in the two-player mode (Task 34): with
			-- two players one of them is a DRIVER, and `GetPlayers()[1]` was as likely to be the
			-- driver as the shooter -- an assertion that was true only of a one-player session inside
			-- the suite the 2-player run requires to be green. Who is a Shooter with one player is
			-- tests/server/match_teams.spec's business now.
			for _, player in ipairs(Players:GetPlayers()) do
				expect(waitUntil(20, function()
					return player.Team ~= nil
				end)).to.equal(true)
				print(
					string.format("[match_live] %s is on %s in phase %s", player.Name, player.Team.Name, Match.phase())
				)
				-- AND NOT TIED, which is new in 1.7b and is not a hedge: in a two-player run the
				-- shooter really does get tied to a tree by tests/client/zz_tie_to_a_tree.spec, and a
				-- tied shooter may not carry a gun. Without this clause the rule working would make
				-- this spec fail.
				local free = not Match.isTied(player.UserId)
				expect(Match.mayCarryWeapon(player)).to.equal(player.Team.Name == "Shooters" and free)
			end
		end)

		it("gave the shooters a gun they are actually holding, not one on a list", function()
			-- THE ASSERTION THIS SUITE DID NOT HAVE, and the one that would have caught what a
			-- two-player run found (Task 34): mayCarryWeapon said SHOOTER for a player whose Backpack
			-- was empty and for whom no Tool existed anywhere in the place. The policy was right and
			-- the player was unarmed for the whole drive -- because a Tool built while the Backpack
			-- was a moment from existing was parented to nil and still recorded as granted.
			-- True at every player count, which is what lets it run in both harness modes.
			for _, player in ipairs(Players:GetPlayers()) do
				expect(waitUntil(20, function()
					return player.Team ~= nil
				end)).to.equal(true)
				local function holdsGun(): boolean
					local backpack = player:FindFirstChildOfClass("Backpack")
					if backpack and backpack:FindFirstChildOfClass("Tool") then
						return true
					end
					local character = player.Character
					return character ~= nil and character:FindFirstChildOfClass("Tool") ~= nil
				end
				-- RE-ASKED INSIDE THE WAIT, not captured before it: the answer can change while this
				-- is waiting (a tie revokes the gun), and comparing against a stale answer would fail
				-- for the rule working.
				local expected = Match.mayCarryWeapon(player)
				local held = waitUntil(if expected then 20 else 1, function()
					expected = Match.mayCarryWeapon(player)
					return holdsGun() == expected
				end)
				-- A NOTE, not a print: this is the assertion a two-player run keeps failing, and the
				-- console it printed into came back truncated every time (Task 34). The weapon's own
				-- counters say WHICH failure it is -- never granted, granted and lost, or revoked
				-- and never granted again -- and they now arrive with the failure.
				local stats = Weapon.stats()
				TestKit.note(
					string.format(
						"match_live: %s (%s) may carry=%s holds=%s | weapon granted=%d grantsMissed=%d revoked=%d",
						player.Name,
						player.Team.Name,
						tostring(expected),
						tostring(holdsGun()),
						stats.granted,
						stats.grantsMissed,
						stats.revoked
					)
				)
				expect(held).to.equal(true)
			end
		end)

		it("reads the arena's tagged markers, and has a drive line pointing at the drivers", function()
			local line = Match.driveLine()
			expect(line).to.be.ok()
			-- The direction is the difference between the safety rule firing on the right shots and
			-- on exactly the wrong ones, and since 1.7b it really does fire on them.
			expect(line.normal.Z > 0.99).to.equal(true)

			local markers = Markers.read()
			expect(markers.complete).to.equal(true)
			expect(#markers.posts).to.equal(8)
			expect(#markers.boarSpawns).to.equal(4)
		end)

		it("publishes a snapshot that is frozen all the way down", function()
			local snapshot = Match.snapshot()
			expect(snapshot).to.be.ok()
			expect(type(snapshot.phase)).to.equal("string")
			expect(type(snapshot.driveNumber)).to.equal("number")
			expect(type(snapshot.rows)).to.equal("table")
			expect(function()
				(snapshot :: any).phase = "Running"
			end).to.throw()
			expect(#snapshot.rows >= 1).to.equal(true) -- PlayerAdded made one, so this cannot vanish
			expect(function()
				snapshot.rows[1].points = 999
			end).to.throw()
		end)

		it("keys everything by userId, and holds one entry for one player", function()
			expect(Match.trackedPlayers()).to.equal(#Players:GetPlayers())
		end)

		it("connected the boar's kill signal, so kills can score at all", function()
			-- A missing dependency is a number in the harness report, not a match that silently
			-- scores zero (design section 7.4).
			expect(Match.stats().killSignalMissing).to.equal(0)
		end)

		it("connected the weapon's safety signal, so the penalty can fire at all", function()
			-- 1.7b's version of the check above, and the same reasoning: a safety rule that is on in
			-- the config and wired to nothing is worse than one that is off.
			expect(Match.CONFIG.SAFETY_ENABLED).to.equal(true)
			expect(Match.stats().safetySignalMissing).to.equal(0)
			expect(typeof(Weapon.SafetyViolated)).to.equal("RBXScriptSignal")
			-- Nobody is tied unless somebody earned it, and nothing in this suite shoots at a driver.
			for _, player in ipairs(Players:GetPlayers()) do
				local tiedNow = Match.isTied(player.UserId)
				if tiedNow then
					-- Not a failure: the two-player client spec ties the shooter on purpose. But a tie
					-- must always agree with the gun.
					expect(Match.mayCarryWeapon(player)).to.equal(false)
				end
			end
		end)

		it("raised the boar's own guard, because carcasses occupy slots for two minutes", function()
			expect(Boar.CONFIG.maxBoars).to.equal(8)
			expect(Match.CONFIG.MAX_ALIVE_BOARS <= Boar.CONFIG.maxBoars).to.equal(true)
		end)
	end)

	describe("the drive's own numbers", function()
		it("are the ones the design fixed, and the 1.7b switches are off", function()
			expect(Match.CONFIG.DRIVE_SECONDS).to.equal(600)
			expect(Match.CONFIG.INTERMISSION_SECONDS).to.equal(20)
			expect(Match.CONFIG.BOARS_PER_DRIVE).to.equal(6)
			expect(Match.CONFIG.DRIVERS_MAY_SHOOT).to.equal(false)
			expect(Match.CONFIG.SAFETY_ENABLED).to.equal(true) -- 1.7b: the penalty is live
			expect(Match.CONFIG.TIE_UNTIL_DRIVE_END).to.equal(true) -- Karen's rule as written
			expect(Match.CONFIG.END_ON_LAST_BOAR).to.equal(false)
		end)

		it("is frozen, so nothing can retune the drive at run time", function()
			expect(function()
				(Match.CONFIG :: any).DRIVE_SECONDS = 1
			end).to.throw()
			expect(function()
				(Match.CONFIG :: any).POINTS.KILL.head = 1
			end).to.throw()
		end)
	end)

	describe("the boar runtime's new clear", function()
		-- The drive may not touch a boar Instance, so "remove every boar at the end of a drive" is a
		-- request to the boar's own owner. Tested on a runtime of this spec's own, at y = 700, so
		-- production's drive is untouched.
		it("removes every boar through the same despawn path, and reports it", function()
			local root = Instance.new("Folder")
			root.Name = "MatchLiveSpec"
			local plate = Instance.new("Part")
			plate.Name = "Plate"
			plate.Size = Vector3.new(120, 4, 120)
			plate.Position = Vector3.new(0, 698, 0)
			plate.Anchored = true
			plate.Parent = root
			root.Parent = workspace

			local runtime = Boar.newRuntime({
				field = { bounds = { minX = -50, maxX = 50, minZ = -50, maxZ = 50 }, exitZ = -40, groundY = 700 },
				parent = root,
				folderName = "Boars",
				rng = Random.new(3),
				threats = function()
					return {}
				end,
				probe = function()
					return false
				end,
				requestPath = function(_id, _from, _to, done)
					done(nil)
				end,
				releasePath = function() end,
			})
			local despawns = {}
			runtime.Despawned:Connect(function(record)
				table.insert(despawns, record)
			end)

			runtime:spawn(Vector3.new(0, 700, 10))
			runtime:spawn(Vector3.new(10, 700, 10))
			expect(#runtime:boars()).to.equal(2)

			runtime:clear("driveOver")
			expect(#runtime:boars()).to.equal(0)
			expect(waitUntil(2, function()
				return #despawns == 2
			end)).to.equal(true)
			expect(despawns[1].reason).to.equal("driveOver")
			expect(runtime:stats().despawned).to.equal(2)

			runtime:destroy()
			root:Destroy()
		end)
	end)
	-- THE CROSS-SYSTEM INVARIANTS (design section 12.4 items 11-13). Three numbers in two owners
	-- have to agree, and the reason this is one `it` is that raising any of them alone is the
	-- failure: "Karen raised the budget to 10" must fail a spec here rather than stall a drive at
	-- run time.
	describe("the drive and the boar runtime agree about how many", function()
		it("keeps the budget, the ceiling and the runtime's capacity in order", function()
			local drive = Match.CONFIG
			expect(drive.BOARS_PER_DRIVE <= Boar.CONFIG.maxBoars).to.equal(true)
			-- A sounder may be MAX_SIZE, so a ceiling below it makes that release PERMANENTLY
			-- impossible and the retry loop stalls the drive. This is the invariant, not a
			-- coincidence of two numbers (Director decision H).
			expect(drive.MAX_ALIVE_BOARS >= drive.SOUNDER.MAX_SIZE).to.equal(true)
			expect(drive.MAX_ALIVE_BOARS <= Boar.CONFIG.maxBoars).to.equal(true)
			-- ...and the ring the boar spreads a sounder on fits inside the flat ground the MAP
			-- guarantees, because Runtime:spawn overwrites the caller's Y.
			local ring = Boar.CONFIG.SOUNDER
			expect(ring.SPAWN_RING_STUDS + ring.PAD_MARGIN_STUDS <= Map.SPAWN_PAD.radius).to.equal(true)
		end)

		it("reads the flag once, at the boundary, and it is OFF on a clean run", function()
			expect(Match.CONFIG.SOUNDER.ENABLED).to.equal(Flags.isOn("BOAR_SOUNDERS"))
			-- A harness PASS can never have been produced with the dark path live: `test` refuses to
			-- start while an override is set, and this is the same fact asserted from inside.
			expect(Match.CONFIG.SOUNDER.ENABLED).to.equal(false)
		end)

		it("asks the runtime what it holds, and the drive is not stalling", function()
			-- THE PRODUCTION RUNTIME IS NOT REACHABLE FROM A SPEC: MatchBoot holds it in a local and
			-- hands it to Match.start, which is the whole point of that composition root -- so the
			-- INTERFACE is asserted on a runtime of this spec's own (the same constructor
			-- production uses), and the OWNER's half is asserted through Match.stats().
			local runtime = Boar.newRuntime({
				field = Boar.CONFIG.field,
				parent = Instance.new("Folder"),
				folderName = "CapacityProbe",
				threats = function()
					return {}
				end,
			})
			expect(type(runtime.capacity)).to.equal("function")
			expect(type(runtime.count)).to.equal("function")
			expect(type(runtime.spawnSounder)).to.equal("function")
			expect(runtime:capacity()).to.equal(Boar.CONFIG.maxBoars)
			expect(runtime:count()).to.equal(0)
			runtime:destroy()

			-- The owner fills boarEntries/boarCapacity on every dispatch, and the drive has been
			-- running through this whole session: nothing can have been held back on an empty field.
			local stats = Match.stats()
			expect(type(stats.sounderHoldbacks)).to.equal("number")
			expect(type(stats.soundersReleased)).to.equal("number")
			expect(type(stats.boarsReleased)).to.equal("number")
			expect(stats.sounderHoldbacks).to.equal(0)
			TestKit.note(
				string.format(
					"drive: %d sounder(s), %d boar(s) released, %d holdback(s), max alive %d, budget %d",
					stats.soundersReleased,
					stats.boarsReleased,
					stats.sounderHoldbacks,
					Match.CONFIG.MAX_ALIVE_BOARS,
					Match.CONFIG.BOARS_PER_DRIVE
				)
			)
		end)
	end)
end
