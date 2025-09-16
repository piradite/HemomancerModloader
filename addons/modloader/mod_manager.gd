extends CanvasLayer

@onready var list = %ModList
@onready var reload_btn = %ReloadButton
@onready var back_btn = %BackButton

const EntryScene = preload("res://addons/modloader/mod_entry.tscn")

func _ready():
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	reload_btn.pressed.connect(_on_reload_pressed)
	back_btn.pressed.connect(_on_mod_manager_back_pressed)
	populate_mod_list()

func _process(_delta: float) -> void:
	Global.block_input_manager = visible

func populate_mod_list():
	for child in list.get_children():
		child.queue_free()

	if ModLoader:
		for mod_id in ModLoader.mods:
			var mod = ModLoader.mods[mod_id]
			var mod_entry = EntryScene.instantiate()
			list.add_child(mod_entry)
			mod_entry.set_mod(mod)

func _on_reload_pressed():
	if ModLoader:
		ModLoader.scan_and_load_mods()
		populate_mod_list()

func _on_mod_manager_back_pressed():
	Global.block_input_manager = false
	queue_free()

func _exit_tree():
	Global.block_input_manager = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_mod_manager_back_pressed()
		get_viewport().set_input_as_handled()
