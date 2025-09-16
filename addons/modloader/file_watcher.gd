extends Node

signal mods_changed

var watch_dir: String
var cache: Dictionary = {}
var timer: Timer

func _ready():
	timer = Timer.new()
	timer.wait_time = 2.0
	timer.autostart = true
	timer.timeout.connect(_scan_for_changes)
	add_child(timer)

func start_watching(dir_path: String):
	watch_dir = dir_path
	_build_initial_cache()

func _build_initial_cache():
	cache.clear()
	var dir = DirAccess.open(watch_dir)
	if not dir: return

	dir.list_dir_begin()
	var item = dir.get_next()
	while item != "":
		if dir.current_is_dir() and not item.begins_with("."):
			var mod_dir_path = watch_dir.path_join(item)
			var mod_dir = DirAccess.open(mod_dir_path)
			if mod_dir:
				mod_dir.list_dir_begin()
				var file = mod_dir.get_next()
				while file != "":
					if not mod_dir.current_is_dir():
						var file_path = mod_dir_path.path_join(file)
						cache[file_path] = FileAccess.get_modified_time(file_path)
					file = mod_dir.get_next()
		item = dir.get_next()

func _scan_for_changes():
	var changed = false
	var current_files: Dictionary = {}
	
	var dir = DirAccess.open(watch_dir)
	if not dir: return

	var mod_dir_count = 0
	dir.list_dir_begin()
	var item = dir.get_next()
	while item != "":
		if dir.current_is_dir() and not item.begins_with("."):
			mod_dir_count += 1
			var mod_dir_path = watch_dir.path_join(item)
			var mod_dir = DirAccess.open(mod_dir_path)
			if mod_dir:
				mod_dir.list_dir_begin()
				var file = mod_dir.get_next()
				while file != "":
					if not mod_dir.current_is_dir():
						var file_path = mod_dir_path.path_join(file)
						current_files[file_path] = FileAccess.get_modified_time(file_path)
						if not cache.has(file_path) or cache[file_path] != current_files[file_path]:
							changed = true
							break
					file = mod_dir.get_next()
			if changed: break
		item = dir.get_next()

	if not changed and len(current_files) != len(cache):
		changed = true

	if changed:
		cache = current_files
		mods_changed.emit()
