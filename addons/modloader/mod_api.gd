extends Node

signal command_executed(details, output)
signal process_created(details, pid)

const Mod = preload("res://addons/modloader/mod.gd")
const ModBase = preload("res://addons/modloader/mod_base.gd")
const Hook = preload("res://addons/modloader/hook.gd")
const PermissionDialogScene = preload("res://addons/modloader/permission_dialog.tscn")
const ThreadedExecutor = preload("res://addons/modloader/threaded_executor.gd")
const SandboxedHTTPRequest = preload("res://addons/modloader/sandboxed_http_request.gd")
const SandboxedHTTPClient = preload("res://addons/modloader/sandboxed_http_client.gd")

signal game_ready
signal setting_changed(mod_id: String, setting_name: String, new_value)

var permission_dialog
var permission_queue = []
var is_dialog_visible = false

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

func sandboxed_os_execute(mod: Mod, command: String, arguments: Array, read_stderr: bool = false, open_console: bool = false):
	var permission = ModSettings.get_permission(mod.id, "os_execute")
	
	var details = {
		"command": command,
		"arguments": arguments,
		"read_stderr": read_stderr,
		"open_console": open_console
	}

	match permission:
		"always_allow":
			_execute_threaded(details)
		"always_deny":
			pass
		"ask":
			var request = {
				"mod": mod,
				"type": "os_execute",
				"details": details
			}
			_enqueue_permission_request(request)

func _execute_threaded(details):
	var executor = ThreadedExecutor.new()
	add_child(executor)
	executor.command_finished.connect(func(d, output, exit_code):
		var result_details = d.duplicate()
		result_details["exit_code"] = exit_code
		command_executed.emit(result_details, output)
		executor.queue_free()
	)
	executor.execute(details)

func sandboxed_os_shell_open(mod: Mod, uri: String) -> int:
	var permission = ModSettings.get_permission(mod.id, "os_shell_open")
	match permission:
		"always_allow":
			OS.shell_open(uri)
			return OK
		"always_deny":
			return FAILED
		"ask":
			var request = {
				"mod": mod,
				"type": "os_shell_open",
				"details": uri
			}
			_enqueue_permission_request(request)
			return OK
	return FAILED

func sandboxed_os_create_process(mod: Mod, path: String, arguments: Array, open_console: bool = false) -> int:
	var permission = ModSettings.get_permission(mod.id, "os_create_process")
	match permission:
		"always_allow":
			return OS.create_process(path, arguments, open_console)
		"always_deny":
			return -1
		"ask":
			var request = {
				"mod": mod,
				"type": "os_create_process",
				"details": {
					"path": path,
					"arguments": arguments,
					"open_console": open_console
				}
			}
			_enqueue_permission_request(request)
			return 0
	return -1

func _enqueue_permission_request(request):
	permission_queue.append(request)
	_process_permission_queue()

func _process_permission_queue():
	if is_dialog_visible or permission_queue.is_empty():
		return

	if not permission_dialog:
		permission_dialog = PermissionDialogScene.instantiate()
		permission_dialog.permission_granted.connect(_on_permission_granted)
		permission_dialog.dialog_hidden.connect(_on_dialog_hidden)
		get_tree().get_root().call_deferred("add_child", permission_dialog)

	is_dialog_visible = true
	var request = permission_queue.pop_front()
	permission_dialog.call_deferred("prompt", request.mod, request.details, request.type)

func _on_permission_granted(p_mod, p_details, p_type):
	match p_type:
		"os_execute":
			_execute_threaded(p_details)
		"os_shell_open":
			OS.shell_open(p_details)
		"os_create_process":
			var pid = OS.create_process(p_details.path, p_details.arguments, p_details.open_console)
			process_created.emit(p_details, pid)
		"http_request":
			p_details.requester._http_request.set("ssl_validate_domain", p_details.ssl_validate_domain)
			p_details.requester._http_request.request(p_details.url, p_details.custom_headers, p_details.method, p_details.request_data)
		"http_client_connect":
			p_details.requester._http_client.connect_to_host(p_details.host, p_details.port, p_details.tls_options)
		"http_client_request":
			p_details.requester._http_client.request(p_details.method, p_details.url, p_details.headers, p_details.body)


func _on_dialog_hidden():
	is_dialog_visible = false
	_process_permission_queue()

func sandboxed_file_access_open(path: String, flags: int) -> FileAccess:
	if not path.begins_with("user://") and not path.begins_with("res://"):
		return null
	return FileAccess.open(path, flags)


func sandboxed_dir_access_open(path: String) -> DirAccess:
	if not path.begins_with("user://") and not path.begins_with("res://"):
		return null
	return DirAccess.open(path)


func sandboxed_http_request_new(mod: Mod) -> SandboxedHTTPRequest:
	var http_request = SandboxedHTTPRequest.new()
	http_request.mod = mod
	add_child(http_request)
	return http_request   


func sandboxed_http_client_new(mod: Mod) -> SandboxedHTTPClient:
	var http_client = SandboxedHTTPClient.new()
	http_client.mod = mod
	return http_client

func sandboxed_tcp_server_new() -> TCPServer:
	return null

func sandboxed_tcp_peer_new() -> StreamPeerTCP:
	return null

func sandboxed_quit():
	pass

func pathify(path: String) -> String:
	if path.begins_with("run://"):
		return "%s/%s" % [run_path(), path.trim_prefix("run://")]
	return path

func run_path() -> String:
	return OS.get_executable_path().get_base_dir()