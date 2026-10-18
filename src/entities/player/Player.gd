class_name Player
extends CharacterBody3D

@export var max_health: float = 100.0
@export var move_speed: float = 9.0
@export var dash_speed: float = 26.0
@export var dash_duration: float = 0.22
@export var dash_cooldown: float = 0.8
@export var parry_duration: float = 0.25
@export var parry_cooldown: float = 1.0

var current_health: float = 100.0

# Movement & Facing
var look_target: Vector3 = Vector3.ZERO
var input_dir: Vector3 = Vector3.ZERO

# Combat State
var is_attacking: bool = false
var is_dashing: bool = false
var is_parrying: bool = false
var is_invulnerable: bool = false

var combo_index: int = 0
var combo_reset_timer: float = 0.0
var attack_timer: float = 0.0

var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector3 = Vector3.FORWARD
var perfect_dodge_window_timer: float = 0.0

var parry_timer: float = 0.0
var parry_cooldown_timer: float = 0.0

# Node References
@onready var model_holder: Node3D = $ModelHolder
@onready var rapier_mesh: Node3D = $ModelHolder/Rapier
@onready var rapier_hitbox: Hitbox3D = $ModelHolder/Rapier/Hitbox3D
@onready var hurtbox: Hurtbox3D = $Hurtbox3D
@onready var character_sprite: Sprite3D = $ModelHolder/CharacterSprite

var texture_front: Texture2D = preload("res://src/entities/player/textures/player_front.png")
var texture_back: Texture2D = preload("res://src/entities/player/textures/player_back.png")

var rapier_rest_pos: Vector3 = Vector3(0.4, 0.2, -0.6)
var rapier_rest_rot: Vector3 = Vector3.ZERO

func _ready() -> void:
	current_health = max_health
	GlobalEvents.player_health_changed.emit(current_health, max_health)
	rapier_hitbox.attacker = self
	rapier_hitbox.deactivate()
	if rapier_mesh:
		rapier_rest_pos = rapier_mesh.position
		rapier_rest_rot = rapier_mesh.rotation

func _process(delta: float) -> void:
	_update_timers(delta)
	_update_mouse_aim()
	_handle_combat_inputs()

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	move_and_slide()

func _update_timers(delta: float) -> void:
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer = max(0.0, dash_cooldown_timer - delta)
		GlobalEvents.player_dash_cooldown_updated.emit(dash_cooldown_timer, dash_cooldown)
	
	if perfect_dodge_window_timer > 0.0:
		perfect_dodge_window_timer = max(0.0, perfect_dodge_window_timer - delta)
		
	if combo_reset_timer > 0.0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0 and not is_attacking:
			combo_index = 0

	if parry_cooldown_timer > 0.0:
		parry_cooldown_timer = max(0.0, parry_cooldown_timer - delta)

func _update_mouse_aim() -> void:
	if is_dashing:
		return
	
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return
	
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := cam.project_ray_origin(mouse_pos)
	var ray_dir := cam.project_ray_normal(mouse_pos)
	var ground_plane := Plane(Vector3.UP, global_position.y)
	var ground_hit = ground_plane.intersects_ray(ray_origin, ray_dir)
	
	if ground_hit:
		look_target = ground_hit
		var flat_target = Vector3(look_target.x, global_position.y, look_target.z)
		if flat_target.distance_to(global_position) > 0.2:
			model_holder.look_at(flat_target, Vector3.UP)
			
	# Update 2.5D directional sprite (Front vs Back based on camera orientation)
	if character_sprite:
		var facing = -model_holder.global_transform.basis.z
		var cam_forward = -cam.global_transform.basis.z
		if facing.dot(cam_forward) > 0.1:
			if character_sprite.texture != texture_back:
				character_sprite.texture = texture_back
		elif facing.dot(cam_forward) < -0.1:
			if character_sprite.texture != texture_front:
				character_sprite.texture = texture_front

func _handle_movement(_delta: float) -> void:
	if is_dashing:
		velocity = dash_direction * dash_speed
		return
	
	# WASD Input (Screen-space camera relative)
	var move_x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var move_z = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	var cam := get_viewport().get_camera_3d()
	if cam:
		var cam_forward = -cam.global_transform.basis.z
		cam_forward.y = 0.0
		cam_forward = cam_forward.normalized()
		var cam_right = cam.global_transform.basis.x
		cam_right.y = 0.0
		cam_right = cam_right.normalized()
		input_dir = (cam_right * move_x + cam_forward * (-move_z)).normalized()
	else:
		input_dir = Vector3(move_x, 0.0, move_z).normalized()
	
	if is_attacking or is_parrying:
		# Reduced movement during attack/parry
		velocity = velocity.move_toward(input_dir * (move_speed * 0.25), 30.0 * _delta)
	else:
		velocity = velocity.move_toward(input_dir * move_speed, 45.0 * _delta)

func _handle_combat_inputs() -> void:
	# Dash has priority: instant dash-canceling out of attack or parry
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0 and not is_dashing:
		_execute_dash()
		return
	
	# Parry / Special
	if Input.is_action_just_pressed("special") and not is_dashing and not is_attacking and parry_cooldown_timer <= 0.0:
		_execute_parry()
		return
		
	# Attack combo
	if Input.is_action_just_pressed("attack") and not is_dashing and not is_parrying:
		_execute_attack()

func _execute_dash() -> void:
	# Cancel any ongoing attack/parry
	if is_attacking:
		_cancel_attack()
	is_parrying = false
	
	is_dashing = true
	is_invulnerable = true
	dash_cooldown_timer = dash_cooldown
	perfect_dodge_window_timer = 0.16 # 160ms window for Perfect Dodge
	
	if input_dir.length() > 0.1:
		dash_direction = input_dir
	else:
		dash_direction = -model_holder.global_transform.basis.z.normalized()
	
	# Visual model tilt
	var tween = create_tween().set_parallel(true)
	tween.tween_property(model_holder, "scale", Vector3(0.8, 0.6, 1.4), 0.08)
	
	await get_tree().create_timer(dash_duration).timeout
	
	is_dashing = false
	is_invulnerable = false
	var restore_tween = create_tween()
	restore_tween.tween_property(model_holder, "scale", Vector3.ONE, 0.08)

func _execute_parry() -> void:
	is_parrying = true
	parry_cooldown_timer = parry_cooldown
	
	# Visual parry guard stance: raise rapier across chest
	var tween = create_tween()
	tween.tween_property(rapier_mesh, "rotation_degrees", Vector3(0, 80, -45), 0.06)
	tween.parallel().tween_property(rapier_mesh, "position", Vector3(0.0, 0.5, -0.4), 0.06)
	
	await get_tree().create_timer(parry_duration).timeout
	
	if is_parrying:
		is_parrying = false
		_reset_rapier_transform(0.12)

func _execute_attack() -> void:
	is_attacking = true
	combo_reset_timer = 0.7
	
	# Combo scaling
	var dmg: float = 18.0
	var stagger: float = 12.0
	var hitstop_time: float = 0.05
	var thrust_distance: float = 1.3
	
	if combo_index == 1:
		dmg = 26.0
		stagger = 18.0
		hitstop_time = 0.06
		thrust_distance = 1.6
	elif combo_index == 2:
		dmg = 45.0
		stagger = 40.0
		hitstop_time = 0.09
		thrust_distance = 2.2
	
	rapier_hitbox.damage = dmg
	rapier_hitbox.stagger_damage = stagger
	
	# Micro lunge in facing direction
	var facing = -model_holder.global_transform.basis.z.normalized()
	velocity += facing * (5.0 + combo_index * 2.0)
	
	# Snappy thrust animation via Tween
	rapier_hitbox.activate()
	var tween = create_tween()
	var forward_pos = rapier_rest_pos + Vector3(0.0, 0.0, -thrust_distance)
	
	# Thrust forward in 70ms
	tween.tween_property(rapier_mesh, "position", forward_pos, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): HitStopManager.trigger_hit_stop(hitstop_time))
	# Retract in 120ms
	tween.tween_property(rapier_mesh, "position", rapier_rest_pos, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	await tween.finished
	rapier_hitbox.deactivate()
	is_attacking = false
	
	# Advance combo index
	combo_index = (combo_index + 1) % 3

func _cancel_attack() -> void:
	rapier_hitbox.deactivate()
	is_attacking = false
	_reset_rapier_transform(0.05)

func _reset_rapier_transform(duration: float = 0.1) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(rapier_mesh, "position", rapier_rest_pos, duration)
	tween.tween_property(rapier_mesh, "rotation", rapier_rest_rot, duration)

# Hurtbox Interface
func is_invulnerable_state() -> bool:
	return is_invulnerable

func is_parrying_state() -> bool:
	return is_parrying

func check_perfect_dodge() -> void:
	if perfect_dodge_window_timer > 0.0:
		perfect_dodge_window_timer = 0.0
		HitStopManager.trigger_perfect_dodge_slowdown()
		GlobalEvents.perfect_dodge_triggered.emit()

func notify_dodge_evaded() -> void:
	check_perfect_dodge()

func trigger_parry_success(hitbox: Hitbox3D) -> void:
	is_parrying = false
	_reset_rapier_transform(0.04)
	HitStopManager.trigger_parry_freeze()
	
	if hitbox.attacker and hitbox.attacker.has_method("take_parry_counter"):
		hitbox.attacker.take_parry_counter(60.0) # Massive posture break
		
	GlobalEvents.parry_successful.emit(hitbox.attacker)

func take_damage(amount: float, _stagger: float, knockback: float, from_pos: Vector3) -> void:
	current_health = max(0.0, current_health - amount)
	GlobalEvents.player_health_changed.emit(current_health, max_health)
	GlobalEvents.damage_number_requested.emit(global_position + Vector3(0, 1.8, 0), str(int(amount)), Color.RED)
	
	# Knockback
	var knock_dir = (global_position - from_pos).normalized()
	knock_dir.y = 0.0
	velocity += knock_dir * knockback
	
	# Visual damage flash
	var tween = create_tween()
	tween.tween_property(model_holder, "scale", Vector3(1.2, 0.8, 1.2), 0.06)
	tween.tween_property(model_holder, "scale", Vector3.ONE, 0.08)
