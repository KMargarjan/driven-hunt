# BRIEF for the Architect -- task 229: the role switch (`docs/design/role-switch.md`)

**Written by the Builder, carrying the Director's dispatch of 2026-10-21.** Read this first; it
overrides anything older in `docs/`, `TASKS.md` or an earlier design where they differ.

Karen, 2026-10-21, verbatim:

> *"we also need to have posibility to choose once you have a card always hunter maybe sometimes I
> want to be a beater we need to find a way to do that"*

The Designer's answer is **section 3 of `<runs-dir>/design/shop2-spec.md`** (2026-10-21, outside the
repo). **Every number and every word in that section is final and is not yours to revisit.** The
Builder's research note is `docs/research/2026-10-21-the-role-switch.md`: sources, the pattern
adopted, and the nine numeric targets.

## 1. What is already decided (do not re-open these)

1. **One wish per player**: `HUNTER` (the default) or `BEATER`. **Server-owned, client-told.** A
   client ASKS; the server is the only writer. The spec: *"No client decides anything: pressing a
   half sends a request, the server writes the attribute, and both controls redraw from it."*
2. **`BEATER` means two things together**: for that drive, `Roster.overruled` / the `always`
   override is **not applied** to him, **and** the roster is asked to **seat him on the beater side
   first**.
3. **It resets to `HUNTER` when the truck leaves.** The spec: *"the single most important rule in
   the design"*. The control says `NEXT DRIVE` and means exactly one.
4. **The reset is written as level-triggered reconciliation on the owner's own scan, not as a
   handler on the departure/leave signal** (Learning Agent L-029; and `Lobby.Join.needsReturn`'s own
   stated reason -- *"there are four ways to end up standing in the wrong place and only one of them
   is a phase change"*).
5. **Invisible to a non-owner, in both places** -- absent, not greyed, not locked.
6. **Two surfaces, one value**: PRIMARY the truck-pad dialog (between the header hairline and the
   four size rows, +119 px when shown, exactly today's height when not); SECONDARY the shop's owned
   `ALWAYS HUNTER` row (`ROW_SWITCH_PX` **124** instead of 64) in WIDE, and the detail pane's status
   block (70 px) in TALL. **The switch appears once, on whichever surface the item has -- never
   both.**
7. **Unavailable, with words, when it cannot be honoured** -- never silently ignored. The four
   captions are `A STAND ON THE LINE` / `WALKING THE DRIVE` / `NO BEATERS THIS DRIVE` /
   `ASKED FOR ALREADY`, and they are **rows in `Lobby.CONFIG.PADS.PANEL` and `Shop.CONFIG.TEXT`**,
   never string literals -- *"words are Karen's to rewrite"*.
8. **No new feature flag.** `Flags.MAX_FLAGS` is 14 and fourteen rows are declared, so there is no
   room; and the honest flag-off story already exists -- the item can only be bought with `SHOP`
   (and `COINS`) on, so with the shop off nobody owns it, `Economy.alwaysHunters()` is empty, no
   wish can exist and the game is bit-for-bit what it is today. **State that identity in the
   design** (`docs/design/role-rotation.md` section 7 is the model).
9. **No new profile field and nothing persisted.** The wish dies with the drive; a logout clears it
   by construction. `Economy.Store`'s template is not to be touched.
10. **The two-way segmented control does not animate anything but colour** (0.12 s Quad Out on
    `BackgroundColor3` / `TextColor3`). Nothing slides: `design-system.md` section 1.4.

## 2. The ONE question this design exists to answer

**Who owns `roleWish`?** It is a new shape for this repository: a value a PLAYER sets, that the
SERVER alone writes, that `Match`/`Roster` reads at assignment time, and that TWO client panels owned
by two different modules draw. The candidates, with what each already owns:

| Candidate | Already owns | Against |
|---|---|---|
| `ServerScriptService.Lobby` | the pads, the party, `DHPadState` / `DHPadFirst` / `DHPadMine`, the one inbound pad door (`Lobby.onPadRequest`), and `Lobby.depart` -- **the truck leaving** | it is the LOBBY: the wish is also set in the shop, which is a different building and a different door |
| `ServerScriptService.Shop` | the shop's door (`Shop.onRequest`), the rate bucket, *"the one place the ORDER of a purchase is written down"* | its header says it *"NEVER WRITES A LOADOUT, A POCKET, A TEAM, ..."*, and a role wish is team-shaped |
| `ServerScriptService.Economy` | ownership (`alwaysHunters`), the profile, `Economy.view()` | its own header forbids holding a `Player` or firing a remote; a wish is neither owned nor saved |
| `ServerScriptService.Match` | the drive, `state.assignment`, `Roster` | the wish is set in the LOBBY, before any drive exists, by a man who may never join one |
| a new owner | -- | rule 3 says one owner per system; a fifth module for one boolean needs a written reason |

**Rule on it, name it, and give it the full owner table** (`docs/design/truck-pads.md` section 7 and
`docs/design/role-rotation.md` section 2 are the two models). Specifically:

* **a. the owner** of the value, and the one function that writes it;
* **b. the WIRE IN**: which inbound door carries a client's ask. Note that `Lobby.onPadRequest` is
  today the pad's one door (*"THERE IS NO REPLY REMOTE"*, one wire in, none out) and
  `Shop.onRequest` is the shop's. Two doors onto one value, or one door, or a third -- rule on it,
  with the forgery counting and the rate limit named;
* **c. the WIRE OUT**: how the two panels learn the value AND whether the player owns the item at
  all. Measured facts the design must work with: `ShopState` is fired **only in reply to a request**,
  so a client that has never opened the shop knows nothing about what it owns; and the spec requires
  `PadPanel.setAlwaysHunter(owned)` -- *told*, never read -- for a man standing on a pad who may
  never have opened the shop in this session. The `DHPadMine` idiom (one attribute on the PLAYER,
  written only by the owner, read on the Hud's one existing evaluation) is the obvious candidate;
  **one attribute whose ABSENCE means "he does not own it" would answer both questions with one
  value** -- rule on whether that is right or whether the two facts must stay separable;
* **d. the RESET**: which scan reconciles it, against what desired state, and the worst-case lag in
  scans and in seconds. It must cover all of: the truck departing, a dismissal between drives, a
  `Scoring -> Assigning` transition, a leave, and a `Reset`;
* **e. the ROSTER RULE**: the exact pure signature(s) added to or changed in
  `src/server/Match/Roster.luau`, and how `Phase.enterAssigning` / the `join` branch reach it.
  `Roster.assign(userIds, previous, config, always)` seats `always` FIRST (task 221, round 3 -- the
  Director overruled an earlier design there with a measurement, so read that header before
  proposing a shape). State whether the wish is applied by **filtering `always` at the owner's edge**
  (so `Roster` learns nothing new) or by **a fifth argument** to `assign`, and prove your choice
  keeps targets 1-3 of the research note;
* **f. the `1/1` CASE.** The spec's state 6 is *"the pad has no beater line (`1 / 1`)"*, caption
  `NO BEATERS THIS DRIVE`. The Builder's reading, which you should confirm or replace with a better
  one: **a party of ONE cannot honour `BEATER`**, because `docs/design/bots.md` fills both sides with
  rigs but states twice that **no bot shoots** -- so a solo beater is a drive in which nothing can be
  shot. On the CLIENT the measurable trigger is `PadPanel`'s own `sent == 1` (the pad publishes only
  `DHPadState` and `DHPadFirst`; `DHPadSize` was *"considered and refused"*, so the party size is NOT
  on the client before the pick); on the SERVER the measurable rule is the roster size at assignment.
  Rule on both halves, and say plainly whether the client ever shows `NO BEATERS THIS DRIVE` before a
  size is pressed. If you believe the spec means something else, say so and rule -- the Builder will
  carry it to the Director rather than argue;
* **g. the SHOP ROW's hit-test**, which the spec already fixes: the two halves at `ZIndex = Z + 4`
  over the row's `Z + 2`, and pressing a half **also** calls `ShopPanel.select(id)`. Confirm it sits
  inside this repo's Z discipline.

## 3. What the design must also contain

1. **Every symbol added or changed, by name and signature**, per file, in the shape of
   `docs/design/role-rotation.md` section 4. Name the files; do not write the code.
2. **The owner table row for `GAME_DESIGN.md`'s *System owners*.**
3. **The flag-off / no-economy identity**, stated as an identity (item 8 above).
4. **How it is tested**, naming the spec files and the scope each belongs to in
   `SCOPE_SPECS` (`tools/studio_mcp.py`). Pure first: `match_roster.spec` can hold targets 1-3 of the
   research note with no world at all. Say which claims need the one Play client, and which -- if any
   -- genuinely need two (the gate for this task already asks for `test2`, because the change touches
   `src/server/Match/` and the teams).
5. **The hazards**, in the shape of section 9 of `role-rotation.md`. At least: the wish surviving a
   drive it should not; a non-owner's forged ask; the reset racing the assignment; two panels drifting
   apart; and the `ZIndex` press reaching the row instead of the half.
6. **What you deliberately leave alone.**

## 4. Deliberately out of scope

Sections 1, 2 and 4 of the shop2 spec (task 228, merged). Persistence of the wish. A role wish for a
player who does NOT own `ALWAYS HUNTER` (it is a different feature and Karen did not ask for it).
Bots that shoot (TASKS.md 161a). Anything about the truck, the countdown or the party size.
