class_name CombatHUD
extends CanvasLayer

@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/TopBar/HealthBar
@onready var health_label: Label = $MarginContainer/VBoxContainer/TopBar/HealthLabel
@onready var dash_bar: ProgressBar = $MarginContainer/VBoxContainer/TopBar/DashBar
@onready var announcement_label: Label = $AnnouncementLabel
@onready var combo_label: Label = $MarginContainer/VBoxContainer/BottomBar/ComboLabel

var announcement_tween: Tween

func _ready() -> void:
	GlobalEvents.player_health_changed.connect(_on_health_changed)
	GlobalEvents.player_dash_cooldown_updated.connect(_on_dash_cooldown)
	GlobalEvents.perfect_dodge_triggered.connect(_on_perfect_dodge)
	GlobalEvents.parry_successful.connect(_on_parry)
	GlobalEvents.damage_number_requested.connect(_on_damage_number)
	announcement_label.modulate.a = 0.0

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
	announcement_tween.tween_property(announcement_label, "modulate:a", 0.0, 0.8).set_delay(0.4)

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
