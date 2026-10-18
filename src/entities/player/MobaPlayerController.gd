class_name MobaPlayerController
extends CharacterBody3D

## MOBA-style player controller supporting both Point-and-Click ground navigation
## (League of Legends / Dota 2 style) and Direct Directional WASD/joystick movement
## (Mobile Legends / Brawl Stars style), with smooth velocity-aligned character turning.

signal destination_reached()
signal destination_changed(target_pos: Vector3)

@export_group("Movement Stats")
## Base movement speed in meters per second.
@export var move_speed: float = 8.5
## Acceleration rate towards target velocity.
@export var acceleration: float = 45.0
## Deceleration rate when coming to a halt.
@export var friction: float = 35.0
## Turning interpolation speed (smooth model rotation toward movement direction).
@export var rotation_speed: float = 14.0
## Stopping distance threshold for click-to-move arrival.
@export var arrival_tolerance: float = 0.25

@export_group("Input Preferences")
## If true, WASD / joystick movement can be used.
@export var enable_direct_input: bool = true
## If true, right-click (or left-click) ground raycasting can be used.
@export var enable_click_to_move: bool = true
## Mouse button used for click-to-move (MOUSE_BUTTON_RIGHT is standard MOBA; MOUSE_BUTTON_LEFT also supported).
@export var click_mouse_button: MouseButton = MOUSE_BUTTON_RIGHT
## Collision mask used to raycast ground surfaces (Layer 1 is typically Environment / Ground).
@export_flags_3d_physics var ground_collision_mask: int = 1

@export_group("Visuals")
## Child node containing character meshes/visuals to rotate smoothly. If null, rotates the root body.
@export var visual_node: Node3D

# Internal navigation state
var _has_click_target: bool = false
var _click_target_position: Vector3 = Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

func _ready() -> void:
	if visual_node == null and has_node("ModelHolder"):
		visual_node = get_node("ModelHolder")

func _unhandled_input(event: InputEvent) -> void:
	if not enable_click_to_move:
		return
	
	# Detect mouse click for ground raycasting
	if event is InputEventMouseButton and event.pressed and not event.is_echo():
		if event.button_index == click_mouse_button:
			_handle_ground_click(event.position)

func _physics_process(delta: float) -> void:
	# Apply standard gravity
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	
	# Determine movement vector based on active input method
	var desired_horizontal_velocity := _calculate_movement(delta)
	
	velocity.x = desired_horizontal_velocity.x
	velocity.z = desired_horizontal_velocity.z
	
	move_and_slide()
	
	# Rotate character model to face velocity
	_update_character_rotation(delta)

## Projects ray from screen mouse position into 3D world to set click destination
func _handle_ground_click(screen_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	var ray_length := 150.0
	
	# Physics raycast against ground collision layer
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + ray_direction * ray_length,
		ground_collision_mask
	)
	var result := space_state.intersect_ray(query)
	
	if result:
		set_destination(result.position)
	else:
		# Fallback: intersect with mathematical horizontal ground plane at character feet
		var ground_plane := Plane(Vector3.UP, global_position.y)
		var hit = ground_plane.intersects_ray(ray_origin, ray_direction)
		if hit:
			set_destination(hit)

## Programmatically set navigation target point
func set_destination(target_world_pos: Vector3) -> void:
	_click_target_position = Vector3(target_world_pos.x, global_position.y, target_world_pos.z)
	_has_click_target = true
	destination_changed.emit(_click_target_position)

## Stop click-to-move navigation
func cancel_destination() -> void:
	if _has_click_target:
		_has_click_target = false
		destination_reached.emit()

func _calculate_movement(delta: float) -> Vector2:
	var move_intent := Vector3.ZERO
	
	# 1. Check Direct Directional Input (WASD / Joystick)
	if enable_direct_input:
		var direct_input = _get_direct_input_vector()
		if direct_input.length() > 0.1:
			# Direct input actively overrides point-and-click navigation
			cancel_destination()
			move_intent = direct_input
	
	# 2. Check Point-and-Click Pathfinding to Destination
	if _has_click_target and move_intent.length() <= 0.1:
		var to_target = _click_target_position - Vector3(global_position.x, _click_target_position.y, global_position.z)
		var distance = to_target.length()
		
		if distance <= arrival_tolerance:
			cancel_destination()
		else:
			move_intent = to_target.normalized()
	
	# 3. Apply Acceleration / Friction
	var current_horizontal := Vector2(velocity.x, velocity.z)
	var target_horizontal := Vector2(move_intent.x, move_intent.z) * move_speed
	
	if move_intent.length() > 0.1:
		current_horizontal = current_horizontal.move_toward(target_horizontal, acceleration * delta)
	else:
		current_horizontal = current_horizontal.move_toward(Vector2.ZERO, friction * delta)
		
	return current_horizontal

## Reads camera-aligned directional input (W moves up on screen, S down, A left, D right)
func _get_direct_input_vector() -> Vector3:
	var input_x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var input_z := Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	var raw_input := Vector2(input_x, input_z)
	
	if raw_input.length() <= 0.1:
		return Vector3.ZERO
	
	raw_input = raw_input.normalized()
	
	var camera := get_viewport().get_camera_3d()
	if camera:
		var cam_forward := -camera.global_transform.basis.z
		cam_forward.y = 0.0
		cam_forward = cam_forward.normalized()
		
		var cam_right := camera.global_transform.basis.x
		cam_right.y = 0.0
		cam_right = cam_right.normalized()
		
		return (cam_right * raw_input.x + cam_forward * (-raw_input.y)).normalized()
	
	return Vector3(raw_input.x, 0.0, raw_input.y).normalized()

## Smoothly aligns model facing with horizontal velocity vector
func _update_character_rotation(delta: float) -> void:
	var horizontal_vel := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal_vel.length() < 0.2:
		return
	
	var target_dir := horizontal_vel.normalized()
	var target_angle := atan2(-target_dir.x, -target_dir.z)
	
	var node_to_rotate := visual_node if visual_node else self
	node_to_rotate.rotation.y = lerp_angle(node_to_rotate.rotation.y, target_angle, rotation_speed * delta)
