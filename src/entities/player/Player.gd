class_name Player
extends CharacterBody3D

@export_group("Movement & Rotation")
@export var max_health: float = 100.0
@export var move_speed: float = 9.0
## Turning interpolation speed towards movement direction (mobile-friendly snappy rotation)
@export var rotation_speed: float = 18.0
## If true, character rotates based on WASD/movement direction. If false, rotates based on mouse.
@export var use_wasd_rotation: bool = true

@export_group("Unarmed Combat Stats")
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
@onready var melee_hitbox: Hitbox3D = $ModelHolder/MeleeHitbox3D
@onready var hurtbox: Hurtbox3D = $Hurtbox3D
@onready var strike_trail_anchor: Node3D = $ModelHolder/StrikeTrailAnchor
@onready var motion_trail = $ModelHolder/StrikeTrailAnchor/MotionTrail

var anim_player: AnimationPlayer = null
var current_anim_name: String = ""

func _ready() -> void:
	current_health = max_health
	GlobalEvents.player_health_changed.emit(current_health, max_health)
	
	if melee_hitbox:
		melee_hitbox.attacker = self
		melee_hitbox.deactivate()
	
	# Find AnimationPlayer inside Belle 3D model instance
	anim_player = _find_animation_player(model_holder)
	if anim_player:
		# Configure loop modes for standard locomotion animations
		for anim_name in ["idle", "run"]:
			if anim_player.has_animation(anim_name):
				var anim = anim_player.get_animation(anim_name)
				if anim:
					anim.loop_mode = Animation.LOOP_LINEAR
		_play_anim("idle", 0.0)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = _find_animation_player(child)
		if found:
			return found
	return null

func _process(delta: float) -> void:
	_update_timers(delta)
	_handle_combat_inputs()
	_update_locomotion_animation()

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_update_rotation(delta)
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

func _update_locomotion_animation() -> void:
	if is_attacking or is_dashing or is_parrying:
		return
	
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > 0.35 and input_dir.length() > 0.05:
		_play_anim("run", 0.12)
	else:
		_play_anim("idle", 0.15)

func _play_anim(anim_name: String, blend_time: float = 0.1, custom_speed: float = 1.0) -> void:
	if not anim_player:
		return
	if not anim_player.has_animation(anim_name):
		return
	if current_anim_name == anim_name and anim_player.is_playing():
		return
		
	current_anim_name = anim_name
	anim_player.play(anim_name, blend_time, custom_speed)

func _update_rotation(delta: float) -> void:
	if is_dashing:
		return
	
	if use_wasd_rotation:
		# Rotate based on movement direction (WASD / virtual joystick)
		if input_dir.length() > 0.05:
			# Keep facing steady while locked in punch/kick strike execution
			if not is_attacking:
				var target_angle := atan2(-input_dir.x, -input_dir.z)
				model_holder.rotation.y = lerp_angle(model_holder.rotation.y, target_angle, rotation_speed * delta)
				look_target = global_position + input_dir
	else:
		_update_mouse_aim()

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

func _handle_movement(_delta: float) -> void:
	if is_dashing:
		velocity = dash_direction * dash_speed
		return
	
	# WASD / Arrow keys input (Screen-space camera relative)
	var move_x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var move_z = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	var raw_input = Vector2(move_x, move_z)
	
	if raw_input.length() > 0.05:
		if raw_input.length() > 1.0:
			raw_input = raw_input.normalized()
			
		var cam := get_viewport().get_camera_3d()
		if cam:
			var cam_forward = -cam.global_transform.basis.z
			cam_forward.y = 0.0
			cam_forward = cam_forward.normalized()
			var cam_right = cam.global_transform.basis.x
			cam_right.y = 0.0
			cam_right = cam_right.normalized()
			input_dir = (cam_right * raw_input.x + cam_forward * (-raw_input.y)).normalized()
		else:
			input_dir = Vector3(raw_input.x, 0.0, raw_input.y).normalized()
	else:
		input_dir = Vector3.ZERO
	
	if is_attacking:
		# Grounded martial arts friction: quickly settle after the initial strike step
		velocity = velocity.move_toward(Vector3.ZERO, 18.0 * _delta)
	elif is_parrying:
		# Sturdy braced stance during parry guard
		velocity = velocity.move_toward(Vector3.ZERO, 25.0 * _delta)
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
	
	if input_dir.length() > 0.05:
		dash_direction = input_dir
		if use_wasd_rotation:
			var target_angle := atan2(-dash_direction.x, -dash_direction.z)
			model_holder.rotation.y = target_angle
			look_target = global_position + dash_direction
	else:
		dash_direction = -model_holder.global_transform.basis.z.normalized()
	
	_play_anim("dash", 0.06, 1.2)
	VFXManager.spawn_dash_burst(global_position, dash_direction)
	
	# Visual model scale stretch
	var tween = create_tween().set_parallel(true)
	tween.tween_property(model_holder, "scale", Vector3(0.85, 0.75, 1.3), 0.08)
	
	await get_tree().create_timer(dash_duration).timeout
	
	is_dashing = false
	is_invulnerable = false
	var restore_tween = create_tween()
	restore_tween.tween_property(model_holder, "scale", Vector3.ONE, 0.08)
	_update_locomotion_animation()

func _execute_parry() -> void:
	if use_wasd_rotation and input_dir.length() > 0.05:
		var target_angle := atan2(-input_dir.x, -input_dir.z)
		model_holder.rotation.y = target_angle
		look_target = global_position + input_dir
		
	is_parrying = true
	parry_cooldown_timer = parry_cooldown
	
	# Play cross-arm defensive guard block
	_play_anim("parry_guard", 0.05, 1.0)
	
	await get_tree().create_timer(parry_duration).timeout
	
	if is_parrying:
		is_parrying = false
		_update_locomotion_animation()

func _execute_attack() -> void:
	is_attacking = true
	combo_reset_timer = 0.7
	
	# If moving with WASD when attacking, snap immediately to face the attack direction
	if use_wasd_rotation and input_dir.length() > 0.05:
		var target_angle := atan2(-input_dir.x, -input_dir.z)
		model_holder.rotation.y = target_angle
		look_target = global_position + input_dir
	
	# 3-Hit Martial Arts Combo sequence
	var dmg: float = 18.0
	var stagger: float = 12.0
	var hitstop_time: float = 0.04
	var trauma: float = 0.15
	var lunge_speed: float = 1.4
	var is_heavy: bool = false
	var anim_name: String = "attack_jab"
	var windup_time: float = 0.06
	var active_time: float = 0.12
	var recover_time: float = 0.08
	var trail_pos: Vector3 = Vector3(0.2, 0.95, -0.7)
	
	if combo_index == 1:
		# Hit 2: Right Cross
		dmg = 26.0
		stagger = 18.0
		hitstop_time = 0.07
		trauma = 0.35
		lunge_speed = 2.0
		is_heavy = false
		anim_name = "attack_cross"
		windup_time = 0.07
		active_time = 0.14
		recover_time = 0.08
		trail_pos = Vector3(-0.18, 0.9, -0.8)
	elif combo_index == 2:
		# Hit 3: Roundhouse Kick Finisher
		dmg = 45.0
		stagger = 40.0
		hitstop_time = 0.12
		trauma = 0.65
		lunge_speed = 2.6
		is_heavy = true
		anim_name = "attack_kick"
		windup_time = 0.10
		active_time = 0.16
		recover_time = 0.12
		trail_pos = Vector3(0.0, 0.65, -0.95)
	
	if melee_hitbox:
		melee_hitbox.damage = dmg
		melee_hitbox.stagger_damage = stagger
		melee_hitbox.is_heavy = is_heavy
		melee_hitbox.combo_index = combo_index
	
	if strike_trail_anchor:
		strike_trail_anchor.position = trail_pos
	if motion_trail:
		motion_trail.start_trail()
	
	# Subtle grounded strike step in facing direction (replaces running momentum)
	var facing = -model_holder.global_transform.basis.z.normalized()
	velocity = facing * lunge_speed
	
	_play_anim(anim_name, 0.04, 1.0)
	
	# Windup frame delay
	await get_tree().create_timer(windup_time).timeout
	if not is_attacking:
		if motion_trail: motion_trail.stop_trail()
		return
		
	# Active strike window
	if melee_hitbox:
		melee_hitbox.activate()
	if is_heavy:
		VFXManager.spawn_shockwave(global_position + facing * 0.8, 3.4, Color(0.75, 0.08, 0.12))
	HitStopManager.trigger_scaled_hitstop(hitstop_time, trauma)
	
	await get_tree().create_timer(active_time).timeout
	if melee_hitbox:
		melee_hitbox.deactivate()
	if motion_trail:
		motion_trail.stop_trail()
		
	# Recovery follow-through
	await get_tree().create_timer(recover_time).timeout
	is_attacking = false
	
	# Advance combo index
	combo_index = (combo_index + 1) % 3
	_update_locomotion_animation()

func _cancel_attack() -> void:
	if melee_hitbox:
		melee_hitbox.deactivate()
	if motion_trail:
		motion_trail.stop_trail()
	is_attacking = false

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
	HitStopManager.trigger_parry_freeze()
	VFXManager.spawn_shockwave(global_position, 4.2, Color(0.2, 0.8, 1.0))
	
	if hitbox.attacker and hitbox.attacker.has_method("take_parry_counter"):
		hitbox.attacker.take_parry_counter(60.0) # Massive posture break
		
	GlobalEvents.parry_successful.emit(hitbox.attacker)
	_update_locomotion_animation()

func take_damage(amount: float, _stagger: float, knockback: float, from_pos: Vector3) -> void:
	current_health = max(0.0, current_health - amount)
	GlobalEvents.player_health_changed.emit(current_health, max_health)
	GlobalEvents.damage_number_requested.emit(global_position + Vector3(0, 1.8, 0), str(int(amount)), Color.RED)
	
	# Knockback
	var knock_dir = (global_position - from_pos).normalized()
	knock_dir.y = 0.0
	velocity += knock_dir * knockback
	
	# Visual damage impact flash
	var tween = create_tween()
	tween.tween_property(model_holder, "scale", Vector3(1.15, 0.85, 1.15), 0.06)
	tween.tween_property(model_holder, "scale", Vector3.ONE, 0.08)
