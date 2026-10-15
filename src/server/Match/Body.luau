--!strict
-- Match.Body: the only writer of a PLAYER's TEAM and of where their character stands. Named after
-- Boar/Body.luau, which has exactly this role for the boar: the module that touches Instances so
-- that nothing else in the system has to.
--
-- THE BOUNDARY IS THE PLAYER, AND SINCE TASK 161 THAT WORD IS LOAD-BEARING. `ServerScriptService.Bots`
-- is the only writer of a BOT RIG's Instances -- its `WalkSpeed`, its `Anchored` and its `CFrame` --
-- so the older reading of this sentence ("the only writer of WalkSpeed in src/, grepped", task 158)
-- is restated here rather than left standing to be found false:
--   * THIS module owns a PLAYER's character: its team, its position, its freeze, its clothes, and the
--     one `held` table, which is keyed by userId and which a bot therefore cannot even appear in.
--   * `Bots.Rig` owns a BOT's body. It never calls `Body.place`, `Body.hold`, `Body.stand`,
--     `Body.tie` or `Body.dressWhenLoaded` -- all five take a `Player`.
--   * THE ONE THING THEY SHARE IS THE OUTFIT, AND IT IS THIS MODULE'S. `Body.dress` takes a `Model`,
--     not a `Player`, so a bot rig is dressed by the one owner of dressing through the seam
--     `Bots.start{ dress = Match.Body.dress }` -- one dressing path, no copy of the outfit rows.
--     The accepted side effect, stated rather than discovered: `Body.accessoriesWorn()`,
--     `Body.slotsFellBack()` and `Body.repaints()` now count bots as well as players, and
--     `Bots.stats()` counts its own dressings separately so the two questions stay separable.
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
-- SINCE MILESTONE 1.7b IT ALSO TIES A PLAYER TO A TREE (design section 8.4) and owns
-- Workspace.DriveMarkers, the one runtime container this system creates -- one rope Part per tied
-- player and nothing else, ever (design section 6.4). Workspace is not Rojo-owned and the harness
-- compares the Edit-mode DataModel, so a run-time folder cannot dirty a run, exactly as
-- Workspace.WeaponEffects does not.
--   Humanoid.WalkSpeed  https://create.roblox.com/docs/reference/engine/classes/Humanoid#WalkSpeed
--     The stock PlayerModule drives movement through Humanoid:Move and never writes WalkSpeed, so
--     this is not a second writer of anything (the same boundary docs/design/camera.md section 6.3
--     records for the camera).
--   BasePart.Anchored   https://create.roblox.com/docs/reference/engine/classes/BasePart#Anchored
--     The belt to WalkSpeed's braces: the CHARACTER'S physics is owned by its own client, so a
--     server-side pivot alone is a suggestion the client can walk out of. Anchoring first makes the
--     pivot stick, which is why the order here is anchor-then-pivot and not the design's list order.
--
-- SINCE M2.8d IT ALSO DRESSES THE CHARACTER (map-generator design section 10): a shooter gets an
-- orange hat, a driver an orange vest. Same module, same signal, same discipline -- it is one more
-- thing written onto a character at the moment the team or the character changes, and the design
-- gives it this owner precisely so it never gets two (not the Hud, which draws the screen and not
-- the world; not the client, which cannot be trusted or screenshotted from the server).
--
-- SINCE TASK 151 THE OUTFIT HAS A BASE, AND EVERYBODY WEARS IT (beater-kit design sections 2-4).
-- Karen's design doc "Driven Hunt v1": the hunter wears a green jacket and green trousers plus an
-- orange hat; the beater wears the same green plus an orange hat AND an orange vest. So this module
-- gained three more writes on the same signals -- the base COLOUR, the removal of the player's own
-- clothing, and a short window that holds both against a late appearance load -- and it gained no
-- second writer: `BodyColors` is written here and nowhere else in the repo, and nothing anywhere
-- calls `Humanoid:ApplyDescription`, which would undo all of it from outside the owner.
--
-- Design: docs/design/beater-kit.md (THE design of what a character wears; it supersedes
--         map-generator section 10 and drive.md section 5.4 where they disagree),
--         docs/design/drive.md (sections 5.1, 5.3, 6.4, 8.4)
-- Note:   docs/research/2026-10-11-beater-kit.md, docs/research/2026-09-25-drive.md
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

local Body = {}

export type TeamName = "Drivers" | "Shooters"

-- THE BASE: a colour, which limbs take it, and what has to go so it can be seen (beater-kit
-- design section 3). `limbs` holds BodyColors property STEMS, not limb names: the property written
-- is `stem .. "Color3"`.
export type BaseRow = {
	color: Color3,
	limbs: { string },
	clearClasses: { string },
	clearLayered: boolean,
}

-- What a tied player's humanoid was before it was frozen, keyed by userId so nothing here holds a
-- Player (design section 7.2's discipline, applied to this table too). Written only by tie/untie.
local held: { [number]: { walkSpeed: number, jumpHeight: number, jumpPower: number } } = {}

-- ONE OPEN APPEARANCE WINDOW PER userId (beater-kit design section 5). Keyed by userId for the same
-- reason `held` is: nothing here holds a Player. Written only by watchAppearance and Body.forget.
local watching: {
	[number]: { character: Model, connection: RBXScriptConnection, closed: boolean },
} = {}

-- HOW FAR A FRESHLY PLACED CHARACTER MAY HAVE DRIFTED before `Body.settle` pivots it again, and
-- how many times that has happened (task 157). One stud is inside a character's own width, so a
-- settle can only ever mean "something else moved it", never "physics breathed".
local SETTLE_TOLERANCE_STUDS = 1
local settled = 0

-- HOW LONG A FRESHLY ADDED CHARACTER IS GIVEN TO BE PARENTED, and how many frames that has cost
-- (task 157). It is a FRAME or two in the one place that needs it and zero in the other, and the
-- ceiling is well inside `Match.CONFIG.PLACE_TIMEOUT` (5 s), which is what gives up on a placement.
local PARENT_WAIT_SECONDS = 2
local parentWaits = 0

-- THE PROOF, NOT A FEELING (design section 5's last paragraph). If `strayCleared` stays 0 on every
-- run and Karen sees green, the window caught nothing and its five seconds can be shortened or
-- dropped -- which is a number to read, not an opinion to hold.
local strayCleared = 0
local repaints = 0

local TEAM_COLORS = {
	Drivers = BrickColor.new("Bright blue"),
	Shooters = BrickColor.new("Bright orange"),
}

-- ------------------------------------------------------------------- M2.8d: the outfits
-- ONE FOLDER PER CHARACTER, destroyed and rebuilt (design section 10.2). Parented to the character,
-- which is what makes "removed on leave and on respawn" structural rather than a cleanup path: a
-- respawn replaces the character and takes its children with it, and so does leaving.
Body.OUTFIT_NAME = "HuntOutfit"

-- HUNTER ORANGE, RGB(255, 112, 0), the design's number, and the same one for both roles. In the
-- field both sides wear safety orange; what says WHICH side you are is the Hud's badge and the team
-- colour below. Director's pick and Karen's to change (her rule: styling never blocks).
local OUTFIT_COLOR = Color3.fromRGB(255, 112, 0)

-- THE GREY-BOX OUTFIT. The design's table (section 10.2) plus the fields it cannot express --
-- `shape`, `rotationDeg`, and since Task 82 `scale`/`pad`/`anchor`, which is how a row says "fit
-- yourself to the limb you are hung on" instead of naming studs that are only right for one avatar.
--
-- `fallbackLimb` is R6: an R15 character has `UpperTorso` and an R6 one has `Torso`. A missing limb
-- is a counted miss rather than a crash.
--
-- THE HAT IS TWO PARTS AND THE SCREENSHOT IS WHY (rule 5). The design's table is one flat cylinder,
-- 2.2 x 0.6 x 2.2 at +0.8 above the Head's centre, and that is exactly what was built and
-- photographed first (.screenshots/20260927T031301Z-task77-hat-2.png): a disc AT THE HAIR LINE that
-- the avatar's hair grows straight through. It measured perfectly -- the spec's 0.95 is still
-- asserted below -- and it read as an orange HALO, not headwear. A hat is a crown and a brim; one
-- disc at any height is a brim on its own, and this project has a whole page about things that
-- measure correct and look wrong (docs/PROJECT_CONTEXT.md).
--
-- So the brim keeps the design's 2.2 diameter and its place in the silhouette, thins to 0.35 and
-- rises to clear a default avatar's hair, and a short crown sits on it. The hat's rows keep their
-- STUDS, because Karen has seen this hat on a player and it reads (PLAYTEST.md, 2026-09-27).
--
-- AND THE VEST IS FOUR PLATES THAT WRAP THE TORSO, BECAUSE KAREN COULD NOT SEE THE OLD ONE.
-- PLAYTEST.md, 2026-09-27: "I can see hat on hunter but not vest on driver". The old row was one
-- 2.2 x 1.6 x 1.3 box CENTRED on the torso, and both halves of that are why it was invisible:
--   * CENTRED means most of it is INSIDE the limb. It stood 0.1 proud on each side of an R15
--     UpperTorso of (2, 1.6, 1) and 0.15 front and back -- and nothing in this game guarantees that
--     torso. `HumanoidDescription` body scaling, an R6 `Torso` and any avatar bundle change the box,
--     and a torso wider than 2.2 or deeper than 1.3 SWALLOWS a part with those numbers whole. A
--     number that is only right for one avatar is the class of bug here, not the vest.
--   * ONE PLATE HAS ONE FACE. Karen looks at a driver from the front, from behind (her own camera is
--     over her shoulder) and from a post 40-80 m away.
-- So a vest row now says its size and its offset as a FUNCTION OF THE LIMB (`Body.fit`): four
-- plates, one per horizontal face, each standing VEST_GAP clear of the limb's own surface whatever
-- that surface is, and the two side plates deep enough to close the wrap around the other two. The
-- deviation from the design's single `Vest` row is recorded in TASKS.md row 82a for the Architect.
-- The thickness, the gap and the 0.78 of the torso's height are the Director's pick and Karen's to
-- change (her rule: styling never blocks).
local VEST_THICKNESS = 0.22
-- CLEAR OF THE SURFACE, not flush with it. Two coplanar faces z-fight, and a plate exactly on the
-- surface also sits INSIDE any layered-clothing mesh that stands off the limb's own box.
local VEST_GAP = 0.12
local VEST_HEIGHT_FRACTION = 0.78 -- of the torso's height: a vest, not a barrel

-- THE GREEN, AND IT WAS MEASURED OFF THE SLEEVE'S OWN TEXTURE (research note section 3).
--
-- Karen, 2026-10-10 ~22:00, with a crop of her own first-person sleeve as the reference: "we need
-- same color by default what is our arms not gloves but arms green or whatever color is so all
-- clothe is that color". So the reference is an albedo, not an opinion -- and NOT the lit frame she
-- sent, whose sleeve pixels read about (105, 100, 78) with the viewmodel's own light on them.
--
-- The sleeve belongs to the two glove models ("Brown leather glove, olive jacket cuff",
-- src/serverstorage/Assets). Every used pixel of both prepped 1024x1024 `texture_baseColor.png`
-- maps was classified by hue; hue 35-100 degrees at saturation > 0.08 is the olive cuff and hue
-- 0-35 is the brown leather. THE TWO MAPS DISAGREE, because they were generated separately:
--   right glove  267,953 olive px  median (74, 67, 47)
--   left  glove  265,739 olive px  median (96, 92, 65)
--   both         533,692 olive px  median (86, 80, 56)   <- this number
-- Neither glove is "the" sleeve, so the base is the median over both. Matching the ALBEDO is the
-- right target: under the same light, a surface with the sleeve's albedo renders as the sleeve.
-- Karen's eye decides and this is one line (beater-kit design section 17 item 1).
Body.BASE_COLOR = Color3.fromRGB(86, 80, 56)

-- ONE BASE, AND BOTH ROLES POINT AT THIS TABLE (design section 3). Same identity, so "everyone
-- wears the same green" is structural rather than six numbers written out twice -- and a team swap
-- cannot re-decide the colour, because there is nothing to re-decide.
--
-- `limbs` are BodyColors property STEMS and `Head` IS DELIBERATELY ABSENT: the head keeps the
-- player's own colour, so a dressed player reads as a person in a green outfit rather than as a
-- green person.
--
-- `clearClasses` and `clearLayered` exist because A COLOUR WRITTEN ON A LIMB IS INVISIBLE UNDER
-- ANYTHING DRAWN OVER THE LIMB: a classic Shirt/Pants is a texture on it, and a layered-clothing
-- accessory is a MESH STANDING OFF it (Roblox's own appearance page, quoted in the note's section
-- 4.1). Nothing is backed up and nothing is restored -- see `Body.strip`.
local BASE: BaseRow = {
	color = Body.BASE_COLOR,
	limbs = { "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" },
	clearClasses = { "Shirt", "Pants", "ShirtGraphic" },
	clearLayered = true,
}
Body.BASE = BASE

-- THE HEAD'S OWN THINGS ARE SPARED (design section 6). A hat, hair, a face, eyebrows and eyelashes
-- are not what hides a torso, and taking a player's hair off to show a green chest would be a cost
-- with no benefit. `Body.isLayered` checks this list FIRST.
Body.SPARED_ACCESSORY_TYPES = {
	Enum.AccessoryType.Hat,
	Enum.AccessoryType.Hair,
	Enum.AccessoryType.Face,
	Enum.AccessoryType.Eyebrow,
	Enum.AccessoryType.Eyelash,
}

-- HOW LONG THE WINDOW STAYS OPEN over one character (design section 5).
--
-- A character's APPEARANCE IS APPLIED ASYNCHRONOUSLY, after the model exists -- which is why
-- `Player.CharacterAppearanceLoaded` and `Player:HasAppearanceLoaded()` exist at all. The welded
-- parts survive whatever the engine does next; a `BodyColors` write and a destroyed `Shirt` do not,
-- because the avatar's own shirt and body colours may land AFTER ours. So the dress is not ordered
-- against that load at all: it happens at once, and then this window holds it.
--
-- NOT `CharacterAppearanceLoaded` AS THE TRIGGER, deliberately: `HasAppearanceLoaded()` is a
-- PLAYER-level fact and the event can have fired before a handler connects, so either form of "wait
-- for the event" can lose the very race the window cannot. The event could later close the window
-- early -- an optimisation, never a correctness condition.
local APPEARANCE_WATCH_SECONDS = 5
-- PUBLISHED so a spec waits THIS and not a 5 copied out of here. Review round 1, finding 1: the
-- window had no test at all, and a test that hard-codes the number it is waiting for goes quietly
-- wrong the day the number moves.
Body.APPEARANCE_WATCH_SECONDS = APPEARANCE_WATCH_SECONDS

-- THE HAT IS DECLARED ONCE AND WORN BY BOTH ROLES (design section 3). Karen's doc gives the hunter
-- an orange hat and the beater an orange hat AND an orange vest, so a second copy of these two rows
-- would be two answers to one question -- this project's named failure mode, in a table.
-- EACH GROUP NOW CARRIES A SLOT NAME (task 151 round 2). A slot is a thing a character wears, in
-- THIS module's own vocabulary -- "hat", "vest" -- and never an asset key or an id: `Match.Body`
-- must not learn what `ServerStorage.Assets` calls anything. The composition root translates, which
-- is the same seam `Boar.setModelSource` uses for what a boar looks like.
--
-- THE ROWS BELOW ARE THE FALLBACK, NOT THE DEFAULT. If a real catalog accessory is loaded for a
-- slot, it is worn and these rows are not built; if the load failed, or nobody wired a source, or
-- the character has no Humanoid to hang an accessory on, they are built exactly as before. Karen
-- has seen these plates read on a player (PLAYTEST.md 2026-09-27), so the fallback is a known-good
-- picture rather than a guess.
local HAT_ROWS = {
	{
		name = "Hat", -- the brim
		limb = "Head",
		fallbackLimb = nil,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.35, 2.2, 2.2), -- world box 2.2 x 0.35 x 2.2 after the turn below
		rotationDeg = Vector3.new(0, 0, 90),
		offset = Vector3.new(0, 0.95, 0), -- above the Head's CENTRE, which is what a Position is
		color = OUTFIT_COLOR,
	},
	{
		name = "HatCrown",
		limb = "Head",
		fallbackLimb = nil,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.7, 1.35, 1.35),
		rotationDeg = Vector3.new(0, 0, 90),
		offset = Vector3.new(0, 1.42, 0),
		color = OUTFIT_COLOR,
	},
}

-- FOUR PLATES, ONE PER HORIZONTAL FACE. `scale` is a multiple of the limb's own size, `pad` is
-- studs added to it, and `anchor` is which face to sit on in halves of the limb (so -1 on Z is
-- the -Z face). A character's front is its -Z, but the front and back plates are identical on
-- purpose: a wrap has no front, so nothing here depends on which way a limb happens to face.
--
-- THE FIELD AGREES WITH THE FOUR PLATES, measured in a jurisdiction that writes it down: Texas
-- requires 400 square inches of hunter orange with at least 144 of them on the CHEST and 144 on the
-- BACK (research note section 2), arrived at for the reason Karen reported -- a beater is looked at
-- from every side.
local VEST_ROWS = {
	{
		name = "VestFront",
		limb = "UpperTorso",
		fallbackLimb = "Torso",
		shape = Enum.PartType.Block,
		scale = Vector3.new(0.98, VEST_HEIGHT_FRACTION, 0),
		pad = Vector3.new(0, 0, VEST_THICKNESS),
		anchor = Vector3.new(0, 0, -1),
		offset = Vector3.new(0, 0, -(VEST_THICKNESS / 2 + VEST_GAP)),
		rotationDeg = Vector3.zero,
		color = OUTFIT_COLOR,
	},
	{
		name = "VestBack",
		limb = "UpperTorso",
		fallbackLimb = "Torso",
		shape = Enum.PartType.Block,
		scale = Vector3.new(0.98, VEST_HEIGHT_FRACTION, 0),
		pad = Vector3.new(0, 0, VEST_THICKNESS),
		anchor = Vector3.new(0, 0, 1),
		offset = Vector3.new(0, 0, VEST_THICKNESS / 2 + VEST_GAP),
		rotationDeg = Vector3.zero,
		color = OUTFIT_COLOR,
	},
	{
		-- The sides are as DEEP as the wrap needs to be closed: the limb plus both plates and
		-- both gaps, so there is no orange-free corner to look at a driver through.
		name = "VestLeftSide",
		limb = "UpperTorso",
		fallbackLimb = "Torso",
		shape = Enum.PartType.Block,
		scale = Vector3.new(0, VEST_HEIGHT_FRACTION, 1),
		pad = Vector3.new(VEST_THICKNESS, 0, 2 * (VEST_THICKNESS + VEST_GAP)),
		anchor = Vector3.new(-1, 0, 0),
		offset = Vector3.new(-(VEST_THICKNESS / 2 + VEST_GAP), 0, 0),
		rotationDeg = Vector3.zero,
		color = OUTFIT_COLOR,
	},
	{
		name = "VestRightSide",
		limb = "UpperTorso",
		fallbackLimb = "Torso",
		shape = Enum.PartType.Block,
		scale = Vector3.new(0, VEST_HEIGHT_FRACTION, 1),
		pad = Vector3.new(VEST_THICKNESS, 0, 2 * (VEST_THICKNESS + VEST_GAP)),
		anchor = Vector3.new(1, 0, 0),
		offset = Vector3.new(VEST_THICKNESS / 2 + VEST_GAP, 0, 0),
		rotationDeg = Vector3.zero,
		color = OUTFIT_COLOR,
	},
}

-- KAREN'S TWO SENTENCES, AS TWO ROWS (design section 3). "Hunter will have default green pens and
-- jacket / Also will have orange hat / Beater will have orange hat and orange vest / Default also
-- green pans and green jacket" -- so: hunter = base + hat, beater = base + hat + vest.
-- A GROUP: one worn thing, its slot, the parts to build when no accessory is available, and which
-- of the character's OWN attachments the real accessory needs cleared.
export type Group = { slot: string, rows: { any }, clears: { string } }

-- A REAL CAP IS SWALLOWED BY A BIG HAIR MESH, AND THIS IS THE MEASUREMENT (task 151 round 2).
-- Looked at the preview and the hunter was wearing a BLACK cap with an orange peak. He was not: our
-- cap was on correctly -- `SolidCap`, 2.01 x 0.93 x 1.43 studs, on `HatAttachment` -- and the black
-- was the avatar's OWN hair, 2.08 x 2.05 x 1.94 studs on `HairAttachment`, a bowl twice the cap's
-- height sitting in the same place. Only the orange peak came out of it.
--
-- The grey-box hat never had this problem because Task 77 RAISED its crown to clear a default
-- avatar's hair (see the OUTFITS header). A catalog accessory cannot be raised: it hangs where its
-- own attachment puts it, which is the whole reason the engine welds it rather than us.
--
-- So each group names the attachments its real accessory needs clear, and `wearAccessory` takes off
-- the character's own accessories on those -- AND ONLY WHEN A REAL ACCESSORY IS ACTUALLY WORN.
-- With the plates, hair stays: they were built to live with it. This is a narrower rule than
-- `Body.strip`'s spare list and it does not change it -- strip still never touches a hat or hair.
local HAT: Group = { slot = "hat", rows = HAT_ROWS, clears = { "HatAttachment", "HairAttachment" } }
-- The vest hangs off the torso's front; a player's own front or back torso accessory would fight it
-- for the same space. Nothing on the head or the limbs is touched.
local VEST: Group = { slot = "vest", rows = VEST_ROWS, clears = { "BodyFrontAttachment", "BodyBackAttachment" } }

local OUTFITS: { [string]: { base: BaseRow, parts: { Group } } } = {
	Shooters = { base = BASE, parts = { HAT } },
	Drivers = { base = BASE, parts = { HAT, VEST } },
}

-- THE SLOT NAMES, published so the composition root and a spec name them from one place rather than
-- typing a literal each (the `Map.TAGS` rule).
Body.SLOTS = table.freeze({ hat = "hat", vest = "vest" })

-- KAREN'S WORD -> THE TEAM NAME, in exactly one place (design section 3, "Naming"). She says beater
-- and hunter; the code says `Drivers` and `Shooters`, and those strings reach `Match.Roster`,
-- `tests/client/Role.luau`, the Hud's badge and a dozen specs. Renaming them is its own task
-- (design section 17 item 5); until then this is the one translator and there is no second mapping.
Body.ROLE_WORDS = { hunter = "Shooters", beater = "Drivers" }

-- What every fitted plate keeps between itself and the limb's surface, published so a spec asserts
-- the invariant rather than a number copied out of this file.
Body.VEST_GAP = VEST_GAP
Body.VEST_THICKNESS = VEST_THICKNESS
Body.VEST_HEIGHT_FRACTION = VEST_HEIGHT_FRACTION

-- ------------------------------------------------------------------- the bought look (task 178)

-- WHAT ONE PLAYER'S OUTFIT LOOKS LIKE, as far as this module is concerned: a colour, and nothing
-- else. `Match.Body` IS HANDED A COLOUR AND NEVER AN OWNERSHIP SET -- the module that dresses people
-- must not learn what a shop is, which is exactly the seam `Body.setAccessorySource` already is in
-- its own words (*"`Match.Body` must not learn what `ServerStorage.Assets` calls anything. The
-- composition root translates"*).
export type Look = { hatColor: Color3? }

-- INJECTED AT THE COMPOSITION ROOT, the `setAccessorySource` shape. nil -- no provider, or a player
-- who has bought nothing -- is TODAY'S GAME: hunter orange, `OUTFIT_COLOR`.
--
-- IT IS A PROVIDER AND NOT ONLY A PARAMETER, and the reason is measured rather than stylistic: this
-- module re-dresses a character from THREE of its own paths (the appearance window's close, the
-- respawn watch, and the tie/untie), and a `look` threaded through only the outside callers would
-- put the orange hat back on a man who had bought a red one the first time he respawned. The
-- explicit parameter stays for the specs and for a caller that knows better; the provider is the
-- default every internal path reads.
local lookProvider: ((Player) -> Look?)? = nil

function Body.setLookProvider(fn: ((Player) -> Look?)?)
	lookProvider = fn
end

function Body.lookProvider(): ((Player) -> Look?)?
	return lookProvider
end

-- THROUGH A pcall, the rule every provider in this repo follows: a provider that errors must not
-- leave a player undressed, and must not silently change what everybody wears. It falls back to
-- nil, which is today's outfit.
local function askLook(player: Player): Look?
	if lookProvider == nil then
		return nil
	end
	local ok, look = pcall(lookProvider :: any, player)
	return if ok and type(look) == "table" then look else nil
end

-- PURE. WHICH COLOUR A SLOT IS WORN IN: the bought one for the hat, and nil -- "the row's own" --
-- for everything else.
--
-- THE VEST IS NOT RECOLOURED, and that is a rule rather than an omission: it is safety orange on
-- both roles for the reason `OUTFIT_COLOR`'s comment gives (*"In the field both sides wear safety
-- orange"*). One cosmetic, one slot, this task.
function Body.tintFor(slot: string?, look: Look?): Color3?
	if look == nil or slot ~= Body.SLOTS.hat then
		return nil
	end
	return look.hatColor
end

-- PURE, and the whole of the fix. (size, offset) for one row on a limb of THIS size:
--   size   = limbSize * row.scale + row.pad
--   offset = limbSize/2 * row.anchor + row.offset
-- A row with no `scale` is a row in studs (the hat) and comes back exactly as written, so this is
-- the same function for both roles and there is no second code path to keep in step.
--
-- Because the offset is measured from the limb's own half-extent, the plate's INNER face lands
-- `VEST_GAP` clear of the limb's surface on ANY avatar: an R15 torso, an R6 `Torso`, a scaled one,
-- or a bundle nobody has seen yet. That is the invariant match_outfit.spec asserts over three
-- different torsos, and it is what the old hard-coded 2.2 x 1.6 x 1.3 could not promise.
function Body.fit(row: any, limbSize: Vector3): (Vector3, Vector3)
	if not row.scale then
		return row.size, row.offset
	end
	local scale, pad = row.scale, row.pad or Vector3.zero
	local anchor = row.anchor or Vector3.zero
	local size = Vector3.new(limbSize.X * scale.X + pad.X, limbSize.Y * scale.Y + pad.Y, limbSize.Z * scale.Z + pad.Z)
	local offset = Vector3.new(
		limbSize.X / 2 * anchor.X + row.offset.X,
		limbSize.Y / 2 * anchor.Y + row.offset.Y,
		limbSize.Z / 2 * anchor.Z + row.offset.Z
	)
	return size, offset
end

-- PURE (design section 10.2). Takes the team and the config, touches no Instance, and answers the
-- same way whether or not there is a game running -- which is what lets a spec drive BOTH states of
-- the flag with nothing to restore (feature-flags.md 13.3).
--
-- The switch is READ FROM THE CONFIG, not from `Flags` directly: `Match.CONFIG.OUTFITS_ENABLED` is
-- the one boundary read (CLAUDE.md, "Feature flags"), and passing it inward as a parameter is what
-- makes the ON branch reachable while the flag sits OFF.
function Body.dressFor(team: TeamName?, config, look: Look?): { any }
	local outfit = Body.outfitFor(team, config)
	if not outfit then
		return {}
	end
	-- FLATTENED IN DECLARATION ORDER: the hat first, then the vest (design section 4). The groups
	-- exist so the hat is declared once; a caller still sees one list of rows, which is why
	-- `Body.dress` and every existing spec case are unchanged in shape.
	local rows = {}
	for _, group in ipairs(outfit.parts) do
		local tint = Body.tintFor((group :: any).slot, look)
		for _, row in ipairs(group.rows) do
			if tint ~= nil then
				-- A COPY, because the declared rows are this module's own frozen vocabulary and a
				-- bought colour belongs to ONE player. Editing the row would be one purchase changing
				-- what everybody on the server wears.
				local tinted = table.clone(row)
				tinted.color = tint
				table.insert(rows, tinted)
			else
				table.insert(rows, row)
			end
		end
	end
	return rows
end

-- PURE. The whole outfit for a role -- its base and its part groups -- or nil when there is nothing
-- to wear. The one place the flag and the team are turned into "is anybody being dressed", so
-- `dressFor` and `baseFor` can never disagree about that answer.
function Body.outfitFor(team: TeamName?, config): { base: BaseRow, parts: { { any } } }?
	if not team or not (config and config.OUTFITS_ENABLED) then
		return nil
	end
	return OUTFITS[team]
end

-- PURE. This role's base clothing, or nil. Both roles share ONE table, so this answers the same
-- table for a hunter and a beater and a spec asserts that with `==`.
function Body.baseFor(team: TeamName?, config): BaseRow?
	local outfit = Body.outfitFor(team, config)
	return if outfit then outfit.base else nil
end

-- PURE. Karen's word for a role -> the team name, or nil for anything else (design section 3). The
-- ONE translator: no other file turns "beater" into "Drivers".
function Body.teamForWord(word: string?): TeamName?
	if not word then
		return nil
	end
	return (Body.ROLE_WORDS[word] :: any) :: TeamName?
end

-- PURE. Would this instance hide a limb's colour? (design section 6)
--
-- IT ASKS FOR THE WRAP OBJECTS AND NOT FOR `AccessoryType`, and the reason is what layered clothing
-- IS: a mesh standing off the limb's own surface, which is why no colour written to the limb can
-- show through one (Roblox's appearance page, quoted in the note's section 4.1). `AccessoryType` is
-- the catalog's taxonomy -- it is `Unknown` on anything a spec builds, and it was `Unknown` on every
-- real catalog accessory probed for this task -- so it is used ONLY for the spare list below, where
-- being wrong costs a hat rather than the design.
--
-- THE SPARE CHECK RUNS FIRST, so a hat that happens to carry a wrap is still spared: nothing in
-- Karen's doc asks for hair or head accessories to go, and the orange hat was built to clear a
-- default avatar's hair (Task 77).
function Body.isLayered(instance: Instance): boolean
	if not instance:IsA("Accoutrement") then
		return false
	end
	if instance:IsA("Accessory") then
		for _, spared in ipairs(Body.SPARED_ACCESSORY_TYPES) do
			if instance.AccessoryType == spared then
				return false
			end
		end
	end
	return instance:FindFirstChildWhichIsA("WrapTarget", true) ~= nil
		or instance:FindFirstChildWhichIsA("WrapLayer", true) ~= nil
end

-- WRITES. Takes off whatever the player's own avatar was wearing that would hide the base, and
-- returns how many instances it removed. A nil base removes nothing: with the flag off, nobody's own
-- clothes are touched (design section 7).
--
-- NOTHING IS BACKED UP AND NOTHING IS RESTORED (design N4). A player's own clothes come back on
-- their NEXT CHARACTER, because the engine loads the avatar's appearance onto a new one; within this
-- character they are gone. That is the honest behaviour, and a saved copy would be a second
-- representation of a fact the avatar already owns.
function Body.strip(character: Model?, base: BaseRow?): number
	if not character or not base then
		return 0
	end
	local removed = 0
	-- A COPY OF THE CHILD LIST, because destroying while iterating `GetChildren` is iterating a list
	-- that is being rewritten. `GetChildren` already returns a fresh array, so this is that array.
	for _, child in ipairs(character:GetChildren()) do
		local clear = false
		for _, className in ipairs(base.clearClasses) do
			if child:IsA(className) then
				clear = true
				break
			end
		end
		if not clear and base.clearLayered and Body.isLayered(child) then
			clear = true
		end
		if clear then
			child:Destroy()
			removed += 1
		end
	end
	return removed
end

-- WRITES THE GREEN. Finds or creates the character's ONE `BodyColors` and writes `base.limbs` to
-- `base.color`. Never writes `HeadColor3`: the head is the player's own (design M5).
--
-- `BodyColors` HAS ONE PROPERTY PER R6 LIMB AND THE ENGINE MAPS THEM ONTO AN R15 RIG'S PARTS, so
-- this is the same five writes on both rigs and a missing limb is NOT a miss here -- there is no
-- limb to look for. It returns false only when it could not find or create the instance at all,
-- which is the `Body.tie` discipline: false means "I failed to do something I should have".
--
-- FOUND-OR-CREATED RATHER THAN ALWAYS NEW, so dressing twice leaves one instance and a stray one
-- the engine added later is written to rather than fought with.
--
-- IT PAINTS EVERY `BodyColors` ON THE CHARACTER, NOT THE FIRST ONE, and that is not tidiness -- it is
-- the bug the first version of this function shipped with, caught by its own spec on the gate's first
-- run. A character that already carries ours and is then handed one by the appearance load has TWO,
-- and `FindFirstChildOfClass` answers whichever comes first in child order; the engine honours
-- whichever it honours. Painting all of them makes the answer the same either way, which is the only
-- form of this write that cannot depend on an order nothing here controls.
function Body.paint(character: Model?, base: BaseRow?): boolean
	if not character or not base then
		return false
	end
	local painted = 0
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("BodyColors") then
			for _, stem in ipairs(base.limbs) do
				(child :: any)[stem .. "Color3"] = base.color
			end
			painted += 1
		end
	end
	if painted == 0 then
		local colors = Instance.new("BodyColors")
		colors.Name = "BodyColors"
		for _, stem in ipairs(base.limbs) do
			(colors :: any)[stem .. "Color3"] = base.color
		end
		colors.Parent = character
		painted = 1
	end
	repaints += 1
	return painted > 0
end

-- Is THIS user's appearance window open? Exact, and unlike the count below it cannot be answered
-- by somebody else's window -- which is what a spec needs when a live server is dressing real
-- players beside it (review round 1, finding 1).
function Body.isWatching(userId: number): boolean
	return watching[userId] ~= nil
end

-- How many appearance windows are open. Must come back to 0: a window that never closed is a
-- connection held against a character that is gone (design section 4's leak proof).
function Body.appearanceWatching(): number
	local n = 0
	for _ in pairs(watching) do
		n += 1
	end
	return n
end

-- How many of the player's own clothing instances arrived AFTER the dress and were taken off by the
-- window, and how many paints have been done. Read by a spec and printed in the harness note.
function Body.strayCleared(): number
	return strayCleared
end

function Body.repaints(): number
	return repaints
end

-- DRESSES ONE CHARACTER. Destroys any existing outfit first, so it is idempotent and a team swap is
-- a re-dress rather than two hats.
--
-- Returns false only when it FAILED to do something it should have -- no character, or no limb to
-- hang the item on -- so the caller can count a miss rather than believe a change it did not make
-- (the `Body.tie` discipline). With the flag off there is nothing to do and that is a success, not a
-- miss: the folder is still cleared, so switching the flag off undresses at the next respawn.
--
-- FOUR PROPERTIES THAT ARE NOT TIDINESS (design section 10.2):
--   * `CanQuery = false`. A hat that stops a pellet changes what the shot hit, and what the shot hit
--     is what `Match.Penalty.judge` reads through the weapon's report. The outfit must be invisible
--     to every ray in the game. This is the one the client spec asserts.
--   * `Massless = true` and NOT anchored. `Body.tie` anchors the ROOT; an anchored hat would pin a
--     character's head to the world.
--   * `CanTouch = false`, which the design's list does not name and `Weapon.Hardware.addPiece` sets
--     for the same reason: a cosmetic part should not fire a Touched event at anything.
--   * `CastShadow = false`: a shadow is the only thing a hat could cost that a player would see.
--
-- THE FOLDER IS PARENTED FIRST, THEN THE PARTS, THEN THE WELDS. A `WeldConstraint` records the
-- offset the parts happen to have when it is enabled and needs both of them in the DataModel --
-- `src/server/Boar/Body.luau` says so where it uses one, and `Weapon.Hardware` uses a legacy Weld
-- instead precisely because its Tool is not parented anywhere yet. Here the character IS live, so
-- the design's WeldConstraint is the right one and the order is what makes it work.
-- ------------------------------------------------- the real catalog accessories (task 151 round 2)
--
-- WHERE A SLOT'S TEMPLATE COMES FROM, injected by the composition root and nil until it is. This
-- module must not require `ServerStorage.Assets`: an owner requiring another owner is what
-- `Boar.setModelSource` exists to avoid, and the mapping from a slot ("hat") to an asset key
-- ("outfit.cap") belongs in the boot script that knows both.
--
-- The function is handed a SLOT and answers a TEMPLATE to clone, or nil. nil is not an error: it
-- means "wear the grey box", which is `Assets.Loader.template`'s own contract and is why the plates
-- below are kept rather than deleted.
local accessorySource: ((string) -> Instance?)? = nil

function Body.setAccessorySource(fn: ((string) -> Instance?)?)
	accessorySource = fn
end

function Body.accessorySource(): ((string) -> Instance?)?
	return accessorySource
end

-- How many real accessories have been put on a character, and how many slots fell back to plates.
-- Numbers rather than a feeling: if `accessoriesWorn` is 0 on a live run, the catalog load failed
-- and the game is wearing grey boxes that look deliberate.
local accessoriesWorn = 0
local slotsFellBack = 0

function Body.accessoriesWorn(): number
	return accessoriesWorn
end

function Body.slotsFellBack(): number
	return slotsFellBack
end

-- THE ACCESSORIES THIS MODULE PUT ON, AND ONLY THOSE. `Humanoid:AddAccessory` parents the accessory
-- to the CHARACTER, not into `HuntOutfit`, so the folder's destroy-and-rebuild does not clean them
-- up and a re-dress would leave a player in two hats. Every one we add carries this attribute, and
-- `undressAccessories` destroys exactly the children that carry it -- so a player's OWN hat, which
-- `Body.strip` deliberately spares, can never be taken off by this path either.
local ACCESSORY_TAG = "HuntOutfitAccessory"
Body.ACCESSORY_TAG = ACCESSORY_TAG

local function undressAccessories(character: Model): number
	local removed = 0
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accoutrement") and child:GetAttribute(ACCESSORY_TAG) ~= nil then
			child:Destroy()
			removed += 1
		end
	end
	return removed
end

-- Puts one slot's real accessory on `character`, or returns false so the caller builds the plates.
--
-- IT NEEDS A HUMANOID, and that is why the plates can never go away: `AddAccessory` is a Humanoid
-- method, and the rigs every spec in this file builds have none. A character with no Humanoid wears
-- the fallback, which is the same answer it has always had.
-- The character's OWN accessories hanging on any of `attachments`, destroyed. It never touches one
-- of ours -- those carry `ACCESSORY_TAG` and are removed by `undressAccessories` instead -- and it
-- is called only when a real accessory is about to take that place, so nothing is removed to make
-- room for something that then fails to arrive.
local function clearAttachments(character: Model, attachments: { string }): number
	local removed = 0
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accoutrement") and child:GetAttribute(ACCESSORY_TAG) == nil then
			local handle = child:FindFirstChild("Handle")
			-- EVERY attachment on the handle, not the first one (review round 1, note). An
			-- accessory may carry several -- that is how one mesh is offered for more than one
			-- slot -- and asking only `FindFirstChildWhichIsA` would miss the one this group named
			-- whenever it is not the first child.
			if handle then
				local hit = false
				for _, inner in ipairs(handle:GetChildren()) do
					if inner:IsA("Attachment") then
						for _, name in ipairs(attachments) do
							if inner.Name == name then
								hit = true
								break
							end
						end
					end
					if hit then
						break
					end
				end
				if hit then
					child:Destroy()
					removed += 1
				end
			end
		end
	end
	return removed
end

local function wearAccessory(character: Model, group: Group, tint: Color3?): boolean
	local slot = group.slot
	local source = accessorySource
	if not source then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	local ok, template = pcall(source, slot)
	if not ok or template == nil then
		return false
	end
	-- The template is whatever `InsertService:LoadAsset` answered with -- a Model holding one
	-- Accessory -- or an Accessory already. Both are accepted, so the boot may hand over either.
	local clone = (template :: Instance):Clone()
	local accessory = if clone:IsA("Accoutrement") then clone else clone:FindFirstChildWhichIsA("Accoutrement")
	if not accessory then
		clone:Destroy()
		return false
	end
	if accessory ~= clone then
		accessory.Parent = nil
		clone:Destroy()
	end
	accessory:SetAttribute(ACCESSORY_TAG, slot)
	-- THE SAME FOUR PROPERTIES THE PLATES CARRY, for the same reasons (design section 10.2). The one
	-- that is not tidiness is `CanQuery = false`: a vest that stops a pellet changes what the shot
	-- hit, and what the shot hit is what `Match.Penalty.judge` reads through the weapon's report.
	for _, d in ipairs(accessory:GetDescendants()) do
		if d:IsA("BasePart") then
			-- THE BOUGHT COLOUR REACHES THE REAL ACCESSORY TOO (task 178), written in the same loop
			-- that already writes the five properties below. A cosmetic that only showed on the
			-- fallback plates would be a purchase Karen cannot see the moment the catalogue cap loads
			-- -- and this repo has a whole page about things that measure correct and look wrong.
			if tint ~= nil then
				d.Color = tint
			end
			d.CanQuery = false
			d.CanTouch = false
			d.CanCollide = false
			d.CastShadow = false
			d.Massless = true
		end
	end
	-- MAKE ROOM ONLY NOW, with the accessory built and about to go on: if anything above had failed
	-- the character would still be wearing their own hair and the plates would be built over it,
	-- exactly as before this task.
	clearAttachments(character, group.clears)
	local worked = pcall(function()
		humanoid:AddAccessory(accessory)
	end)
	if not worked or accessory.Parent == nil then
		accessory:Destroy()
		return false
	end
	accessoriesWorn += 1
	return true
end

function Body.dress(character: Model?, team: TeamName?, config, look: Look?): boolean
	if not character or not character.Parent then
		return false
	end
	local existing = character:FindFirstChild(Body.OUTFIT_NAME)
	if existing then
		existing:Destroy()
	end
	-- AND THE REAL ACCESSORIES THIS MODULE PUT ON LAST TIME (task 151 round 2). They live on the
	-- character rather than in the folder, so destroying the folder does not reach them and a
	-- re-dress would be a second hat.
	undressAccessories(character)
	-- THE BASE GOES ON FIRST, AND IT IS THE SAME WORK ON THE SAME SIGNAL (Task 151, design section
	-- 4): take off what would hide it, then write the colour. `strip` and `paint` both answer
	-- "nothing to do" for a nil base, so the flag-off branch below is reached with nobody's own
	-- clothes touched.
	local base = Body.baseFor(team, config)
	Body.strip(character, base)
	if base and not Body.paint(character, base) then
		-- A base was wanted and the colour could not be written: that is a failure to do something
		-- this module should have done, which is what a false return means here.
		return false
	end
	local outfit = Body.outfitFor(team, config)
	if not outfit then
		return true -- nothing to wear: the flag is off, or this player has no team
	end
	-- EACH GROUP IS ONE WORN THING: the real catalog accessory if one is loaded and this character
	-- can take it, and otherwise the plates. Never both, which is what makes the count per role a
	-- thing a spec can assert.
	local rows = {}
	for _, group in ipairs(outfit.parts) do
		local tint = Body.tintFor((group :: any).slot, look)
		if wearAccessory(character, group, tint) then
			continue
		end
		slotsFellBack += 1
		for _, row in ipairs(group.rows) do
			if tint ~= nil then
				local tinted = table.clone(row)
				tinted.color = tint
				table.insert(rows, tinted)
			else
				table.insert(rows, row)
			end
		end
	end
	if #rows == 0 then
		return true -- every slot is wearing a real accessory, so there are no plates to build
	end
	local folder = Instance.new("Folder")
	folder.Name = Body.OUTFIT_NAME
	folder.Parent = character
	local made = 0
	for _, row in ipairs(rows) do
		local limb = character:FindFirstChild(row.limb)
		if not limb and row.fallbackLimb then
			limb = character:FindFirstChild(row.fallbackLimb)
		end
		if limb and limb:IsA("BasePart") then
			-- FITTED TO THE LIMB THAT WAS ACTUALLY FOUND, not to the one the row hoped for: an
			-- R6 `Torso` and a scaled R15 `UpperTorso` are different boxes and the vest wraps both.
			local size, offset = Body.fit(row, limb.Size)
			local part = Instance.new("Part")
			part.Name = row.name
			part.Shape = row.shape
			part.Size = size
			part.Color = row.color
			part.Material = Enum.Material.SmoothPlastic
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.CFrame = limb.CFrame
				* CFrame.new(offset)
				* CFrame.Angles(math.rad(row.rotationDeg.X), math.rad(row.rotationDeg.Y), math.rad(row.rotationDeg.Z))
			part.Parent = folder
			local weld = Instance.new("WeldConstraint")
			weld.Name = row.name .. "Weld"
			weld.Part0 = limb
			weld.Part1 = part
			weld.Parent = part
			made += 1
		end
	end
	if made == 0 then
		folder:Destroy()
		return false
	end
	return true
end

-- Closes this user's appearance window, if one is open. Idempotent.
local function stopWatching(userId: number)
	local row = watching[userId]
	if not row then
		return
	end
	row.closed = true
	row.connection:Disconnect()
	watching[userId] = nil
end

-- DRESS NOW, THEN HOLD IT (design section 5). This is the one path every production caller uses;
-- `Body.dress` stays the single-shot the specs drive.
--
-- The window watches ONE character's children for `APPEARANCE_WATCH_SECONDS` and does exactly three
-- things: paints a `BodyColors` the engine added, takes off a shirt or a layered garment the engine
-- added, and ignores everything else. At its close it paints ONCE MORE, because the engine can
-- MODIFY an existing `BodyColors` rather than add one -- and modifying fires no `ChildAdded`, so a
-- window that only listened would miss exactly that case.
--
-- IT IS KEYED BY userId AND REPLACES ITSELF, so a player can never hold two windows, and every
-- handler re-checks that this is still the player's current character: a window belonging to a dead
-- character is inert as well as short-lived.
function Body.dressWhenLoaded(player: Player, character: Model, config, look: Look?)
	-- RESOLVED ONCE, HERE, and used by both the immediate dress and the re-dress at the window's
	-- close: two reads could answer differently if a purchase landed in between, and then the hat
	-- would change colour five seconds after he spawned.
	local resolved = look or askLook(player)
	Body.dress(character, Body.teamOf(player), config, resolved)

	local userId = player.UserId
	stopWatching(userId)
	local base = Body.baseFor(Body.teamOf(player), config)
	if not base then
		return -- nothing to hold: the flag is off, or this player has no team
	end

	local row
	local connection = character.ChildAdded:Connect(function(child)
		if not row or row.closed then
			return
		end
		if player.Character ~= character or character.Parent == nil then
			return
		end
		if child:IsA("BodyColors") then
			Body.paint(character, base)
			return
		end
		for _, className in ipairs(base.clearClasses) do
			if child:IsA(className) then
				child:Destroy()
				strayCleared += 1
				return
			end
		end
		-- NEVER ONE OF OURS (review round 1, note). The close calls `Body.dress` BEFORE
		-- `stopWatching`, so `humanoid:AddAccessory` fires `ChildAdded` straight into this live
		-- handler -- and a catalog garment that carries a `WrapTarget`/`WrapLayer` is exactly what
		-- `Body.isLayered` answers true for. Today's cap and vest are rigid and do not bite; a
		-- catalog JACKET would have been destroyed by the window that had just put it on.
		if child:GetAttribute(ACCESSORY_TAG) ~= nil then
			return
		end
		if base.clearLayered and Body.isLayered(child) then
			child:Destroy()
			strayCleared += 1
		end
	end)
	row = { character = character, connection = connection, closed = false }
	watching[userId] = row

	task.delay(APPEARANCE_WATCH_SECONDS, function()
		if watching[userId] ~= row then
			return -- replaced by a later character, or forgotten
		end
		if player.Character == character and character.Parent ~= nil then
			-- A FULL RE-DRESS AT THE CLOSE, NOT JUST A REPAINT, and the Forest Test measured why.
			-- A player who spawned there came out GREEN AND BARE-HEADED: the colour had survived
			-- (this window repaints it) and the cap had not. The appearance load does not only add
			-- a `BodyColors` and a `Shirt` -- it applies the avatar's whole look, and an accessory
			-- we welded on a moment earlier can go with it. Typing `/beater` afterwards put both
			-- the cap and the vest on correctly, which is what said the dressing was fine and the
			-- TIMING was not.
			--
			-- `dress` is idempotent by construction -- it destroys the folder and this module's own
			-- tagged accessories first -- so this is "whatever is missing, put it back" and not a
			-- second hat. It subsumes the repaint, because `dress` paints.
			Body.dress(character, Body.teamOf(player), config, resolved)
		end
		stopWatching(userId)
	end)
end

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
function Body.setTeam(player: Player, name: TeamName?, config)
	player.Team = Body.teamNamed(name)
	player.Neutral = name == nil
	-- AND THE OUTFIT FOLLOWS THE TEAM, at the same moment, from the same writer. A team swap does
	-- not always come with a respawn, and a driver still wearing a shooter's hat is two answers to
	-- one question -- this project's named failure mode. `config` is optional so a caller that does
	-- not have one (a spec asserting only the Team field) is unchanged.
	--
	-- THROUGH THE WINDOW SINCE TASK 151, because a team swap writes the base as well as the parts
	-- and the base is the half a late appearance load can undo.
	local character = player.Character
	if config and character then
		Body.dressWhenLoaded(player, character, config)
	end
end

function Body.teamOf(player: Player): TeamName?
	local team = player.Team
	if not team then
		return nil
	end
	return (team.Name :: any) :: TeamName?
end

-- ------------------------------------------------------------------- task 192: ONE PLACEMENT RULE
--
-- KAREN, 2026-10-14: *"when drive ends I am underground ... when next round is started respawn in
-- under terrain and I dead all a time"*.
--
-- THE RULE, IN ONE SENTENCE: **a target's Y is the GROUND MEASURED AT THAT TARGET'S OWN x, z, plus a
-- clearance** -- never a hard-coded number, never a number measured somewhere else and carried
-- sideways. A CALLER'S Y IS ADVISORY, and that is stated here rather than discovered later:
-- `Body.placementFor` below still returns post-top + `STAND_HEIGHT_STUDS`, `Scene.ringLayout`
-- still returns its ring and `Lobby.spawnCFrame` still returns its porch slot; `Body.onGround`
-- then replaces the Y with the one that is really there. Where the caller was already right -- the
-- road, the DEV arena -- the snap moves it by less than the voxel surface, and `Body.snapped()`
-- counts how often it moved it by more.
--
-- IT LIVES HERE AND NOWHERE ELSE because this module is the one writer of where a character stands
-- (this file's header, CLAUDE.md rule 3). Every path Karen walks arrives here: the drive's
-- `Body.place`, the LOBBY'S RETURN -- which is injected as
-- `place = function(player, cframe) Body.place(player, cframe, Match.CONFIG) end` -- the results
-- scene's `Body.stand`, and the tie. One owner, one rule, four callers.
--
-- WHAT WAS MEASURED, before any of this was written (note section 2). In the live Forest Test, on
-- the `edge` layout, with a 0.5 s sampler on the player's root:
--   * at the drive's end the player sat at `(3543, 174.5, -3001)` with the terrain under him at
--     189.0 -- his feet 17.5 studs UNDER the ground, anchored, for the whole 25-second scene;
--   * three seconds into the next round the lobby's return put his ROOT at the ground itself
--     (149.2, ground 150.0), the engine ejected the body downward, and it fell
--     119.8 -> 39.0 -> -93.3 -> -285.7 and was DESTROYED below `FallenPartsDestroyHeight`.
--
-- Pattern: **DROP TO FLOOR**, which is Valve's `UTIL_DropToFloor` (`game/server/util.cpp`, Source
-- SDK 2013): an entity's spawn Y is never authored, it is a trace straight down from the authored
-- point. Unreal does the same for a target inside geometry (`UWorld::FindTeleportSpot`).
--   https://github.com/ValveSoftware/source-sdk-2013
--   https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Runtime/Engine/Engine/UWorld
--   https://create.roblox.com/docs/workspace/raycasting
-- Note: docs/research/2026-10-15-one-placement-rule.md

-- HOW FAR ABOVE THE MEASURED GROUND THE ROOT IS PUT. The default is the caller's own
-- `STAND_HEIGHT_STUDS` (3.5) -- this repo's existing number for exactly this -- and 3.5 was
-- measured on a live stand as root 4.0 above the terrain with the feet 0.2 clear.
local DEFAULT_CLEARANCE_STUDS = 3.5

-- THE RAY. 300 above the target and 1200 down: `ForestTest.groundAt` and `ForestTest.terrainYAt`
-- both use 1200 of reach in this place, and starting 300 above the TARGET rather than at an
-- absolute height assumes nothing about how high a world is.
local GROUND_PROBE_UP_STUDS = 300
local GROUND_PROBE_DOWN_STUDS = 1200

-- A MISSED RAY IS "NOT LOADED YET", NOT "NO GROUND" (Roblox instance streaming). Three tries inside
-- a sixth of a second, which is well under `PARENT_WAIT_SECONDS` and `config.PLACE_TIMEOUT`.
local GROUND_RETRIES = 3
local GROUND_RETRY_SECONDS = 0.05

-- HOW FAR ABOVE A POINT THE NEAR PROBE STARTS (round 2). Big enough to clear the gap between a
-- caller's Y and a ground slightly above it -- the lobby's return asked for a Y a stud under the
-- shelf -- and small enough to stay under the lowest thing anybody stands beneath: the lodge's
-- eaves are 10 studs over the shelf (`Lobby.CONFIG.LODGE.SIZE.Y`) and a root stands about 3 studs
-- up, so 6 leaves four studs of margin under the eaves and cannot reach a canopy at all.
local NEAR_PROBE_STUDS = 6

-- HOW FULL A VOXEL HAS TO BE TO COUNT AS SOLID. Measured in this place: `Air` reads 0.00, three
-- studs inside the surface reads 0.91 and twenty studs inside reads 1.00, so a half is well clear
-- of both the surface's own partial voxel and of nothing.
local TERRAIN_SOLID_OCCUPANCY = 0.5

-- HOW FAR THE SNAP HAD TO MOVE A Y BEFORE IT COUNTS AS HAVING MOVED IT. Roblox terrain is voxelised
-- and a marker's own face is not exactly the surface, so half a stud is "the caller was right".
local SNAP_TOLERANCE_STUDS = 0.5

local groundReader: ((number, number) -> number?)? = nil
local snapped = 0
local snapMisses = 0
local worstSnapStuds = 0

-- THE WORLD'S OWN SINGLE GROUND READER, injected at the composition root -- in the Forest Test
-- `ForestTest.groundAt`, which is the same function `Markers.setReaders`, `Bots.start` and
-- `Lobby.start` are already handed. `Match.start` sets it from `world.groundAt` and `Match.stop`
-- clears it, exactly as it does for `world.placement` and `world.config`. A world that injects
-- nothing gets the fallback below, which is the DEV place.
function Body.setGroundReader(fn: ((number, number) -> number?)?)
	groundReader = fn
end

function Body.groundReader(): ((number, number) -> number?)?
	return groundReader
end

-- WHERE THE GROUND IS UNDER THIS POINT. The world's reader when there is one; otherwise one ray
-- down, excluding every CHARACTER -- a person is not ground, which is the rule `ForestTest.groundAt`
-- and `ForestTest.roomToStand` already state for this place. It is NOT a second definition of that
-- rule: when a world has one, this never runs.
--
-- `pcall` ROUND THE INJECTED READER: a world's reader that throws must not take a placement with it,
-- and a placement that cannot measure is the `nil` case below, which is handled.
-- ONE ASK, AT ONE STARTING HEIGHT. The world's reader when there is one; otherwise one ray down,
-- excluding every CHARACTER.
--
-- THE FALLBACK IS THE DEV PLACE'S READER AND NOTHING ELSE (Reviewer round 1, note 7). It excludes
-- only characters, while `ForestTest.groundAt` also excludes that world's foliage and animals --
-- and that is not two answers to one question, because they never both run: a world that has a
-- reader injects it, and the DEV arena has no foliage, no `Boars` folder and no canopy to stop a
-- ray on. If a third world ever has foliage, it brings its own reader as the forest does.
local function askGround(x: number, z: number, fromY: number?): number?
	if groundReader ~= nil then
		local ok, measured = pcall(groundReader :: any, x, z, fromY)
		return if ok and type(measured) == "number" then measured else nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local ignore = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local from = if type(fromY) == "number" then fromY :: number else GROUND_PROBE_UP_STUDS
	local hit = Workspace:Raycast(Vector3.new(x, from, z), Vector3.new(0, -GROUND_PROBE_DOWN_STUDS, 0), params)
	return if hit then hit.Position.Y else nil
end

-- WHERE THE GROUND IS UNDER THIS POINT -- and since round 2 that sentence is enforced rather than
-- hoped for (Reviewer round 1, finding 1).
--
-- THE FAULT IT FIXES: a ray that starts 600 or 300 studs up answers "what is the first solid thing
-- from the sky". Indoors that is the LODGE'S ROOF (`Lobby.Build.roof`, 10-18 studs over the shelf,
-- in no excluded folder), so a player standing at task 178's shop counter measured 7-15 studs
-- "under the ground" -- and the floor net below pivoted him out of the building four times a
-- second. The same ray stops on the canopy of the 831 Studio-built `Session` trees, which is a
-- beater walking 580 studs through the wood.
--
-- THE RULE: **a downward ray can only hit what is BELOW its origin**, so asking from just above the
-- point asks the only question that was ever meant -- what would a body here land on -- and nothing
-- overhead can answer it. `NEAR_PROBE_STUDS` is how far above "just above" is.
--
-- STAGE B EXISTS BECAUSE A RAY FROM INSIDE A SOLID MISSES, AND THAT IS MEASURED. In this place, at
-- (3555, -3000) with the surface at 191.6: from 197.6 down -> HIT 191.6; from 188.6 (three studs
-- INSIDE) -> MISS; from 171.6 (twenty studs inside) -> MISS. So a point buried in the hill cannot
-- find its own surface by looking down, and the far cast is the only thing that can. It runs ONLY
-- when the near one found nothing, which is exactly "there is nothing below this point" -- buried,
-- or over a hole -- and never while a body is standing on something.
--
-- `fromY` IS OPTIONAL and nil means "I am asking about a COLUMN, not about a body" -- the scene's
-- layout points, a spec's hand-written reader. Those get stage B alone, which is where they were
-- before this round.
function Body.groundUnder(x: number, z: number, fromY: number?): number?
	if type(fromY) == "number" then
		local near = askGround(x, z, (fromY :: number) + NEAR_PROBE_STUDS)
		if near ~= nil then
			return near
		end
	end
	return askGround(x, z, nil)
end

-- IS THIS POINT INSIDE SOLID TERRAIN? The one test in this module that asks about the body's own
-- place and NOTHING above it, which is why the net leans on it.
--
--   Terrain:ReadVoxels  https://create.roblox.com/docs/reference/engine/classes/Terrain#ReadVoxels
--     Answers a material and an occupancy per 4-stud voxel. MEASURED in this place, at the stand on
--     the `edge` line: four studs ABOVE the surface reads `Air` 0.00; three studs inside reads
--     `Grass` 0.91; twenty studs inside reads `Grass` 1.00; two hundred studs up reads `Air` 0.00.
--     So "am I buried" has a crisp answer that a roof, a canopy or a truck cannot change -- and a
--     player standing on the lodge floor is NOT buried, because his root is three studs of air
--     above the terrain shelf that floor is laid on.
--
-- `Region3:ExpandToGrid(4)` because `ReadVoxels` takes a region aligned to the voxel grid; `pcall`
-- because a region outside the terrain's own extents throws, and "I could not tell" is `false`.
function Body.insideTerrain(at: Vector3): boolean
	local half = Vector3.new(2, 2, 2)
	local ok, materials, occupancy = pcall(function()
		local region = Region3.new(at - half, at + half):ExpandToGrid(4)
		return Workspace.Terrain:ReadVoxels(region, 4)
	end)
	if not ok or type(materials) ~= "table" then
		return false
	end
	local column = ((materials :: any)[1] or {})[1]
	local material = if column ~= nil then column[1] else nil
	local filledColumn = ((occupancy :: any)[1] or {})[1]
	local filled = if filledColumn ~= nil then filledColumn[1] else nil
	if material == nil or filled == nil then
		return false
	end
	return material ~= Enum.Material.Air and (filled :: number) >= TERRAIN_SOLID_OCCUPANCY
end

-- THE SAME QUESTION, ASKED AGAIN WHEN IT HAS NO ANSWER. A miss is "this region has not streamed or
-- loaded yet" far more often than it is "there is no ground here" (Roblox instance streaming), and
-- the retry is what turns the first case into an answer instead of into a fall. It YIELDS, and only
-- on a miss: the server holds the whole world, so in a live session this loop runs once.
local function groundWithRetries(x: number, z: number, fromY: number?): number?
	for attempt = 1, GROUND_RETRIES do
		local y = Body.groundUnder(x, z, fromY)
		if y ~= nil then
			return y
		end
		if attempt < GROUND_RETRIES then
			task.wait(GROUND_RETRY_SECONDS)
		end
	end
	return nil
end

-- THE SNAP. Takes the caller's CFrame and returns the same frame with its Y on the ground under it.
-- Returns the ORIGINAL frame, unchanged, when the ground cannot be measured at all -- a placement
-- that cannot measure must still happen (a player who is not placed is a player standing in the
-- lobby forever), and `Body.snapMisses()` is how that shows up as a number instead of as a feeling.
--
-- THE ROTATION IS THE CALLER'S AND IS NEVER TOUCHED: which way a hunter faces is the drive's
-- decision, not the ground's.
--
-- IT RETURNS THE MEASURED GROUND AS WELL AS THE FRAME, so the one line the owner prints about a
-- placement carries the measurement rather than a second ray's opinion of it (`nil` when the ray
-- missed, which is the honest answer and what `snapMisses` counts).
function Body.onGround(cframe: CFrame?, clearanceStuds: number?): (CFrame?, number?)
	if cframe == nil then
		return nil, nil
	end
	local at = (cframe :: CFrame).Position
	-- ASKED FROM THE TARGET'S OWN HEIGHT (Reviewer round 1, finding 1): a lobby return or a ring
	-- slot INSIDE a building must land on the floor, not on the roof over it.
	local ground = groundWithRetries(at.X, at.Z, at.Y)
	if ground == nil then
		snapMisses += 1
		return cframe, nil
	end
	local clearance = if type(clearanceStuds) == "number" then clearanceStuds else DEFAULT_CLEARANCE_STUDS
	local wanted = (ground :: number) + clearance
	local moved = math.abs(wanted - at.Y)
	if moved > SNAP_TOLERANCE_STUDS then
		snapped += 1
		worstSnapStuds = math.max(worstSnapStuds, moved)
	end
	return (cframe :: CFrame) - at + Vector3.new(at.X, wanted, at.Z), ground
end

-- THE ONE LINE A PLACEMENT PRINTS, and it is the evidence this task was dispatched to produce:
-- every spawn and every teleport says where it put a body, what the ground under that point
-- measured, and how far it had to move the caller's own Y to get there. A placement that reads
-- `ground=MISS` is the one case the net below exists for.
--
-- ON THE CONSOLE AND NOT IN A COUNTER, because a counter cannot say WHICH placement was wrong, and
-- because a tool that requires this module over StudioMCP gets a sandboxed copy with empty state
-- (measured, task 122) -- so the server's own print is the only honest channel. It happens at a
-- drive boundary and at a lobby return, which is a handful of lines every few minutes.
local function reportPlacement(what: string, who: string, asked: CFrame, put: CFrame?, ground: number?)
	local at = if put ~= nil then (put :: CFrame).Position else asked.Position
	print(
		string.format(
			"[place] %s %s at (%.0f, %.1f, %.0f) ground=%s askedY=%.1f dY=%s",
			what,
			who,
			at.X,
			at.Y,
			at.Z,
			if ground ~= nil then string.format("%.1f", ground :: number) else "MISS",
			asked.Position.Y,
			if ground ~= nil then string.format("%+.1f", at.Y - asked.Position.Y) else "0.0"
		)
	)
end

-- The clearance a config asks for, with this module's default when it says nothing. One place, so
-- `place`, `stand` and the floor net cannot disagree about how high off the ground a body sits.
function Body.clearanceFor(config): number
	local asked = if config then (config :: any).STAND_HEIGHT_STUDS else nil
	return if type(asked) == "number" then asked else DEFAULT_CLEARANCE_STUDS
end

-- How many placements the snap actually MOVED (by more than half a stud), how many could not measure
-- the ground at all, and the worst correction it has made. 0 / 0 in a world whose callers were
-- already right; the measured Forest Test gathering was 17.5.
function Body.snapped(): number
	return snapped
end

function Body.snapMisses(): number
	return snapMisses
end

function Body.worstSnapStuds(): number
	return worstSnapStuds
end

-- Where a player of this team stands, given the marker set and their index within the team.
-- Shooters take one post each, by index, and face +Z (up the drive). Drivers spread across the
-- driver start's X extent and face -Z (toward the line).
--
-- ITS Y IS ADVISORY SINCE TASK 192 (the rule above): `Body.place` snaps whatever this returns onto
-- the ground measured at that x, z. The post-top arithmetic stays because it is the right ANSWER in
-- both worlds -- a post sits on the ground -- and because a spec reads it with no Workspace at all.
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

-- THE PIVOT AGAIN, ONE FRAME LATER, AND IT IS A MEASUREMENT AND NOT A BELT-AND-BRACES HABIT.
--
-- MEASURED in the place "Driven Hunt Forest Test" (task 157): a character placed by the lines above
-- stayed exactly where `LoadCharacter` had put it -- the place's own `SpawnLocation`, on the road at
-- (3000, -2109) -- while the `CFrame` the drive had chosen was 240 studs north. A direct `PivotTo`
-- from a server query on the same character in the same session STUCK (dz 0 -> 240, still 240 two
-- seconds later), so the engine was not refusing the move: the move was being OVERWRITTEN. That
-- place has a `SpawnLocation` and the DEV place does not (its own was archived in task 22), which is
-- why this never showed in a hundred DEV drives.
--
-- IT IS THE SAME FACT `ForestTestBoot` HAD ALREADY WRITTEN DOWN, in task 153's own comment:
-- *"DEFERRED ... the spawn location has just put the character down and `CharacterAdded` runs inside
-- that frame, so the move is made after it."* That boot deferred its own write for exactly this
-- reason; `Body.place` did not, because it had never had to.
--
-- SO: pivot now (which is right in DEV and costs nothing), and once more as soon as this
-- resumption cycle ends -- `task.defer`, not a frame -- IF the character has drifted more than a
-- stud from where it was put. `Body.settled()` counts how often
-- the second one bit, so "it only matters in one world" is a number rather than a belief -- and
-- there is still ONE writer of where a character stands.
function Body.settle(character: Model, cframe: CFrame)
	task.defer(function()
		local root = character.PrimaryPart
		if character.Parent == nil or root == nil then
			return
		end
		if (root.Position - cframe.Position).Magnitude <= SETTLE_TOLERANCE_STUDS then
			return
		end
		settled += 1
		character:PivotTo(cframe)
	end)
end

-- How many placements needed the second pivot. 0 in a DEV session; non-zero in the Forest Test.
function Body.settled(): number
	return settled
end

-- How many frames placements have spent waiting for a character to be parented. 0 where
-- `CharacterAdded` already carries a parented character, which is the DEV place.
function Body.parentWaits(): number
	return parentWaits
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
		-- DRESSED BEFORE THE EARLY RETURN, because a player who spawned with nowhere to stand is
		-- still a player of a team (M2.8d). This handler is the design's first call site: it is the
		-- one place that already knows a NEW character has arrived for a player whose team is set.
		-- A NEW CHARACTER IS EXACTLY WHERE THE APPEARANCE RACE LIVES (Task 151), so this is the one
		-- call site that most needs the window rather than the single shot.
		--
		-- ...AND IT IS FIRST, BEFORE THE SNAP (Reviewer round 1, note 8). `Body.onGround` can YIELD
		-- on a missed ray, so measuring first would open the appearance window up to
		-- `GROUND_RETRIES * GROUND_RETRY_SECONDS` later for no gain: the two are independent, and
		-- dressing first costs nothing.
		Body.dressWhenLoaded(player, character, config)
		-- ON THE GROUND THAT IS REALLY THERE (task 192, the rule above). The caller's Y is advisory
		-- and this is where it stops being: the lobby's return asked for the shelf height itself
		-- (`SPAWN.OFFSET.Y` is 0), which put the ROOT inside the terrain, and the engine answered by
		-- ejecting the body downward until `FallenPartsDestroyHeight` destroyed it -- measured, and
		-- it is the death Karen reported at the start of every round.
		--
		-- SNAPPED HERE AND NOT BEFORE `LoadCharacter`, because the snap can YIELD and this handler
		-- is already a `task.spawn`. `Body.settle` below is then given the SNAPPED frame, so the
		-- second pivot cannot put the body back at the caller's wrong Y.
		local target, measured = Body.onGround(cframe, Body.clearanceFor(config))
		if not target then
			finish(true) -- nowhere to put them: they spawned, and that is not a failure
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			-- The character exists but its root has not replicated yet. One wait, then try again.
			character:GetPropertyChangedSignal("PrimaryPart"):Wait()
		end
		-- ...AND IT MAY NOT BE PARENTED YET EITHER, WHICH IS MEASURED AND NOT DEFENSIVE (task 157).
		--
		-- In the place "Driven Hunt Forest Test", `CharacterAdded` fires with `character.Parent ==
		-- nil`: a probe that ran this exact sequence in that session printed
		-- `added parent=false root=true primary=true`, so the guard below was false, `PivotTo` never
		-- ran, and every player stood where `LoadCharacter` had left them -- the place's own
		-- SpawnLocation, on the road, while the drive had chosen a stand or a beater start 240 studs
		-- north. The DEV place parents it first, which is why a hundred drives there never showed it.
		--
		-- THE GUARD ITSELF WAS NOT WRONG, it was ANSWERING TWO QUESTIONS: "has this character gone?"
		-- and "has it arrived yet?" are not the same question, and only the first one deserves a
		-- refusal. So this waits, bounded, for the one that is about to be true.
		local waited = 0
		while character.Parent == nil and waited < PARENT_WAIT_SECONDS do
			parentWaits += 1
			waited += task.wait()
		end
		if character.Parent then
			character:PivotTo(target :: CFrame)
			-- REPORTED WHERE IT HAPPENED AND NOT WHERE IT WAS DECIDED (task 192): a line printed
			-- before the pivot would say a body is somewhere it never reached.
			reportPlacement("spawn", player.Name, cframe :: CFrame, target, measured)
			Body.settle(character, target :: CFrame)
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

-- ------------------------------------------------------------------- 1.7b: tied to a tree
-- The one runtime container this system creates, and this module is its only writer. Created on
-- first use so a server that never punishes anybody never makes it.
function Body.driveMarkers(): Folder
	local existing = Workspace:FindFirstChild("DriveMarkers")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "DriveMarkers"
	folder.Parent = Workspace
	return folder
end

function Body.ropeName(userId: number): string
	return string.format("Rope_%d", userId)
end

-- Which tree to tie this player to: the nearest tagged tree, else the nearest post, else nil -- and
-- nil means DO NOT TIE. A nil anchor used as a CFrame would teleport the player to the origin, which
-- is the silent wrong answer this returns nothing instead of (design section 8.4).
function Body.anchorFor(markers, from: Vector3?): BasePart?
	local candidates = if #markers.trees > 0 then markers.trees else markers.posts
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, part in ipairs(candidates) do
		local distance = if from then (part.Position - from).Magnitude else 0
		if distance < bestDistance then
			best, bestDistance = part, distance
		end
	end
	return best
end

-- Where a tied player stands: on the side of the tree they came from, on the ground, facing it.
--
-- NOT the design's `TIE_OFFSET = CFrame.new(0, 0, 2.5)` (reviews/task-35/DESIGN_DELTA.md): the
-- arena's trees are the 8 x 24 x 8 corner pillars, so 2.5 studs along the tree's own +Z is INSIDE
-- the pillar and twelve studs up in the air, because a part's Position is its centre. The gap is
-- measured from the trunk's surface and the height from its base.
function Body.tiePointFor(tree: BasePart, from: Vector3?, config): CFrame
	local base = tree.Position.Y - tree.Size.Y / 2 + config.STAND_HEIGHT_STUDS
	local centre = Vector3.new(tree.Position.X, base, tree.Position.Z)
	local away = if from then Vector3.new(from.X - tree.Position.X, 0, from.Z - tree.Position.Z) else Vector3.zero
	local direction = if away.Magnitude < 1e-3 then Vector3.new(0, 0, 1) else away.Unit
	local radius = math.max(tree.Size.X, tree.Size.Z) / 2 + config.TIE_GAP_STUDS
	return CFrame.lookAt(centre + direction * radius, centre)
end

local function ropeFor(root: BasePart, tree: BasePart, userId: number, config, parent: Instance): Part?
	local from = root.Position
	local to = Vector3.new(tree.Position.X, from.Y, tree.Position.Z)
	local span = (to - from).Magnitude
	if span < 0.2 then
		return nil -- no rope to draw, and CFrame.lookAt on two equal points errors
	end
	local rope = Instance.new("Part")
	rope.Name = Body.ropeName(userId)
	rope.Shape = Enum.PartType.Cylinder
	-- A cylinder's axis is its X, so the length goes in X and the rotation below puts X along the
	-- rope: composing a 90-degree yaw onto lookAt maps the part's XVector onto the look direction.
	rope.Size = Vector3.new(span, config.ROPE_THICKNESS, config.ROPE_THICKNESS)
	rope.CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.pi / 2, 0)
	rope.Color = config.ROPE_COLOR
	rope.Material = Enum.Material.Fabric
	rope.Anchored = true
	rope.CanCollide = false
	rope.CanQuery = false -- it must never stop a pellet or an aim ray
	rope.CastShadow = false
	rope.Parent = parent
	return rope
end

-- Ties `player` to `tree`. Returns true only if it actually happened, so the owner can count a miss
-- rather than believe a tie that never took. `parent` is where the rope goes (Workspace.DriveMarkers
-- in production; its own folder in a spec).
function Body.tie(player: Player, tree: BasePart, config, parent: Instance?): boolean
	local ok = Body.tieCharacter(player.Character, player.UserId, tree, config, parent)
	-- THE SECOND CALL SITE THE DESIGN NAMES: a re-tie. A tied player who presses Reset gets a new
	-- character and `Match.watchCharacter` re-ties it here; without this that character would be the
	-- one person in the drive wearing nothing. It is on the PLAYER wrapper and not on
	-- `tieCharacter`, because the team is a fact about the player and `tieCharacter` has only a
	-- userId -- the seam a spec uses so it never freezes the one live player.
	local character = player.Character
	if ok and character then
		Body.dressWhenLoaded(player, character, config)
	end
	return ok
end

-- HOW FAST A PLAYER WALKS WHEN NOTHING IS HOLDING HIM, asked of the PLACE and not written down
-- here: `StarterPlayer.CharacterWalkSpeed` is what every new character of this place is born with,
-- so a place that slows everybody down is still right. 16 is Roblox's own default, and the fallback
-- for a context with no StarterPlayer.
--   https://create.roblox.com/docs/reference/engine/classes/StarterPlayer#CharacterWalkSpeed
function Body.defaultWalkSpeed(): number
	local speed = StarterPlayer and StarterPlayer.CharacterWalkSpeed
	return if type(speed) == "number" and speed > 0 then speed else 16
end

-- HOW MANY TIMES A RESTORE REFUSED TO HAND BACK A ZERO. It must stay 0 for ever; see
-- `Body.untieCharacter`. A number rather than a belief, which is this repo's habit for
-- "this cannot happen".
local rescued = 0

-- How many characters have been stood somewhere by `Body.standCharacter` (task 159).
local stood = 0

function Body.rescued(): number
	return rescued
end

-- HELD WHERE HE STANDS: the freeze alone, with no tree, no rope and no move (task 158). This is the
-- beaters' hold at the start line while the countdown runs -- Karen: *"Beater start in line with
-- others and countdown when drive starts"*.
--
-- IT IS THE TIE'S OWN FREEZE, FACTORED OUT AND NOT A SECOND ONE: the same three humanoid numbers,
-- the same `held` table they are saved in and the same anchored root, so this module stays the ONE
-- writer of whether a character can move and `Body.untie` restores either of them. A hold IS a tie
-- without the rope and without the teleport, and writing it twice is how two systems end up
-- disagreeing about who is frozen.
--
--   Humanoid.WalkSpeed  https://create.roblox.com/docs/reference/engine/classes/Humanoid#WalkSpeed
--   BasePart.Anchored   https://create.roblox.com/docs/reference/engine/classes/BasePart#Anchored
-- Returns the frozen character's root, or nil if nothing could be frozen -- which is what lets
-- `tieCharacter` below reuse both the work and the refusals rather than repeating either.
function Body.holdCharacter(character: Model?, userId: number): BasePart?
	if not character or not character.Parent then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local found = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not (found and found:IsA("BasePart")) then
		return nil
	end
	local root = found :: BasePart

	-- SAVED ONCE, WHATEVER FROZE HIM FIRST. A hold applied on top of a tie must not record
	-- WalkSpeed 0 as "what he had before", which would leave a freed player unable to walk.
	if not held[userId] then
		held[userId] = {
			walkSpeed = humanoid.WalkSpeed,
			jumpHeight = humanoid.JumpHeight,
			jumpPower = humanoid.JumpPower,
		}
	end
	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0
	humanoid.JumpPower = 0 -- for places on UseJumpPower; writing both costs nothing
	root.Anchored = true
	return root
end

-- The player wrapper, for the same reason `Body.tie` has one.
function Body.hold(player: Player): boolean
	return Body.holdCharacter(player.Character, player.UserId) ~= nil
end

-- Whether this module is holding that character still -- a tie or a hold, which are the same freeze.
function Body.isHolding(userId: number): boolean
	return held[userId] ~= nil
end

-- HOLD IT AS SOON AS IT HAS ARRIVED, however late that is (task 168).
--
-- THIS IS THE TASK-157 RACE, IN THE HOLD PATH, AND IT WAS MEASURED TWICE. `Body.place`'s own `pivot`
-- already carries the finding: in the place "Driven Hunt Forest Test" `CharacterAdded` fires with
-- `character.Parent == nil`, and the DEV place parents it first -- which is why a hundred DEV drives
-- never showed it. `Body.holdCharacter` refuses an unparented character (rightly: a character that
-- has GONE must not be written), so the drive's own re-apply after a placement respawn silently did
-- nothing, and the beater it had just decided to hold could walk.
--
-- MEASURED in a live Play session of the Forest Test, 2026-10-12, as a player beater at the start
-- line: `t=7.7s walkSpeed=0 anchored=true` on the character the hold was applied to, then
-- `t=7.9s walkSpeed=16 anchored=false` on the one `LoadCharacter` replaced it with. With this wait:
-- `walkSpeed=0 anchored=true` all the way to GO.
--
-- "HAS IT GONE?" AND "HAS IT ARRIVED YET?" ARE NOT THE SAME QUESTION, which is the sentence
-- `Body.place` already answers with a bounded wait -- and the bound is its own
-- `PARENT_WAIT_SECONDS`, so there is one number for how long a character may take to arrive.
-- `stillWanted` is the caller's own re-check, asked again after the wait: a hold the drive has let
-- go of in the meantime must not be applied to the character that finally turned up.
function Body.holdWhenLoaded(character: Model, userId: number, stillWanted: (() -> boolean)?): boolean
	if character == nil then
		return false
	end
	if not character.PrimaryPart then
		character:GetPropertyChangedSignal("PrimaryPart"):Wait()
	end
	local waited = 0
	while character.Parent == nil and waited < PARENT_WAIT_SECONDS do
		parentWaits += 1
		waited += task.wait()
	end
	if stillWanted ~= nil and stillWanted() ~= true then
		return false
	end
	return Body.holdCharacter(character, userId) ~= nil
end

-- HELD WHERE THE DRIVE SAYS, NOT WHERE HE IS: the hold plus a move, with no rope and no respawn
-- (task 159, the results scene). It is `tieCharacter` without the tree -- the same `holdCharacter`
-- freeze and the same `PivotTo` -- so this module stays the one writer of where a character stands
-- and of whether it can move, and the scene decides only the CFrame.
--
-- WHY NOT `Body.place`: that is the drive's own placement and it calls `LoadCharacter`, which
-- respawns the player -- a new character, a dropped Tool and a reset camera, three seconds after a
-- drive in which she was holding a gun. The results scene moves the character she is already in.
--
-- `Anchored` IS WHY THE MOVE STICKS: a character's physics is owned by its own client, so a
-- server-side pivot alone is a suggestion (see this module's header). `holdCharacter` anchors first
-- and the pivot follows, which is the order the tie uses for the same reason.
--
-- ...AND ON THE GROUND UNDER THE SLOT IT IS GIVEN (task 192). THIS is where Karen stood 17.5 studs
-- underground: `Scene.ringLayout` lays a ring 14 studs across at ONE Y, taken off the middle post,
-- and on the `edge` layout's 80-stud hillside that one Y is not the ground anywhere else on the
-- line. The ring is still the scene's to compute; the ground is this module's to measure, which is
-- the same split `placementFor` and `place` already have. `clearance` is the caller's
-- `STAND_HEIGHT_STUDS`, so a player at the scene stands as high off the floor as a hunter on a
-- stand -- which is what `Scene.ringLayout`'s own header says it is doing.
function Body.standCharacter(character: Model?, userId: number, cframe: CFrame, config): boolean
	local root = Body.holdCharacter(character, userId)
	if root == nil or character == nil then
		return false
	end
	local target, measured = Body.onGround(cframe, Body.clearanceFor(config))
	character:PivotTo(target :: CFrame)
	reportPlacement("gather", character.Name, cframe, target, measured)
	stood += 1
	return true
end

-- The player wrapper, for the same reason `Body.tie` and `Body.hold` have one.
function Body.stand(player: Player, cframe: CFrame, config): boolean
	return Body.standCharacter(player.Character, player.UserId, cframe, config)
end

-- How many characters this module has stood somewhere (the results scene's own number).
function Body.stood(): number
	return stood
end

-- ------------------------------------------------------------------- task 192: THE FLOOR, AS A NET
--
-- THE RULE ABOVE IS THE FIX; THIS IS THE NET UNDER IT, and the difference matters. The snap makes
-- every target right; this catches a body that is under the ground ANYWAY -- a second writer that
-- has not been found yet, a client whose region had not streamed when it was moved, a fall through a
-- seam in the voxels -- and puts it back before the engine deletes it.
--
-- Pattern: UNREAL'S `KillZ` HOOK, INVERTED. `AWorldSettings::KillZ` plus `AActor::FellOutOfWorld` is
-- the engine telling the game that a body has left the world instead of only deleting it; Roblox
-- has the deletion (`Workspace.FallenPartsDestroyHeight`) and NO hook, so this is the hook. The
-- inversion is the whole point: Unreal's default is to kill, and this puts the body back.
--   https://create.roblox.com/docs/reference/engine/classes/Workspace#FallenPartsDestroyHeight
--   https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Runtime/Engine/GameFramework/AWorldSettings
--   Humanoid.FloorMaterial https://create.roblox.com/docs/reference/engine/classes/Humanoid#FloorMaterial
-- Note: docs/research/2026-10-15-one-placement-rule.md section 4
--
-- IT MUST STAY AT ZERO. `Body.rescuedFromUnderGround()` is in the drive's report, and a session in
-- which it is not 0 is a session with a placement bug that this net is hiding -- which is a number
-- to read, not a thing to be pleased about. The same discipline `strayCleared` already has.

-- HOW FAR UNDER THE GROUND IS NOT A STANDING CHARACTER. An R15 root is about 3 studs above its own
-- feet and the voxel surface is good to about half a stud, so 5 studs below the measured ground
-- cannot be anybody standing on it. The three real failures measured in task 192 were 4, 17.5 and
-- 650 studs. It is the SOFT WALL's threshold (`Body.liftOntoGround`); the net below does not use a
-- depth at all any more -- see `Body.floorStep`.
local MAX_BELOW_GROUND_STUDS = 5

-- HOW FAST DOWNWARD COUNTS AS FALLING. Roblox gravity is 196.2 studs/s^2, so a body that has been
-- falling for a tenth of a second is already past 19; 5 is comfortably above the jitter of a body
-- settling on a slope and far below anything that is really dropping.
local FALLING_SPEED_STUDS = 5

-- HOW FAR UNDER A FALLING BODY THE NET LOOKS FOR A FLOOR. 500 studs is about three seconds of fall,
-- which at the net's 4 Hz is a dozen chances to catch him before `FallenPartsDestroyHeight` does.
local FALL_PROBE_STUDS = 500

-- HOW FAR A RESCUE HAS TO MOVE A BODY BEFORE IT IS A RESCUE (Reviewer round 1, note 1).
local RESCUE_MOVED_STUDS = 1

-- HOW MUCH WARNING THE ENGINE'S OWN DELETION GETS. A body below `FallenPartsDestroyHeight` is
-- DESTROYED, which is a death; 100 studs above it is about a second and a half of fall at terminal
-- speed, and the net runs at 4 Hz.
local FLOOR_MARGIN_STUDS = 100

-- WHERE EACH PLAYER WAS LAST SEEN STANDING ON SOMETHING, keyed by userId so nothing here holds a
-- Player -- the discipline `held` and `watching` already follow. Written only by `floorStep` and
-- cleared by `Body.forget`.
local lastGood: { [number]: Vector3 } = {}
local rescuedUnderGround = 0
local worstRescueStuds = 0

-- HOW FAR UNDER THE GROUND THIS POINT IS, as a number. Positive means buried; 0 or negative means
-- on it or above it; nil means the ground could not be measured, which is not the same as "it is
-- fine" and is why every caller branches on it.
function Body.underGroundBy(at: Vector3): number?
	-- ASKED FROM THE POINT ITSELF (round 2). Before this it asked from the sky, so a roof or a
	-- canopy overhead answered "the ground" and a man standing indoors measured 7-15 studs under it.
	local ground = Body.groundUnder(at.X, at.Z, at.Y)
	return if ground == nil then nil else (ground :: number) - at.Y
end

-- HOW FAR UNDER THE GROUND IS NOT A STANDING CHARACTER, for a caller that has to make the same
-- judgement this module's own net makes. One number, one reader.
function Body.maxBelowGround(): number
	return MAX_BELOW_GROUND_STUDS
end

-- A POINT, LIFTED OUT OF THE HILL -- and ONLY out of it. Returns the point unchanged (and `false`)
-- when it is on the ground, above it, or when the ground cannot be measured; the lifted point (and
-- `true`) when it is more than `MAX_BELOW_GROUND_STUDS` under it.
--
-- IT IS ONE-SIDED ON PURPOSE. A caller that writes a position every frame -- `ForestTest.boundary`,
-- the hunter's soft wall -- must not be allowed to pin a jumping player to the ground; what it must
-- never do is put a body INTO the hill. So this answers only the second question.
function Body.liftOntoGround(at: Vector3, clearanceStuds: number?): (Vector3, boolean)
	local below = Body.underGroundBy(at)
	if below == nil or (below :: number) <= MAX_BELOW_GROUND_STUDS then
		return at, false
	end
	local clearance = if type(clearanceStuds) == "number" then clearanceStuds else DEFAULT_CLEARANCE_STUDS
	return Vector3.new(at.X, at.Y + (below :: number) + clearance, at.Z), true
end

function Body.rescuedFromUnderGround(): number
	return rescuedUnderGround
end

-- THE BIGGEST LIFT A RESCUE HAS MADE, in studs. It was `worstBelowGroundStuds` in round 1, when the
-- net measured a DEPTH; the net no longer asks for one -- it asks whether the body is buried, off
-- the world or falling through nothing -- so the honest number is how far it had to move him.
function Body.worstRescueStuds(): number
	return worstRescueStuds
end

-- Where this module last saw that player standing on something. nil until it has.
function Body.lastGoodPosition(userId: number): Vector3?
	return lastGood[userId]
end

-- ONE PASS OF THE NET. Returns how many characters it actually MOVED, so the owner can count it.
--
-- IT ASKS THREE QUESTIONS AND EVERY ONE OF THEM IS ABOUT THE BODY'S OWN PLACE (Reviewer round 1,
-- finding 1). Round 1 asked a fourth -- "is the ground above me higher than I am" -- and the ground
-- was read from the sky, so a roof, a canopy or a truck overhead counted as the floor and this
-- function pivoted a man out of the lodge four times a second. There is no "how far under the
-- ground am I" here any more:
--
--   1. BURIED. `Body.insideTerrain` reads the voxel the root is in. Nothing above it can change
--      that answer, and a player standing on the lodge floor reads `Air` because his root is three
--      studs above the shelf the floor is laid on.
--   2. OFF THE WORLD. Below `FallenPartsDestroyHeight + FLOOR_MARGIN_STUDS`, where the engine is
--      about to delete the body -- which is a death, not a fall.
--   3. FALLING THROUGH NOTHING. The engine says he is not standing on anything
--      (`Humanoid.FloorMaterial == Air`), he is moving DOWN faster than `FALLING_SPEED_STUDS`, and
--      a ray from his own root finds no floor within `FALL_PROBE_STUDS`. All three, together.
--
-- A CHARACTER THE ENGINE SAYS IS STANDING IS NEVER TOUCHED BY 2 OR 3, and is remembered as the last
-- good place instead. `FloorMaterial` is the engine's own answer to "is he on something", and it is
-- true of the lodge's floor, a truck's running board, a branch and the terrain alike.
local function fallingFreely(root: BasePart, humanoid: Humanoid): boolean
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		return false
	end
	if root.AssemblyLinearVelocity.Y > -FALLING_SPEED_STUDS then
		return false
	end
	-- FROM THE ROOT, DOWNWARD, AND BOUNDED. A downward ray cannot hit anything above the body, so
	-- this is "is there a floor under me", never "what is over my head".
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local ignore = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	return Workspace:Raycast(root.Position, Vector3.new(0, -FALL_PROBE_STUDS, 0), params) == nil
end

-- `service` IS A PARAMETER for the reason every seam in this file is: a spec drives it with a fake
-- `GetPlayers` and no Workspace. `floorY` and `buriedTest` likewise -- the defaults are this
-- place's own destroy height plus the margin, and `Body.insideTerrain`. A spec can then drive
-- "this body is inside the hill" and "this body is under the lodge's roof" as two different
-- answers with hand-written numbers, which is the distinction round 1 could not make at all.
function Body.floorStep(service: any, floorY: number?, buriedTest: ((Vector3) -> boolean)?): number
	local players = if service and service.GetPlayers then service:GetPlayers() else {}
	local floor = if type(floorY) == "number"
		then floorY :: number
		else Workspace.FallenPartsDestroyHeight + FLOOR_MARGIN_STUDS
	local putBack = 0
	for _, player in ipairs(players) do
		local character = player.Character
		local root = character and (character.PrimaryPart or character:FindFirstChild("HumanoidRootPart"))
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		-- THE NET IS FOR THE LIVING, AND THAT IS MEASURED (task 192, the first proof run). A dead
		-- character is a ragdoll: on the `edge` layout's slope one slid ten studs downhill and
		-- clipped 47.8 studs into the terrain, and the net dutifully put a CORPSE back on its stand
		-- half a second before `LoadCharacter` destroyed it. That is a rescue of nobody.
		local alive = humanoid ~= nil and humanoid.Health > 0
		if character and character.Parent and root and root:IsA("BasePart") and humanoid and alive then
			local at = (root :: BasePart).Position
			local standing = humanoid.FloorMaterial ~= Enum.Material.Air
			local buried = if buriedTest ~= nil then buriedTest(at) else Body.insideTerrain(at)
			local offTheWorld = at.Y < floor
			local falling = not standing and fallingFreely(root :: BasePart, humanoid)
			if standing and not buried then
				-- STANDING ON SOMETHING, SO THIS IS A GOOD PLACE -- the lodge floor, a truck's
				-- running board, a branch, the terrain. The net never moves him from here.
				lastGood[player.UserId] = at
			elseif buried or offTheWorld or falling then
				-- BACK WHERE HE WAS STANDING, and if this module never saw that, on the ground over
				-- his own x and z. The second case answers a man who fell through the moment he
				-- arrived.
				local home = lastGood[player.UserId] or at
				local wanted = Body.onGround(
					CFrame.new(home) * ((root :: BasePart).CFrame - (root :: BasePart).CFrame.Position),
					DEFAULT_CLEARANCE_STUDS
				)
				-- COUNTED ONLY WHEN THE BODY ACTUALLY MOVED (Reviewer round 1, note 1). With no
				-- remembered place and no measurable ground the "rescue" would pivot him to where he
				-- already is, and at 4 Hz that is a run of rescues of nobody in the counter whose
				-- whole value is that it stays 0.
				local target = if wanted ~= nil then (wanted :: CFrame).Position else at
				if (target - at).Magnitude > RESCUE_MOVED_STUDS then
					character:PivotTo(wanted :: CFrame)
					if not (root :: BasePart).Anchored then
						(root :: BasePart).AssemblyLinearVelocity = Vector3.zero
					end
					putBack += 1
					rescuedUnderGround += 1
					worstRescueStuds = math.max(worstRescueStuds, (target - at).Magnitude)
					print(
						string.format(
							"[place] RESCUED %s: root (%.0f, %.1f, %.0f) was %s, put back at (%.0f, %.1f, %.0f)",
							player.Name,
							at.X,
							at.Y,
							at.Z,
							if buried
								then "inside solid terrain"
								elseif offTheWorld then string.format("below the floor %.0f", floor)
								else "falling with no floor under it",
							target.X,
							target.Y,
							target.Z
						)
					)
				end
			end
		end
	end
	return putBack
end

-- The same work against a Model rather than a Player, which is the seam a spec uses: a live spec must
-- not freeze and move the one real player in a Play session, because half the client suite is
-- standing in it (a spec that revoked the live gun broke exactly that, Task 34).
function Body.tieCharacter(character: Model?, userId: number, tree: BasePart, config, parent: Instance?): boolean
	-- THE FREEZE IS `holdCharacter`'S, AND SO ARE ITS REFUSALS: no character, no humanoid or no root
	-- means no tie, exactly as before. What a tie adds is the move and the rope.
	local root = Body.holdCharacter(character, userId)
	if root == nil or character == nil then
		return false
	end
	-- ...AND NEVER INSIDE THE HILL (task 192), but NOT snapped like the other three.
	--
	-- `tiePointFor` reads the TREE's OWN BOTTOM FACE, and that is already a measurement of the
	-- ground: a tree stands on it. Replacing it with a ray would be worse, not better -- a tree on a
	-- rock or a platform would tie the offender to the ground far below it, and
	-- `match_safety.spec`'s own fixture (a trunk 700 studs up) says so in one assertion. So the tie
	-- keeps the tree's answer and takes only the ONE-SIDED half of the rule: a point more than
	-- `Body.maxBelowGround()` studs INSIDE the ground is lifted out of it, and a point on or above
	-- the ground is left exactly where the trunk put it.
	local asked = Body.tiePointFor(tree, root.Position, config)
	local clearance = Body.clearanceFor(config)
	local lifted, moved = Body.liftOntoGround(asked.Position, clearance)
	local target = if moved then asked - asked.Position + lifted else asked
	character:PivotTo(target)
	if moved then
		-- The ground the lift found, without asking for it twice: it put the point `clearance`
		-- above it.
		reportPlacement("tie", character.Name, asked, target, lifted.Y - clearance)
	end

	local folder = parent or Body.driveMarkers()
	local previous = folder:FindFirstChild(Body.ropeName(userId))
	if previous then
		previous:Destroy() -- one rope per player, never two (it is re-tied after a respawn)
	end
	ropeFor(root, tree, userId, config, folder)
	return true
end

-- Frees a tied or held player: the humanoid gets back exactly the numbers it had, the root is
-- unanchored and the rope is destroyed. Safe to call on somebody who was never frozen.
--
-- EXCEPT THAT IT WILL NOT HAND BACK A WALKSPEED OF ZERO, and the reason is the failure it would be:
-- a player who cannot walk and has nothing holding him is stuck for the rest of the session, with
-- no rope, no banner and nothing on screen to say why -- the worst kind of bug, and the one Karen
-- would feel first. A saved zero is impossible as this module is written (the save happens BEFORE
-- the zero is written, and `Body` is the only writer of `WalkSpeed` in `src/` -- grepped, task 158),
-- so this is a floor under a thing that cannot happen: `Body.rescued()` counts it, and if that
-- number is ever not 0 then something cleared a `held` row out from under a frozen character and
-- THAT is the bug to fix. Jump is deliberately not floored: a place may really want nobody jumping,
-- and being unable to jump strands nobody.
function Body.untie(player: Player, parent: Instance?)
	Body.untieCharacter(player.Character, player.UserId, parent)
end

function Body.untieCharacter(character: Model?, userId: number, parent: Instance?)
	local saved = held[userId]
	held[userId] = nil
	if character and character.Parent then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and saved then
			local walkSpeed = saved.walkSpeed
			if not (type(walkSpeed) == "number" and walkSpeed > 0) then
				rescued += 1
				walkSpeed = Body.defaultWalkSpeed()
			end
			humanoid.WalkSpeed = walkSpeed
			humanoid.JumpHeight = saved.jumpHeight
			humanoid.JumpPower = saved.jumpPower
		end
		local root = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.Anchored = false
		end
	end
	local folder = parent or Workspace:FindFirstChild("DriveMarkers")
	local rope = folder and folder:FindFirstChild(Body.ropeName(userId))
	if rope then
		rope:Destroy()
	end
end

-- After this, no table in this module is keyed by that user.
function Body.forget(userId: number)
	held[userId] = nil
	-- AND THE APPEARANCE WINDOW (Task 151). A player who leaves inside the five seconds would
	-- otherwise leave a connection held against a character that is gone -- `Body.appearanceWatching`
	-- is the number that proves this line works.
	stopWatching(userId)
	-- AND WHERE HE WAS LAST STANDING (task 192), for the same reason: a table keyed by userId that
	-- nothing ever removes from is a leak, and a rejoining player's old position is not his.
	lastGood[userId] = nil
end

function Body.tracked(): number
	local n = 0
	for _ in pairs(held) do
		n += 1
	end
	return n
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

-- EVERYTHING A BOAR CAN PERCEIVE, with what KIND each one is (task 118). A new function beside
-- `driverPositions` and deliberately not a change to it: that one answers "who is pushing, and who
-- may be tied", this one answers "what can a boar perceive". One predicate answering two unrelated
-- questions is a named cause of death of the previous project, and `Match.playerDrivers` and
-- `Penalty` keep reading the old one unchanged.
--
-- A SHOOTER STANDING ON A POST IS NOW PERCEIVABLE, and that is what makes Karen's central scene
-- possible: he is noticed at 25 studs and flushes the animal only at 15, so a boar can come down
-- the corridor to the line instead of turning back at the first man it can see. Whether it reacts
-- to him at all is `Boar.CONFIG.SENSE.ENABLED`'s decision, in the Brain, not this function's.
-- Design: docs/design/boar-behaviour.md section 8
function Body.boarStimuli(
	teamOf: (Player) -> TeamName?,
	service: any?
): { { id: string, position: Vector3, kind: string } }
	local out = {}
	for _, player in ipairs((service or Players):GetPlayers()) do
		local team = teamOf(player)
		local kind = if team == "Drivers" then "driver" elseif team == "Shooters" then "shooter" else nil
		if kind then
			local character = player.Character
			local root = character and character.PrimaryPart
			if root then
				table.insert(out, { id = tostring(player.UserId), position = root.Position, kind = kind })
			end
		end
	end
	return out
end

return Body
