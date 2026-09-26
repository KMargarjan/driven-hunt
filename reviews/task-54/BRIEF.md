# Task 54 — ARCHITECT: revise `docs/design/map-generator.md` and `docs/design/drive.md` for Karen's references

Written by the Director. Karen supplied reference images (outside the repo, described here) and decided
on 2026-09-26:
- The SHOOTER LINE runs ALONG A FOREST ROAD (a ride/track through the woods), not along a field edge.
  Boars cross the road from the driven side to the other side; some come out of the forest between two
  shooters. Shooters stand on the road (posts along it). References show mixed deciduous/coniferous
  forest, autumn leaf litter, a gravel/earth forest road, shooters ~40-80 m apart.
- Season: AUTUMN (orange/brown/yellow deciduous leaves, green spruce), a few common EU species only:
  oak, birch, black alder, spruce.
- Boars come as a MIX of singles and groups (2-5, a sounder), not only singles.
- Outfits: shooters wear an orange hat, drivers an orange vest (hunting safety colours; the drive's
  safety rule can use them to read who is where).
Deliver:
1. The map changes: where the drive corridor, the forest road with the shooter posts, the woods the
   drivers push through, and fields (if any remain) go; marker changes (posts on the road; DriveLine =
   the road); autumn palette/material choices for terrain and proxies; what M2.3/M2.4 now place.
2. The drive changes for groups: how a release spawns a group (sizes, mix, spacing), how the Boar
   runtime/brain handles a group (follow a leader? flee together? scatter on a shot?) — borrow a known
   pattern (boids/flocking or leader-follower) with sources — and the config numbers (Karen's feel values
   marked). Which parts go behind a feature flag (docs/design/feature-flags.md) so they merge OFF.
3. Outfits: owner and the simplest grey-box version (coloured parts) until the models arrive.
4. The task order for the Builder and what Karen checks in her next playtest.
No local absolute Windows paths.
