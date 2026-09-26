--!strict
-- Flags: the declarations and defaults of every feature flag, the pure resolver, and this process's
-- one resolved answer. Booleans only -- no game number and no string ever lives here.
--
-- WHY: feel-critical work (shooting, camera, penalty, the map switch) used to wait for Karen's
-- playtest before merging, so ten PRs stacked on one unmerged PR. A flagged path MERGES as soon as
-- it is reviewed and green, switched OFF; the Director turns it ON for a playtest with
-- `tools/flags.py set <NAME> on`, which touches no file; Karen's OK flips the default in a later
-- three-line commit.
--
-- OWNERSHIP (rule 3), three distinct things and one writer each:
--   * these declarations        -- NOBODY at run time. Frozen data; the Builder edits this file and
--                                 git records it. The same shape as Shotgun.CONFIG and the map
--                                 contract row in GAME_DESIGN.md.
--   * ReplicatedStorage.Flags.State attributes (the mirror clients read)
--                              -- ServerScriptService.FlagsBoot, once per server lifetime.
--   * ServerStorage DHFlag_* attributes (the Studio override)
--                              -- tools/studio_mcp.py, Edit mode only.
--
-- There is no setter, no listener, no event and no remote. A flag is resolved once per process and
-- memoised; nothing can change it afterwards, which is what makes "what was this run tested with"
-- a question with one answer.
--
-- Pattern: a frozen declaration table plus a pure resolver, as src/shared/Shotgun/init.luau and
-- src/shared/Drive/init.luau already are here; the toggle lifecycle (born/expires, and expiry as a
-- build failure) is Pete Hodgson's "Feature Toggles", https://martinfowler.com/articles/feature-toggles.html
-- Design: docs/design/feature-flags.md (sections 3, 4, 5, 11, 12)
-- Note:   docs/research/2026-09-26-feature-flags.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Flags = {}

export type FlagRow = {
	default: boolean, -- the reviewed value. A new dark path is born `false`.
	owner: string, -- the module that READS it, e.g. "ServerScriptService.Match"
	born: string,
	expires: string, -- ISO date: retire, flip, or re-justify by this date. Past = the specs fail.
	why: string, -- one line: what turning it ON does, in the player's terms
}

-- All-caps, so a flag name can never collide with the mirror's own Digest/Source attributes, and so
-- it satisfies Roblox's attribute-name rules (no leading digit, no RBX prefix).
Flags.NAME_PATTERN = "^[A-Z][A-Z0-9_]*$"
Flags.MAX_NAME_LENGTH = 40 -- "DHFlag_" + 40 <= Roblox's 100-character attribute-name limit
Flags.OVERRIDE_PREFIX = "DHFlag_"
Flags.MAX_FLAGS = 12 -- more than twelve dark paths means the stack problem moved, not went away
Flags.WAIT_SECONDS = 10 -- a client's wait for the published mirror
Flags.STATE_NAME = "State"
Flags.DIGEST_ATTRIBUTE = "Digest"
Flags.SOURCE_ATTRIBUTE = "Source"
Flags.SOURCES = { defaults = true, override = true, published = true, ["published-timeout"] = true }

-- THE DECLARATIONS. One row per flag; see docs/design/feature-flags.md section 11 for the lifecycle.
Flags.DEFAULTS = {
	TIE_UNTIL_DRIVE_END = {
		default = true,
		owner = "ServerScriptService.Match",
		born = "2026-09-25 task 32 (as Match.CONFIG), 2026-09-26 task 52 (as a flag)",
		-- ACCEPTED by Karen already, so this one does not expire in 21 days like a new dark path:
		-- it stays until the losing TIE_SECONDS branch is archived (design section 10 step 7).
		expires = "2026-12-31",
		why = "A tied player stays tied until the drive ends. OFF frees him after TIE_SECONDS.",
	} :: FlagRow,
	BOAR_SOUNDERS = {
		default = false,
		-- The owner NAMED here is the module that will read it at its boundary
		-- (`Match.CONFIG.SOUNDER.ENABLED`) when the drive learns to release a sounder. THAT IS THE
		-- NEXT TASK (Director decision J: the sounder exists first, the drive releases it second),
		-- so today nothing reads this row and turning it on changes nothing a player can see. It is
		-- declared now because the Director asked for the flag to exist with the behaviour, and
		-- because a row born OFF is what lets the behaviour merge dark.
		owner = "ServerScriptService.Match",
		born = "2026-09-26 task 60 (the sounder itself; the release is task 61)",
		expires = "2026-10-17", -- 20 days: inside the 21-day ceiling (feature-flags.md section 12)
		why = "Boars come as a mix of singles and sounders of 2-5. OFF releases one boar per release, as today.",
	} :: FlagRow,
}

-- deepFreeze, REQUIRED and not copied: table.freeze is shallow, and this repo has already paid for
-- that once (src/shared/Drive/init.luau, Task 23a note (b)). A row's fields must be frozen too.
Shotgun.deepFreeze(Flags.DEFAULTS)

local ISO_DATE = "^(%d%d%d%d)%-(%d%d)%-(%d%d)$"

-- ---------------------------------------------------------------- pure

-- The reviewed value of every flag: name -> boolean. A new frozen table each call.
function Flags.defaults(): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for name, row in pairs(Flags.DEFAULTS) do
		out[name] = row.default
	end
	return table.freeze(out)
end

-- resolve(defaults, overrides) -> (a NEW frozen table, the rejected override keys with a reason).
-- It never mutates either argument and NEVER COERCES a value: "true" is not true, and 1 is not true.
-- An override for a name that is not declared is rejected rather than created, because a flag that
-- exists only because somebody set an attribute is a flag nothing reviewed.
function Flags.resolve(
	defaults: { [string]: boolean },
	overrides: { [string]: any }?
): ({ [string]: boolean }, { string })
	-- table.clone, not a hand-rolled loop: it is shallow, which is exactly right for a map of
	-- booleans, and it returns an UNFROZEN copy of a frozen argument, which is what lets the
	-- overrides be applied to it without touching the caller's table.
	local out: { [string]: boolean } = table.clone(defaults)
	local rejected: { string } = {}
	if overrides then
		local names: { string } = {}
		for name in pairs(overrides) do
			table.insert(names, name)
		end
		table.sort(names) -- a stable order, so two runs report the same list
		for _, name in ipairs(names) do
			local value = overrides[name]
			if defaults[name] == nil then
				table.insert(rejected, string.format("unknown flag %s", name))
			elseif type(value) ~= "boolean" then
				table.insert(rejected, string.format("%s is not a boolean (%s)", name, type(value)))
			else
				out[name] = value
			end
		end
	end
	return table.freeze(out), rejected
end

-- "A=1|B=0", sorted by name. One string that says what a process resolved, so the server and every
-- client can be compared with a single equality.
function Flags.digest(resolved: { [string]: boolean }): string
	local names: { string } = {}
	for name in pairs(resolved) do
		table.insert(names, name)
	end
	table.sort(names)
	local parts: { string } = {}
	for _, name in ipairs(names) do
		table.insert(parts, name .. "=" .. (if resolved[name] then "1" else "0"))
	end
	return table.concat(parts, "|")
end

-- Every declaration fault in ONE list, so a bad row is one spec failure and not five runs.
-- `today` is a parameter, not os.date, so the rot tripwire is testable at any date (section 13.1).
function Flags.problems(defaults: { [string]: FlagRow }, today: string): { string }
	local out: { string } = {}
	local names: { string } = {}
	for name in pairs(defaults) do
		table.insert(names, name)
	end
	table.sort(names)

	if #names > Flags.MAX_FLAGS then
		table.insert(out, string.format("%d flags declared, and MAX_FLAGS is %d", #names, Flags.MAX_FLAGS))
	end
	if not string.match(today, ISO_DATE) then
		table.insert(out, string.format("today %q is not an ISO date (YYYY-MM-DD)", today))
	end

	for _, name in ipairs(names) do
		local row = defaults[name]
		local where = "flag " .. name
		if not string.match(name, Flags.NAME_PATTERN) then
			table.insert(out, string.format("%s: the name must match %s", where, Flags.NAME_PATTERN))
		end
		if #name > Flags.MAX_NAME_LENGTH then
			table.insert(
				out,
				string.format("%s: the name is %d characters, over %d", where, #name, Flags.MAX_NAME_LENGTH)
			)
		end
		if type(row) ~= "table" then
			table.insert(out, string.format("%s: the row is a %s, not a table", where, type(row)))
			continue
		end
		if type(row.default) ~= "boolean" then
			table.insert(out, string.format("%s: `default` is a %s, not a boolean", where, type(row.default)))
		end
		for _, field in ipairs({ "owner", "born", "expires", "why" }) do
			local value = (row :: any)[field]
			if type(value) ~= "string" or value == "" then
				table.insert(out, string.format("%s: `%s` must be a non-empty string", where, field))
			end
		end
		if type(row.expires) == "string" then
			if not string.match(row.expires, ISO_DATE) then
				table.insert(out, string.format("%s: `expires` %q is not an ISO date (YYYY-MM-DD)", where, row.expires))
			elseif string.match(today, ISO_DATE) and row.expires < today then
				-- THE ROT TRIPWIRE (design section 11). An expired flag fails the spec, which fails
				-- the harness, which blocks the merge gate. The fix is one of three: retire it, flip
				-- it, or move the date with a reason in `why`. Moving it costs one line, so this can
				-- never actually block a task -- it can only force someone to say the flag still has
				-- a reason to exist.
				table.insert(
					out,
					string.format(
						"%s: EXPIRED on %s (today is %s). Retire it, flip its default, or move the date with a reason: docs/design/feature-flags.md section 11",
						where,
						row.expires,
						today
					)
				)
			end
		end
	end
	return out
end

-- {} when isStudio is false or host is nil. THE STUDIO TEST IS AN ARGUMENT, so the production branch
-- -- "a published place ignores every DHFlag_ attribute" -- is provable from inside Studio, where
-- RunService:IsStudio() is always true and no harness run can make it false.
function Flags.readOverrides(host: Instance?, isStudio: boolean): { [string]: any }
	local out: { [string]: any } = {}
	if not isStudio or host == nil then
		return out
	end
	for name, value in pairs(host:GetAttributes()) do
		if string.sub(name, 1, #Flags.OVERRIDE_PREFIX) == Flags.OVERRIDE_PREFIX then
			out[string.sub(name, #Flags.OVERRIDE_PREFIX + 1)] = value
		end
	end
	return out
end

-- ---------------------------------------------------------------- this process

local resolved: { [string]: boolean }? = nil
local source = "defaults"
local line = ""
local rejectedHere: { string } = {}
local overridden: { string } = {}

-- The mirror's host instance. It is a CHILD OF THIS MODULE (src/shared/Flags/State.model.json), so
-- it is found through `script` and never by searching ReplicatedStorage: one file, one instance, and
-- Rojo owns both. It is a Rojo-owned empty Configuration rather than a run-time-created instance
-- because every Rojo-owned container defaults to $ignoreUnknownInstances: false, so an instance with
-- no file on disk is DELETED at the next Connect (CLAUDE.md, "Rojo DELETES Studio-created
-- instances"). An empty .model.json also makes it exist in Edit, where the `flags` command looks.
local function state(): Instance?
	return script:FindFirstChild(Flags.STATE_NAME)
end

local function describe(set: { [string]: boolean }): string
	local names: { string } = {}
	for name in pairs(set) do
		table.insert(names, name)
	end
	table.sort(names)
	local parts: { string } = {}
	for _, name in ipairs(names) do
		table.insert(parts, name .. "=" .. (if set[name] then "1" else "0"))
	end
	return string.format("%d flag%s: %s", #names, if #names == 1 then "" else "s", table.concat(parts, " "))
end

local function resolveOnServer()
	local overrides = Flags.readOverrides(game:GetService("ServerStorage"), RunService:IsStudio())
	local applied = 0
	for _ in pairs(overrides) do
		applied += 1
	end
	local out, rejected = Flags.resolve(Flags.defaults(), overrides)
	resolved = out
	rejectedHere = rejected
	applied -= #rejected
	source = if applied > 0 then "override" else "defaults"

	local defaults = Flags.defaults()
	for name, value in pairs(out) do
		if defaults[name] ~= value then
			table.insert(overridden, name)
		end
	end
	table.sort(overridden)
end

local function resolveOnClient()
	local host = state()
	local digest: any = host and host:GetAttribute(Flags.DIGEST_ATTRIBUTE)
	if host and digest == nil then
		-- WAIT, then fall back. The mirror is written once at server start, before any player
		-- exists, so the real wait is about zero -- but a client that joined during a restart must
		-- not read half a set, which is why the server writes Digest LAST and this waits for it.
		--
		-- The SIGNAL wakes it and the DEADLINE bounds it: a bare poll would cost up to one interval
		-- of latency on every boot, and a bare signal:Wait() would hang a client for ever if the
		-- server never published. `arrived` is written by the connection and read by the loop.
		local arrived = false
		local connection = host:GetAttributeChangedSignal(Flags.DIGEST_ATTRIBUTE):Connect(function()
			arrived = true
		end)
		local deadline = os.clock() + Flags.WAIT_SECONDS
		while not arrived and os.clock() < deadline do
			task.wait(0.05)
			if host:GetAttribute(Flags.DIGEST_ATTRIBUTE) ~= nil then
				break
			end
		end
		connection:Disconnect()
		digest = host:GetAttribute(Flags.DIGEST_ATTRIBUTE)
	end

	if host == nil or digest == nil then
		resolved = Flags.defaults()
		source = "published-timeout"
		return
	end

	local out: { [string]: boolean } = {}
	for name in pairs(Flags.DEFAULTS) do
		local value = host:GetAttribute(name)
		out[name] = if type(value) == "boolean" then value else Flags.DEFAULTS[name].default
	end
	resolved = table.freeze(out)
	source = "published"
	if Flags.digest(out) ~= digest then
		-- Never a silent disagreement: a client that read something other than what the server
		-- published says so, loudly, and calls itself a timeout rather than the truth.
		warn(
			string.format(
				"[flags] the mirror disagrees with what this client read: %q vs the server's %q. Using the defaults.",
				Flags.digest(out),
				tostring(digest)
			)
		)
		resolved = Flags.defaults()
		source = "published-timeout"
	end
end

local function ensure()
	if resolved ~= nil then
		return
	end
	local began = os.clock()
	if RunService:IsServer() then
		resolveOnServer()
	else
		resolveOnClient()
	end
	local set = resolved :: { [string]: boolean }
	line = string.format(
		"[flags] %s %s %s  digest=%s",
		if RunService:IsServer() then "server" else "client",
		source,
		describe(set),
		Flags.digest(set)
	)
	if #overridden > 0 then
		local parts: { string } = {}
		local defaults = Flags.defaults()
		for _, name in ipairs(overridden) do
			table.insert(
				parts,
				string.format("%s=%d (default %d)", name, if set[name] then 1 else 0, if defaults[name] then 1 else 0)
			)
		end
		local total = 0
		for _ in pairs(set) do
			total += 1
		end
		warn(
			string.format(
				"[flags] OVERRIDE ACTIVE (Studio only) %d of %d: %s",
				#overridden,
				total,
				table.concat(parts, " ")
			)
		)
	end
	if #rejectedHere > 0 then
		-- A silently ignored override is how a playtest gets run against the wrong build and then
		-- reported as the right one.
		warn("[flags] override(s) REJECTED and NOT applied: " .. table.concat(rejectedHere, "; "))
	end
	local took = (os.clock() - began) * 1000
	if took > 1 then
		warn(string.format("[flags] resolution took %.2f ms, over the 1 ms budget (design section 12)", took))
	end
end

-- This process's answer. Computed once, memoised, frozen.
function Flags.all(): { [string]: boolean }
	ensure()
	return resolved :: { [string]: boolean }
end

-- ERRORS on a name that is not declared. A typo that read as `false` would be a dark path that
-- silently never runs and a spec that passes for the wrong reason (design section 4.1), the same
-- refusal Penalty.expired makes of "a config number that nothing reads is a lie in a table".
function Flags.isOn(name: string): boolean
	local set = Flags.all()
	local value = set[name]
	if value == nil then
		local known: { string } = {}
		for declared in pairs(Flags.DEFAULTS) do
			table.insert(known, declared)
		end
		table.sort(known)
		error(string.format("Flags.isOn(%q): no such flag. Declared: %s", name, table.concat(known, ", ")), 2)
	end
	return value
end

function Flags.source(): string
	ensure()
	return source
end

function Flags.line(): string
	ensure()
	return line
end

-- SERVER ONLY, and FlagsBoot is its only caller. Digest is written LAST, after every flag, so
-- "Digest present" means "the set is complete" and a client can never read half a set.
function Flags.publish(resolvedSet: { [string]: boolean }, publishedSource: string): ()
	if not RunService:IsServer() then
		error("Flags.publish is server-only: a client never writes the mirror it reads", 2)
	end
	local host = state()
	if host == nil then
		error("Flags.publish: ReplicatedStorage.Flags.State is missing (src/shared/Flags/State.model.json)", 2)
	end
	if Flags.SOURCES[publishedSource] == nil then
		error(string.format("Flags.publish: %q is not one of the declared sources", publishedSource), 2)
	end
	for name in pairs(host:GetAttributes()) do
		host:SetAttribute(name, nil)
	end
	for name, value in pairs(resolvedSet) do
		host:SetAttribute(name, value)
	end
	host:SetAttribute(Flags.SOURCE_ATTRIBUTE, publishedSource)
	host:SetAttribute(Flags.DIGEST_ATTRIBUTE, Flags.digest(resolvedSet)) -- LAST, always
end

return Flags
