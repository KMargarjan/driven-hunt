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
