class_name Hurtbox3D
extends Area3D

signal hit_received(hitbox: Hitbox3D)

@export var owner_node: Node3D

func _ready() -> void:
	if not owner_node:
		owner_node = get_parent() as Node3D
	monitoring = true
	monitorable = true

func receive_hit(hitbox: Hitbox3D) -> void:
	if not owner_node:
		return
	
	# Check Parry
	if owner_node.has_method("is_parrying") and owner_node.is_parrying():
		if hitbox.is_parryable:
			var parry_pos = (global_position + hitbox.global_position) * 0.5
			VFXManager.spawn_shockwave(parry_pos, 4.2, Color(0.2, 0.8, 1.0))
			VFXManager.spawn_hit_impact(parry_pos, (global_position - hitbox.global_position).normalized(), true)
			if owner_node.has_method("trigger_parry_success"):
				owner_node.trigger_parry_success(hitbox)
			return

	# Check Invulnerability / Dodge
	if owner_node.has_method("is_invulnerable") and owner_node.is_invulnerable():
		if owner_node.has_method("notify_dodge_evaded"):
			owner_node.notify_dodge_evaded()
		return

	hit_received.emit(hitbox)
	
	# Spawn Hit Impact VFX (Directional Blood & Sparks)
	var hit_pos = (global_position + hitbox.global_position) * 0.5
	var hit_dir = (global_position - hitbox.global_position).normalized()
	if hit_dir.is_zero_approx():
		hit_dir = Vector3(0, 0, 1)
		
	VFXManager.spawn_hit_impact(hit_pos, hit_dir, hitbox.is_heavy)
	if hitbox.is_heavy:
		VFXManager.spawn_shockwave(hit_pos, 3.5, Color(0.75, 0.08, 0.12))
	
	if owner_node.has_method("take_damage"):
		owner_node.take_damage(
			hitbox.damage,
			hitbox.stagger_damage,
			hitbox.knockback_force,
			hitbox.global_position
		)
