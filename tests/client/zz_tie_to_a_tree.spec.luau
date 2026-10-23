-- zz_tie_to_a_tree.spec: the safety rule, end to end, with a real shot from a real player.
--
-- THE `zz_` PREFIX IS DELIBERATE AND IT IS LOAD-BEARING. TestEZ runs the spec modules in the order
-- the specs folder lists them, and this is the one spec whose success TAKES THE GUN AWAY: a tied
-- shooter may not carry one (docs/design/drive.md section 8.4 item 5). tests/client/weapon_client.spec
-- already records that "a spec that revoked this gun mid-session broke exactly this window, and was
-- withdrawn" (Task 34). So this must run after every spec that needs an armed player, and its
-- scenario must be the LAST one in tests/client/input_scenarios.txt. Rename it and the run goes red
-- in weapon_client, not here.
--
-- WHAT IT ASSERTS DEPENDS ON WHO IS IN THE SESSION, which is what makes it run in both harness modes
-- (`test` and `test2`), and neither branch is a skip -- each one asserts a real rule:
--   * TWO PLAYERS (test2): this client is the SHOOTER, the other is the DRIVER standing on the driver
--     pad. This spec walks up behind him, keeps the camera BESIDE him, the harness replays a click,
--     and the server ties this player to a tree. Click -> ContextActionService -> client weapon ->
--     FireRequest -> validator -> cast -> Weapon.SafetyArc's 45-degree filter -> Match.Penalty.judge
--     -> Match.Body.tie -> the snapshot's `tied` list -> this client's Hud banner. Nothing is stubbed.
--
-- SINCE TASK 171 THIS SPEC STAGES ITS SHOOTER ON HIS OWN STAND, FROM THE DRIVE'S OWN ANSWER, AND
-- BRINGS THE DRIVER TO HIM -- which is the opposite of what it used to do. It used to walk the
-- shooter to the driver: in the DEV arena the posts are at z = -150 and the driver pad at z = +170,
-- so that walk was 525 studs, and from there the OFF-STAND rule refused every shot he took
-- (measured in the Director's two-player run at `8b2bb40`: `probe aimed AT the driver ->
-- refused=off-stand`, and seven more `off-stand` refusals from the earlier scenarios' shots). The
-- stand circle now arrives on the match snapshot (`snapshot.stands`, keyed by userId) from the same
-- `Match.standAreaOf` the fire gate reads, so this spec stages against the server's own geometry
-- instead of a guess -- and the DRIVER's client walks itself in front of that stand, because a
-- client may only move its own character and a shot has to be able to reach him (`Buck` carries 100
-- studs).
--
-- AND BOTH CHARACTERS ARE PARKED WHILE THE WINDOW IS OPEN, AND THE GEOMETRY IS RECORDED AT THE SHOT.
-- The Director's third two-player run (`cd30764`) is why, and what it does NOT say is as important as
-- what it does:
--   * the DRIVER's pivot provably took -- he read `-560, 5.15, -675`, which is the stand centre
--     (`-700`) plus exactly `STAND_BEHIND`;
--   * the SHOOTER read `-560, 3.5, -741`, **41 studs** off the centre -- but that reading was taken
--     ~25 seconds after the probe, at the end of the case, and the replay holds movement keys the
--     whole time. So WHEN he left his stand is simply not in the data, and a spec that reads a
--     position back later cannot tell "the pivot failed" from "he walked off afterwards";
--   * and the probe's own answer was `refused=nil` with the barrels UNCHANGED and `busy=0.60` --
--     the scenario presses R 1.2 s after the cue, and a `busy` rejection is the REDUCER's: it
--     commits no state and carries no `refused` field, so it reads exactly like "no rule spoke".
-- Both are fixed at the source rather than guessed at: the characters are HELD (see `park`), every
-- pre-condition the rule needs is MEASURED before each attempt, the numbers are recorded AT the shot
-- the gate judged, and the probe RETRIES -- because a mechanical rejection costs nothing, so trying
-- again inside the window is free and is the only way to be sure the shot did not land in a gun
-- whose hands were full.
--
-- AND THE TWO SHOTS ARE ORDERED, which is what the Director's fourth two-player run (`bac93d6`)
-- measured the need for. In it the staging and the rule both worked -- `me 0.5 from the centre;
-- driver 25.0 away; ray hit Workspace.Player2.UpperTorso`, `refused=beater-in-line after 2
-- attempt(s)`, the gun unchanged -- and the only failure was this spec asserting `Match.isTied()`
-- afterwards: by then the REPLAYED CLICK had legitimately tied him. The probe's pre-conditions push
-- it into the gap after the scenario's own reload (R lands at 1.2 s, the reload runs 2.0 s, the
-- first click lands at 3.8 s), so "after the probe" and "after the tie shot" were the same moment.
-- Two fixes, both of them about WHEN rather than what:
--   * the refusal case asserts the tie state RECORDED AROUND ITS OWN SHOT -- untied before it,
--     untied after it, no new violation -- which is the claim "a refused shot ties nobody" exactly.
--     Reading `Match.isTied()` later asks a different question, and the answer to that one is
--     rightly yes;
--   * and the aim stays ON the driver until the probe has answered, so a click that lands early is
--     REFUSED rather than tying him. The scenario fires twice (3.8 s and 5.0 s), so the tie shot is
--     whichever click comes after the probe is done -- the tie can no longer precede it.
--
-- AND THERE ARE TWO RULES ABOUT A SHOT NEAR A BEATER, SO IT STAGES BOTH -- which is the other half
-- of what this file carries and the reason the aim is `BESIDE_STUDS` off his body (10 since task
-- 248, and see that constant for why it moved):
--   1. THE RAY WOULD HIT HIM -> THE SHOT IS REFUSED. `Weapon.Rules.beaterInLine`, Karen 2026-10-11:
--      *"thye just can't shoot them"*. Nothing fires, nothing is spent, NOBODY IS TIED -- there is no
--      shot to judge. Staged by the probe in `onCue` below, aimed dead at him.
--   2. THE RAY MISSES HIM BY MORE THAN `SAFETY_LOCK_STUDS` AND PASSES WITHIN `SAFETY_MISS_STUDS`
--      -> THE SHOT FIRES AND TIES HIM.
--      That is what the arc is FOR: shooting dangerously close to the line of men
--      (`Match.Penalty.judge`). Staged by the real replayed click, aimed `BESIDE_STUDS` to his side.
-- THE TWO CANNOT BOTH HAPPEN TO ONE SHOT, and that is the whole of "no double handling": a refused
-- shot returns before `Weapon.SafetyViolated` is published, so the penalty is only ever reached by a
-- shot that was fired. The three rules are asked in `Weapon.Rules.ORDER` -- off-stand, then the
-- beater in the ray, then the licence -- so a shooter who is BOTH off his stand and aiming at a man
-- is told to get back on his stand, and this spec has to put him there before it can prove anything
-- about his aim. UNTIL TASK 171 IT STAGED CASE 1 AND EXPECTED CASE 2's OUTCOME: it
-- aimed dead at the driver (`miss 0.0 of 12`, measured in the Director's `test2` at `5e0ee90`) and
-- the new rule correctly refused the shot, so nothing was tied and this spec failed at the tie.
-- **The tie proof is not weakened and was not deleted** -- it is staged on the shot the arc exists
-- to punish, and the refusal it used to stage by accident is now asserted on purpose.
--   * ONE PLAYER (test): there is no driver, so this fires the same shot straight INTO the drive and
--     asserts that nothing happens. That is not a weaker test -- it is the case the design rejected
--     an earlier rule for: a shooter on a post faces the drive, so if "inside the 45-degree cone"
--     were the verdict, this shot would tie everybody in the first minute (design section 8.1).
--   * A DRIVER's client (test2, checked like any other since Task 36): carries no gun, and asserts
--     that. The replay reaches him too, so the cue key arrives -- and `onCue` deliberately does
--     nothing on a client that is not the shooter, so this spec never touches a driver's camera
--     while camera_client.spec is asserting about it.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/drive.md (sections 8.1, 8.2, 8.3, 8.4, 9.3)
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InputReady = require(ReplicatedStorage:WaitForChild("ClientTests"):WaitForChild("InputReady"))
-- THE WIRE ITSELF (task 171), for the refusal probe: one `FireRequest` with a legal payload, aimed
-- at the driver. `src/client/Weapon/Input.luau` is still the only firer of it in CLIENT CODE -- this
-- is a spec driving the player's own path at the wire, exactly as `weapon_client.spec` already fires
-- payloads through `Shotgun.remotes().FireRequest` -- and it is the only way to stage two different
-- shots inside one replayed scenario, which carries one click.
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local Role = require(ReplicatedStorage:WaitForChild("ClientTests"):WaitForChild("Role"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
-- One fact, for one question: is the Tool in this player's hands a GUN? (task 152)
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Camera = require(scripts:WaitForChild("Camera"))
local Hud = require(scripts:WaitForChild("Hud"))
local Match = require(scripts:WaitForChild("Match"))
local Weapon = require(scripts:WaitForChild("Weapon"))

local CUE_ACTION = "DrivenHunt.Test.TieCue"
-- The last of five scenarios, and since Task 36 `test2` sends every step to BOTH clients, so the
-- replay takes about twice as long there as the ~60 s it takes with one.
local CUE_TIMEOUT = 240
local TIE_TIMEOUT = 25 -- from the cue to the snapshot saying so
-- HOW FAR IN FRONT OF THE SHOOTER'S STAND THE DRIVER IS PUT (task 171; before it, how far behind
-- the driver the shooter walked). It has to be inside the ammo's range -- `Buck` carries 100 studs
-- and the gun may be holding either kind -- and far enough that the shot does not start inside him.
local STAND_BEHIND = 25
local DOWN_THE_DRIVE = 200 -- studs up +Z, for the one-player shot at nobody
-- HOW FAR BESIDE HIM THE TIE SHOT IS AIMED (task 171). It has to clear his BODY -- an R15 character
-- is about two studs across -- and it has to stay inside `Match.CONFIG.SAFETY_MISS_STUDS` (12),
-- which is what makes the shot a violation. At `STAND_BEHIND` = 25 studs ten studs off is 21.8
-- degrees off the drive, still inside the 45-degree half-arc
-- (`Shotgun.CONFIG.SAFETY_ARC_HALF_DEG`), so the arc still publishes it.
--
-- IT WAS 5 UNTIL TASK 248 AND THE SAFETY LOCK IS WHY IT MOVED. The lock refuses any shot whose line
-- passes within `Match.CONFIG.SAFETY_LOCK_STUDS` (6) of ANY person, so at 5 studs this shot no
-- longer fires at all and the tie this file is named for could never be reached: the case would have
-- gone green on a REFUSAL and proved the wrong rule. 10 sits in the band between the two radii --
-- outside the lock, inside the tie -- which is the band `Match.CONFIG.SAFETY_LOCK_STUDS`'s own note
-- exists to defend. The lock's half is proved by the probe below, aimed straight at him.
local BESIDE_STUDS = 10
-- Seconds to wait for the server's answer to one probe shot. It is one round trip; the gun publishes
-- on the refusal with `force`, so this is slack and not a guess.
local PROBE_TIMEOUT = 3
-- How long the probe keeps TRYING, and it is a window rather than a moment because the staging can
-- take several attempts to satisfy: a rejected attempt commits no state and costs nothing, so the
-- honest shape is "try while the staging holds until the server answers with a RULE".
-- WHAT THE SCENARIO GIVES IT (`input_scenarios.txt`, "tie-the-driver", reordered in task 210): the
-- reload comes BEFORE the cue and is over by it, so the cue finds a loaded, idle gun, and the first
-- replayed click is 4.0 s after the cue. That 4.0 s is the runway in which a probe shot and the
-- server's answer can both land with nothing else writing the gun -- which is what the comparison
-- below needs and what it did not have when R landed 1.2 s after the cue.
local PROBE_WINDOW = 10
-- Between attempts. Six requests a second is `Shotgun.CONFIG.FIRE_RATE_LIMIT`, so four a second
-- cannot be rate-limited into looking like a refusal.
local PROBE_EVERY = 0.25
-- How far the driver may be when the probe goes. `Buck` carries 100 studs and the aim ray is cast to
-- the ammo's range, so a beater beyond it is not in the ray at all and the rule correctly says
-- nothing -- which is why the driver is brought to the stand and not aimed at across the arena.
local PROBE_REACH = 40
-- HOW LONG THE GUN MUST HAVE BEEN LEFT ALONE BEFORE A PROBE SHOT GOES (task 210). `busyFor` is the
-- SERVER's answer, published; a replayed key that landed a moment ago is already on the wire and its
-- reload has not reached this client's snapshot yet, so "not busy" is not yet "nobody is reloading
-- it". `RELOAD_TOTAL` is 2.0 s and one round trip is milliseconds, so half a second is slack.
local PROBE_QUIET = 0.5

local cuedAt: number? = nil
local stagedFrom: Vector3? = nil
local stagedDistance: number? = nil
local violations = {}
-- WHAT THE GUN LOOKED LIKE WHEN THE SHOT WAS STAGED (task 152). When this spec fails it says
-- `violations=0`, and that one number cannot tell "the shot was never fired" from "the shot was
-- fired and the Match did not judge it" -- which are different defects in different systems. The
-- barrels and the reserve change on a shot and on nothing else, so the pair splits it.
local stagedGun: string? = nil
local stagedTheirs: Vector3? = nil
-- WHAT THE PROBE SHOT MEASURED (task 171): the reason the server gave for refusing it, and the gun
-- before and after -- which is what "no shell spent" means on this side of the wire.
local probeReason: string? = nil
local probeBefore: string? = nil
local probeAfter: string? = nil
local probeFired = false
-- WHAT WAS TRUE WHEN THE PROBE WENT, recorded at that instant rather than read back afterwards: the
-- replay keeps playing and the gate judged the shot against THESE numbers. `blocked` is the last
-- thing that stopped an attempt, so a probe that never fired says why in one word.
local probeShots = 0
-- HOW MANY TIMES THE SERVER ITSELF ANSWERED `off-stand`, AND FOR HOW LONG (task 174, the Director's
-- `test2` at `454d58a`). See the retry in the probe loop: these two are the measurement of the lag
-- between this client parking itself and the SERVER seeing it there.
local probeOffStand = 0
local probeAgreedAfter: number? = nil
local probeBlocked: string? = nil
local probeFromCentre: number? = nil
local probeToDriver: number? = nil
local probeRayHit: string? = nil
-- HOW MANY ATTEMPTS WERE THROWN AWAY BECAUSE THE REPLAY TOUCHED THE GUN INSIDE THE WINDOW (task
-- 210). See `QUIET_ACTION` below and the discard in the probe loop.
local probeDiscarded = 0

-- WHEN THE REPLAY LAST TOUCHED THIS GUN (task 210, borrowing `weapon_client.spec`'s own
-- `QUIET_ACTION` -- the same keys for the same reason). The probe's claim is "a refused shot spends
-- nothing", and it is measured as a gun print taken before the shot against one taken when the
-- server answers. THE REPLAY WRITES THE SAME GUN INSIDE THAT WINDOW: this scenario's `R` is a real
-- reload, and a reload of a Live/Live gun puts both unfired shells back into the pocket, empties the
-- barrels and sets `busyUntil` (`Weapon.StateMachine`'s `Break` branch, `RELOAD_BREAK` = 0.5 s) --
-- which is EXACTLY the pair the Director measured on 2026-10-18 at `e1c6966` and `449e012`:
-- `eq=true b=Live/Live ammo=Buck res=10 busy=0.00` before, `eq=true b=Empty/Empty ammo=Buck res=12
-- busy=0.50` after. +2 in the pocket, both barrels emptied, half a second of Break. Nothing to do
-- with the refused shot: the replay's own reload, landing between the request and the answer.
--
-- Nothing in the STATE can tell those apart, so an attempt whose window was not quiet is THROWN AWAY
-- AND RETRIED rather than asserted through -- a refused attempt commits nothing and costs no shell,
-- which is what makes a retry free here (the same reasoning as the `off-stand` retry below).
-- `Pass`, like every probe in this file, so nothing a player does is swallowed.
local QUIET_ACTION = "DrivenHunt.Test.TieQuiet"
local lastWeaponInput = 0
ContextActionService:BindAction(QUIET_ACTION, function()
	lastWeaponInput = os.clock()
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.R, Enum.KeyCode.X, Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2)
-- WAS HE TIED, AND HOW MANY VIOLATIONS HAD BEEN ANNOUNCED, ON EITHER SIDE OF THE PROBE'S OWN SHOT.
-- The pair IS the claim: a refused shot ties nobody. Read later, the question becomes "is he tied
-- NOW", and after the replayed click the honest answer to that is yes.
local probeTiedBefore: boolean? = nil
local probeTiedAfter: boolean? = nil
local probeViolationsBefore: number? = nil
local probeViolationsAfter: number? = nil
-- DID THE GUN CLICK? (the Reviewer's round-1 note on the dry click.) `CameraBoot` plays one dry
-- click when a snapshot arrives carrying `refused`, and this is the one place in the suite where a
-- real refusal reaches a real client -- so the counter is read on either side of the probe's own
-- shot. `Weapon.Sound.stats()` is the seam that exists for exactly this: no speaker required.
local probeDryBefore: number? = nil
local probeDryAfter: number? = nil
-- One line per attempt, for the note: what stopped it, or what the server answered.
local probeLog: { string } = {}
-- TRUE once the probe has answered or its window has closed. Until then the aim stays ON the driver,
-- so a replayed click cannot tie him before the refusal has been measured.
local probeDone = false
-- WHERE THIS CHARACTER IS HELD WHILE THE WINDOW IS OPEN (task 171). nil until the cue stages it.
local parkAt: Vector3? = nil
-- EVERY REFUSAL THIS CLIENT WAS TOLD ABOUT, recorded as it arrives. `refused` belongs to ONE
-- published snapshot, and the arming sweep publishes again every two seconds with the field empty --
-- so reading `Weapon.get().refused` later is a race, and this is not.
local refusals: { string } = {}
Weapon.Changed:Connect(function(snapshot)
	if snapshot ~= nil and type(snapshot.refused) == "string" then
		table.insert(refusals, snapshot.refused)
	end
end)

local function gunPrint(): string
	local snap = Weapon.get()
	if snap == nil then
		return "<no state>"
	end
	local barrels = {}
	for _, barrel in ipairs(snap.barrels) do
		table.insert(barrels, tostring(barrel))
	end
	return string.format(
		"eq=%s b=%s ammo=%s res=%s busy=%.2f",
		tostring(snap.equipped),
		table.concat(barrels, "/"),
		tostring(snap.ammo),
		tostring(snap.reserve[snap.ammo]),
		snap.busyFor
	)
end

-- The feed is the "visible to everyone" half of Karen's rule, and it fades after FEED_SECONDS, so it
-- is recorded as it arrives rather than read later.
Match.Feed:Connect(function(entry)
	if entry.kind == "violation" then
		table.insert(violations, entry)
	end
end)

-- FORWARD: the probe inside `onCue` waits for the driver to arrive, and `onCue` is defined above
-- the helper. `local` here and a plain assignment below means the definition lands on THIS local
-- rather than creating a global (the idiom `Weapon.runCycle` already uses).
local waitUntil

local function rootOf(subject: Player): BasePart?
	local character = subject.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- HOLDS THIS CHARACTER AT ONE POINT, every frame, for as long as the cue window is open. The
-- `root.CFrame` + zeroed `AssemblyLinearVelocity` pair is `ForestTest.boundary`'s own idiom (task
-- 166) and for the same reason: a position written once is undone by the next step of a held key,
-- and the replay holds keys. The ROTATION is untouched -- the camera owner aims, not this.
--
-- MEASURED NEED: in the Director's run at `cd30764` the shooter read 41 studs off the stand centre
-- by the end of the case -- after a pivot that had put him on it -- because the replay was still
-- holding his movement keys.
local function park(root: BasePart, at: Vector3)
	root.CFrame = CFrame.new(at) * (root.CFrame - root.CFrame.Position)
	root.AssemblyLinearVelocity = Vector3.zero
end

-- THIS PLAYER'S OWN STAND CIRCLE, AS THE DRIVE PUBLISHED IT (task 171). `snapshot.stands` is keyed
-- by `tostring(userId)` and is the server's own `Match.standAreaOf` -- the same answer the off-stand
-- fire gate reads, so staging against it cannot disagree with the rule being tested. nil means the
-- drive gave this player no circle (a beater, or nowhere to put him), and then there is no rule.
local function standOf(subject: Player)
	local snapshot = Match.get()
	local stands = if snapshot ~= nil then (snapshot :: any).stands else nil
	local area = if stands ~= nil then stands[tostring(subject.UserId)] else nil
	if type(area) ~= "table" or typeof(area.centre) ~= "Vector3" then
		return nil
	end
	return area
end

-- The SHOOTER of this session, which the driver's client needs: it stages itself in front of HIS
-- stand, and `standOf` works for any player because the snapshot carries the whole roster's circles.
local function theShooter(): Player?
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Team and other.Team.Name == "Shooters" then
			return other
		end
	end
	return nil
end

-- The other player, if this session has one and the drive made them a driver.
local function driver(): Player?
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other.Team and other.Team.Name == "Drivers" then
			return other
		end
	end
	return nil
end

-- A GUN, NOT JUST A TOOL (task 152). The beater's horn is a `Tool` too, and this asks whether a
-- tied DRIVER is armed -- which is exactly the player who now carries one.
local function holdsGun(): boolean
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		for _, child in ipairs(if container then container:GetChildren() else {}) do
			if Weapons.isWeaponTool(child) then
				return true
			end
		end
	end
	return false
end

-- THE CUE. The harness cannot tell a spec "your scenario starts now" except through the input it
-- replays, and this spec must be moving and aiming BEFORE the click arrives -- so the scenario opens
-- with one key, exactly as weapon_client.spec's Q does. It also means this spec touches the camera
-- only inside its own scenario, so it never fights shoot_boar.spec for it.
--
-- (The scenario's `moveTo` right after the cue is not aiming -- under MouseBehavior = LockCenter
-- StudioMCP's moveTo delivers no usable delta, docs/design/camera.md 9.3. It is there because
-- StudioMCP refuses a click with no established mouse position: "Either x and y, instance_path, or a
-- prior action that establishes mouse position is required", measured 2026-09-25.)
local function onCue(_name: string, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin or cuedAt then
		return Enum.ContextActionResult.Pass
	end
	-- THE DRIVER HAS A STAGING JOB OF HIS OWN SINCE TASK 171, and it is the only thing he does here.
	-- The shot has to be able to REACH him -- in the DEV arena his pad is 320 studs from the posts
	-- and `Buck` carries 100 -- and the shooter may no longer walk to him, because off his own stand
	-- he cannot fire at all. So the driver walks to the shooter: a client may move its own character
	-- and nothing else, which is the same rule the shooter's own pivot has always followed (and the
	-- harness's own `stage` step, tools/studio_mcp.py).
	--
	-- IT STILL DOES NOT TOUCH A DRIVER'S CAMERA. That was the reason `onCue` ignored him outright,
	-- and the reason stands: `camera_client.spec` is asserting about that camera at this moment. A
	-- character pivot is `Match.Body`'s own idiom and writes no camera.
	if Role.isDriver() then
		local me = rootOf(player)
		local target = theShooter()
		local stand = if target then standOf(target) else nil
		local character = player.Character
		if me and stand and character then
			-- IN FRONT OF HIS STAND, up +Z -- the direction the arena's DriveLine marker points and
			-- the direction the drive comes from, so the shot that follows runs up the drive exactly
			-- as it always did. At the stand's own height: the shooter stands on a post a few studs
			-- up, and a driver dropped at that height simply falls to the ground.
			local at = (stand.centre :: Vector3) + Vector3.new(0, 0, STAND_BEHIND)
			character:PivotTo(CFrame.lookAt(at, stand.centre))
			-- AND HELD THERE. At the stand's own height, so the shot runs level and the distance to
			-- him is exactly `STAND_BEHIND` -- a driver left to fall would be five studs lower and
			-- the geometry would depend on where the ground happens to be.
			parkAt = at
		end
		cuedAt = os.clock()
		return Enum.ContextActionResult.Pass
	end
	cuedAt = os.clock()
	local me = rootOf(player)
	local target = driver()
	local theirs = if target then rootOf(target) else nil
	local character = player.Character
	local stand = standOf(player)
	if me and theirs and character and stand then
		-- ON HIS OWN STAND, FROM THE DRIVE'S OWN ANSWER (task 171). The replay has been walking him
		-- around for five scenarios, so by now he is somewhere else entirely -- and off his stand he
		-- may not fire (`Weapon.Rules.outsideStand`), which is what refused every shot in the
		-- Director's run at `8b2bb40`. The centre of the circle is where the drive put him, so this
		-- is a walk back to his post and not a new place to stand.
		local at = stand.centre :: Vector3
		character:PivotTo(CFrame.lookAt(at, at + Vector3.new(0, 0, 1)))
		parkAt = at
		stagedFrom = at
		stagedDistance = STAND_BEHIND
		stagedTheirs = theirs.Position
		stagedGun = gunPrint()
		-- RULE 1, STAGED ON PURPOSE (task 171): one shot aimed DEAD AT HIM, which the server must
		-- refuse. It goes first, before the replayed click, because a tie takes the gun away and a
		-- refusal has to be measured while there is still a gun to refuse with.
		--
		-- IN A SPAWNED THREAD, because this is a `ContextActionService` callback and must not yield;
		-- the input it is bound to is the cue, and the harness's own click is seconds behind it (the
		-- fire limiter is `FIRE_RATE_LIMIT` = 6 a second, so the two cannot collide).
		task.spawn(function()
			-- EVERY PRE-CONDITION THE RULE NEEDS, MEASURED, and the one that fails is the word the
			-- note carries. A probe fired without these proves nothing: the Director's three
			-- two-player runs failed on exactly this, once per missing condition (off his stand, out
			-- of the ray, into a busy gun).
			local function staging(): (boolean, string, number, number, string)
				local mine = rootOf(player)
				local root = rootOf(target :: Player)
				local gun = Weapon.get()
				if mine == nil or root == nil then
					return false, "no-character", -1, -1, "?"
				end
				local fromCentre = (mine.Position - at).Magnitude
				local toDriver = (root.Position - mine.Position).Magnitude
				-- HE MUST BE IN HIS OWN CIRCLE, by the drive's own published radius, or the FIRST
				-- rule in `Weapon.Rules.ORDER` answers instead of the one being tested.
				if fromCentre > (stand :: any).radius then
					return false, "off-stand", fromCentre, toDriver, "?"
				end
				if toDriver > PROBE_REACH then
					return false, "driver-far", fromCentre, toDriver, "?"
				end
				-- THE GUN MUST BE ABLE TO FIRE AT ALL. A `busy` or `barrel-empty` rejection is the
				-- reducer's and carries no `refused` field, so it reads exactly like "the rule said
				-- nothing" -- which is what `cd30764` measured (`busy=0.60`, the scenario's own R).
				if gun == nil or not gun.equipped or gun.busyFor > 0 or gun.barrels[gun.selected] ~= "Live" then
					return false, "gun-not-ready", fromCentre, toDriver, "?"
				end
				-- ...AND NOBODY MAY HAVE JUST TOUCHED IT (task 210). `busyFor` above is the server's
				-- published answer, so a replayed key already on the wire reads as an idle gun right
				-- up to the moment its reload comes back.
				if os.clock() - lastWeaponInput < PROBE_QUIET then
					return false, "input-in-flight", fromCentre, toDriver, "?"
				end
				-- AND THE AIM RAY MUST REALLY REACH HIS BODY. The server refuses on what the ray
				-- HITS, so this client casts the same ray first and names what is in the way --
				-- which in `cd30764` would have said "the post he had walked behind".
				local camera = workspace.CurrentCamera
				local eye = if camera then camera.CFrame.Position else mine.Position
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { player.Character :: Instance }
				params.IgnoreWater = true
				local result = workspace:Raycast(eye, root.Position - eye, params)
				local hit = if result then result.Instance else nil
				local onHim = hit ~= nil
					and (target :: Player).Character ~= nil
					and hit:IsDescendantOf((target :: Player).Character :: Instance)
				local name = if hit then hit:GetFullName() else "<nothing>"
				if not onHim then
					return false, "ray-blocked", fromCentre, toDriver, name
				end
				return true, "", fromCentre, toDriver, name
			end

			-- IT RETRIES WHILE THE STAGING HOLDS. A rejected attempt commits no state and costs no
			-- shell, so trying again is free -- and it is the only way to be sure the shot lands in a
			-- gun that is not mid-reload. Since task 210 the scenario's reload is over BEFORE the cue
			-- and the first replayed click is 4.0 s after it, so the whole runway is quiet; the
			-- discard below is what makes that a measurement rather than an assumption.
			-- WHERE THIS CASE STARTS FROM, recorded before the first attempt: it must start UNTIED.
			-- A session that arrives here already tied is a real finding and not something to work
			-- around -- the gun would be gone, the probe could not fire at all, and the case says so
			-- (TASKS.md 166a(b) records the same race for `weapon_client` and `rifle_client`).
			probeTiedBefore = Match.isTied()
			probeViolationsBefore = #violations
			probeDryBefore = Weapon.Sound.stats().dry
			local deadline = os.clock() + PROBE_WINDOW
			while os.clock() < deadline and probeReason == nil do
				local ok, why, fromCentre, toDriver, hitName = staging()
				if not ok then
					probeBlocked =
						string.format("%s (centre %.1f, driver %.1f, ray %s)", why, fromCentre, toDriver, hitName)
					if #probeLog < 8 then
						table.insert(
							probeLog,
							string.format("blocked=%s tied=%s", probeBlocked :: string, tostring(Match.isTied()))
						)
					end
					task.wait(PROBE_EVERY)
					continue
				end
				local mine = rootOf(player)
				local root = rootOf(target :: Player)
				local camera = workspace.CurrentCamera
				local eye = if camera then camera.CFrame.Position else (mine :: BasePart).Position
				local toward = (root :: BasePart).Position - eye
				if toward.Magnitude < 1e-3 then
					break
				end
				-- THE STATE THIS SHOT IS ABOUT, READ FRESH FOR EVERY ATTEMPT (task 210). It used to
				-- be read once and kept, so after an `off-stand` retry the comparison below
				-- bracketed every attempt since the first -- seconds of replayed input, not one
				-- shot's round trip.
				probeBefore = gunPrint()
				local inputMark = lastWeaponInput
				probeBlocked = nil
				probeFromCentre, probeToDriver, probeRayHit = fromCentre, toDriver, hitName
				stagedTheirs = (root :: BasePart).Position
				local before = #refusals
				-- The payload the client's own `Input.onFire` sends, and nothing else: an origin and
				-- a unit direction (design section 5.7).
				Shotgun.remotes().FireRequest:FireServer({ origin = eye, direction = toward.Unit })
				probeFired = true
				probeShots += 1
				local answer = os.clock() + math.min(PROBE_TIMEOUT, PROBE_EVERY * 4)
				while os.clock() < answer and #refusals == before do
					task.wait(0.05)
				end
				local answered = refusals[before + 1]
				-- THE WINDOW HAS TO HAVE BEEN QUIET, or "the shot spent nothing" cannot be read off
				-- the gun at all (task 210). Thrown away and retried, with the attempt in the log.
				if lastWeaponInput ~= inputMark then
					probeDiscarded += 1
					probeBefore = nil
					if #probeLog < 12 then
						table.insert(
							probeLog,
							string.format(
								"#%d DISCARDED: the replay touched the gun inside the window (answered=%s)",
								probeShots,
								tostring(answered)
							)
						)
					end
					task.wait(PROBE_EVERY)
					continue
				end
				probeAfter = gunPrint()
				-- THE OTHER HALF OF THE CLAIM, read the instant the server has answered: a refused
				-- shot must have tied nobody and announced nothing.
				probeTiedAfter = Match.isTied()
				probeViolationsAfter = #violations
				probeDryAfter = Weapon.Sound.stats().dry
				table.insert(
					probeLog,
					string.format(
						"#%d answered=%s tied %s->%s violations %d->%d",
						probeShots,
						tostring(answered),
						tostring(probeTiedBefore),
						tostring(probeTiedAfter),
						probeViolationsBefore or -1,
						probeViolationsAfter or -1
					)
				)
				-- `off-stand` IS NOT AN ANSWER TO THIS CASE'S QUESTION -- IT IS THE SERVER SAYING IT
				-- HAS NOT GOT HIM THERE YET (task 174, the Director's `test2` at `454d58a`: this
				-- client read itself **0.0 studs** from its own stand centre and the server's first
				-- rule still refused the shot, five refusals running, because GO had just respawned
				-- him onto his post and the park had not reached the server).
				--
				-- SO THE WAIT IS ON THE SERVER'S OWN VERDICT, which is what the Director asked for and
				-- is the only read that cannot drift from the rule: `Rules.outsideStand` is computed
				-- from the SERVER's view of his root, and that view is not published to this client at
				-- all -- the snapshot carries the stand CIRCLE (`snapshot.stands`) and no positions.
				-- Asking the gate is asking the gate. A probe aimed at his body can only ever be
				-- REFUSED (`off-stand` or `beater-in-line`), never accepted, and a refused attempt
				-- commits no state and costs no shell -- which is why asking again is free and why
				-- this is a retry rather than a sleep.
				--
				-- BOUNDED BY `PROBE_WINDOW`, unchanged: if the server never agrees inside it the case
				-- FAILS, with every attempt and its answer in the note. Nothing is weakened -- the
				-- assertion is still `beater-in-line`, and it is now asserted of the server's answer
				-- to a shot taken from where the server could see him.
				if answered == "off-stand" then
					probeOffStand += 1
					task.wait(PROBE_EVERY)
					continue
				end
				probeAgreedAfter = os.clock() - (cuedAt or os.clock())
				probeReason = answered
			end
			if probeAfter == nil then
				probeAfter = gunPrint()
			end
			-- THE AIM MAY MOVE OFF HIS BODY NOW. Until this line a replayed click is refused by the
			-- very rule being measured, which is why the tie can no longer land first.
			probeDone = true
		end)
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction(CUE_ACTION, onCue, false, Enum.KeyCode.T)

-- Holds the aim: on the driver when there is one, otherwise straight down the drive at nobody. It
-- asks the CAMERA OWNER and never writes workspace.CurrentCamera -- the camera's own foreign-write
-- detector counts that, and weapon_client.spec asserts the counter does not move.
local aiming = RunService.RenderStepped:Connect(function()
	if not cuedAt or os.clock() - cuedAt > TIE_TIMEOUT then
		return
	end
	-- HELD WHERE THE CUE PUT HIM, every frame, for both roles (task 171). See `park`.
	local mine = rootOf(player)
	if parkAt ~= nil and mine ~= nil then
		park(mine, parkAt :: Vector3)
	end
	local target = driver()
	local theirs = if target then rootOf(target) else nil
	if theirs and not Role.isDriver() then
		-- BESIDE HIM, NOT AT HIM (task 171) -- BUT ONLY ONCE THE PROBE HAS ANSWERED. Aimed at him the
		-- shot is REFUSED before it exists (`Weapon.Rules.beaterInLine`) and there is nothing for the
		-- safety rule to judge; aimed `BESIDE_STUDS` to his side it clears the SAFETY LOCK's 6 studs
		-- (task 248) so it really fires, it still passes within `SAFETY_MISS_STUDS` of him, and the arc
		-- and `Match.Penalty` do what this spec is named for.
		--
		-- THE ORDER IS THE POINT OF THE `probeDone` GUARD (`bac93d6`): the scenario clicks at 3.8 s
		-- and 5.0 s after the cue and the probe cannot fire until the scenario's own reload has
		-- finished, so an early click used to tie him BEFORE the refusal had been measured. While the
		-- aim is still on his body such a click is refused -- harmless, and more evidence -- and the
		-- tie is taken by whichever click comes after this flips.
		-- ...AND SINCE TASK 174 `probeDone` ALSO MEANS THE SERVER HAS HIM IN HIS STAND, so the arc shot
		-- inherits the probe's wait and cannot be refused `off-stand` either: the probe retries until
		-- the server's own rule stops saying it (the loop above), and only then does the aim move
		-- beside him for the click that ties him. One wait, placed before both shots, because this
		-- case runs before the tie case and he stays parked in between.
		local aimAt = if probeDone then theirs.Position + Vector3.new(BESIDE_STUDS, 0, 0) else theirs.Position
		Camera.lookAt(aimAt)
		return
	end
	-- AND A DRIVER'S CAMERA IS NOT THIS SPEC'S, which is the Reviewer's round-1 finding 1 and was a
	-- real regression: the driver's branch of `onCue` sets `cuedAt` (it has staging of its own since
	-- task 171, where before it returned without setting anything), `driver()` skips self, so on HIS
	-- client `theirs` is nil and this fall-through steered his camera every frame for the whole
	-- `TIE_TIMEOUT` -- while `camera_client.spec` is asserting about that camera, and while this
	-- file's own comment and the review request both said it never happens. The parking above is his
	-- half of the window; the AIM is the shooter's alone.
	if Role.isDriver() then
		return
	end
	local me = rootOf(player)
	if me then
		Camera.lookAt(me.Position + Vector3.new(0, 0, DOWN_THE_DRIVE))
	end
end)

InputReady.ready("zz_tie_to_a_tree")

function waitUntil(seconds: number, predicate: () -> boolean): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if predicate() then
			return true
		end
		task.wait(0.05)
	end
	return predicate()
end

return function()
	describe("a real shot down the drive line", function()
		-- A DRIVER IS NEVER CUED -- `onCue` ignores him on purpose -- so his client must not wait for
		-- one. MEASURED, and it is the reason this is a function and not a plain wait: two 150-second
		-- waits on the driver's client pushed its whole suite past the harness's 420-second report
		-- window, and a report that never arrives is one the run cannot even check (Task 34's half of
		-- the client suite).
		local function cued(): boolean
			-- ONE SOURCE FOR THE ROLE (TASKS.md 36a(3)(d)). This used to ask Match.myTeam() while
			-- `onCue` asked Role.isDriver(), and a nil team when Role resolved would have let the two
			-- disagree: the cue would have fired the shot and this would still have said "not a
			-- shooter". Role is the one answer the whole client suite branches on.
			expect(waitUntil(20, function()
				return Match.myTeam() ~= nil
			end)).to.equal(true)
			-- ...and Role, resolved at require time, must agree with the team the drive published.
			expect(Role.isDriver()).to.equal(Match.myTeam() == "Drivers")
			if not Role.isShooter() then
				return false
			end
			return waitUntil(CUE_TIMEOUT, function()
				return cuedAt ~= nil
			end)
		end

		it("was cued by the harness, so this spec's own scenario really ran", function()
			local shooter = cued()
			TestKit.note(
				string.format(
					"zz_tie: %s team=%s players=%d staged=%s cued=%s",
					player.Name,
					tostring(Match.myTeam()),
					#Players:GetPlayers(),
					tostring(stagedDistance),
					tostring(shooter)
				)
			)
			-- A shooter must have been cued; a driver is never cued and that is the rule, not a miss.
			expect(shooter).to.equal(Match.myTeam() == "Shooters")
		end)

		-- RULE 1 OF TASK 171, AND IT RUNS BEFORE THE TIE CASE ON PURPOSE: the tie takes the gun away,
		-- so a refusal can only be measured while the player still has one. The probe fired at the
		-- cue, which is seconds before the replayed click the next case depends on.
		it("refuses a shot aimed straight at a beater, and spends nothing doing it", function()
			expect(cued()).to.equal(Match.myTeam() == "Shooters")

			if Role.isDriver() then
				-- A driver carries no gun, so he cannot stage this at all.
				expect(holdsGun()).to.equal(false)
				return
			end

			if driver() == nil then
				-- ONE PLAYER: there is nobody to refuse a shot at, so the probe never fired -- and
				-- that is the honest assertion rather than a skip. The shot this session fires goes
				-- down an empty drive and is judged by the next case.
				expect(#Players:GetPlayers()).to.equal(1)
				expect(probeFired).to.equal(false)
				expect(probeReason).to.equal(nil)
				TestKit.note("zz_tie: one player, so no beater to refuse a shot at; probe not fired")
				return
			end

			-- TWO PLAYERS: the probe was fired dead at him.
			-- WAIT FOR THE PROBE TO BE FINISHED, not merely to have fired once (task 174). Since the
			-- retry above, a first answer of `off-stand` is not the end of it: `probeDone` is the
			-- loop's own last line, so this waits for the whole `PROBE_WINDOW` at most and then
			-- asserts whatever the server's last word was.
			expect(waitUntil(PROBE_WINDOW + PROBE_TIMEOUT * 2, function()
				return probeDone and probeAfter ~= nil
			end)).to.equal(true)
			local stand = standOf(player)
			TestKit.note(
				string.format(
					"zz_tie: probe aimed AT the driver -> refused=%s after %d attempt(s); blocked=%s; "
						.. "gun before [%s] after [%s]; refusals seen [%s]",
					tostring(probeReason),
					probeShots,
					tostring(probeBlocked),
					tostring(probeBefore),
					tostring(probeAfter),
					table.concat(refusals, ", ")
				)
			)
			-- THE GEOMETRY AS IT WAS WHEN THE SHOT WENT, not read back afterwards: the gate judged
			-- THESE numbers, and the replay keeps playing. `off-stand` instead of `beater-in-line`
			-- means the staging missed its own stand rather than the rule being wrong
			-- (`Weapon.Rules.ORDER`), and `ray` names what was in the way when nothing was refused.
			TestKit.note(
				string.format(
					"zz_tie: at the probe: stand=%s r=%s; me %.1f from the centre; driver %.1f away; ray hit %s",
					tostring(stand and stand.centre),
					tostring(stand and stand.radius),
					probeFromCentre or -1,
					probeToDriver or -1,
					tostring(probeRayHit)
				)
			)
			-- EVERY ATTEMPT, with the tie state at each one: the Director's question of `bac93d6`
			-- ("what was the first attempt?") answered in the log rather than inferred from a
			-- counter.
			TestKit.note(
				string.format(
					"zz_tie: probe attempts (%d discarded for replayed input inside the window, task 210): %s",
					probeDiscarded,
					table.concat(probeLog, " | ")
				)
			)
			-- WHAT THE SERVER'S OWN ANSWER DID, AND HOW LONG IT TOOK (task 174). The number that was
			-- missing when this case failed at `454d58a`: the client's distance said one thing and the
			-- server's rule another, and nothing in the log said how long that lasted. The server's
			-- VIEW of his root is not published to any client -- the snapshot carries the stand circle
			-- and no positions -- so its VERDICT is the read, and this is it, counted.
			TestKit.note(
				string.format(
					"zz_tie: the SERVER's own rule took %d off-stand refusal(s)%s to agree he was in "
						.. "his stand; this client read %.1f studs from the centre (stand r=%s)",
					probeOffStand,
					if probeAgreedAfter ~= nil
						then string.format(" and agreed %.1f s after the cue", probeAgreedAfter)
						else " and never agreed",
					probeFromCentre or -1,
					tostring(stand and stand.radius)
				)
			)
			-- THE STAGING'S OWN CLAIMS, asserted before the rule's and against the recorded numbers.
			-- Without them the case cannot tell "the beater rule is broken" from "this spec fired
			-- from the wrong place, at the wrong distance, through a post, or into a busy gun" --
			-- which is one defect per two-player run so far.
			expect(stand).to.be.ok()
			expect(probeBlocked).to.equal(nil)
			expect(probeFromCentre).to.be.ok()
			expect((probeFromCentre :: number) <= (stand :: any).radius).to.equal(true)
			expect((probeToDriver :: number) <= PROBE_REACH).to.equal(true)
			expect(probeRayHit).to.be.ok()
			-- THE SERVER'S OWN WORD FOR IT, off the wire: `Weapon.Rules.REASON.BEATER`.
			expect(probeReason).to.equal("beater-in-line")
			-- NOTHING WAS SPENT. The gun print carries the barrels and the pocket, so an unchanged
			-- string is "no shell, no barrel, no reload" in one comparison.
			expect(probeAfter).to.equal(probeBefore)
			-- AND NOBODY WAS TIED BY IT: there was no shot to judge. MEASURED AROUND THE PROBE'S OWN
			-- SHOT and not afterwards, which is the correction `bac93d6` forced: by the time this case
			-- reached its assertions the replayed click had legitimately tied him, so
			-- `Match.isTied()` here asks "is he tied NOW" and the honest answer to that is yes. The
			-- pair below is the claim itself -- untied before the refused shot, untied after it, and
			-- no violation announced in between -- and it is STRICTER than the old line, because the
			-- old one could have been satisfied by a probe that never fired.
			--
			-- `probeTiedBefore` IS ALSO THE CASE'S STARTING CONDITION: a session that arrives here
			-- already tied fails on this line, and that is the right outcome -- the gun would be
			-- gone, and TASKS.md 166a(b) records the same race biting two other client specs.
			expect(probeTiedBefore).to.equal(false)
			expect(probeTiedAfter).to.equal(false)
			expect(probeViolationsAfter).to.equal(probeViolationsBefore)
			-- AND THE GUN CLICKED. The server's refusal is the client's cue to play one dry click
			-- (`CameraBoot` -> `Weapon.Sound.dry`), and this is the only refusal in the suite that
			-- travels the real wire to a real client, so it is the only place that wiring can be
			-- asserted. The sound itself is Karen's to judge; that it was ASKED FOR is this line.
			TestKit.note(
				string.format("zz_tie: dry clicks %s -> %s", tostring(probeDryBefore), tostring(probeDryAfter))
			)
			expect((probeDryAfter or 0) > (probeDryBefore or 0)).to.equal(true)
		end)

		it("ties the shooter to a tree when a driver was in its path, or nobody when none was", function()
			expect(cued()).to.equal(Match.myTeam() == "Shooters")

			if Role.isDriver() then
				-- A DRIVER's client. It carries no gun (DRIVERS_MAY_SHOOT is false), so it cannot
				-- break this rule at all, and the rule must not have touched it either.
				expect(Match.myTeam()).to.equal("Drivers")
				expect(holdsGun()).to.equal(false)
				expect(Match.isTied()).to.equal(false)
				expect(Hud.isTiedBannerVisible()).to.equal(false)
				return
			end

			if driver() == nil then
				-- ONE PLAYER: the same shot, into an empty drive. The 45-degree arc published it to
				-- the Match and the Match let it go, because no driver was in the path. This is the
				-- rule NOT being a cone (design section 8.1).
				expect(#Players:GetPlayers()).to.equal(1)
				local tiedAnyway = waitUntil(TIE_TIMEOUT, function()
					return Match.isTied()
				end)
				expect(tiedAnyway).to.equal(false)
				expect(Hud.isTiedBannerVisible()).to.equal(false)
				expect(holdsGun()).to.equal(true) -- and the gun is still his
				return
			end

			-- TWO PLAYERS: the shot really did go dangerously close to a person -- `BESIDE_STUDS` off
			-- his body and inside `SAFETY_MISS_STUDS`, which is the shot the arc exists to punish
			-- (task 171; before it this aim was dead at him, which the new rule refuses outright).
			expect(stagedDistance).to.equal(STAND_BEHIND)
			local tied = waitUntil(TIE_TIMEOUT, function()
				return Match.isTied()
			end)
			if not tied then
				-- EVERY FACT THE NEXT READER NEEDS, and it is here because `violations=0` alone sent
				-- task 152 down two wrong paths: where BOTH players actually are now against where
				-- they were when the shot was staged, and whether the gun fired at all.
				local snapshot = Match.get()
				local target = driver()
				local theirsNow = if target then rootOf(target) else nil
				local meNow = rootOf(player)
				local drift = if theirsNow and stagedTheirs
					then (theirsNow.Position - (stagedTheirs :: Vector3)).Magnitude
					else -1
				local myDrift = if meNow and stagedFrom
					then (meNow.Position - (stagedFrom :: Vector3)).Magnitude
					else -1
				-- How far the driver is off the line this shot was staged on: `miss` in Penalty's own
				-- terms, against `SAFETY_MISS_STUDS` (12).
				-- AGAINST THE POINT THE SHOT WAS AIMED AT, which since task 171 is `BESIDE_STUDS` to
				-- his side -- not his root. Measured off his root this number was 0.0 by
				-- construction and said nothing; measured off the aim line it is the quantity
				-- `Penalty.judge` actually compares with `SAFETY_MISS_STUDS`, so a drift that
				-- carried him out of the 12 studs would be visible here.
				local miss = -1
				if theirsNow and meNow then
					local aim = (theirsNow.Position + Vector3.new(BESIDE_STUDS, 0, 0)) - meNow.Position
					if aim.Magnitude > 1e-6 then
						local toward = theirsNow.Position - meNow.Position
						miss = (toward - aim.Unit * toward:Dot(aim.Unit)).Magnitude
					end
				end
				TestKit.note(string.format(
					"zz_tie: NOT tied. phase=%s holdsGun=%s from=%s violations=%d refusals=[%s]",
					tostring(snapshot and snapshot.phase),
					tostring(holdsGun()),
					tostring(stagedFrom),
					#violations,
					-- SINCE TASK 171 THIS IS THE FIRST THING TO READ: a refusal here means the
					-- shot was never fired, so the Match was never asked -- the aim is back on
					-- his body instead of `BESIDE_STUDS` off it.
					table.concat(refusals, ", ")
				))
				TestKit.note(
					string.format(
						"zz_tie: driver staged at %s, now %s (drift %.1f); me staged %s, now %s (drift %.1f); miss %.1f of %d",
						tostring(stagedTheirs),
						tostring(theirsNow and theirsNow.Position),
						drift,
						tostring(stagedFrom),
						tostring(meNow and meNow.Position),
						myDrift,
						miss,
						12
					)
				)
				-- THE ONE THAT SPLITS THE PROBLEM: the gun at the cue against the gun now. If the
				-- barrels and the reserve are unchanged, NO SHOT WAS FIRED and the Match was never
				-- asked anything -- which is a weapon/input defect and not a penalty one.
				TestKit.note(string.format("zz_tie: gun at cue [%s] -> now [%s]", tostring(stagedGun), gunPrint()))
			end
			expect(tied).to.equal(true)
			-- ...AND IT WAS A SHOT, NOT A REFUSAL. One line, because the pair of them IS the task 171
			-- rule: the probe aimed at him was refused and tied nobody, and this shot aimed five
			-- studs off him was fired and tied him.
			TestKit.note(
				string.format(
					"zz_tie: TIED by a shot aimed %d studs beside the driver at %d studs; probe aimed at him was refused=%s",
					BESIDE_STUDS,
					STAND_BEHIND,
					tostring(probeReason)
				)
			)

			-- The snapshot is what everyone sees, and it names him.
			local snapshot = Match.get()
			local found = false
			for _, userId in ipairs(snapshot.tied) do
				if userId == player.UserId then
					found = true
				end
			end
			expect(found).to.equal(true)

			-- Visible to everyone: the feed said so. That is Karen's "visible to everyone with an
			-- announcement", and it is recorded as it arrives because the feed fades.
			expect(#violations >= 1).to.equal(true)
			expect(violations[1].userId).to.equal(player.UserId)

			-- On this player's own screen, with every ancestor really there.
			expect(waitUntil(5, function()
				return Hud.isTiedBannerVisible()
			end)).to.equal(true)
			local node: Instance? = Hud.tiedBanner()
			while node and node ~= game do
				if node:IsA("GuiObject") then
					expect(node.Visible).to.equal(true)
				elseif node:IsA("ScreenGui") then
					expect(node.Enabled).to.equal(true)
				end
				node = node.Parent
			end
			expect(node).to.equal(game)

			-- And the gun is gone: a tied player holding a gun he cannot aim is a worse joke than a
			-- tied player with none (design section 8.4 item 5).
			expect(waitUntil(10, function()
				return not holdsGun()
			end)).to.equal(true)

			-- AND THE CLIENT WAS TOLD (TASKS.md 35b(a)). Weapon.revoke used to reset the player's
			-- state without publishing it, so this replica kept the snapshot from before the gun was
			-- taken and the Hud kept drawing an ammo readout for a gun that no longer exists -- which
			-- is what .screenshots/task35-tied-to-a-tree.png shows.
			expect(waitUntil(10, function()
				local state = Weapon.get()
				return state ~= nil and not state.equipped
			end)).to.equal(true)
			expect(Hud.readoutText()).to.equal("")
		end)

		afterAll(function()
			if aiming.Connected then
				aiming:Disconnect()
			end
			ContextActionService:UnbindAction(CUE_ACTION)
			ContextActionService:UnbindAction(QUIET_ACTION)
		end)
	end)
end
