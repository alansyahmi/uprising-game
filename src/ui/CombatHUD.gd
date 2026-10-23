class_name CombatHUD
extends CanvasLayer

# Combat Bars
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HeaderHBox/TopBar/HealthBar
@onready var health_label: Label = $MarginContainer/VBoxContainer/HeaderHBox/TopBar/HealthLabel
@onready var dash_bar: ProgressBar = $MarginContainer/VBoxContainer/HeaderHBox/TopBar/DashBar
@onready var announcement_label: Label = $AnnouncementLabel
@onready var combo_label: Label = $MarginContainer/VBoxContainer/BottomBar/WeaponInfo/ComboLabel

# Objectives Tracker
@onready var enemy_count_label: Label = $MarginContainer/VBoxContainer/HeaderHBox/ObjectivesPanel/Margin/VBox/EnemyCountLabel
@onready var lives_label: Label = $MarginContainer/VBoxContainer/HeaderHBox/ObjectivesPanel/Margin/VBox/LivesLabel
@onready var crit1_label: Label = $MarginContainer/VBoxContainer/HeaderHBox/ObjectivesPanel/Margin/VBox/Crit1Label
@onready var crit2_label: Label = $MarginContainer/VBoxContainer/HeaderHBox/ObjectivesPanel/Margin/VBox/Crit2Label
@onready var crit3_label: Label = $MarginContainer/VBoxContainer/HeaderHBox/ObjectivesPanel/Margin/VBox/Crit3Label

# Intro Banner
@onready var intro_banner: VBoxContainer = $IntroBanner

# Defeated Screen
@onready var defeated_screen: Control = $DefeatedScreen
@onready var dim_overlay: ColorRect = $DefeatedScreen/DimOverlay
@onready var defeat_enemies_label: Label = $DefeatedScreen/CenterBox/DefeatedStatsPanel/Margin/StatsVBox/DefeatEnemiesLabel
@onready var defeat_deaths_label: Label = $DefeatedScreen/CenterBox/DefeatedStatsPanel/Margin/StatsVBox/DefeatDeathsLabel
@onready var try_again_button: Button = $DefeatedScreen/CenterBox/ButtonsHBox/TryAgainButton
@onready var main_menu_button: Button = $DefeatedScreen/CenterBox/ButtonsHBox/MainMenuButton

# Victory Screen
@onready var victory_screen: Control = $VictoryScreen
@onready var victory_dim_overlay: ColorRect = $VictoryScreen/VictoryDimOverlay
@onready var rating_stars_label: Label = $VictoryScreen/VictoryCenterBox/RatingStarsLabel
@onready var vic_crit1_label: Label = $VictoryScreen/VictoryCenterBox/CriteriaPanel/Margin/CriteriaVBox/VicCrit1Label
@onready var vic_crit2_label: Label = $VictoryScreen/VictoryCenterBox/CriteriaPanel/Margin/CriteriaVBox/VicCrit2Label
@onready var vic_crit3_label: Label = $VictoryScreen/VictoryCenterBox/CriteriaPanel/Margin/CriteriaVBox/VicCrit3Label
@onready var vic_try_again_button: Button = $VictoryScreen/VictoryCenterBox/VicButtonsHBox/VicTryAgainButton
@onready var vic_main_menu_button: Button = $VictoryScreen/VictoryCenterBox/VicButtonsHBox/VicMainMenuButton

var announcement_tween: Tween
var current_killed: int = 0
var max_enemies: int = 12
var current_deaths: int = 0
var max_deaths: int = 3

func _ready() -> void:
	GlobalEvents.player_health_changed.connect(_on_health_changed)
	GlobalEvents.player_dash_cooldown_updated.connect(_on_dash_cooldown)
	GlobalEvents.perfect_dodge_triggered.connect(_on_perfect_dodge)
	GlobalEvents.parry_successful.connect(_on_parry)
	GlobalEvents.damage_number_requested.connect(_on_damage_number)
	
	GlobalEvents.stage_intro_started.connect(_on_stage_intro_started)
	GlobalEvents.stage_intro_completed.connect(_on_stage_intro_completed)
	GlobalEvents.enemy_count_updated.connect(_on_enemy_count_updated)
	GlobalEvents.player_death_occurred.connect(_on_player_death_occurred)
	GlobalEvents.stage_completed.connect(_on_stage_completed)
	GlobalEvents.stage_failed.connect(_on_stage_failed)
	
	try_again_button.pressed.connect(_on_try_again_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	vic_try_again_button.pressed.connect(_on_try_again_pressed)
	vic_main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	announcement_label.modulate.a = 0.0
	defeated_screen.visible = false
	victory_screen.visible = false
	
	_update_objectives_display()

func _on_stage_intro_started() -> void:
	defeated_screen.visible = false
	victory_screen.visible = false
	
	if intro_banner:
		intro_banner.visible = true
		intro_banner.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(intro_banner, "modulate:a", 1.0, 0.4)
		tw.tween_interval(1.8)
		tw.tween_property(intro_banner, "modulate:a", 0.0, 0.8)

func _on_stage_intro_completed() -> void:
	if intro_banner:
		var tw = create_tween()
		tw.tween_property(intro_banner, "modulate:a", 0.0, 0.3)
		await tw.finished
		intro_banner.visible = false

func _on_enemy_count_updated(killed: int, total: int) -> void:
	current_killed = killed
	max_enemies = total
	_update_objectives_display()

func _on_player_death_occurred(deaths: int, max_d: int) -> void:
	current_deaths = deaths
	max_deaths = max_d
	_update_objectives_display()

func _update_objectives_display() -> void:
	if enemy_count_label:
		enemy_count_label.text = "HOSTILES PURGED: %d / %d" % [current_killed, max_enemies]
		
	if lives_label:
		var remaining_lives = max(0, max_deaths - current_deaths)
		var hearts = ""
		for i in range(remaining_lives):
			hearts += "♥ "
		for i in range(current_deaths):
			hearts += "♡ "
		lives_label.text = "LIVES: %s (DEATHS: %d / %d)" % [hearts.strip_edges(), current_deaths, max_deaths]
		
	if crit1_label:
		crit1_label.text = "★ 1. Clear all enemies [%d/%d]" % [current_killed, max_enemies]
		if current_killed >= max_enemies:
			crit1_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4))
		else:
			crit1_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
			
	if crit2_label:
		crit2_label.text = "★ 2. Die <= 1 time [Deaths: %d]" % [current_deaths]
		if current_deaths <= 1:
			crit2_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4))
		else:
			crit2_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.35))
			
	if crit3_label:
		crit3_label.text = "★ 3. Die <= 2 times [Deaths: %d]" % [current_deaths]
		if current_deaths <= 2:
			crit3_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4))
		else:
			crit3_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.35))

func _on_stage_failed(total_deaths: int) -> void:
	defeated_screen.visible = true
	defeat_enemies_label.text = "HOSTILES PURGED: %d / %d" % [current_killed, max_enemies]
	defeat_deaths_label.text = "DEATHS INCURRED: %d / %d (LIMIT REACHED)" % [total_deaths, max_deaths]
	
	dim_overlay.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(dim_overlay, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_stage_completed(crit1: bool, crit2: bool, crit3: bool, total_deaths: int) -> void:
	victory_screen.visible = true
	
	# Evaluate stars
	var star_count = 0
	if crit1: star_count += 1
	if crit2: star_count += 1
	if crit3: star_count += 1
	
	var stars_text = ""
	for i in range(star_count):
		stars_text += "★ "
	for i in range(3 - star_count):
		stars_text += "☆ "
	rating_stars_label.text = stars_text.strip_edges()
	
	# Criteria lines
	vic_crit1_label.text = "★ CRITERION 1: Clear all 12 enemies [%d/%d]  -  %s" % [
		current_killed, max_enemies,
		"ACHIEVED" if crit1 else "FAILED"
	]
	vic_crit1_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4) if crit1 else Color(0.7, 0.7, 0.7))
	
	vic_crit2_label.text = "★ CRITERION 2: Die no more than 1 time [Deaths: %d]  -  %s" % [
		total_deaths,
		"ACHIEVED" if crit2 else "FAILED"
	]
	vic_crit2_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4) if crit2 else Color(0.9, 0.35, 0.4))
	
	vic_crit3_label.text = "★ CRITERION 3: Die no more than 2 times [Deaths: %d]  -  %s" % [
		total_deaths,
		"ACHIEVED" if crit3 else "FAILED"
	]
	vic_crit3_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4) if crit3 else Color(0.9, 0.35, 0.4))
	
	victory_dim_overlay.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(victory_dim_overlay, "modulate:a", 1.0, 0.5)

func _on_try_again_pressed() -> void:
	# Hide overlays and reload scene to restart cleanly from step 1 (upper body zoom -> 3s zoom-out)
	defeated_screen.visible = false
	victory_screen.visible = false
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/MainMenu.tscn")

func _on_health_changed(current: float, max_val: float) -> void:
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = current
	if health_label:
		health_label.text = "FLESH INTEGRITY: %d / %d" % [int(current), int(max_val)]

func _on_dash_cooldown(current: float, max_cd: float) -> void:
	if dash_bar:
		dash_bar.max_value = max_cd
		dash_bar.value = max_cd - current

func _on_perfect_dodge() -> void:
	_show_announcement("✦ PERFECT DODGE ✦\n[TIME DILATION ACTIVE]", Color(0.2, 0.9, 1.0))

func _on_parry(_enemy: Node3D) -> void:
	_show_announcement("⚔ PARRY DEFLECTED ⚔\n[POSTURE SHATTERED]", Color(1.0, 0.85, 0.2))

func _show_announcement(text: String, col: Color) -> void:
	announcement_label.text = text
	announcement_label.add_theme_color_override("font_color", col)
	
	if announcement_tween and announcement_tween.is_valid():
		announcement_tween.kill()
		
	announcement_label.pivot_offset = announcement_label.size / 2.0
	announcement_label.scale = Vector2(1.3, 1.3)
	announcement_label.modulate.a = 1.0
	
	announcement_tween = create_tween().set_parallel(true)
	announcement_tween.tween_property(announcement_label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	announcement_tween.tween_property(announcement_label, "modulate:a", 0.0, 0.8).set_delay(0.6)

func _on_damage_number(world_pos: Vector3, text: String, color: Color) -> void:
	var cam = get_viewport().get_camera_3d()
	if not cam:
		return
	if cam.is_position_behind(world_pos):
		return
		
	var screen_pos = cam.unproject_position(world_pos)
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.position = screen_pos + Vector2(randf_range(-15, 15), randf_range(-10, 10))
	add_child(lbl)
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 45.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.2)
	await tw.finished
	lbl.queue_free()
