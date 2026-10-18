# Task 201 part 3 — the start card, the pill's vocabulary, and Karen's boar on the hit card

Task: 205
Round: 1
Base: main @ `e3ad45f`
Code commit: `c7f789c74306907c4b2af83fa2552e6015977fb0`

```
[harness] PASS: 33/33 checks @ c7f789c74306907c4b2af83fa2552e6015977fb0 (clean tree) scope=all
```

**THE FOLDER IS `task-205` AND THE ROADMAP CALLS THIS "201 PART 3".** `tools/agents.py` resolves a
task of DIGITS only (`resolve_task`, and the `task-(\d+)/REQUEST\.md` regex), and `reviews/task-201/`
holds part 1's own PASS for a PR already merged to `main` (rule 7). Part 2 is in `task-203` for the
same reason. 205 is this branch's other real task number and both halves shipped in it, so one
request covers both, as the dispatch asked.

**THIS CHANGE NEEDS `test2`.** `src/server/Match/`, `src/shared/Drive/`, `tests/client/Role.luau`,
`tests/client/match_client.spec.luau` and `tests/server/match_*.spec.luau` are all in
`TWO_PLAYER_PATHS`. The `[harness2]` line for this commit is the Director's run and the merge needs
it.

**THE LINE ABOVE IS `scope=all`, NOT A SCOPED ONE.** `--scope auto` resolved to the WHOLE suite,
because `tests/client/Role.luau` maps to no `BLAST_RADIUS` row and anything unmapped under `tests/`
can only mean everything. So it is FULL one-player evidence for the merge, not just review-round
evidence (CLAUDE.md: *"A `--scope auto` run that resolves to the whole suite is tagged `scope=all`
… it played every spec, so it IS full evidence"*). I read the token out of the log rather than
assuming the run was narrow.

Note: `docs/research/2026-10-17-one-design-system.md`, the "Part 3" and "Task 205" sections.

---

## 1. The start card, to the Designer's `startcard-spec.md`

Karen, 2026-10-18: *"this message has to be improved maybe each from new line ask designer more user
friendly"*. The Designer wrote a file for it; this builds it.

**What it was** (`startcard-before.png`): a 440-wide panel of four 24 px `Enum.Font.Code` lines with
a black stroke, whose body was one server sentence — `WILD BOAR, POINTS: male 10, female 6, cub -10`
— plus `a piglet COSTS you - leave them`, and the BEATER got the same card.

**What it is**: `Style.card` + a `UIListLayout` of eight children — `Eyebrow / Role / Rule1 /
Section / Rows / Rule2 / Countdown / Bar` — and four rows of glyph + words + at most one right-hand
cell. Per role: `WHAT TO SHOOT` with the four prices, or `WHAT TO DO` with the licence, the push,
the horn and the line. Both last lines are instructions over the same deadline.

*Verify*: `Hud.renderStartCard` in `src/client/Hud/init.luau` is still the one writer;
`Hud.startCardRows` is the pure body; `hud_style.spec`'s `describe("the start card")` asserts the
build (the card's own tokens, the eight children in order, the full-bleed hairlines, the glyphs as
Frames, the two `DISPLAY` labels and nothing else at that step, both measured layouts);
`match_client.spec`'s `describe("the start card")` asserts the WORDS, per role, read off the drawn
card through `Hud.startCardRowText`.

**Live, in DEV** — `.screenshots/20261018T163740Z-t201c-startcard-hunter.png` (hunter) and
`20261018T164244Z-t201c-startcard-beater-dev.png` (beater). Probed off the live `PlayerGui`:

```
card=true 440x274 at 264,92 | DRIVE 1 / YOU ARE A HUNTER / WHAT TO SHOOT
  | [tick] Male boar +10 || [tick] Female boar +6 || [cross] Piglet - leave them -10
  || [cross] A person -10 | GET TO YOUR STAND 11 | bar=1.00
card=true 440x274 ... | DRIVE 1 / YOU ARE A BEATER / WHAT TO DO
  | [cross] You do not shoot [NEEDS LICENCE] || [chevron] Push the boars to the hunters
  || [horn] Click your horn as you walk || [cross] Do not cross their line DRIVE OVER
  | WAIT FOR THE HORN 9
```

## 2. A sentence cannot be laid out, so the server sends values

`Match.quarryLines` → **`Match.quarryRows`**: one row per kind with what that kind is worth, and the
snapshot also carries **`safetyPenalty`**, which is what the Designer's new `A person` row is priced
off. The RULE did not move — which kinds are quarry and what each is worth are still only in
`Match.CONFIG` — and the client still holds no copy of it.

*Why not parse the old sentence on the client*: a presentation string is not an interface, and
`SAFETY_PENALTY` is not in that sentence at all, so the client would have had to carry a copy of a
penalty. *Verify*: `match_config.spec`'s `describe("the quarry rows")`, `match_live.spec`'s "puts
what may be shot on the wire, as the rows the card draws" (the live snapshot equals
`Match.quarryRows(Match.config())` kind for kind and price for price, and `safetyPenalty` equals the
config's), and `match_client.spec`'s last case (the wire's rows are TABLES, and `Drive.CONFIG` holds
no `QUARRY`, no `POINTS` and no price inside its copy).

The retired function, `QUARRY_NOTE` and the rollback are in
`backups/2026-10-18_task-201-3_quarry-lines.txt` (rule 7).

## 3. `cub` is never printed, in one place

`Report.kindWord` is that place (`cub` → `piglet`); the start card, the hit card and the drive
report's ANIMAL column all read it. The report printed `CUB` until this task while the card said
`piglet` — fault 2 of the spec: *"A new player reads them as two animals and shoots the one he
thinks is safe."* The data string is unchanged everywhere it is a KEY.

*Verify*: `match_client.spec` "never prints the word cub, on either card"; `report_panel.spec`
"draws one row per animal…" now asserts the record is still `cub` and the drawn row says `PIGLET`.

## 4. `Style` gained §3.10's glyphs, and lost the last monospace builder

`Style.glyph` builds tick, cross, chevron and horn as Frames, every number a fraction of one `px`
argument. `Style.ruleAfter` puts a section head's hairline after its word. `Style.sectionHead` takes
its colour. **`panelLabel` is gone** — the Hud's last `Enum.Font.Code` + black-stroke builder, whose
final caller was this card (`backups/2026-10-18_task-201-3_panelLabel.txt`); the card's own case
asserts no `UIStroke` and no `Enum.Font.Code` on any of its 21 labels.

## 5. The status pill says `HUNTER` / `BEATER` (201a)

The design system's §5 surface 1 called the old pill a defect in these words: *"the start card's own
words, because the HUD says two different things for one fact today"*. The card has said `YOU ARE A
HUNTER` since task 158 while the pill two inches above it said `SHOOTER`. Karen's doc and every
message she sends say hunter and beater.

**One owner**: `Hud.roleBadge` now RETURNS `Hud.roleWord`, so the bar and the card cannot drift
apart again — the pill is the only place in the game that still draws a role word, because task
170 took the TEAM column off the results rows.

**Display only, and I grepped before claiming it** (L-030). Every `SHOOTER` / `DRIVER` literal in
`src/` and `tests/` is one of: this badge (changed), the spec kit's copy of it
(`tests/client/Role.luau`, changed), a comment, or a name that is not the word —
`SHOT_HEARD_FROM_SHOOTER_M`, `PACE.DRIVER_RUN_STUDS`, `Drive.CONFIG.SHOOTER_COLOR` /
`DRIVER_COLOR` (config KEYS read by `MapUi`), and `local SHOOTER = 11` in `match_safety.spec` (a
userId). **The TEAM names are a different string and are untouched**: `Shooters` / `Drivers` on the
wire, in `Match.CONFIG`, in `Players.Team`, in `Match.myTeam`, in `Style.teamColor` and in `MapUi`'s
marker table, and every `team == "Drivers"` branch still reads those. Nothing keys off the badge
word: the pill's colour is `Style.teamColor(team)`, by team name.

*Verify*: `Hud.roleBadge` in `src/client/Hud/init.luau`; `Role.badge()` in `tests/client/Role.luau`;
`match_client.spec` "has the drive's own words on it" — the DRAWN bar contains `Role.badge()`, the
two agree, and the bar carries **neither** `SHOOTER` nor `DRIVER` any more; and the board's rows are
asserted clear of both vocabularies.

**Before and after, same frame, same camera:**
`.screenshots/20261018T163740Z-t201c-startcard-hunter.png` (pill `SHOOTER`, card `YOU ARE A HUNTER`)
and `...20261018T170948Z-t201c-startcard-hunter.png` (pill `HUNTER`).

## 6. Task 205: Karen's own boar silhouettes, and her spread rule

Karen: *"and what is that? you need proper image for wildboar when showing hit now it feels mess
unclear wtf ? / it's in download male named"* and *"if same place spread if not same show spread"*.
Her two JPGs were keyed (the checkerboard is baked, not alpha), cropped, checked at 2x and uploaded
as Decals — both **Approved**, her OK quoted in `assets/uploads.json`, nothing of hers committed.
`Report.boarImage` is the one place a kind becomes a picture; `BoarArt.spread` is pure and fans
co-located dots onto a deterministic ring, moving the DRAWING and never the record.

**The dot box is a FIT, not the outline's extremes**, and that is the measurement worth checking:
the raw extremes put the head zone's CENTRE off the animal (11 % of its sample grid on black). The
box keeps every zone on the animal while still spanning it (worst zone 82 % male, 92 % female). A
100 %-scoring box was refused because it shrank onto the torso and destroyed what the picture means.
`Report.CONFIG.SILHOUETTE` — the server's zone truth — was not touched.

*Verify*: `hit_card.spec`'s `describe("Karen's silhouette")` (the image chosen by kind; nine pellets
at one spot drawn as nine distinct deterministic dots and a lone pellet unmoved; every dot inside
the measured box). L-028 lines at the pre-fix `e3ad45f` are in the previous dispatch's report:
`hit_card.spec:197/241/300` all "attempt to call a nil value".

## 7. The countdown bar has no length constant, on purpose

The phase is `Match.CONFIG.INTERMISSION_SECONDS` (15 today; 20 and 10 before) and the client is
never told it, so the spec's `secondsLeft / 10` would draw a two-thirds-full bar on the frame the
card appears. The renderer latches the largest `secondsLeft` it has seen since the card went up.
*Verify*: `Hud.startCardBarScale`, and `match_client.spec` "fills the countdown bar against the
phase it actually saw, not a constant".

---

## The new cases, failing at the pre-fix commit `6c734af` (L-028)

`git checkout 6c734af -- src/` with the NEW specs, then `test --scope auto` on a deliberately dirty
tree (the harness flags it `DIRTY TREE - NOT valid evidence`, which is right: it is evidence about
the CASES).

```
failed [server] match_config.spec:162 attempt to call a nil value   -> no Match.quarryRows
failed [server] match_config.spec:175 attempt to call a nil value
failed [server] match_config.spec:185 attempt to call a nil value
failed [server] match_config.spec:197 attempt to call a nil value
failed [server] match_config.spec:209 attempt to call a nil value
failed [client] Expected value "0.109804, 0.0980392, 0.0823529", got "0.0627451, 0.0705882, 0.0784314"
        -> the card was Color3.fromRGB(16, 18, 20) and not Style.LOOK.PANEL
failed [client] hud_style.spec:820 Expected value "nil" to be non-nil      -> no Rule1 slot
failed [client] hud_style.spec:847 Expected value "nil" to be non-nil      -> no Rows/Row1/Icon
failed [client] hud_style.spec:867 invalid argument #1 to 'ipairs'         -> no Countdown
failed [client] hud_style.spec:900 attempt to index nil with 'TextSize'    -> no Section
[client] 398 passed, 20 failed
```
(The client report prints the first five failures; 20 failed in all, the rest being the per-role
word cases in `match_client.spec`.)

**And the PILL's own cases, failing at `f92fca0`** — the same method, `git stash`-ing only `src/`
so the new specs run against the old source:
```
failed [client] match_client.spec:180 Expected value "true" (boolean), got "false" (boolean)
        -> the drawn bar says SHOOTER and Role.badge() now says HUNTER
[client] 417 passed, 1 failed       (and 418 passed, 0 failed with the fix)
```
TestEZ stops a case at its first failed `expect`, so the two assertions after it on lines 181-186
are covered by the same case passing afterwards.

## Ready-check (standing rule A) — one Play of 88 s in DEV, at the code commit

1. **The Tool is in the CHARACTER**: at 15 s `team=Shooters character=[Shotgun] backpack=[Rifle]`;
   at the end the same.
2. **The console**: 10 975 chars, **0** lines matching `Stack Begin` / `attempt to` /
   `invalid argument` / `is not a valid member` / `Unable to cast`
   (`<runs-dir>/t201c-console.txt`).
3. **The changed feature ran**: the card drew and then CLEARED at `Running`
   (`card=false … | / / | | | bar=0.00`), which is the rule that the next drive must not flash the
   last one's card.

A second 88 s Play for the beater frame: same tool line (`team=Drivers`), 10 829 chars, 0
suspicious. A third in the Forest Test place: 13 131 chars, 0 suspicious.

## What is NOT proven, and what I got wrong

* **No live hit-card frame, after five attempts across two sessions, and I now know why.** The shot
  itself works: `FireRequest:FireServer` with `Input.luau`'s own payload fires with no console
  error, and the live card already carries **Karen's male silhouette**
  (`image=rbxassetid://80206901277832`, read off the live `PlayerGui` — so the upload, the asset id
  and the `ImageLabel` are proven on the real screen). What I could not do is STAGE the animal: the
  BaseParts under `Workspace.Boars` are the boar's ZONE parts (`ZoneHead`, `ZoneRear`), and my
  script moved ONE of them 50 studs in front of the player instead of the animal — so every shot
  went at a dismembered zone part and nothing was hit. **The route for the next attempt is in this
  repo**: `tools/studio_mcp.py`'s own `shoot-the-boar` scenario stages properly
  (`QUERY_STAGE_TARGET` + the input scenario), and this run's own gate line reports
  `staged on Workspace.Boars.Boar1, 22 studs away`. Reuse that rather than a hand-rolled search --
  and with `python tools/flags.py set QUICK_TEST on` there is no 35 s wait either: that flag is
  *"3 s intermission, the first release immediately, 3 boars on the road in front of the shooters"*.
  The silhouette, the measured box and the spread are `hit_card.spec`'s.
* **`DHForestStartRole` cannot colour the FIRST drive's card, and that is a real finding.** I set it
  to `beater` in the Forest Test place (prior value `hunter`, captured BEFORE the write, restored
  after and read back: `RESTORED DHForestStartRole = hunter`). The console shows
  `[ForestTest] … asked to join as a beater (start switch)`, but `ForestTestBoot` honours a request
  at the `Running` boundary — after the `Assigning` the card is drawn in — so drive 1's card is
  still the hunter's. **The beater frame was taken in DEV instead**, by moving the player to the
  `Drivers` team from a server line during `Assigning` — which is the same thing
  `Match.requestTeam` does, and `Match.myTeam()` reads `LocalPlayer.Team`. The card, the wire and
  the HUD are all real; only the ROSTER's choice was made by hand, and that is said here rather
  than implied.
* **Three deliberate departures from the spec**, each with its reason in the research note: a row's
  cells are an x and a width rather than a `UIListLayout` with slack (that needs `UIFlexItem`, which
  nothing in this repo uses and I did not prove in this Studio); the dash in `Piglet - leave them`
  is ASCII, not §3.10's `–` (that character is only legal after the one-time Studio glyph check I
  did not run, and `Style.spaced` walks bytes, so a multi-byte glyph in a spaced label would be cut
  in half); and there is no 0.16 s fade-in (fading a card as one object needs a `CanvasGroup`,
  which changes how the whole card composites over the world).
* **The section head's hairline is faint on screen.** It is `LINE` at 0.35 over `PANEL`, which is
  the system's own token and the same pair the results board draws — but at 1 px on a card I can
  barely see it in either frame. Worth the Designer's eye; not changed on my own judgement.
* **201a is only PARTLY resolved.** The pill's word is done (section 5); the other two items that
  report listed as skipped are NOT, and nothing here touches them: the top band's spacing
  (8 / 40 / 108 → 12 / 50 / 98) and the ammo chip's `NO BUCK` notice. Any ready message to Karen
  must name those two as still open.
* **Karen has not seen any of it.** It is all look; she approved merging look work before she sees
  it (2026-10-17: *"it's ok to keep doing it"*).
