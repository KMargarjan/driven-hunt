--!strict
-- MapGen.Digest: A CANONICAL DIGEST OF A BUILT MAP, and PURE. Given the same instances and the same
-- terrain samples it returns the same 64 hex characters; change one position by a hundredth of a stud
-- and it returns something else.
--
-- WHAT IT IS NOT: it is not SHA-256 and it does not pretend to be. It is two 32-bit FNV-1a streams
-- printed as 8 hex digits each and padded to 64, i.e. A CHANGE DETECTOR, not a cryptographic hash.
-- Nothing here defends against someone CHOOSING a colliding map; it defends against a hand edit in
-- Studio quietly becoming the committed map, which is the threat the design names (section 6.4).
-- Saying so here is cheaper than someone later trusting it for something it cannot do.
--
--   FNV-1a  http://www.isthe.com/chongo/tech/comp/fnv/  (public domain, by the author's statement)
--   bit32   https://luau.org/library#bit32-library -- 32-bit ops on doubles, which is why the
--           streams are 32-bit: Luau has no 64-bit integer to carry a wider accumulator in.
--
-- THE DIGEST HAS TWO HALVES, and the split is load-bearing: `markers .. terrain`, 32 hex each. A
-- server spec can recompute the MARKER half in milliseconds from the live parts (design section 13.1
-- check 11), while the terrain half needs 4,096 voxel reads and belongs to `mapgen.py verify`.
--
-- Design: docs/design/map-generator.md (section 6.4)
local Digest = {}

export type Entry = {
	name: string, -- the full name, e.g. "DrivenHuntMap.Markers.ShooterPost3"
	className: string,
	position: Vector3,
	size: Vector3,
	tags: { string },
}

export type Sample = { x: number, z: number, occupancy: number, material: string }

local PRIME = 16777619
local OFFSET_A = 2166136261
local OFFSET_B = 84696351 -- a second basis, so the two words of a half are not the same function

-- 32-bit multiply, SPLIT IN HALVES because a double loses bits above 2^53: hash * PRIME reaches
-- 7.2e16 and its low 32 bits would then be garbage that differs between builds. Each product here
-- stays under 1.2e12, which a double holds exactly.
local function mul32(hash: number, factor: number): number
	local low = hash % 65536
	local high = (hash - low) / 65536
	return (low * factor + ((high * factor) % 65536) * 65536) % 4294967296
end

local function fnv1a(text: string, offset: number): number
	local hash = offset
	for index = 1, #text do
		hash = mul32(bit32.bxor(hash, string.byte(text, index)), PRIME)
	end
	return hash
end

-- 16 hex characters from one text: two independent words, so a single-byte change moves both.
local function word(text: string): string
	return string.format("%08x%08x", fnv1a(text, OFFSET_A), fnv1a(text, OFFSET_B))
end

-- Half a digest: 32 hex characters, the text hashed once and its reverse hashed again. The reverse
-- pass is what stops FNV's weakest property here -- that appending to the text only extends the walk.
function Digest.half(text: string): string
	return word(text) .. word(string.reverse(text))
end

local function round(value: number, scale: number): number
	-- Integers, so the text never carries "-0" or a float's 17th digit and two runs agree exactly.
	return math.floor(value * scale + 0.5)
end

-- One canonical line per instance. Rounded to 0.01 studs (design section 6.4): the engine's float32
-- positions differ in the last bits between sessions, and a digest that fails on that is noise.
function Digest.line(entry: Entry, scale: number): string
	local tags = table.clone(entry.tags)
	table.sort(tags)
	return string.format(
		"%s|%s|%d|%d|%d|%d|%d|%d|%s",
		entry.name,
		entry.className,
		round(entry.position.X, scale),
		round(entry.position.Y, scale),
		round(entry.position.Z, scale),
		round(entry.size.X, scale),
		round(entry.size.Y, scale),
		round(entry.size.Z, scale),
		table.concat(tags, ",")
	)
end

-- The marker block: every instance, sorted BY ITS OWN LINE rather than by name, so two same-named
-- siblings (which the contract check catches separately) still produce one stable order.
function Digest.markerText(entries: { Entry }, scale: number): string
	local lines = {}
	for _, entry in ipairs(entries) do
		table.insert(lines, Digest.line(entry, scale))
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end

function Digest.terrainText(samples: { Sample }, scale: number): string
	local lines = {}
	for _, sample in ipairs(samples) do
		table.insert(
			lines,
			string.format(
				"%d|%d|%d|%s",
				round(sample.x, 1),
				round(sample.z, 1),
				round(sample.occupancy, scale),
				sample.material
			)
		)
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end

-- The whole digest: 64 hex characters, the marker half first.
-- The palette, as canonical text. It is IN the digest (design section 8.4) because a hand-edited
-- terrain colour is a change to the map that nothing else would notice: the voxels are identical, the
-- markers are identical, and the place looks different.
function Digest.paletteText(palette): string
	if palette == nil then
		return ""
	end
	local roles = {}
	for role in pairs(palette) do
		table.insert(roles, role)
	end
	table.sort(roles)
	local lines = {}
	for _, role in ipairs(roles) do
		local colour = palette[role]
		table.insert(
			lines,
			string.format(
				"%s=%d,%d,%d",
				role,
				math.round(colour.R * 255),
				math.round(colour.G * 255),
				math.round(colour.B * 255)
			)
		)
	end
	return table.concat(lines, "|")
end

function Digest.of(entries: { Entry }, samples: { Sample }, scale: number, palette): string
	return Digest.half(Digest.markerText(entries, scale))
		.. Digest.half(Digest.terrainText(samples, scale) .. "|palette|" .. Digest.paletteText(palette))
end

-- The half a spec can afford to recompute.
function Digest.markerHalf(digest: string): string
	return string.sub(digest, 1, 32)
end

return Digest
