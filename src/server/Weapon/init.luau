--!strict
-- Weapon: the owner of every player's authoritative weapon state, of every granted Tool, and of the
-- six RemoteEvents (CLAUDE.md rule 3; the fifth, HitMarker, arrived with Milestone 1.5's hit
-- marker, and the sixth, ShotLanded, with Task 185's flight -- both one way, server -> client, and
-- the Hud and Effects are what draw them). It writes no boar state -- it publishes HitReported and the
-- boar's own owner decides what a hit means (docs/design/shotgun.md section 6) -- and it writes no
-- camera: the client reads workspace.CurrentCamera.CFrame for the aim ray and nothing more.
--
-- Pattern: one module-level owner over a pure core, the shape src/server/Boar/init.luau uses. The
-- pure modules (StateMachine, Validator, Limits, Registry, Pattern, Hits, SafetyArc) take `now`,
-- `rng`, `cast` and `ignore` as parameters, so the whole authoritative path is testable with no
-- Studio, no input harness and no boar. Cast is the only caller of Workspace:Raycast.
--   RemoteEvent security  https://create.roblox.com/docs/scripting/events/remote
--     "never trust the client": the client sends {origin, direction} and NOTHING else, so there is
--     no claimed target to reconcile and no tolerance to tune (design section 5.7).
--   BindableEvent         https://create.roblox.com/docs/reference/engine/classes/BindableEvent
--     signals, the choice docs/design/boar-ai.md already made for Despawned
--
-- Nothing happens on require: only WeaponBoot calls start(), so a spec can require this module and
-- drive the pure core with no game running.
--
-- Design: docs/design/shotgun.md (sections 3.1, 5.4, 5.5), docs/design/ballistics.md (sections 2, 6)
-- Note:   docs/research/2026-09-24-shotgun.md, docs/research/2026-10-14-ballistics-lead.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- THE ONE CLOCK THAT ADVANCES A FLIGHT (task 185). One `Heartbeat`, connected in `Weapon.start`,
-- and the only caller of `flight:advance` in the repo -- a grep must find one site.
local RunService = game:GetService("RunService")
-- WHERE THE STUDIO-ONLY CLAIM COUNTERS ARE PUBLISHED (task 266b). Server-only by construction, which
-- is what makes it readable by a server probe and invisible to every client.
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- THE PURE MATHS OF A SHOT THAT TAKES TIME TO ARRIVE (task 185). Frozen numbers plus functions of
-- their arguments, no writer at all -- the shape `Gun`, `Horn` and `Shop` already have.
-- THE ONE QUESTION THIS OWNER ASKS THE FLAG TABLE (task 260): which CAMERA is this game running.
-- `ORIGIN_TOLERANCE_STUDS` below is the only thing that reads it, once, at the boundary.
local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
local Ballistics = require(ReplicatedStorage:WaitForChild("Ballistics"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

local Cast = require(script.Cast)
local Rewind = require(script.Rewind)
-- THE SHOTS STILL IN THE AIR (task 185). It holds the list and steps it; it casts nothing itself
-- (the cast is a parameter), builds no report and fires no signal -- this file does all of that,
-- exactly as it did before, one frame or more later (docs/design/ballistics.md section 2).
local Flight = require(script.Flight)
local Hardware = require(script.Hardware)
-- THE BEATER'S HORN (task 152). It is in this system because the design puts it here -- *"worn is
-- Body's; carried is Weapon's"* (docs/design/beater-kit.md section 16 item 1) -- and it is its own
-- module because it shares no state with a gun. Nothing in this file calls into it: it is required
-- here only so that the two composition roots reach it as `Weapon.Horn`, the way they already reach
-- `Weapon.Hardware`.
local Horn = require(script.Horn)
local Hits = require(script.Hits)
local Limits = require(script.Limits)
local Pattern = require(script.Pattern)
local Registry = require(script.Registry)
-- THE THREE RULES OF TASK 171 (can't shoot off your stand, can't shoot a beater, can't shoot a
-- species you have no licence for). Pure, like every other module in this folder, and asked in
-- `Rules.ORDER`'s declared order by `Rules.refuse` -- which this file calls once and does not
-- second-guess, so the order is a rule a spec can assert rather than this file's private habit.
local Rules = require(script.Rules)
-- THE SHOP'S PURE DATA (task 178), for ONE function: `Shop.startFor(row, owned)`, which says what
-- shells this player may be issued. Frozen shared data with no writer, required the way `Rules`
-- requires `Licences` -- and `ServerScriptService.Shop` is NOT required here: this owner knows
-- nothing about a door, a price or a remote.
local Shop = require(ReplicatedStorage:WaitForChild("Shop"))
local SafetyArc = require(script.SafetyArc)
local Shapes = require(script.Shapes)
local StateMachine = require(script.StateMachine)
local Validator = require(script.Validator)

type WeaponState = Shotgun.WeaponState
type HitReport = Shotgun.HitReport

local Weapon = {}

-- Exported for specs only, exactly as src/server/Boar/init.luau exports Boar.Brain.
Weapon.StateMachine = StateMachine
Weapon.Validator = Validator
Weapon.Limits = Limits
Weapon.Registry = Registry
Weapon.Pattern = Pattern
Weapon.Hits = Hits
-- The flight MODULE and the ballistics maths, exported for specs exactly as every pure module above
-- is: a pure spec makes its own `Flight.new()` with its own config and its own cast, and never
-- touches the live one (design 4.3).
Weapon.Flight = Flight
Weapon.Ballistics = Ballistics
-- The weapon table and the world shape map, exported for the specs: the same reason every module
-- above is here, and the reason `rifle.spec` can drive two weapons with no Studio.
Weapon.Weapons = Weapons
Weapon.Shapes = Shapes
Weapon.SafetyArc = SafetyArc
-- The three fire rules (task 171), exported for the same reason every pure module above is: a spec
-- drives them with hand-written numbers, no world and no drive.
Weapon.Rules = Rules
Weapon.Cast = Cast
Weapon.Hardware = Hardware
Weapon.Shape = Shapes.BY_ID.shotgun
-- ...and the horn, which is not a gun and is reached the same way (task 152). It has its own
-- lifetime: `Horn.start()` is called by the composition root, not by `Weapon.start()`, because WHO
-- may carry one is that root's decision and this owner's arming has nothing to say about it.
Weapon.Horn = Horn

local CONFIG = Shotgun.CONFIG

-- HOW FAR FROM HIS OWN ROOT A PLAYER MAY CLAIM HIS EYE IS, read ONCE at this owner's boundary and
-- passed inward as an argument (task 260). That is the shape `docs/design/feature-flags.md` requires
-- of a flag read, applied to the one place this server has to know which CAMERA the game is running:
-- in FIRST PERSON the eye is 1.226 to 1.993 studs from the root (`camera_mode.spec` sweeps the whole
-- pitch range and asserts it), and in the third-person rollback the client's own clamp puts it at
-- 14.5. One number for both branches is the looser of the two, and this request is a CLIENT CLAIM
-- that `BORE_ON_SIGHT_LINE` now launches the bullet from -- so the loose number is the one that
-- matters. `Shotgun.CONFIG` carries both and says how each was measured.
--
-- IT READS THE SAME FLAG `Camera.Config` READS, which is the point rather than a coupling: "is this
-- game first person" has one answer, and a server that decided it some other way could disagree with
-- the camera that actually drew the frame.
local ORIGIN_TOLERANCE_STUDS = if Flags.isOn("FIRST_PERSON")
	then CONFIG.CAMERA_ORIGIN_TOLERANCE_FIRST_PERSON
	else CONFIG.CAMERA_ORIGIN_TOLERANCE

-- WHETHER THIS SERVER BELIEVES A CLIENT'S HIT CLAIM (task 266), read ONCE at this owner's boundary
-- in exactly the shape above -- which is the only shape `docs/design/feature-flags.md` permits.
--
-- OFF IS THE GAME BEFORE TASK 266, BY THE SAME CODE PATH: no claim is accepted, the shot resolves
-- from the server's own flight, and `stats.claimsIgnored` is the only trace. That matters more than
-- it sounds: "ignored" and "today" MUST be one path, or the flag's off state is a second
-- implementation nobody tests.
--
-- `claimPolicy` IS THE PARAMETER BESIDE IT, because CLAUDE.md requires a flagged path to be
-- reachable BY PARAMETER as well as by flag -- otherwise the ON branch cannot be tested while the
-- row sits at OFF. `Weapon.setClaimPolicy(nil)` restores this boundary's own answer, the shape
-- `setArmingPolicy` and `setCast` already have.
local CLAIMS_ON = Flags.isOn("HIT_CLAIM")
local claimPolicy: boolean? = nil

-- WHETHER THIS SERVER TESTS AN ANIMAL WHERE THE SHOOTER DREW IT (task 305). Read ONCE, here, at the
-- boundary, and passed inward as a shot's `rewindSeconds` -- so `Flight` and `Rewind` never read a
-- flag. `rewindPolicy` is the parameter beside it, the shape `setClaimPolicy` already has.
local REWIND_ON = Flags.isOn("AIM_REWIND")
local rewindPolicy: boolean? = nil

local registry = Registry.new()
-- ONE TOOL PER WEAPON PER PLAYER (task 140). Two Tools, because the engine's own hotbar is then the
-- switch: `1` and `2` are its keys, a switch changes `Tool.Parent` and nothing on the server runs
-- but the `sync()` that already watches exactly that signal. The alternative -- one Tool rebuilt on
-- a keypress -- puts a remote into `Hardware.equip`, which is the most expensive path in the system
-- and the one that produced "the gun is in the Backpack" in tasks 34, 123, 129 and 133.
local tools: { [Player]: { [string]: Tool } } = {}
local connections: { [Player]: { RBXScriptConnection } } = {}
local toolWatchers: { [Player]: { [string]: RBXScriptConnection } } = {}
-- One per player: the connection that notices the granted Tool being destroyed (Task 34).
local toolLifeWatchers: { [Player]: { [string]: RBXScriptConnection } } = {}
local stats = {
	shots = 0,
	reports = 0,
	rateDropped = 0,
	badRequests = 0,
	-- THE LARGEST |origin - root| ANY ACCEPTED SHOT HAD, in studs (task 260). In first person the
	-- geometry caps it at 1.993; anything much above that on a real server is the replication lag
	-- between the eye the client drew and the root this server has, which is the one term
	-- `CAMERA_ORIGIN_TOLERANCE_FIRST_PERSON`'s margin is for and the one nothing here can measure.
	originFarthest = 0,
	-- HOW MANY SHOTS THE ORIGIN BOUND REFUSED, and the worst separation among them (task 260 round
	-- 2). Both must stay 0 in an honest run: the geometry caps a first-person eye at 1.993 studs and
	-- the bound is 6, so a non-zero `originRefused` on a real server is either a forgery or the
	-- replication lag this margin was guessed for -- and `originRefusedFarthest` is which.
	originRefused = 0,
	originRefusedFarthest = 0,
	-- THE AIM QUESTION (task 238). `aimQuestions` is every `"Aim"` that got as far as a cast;
	-- `aimAdvised` the ones that answered with a gate -- today only `no-licence` -- and so published.
	-- The difference between them is how often a player shouldered at something he may already shoot,
	-- which is the number that says the cooldown is not costing a message per shoulder for nothing.
	aimQuestions = 0,
	aimAdvised = 0,
	-- HOW OFTEN THE LICENCE PROVIDER ANSWERED "I DO NOT KNOW" (task 255): a wired provider that
	-- errored or answered no table, which in the live game is a player whose economy profile is not
	-- open yet. Both gates -- the aim advice and the fire refusal -- then skip the licence question
	-- (`askLicences`), so this counter is the ONLY place a live run can see it happening: a silent
	-- skip and a working gate look identical from outside.
	licenceUnknown = 0,
	granted = 0,
	grantsMissed = 0, -- a tool built for a player with no Backpack: nothing recorded, tried again later
	revoked = 0,
	armingRepairs = 0, -- a sweep found a player who should be holding a gun and was not
	-- HOW EVERY EQUIP ENDED (task 129): see `Hardware.equipStats`. Copied out in `Weapon.stats`
	-- rather than kept here, because the equip itself is Hardware's.
	armingSweeps = 0, -- passes of the sweep below: 0 in a running server means it is not running
	meshUpgrades = 0, -- guns that were wearing the parts fallback when the mesh arrived (Task 76)
	meshUpgradeFails = 0, -- passes of that upgrade that ERRORED, so a silent one cannot look like a no-op
	emptySwaps = 0,
	markers = 0,
	-- HOW MANY SHOTS THE RULES REFUSED (task 171), and which rule refused them. Separate from
	-- `badRequests` on purpose: a refused shot is a LEGAL request that the game said no to, and
	-- counting it as a bad request would hide a mis-wired provider inside the forgery counter.
	refused = 0,
	refusedBy = {} :: { [string]: number },
	-- HOW MANY TRIGGER PULLS LANDED ON A GUN WITH NOTHING ANYWHERE (task 248). Separate from
	-- `refused` for that counter's own stated reason: a refusal is a LEGAL request the game said no
	-- to, and this is a gun that has nothing to say yes with.
	emptyTriggers = 0,
	-- THE CLAIM'S OWN INSTRUMENTS (task 266). A feature that can only fail by refusing everything
	-- needs to be able to say so: `claims` is how many arrived, `claimsIgnored` how many arrived
	-- while the policy was off (the OFF state's own meter), and `refusedClaimBy` names WHICH of the
	-- six checks a real server is failing rather than only how often.
	claims = 0,
	claimsIgnored = 0,
	claimsAccepted = 0,
	-- THE WORST ACCEPTED VIEW LAG (task 271): how far back the sweep had to look to find the
	-- picture the shooter actually shot at. **This is the instrument that argues
	-- `VIEW_LAG_BASE_SECONDS` down**: a server whose accepted claims all sit near 0 does not need
	-- the window, and one whose claims sit at the edge needs a bigger one.
	claimWorstLagSeconds = 0,
	-- WHAT THE SWEEP ACTUALLY REACHED, on the LAST claim that ran one (task 272 item 1). Four
	-- numbers, because they are what separates "the sweep is short" from "the choice is wrong":
	-- how many candidates it found against how many steps it asked for, how wide its window was,
	-- and whether ANY of them passed check 3. Task 271 read `lag=0.033s` -- two grid steps of the
	-- eighteen a 0.30 s window asks for -- and could not say which of the two that was.
	claimSweepFound = 0,
	claimSweepAsked = 0,
	claimSweepWindow = 0,
	claimSweepPassed = false,
	claimSweepSpread = 0,
	claimSweepIndex = 0,
	claimSweepBestLine = 0,
	claimSweepBestIndex = 0,
	claimSweepSegments = 0,
	-- The last claim's own part and zone, for EVERY claim that reaches the judge -- accepted or
	-- refused (task 274). Not the accepted ones only: reading it as "an accepted claim named this"
	-- is the exact mis-attribution this field was added to end.
	claimLastPart = "none",
	-- The displacement between the arrival instant and the swept one, on the last claim that
	-- reached the sweep (task 275). It is what check 5's waiver is widened by, and it is published
	-- so a spec can assert the OWNER supplies it rather than the spec's own hand.
	claimLastDisplacement = 0,
	-- WHY A REFUSAL HAPPENED, AS A NUMBER (task 269b). `refusedClaimBy` counts them by name;
	-- this keeps, per name, the WORST measured value, its budget, and -- for the one rule whose
	-- cause is an Instance -- what actually stopped the bullet.
	--
	-- **IT EXISTS BECAUSE TASK 269 COULD NOT ASK THE NEXT QUESTION.** That task measured
	-- `claims=10 accepted=2 refused=8 [claim-blocked=4 claim-line=4]` on real shots at running deer,
	-- and `claimWorstStuds` / `claimWorstLineStuds` / `claimWorstEndStuds` are written only AFTER
	-- `claimsAccepted += 1` -- so a refused claim left nothing behind at all, and the published
	-- worsts were the worst over the two ACCEPTED claims. A rule that refuses without leaving a
	-- number cannot be argued with.
	refusedClaimWorst = {} :: { [string]: { measured: number, budget: number, note: string? } },
	claimsRefused = 0,
	refusedClaimBy = {} :: { [string]: number },
	-- THE VIEW-ERROR METER, and the one number anybody has ever had for it. The worst ACCEPTED
	-- disagreement between the client's own point and the server's rewind of it (check 2), and the
	-- worst accepted distance from the server's own trajectory (check 3). Task 265 spent three
	-- rounds trying to measure the first of these with a paired probe and could not establish it;
	-- this is the same quantity, measured by the game itself on every honest shot, which is what
	-- lets `POSITION_TOLERANCE_STUDS` be argued down from evidence later
	-- (the idiom `stats.originFarthest` already uses).
	claimWorstStuds = 0,
	claimWorstLineStuds = 0,
	-- The trajectory's END point against the claimed point: the across-track figure above PLUS the
	-- along-track error. Reported beside it, never used by a check (task 266b, round 1).
	claimWorstEndStuds = 0,
	-- HOW OLD THE CLAIMED ARRIVAL WAS WHEN THE SHOT RESOLVED, in seconds, over every claim that got
	-- as far as the rewind -- accepted or refused (task 266b). **NEGATIVE IS THE FUTURE**, and that
	-- is the whole reason this pair exists: `Boar.sampleAt` refuses an instant after its newest
	-- sample, so a client whose `GetServerTimeNow()` runs AHEAD of the server's produces a claim
	-- nobody can answer, and the refusal reads `claim-history` with no clue why. Task 265 measured
	-- the client drawing animals ~0.17 s in the future and could not establish the cause; this is
	-- the same quantity asked from the one place that can answer it.
	claimAgeMin = 0,
	claimAgeMax = 0,
	claimAges = 0,
	-- WHY THE REWIND SAID NO, as a short string: "unwired", "no-sample", "ok", or the error a
	-- throwing provider produced. `claim-history` alone is a riddle; this is the answer (task 266b).
	claimHistoryWhy = "",
	-- TASK 305. How many rewound animal casts this server has made, and how many found the animal
	-- where the shooter drew it. Both 0 in any run with `AIM_REWIND` off or no animal in the air.
	rewindCasts = 0,
	rewindHits = 0,
	-- THE FLIGHT'S OWN NUMBERS (task 185). `shots` keeps its meaning -- accepted trigger pulls --
	-- so it now LEADS `shotsResolved` by up to 0.365 s, and that gap is the instrument for "a shot
	-- that never landed". `flightTimeouts` must stay 0: nothing legitimate reaches
	-- `FLIGHT_MAX_SECONDS` (5.5x the longest real flight), so a non-zero value is a bug.
	-- `noBallistics` must stay 0 too: both shipped rows carry all three numbers and `rifle.spec`
	-- asserts it field by field, so a non-zero value is a data fault in a weapon row.
	shotsResolved = 0,
	flightTimeouts = 0,
	flightRefused = 0,
	noBallistics = 0,
	-- THE LAG COMPENSATION THIS SERVER HAS HANDED OUT, in seconds (task 256), mirrored off
	-- `Flight.catchUpSeconds` beside the two above so one `stats()` still answers everything. It
	-- IT IS NEAR ZERO IN A HARNESS RUN, AND "NEAR" IS MEASURED (task 256, round 2). A loopback
	-- Studio Play session does NOT read a zero ping: `Player:GetNetworkPing()` reported 1.70 ms of
	-- total compensation across one run's shots -- 0.065 studs on a sprinting boar, nothing a player
	-- could see, but NOT 0. The first version of `weapon_state.spec` asserted exactly 0 and failed on
	-- it, which is how this is known rather than assumed.
	-- So the guard is a PER-SHOT BOUND (10 ms, ~50x this machine and 15x under the cap): loose enough
	-- never to flake, tight enough that a wrong `FLIGHT_CATCHUP_PING_FACTOR` or a seconds/milliseconds
	-- mix-up trips it. On a real server it is expected to be much larger, and it is the only
	-- instrument anybody has for how much that factor is actually buying (research note 5.4).
	flightCatchUpSeconds = 0,
	-- Passes of `Weapon.refillForDrive` that actually refilled a drive's shells (task 171): 0 in a
	-- running drive means the drive is not calling it.
	refills = 0,
}

-- Seconds between arming sweeps. EDGE-TRIGGERED ARMING MISSES, and a miss is permanent: the drive
-- calls refreshArming on its own transitions and the weapon grants on CharacterAdded, so if the
-- answer to "may this player carry a gun" changes between two edges -- or a grant lands in the
-- Backpack a placement is about to destroy while the drive is still mid-transition -- nothing asks
-- again and the player stands in a whole drive empty-handed. Measured in a two-player drive, twice,
-- with mayCarryWeapon saying the shooter was armed (Task 34). The sweep is the level: it asks the
-- same question the same way, grants nothing a refreshArming would not, and costs one table scan.
local ARMING_SWEEP_SECONDS = 2

local hitSignal = Instance.new("BindableEvent")
local safetySignal = Instance.new("BindableEvent")
local shotSignal = Instance.new("BindableEvent")
local resolvedSignal = Instance.new("BindableEvent")
Weapon.HitReported = hitSignal.Event
-- ({ shooterUserId: number, muzzle: Vector3, ammo: string }) -- A SHOT WAS FIRED, hit or miss, and
-- before this there was no server-side way to know that: `HitReported` is per hit and the client
-- remote below is per client. Fired once per ACCEPTED shot, so a rate-limited, invalid or unarmed
-- click publishes nothing. The name deliberately matches the remote: one fact, two audiences,
-- exactly as `HitReported` sits beside the `HitMarker` remote.
--
-- Its one listener is `MatchBoot`, which calls `Boar`'s `runtime:hearShot(muzzle, at)`: every boar
-- inside either of `SENSE`'s two radii sprints. Neither owner requires the other.
-- Design: docs/design/boar-behaviour.md section 4.5
Weapon.ShotFired = shotSignal.Event
-- A SHOT RESOLVED, HIT *OR* MISS (task 298, design section 8.3). `HitReported` is per hit, so a miss
-- publishes nothing, and `ShotFired` fires at the TRIGGER, up to 0.365 s before the bullet lands.
-- One publish from the one place that knows; it decides nothing and writes nothing.
-- ({ shooter: Player?, shooterUserId: number, weapon: string?, ammo: string, muzzle: Vector3,
--    reachedStuds: number, endPoint: Vector3, firedAt: number, resolvedAtServerTime: number,
--    hitParts: { Instance } })
Weapon.ShotResolved = resolvedSignal.Event
-- (player, aim: Vector3 unit, muzzle: Vector3, stopAt: number) -- stopAt is studs from the muzzle to
-- where the shot stopped, or the ammo's range when it hit nothing. The drive needs it to tell a shot
-- that went past a driver from one that stopped in the boar in front of him (Task 35).
Weapon.SafetyViolated = safetySignal.Event

local started = false
local remotes = nil -- resolved once in start(); Shotgun.remotes() is five WaitForChild calls
local rng = Random.new()
local castFn: Shotgun.CastFn = Cast.world
-- THE ONE LIVE FLIGHT (task 185). One instance for the server, stepped by the one `Heartbeat` in
-- `Weapon.start`. `Shotgun.CONFIG` is its config: the step cap, the sub-step cap, the ceiling and
-- the live cap are properties of the SERVER, not of a gun (design 3.2).
local flight = Flight.new(CONFIG)
local driveLineProvider: Shotgun.DriveLineProvider? = nil
-- Injected by the drive at the composition root (docs/design/drive.md section 8.5). The THIRD
-- injected provider on this owner, beside setCast and setDriveLineProvider -- the established idiom,
-- not a new mechanism. nil restores Shotgun.CONFIG.shouldArm, which is what a server with no Match
-- uses, so every tests/server/weapon_*.spec.luau is untouched.
local armingPolicy: ((Player) -> boolean)? = nil

-- THE FACTS THE RULES NEED (three in task 171, a fourth in 174), injected at the composition root exactly as the two
-- above are: the drive answers them and the weapon still decides and still writes
-- (docs/research/2026-10-13-the-rules.md, the pattern adopted, item 3).
--
-- WITH NO PROVIDER WIRED EVERY ANSWER IS "NO RESTRICTION", so a server with no Match -- which is
-- every tests/server/weapon_*.spec.luau and the bare DEV place -- fires exactly as it did before
-- this task. A gate that defaulted to "refuse" would make an unwired world look like Karen's rule
-- working, which is the silent failure this repo measures instead of assuming.
local targetProvider: ((Instance?) -> Rules.Target?)? = nil
local standProvider: ((Player) -> Rules.StandArea?)? = nil
local licenceProvider: ((Player) -> { [string]: boolean }?)? = nil
-- WHAT HE HAS BOUGHT (task 178). nil is "nobody answered", which is today's game.
local entitlementProvider: ((Player) -> { [string]: boolean }?)? = nil
-- IS THE DRIVE OPEN *FOR THIS PLAYER*? (task 174, the fourth fact; the `Player` is task 298's.) It
-- was "for everybody at once" until a shooting range existed in the lobby, where one man's trigger is
-- live between drives. `Match.driveOpen` ignores the argument, so every shipped caller is unchanged.
local driveOpenProvider: ((Player?) -> boolean?)? = nil
-- THE SAFETY LOCK'S PROVIDER (task 248): see `Weapon.setSafetyLineProvider`.
local safetyLineProvider: ((Player, Vector3, Vector3, number) -> boolean?)? = nil
-- WHERE AN ANIMAL WAS (task 266). `Boar.Runtime:cframeAt` in production, wired by a composition root.
local historyProvider: ((Instance, number) -> CFrame?)? = nil

function Weapon.setCast(cast: Shotgun.CastFn?)
	castFn = cast or Cast.world
end

function Weapon.setDriveLineProvider(provider: Shotgun.DriveLineProvider?)
	driveLineProvider = provider
end

-- WHAT THE AIM RAY HIT, as the thing's own owner describes it: `{ beater = true }` for a man walking
-- the drive, `{ species = "boar" }` for an animal. The weapon knows what neither of those IS.
function Weapon.setTargetProvider(provider: ((Instance?) -> Rules.Target?)?)
	targetProvider = provider
end

-- THIS PLAYER'S STAND CIRCLE, or nil for "he has none" -- a beater, a player between drives, a
-- hunter whose 15 s pick has not locked.
--
-- ...AND IT HANDS BACK THE ONE IT IS REPLACING (task 301), for `setDriveOpenProvider`'s reason. It
-- was the one setter of the four that returned nothing, so `Range.installOver` captured a nil base
-- and the composed provider answered "no stand" for everybody everywhere -- the drive's own rule
-- gone server-wide (reviews/task-298/RESULT.md finding 1).
function Weapon.setStandProvider(provider: ((Player) -> Rules.StandArea?)?): ((Player) -> Rules.StandArea?)?
	local previous = standProvider
	standProvider = provider
	return previous
end

-- WHICH SPECIES HE IS LICENSED FOR. STILL UNWIRED AFTER THE SHOP (task 178), and the promise this
-- comment used to make -- *"The shop task wires it"* -- is withdrawn with its reason, which is the
-- shop's own invariant: no deer exists, a boar needs no licence (`Licences.ROWS`), and a catalogue
-- row for a SPECIES PERMIT for an animal that is not in the game would be a row that grants nothing
-- -- the one thing `Shop.rowsOk` refuses. Karen names its price the day a deer exists
-- (docs/design/shop.md section 7.4 and 16 item 13). So the rule stays reachable and inert.
--
-- IT IS A DIFFERENT LICENCE FROM THE SHOP'S. `licence.beater` is a BEATER's permission to carry a
-- gun in a drive and is read by `Match.mayCarryWeapon` alone; this one is permission to shoot AT a
-- species and is read by `Rules.unlicensed`. Three things called "licence" in one game, and
-- conflating two of them is the `Match.Penalty` warning applied to a word.
function Weapon.setLicenceProvider(provider: ((Player) -> { [string]: boolean }?)?)
	licenceProvider = provider
end

-- WHAT HE HAS BOUGHT (task 178): the FOURTH injected provider on this owner, in the shape the other
-- three have. `ServerScriptService.Economy` answers it through the composition root, which is where
-- the `Player` -> userId translation belongs -- this owner's providers all take a Player and
-- `Economy` *"must not hold a Player"* (its own header).
--
-- UNWIRED MEANS nil, AND nil IS TODAY'S GAME: the full loadout and the weapon's own shells
-- (docs/design/shop.md section 7.1). A world with no shop -- the bare DEV place and every
-- `tests/server/weapon_*.spec.luau` -- is untouched by this task.
--
-- IT HANDS BACK THE ONE IT IS REPLACING (task 298), for `setDriveOpenProvider`'s reason.
function Weapon.setEntitlementProvider(
	provider: ((Player) -> { [string]: boolean }?)?
): ((Player) -> { [string]: boolean }?)?
	local previous = entitlementProvider
	entitlementProvider = provider
	return previous
end

-- WHETHER THE DRIVE IS BETWEEN ITS TWO SIGNALS (task 174). KAREN, 2026-10-13 ~09:35: *"for hunter
-- once hunt over (drive) horn anounce then I can; shoot anymore"*. `Match.driveOpen` answers it off
-- the drive's own phase and GO time, which is the same predicate the beater's horn is gated on
-- (`Match.mayBlowHorn`) and the bot line's walk (`Match.botsMayGo`) -- one source, no second clock.
--
-- Unwired means "no restriction", the default every provider above takes: `Rules.driveClosed` refuses
-- only on an explicit `false`.
--
-- ...AND IT HANDS BACK THE ONE IT IS REPLACING (task 298), exactly as `setArmingPolicy` has since
-- task 150: a second root that composes over this one must be able to keep the first one's answer
-- without knowing who installed it.
function Weapon.setDriveOpenProvider(provider: ((Player?) -> boolean?)?): ((Player?) -> boolean?)?
	local previous = driveOpenProvider
	driveOpenProvider = provider
	return previous
end

-- DOES THIS SHOT LINE PASS CLOSE TO A PERSON? (task 248.) KAREN, 2026-10-23: *"I still can shoot
-- towards hunters and beaters"*. THE SIXTH injected provider on this owner, in the shape the five
-- above have: the DRIVE measures it -- `Match.lineIsUnsafe`, over `Match.Penalty.judge`, which is
-- the game's one definition of *"the shot passed close to a person"* and already judges the tie --
-- and the WEAPON refuses and writes. It is handed four facts the weapon has at the trigger and
-- nothing else: who is shooting, where the muzzle is, which way the pellets are going, and how far
-- they get.
--
-- IT IS THE ONE PROVIDER WHOSE ANSWER IS SHOT-SPECIFIC, which is why it takes arguments where
-- `driveOpenProvider` takes none: the question is about THIS line and not about the world.
--
-- Unwired means "no restriction", the default every provider here takes: `Rules.unsafeLine` refuses
-- only on an explicit `true`, so every `tests/server/weapon_*.spec.luau` and a bare DEV place fire
-- exactly as they did before this task.
function Weapon.setSafetyLineProvider(provider: ((Player, Vector3, Vector3, number) -> boolean?)?)
	safetyLineProvider = provider
end

-- WHERE WAS THIS INSTANCE AT THIS SERVER TIME? (task 266) The SEVENTH injected provider on this
-- owner, in exactly the shape the six above have, and the only one whose answer comes from the BOAR
-- rather than from the drive. Given any Instance that belongs to an animal and a
-- `GetServerTimeNow()` stamp, it answers THAT INSTANCE's own CFrame at that time.
--
-- THIS IS THE WHOLE OF WHAT THE WEAPON KNOWS ABOUT AN ANIMAL'S PAST. It cannot enumerate animals,
-- cannot ask where one is NOW, and holds nothing between shots: it is handed an answer, never a
-- buffer (`docs/design/ballistics.md` section 2.1). `Boar` does not require `Weapon` and `Weapon`
-- does not require `Boar`; a composition root wires them, which is `docs/design/shotgun.md` 6.3's
-- rule -- *"neither owner depends on the other"*.
--
-- nil IS "I DO NOT KNOW", AND IT IS FOUR FACTS WITH ONE ANSWER: the instance is not an animal's, the
-- animal is dead/DOWN/GONE, the time is outside the ring's span, or no provider is wired at all.
-- Every one of them REFUSES the claim -- which is the weapon's own default for every provider here:
-- unwired means today's game.
function Weapon.setHistoryProvider(provider: ((Instance, number) -> CFrame?)?)
	historyProvider = provider
end

-- A SECOND RUNTIME'S HISTORY, BESIDE THE FIRST (task 305, round 1 finding 1). **The lobby has TWO
-- animal runtimes**: the drive's, wired by `MatchBoot`/`ForestTestBoot` through the seam above, and
-- the range's own (`RangeBoot`'s `Boar.newRuntime`, which "does not borrow the drive's"). With one
-- replaceable slot, whichever booted last won and every shot on the OTHER runtime's animal resolved
-- with no rewind -- which was every shot on the range, measured 0/6 by session 9d5b3ff8.
--
-- APPENDED, NOT REPLACING, so the two boots above are untouched and the order they load in cannot
-- decide the answer. `nil` CLEARS THE EXTRAS and `setHistoryProvider(nil)` clears the primary, so a
-- spec restores exactly what it found. One list of at most a handful, walked in order, first
-- non-nil wins -- `nil` from one runtime means "not mine", which is the seam's own documented
-- meaning, so falling through is reading it correctly rather than guessing.
local extraHistory: { (Instance, number) -> CFrame? } = {}

function Weapon.addHistoryProvider(provider: ((Instance, number) -> CFrame?)?)
	if provider == nil then
		table.clear(extraHistory)
		return
	end
	table.insert(extraHistory, provider)
end

-- WHERE WAS THIS INSTANCE THEN, asked of the primary and then of each extra. nil is still "nobody
-- knows", and `Weapon.castWithRewind` keeps today's behaviour for exactly that answer.
local function historyAt(instance: Instance, at: number): CFrame?
	if historyProvider ~= nil then
		local answer = historyProvider(instance, at)
		if answer ~= nil then
			return answer
		end
	end
	for _, provider in ipairs(extraHistory) do
		local answer = provider(instance, at)
		if answer ~= nil then
			return answer
		end
	end
	return nil
end

-- THE TWO WORLD CALLS THE REWIND MAKES, AS ONE SEAM (task 305). `Cast.candidates` asks what animal
-- is NEAR the segment and `Cast.only` casts at one of them; both touch Workspace, so both are
-- injectable and `weapon_rewind.spec` drives the whole path with no world at all. nil restores the
-- real ones, which is every caller in the game. The shape is `setCast`'s.
local candidatesFn: ((Vector3, Vector3, number, { Instance }, (Instance?) -> (Instance?, string), number) -> { Instance })? =
	nil
local castOnlyFn: ((Instance, Vector3, Vector3) -> Shotgun.Impact?)? = nil

function Weapon.setRewindWorld(
	candidates: ((
		Vector3,
		Vector3,
		number,
		{ Instance },
		(Instance?) -> (Instance?, string),
		number
	) -> { Instance })?,
	castOnly: ((Instance, Vector3, Vector3) -> Shotgun.Impact?)?
)
	candidatesFn = candidates
	castOnlyFn = castOnly
end

-- WHETHER THIS SERVER REWINDS, as a parameter beside the flag. `nil` restores the boundary's answer.
function Weapon.setRewindPolicy(enabled: boolean?): boolean?
	local was = rewindPolicy
	rewindPolicy = enabled
	return was
end

-- HOW FAR BACK THIS SHOOTER'S PICTURE OF A MOVING ANIMAL IS, in seconds.
--
-- `FLIGHT_REWIND_BASE_SECONDS` (0.250 since task 309a, MEASURED -- see its row) is the engine's own interpolation
-- buffer, plus the ping's downward trip, capped by the animal ring's own span. THE SHAPE IS
-- `Weapon.viewWindowFor`'s line for line: `ping` is a parameter with a `GetNetworkPing` fallback
-- inside a `pcall`, and a negative, a NaN or a missing ping contributes ZERO rather than a guess --
-- so the failure mode of this whole feature is "the game shoots as it did yesterday".
function Weapon.rewindFor(player: Player?, ping: number?, config: any?): number
	if rewindPolicy == false or (rewindPolicy == nil and not REWIND_ON) then
		return 0
	end
	local cfg = config or CONFIG
	local seconds = ping
	if seconds == nil then
		local ok, measured = pcall(function()
			return (player :: any):GetNetworkPing()
		end)
		seconds = if ok and type(measured) == "number" then measured else 0
	end
	if type(seconds) ~= "number" or seconds ~= seconds or seconds <= 0 then
		seconds = 0
	end
	return math.clamp(
		cfg.FLIGHT_REWIND_BASE_SECONDS + seconds * cfg.FLIGHT_CATCHUP_PING_FACTOR,
		0,
		cfg.CLAIM.VIEW_LAG_MAX_SECONDS
	)
end

-- THE CAST THE FLIGHT ACTUALLY USES (task 305). Two passes, nearest wins:
--   1. the STATIC world, with every candidate animal EXCLUDED, so a present-position animal can
--      never stop a bullet and be read as a tree;
--   2. each candidate, cast with the segment moved by MINUS its own displacement over `rewind` --
--      `Weapon.Rewind`, which is pure and owns that arithmetic.
-- With `rewind` 0, no provider, or no candidate near the segment it is `castFn(origin, dir, ignore)`
-- and NOTHING ELSE RUNS: the flag's off state and today's game are one path.
-- WHICH EXIT `castWithRewind` TOOK, out where a probe can read it (task 305b). Studio only and
-- read by nothing in the game: `stats` is module state and an `execute_luau` probe gets a FRESH
-- module, so the live server's own answer has to be published (`ServerStorage.DHBoarHistory`'s rule).
-- ...AND WHY, COUNTED PER REASON (task 309). "plain" was one number for five different exits, so a
-- run that never rewound read the same as one that rewound every shot and missed.
-- Note: reviews/task-309/REQUEST.md
local rewindTrail = { plain = 0, cast = 0, hit = 0, why = {} :: { [string]: number } }
-- READ ONCE, AND EVERY CALL SITE IS WRAPPED IN `if STUDIO then` (round 1 finding 1): a live server
-- formats no string and reads no part for a probe it cannot reach.
local STUDIO = RunService:IsStudio()
local function trail(why: string, extra: string?)
	rewindTrail.why[why] = (rewindTrail.why[why] or 0) + 1
	pcall(function()
		local reasons = {}
		for name, count in pairs(rewindTrail.why) do
			table.insert(reasons, string.format("%s=%d", name, count))
		end
		table.sort(reasons)
		ServerStorage:SetAttribute(
			"DH305Rewind",
			string.format(
				"plain=%d cast=%d hit=%d counts[%s] why=%s %s",
				rewindTrail.plain,
				rewindTrail.cast,
				rewindTrail.hit,
				table.concat(reasons, " "),
				why,
				extra or ""
			)
		)
	end)
end

function Weapon.castWithRewind(
	origin: Vector3,
	direction: Vector3,
	ignore: { Instance },
	rewind: number?
): Shotgun.Impact?
	if type(rewind) ~= "number" or rewind <= 0 or (historyProvider == nil and #extraHistory == 0) then
		if STUDIO then
			rewindTrail.plain += 1
			trail(
				if type(rewind) ~= "number" or rewind <= 0 then "rewind-zero" else "no-provider",
				string.format("rewind=%s extras=%d", tostring(rewind), #extraHistory)
			)
		end
		return castFn(origin, direction, ignore)
	end
	local findCandidates = candidatesFn or Cast.candidates
	local castOnly = castOnlyFn or Cast.only
	-- The pad is how far the fastest animal can travel over the rewind window, so one it has
	-- already carried off the line is still a candidate.
	local pad = rewind * CONFIG.CLAIM.MAX_TARGET_SPEED_STUDS
	-- NEAREST TO THE MUZZLE FIRST (round 1 note): `MAX_TARGETS` cuts the list, and cutting an
	-- arbitrary order would leave the 9th animal of a sounder neither rewound nor excluded.
	local roots = findCandidates(origin, direction, pad, ignore, Hits.targetOf, CONFIG.CLAIM.MAX_TARGETS)
	if #roots == 0 then
		if STUDIO then
			rewindTrail.plain += 1
			trail("no-roots", string.format("rewind=%.3f pad=%.1f", rewind, pad))
		end
		return castFn(origin, direction, ignore)
	end
	local at = Workspace:GetServerTimeNow() - rewind
	local candidates: { Rewind.Candidate } = {}
	local staticIgnore = table.clone(ignore)
	for _, root in ipairs(roots) do
		local present = (root :: any).CFrame
		local past = historyAt(root, at)
		-- **EXCLUDED FROM THE STATIC PASS ONLY IF IT IS IN THE REWOUND ONE** (round 1 finding 1).
		-- The other order deleted an animal the provider cannot answer for from BOTH passes and the
		-- bullet went straight through it -- and `cframeAt` answers nil for four ordinary states: an
		-- animal no wired runtime owns, one that is DOWN, one younger than the rewind window, and
		-- one whose trunk has gone. Those keep TODAY's behaviour instead: tested where the server
		-- has them, which is a hit the shooter must lead for, not a miss he cannot explain.
		if typeof(present) == "CFrame" and typeof(past) == "CFrame" then
			table.insert(staticIgnore, root)
			table.insert(candidates, { root = root, present = present, past = past })
		end
	end
	if #candidates == 0 then
		if STUDIO then
			rewindTrail.plain += 1
			trail("no-history", string.format("rewind=%.3f roots=%d", rewind, #roots))
		end
		return castFn(origin, direction, ignore)
	end
	local static = castFn(origin, direction, staticIgnore)
	local rewound = Rewind.impact(origin, direction, candidates, castOnly, CONFIG.CLAIM.MAX_TARGETS)
	stats.rewindCasts += #candidates
	if rewound ~= nil then
		stats.rewindHits += 1
	end
	-- THE WHOLE DIAGNOSTIC INSIDE ONE GUARD (round 1 finding 1): the instant the animal was tested
	-- at, published on the animal so the SHOOTER'S client can compare it with his own trigger, and
	-- the effective look-back in seconds. Nothing in the game reads either.
	if STUDIO then
		rewindTrail.cast += 1
		if rewound ~= nil then
			rewindTrail.hit += 1
		end
		pcall(function()
			local root = candidates[1].root :: any
			root:SetAttribute("DH305At", at)
			-- THE FRAME THE SERVER ACTUALLY TESTED, beside the instant it names (task 309a). `At`
			-- alone cannot settle "the server tested the animal HERE, the client drew it THERE":
			-- the two positions are the evidence, so both tenses are published as plain strings.
			-- Studio only, read by nothing in the game -- an instrument, like `DHLastHits`.
			-- ON `candidates[1]`, THE NEAREST CANDIDATE, and not necessarily the animal struck
			-- (round 1, note): with one animal on the segment it is the right one, which is the
			-- range bench's case; with a sounder in the pad these two name a different animal from
			-- the one the ring's `id=` does, and the reader must check that they agree.
			root:SetAttribute(
				"DH305Past",
				string.format(
					"%.3f,%.3f,%.3f",
					candidates[1].past.Position.X,
					candidates[1].past.Position.Y,
					candidates[1].past.Position.Z
				)
			)
			root:SetAttribute(
				"DH305Pres",
				string.format(
					"%.3f,%.3f,%.3f",
					candidates[1].present.Position.X,
					candidates[1].present.Position.Y,
					candidates[1].present.Position.Z
				)
			)
		end)
		local back = (candidates[1].present.Position - candidates[1].past.Position).Magnitude
		local spd = (candidates[1].root :: any).AssemblyLinearVelocity.Magnitude
		trail(
			"rewound",
			string.format(
				"rewind=%.3f cands=%d back=%.2f spd=%.2f eff=%.3f hit=%s",
				rewind,
				#candidates,
				back,
				spd,
				if spd > 1 then back / spd else 0 / 0,
				tostring(rewound ~= nil)
			)
		)
	end
	return Rewind.nearer(static, rewound)
end

-- WHETHER THIS SERVER ACCEPTS CLAIMS, as a parameter beside the flag (task 266).
--
-- `nil` RESTORES THE BOUNDARY'S OWN ANSWER (`Flags.isOn("HIT_CLAIM")`, read once at load). It exists
-- because CLAUDE.md requires a flagged path to be reachable BY PARAMETER as well as by flag -- a
-- path that can only be reached at the row's shipped value cannot be tested at the other one -- and
-- because the live forged-claim case in `weapon_shot.spec` has to reach the ON branch while the row
-- sits at OFF. Returns what it was, so a spec can restore it rather than assuming the default.
function Weapon.setClaimPolicy(enabled: boolean?): boolean?
	local was = claimPolicy
	claimPolicy = enabled
	return was
end

-- EVERY PROVIDER IS CALLED THROUGH `pcall`, the rule `mayArm` already states: a provider that errors
-- must not leave a player permanently unable to shoot AND must not silently remove the rule. It
-- falls back to "no restriction", which is the weapon's own default and what a server with no Match
-- uses anyway.
local function askTarget(instance: Instance?): Rules.Target?
	if targetProvider == nil then
		return nil
	end
	local ok, target = pcall(targetProvider :: any, instance)
	return if ok and type(target) == "table" then target else nil
end

local function askStand(player: Player): Rules.StandArea?
	if standProvider == nil then
		return nil
	end
	local ok, area = pcall(standProvider :: any, player)
	return if ok and type(area) == "table" then area else nil
end

local function askDriveOpen(player: Player?): boolean?
	if driveOpenProvider == nil then
		return nil
	end
	local ok, open = pcall(driveOpenProvider :: any, player)
	-- A PROVIDER THAT THREW SAYS NOTHING, not "closed": the same call `askStand` and `askTarget`
	-- make, and the stronger one here -- a drive whose predicate errored must not leave every hunter
	-- in the wood clicking a dead trigger with one line on screen blaming the drive.
	return if ok and type(open) == "boolean" then open else nil
end

-- THE SAFETY LOCK, THROUGH A pcall LIKE EVERY OTHER PROVIDER HERE (task 248), and the fallback is
-- the same one: nil, which `Rules.unsafeLine` reads as no restriction. A drive whose geometry threw
-- must not leave every hunter in the wood clicking a dead trigger -- `askDriveOpen`'s own reason,
-- and the stronger one here, because this provider is asked on every single trigger pull.
-- WHERE WAS IT? Through a `pcall` like every other provider here, and the fallback is the strongest
-- one in this file: nil, which REFUSES the claim. A provider that errored must not be read as "the
-- client was right" -- the whole point of the rewind is that the server satisfies itself, so no
-- answer means no.
local function askWhereWas(instance: Instance, at: number): CFrame?
	if historyProvider == nil then
		-- UNWIRED IS ITS OWN ANSWER, and it is a different fault from "the provider said no": one is
		-- a composition root that forgot a line, the other is an animal the server cannot place.
		-- They were one `claim-history` until task 266b, which cost a live session to tell apart.
		stats.claimHistoryWhy = "unwired"
		return nil
	end
	local ok, where = pcall(historyProvider :: any, instance, at)
	if not ok then
		-- A PROVIDER THAT THREW IS NOT A PROVIDER THAT REFUSED. `pcall` turning an error into nil is
		-- right -- a diagnostic must not take down the shot resolution -- but silently is not, and
		-- this is the one place that can tell the difference.
		stats.claimHistoryWhy = string.sub(tostring(where), 1, 120)
		return nil
	end
	if typeof(where) ~= "CFrame" then
		stats.claimHistoryWhy = "no-sample"
		return nil
	end
	stats.claimHistoryWhy = "ok"
	return where
end

local function askLineUnsafe(player: Player, muzzle: Vector3, aim: Vector3, stopAt: number): boolean?
	if safetyLineProvider == nil then
		return nil
	end
	local ok, unsafe = pcall(safetyLineProvider :: any, player, muzzle, aim, stopAt)
	return if ok and type(unsafe) == "boolean" then unsafe else nil
end

-- WHAT HE HOLDS, AND -- SINCE TASK 255 -- WHETHER ANYBODY ACTUALLY KNOWS.
--
-- KAREN, 2026-10-24, verbatim: *"I have redstag license but when I aim at the begining popup shows I
-- need license just after while I can shoow need fix"*.
--
-- THE SECOND RETURN IS THE WHOLE FIX, and the reason is three lines of other people's code. This
-- provider is `ShopData.licencesFor(Economy.ownedOf(userId))`; `Economy.ownedOf` answers **nil, not
-- `{}`, for a player with no open profile** and says why in as many words (*"every reader of what
-- ownership GIVES treats nil as 'nobody answered, leave the game as it was'... so a refused session
-- lock or a DataStore outage cannot take away the rifle a man paid for"*); and `Shop.licencesFor`
-- passes that nil straight through, with a comment that `nil` and `{}` *"mean the same thing"* to
-- `Licences.allows`. They do -- and that is exactly the defect: to `Licences.allows` both read as
-- HE HOLDS NOTHING, so between `PlayerAdded` and the store's reply (and for the WHOLE drive when the
-- load is refused or throws -- `Economy.load` warns and retries only *"at the next drive start"*,
-- which is Karen's *"just after a while I can shoot"*) a man who has paid $750 for the red stag card
-- is told `NO DEER LICENCE` and refused the shot.
--
-- SO THIS OWNER ASKS A SECOND QUESTION AND THE RULE SKIPS ITSELF WHEN THE ANSWER IS "I DO NOT KNOW":
--   * NO PROVIDER AT ALL -> `(nil, true)`. There is no ownership in this world: the DEV arena with
--     the shop off, every `tests/server/weapon_*.spec.luau`. Nothing is unknown, because nothing
--     exists to know -- and this world's answer is byte-identical to the one before this task.
--   * A PROVIDER THAT ERRORS OR ANSWERS A NON-TABLE -> `(nil, false)`. This file's own written rule
--     for every provider, which `askOwned` states three lines down: *"a provider that errors must
--     not leave a player permanently unable to shoot"*. The LICENCE provider was the one place that
--     did the opposite.
--   * A TABLE -> `(held, true)`. An OPEN profile that has bought nothing answers a frozen `{}` --
--     `Economy.load` writes `ownedSets[userId] = {}` -- so the popup still fires for the man who
--     really has no card. That is what makes this fix narrow rather than a hole: the only state it
--     changes is the one nobody has an answer for.
local function askLicences(player: Player): ({ [string]: boolean }?, boolean)
	if licenceProvider == nil then
		return nil, true
	end
	local ok, held = pcall(licenceProvider :: any, player)
	if ok and type(held) == "table" then
		return held, true
	end
	stats.licenceUnknown += 1
	return nil, false
end

-- WHAT HE OWNS, THROUGH A pcall, the rule this file already states for every provider: *"a provider
-- that errors must not leave a player permanently unable to shoot AND must not silently remove the
-- rule. It falls back to 'no restriction'"* -- which here is nil, and nil is the gun he has today.
local function askOwned(player: Player): { [string]: boolean }?
	if entitlementProvider == nil then
		return nil
	end
	local ok, owned = pcall(entitlementProvider :: any, player)
	return if ok and type(owned) == "table" then owned else nil
end

-- WHAT THIS PLAYER'S COPY OF THIS WEAPON STARTS WITH: his allowance, or the weapon's own row when
-- nobody has said. One call, in one place, so `grant`, `revoke` and `refillForDrive` cannot disagree
-- about what he may carry.
local function startFor(
	player: Player,
	row: any
): { ammo: string?, reserve: { [string]: number }?, unlimited: { [string]: boolean }? }?
	local owned = askOwned(player)
	if owned == nil then
		return nil
	end
	return Shop.startFor(row, owned)
end

-- ...AND IT HANDS BACK THE ONE IT IS REPLACING (task 150), so a caller that needs the policy for the
-- length of one test can put the real one back without knowing who installed it or what it was.
-- `ForestTestBoot` and `MatchBoot` ignore the return and are unchanged.
function Weapon.setArmingPolicy(policy: ((Player) -> boolean)?): ((Player) -> boolean)?
	local previous = armingPolicy
	armingPolicy = policy
	return previous
end

local function mayArm(player: Player): boolean
	if armingPolicy then
		local ok, allowed = pcall(armingPolicy, player)
		-- A policy that errors must not leave a player permanently unarmed AND must not silently
		-- arm everybody: fall back to the weapon's own default, which is what a server with no
		-- Match uses anyway.
		if ok then
			return allowed == true
		end
	end
	return CONFIG.shouldArm(player)
end

-- A Tool belongs to whatever it is parented to, and a respawn destroys both: the Backpack it is
-- sitting in AND the character it is equipped on. MEASURED in a two-player drive (Task 34): the
-- drive places players by respawning them (Match.Body.place -> LoadCharacter), the grant lands in
-- the Backpack that respawn is about to replace, and the gun dies with it a frame later. Without
-- this the record outlives the Tool, refreshArming believes the player is armed, and nobody is
-- ever granted anything again -- a Shooter walked a whole ten-minute drive with empty hands.
local function toolsOfPlayer(player: Player): { [string]: Tool }
	local held = tools[player]
	if held == nil then
		held = {}
		tools[player] = held
	end
	return held
end

local function watchTool(player: Player, tool: Tool, id: string)
	-- ONE per weapon per player, replaced at each grant rather than appended: a player who is granted
	-- every few seconds would otherwise leave a dead connection behind every time, for the session.
	local watchers = toolLifeWatchers[player]
	if watchers == nil then
		watchers = {}
		toolLifeWatchers[player] = watchers
	end
	local previous = watchers[id]
	if previous then
		previous:Disconnect()
	end
	watchers[id] = tool.AncestryChanged:Connect(function()
		-- ...AND "LOST" IS NOT ONLY `Parent == nil` (task 144). A respawn DETACHES the old Backpack
		-- -- sets its own Parent to nil -- without destroying it, so a Tool sitting in it keeps a
		-- perfectly non-nil Parent and this handler used to return here for ever. `Weapon.reachable`
		-- asks the question that matters instead: can the PLAYER get at it.
		if Weapon.reachable(tool, player) then
			return -- equipping moves it Backpack -> Character; that is not losing it
		end
		if toolsOfPlayer(player)[id] == tool then
			toolsOfPlayer(player)[id] = nil
		end
	end)
end

-- CAN THE PLAYER ACTUALLY GET AT THIS TOOL? PURE, and public so a spec can drive the one shape no
-- session reproduces on demand (task 144).
--
-- "HAS A PARENT" IS NOT THE SAME QUESTION, AND THE DIFFERENCE COST A HUNTER HIS SHOTGUN. Measured in
-- the Forest Test, 10 double-deaths: die once, then again inside `AUTO_EQUIP_DELAY_SECONDS`, and the
-- player comes back with `bag=[Rifle,RifleOpen]` and EMPTY HANDS (that trace is from task 144,
-- when the loadout still had the open-sighted rifle in it) -- and stays that way through the
-- next respawn and the one after. A census of the whole DataModel found only TWO of our Tools: the
-- shotgun was not under `game` at all. That is the shape. A respawn DETACHES the old Backpack --
-- `Parent = nil` on the Backpack, which takes it out of the tree -- but does not DESTROY it, so the
-- Tool inside keeps a non-nil Parent indefinitely. The old rule read that as "he is holding it", the
-- grant was skipped, and `watchTool`'s `Parent ~= nil` guard meant the record was never cleared
-- either. Nothing re-granted until the engine got round to destroying the detached Backpack, which
-- is why Task 141 saw it only in a long session and could not reproduce it on a fresh one.
--
-- THE LIVE CONTAINERS ARE THE ANSWER, and they are the same two `Hardware.toolsOf` already walks:
-- the Backpack the player has NOW and the character they are wearing NOW. Nothing else can be
-- reached, whatever its Parent says.
function Weapon.reachable(tool: Instance?, player: Player): boolean
	if tool == nil then
		return false
	end
	local parent = (tool :: Instance).Parent
	if parent == nil then
		return false
	end
	return parent == player:FindFirstChildOfClass("Backpack") or parent == player.Character
end

-- Does this player HOLD a gun, rather than: is one recorded against their name? A Tool goes with
-- the character it is equipped on, so a respawn -- which the drive performs on every placement --
-- destroys it, and a Tool that never reached a Backpack is parented to nil from the start. Since
-- task 144 it also goes with a Backpack that was merely DETACHED. Every one of those is a stale
-- record, and believing it leaves the player unarmed with nothing ever re-granting (Task 34).
--
-- THE RECORD IS CORRECTED ON EVERY READ, which is what makes the arming sweep a repair rather than
-- a re-statement of the same wrong answer: drop it here and the next `armingAction` says "grant".
local function holdsTool(player: Player, id: string): boolean
	local tool = toolsOfPlayer(player)[id]
	if tool == nil then
		return false
	end
	if not Weapon.reachable(tool, player) then
		toolsOfPlayer(player)[id] = nil
		return false
	end
	return true
end

-- The whole arming decision, as a pure function of the two facts it depends on. Exported so it can
-- be asserted without taking a live player's gun away: a spec that did that broke three client
-- specs, which were right to complain (Task 34).
function Weapon.armingAction(allowed: boolean, holding: boolean): string?
	if allowed and not holding then
		return "grant"
	elseif not allowed and holding then
		return "revoke"
	end
	return nil
end

-- Re-evaluate now, and grant or revoke to match. The drive calls this when a team is assigned after
-- the character already spawned -- the join-mid-drive race -- and the weapon still does the writing.
-- ...FOR EVERY WEAPON IN THE LOADOUT (task 140). `armingAction` stays pure and per weapon: a
-- hunter either carries this gun or does not, and the rifle is simply a second answer to the same
-- question. With the `RIFLE` flag off the loadout is one weapon and this is what it always was.
-- MUST THE PRIMARY'S EQUIP WAIT FOR THE ENGINE'S OWN BACKPACK GUI? PURE, public, and a function
-- of the loadout alone -- which is what makes both answers reachable in a spec while the `RIFLE`
-- flag sits at one of them (CLAUDE.md, feature flags: "a flagged path must be reachable by
-- parameter as well as by flag, or its two states cannot be tested").
--
-- ONLY WHEN MORE THAN ONE TOOL IS HANDED OVER. The hotbar bug needs two: the GUI numbers a slot the
-- first time it sees a Tool, so equipping inside the grant hides the shotgun from it and the rifle
-- takes slot 1. With ONE weapon there is no order to get wrong, and a spawn in the shipped build is
-- then bit-for-bit what it was before the rifle existed -- no half second of empty hands for a bug
-- that cannot happen (the Reviewer's note, round 1).
function Weapon.equipDelayFor(wanted: { string }): number
	return if #wanted > 1 then CONFIG.AUTO_EQUIP_DELAY_SECONDS else 0
end

-- `wanted` IS A PARAMETER WITH A DEFAULT (task 141, the Reviewer's note round 2), and it is the
-- same medicine as `Weapon.equipDelayFor` one level up: the flag's two worlds must both be
-- reachable without the flag, or the ORDER this function exists to get right can only be tested in
-- whichever world the gate happens to run in. Production passes nothing and gets `Weapons.loadout()`
-- -- the one flag read in the whole weapon system, still at that one boundary.
function Weapon.refreshArming(player: Player, loadout: { string }?)
	local allowed = mayArm(player)
	-- WHAT HE MAY CARRY AT ALL: the flag's list, narrowed by what he has bought (task 178).
	-- `loadout` stays a PARAMETER with a default, which is what task 141 added it for -- *"the flag's
	-- two worlds must both be reachable without the flag"* -- and the ownership read is the
	-- production default beside it.
	local wanted = loadout or Weapons.loadout(askOwned(player))
	-- IN `Weapons.ORDER`, AND THE ORDER IS THE HOTBAR (task 141): see `Weapon.grant`. The engine
	-- numbers a Backpack slot by the order the Tool arrives, so granting in order IS the fix, and it
	-- only works because nothing equips in the middle of this loop any more.
	local granted = 0
	for _, id in ipairs(wanted) do
		local action = Weapon.armingAction(allowed, holdsTool(player, id))
		if action == "grant" then
			if Weapon.grant(player, id) ~= nil then
				granted += 1
			end
		elseif action == "revoke" then
			Weapon.revoke(player, id)
		end
	end
	-- THE PRIMARY GOES IN THE HAND, ONCE THE WHOLE LOADOUT IS IN THE BAG -- and only when this pass
	-- actually handed something over and the player is holding nothing. The narrow rule is
	-- deliberate, and it is the same one `Weapon.upgradeLook` follows: `AUTO_EQUIP` is about the
	-- GRANT, so a sweep must never take the rifle out of the hands of a player who chose it, and
	-- must never undo a holster.
	if CONFIG.AUTO_EQUIP and granted > 0 and Weapon.heldId(player) == nil then
		local primary = toolsOfPlayer(player)[Weapons.PRIMARY]
		if primary ~= nil then
			local delay = Weapon.equipDelayFor(wanted)
			if delay <= 0 then
				-- ONE WEAPON: no hotbar order to protect, so the spawn is exactly what it was.
				Hardware.equip(primary, player)
			else
				-- NOT IN THIS FRAME: see `Weapon.equipDelayFor` and
				-- `Shotgun.CONFIG.AUTO_EQUIP_DELAY_SECONDS`. The guards are re-read when the delay
				-- fires rather than captured: a player who picked up the rifle, holstered, died or
				-- left in that half second must not have a shotgun pushed into their hands, and the
				-- Tool itself may be gone by then.
				task.delay(delay, function()
					if primary.Parent == nil or toolsOfPlayer(player)[Weapons.PRIMARY] ~= primary then
						return
					end
					if Weapon.heldId(player) ~= nil then
						return
					end
					Hardware.equip(primary, player)
				end)
			end
		end
	end
	-- ...AND ANY WEAPON THAT IS NO LONGER IN IT GOES. Turning the flag off mid-session must take the
	-- rifle away rather than leave an unreachable Tool in the Backpack.
	for _, id in ipairs(Weapons.ids()) do
		local inLoadout = false
		for _, want in ipairs(wanted) do
			if want == id then
				inLoadout = true
				break
			end
		end
		if not inLoadout and holdsTool(player, id) then
			Weapon.revoke(player, id)
		end
	end
end

-- HOW MANY LIVE ROUNDS ARE IN THE GUN. PURE and public: the owner asks it to decide whether an
-- empty rifle should change its own magazine, and a spec asks it without a session (task 142).
function Weapon.roundsLeft(state): number
	local live = 0
	for _, chamber in ipairs(state.barrels) do
		if chamber == "Live" then
			live += 1
		end
	end
	return live
end

-- WHAT THE CLAIM GATE HAS DONE, AS ONE LINE OF TEXT A PROBE CAN READ (task 266b item 1).
--
-- **THE PROBLEM IT SOLVES, measured by losing three attempts to it in task 266.** The counters above
-- are module state, and `studio_mcp`'s Luau channel gets a **fresh module cache** (memory:
-- `studio-mcp-execute-luau-single-line`), so a probe that requires `Weapon` reads a `Weapon` that has
-- never seen a player: every counter zero, whatever the live server has done. So the one question
-- this whole feature turns on -- *did the server ACCEPT the claim?* -- could not be asked at all, and
-- task 266 had to answer it by inference three times and failed each time. The Reviewer's own
-- round-3 note: *"The accepted path has never executed, anywhere."*
--
-- PURE, AND EXPORTED SEPARATELY FROM THE WRITE, so the formatting is testable with no world and no
-- attribute: `weapon_shot.spec` drives it with a hand-written table.
--
-- THE REASONS ARE SORTED, so two runs of the same server produce the same string and a diff between
-- them is a fact rather than a hash order.
function Weapon.claimLine(from: any): string
	if type(from) ~= "table" then
		return ""
	end
	local reasons = {}
	if type(from.refusedClaimBy) == "table" then
		local worst = if type(from.refusedClaimWorst) == "table" then from.refusedClaimWorst else {}
		for reason, count in pairs(from.refusedClaimBy) do
			-- THE COUNT, AND THEN THE WORST MEASURED VALUE AGAINST ITS BUDGET (task 269b):
			-- `claim-line=4 worst 7.412/2.000` reads as "four of them, and the worst missed a
			-- two-stud budget by seven and a half". A reason with no number keeps its bare count,
			-- which is the honest shape for a type or a NaN refusal.
			local row = worst[reason]
			if type(row) == "table" and type(row.measured) == "number" then
				table.insert(
					reasons,
					string.format(
						"%s=%d worst %.3f/%.3f%s",
						tostring(reason),
						count,
						row.measured,
						row.budget or 0,
						if type(row.note) == "string" then " (" .. row.note .. ")" else ""
					)
				)
			else
				table.insert(reasons, string.format("%s=%d", tostring(reason), count))
			end
		end
		table.sort(reasons)
	end
	return string.format(
		"enabled=%s claims=%d accepted=%d refused=%d ignored=%d worst=%.3f/%.3f/%.3f lag=%.3fs "
			.. "sweep=%d/%d win=%.3fs spread=%.3f passed=%s took=%d best=%d@%.3f segs=%d "
			.. "claimed=%s age=%.3f..%.3f/%d why=%s [%s]",
		tostring(from.claimsEnabled),
		from.claims or 0,
		from.claimsAccepted or 0,
		from.claimsRefused or 0,
		from.claimsIgnored or 0,
		from.claimWorstStuds or 0,
		from.claimWorstLineStuds or 0,
		from.claimWorstEndStuds or 0,
		from.claimWorstLagSeconds or 0,
		from.claimSweepFound or 0,
		from.claimSweepAsked or 0,
		from.claimSweepWindow or 0,
		from.claimSweepSpread or 0,
		tostring(from.claimSweepPassed),
		from.claimSweepIndex or 0,
		from.claimSweepBestIndex or 0,
		from.claimSweepBestLine or 0,
		from.claimSweepSegments or 0,
		tostring(from.claimLastPart),
		from.claimAgeMin or 0,
		from.claimAgeMax or 0,
		from.claimAges or 0,
		tostring(from.claimHistoryWhy),
		table.concat(reasons, " ")
	)
end

-- THE ATTRIBUTE'S NAME, here rather than typed into a probe, so the one in the game and the one in
-- the spec cannot drift.
Weapon.CLAIM_STATS_ATTRIBUTE = "DHClaimStats"

-- WRITTEN ONLY IN STUDIO, and that is not a convention -- `RunService:IsStudio()` is checked here,
-- so a live server never writes it however many shots it resolves. The shape is
-- `Boar.legendaryForced`'s, read the other way round: that one READS a Studio-only attribute, this
-- one WRITES one.
--
-- IT IS NOT A `DHFlag_*` OVERRIDE and it is not read by anything in the game: nothing branches on
-- it, so a stale value cannot change a drive. `tools/studio_mcp.py` refuses a harness run while a
-- flag override is set and cannot see this one -- which is correct, because this one is an OUTPUT.
--
-- `pcall` BECAUSE AN ATTRIBUTE WRITE CAN THROW on a name the engine dislikes, and a diagnostic that
-- can take down the shot resolution is worse than no diagnostic.
--
-- `isStudio` IS A PARAMETER WITH A DEFAULT, for the reason `g` is one all through `Ballistics` and
-- `toleranceStuds` is one in `Validator.checkShot`: **a branch that can only be reached at one value
-- cannot be tested at the other.** A spec runs in Studio, so without this the live-server branch --
-- the one that must write NOTHING -- would be unreachable and could rot silently into a server that
-- writes an attribute on every shot. `nil` is the engine's own answer and is every caller in the
-- game.
function Weapon.publishClaimStats(isStudio: boolean?): boolean
	local studio = if type(isStudio) == "boolean" then isStudio else RunService:IsStudio()
	if not studio then
		return false
	end
	local ok = pcall(function()
		ServerStorage:SetAttribute(Weapon.CLAIM_STATS_ATTRIBUTE, Weapon.claimLine(Weapon.stats()))
	end)
	return ok
end

function Weapon.stats()
	local out = table.clone(stats)
	-- `table.clone` is SHALLOW, so the per-rule tally has to be copied by hand or a caller holds a
	-- reference to the live table and can edit the server's own counters (the rule `StateMachine`'s
	-- `draft` already states for `barrels` and `reserve`).
	out.refusedBy = table.clone(stats.refusedBy)
	-- The same hand copy, for the same reason (task 266).
	out.refusedClaimBy = table.clone(stats.refusedClaimBy)
	-- ...AND ONE LEVEL DEEPER, because each row is itself a table (task 269b): a shallow clone would
	-- hand a caller the live rows and let it edit the server's own diagnostics.
	out.refusedClaimWorst = {}
	for reason, row in pairs(stats.refusedClaimWorst) do
		out.refusedClaimWorst[reason] = table.clone(row)
	end
	-- WHICH ANSWER THE CLAIM GATE IS ACTUALLY GIVING, for the reason `originTolerance` below is
	-- here at all (task 260 round 3's blocking finding): a boundary read into a module local is
	-- invisible from outside, so deleting the wiring would leave the suite green with the feature
	-- silently off. `claimsEnabled` is the resolved answer -- the parameter when one is set,
	-- otherwise the flag -- and `weapon_shot.spec` asserts it on both sides of `setClaimPolicy`.
	out.claimsEnabled = if claimPolicy ~= nil then claimPolicy else CLAIMS_ON
	-- WHICH ORIGIN BOUND THIS SERVER RESOLVED (task 260 round 3, the Reviewer's blocking finding).
	-- `ORIGIN_TOLERANCE_STUDS` is a module local read once at the boundary, so nothing outside this
	-- file could see WHICH of the two rows the shipped build actually chose -- and the Reviewer's
	-- test was the right one: deleting the fourth argument from both `checkShot` call sites left the
	-- whole suite green with the bound silently back at the third-person 15. This field is what
	-- `weapon_shot.spec` asserts against `Shotgun.CONFIG.CAMERA_ORIGIN_TOLERANCE_FIRST_PERSON`, so
	-- the WIRING is pinned and not just the arithmetic.
	out.originTolerance = ORIGIN_TOLERANCE_STUDS
	-- ...AND HOW THE EQUIPS ENDED, which is Hardware's own tally (task 129).
	out.equipNow = Hardware.equipStats.now
	out.equipNoCharacter = Hardware.equipStats.noCharacter
	out.equipDeferred = Hardware.equipStats.deferred
	out.equipLate = Hardware.equipStats.late
	out.equipGaveUp = Hardware.equipStats.gaveUp
	-- ...AND HOW MUCH IS IN THE AIR RIGHT NOW (task 185), which is the leak instrument: a server at
	-- rest must read 0. `casts` is the cost claim's own counter.
	out.inFlight = flight:count()
	out.flightShots = flight:shots()
	out.flightCasts = flight.casts
	return out
end

-- HOW MANY PROJECTILES ARE IN THE AIR, and in how many shots. READ ONLY, and there is deliberately
-- no way to STEP the live flight from outside: the one caller of `flight:advance` is the `Heartbeat`
-- in `Weapon.start` (design 4.3). A second driver would let a spec and the Heartbeat step the same
-- list in the same frame, which is a second writer bought for nothing -- a pure spec makes its own
-- `Flight.new()`, and a live spec waits on this.
function Weapon.flightCount(): number
	return flight:count()
end

function Weapon.flightShots(): number
	return flight:shots()
end

-- Tells ONE player that something of theirs landed. One way, server -> that client only, and it
-- carries no state: the Hud decides what to draw and the weapon never draws anything (rule 3).
--
-- The weapon does not know what a boar is and does not learn here: it sends "hit" because its own
-- cast found a damageable target, and BoarBoot -- the composition root that already knows both
-- systems -- calls this again with "kill" when the BOAR's runtime says the animal died. That is the
-- same direction the damage seam already runs in (design section 6.3), so neither owner grows a
-- reference to the other.
function Weapon.markHit(player: Player, kind: string?, zone: string?)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return -- a spec's stand-in shooter, or a player who left mid-shot
	end
	-- ...AND A PLAYER WHO HAS GONE GETS NOTHING (task 185). A shot now lands up to 0.365 s after the
	-- trigger, so a shooter can leave between the two: the bullet still flies and still hits (it has
	-- left the gun -- design 6.4), but a `FireClient` to a Player no longer in `Players` is
	-- meaningless. `Parent == nil` is how a departed Player reads, and the guard lives here because
	-- this is already the function that guards "a player who left mid-shot".
	if player.Parent == nil then
		return
	end
	local channel = remotes or Shotgun.remotes()
	stats.markers += 1
	channel.HitMarker:FireClient(player, { kind = kind or "hit", zone = zone, at = os.clock() })
end

-- The arming answer this owner actually uses, exposed so a spec can assert the pcall fallback rather
-- than infer it from whether a Tool appeared (TASKS.md 32a(d)). It decides nothing and writes
-- nothing: refreshArming is still the only thing that grants or revokes.
function Weapon.mayArmForTests(player: Player): boolean
	return mayArm(player)
end

function Weapon.trackedPlayers(): number
	return registry:count()
end

-- ONE ENTRY PER PLAYER, HOLDING ONE STATE PER WEAPON (task 140). `Registry` still keys by player
-- and still has one `forget`, which is what defect (c)'s leak assertion reads -- what changed is the
-- VALUE it holds.
type PlayerWeapons = {
	held: string?,
	states: { [string]: WeaponState },
	-- WHICH DRIVE'S SHELLS HE IS CARRYING (task 171). nil means "none yet". It is a drive NUMBER and
	-- not a boolean so that a refill which was missed cannot look done, and so that dying in the
	-- middle of a drive is not a resupply: `Weapon.refillForDrive` is level-triggered on this field,
	-- the discipline `botsRebuiltForDrive` in `Match` already follows.
	refilledForDrive: number?,
}

local function entryOf(player: Player): PlayerWeapons
	local entry = registry:get(player) :: PlayerWeapons?
	if entry == nil then
		entry = { held = nil, states = {}, refilledForDrive = nil }
		registry:set(player, entry)
	end
	return entry :: PlayerWeapons
end

local function stateOf(player: Player, id: string?): WeaponState?
	local entry = registry:get(player) :: PlayerWeapons?
	if entry == nil then
		return nil
	end
	return entry.states[id or entry.held or Weapons.PRIMARY]
end

-- WHICH WEAPON THIS PLAYER IS HOLDING, derived from the Tool's Parent and never stored by anybody
-- else (design 5.2). `watchEquipped`'s `sync()` is its one writer, and it writes `equipped` in the
-- same breath, so the two cannot disagree.
function Weapon.heldId(player: Player): string?
	local entry = registry:get(player) :: PlayerWeapons?
	return if entry then entry.held else nil
end

-- The row of the weapon in the player's hands, or the primary's when their hands are empty: the
-- fire path has to validate against SOMETHING, and a request from a player holding nothing is
-- refused by the reducer's own `not-equipped` a line later.
local function rowOf(player: Player)
	return Weapons.row(Weapon.heldId(player)) or Weapons.ROWS[Weapons.PRIMARY]
end
Weapon.rowOf = rowOf

function Weapon.getSnapshot(player: Player): Shotgun.WeaponSnapshot?
	local id = Weapon.heldId(player) or Weapons.PRIMARY
	local state = stateOf(player, id)
	return if state then Shotgun.snapshot(state, os.clock(), nil, id) else nil
end

-- Publishing is rate-limited per player, so a spammer cannot make the server flood its own client.
-- `bucket` NAMES WHICH BUDGET THIS PUBLISH SPENDS (task 140). nil is the old behaviour: the
-- `state` bucket at `STATE_RATE_LIMIT`, or nothing at all when `force` is set. A switch publishes
-- through the `equip` bucket instead, because the Parent-change publish used to be forced past
-- every limit and a player mashing 1/2 would flood `StateChanged` at input rate.
local function publish(
	player: Player,
	id: string,
	state: WeaponState,
	force: boolean?,
	notice: string?,
	bucket: string?,
	-- The sequence step being run right now (task 142), so the client draws the server's action
	-- instead of inferring it from a state that looks the same for two different steps.
	action: string?,
	-- WHY THE LAST TRIGGER PULL DID NOTHING (task 171), one of `Rules.REASON`. It is on the wire
	-- because the client cannot infer it: a refused shot leaves the state EXACTLY as it was, so the
	-- replica sees a loaded, closed, un-busy gun -- which is also what it sees when nobody pulled
	-- the trigger at all. `CameraBoot` turns it into one dry click; the Hud prints `notice`.
	refused: string?,
	-- WHAT WOULD STOP THE NEXT TRIGGER PULL (task 238), answered because the player AIMED and not
	-- because he fired. A DIFFERENT FIELD FROM `refused` ON PURPOSE: see `WeaponSnapshot.advice`.
	-- Nothing clicks, nothing is spent, and the readout's notice stays empty.
	advice: string?
)
	local now = os.clock()
	if not force or bucket ~= nil then
		local name = bucket or "state"
		local limit = if name == "equip" then CONFIG.EQUIP_RATE_LIMIT else CONFIG.STATE_RATE_LIMIT
		local allowed, next = Limits.allow(registry:bucket(player, name), now, limit)
		registry:setBucket(player, name, next)
		if not allowed then
			return
		end
	end
	local channel = remotes or Shotgun.remotes()
	channel.StateChanged:FireClient(player, Shotgun.snapshot(state, now, notice, id, action, refused, advice))
end

local function setState(player: Player, id: string, state: WeaponState)
	entryOf(player).states[id] = state
end

-- IS THIS PLAYER STILL CARRYING AN EARLIER DRIVE'S SHELLS? PURE, so the whole rule is drivable with
-- two numbers and no drive (task 171).
--
-- A NON-NUMBER DRIVE MEANS NO REFILL, which is the honest answer for a world that has no drive at
-- all: the DEV place with no `Match`, and every weapon spec. Those start full from
-- `StateMachine.initial` and are untouched by this task.
function Weapon.needsRefill(refilledForDrive: number?, driveNumber: any): boolean
	if type(driveNumber) ~= "number" then
		return false
	end
	return refilledForDrive ~= driveNumber
end

-- THE DRIVE'S SHELLS, ONCE PER DRIVE (task 171). KAREN, 2026-10-10: *"default is double barrel
-- shotgun with limited ammon per round"* -- so `START_RESERVE` is a per-DRIVE allowance now
-- (`Shotgun.CONFIG.DRIVE_SHELLS`, 12 of each kind) and something has to put it back.
--
-- LEVEL-TRIGGERED ON THE DRIVE NUMBER, not edge-triggered on a phase: the drive calls this through
-- `world.weapon.refillForDrive` from the same place it refreshes arming, which runs on a transition,
-- on a join, on a tie and on a respawn -- and the number is what makes all of those idempotent. So
-- DYING IN THE MIDDLE OF A DRIVE IS NOT A RESUPPLY, and a player who joins mid-drive still gets his
-- allowance. The discipline `Match`'s own `botsRebuiltForDrive` already follows, for the same reason.
--
-- It returns how many weapons were refilled, so a caller can tell "nothing to do" from "done".
function Weapon.refillForDrive(player: Player, driveNumber: number?): number
	local entry = entryOf(player)
	if not Weapon.needsRefill(entry.refilledForDrive, driveNumber) then
		return 0
	end
	entry.refilledForDrive = driveNumber
	local filled = 0
	-- EVERY WEAPON HE IS TRACKED FOR, each from ITS OWN row: the shotgun's 12 shells and the rifle's
	-- own `START_RESERVE` are different numbers and neither is written here.
	for id, state in pairs(entry.states) do
		local row = Weapons.row(id) or Weapons.ROWS[Weapons.PRIMARY]
		-- HIS ALLOWANCE, PER WEAPON, FROM THAT WEAPON'S OWN ROW (task 178) -- the rule this function
		-- already states: *"the shotgun's 12 shells and the rifle's own `START_RESERVE` are different
		-- numbers and neither is written here"*. nil leaves the row's own pockets, exactly as before.
		local start = startFor(player, row)
		local refilled, reason = StateMachine.apply(
			state,
			-- ...AND HIS UNLIMITED POCKETS, ON THE SAME ACTION (task 221). `Refill` is a server-side
			-- primitive -- `Validator.checkRequest` accepts only "Reload" and "SelectAmmo" over the
			-- wire -- so no client can send one, let alone one carrying an allowance.
			{
				kind = "Refill",
				reserve = if start then start.reserve else nil,
				unlimited = if start then start.unlimited else nil,
			},
			os.clock(),
			row
		)
		if reason == nil then
			setState(player, id, refilled)
			publish(player, id, refilled, true)
			filled += 1
		end
	end
	-- ONLY WHEN SOMETHING WAS REFILLED (the Reviewer's round-1 note). A pass that got past
	-- `needsRefill` but found no tracked weapon -- or whose reducer refused -- is not a refill, and
	-- this counter's own comment says it counts refills.
	if filled > 0 then
		stats.refills += 1
	end
	return filled
end

-- `equipped` is derived from the Tool's Parent, never from a client claim and never from
-- Tool.Equipped on the server (design section 5.4).
local function watchEquipped(player: Player, tool: Tool, id: string)
	local function sync()
		local entry = entryOf(player)
		local state = entry.states[id]
		if not state then
			return
		end
		local equipped = tool.Parent ~= nil and tool.Parent == player.Character
		-- ...AND WHICH WEAPON IS IN THE HAND, written by the same function in the same frame (task
		-- 140, design 5.2). Two fields that cannot disagree, because one `sync()` writes both.
		if equipped then
			entry.held = id
		elseif entry.held == id then
			entry.held = nil
		end
		local next = StateMachine.setEquipped(state, equipped)
		if next ~= state then
			setState(player, id, next)
			-- THROUGH THE `equip` BUCKET rather than forced: see `publish`.
			publish(player, id, next, true, nil, "equip")
		end
	end
	-- One watcher per weapon per player: grant() runs again on every respawn, and the old Tool's
	-- connection would otherwise live until the player left (round 1 note).
	local watchers = toolWatchers[player]
	if watchers == nil then
		watchers = {}
		toolWatchers[player] = watchers
	end
	local previous = watchers[id]
	if previous then
		previous:Disconnect()
	end
	watchers[id] = tool:GetPropertyChangedSignal("Parent"):Connect(sync)
	sync()
end

-- `id` IS WHICH WEAPON (task 140); nil is the primary, which is what every caller written before
-- the rifle means.
function Weapon.grant(player: Player, id: string?): Tool?
	local weaponId = id or Weapons.PRIMARY
	local row = Weapons.row(weaponId)
	if row == nil then
		return nil
	end
	Hardware.destroy(toolsOfPlayer(player)[weaponId])
	local previous = stateOf(player, weaponId)
	-- HIS OWN SHELLS (task 178): buckshot only until he has bought the slug, and the weapon's own
	-- row when there is no shop in this build.
	local state = StateMachine.initial(row, startFor(player, row))
	if previous then
		local bumped = table.clone(state) :: any
		bumped.epoch = previous.epoch + 1
		state = Shotgun.deepFreeze(bumped)
	end
	setState(player, weaponId, state)

	-- ONE TOOL PER PLAYER, enforced. A stray Shotgun -- one this owner lost track of, or one a
	-- caller produced while an older grant was in flight -- would survive a revoke, because revoke
	-- destroys the RECORDED tool. Nothing between build and the record below yields, so no second
	-- grant can start inside this one.
	for _, stray in Hardware.toolsOf(player, weaponId) do
		Hardware.destroy(stray)
	end

	local tool = Hardware.build(row)
	connections[player] = connections[player] or {}
	if not Hardware.give(tool, player) then
		-- No Backpack at this instant: the character is still coming, or the player is leaving.
		-- Record NOTHING and return nil, so the next refreshArming tries again instead of counting
		-- a tool that is parented to nil (Task 34: that is what left a two-player drive's shooter
		-- without a gun). The Backpack hook in watchPlayer fires when it does arrive.
		Hardware.destroy(tool)
		stats.grantsMissed += 1
		return nil
	end
	toolsOfPlayer(player)[weaponId] = tool
	watchTool(player, tool, weaponId)
	watchEquipped(player, tool, weaponId)
	-- THE EQUIP IS NOT HERE ANY MORE (task 141), and that is the whole of the hotbar-order bug.
	-- Measured by the Director in the Forest Test: the hotbar read `1 Rifle, 2 Shotgun`, against the
	-- design and against Karen's own words. The engine's Backpack numbers its slots in the order
	-- Tools ARRIVE in it, and this equipped the shotgun the instant it was granted -- which moved it
	-- OUT of the Backpack before the rifle was ever put in. So the rifle arrived into an empty
	-- Backpack and took slot 1, and the shotgun came back to slot 2 the first time it was holstered.
	--
	-- `Weapon.refreshArming` grants the whole loadout in `Weapons.ORDER` and equips the primary
	-- AFTERWARDS, so both Tools reach the Backpack in order and the hotbar is the order of the list.
	stats.granted += 1
	publish(player, weaponId, stateOf(player, weaponId) :: WeaponState, true)
	return tool
end

-- EVERY GUN'S LOOK BROUGHT UP TO DATE, AND EVERY ONE OF THEM BACK IN ITS HAND (task 123 round 9).
--
-- KAREN, playing: *"There is no weapon something is broken"*. Measured in her session, in this
-- order: the barrels template was missing when the gun was built, the handle mesh landed at 416 ms,
-- the barrels at 2096 ms, and then "upgraded 1 gun(s)". The upgrade put the mesh on and left the
-- Tool in the BACKPACK, so she stood at the stand with empty hands.
--
-- IT IS A RACE, NOT A FOREST-TEST FACT: `WeaponBoot` starts the weapon system BEFORE the preload
-- finishes, deliberately (task 74, review round 1: a stalled `LoadAsset` must not mean a gunless
-- player), so any place whose barrels asset is slow on the day hits it -- DEV included. This is the
-- one path both callers use, so both are fixed by it.
--
-- RE-EQUIPPED ONLY ON THE FRAME THE LOOK CHANGED, which is the narrow rule on purpose: a sweep that
-- re-equipped every tick would make putting the gun away impossible, and `AUTO_EQUIP` is about the
-- grant, not about overriding a player who holstered.
function Weapon.upgradeLook(): number
	return Hardware.upgradeAll(function(player: Player, tool: Tool)
		if not CONFIG.AUTO_EQUIP then
			return
		end
		local character = player.Character
		if character == nil or tool.Parent == character then
			return
		end
		-- ...AND ONLY THE WEAPON THE PLAYER IS ACTUALLY CARRYING IN THEIR HANDS (task 140). With two
		-- Tools this sweep would otherwise put BOTH in the character -- whichever upgraded last
		-- winning -- and a player who picked the shotgun would find a rifle in their hands when a
		-- mesh landed. MEASURED in the first live session of this task: the rifle ended up equipped
		-- at the spawn, against `AUTO_EQUIP`'s own rule that the PRIMARY is what goes in the hand.
		--
		-- The rule is the narrow one: re-equip the weapon that was already held, and when the
		-- player holds nothing, only the primary.
		local id = Weapons.idForToolName(tool.Name)
		local held = Weapon.heldId(player)
		if id ~= (held or Weapons.PRIMARY) then
			return
		end
		Hardware.equip(tool, player)
	end)
end

-- `id` IS WHICH WEAPON; **nil is every weapon**, which is what `Match` means when it takes a
-- player's gun away at a tie and is therefore the behaviour that must not change (task 140).
function Weapon.revoke(player: Player, id: string?)
	if id == nil then
		for _, each in ipairs(Weapons.ids()) do
			Weapon.revoke(player, each)
		end
		return
	end
	local weaponId = id
	local row = Weapons.row(weaponId)
	if row == nil then
		return
	end
	Hardware.destroy(toolsOfPlayer(player)[weaponId])
	toolsOfPlayer(player)[weaponId] = nil
	local previous = stateOf(player, weaponId)
	if previous then
		local state = table.clone(StateMachine.initial(row, startFor(player, row))) :: any
		state.epoch = previous.epoch + 1
		local reset = Shotgun.deepFreeze(state)
		setState(player, weaponId, reset)
		stats.revoked += 1
		-- AND TELL THE CLIENT (TASKS.md 35b(a)). Resetting the state without publishing it left the
		-- replica holding the snapshot from before the gun was taken, so a player tied to a tree
		-- kept an ammo readout on screen for a gun that no longer exists -- visible in
		-- .screenshots/task35-tied-to-a-tree.png. grant() publishes; revoke has to as well, or the
		-- two halves of the same owner disagree about what the player is holding.
		publish(player, weaponId, reset, true)
	end
end

-- After this, NO table in this system is keyed by that player. That is defect (c), and
-- weapon_state.spec asserts it through Registry:count().
function Weapon.forget(player: Player)
	Weapon.revoke(player)
	registry:forget(player)
	for _, watcher in pairs(toolWatchers[player] or {}) do
		watcher:Disconnect()
	end
	toolWatchers[player] = nil
	for _, watcher in pairs(toolLifeWatchers[player] or {}) do
		watcher:Disconnect()
	end
	toolLifeWatchers[player] = nil
	tools[player] = nil
	for _, connection in ipairs(connections[player] or {}) do
		connection:Disconnect()
	end
	connections[player] = nil
end

-- HOW MUCH LAG THIS SHOT OWES ITS SHOOTER, in seconds (task 256).
--
-- KAREN, 2026-10-24: *"we need to aim ahead to hit animal when running"* / *"it seems there is a bit
-- off"*. The player aimed at the animal his client drew one trip ago; the server resolves the shot
-- against where that animal is one trip later. MEASURED (research note section 5.3): at 60 ms one
-- way a boar at `SPRINT_SPEED` wants 64 cm of lead ON TOP of the true 91 cm at 60 m. So without this
-- the lead a player must learn is the real lead plus his own ping, which is not a real-life feeling.
--
-- PURE EXCEPT FOR THE ONE READ IT EXISTS TO MAKE, and `ping` is a PARAMETER with a default for the
-- reason `Weapon.equipDelayFor` and `Ballistics.dropAt` already state: a number that can only be
-- read at one value cannot be tested at another -- and this one reads 1-2 ms on a loopback Studio
-- session (measured, task 256 round 2), so a spec that could not supply its own could not reach this
-- function's interesting half at all.
--
-- `Player:GetNetworkPing()` IS THE ONLY LATENCY A SERVER CAN HAVE WITHOUT A PROTOCOL OF OUR OWN, and
-- it is unspoofable here precisely because the client never sends it. Its units are the uncertain
-- part -- the docs say only *"the network ping in seconds"* -- which is why the conversion is
-- `FLIGHT_CATCHUP_PING_FACTOR`, a row, and not a literal here.
--
-- A NEGATIVE, A NAN OR A MISSING PING IS ZERO, never a fallback guess: 0 is exactly today's
-- behaviour, so the failure mode of this whole feature is "the game shoots as it did yesterday".
-- `Flight.launch` clamps the upper end again, at the one door into that module.
-- HOW FAR BACK THIS SERVER WILL LOOK FOR THIS SHOOTER'S OWN PICTURE, in seconds (task 271,
-- design 4.4). **THE SHAPE IS `Weapon.catchUpFor`'s, line for line and deliberately**: `ping` is a
-- PARAMETER with a `GetNetworkPing` fallback inside a `pcall`, a negative or a NaN contributes ZERO
-- rather than a guess, and the result is clamped at one named ceiling. A number that can only be
-- read at one value cannot be tested at another, and a loopback Studio session reads 1-2 ms
-- (measured, task 256 round 2), so a spec that could not supply its own ping could not reach this
-- function's interesting half at all.
--
-- IT REUSES `FLIGHT_CATCHUP_PING_FACTOR` and does not add a second one.
-- THE WINDOW, OVERRIDDEN BY A SPEC AND BY NOTHING ELSE (round 1's finding 1). `judgeClaimFor`
-- reads `CONFIG.CLAIM` directly and asks `viewWindowFor` with no config, so without this seam no
-- case could set the window to 0 -- and design 3.4's own claim is that
-- `VIEW_LAG_BASE_SECONDS = 0` reproduces v3's single-instant check exactly. A claim about a dial
-- nothing can turn is not a claim. `nil` restores the configured answer, which is every caller in
-- the game; the shape is `Weapon.setClaimPolicy`'s.
local viewWindowOverride: number? = nil

function Weapon.setViewWindow(seconds: number?): number?
	local was = viewWindowOverride
	viewWindowOverride = if type(seconds) == "number" and seconds >= 0 then seconds else nil
	return was
end

function Weapon.viewWindowFor(player: Player?, ping: number?, config: any?): number
	if viewWindowOverride ~= nil then
		return viewWindowOverride
	end
	local cfg = config or CONFIG
	local seconds = ping
	if seconds == nil then
		local ok, measured = pcall(function()
			return (player :: any):GetNetworkPing()
		end)
		seconds = if ok and type(measured) == "number" then measured else 0
	end
	if type(seconds) ~= "number" or seconds ~= seconds or seconds <= 0 then
		seconds = 0
	end
	return math.clamp(
		cfg.CLAIM.VIEW_LAG_BASE_SECONDS + seconds * cfg.FLIGHT_CATCHUP_PING_FACTOR,
		0,
		cfg.CLAIM.VIEW_LAG_MAX_SECONDS
	)
end

function Weapon.catchUpFor(player: Player?, ping: number?, config: any?): number
	local seconds = ping
	if seconds == nil then
		local ok, measured = pcall(function()
			return (player :: any):GetNetworkPing()
		end)
		seconds = if ok and type(measured) == "number" then measured else 0
	end
	-- `seconds ~= seconds` is the NaN test: a NaN survives `math.clamp` and would poison every
	-- projectile's `elapsed` for the life of the server.
	if type(seconds) ~= "number" or seconds ~= seconds or seconds <= 0 then
		return 0
	end
	local cfg = config or CONFIG
	return math.clamp(seconds * cfg.FLIGHT_CATCHUP_PING_FACTOR, 0, cfg.FLIGHT_CATCHUP_MAX_SECONDS)
end

local function rootPositionOf(player: Player): Vector3?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return root.Position
end

-- The ignore list for one shot: the shooter's character (which contains the equipped Tool, so the
-- gun's own Handle goes with it), plus the client effects folder IF one exists server-side, which
-- normally it does not -- client-created Instances do not replicate up (design section 2.3 item 7).
--
-- WHAT THIS SHOOTER'S SHOT MUST NOT SEE (task 306 B5). The EIGHTH injected provider on this owner,
-- in the shape the seven have: UNWIRED MEANS NIL, AND NIL IS TODAY'S GAME -- nothing is appended and
-- every `tests/server/weapon_*.spec.luau` is bit-for-bit unchanged.
-- Note: docs/design/shooting-range-lobby.md section 4.3
local ignoreProvider: ((Player, number?) -> { Instance }?)? = nil

function Weapon.setIgnoreProvider(provider: ((Player, number?) -> { Instance }?)?)
	ignoreProvider = provider
end

local function ignoreFor(player: Player, rewindSeconds: number?): { Instance }
	local ignore: { Instance } = {}
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local effects = Workspace:FindFirstChild("WeaponEffects")
	if effects then
		table.insert(ignore, effects)
	end
	-- `rewindSeconds` is the SAME number the shot carries, so the answer is measured at the instant
	-- the rewind tests and not at one nobody shot at. A provider that throws does not refuse the
	-- shot: the list is the shooter's own character and the effects folder, which is today's game.
	local provider = ignoreProvider
	if provider ~= nil then
		local ok, extra = pcall(provider, player, rewindSeconds)
		if ok and type(extra) == "table" then
			for _, instance in ipairs(extra :: { Instance }) do
				if typeof(instance) == "Instance" then
					table.insert(ignore, instance)
				end
			end
		end
	end
	return ignore
end

-- WHAT IS IN FRONT OF THE GUN: ONE RAY, ONE IMPLEMENTATION, TWO CALLERS (task 238).
--
-- The trigger (`onFireRequest`) and the aim question (`onActionRequest`'s `"Aim"` branch -- there is
-- no `onAimRequest`; the Reviewer caught this comment naming one) both ask this and nothing
-- else, which is the whole of how task 238 avoided *"a second targeting path"*. Before it there was
-- exactly one cast in the game and it lived inline in the fire flow; the popup needed the same
-- answer at a different moment, and a client-side ray would have been a second answer to "what is
-- the player looking at" -- `docs/PROJECT_CONTEXT.md`'s named failure (*"Two systems wrote the
-- creature's position"*).
--
-- IT RETURNS BOTH, because the two callers need different halves of one cast: the trigger needs the
-- IMPACT (its position is where the shot is aimed, `Hits` groups off it), and both need the TARGET
-- (`askTarget`, the provider `Boar` installs, which is what knows a species from an Instance).
-- Returning the target alone would make the fire path cast twice.
--
-- Note: docs/research/2026-10-22-licence-popup-and-robux.md section 3.1
local function lookAhead(
	player: Player,
	origin: Vector3,
	direction: Vector3,
	range: number
): (Rules.Target?, Shotgun.Impact?)
	local impact = castFn(origin, direction * range, ignoreFor(player))
	return askTarget(if impact then impact.instance else nil), impact
end

-- The whole server flow for one FireRequest (design section 5.5).
--
-- IT RETURNS ITS OWN DECISION (Task 80, round 2): nil when the shot was taken, otherwise the reason
-- it was not. `OnServerEvent:Connect` discards the return, so nothing about the game changes -- but a
-- caller now gets a per-call answer instead of having to infer one from a counter. That distinction
-- cost a two-player run: the first version of the handler spec asserted `stats.shots` had not moved
-- across its own window, and `stats` is ONE module-level table for the whole server, so the shooter's
-- legitimate replayed click landed in the spec's numbers and read as a forged request being accepted.
-- A return value belongs to one call and one player and cannot be raced by anybody.
-- FORWARD: the fire path starts the bolt and the sequence runner is defined below, so the name has
-- to exist first. `local` here and `function runCycle` below means the assignment lands on THIS
-- local rather than creating a global.
local runCycle

-- WHEN A SHOT ARRIVES (task 185). One `Resolution` per shot whose LAST projectile has resolved, so
-- today's contract is preserved exactly: nine buckshot pellets on one boar is ONE `HitReport` with
-- `pellets = 9`, never nine reports as they land. `HitLog`, `Match`, `ForestTest` and the hit marker
-- all depend on that and none of them changes.
--
-- `Hits.group` IS STILL THE ONE CONSTRUCTOR OF A `HitReport`, and it is given the SHOT's time
-- (`firedAt`), not the arrival's -- see the comment on `firedAt` at the launch.
--
-- THE MARKER ARRIVES WHEN THE BULLET DOES, which is correct: the tick is the confirmation that
-- something was hit, and it was not hit yet.
-- WHETHER TO BELIEVE THE SHOOTER'S OWN PICTURE OF THIS SHOT (task 266), and the one place the
-- facts for it are gathered. It returns the impact list the report should be built from: the
-- claim's single impact when the claim is believed, and `res.impacts` -- today's answer, bit for
-- bit -- in every other case.
--
-- IT IS JUDGED AT THE RESOLUTION AND NOT AT THE TRIGGER, which is the design's own reason and worth
-- restating here: the claimed arrival is `firedAtView + flightSeconds`, which at the trigger is
-- still in the server's FUTURE whenever the flight is longer than the upward trip -- the usual case.
-- By the time the bullet lands it is in the past by exactly that trip, and the Boar's ring covers
-- it. **THE SHOT IN THE AIR IS THE PENDING QUEUE** (design 5.1).
--
-- A REFUSED CLAIM'S SHOT RESOLVES EXACTLY AS IT DOES TODAY, from the flight's own impacts. Not a
-- forced miss and not a silent nothing, and the reason is in design 5.3: if a refusal were a miss,
-- corrupting or withholding a claim would be a way to DENY damage and every honest player on a bad
-- connection would lose hits he can see; if a refusal were a hit, the checks would be decoration.
--
-- Design: docs/design/ballistics.md (sections 5.2, 5.3)
local function judgeClaimFor(res: Flight.Resolution): { Shotgun.Impact }
	local shot = res.shot
	local claim = shot.claim
	if claim == nil then
		return res.impacts
	end
	stats.claims += 1
	local enabled = if claimPolicy ~= nil then claimPolicy else CLAIMS_ON
	if not enabled then
		stats.claimsIgnored += 1
		return res.impacts
	end

	-- THE MEASURED VALUE AND ITS BUDGET GO IN HERE, which is the one place every refusal passes
	-- through (task 269b). `measured`/`budget` are `Validator.judgeClaim`'s own third and fourth
	-- returns, in the rule's own unit; `note` is the part of the cause that is an Instance and so
	-- cannot come from that pure module. The WORST is kept per reason, so one lucky shot cannot
	-- hide the shape of the failure.
	local function refuse(reason: string, measured: number?, budget: number?, note: string?): { Shotgun.Impact }
		stats.claimsRefused += 1
		stats.refusedClaimBy[reason] = (stats.refusedClaimBy[reason] or 0) + 1
		if type(measured) == "number" then
			local row = stats.refusedClaimWorst[reason]
			if row == nil or measured > row.measured then
				stats.refusedClaimWorst[reason] =
					{ measured = measured, budget = if type(budget) == "number" then budget else 0, note = note }
			end
		end
		return res.impacts
	end

	-- THE CLAIMED PART MUST BELONG TO A LIVE ANIMAL THE SERVER KNOWS. `Hits.targetOf` is the one
	-- reader of `Damageable`, which only the animal's own owner writes -- so a part the client
	-- invented, or any other instance in the world, dies here.
	local target = Hits.targetOf(claim.part)
	if target == nil then
		return refuse("claim-part")
	end
	local part = claim.part :: BasePart
	if not part:IsA("BasePart") then
		return refuse("claim-part")
	end
	-- WHICH PART THE CLIENT ACTUALLY CLAIMED, and what zone that part carries (task 274). Recorded
	-- for EVERY claim that gets this far -- accepted or refused -- because the question it answers
	-- is about the CLIENT's own simulation and does not wait on the server's verdict.
	--
	-- **IT IS THE ONE FIELD THAT MOVES THIS INVESTIGATION.** An accepted claim already decides the
	-- zone (`Validator.claimImpact` sets `instance = claim.part`; `Hits.group` reads that part's
	-- `HitZone`), so task 272's live zones -- Terrain, legs, body on a trial with three ACCEPTED
	-- claims -- had two possible explanations and no way to tell them apart.
	--
	-- **AND RECORDING IT FOR EVERY CLAIM RATHER THAN THE ACCEPTED ONES IS THE WHOLE POINT, because
	-- the two readings disagree.** An earlier version of this field wrote only on acceptance and
	-- read `ZoneRear(rear)` and the trunk -- which says *the client is claiming the rear*. Written
	-- here, for every claim, it reads **`ZoneChest(chest)` on every claim of the same trial** with
	-- the sight settled under 0.6 degrees on the chest. The client claims the chest; it is the
	-- CHEST claims that are refused, and the rear ones are what survived to be accepted. A field
	-- that only records the survivors measures the filter, not the thing.
	local claimedZone = part:GetAttribute("HitZone")
	stats.claimLastPart =
		string.format("%s(%s)", part.Name, if type(claimedZone) == "string" then claimedZone else tostring(claimedZone))

	-- WHERE WAS IT WHEN THE SHOOTER SAW IT. The arrival instant is DERIVED and never sent, so there
	-- is one fewer number for a client to lie about independently.
	local arrivalAt = claim.firedAtView + claim.flightSeconds
	-- MEASURED BEFORE THE LOOKUP, so a refusal still leaves the number behind.
	local age = Workspace:GetServerTimeNow() - arrivalAt
	if stats.claimAges == 0 then
		stats.claimAgeMin, stats.claimAgeMax = age, age
	else
		stats.claimAgeMin = math.min(stats.claimAgeMin, age)
		stats.claimAgeMax = math.max(stats.claimAgeMax, age)
	end
	stats.claimAges += 1
	-- ONE LOOKUP, AT THE CLAIM'S OWN ARRIVAL INSTANT -- `docs/design/ballistics.md` section 5.2,
	-- unchanged.
	--
	-- **ROUND 1 OF TASK 269b PUT A BACKWARD SEARCH HERE AND THE REVIEWER WAS RIGHT TO REFUSE IT.**
	-- It kept, from thirteen instants across 0.25 s, the one minimising
	-- `|where * claim.offset - claim.point|` -- which is the SAME EXPRESSION check 3 tests
	-- (`|clientPoint - serverPoint|`). So it did not leave the checks alone: it widened check 3 from
	-- one instant to the best of thirteen, i.e. to "the animal was within 6 studs of the claimed
	-- point at ANY time in a quarter second", which at the 34 studs/s measured is 8.5 studs of path.
	-- It also made `claim-future` unreachable -- the loop simply stepped back until an instant at or
	-- before the present answered -- so a client could put `firedAtView` ahead of the server clock
	-- and be judged instead of refused.
	--
	-- AND BY ITS OWN MEASUREMENT IT CARRIED NOTHING: `match=0.000s` on every claim of every live
	-- trial, because the best instant was always the arrival instant. A mechanism that loosens a
	-- rule and moves no number is deleted, not defended.
	-- THE SERVER'S OWN TRAJECTORY, WALKED ONCE (task 271, design 4.9). `Ballistics.advance` from
	-- the shot's own bore along its own launch direction, for exactly `claim.flightSeconds`. Walked
	-- once rather than once per candidate: sixteen `advance` calls per claimed shot, not 448.
	local ballistic = Ballistics.shotFor(Weapons.row(shot.weapon or Weapons.PRIMARY), shot.ammo)
	if ballistic == nil then
		return refuse("claim-weapon")
	end
	local bore = shot.bore
	if typeof(bore) ~= "Vector3" then
		-- A RECORD WITH NO BORE cannot have its trajectory re-stepped, so the claim is refused
		-- rather than judged against a guessed direction. Unreachable from `onFireRequest`, which
		-- always sets it; reachable from a hand-built record in a spec, which is why it is a refusal
		-- and not an assert.
		return refuse("claim-weapon")
	end
	local segments = {}
	do
		local position = shot.muzzle
		local velocity = bore * ballistic.v0
		local remaining = claim.flightSeconds
		for _ = 1, CONFIG.CLAIM.MAX_SUBSTEPS do
			if remaining <= 0 then
				break
			end
			local step = math.min(remaining, CONFIG.FLIGHT_STEP_MAX_SECONDS)
			local nextPosition, nextVelocity = Ballistics.advance(position, velocity, step, ballistic)
			table.insert(segments, { from = position, to = nextPosition })
			position, velocity = nextPosition, nextVelocity
			remaining -= step
		end
	end

	-- THE VIEW INSTANT (task 271, design 5.2.1). **MEASURED, live, in Karen's place**: a
	-- `claim-line` refusal of 5.457 against a 2.0 budget whose decomposition read
	-- `along -2.079, across 4.679, ALONG THE ANIMAL +5.106 (v 28.7 studs/s, so 0.178 s of it)` --
	-- 99.7 % of the gap along the animal's own velocity. The two sides did not disagree about
	-- WHERE; they disagreed about WHEN. So the geometric checks are no longer evaluated at the
	-- single instant `arrivalAt`: the server sweeps its OWN history backwards over a window IT
	-- owns, and judges at the one instant its OWN trajectory came closest -- among the instants
	-- that pass check 3. `arrivalAt` is always candidate 1, so this is a strict superset of what
	-- one instant accepted.
	-- THE SHOOTER, FOR HIS OWN PING AND NOTHING ELSE. `shooterUserId` is on the shot record the
	-- flight carries; a player who has left gives nil, and `viewWindowFor` then contributes no ping
	-- and answers the base window, which is the safe direction.
	local shooter = if type(shot.shooterUserId) == "number" then Players:GetPlayerByUserId(shot.shooterUserId) else nil
	local window = Weapon.viewWindowFor(shooter)
	local candidates = {}
	local lastWhy = stats.claimHistoryWhy
	local asked = 0
	for k = 0, CONFIG.CLAIM.VIEW_LAG_MAX_SAMPLES - 1 do
		local at = arrivalAt - k * CONFIG.CLAIM.VIEW_LAG_STEP_SECONDS
		if arrivalAt - at > window then
			break
		end
		-- THE HISTORY REASON IS KEPT LOCAL AND PUBLISHED ONLY WHEN NO CANDIDATE ANSWERED
		-- (design 4.9, round 1's finding 3, and it was right). `askWhereWas` writes
		-- `stats.claimHistoryWhy` on EVERY call; with a sweep the oldest candidate legitimately
		-- answers nil at the ring's edge, so an ACCEPTED claim would leave that nil's reason behind
		-- and destroy the one diagnostic that tells an unwired root from an unplaceable animal
		-- (task 266b, which cost a live session). The value before the sweep is restored unless the
		-- sweep itself found nothing.
		asked += 1
		local whyBefore = stats.claimHistoryWhy
		local where = askWhereWas(claim.part, at)
		lastWhy = stats.claimHistoryWhy
		stats.claimHistoryWhy = whyBefore
		if where == nil then
			-- GOING BACKWARDS, ONCE THE RING'S SPAN IS LEFT IT IS LEFT FOR GOOD -- but only after a
			-- non-nil answer. `arrivalAt` itself can sit up to one Heartbeat past the newest sample,
			-- which `Boar.sampleAt` refuses rather than extrapolates, and that must not end the
			-- sweep before it has started.
			if #candidates > 0 then
				break
			end
		else
			table.insert(candidates, { at = at, point = where * claim.offset })
		end
	end
	if #candidates == 0 then
		stats.claimHistoryWhy = lastWhy
		return refuse("claim-history")
	end
	-- WHAT STOPPED THE SERVER'S OWN FLIGHT, AS AN IDENTITY (task 269b). Read once, here, because
	-- `Hits.targetOf` needs an Instance and `Validator` may touch none: if the thing the flight
	-- stopped on belongs to the SAME animal the claim names, the bullet reached its target and
	-- check 5 -- the line-of-sight rule -- has nothing to say about it.
	local firstImpact = res.impacts[1]
	local stopper = if type(firstImpact) == "table" then firstImpact.instance else nil
	local stoppedBySame = false
	if typeof(stopper) == "Instance" then
		stoppedBySame = Hits.targetOf(stopper) == target
	end

	local index, trajectoryPoint, _lineStuds, _movedStuds, anyPassed =
		Validator.pickViewInstant(candidates, segments, claim.point, CONFIG.CLAIM)
	-- ITEM 1's FOUR NUMBERS, written for every claim that reached the sweep.
	stats.claimSweepFound = #candidates
	stats.claimSweepAsked = asked
	stats.claimSweepWindow = window
	stats.claimSweepPassed = anyPassed == true
	-- HOW FAR APART THE SWEEP'S OWN CANDIDATES ARE (task 272). Nineteen candidates over 0.3 s of a
	-- 28 studs/s animal should span ~8.5 studs; a spread near zero means the ring answered the SAME
	-- point nineteen times, and then the first candidate wins every tie by the strict `<` and the
	-- chosen lag is 0 whatever the window is. That is the one reading that explains
	-- `sweep=19/19 win=0.301s passed=true lag=0.000s` beside a gap that needs 0.164 s.
	stats.claimSweepSpread = (candidates[#candidates].point - candidates[1].point).Magnitude
	-- WHICH CANDIDATE WAS TAKEN, AND WHAT THE BEST ONE WOULD HAVE BEEN (task 272). The sweep is
	-- measured healthy -- 19 of 19, spanning 8 studs -- and still answers the arrival instant while
	-- a candidate 0.164 s back exists. These two numbers are what separates "check 3 filtered the
	-- right one out" from "the trajectory is no nearer to any of them".
	stats.claimSweepIndex = index or 0
	do
		local best, bestAt = math.huge, 0
		for candidateIndex, candidate in ipairs(candidates) do
			local _, studs = Validator.closestOnSegments(segments, candidate.point)
			if studs < best then
				best, bestAt = studs, candidateIndex
			end
		end
		stats.claimSweepBestLine = best
		stats.claimSweepBestIndex = bestAt
		stats.claimSweepSegments = #segments
	end
	if index == nil then
		return refuse("claim-history")
	end
	local serverPoint = candidates[index].point
	local lineLagSeconds = arrivalAt - candidates[index].at
	local displacementStuds = (candidates[1].point - candidates[index].point).Magnitude
	stats.claimLastDisplacement = displacementStuds
	local closest = trajectoryPoint or serverPoint
	local closestStuds = (closest - serverPoint).Magnitude
	local position = closest

	local ok, reason, measured, budget = Validator.judgeClaim({
		offset = claim.offset,
		partHalf = part.Size / 2,
		clientPoint = claim.point,
		serverPoint = serverPoint,
		-- THE CLOSEST APPROACH, not the position at the claimed instant (above).
		trajectoryPoint = closest,
		reachedStuds = res.reachedStuds,
		claimedStuds = claim.distanceStuds,
		-- NEGATIVE MEANS THE FUTURE, which `judgeClaim` refuses by its own name. Measured against
		-- the MATCHED instant (task 269b), so the clock check and the geometry checks are about the
		-- same moment.
		ageSeconds = age,
		-- DID THE SERVER'S OWN FLIGHT STOP ON THE CLAIMED ANIMAL ITSELF (task 269b)? Then the line
		-- of sight was clear and check 5 has nothing to say. `Hits.targetOf` is the same walk that
		-- found `target` above, so "the same animal" is the same question asked once more.
		stoppedByClaimedTarget = stoppedBySame,
		-- HOW FAR THE CLAIMED ANIMAL ITSELF MOVED BETWEEN THE SWEPT INSTANT AND THE ARRIVAL ONE
		-- (task 275). Check 5 adds it to the self-block waiver's bound and to nothing else, so a
		-- tree is still a tree.
		--
		-- **IT IS THE SWEEP'S OWN TWO POINTS AND NOT A VELOCITY EXTRAPOLATION** (round 1's finding
		-- 1). It was `AssemblyLinearVelocity * lineLagSeconds`, which no case could see: an
		-- anchored spec part reads velocity 0, so the term was 0 before and after the change and
		-- the producing line could be deleted with the suite green. `candidates[1]` is the arrival
		-- instant and `candidates[index]` is the one the sweep chose, both of them the SERVER's own
		-- rewinds -- so this is the displacement that actually happened between the two instants
		-- the server itself picked, measured rather than extrapolated, and a history provider that
		-- answers `at` makes it non-zero in a spec.
		displacementStuds = displacementStuds,
		flightSeconds = claim.flightSeconds,
		expectedFlightSeconds = Ballistics.timeToRange(ballistic, claim.distanceStuds),
	}, CONFIG.CLAIM)
	if not ok then
		-- WHAT STOPPED THE BULLET, for the one rule whose cause is an Instance (task 269b). The
		-- flight already ran and already knows: its first impact is the thing that cut it short, and
		-- its FULL PATH is what tells a reader whether it was the animal's own trunk, a zone box, a
		-- tree's collider or the terrain. `Validator` may not touch an Instance -- its own header's
		-- first sentence -- so this is the owner's half of the same answer.
		local note = nil :: string?
		-- WHICH WAY THE 4.8 STUDS LIES (task 271 item 1). `claim-line` has published a MAGNITUDE
		-- since task 266 and a magnitude cannot tell three different defects apart:
		--   ACROSS the shot      the two sides are not flying the same line -- an aim or a bore
		--                        defect, 259b's own question;
		--   ALONG the shot       sub-step granularity and the bore's set-back, which check 4 was
		--                        rewritten in task 266b to stop charging for;
		--   ALONG THE ANIMAL     the two sides disagree about WHEN, not where -- a view-lag defect,
		--                        and the only one of the three a tolerance must never be widened for.
		-- So the pair is printed, decomposed on those three named axes, with the instants beside it.
		-- The animal's own velocity is read off the live part, which is the server's own fact.
		if reason == "claim-line" or reason == "moved" then
			local shotDir = if typeof(bore) == "Vector3" and bore.Magnitude > 1e-6 then bore.Unit else Vector3.zAxis
			local gap = claim.point - serverPoint
			local across = gap - shotDir * gap:Dot(shotDir)
			local travel = part.AssemblyLinearVelocity
			local travelDir = if travel.Magnitude > 1e-6 then travel.Unit else Vector3.zero
			note = string.format(
				"client %.2f,%.2f,%.2f vs server %.2f,%.2f,%.2f | gap %.3f = along %+.3f, across %.3f, "
					.. "ALONG THE ANIMAL %+.3f (v %.1f studs/s, so %.3f s of it) | firedAtView %.3f + flight "
					.. "%.4f = arrival %.3f, age %+.3f | muzzle %.2f,%.2f,%.2f dir %.3f,%.3f,%.3f",
				claim.point.X,
				claim.point.Y,
				claim.point.Z,
				serverPoint.X,
				serverPoint.Y,
				serverPoint.Z,
				gap.Magnitude,
				gap:Dot(shotDir),
				across.Magnitude,
				gap:Dot(travelDir),
				travel.Magnitude,
				if travel.Magnitude > 1e-6 then math.abs(gap:Dot(travelDir)) / travel.Magnitude else 0,
				claim.firedAtView,
				claim.flightSeconds,
				arrivalAt,
				age,
				shot.muzzle.X,
				shot.muzzle.Y,
				shot.muzzle.Z,
				shotDir.X,
				shotDir.Y,
				shotDir.Z
			)
		end
		if reason == "claim-blocked" then
			local first = res.impacts[1]
			local hit = if type(first) == "table" then first.instance else nil
			note = string.format(
				"reached %.2f of %.2f studs, stopped by %s",
				res.reachedStuds or -1,
				claim.distanceStuds,
				if typeof(hit) == "Instance" then hit:GetFullName() else "nothing it reported"
			)
		end
		return refuse(reason or "claim-refused", measured, budget, note)
	end

	stats.claimsAccepted += 1
	-- THE WORST **ACCEPTED** VIEW LAG, and it is updated HERE and nowhere else (round 1's finding
	-- 4). Before the fix the `math.max` sat above `judgeClaim`, so every claim that found a
	-- candidate -- refused included -- raised it, and design 1.2a item 15 makes a delete-or-keep
	-- decision from this number.
	stats.claimWorstLagSeconds = math.max(stats.claimWorstLagSeconds, lineLagSeconds)
	stats.claimWorstStuds = math.max(stats.claimWorstStuds, (claim.point - serverPoint).Magnitude)
	-- THE METER MUST MEASURE WHAT THE CHECK MEASURES (the Reviewer, round 1). This read `position`
	-- -- the trajectory's point at the claimed instant -- while check 4 is given `closest`, so the
	-- published number was the along-track-contaminated quantity no check uses, and the design
	-- documents this field as the one `LINE_TOLERANCE_STUDS` is to be argued down from.
	stats.claimWorstLineStuds = math.max(stats.claimWorstLineStuds, closestStuds)
	-- ...AND THE OLD QUANTITY IS KEPT UNDER ITS OWN NAME, because it is worth seeing: the gap
	-- between the two IS the along-track error (sub-step granularity plus the bore's set-back), and
	-- a reader who only ever sees one of them cannot tell which kind of disagreement he has.
	stats.claimWorstEndStuds = math.max(stats.claimWorstEndStuds, (position - serverPoint).Magnitude)

	-- TRUNCATED TO EXACTLY ONE IMPACT, and that is the whole of the single-answer rule: the claim
	-- says where the bullet actually stopped, so every impact the flight found farther out never
	-- happened. A claimable shot is single-pellet by construction (design section 6), so the flight
	-- had at most one impact and this is "the accepted claim replaces it" -- no merging, no second
	-- report, and `pellets` is 1 exactly as it is for a slug today.
	-- ONE IMPACT, BUILT BY `Validator.claimImpact`, which is pure and exported so the truncation
	-- ARITHMETIC is driven with no world (`weapon_hits.spec` case 26).
	--
	-- **THE WIRING -- THIS LINE -- IS COVERED BY `weapon_shot.spec`'s ACCEPT CASE AND BY NOTHING
	-- ELSE** (task 266b). The Reviewer's round-3 note was right that the earlier comment here
	-- overclaimed: replacing this with `return res.impacts` left the whole suite green, because
	-- case 26 calls `claimImpact` directly and the only assertion on `claimsAccepted` anywhere was
	-- that it had NOT moved. The accept case now resolves a real flight through a scripted world
	-- that stops nothing, so with this line gone there is no report on the claimed part and it
	-- fails.
	return { Validator.claimImpact(claim, part.CFrame, bore, part.Material) }
end

local function onShotLanded(res: Flight.Resolution)
	local shot = res.shot
	stats.shotsResolved += 1
	-- WHOSE ANSWER THIS REPORT IS BUILT FROM (task 266): the shooter's own validated claim, or the
	-- server's flight. `Hits.group` is still the ONE constructor of a `HitReport` and still runs
	-- once, which is what keeps every reader -- `HitLog`, `Match`, `ForestTest`, the hit marker --
	-- unchanged.
	local impacts = judgeClaimFor(res)
	-- THE COUNTERS, OUT WHERE A PROBE CAN READ THEM (task 266b item 1). Here and nowhere else: this
	-- is the one line every claim verdict passes through, so the attribute cannot fall behind the
	-- numbers it reports. In a live server `publishClaimStats` returns false and writes nothing.
	Weapon.publishClaimStats()
	local reports = Hits.group(shot.shooter, impacts, shot.ammo, shot.firedAt, shot.weapon)
	stats.reports += #reports

	-- THE SHOT RESOLVED, HIT OR MISS (task 298, design 8.3). ONCE, from the facts this function
	-- already holds, before the reports go out so no listener can be told about a hit and never
	-- about the shot. `endPoint` is the flight's own measured end; a refused shot never flew, so it
	-- ends at the muzzle. Its one listener is `Range`, wired at a composition root.
	local hitParts: { Instance } = {}
	for _, impact in ipairs(impacts) do
		if impact.instance ~= nil then
			table.insert(hitParts, impact.instance)
		end
	end
	resolvedSignal:Fire({
		shooter = shot.shooter,
		shooterUserId = shot.shooterUserId,
		weapon = shot.weapon,
		ammo = shot.ammo,
		muzzle = shot.muzzle,
		reachedStuds = res.reachedStuds,
		endPoint = if res.endPoint ~= nil then res.endPoint else shot.muzzle,
		firedAt = shot.firedAt,
		resolvedAtServerTime = Workspace:GetServerTimeNow(),
		hitParts = hitParts,
	})

	for _, report in ipairs(reports) do
		hitSignal:Fire(report)
		-- One marker per (shot, target), not one per pellet: nine pellets on one boar is one hit.
		Weapon.markHit(shot.shooter, "hit", report.zone)
	end

	-- WHERE THE DUST GOES (design section 7). The bang was at the trigger; this is the bullet
	-- arriving, and it is the one thing on screen that tells a player a shot takes time -- with no
	-- tracer and no number. It carries nothing but the shooter and the points: no target, no zone,
	-- no damage, no state. A shot that hit nothing sends nothing.
	if #impacts > 0 then
		local points = {}
		-- ...AND WHAT IT LANDED ON (task 249). KAREN, 2026-10-23, with a frame: *"after shoot
		-- remianing this ? what is that ?"* -- the client drew a `Neon` cube at each of these
		-- points because a point is all it was ever given. Two more parallel arrays, nothing else:
		-- the surface NORMAL, so the puff comes off the ground instead of out of it, and the
		-- surface MATERIAL as a plain STRING, so the client picks soil or splinters.
		--
		-- STRINGS AND NOT `Enum.Material` VALUES, because an Enum crossing a RemoteEvent arrives as
		-- an EnumItem the client would have to compare against its own enum anyway -- and the
		-- client's own table (`Shotgun.CONFIG.IMPACT.WOOD`) is keyed by name. One representation,
		-- at the one boundary.
		--
		-- THREE ARRAYS AND NOT ONE ARRAY OF TABLES: `impacts` is the field every client built
		-- before this task reads, and it still carries exactly what it always did, so an older
		-- client draws what it always drew rather than nothing.
		local normals = {}
		local materials = {}
		-- ...AND WHICH BODY IT LANDED ON (task 256). KAREN, 2026-10-24: *"this signe where we shot
		-- where we hit sometimes shows we hit empty space and died needs corection"*. The dust was
		-- drawn at a WORLD point, and a boar at `SPRINT_SPEED` is 11.4 studs -- two of its own body
		-- lengths -- past that point before its grains have faded (research note section 8.1). This
		-- is the one fact the client needs to pin the dust to the animal instead of to the air.
		--
		-- THE INSTANCE AND NOTHING ELSE. No local offset: the client has the part and the part has a
		-- CFrame, so the offset is `PointToObjectSpace` there -- and the client's own copy of where
		-- the animal is NOW is the right frame to draw in, because that is the animal the player can
		-- see. Sending an offset would be a second representation of a derivable thing, stale by
		-- exactly the trip time.
		--
		-- WHETHER IT MOVES IS THE CLIENT'S QUESTION, not this one's: `Effects.ridesWith` asks the
		-- part's own `Anchored`. The server reports what was struck; the client decides how to draw
		-- it, which is the division `materials` already follows.
		local parts = {}
		-- `impacts` AND NOT `res.impacts` (task 266): the dust has to be drawn from the same list the
		-- report was built from, or an accepted claim would put the HIT on the animal and the PUFF
		-- where the server's own bullet went -- two things drawing one shot, which is the overlapping
		-- -owner failure this project is named after, and exactly the complaint Karen made
		-- (*"this signe where we shot ... shows we hit empty space"*).
		for _, impact in ipairs(impacts) do
			table.insert(points, impact.position)
			-- `false` IS THE PLACEHOLDER, NOT A HOLE, for the reason the normals array states right
			-- below: all four arrays are read BY INDEX on the client, and a nil here would shorten
			-- this one and stand every later pellet's dust on the wrong surface. A cast can only
			-- return a BasePart or Terrain today, and Terrain is anchored world either way.
			table.insert(
				parts,
				if impact.instance ~= nil and impact.instance:IsA("BasePart") then impact.instance else false
			)
			-- A PLACEHOLDER RATHER THAN A HOLE, in BOTH arrays (round 1, note). The three arrays
			-- are read BY INDEX on the client, so one impact with no normal would shift every
			-- later entry and stand a puff on another pellet's surface. `materials` already
			-- substituted `""`; `Vector3.zero` is the normal's own "nothing was said", and
			-- `Effects.impactFrame` reads it as world up.
			table.insert(normals, if typeof(impact.normal) == "Vector3" then impact.normal else Vector3.zero)
			table.insert(materials, if impact.material ~= nil then impact.material.Name else "")
		end
		local channel = remotes or Shotgun.remotes()
		channel.ShotLanded:FireAllClients({
			shooterUserId = shot.shooterUserId,
			impacts = points,
			normals = normals,
			materials = materials,
			-- FOURTH PARALLEL ARRAY, FOLLOWING THE THREE (task 256): a client written before this
			-- task simply does not read it and draws exactly what it always drew.
			parts = parts,
		})
	end
end

local function onFireRequest(player: Player, req: any): string?
	local now = os.clock()
	local allowed, bucket = Limits.allow(registry:bucket(player, "fire"), now, CONFIG.FIRE_RATE_LIMIT)
	registry:setBucket(player, "fire", bucket)
	if not allowed then
		stats.rateDropped += 1
		return "rate-limited"
	end

	-- WHICH WEAPON THIS SHOT IS (task 140), and every ballistic number below comes from its row.
	-- The SYSTEM's numbers -- the arc, the origin tolerance, the rate limits -- stay in
	-- `Shotgun.CONFIG`, where they belong: a rule of the drive is not a property of a gun.
	local id = Weapon.heldId(player) or Weapons.PRIMARY
	local row = Weapons.row(id) or Weapons.ROWS[Weapons.PRIMARY]
	local state = stateOf(player, id)
	if not state then
		return "untracked"
	end

	local rootPosition = rootPositionOf(player)
	local ok, why = Validator.checkShot(req, rootPosition, CONFIG, ORIGIN_TOLERANCE_STUDS)
	if not ok then
		-- THE REFUSED SEPARATION IS RECORDED TOO (the Reviewer's round-1 note). Written only on the
		-- accepted path, `originFarthest` could argue the bound TIGHTER and never looser: the one
		-- event that would show 6 studs is too tight is a shot refused `origin-far`, and that shot
		-- never reached the line below. Now both are instruments: `originFarthest` is the worst
		-- HONEST shot and `originRefusedFarthest` the worst refused one, so a real server can say
		-- which way the number should move.
		if rootPosition and why == "origin-far" then
			stats.originRefused += 1
			stats.originRefusedFarthest = math.max(stats.originRefusedFarthest, (req.origin - rootPosition).Magnitude)
		end
		stats.badRequests += 1
		publish(player, id, state)
		return why or "bad-request"
	end
	-- THE INSTRUMENT FOR THE BOUND ABOVE (task 260). The geometry is measured and the NETWORK half is
	-- not measurable on this PC (a loopback Studio session reads 1-2 ms of ping), so this records how
	-- close honest shots actually come to `ORIGIN_TOLERANCE_STUDS` on a real server: the largest
	-- separation any ACCEPTED shot had. It is the evidence a later tightening or loosening should be
	-- argued from, and it is one `math.max` on a path that already has the two Vector3s in hand.
	if rootPosition then
		stats.originFarthest = math.max(stats.originFarthest, (req.origin - rootPosition).Magnitude)
	end

	local fired, reason = StateMachine.apply(state, { kind = "Fire" }, now, row)
	if reason then
		-- THE TRIGGER PULLED ON A GUN WITH NOTHING IN IT AND NOTHING LEFT (task 248). KAREN,
		-- 2026-10-23: *"if no rounds at all tell no ammo"*. Until today this was the quietest event
		-- in the game: the reducer answered `barrel-empty`, an UNFORCED publish went out, and the
		-- player got no click, no line and no reason -- a dead trigger. `Shotgun.ammoNeed` is the
		-- one answer to which of the three states the gun is in, and the Hud's rail highlights the
		-- R off the SAME function, so what he is told here and what is lit there cannot disagree.
		--
		-- ONLY THE `EMPTY` STATE SPEAKS. A gun he can simply reload is the RELOAD state, and that is
		-- the rail's highlight to say -- a notice as well would be two things saying one thing.
		if reason == "barrel-empty" and Shotgun.ammoNeed(state, row) == Shotgun.AMMO_NEED.EMPTY then
			stats.emptyTriggers += 1
			-- FORCED PAST THE PUBLISH LIMITER and carrying `refused`, for the reason the rules'
			-- refusal publish gives: an answer the client never hears is a trigger that did nothing
			-- for no visible reason. `refused` is what makes the one dry click and the one centre
			-- line, and it is the gun's own wire value -- never a `Rules.REASON`.
			publish(player, id, state, true, Shotgun.NOTICE_NO_AMMO, nil, nil, Shotgun.REFUSED_NO_AMMO)
			return reason
		end
		publish(player, id, state)
		return reason
	end
	local ammo = state.loaded[state.selected]

	local tool = toolsOfPlayer(player)[id]
	local muzzle = tool and Hardware.muzzlePosition(tool)
	if not muzzle then
		-- A SHELL IS NO LONGER SPENT ON A GUN WITH NO MUZZLE (task 171; the Reviewer's round-1 note
		-- asked for it to be stated). Before the gates moved above `setState` this path had already
		-- committed the fired state, so a Tool whose `Muzzle` attachment was missing cost the player
		-- a round for a shot that never happened. `state` is published, not `fired`, so the gun stays
		-- as it is. It is a consequence of the reorder rather than a goal of it, and it is an
		-- improvement: no muzzle is a HARDWARE fault, and the player should not pay for one.
		publish(player, id, state)
		return "no-muzzle"
	end

	local range = row.RANGE_STUDS[ammo]
	-- ONE CAST, AND IT IS THE ONE THE AIM QUESTION MAKES TOO (task 238). `aimTarget` is handed
	-- straight to `Rules.refuse` below, where `askTarget(aimImpact.instance)` used to be computed a
	-- second time at the call site.
	local aimTarget, aimImpact = lookAhead(player, req.origin, req.direction, range)
	local aimPoint = if aimImpact then aimImpact.position else req.origin + req.direction * range

	-- WHERE THE BORE STARTS, AND IT IS ONE CALL (task 259). It was `muzzle` and two inline lines.
	-- KAREN, 2026-10-24: *"we need to work on rifle acuracy when aiming with scope, it seems there
	-- is a bit off"*. The convergence below cancels the eye-to-muzzle offset AT THE AIM POINT and
	-- nowhere else, so when the ray hits nothing -- which is every shot led into empty space at a
	-- running animal, her own next sentence -- the 0.73 studs MEASURED between the eye and the
	-- world Tool's muzzle is divided down instead of cancelled, and the shot lands 19 cm right of
	-- the reticle at 25 m. `Ballistics.boreOrigin` holds the measurement, the arithmetic and the
	-- parameter; `CONFIG.BORE_ON_SIGHT_LINE` **ships `true` since task 260**, so the bore starts on
	-- the sight line and the 0.73 studs is gone whatever the ray hit. This line said "is false,
	-- which is today bit for bit" until task 265 round 2 -- true when task 259 wrote it, stale from
	-- task 260 onward, and it misled that round's own request.
	local origin = Ballistics.boreOrigin(req.origin, req.direction, muzzle, CONFIG.BORE_ON_SIGHT_LINE)
	local aim = Ballistics.convergeAim(origin, aimPoint, req.direction, CONFIG.MIN_AIM_DISTANCE)
	-- HOW FAR THIS SHOT GETS, COMPUTED ONCE AND READ TWICE (task 248). It was computed inside the
	-- safety-arc block below, AFTER the shot had been committed; the SAFETY LOCK has to ask the same
	-- question BEFORE it, and two expressions for "where the shot stopped" would be two answers to
	-- the question `Match.Penalty.judge` is given. The distance from the muzzle to the AIM POINT, not
	-- `report.nearest`: the reason is in the arc block's own comment below and has not changed.
	-- ...MEASURED FROM WHERE THE SHOT ACTUALLY LEAVES (task 259), which is `origin` and not `muzzle`:
	-- the two differ only by the 0.73 studs across the sight line when `BORE_ON_SIGHT_LINE` is on,
	-- and with it off they are the same Vector3, so this is unchanged in the shipped build.
	local stopAt = if aimImpact then (aimPoint - origin).Magnitude else range

	-- -------------------------------------------------------------- THE RULES (task 171)
	--
	-- EVERY GATE IS ASKED BEFORE ANYTHING IS COMMITTED, and the order is this owner's -- the same
	-- division `Limits`, `Validator` and `StateMachine` above already follow: each of them answers
	-- one question and this function decides when to ask it (docs/research/2026-10-13-the-rules.md).
	--
	-- `fired` IS NOT KEPT WHEN A GATE REFUSES, and that is the whole mechanism. `StateMachine.apply`
	-- is pure and hands back a NEW state, so declining to call `setState` is what makes a refused
	-- shot cost nothing: no shell spent, no barrel moved, no bolt started, no `ShotFired`, no pellet
	-- cast, no `SafetyViolated`, no hit. That is OpenTTD's test-then-execute (`CommandCost`), and it
	-- is the opposite of ioquake3's `g_friendlyFire`, which lets the shot fly and drops the damage --
	-- the shape Karen refused: *"thye just can't shoot them"*.
	--
	-- WHY THE GATES ARE HERE AND NOT BEFORE `StateMachine.apply`: the aim ray needs the ammo's range,
	-- and the ammo is `state.loaded[state.selected]`, which is only meaningful once the reducer has
	-- agreed that this gun can fire at all. An empty, open or busy gun is refused for a MECHANICAL
	-- reason first, which is what the player already sees today.
	--
	-- WHAT THE PLAYER GETS INSTEAD OF A SHOT: the reason on the wire, which the client turns into one
	-- dry click and one short line on the readout (`Rules.NOTICE`). No punishment -- Karen asked for
	-- none, twice.
	-- ONE CALL, AND THE ORDER IS `Rules.ORDER`'s (task 171, after the Director's two-player run):
	-- off-stand, then the beater in the ray, then the licence. It used to be an `if` chain here,
	-- which made the order this owner's private habit instead of a rule anybody could assert;
	-- `weapon_rules.spec` now trips all three at once and names the winner.
	local fireLicences, fireLicencesKnown = askLicences(player)
	local refused = Rules.refuse({
		position = rootPositionOf(player),
		stand = askStand(player),
		target = aimTarget,
		-- ...AND WHETHER ANYBODY KNOWS WHAT HE HOLDS (task 255). Two returns from one call, so the
		-- gate can never read the set and the knowledge from two different asks of a provider that
		-- may answer differently a millisecond apart.
		licences = fireLicences,
		licencesKnown = fireLicencesKnown,
		-- ...AND WHETHER THE DRIVE IS ON AT ALL (task 174), which `Rules.ORDER` asks FIRST.
		driveOpen = askDriveOpen(player),
		-- ...AND WHETHER THIS LINE PASSES CLOSE TO A PERSON (task 248): the SAFETY LOCK. The drive
		-- measures it off the shot the player is actually about to take -- this muzzle, this
		-- direction, this far -- so what is refused is what would have been fired, the rule
		-- `SafetyArc` and `beaterInLine` already state for the same reason.
		-- `origin`, NOT `muzzle` (task 259): the design's rule here is *"what is refused is what
		-- would have been fired"*, so the line tested is the line the bullet takes. The two differ
		-- by 0.73 studs only when `CONFIG.BORE_ON_SIGHT_LINE` is on; off, they are the same Vector3.
		lineUnsafe = askLineUnsafe(player, origin, aim, stopAt),
	})
	if refused ~= nil then
		stats.refused += 1
		stats.refusedBy[refused] = (stats.refusedBy[refused] or 0) + 1
		-- THE STATE THAT IS PUBLISHED IS `state`, NOT `fired`: the gun the player is still holding,
		-- with its shell still in it. Forced past the publish limiter because a refusal the client
		-- never hears is a trigger that did nothing for no visible reason.
		publish(player, id, state, true, Rules.noticeFor(refused), nil, nil, refused)
		return refused
	end

	setState(player, id, fired)

	-- -------------------------------------------------------- THE SHOT LEAVES THE GUN (task 185)
	--
	-- IT IS NO LONGER RESOLVED HERE. Until this task the next two lines were `Hits.resolve` and
	-- `Hits.group`: one cast per pellet, the whole range, in THIS frame -- so a boar sprinting at
	-- `Boar.CONFIG.SPRINT_SPEED` (38 studs/s) was hit wherever the reticle sat and aiming ahead
	-- could only miss. Karen, 2026-10-14: *"when I shoot in running animal I need to aim a bit in
	-- front based on speed distance ect I wan to have that feeling"*, and *"same with s/s"*.
	--
	-- `onShotLanded` below is where the hit now happens, one or more Heartbeats later, with the
	-- target judged WHERE IT IS when the bullet gets there. Everything after this block is exactly
	-- what it was and happens in exactly this frame: the safety arc, the publish, the bolt, the
	-- bang the boar hears, and the flash on every client.
	local ballistic = Ballistics.shotFor(row, ammo)
	if ballistic == nil then
		-- A DATA FAULT, NOT A SHOT, and the player does not pay for it. The same rule this function
		-- already applies to a gun with no muzzle: *"no muzzle is a HARDWARE fault, and the player
		-- should not pay for one."* `state` is published rather than `fired`, so the shell is NOT
		-- spent. It does NOT fall back to a straight line: a fallback would be a second answer to
		-- "where did the bullet go", reachable by a typo in a data table (design 6.5). Unreachable
		-- in the shipped build -- both rows carry all three numbers and `rifle.spec` asserts it
		-- field by field -- which is the point.
		stats.noBallistics += 1
		if stats.noBallistics == 1 then
			warn(string.format("[Weapon] %s has no ballistics for %s: the shot cannot fly", id, tostring(ammo)))
		end
		publish(player, id, state)
		return "no-ballistics"
	end

	-- THE ELEVATION IS APPLIED ONCE, TO `aim`, BEFORE THE PATTERN. The bore sits a little above the
	-- sight line so the falling bullet crosses it again at the ZERO distance, and the cone then
	-- spreads about the ELEVATED bore -- which is what a real elevated barrel does. Patterning first
	-- and elevating nine directions afterwards would be nine elevations and a second place for the
	-- sign to be wrong. `Pattern.directions` is untouched.
	local bore = Ballistics.launchDirection(aim, ballistic)

	-- THE CLAIM'S SHAPE, JUDGED HERE AND ITS GEOMETRY JUDGED AT THE RESOLUTION (task 266). A fault
	-- in the SHAPE -- a missing field, a NaN, a flight longer than a projectile may live, or a
	-- pattern weapon trying to claim a point -- is cheap to find and must not travel with the shot,
	-- so the claim is DROPPED and **the shot proceeds**: a bad claim is not a refused trigger, and a
	-- player whose client sends nonsense still gets the game everybody else has.
	--
	-- `row.PELLETS[ammo]` IS READ OFF THE WEAPON'S OWN ROW, so "may this shot carry a claim" is DATA
	-- and not a bit the client chooses: buckshot's nine pellets are refused `claim-pattern` and the
	-- spread stays the server's secret (`docs/design/shotgun.md` 5.7).
	local claim = nil
	if type(req) == "table" and req.claim ~= nil then
		local shapeOk, shapeWhy = Validator.checkClaim(req.claim, CONFIG, row.PELLETS and row.PELLETS[ammo])
		if shapeOk then
			claim = req.claim
		else
			stats.claims += 1
			stats.claimsRefused += 1
			local key = shapeWhy or "claim-refused"
			stats.refusedClaimBy[key] = (stats.refusedClaimBy[key] or 0) + 1
		end
	end

	-- HOISTED (task 306 B5): the ignore list is now asked AT this rewind, so the one number has to
	-- exist before the table that carries it. `Weapon.rewindFor` is still the only thing that
	-- computes it and still returns 0 when the flag or the policy is off.
	local rewindSeconds = Weapon.rewindFor(player, nil, CONFIG)
	local launched = flight:launch({
		shooter = player,
		-- TAKEN AT THE TRIGGER, so a shooter who leaves before the bullet lands is still
		-- identifiable: `HitLog` and `Score` key by this (design 6.4).
		shooterUserId = player.UserId,
		weapon = id,
		ammo = ammo,
		-- WHERE THE PROJECTILES START (task 259). `Flight` casts its first segment from this point,
		-- and it is `origin` -- the bore -- not the Tool's attachment. **`CONFIG.BORE_ON_SIGHT_LINE`
		-- SHIPS `true` SINCE TASK 260**, so the two are 0.73 studs apart in the shipped build; this
		-- sentence said "off ... today bit for bit", which was true when task 259 wrote it and stale
		-- from task 260 onward (the Reviewer, task 266 round 1, and the same class of stale
		-- shipped-value sentence task 265 round 2 existed to remove).
		--
		-- THE ATTACHMENT IS STILL WHAT THE FLASH READS: `ShotFired` carries `muzzle`, because a
		-- flash has to come out of the gun. **`ShotLanded` carries no muzzle at all** -- its payload
		-- is `shooterUserId`, `impacts`, `normals`, `materials`, `parts`, built in `onShotLanded`
		-- ABOVE this function -- and both the old wording here and TASKS.md 259b(c3) named it
		-- wrongly (the Reviewer, task 266 round 1).
		-- **AND `safetySignal` BELOW IS NOT A FLASH, WHICH THE FIRST VERSION OF THIS COMMENT CALLED
		-- IT (the Reviewer's round-1 note).** `Weapon.SafetyViolated`'s own header says the drive
		-- needs that payload, and `Match.Penalty.judge` measures off it -- so at
		-- `BORE_ON_SIGHT_LINE = true` the published line started 0.73 studs off the line
		-- `askLineUnsafe` tested, which is exactly the asymmetry the `lineUnsafe` comment argues
		-- against. **THAT IS FIXED SINCE TASK 266: `safetySignal:Fire` now publishes `origin`**, so
		-- the lock and the penalty measure one line. This comment said it was "not changed here" and
		-- queued as TASKS.md 259b, which was true from task 259 until task 266; the fix is at that
		-- call site below, with the measurement and the arithmetic
		-- (`docs/design/ballistics.md` section 8).
		muzzle = origin,
		-- THE SAME LIST THE AIM CAST USED, asked again rather than kept in a local: `lookAhead` owns
		-- the cast now (task 238) and `ignoreFor` is a pure build from the player's character, so
		-- asking twice in one frame answers the same thing and nothing is passed around to go stale.
		ignore = ignoreFor(player, rewindSeconds),
		rangeStuds = range,
		-- THE TIME OF THE SHOT, which becomes `HitReport.at`. Not the arrival's: `HitLog.recordHit`
		-- asks "when in this drive was this shot taken", and a report with two clocks in it is worse
		-- than one that is 0.3 s early (design 6.3).
		firedAt = now,
		epoch = fired.epoch,
		-- CARRIED, NEVER READ BY `Flight` (task 266). The claim rides the record that is already
		-- held for exactly as long as the bullet is in the air, which is what makes the pending
		-- queue free; the bore is what lets the owner re-step its own trajectory when it lands.
		claim = claim,
		bore = bore,
		-- HOW FAR BACK THIS SHOOTER'S PICTURE IS (task 305). Taken at the trigger, like `muzzle`
		-- and `firedAt`, because by the time the bullet lands the ping has moved on; `Weapon.rewindFor`
		-- is the one thing that computes it and returns 0 when the flag or the policy is off.
		rewindSeconds = rewindSeconds,
		-- THE ANCHOR THAT REWIND IS MEASURED FROM (task 305b), on the clock the animal's own ring
		-- is stamped with, so the two are comparable without a conversion.
		firedAtServer = Workspace:GetServerTimeNow(),
		-- LAG COMPENSATION, THE FOURTH ARGUMENT (task 256). `Weapon.catchUpFor` is the one thing
		-- that computes it and `Flight.launch` clamps it again; it is the shooter's own trip, so a
		-- player on a good connection is given nothing and the lead he learns is the TRUE lead.
	}, Pattern.directions(ammo, bore, rng, row), ballistic, Weapon.catchUpFor(player, nil, CONFIG))
	if launched == 0 then
		stats.flightRefused += 1
	end
	stats.shots += 1

	if driveLineProvider then
		local line = driveLineProvider()
		-- `aim`, not the camera direction: a published violation must match where the pellets went.
		if line and SafetyArc.isForbidden(aim, line, CONFIG.SAFETY_ARC_HALF_DEG) then
			-- `stopAt` IS HOW FAR THE SHOT GOT, the fourth argument the drive needs (Task 35):
			-- without it a clean kill on a boar 30 studs away ties the shooter because a driver
			-- stood 80 studs behind it, in line -- the pellets never got near him. It is COMPUTED
			-- ONCE, above the rules, and the SAFETY LOCK is given the same number (task 248).
			--
			-- It is the distance from the muzzle to the AIM POINT, not `report.nearest` as
			-- docs/design/drive.md section 8.2 proposed (reviews/task-35/DESIGN_DELTA.md): with
			-- buckshot the nearest impact of a nine-pellet pattern is whichever pellet clipped the
			-- ground first, which at long range is a few studs out and would mask every violation.
			-- The aim point is where the shot was actually going.
			--
			-- ...AND IT STARTS WHERE THE BULLET STARTS, WHICH IS `origin` AND NOT `muzzle` (259b,
			-- fixed here by `docs/design/ballistics.md` section 8). This line published the Tool's
			-- attachment while `askLineUnsafe` above tested the BORE, with the SAME `aim` unit vector
			-- -- so the tested ray `origin + aim*t` and the published ray `muzzle + aim*t` were
			-- **PARALLEL**, 0.73 studs apart (MEASURED, task 259: the world Tool's muzzle is
			-- +0.741/-0.201 studs off the eye for the shotgun and +0.718/-0.135 for the rifle, in the
			-- live camera's own frame). `Match.Penalty.judge` takes a PERPENDICULAR distance to the
			-- published ray, so the two answers differed by up to that 0.73 studs **at every range**,
			-- 30 studs and 300 alike -- a range-independent flip band around
			-- `Match.CONFIG.SAFETY_MISS_STUDS` (12). Task 265 round 3 measured it off the code and
			-- its round-3 review corrected the first arithmetic, which claimed the band closed at
			-- the aim point: parallel rays do not converge.
			--
			-- SO THE LOCK AND THE PENALTY NOW MEASURE ONE LINE, which is the rule the `lineUnsafe`
			-- comment above already states -- *"what is refused is what would have been fired"*. A
			-- driver can no longer be passed by the lock and then judged unsafe by the penalty, or
			-- the other way round.
			--
			-- NOTHING UNDER `src/server/Match/` CHANGES. `Match.onSafetyViolation(player, aim,
			-- muzzle, stopAt)` and `Match.lineIsUnsafe` both already take the ray's START as an
			-- argument and build a `Penalty.Shot` from it, so this is one Vector3 at one call site.
			-- `ShotFired` below keeps the Tool's `muzzle`, and that asymmetry is deliberate: a flash
			-- has to come out of the gun, a penalty has to measure the bullet's own line.
			-- **`ShotLanded` carries no muzzle** -- see the `muzzle = origin` block above; the first
			-- version of this comment said it did, repeating the error TASKS.md 259b(c3) had already
			-- recorded in the comment it replaced (the Reviewer, task 266 round 1).
			safetySignal:Fire(player, aim, origin, stopAt)
		end
	end

	publish(player, id, fired, true)

	-- ...AND THE BOLT WORKS ITSELF (task 140). With one chamber a manual cycle means pressing R
	-- after EVERY shot, which is a reload and not a bolt, so a weapon whose row says `AUTO_CYCLE`
	-- runs its own sequence once the trigger's own dwell has elapsed. `runCycle` is the same
	-- function `R` runs, so there is one sequence runner in the system and not two.
	if row.AUTO_CYCLE then
		task.spawn(function()
			task.wait(row.BARREL_DELAY)
			local after = stateOf(player, id)
			if after and after.epoch == fired.epoch then
				runCycle(player, id, fired.epoch)
			end
		end)
	end

	-- THE SHOT AS A FACT, FOR THE SERVER (task 118). It goes out beside the client remote below so
	-- the two can never disagree about what counted as a shot.
	--
	-- ...AND IT CARRIES WHERE THE SHOT WENT (task 149b). Not the pellet pattern -- one point, the aim
	-- ray's own impact, or the end of the range when it hit nothing. A boar hears a bang at a place,
	-- and there are TWO places: the muzzle and the far end. Karen: *"I shoot and few run and next to
	-- them another group walk"* -- the group beside the animal she hit is at `at`, not at `muzzle`.
	shotSignal:Fire({ shooterUserId = player.UserId, muzzle = muzzle, at = aimPoint, ammo = ammo })

	local channel = remotes or Shotgun.remotes()
	-- WHICH PIPE FIRED, AND THE FRAME TO DRAW IT IN (task 92). `state.selected` is the barrel this
	-- shot came out of -- `fired.selected` has already moved to the other one -- and `muzzleCFrame` is
	-- that barrel's own muzzle, which is what a client needs to point a flash along the bore without
	-- re-deriving the gun's orientation from a position. `muzzle` stays exactly what it was: the
	-- ballistic origin every pellet came from.
	channel.ShotFired:FireAllClients({
		shooterUserId = player.UserId,
		muzzle = muzzle,
		-- ALWAYS EMPTY SINCE TASK 185, and the field stays so the wire shape and the payload type
		-- are unchanged. The impact points do not exist in this frame any more -- the bullet has not
		-- arrived. They go out on `ShotLanded` when it does, and `Effects.play` already reads
		-- `payload.impacts or {}`, so it draws the flash and the smoke and never enters its tracer
		-- branch. The FLASH, the SMOKE, the SOUND and the RECOIL all stay here, at the trigger
		-- (design section 7).
		impacts = {},
		ammo = ammo,
		barrel = state.selected,
		muzzleCFrame = Hardware.muzzleCFrame(tool, state.selected),
	})
	return nil -- the shot was taken
end

-- Break/Load/Close are never reachable from here: Validator.checkRequest accepts only "Reload" and
-- "SelectAmmo" (defect d). The reload sequence below is the only caller of the primitives.
-- Break -> Load -> Load -> Close, the 2.0 s window both R and X run through. Uninterruptibility is
-- the reducer's, not a flag: from the first Break until Close, a second Reload is refused "is-open"
-- and every Fire is refused "is-open" (design section 5.5).
-- ONE SEQUENCE RUNNER FOR BOTH WEAPONS (task 140). The steps are `row.CYCLE` -- the shotgun's
-- four, the rifle's three -- read from data instead of built in code, and everything else here is
-- what it was: the `"no-reserve"` exception, the `"is-open"` recovery that closes a gun it left
-- open, and the trailing publish that clears the Hud's R.
-- `steps` NAMES WHICH SEQUENCE (task 142), and nil is the weapon's own cycle. A magazine rifle has
-- TWO: working the bolt after a shot (`CYCLE` -- back, forward) and changing the magazine
-- (`RELOAD` -- the box, then a bolt cycle to chamber the first round). The shotgun has one, so its
-- row carries no `RELOAD` and both callers get the same four steps they always did.
-- WHAT A REFUSED STEP MEANS, AS A PURE RULE WITH THREE ANSWERS (task 224). `runCycle` used to carry
-- one hard-coded boolean -- `step.kind == "Load" and reason == "no-reserve"` -- and a third case
-- arrived with the lever rifle's tube magazine.
--
--   "walk"   keep going. An EMPTY POCKET: closing a gun with fewer rounds in it, or none, is correct.
--   "finish" the magazine is FULL: skip every remaining `Load` and run the sequence's last step.
--   "abort"  anything else. The world moved under it -- today's recovery path, unchanged.
--
-- WHY `barrel-full` IS NOT SIMPLY ANOTHER `walk`. A partial top-up -- three in a tube of five, press
-- R -- makes the fourth `Load` answer `barrel-full`. As a `walk` the unused steps still burn their
-- 0.42 s each, so putting TWO rounds in would take the same 2.90 s as putting in five. As a `finish`
-- it is 0.40 + 2 * 0.42 + 0.40 = 1.64 s and the `Close` is a real published, timed, voiced step.
--
-- IT CHANGES NOTHING FOR EITHER SHIPPED GUN, and that is provable rather than hoped: the shotgun's
-- `Break` ejects `"all"`, so both its chambers are always `Empty` when its two `Load`s run, and the
-- rifle's reload uses `Magazine`, which fills every chamber at once and whose own `barrel-full` is a
-- `Magazine` refusal and not a `Load` one. `tests/server/lever.spec.luau` drives all three answers
-- and asserts that neither gun can reach the new one.
--
-- PURE AND EXPORTED precisely so those cases need no session, no player and no Tool.
--
-- Design: docs/design/lever-rifle.md (section 6.3)
function Weapon.cycleRefusal(kind: string?, reason: string?): string
	if kind == "Load" then
		if reason == "no-reserve" then
			return "walk"
		elseif reason == "barrel-full" then
			return "finish"
		end
	end
	return "abort"
end

-- `ejects` IS CARRIED THROUGH THE WHOLE SEQUENCE AND READ BY ONE STEP (task 244). Only the `Break`
-- branch of the reducer looks at it, and only one caller sends one: the reload a SHELL-TYPE SWAP
-- runs, which must empty the gun of the old shell before it can load the new one. Every caller
-- written before this passes four arguments and behaves bit for bit as it did.
function runCycle(player: Player, id: string, epoch: number, steps: { any }?, ejects: string?)
	local row = Weapons.row(id) or Weapons.ROWS[Weapons.PRIMARY]
	local sequence = steps or row.CYCLE
	-- SET WHEN THE MAGAZINE FILLED EARLY (task 224): every later `Load` is skipped and the rest of
	-- the sequence -- the `Close` -- still runs. See `Weapon.cycleRefusal`.
	local filled = false
	for _, step in ipairs(sequence) do
		local state = stateOf(player, id)
		if not state or state.epoch ~= epoch then
			return -- the player respawned, was revoked, or left: abandon the sequence
		end
		if filled and step.kind == "Load" then
			continue
		end
		-- THE SEQUENCE GOES WITH THE STEP (task 184). `Break` and `Close` are in both of the rifle's
		-- lists and no longer with the same waits, so the reducer is told which list this step came
		-- from rather than left to guess from a fixed search order.
		local next, reason =
			StateMachine.apply(state, { kind = step.kind, ejects = ejects :: any }, os.clock(), row, sequence)
		-- An empty pocket is the ONE rejection this sequence walks past: closing a gun with one
		-- shell, or none, is correct. Any other reason means the world moved under it (round 1
		-- note), so it stops and republishes rather than closing a gun the player did not ask for.
		local verdict = if reason then Weapon.cycleRefusal(step.kind, reason) else "walk"
		if verdict == "finish" then
			-- THE TUBE IS FULL. Nothing was written and nothing is owed: skip the remaining `Load`s
			-- and let the loop reach the sequence's last step, which closes the action.
			filled = true
			continue
		end
		if reason and verdict == "abort" then
			-- A REFUSAL AFTER `Break` USED TO LEAVE THE GUN OPEN FOR EVER (TASKS.md 24a(a)): every
			-- later Reload is refused with "is-open" and every Fire with the same, so the player is
			-- carrying a brick until they respawn. Close it before giving up. The player asked for a
			-- reload; a closed gun is the state they asked to end in, and Close after the step's own
			-- window has elapsed is the same action the sequence would have taken itself.
			if state.open then
				-- A "busy" refusal is the one this has to wait out: StateMachine.apply rejects every
				-- action while `now < busyUntil`, so an immediate Close would be refused for the same
				-- reason the step was and the gun would stay open anyway. A fraction of a second is
				-- cheaper than a gun that cannot be reloaded or fired again.
				local remaining = state.busyUntil - os.clock()
				if remaining > 0 then
					task.wait(remaining)
				end
				local closed, refused = StateMachine.apply(state, { kind = "Close" }, os.clock(), row, sequence)
				if not refused then
					setState(player, id, closed)
				end
			end
			-- BREAK, NOT RETURN: the trailing publish below is what clears the Hud's "R" once the
			-- last window has elapsed, and an abort needs it exactly as much as a finished sequence.
			break
		end
		setState(player, id, next)
		publish(player, id, next, true, nil, nil, step.kind)
		task.wait(step.wait)
	end
	-- One last publish once the final window has elapsed. Without it the newest snapshot a client
	-- ever sees is the one made at Close, whose busyFor is RELOAD_CLOSE, so the Hud keeps its "R"
	-- until something else changes the state -- which a player would read as a gun stuck reloading.
	local state = stateOf(player, id)
	if state and state.epoch == epoch then
		publish(player, id, state, true)
	end
	-- AN EMPTY RIFLE CHANGES ITS OWN MAGAZINE. Karen: *"when empty (or on R)"*. Only after the
	-- weapon's own CYCLE -- never after a reload, which would be a loop -- and only when the row
	-- asks for it, so the shotgun is untouched.
	if steps == nil and row.AUTO_RELOAD_WHEN_EMPTY and row.RELOAD ~= nil and state and state.epoch == epoch then
		if Weapon.roundsLeft(state) == 0 and (state.reserve[state.ammo] or 0) > 0 then
			runCycle(player, id, epoch, row.RELOAD)
		end
	end
end

-- Same contract as `onFireRequest` above, and the same reason for it: nil when the request was
-- acted on, otherwise the reason it was not.
-- `aim` IS THE THIRD ARGUMENT AND ONLY `"Aim"` SENDS ONE (task 238): `{origin, direction}`, the same
-- shape `FireRequest` carries and validated by the same `Validator.checkShot`. Every caller written
-- before task 238 passes two arguments and is unchanged.
local function onActionRequest(player: Player, kind: any, ammo: any, aim: any): string?
	local now = os.clock()
	local allowed, bucket = Limits.allow(registry:bucket(player, "action"), now, CONFIG.ACTION_RATE_LIMIT)
	registry:setBucket(player, "action", bucket)
	if not allowed then
		stats.rateDropped += 1
		return "rate-limited"
	end

	local id = Weapon.heldId(player) or Weapons.PRIMARY
	local row = Weapons.row(id) or Weapons.ROWS[Weapons.PRIMARY]
	local state = stateOf(player, id)
	if not state then
		return "untracked"
	end

	-- THE AMMO WHITELIST IS THIS WEAPON'S (task 140): `X` on a rifle with one kind is a
	-- `bad-request` at the wire, counted like any other, with no new branch below.
	local ok, why = Validator.checkRequest(kind, ammo, row)
	if not ok then
		stats.badRequests += 1
		publish(player, id, state)
		return why or "bad-request"
	end

	-- ----------------------------------------------------------------- THE AIM QUESTION (task 238)
	--
	-- KAREN, 2026-10-21: *"if you dont have a license when you aim and what to shoot it shows popup
	-- you dont have license"*. The client sends this ONCE on the rising edge of ADS, behind its own
	-- cooldown (`Input.aimAdviceDue`), and this answers *"what would stop you shooting the thing in
	-- front of you"* in the snapshot's `advice` field.
	--
	-- IT MOVES NOTHING. No reducer call, no `setState`, no shell, no `ShotFired`, no `SafetyViolated`
	-- and no hit -- it is a READ of the world plus one pure predicate. `state` is published exactly
	-- as it already was, which is why it cannot cost the player anything whatever he does with it.
	--
	-- IT ASKS `Rules.unlicensed` AND NOT `Rules.refuse`, and that is a decision. `Rules.refuse` walks
	-- all six questions in `Rules.ORDER`, and five of them -- the drive being over, his stand, his
	-- platform, a beater in the line -- have nothing to do with a licence and nothing on screen is
	-- built to receive them. Asking ONE question keeps this a narrow answer rather than a second
	-- reader of an order `Rules.ORDER` owns. Widening it later is one line here and a card there.
	--
	-- THE RANGE IS THE NEXT SHOT'S. The loaded shell when the gun is loaded, and the SELECTED kind
	-- when it is empty -- so the advice is about the shot he is about to take, and an empty gun still
	-- answers (a man who has just emptied it at a deer is exactly who needs telling).
	--
	-- Note: docs/research/2026-10-22-licence-popup-and-robux.md section 3.1
	if kind == "Aim" then
		-- `ORIGIN_TOLERANCE_STUDS` HERE TOO (task 260 round 2, the Reviewer's blocking finding 2).
		-- This payload is byte-identical to `FireRequest`'s -- `Input.fire` and `Input.aim` build it
		-- from the same two lines -- so bounding it at 15 studs here and 6 at the trigger would be
		-- two answers to one question, and the comment above this block promises the opposite.
		local okRay, whyRay = Validator.checkShot(aim, rootPositionOf(player), CONFIG, ORIGIN_TOLERANCE_STUDS)
		if not okRay then
			-- THE SAME VALIDATOR THE TRIGGER'S RAY GETS, so a forged origin is refused here on the
			-- same terms. Counted as a forgery, and NOTHING is published: a bad packet gets no
			-- answer at all.
			stats.badRequests += 1
			return whyRay or "bad-request"
		end
		local ammoAhead = state.loaded[state.selected] or state.ammo
		local range = row.RANGE_STUDS[ammoAhead]
		if type(range) ~= "number" then
			-- A DATA FAULT, NOT AN ANSWER. Every shipped row carries every kind's range; answering
			-- "nothing would stop you" off a missing number would be a popup that never appeared
			-- for a reason nobody could see.
			stats.badRequests += 1
			return "no-range"
		end
		local target = lookAhead(player, aim.origin, aim.direction, range)
		local advice: string? = nil
		-- UNKNOWN IS NOT "NO" (task 255). KAREN, 2026-10-24: *"I have redstag license but when I aim
		-- at the begining popup shows I need license"*. The popup is asked the same two questions
		-- the FIRE gate is asked, through the same one call, so the card on her screen and the
		-- refusal in her trigger can never disagree about whether anybody knows what she owns --
		-- which is the half of this the Director named: *"so a licensed shot is not refused early
		-- either"*. `askLicences`' header has the cause.
		local held, known = askLicences(player)
		if known and Rules.unlicensed(target, held) then
			advice = Rules.REASON.LICENCE
		end
		stats.aimQuestions += 1
		if advice ~= nil then
			stats.aimAdvised += 1
			-- FORCED PAST THE PUBLISH LIMITER, for the reason the refusal publish gives: an answer
			-- the client never hears is a question that did nothing for no visible reason. `notice`
			-- is nil -- the readout is not where this is said -- and `refused` is nil, so no dry
			-- click.
			publish(player, id, state, true, nil, nil, nil, nil, advice)
		end
		-- NOTHING IS PUBLISHED WHEN THERE IS NO ADVICE, which is the common case by far: he is
		-- licensed, or he is looking at a boar, a tree or the sky. A snapshot per aim-on carrying
		-- nothing would be one message per shoulder for every player in the drive.
		return nil
	end

	-- X, since Karen's playtest of 2026-09-25: switching the type RELOADS to it. Break returns the
	-- unfired shells of the old type to their own pocket, two of the new type go in, and the gun
	-- closes -- the same 2.0 s uninterruptible window as R, and no firing during it. An empty pocket
	-- of the new type does nothing at all, and says so on the Hud.
	if kind == "SelectAmmo" then
		if not state.equipped or state.open or now < state.busyUntil then
			publish(player, id, state)
			return "not-ready"
		end
		if (state.reserve[ammo] or 0) <= 0 then
			stats.emptySwaps += 1
			publish(player, id, state, true, "NO " .. string.upper(ammo))
			return "empty-pocket"
		end
		local swapped = StateMachine.apply(state, { kind = "SelectAmmo", ammo = ammo }, now, row)
		setState(player, id, swapped)
		publish(player, id, swapped, true)
		-- **IT EMPTIES THE GUN OF THE OLD SHELL FIRST (task 244).** KAREN, 2026-10-22: *"be sure
		-- when I shoot slugs it will be slug and when buck it will be buck on bot weapons"*. The
		-- side-by-side already did, because its own `CYCLE_EJECTS` is `"all"` -- you crack it over
		-- your arm and everything comes out. The SEMI-AUTO's is `"spent"`, which is right for the
		-- bolt after a shot and wrong for a man changing ammunition: a tube of five live buckshot
		-- has no empty chamber, so all five `Load`s answered `barrel-full`, the shells stayed buck,
		-- and `state.ammo` -- the SELECTION -- said Slug. MEASURED in the live Forest Test on her
		-- own path. `"all"` here is the hand that empties the magazine, and the unfired shells go
		-- back to their own pocket exactly as the side-by-side's already do.
		task.spawn(runCycle, player, id, swapped.epoch, row.RELOAD, "all")
		return nil -- the swap was accepted
	end

	-- "Reload": one thread per player. A second Reload while the action is open is rejected by the
	-- reducer's own "is-open", which is what makes the 2.0 s window uninterruptible (feel default 2).
	if not state.equipped or state.open or now < state.busyUntil then
		publish(player, id, state)
		return "not-ready"
	end
	local epoch = state.epoch
	-- R IS THE MAGAZINE CHANGE ON A WEAPON THAT HAS ONE (task 142), and the break-open sequence on
	-- one that does not: `row.RELOAD` is the whole of the difference.
	task.spawn(runCycle, player, id, epoch, row.RELOAD)
	return nil -- the reload was accepted
end

local function watchPlayer(player: Player)
	connections[player] = connections[player] or {}
	local function onCharacter()
		-- EVERY WEAPON IN THE LOADOUT, not just the primary (task 140). `refreshArming` grants what
		-- is missing and revokes what is no longer allowed, so it is idempotent and is the one path
		-- that knows how many guns a hunter carries.
		Weapon.refreshArming(player)
	end
	table.insert(connections[player], player.CharacterAdded:Connect(onCharacter))
	-- A NEW BACKPACK IS A NEW CHANCE. A respawn replaces it, and whichever order the engine
	-- delivers CharacterAdded and the new Backpack in, this is the moment a player who lost their
	-- gun with the old one can be given another (Task 34). refreshArming grants only if they are
	-- allowed one and are not already holding it, so this is idempotent.
	table.insert(
		connections[player],
		player.ChildAdded:Connect(function(child)
			if child:IsA("Backpack") then
				Weapon.refreshArming(player)
			end
		end)
	)
	if player.Character then
		onCharacter()
	end
end

-- THE SEAM A FORGED REQUEST ARRIVES THROUGH, reachable by parameter as well as by remote (Task 80).
-- `OnServerEvent` can only be raised by a client, so until now the only way to test "the server
-- ignores a request it must not accept" was from a Play client, watching this player's published
-- state for a change. That test could never be sound: THIS module is the only writer of that state
-- and it rewrites it on its own schedule -- `Weapon.grant` resets it and auto-equips, the arming
-- sweep calls grant again, a Reload is a multi-step cycle -- so "the state changed" and "the forged
-- request was accepted" are the same observation from the client. Task 80 measured a client run
-- failing for the first reason and reading as the second.
--
-- These two are the SAME functions `Weapon.start` connects to the remotes, not a copy: one owner, one
-- implementation, and a spec can hand them a player and a forged payload with nothing in flight.
-- `Weapon.stats().badRequests` is the counter that says the whitelist refused it.
Weapon.onActionRequest = onActionRequest
Weapon.onFireRequest = onFireRequest

function Weapon.start()
	assert(not started, "Weapon.start() called twice")
	started = true

	remotes = Shotgun.remotes()
	remotes.FireRequest.OnServerEvent:Connect(onFireRequest)
	remotes.ActionRequest.OnServerEvent:Connect(onActionRequest)

	-- THE ONE CLOCK THAT ADVANCES EVERY SHOT IN THE AIR (task 185). One connection for the whole
	-- server, made here and nowhere else: a grep for `flight:advance` under `src/` must find this
	-- site alone (design 4.3, 6.2).
	--
	-- `Weapon.castWithRewind` READS `castFn` PER CALL, not captured once, so the seam `Weapon.setCast` writes
	-- is the one the flight uses too -- which is what lets a spec's injected cast answer the pellets
	-- -- and it adds the task-305 rewound pass around it when the shot carries a `rewindSeconds`.
	RunService.Heartbeat:Connect(function(dt)
		local resolved = flight:advance(dt, Weapon.castWithRewind, Workspace:GetServerTimeNow())
		for _, res in ipairs(resolved) do
			onShotLanded(res)
		end
		-- The flight's own timeouts and refusals, mirrored into this owner's tally so one `stats()`
		-- answers everything. Both must stay 0 in every run.
		stats.flightTimeouts = flight.timedOut
		-- ...AND THE LAG COMPENSATION IT GRANTED (task 256). Mirrored here for the same reason and
		-- read the same way: 0.000 in any run with no network.
		stats.flightCatchUpSeconds = flight.catchUpSeconds
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	-- The sweep (above). It is the only thing here that is not edge-driven, and it exists because
	-- every edge in this system has now been seen to miss.
	task.spawn(function()
		while true do
			task.wait(ARMING_SWEEP_SECONDS)
			stats.armingSweeps += 1
			for _, player in ipairs(Players:GetPlayers()) do
				local wanted = mayArm(player)
				if wanted then
					-- ...AND IT IS COUNTED PER WEAPON (task 140, the Reviewer's finding 1). This read
					-- `holdsTool(player)` with no weapon id after that function became per weapon, so
					-- the table read answered nil, the call answered false, and the counter rose on
					-- EVERY sweep for EVERY armable player -- which would have destroyed the one
					-- instrument this repo has for "a player who should be holding a gun and is
					-- not" (`reviews/task-34/REQUEST.md`: *"armingRepairs has been 0 in every run
					-- since"*).
					-- HIS OWN LIST (task 178, the Reviewer's round-1 note), not the flag's whole one: with the
					-- shop on, a player who has not bought the rifle is CORRECTLY not holding one, and asking the
					-- unnarrowed list counted him as a repair on every sweep -- destroying the one instrument
					-- this counter exists to be ("a player who should be holding a gun and was not").
					for _, id in ipairs(Weapons.loadout(askOwned(player))) do
						if not holdsTool(player, id) then
							stats.armingRepairs += 1
						end
					end
				end
				pcall(Weapon.refreshArming, player)
			end
			-- AND THE LOOK, for a gun granted before the mesh landed (TASKS.md row 75a(h)).
			-- `WeaponBoot` upgrades once, the moment the preload returns; this is the same net the
			-- sweep above is -- the asset can arrive LATER than the preload budget, because a load
			-- that timed out is late rather than lost (`Loader` adopts it), and there is no signal
			-- for that. `Hardware.upgrade` is idempotent and never yields, so a pass that has
			-- nothing to do costs one child lookup per carried Tool.
			local ok, upgraded = pcall(Weapon.upgradeLook)
			if ok then
				stats.meshUpgrades += upgraded
			else
				-- COUNTED AND SAID ONCE, NOT SWALLOWED. A pcall whose failure goes nowhere is how a
				-- sweep that repairs nothing looks exactly like a sweep with nothing to repair.
				stats.meshUpgradeFails += 1
				if stats.meshUpgradeFails == 1 then
					warn(string.format("[Weapon] the mesh upgrade sweep failed: %s", tostring(upgraded)))
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		Weapon.forget(player)
	end)
end

return Weapon
