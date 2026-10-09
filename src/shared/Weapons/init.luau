--!strict
-- Weapons: THE TABLE OF WEAPONS. One row per gun, frozen, no writer -- the shape
-- `Boar.CONFIG.KINDS` already ships for three animals, applied to two guns (CLAUDE.md rule 3: one
-- owner per system, and `ServerScriptService.Weapon` stays that owner).
--
-- WHY A LITERAL TABLE AND NOT A REGISTRY THAT COLLECTS ROWS. A registry needs a registration order,
-- and a weapon that forgot to register is a weapon that silently does not exist -- the same class of
-- defect as the `FindFirstChild`-instead-of-`WaitForChild` races of tasks 123, 133 and 134. A
-- literal is readable as a sentence, is frozen at require time, and `Weapons.ids()` cannot answer
-- differently on two machines.
--
-- THE SHOTGUN'S ROW IS BUILT FROM `Shotgun.CONFIG`, NEVER COPIED OUT OF IT. There is still exactly
-- one source for every shotgun number, and `tests/server/rifle.spec.luau` asserts the row field by
-- field against that config, so a number that moves fails the harness rather than drifting.
--
-- WHAT A ROW MAY NOT CARRY, and this is a rule rather than an omission: the safety arc, the camera
-- origin tolerance, the rate limits, `AUTO_EQUIP` and `shouldArm` are rules of the DRIVE and of the
-- PROTOCOL, not properties of a gun. A per-weapon `SAFETY_ARC_HALF_DEG` would let a new weapon widen
-- its own licence to shoot down the line. They stay in `Shotgun.CONFIG` and the owner reads them
-- there; `rifle.spec` asserts that no row has them.
--
-- Design: docs/design/rifle.md (section 4)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
local Gun = require(ReplicatedStorage:WaitForChild("Gun"))
local Rifle = require(ReplicatedStorage:WaitForChild("Rifle"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local RifleGeometry = require(ReplicatedStorage:WaitForChild("Rifle"):WaitForChild("Geometry"))

local Weapons = {}

export type WeaponId = string
export type CycleStep = Rifle.CycleStep

export type Row = {
	id: WeaponId,
	label: string, -- what the Hud prints
	toolName: string, -- Tool.Name, and how a stray one is found
	slot: number, -- the hotbar order, for the record; the engine does the ordering

	RANGE_STUDS: { [string]: number },
	PELLETS: { [string]: number },
	SPREAD_FULL_DEG: { [string]: number },
	AMMO_KINDS: { string },
	AMMO_LABEL: { [string]: string },
	INITIAL_AMMO: string,
	START_RESERVE: { [string]: number },

	BARRELS: number,
	BARREL_DELAY: number,
	AUTO_CYCLE: boolean,
	CYCLE: { CycleStep },
	CYCLE_TOTAL: number,

	HANDLE_SIZE: Vector3,
	HANDLE_TRANSPARENCY: number,
	GRIP: CFrame,
	MUZZLE_OFFSET: Vector3,
	HANDLE_COLOR: Color3,
	LOOK: { [string]: Color3 },
	-- The manifest keys this weapon's WORLD tool wears, in wear order, and the Instance name each
	-- one is worn as. The first name is always `Model`, because "does this Handle have a Model
	-- child" is what `Hardware.wearsMesh` and the upgrade sweep read.
	ASSET_KEYS: { string },
	MESH_NAMES: { string },

	-- nil means "no scope": the shotgun's bead. `Camera` is told this table and nothing else.
	scope: Rifle.Scope?,
}

local C = Shotgun.CONFIG

Weapons.ROWS = {
	shotgun = {
		id = "shotgun",
		label = "SHOTGUN",
		toolName = "Shotgun",
		slot = 1,
		RANGE_STUDS = C.RANGE_STUDS,
		PELLETS = C.PELLETS,
		SPREAD_FULL_DEG = C.SPREAD_FULL_DEG,
		AMMO_KINDS = { "Slug", "Buck" },
		AMMO_LABEL = { Slug = "SLUG", Buck = "BUCK" },
		INITIAL_AMMO = C.INITIAL_AMMO,
		START_RESERVE = C.START_RESERVE,
		BARRELS = C.BARRELS,
		BARREL_DELAY = C.BARREL_DELAY,
		-- The shotgun's reload is not automatic and never was: `R` runs it.
		AUTO_CYCLE = false,
		-- THE FOUR STEPS `Weapon.runReload` BUILT IN CODE, moved into data with the same four
		-- numbers. `CYCLE_TOTAL` is `RELOAD_TOTAL`, which `weapon_state.spec` has asserted since
		-- task 24.
		CYCLE = {
			{ kind = "Break" :: Shotgun.ActionKind, wait = C.RELOAD_BREAK },
			{ kind = "Load" :: Shotgun.ActionKind, wait = C.RELOAD_SHELL },
			{ kind = "Load" :: Shotgun.ActionKind, wait = C.RELOAD_SHELL },
			{ kind = "Close" :: Shotgun.ActionKind, wait = C.RELOAD_CLOSE },
		},
		CYCLE_TOTAL = C.RELOAD_TOTAL,
		HANDLE_SIZE = C.HANDLE_SIZE,
		HANDLE_TRANSPARENCY = C.HANDLE_TRANSPARENCY,
		GRIP = C.GRIP,
		MUZZLE_OFFSET = C.MUZZLE_OFFSET,
		HANDLE_COLOR = C.HANDLE_COLOR,
		LOOK = C.LOOK,
		-- THE WORLD GUN'S KEYS, which are not the viewmodel's: `Gun.MESH_KEYS` names what the
		-- first-person gun clones, and these two are what `Weapon.Hardware` welds onto the Tool.
		ASSET_KEYS = { "shotgun.handle", "shotgun.barrels" },
		MESH_NAMES = { "Model", "Barrels" },
		scope = nil,
	} :: Row,
	rifle = {
		id = "rifle",
		label = "RIFLE",
		toolName = "Rifle",
		slot = 2,
		RANGE_STUDS = Rifle.CONFIG.RANGE_STUDS,
		PELLETS = Rifle.CONFIG.PELLETS,
		SPREAD_FULL_DEG = Rifle.CONFIG.SPREAD_FULL_DEG,
		AMMO_KINDS = Rifle.CONFIG.AMMO_KINDS,
		AMMO_LABEL = Rifle.CONFIG.AMMO_LABEL,
		INITIAL_AMMO = Rifle.CONFIG.INITIAL_AMMO,
		START_RESERVE = Rifle.CONFIG.START_RESERVE,
		BARRELS = Rifle.CONFIG.BARRELS,
		BARREL_DELAY = Rifle.CONFIG.BARREL_DELAY,
		AUTO_CYCLE = Rifle.CONFIG.AUTO_CYCLE,
		CYCLE = Rifle.CONFIG.CYCLE,
		CYCLE_TOTAL = Rifle.CONFIG.CYCLE_TOTAL,
		-- The bolt's own rules (task 142): what it ejects, what a magazine change is, and what the
		-- Hud prints. A row without them is a break action, which is what the shotgun's row is.
		CYCLE_EJECTS = Rifle.CONFIG.CYCLE_EJECTS,
		RELOAD = Rifle.CONFIG.RELOAD,
		RELOAD_TOTAL = Rifle.CONFIG.RELOAD_TOTAL,
		MAGAZINE = Rifle.CONFIG.MAGAZINE,
		AUTO_RELOAD_WHEN_EMPTY = Rifle.CONFIG.AUTO_RELOAD_WHEN_EMPTY,
		READOUT = Rifle.CONFIG.READOUT,
		HANDLE_SIZE = Rifle.CONFIG.HANDLE_SIZE,
		HANDLE_TRANSPARENCY = Rifle.CONFIG.HANDLE_TRANSPARENCY,
		GRIP = Rifle.CONFIG.GRIP,
		MUZZLE_OFFSET = Rifle.CONFIG.MUZZLE_OFFSET,
		HANDLE_COLOR = Rifle.CONFIG.LOOK.wood,
		LOOK = Rifle.CONFIG.LOOK,
		-- The action is worn as `Model` -- the body, the piece that must be there for the gun to
		-- count as dressed -- and the other three hang off the Handle beside it.
		ASSET_KEYS = { "rifle.action", "rifle.stock", "rifle.bolt", "rifle.scope" },
		MESH_NAMES = { "Model", "Stock", "Bolt", "Scope" },
		SOUND = Rifle.CONFIG.SOUND,
		scope = Rifle.CONFIG.scope,
	} :: Row,
}

-- Hotbar order: slot 1 and slot 2, which are the keys Roblox itself binds.
Weapons.ORDER = { "shotgun", "rifle" }
-- What `AUTO_EQUIP` puts in the hand at a spawn. A spawn is bit-for-bit what it was before the
-- rifle existed.
Weapons.PRIMARY = "shotgun"
Weapons.FLAG = "RIFLE"

Shotgun.deepFreeze(Weapons.ROWS)
table.freeze(Weapons.ORDER)

-- THE GEOMETRY MAP LIVES HERE because both sides are shared modules. The WORLD shape map cannot:
-- `Weapon.Shape` is a server module and a shared module may not require one, so that map is
-- `ServerScriptService.Weapon.Shapes` and this one is here. Shallow-frozen ON PURPOSE: `deepFreeze`
-- recurses into table values and would freeze another module's own table, which is not ours to
-- freeze.
local GEOMETRY = table.freeze({
	shotgun = Gun,
	rifle = RifleGeometry,
})

function Weapons.row(id: WeaponId?): Row?
	if type(id) ~= "string" then
		return nil
	end
	return (Weapons.ROWS :: any)[id]
end

function Weapons.ids(): { WeaponId }
	return table.clone(Weapons.ORDER)
end

function Weapons.geometry(id: WeaponId?): any?
	if type(id) ~= "string" then
		return nil
	end
	return (GEOMETRY :: any)[id]
end

-- PURE, so the flag's two worlds are both reachable in a spec with no flag set.
function Weapons.loadoutFor(rifleOn: boolean): { WeaponId }
	if not rifleOn then
		return { Weapons.PRIMARY }
	end
	return table.clone(Weapons.ORDER)
end

-- THE ONE FLAG READ IN THE WHOLE WEAPON SYSTEM, at this boundary, passed inward as a list -- the
-- only permitted shape (CLAUDE.md, feature flags).
function Weapons.loadout(): { WeaponId }
	return Weapons.loadoutFor(Flags.isOn(Weapons.FLAG))
end

function Weapons.toolNames(): { [string]: WeaponId }
	local out: { [string]: WeaponId } = {}
	for id, row in pairs(Weapons.ROWS) do
		out[row.toolName] = id
	end
	return out
end

-- Is this the name of a Tool this system owns? Answered off the table, so no caller carries the
-- literal "Shotgun" again.
function Weapons.isToolName(name: string?): boolean
	if type(name) ~= "string" then
		return false
	end
	return Weapons.toolNames()[name] ~= nil
end

function Weapons.idForToolName(name: string?): WeaponId?
	if type(name) ~= "string" then
		return nil
	end
	return Weapons.toolNames()[name]
end

return Weapons
