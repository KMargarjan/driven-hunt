-- match_phase.spec: the whole match state machine, driven with no players, no boars, no Instances
-- and no clock. Match.Phase is pure and returns (state, effects), so a ten-minute drive -- with
-- joins, leaves, kills and a server hitch -- runs here in milliseconds and every assertion is
-- against a plain table.
--
-- Time is simulated: `now` is a number this spec increments. There is no task.wait in this file.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/drive.md (sections 4, 12.1)
local ServerScriptService = game:GetService("ServerScriptService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Match = require(ServerScriptService:WaitForChild("Match"))
local Phase = Match.Phase
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

-- This spec's own numbers, short enough to read in a failure message.
local CONFIG = {
	DRIVE_SECONDS = 60,
	INTERMISSION_SECONDS = 10,
	SCORE_SECONDS = 5,
	MIN_PLAYERS = 1,
	MAX_PLAYERS = 16,
	ODD_PLAYER_TEAM = "Shooters",
	SWAP_TEAMS_EACH_DRIVE = true,
	START_HOLD_TEAM = "Drivers", -- task 158: the beaters are held at their line for the countdown
	BOARS_PER_DRIVE = 4,
	FIRST_RELEASE_SECONDS = 5,
	RELEASE_INTERVAL_SECONDS = 10,
	RELEASE_JITTER_SECONDS = 0, -- jitter has its own test; every other one wants exact times
	MAX_ALIVE_BOARS = 2,
	SEED = 7,
	-- TASK 163: the drive's horn signal, ON here so this file drives the live shape rather than a
	-- quieter one. Every case that reads the feed therefore has to say WHICH entry it means.
	SIGNAL_ENABLED = true,
}

local SPAWNS = { Vector3.new(-40, 0, 120), Vector3.new(40, 0, 120) }

local function config(overrides)
	local merged = table.clone(CONFIG)
	for key, value in pairs(overrides or {}) do
		merged[key] = value
	end
	return merged
end

local function kinds(effects): { string }
	local out = {}
	for _, effect in ipairs(effects) do
		table.insert(out, effect.kind)
	end
	return out
end

local function countKind(effects, kind: string): number
	local n = 0
	for _, effect in ipairs(effects) do
		if effect.kind == kind then
			n += 1
		end
	end
	return n
end

-- HOW MANY FEED ENTRIES OF ONE KIND (task 163). The feed carries more than lines now -- a `signal`
-- entry is a sound and has no words -- so a case that means "the drive's horn" asks for it by name.
local function countFeed(effects, entryKind: string): number
	local n = 0
	for _, effect in ipairs(effects) do
		if effect.kind == "feed" and effect.entry ~= nil and effect.entry.kind == entryKind then
			n += 1
		end
	end
	return n
end

-- The `text` of the one feed entry of a kind, or nil.
local function feedText(effects, entryKind: string): string?
	for _, effect in ipairs(effects) do
		if effect.kind == "feed" and effect.entry ~= nil and effect.entry.kind == entryKind then
			return effect.entry.text
		end
	end
	return nil
end

-- A state with markers present, so a drive can start at all.
local function ready(cfg)
	local state = Phase.initial(cfg)
	state = (Phase.step(state, { kind = "markers", complete = true, missing = {}, boarSpawns = SPAWNS }, 0, cfg))
	return state
end

-- Steps `seconds` of simulated time in `dt` slices from `at`, collecting every effect.
local function run(state, cfg, at: number, seconds: number, dt: number, aliveBoars: number?)
	local collected = {}
	local elapsed = 0
	while elapsed < seconds do
		elapsed += dt
		local effects
		state, effects = Phase.step(state, { kind = "tick", aliveBoars = aliveBoars or 0 }, at + elapsed, cfg)
		for _, effect in ipairs(effects) do
			table.insert(collected, effect)
		end
	end
	return state, collected, at + elapsed
end

return function()
	describe("waiting", function()
		it("stays Waiting with nobody, for ten simulated minutes", function()
			local cfg = config()
			local state = ready(cfg)
			expect(state.phase).to.equal("Waiting")
			local collected
			state, collected = run(state, cfg, 0, 600, 0.25)
			expect(state.phase).to.equal("Waiting")
			expect(countKind(collected, "assignTeams")).to.equal(0)
		end)

		it("stays Waiting when the markers are incomplete, and says which tag is missing", function()
			local cfg = config()
			local state = Phase.initial(cfg)
			state = (
				Phase.step(state, {
					kind = "markers",
					complete = false,
					missing = { "DrivenHunt.DriveLine (0 found, want 1)" },
					boarSpawns = {},
				}, 0, cfg)
			)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg))
			expect(state.phase).to.equal("Waiting")
			local reasons = Phase.waitingFor(state, cfg)
			expect(#reasons).to.equal(1)
			expect(string.find(reasons[1], "DriveLine") ~= nil).to.equal(true)
		end)

		it("starts the drive on the step that completes the roster, not a tick later", function()
			local cfg = config()
			local state = ready(cfg)
			local effects
			state, effects = Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg)
			expect(state.phase).to.equal("Assigning")
			expect(countKind(effects, "assignTeams")).to.equal(1)
		end)
	end)

	describe("assigning", function()
		it("emits teams, a clear, a placement, arming and one broadcast -- once", function()
			local cfg = config()
			local state = ready(cfg)
			local effects
			state, effects = Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg)
			local list = kinds(effects)
			expect(table.find(list, "assignTeams")).to.be.ok()
			expect(table.find(list, "clearBoars")).to.be.ok()
			expect(table.find(list, "placePlayers")).to.be.ok()
			expect(table.find(list, "refreshArming")).to.be.ok()
			expect(countKind(effects, "assignTeams")).to.equal(1)

			-- ...and not again on the next nine seconds of ticks.
			local later
			state, later = run(state, cfg, 0, cfg.INTERMISSION_SECONDS - 1, 0.25)
			expect(countKind(later, "assignTeams")).to.equal(0)
			expect(state.phase).to.equal("Assigning")
		end)

		it("becomes Running after exactly INTERMISSION_SECONDS", function()
			local cfg = config()
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg))
			local at
			state, _, at = run(state, cfg, 0, cfg.INTERMISSION_SECONDS - 0.5, 0.25)
			expect(state.phase).to.equal("Assigning")
			state = (Phase.step(state, { kind = "tick" }, at + 1, cfg))
			expect(state.phase).to.equal("Running")
		end)
	end)

	describe("the drive", function()
		it("releases exactly BOARS_PER_DRIVE boars, the first after FIRST_RELEASE_SECONDS", function()
			local cfg = config()
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg))
			state = (Phase.step(state, { kind = "tick" }, cfg.INTERMISSION_SECONDS, cfg))
			expect(state.phase).to.equal("Running")

			local collected
			state, collected = run(state, cfg, cfg.INTERMISSION_SECONDS, cfg.DRIVE_SECONDS - 1, 0.25)
			expect(countKind(collected, "spawnSounder")).to.equal(cfg.BOARS_PER_DRIVE)

			-- every release carries one of the tagged spawn positions
			for _, effect in ipairs(collected) do
				if effect.kind == "spawnSounder" then
					expect(effect.position).to.be.ok()
				end
			end
		end)

		it("holds a release back when the runtime is full, and does not lose it", function()
			local cfg = config()
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg))
			state = (Phase.step(state, { kind = "tick" }, cfg.INTERMISSION_SECONDS, cfg))

			-- MAX_ALIVE_BOARS are already out: nothing may be released...
			local blocked
			state, blocked = run(state, cfg, cfg.INTERMISSION_SECONDS, 20, 0.25, cfg.MAX_ALIVE_BOARS)
			expect(countKind(blocked, "spawnSounder")).to.equal(0)

			-- ...and the moment one is gone, the held release happens on the next tick.
			local effects
			state, effects = Phase.step(state, { kind = "tick", aliveBoars = 0 }, cfg.INTERMISSION_SECONDS + 21, cfg)
			expect(countKind(effects, "spawnSounder")).to.equal(1)
		end)

		it("does not lose a release to a JOIN that lands on the release moment", function()
			-- Round 1, finding 1. Only the tick used to carry `aliveBoars`, so a join or a leave at a
			-- release moment read zero, passed the guard, consumed the release and pushed the
			-- schedule on -- and the owner, which had a second guard of its own, then refused the
			-- spawn. The boar was never released and never retried: a six-boar drive quietly ran
			-- five, and the Hud counted one that did not exist. The guard is now one guard, and it
			-- reads the count off WHATEVER event arrives.
			local cfg = config()
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "a" }, 0, cfg))
			state = (Phase.step(state, { kind = "tick", aliveBoars = 0 }, cfg.INTERMISSION_SECONDS, cfg))
			local at = cfg.INTERMISSION_SECONDS + cfg.FIRST_RELEASE_SECONDS + 1

			local effects
			state, effects =
				Phase.step(state, { kind = "join", userId = 2, name = "b", aliveBoars = cfg.MAX_ALIVE_BOARS }, at, cfg)
			expect(countKind(effects, "spawnSounder")).to.equal(0)
			expect(state.boarsReleased).to.equal(0) -- nothing was consumed

			-- ...and the moment there is room, the release that was held back happens.
			state, effects = Phase.step(state, { kind = "tick", aliveBoars = 0 }, at + 0.25, cfg)
			expect(countKind(effects, "spawnSounder")).to.equal(1)
			expect(state.boarsReleased).to.equal(1)
		end)

		it("takes a release back when the runtime refused it after all", function()
			-- The owner's half of the same finding: Runtime:spawn can still assert, and when it does
			-- the release must return to the schedule rather than vanish.
			local cfg = config()
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "a" }, 0, cfg))
			state = (Phase.step(state, { kind = "tick", aliveBoars = 0 }, cfg.INTERMISSION_SECONDS, cfg))
			local at = cfg.INTERMISSION_SECONDS + cfg.FIRST_RELEASE_SECONDS + 1
			local effects
			state, effects = Phase.step(state, { kind = "tick", aliveBoars = 0 }, at, cfg)
			expect(countKind(effects, "spawnSounder")).to.equal(1)
			expect(state.boarsReleased).to.equal(1)

			state = Phase.releaseFailed(state, at, 1)
			expect(state.boarsReleased).to.equal(0)

			-- due again immediately, not one RELEASE_INTERVAL_SECONDS later
			state, effects = Phase.step(state, { kind = "tick", aliveBoars = 0 }, at + 0.25, cfg)
			expect(countKind(effects, "spawnSounder")).to.equal(1)
		end)

		it("ends after exactly DRIVE_SECONDS, freeing everyone and clearing the boars", function()
			local cfg = config()
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg))
			state = (Phase.step(state, { kind = "tick" }, cfg.INTERMISSION_SECONDS, cfg))
			local at = cfg.INTERMISSION_SECONDS + cfg.DRIVE_SECONDS
			local effects
			state, effects = Phase.step(state, { kind = "tick" }, at, cfg)
			expect(state.phase).to.equal("Scoring")
			expect(countKind(effects, "release")).to.equal(1)
			expect(countKind(effects, "clearBoars")).to.equal(1)
		end)

		it("scores nothing and says nothing about a kill outside Running", function()
			local cfg = config()
			local state = ready(cfg) -- still Waiting
			local effects
			state, effects = Phase.step(state, { kind = "kill", userId = 1, record = {} }, 0, cfg)
			expect(countKind(effects, "feed")).to.equal(0)
			expect(state.boarsAccounted).to.equal(0)
		end)

		it("counts a kill inside Running, and the feed says who", function()
			local cfg = config()
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg))
			state = (Phase.step(state, { kind = "tick" }, cfg.INTERMISSION_SECONDS, cfg))
			local effects
			state, effects = Phase.step(state, {
				kind = "kill",
				userId = 1,
				name = "Karen",
				record = { killingZone = "head" },
			}, cfg.INTERMISSION_SECONDS + 1, cfg)
			expect(state.boarsAccounted).to.equal(1)
			expect(countKind(effects, "feed")).to.equal(1)
		end)
	end)

	describe("scoring, and the next drive", function()
		it("goes back to Assigning with players, and to Waiting without", function()
			local cfg = config()
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg))
			state = (Phase.step(state, { kind = "tick" }, cfg.INTERMISSION_SECONDS, cfg))
			local endOfDrive = cfg.INTERMISSION_SECONDS + cfg.DRIVE_SECONDS
			state = (Phase.step(state, { kind = "tick" }, endOfDrive, cfg))
			expect(state.phase).to.equal("Scoring")

			local withPlayers = (Phase.step(state, { kind = "tick" }, endOfDrive + cfg.SCORE_SECONDS, cfg))
			expect(withPlayers.phase).to.equal("Assigning")
			expect(withPlayers.driveNumber).to.equal(2)

			local empty = (Phase.step(state, { kind = "leave", userId = 1 }, endOfDrive + 1, cfg))
			empty = (Phase.step(empty, { kind = "tick" }, endOfDrive + cfg.SCORE_SECONDS, cfg))
			expect(empty.phase).to.equal("Waiting")
		end)

		it("swaps the roles on the next drive", function()
			local cfg = config()
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "a" }, 0, cfg))
			state = (Phase.step(state, { kind = "join", userId = 2, name = "b" }, 0, cfg))
			local first = table.clone(state.assignment)
			state = (Phase.step(state, { kind = "tick" }, cfg.INTERMISSION_SECONDS, cfg))
			local endOfDrive = cfg.INTERMISSION_SECONDS + cfg.DRIVE_SECONDS
			state = (Phase.step(state, { kind = "tick" }, endOfDrive, cfg))
			state = (Phase.step(state, { kind = "tick" }, endOfDrive + cfg.SCORE_SECONDS, cfg))
			expect(state.phase).to.equal("Assigning")
			for userId, team in pairs(first) do
				expect(state.assignment[userId]).never.to.equal(team)
			end
		end)
	end)

	describe("the end of a drive (task 159)", function()
		-- Karen, 2026-10-10: *"Timer or when all beaters cross line of hunters"*. Two endings, one
		-- `Scoring` phase. The GEOMETRY is the owner's (`Match.crossedLine`, driven by
		-- match_scene.spec); what this machine does is compare the two numbers it is handed.
		local function toRunning(cfg)
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "hunter" }, 0, cfg))
			state = (Phase.step(state, { kind = "join", userId = 2, name = "beater" }, 0, cfg))
			state = (Phase.step(state, { kind = "tick" }, cfg.INTERMISSION_SECONDS, cfg))
			expect(state.phase).to.equal("Running")
			return state
		end

		local function indexOf(order, kind)
			for index, name in ipairs(order) do
				if name == kind then
					return index
				end
			end
			return -1
		end

		it("ends on the clock, as it always has, and says so", function()
			local cfg = config({ END_ON_BEATERS_CROSS = true })
			local state = toRunning(cfg)
			local endOfDrive = cfg.INTERMISSION_SECONDS + cfg.DRIVE_SECONDS
			local effects
			state, effects = Phase.step(state, { kind = "tick", beaters = 2, beatersAcross = 0 }, endOfDrive, cfg)
			expect(state.phase).to.equal("Scoring")
			expect(state.endedEarly).to.equal(false)
			-- The feed LINE is the plain one: nothing happened except the clock. Asked of the
			-- `phase` entry by name, because the same effects also carry the drive's horn (task
			-- 163), whose `text` is the word "end" and is never read as a line.
			expect(feedText(effects, "phase")).to.equal("Drive over")
		end)

		it("ends EARLY when every beater is through the line, and names that in the feed", function()
			local cfg = config({ END_ON_BEATERS_CROSS = true })
			local state = toRunning(cfg)
			local at = cfg.INTERMISSION_SECONDS + 5
			-- One of two through is not all of them.
			state = (Phase.step(state, { kind = "tick", beaters = 2, beatersAcross = 1 }, at, cfg))
			expect(state.phase).to.equal("Running")
			local effects
			state, effects = Phase.step(state, { kind = "tick", beaters = 2, beatersAcross = 2 }, at + 1, cfg)
			expect(state.phase).to.equal("Scoring")
			expect(state.endedEarly).to.equal(true)
			-- ...and the scene still gets the whole of SCORE_SECONDS, from the moment it ended.
			expect(state.phaseEndsAt).to.equal(at + 1 + cfg.SCORE_SECONDS)
			local said = false
			for _, effect in ipairs(effects) do
				if effect.kind == "feed" and effect.entry.kind == "phase" then
					said = string.find(effect.entry.text, "beaters", 1, true) ~= nil
				end
			end
			expect(said).to.equal(true)
		end)

		it("needs a REAL beater: with none in the drive only the clock ends it", function()
			-- THE CLAUSE THAT MATTERS. "All of nobody is through" is true in arithmetic, and a solo
			-- hunter -- every DEV harness session, and every session Karen plays alone -- would have
			-- her ten-minute drive end on its first tick.
			local cfg = config({ END_ON_BEATERS_CROSS = true })
			local state = toRunning(cfg)
			local collected
			state, collected = run(state, cfg, cfg.INTERMISSION_SECONDS, cfg.DRIVE_SECONDS - 1, 1)
			expect(state.phase).to.equal("Running")
			expect(countKind(collected, "scene")).to.equal(0)
			expect(Phase.beatersThrough({ kind = "tick", beaters = 0, beatersAcross = 0 }, cfg)).to.equal(false)
		end)

		it("does not end early at all with the rule off", function()
			local cfg = config({ END_ON_BEATERS_CROSS = false })
			local state = toRunning(cfg)
			state = (
				Phase.step(state, {
					kind = "tick",
					beaters = 2,
					beatersAcross = 2,
				}, cfg.INTERMISSION_SECONDS + 5, cfg)
			)
			expect(state.phase).to.equal("Running")
			expect(state.endedEarly).to.equal(false)
		end)

		it("holds the WHOLE ROSTER at the scene, and builds it after the ties are freed", function()
			local cfg = config({ END_ON_BEATERS_CROSS = true })
			local state = toRunning(cfg)
			local endOfDrive = cfg.INTERMISSION_SECONDS + cfg.DRIVE_SECONDS
			local effects
			state, effects = Phase.step(state, { kind = "tick" }, endOfDrive, cfg)
			local order = kinds(effects)
			-- THE ORDER IS THE DESIGN: the ties go first (a rope on a man standing at the gathering
			-- spot is two freezes on one character), then the animals are cleared, then everybody is
			-- held, and only then is the scene built -- because the scene MOVES each character and
			-- `Body.stand` holds the one it is given.
			expect(indexOf(order, "release") > 0).to.equal(true)
			expect(indexOf(order, "release") < indexOf(order, "hold")).to.equal(true)
			expect(indexOf(order, "hold") < indexOf(order, "scene")).to.equal(true)
			expect(countKind(effects, "scene")).to.equal(1)
			-- EVERYBODY, not one team: the hunter who shot and the beater who pushed both stand there.
			for _, effect in ipairs(effects) do
				if effect.kind == "hold" then
					expect(#effect.userIds).to.equal(2)
					expect(effect.userIds[1]).to.equal(1)
					expect(effect.userIds[2]).to.equal(2)
				end
			end
			expect(Phase.participantIds(state)[1]).to.equal(1)
			expect(#Phase.participantIds(state)).to.equal(2)
		end)

		it("takes the scene down and frees everybody when the next drive starts", function()
			local cfg = config({ END_ON_BEATERS_CROSS = true })
			local state = toRunning(cfg)
			local endOfDrive = cfg.INTERMISSION_SECONDS + cfg.DRIVE_SECONDS
			state = (Phase.step(state, { kind = "tick" }, endOfDrive, cfg))
			local effects
			state, effects = Phase.step(state, { kind = "tick" }, endOfDrive + cfg.SCORE_SECONDS, cfg)
			expect(state.phase).to.equal("Assigning")
			local order = kinds(effects)
			-- FIRST, both of them: the lights come down and the scene's hold is handed back BEFORE
			-- anybody is placed, or a hunter would be respawned on his stand unable to walk.
			expect(order[1]).to.equal("clearScene")
			expect(order[2]).to.equal("free")
			expect(indexOf(order, "free") < indexOf(order, "placePlayers")).to.equal(true)
			expect(indexOf(order, "free") < indexOf(order, "hold")).to.equal(true)
			-- ...AND THE NEW HOLD IS APPLIED BEFORE THE RESPAWN (task 159, the two-player failure):
			-- free everybody, assign the new teams, hold the new beaters, and only then place.
			expect(indexOf(order, "hold") < indexOf(order, "placePlayers")).to.equal(true)
			-- ...and the new hold is the START LINE's again: the beaters only.
			for _, effect in ipairs(effects) do
				if effect.kind == "hold" then
					expect(#effect.userIds).to.equal(1)
					expect(state.assignment[effect.userIds[1]]).to.equal(cfg.START_HOLD_TEAM)
				end
			end
		end)

		it("takes the scene down when the server empties out instead", function()
			-- The other way out of Scoring: nobody left to start a drive with. The lights must not
			-- stay standing over the last drive's animals for whoever joins next, and whoever is
			-- still held must not stay frozen.
			local cfg = config({ END_ON_BEATERS_CROSS = true })
			local state = toRunning(cfg)
			local endOfDrive = cfg.INTERMISSION_SECONDS + cfg.DRIVE_SECONDS
			state = (Phase.step(state, { kind = "tick" }, endOfDrive, cfg))
			state = (Phase.step(state, { kind = "leave", userId = 1 }, endOfDrive + 1, cfg))
			state = (Phase.step(state, { kind = "leave", userId = 2 }, endOfDrive + 1, cfg))
			local effects
			state, effects = Phase.step(state, { kind = "tick" }, endOfDrive + cfg.SCORE_SECONDS, cfg)
			expect(state.phase).to.equal("Waiting")
			expect(countKind(effects, "clearScene")).to.equal(1)
			expect(countKind(effects, "free")).to.equal(1)
		end)

		it("ends a drive once: a crossing already through cannot re-enter Scoring", function()
			-- The beaters stay across the line for the whole of the scene, so the predicate is still
			-- true on every tick of it -- and `Phase.step` only asks it in `Running`.
			local cfg = config({ END_ON_BEATERS_CROSS = true })
			local state = toRunning(cfg)
			local at = cfg.INTERMISSION_SECONDS + 5
			state = (Phase.step(state, { kind = "tick", beaters = 2, beatersAcross = 2 }, at, cfg))
			expect(state.phase).to.equal("Scoring")
			local collected
			state, collected = run(state, cfg, at, cfg.SCORE_SECONDS - 1, 1)
			expect(state.phase).to.equal("Scoring")
			expect(countKind(collected, "scene")).to.equal(0)
			expect(countKind(collected, "clearScene")).to.equal(0)
		end)
	end)

	describe("the broadcast a client may not miss", function()
		it("forces the push on every phase entry, and only there", function()
			-- STATE_MIN_INTERVAL is the floor between pushes for a busy drive; a PHASE CHANGE behind
			-- it is a client showing the wrong drive until the 5-second heartbeat. Task 41's clock
			-- seam crossed two boundaries inside one throttle window and watched the drive-start push
			-- vanish, so every phase entry now marks its broadcast `force`.
			local cfg = config()
			local state = ready(cfg)

			local function forcedIn(effects): (number, number)
				local forced, throttled = 0, 0
				for _, effect in ipairs(effects) do
					if effect.kind == "broadcast" then
						if effect.force == true then
							forced += 1
						else
							throttled += 1
						end
					end
				end
				return forced, throttled
			end

			-- Waiting -> Assigning
			local effects
			state, effects = Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg)
			local forced, throttled = forcedIn(effects)
			expect(forced).to.equal(1) -- the phase entry
			expect(throttled).to.equal(1) -- the join itself, which may wait for the floor

			-- Assigning -> Running, and Running -> Scoring
			state, effects = Phase.step(state, { kind = "tick" }, cfg.INTERMISSION_SECONDS, cfg)
			expect(state.phase).to.equal("Running")
			forced, throttled = forcedIn(effects)
			expect(forced).to.equal(1)
			expect(throttled).to.equal(0)

			local endOfDrive = cfg.INTERMISSION_SECONDS + cfg.DRIVE_SECONDS
			state, effects = Phase.step(state, { kind = "tick" }, endOfDrive, cfg)
			expect(state.phase).to.equal("Scoring")
			expect((forcedIn(effects))).to.equal(1)

			-- An ordinary event inside a phase is NOT forced: that is what the floor is for.
			local _, quiet = Phase.step(state, { kind = "join", userId = 2, name = "Mila" }, endOfDrive + 1, cfg)
			local quietForced, quietThrottled = forcedIn(quiet)
			expect(quietForced).to.equal(0)
			expect(quietThrottled).to.equal(1)
		end)
	end)

	describe("the safety rule's effects", function()
		-- The machine does not decide WHETHER the shot was a violation (Match.Penalty does, and the
		-- owner asks the three questions around it). What it owns is what happens next, and in what
		-- order.
		local function running(cfg)
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg))
			state = (Phase.step(state, { kind = "join", userId = 2, name = "Mila" }, 0, cfg))
			state = (Phase.step(state, { kind = "tick" }, cfg.INTERMISSION_SECONDS, cfg))
			expect(state.phase).to.equal("Running")
			return state
		end

		it("freezes the offender BEFORE it announces it, so the two cannot disagree", function()
			local cfg = config()
			local state = running(cfg)
			local at = cfg.INTERMISSION_SECONDS + 5
			local effects
			state, effects = Phase.step(state, { kind = "violation", userId = 1, name = "Karen", at = at }, at, cfg)
			-- The order is load-bearing: the owner's `tied` set is what the snapshot reports, so a
			-- broadcast applied before the tie would announce the violation and show nobody tied.
			expect(kinds(effects)[1]).to.equal("freeze")
			expect(kinds(effects)[2]).to.equal("feed")
			expect(kinds(effects)[3]).to.equal("broadcast")
			expect(effects[1].userId).to.equal(1)
			expect(effects[2].entry.kind).to.equal("violation")
			expect(effects[2].entry.userId).to.equal(1)
			expect(countKind(effects, "freeze")).to.equal(1)
			-- The drive is not interrupted by it: nobody is respawned, nothing is re-armed by the
			-- machine, and no boar is touched.
			expect(countKind(effects, "placePlayers")).to.equal(0)
			expect(countKind(effects, "clearBoars")).to.equal(0)
		end)

		it("ignores a violation in every phase but Running", function()
			local cfg = config()
			-- Waiting: nobody has a gun at all.
			local waiting = ready(cfg)
			local _, idle = Phase.step(waiting, { kind = "violation", userId = 1, at = 0 }, 0, cfg)
			expect(countKind(idle, "freeze")).to.equal(0)
			expect(countKind(idle, "feed")).to.equal(0)

			-- Assigning: the drive has not started, so the rule has not either.
			local assigning = (Phase.step(waiting, { kind = "join", userId = 1, name = "Karen" }, 0, cfg))
			expect(assigning.phase).to.equal("Assigning")
			local _, early = Phase.step(assigning, { kind = "violation", userId = 1, at = 1 }, 1, cfg)
			expect(countKind(early, "freeze")).to.equal(0)

			-- Scoring: "shooting is possible and pointless" (design section 4.1).
			local state = running(cfg)
			local endOfDrive = cfg.INTERMISSION_SECONDS + cfg.DRIVE_SECONDS
			state = (Phase.step(state, { kind = "tick" }, endOfDrive, cfg))
			expect(state.phase).to.equal("Scoring")
			local _, late =
				Phase.step(state, { kind = "violation", userId = 1, at = endOfDrive + 1 }, endOfDrive + 1, cfg)
			expect(countKind(late, "freeze")).to.equal(0)
		end)

		it("frees everybody when the drive ends, in the same step that clears the boars", function()
			local cfg = config()
			local state = running(cfg)
			local endOfDrive = cfg.INTERMISSION_SECONDS + cfg.DRIVE_SECONDS
			local effects
			state, effects = Phase.step(state, { kind = "tick" }, endOfDrive, cfg)
			expect(state.phase).to.equal("Scoring")
			expect(countKind(effects, "release")).to.equal(1)
			expect(countKind(effects, "clearBoars")).to.equal(1)
		end)

		it("does not freeze a second time for a second violation, because it is asked once", function()
			-- The machine is told about a violation only when the owner has decided there is one, and
			-- the owner's second question is "is he already tied". So two violation EVENTS do produce
			-- two freezes here -- and that is why the guard lives in the owner, where the `tied` table
			-- is. Asserted, so nobody moves it and believes it was here.
			local cfg = config()
			local state = running(cfg)
			local at = cfg.INTERMISSION_SECONDS + 5
			local first, second
			state, first = Phase.step(state, { kind = "violation", userId = 1, at = at }, at, cfg)
			state, second = Phase.step(state, { kind = "violation", userId = 1, at = at + 0.1 }, at + 0.1, cfg)
			expect(countKind(first, "freeze")).to.equal(1)
			expect(countKind(second, "freeze")).to.equal(1)
		end)
	end)

	describe("joining and leaving", function()
		it("puts a mid-drive joiner on the smaller team and moves nobody else", function()
			local cfg = config()
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "a" }, 0, cfg))
			state = (Phase.step(state, { kind = "join", userId = 2, name = "b" }, 0, cfg))
			state = (Phase.step(state, { kind = "tick" }, cfg.INTERMISSION_SECONDS, cfg))
			expect(state.phase).to.equal("Running")
			local before = table.clone(state.assignment)

			local effects
			state, effects =
				Phase.step(state, { kind = "join", userId = 3, name = "c" }, cfg.INTERMISSION_SECONDS + 5, cfg)
			expect(state.assignment[3]).to.be.ok()
			expect(countKind(effects, "placePlayers")).to.equal(1)
			for userId, team in pairs(before) do
				expect(state.assignment[userId]).to.equal(team) -- nobody already playing moved
			end
		end)

		it("drops a leaver from the roster without ending the drive", function()
			local cfg = config()
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "a" }, 0, cfg))
			state = (Phase.step(state, { kind = "join", userId = 2, name = "b" }, 0, cfg))
			state = (Phase.step(state, { kind = "tick" }, cfg.INTERMISSION_SECONDS, cfg))
			state = (Phase.step(state, { kind = "leave", userId = 2 }, cfg.INTERMISSION_SECONDS + 1, cfg))
			expect(state.phase).to.equal("Running") -- a drive never aborts because a team emptied
			expect(state.assignment[2]).to.equal(nil)
			expect(Phase.participantCount(state)).to.equal(1)
		end)
	end)

	describe("robustness", function()
		it("advances one phase at most across a five-second server hitch", function()
			local cfg = config()
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "a" }, 0, cfg))
			expect(state.phase).to.equal("Assigning")
			-- One step with a huge `now`: the machine may enter Running, and must not run the whole
			-- drive and land in Scoring in the same step.
			state = (Phase.step(state, { kind = "tick" }, 10000, cfg))
			expect(state.phase).to.equal("Running")
		end)

		it("is deterministic: the same seed and events give the same effects", function()
			local cfg = config({ RELEASE_JITTER_SECONDS = 15 })
			local function play()
				local state = ready(cfg)
				state = (Phase.step(state, { kind = "join", userId = 1, name = "a" }, 0, cfg))
				local collected
				state, collected = run(state, cfg, 0, 90, 0.25)
				return kinds(collected)
			end
			local first, second = play(), play()
			expect(#first).to.equal(#second)
			for index, kind in ipairs(first) do
				expect(second[index]).to.equal(kind)
			end
		end)

		it("jitters the releases, deterministically, inside the configured spread", function()
			for index = 1, 20 do
				local value = Phase.jitter(7, index, 15)
				expect(value >= -15 and value <= 15).to.equal(true)
				expect(Phase.jitter(7, index, 15)).to.equal(value) -- same seed, same answer
			end
			expect(Phase.jitter(7, 1, 0)).to.equal(0)
		end)

		it("returns a frozen state that cannot be written", function()
			local state = ready(config())
			expect(function()
				state.phase = "Running"
			end).to.throw()
		end)

		it("steps 10000 times in under 200 ms", function()
			local cfg = config()
			local state = ready(cfg)
			for userId = 1, 16 do
				state = (Phase.step(state, { kind = "join", userId = userId, name = "p" }, 0, cfg))
			end
			local started = os.clock()
			local at = 0
			for _ = 1, 10000 do
				at += 0.25
				state = (Phase.step(state, { kind = "tick", aliveBoars = 1 }, at, cfg))
			end
			local elapsed = (os.clock() - started) * 1000
			print(string.format("[match_phase] 10000 steps in %.0f ms", elapsed))
			expect(elapsed < 200).to.equal(true)
		end)
	end)
	-- THE SOUNDER RELEASE (design, "the sounder release" and section 12.1). Both states of the flag
	-- are exercised here whatever the flag is set to, because `SOUNDER.ENABLED` arrives in `config`
	-- and this spec writes its own (feature-flags.md section 13.3).
	-- ------------------------------------------------------------------ the quick test (task 83)
	describe("the quick test", function()
		-- Its own numbers, and its own spawn on "the road". Everything below drives BOTH states from
		-- one table, so neither the flag nor Studio is consulted anywhere in this file.
		local LINE = Vector3.new(0, 0, -700)
		local QUICK = {
			QUICK_TEST = true,
			QUICK_TEST_INTERMISSION_SECONDS = 3,
			QUICK_TEST_SOUNDER = 3,
			QUICK_TEST_AHEAD_STUDS = 12,
			QUICK_TEST_SPREAD_STUDS = 6,
			-- ROOM FOR THE THREE, and the first run of this block is why it is written down: this
			-- file's own MAX_ALIVE_BOARS is 2, so a three-boar release was held back for ever and
			-- three cases failed on a ceiling rather than on the quick test. A release bigger than
			-- the ceiling can never happen -- `maybeRelease` holds the WHOLE sounder back -- which
			-- is a real invariant, and `match_live.spec` asserts it of the live numbers.
			MAX_ALIVE_BOARS = 4,
			QUICK_TEST_INTERVAL_SECONDS = 15,
			-- DELIBERATELY NOT THIS FILE'S OWN FIRST_RELEASE_SECONDS (5): when the two are equal,
			-- a quick branch that returned the ordinary number passes every case here. Measured --
			-- that mutation ran green until this line made them different.
			QUICK_TEST_FIRST_RELEASE_SECONDS = 2,
		}

		local function quickConfig(overrides)
			local merged = config(QUICK)
			for key, value in pairs(overrides or {}) do
				merged[key] = value
			end
			return merged
		end

		local function readyQuick(cfg)
			local state = Phase.initial(cfg)
			return (
				Phase.step(state, {
					kind = "markers",
					complete = true,
					missing = {},
					boarSpawns = SPAWNS,
					quickSpawn = LINE + Vector3.new(0, 0, cfg.QUICK_TEST_AHEAD_STUDS),
				}, 0, cfg)
			)
		end

		it("shortens the intermission and fires the first release at once, and does neither when off", function()
			-- BOTH BRANCHES, ONE TABLE EACH. With the quick test off these are the numbers this
			-- drive has always had, which is the half that says a playtest switch changed nothing.
			local off = config()
			expect(Phase.intermissionSeconds(off)).to.equal(off.INTERMISSION_SECONDS)
			expect(Phase.firstReleaseSeconds(off)).to.equal(off.FIRST_RELEASE_SECONDS)

			local on = quickConfig()
			expect(Phase.intermissionSeconds(on)).to.equal(3)
			expect(Phase.firstReleaseSeconds(on)).to.equal(2)
			-- AND THE SHIPPED NUMBERS ARE REALLY FASTER, which is the claim Karen made and the one a
			-- fixture cannot answer: this file's own FIRST_RELEASE_SECONDS is 5 because a test does
			-- not want to simulate twenty, and comparing the quick value against THAT compared 5
			-- with 5 and failed (the first gate of this task). The production table is what the
			-- promise is about.
			local live = Match.CONFIG
			expect(live.QUICK_TEST_INTERMISSION_SECONDS < live.INTERMISSION_SECONDS).to.equal(true)
			expect(live.QUICK_TEST_FIRST_RELEASE_SECONDS < live.FIRST_RELEASE_SECONDS).to.equal(true)
			expect(live.QUICK_TEST_INTERVAL_SECONDS < live.RELEASE_INTERVAL_SECONDS).to.equal(true)
			-- THIRTY SECONDS OF WAITING BECOMES EIGHT, and that difference IS task 83.
			--
			-- THE FACTOR WAS 4 AND IS NOW 3, because task 158 cut the intermission from 20 to 10 at
			-- Karen's word ("timer like 10s to find position to stand"): the real wait is 30 s rather
			-- than 40, the quick wait is the same 8, and 8 * 4 = 32 is no longer under it. The claim
			-- being made is "the quick test is MUCH faster", which at 3.75x it still is -- and the
			-- honest way to keep a measured assertion true is to say what was measured, not to retune
			-- a playtest number so an old multiple survives.
			local realWait = live.INTERMISSION_SECONDS + live.FIRST_RELEASE_SECONDS
			local quickWait = live.QUICK_TEST_INTERMISSION_SECONDS + live.QUICK_TEST_FIRST_RELEASE_SECONDS
			expect(quickWait * 3 <= realWait).to.equal(true)
			TestKit.note(string.format("task83: %d s of waiting becomes %d s with the quick test", realWait, quickWait))
		end)

		it("puts three boars on the road within seconds of the first player joining", function()
			-- THE WHOLE POINT, AS A CLOCK. Karen, 2026-09-27: "just for testing could be much faster
			-- that they cross a line small group and then you can shoot".
			local cfg = quickConfig()
			local state = readyQuick(cfg)
			local at = 0
			state = (Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, at, cfg))
			expect(state.phase).to.equal("Assigning")

			local collected
			state, collected, at = run(state, cfg, at, 12, 0.25)
			expect(state.phase).to.equal("Running")
			local spawns = {}
			for _, effect in ipairs(collected) do
				if effect.kind == "spawnSounder" then
					table.insert(spawns, effect)
				end
			end
			expect(#spawns).to.equal(1)
			expect(spawns[1].size).to.equal(3)
			-- ON THE ROAD, not at the far marker: the position is the one the owner measured from
			-- the drive line, and the ring is clamped to the road's own width.
			expect(spawns[1].position).to.equal(LINE + Vector3.new(0, 0, cfg.QUICK_TEST_AHEAD_STUDS))
			expect(spawns[1].spread).to.equal(cfg.QUICK_TEST_SPREAD_STUDS)
			expect(at <= 12).to.equal(true) -- 3 s of intermission plus a 5 s first release, not 40

			-- ...and the same nine seconds with the quick test off release nothing at all, because
			-- the drive has not even started yet: the intermission alone is ten.
			local slowCfg = config()
			local slow = ready(slowCfg)
			slow = (Phase.step(slow, { kind = "join", userId = 1, name = "Karen" }, 0, slowCfg))
			local slowEffects
			slow, slowEffects = run(slow, slowCfg, 0, 9, 0.25)
			expect(slow.phase).to.equal("Assigning")
			expect(countKind(slowEffects, "spawnSounder")).to.equal(0)
		end)

		it("keeps them coming on its own rhythm, and only the FIRST release is the quick one", function()
			local cfg = quickConfig({ BOARS_PER_DRIVE = 6, QUICK_TEST_INTERVAL_SECONDS = 5 })
			local state = readyQuick(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg))
			local collected
			state, collected = run(state, cfg, 0, 40, 0.25)
			local spawns = {}
			for _, effect in ipairs(collected) do
				if effect.kind == "spawnSounder" then
					table.insert(spawns, effect)
				end
			end
			expect(#spawns >= 2).to.equal(true)
			-- the first is the quick one...
			expect(spawns[1].size).to.equal(3)
			expect(spawns[1].spread).to.equal(cfg.QUICK_TEST_SPREAD_STUDS)
			-- ...and the second is an ordinary release: a marker position, the map's own spread
			-- (nil here, so the owner uses the spawn pad), and the sounder flag's own size. It
			-- arrives on the quick rhythm rather than the drive's 90 seconds, which is what makes a
			-- playtest a series of crossings instead of one blink.
			expect(spawns[2].spread).to.equal(nil)
			local fromMarker = false
			for _, spawn in ipairs(SPAWNS) do
				if spawns[2].position == spawn then
					fromMarker = true
				end
			end
			expect(fromMarker).to.equal(true)
		end)

		it("falls back to the normal marker when there is no line to measure from", function()
			-- A map with no DriveLine cannot have a quick spawn, and the release must still happen
			-- rather than being dropped: `quickSpawn` is nil and everything else is unchanged.
			local cfg = quickConfig()
			local state = Phase.initial(cfg)
			state = (
				Phase.step(state, { kind = "markers", complete = true, missing = {}, boarSpawns = SPAWNS }, 0, cfg)
			)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg))
			local collected
			state, collected = run(state, cfg, 0, 12, 0.25)
			local spawns = {}
			for _, effect in ipairs(collected) do
				if effect.kind == "spawnSounder" then
					table.insert(spawns, effect)
				end
			end
			expect(#spawns).to.equal(1)
			expect(spawns[1].spread).to.equal(nil)
			local fromMarker = false
			for _, spawn in ipairs(SPAWNS) do
				if spawns[1].position == spawn then
					fromMarker = true
				end
			end
			expect(fromMarker).to.equal(true)
		end)
	end)

	describe("the release is a sounder", function()
		-- THE REAL NUMBERS, AS LITERALS. The flag-off identity proof must not be able to agree with
		-- a changed CONFIG: if somebody moves the 90-second rhythm, this fails, which is the point.
		local function liveConfig(enabled: boolean)
			return {
				DRIVE_SECONDS = 600,
				INTERMISSION_SECONDS = 10,
				SCORE_SECONDS = 5,
				MIN_PLAYERS = 1,
				MAX_PLAYERS = 16,
				ODD_PLAYER_TEAM = "Shooters",
				SWAP_TEAMS_EACH_DRIVE = true,
				BOARS_PER_DRIVE = 6,
				FIRST_RELEASE_SECONDS = 20,
				RELEASE_INTERVAL_SECONDS = 90,
				RELEASE_JITTER_SECONDS = 15,
				MAX_ALIVE_BOARS = 6,
				SEED = 1,
				SOUNDER = {
					ENABLED = enabled,
					MAX_SIZE = 5,
					SIZE_WEIGHTS = { 40, 20, 18, 12, 10 },
					EXPECTED_SIZE = 2.32,
					TAIL_SECONDS = 90,
					GAP_MIN_SECONDS = 45,
					GAP_MAX_SECONDS = 180,
					HOLDBACK_WARN = 20,
				},
			}
		end

		-- One whole drive, from Waiting, with an empty field throughout. Returns the releases as
		-- { at (seconds since the drive started), size, position } and the state at the end.
		local function runDrive(cfg, alive: number?, entries: number?, capacity: number?)
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg))
			state = (Phase.step(state, { kind = "tick" }, cfg.INTERMISSION_SECONDS, cfg))
			expect(state.phase).to.equal("Running")

			local started = cfg.INTERMISSION_SECONDS
			local releases = {}
			local now = started
			while now < started + cfg.DRIVE_SECONDS - 0.5 do
				now += 0.25
				local effects
				state, effects = Phase.step(state, {
					kind = "tick",
					aliveBoars = alive or 0,
					boarEntries = entries or 0,
					boarCapacity = capacity or 8,
				}, now, cfg)
				for _, effect in ipairs(effects) do
					if effect.kind == "spawnSounder" then
						table.insert(releases, { at = now - started, size = effect.size, position = effect.position })
					end
				end
			end
			return releases, state
		end

		it("with the flag OFF releases six singles on exactly the old schedule", function()
			local cfg = liveConfig(false)
			local releases, state = runDrive(cfg)

			expect(#releases).to.equal(6)
			expect(state.boarsReleased).to.equal(6)
			-- THE TWO COUNTS ARE EQUAL OFF THE FLAG, which is what makes the marker round-robin and
			-- the jitter index the same sequence they were before this task.
			expect(state.soundersReleased).to.equal(state.boarsReleased)
			for _, release in ipairs(releases) do
				expect(release.size).to.equal(1)
				expect(release.position).to.be.ok()
			end
			-- The first is EXACT (Task 32 measured why), the rest are 90 s +/- 15.
			expect(math.abs(releases[1].at - 20) < 0.3).to.equal(true)
			for index = 2, #releases do
				local gap = releases[index].at - releases[index - 1].at
				expect(gap >= 90 - 15 - 0.3 and gap <= 90 + 15 + 0.3).to.equal(true)
			end
			-- ...and round-robin over the markers, in order.
			for index, release in ipairs(releases) do
				expect(release.position).to.equal(SPAWNS[((index - 1) % #SPAWNS) + 1])
			end
		end)

		it("with the flag ON spends exactly the drive's budget, in sizes 1..MAX_SIZE", function()
			local histogram = { 0, 0, 0, 0, 0 }
			local releases = 0
			for seed = 1, 200 do
				local cfg = liveConfig(true)
				cfg.SEED = seed
				local drive = runDrive(cfg)
				local sum = 0
				for _, release in ipairs(drive) do
					expect(release.size >= 1 and release.size <= cfg.SOUNDER.MAX_SIZE).to.equal(true)
					histogram[release.size] += 1
					releases += 1
					sum += release.size
				end
				-- EXACTLY the budget: never five animals, never seven. The clamp to what is left is
				-- what guarantees it, and it is also what bends the mix (the next case).
				expect(sum).to.equal(cfg.BOARS_PER_DRIVE)
			end
			TestKit.note(
				string.format(
					"sounder mix over 200 drives: %d releases, sizes 1-5 = %d/%d/%d/%d/%d",
					releases,
					histogram[1],
					histogram[2],
					histogram[3],
					histogram[4],
					histogram[5]
				)
			)
			-- Every size does occur, or the weights are decoration.
			for size = 1, 5 do
				expect(histogram[size] > 0).to.equal(true)
			end
		end)

		it("draws the weights it is given, within 20% (before the budget clamps them)", function()
			-- THE DRAW, not the released mix. Measured 2026-09-26: the released histogram over 200
			-- drives is 41 / 23 / 25 / 8 / 3 per cent against weights of 40 / 20 / 18 / 12 / 10,
			-- because a six-animal budget cannot pay for a five after a three -- `sounderSize`
			-- clamps to what is left, which is the same rule that makes the sizes sum exactly. So
			-- the distribution is asserted where it IS the distribution: a budget big enough that
			-- the clamp never bites.
			local cfg = liveConfig(true)
			cfg.BOARS_PER_DRIVE = 10000
			local histogram = { 0, 0, 0, 0, 0 }
			local draws = 2000
			for index = 1, draws do
				local state = { seed = 1, driveNumber = 1, boarsReleased = 0, soundersReleased = index - 1 }
				histogram[Phase.sounderSize(state :: any, cfg)] += 1
			end
			local weights = cfg.SOUNDER.SIZE_WEIGHTS
			local total = 0
			for _, weight in ipairs(weights) do
				total += weight
			end
			for size, weight in ipairs(weights) do
				local want = weight / total
				local got = histogram[size] / draws
				expect(math.abs(got - want) <= want * 0.2).to.equal(true)
			end
		end)

		it("keeps EXPECTED_SIZE equal to the mean of the weights", function()
			local sounder = liveConfig(true).SOUNDER
			local total, weighted = 0, 0
			for size, weight in ipairs(sounder.SIZE_WEIGHTS) do
				total += weight
				weighted += size * weight
			end
			expect(math.abs(weighted / total - sounder.EXPECTED_SIZE) <= 0.01).to.equal(true)
			-- ...and the shipped config, not only this spec's copy.
			local live = Match.CONFIG.SOUNDER
			local liveTotal, liveWeighted = 0, 0
			for size, weight in ipairs(live.SIZE_WEIGHTS) do
				liveTotal += weight
				liveWeighted += size * weight
			end
			expect(math.abs(liveWeighted / liveTotal - live.EXPECTED_SIZE) <= 0.01).to.equal(true)
		end)

		it("is the same drive twice, and a different drive next time", function()
			local cfg = liveConfig(true)
			local function sizes(driveNumber: number)
				local out = {}
				for index = 0, 5 do
					local state =
						{ seed = cfg.SEED, driveNumber = driveNumber, boarsReleased = 0, soundersReleased = index }
					table.insert(out, Phase.sounderSize(state :: any, cfg))
				end
				return table.concat(out, ",")
			end
			expect(sizes(1)).to.equal(sizes(1))
			expect(sizes(1)).never.to.equal(sizes(2))
			-- THE COMMITTED SEED'S OPENING, recorded rather than assumed (design section 12.10): if
			-- it opened with a single, the seed would be the thing to change.
			-- WITH THE FLAG ON, whatever the flag is set to right now: off it every size is 1 and the
			-- note would say nothing about the seed. The committed seed opens with a GROUP, so
			-- there is no seed to change (design section 12.10).
			local live = table.clone(Match.CONFIG)
			local liveSounder = table.clone(Match.CONFIG.SOUNDER)
			liveSounder.ENABLED = true
			live.SOUNDER = liveSounder
			local first = {}
			local budget = live.BOARS_PER_DRIVE
			local drawn = { seed = live.SEED, driveNumber = 1, boarsReleased = 0, soundersReleased = 0 }
			while budget > 0 and #first < 6 do
				local size = Phase.sounderSize(drawn :: any, live)
				table.insert(first, size)
				budget -= size
				drawn.boarsReleased += size
				drawn.soundersReleased += 1
			end
			TestKit.note(
				string.format(
					"SEED=%d drive 1 is sizes %s with the flag ON (it is %s right now)",
					live.SEED,
					table.concat(first, ","),
					tostring(Match.CONFIG.SOUNDER.ENABLED)
				)
			)
			expect(first[1] >= 2).to.equal(true) -- the committed seed opens with a group, not a single
		end)

		it("paces the releases across the drive, inside the gap clamp", function()
			local cfg = liveConfig(true)
			-- The gap itself, straight from the function: it can never be outside the clamp, at any
			-- point of the drive and whatever the budget is.
			for remaining = 0, 6 do
				for elapsed = 0, 540, 30 do
					local state = {
						seed = 1,
						driveNumber = 1,
						boarsReleased = cfg.BOARS_PER_DRIVE - remaining,
						soundersReleased = 1,
						phaseEndsAt = 600,
					}
					local gap = Phase.releaseGap(state :: any, 2, elapsed, cfg)
					expect(gap >= cfg.SOUNDER.GAP_MIN_SECONDS).to.equal(true)
					expect(gap <= cfg.SOUNDER.GAP_MAX_SECONDS).to.equal(true)
				end
			end

			-- ...and over 200 drives, where it lands. MEASURED 2026-09-26: the worst last release is
			-- at 521 s and 25 of 200 drives place their last release after DRIVE_SECONDS minus
			-- TAIL_SECONDS. The design's section 12.1 item 5 asserts that never happens; it does,
			-- because GAP_MIN_SECONDS = 45 wins over the pacing once the budget is nearly spent and
			-- a drive of all-singles needs six releases. Asserted as what the code guarantees, with
			-- the deviation stated in reviews/task-61/REQUEST.md.
			local byTail, drives, worst = 0, 0, 0
			for seed = 1, 200 do
				local seeded = liveConfig(true)
				seeded.SEED = seed
				local releases = runDrive(seeded)
				drives += 1
				local last = releases[#releases].at
				worst = math.max(worst, last)
				if last <= seeded.DRIVE_SECONDS - seeded.SOUNDER.TAIL_SECONDS then
					byTail += 1
				end
				expect(last < seeded.DRIVE_SECONDS).to.equal(true)
			end
			TestKit.note(
				string.format(
					"sounder pacing: %d/%d drives done by the tail, worst last release %.1f s",
					byTail,
					drives,
					worst
				)
			)
			expect(worst <= 560).to.equal(true)
			expect(byTail >= drives * 0.8).to.equal(true)
		end)

		it("holds a whole sounder back rather than releasing part of it", function()
			-- A drawn size of 5 with four slots free: nothing is released, the budget is untouched,
			-- and the SAME size arrives when there is room -- because the hash index did not move.
			local cfg = liveConfig(true)
			local seed = nil
			for candidate = 1, 500 do
				local state = { seed = candidate, driveNumber = 1, boarsReleased = 0, soundersReleased = 0 }
				if Phase.sounderSize(state :: any, cfg) == 5 then
					seed = candidate
					break
				end
			end
			expect(seed).to.be.ok()
			cfg.SEED = seed

			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg))
			state = (Phase.step(state, { kind = "tick" }, cfg.INTERMISSION_SECONDS, cfg))
			local at = cfg.INTERMISSION_SECONDS + cfg.FIRST_RELEASE_SECONDS + 1

			local effects
			state, effects = Phase.step(
				state,
				{ kind = "tick", aliveBoars = cfg.MAX_ALIVE_BOARS - 2, boarEntries = 0, boarCapacity = 8 },
				at,
				cfg
			)
			expect(countKind(effects, "spawnSounder")).to.equal(0)
			expect(state.boarsReleased).to.equal(0)
			expect(state.holdbacks).to.equal(1)

			state, effects =
				Phase.step(state, { kind = "tick", aliveBoars = 0, boarEntries = 0, boarCapacity = 8 }, at + 0.25, cfg)
			expect(countKind(effects, "spawnSounder")).to.equal(1)
			expect(effects[1].size).to.equal(5)
			expect(state.boarsReleased).to.equal(5)
			expect(state.holdbacks).to.equal(0)
		end)

		it("holds back on the CARCASS count too, not only the live one", function()
			-- Hazard 2 of design section 6.3: a carcass holds a runtime slot for CARCASS_SECONDS and
			-- `aliveBoars` does not count it, so a field with nothing alive can still be full.
			local cfg = liveConfig(true)
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg))
			state = (Phase.step(state, { kind = "tick" }, cfg.INTERMISSION_SECONDS, cfg))
			local at = cfg.INTERMISSION_SECONDS + cfg.FIRST_RELEASE_SECONDS + 1

			local effects
			state, effects =
				Phase.step(state, { kind = "tick", aliveBoars = 0, boarEntries = 7, boarCapacity = 8 }, at, cfg)
			expect(countKind(effects, "spawnSounder")).to.equal(0)
			expect(state.boarsReleased).to.equal(0)

			state, effects =
				Phase.step(state, { kind = "tick", aliveBoars = 0, boarEntries = 0, boarCapacity = 8 }, at + 0.25, cfg)
			expect(countKind(effects, "spawnSounder")).to.equal(1)
		end)

		it("gives a refused sounder back whole", function()
			local cfg = liveConfig(true)
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg))
			state = (Phase.step(state, { kind = "tick" }, cfg.INTERMISSION_SECONDS, cfg))
			local at = cfg.INTERMISSION_SECONDS + cfg.FIRST_RELEASE_SECONDS + 1

			local effects
			state, effects =
				Phase.step(state, { kind = "tick", aliveBoars = 0, boarEntries = 0, boarCapacity = 8 }, at, cfg)
			expect(countKind(effects, "spawnSounder")).to.equal(1)
			local size = effects[1].size
			local sounders, boars = state.soundersReleased, state.boarsReleased

			state = Phase.releaseFailed(state, at, size)
			expect(state.soundersReleased).to.equal(sounders - 1)
			expect(state.boarsReleased).to.equal(boars - size)
			expect(state.nextReleaseAt).to.equal(at)

			-- ...and the retry is the SAME sounder: same index, same size.
			state, effects =
				Phase.step(state, { kind = "tick", aliveBoars = 0, boarEntries = 0, boarCapacity = 8 }, at + 0.25, cfg)
			expect(countKind(effects, "spawnSounder")).to.equal(1)
			expect(effects[1].size).to.equal(size)

			-- A hand-back with nothing released is a no-op, not a negative count.
			local fresh = ready(cfg)
			expect(Phase.releaseFailed(fresh, 0, 5).boarsReleased).to.equal(0)
			expect(Phase.releaseFailed(fresh, 0, 5).soundersReleased).to.equal(0)
		end)

		it("never releases twice in one step, even on a five-second hitch", function()
			local cfg = liveConfig(true)
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg))
			state = (Phase.step(state, { kind = "tick" }, cfg.INTERMISSION_SECONDS, cfg))
			local now = cfg.INTERMISSION_SECONDS
			local phases = 0
			local previous = state.phase
			while now < cfg.INTERMISSION_SECONDS + cfg.DRIVE_SECONDS do
				now += 5 -- a five-second hitch, every step
				local effects
				state, effects =
					Phase.step(state, { kind = "tick", aliveBoars = 0, boarEntries = 0, boarCapacity = 8 }, now, cfg)
				expect(countKind(effects, "spawnSounder") <= 1).to.equal(true)
				if state.phase ~= previous then
					phases += 1
					previous = state.phase
				end
			end
			expect(phases <= 2).to.equal(true) -- Running -> Scoring (-> Assigning) and no further
		end)

		it("runs 10000 steps in well under 200 ms", function()
			local cfg = liveConfig(true)
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg))
			local started = os.clock()
			local now = 0
			for _ = 1, 10000 do
				now += 0.1
				state = (
					Phase.step(state, { kind = "tick", aliveBoars = 0, boarEntries = 0, boarCapacity = 8 }, now, cfg)
				)
			end
			local elapsed = (os.clock() - started) * 1000
			TestKit.note(string.format("match_phase: 10000 steps in %.0f ms (budget 200 ms)", elapsed))
			expect(elapsed < 200).to.equal(true)
		end)
	end)
	---------------------------------------------------------------- the forest's drive (task 157)

	describe("a world that owns its own animals", function()
		-- THE FOREST TEST'S CONFIG, which is `Match.CONFIG` with two scalars overridden at the
		-- composition root (`Match.WORLD_OVERRIDABLE`): its own drive length, and NO releases --
		-- the wood there is `ForestTest`'s and the drive must never spawn into it or clear it.
		local function forest()
			return config({ DRIVE_SECONDS = 300, BOARS_PER_DRIVE = 0 })
		end

		it("never asks for an animal, over a whole simulated drive", function()
			local cfg = forest()
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg))
			expect(state.phase).to.equal("Assigning")
			local collected
			-- the intermission plus the whole 300-second drive plus the scoring
			state, collected = run(state, cfg, 0, 340, 0.25)
			expect(countKind(collected, "spawnSounder")).to.equal(0)
			expect(state.boarsReleased).to.equal(0)
			expect(state.soundersReleased).to.equal(0)
			-- AND NOT ONE HOLD-BACK EITHER: `maybeRelease` returns on its FIRST predicate
			-- (`boarsReleased >= BOARS_PER_DRIVE`, true at 0), so there is no retry loop and no
			-- warning -- which is the whole reason the switch is this number and not a new branch.
			expect(state.holdbacks).to.equal(0)
			TestKit.note(
				string.format("match_phase forest: %d effects over 340 s, 0 spawnSounder, 0 holdbacks", #collected)
			)
		end)

		it("still runs every phase, on the forest's own clock", function()
			local cfg = forest()
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg))
			expect(state.phase).to.equal("Assigning")
			state = (run(state, cfg, 0, cfg.INTERMISSION_SECONDS + 1, 0.25))
			expect(state.phase).to.equal("Running")
			-- 300 and not 600: the drive's length is the one number the forest overrides for feel.
			state = (run(state, cfg, cfg.INTERMISSION_SECONDS + 1, cfg.DRIVE_SECONDS - 10, 0.5))
			expect(state.phase).to.equal("Running")
			-- OVER THE END AND NO FURTHER, measured off the machine's OWN deadline rather than off
			-- arithmetic here: `phaseEndsAt` is the only clock this system has, and `Scoring` is only
			-- `SCORE_SECONDS` long, so a window named in seconds either stops short of the boundary
			-- or runs through it into the next `Assigning` (both happened in round 1).
			local endsAt = state.phaseEndsAt
			state = (run(state, cfg, endsAt - 1, 2, 0.25))
			expect(state.phase).to.equal("Scoring")
		end)
	end)

	-- THE START OF A DRIVE (task 158). Karen: *"timer when start, timer like 10s to find position to
	-- stand"*, *"Beater start in line with others and countdown when drive starts"*.
	--
	-- NO PHASE WAS ADDED, and that is what these cases are about. The countdown IS `Assigning`, so
	-- every one of them is about the one deadline this machine already had plus the two effects that
	-- say who is held and when they are let go.
	describe("the start of a drive", function()
		-- FOUR PLAYERS AND A ROSTER THAT WAITS FOR THEM, so the drive is ENTERED with both sides
		-- full: `MIN_PLAYERS = 1` would start the drive on the first join and the other three would
		-- arrive through the join branch, which is a different case (it has its own below).
		-- `Roster.assign` sorts, so 1 and 2 are the beaters and 3 and 4 the hunters, every run.
		local FOUR = { MIN_PLAYERS = 4 }

		local function assigning(cfg)
			local state = ready(cfg)
			local effects
			for userId = 1, 4 do
				state, effects = Phase.step(state, { kind = "join", userId = userId, name = "p" .. userId }, 0, cfg)
			end
			expect(state.phase).to.equal("Assigning")
			return state, effects
		end

		local function heldIn(effects): { number }
			for _, effect in ipairs(effects) do
				if effect.kind == "hold" then
					return effect.userIds or {}
				end
			end
			return {}
		end

		local function freedIn(effects)
			for _, effect in ipairs(effects) do
				if effect.kind == "free" then
					return effect.userIds or "all"
				end
			end
			return nil
		end

		it("is the intermission itself: ONE deadline, which is the timer every side counts down", function()
			local cfg = config()
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg))
			expect(state.phase).to.equal("Assigning")
			-- THE ONE NUMBER: the hunter's stand timer, the beater's countdown and the card's life
			-- are all this, counted down locally off `phaseEndsAt`. There is no second clock.
			expect(state.phaseEndsAt).to.equal(cfg.INTERMISSION_SECONDS)
			expect(Phase.intermissionSeconds(cfg)).to.equal(cfg.INTERMISSION_SECONDS)
			state = (run(state, cfg, 0, cfg.INTERMISSION_SECONDS + 0.5, 0.25))
			expect(state.phase).to.equal("Running")
		end)

		it("holds exactly the beaters at the line, and BEFORE they are placed (task 159)", function()
			local cfg = config(FOUR)
			local _, effects = assigning(cfg)
			expect(table.concat(heldIn(effects), ",")).to.equal("1,2")
			-- **BEFORE** `placePlayers`, AND THE ORDER IS A MEASUREMENT (task 159). It was the other
			-- way round until the Director's two-player run failed on it
			-- (`[harness2] FAIL 33/35 @ 7ea945f`, zz_drive_boundary "took the scene down before the
			-- next drive, and let everybody go", for the one player the roster had just made a
			-- beater): `placePlayers` is the only effect in this list whose owner YIELDS
			-- (`Player:LoadCharacter`), the drive is already in `Assigning` with its new number while
			-- it yields, and the Heartbeat broadcasts that drive to every client before a `hold` at
			-- the end of the list has been applied -- so for the length of a respawn a beater the
			-- machine had decided to hold was not held, and nothing reading the drive could tell.
			-- Holding first costs one frame of freezing a character that is about to be replaced, and
			-- the character watch puts the freeze on the one that arrives, exactly as task 158
			-- already relied on.
			local list = kinds(effects)
			expect(table.find(list, "hold") < table.find(list, "placePlayers")).to.equal(true)
			expect(countKind(effects, "hold")).to.equal(1)
		end)

		it("holds no hunter, because the same ten seconds is his to walk to his stand with", function()
			local cfg = config(FOUR)
			local state, effects = assigning(cfg)
			for _, userId in ipairs(heldIn(effects)) do
				expect(state.assignment[userId]).to.equal("Drivers")
			end
			expect(state.assignment[3]).to.equal("Shooters")
			expect(state.assignment[4]).to.equal("Shooters")
			expect(table.find(heldIn(effects), 3)).to.equal(nil)
			expect(table.find(heldIn(effects), 4)).to.equal(nil)
		end)

		it("holds nobody when there is no beater, rather than an empty effect", function()
			local cfg = config()
			local state = ready(cfg)
			local effects
			-- ODD_PLAYER_TEAM is Shooters, so a solo player is a hunter and the line is empty.
			state, effects = Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg)
			expect(state.assignment[1]).to.equal("Shooters")
			expect(countKind(effects, "hold")).to.equal(0)
		end)

		it("lets everybody go at GO, with one effect that names nobody", function()
			local cfg = config({ MIN_PLAYERS = 4, BOARS_PER_DRIVE = 0 })
			local state = assigning(cfg)
			local effects
			state, effects = Phase.step(state, { kind = "tick", aliveBoars = 0 }, cfg.INTERMISSION_SECONDS, cfg)
			expect(state.phase).to.equal("Running")
			expect(countKind(effects, "free")).to.equal(1)
			-- NIL MEANS EVERYBODY HELD, so a beater who joined mid-countdown goes with the rest and
			-- no list can go stale between the hold and GO.
			expect(freedIn(effects)).to.equal("all")
			-- Exactly once: nothing inside the drive frees anybody again.
			local later
			state, later = run(state, cfg, cfg.INTERMISSION_SECONDS, 20, 0.5)
			expect(countKind(later, "free")).to.equal(0)
		end)

		it("holds a beater who arrives inside the countdown, and not a hunter", function()
			local cfg = config(FOUR)
			local state = assigning(cfg)
			local effects
			-- Both sides are 2/2, so the next joiner fills ODD_PLAYER_TEAM: a hunter, not held.
			state, effects = Phase.step(state, { kind = "join", userId = 5, name = "e" }, 1, cfg)
			expect(state.assignment[5]).to.equal("Shooters")
			expect(countKind(effects, "hold")).to.equal(0)
			-- ...and the one after him is a beater, who is.
			state, effects = Phase.step(state, { kind = "join", userId = 6, name = "f" }, 2, cfg)
			expect(state.assignment[6]).to.equal("Drivers")
			expect(table.concat(heldIn(effects), ",")).to.equal("6")
			expect(state.phase).to.equal("Assigning")
			-- ...and his hold comes BEFORE his placement too (task 159): one rule for every hold in
			-- this machine, so the yielding respawn can never be the thing that defines it.
			local joinOrder = kinds(effects)
			expect(table.find(joinOrder, "hold") < table.find(joinOrder, "placePlayers")).to.equal(true)
		end)

		it("holds nobody who joins INSIDE the drive: the line is behind them by then", function()
			local cfg = config({ MIN_PLAYERS = 4, BOARS_PER_DRIVE = 0 })
			local state = assigning(cfg)
			state = (Phase.step(state, { kind = "tick" }, cfg.INTERMISSION_SECONDS, cfg))
			expect(state.phase).to.equal("Running")
			local effects
			local at = cfg.INTERMISSION_SECONDS + 5
			state, effects = Phase.step(state, { kind = "join", userId = 7, name = "g" }, at, cfg)
			expect(countKind(effects, "placePlayers")).to.equal(1)
			expect(countKind(effects, "hold")).to.equal(0)
		end)

		it("puts a side-changer's hold or release before his placement too (task 159)", function()
			-- THE THIRD PLACE THE SAME RULE APPLIES. `Match.requestTeam` is honoured inside the
			-- countdown, and the effects it emits yield in the same way.
			local cfg = config(FOUR)
			local state = assigning(cfg)
			-- userId 3 is a hunter in this roster; made a beater, he is held, and the hold is first.
			local effects
			state, effects = Phase.step(state, { kind = "team", userId = 3, team = "Drivers" }, 2, cfg)
			local order = kinds(effects)
			expect(table.find(order, "hold")).to.be.ok()
			expect(table.find(order, "hold") < table.find(order, "placePlayers")).to.equal(true)
			-- ...and made a hunter again, his release is first.
			state, effects = Phase.step(state, { kind = "team", userId = 3, team = "Shooters" }, 3, cfg)
			order = kinds(effects)
			expect(table.find(order, "free")).to.be.ok()
			expect(table.find(order, "free") < table.find(order, "placePlayers")).to.equal(true)
			expect(state.assignment[3]).to.equal("Shooters")
		end)

		it("moves the hold with a player who changes sides inside the countdown", function()
			local cfg = config(FOUR)
			local state = assigning(cfg)
			expect(state.assignment[1]).to.equal("Drivers")
			expect(state.assignment[3]).to.equal("Shooters")
			local effects
			-- A hunter made a beater is held at the line.
			state, effects = Phase.step(state, { kind = "team", userId = 3, team = "Drivers" }, 1, cfg)
			expect(table.concat(heldIn(effects), ",")).to.equal("3")
			-- A beater made a hunter is let go -- and ONLY him, so a role flip cannot release the
			-- whole line.
			state, effects = Phase.step(state, { kind = "team", userId = 1, team = "Shooters" }, 2, cfg)
			expect(countKind(effects, "hold")).to.equal(0)
			expect(table.concat(freedIn(effects) :: { number }, ",")).to.equal("1")
		end)

		-- ---------------------------------------------------------------- task 168: GO is the fanfare's end
		--
		-- KAREN, 2026-10-12 ~21:45: *"you can't move as a beater before horn made signal and there
		-- should be countdown"*. Both states are driven here by PARAMETER (`GO_HOLD_SECONDS`), which
		-- is why none of the cases above had to change: with it unset the machine frees at GO exactly
		-- as task 158 wrote it.
		it("holds the line through the start fanfare and lets it go at the end of the phrase", function()
			local cfg = config({ MIN_PLAYERS = 4, BOARS_PER_DRIVE = 0, GO_HOLD_SECONDS = 2 })
			local state = assigning(cfg)
			-- Two beaters and two hunters, and the beaters are held by the countdown.
			local effects
			state, effects = Phase.step(state, { kind = "tick", aliveBoars = 0 }, cfg.INTERMISSION_SECONDS, cfg)
			expect(state.phase).to.equal("Running")
			-- GO SOUNDS THE HORN AND FREES NOBODY. This is the whole of the fix: before task 168 the
			-- `free` and the `signal` were in this same effect list.
			expect(feedText(effects, "signal")).to.equal("start")
			expect(countKind(effects, "free")).to.equal(0)
			expect(state.goFreed).to.equal(false)
			expect(state.goFreeAt).to.equal(cfg.INTERMISSION_SECONDS + 2)

			-- ...AND STILL NOBODY, A WHOLE SECOND AND A HALF LATER.
			local during
			state, during = run(state, cfg, cfg.INTERMISSION_SECONDS, 1.5, 0.25)
			expect(countKind(during, "free")).to.equal(0)
			expect(state.goFreed).to.equal(false)

			-- THEN, PAST THE PHRASE, ONE `free` THAT NAMES NOBODY -- so a beater who joined inside
			-- the countdown goes with the rest.
			local after
			state, after = run(state, cfg, cfg.INTERMISSION_SECONDS + 1.5, 1, 0.25)
			expect(countKind(after, "free")).to.equal(1)
			expect(freedIn(after)).to.equal("all")
			expect(state.goFreed).to.equal(true)
			-- EXACTLY ONCE, however many ticks arrive: `goFreed` is the latch, not the time.
			local later
			state, later = run(state, cfg, cfg.INTERMISSION_SECONDS + 2.5, 20, 0.5)
			expect(countKind(later, "free")).to.equal(0)
			-- ...AND THE TIME STAYS ON THE STATE, because a beater's screen says `GO` for five
			-- seconds afterwards and works that out from the age of this timestamp.
			expect(state.goFreeAt).to.equal(cfg.INTERMISSION_SECONDS + 2)
			TestKit.note(
				string.format(
					"match_phase: GO hold %.2f s, freed at %.2f, drive still Running=%s",
					Phase.goHoldSeconds(cfg),
					state.goFreeAt,
					tostring(state.phase == "Running")
				)
			)
		end)

		it("holds a PLAYER beater, not just a bot: the hold is the roster's and names her userId", function()
			-- The hold has nothing to do with bots -- `Phase` has never heard of one. This states it
			-- as a case, because Karen reported being able to walk as a beater and the first question
			-- was whether the machine held a person at all.
			local cfg = config({ MIN_PLAYERS = 4, BOARS_PER_DRIVE = 0, GO_HOLD_SECONDS = 2 })
			local state = ready(cfg)
			-- THE HOLD IS IN THE JOIN THAT COMPLETES THE ROSTER, not in the tick after it: the fourth
			-- join starts the drive on its own step (`Phase.step` runs time whatever the event was),
			-- which is the property "a join that completes the roster starts the drive".
			local effects
			for userId = 1, 4 do
				state, effects = Phase.step(state, { kind = "join", userId = userId, name = "p" .. userId }, 0, cfg)
			end
			expect(state.phase).to.equal("Assigning")
			local held = heldIn(effects)
			expect(#held > 0).to.equal(true)
			for _, userId in ipairs(held) do
				expect(state.assignment[userId]).to.equal(cfg.START_HOLD_TEAM)
			end
			-- Through the countdown AND through the fanfare, nothing frees her.
			local collected
			state, collected = run(state, cfg, 0, cfg.INTERMISSION_SECONDS + 1.5, 0.25)
			expect(state.phase).to.equal("Running")
			expect(countKind(collected, "free")).to.equal(0)
		end)

		it("takes the fanfare hold off the horn's own measured phrase, not a number of its own", function()
			-- `Match.CONFIG.GO_HOLD_SECONDS` is `Horn.signalSeconds("start")`: the drive holds the
			-- line for exactly as long as the asset sounds, so a new phrase moves the hold with it.
			local HornData = require(ReplicatedStorage:WaitForChild("Horn"))
			local phrase = HornData.signalSeconds("start", HornData.CONFIG)
			expect(math.abs(Match.CONFIG.GO_HOLD_SECONDS - phrase) < 1e-9).to.equal(true)
			expect(phrase > 1).to.equal(true) -- a real phrase, not a rounding of zero
			expect(Phase.goHoldSeconds(Match.CONFIG)).to.equal(phrase)
			-- ZERO IS THIS FILE BEFORE TASK 168, and it is reachable by parameter.
			expect(Phase.goHoldSeconds({ GO_HOLD_SECONDS = 0 })).to.equal(0)
			expect(Phase.goHoldSeconds({})).to.equal(0)
		end)

		it("does not carry a pending hold into the results scene or the next drive", function()
			local cfg = config({ MIN_PLAYERS = 4, BOARS_PER_DRIVE = 0, GO_HOLD_SECONDS = 2, DRIVE_SECONDS = 1 })
			local state = assigning(cfg)
			-- The drive is one second long, so it ends INSIDE its own fanfare -- the pathological
			-- case, and the one that would otherwise free the ring at the gathering.
			local collected
			state, collected = run(state, cfg, cfg.INTERMISSION_SECONDS, 2, 0.25)
			expect(state.phase).to.equal("Scoring")
			expect(state.goFreed).to.equal(true)
			expect(state.goFreeAt).to.equal(math.huge)
			-- AND THE PENDING HOLD IS DROPPED RATHER THAN HANDED BACK: `Scoring` holds EVERYBODY for
			-- the results scene, so a `free` arriving here -- which is what a `goFreeAt` left standing
			-- would have emitted a quarter of a second later -- would let the ring wander off.
			local order = kinds(collected)
			expect(countKind(collected, "free")).to.equal(0)
			local releaseAt, holdAt = table.find(order, "release"), table.find(order, "hold")
			expect(releaseAt).to.be.ok()
			expect(holdAt).to.be.ok()
			-- The ties are released BEFORE the scene's hold, which is the order `enterScoring` has
			-- always had (a rope on a man standing at the gathering is two freezes on one character).
			expect((releaseAt :: number) < (holdAt :: number)).to.equal(true)
			-- And the next drive starts with nothing pending.
			state = (select(1, run(state, cfg, cfg.INTERMISSION_SECONDS + 2, cfg.SCORE_SECONDS + 1, 0.25)))
			expect(state.phase).to.equal("Assigning")
			expect(state.goFreeAt).to.equal(math.huge)
			expect(state.goFreed).to.equal(true)
		end)

		it("holds a player who is MADE a beater at GO, which is how the Forest Test does it", function()
			-- THE BUG KAREN REPORTED, AS A CASE. In the Forest Test the role switch is honoured on the
			-- `Running` transition (`ForestTestBoot`, task 157: the intermission has already respawned
			-- everybody once), so she became a beater one step AFTER `Assigning` -- and the old rule
			-- held somebody only DURING `Assigning`. MEASURED live, 2026-10-12: `team=Drivers
			-- walkSpeed=16 anchored=false` from the moment she was made one.
			local cfg = config({ MIN_PLAYERS = 4, BOARS_PER_DRIVE = 0, GO_HOLD_SECONDS = 2 })
			local state = assigning(cfg)
			local effects
			-- GO.
			state, effects = Phase.step(state, { kind = "tick", aliveBoars = 0 }, cfg.INTERMISSION_SECONDS, cfg)
			expect(state.phase).to.equal("Running")
			expect(Phase.lineHeld(state)).to.equal(true)
			-- A HUNTER IS MADE A BEATER INSIDE THE FANFARE: held, before the placement that moves her.
			local at = cfg.INTERMISSION_SECONDS + 0.2
			state, effects = Phase.step(state, { kind = "team", userId = 3, team = "Drivers" }, at, cfg)
			expect(state.assignment[3]).to.equal("Drivers")
			expect(table.concat(heldIn(effects), ",")).to.equal("3")
			local order = kinds(effects)
			expect((table.find(order, "hold") :: number) < (table.find(order, "placePlayers") :: number)).to.equal(true)
			-- ...AND LET GO WITH EVERYBODY ELSE AT THE END OF THE PHRASE, by the one `free`.
			local after
			state, after = run(state, cfg, at, 2, 0.25)
			expect(countKind(after, "free")).to.equal(1)
			expect(freedIn(after)).to.equal("all")
			expect(Phase.lineHeld(state)).to.equal(false)

			-- WELL INTO THE DRIVE NOBODY IS HELD, which is task 158's rule and is unchanged: a beater
			-- made then is far behind the line already. HALF A MINUTE AND NOT A WHOLE ONE, because
			-- this spec's `DRIVE_SECONDS` is 60 and a step at `at + 60` lands in `Scoring`, where the
			-- `team` branch does nothing at all -- which would be a case passing for the wrong reason.
			local late
			state, late = Phase.step(state, { kind = "team", userId = 4, team = "Drivers" }, at + 30, cfg)
			expect(state.phase).to.equal("Running")
			expect(state.assignment[4]).to.equal("Drivers")
			expect(countKind(late, "hold")).to.equal(0)
			-- ...AND A JOINER IS THE SAME RULE, through the same predicate.
			expect(Phase.lineHeld({ phase = "Assigning" } :: any)).to.equal(true)
			expect(Phase.lineHeld({ phase = "Running", goFreed = false } :: any)).to.equal(true)
			expect(Phase.lineHeld({ phase = "Running", goFreed = true } :: any)).to.equal(false)
			expect(Phase.lineHeld({ phase = "Scoring", goFreed = false } :: any)).to.equal(false)
			expect(Phase.lineHeld({ phase = "Waiting", goFreed = false } :: any)).to.equal(false)
		end)

		-- TASK 174: THE SIGNALS ARE THE RULES. KAREN, 2026-10-13 ~09:35: *"we can't walk or make a
		-- horn sound before horn anounce hunting started for beater / for hunter once hunt over
		-- (drive) horn anounce then I can; shoot anymore"*.
		--
		-- `Phase.driveOpen` IS THE ONE SOURCE the horn gate (`Match.mayBlowHorn`), the fire gate
		-- (`Weapon.Rules.driveClosed`, through `Match.driveOpen`) and the bot line's walk
		-- (`Match.botsMayGo`) all read, so this case states the WINDOW once, against the real machine
		-- and both of its endings, instead of three gates each stating it in its own words.
		it("opens the drive at GO and shuts it at the end, by the clock and by the line (task 174)", function()
			local cfg = config({ MIN_PLAYERS = 4, BOARS_PER_DRIVE = 0, GO_HOLD_SECONDS = 2 })
			local state = assigning(cfg)
			-- THE COUNTDOWN. The start signal has not sounded, so nothing is open -- and this is the
			-- half of Karen's rule the horn needed: a beater is already held still here (task 158).
			expect(state.phase).to.equal("Assigning")
			expect(Phase.driveOpen(state)).to.equal(false)

			-- `Running` BEGINS AND THE FANFARE IS STILL SOUNDING: still shut. GO is the END of the
			-- phrase (`Phase.goHoldSeconds`), which is the whole of task 168's correction.
			state = (Phase.step(state, { kind = "tick", aliveBoars = 0 }, cfg.INTERMISSION_SECONDS, cfg))
			expect(state.phase).to.equal("Running")
			expect(Phase.lineHeld(state)).to.equal(true)
			expect(Phase.driveOpen(state)).to.equal(false)

			-- GO. The one `free` has been emitted and the drive is open.
			local at
			state, _, at = run(state, cfg, cfg.INTERMISSION_SECONDS, 2.5, 0.25)
			expect(state.phase).to.equal("Running")
			expect(Phase.lineHeld(state)).to.equal(false)
			expect(Phase.driveOpen(state)).to.equal(true)

			-- ENDING 1, THE CLOCK (Karen's *"Timer"*).
			local byClock = (run(state, cfg, at, cfg.DRIVE_SECONDS, 0.25))
			expect(byClock.phase).to.equal("Scoring")
			expect(Phase.driveOpen(byClock)).to.equal(false)

			-- ENDING 2, THE LINE (*"or when all beaters cross line of hunters"*, task 159). The SAME
			-- answer, which is what makes "from the end signal" one rule and not two.
			local byLine = (Phase.step(state, { kind = "tick", beaters = 2, beatersAcross = 2 }, at + 1, cfg))
			expect(byLine.phase).to.equal("Scoring")
			expect(Phase.driveOpen(byLine)).to.equal(false)

			-- ...AND IT STAYS SHUT THROUGH THE RESULTS SCENE AND THE NEXT COUNTDOWN -- *"until the
			-- next drive's GO"* -- which is the span a hunter's trigger does nothing in.
			local nextDrive = (run(byLine, cfg, at + 1, cfg.SCORE_SECONDS + 1, 0.25))
			expect(nextDrive.phase).to.equal("Assigning")
			expect(Phase.driveOpen(nextDrive)).to.equal(false)

			-- THE HAND-WRITTEN STATES, which is the shape the three gates are driven with in their own
			-- files, and `nil` for a world with no drive at all.
			expect(Phase.driveOpen({ phase = "Running", goFreed = true } :: any)).to.equal(true)
			expect(Phase.driveOpen({ phase = "Running", goFreed = false } :: any)).to.equal(false)
			expect(Phase.driveOpen({ phase = "Assigning", goFreed = true } :: any)).to.equal(false)
			expect(Phase.driveOpen({ phase = "Scoring", goFreed = true } :: any)).to.equal(false)
			expect(Phase.driveOpen({ phase = "Waiting", goFreed = true } :: any)).to.equal(false)
			expect(Phase.driveOpen(nil)).to.equal(false)
			-- AND THE BOT LINE'S RULE IS THIS PREDICATE ITSELF since task 174, not a copy of it.
			expect(Match.botsMayGo({ phase = "Running", goFreed = true })).to.equal(true)
			expect(Match.botsMayGo({ phase = "Running", goFreed = false })).to.equal(false)
			expect(Match.botsMayGo(nil)).to.equal(false)
		end)

		it("asks the config who is held, so a spec can point it at either side", function()
			local assignment = { [1] = "Drivers" :: any, [2] = "Shooters" :: any, [3] = "Drivers" :: any }
			expect(table.concat(Phase.heldUserIds(assignment, { START_HOLD_TEAM = "Drivers" }), ",")).to.equal("1,3")
			expect(table.concat(Phase.heldUserIds(assignment, { START_HOLD_TEAM = "Shooters" }), ",")).to.equal("2")
			expect(#Phase.heldUserIds({}, { START_HOLD_TEAM = "Drivers" })).to.equal(0)
		end)
	end)

	describe("a world asks for one player to change sides", function()
		local function running(cfg)
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "Karen" }, 0, cfg))
			state = (run(state, cfg, 0, cfg.INTERMISSION_SECONDS + 1, 0.25))
			expect(state.phase).to.equal("Running")
			return state
		end

		it("reassigns exactly that player, with the three effects a join gets", function()
			local cfg = config({ BOARS_PER_DRIVE = 0 })
			local state = running(cfg)
			expect(state.assignment[1]).to.equal("Shooters") -- ODD_PLAYER_TEAM
			local effects
			-- WELL INSIDE THE DRIVE: this spec's `DRIVE_SECONDS` is 60, so a step at t=100 would be
			-- past the end and would carry `enterScoring`'s effects as well (measured, round 1).
			state, effects = Phase.step(state, { kind = "team", userId = 1, team = "Drivers" }, 30, cfg)
			expect(state.assignment[1]).to.equal("Drivers")
			expect(table.concat(kinds(effects), ",")).to.equal("assignTeams,placePlayers,refreshArming,broadcast")
			expect(state.phase).to.equal("Running")
			-- NO FEED LINE: the feed's kinds are a contract with the Hud's renderer, and a dev
			-- command in a playtest world is not an announcement.
			expect(countKind(effects, "feed")).to.equal(0)
		end)

		it("does nothing at all outside a drive", function()
			local cfg = config({ BOARS_PER_DRIVE = 0 })
			local state = ready(cfg)
			local effects
			state, effects = Phase.step(state, { kind = "team", userId = 1, team = "Drivers" }, 0, cfg)
			expect(state.phase).to.equal("Waiting")
			expect(state.assignment[1]).to.equal(nil)
			expect(#effects).to.equal(0)
		end)

		it("ignores a request for a player who is not in the drive", function()
			local cfg = config({ BOARS_PER_DRIVE = 0 })
			local state = running(cfg)
			local effects
			state, effects = Phase.step(state, { kind = "team", userId = 99, team = "Drivers" }, 30, cfg)
			expect(state.assignment[99]).to.equal(nil)
			expect(#effects).to.equal(0)
		end)

		it("is not sticky: the next drive swaps her back", function()
			-- Karen, 2026-10-11: *"you start as a hunter then next round you are beater"*. The
			-- rotation is `SWAP_TEAMS_EACH_DRIVE`, and a request that outlived its drive would pin
			-- her on one side for ever. The request moves THIS drive; the roster still decides the
			-- next one off `previousAssignment`.
			local cfg = config({ BOARS_PER_DRIVE = 0 })
			local state = running(cfg)
			state = (Phase.step(state, { kind = "team", userId = 1, team = "Drivers" }, 30, cfg))
			expect(state.assignment[1]).to.equal("Drivers")
			-- TO THE NEXT DRIVE, AND THE ASSERTION IS THE DRIVE NUMBER RATHER THAN A PHASE: the
			-- intermission is only `INTERMISSION_SECONDS` long, so which phase drive 2 is in depends
			-- on how far the window ran. What this case is about is the roster's own answer.
			local at = 30
			while state.driveNumber < 2 and at < 30 + cfg.DRIVE_SECONDS + cfg.SCORE_SECONDS + 10 do
				at += 0.5
				state = (Phase.step(state, { kind = "tick", aliveBoars = 0 }, at, cfg))
			end
			expect(state.driveNumber).to.equal(2)
			expect(state.assignment[1]).to.equal("Shooters")
		end)
	end)
	-- TASK 163. KAREN, 2026-10-12: *"when hunt starts 3 longer horn calls and when ends the same"*.
	-- The machine's whole share of that is ONE feed entry at GO and ONE at the end, whichever of the
	-- two endings it was -- the notes are `Horn.CONFIG.SIGNAL`'s and the sound is `Hud.Sound`'s.
	describe("the drive's horn signal", function()
		local function started(cfg)
			local state = ready(cfg)
			local effects
			state, effects = Phase.step(state, { kind = "join", userId = 1, name = "hunter" }, 0, cfg)
			-- The countdown does NOT signal: the horn goes at GO, not at the card.
			expect(countFeed(effects, "signal")).to.equal(0)
			state, effects = Phase.step(state, { kind = "tick" }, cfg.INTERMISSION_SECONDS, cfg)
			expect(state.phase).to.equal("Running")
			return state, effects
		end

		it("sounds exactly once at GO, and says which signal it is", function()
			local cfg = config()
			local _, effects = started(cfg)
			expect(countFeed(effects, "signal")).to.equal(1)
			expect(feedText(effects, "signal")).to.equal("start")
		end)

		it("does not sound again on any later tick of the same drive", function()
			local cfg = config()
			local state = started(cfg)
			local collected
			state, collected = run(state, cfg, cfg.INTERMISSION_SECONDS, cfg.DRIVE_SECONDS - 1, 0.25)
			expect(state.phase).to.equal("Running")
			expect(countFeed(collected, "signal")).to.equal(0)
		end)

		it("sounds exactly once when the clock ends the drive", function()
			local cfg = config({ END_ON_BEATERS_CROSS = true })
			local state = started(cfg)
			local effects
			state, effects = Phase.step(
				state,
				{ kind = "tick", beaters = 2, beatersAcross = 0 },
				cfg.INTERMISSION_SECONDS + cfg.DRIVE_SECONDS,
				cfg
			)
			expect(state.phase).to.equal("Scoring")
			expect(state.endedEarly).to.equal(false)
			expect(countFeed(effects, "signal")).to.equal(1)
			expect(feedText(effects, "signal")).to.equal("end")
		end)

		it("sounds exactly once when the BEATERS end the drive -- the other ending, same signal", function()
			local cfg = config({ END_ON_BEATERS_CROSS = true })
			local state = ready(cfg)
			state = (Phase.step(state, { kind = "join", userId = 1, name = "hunter" }, 0, cfg))
			state = (Phase.step(state, { kind = "join", userId = 2, name = "beater" }, 0, cfg))
			state = (Phase.step(state, { kind = "tick" }, cfg.INTERMISSION_SECONDS, cfg))
			local at = cfg.INTERMISSION_SECONDS + 5
			local effects
			state, effects = Phase.step(state, { kind = "tick", beaters = 2, beatersAcross = 2 }, at, cfg)
			expect(state.phase).to.equal("Scoring")
			expect(state.endedEarly).to.equal(true)
			expect(countFeed(effects, "signal")).to.equal(1)
			-- THE SAME WORD AS THE CLOCK'S ENDING, which is the decision: Karen said *"when ends the
			-- same"*, so the two endings are one signal and `reason` is not read.
			expect(feedText(effects, "signal")).to.equal("end")
		end)

		it("sounds once per drive and no more, across two whole drives", function()
			local cfg = config()
			local state = started(cfg)
			local collected
			-- The rest of drive 1, the whole results scene, drive 2's countdown, drive 2 and its end.
			state, collected = run(
				state,
				cfg,
				cfg.INTERMISSION_SECONDS,
				cfg.DRIVE_SECONDS + cfg.SCORE_SECONDS + cfg.INTERMISSION_SECONDS + cfg.DRIVE_SECONDS,
				0.25,
				0
			)
			expect(state.driveNumber).to.equal(2)
			-- drive 1's end, drive 2's GO, drive 2's end.
			expect(countFeed(collected, "signal")).to.equal(3)
		end)

		it("is silent with SIGNAL_ENABLED false, so both states are reachable by parameter", function()
			local cfg = config({ SIGNAL_ENABLED = false })
			local state = ready(cfg)
			local effects
			state, effects = Phase.step(state, { kind = "join", userId = 1, name = "hunter" }, 0, cfg)
			state, effects = Phase.step(state, { kind = "tick" }, cfg.INTERMISSION_SECONDS, cfg)
			expect(state.phase).to.equal("Running")
			expect(countFeed(effects, "signal")).to.equal(0)
			-- ...and the phase LINE is untouched: the switch is the horn's and nothing else's.
			expect(feedText(effects, "phase")).to.equal("Drive on")
			state, effects = Phase.step(state, { kind = "tick" }, cfg.INTERMISSION_SECONDS + cfg.DRIVE_SECONDS, cfg)
			expect(state.phase).to.equal("Scoring")
			expect(countFeed(effects, "signal")).to.equal(0)
		end)
	end)
end
