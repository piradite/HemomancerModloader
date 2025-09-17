extends Node

const Mod = preload("res://addons/modloader/mod.gd")
const ModBase = preload("res://addons/modloader/mod_base.gd")
const Hook = preload("res://addons/modloader/hook.gd")

signal game_ready
signal setting_changed(mod_id: String, setting_name: String, new_value)

func _ready():
	if ModLoader:
		ModLoader.game_ready.connect(func(): game_ready.emit())

func add_hook(mod: Mod, node: Node, hook: Hook):
	return ModLoader.add_hook(mod.id, node, hook)

func replace_script(node: Node, new_script_path: String):
	if node and new_script_path:
		var script = load(new_script_path)
		if script:
			node.set_script(script)
			return true
	return false

func set_property(mod: Mod, object: Object, property_name: String, value):
	return ModLoader.set_property(mod.id, object, property_name, value)

func get_mod_upgrades(mod: Mod) -> Upgrades:
	if ModLoader.mod_upgrades.has(mod.id):
		return ModLoader.mod_upgrades[mod.id]
	return null

func add_stat(mod: Mod, stat: String, value):
	ModLoader.add_stat(mod.id, stat, value)

func add_modifier(mod: Mod, stat: String, value):
	ModLoader.add_modifier(mod.id, stat, value)

func get_setting(mod_id: String, setting_name: String, default_value):
	return ModSettings.get_setting(mod_id, setting_name, default_value)

func set_setting(mod_id: String, setting_name: String, value):
	ModSettings.set_setting(mod_id, setting_name, value)
	setting_changed.emit(mod_id, setting_name, value)

func recalculate_stats():
	ModLoader._recalculate_all_stats()

func sandboxed_os_execute(command: String, arguments: Array, output: Array = [], read_stderr: bool = false, open_console: bool = false) -> int:
	return -1

func sandboxed_os_shell_open(uri: String) -> int:
	return -1

func sandboxed_os_create_process(path: String, arguments: Array, open_console: bool = false) -> int:
	return -1

func sandboxed_file_access_open(path: String, flags: int) -> FileAccess:
	if not path.begins_with("user://") and not path.begins_with("res://"):
		return null
	return FileAccess.open(path, flags)

func sandboxed_dir_access_open(path: String) -> DirAccess:
	if not path.begins_with("user://") and not path.begins_with("res://"):
		return null
	return DirAccess.open(path)

func sandboxed_http_request_new() -> HTTPRequest:
	return HTTPRequest.new()

func sandboxed_http_client_new() -> HTTPClient:
	return HTTPClient.new()

func sandboxed_tcp_server_new() -> TCPServer:
	return null

func sandboxed_tcp_peer_new() -> StreamPeerTCP:
	return null

func sandboxed_quit():
	pass
