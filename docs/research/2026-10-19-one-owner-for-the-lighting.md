# One owner for the lighting (Task 215)

**Karen, 2026-10-17**, asked whether the Designer should tune the lighting -- the cabin and the boar
heads read pale: **"yes"**. The Designer's answer is
`<runs-dir>/design/lighting-spec.md` plus `lighting-mockups.png`
("the Designer's lighting spec, 2026-10-19"), and this note is what had to be settled before any of
it could be written down as code.

---

## 1. What the system must do

1. **Put the look in git.** Today `Lighting` is place content that nobody owns: no file in `src/`
   writes it, so the only record of the game's light is whatever was last typed into a Studio
   property box, in two places, differently. A reviewer cannot read it and a commit cannot change
   it.
2. **One writer** (rule 3), in **every world** -- the DEV arena where the harness runs and the
   Forest Test where Karen plays -- from **one data table**, so that "what light does this build
   have" has exactly one answer and that answer is a diff.
3. **Be switchable off without a commit**, because the whole change is a judgement about how dark a
   game should be and only Karen can make it. Off must mean *untouched*, not *a second set of
   numbers*: a place whose light the owner has already overwritten cannot be put back by a flag.
4. **Not cost frames.** The measurement the Designer gives is a phone budget; the task has to come
   back with the frame time it actually cost.
5. **Keep boars visible in shade and the HUD legible**, which are the two things a hunting game
   cannot trade away for atmosphere.

## 2. What is actually there, measured first (2026-10-19, Edit, both places)

Nothing in `src/`, `tests/` or `tools/` mentions `Lighting`, `Atmosphere`, `Bloom` or `SunRays`
(`grep`, empty). So both places were read live:

| | Forest Test (Karen plays here) | DEV (the harness) |
|---|---|---|
| `Ambient` | **159,159,159** | 110,100,90 |
| `OutdoorAmbient` | 125,155,200 | 150,140,125 |
| `Brightness` | **3.00** | 2.60 |
| `ClockTime` | **15.00** | 13.00 |
| `GeographicLatitude` | 54 | 52 |
| `ExposureCompensation` | 0.00 | 0.25 |
| `EnvironmentDiffuseScale` | 0.00 | 1.00 |
| `ColorShift_Top` | 255,206,149 | 0,0,0 |
| children | `SunRays`(on) `DepthOfField`(on) `ColorCorrection`(on) `Blur`(on) `Bloom`(on) `Sky` `Atmosphere` | `Sky` `SunRays`(off) `Bloom`(off) `DepthOfField`(off) `DrivenHuntAtmosphere` `DrivenHuntColorCorrection`(on) |

**Three things this changed about the task, and none of them were in the brief:**

* **The two places are not the same place.** The Designer's "today" column (`Ambient 159`,
  `Brightness 3.0`, `ClockTime 14.5`) is the Forest Test, near enough -- the clock is 15.0, not
  14.5. The DEV place is a third setting again. An owner that writes one table in every world is
  therefore not only tidier, it is the only way the two stop drifting.
* **`ColorCorrection.Saturation = -0.5` is live in the Forest Test.** Half the colour is being taken
  out of every frame by an effect nobody owns and nothing records. This is a second, independent
  cause of "pale and washed out" that the spec's §0 does not name -- it measured the ambient and
  stopped there. It is also why the before frames look greyer than `Ambient 159` alone explains.
* **`Lighting.Technology` cannot be read or written from a script.** Both a plugin thread and a game
  thread answer *"cannot read 'Technology' (lacking capability RobloxScript)"*. So the spec's
  `Technology = ShadowMap` row is **not implementable as a write**; it is recorded as an expectation
  in a comment and the place is left to its own setting. The spec's own argument -- that the look is
  built out of a 2.7 : 1 sun-to-sky ratio and therefore survives hard shadows -- is what makes that
  safe.

## 3. Sources

### A. Roblox Creator Docs -- *Lighting*, *Atmospheric effects*, *Post-processing effects*
<https://create.roblox.com/docs/environment/lighting> ·
<https://create.roblox.com/docs/environment/atmosphere> ·
<https://create.roblox.com/docs/environment/post-processing-effects>
Licence **CC BY 4.0** (`Roblox/creator-docs`, the repo these pages are built from). Maintained:
commits within the month.

*Well:* it is the only authority on what `Ambient` means against `OutdoorAmbient` (light reaching
surfaces occluded from the sky, versus open to it) -- which is the single distinction the whole
Designer spec is built on -- and on `Atmosphere.Decay` only applying away from the sun.
*Badly:* no cost figures at all, no guidance on which effects fight each other, and the `Technology`
page does not mention that the property is unreadable from a script, which cost a probe to find out.

### B. Pete Hodgson, *Feature Toggles (aka Feature Flags)*
<https://martinfowler.com/articles/feature-toggles.html> · free to read, no reuse licence stated ·
2017, still the canonical write-up and already this repo's adopted source
(`docs/research/2026-09-26-feature-flags.md`).

*Well:* it is where "a release toggle is read **once**, at a boundary, and the value passed inward"
comes from, and where the 21-day expiry on a dark path comes from. It also names the exact failure
this task has to avoid: a toggle whose off-state is *a different configuration* rather than *the
previous behaviour* is not a toggle, it is a fork.
*Badly:* it is written for request-scoped server code; it has nothing to say about a toggle whose
effect is a **mutation of shared world state**, which is this one. That gap is what §4's
adopt-don't-restore decision answers.

### C. Unity -- *Lighting Settings Asset*
<https://docs.unity3d.com/Manual/class-LightingSettings.html> · proprietary documentation,
free to read · maintained per engine release.

*Well:* the structural idea borrowed here. Unity does not let a scene's environment lighting be a
scatter of properties: it is **one asset -- one serialised table of values -- applied to the scene**,
so the environment is a reviewable artefact with a name rather than a state somebody left behind.
`Light.CONFIG` plus `Light.plan` is that asset, in a language that has no assets.
*Badly:* Unity's version is engine-enforced and ours is a convention; nothing stops the next person
typing into Studio's property box, and only the owner's own console line will say the two disagree.

### D. Roblox DevForum -- *Future is Bright: Phase 3* (ShadowMap vs Future)
<https://devforum.roblox.com/t/future-is-bright-phase-3-the-future-is-bright/1109391>
Forum post by the rendering team, 2021. No licence; **not maintained** -- a dated announcement, and
treated here as evidence of intent, not as a current API reference.

*Well:* it is the primary statement of what `Future` actually buys (per-light shadows, area
specular) and therefore of what is being declined. It is also the source for `ShadowSoftness` being
a `Future`-only control, which is why the spec's 0.35 is recorded as inert rather than claimed.
*Badly:* no numbers for the cost on a low-end device, so the spec's "+15-25 % GPU on a mid phone" is
the Designer's figure and is **not** verified by this note. Nothing in this task depends on it --
`Future` is not switched on.

### E. BT.601 luma (`Y' = 0.299 R + 0.587 G + 0.114 B`)
<https://www.itu.int/rec/R-REC-BT.601> · ITU-R Recommendation, in force, freely downloadable.

*Well:* it is the arithmetic the Designer's §2 table was computed with, and that is checkable rather
than assumed: the boar flank's "72" and the dirt track's "47" both reproduce to the digit from the
albedos named beside them. So the spec's claim can be re-derived here and turned into a spec
assertion instead of a frame somebody looked at.
*Badly:* **§2's grass row does not reproduce.** `112,124,72` under `OutdoorAmbient 104,116,132`
renders `46,56,37`, whose BT.601 luma is **51.0**, not the **45** the table prints -- so the
advertised 1.6 : 1 is really **1.43 : 1** on the Designer's own numbers, under the ≥ 1.5 this task
is told to hit. That discrepancy is the reason §5's target is measured off real pixels in the game
and not taken from the table.

## 4. The pattern adopted, and why

**A frozen data table, a pure `plan`, and a thin `apply` -- plus adopt-by-class, never create-twice.**

* **`Light.CONFIG`** is the Designer's spec as data: one table, one row per property, each with the
  spec's own reason beside it. Source C's "one asset, not scattered properties".
* **`Light.plan(enabled, config)`** is pure and is where the flag lands. It answers **`nil` when the
  flag is off** and a frozen list of writes when it is on. That is what makes "off = untouched"
  provable *by parameter* while the row sits at `true` (source B's boundary rule, and CLAUDE.md's
  "reachable by parameter as well as by flag"): the spec calls `plan(false, CONFIG)` and asserts
  nothing comes back, without a Lighting service and without a Play session.
* **`Light.apply(lighting, plan)`** is the only thing that touches the service. It walks the plan,
  **adopts** the first child of each class that is already there and only **creates** one when there
  is none -- and never creates a `SunRaysEffect`, `BlurEffect` or `DepthOfFieldEffect` at all, it
  only switches off one it finds. Idempotent by construction: applying twice writes the same values
  and adds no instance.
* **The off-switch is "never written", not "written back".** Source B's gap (§3B): the honest
  alternative -- snapshot the place's lighting at boot and restore it when the flag is off -- is
  refused, because a snapshot taken after something else has already written is a snapshot of the
  wrong thing, and because the override is set in **Edit** and read at **boot**, so the flag is
  always known before the first write. Off means the boot returns after one `print`.

**Three deviations from the Designer's spec, each with its reason:**

1. **`Technology` is not written** (§2 above): the property is unreadable and unwritable from a
   script. Recorded in `CONFIG` as a comment only.
2. **`SunRaysEffect`, `BlurEffect` and `DepthOfFieldEffect` are switched off when present.** §4 of
   the spec says SunRays is not used, and the Forest Test has it **on**; the spec never saw the
   `Blur` (Size 1.0, on) or the `DepthOfField` (on, both intensities 0) because they were not in the
   brief. An unowned post effect that silently changes every frame is the exact thing this task
   exists to end, so all three are in the table with an explicit `Enabled = false`.
3. **`FogStart`/`FogEnd`/`FogColor` are left alone**, as the spec says -- an `Atmosphere` supersedes
   them.

**Not built, and said so:** no day/night cycle, no per-world lighting variants, no interior trigger
volume, and no `Future` experiment. One setup, one morning, every world.

## 5. The numeric targets

| | target | where it comes from |
|---|---|---|
| boar in open shade vs the grass behind it | **luminance ratio ≥ 1.5 : 1**, measured off the rendered frame | the Director's dispatch; the spec's §2 claims 1.6 and its own arithmetic gives 1.43 (§3E) |
| HUD type over the brightest sky | **every colour ≥ 4.5 : 1**, and the sky measured, not predicted | design-system §2; the spec predicts a worst patch of `#C6CBD0` |
| the slate | `0.18`, moving to **`0.14`** only if the measured sky is brighter than `#B4CFE4` | the spec's §6, which calls 0.14 "insurance, not an improvement" |
| lit : shaded | **≈ 2.7 : 1** | the spec's §1 `Brightness` row |
| frame cost of the flag | **≤ 0.6 ms**, measured with the flag on and off at the same camera | the spec's §8 adds 0.1 (Atmosphere) + 0.05 (ColorCorrection) + 0.4 (Bloom) |
| lodge | three distinct pools, dark boards between; the trophy lit from below and **not black** | the spec's §5 and §7 |

**The named fallbacks, so an adjustment is inside the spec rather than invented:** if deep shade is
unreadable the knob is `Ambient` → `54,49,43` (§2), **not** the boar's albedo and not
`OutdoorAmbient`; if frames suffer the first and only cut is `Bloom` (§8); if the trophy reads black
the fix is one mantel `PointLight` at `Brightness 0.5 / Range 9 / 255,196,132` (§5).
