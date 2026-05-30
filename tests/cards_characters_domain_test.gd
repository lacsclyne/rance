extends SceneTree

const CollectionStateScript := preload("res://src/cards_characters/collection_state.gd")
const FormationStateScript := preload("res://src/cards_characters/formation_state.gd")

var _failures := []


func _init() -> void:
	var exit_code := _run()
	if exit_code == 0:
		print("Cards and characters domain validation passed.")
	else:
		printerr("Cards and characters domain validation failed:")
		for failure in _failures:
			printerr("- %s" % failure)
	quit(exit_code)


func _run() -> int:
	var loader = load("res://src/data/content_data_loader.gd").new()
	var loaded: Dictionary = loader.load_and_validate()
	_expect(loaded["ok"], "content data must validate before domain checks")
	if not loaded["ok"]:
		for error in loaded["errors"]:
			_failures.append(error)
		return 1

	var collection = CollectionStateScript.new(loaded)
	collection.add_character_cards([
		"character.iris",
		"character.toma",
		"character.maelle",
		"character.ren",
		"character.bram"
	])
	collection.add_character_card("character.iris")

	var iris_card = collection.get_card_instance("character.iris")
	_expect(iris_card != null, "owned character card can be fetched")
	if iris_card != null:
		_expect_equal(1, iris_card.duplicate_level, "duplicate card increments duplicate level")
		_expect_equal(1, iris_card.training_points, "duplicate card adds training points")

	var squads: Dictionary = collection.build_faction_squads()
	_expect(squads.has("faction.liberation_front"), "known faction squad is available")
	_expect(squads.has("faction.arcane_union"), "second known faction squad is available")
	_expect(squads.has("faction.iron_court"), "unowned known faction still has a zero squad")
	if squads.has("faction.liberation_front"):
		_expect_equal(21, squads["faction.liberation_front"].get_at(), "owned faction AT includes duplicates and non-leaders")
		_expect_equal(122, squads["faction.liberation_front"].get_hp(), "owned faction HP includes duplicate training")
	if squads.has("faction.arcane_union"):
		_expect_equal(12, squads["faction.arcane_union"].get_at(), "second owned faction AT is calculated")
		_expect_equal(62, squads["faction.arcane_union"].get_hp(), "second owned faction HP is calculated")
	if squads.has("faction.iron_court"):
		_expect_equal(0, squads["faction.iron_court"].get_at(), "unowned faction AT remains zero")
		_expect_equal(0, squads["faction.iron_court"].get_hp(), "unowned faction HP remains zero")

	var formation = FormationStateScript.new(collection)
	_expect_equal(3, formation.get_frontline_slot_count(), "formation defaults to three frontline slots")
	_expect_equal(7, FormationStateScript.frontline_slot_count_from_progression(
		["progression.crossroad_secure", "progression.relic_recovered"],
		{
			"progression.crossroad_secure": 5,
			"progression.relic_recovered": 7
		}
	), "progression slot interface can expand to seven slots")
	_expect(formation.set_frontline_slot_count(5)["ok"], "formation can expand to five slots for progression")
	_expect_equal(5, formation.get_frontline_slot_count(), "expanded slot count is retained")
	_expect(formation.apply_progression_slot_unlocks(
		["progression.crossroad_secure"],
		{"progression.crossroad_secure": 3}
	) == 3, "progression slot interface can keep the default size")

	_expect(formation.set_leader(0, "character.iris")["ok"], "first leader can be assigned")
	_expect(formation.set_leader(1, "character.maelle")["ok"], "second leader can be assigned")
	_expect(formation.set_leader(2, "character.ren")["ok"], "third leader can be assigned")

	var frontline_squads: Dictionary = formation.build_frontline_faction_squads()
	if frontline_squads.has("faction.liberation_front"):
		var liberation = frontline_squads["faction.liberation_front"]
		_expect(liberation.member_character_ids.has("character.bram"), "non-leader owned character contributes to faction power")
		_expect_equal(22, liberation.get_at(), "leader AT correction is applied to faction AT")
		_expect_equal(126, liberation.get_hp(), "leader HP correction is applied to faction HP")
	if frontline_squads.has("faction.arcane_union"):
		_expect_equal(14, frontline_squads["faction.arcane_union"].get_at(), "multiple leaders can add faction AT correction")
		_expect_equal(68, frontline_squads["faction.arcane_union"].get_hp(), "multiple leaders can add faction HP correction")

	_expect_equal(194, formation.get_party_hp(), "party HP sums frontline faction HP once per represented faction")
	var skill_ids := formation.get_available_skill_ids()
	_expect_equal(6, skill_ids.size(), "available skills come from the three leaders")
	_expect(skill_ids.has("skill.shield_wall"), "leader skill list includes first leader skill")
	_expect(skill_ids.has("skill.field_medicine"), "leader skill list includes second leader skill")
	_expect(skill_ids.has("skill.surge_control"), "leader skill list includes third leader skill")

	return 1 if not _failures.is_empty() else 0


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_equal(expected, actual, message: String) -> void:
	if expected != actual:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
