class_name ModLoaderSetupUtils


static func get_local_folder_dir(subfolder: String = "") -> String:
	var game_install_directory := OS.get_executable_path().get_base_dir()

	if OS.get_name() == "macOS":
		game_install_directory = game_install_directory.get_base_dir().get_base_dir()

	if OS.has_feature("editor"):
		game_install_directory = "res://"

	return game_install_directory.path_join(subfolder)

static func get_override_path() -> String:
	var base_path := ""
	if OS.has_feature("editor"):
		base_path = ProjectSettings.globalize_path("res://")
	else:
		base_path = OS.get_executable_path().get_base_dir()

	return base_path.path_join("override.cfg")

static func get_autoload_array() -> Array:
	var autoloads := []
	for prop in ProjectSettings.get_property_list():
		var name: String = prop.name
		if name.begins_with("autoload/"):
			autoloads.append(name.trim_prefix("autoload/"))
	return autoloads

static func get_autoload_index(autoload_name: String) -> int:
	var autoloads := get_autoload_array()
	return autoloads.find(autoload_name)

static func get_flat_view_dict(p_dir := "res://") -> PackedStringArray:
	var data: PackedStringArray = []
	var dirs := [p_dir]
	while not dirs.is_empty():
		var dir_name: String = dirs.back()
		dirs.pop_back()
		var dir := DirAccess.open(dir_name)
		if dir:
			dir.list_dir_begin()
			var file_name := dir.get_next()
			while file_name != "":
				if not file_name.begins_with("."):
					if dir.current_is_dir():
						dirs.push_back(dir.get_current_dir().path_join(file_name))
					else:
						data.append(dir.get_current_dir().path_join(file_name))
				file_name = dir.get_next()
	return data

static func copy_file(from: String, to: String) -> void:
	var global_to_path := ProjectSettings.globalize_path(to.get_base_dir())
	if not DirAccess.dir_exists_absolute(global_to_path):
		DirAccess.make_dir_recursive_absolute(global_to_path)

	var file_from := FileAccess.open(from, FileAccess.READ)
	if file_from.get_error() != OK: return

	var content := file_from.get_buffer(file_from.get_length())
	var file_to := FileAccess.open(to, FileAccess.WRITE)
	if file_to.get_error() != OK: return
	file_to.store_buffer(content)
