# Task 198 -- the hit card: a black boar in the corner with a red dot where each shot landed

Task: 198
Round: 1
Base: `b7e6eb9`
Code commit: `2820229352338474d1114a2be526cbee5a573927`

> **On the round number.** The Director dispatched this as "round 3". It is written as `Round: 1`
> because that is what `tools/agents.py` demands and refusing to notice would simply have the review
> refused: `expected = 1 if prev_rnd is None or prev_verdict == "PASS" else prev_rnd + 1`, and this
> task's committed `RESULT.md` is **round 2, PASS**. A PASS resets the count (CLAUDE.md, the stop
> rule). So this is round 1 against a NEW code commit, not a third attempt at the old one: round 2
> passed on `555bd46`, CI then went red on a harness-selftest case, and `2820229` is the one-file fix.

```
[harness] PASS: 33/33 checks @ 2820229352338474d1114a2be526cbee5a573927 (clean tree) scope=all
```

The Director ran that full gate. `test2` is **N/A**: no `TWO_PLAYER_PATHS` file is in the branch --
nothing under `src/server/Match/`, `src/client/Match/` or `src/shared/Drive/`, neither `MatchBoot`,
nor `tests/client/Role.luau`, nor any spec on that list; and `tools/studio_mcp.py`, the only file
`2820229` touches, is explicitly NOT on it (the Director's 2026-10-03 decision puts the harness with
the tools).

`scope=all` from `--scope auto` is correct rather than an expansion fault -- see claim 1.

`SMOKE PASS` (rule A), Forest Test, 80 s: gun in the CHARACTER at 15 s and at 80 s
(`@15s=1 @80s=1`); `stacks=0 errorLines=0` read over the WHOLE log, boot included (`smoke.sh`
concatenates the boot `consolefull` with the end one before grepping); `waves=9` released; the
player on the ground at 15 s, at the end, and 10 s after a respawn.

## What this is

Karen, 2026-10-16, with a reference frame of somebody else's hunting video: *"there is a black boar
image as you can see and red dot / so once we hit boar we can show where it has been hitted / red dot
will indicate so if shells then several of them / so somewhere in corner after hit we indicate where
it landed"*.

One of **your** shots lands on an animal; a small dark card appears in the lower left with a solid
black boar on a bone plate and a red dot wherever each pellet struck. It holds 3 s and fades.

**ONE owner for the picture and the projection** (the dispatch's words). `ReportPanel`'s three
private drawing functions moved, unchanged in what they draw, to `src/client/Hud/BoarArt.luau`, with
the colours, the size and the facing as arguments; `HitLog.Shape.dot` is still the one projection.
**The one new piece of data** is per-pellet landing places: `Weapon.Hits.group` still makes ONE
report per (shot, target) and now carries `points` underneath it, which `HitLog.Shape.cardDots`
projects.

Files: `src/shared/Report/init.luau`, `src/shared/Shotgun/init.luau`, `src/server/Weapon/Hits.luau`,
`src/server/HitLog/Shape.luau`, `src/server/HitLog/init.luau`, `src/client/Report/init.luau`,
`src/client/Hud/BoarArt.luau` (new), `src/client/Hud/HitCard.luau` (new),
`src/client/Hud/ReportPanel.luau`, `src/client/Hud/init.luau`, `tests/server/hit_card.spec.luau`
(new), `tests/client/hit_card.spec.luau` (new), `tools/studio_mcp.py` (`SCOPE_SPECS` only),
`docs/research/2026-10-17-hit-card.md` + INDEX.

## The round-1 blocking finding, and that the check for it can fail

The first review found both new payloads putting a RAW SERVER CLOCK on the wire as `at`, which
`sinceOpen`'s own comment and `docs/design/drive-report.md` section 2 forbid by name.

**Fixed, and pinned by a case that was RUN AGAINST THE PRE-FIX CODE AND FAILED THERE** -- the thing
four earlier tasks got wrong by shipping a check that could not fail. Two runs, each reverting one
path of the working tree and restoring it (the tree was byte-identical to the code commit
afterwards):

**A. the whole pre-fix `src/server/HitLog/init.luau` (from `df647fd`), new spec on top**
(`<runs-dir>/test-198-prefix-A.log`):

```
  failed [server] hit_card.spec:279 ServerStorage.Tests.hit_card.spec:279: attempt to call a nil value
[harness] FAIL: 31/33 checks @ 3ef2abe... (DIRTY TREE (1 paths) - NOT valid evidence) scope=all
```

That nil is `HitLog.lastCard()`, which did not exist then.

**B. the shipped module with ONLY the two `sinceOpen` conversions reverted**
(`<runs-dir>/test-198-prefix-B.log`):

```
  failed [server] hit_card.spec:300 Expected value "true" (boolean), got "false" (boolean) instead
[harness] FAIL: 31/33 checks @ 3ef2abe... (DIRTY TREE (1 paths) - NOT valid evidence) scope=all
```

Line 300 is the `at` assertion itself. The case fails for its own defect and nothing else.

## Claims

1. **The two new spec files belong to a scope, both selftests pass, and the scope resolution is
   UNCHANGED.** CI went red on PR #181 at the harness selftest's "every spec file on disk belongs to
   a scope" case; `2820229` adds the two files to `SCOPE_SPECS` in `tools/studio_mcp.py` and changes
   nothing else. They go where what they test lives: `report` gets **both** (`src/shared/Report/` and
   `src/server/HitLog/` already resolve to that scope, and the card is drawn from
   `Report.CONFIG.CARD`, placed by `HitLog.Shape.cardDots` and built in `HitLog.recordHit`); `hud`
   gets the client one (`Hud.HitCard` and `Hud.BoarArt` are under `src/client/Hud/`); `weapon` gets
   the server one (it drives `Weapon.Hits.group`'s new `points`). The dual membership is the idiom
   `zz_horn`, `boar_hit`, `shop_panel` and `pad_panel` already use.
   *Verify:* `python tools/studio_mcp.py selftest` -> `selftest PASS` and
   `python tools/agents.py selftest` -> `all ok` (logs `<runs-dir>/selftest-198-after.log`,
   `-agents.log`; the reproduction is `-before.log`).
   **It only WIDENS what a scoped run plays** -- a `report` change used to play neither file and now
   plays both. **This branch still resolves to `all`**, read off the resolver rather than assumed:
   `studio_mcp.resolve_scope("auto")` returns `['all']`, `'auto, from 18 changed path(s)'`, because
   **`src/client/Report/init.luau` is the one source path with no `BLAST_RADIUS` row**.
   **No row was added for it**, deliberately: it would be defensible (the client replica of the same
   system) but it would NARROW a future `--scope auto` for that path from the whole suite to four
   specs, and narrowing coverage as a side effect of a CI fix is not this task's to do. Unmapped
   falls back to the full suite, which is the safe direction. Flagged for the Director.

2. **Every `at` this module puts on the wire is seconds since the drive opened, and the card a spec
   reads is the card `recordHit` actually built.** `recordHit`'s card sends `sinceOpen(at)` and
   `recordDown`'s `hitFatal` sends `sinceOpen(animal.dots[index].at)`; `HitLog.lastCard()` is a
   window onto the last payload, cleared by `HitLog.clear`. *Verify:* `tests/server/hit_card.spec.luau`,
   case **"puts one dot on the card per pellet, and the card it SENT carries them"** -- the drive
   opens at t=100, a 4-pellet report fires at t=103, and the sent card's `at` is asserted to be 3,
   alongside `kind`, `drive`, `animal`, `hits`, `#dots` and exactly one `lead`. Failing runs A and B
   above. The internal record keeps the raw clock on purpose and the payload builders convert it,
   unchanged from before this task.

3. **One dot per pellet that struck the animal; a slug gets one; the list is bounded.**
   *Verify:* `tests/server/hit_card.spec.luau` -- "gives one point per pellet that struck the target,
   and keeps one report" (4 hand-written impacts through `Weapon.Hits.group` -> one report,
   `pellets == 4`, `#points == 4`, and `position` still the nearest impact); "gives a slug exactly
   one dot"; "never carries more dots than the ceiling" (`Report.CONFIG.CARD.DOTS_MAX`, with
   `Hits.POINTS_MAX` the same number at the other end).

4. **The card's dots come out of the drive report's own projection, and there is no second one.**
   *Verify:* "gives one dot per pellet, at exactly what Shape.dot answers for that pellet" recomputes
   `HitLog.Shape.dot` independently per point and compares to 1e-9; and
   `grep -rn "PointToObjectSpace" src/` finds it in the hit path exactly once, in
   `src/server/HitLog/Shape.luau` (`src/client/Hud/Objective.luau` also uses it, for the objective
   line's arrow, nothing to do with a shot). `BoarArt` projects nothing.

5. **Exactly one `lead` dot, and it is the one the TAB report draws.** `Hits.group` reports the
   NEAREST impact as the shot's position; `Shape.cardDots` marks the point nearest that.
   *Verify:* "marks exactly one lead dot, and it is the one the drive report draws".

6. **Nothing for a miss, a beater or scenery, and the refusals are counted.** A miss makes no
   `HitReport` at all (`Hits.targetOf` finds no `Damageable` root); a hit on anything not damageable
   is still RECORDED but gets no card. *Verify:* "makes no report and no points at all for a miss";
   `HitLog.cardWorthy` -- "is true only for a damageable target hit by a real shooter"; "sends one
   card per hit on an animal, and none for a beater or a miss" (`stats.cards` 1, `stats.cardlessHits`
   1).

7. **It goes to the shooter and to nobody else.** *Verify:*
   `grep -n "FireClient\|FireAllClients" src/server/HitLog/init.luau` -- the pre-existing
   `FireAllClients` in `broadcast`, the pre-existing `ReportData:FireClient` answering a client's own
   request, and `ReportEvent:FireClient` in `toShooter`, whose only callers are `recordHit` (the
   card) and `recordDown` (the fatal mark), each passing the shooter/killer.

8. **The client draws what arrived and computes nothing: red dots on a black animal, an ASCII label,
   mirrored when the shot came in on the far flank.** *Verify:*
   `tests/client/hit_card.spec.luau` -- "puts one red dot per pellet, at the (u, v) the server
   measured" (reads `U`/`V` back off the Instances and `BackgroundColor3` off the pip); "gives a slug
   exactly one dot and a label with no fraction"; "names the pattern and how much of it landed";
   "turns the animal round when the shot came in on the far flank" (reads the drawn x of all four
   dots in both facings, asserts each mirrored one is exactly `1 - x`, and that the near picture was
   cleared). `Report.cardFacing` and `Report.cardLabel` are pure and asserted server-side, including
   that every byte of the label is ASCII -- U+00B7 drew as two missing-glyph boxes in the first frame.

9. **It holds ~3 s then fades, a second hit replaces it, and the kill marks the lead dot in the
   report's own kill colour.** *Verify:* "holds for about three seconds, fades, and then is gone"
   (drives `HitCard.step` with its own dt); "replaces the card rather than stacking a second one";
   "marks the lead dot when the shot turns out to be the fatal one"; "ignores a kill that belongs to
   another animal or another shot". Three first-round notes are in this area and are fixed:
   `HitCard.markFatal` now paints `Shotgun.CONFIG.HIT_MARK_KILL_COLOR` (it was painting the colour
   the dot already was), `HitCard.setFade` no longer repaints the art frame's backing that `build`
   deliberately made transparent, and `HitCard.stop` holds and disconnects its two wire connections
   so a stop/start pair cannot draw every hit twice.

10. **The corner collides with nothing and sits in the right layer.** Lower left, above the kill
    feed, its bottom computed from `Drive.CONFIG.FEED_BOTTOM_OFFSET` and `FEED_LINES` rather than
    eyeballed. *Verify:* "keeps the card clear of the feed, the readout, the compass, the bar and the
    map" (rectangle intersection against `Feed`, `Readout`, `Compass`, `DriveBar`, `ObjectiveLine`,
    `MiniMap`, `Rail`, all made visible for the measurement); "sits over the scope's mask and under
    the report" (`CARD.Z_INDEX` 14, between the scope's 13 and `PANEL_Z_INDEX` 15).

## The live shot

One buckshot through the real request path (`FireRequest:FireServer`) in the Forest Test, from where
the drive put the hunter -- he is never moved, because `Weapon.Rules` refuses a shot from outside his
stand circle -- at a boar put broadside 54 studs in front of him. **Run:
`<runs-dir>/t198-LIVE.log`, frame `<runs-dir>/t198-LIVE-buck-card.png`** (first person, player's eye
height, looked at by me and by the Director). Every number below is from that one run and that one
frame:

```
Buck HIT Boar4 | range 53.9 studs = 15.1 m | fire->card 0.143 s | facing=Art
label=[H I T   -   B U C K   4 / 9] dots=4
  dot u=1.0000 v=0.0000 zone=rear lead=false  drawnX=0.9700
  dot u=1.0000 v=0.0000 zone=rear lead=true   drawnX=0.9700
  dot u=1.0000 v=0.0980 zone=rear lead=false  drawnX=0.9700
  dot u=1.0000 v=0.1648 zone=rear lead=false  drawnX=0.9764
```

So the 0.3 s target is **measured at 0.143 s**, fire to card visible, on the client's own clock, and
four pellets of nine drew four dots.

**What that frame shows that no spec would have:** the animal turned and ran as it was put down, so
all four pellets struck the trunk box's REAR FACE, which `Shape.dot` projects to `u = 1.0` exactly --
the same arithmetic that sends a nose-on shot to `u = 0`, which the comment above `Report.ontoBoar`
already describes. The four dots therefore draw on top of each other at the rump. The record is
truthful and the drawing faithful to it; whether same-face pellets should be spread out on the
picture is a LOOK decision for Karen and is deliberately not made here.

## What is NOT proven

* **The wire seam has no spec.** Nothing in `tests/` exercises the `event.kind == "hit"` /
  `"hitFatal"` branches of `ReportClient.start`'s `OnClientEvent`, nor the
  `ReportSystem.Hit:Connect(HitCard.show)` wiring in `Hud.start`; every client case drives
  `HitCard.show` / `HitCard.markFatal` directly. The reason it is not fixed rather than an oversight:
  only the SERVER can `FireClient`, so a client spec cannot reach that branch, and a server spec
  cannot order itself against the client runner. The live shot above is the only evidence that branch
  runs, and it is real evidence -- the card in that frame arrived over it.
* **The fatal mark has never been seen on a live kill**, only in the client spec driving `markFatal`.
  The new kill COLOUR has no assertion at all; the spec checks the `Fatal` attribute and the shape.
* **Claim 10 is measured at one viewport.** The card's x span is fixed (16..204) and the `Readout` is
  anchored bottom-right 24 px tall, so width is safe by construction; HEIGHT is not tested -- under
  about 400 px of viewport the card's top climbs into the compass band. Not a case the game ships
  into today.
* A claim of mine from the first round was **wrong and is withdrawn**: I reported the Forest Test
  place as a half-synced tree that could not run this change, and said MEASURED. The probe read
  `ModuleScript.Source` from the EDIT datamodel, where every script reads back as the empty string --
  `HitLog`, in that place for seventy tasks, "measured" missing too. Re-probed in Play, that place
  has the whole change, and the live shot above was taken there. There is nothing for Karen to click.
* **The nine notes from the round-2 PASS are queued as `198a` in `TASKS.md`, not fixed.** Three are
  worth doing first and are named there: `docs/design/drive-report.md`'s remote table no longer
  describes its own wire now `ReportEvent` also goes to one client; `Hud.build`'s overlap guarantee
  rests on a copied `20` literal rather than a constant; and the `lead` invariant is computed over
  two different sets (`position` over all impacts, `points` capped at `POINTS_MAX`) -- unreachable at
  18 pellets, but not guaranteed by construction.

No `.rbxm`, no `ignoreUnknownInstances`, no flag, no `poses.json`, no Architect design run (this
extends the drive report rather than adding a system; tasks 135/137/138 did the same).
