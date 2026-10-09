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

-- THE ROW IS THE CONFIG (task 140). `initial` always read `BARRELS`, `INITIAL_AMMO` and
-- `START_RESERVE` off whatever it was handed, and a weapon row carries all three -- so a two-barrel
-- shotgun and a one-chamber rifle start from the same function with no branch in it.
function StateMachine.initial(config): WeaponState
	local barrels, loaded = {}, {}
	for index = 1, config.BARRELS do
		barrels[index] = "Live"
		loaded[index] = config.INITIAL_AMMO
	end
	-- A copy: CONFIG.START_RESERVE is deep-frozen, and this one is about to be spent.
	local reserve = table.clone(config.START_RESERVE)
	return Shotgun.deepFreeze({
		equipped = false,
		open = false,
		barrels = barrels,
		loaded = loaded,
		selected = 1,
		ammo = config.INITIAL_AMMO,
		reserve = reserve,
		busyUntil = 0,
		epoch = 0,
	})
end

-- A mutable copy, deep enough for the two arrays this state owns (table.clone is shallow).
local function draft(state: WeaponState)
	local copy = table.clone(state) :: any
	copy.barrels = table.clone(state.barrels)
	copy.loaded = table.clone(state.loaded)
	copy.reserve = table.clone(state.reserve)
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

-- HOW LONG THIS WEAPON'S ACTION IS BUSY AFTER ONE STEP OF ITS CYCLE (task 140). The sequence and
-- its timings are data on the row (`CYCLE`), because a bolt is not a break-action with different
-- numbers: it is three steps where the shotgun has four. The first step of that kind is the answer,
-- which is exactly right for the shotgun's two identical `Load`s.
-- IT SEARCHES BOTH OF THE WEAPON'S SEQUENCES (task 142), not just `CYCLE`. A magazine rifle has
-- two -- the bolt (`CYCLE`) and the magazine change (`RELOAD`) -- and `Magazine` appears only in the
-- second, so a lookup that read `CYCLE` alone answered 0 for it: MEASURED in the Forest Test, the
-- step published `action=Magazine busy=0.00` and the whole 1.35 s window did not exist, which is
-- why the drawn box never moved. `Break` and `Close` are in both lists with the same waits, so the
-- order between them decides nothing.
local function waitFor(row, kind: string): number
	for _, list in ipairs({ row.CYCLE, row.RELOAD }) do
		if list ~= nil then
			for _, step in ipairs(list) do
				if step.kind == kind then
					return step.wait
				end
			end
		end
	end
	return 0
end

-- Returns (newState, nil) or (the SAME state, reason). Rejection reasons are a closed set, so the
-- owner and the specs can name them: "busy", "is-open", "is-closed", "not-equipped",
-- "barrel-empty", "no-reserve", "barrel-full", "bad-action".
--
-- `row` IS REQUIRED AND HAS NO DEFAULT (task 140). This function used to read `Shotgun.CONFIG` at
-- its top, which with two weapons is a rifle timed like a shotgun, silently. No default means every
-- caller has to say which weapon it means.
function StateMachine.apply(state: WeaponState, action: Action, now: number, row): (WeaponState, string?)
	local config = row
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
		-- WHAT OPENING THE ACTION EJECTS IS THE WEAPON'S OWN RULE (task 142), because a bolt is not
		-- a break action with different numbers. `"all"` is the shotgun: you crack it over your arm
		-- and everything in it comes out. `"spent"` is a magazine rifle: working the bolt throws the
		-- FIRED CASE and leaves the rest of the magazine where it is -- and without this the rifle's
		-- own auto-cycle would have dumped two live rounds on the ground after every shot.
		local ejects = config.CYCLE_EJECTS or "all"
		for index = 1, #next.barrels do
			local chamber = next.barrels[index]
			if ejects == "spent" and chamber ~= "Spent" then
				continue
			end
			-- An UNFIRED shell goes back into its own pocket (Karen, 2026-09-25: "the unfired shells
			-- of the old type go back to the reserve"); a spent case is gone. One rule, in the one
			-- place that owns the action.
			local loadedKind = next.loaded[index]
			if chamber == "Live" and loadedKind ~= "None" then
				next.reserve[loadedKind] = (next.reserve[loadedKind] or 0) + 1
			end
			next.barrels[index] = "Empty"
			next.loaded[index] = "None"
		end
		next.busyUntil = now + waitFor(row, "Break")
		return Shotgun.deepFreeze(next), nil
	elseif kind == "Load" then
		if not state.open then
			return state, "is-closed"
		end
		if (state.reserve[state.ammo] or 0) <= 0 then
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
		next.reserve[state.ammo] = next.reserve[state.ammo] - 1
		next.busyUntil = now + waitFor(row, "Load")
		return Shotgun.deepFreeze(next), nil
	elseif kind == "Close" then
		if not state.open then
			return state, "is-closed"
		end
		local next = draft(state)
		next.open = false
		next.selected = nextLive(next.barrels, #next.barrels)
		next.busyUntil = now + waitFor(row, "Close")
		return Shotgun.deepFreeze(next), nil
	elseif kind == "Magazine" then
		-- THE MAGAZINE CHANGE, IN ONE STEP. Karen: *"in magazine 3 shells then it changes with left
		-- hand magazine"*. Every empty chamber is filled from the pocket at once, which is what
		-- swapping a box of three IS; the bolt that chambers the first of them is the `Break`/`Close`
		-- the reload sequence runs straight after (`row.RELOAD`).
		--
		-- IT DOES NOT NEED THE ACTION OPEN, and that is the honest model: you change a magazine with
		-- the bolt wherever it is. It does need the gun equipped, and `busyUntil` is what makes it
		-- uninterruptible like every other step.
		if not state.equipped then
			return state, "not-equipped"
		end
		local empty = 0
		for index = 1, #state.barrels do
			if state.barrels[index] ~= "Live" then
				empty += 1
			end
		end
		if empty == 0 then
			return state, "barrel-full"
		end
		local pocket = state.reserve[state.ammo] or 0
		if pocket <= 0 then
			return state, "no-reserve"
		end
		local next = draft(state)
		local fed = 0
		for index = 1, #next.barrels do
			if next.barrels[index] ~= "Live" and fed < pocket then
				next.barrels[index] = "Live"
				next.loaded[index] = state.ammo
				fed += 1
			end
		end
		next.reserve[state.ammo] = pocket - fed
		-- The first live chamber is what the bolt will feed, so the selection follows it rather than
		-- staying on whatever was fired last.
		next.selected = nextLive(next.barrels, #next.barrels)
		next.busyUntil = now + waitFor(row, "Magazine")
		return Shotgun.deepFreeze(next), nil
	elseif kind == "SelectAmmo" then
		local ammo = action.ammo
		-- THE KINDS THIS WEAPON CAN CARRY, from its row (task 140), where this used to be the two
		-- shotgun literals. A rifle with one kind refuses every SelectAmmo, which is what makes `X`
		-- on it a `bad-request` at the wire rather than a branch in the owner.
		local known = false
		for _, allowed in ipairs(row.AMMO_KINDS) do
			if ammo == allowed then
				known = true
				break
			end
		end
		if not known then
			return state, "bad-action"
		end
		local next = draft(state)
		-- The kind the next Load inserts. Since Karen's playtest the owner follows this with a full
		-- Break/Load/Load/Close, so pressing X really does change what is IN the gun -- but this
		-- primitive still does one thing only.
		next.ammo = ammo
		return Shotgun.deepFreeze(next), nil
	end

	return state, "bad-action"
end

return StateMachine
