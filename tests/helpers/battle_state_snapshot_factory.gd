## BattleStateSnapshotFactory — synthetic BattleStateSnapshot construction for unit tests.
##
## Provides builder pattern with default-fill of all 7 fields. Covers chapter-1
## archetype scenarios (4 archetypes × varied positions/HP) + edge case fixtures
## (zero-candidates per EC-AI-1 + all-suicidal per EC-AI-2).
class_name BattleStateSnapshotFactory
extends RefCounted


## Constructs a default snapshot with the given enemy + player units.
## Each unit dict needs: unit_id, archetype (StringName), position, hp_current,
## hp_max, atk, def, move_range, attack_range, side, is_player_controlled,
## passive_id (optional), tag (optional), is_alive (default true).
static func make(
		enemies: Array[Dictionary],
		players: Array[Dictionary],
		map_dims: Vector2i = Vector2i(15, 15),
		chokepoints: Array[Vector2i] = [],
) -> BattleStateSnapshot:
	var snap: BattleStateSnapshot = BattleStateSnapshot.new()
	snap.units = []
	for e in enemies:
		var d: Dictionary = e.duplicate(true)
		d["side"] = 1
		d["is_player_controlled"] = false
		if not d.has("is_alive"):
			d["is_alive"] = true
		snap.units.append(d)
	for p in players:
		var d: Dictionary = p.duplicate(true)
		d["side"] = 0
		d["is_player_controlled"] = true
		if not d.has("is_alive"):
			d["is_alive"] = true
		snap.units.append(d)
	snap.map_dimensions = map_dims
	snap.terrain_grid = PackedInt32Array()
	snap.queue_unit_ids = []
	snap.round_number = 1
	snap.chokepoints = chokepoints
	# Centroid of enemy positions for formation_center.
	if not enemies.is_empty():
		var sum: Vector2i = Vector2i.ZERO
		for e in enemies:
			sum += e.get("position", Vector2i.ZERO) as Vector2i
		snap.formation_center = Vector2i(sum.x / enemies.size(), sum.y / enemies.size())
	return snap


## Convenience: makes a unit dict with sensible defaults.
static func unit(
		unit_id: int,
		archetype: StringName,
		position: Vector2i,
		hp_current: int = 100,
		hp_max: int = 100,
		extra: Dictionary = {},
) -> Dictionary:
	var d: Dictionary = {
		"unit_id": unit_id,
		"archetype": archetype,
		"position": position,
		"hp_current": hp_current,
		"hp_max": hp_max,
		"atk": 10,
		"def": 5,
		"move_range": 3,
		"attack_range": 1,
		"is_alive": hp_current > 0,
		"tag": &"",
		"passive_id": &"",
	}
	for k in extra.keys():
		d[k] = extra[k]
	return d
