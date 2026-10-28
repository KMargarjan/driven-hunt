# Task 305d -- the live measurements, all in KAREN'S place (Forest Test, Play)

Her overrides were READ FIRST and **nothing of hers was touched** (rule K). Thirteen rows before the
session and the same thirteen after, `DHFlag_ZONES_FOLLOW_GAIT=true` among them (305c left it on):

```
placeId=130094961655666  Body.followGait=function  GAIT=true shift=2.5
SSattrs: DHFlag_AIM_REWIND=true, DHFlag_BOAR_BEHAVIOUR=true, DHFlag_BOAR_MODEL=true, DHFlag_COINS=true,
 DHFlag_DEER_ROAD_LEAP=true, DHFlag_DRIVE_BOTS=true, DHFlag_HIT_CLAIM=false, DHFlag_HORN=true,
 DHFlag_LICENCE_POPUP=true, DHFlag_LOBBY=true, DHFlag_RANGE=true, DHFlag_SHOP=true,
 DHFlag_ZONES_FOLLOW_GAIT=true
```

`flags.py --place forest clear` was never run. The place was served by `driven-hunt-294` on
**localhost:34874** (panel shot `<runs-dir>/305d-conn-crop.png`, "DrivenHunt localhost:34874,
8 seconds ago"); `driven-hunt-karen` and its :34873 were never touched.

Instruments, all in `<runs-dir>/305d/`:

| probe | what it reads |
|---|---|
| `rig.luau` | each box's weld `C0` in the trunk frame, frame by frame: the worst POSE TRAVEL over a lag |
| `rig2.luau` | `gaitRig`'s rule re-implemented on the live rig, fed the REST offsets from `Body.kindGeometry` |
| `carrier.luau` | which bone the SHIPPED `gaitRig` chose: predict `C0` from each bone and match the live one |
| `carrier2.luau` | the same question from INSTANCE FACTS ALONE -- the carrier is the bone whose derived `inBone` is constant. No geometry table, so a fresh module cache cannot mislead it |
| `aim.luau` / `ray.luau` | the Playtester's own aim points, as a point and as a RAY from the shooter's eye, against the box set the server tests after the rewind translation |
| `propS/propC.luau` | how old the box POSE is on the client: a server-stamped attribute read back on the client |
| `trial2.tpl` -> `U*.luau` | a real `FireRequest` from the client VM at the Playtester's own aim point (the drawn box surface, **not** the nose bone), zero added lead |

## 1. The three dispatch items

| item | measurement | verdict |
|---|---|---|
| **1. the WALK regressed (chest 1/5, 19.3 m behind)** | `ray.luau` at 4.50 studs/s: a ray from the shooter's eye through the DRAWN chest centre, translated by the rewind shift, hits a zone part on **189/189 frames** (`ZoneChest1` 109, `ZoneChest2` 80). `U1` real `FireRequest`s at the same aim: **4/5** on `5c444dbe` and **4/5** on the fix -- the same 4/5 that 305b read | **NOT REPRODUCED** |
| **2. SEMI-AUTO is broken (0/3 where the shotgun carries the nose)** | Ballistics are the SAME TABLE by reference: both read `muzzle=1752  t(125)=0.0763 s  lead=1.83 studs`. Back to back at RUN, nose aim, same rig: `5c444dbe` **semiauto 1/5, shotgun 4/5**; at a STANDING boar **semiauto 2/5, shotgun 3/5**; on the fix **semiauto 3/5, shotgun 3/5**. The nose tip is a ~50% aim for BOTH guns | **NOT THE GUN** |
| **3. the rewind pairs an old trunk with a present pose** | the pose is **not** 0.18 s old on the client: a server-stamped attribute reads back at **min 0.0372, max 0.0797, mean 0.0556 s** over 234 samples. Worst box POSE TRAVEL over that real lag, at RUN: head 0.267, chest 0.233-0.289 studs, against boxes 0.32-1.76 studs across | **REAL BUT SMALL** (~0.05-0.3 studs, not the 0.3-1.8 the escalation feared) |

## 2. What IS wrong, and the fix

`Body.gaitRig` picked each box's bone by **plain nearest rest distance over all 40 bones**. Two boxes
sit on the boar's BACK, a stud above the spine, so the nearest bone in the air is a paired one:

```
rig2.luau, male, 40 bones, REST offsets:
ZoneBody1   rest=0.00,1.56,-0.95 -> ear_1.L    d=0.534   (2nd ear_1.R   d=0.534)
ZoneBody2   rest=0.00,1.44,-0.11 -> hip_1_f.R  d=0.576   (2nd hip_1_f.L d=0.576)
```

**The slab over the shoulders was skinned to an EAR.** A paired bone moves with one side only.
Centre-line bones read |x| = 0.000 on this rig (`Neck`, `Spine_01..05`, `head`, `mouth`, `nose`,
`tail_*`, `root_bone`); every paired one starts at **0.235**. So the rule is: a box on the centre
line takes a centre-line bone; a box off it takes its own side's or a centre one. A tenth of the
mesh's width (0.140 for the male) separates the two groups with room to spare.

### Before and after, same probe, same place, same pace

| reading | `5c444dbe` | `472b8c68` |
|---|---|---|
| `ZoneBody1` carrier (`carrier.luau`, predicted vs live `C0`) | -- | **`Neck`, err 0.0284** (next `hip_1_f.R` 0.1550) |
| `ZoneBody1` carrier by the OLD rule on the same live rig (`rig2.luau`) | **`ear_1.L`** | `ear_1.L` (the probe re-implements the old rule; it is the BEFORE side, computed on the same animal) |
| `ZoneBody2` carrier | old rule: `hip_1_f.R` | **`Spine_01`, err 0.0242** |
| `ZoneBody1` worst pose travel per real lag, RUN (`rig.luau`) | **0.420 studs** | **0.268** (-36%) |
| `ZoneBody2` worst pose travel per real lag, RUN | 0.184 | **0.141** (-23%) |
| `ZoneHead1` / `ZoneChest1` worst pose travel, RUN (untouched boxes) | 0.264 / 0.293 | 0.267 / 0.289 |
| every other box's carrier | spine / tail / shin | unchanged |

`ZoneBody1` is **0.12 studs tall**: 0.420 studs of travel is three and a half times its own height.

### The known-bad input still fails (rule L)

`U7`, rifle at RUN, aimed one full body length ahead of the drawn snout, in clear air: **0/3**.
Nothing was widened.

## 3. NOT PROVEN

- **The click thresholds in the dispatch** (rifle RUN nose >= 8/10 and the rest). This rig is a
  `FireRequest` from the client VM, and it reads **systematically lower than the Playtester's real
  clicks on the same build**: rifle RUN nose = **4/10** here on `5c444dbe` where the Playtester's
  board read 9/10, and 305c's own rig read 6/10. The screen-centre gate the Playtester uses is not
  in it. **No count in this file is the game's hit rate**; they are used only as before/after pairs
  on one instrument. The thresholds need the Playtester.
- **The red deer.** `U8` reads 0/5 at the stag's nose on the fix and there is **no before from this
  instrument**. `carrier2.luau` says the stag's TRUNK boxes are all carried by spine/neck bones
  (`Spine_01`, `Spine_03`, `Spine_base`, `neck_01`, `neck_02`), so the rule changes nothing there --
  but the stag's HEAD boxes are inside that detector's blind spot: validated against `carrier.luau`
  on the boar it agrees 6/6 on trunk boxes and **disagrees on the head cluster**, where `nose`,
  `mouth`, `eye` and `eyelid` sit within 0.2 studs and the spreads tie. `rig2.luau` cannot help: a
  fresh module cache returns the BOAR's zone table for `kind="stag"`.
- **Karen has not played it, and no shooter's-eye frame was taken** of a hit on the back slab.
- **The 19.3 m / 2.8 m `MISS GAP` figures.** `Range.gapStuds` measures the ray's END POINT against
  the target's present X: a shot that passes a hair wide carries on to the berm, so the number is
  the berm's offset, not the shooter's error. 305b already queued this; nothing here leans on it.
