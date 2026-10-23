-- lobby_next.spec: THE PARTY THAT GOES AGAIN, driven with hand-written numbers -- no world, no
-- drive, no clock and no player. `Lobby.Next` is pure, which is what lets a whole drive-to-drive
-- cycle run here in microseconds instead of in a 300-second Play session.
--
-- KAREN, 2026-10-23: *"we need continues game so after drive new drive imidiatly after same amount
-- seconds and who has licesne can select who he can be next round if dont then oposit previuos
-- round"*.
--
-- **EVERY ARM IS ENTERED EXPLICITLY, AND THAT IS LEARNING AGENT L-093'S LESSON** (three recurrences
-- in one task: BoarArt's mirror, HitCard's fade and the 14-frame fallback all shipped unreachable).
-- The five verdicts are IDLE, WAITING, COUNTING, GO and CLEARED, and there is a case that reaches
-- each of them BY NAME -- plus one for every way the membership can shrink under the countdown.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/lobby.md (sections 4, 6, 8)
-- Note:   docs/research/2026-10-23-the-continuous-drive-loop.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = require(ReplicatedStorage:WaitForChild("Lobby"))
local Lobby = require(ServerScriptService:WaitForChild("Lobby"))

local Next = Lobby.Next
local CFG = Data.CONFIG.PADS.NEXT

-- THE THREE SETS THE OWNER MEASURES, as a helper, so a case states only what it is about: everybody
-- named is present unless the case says otherwise.
local function facts(ids: { number }, inDrive: { number }?, held: { number }?)
	local out = { present = {}, inDrive = {}, held = {} }
	for _, id in ipairs(ids) do
		out.present[id] = true
	end
	for _, id in ipairs(inDrive or {}) do
		out.inDrive[id] = true
	end
	for _, id in ipairs(held or {}) do
		out.held[id] = true
	end
	return out
end

return function()
	describe("the empty party", function()
		it("is IDLE and holds nobody", function()
			local state = Next.initial()
			expect(Next.count(state)).to.equal(0)
			expect(Next.secondsLeft(state, 100)).to.equal(nil)
			local after, verdict, going = Next.step(state, facts({ 1 }), 100, CFG)
			expect(verdict).to.equal(Next.IDLE)
			expect(#going).to.equal(0)
			-- BY IDENTITY: an empty state that needs no normalising is handed straight back, so the
			-- owner's `nextDrive = state` allocates nothing on a server with no drive running.
			expect(after).to.equal(state)
		end)

		it("normalises a deadline that has no members left behind it", function()
			-- A HAND-WRITTEN BROKEN STATE, which is the only way to reach this branch: a number on
			-- nobody's screen. It cannot be produced by `collect` plus `step`, and that is exactly
			-- why it is asserted rather than assumed.
			local broken = { members = {}, sitOut = { [7] = true }, at = 500, since = 490 }
			local after, verdict = Next.step(broken, facts({ 7 }), 501, CFG)
			expect(verdict).to.equal(Next.IDLE)
			expect(after.at).to.equal(nil)
			expect(next(after.sitOut)).to.equal(nil)
		end)
	end)

	describe("collecting the roster", function()
		it("takes the whole roster, both sides, with no team read anywhere", function()
			-- KAREN'S FIRST SENTENCE: *"back to lobby after hunt to have the same not saperate for
			-- beaters"*. This module keys by userId and has no idea what a team is, so one list is
			-- the structural answer rather than a rule that could be forgotten.
			local state = Next.collect(Next.initial(), { 3, 1, 2 }, 100)
			expect(Next.count(state)).to.equal(3)
			expect(Next.has(state, 1)).to.equal(true)
			expect(Next.has(state, 2)).to.equal(true)
			expect(Next.has(state, 3)).to.equal(true)
			-- SORTED, so the owner's attribute writes and the list handed to `depart` are the same
			-- order every time.
			local ids = Next.ids(state)
			expect(ids[1]).to.equal(1)
			expect(ids[3]).to.equal(3)
			expect(state.at).to.equal(nil)
			expect(state.since).to.equal(100)
		end)

		it("clears every opt-out, so by default they are in at the start of every gap", function()
			local first = Next.sit(Next.collect(Next.initial(), { 1, 2 }, 100), 1, true)
			expect(Next.isOut(first, 1)).to.equal(true)
			local second = Next.collect(first, { 1, 2 }, 400)
			expect(Next.isOut(second, 1)).to.equal(false)
			expect(#Next.goers(second)).to.equal(2)
		end)

		it("replaces the party and never merges it", function()
			local first = Next.collect(Next.initial(), { 1, 2 }, 100)
			local second = Next.collect(first, { 3 }, 400)
			expect(Next.count(second)).to.equal(1)
			expect(Next.has(second, 1)).to.equal(false)
			expect(Next.has(second, 3)).to.equal(true)
		end)

		it("is frozen, so nothing outside this module can write a membership", function()
			local state = Next.collect(Next.initial(), { 1 }, 100)
			expect(table.isfrozen(state)).to.equal(true)
			expect(table.isfrozen(state.members)).to.equal(true)
			expect(table.isfrozen(state.sitOut)).to.equal(true)
		end)

		it("collects nobody from a drive that ended empty", function()
			local state = Next.collect(Next.initial(), {}, 100)
			local _after, verdict = Next.step(state, facts({ 1 }), 100, CFG)
			expect(verdict).to.equal(Next.IDLE)
		end)
	end)

	describe("WAITING: the results scene is still up", function()
		it("sets no deadline while anybody in the party is still held", function()
			-- THIS IS THE ORDER KAREN ASKED FOR -- the lodge FIRST, then the wait -- and it is one
			-- predicate: `held` is the results scene (`enterScoring` holds the whole roster), so the
			-- countdown cannot start until the same `free` that lets the return rule walk them home.
			local state = Next.collect(Next.initial(), { 1, 2 }, 100)
			local after, verdict, going = Next.step(state, facts({ 1, 2 }, nil, { 2 }), 101, CFG)
			expect(verdict).to.equal(Next.WAITING)
			expect(after.at).to.equal(nil)
			expect(Next.secondsLeft(after, 101)).to.equal(nil)
			-- NOTHING IS OFFERED while there is no countdown: the card is down and so is its list.
			expect(#going).to.equal(0)
		end)

		it("arms the moment the last man is let go", function()
			local state = Next.collect(Next.initial(), { 1, 2 }, 100)
			state = (Next.step(state, facts({ 1, 2 }, nil, { 1, 2 }), 101, CFG))
			local after, verdict = Next.step(state, facts({ 1, 2 }), 105, CFG)
			expect(verdict).to.equal(Next.COUNTING)
			expect(after.at).to.equal(105 + CFG.SECONDS)
			expect(Next.secondsLeft(after, 105)).to.equal(CFG.SECONDS)
		end)

		it("arms anyway after ARM_TIMEOUT_SECONDS, so one stuck man cannot stop the loop", function()
			-- HAZARD 1 OF THE NOTE, and it is reachable BY PARAMETER rather than by a wedged drive:
			-- player 2 is held for ever, which is what a character that never loads looks like.
			local state = Next.collect(Next.initial(), { 1, 2 }, 100)
			local held = facts({ 1, 2 }, nil, { 2 })
			local before, verdict = Next.step(state, held, 100 + CFG.ARM_TIMEOUT_SECONDS - 0.5, CFG)
			expect(verdict).to.equal(Next.WAITING)
			expect(before.at).to.equal(nil)
			local at = 100 + CFG.ARM_TIMEOUT_SECONDS
			local after, late = Next.step(before, held, at, CFG)
			expect(late).to.equal(Next.COUNTING)
			expect(after.at).to.equal(at + CFG.SECONDS)
		end)
	end)

	describe("COUNTING, and then GO", function()
		local function armed(ids: { number })
			local state = Next.collect(Next.initial(), ids, 100)
			local after = (Next.step(state, facts(ids), 100, CFG))
			return after
		end

		it("counts down and then hands the owner exactly who goes", function()
			local state = armed({ 1, 2 })
			expect(state.at).to.equal(100 + CFG.SECONDS)
			local mid, counting = Next.step(state, facts({ 1, 2 }), 104, CFG)
			expect(counting).to.equal(Next.COUNTING)
			expect(Next.secondsLeft(mid, 104)).to.equal(CFG.SECONDS - 4)
			local after, verdict, going = Next.step(mid, facts({ 1, 2 }), 100 + CFG.SECONDS, CFG)
			expect(verdict).to.equal(Next.GO)
			expect(#going).to.equal(2)
			expect(going[1]).to.equal(1)
			-- THE PARTY IS CLEARED IN THE SAME STEP, which is what makes GO happen ONCE however many
			-- scans land in the same tenth of a second.
			expect(Next.count(after)).to.equal(0)
			local _again, idle = Next.step(after, facts({ 1, 2 }), 100 + CFG.SECONDS + 0.1, CFG)
			expect(idle).to.equal(Next.IDLE)
		end)

		it("never offers a man the drive already has", function()
			-- HAZARD 2: he walked onto a truck pad during the countdown and that pad departed. The
			-- membership test is `inDrive`, asked every scan, which is the same fact `occupancy`
			-- already drops a man from a pad list for -- so there is no second check to forget.
			local state = armed({ 1, 2 })
			local after, verdict, going = Next.step(state, facts({ 1, 2 }, { 2 }), 100 + CFG.SECONDS, CFG)
			expect(verdict).to.equal(Next.GO)
			expect(#going).to.equal(1)
			expect(going[1]).to.equal(1)
			expect(Next.count(after)).to.equal(0)
		end)

		it("drops a man who left the server, and clears when the last one goes", function()
			local state = armed({ 1, 2 })
			local one, counting = Next.step(state, facts({ 1 }), 102, CFG)
			expect(counting).to.equal(Next.COUNTING)
			expect(Next.count(one)).to.equal(1)
			expect(Next.has(one, 2)).to.equal(false)
			local after, verdict = Next.step(one, facts({}), 103, CFG)
			expect(verdict).to.equal(Next.CLEARED)
			expect(Next.count(after)).to.equal(0)
			expect(after.at).to.equal(nil)
		end)

		it("takes a man's opt-out away with him", function()
			local state = Next.sit(armed({ 1, 2 }), 2, true)
			expect(Next.isOut(state, 2)).to.equal(true)
			local after = (Next.step(state, facts({ 1 }), 102, CFG))
			expect(Next.isOut(after, 2)).to.equal(false)
			expect(next(after.sitOut)).to.equal(nil)
		end)
	end)

	describe("SIT OUT", function()
		local function armed(ids: { number })
			return (Next.step(Next.collect(Next.initial(), ids, 100), facts(ids), 100, CFG))
		end

		it("takes him out of the list that goes, and leaves the countdown running", function()
			-- *"A player who wants to stop: give a SIT OUT control... By default they are in."*
			local state = Next.sit(armed({ 1, 2 }), 1, true)
			expect(Next.isOut(state, 1)).to.equal(true)
			-- THE DEADLINE IS UNTOUCHED: that is what lets the last of them change his mind.
			expect(state.at).to.equal(100 + CFG.SECONDS)
			local goers = Next.goers(state)
			expect(#goers).to.equal(1)
			expect(goers[1]).to.equal(2)
			local _after, verdict, going = Next.step(state, facts({ 1, 2 }), 100 + CFG.SECONDS, CFG)
			expect(verdict).to.equal(Next.GO)
			expect(#going).to.equal(1)
			expect(going[1]).to.equal(2)
		end)

		it("is reversible until the deadline", function()
			local out = Next.sit(armed({ 1 }), 1, true)
			expect(#Next.goers(out)).to.equal(0)
			local back = Next.sit(out, 1, false)
			expect(Next.isOut(back, 1)).to.equal(false)
			local _after, verdict, going = Next.step(back, facts({ 1 }), 100 + CFG.SECONDS, CFG)
			expect(verdict).to.equal(Next.GO)
			expect(#going).to.equal(1)
		end)

		it("ends the gap with nobody going when everybody sits out", function()
			local state = Next.sit(Next.sit(armed({ 1, 2 }), 1, true), 2, true)
			local after, verdict, going = Next.step(state, facts({ 1, 2 }), 100 + CFG.SECONDS, CFG)
			-- CLEARED AND NOT GO: nothing is handed to `Lobby.depart`, so nothing is enrolled -- and
			-- the countdown still RAN, which is the whole reason the opt-out is not a removal.
			expect(verdict).to.equal(Next.CLEARED)
			expect(#going).to.equal(0)
			expect(Next.count(after)).to.equal(0)
		end)

		it("refuses a stranger, so the opt-out set can never name a man with no party", function()
			local state = armed({ 1 })
			local after = Next.sit(state, 99, true)
			expect(after).to.equal(state)
			expect(Next.isOut(after, 99)).to.equal(false)
		end)

		it("is a no-op for a value it already holds, so a double press writes nothing", function()
			local out = Next.sit(armed({ 1 }), 1, true)
			expect(Next.sit(out, 1, true)).to.equal(out)
			local back = Next.sit(out, 1, false)
			expect(Next.sit(back, 1, false)).to.equal(back)
		end)
	end)

	describe("the numbers", function()
		it("waits the between-drive length the Director's brief names", function()
			-- 8, which is `Match.CONFIG.SCORE_SECONDS` after Karen's *"make 8s max"* -- and inside
			-- Valve's own clamp for the same gap (`mp_bonusroundtime`, 5..15).
			expect(CFG.SECONDS).to.equal(8)
			expect(CFG.SECONDS >= 5).to.equal(true)
			expect(CFG.SECONDS <= 15).to.equal(true)
		end)

		it("bounds the arming by a timeout longer than the whole results scene", function()
			local Match = require(ServerScriptService:WaitForChild("Match"))
			expect(CFG.ARM_TIMEOUT_SECONDS > Match.CONFIG.SCORE_SECONDS).to.equal(true)
		end)
	end)
end
