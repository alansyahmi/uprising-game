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

# Stage & Lifecycle State
var current_health: float = 100.0
var death_count: int = 0
var max_allowed_deaths: int = 3
var is_dead: bool = false
var is_defeated: bool = false
var input_enabled: bool = false
var spawn_position: Vector3 = Vector3.ZERO

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
	spawn_position = global_position
	current_health = max_health
	death_count = 0
	GlobalEvents.player_health_changed.emit(current_health, max_health)
	
	if melee_hitbox:
		melee_hitbox.attacker = self
		melee_hitbox.deactivate()
	
	GlobalEvents.stage_intro_started.connect(func(): input_enabled = false)
	GlobalEvents.stage_intro_completed.connect(func(): if not is_defeated: input_enabled = true)
	GlobalEvents.restart_stage_requested.connect(reset_player)
	
	# Find AnimationPlayer inside Belle 3D model instance
	anim_player = _find_animation_player(model_holder)
	if anim_player:
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

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found = _find_skeleton(child)
		if found:
			return found
	return null

func _process(delta: float) -> void:
	if is_defeated or is_dead:
		return
	_update_timers(delta)
	if input_enabled:
		_handle_combat_inputs()
	_update_locomotion_animation()

func _physics_process(delta: float) -> void:
	if is_defeated or is_dead:
		velocity = velocity.move_toward(Vector3.ZERO, 30.0 * delta)
		move_and_slide()
		return
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
	if is_attacking or is_dashing or is_parrying or is_defeated or is_dead:
		return
	
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > 0.35 and input_dir.length() > 0.05:
		_play_anim("run", 0.12)
	else:
		_play_anim("idle", 0.15)

func _play_anim(anim_name: String, blend_time: float = 0.1, custom_speed: float = 1.0) -> void:
	if not anim_player or is_defeated:
		return
	if not anim_player.has_animation(anim_name):
		return
	if current_anim_name == anim_name and anim_player.is_playing():
		return
		
	current_anim_name = anim_name
	anim_player.play(anim_name, blend_time, custom_speed)

func _update_rotation(delta: float) -> void:
	if is_dashing or not input_enabled:
		return
	
	if use_wasd_rotation:
		if input_dir.length() > 0.05:
			if not is_attacking:
				var target_angle := atan2(-input_dir.x, -input_dir.z)
				model_holder.rotation.y = lerp_angle(model_holder.rotation.y, target_angle, rotation_speed * delta)
				look_target = global_position + input_dir
	else:
		_update_mouse_aim()

func _update_mouse_aim() -> void:
	if is_dashing or not input_enabled:
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
		
	if not input_enabled:
		velocity = velocity.move_toward(Vector3.ZERO, 35.0 * _delta)
		input_dir = Vector3.ZERO
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
		velocity = velocity.move_toward(Vector3.ZERO, 18.0 * _delta)
	elif is_parrying:
		velocity = velocity.move_toward(Vector3.ZERO, 25.0 * _delta)
	else:
		velocity = velocity.move_toward(input_dir * move_speed, 45.0 * _delta)

func _handle_combat_inputs() -> void:
	if not input_enabled:
		return
		
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
	if is_attacking:
		_cancel_attack()
	is_parrying = false
	
	is_dashing = true
	is_invulnerable = true
	dash_cooldown_timer = dash_cooldown
	perfect_dodge_window_timer = 0.16
	
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
	
	_play_anim("parry_guard", 0.05, 1.0)
	
	await get_tree().create_timer(parry_duration).timeout
	
	if is_parrying:
		is_parrying = false
		_update_locomotion_animation()

func _execute_attack() -> void:
	is_attacking = true
	combo_reset_timer = 0.7
	
	if use_wasd_rotation and input_dir.length() > 0.05:
		var target_angle := atan2(-input_dir.x, -input_dir.z)
		model_holder.rotation.y = target_angle
		look_target = global_position + input_dir
	
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
	
	var facing = -model_holder.global_transform.basis.z.normalized()
	velocity = facing * lunge_speed
	
	_play_anim(anim_name, 0.04, 1.0)
	
	await get_tree().create_timer(windup_time).timeout
	if not is_attacking or is_defeated:
		if motion_trail: motion_trail.stop_trail()
		return
		
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
		
	await get_tree().create_timer(recover_time).timeout
	is_attacking = false
	
	combo_index = (combo_index + 1) % 3
	_update_locomotion_animation()

func _cancel_attack() -> void:
	if melee_hitbox:
		melee_hitbox.deactivate()
	if motion_trail:
		motion_trail.stop_trail()
	is_attacking = false

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
		hitbox.attacker.take_parry_counter(60.0)
		
	GlobalEvents.parry_successful.emit(hitbox.attacker)
	_update_locomotion_animation()

func take_damage(amount: float, _stagger: float, knockback: float, from_pos: Vector3) -> void:
	if is_invulnerable or is_dead or is_defeated:
		return
		
	current_health = max(0.0, current_health - amount)
	GlobalEvents.player_health_changed.emit(current_health, max_health)
	GlobalEvents.damage_number_requested.emit(global_position + Vector3(0, 1.8, 0), str(int(amount)), Color.RED)
	
	var knock_dir = (global_position - from_pos).normalized()
	knock_dir.y = 0.0
	velocity += knock_dir * knockback
	
	var tween = create_tween()
	tween.tween_property(model_holder, "scale", Vector3(1.15, 0.85, 1.15), 0.06)
	tween.tween_property(model_holder, "scale", Vector3.ONE, 0.08)
	
	if current_health <= 0.0:
		_handle_player_death()

func _handle_player_death() -> void:
	if is_dead or is_defeated:
		return
		
	death_count += 1
	GlobalEvents.player_death_occurred.emit(death_count, max_allowed_deaths)
	
	if death_count >= max_allowed_deaths:
		_trigger_defeat()
	else:
		_trigger_respawn()

func _trigger_respawn() -> void:
	is_dead = true
	is_invulnerable = true
	input_enabled = false
	if melee_hitbox: melee_hitbox.deactivate()
	if motion_trail: motion_trail.stop_trail()
	
	var death_title = "FLESH COMPROMISED // REVIVING (DEATH %d/%d)" % [death_count, max_allowed_deaths]
	GlobalEvents.damage_number_requested.emit(global_position + Vector3(0, 2.2, 0), death_title, Color(1.0, 0.4, 0.2))
	
	_play_anim("idle", 0.1)
	var tw = create_tween()
	tw.tween_property(model_holder, "scale", Vector3(1.2, 0.6, 1.2), 0.2)
	tw.tween_property(model_holder, "scale", Vector3.ONE, 0.2)
	
	await get_tree().create_timer(0.6).timeout
	
	current_health = max_health
	GlobalEvents.player_health_changed.emit(current_health, max_health)
	GlobalEvents.player_respawned.emit()
	
	is_dead = false
	input_enabled = true
	
	VFXManager.spawn_shockwave(global_position, 3.2, Color(0.2, 0.8, 1.0))
	var blink_count = 6
	for i in range(blink_count):
		model_holder.visible = not model_holder.visible
		await get_tree().create_timer(0.12).timeout
	model_holder.visible = true
	is_invulnerable = false

func _trigger_defeat() -> void:
	is_defeated = true
	is_dead = true
	input_enabled = false
	is_invulnerable = true
	
	if hurtbox:
		hurtbox.monitoring = false
		hurtbox.monitorable = false
	if melee_hitbox:
		melee_hitbox.deactivate()
	if motion_trail:
		motion_trail.stop_trail()
	if anim_player:
		anim_player.stop()
		
	_pose_defeat_rig()
	GlobalEvents.stage_failed.emit(death_count)

func _pose_defeat_rig() -> void:
	# 1. Pose Skeleton3D bones for defeat posture
	var skel: Skeleton3D = _find_skeleton(model_holder)
	if skel:
		var head_idx = skel.find_bone("頭")
		if head_idx != -1:
			skel.set_bone_pose_rotation(head_idx, Quaternion.from_euler(Vector3(0.25, 0.45, 0.15)))
		
		var arm_l_idx = skel.find_bone("腕.L")
		if arm_l_idx != -1:
			skel.set_bone_pose_rotation(arm_l_idx, Quaternion.from_euler(Vector3(0.3, 0.6, 0.9)))
		var arm_r_idx = skel.find_bone("腕.R")
		if arm_r_idx != -1:
			skel.set_bone_pose_rotation(arm_r_idx, Quaternion.from_euler(Vector3(0.3, -0.6, -0.9)))
			
		var wrist_l = skel.find_bone("手首.L")
		if wrist_l != -1:
			skel.set_bone_pose_rotation(wrist_l, Quaternion.from_euler(Vector3(-0.4, 0.2, 0.0)))
		var wrist_r = skel.find_bone("手首.R")
		if wrist_r != -1:
			skel.set_bone_pose_rotation(wrist_r, Quaternion.from_euler(Vector3(-0.4, -0.2, 0.0)))
			
		var knee_l = skel.find_bone("ひざ.L")
		if knee_l != -1:
			skel.set_bone_pose_rotation(knee_l, Quaternion.from_euler(Vector3(0.35, 0.0, 0.0)))
		var knee_r = skel.find_bone("ひざ.R")
		if knee_r != -1:
			skel.set_bone_pose_rotation(knee_r, Quaternion.from_euler(Vector3(0.35, 0.0, 0.0)))

	# 2. Animate the model rig collapsing backwards flat onto the floor
	var defeat_tween = create_tween()
	defeat_tween.set_parallel(true)
	defeat_tween.tween_property(model_holder, "rotation_degrees:x", -82.0, 0.45)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	defeat_tween.tween_property(model_holder, "position:y", 0.12, 0.45)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	defeat_tween.tween_property(model_holder, "position:z", model_holder.position.z + 0.35, 0.45)
	
	var chain_tw = defeat_tween.chain().set_parallel(true)
	chain_tw.tween_property(model_holder, "rotation_degrees:x", -88.0, 0.18)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)
	chain_tw.tween_property(model_holder, "position:y", 0.10, 0.18)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)
		
	VFXManager.spawn_shockwave(global_position, 2.4, Color(0.65, 0.08, 0.12))
	HitStopManager.trigger_scaled_hitstop(0.12, 0.8)

func reset_player() -> void:
	current_health = max_health
	death_count = 0
	is_dead = false
	is_defeated = false
	input_enabled = false
	is_invulnerable = false
	
	global_position = spawn_position
	velocity = Vector3.ZERO
	
	model_holder.position = Vector3.ZERO
	model_holder.rotation = Vector3.ZERO
	model_holder.scale = Vector3.ONE
	
	var skel: Skeleton3D = _find_skeleton(model_holder)
	if skel:
		skel.clear_bones_global_pose_override()
		for b in range(skel.get_bone_count()):
			skel.set_bone_pose_rotation(b, Quaternion.IDENTITY)
			skel.set_bone_pose_position(b, Vector3.ZERO)
			
	if hurtbox:
		hurtbox.monitoring = true
		hurtbox.monitorable = true
		
	GlobalEvents.player_health_changed.emit(current_health, max_health)
	_play_anim("idle", 0.0)
