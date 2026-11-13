PASS (item 9, 10 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: nothing about the flag-ON world has
been seen in Karen's place. The request says so itself ("Karen has not seen any of it"), there is no
screenshot or frame description anywhere in it, and the flag is born OFF (`BOAR_ATTACH_BUDGET`,
`default = false`, and `ATTACH_BUDGET_MS = if Flags.isOn(...) then 8 else 0` resolves to 0 = no budget),
so her build is byte-for-byte today's. What exists for items 9 and 10 is probe-read NUMBERS out of her
Forest Test (`StepMsMax` / `StepOwners`, `349-table.py`) -- not a picture of an animal putting its coat
on a few frames late. Whether that delay is visible at all is hers.

Delete-the-producer (duty (a)), done by reading, case by case:
- `boar_attach_budget.spec` ":199 `expect(drawn).to.equal(1)`" and ":215
  `expect(table.concat(seen, ",")).to.equal("1,2,3,4")`" -- with `if budget <= 0 or prof.attach < budget`
  made always-true, every animal is dressed in step 1, so they read 4 and "4,4,4,4". That is exactly the
  pasted failure in claim 7, line for line. Deleting the FEEDER (`prof.attach += (os.clock() - attachAt)
  * 1000`) reddens them too: `prof.attach` stays 0, always under the budget. `dressed()` counts
  `part:FindFirstChild(MODEL.NAME)` on the live trunk, not a counter, so the two sides are not one
  identity.
- the flag-row case and "leaves ATTACH_BUDGET_MS at 0" both go nil-vs-value if the row or the CONFIG
  line is deleted.
- the two control cases DO survive deletion -- "with no budget, one step dresses every animal" and
  "changes nothing else: the same four animals, alive" (`count`/`liveCount` are 4 with or without the
  budget). Not a finding: they are regression guards whose whole content is "the OFF world is today's",
  and the two cases that carry the claim redden. But claim 8 says "the two cases under 'with a budget'"
  and offers the `count`/`liveCount` one as part of the proof; there are three cases there and that one
  proves nothing about the budget.

## Notes (non-blocking)
- `docs/research/2026-11-12-frame-budget-for-attaching-models.md` -- "The design's budget
  (`docs/design/grid-map.md` 9.2, quoted by task 327h) is **20 ms peak**" misquotes it. §9.2 reads
  "**boar runtime, server step** | **<= 4.0 ms/frame average, <= 8.0 ms peak**". The 20/40 ms figures are
  the DISPATCH's. Same slip in the targets table ("the design's own figure is 20 ms"). Worth fixing
  because it hides the real gap: 26.1 ms ON is inside the dispatch's 40 and still 3x the design's 8.0.
- `reviews/task-355/MEASUREMENTS.md`, BEFORE | AFTER -- "`attach` total over the drive | 864 ms | 864 ms"
  cannot be right in both columns: the two drives released 91 and 104 animals and their `attach` WORST
  differs (92.1 vs 70.4 ms), so the totals must differ. Looks like the BEFORE cell transcribed into the
  OFF cell. It changes no conclusion (the row is already marked not comparable across arms), but one of
  the two numbers is wrong.
- `reviews/task-355/REQUEST.md` claim at "What changed" -- "`MEASUREMENTS.md` is the table, written
  before any fix code" is not what the repo shows: the file first appears at `de597a5f` (01:49), after
  the fix `c47a41b0` (00:51), and it contains the BEFORE | AFTER table, which cannot predate the fix.
  What the repo DOES support is the substance: the three instrument commits (`83837a30` 00:01,
  `f96d38a8` 00:21, `402aec2e` 00:31) and the BEFORE run taken at `402aec2e` all precede the fix. Say
  that instead.
- `tests/server/boar_attach_budget.spec.luau`, the describe comment -- "delete `mayAttach` from the
  step's `if`" names a symbol that does not exist; the code is `local budget =
  config.MODEL.ATTACH_BUDGET_MS` / `if budget <= 0 or prof.attach < budget then`. The claim-7 wording
  quotes the real line.
- `reviews/task-355/MEASUREMENTS.md`, spike 2 -- the `lobby` bucket is
  `bootProf.lobby = (os.clock() - lobbyAt) * 1000` around BOTH `Lobby.step(now, players)` AND
  `reportLobby()`, so 378.4 ms is not isolated to the symbol the row names. `cells` likewise includes
  its own print formatting. Only matters when somebody goes to fix spike 2.
- `reviews/task-355/MEASUREMENTS.md` -- "animals left with no model | 0 | 0 | 0" is the one row that
  names no instrument. Nothing in `src/` publishes an undressed count (`_stepCost` writes `StepCount`,
  `StepMsAvg`, `StepMsMax`, `StepWorst`, `SpawnCost`, `StepOwners`, `Alive`, `Live`, `LiveMax`,
  `DespawnByReason`), so the figure cannot be re-derived from the repo -- name the probe that counted it.
- `tests/server/boar_model.spec.luau`, `boar_shot.spec.luau`, `deer.spec.luau` -- their worlds do
  `local copy = table.clone(MODEL); copy.ENABLED = ...` and never pin `ATTACH_BUDGET_MS`, so in a Studio
  place with `DHFlag_BOAR_ATTACH_BUDGET` on they run with an 8 ms budget they were not written for. Low
  risk today (they dress one animal and `step(runtime, 1/60, 3)`), but pin `copy.ATTACH_BUDGET_MS = 0`
  at the flag flip, when the harness will first be run with the row lit.
- `src/server/Boar/init.luau`, the attach block -- `local budget = config.MODEL.ATTACH_BUDGET_MS` reads
  the WORLD's MODEL two lines under a comment that insists "`entry.config` AND NOT `config` ... a deer's
  `MODEL` is its own table". It is the right choice (a frame budget belongs to the runtime, not to a
  species) and harmless either way (the deer's MODEL is a clone of this one and `MODEL_OVERRIDES` does
  not touch the key), but nothing says so.
- `src/shared/Flags/init.luau`, `LICENCE_POPUP` -- rule 4: the expiry move is a second task riding along
  (precedent: 354's `report_panel.spec` repair). It is disclosed and it unblocked the gate, so fine; two
  things to queue: the reason sits in a comment, where `flags.spec`'s own tripwire comment says the fix
  is "move the date with a reason in `why`", and the thing actually missing is Karen's word on the
  default (TASKS.md 82b).
- the instrument's own cost is never measured. Every reading in the file -- including the "BEFORE" run at
  `402aec2e` -- carries it, so there is no step time without the ~4 extra `os.clock()` calls per animal
  per frame plus the nine-key rollup, and this is a task about the server's worst frame. It is cheap
  (tens of ns a call) and permanent and unflagged; state its overhead rather than leaving it unstated.
- small, and only because somebody will read these files next: `Boar.PROF_ORDER` was inserted between the
  "HOW OFTEN THE STEP COST IS PUBLISHED ... 120 steps" comment and the `Boar.STEP_PUBLISH_EVERY = 120`
  it documents, and `local sections` / `ForestTest.stepSections` between the "`inPlace` IS A PARAMETER"
  comment and `ForestTest.step`. Also `stepSections` returns the module table by reference, where the
  house's other diagnostics clone (`pathProblems` -> `table.clone`); one read-only reader today.

---
REVIEWER verdict on commit `dbb3c3eb5db4ebf6d34ed75aea69f3e9841fb777` (round 1) · 2026-11-13 01:09 UTC · session cost $4.07, 44 turns · written by tools/agents.py
