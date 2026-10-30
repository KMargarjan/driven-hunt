# Solo on the whole range: one span, three bounds, two pictures, one owner each

Task 313. Design to `reviews/task-313/BRIEF.md`, which overrides anything older in `docs/`,
`TASKS.md` and the earlier design. **This is a DELTA to `docs/design/shooting-range-lobby.md`
(task 306), which stays in force for everything it does not replace**, and that document is itself a
delta to `docs/design/shooting-range.md` (task 298).

Nothing below is measured in a running game. Every spatial claim is arithmetic off shipped symbols,
cited by file and symbol; every engine fact is cited to a shipped caller or to the Roblox
documentation; everything that needs an eye or a frame is in §15.

---

## 0. The delta map

| `shooting-range-lobby.md` | This document |
|---|---|
| §4.3 the shot's ignore list | **extended** (§8): unchanged code, with the proof that it still holds at six animals in one wide span, and the exclusion-before-cap order read off `Cast.candidates` |
| §4.4 the picture (`Mask`) | **extended** (§7): `Mask` keeps its rule and its folder and gains a wider window; a **second owner** is added for the second picture, by file |
| §5.3 six windows in one corridor | **replaced** (§2–§4): the window is no longer `mat ± 18`. It is derived per station and per lane from three bounds, and the leg becomes the span plus one apron |
| §6 the paces | **extended** (§5): the two ISSF paces keep the ISSF definition; the crossing TIMES are re-expressed over the new span. No speed moves |
| §9 interfaces | **extended** (§10) |
| §12 numeric targets | **T3 and T6 replaced, T5 re-expressed, T12 extended, T15–T18 new** (§13) |
| §15 item 7 (*"does the animal vanish at the window's edge? default yes"*) | **closed by Karen and the Director** (§1). It vanishes only in the apron now |
| everything else (§1, §2, §3 owners, §5.1–5.2, §5.4, §7, §8, §10, §11, §13, §14, §16) | **unchanged** |

---

## 1. What this system must do, and what it must not do

Karen, 2026-10-30 ~09:30 UTC: *"hill is perfect, we will need to improve isolated view where when I
click E it will make that I am alone in all shooting range and then we can test all way running
waling ect animal, now is to short for one specific stand"*.

### Must do

1. **E at a station starts that man's solo view, and his animal crosses as much of the range as the
   built earth and his own bay allow** — not his station's 36-stud opening. §2–§4 derive the span;
   §5 re-expresses the times.
2. **While solo, his client draws his own animal and nothing else alive**: the other five animals
   stay hidden (shipped `src/client/Range/Mask.luau`), and **other players' characters are hidden
   too**, so "I am alone" is literal (§7).
3. **Many men still play at once, and each may hit only his own animal** (§8). Unchanged mechanism.
4. **The safety envelope holds at the new widest angle**: every shot whose aim point is on his
   animal's silhouette still ends in earth, from both firing positions and at all three distances
   (§3, §13 T6).
5. **Ground and treestand both keep working; the three distances stay 107 / 125 / 179**
   (`Range.LAYOUT.DISTANCES_STUDS`).
6. **Both states are testable**: the whole change is behind one flag, born off, and the new span is
   reachable by parameter as well as by flag (§9).

### Must NOT do

- **No second window predicate.** One function answers "where may his animal be, and therefore what
  does he see and what may he hit", and the server's door (`Range.ignoredFor`), the client's picture
  (`Range.maskFor` → `Mask.setWindow`) and the crossing timer (`timeWindow`) all read **that one
  function**. Today they already read one (`RangeData.windowSpanFor`); that stays true.
- **No new cast, no new ray, no second renderer of an animal, no client-authored hit.** Unchanged
  from §1 of the base delta.
- **No change to `Shotgun.CONFIG.CLAIM.*`, `Rules.unsafeLine` or the safety-arc penalty.**
- **No change to the three distances, no new asset, no new LAYOUT geometry row that moves a built
  part.** The hut, the mats, the posts, the benches, the decks, the banks and the heap are all built
  exactly where step B10 left them (§3.4 names the one thing a later LOOK task may widen).
- **No second reader of the new flag.** One module reads it (§9); the client is TOLD.
- **No write by the range to any instance the range did not create, except the client-local
  transparency of (a) the range's own targets and (b) other players' characters** — and those are
  two disjoint sets with one owner each (§7).

---

## 2. The three numbers that used to be one

`LAYOUT.WINDOW_STUDS` = 36 is read by **four** places in `src/shared/Range/init.luau` today, for
three unrelated purposes. The brief's first requirement is to separate them by name.

| # | What the number means | Who reads it today | What it becomes |
|---|---|---|---|
| 1 | **The ISSF pace definition.** `slow` is 10 m in 5.0 s and `fast` 10 m in 2.5 s, so a pace's stud speed is `WINDOW_STUDS / CROSSING_SECONDS` | `Range.paceSpeedFor` (`layout.WINDOW_STUDS / seconds`) | **unchanged, 36.** Read through the new named accessor `Range.paceWindowStuds(layout)` and by **nothing else**. `slow` stays 7.20 studs/s and `fast` 14.40 |
| 2 | **The apron geometry.** `laneLength = WINDOW + 2*APRON` = 76 is what the corridor, the derived berm width, the footprint, the terrace and the plate span are all measured from | `Range.laneLength`, and through it `corridorSpan`, `bermWidthFor`, `footprintFor`, `fieldFor`, `Build`'s plate | **unchanged, 36 + 40 = 76.** Not one built edge moves. This is the whole reason the span is NOT implemented by growing `WINDOW_STUDS` |
| 3 | **What a man SEES and what his shot may HIT** | `Range.windowSpanFor` (`mat.X ± 18`), and `sightHalfWidthAt` (`ahead × 18 / 107`) | **replaced by `Range.sightSpanFor`** (§3), derived per station and per lane, and by `Range.backstopSlope` (§3.1) |

**This is exactly the trap the brief named.** Had the masking window simply become 196 and kept
feeding `paceSpeedFor`, `slow` would have become 39.2 studs/s and `fast` 78.4 — faster than
`Boar.CONFIG.PACE.SPRINT_SPEED` 38 and no longer ISSF. Separating (1) from (3) by name is what makes
that impossible rather than merely unintended, and `range.spec` asserts it: `paceSpeedFor` is driven
with a layout whose `sightSpanFor` is wide and must still answer 7.20 / 14.40.

**`LAYOUT.WINDOW_STUDS` is not renamed in this task.** Renaming a frozen row touches `Build`, the
server owner, `range.spec` in nineteen places and `range_mask.spec`; the comment on the row and the
new accessor carry the meaning instead, and `range.spec` asserts the accessor is the only reader in
`src/` (a grep case, the shape `range.spec` already uses for "no `.CFrame =` under `src/server/Range/`").

---

## 3. The span, as arithmetic

### 3.1 Three bounds, intersected. Every number off `LAYOUT`.

Anchor-relative X (+x east), downrange taken out by sign as every other function in the module does.
All six values below are computed by shipped functions:

```
spotSpan            = (SPOT_COUNT-1) * SPOT_SPACING = 5 * 24          = 120   Range.spotSpan
laneLength          = WINDOW + 2*APRON = 36 + 40                      = 76    Range.laneLength
corridorSpan        = [-38, 158]                            width      196    Range.corridorSpan
bankReach           = BANK.beyondStuds + BANK.size.X = 6 + 12         = 18    Range.bankReach
bermWidthFor        = 120 + 76 + 2*18 = 232 (already on the 4-grid)   = 232   Range.bermWidthFor
bermSpanFor         = 60 +- 116                        = [-56, 176]           Range.bermSpanFor
bermCrestFaceZ      = distanceMax + behindStuds - depth/2 = 179+17-4  = 192   Range.bermCrestFaceZ
bermToeZ            = 192 - slopeRun 8                                = 184   Range.bermToeZ
```

**Bound 1 — THE BACKSTOP.** The shot must reach earth that is at FULL height, not the toe's edge.
`Range.bermColumns` tapers the crest by `shoulderDropStuds` 5 over the outer `shoulderStuds` 16 of
the span (`taper = clamp(edge / shoulderStuds, 0, 1)`), and `range.spec`'s shipped case *"fills an
uneven earth hill"* holds `column.top >= deckEye` (17.5) only for the columns at `taper == 1`. So the
load-bearing backstop is the berm's span less the two shoulders, tested at the crest face:

```
backstop interval  E = [-56 + 16, 176 - 16] = [-40, 160]     at  Zcrest = 192
```

The two 18-stud side banks (`Range.bankBalls`, x [164,176] and [-56,-44], z 172..186) and the
tapered shoulders are then **margin, not load-bearing** — which is deliberate: the bound must not
depend on a bank's 12-stud width or on the toe's edge, both of which a later look task could move.

For a firing point at `x_s` on the firing line and a lane distance `d`, the ray through an aim point
`x_a` at the lane crosses `Zcrest` at `x_s + (x_a - x_s) * Zcrest/d`. Inverting:

```
B(s, d) = [ x_s + (-40 - x_s) * d/192 ,  x_s + (160 - x_s) * d/192 ]
width of B = 200 * d / 192 = 1.04167 * d      -- the same at every station
```

**The widest ray this range may ever be offered is one angle, and it is a constant of the built
earth:** from mat 1 to the backstop's east corner, `atan(160/192)` = **39.806°** (and from mat 6 to
the west corner, the same). Today's worst is `atan(18/107)` = 9.55°. `Range.backstopSlope(layout)`
returns `0.8333`, and `Range.sightHalfWidthAt(layout, ahead)` becomes `ahead * backstopSlope` — one
number, read by the span, by the hut bound and by the berm's own in-fan spec case.

**The deck is always safer, by one line of algebra.** From the deck the ray starts
`STAND.backStuds` = 14 further back, so both legs grow: the ratio is `(192+14)/(d+14)` against
`192/d`, and `(Z+b)/(d+b) < Z/d` exactly when `d < Z`, which holds for every lane
(179 < 192). So **one span per station and lane, computed for the BENCH, is safe for both firing
positions** — and it does not move when a man climbs his own ladder, which is what keeps the picture
still while he climbs.

**Bound 2 — THE CLEAR FAN (his own bay's opening).** Only one piece of a station's furniture reaches
the bore's own height. The bench bore is `shelf + HighSeats.AIM_RISE_STUDS` = **shelf + 5** (the
number `range.spec`'s `deckEye` is built from):

| His own furniture | Top, over the shelf | Off axis | Ahead of the mat | In the bore's plane? |
|---|---|---|---|---|
| Bench (`LAYOUT.BENCH`) | 2.7 | ±3 | 2.9 .. 4.1 | no — the shot passes 2.3 studs over it |
| Prompt post (`LAYOUT.POST`) | 4.0 | +2.4 .. +3.6 | 6.4 .. 7.6 | no — 1.0 stud over it |
| Hut roof (`LAYOUT.HUT`) | 9.0 .. 9.6 (bottom .. top) | ±6.5 | −4.5 .. 10.5 | no — 4 studs above it |
| **Hut corner posts** (`Range.hutPostPositions`) | **9.0** (to the roof's underside) | **±6.05 ± 0.45** | **9.6 .. 10.5** | **YES** |

So the two downrange hut posts frame his bay, and the ray must stay inboard of them through their
whole Z extent — `x(10.5) <= 5.6`, the post's inner face:

```
f = (HUT.roofSize.X/2 - HUT.postSection) / (HUT.roofAheadStuds + HUT.roofSize.Z/2)
  = (6.5 - 0.9) / (3 + 7.5) = 5.6/10.5 = 0.53333
C(s, d) = [ x_s - f*d , x_s + f*d ]
```

This is not an arbitrary cap. It is **what he can see out of his own firing hut** — source 1's bay —
and it is visible to Karen as the frame it is. From the **deck** nothing of his own station is in the
bore's plane at all: the ray falls from 17.5 to 5 over 121 studs, so at the hut's downrange edge
(24.5 studs ahead of the deck) it is at 15.0, above the roof's 9.6. The deck shoots over his own hut,
which is the point of a deck.

**Bound 3 — THE APRON.** The leg is the span plus one apron at each end (§4), and the leg may not
leave the corridor or the animal walks into the built cover:

```
A = [ corridorWest + APRON , corridorEast - APRON ] = [-18, 138]      width 156
```

**The silhouette.** The aim point may be anywhere on the animal, so the bounds on the aim point are
bounds on the animal's CENTRE shifted by its half length. `Boar.CONFIG.BODY_SIZE` is
`Vector3.new(2, 3, 5.5)` (width, height, length) and the stag's `KINDS` row is
`Vector3.new(1.8, 4.8, 7.05)`; on the range the body lies along X, so the worst half length is
3.525. **One new LAYOUT row, `SIGHT.silhouetteStuds = 4`**, with that provenance written on it (and
it is the same measurement `BERM.toeClearStuds`' comment already records: *"the released boar's trunk
measures 2 x 3 x 5.5 ... so half its length is 2.75"*).

```
sightSpanFor(s, d) = ( shrink(B(s,d), 4) INTERSECT shrink(C(s,d), 4) ) INTERSECT A
laneEndsFor(s, d)  = sightSpanFor(s, d) grown by APRON at each end        (subset of the corridor)
```

### 3.2 The spans, worked through

`d/192` = 0.557292 (107), 0.651042 (125), 0.932292 (179). `f*d` = 57.07, 66.67, 95.47.

**107 studs:**

| spot | B shrunk | C shrunk | ∩ A | **span** |
|---|---|---|---|---|
| 1 (0) | [−18.29, 85.17] | [−53.07, 53.07] | [−18, 53.07] | **71.07** |
| 2 (24) | [−7.66, 95.79] | [−29.07, 77.07] | [−7.66, 77.07] | **84.73** |
| 3 (48) | [2.96, 106.42] | [−5.07, 101.07] | [2.96, 101.07] | **98.11** |
| 4 (72) | [13.58, 117.04] | [18.93, 125.07] | [18.93, 117.04] | **98.11** |
| 5 (96) | [24.21, 127.66] | [42.93, 149.07] | [42.93, 127.66] | **84.73** |
| 6 (120) | [34.83, 138.29] | [66.93, 173.07] | [66.93, 138] | **71.07** |

**125 studs:** 80.67 / 100.34 / 115.96 / 115.96 / 100.34 / 80.67
(spot 1: B [−22.04, 100.17] ∩ C [−62.67, 62.67] ∩ A → [−18, 62.67])

**179 studs:** 109.47 / 133.47 / **156** / **156** / 133.47 / 109.47
(spot 3: B [−30.04, 148.42] ∩ C [−43.47, 139.47] ∩ A → [−18, 138] — **the apron cap binds, which
means the middle four stations get every stud of corridor the turn-around leaves**)

### 3.3 T6 re-swept: the widest shot at the chosen span, and where it ends

The widest aim point is `span.max + 4` (or `span.min - 4`). By construction the backstop bound is
tight where it binds, so the worst ray lands exactly on the backstop's corner:

| spot, lane, position | aim point | x at Zcrest | inside [−40, 160]? | angle |
|---|---|---|---|---|
| 1, 107, bench | +89.17 | 89.17 × 192/107 = **160.0** | yes, on the corner | **39.81°** |
| 1, 107, deck | +89.17 | 89.17 × 206/121 = **151.8** | yes, 8.2 studs clear | 36.39° |
| 1, 125, bench | +104.17 | 104.17 × 192/125 = **160.0** | yes, on the corner | 39.81° |
| 1, 179, bench | +99.47 | 99.47 × 192/179 = **106.7** | yes, 53 studs clear (the hut cap binds first) | 29.07° |
| 3, 179, bench | +142.0 | 142.0 × 192/179 = **152.3** | yes, 7.7 studs clear (the apron cap binds first) | 38.43° |
| 6, 179, bench (west) | −22.0 | 120 + (−142) × 1.0726 = **−32.3** | yes, 7.7 studs clear | 38.43° |

**The maximum off-axis angle anywhere on this range becomes 39.81°, from 9.55° today, and it is the
angle the built earth subtends from the outermost mat.** The brief's 58.7 / 54.6 / 44.6° are the
angles to the bank's OUTER face at 176; they are refused, with this arithmetic, because at 107 a ray
to 176 crosses `Zcrest` at 316 studs — 156 studs past the end of the heap and out of her place
altogether.

Vertical clearance is unchanged in kind: a level shot from the bench bore (shelf + 5) at the chest
meets the heap at 5 of its 21 studs, and from the deck at 3.9 — the base design's own T6 numbers. The
only change is the slant range, 192/cos(39.81°) = 250 studs instead of 192, which drops the bullet
slightly further and therefore lower into the same earth.

### 3.4 The one thing that could widen the span, and why it is not this task

If the hut's bay were opened to the full backstop fan, the clear-fan bound would vanish and every
station would get **103.17 / 118.17 / 156** (the backstop-and-apron numbers), run crossings
4.30 / 4.92 / 6.50 s at every station. The arithmetic for it is one row:

```
HUT.roofSize.X >= 2 * ( backstopSlope * (roofAheadStuds + roofSize.Z/2) + postSection )
               =  2 * ( 0.8333 * 10.5 + 0.9 ) = 19.3   ->  20 on even studs (today 13)
```

At 24-stud spacing that leaves 4 studs between neighbouring huts. It moves a BUILT part, so it needs
a rebuild of her place and a frame Karen looks at — which is the LOOK lane (step B10), not this one.
**Director decision asked for, §16 item 2. It blocks nothing: the span is a derived function and
widening the hut changes its answer with no code change at all.**

---

## 4. The leg, the turn-around, and the banks — confirmed, not assumed

**`laneEnds` becomes the span plus one apron, for EVERY station, and not only for a solo occupant.**
There is no non-solo occupant: a station's animal exists only while someone is measured at it
(`occupancy()` → `release`, design 7.4), and with the flag on every occupied station runs the wide
leg. Conditioning the leg per player would make two animals on one station's lane, which cannot
happen (`Range.CONFIG.MAX_TARGETS = SPOT_COUNT`, one trial per spot).

**Why the leg keeps an apron at all.** `timeWindow` arms on LEAVING the span and records on exit
(`trial.windowArmed`, `trial.windowEnteredAt`). If the leg equalled the span, the animal would be
released inside the span and never leave it: `windowEnteredAt` would stay nil, **no crossing would
ever be recorded**, and T3/T5's instrument and the board's `crossing %.2f s` would both die quietly.
The apron is what keeps the instrument alive, and it is also the turn-around out of sight, which is
its shipped purpose (`LAYOUT.APRON_STUDS`' own comment).

**The brief's claim about the banks is wrong by 6 studs, and the correction is in this design's
favour.** The brief says *"`bankReach` ... so the two bank NEAR faces sit at −38 and +158"*. Read off
`Range.bankPosition` and `Range.bankSpanFor`:

```
bankPosition(leg 1).X = corridorEast + (beyondStuds + size.X/2) = 158 + (6 + 6) = 170
bankSpanFor(leg 1)    = [164, 176]      -- NEAR face 164, OUTER face 176
bankSpanFor(leg 2)    = [-56, -44]      -- NEAR face -44, OUTER face -56
```

−38 and +158 are the **corridor's** ends. The banks' near faces stand **`BANK.beyondStuds` = 6 studs
beyond them**, which is task 298 step B2's MEASUREMENT: *"built on the end, the target hit the bank's
inner face and STOPPED 7.8 studs short of an end it could never reach, so no leg ever finished"*. So:

- the turn-around at the corridor's end is **6 studs clear of the cover**, which is why it can happen
  at all;
- the banks' OUTER faces are 176 and −56, which are the berm's own faces — the identity
  `range.spec` already asserts (`bermSpanFor` == `bankSpanFor` outer);
- **no new geometry is needed, and none is built.** The leg at the 179 lane is the corridor exactly,
  −38 .. 158, for every station.

At the 179 lane all six animals therefore share one leg and turn at the same two points. They cannot
collide (`Boar.Body.useCollisionGroup` gives each animal its own collision group —
*"so animals do not touch each other"*), cannot take each other's bullets (§8), and five of the six
are invisible (§7).

**The animal is released outside the span, by construction.** `release` spawns at
`laneEnds(..., trial.leg + 1, ...)`, which is one apron outside the span, so `windowArmed = true` at
release is correct and the first entry is a real one. `range.spec` asserts the release point is never
inside `sightSpanFor`, for all six stations and all three lanes.

---

## 5. The crossing times, re-expressed (the arithmetic the brief asked for)

Speeds are unchanged and still come from one place each: Karen's four from the injected
`Boar.paceSpeed` (`PACE.WALK_SPEED` 4.5, `TROT_SPEED` 11, `RUN_SPEED` 24) and ISSF's two from
`paceWindowStuds / CROSSING_SECONDS` = 36/5.0 = **7.20** and 36/2.5 = **14.40**.

**Seconds across the span = span / speed.** At the narrowest station of each lane (spots 1 and 6):

| lane | span | walk 4.5 | slow 7.2 | trot 11 | fast 14.4 | run 24 |
|---|---|---|---|---|---|---|
| 107 | 71.07 | 15.79 | 9.87 | 6.46 | 4.94 | **2.96** |
| 125 | 80.67 | 17.93 | 11.20 | 7.33 | 5.60 | **3.36** |
| 179 | 109.47 | 24.33 | 15.20 | 9.95 | 7.60 | **4.56** |

At the widest (spots 3 and 4):

| lane | span | walk | slow | trot | fast | run |
|---|---|---|---|---|---|---|
| 107 | 98.11 | 21.80 | 13.63 | 8.92 | 6.81 | **4.09** |
| 125 | 115.96 | 25.77 | 16.11 | 10.54 | 8.05 | **4.83** |
| 179 | **156** | 34.67 | 21.67 | 14.18 | 10.83 | **6.50** |

Spots 2 and 5 sit between: at 179, span 133.47 → run **5.56 s**.

**Today, for comparison** (`windowSpanFor` = 36 studs, every station, every lane): walk 8.00, slow
5.00, trot 3.27, fast 2.50, run **1.50 s**. So the run crossing Karen called *"to short"* grows by
**2.0× to 4.3×**, and at her long lane in the middle of the line she gets 6.50 s across 156 studs.

**The brief's 196-stud figures (run 8.2 s) are not reachable under the unchanged envelope rule**, and
§3.3 is the arithmetic: 196 studs needs earth out to x 277 at the 107 lane, a heap 433 studs wide
instead of 232, on ground her census never covered (`Range.ANCHORS["forest-test"]`'s own comment:
*"MEASURED IN HER PLACE 2026-10-29 ... 990 ground samples"* over the footprint x 2532..2788 only) and
falling to 141–144 where the asphalt road crosses. §16 item 1 puts the trade in front of the
Director in one line.

**The ISSF paces keep the ISSF definition, and it stays checkable.** The live timer now measures the
span, not 36 studs, so the 5.0 s / 2.5 s figures become a pure-arithmetic case rather than a measured
one: `crossingSeconds(paceWindowStuds(LAYOUT), paceSpeedFor("slow", LAYOUT, speedOf))` == 5.00
exactly, and the measured span crossing scaled by `36 / span` must land on it within T5's tolerance.
Both are in `range.spec` (the first is already there, at the `WINDOW_STUDS = 72` case).

---

## 6. Owners — one writer each, named

Only the rows that change. Everything else in §3 of the base delta stands.

| System | THE one writer | On disk | Changed? |
|---|---|---|---|
| Where this station's animal may be (the span), the leg, the crossing timer | `ServerScriptService.Range` (`state.trials`), through the pure `ReplicatedStorage.Range` | `src/server/Range/init.luau`, `src/shared/Range/init.luau` | **unchanged owner**, new arithmetic |
| Which range animals this ONE PLAYER can SEE (`LocalTransparencyModifier` on parts under `Workspace.RangeTargets`) | `StarterPlayerScripts.Range.Mask` | `src/client/Range/Mask.luau` | **unchanged owner**, wider window told to it. No behaviour change in the module |
| **Which OTHER PLAYERS this one can see** (`LocalTransparencyModifier` on parts under another player's `Character`) | **`StarterPlayerScripts.Range.Solo`** | **`src/client/Range/Solo.luau` (new)** | **NEW owner.** Disjoint from `Mask`, from `Camera.Rig` and from `Camera.Viewmodel` by construction and by refusal (§7) |
| `LocalTransparencyModifier` on the LOCAL character | `StarterPlayerScripts.Camera.Rig` | `src/client/Camera/Rig.luau` | **unchanged, and never touched by the range** |
| `LocalTransparencyModifier` on the viewmodel's own clone | `StarterPlayerScripts.Camera.Viewmodel` | `src/client/Camera/Viewmodel.luau` | **unchanged** |
| Which instances one shot may not see | `ServerScriptService.Weapon` (`ignoreFor` builds and filters); `Range.ignoredFor` answers | `src/server/Weapon/init.luau` | **unchanged** — no new seam, no new provider |
| The solo flag's value | `ServerScriptService.Range` (`Range.SOLO_VIEW`), **once** | `src/server/Range/init.luau` | **new, one reader** (§9) |
| The client root that wires both pictures | `StarterPlayerScripts.RangeBoot` | `src/client/RangeBoot.client.luau` | one more `start` and one more `step` |

Mirror these rows into `GAME_DESIGN.md` "System owners" in the same commit as the first code.

---

## 7. The second picture: `src/client/Range/Solo.luau`

### 7.1 What it is, and what it is told

```lua
-- Range.Solo: THE ONE WRITER of `LocalTransparencyModifier` on parts under ANOTHER PLAYER'S
-- Character. Borrowed whole from `src/client/Range/Mask.luau` -- the same sweep, the same
-- level-triggered/edge-written apply, the same restore -- with ONE predicate changed: membership is
-- "under a remote player's character", not "under the range's targets folder".
Solo.start(seams: {
    players: (() -> { any })?,      -- nil = Players:GetPlayers
    me: any?,                       -- nil = Players.LocalPlayer
    isTarget: ((Instance) -> boolean)?,   -- nil = RangeData.isTarget
}?): boolean
Solo.setAlone(alone: boolean)       -- TOLD by the server, on the board payload (`record.alone`)
Solo.step(dt: number?)
Solo.stats(): { others: number, hidden: number, shown: number, writes: number,
                refused: number, sweeps: number }
Solo.stop()
```

- **It writes `BasePart.LocalTransparencyModifier` and nothing else.** The property is client-local
  and not replicated, which is why `Camera.Rig` can use it on the local body with no round trip
  (<https://create.roblox.com/docs/reference/engine/classes/BasePart>).
- **In scope:** every `BasePart` under `player.Character` for every player in `players()` that is not
  `me`. That is the character model, its accessories, its outfit plates (`Match.Body`'s OUTFITS) and
  **the Tool in his hand**, because an equipped Tool is parented to the character.
- **Out of scope, and stated rather than discovered:** the engine's own name/health display over
  another player's head. The only levers are `Humanoid.DisplayDistanceType` /
  `NameDisplayDistance` / `HealthDisplayType`, which are ordinary replicated properties and not
  client-local by design. Whether a floating name over an invisible body is tolerable is Karen's
  (§16 item 6); **the fallback is pre-decided**: a client-local write of
  `DisplayDistanceType = None` on those same remote `Humanoid`s, by **this module and nothing else**,
  which is disjoint from the only two writers of that property in `src/` — `Bots.Rig.dress`
  (`src/server/Bots/Rig.luau`) and `Lobby.Build`'s shopkeeper (`src/server/Lobby/Build.luau`), both
  server-side and both on NPC Humanoids that are no `Player.Character`.
- **Sound is not hidden.** "Alone" is a picture. Other players' footsteps and horns still carry; the
  range's own animals are already silent (`SOUND.ENABLED = false`, base delta §7.4).
- **A late character is handled by the sweep, not by a signal** — the same rule and the same reason
  as `Mask`: `Players:GetPlayers()` is read every step, so a player who joins, respawns or streams in
  is hidden on the next frame. No `PlayerAdded`/`CharacterAdded` connection exists to leak or to miss
  a respawn between frames.
- **He leaves the mat → everything comes back.** `setAlone(false)` restores exactly the values the
  module recorded, part by part, on the next step; `stop()` does the same and is the door out.

### 7.2 The disjointness argument, as a partition and not as a promise

Four writers of this one property exist in `src/` after this task. Membership is decided by
ANCESTOR, and the order is total, so no instance is in two sets:

| Owner | Its set | Evidence |
|---|---|---|
| `Camera.Rig` | parts of `Players.LocalPlayer.Character` | `Rig.luau` header: *"the only writer of LocalTransparencyModifier on the local character"*; `hiddenParts` is filled from the local character only, and `setLocalBodyHidden` is the only writer |
| `Camera.Viewmodel` | parts of the model IT created, parented to `workspace.CurrentCamera` | `buildNewGun` sets `LocalTransparencyModifier = 0` on parts it has just cloned and inserts them into `clearParts`; `Viewmodel.clear` destroys the model and clears the list |
| `Range.Mask` | `BasePart`s under `Workspace.<Range.TARGETS_FOLDER>` | `Mask.start`'s `root`, `partsOf`, and `isLocalBody`'s refusal |
| **`Range.Solo`** | `BasePart`s under a remote `player.Character` that are **not** `RangeData.isTarget` and **not** under `me.Character` | this design; the two refusals are code, not comment |

**Rule, written once: the folder wins over the character.** `Solo` refuses anything
`RangeData.isTarget` answers true for — which is one `FindFirstAncestor(TARGETS_FOLDER)` read
(`Range.isTarget`) — so even the pathological case `range_mask.spec` already stages (a character
model parented INTO the targets folder, in *"never writes a part under the local character"*) has
exactly one writer: `Mask`. `Mask` needs no change for this, because its root is the folder and it
never looks outside it.

**The spec asserts the partition rather than describing it** (§14.2): one staged scene holding all
four sets, both modules stepped, and then — for every part — the assertion that exactly one of
`Mask.stats().writes` and `Solo.stats().writes` accounts for it, with `refused` rising on the other.
A case that deletes `Solo`'s `isTarget` refusal fails it.

### 7.3 One staleness defect this closes, because the feature needs it closed

`record.alone`, `record.mine` and `record.window` are all measured on every `Range.recordOf` read
(`copy.mine, copy.window = Range.maskFor(player)`), but a read only happens on a **publish**, and
`publish` is reached from `onRequest`, `Range.look`, a shot, a hit, and `flushMasks` — which runs
only when `state.maskDirty` is set, and that is set only by `release`, `clearTarget` and the
lost-target path. **Nothing publishes when a man changes station.** So today a man who walks from
station 2 to station 4 without pressing E keeps station 2's `mine` and window: he sees station 2's
animal and his own shot ignores his own new one. With a 156-stud span and other players hidden, that
becomes "I am alone looking at somebody else's boar".

**Fix, in the owner that already measures it, at the rate it already measures it:** `scan` compares
each watcher's measured station (`playerSpot`) with the previous tick's (`state.spotOf[userId]`, one
new table) and sets `state.maskDirty` on any change. Cost: one comparison per watcher per scan tick
(`STEP_HZ` 10), and the push itself is the one `flushMasks` already does. **So `alone`, `mine` and
`window` can never be more than 0.1 s stale.** `range.spec` asserts it: a fake player moved from
station 2 to station 4 with no request gets a push whose `mine` is station 4's trunk.

### 7.4 Why the picture is two modules and not one

One module writing both sets would also be "one writer". It is two because the brief requires the
second picture's owner to be a NAMED file disjoint from `Mask`'s writes, and because two owners can
be asserted independently: a defect in the character sweep cannot then hide an animal, which is
exactly the failure `docs/PROJECT_CONTEXT.md` records (*"one predicate answered two unrelated
questions, so mounting hid both the crosshair and the weapon"*). The cost is ~70 lines of borrowed
bookkeeping. **`Mask.luau` is NOT refactored into a shared helper in this task** — it is shipped,
reviewed, and the only thing holding T12 — and the extraction is queued as a fix-before-release note.

---

## 8. The hit side at six animals in one wide span (decision c)

**No code changes here. The design's job is to show the shipped rule still holds, with evidence.**

**(a) The five that are not his are excluded unconditionally, so the span's width cannot matter to
them.** `Range.ignoredFor`:

```lua
local hide = spot ~= mine
if not hide then  -- only HIS OWN is window-tested
    local minX, maxX = RangeData.windowSpanFor(anchor, spot, RangeData.LAYOUT)
    hide = not RangeData.inWindow(minX, maxX, ...)
end
```

Widening the span can therefore only make **his own** target hittable more of the time. It can never
add a foreign body to his shot's world. The one line that changes in this function is the span's
source (`sightSpanFor` instead of `windowSpanFor`), read from the same place `Range.maskFor` reads it
— which is what keeps the shot's door and the picture one question.

**(b) `CLAIM.MAX_TARGETS` (8) cannot cut a body before the ignore list excludes it, and that is the
engine's own order, not a convention.** `Weapon.castWithRewind` passes the list built by `ignoreFor`
(the shooter's character, the `WeaponEffects` folder, and the provider's answer) straight into
`findCandidates`. In `src/server/Weapon/Cast.luau`, `Cast.candidates`:

1. sets `params.FilterType = Enum.RaycastFilterType.Exclude` and
   `params.FilterDescendantsInstances = ignore`;
2. runs `Workspace:GetPartBoundsInRadius(...)` with those params — so the excluded trunks and
   everything welded under them are **never returned at all**
   (<https://create.roblox.com/docs/reference/engine/classes/WorldRoot#GetPartBoundsInRadius>);
3. only then sorts the surviving roots by distance to the muzzle and cuts: `if index > maxTargets
   then break`.

The exclusion is applied by the engine query; the cap is applied to what survived it. Excluding a
trunk excludes its descendants (`FilterDescendantsInstances`), and `Range.isTarget`'s own comment
records that the zone parts are welded **under** the trunk, so one instance per animal is the whole
exclusion. **Worst case arithmetic:** `Range.CONFIG.MAX_TARGETS = SPOT_COUNT` = 6 animals exist, 5
are excluded, 1 candidate reaches a cap of 8. There is no reachable state in which the cap bites on
the range.

**(c) Both call sites keep their meaning.** `ignoreFor` is asked twice per shot at most:
`lookAhead` (the aim ray and the target popup) with no rewind, and the fire path with
`Weapon.rewindFor(...)` — the same number the shot carries. `Range.ignoredFor` reads his own
target's past position through `targetPositionOf`, which is the SAME history ring
`Weapon.castWithRewind` judges the shot against, so the animal stays hittable exactly where it is
drawn even in the apron's last stud.

**(d) The one hole, named and out of scope.** The CLIENT's own claim path has no ignore provider:
`src/client/Weapon/Claim.luau`'s `Claim.targets` collects every `Damageable` root within reach,
bounded by the same `CLAIM.MAX_TARGETS`, and `LocalTransparencyModifier` changes nothing a bounds
query can see. With `HIT_CLAIM` lit, a client at station 1 could claim a hit on station 2's animal.
It is unreachable today — `Flags.DEFAULTS.HIT_CLAIM.default = false` — and the brief forbids touching
`CLAIM.*` or the claim path in this task. **Queued as a named task**, not left to be discovered:
*"the claim path needs the range's ignore list before `HIT_CLAIM` is lit"* (§16 item 4).

---

## 9. The feature flag

This is a feel-critical path, so CLAUDE.md's rule applies in full.

```lua
RANGE_SOLO = {
    default = false,
    owner = "ServerScriptService.Range",
    born = "2026-10-30 task 313",
    expires = "2026-11-20",        -- 21 days, the ceiling in feature-flags.md section 12
    why = "E at a station makes a man alone on the whole range: his animal crosses as much of the "
       .. "lane as the built earth and his own bay allow (71-156 studs instead of 36), and every "
       .. "other player's body is hidden for him. OFF is exactly the game before task 313 -- the "
       .. "window is his own mat +- 18, the leg is 76 studs, and nobody is hidden.",
} :: FlagRow
```

- **`Flags.MAX_FLAGS` 21 -> 22, and the Builder says so rather than quietly retiring somebody else's
  row.** The table holds exactly 21 rows today, so `flags.spec`'s rot tripwire refuses the
  twenty-second — the cap doing its job. The two ways out are the two task 238 listed and the first
  is still queued as TASKS.md 82b, which is the Director's call. This is one line either way
  (§16 item 3).
- **One boundary reads it**, beside the row that already does: `Range.SOLO_VIEW = Flags.isOn("RANGE_SOLO")`
  in `src/server/Range/init.luau`, next to `Range.ENABLED = Flags.isOn("RANGE")`.
- **Passed inward as a parameter**, in the shape `enabled` already uses:
  `Range.start`'s `seams.solo` (`if seams.solo == nil then Range.SOLO_VIEW else seams.solo == true`)
  → `state.solo` → the `wide` argument of `RangeData.sightSpanFor` and `RangeData.laneEndsFor`, which
  are pure and take it explicitly. **Both states are therefore reachable by parameter while the row
  sits at one of them**, which is what `range.spec` drives.
- **`wide = false` is bit-for-bit today's game**: `sightSpanFor(..., false)` returns `mat.X ± 18`
  exactly (it *is* `windowSpanFor`'s body) and `laneEndsFor(..., false)` returns
  `laneCentre ± laneLength/2`. `range.spec` asserts the OFF branch against the shipped functions,
  not against numbers typed in the spec.
- **The client reads no flag.** The server resolves it and the board payload carries the decision
  (`record.alone`), so there is one judge of "am I alone" and one reader of the row.

---

## 10. Interfaces, with types

### 10.1 `ReplicatedStorage.Range` — pure, new and changed

```lua
-- (1) THE ISSF PACE WINDOW. The ONLY reader is `paceSpeedFor`. 36 studs, and it never moves with
-- what a man can see.
function Range.paceWindowStuds(layout): number

-- (2) THE BUILT EARTH, as the two bounds a shot has to end inside. PURE.
function Range.backstopSpanFor(anchor: Vector3, layout): (number, number)   -- bermSpan less the shoulders
function Range.backstopSlope(layout): number                                -- 160/192 = 0.83333
function Range.sightHalfWidthAt(layout, aheadStuds: number): number         -- CHANGED: ahead * backstopSlope
function Range.bayHalfSlope(layout): number                                 -- the hut's own opening, 0.53333

-- (3) WHERE HIS ANIMAL MAY BE, AND THEREFORE WHAT HE SEES AND WHAT HE MAY HIT.
-- THE ONE PREDICATE, read by `Range.maskFor` (the picture), `Range.ignoredFor` (the shot's door)
-- and `timeWindow` (the crossing). `wide = false` IS `windowSpanFor` exactly.
function Range.sightSpanFor(
    anchor: Vector3, spot: number, layout, distanceStuds: number?, wide: boolean?
): (number, number)

-- ...and the leg: the span plus one apron at each end, which is a SUBSET of `corridorSpan` by
-- construction, so the turn-around is always 6 studs clear of the built cover.
function Range.laneEndsFor(
    anchor: Vector3, layout, leg: number, downrange: number?, spot: number?,
    distanceStuds: number?, wide: boolean?
): Vector3

-- KEPT, UNCHANGED, AND STILL THE OFF BRANCH: `windowSpanFor(anchor, spot, layout)` ==
-- `sightSpanFor(anchor, spot, layout, nil, false)`. `laneEnds(...)` == `laneEndsFor(..., false)`.
Range.inWindow(minX, maxX, x: number?)            -- unchanged, both edges count
Range.LAYOUT.SIGHT = { silhouetteStuds = 4 }      -- the one new row (section 3.1)
```

`Range.LAYOUT` gains **one row** (`SIGHT`) and changes **none**. No built part moves.

### 10.2 `ServerScriptService.Range`

```lua
Range.SOLO_VIEW: boolean                 -- the ONE read of the flag
Range.start(seams)                       -- `seams.solo` added, defaulting to Range.SOLO_VIEW
Range.spanFor(player: any): (number?, number?)   -- what this man's span is, for the board and the spec
Range.maskFor(player: any): (Instance?, { minX: number, maxX: number }?, boolean)
                                         -- THIRD RETURN: `alone` -- the server measured him at a
                                         -- station AND the solo view is on
Range.ignoredFor(player, rewindSeconds)  -- unchanged signature; reads `sightSpanFor`
Range.stats()                            -- `.spanPushes` added beside `.boardPushes`
```

`Range.mayShoot`, `Range.spotAt`, `Range.positionOf`, `Range.standReach`, `Range.installOver` and the
four composed providers are **untouched** — which is also why this task does not touch the
gun-stripping defect (§14.5).

### 10.3 The remotes

`RangeRequest` (client → server) **gains nothing**: no span, no instance, no "make me alone".
`RangeBoard` (server → client) gains one field on the per-player record:

```lua
record.alone : boolean     -- the SERVER's measurement: he is at a station and the solo view is on
record.window: { minX: number, maxX: number }   -- unchanged field, now the derived span
record.mine  : Instance?                        -- unchanged
```

### 10.4 `StarterPlayerScripts.Range.Solo`

§7.1. Started and stepped by `src/client/RangeBoot.client.luau`, which is already the only thing that
knows both the board remote and a picture; it gains `Solo.start(...)`, one
`Solo.setAlone(record.alone == true)` in the existing `OnClientEvent` handler, and one `Solo.step(dt)`
in the existing Heartbeat. **`Mask` is not modified at all.**

---

## 11. What it reads and writes, and who owns each

| Fact | Direction | Owner | How |
|---|---|---|---|
| the built earth's span and crest face | read, pure | `ReplicatedStorage.Range` (frozen data, no run-time writer) | `bermSpanFor`, `bermCrestFaceZ`, `BERM.shoulderStuds` |
| the hut's own opening | read, pure | same | `HUT.roofSize`, `HUT.postSection`, `HUT.roofAheadStuds` |
| the animal's longest body | read, as DATA | `ServerScriptService.Boar` owns the real number (`CONFIG.BODY_SIZE`, `KINDS.stag`); `LAYOUT.SIGHT.silhouetteStuds` carries it with its provenance | the shared module reaches no server module |
| which station a man is at | measured | `ServerScriptService.Range` (`spotAt` → `positionOf`) | unchanged; never claimed by a payload |
| which instances a shot may not see | the range answers; the WEAPON decides and filters | `ServerScriptService.Weapon` | `Weapon.setIgnoreProvider` ← `Range.ignoredFor` (shipped) |
| where an animal was at a past instant | read | `ServerScriptService.Boar` (`Runtime:cframeAt`, *"THE ONE READER of the ring"*) | `boars.cframeAt` |
| which range animals I can see | **write**, client-local | `StarterPlayerScripts.Range.Mask` | `LocalTransparencyModifier` under `Workspace.RangeTargets` |
| **which other players I can see** | **write**, client-local | **`StarterPlayerScripts.Range.Solo`** | `LocalTransparencyModifier` under a remote `player.Character` |
| `LocalTransparencyModifier` on MY character | **never touched by the range** | `StarterPlayerScripts.Camera.Rig` | — |
| the name tag over another player | **not written** (§7.1) | the engine | fallback pre-decided and owned by `Solo` |
| the flag's value | read **once** | `ServerScriptService.Range` | `Flags.isOn("RANGE_SOLO")` |
| money, points, penalties, licences, the roster, a drive row | not read, not written | `Economy`, `Match`, `HitLog` | — |
| any terrain, any built part, any CFrame | **not written by this task** | `ServerScriptService.Range.Build` | — |

---

## 12. External sources (rules 1 and 2)

1. **BSRC 50 m Running Boar / Time Limit Range** — <https://bsrc.co.uk/time-limit-range/> ·
   <https://bsrc.co.uk/wp-content/uploads/2023/01/50m-Running-Boar-Normal-Runs.pdf>
   Club pages, text © BSRC, **reference only, nothing copied**; live (2023 PDF).
   *Well:* the 10.00 m opening, 5.0 s and 2.5 s, and **the firing hut of BAYS** — a shooter looks out
   of his own bay and the bay frames what he can see. *Badly:* second-hand for the ISSF rulebook,
   which could not be retrieved; a sport range, so nothing about a backstop.
   **Taken:** the pace definition stays 36 studs / 5.0 s / 2.5 s (§2 row 1), and **the bay's opening
   as the clear-fan bound** (§3.1 bound 2) rather than an invented cap.
2. **Wikipedia, 50 metre running target** — <https://en.wikipedia.org/wiki/50_meter_running_target>
   · CC BY-SA 4.0, current. *Well:* confirms the opening and both times independently, and the
   `mixed` event. *Badly:* no construction detail, nothing about safety.
   **Taken:** the independent confirmation that the pace times are a SPECIFICATION and must not move
   with the picture — which is the whole of §2.
3. **US Army TC 25-8, *Training Ranges*, appendix B (surface danger zones)** —
   <https://armypubs.army.mil/> · **US Government work, public domain**, current series; already
   cited in `Range.LAYOUT.BERM`'s own comment for the 6 m berm. And **NRA Range Source Book, ch. 3
   (impact berms)** — <https://www.nrahq.org/pdf/RangeSourceBook.pdf> · © NRA, reference only, the
   standing edition. *Well:* both define the danger area from the **widest firing angle the range
   permits**, and both solve it the same way round: a range **limits the firing angle to the
   backstop** and does not chase the angle with more earth. *Badly:* live-fire documents, so their
   absolute figures (ricochet fans, 5° lateral dispersion) are about a real bullet and are not
   transferable to this engine's ballistics.
   **Taken: the pattern of decision (d)** — the span is derived FROM the backstop (§3.1 bound 1), and
   growing the heap is refused with arithmetic (§3.4, §5). This is borrowed, not invented, and it is
   why the cap is a bound and not a taste.
4. **Roblox Creator Documentation** — `BasePart.LocalTransparencyModifier`, `Players:GetPlayers`,
   `Player.Character`, `OverlapParams.FilterDescendantsInstances`, `WorldRoot:GetPartBoundsInRadius`,
   `Humanoid.DisplayDistanceType`. <https://create.roblox.com/docs/reference/engine/classes/BasePart>
   · <https://create.roblox.com/docs/reference/engine/classes/WorldRoot#GetPartBoundsInRadius> ·
   <https://github.com/Roblox/creator-docs> — the docs repository is **CC BY 4.0** and continuously
   maintained. *Well:* the client-local, non-replicated nature of the transparency modifier, and that
   an Exclude filter is applied by the query itself. *Badly:* silent on whether the modifier hides a
   SKINNED MeshPart, which is why that is still §15 item 2 with a shipped fallback.
5. **This repository, which outranks all of the above for the mechanism.**
   `src/client/Range/Mask.luau` (the sweep, the level-triggered desired state with an edge-triggered
   write, the recorded original, the restore, the refusal counter — `Solo` is this module with one
   predicate changed, and its header says so, rule 9); `src/client/Camera/Rig.luau` (one writer per
   property per set, plus the foreign-write detector that turns rule 3 into a number);
   `src/server/Weapon/Cast.luau` (`Cast.candidates`: exclude in the query, cap after the sort);
   `src/server/Range/init.luau` (`timeWindow`'s armed/entered state machine, which is why the leg
   keeps an apron).
6. **Valve, *Latency Compensating Methods*** —
   <https://developer.valvesoftware.com/wiki/Latency_Compensating_Methods_in_Client/Server_In-game_Protocol_Design_and_Optimization>
   Already adopted and shipped as `Weapon.Rewind` (task 305). Named because **this design adds
   nothing to it**: the animal is the server's own, the shot is judged where the shooter drew it, and
   widening what he can see changes no instant and no lag model.

---

## 13. Numeric targets

| # | Target | Instrument |
|---|---|---|
| **T3** (replaced) | **A man at station *n* has exactly ONE animal drawn for him AND no other player's body drawn**, whatever the other five are doing. `Mask.stats().shown == 1`, `Mask.stats().hidden == targets - 1`, `Solo.stats().hidden == others` | two clients, one screenshot each (Director ops step, §14.4), plus the two `stats()` |
| **T5** (re-expressed) | Measured crossing within **`CROFFING_TOLERANCE` 10 %** of `span / speed` for the station and lane he is on — at station 3, 125 studs: 25.77 / 16.11 / 10.54 / 8.05 / 4.83 s. **And the ISSF identity exactly**: `crossingSeconds(paceWindowStuds, paceSpeedFor("slow"))` == 5.00, `("fast")` == 2.50 | `Range.step`'s own window timer, published as `record.crossingSeconds`; the identity is a pure case. (The base design wrote 5 %; the shipped `Range.CONFIG.CROSSING_TOLERANCE` is 0.10 and this row states the code's number) |
| **T6** (re-swept) | **No shot leaves the range at the new widest angle. Maximum off-axis angle 39.81°** (was 9.55°). Every shot whose aim point is on the animal's silhouette, from both positions, at all three distances, at all six stations, crosses `bermCrestFaceZ` inside `backstopSpanFor` — §3.3's table, worst margin 0.0 studs where the backstop bound binds (by construction) and 7.7 studs where the apron cap binds | a ray sweep from each station across the full span, both positions, three distances: **36 combinations**, in `range.spec` as arithmetic AND once in her place as a real sweep |
| **T12** (extended) | **Both pictures are free when nothing changes.** `Mask.stats().writes` does not climb across 60 idle steps; `Solo.stats().writes` does not either; `Cursor.stats().reasserts` stays 0 | `range_mask.spec`, `range_solo.spec` |
| **T15** (new) | **The mask's write budget at six animals in one wide span.** `writes` settles at `Σ (1 trunk + #ZONES.ORDER + drawn parts)` = 6 × (1 + 5 + 1) = **42** for six boars, then 0 while nothing changes. **Per second it is CHEAPER than today**: writes happen on span edges only, so at run the 196-stud leg costs 2 × 7 = 14 writes every 8.17 s (103 /min) against today's 76-stud leg at 14 every 3.17 s (265 /min) | `Mask.stats().writes` against `.sweeps`, in `range_mask.spec` and live |
| **T16** (new) | **`Solo`'s sweep costs ≤ 0.1 ms per frame at 16 players**: one `GetPlayers`, 15 `Character` reads, ≤ 15 × ~20 `BasePart`s visited, no write | `Solo.stats().sweeps`, the Studio microprofiler (ops step) |
| **T17** (new) | **Nothing of his own station stands in his own fan.** For every station, lane and position, no part of that station's mat, bench, prompt post, hut post, hut roof, deck or ladder intersects the solid angle from the firing point to the span — §3.1's table is the arithmetic (only the hut posts reach the bore's plane, and the span is bounded by them) | `range.spec`, reading the BUILT parts out of the folder by name, not the pure points |
| **T18** (new) | **The span, the leg and the corridor nest, always**: `sightSpanFor ⊆ [corridorWest+APRON, corridorEast−APRON] ⊆ ...`, `laneEndsFor ⊆ corridorSpan`, and the release point is never inside `sightSpanFor` — for 6 stations × 3 lanes × 2 signs of `downrange` × both flag states | `range.spec`, pure |
| T1, T2, T4, T7–T11, T13, T14 | **unchanged** from the base delta. T14 gains one clause: **no write under `src/client/Range/` to any part that is neither under `Workspace.RangeTargets` nor under a remote player's character** | the specs plus the Reviewer's read |

---

## 14. How it is tested

### 14.1 Server spec — `tests/server/range.spec.luau`, new groups

1. **The span, as arithmetic and not as a typed table.** For all 6 stations × 3 lanes:
   `sightSpanFor` equals the intersection recomputed in the spec from `bermSpanFor`,
   `BERM.shoulderStuds`, `bermCrestFaceZ`, `HUT.*` and `corridorSpan` — so deleting any one of the
   three bounds changes the answer and fails. Plus §3.2's three floors (71.07 / 80.67 / 109.47) and
   the two ceilings (98.11 / 115.96 / 156) to 0.01 studs.
2. **The OFF branch is bit-for-bit today's**: `sightSpanFor(anchor, spot, LAYOUT, d, false)` ==
   `windowSpanFor(anchor, spot, LAYOUT)` for every station and every lane, and
   `laneEndsFor(..., false)` == `laneEnds(...)`.
3. **T18's nesting**, as above, both signs of `downrange`.
4. **T6's 36 combinations**, as arithmetic: the worst ray per (station, lane, position) crosses
   `bermCrestFaceZ` inside `backstopSpanFor`. A case that widens `LAYOUT.SIGHT.silhouetteStuds` to 0
   must still pass; a case that removes the `shoulderStuds` trim must FAIL (the bound is load-bearing).
5. **T17 against the BUILT parts**: build the range, read every `Mat`, `Bench`, `Post`,
   `HutPost<spot>_<corner>`, `Roof<spot>`, `Board<spot>` and `Stand<spot>` piece out of the folder by
   name, and assert each is outside the fan or below/above the bore plane, with the height test
   explicit. Deleting the hut block must not make it vacuous.
6. **The paces did not move**: `paceSpeedFor` == 7.20 / 14.40 against `paceWindowStuds`, driven with
   a layout whose span is wide — the regression §2 exists to prevent.
7. **`ignoredFor` at six animals in one wide span**: a man at station 3, all six released and all six
   inside every span → exactly five roots, every one a TRUNK and never a zone part; his own added
   when it is in the apron; nobody at a station → empty; nil `boars` → empty, no error.
8. **The cap order**: a fake `candidatesFn` that records the `ignore` list it was handed proves the
   provider's instances reach `Cast.candidates` BEFORE any cut, and
   `weapon_rewind.spec`'s shipped two-candidates case still answers the un-ignored one.
9. **The staleness fix** (§7.3): a fake player moved from station 2 to station 4 with no request gets
   a push within one scan tick whose `mine`, `window` and `alone` are station 4's.
10. **The crossing timer on the wide span**: released at a leg end → outside the span → `windowArmed`
    true; one entry and one exit per leg; the recorded seconds match `span / issuedSpeed` within T5.
11. **`alone`**: true only when the server measured a station AND `state.solo`; false off the mat;
    false with the flag off, at every station.

### 14.2 Client specs

- **`tests/client/range_solo.spec.luau` (new).** Fake `players` and `me` seams; three remote
  characters plus the local one plus six fake trunks in a fake targets folder, all in one staged
  scene. Asserted: every remote character's parts go to 1 and come back to the value they had;
  the LOCAL character is never written and `refused` rises; a part under the targets folder is never
  written and `refused` rises; a character that appears after `start` is hidden on the next step;
  `setAlone(false)` restores everything; `stop()` restores everything; **T12** — `writes` does not
  climb across 60 idle steps; and the live-copy case `range_mask.spec` already uses, proving the
  spec measures the starter copy and not the one `RangeBoot` steps.
- **`tests/client/range_mask.spec.luau` (extended).** The windows come from `sightSpanFor` instead of
  `windowSpanFor` (same call shape, two more arguments); T15's settled write count; **and the
  PARTITION case**: `Mask` and `Solo` both stepped over one staged scene holding all four sets, and
  for every part exactly one of them accounts for the write while the other counts a refusal.
- `tests/client/range_panel.spec.luau` (extended): the board still prints `crossing` and the two lead
  numbers with the span it was told.

### 14.3 The harness, on the player's path

The shipped stage block needs **no harness change**: it finds
`Workspace.Range:FindFirstChildWhichIsA("BasePart")` and places the character on it, which is why
`Build` still parents mat 1 first. One scenario is reused (`the-range`, station 1, bench).

Four limits, with the fallback for each (rule 6 — a harness fault is a bug and is reported):

| Limit | Evidence | What is done |
|---|---|---|
| **The harness cannot run two clients' cameras.** `test2` starts a second player but the scenario file and the stage are the first client's | `tools/studio_mcp.py`'s docstring; `TWO_PLAYER_PATHS` | **T3 is a Director ops step**: two clients, two men at two stations, one screenshot from each. The specs prove both pictures' RULES; they cannot prove two real screens disagree |
| The replay **cannot aim input at an instance**, and no shipped scenario has ever clicked a GUI row | TASKS.md task 6: *"Cannot express: touch, gamepad, `textInput`, frame-counted holds, input aimed at an instance"* | unchanged: the panel is anchored at the screen centre, the scenario clicks that point, and the spec asserts the button's real `AbsolutePosition`/`AbsoluteSize` contains it before asserting the click arrived |
| Whether a replayed `E` reaches the engine's own `ProximityPrompt` handling is **NOT ESTABLISHED** | `ShopPanel.setPrompt`: *"a spec cannot fire a real `ProximityPrompt`"* | the spec opens through the shipped `setPrompt` seam; the real `E` at a station is a Director ops step with a screenshot |
| A client spec cannot assert what the SCREEN shows, only what a property says | rule 5, and `docs/PROJECT_CONTEXT.md`'s *"a marker wandering the screen ... certified a blank screen twice"* | every claim about invisibility is paired with a frame somebody looked at (§14.4) |

### 14.4 Screenshots (rule 5) — required, looked at before any claim

1. **The isolation frame, from two clients at the same instant**: two men at stations 2 and 5, each
   frame showing one animal and no other man (T3).
2. Down lane 3 from the bench at 179 with the animal at the span's **far end** — is 156 studs of run
   what Karen asked for.
3. The same at the span's **near end**, and one frame of the **turn-around in the apron**, to show
   what vanishes and where.
4. Station 1 at 107 looking east at the span's far end, with his own hut post in frame — the bay's
   opening (§3.1 bound 2), the one thing Karen can see the cap in.
5. The board after a run of shots at 179: the crossing seconds Karen reads.

### 14.5 The known defect in this area, NOT fixed here

`playtest/range-v3/report.md`, *"Seen by accident"*: stepping off a mat or walking the firing line
between stations strips all four guns and rearms the wrong one, with nothing on screen.

**Does anything this design adds touch that path? No, and here is the path.** The loan is
`Range.entitlementOver` → `loanSet()`, gated by `Range.mayShoot(player)` → `playerSpot` →
`RangeData.spotAt`, bounded by `Range.standReach`. **This task changes none of those six symbols**:
not the station box, not `spotAt`, not `standReach`, not `mayShoot`, not the loan, not the arming or
drive-open providers.

**But it makes the defect more likely to be met**, exactly as the brief says: a man tracking an
animal across 156 studs turns his body and walks. So the design records it as a Director scheduling
item (§16 item 5) and recommends the fix lands **before** this flag is lit for a playtest — otherwise
Karen's first solo run is likely to end with an empty backpack, and the report will be about the gun
and not about the span.

### 14.6 Blast radius and the gate

Changed paths: `src/shared/Range/init.luau`, `src/server/Range/init.luau`,
`src/client/Range/Solo.luau` (new), `src/client/RangeBoot.client.luau`, `src/shared/Flags/init.luau`,
`tests/server/range.spec.luau`, `tests/client/range_mask.spec.luau`,
`tests/client/range_solo.spec.luau` (new), `tools/studio_mcp.py`.

- `BLAST_RADIUS` already maps `src/client/Range/` → `range` and `src/shared/Range/`,
  `src/server/Range/` → `range`; `src/shared/Flags` → `flags`. **`SCOPE_SPECS["range"]` must gain
  `tests/client/range_solo.spec.luau` in the same commit**, because `selftest` fails if a spec file
  belongs to no scope.
- **`test2` is N/A for every one of these paths, and that is CLAUDE.md's explicit list, not an
  opinion**: none is in `TWO_PLAYER_PATHS`, and the Director's 2026-10-03 decision puts
  `tools/studio_mcp.py` with the tools. The one-player line is required, always. **T3 still needs two
  clients and is an ops step** (§14.3), which is the arrangement the base delta §11.6 already chose
  as its default.

---

## 15. UNVERIFIED UNTIL BUILT

An Architect PASS proves this document is coherent. It does **not** prove it fits the engine. Every
item below is a document fact.

1. **T6 in all 36 combinations**, as a real sweep in her place. The arithmetic says the worst ray
   lands on the backstop's corner **with zero margin** where the backstop bound binds — that is the
   definition of the bound, and it means a measured sweep is the only thing that can confirm the
   heap's actual surface catches it. If it does not, the fix is one number: trim the backstop
   interval by more than `shoulderStuds`.
2. **That `LocalTransparencyModifier` hides a skinned MeshPart** (carried over, still unverified).
   Fallback shipped and off by default: `Mask.start`'s `alsoTransparency`.
3. **That the same property hides another player's whole character**, including accessories, the
   outfit plates and an equipped Tool. The parts are ordinary `BasePart`s, so the mechanism is the
   same; nobody has looked.
4. **The name tag over an invisible player** (§7.1). Fallback pre-decided; needs one frame.
5. **That 71–156 studs reads as "all the way"** to Karen, and that a span bounded by her own hut post
   reads as a bay and not as a bug (§16 item 6).
6. **That the per-station and per-lane spans do not read as inconsistency.** Station 1 at 107 gets
   71 studs and station 3 at 179 gets 156; the reason is visible (the heap and his own bay) but
   nobody has seen it.
7. **That six animals on ONE leg at the 179 lane do not bunch visibly.** They cannot collide
   (collision groups) and five are invisible, but the sixth passes through the other five's volumes
   and nobody has looked at that from a station.
8. **Six drawn animals' frame cost** at the wider sweep (T11, T15, T16).
9. **That the measured crossing lands inside T5 on the wide span.** The span is 4.3× today's, so any
   systematic error in `timeWindow`'s entry/exit instants is 4.3× smaller as a fraction — the easy
   direction — but it has not been measured once.
10. **That the staleness fix (§7.3) actually fires on the station edge in a live session**, and that
    one push per edge per watcher at 10 Hz costs nothing noticeable.

---

## 16. Open decisions

### For the Director (scope) — none blocks building

1. **Ratify the cap, or buy the heap.** This design caps the span at the built earth and the built
   bay: 71–156 studs, run 2.96–6.50 s, against the brief's hoped 196 studs / 8.17 s. The alternative
   is a heap **433 studs wide instead of 232** (§5), on ground her 990-sample census never covered,
   with a new census, a new terrace, a new footprint and a new home-area rectangle. **Default: the
   cap.** Nothing is blocked either way — the span is a derived function of the earth's own width, so
   a wider heap widens it with no code change.
2. **Open the bay?** `HUT.roofSize.X` 13 → 20 removes the clear-fan bound and gives every station
   **103 / 118 / 156** at run 4.30 / 4.92 / 6.50 s (§3.4). It moves a BUILT part, so it is a LOOK
   task with a rebuild and a frame. **Default: not in this task.**
3. **`Flags.MAX_FLAGS` 21 → 22** (§9). One line, and the real fix (TASKS.md 82b, retiring three
   accepted rows) stays queued and is the Director's call.
4. **The claim path's missing ignore list** (§8d). `HIT_CLAIM` is dark, so it is unreachable; it must
   be a named task before that row is ever lit. **Default: queue it.**
5. **Schedule the gun-stripping fix before this flag is lit for a playtest** (§14.5). It is a
   separate task and this design does not touch its path, but a wide span makes a man walk.
6. **Does `src/client/Range/` join `TWO_PLAYER_PATHS`?** Unchanged question, unchanged default: **no**
   — T3 is an ops step with two clients and two screenshots.

### For Karen (feel) — each has a stated default, none blocks building

7. **Does the animal still vanish, and where?** It now vanishes only in the **apron**, 20 studs at
   each end, where it turns around. Default: **yes, in the apron only** — the apron is what keeps the
   crossing clock honest (§4), so the alternative costs the board's crossing number.
8. **A floating name over an invisible player** (§7.1, §15 item 4). Default: **leave it**; the
   fallback is one line if she says it spoils "alone".
9. **Other players can still be HEARD.** Default: **yes** — "alone" is a picture, and per-player
   sound does not exist in this engine.
10. **The span differs by station and by lane** (§3.2). Default: **yes, and visibly so** — the two
    reasons are the heap she can see and her own hut post she can see. The alternative is one span for
    all six, which is the intersection, which is 11 studs at the 125 lane and therefore not an
    alternative.
11. **Which lane the solo view is most worth having on.** The design's answer is **179 in the middle
    four bays** (156 studs, run 6.50 s); the menu still opens on 125 (`DISTANCE_STUDS`), her shipped
    default.

---

## 17. The build steps

Each is one task, small, provable, in the order it can be proved. Rule 4 holds.

| # | What | What closes it |
|---|---|---|
| **C1** | **The three names, no behaviour change.** `paceWindowStuds`, `backstopSpanFor`, `backstopSlope`, `bayHalfSlope`, `LAYOUT.SIGHT`, and `sightHalfWidthAt` re-expressed as `ahead × backstopSlope` — with the span itself still `mat ± 18`. Nothing moves | `range.spec` groups 1 (off branch), 6 (the paces), and the shipped hut/berm fan cases re-pointed at the new bound. Harness. **Zero visual change, so no screenshot** |
| **C2** | **The span and the leg, behind the flag, off.** `sightSpanFor`, `laneEndsFor`, the `RANGE_SOLO` row, `Range.SOLO_VIEW`, `seams.solo`, `timeWindow`'s predicate, `release`'s leg end | `range.spec` groups 1–4, 7, 10, 11; **T6** as arithmetic; **T18**; harness. Flag off, so the shipped game is unchanged |
| **C3** | **The second picture.** `src/client/Range/Solo.luau`, `record.alone`, the client root's two lines | `range_solo.spec`, the PARTITION case in `range_mask.spec`; **T12**, **T16** |
| **C4** | **The staleness fix.** `state.spotOf` and the station edge in `scan` | `range.spec` group 9 |
| **C5** | **Her place, flag ON by override** (`tools/flags.py set RANGE_SOLO on`, no commit). The sweep, the frames, the playtest | **T3** (two clients, two screenshots), **T5** measured at three lanes, **T6** swept for real, **T15**, §14.4's five frames, `PLAYTEST.md` |
| **C6** | **Karen's OK flips the default**, or her no retires the row and archives the losing branch under `backups/` with a note (rule 7) | a three-line commit with the one-player gate |

C2 needs C1. C3 and C4 are independent of each other and both need C2. C5 needs C2–C4. C6 needs C5.
