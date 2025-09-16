class_name Mod
extends RefCounted

var id: String
var path: String
var manifest: Dictionary
var instance: Node
var enabled: bool = true
var version_mismatch: bool = false

var settings: Dictionary = {}
var stats: Dictionary = {}
var modifiers: Dictionary = {}

func _init(p_id, p_path, p_manifest):
	id = p_id
	path = p_path
	manifest = p_manifest
	load_enabled_state()
	load_settings()

func get_name() -> String:
	return manifest.get("name", id)

func get_version() -> String:
	return manifest.get("version", "0.0.0")

func get_author() -> String:
	return manifest.get("author", "Unknown")

func get_description() -> String:
	return manifest.get("description", "")

func save_enabled_state():
	var config = ConfigFile.new()
	config.set_value("state", "enabled", enabled)
	config.save(path.path_join("mod_state.cfg"))

func load_enabled_state():
	var config = ConfigFile.new()
	var err = config.load(path.path_join("mod_state.cfg"))
	if err == OK:
		enabled = config.get_value("state", "enabled", true)

func get_setting(key: String, default_value):
	return settings.get(key, default_value)

func set_setting(key: String, value):
	settings[key] = value
	save_settings()

func save_settings():
	var config = ConfigFile.new()
	for key in settings:
		config.set_value("values", key, settings[key])
	config.save(path.path_join("settings.cfg"))

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(path.path_join("settings.cfg"))
	if err == OK:
		var keys = config.get_section_keys("values")
		for key in keys:
			settings[key] = config.get_value("values", key)
