--!strict
-- Bots.Rig: THE ONLY WRITER OF A BOT RIG'S INSTANCES, and of `Workspace.DriveBots` (rule 3). It
-- builds one R15 body, sets its properties, parents it, places it, and destroys it. It decides
-- nothing: how many there are is `Bots.Fill`'s, where they walk is `Bots.Lane`'s, when any of it
-- happens is the owner's, and what they WEAR is `Match.Body`'s and is reached through an injected
-- seam so there is one dressing path in this repo and not two.
--
-- THE BOUNDARY WITH `Match.Body` IS THE PLAYER (docs/design/bots.md section 3.2). `Body` is the only
-- writer of a PLAYER's character -- its team, its position, its freeze, its clothes and the one
-- `held` table keyed by userId. This module is the only writer of a BOT's. It never touches `held`
-- (a bot has no userId to key it with) and never calls `Body.place`, `Body.hold`, `Body.stand`,
-- `Body.tie` or `Body.dressWhenLoaded` -- all five take a `Player`.
--
-- THE RIG SOURCE IS INJECTED, the shape `Boar.setModelSource` and `Body.setAccessorySource` already
-- have: the default is the engine's own R15 builder and a spec hands in a fake body, so every spec
-- runs with no avatar service, no web call and no Play.
--   Players:CreateHumanoidModelFromDescription
--     https://create.roblox.com/docs/reference/engine/classes/Players#CreateHumanoidModelFromDescription
--
-- Design: docs/design/bots.md (sections 3.2, 11)
-- Note:   docs/research/2026-10-12-bots.md (sections 2.2, 2.5)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Rig = {}

Rig.FOLDER_NAME = "DriveBots"

-- THE DEFAULT SOURCE: one call is a complete R15 rig with a Humanoid, so there is no hand-built rig,
-- no `.rbxm` (banned) and no sixty-line model file. An EMPTY `HumanoidDescription` on purpose -- no
-- bundle, no clothing, nothing to fetch -- because `Match.Body.dress` paints the green and wears the
-- hat and the vest, and a described outfit would be a second answer to what a beater looks like.
local function defaultSource(description: HumanoidDescription, rigType: Enum.HumanoidRigType): Model?
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, rigType)
	end)
	if not ok or typeof(model) ~= "Instance" then
		return nil
	end
	return model :: Model
end

local source: (HumanoidDescription, Enum.HumanoidRigType) -> Model? = defaultSource

function Rig.setSource(fn: ((HumanoidDescription, Enum.HumanoidRigType) -> Model?)?)
	source = fn or defaultSource
end

function Rig.source(): (HumanoidDescription, Enum.HumanoidRigType) -> Model?
	return source
end

-- THE ONE RUN-TIME CONTAINER, created on demand under Workspace. `Workspace` is not Rojo-owned and
-- the harness compares the EDIT DataModel, so a rig built during Play cannot dirty a run -- exactly
-- as `Workspace.DriveMarkers`, `DriveScene`, `ForestMarkers`, `WeaponEffects` and `Boars` do not.
function Rig.folder(): Folder
	local existing = Workspace:FindFirstChild(Rig.FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = Rig.FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

-- MAY YIELD. `CreateHumanoidModelFromDescription` is documented to load assets, so the owner keeps
-- this off its step loop and guards the result with an epoch (`Bots.step`). Returns nil rather than
-- erroring: a build that fails is a number in the report, not a dead drive.
function Rig.build(name: string): Model?
	local model = source(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	if model == nil then
		return nil
	end
	model.Name = name
	return model
end

-- WHAT A BOT'S BODY IS SET TO, and two of these are measurements rather than tidiness.
--
-- `CanQuery = false` ON EVERY PART, and the reason is this repo's own, stated the same way in
-- `Match.Scene`, `Match.Body` and `ForestTest.Markers`: *a prop that stops a pellet changes what the
-- shot hit, and what the shot hit is what the safety rule and the hit record read*. Three facts
-- become true at once with one property instead of a filter in three places -- a bot cannot be
-- credited a hit, cannot appear in the drive report, and cannot stop a shot that is otherwise legal.
-- `shootable = true` is the fallback if a humanoid turns out not to WALK with it off, and the
-- measurement is the Builder's to take (design section 11.3).
--
-- `CanTouch = false`: a body should not fire `Touched` at anything.
--
-- `DisplayDistanceType = None`: eight name tags over the stands is eight things Karen did not ask to
-- see.
function Rig.prepare(model: Model, config, walks: boolean): Humanoid?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return nil
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed = if walks then config.WALK_SPEED else 0
	humanoid.JumpHeight = 0
	humanoid.JumpPower = 0

	-- THE VENDOR'S OWN SENTENCE, taken as far as the outfit allows (Roblox, "Improve performance":
	-- *"Static NPCs that do not move generally have no need for the Humanoid class"*, and *"There is
	-- a performance cost to leaving certain HumanoidStateTypes enabled"*). The class has to stay --
	-- `Humanoid:AddAccessory` needs it and the outfit is `Body`'s -- so what goes is the WORK: a
	-- stander evaluates no state machine at all.
	if not walks then
		humanoid.EvaluateStateMachine = false
		-- ...AND EVERY STATE OFF, which is what the design asks for in so many words (section 9.2,
		-- *"every `HumanoidStateType` disabled via `SetStateEnabled`"*) and what round 1 found
		-- missing. `None` is skipped because it is not a state a humanoid can be in; the rest are a
		-- stander's whole repertoire of work, and it does none of it.
		for _, state in ipairs(Enum.HumanoidStateType:GetEnumItems()) do
			if state ~= Enum.HumanoidStateType.None then
				humanoid:SetStateEnabled(state, false)
			end
		end
	end

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanTouch = false
			if config.SHOOTABLE ~= true then
				part.CanQuery = false
			end
		end
	end
	return humanoid
end

-- WHERE IT STANDS. A stander is ANCHORED and a walker is not, and the anchor is the same measurement
-- `Body.holdCharacter`'s header records: a character's physics is owned by a client, so a
-- server-side pivot alone is a suggestion. Nothing else in the game owns a bot's physics, but a
-- stander on a post must not be nudged off it by anything, and anchoring is also what makes the
-- vendor's "static NPC" case cost nothing.
function Rig.place(model: Model, cframe: CFrame, anchored: boolean): boolean
	if model.Parent == nil then
		return false
	end
	local found = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not (found and found:IsA("BasePart")) then
		return false
	end
	local root = found :: BasePart
	if model.PrimaryPart == nil then
		model.PrimaryPart = root
	end
	root.Anchored = anchored
	model:PivotTo(cframe)
	return true
end

-- Where it is now, flat or not -- nil for a rig that has lost its root or its parent.
function Rig.positionOf(model: Model?): Vector3?
	if model == nil or model.Parent == nil then
		return nil
	end
	local found = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if found and found:IsA("BasePart") then
		return (found :: BasePart).Position
	end
	return nil
end

-- ------------------------------------------------------------------ the walk (task 161 round 2, MEASURED in 164)
--
-- A RIG BUILT BY THE ENGINE CARRIES NO `Animate` SCRIPT. That script comes from
-- `StarterCharacterScripts`, which only a PLAYER's character gets, so without these clips a bot
-- walks upright without moving its legs -- it SLIDES. That is the first thing Karen would see, and
-- it is exactly the class of failure `docs/PROJECT_CONTEXT.md` exists about: everything measures
-- correct and it looks wrong.
--
-- TASK 164 IS KAREN LOOKING AT IT ANYWAY -- *"bots looks odd improve waliking"* (2026-10-12) -- AND
-- EVERY NUMBER BELOW WAS THEN MEASURED OFF THE ENGINE ITSELF rather than reasoned about. The probe
-- read a real player's own `Animate` script and its playing `AnimationTrack`s through StudioMCP,
-- and read the live bots in Karen's Forest Test place the same way
-- (`docs/research/2026-10-12-bots.md` section 7 records both runs, with the raw lines).
--
-- THE CLIPS ARE ROBLOX'S OWN DEFAULTS, AND SINCE TASK 164 THEY ARE THE ONES A PLAYER ACTUALLY
-- PLAYS. Task 161 took the ids from the older R15 set; the probe read what the engine itself put in
-- `Character.Animate` on 2026-10-12 and found a player walking on a DIFFERENT clip:
--     913402848  "WalkAnim"           <- the default animation set's walk: what a player plays
--     507777826  "R15Walk"            <- task 161's id, the older set. Loads, but nobody else plays it
--     507766666  "R15IdleLookAround"  <- `Animate`'s own `idle/Animation2`
--     507768375  "ToolNoneAnim"       <- what a player's arm does while a Tool is in its hand
-- `IsPublicDomain` is FALSE on all of them, and that is said out loud rather than glossed: it is
-- false for every Roblox-owned default, and it is the reason these are NOT run through the repo's
-- upload and manifest pipeline (`ServerStorage.Assets`), which is for assets WE publish.
--
-- THE IDLE STAYS THE LOOK-AROUND ONE, against the player's own usual choice, and that is a decision
-- rather than an oversight: `Animate` picks `idle/Animation1` (507766388) nine times in ten and the
-- look-around one time in ten, but a bot hunter does nothing but stand on a stand for a whole
-- drive, and the dispatch asks for *"a subtle idle / look-around"*. The probe measured 507766666
-- already playing at weight 1.00 on all three standers, so "standing stock still" was NOT what was
-- wrong. Reported as measured, and not changed.
--
-- IT IS PLAYED FROM THE SERVER, which the vendor names as a cost -- *"NPC animations that run on the
-- server need to be simulated on the server and replicated to the client"*
-- (https://create.roblox.com/docs/performance-optimization/improve). Four walkers is the whole of
-- it, and the alternative -- a client module that animates somebody else's rig -- would be a second
-- writer of a body this file owns. If the cost is ever measured, the page's own answer is an
-- `AnimationController` on the client and that is a task with a measurement beside it.
--
-- A FAILURE HERE CANNOT STOP A BOT WALKING. Every load is pcall'd and counted; a bot with no clips
-- is exactly the bot task 161 round 1 shipped.
Rig.CLIPS = table.freeze({
	walk = "rbxassetid://913402848",
	idle = "rbxassetid://507766666",
})

-- THE TOOL POSE, AND IT IS A SEPARATE SLOT ON PURPOSE. `Rig.playClip` stops every OTHER clip in
-- `Rig.CLIPS`, and this one has to play ON TOP of the walk -- which is exactly what a player does:
-- the probe read `ToolNoneAnim` at priority `Idle`, weight 1.00, playing AT THE SAME TIME as
-- `WalkAnim` at priority `Core`. `Core` ranks below `Idle` in `Enum.AnimationPriority`, so the tool
-- clip wins the arm joints and the gait keeps the legs.
--   https://create.roblox.com/docs/reference/engine/enums/AnimationPriority
--
-- WHAT IT FIXES, measured in Karen's own place on 2026-10-12: every bot beater had `tool=Horn` in
-- its hand and `tracks=[507777826]` -- the walk clip ALONE. So the horn rode a freely swinging arm
-- while a player beside it holds its tool still. This is the dispatch's *"a bot beater holding the
-- horn should hold it like a player"*, and "like a player" is now literally the same asset at the
-- same priority.
Rig.TOOL_CLIP = "rbxassetid://507768375"

-- HOW FAST THE LEGS TURN OVER, AND ALL OF IT IS A MEASUREMENT (task 164). The probe held W in a real
-- Play session, set `Humanoid.WalkSpeed` to each of 2..16 in turn and read the walk track's own
-- `Speed` back out of the engine's `Animate` script:
--     ws      2      3      4      5      6     7..12    16
--     rate  0.3074 0.4435 0.5948 0.7411 0.8899 1.0000  1.1846
-- Below ~6.74 studs/s the rate is LINEAR in the ground speed -- rate/ws is 0.1478, 0.1487, 0.1482,
-- 0.1483 at ws 3, 4, 5, 6 -- and from 7 up it pins at 1.0 while the RUN clip fades in by WEIGHT
-- instead (0.039 at ws 7, 0.339 at ws 9, 0.780 at ws 12, 1.000 at ws 16). So `913402848` is authored
-- for a natural ground speed of 1 / 0.14827 = 6.74 studs/s, and the engine's own answer for a
-- character slower than that is `speed / 6.74`.
--
-- OUR BOTS WALK AT `Bots.CONFIG.WALK_SPEED` = 5 AND WERE PLAYING AT 1.000. Measured live in the
-- Forest Test the same day: four beaters at 4.70-5.00 studs/s of real ground speed, every one of
-- them turning its legs over for a 6.74 studs/s gait. That is a 35% overspeed with the foot on the
-- ground, and it is the sliding Karen was looking at.
--
-- THE SWITCH POINT IS THE ENGINE'S TOO: `Animate`'s `onRunning` walks above 0.75 studs/s and idles
-- below it. And the ws=2 sample sitting 3.6% ABOVE the straight line is that script's own rate floor
-- beginning to bite, so `MIN_RATE` is 0.30 rather than a number chosen here.
--
-- `IDLE_BELOW_STUDS` IS THE ONE INVENTED NUMBER AND IT IS A DEAD BAND, not a threshold: with a
-- single threshold a bot sitting at 0.75 studs/s -- which is what a bot shouldering a trunk does --
-- flips clip every step at 5 Hz, and that is the stop-start the dispatch asks about. Walk above
-- 0.75, idle below 0.50, and BETWEEN THEM KEEP WHAT IS PLAYING. Ordinary hysteresis, and `Rig.gait`
-- is pure so `bots_lane.spec` drives the band rather than this comment claiming it.
Rig.GAIT = table.freeze({
	NATURAL_WALK_SPEED = 6.74,
	WALK_ABOVE_STUDS = 0.75,
	IDLE_BELOW_STUDS = 0.5,
	MIN_RATE = 0.3,
	MAX_RATE = 1,
	-- A 5 Hz step must not call into the Animator for a rate that has not really moved.
	RATE_EPSILON = 0.02,
	FADE_SECONDS = 0.2,
})

export type Clips = {
	walk: AnimationTrack?,
	idle: AnimationTrack?,
	tool: AnimationTrack?,
	playing: string?,
	rate: number?,
	holding: boolean?,
}

-- PURE: a ground speed and what is playing now -> the clip to play, and the rate to play it at.
-- Nothing here reads an Instance, so a spec drives the dead band and the rate law directly.
function Rig.gait(speed: number, playing: string?): (string, number)
	local g = Rig.GAIT
	local want
	if speed > g.WALK_ABOVE_STUDS then
		want = "walk"
	elseif speed < g.IDLE_BELOW_STUDS then
		want = "idle"
	else
		-- INSIDE THE DEAD BAND: whatever is already playing, which is the whole of the fix.
		want = if playing == "walk" then "walk" else "idle"
	end
	if want ~= "walk" then
		return want, 1
	end
	return "walk", math.clamp(speed / g.NATURAL_WALK_SPEED, g.MIN_RATE, g.MAX_RATE)
end

-- Loads every clip onto this rig's own `Animator` -> (the clips, how many loaded, how many were
-- TRIED). The owner counts failures off that third return rather than off a number written at the
-- call site, so adding a clip here can never make `clipsFailed` go negative (task 161 round 2's
-- note, now structural instead of a loop at the caller). `{}, 0, 0` for a rig with no humanoid.
function Rig.loadClips(humanoid: Humanoid?): (Clips, number, number)
	if humanoid == nil then
		return {}, 0, 0
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		animator = Instance.new("Animator");
		(animator :: Animator).Parent = humanoid
	end
	-- EVERY RIG LOADS ALL THREE, a stander included. One extra `LoadAnimation` against a uniform
	-- count is worth more than a per-team branch nobody can read the report of.
	local wanted: { [string]: string } = { tool = Rig.TOOL_CLIP }
	for name, id in pairs(Rig.CLIPS) do
		wanted[name] = id
	end
	local clips: Clips = {}
	local loaded = 0
	local tried = 0
	for name, id in pairs(wanted) do
		tried += 1
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		animation.Parent = humanoid
		local ok, track = pcall(function()
			return (animator :: Animator):LoadAnimation(animation)
		end)
		if ok and track ~= nil then
			(clips :: any)[name] = track
			loaded += 1
		else
			animation:Destroy()
		end
	end
	-- THE PRIORITY IS SET RATHER THAN INHERITED. The whole point of the tool clip is that it
	-- outranks the gait on the arm joints, and nothing here should rest on an asset's own stored
	-- priority staying what it is today. `Idle` is what the probe read off a player's own track.
	local tool = clips.tool
	if tool ~= nil then
		pcall(function()
			(tool :: AnimationTrack).Priority = Enum.AnimationPriority.Idle
		end)
	end
	return clips, loaded, tried
end

-- Plays one gait clip at `rate` and stops the other. Idempotent in the clip AND in the rate: asking
-- for what is already playing, at the rate it is already playing at, does nothing -- so this is safe
-- to call from a 5 Hz step. Returns whether the CLIP changed (not the rate), which is what task
-- 161's callers and its specs read.
function Rig.playClip(clips: Clips?, want: string, rate: number?): boolean
	if clips == nil then
		return false
	end
	local track = (clips :: any)[want] :: AnimationTrack?
	if track == nil then
		return false
	end
	local speed = rate or 1
	if clips.playing == want then
		if math.abs((clips.rate or 1) - speed) > Rig.GAIT.RATE_EPSILON then
			track:AdjustSpeed(speed)
			clips.rate = speed
		end
		return false
	end
	for name in pairs(Rig.CLIPS) do
		local other = (clips :: any)[name] :: AnimationTrack?
		if name ~= want and other ~= nil and other.IsPlaying then
			other:Stop(Rig.GAIT.FADE_SECONDS)
		end
	end
	track:Play(Rig.GAIT.FADE_SECONDS)
	track:AdjustSpeed(speed)
	clips.playing = want
	clips.rate = speed
	return true
end

-- The tool pose on or off, ON TOP of whatever gait is playing -- so it is not routed through
-- `playClip`, which stops the others. Idempotent; returns whether it changed, so the owner counts
-- it rather than assuming it.
function Rig.holdTool(clips: Clips?, holding: boolean): boolean
	-- `holding == true` RATHER THAN `holding`, so a fresh rig asked to hold nothing is a no-op and
	-- is not counted as a pose (the owner counts this function's `true`s).
	if clips == nil or (clips.holding == true) == holding then
		return false
	end
	local track = clips.tool
	if track == nil then
		return false
	end
	if holding then
		track:Play(Rig.GAIT.FADE_SECONDS)
	else
		track:Stop(Rig.GAIT.FADE_SECONDS)
	end
	clips.holding = holding
	return true
end

-- Destroys one rig. Idempotent.
function Rig.destroy(model: Model?)
	if model ~= nil then
		model:Destroy()
	end
end

-- Destroys the whole container. Returns whether there was one, so the owner can count it.
function Rig.clearFolder(): boolean
	local existing = Workspace:FindFirstChild(Rig.FOLDER_NAME)
	if existing == nil then
		return false
	end
	existing:Destroy()
	return true
end

return Rig
