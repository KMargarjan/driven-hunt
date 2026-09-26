-- match_phase.spec: the whole match state machine, driven with no players, no boars, no Instances
-- and no clock. Match.Phase is pure and returns (state, effects), so a ten-minute drive -- with
-- joins, leaves, kills and a server hitch -- runs here in milliseconds and every assertion is
-- against a plain table.
--
-- Time is simulated: `now` is a number this spec increments. There is no task.wait in this file.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/drive.md (sections 4, 12.1)
local ServerScriptService = game:GetService("ServerScriptService")

local Match = require(ServerScriptService:WaitForChild("Match"))
local Phase = Match.Phase

-- This spec's own numbers, short enough to read in a failure message.
local CONFIG = {
	DRIVE_SECONDS = 60,
	INTERMISSION_SECONDS = 10,
	SCORE_SECONDS = 5,
	MIN_PLAYERS = 1,
	MAX_PLAYERS = 16,
	ODD_PLAYER_TEAM = "Shooters",
	SWAP_TEAMS_EACH_DRIVE = true,
	BOARS_PER_DRIVE = 4,
	FIRST_RELEASE_SECONDS = 5,
	RELEASE_INTERVAL_SECONDS = 10,
	RELEASE_JITTER_SECONDS = 0, -- jitter has its own test; every other one wants exact times
	MAX_ALIVE_BOARS = 2,
	SEED = 7,
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
			expect(countKind(collected, "spawnBoar")).to.equal(cfg.BOARS_PER_DRIVE)

			-- every release carries one of the tagged spawn positions
			for _, effect in ipairs(collected) do
				if effect.kind == "spawnBoar" then
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
			expect(countKind(blocked, "spawnBoar")).to.equal(0)

			-- ...and the moment one is gone, the held release happens on the next tick.
			local effects
			state, effects = Phase.step(state, { kind = "tick", aliveBoars = 0 }, cfg.INTERMISSION_SECONDS + 21, cfg)
			expect(countKind(effects, "spawnBoar")).to.equal(1)
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
			expect(countKind(effects, "spawnBoar")).to.equal(0)
			expect(state.releasesDone).to.equal(0) -- nothing was consumed

			-- ...and the moment there is room, the release that was held back happens.
			state, effects = Phase.step(state, { kind = "tick", aliveBoars = 0 }, at + 0.25, cfg)
			expect(countKind(effects, "spawnBoar")).to.equal(1)
			expect(state.releasesDone).to.equal(1)
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
			expect(countKind(effects, "spawnBoar")).to.equal(1)
			expect(state.releasesDone).to.equal(1)

			state = Phase.releaseFailed(state, at)
			expect(state.releasesDone).to.equal(0)

			-- due again immediately, not one RELEASE_INTERVAL_SECONDS later
			state, effects = Phase.step(state, { kind = "tick", aliveBoars = 0 }, at + 0.25, cfg)
			expect(countKind(effects, "spawnBoar")).to.equal(1)
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
end
