# Task 161 — design brief for the ARCHITECT: bots fill the drive

Written by the Builder, carrying the Director (2026-10-11/12). This brief is the input to
`tools/architect.sh design bots --task 161` and **overrides anything older** in `docs/`, `TASKS.md`
and any existing design where they disagree (`docs/ARCHITECT_PROMPT.md`).

Read first: **`docs/research/2026-10-12-bots.md`** — this task's note. §2 names the four external
sources with licences and maintenance status, quotes the one that IS the design (ioquake3's
`G_CheckMinimumPlayers`, GPL-2.0, fetched and quoted verbatim) and says what each source does well
and badly. §3 is the pattern, **already chosen and not open**. §5 is the numbers. §6 is the owner
table this design has to either adopt or overrule with a reason.

The design is a **new system document**, `docs/design/bots.md`. It is also a **delta** to
`docs/design/drive.md` (§3.5 the one composition root, §5.3 what `Assigning` does, §9.2 the owner's
interface, §7.1 the score) and to `docs/design/forest-drive.md` (§4.3 placement, §6 the threats and
the safety arc, and wherever it says this world's beaters are phantoms).

---

## 1. The decisions already taken — do not re-open them

1. **KAREN, 2026-10-11, her v1 rule, verbatim:** *"Let's make 4 hunters 4 beaters"*. And she
   answered **"start now"** to the Director's proposal containing: *"Real visible bots: beaters
   walking in orange vests, hunters standing on stands... a solo player still feels part of a full
   drive; at launch servers will often have only 1-3 players, and bots fill the 4+4 so the game
   still works."* **Karen tests SOLO, in the Forest Test.** She judges the look in the morning.
2. **BOTS ARE VISIBLE R15 RIGS, not phantoms.** The whole point is that she can SEE a full drive.
   The Forest Test's existing phantom beaters are *"invisible phantom positions with nobody standing
   on them"* and they are what this task replaces.
3. **A BOT IS NEVER A PLAYER.** No score row, no DataStore, no `Player` object, no team membership,
   no `participants` entry. The mechanism is already in the code and it is **structural, not a
   filter**: a bot has no userId, and `Match.playerDrivers`, `Match.pushCreditable` and
   `Phase.participantIds` each already refuse a non-numeric or absent one. Do not design a new
   "is this a bot" predicate for the score.
4. **ONE PUSH SOURCE.** A bot beater's walk spooks boars through **the existing door** — the same
   threat list and the same flush/`PACE` rules a real beater's walk goes through (tasks 153/154),
   `kind = "driver"` and **no `phantom` mark**, because a body is standing there. The Forest Test's
   wave-mode phantoms are **suppressed while bots are on**. The LINE mode never had any
   (TASKS.md 153b), so nothing there changes.
5. **THE OUTFIT HAS ONE OWNER AND IT DOES NOT MOVE.** `Match.Body` dresses bots exactly as it
   dresses players: `Body.dress(character, team, config)` already takes a **Model**, not a Player.
   No second dressing path, no copy of the outfit rows.
6. **BOT HUNTERS DO NOT SHOOT** in this task. A shooting bot is its own task (note §4, queued as
   TASKS.md 161a).
7. **THE PATTERN IS CHOSEN** (note §3) and the design states it rather than choosing it:
   * **FILL** = ioquake3's `G_CheckMinimumPlayers`, re-pointed: per-team target, `humans + bots`
     counted against it, add and remove symmetric, target 0 is the switch, never during the
     intermission — evaluated at the drive's own **phase boundary**, not on a timer.
   * **WALK** = `Humanoid:MoveTo` re-issued every 2 s inside the engine's documented 8-second
     timeout, down a **per-bot lane** (its own X on the start line, its own point on the road), with
     this repo's own whisker side-step for trunks. **`PathfindingService` is REJECTED** — three
     reasons in note §3, the first being that eight shortest paths are eight detours and the line is
     the feature.
   * **STAND** = anchored root, `EvaluateStateMachine = false`, every `HumanoidStateType` disabled,
     nothing animated from the server, `DisplayDistanceType = None`. This is Roblox's own *"static
     NPCs that do not move generally have no need for the Humanoid class"* taken as far as wearing
     the outfit allows (`Humanoid:AddAccessory` needs a Humanoid).
8. **THE RIG SOURCE IS AN INJECTED SEAM.** Default
   `Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)`; settable, the shape
   `Boar.setModelSource` and `Body.setAccessorySource` already have — so every spec builds bots from
   a fake rig with no avatar service, no web call and no Play.
9. **NO POOL.** Rigs are destroyed and rebuilt per drive (note §1 item 6 and §2.2's rejected last
   line). Once per ten-minute drive is not the *"frequent respawning"* the vendor warns about, and a
   pool would be live state carried across the one boundary that exists to reset it.
10. **A FEATURE FLAG, born OFF, per CLAUDE.md "Feature flags".** Bots change how the drive FEELS, so
    the row is born `default = false` with `owner`, `born`, `expires` inside 21 days and a one-line
    `why`, read **once at `Match.CONFIG`'s boundary** and passed inward — the only permitted shape.
    Off must mean today's behaviour bit for bit, and the flagged path must be reachable **by
    parameter** as well as by flag.

## 2. The two decisions this design MUST take, because the Builder took them provisionally and they
   are owner questions

1. **WHERE THE FILL IS CALLED FROM.** The note's answer is **`world.bots` injected into
   `Match.start`** — a small interface the drive calls at its own boundaries — because *no owner
   requires another owner* (the rule both `MatchBoot` and `ForestTestBoot` are written to), and
   because a world that injects nothing then gets today's drive with no new code path, which is the
   switch's second half. **The alternative the Architect must rule on:** driving bots entirely from
   the composition root off `Match.PhaseChanged` (where `ForestTestBoot` already hooks the picks and
   the report), with **no change to `Match` at all**. That is cheaper and keeps a `TWO_PLAYER_PATHS`
   file untouched — but it cannot answer decision 2 below, because the drive's end has to ask
   somebody how many beaters there are. Say which, and say what the interface is, symbol by symbol.
2. **WHETHER BOT BEATERS END THE DRIVE.** The Builder's answer is **yes**, and the reasoning is
   Karen's own open complaint: `TASKS.md` **159a(f)** — *"a solo beater ends the drive the moment
   she crosses the road"* — is on the board waiting for her word. Her rule is *"Timer or when all
   beaters cross line of hunters"*; with a line of bots walking beside her, "all beaters" is the
   LINE, so she crossing first ends nothing and the drive ends when the last of the line is past.
   `Match.beaterCrossing` is the measurement and `Phase.beatersThrough` stays the rule, untouched —
   it only compares two numbers. **If the Architect disagrees, it must say what else ends a drive in
   a solo game**, because the drive needs *some* end.

## 3. What the design must contain

1. **The owner table**, adopting or overruling note §6, naming the **one writer** of: the bot rigs'
   Instances, their lifetime, their movement, their horn rhythm, what they wear, where they stand at
   the start and in the results ring, how many there are, and the threat entry a boar perceives.
   Say explicitly which of these stay with `Match.Body`, `Match`, `Scene`, `Weapon.Horn`,
   `ForestTest` and the boar runtime, and which are new.
2. **The module layout**: which files, which are pure, which touch Instances. The house shape is a
   folder module owning state over pure decision modules driven by an injected world (`Match`,
   `Boar`, `Weapon` are three instances of it). Name the pure pieces — at minimum the fill
   arithmetic and the lane geometry — because those are what the specs drive with no world.
3. **The interface between the drive and the bots**, symbol by symbol, including what happens at
   each of the four phase boundaries (`Waiting`, `Assigning`, `Running`, `Scoring`) and at a drive
   that ends early.
4. **How a bot beater's horn blast reaches the boars.** The constraint: it must be the **existing**
   `Weapon.Horn` door — the real reach (`Horn.spookStuds`), the real cooldown
   (`Horn.CONFIG.COOLDOWN`) and the one signal both composition roots already connect
   (`Weapon.Horn.Blown`) — and `Horn.blow(player)` takes a **Player** and a held **Tool**, which a
   bot has neither of. Say how: a new non-player entry point on the horn's own owner, a bot that
   really carries a built `Horn.build()` Tool, or something else. Say what `blowerUserId` is for a
   bot and check that `Match.creditPush` already refuses it.
5. **What the phantoms become** (decision 4): where the suppression is decided, and by whom.
6. **The flag**: its name, what reading it once at the boundary looks like, and which parameter
   carries it inward so both states are testable while the flag sits at one of them.
7. **What is forbidden.** At minimum: no second score, no second placement writer, no second push
   source, no `.rbxm`, no script-like instance made in Studio, no bot in `state.participants`, no
   bot with a userId.
8. **The blast radius.** Whether `src/server/Bots/` belongs in `TWO_PLAYER_PATHS`
   (`tools/agents.py`) and in `BLAST_RADIUS`/`SCOPE_SPECS` (`tools/studio_mcp.py`), with the
   reason. The Builder's provisional answer: **`BLAST_RADIUS` yes** (a new `bots` scope with its own
   specs), **`TWO_PLAYER_PATHS` no** — a bot is not a player, and a second human changes nothing
   about what a bot rig does, while the fill count per real-player count is a **pure** function a
   spec drives at every count from 0 to 8. This task touches `src/server/Match/` regardless, so it
   needs `test2` anyway.

## 4. What is NOT this design

* The role rotation and its anti-cheat memory (a separate queued task).
* Money, saving, DataStore (step 3b).
* Dogs, bot names, bot chat, bot animations beyond the engine's own walk.
* A bot that shoots, and whether a shot through a bot beater should tie a hunter to a tree
  (TASKS.md 161a — a Karen decision, named in note §4 so it is declared rather than discovered).

## 5. The checks this task will have to pass, so the design does not make them impossible

* Specs for the **logic**, with no frames and no long traces (Karen's rule): fill counts per
  real-player count, a bot never in a score row, a bot beater's spook going through the real door,
  cleanup each drive, and **switch off = today's behaviour**.
* The full one-player gate twice, plus `test2` (this task touches `TWO_PLAYER_PATHS`).
* **One screenshot** of the bots on the line in the Forest Test, looked at once.
