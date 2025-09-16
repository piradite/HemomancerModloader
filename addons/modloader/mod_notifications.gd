extends Node

const ModNotificationScene = preload("res://addons/modloader/mod_notification.tscn")

func show_notification(message: String, duration: float = 5.0):
	var notification = ModNotificationScene.instantiate()
	notification.show_message(message, duration)
	get_tree().get_root().call_deferred("add_child", notification)
