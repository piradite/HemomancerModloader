extends CanvasLayer

signal confirmed
signal canceled

@onready var label = $Panel/VBoxContainer/Label
@onready var yes_button = $Panel/VBoxContainer/HBoxContainer/YesButton
@onready var no_button = $Panel/VBoxContainer/HBoxContainer/NoButton

func _ready():
	yes_button.pressed.connect(func(): emit_signal("confirmed"))
	no_button.pressed.connect(func(): emit_signal("canceled"))
	yes_button.pressed.connect(hide)
	no_button.pressed.connect(hide)

func set_version_info(mod_version: String, game_version: String):
	label.text = "This mod is for game version %s, but you are running %s. Are you sure you want to enable it?" % [mod_version, game_version]

func popup_centered():
	show()
