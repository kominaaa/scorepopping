extends Node3D

@export var bubble_scene: PackedScene
@export var spawn_interval: float = 1.0
@export var x_range: Vector2 = Vector2(-0.7, 0.7)
@export var y_range: Vector2 = Vector2(-0.4, 0.4)
@export var z_position: float = 0.0
@export var min_spawn_distance: float = 0.2
@export var max_spawn_attempts: int = 50
@export var end_sound: AudioStreamPlayer

@export var difficulty_affects_spawn: bool = true
@export var min_spawn_factor_at_high_difficulty: float = 0.55
@export var spawn_smooth: float = 10.0

@export var difficulty_affects_grow: bool = true
@export var difficulty_affects_score: bool = true

@export var bubbles_for_start_slow: int = 2
@export var bubbles_for_max_slow: int = 10
@export var bubble_count_curve: float = 1.8

@export var quota_enabled: bool = true
@export var quota_base: int = 2
@export var quota_per_doubling: int = 1
@export var quota_max: int = 18
@export var quota_spawn_burst_limit: int = 3

@export var risk_enabled: bool = true
@export var risk_neighbors: int = 3
@export var risk_range: float = 0.18
@export var risk_power: float = 2.0
@export var risk_max_multiplier: float = 2.5
@export var risk_refresh_interval: float = 0.10

@onready var main_scene: Node = get_tree().get_current_scene()

var spawn_timer: Timer
var bubbles: Array[Node3D] = []
var spawn_factor_smoothed: float = 1.0
var risk_refresh_accum: float = 0.0


func _ready() -> void:
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(Callable(self, "_spawn_bubble"))
	add_child(spawn_timer)

	_spawn_bubble(true)
	spawn_timer.start()


func _process(delta: float) -> void:
	_cleanup_bubbles()
	_check_collisions()
	_update_bubble_load_factor()

	if quota_enabled:
		_enforce_quota()

	if difficulty_affects_spawn:
		_update_spawn_rate(delta)
	else:
		if spawn_timer:
			spawn_timer.wait_time = spawn_interval

	if difficulty_affects_grow:
		_apply_difficulty_to_grow()

	if difficulty_affects_score:
		_apply_difficulty_to_score()

	if risk_enabled:
		risk_refresh_accum += delta
		if risk_refresh_accum >= max(risk_refresh_interval, 0.001):
			risk_refresh_accum = 0.0
			_update_risk_realtime()


func _get_difficulty_multiplier() -> float:
	if main_scene == null:
		return 1.0
	if not main_scene.has_method("get_difficulty_factor"):
		return 1.0
	return max(float(main_scene.get_difficulty_factor()), 0.0)


func _enforce_quota() -> void:
	if main_scene == null:
		return
	if not main_scene.has_method("get_difficulty_factor"):
		return
	if "game_over" in main_scene and bool(main_scene.game_over):
		return

	var diff_mult: float = _get_difficulty_multiplier()
	var doublings: int = int(floor(log(max(diff_mult, 1.0)) / log(2.0)))

	var q: int = quota_base + doublings * quota_per_doubling
	if quota_max > 0:
		q = min(q, quota_max)

	var missing: int = q - bubbles.size()
	if missing <= 0:
		return

	var burst: int = min(missing, max(quota_spawn_burst_limit, 1))
	for _i: int in range(burst):
		_spawn_bubble(true)


func _update_bubble_load_factor() -> void:
	if main_scene == null:
		return
	if not main_scene.has_method("set_bubble_load_factor"):
		return
	if "game_over" in main_scene and bool(main_scene.game_over):
		return

	var count: int = 0
	for b: Node3D in bubbles:
		if b and not b.is_queued_for_deletion():
			count += 1

	var start: int = max(bubbles_for_start_slow, 0)
	var maxb: int = max(bubbles_for_max_slow, start + 1)

	var raw: float = clamp(float(count - start) / float(maxb - start), 0.0, 1.0)
	var shaped: float = pow(raw, bubble_count_curve)

	main_scene.set_bubble_load_factor(shaped)


func _update_spawn_rate(delta: float) -> void:
	if main_scene == null:
		return
	if not main_scene.has_method("get_difficulty_factor"):
		return
	if spawn_timer == null:
		return
	if "game_over" in main_scene and bool(main_scene.game_over):
		return

	var diff_mult: float = _get_difficulty_multiplier()
	var d01: float = clamp(log(max(diff_mult, 1.0)) / log(2.0), 0.0, 1.0)
	var target_factor: float = lerp(1.0, min_spawn_factor_at_high_difficulty, d01)

	spawn_factor_smoothed = lerp(
		spawn_factor_smoothed,
		target_factor,
		1.0 - exp(-spawn_smooth * delta)
	)

	spawn_timer.wait_time = spawn_interval * spawn_factor_smoothed


func _apply_difficulty_to_grow() -> void:
	if "game_over" in main_scene and bool(main_scene.game_over):
		return

	var diff_mult: float = _get_difficulty_multiplier()

	for b: Node3D in bubbles:
		if b and not b.is_queued_for_deletion() and b.has_method("set_grow_multiplier"):
			b.set_grow_multiplier(diff_mult)


func _apply_difficulty_to_score() -> void:
	if "game_over" in main_scene and bool(main_scene.game_over):
		return

	var diff_mult: float = _get_difficulty_multiplier()

	for b: Node3D in bubbles:
		if b and not b.is_queued_for_deletion() and b.has_method("set_difficulty_multiplier"):
			b.set_difficulty_multiplier(diff_mult)


func _update_risk_realtime() -> void:
	for b: Node3D in bubbles:
		if b and not b.is_queued_for_deletion() and b.has_method("set_risk_multiplier"):
			b.set_risk_multiplier(_compute_risk_multiplier(b))


func _spawn_bubble(at_random: bool = false) -> void:
	_cleanup_bubbles()

	var spawn_pos: Vector3 = Vector3.ZERO
	var spawn_successful: bool = false

	for _i: int in range(max_spawn_attempts):
		if at_random or bubbles.is_empty():
			spawn_pos = _random_position()
		else:
			spawn_pos = _find_farthest_position()

		var valid: bool = true
		for b: Node3D in bubbles:
			if b and not b.is_queued_for_deletion():
				if spawn_pos.distance_to(b.global_transform.origin) < min_spawn_distance:
					valid = false
					break

		if valid:
			spawn_successful = true
			break

	if not spawn_successful:
		return

	var bubble: Node3D = bubble_scene.instantiate()
	bubble.global_transform.origin = spawn_pos
	add_child(bubble)

	if bubble.has_signal("bubble_destroyed"):
		bubble.connect("bubble_destroyed", Callable(self, "_on_bubble_destroyed"))
	if bubble.has_signal("collision_detected"):
		bubble.connect("collision_detected", Callable(self, "_on_bubble_collision"))

	bubbles.append(bubble)

	if difficulty_affects_grow and bubble.has_method("set_grow_multiplier"):
		bubble.set_grow_multiplier(_get_difficulty_multiplier())

	if difficulty_affects_score and bubble.has_method("set_difficulty_multiplier"):
		bubble.set_difficulty_multiplier(_get_difficulty_multiplier())

	if risk_enabled and bubble.has_method("set_risk_multiplier"):
		bubble.set_risk_multiplier(_compute_risk_multiplier(bubble))


func _random_position() -> Vector3:
	var x_pos: float = randf_range(x_range.x, x_range.y)
	var y_pos: float = randf_range(y_range.x, y_range.y)
	return Vector3(x_pos, y_pos, z_position)


func _find_farthest_position() -> Vector3:
	var farthest: Vector3 = Vector3.ZERO
	var best_min_dist: float = -INF

	for _i: int in range(50):
		var candidate: Vector3 = _random_position()
		var min_dist: float = INF

		for b: Node3D in bubbles:
			if b and not b.is_queued_for_deletion():
				min_dist = min(min_dist, candidate.distance_to(b.global_transform.origin))

		if min_dist > best_min_dist:
			best_min_dist = min_dist
			farthest = candidate

	return farthest


func _cleanup_bubbles() -> void:
	var valid: Array[Node3D] = []
	for b: Node3D in bubbles:
		if b and not b.is_queued_for_deletion():
			valid.append(b)
	bubbles = valid


func _on_bubble_destroyed(bubble: Node3D, bubble_base_value: int) -> void:
	if bubble in bubbles:
		bubbles.erase(bubble)

	var final_value_f: float = float(bubble_base_value)

	if risk_enabled:
		final_value_f *= _compute_risk_multiplier(bubble)

	if difficulty_affects_score:
		final_value_f *= _get_difficulty_multiplier()

	var final_value: int = int(round(final_value_f))

	if main_scene and main_scene.has_method("increment_score"):
		main_scene.increment_score(final_value)


func _compute_risk_multiplier(bubble: Node3D) -> float:
	if bubble == null:
		return 1.0
	if bubble.is_queued_for_deletion():
		return 1.0

	var gaps: Array[float] = []
	var radius_a: float = 0.5 * bubble.scale.x

	for other: Node3D in bubbles:
		if other == bubble:
			continue
		if other == null:
			continue
		if other.is_queued_for_deletion():
			continue

		var radius_b: float = 0.5 * other.scale.x
		var dist: float = bubble.global_transform.origin.distance_to(other.global_transform.origin)
		var gap: float = dist - (radius_a + radius_b)
		gaps.append(gap)

	if gaps.is_empty():
		return 1.0

	gaps.sort()

	var k: int = min(max(risk_neighbors, 1), gaps.size())
	var sum: float = 0.0
	var rr: float = max(risk_range, 0.0001)

	for i: int in range(k):
		var g: float = gaps[i]
		var closeness: float = clamp(1.0 - (g / rr), 0.0, 1.0)
		sum += pow(closeness, risk_power)

	var avg: float = sum / float(k)
	return lerp(1.0, risk_max_multiplier, avg)


func _on_bubble_collision() -> void:
	if main_scene and main_scene.has_method("end_game"):
		main_scene.end_game()
	if end_sound:
		end_sound.play()


func _check_collisions() -> void:
	for i: int in range(bubbles.size()):
		for j: int in range(i + 1, bubbles.size()):
			var a: Node3D = bubbles[i]
			var b: Node3D = bubbles[j]

			if a and b and not a.is_queued_for_deletion() and not b.is_queued_for_deletion():
				var d: float = a.global_transform.origin.distance_to(b.global_transform.origin)
				if d < min_spawn_distance:
					_on_bubble_collision()
					return
