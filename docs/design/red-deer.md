# Red deer: stag, hind and calf in the drive

Task 223. Architect design, written to `reviews/task-223/BRIEF.md` (Director's dispatch of
2026-10-20), which overrides anything older in `docs/`, `TASKS.md` and `GAME_DESIGN.md`.

Normative for: the red deer's data, its owner, the species seam, the spawn mix, the clip set, the
prices, the licence flip, the screens and the tool. Not normative for: what a boar does (that is
`docs/design/boar-ai.md` and `docs/design/drive.md`), the fire gate (`docs/design/shotgun.md`
section 6.4 and `docs/research/2026-10-13-the-rules.md`), or the catalogue's layout
(`docs/design/shop.md`, `docs/design/economy-v1.md`).

The Builder's research note for this task is `docs/research/2026-10-20-red-deer.md`, added to
`docs/research/INDEX.md` (rule 1). Section 15 below is that note's source block; the note carries it
plus the prep run's measurements.

---

## 1. What the system must do, and what it must not do

### 1.1 Must

1. Put three red deer — **stag, hind, calf** — into the drive, released by the boar runtime's own
   release machinery, at `DEER.CHANCE_PER_RELEASE` (§4).
2. Publish `Species = "reddeer"` on every deer trunk, so the fire gate that has existed since task
   171 (`Weapon.Rules.unlicensed`, rule 3 of `Rules.ORDER`) refuses a shot at one from a player who
   holds no card, and allows it from one who does. **No new gate.**
3. Put the three prices in the one table that prices a kill: `Match.CONFIG.POINTS.KIND` —
   `stag = 20`, `hind = 6`, `calf = -10` (D-4).
4. Turn the catalogue's existing **RED STAG CARD** into a **DEER LICENCE** covering all three kinds,
   and put it on sale (D-1, D-2), with the keys `licence = "reddeer"` and `licence.reddeer`
   unchanged.
5. Draw a deer where a deer is: its own skinned model per kind, its own hit-zone boxes, its own
   trunk size, its own clip table and its own animation ids — never the boar's.
6. Count a deer kill on the drive report and draw it on the hit card, with no column that reads
   `MALE 0 FEM 0 CUB 0 KILLS 1`.

### 1.2 Must not

1. **Must not be a second animal system.** No second brain, no second body, no second wound, no
   second release loop, no new `Brain` state. D-5 and D-6; this design adopts the Builder's
   proposal, amended in §3.
2. **Must not rename `src/server/Boar`.** The rename to `src/server/Animal` is correct and it is a
   **LATER task** — see §11.1 for the list of names that go with it. A 10,000-line owner renamed
   inside this task buries the animal in a diff nobody can review.
3. **Must not invent a number it can measure.** Every clip length, every ground speed, every zone
   box and every baked length in this design is MEASURED (§6, §7) or is named here as a measurement
   the Builder must take before the commit. No fabricated animation asset id (D-8), no fabricated
   image id (D-7).
4. **Must not add a feature flag.** §10.
5. **Must not touch `TWO_PLAYER_PATHS` in `tools/agents.py`.** It does touch one file *in* that
   list, on purpose and unavoidably — see §13.4.

---

## 2. Owners (CLAUDE.md rule 3). One writer each, named

| What | The one writer | On disk | Changed by this task? |
|---|---|---|---|
| A deer's Instances (trunk, constraints, zone parts, visual, sounds) | `Boar.Body` | `src/server/Boar/Body.luau` | **No.** Not one line. It already builds whatever `config` and `geometry` say. |
| A deer's `Species` attribute | `Boar.Body.create` | `src/server/Boar/Body.luau` | **One line**: `row.species or "boar"` instead of the literal `Licences.ROWS.boar.species`. |
| A deer's geometry (trunk size, zones, scale, mesh scale, death lift) | `Boar.Body.kindGeometry` | `src/server/Boar/Body.luau` | **No.** It reads `config.ZONES` / `config.BODY_SIZE`; §3 hands it the deer's. |
| Which animal a kind is, and what it lives by | `Boar.CONFIG.KINDS` + `Boar.kindConfig` | `src/server/Boar/init.luau` | **Yes**: three rows, three `SPECIES` rows, one new pure function. |
| A deer's behaviour | `Boar.Brain` | `src/server/Boar/Brain.luau` | **No.** Not one line. The numbers arrive in `config` (§5). |
| A deer's wound and death | `Boar.Wound` | `src/server/Boar/Wound.luau` | **No.** No `toughness` row for any deer kind (§5.4). |
| Which animals a release is, and the deer draw | `Boar.sounderKinds` / `Boar.deerComposition` / `Runtime:spawnSounder` | `src/server/Boar/init.luau` | **Yes** (§4). |
| A deer's drawn model and clip ids, as a MAPPING between two owners | `BoarAssetsBoot` | `src/server/BoarAssetsBoot.server.luau` | **Yes**: three `MODEL_KEYS` rows, a per-species `CLIP_KEYS`, and the new `animationIdFor(species, name)` argument order (§6.3). |
| Every asset id | `Assets.ROWS` / `Assets.KEYS` | `src/serverstorage/Assets/init.luau` | **Yes**: 3 model rows, 11 declared animation keys with **no rows** (D-8), a `DEER_LICENCE` constant. |
| Which species needs a licence, and does one exist in this build | `Licences.ROWS` | `src/shared/Licences/init.luau` | **Yes**: `reddeer.shipped = true`, label. No function changes. |
| Whether a shot is refused | `Weapon.Rules` + `Weapon` (the owner that asks) | `src/server/Weapon/Rules.luau`, `src/server/Weapon/init.luau` | **No.** Not one line. Fully wired since task 221 (`MatchBoot` → `Weapon.setLicenceProvider`). |
| What a player holds | `Economy` (writes) + `Shop.licencesFor` (reads it into a set) | `src/server/Economy/`, `src/shared/Shop/init.luau` | **No.** |
| The catalogue | `Shop.ROWS` | `src/shared/Shop/init.luau` | **Yes**: the RED_STAG row's `label`, `blurb` and `sale`. The `id` does not move. |
| What a kill is worth | `Match.CONFIG.POINTS.KIND`, applied by `Match.Score.kill` | `src/server/Match/init.luau`, `src/server/Match/Score.luau` | **`init.luau` yes** (three rows, three `SCENE.ANIMAL_SCALES` rows). `Score.luau` **no** — `pointsForKind` already prices off `record.kind` and nothing else, so a negative row **is** the penalty (D-3). |
| The per-kind kill counts on the wire | `HitLog.Shape` | `src/server/HitLog/Shape.luau` | **Yes**: three `byKind` keys and three names in its `if`. |
| The wire's shape | `Report` types | `src/shared/Report/init.luau` | **Yes**: `DriveReport.byKind` grows three keys. |
| Which picture an animal gets | `Report.boarImage` | `src/shared/Report/init.luau` | **Yes**: three branches, two new `BOAR_IMAGE` rows, `CALF_SCALE`. |
| A data kind's player-facing noun | `Report.kindWord` | `src/shared/Report/init.luau` | **No.** "An unknown kind is returned as it came" already answers `stag`/`hind`/`calf` correctly. |
| The hit card's second label | `Report.trophyWord` | `src/shared/Report/init.luau` | **Yes**: one row, `stag` → `RED STAG` (§8.3). |
| The report board's columns | `ReportPanel.LIST_COLUMNS` + `listCellsFor` | `src/client/Hud/ReportPanel.luau` | **`listCellsFor` yes** (three folds, §8.2). `LIST_COLUMNS` **no** — no column moves, no pixel moves. |
| The start card | `Match.CONFIG.QUARRY` + `Drive.CONFIG.START_CARD_*` | `src/server/Match/init.luau`, `src/shared/Drive/init.luau` | **No.** §8.4. |
| The prep recipe | `tools/boar_prep.py` | `tools/boar_prep.py` | **Yes**: a `SPECIES` table (§9). |

**Nothing above has two writers, and nothing new is created.** The deer adds no owner. Every row in
the table is a module that already owns exactly that question for the boar.

---

## 3. The species seam. One sentence per file, and the answer to the brief's question

### 3.1 The brief's question: a `SPECIES` table, or a `species` string on the kind row?

**Both, and they are two different questions.** Stated plainly because getting this wrong is a
second table that drifts:

* **`species` is a STRING on the kind row**, defaulting to `"boar"`, because the question *"what
  species is this animal"* is answered per kind and is one word. It makes the smallest possible
  diff where it is read: `Body.create` already calls `Body.kindRow(kind, config)` one line above,
  so publishing the attribute is `row.species or "boar"` — and the `or "boar"` is what makes the
  four existing rows **unchanged in meaning** without editing one of them.
* **`Boar.CONFIG.SPECIES` is a TABLE of OVERRIDES**, keyed by that string, because the questions
  *"how big is this animal's trunk"*, *"where are its hit zones"* and *"what clips does it have"*
  are answered per species and are tables. A clip table on a kind row would be three copies of the
  deer's clips on three rows; a reverse lookup from a `SPECIES` table to "which species is this
  kind" would be a search.

So: the string is the KEY and the table is the DATA, and neither is the other's second copy.

### 3.2 The one new pure function, and it is the identity for every boar

```luau
-- `Boar.speciesConfig(species, config)` -> config
-- IDENTITY (`==` by reference) for nil, for "boar", and for any species with no SPECIES row.
-- A clone with BODY_SIZE, ZONES and MODEL replaced for a species that has one.
function Boar.speciesConfig(species: string?, config)
```

This is **exactly the shape `Boar.kindConfig` already has** (`src/server/Boar/init.luau`,
`Boar.kindConfig`: *"for every kind with no `wary` row it returns the config TABLE ITSELF and not a
copy, so for the male, the sow, the cub and the whole flag-off world this is the IDENTITY FUNCTION
and nothing can drift"*). That property is the whole reason this seam is safe, and a spec asserts
it by reference (§13.1 case 4).

`Boar.kindConfig` becomes the one door and composes the two:

```
kindConfig(kind, config):
    row     = Body.kindRow(kind, config)
    out     = Boar.speciesConfig(row and row.species, config)   -- the species' tables
    then    the existing `wary` scaling, applied to `out`        -- unchanged arithmetic
```

Every boar kind still gets `config` itself unless it has a `wary` row, which is the legendary and
nothing else. **Arithmetically untouched.**

### 3.3 `Boar.CONFIG.ZONES`, `BODY_SIZE` and `MODEL.CLIPS` STAY WHERE THEY ARE and ARE the boar's

Not moved under `SPECIES.boar`. Moving them would rewrite every reader and every spec for no gain,
and `report_silhouette.spec` asserts `Report.CONFIG.SILHOUETTE` against `Boar.CONFIG.ZONES` by that
exact path. `SPECIES.reddeer` carries only what differs:

```luau
Boar.CONFIG.SPECIES = {
    -- NO `boar` ROW, DELIBERATELY. `speciesConfig` is the identity for a species with no row, so
    -- the boar's tables are `Boar.CONFIG.ZONES`, `.BODY_SIZE` and `.MODEL` -- the ones every
    -- reader and every spec already names. A `boar` row here would be a second copy of them.
    reddeer = {
        BODY_SIZE = <measured, §7.2>,
        ZONES     = <measured, §7.3>,
        MODEL     = <table.clone(Boar.CONFIG.MODEL) with CLIPS, ANIMATION_IDS, TROT_FROM,
                     HIT_SECONDS (and MAX_RATE only if §7.4's sweep asks for it) replaced>,
    },
}
```

`MODEL` is a **clone with named overrides**, not a second MODEL table written out. There are
thirty-odd numbers in `Boar.CONFIG.MODEL` (`FADE_SECONDS`, `PADDLE_HZ`, `DISPLAY_ROLL_DEG`, …) and
every one of them is about *how a drawn animal is played*, not about which animal it is. Two copies
of thirty numbers is thirty chances to drift.

### 3.4 Which modules learn the word `species`, and which must not

**Learn it (five places, each one line or one lookup):**

| File / symbol | What it learns |
|---|---|
| `src/server/Boar/init.luau` — `Boar.CONFIG.KINDS.*` | each row carries `species`; three deer rows carry `"reddeer"` |
| `src/server/Boar/init.luau` — `Boar.CONFIG.SPECIES` | the override table |
| `src/server/Boar/init.luau` — `Boar.speciesConfig`, `Boar.kindConfig` | the lookup and the composition |
| `src/server/Boar/init.luau` — `Runtime:spawn`, `Runtime:displayCarcass`, `Runtime:step`, `Runtime:_modelTemplate` | which config an animal lives by (§3.5) |
| `src/server/Boar/Body.luau` — `Body.create` | `row.species or "boar"` on the attribute |
| `src/server/BoarAssetsBoot.server.luau` — `CLIP_KEYS`, `animationIdFor` | the clip key tables are per species (§6.3) |

**Must NOT learn it:**

* `Boar.Brain` — it reads numbers out of `config`. A `if species == "reddeer"` in the Brain is the
  second brain this design exists to refuse.
* `Boar.Wound` — the damage model owns *"the vitals are not armoured"* and nothing else.
* `Boar.Body` beyond that one line — every box it builds already comes from `geometry`.
* `Match`, `Match.Score`, `Match.Scene`, `HitLog`, `Report`, `ReportPanel`, `Drive` — they all key
  on **`kind`**, which is already a unique string across both species (`stag` is not `male`). They
  never need the species at all, and that is the property that keeps this diff small.
* `Weapon` and `Weapon.Rules` — they read one string off the thing they hit and look it up in
  `Licences.ROWS`. They have never known what a boar is and must not learn what a deer is.

### 3.5 The Runtime's four call sites (the whole of the behaviour change)

Today `Runtime:spawn` computes `geometry` from `self._config` and then `Brain.new(Boar.kindConfig(...))`.
The order inverts and the per-animal config is kept on the entry:

1. **`Runtime:spawn`** — compute `local animalConfig = Boar.kindConfig(kind, config)` FIRST, then
   `Body.kindGeometry(kind, animalConfig)`, then `Body.create(animalConfig, …)`, then
   `Brain.new(animalConfig, …)`, and store `entry.config = animalConfig`. For every boar kind
   without a `wary` row this is `config` itself, so every line is the line it was.
2. **`Runtime:step`** — `Body.attachVisual` and `Body.stepVisual` take `entry.config`, not
   `config`. This is the one change that makes a deer play deer clips, and it is two arguments.
3. **`Runtime:displayCarcass`** — takes `Boar.kindConfig(kind, self._config)` for both the geometry
   and `Body.displayCarcass`, so the stag laid out at the gathering is a stag.
4. **`Runtime:_modelTemplate`** — fills the **species'** `MODEL.ANIMATION_IDS` table, and asks the
   lookup with the species (§6.3).

**An already-spawned animal keeps the config it was born with**, which is the rule `Runtime:spawn`
already states for `self._field` and for `kindConfig`.

### 3.6 The bug this seam exists to prevent, said out loud

`Body.hasClip(name, config)` reads `config.MODEL.ANIMATION_IDS[name]`, and
`Body.clipFor` reads `config.MODEL.CLIPS[name]`. Both tables are keyed by the **semantic** clip name
(`idle`, `walk`, `hitFront`). If the deer shared the boar's `MODEL`, a deer would be handed the
**boar's published animation ids** — boar clips, measured for boar bone lengths, played on
`Arm_Deer`. The brief measured that the two rigs share most bone names (`thigh_b`, `head`,
`Spine_`) and differ on the neck (`neck_01`/`neck_02` against `Neck`), so the tracks would partly
apply: a deer walking with a boar's legs and a frozen neck. Nothing in the suite can see it —
`AnimationId` is a number and it would be set correctly. **`tests/server/deer.spec.luau` asserts the
two id tables are not the same table** (§13.1 case 6).

---

## 4. The spawn mix

### 4.1 Where the numbers are read, once

**In the BOAR's owner, not in `Match`.** Two reasons, and both are already written in this repo:

* *Who is in a release is the boar system's fact.* `src/server/ForestTest/init.luau` says so where
  it reads `Boar.CONFIG.SOUNDER.COMPOSITIONS`: *"who is in a flock is the boar system's fact"*. And
  `Match.applySpawnSounder` passes **no composition at all** — it asks for a position, a count and a
  spread, and the kinds are drawn inside `Runtime:spawnSounder` by `Boar.sounderKinds`.
* *`src/server/Match/` is on `TWO_PLAYER_PATHS`.* Putting the deer draw in `Phase.maybeRelease`
  would be the wrong owner **and** would be the wrong file (§13.4).

So one new pure function beside the three `legendary` ones, in `src/server/Boar/init.luau`:

```luau
-- WHICH DEER GROUP THIS RELEASE IS, or nil for "this release is boars" (task 223). Pure: one roll
-- for whether, one roll for which, a composition out -- so "one release in five" is a spec case and
-- not a probability a playtest has to measure. `roll` in [0,1), so CHANCE 0 and 1 are EXACT.
-- GATED ON `KINDS.ENABLED`, exactly as `Boar.wantsLegendary` is: with `BOAR_MODEL` off there are no
-- kinds, so there is no deer either, and NO NUMBER IS DRAWN -- the runtime's `Random` stream stays
-- bit-for-bit the one every existing spec was written against.
function Boar.deerComposition(roll: number, pick: number, config): { [string]: number }?
```

`Runtime:spawnSounder` consults it **only when the caller passed no `composition`** (so the Forest
Test's named waves are untouched), and the existing line
`if type(composition) == "table" then size = Boar.compositionSize(composition) end` then sizes the
release — one place that knows what a composition weighs, which is what that line already promises.

### 4.2 The numbers

```luau
Boar.CONFIG.SPECIES.reddeer.RELEASE = {
    CHANCE_PER_RELEASE = 0.2,          -- K's dial, D-9
    MAX_GROUPS_ALIVE   = 1,
    COMPOSITIONS = {
        { weight = 40, stags = 1 },                 -- a stag alone
        { weight = 40, hinds = 1, calves = 1 },     -- a hind with her calf
        { weight = 20, stags = 1, hinds = 2 },      -- a stag with hinds
    },
}
```

**Why these three and these weights.** Karen's and the Director's sentence is *"a stag alone or with
hinds, a hind with a calf"* (D-6), which is three shapes, and ADW's account of *Cervus elaphus*
(§15 source 1) is the same three: matriarchal groups of hinds with their calves, stags solitary or
in bachelor groups outside the rut, and a stag holding hinds in the rut. The weights are reasoned
from this game rather than from the animal:

* **A hind with a calf is 40 %** because it is the group that carries the **penalty** (D-3). A
  −10 row that a player meets once a session is a trap; one he meets most drives is a rule he
  learns. It must be as common as the stag.
* **A stag alone is 40 %** because it is the 20-point shot the 750-coin card was bought for, and
  because it is the one release that is never deferred (§4.3).
* **A stag with hinds is 20 %** because it is the biggest group (3 of the drive's 6 live animals)
  and the rarest real sight outside the rut.

**What that is, arithmetically**, so Karen turns one dial against a number and not a feeling. A
drive is `FIRST_RELEASE_SECONDS = 20` plus `RELEASE_INTERVAL_SECONDS = 90` over a 10-minute drive —
about **6 releases**:

| | |
|---|---|
| expected animals in a deer group | 0.4·1 + 0.4·2 + 0.2·3 = **1.8** |
| expected deer releases per drive | 0.2 · 6 = **1.2** |
| expected deer per drive | **2.16**, against `BOARS_PER_DRIVE = 6` boars |
| drives with no deer at all | 0.8⁶ = **26 %** |

So about **three drives in four** carry deer, and about a quarter of the animals in a drive are
deer. That is "rarer than boar" and it is not folklore. **It is one number, `CHANCE_PER_RELEASE`,
and it is Karen's to turn** (§16 item 2).

### 4.3 The cap, and it is structural rather than a count that could drift

`MAX_GROUPS_ALIVE = 1`, answered the way `Runtime:_legendaryAllowed` answers its cap: the Runtime
counts **its own live entries** whose kind's species is `"reddeer"` and refuses a second deer draw.
It is not a counter two code paths could disagree about — there is one list of live animals and it
is the answer.

**Two deer groups cannot be out at once** because a drive is 6 live animals and a deer group is up
to 3: two groups could be half the drive, and the animal Karen called rare would be the animal in
front of every shooter.

**...EXCEPT A PARTY OF ONE, SINCE TASK 253** (the Director's decision, 2026-10-24). The stag may be
released while the hind party is still on its feet, because he moves alone and one animal cannot be
half a drive -- `RELEASE.LONE_PARTY_EXTRA_GROUPS` raises the cap by one for a party whose own
composition weighs `LONE_PARTY_SIZE`. It was measured: the hinds held him over to the drive's next
silence and he came out 26 seconds late, against an arithmetic written for his slot. Hind + calf +
stag is 3 of the 6, which is the bound the paragraph above is really about.

**A deer release that does not fit is DEFERRED, not dropped,** and that needs no new code:
`Runtime:spawnSounder` already returns `{}` when `#self._boars + size > maxBoars`, and
`Match.applySpawnSounder` already treats an empty answer as `releasesDeferred` plus
`Phase.releaseFailed`, which retries on the next step (*"deferred, not dropped"*, design
section 6.3). The retry draws again, so a deferred 3-deer release usually becomes something that
fits. Worth stating because it is the one case where the deer costs the drive a tick: a `stags = 1,
hinds = 2` draw with 4 boars already alive defers.

---

## 5. The behaviour numbers. Multipliers on rows that already exist, and no new state

### 5.1 The mechanism is `wary`, unchanged

`Boar.kindConfig` already reads `row.wary = { noticeScale, runScale }` and scales exactly six
numbers with it: `DETECT_RADIUS`, `CALM_RADIUS`, `SENSE.NOTICE_MOVING`, `SENSE.NOTICE_STANDING`,
`SENSE.FLUSH_STUDS`, `SENSE.CALM_MARGIN` (notice) and `SPRINT_SPEED`, `PACE.RUN_SPEED` (run). **No
third field is added and no new `Brain` state is added.** The deer's whole behaviour is six numbers
times a constant.

### 5.2 The rows

```luau
stag = { …, wary = { noticeScale = 1.5, runScale = 1.18 } },
hind = { …, wary = { noticeScale = 1.8, runScale = 1.18 } },
calf = { …, wary = { noticeScale = 1.8, runScale = 1.18 } },
```

| | boar | legendary | stag | hind / calf |
|---|---|---|---|---|
| `DETECT_RADIUS` | 40 | 56 | **60** | **72** |
| `CALM_RADIUS` | 70 | 98 | **105** | **126** |
| `SENSE.NOTICE_STANDING` | 25 | 35 | **37.5** | **45** |
| `SENSE.NOTICE_MOVING` | 60 | 84 | **90** | **108** |
| `SENSE.FLUSH_STUDS` | 15 | 21 | **22.5** | **27** |
| `SPRINT_SPEED` | 38 | 42.6 | **44.8** | **44.8** |

### 5.3 Why each number, and what "breaks earlier" is

**`runScale = 1.18`, and it is the same for all three kinds.** This is the amendment to the
Builder's D-6 proposal and it is a correctness constraint, not taste: the Brain's follower matches
the leader's speed but `Brain:_runSpeed` answers **per animal**, so two kinds in one group with
different `runScale` drift apart, and `SOUNDER.BREAK_STUDS = 60` over `BREAK_SECONDS = 4` then
**dissolves the group**. A hind who outruns her own calf is not a hind with a calf. One species, one
`runScale`.

1.18 gives 44.8 studs/s = 12.5 m/s = **45 km/h**. A red deer really does about 65–70 km/h, which
would be ~66 studs/s (1.74×), and that figure is **refused on measured grounds**: the boar's 38 is
already 38 km/h against a real boar's ~40 (`Boar.CONFIG.SPRINT_SPEED`'s own comment), i.e. ~95 % of
the animal, so scaling the deer to the same fidelity gives an animal that (a) leaves a 400-stud
drive corridor in six seconds and (b) cannot be pushed at all by a `Humanoid` at `WalkSpeed` 16.
1.18 makes the deer the fastest thing in the drive by a sixth and still pushable. It is also just
above the legendary's 1.12, so it sits inside the envelope `boar_kinds.spec` already sweeps.
**Karen's dial** (§16 item 3).

**Only the RUN is scaled, not the walk or the trot**, and that is the trait rather than an
omission: `kindConfig` does not touch `TROT_SPEED` or `PACE.WALK_SPEED`, so a deer being crowded by
beaters moves off at the same pace a boar does and is a sixth faster **only once something
frightens it**. That is the whole of "deer are jumpier": they *break* sooner and *run* harder, they
do not *walk* faster.

**`noticeScale` differs between the stag and the hinds, and it may**, because notice is per-animal
and `Runtime:_stepAlarm` already spreads panic through a sounder member by member — so the
**jumpiest member is the group's trigger**, which is exactly what a hind with a calf is. The stag's
1.5 and the hinds' 1.8 therefore do not fight; they make the harem break on the hind's radius and
the lone stag break on his own.

**"How much earlier it breaks" IS `SENSE.NOTICE_MOVING`.** There is no separate break number to
add. A boar notices a walking man at 60 studs (17 m); a hind notices him at 108 (**30 m**). 30 m is
chosen against the corridor: the drive is ~400 studs (112 m) long, so a 100-m flight distance —
which is within the range the literature gives for undisturbed red deer — would mean every deer
left before a beater was in sight and no player ever saw one. **This is a negative result and it is
recorded as one** (§15.6): no source with a licence this design could cite gives a red deer's
flight distance from a walking person in a form this game can use, so the number is reasoned from
this game's own geometry — the precedent being `KINDS.LEGENDARY.CHANCE_PER_DRIVE`, whose own comment
records the genre's published rates as a negative result for the same reason.

### 5.4 Two rows the deer deliberately does NOT get

* **No `toughness`.** `Boar.toughnessFor` is the LEGENDARY's armour and its own derivation is about
  a mature boar's shield of gristle (`Boar.Wound`'s comment: *"at `toughness = 2` one chest slug
  still kills a legendary outright"*). A red deer is thin-skinned. Shooting one is **not** harder
  than shooting a boar, and if Karen wants a stag to carry a wound further that is a `toughness`
  row and one playtest (§16 item 4).
* **No new `SOUNDER` spacing.** `SEPARATION_STUDS = 7` and `COLUMN_SPACING_STUDS = 9` stay as they
  are for the deer, and this is deliberate. Scaling separation to the deer's body (7 → ~9.1) would
  put the push radius **outside** `FORMATION`'s own slot offset of 9 studs behind the leader, so
  cohesion would pull a member to a slot that separation pushes it out of — a flicker. Either both
  scale or neither does, and neither is the zero-diff choice: a deer group is 1–3 animals, they do
  not collide with each other (`Boar.CONFIG.BOAR_COLLISION` is registered not to collide with
  itself), and `FORMATION` slots 4 and 5 are unreachable at a cap of 3. The visible cost is that
  two hinds may stand nose-to-tail rather than a body length apart, which is what deer do. **Queued
  as Karen's feel item** (§16 item 5).

### 5.5 Two one-line rows that are not multipliers, and why they are here anyway

* **`MARCH_RANK`** (`src/server/Boar/init.luau`, above `Boar.marchOrder`) is
  `{ female = 1, cub = 2, male = 3 }` and falls back to **2** for an unknown kind — so a hind, her
  calf and a stag would all rank 2 and march in distance order. Three keys fix it with no new
  mechanism: `hind = 1, calf = 2, stag = 3`. The **rear guard** stays boar-only (it counts
  `kind == "female"` and needs two of them), which is right: a stag with hinds is not a nursery.
* **`SOUND.VOICE`** rows. `Body.voiceRow` returns nil for a kind with no row and no matching
  `model`, and `Body.voiceIds` then falls back to the generic spec's ids — **which are pig
  squeals**. A stag squealing like a sow is a defect Karen will hear in the first ten seconds. The
  existing mechanism answers it with one number per kind, which is what the legendary's row already
  is (*"It is his SAMPLES … pitched down: a new sample nobody has heard would be a second thing to
  judge"*):

  ```luau
  stag = { pitch = 0.55, death = { 9117361361 }, cry = { … }, grunt = { 9117357588, 9117352464 } },
  hind = { pitch = 0.90, … },
  calf = { pitch = 1.30, … },
  ```

  This corrects the brief's §7 list by exactly one item: **"no deer sound SET" stays, but the pitch
  rows land**, because the alternative is not silence (there is no way to silence a kind through
  this table) — it is a pig. A real deer cue set (roar, bark, bleat) is an id Karen must hear first
  and is §16 item 6.

---

## 6. The clips

### 6.1 One rig, one clip set, eleven clicks

The brief measured it: all three files carry `Arm_Deer`, 42 bones, identical names. So **one clip
set serves all three kinds** and the publishes are **1×, not 3×** — the same situation as `Arm_Boar`
(46 bones, male/female/cub). The authority for *why* that works is Roblox's own rigging and Animator
documentation (§15 source 3): bones are descendants of the MeshPart, and `Animator:LoadAnimation`
on the server replicates the track to every client.

### 6.2 The v1 clip list — eleven, named one by one

The package ships 77 (80 for the calf) and the names are **not** the boar's, so the clip list is
per species and cannot be a constant (the brief's measured fact 3). `Boar.CONFIG.SPECIES.reddeer.MODEL.CLIPS`:

| semantic name | package clip | what it is for |
|---|---|---|
| `idle` | `Idle_1` | standing; the fallback every missing clip falls back to |
| `walk` | `Walk_F_IP` | `WANDER_SPEED`, and the band `MODEL.WALK_FROM`…`TROT_FROM` |
| `trot` | `Trot_F_IP` | `TROT_SPEED` — being pushed, which is most of a drive |
| `run` | `Run_F_IP` | `SPRINT_SPEED · 1.18` — bolting |
| `turnLeft` | `Turn_L_IP` | a pivot below `WALK_FROM`, so a turning deer does not skate |
| `turnRight` | `Turn_R_IP` | the same |
| `deathLeft` | `Death_L` | it falls on the side `Body.collapse` rolls it onto |
| `deathRight` | `Death_R` | the other side |
| `hitFront` | `Hit_Front` | the flinch on the tick a pellet lands from in front |
| `hitBack` | `Hit_Back` | …and from behind (`handle.hitFromBehind`) |
| `smell` | `Idle_5` | `MODEL.ALERT_CLIP` — head up, the single most characteristic thing a deer does, and the one the ALERT state already asks for by name |

**Eleven publishes, and they are Karen's clicks** (D-8). `ESCALATE.md` gets a **`NEEDS KAREN 223`**
entry listing them in order, with the exact Studio path (Animation Editor → import the FBX the prep
wrote → Publish to Roblox → copy the id). An animation asset id can only be made by hand
(`Assets.KEYS`'s own block; `docs/research/2026-10-03-boar-skinned-model.md` source 1: *"It is
clicks, per clip. There is no API behind it"*). Until each one lands, `Assets.byKey` answers nil,
`Body.hasClip` is false, `trackFor` returns nil, and the deer **stands and slides** exactly as the
boar did between tasks 115 and 116 — which is honest, is tested, and is the precedent.

**`Hit_Middle` is not taken.** `Body.clipFor` chooses between exactly two flinches off
`hitFromBehind`; a third would need a new fact on the hit record and a branch in the one function
that chooses a clip. Queued, not smuggled in.

### 6.3 The calm repertoire is OUT of v1 — four clicks saved, and here is the trade

`grazeLoop` (`Eat_loop`), `grazeChew` (the deer has **one** `Eat_loop`, not the boar's two, so this
row cannot exist at all), `grazeStart`/`grazeEnd` (`EatDrink_start`/`_end`) and `digWalk`
(`Eat_walk_IP`) are **not published in v1**. The reasoning is the one the design is supposed to do:
every clip is a hand publish, and a grazing deer is only visible in the ~20 seconds between a
release and the beaters reaching it. `Body.activityClip` already resolves to a name whose
`hasClip` is false, so the animal plays `idle` and every behaviour is unchanged. **`smell` is the
exception and is in v1** because `MODEL.ALERT_CLIP = "smell"` is read by the alert state for every
species, and a deer standing head-up is what being noticed *looks like*.

### 6.4 `animationIdFor` grows a species, and the argument goes FIRST

`Boar.setModelSource(templateFor, animationIdFor)` and `Runtime:setModelSource` take
`animationIdFor(name) -> number?`. `idle` is now a clip name in **two** species, so the lookup must
be told which:

```luau
animationIdFor(species: string, name: string) -> number?
```

**Species first, deliberately.** A spec or a world that wires a stale one-argument fake
(`function(name) return ids[name] end`) then receives the species where it expected the name and
answers **nil** — which is "no clip", which is "the animal stands still", which is the safe, tested
state. With the species second, a stale fake would answer the **boar's** id for a deer clip, which
is §3.6's bug arriving through the test harness. The argument order is the guard.

`BoarAssetsBoot`'s `CLIP_KEYS` becomes `CLIP_KEYS[species][name]`, and **both of its assert loops
run per species** — a clip name in `MODEL.CLIPS` with no key, and a key with no clip, still fail at
boot rather than by not animating. That boot script's own history is the reason this matters: task
219's assert loop *"died at its own assert, so `setModelSource` was never called and NOT ONE BOAR IN
THE GAME WAS EVER DRESSED"*. The deer's three kinds and 11 clips go through the same two loops, and
`KINDS.ORDER` (not `pairs`) is still what they walk.

### 6.5 Preload: the deer gets its own scope

The three deer model rows carry `scope = "deer"`, and `BoarAssetsBoot` makes a **second**
`Loader.preload(Assets.keysFor("deer"))` call. One call for six skinned meshes would spend the
boar's own `Loader.CONFIG.PRELOAD_BUDGET_S` on the deer; two calls give each scope its budget, so a
slow deer load cannot cost a boar its coat. That is exactly what `AssetRow.scope`'s own comment says
the field is for (*"WHO NEEDS THIS ROW BEFORE A PLAYER CAN USE IT"*). A deer born before its
template lands is a grey box that puts its coat on within a second (`_modelTemplate`'s
`ASK_EVERY_SECONDS`) — *late is not lost*.

### 6.6 The three authored clips are OUT of v1, confirmed

`deathPaddleLeft`, `deathPaddleRight` and `crippleDrag` (task 116's synthesised clips) get **no deer
rows**. `Body.clipFor` then returns the fall and holds it, and a crippled deer plays its gait —
precisely the pre-task-116 behaviour, which is tested. The deer's species row in the tool carries
`synth = ()` and records the **one** bone-name difference the brief measured (`Neck` → `neck_01` /
`neck_02`) so the later task does not re-measure it.

---

## 7. The measurements. What is measured, and how

### 7.1 The lengths baked in

1 stud = 0.28 m (`Map.CONFIG`'s scale). Off the brief's measured bounding boxes, with **Y as
length**:

| | bbox Y (m) | baked length (studs) | `scale` (÷ stag) | triangles | ceiling |
|---|---|---|---|---|---|
| stag | 1.975 | **7.05** | 1.000 | 14,652 | 20,000 ✓ |
| hind | 1.689 | **6.03** | 0.855 | 12,342 | 20,000 ✓ |
| calf | 0.976 | **3.49** | 0.495 | 12,200 | 20,000 ✓ |

So `--length-studs 7.05 / 6.03 / 3.49`, `--texture-px 1024`. The stag's bbox Z of 2.219 m is
**antler height, not length** — the brief says so and it is the one number that would silently make
a stag 7.9 studs tall.

**`scale` is relative to the STAG, not to the boar male**, because the deer species carries its own
`BODY_SIZE` and `ZONES` (which are the stag's) and `kindGeometry` multiplies them by `row.scale`.
The hind's 0.855 falling within 0.0003 of the boar sow's 0.8553 is a coincidence and is worth a
comment so nobody later "simplifies" one into the other.

**`clipScale` is MEASURED, not assumed.** `tools/boar_prep.py` reports each animal's own
`groundStudsPerSecond` per clip; the boar's came out 0.8553 and 0.4372 against scales of 0.85 and
0.45, i.e. close to but not equal to the length ratio. The stag's is **1.0 by construction** (the
clip table is measured at his baked length); the hind's and calf's are whatever the prep run says.

### 7.2 `BODY_SIZE` — MEASURED, and it cannot be the boar's box scaled

The boar's `BODY_SIZE = (2, 3, 5.5)`. Uniformly scaled to the stag's length that is
(2.56, 3.85, 7.05): a trunk **0.72 m wide** where the animal is 0.97, and **1.08 m tall** where a
stag stands ~1.2 m at the withers. A deer is a leggier, narrower, taller animal than a boar and no
single multiplier makes the boar's box into its box.

**So it is measured off the loaded rig**, the same way and with the same method task 119 used for
the boar on 2026-10-04: in a Play session, read `Arm_Deer`'s own bones out of
`ServerStorage.AssetCache` through the harness, in mesh object space, then add the
`Body.visualOffset` Y that stands the feet on the box's bottom. The three numbers to take are the
withers height (the trunk's Y), the shoulder width (its X) and the brisket-to-rump length (its Z,
which must come out at the baked length). Written into
`Boar.CONFIG.SPECIES.reddeer.BODY_SIZE` as a measurement with the date, exactly as
`BOAR_MALE_SIZE` carries *"read in Studio off the loaded asset 120607820179994 on 2026-10-03"*.

### 7.3 `ZONES` — MEASURED, and this is the biggest single piece of work in the task

The boar's four zone boxes are **measured off the boar's drawn skull**: `head` is
`size (1.2, 1.3, 1.36)`, `offset (0, 1.0, -2.13)`, and its comment records the bones it was fitted
to (*"nose z −2.388 … the mesh's own front face z −2.750"*) plus the fault it fixed — *"until this
task it was a box hanging in the air 1.15 studs in FRONT of the snout … A shot at the animal's face
landed on the trunk and was charged to `body`"*.

**A red deer carries its head high on a long neck.** Scaling the boar's offsets by 1.282 puts the
stag's `head` box in empty air in front of its chest and reproduces that exact bug on a new animal.
So the deer's four boxes are measured off `Arm_Deer`'s own bones in the same probe as §7.2, under
the same three rules the boar's rows already state:

* the `-Z` front face **proud by `PROTRUSION`** (0.06 × `scale`), so a ray from the front meets the
  head and not the trunk;
* the `+Y` top **proud**, so a shot from above the skull is a head shot;
* `±X` **not** proud (a pure flank is `body`), and `head`/`chest` meeting at an **interior**
  boundary, because two coincident surfaces at one ray distance is a coin toss and not a hit zone
  (task 116, review round 2).

**The acceptance test is `boar_zones.spec`'s, not a number:** twelve real rays fired from outside at
each deer kind, each returning the zone the geometry says it should. That spec exists because *"zone
parts nested inside the trunk would never be hit: every shot would report `body`, and a spec that
called `takeHit` with zone = "head" directly would pass while no player could ever produce a head
shot."*

**Ordering.** §7.2 and §7.3 need the model uploaded and loaded, so the task's order is: prep (§9) →
upload (Karen's OK is on record) → `Assets.ROWS` → probe in a Play session → write the two tables →
specs. The zone numbers cannot be written before the probe and **must not be guessed**.

### 7.4 `MODEL` overrides, and the one rail that may have to move

The deer's `MODEL` clone overrides:

* `CLIPS` — §6.2, with `seconds` and `groundStudsPerSecond` **off the prep run**, and `seconds`
  re-read from the published asset with `AnimationClipProvider:GetAnimationClipAsync` (last
  keyframe's `Time`) once the ids exist. `BoarAssetsBoot` already warns when `row.clipSeconds` and
  `CLIPS[name].seconds` drift by more than half a frame at 24 fps, and that warning now covers the
  deer for free.
* `ANIMATION_IDS = {}` — its own table (§3.6).
* `TROT_FROM = CLIPS.walk.groundStudsPerSecond * WALK_MAX_RATE` — the **derivation**, not a literal,
  so the band edge follows the measurement.
* `HIT_SECONDS = CLIPS.hitFront.seconds`.
* `RUN_FROM` is **not** overridden: it is `(TROT_SPEED + SPRINT_SPEED) / 2` off the base speeds and
  has nothing to do with the clips.
* `MAX_RATE` **only if the sweep asks for it.** `Body.gaitBands` computes
  `maxRate = MODEL.MAX_RATE / math.min(clipScale, 1)`, so the stag gets the male's 2.8 and the calf
  gets 2.8 / 0.495 = 5.66. The worst ask is the trot clip at the top of its own band, which is
  scale-invariant — but the deer's `SPRINT_SPEED` is scaled by `runScale` while `RUN_FROM` is not,
  so the ask is `44.8 / (CLIPS.run.groundStudsPerSecond · clipScale)` and it is not knowable until
  the prep run reports that ground speed. **If the measured deer run clip cannot carry 44.8 studs/s
  at or below 2.8, the fix is the RAIL and not the speed** — `MAX_RATE`'s own derivation is *"the
  ceiling is above everything the game can ask for, so it never shapes how an animal moves"*. The
  deer's `MODEL` carries its own `MAX_RATE` in that case, and `boar_kinds.spec`'s sweep is what
  decides (§13.2).

### 7.5 `deathLiftStuds`

Measured per kind the way the boar's three were (0 / 0.205 / 1.009): at the frame `Body.stepVisual`
freezes the death at (`length − HOLD_EPSILON`), the lowest bone against the rig's own bottom plane.
It is only knowable **after** `Death_L`/`Death_R` have ids, so it is 0 for all three until the
publishes land and is then a three-number commit. Named here so it is a known follow-up and not a
carcass sunk into the ground that nobody can explain.

---

## 8. The screens

### 8.1 The silhouettes (D-7)

`Report.CONFIG.BOAR_IMAGE` gains two rows and one scale:

```luau
BOAR_IMAGE = {
    male   = { id = "rbxassetid://135789362198066", box = { … } },  -- unchanged
    female = { id = "rbxassetid://121961957713451", box = { … } },  -- unchanged
    stag   = { id = "rbxassetid://<IMAGE id>",      box = { <measured> } },  -- `male deer.jpg`
    hind   = { id = "rbxassetid://<IMAGE id>",      box = { <measured> } },  -- `famale deer.jpg`
},
CALF_SCALE = 0.70,
```

and `Report.boarImage` gains three branches: `stag` → the stag row, `hind` → the hind row, `calf` →
the **hind** row at `CALF_SCALE` — the `PIGLET_SCALE` pattern, said out loud, exactly as D-7 asks.

**`CALF_SCALE` is its own row and not `PIGLET_SCALE` reused**, although both are 0.70. They are two
independent drawn choices about two different animals (`PIGLET_SCALE`'s own comment: *"about what a
cub is beside its mother"*), and a change to the piglet's drawing must not silently move the calf's.

**Task 205's measured lesson is binding and it costs a whole round if it is forgotten.** An Open
Cloud PNG upload creates a **`Decal`** (`AssetTypeId 13`) and an `ImageLabel` **cannot draw a decal
id** — measured in Play on 2026-10-18, three labels on one plate, every one `IsLoaded = false` and
the plate EMPTY, *"which no spec could see — `Image` is a string and it was set correctly"*. So:

* the id written into `BOAR_IMAGE` is the **Image** id, resolved on the **server** with
  `InsertService:LoadAsset(decalId).Texture`;
* the **decal** id is what `assets/uploads.json` records, because that file records what was
  uploaded;
* and the acceptance evidence is a **screenshot of the hit card with the animal on it** plus a
  probe of `ImageLabel.IsLoaded`, not the string.

**`box` is MEASURED, not inherited.** It is where the dots' unit square sits on the PNG, and the
boar's was searched for rather than taken from the outline's extremes — the raw nose/rump/back/belly
put the head zone's centre **off** the animal (11 % of the head box's sample grid on black). The
deer's bar is task 205's own: **every zone's centre on the animal and ≥80 % of the worst zone's
sample grid** (the boar scored 82 %), and a box that scores 100 % by shrinking onto the torso is
refused for the reason already written there — *"a head shot and a rump shot both drew inside the
belly and the picture stopped meaning where the shot landed"*.

**`Report.CONFIG.SILHOUETTE` is NOT species-aware and does not change.** The dot's (u, v) comes from
`HitLog.Shape.dot`, which normalises by the **animal's own box**
(`u = (z + halfLength) / length, v = 0.5 − y / height`), so a hit on a stag's chest lands in the
right place on the deer picture with no new arithmetic at all. `SILHOUETTE` stays the boar's
projected `ZONES`, and `report_silhouette.spec` must name **`Boar.CONFIG.ZONES`** explicitly (which
§3.3 keeps as the boar's, by identity) so that a change to the deer's zones can neither break nor
satisfy it.

### 8.2 The drive report

* **`Report.DriveReport.byKind`** goes from five keys to eight: `male, female, cub, legendary, stag,
  hind, calf, unknown`. All keys always, as numbers — *"a dictionary with a hole does not survive
  the wire faithfully"*.
* **`HitLog.Shape`** seeds those eight and names the seven real kinds in its `if`. This is the fault
  task 219 shipped and fixed: *"`HitLog`'s `byKind` counted the trophy as an `unknown`"*, and
  `unknown` exists so a kind **typo** shows up as a number. A deer falling into it destroys that
  signal.
* **`ReportPanel.listCellsFor`** folds the three deer kinds into the three existing count columns:
  `male += stag`, `female += hind`, `cub += calf`. **No column moves and no pixel moves**, and
  `LIST_COLUMNS` is untouched. This is precisely task 219's decision and argument, applied: the
  column heads are **`MALE` / `FEM` / `CUB`** — sex and age words, not species words — so folding a
  stag into MALE is true, and the alternative is a player who shot a stag reading
  `MALE 0 FEM 0 CUB 0 KILLS 1`, *"which reads as broken"*. A column of its own is queued, not
  smuggled in.
* **The detail page's ANIMAL column needs nothing.** `Report.kindWord` returns an unknown kind **as
  it came**, so it prints `STAG`, `HIND`, `CALF`. The cell is 78 px and `LEGENDARY` measured 55.0 px
  in its own face already fits it, so four-letter words are safe by inspection of that measurement.

### 8.3 The hit card

`Report.trophyWord` gains one row: `stag` → **`RED STAG`**. One place, one decision, so the card
cannot say "stag" for a hind. The bound is measured and already recorded: `LEGENDARY BOAR` is
104.0 px in the label's own 164 px box, so an 8-character string fits with room.

`hind` and `calf` get **no** trophy word: `trophyWord`'s whole job is *"nil for every animal that is
not one"*, and a calf is a penalty.

### 8.4 The start card is NOT touched, and that is a decision

`Match.CONFIG.QUARRY` keeps its single `WILD BOAR` row and `Drive.CONFIG.START_CARD_QUARRY_WORDS`
gets no deer rows. `START_CARD_ROWS_MAX` is **4** with the Designer's reason on it (*"ONE IDEA PER
LINE, AND FOUR LINES IS THE CEILING for a three-second read"*), and the four are male, female,
piglet and the **person** row. A fifth row would silently push the person row — *"a tie to a tree is
a real rule the card never mentioned, and the beaters are walking toward the hunter while this card
is up"* — off a card of fixed height. **The deer is announced where there is room:** `RED STAG` on
the hit card's plate, `STAG`/`HIND`/`CALF` in the report's ANIMAL column, three counts on the wire,
and the shop's own blurb. A fifth start-card row or a merged one is the Designer's call and is
queued (§16 item 7).

This also means **`Match.quarryRows` is untouched**, which keeps `tests/server/match_config.spec`
and `match_live.spec`'s *"the snapshot's rows are `Match.quarryRows`"* assertions unchanged.

---

## 9. The tool: generalise, do not twin

The Builder's §3 proposal is **adopted as written**. `tools/boar_prep.py` already has the animal
dimension (`--animal`, `--clips`, `--length-studs`, `--texture-px`, `--albedo`), the copy-and-hash
guard and the ground-speed measurement; a deer twin would be a second copy of all of it, which is
rule 2 inverted.

```python
SPECIES = {
    "boar": {
        "animals": {...},            # today's `--animal` names
        "textures": {...},           # today's `texture_names` stems
        "clips": DEFAULT_CLIPS,      # BY IDENTITY -- the same tuple object
        "synth": SYNTH_CLIPS,        # BY IDENTITY
        "bones": {...},              # today's prefixes, incl. "Neck"
    },
    "reddeer": {
        "animals": {"stag": "Red_Deer", "hind": "RedDeer_Doe", "calf": "RedDeer_Calf"},
        "textures": {"stag": "Red_Deer", "hind": "RedDeerDoe", "calf": "RedDeerCalf"},
        "clips": DEER_CLIPS,         # the eleven of §6.2
        "synth": (),                 # §6.6
        "bones": {... "neck": ("neck_01", "neck_02") ...},   # the ONE difference, recorded
    },
}
```

Three hard requirements on the change:

1. **`boar` keeps today's values BY IDENTITY** — the same `DEFAULT_CLIPS` and `SYNTH_CLIPS` tuple
   objects, not retyped copies — so `selftest` can prove the boar's recipe did not move a
   character. `selftest`'s existing check is `sorted(set(wanted) - set(DEFAULT_CLIPS)) == []` **by
   name**, which is right and must stay: a bare count *"is the one thing about a list that does not
   say which list it is"*.
2. **`selftest` gains the same two name-based checks for the deer**, plus one new one: every clip in
   a species' `clips` must be in that species' own list and in no other's. The `--clips` validator's
   refusal message must name the SPECIES, because `"clip 'Hit_F' is not one of the 11 this game asks
   for"` is unreadable without it.
3. **The calf's embedded albedo is a `.tif`** and the separate texture folder's is a PNG (the
   brief's measured fact 4). The prep reads the folder, so this is a note on the row, not a code
   path — but `selftest` must assert the three deer texture stems by name, the way it already
   asserts `"Boar_Male_Albedo1.png"`.

**The file keeps its name this task.** `tools/animal_prep.py` is the right name and it goes with the
`src/server/Animal` rename (§11.1).

---

## 10. No feature flag, and the reason is stronger than D-10's

The Builder's D-10 reading reaches the right answer for an incomplete reason. The real reason:

**The deer is already behind `BOAR_MODEL`, and that flag's default is `false`.**
`Boar.CONFIG.KINDS.ENABLED = Flags.isOn("BOAR_MODEL")`, and with it off `Body.kindRow` returns the
`DEFAULT` male row for **any** kind handed to it and `Boar.sounderKinds` forces every named kind to
the default. So on a flag-off build a deer cannot be drawn, cannot be sized, cannot be spawned and
cannot publish `Species = "reddeer"`. There is nothing left for a `DEER` flag to switch.

Three further reasons:

1. A `DEER` flag would put a **third state** (flag off / card unowned / card owned) on a rule that
   has two, which is D-10's own argument.
2. `Flags.MAX_FLAGS` is **14** and there are 14 rows. A fifteenth is the **Director's** call
   (`docs/design/feature-flags.md` section 12, and `TASKS.md` row 215a already queues the cap for
   his word). Spending that on a path another flag already gates would be the worst possible use of
   it.
3. The rollback is a revert of data rows.

**Two consequences the Builder must honour, both one line each:**

* **`Boar.deerComposition` is gated on `config.KINDS.ENABLED`**, exactly as `Boar.wantsLegendary`
  is, and **no number is drawn** when it is off — otherwise `spawnSounder` would resize a release to
  a deer composition and then spawn three boar **males**, and the runtime's `Random` stream would
  stop being the one every existing spec was written against. That second half is why the gate goes
  *before* the roll and not after it.
* **Every deer spec drives `config` by parameter** with `KINDS.ENABLED = true`, the way
  `boar_kinds.spec` and `boar_legendary.spec` already do. The harness always runs with the flag at
  its default, because `test` and `test2` **refuse to start while any override is set** — so a spec
  that needed the flag on could never run in the gate at all.

**And the one thing this exposes, which belongs to the Director** (§16 item 1): with `BOAR_MODEL`
off, `Shop.ROWS[RED_STAG].sale = true` sells a 750-coin card for an animal that will never appear in
that build. Nothing in the harness catches it — `Shop.rowsOk`'s I3a reads
`Licences.ROWS.reddeer.shipped`, which is a literal. The flag **expires 2026-10-24**, and
`tests/server/flags.spec.luau` fails the harness on a past expiry, so the decision is forced within
four days whatever this task does. What the Builder ships, and the fallback, are written out in
§16 item 1.

---

## 11. What is NOT in v1, in writing

The brief's §7 list is confirmed with **one correction** (the voice pitch rows, §5.5):

| Not in v1 | Why, and where it is queued |
|---|---|
| The synthesised death-paddle and cripple-drag clips | §6.6. No deer row, `hasClip` false, pre-task-116 behaviour, which is tested. The tool's deer row records the bone-name difference for the later task. |
| Roaring / rutting | No `Brain` state, no clip, no rule. Karen has not asked. |
| Antler damage | Not a thing this game's wound model can express. |
| A deer sound **set** | §5.5 — the pitch rows land, the samples stay the boar's. §16 item 6. |
| A third silhouette image for the calf | `CALF_SCALE = 0.70` on the hind's drawing, honest about being the same picture (§8.1). |
| The grazing repertoire (4 clips) | §6.3, with the trade written out. `smell` IS in v1. |
| `Hit_Middle` | §6.2. |
| A `toughness` row | §5.4. |
| A fifth start-card row | §8.4. |
| A fourth count column on the report board | §8.2. |
| Deer-scaled group spacing | §5.4. |
| `deathLiftStuds` for the three kinds | §7.5 — 0 until the death clips have ids, then a three-number commit. |

### 11.1 The rename, and it is a LATER task

`src/server/Boar` → `src/server/Animal` is **correct** and must not happen in this task: a rename of
a 10,000-line owner inside this diff buries the deer where nobody can review it. The list, so the
later task is one task and not five:

`src/server/Boar/` → `src/server/Animal/` · `BoarAssetsBoot.server.luau` →
`AnimalAssetsBoot.server.luau` · `tools/boar_prep.py` → `tools/animal_prep.py` ·
`Report.boarImage` → `Report.animalImage` · `Report.CONFIG.BOAR_IMAGE` → `ANIMAL_IMAGE` ·
`Report.CONFIG.PIGLET_SCALE`/`CALF_SCALE` → one `YOUNG_SCALE` table ·
`Boar.CONFIG.BOAR_COLLISION` → `ANIMAL_COLLISION` · `Match.CONFIG.MAX_ALIVE_BOARS`,
`BOARS_PER_DRIVE` · `Runtime:boars()`, `world.boars` · `Workspace.Boars` (a world-facing name, so it
is a migration and not a rename) · `tools/studio_mcp.py`'s `BLAST_RADIUS` and `SCOPE_SPECS` `boar`
entries · the `boar_*.spec.luau` file names. **Queued for the Director.**

---

## 12. Numeric targets

| | target | source |
|---|---|---|
| deer meshes | 3, each ≤ 20,000 triangles (14,652 / 12,342 / 12,200) | measured, brief §2 |
| textures | 1024 px, albedo alpha dropped | `boar_prep.py`'s own default |
| baked lengths | 7.05 / 6.03 / 3.49 studs | measured, §7.1 |
| `scale` (÷ stag) | 1.000 / 0.855 / 0.495 | §7.1 |
| `SCENE.ANIMAL_SCALES` (÷ boar male 5.5) | 1.28 / 1.10 / 0.63 | §7.1, and **asserted** (§13.1 case 12) |
| animation publishes | **11**, by hand, Karen's clicks | §6.2 |
| deer release chance | 0.2 per release | D-9 |
| deer groups alive | ≤ 1 | §4.3 |
| deer group size | 1–3, inside `MAX_ALIVE_BOARS = 6` | §4.2 |
| expected deer per drive | 2.16 against 6 boars; 26 % of drives carry none | §4.2 |
| points | stag 20, hind 6, calf −10 | D-4 |
| coins at `COINS_PER_POINT = 2` | 40 / 12 / −20 | D-4 |
| the card | 750 coins ≈ 19 stags, `hunts = 0` | D-4 |
| notice × | stag 1.5, hind/calf 1.8 → a hind notices a walking man at **108 studs (30 m)** | §5.2 |
| run × | 1.18, all three → `SPRINT_SPEED` **44.8 studs/s = 45 km/h** | §5.3 |
| `KINDS.ORDER` | 4 → 7, so 7 template lookups per step instead of 4 (table reads once a template is held) | §13.5 |
| `byKind` | 5 keys → 8 | §8.2 |
| hit-card `box` | every zone's centre on the animal, ≥ 80 % of the worst zone's grid | task 205's measured 82 % |
| zone rays | 12 per deer kind, each returning its own zone | `boar_zones.spec`'s method |
| clip length drift | ≤ 1/48 s between `row.clipSeconds` and `CLIPS[name].seconds` | `BoarAssetsBoot`'s existing warn |

---

## 13. How it is tested

### 13.1 `tests/server/deer.spec.luau` (new) — the arm each case enters

Named by **arm**, per the brief. Every case must be shown **failing against the pre-fix commit**
(L-028), and every place a `kind` is read gets a case that actually enters the new arm (L-093).

| # | Arm entered | What it proves |
|---|---|---|
| 1 | `Weapon.Rules.unlicensed` **true** branch, reached from a **real** deer trunk built by `Body.create` — not the hand-made stub `weapon_rules.spec` uses | **unlicensed is refused**: `Match.classifyTarget` on a real stag answers `species = "reddeer"`, `Rules.ask` returns `REASON.LICENCE`, and `Rules.noticeFor` is `NO LICENCE` |
| 2 | the same rule's **false** branch with `held = { reddeer = true }` | **licensed shoots** |
| 3 | `Body.create`'s `row.species or "boar"`, **both** arms | all three deer kinds publish `Species = "reddeer"`; all four boar kinds publish `"boar"` (the default is what keeps them unchanged) |
| 4 | `Boar.speciesConfig` identity arm | `== config` **by reference** for nil, `"boar"` and an unknown species; a clone with the three tables for `"reddeer"` |
| 5 | `Boar.kindConfig` composition arm | a deer kind gets the species tables **and** the `wary` scaling; a boar kind with no `wary` row is still `config` by reference |
| 6 | `Body.hasClip`'s id lookup, per species | false for every deer clip while no deer animation row exists, **and** the deer's `ANIMATION_IDS` is a different table: write an id into the boar's and the deer's is still empty (§3.6) |
| 7 | `Boar.deerComposition` | exact at roll 0 and 1 (never / always); each of the three compositions at its weight boundary; `Boar.compositionSize` of each is 1 / 2 / 3; **nil and no roll drawn** when `KINDS.ENABLED` is false |
| 8 | the cap | a second deer group is refused while one is alive, and allowed after `Runtime:clear` |
| 9 | `Score.kill`'s `pointsForKind` **known** branch | stag 20, hind 6, calf −10, and `known == true` for all three, so none of them lands in `unknownKindKills` — the **penalty is the row** (D-3) and there is no second mechanism |
| 10 | `HitLog.Shape`'s counted-kind `if` | a stag kill increments `byKind.stag` and **not** `byKind.unknown` |
| 11 | `Shop.rowsOk`'s I3a, **both** arms | no problems with `sale = true` + `shipped = true`; and still **refused** for `sale = true` + a hand-made licence table with `shipped = false` — the invariant is not weakened by being satisfied |
| 12 | `SCENE.ANIMAL_SCALES` vs the baked lengths | for all **seven** kinds, `ANIMAL_SCALES[kind] * 5.5` equals that kind's baked length in studs. This replaces the scene's hand-maintained *"the same four numbers"* comment with arithmetic, and it is the case that catches the §7.1 trap (deer `scale` is ÷ stag, scene `scale` is ÷ boar male) |
| 13 | `Report.boarImage`'s three new branches | stag → the stag id, hind → the hind id, calf → the **hind** id at `CALF_SCALE`; `Report.kindWord` returns all three as they came; `Report.trophyWord("stag") == "RED STAG"` and is nil for `hind` and `calf` |

### 13.2 Existing server specs that gain an arm

| Spec | The arm |
|---|---|
| `boar_zones.spec` | twelve real rays per **deer** kind, from outside, each returning its own zone (§7.3). This is the acceptance test for the measured boxes. |
| `boar_kinds.spec` | the sweep extended to the deer: **every deer kind at every speed the Brain can ask for**, failing if any rate sits on `minRate` or `maxRate`. This is what decides §7.4's `MAX_RATE` question. |
| `boar_sounder.spec` | a deer release forms a sounder, gets a leader, and `Boar.marchOrder` puts a hind in front of her calf and a stag last |
| `boar_body.spec` | `Body.kindGeometry` for the three deer kinds: trunk, four zones and mesh scale all off the **deer's** tables |
| `boar_model.spec` | the new `animationIdFor(species, name)` order, and a **stale one-argument fake answering nil** (§6.4) |
| `assets_seam.spec` | every `KINDS.ORDER` row's `model` has an `Assets.KEYS` entry and every deer clip name has a key — the data `BoarAssetsBoot`'s two assert loops check, asserted where a spec can see it (no spec can require a boot script, and task 219's boot died at its own assert with no spec watching) |
| `report_silhouette.spec` | still asserts against **`Boar.CONFIG.ZONES`** by that path, so the deer's zones can neither break nor satisfy it (§8.1) |
| `shop.spec` | the renamed label and blurb; `#Shop.rowsOk(...) == 0` with the row on sale |
| `weapon_rules.spec` | unchanged and must stay green: its `reddeer` **stub** has proved this gate since task 171, and case 1 above is the real animal arriving at the same rule |
| `match_score.spec` | the three new `POINTS.KIND` rows priced through `Score.kill` |

### 13.3 Client specs

| Spec | The arm |
|---|---|
| `tests/client/hit_card.spec.luau` | the card for a stag: the deer image is the one drawn, the plate's second label reads `RED STAG`, and **`ImageLabel.IsLoaded` is probed** — task 205's lesson is that an empty label measures perfectly |
| `tests/client/report_panel.spec.luau` | `listCellsFor` folds stag → MALE, hind → FEM, calf → CUB; the detail row prints `STAG` / `HIND` / `CALF` and is not clipped |
| `tests/client/shoot_boar.spec.luau` | a real shot at a real deer, end to end, in the client's own hands |

### 13.4 The harness, the screenshots and the gate

**Three screenshots, inspected (rule 5).** A number is not a verification, and the three things most
likely to be measured-correct-and-look-wrong here are:

1. **The three deer standing beside a boar**, in the Forest Test with `BOAR_MODEL` on, one capture.
   What to look at: the stag is a quarter longer than a boar male and carries his head **above** the
   boar's back; the calf is not sunk into the ground; the antlers are not clipping the trunk; no
   grey box.
2. **The hit card after a stag is shot**, with a dot on it. What to look at: there is an **animal**
   on the plate (the decal trap, §8.1), the dot is on the body part that was hit, and the label
   reads `RED STAG`.
3. **The gathering at the end of a drive with a stag in it.** What to look at: the stag is laid out
   lying on its **right** side at the drive's own scale and is visibly the biggest thing in the row
   — `Runtime:displayCarcass` is a path that was wrong for five tasks precisely because nobody
   looked (task 173 round 1, finding 2).

**Harness input** (`tests/client/input_scenarios.txt`) is not needed for anything new: the deer is
shot with the same trigger the boar is, and `shoot_boar.spec` already drives it. The harness **can**
drive input and capture (Tasks 6 and 7 are both closed), so neither is a claimed-but-unrunnable
verification.

**What the harness cannot do, and what therefore goes to Karen:** publish an animation asset id
(11 clicks), press Rojo **Connect**, and set the `BOAR_MODEL` override for the playtest the three
screenshots are taken in. All of that is one **`NEEDS KAREN 223`** entry in `ESCALATE.md` with the
clicks in order.

**The gate includes `test2`, and that is unavoidable.** `Match.CONFIG.POINTS.KIND` and
`SCENE.ANIMAL_SCALES` live in `src/server/Match/init.luau`, which is on `TWO_PLAYER_PATHS`, and
`tests/server/match_score.spec.luau` matches `match_*.spec.luau`. So the PR needs
`[harness2] PASS: n/n checks @ <same sha> (clean tree)` and one human click.

**This is accepted rather than worked around.** What a kill is worth is the **match's** data —
`Score.kill` prices off `POINTS.KIND` and nothing else — and there is exactly one such table. Moving
the deer's three prices out of it to dodge a harness run would create the second price table that
rule exists to prevent, and it would be a worse trade than one click. The Builder plans for it: the
`test2` run is part of the definition of done for this task, and the reason is written in the
request so the Reviewer does not have to derive it.

### 13.5 Scope membership (standing rule G)

`tests/server/deer.spec.luau` is named in **six** `SCOPE_SPECS` tuples, because six owners' files
can break it, and the dual-membership idiom (`zz_horn`, `boar_hit`, `shoot_boar`, `money`) is
already how this table says that:

| scope | reached by |
|---|---|
| `boar` | `src/server/Boar/`, `src/server/BoarAssetsBoot.server.luau` |
| `assets` | `src/serverstorage/Assets/` |
| `weapon` | `src/shared/Licences/` |
| `shop` | `src/shared/Shop/` |
| `report` | `src/shared/Report/`, `src/server/HitLog/` |
| `match` | `src/server/Match/` |

No `BLAST_RADIUS` row is added: every path this task touches is already mapped. `tools/studio_mcp.py
selftest` fails if a spec file belongs to no scope, so this is a CI condition and not a preference.
A `--scope auto` run for this task therefore resolves to roughly the whole suite, which is correct
and is why only the **review round** can use it; the PR to `main` needs the full `test` anyway.

### 13.6 Docs the Builder updates

`docs/research/2026-10-20-red-deer.md` + `docs/research/INDEX.md` (rule 1) · `GAME_DESIGN.md`'s
*System owners* table (rule 3: it mirrors this design) · `TASKS.md` row 223's status ·
`assets/uploads.json` (3 models + 2 decals, with Karen's verbatim OKs) · `CREDITS.md` (the Fab
attribution, §15 source 5) · `ESCALATE.md` (`NEEDS KAREN 223`).

---

## 14. The order of work

The dependencies are real and getting them wrong costs a round:

1. `tools/boar_prep.py` `SPECIES` table + `selftest` (offline, no Blender, no model).
2. The prep run for all three deer, which **measures** `seconds` and `groundStudsPerSecond` per clip
   and writes one FBX per clip. Everything it writes stays **outside the repo**.
3. Upload the three models (`tools/roblox_upload.py`, Karen's OK on record) → `Assets.ROWS`.
4. Upload the two keyed PNGs → resolve each **decal** id to its **Image** id on the server
   (§8.1) → `Report.CONFIG.BOAR_IMAGE`.
5. **Probe the loaded rig in a Play session** → `SPECIES.reddeer.BODY_SIZE` and `ZONES` (§7.2, §7.3).
   *Nothing before this point can be guessed past.*
6. The data and the seam: `KINDS` rows, `SPECIES` table, `speciesConfig`, `kindConfig`,
   `deerComposition`, the four Runtime call sites, `Body.create`'s one line, `BoarAssetsBoot`,
   `MARCH_RANK`, `VOICE`, `POINTS.KIND`, `ANIMAL_SCALES`, `byKind`, `boarImage`, `trophyWord`,
   `listCellsFor`, `Licences`, `Shop`.
7. The specs (§13), each shown failing first.
8. `ESCALATE.md` `NEEDS KAREN 223` → the 11 publishes → the animation rows → `deathLiftStuds`
   (§7.5) → the three screenshots.

Steps 3–5 and 8 need Karen's clicks or a live session. **If step 8 has not happened when the task is
otherwise done, the deer ships standing and sliding with `Body.hasClip` false** — which is honest,
is tested, and is the precedent (tasks 115 → 116). It is **not** a reason to ship step 5 guessed.

---

## 15. External sources

### 15.1 Animal Diversity Web — *Cervus elaphus*

University of Michigan Museum of Zoology, <https://animaldiversity.org/accounts/Cervus_elaphus/>.
**Licence:** ADW's own terms of use (its account text is published under a Creative Commons
BY-NC-SA licence); text consulted, nothing copied. **Status:** maintained by the Museum of Zoology,
and this repository **already borrows from ADW** — `Boar.CONFIG.SOUNDER.MAKEUP.REAR_GUARD`'s comment
names *"ADW's 'adults in the lead AND rear'"*.
**Well:** group structure, which is what this design needed — hinds with their calves in
matriarchal groups, stags solitary or in bachelor groups outside the rut, a stag holding hinds in
the rut. That is Karen's sentence, independently.
**Badly:** nothing usable on flight distance, no speed in units a 0.28 m stud can take, and nothing
at all about a driven hunt.
**Adopted:** the three group compositions of §4.2, and the decision that a stag alone is the common
case rather than the rare one.

### 15.2 Reynolds, *Steering Behaviors For Autonomous Characters* (GDC 1999)

<https://www.red3d.com/cwr/steer/gdc99/> and <https://www.red3d.com/cwr/boids/>.
**Licence:** the author's own pages; the technique is described, **no code taken** — which is what
`Boar.CONFIG.SOUNDER`'s header already records.
**Status:** unmaintained since 1999 and canonical. A paper, not a library.
**Well:** leader following blended with separation / cohesion / alignment, which is exactly the
sounder this game has.
**Badly:** it states no hierarchy among the three rules, which this repository has already
**corrected** in writing (`SEPARATION = 1.6`, and its comment: *"this is THIS BUILD'S decision, not
Reynolds'"*).
**Adopted:** **nothing new.** A deer group is the boar's blend unchanged, and that is the point —
the alternative is a second flocking model with its own weights to disagree with the first.

### 15.3 Roblox — Rigging, and AnimationController / Animator

<https://create.roblox.com/docs/art/modeling/rigging> and
<https://create.roblox.com/docs/reference/engine/classes/AnimationController>.
**Licence:** Roblox's documentation terms; facts used, no text copied.
**Status:** maintained by Roblox (it is their engine reference).
**Well:** bones are descendants of the MeshPart, and `Animator:LoadAnimation` on the **server**
replicates the track to every client — which together are why one clip set on one shared `Arm_Deer`
serves three kinds and every player sees the same animal doing the same thing.
**Badly:** it does not say what the FBX importer does to a shared armature, and it does not say that
an animation asset id can only be made in the Animation Editor. This repository **measured** both
(`docs/research/2026-10-03-boar-skinned-model.md`), and `Assets.KEYS`'s boar block records that
`AssetService:CreateAssetAsync` answered *"not available yet"* for Animation and Model on
2026-10-03. The documentation is right about the engine and silent about the pipeline.
**Adopted:** one clip set for three kinds (§6.1), published once, by hand.

### 15.4 theHunter: Call of the Wild

<https://store.steampowered.com/app/518790/theHunter_Call_of_the_Wild/>.
**Licence:** a commercial game. Nothing is taken but the **shape of a rule**; no asset, no code, no
text. **Status:** actively updated. Already source 4 of
`docs/research/2026-10-13-the-rules.md`, which is where `src/shared/Licences` came from.
**Well:** permission is **per species**, it is bought, and the refusal is immediate and legible at
the moment of the shot — which is `Rules.NOTICE[REASON.LICENCE] = "NO LICENCE"`.
**Badly:** it ties permission to **weapon class** as well as to species, which this game refuses:
one card, one species, covering stag, hind and calf (D-2). A second dimension on the rule would make
"may I shoot this" a two-table question.
**Adopted:** `Licences.ROWS.reddeer` as it already stands since task 171. **This design adds no
rule**; it flips `shipped` and renames a label.

### 15.5 Fab Standard License

<https://www.fab.com/eula>.
**Licence:** the EULA itself — the licence Karen bought "Red Deer Family" under.
**Status:** maintained by Epic Games.
**Well:** it permits private use, reproduction and modification of the Content as a **component** of
a game that adds its own value, which is what this is.
**Badly, and it must be said again on the deer's row:** the page **answers 403 to this machine's
fetch tool**, so `src/serverstorage/Assets/init.luau`'s `BOAR_LICENCE` quotes it from a web search
of 2026-10-03 **and says so**. The deer's new `DEER_LICENCE` constant carries the same quote, the
same caveat and a new `attribution` naming *"Red Deer Family" by RedDeer, bought on Fab under the
Fab Standard License on 2026-10-20*.
**Adopted:** the two conditions that matter are met either way — the binary is never committed
(`.rbxm` is banned outright) and nothing is distributed standalone; what reaches Roblox is an asset
inside Karen's own account used by her own place.

### 15.6 A recorded negative result

**No source with a licence this design could cite gives a red deer's flight distance from a walking
person in a form this game can use.** Figures in the tens to low hundreds of metres are commonly
quoted and are not reproducible here, and a 100-m flight distance would empty the drive corridor
before a beater was in sight (§5.3). So `noticeScale` is reasoned from **this game's own geometry**,
and that is recorded as a negative result for the same reason
`KINDS.LEGENDARY.CHANCE_PER_DRIVE`'s comment records one: *"the genre published rare-spawn rates are
player estimates and the research note records that as a NEGATIVE result"*. The number is Karen's to
turn after one playtest.

---

## 16. Open decisions

**None of these blocks the build.** Each has a written default the Builder ships and a fallback.

1. **THE DIRECTOR, FIRST.** `BOAR_MODEL`'s default is `false`, so on the default build no deer can
   spawn (§10) while `Shop.ROWS[RED_STAG].sale = true` sells the card for 750 coins. Nothing in the
   harness catches it. The flag **expires 2026-10-24** and `flags.spec` fails the harness on a past
   expiry, so the Director must answer within four days regardless.
   *The Builder ships:* `shipped = true` and `sale = true` as literals, per D-1.
   *If the Director flips `BOAR_MODEL`'s default to `true`* (Karen has already accepted the drawn
   boar; this is step 6 of the flag lifecycle and is hers to authorise), the catalogue is honest and
   nothing else changes.
   *If he will not*, the one-line fallback is `sale = false` with `shipped = true` — which
   `rowsOk` **allows** (I3a only refuses sale-with-not-shipped) and which is the state task 221
   shipped. The card then goes on sale with the flag flip, in a three-line commit.
2. **KAREN (feel).** `DEER.CHANCE_PER_RELEASE = 0.2` → 2.16 deer per drive against 6 boars, and a
   quarter of drives with none (§4.2). One number.
3. **KAREN (feel).** `runScale = 1.18` → 45 km/h, against a real red deer's 65–70 (§5.3). One
   number, and the design argues against going higher.
4. **KAREN (feel).** Should a stag carry a wound further than a boar? That is a `toughness` row and
   this design deliberately gives it none (§5.4).
5. **KAREN (feel).** Deer group spacing: two hinds may stand nose-to-tail (§5.4). Changing it means
   scaling `SEPARATION_STUDS`, `COLUMN_SPACING_STUDS` **and** `FORMATION` together, or none.
6. **KAREN (feel).** The deer voice. v1 is the boar's samples at three pitches (§5.5). A real cue
   set (roar / bark / bleat) is a Roblox library id she must hear first.
7. **THE DESIGNER / THE DIRECTOR (scope).** The start card has four rows and they are spoken for, so
   the deer is announced nowhere on it (§8.4). A fifth row, a merged row, or a second page is a
   layout decision with a measured height.
8. **THE DIRECTOR (scope).** The rename to `src/server/Animal`, with the full name list in §11.1.
9. **THE DIRECTOR (scope).** A fourth count column on the report board for the trophy and the deer
   (§8.2) — queued since task 219 and now carrying three more kinds.

---

## 17. What this design could not verify (rule 8)

* **The zone and trunk measurements do not exist yet.** §7.2 and §7.3 specify a probe and its
  acceptance test; they do not contain numbers, because no deer model has been uploaded or loaded.
  Anything written there before the probe would be a guess, and the boar's `head` box was wrong for
  five tasks the last time one was reasoned instead of measured.
* **The deer clips' `seconds` and `groundStudsPerSecond` are not known.** They come out of the prep
  run (step 2 of §14). §7.4 therefore cannot say whether the deer needs its own `MAX_RATE`; it says
  what decides the question and which way the fix goes.
* **No Roblox Studio was available to this run** (`.agent-evidence/INDEX.md`: *"Roblox Studio is not
  available: harness claims can be checked only for consistency"*). Every claim in §13.4 about what
  a screenshot will show is a requirement on the Builder, not an observation.
* **`DevPackages/` is absent from the worktree**, so the sourcemap omits TestEZ. Nothing in this
  design depends on it beyond the spec files existing where `tests/TestKit.luau` loads them.
* **The Fab EULA was not read from the page** (§15.5). The 403 is pre-existing and is recorded in
  `Assets.ROWS`'s `BOAR_LICENCE`; the deer's row inherits the caveat verbatim.
* **Red deer flight distance** has no citable source this design would stand behind (§15.6).
* **`SLOT_BACK_STUDS` and `SLOT_SIDE_STUDS` appear to have no reader** in `src/server/Boar/`
  (`FORMATION` and `COLUMN_SPACING_STUDS` are what `Brain` reads). §5.4's reasoning does not depend
  on it, but the two rows being dead is worth an audit item rather than a silent assumption.
