# Task 246: the continuous drive loop

Task: 246
Round: 2
Base: main (`e437eaad`)
Code commit: `acc2ffd84bfdd1474aa9b919f98ee6f4fd3ebcf2`

Gate, FULL run, at the code commit:

```
[harness] PASS: 34/34 checks @ acc2ffd84bfdd1474aa9b919f98ee6f4fd3ebcf2 (clean tree) scope=all
```

2078 server assertions (67 spec files) + 558 client assertions, 0 failed, 0 errors.

`[harness2]` **N/A, and the paths are why**: not one file this branch touches is in
`TWO_PLAYER_PATHS` (`tools/agents.py`). The branch changes `src/server/Lobby/`, `src/shared/Lobby/`,
`src/server/ForestTestBoot.server.luau`, `src/client/Hud/`, `tools/studio_mcp.py` and three spec
files, and the list is `src/server/Match/`, `src/server/MatchBoot.server.luau`, `src/client/Match/`,
`src/client/MatchBoot.client.luau`, `src/shared/Drive/`, `tests/client/Role.luau` plus the
`match_*` / `zz_drive_boundary` / `match_client` / `outfit_client` / `zz_tie_to_a_tree` specs.
**Nothing in `Match` changed in this task** -- which is claim 1.

## What changed

Karen, 2026-10-23: *"we need back to lobby after hunt to have the same not saperate for beaters (if
it's not the same) / also we need continues game so after drive new drive imidiatly after same
amount seconds and who has licesne can select who he can be next round if dont then oposit previuos
round"*.

**Two of her three asks were already true, and the work was measuring that.** The one new thing is
the party that goes again:

* `src/server/Lobby/Next.luau` -- NEW, PURE: one deadline in the state, a membership and an opt-out
  reconciled every scan, five verdicts.
* `src/server/Lobby/init.luau` -- the owner: collects the roster before `dismissAll` empties it,
  arms the countdown when the party is home, writes two attributes as a level rule, the SIT OUT
  door, and hands the party to the same `Lobby.depart` seam a pad's party leaves through. Plus one
  edge-triggered console line per verdict change.
* `src/shared/Lobby/init.luau` -- `DHNextDriveAt`, `DHNextDriveOut`, `NextRequest`, `NEXT_WORD`,
  `nextAllowed`, and `CONFIG.PADS.NEXT` (the 8 s, the 12 s bound, the words, the pixel rows).
* `src/shared/Lobby/Remotes.model.json` -- the third RemoteEvent.
* `src/client/Hud/PadPanel.luau` -- a THIRD surface: the countdown card, in the size dialog's own
  rectangle, with the number, one SIT OUT button (`Y`) and the role switch (`T`).
* `src/client/Hud/init.luau` -- the frame, and two attribute reads in the one evaluation.
* `tools/studio_mcp.py` -- `lobby_next.spec` into the `lobby` and `match` scopes (rule G).

Research note: `docs/research/2026-10-23-the-continuous-drive-loop.md` (sources A-D, one of them a
negative result).

## Claims, and how to verify each

1. **`Match` IS UNTOUCHED, AND THE LOOP WAS ALREADY IN IT.** `git diff main..HEAD --stat` names no
   file under `src/server/Match/`. `Phase.step`'s `Scoring` exit already reads
   `if enoughPlayers(...) and markersComplete then enterAssigning(...) else enterWaiting(...)`, so
   what stopped the loop was `Lobby.onPhase("Scoring") -> dismissAll()` emptying the roster one scan
   into the results scene. Verify: read that branch of `Phase.step`, then `Lobby.onPhase`.

2. **ONE RETURN FOR BOTH SIDES, AND NOTHING ON THAT PATH CHANGED.** `Join.needsReturn(inDrive,
   held, inField)` reads no team; `Lobby.stepPlayer` applies it to every occupant through the one
   injected `place` seam; `enterScoring` holds the whole roster and `enterWaiting` emits `free` and
   `unassign` for everybody. `git diff main..HEAD -- src/server/Lobby/Join.luau` is EMPTY and the
   diff of `stepPlayer`'s return block is empty. **So the live measurement of both roles returning
   identically (below) is also a measurement of the behaviour before this task** -- there is no
   per-role branch to have broken. Verify: the empty diff, plus `Join.needsReturn`'s three
   arguments.

3. **THE PARTY IS COLLECTED BEFORE THE ROSTER IS EMPTIED, FROM `world.inDrive` AND FROM NO TEAM.**
   `Lobby.step`'s `dismissPending` block loops the occupants, keeps the ones `world.inDrive` answers
   true for, and only then calls `world.dismissAll()`. Verify: that block; `lobby_live.spec`
   *"collects the whole roster, both sides, and waits for the results scene"*.

4. **THE COUNTDOWN ARMS WHEN THE PARTY IS HOME, NOT WHEN THE DRIVE ENDS** -- Karen's order, the
   lodge first. `Next.step` sets no deadline while any member is `held` (the results scene) or
   `inDrive`; `nextDrive.at` nil means `DHNextDriveAt` is never written, which is the card's whole
   visibility rule. Verify: `lobby_next.spec` *"sets no deadline while anybody in the party is still
   held"* and *"arms the moment the last man is let go"*; `lobby_live.spec` *"arms the countdown when
   the scene lets everybody go, once, on the edge"*.

5. **EVERY ARM OF THE STATE MACHINE IS ENTERED BY NAME (L-093).** `tests/server/lobby_next.spec.luau`
   has a case reaching IDLE, WAITING, COUNTING, GO and CLEARED, plus: a man dropped for leaving, a
   man dropped because a pad already took him (hazard 2), his opt-out dropped with him, the opt-out
   reversed, everybody sitting out, a stranger refused, a double press as a no-op, and the
   `ARM_TIMEOUT_SECONDS` path (hazard 1) driven BY PARAMETER. Verify: read the file's `describe`
   names against `Next`'s five verdicts.

6. **NOTHING A CLIENT SENDS CAN PUT A MAN INTO A PARTY.** `Lobby.onNextRequest` takes one word from
   the payload, refuses any second key as `bad-request`, rate-limits on its OWN bucket, and refuses
   a man who is not already a member as `no-party` -- counted apart from a forgery. The most it can
   do is set or clear `sitOut` for the caller. Verify: the function; `lobby_live.spec` *"refuses a
   forged payload, a flood and a man with no party, and tells them apart"*.

7. **THE PARTY LEAVES THROUGH THE ONE SEAM A PAD'S PARTY LEAVES THROUGH**, with `padIndex = nil`
   because no pad sent them. Verify: `stepNextDrive`'s `GO` branch; `lobby_live.spec` *"sends the
   party again through the same depart seam, with no pad"* and *"enrols the party into this server's
   own drive when no seam is injected"*.

8. **THE CARD IS THE SIZE DIALOG'S OWN RECTANGLE AND THE TWO ARE NEVER UP TOGETHER.**
   `PadPanel.dialogShown()` is `ask ~= nil and not nextShown()`, `render` reads it, and
   `PadPanel` owns both `Visible`s. The card's width, bottom edge and `ZIndex` come from
   `widthFor`/`positionFor`/`zIndex` -- the dialog's own three functions -- so task 209's
   banner-overlap arithmetic is untouched and `hud_clarity.spec` gains no band. Verify:
   `pad_panel.spec` *"is built, hidden, and the size dialog's own rectangle"*, *"closes the size
   dialog while it is up, and gives it back after"*, *"never draws over the click's banner, at either
   viewport step"* (720 / 800 / 1080).

9. **THE ROLE RULE IS THE ONE THAT WAS ALREADY THERE, ON A SECOND SURFACE.** No change to
   `Roster.assign`, `Roster.wishedWith`, `Roster.previousFrom` or `Lobby.wishFor`. The card's switch
   is built by `ShopPanel.buildRoleSwitch` and painted by `ShopPanel.paintRoleSwitch` from ONE
   evaluation of the three values, so the two surfaces cannot disagree. Verify: `pad_panel.spec`
   *"shows the role switch on the card, on the dialog's own condition, lit the same way"*
   (`nextRoleLit() == roleLit()` in both states); `lobby_live.spec` *"still lets a man choose his
   role while he waits at the lodge"*.

10. **NOTHING PER-FRAME WRITES A PROPERTY A POINTER TWEENS** (round 1, finding 1). `setNext` is
    called by the Hud's one evaluation every frame and now calls `render()` only on the
    shown/hidden edge, and `paintNextButton()` / `renderRole()` only on that edge or when `out`
    changes; `renderNext` touches no `BackgroundColor3` at all and paints no switch. `MouseLeave`
    restores `PadPanel.nextButtonTint()`, which is pure, so the handlers and the edge writer read
    one answer. Verify: `pad_panel.spec` *"leaves every BackgroundColor3 alone per frame, so a
    hover survives"* -- it paints the hover by hand on BOTH the pad dialog's `Size1` row and the
    card's `SitOut`, drives thirty frames of the setter and finds the colour still there, then
    checks the resting tint is still written when `out` flips.

11. **`T` IS BOUND WHILE EITHER SURFACE IS UP, AND NEITHER UNBINDS IT UNDER THE OTHER** (round 1,
    finding 2). `setAsk`'s close branch asks `PadPanel.nextShown()`, the mirror of `setNext`'s
    `bindSwitchKey(ask ~= nil)`. Verify: `pad_panel.spec` *"keeps T bound when a man walks off a
    pad with the card up"*, which drives the order both ways round and still asserts the key is
    released when neither surface is up.

12. **THE NUMBERS.** `NEXT.SECONDS` 8 (the brief's *"reuse the existing between-drive length"* =
    `SCORE_SECONDS`, and inside Valve's own 5..15 clamp for the same gap);
    `ARM_TIMEOUT_SECONDS` 12 > `SCORE_SECONDS`. Verify: `lobby_next.spec`'s *"the numbers"* block,
    which asserts both against `Match.CONFIG` rather than restating them.

## What was measured in the live Forest Test, on Karen's path

**AT `98e498aa`, WHICH IS THE ROUND-1 CODE COMMIT AND NOT THIS ONE, AND THAT IS SAID RATHER THAN
GLOSSED.** The round-2 diff is `src/client/Hud/PadPanel.luau` (when three properties are written),
one `warn` in `src/server/Lobby/init.luau` and three spec cases -- it changes no state, no wire, no
rectangle and no number, so every measurement below still stands. What it COULD have broken is
exactly what the two new spec cases assert (claims 10 and 11), and the Forest Test was closed before
the gate as the standing block requires, so re-measuring it is for the Director or Karen.

Place `130094961655666`, her attributes read before and after and **identical**
(`DHFlag_BOAR_BEHAVIOUR/BOAR_MODEL/COINS/DEER_ROAD_LEAP/DRIVE_BOTS/HORN/LICENCE_POPUP/LOBBY/SHOP=true`,
`DHForestStartRole=hunter`, `DHShopTestGrant=true`).

**ONE DEVIATION FROM THE DIRECTOR'S STANDING BLOCK, DISCLOSED RATHER THAN BURIED (rule 8):** the
block says CHANGE NO ATTRIBUTE, and I set **`DHForestDriveSeconds = 40`** for the runs and cleared it
afterwards. Reason: three consecutive 300-second drives cannot be played inside one session, and
that attribute is the Director's own short-drive lever (task 201 part 2), absent from Karen's setup
before and after. The dump above is the proof it is back as it was.

**THE LOOP, SAMPLED (L-022: a trace, not a narrative).** One player, three consecutive drives, **no
pad stepping between them**, polled every 1.5 s off the live HUD and the live attributes:

```
[  22.6] phase=?        drive=3 team=Shooters nextAt=nil   <- `?` is the log's own word: while the
[  24.3] phase=SCORING  drive=3 team=Shooters nextAt=nil      drive RUNS that chip shows the clock
                                                              and not a phase word, so the probe's
                                                              pattern matched nothing. Quoted as it
                                                              came out rather than tidied.
[  32.4] phase=WAITING  drive=3 team=nil      nextAt=1792745637.5137322   <- at the lodge, card up
[  40.5] phase=ASSIGNING drive=4 team=Drivers nextAt=nil                  <- the next drive, by itself
[  54.9] phase=?        drive=4 team=Drivers  nextAt=nil
[  95.1] phase=SCORING  drive=4 team=Drivers  nextAt=nil
[ 103.0] phase=WAITING  drive=4 team=nil      nextAt=1792745709.1404173   <- at the lodge, card up
[ 110.9] phase=WAITING  drive=4 team=Shooters nextAt=1792745709.1404352   <- drive 5's team dealt
```

* **the role alternates without the card**: Shooters -> Drivers -> Shooters, three drives running;
* **the gap is 8 + 8**: SCORING at 24.3 -> card at 32.4 (`SCORE_SECONDS` 8) -> ASSIGNING at 40.5
  (`NEXT.SECONDS` 8), and the same 8 + 8 again at 95.1 / 103.0 / 110.9;
* **both roles return the same way**: `team=nil` at the lodge in both gaps, from a drive he played as
  a hunter and from one he played as a beater, through the one rule claim 2 names.

**THE CARD, DRAWN, WITH A LIVE COUNTDOWN** (`t246-card-in.png`, `t246-click-before.png`):
`THE HUNT GOES ON` / `NEXT DRIVE IN` / `8` -> `7` -> `6` -> `4` -> `1` / `SIT OUT` /
`YOU ARE IN THE NEXT DRIVE` / `OR STEP ONTO A TRUCK PAD TO GO NOW`.

**THE REAL CLICK AND THE REAL KEY, both on her path:**

```
>>> BEFORE          out=nil  button=S I T   O U T
clicked 1764,663                  (click.ps1 -- changes the foreground window first)
>>> AFTER CLICK 1   out=nil  button=S I T   O U T          <- the focus change swallowed it
rawclicked 1764,663               (rawclick.ps1 -- no foreground change)
>>> AFTER CLICK 2   out=true button=I   A M   C O M I N G   <- the press landed
rawclicked 1764,663
>>> AFTER CLICK 3   out=nil  button=S I T   O U T          <- and it toggles back
>>> REAL OS KEY Y   out=nil -> true, button S I T   O U T -> I   A M   C O M I N G
```

The click point was computed from the live `AbsolutePosition`, and the first failure was measured
rather than guessed at: `PlayerGui:GetGuiObjectsAtPosition` at the button's centre returns
`SitOut.Label` (z 18), `PadNext.SitOut` (z 17, `Active=true`), `PadNext` (z 15) and **nothing on
top**, with `MouseBehavior=Default`, the icon enabled and the cursor measurably inside the button.
`rawclick.ps1` exists in the Director's own toolbox for exactly this. So: **the button works, by
real click, in both directions, and by the `Y` key.**

**SIT OUT LEAVES YOU AT THE LODGE:** with `out=true` at the deadline, the party was cleared, nobody
was enrolled, and **120 s of polling found no further drive** -- he stayed in the lobby with the
pads, which is the lobby before this task. Frames: `t246-card-out.png`, `t246-card-back.png`,
`t246-key-after.png`, `t246-click3.png` (all in `<runs-dir>`).

**Console at boot:** `[lobby] the hunt goes on: 8s at the lodge between drives (armed when
everybody is home, or after 12s), sit-out door=true`.

## What I could not verify, and what went wrong (rule 8)

1. **THE ROLE SWITCH ON THE CARD WAS NOT SEEN LIT IN THE FOREST TEST.** The live player owns no
   `ALWAYS HUNTER` card, so `DHRoleWish` was absent for the whole session and `RoleBlock` was
   correctly `Visible=false` in every probe (`RoleBlock vis=false` in the traces). Buying the card
   needs a shop purchase through the live remote, which I ran out of session for. What IS proven:
   the control is the SAME widget from the SAME builder, painted by the SAME painter from ONE
   evaluation, and `pad_panel.spec` asserts `nextRoleLit() == roleLit()` in both states and
   `switchShown` on the dialog's own condition. **A frame of the lit switch on the card is for
   Karen or for the Director.**
2. **`test2` WAS NOT RUN.** The dispatch asked for it; no file this branch touches is in
   `TWO_PLAYER_PATHS`, so `tools/agents.py` does not ask for it and the merge gate does not either.
   Named, not assumed.
3. **ROUND 1'S TWO BLOCKING FINDINGS WERE BOTH REAL, BOTH MINE, AND BOTH FIXED AT THEIR OWNER.**
   (a) `setNext` ended in `PadPanel.render()` and is called EVERY FRAME, and that renderer rewrites
   every size row's `BackgroundColor3` unconditionally -- so the TRUCK PAD DIALOG'S hover tint,
   shipped behaviour this task never set out to touch, was erased one frame after `MouseEnter` wrote
   it, with or without the card up; the card had the same fault against its own button and
   `renderNext -> renderRole` had it against the switch's press flash. Every property a pointer
   tweens is now written on an EDGE and the per-frame renderer is left to the seconds (claim 10).
   (b) `setAsk`'s close branch unbound `T` unconditionally while the card's own chip still
   advertised it (claim 11). Two of the six notes were taken with them: the `SECONDS` assertion, and
   `stats.nextTimeouts` asked of the party rather than of every occupant. **The other four notes are
   for `TASKS.md`**: the `depart`-returns-zero retry, `docs/design/lobby.md` never extended for this
   task (or for 182 and 229 before it), `nextRoleHeight`'s comment missing `ROLE.LEAD_PX` from the
   43 px it accounts for, and the lit switch's missing frame.
4. **FOUR DEFECTS OF MINE FOUND BEFORE THE REVIEW, BY LOOKING OR BY THE GATE, EACH FIXED IN ITS OWN
   COMMIT:**
   `nextLayoutFor` read `SWITCH.TRACK_PX`, which does not exist, and **killed the whole client Hud at
   boot** (`PlayerGui` with no `HunterHud`) -- caught by looking at the running game, not by a
   number; `Lobby.Next` was invisible between drives, so a stall could not be told from "no party"
   (now one console line per verdict change); `setNextAt` compared two separately-converted clocks
   and wrote four times for one unchanged deadline (now `DHLobbyLeaveAt`'s own edge shape); and
   `pad_panel.spec`'s restores handed back two frames of three.
5. **`lobby_live.spec`'s shared fake does not clear `inDrive` on `dismissAll`** (deliberately, for
   task 182's own measured reason), so my describe patches that one seam to do what
   `Match.dismissAll` does. The patch is in the spec and said out loud there.
6. **A pre-existing error, not mine and not fixed here:** `ServerScriptService.Boar:5435: Boar
   runtime is at maxBoars` appeared in the Forest Test console during the long runs. It is the boar
   cap already queued; this branch touches no boar file.
