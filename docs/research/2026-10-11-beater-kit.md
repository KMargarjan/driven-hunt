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
| No upload, no Robux | *"we can buy or find online"*; the Director's cut is the Roblox library, worn by the experience |
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

### 4.2 The catalog accessories ARE usable, and round 1 said the opposite -- the correction

**ROUND 1 OF THIS NOTE WAS WRONG, and the error was mine.** It measured the three candidate catalog
items, read `PriceInRobux: 50` and `IsPublicDomain: false`, and concluded that the catalog route was
"measured shut". The measurements were right; **the conclusion drawn from them was not**, and the
Director corrected it on 2026-10-11:

> A catalog item's price is what a **player** pays to **own** it on their own avatar. An experience
> may put **any** public catalog accessory on characters at no cost to anyone -- that is how every
> try-on and outfit game works. The vest LOADS, one Accessory, no scripts. So it IS usable for free,
> which is exactly what Karen asked for.

That is right, and round 1's own evidence already showed it: the vest and both hats **loaded** when
`InsertService:LoadAsset` was called on them. `IsPublicDomain` means *free to take onto an avatar*,
not *usable by an experience*; I read it as the second. Nothing about the earlier numbers changes --
only what they mean.

**So the catalog route is the LEAD, and the grey-box plates are the fallback.**

| Id | Name | Creator | Price to a player | `LoadAsset` in the DEV place, 2026-10-11 |
|---|---|---|---|---|
| **99269365249885** | **High Vis Vest Orange** | RP UGC | 50 R$ | one `Accessory`, `MeshPart` handle 2.08 x 1.90 x 1.11, `BodyFrontAttachment`, **no scripts** |
| **13724841516** | **Orange Cap** | dvdko | 90 R$ | one `Accessory`, `MeshPart` handle 2.01 x 0.93 x 1.43, `HatAttachment`, **no scripts** |
| 1043468 | Hunting Hat | Roblox | 99 R$ | loads; it is the "RobinHood" hat, not a cap |
| 6037258153 | Hunting Cap | GuestCapone | 90 R$ | loads, and its own accessory is named **"Hunting Cap [Red]"** -- it is red |

**The cap was chosen by measurement, after the first attempt picked a black one.** This is worth
reading, because the first method looked rigorous and was not:

* **What I did first, and why it was wrong.** Ten candidates were loaded, their *handles* floated in
  one row, the row was photographed once, and each cap's colour was read from pixels at an x
  coordinate I had *computed by assuming* where each cap landed in the frame. That picked
  `6202417448` "Orange Trendy Cap" on a reading of (201, 94, 0). Put on an actual character it
  rendered **black with an orange trim**. Two separate mistakes: a pixel sample at a guessed
  coordinate is not a measurement, and **a handle in a row is not a hat on a head.**
* **What settles it.** Each candidate alone, at the same place, on one fixed camera, measured over
  the whole silhouette -- with a **dark fraction** beside the colour, which is the number that
  catches a black cap with an orange logo:

| Id | Name, creator | Median RGB | Saturation | Green/red | Dark fraction |
|---|---|---|---|---|---|
| **13724841516** | **"Orange Cap", dvdko** | **(203, 97, 1)** | **0.995** | **0.478** | **0.000** |
| 72426675841683 | "Orange Cap", Bellzko | (207, 78, 3) | 0.986 | 0.377 | 0.001 |
| 88028893591722 | "Worn Orange Beanie", BRNCO | (179, 91, 1) | 0.994 | 0.508 | **0.201** |
| 14295768399 | "Simple Beanie - Orange", jdoggL | (214, 142, 33) | 0.846 | 0.664 | 0.000 |
| 15507366160 | "P Baseball Cap - Orange", Verifly | (201, 137, 61) | 0.697 | 0.682 | 0.009 |
| 4962838235 | "Orange Cap", Ellzd | (213, 151, 65) | 0.695 | 0.709 | 0.000 |
| 13655567248 | "Cap Orange", HulaHoopman6 | (206, 141, 80) | 0.612 | 0.684 | 0.000 |
| 138991964289771 | "Orange Cap", Classic Limiteds | (181, 138, 72) | 0.602 | 0.762 | 0.052 |
| **6202417448** | "Orange Trendy Cap", Ellzd -- **the wrong first pick** | (194, 147, 98) | **0.495** | **0.758** | 0.000 |
| 12326959807 | "Orange Beanie", wonderforge | (69, 17, 0) | 1.000 | 0.246 | **0.719** |

`OUTFIT_COLOR` (255, 112, 0) is green/red **0.439** at saturation 1.0, so **`13724841516` is the
closest fully saturated cap with no dark area at all** -- and looking at it
(`<runs-dir>/151-caps/cap-13724841516.png`) confirms it: a solid blaze-orange baseball cap with a
curved peak and no branding, which is what a hunter wears. Bellzko's is redder (0.377); the beanies
are either a fifth black or a dark burnt orange.

**The vest wraps, so no back plate is needed under it.** The Director asked specifically, because
Karen once could not see a single-plate vest at all (PLAYTEST.md, 2026-09-27). Rendered on a
stand-in torso in the base green, front and back, and inspected
(`<runs-dir>/151-vest-check.png`): the **back is a plain orange panel with a reflective band** and
the front has the V-neck, the zip and two bands. Both sides are orange.

**What the free-pool search in round 1 still tells us, and it is no longer a blocker:**
`AvatarEditorService:SearchCatalog` with `MaxPrice = 0` over *high vis vest*, *safety vest*,
*hunting vest*, *orange cap*, *orange beanie* and *hunter orange hat* returns no blaze-orange hi-vis
vest and no orange hunting cap. That is now only a fact about the **free** pool, which this project
has no reason to restrict itself to.

**The plates are KEPT as the fallback, and that is not hedging.** A catalog accessory is a mesh that
belongs to somebody else: it can be taken down, moderated, or simply fail to load inside
`Loader.CONFIG.LOAD_TIMEOUT_S`. `Match.Body` wears the accessory when one is available and builds
the Task 77 hat and the Task 82 four-plate vest when it is not -- a known-good picture Karen has
already seen read on a player, rather than a bare character. `Body.accessoriesWorn()` and
`Body.slotsFellBack()` say on every run which of the two happened, because a beater in four orange
boxes and a beater in a real hi-vis vest look equally deliberate in a console log.

**Still not measured, and it matters for the published game:** both items load in **Studio**. A live
(non-Studio) server's `InsertService:LoadAsset` has its own ownership rules, and this project has not
run a published server. If it refuses there, the fallback above is what players see -- which is why
the fallback exists and why the boot prints which route it took.

**Nothing is uploaded and nothing is bought.** No `assets/uploads.json` row (that file is one row per
Open Cloud upload, and there was none), no Robux spent, and the two manifest rows in
`src/serverstorage/Assets/init.luau` carry `basis = "roblox-catalog-accessory"` with this correction
quoted in them.

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

### 5.4 What Task 152 actually measured, 2026-10-11

Section 5.2 left three things open and this is each of them, measured in the Forest Test.

**1. The model route is shut, confirmed a second time.** Nothing changed: the geometry is built from
parts (`src/shared/Horn/init.luau`, `Horn.pieces`) -- a nickel mouthpiece, three tube sections of
growing bore, a flare and a bell, plus a leather carrying cord. Six pieces, six welds, no asset, no
upload, no Robux.

**2. The voice loads, and it is SIXTY SECONDS LONG.** `rbxassetid://9038902877` reports
`IsLoaded = true` and **`TimeLength = 60.63`**. It is not one blast: it is a vintage recording of a
hunting horn being blown over and over. Played whole, one click would sound a horn for a minute, so
**the clip has to be cut, and the cut was measured rather than guessed.** `Sound.PlaybackLoudness`
sampled at render rate for 14 s, peak per 0.1 s bucket:

| Window | Peak loudness | What it is |
|---|---|---|
| 0.0 - 0.1 | 0 | the asset's own dead lead-in |
| 0.2 - 4.0 | 43 - 453 | **the first call** -- a complete signal phrase |
| 4.1 - 5.0 | 142 falling to 11 | its decay, into the clip's own silence |
| 5.1 - 8.8 | 31 - 411 | the SECOND call |
| 9.0 - 9.6 | 10 - 28 | silence again |
| 10.0 - | 30 - 496 | the third call, and so on to 60.63 |

So `SOUND_START = 0.12` (past the dead lead-in, so the horn sounds *on* the click) and
`SOUND_CUT = 4.4` (inside the clip's own silence, so the stop cannot click, and before 5.1, so one
blast is one signal and never two). **The one number this moved is the cooldown:** the dispatch's
start value was 3 s, and a 3 s cooldown over a 4.0 s call chops the last note AND lets a beater
clicking on the cooldown produce one continuous unbroken horn. `COOLDOWN = 5` is the smallest value
that fits a whole call. All four are data and `tests/server/horn.spec.luau` asserts only the
relations between them, not the values.

**Nobody has heard it yet.** Karen's ears decide, and every one of those numbers is one line.

**3. The spook reuses the existing door, and "away from the beater" means what the drive already
means by it.** `Runtime:hearHorn(at, radiusStuds)` sweeps its own animals and calls `Brain:spook(at)`
-- the one door every fright comes through, the same one `ForestTest`'s phantom beaters use -- with
the `shot` argument left nil, so the task 150 shot latch (`SENSE.SHOT_FLIGHT_UNTIL_EXIT`) does NOT
fire and `_lastShotAt`/`_lastShotPos` are untouched. That matters: a beater walking a wood blowing
every five seconds must not empty it, and an animal spawned later must not inherit a bang that was
never fired.

**What that door does with the direction is worth writing down, because "runs AWAY from the beater"
reads as a straight line and is not one.** `Brain:_latchFlight` heads the animal for `field.exitZ`
and makes the thing that frightened it a SWERVE -- *"the exit is the heading and the gun is a
swerve ... driven game breaks PAST the guns"* (task 139, the Director's decision A, measured). A
beater pushing animals toward the hunters' line is exactly what that rule is for, so the horn
inherits it rather than inventing a second panic rule, which is what 5.3 asked for.

**MEASURED, live, one beater and one blast each time:**

| Trace | Inside 286 studs (80 m) | Outside it |
|---|---|---|
| first blast, 13 animals | **12 of 12 ran** at 21.3 - 23.0 studs/s, and **every one ended FARTHER from the beater** (+5 to +34 studs in 1.5 s) | none in the world |
| a later blast, with a 1.5 s control window BEFORE it | 18 animals; **10 went from under 6 studs/s to 15.9 - 21.0**, the other 8 were already running | **7 animals at 295 - 341 studs: 0 started running.** Each was walking at 4.5 - 4.6 studs/s before the blast and 4.5 - 4.6 after |

The radius boundary is visible in that second trace's own rows: the animal at **276 studs ran**, the
one at **295 did not**.

### 5.5 The defect this task found by LOOKING, and it is the camera's

**A beater holding the horn saw a SHOTGUN in first person.** The server said the character held the
`Horn` and the Backpack held the gun; the frame said side-by-side shotgun. Karen plays in first
person, so that frame was the whole of what she would have seen.

The cause is one sentence that stopped being true. `Camera.Viewmodel`'s source is *"the Handle of the
Tool in the local character"*, and until the horn there was only one kind of Tool in this game -- so
it took the horn's Handle, `Viewmodel.weaponId()` found no `DrivenHunt.Weapon` attribute on it,
`Weapons.row(nil) or Shotgun.CONFIG` answered the shotgun, and it drew the wrong object out of the
right Handle. `Camera.Rig` has the same assumption written out in its own header -- *"In first person
the viewmodel IS the gun"* -- and hides everything the character holds, Tool included.

**The fix is one shared fact asked in two places.** `Weapons.isWeaponTool(tool)` (attribute first,
name as the fallback for a Tool from a server older than task 140): `Viewmodel` draws nothing for a
non-weapon Tool, and `Rig` leaves a non-weapon Tool VISIBLE. The two conditions are exact
complements, so the thing in the hand is on screen exactly once -- as the viewmodel clone or as the
real Tool, never twice (which is the "two shotguns on screen at once" Rig's header records) and never
neither. The horn is therefore seen in first person as the real object, and
`tests/client/camera_client.spec.luau` drives both halves against one probe.

**What is NOT built, and is named rather than hidden:** there is no first-person horn *viewmodel*.
The gun viewmodel poses hands, shells, a hinge and a sight around a gun, and none of that is a horn;
the real Tool is drawn instead, so the horn is in view but **no hands are**, and the "raise to mouth"
is a tilt of `Tool.Grip` with the ARM left where it is. Raising an arm means writing the character's
Motor6Ds or playing a track on its Animator, which would be a second writer on a character that has
exactly one per concern (CLAUDE.md rule 3). A posed first-person horn with hands is the camera
system's own task.

---

## 6. Numeric targets

| Thing | Value | Where it came from |
|---|---|---|
| base clothing colour | **RGB(86, 80, 56)** | median of both sleeve albedo maps, section 3 |
| hunter | base + orange hat | Karen's doc |
| beater | base + orange hat + orange vest | Karen's doc |
| beater vest | catalog `99269365249885` (RP UGC), plates as the fallback | section 4.2 |
| hat, both roles | catalog `13724841516` (dvdko), the two-part hat as the fallback | section 4.2 |
| orange, for the fallback plates | RGB(255, 112, 0) | unchanged, `Match.Body`'s existing `OUTFIT_COLOR` |
| vest plates | 4, one per horizontal face | Task 82, and Texas's 144 in² front **and** back |
| head, hair and the player's own hats | untouched | nothing asks for them, and the hat clears hair (Task 77) |
| horn sound (152) | `rbxassetid://9038902877` | section 5.2, licensed; **measured 2026-10-11: loads, 60.63 s** (5.4) |
| horn clip window (152) | **0.12 - 4.4 s** of it | one complete call, cut inside the clip's own silence (5.4) |
| horn cooldown (152) | **5 s** | the smallest that fits one 4.0 s call; the dispatch's 3 chopped it (5.4) |
| horn spook radius (152) | **80 m = 286 studs** | the Director's value, written in both units like task 150's radii |
| horn geometry (152) | **6 parts, 6 welds**, no asset | the model route is shut; parts, as the shotgun is (5.2, 5.4) |

---

## 7. What is explicitly NOT in Task 151

* **The horn** -- Task 152, with section 5 as its head start.
* **The compass** pointing a beater at the hunters' line -- later, per the Director's cut.
* **The beater line and the countdown**, money per drive, the weapon licence, spooking with a weapon --
  all in Karen's doc, all their own tasks.
* **Buying either item** -- nobody needs to: an experience wears a catalog accessory at no cost (section 4.2).
* **A classic Shirt/Pants upload** -- it would match exactly, it needs an upload OK, and route 2 gets
  the same colour without one.
