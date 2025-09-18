class_name ModSandbox
extends RefCounted

var mod_id: String

const DENY_KEYWORDS = [
	"OS.execute",
	"OS.shell_open",
	"OS.create_process",
	"HTTPRequest",
	"HTTPClient",
	"TCPServer",
	"StreamPeerTCP",
	"FileAccess",
	"DirAccess",
	"get_tree().quit",
	"replace_script"
]

func _init(p_mod_id: String):
	mod_id = p_mod_id

func get_unsafe_keywords(code: String) -> Array:
	var found_keywords = []
	for keyword in DENY_KEYWORDS:
		if code.find(keyword) != -1:
			found_keywords.append(keyword)
	return found_keywords
