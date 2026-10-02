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

What was changed, and nothing else was: `tools/gltf_split.py` split the model into its two hinge
groups and its shell and aligned them to the game's frame; `tools/asset_prep.py` (the `model-b`
preset) shaded it smooth by angle, resized the textures to 1024 and split the packed
occlusion-roughness-metalness map into the two single-channel maps Roblox reads. No pixel was
recoloured and no shine number was written.

## Everything else

The rest of the art in this game is Karen's own — generated in her own paid Meshy account or built
from this repository's own geometry — and is recorded in `assets/uploads.json` with her upload
approval, verbatim, for each asset.
