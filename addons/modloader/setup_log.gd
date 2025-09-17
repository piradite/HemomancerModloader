class_name ModLoaderSetupLog

static func info(message: String, mod_name: String) -> void:
	_log(message, mod_name, "INFO")

static func debug(message: String, mod_name: String) -> void:
	_log(message, mod_name, "DEBUG")

static func error(message: String, mod_name: String) -> void:
	_log(message, mod_name, "ERROR")
	printerr(message)

static func fatal(message: String, mod_name: String) -> void:
	_log(message, mod_name, "FATAL")
	assert(false, message)

static func _log(message: String, mod_name: String, log_type: String = "INFO") -> void:
	var time_str := "%s   " % _get_time_string()
	var log_message := "%s%s: %s" % [time_str, log_type, message]
	print(log_message)

static func _get_time_string() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%02d:%02d:%02d" % [now.hour, now.minute, now.second]
