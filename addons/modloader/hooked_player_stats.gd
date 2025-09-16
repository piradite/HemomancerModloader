class_name HookedPlayerStats
extends PlayerStats

func _calc_add_stat(stat_key: StringName) -> float:
	var original_value = super(stat_key)
	return ModLoader._modded_calc_add_stat_hook(stat_key, original_value)

func _calc_mult_stat(stat_key: StringName) -> float:
	var original_value = super(stat_key)
	return ModLoader._modded_calc_mult_stat_hook(stat_key, original_value)
