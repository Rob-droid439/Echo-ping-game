shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 beam_tint : source_color = vec4(0.82, 0.88, 1.0, 1.0);

void fragment() {
	// UV.y runs from the small eye-side opening toward the far end.
	float apex_fade = pow(clamp(1.0 - UV.y, 0.0, 1.0), 0.55);
	float far_fade = 1.0 - smoothstep(0.75, 1.0, UV.y);
	vec3 view_dir = normalize(VIEW);
	float edge = pow(clamp(abs(dot(NORMAL, view_dir)), 0.0, 1.0), 0.35);
	ALBEDO = beam_tint.rgb;
	EMISSION = beam_tint.rgb;
	ALPHA = 0.055 * apex_fade * far_fade * (0.25 + 0.75 * edge);
}
