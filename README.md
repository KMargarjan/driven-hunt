# driven-hunt

[![CI](https://github.com/KMargarjan/driven-hunt/actions/workflows/ci.yml/badge.svg)](https://github.com/KMargarjan/driven-hunt/actions/workflows/ci.yml)

Roblox game, developed with Rojo. See `CLAUDE.md` for rules, the git workflow, the definition of done,
layout and the full run/test guide. Karen's playtest log: `PLAYTEST.md`.

## First-time setup (Windows)

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then in this folder run: `rokit install`
2. `wally install` (restores `DevPackages/`, which holds TestEZ)
3. `rojo plugin install`, then restart Studio. In Studio's Manage Plugins, keep the Creator Store
   "Rojo" plugin disabled.
4. `rojo serve`
5. In Studio, open **Driven Hunt DEV**, then **Plugins → Rojo → Connect**.
6. Press **Play**. The Output shows `sync ok`. Tests do not run in normal playtests.
7. To run the tests: stop Play, then `python tools/studio_mcp.py test`.
