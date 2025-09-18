extends Node

signal command_finished(details, output, exit_code)

func execute(details: Dictionary):
	var thread = Thread.new()
	thread.start(func(): _thread_func(details))

func _thread_func(details: Dictionary):
	var output = []
	var exit_code = OS.execute(details.command, details.arguments, output, details.read_stderr, details.open_console)
	call_deferred("emit_signal", "command_finished", details, output, exit_code)
