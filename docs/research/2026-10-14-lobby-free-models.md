# Free Creator Store models in the lobby: how one gets into this place, and what it costs

2026-10-14, task 180. Written before the code, per CLAUDE.md rule 1.

Karen, 2026-10-14 ~09:30, verbatim:

> let's start with lobby / we need better house we can use free models / we need car truck model or
> hunting bus also use free model / place could be a bit more nicer like road going to that house and
> around fields and forrests / ... and then on walls we can make trophys like head of deer head of
> boar / so work on lobby now

---

## 1. What the system must do

1. Put a **free, public, script-free** hunting lodge, a hunting truck (four of them, side by side)
   and two kinds of trophy head into the lobby that task 177 built at (2850, −2950) in the Forest
   Test place.
2. Do it **without a Karen click** if that is possible, and say plainly and immediately if it is not
   (the dispatch's `NEEDS KAREN 180`).
3. Keep **task 177's flow** working: spawn at the lodge, walk into the circle by the truck, drive.
4. Keep the lobby buildable **where the models are not** — the DEV place, a renamed folder, a spec —
   because the harness and every server spec run in a place that has never seen them.
5. Stay inside a part budget somebody can read, and credit every creator.

### What it must not do

* Put a Script, LocalScript or ModuleScript anywhere (CLAUDE.md: *"Nothing script-like is ever
  created in Studio"*, and the harness fails on one outside a Rojo-owned path).
* Commit a `.rbxm` or `.rbxl` (banned: CI and the harness both fail on it).
* Make the DEV place's harness depend on content only one of the two places has.

---

## 2. The three routes, and which of them this repository has already measured shut

### 2a. `InsertService:LoadAsset(id)` at run time — **REJECTED, and it was measured, twice**

This is the route every other asset in the game takes (`src/serverstorage/Assets/Loader.luau`, the
only caller in the repo), and it works there because every id in `Assets.ROWS` is **Karen's own
upload**. It does not work for a free Creator Store model somebody else made:

* `docs/research/2026-09-26-asset-pipeline.md` §8, from the Creator Store Terms: a free asset *"is
  licensed only if its creator ticked share, the same flag that decides whether a script may load
  it"*. The documented escape, `AssetService.AllowInsertFreeAssets`, is **`RobloxScriptSecurity` on
  read AND write**, so no script in any experience can turn it on.
* Measured in this repository on 2026-10-10, task 152: two free Creator Store **horn** models both
  answered `"User is not authorized to access Asset."` while a public **sound** id loaded fine
  (`docs/design/beater-kit.md` §16.1).
* `docs/design/asset-pipeline.md` D2 already records that `docs/design/map-generator.md` §8.2 is
  **wrong** about this, and names the three alternatives: buy the asset, use only shared ones, or
  *"insert it in Studio by hand and export"*.

**It was NOT re-measured for the four models chosen here, and that is deliberate.** The one way to
measure it from this seat is `execute_luau`, and `tools/studio_mcp.py`'s docstring forbids exactly
that in capitals: *"NEVER CALL `InsertService:LoadAsset` (OR ANYTHING ELSE THAT NEEDS AN ASSET
CAPABILITY) THROUGH `execute_luau` … it cost a night's gate"* — one such call on 2026-10-01 left the
MCP thread carrying `LoadUnownedAsset` and every `require` the harness made was refused afterwards.
A measurement that can break the gate, to re-confirm a rule two independent sources already state,
is not worth taking. **Reported as a gap, not as a fact (rule 8):** route 2a is rejected on recorded
evidence, not on a measurement of these four ids.

### 2b. Export the inserted model as `.model.json` under `src/` — **REJECTED, measured here**

It would be the best of all worlds: geometry in git, reviewable as a diff, present in both places.
It cannot be done today. `tools/studio_mcp.py`'s own docstring, on how check 4 compares a synced
file: *"a typed value (`{"Vector3": ...}`) fails as 'cannot compare' until a comparison is added"* —
and it *"never skips it"*. Every part in a model has a `Size` and a `CFrame`. So a `.model.json`
carrying geometry **fails the harness**, which fails the merge gate. Teaching the harness typed
values is real engineering-lane work and is queued, not smuggled into a lobby task.

### 2c. Insert it into the place once, in Edit, and CLONE it at run time — **ADOPTED**

StudioMCP ships two tools this repository had never used: **`search_asset`** (Creator Store, with
`priceFilter: "free"`) and **`insert_asset`** (by asset id, into a named `parentPath`). Measured
today, 2026-10-14:

| Measurement | Result |
|---|---|
| `search_asset` scope `creator_store`, `priceFilter` `free` | works; returns id, name, creator, `isFree`, `thumbnailUrl` |
| `insert_asset` of a free model nobody here owns (9552486262) | `{"status":"success"}`, **no Karen click** |
| 16 further free models inserted in one batch | 16/16 `success` |
| scripts in an inserted free model | present and real: the first candidate carried 3, one candidate carried 42 |
| `insert_asset` honours `studio_id` | **NO** — see §5, the one trap in this route |

So the Toolbox-take that task 152 assumed was needed is **not** needed: StudioMCP inserts a free
public model straight into the open place. That lands it in `Workspace`, which is the one container
CLAUDE.md marks *"Studio-edited, non-script content"* and which **Rojo does not manage**, so it
survives Karen's Connect. `Workspace.OurForest`, `Workspace.Foliage` and the two `Session` folders in
the same place are exactly this kind of content already — the precedent is in the place, not
borrowed from outside it.

The run-time owner then **clones** out of `Workspace.LobbyAssets`. No asset id appears anywhere in
`src/`, no `LoadAsset` is called, no capability is needed, and the fallback is the honest one: when
the folder is not there, task 177's parts build runs.

---

## 3. External sources

1. **Roblox Creator Docs — Creator Store / Marketplace Terms**, via this repository's own reading of
   them in `docs/research/2026-09-26-asset-pipeline.md` §8 (fetched and quoted there, 2026-09-26).
   Licence: Roblox Terms of Use, current and maintained.
   *Good:* it settles the legal question — the Terms grant use *"in Roblox Studio and in Experiences
   on the Services"*, so **using** a free model in our experience is exactly what the licence is for.
   *Bad:* it ties loadability to a per-asset "share" flag the listing does not show, which is why 2a
   fails unpredictably rather than consistently.
2. **Roblox Creator Docs — `InsertService` / `AssetService.AllowInsertFreeAssets`**
   <https://create.roblox.com/docs/reference/engine/classes/InsertService>. Licence: Roblox docs
   terms, current.
   *Good:* states the rule plainly — *"you must use `AssetService:LoadAssetAsync()` and enable
   `AssetService.AllowInsertFreeAssets`"*.
   *Bad:* it does not say that the property is `RobloxScriptSecurity` on both read and write, which
   is the fact that makes the sentence unusable; that came from the API dump.
3. **Roblox Creator Docs — `Model:ScaleTo` and `Model:GetBoundingBox`**
   <https://create.roblox.com/docs/reference/engine/classes/Model>. Licence: Roblox docs terms,
   current.
   *Good:* `ScaleTo` scales a `MeshPart`'s geometry as well as a `Part`'s size, so one number resizes
   a whole free model; `GetBoundingBox` is how "stand it on the shelf" becomes a measurement.
   *Bad:* a Model's pivot is its bounding-box centre unless somebody set a `PrimaryPart`, so
   `PivotTo` alone puts a lodge half underground — the sit-on-shelf correction is ours.
4. **This repository — `src/serverstorage/MapGen/Props.luau` (`Props.template`, `Props.scriptIn`)**.
   *Good:* the pattern for "a template becomes placed instances", including refusing a scripted
   asset, is already written and reviewed here; `Build.clone` is the same shape.
   *Bad:* it gets its template from `Assets.Loader` and therefore from an **owned** id, which is the
   one thing the lobby cannot do.
5. **This repository — `src/server/Lobby/Build.luau` at task 177**, and `TestArena.build`'s
   parts-into-a-folder, parent-last rule.
   *Good:* the whole fallback already exists, is reviewed, and is photographed. Nothing had to be
   invented for the no-models case.
   *Bad:* its interior placed everything against `cfg.LODGE.SIZE`, which is only one of the two rooms
   that now exist — hence `Room` and the wall-named trophy mounts.

---

## 4. What was measured about the models themselves

Sixteen free candidates were inserted and measured (parts, scripts, bounding box), and judged on
their Creator Store thumbnails side by side. The four chosen all carry **zero scripts**, which was
not assumed — it was counted.

| Role | Model | Creator | Asset id | Parts | Scripts | Size (studs) |
|---|---|---|---|---|---|---|
| lodge | Log Cabin | uhhhh17 | 4746497269 | 266 | **0** | 23.1 × 15.9 × 30.9 |
| truck | PickUp Truck (Prop) | RedWood Roleplay GROUP | 8891351929 | 76 | **0** | 18.5 × 7.0 × 8.7 |
| deer trophy | Deer Head Wall Mount Trophy Decor Home | bell4hd | 101243188132816 | 26 | **0** | 5.0 × 5.4 × 2.9 |
| boar trophy | Boar Head | Atejime | 15282258007 | 3 | **0** | 3.3 × 2.1 × 2.8 |

Rejected, with the reason, so they are not re-proposed:

* **Log cabin 9552486262** (Shamrockaway) — 1043 parts and 3 scripts for one building.
* **Old pickup truck 7658302807** — the prettiest truck by a distance, and 937 parts: 3748 for four.
* **Short Pickup Truck 10295313252** — 617 parts, 2468 for four.
* **Pickup Truck 6418225759 (by Roblox)** — the one model here that `LoadAsset` *would* accept, and
  it is a scripted vehicle kit (42 scripts) of modern sports trucks. Noted because "an asset Roblox
  owns" is a real escape hatch for a future task, just not for a parked prop.
* **69975694** — renders as a featureless brown box.
* **6404345915** — a grey suburban house, 1558 parts, 6 scripts.

**The lodge's interior was raycast, not assumed**, because the shop counter and three trophy heads
have to land on real walls:

```
east wall  x = +9.76    west wall  x = −10.01
back wall  z = +14.85   front wall z = −4.90
floor      y =   3.31   ceiling    y =  10.72
```

— relative to the model's own bounding-box centre and base. The box is **not** the room: 10.6 of its
30.9 studs of depth are porch, which is why the room's centre sits 5 studs north of the box's. A
7.4-stud ceiling against a ~5-stud character is headroom; a 19.6 × 19.6 room holds a 12-stud counter,
a fireplace and a shopkeeper (task 181).

---

## 5. The one trap, and it nearly dirtied the harness place

`insert_asset` **ignores `studio_id`**. Both open Studios — the Forest Test place and the **DEV
place, where the harness runs** — received all sixteen candidates, 77 scripts among them, straight
into `Workspace`. The harness's *"no script outside a Rojo-managed path"* check would have failed on
that, and the cause would have looked like a broken harness.

It was found by listing both places' `Workspace` children and seeing the same probe folder in each,
and both were cleaned before anything else was done (`scriptsInWorkspace=0`, verified in both). The
secondary cause was ours: `Studio._call(tool, args)` takes the studio as the **keyword**
`studio_id=`, and a `studio_id` buried in `args` is silently overwritten by `_scoped` with the pinned
default. Worth knowing for any future tool that inserts.

**Recorded for the Director:** the models now in the Forest Test place's `Workspace.LobbyAssets` were
put there by this task, in Edit. The place must be **saved** for them to survive a Studio restart —
that is the one thing here nobody but Karen can do, and it is not a blocker, because the fallback
build is what happens until she does.

---

## 6. The pattern adopted, and why

**A Studio-made, script-free template folder in `Workspace`, cloned by the run-time owner, with a
per-piece fallback to the parts build.**

* `Workspace.LobbyAssets` holds `Lodge`, `Truck`, `DeerHead`, `BoarHead` and a `Trees` folder.
* `Lobby.Build.clone(templates, key, …)` is the **one** place a template becomes a lobby instance. It
  strips scripts on the way through (belt and braces — these four carry none, and the next one might),
  anchors every part (a free model ships with whatever its builder left), scales with `ScaleTo` and
  sits the result on the shelf with `GetBoundingBox`.
* `templates` is an **argument**, like `container` and the anchor already are, so a spec drives both
  branches with a folder of plain parts and no Creator Store round trip.
* A missing template is **not an error**: it answers nil, the caller builds task 177's version, and
  `stats.models` / `stats.fallbacks` / `stats.strippedScripts` say which happened — counted, not
  believed.

**Borrowed rather than built (rule 2):** the template→instance shape and the script refusal from
`MapGen.Props`; the whole no-models lodge, truck, ring, sign and spawn from task 177; the ring itself
from `ForestTest.Markers.RING`; the trees from `Workspace.OurForest`, which is the actual wood the
drive runs in rather than a second kind of tree.

**Invented, with the reason here (rule 2):** `Room` — a measured rectangle `{centre, halfX, halfZ,
height}` — and trophy mounts that name a **wall** instead of an offset. There are now two lodges with
two different rooms (19.6 × 19.6 × 7.4 against 38 × 26 × 9), and a constant offset can only ever be
right for one of them; the other would hang a stag's head half inside a wall and the chimney through
the roof. That is this project's named failure mode (*"things measured correct and looked wrong"*)
with a number attached, so it gets a type rather than a comment.

---

## 7. Numeric targets

| What | Target | How it is checked |
|---|---|---|
| scripts anywhere in `Workspace.Lobby` | **0** | `lobby.spec`: the existing tree scan, plus a spec that hides a Script in a template and counts it stripped |
| lobby part budget | **≤ 1200** (was 400) | `Build.build` returns the count; `lobby.spec` asserts it in both branches |
| parts, free-model build | ~965: lodge 266, four trucks 304, trophies 55, trees ~150, the rest ~190 | `Build.stats().parts` |
| parts, fallback build | ~330 | `lobby.spec`, the no-templates case |
| trucks | **4**, `BAY_GAP_STUDS` apart, bay 1 unmoved from task 177 | `lobby.spec` reads each pivot's x |
| every cloned part | anchored | `lobby.spec` walks the built tree |
| every free model | bottom within 0.05 studs of the shelf | `lobby.spec` against `GetBoundingBox` |
| road, fences, trees | inside the 220 × 220 shelf | `lobby.spec`, the same bound `Field.fill` is held to |
| trophies | 3, on a wall, above the floor and below the ridge, in **both** builds | `lobby.spec` |

---

## 8. What I could not verify

* **That `InsertService:LoadAsset` refuses these four ids in particular** (§2a). Rejected on two
  recorded sources and one prior measurement of other free models; not re-measured, because the only
  available instrument is the one the harness docstring forbids.
* **That the place has been saved.** The templates are in the running Studio's `Workspace`. Whether
  they survive a restart is Karen's `File → Save` and nobody else's.
* **How the four models look in Karen's eye.** Two screenshots are owed and inspected (rule 5); the
  judgement is hers.
* **`screen_capture` with explicit camera arguments did not move the camera** in a background Studio
  window during this task — it returned the same frame twice. The camera was moved with
  `workspace.CurrentCamera.CFrame` instead. Reported as a harness-adjacent fault (rule 6), not fixed
  here.
