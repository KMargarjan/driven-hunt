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
function Body.dressFor(team: TeamName?, config): { any }
	local outfit = Body.outfitFor(team, config)
	if not outfit then
		return {}
	end
	-- FLATTENED IN DECLARATION ORDER: the hat first, then the vest (design section 4). The groups
	-- exist so the hat is declared once; a caller still sees one list of rows, which is why
	-- `Body.dress` and every existing spec case are unchanged in shape.
	local rows = {}
	for _, group in ipairs(outfit.parts) do
		for _, row in ipairs(group.rows) do
			table.insert(rows, row)
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

local function wearAccessory(character: Model, group: Group): boolean
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

function Body.dress(character: Model?, team: TeamName?, config): boolean
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
		if wearAccessory(character, group) then
			continue
		end
		slotsFellBack += 1
		for _, row in ipairs(group.rows) do
			table.insert(rows, row)
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
function Body.dressWhenLoaded(player: Player, character: Model, config)
	Body.dress(character, Body.teamOf(player), config)

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
			Body.dress(character, Body.teamOf(player), config)
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
-- SO: pivot now (which is right in DEV and costs nothing), and once more on the next frame IF the
-- character has drifted more than a stud from where it was put. `Body.settled()` counts how often
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
		Body.dressWhenLoaded(player, character, config)
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
			Body.settle(character, cframe)
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

-- The same work against a Model rather than a Player, which is the seam a spec uses: a live spec must
-- not freeze and move the one real player in a Play session, because half the client suite is
-- standing in it (a spec that revoked the live gun broke exactly that, Task 34).
function Body.tieCharacter(character: Model?, userId: number, tree: BasePart, config, parent: Instance?): boolean
	if not character or not character.Parent then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not (root and root:IsA("BasePart")) then
		return false
	end

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
	character:PivotTo(Body.tiePointFor(tree, root.Position, config))

	local folder = parent or Body.driveMarkers()
	local previous = folder:FindFirstChild(Body.ropeName(userId))
	if previous then
		previous:Destroy() -- one rope per player, never two (it is re-tied after a respawn)
	end
	ropeFor(root :: BasePart, tree, userId, config, folder)
	return true
end

-- Frees a tied player: the humanoid gets back exactly the numbers it had, the root is unanchored and
-- the rope is destroyed. Safe to call on somebody who was never tied.
function Body.untie(player: Player, parent: Instance?)
	Body.untieCharacter(player.Character, player.UserId, parent)
end

function Body.untieCharacter(character: Model?, userId: number, parent: Instance?)
	local saved = held[userId]
	held[userId] = nil
	if character and character.Parent then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and saved then
			humanoid.WalkSpeed = saved.walkSpeed
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
