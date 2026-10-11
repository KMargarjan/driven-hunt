# The beater kit, part 1: the OUTFIT (both roles)

Task 151. Design for `docs/design/beater-kit.md`, written to `reviews/task-151/BRIEF.md` (Builder
carrying the Director, 2026-10-11) and `docs/research/2026-10-11-beater-kit.md`.

This document is from now on **the** design of what a character wears. It is a **delta** to
`docs/design/map-generator.md` §10 and `docs/design/drive.md` §5.4 and overrides both where they
disagree (see §14, *Superseded text*). The horn is **Task 152** and is not designed here beyond one
sentence naming its future owner (§13).

---

## 1. What the system must do, and what it must not do

### Must

| # | Requirement | Source |
|---|---|---|
| M1 | **Everybody with a role wears green**: jacket and trousers in `Color3.fromRGB(86, 80, 56)` — torso, both arms, both legs | Karen 2026-10-10 ~22:00, *"we need same color by default what is our arms … so all clothe is that color"*; note §3 |
| M2 | **A hunter (`Shooters`) adds the orange hat**, exactly the two parts the repo already builds | Karen's doc *"Also will have orange hat"*; `Match.Body`'s `OUTFITS.Shooters` |
| M3 | **A beater (`Drivers`) adds the orange hat AND the orange vest**, exactly the four plates the repo already builds | Karen's doc *"Beater will have orange hat and orange vest"*; `OUTFITS.Drivers`, Task 82 |
| M4 | **Nothing may hide the green**: the player's own `Shirt`, `Pants`, `ShirtGraphic` and layered-clothing accessories go | note §4.1 — a mesh standing off the limb cannot be coloured by a write to the limb |
| M5 | **The head keeps the player's own colour**; hair and head accessories are left alone | brief 1.4; the hat was built to clear a default avatar's hair (Task 77) |
| M6 | **One writer**, and it is the one that already writes characters: `Match.Body` | CLAUDE.md rule 3; brief 1.6 |
| M7 | **Karen can see a beater in the Forest Test**, a world with no beaters and no `Teams` | brief 1.8 |
| M8 | The colour is **matched, not approximated**, with no upload, no Robux and no new asset id | note §4.2: the catalog route is measured shut |

### Must not

| # | Prohibition | Why |
|---|---|---|
| N1 | **Never `Humanoid:ApplyDescription`** | it rebuilds the character's parts, and this module welds plates to `UpperTorso` (`Body.dress`) and anchors a tied player's root (`Body.tieCharacter`). Note §4.1 |
| N2 | **No second writer of appearance**, and nothing on the client | a client-drawn outfit is per-client, untrustworthy, and cannot be screenshotted from the server (map-generator §10.1) |
| N3 | **No new feature flag.** `ORANGE_OUTFITS` is the switch and it is already `default = true` | brief 1.7; `src/shared/Flags/init.luau`, `ORANGE_OUTFITS` |
| N4 | **No backup of the player's own clothes.** Nothing is saved and nothing is restored | brief 2.3 — the honest answer is that the next respawn restores them |
| N5 | **The outfit is never a source of truth.** `Match.Penalty.judge` keeps deciding from teams (`Body.teamOf`) | map-generator §10.2 item 3; two representations of one fact is this project's named failure mode |
| N6 | **No yield inside `Body.dress`** (no `WaitForChild`, no `task.wait`) | it runs inside the `CharacterAdded` handler `Body.place` depends on for its pivot ordering |
| N7 | **No horn, no compass, no beater line, no countdown, no economy** | brief 0 and 3; note §7 |

---

## 2. Owner, and where it lives

**`ServerScriptService.Match` → `Match.Body`** — `src/server/Match/Body.luau`. Unchanged owner,
widened job. It is **the single writer of all five of these**:

| Written thing | Function | Nothing else writes it |
|---|---|---|
| the base clothing colour (`BodyColors`) | `Body.paint` | `BodyColors` appears in **no other file in the repo** — grep for `BodyColors` over `*.luau` returns one hit, a comment in `Body.luau` about `HumanoidDescription` scaling. There is no second writer today and this design creates none |
| the removal of the player's own clothing | `Body.strip` | — |
| the hat and the vest parts | `Body.dress` → `OUTFITS` | — |
| the outfit folder `HuntOutfit` | `Body.dress` (`Body.OUTFIT_NAME`) | — |
| `Player.Team` | `Body.setTeam` | drive.md §5.1 and the `Body.luau` header already state this |

**Who may ask it to dress somebody** — two callers, both server, both composition-root-level:

1. **`ServerScriptService.Match`** (`src/server/Match/init.luau`): `Body.place` (the drive's
   placement), `Body.setTeam` (the roster), `Match.watchCharacter` (respawn and Reset),
   `Body.tie` (a re-tie re-dresses).
2. **`ServerScriptService.ForestTestBoot`** (`src/server/ForestTestBoot.server.luau`), in the
   playtest world only — §9.

**Explicitly not:** the Hud (`src/client/Hud/init.luau` draws the screen; it already derives its
`DRIVER`/`SHOOTER` badge from `Player.Team` through `Match.myTeam`, which is a *read*), the client at
all, the map, `Boar`, `Weapon`, `ForestTest` (the data/world module writes no Instance on a player —
see §9).

**One more owner rule, written down because it is invisible otherwise:** nothing in this repo may
call `Humanoid:ApplyDescription`, `Humanoid:ApplyDescriptionReset` or write
`Humanoid.HumanoidDescription` on a player character. Either would restore the clothes `Body.strip`
removed and overwrite the colour `Body.paint` wrote, from outside the owner. Today no file does
(grep: `ApplyDescription`, `HumanoidDescription` → one comment).

---

## 3. The data: one base, part rows declared once

The row shape the brief asks for (2.2). `OUTFITS` stops being "team → part rows" and becomes
"team → a base plus a list of part groups", so that Karen's two sentences are two rows and **the hat
is declared once**.

```luau
-- src/server/Match/Body.luau

export type TeamName = "Drivers" | "Shooters"          -- unchanged

export type BaseRow = {
    color: Color3,
    limbs: { string },         -- BodyColors property STEMS; the property is stem .. "Color3"
    clearClasses: { string },  -- ClassNames to destroy
    clearLayered: boolean,     -- see Body.isLayered, §6
}

-- MEASURED off both glove models' own texture_baseColor.png olive cuff pixels, median over
-- 533,692 pixels (docs/research/2026-10-11-beater-kit.md §3). NOT sampled from a lit frame.
Body.BASE_COLOR = Color3.fromRGB(86, 80, 56)

-- THE ONE BASE, AND BOTH ROLES POINT AT THIS TABLE. Same identity, so "everyone wears the same
-- green" is structural and a spec asserts it with `==` rather than by comparing six numbers twice.
local BASE: BaseRow = {
    color = Body.BASE_COLOR,
    limbs = { "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" },  -- the HEAD IS NOT HERE
    clearClasses = { "Shirt", "Pants", "ShirtGraphic" },
    clearLayered = true,
}
Body.BASE = BASE

local HAT  = { <brim row>, <crown row> }                       -- the two Task 77 rows, verbatim
local VEST = { <front>, <back>, <leftSide>, <rightSide> }      -- the four Task 82 rows, verbatim

-- hunter = base + hat.   beater = base + hat + vest.   One statement each.
local OUTFITS: { [string]: { base: BaseRow?, parts: { { any } } } } = {
    Shooters = { base = BASE, parts = { HAT } },
    Drivers  = { base = BASE, parts = { HAT, VEST } },
}
```

**Nothing about the hat's or the vest's geometry changes** (brief 1.5): the rows keep their studs,
their `scale`/`pad`/`anchor`, their `fallbackLimb`, their `rotationDeg` and `OUTFIT_COLOR =
Color3.fromRGB(255, 112, 0)`. `Body.fit` is untouched, and so is the clearance invariant
`match_outfit.spec` asserts over three torsos.

**Naming.** Karen says *beater* and *hunter*; the code's `TeamName` is `"Drivers"` and `"Shooters"`,
and this task does **not** rename it — the strings reach `Match.Roster`, `tests/client/Role.luau`,
the Hud badge and a dozen specs. The mapping lives in exactly one place:

```luau
Body.ROLE_WORDS = { hunter = "Shooters", beater = "Drivers" }   -- Karen's word -> the team name
function Body.teamForWord(word: string?): TeamName?             -- the only translator
```

A rename is §15 item 5, for the Director.

---

## 4. Public interface

Additions and changes to `Match.Body`. Everything else in that module is unchanged.

```luau
-- PURE. What this role's clothing is, or nil. Reads the flag only through `config`.
function Body.baseFor(team: TeamName?, config): BaseRow?

-- PURE. The role's part rows, FLATTENED in declaration order: the hat first, then the vest.
-- Shooters -> 2 rows. Drivers -> 6 rows. Unchanged signature, unchanged element shape.
function Body.dressFor(team: TeamName?, config): { any }

-- PURE. Is this instance layered clothing that would hide a limb's colour? (§6)
function Body.isLayered(instance: Instance): boolean

-- WRITES. Destroys the cleared classes and the non-spared layered accessories on `character`.
-- Returns how many instances it removed. nil base -> 0 and nothing touched.
function Body.strip(character: Model?, base: BaseRow?): number

-- WRITES. Finds or creates the character's ONE `BodyColors` and writes `base.limbs` to
-- `base.color`. Never writes `HeadColor3`. nil base -> false and nothing touched.
function Body.paint(character: Model?, base: BaseRow?): boolean

-- WRITES, and it is the production entry point. Unchanged signature. Order:
--   1. destroy any existing `HuntOutfit` folder            (as today)
--   2. Body.strip(character, baseFor(team, config))
--   3. Body.paint(character, baseFor(team, config))
--   4. build the part rows, weld them to the limb found    (as today, via Body.fit)
-- Returns false ONLY when it failed to do something it should have:
--   * no character, or character.Parent == nil
--   * a base was wanted and `paint` returned false
--   * rows were wanted and NONE could be made (the folder is destroyed again, as today)
-- Flag off or no team is a SUCCESS with nothing to do, and the folder is still cleared.
-- DOES NOT YIELD (N6).
function Body.dress(character: Model?, team: TeamName?, config): boolean

-- WRITES, and the ONE path every caller uses from now on: dress now, then hold a bounded window
-- over this character so a late appearance load cannot undo it (§5).
function Body.dressWhenLoaded(player: Player, character: Model, config)

-- READ-ONLY counters, for a spec and for the harness note (they are the proof, not a feeling):
function Body.appearanceWatching(): number   -- open windows; must return to 0
function Body.strayCleared(): number         -- cleared-class instances the window caught
function Body.repaints(): number             -- paints performed

-- Unchanged, and now routed through dressWhenLoaded instead of dress:
function Body.setTeam(player: Player, name: TeamName?, config)
```

`Body.forget(userId)` additionally closes that user's window and clears its row (it is already
called by `Match.forget`, and §9 adds the Forest Test's call).

**No remote, no RemoteEvent, no RemoteFunction, no client module.** The entire system is server
writes that the engine replicates. `src/shared/Drive/` is untouched; the snapshot carries nothing
about outfits, because the character *is* the message.

---

## 5. The dress moments, and the appearance-load race

Today there are four call sites, all of which stay: `Body.place`'s `pivot` handler,
`Body.setTeam`, `Match.watchCharacter`'s `CharacterAdded` handler, and `Body.tie` on a successful
tie. Each becomes `Body.dressWhenLoaded`.

**The race, and why the design must not depend on an order.** `Body.dress` welds parts onto limbs,
which survives anything the engine does afterwards. A `BodyColors` write and a destroyed `Shirt` do
**not**: a character's appearance is applied **asynchronously, after the model exists** — which is
precisely why `Player.CharacterAppearanceLoaded` and `Player:HasAppearanceLoaded()` exist at all. If
the avatar's own shirt and `BodyColors` land *after* our write, Karen sees the player's own clothes
and none of the green. I cannot measure which way round it happens here (Studio is not available to
the Architect: `.agent-evidence/INDEX.md`), so the design is **order-independent**:

```
Body.dressWhenLoaded(player, character, config):
  1. Body.dress(character, Body.teamOf(player), config)        -- the hat is on immediately
  2. open ONE window per userId (replacing any previous one):
       character.ChildAdded, for APPEARANCE_WATCH_SECONDS = 5:
         child:IsA("BodyColors")                  -> Body.paint(character, base)   [repaints += 1]
         child is a cleared class, or isLayered    -> child:Destroy()               [strayCleared += 1]
         anything else                             -> ignored
  3. at the window's close: ONE final Body.paint(character, base)
     (the engine can MODIFY an existing BodyColors instead of adding one, which fires no ChildAdded)
  4. close: disconnect, drop the row
```

Guards: the handler does nothing if `player.Character ~= character` or `character.Parent == nil`
(so a window belonging to a dead character is inert as well as short-lived); the window is keyed by
userId and replaced by the next character, so a player can never hold two; `Body.forget` closes it.
`Body.appearanceWatching()` returning 0 after the suite is the leak proof.

`CharacterAppearanceLoaded` is **not** the trigger, deliberately: `HasAppearanceLoaded()` is a
player-level fact, and the event can fire before a handler connects to it, so either form of
"wait for the event" can lose the same race the window cannot. The event may be used later to close
the window *early*; that is an optimisation, not a correctness condition.

**The measurement this owes the next task:** `Body.strayCleared()` and `Body.repaints()` go into the
harness note. If `strayCleared` is 0 on every run and Karen sees green, the window caught nothing and
5 s can be shortened or dropped — a number, not an opinion.

---

## 6. What counts as layered clothing (brief 2.4)

A **predicate**, not a list of ids:

```luau
Body.SPARED_ACCESSORY_TYPES = {
    Enum.AccessoryType.Hat, Enum.AccessoryType.Hair, Enum.AccessoryType.Face,
    Enum.AccessoryType.Eyebrow, Enum.AccessoryType.Eyelash,
}

function Body.isLayered(instance: Instance): boolean
    if not instance:IsA("Accoutrement") then return false end
    if instance:IsA("Accessory") and <AccessoryType is in SPARED> then return false end   -- spare wins
    return instance:FindFirstChildWhichIsA("WrapTarget", true) ~= nil
        or instance:FindFirstChildWhichIsA("WrapLayer", true) ~= nil
end
```

* **Why `WrapTarget`/`WrapLayer` and not `AccessoryType`.** The note's reading of Roblox's appearance
  page: a layered accessory is one carrying those, i.e. **a mesh standing off the limb's own
  surface** — which is exactly the failure mode (no colour written to a limb can show through one).
  `AccessoryType` is the catalog's taxonomy and is `Unknown` on anything a spec builds; the wrap
  objects are what a spec can construct and what the engine actually renders. `AccessoryType` is used
  only for the **spare** list, where being wrong costs a hat, not the design.
* **Spared, deliberately:** hats, hair, face, eyebrows, eyelashes. Nothing in Karen's doc asks for
  them to go, and the orange hat was built to clear a default avatar's hair (Task 77). The spare
  check runs **first**, so a hat that happens to carry a wrap is still spared.
* **Classic clothing** is separate and simpler: the `clearClasses` list destroys `Shirt`, `Pants`,
  `ShirtGraphic` by ClassName.
* **Rule 7 does not apply.** These are runtime Instances on a respawnable character, not files. The
  outfit folder is already destroyed and rebuilt every dress.

---

## 7. Idempotence, team swap, respawn, the flag off, and "undress" (brief 2.3)

| Event | What happens |
|---|---|
| **dress twice in a row** | folder destroyed and rebuilt (as today); `paint` rewrites the **same** `BodyColors` instance, so nothing accumulates; `strip` finds nothing new. One hat, one vest, one `BodyColors`, always |
| **team swap** (`Body.setTeam`) | the base is the **same table** for both roles, so the colour does not change and is not re-decided; the parts go hat ↔ hat + vest. A beater who becomes a hunter loses four plates and keeps the green |
| **respawn / Reset / death** | a NEW character, so the colour is gone with the old one. `Match.watchCharacter`'s `CharacterAdded` handler re-dresses — plus the window, which is what makes the *colour* survive the respawn as reliably as the hat does |
| **flag off** (`ORANGE_OUTFITS = false`) | `baseFor` and `dressFor` both answer empty: **nobody is dressed, and nobody's own clothes are touched**. The existing folder is still cleared, so switching the flag off undresses at the next respawn, exactly as today |
| **"undress"** | there is no undress, and no backup (N4). A colour that has overwritten the player's own is restored by **the next respawn**, because the engine loads the avatar's own appearance onto the new character. Within a session, a dressed player's own clothes do not come back. That is the honest behaviour; nothing here saves or restores anything |
| **flag flipped mid-session** | cannot happen in a way this system sees: `Match.CONFIG.OUTFITS_ENABLED` is read once at require time (`src/server/Match/init.luau`), which is the one permitted shape |

---

## 8. R6 and R15, and what counts as a miss (brief 2.5)

* **`BodyColors` has one property per R6 limb and the engine maps them onto an R15 rig's parts.** The
  base therefore writes the same five properties on both rigs, and **a missing limb is not a miss**:
  `paint` writes properties on one instance and has no limb to look for. It returns false only if it
  could not find or create the `BodyColors` at all.
* **For PARTS nothing changes**: a limb is looked up by `row.limb`, then `row.fallbackLimb`
  (`UpperTorso` → `Torso`), and a row whose limb is absent is **a counted miss** exactly as today —
  `made == 0` destroys the folder and returns false.
* So on an R6 rig: five properties painted, the hat on `Head`, the vest on `Torso` via `fallbackLimb`.
  On a head-less rig: painted, and `dress` returns false because no part could be made.

---

## 9. The Forest Test seam (brief 1.8 and 2.6)

The playtest world has no beaters (its drivers are phantoms — `ForestTest.boarThreats` inserts
`kind = "driver", phantom = true` positions with nobody standing on them) and no `Teams`. Karen tests
alone there. Three owners, each answering one question:

| Question | Owner | Where |
|---|---|---|
| **which role has this player ASKED for** | `ServerScriptService.ForestTest` | `src/server/ForestTest/init.luau`, `state.roles[userId]` — beside `state.picks`, which already answers "which stand" the same way |
| **which role this player IS** | `Match.Body` | `Player.Team`, written by `Body.setTeam`. The request is not a second copy of the truth: the team is the truth, and `Body.teamOf` stays the one reader |
| **what they wear** | `Match.Body` | `Body.dressWhenLoaded`, from the same call as the team |

**The interface** (pure half in `ForestTest`, so a spec drives it in the DEV place with no world):

```luau
export type RoleWord = "hunter" | "beater"

ForestTest.ROLE_DEFAULT: RoleWord = "hunter"             -- brief 1.8: he spawns as a hunter
function ForestTest.parseRole(text: string): RoleWord?   -- PURE. "/beater", "/hunter", case- and
                                                         -- whitespace-insensitive; anything else nil
function ForestTest.roleOf(userId: number): RoleWord     -- the stored request, else the default
function ForestTest.setRole(userId: number, role: RoleWord): RoleWord
function ForestTest.clearRole(userId: number)
```

`ForestTest` writes **no Instance** for this and does not require `Match` — it answers in Karen's
words, and the boot translates them through `Body.teamForWord`. That keeps the module's existing
property ("it writes no Instance on a player") and avoids a second place where "beater" means
`Drivers`.

**The wiring, all of it in `src/server/ForestTestBoot.server.luau`** (the world's composition root,
which owns nothing and decides nothing):

1. once, at boot: `Body.ensureTeams()` — so `Player.Team` is a real Team in this world too and
   `Body.teamOf` answers the same way in both worlds;
2. in the existing `Players.PlayerAdded` → `player.CharacterAdded` handler, **first line**:
   `Body.setTeam(player, Body.teamForWord(ForestTest.roleOf(player.UserId)), Match.CONFIG)`.
   The existing root wait, pick window, spawn pivot and leash are untouched;
3. `player.Chatted` → `ForestTest.parseRole(text)`; on a hit, `ForestTest.setRole` then
   `Body.setTeam(player, Body.teamForWord(role), Match.CONFIG)`, and **print one line** naming the
   role and the number of parts worn. Server-only: no remote, no input binding, no client module, no
   camera. The chat is a **dev command in a playtest world**, not a game mechanic;
4. `Players.PlayerRemoving` (it already calls `ForestTest.clearPick`): add `ForestTest.clearRole` and
   `Body.forget(player.UserId)`. **`Match.forget` never runs in this world**, so without this line
   the window row and `held` would be the one thing that leaks here.

**The flag is read once, by its owner.** `ForestTestBoot` passes `Match.CONFIG`, never
`Flags.isOn("ORANGE_OUTFITS")`: the flag's `owner` is `"ServerScriptService.Match"`
(`src/shared/Flags/init.luau`), and a second boundary read would be a second answer.

**How it cannot leak into the real match** — the two guards already exist and are quoted:
`src/server/ForestTestBoot.server.luau` returns immediately unless
`Map.EXPECTED_WORLD == "forest-test"`; `src/server/MatchBoot.server.luau` returns in that world
(*"the world is forest-test: ForestTestBoot owns this place"*). The harness runs in the DEV place, so
every line above is inert during a harness run and the only Forest Test code a spec can reach is the
pure half.

**Two deliberate non-changes, named so nobody "fixes" them silently:**

* `ForestTest.boarThreats` still reports every real player as `kind = "shooter"`, whatever role they
  asked for. A beater who actually pushed boars would change what the waves do and what
  `PACE.DRIVER_RUN_STUDS` sees — that is a boar/drive task, not this one (§15 item 6).
* `Weapon.setArmingPolicy` in that world still arms everybody, so a "beater" carries a shotgun. The
  beater's horn is Task 152 and the weapon licence is later (note §7).

**The trigger, and its one measurement.** `Player.Chatted` is the primary: server-side, one line, no
instance, no container. Whether it fires depends on the place's chat version, and I cannot test it
from here. **If it does not fire in the Forest Test place**, the fallback is a `TextChatCommand`
instance created at run time by `ForestTestBoot` (`PrimaryAlias = "/beater"`,
`SecondaryAlias = "/hunter"`, parented to `TextChatService`, `Triggered` connected on the server) —
a run-time instance in a non-Rojo container, exactly as `Workspace.DriveMarkers` is. Either way the
seam, the owners and every function above are identical: the trigger calls `ForestTest.setRole` plus
`Body.setTeam` and nothing else. **The review request must say which one fired and paste the console
line**; a trigger that was not seen to fire is not evidence.

---

## 10. The penalty interaction (brief 2.7)

**The order stays dress → tie**, and it is already written that way in two places:
`Match.watchCharacter` dresses on `CharacterAdded` and only then waits for `PrimaryPart` and calls
`Body.tie`; `Body.tie` re-dresses *after* a successful tie so a re-tied player is not the one person
in the drive wearing nothing.

**A `BodyColors` write cannot disturb the tie**, and neither can the stripping:

* `paint` writes six-property colours on one non-physical instance. It replaces no part, breaks no
  weld, moves nothing and does not yield (note §4.1: *"It touches no part"*). This is the whole reason
  route 2 was chosen over `ApplyDescription`, which **does** rebuild parts.
* `strip` destroys `Shirt`/`Pants`/`ShirtGraphic` (not `BasePart`s at all) and layered accessories.
  The tie's state lives in `humanoid.WalkSpeed`/`JumpHeight`/`JumpPower`, `root.Anchored` and a rope
  Part in `Workspace.DriveMarkers` — none of them a child of an accessory. The outfit's own
  `WeldConstraint`s are anchored to `Head`/`UpperTorso`/`Torso`, never to an accessory, so destroying
  one cannot orphan a weld.
* The §5 window can fire **after** a tie. It paints and may destroy a stray shirt; it writes nothing
  physics-related, so a tied player stays tied, anchored and at the tree.
* `Match.Penalty.judge` keeps reading teams, and every worn part keeps `CanQuery = false`, so the
  outfit remains invisible to the shot that the penalty is judged on (N5).

---

## 11. What it reads from, and writes to, other systems

| Direction | Thing | Owner |
|---|---|---|
| reads | `Match.CONFIG.OUTFITS_ENABLED` (the one flag read, at the boundary) | `ServerScriptService.Match` — `src/server/Match/init.luau` |
| reads | `Player.Team` via `Body.teamOf`, to know the role | `Match.Body` (itself) |
| reads | the limb's own `Size` and `CFrame`, through `Body.fit` | the engine / the player's avatar |
| reads | `ForestTest.roleOf` (playtest world only) | `ServerScriptService.ForestTest` |
| writes | `character.HuntOutfit` folder, its parts and welds | `Match.Body` |
| writes | `character` → one `BodyColors` | `Match.Body` |
| destroys | the character's `Shirt`, `Pants`, `ShirtGraphic`, non-spared layered accessories | `Match.Body` |
| writes | `Player.Team`, `Player.Neutral` | `Match.Body` (`Body.setTeam`) |
| **does not touch** | the camera, the cursor, input, the Hud, any remote, `Workspace`, the boar, the weapon, the viewmodel | their own owners |

Readers that will *see* the change and must not be edited for it: `src/client/Hud/init.luau`'s
badge (reads `Player.Team`), `tests/client/Role.luau`, `Match.Roster`, `Match.playerDrivers`,
`Body.boarStimuli`. None of them reads an outfit, which is the property N5 protects.

---

## 12. External sources

| # | Source | Licence / maintenance | Does well | Does badly | Used for |
|---|---|---|---|---|---|
| 1 | **Roblox creator-docs, "Character appearance"** — [content/en-us/characters/appearance.md](https://github.com/Roblox/creator-docs/blob/main/content/en-us/characters/appearance.md) | CC BY 4.0 (docs) / MIT (samples); Roblox's own repo, actively maintained | names `HumanoidDescription` as the atomic route, and names layered accessories as `WrapTarget`/`WrapLayer`-carrying — the basis of `Body.isLayered` | says nothing about the `CharacterAdded`-vs-appearance-load order, nor about what `ApplyDescription` does to existing welds | **rejecting** route 1 (N1) and **adopting** the layered predicate (§6) |
| 2 | **Roblox Engine reference, `BodyColors`** — [create.roblox.com/docs/reference/engine/classes/BodyColors](https://create.roblox.com/docs/reference/engine/classes/BodyColors) | Roblox documentation, no open licence (cited, not copied); maintained with the engine | exhaustive and tiny: six `Color3` properties and nothing else, which is why the write cannot have a side effect | does not spell out the R6→R15 mapping, nor precedence against clothing drawn over the limb | the **adopted** colour route (§3, §8) |
| 3 | **DevForum, "Changing body colors on the server"** — [devforum.roblox.com/t/751923](https://devforum.roblox.com/t/changing-body-colors-on-the-server/751923) | community post, no licence; 2020, unmaintained | the exact pattern **borrowed** (rule 2): find or create the character's `BodyColors`, then write the properties | a forum answer with no test, and it ignores the thing that defeats it — clothing standing over the limb | `Body.paint` (§4) |
| 4 | **DevForum, "Applying humanoid clothing on the client end"** — [devforum.roblox.com/t/287003](https://devforum.roblox.com/t/applying-humanoid-clothingetc-on-the-client-end/287003) | community post, no licence; 2019, unmaintained | states the constraint that matters: appearance applied on the client is right for one player only | anecdotal, pre-layered-clothing | **N2**: server-only, no client writer |
| 5 | **Roblox Engine reference, `Player.CharacterAppearanceLoaded` / `Player:HasAppearanceLoaded`** — [CharacterAppearanceLoaded](https://create.roblox.com/docs/reference/engine/classes/Player#CharacterAppearanceLoaded), [HasAppearanceLoaded](https://create.roblox.com/docs/reference/engine/classes/Player#HasAppearanceLoaded) | Roblox documentation; maintained | proves appearance arrives **after** the character exists — the race §5 is built around | promises no ordering against a `CharacterAdded` handler, and `HasAppearanceLoaded` is player-level, not per character | **rejecting** "wait for the event" in favour of the order-independent window (§5) |
| 6 | **Roblox Engine reference, `Player.Chatted`** and **`TextChatCommand`** — [Player.Chatted](https://create.roblox.com/docs/reference/engine/classes/Player#Chatted), [TextChatCommand](https://create.roblox.com/docs/reference/engine/classes/TextChatCommand) | Roblox documentation; maintained (`TextChatCommand` is the current API) | a server-side dev command with no remote and no input owner | `Player.Chatted`'s behaviour depends on the place's chat version, and neither can be measured from this run | §9's trigger, primary plus fallback, **with the measurement named** |
| 7 | **The field: `jagdjuenger.de` "Drückjagd-Ausrüstung"** — [link](https://www.jagdjuenger.de/ausruestung/drueckjagd-ausruestung/); **`alljagd.de` Signal- & Warnkleidung** (UVV Jagd §4 Abs. 12) — [link](https://www.alljagd.de/signal-warnkleidung); **`livingactive.de` "Als Treiber auf der Drückjagd"** — [link](https://www.livingactive.de/blog/als-treiber-auf-der-drueckjagd-unsere-empfehlungen/); control case **Texas blaze-orange law** — [link](https://tpwd.texas.gov/education/hunter-education/blaze-orange-laws) | editorial / regulatory web pages, no licence; commercially maintained, not versioned | all three agree on the shape: base clothing + an orange torso panel visible **front and back** + orange headgear, and jagdjuenger is explicit that a band or a hat alone is **not** enough. Texas independently requires 144 in² front **and** back | retailers' interest is selling clothes, and a German accident rule is not a Roblox number | **confirming** the four-plate wrap plus the hat (M2, M3) and that the vest is not optional for a beater |

**Pattern adopted, and why.** Route 2 of the note: **`BodyColors` written directly, by the module
that already writes the character**, plus **grey-box parts** for the orange. It is the only route
that gets Karen's exact colour with no upload and no Robux (the catalog is measured shut: the named
vest is 50 R$ and `IsPublicDomain: false`, and a free-pool search over six keywords found no
blaze-orange hi-vis vest and no orange hunting cap), and the only one that cannot disturb the welds
and the tie this module already owns. **Where it is borrowed:** the find-or-create `BodyColors`
pattern from source 3; the layered-clothing predicate from source 1; the hat and vest geometry from
this repo's own Tasks 77 and 82, unchanged; the colour measured off the two glove models'
`texture_baseColor.png`. **What is invented:** the §5 window — there is no published pattern for
"hold a character's appearance against a late engine write", so the reason is recorded in §5 and the
counters exist to show whether it was needed at all.

---

## 13. Numeric targets

| Thing | Value | Where it comes from |
|---|---|---|
| base clothing colour | **`Color3.fromRGB(86, 80, 56)`** | median over 533,692 olive cuff pixels of both glove albedo maps (note §3) |
| orange | `Color3.fromRGB(255, 112, 0)` | unchanged `OUTFIT_COLOR` |
| `BodyColors` properties written | **5 of 6** (`Torso`, `LeftArm`, `RightArm`, `LeftLeg`, `RightLeg`); `HeadColor3` never written | M5 |
| parts worn, hunter | **2** (`Hat`, `HatCrown`) | Task 77, unchanged |
| parts worn, beater | **6** (hat 2 + vest 4) | Task 82, unchanged |
| vest clearance | every plate's inner face ≥ `VEST_GAP` (0.12) clear of the limb's surface, on any torso | Task 82 invariant, still asserted |
| cleared classes | **3** (`Shirt`, `Pants`, `ShirtGraphic`) + every non-spared layered accessory | M4 |
| spared accessory types | **5** (Hat, Hair, Face, Eyebrow, Eyelash) | M5 |
| `Body.dress` instance budget | ≤ **14** created per character: 1 folder + 6 parts + 6 welds + at most 1 `BodyColors` | — |
| `Body.dress` yields | **0** | N6 |
| appearance window | **5 s** per character, event-driven, **1** extra paint at its close | §5 |
| paints per character, steady state | **2** (dress + window close), plus 1 per stray `BodyColors` and 1 per team swap | §5, §7 |
| open windows after a run | **0** (`Body.appearanceWatching()`) | leak proof |
| per-frame cost | **none** — no `Heartbeat`, no `RunService` connection anywhere in this system | — |
| Forest Test role default | `"hunter"` → `Shooters` | brief 1.8 |
| Forest Test chat aliases | **2** (`/hunter`, `/beater`) | §9 |
| new remotes, new flags, new asset ids, Robux | **0, 0, 0, 0** | N2, N3, M8 |

---

## 14. Superseded text

Not a contradiction to resolve by code, so it is named here rather than left for an audit to find:

* `docs/design/map-generator.md` §10 (and its table "Shooter → `Hat` … Driver → `Vest`, 2.2 × 1.6 ×
  1.3") — superseded by §3 of this document. Its §10.3 "it merges OFF" is also stale: the flag is ON
  by default since Task 82.
* `docs/design/drive.md` §5.4 and the `Body.luau` row in its module table — superseded by §2, §3
  and §4 of this document.
* `GAME_DESIGN.md`'s *System owners* row for the outfit must be made to **mirror this design**
  (CLAUDE.md rule 3): owner `ServerScriptService.Match` → `Match.Body`, file
  `src/server/Match/Body.luau`, design `docs/design/beater-kit.md`. That edit is the Builder's.
* The two older designs are not edited in this task (the Architect writes designs, and this run
  writes one file). They are regenerated or deleted-with-a-pointer by a later Architect run.

---

## 15. Testing

**The gate for this task is the full `test` AND `test2`, for the review round as well as the PR.**
`src/server/Match/Body.luau`, `src/server/Match/init.luau`, `tests/server/match_outfit.spec.luau` and
`tests/client/outfit_client.spec.luau` are all in `TWO_PLAYER_PATHS` (`tools/agents.py`). A
`--scope auto` run does not help here either: `src/server/ForestTest/` is unmapped in
`BLAST_RADIUS`, which resolves to the whole suite and is tagged `scope=all` — full evidence, and
`scope_verdict` therefore still asks for the `[harness2]` line.

### Server spec — `tests/server/match_outfit.spec.luau` (extend; it already builds rigs at y = 900 and never touches the live player)

1. **the flag row**, unchanged assertions; plus the `why` text still describes the ON branch.
2. **`baseFor` is pure and is ONE base**: `baseFor("Shooters", ON) == baseFor("Drivers", ON)` (table
   identity), `.color == Color3.fromRGB(86, 80, 56)`, `.limbs` is exactly the five stems and
   **contains no `"Head"`**, `.clearClasses` is exactly the three; `baseFor(team, OFF)` and
   `baseFor(nil, ON)` are nil.
3. **`dressFor` composes**: `Shooters` → 2 rows `Hat`, `HatCrown`; `Drivers` → 6 rows in order
   `Hat, HatCrown, VestFront, VestBack, VestLeftSide, VestRightSide`; **the hat rows are the same
   tables in both** (declared once); both `{}` with `OFF`.
4. **`paint` over a rig**: one `BodyColors` created, the five properties equal the base colour,
   `HeadColor3` still holds the value the rig gave it; painting twice leaves **one** instance;
   `paint(rig, nil)` creates nothing.
5. **`strip` over a rig** carrying a `Shirt`, `Pants`, `ShirtGraphic`, a layered `Accessory`
   (MeshPart handle + a `WrapLayer` child), a rigid `Hat`-type accessory and a `Hair`-type
   accessory → the first four are gone, the hat and the hair remain; the return count is 4.
6. **`isLayered`** directly: wrap-carrying accessory true; same accessory typed `Hat` false; a plain
   `Part` false.
7. **`dress` end to end** on an R15 rig, an R6 rig (`Torso`, no `UpperTorso`) and the scaled torso:
   part count per role, `CanQuery == false`, `Massless`, `CanTouch == false`, `CastShadow == false`,
   `Anchored == false`, a `WeldConstraint` per part with `Part0` the limb, and the existing clearance
   invariant. On the R6 rig the vest falls back to `Torso` and `paint` still writes five properties
   and is **not** a miss.
8. **misses stay misses**: a rig with no `Head` and no torso → `dress` returns false and no folder
   survives.
9. **the window** (`dressWhenLoaded`, driven against a rig and a fake player seam, or against
   `Body.dress` plus a direct `ChildAdded` fire): a `Shirt` added inside the window is removed and
   `strayCleared` increments; a `Hat` added is kept; a `BodyColors` added is painted; after the
   window closes a new `Shirt` survives; `Body.appearanceWatching()` returns to 0.
10. **the live case** (flag ON by default): every teamed character has the folder, the right part
    count for its team, and a `BodyColors` whose torso/arm/leg colours equal the base and whose head
    colour does not; no `Shirt`/`Pants` on a dressed character. `TestKit.note` prints the counts,
    `strayCleared` and `repaints`.

### Forest Test spec — `tests/server/forest_stand.spec.luau` (extend, pure only)

`parseRole` for `/beater`, `/hunter`, `  /BEATER `, `/horn`, `""`, `"beater"`; `roleOf` default
`"hunter"`; `setRole` then `roleOf`; `clearRole` back to the default;
`Body.teamForWord("beater") == "Drivers"` and `("hunter") == "Shooters"`, `teamForWord("x") == nil`.

### Client spec — `tests/client/outfit_client.spec.luau` (extend)

The client is where Karen looks, so what it asserts is what **reached** it: every outfit part still
`CanQuery == false`; every teamed character's `BodyColors` torso/arm/leg colours equal the base and
its head colour does not; no `Shirt`, `Pants` or `ShirtGraphic` on a dressed character; part count
per team; the flag-off branch still asserts zero. `TestKit.note` carries the numbers.

### Harness input and screenshots

* **The harness cannot drive the chat command.** `tests/client/input_scenarios.txt` expresses keys,
  mouse buttons, mouse moves and gaps — no text entry (TASKS.md Tasks 6–7; the format is in
  `tools/studio_mcp.py`'s docstring). So the chat path is proved by (a) the **pure parser** in a spec
  and (b) **one console line** from the Forest Test place, pasted into the request. A trigger nobody
  saw fire is not evidence.
* **Rule 5, and it needs a real avatar.** A spec rig is bare parts with no Humanoid, so a rig
  screenshot says nothing about `BodyColors`. The frames owed are: a **Play session in the DEV
  place**, the single player dressed by the drive — one frame **front** and one **back**
  (`python tools/studio_mcp.py capture <name> [camera] [look-at]`), inspected by the Builder, showing
  green torso/arms/legs, the player's own head colour, no shirt, the orange hat, and the vest if the
  roster made them a driver.
* **The honest gap:** no tool can set a live player's team mid-session, so the Builder can only
  screenshot the role the drive happened to assign. **The other role is Karen's**, in the Forest Test
  with `/beater` — which is exactly what §9 exists for. The report must say which role it
  photographed and which one it did not.
* **Karen's alone:** "it reads as a beater", and whether RGB(86, 80, 56) looks like her sleeve. One
  line to change if it does not.

---

## 16. Later, not in this task

1. **The horn — Task 152.** One sentence, as the brief allows: the horn is **carried, not worn**, so
   its owner is `ServerScriptService.Weapon` (`src/server/Weapon/Hardware.luau` already builds parts
   onto a Tool and grants it), never `Match.Body`. Worn is Body's; carried is Weapon's. Research is
   note §5, including the measured fact that free Creator Store horn **models** refuse to load
   (`"User is not authorized to access Asset."`) while the sound `rbxassetid://9038902877` is public.
2. The compass pointing a beater at the hunters' line.
3. The beater line and the countdown, money per drive, the weapon licence, spooking with a weapon.
4. Buying the 50 R$ catalog vest (99269365249885) — Karen's call; note §4.2 is the measurement.
5. A classic `Shirt`/`Pants` upload, which would match exactly and needs an upload OK.
6. Retiring the `ORANGE_OUTFITS` row and archiving the undressed branch (TASKS.md row 82b).

---

## 17. Open decisions — none of them blocks building

**Karen (feel):**

1. Does `RGB(86, 80, 56)` read as her sleeve on screen? One line in `Body.BASE_COLOR` if not.
2. Does the beater read as a beater (hat + four plates + green), front, back and from a post 40–80 m
   away?
3. Her doc says both roles wear **green** trousers; the field sources say a beater's trousers should
   be orange. **Her doc wins** (note §2) — log only, recorded so nobody "fixes" it.
4. Buy the 50 R$ hi-vis vest? Her money, her call (§16 item 4).

**Director (scope):**

5. Rename `"Drivers"`/`"Shooters"` to `"Beaters"`/`"Hunters"`? It touches `Match.Roster`,
   `tests/client/Role.luau`, the Hud badge, `Body.TEAM_COLORS` and a dozen specs, so it is its own
   task. Until then `Body.ROLE_WORDS` is the one translator.
6. Should a Forest Test "beater" actually **push** boars (`kind = "driver"` in
   `ForestTest.boarThreats`)? That changes what the waves do and what `PACE.DRIVER_RUN_STUDS` sees —
   a boar/drive task, deliberately not this one (§9).

Everything the build needs is fixed above: the colour, the composition, the interface, the call
sites, the predicate, the counters, the owners, the numbers, the specs and the gate.
