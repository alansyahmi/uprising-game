class_name MotionTrail3D
extends MeshInstance3D

# Dynamic ribbon trail for punches, kicks, and weapon swings in Godot 4.
# Uses ImmediateMesh to construct a smooth gradient triangle strip between tracked points.

@export var max_points: int = 10
@export var trail_width: float = 0.28
@export var trail_color_head: Color = Color(0.85, 0.08, 0.12, 0.85)
@export var trail_color_tail: Color = Color(0.35, 0.02, 0.04, 0.0)

var is_emitting: bool = false
var _points: Array[Dictionary] = [] # Array of { "top": Vector3, "bottom": Vector3, "alpha": float }
var _imm_mesh: ImmediateMesh
var _trail_material: StandardMaterial3D

func _ready() -> void:
	_imm_mesh = ImmediateMesh.new()
	mesh = _imm_mesh
	
	_trail_material = StandardMaterial3D.new()
	_trail_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	_trail_material.blend_mode = StandardMaterial3D.BLEND_MODE_ADD
	_trail_material.cull_mode = StandardMaterial3D.CULL_DISABLED
	_trail_material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	_trail_material.vertex_color_use_as_albedo = true
	material_override = _trail_material
	
	top_level = true # Work in world coordinates so trail stays pinned in world space

func start_trail() -> void:
	_points.clear()
	is_emitting = true
	visible = true

func stop_trail() -> void:
	is_emitting = false

func _process(delta: float) -> void:
	# Age existing points
	var i = _points.size() - 1
	while i >= 0:
		_points[i]["alpha"] -= delta * 5.0 # Fade over ~0.2s
		if _points[i]["alpha"] <= 0.0:
			_points.remove_at(i)
		i -= 1

	# Sample new points if emitting
	if is_emitting and get_parent() is Node3D:
		var parent_node = get_parent() as Node3D
		var center_pos = parent_node.global_position
		var up_vec = parent_node.global_transform.basis.y.normalized() * (trail_width * 0.5)
		
		_points.push_front({
			"top": center_pos + up_vec,
			"bottom": center_pos - up_vec,
			"alpha": 1.0
		})
		
		if _points.size() > max_points:
			_points.pop_back()

	_rebuild_mesh()
	
	if not is_emitting and _points.is_empty():
		visible = false

func _rebuild_mesh() -> void:
	_imm_mesh.clear_surfaces()
	if _points.size() < 2:
		return

	_imm_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for idx in range(_points.size()):
		var pt = _points[idx]
		var ratio = float(idx) / float(_points.size())
		var col = trail_color_head.lerp(trail_color_tail, ratio)
		col.a *= pt["alpha"]
		
		_imm_mesh.surface_set_color(col)
		_imm_mesh.surface_add_vertex(pt["top"])
		_imm_mesh.surface_set_color(col)
		_imm_mesh.surface_add_vertex(pt["bottom"])
		
	_imm_mesh.surface_end()
