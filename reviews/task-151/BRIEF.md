# Task 151 — design brief for the ARCHITECT: the beater kit (the OUTFIT)

Written by the Builder, carrying the Director (2026-10-11). This brief is the input to
`tools/architect.sh design beater-kit --task 151` and **overrides anything older** in `docs/`,
`TASKS.md` and any existing design where they disagree (`docs/ARCHITECT_PROMPT.md`).

Read first: **`docs/research/2026-10-11-beater-kit.md`** — the sources, the measured colour, and the
measurement that shuts the catalog route. The design is a **delta** to
`docs/design/map-generator.md` section 10 (the outfits) and `docs/design/drive.md` (where `Match.Body`
is the owner of what a character wears).

## 0. The scope cut — read this before anything else

The Director cut Task 151 to **the OUTFIT only, both roles**, plus the minimum needed to **see** a
beater in the Forest Test. **The HORN IS TASK 152** and must not be designed into this task's build;
the compass is later still. Research for the horn is already in section 5 of the note, so 152 starts
fast. If the design wants to say where the horn will hang, one sentence naming the owner is welcome —
no interfaces, no data, no tool.

## 1. The decisions, already taken — do not re-open them

1. **ONE OUTFIT SYSTEM FOR BOTH ROLES**, from Karen's design doc "Driven Hunt v1": base = **green
   jacket + green trousers for everyone**; **HUNTER** adds an orange hat; **BEATER** adds an orange
   hat **and** an orange vest. This supersedes "do not change hunters now": hunters are dressed too.
2. **THE BASE COLOUR IS `Color3.fromRGB(86, 80, 56)`** — measured off both glove models' own
   `texture_baseColor.png` olive cuff pixels (note section 3), not sampled from a lit frame. Exact
   match is the requirement: Karen, 2026-10-10 ~22:00, *"we need same color by default what is our
   arms not gloves but arms green or whatever color is so all clothe is that color"*.
3. **THE GREEN CLOTHING IS `BodyColors`, WRITTEN DIRECTLY — NOT `Humanoid:ApplyDescription`**
   (note section 4.1). `ApplyDescription` rebuilds the character's parts, and `Match.Body` is the
   module that welds plates to `UpperTorso` and anchors a punished player's root to a tree. Torso,
   both arms and both legs take the colour; **the head keeps the player's own colour**.
4. **THE PLAYER'S OWN `Shirt`, `Pants`, `ShirtGraphic` AND LAYERED CLOTHING ARE CLEARED** with it,
   because a mesh standing off the limb hides any colour written to the limb. **Hair and head
   accessories are left alone** (the hat was designed to clear a default avatar's hair in Task 77).
5. **THE ORANGE HAT AND THE ORANGE VEST STAY THE PARTS THE REPO ALREADY BUILDS** — `Match.Body`'s
   `OUTFITS` table, the two-part hat and the four-plate wrap, unchanged in geometry. This is the
   dispatch's own fallback promoted to the lead, because the dispatched catalog route is **measured
   shut** (note section 4.2): "High Vis Vest Orange" (99269365249885) is **50 R$ and
   `IsPublicDomain: false`**, both candidate hunting hats are paid and one is red, and a free-pool
   `SearchCatalog` over six keywords contains no blaze-orange hi-vis vest and no orange hunting cap.
   **No upload, no Robux, no new asset id in this task.**
6. **`Match.Body` REMAINS THE ONE WRITER** of what a character wears (rule 3). The base colour and
   the stripping are more of the same job at the same moment, from the same owner.
7. **THE FLAG IS THE EXISTING `ORANGE_OUTFITS`**, which is already `default = true` and already
   accepted by Karen. No new flag: this task changes what the ON branch *is*, and the OFF branch must
   stay "nobody is dressed, and nobody's own clothes are touched".
8. **KAREN MUST BE ABLE TO SEE A BEATER IN THE FOREST TEST**, which has no beaters (its drivers are
   phantoms with nobody standing on them) and no `Teams` at all. The Builder's lead: `ForestTestBoot`
   dresses the player as a **hunter** on spawn, and a **server-side chat command** switches the
   character between hunter and beater on the spot, so the whole thing is server-only, adds no input
   owner and does not touch the camera or the client. The Architect may replace this with something
   better; it must stay server-only and must not create a second writer of appearance.
9. **Not in this task** (note section 7): the horn, the compass, the beater line and countdown, money,
   the weapon licence, spooking with a weapon. Name them in the design's "later" list if useful.

## 2. What the design must contain

1. **Owners (rule 3).** State explicitly that `Match.Body` is the single writer of: the base clothing
   colour, the removal of the player's own clothing, the hat, the vest, and the outfit folder. Name
   who may ask it to dress somebody (`Match`, and in the playtest world `ForestTestBoot`) and state
   that nothing else writes `BodyColors`, `Shirt`, `Pants` or the character's accessories — including
   the client, which could not be screenshotted from the server anyway.
2. **The row shape.** Today `OUTFITS` is keyed by team name and holds only part rows. The design must
   say how a **base** (a colour plus "clear these classes") composes with the **per-role** part rows,
   so that "beater = base + hat + vest" and "hunter = base + hat" are each one statement and the hat
   is declared once rather than twice. `Body.dressFor(team, config)` stays **pure** and must remain
   drivable by a spec with the flag at either value, as it is today.
3. **Idempotence and the respawn path.** `Body.dress` already destroys and rebuilds the outfit folder
   so a team swap is a re-dress rather than two hats. A `BodyColors` write is **not** inside that
   folder: say what happens to it on a team swap, on a respawn, and with the flag off, and say what
   "undress" means for a colour that has overwritten the player's own (the honest answer is that the
   next respawn restores it, and the design should say so rather than invent a backup).
4. **What counts as "layered clothing"** for the stripping rule, as a predicate a spec can drive, not
   a list of ids: the note's reading of Roblox's appearance page is `WrapTarget`/`WrapLayer`-carrying
   accessories. Say which accessory kinds are deliberately spared (hair, hats, face).
5. **R6 and R15.** `BodyColors` has one property per R6 limb and the engine maps them onto R15 parts.
   The existing vest rows already carry `fallbackLimb` for R6. Say what the base colour does on each
   rig, and whether a missing limb is a counted miss (as a missing limb is today) or nothing at all.
6. **The Forest Test seam** (section 1.8). Name the owner of "which role am I playing in the playtest
   world", where it lives, and how it cannot leak into the real match: `MatchBoot` stands aside in that
   world and `ForestTestBoot` returns immediately in every other.
7. **The penalty interaction.** `Match.Penalty` ties a player to a tree and `Match.init` re-dresses
   them tied or not (Task 82). Confirm the order is still "dress, then tie", and that a `BodyColors`
   write cannot disturb the tie.
8. **What a spec can assert, and what only a screenshot can.** The colour, the cleared classes, the
   part count per role and `CanQuery = false` on every worn part are assertable. "It reads as a beater"
   is Karen's, through the preview frames this task owes her.

## 3. What the design must NOT do

* Do not introduce a second writer of appearance, and do not move the outfit to the client.
* Do not require an upload, a Robux purchase or a new asset id.
* Do not design the horn, the compass, the beater line, the countdown or the economy.
* Do not add a new feature flag.
