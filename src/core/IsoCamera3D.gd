class_name IsoCamera3D
extends Camera3D

## Camera perspective profiles inspired by Hades and Mobile Legends: Bang Bang (MLBB)
enum CameraProfile {
	HADES_ISOMETRIC,  ## 45-degree diagonal 3/4 isometric ARPG view (like Hades)
	MLBB_MOBA,        ## Elevated forward-biased tactical MOBA view (like Mobile Legends: Bang Bang)
	CUSTOM            ## Custom manual offset & FOV
}

@export var profile: CameraProfile = CameraProfile.HADES_ISOMETRIC:
	set(val):
		profile = val
		_apply_profile_settings(profile, false)

@export var target: Node3D
@export var follow_speed: float = 8.5
@export var mouse_lead_factor: float = 0.15
@export var max_mouse_lead: float = 2.5

# Active target values (interpolated smoothly)
@export var camera_offset: Vector3 = Vector3(-14.0, 17.0, 14.0)
@export var focus_offset: Vector3 = Vector3(0.0, 0.9, 0.0)
@export var target_fov: float = 38.0

# Interpolation state for smooth transitions
var current_offset: Vector3
var current_focus: Vector3

# Screen shake trauma
var trauma: float = 0.0
var trauma_decay: float = 2.5
var max_shake_offset: float = 0.6
var noise_time: float = 0.0

@export_group("Obstacle Occlusion Transparency")
## Enable fading obstacles when blocking line of sight to player and nearby targets
@export var enable_occlusion_fade: bool = true
## Target opacity when occluded (0.28 means 28% opacity / 72% transparent)
@export var occluded_alpha: float = 0.28
## Duration of fade in/out transitions in seconds
@export var fade_duration: float = 0.18
## Physics collision mask for obstacles/environment (Layer 1)
@export_flags_3d_physics var obstacle_collision_mask: int = 1
## Radius around player to include combat targets (enemies) for occlusion fading
@export var combat_target_radius: float = 14.0

var _faded_mesh_tweens: Dictionary = {}

func _ready() -> void:
	_apply_profile_settings(profile, false)
	current_offset = camera_offset
	current_focus = focus_offset
	fov = target_fov
	
	if target:
		var initial_pos = target.global_position + current_offset
		global_position = initial_pos
		look_at(target.global_position + current_focus, Vector3.UP)
	
	if HitStopManager:
		HitStopManager.screen_shake_requested.connect(add_trauma)
		
	call_deferred("_check_automated_capture")

func _check_automated_capture() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--capture-test":
			_run_capture_sequence()
			return

func _run_capture_sequence() -> void:
	set_profile(CameraProfile.HADES_ISOMETRIC, false)
	current_offset = camera_offset
	current_focus = focus_offset
	fov = target_fov
	
	if target:
		global_position = target.global_position + camera_offset
		look_at(target.global_position + focus_offset, Vector3.UP)
	
	for i in range(25):
		await get_tree().process_frame
		
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://screenshot_gameplay_current.png")
	print("CAPTURE: screenshot_gameplay_current.png saved")
	
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	# Press 'C' to toggle between Hades and Mobile Legends camera POV
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			toggle_profile()

func toggle_profile() -> void:
	if profile == CameraProfile.HADES_ISOMETRIC:
		set_profile(CameraProfile.MLBB_MOBA, true)
	else:
		set_profile(CameraProfile.HADES_ISOMETRIC, true)

func set_profile(new_profile: CameraProfile, smooth: bool = true) -> void:
	profile = new_profile
	_apply_profile_settings(profile, smooth)
	
	# Announce camera change on HUD if available
	var profile_name = "HADES ISOMETRIC [45° DIAGONAL]" if profile == CameraProfile.HADES_ISOMETRIC else "MOBILE LEGENDS [TACTICAL MOBA]"
	GlobalEvents.damage_number_requested.emit(
		target.global_position + Vector3(0, 2.4, 0) if target else Vector3(0, 2, 0),
		"POV: " + profile_name,
		Color(0.2, 0.95, 0.9)
	)

func _apply_profile_settings(p: CameraProfile, smooth: bool) -> void:
	match p:
		CameraProfile.HADES_ISOMETRIC:
			# Hades signature isometric: 45° diagonal angle, ~40° elevation, zoomed-out tactical arena view
			camera_offset = Vector3(-14.0, 17.0, 14.0)
			focus_offset = Vector3(0.0, 0.9, 0.0)
			target_fov = 38.0
		CameraProfile.MLBB_MOBA:
			# Mobile Legends MOBA (vidref.mp4): Symmetrical elevated view with forward bias (+Z ahead vision)
			camera_offset = Vector3(0.0, 13.2, 8.5)
			focus_offset = Vector3(0.0, 0.9, -1.2)
			target_fov = 38.0
		CameraProfile.CUSTOM:
			pass
	
	if not smooth:
		current_offset = camera_offset
		current_focus = focus_offset
		fov = target_fov

func add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	if not target:
		return
	
	# Smoothly interpolate profile offsets and FOV
	current_offset = current_offset.lerp(camera_offset, 6.0 * delta)
	current_focus = current_focus.lerp(focus_offset, 6.0 * delta)
	fov = lerpf(fov, target_fov, 6.0 * delta)
	
	# Compute mouse lead on the ground plane
	var lead_offset := Vector3.ZERO
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := project_ray_origin(mouse_pos)
	var ray_dir := project_ray_normal(mouse_pos)
	var ground_plane := Plane(Vector3.UP, target.global_position.y)
	var ground_hit = ground_plane.intersects_ray(ray_origin, ray_dir)
	
	if ground_hit:
		var diff = ground_hit - target.global_position
		lead_offset = diff * mouse_lead_factor
		if lead_offset.length() > max_mouse_lead:
			lead_offset = lead_offset.normalized() * max_mouse_lead
	
	# Smoothly position camera
	var desired_pos = target.global_position + current_offset + lead_offset
	global_position = global_position.lerp(desired_pos, follow_speed * delta)
	
	# Keep camera focused smoothly on target + focus offset + slight lookahead
	var look_target = target.global_position + current_focus + (lead_offset * 0.3)
	look_at(look_target, Vector3.UP)
	
	# Process screen shake trauma
	if trauma > 0.0:
		noise_time += delta * 45.0
		var shake_amount = trauma * trauma
		h_offset = sin(noise_time) * max_shake_offset * shake_amount
		v_offset = cos(noise_time * 1.3) * max_shake_offset * shake_amount
		trauma = max(0.0, trauma - trauma_decay * delta)
	else:
		h_offset = 0.0
		v_offset = 0.0

func _physics_process(_delta: float) -> void:
	_update_occlusion_fading()

func _update_occlusion_fading() -> void:
	if not enable_occlusion_fade or not target:
		return
	
	var space_state := get_world_3d().direct_space_state
	if not space_state:
		return
	
	var currently_occluding: Dictionary = {}
	var test_points: Array[Vector3] = []
	var player_base = target.global_position
	
	# 1. Sample player torso, head, and shoulder width
	test_points.append(player_base + Vector3(0.0, 0.9, 0.0))
	test_points.append(player_base + Vector3(0.0, 1.5, 0.0))
	
	var cam_to_player = (player_base - global_position).normalized()
	var right_vec = cam_to_player.cross(Vector3.UP).normalized()
	test_points.append(player_base + Vector3(0.0, 0.9, 0.0) + right_vec * 0.4)
	test_points.append(player_base + Vector3(0.0, 0.9, 0.0) - right_vec * 0.4)
	
	# 2. Sample nearby combat targets (enemies)
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy is Node3D and is_instance_valid(enemy):
			if enemy.global_position.distance_to(player_base) <= combat_target_radius:
				test_points.append(enemy.global_position + Vector3(0.0, 0.9, 0.0))
				test_points.append(enemy.global_position + Vector3(0.0, 1.5, 0.0))
	
	# 3. Exclude characters themselves from the raycast
	var exclude_rids: Array[RID] = []
	if target is CollisionObject3D:
		exclude_rids.append(target.get_rid())
	for enemy in enemies:
		if enemy is CollisionObject3D and is_instance_valid(enemy):
			exclude_rids.append(enemy.get_rid())
	
	# 4. Perform raycasts
	for pt in test_points:
		var dir = (pt - global_position).normalized()
		var ray_origin = global_position + dir * 0.5
		var query := PhysicsRayQueryParameters3D.create(ray_origin, pt, obstacle_collision_mask, exclude_rids)
		
		# Trace ray through multiple potential obstacles
		var max_passes = 4
		var current_from = ray_origin
		while max_passes > 0:
			max_passes -= 1
			query.from = current_from
			query.to = pt
			var hit = space_state.intersect_ray(query)
			if hit.is_empty():
				break
			
			var collider = hit.collider
			if collider is Node:
				var meshes = _find_meshes_in_object(collider)
				for m in meshes:
					currently_occluding[m] = true
			
			if "position" in hit:
				current_from = hit.position + dir * 0.1
				if current_from.distance_to(pt) < 0.2:
					break
			else:
				break
	
	# 5. Fade occluding obstacles
	var target_transparency = 1.0 - occluded_alpha
	for mesh in currently_occluding.keys():
		if not is_instance_valid(mesh):
			continue
		if not _faded_mesh_tweens.has(mesh) or not is_equal_approx(mesh.transparency, target_transparency):
			_fade_mesh(mesh, target_transparency)
	
	# 6. Restore non-occluding obstacles
	var to_remove: Array[MeshInstance3D] = []
	for mesh in _faded_mesh_tweens.keys():
		if not is_instance_valid(mesh):
			to_remove.append(mesh)
			continue
		if not currently_occluding.has(mesh):
			_restore_mesh(mesh)
			to_remove.append(mesh)
			
	for mesh in to_remove:
		_faded_mesh_tweens.erase(mesh)

func _find_meshes_in_object(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	
	for child in node.get_children():
		if child is MeshInstance3D:
			result.append(child)
			
	if result.is_empty() and node.get_parent():
		for sibling in node.get_parent().get_children():
			if sibling is MeshInstance3D:
				result.append(sibling)
				
	return result

func _fade_mesh(mesh: MeshInstance3D, target_transparency: float) -> void:
	# Ensure mesh has its own unique material override to prevent mutating shared materials
	var mat = mesh.material_override as StandardMaterial3D
	if not mat:
		var base_mat: StandardMaterial3D = null
		if mesh.mesh and mesh.mesh.material is StandardMaterial3D:
			base_mat = mesh.mesh.material
		elif mesh.get_surface_override_material(0) is StandardMaterial3D:
			base_mat = mesh.get_surface_override_material(0)
		
		if base_mat:
			mat = base_mat.duplicate() as StandardMaterial3D
		else:
			mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.22, 0.24, 0.3, 1.0)
			mat.roughness = 0.7
			
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		mesh.material_override = mat

	if _faded_mesh_tweens.has(mesh):
		var tw = _faded_mesh_tweens[mesh]
		if tw is Tween and tw.is_valid():
			tw.kill()

	var target_alpha = 1.0 - target_transparency
	var tween = create_tween().set_parallel(true)
	tween.tween_property(mesh, "transparency", target_transparency, fade_duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", target_alpha, fade_duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	_faded_mesh_tweens[mesh] = tween

func _restore_mesh(mesh: MeshInstance3D) -> void:
	var mat = mesh.material_override as StandardMaterial3D
	if _faded_mesh_tweens.has(mesh):
		var tw = _faded_mesh_tweens[mesh]
		if tw is Tween and tw.is_valid():
			tw.kill()
			
	var tween = create_tween().set_parallel(true)
	tween.tween_property(mesh, "transparency", 0.0, fade_duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	if mat:
		tween.tween_property(mat, "albedo_color:a", 1.0, fade_duration)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_IN)
