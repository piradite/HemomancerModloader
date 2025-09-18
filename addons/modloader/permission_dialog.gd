extends CanvasLayer

signal permission_granted(mod, details, type)
signal dialog_hidden

@onready var message_label = get_node("Panel/VBoxContainer/MessageLabel")
@onready var remember_checkbox = get_node("Panel/VBoxContainer/RememberCheckBox")
@onready var allow_button = get_node("Panel/VBoxContainer/HBoxContainer/AllowButton")
@onready var deny_button = get_node("Panel/VBoxContainer/HBoxContainer/DenyButton")

var mod: Mod
var details: Variant
var type: String

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	allow_button.pressed.connect(func(): _on_response(true))
	deny_button.pressed.connect(func(): _on_response(false))

func prompt(p_mod: Mod, p_details: Variant, p_type: String):
	mod = p_mod
	details = p_details
	type = p_type

	var message = ""
	match type:
		"os_shell_open":
			message = "Mod '%s' wants to open the following URL:\n\n%s\n\nDo you want to allow this?" % [mod.get_name(), details]
		"os_execute":
			var command_str = details.command + " " + " ".join(details.arguments)
			message = "Mod '%s' wants to run the following command:\n\n%s\n\nThis could be dangerous. Do you want to allow this?" % [mod.get_name(), command_str]
		"os_create_process":
			var command_str = details.path + " " + " ".join(details.arguments)
			message = "Mod '%s' wants to run the following background process:\n\n%s\n\nThis could be dangerous. Do you want to allow this?" % [mod.get_name(), command_str]
		"http_request":
			message = "Mod '%s' wants to make a web request to the following URL:\n\n%s" % [mod.get_name(), details.url]
			if not details.ssl_validate_domain:
				message += "\n\nWARNING: This request is insecure and is vulnerable to man-in-the-middle attacks."
			message += "\n\nDo you want to allow this?"
		"http_client_connect":
			message = "Mod '%s' wants to connect to host '%s' on port %d.\n\nDo you want to allow this?" % [mod.get_name(), details.host, details.port]
			if details.tls_options and not details.tls_options.verify_host:
				message += "\n\nWARNING: This connection is insecure (SSL validation disabled) and is vulnerable to man-in-the-middle attacks."
		"http_client_request":
			message = "Mod '%s' wants to send a low-level HTTP request to '%s'.\n\nDo you want to allow this?" % [mod.get_name(), details.url]

	message_label.text = message
	remember_checkbox.button_pressed = false
	show()

func _on_response(allowed: bool):
	if remember_checkbox.button_pressed:
		var value = "always_allow" if allowed else "always_deny"
		ModSettings.set_permission(mod.id, type, value)

	if allowed:
		emit_signal("permission_granted", mod, details, type)

	hide()
	dialog_hidden.emit()
