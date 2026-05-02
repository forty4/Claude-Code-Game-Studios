## hp_status_controller.gd
## Battle-scoped HP/Status controller — owns per-unit current_hp + status_effects state.
## Created by Battle Preparation at battle-init (one instance per battle); freed
## automatically with BattleScene per ADR-0002 lifecycle. NOT an autoload.
##
## Signal emitted: GameBus.unit_died(unit_id: int) — sole HP/Status-domain signal per ADR-0001 §7.
## Signal consumed: GameBus.unit_turn_started(unit_id: int) — DoT tick + duration decrement
##   (subscription wired in story-006 _ready() body per ADR-0010 §11).
##
## Public API: 8 methods (initialize_unit, apply_damage, apply_heal, apply_status,
##   get_current_hp, get_max_hp, is_alive, get_modified_stat, get_status_effects).
## Test seam: _apply_turn_start_tick (direct dispatch without GameBus subscription).
##
## Instance field count: exactly 2 per ADR-0010 §2 guardrail.
## Method bodies: 7 implemented by story-002+003+004+005; 4 stubbed for stories 006/007.
##   Story-002 (✅ implemented): initialize_unit + get_current_hp + get_max_hp + is_alive.
##   Story-003 (✅ implemented): apply_damage (F-1 pipeline) + _propagate_demoralized_radius STUB.
##   Story-004 (✅ implemented): apply_heal (F-2 pipeline + EXHAUSTED multiplier + overheal prevention).
##   Story-005 (✅ implemented): apply_status (CR-5c/d/e + CR-7 mutex + .duplicate()).
##   Story-006 implements get_modified_stat + get_status_effects + _apply_turn_start_tick + _ready().
##   Story-007 implements _propagate_demoralized_radius.
class_name HPStatusController
extends Node


# ── Instance Fields (exactly 2 per ADR-0010 §2 guardrail) ────────────────────

## Per-unit HP/status state map. Keyed by unit_id (int, matching ADR-0001 signal contract).
## Populated by initialize_unit at battle-init; read/mutated by all public methods.
var _state_by_unit: Dictionary[int, UnitHPState] = {}

## Map grid reference — injected by Battle Preparation post-new() per ADR-0010 §11 R-3.
## Used by _propagate_demoralized_radius (story-007) for DEMORALIZED radius scan.
## assert(_map_grid != null) guard added at the top of _propagate_demoralized_radius.
var _map_grid: MapGrid


# ── Lifecycle (story-006: GameBus.unit_turn_started subscription) ────────────

func _ready() -> void:
	## ADR-0010 §11 line 444-449. CONNECT_DEFERRED per ADR-0001 §5 (cross-scene re-entrancy).
	GameBus.unit_turn_started.connect(_on_unit_turn_started, Object.CONNECT_DEFERRED)


func _exit_tree() -> void:
	if GameBus.unit_turn_started.is_connected(_on_unit_turn_started):
		GameBus.unit_turn_started.disconnect(_on_unit_turn_started)


func _on_unit_turn_started(unit_id: int) -> void:
	## Thin delegator — keeps the test seam (_apply_turn_start_tick) callable directly.
	_apply_turn_start_tick(unit_id)


# ── Public API (8 methods + 1 test seam — bodies stubbed for story-001) ──────

## Initializes HP state for a unit at battle-start.
## Caches max_hp via UnitRole.get_max_hp(hero, unit_class); creates UnitHPState entry.
## CR-1a initialization: current_hp = max_hp at battle start (after Formation pre-battle buffs).
## Implemented by story-002.
func initialize_unit(unit_id: int, hero: HeroData, unit_class: int) -> void:
	var state := UnitHPState.new()
	state.unit_id = unit_id
	state.max_hp = UnitRole.get_max_hp(hero, unit_class)
	state.current_hp = state.max_hp  # CR-1a: every unit starts at max_hp
	state.status_effects = []  # Array[StatusEffect] — typed empty array
	state.hero = hero
	state.unit_class = unit_class
	_state_by_unit[unit_id] = state


## Applies resolved damage to a unit via the F-1 4-step intake pipeline.
## Called exclusively by Grid Battle on HIT — NEVER by Damage Calc (per ADR-0012 line 260).
## F-1 pipeline: Step 1 (SHIELD_WALL_FLAT passive reduction) → Step 2 (status modifier:
##   DEFEND_STANCE -50% / VULNERABLE +%) → Step 3 (MIN_DAMAGE=1 floor) → Step 4 (HP reduction;
##   emits GameBus.unit_died if current_hp reaches 0).
## attack_type: PHYSICAL=0, MAGICAL=1 per ADR-0012 §C CR-1.
## source_flags: Array of StringName passive tags from the attacker (e.g., [&"passive_shield_wall"]).
## Implemented by story-003.
func apply_damage(unit_id: int, resolved_damage: int, attack_type: int, source_flags: Array) -> void:
	var state: UnitHPState = _state_by_unit.get(unit_id)
	if state == null or state.current_hp == 0:
		push_warning("apply_damage on dead/unknown unit_id %d" % unit_id)
		return

	# F-1 Step 1: Passive flat reduction (PHYSICAL + Shield Wall only)
	const PHYSICAL: int = 0  # local const matches ADR-0012 §C CR-1 attack_type enum
	var post_passive: int
	# NOTE: PASSIVE_TAG_BY_CLASS maps UnitClass → single StringName (not Array);
	# equality check (==) is correct here — ADR pseudocode `in` operator is a prose
	# approximation; the actual Dictionary structure requires == for exact match.
	if attack_type == PHYSICAL and UnitRole.PASSIVE_TAG_BY_CLASS[state.unit_class] == &"passive_shield_wall":
		post_passive = resolved_damage - (BalanceConstants.get_const("SHIELD_WALL_FLAT") as int)
	else:
		post_passive = resolved_damage

	# F-1 Step 2: Status modifier (DEFEND_STANCE first per EC-03 bind-order rule)
	# NOTE per /architecture-review delta-#7 godot-specialist Item 9 (corrected same-patch):
	# `floor()` returns float in GDScript 4.x — explicit `int(...)` cast eliminates editor SAFE-mode
	# implicit-coercion warning at the assignment site `post_passive: int = ...`. The `100.0`
	# literal forces float division (Variant `100` could otherwise yield integer division).
	for effect: StatusEffect in state.status_effects:
		if effect.effect_id == &"defend_stance":
			post_passive = int(floor(post_passive * (1.0 - (BalanceConstants.get_const("DEFEND_STANCE_REDUCTION") as float) / 100.0)))
	# NOTE: VULNERABLE post-MVP — story-003 does NOT implement; ADR-0010 §6 line 256-258 documents future hook

	# F-1 Step 3: MIN_DAMAGE floor (dual-enforced; Damage Calc enforces same value upstream)
	var final_damage: int = maxi(BalanceConstants.get_const("MIN_DAMAGE") as int, post_passive)

	# F-1 Step 4: HP reduction + death emission
	state.current_hp = maxi(0, state.current_hp - final_damage)
	if state.current_hp == 0:
		GameBus.unit_died.emit(unit_id)  # AFTER mutation per Verification §5
		# CR-8c: Commander class auto-trigger DEMORALIZED radius (story-007 fills body)
		if state.unit_class == UnitRole.UnitClass.COMMANDER:
			_propagate_demoralized_radius(state)


## Applies healing to a unit via the F-2 4-step pipeline.
## F-2 pipeline: Step 1 (raw_heal computed by caller) → Step 2 (EXHAUSTED multiplier
##   raw_heal × EXHAUSTED_HEAL_MULT clamped to ≥1) → Step 3 (overheal prevention
##   min(raw_heal, max_hp - current_hp)) → Step 4 (current_hp += heal_amount).
## Returns: actual heal_amount applied (0 if dead/unknown per CR-4b; 0 if full-HP per EC-09;
##   else the integer amount of HP restored, ≥1 if alive and not full-HP).
## raw_heal: integer pre-multiplier heal value computed by caller (skill/item formula).
## source_unit_id: attacker/skill-source unit_id; preserved for forward-compat
##   (future healing-received attribution) — NOT consumed by F-2 pipeline in MVP.
## Implemented (story-004).
func apply_heal(unit_id: int, raw_heal: int, source_unit_id: int) -> int:
	var state: UnitHPState = _state_by_unit.get(unit_id)
	if state == null or state.current_hp == 0:
		return 0  # CR-4b: dead/unknown units cannot be healed

	# F-2 Step 1: raw_heal already computed by caller (skill/item formula)
	# F-2 Step 2: EXHAUSTED multiplier (CR-4 Step 2 — int cast per delta-#7 Item 9)
	if _has_status(state, &"exhausted"):
		raw_heal = int(max(1, floor(raw_heal * (BalanceConstants.get_const("EXHAUSTED_HEAL_MULT") as float))))

	# F-2 Step 3: Overheal prevention (CR-4a — no spillover beyond max_hp)
	var heal_amount: int = mini(raw_heal, state.max_hp - state.current_hp)

	# F-2 Step 4: HP increase
	state.current_hp += heal_amount

	return heal_amount  # caller inspects for UI feedback (skip 'healed for 0' on full-HP per EC-09)


## Applies a status effect to a unit by loading the template .tres and duplicating it.
## Returns true if the effect was applied; false if rejected (CR-7 mutual exclusion,
## DEFEND_STANCE-while-EXHAUSTED blocked, or unit is dead).
## CR-5c: same effect_id on an active effect refreshes remaining_turns (no duplicate stack).
## CR-5d: different effect_ids co-exist up to MAX_STATUS_EFFECTS_PER_UNIT=3.
## CR-5e: oldest effect evicted when slot limit reached.
## duration_override: -1 means use the template's remaining_turns default.
## Implemented (story-005).
func apply_status(unit_id: int, effect_template_id: StringName, duration_override: int, source_unit_id: int) -> bool:
	var state: UnitHPState = _state_by_unit.get(unit_id)
	if state == null or state.current_hp == 0:
		return false

	# CR-7 mutex: EXHAUSTED active → DEFEND_STANCE attempt rejected
	if effect_template_id == &"defend_stance" and _has_status(state, &"exhausted"):
		return false  # caller surfaces "피로로 태세 유지 불가" UI feedback per AC-15

	# CR-7 mutex: DEFEND_STANCE active → EXHAUSTED apply force-removes DEFEND_STANCE first
	if effect_template_id == &"exhausted" and _has_status(state, &"defend_stance"):
		_force_remove_status(state, &"defend_stance")  # AC-16 + EC-13

	# CR-5c: same effect_id refresh (no stack)
	var existing: StatusEffect = _find_status(state, effect_template_id)
	if existing != null:
		existing.remaining_turns = duration_override if duration_override >= 0 else _template_default_duration(effect_template_id)
		existing.source_unit_id = source_unit_id  # update source for DEMORALIZED recovery proximity
		return true

	# CR-5e: max slots check + oldest-first eviction (Array preserves insertion order)
	var max_slots: int = BalanceConstants.get_const("MAX_STATUS_EFFECTS_PER_UNIT") as int
	if state.status_effects.size() >= max_slots:
		state.status_effects.pop_front()  # evict oldest (insertion-order)

	# Apply: load template + duplicate + inject overrides
	var template: StatusEffect = load("res://assets/data/status_effects/%s.tres" % effect_template_id) as StatusEffect
	if template == null:
		push_error("apply_status: unknown effect template %s" % effect_template_id)
		return false
	# SHALLOW duplicate intentional per ADR-0010 §4 hot-reload note + delta-#7 Item 2 PASS:
	# tick_effect: TickEffect is read-only post-load; sharing the Resource reference
	# between template and instance is correct (matches read-only sub-Resource pattern).
	# Editor-mode hot-reload of .tres values reflects live in all currently-applied
	# StatusEffect instances via shared TickEffect reference — intentional for designer iteration.
	# Production builds unaffected (no hot-reload in shipped binaries).
	var instance: StatusEffect = template.duplicate()  # NOT duplicate_deep()
	instance.remaining_turns = duration_override if duration_override >= 0 else template.remaining_turns
	instance.source_unit_id = source_unit_id
	state.status_effects.append(instance)
	return true


## Returns the unit's current HP. Returns 0 for unknown unit_id.
## Implemented by story-002.
func get_current_hp(unit_id: int) -> int:
	if not _state_by_unit.has(unit_id):
		push_warning("get_current_hp: unknown unit_id %d" % unit_id)
		return 0
	return _state_by_unit[unit_id].current_hp


## Returns the unit's maximum HP (cached at battle-init). Returns 0 for unknown unit_id.
## Implemented by story-002.
func get_max_hp(unit_id: int) -> int:
	if not _state_by_unit.has(unit_id):
		push_warning("get_max_hp: unknown unit_id %d" % unit_id)
		return 0
	return _state_by_unit[unit_id].max_hp


## Returns true if the unit is alive (current_hp > 0). Returns false for unknown unit_id.
## Implemented by story-002.
func is_alive(unit_id: int) -> bool:
	if not _state_by_unit.has(unit_id):
		return false  # NO push_warning — is_alive is the canonical guard query; warning would log on every safe-call check
	return _state_by_unit[unit_id].current_hp > 0


## Returns the unit's effective stat value after all active modifier_targets are applied.
## F-4 formula: total_modifier = clamp(sum(modifier_i), MODIFIER_FLOOR, MODIFIER_CEILING)
##   modified_stat = max(1, floor(base_stat * (1 + total_modifier / 100)))
## stat_name: StringName key matching UnitRole accessor names (e.g., &"atk", &"effective_move_range").
## Returns 0 for unknown unit_id or unknown stat_name.
## EXHAUSTED special-case: effective_move_range gets flat -1 after F-4 (not percent).
## Implemented by story-006.
func get_modified_stat(unit_id: int, stat_name: StringName) -> int:
	var state: UnitHPState = _state_by_unit.get(unit_id)
	if state == null:
		return 0

	# Get base stat from UnitRole accessors per stat_name dispatch
	var base_stat: int
	match stat_name:
		&"atk":
			base_stat = UnitRole.get_atk(state.hero, state.unit_class)
		&"phys_def":
			base_stat = UnitRole.get_phys_def(state.hero, state.unit_class)
		&"mag_def":
			base_stat = UnitRole.get_mag_def(state.hero, state.unit_class)
		&"initiative":
			base_stat = UnitRole.get_initiative(state.hero, state.unit_class)
		&"effective_move_range":
			base_stat = UnitRole.get_effective_move_range(state.hero, state.unit_class)
		_:
			push_error("get_modified_stat: unknown stat_name %s" % stat_name)
			return 0

	# F-4: Sum modifier_targets[stat_name] across active effects
	var total_modifier: int = 0
	for effect: StatusEffect in state.status_effects:
		if stat_name in effect.modifier_targets:
			total_modifier += effect.modifier_targets[stat_name] as int

	# Clamp to [MODIFIER_FLOOR, MODIFIER_CEILING] per CR-5f
	total_modifier = clamp(
		total_modifier,
		BalanceConstants.get_const("MODIFIER_FLOOR") as int,
		BalanceConstants.get_const("MODIFIER_CEILING") as int
	)

	# Apply: max(1, int(floor(base × (1 + total_modifier / 100.0))))
	# Explicit int(floor(...)) per /architecture-review delta-#7 Item 9.
	var result: int = max(1, int(floor(base_stat * (1 + total_modifier / 100.0))))

	# EXHAUSTED move-range special-case branch (flat -1, not percent — per ADR-0010 §9 note)
	if stat_name == &"effective_move_range" and _has_status(state, &"exhausted"):
		result -= BalanceConstants.get_const("EXHAUSTED_MOVE_REDUCTION") as int
		result = max(1, result)

	return result


## Returns a shallow copy of the unit's active status effects array.
## Returns empty Array for unknown unit_id or unit with no active effects.
## Shallow copy prevents accidental Array.append() on the authoritative array;
## element-level mutation is forbidden by convention (story-008 lint enforces R-5).
## Implemented by story-006.
func get_status_effects(unit_id: int) -> Array:
	var state: UnitHPState = _state_by_unit.get(unit_id)
	if state == null:
		return []
	return state.status_effects.duplicate()  # shallow copy; StatusEffect refs shared (R-5)


# ── Test Seam ─────────────────────────────────────────────────────────────────

## Test seam: direct DoT tick + duration decrement dispatch without GameBus subscription.
## Production path: called via GameBus.unit_turn_started signal handler (story-006 wires _ready()).
## Test path: called directly to bypass signal infrastructure, exercising the tick logic
## in isolation per ADR-0010 §Verification R-5 + ADR-0005 §Alt 4 DI-seam precedent.
## Convention: underscore prefix marks test-seam methods; production callers forbidden.
## Implemented by story-006.
func _apply_turn_start_tick(unit_id: int) -> void:
	var state: UnitHPState = _state_by_unit.get(unit_id)
	if state == null or state.current_hp == 0:
		return

	# F-3 DoT tick (BEFORE duration decrement — so DoT fires once on the expiry turn)
	# Per ADR-0010 §8 lines 334-365: DoT ticks first, then duration decrements.
	for effect: StatusEffect in state.status_effects:
		if effect.tick_effect != null and effect.tick_effect.damage_type == 0:  # 0 = TRUE_DAMAGE
			var dot: int = clamp(
				int(floor(state.max_hp * effect.tick_effect.dot_hp_ratio)) + effect.tick_effect.dot_flat,
				effect.tick_effect.dot_min,
				effect.tick_effect.dot_max_per_turn
			)
			state.current_hp = max(0, state.current_hp - dot)  # bypasses F-1 intake (true damage)
			if state.current_hp == 0:
				GameBus.unit_died.emit(unit_id)  # POISON-killed unit per EC-06
				# CR-8c R-6 dual-invocation: DoT-killed Commander triggers DEMORALIZED radius
				if state.unit_class == UnitRole.UnitClass.COMMANDER:
					_propagate_demoralized_radius(state)
				return  # don't process further effects on dead unit

	# CR-5: TURN_BASED duration decrement + expiry (reverse-index for safe in-place removal)
	# Per delta-#7 Item 7: forward iteration with remove_at skips elements — use reverse.
	var i: int = state.status_effects.size() - 1
	while i >= 0:
		var effect: StatusEffect = state.status_effects[i]
		if effect.duration_type == 0:  # 0 = TURN_BASED
			effect.remaining_turns -= 1
			if effect.remaining_turns <= 0:
				state.status_effects.remove_at(i)  # expire
		elif effect.duration_type == 2 and effect.effect_id == &"defend_stance":
			# 2 = ACTION_LOCKED; SE-3: 1-turn DEFEND_STANCE expiry per CR-13 grid-battle.md
			state.status_effects.remove_at(i)
		i -= 1

	# CR-6 SE-2: DEMORALIZED CONDITION_BASED recovery check (ally hero ≤ DEMORALIZED_RECOVERY_RADIUS tiles)
	var demoralized: StatusEffect = _find_status(state, &"demoralized")
	if demoralized != null and _has_ally_hero_within_radius(state, BalanceConstants.get_const("DEMORALIZED_RECOVERY_RADIUS") as int):
		_force_remove_status(state, &"demoralized")


# ── Private Helpers — story-007 (_propagate_demoralized_radius) ──────────────

## Propagates DEMORALIZED to all living allies within DEMORALIZED_RADIUS of the commander.
## Called from apply_damage Step 4 (CR-8c) AND _apply_turn_start_tick DoT-kill branch (R-6).
## CR-5c refresh handles already-DEMORALIZED allies per EC-17 (no double penalty).
## Implements ADR-0010 §11 + R-6 dual-invocation. Story-007.
func _propagate_demoralized_radius(commander_state: UnitHPState) -> void:
	assert(_map_grid != null, "HPStatusController._map_grid must be injected by Battle Preparation")
	var radius: int = BalanceConstants.get_const("DEMORALIZED_RADIUS") as int
	var duration: int = BalanceConstants.get_const("DEMORALIZED_DEFAULT_DURATION") as int
	var commander_coord: Vector2i = _get_unit_coord(commander_state.unit_id)

	# Snapshot iteration per delta-#7 Item 6 PASS — Array returned by keys() is independent
	# of Dictionary mutations (apply_status appends to status_effects, not the keys set).
	for unit_id: int in _state_by_unit.keys():
		if unit_id == commander_state.unit_id:
			continue  # commander itself excluded from propagation
		var state: UnitHPState = _state_by_unit[unit_id]
		if state.current_hp == 0:
			continue  # dead allies excluded per ADR-0010 §11 line 428-429
		if not _is_ally(commander_state, state):
			continue  # non-ally faction excluded
		# is_morale_anchor branch DEFERRED post-MVP per OQ-2 — HeroData 26-field schema does NOT
		# include the morale-anchor field (verified 2026-04-30 grep zero-match). MVP triggers
		# ONLY via condition (a) Commander class + condition (c) direct skill apply.
		# Future post-MVP migration adds a morale-anchor branch reading the hero record.
		# See ADR-0010 §ADR Dependencies Soft / Provisional (2) for migration path.
		var coord: Vector2i = _get_unit_coord(unit_id)
		if _manhattan_distance(commander_coord, coord) <= radius:
			apply_status(unit_id, &"demoralized", duration, commander_state.unit_id)
			# CR-5c refresh handles already-DEMORALIZED units per EC-17 (no double penalty)


# ── Private helpers — story-005 ──────────────────────────────────────────────

## Returns true if the unit's status_effects Array contains any effect with the given effect_id.
## Used by apply_status CR-7 mutex enforcement and apply_heal F-2 EXHAUSTED multiplier (story-004 if shipped uses this).
func _has_status(state: UnitHPState, effect_id: StringName) -> bool:
	for effect: StatusEffect in state.status_effects:
		if effect.effect_id == effect_id:
			return true
	return false


## Returns the first StatusEffect in state.status_effects matching effect_id, or null if absent.
## Used by apply_status CR-5c same-effect refresh path.
func _find_status(state: UnitHPState, effect_id: StringName) -> StatusEffect:
	for effect: StatusEffect in state.status_effects:
		if effect.effect_id == effect_id:
			return effect
	return null


## Removes ALL StatusEffect instances matching effect_id from state.status_effects.
## Reverse-index iteration per delta-#7 Item 7 PASS (forward iteration with remove_at would skip elements).
## Used by apply_status CR-7 force-release for DEFEND_STANCE → EXHAUSTED transition.
## Story-006 reuses this helper for ACTION_LOCKED expiry pattern.
func _force_remove_status(state: UnitHPState, effect_id: StringName) -> void:
	var i: int = state.status_effects.size() - 1
	while i >= 0:
		if state.status_effects[i].effect_id == effect_id:
			state.status_effects.remove_at(i)
			# Continue iterating in case duplicates exist (defensive — should not happen per CR-5c refresh contract)
		i -= 1


## Loads the .tres template for effect_template_id and returns its remaining_turns default.
## Used by apply_status CR-5c refresh path when duration_override == -1.
## Defense-in-depth: returns 0 if template load fails (caller already failed via load null-check).
## NOTE: redundant load() vs the apply path; story-008 may optimize via cached template references — Polish-tier opportunity.
func _template_default_duration(effect_template_id: StringName) -> int:
	var template: StatusEffect = load("res://assets/data/status_effects/%s.tres" % effect_template_id) as StatusEffect
	if template == null:
		return 0
	return template.remaining_turns


# ── Private helpers — story-006 (turn-start tick + F-4) ──────────────────────

## Returns true if any ally hero (Commander class or named hero) is within manhattan
## distance ≤ radius tiles of the given state's unit.
## Uses _map_grid DI (asserted non-null). Tests inject MapGridStub with controlled
## occupant_id values per ADR-0010 §11 R-3 + §13 DI test seam.
## Story-007 may refine the ally definition once HeroData.is_morale_anchor lands per OQ-2.
func _has_ally_hero_within_radius(state: UnitHPState, radius: int) -> bool:
	assert(_map_grid != null, "HPStatusController._map_grid must be injected by Battle Preparation")
	var unit_coord: Vector2i = _get_unit_coord(state.unit_id)
	if unit_coord == Vector2i(-1, -1):
		return false
	for other_unit_id: int in _state_by_unit.keys():
		if other_unit_id == state.unit_id:
			continue
		var other_state: UnitHPState = _state_by_unit[other_unit_id]
		if other_state.current_hp == 0:
			continue
		if not _is_ally(state, other_state):
			continue
		if (other_state.unit_class == UnitRole.UnitClass.COMMANDER) or _is_hero(other_state):
			var other_coord: Vector2i = _get_unit_coord(other_unit_id)
			if other_coord == Vector2i(-1, -1):
				continue
			if _manhattan_distance(unit_coord, other_coord) <= radius:
				return true
	return false


## Returns the (col, row) coord of unit_id on the MapGrid, or (-1, -1) if not found.
## MVP O(N) scan — coord_to_unit reverse cache deferred to story-008 Polish-tier TD entry.
func _get_unit_coord(unit_id: int) -> Vector2i:
	var dims: Vector2i = _map_grid.get_map_dimensions()
	for x: int in range(dims.x):
		for y: int in range(dims.y):
			var coord := Vector2i(x, y)
			var tile: MapTileData = _map_grid.get_tile(coord)
			if tile != null and tile.occupant_id == unit_id:
				return coord
	return Vector2i(-1, -1)  # not found — defense-in-depth


## Returns true if both states' heroes are non-null and share faction.
## MVP uses real HeroData.faction field (confirmed at src/foundation/hero_data.gd:40).
func _is_ally(state_a: UnitHPState, state_b: UnitHPState) -> bool:
	if state_a.hero == null or state_b.hero == null:
		return false
	return state_a.hero.faction == state_b.hero.faction


## Returns true if the state has a non-null hero with a non-empty Korean name (named hero).
## Approximates "morale anchor" pending HeroData.is_morale_anchor field (post-MVP per OQ-2).
## Uses name_ko as the canonical "has a name" check (empty string = generic Soldier unit).
func _is_hero(state: UnitHPState) -> bool:
	return state.hero != null and state.hero.name_ko != ""


## Manhattan distance between two grid coords. Pure math — no allocations.
func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
