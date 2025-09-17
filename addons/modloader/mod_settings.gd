extends Node

var settings: Dictionary = {}
const SETTINGS_FILE = "user://mod_settings.json"

func _ready():
	load_settings()

func load_settings():
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			var data = json.get_data()
			if typeof(data) == TYPE_DICTIONARY:
				settings = data
			else:
				pass
		else:
			pass
	ModLoader._on_settings_ready()

func save_settings():
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(settings, "	")
		file.store_string(json_string)
		file.close()
	else:
		pass

func get_setting(mod_id: String, setting_name: String, default_value):
	var value = default_value
	if settings.has(mod_id) and settings[mod_id].has(setting_name):
		value = settings[mod_id][setting_name]
	return value

func set_setting(mod_id: String, setting_name: String, value):
	if not settings.has(mod_id):
		settings[mod_id] = {}
	settings[mod_id][setting_name] = value
	save_settings()