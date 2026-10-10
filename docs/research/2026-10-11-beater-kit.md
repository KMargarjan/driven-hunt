# The beater kit: one outfit for both roles, and what a beater carries

2026-10-11, for Task 151 (the outfit) and Task 152 (the horn). Karen, 2026-10-10 ~18:20:

> *"we need to focus I think next to beaters / we need to make outfit (we can buy or find online)
> orange west heat hunting pens / then we need to make tool for beater, horn, signal, something that
> they can walk and make sound for spook / then we can test other steps like scoring ect / hunter
> part is good for now"*

and at ~22:00, with a crop of her own first-person sleeve as the colour reference:

> *"we need same color by default what is our arms not gloves but arms green or whatever color is so
> all clothe is that color / then orange vest and orange hat"*

and at ~22:10:

> *"for horn you can use hon from free library roblox / for hat and vest same / so horn will be
> default tool for beater"*

Her design doc "Driven Hunt v1" is the specification both roles are built to:

> *"Hunter will have default green pens and jacket / Also will have orange hat / Beater will have
> orange hat and orange vest / Default also green pans and green jacket"*

The Director's scope cut (2026-10-11) splits this: **Task 151 is the outfit for both roles**, plus the
minimum needed to see a beater in the Forest Test. **Task 152 is the horn.** Sections 2, 3 and 4 below
settle 151. Section 5 is 152's head start, and it is written because the free-library route Karen
named turns out to be partly shut, which 152 should not have to discover for itself.

---

## 1. What the system must do

| Must | Why, in Karen's words |
|---|---|
| **Everyone** wears a jacket and trousers in the colour of the first-person sleeve | *"we need same color by default what is our arms ... so all clothe is that color"* |
| A **hunter** adds an orange hat | the doc: *"Also will have orange hat"* |
| A **beater** adds an orange hat **and** an orange vest | the doc: *"Beater will have orange hat and orange vest"* |
| The colour **matches**, not approximates | *"same color by default what is our arms"*; the Director: a catalog jacket in "some green" is not acceptable |
| No upload, no Robux | *"we can buy or find online"*, cut by the Director to the free library only |
| Karen can **see a beater** in the Forest Test, which has no beaters | she tests alone in that place |

Out of this task, named so they are not forgotten: the beater line and the countdown, the compass that
points at the hunters' line, money per drive, the weapon licence, and using a weapon to spook. Each is
in Karen's doc and each is its own task.

---

## 2. How a driven-hunt beater really dresses -- three sources

1. **UVV Jagd section 4 para 12 (the German hunting accident-prevention rules), as summarised by
   [alljagd's Signal- & Warnkleidung page](https://www.alljagd.de/signal-warnkleidung).** A warning
   vest is **mandatory** on a group hunt. For beaters it names *"yellow rain clothing or chest bands
   in orange-red signal colours"* as acceptable, and is explicit that beaters, shooters **and dogs**
   must stand out from their surroundings. Regulatory text, not a maintained artefact: cited for what
   the clothing has to achieve, not for a number.
2. **[jagdjuenger.de, "Drueckjagd-Ausruestung fuer Schuetzen, Hundefuehrer, Treiber"](https://www.jagdjuenger.de/ausruestung/drueckjagd-ausruestung/).**
   The strongest statement of the three and the one this outfit follows: *"an orange arm or hat band
   is definitely not sufficient; at least a clearly recognisable warning vest must be worn, and even
   better in combination with a signal-coloured cap."* So **vest + cap**, which is exactly the pair
   Karen's doc asks for. It also lists the beater's kit as a warning jacket **or** vest, warning
   trousers or signal overalls, and a signal-coloured cap.
3. **[livingactive.de, "Als Treiber auf der Drueckjagd"](https://www.livingactive.de/blog/als-treiber-auf-der-drueckjagd-unsere-empfehlungen/).**
   A beater's own equipment list: *"conspicuous, weatherproof and thorn-proof clothing in orange (at
   least jacket, trousers and cap)"*, sturdy boots, thorn-proof gloves. A retailer's blog, so its
   interest is selling clothes: cited for the **composition** of the kit, which all three agree on.

North American practice is the control case: [Texas Parks & Wildlife's blaze-orange
law](https://tpwd.texas.gov/education/hunter-education/blaze-orange-laws) requires **400 square inches
of hunter orange plus orange headgear, with at least 144 square inches on the chest and 144 on the
back**. A different jurisdiction arrives at the same shape -- a torso panel visible front and back,
plus a hat.

**What this settles for the game.** The real kit is *base clothing* + *orange torso panel* + *orange
headgear*; the panel is visible **front and back**; headgear alone is explicitly not enough. Our
existing vest is four plates, one per horizontal face of the torso (Task 82, built after Karen could
not see a single-plate vest at all). Texas's 144 in² front **and** 144 in² back is independent support
for that shape, arrived at for the same reason -- a beater is looked at from every side.

**What it does not settle:** whether the *hunter* also wears orange trousers. Source 3 says a beater's
trousers should be orange; Karen's doc says both roles wear **green** trousers and the orange is the
hat and the vest. **Karen's doc wins** -- it is the game's design, the sources are the field's
practice, and the one is allowed to differ from the other. Recorded here so nobody later "fixes" it.

---

## 3. The colour, MEASURED off the sleeve texture

Karen's reference is her own screen: the first-person sleeve. The Director sampled her screenshot at
about **RGB(105, 100, 78)** and asked for the true base colour to be read off the mesh's own texture
instead, because a screenshot is lit.

The sleeve is part of the two glove models (`gun.hand.right`, `gun.hand.left` in
`src/serverstorage/Assets`): *"Brown leather glove, olive jacket cuff"*. Their prepped base-colour maps
are the albedo Roblox samples. Measured 2026-10-11 over every used pixel of both 1024x1024
`texture_baseColor.png` files, classifying by hue and keeping hue 35-100 degrees at saturation > 0.08
(the olive cuff; the rest of each map is hue 0-35, the brown leather):

| Map | Olive pixels | Median RGB | Mean RGB |
|---|---|---|---|
| `glove_right_v4_r1` | 267,953 | **(74, 67, 47)** | (74.9, 68.2, 47.8) |
| `glove_left_v4_r1` | 265,739 | **(96, 92, 65)** | (98.3, 94.2, 66.7) |
| **both together** | 533,692 | **(86, 80, 56)** | (86.6, 81.2, 57.2) |

**The two gloves do not agree**, and that is a fact about the assets rather than a measurement error:
they were generated separately in Meshy and the left one's cuff is a third brighter. Neither is "the"
sleeve, so the adopted number is the **median over both**, weighted by pixel count as the table shows:

> **`OUTFIT_BASE_COLOR = Color3.fromRGB(86, 80, 56)`** -- a muted olive.

It agrees with the Director's lit sample in the only way it can: the albedo (86, 80, 56) is darker than
the lit frame (105, 100, 78), because the frame has the viewmodel's own light on it. Matching the
**albedo** is the right target -- under the same light, a surface with the sleeve's albedo renders as
the sleeve. One line to change if Karen's eye disagrees.

---

## 4. How to put green clothing on a Roblox character -- three routes, and what the catalog actually has

### 4.1 The three routes

1. **`HumanoidDescription` + `Humanoid:ApplyDescription`.** Roblox's own
   [Character appearance page](https://github.com/Roblox/creator-docs/blob/main/content/en-us/characters/appearance.md)
   (fetched 2026-10-11): *"You can programmatically modify a Humanoid by updating
   HumanoidDescription"* -- scales, accessories, clothing, body parts, colours and animations, applied
   **atomically**, with `SetAccessories()` for *"layered or bulk accessory changes"*. The
   [DevForum thread on applying it client-side](https://devforum.roblox.com/t/applying-humanoid-clothingetc-on-the-client-end/287003)
   records the constraint that matters: it must run on the **server**, or the look is right only for
   the one player who applied it. Against it, for *this* module: `ApplyDescription` **rebuilds the
   character's parts**, and `Match.Body` welds plates to `UpperTorso` and anchors a punished player's
   root to a tree. A call that can replace the limb a `WeldConstraint` is anchored to is the wrong
   instrument for the module whose other job is holding things onto limbs. The page also notes scaling
   *"doesn't affect R6 body types"*.
2. **`BodyColors` written directly.** Roblox's
   [BodyColors reference](https://create.roblox.com/docs/reference/engine/classes/BodyColors) (fetched
   2026-10-11) is six properties and nothing else: `HeadColor3`, `TorsoColor3`, `LeftArmColor3`,
   `RightArmColor3`, `LeftLegColor3`, `RightLegColor3`. The
   [DevForum thread on changing body colours on the server](https://devforum.roblox.com/t/changing-body-colors-on-the-server/751923)
   is the pattern: find or create the character's `BodyColors` and write the properties. It touches
   **no part** -- it replaces no limb, breaks no weld, and does not yield.
3. **A classic `Shirt`/`Pants` texture, or a catalog `JacketAccessory`.** A classic shirt in exactly
   RGB(86, 80, 56) means **uploading** an image, which this task may not do. A catalog jacket is
   somebody else's colour and cannot be made to match -- which is the requirement Karen stated twice.

**Adopted: route 2.** It is the only one that gets the colour exactly right with no upload, and the
only one that cannot disturb the welds and the tie `Match.Body` already owns. The green jacket and
trousers are the character's **torso, arms and legs** painted the sleeve's olive; the head keeps the
player's own colour, so it reads as a person in a green outfit rather than as a green person.

**What route 2 needs beside it.** A `BodyColors` write is invisible under anything drawn on top of the
limb, so the outfit must also clear the player's own `Shirt`, `Pants` and `ShirtGraphic`, and any
**layered-clothing** accessory. The appearance page is why layered clothing has to be named separately:
*"Layered accessories can work with both standard player characters and non-R15 models"* when they
carry `WrapTarget`/`WrapLayer` -- that is, they are a mesh standing off the limb's own surface rather
than a texture on it, so no colour written to the limb can show through one. Head accessories and hair
are **left alone**: nothing in Karen's doc asks for them to go, and the hat was designed to clear a
default avatar's hair in Task 77.

### 4.2 The catalog items the dispatch named are NOT free, and nothing free fits -- measured

The dispatch asked for the catalog item *"High Vis Vest Orange"* (99269365249885, RP UGC) through
`HumanoidDescription`, an orange catalog cap, and to *"check each id loads and is public"*. Checked
2026-10-11 with `MarketplaceService:GetProductInfo` and `InsertService:LoadAsset` in the DEV place:

| Id | Name | Creator | Price | `IsPublicDomain` | `LoadAsset` |
|---|---|---|---|---|---|
| 99269365249885 | High Vis Vest Orange | RP UGC | **50 R$** | **false** | loads: one `Accessory`, `MeshPart` handle 2.08 x 1.90 x 1.11, `BodyFrontAttachment`, **no scripts** |
| 1043468 | Hunting Hat | Roblox | **99 R$** | **false** | loads: `Accessory` "RobinHood", `HatAttachment`, no scripts |
| 6037258153 | Hunting Cap | GuestCapone | **90 R$** | **false** | loads: `Accessory` **"Hunting Cap [Red]"** -- it is red, not orange |

All three are **paid** and none is public domain. The free pool was then searched directly, with
`AvatarEditorService:SearchCatalog` and `CatalogSearchParams.MaxPrice = 0`, over six keywords -- *high
vis vest*, *safety vest*, *hunting vest*, *orange cap*, *orange beanie*, *hunter orange hat*. **No free
blaze-orange hi-vis vest and no free orange hunting cap exist in it.** What comes back is unrelated
UGC: OCSO police vests, military camo vests, a Taro life vest, an adidas crop top, beanies in brown,
grey and green, an *Orange Safari Hat*, a *Mushroom Hat - Soft Orange*. The lists are in the task's
review request.

**Conclusion, and it is the dispatch's own fallback promoted to the lead: the orange hat and the orange
vest stay the parts the repo already builds** (`Match.Body`'s `OUTFITS`). They cost nothing, they are
already the right orange, Karen has seen the hat read as a hat, and the four-plate vest exists because
she could not see the single-plate one (PLAYTEST.md, 2026-09-27). Buying the 50 R$ vest is **Karen's**
decision, not the Builder's; when she makes it, the row above is the id and the measurement.

One more reason to prefer parts here, which the measurement in section 5.2 makes concrete: a catalog
accessory is a **mesh somebody else can take down**. A grey-box part cannot stop loading.

---

## 5. Task 152's head start: what a beater carries, and what the free library will actually give us

### 5.1 What a real beater uses to make noise -- three sources

1. **[jagdjuenger.de](https://www.jagdjuenger.de/ausruestung/drueckjagd-ausruestung/)**, again: the
   beater's list includes a *Signalgeber* -- *"Pfeife, Horn oder Rassel"* (whistle, horn or rattle).
2. **[livingactive.de](https://www.livingactive.de/blog/als-treiber-auf-der-drueckjagd-unsere-empfehlungen/)**:
   signal devices such as a whistle, rattle and signal horn are the beater's tools, *"which make noise
   and keep the game moving"* -- the function stated plainly, and it is exactly the mechanic Karen
   asked for.
3. **[The wildundhund.de forum thread "Laerminstrumente fuer Treiber"](https://forum.wildundhund.de/threads/laerminstrumente-fuer-treiber.118997/)**
   -- hunters arguing about which noise-maker to carry. A forum, so no authority: cited as evidence
   that the **set** is whistle / rattle / horn / voice, and that practitioners disagree about which,
   which is why the tool should be one row of data rather than a hard-coded horn.
   [Oldenburger Jagdcenter](https://www.oldenburger-jagdcenter.de/Ausruestung/Diverses-Jagdzubehoer/Jagd-Signalhorn-aus-Messing.html)
   sells the object itself: a **polished-brass signal horn**, standard kit for driven hunts and easy
   for the unpractised to blow. That is the shape and the material to build.

So Karen's **horn** is the right pick, and the alternatives (whistle, rattle) are the same mechanic with
a different sound id. One tool, one row per noise-maker.

### 5.2 The free-library model route is MEASURED SHUT; the sound route is open

Karen: *"for horn you can use hon from free library roblox"*. Measured 2026-10-11:

* **The avatar catalog has no horn at all.** `SearchCatalog` at `MaxPrice = 0` for *hunting horn*,
  *bugle*, *air horn* and *whistle* returns only back-accessory devil and demon horns and a horned
  sword.
* **Free Creator Store horn MODELS refuse to load.** The two plausible ones -- **"The FIRST Bugle!"**
  (33685172, blobyray, `IsPublicDomain: true`) and **"horn"** (5454407759, ilove_oxygen, public) --
  both answer `InsertService:LoadAsset` with **`"User is not authorized to access Asset."`** in the
  DEV place. A model marked public in the store is not therefore loadable by this place's owner. For
  contrast, the paid *accessories* in section 4.2 all loaded: accessories and models do not travel the
  same road.
* Everything else a model search for *horn* returns is a devil horn, a unicorn horn, a train horn or a
  car-horn script.

**So the horn's geometry should be built from parts**, the way Task 99 built the shotgun's metal and for
the reason recorded there: a Roblox `Cylinder` is analytically round, parts are numbers a Director can
tune live and a Reviewer can read in a diff, and there is no upload round trip. A brass signal horn is a
tapered tube and a flared bell -- a short stack of cylinders with a cone at the end. 152 should confirm
this against the model route itself rather than trusting this paragraph.

**The horn's VOICE is available and licensed.** Searched through Roblox's own audio search endpoint and
verified by name and creator through the public asset-details endpoint -- the procedure Task 142 used
for the rifle:

| Candidate | Id | Name, creator | Record |
|---|---|---|---|
| **the horn** | `9038902877` | **"Hunting Horn"**, APMOfficial -- *"Upbeat French horn signal. Authentic vintage vinyl recording (60s). Newly remastered."* | `IsPublicDomain: true`, asset type 3 |
| a whistle | `9120675895` | "Whistle Calling 4 (SFX)", ProSoundEffects -- *"Whistle, CU, 'Calling', Airy, Light Lip Smacking"*, 1.0 s | `IsPublicDomain: true` |
| (rejected) | `9114075901` | "Diesel Truck Horn Air Horn Exterior 3 (SFX)", ProSoundEffects | a truck, not a hunt |

**Not yet measured, and 152 must do it:** that `9038902877` loads in the place with
`ContentProvider:PreloadAsync`, and its `TimeLength` -- the `cut`/`fade` numbers cannot be chosen
without it. And **nobody here has heard it.** Karen's ears decide, and it is one line.

### 5.3 The spook, for 152

Karen's *"something that they can walk and make sound for spook"* needs **no new boar rule**. The
behaviour note ([2026-10-04-boar-behaviour.md](2026-10-04-boar-behaviour.md)) already gives the Brain a
per-stimulus notice and flush radius, and a shot that is *"a sound, not a hit"* delivered through
`runtime:hearShot`. A horn blast is the same shape: a position, a radius and a loudness, through the
stimulus path that exists. 152 should reuse it and must not add a second panic rule -- and the stimulus
must be **real**, from the beater's own position, never a phantom.

---

## 6. Numeric targets

| Thing | Value | Where it came from |
|---|---|---|
| base clothing colour | **RGB(86, 80, 56)** | median of both sleeve albedo maps, section 3 |
| hunter | base + orange hat | Karen's doc |
| beater | base + orange hat + orange vest | Karen's doc |
| orange | RGB(255, 112, 0) | unchanged, `Match.Body`'s existing `OUTFIT_COLOR` |
| vest plates | 4, one per horizontal face | Task 82, and Texas's 144 in² front **and** back |
| head, hair and the player's own hats | untouched | nothing asks for them, and the hat clears hair (Task 77) |
| horn sound (152) | `rbxassetid://9038902877` | section 5.2, licensed, not yet load-measured |

---

## 7. What is explicitly NOT in Task 151

* **The horn** -- Task 152, with section 5 as its head start.
* **The compass** pointing a beater at the hunters' line -- later, per the Director's cut.
* **The beater line and the countdown**, money per drive, the weapon licence, spooking with a weapon --
  all in Karen's doc, all their own tasks.
* **Buying the 50 R$ catalog vest** -- Karen's call; section 4.2 is the measurement she would need.
* **A classic Shirt/Pants upload** -- it would match exactly, it needs an upload OK, and route 2 gets
  the same colour without one.
