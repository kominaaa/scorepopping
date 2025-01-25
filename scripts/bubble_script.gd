extends Node3D

signal bubble_destroyed(bubble: Node3D, bubble_value: int)
signal collision_detected
signal progress_updated(progress: float)

@export var scale_rate: float = 1.0
@export var max_scale: float = 20.0
@export var min_value: int = 1
@export var max_value: int = 1000
@export var label_3d: Label3D
@export var bubble_mesh: MeshInstance3D
@export var explosion_scene: PackedScene
@export var area: Area3D
@export var collision_shape: CollisionShape3D

var current_progress: float = 0.0
var current_value: int = 0

func _ready():
	set_process(true)

	if area:
		area.area_entered.connect(Callable(self, "_on_area_entered"))
		area.input_event.connect(Callable(self, "_on_input_event"))

func _process(delta: float):
	if scale.x < max_scale:
		var new_scale = scale + Vector3(scale_rate, scale_rate, scale_rate) * delta
		if new_scale.x > max_scale:
			new_scale = Vector3(max_scale, max_scale, max_scale)
		scale = new_scale

		_update_label_and_colors()

		# Vérifier si on a atteint la valeur max
		if current_value >= max_value:
			_pop_bubble()  # Auto-pop si on a atteint 999
			return
	else:
		# On a déjà la taille max. On peut décider ici aussi de pop la bulle
		set_process(false)
		_pop_bubble()

func _update_label_and_colors():
	current_progress = (scale.x - 1.0) / (max_scale - 2.0)
	current_value = round(lerp(float(min_value), float(max_value), current_progress))

	emit_signal("progress_updated", current_progress)

	label_3d.text = str(current_value)

func _on_area_entered(other_area: Area3D) -> void:
	if other_area.get_parent() != self:
		emit_signal("collision_detected")

func _on_input_event(camera: Camera3D, event: InputEvent, click_position: Vector3, click_normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_bubble_clicked(click_position)

func _on_bubble_clicked(impact_pos: Vector3) -> void:
	_pop_bubble()


func _pop_bubble() -> void:
	# Crée l'explosion
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		explosion.global_transform.origin = global_transform.origin
		get_tree().current_scene.add_child(explosion)

		if explosion.has_method("set_progress"):
			explosion.set_progress(current_progress)

	# Déconnecter les signaux, si nécessaire
	if area:
		if area.area_entered.is_connected(_on_area_entered):
			area.area_entered.disconnect(Callable(self, "_on_area_entered"))
		if area.input_event.is_connected(_on_input_event):
			area.input_event.disconnect(Callable(self, "_on_input_event"))

	# Émettre le signal pour que le Main.gd puisse ajouter les points
	emit_signal("bubble_destroyed", self, current_value)

	# Détruire la bulle
	queue_free()
