extends Node3D

@export var pop_duration: float = 0.12
@export var overshoot: float = 1.25
@export var start_scale: float = 0.05

@export var auto_free: bool = false
@export var life_time: float = 2.0

var _base_scale: Vector3

func _ready() -> void:
	_base_scale = scale

	# Start tout petit (mais pas 0 exact pour éviter certains soucis visuels)
	scale = _base_scale * start_scale

	# Pop: petit -> overshoot -> normal
	var t := create_tween()
	t.set_trans(Tween.TRANS_BACK)
	t.set_ease(Tween.EASE_OUT)

	t.tween_property(self, "scale", _base_scale * overshoot, pop_duration)
	t.tween_property(self, "scale", _base_scale, pop_duration * 0.8)

	# Optionnel: auto-destruction après un délai
	if auto_free:
		var t2 := create_tween()
		t2.tween_interval(max(life_time, 0.0))
		t2.tween_callback(queue_free)
