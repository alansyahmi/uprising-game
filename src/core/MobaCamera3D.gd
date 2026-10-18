class_name MobaCamera3D
extends Camera3D

## MOBA-style top-down 3D camera modeled after Mobile Legends and League of Legends.
## Features fixed oblique downward tilt (-50° to -60° pitch), locked yaw,
## smooth target interpolation, and dynamic skill-aim panning.

@export_group("Target Tracking")
## Target node to follow (usually the Player CharacterBody3D).
@export var target: Node3D
## Smoothing follow speed. Higher values track more tightly; lower values provide smoother drift.
@export var follow_speed: float = 9.0
## Fixed 3D camera offset from the player position.
## Vector3(0, 13.0, 9.5) yields approximately -54° downward pitch along the X-axis facing forward (-Z).
@export var camera_offset: Vector3 = Vector3(0.0, 13.0, 9.5)
## Focus offset added to target position (offsets the look-at point slightly ahead of the hero).
@export var focus_offset: Vector3 = Vector3(0.0, 0.9, -1.2)

@export_group("Skill Aim Panning")
## Enables skill aiming to nudge/pan camera in direction of targeted skill (like MLBB skill cast).
@export var enable_skill_panning: bool = true
## Maximum distance (in meters) the camera can pan away while aiming skills.
@export var max_skill_aim_pan: float = 4.5
## Responsiveness when transitioning in and out of skill aiming.
@export var aim_pan_speed: float = 8.0

@export_group("Screen Shake (Trauma)")
@export var trauma_decay: float = 2.5
@export var max_shake_offset: float = 0.5

# Runtime internal state
var _current_aim_offset: Vector3 = Vector3.ZERO
var _target_aim_offset: Vector3 = Vector3.ZERO
var _fixed_rotation: Vector3 = Vector3.ZERO
var _trauma: float = 0.0
var _noise_time: float = 0.0

func _ready() -> void:
	# Ensure the camera is decoupled from player hierarchy (should be independent in scene)
	top_level = true
	
	# Compute and lock the fixed oblique downward tilt looking forward along -Z
	_initialize_locked_orientation()
	
	if target:
		global_position = target.global_position + camera_offset

func _initialize_locked_orientation() -> void:
	# Position temporary transform at offset looking at focus_offset
	look_at_from_position(camera_offset, focus_offset, Vector3.UP)
	# Lock this exact rotation (Pitch ~ -54°, Yaw = 0°, Roll = 0°)
	_fixed_rotation = rotation

func _process(delta: float) -> void:
	if not target:
		return
	
	# Smoothly interpolate dynamic skill aim pan offset
	_current_aim_offset = _current_aim_offset.lerp(_target_aim_offset, aim_pan_speed * delta)
	
	# Desired position = player position + static MOBA offset + dynamic skill aim pan
	var desired_position = target.global_position + camera_offset + _current_aim_offset
	
	# Framerate-independent exponential smoothing
	var follow_factor: float = 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(desired_position, follow_factor)
	
	# Enforce strictly locked top-down pitch and yaw rotation (no unwanted camera spins)
	rotation = _fixed_rotation
	
	# Handle screen shake trauma
	_process_screen_shake(delta)

## Nudge camera view in aiming direction when targeting skills / abilities
func set_skill_aim_offset(aim_direction: Vector3, strength: float = 1.0) -> void:
	if not enable_skill_panning:
		return
	var flat_dir = Vector3(aim_direction.x, 0.0, aim_direction.z).normalized()
	_target_aim_offset = flat_dir * clampf(strength, 0.0, 1.0) * max_skill_aim_pan

## Reset skill pan back to centered hero view
func clear_skill_aim_offset() -> void:
	_target_aim_offset = Vector3.ZERO

## Add trauma for screen shake effects
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func _process_screen_shake(delta: float) -> void:
	if _trauma > 0.0:
		_noise_time += delta * 45.0
		var shake_amount = _trauma * _trauma
		h_offset = sin(_noise_time) * max_shake_offset * shake_amount
		v_offset = cos(_noise_time * 1.3) * max_shake_offset * shake_amount
		_trauma = maxf(0.0, _trauma - trauma_decay * delta)
	else:
		h_offset = 0.0
		v_offset = 0.0
