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
-- `start` IS WHAT ONE PLAYER MAY BE ISSUED (task 178), and `nil` is the weapon's own row -- which
-- is what every caller written before the shop passes, so no weapon spec and no number moves.
-- `Shop.startFor(row, owned)` is what produces it, and nothing about the ROW is edited: the pocket
-- sizes are still `START_RESERVE`'s (docs/design/shop.md section 7.3).
function StateMachine.initial(
	config,
	start: { ammo: string?, reserve: { [string]: number }?, unlimited: { [string]: boolean }? }?
): WeaponState
	local ammo = (start and start.ammo) or config.INITIAL_AMMO
	local barrels, loaded = {}, {}
	for index = 1, config.BARRELS do
		barrels[index] = "Live"
		loaded[index] = ammo
	end
	-- A copy: CONFIG.START_RESERVE is deep-frozen, and this one is about to be spent.
	local reserve = if start and start.reserve then table.clone(start.reserve) else table.clone(config.START_RESERVE)
	-- WHICH POCKETS DO NOT GO DOWN (task 221). `{}` for every caller written before the shop, which
	-- is the game as it was: `Shop.startFor` is the only thing that ever answers a non-empty one.
	local unlimited = if start and start.unlimited then table.clone(start.unlimited) else {}
	return Shotgun.deepFreeze({
		equipped = false,
		open = false,
		barrels = barrels,
		loaded = loaded,
		selected = 1,
		ammo = ammo,
		reserve = reserve,
		unlimited = unlimited,
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
	copy.unlimited = table.clone(state.unlimited or {})
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
-- why the drawn box never moved. `Break` and `Close` are in both lists -- they USED to carry the
-- same waits in each, so the order between them decided nothing, and then task 184 made the bolt a
-- second slower and left the magazine change alone.
-- `steps` IS THE SEQUENCE ACTUALLY BEING RUN, AND IT WINS (task 184). Until Karen made the bolt a
-- second slower, `Break` and `Close` carried the same waits in both of the rifle's lists, so
-- searching them in a fixed order decided nothing and this comment said as much. It decides
-- everything now: the bolt's `Break` is 0.68 s and the magazine change's is still 0.26 s, and a
-- first-match search would have charged the magazine change the bolt's window -- `runCycle` would
-- then `task.wait(0.26)`, ask for `Close`, be refused "busy", and finish the reload down its
-- error-recovery path. `runCycle` knows which list it is walking, so it says.
-- nil keeps the old behaviour exactly, for every caller that is not walking a sequence -- and the
-- three lists are searched by NAME rather than by `ipairs` over a table holding them, because
-- `ipairs({ nil, CYCLE, RELOAD })` iterates nothing at all. Round 1 of task 184 wrote exactly that
-- and every window became 0: the gun was never busy after any step. `rifle.spec`'s three timing
-- cases caught it.
-- nil, NOT 0, is "this list does not have that kind": a step may legitimately wait 0 s, and `or`
-- would walk past it.
local function waitIn(list: { any }?, kind: string): number?
	if list == nil then
		return nil
	end
	for _, step in ipairs(list) do
		if step.kind == kind then
			return step.wait
		end
	end
	return nil
end

local function waitFor(row, kind: string, steps: { any }?): number
	local wait = waitIn(steps, kind)
	if wait == nil then
		wait = waitIn(row.CYCLE, kind)
	end
	if wait == nil then
		wait = waitIn(row.RELOAD, kind)
	end
	return wait or 0
end

-- Returns (newState, nil) or (the SAME state, reason). Rejection reasons are a closed set, so the
-- owner and the specs can name them: "busy", "is-open", "is-closed", "not-equipped",
-- "barrel-empty", "no-reserve", "barrel-full", "bad-action".
--
-- `row` IS REQUIRED AND HAS NO DEFAULT (task 140). This function used to read `Shotgun.CONFIG` at
-- its top, which with two weapons is a rifle timed like a shotgun, silently. No default means every
-- caller has to say which weapon it means.
-- `steps` IS OPTIONAL AND ADDITIVE (task 184): the sequence the caller is walking, so a weapon whose
-- two sequences no longer share their `Break`/`Close` waits is charged the window of the step it
-- actually took. Every caller that passes nothing behaves exactly as it did.
function StateMachine.apply(
	state: WeaponState,
	action: Action,
	now: number,
	row,
	steps: { any }?
): (WeaponState, string?)
	local config = row
	local kind = action.kind

	-- `Refill` IS EXEMPT FROM THE BUSY WINDOW, like `SelectAmmo` (task 171): it is the DRIVE putting
	-- shells in his pocket at its own start, not something the player's hands are doing, and a refill
	-- refused because he happened to be closing the action is a refill that is simply lost -- the
	-- owner has already recorded the drive as refilled by the time the reducer answers.
	if kind ~= "SelectAmmo" and kind ~= "Refill" and now < state.busyUntil then
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
			if chamber == "Live" and loadedKind ~= "None" and not next.unlimited[loadedKind] then
				-- ...AND AN UNLIMITED POCKET DOES NOT GO UP EITHER (task 221). Nothing was taken out
				-- of it when the shell was loaded, so putting one back would make the number on
				-- screen climb for ever.
				next.reserve[loadedKind] = (next.reserve[loadedKind] or 0) + 1
			end
			next.barrels[index] = "Empty"
			next.loaded[index] = "None"
		end
		next.busyUntil = now + waitFor(row, "Break", steps)
		return Shotgun.deepFreeze(next), nil
	elseif kind == "Load" then
		if not state.open then
			return state, "is-closed"
		end
		-- AN UNLIMITED POCKET IS NEVER EMPTY (task 221): the refusal is skipped and the number below
		-- is not written, so the readout holds still and `INF` is the truth rather than a label.
		local boundless = state.unlimited[state.ammo] == true
		if not boundless and (state.reserve[state.ammo] or 0) <= 0 then
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
		if not boundless then
			next.reserve[state.ammo] = next.reserve[state.ammo] - 1
		end
		next.busyUntil = now + waitFor(row, "Load", steps)
		return Shotgun.deepFreeze(next), nil
	elseif kind == "Close" then
		if not state.open then
			return state, "is-closed"
		end
		local next = draft(state)
		next.open = false
		next.selected = nextLive(next.barrels, #next.barrels)
		next.busyUntil = now + waitFor(row, "Close", steps)
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
		-- AN UNLIMITED POCKET FEEDS AS MANY AS THERE ARE CHAMBERS (task 221), and is not written
		-- below: `pocket` stands in for "enough", so the loop fills every empty barrel.
		local boundless = state.unlimited[state.ammo] == true
		local pocket = if boundless then #state.barrels else (state.reserve[state.ammo] or 0)
		if pocket <= 0 then
			return state, "no-reserve"
		end
		local next = draft(state)
		local fed = 0
		-- IT FILLS A SPENT CHAMBER TOO, and that is deliberate rather than overlooked (the
		-- Reviewer's note): pressing R with a fired case still in the chamber swaps the box AND
		-- discards that case with it, which costs one round from the pocket and is what the sequence
		-- then chambers. Requiring `Empty` would leave the spent case in a gun whose own bolt cycle
		-- has already run, with nothing left to eject it.
		for index = 1, #next.barrels do
			if next.barrels[index] ~= "Live" and fed < pocket then
				next.barrels[index] = "Live"
				next.loaded[index] = state.ammo
				fed += 1
			end
		end
		if not boundless then
			next.reserve[state.ammo] = pocket - fed
		end
		-- The first live chamber is what the bolt will feed, so the selection follows it rather than
		-- staying on whatever was fired last.
		next.selected = nextLive(next.barrels, #next.barrels)
		next.busyUntil = now + waitFor(row, "Magazine", steps)
		return Shotgun.deepFreeze(next), nil
	elseif kind == "Refill" then
		-- THE DRIVE'S SHELLS, PUT BACK (task 171). KAREN, 2026-10-10: *"limited ammon per round"* --
		-- so the pocket is `START_RESERVE` again at the start of each drive and not before, and this
		-- is the one place that is written. It is a SERVER-SIDE primitive: `Validator.checkRequest`
		-- accepts only "Reload" and "SelectAmmo" over the wire, so no client can ask for it.
		--
		-- WHAT IS IN THE GUN IS NOT TOUCHED. Only the pocket: a hunter who starts a drive with a
		-- live shell in the right barrel keeps it, which is what carrying a loaded gun means.
		local next = draft(state)
		-- A copy, for the reason `initial` gives: CONFIG.START_RESERVE is deep-frozen and this one is
		-- about to be spent.
		--
		-- `action.reserve` IS THIS PLAYER'S OWN ALLOWANCE (task 178), and it is carried on the ACTION
		-- rather than as a fifth parameter because this primitive is SERVER-SIDE BY CONSTRUCTION:
		-- `Validator.checkRequest` accepts only "Reload" and "SelectAmmo" over the wire, so no client
		-- can send a `Refill` at all, let alone one carrying a reserve. nil is the weapon's own row.
		next.reserve = if action.reserve then table.clone(action.reserve) else table.clone(config.START_RESERVE)
		-- ...AND HIS ALLOWANCE WITH IT (task 221), carried on the same action for the same reason.
		-- nil is the weapon's own, which is NO unlimited pockets, which is today's game -- so a
		-- refill that never heard of this field puts the drive's twelve back exactly as it did.
		next.unlimited = if action.unlimited then table.clone(action.unlimited) else {}
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
