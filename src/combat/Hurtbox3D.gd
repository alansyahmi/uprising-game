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
			if owner_node.has_method("trigger_parry_success"):
				owner_node.trigger_parry_success(hitbox)
			return

	# Check Invulnerability / Dodge
	if owner_node.has_method("is_invulnerable") and owner_node.is_invulnerable():
		if owner_node.has_method("notify_dodge_evaded"):
			owner_node.notify_dodge_evaded()
		return

	hit_received.emit(hitbox)
	
	if owner_node.has_method("take_damage"):
		owner_node.take_damage(
			hitbox.damage,
			hitbox.stagger_damage,
			hitbox.knockback_force,
			hitbox.global_position
		)
