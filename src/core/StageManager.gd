class_name StageManager
extends Node

## Manages stage progression, 12-enemy wave spawning, criteria evaluation, and completion.

@export var total_enemies: int = 12
@export var enemy_scene: PackedScene = preload("res://src/entities/enemies/TrainingDummy.tscn")

var enemies_killed: int = 0
var current_wave: int = 0
var stage_finished: bool = false
var active_enemies: Array[Node3D] = []

func _ready() -> void:
	GlobalEvents.enemy_killed.connect(_on_enemy_killed)
	GlobalEvents.stage_intro_completed.connect(_on_intro_completed)
	GlobalEvents.restart_stage_requested.connect(restart_stage)
	
	# Initial UI update
	call_deferred("_broadcast_initial_counts")

func _broadcast_initial_counts() -> void:
	GlobalEvents.enemy_count_updated.emit(enemies_killed, total_enemies)

func _on_intro_completed() -> void:
	if current_wave == 0 and not stage_finished:
		start_wave(1)

func start_wave(wave_num: int) -> void:
	current_wave = wave_num
	var player = get_tree().get_first_node_in_group("player")
	
	match wave_num:
		1:
			_show_announcement("✦ WAVE 1 / 3 ✦\n[PURGE 4 HOSTILES]", Color(0.9, 0.75, 0.2))
			await get_tree().create_timer(0.6).timeout
			# 2 passive targets, 2 standard attackers
			_spawn_enemy(Vector3(-5.5, 0, -3.0), false, 120.0, 3.2)
			_spawn_enemy(Vector3(5.5, 0, -3.0), false, 120.0, 3.2)
			_spawn_enemy(Vector3(-3.5, 0, 1.0), true, 140.0, 3.2)
			_spawn_enemy(Vector3(3.5, 0, 1.0), true, 140.0, 3.2)
		2:
			_show_announcement("✦ WAVE 2 / 3 ✦\n[THE BLOOD PACK APPROACHES]", Color(1.0, 0.45, 0.15))
			await get_tree().create_timer(0.8).timeout
			# 4 aggressive attackers
			_spawn_enemy(Vector3(-7.0, 0, -6.0), true, 140.0, 2.7)
			_spawn_enemy(Vector3(7.0, 0, -6.0), true, 140.0, 2.7)
			_spawn_enemy(Vector3(-6.0, 0, 4.0), true, 140.0, 2.7)
			_spawn_enemy(Vector3(6.0, 0, 4.0), true, 140.0, 2.7)
		3:
			_show_announcement("✦ FINAL WAVE 3 / 3 ✦\n[SACRAMENT ELITES INCOMING]", Color(0.9, 0.1, 0.2))
			await get_tree().create_timer(0.8).timeout
			# 4 elite fast attackers
			_spawn_enemy(Vector3(0.0, 0, -9.0), true, 160.0, 2.2)
			_spawn_enemy(Vector3(-8.0, 0, -1.0), true, 160.0, 2.2)
			_spawn_enemy(Vector3(8.0, 0, -1.0), true, 160.0, 2.2)
			_spawn_enemy(Vector3(0.0, 0, 1.0), true, 160.0, 2.2)

func _spawn_enemy(pos: Vector3, is_attacker: bool, hp: float, attack_int: float) -> void:
	if not enemy_scene:
		return
		
	# Spawn telegraph effect
	VFXManager.spawn_shockwave(pos, 2.2, Color(0.9, 0.15, 0.2, 0.8))
	
	var enemy = enemy_scene.instantiate() as Node3D
	get_parent().add_child(enemy)
	enemy.global_position = pos
	
	if "is_attacker" in enemy:
		enemy.is_attacker = is_attacker
	if "max_health" in enemy:
		enemy.max_health = hp
		enemy.current_health = hp
	if "attack_interval" in enemy:
		enemy.attack_interval = attack_int
		
	active_enemies.append(enemy)

func _on_enemy_killed(enemy: Node3D) -> void:
	if active_enemies.has(enemy):
		active_enemies.erase(enemy)
		
	enemies_killed += 1
	GlobalEvents.enemy_count_updated.emit(enemies_killed, total_enemies)
	
	# Check for next wave or stage completion
	if enemies_killed == 4 and current_wave == 1:
		await get_tree().create_timer(1.2).timeout
		start_wave(2)
	elif enemies_killed == 8 and current_wave == 2:
		await get_tree().create_timer(1.2).timeout
		start_wave(3)
	elif enemies_killed >= total_enemies and not stage_finished:
		_complete_stage()

func _complete_stage() -> void:
	stage_finished = true
	var player = get_tree().get_first_node_in_group("player")
	var deaths: int = 0
	if player and "death_count" in player:
		deaths = player.death_count
		
	# Criteria Evaluation:
	# 1. Clear all enemies on that stage e.g. 12/12 enemies killed (Always true here)
	# 2. Character didn't die more than 1 time (deaths <= 1)
	# 3. Character didn't die more than 2 times (deaths <= 2)
	var crit1: bool = (enemies_killed >= total_enemies)
	var crit2: bool = (deaths <= 1)
	var crit3: bool = (deaths <= 2)
	
	GlobalEvents.stage_completed.emit(crit1, crit2, crit3, deaths)

func _show_announcement(text: String, col: Color) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("_show_announcement"):
		hud._show_announcement(text, col)

func restart_stage() -> void:
	# Remove any existing active enemies
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()
	
	# Remove any remaining in enemies group
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()
			
	enemies_killed = 0
	current_wave = 0
	stage_finished = false
	GlobalEvents.enemy_count_updated.emit(0, total_enemies)
