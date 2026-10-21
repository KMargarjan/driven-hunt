# Task 223 BRIEF: the red deer -- stag, hind and calf in the drive

Written by the Builder, carrying the Director's dispatch of 2026-10-20. Read this first
(`docs/ARCHITECT_PROMPT.md`): it **overrides** anything older in `docs/`, `TASKS.md` or an earlier
design.

The design file to write is **`docs/design/red-deer.md`**.

---

## 0. What Karen bought and what she said

Karen, 2026-10-20: *"I will buy red tag deer"*. She bought **RedDeer's "Red Deer Family"** (Fab,
Personal licence): three rigged animals -- stag, hind (the package calls her Doe) and calf.

**UPLOAD OK, verbatim `"yes"`** (2026-10-20 ~13:05) to: *"may I upload the Red Deer models and their
animations to Roblox (your account, private use in this game, never shared)?"*

**UPLOAD OK, verbatim `"yes"`** (2026-10-20 ~13:10) to: *"your deer silhouette pictures (for the hit
card) ... Want them uploaded too, like the boar ones?"* -- `male deer.jpg` and `famale deer.jpg`.

**Karen, 2026-10-20 ~13:35, verbatim:** *"deer also will be possible to shoot if you have purchased
deer license"*.

**BOUGHT ASSET.** The FBX, the textures and everything the prep writes stay **outside the repo**,
exactly as the boar's did. Nothing of the package is ever committed or redistributed.

---

## 1. DECISIONS ALREADY TAKEN. The design does not reopen these.

**D-1. A red deer is a LICENSED species, and the gate already exists.** `ReplicatedStorage.Licences`
has carried a `reddeer` row since task 171 and `Weapon.Rules.unlicensed` (rule 3 of the fire gate)
already refuses a shot at a species the shooter holds no card for. **No new gate is designed.** What
lands is the DATA: `Licences.ROWS.reddeer.shipped = true` and `Shop.ITEM.RED_STAG.sale = true`, in
the same commit as the animal -- which is the day `Licences`'s own header and `Shop.rowsOk`'s I3a
were written for.

**D-2. The refusal covers ALL THREE: stag, hind and calf.** Karen's words are *"deer also will be
possible to shoot if you have purchased deer license"* -- one licence, one species. So every deer
kind publishes `Species = "reddeer"` and one card covers the family. **The card is renamed.** "RED
STAG CARD" granting permission over a hind and a calf too would be the shop lying (`rowsOk`'s I3
spirit); the Builder's choice is **`DEER LICENCE`**, with the blurb saying it covers stag, hind and
calf. The grant string `licence = "reddeer"` and the item id `licence.reddeer` do **not** change --
they are keys, and renaming a key would be renaming the rule (`Report.kindWord`'s own rule).

**D-3. A calf is a piglet.** Karen's cub rule, 2026-10-12, is that shooting the young is a penalty,
and the calf is the same rule. `POINTS.KIND.calf = -10`, the identical figure `cub` carries and the
same figure `SAFETY_PENALTY` uses. **One number, no second mechanism**: `Score.kill` already prices
a kill off `record.kind` and nothing else, so a negative row IS the penalty. The design must NOT
invent a second penalty path for it.

**D-4. The points.** `stag = 20`, `hind = 6`, `calf = -10`.
- `stag = 20` is **two males**. Above a male boar (10) because it is the licensed, rarer, paid-for
  quarry, and **below the legendary boar (25)**, which stays this game's ceiling because it is
  Karen's own (*"first place ofc more legendary more ect"*) and is a 1-in-4 trophy.
- `hind = 6` is **exactly the sow's price**, which is the Director's figure (*"hind ~ female boar"*).
  A hind and a sow are the same thing to a hunter -- the female of the species -- so they cost the
  same, and no reason has to be invented for a gap.
- At `Economy.CONFIG.COINS_PER_POINT = 2` a stag pays 40 coins, so the 750-coin licence pays back
  over about nineteen stags. That is deliberate: a licence is a season, not a transaction.

**D-5. ONE OWNER, AND IT IS THE ANIMAL RUNTIME THAT ALREADY EXISTS.** A second 2,400-line brain for
a second quadruped is the "invented foundations" failure `docs/PROJECT_CONTEXT.md` names. The
Builder's proposal, which the design should adopt or refuse in writing:

> The red deer is **a SPECIES dimension on the kind row**, not a new system. `Boar.CONFIG.KINDS`
> grows `stag`, `hind` and `calf` rows; every row carries `species` (defaulting to `"boar"`, so no
> existing row changes meaning); `Boar.Body.create` publishes `Species` **from the kind row** instead
> of the literal `"boar"` it publishes today. The Brain, the Wound, the Body, the kill record, the
> display carcass and the hit log are untouched in their logic.

If the Architect wants the folder renamed (`src/server/Boar` -> `src/server/Animal`), **say so and
say it is a LATER task**: a rename of a 10,000-line owner inside this task would bury the deer in a
diff nobody can review.

**D-6. The behaviour is the boar's brain with numbers, not new states.** Deer are faster, jumpier and
flee earlier. The design must express that as **multipliers on rows that already exist** -- the shape
`KINDS.legendary.wary` already has (`noticeScale`, `runScale`) -- and must NOT add a Brain state.
Group makeup: a stag alone or with hinds, a hind with a calf.

**D-7. The silhouettes are the boar's mechanism, including its scar.** `Report.CONFIG.BOAR_IMAGE`
gains deer rows. Task 205's measured lesson is binding: **an Open Cloud PNG upload creates a `Decal`,
and an `ImageLabel` cannot draw a decal id.** The id written into config must be the **Image** id,
resolved on the server with `InsertService:LoadAsset(decalId).Texture`, and the **decal** id is what
`assets/uploads.json` records. Male image -> stag, female image -> hind, **female image scaled down
-> calf** (the `PIGLET_SCALE` pattern, said out loud).

**D-8. The animation asset ids are Karen's clicks and will not be faked.** Measured again for this
package, below: all three deer share ONE armature, so ONE clip set serves all three kinds. An
animation asset id can still only be made in Studio's Animation Editor (`Assets.KEYS`'s own block,
and `docs/research/2026-10-03-boar-skinned-model.md` source 1: *"It is clicks, per clip. There is no
API behind it"*). So the keys are declared with **no rows**, `Assets.byKey` answers nil,
`Body.hasClip` is false and the deer stands and slides exactly as the boar did between tasks 115 and
116 -- which is honest, is tested, and is the precedent. The clicks go in `ESCALATE.md` as
**`NEEDS KAREN 223`**.

**D-9. Deer are rarer than boars and the mix is one number.** The Builder's proposal: a release is a
deer group with chance `DEER_CHANCE_PER_RELEASE = 0.2` (one release in five), drawn per release, with
the boar's own release machinery otherwise untouched. The design names the number and where it is
read, once, at one boundary.

**D-10. Born behind a flag? NO -- and the design must say which it is.** The Builder's reading: the
deer is **content behind the licence**, not a feel-critical path: with no card nobody can shoot one,
and with `Licences.ROWS.reddeer.shipped` the rollback is a three-line revert. A new `DEER` flag would
add a third state (flag off / card unowned / card owned) to a rule that already has two. The
Architect decides and writes the reason down.

---

## 2. MEASURED FACTS about the package. These are not guesses.

Probed with headless Blender 5.2 on 2026-10-20 from
`<assets-dir>/deer/incoming` (the unzipped copy; the Downloads originals untouched).

| | file stem | armature | bones | triangles | bbox (m) X / Y / Z |
|---|---|---|---|---|---|
| stag | `Red_Deer` | `Arm_Deer` | 42 | 14,652 | 0.971 / 1.975 / 2.219 |
| hind | `RedDeer_Doe` | `Arm_Deer` | 42 | 12,342 | 0.562 / 1.689 / 1.429 |
| calf | `RedDeer_Calf` | `Arm_Deer` | 42 | 12,200 | 0.345 / 0.976 / 0.973 |

1. **ONE RIG FOR THREE ANIMALS.** All three carry `Arm_Deer`, 42 bones, with identical bone names.
   This is the boar's situation (`Arm_Boar`, 46 bones, shared by male/female/cub) and it means
   **one clip set, published once, serves all three kinds** -- the clicks are 1x, not 3x.
2. **Y IS LENGTH, Z IS HEIGHT.** At this project's 1 stud = 0.28 m the lengths are stag **7.05
   studs**, hind **6.03**, calf **3.49** -- against the boar male's 5.5. The stag's Z of 2.219 m is
   antler height, not body length.
3. **THE PACKAGE SHIPS 77 CLIPS (80 for the calf), AND THE NAMES ARE NOT THE BOAR'S.** Of
   `boar_prep.py`'s `DEFAULT_CLIPS`, eleven exist verbatim (`Idle_1`, `Idle_5`, `Walk_F_IP`,
   `Trot_F_IP`, `Run_F_IP`, `Turn_L_IP`, `Turn_R_IP`, `Death_L`, `Death_R`, `EatDrink_start`,
   `EatDrink_end`) and **five do not**: the deer has `Hit_Front` / `Hit_Back` / `Hit_Middle` where
   the boar has `Hit_F` / `Hit_B`, one `Eat_loop` where the boar has `Eat_loop_1` / `Eat_loop_2`, and
   `Eat_walk_IP` / `EatDig_loop` where the boar has `Dig_walk_IP`. **So the clip list is per species
   and cannot be a constant.**
4. **The file layout is the boar's exactly**: `<animal>_NoAlpha.fbx` + `<animal>_anim_IP.fbx`, with
   `_LOD` / `_LowPoly` / `_RM` variants beside them. Textures are `Red_Deer_*`, `RedDeerDoe_*`,
   `RedDeerCalf_*` with `Albedo1..4`, `Normal`, `Roughness` -- `boar_prep.py`'s `texture_names` shape
   with three more stems. **The calf's embedded albedo is a `.tif`**; the separate texture folder's
   is a PNG, which is what the prep reads.
5. The bone groups `boar_prep.py`'s synthesised clips name (`thigh_b`, `shin_b`, `hoof_b`, `hip_b`,
   `thigh_f`, `shin_f`, `hoof_f`, `hip_1_f`, `Spine_`, `tail_`, `head`) all exist on `Arm_Deer`, with
   ONE difference: the deer's neck is `neck_01` / `neck_02` where the boar's is `Neck`.

---

## 3. THE TOOL. One rule, and the Builder's answer is: GENERALISE, do not twin.

`tools/boar_prep.py` already has the animal dimension, `--clips`, `--length-studs`, `--texture-px`,
`--albedo`, the copy-and-hash guard and the ground-speed measurement. A deer twin would be a second
copy of all of that, which is rule 2 inverted. **The Builder will add a SPECIES table** carrying,
per species: the animal names, the texture stems, the clip list and the synth-clip bone groups --
`boar` keeping today's values **by identity**, so `selftest` can prove the boar's recipe did not
move a character. The file keeps its name this task (a rename is a separate diff); the Architect
says whether it should become `tools/animal_prep.py` later.

---

## 4. WHAT THE DESIGN MUST CONTAIN

1. **The owner table.** Who writes a deer's body, its brain, its species attribute, its points, its
   licence verdict, its silhouette and its spawn decision -- one writer each, named by module, and
   which of them are UNCHANGED from the boar. Rule 3.
2. **The species seam, in one sentence per file.** Exactly which existing modules learn the word
   `species` and which must not. In particular: does `Boar.CONFIG` grow a `SPECIES` table, or does
   each kind row carry a `species` string? Name the one that makes the smaller diff and say why.
3. **The spawn mix**, as the numbers and the one boundary that reads them: chance of a deer release,
   the group compositions (stag alone / stag + hinds / hind + calf) and their weights, and the cap
   (can two deer groups be out at once?).
4. **The behaviour numbers**, as multipliers on existing rows: notice radius, flee speed, how much
   earlier it breaks, and the group's spacing. Each with a reason, and none of them a new state.
5. **The clip list for the deer**, chosen from the 77 and named one by one with what each is for --
   the boar's `DEFAULT_CLIPS` block is the format. **Say how many clicks that is for Karen**, and
   whether the calm repertoire (`Idle_5`, `Eat_loop`, `EatDrink_start/end`) is in v1 or queued: every
   clip is a hand publish and the design is what decides whether it is worth one.
6. **The lengths baked in**, in studs, for all three, against the measured bbox above.
7. **What is NOT in v1, in writing.** The Builder's list, for the Architect to confirm or correct:
   the synthesised death-paddle and cripple-drag clips (the boar's three authored clips, task 116),
   roaring/rutting, antler damage, a deer-only sound set, and a third silhouette image for the calf.
8. **The specs**, by name, and for each one the ARM it enters -- not the assertion. The Learning
   Agent's L-093 and L-028 are binding here: *licensed shoots*, *unlicensed is refused*, *calf scores
   the penalty*, *stag and hind score their own prices*, and each must FAIL against the pre-fix
   commit. Name which scope in `SCOPE_SPECS` each new spec file joins (standing rule G: a spec in no
   scope turns CI red).
9. **The open decisions, if any, as a numbered list** -- that is what makes `ARCH_RESULT.md` a
   blocking verdict rather than a note.

## 5. What the Builder will NOT do in this task

Rename the Boar owner; build a second brain; author new clips; add a Brain state; publish an
animation asset id (Karen's clicks); touch `TWO_PLAYER_PATHS`; or sell a licence for an animal that
is not in the drive.
