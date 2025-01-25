extends Node3D

@onready var camera: Camera3D = $Camera3D

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos: Vector2 = event.position
		var from: Vector3 = camera.project_ray_origin(mouse_pos)
		var to: Vector3 = from + camera.project_ray_normal(mouse_pos) * 10000.0

		var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
		
		var result: Dictionary = space_state.intersect_ray(query)
		
		if result:
			var collider = result.collider
			if collider:
				# On appelle une fonction que l'objet doit implémenter
				# pour gérer sa propre logique
				if "on_clicked" in collider:  # vérifie que la méthode existe
					collider.on_clicked(result.position)
