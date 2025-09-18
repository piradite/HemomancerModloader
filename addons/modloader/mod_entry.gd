extends Panel

const Mod = preload("res://addons/modloader/mod.gd")
const VersionMismatchDialogScene = preload("res://addons/modloader/version_mismatch_dialog.tscn")
const SandboxWarningDialogScene = preload("res://addons/modloader/sandbox_warning_dialog.tscn")
const SettingsMenuScene = preload("res://addons/modloader/mod_settings_menu.tscn")

@onready var name_label = %ModName
@onready var author_label = %ModAuthor
@onready var desc_label = %ModDescription
@onready var status_label = %StatusIndicator
@onready var settings_button = %SettingsButton
@onready var desc_container = desc_label.get_parent()

var mod: Mod
var confirm_dialog
var sandbox_dialog

var scrolling = false
var scroll_speed = 80.0
var original_description: String
var text_width = 0.0
var separator_width = 0.0

func _ready():
	settings_button.pressed.connect(_on_settings_pressed)
	
	confirm_dialog = VersionMismatchDialogScene.instantiate()
	confirm_dialog.confirmed.connect(_on_enable_confirmed)
	add_child(confirm_dialog)
	confirm_dialog.hide()

	sandbox_dialog = SandboxWarningDialogScene.instantiate()
	sandbox_dialog.confirmed.connect(_on_sandbox_confirmed)
	add_child(sandbox_dialog)
	sandbox_dialog.hide()

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if settings_button.get_global_rect().has_point(event.global_position):
			return
		_on_toggled()

func _process(delta):
	if scrolling:
		if text_width > desc_container.size.x:
			desc_label.position.x -= scroll_speed * delta
			if desc_label.position.x <= -(text_width + separator_width):
				desc_label.position.x += (text_width + separator_width)

func set_mod(p_mod: Mod):
	mod = p_mod
	name_label.text = mod.get_name()
	author_label.text = "by " + mod.get_author()
	
	original_description = mod.get_description()
	desc_label.text = original_description
	
	update_status_indicator()

	name_label.modulate = Color.WHITE
	var has_sandbox_issues = not mod.sandboxed_keywords.is_empty()

	if mod.version_mismatch and has_sandbox_issues:
		name_label.text = mod.get_name() + "*"
		name_label.modulate = Color.RED
	elif mod.version_mismatch:
		name_label.modulate = Color.RED
	elif has_sandbox_issues:
		name_label.modulate = Color.ORANGE

	if not mod.manifest.has("settings") or mod.manifest.settings.size() == 0:
		settings_button.hide()

	self.mouse_entered.connect(_start_scroll)
	self.mouse_exited.connect(_stop_scroll)

func _start_scroll():
	await get_tree().process_frame
	var font = desc_label.get_theme_font("font")
	var font_size = desc_label.get_theme_font_size("font_size")
	if not font:
		return

	text_width = font.get_string_size(original_description, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	separator_width = font.get_string_size("    ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	if text_width > desc_container.size.x:
		desc_label.text = original_description + "    " + original_description
	
	scrolling = true

func _stop_scroll():
	if get_global_rect().has_point(get_global_mouse_position()):
		return

	scrolling = false
	desc_label.text = original_description
	desc_label.position.x = 0

func _on_toggled():
	if mod.enabled:
		ModLoader.disable_mod(mod.id)
		update_status_indicator()
	else:
		if not mod.sandboxed_keywords.is_empty():
			var keyword_label = sandbox_dialog.get_node_or_null("Panel/VBoxContainer/KeywordListLabel")
			if keyword_label:
				keyword_label.text = ", ".join(mod.sandboxed_keywords)
			sandbox_dialog.popup_centered()
			return

		if mod.version_mismatch:
			confirm_dialog.set_version_info(mod.get_game_version(), ModLoader.version)
			confirm_dialog.popup_centered()
			return
		
		_enable_mod()

func _on_sandbox_confirmed():
	if mod.version_mismatch:
		confirm_dialog.set_version_info(mod.get_game_version(), ModLoader.version)
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
