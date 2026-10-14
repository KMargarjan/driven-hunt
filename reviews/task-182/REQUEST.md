# Task 182 review request

Task: 182
Round: 1
Base: 718176d (main, #165 merged)
Code commit: 1c97dc57a8050c009bb0573ed19bfd6f33e9537c

```
[harness] PASS: 33/33 checks @ 1c97dc57a8050c009bb0573ed19bfd6f33e9537c (clean tree) scope=all
```

Run twice at this commit (`.agent-logs/task182-test-final1.log`, `task182-test-final2.log`):
1415 server assertions, 337 client, 54 + 19 spec files.

**`[harness2]` is N/A and that is checkable, not hopeful.** `TWO_PLAYER_PATHS` in `tools/agents.py`
is `src/server/Match/`, `src/server/MatchBoot.server.luau`, `src/client/Match/`,
`src/client/MatchBoot.client.luau`, `src/shared/Drive/`, `tests/client/Role.luau` and their specs.
**No file under any of them changed** — `git diff --name-only 718176d..HEAD` is the check, and
`grep -rn Lobby src/server/Match/` still answers nothing.

---

## What changed

Karen, 2026-10-14 ~09:30: *"when start hunt we need to go next to truck has to be mark where and has
to be coloroude circle like in all games or rectangle where people stand and can be 1/1 or 4/4 you
can select on dialiog how many like in roblox games and can be several truck like 4 of them nicly
aligned next ot each other and you come to truck back rectangle and can click and select how many
players"*.

Four coloured rectangles, one behind each of task 180's trucks, replacing task 177's single orange
circle. The countdown moves from the PLAYER to the PAD. Built to `docs/design/truck-pads.md`
(Architect PASS, no blocking decisions); reasoning in `docs/research/2026-10-14-truck-pads.md`.

---

## Claims

**1. The pad state machine is pure, and every state and transition in the design's section 6.2 is a
spec case.** `src/server/Lobby/Pads.luau`: `Pads.step` takes `(pad, members, now, cfg)` and returns
one new pad and one verdict, ONE transition per call. *Verify:* `tests/server/lobby.spec.luau`,
`describe("the pads: the state machine")` — asks the first man; elects the earliest `since` and
breaks a tie by userId; takes a pick only while `sizing` and only one of the four sizes; defaults to
1 at `PICK_TIMEOUT_SECONDS`; counts down when full AND when the fill times out; departs exactly once
at the deadline and never again in `leaving`; cancels only when EMPTY; re-elects with a fresh clock;
does not move the deadline on a join or a leave.

**2. Only the first man on the pad may pick, and every fact is measured server-side.**
`Lobby.onPadRequest` (`src/server/Lobby/init.luau`) is `Shop.onRequest`'s shape: public so a spec
drives it by parameter, rate-limited per player, and it reads WHICH PAD HE IS ON off the character
(`Pads.indexAt(rootOf(player), ...)`), never off the payload. A forged payload is counted in
`badRequests`; a legal-but-refused pick in `refusedBy`. *Verify:*
`tests/server/lobby_live.spec.luau`, *"takes a pick only from the man it asked, on the pad he is
standing on, while it is asking"* — seven forged payloads all `bad-request` with `refusedBy` EMPTY,
then `not-first`, `not-on-pad`, `too-late`, `rateLimited`.

**3. The party reaches the drive, once per member, through task 177's existing door.**
`Lobby.depart` → `Lobby.enrolHere` → `world.enrol` per member. `Lobby` still writes no team, no
character position and no roster entry. *Verify:* `lobby_live.spec`, *"gives every member of a
departing party the SAME deadline, once, on the edge"* (two members, two `enrol` calls, no third on
the next scan, pad empties by itself) and *"defaults the pick to one and sends him alone"*.

**4. Four pads are four doors into one hunt, and the mid-drive join is kept.** The Director's
default (design 6.5). *Verify:* `lobby_live.spec`, *"still enrols a party while a drive is running"*.

**5. The reserved-server teleport is a SEAM, designed and not built, reachable by parameter in both
directions.** `world.depart` defaults to `Lobby.enrolHere`; `ReserveServerAsync` +
`TeleportToPrivateServer` are named in `Lobby.depart`'s header with the one sentence saying Studio
cannot test a teleport. No flag row was added, and the design's 9.1 says why (`Flags` is at
`MAX_FLAGS = 13`, and a flag over code that does not exist has no second state to reach). *Verify:*
`lobby_live.spec`, *"hands the party to the injected depart seam instead"* — `enrol` is NOT called.

**6. Outbound is two attributes on the pad's own part and no new remote; inbound is one
`RemoteEvent`.** `DHPadState` / `DHPadFirst`, written by `Build.setPad` (the one writer of every part
in `Workspace.Lobby`), edge-triggered. `src/shared/Lobby/Remotes.model.json` holds `PadRequest` and
nothing else. *Verify:* `lobby.spec` *"writes a pad's words and attributes only when they CHANGE"*
(the same values twice returns false and `padWrites` does not move) and `lobby_live.spec` *"writes
nothing to a pad when nobody moves"* (50 scans, `padWrites` unchanged).

**7. The client's four readers work on a lobby that is really in `Workspace`, and drop a destroyed
part rather than answering a stale position.** `Lobby.padPart`, `padPositions`, `padStateOf`,
`padAsking`. *Verify:* `lobby.spec` *"is found by the FOUR READERS the client has"* — it builds into
`Workspace`, asserts all four plus `spotPart() == padPart(1)`, asserts that a pad in `filling` asks
NOBODY even though it still remembers who picked, then destroys it and asserts all three readers go
empty.

**8. The dialog is told, draws what arrived, and sends one two-field message per press.**
`src/client/Hud/PadPanel.luau` — `Visible == (ask ~= nil)` where `ask` is
`Lobby.padAsking(LocalPlayer.UserId)`, so the client holds no opinion about who is first. *Verify:*
`tests/client/pad_panel.spec.luau` — the frame's rectangle fits 400 px and every button is ≥ 44 px;
the four labels are the DATA's own, in order; `press` fires exactly once with `{pad, size}` and two
fields; a size not in `SIZES` fires nothing; `padsize`-keyed `Cursor`/`Input` requests and releases.

**9. Pad 1 is still called `TruckSpot`, so nothing outside this repo has to change.**
`Lobby.spotPart`, `spotPosition`, the Hud's `kind = "truck"` chevron and the Director's `smoke.sh`
all keep working. **No change to `smoke.sh` is requested**, and the arithmetic it depends on is
asserted: `PICK_TIMEOUT 8 + COUNTDOWN 5 + 2 scans < 20`. *Verify:* `lobby.spec`, *"defaults the pick
to ONE ... and reaches the drive unattended"* and `Data.padPartName(1) == Data.SPOT_NAME`.

**10. THE PADS WERE BURIED, I FOUND IT BY LOOKING, AND THE FIX IS MEASURED (commit `1c97dc5`).**
The first live frame showed four billboards and NO rectangles. Probed rather than guessed: every
pad's top was 149.828 and the terrain under it 150.000 — all four were **0.17 studs underground**.
The design's arithmetic assumed the surface a pad lands on is the nominal shelf; Roblox terrain is
VOXELISED, so `Field.fill`'s actual surface was 0.75 studs higher. `Build.pads` now takes the
world's own `groundAt` — the reader the owner already uses for the shelf and `Markers.setReaders`
uses for the stand rings — and sits each deck on what it measures. *Verify:* `lobby.spec`, *"sits
each pad on the ground that is REALLY there"* (it asks once per pad, at the pad's own centre; the
top clears the measured ground; x and z do not move; a reader that answers nil leaves the pure
arithmetic standing), and the live re-probe: `clear=+0.080` on all four, which is `LIFT_STUDS`.

---

## Screenshots, both inspected (rule 5)

* `.screenshots/182-pads-row.png` — the four trucks side by side, each with its coloured rectangle
  behind it (green / blue / orange / violet) and a glowing edge, each billboard reading `TRUCK n`
  and `0 / -`. The objective line reads *"step on a truck pad to hunt"* and the chevron *"TRUCK 12
  m"*. `182-pads-angle.png` is the same row from the south-west.
* `.screenshots/182-size-dialog.png` — the dialog on the live client, opened by the server's own
  attribute: `HOW MANY PLAYERS?` over `1 / 1  alone`, `2 / 2`, `4 / 4`, `8 / 8  full hunt`.

Both are in the **Forest Test** place in Play (the lobby is built at run time and `Lobby.ANCHORS`
has one row), so they are not reproducible from the DEV place the harness uses.

---

## What I could not verify

1. **`test2`.** N/A by the path list above, not by judgement. Not run.
2. **The reserved-server teleport.** Not built and not testable in Studio (design section 9). The
   seam is driven in both directions by a spec; the real call is not.
3. **A real tap on a dialog button.** A spec cannot fire `GuiButton.Activated` and the harness's
   input scenarios carry keys, mouse buttons and moves only, so `PadPanel.press` proves the ACTION
   and not the touch. `Rail.press`' own stated limit.
4. **How 9 x 12 reads under eight bodies.** One man stood on a pad in the live place; eight did not.
   Arithmetic says 108 square studs holds them. Karen's eye decides.
5. **`FILL_TIMEOUT_SECONDS` = 45 and `PICK_TIMEOUT_SECONDS` = 8** are first values. Nobody has
   waited 45 seconds on a pad.
6. **The Director's `smoke.sh` was not run** — it refuses while Studio is not in Edit, and it was
   the Forest Test session I was photographing in. The arithmetic it depends on is asserted
   (claim 9); the run itself is the Director's.
7. **A second Studio was attached throughout** (DEV + Forest Test). `tools/studio_mcp.py test`
   pinned DEV and the reports carry `comes from the DEV place (136410205938347)`, but the FIRST
   attempt of the first run landed on the Forest Test place and failed its own place check —
   StudioMCP's `list_roblox_studios` was alternating between the two. It is a harness/StudioMCP
   flake, it is reported rather than worked around, and every PASS line above names DEV.

---

## Notes for the Director (not blocking)

* **The objective line is *"step on a truck pad to hunt"* and not the dispatch's *"Step on a truck
  pad to start a hunt"***. The Director's sentence is 35 characters and `hud_clarity.spec` bounds
  that table at 33 with the engine's own `TextFits` at 400 px — task 177 raised it from 32 to 33 by
  measuring. Shortened rather than raising the bound a second time in two tasks.
* **The trucks are white**, which is the free model's own colour (task 180), not this task's.
* Design section 18 lists five things for Karen (the colours, the words, 9 x 12, the two timeouts)
  and four for the Director (smoke.sh's wait must be ≥ 15 s, the teleport flag row's ordering, the
  chevron's arrival band on a 9 x 12 pad, and the `lobby.md` replacement sections, which are the
  Architect's edit and are queued rather than made here).
