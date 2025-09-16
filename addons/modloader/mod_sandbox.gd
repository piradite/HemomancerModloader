class_name ModSandbox
extends RefCounted

var mod_id: String

const DENY_KEYWORDS = [
	"OS.execute",
	"OS.shell_open",
	"OS.create_process",
	"FileAccess",
	"DirAccess",
	"HTTPRequest",
	"HTTPClient",
	"TCPServer",
	"StreamPeerTCP",
	"get_tree().quit",
]

func _init(p_mod_id: String):
	mod_id = p_mod_id

func sandbox_script(script_path: String) -> String:
	var file = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		return ""

	var code = file.get_as_text()
	file.close()

	if not _is_script_safe(code):
		return ""

	return code

func _is_script_safe(code: String) -> bool:
	for keyword in DENY_KEYWORDS:
		if code.find(keyword) != -1:
			return false
	return true
