extends RefCounted

## The DCS catalog discovers Rastro without framework branches or game dependencies.

const Options = preload("res://games/rastro/rastro_options.gd")
const Garage = preload("res://games/rastro/garage_state.gd")


static func manifest() -> GameManifest:
	var game := GameManifest.new()
	game.id = Options.GAME_ID
	game.title = "Rastro"
	game.tagline = "Three cars. Your signature."
	game.menu_order = 19
	game.gameplay_scene_path = "res://games/rastro/gameplay.tscn"
	game.intro_scene_path = "res://games/rastro/intro.tscn"
	game.supports_multiplayer = false
	game.supports_cpu_opponent = false
	game.uses_shell_round_rules = false
	game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	game.control_bindings = Options.CONTROL_BINDINGS
	game.tutorial_video_path = "res://games/rastro/assets/video/tutorial.ogv"
	game.tutorial_poster_path = "res://games/rastro/assets/video/tutorial_poster.webp"
	game.save_files = [{
		"path": Garage.SAVE_PATH, "title": "Garage",
		"description": "The selected car and each car's paint, wheels, tires, suspension and engine.",
	}]
	game.stats_url = "https://deskcansaw.com"
	game.theme = GameTheme.new()
	game.theme.logo_texture_path = "res://games/rastro/assets/logo.svg"
	game.theme.accent = Color("e4b54e")
	game.theme.light = Color("f5e1b5")
	game.theme.plaque_color = Color("203237")
	game.theme.background_top = Color("1d343b")
	game.theme.background_bottom = Color("0d171d")
	game.theme.menu_motion = GameTheme.MenuMotion.FIRM
	game.copy = {
		"single_player_description": "An untimed 3D workshop. All three cars and every part are free.",
		"instructions_solo_summary": "Choose a car, make it yours, and keep a portable build.",
		"instructions_headline": "MAKE IT YOURS",
		"instructions_rules": (
			"Rastro currently contains a garage, not races or competitions.\n"
			+ "The Nissan Cube, Hyundai Sonata and Honda CR-V are all available immediately. "
			+ "Each keeps its own build. Paint and rim finishes are cosmetic; wheels, tires, "
			+ "suspension, ride height and engine kits change the displayed tuning estimates. "
			+ "Those estimates are fictional game values, not manufacturer specifications. "
			+ "There is no driving simulation in this version.\n"
			+ "Changes save automatically. Factory reset asks before resetting only the selected car. "
			+ "The main menu's Saves screen can back up, restore or delete the garage.\n"
			+ "Export build shows version 1 JSON; Import build validates pasted JSON before replacing "
			+ "only its named car. No models or scripts are imported. "
			+ "The format prepares for future Cube Trials support; that game cannot load it yet."
		),
		"player_one_control_description": (
			"Use normal UI navigation to choose parts. Camera keys inspect without changing parts."
		),
		"instructions_player_one_controls": (
			"Mouse or touch: choose parts, drag the car to orbit, wheel or pinch to zoom. "
			+ "The camera buttons work with touch, keyboard and gamepad. "
			+ "Keyboard: Tab / arrows navigate; Enter selects. Use the rebindable camera keys below. "
			+ "Gamepad: left stick / D-pad navigates, A selects, right stick orbits, "
			+ "shoulder buttons zoom, Y frames the car, Start opens the menu. Escape also opens the menu."
		),
	}
	game.credits = [
		{"heading": "Rastro", "lines": ["Design and development - DeskCanSaw Games"]},
		{"heading": "Original car models", "lines": [
			"DeskCanSaw Games - original Cube Trials meshes, copied into Rastro",
			"Original procedural workshop and aftermarket parts",
			"Vehicle names identify the models; no manufacturer endorsement.",
		]},
	]
	return game
