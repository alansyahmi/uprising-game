shader_type spatial;

uniform vec4 color_tile : source_color = vec4(0.14, 0.16, 0.22, 1.0);
uniform vec4 color_grout : source_color = vec4(0.07, 0.08, 0.11, 1.0);
uniform vec4 color_accent : source_color = vec4(0.18, 0.21, 0.29, 1.0);
uniform float tile_scale = 18.0;
uniform float grout_width = 0.035;

void fragment() {
	vec2 uv = UV * tile_scale;
	vec2 grid = fract(uv);
	
	// Smooth grout lines
	float edge_x = smoothstep(0.0, grout_width, grid.x) * smoothstep(0.0, grout_width, 1.0 - grid.x);
	float edge_y = smoothstep(0.0, grout_width, grid.y) * smoothstep(0.0, grout_width, 1.0 - grid.y);
	float tile_mask = edge_x * edge_y;
	
	// Subtle alternation between adjacent stone slabs
	vec2 tile_id = floor(uv);
	float pattern = mod(tile_id.x + tile_id.y, 2.0);
	vec3 slab_color = mix(color_tile.rgb, color_accent.rgb, pattern * 0.18);
	
	ALBEDO = mix(color_grout.rgb, slab_color, tile_mask);
	ROUGHNESS = mix(0.9, 0.65, tile_mask);
	METALLIC = 0.08;
}
