class_name IsoCamera3D
extends Camera3D

@export var target: Node3D
@export var follow_speed: float = 8.0
@export var mouse_lead_factor: float = 0.2
@export var max_mouse_lead: float = 3.5

# Base offset for Isometric Hades / Diablo angle:
# Raised up and back along Z, tilted down ~50 degrees
@export var camera_offset: Vector3 = Vector3(0.0, 15.0, 12.0)

var trauma: float = 0.0
var trauma_decay: float = 2.5
var max_shake_offset: float = 0.6
var noise_time: float = 0.0

func _ready() -> void:
	# Look toward target offset
	look_at_from_position(camera_offset, Vector3.ZERO, Vector3.UP)
	if HitStopManager:
		HitStopManager.screen_shake_requested.connect(add_trauma)

func add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	if not target:
		return
	
	# Compute mouse ground plane position
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := project_ray_origin(mouse_pos)
	var ray_dir := project_ray_normal(mouse_pos)
	var ground_plane := Plane(Vector3.UP, target.global_position.y)
	var ground_hit = ground_plane.intersects_ray(ray_origin, ray_dir)
	
	var lead_offset := Vector3.ZERO
	if ground_hit:
		var diff = ground_hit - target.global_position
		lead_offset = diff * mouse_lead_factor
		if lead_offset.length() > max_mouse_lead:
			lead_offset = lead_offset.normalized() * max_mouse_lead
	
	var desired_pos = target.global_position + camera_offset + lead_offset
	global_position = global_position.lerp(desired_pos, follow_speed * delta)
	
	# Process screen shake trauma
	if trauma > 0.0:
		noise_time += delta * 45.0
		var shake_amount = trauma * trauma
		h_offset = sin(noise_time) * max_shake_offset * shake_amount
		v_offset = cos(noise_time * 1.3) * max_shake_offset * shake_amount
		trauma = max(0.0, trauma - trauma_decay * delta)
	else:
		h_offset = 0.0
		v_offset = 0.0
