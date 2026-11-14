shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 beam_tint : source_color = vec4(0.58, 0.76, 1.0, 1.0);
uniform float beam_density : hint_range(0.0, 2.0) = 1.0;
uniform float beam_softness : hint_range(0.0, 1.0) = 0.8;
// Metres over which the volume dissolves when it lies close to an opaque surface.
uniform float surface_fade : hint_range(0.0, 4.0) = 0.6;
uniform sampler2D depth_tex : hint_depth_texture;

float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	// UV.y runs from the emitter (0) toward the far end (1).
	float v = UV.y;
	float axial = smoothstep(0.0, 0.08, v) * (1.0 - smoothstep(0.38, 0.92, v));
	float apex_glow = 1.0 - smoothstep(0.0, 0.22, v);

	// Grazing-angle fade: alpha reaches zero at the geometric silhouette, so the
	// low-poly cone edge can never read as a hard polygon boundary.
	float ndv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float silhouette = smoothstep(0.0, mix(0.28, 0.78, beam_softness), ndv);

	// Low-frequency haze drifts on TIME (render clock) and never steps.
	float haze_a = smooth_noise(vec2(UV.x * 4.0, UV.y * 7.0 - TIME * 0.10));
	float haze_b = smooth_noise(vec2(UV.x * 9.0 + 13.0, UV.y * 14.0 - TIME * 0.18));
	float haze = mix(0.82, 1.12, haze_a * 0.65 + haze_b * 0.35);

	// Soft-particle fade against the depth buffer: the volume dissolves over
	// 'surface_fade' metres instead of intersecting geometry with a hard line.
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 vview = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vview.xyz /= vview.w;
	float scene_dist = -vview.z;
	float diff = scene_dist + VERTEX.z;
	float contact = pow(clamp(1.0 - diff / max(surface_fade, 0.001), 0.0, 1.0), 1.4);

	float intensity = axial * silhouette * haze * (1.0 - contact);
	vec3 tint = beam_tint.rgb;
	ALBEDO = tint * 0.25;
	EMISSION = tint * (0.9 + 0.9 * apex_glow);
	ALPHA = beam_density * 0.30 * intensity
		+ beam_density * 0.18 * apex_glow * silhouette * (1.0 - contact);
}
