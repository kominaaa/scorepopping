extends Control

@export var pop_duration: float = 0.12
@export var overshoot: float = 1.25
@export var start_scale: float = 0.05

var _base_scale: Vector2
var _tween: Tween

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_base_scale = scale

	await get_tree().process_frame
	_update_pivot()

	visibility_changed.connect(_on_visibility_changed)

	if is_visible_in_tree():
		pop()

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		pop()

func _update_pivot() -> void:
	pivot_offset = size * 0.5

func pop() -> void:
	if _tween and _tween.is_running():
		_tween.kill()

	await get_tree().process_frame
	_update_pivot()

	scale = _base_scale * start_scale

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_BACK)
	_tween.set_ease(Tween.EASE_OUT)

	_tween.tween_property(self, "scale", _base_scale * overshoot, pop_duration)
	_tween.tween_property(self, "scale", _base_scale, pop_duration * 0.8)
