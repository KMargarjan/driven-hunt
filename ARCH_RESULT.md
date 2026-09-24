1. `tools/studio_mcp.py:398` + `:504` — typed property values ("cannot compare") make any positioned `.model.json` part fail the harness, so the grey-box core loop (boar, shotgun Tool, drive line) has no legal way to put geometry on disk.
2. `tools/studio_mcp.py:174` + `:519` — the unmanaged-instance scan covers only `LuaSourceContainer`, so a Studio-created non-script instance in a Rojo-owned container passes the harness and is deleted at the next Connect.
3. `tools/agents.py:1` — the four-agent script, now the gate on everything reaching Karen, has no research note and no external sources (rules 1, 2, 9); `docs/research/INDEX.md:7` lists only the toolchain note.
4. `tools/agents.py:259` — audit mode tells the Architect to read earlier audits, but `docs/architecture/` is absent at this commit and `tools/agents.py:266` precomputes no prior audit or git log, so `TASKS.md:14`'s open items L2/L4/L6–L9 exist in no reachable file.
5. `ARCH_RESULT.md:1` — a Builder-written `NONE` in a file whose own line 4 says only `tools/architect.sh` writes it; no check ties either verdict file to the commit being merged, and `tools/agents.py:248` lets a dirty-tree audit write an unqualified verdict.

---
ARCHITECT verdict on commit `24fd22a78d69be95484b3e4b0368c5734fd9af3f` (audit -> docs\architecture\audit-002.md) · 2026-09-24 18:47 UTC · session cost $2.53, 50 turns · written by tools/agents.py
