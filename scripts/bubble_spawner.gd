extends Node3D

@export var bubble_scene: PackedScene
@export var spawn_interval: float = 1.0
@export var x_range: Vector2 = Vector2(-0.7, 0.7)
@export var y_range: Vector2 = Vector2(-0.4, 0.4)
@export var z_position: float = 0.0
@export var max_spawn_attempts: int = 80
@export var end_sound: AudioStreamPlayer

@export var spawn_scale: float = 0.35
@export var spawn_margin: float = 0.02
@export var collision_margin: float = 0.0
@export var spawn_spacing_seconds: float = 0.08

@export var spawn_samples: int = 80
@export var spawn_pick_top_k: int = 6

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

@export var use_manual_collision_check: bool = true

@onready var main_scene: Node = get_tree().get_current_scene()

var spawn_timer: Timer
var bubbles: Array[Node3D] = []
var spawn_factor_smoothed: float = 1.0
var risk_refresh_accum: float = 0.0

var cached_spawn_radius_world: float = 0.0

var pending_spawns: int = 0
var spawn_in_progress: bool = false
var last_game_over_state: bool = false


func _ready() -> void:
	add_to_group("bubble_spawner")
	var spawners: Array[Node] = get_tree().get_nodes_in_group("bubble_spawner")
	if spawners.size() > 1:
		queue_free()
		return

	pending_spawns = 0
	spawn_in_progress = false
	risk_refresh_accum = 0.0
	spawn_factor_smoothed = 1.0
	bubbles.clear()

	_cached_measure_spawn_radius()

	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(Callable(self, "_on_spawn_timer"))
	spawn_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(spawn_timer)

	last_game_over_state = _is_game_over()
	if not last_game_over_state:
		_request_spawn(1)
		spawn_timer.start()


func _exit_tree() -> void:
	_reset_spawner_state()


func _process(delta: float) -> void:
	var go: bool = _is_game_over()
	if go != last_game_over_state:
		last_game_over_state = go
		if go:
			_reset_spawner_state()
		else:
			_cached_measure_spawn_radius()
			_request_spawn(1)
			if spawn_timer:
				spawn_timer.start()

	if go:
		return

	_cleanup_bubbles()

	if use_manual_collision_check:
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


func _is_game_over() -> bool:
	if main_scene == null:
		return false
	if "game_over" in main_scene:
		return bool(main_scene.game_over)
	return false


func _reset_spawner_state() -> void:
	pending_spawns = 0
	spawn_in_progress = false
	if spawn_timer:
		spawn_timer.stop()


func _on_spawn_timer() -> void:
	if _is_game_over():
		return
	_request_spawn(1)


func _request_spawn(count: int) -> void:
	if _is_game_over():
		return
	pending_spawns += max(count, 0)
	_process_spawn_queue()


func _process_spawn_queue() -> void:
	if spawn_in_progress:
		return
	if pending_spawns <= 0:
		return
	if _is_game_over():
		pending_spawns = 0
		return

	spawn_in_progress = true
	call_deferred("_spawn_queue_run")


func _spawn_queue_run() -> void:
	while pending_spawns > 0 and not _is_game_over():
		pending_spawns -= 1
		await _spawn_one_bubble()

		var t: float = max(spawn_spacing_seconds, 0.0)
		if t > 0.0:
			await get_tree().create_timer(t, false).timeout
		else:
			await get_tree().physics_frame

	spawn_in_progress = false
	if _is_game_over():
		pending_spawns = 0


func _cached_measure_spawn_radius() -> void:
	cached_spawn_radius_world = 0.0
	if bubble_scene == null:
		return

	var tmp: Node3D = bubble_scene.instantiate() as Node3D
	add_child(tmp)

	if tmp.has_method("set_collision_enabled"):
		tmp.call("set_collision_enabled", false)

	tmp.scale = Vector3.ONE * spawn_scale
	tmp.global_position = global_position
	tmp.force_update_transform()

	if tmp.has_method("get_world_radius"):
		cached_spawn_radius_world = float(tmp.call("get_world_radius"))

	tmp.queue_free()

	if cached_spawn_radius_world <= 0.0:
		cached_spawn_radius_world = 0.5 * spawn_scale


func _get_difficulty_multiplier() -> float:
	if main_scene == null:
		return 1.0
	if not main_scene.has_method("get_difficulty_factor"):
		return 1.0
	return max(float(main_scene.get_difficulty_factor()), 0.0)


func _enforce_quota() -> void:
	if _is_game_over():
		return
	if main_scene == null:
		return
	if not main_scene.has_method("get_difficulty_factor"):
		return

	var diff_mult: float = _get_difficulty_multiplier()
	var doublings: int = int(floor(log(max(diff_mult, 1.0)) / log(2.0)))

	var q: int = quota_base + doublings * quota_per_doubling
	if quota_max > 0:
		q = min(q, quota_max)

	var have_total: int = bubbles.size() + pending_spawns
	var missing_total: int = q - have_total
	if missing_total <= 0:
		return

	var burst: int = min(missing_total, max(quota_spawn_burst_limit, 1))
	_request_spawn(burst)


func _update_bubble_load_factor() -> void:
	if main_scene == null:
		return
	if not main_scene.has_method("set_bubble_load_factor"):
		return
	if _is_game_over():
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
	if _is_game_over():
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
	if _is_game_over():
		return
	var diff_mult: float = _get_difficulty_multiplier()
	for b: Node3D in bubbles:
		if b and not b.is_queued_for_deletion() and b.has_method("set_grow_multiplier"):
			b.set_grow_multiplier(diff_mult)


func _apply_difficulty_to_score() -> void:
	if _is_game_over():
		return
	var diff_mult: float = _get_difficulty_multiplier()
	for b: Node3D in bubbles:
		if b and not b.is_queued_for_deletion() and b.has_method("set_difficulty_multiplier"):
			b.set_difficulty_multiplier(diff_mult)


func _update_risk_realtime() -> void:
	for b: Node3D in bubbles:
		if b and not b.is_queued_for_deletion() and b.has_method("set_risk_multiplier"):
			b.set_risk_multiplier(_compute_risk_multiplier(b))


func _get_radius(b: Node3D) -> float:
	if b and b.has_method("get_world_radius"):
		return float(b.call("get_world_radius"))
	return 0.0


func _random_position() -> Vector3:
	return Vector3(
		randf_range(x_range.x, x_range.y),
		randf_range(y_range.x, y_range.y),
		z_position
	)


func _score_candidate(p_global: Vector3, new_r: float) -> float:
	if bubbles.is_empty():
		return 9999.0

	var best: float = INF
	for b: Node3D in bubbles:
		if b and not b.is_queued_for_deletion():
			var rb: float = _get_radius(b)
			var d: float = p_global.distance_to(b.global_position)
			var margin: float = d - (rb + new_r + spawn_margin)
			best = min(best, margin)

	return best if best != INF else 9999.0


func _pick_spawn_candidate_global() -> Vector3:
	var new_r: float = max(cached_spawn_radius_world, 0.0001)

	var k: int = max(spawn_pick_top_k, 1)
	var top_pts: PackedVector3Array = PackedVector3Array()
	var top_scores: PackedFloat32Array = PackedFloat32Array()

	var n: int = max(spawn_samples, 1)
	for _i: int in range(n):
		var p: Vector3 = global_transform * _random_position()
		var s: float = _score_candidate(p, new_r)
		if s <= 0.0:
			continue

		if top_pts.size() < k:
			top_pts.append(p)
			top_scores.append(s)
		else:
			var worst_i: int = 0
			for j: int in range(top_scores.size()):
				if top_scores[j] < top_scores[worst_i]:
					worst_i = j
			if s > top_scores[worst_i]:
				top_pts[worst_i] = p
				top_scores[worst_i] = s

	if top_pts.size() == 0:
		return Vector3.INF

	var idx: int = randi() % top_pts.size()
	return top_pts[idx]


func _can_place_with_radius(spawn_global: Vector3, new_radius: float) -> bool:
	for b: Node3D in bubbles:
		if b and not b.is_queued_for_deletion():
			var rb: float = _get_radius(b)
			var d: float = spawn_global.distance_to(b.global_position)
			if d < (new_radius + rb + spawn_margin):
				return false
	return true


func _spawn_one_bubble() -> void:
	if _is_game_over():
		return

	_cleanup_bubbles()

	for _attempt: int in range(max_spawn_attempts):
		var spawn_global: Vector3 = _pick_spawn_candidate_global()
		if spawn_global == Vector3.INF:
			return

		var bubble: Node3D = bubble_scene.instantiate() as Node3D
		add_child(bubble)

		if bubble.has_method("set_collision_enabled"):
			bubble.call("set_collision_enabled", false)

		bubble.scale = Vector3.ONE * spawn_scale
		bubble.global_position = spawn_global
		bubble.force_update_transform()

		var new_radius: float = _get_radius(bubble)
		if new_radius <= 0.0 or not _can_place_with_radius(bubble.global_position, new_radius):
			bubble.queue_free()
			continue

		await get_tree().physics_frame
		if bubble == null or bubble.is_queued_for_deletion() or _is_game_over():
			continue

		bubble.force_update_transform()
		new_radius = _get_radius(bubble)

		if new_radius <= 0.0 or not _can_place_with_radius(bubble.global_position, new_radius):
			bubble.queue_free()
			continue

		if bubble.has_method("set_collision_enabled"):
			bubble.call("set_collision_enabled", true)

		if bubble.has_signal("bubble_destroyed"):
			bubble.connect("bubble_destroyed", Callable(self, "_on_bubble_destroyed"))

		# >>> IMPORTANT : on attend une position
		if bubble.has_signal("collision_detected"):
			bubble.connect("collision_detected", Callable(self, "_on_bubble_collision"))

		bubbles.append(bubble)

		if difficulty_affects_grow and bubble.has_method("set_grow_multiplier"):
			bubble.set_grow_multiplier(_get_difficulty_multiplier())
		if difficulty_affects_score and bubble.has_method("set_difficulty_multiplier"):
			bubble.set_difficulty_multiplier(_get_difficulty_multiplier())
		if risk_enabled and bubble.has_method("set_risk_multiplier"):
			bubble.set_risk_multiplier(_compute_risk_multiplier(bubble))

		return


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
	if bubble == null or bubble.is_queued_for_deletion():
		return 1.0

	var gaps: Array[float] = []
	var radius_a: float = _get_radius(bubble)

	for other: Node3D in bubbles:
		if other == bubble or other == null or other.is_queued_for_deletion():
			continue
		var radius_b: float = _get_radius(other)
		var dist: float = bubble.global_position.distance_to(other.global_position)
		gaps.append(dist - (radius_a + radius_b))

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

	return lerp(1.0, risk_max_multiplier, (sum / float(k)))


# >>> Reçoit une position (depuis Bubble.gd ou depuis le check manuel)
func _on_bubble_collision(pos: Vector3) -> void:
	# Appel “propre” si tu as ajouté trigger_game_over_at dans ton GameManager
	if main_scene and main_scene.has_method("trigger_game_over_at"):
		main_scene.trigger_game_over_at(pos)
	elif main_scene and main_scene.has_method("end_game"):
		main_scene.end_game()

	if end_sound:
		end_sound.play()


func _check_collisions() -> void:
	for i: int in range(bubbles.size()):
		for j: int in range(i + 1, bubbles.size()):
			var a: Node3D = bubbles[i]
			var b: Node3D = bubbles[j]
			if a and b and not a.is_queued_for_deletion() and not b.is_queued_for_deletion():
				var ra: float = _get_radius(a)
				var rb: float = _get_radius(b)
				var dvec: Vector3 = b.global_position - a.global_position
				var d: float = dvec.length()

				if d < (ra + rb + collision_margin):
					# Calcul du point d'impact (même logique que Bubble.gd)
					if d < 0.0001:
						_on_bubble_collision(a.global_position)
						return

					var dir := dvec / d
					var pA := a.global_position + dir * ra
					var pB := b.global_position - dir * rb
					var contact_point := (pA + pB) * 0.5

					_on_bubble_collision(contact_point)
					return
