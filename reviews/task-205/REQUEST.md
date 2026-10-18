# Task 201 part 3 — the start card, the pill's vocabulary, and Karen's boar on the hit card

Task: 205
Round: 2
Base: main @ `e3ad45f`
Code commit: `2c622e9c19511b5906d0934179554b8bcd396c0a`

```
[harness] PASS: 33/33 checks @ 2c622e9c19511b5906d0934179554b8bcd396c0a (clean tree) scope=all
[harness2] PASS: 35/35 checks @ 2c622e9c19511b5906d0934179554b8bcd396c0a (clean tree)
```

Both lines are the Director's own runs at this commit, on a clean tree, first try. `scope=all` is
FULL one-player evidence, not a scoped round line: `--scope auto` resolved to the whole suite
because `tests/client/Role.luau` maps to no `BLAST_RADIUS` row, and I read that token out of the log
rather than assuming the run was narrow. Only `TASKS.md` and this file have been committed since
`2c622e9`, both on the merge gate's allow-list.

**THE FOLDER IS `task-205`, THE ROADMAP CALLS THIS "201 PART 3".** `tools/agents.py` resolves a task
of DIGITS only, and `reviews/task-201/` holds part 1's PASS for a PR already on `main` (rule 7).
Part 2 is in `task-203` for the same reason.

**`test2` IS REQUIRED AND IS IN HAND**: `src/server/Match/`, `src/shared/Drive/`,
`tests/client/Role.luau`, `tests/client/match_client.spec.luau` and `tests/server/match_*.spec.luau`
are in `TWO_PLAYER_PATHS`.

Round 1 returned **two blocking findings**. Both were real, both are fixed below, and the second one
uncovered a defect bigger than either: **the hit card had been drawing no animal at all**.

Note: `docs/research/2026-10-17-one-design-system.md`, the "Part 3" and "Task 205" sections.

---

## 1. Round 1, finding 1: the mirror was not a mirror — measured, not argued

The reviewer caught `picture.Size = UDim2.fromScale(-chosen.scale, chosen.scale)` and was right.
Three `ImageLabel`s on one plate, same image, in a live Play
(`.screenshots/20261018T173406Z-t205-mirror-probe.png`):

| | result |
|---|---|
| plain | drawn, **nose left** |
| negative `Size.X` — what the code did | drawn, **nose left**: the box moves, the pixels do not flip |
| negative `ImageRectSize.X` — the other candidate | **nothing drawn at all** |

So neither is a mirror. **The picture is never flipped now, and `drawDots` stops flipping the dots
with it** — the two flips used to cancel for anatomy and change only the facing, so dropping both
leaves every dot where it struck. Kept: a hit on the head draws on the head. Lost, and written into
`BoarArt.setKind` rather than implied: the card no longer faces the way the player stood, because
one image has no parts to lay the other way round. The fourteen-part fallback still mirrors by
relayout and reads the same `Mirrored` attribute. `setKind` no longer takes a `mirror` argument.

*Verify*: `BoarArt.setKind` and `BoarArt.drawDots`; `hit_card.spec` "draws the far flank with a real
picture and the marks still on the right end" — a `side = -1` payload, which nothing had ever drawn.

## 2. The defect that finding 2 uncovered: the ids were DECALS, and nothing rendered

An Open Cloud PNG upload creates a **Decal** (`AssetTypeId 13`), and an `ImageLabel` cannot draw
one. Measured on the same plate (`...173221Z-t205-mirror-probe.png`): with the decal ids every label
was `IsLoaded = false` and the plate was EMPTY, while a built-in `rbxasset://` control beside them
loaded. **So the card has been drawing no animal since the silhouettes landed**, and no spec could
see it — `Image` is a string and it was set correctly.

`InsertService:LoadAsset(decalId)` returns a model holding a `Decal` whose `.Texture` is the image:
`80206901277832 -> rbxassetid://135789362198066`, `108874258373849 -> rbxassetid://121961957713451`.
Those are what `Report.CONFIG.BOAR_IMAGE` carries now; the decal ids stay in `assets/uploads.json`,
which records what was UPLOADED.

*Verify*: `Report.CONFIG.BOAR_IMAGE`; `hit_card.spec` "points at the IMAGE behind each decal, not
the decal".

## 3. Round 1, finding 2: the frames, both facings, through the real path

`QUICK_TEST` on for the run (cleared after, verified `off / none / off`), the hunter left **on his
stand** — teleporting him beside the animal is why eight earlier shots never landed,
`Weapon.Rules.outsideStand` refuses them — the boar moved in front of him, and the shot sent on
`FireRequest:FireServer` with `src/client/Weapon/Input.luau`'s own payload.

* **`.screenshots/20261018T174012Z-t205-hitcard-right.png`** — near flank, `HIT - SLUG`, one red dot
  **on the head**; the kill feed beside it reads `MALE BOAR head 2 m SHOTGUN`.
* **`.screenshots/20261018T174113Z-t205-hitcard-left.png`** — far flank (`side = -1`, so
  `Report.cardFacing` is true and the mirrored frame is the one shown), `HIT - BUCK 9/9`, the nine
  pellets **fanned into a rosette**: Karen's *"if same place spread"* rule, live.

Both are the same card, plate and `HIT - SLUG` label as her own
`<runs-dir>/karen-2026-10-18/shot-4.png`, which is the fourteen `Frame`s she called *"mess unclear
wtf ?"*. I looked at all three.

## 4. The start card, to the Designer's `startcard-spec.md`

Karen: *"this message has to be improved maybe each from new line ask designer more user friendly"*.
`Style.card` + a `UIListLayout` of eight children — `Eyebrow / Role / Rule1 / Section / Rows /
Rule2 / Countdown / Bar` — and four rows of glyph + words + at most one right-hand cell. Per role:
`WHAT TO SHOOT` with the four prices, or `WHAT TO DO` with the licence, the push, the horn and the
line. Live: `.screenshots/20261018T170948Z-t201c-startcard-hunter.png` and
`...164244Z-t201c-startcard-beater-dev.png`.

*Verify*: `Hud.renderStartCard` is still the one writer, `Hud.startCardRows` the pure body;
`hud_style.spec`'s `describe("the start card")` (the card's own tokens, the eight children in order,
the full-bleed hairlines, the glyphs as Frames, the two `DISPLAY` labels and nothing else at that
step, both measured layouts); `match_client.spec`'s `describe("the start card")` for the WORDS, per
role, read off the drawn card.

## 5. A sentence cannot be laid out, so the server sends values

`Match.quarryLines` → **`Match.quarryRows`**: one row per kind with its price, plus `safetyPenalty`
on the snapshot for the Designer's `A person` row. The RULE did not move — which kinds are quarry
and what each is worth are still only in `Match.CONFIG`. *Why not parse the old sentence on the
client*: a presentation string is not an interface, and `SAFETY_PENALTY` is not in it at all. The
retired function, `QUARRY_NOTE` and the rollback are in
`backups/2026-10-18_task-201-3_quarry-lines.txt` (rule 7).

*Verify*: `match_config.spec`'s `describe("the quarry rows")`; `match_live.spec` "puts what may be
shot on the wire, as the rows the card draws"; `match_client.spec`'s last case.

## 6. `cub` is never printed, in one place

`Report.kindWord` (`cub` → `piglet`); the start card, the hit card and the drive report's ANIMAL
column all read it. The report printed `CUB` until this task while the card said `piglet`.

*Verify*: `match_client.spec` "never prints the word cub, on either card"; `report_panel.spec`
asserts the record is still `cub` and the drawn row says `PIGLET`.

## 7. `Style` gained §3.10's glyphs, and lost the last monospace builder

`Style.glyph` (tick, cross, chevron, horn as Frames, every number a fraction of one `px`),
`Style.ruleAfter`, and a colour on `Style.sectionHead`. **`panelLabel` is gone** — the Hud's last
`Enum.Font.Code` + black-stroke builder, archived under `backups/`.

## 8. The status pill says `HUNTER` / `BEATER` (201a)

`Hud.roleBadge` now RETURNS `Hud.roleWord`, so the bar and the card cannot drift apart again.
**Display only, grepped before claiming it**: every other `SHOOTER` / `DRIVER` literal is a comment
or a name that is not the word (`SHOT_HEARD_FROM_SHOOTER_M`, `PACE.DRIVER_RUN_STUDS`,
`Drive.CONFIG.SHOOTER_COLOR` / `DRIVER_COLOR`, `local SHOOTER = 11` in `match_safety.spec`). The
TEAM names `Shooters` / `Drivers` are a different string and are untouched; nothing keys off the
badge, because the pill's colour is `Style.teamColor(team)`.

Before / after, same frame and camera: `...163740Z-t201c-startcard-hunter.png` (pill `SHOOTER` over
a card saying `YOU ARE A HUNTER`) → `...170948Z-t201c-startcard-hunter.png` (pill `HUNTER`).

## 9. The countdown bar has no length constant, on purpose

The phase is `Match.CONFIG.INTERMISSION_SECONDS` (15 today; 20 and 10 before) and the client is
never told it, so the spec's `secondsLeft / 10` would draw a two-thirds-full bar on the frame the
card appears. The renderer latches the largest `secondsLeft` it has seen. *Verify*:
`Hud.startCardBarScale` and its case in `match_client.spec`.

---

## Every new case, failing at `f92fca0` (L-028)

`git checkout f92fca0 -- src/`, then `test --scope auto` against the NEW specs.

```
failed [client] hit_card.spec:196 Expected value "false" (boolean), got "nil" (nil) instead
        -> no Mirrored attribute: the drawing and the dots had no shared answer
failed [client] hit_card.spec:376 Expected value "true" (boolean), got "false" (boolean) instead
        -> picture.Size.X.Scale > 0 is FALSE on the far flank: finding 1's negative width
failed [client] Expected value "rbxassetid://135789362198066" (string), got "rbxassetid://80206901277832"
        -> the decal id, which renders nothing
failed [client] match_client.spec:180 Expected value "true" (boolean), got "false" (boolean) instead
        -> the drawn bar said SHOOTER while Role.badge() says HUNTER
[client] 416 passed, 4 failed      (418+ passed, 0 failed at the code commit: 33/33 scope=all)
```

The start card's own cases fail at the part's base `6c734af` for the same kind of reason
(`match_config.spec:162/175/185/197/209` "attempt to call a nil value" — no `Match.quarryRows`;
`hud_style.spec:820/847/867/900` — no `Rule1`, `Rows/Row1/Icon`, `Countdown` or `Section`; and the
card's colour read `0.0627, 0.0706, 0.0784`, which is `Color3.fromRGB(16, 18, 20)` and not
`Style.LOOK.PANEL`).

**One case changed rather than being added**: `hit_card.spec`'s far-flank case was written for the
fourteen-`Frame` drawing and asserted the dots land at `1 - x`. It now asserts they land at `x`,
because neither the picture nor the dots are flipped. The same claim underneath — the dots and the
picture agree — restated for a drawing that cannot flip. **The gate caught that, not a review.**

## Ready-check (standing rule A)

**In DEV, at this build** — the frames Play:
1. **Tool in the CHARACTER**: at 15 s `team=Shooters character=[Shotgun] backpack=[Rifle]`; at the
   end the same.
2. **Console**: 11 196 chars, **0** lines matching `Stack Begin` / `attempt to` /
   `invalid argument` / `is not a valid member` / `Unable to cast`.
3. **The changed feature ran**: both hit cards drew, with the image loaded
   (`card=true image=rbxassetid://135789362198066 loaded=true drawn=148x80 dots=9`).

**In the FOREST TEST, the place Karen plays — half of rule A is NOT met there, and this is the
measurement rather than an assertion.** Two Plays of ≥ 88 s at this build, both probed at 15 s and
again at the end, in that place:

```
15 s  (rule A): Alhamdulilah824 team=nil character=[] backpack=[]
end   (rule A): Alhamdulilah824 team=nil character=[] backpack=[]
hud: hitcard=true image=rbxassetid://135789362198066 startcard=false
console 12 903 chars; suspicious 0        (second Play: 13 028 chars; suspicious 0)
```

So in that world the console is clean and the HUD is alive carrying the new image id, but the
player is **unenrolled in the lobby** — no team and no Tool at all, which is that place's own
design, not a regression from this branch: he is given a gun when he walks onto a truck pad
(`<runs-dir>/lobby-go.luau` is the route, and it is what the beater run used earlier today). I ran
out of the time box before re-running the Forest Test through that route, so **the "Tool in the
character" half of rule A is DEV's and not the Forest Test's**.

## What else is NOT proven

* **The frames are mine.** Per the standing lesson that proof frames should be re-shot by the
  checker, the route is in `<runs-dir>/t205-frames.py`: `flags.py set QUICK_TEST on`, leave the
  hunter on his stand, move `workspace.Boars.Boar1` 20 studs in front of him, fire through
  `FireRequest:FireServer`.
* **201a is only partly resolved.** The pill's word is done; the top band's spacing
  (8 / 40 / 108 → 12 / 50 / 98) and the ammo chip's `NO BUCK` notice are untouched and still open.
* **Round 1's seven non-blocking notes are not fixed** (notes under a PASS are queued, and these
  were under findings): the nine dead `Drive.CONFIG.START_CARD_*` size constants, the
  `ScaleType.Fit` letterbox error of ~1.5-4 px, the bar re-latching if TAB is opened during
  `Assigning`, the fan now applying to the drive report's rows too, the misplaced `HitCard.art`
  doc comment, the backup file's wording, and this request's own "21 labels" claim (the case
  asserts `> 10` and prints the count).
* **Karen has not seen any of it.** She approved merging look work before she sees it (2026-10-17:
  *"it's ok to keep doing it"*).
