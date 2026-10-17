# Task 198 -- the hit card: a black boar in the corner with a red dot where each shot landed

Task: 198
Round: 1
Base: `b7e6eb9` (`main`, the merge of #180)
Code commit: `9194785023729dcb58c1773301e8e9be439332d1`

Gate (one player; **no TWO_PLAYER_PATHS file is touched** -- nothing under `src/server/Match/`,
`src/client/Match/`, `src/shared/Drive/`, neither `MatchBoot`, nor `tests/client/Role.luau`, nor any
spec on that list):

```
[harness] PASS: 33/33 checks @ 9194785023729dcb58c1773301e8e9be439332d1 (clean tree) scope=all
```

`SMOKE PASS` (rule A), Forest Test, 80 s: `gun in hand @15s=1 @80s=1 | stacks=0 errorLines=0 |
waves=9`, player on the ground at 15 s, at the end and 10 s after a respawn. The "0 errors" was read
over the WHOLE log, boot included: `smoke.sh` writes `consolefull` at boot into
`smoke-console-boot.txt` and again at the end, and greps the concatenation (L-087).

## What changed

Karen, 2026-10-16, with a reference frame of somebody else's hunting video: *"there is a black boar
image as you can see and red dot / so once we hit boar we can show where it has been hitted / red dot
will indicate so if shells then several of them / so somewhere in corner after hit we indicate where
it landed"*.

**ONE owner for the picture and the projection.** `ReportPanel`'s three private drawing functions
(`buildSilhouette`, `clearDots`, `drawDots`) moved, unchanged in what they draw, to
`src/client/Hud/BoarArt.luau`; the colours, the size and the facing became arguments.
`HitLog.Shape.dot` is still the one projection and is not duplicated anywhere.

**The one new piece of data** is per-pellet landing places: `Weapon.Hits.group` still makes ONE
report per (shot, target) with `pellets = n` and the NEAREST impact as `position`, and now carries
`points` underneath it (`Hits.POINTS_MAX` = 24). `HitLog.Shape.cardDots` projects each through
`Shape.dot` and marks the one the drive report draws as `lead`.

Files: `src/shared/Report/init.luau` (`CONFIG.CARD`, `CardDot`/`CardPayload`, `cardFacing`,
`cardLabel`), `src/shared/Shotgun/init.luau` (`HitReport.points`), `src/server/Weapon/Hits.luau`,
`src/server/HitLog/Shape.luau` (`cardDots`), `src/server/HitLog/init.luau` (`cardWorthy`,
`toShooter`, the card in `recordHit`, the `hitFatal` in `recordDown`), `src/client/Report/init.luau`
(`Hit`, `HitFatal`), `src/client/Hud/BoarArt.luau` (new), `src/client/Hud/HitCard.luau` (new),
`src/client/Hud/ReportPanel.luau` (delegates), `src/client/Hud/init.luau` (the frame + `start`),
`tests/server/hit_card.spec.luau` (new), `tests/client/hit_card.spec.luau` (new),
`docs/research/2026-10-17-hit-card.md` + INDEX.

## Claims

1. **One dot per pellet that struck the animal; a slug gets one.** `Hits.group` collects
   `entry.points` per impact and `Shape.cardDots` projects each. *Verify:* `tests/server/hit_card.spec.luau`,
   "gives one point per pellet that struck the target, and keeps one report" (4 hand-written impacts
   -> `#reports == 1`, `pellets == 4`, `#points == 4`) and "gives one dot per pellet..." / "gives a
   slug exactly one dot". Live: the card readout below.

2. **The card's dots come out of the drive report's own projection, not a second one.**
   `Shape.cardDots` calls `Shape.dot` and nothing else; `BoarArt` does no projection at all. *Verify:*
   the spec case "gives one dot per pellet, at exactly what Shape.dot answers for that pellet"
   recomputes `Shape.dot` independently per point and compares to 1e-9; and `grep -rn "PointToObjectSpace" src/`
   finds it in the hit path exactly once, `src/server/HitLog/Shape.luau:33` (the only other hits are
   `src/client/Hud/Objective.luau`, which projects the objective line's arrow and has nothing to do
   with a shot).

3. **The `lead` dot is the one the report draws, and there is exactly one.** `Hits.group` reports the
   NEAREST impact as the shot's position; `cardDots` marks the point nearest that. *Verify:* the spec
   case "marks exactly one lead dot, and it is the one the drive report draws".

4. **Nothing for a miss, a beater or scenery.** A miss makes no `HitReport` at all
   (`Hits.targetOf` finds no `Damageable` root); a hit on anything not damageable is still RECORDED
   but gets no card, and the refusal is counted. *Verify:* the spec cases "makes no report and no
   points at all for a miss", "HitLog.cardWorthy ... is true only for a damageable target hit by a
   real shooter", and "sends one card per hit on an animal, and none for a beater or a miss"
   (`stats.cards` 1, `stats.cardlessHits` 1).

5. **It goes to the shooter and to nobody else.** *Verify:*
   `grep -n "FireClient\|FireAllClients" src/server/HitLog/init.luau` gives three lines: the
   pre-existing `FireAllClients` in `broadcast` (the kill line and the drive boundaries), the
   pre-existing `ReportData:FireClient` that answers a client's own request, and the one this task
   adds -- `ReportEvent:FireClient(player, event)` in `toShooter`, whose only two callers are
   `recordHit` (the card) and `recordDown` (the fatal mark), each passing the shooter/killer.

6. **The client draws exactly what arrived, in red, on a black animal.** *Verify:*
   `tests/client/hit_card.spec.luau`, "puts one red dot per pellet, at the (u, v) the server
   measured" (reads the `U`/`V` attributes back off the Instances and the `BackgroundColor3` off the
   pip), "gives a slug exactly one dot and a label with no fraction", "names the pattern and how
   much of it landed".

7. **A far-flank shot turns the animal round, and the marks go with it.** `Report.cardFacing` is the
   majority of this shot's own `side`; `BoarArt` lays the parts out at `u -> 1 - u` and mirrors the
   dots with the same line. *Verify:* the client case "turns the animal round when the shot came in
   on the far flank" reads the drawn x of all four dots in both facings and asserts each mirrored one
   is exactly `1 - x`; and the server case "Report.cardFacing" for the majority rule and the tie.

8. **It appears at once, holds ~3 s, fades, and a second hit replaces it.** *Verify:* the client
   cases "holds for about three seconds, fades, and then is gone" (drives `HitCard.step` with its own
   dt) and "replaces the card rather than stacking a second one". **The 0.3 s is NOT measured
   end-to-end and I am not claiming it was**: what is checked is structural -- `recordHit` builds and
   fires the card synchronously inside the `Weapon.HitReported` handler, with no yield between the
   dot and the `FireClient`, over one RemoteEvent (`grep -n "task.wait\|task.delay\|task.spawn"
   src/server/HitLog/init.luau` is empty). On screen, the card was `Visible` on the first readback
   after every injection in `<runs-dir>/t198-frames.log`.

9. **The fatal mark is the report's own mark, and it arrives after the card.** The animal enters DOWN
   on the Brain's NEXT tick, so `recordDown` sends `hitFatal` joined on the animal and the shot's own
   clock. *Verify:* the client cases "marks the lead dot when the shot turns out to be the fatal one"
   and "ignores a kill that belongs to another animal or another shot".

10. **The corner collides with nothing, at any width.** Lower left, above the kill feed, its bottom
    computed from `Drive.CONFIG.FEED_BOTTOM_OFFSET` and `FEED_LINES`. *Verify:* the client case "keeps
    the card clear of the feed, the readout, the compass, the bar and the map" (rectangle
    intersection against `Feed`, `Readout`, `Compass`, `DriveBar`, `ObjectiveLine`, `MiniMap`,
    `Rail`, all made visible for the measurement), and "sits over the scope's mask and under the
    report" (`Z_INDEX` 14, between 13 and `PANEL_Z_INDEX` 15).

## What I could not verify, and one thing that needs Karen

**THE LIVE SHOT WAS NOT OBTAINED, AND THE FRAMES ARE NOT OF A REAL PELLET.** This is the weakest part
of this request and it is stated first.

* The frames (`<runs-dir>/t198-buck-card.png`, `t198-slug-card.png`, `t198-farside-card.png`,
  `t198-buck-and-report-card.png`, all looked at) are taken from the player's own eye in a running
  DEV session, and every line of the drawing is the shipped client's: the payload is sent down the
  REAL remote the server uses for the card (`Report.Remotes.ReportEvent`, which is exactly what
  `HitLog.toShooter` fires) rather than being measured off a pellet. The readback off the Instances
  is in `<runs-dir>/t198-frames.log` -- 4 dots for the pattern, 1 for the slug, 3 mirrored onto
  `ArtMirrored`, label `H I T   -   B U C K   4 / 9`, card at (16, 464), 188 x 138, ZIndex 14.
* **The Forest Test place could not run this change at all**, which is why no live shot landed there.
  MEASURED: in that place `ReplicatedStorage.Report`'s source has no `CARD` block and
  `ServerScriptService.HitLog`'s has no `cardWorthy`, while `Hud.BoarArt` and `Hud.HitCard` ARE
  present -- a half-synced tree. `servePlaceIds` in `default.project.json` is the DEV place only.
  **NEEDS KAREN:** open the Forest Test Studio and press Rojo **Connect** (or re-publish DEV to it)
  before judging this in the wood.
* Seven live runs in the Forest Test are in `<runs-dir>/t198-live.log` and the session's own console;
  what they measured, all of it worth keeping: the weapon REFUSES a shot from outside the hunter's
  stand circle ("NOT IN YOUR STAND") and between drives ("THE DRIVE IS OVER"), so a hunter may not be
  teleported to a chosen range; and a first-order lead computed from the client's
  `AssemblyLinearVelocity` threw every shot off the animal.
* **The fatal mark has not been seen on a live kill** -- only in the client spec, which drives
  `markFatal` directly.
* The buckshot-at-15-m and slug-at-40-m frames Karen asked for are therefore at the PAYLOAD level,
  not the pellet level. The server specs are what stand behind the pellet counts.

Nothing else: no `.rbxm`, no `ignoreUnknownInstances`, no flag, no `poses.json`, no Architect design
run (this extends the drive report rather than adding a system; tasks 135/137/138 did the same).
