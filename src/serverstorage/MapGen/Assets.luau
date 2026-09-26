--!strict
-- MapGen.Assets: THE ASSET MANIFEST. Pure data, frozen, and EMPTY on purpose.
--
-- Karen's Meshy models and Creator Store choices do not exist yet, so `byKey` returns nil for every
-- key and `Props` places a grey-box PROXY of the right footprint instead (design section 8.3). That
-- is the whole reason M2.1 is buildable today: a later asset id replaces one proxy and no code
-- changes. `ROWS` being empty is therefore a state, not a hole.
--
-- ROWS ARE APPENDED AND VERSIONED, NEVER EDITED (research note section 9): a changed mesh is a NEW
-- asset id, so replacing an id in place would destroy the provenance of the map already built from
-- the old one, and a moderated-away id would become undiagnosable. `byKey` answers with the highest
-- `version` for that key.
--
-- The binary is NEVER committed (`.rbxm` is banned outright, CLAUDE.md), so this table plus the id
-- IS the record of where each model came from and under what licence.
--
-- Design: docs/design/map-generator.md (section 8.1)
-- Note:   docs/research/2026-09-24-map-generator.md (sections 8, 9)
local Assets = {}

export type AssetRow = {
	key: string, -- "tree.spruce.a" -- what Layout and Scatter ask for
	id: number, -- rbxassetid
	name: string, -- as listed on the Creator Store / as exported from Meshy
	creator: string,
	source: "creator-store" | "meshy" | "roblox",
	licenceNote: string, -- one line; Creator Store: "use on Roblox only, not redistributable"
	added: string, -- ISO date
	version: number, -- bumped when a new id replaces this one; the row is APPENDED, never edited
	tris: number?, -- measured at import, nil until measured
	kind: "mesh" | "model",
}

-- The keys the generator asks for. Listed even while ROWS is empty, because the proxy needs a
-- footprint per key and a typo'd key must be a lint-visible name rather than a silent nil.
--
-- ONE KEY PER SPECIES, not one key for the wood (audit-005 must-fix 2). The four species have
-- different trunks, crowns, heights and colours, so they will be four different meshes: a single
-- `treeSpruce` key meant that the day the first tree id landed, all ~2,700 trees in the wood became
-- the same spruce mesh while every species spec still passed, because every one of them was a claim
-- about `Scatter.speciesAt` and not about what was planted. The key a tree asks for now comes from
-- its OWN species row (`Config.SPECIES[i].assetKey`), and `Props.trees` reports the keys it proxied
-- per species -- so a wood built from one key is visible in the step's own report.
-- The names are docs/design/map-generator.md section 12.1's exactly.
Assets.KEY = table.freeze({
	treeSpruce = "tree.spruce.a",
	treeBirch = "tree.birch.a",
	treeOak = "tree.oak.a",
	treeAlder = "tree.alder.a",
	hedge = "hedge.mixed.a",
	-- M2.8c: the high seat behind four of the stands. Design section 18 names the key; until a row
	-- exists `Props.furniture` builds the seven-box proxy, and when one does the model replaces the
	-- WHOLE proxy rather than one box of it.
	highSeat = "prop.highseat",
})

Assets.ROWS = {} :: { AssetRow }

-- The newest version for a key, or nil -- which means "place a proxy", not "fail".
function Assets.byKey(key: string): AssetRow?
	local best: AssetRow? = nil
	for _, row in ipairs(Assets.ROWS) do
		if row.key == key and (best == nil or row.version > best.version) then
			best = row
		end
	end
	return best
end

return Assets
