# Task 88 — research and design for first person, the viewmodel and the bead

Task: 88
Round: 1
Base: `main` (`d53589c`)
Code commit: `9fbcd697c4e0a8052e7f07f0c4b70e637ba2d104`

```
[harness] PASS: 32/32 checks @ 9fbcd697c4e0a8052e7f07f0c4b70e637ba2d104 (clean tree)
```

**DOCS-ONLY**: no `src/`, no `tests/`, no `tools/` — `git diff --name-only main..HEAD` is four docs
files plus `TASKS.md`. `test2` is **N/A** for the same reason (CLAUDE.md, git workflow step 4). The
one-player line above is my own `gate.sh --one-player-only` run at this head; it is evidence that the
tree is clean and the place still builds, not evidence about a change to the game, because there is
none.

**What changed.** `docs/research/2026-09-27-first-person-viewmodel.md` (new),
`docs/research/INDEX.md` (one row), `reviews/task-88/BRIEF.md` (new),
`docs/design/camera.md` (rewritten by the Architect through `tools/architect.ps1 design camera
--task 88`), `reviews/task-88/ARCH_RESULT.md` (written by the script), `TASKS.md` rows 88 and 88a.

## Claims

1. **RULE 1 IS SATISFIED BEFORE ANY CODE, AND NO CODE WAS WRITTEN.** The note is written, indexed and
   committed **before** the design run, and nothing in `src/`, `tests/` or `tools/` is touched by this
   branch. Verify: the note's file, its row at the top of `docs/research/INDEX.md`, and
   `git diff --name-only main..HEAD`.

2. **SIX SOURCES, EACH WITH ITS LICENCE AND MAINTENANCE STATE CHECKED, NOT ASSUMED.** §3 of the note:
   Roblox's creator-docs (**CC BY 4.0**, last push 2026-09-26, 841 stars — read off the GitHub API,
   not guessed), two DevForum tutorials (**no licence**, 2021 and 2022), Quenty's `NevermoreEngine`
   (**MIT**, last push 2026-09-24, 614 stars), the four public FPS kits, and Karen's own clips.
   Verify: §3 and its table; every licence and date in it came from `api.github.com/repos/<repo>`.

3. **THE SURVEY'S ANSWER IS "NOTHING IS ADOPTABLE", AND THAT IS THE FINDING, NOT A GAP** (rule 2).
   `minh-p/FPS_Viewmodel` (2020), `MonzterDev/First-Person-Camera-Roblox` (2022) and
   `sshar1/FPS-Framework` (2022) carry **no licence at all** — which is all rights reserved, not
   "free" — and `Kishero/CommunityFPS` is MIT but was last pushed in **2016**, before R15 and Luau. So
   the note borrows the **pattern** (the AimPart/sight idea, the sway input, the spring maths) and
   says where each piece comes from. Verify: §3 E and §4 of the note.

4. **THE REFERENCE WAS MEASURED, AND THE METHOD AND ITS LIMITS ARE WRITTEN DOWN** (rule 8). I cannot
   watch a video; frames were rendered out of Karen's two clips with the headless Blender
   `tools/asset_prep.py` already drives, into the scratchpad **outside the repo**, and looked at one
   by one (rule 5). The note says the clips are WhatsApp re-encodes, **cropped to 16:9**, so vertical
   positions are not trustworthy and timings are good only to the sampled frame at 24 fps. Verify:
   §2 and its "Method, said plainly" paragraph.

5. **THE TWO NUMBERS TAKEN FROM IT ARE BOUNDED, NOT ROUNDED.** Mount ≈**0.29 s** (gun invisible at
   frame 1946, carried at 1955, mid-rotation at 1957, aligned down the rib at 1961), stated with its
   bracket of 0.17–0.38 s; ADS zoom ≈**1.3×** from two trunks 330 px → 430 px apart, giving ≈57°, and
   recorded as the band **55–58°** because the camera also moves onto the stock. Verify: §2.2.

6. **KAREN'S ACCEPTED FEEL NUMBERS ARE KEPT, NOT OVERWRITTEN BY SOMEBODY ELSE'S GAME.**
   `FOV_AIM_DEG = 50` and `AIM_BLEND_SECONDS = 0.20` (her 2026-09-25 sign-off) stay, with the
   reference's 55–58° and ≈0.29 s recorded beside them as dials she can turn. Verify: the note §6
   table and `docs/design/camera.md` §8 and §12's Karen list, items 1 and 2.

7. **WHAT THE REFERENCE DOES NOT SHOW IS SAID AS PLAINLY AS WHAT IT DOES.** In ≈14 frames across both
   clips and both stills there are **no hands or arms** — the gun appears to float — so "hands on the
   gun" is recorded as **Karen's requirement to design, not a thing to copy**, with two routes and a
   recommendation. And the reference's **rifle scope and binoculars do draw a reticle**, so "no
   crosshair" is the shotgun's rule in that game; ours is Karen's, none ever. Verify: the note §2.1
   table (rows "Hands / arms" and "Reticle elsewhere") and §5.3.

8. **THE BRIEF CARRIES THE DECISIONS AND THE DESIGN ANSWERS THEM.** `reviews/task-88/BRIEF.md` lists
   the nine decisions already taken (first person replaces the 2026-09-25 shoulder camera; no
   crosshair ever; low-left carry; the bead; hands; minimal HUD; `FIRST_PERSON` born OFF; Karen's
   numbers kept; docs-only) and ten things the design must contain.
   `reviews/task-88/ARCH_RESULT.md` line 1 is **PASS** for `0af80b8`, and `docs/design/camera.md` has
   the owners (§3), the flag (§6.6), the `Sight` seam (§6.5), the numeric table (§8), the spec plan
   (§9), the `GAME_DESIGN.md` rows ready to paste (§11), open decisions that block nothing (§12), what
   it could not verify (§13) and the five steps with their screenshots (§14).

9. **THE ONE NEW TESTABLE NUMBER IS THE BEAD, AND IT IS GEOMETRIC RATHER THAN TUNED.** ADS aligns a
   `Sight` attachment — created by `Weapon.Hardware` beside the `Muzzle` attachment it already creates
   — with the camera, so the bead lands on the view axis **because of where the bead is**; and the
   acceptance test is that the bead projects within **8 px of screen centre at 1920×1080**
   (0.37° at the 50° ADS FOV, ≈0.9 studs at 40 m, against a boar 5.5 studs long). The per-variant
   values are named: the parts gun reuses the same pure expression that places its `Bead` piece; the
   upload is **exactly one MeshPart** (`Assets`), so its value is a measured row field, `nil` until S2
   measures it, with a loud fallback. Verify: note §4.3 and §6; design §6.5 and §9.2.

10. **WHAT WAS DELIBERATELY NOT DONE IS RECORDED RATHER THAN LEFT TO BE FOUND** (`TASKS.md` 88a):
    `docs/design/shotgun.md` is **untouched** — `tools/agents.py` writes one design file per `design`
    call and this call's target was `camera.md`, so the shotgun-side delta is named inside the camera
    design and queued for reconciliation the way 74a(g) and 75a(i) are; `GAME_DESIGN.md`'s camera
    owner row still describes the **third-person** system, because that is what is in the game and
    nothing shipped here; and the reference clips stay outside the repo — looked at, measured, never
    committed and never copied.
