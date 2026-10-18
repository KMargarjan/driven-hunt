# Task 201 part 3 — the start card, the pill's vocabulary, and Karen's boar on the hit card

Task: 205
Round: 3
Base: main @ `e3ad45f`
Code commit: `f46226e512bfbcbfc9ac0390636a41a2618103d9`

```
[harness] PASS: 33/33 checks @ f46226e512bfbcbfc9ac0390636a41a2618103d9 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ f46226e512bfbcbfc9ac0390636a41a2618103d9 (clean tree)
```

Both lines are the Director's own runs at this commit, on a clean tree, first try. `scope=all` is
FULL one-player evidence: `--scope auto` resolved to the whole suite because `tests/client/Role.luau`
maps to no `BLAST_RADIUS` row. **This commit IS the head** — `git diff --name-only f46226e..HEAD` is
empty, so nothing at all has been committed since the lines were taken.

**THE FOLDER IS `task-205`, THE ROADMAP CALLS THIS "201 PART 3".** `tools/agents.py` resolves a task
of DIGITS only; `reviews/task-201/` holds part 1's PASS for a PR already on `main` (rule 7), and
part 2 is in `task-203` for the same reason.

**`test2` IS REQUIRED AND IS IN HAND**: `src/server/Match/`, `src/shared/Drive/`,
`tests/client/Role.luau`, `tests/client/match_client.spec.luau` and `tests/server/match_*.spec.luau`
are in `TWO_PLAYER_PATHS`.

Round 1 returned two blocking findings and round 2 returned one. All three are fixed below, in their
final state. Note: `docs/research/2026-10-17-one-design-system.md`, the "Part 3" and "Task 205"
sections.

---

## 1. Round 2's finding: the whole card fades now, whatever class a child is

`setFade` walked the art's children asking `IsA("Frame")`, and task 205 put an `ImageLabel` there —
a `GuiLabel`, not a `Frame` — so for the last half-second of every hit card the panel, the plate,
the words and the dots faded out while Karen's black boar stayed at full strength over the world and
then vanished. The fourteen `Frame`s it replaced did fade.

**Fixed as one generic walk, not a second name in a list.** `fadeInk(node, at)` takes any node and
fades the property that carries what you SEE — an image's `ImageTransparency`, a label's
`TextTransparency`, a stroke's `Transparency`, a frame's `BackgroundTransparency` — and `setFade`
walks `art:GetDescendants()` through it, so a nested child (the ring inside a dot, a future icon) is
covered and the next child type cannot recur the defect. A node's BACKGROUND is still never touched
unless it IS a frame: the silhouette's is deliberately transparent and writing the fade into it
would draw a rectangle (round 1's own note), and the art frame itself is not in the walk.

*Verify*: `HitCard.fadeInk` and `HitCard.setFade`; `hit_card.spec` "holds for about three seconds,
fades, and then is gone", which now asserts BY CLASS over every visible descendant of the card —
each past its resting value and not yet gone — and then that all four kinds (image, text, dot,
stroke) were really on screen, so it cannot pass by finding nothing.

**Failing at `2c622e9`** — `git checkout 2c622e9 -- src/client/Hud/HitCard.luau`, then
`test --scope auto` against the new case:

```
[tests:server] PASS: 1628 passed, 0 failed, 0 skipped, 0 errors, 59 spec files
  failed [client] hit_card.spec:455 Expected value "true" (boolean), got "false" (boolean) instead
  FAIL [client] > 0 passed, 0 failed, 0 errors, 0 skipped  (419 passed, 1 failed, 1 errors, 0 skipped)
```

Line 455 is `expect(node.ImageTransparency > 1e-3).to.equal(true)`: mid-fade the silhouette sat at
exactly 0. At this commit the same suite is `33/33 … scope=all`.

*One thing worth saying plainly*: my first attempt at this commit shipped the SPEC WITHOUT THE FIX —
a `git checkout HEAD -- src/client/Hud/HitCard.luau`, meant to undo the pre-fix experiment, reverted
my own edit because HEAD was still the previous commit. The gate caught it
(`FAIL: 31/33 @ 153a60e`), I re-applied and amended, and `git show --stat f46226e` carries both
files.

## 2. Round 1's finding 1: the mirror was not a mirror — measured, not argued

Three `ImageLabel`s on one plate, same image, in a live Play
(`.screenshots/20261018T173406Z-t205-mirror-probe.png`): plain draws **nose left**; a negative
`Size.X` — what the code did — draws **nose left too** (the box moves, the pixels do not flip); a
negative `ImageRectSize.X` draws **nothing at all**.

So the picture is never flipped and `drawDots` stops flipping the dots with it: the two flips used
to cancel for anatomy and change only the facing, so dropping both leaves every dot where it struck.
Kept: a hit on the head draws on the head. Lost, and written into `BoarArt.setKind` rather than
implied: the card no longer faces the way the player stood, because one image has no parts to lay
the other way round. The fourteen-part fallback still mirrors by relayout — through `look.mirror`,
because `setKind` returns early with no `Silhouette` and writes no attribute (round 2's note; this
request's round-2 wording was wrong and is corrected here).

*Verify*: `BoarArt.setKind`, `BoarArt.drawDots`; `hit_card.spec` "draws the far flank with a real
picture and the marks still on the right end" — a `side = -1` payload, which nothing had ever drawn.

## 3. The defect round 1's finding 2 uncovered: the ids were DECALS, so nothing rendered

An Open Cloud PNG upload creates a **Decal** (`AssetTypeId 13`), which an `ImageLabel` cannot draw.
Measured (`...173221Z-t205-mirror-probe.png`): with the decal ids every label was `IsLoaded = false`
on an EMPTY plate while a built-in `rbxasset://` control loaded. The card had been drawing no animal
at all, and no spec could see it — `Image` is a string and it was set correctly.
`InsertService:LoadAsset(decalId).Texture` gives the image behind it: `80206901277832 ->
rbxassetid://135789362198066`, `108874258373849 -> rbxassetid://121961957713451`. The decal ids stay
in `assets/uploads.json`, which records what was UPLOADED.

*Verify*: `Report.CONFIG.BOAR_IMAGE`; `hit_card.spec` "points at the IMAGE behind each decal".

## 4. Round 1's finding 2 itself: the frames, both facings, through the real path

`QUICK_TEST` on for the run and cleared after (`off / none / off`), the hunter left **on his stand**
— teleporting him beside the animal is why eight earlier shots never landed,
`Weapon.Rules.outsideStand` refuses them — the boar moved in front of him, and the shot sent on
`FireRequest:FireServer` with `src/client/Weapon/Input.luau`'s own payload.

* **`.screenshots/20261018T174012Z-t205-hitcard-right.png`** — near flank, `HIT - SLUG`, one red dot
  **on the head**; the kill feed beside it reads `MALE BOAR head 2 m SHOTGUN`.
* **`.screenshots/20261018T174113Z-t205-hitcard-left.png`** — far flank (`side = -1`, so
  `Report.cardFacing` is true and the mirrored frame is shown), `HIT - BUCK 9/9`, the nine pellets
  **fanned into a rosette**: Karen's *"if same place spread"* rule, live.

Both are the same card, plate and label as her own `<runs-dir>/karen-2026-10-18/shot-4.png`, which
is the fourteen `Frame`s she called *"mess unclear wtf ?"*.

## 5. The start card, to the Designer's `startcard-spec.md`

Karen: *"this message has to be improved maybe each from new line ask designer more user friendly"*.
`Style.card` + a `UIListLayout` of eight children — `Eyebrow / Role / Rule1 / Section / Rows /
Rule2 / Countdown / Bar` — and four rows of glyph + words + at most one right-hand cell. Per role:
`WHAT TO SHOOT` with the four prices, or `WHAT TO DO` with the licence, the push, the horn and the
line. Live: `...170948Z-t201c-startcard-hunter.png`, `...164244Z-t201c-startcard-beater-dev.png`.

*Verify*: `Hud.renderStartCard` is the one writer and `Hud.startCardRows` the pure body;
`hud_style.spec`'s `describe("the start card")` (tokens, the eight children in order, the full-bleed
hairlines, the glyphs as Frames, the two `DISPLAY` labels and nothing else at that step, both
measured layouts); `match_client.spec`'s `describe("the start card")` for the WORDS, per role, read
off the drawn card.

## 6. A sentence cannot be laid out, so the server sends values

`Match.quarryLines` → **`Match.quarryRows`** (one row per kind with its price) plus `safetyPenalty`
on the snapshot for the `A person` row. The RULE did not move. The retired function, `QUARRY_NOTE`
and the rollback are in `backups/2026-10-18_task-201-3_quarry-lines.txt` (rule 7).

*Verify*: `match_config.spec`'s `describe("the quarry rows")`; `match_live.spec` "puts what may be
shot on the wire, as the rows the card draws"; `match_client.spec`'s last case.

## 7. `cub` is never printed, and the pill says `HUNTER` / `BEATER`

`Report.kindWord` (`cub` → `piglet`) is read by the start card, the hit card and the drive report's
ANIMAL column, which printed `CUB` until this task. `Hud.roleBadge` now RETURNS `Hud.roleWord`, so
the bar and the card cannot drift apart; **display only** — the TEAM names `Shooters` / `Drivers`
are a different string, untouched, and the pill's colour is `Style.teamColor(team)`, keyed by team.
Before / after: `...163740Z-t201c-startcard-hunter.png` (pill `SHOOTER`) →
`...170948Z-...` (pill `HUNTER`).

## 8. `Style` gained §3.10's glyphs, and lost the last monospace builder

`Style.glyph` (tick, cross, chevron, horn as Frames, every number a fraction of one `px`),
`Style.ruleAfter`, a colour on `Style.sectionHead`; **`panelLabel` is gone**, archived under
`backups/`.

---

## Every new case, failing before its fix (L-028)

Against `f92fca0` (`git checkout f92fca0 -- src/`), for rounds 1-2's work:

```
failed [client] hit_card.spec:196 Expected value "false" (boolean), got "nil" (nil) instead
        -> no Mirrored attribute: the drawing and the dots had no shared answer
failed [client] hit_card.spec:376 Expected value "true" (boolean), got "false" (boolean) instead
        -> picture.Size.X.Scale > 0 is FALSE on the far flank: the negative width
failed [client] Expected value "rbxassetid://135789362198066" (string), got "rbxassetid://80206901277832"
        -> the decal id, which renders nothing
failed [client] match_client.spec:180 Expected value "true" (boolean), got "false" (boolean) instead
        -> the drawn bar said SHOOTER while Role.badge() says HUNTER
[client] 416 passed, 4 failed
```

The start card's own cases fail at the part's base `6c734af` (`match_config.spec:162/175/185/197/209`
"attempt to call a nil value" — no `Match.quarryRows`; `hud_style.spec:820/847/867/900` — no
`Rule1`, `Rows/Row1/Icon`, `Countdown` or `Section`; and the card's drawn colour read
`0.0627, 0.0706, 0.0784`, which is `Color3.fromRGB(16, 18, 20)` and not `Style.LOOK.PANEL`). The
fade case's line is in section 1 above.

**One case was changed rather than added**: `hit_card.spec`'s far-flank case was written for the
fourteen-`Frame` drawing and asserted the dots land at `1 - x`; it now asserts `x`, because neither
the picture nor the dots are flipped. The same claim underneath — the dots and the picture agree —
restated for a drawing that cannot flip. The gate caught that, not a review.

## Ready-check (standing rule A)

Rule A was last run at `2c622e9`; round 3 changed one client-side fade and the Director's dispatch
said a fresh Play was not needed for it. At that build, **in DEV**:

1. **Tool in the CHARACTER**: at 15 s `team=Shooters character=[Shotgun] backpack=[Rifle]`; at the
   end the same.
2. **Console**: 11 196 chars, **0** lines matching `Stack Begin` / `attempt to` /
   `invalid argument` / `is not a valid member` / `Unable to cast`.
3. **The changed feature ran**: both hit cards drew with the image loaded
   (`card=true image=rbxassetid://135789362198066 loaded=true drawn=148x80 dots=9`).

**In the FOREST TEST, the place Karen plays, half of rule A is NOT met — the measurement, not an
assertion.** Two Plays of ≥ 88 s at that build, probed at 15 s and again at the end:

```
15 s  (rule A): Alhamdulilah824 team=nil character=[] backpack=[]
end   (rule A): Alhamdulilah824 team=nil character=[] backpack=[]
hud: hitcard=true image=rbxassetid://135789362198066 startcard=false
console 12 903 chars; suspicious 0        (second Play: 13 028 chars; suspicious 0)
```

The console is clean and the HUD carries the new image id, but the player is **unenrolled in that
world's lobby** — no team and no Tool at all, which is that place's design and not a regression from
this branch: he is given a gun when he walks onto a truck pad (`<runs-dir>/lobby-go.luau`). So the
"Tool in the character" half is DEV's, not the Forest Test's.

## What is NOT proven

* **The frames are mine**, and the route to re-shoot them is `<runs-dir>/t205-frames.py`:
  `flags.py set QUICK_TEST on`, leave the hunter on his stand, move `workspace.Boars.Boar1` 20 studs
  in front of him, fire through `FireRequest:FireServer`.
* **201a is only partly resolved**: the pill's word is done; the top band's spacing
  (8 / 40 / 108 → 12 / 50 / 98) and the ammo chip's `NO BUCK` notice are untouched.
* **Rounds 1 and 2's non-blocking notes are not fixed** (notes are queued, not fixed in-round): the
  nine dead `Drive.CONFIG.START_CARD_*` constants; the drive report passing no `kind`, so a `cub` is
  the sow on the card and the generic frames in the report (my "one place" sentence is too broad);
  both card art frames built with `kind = "male"`, which makes the frame fallback unreachable; the
  fan measured in frame pixels but drawn into the smaller box; the `ScaleType.Fit` letterbox error
  of ~1.5-4 px; the bar re-latching if TAB is opened during `Assigning`; the misplaced `HitCard.art`
  doc comment; the backup file's wording; and `match_client.spec`'s `LIVE` fixture still carrying
  the retired string-shaped quarry.
* **Karen has not seen any of it.** She approved merging look work before she sees it (2026-10-17:
  *"it's ok to keep doing it"*).
