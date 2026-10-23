extends Node3D

# VFXManager: Central manager for combat visual effects, blood splatters, decals, and shockwaves.
# Uses procedurally generated textures and pooled particles for optimal performance and zero asset dependencies.

var _blood_texture: ImageTexture
var _spark_material: StandardMaterial3D
var _blood_material: StandardMaterial3D
var _ring_material: StandardMaterial3D

func _ready() -> void:
	_init_textures_and_materials()

func _init_textures_and_materials() -> void:
	# 1. Generate procedural blood splatter texture for Decals
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(size * 0.5, size * 0.5)
	var max_r := size * 0.38
	
	# Main blood blotch
	for y in range(size):
		for x in range(size):
			var dist = center.distance_to(Vector2(x, y))
			if dist < max_r:
				# Irregular organic splatter edge
				var angle = center.angle_to_point(Vector2(x, y))
				var noise_val = sin(angle * 7.0) * cos(angle * 5.0) * (max_r * 0.25)
				if dist < (max_r * 0.75 + noise_val):
					var alpha = clampf(1.0 - (dist / (max_r * 0.85)), 0.6, 0.95)
					# Dark burgundy blood
					img.set_pixel(x, y, Color(0.35, 0.03, 0.05, alpha))
	
	# Satellite splatter droplets around main blotch
	var rng = RandomNumberGenerator.new()
	rng.seed = 1337
	for i in range(16):
		var ang = rng.randf_range(0, TAU)
		var d = rng.randf_range(max_r * 0.8, size * 0.48)
		var drop_center = center + Vector2(cos(ang), sin(ang)) * d
		var drop_r = rng.randf_range(2.0, 5.5)
		for dy in range(-int(drop_r) - 1, int(drop_r) + 2):
			for dx in range(-int(drop_r) - 1, int(drop_r) + 2):
				var px = int(drop_center.x + dx)
				var py = int(drop_center.y + dy)
				if px >= 0 and px < size and py >= 0 and py < size:
					if Vector2(dx, dy).length() <= drop_r:
						img.set_pixel(px, py, Color(0.38, 0.02, 0.05, 0.85))
						
	_blood_texture = ImageTexture.create_from_image(img)

	# 2. Spark particle material (additive glowing iron/gold sparks)
	_spark_material = StandardMaterial3D.new()
	_spark_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	_spark_material.blend_mode = StandardMaterial3D.BLEND_MODE_ADD
	_spark_material.albedo_color = Color(1.0, 0.75, 0.3)
	_spark_material.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES

	# 3. Blood droplet particle material (dark shiny red)
	_blood_material = StandardMaterial3D.new()
	_blood_material.shading_mode = StandardMaterial3D.SHADING_MODE_PER_PIXEL
	_blood_material.albedo_color = Color(0.45, 0.02, 0.05)
	_blood_material.roughness = 0.2
	_blood_material.metallic = 0.1

	# 4. Expanding shockwave ring material
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.blend_mode = StandardMaterial3D.BLEND_MODE_ADD
	_ring_material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.albedo_color = Color(0.7, 0.08, 0.12, 0.85)

## Spawns directional blood burst and iron sparks on hit impact
func spawn_hit_impact(hit_pos: Vector3, hit_direction: Vector3, is_heavy: bool = false) -> void:
	if not is_inside_tree():
		return

	# 1. Directional Blood Spray Particles
	var blood_particles = GPUParticles3D.new()
	add_child(blood_particles)
	blood_particles.global_position = hit_pos
	
	var blood_mat = ParticleProcessMaterial.new()
	blood_mat.direction = hit_direction.normalized()
	blood_mat.spread = 40.0 if not is_heavy else 60.0
	blood_mat.initial_velocity_min = 4.0 if not is_heavy else 7.0
	blood_mat.initial_velocity_max = 7.5 if not is_heavy else 11.5
	blood_mat.gravity = Vector3(0, -14.0, 0)
	blood_mat.damping_min = 2.0
	blood_mat.damping_max = 5.0
	blood_mat.scale_min = 0.03
	blood_mat.scale_max = 0.08 if not is_heavy else 0.12
	blood_mat.color = Color(0.48, 0.03, 0.06, 1.0)
	
	blood_particles.process_material = blood_mat
	var sphere = SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	sphere.material = _blood_material
	blood_particles.draw_pass_1 = sphere
	blood_particles.amount = 18 if not is_heavy else 36
	blood_particles.lifetime = 0.45
	blood_particles.one_shot = true
	blood_particles.explosiveness = 0.95
	blood_particles.emitting = true
	
	# 2. Gritty Kinetic Sparks
	var spark_particles = GPUParticles3D.new()
	add_child(spark_particles)
	spark_particles.global_position = hit_pos
	
	var spark_mat = ParticleProcessMaterial.new()
	spark_mat.direction = -hit_direction.normalized() + Vector3(0, 0.4, 0)
	spark_mat.spread = 75.0
	spark_mat.initial_velocity_min = 5.0
	spark_mat.initial_velocity_max = 9.0 if not is_heavy else 14.0
	spark_mat.gravity = Vector3(0, -9.8, 0)
	spark_mat.damping_min = 6.0
	spark_mat.damping_max = 10.0
	spark_mat.scale_min = 0.02
	spark_mat.scale_max = 0.05
	
	spark_particles.process_material = spark_mat
	var quad = QuadMesh.new()
	quad.size = Vector2(0.04, 0.04)
	quad.material = _spark_material
	spark_particles.draw_pass_1 = quad
	spark_particles.amount = 14 if not is_heavy else 28
	spark_particles.lifetime = 0.28
	spark_particles.one_shot = true
	spark_particles.explosiveness = 0.98
	spark_particles.emitting = true

	# 3. Spawn Floor Blood Decal below hit position
	spawn_blood_decal(hit_pos + hit_direction.normalized() * 0.4)
	
	# Auto-free particle emitters
	_schedule_free(blood_particles, 0.6)
	_schedule_free(spark_particles, 0.4)

## Projects a fading dark burgundy blood decal onto the arena floor
func spawn_blood_decal(pos: Vector3) -> void:
	if not is_inside_tree():
		return
		
	var decal = Decal.new()
	add_child(decal)
	# Position slightly above floor
	decal.global_position = Vector3(pos.x, 0.1, pos.z)
	decal.size = Vector3(1.2, 0.8, 1.2)
	decal.texture_albedo = _blood_texture
	decal.modulate = Color(0.65, 0.05, 0.08, 0.9)
	decal.cull_mask = 1 # Affects environment/floor
	
	# Random Y rotation for natural variation
	decal.rotation.y = randf_range(0, TAU)
	
	# Fade out over 5 seconds
	var tween = decal.create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(decal, "modulate:a", 0.0, 2.0)
	tween.tween_callback(decal.queue_free)

## Spawns an expanding kinetic shockwave ring (for finisher kick and parry counter)
func spawn_shockwave(pos: Vector3, max_scale: float = 3.6, color: Color = Color(0.7, 0.08, 0.12)) -> void:
	if not is_inside_tree():
		return

	var ring_node = MeshInstance3D.new()
	add_child(ring_node)
	ring_node.global_position = Vector3(pos.x, 0.08, pos.z)
	ring_node.rotation.x = -PI * 0.5 # Flat on floor
	
	var torus = TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	ring_node.mesh = torus
	
	var mat = _ring_material.duplicate() as StandardMaterial3D
	mat.albedo_color = color
	ring_node.material_override = mat
	ring_node.scale = Vector3(0.2, 0.2, 0.2)
	
	var tween = ring_node.create_tween().set_parallel(true)
	tween.tween_property(ring_node, "scale", Vector3(max_scale, max_scale, max_scale), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.24)
	
	tween.chain().tween_callback(ring_node.queue_free)

## Spawns a blood-smoke dash silhouette burst
func spawn_dash_burst(pos: Vector3, direction: Vector3) -> void:
	if not is_inside_tree():
		return
		
	var burst = GPUParticles3D.new()
	add_child(burst)
	burst.global_position = pos + Vector3(0, 0.8, 0)
	
	var mat = ParticleProcessMaterial.new()
	mat.direction = -direction.normalized()
	mat.spread = 35.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, 0.8, 0)
	mat.scale_min = 0.15
	mat.scale_max = 0.35
	mat.color = Color(0.25, 0.02, 0.04, 0.6)
	
	burst.process_material = mat
	var sphere = SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	var s_mat = StandardMaterial3D.new()
	s_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	s_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	s_mat.albedo_color = Color(0.25, 0.02, 0.04, 0.5)
	sphere.material = s_mat
	
	burst.draw_pass_1 = sphere
	burst.amount = 12
	burst.lifetime = 0.32
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.emitting = true
	
	_schedule_free(burst, 0.5)

func _schedule_free(node: Node, delay: float) -> void:
	var t = get_tree().create_timer(delay, false, false, true)
	t.timeout.connect(func():
		if is_instance_valid(node):
			node.queue_free()
	)
