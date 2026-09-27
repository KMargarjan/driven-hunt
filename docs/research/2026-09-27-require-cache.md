# Research: Studio's require cache, and why a new feature flag did not exist

Task 78. A bug fix in an existing tool rather than a new system, so this note is short — but the
Director asked for the Roblox documentation on `require` caching to be quoted, and the quoting turned
out to be the interesting part.

## What the system must do

`python tools/flags.py set <NAME> on` must switch a feature flag on for a playtest, for **any** flag
the repo declares — including one added in the task that is about to be played. On 2026-09-27 it did
not:

```
$ python tools/flags.py set ORANGE_OUTFITS on
[flags] REFUSED: no such flag ORANGE_OUTFITS. An override for a flag that does not exist is a typo
        the resolver would only log.
$ python tools/flags.py
[flags] BOAR_SOUNDERS  ...
[flags] TIE_UNTIL_DRIVE_END  ...          <- ORANGE_OUTFITS is not listed at all
```

…while `flags.py live` in a Play session listed `ORANGE_OUTFITS=false` perfectly. The flag existed,
was merged, was resolved by the running server, and was invisible to the two Edit-mode queries. It
blocked the Director switching it on for Karen's playtest, which is the one thing the whole
feature-flag design exists to make cheap (`docs/design/feature-flags.md`).

## Sources

1. **Roblox, `ModuleScript` class reference** — first-party, current.
   <https://create.roblox.com/docs/reference/engine/classes/ModuleScript>
   > *"`ModuleScripts` run once and only once per Luau environment and return the exact same value
   > for subsequent calls to `require()`."*
   > *"It's important to know that return values from `ModuleScripts` are independent with regards
   > to `Scripts` and `LocalScripts`, and other environments like the Command Bar."*

   **Good:** the second sentence is the whole diagnosis. The Edit-mode MCP context is one of those
   *other environments* and keeps a cache of its own, which is why a Play session and an Edit-mode
   query disagreed about the same file. **Bad:** it says nothing about what happens when the
   ModuleScript's `Source` is replaced under a cached module, which is exactly what Rojo does.
2. **Roblox, `require` global** — first-party, current.
   <https://create.roblox.com/docs/reference/engine/globals/LuaGlobals#require>
   > *"Returns the value that was returned by the given ModuleScript, running it if it has not been
   > run yet."*

   **Good:** "if it has not been run yet" is the rule, stated as a property of the *ModuleScript
   instance*. **Bad:** it is one sentence, and "run" is not defined against a source change.
3. **BOTH RENDERED PAGES GAVE A FETCHER NOTHING.** Asked twice on 2026-09-27, each returned the
   signature and navigation and no caching wording at all. The sentences above are quoted from the
   **generated source those pages are built from** — first-party and public:
   `Roblox/creator-docs`, `content/en-us/reference/engine/classes/ModuleScript.yaml` and
   `content/en-us/reference/engine/globals/LuaGlobals.yaml`. This repo has hit the same wall before
   (the Blender manual, `2026-09-26-asset-prep.md`; `en.help.roblox.com`, the asset-pipeline note),
   and the rule it set then applies here: **say the page did not answer, and measure instead.**
4. **This repository, `tools/mapgen.py`** — the fix already existed here, with its own measurement
   beside it, since 2026-09-26:
   > *"MEASURED 2026-09-26: Studio's require cache survives between execute_luau calls, and Rojo
   > replacing a ModuleScript's Source does NOT reload an already-required module — so a Config edit
   > was invisible to `build`… `require` on a parentless clone loads the CURRENT source, leaves
   > nothing in the DataModel… and costs nothing measurable."*

   **Good:** rule 2, borrow before building, and the borrow is from this project's own past self.
   **Bad:** nobody carried it across to the flag queries, and the comment on `QUERY_FLAG_TABLE`
   asserted the opposite — that the cache was *"CORRECT rather than a hazard"*. A wrong comment
   beside working code is how a defect survives a review.

## The measurement

Nothing above says what happens when the `Source` changes under a cached module. So it was built
from scratch, in memory, in the Edit-mode MCP context — the same context `flags set` runs in:

| step | result |
|---|---|
| `Instance.new("ModuleScript")`, `Source` returns `{A}`, `require` | `A` |
| rewrite `Source` to return `{A, B}` — the same instance, as Rojo does | — |
| `require` the **same instance** again | **`A`** |
| `require` a **`Clone()`** of it | **`A,B`** |

That is the bug and the fix in four lines, and it needs no pre-existing staleness to reproduce. It
is now a harness check (`QUERY_REQUIRE_CACHE`), and it asserts only the half the tool depends on —
that a clone reads the current source. Whether the same instance goes stale is **reported, not
asserted**: if Roblox ever changed that, an assertion would block this repo for a fix that helps it.

## The pattern adopted, and why

**Require a parentless `Clone()` of the module, destroy it, use the table.** `FRESH_FLAGS` in
`tools/studio_mcp.py`, shared by both Edit-mode queries that need `Flags.DEFAULTS`.

Rejected alternatives:

- **Parse `DEFAULTS` out of `Source`.** It works — `Source` is readable from this context, measured
  (18,253 bytes, and it contains `ORANGE_OUTFITS`) — but it means a second, weaker implementation of
  what the module already says, and the rows carry `default`, `owner`, `expires` and `why` across
  comment-heavy multi-line table entries. A parser is a new thing to be wrong.
- **`loadstring` the source.** That is arbitrary Luau, and these queries are deliberately constants
  with a JSON string and a boolean literal interpolated. The property is worth more than the
  convenience.
- **Parent the clone before requiring it.** Also works (measured), and it puts a ModuleScript into a
  Rojo-owned container for the length of a call — the one thing the harness's own "no script outside
  Rojo-managed paths" check exists to catch. A parentless clone needs no such exception.
- **Tell the Director to restart Studio.** It is what happened in practice, four times now, and it
  costs a Connect click and everything the session held.

## The audit the Director asked for

Every `require` inside a Luau query in `tools/`:

| where | verdict |
|---|---|
| `studio_mcp.py` `QUERY_FLAG_TABLE` | **was stale — fixed**, requires a clone |
| `studio_mcp.py` `QUERY_SET_FLAG` | **was stale — fixed**, requires a clone |
| `studio_mcp.py` `QUERY_FLAG_OVERRIDES`, `QUERY_CLEAR_FLAGS` | no require: they read `ServerStorage` attributes and match the literal `"DHFlag_"`. Safe, and noted below |
| `studio_mcp.py` `QUERY_FLAG_LIVE` | no require: reads attributes off `ReplicatedStorage.Flags.State` in the running process |
| `studio_mcp.py` `QUERY_STAGE` and the camera path | no require **on purpose** — it invokes a BindableFunction, because a required copy would be a *different* camera module from the one the player is looking through (its own comment says so, Task 30) |
| `mapgen.py` `CALL` | already a clone, since 2026-09-26 |
| `mapgen.py` `STALE` | requires both deliberately, to report the difference |

**One thing left alone, and said rather than fixed:** `QUERY_FLAG_OVERRIDES` and `QUERY_CLEAR_FLAGS`
hardcode `"DHFlag_"` and the number 7 where the module has `Flags.OVERRIDE_PREFIX`. That is a second
copy of a fact, which this project dislikes — but it is a *constant*, not a cache, so it cannot go
stale the way this bug did, and making those two queries require a module they do not otherwise need
would trade a real property (they work even if `Flags` fails to load) for a tidiness. Queued as
78a(b) for the Director rather than decided here.

## What this note does not settle

- **Whether anything else in a long Studio session is holding a stale module.** `mapgen.py stale`
  answers that for `ReplicatedStorage.Map` and prints a note; nothing asks it about the others, and
  the honest answer is that reopening the place is still the only thing that clears them all.
- **Why the rendered documentation pages return nothing to a fetcher.** Three pages, two attempts
  each. The generated YAML is the workaround, not an explanation.
