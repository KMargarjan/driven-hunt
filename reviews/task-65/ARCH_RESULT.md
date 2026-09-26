1. `GAME_DESIGN.md` System owners table — no row for the asset manifest, for the id→Instance seam, or for the boar's visible model, while `src/serverstorage/MapGen/Props.luau` `Props.template` is already the repo's only `InsertService:LoadAsset` caller. Blocks: the boar model swap.
2. `src/serverstorage/MapGen/Assets.luau` `Assets.KEY` has one tree key for four species, and `tests/server/map_contract.spec.luau` asserts species only against `MapGen.Scatter.speciesAt`, never against the built wood. Blocks: M2.8c and M2.3/M2.7d.

---
ARCHITECT verdict on commit `755161e70bb6a48f6da985fc5b15ca8b27f10dbd` (audit -> docs\architecture\audit-005.md) · 2026-09-26 18:06 UTC · session cost $6.93, 57 turns · written by tools/agents.py
