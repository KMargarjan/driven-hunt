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
-- ONE FACT, FOR ONE QUESTION: has the build that just ran a drive got money in it? (task 233)
-- `Economy.isEnabled` is the owner's own boundary read of `COINS`, which is a v1 default from
-- 2026-10-21, so the two economy fields on the live snapshot are asked of it rather than pinned.
local Economy = require(ServerScriptService:WaitForChild("Economy"))
local Flags = require(game:GetService("ReplicatedStorage"):WaitForChild("Flags"))
local Map = require(game:GetService("ReplicatedStorage"):WaitForChild("Map"))
local Match = require(ServerScriptService:WaitForChild("Match"))
local TestKit = require(game:GetService("ReplicatedStorage"):WaitForChild("TestKit"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
-- One fact, for one question: is the Tool in this player's hands a GUN? (task 152)
local Weapons = require(game:GetService("ReplicatedStorage"):WaitForChild("Weapons"))
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
				-- A GUN, NOT JUST A TOOL (task 152). The beater's horn is a `Tool` too, and a DRIVER
				-- -- the player who must NOT be armed -- is exactly the one who carries one.
				local function holdsGun(): boolean
					for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
						for _, child in ipairs(if container then container:GetChildren() else {}) do
							if Weapons.isWeaponTool(child) then
								return true
							end
						end
					end
					return false
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
						"match_live: %s (%s) may carry=%s holds=%s | weapon granted=%d grantsMissed=%d revoked=%d"
							.. " | equip now=%d late=%d deferred=%d noChar=%d gaveUp=%d",
						player.Name,
						player.Team.Name,
						tostring(expected),
						tostring(holdsGun()),
						stats.granted,
						stats.grantsMissed,
						stats.revoked,
						stats.equipNow,
						stats.equipLate,
						stats.equipDeferred,
						stats.equipNoCharacter,
						stats.equipGaveUp
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

		-- TASK 221, the Reviewer's round-1 finding 2: `roleOverruled` is DERIVED from the live
		-- assignment and is ABSENT when there is no economy view -- the `stands` / `coinsOn` idiom
		-- (*"ABSENT means the server never sent it"*). The harness runs with no economy, so this is
		-- the flag-off half of the field, asserted against the real running drive.
		it("ships roleOverruled and coinsOn exactly as the running build's money switch says", function()
			local snapshot = Match.snapshot()
			expect(snapshot).to.be.ok()
			-- BOTH HALVES, READ OFF THE BUILD (task 233). `COINS` became a v1 default on 2026-10-21,
			-- so the drive that just ran in the DEV place HAS an economy -- which is the opposite of
			-- what this case was written against, and it failed on both lines in the flip's own gate
			-- run (`coinsOn` got `true` for `nil`). It is asked of `Economy.isEnabled()` rather than
			-- pinned to either answer, exactly as `zz_drive_boundary.spec`'s own `roleOverruled`
			-- case already asks, because a harness run may set no `DHFlag_` override at all: the one
			-- branch it can take is the DECLARED default, and both are written out so that flipping
			-- the row back is still measured here and not silently unasserted.
			if Economy.isEnabled() then
				expect(snapshot.coinsOn).to.equal(true)
				-- PRESENT AND EMPTY. There is no lodge in the DEV place, so nobody can have bought
				-- the hunter's place and nobody can have been overruled -- but the field is sent,
				-- because the build has money in it.
				expect(snapshot.roleOverruled).to.be.ok()
				expect(#snapshot.roleOverruled).to.equal(0)
			else
				-- ABSENT, not an empty array: a client that never heard of the field reads exactly
				-- what it always did, and `Match.isRoleOverruled` answers false off `or {}`.
				expect(snapshot.roleOverruled).to.equal(nil)
				-- ...and the two fields it copies that idiom from behave the same way here.
				expect(snapshot.coinsOn).to.equal(nil)
			end
			-- TASK 229, review round 1 finding 1: the record `roleOverruled` is now computed
			-- AGAINST -- the wishes the assignment was actually made with, rather than the live memo
			-- the assignment itself empties. On the real running drive in the DEV place there is no
			-- lobby, so nothing can ever be in it, and a COPY is what this owner hands out.
			local seated = Match.seatedWishes()
			expect(seated).to.be.ok()
			expect(next(seated)).to.equal(nil)
			expect(Match.seatedWishes()).never.to.equal(seated)
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
			-- 20 -> 10 (task 158) -> 15 (task 163) -> 5 (task 249). Karen named 10 and then, after
			-- playing it, named 15: *"for hunter a bit more time like 15s to find a place"*; on
			-- 2026-10-23 she named the whole gap instead (*"a bit to long to wait for game we need
			-- to reduce seconds"*) and the Director set that gap at 15 seconds for all three
			-- phases. It is the start card's life, the hunter's stand timer and the beaters' hold,
			-- which are one deadline.
			-- backups/2026-10-11_task158_intermission_20s.txt,
			-- backups/2026-10-12_task163_intermission_10s.txt,
			-- backups/2026-10-23_task249_between-drive-gap-31s.txt.
			expect(Match.CONFIG.INTERMISSION_SECONDS).to.equal(5)
			-- ...AND THE WAIT ON THE OTHER SIDE OF A DRIVE (task 209). Karen, 2026-10-18: *"time for
			-- next rount is to long make 8s max"*. This is the number she was reading: the results
			-- panel's footer says `NEXT DRIVE IN n` and counts THIS down, and it was 25 -- measured
			-- at 25.22 s on her own path in the live Forest Test before a line was changed. The
			-- `<=` and not an `==` is the rule she gave ("8s max"), so a later tune down cannot
			-- quietly fail a spec that only pins a number.
			expect(Match.CONFIG.SCORE_SECONDS <= 8).to.equal(true)
			expect(Match.CONFIG.SCORE_SECONDS).to.equal(4)
			-- TASK 163: the drive signals, and the drive it is signalling is this one.
			expect(Match.CONFIG.SIGNAL_ENABLED).to.equal(true)
			expect(Match.CONFIG.BOARS_PER_DRIVE).to.equal(6)
			expect(Match.CONFIG.DRIVERS_MAY_SHOOT).to.equal(false)
			expect(Match.CONFIG.SAFETY_ENABLED).to.equal(true) -- 1.7b: the penalty is live
			expect(Match.CONFIG.TIE_UNTIL_DRIVE_END).to.equal(true) -- Karen's rule as written
			expect(Match.CONFIG.END_ON_LAST_BOAR).to.equal(false)
		end)

		-- ---------------------------------------- the whole gap between two drives (task 249)
		--
		-- KAREN, 2026-10-23: *"a bit to long to wait for game we need to reduce seconds"*. The gap
		-- is THREE phases in two modules and no single row says how long it is, which is how it
		-- reached 31 seconds without anybody choosing 31. This case is that sum, written down:
		-- cut any one of the three and the total moves, and this is the assertion that notices.
		it("is 15 seconds from the end of one drive to the start of the next (task 249)", function()
			local Lobby = require(game:GetService("ReplicatedStorage"):WaitForChild("Lobby"))
			local results = Match.CONFIG.SCORE_SECONDS
			local card = Lobby.CONFIG.PADS.NEXT.SECONDS
			local walk = Match.CONFIG.INTERMISSION_SECONDS
			expect(results).to.equal(4)
			expect(card).to.equal(6)
			expect(walk).to.equal(5)
			expect(results + card + walk).to.equal(15)
			-- ...AND THE CARD KEEPS THE BIGGEST SHARE, which is the Director's *"keep the role
			-- choice usable"*: `T` swaps hunter for beater and `Y` sits the drive out, and both
			-- are bound only while that card is up.
			expect(card > results).to.equal(true)
			expect(card > walk).to.equal(true)
		end)

		it("are the table the LIVE drive is running on, by identity (task 157)", function()
			-- THE WHOLE PROOF THAT THE DEV DRIVE DID NOT CHANGE when the Forest Test gained one.
			-- `Match.start` merges `world.config` over the defaults, and `MatchBoot` -- the boot that
			-- ran in this place -- passes none, so `mergeConfig` returns the defaults THEMSELVES.
			-- One assertion covers every number, because there is only one table.
			expect(Match.config()).to.equal(Match.CONFIG)
		end)

		it("is frozen, so nothing can retune the drive at run time", function()
			expect(function()
				(Match.CONFIG :: any).DRIVE_SECONDS = 1
			end).to.throw()
			expect(function()
				(Match.CONFIG :: any).POINTS.KIND.male = 1
			end).to.throw()
		end)
	end)

	-- THE START OF A DRIVE, IN THE DRIVE THAT IS RUNNING NOW (task 158). The pure half -- who is held
	-- and when -- is `match_phase.spec`; this is the half that only production can answer: the wire
	-- really carries the quarry, and the owner really holds nobody once the drive is live.
	describe("the start of a drive", function()
		it("puts what may be shot on the wire, as the rows the card draws", function()
			local snapshot = Match.snapshot()
			expect(type(snapshot.quarry)).to.equal("table")
			expect(#snapshot.quarry > 0).to.equal(true)
			-- THE SERVER'S RULE, NOT A SECOND COPY: the snapshot's rows are `Match.quarryRows` of
			-- the config this drive is running on, kind for kind and price for price.
			local expected = Match.quarryRows(Match.config())
			expect(#snapshot.quarry).to.equal(#expected)
			local drawn = {}
			for index, row in ipairs(expected) do
				expect(snapshot.quarry[index].species).to.equal(row.species)
				expect(snapshot.quarry[index].kind).to.equal(row.kind)
				expect(snapshot.quarry[index].points).to.equal(row.points)
				table.insert(drawn, string.format("%s=%s", row.kind, tostring(row.points)))
			end
			-- ...AND WHAT SHOOTING A PERSON COSTS, which is the card's fourth row (201 part 3).
			expect(snapshot.safetyPenalty).to.equal(Match.config().POINTS.SAFETY_PENALTY)
			-- ...and it is frozen all the way down, like every other field on it.
			expect(table.isfrozen(snapshot.quarry)).to.equal(true)
			expect(table.isfrozen(snapshot.quarry[1])).to.equal(true)
			TestKit.note("match-live: the start card reads -> " .. table.concat(drawn, " | "))
		end)

		it("holds nobody once the drive is live, and every frozen player is frozen BY THE TIE", function()
			-- THE CLAIM: the hold is `Assigning` only, `Phase.enterRunning` always emits `free`, and
			-- by the time the drive is running nobody is held -- which is what a stuck hold would
			-- break for Karen, and what no pure spec can see.
			--
			-- THE DRIVE HAS TWO FREEZES AND THIS ACCOUNTS FOR BOTH, which is what round 1's own
			-- version got wrong: it asserted `WalkSpeed > 0` for EVERY player, and in the TWO-PLAYER
			-- run `zz_tie_to_a_tree` ties a shooter to a tree on purpose -- so a player the game had
			-- deliberately frozen, by the rule Karen asked for, failed a case about the hold
			-- (`[harness2] FAIL 33/35 @ 8f9f340`, `match_live.spec:273`; `match_teams` and
			-- `zz_drive_boundary` both noted `1 tied` in the same run, and `weapon_client` noted
			-- "this shooter is tied to a tree"). The hold itself was released for both players:
			-- `Match.isHeld` was false for everybody, which is the line above the one that failed.
			--
			-- So every player is now asserted on BOTH properties, each against its own rule -- the
			-- tie must really hold a tied player, and nothing must hold anybody else. That is
			-- strictly more than the old version checked, and it is what the two freezes mean.
			expect(waitUntil(25, function()
				return Match.phase() == "Running"
			end)).to.equal(true)
			local report = {}
			for _, player in ipairs(Players:GetPlayers()) do
				local held = Match.isHeld(player.UserId)
				local tied = Match.isTied(player.UserId)
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local root = character and character.PrimaryPart
				-- NAMED BEFORE IT IS ASSERTED, so a failure says which mechanism did it rather than
				-- leaving the next reader to guess between the hold, the tie and a respawn.
				table.insert(
					report,
					string.format(
						"%s(%s) held=%s tied=%s ws=%s anchored=%s",
						player.Name,
						tostring(Match.Body.teamOf(player)),
						tostring(held),
						tostring(tied),
						tostring(humanoid and humanoid.WalkSpeed),
						tostring(root and root.Anchored)
					)
				)
				-- THE HOLD IS OFF EVERYBODY. No exception, tied or not: a tie is not a hold.
				expect(held).to.equal(false)
				if humanoid then
					if tied then
						-- The safety rule's own freeze, and it must really be holding him: a tie
						-- that left him walking would be the penalty not happening.
						expect(humanoid.WalkSpeed).to.equal(0)
						if root then
							expect(root.Anchored).to.equal(true)
						end
					else
						-- The belt and the braces the hold writes, both back where they started.
						expect(humanoid.WalkSpeed > 0).to.equal(true)
						if root then
							expect(root.Anchored).to.equal(false)
						end
					end
				end
			end
			TestKit.note("match-live: in the drive -> " .. table.concat(report, " | "))
			TestKit.note(
				string.format(
					"match-live: holds=%d reapplied=%d walkSpeedsRescued=%d",
					Match.stats().holds,
					Match.stats().holdsReapplied,
					Match.Body.rescued()
				)
			)
			-- `walkSpeedsRescued` IS A DIAGNOSTIC HERE AND NOT AN ASSERTION, and the reason is worth
			-- stating: `Body.untieCharacter` refuses to hand back a WalkSpeed of 0, so a rescue
			-- leaves the player WALKING -- which is exactly what this case already checks, and
			-- therefore something it cannot see. The number is printed so a human reading the run
			-- would notice it move; what PROVES the floor is `match_safety.spec`, where the only
			-- route to a saved zero is forced on a fixture and the counter is asserted by delta.
		end)

		it("names the beaters as the side held at the line, and does not let a world change it", function()
			expect(Match.CONFIG.START_HOLD_TEAM).to.equal("Drivers")
			-- NOT OVERRIDABLE: "who is held at the start of a drive" is one answer in the world Karen
			-- plays, exactly like the safety numbers (docs/design/drive.md section 3.4).
			expect(Match.WORLD_OVERRIDABLE.START_HOLD_TEAM).to.equal(nil)
			expect(Match.WORLD_OVERRIDABLE.QUARRY).to.equal(nil)
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
			-- THE QUICK TEST'S OWN RELEASE IS SUBJECT TO THE SAME CEILING (task 83): `maybeRelease`
			-- holds the WHOLE sounder back when it does not fit, so a quick release bigger than the
			-- ceiling would stall the drive it is supposed to shorten -- for ever, on a retry loop.
			-- The first run of `match_phase.spec`'s quick-test block failed exactly that way against
			-- its own small ceiling, which is why it is an invariant here and not a comment there.
			expect(drive.MAX_ALIVE_BOARS >= drive.QUICK_TEST_SOUNDER).to.equal(true)
			expect(drive.MAX_ALIVE_BOARS <= Boar.CONFIG.maxBoars).to.equal(true)
			-- ...and the ring the boar spreads a sounder on fits inside the flat ground the MAP
			-- guarantees, because Runtime:spawn overwrites the caller's Y.
			local ring = Boar.CONFIG.SOUNDER
			expect(ring.SPAWN_RING_STUDS + ring.PAD_MARGIN_STUDS <= Map.SPAWN_PAD.radius).to.equal(true)
		end)

		it("never runs the quick test on a clean run, and cannot run it outside Studio", function()
			-- TASK 83, AND THE STUDIO GUARD IS THE HALF THAT MATTERS. `QUICK_TEST` is the only flag
			-- whose value is ANDed with `RunService:IsStudio()` at its boundary, so a live server
			-- cannot run it however the attribute got there. The guard is a pure function, which is
			-- what lets this assert the case a Studio spec can never reach: not Studio.
			expect(Match.quickTestEnabled(true, false)).to.equal(false)
			expect(Match.quickTestEnabled(false, true)).to.equal(false)
			expect(Match.quickTestEnabled(false, false)).to.equal(false)
			-- ...and it IS enabled when both halves say so, or the case above would pass on a
			-- function that always answers false.
			expect(Match.quickTestEnabled(true, true)).to.equal(true)

			-- The live value: `test` refuses to start while an override is set, so a harness PASS is
			-- always the reviewed default -- which is off.
			expect(Match.CONFIG.QUICK_TEST).to.equal(Match.quickTestEnabled(Flags.isOn("QUICK_TEST"), true))
			expect(Match.CONFIG.QUICK_TEST).to.equal(false)
			expect(Flags.DEFAULTS.QUICK_TEST.default).to.equal(false)

			-- AND NO PHANTOM DRIVER EXISTS. The quick test pushes its sounder by telling the boar
			-- world a driver is standing behind it; with the flag off there is never one, and every
			-- threat the boars are given is a real player keyed by a real userId.
			expect(Match.quickTestPhantom(os.clock())).to.equal(nil)
			-- AND THE SPAWN IS IN FRONT OF A POST, not at the corridor's centre. The line marker is
			-- 1,240 studs wide and the posts span 1,120 of it, so a sounder at the line's own
			-- Position can be 560 studs from the only shooter -- which is what the first quick-test
			-- screenshot showed: nothing, twice. Driven by parameter, because the live config has
			-- the flag off.
			local quickConfig = table.clone(Match.CONFIG) :: any
			quickConfig.QUICK_TEST = true
			local line = { position = Vector3.new(0, 0, -700), normal = Vector3.new(0, 0, 1) }
			local post = Instance.new("Part")
			post.Position = Vector3.new(-560, 3, -700)
			local at = Match.quickSpawnFor(line, { post }, quickConfig)
			expect(at).to.be.ok()
			expect((at :: Vector3).X).to.equal(-560 + quickConfig.QUICK_TEST_SIDE_STUDS)
			expect((at :: Vector3).Z).to.equal(-700 + quickConfig.QUICK_TEST_AHEAD_STUDS)
			-- ...and with the flag off there is no spawn at all, whatever the markers say
			expect(Match.quickSpawnFor(line, { post }, Match.CONFIG)).to.equal(nil)
			post:Destroy()

			-- THE PHANTOM MUST NOT REACH ANYTHING THAT MEANS A PERSON, and this is the defect that
			-- taught it: push credit is keyed BY USER ID, and `credit[tonumber("quick-test")] = at`
			-- is `credit[nil] = at` -- "table index is nil", on every step of every quick-test
			-- session, taking the rest of the drive's step with it. The console found it; the
			-- harness never could, because the flag is off here. `Match.playerDrivers` is the one
			-- filter both the safety rule and push credit now go through.
			local mixed = {
				{ id = "12345", position = Vector3.new(1, 0, 2) },
				{ id = "quick-test", position = Vector3.new(3, 0, 4) },
			}
			local people = Match.playerDrivers(mixed)
			expect(#people).to.equal(1)
			expect(people[1].userId).to.equal(12345)
			expect(people[1].position).to.equal(Vector3.new(1, 0, 2))
			expect(#Match.playerDrivers({})).to.equal(0)

			-- ...AND THE SAME RULE AT THE HORN'S DOOR (task 160). Karen asked for a beater ranking,
			-- so a blast now credits the man who blew it for the animals it pushed -- and a phantom
			-- beater (the quick test's, the forest's wave) must earn nothing by construction, not by
			-- a filter somebody remembers to apply. `Match.pushCreditable` is pure, so both branches
			-- are one line each with no drive running.
			expect(Match.pushCreditable(12345, "Drivers", true)).to.equal(true)
			expect(Match.pushCreditable(12345, "Shooters", true)).to.equal(false) -- a hunter is not a beater
			expect(Match.pushCreditable(12345, "Drivers", false)).to.equal(false) -- no live drive to score in
			expect(Match.pushCreditable(12345, nil, true)).to.equal(false) -- not in this drive at all
			expect(Match.pushCreditable(nil, "Drivers", true)).to.equal(false) -- the phantom: no userId
			expect(Match.pushCreditable("quick-test", "Drivers", true)).to.equal(false)
			-- ...and the real owner, in this place, refuses every one of them: nothing is credited.
			expect(Match.creditPush(nil, { "Boar1" })).to.equal(0)
			expect(Match.creditPush("quick-test" :: any, { "Boar1" })).to.equal(0)
			local before = Match.stats().hornCredits
			expect(Match.creditPush(12345678, { "Boar1" })).to.equal(0) -- nobody by that id is driving here
			expect(Match.stats().hornCredits).to.equal(before)

			-- ...AND THE WRITE ITSELF, WHICH NO REFUSAL CAN REACH (round 1 finding 1). Every
			-- assertion above is a `== 0`, so they are all satisfied by a `creditPush` that does
			-- nothing at all. `Match.writePushCredit` is the loop `creditPush` runs once it has
			-- decided to pay, and `Match.pushCreditWithin` is the read `onDowned` hands to
			-- `Score.kill` -- both pure, both driven here with their own table and no drive, so
			-- deleting the write fails this case.
			local credits = {}
			expect(Match.writePushCredit(credits, 42, { "A", "B", 7, false :: any }, 100)).to.equal(2)
			expect(credits.A[42]).to.equal(100)
			expect(credits.B[42]).to.equal(100)
			expect(credits[7]).to.equal(nil) -- a non-string id is SKIPPED, never `credits[nil]`
			-- A SECOND BLAST AT THE SAME ANIMAL REFRESHES THE TIMESTAMP AND ADDS NO CREDIT (round 1,
			-- note 4): the write is idempotent, so the tally `stats().hornCredits` keeps must be too.
			expect(Match.writePushCredit(credits, 42, { "A" }, 140)).to.equal(0)
			expect(credits.A[42]).to.equal(140)
			-- ...and a second BEATER on the same animal is a second credit.
			expect(Match.writePushCredit(credits, 43, { "A" }, 150)).to.equal(1)
			expect(Match.writePushCredit(credits, 42, nil, 160)).to.equal(0)

			-- THE READ, with the window the drive uses: inside it pays, outside it does not, and an
			-- animal nobody pushed answers an empty table rather than nil.
			local window = Match.CONFIG.POINTS.PUSH_WINDOW
			local inWindow = Match.pushCreditWithin(credits, "A", 150 + window, window)
			expect(inWindow[43]).to.equal(150)
			expect(inWindow[42]).to.equal(nil) -- 140 is older than the window at this instant
			expect(next(Match.pushCreditWithin(credits, "A", 150 + window + 1, window))).to.equal(nil)
			expect(next(Match.pushCreditWithin(credits, "nobody", 150, window))).to.equal(nil)
			expect(next(Match.pushCreditWithin(credits, nil, 150, window))).to.equal(nil)
			local threats = Match.driverThreats()
			for _, threat in ipairs(threats) do
				expect(tonumber(threat.id)).never.to.equal(nil)
			end
			TestKit.note(
				string.format(
					"task83: QUICK_TEST=%s, %d threat(s), all real players",
					tostring(Match.CONFIG.QUICK_TEST),
					#threats
				)
			)
		end)

		it("tells the boar what KIND each person is, and gives the phantom a driver's", function()
			-- TASK 120, taking 118a(a). `MatchBoot` routes production's whole stimulus list through
			-- `Match.boarThreats` -> `Body.boarStimuli`, and the ONE line that keeps the flag-OFF
			-- world intact is the ternary that tags a shooter `"shooter"` and not `"driver"`: with
			-- `BOAR_BEHAVIOUR` off the Brain drops every stimulus that is not a driver, so if that
			-- ternary ever said "driver" a man on a post would flush boars at 40 studs in the game
			-- that shipped. Nothing asserted it.
			-- FOUR PEOPLE, EACH WITH A BODY, so the ternary is actually reached (review round 1,
			-- finding 2: a cast with no Character asserted nothing but `#stimuli == 0`).
			local function person(userId: number, hasBody: boolean)
				if not hasBody then
					return { UserId = userId, Character = nil }
				end
				local character = Instance.new("Model")
				character.Name = "Body" .. tostring(userId)
				local root = Instance.new("Part")
				root.Name = "HumanoidRootPart"
				root.Anchored = true
				root.Position = Vector3.new(userId, 5, userId)
				root.Parent = character
				character.PrimaryPart = root
				return { UserId = userId, Character = character }
			end

			local people = {
				person(11, true), -- Shooters, with a body
				person(12, true), -- Drivers, with a body
				person(13, true), -- on no team at all
				person(14, false), -- Shooters, but nothing drawn yet
			}
			local teams = { [11] = "Shooters", [12] = "Drivers", [13] = "Spectators" }
			local stimuli = Match.Body.boarStimuli(function(player)
				return teams[player.UserId]
			end, {
				GetPlayers = function()
					return people
				end,
			})

			-- THE TERNARY, BOTH WAYS. A shooter is tagged "shooter" and NOT "driver": with
			-- `BOAR_BEHAVIOUR` off the Brain drops every stimulus that is not a driver, so one
			-- wrong branch here would have a man on a post flushing boars at 40 studs in the game
			-- that shipped.
			local byId = {}
			for _, stimulus in ipairs(stimuli) do
				byId[stimulus.id] = stimulus
			end
			expect(#stimuli).to.equal(2)
			expect(byId["11"]).to.be.ok()
			expect(byId["11"].kind).to.equal("shooter")
			expect(byId["11"].position).to.equal(Vector3.new(11, 5, 11))
			expect(byId["12"]).to.be.ok()
			expect(byId["12"].kind).to.equal("driver")
			expect(byId["12"].position).to.equal(Vector3.new(12, 5, 12))
			-- A TEAM THAT IS NEITHER IS NOT A STIMULUS AT ALL, which is what keeps a spectator out
			-- of the list -- and a player with no body is not one either, because a stimulus needs
			-- a position.
			expect(byId["13"]).to.equal(nil)
			expect(byId["14"]).to.equal(nil)
			for _, player in ipairs(people) do
				if player.Character then
					player.Character:Destroy()
				end
			end

			-- AND THE PHANTOM, ASKED DIRECTLY rather than hoped for in a list that can be empty
			-- (review round 1, finding 2). `Match.quickTestPhantom` answers a POSITION or nil, and
			-- it is `Match.boarThreats` that dresses it -- so this asserts BOTH states: when the
			-- quick test is pushing, the published list carries that exact phantom as a DRIVER with
			-- a non-numeric id (which is what keeps it out of `Match.playerDrivers`, task 83's own
			-- defect, `credit[nil] = at`); when it is not, the list carries no phantom at all.
			local phantomAt = Match.quickTestPhantom(os.clock())
			local live = Match.boarThreats()
			local phantom = nil
			for _, threat in ipairs(live) do
				expect(threat.kind == "driver" or threat.kind == "shooter").to.equal(true)
				expect(typeof(threat.position)).to.equal("Vector3")
				if threat.id == "quick-test" then
					phantom = threat
				end
			end
			if phantomAt then
				expect(phantom).to.be.ok()
				expect(phantom.kind).to.equal("driver")
				expect(tonumber(phantom.id)).to.equal(nil)
				expect((phantom.position - phantomAt).Magnitude < 1e-3).to.equal(true)
			else
				expect(phantom).to.equal(nil)
			end
			TestKit.note(
				string.format(
					"task120: boarStimuli tagged %d of 4 people (shooter + driver, spectator and bodiless dropped); "
						.. "phantom=%s; %d live stimulus(es)",
					#stimuli,
					if phantom then phantom.kind .. "/" .. phantom.id else "none",
					#live
				)
			)
		end)

		it("reads the flag once, at the boundary, and it is the REVIEWED value on a clean run", function()
			expect(Match.CONFIG.SOUNDER.ENABLED).to.equal(Flags.isOn("BOAR_SOUNDERS"))
			-- FLIPPED ON IN TASK 82 (Karen's OK, PLAYTEST.md 2026-09-26 and 2026-09-27), so "and it
			-- is OFF" is not the fact any more. The fact that still holds, and the one worth
			-- asserting, is that a harness PASS is produced with the value GIT REVIEWED and not with
			-- an override: `test` refuses to start while one is set, and this is the same thing
			-- asserted from inside the server it started.
			expect(Match.CONFIG.SOUNDER.ENABLED).to.equal(Flags.DEFAULTS.BOAR_SOUNDERS.default)
			expect(Flags.DEFAULTS.BOAR_SOUNDERS.default).to.equal(true)
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

			-- The owner fills boarEntries/boarCapacity on every dispatch, so a release is held back
			-- only when the whole sounder does not fit.
			--
			-- NOT `== 0` ANY MORE, AND TASK 82 IS WHY. With BOAR_SOUNDERS ON by default a release is
			-- a GROUP of up to MAX_SIZE, so `alive + size > MAX_ALIVE_BOARS` is a legitimate thing to
			-- happen on a field the players are not clearing -- and whether it has happened by the
			-- time this spec runs depends on where in the release schedule the run landed. That is
			-- the shape of flake Task 80 spent a whole task on. What must never happen is a drive
			-- that holds back until it warns, and that is what is asserted: the drive is not stuck.
			local stats = Match.stats()
			expect(type(stats.sounderHoldbacks)).to.equal("number")
			expect(type(stats.soundersReleased)).to.equal("number")
			expect(type(stats.boarsReleased)).to.equal("number")
			expect(stats.sounderHoldbacks < Match.CONFIG.SOUNDER.HOLDBACK_WARN).to.equal(true)
			expect(stats.boarsReleased <= Match.CONFIG.BOARS_PER_DRIVE).to.equal(true)
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

	-- ---------------------------------------------------------------- task 177: the lobby's seam
	--
	-- WHAT IS ASSERTED HERE IS THE IDENTITY CLAIM, and it is the important one: a world that injects
	-- no `enrol` -- which is `MatchBoot`, which is the DEV place, which is where the harness runs --
	-- behaves exactly as it did before task 177. The enrol-FALSE branch belongs to the other place:
	-- `lobby_live.spec` drives the lobby against fake doors, and the live `enrol = false` path is
	-- evidenced in the Forest Test session itself, because this singleton cannot be restarted under a
	-- running client suite (the first paragraph of this file says why).
	describe("the drive's own doors (task 177)", function()
		it("still enrols everybody who joins, because this world injects no switch", function()
			local player = Players:GetPlayers()[1]
			expect(player).to.be.ok()
			-- He is a participant, which is the whole of "joining the server joins the drive".
			expect(Match.isParticipant((player :: Player).UserId)).to.equal(true)
			-- ...and the read half answers for somebody this owner has never seen.
			expect(Match.isParticipant(-12345)).to.equal(false)
		end)

		it("is idempotent: enrolling a man who is already in the drive moves nobody", function()
			local player = Players:GetPlayers()[1] :: Player
			local before = Match.assignmentOf(player.UserId)
			local tracked = Match.trackedPlayers()
			-- `Phase.step`'s `join` branch re-assigns to the SMALLER team and re-places inside a live
			-- drive, so a second enrol of a participant would move him mid-drive. The guard is what
			-- makes the lobby's 10 Hz scan safe.
			expect(Match.enrol(player)).to.equal(true)
			expect(Match.assignmentOf(player.UserId)).to.equal(before)
			expect(Match.trackedPlayers()).to.equal(tracked)
		end)

		-- THE THIRD READER (task 287): WOULD A PAD STEP START A FRESH DRIVE FOR HIM? The rule is pure
		-- and is driven at every boundary in `match_phase.spec`; what this asserts is the DOOR, in
		-- the live place, for the ordinary man -- nobody this drive has let go of, so there is nothing
		-- to restart and the lobby's pads are an ordinary door.
		it("says no pad restarts a drive for a man it never let go of (task 287)", function()
			local player = Players:GetPlayers()[1] :: Player
			expect(Match.mayRestart(player.UserId)).to.equal(false)
			expect(Match.mayRestart(-999)).to.equal(false)
			expect(Match.stats().restarts).to.equal(0)
		end)

		it("refuses to enrol somebody it has never registered", function()
			-- Not a `Player`: the door reads `UserId` and `Name`, and refuses rather than half-doing
			-- it -- there would be no board row to put a team on and no character watch to hold.
			local stranger = { UserId = -999, Name = "nobody" } :: any
			expect(Match.enrol(stranger)).to.equal(false)
			expect(Match.isParticipant(-999)).to.equal(false)
		end)

		it("refuses dismissAll in a world that enrols automatically, and empties nothing", function()
			-- In such a world nothing would ever refill the roster and the drive would sit in
			-- `Waiting` for ever. This IS the DEV place, so the refusal is what the harness must see.
			local player = Players:GetPlayers()[1] :: Player
			expect(Match.dismissAll()).to.equal(0)
			expect(Match.isParticipant(player.UserId)).to.equal(true)
			expect(Match.stats().dismissals).to.equal(0)
		end)

		it("never resurrects a departed player as a ghost row on the board", function()
			-- REVIEW ROUND 1, FINDING 1, and the two halves of it are asserted together because one
			-- is the hazard and the other is the guard.
			--
			-- THE HAZARD, in `Score`'s own words: `setTeam` goes through `mutable`, which for a userId
			-- with no row returns `blankRow(userId, name or tostring(userId))`. So asking it to clear
			-- the team of somebody the board has never seen CREATES him -- named by his raw userId,
			-- 0 points, not marked `left` -- and `Score.leaderboard` then puts him on the wire for the
			-- whole of the next drive.
			local Score = Match.Score
			local board = Score.setTeam(Score.new(), -4242, nil)
			local resurrected = false
			for _, row in ipairs(Score.leaderboard(board)) do
				if row.userId == -4242 then
					resurrected = true
					expect(row.name).to.equal("-4242")
					expect(row.points).to.equal(0)
					expect(row.left).never.to.equal(true)
				end
			end
			expect(resurrected).to.equal(true)

			-- THE GUARD: the effect's list outlives the player, because `Phase.enterAssigning` builds
			-- it from `previousAssignment` and the `leave` branch clears `participants` and
			-- `assignment` and not that. `Match.unassignTargets` filters it to the ids this owner
			-- still knows -- `names`, which `Match.forget` clears BEFORE the `leave` it dispatches.
			local known = { [11] = "here", [13] = "also here" }
			local targets = Match.unassignTargets({ 11, 12, 13 }, known)
			expect(#targets).to.equal(2)
			expect(targets[1]).to.equal(11)
			expect(targets[2]).to.equal(13)
			-- The order the effect gave is kept, so the owner's loop is still deterministic.
			expect(#Match.unassignTargets({ 12 }, known)).to.equal(0)
			expect(#Match.unassignTargets(nil, known)).to.equal(0)
			expect(#Match.unassignTargets({}, known)).to.equal(0)

			-- ...and the live player IS known, so an unassign that names him really does reach him.
			local player = Players:GetPlayers()[1] :: Player
			expect(#Match.unassignTargets({ player.UserId }, { [player.UserId] = player.Name })).to.equal(1)
		end)

		it("counts the seam's three numbers", function()
			local stats = Match.stats()
			expect(type(stats.enrolments)).to.equal("number")
			expect(type(stats.dismissals)).to.equal("number")
			expect(type(stats.unassigned)).to.equal("number")
		end)
	end)
end
