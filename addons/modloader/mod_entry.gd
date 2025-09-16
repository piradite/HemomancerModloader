extends Panel

@onready var name_label = %ModName
@onready var author_label = %ModAuthor
@onready var desc_label = %ModDescription
@onready var status_label = %StatusIndicator
@onready var settings_button = %SettingsButton

var mod: Mod
var confirm_dialog: ConfirmationDialog

const SettingsMenuScene = preload("res://addons/modloader/mod_settings_menu.tscn")

func _ready():
	settings_button.pressed.connect(_on_settings_pressed)
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Enable Mod?"
	confirm_dialog.dialog_text = "This mod is for a different game version. Are you sure you want to enable it?"
	confirm_dialog.confirmed.connect(_on_enable_confirmed)
	add_child(confirm_dialog)

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if settings_button.get_global_rect().has_point(event.global_position):
			return
		_on_toggled()

func set_mod(p_mod: Mod):
	mod = p_mod
	name_label.text = mod.get_name()
	author_label.text = "by " + mod.get_author()
	desc_label.text = mod.get_description()
	update_status_indicator()

	if mod.version_mismatch:
		name_label.modulate = Color.RED

	if not mod.manifest.has("settings") or mod.manifest.settings.size() == 0:
		settings_button.hide()

func _on_toggled():
	if mod.enabled:
		ModLoader.disable_mod(mod.id)
		update_status_indicator()
	else:
		if mod.version_mismatch:
			confirm_dialog.popup_centered()
		else:
			_enable_mod()

func _enable_mod():
	ModLoader.enable_mod(mod.id)
	update_status_indicator()

func _on_enable_confirmed():
	_enable_mod()

func update_status_indicator():
	if mod.enabled:
		status_label.text = "[ ENABLED ]"
		status_label.self_modulate = Color.GREEN
	else:
		status_label.text = "[ DISABLED ]"
		status_label.self_modulate = Color.RED

func _on_settings_pressed():
	var main = get_tree().get_root().get_node_or_null("Main")
	if not main:
		return

	var existing_settings = main.find_child("ModSettingsCanvas", true, false)
	if is_instance_valid(existing_settings):
		existing_settings.queue_free()

	var settings_menu_instance = SettingsMenuScene.instantiate()
	settings_menu_instance.name = "ModSettingsCanvas"
	main.add_child(settings_menu_instance)
	
	var settings_menu_node = settings_menu_instance.get_node("ModSettingsMenu")
	settings_menu_node.set_mod(mod)
