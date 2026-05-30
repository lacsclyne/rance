class_name CardInstance
extends RefCounted

const DUPLICATE_AT_BONUS := 1
const TRAINING_HP_BONUS := 2
const DEFAULT_DUPLICATE_TRAINING_POINTS := 1

var character_id := ""
var duplicate_level := 0
var training_points := 0


func _init(
	new_character_id: String = "",
	new_duplicate_level: int = 0,
	new_training_points: int = 0
) -> void:
	character_id = new_character_id
	duplicate_level = max(0, new_duplicate_level)
	training_points = max(0, new_training_points)


func add_duplicate(training_points_gain: int = DEFAULT_DUPLICATE_TRAINING_POINTS) -> void:
	duplicate_level += 1
	training_points += max(0, training_points_gain)


func get_at_bonus() -> int:
	return duplicate_level * DUPLICATE_AT_BONUS


func get_attack_bonus() -> int:
	return get_at_bonus()


func get_hp_bonus() -> int:
	return training_points * TRAINING_HP_BONUS


func get_summary() -> Dictionary:
	return {
		"character_id": character_id,
		"duplicate_level": duplicate_level,
		"training_points": training_points,
		"at_bonus": get_at_bonus(),
		"hp_bonus": get_hp_bonus()
	}
