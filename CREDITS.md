# Credits

Third-party work used in Driven Hunt, and the credit each licence asks for.

This file exists because a licence condition that lives only in a code comment is a licence condition
nobody reads. Every entry below is also recorded, with the asset id and the sha256 of exactly what was
uploaded, in `assets/uploads.json` and in `src/serverstorage/Assets/init.luau` (the `licence` field of
each row).

## 3D models

### Double Barrel Shotgun — Ryan_Nein (CC-BY-4.0)

The first-person shotgun since task 105 (2026-10-02): its barrel group, its frame group and its shell.

> This work is based on ["Double Barrel Shotgun"](https://sketchfab.com/3d-models/double-barrel-shotgun-063cb20627ea40b0915f9d9eeb65c8dd)
> by [Ryan_Nein](https://sketchfab.com/Ryan_Nein) licensed under
> [CC-BY-4.0](http://creativecommons.org/licenses/by/4.0/)

The licence's own words, from the `license.txt` shipped with the download: *"license type: CC-BY-4.0
(http://creativecommons.org/licenses/by/4.0/); requirements: Author must be credited. Commercial use
is allowed."*

What was changed, and nothing else was:

- `tools/gltf_split.py` split the model into its two hinge groups and its shell and aligned them to
  the game's frame. No vertex was added, moved relative to its neighbours, or removed.
- `tools/asset_prep.py` (the `model-b-barrels`, `model-b-frame` and `model-b` presets) shaded it
  smooth by angle, resized the textures to 1024, and split the packed
  occlusion-roughness-metalness map into the two single-channel maps Roblox reads.
- **The shine was re-tuned for Roblox, and the steel recoloured with it.** The artist's map says
  metalness 0.98, which is right for steel in any renderer with an environment — and Roblox's
  environment over an open field is the sky, so in the game the barrels rendered as a white mirror.
  Metalness is written down to 0.10 and roughness to 0.50, and because a conductor's colour is what
  it reflects, the steel's base colour then had to carry the darkness the reflection used to: blued
  for the barrels, case-hardened grey for the action. **The walnut is his, untouched**, and so is
  every line of the model's own form.

### DAE - Rigby Hunting Rifle — Martijn Vaes (CC-BY-4.0)

The first-person rifle since task 140 (2026-10-09): its stock, its action, its bolt and its scope.
Karen chose the model herself, *"I think we inaf this one it's already with scope"*.

> This work is based on ["DAE -  Rigby Hunting Rifle - Game Ready Asset"](https://sketchfab.com/3d-models/dae-rigby-hunting-rifle-game-ready-asset-e77855f0c3ea4340a4d67a4ece4b87ac)
> by [Martijn Vaes](https://sketchfab.com/MartijnVaes) licensed under
> [CC-BY-4.0](http://creativecommons.org/licenses/by/4.0/)

The licence's own words, from the `license.txt` shipped with the download: *"license type: CC-BY-4.0
(http://creativecommons.org/licenses/by/4.0/); requirements: Author must be credited. Commercial use
is allowed."*

What was changed, and nothing else was:

- `tools/gltf_split.py` (the `rigby` plan) split the model into four groups -- stock, action, bolt
  and scope -- and aligned them to the game's frame at 4.4 studs over all, the shotgun's own length.
  No vertex was added, moved relative to its neighbours, or removed, except the two anchor triangles
  every group carries at the whole model's corners so that they import at one size and one origin.
- The **lens** (`Lens_Low`, the model's only material-1 node) is **not uploaded at all**: its
  material carries no base colour texture, and a scope lens is a flat glass disc, which the game
  draws from a Roblox part exactly as it draws the shotgun's bore discs.
- `tools/asset_prep.py` (the `model-b` preset, unchanged) shaded it smooth by angle, resized the
  textures to 1024, split the packed occlusion-roughness-metalness map into the two single-channel
  maps Roblox reads, and wrote metalness down to 0.10 with roughness 0.50 for the metal -- the same
  measured correction the shotgun needed, for the same reason (Roblox's environment over a field is
  the sky, and a conductor at metalness 0.98 mirrors it). **Every base colour is the artist's, and
  none was recoloured**: measured off his own atlas, his barrel is RGB(51, 43, 39) and his scope
  RGB(42, 37, 36), which are already dark where the shotgun model's were pale.
- **THREE MAKER'S MARKS WERE PAINTED OUT OF THE ATLAS BEFORE ANYTHING WAS UPLOADED**, and this is a
  trademark matter rather than a look one: CC-BY-4.0 licenses the geometry and the texture, not the
  brands printed on them. The scope's **maker name** (a 20x140-pixel band), its **"Made in Austria"
  line and serial**, its **two bird logos**, and the stock's **gold double-R monogram** are gone --
  the first four replaced by the body colour under them, the monogram cloned over with the walnut
  220 pixels below it. The scope's magnification numerals are generic and were kept. The original
  download is untouched and is proved so by a hash manifest in the task's own request.

### Horn — r4ulp3rcy (CC-BY-4.0)

The beater's signal horn since task 169 (2026-10-13): one natural horn, ivory and curved, with two
pierced silver bands. Karen found the model herself after saying *"We need better horn"*, and gave
the upload OK the same evening: *"Yes, upload it"*. Before it, the horn was nine brass cylinders
built in code (`Horn.pieces`), which is still what a beater carries if the asset will not load.

> This work is based on ["Horn"](https://sketchfab.com/3d-models/horn-c60fda73ef37454a8b49c244af87550c)
> by [r4ulp3rcy](https://sketchfab.com/r4ulp3rcy) licensed under
> [CC-BY-4.0](http://creativecommons.org/licenses/by/4.0/)

The licence's own words, from the `license.txt` shipped with the download: *"license type: CC-BY-4.0
(http://creativecommons.org/licenses/by/4.0/); requirements: Author must be credited. Commercial use
is allowed."*

What was changed, and nothing else was:

- `tools/asset_prep.py` (the new `horn` preset) shaded it smooth by angle at 35 degrees, resized the
  three 2048 maps to 1024, split the packed occlusion-roughness-metalness map into the two
  single-channel maps Roblox reads, and wrote metalness down to 0.10 with roughness 0.50 — the same
  measured correction the shotgun and the rifle needed, for the same reason (Roblox's environment
  over a field is the sky, and a conductor at metalness 0.98 mirrors it).
- The download's **two material slots** (`horn` and `metal`) address **one** set of three images, so
  `tools/asset_prep_blender.py:collapse_materials` merged them into one. No pixel and no face
  changed hands: the two slots were two names for the same material.
- **Every base colour is the artist's and none was recoloured.** His own mark, "R4VL" engraved on a
  band, is his signature on his own work and is left exactly where he put it; nothing was painted
  out of this atlas.
- No vertex was added, moved relative to its neighbours, or removed. The horn's size in the game
  (1.25 studs over all) is set by the consumer at run time from `Horn.MESH.SIZE_STUDS`, not baked
  into the geometry.

### Semi-Automatic Shotgun — PStudio (Fab Standard License)

The semi-automatic shotgun since task 225 (2026-10-20): an MP-153-pattern gas-operated 12 gauge with
a Picatinny rail and a red-dot sight, split by `tools/gltf_split.py` into six groups — the action,
the barrel, the stock, the **bolt** and the **shell lifter**, which are the two groups that move, and
the sight. The package also contains a 12-gauge shell model (a full round and a shorter spent hull),
which is not used yet.

> Semi-automatic shotgun model: *"Semi-Automatic Shotgun"* by **PStudio**, bought on
> [Fab](https://www.fab.com) under the Fab Standard License on 2026-10-20.

The licence permits private use, reproduction, display and modification inside this game, and
forbids distributing the Content on a standalone basis. **The bought files are never committed to
this repository and never redistributed**: the pipeline runs outside it and only the uploaded Roblox
asset ids reach the game.

### Lever action rifle — Jeick (Fab Standard License)

The lever-action rifle since task 224 (2026-10-20): a Ruger-made Marlin 1895 SBL in .45-70, split
into three published MeshParts — the action (receiver, barrel, Picatinny rail with both iron sights,
magazine tube, fore-end, trigger, hammer, breech bolt and loading gate), the stock, and the finger
lever, which is the one group that moves. The package also contains a .45-70 cartridge model, which
this game does not use.

> Lever-action rifle model: *"Lever action rifle"* by **Jeick**, bought on [Fab](https://www.fab.com)
> under the Fab Standard License on 2026-10-20.

The licence grant is the same one the boar is used under, quoted below, and with the same caveat:
**read through a web search, not from the page** — `fab.com/eula` answers 403 to this machine. **The
download itself ships no licence file**, which was checked (the FBX, the OBJ and every entry of
`additional_files.zip`); no tier is claimed here, because none of the records this machine can reach
names one. The two conditions that bear on this repository are met either way: the rifle is a
component of a game that adds its own value, and it is never distributed on a standalone basis — the
binary is never committed (`.rbxm` is banned outright) and what reaches Roblox is three meshes inside
Karen's own account.

### Boar Family — RedDeer (Fab Standard License)

The wild boar since task 115 (2026-10-03): the male's skinned mesh, its three colour maps and the ten
clips it is animated by (idle, walk, trot, run, two turns, two deaths, two flinches). The package also
contains a female and a cub, which this game does not use yet.

> Wild boar models and animations: *"Boar Family"* by **RedDeer**, bought on [Fab](https://www.fab.com)
> under the Fab Standard License on 2026-10-03.

The licence grant, as the Fab EULA states it: *"A "Standard License" grants you a non-exclusive and
non-transferable license to privately use, reproduce, display, perform, and modify the Content in
accordance with the terms of this Agreement. [...] you may not Distribute Content on a standalone
basis to third parties except to your collaborators"*. **Read through a web search on 2026-10-03, not
from the page** — `fab.com/eula` answers 403 to this machine. The two conditions that bear on this
repository are met either way: the boar is a component of a game that adds its own value, and it is
never distributed on its own. The binary is never committed (`.rbxm` is banned outright), and what
reaches Roblox is one asset inside Karen's own account, used by her own place.

What was changed, and nothing else was:

- `tools/boar_prep.py` kept ten of the package's 74 clips, resized the three 4096 maps to 1024 and
  dropped the albedo's alpha channel, shaded the surface smooth by angle, and scaled the whole thing
  so the animal is 5.5 studs long — the length of the physics box it is welded to.
- No vertex was added, moved relative to its neighbours, or removed, and no animation was edited.

### The lobby's free Creator Store models (task 180, 2026-10-14)

The hunting lodge Karen walks out of, the four trucks parked beside it, and the two trophy heads on
its wall. All four are **free** Creator Store models, used in this experience under the Creator Store
terms — which grant use *"in Roblox Studio and in Experiences on the Services"* — and none of them
asks for a credit. **They are credited anyway**, because Karen's instruction for this task was to
credit the creator *"even if not required"*, and because an unattributed free model is the kind of
thing nobody can trace a year later.

Nothing was re-uploaded and nothing was modified: each model is **inserted once into the place in
Studio** and cloned at run time by `ServerScriptService.Lobby.Build`. The only changes the clone makes
are to anchor every part and to strip any script instance (all four shipped with **none** — counted,
not assumed).

| What it is | Model | Creator | Asset | Still used? |
|---|---|---|---|---|
| the lodge | Log Cabin | uhhhh17 | [4746497269](https://create.roblox.com/store/asset/4746497269) | **no, since task 187** |
| the four trucks | PickUp Truck (Prop) | RedWood Roleplay GROUP | [8891351929](https://create.roblox.com/store/asset/8891351929) | yes |
| the stag's head | Deer Head Wall Mount Trophy Decor Home | bell4hd | [101243188132816](https://create.roblox.com/store/asset/101243188132816) | **no, since task 187** |
| the boar's head | Boar Head | Atejime | [15282258007](https://create.roblox.com/store/asset/15282258007) | **no, since task 187** |

**Three of the four were dropped in task 187 and the rows stay**, because a credit is a record of
what was used and when, not a list of what is in the place today. Karen, 2026-10-14, on the free
cabins she was shown: *"all of then garbadge ... you build then one proper europen standart"*, so the
lodge and everything on its walls is built from parts by `Lobby.Build` and no longer clones anything.
The models are still parked in `Workspace.LobbyAssets` in the Forest Test place and nothing reads
them; the reason, and what replaced them, are in
`docs/research/2026-10-14-european-hunting-lodge.md` and
`backups/2026-10-14_task-187_free-lodge.txt`.

The lobby's tree line is cloned from `Workspace.OurForest` — the wood the drive already runs in —
and is credited wherever that pack is credited; it is not a new third-party asset.

There is no `assets/uploads.json` row for any of these, and there should not be: that file is *"one
row per Open Cloud upload"*, and nothing here was uploaded. The route, the measurements and the
rejected alternatives are in `docs/research/2026-10-14-lobby-free-models.md`.

## Sounds

### Deer rut - Brame Cerf — L.Finck (CC0)

The red stag's rut roar since task 254 (2026-10-24): the ambience cue you hear from the far wood in
the first 90 seconds of a drive that carries a stag, and once more at his release (`ForestTest.ROAR`;
both cues go through `ForestTest.roarNow`, so both play a region). Asset **122287696922128**,
*"Driven Hunt red stag rut roar"*.

> ["Deer rut - Brame Cerf"](https://freesound.org/people/L.Finck/sounds/653532/) by
> [L.Finck](https://freesound.org/people/L.Finck/) on Freesound, dedicated to the public domain under
> [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

**CC0 asks for no credit at all, and that is exactly why this entry exists**: a waiver is the one
licence whose terms leave no trace in the repository, so without a line here nothing would record
where the sound came from or that it was checked. It is also the only licence of the five audited
that this project could legally use — Roblox takes a *"fully sublicensable and transferable"* licence
over anything uploaded, which CC BY, CC BY-SA and the commercial library all refuse to grant. The
audit is `docs/research/2026-10-24-stag-voice-and-the-drive-s-length.md` section 2.

What was changed, and nothing else was:

- Nothing in the file. The HQ preview mp3 was uploaded as it was downloaded (52.897 s, 48 kHz; the
  sha256 of exactly those bytes is in `assets/uploads.json`).
- The game plays **three 5-second regions** of it rather than the whole recording, through
  `Sound.PlaybackRegion`, with a 0.35 s fade at each end and a measured per-region gain. The regions
  and the measurement are in `ForestTest.ROAR.clips`.

## Code and libraries

### ProfileStore 1.0.3 — MadStudioRoblox (Apache-2.0)

The save layer behind a player's coins since task 170 (2026-10-13): it loads a profile once per
server, keeps a local copy, auto-saves it, and holds a **session lock** so two servers cannot write
one player's data. Nothing of ours is written around it — no retry loop, no backoff, no
`UpdateAsync`, no auto-save of our own.

> ["ProfileStore"](https://github.com/MadStudioRoblox/ProfileStore) by
> [MadStudioRoblox](https://github.com/MadStudioRoblox), licensed under
> [Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0). Its own description: *"Periodic
> DataStore saving solution with session locking"*.

- **How it arrives:** Wally, pinned exactly — `lm-loleris/profilestore@1.0.3` under
  `[server-dependencies]` in `wally.toml`, resolved into the git-ignored `ServerPackages/` and
  pinned to the commit by `serverpackages.sha256`. Not vendored, not copied, not edited.
- **Where it is in the place:** `ServerStorage.ServerPackages.ProfileStore`, required by exactly one
  function in the repository — `Economy.Store.live` — lazily, and never in Studio.
- **What is NOT modified:** nothing. No fork, no patch, no `ProfileStore.SetConstant`: the auto-save
  period and the session-steal timings are the author's tested defaults.
- **The licence obligation, stated plainly:** Apache-2.0 section 4(a) asks that a copy of the licence
  travel with a distribution. The package's own project file syncs only `ProfileStore.luau`, so the
  published place carries the code and not the notice. This entry is the attribution; shipping the
  licence text with the place is a before-release item, filed with the publish step that already has
  to strip the test code (`TASKS.md` row 2).

Note: `docs/research/2026-10-13-coins-persistence.md`. Design: `docs/design/economy.md`.

### TestEZ 0.4.1 — Roblox (Apache-2.0)

The test framework every spec in `tests/` is written against, and the thing that counts the passes
in every harness report. A **dev** dependency: `roblox/testez@0.4.1` under `[dev-dependencies]`,
resolved into the git-ignored `DevPackages/` and pinned to the commit by `devpackages.sha256`.
Upstream is archived; the version is pinned exactly for that reason.

> ["TestEZ"](https://github.com/Roblox/testez) by [Roblox](https://github.com/Roblox), licensed under
> [Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0).

## Everything else

The rest of the art in this game is Karen's own — generated in her own paid Meshy account or built
from this repository's own geometry — and is recorded in `assets/uploads.json` with her upload
approval, verbatim, for each asset.
