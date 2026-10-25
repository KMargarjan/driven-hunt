PASS

The shotgun delta is stated INSIDE this design (section 14: `shotgun.md` §§3.1, 5.3, 5.5, 5.7, 11,
13.1, 13.2, 15), as `reviews/task-266/BRIEF.md` section "If the ballistics design can state the
shotgun delta inside itself" allows. **Do not make the second run** (`architect.ps1 design shotgun
--task 266`): one design owns the flight and names its deltas, and a second file could disagree with
it about the claim payload.

Three things in the design are the Director's or Karen's and are called out in section 16. **None of
them blocks building**, which is why this is a PASS and not a numbered list:
- `Flags.MAX_FLAGS` must go 17 -> 18 for the `HIT_CLAIM` row (section 3.4). The Builder may take it
  under a stated assumption, as tasks 238, 245b and 251 each did verbatim; the alternative is
  retiring TASKS.md 82b first, which is the Director's call.
- **This task needs `test2`** (section 13.2): `src/server/MatchBoot.server.luau` is in
  `TWO_PLAYER_PATHS` and the history provider can only be wired in a composition root. That is one
  human click per PR, not a design hole.
- Section 15 lists what I could not verify, the shared clock first.

---
ARCHITECT verdict on commit `48750fad184c76284e2e0fbdbf15e964dd44bcac` (design ballistics -> docs\design\ballistics.md) · 2026-10-25 18:28 UTC · session cost $8.33, 54 turns · written by tools/agents.py
