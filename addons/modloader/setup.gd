extends SceneTree

const LOG_NAME := "ModLoader:Setup"

var ModLoaderSetupLog: Object = load("res://addons/modloader/setup_log.gd")
var ModLoaderSetupUtils: Object = load("res://addons/modloader/setup_utils.gd")

const AUTOLOADS_TO_ADD := [
	{"name": "ModLoaderLog", "path": "*res://addons/modloader/log.gd"},
	{"name": "ModLoader", "path": "*res://addons/modloader/mod_loader.gd"},
	{"name": "ModSettings", "path": "*res://addons/modloader/mod_settings.gd"},
	{"name": "ModAPI", "path": "*res://addons/modloader/mod_api.gd"},
	{"name": "ModNotifications", "path": "*res://addons/modloader/mod_notifications.gd"}
]

func _init() -> void:
	ModLoaderSetupLog.info("ModLoader setup initialized", LOG_NAME)

	if is_modloader_setup():
		modded_start()
		return

	setup_modloader()

func is_modloader_setup() -> bool:
	var override_path = ModLoaderSetupUtils.get_override_path()
	return FileAccess.file_exists(override_path)

func modded_start() -> void:
	ModLoaderSetupLog.info("ModLoader is already set up. Nothing to do.", LOG_NAME)

func setup_modloader() -> void:
	ModLoaderSetupLog.info("Setting up ModLoader...", LOG_NAME)
	handle_override_cfg()

	ModLoaderSetupLog.info("ModLoader is set up. Please restart the game.", LOG_NAME)
	OS.alert("The ModLoader has been set up. The game needs to be restarted to apply the changes.")
	restart()

func make_project_data_public() -> void:
	pass

func get_combined_global_script_class_cache() -> ConfigFile:
	ModLoaderSetupLog.info("Creating combined class cache...", LOG_NAME)

	var game_classes_raw = ProjectSettings.get_setting("_global_script_classes", [])
	var game_classes = []
	for c in game_classes_raw:
		game_classes.append(c)

	var modloader_classes = [
		{"base": "Resource", "class": "PlayerStats", "language": "GDScript", "path": "res://types/stats.gd"},
		{"base": "RefCounted", "class": "Mod", "language": "GDScript", "path": "res://addons/modloader/mod.gd"},
		{"base": "Resource", "class": "Hook", "language": "GDScript", "path": "res://addons/modloader/hook.gd"},
		{"base": "Node", "class": "ModBase", "language": "GDScript", "path": "res://addons/modloader/mod_base.gd"},
		{"base": "PlayerStats", "class": "HookedPlayerStats", "language": "GDScript", "path": "res://addons/modloader/hooked_player_stats.gd"},
		{"base": "RefCounted", "class": "ModSandbox", "language": "GDScript", "path": "res://addons/modloader/mod_sandbox.gd"}
	]

	var combined_classes = game_classes
	var existing_class_names = {}
	for c in game_classes:
		existing_class_names[c.class] = true
	
	for c in modloader_classes:
		if not existing_class_names.has(c.class):
			combined_classes.append(c)

	var final_cache := ConfigFile.new()
	final_cache.set_value("", "list", combined_classes)
	return final_cache

func handle_override_cfg() -> void:
	var class_cache := get_combined_global_script_class_cache()

	var override_path = ModLoaderSetupUtils.get_override_path()
	ModLoaderSetupLog.info("Building and saving override.cfg at: %s" % override_path, LOG_NAME)
	
	var final_config := ConfigFile.new()

	var game_classes = class_cache.get_value("", "list", [])
	if not game_classes.is_empty():
		final_config.set_value("_global_script_classes", "list", game_classes)

	var existing_autoloads := {}
	var autoload_props = ProjectSettings.get_property_list().filter(func(p): return p.name.begins_with("autoload/"))
	for prop in autoload_props:
		var autoload_name = prop.name.trim_prefix("autoload/")
		existing_autoloads[autoload_name] = ProjectSettings.get_setting(prop.name)

	for autoload_info in AUTOLOADS_TO_ADD:
		final_config.set_value("autoload", autoload_info.name, autoload_info.path)

	for autoload_name in existing_autoloads.keys():
		if not AUTOLOADS_TO_ADD.has(autoload_name):
			final_config.set_value("autoload", autoload_name, existing_autoloads[autoload_name])

	var save_error := final_config.save(override_path)
	if save_error != OK:
		ModLoaderSetupLog.error("Failed to save override.cfg with error code: %s" % save_error, LOG_NAME)

func restart() -> void:
	OS.set_restart_on_exit(true)
	quit()
