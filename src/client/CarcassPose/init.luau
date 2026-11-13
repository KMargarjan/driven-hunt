--!strict
-- CarcassPose: THE ONE WRITER of client-local `AnimationTrack`s on a DEAD animal's rig
-- (CLAUDE.md rule 3; design docs/design/carcass-pose.md section 2). It writes nothing else,
-- anywhere: no BasePart property, no attribute, no instance under Workspace, and it never touches a
-- track it did not itself load.
--
-- WHY IT EXISTS. Karen, 2026-11-10: "animal died and then stand and then again die". MEASURED
-- first (358-bind.luau, her Forest Test): a client whose rig is drawing NO pose shows the BIND pose,
-- which for every animal in this game is standing -- hind 1.05 -> 4.94 studs of drawn bone span --
-- and it NEVER recovers, 3 of 3 still standing after 12 s, because the server's re-assert is
-- one-shot at 6 s. The server cannot fix it: it already thinks it said the death once.
--
-- The mechanism was measured before it was designed (358-feas.luau): `Animator:LoadAnimation` from
-- the CLIENT on a server-owned Animator returns a track, it plays beside the replicated one, and it
-- changes what is drawn. Roblox's own default character `Animate` script is the same shape -- the
-- client owns the drawn pose of a replicated rig.
--   https://create.roblox.com/docs/reference/engine/classes/Animator
--   https://create.roblox.com/docs/reference/engine/enums/AnimationPriority
-- Note: docs/research/2026-11-13-carcass-pose.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarcassData = require(ReplicatedStorage:WaitForChild("Carcass"))
local AssetFetch = require(ReplicatedStorage:WaitForChild("AssetFetch"))

local CarcassPose = {}

-- A carcass that is standing has been standing for seconds; a quarter second is invisible beside
-- that, and it is 4 sweeps a second instead of 60 (design 9.1).
CarcassPose.SWEEP_SECONDS = 0.25
-- A release wave is ten animals; four a sweep clears ten in 0.75 s and never spikes a frame.
CarcassPose.MAX_POSES_PER_SWEEP = 4
-- `AssetFetch.RETRY_SECONDS` is 3, so this is about six attempts. A client that cannot download a
-- clip is not helped by asking for ever.
CarcassPose.POSE_TIMEOUT_SECONDS = 20
CarcassPose.CLIP_FOLDER_NAME = "Clips"
CarcassPose.FOLDER_NAME = "Boars"

export type PoseView = {
	carcass: boolean,
	poseId: number?,
	poseAt: number?,
	hasAnimator: boolean,
	deathPlaying: boolean,
	assetReady: boolean,
	trackLength: number?,
	posed: boolean,
}

-- THE WHOLE DECISION, PURE, and it answers a NAMED REASON so every branch can be driven with no rig,
-- no asset and no Play session (the idiom of `Body.shouldRehold` and `Claim.simulate`).
-- "skip" | "wait-rig" | "wait-asset" | "wait-length" | "leave" | "pose"
function CarcassPose.decide(view: PoseView): string
	if not view.carcass then
		return "skip" -- a living animal is the server's to draw, always
	end
	local id, at = view.poseId, view.poseAt
	if id == nil or id <= 0 or at == nil or at < 0 then
		return "skip" -- nothing was published; not knowing is not a licence to invent
	end
	if view.posed then
		return "skip" -- once per carcass per published pose. No storm, no per-frame write
	end
	if not view.hasAnimator then
		return "wait-rig" -- `Visual` is Atomic-streamed and can arrive after the trunk
	end
	if view.deathPlaying then
		-- Some death is already drawing this animal. Measured benign in 19/19 kills and 80/80 forced
		-- server repairs, and snapping a fall that is still running to its end would be a defect
		-- this owner would have caused.
		return "leave"
	end
	if not view.assetReady then
		return "wait-asset"
	end
	local length = view.trackLength
	if length == nil then
		return "pose" -- nothing loaded yet: load it, and the next sweep re-asks
	end
	if length <= 0 then
		-- THE FRAME-0 TRAP. `LoadAnimation` hands back a track for an asset that has not downloaded
		-- and its `Length` is 0; pinning `TimePosition` on it clamps to frame 0 of the fall, which
		-- is the animal STANDING -- the defect, caused by the fix. `Body.shouldRehold` carries the
		-- same sentence: a zero length means "not loaded yet", never "already over".
		return "wait-length"
	end
	return "pose"
end

type Record = {
	pose: string, -- the attribute value this record was built for
	id: number,
	at: number,
	posed: boolean,
	track: AnimationTrack?,
	firstSeen: number,
	timedOut: boolean,
}

type Stats = {
	sweeps: number,
	trunks: number,
	carcasses: number,
	candidates: number,
	posed: number,
	leftAlone: number,
	waitingRig: number,
	waitingAsset: number,
	waitingLength: number,
	timedOut: number,
	loads: number,
	plays: number,
	writes: number,
	bindBefore: number,
	repairs: number,
	worstSweepMs: number,
	lastSweepAt: number,
}

type State = {
	started: boolean,
	enabled: boolean,
	folder: Instance?,
	now: () -> number,
	sweepSeconds: number,
	ready: (string, Instance) -> boolean,
	load: ((Instance, number) -> any?)?,
	clips: Folder?,
	animations: { [number]: Animation },
	records: { [Instance]: Record },
	since: number,
	stats: Stats,
}

local function freshStats(): Stats
	return {
		sweeps = 0,
		trunks = 0,
		carcasses = 0,
		candidates = 0,
		posed = 0,
		leftAlone = 0,
		waitingRig = 0,
		waitingAsset = 0,
		waitingLength = 0,
		timedOut = 0,
		loads = 0,
		plays = 0,
		writes = 0,
		bindBefore = 0,
		repairs = 0,
		worstSweepMs = 0,
		lastSweepAt = 0,
	}
end

local state: State = {
	started = false,
	enabled = false,
	folder = nil,
	now = os.clock,
	sweepSeconds = CarcassPose.SWEEP_SECONDS,
	-- `AssetFetch.readyId` IS the ask as well as the answer: it requests when its own `nextAsk` rule
	-- says so. DEVIATION from design 6.2's two-function seam, which asked for `ready` and `ask`:
	-- `AssetFetch` has no separate `ask` for a bare id, and adding one would be a second asker.
	ready = AssetFetch.readyId,
	load = nil,
	clips = nil,
	animations = {},
	records = {},
	since = 0,
	stats = freshStats(),
}

-- The Animator is found BY CLASS, never by name: the controller's and the model's names are the
-- server's strings, and copying one here would be a second home for it. `Body.attachVisual` asserts
-- exactly one controller and one animator per rig, which is the fact this rests on.
local function animatorOf(trunk: Instance): Instance?
	return trunk:FindFirstChildWhichIsA("Animator", true)
end

local function animationFor(id: number): Animation
	local existing = state.animations[id]
	if existing ~= nil then
		return existing
	end
	local animation = Instance.new("Animation")
	animation.Name = "Death" .. tostring(id)
	animation.AnimationId = CarcassData.contentId(id)
	-- Its own folder, under PlayerScripts, never under Workspace.
	animation.Parent = state.clips
	state.animations[id] = animation
	return animation
end

-- Is a death already drawing this animal? Read-only: the server's tracks are the server's.
local function deathPlaying(animator: Instance, id: number): boolean
	local wanted = CarcassData.contentId(id)
	local ok, tracks = pcall(function()
		return (animator :: any):GetPlayingAnimationTracks()
	end)
	if not ok or type(tracks) ~= "table" then
		return false
	end
	for _, track in ipairs(tracks :: { AnimationTrack }) do
		local animation = track.Animation
		if animation ~= nil and animation.AnimationId == wanted and track.IsPlaying then
			return true
		end
	end
	return false
end

-- RECORDED, NOT GUESSED (design 9.2): was the rig at its bind pose when we posed it? A bone at bind
-- has an identity `Transform`. One read of up to 40 bones, once, on the frame it poses -- so "the
-- ON state fixed the ones that were broken" is a number and not a belief.
local BIND_SAMPLE = 40
local function atBind(trunk: Instance): boolean
	local seen, moved = 0, false
	for _, d in ipairs(trunk:GetDescendants()) do
		if d:IsA("Bone") then
			seen += 1
			if (d :: Bone).Transform.Position.Magnitude > 1e-3 then
				moved = true
				break
			end
			if seen >= BIND_SAMPLE then
				break
			end
		end
	end
	return seen > 0 and not moved
end

local function loadTrack(animator: Instance, id: number): AnimationTrack?
	local loader = state.load
	if loader ~= nil then
		return (loader(animator, id) :: any) :: AnimationTrack?
	end
	local ok, track = pcall(function()
		return (animator :: any):LoadAnimation(animationFor(id))
	end)
	if not ok then
		return nil
	end
	return track :: AnimationTrack?
end

-- The four writes of a pose, on an object this client made, once (design 4.2).
local function pin(record: Record, track: AnimationTrack)
	track.Priority = Enum.AnimationPriority.Action -- beats the server's Movement (Body.trackFor)
	track.Looped = false -- a looping death stands the carcass back up every 1.2 s (task 115)
	track:Play(0, 1, 0)
	track.TimePosition = math.clamp(record.at, 0, math.max(track.Length - CarcassData.HOLD_EPSILON, 0))
	track:AdjustSpeed(0)
	state.stats.plays += 1
	state.stats.writes += 4
	record.posed = true
end

local function stopTracks()
	for _, record in pairs(state.records) do
		local track = record.track
		if track ~= nil then
			pcall(function()
				track:Stop(0)
			end)
		end
	end
end

function CarcassPose.start(seams: any): boolean
	seams = seams or {}
	if seams.enabled ~= true then
		-- NOTHING IS TOUCHED when it is off: no folder lookup, no record, no instance, no sweep.
		state.enabled = false
		state.started = false
		return false
	end
	local folder = seams.folder
	if folder == nil then
		folder = game:GetService("Workspace"):FindFirstChild(seams.folderName or CarcassPose.FOLDER_NAME)
	end
	if folder == nil then
		-- Askable again, exactly as `Mask.start` is: a place with no animals never starts at all.
		return false
	end
	state.enabled = true
	state.started = true
	state.folder = folder
	state.now = seams.now or os.clock
	state.sweepSeconds = seams.sweepSeconds or CarcassPose.SWEEP_SECONDS
	state.ready = seams.ready or AssetFetch.readyId
	state.load = seams.load
	state.animations = {}
	state.records = {}
	state.since = 0
	state.stats = freshStats()
	if state.clips == nil then
		local parent = seams.clipParent
		if parent == nil then
			local player = Players.LocalPlayer
			parent = if player ~= nil then player:FindFirstChild("PlayerScripts") else nil
		end
		if parent ~= nil then
			local clips = Instance.new("Folder")
			clips.Name = CarcassPose.CLIP_FOLDER_NAME
			clips.Parent = parent
			state.clips = clips
		end
	end
	return true
end

-- SAY THE COUNTS OUT LOUD, WHERE A PROBE CAN READ THEM (the rule task 293c wrote for `Reholds`,
-- and V293b restated: a counter that lives only in module state is not a diagnostic). A live
-- `execute_luau` probe gets a FRESH module cache, so `stats()` through one is always zeroes.
--
-- ON ITS OWN FOLDER, which is the whole of the boundary here: this owner may write no attribute on
-- anything it did not create, and `Clips` is the one instance it creates. Read-compare-write, so a
-- sweep that changed nothing writes nothing.
local PUBLISHED = {
	"sweeps",
	"carcasses",
	"posed",
	"leftAlone",
	"bindBefore",
	"waitingRig",
	"waitingAsset",
	"waitingLength",
	"timedOut",
	"loads",
	"plays",
	"writes",
}
local function publish(stats: Stats)
	local clips = state.clips
	if clips == nil then
		return
	end
	for _, key in ipairs(PUBLISHED) do
		local value = (stats :: any)[key]
		if clips:GetAttribute(key) ~= value then
			clips:SetAttribute(key, value)
		end
	end
end

local function sweep()
	local folder = state.folder
	if folder == nil then
		return
	end
	local stats = state.stats
	stats.sweeps += 1
	local now = state.now()
	stats.lastSweepAt = now
	local posedThisSweep = 0
	local seen: { [Instance]: boolean } = {}
	for _, trunk in ipairs(folder:GetChildren()) do
		if trunk:IsA("BasePart") then
			stats.trunks += 1
			seen[trunk] = true
			if trunk:GetAttribute("Carcass") == true then
				stats.carcasses += 1
				local value = trunk:GetAttribute(CarcassData.ATTRIBUTE)
				local id, at = CarcassData.parse(value)
				local record = state.records[trunk]
				if id ~= nil and at ~= nil and (record == nil or record.pose ~= value) then
					-- A NEW PUBLISHED POSE is a new record: the paddle superseding the fall is the
					-- one time it happens, and the carcass is posed again at the new frame.
					record = {
						pose = tostring(value),
						id = id,
						at = at,
						posed = false,
						track = nil,
						firstSeen = now,
						timedOut = false,
					}
					state.records[trunk] = record
				end
				-- A POSE THIS OWNER PUT ON AND SOMETHING ELSE TOOK OFF IS PUT BACK, and the test is
				-- the state the defect produces rather than a count: OUR OWN track has stopped.
				-- That cannot happen by itself -- a track pinned at speed 0 stays playing -- so a
				-- repair follows an external stop and nothing else, and the repair's own result is
				-- the state that refuses the next one. It is `Body.shouldRehold`'s rule, on this
				-- side of the wire, and unbounded for task 293b's reason: a carcass that loses its
				-- hold on the 4th stop, or the 400th, is Karen's bug either way.
				if record ~= nil and record.posed and record.track ~= nil and not record.track.IsPlaying then
					record.posed = false
					stats.repairs += 1
				end
				if
					record ~= nil
					and not record.timedOut
					and not record.posed
					and posedThisSweep < CarcassPose.MAX_POSES_PER_SWEEP
				then
					local animator = animatorOf(trunk)
					local track = record.track
					local view: PoseView = {
						carcass = true,
						poseId = record.id,
						poseAt = record.at,
						hasAnimator = animator ~= nil,
						deathPlaying = animator ~= nil and track == nil and deathPlaying(animator, record.id),
						assetReady = animator ~= nil and state.ready(CarcassData.contentId(record.id), trunk),
						trackLength = if track ~= nil then track.Length else nil,
						posed = record.posed,
					}
					local answer = CarcassPose.decide(view)
					if answer ~= "skip" then
						stats.candidates += 1
					end
					if answer == "leave" then
						stats.leftAlone += 1
						record.posed = true -- it is already drawn; stop asking about it
					elseif answer == "wait-rig" then
						stats.waitingRig += 1
					elseif answer == "wait-asset" then
						stats.waitingAsset += 1
					elseif answer == "wait-length" then
						stats.waitingLength += 1
					elseif answer == "pose" and animator ~= nil then
						if track == nil then
							if atBind(trunk) then
								stats.bindBefore += 1
							end
							track = loadTrack(animator, record.id)
							record.track = track
							if track ~= nil then
								stats.loads += 1
							end
						end
						if track ~= nil and track.Length > 0 then
							pin(record, track)
							stats.posed += 1
							posedThisSweep += 1
						end
					end
					if
						not record.posed
						and answer ~= "skip"
						and now - record.firstSeen >= CarcassPose.POSE_TIMEOUT_SECONDS
					then
						record.timedOut = true
						stats.timedOut += 1
					end
				end
			end
		end
	end
	-- A TRUNK THAT LEFT THE FOLDER IS FORGOTTEN, never written to: a cleared carcass is destroyed,
	-- and a write to a destroyed instance is an error, not a restore (`Range.Mask.step`'s own rule).
	for trunk in pairs(state.records) do
		if not seen[trunk] then
			state.records[trunk] = nil
		end
	end
	local spent = (state.now() - now) * 1000
	if spent > stats.worstSweepMs then
		stats.worstSweepMs = spent
	end
	publish(stats)
end

function CarcassPose.step(dt: number)
	if not state.started then
		return
	end
	state.since += dt
	if state.since < state.sweepSeconds then
		return
	end
	state.since = 0
	sweep()
end

-- `Stop` DOES NOT UNDO A POSE, and this does not pretend it does: stopping a client track leaves
-- the bones at their last Transform and the pose stays (MEASURED, 358-clipop.luau). The only thing
-- to "restore" to is the bind pose, which is the standing animal this owner exists to remove.
function CarcassPose.stop()
	stopTracks()
	state.started = false
	state.enabled = false
	state.folder = nil
	state.records = {}
	state.animations = {}
	local clips = state.clips
	if clips ~= nil then
		clips:Destroy()
		state.clips = nil
	end
	state.since = 0
	state.stats = freshStats()
end

function CarcassPose.stats()
	return table.clone(state.stats)
end

function CarcassPose.isStarted(): boolean
	return state.started
end

return CarcassPose
