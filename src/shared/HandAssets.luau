--!strict
-- HandAssets: the THREE NAMES the first-person hands are published under, and nothing else.
--
-- It exists because the two ends of that publication cannot see each other's tables. The server
-- loads the hands -- `InsertService:LoadAsset` is server-only, and `ServerStorage.Assets.Loader` is
-- the one place in this repo an asset id becomes an Instance (docs/design/asset-pipeline.md section
-- 5) -- and parks the templates in `ReplicatedStorage`, where `Camera.Viewmodel` clones them under
-- `workspace.CurrentCamera` for the local player. `ServerStorage.Assets` is not replicated, so the
-- client cannot read the manifest at all.
--
-- Without this module the folder name and the two child names would be string literals in two files
-- that never meet, and a typo in one of them is a silent nil and a gun with no hands that nobody can
-- explain -- the reason `Assets.KEYS` and `Map.TAGS` exist, one layer over.
--
-- PURE DATA. No service, no Instance, no state: it is a table of names, frozen.
local HandAssets = {}

-- Created at RUN TIME by `ServerScriptService.ViewmodelAssetsBoot`, never on disk. ReplicatedStorage
-- is Rojo-owned with `$ignoreUnknownInstances: false`, so a folder parked here in Edit would be
-- deleted at the next Connect (CLAUDE.md); a folder a running server makes for itself lives and dies
-- with that server, exactly as `Assets.Loader`'s own cache folder does.
HandAssets.FOLDER_NAME = "ViewmodelHands"
-- ONE FOLDER AGAIN SINCE TASK 114. Task 106 added a second one, `ViewmodelHandsNewGun`, because two
-- guns wanted two pairs of gloves; Karen's gun is the only gun now and her pair is the only pair, so
-- there is one folder and the names in it are the names everything downstream has always used.

HandAssets.RIGHT = "HandRight"
HandAssets.LEFT = "HandLeft"

-- Which manifest key each published name comes from. The SERVER reads this; the client only ever
-- needs the names, because by the time it looks the Instance is already there or it is not.
--
-- `gun.hand.*` AND NOT `hand.*`, AND THE KEYS ARE WHY (task 106, round 2, kept through task 114).
-- Karen's gloves were first shipped as `hand.right` version 2 -- and a new version SUPERSEDES, so
-- `Assets.byKey` handed the OLD gun a pair it was never posed for: upside down (its `twist` of 180 is
-- for a palm-DOWN model) and at 53 % of the size its poses assumed. The fix was a different KEY, and
-- these are those keys. The v1 pair and the gun they were posed for are gone, and their ROWS STAY
-- WHERE THEY ARE: `src/serverstorage/Assets/init.luau` keeps them at `scope = "retired"`, which is
-- rule 7 satisfied in place -- an id that has been in a place is provenance, and nothing loads a
-- scope no boot line asks for.
HandAssets.KEY_OF = table.freeze({
	[HandAssets.RIGHT] = "gun.hand.right",
	[HandAssets.LEFT] = "gun.hand.left",
})

-- WHICH WAY EACH GLOVE'S OWN MESH POINTS, MEASURED (task 108), and this is the whole of Karen's
-- "left hand is oposit180deg need to turn or not sure but broken".
--
-- THE TWO MODELS DO NOT SHARE AN AXIS. Measured off each prepped mesh by classifying every vertex by
-- the colour its own UV samples in the base-colour map -- the cuff is olive, the glove is brown -- so
-- the centroid of one to the centroid of the other IS the wrist-to-fingers direction, exactly:
--
--   RIGHT glove: wrist -> fingers (+0.963, 0.265, -0.048), i.e. its own +X, and the palm faces -Z
--     ...BOTH OF WHICH ARE THE OTHER WAY ROUND FROM THE SOURCE FILE, and those two signs are the
--     whole of Karen's *"hadn is oposit now reload with ending of arm not fingers"* (task 189, the
--     fingers) and *"it has to palm inside now is outside"* (task 190, the palm). See `AXES` below.
--   LEFT  glove: wrist -> fingers ( 0.317, 0.874, -0.369), i.e. its own +Y, and the palm faces
--                roughly (0.458, 0.488, 0.743)
--
-- ONE CONVENTION IS WHAT THIS IS FOR, AND `Camera.Viewmodel.align` IS WHAT READS IT. Because the two
-- models differ, no single yaw/pitch/twist can mean the same thing on both: the Director's live try
-- of `left.rot.twist 180` moved the glove to the far side of the barrels instead of rolling the
-- palm, which is what a shared number does when the two meshes disagree about which axis it turns.
-- So `poseHands` applies a per-glove rotation that takes each mesh into ONE frame -- FINGERS ALONG
-- +X, PALM TOWARD +Y -- on the right of the pose offset, and the pose's three angles are read in
-- THAT frame on both. All three poses in `poses.json` are seeded in it.
--
-- The palm normal is the hand cloud's flattest axis signed toward the fingertips (a curled hand's
-- tips lie over its palm). On the right glove that is a clean slab; on the LEFT, which is a cupped C,
-- it is an estimate -- `align` squares it against the fingers, which were measured exactly, so a few
-- degrees of error there turns into a few degrees of roll and the pose's `twist` is the dial that
-- finishes it.
--
-- `python tools/pose.py inspect <pose>` photographs the drawn viewmodel FROM OUTSIDE, which is how
-- these were judged: three rounds of guessing at two dark lumps beside a barrel could not.

-- WHERE THE RIGHT GLOVE ACTUALLY HOLDS SOMETHING, in that same aligned frame (task 188).
--
-- Karen, 2026-10-15: *"we need to improve right hand now seems odd it has to be aligned perfectly"*.
-- "Aligned" needs a point on the HAND as well as a point on the gun, and this file had neither: the
-- poses placed the part's BOUNDING-BOX CENTRE, which is a point in the middle of the forearm.
--
-- MEASURED, not chosen. The prepped mesh was voxelised at 0.006 studs in the aligned frame and the
-- enclosed hole in its own silhouette found: the three curled fingers, the palm and the thumb ring a
-- gap centred at (+0.165, 0.000, -0.006) whose axis is the aligned Y, 0.054 studs across in X and
-- 0.060 in Z, with a largest inscribed circle of radius 0.024-0.030. One column of it -- exactly
-- this point -- is clear of glove along the WHOLE of Y, so it is a hole and not a dimple. The
-- rifle's bolt knob is a ball of radius 0.0256 (`Rifle.Geometry.boltKnobOffset`), which is the same
-- size: the fist was modelled closed on something this big, and the knob is that thing.
--
-- IT IS AT THE PUBLISHED SIZE. `Assets` scales the glove to `HAND_RIGHT_SIZE` (0.669 x 0.350 x
-- 0.211 studs) and this was measured on the mesh scaled the same way, so it is a part-local offset
-- and needs no dial. If the glove is ever republished at another size this number moves with it.
--
-- NOTHING READS IT AT RUN TIME. `Camera.Viewmodel.poseHands` still places the part, exactly as
-- before; this is what `tests/server/viewmodel_poses.spec.luau` MEASURES the pose data against, so a
-- hand that drifts off the grip or off the knob fails the harness instead of waiting for Karen.
--
-- THE Z IS TASK 188'S AGAIN SINCE TASK 190, and the reason is the whole of that task. Task 189
-- flipped it because it believed the drawn part was a MIRROR of the source file; it is a ROTATION
-- (`AXES.RIGHT` below says how that was measured), and a proper rotation leaves every ALIGNED
-- coordinate exactly where it was -- `(R p) . (R e) = p . e` for all three axes, cross product
-- included. So this is task 188's number, recomputed off the same prepped mesh in task 190 and
-- agreeing with it to 1e-3: nothing about this point ever moved.
HandAssets.GRIP_STUDS = Vector3.new(0.165, 0.0, -0.006)
-- Half the gap, for a tolerance that means something: a grip point this far off still has the wood
-- or the knob inside the hand.
HandAssets.GRIP_RADIUS_STUDS = 0.027

-- THE TWO ENDS OF THE GLOVE (task 189), in the same aligned frame, so a pose can be ASKED which end
-- is doing the holding instead of being believed.
--
-- Karen, 2026-10-15, after playing task 188: *"hadn is oposit now reload with ending of arm not
-- fingers"*. She is describing exactly this: the hand was drawn end-for-end, so the CUFF worked the
-- bolt knob and the fist hung in the air behind it. Nothing in the repo could see that, because the
-- only landmark on the glove was the grip point -- one point, which is at the same distance from the
-- knob whichever way round the hand is.
--
-- MEASURED the same way everything else here is: the mean of the extreme 2 % of the glove's own
-- vertices at each end of the fingers axis, at the published size, in the aligned frame. (THE Z OF
-- BOTH WAS FLIPPED BY TASK 189 AND IS PUT BACK BY TASK 190, for the reason `GRIP_STUDS` gives
-- above: the import is a rotation, which moves no aligned coordinate at all. X and Y are unchanged.) The
-- fingertip landmark is the tip of the one extended digit; the cuff landmark is the open end of the
-- sleeve. `GRIP_STUDS` lies between them, 0.17 from the fingertip and 0.49 from the cuff, which is
-- what makes the spec case meaningful: a pose that holds the knob with the WRONG end puts the cuff
-- nearer the knob than the fingertip, and `viewmodel_poses.spec` fails.
HandAssets.FINGERTIP_STUDS = Vector3.new(0.3324, -0.0599, 0.0178)
HandAssets.CUFF_STUDS = Vector3.new(-0.3238, -0.0105, -0.0315)

-- THE RIGHT GLOVE'S AXES ARE THE DRAWN PART'S, NOT THE SOURCE FILE'S (task 189), and the difference
-- between those two is a MIRROR IN X.
--
-- WHAT WENT WRONG. Task 188 measured these off the published right glove's glTF -- cuff centroid to
-- hand centroid -- and got `fingers = (-0.9632, 0.2645, 0.0484)`. That is correct FOR THAT FILE. It
-- is not correct for the MeshPart Roblox draws: the asset went up as FBX, and the part that comes
-- back has its local X the other way about, so the same numbers point `align`'s +X at the CUFF.
-- Every pose task 188 then SOLVED in that frame came out end-for-end -- the sleeve on the bolt knob,
-- the fist in the air behind it -- which is what Karen saw and said. (The poses tuned BY EYE before
-- that, and the left glove's, never noticed: an eyeballed pose absorbs whatever `align` does, which
-- is exactly why only the solved ones broke.)
--
-- MEASURED IN THE RUNNING GAME, not in the file, which is the only place the question can be
-- settled: marker balls parked on the drawn part's own axes and photographed. Task 189 did the +X
-- and -X ends -- the +X ball sits on the brown fist, the -X ball on the olive cuff
-- (`.screenshots/t189-axes2.png`, `t189-axes3.png`).
--
-- ...AND TASK 189 THEN GUESSED THE OTHER TWO, WHICH IS THE WHOLE OF TASK 190. Two ends do not fix a
-- frame: they fix one axis. Task 189 closed the gap by ASSUMING the import was a mirror in X, which
-- flips `fingers`'s X and leaves `palm`'s Z alone -- and recorded the guess as 189a(k), *"the palm's
-- sign is inferred, not measured ... the glove is rolled, which no spec can see"*. It was rolled.
-- Karen, 2026-10-15 ~16:30: *"now right hand reload with outside of fingersit has to palm inside now
-- is outside fix that"*.
--
-- SO TASK 190 PHOTOGRAPHED THE OTHER AXIS, the same way. The published `HandRight` template was
-- cloned into the sky at IDENTITY rotation with neon balls on its own +-Y and +-Z, and shot down
-- each of the four faces (`.screenshots/t190-glove-minusZ.png` and its three siblings). THE -Z FACE
-- IS THE PALM: it is `assets/.../glove_right_v4_r1/render_across.png` frame for frame -- the thumb
-- and the index closing a ring you can see through, the finger pads below it -- while the +Z face is
-- `render_across-back.png`, the stitched back panel and the knuckles.
--
-- AND THAT MAKES IT A ROTATION, NOT A MIRROR, which is task 189's open question 8.2 answered. In the
-- drawn part the thumb lies at +Y with the fingers at +X and the palm at -Z, so `thumb =
-- fingers x palm` -- the RIGHT-hand relation. A mirror would have made the drawn glove a LEFT hand
-- and put the thumb the other side; it is not and it does not. The import is therefore the proper
-- rotation that carries the file's (-X fingers, +Z palm) to the part's (+X, -Z): a half turn about
-- Y. Both measured signs are what that rotation predicts, and the two landmarks above keep task
-- 188's Z, because a proper rotation moves no coordinate in the aligned frame.
--
-- WHAT IT COSTS TO BE WRONG HERE, AND WHY NO SPEC CAUGHT IT. `align` is DEFINED to put the palm on
-- +Y, so the drawn palm is `handOffset.UpVector` whatever this table says -- a pose file and a spec
-- reading it agree with each other while the glove itself is rolled 180 degrees. The landmarks do
-- not help: both lie within a tenth of a stud of the fingers axis, so they are nearly fixed by the
-- roll. The case that does see it needs THIS table to be right first, and it is in
-- `viewmodel_poses.spec`: the palm must point AT the bolt knob at every sample of the cycle.
--
-- THE LEFT GLOVE IS NOT TOUCHED AND IT IS PROBABLY WRONG IN THE SAME WAY (task 189, reported not
-- fixed): the same screenshots show the left hand's olive cuff flat against the fore-end with its
-- fingers pointing off into the air. Its pose was tuned by eye, so flipping its axis would move a
-- hand Karen has already accepted; it is the next task's, with the evidence in that task's note.
HandAssets.AXES = table.freeze({
	[HandAssets.RIGHT] = table.freeze({
		fingers = Vector3.new(0.9632, 0.2645, -0.0484),
		palm = Vector3.new(0.0660, 0.1061, -0.9922),
	}),
	[HandAssets.LEFT] = table.freeze({
		fingers = Vector3.new(0.3172, 0.8738, -0.3686),
		palm = Vector3.new(0.4579, 0.4884, 0.7428),
	}),
})

return table.freeze(HandAssets)
