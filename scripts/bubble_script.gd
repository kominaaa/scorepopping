extends Node3D

signal bubble_destroyed(bubble: Node3D, bubble_base_value: int)
signal collision_detected
signal progress_updated(progress: float)

@export var scale_rate: float = 1.0
@export var max_scale: float = 20.0
@export var min_value: int = 1
@export var max_value: int = 200
@export_range(0.1, 10.0, 0.1) var score_exponent: float = 1.0
@export var label_3d: Label3D
@export var bubble_mesh: MeshInstance3D
@export var explosion_scene: PackedScene
@export var area: Area3D
@export var collision_shape: CollisionShape3D

var current_progress: float = 0.0
var current_base_value: int = 0

var grow_multiplier: float = 1.0
var risk_multiplier: float = 1.0
var difficulty_multiplier: float = 1.0


func _ready() -> void:
	set_process(true)

	if area:
		area.area_entered.connect(Callable(self, "_on_area_entered"))
		area.input_event.connect(Callable(self, "_on_input_event"))


func set_grow_multiplier(m: float) -> void:
	grow_multiplier = max(m, 0.0)


func set_risk_multiplier(m: float) -> void:
	risk_multiplier = max(m, 1.0)
	_update_label_and_value()


func set_difficulty_multiplier(m: float) -> void:
	difficulty_multiplier = max(m, 0.0)
	_update_label_and_value()


func set_collision_enabled(enabled: bool) -> void:
	if area:
		area.monitoring = enabled
		area.monitorable = enabled
	if collision_shape:
		collision_shape.disabled = not enabled


func get_world_radius() -> float:
	if collision_shape and collision_shape.shape is SphereShape3D:
		var sphere: SphereShape3D = collision_shape.shape as SphereShape3D
		var gs: Vector3 = collision_shape.global_transform.basis.get_scale()
		var max_axis: float = max(gs.x, max(gs.y, gs.z))
		return sphere.radius * max_axis

	var g: Vector3 = global_transform.basis.get_scale()
	return 0.5 * max(g.x, max(g.y, g.z))


func _process(delta: float) -> void:
	if scale.x < max_scale:
		var effective_rate: float = scale_rate * grow_multiplier
		var new_scale: Vector3 = scale + Vector3(effective_rate, effective_rate, effective_rate) * delta
		if new_scale.x > max_scale:
			new_scale = Vector3(max_scale, max_scale, max_scale)
		scale = new_scale

		_update_label_and_value()

		if current_base_value >= max_value:
			_pop_bubble()
			return
	else:
		set_process(false)
		_pop_bubble()


func _update_label_and_value() -> void:
	current_progress = clamp((scale.x - 1.0) / (max_scale - 1.0), 0.0, 1.0)
	var curved: float = pow(current_progress, score_exponent)

	var base_value_f: float = lerp(float(min_value), float(max_value), curved)
	current_base_value = int(round(base_value_f))

	emit_signal("progress_updated", current_progress)

	if label_3d:
		var displayed: float = float(current_base_value) * risk_multiplier * difficulty_multiplier
		label_3d.text = str(int(round(displayed)))


func _on_area_entered(other_area: Area3D) -> void:
	if other_area.get_parent() != self:
		emit_signal("collision_detected")


func _on_input_event(camera: Camera3D, event: InputEvent, click_position: Vector3, click_normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_pop_bubble()


func _pop_bubble() -> void:
	if explosion_scene:
		var explosion: Node = explosion_scene.instantiate()
		(explosion as Node3D).global_transform.origin = global_transform.origin
		get_tree().current_scene.add_child(explosion)

		if explosion.has_method("set_progress"):
			explosion.call("set_progress", current_progress)

	if area:
		if area.area_entered.is_connected(Callable(self, "_on_area_entered")):
			area.area_entered.disconnect(Callable(self, "_on_area_entered"))
		if area.input_event.is_connected(Callable(self, "_on_input_event")):
			area.input_event.disconnect(Callable(self, "_on_input_event"))

	emit_signal("bubble_destroyed", self, current_base_value)
	queue_free()
