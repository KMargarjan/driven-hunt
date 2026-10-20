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
-- WHAT A PLAYER HAS BOUGHT, as a pure question over a frozen catalogue (task 178). The direction is
-- deliberate and one-way: this module requires the shop's DATA and the shop's data requires nothing
-- of this -- `Shop.rowsOk` takes the weapon table as a PARAMETER precisely so there is no cycle.
local Shop = require(ReplicatedStorage:WaitForChild("Shop"))
local Lever = require(ReplicatedStorage:WaitForChild("Lever"))
local Rifle = require(ReplicatedStorage:WaitForChild("Rifle"))
local SemiAuto = require(ReplicatedStorage:WaitForChild("SemiAuto"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local LeverGeometry = require(ReplicatedStorage:WaitForChild("Lever"):WaitForChild("Geometry"))
local RifleGeometry = require(ReplicatedStorage:WaitForChild("Rifle"):WaitForChild("Geometry"))
local SemiAutoGeometry = require(ReplicatedStorage:WaitForChild("SemiAuto"):WaitForChild("Geometry"))

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
	-- HOW THE SHOT FLIES (task 185): the muzzle velocity in studs/s, the drag coefficient per stud
	-- and the distance the trajectory crosses the sight line at. Keyed by ammo like the three above,
	-- read off this row by `Ballistics.shotFor`, and REQUIRED -- a row missing any one of them
	-- refuses the shot rather than firing it in a straight line, because a fallback would be a
	-- second answer to "where did the bullet go" (design section 6.5).
	MUZZLE_STUDS_PER_S: { [string]: number },
	DRAG_PER_STUD: { [string]: number },
	ZERO_STUDS: { [string]: number },
	-- ...AND HOW MUCH OF REAL GRAVITY THAT PROJECTILE FALLS AT (task 189). Required like the three
	-- above and read by the same `Ballistics.shotFor`: the rifle's bullet is flattened so a standing
	-- shot is dead on the reticle from 50 to 200 m (Karen, 2026-10-15), and the shotgun's two ammos
	-- carry 1.0, which is the real world. A row without it refuses the shot.
	GRAVITY_SCALE: { [string]: number },
	AMMO_KINDS: { string },
	AMMO_LABEL: { [string]: string },
	-- WHICH `Style.glyph` THE HUD'S AMMO CHIP DRAWS FOR EACH LOAD (task 204), and OPTIONAL: a gun
	-- whose row has none gets the chip it has always had. It sits beside `AMMO_LABEL` and for
	-- exactly the same reason -- the wire says `Slug` for BOTH guns, because `Boar.Wound.damageFor`
	-- branches on that string, so a glyph keyed off the wire word alone would draw a shotgun shell
	-- for a .416 Rigby cartridge. The row is where a gun says what its own ammunition looks like.
	AMMO_GLYPH: { [string]: string }?,
	INITIAL_AMMO: string,
	START_RESERVE: { [string]: number },

	BARRELS: number,
	BARREL_DELAY: number,
	AUTO_CYCLE: boolean,
	CYCLE: { CycleStep },
	CYCLE_TOTAL: number,

	-- THE MAGAZINE WEAPON'S OWN FIELDS (task 142), every one optional: a break action has none of
	-- them and the shotgun's row carries none. They were written into the rifle's literal and read
	-- in `--!strict` files for a round without being in the type, which is a sealed type telling a
	-- lie (the Reviewer's note).
	--
	-- `CYCLE_EJECTS` is "all" (the default, and the shotgun) or "spent" -- what opening the action
	-- throws away. `RELOAD` is the second sequence, the magazine change; `MAGAZINE` is what one box
	-- holds; `READOUT` is "magazine" where the Hud prints rounds over capacity instead of one glyph
	-- per chamber; `SOUND` is this weapon's own voices.
	CYCLE_EJECTS: string?,
	RELOAD: { CycleStep }?,
	RELOAD_TOTAL: number?,
	MAGAZINE: number?,
	AUTO_RELOAD_WHEN_EMPTY: boolean?,
	READOUT: string?,
	SOUND: { [string]: any }?,
	-- WHICH SIGHT THE GUN CARRIES (task 143): "scope", "bead", or "reddot" (task 225). nil is
	-- "scope", which is every row written before task 143 -- and on a weapon with no `scope` block
	-- at all it decides which sight is DRAWN rather than how aiming works.
	SIGHT: string?,
	-- IS THIS WEAPON BOUGHT, OR CAN IT ALSO ARRIVE FREE? (task 224.) nil or false is every row
	-- written before it, and those keep their behaviour bit-for-bit.
	--
	-- WHY IT EXISTS, and it was MEASURED rather than feared. `Shop.loadoutFrom` hands out EVERY id
	-- when the ownership set is nil, and nil is "unrestricted": a world that wired no provider, a
	-- build with the shop off, a profile that would not load, and every `weapon_*.spec`. That
	-- direction is the safety of the whole feature -- nobody loses a gun because a DataStore was
	-- slow -- and it is NOT weakened here. But it also means a third weapon changes what those
	-- worlds hand out, and the DEV gate measured exactly that: the character held the LEVER and the
	-- shotgun sat in the backpack, which is a gun the player never bought and never asked for.
	--
	-- THE DIRECTOR'S RULE, 2026-10-20: *"a player who has NOT bought the lever rifle must never hold
	-- it -- the free-path default stays exactly as before 224"*. A row that sets this is carried
	-- ONLY by a player whose ownership set actually names it. Nothing about the shotgun or the
	-- Rigby moves, which is the point.
	OWNED_ONLY: boolean?,

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
		MUZZLE_STUDS_PER_S = C.MUZZLE_STUDS_PER_S,
		DRAG_PER_STUD = C.DRAG_PER_STUD,
		ZERO_STUDS = C.ZERO_STUDS,
		GRAVITY_SCALE = C.GRAVITY_SCALE,
		-- THE SHELL'S OWN IDENTITY, READ AND NOT COPIED (task 225). These three were literals here
		-- until a SECOND gun started firing this cartridge, which is when "what loads exist and
		-- what each is called" stopped being a fact about this gun. They are `Shotgun.CONFIG`'s
		-- now, beside that cartridge's ballistics, and both shotgun rows read them. No value moved,
		-- and `rifle.spec`'s field-by-field walk of this row against that config now covers them.
		AMMO_KINDS = C.AMMO_KINDS,
		AMMO_LABEL = C.AMMO_LABEL,
		-- THE ONLY SHELL IN THE GAME THAT HAS TWO LOADS, so the only ammunition that carries this
		-- (task 204) -- and therefore the only two rows that have a glyph.
		AMMO_GLYPH = C.AMMO_GLYPH,
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
		MUZZLE_STUDS_PER_S = Rifle.CONFIG.MUZZLE_STUDS_PER_S,
		DRAG_PER_STUD = Rifle.CONFIG.DRAG_PER_STUD,
		ZERO_STUDS = Rifle.CONFIG.ZERO_STUDS,
		GRAVITY_SCALE = Rifle.CONFIG.GRAVITY_SCALE,
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
		SIGHT = "scope",
	} :: Row,
	-- THE LEVER-ACTION RIFLE (task 224). Karen, 2026-10-20: *"weapons / make it work like we have
	-- now"*, and she bought the model: a Ruger-made Marlin 1895 SBL in .45-70.
	--
	-- IT READS NOTHING OUT OF `Rifle.CONFIG`, and that is the rule rather than an oversight: the two
	-- rifles share NO number, only machinery. `Rifle`'s own header says why -- the file that holds
	-- Karen's accepted numbers must not become the file everybody edits -- and `lever.spec` walks
	-- this row field by field against `Lever.CONFIG`, so a number that moves fails the harness
	-- instead of drifting.
	lever = {
		id = "lever",
		-- FIVE CHARACTERS, AND IT MUST STAY AT SEVEN OR FEWER: `ReportPanel.DETAIL_COLUMNS`' `gun`
		-- cell is 88 px, and task 219 measured `SHOTGUN` at 46 px in that cell's own face.
		label = "LEVER",
		toolName = "Lever",
		slot = 3,
		RANGE_STUDS = Lever.CONFIG.RANGE_STUDS,
		PELLETS = Lever.CONFIG.PELLETS,
		SPREAD_FULL_DEG = Lever.CONFIG.SPREAD_FULL_DEG,
		MUZZLE_STUDS_PER_S = Lever.CONFIG.MUZZLE_STUDS_PER_S,
		DRAG_PER_STUD = Lever.CONFIG.DRAG_PER_STUD,
		ZERO_STUDS = Lever.CONFIG.ZERO_STUDS,
		GRAVITY_SCALE = Lever.CONFIG.GRAVITY_SCALE,
		AMMO_KINDS = Lever.CONFIG.AMMO_KINDS,
		AMMO_LABEL = Lever.CONFIG.AMMO_LABEL,
		INITIAL_AMMO = Lever.CONFIG.INITIAL_AMMO,
		START_RESERVE = Lever.CONFIG.START_RESERVE,
		BARRELS = Lever.CONFIG.BARRELS,
		BARREL_DELAY = Lever.CONFIG.BARREL_DELAY,
		AUTO_CYCLE = Lever.CONFIG.AUTO_CYCLE,
		CYCLE = Lever.CONFIG.CYCLE,
		CYCLE_TOTAL = Lever.CONFIG.CYCLE_TOTAL,
		-- The tube's own rules: the throw ejects the fired case only, the reload is cartridges
		-- through the gate one at a time, and the Hud prints rounds over capacity.
		CYCLE_EJECTS = Lever.CONFIG.CYCLE_EJECTS,
		RELOAD = Lever.CONFIG.RELOAD,
		RELOAD_TOTAL = Lever.CONFIG.RELOAD_TOTAL,
		MAGAZINE = Lever.CONFIG.MAGAZINE,
		AUTO_RELOAD_WHEN_EMPTY = Lever.CONFIG.AUTO_RELOAD_WHEN_EMPTY,
		READOUT = Lever.CONFIG.READOUT,
		HANDLE_SIZE = Lever.CONFIG.HANDLE_SIZE,
		HANDLE_TRANSPARENCY = Lever.CONFIG.HANDLE_TRANSPARENCY,
		GRIP = Lever.CONFIG.GRIP,
		MUZZLE_OFFSET = Lever.CONFIG.MUZZLE_OFFSET,
		HANDLE_COLOR = Lever.CONFIG.LOOK.wood,
		LOOK = Lever.CONFIG.LOOK,
		-- The action is worn as `Model` -- the body, the piece that must be there for the gun to
		-- count as dressed -- and the other two hang off the Handle beside it.
		ASSET_KEYS = { "lever.action", "lever.stock", "lever.lever" },
		MESH_NAMES = { "Model", "Stock", "Lever" },
		SOUND = Lever.CONFIG.SOUND,
		-- NO `scope` BLOCK AT ALL, which is what makes the aim the shotgun's path rather than the
		-- Rigby's: no eyepiece, no reticle, no sight picture, the gun and both gloves left in the
		-- view. `SIGHT = "bead"` is task 143's machinery, kept on purpose when task 148 retired the
		-- row that used it (`backups/2026-10-10-rifle-open-sights.md`).
		SIGHT = "bead",
		scope = nil,
		-- BOUGHT, OR NOT CARRIED (task 224, the Director's rule). The unrestricted default -- what
		-- every un-wired world and every weapon spec gets -- does NOT hand this gun out, so the free
		-- path is bit-for-bit what it was before this weapon existed.
		OWNED_ONLY = true,
	} :: Row,
	-- THE SEMI-AUTOMATIC SHOTGUN (task 225). Karen, 2026-10-20: *"weapons / make it work like we have
	-- now"*, and she bought the model: an MP-153-pattern gas-operated 12 gauge with a rail and a red
	-- dot.
	--
	-- IT READS ITS AMMUNITION OUT OF `Shotgun.CONFIG` AND EVERYTHING ELSE OUT OF ITS OWN CONFIG, and
	-- that split is the rule rather than an accident. The two RIFLES share no number because they
	-- fire different cartridges; the two SHOTGUNS fire the SAME shell, so a second copy of its
	-- ballistics would be a second answer to how far a slug goes. `semiauto.spec` asserts the
	-- ammunition rows by TABLE IDENTITY against `Shotgun.CONFIG` and walks every other field against
	-- `SemiAuto.CONFIG`, so neither half can drift.
	semiauto = {
		id = "semiauto",
		-- FOUR CHARACTERS, AND IT MUST STAY AT SEVEN OR FEWER: `ReportPanel.DETAIL_COLUMNS`' `gun`
		-- cell is 88 px, and task 219 measured `SHOTGUN` at 46 px in that cell's own face. The shop
		-- row says "SEMI-AUTO SHOTGUN"; this is what fits on a drive report. `"SEMI"` is the
		-- alternative and the choice is Karen's (design 17, K-7).
		label = "AUTO",
		toolName = "SemiAuto",
		slot = 4,
		-- THE SAME SHELL, BY REFERENCE. `SemiAuto.CONFIG` holds these as `Shotgun.CONFIG`'s own
		-- tables, so this row is reading one answer through one hop and not copying a second.
		RANGE_STUDS = SemiAuto.CONFIG.RANGE_STUDS,
		PELLETS = SemiAuto.CONFIG.PELLETS,
		SPREAD_FULL_DEG = SemiAuto.CONFIG.SPREAD_FULL_DEG,
		MUZZLE_STUDS_PER_S = SemiAuto.CONFIG.MUZZLE_STUDS_PER_S,
		DRAG_PER_STUD = SemiAuto.CONFIG.DRAG_PER_STUD,
		ZERO_STUDS = SemiAuto.CONFIG.ZERO_STUDS,
		GRAVITY_SCALE = SemiAuto.CONFIG.GRAVITY_SCALE,
		AMMO_KINDS = SemiAuto.CONFIG.AMMO_KINDS,
		AMMO_LABEL = SemiAuto.CONFIG.AMMO_LABEL,
		AMMO_GLYPH = SemiAuto.CONFIG.AMMO_GLYPH,
		INITIAL_AMMO = SemiAuto.CONFIG.INITIAL_AMMO,
		START_RESERVE = SemiAuto.CONFIG.START_RESERVE,
		BARRELS = SemiAuto.CONFIG.BARRELS,
		BARREL_DELAY = SemiAuto.CONFIG.BARREL_DELAY,
		AUTO_CYCLE = SemiAuto.CONFIG.AUTO_CYCLE,
		CYCLE = SemiAuto.CONFIG.CYCLE,
		CYCLE_TOTAL = SemiAuto.CONFIG.CYCLE_TOTAL,
		-- The tube's own rules, the lever's shape with a gas piston's numbers: the stroke throws the
		-- fired hull only, the reload is shells through the port one at a time, and the Hud prints
		-- rounds over capacity.
		CYCLE_EJECTS = SemiAuto.CONFIG.CYCLE_EJECTS,
		RELOAD = SemiAuto.CONFIG.RELOAD,
		RELOAD_TOTAL = SemiAuto.CONFIG.RELOAD_TOTAL,
		MAGAZINE = SemiAuto.CONFIG.MAGAZINE,
		AUTO_RELOAD_WHEN_EMPTY = SemiAuto.CONFIG.AUTO_RELOAD_WHEN_EMPTY,
		READOUT = SemiAuto.CONFIG.READOUT,
		HANDLE_SIZE = SemiAuto.CONFIG.HANDLE_SIZE,
		HANDLE_TRANSPARENCY = SemiAuto.CONFIG.HANDLE_TRANSPARENCY,
		GRIP = SemiAuto.CONFIG.GRIP,
		MUZZLE_OFFSET = SemiAuto.CONFIG.MUZZLE_OFFSET,
		HANDLE_COLOR = SemiAuto.CONFIG.LOOK.wood,
		LOOK = SemiAuto.CONFIG.LOOK,
		-- The action is worn as `Model` -- the body, the piece that must be there for the gun to
		-- count as dressed -- and the other five hang off the Handle beside it. SIX, which is two
		-- more than any gun so far: three of the splits are forced by MATERIAL (this model has three
		-- where the Marlin had one, and one MeshPart is one material) and two by MOTION.
		ASSET_KEYS = {
			"semiauto.action",
			"semiauto.barrel",
			"semiauto.stock",
			"semiauto.bolt",
			"semiauto.lifter",
			"semiauto.sight",
		},
		-- `Optic` AND NOT `Sight`: `Hardware.SIGHT_NAME` is `"Sight"`, and `Hardware.setSight`
		-- finds the Handle's sight ATTACHMENT with `FindFirstChild` -- so a worn MESH of that
		-- name is found first and the attachment is lost. The same collision on the drawn gun
		-- cost the aimed pose its sight plane (the Reviewer, round 1, finding 1).
		MESH_NAMES = { "Model", "Barrel", "Stock", "Bolt", "Lifter", "Optic" },
		SOUND = SemiAuto.CONFIG.SOUND,
		-- NO `scope` BLOCK AT ALL, which is what makes aiming the side-by-side's path rather than
		-- the Rigby's: no eyepiece, no mask, no magnification, the gun and both gloves left in the
		-- view. `SIGHT = "reddot"` then says which sight is DRAWN on it.
		SIGHT = SemiAuto.CONFIG.SIGHT,
		scope = nil,
		-- BOUGHT, OR NOT CARRIED (task 224's rule, applied again). The unrestricted default -- what
		-- every un-wired world and every weapon spec gets -- does NOT hand this gun out, so the free
		-- path is bit-for-bit what it was before this weapon existed.
		OWNED_ONLY = true,
	} :: Row,
}

-- Hotbar order: slot 1 and slot 2, which are the keys Roblox itself binds.
-- THE HOTBAR'S ORDER (task 141): 1 the shotgun, 2 the rifle with its scope.
--
-- SLOT 3 WAS THE OPEN-SIGHTED RIFLE AND KAREN TOOK IT OUT (task 148): *"please remove rifle without
-- scope so we don't implement now"*. The row, its pose set and its two spec cases are archived in
-- `backups/2026-10-10-rifle-open-sights.md` with the commit that had them -- and the MACHINERY it
-- needed is deliberately still here, because none of it is dead weight for the scoped rifle:
-- `Geometry.sightKind`, `Geometry.beadOffset`, the `Bead` piece's `onlyFor` and `ShapeRifle`'s
-- `skipFor` are what let ONE geometry draw a gun with or without glass, which is the shape the next
-- sight (Karen also asked for an Aimpoint) wants.
-- SLOT 3 IS THE LEVER RIFLE (task 224). It was the open-sighted Rigby until task 148, and the
-- ordering was measured then (`1 Shotgun, 2 Rifle, 3 RifleOpen`), so this is a rung being
-- re-occupied rather than a new mechanism.
-- SLOT 4 IS THE SEMI-AUTOMATIC SHOTGUN (task 225), appended rather than inserted: a slot a
-- player already knows must not move under him, and the engine numbers a slot the first time
-- it SEES a Tool (task 141, measured).
Weapons.ORDER = { "shotgun", "rifle", "lever", "semiauto" }
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
	lever = LeverGeometry,
	semiauto = SemiAutoGeometry,
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
--
-- `owned` IS WHAT HE HAS BOUGHT (task 178), and `nil` IS UNRESTRICTED -- today's list, exactly.
-- That direction is the safety of the whole feature (docs/design/shop.md section 7.1): a world that
-- wired no provider, every `tests/server/weapon_*.spec.luau`, a build with the shop off, and a
-- player whose profile would not load all answer nil, and all of them keep the gun they have. The
-- PRIMARY is never taken away either way -- Karen's *"default is double barrel shotgun"*.
-- WHICH IDS ARE EVEN CANDIDATES (task 224). `OWNED_ONLY` is applied HERE and not in `Shop`, because
-- this is the module that owns "which of them a hunter carries" and the only one that can see the
-- rows: `Shop.loadoutFrom` takes a LIST OF IDS precisely so it never has to know what a weapon is,
-- and `Shop.rowsOk` takes the weapon table as a parameter for the same reason -- there is no require
-- from the shop's data back to here and there must not be one.
--
-- IT NARROWS THE LIST; IT DOES NOT CHANGE THE RULE. `Shop.loadoutFrom` still decides, and still
-- answers "everything it was given" for a nil ownership set. The PRIMARY is still never taken away.
-- The only difference is that a bought-or-nothing weapon is not in the unrestricted list at all.
--
-- PURE, like everything else on this path, so both branches are reachable in a spec with no flag
-- and no provider anywhere.
local function carriable(owned: { [string]: boolean }?): { WeaponId }
	if owned ~= nil then
		-- OWNERSHIP IS ALREADY THE GATE: every id goes forward and `loadoutFrom` keeps the ones he
		-- bought. `OWNED_ONLY` decides nothing here, which is what makes buying the gun work at all.
		return Weapons.ORDER
	end
	local out: { WeaponId } = {}
	for _, id in ipairs(Weapons.ORDER) do
		local row = Weapons.ROWS[id]
		if row == nil or not row.OWNED_ONLY then
			table.insert(out, id)
		end
	end
	return out
end

function Weapons.loadoutFor(rifleOn: boolean, owned: { [string]: boolean }?): { WeaponId }
	if not rifleOn then
		return { Weapons.PRIMARY }
	end
	return Shop.loadoutFrom(carriable(owned), Weapons.PRIMARY, owned)
end

-- THE ONE FLAG READ IN THE WHOLE WEAPON SYSTEM, at this boundary, passed inward as a list -- the
-- only permitted shape (CLAUDE.md, feature flags). The ownership set is the caller's: the server
-- owner reads it through its own pcall-ed provider and hands it in (`Weapon.askOwned`).
function Weapons.loadout(owned: { [string]: boolean }?): { WeaponId }
	return Weapons.loadoutFor(Flags.isOn(Weapons.FLAG), owned)
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

-- IS THE THING IN THIS HAND A GUN? (task 152). Until the beater's horn there was only one kind of
-- Tool in this game, so "a Tool in the character" and "a gun" were the same sentence and both camera
-- modules said the second while meaning the first. MEASURED, Forest Test 2026-10-11: a beater
-- holding a horn saw a SHOTGUN in first person -- `Viewmodel.update` took the horn's Handle, found
-- no `DrivenHunt.Weapon` attribute on it and fell back to `Shotgun.CONFIG`, so the viewmodel drew
-- the wrong object out of the right Handle.
--
-- IT ASKS TWICE AND THE ATTRIBUTE COMES FIRST, because that is the one `Hardware.build` writes and
-- the one `Viewmodel.weaponId` already trusts ("the drawn gun follows the INSTANCE"). The NAME is
-- the fallback, so a Tool granted by a server older than task 140 -- which has no attribute -- is
-- still recognised as a gun rather than quietly becoming a horn.
function Weapons.isWeaponTool(tool: Instance?): boolean
	if tool == nil or not tool:IsA("Tool") then
		return false
	end
	local id = (tool :: Tool):GetAttribute("DrivenHunt.Weapon")
	if type(id) == "string" and Weapons.row(id :: string) ~= nil then
		return true
	end
	return Weapons.isToolName((tool :: Tool).Name)
end

return Weapons
