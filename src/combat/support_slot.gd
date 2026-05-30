class_name SupportSlot
extends RefCounted

var team := ""
var statuses := []


func _init(team_value: String = "") -> void:
	team = team_value


func to_dictionary() -> Dictionary:
	var status_rows := []
	for status in statuses:
		if status != null and status.has_method("to_dictionary"):
			status_rows.append(status.to_dictionary())
	return {
		"team": team,
		"statuses": status_rows
	}
