# The role switch: a man who bought the hunter's place asks to beat, for one drive

**Task 229.** Karen, 2026-10-21, verbatim:

> *"we also need to have posibility to choose once you have a card always hunter maybe sometimes I
> want to be a beater we need to find a way to do that"*

The designer's answer is section 3 of `<runs-dir>/design/shop2-spec.md` (2026-10-21), with
`shop2-role.png`. This note is the half the spec does not carry: what the system must do, what was
borrowed, from whom, and the numbers it is held to.

---

## 1. What the system must do

`ALWAYS HUNTER` costs 2000 and grants `alwaysHunter = true`. `Economy.alwaysHunters()` derives the
set of owners from the owned sets; `Roster.assign` seats every man in that set on the hunter side
FIRST and lets the rotation fill what is left; `Roster.overruled` names the ones the hunter-slot
count beat, so the Hud can say why. Today that is **unconditional**: there is no input to the drive,
from any direction, by which an owner can take a horn. That is the defect Karen named.

So:

1. **One wish per player**, `HUNTER` (the default) or `BEATER`, **server-owned**. A client asks; the
   server is the only writer. A client that could write it could put itself on either side of a
   drive, which is the whole security of `Lobby.onPadRequest` and `Shop.onRequest`.
2. **`BEATER` means two things, together**: the `alwaysHunter` override is NOT applied to him for
   that drive, and the roster is asked to seat him on the beater side first. One without the other
   is not the feature -- dropping him out of `always` alone leaves him in the ordinary rotation,
   which seats him as a hunter about half the time.
3. **It resets to `HUNTER` when the truck leaves.** The spec calls this *"the single most important
   rule in the design"*: a man who beat once and forgot would quietly stop being a hunter for ever,
   which is the opposite of what he paid 2000 for. The control says `NEXT DRIVE` and means one.
4. **It is a wish, not a guarantee** -- already true of the item (its blurb: *"unless the teams
   cannot be made even"*). The one case that cannot be honoured is a drive with no other side: a
   party of one. There the control is **unavailable and says so**, never silently ignored.
5. **Invisible to a non-owner**, in both places. Not greyed, not locked -- absent. *"A control for a
   thing you do not have is an advertisement, and this shop already has a shop for that."*
6. **Two windows onto one value**: the truck-pad dialog (primary -- the only screen every player
   passes through on the way to every drive) and the shop's owned `ALWAYS HUNTER` row (secondary --
   the receipt that teaches him it is a choice). Both redraw from the one value; neither holds one.

### 1.1 Why a party of one cannot honour `BEATER`, measured rather than assumed

`docs/design/bots.md` fills every empty slot on BOTH sides with a visible R15 rig
(`TARGET = { hunters = 4, beaters = 4 }`), so a solo drive is not empty of beaters. But the same
design says, twice, that **no bot shoots**: section 1.3 (*"They do not shoot"*; a shooting bot is
TASKS.md 161a) and section 2 (*"No bot shoots, and no bot is protected by the safety rule"*). So a
solo player who beats is a drive in which **nothing can be killed and nothing can be scored** -- not
an unbalanced drive, a pointless one. That is the measurement behind rule 4, and it is why the
unavailable state is a real state and not a defensive branch.

---

## 2. Three external sources, and what each got right and wrong for us

### 2.1 ioquake3 -- `code/game/g_cmds.c`, `SetTeam()` -- **the refusal that speaks**

* <https://github.com/ioquake/ioq3/blob/main/code/game/g_cmds.c>
* Licence **GPL-2.0**. Active: last push 2026-10-12, not archived (checked 2026-10-21).
* Already cited by `docs/design/role-rotation.md` section 12.1 for `PickTeam` / `TeamCount` in
  `g_team.c`; this is the other half of that file's family, the one that handles a player's *request*.

```c
void SetTeam( gentity_t *ent, const char *s )
...
if ( g_teamForceBalance.integer && !client->pers.localClient && !( ent->r.svFlags & SVF_BOT ) ) {
    ...
    // We allow a spread of two
    if ( team == TEAM_RED && counts[TEAM_RED] - counts[TEAM_BLUE] > 1 ) {
        trap_SendServerCommand( clientNum, "cp \"Red team has too many players.\n\"" );
        return;         // ignore the request
    }
```

**What it does well, and is adopted:** the client sends a *string request*, the server is the one
writer of `sess.sessionTeam`, and a refused request **prints a sentence naming the reason**. Our
`NO BEATERS THIS DRIVE` is that `cp` line: the refusal is a state with words, not silence.

**What it does badly for us, and is not adopted:** it applies the change **immediately** and
**stores no pending preference at all** -- either the team changes now or the request is gone.
Karen's sentence is *"sometimes I want to be a beater"* about a drive that has not started, and the
control says `NEXT DRIVE`, so we need exactly the thing ioquake3 declines to keep: a stored wish
with a lifetime.

### 2.2 Xonotic -- `qcsrc/server/teamplay.qc`, `TeamBalance_CheckAllowedTeams` -- **the unavailable state, computed before the click**

* <https://github.com/xonotic/xonotic-data.pk3dir/blob/master/qcsrc/server/teamplay.qc>
* The GitHub mirror declares no licence field; Xonotic's gamecode is distributed under the GPL.
  Active: last push 2026-10-21, not archived (checked 2026-10-21). **Pattern read; no code copied**,
  so the licence does not reach this repository either way.

`entity TeamBalance_CheckAllowedTeams(entity for_whom)` builds a balance entity that marks teams
`TEAM_NOT_ALLOWED`, and the team menu is drawn from that -- so a team you cannot join is **drawn as
unjoinable rather than discovered by clicking it**. That is precisely the shape of our state 6: the
unavailability is a fact the control is drawn FROM, not an error it reports afterwards.

**What it does badly, and is deliberately inverted:** `Player_SetTeamIndex`, `SetPlayerTeam` and
`MoveToTeam` all refuse by **returning `false` with no message to the player**. Karen reads a silent
no-op as broken, and this repository's Hud rules say so in writing
(`docs/design/hud-clarity.md`), so every refusal here carries a caption.

### 2.3 Shine (Natural Selection 2 admin mod), Vote Shuffle -- **a team preference the optimiser may overrule**

* <https://github.com/Person8880/Shine/wiki/Vote-Random> - repo <https://github.com/Person8880/Shine>
* **No licence declared** in the repository metadata (checked 2026-10-21). Active: last push
  2026-02-07, not archived. **Pattern read; no code copied.**
* The closest precedent found for the thing Karen asked for: a *preference* a player sets, fed to a
  team-balancing optimiser which *attempts* to honour it. The wiki's own words are that the optimiser
  will *"attempt to keep them on the same team"* and then *"check the final teams to determine if the
  weighted majority of players have the team they want"*, under a `TeamPreferences` group of
  settings.

**Adopted:** the preference is an **input to the balancer and never a decision**, and whether it was
honoured is read off the FINAL teams rather than promised in advance. That is already how this
repository treats the stored turn (`Roster.previousFrom` is *"a SUGGESTION"*) and the bought place
(`Roster.overruled` is computed *from the assignment that was actually made*), so the wish joins an
existing family instead of inventing a fourth rule.

**Not verified, and recorded as such (rule 8):** a web-search summary states Shine clears the
preference at the end of a round; the wiki page I fetched does not say so in the text returned, and
the plugin's source was not read. So *"reset each drive"* is this repository's own rule, from the
designer's spec (section 3.1) and from Karen's *"maybe sometimes"*; Shine is cited only for the
preference-not-guarantee shape.

---

## 3. The pattern adopted, and the one thing invented

**Adopted, and all three already exist here** (rule 2 applies to internal patterns too):

| Borrowed from | What | Where it already lives |
|---|---|---|
| `Lobby.Join.needsReturn` | **level-triggered, never edge-triggered**: *"there are four ways to end up standing in the wrong place and only one of them is a phase change"* | `src/server/Lobby/Join.luau` |
| `PadPanel.setAsk` / `Rail.setWeapon` | the panel is **told** the fact by the Hud's one evaluation and reads no attribute itself | `src/client/Hud/PadPanel.luau` |
| `Economy.owedTeams` / `Economy.alwaysHunters` | a **frozen, memoised** read-only table handed to the drive through `Economy.view()`, nil or empty answering the pre-feature game by identity | `src/server/Economy/init.luau` |

The reset is written as **reconciliation to a desired state on the owner's own scan**, not as a
handler on the departure signal. The reason is not taste: the Backpack race (Learning Agent L-029)
and `Join.needsReturn`'s own four cases are the same lesson twice -- a man stops being in a drive by
departing, by being dismissed between drives, by leaving the server, by a `Scoring -> Assigning`
transition that never reaches `Waiting`, and by pressing Reset. One level rule covers all of them;
five handlers cover four of them, and the fifth is the bug.

**Invented, with the reason rule 2 demands:** nothing about the *mechanism* -- but the **two-way
segmented control with no travelling thumb** is this project's own, and the reason is in
`design-system.md` section 1.4 (*"A HUD that moves is a HUD you cannot read while aiming"*). Every
off-the-shelf toggle slides. Here the selected half simply **is** the lit one, with a 2 px underline
at full opacity as the only chrome it has.

---

## 4. The numeric targets

| # | Target | How it is checked |
|---|---|---|
| 1 | a `BEATER` wish puts the owner on the beater side at **every roster size 2..16**, and the two sides still differ by at most one | `match_roster.spec`, pure |
| 2 | a `HUNTER` wish, or none, answers the pre-task assignment **by identity** -- the same table, value for value, at every size 2..16 | `match_roster.spec`, pure |
| 3 | the wish is **not** honoured for a roster of **1** (section 1.1): he is a hunter, and nothing is consumed | `match_roster.spec`, pure |
| 4 | after a departure the stored wish reads `HUNTER` again, **within one scan** of the owner's step | server spec, driven by parameter |
| 5 | a non-owner's wish is **absent**, so neither control is built | server spec + client spec |
| 6 | a forged `BEATER` from a non-owner changes nothing and is **counted** apart from a well-formed ask | server spec |
| 7 | the pad dialog is **119 px taller** with the block and **exactly today's height** without it | client spec, pure (`PadPanel.heightFor`) |
| 8 | the shop's owned `ALWAYS HUNTER` row is **124 px** and nothing above it moves | client spec, off the BUILT instances |
| 9 | the feature costs **no new per-frame wire**: one attribute written on a change, read by the Hud's one existing evaluation | counted in the review request |

---

## 5. What this note does not decide

The **owner** of the wish, the attribute's name, which inbound door carries the request, and the
exact signature of every symbol. Those are the Architect's (`reviews/task-229/BRIEF.md`, then
`docs/design/role-switch.md`), because the value is written by a player, read by `Match`, and drawn
by two panels owned by two different modules -- three owners away from each other, which is the one
shape CLAUDE.md rule 3 exists for.
