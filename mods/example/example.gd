extends ModBase

func _on_mod_loaded():
	update_stat_from_setting()
	ModAPI.setting_changed.connect(_on_setting_changed)

func _on_mod_unloaded():
	ModAPI.setting_changed.disconnect(_on_setting_changed)

func _on_setting_changed(changed_mod_id: String, setting_name: String, _new_value):
	if changed_mod_id == mod.id and setting_name == "extra_max_health":
		update_stat_from_setting()
		ModAPI.recalculate_stats()

func update_stat_from_setting():
	var hp_boost = ModAPI.get_setting(mod.id, "extra_max_health", 50)
	ModAPI.add_stat(mod, "extra_max_health", hp_boost)