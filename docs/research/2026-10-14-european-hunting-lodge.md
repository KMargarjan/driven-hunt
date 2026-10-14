# A Central-European hunting lodge, built from parts

2026-10-14, task 187. Written before the code, per CLAUDE.md rule 1.

Karen, 2026-10-14 ~21:30-21:35, verbatim:

> then we need to find normal house ... I need hunting house where will be fireplace table on walls
> animal antlers ect like hunting cabin

and, on the free Creator Store cabins she was shown:

> all of then garbadge

> you build then one proper europen standart

and earlier the same day (~17:00), on what task 180 shipped:

> house is broken person inside broken

---

## 1. What the system must do

1. Put **one** hunting lodge in the lobby at (2850, −2950) in the Forest Test place, and have it
   look **designed** — a Central-European *Jagdhaus*, not a grey box and not an American log cabin.
2. Keep everything the lodge already carries working: the walk-in door, the shop counter, the
   shopkeeper and his `ProximityPrompt` (task 181), the trophies on the walls, the warm inside.
3. Fix *"person inside broken"*.
4. Build the same lodge **in every place**, including the DEV place, which has never had a free
   Creator Store model inserted — the harness runs there.
5. Stay inside a part budget somebody can read (the Director's ceiling for this task: 1,500 for the
   whole lobby).
6. Leave the 177/180 road, fields and forest and 182's trucks and pads **unchanged**.

### What it must not do

* Put a Script, LocalScript or ModuleScript anywhere (CLAUDE.md; the harness fails on one).
* Commit a `.rbxm` (banned).
* Need a mesh, a union or an upload: **parts and Roblox materials only** (the task's own words).

---

## 2. Why the free model goes, and what replaces it (rule 2: borrow before building)

Task 180 cloned **"Log Cabin" by uhhhh17** (Creator Store 4746497269, free, 266 parts, script-free)
and task 187 removes it. The reason is not that the clone failed — it worked exactly as that task's
note describes — it is that **the owner of the game looked at it and rejected it**, and the three
alternatives she was shown with it. That is the one judgement this project does not get to overrule
(`docs/PROJECT_CONTEXT.md`: Karen decides anything about feel or design).

Rule 2 asks for a written reason before inventing. It is this, in three parts:

1. **There is nothing left to borrow.** The free Creator Store cabins are American/rustic log cabins
   (shallow roofs, railings, no plinth, no shutters, no chimney) and the owner has judged the
   available ones garbage. A paid model is not a route this task has (no purchase, and the licence
   question task 180's note settles only for free assets).
2. **What a lodge is, IS borrowed** — the FORM comes from the sources in section 3 and not from
   taste; only the arithmetic is ours.
3. **The repository already builds this way.** Task 177's parts lodge, `Weapon.Hardware`'s gun and
   `MapGen.Props` are all parts-in-code, for the reason given in `2026-09-26-shotgun-model.md`: a
   part build is reviewable in a diff, and a binary is not.

The **truck** and the **trees** stay free models: Karen has looked at both and kept them. The two
trophy HEADS go with the cabin — a 5.4-stud tan deer head measured next to a 2.4-stud shield reads
as a toy, and one look for the whole wall beats a mixed set.

---

## 3. Sources: what a *Jagdhaus* is made of

| # | Source | Licence / status | What it gives |
|---|---|---|---|
| 1 | [Wikipedia, *Log cabin*](https://en.wikipedia.org/wiki/Log_cabin) | CC BY-SA 4.0, actively maintained | corner notching, the purlin roof, split shingles |
| 2 | [Google Arts & Culture / Bayern Tourismus, *Log cabins in Upper Bavaria*](https://artsandculture.google.com/story/log-cabins-in-upper-bavaria-bayern-tourismus-marketing/UwUh28ERE7P1Dw) (Freilichtmuseum Glentleiten) | publisher-hosted editorial, live | **projecting corner ends**, the projection length, spruce/fir, moss chinking |
| 3 | [Wikipedia, *Jagdschloss*](https://en.wikipedia.org/wiki/Jagdschloss) | CC BY-SA 4.0, actively maintained | the vocabulary: *Jagdhaus* (permanent, masonry or wooden) vs *Jagdhütte* (simple, remote); simple lodges "mostly constructed with timber framing" |
| 4 | A measured roe-deer *Trophäenschild* ([listing](https://www.arezzona.com/product/96892/Vintage-Roe-Deer-Antler-Mount-on-Wooden-Plaque-Rustic-Cabin-Wall-Hunting-Decor), and the Etsy market page for the same object) | commercial listing, live | **the proportion**: plaque 22 cm × 10 cm carrying 10.5 cm of antler |
| 5 | [Roblox `Fire`](https://create.roblox.com/docs/reference/engine/classes/Fire), [`ParticleEmitter`](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter), [`PointLight`](https://create.roblox.com/docs/reference/engine/classes/PointLight) | first-party docs, live | the fire: `Size`, `Heat`, `Color`, `SecondaryColor` on `Fire`; the emitter for embers; one light |

### What each is good and bad for

* **Source 1** is the only one of the three architecture sources that is both precise and stable, and
  it is **American-centred**: it gives notching and purlin roofs but says nothing about plinths,
  shutters or chimneys, and the fetch returned nothing on log diameters. Used for the corner, not
  for the silhouette.
* **Source 2** is the one that names the detail this build turns on — *"corners with protruding beam
  ends, called projections ... the projection cuts in logs are made around 15 to 20 cm from the end
  of the block"* — and it is Alpine, which is the right region. It is editorial rather than
  scholarly, and **a second fetch of the same page for roof overhang, shingles and shutters returned
  nothing**: recorded as a negative result, and those three are taken from source 3's "timber
  framing" plus ordinary observation, not asserted as sourced.
* **Source 3** fixes the vocabulary and the class of building (a *Jagdhaus* is permanent and may be
  masonry or wood) but is about aristocratic *Jagdschlösser*, which this is not.
* **Source 4** is a shop listing, which is weak evidence about history and **exact** evidence about
  proportion, which is all it is used for: 22 : 10 is the shield, and the antlers are about half the
  shield's height again.
* **Source 5** is first-party and current. `Fire`'s page documents `Size`, `Heat`, `Color`,
  `SecondaryColor` and `Enabled` and says nothing about preferring a `ParticleEmitter`; both are used
  here, the `Fire` for the flame and the emitter for embers it does not throw.

### The pattern adopted

**The building is a list of named pieces, each one of them a thing one of those sources names**, and
every dimension is a row in `Lobby.CONFIG.LODGE`:

| Piece | Why it is there |
|---|---|
| stone **plinth**, sunk 2 studs into the ground | a lodge's sills never touch the earth (source 3, "masonry or wooden"); and task 186 measured Roblox terrain up to a stud below the nominal shelf on this very yard — a building cannot be settled per wheel, so it is given a base no eye can find the bottom of |
| horizontal **log courses**, 1.8 studs (≈50 cm) | source 1 |
| **projecting corner ends**, 0.9 studs (≈25 cm), turned a quarter turn each course | source 2, and it is what makes the corner read as notched rather than butted |
| steep **gabled roof**, 44°, eaves 3.4 studs, gables 2.2, exposed **rafter ends** | Alpine rather than American: the deep overhang is most of the silhouette |
| stone **chimney** up the west gable, outside | no hole to cut in the roof, and the fireplace inside stands on the same wall |
| **windows** cut as holes, with frame, muntins, sill and **shutters** carrying a cut-out | the shutter and its carved motif are the Central-European marker; a part cannot have a hole in it, so the motif is a darker piece laid on the leaf, which is what a painted shutter is anyway |
| covered **porch**: deck, stone steps, posts with knee brackets, lean-to roof, bench, **woodpile** | the entrance Karen arrives at |
| **antlers over the door**, on the gable | Karen's own word, task 177 |
| inside: **fireplace** with mantel and a real fire, heavy **table** and benches, **beamed ceiling**, plank floor, shop **counter**, **gun rack**, three lanterns | Karen's list, verbatim |
| **trophy rows**: twelve mounts — nine roe shields, a boar's tusk plate, a red stag over the fire | source 4's proportion, repeated. The rows are the classic German wall |

---

## 4. The numeric targets

| Target | Value | Why |
|---|---|---|
| footprint | 36 × 26 studs | SMALLER than task 177's 40 × 28, so every clearance the pads and fences were computed against only widens |
| room | 32.4 × 22.4 × 12.6 | the task asked for ≥ 14 × 10 walkable. The HEIGHT is arithmetic, not taste: a stag mount is 3.2 studs of shield and four of antler and hangs over a mantel five studs up, which an 11-stud room cannot hold |
| ridge | 28 studs over the shelf → 44° | source 2's region; `FIELD.CLEAR_STUDS` (96) still clears it |
| floor above the yard | 2.8 studs, reached by 3 stone steps | each rise under a stud, so the engine walks a player up without a jump |
| door | 7 × 9 studs, a GAP | Karen: *"a door you walk through"* |
| parts | lodge ≈ 420, whole lobby ≈ 885 | budget raised 1200 → **1500** (the Director's ceiling), with the arithmetic in `Lobby.CONFIG.MAX_PARTS` |
| lights | 1 fire + 3 lanterns inside + 2 on the porch | written once each, at build; nothing in this lodge is animated by a script |

---

## 5. "Person inside broken", measured

Probed in Karen's own place, 2026-10-14, before anything was changed:

```
keeper root=2853.4,155.5,-2890.8  shirt=none  accessories=0
  UpperTorso color=86,80,56        <- the hunter green, correct
  Head       color=0,0,0           <- SOLID BLACK, and no face
```

The outfit owner is **right** and was not changed: `Match.Body.paint` writes the five R6 limb stems
and deliberately never `HeadColor3` — *"the head is the player's own"* (design M5). That is correct
for a player and leaves a man built from an **empty** `HumanoidDescription` with the head such a
description ships: black, featureless. He is not a player and has no appearance of his own, so the
LODGE gives him one — a skin tone on every `BodyColors` he carries, and Roblox's own
`rbxasset://textures/face.png`, which is an engine asset and not an upload.

The other half of *"house is broken"* was the free cabin's room (19.6 × 19.6 × 7.4) holding furniture
measured for task 177's (38 × 26 × 9): a 12-stud counter in a 9.8-stud half-room, a table through the
wall, a chimney at the ceiling. One lodge, one set of measurements, and that class of bug is gone.

---

## 6. Two things the photographs caught that no amount of arithmetic would have

Both are recorded because rule 5 exists for exactly this reason.

1. **The house had no door and no windows at all.** An opening is written in the config as studs from
   the lodge's own middle; a wall run is built in world coordinates. `11 ± 2.5` overlaps nothing in
   `x 2833.8 … 2866.2`, so every course was built whole. **The spec did not see it**: the suite
   anchors at (0, 100, 0), where the two frames of reference are the same number. The fix is one
   conversion at the one place the rows are read; the new case builds a lodge at Karen's own
   x = 2850 and asserts no `Wall*` part contains the middle of any opening.
2. **The porch roof was inside the main roof.** Hung at the wall top — where a porch roof obviously
   goes — it was above and behind the main eave, which oversails the wall by 3.4 studs at 44° and is
   therefore already 3.3 studs lower. It is now hung off the point the main eave ENDS, and the posts
   are shorter than that point (at 8.5 studs the lean-to ran uphill).

Also from the photographs, and fixed: the fire was a white blob (a `Fire` of size 7 on a firebox-wide
neon slab), the antlers were white twigs on a wall the same colour as their shields, the porch
brackets read as arrowheads, the logs photographed almost pink, and the SHOP sign faced into the
logs — a `SurfaceGui`'s `Front` is the part's own −Z, so the half turn that "pointed it at the room"
turned it away from it.
