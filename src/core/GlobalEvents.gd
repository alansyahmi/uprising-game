extends Node

# Global Event Bus for Uprising: The Blood Sacrament

signal hit_registered(attacker: Node3D, target: Node3D, damage: float, is_critical: bool)
signal damage_number_requested(global_pos: Vector3, text: String, color: Color)
signal perfect_dodge_triggered()
signal parry_successful(enemy: Node3D)
signal enemy_staggered(enemy: Node3D)
signal player_health_changed(current_hp: float, max_hp: float)
signal player_dash_cooldown_updated(current: float, max_cd: float)

func _ready() -> void:
	_ensure_input_mappings()

func _ensure_input_mappings() -> void:
	_register_key_action("move_up", KEY_W)
	_register_key_action("move_down", KEY_S)
	_register_key_action("move_left", KEY_A)
	_register_key_action("move_right", KEY_D)
	_register_key_action("dash", KEY_SPACE)
	_register_key_action("burst", KEY_Q)
	_register_mouse_action("attack", MOUSE_BUTTON_LEFT)
	_register_mouse_action("special", MOUSE_BUTTON_RIGHT)

func _register_key_action(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(action_name, ev)

func _register_mouse_action(action_name: String, mouse_button: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		var ev := InputEventMouseButton.new()
		ev.button_index = mouse_button
		InputMap.action_add_event(action_name, ev)
