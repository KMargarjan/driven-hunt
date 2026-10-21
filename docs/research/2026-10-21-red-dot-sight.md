# A red-dot sight the player looks THROUGH

**Task 234, part 1.** Karen, 2026-10-21, playing the Forest Test with the semi-automatic aimed,
with a screenshot:

> *"this aiming is not coirrect for semiauto / you know this type of aiming you look from that
> galss and there is a dot inside right ?"*

and, naming the type and the picture she wants:

> *"Red Dot Sight / Micro Red Dot Sight"* ... *"verry similar just red light red and then dot
> acordingly to be visble"* ... *"on semiauto we have now aim there like aimpoint but not exactly,
> when we aim we need to see tru that and see that view not the dot"*

Her two references are `<runs-dir>/design/reddot-ref-1.png` and `reddot-ref-2.png`.

The defect is reproduced at `.screenshots/234-before-semiauto-aim.png` (DEV, aimed, eye height,
969 x 784, FOV 50): a bare red ball floating over the receiver, no housing, no glass, nothing to
look through. That is what task 227 left behind on purpose -- it faded the bought one-piece optic
out of the sight line because its glass is an opaque amber face, and queued the real fix as 227b.
This is 227b.

---

## 1. What the system must do

1. **A housing the player looks through**, with its rim IN VIEW while aimed -- a dark ring framing
   the picture, not a sight that disappears when you use it.
2. **Clear glass**, lightly tinted. The scene is seen THROUGH it.
3. **A red dot INSIDE the glass, at the screen centre, on the camera axis**, staying on the target
   as the gun moves.
4. **It must read at 1280 x 720 and must not hide a deer at 50 m.** A stag is 2.1 m tall; at 50 m
   that is 2.4 degrees, so a dot of about one degree is a third of the animal's height -- findable,
   and not a blindfold.
5. **In the gun's real proportions.** Karen named the class: a MICRO red dot (Aimpoint Micro
   T-2 / H-2), on a low mount, on the receiver's rail.
6. **No new upload.** The bought `semiauto.sight` mesh cannot be re-split in this repo (bought
   assets live outside it), so the housing is built from Roblox parts.

---

## 2. What was measured first

Everything below is measured in the Handle's own frame (-Z is the muzzle, +X right, +Y up), at
`HANDLE_SIZE.Z = 4.9`, by a live probe in the aimed pose
(`<runs-dir>/234-measure.luau`, run through `227run.py client`):

```
fov=50.00 viewport=969, 784
eye-in-handle  = (0, 0.2359, 1.3835)      -- the camera, laid by Mode.aimOffset
look-in-handle = (0, 0, -1)               -- straight down the sight line
Dot            local=(0, 0, -0.9000)      -- dead on the axis, 0.9 studs in front
```

So the dot is ALREADY on the camera axis and already at the screen centre: requirement 3's second
half is task 227's and is kept, not rebuilt. What is missing is everything around it.

The horizontal field at that viewport is `2*atan(tan(25 deg) * 969/784) = 59.9 degrees`.

The measured optic: `X[-0.0627 +0.0869] Y[+0.1850 +0.3379] Z[+0.3725 +0.5952]`, rear glass at
(x -0.0032, y +0.2318, z +0.5894), front glass at (x -0.0033, y +0.2400, z +0.3776).
At this repo's own stated scale (`Gun`: Roblox's 0.28 m/stud) that housing is 43 mm tall and
62 mm long -- a Micro T-2 (68.6 mm long) on a low mount. **The bought model is already the right
sight; only its glass is wrong.**

---

## 3. Sources

| # | Source | Licence | Maintained | What it gave |
|---|---|---|---|---|
| 1 | [Red dot sight](https://en.wikipedia.org/wiki/Red_dot_sight), Wikipedia | CC BY-SA 4.0 | yes, live article | the optics, and the two housing families |
| 2 | [TheArturZh, *Implementation of optical scope shadow, effect of scope parallax adjustment, and parallax-free reflex sight*](https://devforum.roblox.com/t/implementation-of-optical-scope-shadow-effect-of-scope-parallax-adjustment-and-parallax-free-reflex-sight/1589383), Roblox DevForum, 2021-12-14 | author: *"You can use code from these files in your project without mentioning the author"* | no (a 2021 tutorial post) | the Roblox-native way to fake a parallax-free reticle, and why we do not need it |
| 3 | [MrMinimal/godot-reflex-sight](https://github.com/MrMinimal/godot-reflex-sight) | **AGPL-3.0-or-later** | no (9 commits, 6 stars) | the same technique as a shader; **rejected on licence** |
| 4 | [Aimpoint Micro T-2 review, *Shooting Illustrated*](https://www.shootingillustrated.com/content/review-aimpoint-micro-t-2-red-dot-optic/) (aimpoint.com itself answers HTTP 403 to a fetcher) | editorial, quoted for figures only | yes | the real numbers: length **2.7 in (68.6 mm)**, objective **20 mm**, clear aperture **18 mm**, **2-MOA** dot, *"flip-up see-through lens covers on both the ocular and objective lenses"* |

### What each does well and badly

**Source 1** is the only one that says what the shooter actually sees, and it is the one that
decides the SHAPE. Two things matter:

> *"the collimated image of the red dot is truly parallax free only at infinity"*

> sights come in *"tube"* designs (cylindrical, like telescopic scopes) or *"open"* designs
> (*"a flat base with a supporting loop"*)

and the dot sizes: *"between 0.6 and 1.6 mrad (2 to 5 MOA)"*. It says nothing about how to draw
one in a game engine.

**Source 2** is the right pattern for the wrong problem, and that is worth writing down because it
is the obvious thing to borrow. It keeps a reticle on target when the EYE IS OFF THE OPTICAL AXIS,
by offsetting a Texture per frame from the camera's position relative to two virtual lens planes.
It also states its own cost: *"We'll need a 'long' scope for reflex sight, preferably the objective
lens should be 1000+ studs away from the ocular lens."* **Rejected, with a measurement**: in this
game `Mode.aimOffset` LAYS the eye on the sight's own axis -- the probe above reads the camera at
`(0, 0, -0.9)` from the dot in the gun's frame, exactly on it -- so the eye is never off axis and
there is no parallax to cancel. Adopting it would add a per-frame writer of a texture offset, a
1000-stud ghost part, and a second answer to "where is the dot", to solve a case this camera cannot
produce. (The day a free-look-while-aimed mode exists, this is the note to come back to.)

**Source 3** is the same technique again, in Godot, and it is **AGPL-3.0-or-later**: a licence this
repo cannot take, since the repo is public and AGPL is viral across the whole work. Read for the
idea, not used, no code copied.

**Source 4** is the only place with Karen's named sight's actual dimensions, and it is what keeps
the housing honest rather than cartoon-sized.

---

## 4. The pattern adopted, and why

**An OPEN (hooded) reflex sight built from Parts, in the one piece list the gun already has
(`SemiAuto.Geometry.pieces`), drawn by the one drawer that already draws every gun
(`Camera.Viewmodel.buildNewGun`).** No new owner, no new instance kind, no per-frame writer.

Three decisions, each with its reason:

**(a) Open, not tube** -- and this was forced by arithmetic, not taste. Looking into a TUBE from
behind, the clear view is the FRONT aperture, not the rear one: with a T-2's 18 mm aperture and
68.6 mm body, an eye 70 mm behind it sees a clear window of
`2*atan(9/(70+68.6)) = 7.4 degrees`. Karen's references show a window filling **36 %**
(ref-1) and **46 %** (ref-2) of the frame width -- about 20-30 degrees. A tube cannot do that at
any eye relief a man can hold; the references are OPEN sights (ref-2's arch is a supporting loop,
source 1's second family) photographed with the lens almost touching the glass. So: **one lens in
a short hood**, where the clear view is the hood's own aperture and there is no tunnel.

**(b) The eye goes to the glass.** The shipped aim pose puts the eye **0.9 studs (252 mm)** behind
the sight -- a rifle scope's eye relief, inherited when this weapon was built and never re-solved
for a red dot. At 0.9 studs NO believable hood fills a third of the frame: it would have to be
0.33 studs (92 mm) across, two thirds of the gun's height. `aim.eyeReliefStuds` for this weapon
goes to **0.35 studs (98 mm)**, which is a cheek weld, and the hood then carries its real size.
The clipping this risks was checked rather than assumed (section 6).

**(c) The hood is a ring of straight segments.** Roblox has no hollow primitive and no built-in
torus, and a `Decal`/`SurfaceGui` ring would need an uploaded image (none is allowed here). A ring
of `HOOD_SEGMENTS` boxes is the one way to draw an annulus out of parts. 16 segments puts the
polygon's sagitta at `R*(1-cos(11.25 deg)) = 0.019*R` -- 0.0013 studs at this radius, about a fifth
of a degree, under one pixel at 1280 wide.

**What is NOT adopted and why:** a `SurfaceGui`/`BillboardGui` dot. A BillboardGui is drawn at a
constant pixel size whatever the distance, so it would not shrink with the window and could not be
bounded against "does not hide a deer at 50 m"; a SurfaceGui on the glass puts the dot ON the lens
plane, which is where a real reflex sight's dot is NOT (source 1: it is collimated to infinity).
The existing `Dot` -- a Neon ball on the sight axis -- is already the better answer and is kept;
`Neon` is a material that renders bright and is not a light source, so it costs the scene nothing.

---

## 5. The numbers, and where each comes from

All in Handle-frame studs at `HANDLE_SIZE.Z = 4.9`; the eye sits `eyeReliefStuds` behind the dot
on the sight axis, so the apparent sizes below are at that distance.

| Name | Value | mm at 0.28 m/stud | Why |
|---|---|---|---|
| `aim.eyeReliefStuds` | 0.35 | 98 | a cheek weld; section 4(b) |
| sight line above the rail | 0.085 | 24 | the near-plane margin, section 6 |
| hood aperture (clear window) | 0.111 dia | 31 | `2*atan(0.0554/0.35) = 18.0 deg` = **30 % of the frame width**, against Karen's ref-1 at 36 % |
| hood outer | 0.147 dia | 41 | `23.7 deg` = **40 % of the frame width**; ref-1's dark rim reaches ~45 % |
| hood depth | 0.05 | 14 | a rim you can see is a rim with a thickness; a Micro's body is 68 mm but an open hood is not a tube |
| `DOT_DIAMETER` | 0.006 | 1.7 | `0.98 deg` at this relief: a third of a stag's 2.4 deg at 50 m (requirement 4). A real 2-MOA dot is 0.033 deg and would be half a pixel |
| `HOOD_SEGMENTS` | 16 | -- | section 4(c) |
| glass transparency | 0.86 | -- | *"clear (lightly tinted)"*; the tint is ref-1's blue-green |

**These are held by a spec, not by this table.** `semiauto.spec` asserts the clear window and the
dot in DEGREES at the shipped eye relief, with both ends bounded -- so a later change to the relief
or the hood that quietly destroys the sight picture fails the gate instead of reaching Karen.

---

## 6. The one risk that was measured: the near plane

Bringing the eye from 0.9 to 0.35 studs puts it INSIDE the receiver's z span (the action spans
z +0.3187..+1.1753; the eye lands at z +0.8335). Roblox clips at `NearPlaneZ = 0.1`, so anything
within 0.1 studs of the camera disappears -- a hole in the gun would be the obvious way to get this
wrong.

It does not happen, and the reason is a number: the sight line sits **0.085 studs above the
receiver's top face** (y +0.298 against the action's +0.2130). At the BOTTOM EDGE of the frame --
25 degrees below the axis at FOV 50 -- the receiver's top is `0.085/tan(25 deg) = 0.182 studs`
away, well outside 0.1. The clipped cone (everything steeper than `atan(0.085/0.1) = 40 deg` below
the axis) is entirely off the bottom of the screen. That 0.085 is why the sight has a MOUNT and is
not laid straight on the rail.

**What this does NOT fix, and it is honest to say so:** the barrel. A sight 0.178 studs above the
bore means the barrel's top edge converges on the sight line with distance -- at the muzzle it is
`atan(0.1026/3.28) = 1.8 degrees` below the dot -- so the lower part of the window is gun, in this
game as on a real shotgun with a low-mounted dot. The same is true in the before frame. It cannot
be removed without a riser no hunter would fit.

---

## 7. What `clearFromBlend` becomes

Task 227's fade stays in `Gun.Piece` and in `Viewmodel.clearAtAim`, with **no shipped row using
it** -- the same standing the `onlyFor` filter has had since task 148 retired the row that first
used it. It is kept because it is the one answer to "this piece must stop blocking the sight line",
and the day a bought optic is split into its own glass group it is what that glass reads.

One real defect in it is fixed here, carried forward from task 227's review (note (a)): it gates on
the MODE NAME alone, so with `FIRST_PERSON` off -- where `Mode` still reaches `"Aiming"` and the
viewmodel is drawn over a third-person camera -- a housing would dissolve with the eye nowhere near
it. It now takes whether this is the first-person gun, and `semiauto.spec` drives both answers.
