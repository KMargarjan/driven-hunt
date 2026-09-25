--!strict
-- Weapon.StateMachine: the pure reducer for one player's weapon. No Instances, no services, no
-- clock, no Player -- `now` is a parameter. It is the ONLY place a WeaponState is produced, and
-- every state it returns is a new deep-frozen table, so a caller cannot mutate history.
--
-- Pattern: reducer, (state, action, now) -> (state, reason?), the shape Boar.Brain uses for the
-- boar's decisions (src/server/Boar/Brain.luau). One decision in one place is rule 3 applied inside
-- a system: "uninterruptible reload" is not a flag, it is `Break` and `Fire` both requiring
-- `open == false` (design section 5.5).
--   Luau table.freeze / table.clone  https://luau.org/library#table-library (both shallow)
--
-- Design: docs/design/shotgun.md (sections 5.3, 12)
-- Note:   docs/research/2026-09-24-shotgun.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

type WeaponState = Shotgun.WeaponState
type Action = Shotgun.Action

local StateMachine = {}

function StateMachine.initial(config): WeaponState
	local barrels, loaded = {}, {}
	for index = 1, config.BARRELS do
		barrels[index] = "Live"
		loaded[index] = config.INITIAL_AMMO
	end
	return Shotgun.deepFreeze({
		equipped = false,
		open = false,
		barrels = barrels,
		loaded = loaded,
		selected = 1,
		ammo = config.INITIAL_AMMO,
		reserve = config.START_RESERVE,
		busyUntil = 0,
		epoch = 0,
	})
end

-- A mutable copy, deep enough for the two arrays this state owns (table.clone is shallow).
local function draft(state: WeaponState)
	local copy = table.clone(state) :: any
	copy.barrels = table.clone(state.barrels)
	copy.loaded = table.clone(state.loaded)
	return copy
end

-- The one writer of `equipped`. The server derives it from the Tool's Parent (design section 5.4),
-- never from a client claim.
function StateMachine.setEquipped(state: WeaponState, equipped: boolean): WeaponState
	if state.equipped == equipped then
		return state
	end
	local next = draft(state)
	next.equipped = equipped
	return Shotgun.deepFreeze(next)
end

-- The next live barrel after `from`, or `from` itself when none is live.
local function nextLive(barrels, from: number): number
	for offset = 1, #barrels do
		local index = (from - 1 + offset) % #barrels + 1
		if barrels[index] == "Live" then
			return index
		end
	end
	return from
end

-- Returns (newState, nil) or (the SAME state, reason). Rejection reasons are a closed set, so the
-- owner and the specs can name them: "busy", "is-open", "is-closed", "not-equipped",
-- "barrel-empty", "no-reserve", "barrel-full", "bad-action".
function StateMachine.apply(state: WeaponState, action: Action, now: number): (WeaponState, string?)
	local config = Shotgun.CONFIG
	local kind = action.kind

	if kind ~= "SelectAmmo" and now < state.busyUntil then
		return state, "busy"
	end

	if kind == "Fire" then
		if not state.equipped then
			return state, "not-equipped"
		end
		if state.open then
			return state, "is-open"
		end
		if state.barrels[state.selected] ~= "Live" then
			return state, "barrel-empty"
		end
		local next = draft(state)
		next.barrels[state.selected] = "Spent"
		next.loaded[state.selected] = "None"
		-- Feel default 4: automatic barrel select. `selected` moves to the other barrel only when
		-- that barrel is live, so an empty gun does not shuffle its selection.
		next.selected = nextLive(next.barrels, state.selected)
		next.busyUntil = now + config.BARREL_DELAY
		return Shotgun.deepFreeze(next), nil
	elseif kind == "Break" then
		if not state.equipped then
			return state, "not-equipped"
		end
		if state.open then
			-- This is what makes the reload uninterruptible: a second Reload cannot start one.
			return state, "is-open"
		end
		local next = draft(state)
		next.open = true
		for index = 1, #next.barrels do
			next.barrels[index] = "Empty"
			next.loaded[index] = "None"
		end
		next.busyUntil = now + config.RELOAD_BREAK
		return Shotgun.deepFreeze(next), nil
	elseif kind == "Load" then
		if not state.open then
			return state, "is-closed"
		end
		if state.reserve <= 0 then
			return state, "no-reserve"
		end
		local target = nil
		for index = 1, #state.barrels do
			if state.barrels[index] == "Empty" then
				target = index
				break
			end
		end
		if not target then
			return state, "barrel-full"
		end
		local next = draft(state)
		next.barrels[target] = "Live"
		next.loaded[target] = state.ammo
		next.reserve = state.reserve - 1
		next.busyUntil = now + config.RELOAD_SHELL
		return Shotgun.deepFreeze(next), nil
	elseif kind == "Close" then
		if not state.open then
			return state, "is-closed"
		end
		local next = draft(state)
		next.open = false
		next.selected = nextLive(next.barrels, #next.barrels)
		next.busyUntil = now + config.RELOAD_CLOSE
		return Shotgun.deepFreeze(next), nil
	elseif kind == "SelectAmmo" then
		local ammo = action.ammo
		if ammo ~= "Slug" and ammo ~= "Buck" then
			return state, "bad-action"
		end
		local next = draft(state)
		-- Only the NEXT load's kind. Shells already in the barrels are never rewritten.
		next.ammo = ammo
		return Shotgun.deepFreeze(next), nil
	end

	return state, "bad-action"
end

return StateMachine
