# Task 53 — design brief for the ARCHITECT: the Meshy tool and the ASSET agent role

Written by the Director. Karen green-lit (2026-09-26) a fifth role, the ASSET agent, and a Meshy tool.
Karen is on a PAID Meshy plan (she owns the output). Her API key is in the Windows user environment
variable `MESHY_API_KEY` (the tool must read it from the process environment, and fall back to the
Windows user registry `HKCU\Environment` when the process started before the variable existed; never
print, log or commit it).

Facts checked against the official docs on 2026-09-26 (the research note must re-fetch and quote them):
base https://api.meshy.ai; text-to-3D `POST /openapi/v2/text-to-3d` (preview, then refine);
image-to-3D `POST /openapi/v1/image-to-3d`; multi-image (1-4 images) `POST /openapi/v1/multi-image-to-3d`;
remesh `POST /openapi/v1/remesh` (topology triangle, target_polycount); polling `GET .../:id`; outputs
GLB/FBX/OBJ + separate PBR maps via signed URLs; auth `Authorization: Bearer msy_...`; API keys need a
paid plan; 20 req/s, concurrent task caps by plan; API output DELETED after 3 days; Meshy may train on
non-Enterprise output; rigging is humanoid-only (not for the boar); no seed (not reproducible);
art_style/negative_prompt/symmetry deprecated. Official MIT meshy-cli and meshy-mcp-server exist
(TypeScript) — evaluate borrowing vs a small Python client (rule 2).

The design must give:
- Owners: `tools/meshy.py` (built by the Builder), operated by the ASSET agent; what the ASSET agent may
  write (assets dir outside the repo; the asset manifest rows — reconcile with docs/design/asset-pipeline.md
  which already owns the manifest) and may never touch (Studio, src/, tests/, other tools).
- The flow: brief (text and/or reference images) -> preview -> Karen's OK (stop point, with a preview
  image she can look at) -> refine (2K, PBR) -> remesh (~18k triangles, under Roblox's 20k) -> download
  immediately -> local validation (triangle count, texture sizes) -> handoff to the Open Cloud upload
  tool from the asset-pipeline design. Credits logged per task.
- Licence basis recorded per asset: "own work, paid Meshy plan"; never published to Meshy community.
- Failure modes (429, task FAILED, expired URLs, 3-day deletion) and how they are loud.
- The ASSET agent's brief (its own prompt file, like docs/REVIEWER_PROMPT.md), and the CLAUDE.md role row.
- The smallest first task: one model (the boar) end to end up to Karen's preview OK.
No local absolute Windows paths.
