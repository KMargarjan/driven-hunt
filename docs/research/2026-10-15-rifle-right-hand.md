# The rifle's right hand: what "aligned perfectly" means, as numbers

Task 188. Karen, 2026-10-15 ~09:20, verbatim: *"rifle is ok now / we need to improve right hand now
seems odd it has to be aligned perfectly"*; asked where: *"Bolt pull, Holding (hip)"*. Her standing
bar for weapons: shooting, weapon and reload must be perfect, checked frame by frame against the
target.

## 1. What the system must do

Two things, and they are the two Karen named.

1. **HIP HOLD.** The right hand holds the **wrist of the stock** -- the narrow part of the wood
   between the receiver's rear and the comb. Palm and fingers on the wood, the hand closed round it
   rather than beside it or under it, the forearm running back and down toward the shoulder.
2. **BOLT PULL.** The hand leaves the grip, takes the **bolt knob**, and stays on it for the whole
   lift-back-forward-down cycle (1.62 s, task 184's timing), then comes back to the grip.

## 2. Sources: what a correct grip looks like

Three, read 2026-10-15, with what each is good and bad for.

1. **U.S. Army TC 3-22.9, *Rifle and Carbine*** (Training Circular, May 2016; public domain as a
   work of the U.S. federal government; current doctrine).
   <https://armypubs.army.mil/ProductMaps/PubForm/Details.aspx?PUB_ID=1001734>
   Chapter 6, "firing hand grip": the firing hand grips the pistol grip **firmly but not tightly**,
   the **thumb and fingers wrap around** it, the **trigger finger lies along the receiver outside
   the trigger guard** until the decision to fire, and the web of the hand sits **high on the
   backstrap** so the grip lines up with the forearm.
   *Good for:* it is a written standard rather than an opinion, and it names the three things that
   can actually be measured -- contact all the way round, the finger indexed off the trigger, the
   wrist in line with the arm.
   *Bad for:* it describes an M4's vertical pistol grip. This rifle has an **English straight-hand
   wrist** whose axis is only ~20 degrees below the bore, so "in line with the forearm" points
   somewhere else entirely and the grip geometry cannot be copied across.
2. **NRA gun safety rules -- "keep your finger off the trigger until ready to shoot"** (National
   Rifle Association; maintained, and the rule itself is unchanged for decades).
   <https://gunsafetyrules.nra.org/>
   The resting index finger lies **straight along the side of the receiver above the trigger
   guard**, never curled inside it.
   *Good for:* it settles the dispatch's open question -- index straight along the side, not on the
   trigger -- for a hunter who is carrying rather than firing.
   *Bad for:* it is a safety rule, not a description of a grip; it says nothing about the other
   three fingers or the thumb.
3. **John Rigby & Co., *Highland Stalker* (the Mauser 98 this repo's mesh is)** (Rigby, read
   2026-10-15; a live maker and the actual model).
   <https://johnrigbyandco.com/rifles/highland-stalker/>
   The **straight-hand (English) stock**: no pistol grip at all, the wrist nearly in line with the
   bore; and a **Mauser 98 bolt handle turned down against the stock at rest, lifted about 90
   degrees to unlock**.
   *Good for:* it is the gun in the game. It is why source 1's pistol-grip geometry does not
   transfer, and it is where "the handle lifts UP and out to the right" comes from.
   *Bad for:* maker's copy, no measurements.

**The pattern adopted**, from sources 1 and 2 with source 3's geometry: *the fist closes around the
wrist of the stock with contact all the way round it, the index finger straight along the receiver
above the guard, and the bolt knob -- when the bolt is worked -- held inside that same fist.*
Nothing is invented (rule 2); what is new is only that both ends of it are now **measured** instead
of eyeballed.

## 3. The numeric targets

| | target | why that number |
|---|---|---|
| hip: the hand's grip point off the **wrist's axis** | **< 0.0719 studs** | half the wrist's own narrowest width: inside that, the grip point is inside the WOOD, which is what having hold of a stock is. (The hand's own gap, 0.027, is the wrong bound here -- a hand slides a little way along a wrist and is still holding it. It IS the right bound for the knob, which is a ball the fist closes on.) Reached: 0.0543 |
| hip: **wrap** -- how far round the wrist the glove reaches | **>= 0.75** of the circle | source 1's "thumb and fingers wrap around" is a closed hand, not a hand laid against one side |
| bolt: the hand's grip point off the **knob's centre**, every frame the hand is on it | **< 0.05 studs** (the dispatch's tolerance) | the knob's own radius is 0.0256, so inside this the knob is inside the hand |
| bolt: glove surface to knob surface | **touching (0.000)** | a hand near the knob is a hand not holding it |
| both: glove inside the wood | **as low as it goes**, reported, never claimed to be zero | section 6 |

## 4. What was measured, and how

Everything below is off the **shipped meshes**, in the Handle's frame (-Z muzzle, +X right, +Y up),
at the scale the game draws them (`HANDLE_SIZE.Z` = 4.4, so the scale factor k is 1).

* **The rifle**: the four group glTFs `tools/gltf_split.py` wrote and `tools/asset_prep.py`
  published, with the two anchor triangles dropped and the vertices mapped into the game frame by
  `game = (fz, fy, -fx)` -- which reproduces the split report's own `minStuds`/`maxStuds` exactly,
  so the mapping is checked rather than assumed.
* **The glove**: the published right glove, scaled so its longest axis is `HAND_LENGTH_STUDS`
  (0.6692) -- which reproduces `HAND_RIGHT_NATURAL` to four decimals -- and rotated into the aligned
  frame `Camera.Viewmodel.align` puts it in (fingers +X, palm +Y).

**The bolt knob** is a least-squares sphere through the 1,900 surface samples of the bolt group past
the action's right wall: **centre (0.0879, 0.0428, 0.6340), radius 0.0256**, mean residual 0.0010,
worst 0.0072. It is a ball on a stem, and it fits one.

**The stock's wrist** is the centre of the wood's cross-section over 0.05-stud slices; narrowest at
z 0.976 and 1.024 (0.1438 and 0.1437 studs across, against 0.1479 at z 0.875 and 0.1655 at z 1.175).
The axis is the first principal direction of those seven slice centres: **point (-0.0111, -0.0603,
1.0246), direction (0.0087, -0.5221, 0.8529)** -- 20.2 degrees below the bore, which is source 3's
straight-hand stock and **not** a pistol grip.

**The glove's own grip point** is the enclosed hole in its silhouette, found by voxelising the mesh
at 0.006 studs in the aligned frame and flood-filling from outside: a gap centred at
**(+0.165, 0.000, -0.006)**, axis along +Y, 0.054 studs across in X and 0.060 in Z, largest
inscribed circle radius 0.024-0.030 -- and one column of it, exactly that point, clear of glove
along the whole of Y, so it is a hole and not a dimple. **The knob's radius (0.0256) and the hole's
(about 0.027) are the same number.** The fist was modelled closed on something this size, and the
knob is that thing.

## 5. What was wrong -- three findings, in the order they bite

**(a) THE RIFLE'S RIGHT HAND WAS THE SHOTGUN'S, BYTE FOR BYTE.** `weapons.rifle.carry.right` and
`weapons.shotgun.carry.right` were the same six numbers -- pos (-0.0456, -0.1976, 0.992), rot
(pitch -24.4176, yaw -103.1991, twist -35.5376) -- and so were `aim.right` and `cycle.right`. Task
140 brought the rifle in with the shotgun's pose set and nothing ever moved them, because **nothing
in the repo said where the rifle was held**. On model B that pose is 0.0885 studs off its wrist
axis: a hand holding a gun. On the Rigby it is **0.0995 off the axis and 0.2205 off the wrist's own
centre**, with **wrap 0.25** -- the hand reaches a quarter of the way round. Rendered off the two
meshes it hangs **under the trigger guard, with the wrist of the stock above and behind it**. That
is Karen's *"seems odd"* at the hip.

**(b) THE BOLT HAND WAS A THIRD OF THE GUN AWAY FROM THE KNOB.** `cycle.hand.grip` put the glove's
grip point **0.5260 studs** from the knob's centre at every frame the hand was supposed to be
holding it, and the nearest glove surface was **0.2832 studs** from the knob's skin -- 74 mm at this
gun's scale, nearly half the hand's own length. The hand was never near the knob at any point of the
cycle, and it was **30-43 % buried in the gun** while it was not.

**(c) THE BOLT HANDLE TURNED *INTO* THE RECEIVER, AND THE HAND FOLLOWED IT IN.** This one is code,
not data. `Camera.Viewmodel.hinge`'s slide path turned the cycle group by
`CFrame.Angles(0, 0, -rad(BOLT_LIFT_DEG * turn))`. **A closed bolt handle hangs below the line it
turns about** -- the knob's centre is 0.067 studs under `boltAxisY` -- and a negative turn about +Z
takes +X toward -Y, so the handle was carried from (right, low) to **(-0.0142, +0.0003)**: left of
the gun's centre line, inside the receiver and the comb. Drawn off the model at the shipped sign
**the handle is not visible at all** for the whole cycle; at +60 it lifts to (0.1021, 0.1525), up and
clear on the right, where a lifted Mauser handle is (source 3). Since `BOLT_HAND.grip` is carried by
that same transform, the right hand was being driven into the wood with it.

## 6. The honest limit: a closed fist on a thick wrist

The glove's gap is **0.054 x 0.060 studs**. The wrist of this stock is **0.144 x 0.203**. The fist
is three times too small to go round it, so **"palm and fingers on the wood with no gap" and "no
fingers through the stock" cannot both be true of this hand on this gun.** Floating the hand clear
leaves a visible gap; closing it makes the fingers overlap the wood. The choice taken is **contact,
with the overlap spread evenly and reported**: 23.3 % of the glove's surface is inside the wood at
the hip, worst depth 0.080 studs (21 mm). Before the change it was 22.6 % and 0.088 -- about the
same amount of overlap, in the wrong place. What changed is where the hand IS, not how much of it
clips.

A hand that really closes on this wrist needs a glove modelled with a wider gap. That is an asset
task and Karen's call; it is recorded here rather than worked around (rule 8).

## 7. Before and after, measured

Hip hold, the glove against the rifle's own meshes:

| | off the wrist axis | off the wrist centre | wrap | inside the wood | worst depth | contact |
|---|---|---|---|---|---|---|
| before | 0.0995 | 0.2205 | 0.25 | 22.6 % | 0.0880 | 32.8 % |
| after | **0.0543** | **0.0585** | **1.00** | 23.3 % | 0.0800 | **49.7 %** |

Bolt cycle -- the hand's grip point against the knob's centre, both carried by the bolt's transform:

| phase (progress) | before: miss | after: miss | after: glove skin to knob skin | after: glove inside the gun |
|---|---|---|---|---|
| hip idle (0.00) | 0.6065 | 0.3821 | -- (hand on the grip) | -- |
| lift half (0.11, reaching) | 0.1565 | 0.1987 | -- (mid reach) | -- |
| lift, reach done (0.22) | 0.5260 | **0.0208** | **0.0000** | 2.1 % |
| lift done (0.35) | 0.5260 | **0.0208** | **0.0000** | 1.3 % |
| drawing back (0.60) | 0.5260 | **0.0208** | **0.0000** | 0.2 % |
| back stop (1.00) | 0.5260 | **0.0208** | **0.0000** | **0.0 %** |
| coming forward (0.60) | 0.5260 | **0.0208** | **0.0000** | 0.2 % |
| closing (0.22) | 0.5260 | **0.0208** | **0.0000** | 2.1 % |
| back at the grip (0.00) | 0.6065 | 0.3821 | -- | -- |

The rows at progress 0.00 and 0.11 are the **reach**, and it is by design: `cycle.hand.reachShare`
is 0.22, so the hand travels from the grip to the knob over the first 22 % of the bolt's travel and
is not meant to be on the knob yet. From 0.22 on it is, and the miss is **constant** -- because the
hand is placed from the bolt's own transform, which is what makes "the bolt moves with the hand"
true by construction rather than by two timelines that agree until they do not. That invariance is a
spec case, not a claim.

## 8. Where the fix lives

* **Content** (`src/shared/Viewmodel/poses.json`, `weapons.rifle`): `carry.right`, `aim.right` and
  `cycle.right` all become the one grip pose -- pos (0.0082, -0.2406, 1.0541), rot (pitch 137.60,
  yaw 101.72, twist -74.58) -- and `cycle.hand.grip` becomes pos (0.1275, -0.1101, 0.7026), rot
  (pitch 159.94, yaw -177.60, twist -83.05). **One pose for the hip and the aim**, because a right
  hand that moved when the eye went to the scope would read as the gun being re-gripped on every
  aim.
* **Engineering**, said plainly because the dispatch asked for it to be said: finding (c) is a
  **sign in the pose player** and cannot be expressed as data -- `liftDeg` is a magnitude, and
  writing -60 into the file would be a number that lies about itself. `Rifle.Geometry.boltLift` owns
  the direction now, beside the axis it turns about, and `Camera.Viewmodel.hinge` calls it. The two
  measured anchors on the gun (`Geometry.boltKnobOffset`, `Geometry.gripOffset`/`gripAxis`) and the
  one on the hand (`HandAssets.GRIP_STUDS`) are new data: nothing reads them at run time, and
  `tests/server/viewmodel_poses.spec.luau` measures the pose file against them, so a hand that
  drifts off the grip or off the knob fails the harness instead of waiting for a playtest.

## 9. What I could not verify (rule 8)

1. **Whether Karen likes it.** The numbers say the hand is on the grip and on the knob; whether the
   wrist angle reads as a hunter's hold is hers to say.
2. **The forearm.** It is off the bottom of the first-person frame at the hip. The cuff's direction
   was constrained to run back and down toward the shoulder, and then not looked at again.
3. **The index finger cannot reach the trigger guard on this hand.** The glove's longest extended
   digit is 0.183 studs from the fist's gap (47 mm), and the trigger sits 0.29 studs forward of the
   wrist. With the fist on the wrist that digit reaches z 0.84 at best -- the rear of the receiver,
   not the guard. Source 2's "straight along the side of the receiver" is satisfied; "above the
   trigger guard" is not reachable without taking the hand off the grip, and nothing was bent to
   fake it.
4. **The glove's gap** (section 6) is a model limit, not a pose that can be tuned out.
