extends CanvasLayer

@onready var label = $PanelContainer/Label
var timer: Timer

var _message: String
var duration: float = 5.0

func _ready():
	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	
	label.text = _message
	timer.start(duration)

func show_message(message: String, p_duration: float = 5.0):
	_message = message
	duration = p_duration
