class_name TrainingDummy
extends CharacterBody3D

@export var max_health: float = 140.0
@export var max_posture: float = 60.0
@export var is_attacker: bool = true
@export var attack_interval: float = 3.2

var current_health: float = 140.0
var current_posture: float = 60.0

var is_staggered: bool = false
var is_dead: bool = false
var stagger_timer: float = 0.0
var attack_timer: float = 0.0
var is_winding_up: bool = false

@onready var model_holder: Node3D = $ModelHolder
@onready var body_mesh: MeshInstance3D = $ModelHolder/BodyMesh
@onready var telegraph_mesh: MeshInstance3D = $ModelHolder/TelegraphMarker
@onready var enemy_hitbox: Hitbox3D = $ModelHolder/EnemyHitbox
@onready var hp_bar: ProgressBar = $SubViewport/BillboardUI/HPBar
@onready var posture_bar: ProgressBar = $SubViewport/BillboardUI/PostureBar

var original_mat: StandardMaterial3D

func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	current_posture = max_posture
	if enemy_hitbox:
		enemy_hitbox.attacker = self
		enemy_hitbox.deactivate()
	if telegraph_mesh:
		telegraph_mesh.visible = false
	if body_mesh:
		original_mat = body_mesh.get_surface_override_material(0)
		if not original_mat:
			original_mat = body_mesh.mesh.material as StandardMaterial3D
	_update_ui()

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = velocity.move_toward(Vector3.ZERO, 30.0 * delta)
		move_and_slide()
		return
		
	if is_attacker and not is_staggered and not is_winding_up:
		var player = get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(player) and not ("is_dead" in player and player.is_dead):
			var dist = global_position.distance_to(player.global_position)
			if dist > 3.2 and dist < 25.0:
				var move_dir = (player.global_position - global_position).normalized()
				move_dir.y = 0.0
				velocity = velocity.move_toward(move_dir * 2.8, 12.0 * delta)
				var flat_pos = Vector3(player.global_position.x, global_position.y, player.global_position.z)
				model_holder.look_at(flat_pos, Vector3.UP)
			else:
				velocity = velocity.move_toward(Vector3.ZERO, 25.0 * delta)
		else:
			velocity = velocity.move_toward(Vector3.ZERO, 25.0 * delta)
	else:
		velocity = velocity.move_toward(Vector3.ZERO, 25.0 * delta)
		
	move_and_slide()

func _process(delta: float) -> void:
	if is_dead:
		return
		
	if is_staggered:
		stagger_timer -= delta
		if stagger_timer <= 0.0:
			_recover_from_stagger()
		return
	
	# Slowly regenerate posture if not taking damage
	if current_posture < max_posture and not is_winding_up:
		current_posture = min(max_posture, current_posture + 8.0 * delta)
		_update_ui()
	
	if is_attacker:
		_process_attack_cycle(delta)

func _process_attack_cycle(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player) or ("is_dead" in player and player.is_dead):
		return
		
	attack_timer += delta
	if attack_timer >= attack_interval and not is_winding_up:
		_start_telegraphed_attack()

func _start_telegraphed_attack() -> void:
	is_winding_up = true
	attack_timer = 0.0
	
	# Look towards player if found
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var flat_pos = Vector3(player.global_position.x, global_position.y, player.global_position.z)
		model_holder.look_at(flat_pos, Vector3.UP)
	
	# Show glowing red telegraph marker
	if telegraph_mesh:
		telegraph_mesh.visible = true
		telegraph_mesh.scale = Vector3(0.2, 0.2, 0.2)
		var tween = create_tween()
		tween.tween_property(telegraph_mesh, "scale", Vector3(1.0, 1.0, 1.0), 0.8)
		await tween.finished
	else:
		await get_tree().create_timer(0.8).timeout
	
	if is_staggered or is_dead:
		if telegraph_mesh: telegraph_mesh.visible = false
		is_winding_up = false
		return
	
	# Execute strike
	if telegraph_mesh:
		telegraph_mesh.visible = false
	
	if enemy_hitbox:
		enemy_hitbox.activate()
	
	# Strike lunge forward
	var facing = -model_holder.global_transform.basis.z.normalized()
	velocity += facing * 8.0
	
	var strike_tween = create_tween()
	strike_tween.tween_property(model_holder, "position", model_holder.position + facing * 0.8, 0.1)
	strike_tween.tween_property(model_holder, "position", Vector3.ZERO, 0.2)
	await strike_tween.finished
	
	if enemy_hitbox:
		enemy_hitbox.deactivate()
	is_winding_up = false

func take_damage(amount: float, stagger: float, knockback: float, from_pos: Vector3) -> void:
	if is_dead:
		return
		
	var final_dmg = amount * (1.5 if is_staggered else 1.0)
	current_health = max(0.0, current_health - final_dmg)
	
	# Posture damage
	if not is_staggered:
		current_posture = max(0.0, current_posture - stagger)
		if current_posture <= 0.0:
			_enter_stagger()
	
	_update_ui()
	
	# Floating damage number
	var dmg_color = Color.YELLOW if is_staggered else Color.WHITE
	GlobalEvents.damage_number_requested.emit(
		global_position + Vector3(0, 2.2, 0),
		str(int(final_dmg)) + ("!" if is_staggered else ""),
		dmg_color
	)
	
	# Knockback
	var knock_dir = (global_position - from_pos).normalized()
	knock_dir.y = 0.0
	velocity += knock_dir * (knockback * 0.7)
	
	# Flash red/white
	_flash_color(Color(1.0, 0.3, 0.3))
	
	# Dynamic Squash & Stretch physical reaction
	if model_holder:
		var tween = create_tween()
		tween.tween_property(model_holder, "scale", Vector3(1.28, 0.72, 1.28), 0.05).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(model_holder, "scale", Vector3(0.92, 1.14, 0.92), 0.08).set_trans(Tween.TRANS_SINE)
		tween.tween_property(model_holder, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	if current_health <= 0.0:
		_die()

func take_parry_counter(posture_loss: float) -> void:
	if is_dead:
		return
	GlobalEvents.damage_number_requested.emit(
		global_position + Vector3(0, 2.4, 0),
		"PARRY BROKEN!",
		Color(0.2, 0.8, 1.0)
	)
	current_posture = max(0.0, current_posture - posture_loss)
	_enter_stagger()
	_flash_color(Color(0.3, 0.8, 1.0))

func _enter_stagger() -> void:
	is_staggered = true
	stagger_timer = 4.0
	is_winding_up = false
	if telegraph_mesh: telegraph_mesh.visible = false
	if enemy_hitbox: enemy_hitbox.deactivate()
	
	GlobalEvents.enemy_staggered.emit(self)
	_update_ui()

func _recover_from_stagger() -> void:
	is_staggered = false
	current_posture = max_posture
	_update_ui()

func _flash_color(_color: Color) -> void:
	var tween = create_tween()
	tween.tween_property(model_holder, "scale", Vector3(1.2, 0.85, 1.2), 0.05)
	tween.tween_property(model_holder, "scale", Vector3.ONE, 0.08)

func _update_ui() -> void:
	if hp_bar:
		hp_bar.value = (current_health / max_health) * 100.0
	if posture_bar:
		posture_bar.value = (current_posture / max_posture) * 100.0

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	remove_from_group("enemies")
	
	if enemy_hitbox: enemy_hitbox.deactivate()
	if telegraph_mesh: telegraph_mesh.visible = false
	var hurtbox = find_child("Hurtbox3D", true, false)
	if hurtbox:
		hurtbox.monitoring = false
		hurtbox.monitorable = false
		
	GlobalEvents.damage_number_requested.emit(global_position + Vector3(0, 2.5, 0), "PURGED", Color.RED)
	GlobalEvents.enemy_killed.emit(self)
	VFXManager.spawn_shockwave(global_position, 2.8, Color(0.8, 0.1, 0.15))
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(model_holder, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(model_holder, "rotation_degrees:y", model_holder.rotation_degrees.y + 180.0, 0.25)
	await tween.finished
	queue_free()
