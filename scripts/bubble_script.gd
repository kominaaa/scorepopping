extends Node3D

signal bubble_destroyed(bubble: Node3D)
signal collision_detected

@export var scale_rate: float = 1.0
@export var max_scale: float = 20.0
@export var min_value: int = 1
@export var max_value: int = 999
@export var gradient_texture: GradientTexture1D
@export var label_3d: Label3D
@export var bubble_mesh: MeshInstance3D
@export var explosion_scene: PackedScene
@export var area: Area3D
@export var collision_shape: CollisionShape3D

func _ready():
	scale = Vector3(1, 1, 1)
	set_process(true)

	# Connecter les signaux
	if area:
		area.area_entered.connect(Callable(self, "_on_area_entered"))
		area.input_event.connect(Callable(self, "_on_input_event"))

func _process(delta):
	# Augmenter la taille de la bulle
	if scale.x < max_scale:
		var new_scale = scale + Vector3(scale_rate, scale_rate, scale_rate) * delta
		if new_scale.x > max_scale:
			new_scale = Vector3(max_scale, max_scale, max_scale)
		scale = new_scale

		# Mettre à jour l'apparence et les couleurs
		_update_label_and_colors()
	else:
		print("Reached max scale. Stopping process.")
		set_process(false)

func _update_label_and_colors():
	var progress = (scale.x - 1.0) / (max_scale - 1.0)
	label_3d.text = str(round(lerp(float(min_value), float(max_value), progress)))

	var color = gradient_texture.gradient.get_color(progress)
	label_3d.modulate = color

	if bubble_mesh.mesh is SphereMesh:
		var material = bubble_mesh.mesh.material
		if material is ShaderMaterial:
			material.set_shader_parameter("fresnel_color", color)

func _on_area_entered(other_area: Area3D) -> void:
	if other_area.get_parent() != self:
		emit_signal("collision_detected")

func _on_input_event(camera: Camera3D, event: InputEvent, click_position: Vector3, click_normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_bubble_clicked(click_position)

func _on_bubble_clicked(impact_pos: Vector3) -> void:
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		explosion.global_transform.origin = self.global_transform.origin
		get_tree().current_scene.add_child(explosion)

	if area:
		area.area_entered.disconnect(Callable(self, "_on_area_entered"))
		area.input_event.disconnect(Callable(self, "_on_input_event"))

	emit_signal("bubble_destroyed", self)
	queue_free()
