extends StaticBody3D

signal clicked(impact_pos: Vector3)

func _input_event(camera: Camera3D, event: InputEvent, click_position: Vector3, click_normal: Vector3, shape_idx: int) -> void:
	if event.is_pressed():
		print("Signal 'clicked' emitted at position: ", click_position)
		emit_signal("clicked", click_position)
