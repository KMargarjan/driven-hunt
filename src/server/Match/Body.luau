--!strict
-- Match.Body: the only writer of a player's TEAM and of where their character stands. Named after
-- Boar/Body.luau, which has exactly this role for the boar: the module that touches Instances so
-- that nothing else in the system has to.
--
-- It decides NOTHING. Every team, every position and every timing arrives as an argument.
--
--   Team / Player.Team  https://create.roblox.com/docs/reference/engine/classes/Team
--     Roblox's own team field: server-authoritative (a client cannot write it), replicated for free,
--     and what Boar.CONFIG.isThreat and Shotgun.CONFIG.shouldArm were both written against. Teams is
--     NOT a Rojo-owned container, so the two Team instances are created at run time and are
--     invisible to the harness's file comparison -- a spec is the only proof they exist.
--     AutoAssignable is set to FALSE explicitly: the page does not state its default
--     (docs/research/2026-09-25-drive.md source A), and Roblox assigning players itself would be a
--     second writer of the one field this system owns.
--
-- PivotTo AFTER LoadCharacter IS A TWO-STEP, not one call: the character does not exist
-- synchronously. place() connects CharacterAdded BEFORE calling LoadCharacter and pivots in that
-- handler, and the owner counts placementsMissed when a character never arrives -- a number in the
-- harness report rather than a feeling in a playtest.
--
-- Design: docs/design/drive.md (sections 5.1, 5.3)
-- Note:   docs/research/2026-09-25-drive.md
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local Body = {}

export type TeamName = "Drivers" | "Shooters"

local TEAM_COLORS = {
	Drivers = BrickColor.new("Bright blue"),
	Shooters = BrickColor.new("Bright orange"),
}

-- Creates the two teams once and returns them by name. Idempotent: a second call returns what is
-- already there rather than making a duplicate (rule 7 -- nothing here ever deletes a Team either).
function Body.ensureTeams(): { [string]: Team }
	local out = {}
	for name, color in pairs(TEAM_COLORS) do
		local existing = Teams:FindFirstChild(name)
		local team = if existing and existing:IsA("Team") then existing else Instance.new("Team")
		team.Name = name
		team.TeamColor = color
		team.AutoAssignable = false
		team.Parent = Teams
		out[name] = team
	end
	return out
end

function Body.teamNamed(name: string?): Team?
	if not name then
		return nil
	end
	local team = Teams:FindFirstChild(name)
	return if team and team:IsA("Team") then team else nil
end

-- One player's team, by NAME. Never by reference: comparing by name is the only form that survives a
-- Team being recreated (source A).
function Body.setTeam(player: Player, name: TeamName?)
	player.Team = Body.teamNamed(name)
	player.Neutral = name == nil
end

function Body.teamOf(player: Player): TeamName?
	local team = player.Team
	if not team then
		return nil
	end
	return (team.Name :: any) :: TeamName?
end

-- Where a player of this team stands, given the marker set and their index within the team.
-- Shooters take one post each, by index, and face +Z (up the drive). Drivers spread across the
-- driver start's X extent and face -Z (toward the line).
function Body.placementFor(markers, team: TeamName, index: number, config): CFrame?
	if team == "Shooters" then
		local posts = markers.posts
		if #posts == 0 then
			return nil
		end
		local post = posts[((index - 1) % #posts) + 1]
		local at = post.Position + Vector3.new(0, post.Size.Y / 2 + config.STAND_HEIGHT_STUDS, 0)
		return CFrame.lookAt(at, at + Vector3.new(0, 0, 1))
	end

	local start = markers.driverStart
	if not start then
		return nil
	end
	local width = math.max(start.Size.X - 4, 1)
	local count = math.max(config.MAX_PLAYERS, 1)
	-- Spread deterministically across the pad, so two drivers never spawn inside each other.
	local fraction = ((index - 1) % count) / count
	local x = start.Position.X - width / 2 + width * fraction
	local at = Vector3.new(x, start.Position.Y + start.Size.Y / 2 + config.STAND_HEIGHT_STUDS, start.Position.Z)
	return CFrame.lookAt(at, at + Vector3.new(0, 0, -1))
end

-- Respawns `player` and puts them where `cframe` says. Returns a function the owner can call to give
-- up waiting; `onPlaced(true/false)` is called exactly once.
function Body.place(player: Player, cframe: CFrame?, config, onPlaced: ((boolean) -> ())?)
	local finished = false
	local connection: RBXScriptConnection? = nil

	local function finish(ok: boolean)
		if finished then
			return
		end
		finished = true
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if onPlaced then
			onPlaced(ok)
		end
	end

	local function pivot(character: Model)
		if not cframe then
			finish(true) -- nowhere to put them: they spawned, and that is not a failure
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			-- The character exists but its root has not replicated yet. One wait, then try again.
			character:GetPropertyChangedSignal("PrimaryPart"):Wait()
		end
		if character.Parent then
			character:PivotTo(cframe)
			finish(true)
		end
	end

	-- CONNECTED BEFORE LoadCharacter, which is the whole point: the character does not exist when
	-- LoadCharacter returns, and a pivot on the old one moves a corpse.
	connection = player.CharacterAdded:Connect(function(character)
		task.spawn(pivot, character)
	end)

	local ok = pcall(function()
		player:LoadCharacter()
	end)
	if not ok then
		finish(false)
		return
	end

	task.delay(config.PLACE_TIMEOUT, function()
		finish(false)
	end)
end

-- Every live player, as the boar's world wants them: only DRIVERS scare boars, which is the
-- mechanic -- a shooter standing on a post must not push the boar back into the wood before it
-- reaches the line.
function Body.driverPositions(teamOf: (Player) -> TeamName?, service: any?): { { id: string, position: Vector3 } }
	local out = {}
	for _, player in ipairs((service or Players):GetPlayers()) do
		if teamOf(player) == "Drivers" then
			local character = player.Character
			local root = character and character.PrimaryPart
			if root then
				table.insert(out, { id = tostring(player.UserId), position = root.Position })
			end
		end
	end
	return out
end

return Body
