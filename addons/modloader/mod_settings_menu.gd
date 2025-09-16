extends Control

@onready var name_label = %ModName
@onready var container = %Settings
@onready var back_btn = %BackButton

var mod: Mod

const ROW_HEIGHT = 40

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	back_btn.pressed.connect(_on_back_pressed)

func set_mod(p_mod: Mod):
	mod = p_mod
	name_label.text = mod.get_name() + " Settings"
	_generate_settings_ui()

func _generate_settings_ui():
	for child in container.get_children():
		child.queue_free()

	if not mod.manifest.has("settings") or mod.manifest.get("settings").size() == 0:
		var no_settings_label = Label.new()
		no_settings_label.text = "This mod has no configurable settings."
		container.add_child(no_settings_label)
		return

	var schema = mod.manifest.get("settings", [])
	for def in schema:
		var name = def.get("name")
		var text = def.get("label", name)
		var type = def.get("type")
		var default = def.get("default")

		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size.y = ROW_HEIGHT
		
		var label = Label.new()
		label.text = text
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var value = ModAPI.get_setting(mod.id, name, default)

		match type:
			"bool":
				var checkbox = CheckBox.new()
				checkbox.button_pressed = value
				checkbox.toggled.connect(func(v): _on_setting_changed(name, v))
				row.add_child(checkbox)
			"int", "float":
				var slider = HSlider.new()
				slider.min_value = def.get("min", 0)
				slider.max_value = def.get("max", 100)
				slider.step = def.get("step", 1)
				slider.value = value
				slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(slider)

				var val_label = Label.new()
				val_label.custom_minimum_size.x = 80
				val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				val_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				val_label.text = str(value)
				row.add_child(val_label)

				slider.value_changed.connect(func(v):
					_on_setting_changed(name, v)
					val_label.text = str(snapped(v, slider.step))
				)
			"string":
				var line_edit = LineEdit.new()
				line_edit.text = value
				line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				line_edit.text_changed.connect(func(v): _on_setting_changed(name, v))
				row.add_child(line_edit)

		container.add_child(row)

	container.custom_minimum_size.y = schema.size() * ROW_HEIGHT

func _on_setting_changed(setting_name: String, new_value):
	ModAPI.set_setting(mod.id, setting_name, new_value)

func _on_back_pressed():
	get_parent().queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		accept_event()
