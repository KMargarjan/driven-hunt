# Task 124 BRIEF — the hit record, the hit indicator, the kill log and the drive report

Written by the Builder, carrying the Director (2026-10-05). This overrides anything older in
`docs/`, `TASKS.md` and any earlier design. Read it before designing `drive-report`.

Research note: `docs/research/2026-10-05-drive-report.md`.

## What Karen asked for, verbatim

> "we need to show when is killed logg or something similar / we need to indicate a hit / and we need
> to show on the end what has been killed where was the hit / so after drive we can see how much I
> killed compairing others and I can click on details or similar and see boars where was the hit /
> something simple but cool"

## Decisions already taken (do not re-open)

1. **ONE SERVER-SIDE OWNER OF THE RECORD.** A new module `HitLog` (server) is the only writer of
   "who hit what, where, and did it die". It is fed by the two signals that already exist and adds
   no new source of truth:
   * `Weapon.HitReported` — fires once per (shot, target), already grouped, carrying `shooter`,
     `target`, `zone`, `zones`, `ammo`, `pellets`, `at`, `nearest`, `normal`.
   * `Boar.Runtime.Downed` — fires per death, carrying `killedByUserId`, `killingZone` and the kind.
2. **THE IMPACT IS STORED IN THE ANIMAL'S OWN FRAME**, `CFrame:PointToObjectSpace(impact)`, taken at
   the moment of the hit. A world position is meaningless once the carcass has despawned; an
   object-space one still means "high on the shoulder" when the report is drawn.
3. **NO SECOND SCORE.** `Match` already owns points, penalties and the roster. The report shows what
   `Match` reports plus the placement `HitLog` adds. In a world with no `Match` (the Forest Test),
   the report shows kills from `HitLog` alone and no points.
4. **THE CLIENT ONLY DRAWS.** No client may write a hit, a kill or a score. One replication event
   per kill (for the log line) and one request/response for the report body.
5. **THE SILHOUETTE IS DIVIDED INTO THE FIVE ZONES THE DAMAGE MODEL HAS**, and no more:
   `head`, `chest`, `body`, `legs`, `rear` (`Boar.CONFIG.WOUND.DAMAGE`). Drawing a liver this game
   never simulates is the mistake Way of the Hunter's own players describe.
6. **THE HIT INDICATOR IS THE SHOOTER'S ONLY.** `Weapon.markHit` and the `HitMarker` remote already
   exist and already go only to the shooter; this task gives them a KILL variant and a soft tick
   sound, and nothing else learns about it.
7. **THE FOREST TEST GETS A DRIVE LENGTH IN DATA** (5 minutes) so the report has an end to show at,
   **and Tab opens it at any time** in both worlds.
8. **IT MUST WORK WITH NO `Match`.** The Forest Test has no drive, no roster and no teams. The report
   and the log must not require one.

## What the design must contain

* **The owner table.** Which module owns the hit record, the report's data, the panel's drawing, and
  the Tab key — and how each is reached from a world that has no `Match`.
* **The record's shape**, field by field, including what is kept for an animal that was hit and never
  died (Karen's "wounded-lost") and when a record is forgotten (per drive? for the session?).
* **The two client paths**: the per-hit marker (shooter only, hit vs kill) and the per-kill feed line
  (everyone), and which remote carries each. Say whether the kill line reuses `Match`'s existing feed
  remote or needs its own in a world with no `Match`.
* **The report's data path**: how a client asks for the report and what comes back, with the size of
  the payload bounded (a drive with 60 animals and 8 hunters must not arrive as one unbounded table).
* **The panel's structure**: the list view (one row per hunter, counts by kind, sorted) and the detail
  view (one animal per row, silhouette with a dot per hit, distance, result), and how it closes.
* **What happens when a drive ends while the panel is open**, and when a player joins mid-drive.
* **Where the Forest Test's drive length lives** and what "the next drive starts" means there.

## Constraints

* `Hud` is the one owner of everything drawn in the player's screen space (`docs/design/` and the
  owners table). The report is Hud-owned or it is a new owner with a written boundary — the design
  decides, and says why.
* No new score, no client authority, no `.rbxm`, no scripts outside Rojo-owned paths.
* The Forest Test world is selected by `Map.EXPECTED_WORLD == "forest-test"`; `MatchBoot` returns
  immediately there and `ForestTestBoot` is its composition root.
* Blast radius: the weapon, the boar, the hud and the Forest Test. The DEV gate cannot run (DEV is
  not open), so the design should say what a later gate would have to cover.
