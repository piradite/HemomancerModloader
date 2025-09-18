extends Node

enum LogLevel { DEBUG, INFO, WARNING, ERROR }

var log_level = LogLevel.DEBUG
var log_file_path = "user://logs/modloader.log"
var log_file: FileAccess

func _ready():
	var dir_path = log_file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if log_file:
		pass
	else:
		push_error("Failed to open log file: %s" % log_file_path)

func _exit_tree():
	if log_file:
		log_file.close()

func debug(message: String):
	_log(LogLevel.DEBUG, message)

func info(message: String):
	_log(LogLevel.INFO, message)

func warning(message: String):
	_log(LogLevel.WARNING, message)

func error(message: String):
	_log(LogLevel.ERROR, message)

func _log(level: LogLevel, message: String):
	if level < log_level:
		return
	var level_str = LogLevel.keys()[level]
	var timestamp = Time.get_datetime_string_from_system()
	var formatted_message = "[%s] [%s] %s" % [timestamp, level_str, message]

	if log_file:
		log_file.store_line(formatted_message)
		log_file.flush()
