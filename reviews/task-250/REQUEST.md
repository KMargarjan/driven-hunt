# Task 250 — gun sounds, rifle punch, money penalties, lodge ambience

Task: 250
Round: 3
Base: `main` at `8970e4c3` (after #229)
Code commit: `58cb7fcd63eaeb16a307928b2a18af695818c512`

```
[harness]  PASS: 34/34 checks @ 58cb7fcd63eaeb16a307928b2a18af695818c512 (clean tree) scope=all
[harness2] PASS: 36/36 checks @ 58cb7fcd63eaeb16a307928b2a18af695818c512 (clean tree)
```

## Round 2's blocking finding, and the one line that settles it

**THE REVIEWER WAS RIGHT TWICE AND THE SECOND TIME WAS SHARPER.** Round 2's five cases drove
`Phase.step` with the figure HANDED IN, so all five passed with `Match.onSafetyViolation`'s two new
fields deleted — verbatim the flaw round 1's own comment accused `report_panel.spec` of.
`onSafetyViolation` is a local connected to `Weapon.SafetyViolated` and nothing in `tests/` fires
that signal.

**`tests/client/zz_tie_to_a_tree.spec.luau` is the one place in the repository that path runs end to
end**: it fires a REAL violating shot in a two-player run and captures the entry the SERVER published
over `MatchEvent`. It now asserts that entry carries a negative `money` and a word, and that
`Hud.feedTextFor` draws the line with `Money.signed`'s figure in it and never `$-1000`. **Delete the
producer's `money` and it fails.** The two-player run at the code commit prints it:

```
note [shooter] task250 tie: the server's own entry carried -$1000 -- "Player1 tied to a tree  -$1000"
```

That also closes one of round 1's own "could not be verified" items: **the $1000 safety fine IS now
proved on a player's path**, by a real shot, with the drawn line read back. The piglet's $500 still
is not (below).

`match_safety.spec`'s describe now says plainly what it covers (the machine's forwarding, the
`isLive` gate, and the row the producer reads) and what it does not (the producer), and names the
file that does.

**Two more notes fixed:** a THIRD wrong cell in the `DAMAGE_BY_WEAPON` grid — deer/slug/rear is
`55 / 1.2 = 45.8`, **grazed**, because `rear` is `crippling` and not `vital` so toughness divides it;
all three wrong cells were on the deer side, which is now written down as the lesson. And the comment
that claimed the fine is read once now says it is read twice, by two call sites of a pure lookup, and
why threading it instead would be the wrong trade.

**Queued, not fixed (rule 10):** the `fine` line names nobody and goes to everybody
(`FireAllClients` plus a format carrying only the figure and the word), where the violation line on
the same screen says the name — and `Hud.pushFeed`'s collapse rule means two players with equal
`row.fines` draw as one line with `x2` rather than one line each. `entry.userId` and `entry.name`
are already on the wire and the wording is the Director's, so it is one format string when he wants
it.

## Round 1's blocking finding, and what it cost

**THE REVIEWER WAS RIGHT AND CLAIM 7 OVERCLAIMED.** The safety fine's FIGURE never reached the feed:
`onSafetyViolation` was the ONE producer of a `violation` event in the whole of `src/` and it set
neither `money` nor `text`, so `Phase.step` forwarded `nil` and `Hud.feedTextFor`'s new clause was
dead on the player's path -- every tie line was the old `"<name> tied to a tree"`. The fine itself
was charged all along (`Score.violation` -> `row.fines` -> `Coins.forRow`), so what was missing was
the ANNOUNCEMENT, which is the half Karen would notice. `report_panel.spec` could not catch it,
because that case hands the Hud the money itself.

Fixed in `a25b712e`: `onSafetyViolation` reads `Score.fineForSafety(config)` -- it already had
`config` in scope -- and puts the signed delta and the word on the dispatched event; the stats read
moves beside it so the fine is read once. **Five new cases in `tests/server/match_safety.spec.luau`
drive the SERVER path** with PRODUCTION's config through `Phase.step` in a live drive: the violation
entry carries the figure and the word; an event with neither is bit for bit the old line; the row the
producer reads really exists and is twice the piglet's; the piglet's own `fine` entry carries its
figure; and a fine outside a live drive says nothing.

**Three of the seven notes were fixed in the same commit, because they are factual errors in text I
wrote** (the rest are queued under rule 10): `Drive.ScoreRow` gained the `fines` field the snapshot
has been emitting since round 1; the `DAMAGE_BY_WEAPON` severity grid had two wrong cells -- deer
body rigby is `100 / 1.2 = 83.3`, **mortal** and not lethal, and deer legs lever is `50 / 1.2 = 41.7`,
**grazed** and not mortal -- now corrected with the arithmetic beside them, and claim 4's table below
is corrected with them; and `Phase`'s `Event` kind list names `"fine"`.

Karen, 2026-10-23, verbatim: *"any lobby music, like birds relax quuiet ? ... and also semiauto same
sound like rifle / we need to change rifle sound and make more damadge recoil and sound / also we
need to make more damadge to shooter if shoot baby like take big amount of money and same to
person"*.

**NOBODY HERE CAN HEAR ANY OF IT.** There is no audio capture in `tools/studio_mcp.py`. Every sound
claim below is *what reached the engine* — the Sound exists, it loaded, it is playing, its id, its
resolved `Volume` and `PlaybackSpeed`. **KAREN'S EARS DECIDE**, and every number is one data row.

## What changed

**1. The semi-auto was firing the rifle's sample.** `SemiAuto.CONFIG.SOUND.shot.id` was
`rbxassetid://9114725315` — *Gun Retort 1*, which is `Rifle.CONFIG.SOUND.shot.id` and the lever's.
Three guns, one bang, and the only 12-gauge with a `SOUND` block was firing a centre-fire rifle. It
is now the side-by-side's own family, a different take.

**2. The rifle.** The RECORDING did not change and the measurement is why (claim 3). What changed is
the cut window, the pitch and a gain; a per-weapon damage column in the ANIMAL's config; and 1.5x
the recoil in `poses.json`.

**3. Money fines.** `Match.CONFIG.FINE`, a SIBLING of `POINTS` because it is a different currency.
$500 for a piglet or a calf, $1000 for a shot that endangers a person, **both on top of** the
existing score penalty.

**4. The lodge's ambience bed.** A NEW SYSTEM with a new owner, designed first
(`docs/design/ambience.md`, Architect PASS at `8e5c3e96`; `reviews/task-250/BRIEF.md` is its input).

## Claims

**1. The semi-auto no longer shares the rifle's voice, and it is the side-by-side's own family.**
MEASURED IN A FOREST TEST PLAY SESSION, 2026-10-23, on the CLIENT, by building each weapon's shot
through the very function `CameraBoot` calls (`Weapon.Sound.shot(Poses.config(Config, id),
Weapons.row(id), ammo)`) and reading the `Sound` instance it put in `SoundService`:

| weapon | ammo | SoundId | Volume | PlaybackSpeed |
|---|---|---|---|---|
| shotgun | Slug | `99008924129683` | 1.188 | 0.820 |
| shotgun | Buck | `99008924129683` | 0.950 | 1.000 |
| **semiauto** | Slug | **`106454770387605`** | 1.250 | 0.787 |
| **semiauto** | Buck | **`106454770387605`** | 1.000 | 0.960 |
| rifle | Slug | `9114725315` | 1.800 | 0.820 |
| lever | Slug | `9114725315` | 1.920 | 0.760 |

Verify: `src/shared/SemiAuto/init.luau` `CONFIG.SOUND.shot`; `tests/server/semiauto.spec.luau`'s two
new cases assert the id is neither rifle's and not `Camera.Config.SOUND_SHOT_ID` either, and that
`fire.volume.shot` now sits beside the side-by-side's rather than above the rifle's;
`tests/server/rifle.spec.luau` asserts the same fact from the other end.

**2. The semi-auto's level was the other half of why it read as a rifle.** `fire.volume.shot` was
1.6 against a sample peaking at 603.6, where the side-by-side is 0.95 against one peaking at 85.3 —
about ten times the perceived level. It is 1.0 now. Verify: `src/shared/Viewmodel/poses.json`
`weapons.semiauto.fire.volume.shot`, written through `tools/pose.py`'s own serializer and path
validator (rule J; `pose.py selftest` passes).

**3. The rifle's RECORDING did not change, and the measurement is the argument.** The licensed
catalogue was swept again (`apis.roblox.com/toolbox-service/v1/marketplace/audio`, filtered to
licensed partners) and every candidate measured in Play on the CLIENT — `IsLoaded`, `TimeLength`,
and a `PlaybackLoudness` peak per 0.1 s bucket:

| id | name | len s | peak | mean |
|---|---|---|---|---|
| 9114725315 | Gun Retort 1 (this) | 4.95 | **603.6** | 30.1 |
| 9118173739 | Rifle Single Shots 1 (the Barrett) | 3.36 | 257.7 | 11.4 |
| 9118174270 / 9118174271 / 9118174539 | Rifle Single Shots 6 / 7 / 8 | 3.68 / 3.70 / 3.40 | 250.6 / 260.3 / 258.5 | 11.8 / 14.4 / 22.5 |
| 128650101411844 / 86903016850225 / 72333449737130 | AS_rifle_shot-01 / -03 / -04 | 0.35 | 86.4 / 92.4 / 77.4 | 7.3 / 8.4 / 6.8 |

It is **2.3x the peak and 1.3x the length of every alternative**; changing the recording would make
the rifle quieter and shorter. **What was wrong was the CUT**, and that was this file's own mistake.
The clip's loudness profile, peak per 0.1 s:

```
t  0.0  0.1  0.2  0.3  0.4  0.5  0.6  0.8  1.0  1.2  1.5  1.8  2.1  2.4  2.8  2.9+
L  442  204   59   38   26   18   14   12   10    8    6    4    2    2    1    0
```

ONE bang at t=0, a smooth decay, silent from 2.8 s — **no doublet**, which is what `cut = 2.0` was
guarding against. At `pitch = 0.88` that cut played **1.76 s of source** and the fade began at
1.06 s, so the last second of the report was never heard. `cut = 3.45, fade = 0.55` at `pitch = 0.82`
plays 2.83 s and fades only where the sample is at 2 of 442. `gain = 1.2` is deliberately small:
at `volume.shot = 1.5` against a 604-peak sample this gun is already ~10x the side-by-side.
Verify: `src/shared/Rifle/init.luau` `CONFIG.SOUND.shot` and the lever's; `rifle.spec` asserts
`cut * pitch > 2.8` and `(cut - fade) * pitch > 2.3` and `gain > 1`.

**4. A rifle bullet now does its own damage, and the ANIMAL decides.**
`Boar.CONFIG.WOUND.DAMAGE_BY_WEAPON` is keyed WEAPON → ZONE and is consulted by `Wound.damageFor`
before the shared `DAMAGE` rows. **The selector is `hit.weapon`**, which `Weapon.Hits.group` has
carried on every report since task 140 and which the two boot lines now forward — so **nothing was
renamed** (both rifles send `Slug` on the wire exactly as the shotgun does, and giving them their own
ammo word is ~300 lines across 25 spec files) and the weapon gains no damage number, which is
`docs/design/hit-zones.md` 3.1's boundary. Shots to kill, before → after:

| zone | boar, Rigby | deer, Rigby | boar, lever | deer, lever |
|---|---|---|---|---|
| body | 2 → **1** | 3 → **1** | 2 → 2 | 3 → **2** |
| legs | 4 → **2** | 4 → **2** | 4 → **2** | 5 → **3** |
| rear | 2 → 2 | 2 → 2 | 2 → 2 | 2 → 2 |
| head / chest | 1 → 1 everywhere | | | |

"Shots to kill" is to reach `LETHAL` **or** `MORTAL` -- a mortal animal dies on bleed-out after
running `Wound.flightStuds`, it does not drop on the shot. The deer's `body, Rigby 3 → 1` is one
shot to KILL and `100 / 1.2 = 83.3` is mortal, not lethal; round 1's severity grid in
`src/server/Boar/init.luau` said lethal and the Reviewer caught it.

The number this exists for: **a .416 through a stag's paunch was a GRAZE** (55 / 1.2 = 45.8, under
`MORTAL`). `rear` stays short of lethal on both rifles ON PURPOSE, so task 116's crippling reaction
survives. Verify: `tests/server/boar_wound.spec.luau`'s new describe drives every branch — a weapon
with a row, one without (the shotgun and the semi-auto are bit for bit unchanged), a zone the row
does not name, a config with no table at all, a nil weapon, the deer's armour on both paths, and
`apply` carrying the weapon onto the record; and the last describe compares the table against
production's **both ways**.

**5. The rifle kicks 1.5x harder, and now above the lever.** `weapons.rifle.fire`: cam 5.6 → 8.4
deg, gun 19.0 → 28.5 deg, back 0.68 → 1.02 studs, the three ceilings with them (6.5 → 9.8,
22.0 → 33.0, 0.80 → 1.20). Measured live in the Forest Test off `Viewmodel.view(DATA, "rifle")`.
The lever is 7.0 / 23.0 / 0.82, so a .416 Rigby now kicks harder than a .45-70 lever, which is the
right way round. Verify: `poses.json`; `rifle.spec`'s existing case asserts the RELATION (harder than
the shotgun, every kick under its own ceiling, home in 0.25–0.6 s) rather than literals.

**6. A piglet or a calf costs $500, a person in the line costs $1000, and both are ON TOP.**
`Match.CONFIG.FINE` is a sibling of `POINTS`, not a field in it: `POINTS` decides the ranking and is
multiplied by `COINS_PER_POINT`; these are flat dollars. `Score.Row.fines` is a positive total,
charged by `Score.kill` **on the killer alone** (an assist and a push are not the shot Karen is
punishing) and by `Score.violation`; `Economy.Coins.forRow` subtracts it flat and `Coins.credit`'s
`FLOOR` of 0 is still the one clamp in the game — so a bad drive earns nothing and no balance goes
negative. Verify: `tests/server/match_score.spec.luau`'s new describe (both fines, the degenerate
configs, the killer-only rule, accumulation, a build with no `FINE` table unchanged, and
production's table compared both ways including *every fined kind is a kind the POINTS also
punish*); `tests/server/economy.spec.luau`'s new describe (flat not through `COINS_PER_POINT`; a
$1000 fine takes the drive negative and the balance to exactly 0).

**7. Karen is told the moment it happens, and again at the end of the drive.** A `fine` feed entry —
`"-$500 · PIGLET"`, the Director's own wording — drawn in the LOSS colour, because
`Hud.feedMeaningFor`'s own key reserves the coin colour for *"money moved"*. The tie and its fine are
ONE line (`"Anna tied to a tree  -$1000"`), because one shot is one event. At the drive's end, one
summary line per fined player beside the results board, whose MONEY column is already net of it, and
`fines` on the snapshot row so a later surface can say WHY. Verify:
`tests/client/report_panel.spec.luau`'s four new cases, including that the figure comes from
`Money.signed` and the layout from `Drive.CONFIG.FEED_FINE_FORMAT` — so the Hud hand-rolls neither,
and never prints `$-500`.

**8. THE DISPATCH'S AMBIENCE PREMISE WAS WRONG, and that is the finding.** It says *"find the
existing ambience owner (the forest ambience runs at volume 3.00)"*. Measured 2026-10-23: **there was
no ambience owner in `src/` at all** — the only five `Sound` creators in the tree are all positional
or one-shots — the forest ambience Karen hears is a **STUDIO-MADE `Workspace.Ambience`**
(`rbxassetid://4629533497`, `Volume 0.50`, looped, playing, probed in the Forest Test's Edit session)
that nothing in git names, and task 248's *"two ambience sounds at volume 3.00"* were `Hud.Sound`'s
two `DriveSignal_*` bugle voices at `Horn.CONFIG.SIGNAL.VOLUME = 3`. So the bed is a NEW SYSTEM and
got an Architect design run first. Verify: `reviews/task-250/BRIEF.md`, `docs/design/ambience.md`
section 0, `reviews/task-250/ARCH_RESULT.md` (PASS).

**9. The bed is built, it plays, and it crossfades on Karen's path.** MEASURED in the Forest Test,
one Play session, as INSTANCE facts in `SoundService`:

```
IN THE DRIVE (team=Shooters)
  Ambience_lodge_birds  id=rbxassetid://9116970949  vol=0.0000 loaded=true playing=true len=75.20 looped=true
  Ambience_lodge_wind   id=rbxassetid://9116258071  vol=0.0000 loaded=true playing=true len=75.77 looped=true
  Workspace.Ambience    id=rbxassetid://4629533497  vol=0.5000           playing=true   (KAREN'S, UNTOUCHED)

MID-CROSSFADE, caught on the lodge -> drive boundary
  Ambience_lodge_birds  vol=0.0216    (0.0216 / 0.055 = 0.393)
  Ambience_lodge_wind   vol=0.0118    (0.0118 / 0.030 = 0.393)
```

**The two ratios are identical to three figures**, which is the proof that ONE gain drives both
voices and that `Volume = gain x LEVEL`. Exactly two bed Sounds exist, both `Ambience_*`, both
parented to `SoundService` (never to a part), both looped, both `IsLoaded`. `Workspace.Ambience` read
`0.5000` at every single sample. Verify: `tests/client/ambience_client.spec.luau` and
`tests/server/ambience.spec.luau`; the harness notes `[ambience] 2 bed Sounds in SoundService`,
`preload request finished: true`, `Ambience_lodge_birds loaded=true len=75.20 playing=true`,
`4 foreign Sound(s) watched, none written`.

**10. Nothing was uploaded and none was needed.** Karen's OK of 2026-10-23 PERMITS CC0 uploads for
four sounds; it does not require them, and the licensed catalogue carried every one. Said plainly
because it is a decision: `tools/roblox_upload.py` implements **Model and Decal only** (its own
selftest asserts `Audio` is refused), so the upload route would have been a tool change on top of a
four-item task; Roblox-provided licensed audio needs no upload, carries no licence risk and is the
route six previous tasks took. **All 21 candidate ids were proved to load** (`IsLoaded == true`) in a
Play session before any was wired in — the engine-side fact, not a moderation state. The lodge's
levels are 0.055 / 0.030 and **not** the design's suggested 0.18 / 0.10, because computed against the
takes actually chosen those would have put the bed at **113 %** of Karen's own forest instead of the
design's own 25–40 % band; these give **34 %**. Verify:
`docs/research/2026-10-23-ambience-and-money-fines.md` sections 4 and 4.2.

## What could NOT be verified, and what I got wrong

* **THE $500 FINE WAS NOT TRIGGERED LIVE.** Six trigger pulls were put on piglets in the Forest Test
  (at 71.6, 171.6, 215.2, 226.0 and 248.6 studs) and **none of them produced a kill**: the results
  board read `coins "+$10"` — participation alone — and no fine line ever appeared. The shots were
  refused or missed and I did not isolate which; the likeliest cause is task 248's own safety lock
  (beaters push the animals, and a shot whose line passes within 6 studs of any person does not
  fire). The $1000 fine is harder still for the same reason — that lock exists to stop exactly the
  shot the penalty punishes. **So item 3's proof is the spec suite and the HUD-text cases, not
  Karen's path**, and the first playtest is what will show it. `stats().finesCharged` and
  `finesMoney` are the two numbers to read.
* **The lodge bed was never caught at FULL level on her path.** It was caught at gain 0.393 and at
  0.000, which proves the crossfade and the arithmetic; the window at the lodge between drives is
  short and I ran out of session. The client spec asserts the full-level case directly.
* **I did not read the Forest Test's attributes FIRST**, which the standing capture block asks for.
  I read them at the END: `DHFlag_BOAR_BEHAVIOUR/BOAR_MODEL/COINS/DEER_ROAD_LEAP/DRIVE_BOTS/HORN/
  LICENCE_POPUP/LOBBY/SHOP=true DHForestStartRole=hunter DHShopTestGrant=true`, which matches the
  set `reviews/task-244/REQUEST.md` recorded plus the flags tasks 245–249 added. **I wrote no
  attribute**: every probe was read-only except the trigger pulls, which write none. Reported as a
  process miss rather than hidden.
* **A screenshot of the fine line (rule 5) does not exist**, because the line never appeared. The
  frame that was taken (`.screenshots/20261023T192354Z-250-fine-feed.png`) shows the lobby screen
  with no fine on it, and is evidence of the absence rather than of the feature.
* **`SoundService.Volume` does not exist.** `docs/design/ambience.md` section 8 names it; the engine
  answers *"Volume is not a valid member of SoundService"*. The design is wrong about the API and
  right about the rule; the spec watches `AmbientReverb`, `DistanceFactor`, `RolloffScale` and
  `DopplerScale` instead. The Architect owns that file, so it is reported and not edited.
* **A game script cannot read `Source`** (it needs `PluginOrOpenCloud`). The design's two
  negative assertions (sections 11.1 and 11.2) are written as text greps; both are now asserted by
  BEHAVIOUR instead, which is the better test anyway.
* **The results board did not gain a FINES column.** Its five columns plus the badge fill its 488 px
  body exactly (`rank 0+20, name 28+186, kills 214+74, points 292+78, coins 374+66, badge 448+40`),
  so a sixth is a reflow and a layout task. The MONEY column is net of the fine and `row.fines` is on
  the wire for whoever draws it.
* **`camera_client.spec:1618` failed one of three runs at this commit** and passed the other two
  (`handsMissing 11 -> 12` on a pass). It is the documented flake of `TASKS.md` 249a(d) and
  `ESCALATE.md` — *"failed 7 of 12 harness runs across seven commits"* — in a file this task does not
  touch. The PASS line above is from a clean run at the same commit.
* **Nobody has heard a single sound in this task.** Karen's ears decide: whether the semi-auto now
  sounds like a shotgun, whether the rifle's full roll is the *"more sound"* she asked for, whether
  the lodge is *"relax quuiet"*, whether 2.5 s is the right fade, and whether $500/$1000 are the
  right figures. Each is one data row.
