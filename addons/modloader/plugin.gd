@tool
extends EditorPlugin

func _enter_tree():
	add_autoload_singleton("ModLoaderLog", "res://addons/modloader/log.gd")
	add_autoload_singleton("ModSettings", "res://addons/modloader/mod_settings.gd")
	add_autoload_singleton("ModLoader", "res://addons/modloader/mod_loader.gd")
	add_autoload_singleton("ModAPI", "res://addons/modloader/mod_api.gd")
	add_autoload_singleton("ModNotifications", "res://addons/modloader/mod_notifications.gd")

func _exit_tree():
	remove_autoload_singleton("ModLoader")
	remove_autoload_singleton("ModAPI")
	remove_autoload_singleton("ModNotifications")
	remove_autoload_singleton("ModLoaderLog")
	remove_autoload_singleton("ModSettings")
