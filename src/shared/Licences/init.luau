--!strict
-- Licences: THE TABLE OF SPECIES AND WHAT IT COSTS TO BE ALLOWED TO SHOOT ONE. One row per species,
-- frozen, no writer -- the shape `Weapons.ROWS` already ships for two guns and `Boar.CONFIG.KINDS`
-- for three animals (CLAUDE.md rule 3: the fire gate in `ServerScriptService.Weapon` stays the one
-- decider; this is only the data it reads).
--
-- KAREN, 2026-10-10, about a red deer: *"they can aim but no shooting happening"*. So a licence is
-- not a purchase that unlocks a weapon, it is permission to shoot an ANIMAL -- which is what a real
-- hunting licence is, and what theHunter: Call of the Wild ties to its weapon classes
-- (docs/research/2026-10-13-the-rules.md source 4).
--
-- IT IS SHARED AND NOT SERVER-ONLY, because the shop that sells a licence and the Hud that would
-- print "NO LICENCE" are both clients, and the server is the one that enforces. A second copy of
-- "a red deer needs a licence" living on the client is exactly the two-correct-pieces-of-code
-- failure docs/PROJECT_CONTEXT.md names.
--
-- NO DEER EXISTS YET. `reddeer` is in the table because Karen's rule is about one and because a rule
-- with no data is not a rule; `tests/server/weapon_rules.spec.luau` proves the gate with a STUB
-- target carrying `Species = "reddeer"`. The boar's own trunk publishes `Species = "boar"`
-- (`Boar.Body.create`), so the free row below is live today rather than dormant.
--
-- Note: docs/research/2026-10-13-the-rules.md
local Licences = {}

-- The attribute a target's OWNER publishes about itself, exactly as `Damageable` and `HitZone` are
-- published by the boar and read by `Weapon.Hits.targetOf` (shotgun design section 6.4). The weapon
-- never knows what a boar is; it reads one string.
Licences.SPECIES_ATTRIBUTE = "Species"

export type Row = {
	species: string,
	label: string, -- what a shop or a Hud would print
	licence: boolean, -- does shooting one need a licence at all
	price: number?, -- what it costs in coins, nil while nobody sells it
}

Licences.ROWS = {
	-- FREE, AND IT IS THE WHOLE GAME TODAY. Karen's quarry is wild boar and she has never asked for
	-- a licence for one; the row exists so that "which species is this" has an answer for the only
	-- animal in the drive, and so the gate is exercised by every real shot rather than by a spec.
	boar = { species = "boar", label = "WILD BOAR", licence = false } :: Row,
	-- THE ONE KAREN'S RULE IS ABOUT, and there is no deer in this game yet. 2026-10-10:
	-- *"they can aim but no shooting happening"*. `price` is nil because the shop does not exist and
	-- a number here would be a decision nobody has taken (it is Karen's, with the shop task).
	reddeer = { species = "reddeer", label = "RED DEER", licence = true } :: Row,
}

-- DEEP-FROZEN, so neither the shop nor a spec can edit the rules of the game at run time.
for _, row in pairs(Licences.ROWS) do
	table.freeze(row)
end
table.freeze(Licences.ROWS)

-- Every species with a row, sorted, so a caller reads a stable list and not a hash order.
function Licences.species(): { string }
	local out = {}
	for name in pairs(Licences.ROWS) do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

function Licences.row(species: string?): Row?
	if type(species) ~= "string" then
		return nil
	end
	return Licences.ROWS[species]
end

-- DOES SHOOTING THIS SPECIES NEED A LICENCE? One question.
--
-- AN UNKNOWN SPECIES NEEDS NO LICENCE, and that is deliberate rather than lax: the alternative is a
-- game where a target somebody forgot to put in this table cannot be shot at all, silently, which is
-- the "a weapon that forgot to register is a weapon that silently does not exist" failure
-- `Weapons`'s own header refuses. A new protected animal is a ROW, and the row is what protects it.
function Licences.required(species: string?, rows: { [string]: Row }?): boolean
	local table_ = rows or Licences.ROWS
	local row = if type(species) == "string" then table_[species] else nil
	return row ~= nil and row.licence == true
end

-- MAY THIS PLAYER SHOOT THIS SPECIES? `held` is whatever the licence provider answered -- a set of
-- species names -- and nil means "he holds none", which is every player today.
function Licences.allows(species: string?, held: { [string]: boolean }?, rows: { [string]: Row }?): boolean
	if not Licences.required(species, rows) then
		return true
	end
	return held ~= nil and held[species :: string] == true
end

return Licences
