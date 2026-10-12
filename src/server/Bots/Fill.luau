--!strict
-- Bots.Fill: HOW MANY BOTS A DRIVE WANTS. PURE -- no services, no Instances, no clock, no Random, and
-- it never knows what a Player is. It takes two counts and a config and returns two counts, which is
-- what lets tests/server/bots_fill.spec.luau check every roster from 0 to 8 per side in microseconds
-- with no players, no rigs and no drive.
--
-- Pattern: ioquake3's `G_CheckMinimumPlayers` (`code/game/g_bot.c`, GPL-2.0, fetched and quoted in
-- the note), re-pointed. https://github.com/ioquake/ioq3/blob/main/code/game/g_bot.c
--
-- WHAT IS BORROWED:
--   * the target is PER TEAM, not per server -- Quake counts and fills `TEAM_RED` and `TEAM_BLUE`
--     separately, which is Karen's "4 hunters 4 beaters" and not "8 bodies";
--   * the count is `humanplayers + botplayers` against the target, so the arithmetic is ONE
--     subtraction;
--   * ADD AND REMOVE ARE SYMMETRIC (`> minplayers && botplayers` removes one), so a bot hands its
--     slot back the moment a real player takes it. Here that is structural: this function is
--     level-triggered, so "remove" is just a smaller answer;
--   * `if (minplayers <= 0) return;` -- THE TARGET IS THE SWITCH. A target of 0 for a side is that
--     side off, with no second boolean beside it.
--
-- WHAT IS CHANGED, AND WHY (rule 2):
--   * Quake POLLS ("only check once each 10 seconds") and refuses while `level.intermissiontime` is
--     set. We have the thing that poll is approximating -- `Match.Phase`'s own transitions -- so the
--     drive calls this at its boundaries and a timer here would be a second answer to "is the roster
--     settled".
--   * its slot reserve (`minplayers >= g_maxclients/2` keeps a connection free for a human) is
--     DROPPED: a Quake bot occupies a client slot and can lock a joiner out, and a rig is not a
--     client and cannot consume a connection. What replaces it is `standsFree`, which is about
--     STANDS: a bot hunter needs a post of its own, because two hunters on one post is one hunter.
--
-- Design: docs/design/bots.md (sections 7, 13, 14)
-- Note:   docs/research/2026-10-12-bots.md (section 2.1)
local Fill = {}

export type Counts = { hunters: number, beaters: number }

local function clampLow(value: number): number
	return if value > 0 then value else 0
end

-- `real` is how many REAL players are on each side of THIS drive (the drive reads it off its own
-- assignment). `standsFree` is how many posts no real hunter is standing on. The answer is how many
-- rigs to build per side, and it is total-capped.
--
-- THE TRIM TAKES BEATERS FIRST, and it is deterministic rather than "whichever side is bigger": a
-- bot hunter is standing on a stand the drive aimed at, and a beater line one short is still a line.
-- With the shipped numbers (`TARGET.hunters + TARGET.beaters == MAX_BOTS`) the trim is unreachable,
-- and `bots_fill.spec` asserts that relation -- the `MAX_ALIVE_BOARS >= SOUNDER.MAX_SIZE` idiom, so
-- "unreachable" is a claim somebody checks and not a coincidence of two numbers.
function Fill.counts(real: Counts, config, standsFree: number?): Counts
	local bots = config.BOTS
	if bots == nil or bots.ENABLED ~= true then
		return { hunters = 0, beaters = 0 }
	end
	local target = bots.TARGET or {}
	local hunters = clampLow((target.hunters or 0) - (real.hunters or 0))
	local beaters = clampLow((target.beaters or 0) - (real.beaters or 0))

	-- A BOT HUNTER NEEDS A STAND OF ITS OWN. `nil` means "the caller did not measure the stands",
	-- which is every pure spec and the arena, and is NOT the same fact as "there are no stands" --
	-- so it does not clamp. A real 0 does.
	if standsFree ~= nil then
		local room = clampLow(standsFree)
		if hunters > room then
			hunters = room
		end
	end

	local cap = bots.MAX_BOTS or (hunters + beaters)
	local over = (hunters + beaters) - cap
	if over > 0 then
		local fromBeaters = if over < beaters then over else beaters
		beaters -= fromBeaters
		over -= fromBeaters
		if over > 0 then
			hunters = clampLow(hunters - over)
		end
	end
	return { hunters = hunters, beaters = beaters }
end

-- How many of a marker set's posts no real hunter is standing on. The drive knows how many real
-- hunters it has; this is the subtraction, kept here so `Fill` holds the whole arithmetic of "how
-- many" and the owner holds none of it.
function Fill.standsFree(postCount: number, realHunters: number): number
	return clampLow(postCount - realHunters)
end

return Fill
