class_name Hitbox3D
extends Area3D

@export var damage: float = 20.0
@export var stagger_damage: float = 15.0
@export var knockback_force: float = 5.0
@export var is_parryable: bool = true

var attacker: Node3D
var hit_targets: Array[Node3D] = []

func _ready() -> void:
	monitoring = false
	monitorable = true
	area_entered.connect(_on_area_entered)

func activate() -> void:
	hit_targets.clear()
	monitoring = true

func deactivate() -> void:
	monitoring = false

func _on_area_entered(area: Area3D) -> void:
	if area is Hurtbox3D:
		var target = area.owner_node
		if target and target != attacker and not hit_targets.has(target):
			hit_targets.append(target)
			area.receive_hit(self)
