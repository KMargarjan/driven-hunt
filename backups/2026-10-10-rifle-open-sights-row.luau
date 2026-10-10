	-- THE SAME RIFLE WITH THE GLASS OFF (task 143). Karen: *"and also we need to have option rifle
	-- without scope ... where aiming true nozzle"*.
	--
	-- EVERY NUMBER IS THE SCOPED RIFLE'S, deliberately: it is the same gun, the same bolt, the same
	-- magazine of three, the same ballistics and the same voice. **Three things differ and they are
	-- all about the sight**: it does not wear `rifle.scope`, its `scope` is nil (so the camera gives
	-- it `FOV_AIM_DEG` -- the shotgun's bead zoom -- with no reticle, no mask and no sway, which is
	-- what "aim like the shotgun" means in this codebase), and `SIGHT = "bead"` tells the geometry to
	-- drop the scope tube and draw a front sight at the muzzle instead.
	--
	-- A ROW RATHER THAN AN OPTION ON THE RIFLE, because every reader in this repo already keys on a
	-- weapon id -- the loadout, the hotbar, the Tool name, the pose set, the report's own word -- and
	-- "the rifle, but a different gun to hold" is exactly what an id is for. The shop later decides
	-- who owns which; today it is slot 3 behind the same flag.
	rifle_open = {
		id = "rifle_open",
		label = "RIFLE (OPEN)",
		toolName = "RifleOpen",
		slot = 3,
		RANGE_STUDS = Rifle.CONFIG.RANGE_STUDS,
		PELLETS = Rifle.CONFIG.PELLETS,
		SPREAD_FULL_DEG = Rifle.CONFIG.SPREAD_FULL_DEG,
		AMMO_KINDS = Rifle.CONFIG.AMMO_KINDS,
		AMMO_LABEL = Rifle.CONFIG.AMMO_LABEL,
		INITIAL_AMMO = Rifle.CONFIG.INITIAL_AMMO,
		START_RESERVE = Rifle.CONFIG.START_RESERVE,
		BARRELS = Rifle.CONFIG.BARRELS,
		BARREL_DELAY = Rifle.CONFIG.BARREL_DELAY,
		AUTO_CYCLE = Rifle.CONFIG.AUTO_CYCLE,
		CYCLE = Rifle.CONFIG.CYCLE,
		CYCLE_TOTAL = Rifle.CONFIG.CYCLE_TOTAL,
		CYCLE_EJECTS = Rifle.CONFIG.CYCLE_EJECTS,
		RELOAD = Rifle.CONFIG.RELOAD,
		RELOAD_TOTAL = Rifle.CONFIG.RELOAD_TOTAL,
		MAGAZINE = Rifle.CONFIG.MAGAZINE,
		AUTO_RELOAD_WHEN_EMPTY = Rifle.CONFIG.AUTO_RELOAD_WHEN_EMPTY,
		READOUT = Rifle.CONFIG.READOUT,
		HANDLE_SIZE = Rifle.CONFIG.HANDLE_SIZE,
		HANDLE_TRANSPARENCY = Rifle.CONFIG.HANDLE_TRANSPARENCY,
		GRIP = Rifle.CONFIG.GRIP,
		MUZZLE_OFFSET = Rifle.CONFIG.MUZZLE_OFFSET,
		HANDLE_COLOR = Rifle.CONFIG.LOOK.wood,
		LOOK = Rifle.CONFIG.LOOK,
		-- THREE GROUPS, NOT FOUR: the scope's upload is simply not worn. The rings stay, because they
		-- are part of the action's own mesh rather than a group of their own -- a rifle whose owner
		-- took the glass off still has its mounts.
		ASSET_KEYS = { "rifle.action", "rifle.stock", "rifle.bolt" },
		MESH_NAMES = { "Model", "Stock", "Bolt" },
		SOUND = Rifle.CONFIG.SOUND,
		-- NO `scope` AT ALL, which is what gives it the shotgun's aim: `Camera.Mode.fovFor` falls back
		-- to `FOV_AIM_DEG`, `Hud.scopeVisible` and `Hud.reticleVisible` are both false for want of an
		-- eyepiece, and `Viewmodel.hiddenByScope` never hides the gun. Karen's no-crosshair rule is
		-- untouched: the crosshair is false in first person whatever is in the hands.
		SIGHT = "bead",
	} :: Row,
