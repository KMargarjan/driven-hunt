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

## Everything else

The rest of the art in this game is Karen's own — generated in her own paid Meshy account or built
from this repository's own geometry — and is recorded in `assets/uploads.json` with her upload
approval, verbatim, for each asset.
