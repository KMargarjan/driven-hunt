# The inside of the lodge: nothing hanging, a seller you can reach, a counter you cannot climb

2026-10-16, task 195. Written before the code, per CLAUDE.md rule 1.

Karen, 2026-10-15 ~17:40, verbatim (via the Director, outside the repo):

> then you need to fix inside the cabin / it's broken there / you need to make nice inside and
> person not hanging and all things not hanging clean perfect doors can be open no doors, inside
> one bot as a seller access with e and you can't go over the table

and her choice of base, the same message: **use the 187 European lodge**.

---

## 1. What the system must do

1. **Nothing hangs.** Every object inside the lodge rests on the floor, is flush against a wall, or
   hangs from the ceiling or a beam -- and that is a *measured* statement, not a built intention.
2. **The seller's feet are on the floorboards.** Not 0.19 studs under them and not above them.
3. **The doorway is a walk-through gap**, at least 6 studs wide, with nothing standing in it and
   nothing standing loose in the room near it.
4. **One seller bot behind the counter**, idle, facing the room, with the `ProximityPrompt` task 181
   already built (`Shop` / `Press E`, keyboard **E**, gamepad **X**, touch button) -- and the prompt
   still reaches a customer **across** the counter.
5. **A player cannot get behind the counter**: not by walking round either end and not by jumping
   over it. The seller stays reachable by the prompt.
6. **It looks like a room somebody keeps**: even trophy rows, a rug, warm light, the gun rack.
7. Everything 187 and 178/181/182 already do keeps working, and the part budget (1,500 for the whole
   lobby; 885 measured at 187) is not blown.

### What it must not do

* Put a Script, LocalScript or ModuleScript anywhere (CLAUDE.md; the harness fails on one).
* Add a mesh, a union, an upload or an `.rbxm`. Parts and Roblox materials only, as in 187.
* Break the prompt's line of sight. `KEEPER.PROMPT.REQUIRES_LINE_OF_SIGHT` is `true`, and a barrier
  a ray can see would put the shop behind a wall nobody can open.
* Stop a pellet **that could otherwise have hit something**. `Build`'s standing rule is *a slab that
  stops a pellet changes what the shot hit*, so everything cosmetic is `CanQuery = false` and
  `CanTouch = false`. Section 3.1 is where this intention met a measurement: a part that COLLIDES is
  always hit by a ray whatever `CanQuery` says, so a no-climb barrier cannot be made ray-invisible,
  and the two bullets above cannot both be satisfied by one part. What follows from that is in
  section 4.

## 2. What is actually wrong today -- MEASURED, in Karen's own place

Measured on 2026-10-16 in **Driven Hunt Forest Test** with the lobby built by `ForestTestBoot`
(`<runs-dir>/t195/dump.txt`, 220 interior parts dumped with their world boxes; the probes are
`<runs-dir>/t195/`). The floor's top is **152.048**, the room is 32.4 x 22.4 x 12.6 and its
centre is (2850, 152.048, -2904).

| # | What | Measured |
|---|---|---|
| 1 | **The door leaf stands INSIDE the room, in the air.** | `DoorLeaf` centre z **-2913.856**; the inner face of the south wall is **-2915.2**, so it is **1.34 studs inside the room**, and its bottom is **152.248** -- **0.2 studs above the floor**. It is `CanCollide = false`, so a player walks straight through a door hanging in mid-floor. This is the *"it's broken there"* and *"all things not hanging"* in one part. |
| 2 | **The shopkeeper's feet are under the floor.** | `LeftFoot` bottom **151.860** against a floor top of **152.048**: **0.188 studs sunk**. `KEEPER.ROOT_HEIGHT = 3` is a *guess at* an R15 rig's root height; the rig's measured `HipHeight` is **2.192**. |
| 3 | **The shopkeeper stands in the counter.** | He is `BEHIND_STUDS = 1.6` behind the counter's centre; the counter is 1.8 deep, so its back face is 0.9 away and his torso front is **0.2 studs** from it. The live dump caught his `RightLowerArm` **1.182 studs** inside `Counter`, his `RightHand` 0.980, and `UpperTorso` 0.350 inside `CounterTop`. It is not the clip alone: his measured **horizontal radius about his own root is 2.42 studs** (the hands' outer corners), and `faceKeeper` turns him on the spot, so the arms that are at his sides when he faces the room swing FORWARD the moment he turns to a customer standing off to one side. A 3.7-stud bay (`COUNTER_BACK` 4.6 less the counter's own 0.9) cannot hold a 2.42-stud radius. |
| 4 | **He reads as a head on a shelf.** | The counter top is **155.248**, 3.2 studs over the floor; his head centre is **156.635**. Only **1.4 studs** of a 5.5-stud man clears the counter, so from the customer side he is a floating head in a hat (`195-b-east.png`). |
| 5 | **Anyone can get behind the counter.** | The counter spans x **2851** to **2863**; the east inner wall is at **2866.2** and the west half of the room is open, so there is a **3.2-stud gap** at one end and seventeen studs at the other. Nothing blocks a jump either: the top is 3.55 studs up against a default `JumpHeight`. |
| 6 | **The shop sign floats off the wall.** | `ShopSign` back face **-2892.95** against an inner wall plane of **-2892.8**: **0.15 studs** of air. |
| 7 | **Two gun-rack pegs float off their board.** | `GunRackPeg3_1/2` start at x **2834.25**; the board's face is **2834.2**. 0.05 studs. |
| 8 | **The trophy rows are not rows.** | The east wall carries four at height 4.8 and **two** at 8.2 on different `along` values; the north wall's boar sits at 5 between two roe at 4.8. |

Nothing else floated. The same scan says the remaining cross-object overlaps are all *structural* and
correct -- the chimney breast through the ceiling boards (0.90), the fire logs in the firebox (0.75),
the stag plaque on the breast (0.36) and each lantern's rod into the boards (0.14) -- which is the
difference this task has to keep: **a thing that hangs on or in another thing is not a thing that
floats.**

## 3. Sources

1. **Roblox Creator Docs -- `BasePart`** (`CanCollide`, `CanQuery`, `CanTouch`):
   <https://create.roblox.com/docs/reference/engine/classes/BasePart>. Roblox's own reference,
   generated from `Roblox/creator-docs` (**CC BY 4.0**, actively maintained). It reads as though the
   three switches were **independent** -- a part that stops a body while being invisible to
   `Raycast` and to `Touched` -- which is exactly what a no-climb barrier in a game whose shots are
   raycasts would want. **Bad, and this is the most useful thing in this note: that is not what the
   engine does.**

   ### 3.1 MEASURED, because the page could not be taken at its word

   Four parts, one per combination, each with a ray fired straight at it, in Karen's own place on
   2026-10-16 (`<runs-dir>/t195/canquery.luau`, run on the CLIENT inside a live session):

   | `CanCollide` | `CanQuery` | read back | the ray |
   |---|---|---|---|
   | true | true | true | **HIT** |
   | true | **false** | **false** | **HIT** |
   | false | true | true | **HIT** |
   | false | false | false | passed through |

   **`CanQuery = false` is ignored while `CanCollide` is true.** The property is stored and reads
   back false; the spatial query hits the part anyway. So a part cannot both stop a body and be
   invisible to a ray, and the first design here -- a full-height invisible clip with the keeper's
   prompt behind it -- was measured in the same session with a ray from a customer's head to the
   keeper's head coming back **"blocked by CounterGuard"** at 1.5, 3 and 5 studs back from the
   till. The prompt's own `RequiresLineOfSight` test is that ray. What that costs and what was done
   about it is section 4.

   ### 3.2 A harness lesson, because it cost an hour and it will cost the next one too

   A `ProximityPrompt` is **not drawn when it is behind the camera**, and in this game the camera
   keeps its own yaw: `Character:PivotTo` turns the body and leaves the camera looking wherever it
   was. Every probe that placed the player at the till and then asked whether the prompt was shown
   answered **no** -- for an hour, through a parent change, a stand-off sweep and
   `RequiresLineOfSight = false` -- because the camera was still facing the door. The honest test
   walks the player up (`Humanoid:MoveTo`) and then asks the camera owner to look at it
   (`player:SetAttribute("DHLookAt", <point>)`, which `Camera.lookAt` watches). With that one line
   the prompt is drawn, `Triggered` fires and `ShopPanel` becomes visible. Recorded here because
   nothing in the repo said it, and because `PromptShown` is a poor detector too: it fires on the
   EDGE, so a prompt that was already shown reports nothing. Count the descendants of
   `PlayerGui.ProximityPrompts` instead.
2. **Valve Developer Community -- "Clip brush" / `tools/toolsplayerclip`**:
   <https://developer.valvesoftware.com/wiki/Clip_brush>. The canonical level-design pattern,
   twenty years old and still the standard: an **invisible brush that blocks players but not
   bullets, not NPCs and not line of sight**, placed to keep a player out of a space the geometry
   does not itself close. **CC BY-NC-SA 3.0**, wiki, actively maintained. **Good:** it is exactly
   this problem, already solved, and it names the failure this task must avoid -- *players bumping
   into nothing* -- by keeping the clip **flush with visible geometry** so the invisible surface
   always coincides with something the eye can see. **Bad:** it is a BSP-compiler concept; the
   translation to a Roblox `Part` is ours, and Source's clip brushes are decided by a texture, so
   there is nothing to copy literally.
3. **Roblox Creator Docs -- `ProximityPrompt`** (`RequiresLineOfSight`, `MaxActivationDistance`):
   <https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt>. Same licence and
   maintenance as (1). It is why the barrier may not be queryable, and why the prompt hangs on an
   attachment at head height rather than on the root (task 181 measured that the counter itself
   blocks a root-height ray). **Bad:** it does not document which collision group or query flag the
   visibility test respects, so the combination here is measured, not assumed.
4. **Roblox Creator Docs -- `Humanoid.HipHeight` and `Model:GetBoundingBox()`**:
   <https://create.roblox.com/docs/reference/engine/classes/Model#GetBoundingBox> and
   <https://create.roblox.com/docs/reference/engine/classes/Humanoid#HipHeight>. The two ways to
   answer *"where are this rig's feet"*. `HipHeight` is the engine's own distance from the root to
   the ground **for a rig the Humanoid is driving**; this keeper's state machine is switched off
   (`EvaluateStateMachine = false`, task 181) -- but the property is still populated by the rig, and
   it is the ONLY one of the two that an animation cannot move. **Measured here**, because the page
   does not say which end of the root part it is measured from: HipHeight **2.192**, root
   half-height 1, soles **3.188** below the root's centre -- so it is the root part's BOTTOM, and
   the build reads it that way. The measured bottom is kept only as a one-way guard. **Bad:**
   `GetBoundingBox` includes accessories, so a hat would lift a naive top-based calculation -- the
   bottom is unaffected, which is why only the bottom is used.
5. **theHunter: Call of the Wild / the genre's outfitter huts** -- a negative source, looked at
   rather than quoted: every hunting-game vendor hut puts the keeper **behind a waist-high counter
   with a solid back wall**, not behind a chest-high one in an open room. It is where the
   "counter too tall, room not closed" pair in section 2 comes from. No licence; not code.

## 4. The pattern adopted, and why

**Borrowed (rule 2), from source 2:** the counter is closed with **visible geometry first and an
invisible clip only where a body could pass over it**.

* A **counter wing** (east end to the east wall) and a **counter return** (west end to the north
  wall), both ordinary `FURNITURE_COLOR` timber at counter height, built by the same `part()` helper
  as the counter. They close the two ways round, and they are *seen*, so nobody walks into nothing.
* A **clip** above them -- `Transparency = 1`, `CanCollide = true`, `CanQuery = false`,
  `CanTouch = false`, `CastShadow = false` -- from the SOLID counter's top to the ceiling, flush
  with the counter's customer face and with the return's west face. That is Valve's rule applied:
  the invisible surface lies exactly on a visible edge, so a player who bumps it is touching a
  counter. (`CanQuery = false` is set and is honest about its intent even though section 3.1 shows
  the engine ignores it on a colliding part; `CanTouch = false` and `CastShadow = false` do work.)
  It starts at the SOLID counter's top and not at the cosmetic slab's, because nothing cosmetic in
  this lodge collides and a clip starting 0.35 studs higher would leave a band with no solid in it.
* **The prompt moves to the counter.** Section 3.1 says a barrier and a sight line through it cannot
  both exist, so the prompt goes on the CUSTOMER'S side of the barrier: an attachment on the counter
  part, `PROMPT_OVER_STUDS` (1.2) above the till's top and `PROMPT_OUT_STUDS` (0.45) in front of its
  face, clear of the clip's own 0.4-stud slab, with the keeper standing directly behind it. It is
  still built only when a keeper was built, `RequiresLineOfSight` stays `true`, and
  `Lobby.shopPrompt` finds it by NAME anywhere under `Workspace.Lobby`, so no reader changed. It is
  still *"a person bot who you need to click E"*: the man is what you walk up to.
* **`MAX_DISTANCE` stays the Director's 8**, and now means more floor rather than less: measured
  from the counter it is 8 studs of standing room in front of the till, against the 5.5 that 8
  studs to a keeper 1.6 behind it used to leave.
* **Nothing is enlarged to make the barrier work.** `Shop.CONFIG.REACH_STUDS` (14) is measured
  against the counter's 12-stud width and is untouched.

**Measured, not guessed (rule: a number is not a verification, but a guess is worse):**

* The keeper is seated by **`Humanoid.HipHeight`**, the engine's own distance from the root part's
  bottom to the ground, so his root's centre goes at `floorY + HipHeight + rootHalfHeight`.
  Measured: HipHeight **2.192** on a 2-stud root is 3.192 against the 3 that `ROOT_HEIGHT` guesses.
  `ROOT_HEIGHT` becomes the fallback for a body with no HipHeight at all.
  **The first attempt measured his lowest part instead, and it was wrong in a way worth recording:**
  seated that way he stood exactly on the boards at build and then sank **0.174 studs** the moment
  the idle clip started, because a clip moves the legs and a pose is not a property of the rig. A
  measured guard is kept, but it may only ever LIFT him -- the pose it reads is an upper bound on
  his soles and never the final word.
* The bay is made big enough for the man instead of the man squeezed into the bay: `COUNTER_BACK`
  4.6 -> **6.4** (a 5.5-stud bay) and `BEHIND_STUDS` 1.6 -> **3.5**, which stands him in the middle
  of it with **2.6** studs in front and **2.9** behind -- both more than his measured 2.42-stud
  radius, whichever way he turns.
* The counter drops from 3.2 to **2.8** (top 3.15), so a standing man shows head **and chest** over
  it instead of a head alone. Both numbers are in `Lobby.CONFIG`, as 187 requires.

**Invented, and the reason written down (rule 2):** the support test itself. There is no Roblox or
third-party "does this part rest on anything" check to borrow; it is six floating-point comparisons
on the part's own box, and it is written as a **spec case**, not as runtime code, so it costs the
game nothing.

**Rejected:**

* *Fixing the door leaf's swing instead of deleting it.* The sign error is one character
  (`CFrame.new(spec.WIDTH/2, 0, 0)` should be negative), but corrected it puts a 7 x 8.6 slab
  standing at 100 degrees **in the middle of the porch**, which a player still walks through; and a
  leaf laid flat on the wall covers a front window at either jamb (the windows are at `along` +/-11,
  the leaf is 7 wide hinged 4.05 from centre). Karen's sentence offers the way out -- *"doors can be
  open no doors"* -- so the leaf and its bands go, and the jambs, lintel and threshold stay as a
  framed opening. Archived under `backups/` with this reason (rule 7).
* *A collision group for the barrier.* `PhysicsService` groups are a second, place-wide registry of
  who collides with what, and this game has none; `CanQuery = false` answers the whole question.
* *Making the keeper non-collidable so a player can walk through him.* He already is, except that
  the engine leaves `UpperTorso`/`LowerTorso` collidable on a rig it re-dresses (measured: both read
  `true` in the live dump). The barrier means it no longer matters where he stands.

## 5. The numeric targets

| Thing | Target |
|---|---|
| Every interior part | supported: bottom within **0.05** studs of the floor top, **or** its box reaches a wall plane / the ceiling, **or** it touches another interior part. No part floats alone. |
| The seller's feet | lowest body part's bottom within **0.05** studs of the floor top, with the idle clip running |
| The seller vs the counter | **>= 2.42** studs (his own measured horizontal radius) of clear air between his root and the counter's back face AND between his root and the north wall |
| The prompt's reach | a customer standing **5 studs** out from the counter's customer face is inside `MAX_DISTANCE` |
| Furniture vs furniture | no two of {table, each bench, counter + top + wing + return, rug, gun rack, seller} overlap by more than **0.05** studs on all three axes |
| The doorway | clear gap **>= 6** studs wide (7), nothing solid in the opening, no `Door*` part inside the room |
| Behind the counter | **unreachable**: no gap at either end below the clip, and the clip reaches the ceiling |
| The prompt | with the barrier up: drawn, `Triggered` fires and `ShopPanel` is visible after a walk-up and one key press |
| The shop sign, the rack pegs | flush: 0 studs of air |
| Trophy rows | every mount hangs at one of exactly **two** heights (`TROPHIES.HEIGHT_STUDS` 4.8 and `TROPHIES.UPPER_STUDS` 8.2), and where a wall carries both rows they use the **same** `along` values |
| Part budget | whole lobby <= **1500** (885 before this task) |

## 6. What this note does not decide

* Whether Karen likes it. She judges the look in the morning; every claim above is a measurement.
* Whether the lodge should have a door leaf at all in the end. If she wants one, it is a porch-side
  model with the windows moved, which is a task and not a line.
