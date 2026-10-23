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
	
	# Alternative arrow keys
	_register_key_action("move_up", KEY_UP)
	_register_key_action("move_down", KEY_DOWN)
	_register_key_action("move_left", KEY_LEFT)
	_register_key_action("move_right", KEY_RIGHT)
	
	_register_key_action("dash", KEY_SPACE)
	_register_key_action("dash", KEY_SHIFT)
	_register_key_action("burst", KEY_Q)
	
	_register_mouse_action("attack", MOUSE_BUTTON_LEFT)
	_register_mouse_action("special", MOUSE_BUTTON_RIGHT)
	
	# Alternative keyboard keys for combat (mobile emulator / keyboard-only friendliness)
	_register_key_action("attack", KEY_J)
	_register_key_action("special", KEY_K)

func _register_key_action(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventKey and ev.physical_keycode == keycode:
			return
			
	var new_ev := InputEventKey.new()
	new_ev.physical_keycode = keycode
	InputMap.action_add_event(action_name, new_ev)

func _register_mouse_action(action_name: String, mouse_button: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventMouseButton and ev.button_index == mouse_button:
			return
			
	var new_ev := InputEventMouseButton.new()
	new_ev.button_index = mouse_button
	InputMap.action_add_event(action_name, new_ev)
